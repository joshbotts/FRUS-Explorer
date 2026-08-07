// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation
import OSLog
import SQLite3
import CoreSpotlight
#if canImport(UIKit)
import UIKit
#endif

private let SQLITE_TRANSIENT_IP = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - IndexingPipeline

/// Processes downloaded FRUS volume XML files into the FTS5 search index and
/// auxiliary SQLite tables (`cross_references`, `page_ranges`, `document_cache`,
/// `document_dates`).
///
/// ## Architecture
/// `IndexingPipeline` is an actor. It owns:
/// - A reference to `FTS5Store` for all FTS5 virtual-table operations.
/// - A raw SQLite connection to the same database file for four auxiliary tables.
///
/// Both connections share the same WAL-mode SQLite file; SQLite serialises writers
/// automatically so concurrent access is safe.
///
/// ## Concurrency
/// `indexAllVolumes()` uses `withThrowingTaskGroup` with a sliding-window pattern
/// to run up to `concurrencyLimit` XML parsers concurrently. XML parsing runs via
/// `nonisolated parseAndExtract`, which leaves the actor's executor free. Storage
/// into SQLite is serialised through the actor.
///
/// ## Auxiliary Tables
/// | Table | Purpose |
/// |---|---|
/// | `cross_references` | Directed edges from `<ref>` elements |
/// | `page_ranges` | One row per `<pb>` element (Session 30 citation lookup) |
/// | `document_cache` | Un-stemmed field text enabling incremental summary/note updates |
/// | `document_dates` | Structured ISO 8601 dates for `SearchService` date filtering |
/// | `person_mentions` | One row per unique person ref per document (Session 39) |
///
/// ## section_id in page_ranges
/// `section_id` equals the containing document's `xml:id`. Pagination restarts between
/// FRUS compilation sections are therefore distinguished naturally because each document
/// has a unique `xml:id`. This matches the Session 30 citation-lookup requirement.
///
/// Version history:
///   1.0 — Session 09: initial implementation
///   1.1 — Session 36: structured date extraction via `<date @when/@from/@to>` AST nodes;
///          `extractStructuredDate(from:)` replaces `parseDateISO` as primary call site;
///          `dateIndexVersion` UserDefaults key added for migration detection
///   1.2 — Session 37: `extractCrossReferences` now populates `context` with the plain
///          text of the enclosing `<note>` or `<div type="editorialNote">` (≤500 chars,
///          truncated at word boundary); `<ref>` in bare paragraphs still gets nil context
///   1.3 — Session 38: `is_editorial_note` column added to `document_cache` and `frus_documents`;
///          `DocumentBrowserEntry.isEditorialNote` populated from the new column
///   1.4 — Session 39: `person_mentions` table added; `extractPersonRefs` populates it
///          during indexing; `PersonMentionRow` private struct added
///   1.5 — Session 41: `persons` and `terms` tables added; glossaries persisted during indexing
///   1.6 — Session 48: FTS5 schema version tracking added; `needsFTSRebuildReindex` / `markFTSRebuildReindexComplete()`
///   1.7 — Session 51: iOS batch-size throttle; memory-warning observer; `Task.yield()` between
///          FTS5 batches; `progressStream: AsyncStream<IndexingProgressUpdate>` for inline capsule
///   1.8 — Session 54: `effectiveConcurrencyLimit` caps `indexAllVolumes` to 1 on iOS;
///          `storeIndexData` co-batches FTS5 and `document_cache` writes to reduce peak RSS
///   1.9 — Session 73: `fetchDocumentBodyText(volumeId:documentId:)` made public; used by
///          collection export's SQLite fast-path before falling back to XML parsing
///   2.0 — Session 75: `indexAllVolumes` switched from `withThrowingTaskGroup` to a
///          non-throwing `withTaskGroup` with per-volume error handling; failed volumes
///          emit `.failed` progress events and the remaining batch continues; duplicate
///          rows in `cross_references`/`person_mentions` on re-index fixed by deleting
///          existing volume rows before inserting; `extractStructuredDate.collectDateNodes`
///          now skips `.footnote` descendants (fixes date corruption from footnote <date>
///          references); `currentDateIndexVersion` bumped to 4
///   2.1 — Session 76: `document_dates` gains `date_iso_max` column; date filtering uses
///          interval overlap (`date_iso <= rangeEnd AND COALESCE(date_iso_max, date_iso)
///   2.2 — Session 88: `datesByDocumentKey(_:)` for timeline year grouping
///          >= rangeStart`) instead of point comparison; `extractDateRange` replaces
///          single-value extraction, using `frus:doc-dateTime-min`/`max` from the AST
///          when present and falling back to per-attribute priority logic; `collectDateNodes`
///          extracted to a shared private helper; `currentDateIndexVersion` bumped to 5
///   2.2 — Session 78: `.attachment` added to the exhaustive `plainText` and `children`
///          computed-property switch sites so attachment body text is included in the
///          full-text search index
///   2.3 — Session 118: `optimize()` moved from `FTS5Store.insertBatch` to a single
///          post-batch call in `indexAllVolumes` and `indexVolume`; eliminates O(n²)
///          performance regression that caused 60+ min corpus indexing; `#if DEBUG`
///          prints replaced with `os.Logger` (always-on, viewable in Console.app)
///   2.4 — Session 118 (follow-up): fix `page_ranges` duplicate rows on re-index (plain
///          INSERT with no pre-delete); fix `docsPerSecond` always 0 during `indexAllVolumes`
///          (`volumeIndexingStartTime` never set); fix `metadataStream` dark during bulk
///          indexing (`emitMetadata` never called); add per-volume `.reading` update in
///          `indexAllVolumes`; carry `volumeId` through parse-failure events (was "unknown")
///   2.5 — Session 119: `allDocumentDates()` — full-table scan returning every indexed
///          document's `date_iso`; used by `CorpusAnalyticsService` to bucket analytics
///          results by actual document date rather than volume start year
///   2.6 — Session 123: emit `.optimizing` + `.complete` IndexingProgressUpdate events
///          around the post-batch `fts5Store.optimize()` call so the bulk-reindex UI
///          doesn't appear to stall during the 30–60 s optimise phase. Previously the
///          only completion signal was on the legacy `progressContinuation` stream,
///          which `AppState.connectIndexingProgress` does not observe.
///   2.7 — Session 123: search performance pass:
///          • `documentDates` + `documentBodyTexts` use CTE VALUES joins instead of
///            `volume_id || '/' || document_id IN (…)` — composite PK index now used
///            instead of a full table scan (83k-row scan → 400-row index lookup per chunk).
///          • `documentBodyTextsAndDates` combined function fetches both values in one
///            SQL statement, halving actor round-trips during search post-processing.
///          • `PRAGMA temp_store=MEMORY` added to keep CTE materializations in RAM.
///   2.8 — Session 129: `documentBodyTextsAndDates` extended to also return `header` and
///          `dateline` from `document_cache`. `SearchService` now substitutes these
///          unstemmed values for the FTS5-indexed (Porter-stemmed) ones so search result
///          rows display the original document text rather than stemmed tokens.
///   2.9 — Session 129: `datesByDocumentKey` silent 500-pair cap replaced with chunked
///          queries (499 strings/chunk, matches 999-variable limit); `currentDateIndexVersion`
///          bumped to 6 to trigger a full clean reindex on devices that accumulated FTS5
///          duplicate rows before the Session 118 `deleteVolume()` fix.
///   3.0 — Current session: `resolvePageBasedCrossReferences(volumeId:)` post-indexes
///          TEI `<ref target="#p{N}">` / `<ref target="#pg{N}">` page references to their
///          containing document IDs via the `page_ranges` table; called in `storeIndexData`
///          after both tables are populated.
///   3.1 — Session 2026-06-08: large-corpus indexing stability:
///          • `PRAGMA wal_checkpoint(PASSIVE)` after each volume in `indexAllVolumes` to
///            prevent the WAL file from growing unboundedly (~50 MB peak vs 1 GB+ before).
///          • `autoreleasepool` added to `FRUSDocumentParser.parseVolumeFull` around the
///            `XMLParser.parse()` call to drain ObjC autorelease pools between volumes,
///            reducing peak RSS spikes that could trigger iOS jetsam kills mid-batch.
///   3.2 — Session 2026-06-08: Volume Front Matter feature:
///          • `VolumeStructureParserDelegate.structuralTypes` extended with `"prefatoryNote"`,
///            `"sources"`, `"persons"`, `"terms"` so front-matter sections are captured.
///          • `volumeSources(forVolumeId:)` public query added to surface front-matter archival
///            sources for `VolumeSourcesView`.
///   3.3 — Session 2026-06-08: `documentBodyTextsAndDates` extended to also return
///          `frontMatterKeys: Set<String>` — the set of `"volumeId/documentId"` composite
///          keys for rows where `is_front_matter = 1`. `SearchService` uses this to populate
///          `SearchResult.isFrontMatter` so the search UI can badge front-matter results.
///   4.0 — Session 2026-06-09: external-content FTS5 redesign.
///          • `frus_documents` and the new `user_content` table are external-content
///            FTS5 tables over `document_cache`, maintained by SQL triggers created in
///            `setupDatabase`. `document_cache` is the single write path for document
///            text; the FTS5 tables store only the inverted index (porter unicode61).
///          • Re-indexing UPSERTs cache rows in place — preserving rowids (the FTS5
///            key) and user fields (`summary_text`, `note_text`, `user_tag_ids`),
///            which `INSERT OR REPLACE` previously wiped on every re-index.
///          • Summary/note/tag updates are single-row `document_cache` UPDATEs; the
///            `AFTER UPDATE OF` triggers re-tokenize only the affected FTS5 table.
///          • `searchDocuments`/`searchDocumentsCount` run the combined corpus +
///            user-content search with all structured filters in SQL — exact
///            pagination, no overscan, one round-trip per search.
///          • `rebuildSearchIndexFromCache()` rebuilds both FTS5 tables from
///            `document_cache` via the FTS5 `rebuild` command (migration fast path —
///            no XML re-parse).
///          • Removed: `frontMatterDocumentKeys`, `documentBodyTexts(AndDates)`
///            (subsumed by `searchDocuments`), per-document FTS5 delete loops.
///   4.1 — Session 154: `checkIndexIntegrity()` runs `PRAGMA quick_check` plus an
///          `integrity-check` (rank=1) on both `frus_documents` and `user_content`,
///          returning a list of problem descriptions for the Storage settings pane.
///          `rebuildSpotlightIndex()` clears and re-submits the Spotlight index from
///          `document_cache` without re-parsing XML; `submitSpotlightItems(for:)` and
///          the new method now share a `makeSearchableItem` helper.
///   4.2 — Session 2026-07-03 (people-eval audit): person-mention `ref` normalisation
///          strips a `volumeId#` prefix (split-set volumes point part 2's body at part 1's
///          persons list — `currentDateIndexVersion` → 13); person rollup v8: junk-name
///          purge hardening, clusterer cannot-link/suffix/Mrs guardrails, and the cluster
///          authority id picked by majority-of-mentions (`majorityAuthorityId`) instead of
///          input order (`currentPersonRollupVersion` → 8).
///   4.3 — Source Explorer Phase 1 (Session 2026-07-03): `extractSourceNote` ports the
///          frus-sources locator chain — head/note/p/seg[@type="source"] →
///          head/note[@type="source"] → top-level inline note — fixing the dominant
///          audit bug: only top-level notes were scanned, so ~77k documents in 1955–1991
///          volumes (which nest the note in `<head>`) had no stored source note (<1%
///          coverage vs 90–95% pre-1955). `[Source: …]` wrappers normalise to
///          `Source: …` so both encodings store one shape and structured
///          (`citation_era='structured'`) rows now exist. `extractHeader` excludes
///          footnote children of `<head>` (cleaner titles — the nested note previously
///          leaked into `document_cache.header`). `document_sources` gains a
///          `classification` column (S1: sentence 2 of the note when it matches the
///          classification-marking vocabulary; store-only).
///          `currentDateIndexVersion` → 14.
///   4.4 — Source Explorer Phase 1 adversarial-review fixes (Session 2026-07-03):
///          `extractSourceNote` gates the pattern-2 whole-note fallback — a head-nested
///          `<note type="source">` whose text lacks a `Source:`/`[Source:` prefix is an
///          editorial remark in the 29 dual-encoding documents, so it now defers to the
///          top-level note (restoring the real decimal/lot citation in 25 pre-1955 docs)
///          and is used only when no top-level note yields text (~1,991 docs with no
///          alternative). `extractHeader` excludes `.footnote` *descendants* of `<head>`
///          via `plainTextExcludingFootnotes` (68 titles nested the note inside
///          `<hi>`/`<persName>`/`<p>` markup). `currentDateIndexVersion` → 15.
///   4.5 — Source Explorer Phase 3 step 1 (Session 2026-07-03): `volume_sources` gains
///          normalized match-key columns `lot_file_norm` (canonical compact lot key,
///          matching `document_sources.lot_file_norm`) and `decimal_class`
///          (subject-numeric / decimal class-leaf location), populated from the
///          reworked `SourcesParserDelegate` (shared lot grammar, outline inheritance,
///          series validity gate, `kind='bibliography'` for listofworks rows).
///          Drop-and-recreate migration keyed on the missing `lot_file_norm` column;
///          `currentDateIndexVersion` → 18.
///   4.6 — Source Explorer Phase 3 step 2 (Session 2026-07-03): matcher rework — no
///          parse-output change, so no index-version bump. `relatedByLotFile` is a
///          single indexed `lot_file_norm` equality (the 4-variant `IN` retired; both
///          sides write the canonical compact key at parse time, so coverage is
///          structural). `relatedByCollection` becomes a normalized comma-boundary
///          prefix match (doc side appends ", Box N") tolerant of both stored
///          record-group forms ("84" / "RG-84"). New volume-level match paths:
///          `relatedByDecimalClass` (front-matter class leaves vs decimal/CFPF rows,
///          S3 lean — prefix match, no period segmenting) and the presidential-library
///          path (`archivalNeighbors(forLotFile:…)` gains `repository`/`decimalClass`
///          and routes library repositories through `relatedByPresidentialLibrary`).
///          LIKE inputs are wildcard-escaped; basis strings localized.
///   4.7 — Source Explorer Phase 3 verification fixes (Session 2026-07-03): the class
///          path made real end-to-end. `document_sources` gains an indexed
///          `decimal_class` column — the canonical class location
///          (`SourceNoteParser.decimalClassKey`: collapsed whitespace, Unicode
///          dashes → ASCII hyphen) extracted from central-files-shaped citations
///          (`.centralFiles`, `.cfpfFile`, and `.naraCollection` rows naming the
///          central files, whose subject-numeric leaf was previously unstored).
///          `relatedByDecimalClass` becomes an indexed equality/prefix lookup on that
///          column (the era-gated `series_name` LIKE fan-out retired — it starved:
///          structured rows were invisible to it and narrative decimal rows often
///          stored no location). `currentDateIndexVersion` → 19.
///   4.8 — Source Explorer Phase 3 adversarial-review fixes (Session 2026-07-03):
///          real bibliography detection (`Published Sources` pseudo-heading subtrees
///          and section heads — the Version-18 `listofworks` trigger matched zero
///          corpus volumes), class-gate hardening (run-together `RG59`/`NYFRC`,
///          numbered issuances, PRC accessions rejected; citation class scan bounded
///          to the citation sentence), plural/spaced-suffix lot grammar, and
///          matcher doc-comment corrections (`relatedByDecimalClass` is a covering-
///          index scan, not a seek — SQLite's LIKE prefix optimization cannot engage
///          on the BINARY-collated column). `currentDateIndexVersion` → 20.
///   4.9 — Source Explorer Phase 4 step 2 (Session 2026-07-03): collection-authority
///          app wiring — no parse-output change, so no index-version bump.
///          `localCollectionStats` computes the S5 local counts for a bundled
///          authority record (indexed documents citing it + their distinct volumes)
///          from the normalized-key columns; `archivalNeighbors(forLotFile:…)` gains
///          a display-time **alias fallback** (`CollectionAliasFallback`, built from
///          the bundled authority record): when every direct key path returns zero,
///          the authority's lot key and then its merged alias forms are retried
///          through the same match paths, bridging the Phase-3 grain mismatches
///          (library sub-collections, heading-level series names).
///  4.10 — Source Explorer Phase 4 adversarial review (Session 2026-07-04): no
///          parse-output change, so no index-version bump. `collectionNeighbors`
///          lists a whole authority record's neighbors through the **same** OR-union
///          clause `localCollectionStats` counts with (`collectionMatchClause` —
///          one clause, one truth; the Collection detail sheet total now always
///          equals the S5 count), and the form window widens 8 → 13
///          (`collectionMatchFormCap`: canonical name + the artifact's 12-alias cap).
///  4.11 — Source Explorer Phase 5 step 1 (Session 2026-07-04): no parse-output
///          change, so no index-version bump. Batched three-state neighbor counts:
///          `neighborCountKey(forLotFile:…)` is the single path-selection truth
///          (`directArchivalNeighbors` now dispatches on it) and
///          `archivalNeighborCounts(forKeys:)` resolves a whole volume's keyed
///          source entries in one round-trip per key family (lot IN + GROUP BY;
///          UNION ALL of per-key COUNT branches reusing the per-tap WHERE builders
///          `classLeafPatterns` / `libraryMatchClause` / `rgSeriesClause`). The
///          Phase-4 alias fallback is deliberately excluded from counts (a zero
///          badge stays tappable and the sheet may exceed it — documented there).
///  4.12 — CA-4 review fix (Session 2026-07-04): no parse-output change, so no
///          index-version bump. `allDocumentKeysWithDates()` enumerates every indexed
///          document (`document_cache`) LEFT JOINed to its optional `date_iso`, so
///          `CorpusAnalyticsService`'s normalization denominator can count undated
///          documents via the volume-start-year fallback — the same population the
///          term-frequency numerator counts — instead of only the dated subset.
///  4.13 — Page-reference resolution fix (Session 2026-07-05): `currentDateIndexVersion`
///          → 21 (parse-output change forces a one-time re-index). FRUS TEI marks each
///          printed page `<pb n="427" xml:id="pg_427"/>` and references it with
///          `<ref target="#pg_427">` — the raw fragment stored is `pg_427` (underscore).
///          `resolvePageBasedCrossReferences` previously matched only the no-underscore
///          `p{N}`/`pg{N}` GLOB and stripped with `dropFirst(2)`, so it resolved zero
///          of the ~2M `pg_{N}` page references — they persisted as phantom `pg_N`
///          targets in every `cross_references`-based feature (CA-6 analytics, the
///          cross-reference graph, the volume connection matrix). Now matches the real
///          `pg_[0-9]*` form, strips `pg_` (`dropFirst(3)`), and resolves via the shared
///          `PageSpanResolver.documentContaining(page:in:)` — the same span-containing
///          algorithm the reader (`PageRangeStore`) uses — so the graph agrees with the
///          footnote links. Roman/front-matter anchors (`pg_III`) and cross-volume page
///          refs stay unresolved (no containing document).
///   Session 09: document-level subject tags retired — `subject_tag_ids` is written
///         NULL (column kept for schema stability; no `currentDateIndexVersion`
///         bump — an emptied derived column, not a parse-semantics change) and the
///         subject-tag WHERE filter is neutralized; `subjectTagStore` dependency
///         removed from the initializer.
///   Session 4 / #243: the person-rollup staleness gate compares a deterministic
///         content fingerprint of the override set (`overrideFingerprint`) instead of
///         its count — a remove-plus-add that nets the same count (routine once the
///         corrections manager's undo exists) now correctly reconsolidates; the old
///         `personRollupOverrideCount` UserDefaults value is cleaned up on first stamp.
///   Session 7 / #240B: `cross_references.is_broken` column + per-volume
///         `markBrokenCrossReferences` (runs before page resolution) + the gated
///         `applyBrokenRefsIndexIfNeeded` backfill keyed to the bundled index's
///         `generated` stamp. Review fix: `resolvePageBasedCrossReferences` enforces
///         its same-volume-only contract (`target_volume_id IS NULL`) —
///         `currentDateIndexVersion` → 22 (see the v22 note above).
public actor IndexingPipeline {

    // MARK: - Configuration

    /// Maximum number of volume XML parsers running concurrently. Default 4.
    public let concurrencyLimit: Int

    /// Effective concurrency cap used by `indexAllVolumes`.
    ///
    /// On iOS, parallel XML parsing of multiple large volumes simultaneously can
    /// exhaust the process memory budget even when each individual volume is processed
    /// in small FTS5 write batches. Capping to 1 on iOS ensures only one volume's
    /// parsed data is in memory at a time during bulk re-index operations.
    private var effectiveConcurrencyLimit: Int {
        #if os(iOS)
        return 1
        #else
        return concurrencyLimit
        #endif
    }

    // MARK: - Batch-size throttle (Session 51)

    /// Default FTS5 insertion batch size per platform.
    ///
    /// On iOS the batch is capped at 50 documents to keep peak RSS below the
    /// system's memory-pressure threshold. On macOS the entire volume is written
    /// in a single transaction (effectively unlimited).
    public static let platformDefaultBatchSize: Int = {
        #if os(iOS)
        return 50
        #else
        return Int.max
        #endif
    }()

    /// Override set by the memory-warning observer or by `setTestBatchSize(_:)`.
    /// When `nil`, `effectiveBatchSize` falls back to `platformDefaultBatchSize`.
    private var _dynamicBatchSize: Int?

    /// The batch size currently in effect for FTS5 insertions.
    var effectiveBatchSize: Int { _dynamicBatchSize ?? Self.platformDefaultBatchSize }

    /// Reduces the effective batch size to 20 when the system reports memory pressure.
    /// Called on the actor from the notification observer.
    private func reduceForMemoryPressure() {
        _dynamicBatchSize = 20
        logger.warning("Memory warning received — batch size reduced to 20")
    }

    /// Test hook: overrides the effective batch size.
    func setTestBatchSize(_ size: Int) { _dynamicBatchSize = size }

    /// Test hook: exposes `effectiveConcurrencyLimit` for platform-specific assertions.
    func testEffectiveConcurrencyLimit() -> Int { effectiveConcurrencyLimit }

    // MARK: - FTS5 Schema Migration (Session 48)

    /// Current FTS5 virtual table schema version.
    ///
    /// Increment this value when the FTS5 schema changes in a way that requires
    /// the index contents to be rebuilt.
    ///
    /// - Version 3: `is_editorial_note UNINDEXED` column added (Session 38/48).
    /// - Version 4: external-content redesign (Session 2026-06-09). `frus_documents`
    ///   reads content from `document_cache` and uses the built-in `porter unicode61`
    ///   tokenizer; summaries/notes moved to the `user_content` table. The rebuild is
    ///   satisfied by `rebuildSearchIndexFromCache()` (no XML re-parse): the content
    ///   table already holds original unstemmed text. This also restores any rows
    ///   previously lost to the unscoped-`document_id` FTS5 delete bug, because
    ///   `document_cache` was never affected by those deletes.
    public static let currentFTSSchemaVersion: Int = 4

    /// UserDefaults key tracking whether the post-FTS5-rebuild re-index is complete.
    public static let ftsSchemaVersionKey = "frusExplorer.ftsSchemaVersion"

    /// Returns `true` if a FTS5 schema rebuild occurred this launch and volumes need
    /// re-indexing so that `is_editorial_note` is correctly populated in the index.
    public nonisolated var needsFTSRebuildReindex: Bool {
        UserDefaults.standard.integer(forKey: Self.ftsSchemaVersionKey) < Self.currentFTSSchemaVersion
    }

    /// Records that the post–FTS5-rebuild re-index is complete.
    /// Call this after `indexAllVolumes()` completes following a schema rebuild.
    public func markFTSRebuildReindexComplete() {
        UserDefaults.standard.set(Self.currentFTSSchemaVersion, forKey: Self.ftsSchemaVersionKey)
        logger.info("FTS5 schema re-index marked at version \(Self.currentFTSSchemaVersion, privacy: .public)")
    }

    // MARK: - Date Index Migration

    /// Current date-index schema version.
    ///
    /// Increment this value whenever `extractStructuredDate` or the `document_dates`
    /// schema changes in a way that requires previously-indexed volumes to be re-indexed.
    ///
    /// - Version 1: plain-text heuristic only (`parseDateISO`)
    /// - Version 2: structured `<date @when/@from/@to>` extraction (Session 36)
    /// - Version 3: all partial dates normalized to full yyyy-MM-dd precision
    /// - Version 4: footnote nodes excluded from date search (Session 75); prevents
    ///   cross-reference dates inside footnotes from corrupting documents' date index
    /// - Version 5: `date_iso_max` column added; interval overlap filtering; `@to` and
    ///   `@notAfter` now captured as range end; `frus:doc-dateTime-min`/`max` used when
    ///   present as authoritative editorial date bounds (Session 76)
    /// - Version 6: FTS5 duplicate-row migration (Session 129) — devices that indexed
    ///   before Session 118 accumulated duplicate rows in `frus_documents` because the
    ///   `deleteVolume()` call before reindex was not yet present; bumping this version
    ///   triggers a full clean reindex via `needsDateReindex` on affected devices
    ///
    /// (The Session 2026-06-09 unscoped-FTS5-delete fix did **not** bump this version:
    /// rows lost to that bug are restored by the FTS schema-version-4 migration's
    /// `rebuildSearchIndexFromCache()`, which rebuilds from the unaffected
    /// `document_cache` without the full XML re-parse a date-version bump would force.)
    ///
    /// - Version 7: real-corpus TEI vocabulary fix (Session 2026-06-10). Editorial
    ///   notes are detected via `subtype="editorial-note"` (the `type="editorialNote"`
    ///   encoding never occurs in the published corpus), front/back-matter sections
    ///   (`type="section"` + `subtype`) are promoted to searchable quasi-documents
    ///   with `is_front_matter` set, archival sources extraction recognises the real
    ///   sources section, and `volume_structures` rows gain the full front/back
    ///   hierarchy. All of these live in parse output, so a full XML re-parse is
    ///   required to repopulate them.
    /// - Version 8: terms-list definitions fix (Session 162 link audit). The terms
    ///   parser split item text on ":" but FRUS separates term and definition with
    ///   a comma after the nested `<term>` element, so every glossary definition in
    ///   the corpus was stored as NULL. A full re-parse repopulates the `terms`
    ///   table's `definition` column so tapped term links show real definitions.
    /// - Version 9: date precision/certainty (Session 163). `document_dates` gains
    ///   `date_precision` (day/month/year — the original TEI granularity before the
    ///   `date_iso` value is padded to a full day) and `date_certainty`
    ///   (exact/range/approximate/textOnly). Both are computed during the XML parse by
    ///   `extractDateMetadata`, so a full re-parse is required to populate them. Lets
    ///   date features render year-only documents honestly instead of as January 1.
    /// - Version 10: canonical document numbers (Session 163). `document_number` is now
    ///   taken from the document div's `@n` (the history.state.gov document number, present
    ///   for every document including early-volume ones unnumbered in print) rather than
    ///   parsed from the `<head>` leading text, which yielded nothing for unnumbered heads
    ///   and left those citations without a number. A re-parse repopulates
    ///   `document_cache.document_number` corpus-wide so citations resolve to HSG.
    /// - Version 11: person role/era metadata (person rollup Phase 1). The persons list carries
    ///   role text (and sometimes an active-year range) after each name; the parser previously
    ///   discarded the trailing text. A re-parse repopulates `persons.role`/`start_year`/`end_year`
    ///   so the People browser can show a `role · era` subtitle.
    /// - Version 12: front-matter sources outline + structure-title whitespace (Session
    ///   2026-07-02). The Session 170 `volume_sources` rewrite (prose + collection-outline
    ///   model: `kind`/`depth`/`is_heading`, PK → `(volume_id, sort_order)`) migrates by
    ///   dropping any pre-170 table, so already-indexed devices show an empty Sources
    ///   section until a re-parse repopulates it — the rewrite session omitted this bump,
    ///   so first launch never auto-reindexed. Additionally, `VolumeStructureParserDelegate`
    ///   now collapses interior whitespace in section titles at parse time (hard-wrapped
    ///   TEI `<head>` text previously carried embedded newlines into `structureJSON` and
    ///   the corpus browser's chapter/compilation rows), which only takes effect on re-parse.
    /// - Version 13: split-set person-ref normalisation (Session 2026-07-03, people-eval
    ///   finding E). `extractPersonRefs`/`collectDocumentRefs` previously stripped only a
    ///   *leading* `#` from `persName/@ref`, so split-set volumes whose body points at the
    ///   sibling part's persons list (`ref="frus1918Supp01v01#p_LR1"` inside
    ///   frus1918Supp01v02) stored the whole prefixed string in
    ///   `person_mentions.person_ref` — 6,486 mention rows across 9 volumes joined neither
    ///   `persons` nor `person_rollup_member` and were invisible to every rollup count and
    ///   "Find all mentions" result. Refs are now normalised to the bare fragment at parse
    ///   time (each part carries its own copy of the set's persons list, so the fragment
    ///   joins the mentioning volume's row). Same pass: Format B (colon-delimited) persons
    ///   list names collapse interior whitespace at parse time, matching Format A, so the
    ///   hardened `PersonListHeuristics` newline rejection can never discard a real person
    ///   whose name was hard-wrapped in the TEI source.
    /// - Version 14: head-nested source-note extraction (Source Explorer Phase 1,
    ///   Session 2026-07-03). `extractSourceNote` previously scanned top-level AST nodes
    ///   only, but every volume from 1955 on nests `<note type="source">` inside `<head>`,
    ///   so ~77,000 documents (1955–1991) stored no source note at all — coverage was
    ///   <1% for 1955+ vs 90–95% pre-1955, and zero `citation_era='structured'` rows
    ///   existed corpus-wide. The extractor now ports the frus-sources locator chain
    ///   (head/note/p/seg[@type="source"] → head/note[@type="source"] → top-level inline
    ///   note) and normalises the `[Source: …]` wrapper to `Source: …`. Same pass:
    ///   `extractHeader` excludes footnote children of `<head>` (headers no longer embed
    ///   the full source-note or head-footnote text), and `document_sources` gains a
    ///   `classification` column (sentence 2 of the note when it is classification
    ///   markings). A re-parse repopulates `document_cache.source_note`/`header` and
    ///   rebuilds `document_sources` corpus-wide.
    /// - Version 15: dual-encoding gate + recursive header cleanup (Source Explorer
    ///   Phase 1 review fixes, Session 2026-07-03). The version-14 head-first priority
    ///   dropped the real archival citation in 25 pre-1955 documents where a head-nested
    ///   editorial remark ("Source text indicates …") co-occurs with a top-level
    ///   decimal/lot citation (frus1949v01, frus1952-54v01p2/v03/v05p1) — the remark won,
    ///   `citation_era` degraded to `unrecognized`, and the lot/decimal archival-neighbor
    ///   keys were lost. `extractSourceNote` now defers a non-`Source:`-prefixed
    ///   whole-note head candidate until top-level notes have been consulted. Same pass:
    ///   `extractHeader` strips `.footnote` *descendants* (not just direct children), so
    ///   the 68 titles with a footnote nested inside `<hi>`/`<persName>`/`<p>` markup
    ///   (frus1914Supp, frus1952-54v13p1, …) no longer embed footnote text. A re-parse
    ///   repopulates `document_cache.source_note`/`header` and `document_sources` for the
    ///   affected documents.
    /// - Version 16: era-aware SourceNoteParser v2 + `lot_file_norm` (Source Explorer
    ///   Phase 2, Session 2026-07-03). The parser grammar now recognizes decimal refs
    ///   with word/office infixes (`893.51 Manchuria/49`, `740.00112 European War
    ///   1939/6363`, `396.1 GE/7–854`), Paris Peace Conference decimals (RG 256),
    ///   `File No.` punctuation variants, loose lot styles (lowercase/comma, en/em-dash,
    ///   lot-leading), presidential-library and manuscript-repository lead notes
    ///   without the `Source:` prefix, named file series (new `.namedFileSeries` case →
    ///   `citation_era='named_series'`), 1961–1963 abstract notes with trailing
    ///   citations, and Public Papers print citations — corpus-wide unrecognized rate
    ///   drops 24.3% → 2.8% on the citations.csv eval corpus. `document_sources` gains
    ///   a `lot_file_norm` column (canonical compact lot key, e.g. "64D199") written at
    ///   parse time. A reindex rebuilds `document_sources` with the v2 classifications
    ///   and normalized lot keys.
    /// - Version 17: SourceNoteParser v2 adversarial-review fixes (Source Explorer
    ///   Phase 2, Session 2026-07-03). Colon-styled inline lots cut at the first `:`
    ///   (and trailing `)` stripped) so `lot_file`/`lot_file_norm` store the compact
    ///   key (`M88`) instead of the colon chain (1,024 corpus rows); abstract notes
    ///   whose summary fits the named-series shape now route to the concrete CIA/NARA
    ///   citation in their tail; FRC-derived record groups no longer read parenthetical
    ///   secondary-copy remarks, and "Nixon Presidential Materials" notes classify as
    ///   their own presidential-library identity instead of `citation_era='foreign'`
    ///   junk (~7k rows); bare `File <number>` citations keep dotted decimals intact.
    ///   A reindex rebuilds `document_sources` with the corrected keys.
    /// - Version 18: front-matter keying, inheritance, and normalized keys (Source
    ///   Explorer Phase 3 step 1, Session 2026-07-03). 85.6% of front-matter source
    ///   items carried no usable match key. `SourcesParserDelegate` now (1) extracts
    ///   lots with the corpus-wide grammar shared with the document side
    ///   (`SourceNoteParser.firstLotReference` — F/W/M designators, en/em-dash and
    ///   run-together forms, `Lot File(s)` infix; the old D-only regex missed 507
    ///   items containing "Lot" and keyed junk like `"Files 74 D 131"`); (2) inherits
    ///   record group / repository from ancestor outline headings down the tree;
    ///   (3) writes normalized keys — `volume_sources.lot_file_norm` (same compact
    ///   form as `document_sources.lot_file_norm`) and `volume_sources.decimal_class`
    ///   (subject-numeric / decimal class-leaf location, doc-side verbatim form);
    ///   (4) gates the junk-prone series-name heuristic (bad captures store nil);
    ///   (5) introduces `kind='bibliography'` for `listofworks` rows — an encoding
    ///   later found unused by the corpus (see Version 20, which detects the real
    ///   published-works encodings). The table is
    ///   dropped and recreated when the new columns are missing; a reindex repopulates
    ///   `volume_sources` corpus-wide with the new keys. The shared lot grammar also
    ///   lets loose document notes match `Lot File 57 D 577` styles, refining some
    ///   `document_sources` classifications on re-parse.
    /// - Version 19: decimal / subject-numeric class keys, end-to-end (Source Explorer
    ///   Phase 3 verification, Session 2026-07-03). The 13-volume real-TEI
    ///   verification sample keyed **zero** class leaves and the doc side had nothing
    ///   to match them against: (1) front-matter `classLeafKey` only tried the
    ///   after-final-colon segment, but the dominant real shapes lead with the class
    ///   (`POL 3 UAR: Arab unity`) or list several (`611.80; 611.86; …: subject`) —
    ///   both now keyed via the shared `SourceNoteParser.decimalClassKey` gate;
    ///   (2) `document_sources` gains a `decimal_class` column (indexed) storing the
    ///   canonical class location for central-files-shaped citations — narrative
    ///   decimal rows (`Central Files, 788.5/9–1361` → `788.5`), subject-numeric
    ///   `structured` rows (`RG 59, Central Files 1967–69, POL 27 ARAB-ISR` →
    ///   `POL 27 ARAB-ISR`, previously dropped entirely), and CFPF rows;
    ///   (3) both sides canonicalize Unicode dashes to the ASCII hyphen — TEI front
    ///   matter writes `POL 27 ARAB–ISR` (en-dash) while document notes carry
    ///   `POL 27 ARAB-ISR` (hyphen), so the step-1 "verbatim" storage could never
    ///   match. Both tables drop and recreate on the missing column; a reindex
    ///   repopulates them corpus-wide.
    /// - Version 20: Source Explorer Phase 3 adversarial-review fixes
    ///   (Session 2026-07-03). (1) The bibliography exclusion is detected from the
    ///   encodings the corpus actually uses — the Version-18 `listofworks` trigger
    ///   matched **zero** of the 694 mirrored volumes, so the audit's ~2,600
    ///   masquerading published-works rows were still keyed `item`:
    ///   `SourcesParserDelegate` now recognizes `Published Sources` pseudo-heading
    ///   paragraphs inside ordinary sources divs (~3,000 items across ~160 volumes,
    ///   plus p-encoded periodical citations) and published-sources section heads
    ///   (frus1969-76v34/v36), marking their rows `kind='bibliography'`.
    ///   (2) The shared class gate rejects run-together record-group /
    ///   records-center / numbered-issuance identifiers (`RG59`, `NYFRC 84-84-002`,
    ///   `NSDM 93`, `PL 480`, PRC accessions) that previously stored junk
    ///   `decimal_class` keys — on the doc side `RG59` also masked the row's
    ///   genuine class. (3) The doc-side class scan is bounded to the citation
    ///   sentence — the first sentence naming the central files (which keeps the
    ///   1961–1963 abstract notes' tail citations), else sentence 1 — so remark
    ///   sentences (`… For the full text of NSDM 91, see …`, ibid. secondary
    ///   references) can never contribute a class key. (4) The shared lot grammar accepts
    ///   plural `Lots …` leads (83 front-matter rows) and the spaced letter suffix
    ///   `Lot 61 D 282 A` (norm parity with the legacy doc-side captures).
    ///   Parse output changes on both tables; a reindex repopulates them.
    ///
    ///   v22 — Session 7 review / #240B: `resolvePageBasedCrossReferences` now enforces its
    ///   documented same-volume-only contract (`target_volume_id IS NULL`). v21 and earlier
    ///   resolved CROSS-volume page refs against the SOURCE volume's pagination, fabricating
    ///   up to ~44K wrong document-level edges corpus-wide (target volume kept, target
    ///   document replaced with a source-volume doc id) — polluting ego graphs, the heat
    ///   matrix, in-degree/PageRank, and defeating the #240B `is_broken` matching for the
    ///   13 broken cross-volume page records whose page number exists in the source volume.
    ///   The bump forces the reindex that rebuilds `cross_references` cleanly; the broken-ref
    ///   marking then re-applies via `markBrokenCrossReferences` during the reindex.
    /// - v23 — #353 / N-1a: three anchored rules in `decimalClassLocation(inCitation:)` give a
    ///   `decimal_class` to **59,669 of the 71,644** decimal rows that had none — the `File No.`
    ///   label the early volumes use, a class followed by prose inside one segment, and the
    ///   dash-alpha suffix (`751G.5-MSP`, `396.1-GE`). `decimal_class` feeds
    ///   `relatedByDecimalClass`, so those documents were absent from the Archival Neighbors
    ///   axis entirely. Verified additive: over all 122,033 rows that already had a class, the
    ///   new parser returns the identical value for every one — 0 changed, 0 lost.
    /// - v24 — #353 / N-1a follow-up: the decimal file writes a class suffix with a space as
    ///   readily as with a dash (`751G.5 MSP` vs `751G.5–MSP`), and the space form is the more
    ///   common — 4,851 notes to 2,029. v23's leading-token rule stored those as the *bare*
    ///   class, merging them with the unrelated unsuffixed file. **5,204 documents** are keyed
    ///   correctly by the fix. Symmetry costs a little more: the dash form absorbed a suffix
///   even when a qualifier followed (`740.00119–EW (39)`) while the space form dropped it, so
///   teaching the space form to match takes the total to **7,419 documents**. Measured against
///   the v23 index: 7,419 corrected, 0 changed otherwise, 0 lost.
    /// - v25 — #353 / N-1b: three residual citation families, **2,996 documents** across 328
    ///   classes. The decimal file's dotless top-level classes (`032`, `320`, `330` — 1,565
    ///   documents over 46 codes, accepted only where a class belongs so the Numerical File's
    ///   `File No. 3767/5` case numbers stay refused); a space after the class dot
    ///   (`501. BC` → `501.BC`, joining the established `501.BB` family); and a dash *and* a
    ///   space (`751G.5– MSP`), the third spelling of the suffix #688 unified. Measured
    ///   against the v24 index: 3,333 newly classed, 1 corrected (840.50. UNRRA joins the 145
///   notes spelling the same class 840.50 UNRRA), 0 lost.
    /// - v26 — #353 / §3.5: a lot number named *outside* the note's own citation clause was
    ///   flipping the whole note onto the lot route. FRUS routinely names a second archive
    ///   later in a note — where another copy lives, or where a document the remark cites
    ///   lives — and three strategies (`tryInlineLotFile`, `tryNarrativeLotFile`,
    ///   `tryLooseLotFile`) each scanned the entire note and took the first `Lot` they found.
    ///   `SourceNoteParser.lotClaimScope(_:)` now narrows the search to the leading sentence
    ///   **when that sentence has already named a competing repository** — a presidential
    ///   library, a manuscript repository, or the central files. Measured against the v25
    ///   index: **581 corrected** (261 → centralFiles, 209 → presidentialLibrary, 78 →
    ///   naraCollection, 28 → cfpfFile, 5 → ciaCollection), **0 lost** — every one moved to a
    ///   *more* specific repository and none fell to `unrecognized`. The scope stays the whole
    ///   note otherwise, because the 1961–1963 abstract notes are genuinely lot files and put
    ///   their citation in the tail; a blanket "sentence 1 only" rule would have broken 1,006
    ///   correct classifications.
    /// - v27 — #353 §3.2/§3.3: the library strategy matched a repository keyword anywhere in a
    ///   note, so a *secondary copy* named in a parenthetical or a remark captured the whole
    ///   citation, and the extracted repository name swallowed everything before the keyword.
    ///   `tryPresidentialLibrary` now searches a body with parentheticals and secondary-copy
    ///   sentences removed, and takes the repository from the keyword's own segment. Measured
    ///   against the v26 index: **382 reclassified** (364 → centralFiles, 8 → namedFileSeries,
    ///   10 → unrecognized) and **457 repository names repaired** — from up to 150 characters
    ///   of abstract prose down to the name, which matters because that value is the archival
    ///   neighbour key and the catalogue query string. The `"Copy obtained from the … Library"`
    ///   idiom is deliberately kept: it asserts provenance rather than a duplicate.
    /// - v28 — #353: agency-held file series. FRUS cites `Agency, Series, Box N, Folder`
    ///   ("National Security Council, Carter Intelligence Files, Box 20, SCC Meetings"), and
    ///   `tryNarrativeNamedSeries` could not reach them: its patterns are anchored to the start
    ///   of the note and require the leading segment to END in Files/Papers/Records/Collection,
    ///   which an agency name does not. `tryAgencyFileSeries` runs LAST in the narrative
    ///   dispatch, so it claims only notes every other strategy declined. Measured against the
    ///   v27 index: **592 recovered** (504 NSC), all from `unrecognized`, **0 lost** — the
    ///   dispatch position guarantees the second number rather than merely reporting it.
    /// - v29 — #353: publication leads. The bare-note path recognised exactly one publication
    ///   (a one-off `hasPrefix("Treaty Series")`) while the `Source:` path recognised six, and
    ///   most publication notes are bare — measured, 331 of 527. Both paths now read one
    ///   `previouslyPublishedLeads` list, extended with `Reprinted from`, `Executive Agreement
    ///   Series`, `Documents on Disarmament`, `The Official Bulletin` and `Issued by the White
    ///   House as a press release`. Measured against the v28 index: **346 recovered** from
    ///   `unrecognized`, **0 lost**. `Unperfected Treaty No. A-10` is deliberately NOT a lead:
    ///   those are archival (NARA RG 11), not printed.
    public static let currentDateIndexVersion: Int = 29

    /// UserDefaults key under which the installed date-index version is persisted.
    public static let dateIndexVersionKey = "frusExplorer.dateIndexVersion"

    /// UserDefaults key holding the `generated` stamp of the broken-refs index last applied to the
    /// on-disk `cross_references.is_broken` flags. Gates the one-shot retroactive backfill so it
    /// re-runs only when the bundled index is refreshed. (Session 7 / #240B deliberately substitutes
    /// this idempotent UPDATE pass for a `currentDateIndexVersion` bump: the rows are unchanged — only
    /// a derived flag is set — so re-indexing the multi-GB corpus for a flag would be disproportionate.)
    public static let brokenRefsIndexAppliedKey = "frusExplorer.brokenRefsIndexApplied"

    /// Returns `true` if the on-disk date index was built with an older extraction
    /// strategy and volumes should be re-indexed to improve date accuracy.
    public nonisolated var needsDateReindex: Bool {
        let installed = UserDefaults.standard.integer(forKey: Self.dateIndexVersionKey)
        // `integer(forKey:)` returns 0 when the key is absent, which is < 2.
        return installed < Self.currentDateIndexVersion
    }

    /// Records that the date index has been rebuilt at the current schema version.
    /// Call this after a successful background re-index triggered by `needsDateReindex`.
    public func markDateReindexComplete() {
        UserDefaults.standard.set(Self.currentDateIndexVersion, forKey: Self.dateIndexVersionKey)
        logger.info("Date index marked at version \(Self.currentDateIndexVersion, privacy: .public)")
    }

    // MARK: - Person Rollup (Phase 0)

    /// Version of the materialised person rollup. Bump to force a rebuild on next consolidation.
    /// v2 (Phase 1): rollup carries role/start_year/end_year.
    /// v3 (Phase 2): membership comes from `PersonClusterer` (blocking + variant folding + era/role
    /// guardrails) and sub-threshold pairs land in `person_cluster_candidate`.
    /// v4 (Phase 3): user `PersonClusterOverride`s are applied as must-link/detach constraints.
    /// v5 (Phase 4): rollup carries `volume_count` (distinct volumes the cluster spans).
    /// v6 (Phase 5): clustering is keyed on the bundled OOH authority crosswalk where covered;
    /// rollup carries `authority_id`/`viaf_id` and the canonical name + birth/death years.
    /// v7 (audit fix): non-person artifacts (leading-bracket parenthetical fragments lifted out of
    /// the List-of-Persons prose, e.g. "(together with … advisers).") are purged from `persons`
    /// before consolidation, so already-indexed databases drop them from the rollup without a
    /// full reindex. New indexes never store them (`PersonListHeuristics` filters at parse time).
    /// v8 (people-eval audit, findings A–D — rollup rebuild only, no reindex):
    /// (A) differing authority ids are a cannot-link union-find constraint in `PersonClusterer`,
    ///     so an uncovered member can no longer transitively bridge two reconciled identities
    ///     (67 conflated rollups incl. Winston-Churchill-as-Clementine, Fidel-as-Raúl Castro);
    /// (B) `PersonClusterer.normalize` stops folding "Mrs." (wife ≠ husband) and captures
    ///     generational suffixes (jr/sr/ii/iii) as distinguishing fields (FDR ≠ FDR Jr.,
    ///     Herter Sr. ≠ Herter Jr.);
    /// (C) the cluster's canonical authority id/name is picked by majority-of-mentions with a
    ///     deterministic tiebreak (`majorityAuthorityId`) instead of `.first` input order;
    /// (D) the purge heuristic (`PersonListHeuristics.isLikelyPersonName`) also rejects
    ///     back-of-book index artifacts — names with standalone page-number runs
    ///     ("Churchill, 532", "Eden, 815–817"), embedded newlines, or >80 characters — the
    ///     671 digit-name frus1941-43 rows (746 rows, all 0 mentions) mis-parsed as persons.
    public static let currentPersonRollupVersion: Int = 8
    /// UserDefaults key under which the installed person-rollup version is persisted.
    public static let personRollupVersionKey = "frusExplorer.personRollupVersion"
    /// UserDefaults key holding the fingerprint of the override set the rollup was last built with,
    /// so a launch after corrections sync in from another device re-consolidates even when the
    /// version is unchanged. A content fingerprint (not a count) so a remove-plus-add that nets the
    /// same count — routine once undo exists — still triggers reconsolidation. (Supersedes the old
    /// `frusExplorer.personRollupOverrideCount` key; its absence on first launch forces one free
    /// reconsolidation that re-stamps this one.)
    public static let personRollupOverrideFingerprintKey = "frusExplorer.personRollupOverrideFingerprint"

    /// An order-independent, cross-device-stable fingerprint of the applied override set.
    ///
    /// Each override becomes a canonical string (a `merge` sorts its symmetric endpoint pair so the
    /// anchor order can't affect the hash); the strings are sorted and SHA-256-hashed. Deterministic
    /// regardless of SwiftData fetch order or CloudKit merge nondeterminism — two devices with the
    /// same logical corrections produce the same fingerprint and don't thrash reconsolidation.
    /// `Swift.Hasher` is deliberately NOT used (its per-process random seed would differ every launch).
    ///
    /// - Parameter overrides: The current override snapshots.
    /// - Returns: A 64-character lowercase hex digest (a fixed constant for the empty set).
    static func overrideFingerprint(_ overrides: [PersonClusterOverrideData]) -> String {
        let u = "\u{1F}"   // unit separator — cannot occur in a volumeId or TEI ref
        let canonical: [String] = overrides.map { o in
            switch o.kind {
            case .split:
                return "split\(u)\(o.volumeIdA)\(u)\(o.refA)"
            case .merge:
                let a = "\(o.volumeIdA)\(u)\(o.refA)"
                let b = "\(o.volumeIdB ?? "")\(u)\(o.refB ?? "")"
                let pair = [a, b].sorted()
                return "merge\(u)\(pair[0])\(u)\(pair[1])"
            }
        }
        let joined = canonical.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Rebuilds the materialised `person_rollup` / `person_rollup_member` tables if they are stale —
    /// the version was bumped, the rollup was never built, or the member set has drifted from the
    /// `persons` table (a volume was added or removed). The People browser reads the rollup directly
    /// because a live cross-corpus rollup over `person_mentions` is too slow on the full corpus.
    /// Cheap when up to date (two `COUNT(*)`s + a version check).
    public func consolidatePersonRollupIfNeeded(overrides: [PersonClusterOverrideData] = []) async throws {
        let installedVersion = UserDefaults.standard.integer(forKey: Self.personRollupVersionKey)
        let members = (try? auxScalarInt("SELECT COUNT(*) FROM person_rollup_member")) ?? -1
        let persons = (try? auxScalarInt("SELECT COUNT(*) FROM persons")) ?? 0
        let lastFingerprint = UserDefaults.standard.string(forKey: Self.personRollupOverrideFingerprintKey) ?? ""
        guard installedVersion < Self.currentPersonRollupVersion
            || members != persons
            || lastFingerprint != Self.overrideFingerprint(overrides) else { return }
        try consolidatePersonRollup(overrides: overrides)
        logger.info("Person rollup consolidated (\(persons, privacy: .public) member entries, \(overrides.count, privacy: .public) overrides).")
    }

    /// Rebuilds the person rollup from `persons` + `person_mentions` + `document_dates` using the
    /// `PersonClusterer` (Phase 2), applying the user's `PersonClusterOverride`s as constraints
    /// (Phase 3): `merge` → must-link, `split` → detach. The clusterer heals fragmentation (the same
    /// person under varying name strings across volumes) and prevents conflation (different people who
    /// share an exact name but are separated in time), honouring the under-merge bias: uncertain pairs
    /// stay split and are recorded in `person_cluster_candidate` as "possibly the same" suggestions.
    /// Mention counts are scoped by `(volume_id, ref)`. The table shape is unchanged from Phase 0/1.
    ///
    /// - Parameters:
    ///   - overrides: User corrections to apply on top of the algorithmic clustering.
    ///   - forceReload: When `false`, reuses the in-memory snapshot of cluster inputs from the last
    ///     load so a single correction re-applies fast (the expensive `persons`/mention-era load is
    ///     skipped). The gated launch/post-index path passes `true`.
    func consolidatePersonRollup(overrides: [PersonClusterOverrideData] = [], forceReload: Bool = true) throws {
        let inputs: [PersonClusterInput]
        if !forceReload, let cached = cachedClusterInputs {
            inputs = cached
        } else {
            // Drop pre-filter non-person artifacts from the derived `persons` table first, so the
            // rebuilt rollup excludes them and the `members == persons` drift invariant still holds
            // (every surviving `persons` row maps to exactly one rollup member). New indexes never
            // reach here with such rows — `PersonListHeuristics` filters them at parse time.
            let purged = try purgeNonPersonRows()
            if purged > 0 {
                logger.info("Purged \(purged, privacy: .public) non-person rows from persons before consolidation.")
            }
            inputs = try loadPersonClusterInputs()
            cachedClusterInputs = inputs
        }
        let (mustLink, detach) = Self.clusterConstraints(from: overrides)
        let output = PersonClusterer.cluster(inputs, mustLink: mustLink, detach: detach)

        try inTransaction {
            try auxExec("DELETE FROM person_rollup")
            try auxExec("DELETE FROM person_rollup_member")
            try auxExec("DELETE FROM person_cluster_candidate")

            // One rollup per cluster (rollup_id = clusterIndex + 1) with aggregated metadata + members.
            let rollupStmt = try auxPrepare("""
                INSERT INTO person_rollup
                    (rollup_id, namekey, canonical_name, description, role, start_year, end_year,
                     volume_count, authority_id, viaf_id, mention_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                """)
            let authIndex = authorityIndex()
            defer { sqlite3_finalize(rollupStmt) }
            let memberStmt = try auxPrepare(
                "INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES (?, ?, ?)")
            defer { sqlite3_finalize(memberStmt) }

            for (clusterIndex, memberIndices) in output.clusters.enumerated() {
                let rollupId = Int64(clusterIndex + 1)
                let members = memberIndices.map { inputs[$0] }
                let agg = Self.aggregateRollup(members)

                // Authority override (Phase 5): a covered cluster shares one canonical id (the
                // clusterer's v8 cannot-link makes a mixed cluster impossible except via a user
                // must-link override). Prefer the authoritative preferred name and birth/death
                // years, and carry the VIAF id, over the heuristic aggregate. v8 (C): the id is
                // picked by majority-of-mentions with a deterministic tiebreak — never `.first`,
                // which let input order decide whose name/VIAF a mixed cluster wore.
                let distinctIds = Set(members.compactMap(\.authorityId))
                if distinctIds.count > 1 {
                    logger.warning("Person rollup \(rollupId, privacy: .public) mixes \(distinctIds.count, privacy: .public) authority ids (user must-link?); picking majority-by-mentions.")
                }
                let authorityId = Self.majorityAuthorityId(for: members)
                let auth = authorityId.flatMap { authIndex?.entry(for: $0) }
                let canonicalName = (auth?.n).flatMap { $0.isEmpty ? nil : $0 } ?? agg.canonicalName

                sqlite3_bind_int64(rollupStmt, 1, rollupId)
                sqlite3_bind_text(rollupStmt, 2, canonicalName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(rollupStmt, 3, canonicalName, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(rollupStmt, 4, agg.description)
                auxBindOptional(rollupStmt, 5, agg.role)
                auxBindOptionalInt(rollupStmt, 6, auth?.b ?? agg.startYear)
                auxBindOptionalInt(rollupStmt, 7, auth?.d ?? agg.endYear)
                sqlite3_bind_int64(rollupStmt, 8, Int64(agg.volumeCount))
                auxBindOptionalInt(rollupStmt, 9, authorityId)
                auxBindOptional(rollupStmt, 10, auth?.v)
                try auxStep(rollupStmt)
                sqlite3_reset(rollupStmt)

                for m in members {
                    sqlite3_bind_text(memberStmt, 1, m.volumeId, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_bind_text(memberStmt, 2, m.ref, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_bind_int64(memberStmt, 3, rollupId)
                    try auxStep(memberStmt)
                    sqlite3_reset(memberStmt)
                }
            }

            // Candidate suggestions (cluster index → rollup_id is +1).
            if !output.candidates.isEmpty {
                let candStmt = try auxPrepare("""
                    INSERT OR IGNORE INTO person_cluster_candidate (rollup_id_a, rollup_id_b, reason)
                    VALUES (?, ?, ?)
                    """)
                defer { sqlite3_finalize(candStmt) }
                for c in output.candidates {
                    sqlite3_bind_int64(candStmt, 1, Int64(c.clusterA + 1))
                    sqlite3_bind_int64(candStmt, 2, Int64(c.clusterB + 1))
                    sqlite3_bind_text(candStmt, 3, c.reason, -1, SQLITE_TRANSIENT_IP)
                    try auxStep(candStmt)
                    sqlite3_reset(candStmt)
                }
            }

            // Mention counts: aggregate once into a keyed temp table, then update by PK lookup.
            try auxExec("CREATE TEMP TABLE IF NOT EXISTS _rollup_counts (rid INTEGER PRIMARY KEY, cnt INTEGER)")
            try auxExec("DELETE FROM _rollup_counts")
            try auxExec("""
                INSERT INTO _rollup_counts (rid, cnt)
                SELECT m.rollup_id, COUNT(DISTINCT pm.volume_id || '||' || pm.document_id)
                FROM person_rollup_member m
                JOIN person_mentions pm ON pm.volume_id = m.volume_id AND pm.person_ref = m.ref
                GROUP BY m.rollup_id
                """)
            try auxExec("""
                UPDATE person_rollup SET mention_count =
                    COALESCE((SELECT cnt FROM _rollup_counts WHERE rid = person_rollup.rollup_id), 0)
                """)
            try auxExec("DELETE FROM _rollup_counts")
        }

        // Record what this build reflects so the gated launch path knows when it is stale.
        UserDefaults.standard.set(Self.currentPersonRollupVersion, forKey: Self.personRollupVersionKey)
        UserDefaults.standard.set(Self.overrideFingerprint(overrides), forKey: Self.personRollupOverrideFingerprintKey)
        // One-time hygiene: drop the superseded count marker so it doesn't sit orphaned
        // in every upgraded install's defaults ("frusExplorer.personRollupOverrideCount").
        UserDefaults.standard.removeObject(forKey: "frusExplorer.personRollupOverrideCount")
    }

    /// Translates user `PersonClusterOverride` snapshots into clusterer constraints.
    ///
    /// An override whose anchor `(volumeId, ref)` is not among the loaded cluster inputs
    /// (its volume was removed from the index) is a **silent no-op**: the constraint is
    /// passed through and simply matches nothing. The override record itself is kept, so
    /// the correction reactivates automatically if that volume is indexed again (#243).
    private static func clusterConstraints(from overrides: [PersonClusterOverrideData])
        -> (mustLink: [(PersonClusterer.MemberKey, PersonClusterer.MemberKey)], detach: [PersonClusterer.MemberKey]) {
        var mustLink: [(PersonClusterer.MemberKey, PersonClusterer.MemberKey)] = []
        var detach: [PersonClusterer.MemberKey] = []
        for o in overrides {
            switch o.kind {
            case .merge:
                if let vb = o.volumeIdB, let rb = o.refB {
                    mustLink.append((PersonClusterer.MemberKey(volumeId: o.volumeIdA, ref: o.refA),
                                     PersonClusterer.MemberKey(volumeId: vb, ref: rb)))
                }
            case .split:
                detach.append(PersonClusterer.MemberKey(volumeId: o.volumeIdA, ref: o.refA))
            }
        }
        return (mustLink, detach)
    }

    /// Deletes List-of-Persons artifacts that are not biographical records (leading-bracket
    /// parenthetical fragments, letterless strings, "See …" redirects) from the derived `persons`
    /// table, identified by `PersonListHeuristics.isLikelyPersonName`. Returns the number removed.
    ///
    /// Rows indexed after the parser gained the filter never match, so this is a one-time cleanup of
    /// databases built before it; deleting from the rebuildable `persons` index keeps the per-volume
    /// persons list and the cross-corpus rollup consistent and preserves the consolidation's
    /// `members == persons` drift invariant. Deletes by `rowid` so each match is removed precisely.
    private func purgeNonPersonRows() throws -> Int {
        var doomed: [Int64] = []
        let stmt = try auxPrepare("SELECT rowid, name FROM persons")
        defer { sqlite3_finalize(stmt) }
        while try auxStep(stmt) {
            let name = auxColumnString(stmt, 1) ?? ""
            if !PersonListHeuristics.isLikelyPersonName(name) {
                doomed.append(sqlite3_column_int64(stmt, 0))
            }
        }
        guard !doomed.isEmpty else { return 0 }
        let del = try auxPrepare("DELETE FROM persons WHERE rowid = ?")
        defer { sqlite3_finalize(del) }
        for rid in doomed {
            sqlite3_bind_int64(del, 1, rid)
            try auxStep(del)
            sqlite3_reset(del)
        }
        return doomed.count
    }

    /// Loads every `persons` row as a `PersonClusterInput`, joined to a per-`(volume_id, ref)`
    /// mention-era (min/max document year from `document_dates`). The mention era gives the clusterer
    /// an era signal even for the common case where the persons list carries no explicit years.
    private func loadPersonClusterInputs() throws -> [PersonClusterInput] {
        // Mention-derived era per (volume_id, ref). GLOB guards against malformed date strings.
        var mentionEra: [String: (Int, Int)] = [:]
        let eraStmt = try auxPrepare("""
            SELECT pm.volume_id, pm.person_ref,
                   MIN(CAST(substr(dd.date_iso, 1, 4) AS INTEGER)),
                   MAX(CAST(substr(CASE WHEN substr(dd.date_iso_max, 1, 4) GLOB '[12][0-9][0-9][0-9]'
                                        THEN dd.date_iso_max ELSE dd.date_iso END, 1, 4) AS INTEGER))
            FROM person_mentions pm
            JOIN document_dates dd ON dd.volume_id = pm.volume_id AND dd.document_id = pm.document_id
            WHERE substr(dd.date_iso, 1, 4) GLOB '[12][0-9][0-9][0-9]'
            GROUP BY pm.volume_id, pm.person_ref
            """)
        defer { sqlite3_finalize(eraStmt) }
        while try auxStep(eraStmt) {
            let vol = auxColumnString(eraStmt, 0) ?? ""
            let ref = auxColumnString(eraStmt, 1) ?? ""
            if let lo = auxColumnIntOptional(eraStmt, 2) {
                mentionEra["\(vol)||\(ref)"] = (lo, auxColumnIntOptional(eraStmt, 3) ?? lo)
            }
        }

        // Per-(volume_id, ref) document-mention counts, used by the v8 majority-of-mentions
        // authority pick (not a clustering signal). Separate from the era query above because
        // that one excludes undated mentions via its document_dates join.
        var mentionCounts: [String: Int] = [:]
        let cntStmt = try auxPrepare(
            "SELECT volume_id, person_ref, COUNT(*) FROM person_mentions GROUP BY volume_id, person_ref")
        defer { sqlite3_finalize(cntStmt) }
        while try auxStep(cntStmt) {
            let vol = auxColumnString(cntStmt, 0) ?? ""
            let ref = auxColumnString(cntStmt, 1) ?? ""
            mentionCounts["\(vol)||\(ref)"] = Int(sqlite3_column_int64(cntStmt, 2))
        }

        let authIndex = authorityIndex()
        var inputs: [PersonClusterInput] = []
        let pStmt = try auxPrepare("SELECT volume_id, ref, name, description, role, start_year, end_year FROM persons")
        defer { sqlite3_finalize(pStmt) }
        while try auxStep(pStmt) {
            let vol = auxColumnString(pStmt, 0) ?? ""
            let ref = auxColumnString(pStmt, 1) ?? ""
            let name = auxColumnString(pStmt, 2) ?? ""
            guard !name.isEmpty else { continue }
            let era = mentionEra["\(vol)||\(ref)"]
            inputs.append(PersonClusterInput(
                volumeId: vol, ref: ref, name: name,
                description: auxColumnString(pStmt, 3),
                role: auxColumnString(pStmt, 4),
                listStartYear: auxColumnIntOptional(pStmt, 5),
                listEndYear: auxColumnIntOptional(pStmt, 6),
                mentionStartYear: era?.0,
                mentionEndYear: era?.1,
                authorityId: authIndex?.canonicalId(volumeId: vol, ref: ref),
                mentionCount: mentionCounts["\(vol)||\(ref)"] ?? 0
            ))
        }
        return inputs
    }

    /// The canonical authority id a cluster should wear: the id whose covered members carry the
    /// most document mentions (majority-by-mentions), ties broken by the smaller id for
    /// determinism (rollup v8, people-eval finding C). Returns `nil` for a fully uncovered
    /// cluster. Mixed clusters are illegal after the v8 cannot-link constraint, but remain
    /// reachable through a user must-link override — this pick is the defensive path so input
    /// order can never decide whose name/VIAF the whole cluster displays.
    static func majorityAuthorityId(for members: [PersonClusterInput]) -> Int? {
        var mentionWeight: [Int: Int] = [:]
        for m in members {
            guard let id = m.authorityId else { continue }
            mentionWeight[id, default: 0] += m.mentionCount
        }
        return mentionWeight.min { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key < b.key
        }?.key
    }

    /// Aggregated rollup metadata for a cluster's members: the most complete name, the first
    /// available description/role, and the widest active span (min start … max end of effective years).
    private static func aggregateRollup(_ members: [PersonClusterInput]) -> RollupAggregate {
        // Canonical name: the most complete (longest); ties broken lexicographically for stability.
        let names: [String] = members.map(\.name)
        let canonical: String = names.min { (a: String, b: String) -> Bool in
            if a.count != b.count { return a.count > b.count }
            return a < b
        } ?? ""
        let description: String? = members.compactMap { (m: PersonClusterInput) -> String? in
            guard let d = m.description, !d.isEmpty else { return nil }
            return d
        }.min()
        let role: String? = members.compactMap { (m: PersonClusterInput) -> String? in
            guard let r = m.role, !r.isEmpty else { return nil }
            return r
        }.min()
        let starts: [Int] = members.compactMap(\.effectiveStartYear)
        let ends: [Int] = members.compactMap(\.effectiveEndYear)
        let namekey = canonical.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let volumeCount = Set(members.map(\.volumeId)).count
        return RollupAggregate(
            canonicalName: canonical,
            namekey: namekey,
            description: description,
            role: role,
            startYear: starts.min(),
            endYear: ends.max(),
            volumeCount: volumeCount
        )
    }

    // MARK: - Logger

    private let logger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "IndexingPipeline")

    // MARK: - Dependencies (let — accessible from nonisolated methods)

    private let fts5Store: FTS5Store
    private let volumesDirectory: URL
    private let stateTracker: IndexingStateTracker?

    // MARK: - Person rollup cache (Phase 3)

    /// In-memory snapshot of the last-loaded cluster inputs, so a user correction can re-apply the
    /// clusterer (with the new constraints) without repeating the expensive `persons`/mention-era
    /// load. Invalidated whenever a volume is indexed or removed.
    private var cachedClusterInputs: [PersonClusterInput]?

    /// The bundled person-authority crosswalk (Phase 5), loaded lazily on first consolidation. The
    /// double optional distinguishes "not yet loaded" (`nil`) from "loaded, absent" (`.some(nil)`),
    /// so a missing bundle resource is only looked up once. Injectable for tests.
    private var loadedAuthorityIndex: PersonAuthorityIndex??

    /// The authority index, loading it from the app bundle on first use (cached).
    func authorityIndex() -> PersonAuthorityIndex? {
        if let cached = loadedAuthorityIndex { return cached }
        let loaded = PersonAuthorityIndex.loadBundled()
        loadedAuthorityIndex = .some(loaded)
        return loaded
    }

    /// Injects an authority index for tests (the unit-test bundle has no bundled JSON).
    /// Invalidates the cluster-input cache so the next consolidation re-resolves canonical ids.
    func setAuthorityIndexForTesting(_ index: PersonAuthorityIndex?) {
        loadedAuthorityIndex = .some(index)
        cachedClusterInputs = nil
    }

    // MARK: - Auxiliary SQLite connection

    nonisolated(unsafe) private var auxDb: OpaquePointer?

    /// Pre-prepared INSERT statement for `document_cache` — the hottest write
    /// path (called once per document in the co-batch loop). Prepared once after
    /// schema setup and reused across all volumes, avoiding `sqlite3_prepare_v2`
    /// overhead on every `storeIndexData` call (#7).
    nonisolated(unsafe) private var preparedCacheInsert: OpaquePointer? = nil
    private let databaseURL: URL

    // MARK: - Progress stream (volume-level, consumed by ReindexView)

    private let progressContinuation: AsyncStream<IndexingProgress>.Continuation
    private let _progress: AsyncStream<IndexingProgress>

    /// Yields `IndexingProgress` events during and after indexing operations.
    public nonisolated var progress: AsyncStream<IndexingProgress> { _progress }

    // MARK: - Fine-grained progress stream (per-document, consumed by IndexingCapsule on iOS)

    private let progressUpdateContinuation: AsyncStream<IndexingProgressUpdate>.Continuation
    private let _progressStream: AsyncStream<IndexingProgressUpdate>

    /// Yields `IndexingProgressUpdate` events at each batch boundary and stage transition.
    ///
    /// Consumers receive per-document throughput and stage information suitable for
    /// an inline progress capsule. The stream uses `.bufferingNewest(100)` so that fast
    /// macOS indexing runs do not drop intermediate updates before the MainActor consumer
    /// is scheduled. AppState applies a 100 ms clock-based throttle on the consumer side
    /// to limit SwiftUI re-render frequency.
    public nonisolated var progressStream: AsyncStream<IndexingProgressUpdate> { _progressStream }

    // MARK: - Metadata discovery stream (one event per volume, after parse completes)

    private let metadataContinuation: AsyncStream<VolumeMetadataDiscovered>.Continuation
    private let _metadataStream: AsyncStream<VolumeMetadataDiscovered>

    /// Yields one `VolumeMetadataDiscovered` event per indexed volume, emitted immediately
    /// after the XML parse phase completes and before any storage batches begin.
    ///
    /// Consumers can use the aggregate counts (persons, dates, cross-references) to enrich
    /// progress displays without waiting for the full write phase to finish.
    public nonisolated var metadataStream: AsyncStream<VolumeMetadataDiscovered> { _metadataStream }

    // MARK: - Per-volume throughput tracking

    private var volumeIndexingStartTime: Date?
    private var volumeDocumentsProcessed: Int = 0

    // MARK: - Initialisation

    /// Creates an `IndexingPipeline`.
    ///
    /// Opens a SQLite connection to `databaseURL` for the auxiliary tables (which share
    /// the same database file as `FTS5Store`). Creates all auxiliary tables if absent.
    ///
    /// - Parameters:
    ///   - fts5Store: The shared FTS5 store. Must use the same `databaseURL`.
    ///   - databaseURL: Path to the shared SQLite database file.
    ///   - volumesDirectory: Directory containing downloaded volume XML files.
    ///   - stateTracker: Optional tracker for interrupted-indexing sentinel persistence.
    ///   - concurrencyLimit: Maximum simultaneous XML parsers. Default 4.
    public init(
        fts5Store: FTS5Store,
        databaseURL: URL,
        volumesDirectory: URL,
        stateTracker: IndexingStateTracker? = nil,
        concurrencyLimit: Int = 4
    ) throws {
        self.fts5Store = fts5Store
        self.databaseURL = databaseURL
        self.volumesDirectory = volumesDirectory
        self.stateTracker = stateTracker
        self.concurrencyLimit = concurrencyLimit

        let (stream, continuation) = AsyncStream.makeStream(of: IndexingProgress.self)
        _progress = stream
        progressContinuation = continuation

        let (updateStream, updateContinuation) = AsyncStream.makeStream(
            of: IndexingProgressUpdate.self,
            bufferingPolicy: .bufferingNewest(100)
        )
        _progressStream = updateStream
        progressUpdateContinuation = updateContinuation

        let (metaStream, metaContinuation) = AsyncStream.makeStream(
            of: VolumeMetadataDiscovered.self,
            bufferingPolicy: .bufferingNewest(10)
        )
        _metadataStream = metaStream
        metadataContinuation = metaContinuation

        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            databaseURL.path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw IndexingError.databaseOpenFailed(message: msg)
        }
        try Self.setupDatabase(h)
        Self.registerExactWordFunction(h)
        auxDb = h

        // Pre-prepare the document_cache UPSERT once after schema setup so every
        // call to auxInsertDocumentCache reuses the compiled statement (#7).
        var cacheStmt: OpaquePointer?
        if sqlite3_prepare_v2(h, Self.documentCacheUpsertSQL, -1, &cacheStmt, nil) == SQLITE_OK {
            preparedCacheInsert = cacheStmt
        }

        // Register for iOS memory-pressure notifications so we can reduce batch size
        // before the OS terminates the process. The observer fires on the main thread;
        // we hop to the actor via an unstructured Task so isolation is maintained.
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.reduceForMemoryPressure() }
        }
        #endif

        logger.info("Initialised. volumesDir=\(volumesDirectory.path, privacy: .public)")
    }

    deinit {
        progressContinuation.finish()
        progressUpdateContinuation.finish()
        metadataContinuation.finish()
        if let stmt = preparedCacheInsert { sqlite3_finalize(stmt) }
        if let db = auxDb { sqlite3_close_v2(db) }
    }

    // MARK: - Public API

    /// Indexes a single downloaded volume by ID.
    ///
    /// Parses the volume XML, inserts FTS5 documents, populates all auxiliary tables,
    /// and runs `optimize()` once to merge FTS5 b-tree segments.
    ///
    /// - Throws: `IndexingError.volumeNotFound` if the XML file is absent.
    public func indexVolume(_ volumeId: String) async throws {
        cachedClusterInputs = nil   // persons/mentions about to change — drop the rollup input cache
        let url = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("indexVolume: file not found for \(volumeId, privacy: .public)")
            throw IndexingError.volumeNotFound(volumeId: volumeId)
        }
        await stateTracker?.markStarted(volumeId: volumeId)
        emit(.indexing(volumeId: volumeId, current: 0, total: 1))
        volumeIndexingStartTime = Date()
        volumeDocumentsProcessed = 0

        logger.info("indexVolume: starting \(volumeId, privacy: .public)")
        let parseStart = Date()

        emitUpdate(IndexingProgressUpdate(
            volumeId: volumeId, stage: .reading,
            completedDocuments: 0, totalDocuments: 0, docsPerSecond: 0
        ))
        let data = try await parseAndExtract(volumeId: volumeId, url: url)
        let parseElapsed = Date().timeIntervalSince(parseStart)
        logger.info("indexVolume: \(volumeId, privacy: .public) parsed \(data.documentCache.count, privacy: .public) docs in \(String(format: "%.1f", parseElapsed), privacy: .public)s")

        // Emit a second .reading update now that the total document count is known.
        // This lets progress bars render a determinate state before storage begins.
        emitUpdate(IndexingProgressUpdate(
            volumeId: volumeId, stage: .reading,
            completedDocuments: 0, totalDocuments: data.documentCache.count, docsPerSecond: 0
        ))
        emitMetadata(buildMetadata(from: data))

        let storeStart = Date()
        try await storeIndexData(data)
        let storeElapsed = Date().timeIntervalSince(storeStart)
        logger.info("indexVolume: \(volumeId, privacy: .public) stored in \(String(format: "%.1f", storeElapsed), privacy: .public)s")

        // Bounded incremental merge after a single-volume index. A full optimize()
        // here is O(total index size) — on a near-complete corpus every additional
        // downloaded volume would trigger a multi-gigabyte segment merge. The FTS5
        // 'merge' command with a positive page quota performs a fixed amount of
        // b-tree consolidation and stops; automerge handles the rest over time.
        // Full optimize() still runs once at the end of indexAllVolumes.
        let optStart = Date()
        try incrementalMergeFTS()
        let optElapsed = Date().timeIntervalSince(optStart)
        logger.info("indexVolume: \(volumeId, privacy: .public) incremental merge in \(String(format: "%.1f", optElapsed), privacy: .public)s")

        submitSpotlightItems(for: data)
        await stateTracker?.markCompleted(volumeId: volumeId)
        emit(.completed(volumeCount: 1, documentCount: data.documentCache.count))
        emitUpdate(IndexingProgressUpdate(
            volumeId: volumeId, stage: .complete,
            completedDocuments: data.documentCache.count,
            totalDocuments: data.documentCache.count,
            docsPerSecond: currentDocsPerSecond(forTotal: data.documentCache.count)
        ))
        let totalElapsed = Date().timeIntervalSince(volumeIndexingStartTime ?? Date())
        logger.info("indexVolume: \(volumeId, privacy: .public) complete — \(data.documentCache.count, privacy: .public) docs, total \(String(format: "%.1f", totalElapsed), privacy: .public)s")
        volumeIndexingStartTime = nil
        volumeDocumentsProcessed = 0
    }

    /// Indexes all downloaded volumes concurrently.
    ///
    /// Uses a sliding-window `TaskGroup` limited to `concurrencyLimit` concurrent
    /// XML parsers. Storage is serialised through the actor after each parse completes.
    ///
    /// Per-volume errors are caught and emitted as `.failed` progress events so that
    /// a single corrupt or unreadable XML file does not abort the entire batch. All
    /// remaining volumes continue to be indexed regardless of individual failures.
    ///
    /// `optimize()` is called exactly **once** after all volumes are stored, not after
    /// each volume. This is essential for performance: calling optimize after every
    /// volume is O(n²) on total index size and would take hours on the full corpus.
    public func indexAllVolumes() async throws {
        let files = Self.findDownloadedVolumes(in: volumesDirectory)
        guard !files.isEmpty else {
            emit(.completed(volumeCount: 0, documentCount: 0))
            return
        }

        let total = files.count
        var completedVolumes = 0
        var failedVolumes = 0
        var totalDocuments = 0
        let batchStart = Date()

        logger.info("indexAllVolumes: starting \(total, privacy: .public) volumes (concurrency=\(self.effectiveConcurrencyLimit, privacy: .public))")
        emit(.indexing(volumeId: files[0].volumeId, current: 0, total: total))

        // Use a non-throwing task group so that a single volume failure does not
        // cancel the entire batch. Each task returns a (volumeId, Result) tuple so
        // that the volumeId is available even when parseAndExtract throws (the prior
        // approach tried to recover it from the error type, which was always "unknown"
        // because parseAndExtract never throws IndexingError.volumeNotFound).
        await withTaskGroup(of: (String, Result<VolumeIndexData, Error>).self) { group in
            var iterator = files.makeIterator()

            // Seed the initial window.
            // On iOS effectiveConcurrencyLimit == 1, keeping only one volume's parsed
            // data in memory at a time; on macOS the caller-supplied concurrencyLimit
            // is used for throughput.
            for _ in 0..<min(effectiveConcurrencyLimit, total) {
                if let file = iterator.next() {
                    await stateTracker?.markStarted(volumeId: file.volumeId)
                    group.addTask { [self] in
                        do {
                            let data = try await self.parseAndExtract(volumeId: file.volumeId, url: file.url)
                            return (file.volumeId, .success(data))
                        } catch {
                            return (file.volumeId, .failure(error))
                        }
                    }
                }
            }

            // Process results and slide the window forward.
            for await (taskVolumeId, result) in group {
                switch result {
                case .success(let data):
                    // Emit a .reading update now that the total document count is known.
                    // This lets progress bars render a determinate state before storage
                    // begins and matches the behaviour of indexVolume().
                    emitUpdate(IndexingProgressUpdate(
                        volumeId: data.volumeId, stage: .reading,
                        completedDocuments: 0, totalDocuments: data.documentCache.count,
                        docsPerSecond: 0
                    ))
                    // Emit metadata so AppState.lastDiscoveredMetadata is populated and
                    // the status-bar completion summary shows real counts after indexing.
                    emitMetadata(buildMetadata(from: data))
                    // Reset per-volume throughput tracking. Without this, currentDocsPerSecond()
                    // always returns 0 during bulk indexing (volumeIndexingStartTime was never
                    // set), which meant docsPerSecond was always 0 in every progress update and
                    // the ETA shown in the queue panel was permanently nil.
                    volumeIndexingStartTime = Date()
                    volumeDocumentsProcessed = 0

                    let storeStart = Date()
                    do {
                        try await storeIndexData(data)
                        let storeElapsed = Date().timeIntervalSince(storeStart)
                        volumeIndexingStartTime = nil
                        volumeDocumentsProcessed = 0
                        await stateTracker?.markCompleted(volumeId: data.volumeId)
                        completedVolumes += 1
                        totalDocuments += data.documentCache.count
                        // Snapshot mutable counters before use in emit/log to satisfy Swift 6
                        // strict-concurrency: OSLog interpolation creates an autoclosure that
                        // would otherwise capture the mutable vars across an actor hop.
                        let progressNow = completedVolumes + failedVolumes
                        emit(.indexing(volumeId: data.volumeId, current: progressNow, total: total))
                        logger.info("indexAllVolumes: [\(progressNow, privacy: .public)/\(total, privacy: .public)] stored \(data.volumeId, privacy: .public) — \(data.documentCache.count, privacy: .public) docs in \(String(format: "%.1f", storeElapsed), privacy: .public)s")
                        // Checkpoint the WAL after each volume to prevent it growing
                        // unboundedly during a large batch (e.g. 552-volume full corpus).
                        // PASSIVE mode: flushes WAL pages to the main DB file without
                        // blocking active readers. Keeps frus.db's WAL file bounded
                        // (~50 MB peak instead of potential 1+ GB), reducing both peak
                        // disk usage and the cost of the final checkpoint at batch end.
                        try? auxExec("PRAGMA wal_checkpoint(PASSIVE)")
                    } catch {
                        volumeIndexingStartTime = nil
                        volumeDocumentsProcessed = 0
                        failedVolumes += 1
                        let failMsg = error.localizedDescription
                        emit(.failed(volumeId: data.volumeId, error: failMsg))
                        logger.error("indexAllVolumes: storeIndexData failed for \(data.volumeId, privacy: .public) — \(failMsg, privacy: .public)")
                    }
                case .failure(let error):
                    failedVolumes += 1
                    emit(.failed(volumeId: taskVolumeId, error: error.localizedDescription))
                    logger.error("indexAllVolumes: parseAndExtract failed for \(taskVolumeId, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                }

                if let file = iterator.next() {
                    await stateTracker?.markStarted(volumeId: file.volumeId)
                    group.addTask { [self] in
                        do {
                            let data = try await self.parseAndExtract(volumeId: file.volumeId, url: file.url)
                            return (file.volumeId, .success(data))
                        } catch {
                            return (file.volumeId, .failure(error))
                        }
                    }
                }
            }
        }

        // Run FTS5 optimize() ONCE for the whole batch. This merges all b-tree segments
        // written during the indexing run. With 552 volumes, this takes ~30–60s — but
        // calling it after each volume (the old behaviour) scaled to O(n²) overall and
        // was the root cause of 60+ minute indexing runs.
        //
        // IMPORTANT: emit `.optimizing` on progressStream BEFORE calling optimize() so the
        // UI can swap to a "Finalizing index…" indeterminate spinner instead of appearing
        // to stall on the last volume's final `.storingBatch` event for 30–60 s.
        emitUpdate(IndexingProgressUpdate(
            volumeId: "",
            stage: .optimizing,
            completedDocuments: totalDocuments,
            totalDocuments: totalDocuments,
            docsPerSecond: 0
        ))
        let optStart = Date()
        logger.info("indexAllVolumes: running optimize() after \(completedVolumes, privacy: .public) volumes")
        do {
            try await fts5Store.optimize()
            let optElapsed = Date().timeIntervalSince(optStart)
            logger.info("indexAllVolumes: optimize() complete in \(String(format: "%.1f", optElapsed), privacy: .public)s")
        } catch {
            logger.error("indexAllVolumes: optimize() failed — \(error.localizedDescription, privacy: .public)")
        }

        // Emit `.complete` on progressStream so AppState.connectIndexingProgress clears
        // currentIndexingProgress (and therefore indexingQueuePosition). Without this the
        // queue panel/banner remain pinned on the .optimizing state forever.
        emitUpdate(IndexingProgressUpdate(
            volumeId: "",
            stage: .complete,
            completedDocuments: totalDocuments,
            totalDocuments: totalDocuments,
            docsPerSecond: 0
        ))

        emit(.completed(volumeCount: completedVolumes, documentCount: totalDocuments))

        let totalElapsed = Date().timeIntervalSince(batchStart)
        logger.info("indexAllVolumes: complete — \(completedVolumes, privacy: .public) indexed, \(failedVolumes, privacy: .public) failed, \(totalDocuments, privacy: .public) docs, \(String(format: "%.0f", totalElapsed), privacy: .public)s elapsed")
    }

    /// Removes all index data for a volume from FTS5 and all auxiliary tables.
    ///
    /// Deleting the volume's `document_cache` rows fires the external-content sync
    /// triggers, which remove the matching rows from both `frus_documents` and
    /// `user_content` — scoped to exactly this volume's rowids. (The previous
    /// per-document FTS5 delete loop matched by `document_id` alone, which removed
    /// rows like `"d1"` from **every** indexed volume.)
    public func removeVolume(_ volumeId: String) async throws {
        cachedClusterInputs = nil   // persons/mentions about to change — drop the rollup input cache
        try auxDeleteVolume(volumeId)
        try? await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [volumeId])

        logger.info("removeVolume: removed FTS5 and auxiliary rows for \(volumeId, privacy: .public)")
    }

    /// Removes all indexed data for every volume in a single bulk operation.
    ///
    /// Issues one `DELETE` statement per table rather than iterating manifest entries,
    /// making it suitable for the app-reset path where iterating 500+ entries would
    /// cause the UI to hang for tens of seconds.
    ///
    /// The FTS5 sync triggers are dropped for the duration: per-row trigger
    /// maintenance across ~80k rows would take minutes, whereas the FTS5
    /// `delete-all` command plus an untriggered table delete is near-instant. The
    /// triggers are recreated before returning (also on failure).
    public func removeAllVolumesFromIndex() async throws {
        for sql in FTS5Schema.frusDocuments.dropTriggerSQL() { try auxExec(sql) }
        for sql in FTS5Schema.userContent.dropTriggerSQL() { try auxExec(sql) }
        defer {
            // Always restore the sync triggers, even if a delete failed mid-way.
            for sql in FTS5Schema.frusDocuments.externalContentTriggerSQL() { try? auxExec(sql) }
            for sql in FTS5Schema.userContent.externalContentTriggerSQL() { try? auxExec(sql) }
        }

        try auxExec("INSERT INTO frus_documents(frus_documents) VALUES('delete-all')")
        try auxExec("INSERT INTO user_content(user_content) VALUES('delete-all')")
        for table in ["cross_references", "page_ranges", "document_dates",
                      "document_cache", "person_mentions", "persons", "terms",
                      "document_sources", "volume_sources", "volume_structures"] {
            let stmt = try auxPrepare("DELETE FROM \(table)")
            defer { sqlite3_finalize(stmt) }
            try auxStep(stmt)
        }
        logger.info("removeAllVolumesFromIndex: complete")
    }

    /// Performs a bounded amount of FTS5 segment merging on both tables.
    ///
    /// `INSERT INTO t(t, rank) VALUES('merge', N)` with a positive N merges b-tree
    /// segments until roughly N pages have been written, then stops — unlike
    /// `optimize`, whose cost grows with total index size. Called after each
    /// single-volume index so segment counts stay low without ever blocking an
    /// interactive download on a whole-corpus merge.
    private func incrementalMergeFTS() throws {
        try auxExec("INSERT INTO frus_documents(frus_documents, rank) VALUES('merge', 64)")
        try auxExec("INSERT INTO user_content(user_content, rank) VALUES('merge', 64)")
    }

    /// Rebuilds both FTS5 tables from the populated `document_cache` content table.
    ///
    /// This is the fast migration path after an FTS5 schema rebuild: the content
    /// table already holds every indexed volume's original text, so the FTS5
    /// `rebuild` command re-derives the inverted index without re-parsing any XML.
    /// On a full corpus this takes tens of seconds versus the better part of an
    /// hour for `indexAllVolumes()`. The resulting index is fully merged, so no
    /// separate `optimize()` pass is needed.
    public func rebuildSearchIndexFromCache() async throws {
        emitUpdate(IndexingProgressUpdate(
            volumeId: "", stage: .optimizing,
            completedDocuments: 0, totalDocuments: 0, docsPerSecond: 0
        ))
        let start = Date()
        try auxExec("INSERT INTO frus_documents(frus_documents) VALUES('rebuild')")
        try auxExec("INSERT INTO user_content(user_content) VALUES('rebuild')")
        let elapsed = Date().timeIntervalSince(start)
        logger.info("rebuildSearchIndexFromCache: complete in \(String(format: "%.1f", elapsed), privacy: .public)s")
        emitUpdate(IndexingProgressUpdate(
            volumeId: "", stage: .complete,
            completedDocuments: 0, totalDocuments: 0, docsPerSecond: 0
        ))
    }

    /// How much of the index file is live data and how much is reclaimable free space.
    ///
    /// SQLite never returns pages to the filesystem on its own: deleted rows go on an internal
    /// freelist and are reused by later inserts, so the file never shrinks. `auto_vacuum` is off
    /// (the default), which is the right choice here — it would add a page-move cost to every
    /// delete — but it means the file size reported by the filesystem is not the size of the data.
    ///
    /// The gap is not small in practice. Reindexing deletes and reinserts every row for a volume,
    /// and nothing on that path compacts afterwards; a store that has been reindexed a few times
    /// can be more than half freelist. Measured on the author's 552-volume store, 2026-08-02:
    /// 6.29 GiB on disk, 2.75 GiB live, **3.53 GiB (56.2%) reclaimable**.
    ///
    /// - Returns: `nil` when the pragmas cannot be read; otherwise the three figures, where
    ///   `fileBytes == liveBytes + reclaimableBytes`.
    public func indexPageStatistics() throws -> IndexPageStatistics? {
        guard let pageSize = try? scalar("PRAGMA page_size"),
              let pageCount = try? scalar("PRAGMA page_count"),
              let freeCount = try? scalar("PRAGMA freelist_count"),
              pageSize > 0, pageCount > 0
        else { return nil }
        return IndexPageStatistics(
            fileBytes: pageCount * pageSize,
            reclaimableBytes: max(0, min(freeCount, pageCount)) * pageSize)
    }

    /// Runs `VACUUM` on the auxiliary SQLite database to reclaim pages freed by
    /// `removeVolume()` calls and shrink the `frus.db` file on disk.
    ///
    /// This is intentionally **not** called automatically after each `removeVolume()`.
    /// VACUUM requires a brief exclusive write lock and can take several seconds on a
    /// large database. Call it once after all desired removals are complete.
    ///
    /// The FTS5 store (`frus.db`) stores both the FTS5 tables and the auxiliary tables
    /// (cross_references, page_ranges, etc.) in the same file. A single VACUUM call
    /// on `auxDb` covers the entire file.
    ///
    /// ## Two things a caller must handle
    /// **Free space.** VACUUM writes a fully-packed copy of the database *before* replacing the
    /// original, so it transiently needs free space of roughly the live size — 2.75 GiB on a
    /// full-corpus store. Check before offering it; failing part-way is a worse experience than
    /// declining up front.
    ///
    /// **Open read-only connections.** VACUUM replaces the file underneath them, so the
    /// boot-once cross-reference / person-mention / page-range stores must be recreated
    /// afterwards (`AppState.refreshReadOnlyStores`) or they read empty for the rest of the
    /// session — the #275 trap. The bulk-removal path already does this; any new caller must too.
    ///
    /// Cost, measured on an FTS5 database of the same page size: **0.38 GiB of live data per
    /// second** on an M-series Mac, so about 7 s for a full-corpus store. Slower on device.
    public func vacuumIndex() async throws {
        let stmt = try auxPrepare("VACUUM")
        defer { sqlite3_finalize(stmt) }
        try auxStep(stmt)
        logger.info("vacuumIndex: complete")
    }

    /// Runs SQLite and FTS5 integrity diagnostics on `frus.db` (Session 154).
    ///
    /// Combines two checks:
    /// - `PRAGMA quick_check`, which scans the whole database file for
    ///   structural corruption (b-tree pages, schema, freelist).
    /// - `INSERT INTO <table>(<table>, rank) VALUES('integrity-check', 1)` on
    ///   both `frus_documents` and `user_content` — the `rank = 1` form of
    ///   FTS5's `integrity-check` command cross-checks each external-content
    ///   index against its `document_cache` content rows.
    ///
    /// - Returns: An empty array if no problems were found, or one descriptive
    ///   string per problem. The Storage settings pane shows an empty result as
    ///   "No problems found" and a non-empty result as an error list with a
    ///   suggestion to run "Delete Index & Rebuild".
    public func checkIndexIntegrity() async throws -> [String] {
        var problems: [String] = []

        let quickCheckStmt = try auxPrepare("PRAGMA quick_check")
        defer { sqlite3_finalize(quickCheckStmt) }
        while try auxStep(quickCheckStmt) {
            if let result = auxColumnString(quickCheckStmt, 0), result != "ok" {
                problems.append(result)
            }
        }

        for table in [FTS5Schema.frusDocuments.tableName, FTS5Schema.userContent.tableName] {
            do {
                try auxExec("INSERT INTO \(table)(\(table), rank) VALUES('integrity-check', 1)")
            } catch let IndexingError.sqliteError(_, message) {
                problems.append("\(table): \(message)")
            }
        }

        logger.info("checkIndexIntegrity: \(problems.count, privacy: .public) problem(s) found")
        return problems
    }

    /// Updates the summary text for a document in `document_cache`.
    ///
    /// The `user_content` FTS5 sync trigger re-indexes the row's user text in the
    /// same statement; the corpus index is untouched. Use this overload when the
    /// `GeneratedSummary` SwiftData model cannot safely cross actor boundaries
    /// (e.g. boot-time sync from a background `ModelContext`).
    func updateSummaryText(volumeId: String, documentId: String, responseText: String) async throws {
        try updateCacheColumns(
            volumeId: volumeId, documentId: documentId, label: "updateSummaryText",
            assignments: [("summary_text", responseText)]
        )
    }

    /// Updates research note content and user tag IDs for a document in `document_cache`.
    ///
    /// The `user_content` FTS5 sync trigger re-indexes the note text; `user_tag_ids`
    /// is `UNINDEXED` so its new value is visible to queries immediately without any
    /// index maintenance. Use this overload when the `ResearchNote` SwiftData model
    /// cannot safely cross actor boundaries (e.g. boot-time or post-download sync
    /// from a background `ModelContext`). Convert the note's `[UUID]` tag array to
    /// the space-separated string format before calling.
    func updateNoteText(
        volumeId: String,
        documentId: String,
        bodyText: String,
        userTagIds: String?
    ) async throws {
        try updateCacheColumns(
            volumeId: volumeId, documentId: documentId, label: "updateNoteText",
            assignments: [("note_text", bodyText), ("user_tag_ids", userTagIds)]
        )
    }

    /// Updates a document's note text and **nothing else**.
    ///
    /// Use this whenever the caller has no authoritative tag string to write. The
    /// `userTagIds:` overload sets `user_tag_ids` to whatever it is passed, so passing `nil`
    /// there *erases* the document's tags — and `user_tag_ids` is per **document**, not per
    /// note, so a note that carries no tags of its own would wipe tags contributed by
    /// another note on the same document. A new note has no tags to contribute, so it must
    /// not speak for the column at all.
    func updateNoteText(
        volumeId: String,
        documentId: String,
        bodyText: String
    ) async throws {
        try updateCacheColumns(
            volumeId: volumeId, documentId: documentId, label: "updateNoteText(textOnly)",
            assignments: [("note_text", bodyText)]
        )
    }

    /// Updates user-tag assignments for a document without touching the note or
    /// summary text.
    ///
    /// `user_tag_ids` is `UNINDEXED` in both FTS5 tables, so this is a plain row
    /// update with no index maintenance at all. Pass `nil` to remove all tags.
    ///
    /// - Parameters:
    ///   - volumeId:   Volume identifier (e.g. `"frus1969-76v10"`).
    ///   - documentId: Document identifier within the volume.
    ///   - userTagIds: Space-separated UUID strings, or `nil` to clear all tags.
    public func updateUserTagIds(
        volumeId: String,
        documentId: String,
        userTagIds: String?
    ) async throws {
        try updateCacheColumns(
            volumeId: volumeId, documentId: documentId, label: "updateUserTagIds",
            assignments: [("user_tag_ids", userTagIds)]
        )
    }

    /// Returns the current user-tag IDs stored for a document as an array of UUID strings.
    ///
    /// Reads `document_cache`. Returns an empty array if the document is not indexed
    /// or has no tag associations. The returned strings are `UUID.uuidString` values.
    ///
    /// Marked `async` so callers outside the actor (e.g. SwiftUI `.task` closures)
    /// can use `await` to hop onto the actor's executor without a warning.
    ///
    /// - Parameters:
    ///   - volumeId:   Volume identifier.
    ///   - documentId: Document identifier within the volume.
    public func currentUserTagIds(volumeId: String, documentId: String) async throws -> [String] {
        guard let cached = try fetchCache(volumeId: volumeId, documentId: documentId),
              let raw = cached.userTagIds, !raw.isEmpty else { return [] }
        return raw.split(separator: " ").map(String.init)
    }

    /// Updates the summary text for a document that is already in the index.
    ///
    /// Writes `summary.responseText` to `document_cache`; the `user_content` FTS5
    /// sync trigger makes the new text immediately searchable.
    func updateSummary(_ summary: GeneratedSummary) async throws {
        try await updateSummaryText(
            volumeId: summary.volumeId,
            documentId: summary.documentId,
            responseText: summary.responseText
        )
    }

    /// Updates the research note text for a document that is already in the index.
    ///
    /// Writes `note.bodyText` to `document_cache`; the `user_content` FTS5 sync
    /// trigger makes the new text immediately searchable.
    func updateResearchNote(_ note: ResearchNote) async throws {
        try updateCacheColumns(
            volumeId: note.volumeId, documentId: note.documentId, label: "updateResearchNote",
            assignments: [("note_text", note.bodyText)]
        )
    }

    // MARK: - Spotlight

    /// Submits CSSearchableItem records for all documents in `data` to the default
    /// Spotlight index. Errors are silently ignored — Spotlight is best-effort.
    private func submitSpotlightItems(for data: VolumeIndexData) {
        let items = data.documentCache.map { doc in
            Self.makeSearchableItem(
                volumeId: data.volumeId, documentId: doc.documentId,
                header: doc.header, bodyText: doc.bodyText
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Builds a single `CSSearchableItem` from cached document fields, shared by
    /// `submitSpotlightItems(for:)` and `rebuildSpotlightIndex()`.
    private static func makeSearchableItem(
        volumeId: String, documentId: String, header: String, bodyText: String
    ) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = header.isEmpty ? documentId : header
        attrs.contentDescription = String(bodyText.prefix(300))
        attrs.keywords = [volumeId, documentId]
        return CSSearchableItem(
            uniqueIdentifier: "\(volumeId)/\(documentId)",
            domainIdentifier: volumeId,
            attributeSet: attrs
        )
    }

    /// Rebuilds the on-device Spotlight index from `document_cache`, without
    /// re-parsing any volume XML (Session 154).
    ///
    /// Deletes every FRUS Explorer item from the system Spotlight index, then
    /// re-submits one `CSSearchableItem` per cached document using the header and
    /// body-text prefix already stored in `document_cache` — the same shape as
    /// `submitSpotlightItems(for:)`, batched to avoid building one enormous array
    /// for a full-corpus rebuild. Use this to recover from a Spotlight index that
    /// has drifted from the on-disk search index without a full reindex.
    public func rebuildSpotlightIndex() async throws {
        try await CSSearchableIndex.default().deleteAllSearchableItems()

        // Each batch is read with its own statement, fully stepped and finalized
        // before the Spotlight submission suspends. The actor is reentrant: an
        // open statement held across an `await` could observe (or block) another
        // call mutating or rebuilding the database mid-iteration. Keyset
        // pagination on rowid keeps each read O(batch) regardless of corpus size.
        var lastRowId: Int64 = 0
        var total = 0
        while true {
            var batch: [CSSearchableItem] = []
            do {
                let sql = """
                    SELECT rowid, volume_id, document_id, header, body_text
                    FROM document_cache WHERE rowid > ? ORDER BY rowid LIMIT 500
                    """
                let stmt = try auxPrepare(sql)
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, lastRowId)
                while try auxStep(stmt) {
                    lastRowId = sqlite3_column_int64(stmt, 0)
                    batch.append(Self.makeSearchableItem(
                        volumeId: auxColumnString(stmt, 1) ?? "",
                        documentId: auxColumnString(stmt, 2) ?? "",
                        header: auxColumnString(stmt, 3) ?? "",
                        bodyText: auxColumnString(stmt, 4) ?? ""
                    ))
                }
            }
            guard !batch.isEmpty else { break }
            try await CSSearchableIndex.default().indexSearchableItems(batch)
            total += batch.count
        }

        logger.info("rebuildSpotlightIndex: resubmitted \(total, privacy: .public) items")
    }

    // MARK: - Browser Query (used by BrowserViewModel)

    /// Returns all documents for a volume in insertion order (source document order).
    ///
    /// Reads `document_cache` which is populated by `indexVolume`. Returns an empty
    /// array if the volume has not been indexed.
    ///
    /// - Parameter volumeId: The volume to query.
    /// - Returns: `DocumentBrowserEntry` values ordered by their rowid.
    public func documents(forVolume volumeId: String) throws -> [DocumentBrowserEntry] {
        let sql = """
            SELECT document_id, document_number, header, dateline, source_note, is_editorial_note
            FROM document_cache WHERE volume_id = ?
            ORDER BY rowid
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)

        var entries: [DocumentBrowserEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(DocumentBrowserEntry(
                documentId:     auxColumnString(stmt, 0) ?? "",
                volumeId:       volumeId,
                documentNumber: auxColumnString(stmt, 1),
                header:         auxColumnString(stmt, 2) ?? "",
                dateline:       auxColumnString(stmt, 3),
                sourceNote:     auxColumnString(stmt, 4),
                isEditorialNote: sqlite3_column_int(stmt, 5) != 0
            ))
        }
        return entries
    }

    /// Returns the document carrying the given canonical printed number in a volume, or
    /// `nil` when the volume is not indexed or has no such document.
    ///
    /// This is a **deterministic** `document_cache` lookup by `document_number` — the
    /// resolution path citation matching requires. A full-text keyword search for a bare
    /// number is NOT a substitute: BM25 ranks every document whose body merely mentions
    /// the digits (dates, telegram numbers, page references) and the result cap starves
    /// out the actual document row in any realistically-sized volume.
    ///
    /// - Parameters:
    ///   - documentNumber: The canonical printed number as stored (e.g. `"15"`).
    ///   - volumeId: The volume to query.
    /// - Returns: The matching entry, or `nil`.
    public func document(
        forDocumentNumber documentNumber: String,
        inVolume volumeId: String
    ) throws -> DocumentBrowserEntry? {
        let sql = """
            SELECT document_id, document_number, header, dateline, source_note, is_editorial_note
            FROM document_cache WHERE volume_id = ? AND document_number = ?
            ORDER BY rowid
            LIMIT 1
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 2, documentNumber, -1, SQLITE_TRANSIENT_IP)

        // auxStep (not a raw sqlite3_step) so a step-level error (I/O, corruption)
        // throws instead of masquerading as "no such document" — a silent false
        // negative here is exactly the user-visible symptom this lookup exists to fix.
        guard try auxStep(stmt) else { return nil }
        return DocumentBrowserEntry(
            documentId:     auxColumnString(stmt, 0) ?? "",
            volumeId:       volumeId,
            documentNumber: auxColumnString(stmt, 1),
            header:         auxColumnString(stmt, 2) ?? "",
            dateline:       auxColumnString(stmt, 3),
            sourceNote:     auxColumnString(stmt, 4),
            isEditorialNote: sqlite3_column_int(stmt, 5) != 0
        )
    }

    /// Returns the complete, in-order reading sequence for a volume: every front- and
    /// back-matter section plus every numbered document, in source order.
    ///
    /// `documents(forVolume:)` reads only `document_cache`, which deliberately omits the
    /// structured / navigation sections kept out of the search index — Persons, Sources,
    /// Table of Contents, and Index. Prev/Next navigation built on that list therefore
    /// skips exactly those sections. This method instead walks the persisted
    /// `VolumeStructure`, enriching body documents with their cached metadata and
    /// synthesising entries for sections absent from `document_cache` so they open as
    /// quasi-documents by `xml:id`.
    ///
    /// Falls back to `documents(forVolume:)` order when no structure is cached. Body
    /// documents the structure walk doesn't reach are appended so the sequence never
    /// loses a document relative to `document_cache`.
    ///
    /// - Parameter volumeId: The volume to build the sequence for.
    /// - Returns: Reading-ordered `DocumentBrowserEntry` values spanning front matter,
    ///   body, and back matter.
    public func readingSequence(forVolume volumeId: String) throws -> [DocumentBrowserEntry] {
        let cached = try documents(forVolume: volumeId)
        guard let structure = try cachedVolumeStructure(forVolumeId: volumeId),
              !structure.isEmpty else {
            return cached
        }
        return Self.mergeReadingSequence(structure: structure, cached: cached, volumeId: volumeId)
    }

    /// Merges a `VolumeStructure` with the volume's `document_cache` rows into a single
    /// reading-ordered list. Pure (no I/O) so it is unit-testable without a database.
    ///
    /// Walks `structure.sections` depth-first in source order. Container sections
    /// (compilations, chapters, the `<front>`/`<back>` wrappers) contribute their direct
    /// documents and then their subsections; leaf sections contribute themselves. Each
    /// id is enriched from `cached` when present, otherwise synthesised from the
    /// section's title. Sections without an explicit `xml:id` are skipped — they can't
    /// be reopened by id. Any cached document the walk doesn't reach is appended last so
    /// the result never loses a document relative to `cached`.
    nonisolated static func mergeReadingSequence(
        structure: VolumeStructure,
        cached: [DocumentBrowserEntry],
        volumeId: String
    ) -> [DocumentBrowserEntry] {
        let byId = Dictionary(cached.map { ($0.documentId, $0) }) { first, _ in first }
        var result: [DocumentBrowserEntry] = []
        var seen = Set<String>()

        func append(id: String, fallbackTitle: String) {
            guard !id.isEmpty, !seen.contains(id) else { return }
            seen.insert(id)
            result.append(byId[id] ?? DocumentBrowserEntry(
                documentId: id, volumeId: volumeId, header: fallbackTitle))
        }

        func walk(_ sections: [VolumeSection]) {
            for section in sections {
                if !section.documentIds.isEmpty || !section.subsections.isEmpty {
                    // Container: direct documents first, then nested subsections.
                    for docId in section.documentIds { append(id: docId, fallbackTitle: "") }
                    walk(section.subsections)
                } else if section.hasExplicitSectionId {
                    // Leaf section: prose front/back matter, or a structured / navigation
                    // section (Persons, Sources, TOC, Index) opened as a quasi-document.
                    append(id: section.sectionId, fallbackTitle: section.title)
                }
            }
        }
        walk(structure.sections)

        // Safety net: include any cached document the walk didn't reach so Prev/Next
        // never loses a body document even if the persisted structure is incomplete.
        for entry in cached where !seen.contains(entry.documentId) {
            seen.insert(entry.documentId)
            result.append(entry)
        }
        return result
    }

    /// Returns `true` if `document_cache` has at least one row for the given volume.
    ///
    /// Used by `BrowserViewModel` to distinguish indexed from unindexed volumes.
    /// nonisolated: accesses `auxDb` (nonisolated(unsafe)) directly — safe as a read-only query.
    public nonisolated func isVolumeIndexed(_ volumeId: String) throws -> Bool {
        let sql = "SELECT 1 FROM document_cache WHERE volume_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(auxDb, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = auxDb.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw IndexingError.sqliteError(code: rc, message: msg)
        }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_text(s, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        return sqlite3_step(s) == SQLITE_ROW
    }

    /// Returns the set of all volume IDs that have at least one row in `document_cache`.
    ///
    /// Used by `AppState` to seed `indexedVolumeIds` at boot so subsequent per-volume
    /// checks can use an O(1) Set lookup rather than a per-call SQLite query.
    /// nonisolated: accesses `auxDb` directly — safe as a read-only query.
    public nonisolated func allIndexedVolumeIds() throws -> Set<String> {
        let sql = "SELECT DISTINCT volume_id FROM document_cache"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(auxDb, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = auxDb.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw IndexingError.sqliteError(code: rc, message: msg)
        }
        defer { sqlite3_finalize(s) }
        var ids = Set<String>()
        while sqlite3_step(s) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(s, 0) {
                ids.insert(String(cString: cStr))
            }
        }
        return ids
    }

    /// Volume IDs that are downloaded on disk but absent from the index.
    ///
    /// Returns only genuinely missing volumes, so a healthy, fully-indexed corpus
    /// yields an empty array. Used by the background task (which cannot reach the
    /// actor-private `volumesDirectory` directly) so a backgrounding with only
    /// word-cloud precompute work pending no longer triggers a wholesale reindex.
    /// Interrupted volumes are not excluded here — callers tracking interruptions
    /// filter them separately.
    public func unindexedDownloadedVolumeIds() throws -> [String] {
        let indexed = try allIndexedVolumeIds()
        return Self.findDownloadedVolumes(in: volumesDirectory)
            .map(\.volumeId)
            .filter { !indexed.contains($0) }
            .sorted()
    }

    // MARK: - Volume Structure Cache (used by BrowserViewModel)

    /// Returns the Browser structure persisted for a volume at index time, or `nil`
    /// if the volume has not been indexed (or was indexed before the
    /// `volume_structures` table existed — the Browser then falls back to parsing
    /// the volume XML on demand, exactly as before).
    public func cachedVolumeStructure(forVolumeId volumeId: String) throws -> VolumeStructure? {
        let stmt = try auxPrepare(
            "SELECT structure_json FROM volume_structures WHERE volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let json = auxColumnString(stmt, 0),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(VolumeStructure.self, from: data)
    }

    // MARK: - Volume Sources Query (used by VolumeSourcesView)

    /// Returns all archival source entries for a volume from the `volume_sources` table.
    ///
    /// Results are ordered by `sort_order` (insertion order from the TEI source list).
    /// Returns an empty array if the volume has not been indexed or has no sources list.
    ///
    /// Used by `VolumeSourcesView` to display the front-matter sources section.
    public func volumeSources(forVolumeId volumeId: String) throws -> [VolumeSourceEntry] {
        let sql = """
            SELECT repository, record_group, lot_file, series_name, entry_text, kind, depth, is_heading,
                   lot_file_norm, decimal_class
            FROM volume_sources
            WHERE volume_id = ?
            ORDER BY sort_order
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        var entries: [VolumeSourceEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(VolumeSourceEntry(
                kind:         VolumeSourceKind(rawValue: auxColumnString(stmt, 5) ?? "item") ?? .item,
                depth:        auxColumnIntOptional(stmt, 6) ?? 0,
                isHeading:    (auxColumnIntOptional(stmt, 7) ?? 0) != 0,
                repository:   auxColumnString(stmt, 0),
                recordGroup:  auxColumnString(stmt, 1),
                lotFile:      auxColumnString(stmt, 2),
                lotFileNorm:  auxColumnString(stmt, 8),
                seriesName:   auxColumnString(stmt, 3),
                decimalClass: auxColumnString(stmt, 9),
                rawText:      auxColumnString(stmt, 4) ?? ""
            ))
        }
        return entries
    }

    // MARK: - Combined Search Query (used by SearchService)

    /// Executes the combined corpus + user-content full-text search with all
    /// structured filters applied inside SQL.
    ///
    /// The query merges matches from `frus_documents` (corpus text) and
    /// `user_content` (summaries/notes) by `document_cache` rowid — the shared
    /// external-content key — taking the better (lower) BM25 score when a document
    /// matches in both. Display fields, body text, the ISO date, and the
    /// front-matter flag are joined from `document_cache` / `document_dates` in the
    /// same statement, so a search is a single SQL round-trip.
    ///
    /// Filters (volume, date range, front matter, person, tags, document type) are
    /// `WHERE` conditions evaluated **before** `LIMIT`/`OFFSET`, which makes
    /// pagination exact — the previous design post-filtered an overscanned FTS5
    /// page in Swift, so page boundaries drifted whenever a filter dropped rows.
    ///
    /// - Parameters:
    ///   - corpusMatch: FTS5 MATCH expression for `frus_documents`, or `nil` to skip
    ///     corpus text (e.g. when the user scopes search to summaries only).
    ///   - userContentMatch: FTS5 MATCH expression for `user_content`, or `nil` to
    ///     skip summaries/notes.
    ///   - filters: Structured filters applied in the `WHERE` clause.
    ///   - limit: Maximum rows returned.
    ///   - offset: Rows to skip (exact, because filtering precedes pagination).
    /// - Throws: `FTS5Error.emptyQuery` when both match expressions are `nil`.
    public func searchDocuments(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        limit: Int,
        offset: Int,
        singlePhaseForParity: Bool = false
    ) throws -> [IndexedSearchRow] {
        let (whereClause, filterBinds) = Self.filterConditions(filters)
        let sql: String
        let binds: [String]
        if corpusMatch == nil, userContentMatch == nil {
            // Filter-only query (e.g. the People browser's "Find all mentions" — a person filter with
            // no FTS terms). No MATCH/BM25; the WHERE clause (which always carries the person filter
            // in this path) does the work, ordered by volume + document for a stable browse. Guard
            // against an unbounded dump if somehow no filter is present.
            guard !whereClause.isEmpty else { return [] }
            sql = """
                SELECT dc.document_id, dc.volume_id, dc.document_number, dc.header, dc.dateline,
                       dc.source_note, dc.body_text, dc.subject_tag_ids, dc.user_tag_ids,
                       dc.is_editorial_note, dc.is_front_matter, dd.date_iso, 0.0 AS score
                FROM document_cache dc
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                ORDER BY dc.volume_id, dc.document_id
                LIMIT \(limit) OFFSET \(offset)
                """
            binds = filterBinds
        } else if singlePhaseForParity {
            // The pre-R-3a shape, retained ONLY so `searchDocumentsSinglePhaseForTesting` can assert
            // the two-phase rewrite against it in-process. Never taken in the app.
            let (matchCTE, matchBinds) = try Self.matchCTE(corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            sql = """
                \(matchCTE)
                SELECT dc.document_id, dc.volume_id, dc.document_number, dc.header, dc.dateline,
                       dc.source_note, dc.body_text, dc.subject_tag_ids, dc.user_tag_ids,
                       dc.is_editorial_note, dc.is_front_matter, dd.date_iso, m.score
                FROM merged m
                JOIN document_cache dc ON dc.rowid = m.docrowid
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                ORDER BY m.score
                LIMIT \(limit) OFFSET \(offset)
                """
            binds = matchBinds + filterBinds
        } else {
            // TWO-PHASE FETCH (R-3a). Rank narrow, then hydrate only the window that survives.
            //
            // The single-phase shape above joins `document_cache` and then sorts, so every matched
            // row is materialised before the sorter runs — 195,519 rows for a common term, at ~5 KB
            // of `body_text` each (mean 5,355 bytes; 1.05 GB in total for `"government"`). `body_text` lives on overflow pages, and SQLite follows those
            // chains only for columns a statement actually selects; phase one selects none of them,
            // so the ranking pass reads b-tree pages instead of megabytes of prose.
            //
            // Measured on the real 6.3 GB store, `"government"`, byte-identical output either way.
            // The honest statement is about SHAPE, not a ratio: the ranking pass still has to score
            // and sort every matched row and costs a few tenths of a second whatever happens
            // (0.32–0.43 s measured, 195,519 rows); what became free is hydrating the window. A
            // single before/after ratio would be a claim about the page cache rather than about the
            // query — the same statement measured 4.70 s cold and 0.25 s warm on this machine.
            //
            // **The speed-up does not hold for `=exact`.** `SearchService.exactColumns(for:)`
            // includes `body_text` whenever `includeDocumentText` is true, which is the default, so
            // an `=exact` query emits `frus_exact_word(dc.body_text, ?)` into the phase-one WHERE
            // clause and forces the ranking pass to read the very column this split exists to
            // avoid. No ratio is quoted for that either: three measurements of the same effect gave
            // 15x, 2.2x and 2.0x purely on cache state.
            //
            // Phase one keeps the SAME joins and the SAME `whereClause`. That is not redundancy —
            // filters reference `dc.` (volume scope, front-matter, editorial-note, user tags,
            // `frus_exact_word`, and the person-mention EXISTS subqueries) and `dd.date_iso`, so
            // they must narrow the set BEFORE the window is drawn. Applying them after `LIMIT`
            // would page through the wrong set and silently return too few rows.
            //
            // `ordinal` is insurance, and honestly labelled as such. Phase two re-reads the window
            // and must reproduce phase one's order; ordering it by `score` alone would leave rows
            // with EQUAL bm25 scores free to come back in a different order than the ranking pass
            // chose. SQLite does not GUARANTEE a stable order for equal sort keys.
            //
            // In practice it currently gives one: a mutation replacing `ORDER BY r.ordinal` with
            // `ORDER BY r.score` passes the parity suite even against a fixture of 40 byte-identical
            // documents that provably share a single bm25 score. So no test in this repo can
            // falsify the ordinal, and it is kept because it makes phase two's order phase one's
            // order BY CONSTRUCTION rather than by an observed coincidence of the current planner.
            // Its cost is not "a window function over an already-LIMITed set" — SQL evaluates window
            // functions before the same query block's ORDER BY and LIMIT, so that model is
            // backwards. The ordinal reuses the sort the ORDER BY already needs, which is why the
            // A/B measured no difference.
            let (matchCTE, matchBinds) = try Self.matchCTE(corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            // The joins in phase one are CONDITIONAL, and that is the whole optimisation.
            //
            // They exist only to let the filters see `dc.`/`dd.` columns. With no filters they are
            // pure cost: one rowid lookup into a 6.3 GB table per matched row, 195,519 of them for a
            // common term. Measured — an unfiltered first page for `govern` is **10.74 s** with the
            // joins and **0.376 s** without. I wrote them in unconditionally first, and only caught
            // it by measuring the finished statement instead of trusting the number I had taken
            // earlier from a shape that did not have them.
            let rankingJoins = whereClause.isEmpty ? "" : """
                    JOIN document_cache dc ON dc.rowid = m.docrowid
                    LEFT JOIN document_dates dd
                        ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                """
            sql = """
                \(matchCTE),
                ranked AS (
                    SELECT m.docrowid AS docrowid,
                           m.score AS score,
                           ROW_NUMBER() OVER (ORDER BY m.score) AS ordinal
                    FROM merged m
                    \(rankingJoins)
                    \(whereClause)
                    ORDER BY m.score
                    LIMIT \(limit) OFFSET \(offset)
                )
                SELECT dc.document_id, dc.volume_id, dc.document_number, dc.header, dc.dateline,
                       dc.source_note, dc.body_text, dc.subject_tag_ids, dc.user_tag_ids,
                       dc.is_editorial_note, dc.is_front_matter, dd.date_iso, r.score
                FROM ranked r
                JOIN document_cache dc ON dc.rowid = r.docrowid
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                ORDER BY r.ordinal
                """
            binds = matchBinds + filterBinds
        }
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, bind) in binds.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), bind, -1, SQLITE_TRANSIENT_IP)
        }

        var rows: [IndexedSearchRow] = []
        while try auxStep(stmt) {
            rows.append(IndexedSearchRow(
                documentId: auxColumnString(stmt, 0) ?? "",
                volumeId: auxColumnString(stmt, 1) ?? "",
                documentNumber: auxColumnString(stmt, 2),
                header: auxColumnString(stmt, 3) ?? "",
                dateline: auxColumnString(stmt, 4),
                sourceNote: auxColumnString(stmt, 5),
                bodyText: auxColumnString(stmt, 6) ?? "",
                subjectTagIds: auxColumnString(stmt, 7),
                userTagIds: auxColumnString(stmt, 8),
                isEditorialNote: sqlite3_column_int(stmt, 9) != 0,
                isFrontMatter: sqlite3_column_int(stmt, 10) != 0,
                dateISO: auxColumnString(stmt, 11),
                score: sqlite3_column_double(stmt, 12)
            ))
        }
        return rows
    }

    /// Returns the exact number of documents matching the search and all filters.
    ///
    /// Runs the same match CTE and `WHERE` clause as `searchDocuments` with a
    /// `COUNT(*)`, so the count agrees with paginated results — unlike the previous
    /// FTS5-only count, which ignored post-processing filters and could overstate.
    public func searchDocumentsCount(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters
    ) throws -> Int {
        let (whereClause, filterBinds) = Self.filterConditions(filters)
        let sql: String
        let binds: [String]
        if corpusMatch == nil, userContentMatch == nil {
            // Filter-only count (mirrors searchDocuments' filter-only path).
            guard !whereClause.isEmpty else { return 0 }
            sql = """
                SELECT COUNT(*)
                FROM document_cache dc
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                """
            binds = filterBinds
        } else if whereClause.isEmpty {
            // No filters: the joins cannot change the answer, so do not pay for them.
            //
            // This is the DEFAULT case, not an edge case — `includeFrontMatter` defaults
            // true and `.all` document type emits no condition, so an ordinary unfiltered
            // search took this path and joined a 1.8 GB table once per matched row to
            // answer a question that needs only the match set's cardinality.
            //
            // Measured against the real 6.3 GB store, `"government"` (195,519 matches),
            // identical answers:
            //
            //     with the joins ....... 2.55 s cold / 0.237 s warm
            //     without .............. 0.011 s cold / 0.003 s warm
            //
            // The join is safe to drop rather than merely unnecessary: both FTS tables are
            // `content='document_cache', content_rowid='rowid'` with the full trigger set,
            // and each `_docsize` shadow holds exactly as many rows as `document_cache`, so
            // an FTS rowid with no content row cannot exist. `countMatchesTheJoinedShape`
            // pins that rather than trusting it.
            let (matchCTE, matchBinds) = try Self.matchCTE(corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            sql = """
                \(matchCTE)
                SELECT COUNT(*) FROM merged m
                """
            binds = matchBinds
        } else {
            let (matchCTE, matchBinds) = try Self.matchCTE(corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            sql = """
                \(matchCTE)
                SELECT COUNT(*)
                FROM merged m
                JOIN document_cache dc ON dc.rowid = m.docrowid
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                """
            binds = matchBinds + filterBinds
        }
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, bind) in binds.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), bind, -1, SQLITE_TRANSIENT_IP)
        }
        guard try auxStep(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Builds the `WITH merged(docrowid, score)` CTE for the requested match scopes.
    ///
    /// One scope yields a single MATCH subquery; both scopes yield a `UNION ALL`
    /// grouped by rowid taking the better (minimum) BM25 score.
    private static func matchCTE(
        corpusMatch: String?,
        userContentMatch: String?
    ) throws -> (sql: String, binds: [String]) {
        let corpusSelect = "SELECT rowid AS docrowid, bm25(frus_documents) AS score FROM frus_documents WHERE frus_documents MATCH ?"
        let userSelect = "SELECT rowid AS docrowid, bm25(user_content) AS score FROM user_content WHERE user_content MATCH ?"
        switch (corpusMatch, userContentMatch) {
        case (nil, nil):
            throw FTS5Error.emptyQuery
        case (let corpus?, nil):
            return ("WITH merged(docrowid, score) AS (\(corpusSelect))", [corpus])
        case (nil, let user?):
            return ("WITH merged(docrowid, score) AS (\(userSelect))", [user])
        case (let corpus?, let user?):
            let sql = """
                WITH merged(docrowid, score) AS (
                  SELECT docrowid, MIN(score) FROM (
                    \(corpusSelect)
                    UNION ALL
                    \(userSelect)
                  ) GROUP BY docrowid
                )
                """
            return (sql, [corpus, user])
        }
    }

    // MARK: - Facet Aggregation (R-1a)

    /// Breaks the current match down by year, volume, person, document type and archival
    /// provenance — entirely in SQL, over the whole match (R-1).
    ///
    /// ## The one rule that makes this affordable
    /// The match set is materialised **once** into a TEMP table with an
    /// `INTEGER PRIMARY KEY`, and every aggregate is driven `FROM` that table outward, with
    /// `CROSS JOIN` pinning the order.
    ///
    /// Measured against the real 6.3 GB store, and stated precisely because the temptation
    /// to overclaim here is strong:
    ///
    /// - Driving from the match set is what matters. `SCAN ms / SEARCH dc USING INTEGER
    ///   PRIMARY KEY` over a 350-match query costs **0.001 s**. Written the other way —
    ///   `FROM document_cache dc WHERE dc.rowid IN (…)` — the planner picks `SCAN dc`, reads
    ///   the whole 1.8 GB table, and the same 350 matches cost **11.07 s**.
    /// - `CROSS JOIN` is **not** what rescues that. Given `FROM temp.facet_mset ms JOIN
    ///   document_cache dc`, SQLite already picks the right order on the real store at 350
    ///   matches — verified. What `CROSS JOIN` buys is that the choice stops depending on
    ///   table statistics: on a twelve-document test fixture the planner picks the *reverse*
    ///   order (`SCAN dc / SEARCH ms`), correctly, because at that size scanning dc's
    ///   covering index is cheaper. A facet panel's cost should not vary with how the
    ///   planner currently feels about row counts, so the order is pinned.
    ///
    /// `EXPLAIN QUERY PLAN` is the acceptance criterion rather than a stopwatch: on a small
    /// fixture both shapes are instant, and only the plan says which was chosen. Note that
    /// the plan names *aliases* — `SCAN dc`, not `SCAN document_cache` — which is what made
    /// an earlier version of the test vacuous.
    ///
    /// ## Whole match, not the page
    /// Decision R-1-2. The result list is capped (1,000 iOS / 7,500 macOS); these counts are
    /// not. Callers must say so rather than let the two numbers be read as one.
    ///
    /// - Parameters:
    ///   - request: which sections to compute, and the per-section row limit. Sections are
    ///     computed lazily per decision R-1-1, so a caller asks for what it is about to show.
    /// - Returns: the breakdown, with every truncation and coverage gap stated.
    func resultSetFacets(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        request: FacetRequest,
        joinedMaterializationForParity: Bool = false
    ) throws -> ResultSetFacets {
        let matchCount = try materializeMatchSet(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters,
            joinedMaterializationForParity: joinedMaterializationForParity)
        defer { try? auxExec("DROP TABLE IF EXISTS temp.facet_mset") }
        guard matchCount > 0 else { return .empty() }

        var bounds: [FacetSection: FacetBound] = [:]
        let limit = max(1, request.limitPerSection)

        func section(
            _ kind: FacetSection, sql: String, distinctSQL: String,
            label: (String) -> String = { $0 }
        ) throws -> [FacetBucket] {
            guard request.sections.contains(kind) else { return [] }
            let buckets = try facetBuckets(sql: sql, limit: limit, label: label)
            let distinct = try scalar(distinctSQL)
            bounds[kind] = FacetBound(shown: buckets.count, total: distinct)
            return buckets
        }

        // Years. `substr(date_iso, 1, 4)` rather than a date function so the index on
        // `date_iso` stays usable and undated rows stay excludable.
        let years = try section(
            .years,
            sql: """
                SELECT substr(dd.date_iso, 1, 4) AS k, COUNT(*) AS c
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                WHERE dd.date_iso IS NOT NULL AND dd.date_iso <> ''
                GROUP BY k ORDER BY k DESC
                """,
            distinctSQL: """
                SELECT COUNT(DISTINCT substr(dd.date_iso, 1, 4))
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                WHERE dd.date_iso IS NOT NULL AND dd.date_iso <> ''
                """)

        // Undated documents appear in no year bucket, so a histogram whose bars sum to less
        // than the match would otherwise be unexplained.
        let undated = request.sections.contains(.years)
            ? try scalar("""
                SELECT COUNT(*)
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                WHERE dd.date_iso IS NULL OR dd.date_iso = ''
                """)
            : 0

        let volumes = try section(
            .volumes,
            sql: """
                SELECT dc.volume_id AS k, COUNT(*) AS c
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                GROUP BY k ORDER BY c DESC, k ASC
                """,
            distinctSQL: """
                SELECT COUNT(DISTINCT dc.volume_id)
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                """)

        // People resolve through the cross-corpus rollup so one person is not split across
        // name variants. `COUNT(DISTINCT …)` because a document may mention several refs
        // that roll up to the same person.
        let people = try section(
            .people,
            sql: """
                SELECT CAST(prm.rollup_id AS TEXT) AS k,
                       COUNT(DISTINCT dc.rowid) AS c,
                       COALESCE(pr.canonical_name, '') AS lbl
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN person_mentions pm
                    ON pm.volume_id = dc.volume_id AND pm.document_id = dc.document_id
                CROSS JOIN person_rollup_member prm
                    ON prm.volume_id = pm.volume_id AND prm.ref = pm.person_ref
                LEFT JOIN person_rollup pr ON pr.rollup_id = prm.rollup_id
                GROUP BY k ORDER BY c DESC, lbl ASC
                """,
            distinctSQL: """
                SELECT COUNT(DISTINCT prm.rollup_id)
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN person_mentions pm
                    ON pm.volume_id = dc.volume_id AND pm.document_id = dc.document_id
                CROSS JOIN person_rollup_member prm
                    ON prm.volume_id = pm.volume_id AND prm.ref = pm.person_ref
                """)

        let documentTypes = try section(
            .documentType,
            sql: """
                SELECT CAST(dc.is_editorial_note AS TEXT) AS k, COUNT(*) AS c
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                GROUP BY k ORDER BY c DESC
                """,
            distinctSQL: """
                SELECT COUNT(DISTINCT dc.is_editorial_note)
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                """)

        let provenance = try section(
            .provenance,
            sql: """
                SELECT ds.citation_era AS k, COUNT(DISTINCT dc.rowid) AS c
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN document_sources ds
                    ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
                GROUP BY k ORDER BY c DESC, k ASC
                """,
            distinctSQL: """
                SELECT COUNT(DISTINCT ds.citation_era)
                FROM temp.facet_mset ms
                CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                CROSS JOIN document_sources ds
                    ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
                """)

        // Two coverage denominators, not one — see `ProvenanceCoverage`.
        var coverage = ProvenanceCoverage(parsed: 0, withRecordGroup: 0, matchCount: matchCount)
        if request.sections.contains(.provenance) {
            coverage = ProvenanceCoverage(
                parsed: try scalar("""
                    SELECT COUNT(DISTINCT dc.rowid)
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    CROSS JOIN document_sources ds
                        ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
                    """),
                withRecordGroup: try scalar("""
                    SELECT COUNT(DISTINCT dc.rowid)
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    CROSS JOIN document_sources ds
                        ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
                    WHERE ds.record_group IS NOT NULL AND ds.record_group <> ''
                    """),
                matchCount: matchCount)
        }

        return ResultSetFacets(
            matchCount: matchCount, years: years, undatedCount: undated,
            volumes: volumes, people: people, documentTypes: documentTypes,
            provenance: provenance, provenanceCoverage: coverage, bounds: bounds)
    }

    /// Counts how many documents in the current match carry each of `tagIds`.
    ///
    /// Deliberately **not** a `FacetSection`. The facet panel exists to triage dimensions too
    /// long to read — 552 volumes, 14,615 person rollups — and user tags are the opposite
    /// problem: measured on the real store, 67 of 316,839 documents carry a tag (0.021%), so a
    /// permanent sixth section would render "Nothing to break down here" for almost every
    /// query and teach the researcher the dimension is broken. These counts belong on the
    /// filter sheet's existing My Tags toggles, which appear only when opened and already
    /// perform the narrowing.
    ///
    /// ## Two rules, both settled by measurement rather than reasoning
    /// **The empty-string guard is what makes it affordable.** Because 99.98% of rows have no
    /// tags, `WHERE user_tag_ids <> ''` removes all string work for almost every seek. With
    /// it, cost is 0.18 s over a 195,519-document match — parity with the shipped Volumes
    /// aggregate's 0.19 s — and **flat in tag count** (500 tags measured at the same 0.18 s).
    /// Without it, 100 tags cost 1.74 s.
    ///
    /// **`COUNT(DISTINCT)` is not optional.** 14 of the 67 tagged rows on the real store repeat
    /// an id inside one string, so `COUNT(*)` reported 25 for a tag the shipped filter matches
    /// on 22 documents. `people` and `provenance` already count distinct for the same reason.
    ///
    /// Keys come from the caller's live `UserTag` list, not from the column, so a stale id
    /// left in `user_tag_ids` can never produce a phantom row.
    ///
    /// - Returns: counts keyed by tag-id string. Tags matching nothing are omitted.
    func userTagCounts(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        tagIds: [String],
        joinedMaterializationForParity: Bool = false
    ) throws -> [String: Int] {
        guard !tagIds.isEmpty else { return [:] }
        let matchCount = try materializeMatchSet(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters,
            joinedMaterializationForParity: joinedMaterializationForParity)
        defer { try? auxExec("DROP TABLE IF EXISTS temp.facet_mset") }
        guard matchCount > 0 else { return [:] }

        let values = tagIds.map { _ in "(?)" }.joined(separator: ",")
        let sql = """
            WITH tv(id) AS (VALUES \(values))
            SELECT tv.id AS k, COUNT(DISTINCT ms.docrowid) AS c
            FROM temp.facet_mset ms
            CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
            JOIN tv ON (' ' || dc.user_tag_ids || ' ') LIKE ('% ' || tv.id || ' %')
            WHERE dc.user_tag_ids IS NOT NULL AND dc.user_tag_ids <> ''
            GROUP BY k
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (index, id) in tagIds.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), id, -1, SQLITE_TRANSIENT_IP)
        }
        var counts: [String: Int] = [:]
        while try auxStep(stmt) {
            guard let key = auxColumnString(stmt, 0) else { continue }
            counts[key] = Int(sqlite3_column_int64(stmt, 1))
        }
        return counts
    }

    /// `EXPLAIN QUERY PLAN` for the tag-count aggregate, so a test can assert its drive order
    /// against the same three rules the facet sections are held to.
    func userTagCountPlanForTesting(tagIds: [String]) throws -> String {
        let values = tagIds.map { _ in "(?)" }.joined(separator: ",")
        // The plan does not depend on the bound values, so a scratch match set is enough.
        try auxExec("DROP TABLE IF EXISTS temp.facet_mset")
        try auxExec("CREATE TEMP TABLE facet_mset (docrowid INTEGER PRIMARY KEY)")
        defer { try? auxExec("DROP TABLE IF EXISTS temp.facet_mset") }
        return try queryPlanForTesting("""
            WITH tv(id) AS (VALUES \(values))
            SELECT tv.id AS k, COUNT(DISTINCT ms.docrowid) AS c
            FROM temp.facet_mset ms
            CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
            JOIN tv ON (' ' || dc.user_tag_ids || ' ') LIKE ('% ' || tv.id || ' %')
            WHERE dc.user_tag_ids IS NOT NULL AND dc.user_tag_ids <> ''
            GROUP BY k
            """)
    }

    /// Materialises the current match into `temp.facet_mset(docrowid INTEGER PRIMARY KEY)`
    /// and returns its size.
    ///
    /// `INTEGER PRIMARY KEY` makes `docrowid` the table's rowid, so every aggregate's join
    /// back to `document_cache` is a rowid seek. `temp_store=MEMORY` is already set
    /// (`setupDatabase`), so this never touches disk.
    private func materializeMatchSet(
        corpusMatch: String?, userContentMatch: String?, filters: SearchSQLFilters,
        joinedMaterializationForParity: Bool = false
    ) throws -> Int {
        try auxExec("DROP TABLE IF EXISTS temp.facet_mset")
        try auxExec("CREATE TEMP TABLE facet_mset (docrowid INTEGER PRIMARY KEY)")

        guard let (sql, binds) = try Self.materializeMatchSetSQL(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters,
            joinedMaterializationForParity: joinedMaterializationForParity)
        else { return 0 }

        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, bind) in binds.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), bind, -1, SQLITE_TRANSIENT_IP)
        }
        guard try auxStep(stmt) || true else { return 0 }
        return try scalar("SELECT COUNT(*) FROM temp.facet_mset")
    }

    /// The statement `materializeMatchSet` runs, split out so a test can explain the real one
    /// rather than a hand-written approximation of it.
    ///
    /// Returns `nil` for the one case that runs no statement at all: a filter-only search with no
    /// filters, which would be the whole corpus rather than a result set.
    private static func materializeMatchSetSQL(
        corpusMatch: String?, userContentMatch: String?, filters: SearchSQLFilters,
        joinedMaterializationForParity: Bool
    ) throws -> (sql: String, binds: [String])? {
        let (whereClause, filterBinds) = Self.filterConditions(filters)
        let sql: String
        let binds: [String]
        if corpusMatch == nil, userContentMatch == nil {
            // Filter-only search (a person filter with no terms). Mirrors
            // `searchDocuments`' filter-only path; an unfiltered filter-only query would be
            // the whole corpus, which is not a result set.
            guard !whereClause.isEmpty else { return nil }
            sql = """
                INSERT INTO temp.facet_mset(docrowid)
                SELECT dc.rowid
                FROM document_cache dc
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                """
            binds = filterBinds
        } else if whereClause.isEmpty, !joinedMaterializationForParity {
            // UNFILTERED MATCH — the joins are pure cost, so drop them.
            //
            // `dc.rowid` in the joined shape below is `m.docrowid` by construction, and with no
            // WHERE clause neither join can influence which rows land in the match set. Both joins
            // therefore contribute nothing but work:
            //
            //  - The INNER JOIN cannot drop a row. Both FTS tables are `content='document_cache',
            //    content_rowid='rowid'` with the full trigger set, so an FTS rowid with no content
            //    row cannot exist. Measured on the owner's index: document_cache 316,839,
            //    frus_documents_docsize 316,839, and zero FTS rowids without a content row.
            //  - The LEFT JOIN cannot fan out. `document_dates` is `PRIMARY KEY (volume_id,
            //    document_id)` with zero duplicate keys measured — and dropping it removes the
            //    possibility entirely rather than relying on it.
            //
            // The cost is stated as a property rather than a ratio, because a ratio here is a
            // statement about the page cache rather than about the query: the joined shape performs
            // one rowid seek into a 6.3 GB table for every matched row, so it is cache-dependent and
            // unbounded — measured on the same machine and statement at 4.70 s cold and 0.25 s warm
            // for 195,519 rows. The joinless shape reads only the FTS postings and measured 0.05 s
            // every round, of which ~0.03 s is process start. This matters most where the cache is
            // least likely to hold those pages, which is iOS.
            //
            // This is the DEFAULT path, not a corner: an unfiltered search over the whole corpus is
            // what the facet panel and the tag counts see before the researcher narrows anything.
            let (matchCTE, matchBinds) = try Self.matchCTE(
                corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            sql = """
                \(matchCTE)
                INSERT INTO temp.facet_mset(docrowid)
                SELECT m.docrowid FROM merged m
                """
            binds = matchBinds
        } else {
            let (matchCTE, matchBinds) = try Self.matchCTE(
                corpusMatch: corpusMatch, userContentMatch: userContentMatch)
            // The filters live here, in phase one, exactly as in `searchDocuments` — a facet
            // must describe the set the researcher is actually looking at.
            //
            // Every one of the 13 conditions `filterConditions` can emit references `dc.` or `dd.`
            // and every one changes which rows match, so none may be deferred to a later pass.
            // A filter applied after the match set is built would describe a different set than the
            // researcher is looking at, silently.
            sql = """
                \(matchCTE)
                INSERT INTO temp.facet_mset(docrowid)
                SELECT dc.rowid
                FROM merged m
                JOIN document_cache dc ON dc.rowid = m.docrowid
                LEFT JOIN document_dates dd
                    ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                \(whereClause)
                """
            binds = matchBinds + filterBinds
        }
        return (sql, binds)
    }

    /// Runs a facet aggregate, returning at most `limit` buckets.
    ///
    /// The statement must select `(key, count)` and may select a third label column.
    private func facetBuckets(
        sql: String, limit: Int, label: (String) -> String
    ) throws -> [FacetBucket] {
        let stmt = try auxPrepare("\(sql) LIMIT \(limit)")
        defer { sqlite3_finalize(stmt) }
        var buckets: [FacetBucket] = []
        while try auxStep(stmt) {
            guard let key = auxColumnString(stmt, 0) else { continue }
            let count = Int(sqlite3_column_int64(stmt, 1))
            let explicit = sqlite3_column_count(stmt) > 2 ? auxColumnString(stmt, 2) : nil
            let text = (explicit?.isEmpty == false) ? explicit! : label(key)
            buckets.append(FacetBucket(key: key, label: text, count: count))
        }
        return buckets
    }

    /// A single-value `SELECT`, for counts and cardinalities.
    private func scalar(_ sql: String) throws -> Int {
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard try auxStep(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// `EXPLAIN QUERY PLAN` for every facet aggregate, so a test can assert the drive order
    /// rather than time it.
    ///
    /// Exposed because the acceptance criterion for this work is the plan: a fixture small
    /// enough to run in a test suite cannot distinguish a rowid seek from a 1.8 GB scan.
    func facetQueryPlansForTesting(
        corpusMatch: String?, userContentMatch: String?, filters: SearchSQLFilters
    ) throws -> [FacetSection: String] {
        _ = try materializeMatchSet(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters)
        defer { try? auxExec("DROP TABLE IF EXISTS temp.facet_mset") }

        var plans: [FacetSection: String] = [:]
        for kind in FacetSection.allCases {
            // Re-derive each section's SQL by asking for it alone and capturing the plan of
            // its bucket statement. Kept deliberately close to `resultSetFacets`' own text.
            let sql: String
            switch kind {
            case .years:
                sql = """
                    SELECT substr(dd.date_iso, 1, 4) AS k, COUNT(*) AS c
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    CROSS JOIN document_dates dd
                        ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
                    WHERE dd.date_iso IS NOT NULL AND dd.date_iso <> ''
                    GROUP BY k ORDER BY k DESC
                    """
            case .volumes:
                sql = """
                    SELECT dc.volume_id AS k, COUNT(*) AS c
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    GROUP BY k ORDER BY c DESC, k ASC
                    """
            case .people:
                sql = """
                    SELECT CAST(prm.rollup_id AS TEXT) AS k, COUNT(DISTINCT dc.rowid) AS c
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    CROSS JOIN person_mentions pm
                        ON pm.volume_id = dc.volume_id AND pm.document_id = dc.document_id
                    CROSS JOIN person_rollup_member prm
                        ON prm.volume_id = pm.volume_id AND prm.ref = pm.person_ref
                    GROUP BY k ORDER BY c DESC
                    """
            case .documentType:
                sql = """
                    SELECT CAST(dc.is_editorial_note AS TEXT) AS k, COUNT(*) AS c
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    GROUP BY k ORDER BY c DESC
                    """
            case .provenance:
                sql = """
                    SELECT ds.citation_era AS k, COUNT(DISTINCT dc.rowid) AS c
                    FROM temp.facet_mset ms
                    CROSS JOIN document_cache dc ON dc.rowid = ms.docrowid
                    CROSS JOIN document_sources ds
                        ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
                    GROUP BY k ORDER BY c DESC, k ASC
                    """
            }
            plans[kind] = try queryPlanForTesting(sql)
        }
        return plans
    }

    // MARK: - Test Hooks (Q-M2)

    /// Runs `searchDocuments` in its pre-R-3a single-phase shape, so a test can assert the
    /// two-phase rewrite returns byte-identical rows in identical order.
    ///
    /// Not used by the app. Output parity is R-3a's acceptance criterion, and "the rows are the
    /// same" is a claim about SQLite's join and ordering behaviour that deserves an equivalence
    /// test rather than a reviewer's eye — particularly for ties, where the two shapes could
    /// legitimately disagree if the rewrite did not carry an explicit ordinal.
    /// The query plan of the statement `materializeMatchSet` really runs.
    ///
    /// Not used by the app. Output parity cannot detect the dropped joins being re-added — the
    /// answer is identical either way — so the plan is the only mechanical guard on the
    /// optimisation itself.
    func materializeMatchSetPlanForTesting(
        corpusMatch: String?, userContentMatch: String?, filters: SearchSQLFilters,
        joinedMaterializationForParity: Bool = false
    ) throws -> String {
        guard let (sql, _) = try Self.materializeMatchSetSQL(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters,
            joinedMaterializationForParity: joinedMaterializationForParity)
        else { return "" }
        // The statement is an INSERT into the temp table, so the table has to exist for SQLite to
        // parse it — creating it here keeps the explained SQL byte-identical to the one that runs.
        try auxExec("DROP TABLE IF EXISTS temp.facet_mset")
        try auxExec("CREATE TEMP TABLE facet_mset (docrowid INTEGER PRIMARY KEY)")
        defer { try? auxExec("DROP TABLE IF EXISTS temp.facet_mset") }
        return try queryPlanForTesting(sql)
    }

    /// The pre-optimisation facet materialisation, kept solely so a test can assert the optimised
    /// one produces identical facets.
    ///
    /// Not used by the app. "Dropping these joins cannot change the answer" is a claim about
    /// SQLite's external-content invariants, and a claim like that is worth asserting against the
    /// real emitter rather than against a reviewer's reading. Do not delete as dead code.
    func resultSetFacetsJoinedMaterializationForTesting(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        request: FacetRequest
    ) throws -> ResultSetFacets {
        try resultSetFacets(corpusMatch: corpusMatch, userContentMatch: userContentMatch,
                            filters: filters, request: request,
                            joinedMaterializationForParity: true)
    }

    /// The pre-optimisation shape behind the filter sheet's My Tags counts. See
    /// ``resultSetFacetsJoinedMaterializationForTesting(corpusMatch:userContentMatch:filters:request:)``
    /// — this is the second production caller of the same materialisation, and it is here so the
    /// optimisation is not half-tested.
    func userTagCountsJoinedMaterializationForTesting(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        tagIds: [String]
    ) throws -> [String: Int] {
        try userTagCounts(corpusMatch: corpusMatch, userContentMatch: userContentMatch,
                          filters: filters, tagIds: tagIds,
                          joinedMaterializationForParity: true)
    }

    func searchDocumentsSinglePhaseForTesting(
        corpusMatch: String?,
        userContentMatch: String?,
        filters: SearchSQLFilters,
        limit: Int,
        offset: Int
    ) throws -> [IndexedSearchRow] {
        try searchDocuments(corpusMatch: corpusMatch, userContentMatch: userContentMatch,
                            filters: filters, limit: limit, offset: offset,
                            singlePhaseForParity: true)
    }

    /// The pre-optimisation count shape, kept solely so a test can assert the optimised one
    /// returns the same number.
    ///
    /// Not used by the app. It exists because "dropping this join cannot change the answer"
    /// is a claim about SQLite's external-content invariants, and a claim like that should
    /// be pinned by an equivalence test rather than by a comment.
    func searchDocumentsCountJoinedForTesting(
        corpusMatch: String?, userContentMatch: String?
    ) throws -> Int {
        let (matchCTE, matchBinds) = try Self.matchCTE(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch)
        let sql = """
            \(matchCTE)
            SELECT COUNT(*)
            FROM merged m
            JOIN document_cache dc ON dc.rowid = m.docrowid
            LEFT JOIN document_dates dd
                ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, bind) in matchBinds.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), bind, -1, SQLITE_TRANSIENT_IP)
        }
        guard try auxStep(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// The raw `user_tag_ids` value for a document, so a test can assert the column was or
    /// was not disturbed.
    func userTagIdsForTesting(volumeId: String, documentId: String) throws -> String? {
        let stmt = try auxPrepare("""
            SELECT user_tag_ids FROM document_cache
            WHERE volume_id = ? AND document_id = ?
            """)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 2, documentId, -1, SQLITE_TRANSIENT_IP)
        guard try auxStep(stmt) else { return nil }
        return auxColumnString(stmt, 0)
    }

    /// The names of every index on `table`, for tests that assert an index exists.
    func indexNamesForTesting(onTable table: String) throws -> [String] {
        let stmt = try auxPrepare(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT_IP)
        var names: [String] = []
        while try auxStep(stmt) {
            if let raw = sqlite3_column_text(stmt, 0) { names.append(String(cString: raw)) }
        }
        return names
    }

    /// `EXPLAIN QUERY PLAN` output for `sql`, joined into one string.
    ///
    /// The facet work's acceptance criterion is the plan, not a stopwatch: a test fixture
    /// small enough to run fast cannot distinguish a covering index from a full scan, but
    /// the plan says which one SQLite chose.
    func queryPlanForTesting(_ sql: String) throws -> String {
        let stmt = try auxPrepare("EXPLAIN QUERY PLAN \(sql)")
        defer { sqlite3_finalize(stmt) }
        var lines: [String] = []
        while try auxStep(stmt) {
            if let raw = sqlite3_column_text(stmt, 3) { lines.append(String(cString: raw)) }
        }
        return lines.joined(separator: " | ")
    }

    /// Registers `frus_exact_word(text, word)` on `handle`, returning 1 when `text`
    /// contains `word` as a whole token on `unicode61`'s boundaries (Q-3b).
    ///
    /// ## Why a SQL function rather than a Swift filter
    /// The exact-word post-filter has to run inside `searchDocumentsCount`'s `COUNT(*)`,
    /// not just over fetched rows. Filtering in Swift would leave the count reporting the
    /// stemmed superset — a number strictly larger than the result list, shown to a
    /// researcher who is about to publish it. It also keeps `LIMIT`/`OFFSET` pagination
    /// exact, which the whole search path depends on.
    ///
    /// ## Cost
    /// The function only ever runs on rows FTS5 has already matched, so its input is the
    /// stemmed candidate set rather than the corpus. It is declared `SQLITE_DETERMINISTIC`
    /// so SQLite may cache and reorder it, and it short-circuits on empty text.
    ///
    /// A failure to register is not fatal here — it surfaces as a clear "no such
    /// function" error on the first exact query rather than a silently wrong answer,
    /// which is the right failure direction.
    nonisolated private static func registerExactWordFunction(_ handle: OpaquePointer) {
        let flags = SQLITE_UTF8 | SQLITE_DETERMINISTIC
        sqlite3_create_function_v2(
            handle, "frus_exact_word", 2, flags, nil,
            { context, argc, argv in
                guard argc == 2, let argv else {
                    sqlite3_result_int(context, 0)
                    return
                }
                guard let textPtr = sqlite3_value_text(argv[0]),
                      let wordPtr = sqlite3_value_text(argv[1]) else {
                    // A NULL column (dateline, source_note and the user-text columns are
                    // all nullable) simply does not contain the word.
                    sqlite3_result_int(context, 0)
                    return
                }
                let text = String(cString: textPtr)
                let word = String(cString: wordPtr)
                sqlite3_result_int(context, ExactWordMatcher.contains(word: word, in: text) ? 1 : 0)
            },
            nil, nil, nil
        )
    }

    /// Renders `filters` to a `WHERE` clause and its bind values.
    ///
    /// Tag conditions wrap the space-separated tag-ID columns in spaces and use
    /// `LIKE '% <id> %'` so each ID matches as a whole token; multiple IDs are
    /// ANDed, mirroring the previous Swift-side `allSatisfy` semantics.
    private static func filterConditions(_ filters: SearchSQLFilters) -> (whereClause: String, binds: [String]) {
        var conditions: [String] = []
        var binds: [String] = []

        if let vids = filters.volumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            conditions.append("dc.volume_id IN (\(placeholders))")
            binds.append(contentsOf: vids)
        }

        // Chunks a large `"volumeId/documentId"` key set into ≤499-bind `IN`/`NOT IN` groups
        // (SQLite caps bound variables at ~999) and appends the combined condition. `IN` groups
        // OR (match any chunk); `NOT IN` groups AND (excluded from every chunk). Mirrors the
        // chunking the rest of this file uses for unbounded `IN` lists. (#377 Phase 2)
        func appendChunkedKeyCondition(_ ids: [String], op: String, chunkJoin: String) {
            let parts = stride(from: 0, to: ids.count, by: 499).map { start -> String in
                let chunk = Array(ids[start..<min(start + 499, ids.count)])
                let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
                binds.append(contentsOf: chunk)
                return "(dc.volume_id || '/' || dc.document_id) \(op) (\(placeholders))"
            }
            conditions.append("(" + parts.joined(separator: chunkJoin) + ")")
        }

        // Project History scope (#377 Phase 2): restrict to an explicit `"volumeId/documentId"` set.
        // Contract: `nil` = no document gate (the default). A non-nil array gates to exactly
        // that set — so an *empty* array (a History scope whose project has engaged no documents
        // yet) matches nothing, rather than silently degrading to "search the whole corpus".
        if let docIds = filters.documentIds {
            if docIds.isEmpty {
                conditions.append("1 = 0")
            } else {
                appendChunkedKeyCondition(docIds, op: "IN", chunkJoin: " OR ")
            }
        }

        // Project Focus "only new" exclusion (#377 Phase 2b): drop already-engaged documents.
        // Contract: `nil`/empty = exclude nothing (unlike `documentIds`, an empty *exclusion*
        // is a no-op, not "match nothing").
        if let excludeIds = filters.excludeDocumentIds, !excludeIds.isEmpty {
            appendChunkedKeyCondition(excludeIds, op: "NOT IN", chunkJoin: " AND ")
        }

        if let range = filters.dateRange {
            // Interval overlap, matching documentKeysInDateRange: the document's
            // [date_iso, COALESCE(date_iso_max, date_iso)] range must intersect the
            // query bounds; undated documents are excluded when a range is active.
            conditions.append("dd.date_iso IS NOT NULL")
            if let earliest = range.earliest {
                conditions.append("COALESCE(dd.date_iso_max, dd.date_iso) >= ?")
                binds.append(earliest)
            }
            if let latest = range.latest {
                conditions.append("dd.date_iso <= ?")
                binds.append(latest)
            }
        }

        if !filters.includeFrontMatter {
            conditions.append("dc.is_front_matter = 0")
        }

        if let personRef = filters.personRef {
            conditions.append("""
                EXISTS (SELECT 1 FROM person_mentions pm
                        WHERE pm.volume_id = dc.volume_id
                          AND pm.document_id = dc.document_id
                          AND pm.person_ref = ?)
                """)
            binds.append(personRef)
        }

        if let rollupId = filters.personRollupId {
            // Cross-corpus person identity: any mention whose (volume_id, ref) belongs to the rollup.
            conditions.append("""
                EXISTS (SELECT 1 FROM person_mentions pm
                        JOIN person_rollup_member m ON m.volume_id = pm.volume_id AND m.ref = pm.person_ref
                        WHERE pm.volume_id = dc.volume_id
                          AND pm.document_id = dc.document_id
                          AND m.rollup_id = ?)
                """)
            binds.append(String(rollupId))
        }

        // Subject-tag filtering is retired (Session 9): the document-level subject
        // taxonomy was dropped for low signal-to-noise. `filters.subjectTagIds` is
        // retained on the persisted/CloudKit surfaces (SavedSearch, SearchParameters,
        // Project defaults) for schema stability but no longer contributes a WHERE
        // condition — otherwise a persisted saved search carrying now-retired subject
        // ids would silently filter every result out against the (now-empty) column.
        for tagId in filters.userTagIds {
            conditions.append("(' ' || COALESCE(dc.user_tag_ids, '') || ' ') LIKE ('% ' || ? || ' %')")
            binds.append(tagId)
        }

        switch filters.documentTypeFilter {
        case .documentsOnly:
            conditions.append("dc.is_editorial_note = 0")
        case .editorialNotesOnly:
            conditions.append("dc.is_editorial_note = 1")
        case .all:
            break
        }

        // Exact-word post-filter (Q-3b). Each `=` term must appear as a whole token in at
        // least one column the query actually searched, so the columns are ORed and the
        // terms ANDed.
        //
        // This lives in the WHERE clause rather than in Swift for one reason that matters
        // more than tidiness: `searchDocumentsCount` runs the same clause. Filtering rows
        // in Swift would leave the count reporting the stemmed superset — a number
        // strictly larger than the results, presented to a researcher writing a method
        // appendix. The plan calls that a silent lie and it is right.
        //
        // Terms with no in-scope column to check are skipped rather than rendered as an
        // empty `OR ()`, which is a syntax error; `exactColumns` is empty only on the
        // filter-only path, where there is no MATCH and therefore nothing to refine.
        if !filters.exactTerms.isEmpty, !filters.exactColumns.isEmpty {
            for term in filters.exactTerms {
                let checks = filters.exactColumns.map { "frus_exact_word(dc.\($0), ?) = 1" }
                conditions.append("(" + checks.joined(separator: " OR ") + ")")
                binds.append(contentsOf: Array(repeating: term, count: filters.exactColumns.count))
            }
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        return (whereClause, binds)
    }

    // MARK: - Date Range Query (used by SearchService)

    /// Returns a set of `"volumeId/documentId"` composite keys for documents whose
    /// date range overlaps `range`. Used by `SearchService` for date filtering.
    ///
    /// Uses interval overlap semantics rather than point containment:
    ///   - `date_iso` (range start) must be ≤ the query's latest bound
    ///   - `COALESCE(date_iso_max, date_iso)` (range end, falling back to start for
    ///     legacy rows) must be ≥ the query's earliest bound
    ///
    /// This correctly handles multi-day documents (`@from`/`@to`), imprecise year-only
    /// documents ("1969-01-01" to "1969-12-31"), and undated documents with
    /// `@notBefore`/`@notAfter` bounds — all of which would be excluded by a
    /// point-comparison query outside their encoded range.
    ///
    /// Documents without any parseable date (`date_iso IS NULL`) are always excluded
    /// when a range filter is active.
    func documentKeysInDateRange(_ range: DateRange, limitToVolumeIds volumeIds: [String]?) throws -> Set<String> {
        var parts: [String] = ["date_iso IS NOT NULL"]
        var args: [String] = []

        // Interval overlap: document_min <= queryEnd AND document_max >= queryStart.
        // COALESCE handles pre-version-5 rows where date_iso_max is NULL by treating
        // the single point date as both the min and max of the document's range.
        if let e = range.earliest {
            parts.append("COALESCE(date_iso_max, date_iso) >= ?")
            args.append(e)
        }
        if let l = range.latest {
            parts.append("date_iso <= ?")
            args.append(l)
        }

        if let vids = volumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            parts.append("volume_id IN (\(placeholders))")
            args.append(contentsOf: vids)
        }

        let sql = "SELECT volume_id, document_id FROM document_dates WHERE " + parts.joined(separator: " AND ")
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), arg, -1, SQLITE_TRANSIENT_IP)
        }

        var keys = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let vid = auxColumnString(stmt, 0), let did = auxColumnString(stmt, 1) {
                keys.insert("\(vid)/\(did)")
            }
        }
        return keys
    }

    // MARK: - Chronology Queries (used by ChronologyView)

    /// Returns the documents whose date interval overlaps `range`, ordered by date,
    /// joined with `document_cache` for display fields — the corpus-wide date browser's
    /// primary query.
    ///
    /// Uses the same interval-overlap semantics as `documentKeysInDateRange` (so multi-day
    /// and imprecise documents are included), but returns hydrated rows ordered by
    /// `date_iso` and capped at `limit`. The date range bounds the working set; callers
    /// should always pass a bounded `range`.
    ///
    /// - Parameters:
    ///   - range: Inclusive ISO date window. Either bound may be `nil` (open-ended).
    ///   - scopeVolumeIds: Optional volume restriction (e.g. a subseries expansion); `nil`
    ///     searches the whole corpus.
    ///   - ascending: Sort oldest-first when `true`, newest-first when `false`.
    ///   - limit: Hard cap on rows returned.
    func documentsInDateRange(
        _ range: DateRange,
        scopeVolumeIds: [String]?,
        ascending: Bool,
        limit: Int
    ) throws -> [ChronologyRow] {
        var parts: [String] = ["dd.date_iso IS NOT NULL"]
        var args: [String] = []
        if let e = range.earliest {
            parts.append("COALESCE(dd.date_iso_max, dd.date_iso) >= ?")
            args.append(e)
        }
        if let l = range.latest {
            parts.append("dd.date_iso <= ?")
            args.append(l)
        }
        if let vids = scopeVolumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            parts.append("dd.volume_id IN (\(placeholders))")
            args.append(contentsOf: vids)
        }

        let order = ascending ? "ASC" : "DESC"
        let sql = """
            SELECT dd.volume_id, dd.document_id, dc.header, dc.dateline, dc.summary_text,
                   dd.date_iso, dd.date_iso_max, dd.date_precision, dd.date_certainty,
                   dc.is_editorial_note, dc.is_front_matter, dc.document_number
            FROM document_dates dd
            JOIN document_cache dc
              ON dc.volume_id = dd.volume_id AND dc.document_id = dd.document_id
            WHERE \(parts.joined(separator: " AND "))
            ORDER BY dd.date_iso \(order), dc.document_number IS NULL, dd.document_id ASC
            LIMIT \(limit)
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), arg, -1, SQLITE_TRANSIENT_IP)
        }

        var rows: [ChronologyRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let vid = auxColumnString(stmt, 0),
                  let did = auxColumnString(stmt, 1),
                  let iso = auxColumnString(stmt, 5)
            else { continue }
            rows.append(ChronologyRow(
                volumeId: vid,
                documentId: did,
                header: auxColumnString(stmt, 2) ?? "",
                dateline: auxColumnString(stmt, 3),
                summary: auxColumnString(stmt, 4),
                dateISO: iso,
                dateISOMax: auxColumnString(stmt, 6),
                precision: DatePrecision(rawValue: auxColumnString(stmt, 7) ?? ""),
                certainty: DateCertainty(storageValue: auxColumnString(stmt, 8)),
                isEditorialNote: sqlite3_column_int(stmt, 9) != 0,
                isFrontMatter: sqlite3_column_int(stmt, 10) != 0,
                documentNumber: auxColumnString(stmt, 11)
            ))
        }
        return rows
    }

    /// Returns `(bucketKey, count)` pairs for documents overlapping `range`, grouped by a
    /// truncated `date_iso` prefix — `yyyy` (year), `yyyy-MM` (month), or `yyyy-MM-dd` (day).
    ///
    /// A cheap `GROUP BY` that powers section count badges, the auto-coarsening decision,
    /// and the optional density chart without materializing every row. Counts bucket each
    /// document at its `date_iso` (start) bucket.
    func dateBucketCounts(
        _ range: DateRange,
        bucket: DateBucket,
        scopeVolumeIds: [String]?
    ) throws -> [(key: String, count: Int)] {
        var parts: [String] = ["date_iso IS NOT NULL"]
        var args: [String] = []
        if let e = range.earliest {
            parts.append("COALESCE(date_iso_max, date_iso) >= ?")
            args.append(e)
        }
        if let l = range.latest {
            parts.append("date_iso <= ?")
            args.append(l)
        }
        if let vids = scopeVolumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            parts.append("volume_id IN (\(placeholders))")
            args.append(contentsOf: vids)
        }

        let sql = """
            SELECT substr(date_iso, 1, \(bucket.prefixLength)) AS bucket, COUNT(*)
            FROM document_dates
            WHERE \(parts.joined(separator: " AND "))
            GROUP BY bucket
            ORDER BY bucket ASC
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), arg, -1, SQLITE_TRANSIENT_IP)
        }

        var result: [(key: String, count: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let key = auxColumnString(stmt, 0) {
                result.append((key: key, count: Int(sqlite3_column_int(stmt, 1))))
            }
        }
        return result
    }

    /// Like `dateBucketCounts`, but additionally grouped by `volume_id` so the chronology
    /// distribution chart can build its stacked, per-volume series for an arbitrarily large
    /// range without materialising rows. Joins `document_cache` (indexed documents only) and
    /// excludes multi-year spanning documents (interval > 366 days), matching the chart's
    /// placed-document semantics and the `documentsInDateRange` list query.
    ///
    /// - Returns: `(bucketKey, volumeId, count)` tuples; the sum of counts is the bucketed
    ///   total used as the chart's headline count when the list is capped.
    func dateBucketVolumeCounts(
        _ range: DateRange,
        bucket: DateBucket,
        scopeVolumeIds: [String]?
    ) throws -> [(bucketKey: String, volumeId: String, count: Int)] {
        var parts: [String] = [
            "dd.date_iso IS NOT NULL",
            "julianday(COALESCE(dd.date_iso_max, dd.date_iso)) - julianday(dd.date_iso) <= 366"
        ]
        var args: [String] = []
        if let e = range.earliest {
            parts.append("COALESCE(dd.date_iso_max, dd.date_iso) >= ?")
            args.append(e)
        }
        if let l = range.latest {
            parts.append("dd.date_iso <= ?")
            args.append(l)
        }
        if let vids = scopeVolumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            parts.append("dd.volume_id IN (\(placeholders))")
            args.append(contentsOf: vids)
        }

        let sql = """
            SELECT substr(dd.date_iso, 1, \(bucket.prefixLength)) AS bucket, dd.volume_id, COUNT(*)
            FROM document_dates dd
            JOIN document_cache dc
              ON dc.volume_id = dd.volume_id AND dc.document_id = dd.document_id
            WHERE \(parts.joined(separator: " AND "))
            GROUP BY bucket, dd.volume_id
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), arg, -1, SQLITE_TRANSIENT_IP)
        }

        var result: [(bucketKey: String, volumeId: String, count: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let key = auxColumnString(stmt, 0), let vid = auxColumnString(stmt, 1) {
                result.append((bucketKey: key, volumeId: vid, count: Int(sqlite3_column_int(stmt, 2))))
            }
        }
        return result
    }

    // MARK: - Date Lookup (used by DocumentTimelineView)

    /// Returns ISO date strings keyed by `"volumeId/documentId"` for the given document pairs.
    ///
    /// Only pairs with a parseable `date_iso` value in `document_dates` are included.
    /// Unindexed or genuinely undated documents are absent from the result dictionary.
    ///
    /// Queries are issued in chunks of 499 to stay within SQLite's 999-variable limit.
    /// All pairs are queried; none are silently dropped.
    ///
    /// - Parameter docs: `(volumeId, documentId)` pairs to query.
    /// - Returns: Dictionary mapping composite key → `date_iso` string (e.g. `"1969-02-15"`).
    public func datesByDocumentKey(
        _ docs: [(volumeId: String, documentId: String)]
    ) throws -> [String: String] {
        guard !docs.isEmpty else { return [:] }
        // 499 key strings × 1 param/key = 499 — safely under the SQLite 999-variable cap.
        let chunkSize = 499
        let allKeys = docs.map { "\($0.volumeId)/\($0.documentId)" }
        var result: [String: String] = [:]
        for chunk in stride(from: 0, to: allKeys.count, by: chunkSize)
                .map({ Array(allKeys[$0..<min($0 + chunkSize, allKeys.count)]) }) {
            let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT volume_id || '/' || document_id, date_iso
                FROM document_dates
                WHERE volume_id || '/' || document_id IN (\(placeholders))
                AND date_iso IS NOT NULL
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, key) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let k = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                    result[k] = d
                }
            }
        }
        return result
    }

    /// Returns full date metadata (interval + precision + certainty) keyed by
    /// `"volumeId/documentId"` for the given document pairs.
    ///
    /// Like `datesByDocumentKey` but also carries `date_iso_max`, `date_precision`, and
    /// `date_certainty` so callers can render dates at their true granularity (e.g. show
    /// "1969" for a year-only document rather than the padded "1969-01-01"). Rows with a
    /// `NULL` `date_iso` are excluded. `precision`/`certainty` are `nil` for rows indexed
    /// before version 9.
    public func dateMetadataByDocumentKey(
        _ docs: [(volumeId: String, documentId: String)]
    ) throws -> [String: DocumentDateMetadata] {
        guard !docs.isEmpty else { return [:] }
        let chunkSize = 499
        let allKeys = docs.map { "\($0.volumeId)/\($0.documentId)" }
        var result: [String: DocumentDateMetadata] = [:]
        for chunk in stride(from: 0, to: allKeys.count, by: chunkSize)
                .map({ Array(allKeys[$0..<min($0 + chunkSize, allKeys.count)]) }) {
            let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT volume_id || '/' || document_id, date_iso, date_iso_max,
                       date_precision, date_certainty
                FROM document_dates
                WHERE volume_id || '/' || document_id IN (\(placeholders))
                AND date_iso IS NOT NULL
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, key) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let k = auxColumnString(stmt, 0), let iso = auxColumnString(stmt, 1) else { continue }
                result[k] = DocumentDateMetadata(
                    dateISO: iso,
                    dateISOMax: auxColumnString(stmt, 2),
                    precision: DatePrecision(rawValue: auxColumnString(stmt, 3) ?? ""),
                    certainty: DateCertainty(storageValue: auxColumnString(stmt, 4))
                )
            }
        }
        return result
    }

    /// Returns structured `document_sources` rows keyed by `"volumeId/documentId"` for
    /// the given document pairs (Authoring Phase 6 — the collections Sources & Archives
    /// block). Documents whose source note was never indexed, or that have no source
    /// note, are absent from the result. One row per document (the table's primary key).
    ///
    /// Queries are issued in chunks of 499 to stay within SQLite's 999-variable limit,
    /// mirroring `datesByDocumentKey`.
    ///
    /// - Parameter docs: `(volumeId, documentId)` pairs to query.
    /// - Returns: Dictionary mapping composite key → the parsed source-note fields.
    public func documentSourcesByKey(
        _ docs: [(volumeId: String, documentId: String)]
    ) throws -> [String: DocumentArchivalSource] {
        guard !docs.isEmpty else { return [:] }
        let chunkSize = 499
        let allKeys = docs.map { "\($0.volumeId)/\($0.documentId)" }
        var result: [String: DocumentArchivalSource] = [:]
        for chunk in stride(from: 0, to: allKeys.count, by: chunkSize)
                .map({ Array(allKeys[$0..<min($0 + chunkSize, allKeys.count)]) }) {
            let placeholders = chunk.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT volume_id || '/' || document_id, volume_id, document_id,
                       repository, record_group, lot_file, series_name, raw_text
                FROM document_sources
                WHERE volume_id || '/' || document_id IN (\(placeholders))
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, key) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let k = auxColumnString(stmt, 0) else { continue }
                result[k] = DocumentArchivalSource(
                    volumeId: auxColumnString(stmt, 1) ?? "",
                    documentId: auxColumnString(stmt, 2) ?? "",
                    repository: auxColumnString(stmt, 3),
                    recordGroup: auxColumnString(stmt, 4),
                    lotFile: auxColumnString(stmt, 5),
                    seriesName: auxColumnString(stmt, 6),
                    rawText: auxColumnString(stmt, 7) ?? "")
            }
        }
        return result
    }

    /// Returns every indexed document date as a single dictionary.
    ///
    /// Performs one full sequential scan of `document_dates` and returns a
    /// `[compositeKey: dateISO]` dictionary where the key is
    /// `"volumeId/documentId"` and the value is the `date_iso` string
    /// (e.g. `"1969-02-15"`). Rows with a `NULL` `date_iso` are excluded.
    ///
    /// The result is intended for analytics workloads that need per-document
    /// dates for the entire indexed corpus. At 316,839 rows (measured 2026-07-30) the
    /// dictionary fits comfortably in memory (< 15 MB). Callers should cache
    /// the result and invalidate it when the index changes.
    public func allDocumentDates() throws -> [String: String] {
        let sql = """
            SELECT volume_id || '/' || document_id, date_iso
            FROM document_dates
            WHERE date_iso IS NOT NULL
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        var result: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let k = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                result[k] = d
            }
        }
        return result
    }

    /// Returns **every** indexed document — including undated ones — as a
    /// `(volumeId, documentId, dateISO?)` triple.
    ///
    /// Unlike `allDocumentDates()`, which omits documents whose `date_iso` is
    /// `NULL` (or absent from `document_dates`), this enumerates the canonical set of
    /// indexed documents (`document_cache`) and LEFT JOINs their stored `date_iso`.
    /// Undated documents appear with a `nil` `dateISO`, letting analytics apply the
    /// same volume-start-year fallback the term-frequency numerator uses so the
    /// normalization denominator counts exactly the same document population as the
    /// numerator.
    ///
    /// The result is intended for the same analytics workloads as
    /// `allDocumentDates()` (316,839 rows, measured 2026-07-30), and callers should cache it and
    /// invalidate on index change.
    ///
    /// - Returns: One `(volumeId, documentId, dateISO)` triple per indexed document,
    ///   with `dateISO == nil` for undated documents.
    /// Returns every indexed document's `rowid` alongside its `(volumeId, documentId)` key.
    ///
    /// The map that lets an occurrence count be dated without joining `document_cache`.
    /// `FTS5Store.termOccurrencesByDocument(stem:)` returns rowids because joining them to their
    /// keys in SQL costs 40–90× more than the vocabulary scan itself — one page fault per matched
    /// document, on a table whose rows average 5.7 KB. Resolving them against this map instead moves
    /// the work to one sequential pass.
    ///
    /// **That pass is nearly free, and by accident.** `idx_document_cache_facet` — created for R-1's
    /// result-set facets, on `(is_front_matter, is_editorial_note, volume_id, document_id)` — is a
    /// *covering* index for this query, because every SQLite index entry carries the rowid. So all
    /// 316,839 rows come back in **0.114 s** without the fat table being touched. Confirm with
    /// `EXPLAIN QUERY PLAN`, which should say `SCAN document_cache USING COVERING INDEX
    /// idx_document_cache_facet`; if that index is ever dropped this becomes a 6.3 GB table scan.
    ///
    /// Cache it and invalidate on index change, like `allDocumentKeysWithDates()`.
    public func allDocumentRowidKeys() throws -> [(rowid: Int64, volumeId: String, documentId: String)] {
        let sql = "SELECT rowid, volume_id, document_id FROM document_cache"
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        var result: [(rowid: Int64, volumeId: String, documentId: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let v = auxColumnString(stmt, 1), let d = auxColumnString(stmt, 2) {
                result.append((rowid: sqlite3_column_int64(stmt, 0), volumeId: v, documentId: d))
            }
        }
        return result
    }

    public func allDocumentKeysWithDates() throws -> [(volumeId: String, documentId: String, dateISO: String?)] {
        let sql = """
            SELECT dc.volume_id, dc.document_id, dd.date_iso
            FROM document_cache dc
            LEFT JOIN document_dates dd
              ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        var result: [(volumeId: String, documentId: String, dateISO: String?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let v = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                result.append((volumeId: v, documentId: d, dateISO: auxColumnString(stmt, 2)))
            }
        }
        return result
    }

    // MARK: - Parsing (nonisolated — runs off the actor's executor for concurrency)

    nonisolated private func parseAndExtract(volumeId: String, url: URL) async throws -> VolumeIndexData {
        let parser = FRUSDocumentParser()
        // Single-pass parse: documents, persons, and terms extracted in one XML read.
        // Replaces three sequential XMLParser(contentsOf:) calls (passes 1-3) that
        // previously each read the entire volume file from disk.
        let fullResult = try await parser.parseVolumeFull(volumeURL: url)
        let astDocs = fullResult.documents

        var crossRefs: [CrossReferenceRow] = []
        var pageRangeRows: [PageRangeRow] = []
        var dateRows: [DocumentDateRow] = []
        var cacheRows: [DocumentCacheRow] = []
        var personMentionRows: [PersonMentionRow] = []

        for astDoc in astDocs {
            let did = astDoc.documentId
            let header     = Self.extractHeader(from: astDoc.nodes)
            let dateline   = Self.extractDateline(from: astDoc.nodes)
            let sourceNote = Self.extractSourceNote(from: astDoc.nodes)
            let bodyText   = Self.extractBodyText(from: astDoc.nodes)
            // Prefer the canonical history.state.gov document number — the div's `@n`,
            // present for every document including early-volume ones unnumbered in print —
            // so citations resolve to the HSG source. Fall back to the `<head>` leading
            // number only if `@n` is somehow absent.
            let docNumber  = astDoc.printedNumber ?? Self.extractDocumentNumber(from: astDoc.nodes)

            let isEditorialNote: Bool = {
                guard let first = astDoc.nodes.first, case .editorialNote = first else { return false }
                return true
            }()

            // Single recursive walk collects cross-refs, person refs, and page ranges
            // simultaneously (#4 — replaces 3 separate full-tree traversals per doc).
            var docCrossRefs: [CrossReferenceRow] = []
            var docPersonRefs: Set<String> = []
            var docPageRanges: [PageRangeRow] = []
            Self.collectDocumentRefs(
                from: astDoc.nodes,
                volumeId: volumeId, documentId: did,
                crossRefs: &docCrossRefs,
                personRefs: &docPersonRefs,
                pageRanges: &docPageRanges
            )
            crossRefs.append(contentsOf: docCrossRefs)
            pageRangeRows.append(contentsOf: docPageRanges)
            for ref in docPersonRefs {
                personMentionRows.append(PersonMentionRow(
                    volumeId: volumeId, documentId: did, personRef: ref))
            }

            let dateMeta = Self.extractDateMetadata(
                from: astDoc.nodes,
                dateTimeMin: astDoc.dateTimeMin,
                dateTimeMax: astDoc.dateTimeMax
            )
            dateRows.append(DocumentDateRow(
                volumeId: volumeId, documentId: did,
                dateISOMin: dateMeta.min, dateISOMax: dateMeta.max,
                precision: dateMeta.precision?.rawValue,
                certainty: dateMeta.certainty?.storageValue
            ))
            cacheRows.append(DocumentCacheRow(
                volumeId: volumeId, documentId: did, documentNumber: docNumber,
                header: header, dateline: dateline, sourceNote: sourceNote,
                // subject_tag_ids is retired (Session 9): the document-level subject
                // taxonomy was dropped for low signal-to-noise. The column is kept for
                // schema stability but written NULL — new and re-indexed rows carry no
                // subject ids. No `currentDateIndexVersion` bump (an empty derived column,
                // not a parse-semantics change).
                bodyText: bodyText, subjectTagIds: nil,
                userTagIds: nil, summaryText: nil, noteText: nil,
                isEditorialNote: isEditorialNote,
                isFrontMatter: astDoc.isFrontMatter
            ))
        }

        // Persons and terms were extracted in the same single-pass parse above.
        let personRows = fullResult.persons.map { p in
            PersonRow(volumeId: volumeId, ref: p.ref, name: p.name, description: p.description,
                      role: p.role, startYear: p.startYear, endYear: p.endYear)
        }
        let termRows = fullResult.terms.map { t in
            TermRow(volumeId: volumeId, ref: t.ref, term: t.term, definition: t.definition)
        }

        // Parse source notes into structured archival citation fields.
        // This is pure string processing — no I/O — so it adds negligible overhead
        // to the indexing pass but enables NARA Catalog queries and archive-browse
        // features without any API calls.
        let sourceNoteParser = SourceNoteParser()
        let documentSourceRows: [DocumentSourceRow] = cacheRows.compactMap { row in
            guard let raw = row.sourceNote, !raw.isEmpty else { return nil }
            let parsed = sourceNoteParser.parse(raw)
            var sourceRow = Self.documentSourceRow(
                volumeId: volumeId, documentId: row.documentId,
                parsed: parsed, rawText: raw
            )
            // S1 (Source Explorer Phase 1): sentence 2 of the note is classification
            // markings when it matches the marking vocabulary; conservative — nil
            // rather than junk. Store-only this phase.
            sourceRow.classification = SourceNoteParser.classificationMarking(fromSourceNote: raw)
            return sourceRow
        }

        // Extract embedded archival citations from editorial note body text.
        let footnoteSourceRows: [DocumentSourceRow] = cacheRows.compactMap { row in
            guard row.isEditorialNote, !row.bodyText.isEmpty else { return nil }
            let citations = sourceNoteParser.extractCitations(from: row.bodyText)
            guard let first = citations.first else { return nil }
            return DocumentSourceRow(
                volumeId: volumeId,
                documentId: row.documentId,
                repository: first.repository,
                recordGroup: first.recordGroup,
                lotFile: first.lotFile,
                seriesName: first.seriesName,
                citationEra: "footnote",
                rawText: first.rawText
            )
        }

        // Volume-level sources from front-matter (parsed by SourcesParserDelegate).
        let volumeSourceRows: [VolumeSourceRow] = fullResult.volumeSources
            .enumerated().map { i, entry in
                VolumeSourceRow(
                    volumeId: volumeId,
                    repository: entry.repository,
                    recordGroup: entry.recordGroup,
                    lotFile: entry.lotFile,
                    lotFileNorm: entry.lotFileNorm,
                    seriesName: entry.seriesName,
                    decimalClass: entry.decimalClass,
                    entryText: entry.rawText,
                    kind: entry.kind.rawValue,
                    depth: entry.depth,
                    isHeading: entry.isHeading,
                    sortOrder: i
                )
            }

        // JSON-encode the Browser structure captured during the same parse pass.
        // Failure is non-fatal: the Browser falls back to parsing the XML on demand.
        let structure = VolumeStructure(volumeId: volumeId, sections: fullResult.structureSections)
        let structureJSON = (try? JSONEncoder().encode(structure))
            .flatMap { String(data: $0, encoding: .utf8) }

        return VolumeIndexData(
            volumeId: volumeId, crossReferences: crossRefs,
            pageRanges: pageRangeRows, documentDates: dateRows, documentCache: cacheRows,
            personMentions: personMentionRows,
            persons: personRows,
            terms: termRows,
            documentSources: documentSourceRows + footnoteSourceRows,
            volumeSources: volumeSourceRows,
            structureJSON: structureJSON
        )
    }

    // MARK: - Storage

    private func storeIndexData(_ data: VolumeIndexData) async throws {
        guard !data.documentCache.isEmpty else { return }

        // --- document_cache insertion, batched for the iOS memory throttle ---
        //
        // document_cache is the single write path for document text: the sync
        // triggers created in setupDatabase() maintain the frus_documents and
        // user_content FTS5 tables from each row write, inside the same
        // transaction. On iOS, batchSize == 50 (or 20 under memory pressure); on
        // macOS it is effectively unlimited. Clamp to totalDocs so ceiling-division
        // and chunk-end arithmetic are overflow-safe even when effectiveBatchSize
        // == Int.max (the macOS sentinel meaning "process everything in one pass").
        let totalDocs = data.documentCache.count
        let batchSize = min(effectiveBatchSize, max(totalDocs, 1))
        let totalBatches = (totalDocs + batchSize - 1) / batchSize
        var processed = 0
        var batchNumber = 0

        // Remove cache rows for documents that no longer exist in this volume's
        // TEI (upstream revisions occasionally renumber or drop documents). The
        // UPSERT below updates surviving rows in place — preserving their rowid
        // (the FTS5 external-content key) and their user fields — so only genuinely
        // vanished documents need deleting. The DELETE trigger cleans both FTS5
        // tables for each removed row.
        try auxDeleteVanishedCacheRows(
            volumeId: data.volumeId,
            survivingDocumentIds: data.documentCache.map(\.documentId)
        )

        for chunkStart in stride(from: 0, to: totalDocs, by: batchSize) {
            batchNumber += 1
            let chunkEnd = min(chunkStart + batchSize, totalDocs)
            let cacheChunk = Array(data.documentCache[chunkStart..<chunkEnd])

            emitUpdate(IndexingProgressUpdate(
                volumeId: data.volumeId,
                stage: .storingBatch(current: batchNumber, total: totalBatches),
                completedDocuments: processed,
                totalDocuments: totalDocs,
                docsPerSecond: currentDocsPerSecond(forTotal: max(processed, 1))
            ))

            try auxInsertDocumentCache(cacheChunk)

            processed += cacheChunk.count
            volumeDocumentsProcessed = processed
            // Yield between batches so the OS can reclaim per-batch allocations.
            await Task.yield()
        }

        // --- Remaining auxiliary tables — separate transactions per operation ---
        //
        // IMPORTANT: do NOT combine these into a single monolithic transaction.
        //
        // `inTransaction` is entirely synchronous: it holds the IndexingPipeline
        // actor's executor thread with zero `await` points from BEGIN through COMMIT.
        // For a large compilation volume with thousands of cross-references, person
        // mentions, and page ranges the combined transaction can hold the actor for
        // 30–60+ seconds. During that window:
        //   - Concurrent parse tasks (up to 4 on macOS) complete their work but
        //     cannot deliver results; they queue on the actor and appear as
        //     "blocked events" in Instruments.
        //   - The SQLite write lock is held continuously, preventing WAL checkpoints
        //     and blocking any other connection that needs to write.
        //   - resolvePageBasedCrossReferences runs O(n) SELECT+UPDATE pairs inside
        //     the long-running transaction, further extending the block.
        //
        // The separate-transaction approach releases the write lock between each
        // operation, allowing the cooperative scheduler to interleave work and
        // keeping each individual lock window short (< 1 second per operation).
        //
        // The withTransactionIfNeeded helpers and inExternalTransaction parameters
        // are retained on each auxInsert* in case a future caller needs to compose
        // operations — just don't use them here.

        try auxDeleteCrossReferences(forVolumeId: data.volumeId)
        try auxDeletePersonMentions(forVolumeId: data.volumeId)
        try auxDeletePageRanges(forVolumeId: data.volumeId)

        try auxInsertCrossReferences(data.crossReferences)
        try auxInsertPageRanges(data.pageRanges)

        // Flag this volume's dead cross-references (#240B) BEFORE page resolution rewrites
        // target_document_id — broken refs keep their raw `pg_N` anchor at this point.
        try inTransaction {
            try markBrokenCrossReferences(volumeId: data.volumeId)
        }

        // Wrap the page-reference UPDATE loop in its own transaction (#2 fix retained).
        // The original code fired each UPDATE as an implicit autocommit — this keeps
        // correctness (atomic resolution) without holding a long combined transaction.
        try inTransaction {
            try resolvePageBasedCrossReferences(volumeId: data.volumeId)
        }

        try auxInsertDocumentDates(data.documentDates)
        try auxInsertPersonMentions(data.personMentions)
        try auxInsertPersons(data.persons)
        try auxInsertTerms(data.terms)
        try auxInsertDocumentSources(data.documentSources)
        // Clear this volume's prior source rows before re-inserting: INSERT OR REPLACE keys
        // on (volume_id, sort_order), so a re-index that yields *fewer* rows would otherwise
        // leave stale trailing rows (sort_order ≥ new count) behind as phantom entries.
        try auxDeleteVolumeSources(forVolumeId: data.volumeId)
        try auxInsertVolumeSources(data.volumeSources)
        try auxInsertVolumeStructure(volumeId: data.volumeId, structureJSON: data.structureJSON)
    }

    // MARK: - Progress

    private func emit(_ state: IndexingProgress.State) {
        progressContinuation.yield(IndexingProgress(state: state))
    }

    private func emitUpdate(_ update: IndexingProgressUpdate) {
        progressUpdateContinuation.yield(update)
    }

    private func emitMetadata(_ meta: VolumeMetadataDiscovered) {
        metadataContinuation.yield(meta)
    }

    private func buildMetadata(from data: VolumeIndexData) -> VolumeMetadataDiscovered {
        let isoDateStrings = data.documentDates.compactMap { $0.dateISOMin }
        let isoDateMaxStrings = data.documentDates.compactMap { $0.dateISOMax ?? $0.dateISOMin }
        let personNames = data.persons.sorted { $0.name < $1.name }.prefix(12).map { $0.name }
        return VolumeMetadataDiscovered(
            volumeId: data.volumeId,
            totalDocuments: data.documentCache.count,
            editorialNoteCount: data.documentCache.filter { $0.isEditorialNote }.count,
            uniquePersonCount: Set(data.personMentions.map { $0.personRef }).count,
            crossReferenceCount: data.crossReferences.count,
            datedDocumentCount: isoDateStrings.count,
            dateRangeMin: isoDateStrings.min(),
            dateRangeMax: isoDateMaxStrings.max(),
            glossaryPersonCount: data.persons.count,
            glossaryTermCount: data.terms.count,
            glossaryPersonNames: Array(personNames)
        )
    }

    /// Rolling throughput estimate: documents processed ÷ elapsed seconds.
    private func currentDocsPerSecond(forTotal total: Int) -> Double {
        guard let start = volumeIndexingStartTime, total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        return Double(total) / elapsed
    }

    // MARK: - Static Text Extraction Helpers

    /// Returns the document title from the first `.head` node, **excluding** any
    /// `.footnote` descendants.
    ///
    /// Every volume from 1955 on nests `<note type="source">` (and often regular
    /// numbered footnotes) inside `<head>`; including footnote text meant a 1955+
    /// document's stored header carried the entire source note (and pre-1955 headers
    /// carried head-level editorial footnotes). The exclusion is *recursive* — 68 corpus
    /// documents (frus1914Supp, frus1952-54v13p1, …) nest the head footnote one level
    /// deeper, inside `<hi>`/`<persName>`/`<p>` markup, so filtering only direct children
    /// still leaked those notes into the title. Excluding all footnote descendants yields
    /// the clean printed title everywhere `document_cache.header` surfaces (search
    /// results, browser rows, citations). Deliberate side effect of the Source Explorer
    /// Phase 1 extraction fix; repopulated by the version-15 reindex.
    nonisolated static func extractHeader(from nodes: [FRUSASTNode]) -> String {
        for node in nodes {
            if case .head(let c) = node {
                return c.map(\.plainTextExcludingFootnotes)
                    .joined(separator: " ").normalizedWhitespace
            }
        }
        return ""
    }

    nonisolated static func extractDateline(from nodes: [FRUSASTNode]) -> String? {
        for node in nodes {
            switch node {
            case .dateline(let c):
                let t = c.map(\.plainText).joined(separator: " ").normalizedWhitespace
                return t.isEmpty ? nil : t
            case .opener(let c):
                if let dl = extractDateline(from: c) { return dl }
            default: break
            }
        }
        return nil
    }

    /// Locates a document's provenance note, porting the Office of the Historian
    /// frus-sources locator chain (`import/import.xq`). Priority order:
    ///
    /// 1. **`<head>`-nested note containing `<seg type="source">`** — Nixon–Ford era
    ///    electronic volumes pair a `<seg type="summary">` with a `<seg type="source">`
    ///    inside the head footnote; only the source segment is the provenance note.
    /// 2. **`<head>`-nested `<note type="source">`** — the encoding used by every volume
    ///    from 1955 on. When the note holds multiple `<p>` children, the first paragraph
    ///    beginning `Source:` / `[Source:` is taken; otherwise the whole note.
    ///    **Gate:** a whole-note candidate that does *not* begin `Source:` / `[Source:`
    ///    is an editorial remark, not necessarily a citation (pre-1955 volumes nest
    ///    remarks like "Source text indicates this memorandum was dictated Nov. 13."
    ///    in `<head>`), so it is *deferred*: patterns 3/4 are consulted first and the
    ///    deferred text is used only when no top-level note yields anything. 29 corpus
    ///    documents carry both encodings (frus1949v01, frus1952-54v01p2/v03/v05p1/v07p1/
    ///    v14p1, frus1969-76ve10); in 25 of them the top-level note holds the real
    ///    decimal/lot citation and the head note is a remark. ~1,991 docs (mostly
    ///    frus1961-63 microfiche supplements and 1931–48 volumes) have a non-prefixed
    ///    head note and NO top-level alternative — the deferred fallback serves those.
    /// 3. **Top-level `<note type="source">`** — the 1861–1954 inline encoding (and
    ///    withheld-document `rend="inline"` provenance notes). Unchanged behaviour.
    /// 4. **Top-level untyped note containing `<seg type="source">`** — top-level
    ///    variant of pattern 1.
    ///
    /// Before this chain existed only pattern 3 was scanned, so ~77,000 documents in
    /// 1955–1991 volumes (which all use pattern 1/2) stored no source note at all.
    ///
    /// All returned text is passed through `normalizeSourceNoteWrapper` so the
    /// `[Source: …]` bracket wrapper collapses to `Source: …` — one stored shape across
    /// both encodings, and the `Source:` prefix is preserved so `SourceNoteParser`'s
    /// narrative branch (→ `citation_era='structured'` rows) fires.
    nonisolated static func extractSourceNote(from nodes: [FRUSASTNode]) -> String? {
        // Patterns 1 + 2: <head>-nested notes (1955+ encodings). A whole-note candidate
        // without a `Source:` prefix is deferred (see the pattern-2 gate in the doc
        // comment): when a top-level note also exists, the top-level text is the real
        // citation and the head note is an editorial remark.
        var deferredHeadNote: String?
        for node in nodes {
            guard case .head(let headChildren) = node else { continue }
            for child in headChildren {
                guard case .footnote(_, let type, _, let noteChildren) = child,
                      type == .source || type == .unclassified else { continue }
                if let seg = segSourceText(in: noteChildren) {
                    return normalizeSourceNoteWrapper(seg)
                }
                if type == .source, let body = sourceNoteBody(fromNoteChildren: noteChildren) {
                    if body.hasPrefix("Source:") || body.hasPrefix("[Source:") {
                        return normalizeSourceNoteWrapper(body)
                    }
                    if deferredHeadNote == nil { deferredHeadNote = body }
                }
            }
        }
        // Patterns 3 + 4: top-level notes (pre-1955 inline encoding).
        for node in nodes {
            guard case .footnote(_, let type, _, let noteChildren) = node else { continue }
            if type == .source {
                let t = noteChildren.map(\.plainText).joined(separator: " ").normalizedWhitespace
                if !t.isEmpty { return normalizeSourceNoteWrapper(t) }
            } else if type == .unclassified, let seg = segSourceText(in: noteChildren) {
                return normalizeSourceNoteWrapper(seg)
            }
        }
        // Deferred pattern-2 fallback: a non-`Source:`-prefixed head note with no
        // top-level alternative (~1,991 docs, e.g. frus1961-63 microfiche supplements).
        if let deferred = deferredHeadNote {
            return normalizeSourceNoteWrapper(deferred)
        }
        return nil
    }

    /// Returns the plain text of the first `<seg type="source">` in `nodes`, recursing
    /// into `.paragraph` wrappers (some volumes wrap each seg in a `<p>`). `<seg>` is not
    /// a first-class AST node — the parser preserves it as `.unknown("seg", …)`.
    /// Returns `nil` when no non-empty source segment exists.
    nonisolated static func segSourceText(in nodes: [FRUSASTNode]) -> String? {
        for node in nodes {
            switch node {
            case .unknown(let name, let attrs, let children)
                    where name == "seg" && attrs["type"] == "source":
                let t = children.map(\.plainText).joined(separator: " ").normalizedWhitespace
                if !t.isEmpty { return t }
            case .paragraph(let children):
                if let t = segSourceText(in: children) { return t }
            default:
                break
            }
        }
        return nil
    }

    /// Selects the provenance text from the children of a `<head>`-nested
    /// `<note type="source">`: when the note holds `<p>` children, the first paragraph
    /// whose text begins `Source:` / `[Source:` wins (some volumes put a summary
    /// paragraph first); otherwise the whole note's plain text. Returns `nil` for an
    /// empty note.
    nonisolated static func sourceNoteBody(fromNoteChildren noteChildren: [FRUSASTNode]) -> String? {
        for child in noteChildren {
            guard case .paragraph(let pChildren) = child else { continue }
            let t = pChildren.map(\.plainText).joined(separator: " ").normalizedWhitespace
            if t.hasPrefix("Source:") || t.hasPrefix("[Source:") { return t }
        }
        let whole = noteChildren.map(\.plainText).joined(separator: " ").normalizedWhitespace
        return whole.isEmpty ? nil : whole
    }

    /// Collapses the `[Source: …]` bracket wrapper (used for withheld-document
    /// provenance notes) to the unbracketed `Source: …` shape, so both TEI encodings
    /// store one consistent form. Text not wrapped in brackets is returned unchanged —
    /// in particular the bare pre-1955 decimal-file notes (`711.00/11–552`) and plain
    /// `Source: …` narratives keep their stored shape exactly.
    nonisolated static func normalizeSourceNoteWrapper(_ text: String) -> String {
        guard text.hasPrefix("[Source:"), text.hasSuffix("]") else { return text }
        let inner = text.dropFirst("[".count).dropLast("]".count)
        return String(inner).normalizedWhitespace
    }

    nonisolated static func extractBodyText(from nodes: [FRUSASTNode]) -> String {
        nodes.map(\.plainText).joined(separator: " ").normalizedWhitespace
    }

    /// Fallback document-number extractor that reads the leading number of the `<head>`
    /// text (e.g. "17. Editorial Note" → "17"), returning `nil` when the head does not begin
    /// with a number.
    ///
    /// Used only when the authoritative `@n` (`FRUSDocumentAST.printedNumber`, the canonical
    /// history.state.gov document number) is absent. Callers should prefer `@n`.
    nonisolated static func extractDocumentNumber(from nodes: [FRUSASTNode]) -> String? {
        for node in nodes {
            if case .head(let c) = node {
                let text = c.map(\.plainText).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let parts = text.split(separator: ".", maxSplits: 1)
                if let first = parts.first?.trimmingCharacters(in: .whitespaces), Int(first) != nil {
                    return first
                }
            }
        }
        return nil
    }

    // MARK: - Unified 3-way AST traversal (#4)

    /// Collects cross-references, person-name refs, and page ranges in a single
    /// recursive AST walk, replacing the three separate full-tree traversals that
    /// `extractCrossReferences`, `extractPersonRefs`, and `extractPageRanges` each
    /// performed independently.
    ///
    /// The existing `extract*` functions are kept for external callers (tests etc.);
    /// `parseAndExtract` uses this unified variant for indexing throughput.
    nonisolated static func collectDocumentRefs(
        from nodes: [FRUSASTNode],
        volumeId: String,
        documentId: String,
        parentReferenceType: String? = nil,
        enclosingText: String? = nil,
        crossRefs: inout [CrossReferenceRow],
        personRefs: inout Set<String>,
        pageRanges: inout [PageRangeRow]
    ) {
        for node in nodes {
            switch node {

            // ── Cross-references ───────────────────────────────────────────────
            case .crossReference(let target, let targetVolumeId, let children):
                let targetDocId = target.hasPrefix("#")
                    ? String(target.dropFirst())
                    : (target.components(separatedBy: "#").last ?? target)
                if !targetDocId.isEmpty {
                    crossRefs.append(CrossReferenceRow(
                        sourceVolumeId: volumeId, sourceDocumentId: documentId,
                        targetVolumeId: targetVolumeId, targetDocumentId: targetDocId,
                        referenceType: parentReferenceType ?? "footnote",
                        context: enclosingText
                    ))
                }
                collectDocumentRefs(from: children, volumeId: volumeId, documentId: documentId,
                    parentReferenceType: parentReferenceType, enclosingText: enclosingText,
                    crossRefs: &crossRefs, personRefs: &personRefs, pageRanges: &pageRanges)

            // ── Person-name links ──────────────────────────────────────────────
            case .persName(let ref, let children):
                if let ref, let normalised = normalizePersonRef(ref) {
                    personRefs.insert(normalised)
                }
                collectDocumentRefs(from: children, volumeId: volumeId, documentId: documentId,
                    parentReferenceType: parentReferenceType, enclosingText: enclosingText,
                    crossRefs: &crossRefs, personRefs: &personRefs, pageRanges: &pageRanges)

            // ── Page breaks ────────────────────────────────────────────────────
            case .pageBreak(let pageNumber):
                let type: String; let intVal: Int?; let raw: String
                switch pageNumber {
                case .arabic(let n):      (type, intVal, raw) = ("arabic", n, "\(n)")
                case .roman(let n):       (type, intVal, raw) = ("roman", n, "\(n)")
                case .prefixed(let s):    (type, intVal, raw) = ("prefixed", nil, s)
                case .unparseable(let s): (type, intVal, raw) = ("unparseable", nil, s)
                }
                pageRanges.append(PageRangeRow(
                    volumeId: volumeId, documentId: documentId, sectionId: documentId,
                    pageNumberType: type, pageNumberInt: intVal, pageNumberRaw: raw
                ))

            // ── Footnote — captures enclosing text for cross-ref context ───────
            case .footnote(_, let type, _, let children):
                let refType: String
                switch type {
                case .editorial: refType = "editorialNote"
                default:         refType = "footnote"
                }
                let noteText = truncateContext(
                    children.map(\.plainText).joined(separator: " ").normalizedWhitespace
                )
                collectDocumentRefs(from: children, volumeId: volumeId, documentId: documentId,
                    parentReferenceType: refType,
                    enclosingText: noteText.isEmpty ? nil : noteText,
                    crossRefs: &crossRefs, personRefs: &personRefs, pageRanges: &pageRanges)

            // ── Editorial notes — captures enclosing text ──────────────────────
            case .editorialNote(let children):
                let editorialText = truncateContext(
                    children.map(\.plainText).joined(separator: " ").normalizedWhitespace
                )
                collectDocumentRefs(from: children, volumeId: volumeId, documentId: documentId,
                    parentReferenceType: "editorialNote",
                    enclosingText: editorialText.isEmpty ? nil : editorialText,
                    crossRefs: &crossRefs, personRefs: &personRefs, pageRanges: &pageRanges)

            // ── All other nodes — recurse into children ────────────────────────
            default:
                collectDocumentRefs(from: node.children, volumeId: volumeId, documentId: documentId,
                    parentReferenceType: parentReferenceType, enclosingText: enclosingText,
                    crossRefs: &crossRefs, personRefs: &personRefs, pageRanges: &pageRanges)
            }
        }
    }

    /// Recursively extracts `<ref>` cross-references from an AST node array.
    ///
    /// When a `<ref>` element appears inside a `<note>` or `<div type="editorialNote">`,
    /// the surrounding note's plain text is captured and stored in `context` (truncated
    /// to 500 characters at the nearest word boundary). This allows the cross-reference
    /// graph view to display the surrounding passage as an edge label.
    ///
    /// `<ref>` elements that appear directly in a paragraph (not inside a note) receive
    /// `context: nil` because there is no meaningful enclosing text to surface.
    ///
    /// - Parameters:
    ///   - nodes: The AST nodes to search.
    ///   - sourceVolumeId: Volume ID of the document containing the `<ref>`.
    ///   - sourceDocumentId: Document ID of the document containing the `<ref>`.
    ///   - parentReferenceType: Reference type inherited from the enclosing note.
    ///   - enclosingText: Plain text of the immediately enclosing `<note>` or
    ///     `<div type="editorialNote">`, truncated to 500 characters. `nil` when
    ///     the `<ref>` is not inside any note element.
    nonisolated static func extractCrossReferences(
        from nodes: [FRUSASTNode],
        sourceVolumeId: String,
        sourceDocumentId: String,
        parentReferenceType: String? = nil,
        enclosingText: String? = nil
    ) -> [CrossReferenceRow] {
        var result: [CrossReferenceRow] = []
        for node in nodes {
            switch node {
            case .crossReference(let target, let targetVolumeId, let children):
                let targetDocId = target.hasPrefix("#")
                    ? String(target.dropFirst())
                    : (target.components(separatedBy: "#").last ?? target)
                if !targetDocId.isEmpty {
                    result.append(CrossReferenceRow(
                        sourceVolumeId: sourceVolumeId, sourceDocumentId: sourceDocumentId,
                        targetVolumeId: targetVolumeId, targetDocumentId: targetDocId,
                        referenceType: parentReferenceType ?? "footnote",
                        context: enclosingText
                    ))
                }
                result.append(contentsOf: extractCrossReferences(
                    from: children,
                    sourceVolumeId: sourceVolumeId, sourceDocumentId: sourceDocumentId,
                    parentReferenceType: parentReferenceType,
                    enclosingText: enclosingText
                ))
            case .footnote(_, let type, _, let children):
                let refType: String
                switch type {
                case .editorial: refType = "editorialNote"
                default:         refType = "footnote"
                }
                // Compute plain text of this note to pass as context for any <ref> inside it.
                let noteText = truncateContext(
                    children.map(\.plainText).joined(separator: " ").normalizedWhitespace
                )
                result.append(contentsOf: extractCrossReferences(
                    from: children,
                    sourceVolumeId: sourceVolumeId, sourceDocumentId: sourceDocumentId,
                    parentReferenceType: refType,
                    enclosingText: noteText.isEmpty ? nil : noteText
                ))
            case .editorialNote(let children):
                let editorialText = truncateContext(
                    children.map(\.plainText).joined(separator: " ").normalizedWhitespace
                )
                result.append(contentsOf: extractCrossReferences(
                    from: children,
                    sourceVolumeId: sourceVolumeId, sourceDocumentId: sourceDocumentId,
                    parentReferenceType: "editorialNote",
                    enclosingText: editorialText.isEmpty ? nil : editorialText
                ))
            default:
                result.append(contentsOf: extractCrossReferences(
                    from: node.children,
                    sourceVolumeId: sourceVolumeId, sourceDocumentId: sourceDocumentId,
                    parentReferenceType: parentReferenceType,
                    enclosingText: enclosingText
                ))
            }
        }
        return result
    }

    /// Truncates `text` to `maxLength` characters at the last word boundary within
    /// that limit, appending `"…"` when truncation occurs.
    ///
    /// Preserves the full text when it is ≤ `maxLength` characters.
    nonisolated private static func truncateContext(_ text: String, maxLength: Int = 500) -> String {
        guard text.count > maxLength else { return text }
        let prefix = text.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        // No word boundary found — hard truncate.
        return String(prefix) + "…"
    }

    /// Normalises a TEI `persName/@ref` to the bare per-volume person id used as the
    /// `persons`/`person_mentions` join key (people-eval finding E, date-index v13).
    ///
    /// Handles all three ref shapes found in the corpus:
    /// - `"p_AH1"` — already bare (returned as-is);
    /// - `"#p_AH1"` — same-volume fragment with the usual leading `#`;
    /// - `"frus1918Supp01v01#p_LR1"` — a split-set volume pointing its body at the sibling
    ///   part's persons list. Each part of a split set carries its own copy of the set's
    ///   persons list, so recording the mention under the bare fragment joins the mentioning
    ///   volume's own `persons` row (and its rollup membership) — storing the prefixed string
    ///   joined nothing and lost 6,486 mentions across 9 volumes.
    ///
    /// Returns `nil` for an empty ref or an empty fragment (`"vol#"`), which must produce no
    /// `person_mentions` row.
    nonisolated static func normalizePersonRef(_ ref: String) -> String? {
        guard let hash = ref.lastIndex(of: "#") else { return ref.isEmpty ? nil : ref }
        let fragment = String(ref[ref.index(after: hash)...])
        return fragment.isEmpty ? nil : fragment
    }

    /// Recursively collects all `ref` attribute values from `.persName` nodes.
    ///
    /// Returns a `Set<String>` so each `person_ref` appears at most once per document,
    /// regardless of how many times the name is mentioned. This matches the
    /// `person_mentions` table design: one row per unique person per document.
    ///
    /// Refs are normalised by `normalizePersonRef` (leading `#` and split-set `volumeId#`
    /// prefixes are stripped); `.persName` nodes with a nil/empty ref are excluded.
    nonisolated static func extractPersonRefs(from nodes: [FRUSASTNode]) -> Set<String> {
        var result = Set<String>()
        for node in nodes {
            if case .persName(let ref, let children) = node {
                if let ref, let normalised = normalizePersonRef(ref) {
                    result.insert(normalised)
                }
                result.formUnion(extractPersonRefs(from: children))
            } else {
                result.formUnion(extractPersonRefs(from: node.children))
            }
        }
        return result
    }

    nonisolated static func extractPageRanges(
        from nodes: [FRUSASTNode],
        volumeId: String,
        documentId: String
    ) -> [PageRangeRow] {
        var result: [PageRangeRow] = []
        for node in nodes {
            if case .pageBreak(let pageNumber) = node {
                let type: String; let intVal: Int?; let raw: String
                switch pageNumber {
                case .arabic(let n):      (type, intVal, raw) = ("arabic", n, "\(n)")
                case .roman(let n):       (type, intVal, raw) = ("roman", n, "\(n)")
                case .prefixed(let s):    (type, intVal, raw) = ("prefixed", nil, s)
                case .unparseable(let s): (type, intVal, raw) = ("unparseable", nil, s)
                }
                result.append(PageRangeRow(
                    volumeId: volumeId, documentId: documentId, sectionId: documentId,
                    pageNumberType: type, pageNumberInt: intVal, pageNumberRaw: raw
                ))
            } else {
                result.append(contentsOf: extractPageRanges(
                    from: node.children, volumeId: volumeId, documentId: documentId
                ))
            }
        }
        return result
    }

    // MARK: - Date Extraction

    /// Holds the date attributes from a single `<date>` AST node plus its context.
    private struct DateNodeInfo {
        let when: String?
        let from: String?
        let to: String?
        let notBefore: String?
        let notAfter: String?
        let inDateline: Bool
    }

    /// Recursively collects all `.date` AST nodes, tagging each with whether it appears
    /// inside a `.dateline`. Descends into `.opener` (datelines often live there) but
    /// does **not** descend into `.footnote` — footnote dates reference other documents
    /// and must not corrupt the enclosing document's own date index.
    nonisolated private static func collectDateNodes(
        _ nodes: [FRUSASTNode],
        inDateline: Bool
    ) -> [DateNodeInfo] {
        var results: [DateNodeInfo] = []
        for node in nodes {
            switch node {
            case .date(let when, let from, let to, let notBefore, let notAfter, let children):
                results.append(DateNodeInfo(when: when, from: from, to: to,
                                            notBefore: notBefore, notAfter: notAfter,
                                            inDateline: inDateline))
                results.append(contentsOf: collectDateNodes(children, inDateline: inDateline))
            case .dateline(let children):
                results.append(contentsOf: collectDateNodes(children, inDateline: true))
            case .opener(let children):
                results.append(contentsOf: collectDateNodes(children, inDateline: inDateline))
            case .footnote:
                break
            default:
                results.append(contentsOf: collectDateNodes(node.children, inDateline: inDateline))
            }
        }
        return results
    }

    /// Extracts the best available ISO 8601 date string from the document's AST nodes.
    ///
    /// Priority order:
    ///   1. `@when` on a `.date` node inside a `.dateline` — exact day-level date.
    ///   2. `@from` on a `.date` node inside a `.dateline` — range start.
    ///   3. `@notBefore` on a `.date` node inside a `.dateline` — approximate start.
    ///   4. `@when` on a `.date` node anywhere in the document body.
    ///   5. Plain-text heuristic (`parseDateISO`) applied to the dateline string — legacy fallback.
    ///
    /// Returns `nil` only when no date information of any kind can be extracted.
    nonisolated static func extractStructuredDate(from nodes: [FRUSASTNode]) -> String? {
        let dateNodes = collectDateNodes(nodes, inDateline: false)

        if let node = dateNodes.first(where: { $0.inDateline && $0.when != nil }),
           let value = node.when { return normalizeToFullDate(value) }
        if let node = dateNodes.first(where: { $0.inDateline && $0.from != nil }),
           let value = node.from { return normalizeToFullDate(value) }
        if let node = dateNodes.first(where: { $0.inDateline && $0.notBefore != nil }),
           let value = node.notBefore { return normalizeToFullDate(value) }
        if let node = dateNodes.first(where: { $0.when != nil }),
           let value = node.when { return normalizeToFullDate(value) }

        // Step 5: Plain-text heuristic on the dateline string (legacy fallback).
        if let datelineText = extractDateline(from: nodes) {
            return parseDateISO(from: datelineText)
        }
        return nil
    }

    /// Extracts the latest ISO 8601 date string representing the end of the document's
    /// date range. Used as `date_iso_max` when `frus:doc-dateTime-max` is absent.
    ///
    /// Priority:
    ///   1. `@to` on a `.date` inside a `.dateline` — explicit range end.
    ///   2. `@notAfter` on a `.date` inside a `.dateline` — uncertainty upper bound.
    ///   3. `@when` on a `.date` inside a `.dateline`, expanded to end-of-period.
    ///   4. `@when` on a `.date` anywhere in the document, expanded to end-of-period.
    nonisolated private static func extractStructuredDateMax(from nodes: [FRUSASTNode]) -> String? {
        let dateNodes = collectDateNodes(nodes, inDateline: false)

        if let node = dateNodes.first(where: { $0.inDateline && $0.to != nil }),
           let value = node.to { return normalizeToEndDate(value) }
        if let node = dateNodes.first(where: { $0.inDateline && $0.notAfter != nil }),
           let value = node.notAfter { return normalizeToEndDate(value) }
        if let node = dateNodes.first(where: { $0.inDateline && $0.when != nil }),
           let value = node.when { return normalizeToEndDate(value) }
        if let node = dateNodes.first(where: { $0.when != nil }),
           let value = node.when { return normalizeToEndDate(value) }
        return nil
    }

    /// Extracts the full date range (min, max) for a document.
    ///
    /// Uses the authoritative `frus:doc-dateTime-min`/`max` attributes from the document
    /// div when present — these are set by the HistoryAtState `update-frus-doc-dates.xsl`
    /// pipeline and represent the editors' curated date assessment. Falls back to
    /// deriving min from `extractStructuredDate` and max from `extractStructuredDateMax`
    /// for volumes not yet processed by that pipeline.
    ///
    /// The min date is normalized via `normalizeToFullDate` (earliest point in period);
    /// the max via `normalizeToEndDate` (latest point). For exact single-day documents,
    /// min and max are equal. For imprecise year-only documents, min = Jan 1 and
    /// max = Dec 31. This enables interval overlap filtering rather than point comparison.
    nonisolated static func extractDateRange(
        from nodes: [FRUSASTNode],
        dateTimeMin: String? = nil,
        dateTimeMax: String? = nil
    ) -> (min: String?, max: String?) {
        let min: String?
        if let dtMin = dateTimeMin {
            min = normalizeToFullDate(dtMin)
        } else {
            min = extractStructuredDate(from: nodes)
        }

        let max: String?
        if let dtMax = dateTimeMax {
            max = normalizeToEndDate(dtMax)
        } else {
            // Derive max from the date nodes, then fall back to expanding min to end-of-period
            // so that a year-only min of "1969-01-01" also produces a max of "1969-12-31".
            max = extractStructuredDateMax(from: nodes) ?? min.map { normalizeToEndDate($0) }
        }

        return (min: min, max: max)
    }

    /// Extracts the document's date interval **and** its original precision/certainty.
    ///
    /// `min`/`max` are identical to `extractDateRange` (the normalized full `yyyy-MM-dd`
    /// interval stored in `date_iso`/`date_iso_max`). `precision`/`certainty` are the new
    /// metadata: they describe the *original* TEI encoding before normalization, so the UI
    /// can render a year-only document as "1969" rather than the false "January 1, 1969"
    /// that the padded `date_iso` implies.
    ///
    /// - `precision` is derived from the component count of the raw `<date>` attribute that
    ///   wins the MIN selection (the same priority as `extractStructuredDate`). When the
    ///   value comes only from the authoritative `frus:doc-dateTime-*` attributes (no
    ///   `<date>` node), precision is `.day`. When it comes from the plain-text heuristic,
    ///   precision is `nil`.
    /// - `certainty` reflects which attribute drove the date: `.exact` (`@when`), `.range`
    ///   (`@from`/`@to`, or differing `doc-dateTime` bounds), `.approximate`
    ///   (`@notBefore`/`@notAfter`), or `.textOnly` (heuristic fallback).
    nonisolated static func extractDateMetadata(
        from nodes: [FRUSASTNode],
        dateTimeMin: String? = nil,
        dateTimeMax: String? = nil
    ) -> (min: String?, max: String?, precision: DatePrecision?, certainty: DateCertainty?) {
        let (minISO, maxISO) = extractDateRange(from: nodes, dateTimeMin: dateTimeMin, dateTimeMax: dateTimeMax)

        // Prefer the granularity of an explicit <date> attribute — it carries the editors'
        // original precision, which the resolved doc-dateTime bounds do not.
        let dateNodes = collectDateNodes(nodes, inDateline: false)
        if let win = winningMinDateAttribute(from: dateNodes) {
            return (minISO, maxISO, precisionOf(win.raw), win.certainty)
        }
        // Authoritative editorial bounds with no <date> attribute: day-precise; a range
        // when the two bounds resolve to different days.
        if let dtMin = dateTimeMin {
            let minDay = normalizeToFullDate(dtMin)
            let maxDay = dateTimeMax.map(normalizeToFullDate) ?? minDay
            return (minISO, maxISO, .day, minDay == maxDay ? .exact : .range)
        }
        // Date (if any) came from the plain-text heuristic on the dateline string.
        if minISO != nil {
            return (minISO, maxISO, nil, .textOnly)
        }
        return (nil, nil, nil, nil)
    }

    /// Returns the raw (un-normalized) date string and certainty that drive the document's
    /// MIN date, following the same priority order as `extractStructuredDate`.
    nonisolated private static func winningMinDateAttribute(
        from dateNodes: [DateNodeInfo]
    ) -> (raw: String, certainty: DateCertainty)? {
        if let n = dateNodes.first(where: { $0.inDateline && $0.when != nil }), let v = n.when {
            return (v, .exact)
        }
        if let n = dateNodes.first(where: { $0.inDateline && $0.from != nil }), let v = n.from {
            return (v, .range)
        }
        if let n = dateNodes.first(where: { $0.inDateline && $0.notBefore != nil }), let v = n.notBefore {
            return (v, .approximate)
        }
        if let n = dateNodes.first(where: { $0.when != nil }), let v = n.when {
            return (v, .exact)
        }
        return nil
    }

    /// Derives `DatePrecision` from the component count of a raw ISO date string
    /// (`"1969"` → `.year`, `"1969-02"` → `.month`, `"1969-02-15"` → `.day`). Any
    /// `xs:dateTime` time portion is stripped first.
    nonisolated private static func precisionOf(_ raw: String) -> DatePrecision {
        let dateOnly = raw.contains("T") ? String(raw.prefix(10)) : raw
        switch dateOnly.split(separator: "-", omittingEmptySubsequences: false).count {
        case 1:  return .year
        case 2:  return .month
        default: return .day
        }
    }

    /// Pads a partial ISO 8601 date string to full `yyyy-MM-dd` precision.
    ///
    /// TEI `@when`/`@from`/`@to` attributes may contain year-only ("1982") or
    /// year-month ("1982-04") values. Storing these as-is breaks the string-comparison
    /// date filter because "1982" < "1982-01-01" lexicographically, causing year-only
    /// documents to be excluded from ranges that include that year.
    ///
    /// Also handles xs:dateTime strings (containing "T") as produced by the
    /// `frus:doc-dateTime-min` attribute — the time portion is stripped before padding.
    ///
    /// Partial dates are treated as the earliest possible date in their period:
    ///   "1982"                         → "1982-01-01"
    ///   "1982-04"                      → "1982-04-01"
    ///   "1982-04-20"                   → "1982-04-20" (unchanged)
    ///   "1982-04-20T00:00:00-05:00"    → "1982-04-20" (time stripped, date unchanged)
    nonisolated static func normalizeToFullDate(_ iso: String) -> String {
        // xs:dateTime strings contain 'T'; extract the date-only portion.
        let dateOnly = iso.contains("T") ? String(iso.prefix(10)) : iso
        let parts = dateOnly.split(separator: "-", omittingEmptySubsequences: false)
        switch parts.count {
        case 1: return "\(dateOnly)-01-01"
        case 2: return "\(dateOnly)-01"
        default: return dateOnly
        }
    }

    /// Pads a partial ISO 8601 date string to its latest possible full `yyyy-MM-dd`.
    ///
    /// Counterpart to `normalizeToFullDate`. Used to compute the `date_iso_max` bound
    /// so that interval overlap filtering includes documents whose stated date range
    /// (e.g. a year-only `@when`) overlaps the query even when the query is mid-year.
    ///
    ///   "1982"                         → "1982-12-31"
    ///   "1982-04"                      → "1982-04-30"
    ///   "1982-04-20"                   → "1982-04-20" (unchanged)
    ///   "1982-04-20T23:59:59-05:00"    → "1982-04-20" (time stripped, date unchanged)
    nonisolated static func normalizeToEndDate(_ iso: String) -> String {
        let dateOnly = iso.contains("T") ? String(iso.prefix(10)) : iso
        let parts = dateOnly.split(separator: "-", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return "\(dateOnly)-12-31"
        case 2:
            let year  = Int(parts[0]) ?? 2000
            let month = Int(parts[1]) ?? 12
            let last  = Self.lastDayOfMonth(year: year, month: month)
            return String(format: "%@-%02d", dateOnly, last)
        default:
            return dateOnly
        }
    }

    /// Gregorian calendar instance shared across all `lastDayOfMonth` calls.
    /// Using a static constant avoids allocating one Calendar per document (316,839) during
    /// a full-corpus re-index (#8).
    nonisolated private static let gregorianCalendar = Calendar(identifier: .gregorian)

    /// Returns the last calendar day of `month` in `year` (Gregorian).
    nonisolated private static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year  = year
        comps.month = month + 1
        comps.day   = 0  // Day 0 of the following month = last day of this month.
        guard let date = gregorianCalendar.date(from: comps) else { return 30 }
        return gregorianCalendar.component(.day, from: date)
    }

    /// Best-effort ISO 8601 date extraction from a dateline string.
    ///
    /// **Legacy fallback only.** Prefer `extractStructuredDate(from:)` which reads
    /// machine-readable `@when`/`@from`/`@to` attributes directly from the AST.
    /// This method is retained only for documents whose `<dateline>` lacks a `<date>`
    /// child element with machine-readable attributes (common in older FRUS volumes
    /// and volumes not yet tagged with `<date when="...">` elements).
    ///
    /// Returns `nil` if no recognizable date pattern is found. Documents without a
    /// parseable date are excluded from date-range–filtered search results.
    nonisolated static func parseDateISO(from dateline: String) -> String? {
        // Strip trailing periods and city prefixes
        let cleaned = dateline
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try sliding window over comma-separated segments
        let segments = cleaned.components(separatedBy: ", ")
        let formats: [(String, String)] = [
            ("MMMM d yyyy",  "yyyy-MM-dd"),
            ("MMMM dd yyyy", "yyyy-MM-dd"),
            // Month-year: output as yyyy-MM, then normalizeToFullDate pads to yyyy-MM-01.
            ("MMMM yyyy",    "yyyy-MM"),
        ]
        for (inFmt, outFmt) in formats {
            formatter.dateFormat = inFmt
            for start in 0..<segments.count {
                for length in stride(from: segments.count - start, through: 1, by: -1) {
                    let candidate = segments[start..<(start + length)]
                        .joined(separator: " ")
                        .replacingOccurrences(of: ",", with: "")
                    if let date = formatter.date(from: candidate) {
                        formatter.dateFormat = outFmt
                        return normalizeToFullDate(formatter.string(from: date))
                    }
                }
            }
        }

        // Last resort: 4-digit year — normalize to yyyy-01-01 so string comparisons work.
        if let range = cleaned.range(of: #"\b(1[89]\d\d|20[012]\d)\b"#, options: .regularExpression) {
            return normalizeToFullDate(String(cleaned[range]))
        }
        return nil
    }

    // MARK: - File Discovery

    nonisolated static func findDownloadedVolumes(in directory: URL) -> [(volumeId: String, url: URL)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [] }
        return contents
            .filter { $0.pathExtension == "xml" }
            .map { (volumeId: $0.deletingPathExtension().lastPathComponent, url: $0) }
            .sorted { $0.volumeId < $1.volumeId }
    }

    // MARK: - Auxiliary Table DDL

    /// Called from `init` (nonisolated context) to configure WAL mode and create tables.
    private static func setupDatabase(_ db: OpaquePointer) throws {
        func exec(_ sql: String) throws {
            var errmsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
            guard rc == SQLITE_OK else {
                let msg = errmsg.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(errmsg)
                throw IndexingError.sqliteError(code: rc, message: msg)
            }
        }
        // Schema-introspection helpers for idempotent migrations. `name`/`table` are always
        // hardcoded literals here, so string interpolation is safe (no user input).
        func tableExists(_ name: String) -> Bool {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='\(name)' LIMIT 1"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            return sqlite3_step(stmt) == SQLITE_ROW
        }
        func columnExists(_ column: String, inTable table: String) -> Bool {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK
            else { return false }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let c = sqlite3_column_text(stmt, 1), String(cString: c) == column { return true }
            }
            return false
        }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        // Wait up to 5 s for a competing writer instead of failing immediately with
        // SQLITE_BUSY. The FTS5Store connection writes to the same file from a
        // different actor (e.g. background summarization updating summary_text while
        // a volume is being indexed here); without a busy timeout those collisions
        // surface as instant errors that `try?` callers silently swallow.
        try exec("PRAGMA busy_timeout = 5000")
        // Keep temporary structures (sort buffers, CTE materializations) in RAM.
        try exec("PRAGMA temp_store=MEMORY")
        try exec("""
            CREATE TABLE IF NOT EXISTS cross_references (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_volume_id TEXT NOT NULL,
                source_document_id TEXT NOT NULL,
                target_volume_id TEXT,
                target_document_id TEXT NOT NULL,
                is_broken INTEGER NOT NULL DEFAULT 0
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_crossref_source ON cross_references(source_volume_id, source_document_id)")
        try exec("CREATE INDEX IF NOT EXISTS idx_crossref_target ON cross_references(target_document_id)")
        // Migrate existing databases that predate Session 17. ALTER TABLE ignores
        // "duplicate column" errors so re-running on an up-to-date DB is safe.
        try? exec("ALTER TABLE cross_references ADD COLUMN reference_type TEXT")
        try? exec("ALTER TABLE cross_references ADD COLUMN context TEXT")
        // Idempotent migration (Session 7 / #240B): flags refs the corpus validation dataset
        // marks unresolvable, so the graph/analytics exclude them and the reading view degrades
        // them. NOT NULL + DEFAULT 0 is legal in ADD COLUMN because a default is supplied.
        try? exec("ALTER TABLE cross_references ADD COLUMN is_broken INTEGER NOT NULL DEFAULT 0")
        try exec("""
            CREATE TABLE IF NOT EXISTS page_ranges (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                section_id TEXT NOT NULL,
                page_number_type TEXT NOT NULL,
                page_number_int INTEGER,
                page_number_raw TEXT NOT NULL
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_page_ranges_volume ON page_ranges(volume_id, page_number_type, page_number_int)")
        try exec("CREATE INDEX IF NOT EXISTS idx_page_ranges_document ON page_ranges(volume_id, document_id)")
        try exec("""
            CREATE TABLE IF NOT EXISTS document_dates (
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                date_iso TEXT,
                date_iso_max TEXT,
                date_precision TEXT,
                date_certainty TEXT,
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        // Idempotent migration for databases that predate Session 76.
        try? exec("ALTER TABLE document_dates ADD COLUMN date_iso_max TEXT")
        // Idempotent migration for databases that predate Session 163 (precision/certainty).
        try? exec("ALTER TABLE document_dates ADD COLUMN date_precision TEXT")
        try? exec("ALTER TABLE document_dates ADD COLUMN date_certainty TEXT")
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_dates ON document_dates(date_iso)")
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_dates_max ON document_dates(date_iso_max)")
        try exec("""
            CREATE TABLE IF NOT EXISTS document_cache (
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                document_number TEXT,
                header TEXT NOT NULL,
                dateline TEXT,
                source_note TEXT,
                body_text TEXT NOT NULL,
                subject_tag_ids TEXT,
                user_tag_ids TEXT,
                summary_text TEXT,
                note_text TEXT,
                is_editorial_note INTEGER NOT NULL DEFAULT 0,
                is_front_matter   INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        // Idempotent migration for databases that predate Session 38.
        try? exec("ALTER TABLE document_cache ADD COLUMN is_editorial_note INTEGER NOT NULL DEFAULT 0")
        // Idempotent migration for databases that predate Session 2026-06-08 (front matter scope).
        try? exec("ALTER TABLE document_cache ADD COLUMN is_front_matter INTEGER NOT NULL DEFAULT 0")
        try exec("""
            CREATE TABLE IF NOT EXISTS person_mentions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                person_ref TEXT NOT NULL,
                UNIQUE(volume_id, document_id, person_ref) ON CONFLICT REPLACE
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_person_mentions_ref ON person_mentions(person_ref)")
        try exec("CREATE INDEX IF NOT EXISTS idx_person_mentions_doc ON person_mentions(volume_id, document_id)")
        // The facet-panel covering index (Q-M2 prerequisite, before R-1).
        //
        // `document_cache` had exactly one index — its PK autoindex — and the two flag
        // columns sit after `body_text` in the row, so any aggregate touching them read the
        // whole 1.8 GB table. Measured against the real 6.3 GB store, `"government"`
        // (195,519 matches):
        //
        //     document-type aggregate ... 11.6-14.4 s  ->  0.038 s
        //     volumes aggregate,
        //       front matter EXCLUDED ...      13.0 s  ->  0.043 s
        //
        // That second row is why this is not just about one two-row chart: with front
        // matter off — a user setting — the *whole* panel paid the scan. 8.47 MB, and the
        // planner picks it unprompted as `USING COVERING INDEX`.
        //
        // Column order is deliberate: the two filter flags first so they can be seeked,
        // then the identity pair so volume aggregation stays inside the index.
        //
        // No `currentDateIndexVersion` bump — an index is derived, not parse output.
        try exec("""
            CREATE INDEX IF NOT EXISTS idx_document_cache_facet
            ON document_cache(is_front_matter, is_editorial_note, volume_id, document_id)
            """)
        try exec("""
            CREATE TABLE IF NOT EXISTS persons (
                volume_id    TEXT NOT NULL,
                ref          TEXT NOT NULL,
                name         TEXT NOT NULL,
                description  TEXT,
                PRIMARY KEY (volume_id, ref)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(name)")
        // Role/era metadata (person rollup Phase 1). Idempotent — the persons list carries role text
        // and sometimes an active-year range after each name; these were previously discarded.
        // A reindex (currentDateIndexVersion bump) repopulates them on existing databases.
        try? exec("ALTER TABLE persons ADD COLUMN role TEXT")
        try? exec("ALTER TABLE persons ADD COLUMN start_year INTEGER")
        try? exec("ALTER TABLE persons ADD COLUMN end_year INTEGER")

        // Person rollup (Phase 0): a materialised cross-volume person index read by the People
        // browser. The per-volume `ref` is the TEI xml:id and is only meaningful within its volume
        // (it both collides across volumes and drifts for the same person), so the cross-corpus
        // identity must be precomputed — a live rollup over `person_mentions` is too slow on the
        // full corpus. `consolidatePersonRollup()` rebuilds these from `persons` + `person_mentions`;
        // they are rebuildable from the index (not user data). Phase 0 keys rollups by normalised
        // name; Phase 2 upgrades the builder to true clustering without changing this shape.
        // The composite index makes the scoped `(volume_id, ref)` mention join fast; the expression
        // index speeds normalised-name grouping. Both build on existing data at open (no reindex).
        try exec("CREATE INDEX IF NOT EXISTS idx_person_mentions_volref ON person_mentions(volume_id, person_ref)")
        try exec("CREATE INDEX IF NOT EXISTS idx_persons_namekey ON persons(lower(trim(name)))")
        try exec("""
            CREATE TABLE IF NOT EXISTS person_rollup (
                rollup_id      INTEGER PRIMARY KEY,
                namekey        TEXT NOT NULL,
                canonical_name TEXT NOT NULL,
                description    TEXT,
                mention_count  INTEGER NOT NULL DEFAULT 0
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_person_rollup_name ON person_rollup(canonical_name)")
        try exec("""
            CREATE TABLE IF NOT EXISTS person_rollup_member (
                volume_id TEXT NOT NULL,
                ref       TEXT NOT NULL,
                rollup_id INTEGER NOT NULL,
                PRIMARY KEY (volume_id, ref)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_person_rollup_member_rollup ON person_rollup_member(rollup_id)")
        // Role/era carried onto the rollup (Phase 1) so the People browser can show a `role · era`
        // subtitle without a per-row persons lookup. Idempotent; repopulated by consolidation.
        try? exec("ALTER TABLE person_rollup ADD COLUMN role TEXT")
        try? exec("ALTER TABLE person_rollup ADD COLUMN start_year INTEGER")
        try? exec("ALTER TABLE person_rollup ADD COLUMN end_year INTEGER")
        // Distinct volumes a cluster spans (Phase 4), for the "N volumes" row subtitle.
        try? exec("ALTER TABLE person_rollup ADD COLUMN volume_count INTEGER NOT NULL DEFAULT 0")
        // Authoritative identity from the bundled OOH crosswalk (Phase 5): the canonical person id
        // and an optional VIAF id. Present only for clusters keyed to the authority index.
        try? exec("ALTER TABLE person_rollup ADD COLUMN authority_id INTEGER")
        try? exec("ALTER TABLE person_rollup ADD COLUMN viaf_id TEXT")

        // Sub-threshold "possibly the same person" suggestions (Phase 2). The clusterer records pairs
        // of rollups it declined to auto-merge (under-merge bias) for later user confirmation; never
        // applied automatically. `rollup_id_a < rollup_id_b` by convention. Rebuilt by consolidation.
        try exec("""
            CREATE TABLE IF NOT EXISTS person_cluster_candidate (
                rollup_id_a INTEGER NOT NULL,
                rollup_id_b INTEGER NOT NULL,
                reason      TEXT,
                PRIMARY KEY (rollup_id_a, rollup_id_b)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_person_cluster_candidate_b ON person_cluster_candidate(rollup_id_b)")

        try exec("""
            CREATE TABLE IF NOT EXISTS terms (
                volume_id   TEXT NOT NULL,
                ref         TEXT NOT NULL,
                term        TEXT NOT NULL,
                definition  TEXT,
                PRIMARY KEY (volume_id, ref)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_terms_term ON terms(term)")

        // Session 130: archival citation tables.
        // Source Explorer Phase 1 (2026-07-03): `classification` column added (sentence 2
        // of the source note when it is classification markings, e.g. "Secret; Nodis").
        // Source Explorer Phase 2 (2026-07-03): `lot_file_norm` column added — the
        // canonical compact lot key (`SourceNoteParser.lotFileNorm`, e.g. "64D199")
        // stored alongside the raw `lot_file` so the Phase 3 matcher can use a single
        // indexed equality instead of a formatting-variant fan-out.
        // Source Explorer Phase 3 verification (2026-07-03): `decimal_class` column
        // added — the canonical decimal / subject-numeric class location
        // (`SourceNoteParser.decimalClassKey`, e.g. "POL 27 ARAB-ISR", "788.5"; dashes
        // hyphen-canonical) written for central-files-shaped citations so front-matter
        // class leaves resolve neighbors with a single indexed lookup. Before this,
        // the class location was unstored: structured rows kept only "Central Files
        // 1967–69" in series_name and narrative decimal rows often stored nothing.
        // The table is fully derived from the TEI, so an old-shape table (detected by
        // the absent newest column) is dropped and recreated — the established
        // volume_sources migration pattern; the version-19 reindex repopulates it.
        if tableExists("document_sources") && (!columnExists("lot_file_norm", inTable: "document_sources")
                                               || !columnExists("decimal_class", inTable: "document_sources")) {
            try? exec("DROP TABLE document_sources")
        }
        try exec("""
            CREATE TABLE IF NOT EXISTS document_sources (
                volume_id      TEXT NOT NULL,
                document_id    TEXT NOT NULL,
                repository     TEXT,
                record_group   TEXT,
                lot_file       TEXT,
                lot_file_norm  TEXT,
                series_name    TEXT,
                citation_era   TEXT NOT NULL DEFAULT 'unrecognized',
                raw_text       TEXT NOT NULL,
                classification TEXT,
                decimal_class  TEXT,
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_rg ON document_sources(record_group)")
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_repo ON document_sources(repository)")
        // Session 152: indexes for same-collection discovery queries
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_lot ON document_sources(lot_file)")
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_era_series ON document_sources(citation_era, series_name)")
        // Source Explorer Phase 2: normalized-lot equality lookups (Phase 3 matcher)
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_lot_norm ON document_sources(lot_file_norm)")
        // Source Explorer Phase 3 verification: class-leaf equality/prefix lookups
        try exec("CREATE INDEX IF NOT EXISTS idx_doc_src_class ON document_sources(decimal_class)")

        // Session 170: volume_sources rewritten to a prose + collection-outline model
        // (kind / depth / is_heading), and the primary key changed from
        // (volume_id, entry_text) to (volume_id, sort_order) so repeated collection headings
        // no longer silently de-duplicate. SQLite can't ALTER a primary key, so a pre-170
        // table (detected by the absent `kind` column) is dropped and recreated below. The
        // table is derived from the TEI, so it repopulates on the next (re)index.
        //
        // Source Explorer Phase 3 (2026-07-03): normalized match keys written at parse
        // time — `lot_file_norm` (canonical compact lot key, `SourceNoteParser.lotFileNorm`,
        // e.g. "64D199", the same normal form `document_sources.lot_file_norm` stores) and
        // `decimal_class` (decimal / subject-numeric class-leaf location in the shared
        // `SourceNoteParser.decimalClassKey` canonical form, e.g. "POL 27 ARAB-ISR" —
        // the same form `document_sources.decimal_class` stores). Same
        // drop-and-recreate migration pattern, keyed on the absent newest column; the
        // version-18/19 reindexes repopulate.
        if tableExists("volume_sources") && (!columnExists("kind", inTable: "volume_sources")
                                             || !columnExists("lot_file_norm", inTable: "volume_sources")) {
            try? exec("DROP TABLE volume_sources")
        }
        try exec("""
            CREATE TABLE IF NOT EXISTS volume_sources (
                volume_id     TEXT NOT NULL,
                repository    TEXT,
                record_group  TEXT,
                lot_file      TEXT,
                lot_file_norm TEXT,
                series_name   TEXT,
                decimal_class TEXT,
                entry_text    TEXT NOT NULL,
                kind          TEXT NOT NULL DEFAULT 'item',
                depth         INTEGER NOT NULL DEFAULT 0,
                is_heading    INTEGER NOT NULL DEFAULT 0,
                sort_order    INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (volume_id, sort_order)
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_vol_src_rg ON volume_sources(volume_id, record_group)")
        // Source Explorer Phase 3: normalized-lot lookups from the cross-volume /
        // collection-authority side (which volumes cite lot X?).
        try exec("CREATE INDEX IF NOT EXISTS idx_vol_src_lot_norm ON volume_sources(lot_file_norm)")

        // Session 2026-06-09: Browser structure cache. One JSON-encoded
        // `VolumeStructure` per indexed volume so browsing never re-parses XML.
        try exec("""
            CREATE TABLE IF NOT EXISTS volume_structures (
                volume_id      TEXT PRIMARY KEY,
                structure_json TEXT NOT NULL
            )
            """)

        // --- External-content FTS5 sync (Session 2026-06-09) ---
        //
        // `frus_documents` is created (and migrated) by `FTS5Store`, which is always
        // constructed before this pipeline (it is an init parameter). `user_content`
        // and the sync triggers are created here because they reference
        // `document_cache`, whose DDL lives above. All statements are idempotent.
        //
        // The triggers keep both FTS5 tables synchronised with `document_cache`:
        // INSERT/DELETE maintain both; the UPDATE OF triggers fire only when the
        // statement's SET list names one of that table's *indexed* columns, so a
        // summary/note update re-tokenizes only `user_content` and a re-index
        // UPSERT re-tokenizes only `frus_documents`.
        //
        // NOTE for future migrations: DROP the triggers before dropping either FTS5
        // table — orphaned triggers would make every document_cache write fail with
        // "no such table".
        try exec(FTS5Schema.userContent.createTableSQL(ifNotExists: true))
        for sql in FTS5Schema.frusDocuments.externalContentTriggerSQL() {
            try exec(sql)
        }
        for sql in FTS5Schema.userContent.externalContentTriggerSQL() {
            try exec(sql)
        }
    }

    // MARK: - Auxiliary Table DML

    private func auxInsertCrossReferences(_ rows: [CrossReferenceRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT INTO cross_references
            (source_volume_id, source_document_id, target_volume_id, target_document_id,
             reference_type, context)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.sourceVolumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.sourceDocumentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 3, row.targetVolumeId)
                sqlite3_bind_text(stmt, 4, row.targetDocumentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 5, row.referenceType)
                auxBindOptional(stmt, 6, row.context)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private func auxInsertPageRanges(_ rows: [PageRangeRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = "INSERT INTO page_ranges (volume_id, document_id, section_id, page_number_type, page_number_int, page_number_raw) VALUES (?, ?, ?, ?, ?, ?)"
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 3, row.sectionId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 4, row.pageNumberType, -1, SQLITE_TRANSIENT_IP)
                if let n = row.pageNumberInt { sqlite3_bind_int64(stmt, 5, Int64(n)) }
                else { sqlite3_bind_null(stmt, 5) }
                sqlite3_bind_text(stmt, 6, row.pageNumberRaw, -1, SQLITE_TRANSIENT_IP)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private func auxInsertDocumentDates(_ rows: [DocumentDateRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO document_dates
            (volume_id, document_id, date_iso, date_iso_max, date_precision, date_certainty)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 3, row.dateISOMin)
                auxBindOptional(stmt, 4, row.dateISOMax)
                auxBindOptional(stmt, 5, row.precision)
                auxBindOptional(stmt, 6, row.certainty)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    /// UPSERT for `document_cache` rows produced by the indexing parse.
    ///
    /// On conflict (re-index of an existing volume) the corpus fields are replaced
    /// but `user_tag_ids`, `summary_text`, and `note_text` are deliberately left
    /// untouched — those columns belong to user data synced from SwiftData, and the
    /// parse always produces `nil` for them. (The previous `INSERT OR REPLACE`
    /// silently wiped them on every re-index, leaving notes/summaries unsearchable
    /// until the next boot-time sync.) Keeping the same row also preserves its
    /// rowid, which the external-content FTS5 tables use as their key.
    ///
    /// The `DO UPDATE SET` list names the corpus columns, so only the
    /// `frus_documents` sync trigger (`AFTER UPDATE OF header, dateline,
    /// source_note, body_text`) fires — `user_content` is untouched.
    private static let documentCacheUpsertSQL = """
        INSERT INTO document_cache
        (volume_id, document_id, document_number, header, dateline, source_note, body_text,
         subject_tag_ids, user_tag_ids, summary_text, note_text, is_editorial_note,
         is_front_matter)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(volume_id, document_id) DO UPDATE SET
          document_number   = excluded.document_number,
          header            = excluded.header,
          dateline          = excluded.dateline,
          source_note       = excluded.source_note,
          body_text         = excluded.body_text,
          subject_tag_ids   = excluded.subject_tag_ids,
          is_editorial_note = excluded.is_editorial_note,
          is_front_matter   = excluded.is_front_matter
        """

    private func auxInsertDocumentCache(_ rows: [DocumentCacheRow]) throws {
        guard !rows.isEmpty else { return }
        // Use the pre-prepared statement when available (#7); fall back to
        // re-preparing if it was never initialised (e.g. in tests).
        let stmt: OpaquePointer
        var localStmt: OpaquePointer? = nil
        if let prepared = preparedCacheInsert {
            stmt = prepared
        } else {
            localStmt = try auxPrepare(Self.documentCacheUpsertSQL)
            stmt = localStmt!
        }
        defer { if let s = localStmt { sqlite3_finalize(s) } }

        // Defensive reset: if a previous call left the shared statement in a
        // stepped-but-not-reset state due to an error, clear it before use.
        // Without this, sqlite3_bind_* returns SQLITE_MISUSE, the bind values
        // are silently discarded, and auxStep fails with MISUSE too — triggering
        // a cascade where every subsequent volume fails the same way.
        sqlite3_reset(stmt)

        try inTransaction {
            for row in rows {
                defer { sqlite3_reset(stmt) }   // always reset, even when auxStep throws
                sqlite3_bind_text(stmt, 1, row.volumeId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 3, row.documentNumber)
                sqlite3_bind_text(stmt, 4, row.header, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 5, row.dateline)
                auxBindOptional(stmt, 6, row.sourceNote)
                sqlite3_bind_text(stmt, 7, row.bodyText, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 8, row.subjectTagIds)
                auxBindOptional(stmt, 9, row.userTagIds)
                auxBindOptional(stmt, 10, row.summaryText)
                auxBindOptional(stmt, 11, row.noteText)
                sqlite3_bind_int(stmt, 12, row.isEditorialNote ? 1 : 0)
                sqlite3_bind_int(stmt, 13, row.isFrontMatter  ? 1 : 0)
                try auxStep(stmt)
            }
        }
    }

    /// Stores (or replaces) the JSON-encoded Browser structure for a volume.
    /// A `nil` payload (encoding failed during parse) is a no-op.
    private func auxInsertVolumeStructure(volumeId: String, structureJSON: String?) throws {
        guard let structureJSON else { return }
        let stmt = try auxPrepare(
            "INSERT OR REPLACE INTO volume_structures (volume_id, structure_json) VALUES (?, ?)")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 2, structureJSON, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    /// Deletes `document_cache` rows for documents that disappeared from a volume's
    /// TEI between indexing runs.
    ///
    /// The surviving IDs are staged in a temp table (kept in memory by
    /// `temp_store=MEMORY`) so the `NOT IN` comparison is unbounded — chunking a
    /// `NOT IN` parameter list would change its semantics, and large compilation
    /// volumes exceed SQLite's 999-bind-variable limit.
    private func auxDeleteVanishedCacheRows(volumeId: String, survivingDocumentIds: [String]) throws {
        try auxExec("CREATE TEMP TABLE IF NOT EXISTS surviving_doc_ids (d TEXT PRIMARY KEY)")
        try auxExec("DELETE FROM surviving_doc_ids")
        defer { try? auxExec("DELETE FROM surviving_doc_ids") }

        let insert = try auxPrepare("INSERT OR IGNORE INTO surviving_doc_ids (d) VALUES (?)")
        defer { sqlite3_finalize(insert) }
        try inTransaction {
            for id in survivingDocumentIds {
                sqlite3_bind_text(insert, 1, id, -1, SQLITE_TRANSIENT_IP)
                try auxStep(insert)
                sqlite3_reset(insert)
            }
        }

        let delete = try auxPrepare("""
            DELETE FROM document_cache
            WHERE volume_id = ?
              AND document_id NOT IN (SELECT d FROM surviving_doc_ids)
            """)
        defer { sqlite3_finalize(delete) }
        sqlite3_bind_text(delete, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(delete)
    }

    private func auxInsertPersonMentions(_ rows: [PersonMentionRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = "INSERT OR REPLACE INTO person_mentions (volume_id, document_id, person_ref) VALUES (?, ?, ?)"
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 3, row.personRef,  -1, SQLITE_TRANSIENT_IP)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private func auxInsertPersons(_ rows: [PersonRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO persons (volume_id, ref, name, description, role, start_year, end_year)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,    -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.ref,         -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 3, row.name,        -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 4, row.description)
                auxBindOptional(stmt, 5, row.role)
                auxBindOptionalInt(stmt, 6, row.startYear)
                auxBindOptionalInt(stmt, 7, row.endYear)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }

        logger.debug("Inserted \(rows.count, privacy: .public) persons for \(rows.first?.volumeId ?? "?", privacy: .public)")
    }

    private func auxInsertTerms(_ rows: [TermRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO terms (volume_id, ref, term, definition)
            VALUES (?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,  -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.ref,       -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 3, row.term,      -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 4, row.definition)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }

        logger.debug("Inserted \(rows.count, privacy: .public) terms for \(rows.first?.volumeId ?? "?", privacy: .public)")
    }

    private func auxInsertDocumentSources(_ rows: [DocumentSourceRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO document_sources
            (volume_id, document_id, repository, record_group, lot_file, lot_file_norm, series_name, citation_era, raw_text, classification, decimal_class)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 3, row.repository)
                auxBindOptional(stmt, 4, row.recordGroup)
                auxBindOptional(stmt, 5, row.lotFile)
                auxBindOptional(stmt, 6, row.lotFileNorm)
                auxBindOptional(stmt, 7, row.seriesName)
                sqlite3_bind_text(stmt, 8, row.citationEra, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 9, row.rawText,     -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 10, row.classification)
                auxBindOptional(stmt, 11, row.decimalClass)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
        logger.debug("Inserted \(rows.count, privacy: .public) document_sources for \(rows.first?.volumeId ?? "?", privacy: .public)")
    }

    private func auxInsertVolumeSources(_ rows: [VolumeSourceRow], inExternalTransaction: Bool = false) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO volume_sources
            (volume_id, repository, record_group, lot_file, lot_file_norm, series_name,
             decimal_class, entry_text, kind, depth, is_heading, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withTransactionIfNeeded(inExternalTransaction) {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 2, row.repository)
                auxBindOptional(stmt, 3, row.recordGroup)
                auxBindOptional(stmt, 4, row.lotFile)
                auxBindOptional(stmt, 5, row.lotFileNorm)
                auxBindOptional(stmt, 6, row.seriesName)
                auxBindOptional(stmt, 7, row.decimalClass)
                sqlite3_bind_text(stmt, 8, row.entryText, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 9, row.kind, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_int64(stmt, 10, Int64(row.depth))
                sqlite3_bind_int64(stmt, 11, row.isHeading ? 1 : 0)
                sqlite3_bind_int64(stmt, 12, Int64(row.sortOrder))
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
        logger.debug("Inserted \(rows.count, privacy: .public) volume_sources for \(rows.first?.volumeId ?? "?", privacy: .public)")
    }

    /// Converts a `ParsedSourceNote` into a `DocumentSourceRow` for storage.
    ///
    /// Central-files-shaped citations (`.centralFiles`, `.cfpfFile`, and
    /// `.naraCollection` whose series names the central files) additionally store the
    /// canonical class location in `decimal_class` (`decimalClassRow(parsed:rawText:)`).
    nonisolated private static func documentSourceRow(
        volumeId: String, documentId: String,
        parsed: ParsedSourceNote, rawText: String
    ) -> DocumentSourceRow {
        var row = baseDocumentSourceRow(volumeId: volumeId, documentId: documentId,
                                        parsed: parsed, rawText: rawText)
        row.decimalClass = decimalClassColumn(parsed: parsed, rawText: rawText)
        return row
    }

    /// The `decimal_class` value for a document-source row: the canonical class
    /// location (`SourceNoteParser.decimalClassLocation(inCitation:)`) when the
    /// citation is central-files-shaped, else `nil`.
    ///
    /// Gated by classification so identifiers in other repositories' citations (CIA
    /// job numbers, council-document series, presidential-library box strings) can
    /// never masquerade as a class: only `.centralFiles` / `.cfpfFile` rows, and
    /// `.naraCollection` rows whose series segment names the central files
    /// ("Central Files 1967–69", "Central Foreign Policy File"), are scanned.
    nonisolated private static func decimalClassColumn(
        parsed: ParsedSourceNote, rawText: String
    ) -> String? {
        switch parsed {
        case .centralFiles, .cfpfFile:
            return SourceNoteParser.decimalClassLocation(inCitation: rawText)
        case .naraCollection(_, let series, _, _):
            guard let series,
                  series.localizedCaseInsensitiveContains("Central Files")
                    || series.localizedCaseInsensitiveContains("Central Foreign Policy")
            else { return nil }
            return SourceNoteParser.decimalClassLocation(inCitation: rawText)
        default:
            return nil
        }
    }

    /// The era/columns mapping for each `ParsedSourceNote` case (everything except the
    /// cross-case `decimal_class` column, which `documentSourceRow` fills).
    nonisolated private static func baseDocumentSourceRow(
        volumeId: String, documentId: String,
        parsed: ParsedSourceNote, rawText: String
    ) -> DocumentSourceRow {
        switch parsed {
        case .centralFiles(let rg, let fid):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: "Department of State", recordGroup: rg,
                lotFile: nil, seriesName: fid, citationEra: "decimal", rawText: rawText)
        case .lotFile(let rg, let lot, let fid):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: "Department of State", recordGroup: rg,
                lotFile: lot, seriesName: fid, citationEra: "lot_file", rawText: rawText,
                lotFileNorm: SourceNoteParser.lotFileNorm(lot))
        case .naraCollection(let rg, let series, let lot, let box):
            let sid = [series, box.map { "Box \($0)" }].compactMap { $0 }.joined(separator: ", ")
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: "National Archives", recordGroup: rg,
                lotFile: lot, seriesName: sid.isEmpty ? nil : sid, citationEra: "structured", rawText: rawText,
                lotFileNorm: lot.map { SourceNoteParser.lotFileNorm($0) })
        case .presidentialLibrary(let lib, let coll, _):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: lib, recordGroup: nil,
                lotFile: nil, seriesName: coll.isEmpty ? nil : coll, citationEra: "structured", rawText: rawText)
        case .ciaCollection(let job, _, _):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: "Central Intelligence Agency", recordGroup: nil,
                lotFile: job, seriesName: nil, citationEra: "structured", rawText: rawText)
        case .foreignGovernmentArchive(let desc):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: nil, recordGroup: nil,
                lotFile: nil, seriesName: desc.prefix(80).description, citationEra: "foreign", rawText: rawText)
        case .previouslyPublished:
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: nil, recordGroup: nil,
                lotFile: nil, seriesName: nil, citationEra: "published", rawText: rawText)
        case .cfpfFile(let fid):
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: "Department of State", recordGroup: "59",
                lotFile: nil, seriesName: fid.map { "CFPF \($0)" } ?? "CFPF", citationEra: "cfpf", rawText: rawText)
        case .namedFileSeries(let series, _):
            // No repository asserted at parse time: the series name is the match key
            // the Phase 3/4 collection-authority work resolves.
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: nil, recordGroup: nil,
                lotFile: nil, seriesName: series, citationEra: "named_series", rawText: rawText)
        case .unrecognized:
            return DocumentSourceRow(volumeId: volumeId, documentId: documentId,
                repository: nil, recordGroup: nil,
                lotFile: nil, seriesName: nil, citationEra: "unrecognized", rawText: rawText)
        }
    }

    /// Deletes all `cross_references` rows where `source_volume_id` matches.
    ///
    /// Called by `storeIndexData` before re-inserting so that re-indexing a volume
    /// does not accumulate duplicate edge rows.
    private func auxDeleteCrossReferences(forVolumeId volumeId: String) throws {
        let stmt = try auxPrepare("DELETE FROM cross_references WHERE source_volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    /// Deletes all `person_mentions` rows for a volume before re-inserting.
    private func auxDeletePersonMentions(forVolumeId volumeId: String) throws {
        let stmt = try auxPrepare("DELETE FROM person_mentions WHERE volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    /// Deletes all `page_ranges` rows for a volume before re-inserting.
    ///
    /// `page_ranges` uses plain `INSERT` with no UNIQUE constraint, so without this
    /// call every re-index of a volume doubles its page-range rows. The citation-lookup
    /// query joins on page ranges and would return duplicate entries silently.
    private func auxDeletePageRanges(forVolumeId volumeId: String) throws {
        let stmt = try auxPrepare("DELETE FROM page_ranges WHERE volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    private func auxDeleteVolumeSources(forVolumeId volumeId: String) throws {
        let stmt = try auxPrepare("DELETE FROM volume_sources WHERE volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    /// Resolves cross-references whose `target_document_id` is a printed-page anchor
    /// (`pg_{N}` where N is an arabic page number) to the document whose page **span**
    /// contains that page, according to the `page_ranges` table.
    ///
    /// FRUS TEI marks each printed page with `<pb n="427" xml:id="pg_427"/>` and points a
    /// reference at a page with `<ref target="#pg_427">`. The `#` is stripped at parse
    /// time (`collectDocumentRefs`), so the raw fragment `pg_427` is stored as
    /// `target_document_id`. This resolver rewrites those fragments to the containing
    /// document ID after indexing.
    ///
    /// ## Target format
    /// The real corpus uses the underscored, arabic form `pg_{digits}` (≈2M references).
    /// Roman / front-matter anchors (`pg_III`, `pg_XIX`, `pg_iii`, `pg_fm12`) point at
    /// front matter that has no `<div type="document">`, so they cannot be resolved and
    /// are deliberately left as unresolved `pg_*` fragments. Historic no-underscore forms
    /// (`p42` / `pg42`) appear essentially nowhere in the corpus and are no longer matched.
    ///
    /// ## Algorithm
    /// Uses the shared ``PageSpanResolver/documentContaining(page:in:)`` — the *same*
    /// span-containing algorithm the reader (`PageRangeStore.document(forPage:inVolume:)`)
    /// uses — rather than a naive exact `page_number_int = N` match, so a page that falls
    /// between two documents' opening `<pb>` elements resolves to its true container and
    /// the graph agrees with the footnote links.
    ///
    /// Called in `storeIndexData` after both `auxInsertCrossReferences` and
    /// `auxInsertPageRanges` are complete for the volume, so all page data is available.
    /// Same-volume resolution only — cross-volume page refs require the target volume
    /// to be indexed first and are left unresolved.
    private func resolvePageBasedCrossReferences(volumeId: String) throws {
        // Find cross-reference rows for this volume whose target is an arabic page anchor.
        // GLOB 'pg_[0-9]*' matches "pg_" followed by a digit (e.g. "pg_427"); roman
        // fragments like "pg_III" do not match and stay unresolved.
        //
        // `target_volume_id IS NULL` enforces the same-volume-only contract documented
        // above. Without it (index v21 and earlier), CROSS-volume page refs matched too and
        // were resolved against the SOURCE volume's pagination — rewriting
        // (frus1907p1, pg_773) into (frus1907p1, <some frus1910 doc id>): a fabricated edge
        // in every graph/analytics query, and a row the #240B broken-ref marking can no
        // longer match. currentDateIndexVersion 22 forces the reindex that heals those rows.
        let findSQL = """
            SELECT rowid, target_document_id
            FROM cross_references
            WHERE source_volume_id = ?
              AND target_volume_id IS NULL
              AND target_document_id GLOB 'pg_[0-9]*'
            """
        let findStmt = try auxPrepare(findSQL)
        defer { sqlite3_finalize(findStmt) }
        sqlite3_bind_text(findStmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)

        var toResolve: [(rowid: Int64, pageNum: Int)] = []
        while sqlite3_step(findStmt) == SQLITE_ROW {
            let rowid = sqlite3_column_int64(findStmt, 0)
            guard let pageId = auxColumnString(findStmt, 1) else { continue }
            // Strip the "pg_" prefix to extract the arabic page number.
            guard let pageNum = Int(pageId.dropFirst(3)), pageNum > 0 else { continue }
            toResolve.append((rowid: rowid, pageNum: pageNum))
        }
        guard !toResolve.isEmpty else { return }

        #if DEBUG
        print("[IndexingPipeline] resolvePageBasedCrossReferences: found \(toResolve.count) candidates in \(volumeId)")
        #endif

        // Fetch every arabic (documentId, page) row for this volume, grouped by section
        // (section_id is the containing document's xml:id, as inserted). Mirrors the
        // reader's query so both paths feed the shared resolver identical inputs.
        var sections: [String: [(documentId: String, pageInt: Int)]] = [:]
        let rowsSQL = """
            SELECT document_id, section_id, page_number_int
            FROM page_ranges
            WHERE volume_id = ? AND page_number_type = 'arabic' AND page_number_int IS NOT NULL
            ORDER BY section_id, page_number_int, rowid
            """
        let rowsStmt = try auxPrepare(rowsSQL)
        defer { sqlite3_finalize(rowsStmt) }
        sqlite3_bind_text(rowsStmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        while sqlite3_step(rowsStmt) == SQLITE_ROW {
            guard let docId = auxColumnString(rowsStmt, 0),
                  let section = auxColumnString(rowsStmt, 1) else { continue }
            let page = Int(sqlite3_column_int64(rowsStmt, 2))
            sections[section, default: []].append((documentId: docId, pageInt: page))
        }
        guard !sections.isEmpty else { return }

        let updateSQL = "UPDATE cross_references SET target_document_id = ? WHERE rowid = ?"
        let updateStmt = try auxPrepare(updateSQL)
        defer { sqlite3_finalize(updateStmt) }

        var resolvedCount = 0
        for (rowid, pageNum) in toResolve {
            // Probe each section's span; the first containing span wins (matches the
            // reader's `document(forPage:inVolume:)` section iteration).
            var docId: String?
            for rows in sections.values {
                if let hit = PageSpanResolver.documentContaining(page: pageNum, in: rows) {
                    docId = hit
                    break
                }
            }
            guard let docId else { continue }

            sqlite3_reset(updateStmt)
            sqlite3_bind_text(updateStmt, 1, docId, -1, SQLITE_TRANSIENT_IP)
            sqlite3_bind_int64(updateStmt, 2, rowid)
            sqlite3_step(updateStmt)
            resolvedCount += 1
        }

        #if DEBUG
        if resolvedCount > 0 {
            print("[IndexingPipeline] resolvePageBasedCrossReferences: resolved \(resolvedCount)/\(toResolve.count) page refs in \(volumeId)")
        }
        #endif
    }

    // MARK: - Broken cross-reference marking (#240B)

    /// Reconstructs the stored `(target_volume_id, target_document_id)` columns from a verbatim
    /// `<ref target>` value the way the indexer did (`collectDocumentRefs` splits the anchor;
    /// the volume prefix is the substring before the first `#`), so a broken-refs record can be
    /// matched back to its cross_references rows. Internal for direct test coverage.
    static func targetColumns(forRawTarget raw: String) -> (volumeId: String?, documentId: String) {
        let documentId = raw.hasPrefix("#")
            ? String(raw.dropFirst())
            : (raw.components(separatedBy: "#").last ?? raw)
        let volumeId: String?
        if raw.hasPrefix("#") || raw.hasPrefix("http") {
            volumeId = nil
        } else if let hash = raw.firstIndex(of: "#") {
            let prefix = String(raw[raw.startIndex..<hash])
            volumeId = prefix.isEmpty ? nil : prefix
        } else {
            volumeId = nil
        }
        return (volumeId, documentId)
    }

    /// Marks `cross_references.is_broken = 1` for a single volume's dead cross-references, matching
    /// the bundled broken-refs index (issue #240B).
    ///
    /// Volume-scoped: brokenness is a pure function of `(sourceVolume, rawTarget)` — a target that
    /// resolves nowhere in the target volume is broken in *every* source document — so this ignores
    /// `source_document_id`, which is both simpler and (unlike the bundle's `sd` key) able to reach
    /// the front/back-matter refs the reading view can't otherwise mark.
    ///
    /// MUST run before `resolvePageBasedCrossReferences` rewrites `target_document_id` for resolvable
    /// page refs — broken refs are precisely the page refs that pass never rewrites, so they keep
    /// their raw `pg_N` anchor here.
    private func markBrokenCrossReferences(volumeId: String) throws {
        guard let index = BrokenRefsIndexStore.shared else { return }
        let targets = index.degradableTargets.filter { $0.sourceVolume == volumeId }
            .map { (sourceVolume: $0.sourceVolume, rawTarget: $0.rawTarget) }
        try markBrokenCrossReferences(volumeId: volumeId, brokenTargets: targets)
    }

    /// The store-independent core of the per-volume marking (internal so tests can inject
    /// synthetic targets without a bundled index).
    ///
    /// - Parameters:
    ///   - volumeId: The source volume whose rows are marked.
    ///   - brokenTargets: `(sourceVolume, rawTarget)` pairs; entries for other volumes are ignored.
    func markBrokenCrossReferences(volumeId: String,
                                   brokenTargets: [(sourceVolume: String, rawTarget: String)]) throws {
        let targets = brokenTargets.filter { $0.sourceVolume == volumeId }
        guard !targets.isEmpty else { return }

        let sameVolSQL = "UPDATE cross_references SET is_broken = 1 " +
            "WHERE source_volume_id = ? AND target_volume_id IS NULL AND target_document_id = ?"
        let crossVolSQL = "UPDATE cross_references SET is_broken = 1 " +
            "WHERE source_volume_id = ? AND target_volume_id = ? AND target_document_id = ?"
        let sameStmt = try auxPrepare(sameVolSQL)
        defer { sqlite3_finalize(sameStmt) }
        let crossStmt = try auxPrepare(crossVolSQL)
        defer { sqlite3_finalize(crossStmt) }

        var marked = 0
        for target in targets {
            let cols = Self.targetColumns(forRawTarget: target.rawTarget)
            guard !cols.documentId.isEmpty else { continue }
            if let tvol = cols.volumeId {
                sqlite3_reset(crossStmt)
                sqlite3_bind_text(crossStmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(crossStmt, 2, tvol, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(crossStmt, 3, cols.documentId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_step(crossStmt)
            } else {
                sqlite3_reset(sameStmt)
                sqlite3_bind_text(sameStmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(sameStmt, 2, cols.documentId, -1, SQLITE_TRANSIENT_IP)
                sqlite3_step(sameStmt)
            }
            marked += Int(sqlite3_changes(auxDb))
        }

        #if DEBUG
        if marked > 0 {
            print("[IndexingPipeline] markBrokenCrossReferences: flagged \(marked) rows in \(volumeId)")
        }
        #endif
    }

    /// One-shot, idempotent retroactive backfill of `cross_references.is_broken` for a corpus indexed
    /// before this feature shipped (or before the bundled index was last refreshed). Gated on the
    /// applied `generated` stamp so it re-runs when the index changes and is a no-op otherwise;
    /// resets every flag first so a *shrinking* index (a ref the editors have since fixed) un-marks.
    ///
    /// Volumes indexed after the marker is current are covered by the per-volume `markBrokenCrossReferences`
    /// on their next (re)index; this covers everything already on disk.
    public func applyBrokenRefsIndexIfNeeded() throws {
        guard let index = BrokenRefsIndexStore.shared else { return }
        let applied = UserDefaults.standard.string(forKey: Self.brokenRefsIndexAppliedKey)
        guard applied != index.generated else { return }

        let targets = index.degradableTargets.map { (sourceVolume: $0.sourceVolume, rawTarget: $0.rawTarget) }
        let marked = try applyBrokenRefsIndex(targets: targets)

        #if DEBUG
        print("[IndexingPipeline] applyBrokenRefsIndexIfNeeded: flagged \(marked) rows for index \(index.generated)")
        #endif

        UserDefaults.standard.set(index.generated, forKey: Self.brokenRefsIndexAppliedKey)
    }

    /// The store/marker-independent core of the backfill (internal so tests can inject synthetic
    /// targets): resets every `is_broken` flag, then re-marks from `targets` in one transaction —
    /// so a *shrinking* index un-marks refs the editors have since fixed.
    ///
    /// - Parameter targets: `(sourceVolume, rawTarget)` pairs to mark corpus-wide.
    /// - Returns: The number of rows flagged.
    @discardableResult
    func applyBrokenRefsIndex(targets: [(sourceVolume: String, rawTarget: String)]) throws -> Int {
        var marked = 0
        try inTransaction {
            try auxExec("UPDATE cross_references SET is_broken = 0")

            let sameVolSQL = "UPDATE cross_references SET is_broken = 1 " +
                "WHERE source_volume_id = ? AND target_volume_id IS NULL AND target_document_id = ?"
            let crossVolSQL = "UPDATE cross_references SET is_broken = 1 " +
                "WHERE source_volume_id = ? AND target_volume_id = ? AND target_document_id = ?"
            let sameStmt = try auxPrepare(sameVolSQL)
            defer { sqlite3_finalize(sameStmt) }
            let crossStmt = try auxPrepare(crossVolSQL)
            defer { sqlite3_finalize(crossStmt) }

            for target in targets {
                let cols = Self.targetColumns(forRawTarget: target.rawTarget)
                guard !cols.documentId.isEmpty else { continue }
                if let tvol = cols.volumeId {
                    sqlite3_reset(crossStmt)
                    sqlite3_bind_text(crossStmt, 1, target.sourceVolume, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_bind_text(crossStmt, 2, tvol, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_bind_text(crossStmt, 3, cols.documentId, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_step(crossStmt)
                } else {
                    sqlite3_reset(sameStmt)
                    sqlite3_bind_text(sameStmt, 1, target.sourceVolume, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_bind_text(sameStmt, 2, cols.documentId, -1, SQLITE_TRANSIENT_IP)
                    sqlite3_step(sameStmt)
                }
                marked += Int(sqlite3_changes(auxDb))
            }
        }
        return marked
    }

    private func auxDeleteVolume(_ volumeId: String) throws {
        for (table, col) in [
            ("cross_references",  "source_volume_id"),
            ("page_ranges",       "volume_id"),
            ("document_dates",    "volume_id"),
            ("document_cache",    "volume_id"),
            ("person_mentions",   "volume_id"),
            ("persons",           "volume_id"),
            ("terms",             "volume_id"),
            ("document_sources",  "volume_id"),
            ("volume_sources",    "volume_id"),
            ("volume_structures", "volume_id"),
        ] {
            let stmt = try auxPrepare("DELETE FROM \(table) WHERE \(col) = ?")
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
            try auxStep(stmt)
        }
    }

    /// Returns the indexed body text for a single document, or `nil` if not yet indexed.
    public func fetchDocumentBodyText(volumeId: String, documentId: String) throws -> String? {
        try fetchCache(volumeId: volumeId, documentId: documentId)?.bodyText
    }

    // MARK: - Word Cloud Support

    /// Returns the body text of every document whose key is in `keys`, in
    /// arbitrary order. Missing or unindexed keys are silently skipped.
    ///
    /// Used by the word-cloud pipeline to gather the text of a bounded scope
    /// (volume, subseries, collection, user tag, saved search). Keys are queried
    /// in chunks via a `WITH wanted(v, d) AS (VALUES …)` CTE joined against the
    /// `document_cache` composite primary key, so SQLite performs index
    /// point-lookups rather than a full scan. Each chunk of 400 pairs binds 800
    /// parameters (within the 999-parameter limit).
    ///
    /// - Parameter keys: The document keys to fetch text for.
    /// - Returns: The non-empty body texts of the matched documents.
    func documentBodyTexts(forKeys keys: [WordCloudDocumentKey]) throws -> [String] {
        guard !keys.isEmpty else { return [] }
        var result: [String] = []
        result.reserveCapacity(keys.count)
        let chunkSize = 400
        var index = 0
        while index < keys.count {
            let chunk = Array(keys[index..<min(index + chunkSize, keys.count)])
            index += chunkSize
            let values = Array(repeating: "(?,?)", count: chunk.count).joined(separator: ",")
            let sql = """
                WITH wanted(v, d) AS (VALUES \(values))
                SELECT dc.body_text
                FROM document_cache dc
                JOIN wanted ON wanted.v = dc.volume_id AND wanted.d = dc.document_id
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            var bind: Int32 = 1
            for key in chunk {
                sqlite3_bind_text(stmt, bind, key.volumeId, -1, SQLITE_TRANSIENT_IP); bind += 1
                sqlite3_bind_text(stmt, bind, key.documentId, -1, SQLITE_TRANSIENT_IP); bind += 1
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let text = auxColumnString(stmt, 0), !text.isEmpty { result.append(text) }
            }
        }
        return result
    }

    /// Body text for the given documents, **keyed** by `"volumeId/documentId"`.
    ///
    /// The sibling ``documentBodyTexts(forKeys:)`` returns a bare `[String]`, which is right for the
    /// word cloud — it tokenises the lot and never asks which document a word came from. A
    /// concordance does ask: every line names its source document, so the body has to arrive
    /// attached to its key. The join does not preserve the order of the `VALUES` list and silently
    /// omits documents that are not in the cache, so zipping the array against the input keys would
    /// mis-attribute quotations to the wrong documents — the worst possible failure for a tool whose
    /// output is quoted evidence.
    ///
    /// Chunked like its sibling to stay under SQLite's variable limit.
    func documentBodyTextsByKey(forKeys keys: [WordCloudDocumentKey]) throws -> [String: String] {
        guard !keys.isEmpty else { return [:] }
        var result: [String: String] = [:]
        let chunkSize = 400
        var index = 0
        while index < keys.count {
            let chunk = Array(keys[index..<min(index + chunkSize, keys.count)])
            index += chunkSize
            let values = Array(repeating: "(?,?)", count: chunk.count).joined(separator: ",")
            let sql = """
                WITH wanted(v, d) AS (VALUES \(values))
                SELECT dc.volume_id, dc.document_id, dc.body_text
                FROM document_cache dc
                JOIN wanted ON wanted.v = dc.volume_id AND wanted.d = dc.document_id
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            var bind: Int32 = 1
            for key in chunk {
                sqlite3_bind_text(stmt, bind, key.volumeId, -1, SQLITE_TRANSIENT_IP); bind += 1
                sqlite3_bind_text(stmt, bind, key.documentId, -1, SQLITE_TRANSIENT_IP); bind += 1
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let volumeId = auxColumnString(stmt, 0),
                      let documentId = auxColumnString(stmt, 1),
                      let text = auxColumnString(stmt, 2), !text.isEmpty else { continue }
                result["\(volumeId)/\(documentId)"] = text
            }
        }
        return result
    }

    /// Returns a short context snippet per document, keyed by `"volumeId/documentId"` — the
    /// leading text a find-related row shows so a researcher can judge relevance (#362).
    ///
    /// Prefers the on-device summary (`summary_text`) when present, else a leading excerpt of the
    /// body text; both are whitespace-collapsed and truncated at a word boundary to `maxLength`.
    /// A document with neither (or an unindexed one) is simply absent from the result. Keys are
    /// point-looked-up through the composite primary key in 400-pair chunks, so this is bounded to
    /// the (small) set of shown rows — never a scan.
    ///
    /// - Parameters:
    ///   - keys: The document keys to fetch snippets for.
    ///   - maxLength: Maximum snippet length in characters.
    /// - Returns: `"volumeId/documentId" → snippet` for the documents that have text.
    func documentSnippets(forKeys keys: [(volumeId: String, documentId: String)],
                          maxLength: Int = 240) throws -> [String: String] {
        guard !keys.isEmpty else { return [:] }
        var result: [String: String] = [:]
        let chunkSize = 400
        var index = 0
        while index < keys.count {
            let chunk = Array(keys[index..<min(index + chunkSize, keys.count)])
            index += chunkSize
            let values = Array(repeating: "(?,?)", count: chunk.count).joined(separator: ",")
            let sql = """
                WITH wanted(v, d) AS (VALUES \(values))
                SELECT dc.volume_id, dc.document_id, dc.summary_text, dc.body_text
                FROM document_cache dc
                JOIN wanted ON wanted.v = dc.volume_id AND wanted.d = dc.document_id
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            var bind: Int32 = 1
            for key in chunk {
                sqlite3_bind_text(stmt, bind, key.volumeId, -1, SQLITE_TRANSIENT_IP); bind += 1
                sqlite3_bind_text(stmt, bind, key.documentId, -1, SQLITE_TRANSIENT_IP); bind += 1
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let volumeId = auxColumnString(stmt, 0),
                      let documentId = auxColumnString(stmt, 1) else { continue }
                let summary = auxColumnString(stmt, 2)
                let body = auxColumnString(stmt, 3)
                let source = (summary?.isEmpty == false ? summary : body) ?? ""
                let snippet = Self.snippet(from: source, maxLength: maxLength)
                if !snippet.isEmpty { result["\(volumeId)/\(documentId)"] = snippet }
            }
        }
        return result
    }

    /// Whitespace-collapses `text` and truncates it to `maxLength` at the nearest preceding word
    /// boundary, appending an ellipsis when cut. Returns "" for empty input.
    nonisolated static func snippet(from text: String, maxLength: Int) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > maxLength else { return collapsed }
        let cut = collapsed.prefix(maxLength)
        let trimmed = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)
        return trimmed + "…"
    }

    /// Returns the `(volumeId, documentId)` key of every indexed document.
    ///
    /// Used to enumerate the corpus scope for a corpus-wide word cloud. The
    /// caller chunks the result through `documentBodyTexts(forKeys:)` so document
    /// text is never all held in memory at once.
    ///
    /// - Returns: All indexed document keys.
    /// A cheap fingerprint of the indexed corpus, used to invalidate persisted
    /// word-cloud results when volumes are added or removed.
    ///
    /// Returns the `document_cache` row count. A change in the set of indexed
    /// volumes changes this count, so a persisted corpus/subseries cloud keyed on
    /// it is recomputed after the index changes (and reused across launches when
    /// it has not).
    ///
    /// - Returns: The number of cached documents.
    func documentCacheCount() throws -> Int {
        let stmt = try auxPrepare("SELECT COUNT(*) FROM document_cache")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func allDocumentKeys() throws -> [WordCloudDocumentKey] {
        let stmt = try auxPrepare("SELECT volume_id, document_id FROM document_cache")
        defer { sqlite3_finalize(stmt) }
        var keys: [WordCloudDocumentKey] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let v = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                keys.append(WordCloudDocumentKey(volumeId: v, documentId: d))
            }
        }
        return keys
    }

    /// Returns the keys of every document tagged with the given user-tag UUID.
    ///
    /// `document_cache.user_tag_ids` stores space-separated UUID strings; the
    /// space-delimited `LIKE` mirrors the user-tag filter used by search so a tag
    /// resolves to exactly the documents the rest of the app considers tagged.
    ///
    /// - Parameter tagId: The user-tag UUID string.
    /// - Returns: The keys of documents carrying that tag.
    func documentKeys(forUserTagId tagId: String) throws -> [WordCloudDocumentKey] {
        let sql = """
            SELECT volume_id, document_id FROM document_cache
            WHERE (' ' || COALESCE(user_tag_ids, '') || ' ') LIKE ('% ' || ? || ' %')
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, tagId, -1, SQLITE_TRANSIENT_IP)
        var keys: [WordCloudDocumentKey] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let v = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                keys.append(WordCloudDocumentKey(volumeId: v, documentId: d))
            }
        }
        return keys
    }

    /// Returns the structured `date_iso` value for each of the given document keys.
    ///
    /// Sources `document_dates.date_iso` — the canonical ISO 8601 date string
    /// (typically `yyyy-MM-dd`, occasionally just `yyyy` for partial-precision
    /// dates). Used by `SearchService` to attach a sortable date to each
    /// `SearchResult` so the macOS search window's date-asc / date-desc sort
    /// orders results chronologically instead of by the free-text dateline.
    ///
    /// Uses a `WITH keys(v, d) AS (VALUES …)` CTE joined against the
    /// `document_dates` composite primary key so SQLite performs index point-lookups
    /// instead of a full table scan. Each chunk of 400 pairs binds 800 parameters
    /// (well within the 999-parameter limit).
    // MARK: - Same-Collection Discovery (Session 152)

    /// Lightweight description of an indexed FRUS document returned by
    /// `relatedDocuments(for:limit:)`.
    public struct RelatedDocument: Sendable {
        /// FRUS volume identifier (e.g. `"frus1964-68v27"`).
        public let volumeId: String
        /// Document identifier within the volume (e.g. `"d42"`).
        public let documentId: String
        /// Document header / title from the indexed cache.
        public let header: String
        /// Dateline (location + date) if available.
        public let dateline: String?
        /// Document number string (e.g. `"42"`) if available.
        public let documentNumber: String?
        /// True when this is an editorial note rather than a primary document.
        public let isEditorialNote: Bool

        /// Corpus-unique `"volumeId/documentId"` key. Use this (never `documentId`
        /// alone) to identify a related document in `ForEach`/dictionaries: neighbor
        /// results span volumes and document ids are only unique within one volume.
        public var compositeKey: String { "\(volumeId)/\(documentId)" }
    }

    /// Returns documents from the same archival collection as `parsed`.
    ///
    /// ## Matching strategy
    ///
    /// | ParsedSourceNote case | Match key | Index used |
    /// |---|---|---|
    /// | `.lotFile` | Canonical compact lot key (`lot_file_norm`) | `idx_doc_src_lot_norm` |
    /// | `.naraCollection` with lot | Same as `.lotFile` | `idx_doc_src_lot_norm` |
    /// | `.naraCollection` non-RG-59 | RG + comma-boundary series prefix | `idx_doc_src_rg` |
    /// | `.centralFiles` with decimal ID | Base number before `/` | `idx_doc_src_era_series` |
    /// | `.presidentialLibrary` | Library keyword + collection prefix | `idx_doc_src_repo` |
    /// | All other cases | Returns empty result | — |
    ///
    /// Only documents from already-indexed volumes appear. The result is ordered
    /// by volume identifier then document identifier.
    ///
    /// - Parameters:
    ///   - parsed: The parsed source note driving the query.
    ///   - limit: Maximum results to return. Default 30.
    /// - Returns: A tuple of matched documents (≤ `limit`) and the total count of
    ///   all matches in the index (may be larger than the returned slice).
    public func relatedDocuments(
        for parsed: ParsedSourceNote,
        limit: Int = 30,
        documentYear: Int? = nil,
        excludingVolumeId: String? = nil,
        excludingDocumentId: String? = nil,
        scopeVolumeIds: Set<String>? = nil,
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        let exclude = (excludingVolumeId, excludingDocumentId)
        // With a volume / subseries scope active, fetch the whole match set (not the
        // display slice) so `applyScope` can count and re-slice the in-scope rows (#217).
        let fetchLimit = scopeVolumeIds == nil ? limit : Self.scopedFetchCeiling
        let raw: (documents: [RelatedDocument], totalCount: Int)
        switch parsed {

        case .lotFile(_, let lotNumber, _):
            raw = try relatedByLotFile(lotNumber, limit: fetchLimit, excluding: exclude, ordering: ordering)

        case .naraCollection(_, _, let lot?, _):
            raw = try relatedByLotFile(lot, limit: fetchLimit, excluding: exclude, ordering: ordering)

        // Non-RG-59 collection (e.g. RG 84, RG 306) with no lot: same (RG, series).
        case .naraCollection(let rg, let series?, nil, _) where rg != "59" && rg != "RG-59":
            raw = try relatedByCollection(recordGroup: rg, series: series,
                                          limit: fetchLimit, excluding: exclude,
                                          ordering: ordering)

        case .centralFiles(_, let fileId?) where fileId.contains("."):
            // Only attempt decimal matching when the identifier contains a period
            // (distinguishes "862S.01/10-1646" from bare File No. values like "3767/5").
            raw = try relatedByDecimal(ref: fileId, currentYear: documentYear,
                                       limit: fetchLimit, excluding: exclude,
                                       ordering: ordering)

        case .presidentialLibrary(let library, let collection, _):
            // Excludes the anchor uniformly (#217): a presidential-library document
            // previously listed itself among its own neighbors.
            raw = try relatedByPresidentialLibrary(library: library,
                                                   collection: collection,
                                                   limit: fetchLimit, excluding: exclude,
                                                   ordering: ordering)

        default:
            raw = ([], 0)
        }
        return Self.applyScope(raw, scopeVolumeIds: scopeVolumeIds, limit: limit)
    }

    /// Returns archival neighbors for an already-indexed document, keyed by its
    /// `volumeId`/`documentId` rather than a pre-parsed source note.
    ///
    /// Fetches the document's stored source-note `raw_text` from `document_sources`,
    /// re-parses it with `SourceNoteParser` (lossless — the structured columns drop the
    /// decimal file id and presidential-library collection the matcher needs), and runs
    /// `relatedDocuments(for:)`. Returns an empty result when the document has no stored
    /// source note (unindexed, or a note with no recognized archival key).
    ///
    /// This is the shared entry point for surfaces that have only a document key
    /// (the cross-reference graph, browser document lists), as opposed to the Source
    /// Explorer which already holds a parsed note.
    ///
    /// - Parameters:
    ///   - volumeId: The source document's volume.
    ///   - documentId: The source document's id within the volume.
    ///   - documentYear: The document's year, for decimal-file chronological segmenting
    ///     (`relatedByDecimal`); pass the year parsed from the document's date when known.
    ///   - limit: Maximum neighbors to return. Default 30.
    /// - Returns: Matched neighbor documents (≤ `limit`), the total match count, and the
    ///   human-readable archival `basis` (e.g. "Lot 64 D 199"), or `basis == nil` when the
    ///   note has no recognized archival key.
    public func archivalNeighbors(
        forVolumeId volumeId: String,
        documentId: String,
        documentYear: Int? = nil,
        limit: Int = 30,
        scopeVolumeIds: Set<String>? = nil
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?) {
        let full = try archivalNeighborsWithCohort(
            forVolumeId: volumeId, documentId: documentId, documentYear: documentYear,
            limit: limit, scopeVolumeIds: scopeVolumeIds)
        return (full.documents, full.totalCount, full.basis)
    }

    /// As ``archivalNeighbors(forVolumeId:documentId:documentYear:limit:scopeVolumeIds:)``, plus the
    /// **cohort size** — how many documents share this anchor's archival container in the whole
    /// index (#644).
    ///
    /// The similarity axis needs this and nothing else does, which is why it is a second entry
    /// point rather than a wider tuple on the first: seventeen call sites destructure the three-tuple
    /// and none of them wants a fourth element.
    ///
    /// Two properties the number has to have, both easy to get wrong:
    ///  - It is taken **before** `applyScope`. The scoped total is what the finding-aid surfaces
    ///    want, but a cohort that shrank under a volume scope would make the same pair read
    ///    "1 of 12" here and "1 of 7,056" there, which is exactly the confusion the chip exists to
    ///    remove.
    ///  - It **includes the anchor**. Every match path excludes the anchor from its own count, so
    ///    the cohort is `totalCount + 1` — "1 of 1,063" means a container of 1,063, not 1,064.
    public func archivalNeighborsWithCohort(
        forVolumeId volumeId: String,
        documentId: String,
        documentYear: Int? = nil,
        limit: Int = 30,
        scopeVolumeIds: Set<String>? = nil
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?, cohortCount: Int) {
        let sql = "SELECT raw_text FROM document_sources WHERE volume_id = ? AND document_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(auxDb, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            return ([], 0, nil, 0)
        }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_text(s, 1, volumeId,   -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(s, 2, documentId, -1, SQLITE_TRANSIENT_IP)
        guard sqlite3_step(s) == SQLITE_ROW, let cStr = sqlite3_column_text(s, 0) else {
            return ([], 0, nil, 0)
        }
        let raw = String(cString: cStr)
        guard !raw.isEmpty else { return ([], 0, nil, 0) }
        let parsed = SourceNoteParser().parse(raw)
        let exclude: (String?, String?) = (volumeId, documentId)
        // Fetch the whole match set when scoped so `applyScope` (below) can filter and
        // re-slice; the widening decision keys on the unscoped total, so scope is
        // applied once, last (#217).
        let fetchLimit = scopeVolumeIds == nil ? limit : Self.scopedFetchCeiling
        // THE ANCHORED PATH ASKS FOR A STRATIFIED POOL (#645) — here and, below, on the alias
        // fallback, which is the same anchor reaching the same axis by another route. The pool
        // exists so the scorers can promote a candidate the generator ranked low, and an
        // alphabetical cut makes most of the container unreachable to them. Every caller of
        // `relatedDocuments(for:)` and of the per-container helpers OUTSIDE this function is a
        // finding aid with no anchor, and keeps the default.
        var result = try relatedDocuments(
            for: parsed, limit: fetchLimit, documentYear: documentYear,
            excludingVolumeId: volumeId, excludingDocumentId: documentId,
            ordering: .stratified
        )
        var basis = parsed.archivalNeighborKey
        // #217 reconciliation — widen the document path to the same Phase-4 collection-
        // authority alias fallback the volume-source path runs, so the same collection
        // returns the same OTHER documents whichever surface opened it. Fires only when
        // every direct path returned zero; the authority record resolves 100% offline
        // from the bundled index; the anchor stays excluded throughout.
        if result.totalCount == 0,
           let record = CollectionAuthorityStore.shared?.record(forParsed: parsed, note: raw) {
            let fallback = IndexingPipeline.CollectionAliasFallback(record: record)
            let keys = Self.directKeys(for: parsed)
            // `.stratified` for the same reason the direct paths above are (#645): this is
            // still the anchored axis. The fallback fires precisely when the direct keys all
            // missed, so it is the ONLY pool these anchors ever see — leaving it alphabetical
            // reproduced the whole defect for them.
            if let viaAuthority = try aliasNeighbors(
                fallback: fallback,
                directLotFile: keys.lotFile, recordGroup: keys.recordGroup,
                series: keys.series, repository: keys.repository,
                limit: fetchLimit, ordering: .stratified, excluding: exclude) {
                result = (viaAuthority.documents, viaAuthority.totalCount)
                basis = viaAuthority.basis
            }
        }
        // Captured BEFORE applyScope, and +1 for the anchor every match path excludes from its
        // own count. See the doc comment: a cohort that changed under a volume scope would make
        // the chip mean something different on two screens showing the same pair.
        let cohortCount = result.totalCount > 0 ? result.totalCount + 1 : 0
        let scoped = Self.applyScope(result, scopeVolumeIds: scopeVolumeIds, limit: limit)
        return (scoped.documents, scoped.totalCount, basis, cohortCount)
    }

    /// Returns archival neighbors for a **volume-level source entry** (a row in a
    /// volume's front-matter sources list), which has no document key of its own.
    ///
    /// Match paths, most-specific first:
    /// 1. **Lot file** — normalized `lot_file_norm` equality.
    /// 2. **Decimal / subject-numeric class leaf** — `relatedByDecimalClass` against
    ///    the indexed `document_sources.decimal_class` column (canonical class
    ///    location for central-files-shaped citations of any era).
    /// 3. **Presidential library** — when `repository` names a library
    ///    (`isLibraryRepository`), the library keyword plus a collection-name prefix
    ///    against document-side presidential-library rows.
    /// 4. **Record group + series** — normalized comma-boundary series prefix.
    ///
    /// Entries with no key on any path return empty with `basis == nil`.
    ///
    /// ## Alias fallback (Source Explorer Phase 4 — display-time only)
    ///
    /// When **every direct path returns zero matches** and an `aliasFallback` (built
    /// from the bundled collection-authority record the entry resolved to) is
    /// provided, the lookup continues in this documented order:
    ///
    /// 1. The authority's **canonical lot key** (`lotFileNorm`) — the record may be
    ///    lot-keyed even when the entry's own row carries no lot (a heading-level
    ///    series name whose lot lives on a sibling citation).
    /// 2. Each of the authority's **merged name/alias forms**, in order, retried
    ///    through the same series-scoped path the entry would use (presidential
    ///    library → record group + series → bare series name); the first form with
    ///    matches wins and is named in the returned `basis`.
    ///
    /// The fallback never runs when a direct path matched (most-specific-first), and
    /// nothing is persisted — the schema is unchanged.
    ///
    /// - Parameters:
    ///   - lotFile: The entry's lot file (e.g. `"64 D 199"`), if any.
    ///   - recordGroup: The entry's record group (e.g. `"59"`), if any.
    ///   - series: The entry's series / collection name, if any (for a library entry
    ///     this is the collection compared against document `series_name`).
    ///   - repository: The entry's holding repository, if any; only library
    ///     repositories participate in matching (path 3).
    ///   - decimalClass: The entry's decimal / subject-numeric class key, if any.
    ///   - aliasFallback: The bundled authority record's keys and alias forms, tried
    ///     only after every direct path returns zero (see above). Default `nil`.
    ///   - limit: Maximum neighbors to return. Default 30.
    /// - Returns: Matched documents (≤ `limit`), the total match count, and the
    ///   human-readable archival `basis`, or `basis == nil` when nothing matched.
    public func archivalNeighbors(
        forLotFile lotFile: String?,
        recordGroup: String?,
        series: String?,
        repository: String? = nil,
        decimalClass: String? = nil,
        aliasFallback: CollectionAliasFallback? = nil,
        limit: Int = 30,
        scopeVolumeIds: Set<String>? = nil
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?) {
        // Fetch the whole match set when scoped; the alias-fallback decision keys on the
        // unscoped total (a direct hit anywhere in the index short-circuits it), so the
        // volume / subseries scope is applied once, last (#217).
        let fetchLimit = scopeVolumeIds == nil ? limit : Self.scopedFetchCeiling
        func scoped(_ r: (documents: [RelatedDocument], totalCount: Int, basis: String?))
            -> (documents: [RelatedDocument], totalCount: Int, basis: String?) {
            let s = Self.applyScope((r.documents, r.totalCount),
                                    scopeVolumeIds: scopeVolumeIds, limit: limit)
            return (s.documents, s.totalCount, r.basis)
        }
        let direct = try directArchivalNeighbors(
            forLotFile: lotFile, recordGroup: recordGroup, series: series,
            repository: repository, decimalClass: decimalClass, limit: fetchLimit)
        if direct.totalCount > 0 { return scoped(direct) }
        guard let aliasFallback else { return scoped(direct) }
        // `.alphabetical`, stated rather than defaulted: this entry point is keyed on a
        // container, not anchored on a document. The list IS the collection, so there is
        // nothing for it to be relevant to and an alphabetical cut is the honest one.
        if let viaAuthority = try aliasNeighbors(
            fallback: aliasFallback, directLotFile: lotFile, recordGroup: recordGroup,
            series: series, repository: repository, limit: fetchLimit,
            ordering: .alphabetical) {
            return scoped(viaAuthority)
        }
        return scoped(direct)
    }

    /// The direct (pre-Phase-4) key paths of `archivalNeighbors(forLotFile:…)`,
    /// most-specific first: lot → class leaf → presidential library → RG + series.
    ///
    /// Path selection is delegated to `neighborCountKey(forLotFile:…)` — the same
    /// derivation the batched three-state counts use — so the per-tap result and the
    /// row's count badge agree on which key family a source entry resolves through
    /// (Source Explorer Phase 5). The queries and `basis` strings are unchanged.
    private func directArchivalNeighbors(
        forLotFile lotFile: String?,
        recordGroup: String?,
        series: String?,
        repository: String?,
        decimalClass: String?,
        limit: Int
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?) {
        guard let key = Self.neighborCountKey(
            forLotFile: lotFile, recordGroup: recordGroup, series: series,
            repository: repository, decimalClass: decimalClass) else {
            return ([], 0, nil)
        }
        switch key {
        case .lotFile:
            // Raw (untrimmed-of-designators) lot for the basis string; key selection
            // guarantees the field is present and non-empty.
            let lot = (lotFile ?? "").trimmingCharacters(in: .whitespaces)
            let r = try relatedByLotFile(lot, limit: limit)
            return (r.documents, r.totalCount,
                    String(localized: "archivalNeighbors.basis.lot",
                           defaultValue: "Lot \(lot)"))
        case .decimalClass:
            let cls = (decimalClass ?? "").trimmingCharacters(in: .whitespaces)
            let r = try relatedByDecimalClass(cls, limit: limit)
            return (r.documents, r.totalCount,
                    String(localized: "archivalNeighbors.basis.decimalClass",
                           defaultValue: "Central files \(cls)"))
        case .presidentialLibrary(let repo, let s):
            let r = try relatedByPresidentialLibrary(library: repo, collection: s, limit: limit)
            return (r.documents, r.totalCount,
                    String(localized: "archivalNeighbors.basis.library",
                           defaultValue: "\(repo): \(s)"))
        case .collection(let rg, let s):
            let r = try relatedByCollection(recordGroup: rg, series: s, limit: limit)
            return (r.documents, r.totalCount,
                    String(localized: "archivalNeighbors.basis.collection",
                           defaultValue: "RG \(rg): \(s)"))
        }
    }

    /// The Phase-4 alias-fallback pass (see `archivalNeighbors(forLotFile:…)` for the
    /// documented order): the authority's lot key first, then each merged name/alias
    /// form through the entry's series-scoped path. Returns `nil` when no fallback
    /// form matched anything.
    ///
    /// ## Why `ordering` has no default (#645)
    /// This is the one helper on the archival path reachable from **both** kinds of caller —
    /// the anchored document-to-document axis and the anchorless key lookup a finding aid
    /// runs — and it takes no parameter that distinguishes them. When `ordering` defaulted,
    /// the anchored caller silently inherited `.alphabetical`, so a document whose direct
    /// keys all missed and which reached its neighbours through the collection authority got
    /// the alphabetical head of the container after all: the exact defect #645 reports,
    /// surviving inside the fix for it. Requiring every caller to state its ordering makes
    /// that class of omission a compile error rather than a silent wrong answer.
    private func aliasNeighbors(
        fallback: CollectionAliasFallback,
        directLotFile: String?,
        recordGroup: String?,
        series: String?,
        repository: String?,
        limit: Int,
        ordering: RelatedPoolOrdering,
        excluding: (String?, String?) = (nil, nil)
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?)? {
        // 1. The authority's canonical lot key (unless the direct path already was it).
        if let lotNorm = fallback.lotFileNorm, !lotNorm.isEmpty {
            let directNorm = directLotFile.map { SourceNoteParser.lotFileNorm($0) }
            if directNorm != lotNorm {
                let r = try relatedByLotFile(lotNorm, limit: limit, excluding: excluding,
                                             ordering: ordering)
                if r.totalCount > 0 {
                    return (r.documents, r.totalCount,
                            String(localized: "archivalNeighbors.basis.lot",
                                   defaultValue: "Lot \(lotNorm)"))
                }
            }
        }
        // 2. Each merged name/alias form through the entry's series-scoped path.
        let directSeries = series?.trimmingCharacters(in: .whitespaces)
        let libraryRepo: String? = repository
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { Self.isLibraryRepository($0) ? $0 : nil }
        let bareRG = recordGroup?.trimmingCharacters(in: .whitespaces)
        for form in fallback.names {
            let name = form.trimmingCharacters(in: .whitespaces)
            guard name.count >= 4, name != directSeries else { continue }
            let r: (documents: [RelatedDocument], totalCount: Int)
            if let libraryRepo {
                r = try relatedByPresidentialLibrary(library: libraryRepo,
                                                     collection: name, limit: limit,
                                                     excluding: excluding, ordering: ordering)
            } else if let rg = bareRG, !rg.isEmpty {
                r = try relatedByCollection(recordGroup: rg, series: name, limit: limit,
                                            excluding: excluding, ordering: ordering)
            } else {
                r = try relatedBySeriesName(name, limit: limit, excluding: excluding,
                                            ordering: ordering)
            }
            if r.totalCount > 0 {
                return (r.documents, r.totalCount,
                        String(localized: "archivalNeighbors.basis.alias",
                               defaultValue: "\(name) (collection authority)"))
            }
        }
        return nil
    }

    // MARK: - Batched Neighbor Counts (Source Explorer Phase 5)

    /// The normalized match key a volume-source entry resolves through, used both to
    /// select the direct per-tap path (`directArchivalNeighbors`) and as the dictionary
    /// key of the batched three-state counts (`archivalNeighborCounts(forKeys:)`) —
    /// one derivation, so the badge and the opened sheet agree by construction.
    public enum ArchivalNeighborCountKey: Sendable, Hashable {
        /// Lot-file path: the canonical compact lot key (`SourceNoteParser.lotFileNorm`,
        /// e.g. `"64D199"`); empty when the raw lot normalizes to nothing (count 0).
        case lotFile(norm: String)
        /// Decimal / subject-numeric class-leaf path: the canonical class location
        /// (`SourceNoteParser.decimalClassKey`); empty when canonicalization fails.
        case decimalClass(key: String)
        /// Presidential-library path: trimmed repository + collection name.
        case presidentialLibrary(repository: String, collection: String)
        /// Record group + series path: trimmed RG (either stored form) + series name.
        case collection(recordGroup: String, series: String)
    }

    /// Derives the `ArchivalNeighborCountKey` for a volume-source entry's match keys,
    /// or `nil` when no path applies — **the single source of truth for path
    /// selection**, mirrored exactly by `directArchivalNeighbors` (which dispatches on
    /// this key). Most-specific first: lot → class leaf → presidential library →
    /// RG + series.
    ///
    /// Pure and `nonisolated static` so display surfaces can derive a row's key
    /// without an actor hop, and tests can pin the selection order.
    nonisolated public static func neighborCountKey(
        forLotFile lotFile: String?,
        recordGroup: String?,
        series: String?,
        repository: String? = nil,
        decimalClass: String? = nil
    ) -> ArchivalNeighborCountKey? {
        func trimmed(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
            return t
        }
        if let lot = trimmed(lotFile) {
            // Accept a "Lot "-prefixed form from any caller (as `relatedByLotFile` does).
            let bare = lot.replacingOccurrences(
                of: "Lot ", with: "", options: [.caseInsensitive, .anchored])
            return .lotFile(norm: SourceNoteParser.lotFileNorm(bare))
        }
        if let cls = trimmed(decimalClass) {
            return .decimalClass(key: SourceNoteParser.decimalClassKey(cls)
                                 ?? Self.fallbackClassKey(cls) ?? "")
        }
        if let repo = trimmed(repository), isLibraryRepository(repo),
           let s = trimmed(series) {
            return .presidentialLibrary(repository: repo, collection: s)
        }
        if let rg = trimmed(recordGroup), let s = trimmed(series) {
            return .collection(recordGroup: rg, series: s)
        }
        return nil
    }

    /// Resolves neighbor **counts** for a whole volume's keyed source entries in a
    /// fixed number of SQL round-trips — the batched query behind the three-state
    /// affordance in `VolumeSourcesView` (no key / keyed-zero / keyed-N), replacing
    /// what would otherwise be one `archivalNeighbors` query per row.
    ///
    /// ## Batching design
    /// Keys are grouped by family and each family resolves in one statement shape:
    /// - **Lot** — all lot norms in a single `WHERE lot_file_norm IN (…) GROUP BY
    ///   lot_file_norm` (index seeks on `idx_doc_src_lot_norm`).
    /// - **Class leaf / presidential library / RG + series** — one `UNION ALL` of
    ///   per-key `SELECT branch, COUNT(*)` subqueries, each branch reusing the *exact*
    ///   `WHERE` clause of its per-tap helper (`classLeafPatterns` /
    ///   `libraryMatchClause` / `rgSeriesClause`), so counts equal the sheet's
    ///   `totalCount` by construction.
    ///
    /// Statements are chunked defensively (≤ 100 branches / ≤ 400 IN values) to stay
    /// far below SQLite's bound-parameter and compound-select limits; a volume's
    /// sources list never approaches the chunk size in practice, so this is one
    /// round-trip per key family.
    ///
    /// ## Alias fallback is deliberately excluded (decision, Phase 5)
    /// The Phase-4 collection-authority alias fallback is **not** folded into the
    /// counts: it fires only after every direct path returns zero and fans out into
    /// up to 13 name-form `LIKE` scans *per record* — not one more indexed lookup,
    /// but an order-of-magnitude cost multiplier applied exactly to the rows that
    /// matched nothing. A row whose badge shows 0 therefore stays tappable, and the
    /// opened sheet may exceed the badge (including 0 → N) when the alias fallback
    /// rescues the query.
    ///
    /// - Parameter keys: The derived keys (`neighborCountKey`) of the volume's keyed
    ///   entries; duplicates collapse.
    /// - Returns: A count for **every** input key (0 when nothing in the user's index
    ///   matches), so callers can distinguish "loaded, zero" from "not yet loaded".
    public func archivalNeighborCounts(
        forKeys keys: [ArchivalNeighborCountKey]
    ) throws -> [ArchivalNeighborCountKey: Int] {
        var counts: [ArchivalNeighborCountKey: Int] = [:]
        for key in keys { counts[key] = 0 }
        guard !counts.isEmpty else { return counts }
        // Snapshot: `counts` is mutated below, and Swift dictionaries must not be
        // written through while a `keys` view is being iterated.
        let uniqueKeys = Array(counts.keys)

        // ── Family 1: lot norms — one grouped IN-seek per ≤400-key chunk. ──
        let lotNorms = uniqueKeys.compactMap { key -> String? in
            guard case .lotFile(let norm) = key, !norm.isEmpty else { return nil }
            return norm
        }
        var lotCounts: [String: Int] = [:]
        for chunk in Self.chunked(lotNorms, size: 400) {
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            let sql = """
                SELECT lot_file_norm, COUNT(*)
                FROM document_sources
                WHERE lot_file_norm IN (\(placeholders))
                GROUP BY lot_file_norm
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, norm) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), norm, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let norm = auxColumnString(stmt, 0) {
                    lotCounts[norm] = Int(sqlite3_column_int64(stmt, 1))
                }
            }
        }
        for key in uniqueKeys {
            if case .lotFile(let norm) = key { counts[key] = lotCounts[norm] ?? 0 }
        }

        // ── Families 2–4: one labeled COUNT branch per key, UNION ALL per chunk. ──
        // Each branch's WHERE is built by the same helper its per-tap query uses.
        var branches: [(key: ArchivalNeighborCountKey, clause: String, params: [String])] = []
        for key in uniqueKeys {
            switch key {
            case .lotFile:
                continue
            case .decimalClass(let canonical):
                guard let patterns = Self.classLeafPatterns(forCanonicalKey: canonical) else { continue }
                let likes = patterns.map { _ in "ds.decimal_class LIKE ? ESCAPE '\\'" }
                    .joined(separator: " OR ")
                branches.append((key, "(\(likes))", patterns))
            case .presidentialLibrary(let repo, let collection):
                guard let m = Self.libraryMatchClause(library: repo, collection: collection) else { continue }
                branches.append((key, m.clause, m.params))
            case .collection(let rg, let series):
                guard let m = Self.rgSeriesClause(recordGroup: rg, series: series) else { continue }
                branches.append((key, m.clause, m.params))
            }
        }
        for chunk in Self.chunked(branches, size: 100) {
            let sql = chunk.enumerated().map { i, branch in
                "SELECT \(i) AS branch, COUNT(*) FROM document_sources ds WHERE \(branch.clause)"
            }.joined(separator: " UNION ALL ")
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            var bind = 1
            for branch in chunk {
                for p in branch.params {
                    sqlite3_bind_text(stmt, Int32(bind), p, -1, SQLITE_TRANSIENT_IP)
                    bind += 1
                }
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idx = Int(sqlite3_column_int64(stmt, 0))
                guard chunk.indices.contains(idx) else { continue }
                counts[chunk[idx].key] = Int(sqlite3_column_int64(stmt, 1))
            }
        }
        return counts
    }

    /// Splits `items` into consecutive slices of at most `size` elements.
    nonisolated private static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: size).map {
            Array(items[$0..<min($0 + size, items.count)])
        }
    }

    // MARK: - Related Document Helpers

    /// SQL fragment + params that exclude the document being viewed from its own neighbors.
    private func exclusion(_ exclude: (String?, String?)) -> (clause: String, params: [String]) {
        guard let v = exclude.0, let d = exclude.1 else { return ("", []) }
        return (" AND NOT (ds.volume_id = ? AND ds.document_id = ?)", [v, d])
    }

    // MARK: - Neighbor Scope (#217)

    /// The synthetic fetch ceiling used when a volume / subseries scope is active
    /// (`scopeVolumeIds != nil`): the underlying neighbor query must return its **whole**
    /// match set — not the display `limit` — so the post-query scope filter can both
    /// recompute the total and re-slice correctly. A neighbor match set is structurally
    /// bounded (one lot / collection / class), so this is effectively unbounded while
    /// staying `Int32`-safe for the SQLite `LIMIT` binding.
    private static let scopedFetchCeiling = 100_000

    /// Restricts a neighbor result to a set of volume ids — the "This volume" / "This
    /// subseries" scopes (#217) — recomputing the total from the filtered rows and
    /// re-slicing to the display `limit`. A `nil` scope means "All indexed volumes" and
    /// returns the result untouched. The scope filter is applied **uniformly in the
    /// public entry points**, so the same archival key returns the same in-scope set on
    /// every trigger surface (the #217 parity guarantee).
    nonisolated private static func applyScope(
        _ result: (documents: [RelatedDocument], totalCount: Int),
        scopeVolumeIds: Set<String>?,
        limit: Int
    ) -> (documents: [RelatedDocument], totalCount: Int) {
        guard let scopeVolumeIds else { return result }
        let filtered = result.documents.filter { scopeVolumeIds.contains($0.volumeId) }
        return (Array(filtered.prefix(limit)), filtered.count)
    }

    /// The direct match keys a parsed document source note routes through — the
    /// document-path equivalent of a front-matter entry's lot / RG / series / repository
    /// fields, so the widened alias fallback (#217) can skip the direct path it already
    /// tried and name its winning form. `nil` on every field for cases with no archival key.
    nonisolated private static func directKeys(
        for parsed: ParsedSourceNote
    ) -> (lotFile: String?, recordGroup: String?, series: String?, repository: String?) {
        switch parsed {
        case .lotFile(_, let lot, _):
            return (lot, nil, nil, nil)
        case .naraCollection(let rg, let series, let lot, _):
            return (lot, rg, series, nil)
        case .presidentialLibrary(let library, let collection, _):
            return (nil, nil, collection, library)
        default:
            return (nil, nil, nil, nil)
        }
    }

    /// Returns documents indexed with the same canonical compact lot key.
    ///
    /// A single indexed equality on `document_sources.lot_file_norm`
    /// (`SourceNoteParser.lotFileNorm`, e.g. `"64D199"`): the query lot is normalized
    /// here, so every spacing and hyphen/en-dash/em-dash variant matches in both
    /// directions. This replaces the former 4-variant `IN` over raw `lot_file`, which
    /// dash variants defeated (audit §2.4).
    ///
    /// **No raw-variant fallback is kept** — norm coverage is structural for every
    /// row this path can match: wherever a `.lotFile` / `.naraCollection` lot is
    /// stored, the same insert writes `lot_file_norm` (`documentSourceRow` for the
    /// doc side, `SourcesParserDelegate.makeItemEntry` for the front-matter side),
    /// and the index-version bumps that introduced the columns (16 and 18) force a
    /// reindex. (`.ciaCollection` rows reuse the `lot_file` column for CIA job
    /// numbers and deliberately carry no norm — job numbers are not lot keys and
    /// never route through this path.)
    private func relatedByLotFile(
        _ rawLot: String,
        limit: Int,
        excluding: (String?, String?) = (nil, nil),
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        // Defensive: volume-source entries store the bare number, but accept a
        // "Lot "-prefixed form from any caller (the retired variant helper did too).
        let bare = rawLot.replacingOccurrences(
            of: "Lot ", with: "", options: [.caseInsensitive, .anchored])
        let norm = SourceNoteParser.lotFileNorm(bare)
        guard !norm.isEmpty else { return ([], 0) }

        let ex = exclusion(excluding)
        let whereClause = "ds.lot_file_norm = ?\(ex.clause)"
        let params = [norm] + ex.params

        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(whereClause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(whereClause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        return try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: params, selectParams: params,
            limit: limit, ordering: ordering
        )
    }

    /// Returns documents from the same archival collection — record group plus a
    /// **normalized prefix match** on series name.
    ///
    /// ## Normalization (deliberate, per audit §2.4)
    /// - **Case**: both comparisons use `LIKE`, which is ASCII-case-insensitive.
    /// - **Whitespace**: collapsed to single spaces at write time on *both* sides
    ///   (`SourceNoteParser` for `document_sources`, `SourcesParserDelegate` for
    ///   `volume_sources`), so no runtime mapping is needed.
    /// - **Dashes**: stored verbatim on both sides — series names come from the same
    ///   TEI vocabulary (en-dash in year ranges on both sides), unlike lot keys where
    ///   the corpus genuinely mixes forms (those go through `lot_file_norm`).
    /// - **Record group**: tolerant of both stored forms — `extractRG` rows store the
    ///   bare number ("84") while lot/decimal-derived rows store "RG-84".
    ///
    /// ## Prefix direction and over-broad guard
    /// The *query* series (a front-matter entry's cleaned name, or a parsed note's
    /// series component) is the prefix; the *stored* `series_name` may append
    /// locator tails (`documentSourceRow` writes `"series, Box N"`). Exact equality
    /// was therefore the wrong grain (81/539 resolved). The prefix only extends
    /// across a **comma boundary** (`series + ",…"`), so `"Moscow Embassy"` never
    /// matches `"Moscow Embassy Files, Box 12"` mid-word, and a ≥4-character minimum
    /// keeps degenerate prefixes from matching broadly.
    private func relatedByCollection(
        recordGroup: String,
        series: String,
        limit: Int,
        excluding: (String?, String?) = (nil, nil),
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        guard let match = Self.rgSeriesClause(recordGroup: recordGroup, series: series) else {
            return ([], 0)
        }
        let ex = exclusion(excluding)
        let whereClause = "\(match.clause)\(ex.clause)"
        let params = match.params + ex.params

        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(whereClause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(whereClause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        return try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: params, selectParams: params,
            limit: limit, ordering: ordering
        )
    }

    /// Returns documents from the same decimal-file **location and chronological segment**.
    ///
    /// Same location = the decimal classification before `/`. Same segment = the same
    /// filing period, derived from each candidate's suffix year (1940+ date form) or, for
    /// pre-1940 sequential refs, its own indexed document year. When the viewed document's
    /// segment can't be determined, falls back to location-only matching.
    ///
    /// Candidates are fetched (capped) and segment-filtered in Swift, since the period
    /// derivation isn't expressible in SQL.
    ///
    /// The SQL row cap is a **candidate** cap, not the display slice: it floors at 1000
    /// (the historical ceiling for unscoped display) but honors a larger passed `limit`,
    /// so a scoped call (`limit == scopedFetchCeiling`) fetches the whole location match
    /// set before the entry point's `applyScope` filters and re-slices it (#217). Binding
    /// the passed `limit` verbatim would instead cap candidates at the display 30 and
    /// starve the segment filter.
    private func relatedByDecimal(
        ref: String,
        currentYear: Int?,
        limit: Int,
        excluding: (String?, String?) = (nil, nil),
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        let location = DecimalFileSegment.location(from: ref)
        guard !location.isEmpty else { return ([], 0) }
        let currentSegment = DecimalFileSegment.segment(for: ref, fallbackYear: currentYear)
        // Two prefixes, because `location(from:)` trims the whitespace a citation may leave
        // before the item slash while `series_name` stores the file number verbatim. A note
        // reading `751G.5 MSP /10–553` is stored with that space, so the trimmed
        // `751G.5 MSP/%` matched none of its 41 siblings and the document showed no archival
        // neighbours at all (reported on frus1952-54v13p1/d416).
        //
        // 2,224 decimal rows (1.2%) carry the space — `501. BC` (183), `740.00119 EW` (87),
        // `357. AC` (59), `751G.5 MSP` (42), `774.5 MSP` (42) among them. Matching it here
        // rather than normalising `series_name` at index time keeps the fix out of the stored
        // data, so it needs no reindex and cannot corrupt a file number that means something.
        let likePrefix = location + "/%"
        let spacedPrefix = location + " /%"
        let ex = exclusion(excluding)

        let sql = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note,
                   ds.series_name, dd.date_iso
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            LEFT JOIN document_dates dd
                ON dd.volume_id = ds.volume_id AND dd.document_id = ds.document_id
            WHERE ds.citation_era = 'decimal'
                AND (ds.series_name = ? OR ds.series_name LIKE ? OR ds.series_name LIKE ?)\(ex.clause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        let params = [location, likePrefix, spacedPrefix] + ex.params
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT_IP)
        }
        // NO PRE-CUT. The segment filter below runs in Swift, on the rows this statement returns,
        // so any LIMIT here truncates the set the filter is allowed to see — and it truncates it
        // by `volume_id`, which sorts chronologically, while a decimal segment IS chronological.
        // The old `max(1000, limit)` therefore kept the EARLIEST volumes and then discarded them
        // all for any later-era anchor. Measured on the owner's index: `893.00` spans 55 volumes
        // and the first 1,000 rows reach 18 of them; `861.00` spans 31 and reaches 5; `812.00`
        // spans 24 and reaches 4. Four thousand anchors got an empty list while the index held
        // their neighbours.
        //
        // The whole match set is bounded and small — the largest decimal location is 4,482 rows —
        // and `runRelatedQuery`'s own COUNT(*) already scans it, so this is not a new class of
        // work. Measured cost of reading it all rather than 120 rows: +19 ms warm, worst case.
        sqlite3_bind_int64(stmt, Int32(params.count + 1), Int64(Int32.max))

        var matched: [RelatedDocument] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let vid = auxColumnString(stmt, 0) ?? ""
            let did = auxColumnString(stmt, 1) ?? ""
            guard !vid.isEmpty, !did.isEmpty else { continue }
            // Segment-filter: keep when the viewed segment is unknown (location-only) or
            // the candidate's segment equals it.
            if let currentSegment {
                let candRef = auxColumnString(stmt, 6) ?? ""
                let candDateYear = (auxColumnString(stmt, 7)?.prefix(4)).flatMap { Int($0) }
                let candSegment = DecimalFileSegment.segment(for: candRef, fallbackYear: candDateYear)
                guard candSegment == currentSegment else { continue }
            }
            matched.append(RelatedDocument(
                volumeId: vid, documentId: did,
                header: auxColumnString(stmt, 2) ?? did,
                dateline: auxColumnString(stmt, 3),
                documentNumber: auxColumnString(stmt, 4),
                isEditorialNote: sqlite3_column_int(stmt, 5) != 0
            ))
        }
        // This path has its own step loop rather than `runRelatedQuery`, so it stratifies here.
        let cut = ordering == .stratified
            ? Self.stratifyByVolume(matched, limit: limit)
            : Array(matched.prefix(limit))
        return (cut, matched.count)
    }

    /// Returns documents citing a decimal / subject-numeric **class** from a
    /// volume-level front-matter leaf (`"POL 27 ARAB–ISR"`, `"DEF 6 MLF"`, `"711.11"`).
    ///
    /// Matches the `document_sources.decimal_class` column, which stores the
    /// canonical class location (`SourceNoteParser.decimalClassKey` — whitespace
    /// collapsed, Unicode dashes → ASCII hyphen, item suffix and sentence tail cut)
    /// for every central-files-shaped citation regardless of era — the narrative
    /// decimal rows (`"…Central Files, 788.5/9–1361"`), the subject-numeric
    /// `structured` rows (`"…RG 59, Central Files 1967–69, POL 27 ARAB-ISR"`), and
    /// CFPF rows. The query key is canonicalized the same way, so the en-dash the TEI
    /// front matter carries matches the hyphen document notes use.
    ///
    /// **Cost: a covering-index scan, not a seek.** The four LIKE patterns walk
    /// `idx_doc_src_class` end to end — SQLite's LIKE prefix optimization requires
    /// a NOCASE-collated (or `PRAGMA case_sensitive_like`) column, and
    /// `decimal_class` is BINARY-collated. The covering index keeps the walk in
    /// index pages only (~126k keyed rows corpus-wide), which is well within budget
    /// for a per-tap query; revisit with a `COLLATE NOCASE` declaration (a schema
    /// change riding the drop-and-recreate migration) if the corpus grows.
    ///
    /// The key matches at four boundaries — exact, `class + " …"` (a subject/country
    /// token boundary, so `"POL 27"` finds `"POL 27 ARAB-ISR"`), `class + "-…"` (a
    /// subdivision, so `"POL 27"` finds `"POL 27-14 ARAB-ISR"`), and `class + ".…"`
    /// (a dotted-decimal subdivision) — which keep `"711.1"` from matching
    /// `"711.11"` mid-token.
    ///
    /// **S3 resolved to its lean — location prefix only, no `DecimalFileSegment`
    /// period filtering.** Porting the doc-side segmenter did not turn out cheap:
    /// (1) a front-matter leaf has no `/item` suffix to derive a filing-period year
    /// from, and the volume's coverage years live in era-dependent prose
    /// (`"Central Files 1967–69: …"`) that would need its own parser; (2) the
    /// subject-numeric leaves that dominate the unkeyed bucket (1963–1973) post-date
    /// the decimal segment table (segments end 1963), so a period filter could never
    /// apply to them; (3) a front-matter entry names the class as used across the
    /// volume's whole span, so *all* indexed citations of the class are the honest
    /// neighbor set for it.
    private func relatedByDecimalClass(
        _ classKey: String,
        limit: Int
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        guard let key = SourceNoteParser.decimalClassKey(classKey)
                ?? Self.fallbackClassKey(classKey),
              let patterns = Self.classLeafPatterns(forCanonicalKey: key) else { return ([], 0) }
        let likes = patterns.map { _ in "ds.decimal_class LIKE ? ESCAPE '\\'" }
            .joined(separator: " OR ")
        let whereClause = "(\(likes))"

        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(whereClause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(whereClause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        return try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: patterns, selectParams: patterns,
            limit: limit
        )
    }

    /// Defensive canonicalization for a class key that fails the shared shape gate.
    /// Stored front-matter keys always pass `SourceNoteParser.decimalClassKey`, so this
    /// only covers direct `archivalNeighbors` callers: whitespace collapsed, Unicode
    /// dashes → ASCII hyphen; `nil` under 3 characters (too short to be a class).
    nonisolated private static func fallbackClassKey(_ raw: String) -> String? {
        let s = raw.replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return s.count >= 3 ? s : nil
    }

    // MARK: - Shared match-clause builders (per-tap queries + batched counts)

    /// The four boundary-gated LIKE patterns for a decimal / subject-numeric class
    /// leaf (exact, token, subdivision, dotted subdivision) — shared verbatim by
    /// `relatedByDecimalClass` and the batched `archivalNeighborCounts` so the badge
    /// and the opened sheet count the same rows. `nil` for an empty key.
    nonisolated private static func classLeafPatterns(forCanonicalKey key: String) -> [String]? {
        guard !key.isEmpty else { return nil }
        let esc = likeEscaped(key)
        return [esc, esc + " %", esc + "-%", esc + ".%"]
    }

    /// The presidential-library `WHERE` over `document_sources ds` — library keyword
    /// LIKE on `repository` plus a ≤50-char collection prefix on `series_name` —
    /// shared verbatim by `relatedByPresidentialLibrary` and the batched
    /// `archivalNeighborCounts`. `nil` when the library name yields no keyword.
    nonisolated private static func libraryMatchClause(
        library: String,
        collection: String
    ) -> (clause: String, params: [String])? {
        let keyword = libraryKeyword(from: library)
        guard !keyword.isEmpty else { return nil }
        let repoLike = "%\(likeEscaped(keyword))%"
        let collectionPrefix = likeEscaped(String(collection.prefix(50)))
        let collectionLike = collectionPrefix.isEmpty ? "%" : collectionPrefix + "%"
        let clause = """
            UPPER(ds.repository) LIKE UPPER(?) ESCAPE '\\'
            AND UPPER(ds.series_name) LIKE UPPER(?) ESCAPE '\\'
            """
        return (clause, [repoLike, collectionLike])
    }

    /// The record-group + comma-boundary series-prefix `WHERE` over
    /// `document_sources ds` (both stored RG forms; over-broad guard: series ≥ 4
    /// chars) — shared verbatim by `relatedByCollection` and the batched
    /// `archivalNeighborCounts`. `nil` when a guard refuses the key.
    nonisolated private static func rgSeriesClause(
        recordGroup: String,
        series: String
    ) -> (clause: String, params: [String])? {
        let s = series.trimmingCharacters(in: .whitespaces)
        guard s.count >= 4 else { return nil }
        // Accept the RG in either stored form regardless of the caller's form.
        let bareRG = recordGroup
            .replacingOccurrences(of: #"^RG[\s\-]*"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        guard !bareRG.isEmpty else { return nil }
        let esc = likeEscaped(s)
        let clause = """
            ds.record_group IN (?, ?)
            AND (ds.series_name LIKE ? ESCAPE '\\' OR ds.series_name LIKE ? ESCAPE '\\')
            """
        return (clause, [bareRG, "RG-\(bareRG)", esc, esc + ",%"])
    }

    /// Returns documents from the same presidential library collection.
    ///
    /// Uses a LIKE match on `repository` (e.g. `%KENNEDY%`) and a prefix match on
    /// `series_name` (first 50 characters of the collection name, wildcard-escaped).
    private func relatedByPresidentialLibrary(
        library: String,
        collection: String,
        limit: Int,
        excluding: (String?, String?) = (nil, nil),
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        guard let match = Self.libraryMatchClause(library: library, collection: collection) else {
            return ([], 0)
        }
        let ex = exclusion(excluding)
        let whereClause = "\(match.clause)\(ex.clause)"
        let params = match.params + ex.params
        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(whereClause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(whereClause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        return try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: params,
            selectParams: params,
            limit: limit, ordering: ordering
        )
    }

    /// Returns documents citing a **bare series name** (no record group, no repository
    /// scope) — the unattributed named-series grain (`citation_era = 'named_series'`
    /// rows and heading-level series the corpus never attributes). Same comma-boundary
    /// prefix rules as `relatedByCollection` (exact, or `name + ",…"` for locator
    /// tails), with the same ≥4-character guard. Used only by the Phase-4 alias
    /// fallback and the S5 local-stats query — direct entry paths always carry a
    /// stronger key.
    private func relatedBySeriesName(
        _ series: String,
        limit: Int,
        excluding: (String?, String?) = (nil, nil),
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        let s = series.trimmingCharacters(in: .whitespaces)
        guard s.count >= 4 else { return ([], 0) }
        let esc = Self.likeEscaped(s)
        let ex = exclusion(excluding)
        let whereClause = "(ds.series_name LIKE ? ESCAPE '\\' OR ds.series_name LIKE ? ESCAPE '\\')\(ex.clause)"
        let params = [esc, esc + ",%"] + ex.params

        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(whereClause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(whereClause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        return try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: params, selectParams: params,
            limit: limit, ordering: ordering
        )
    }

    // MARK: - Collection Authority Fallback (Source Explorer Phase 4)

    /// The bundled collection-authority record's match keys, passed by display
    /// surfaces into `archivalNeighbors(forLotFile:…)` for the display-time alias
    /// fallback. Carrying the values (rather than consulting the bundle inside the
    /// matcher) keeps the matcher deterministic and fixture-testable.
    public struct CollectionAliasFallback: Sendable, Equatable {
        /// The authority record's canonical compact lot key, when lot-keyed.
        public let lotFileNorm: String?
        /// The record's canonical name followed by its merged alias forms, in the
        /// artifact's order.
        public let names: [String]
        /// Memberwise initializer.
        public init(lotFileNorm: String?, names: [String]) {
            self.lotFileNorm = lotFileNorm
            self.names = names
        }
    }

    // MARK: - Collection Authority Local Stats (Source Explorer Phase 4, S5)

    /// Local per-user statistics for one bundled collection-authority record: how much
    /// of the user's **own index** cites the collection. Owner decision **S5**: the
    /// artifact never ships document counts — these are always recomputed here.
    public struct CollectionLocalStats: Sendable, Equatable {
        /// Indexed documents whose source note cites the collection.
        public let documentCount: Int
        /// Distinct indexed volumes those documents span.
        public let volumeCount: Int
        /// Memberwise initializer.
        public init(documentCount: Int, volumeCount: Int) {
            self.documentCount = documentCount
            self.volumeCount = volumeCount
        }
    }

    /// Maximum distinct name/alias forms folded into the record-level OR-union match
    /// clause — covers a record's canonical name plus the artifact's full alias cap
    /// (12), so the S5 counts and the record-level neighbors query never window the
    /// alias list differently.
    private static let collectionMatchFormCap = 13

    /// Builds the record-level OR-union `WHERE` clause over `document_sources ds` for
    /// one bundled collection-authority record — **the single source of truth** shared
    /// by `localCollectionStats` (the S5 counts) and `collectionNeighbors` (the
    /// record-level Archival Neighbors sheet), so the two surfaces agree by
    /// construction:
    ///
    /// - the record's canonical lot key → `lot_file_norm` equality (indexed seek);
    /// - each name/alias form (≥4 chars, capped at `collectionMatchFormCap`) →
    ///   - presidential-library records: repository keyword + collection prefix
    ///     (`relatedByPresidentialLibrary` shape),
    ///   - record-group records: RG (both stored forms) + comma-boundary series prefix
    ///     (`relatedByCollection` shape),
    ///   - unattributed records: bare comma-boundary series prefix
    ///     (`relatedBySeriesName` shape).
    ///
    /// Returns `nil` when the record yields no usable branch.
    private func collectionMatchClause(
        lotFileNorm: String?,
        repository: String?,
        recordGroup: String?,
        names: [String]
    ) -> (clause: String, params: [String])? {
        var branches: [String] = []
        var params: [String] = []

        if let lot = lotFileNorm?.trimmingCharacters(in: .whitespaces), !lot.isEmpty {
            branches.append("ds.lot_file_norm = ?")
            params.append(lot)
        }

        let repo = repository?.trimmingCharacters(in: .whitespaces)
        let isLibrary = repo.map(Self.isLibraryRepository) ?? false
        let bareRG = recordGroup.map {
            $0.replacingOccurrences(of: #"^RG[\s\-]*"#, with: "",
                                    options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
        }.flatMap { $0.isEmpty ? nil : $0 }

        var seenNames: Set<String> = []
        for form in names {
            let name = form.trimmingCharacters(in: .whitespaces)
            guard name.count >= 4, seenNames.insert(name.lowercased()).inserted,
                  seenNames.count <= Self.collectionMatchFormCap else { continue }
            let esc = Self.likeEscaped(name)
            if isLibrary, let repo {
                let keyword = Self.libraryKeyword(from: repo)
                guard !keyword.isEmpty else { continue }
                branches.append("""
                    (UPPER(ds.repository) LIKE UPPER(?) ESCAPE '\\' \
                    AND UPPER(ds.series_name) LIKE UPPER(?) ESCAPE '\\')
                    """)
                params.append("%\(Self.likeEscaped(keyword))%")
                params.append(Self.likeEscaped(String(name.prefix(50))) + "%")
            } else if let bareRG {
                branches.append("""
                    (ds.record_group IN (?, ?) \
                    AND (ds.series_name LIKE ? ESCAPE '\\' OR ds.series_name LIKE ? ESCAPE '\\'))
                    """)
                params.append(contentsOf: [bareRG, "RG-\(bareRG)", esc, esc + ",%"])
            } else {
                branches.append("""
                    (ds.series_name LIKE ? ESCAPE '\\' OR ds.series_name LIKE ? ESCAPE '\\')
                    """)
                params.append(contentsOf: [esc, esc + ",%"])
            }
        }
        guard !branches.isEmpty else { return nil }
        return (branches.joined(separator: " OR "), params)
    }

    /// Computes the S5 local stats for an authority record — indexed documents citing
    /// it plus their distinct volumes — in **one** SQL round-trip over the
    /// normalized-key columns.
    ///
    /// The `WHERE` clause is `collectionMatchClause` — the exact clause
    /// `collectionNeighbors` runs — so these counts always agree with the record-level
    /// Archival Neighbors sheet. (The *entry-level* neighbors path,
    /// `archivalNeighbors(forLotFile:…)`, is intentionally different: it resolves one
    /// citation row by its most specific key, not a whole authority record.)
    ///
    /// Class-keyed sub-series are **not** folded in: their citing documents are their
    /// own `decimal_class` queries (the class child's Archival Neighbors action), and
    /// folding them into the parent would count the whole central-files corpus.
    ///
    /// - Parameters:
    ///   - lotFileNorm: The record's canonical compact lot key, if lot-keyed.
    ///   - repository: The record's canonical repository keyword, if any.
    ///   - recordGroup: The record's record-group number, if any.
    ///   - names: The record's canonical name followed by its alias forms.
    /// - Returns: The local document / distinct-volume counts (zero when the user's
    ///   index cites nothing from the collection).
    public func localCollectionStats(
        lotFileNorm: String?,
        repository: String?,
        recordGroup: String?,
        names: [String]
    ) throws -> CollectionLocalStats {
        guard let match = collectionMatchClause(
            lotFileNorm: lotFileNorm, repository: repository,
            recordGroup: recordGroup, names: names) else {
            return CollectionLocalStats(documentCount: 0, volumeCount: 0)
        }
        let sql = """
            SELECT COUNT(*), COUNT(DISTINCT ds.volume_id)
            FROM document_sources ds
            WHERE \(match.clause)
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, p) in match.params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT_IP)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return CollectionLocalStats(documentCount: 0, volumeCount: 0)
        }
        return CollectionLocalStats(
            documentCount: Int(sqlite3_column_int64(stmt, 0)),
            volumeCount: Int(sqlite3_column_int64(stmt, 1))
        )
    }

    /// Returns archival neighbors for a **whole authority record** (the Collection
    /// detail surface): the union of every match shape the record carries, via the
    /// same `collectionMatchClause` that `localCollectionStats` counts with — one
    /// clause, one truth, so the sheet's total always equals the S5 count
    /// (adversarial review 2026-07-04, finding 3; the previous record-level path
    /// short-circuited on the lot branch and could list fewer documents than the
    /// count shown beside the button).
    ///
    /// - Parameters:
    ///   - lotFileNorm: The record's canonical compact lot key, if lot-keyed.
    ///   - repository: The record's canonical repository keyword, if any.
    ///   - recordGroup: The record's record-group number, if any.
    ///   - names: The record's canonical name followed by its alias forms.
    ///   - limit: Maximum neighbors to return. Default 30.
    /// - Returns: Matched documents (≤ `limit`), the total match count, and the
    ///   human-readable `basis` (the record's canonical name), or `basis == nil`
    ///   when the record yields no usable match shape.
    public func collectionNeighbors(
        lotFileNorm: String?,
        repository: String?,
        recordGroup: String?,
        names: [String],
        limit: Int = 30,
        scopeVolumeIds: Set<String>? = nil
    ) throws -> (documents: [RelatedDocument], totalCount: Int, basis: String?) {
        guard let match = collectionMatchClause(
            lotFileNorm: lotFileNorm, repository: repository,
            recordGroup: recordGroup, names: names) else {
            return ([], 0, nil)
        }
        // Fetch the whole match set when scoped so `applyScope` can filter + re-slice (#217).
        let fetchLimit = scopeVolumeIds == nil ? limit : Self.scopedFetchCeiling
        let countSQL = "SELECT COUNT(*) FROM document_sources ds WHERE \(match.clause)"
        let selectSQL = """
            SELECT ds.volume_id, ds.document_id,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM document_sources ds
            JOIN document_cache dc
                ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE \(match.clause)
            ORDER BY ds.volume_id, ds.document_id
            LIMIT ?
            """
        let r = try runRelatedQuery(
            countSQL: countSQL, selectSQL: selectSQL,
            countParams: match.params, selectParams: match.params,
            limit: fetchLimit
        )
        let scoped = Self.applyScope(r, scopeVolumeIds: scopeVolumeIds, limit: limit)
        let basis = names.first?.trimmingCharacters(in: .whitespaces)
            ?? lotFileNorm.map {
                String(localized: "archivalNeighbors.basis.lot", defaultValue: "Lot \($0)")
            }
        return (scoped.documents, scoped.totalCount, basis)
    }

    /// Shared executor for COUNT + SELECT related-document queries.
    /// Re-cuts a fetched pool to `limit` by taking one document from each volume in turn.
    ///
    /// Order within a volume is preserved, so the result is deterministic — the queries already
    /// sort by `(volume_id, document_id)` and this only interleaves them. A container that spans
    /// one volume comes back unchanged.
    ///
    /// Done in Swift rather than as a SQL window function on purpose. Measured on the owner's
    /// index, full-fetch-plus-Swift versus `ROW_NUMBER()`: decimal 893.00 **25.4 ms vs 258.3 ms**
    /// cold, lot 54D270 1.9 vs 3.3, NSC Files 52.6 vs 52.5 — equal or better everywhere. It also
    /// forces no new sort: `relatedByPresidentialLibrary` today plans as a bare index scan with no
    /// sort step, and a window function would add a co-routine and a temp b-tree.
    static func stratifyByVolume(_ documents: [RelatedDocument], limit: Int) -> [RelatedDocument] {
        guard limit > 0, documents.count > limit else { return Array(documents.prefix(max(0, limit))) }
        var byVolume: [String: [RelatedDocument]] = [:]
        var volumeOrder: [String] = []
        for document in documents {
            if byVolume[document.volumeId] == nil { volumeOrder.append(document.volumeId) }
            byVolume[document.volumeId, default: []].append(document)
        }
        var result: [RelatedDocument] = []
        result.reserveCapacity(limit)
        var round = 0
        while result.count < limit {
            var placedAny = false
            for volume in volumeOrder where result.count < limit {
                guard let rows = byVolume[volume], round < rows.count else { continue }
                result.append(rows[round])
                placedAny = true
            }
            guard placedAny else { break }
            round += 1
        }
        return result
    }

    private func runRelatedQuery(
        countSQL: String,
        selectSQL: String,
        countParams: [String],
        selectParams: [String],
        limit: Int,
        ordering: RelatedPoolOrdering = .alphabetical
    ) throws -> (documents: [RelatedDocument], totalCount: Int) {
        // 1. Count
        let totalCount: Int
        let countStmt = try auxPrepare(countSQL)
        defer { sqlite3_finalize(countStmt) }
        for (i, p) in countParams.enumerated() {
            sqlite3_bind_text(countStmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT_IP)
        }
        if sqlite3_step(countStmt) == SQLITE_ROW {
            totalCount = Int(sqlite3_column_int64(countStmt, 0))
        } else {
            totalCount = 0
        }
        guard totalCount > 0 else { return ([], 0) }

        // 2. Fetch
        var docs: [RelatedDocument] = []
        let selectStmt = try auxPrepare(selectSQL)
        defer { sqlite3_finalize(selectStmt) }
        for (i, p) in selectParams.enumerated() {
            sqlite3_bind_text(selectStmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT_IP)
        }
        // A stratified cut has to see the whole container before it can sample it. The set is
        // bounded (the largest is 7,056 rows) and the COUNT(*) above already scanned it.
        let fetchLimit = ordering == .stratified ? Int(Int32.max) : limit
        sqlite3_bind_int64(selectStmt, Int32(selectParams.count + 1), Int64(fetchLimit))
        while sqlite3_step(selectStmt) == SQLITE_ROW {
            let vid   = auxColumnString(selectStmt, 0) ?? ""
            let did   = auxColumnString(selectStmt, 1) ?? ""
            let head  = auxColumnString(selectStmt, 2) ?? did
            let date  = auxColumnString(selectStmt, 3)
            let docNo = auxColumnString(selectStmt, 4)
            let isEd  = sqlite3_column_int(selectStmt, 5) != 0
            guard !vid.isEmpty, !did.isEmpty else { continue }
            docs.append(RelatedDocument(
                volumeId: vid, documentId: did,
                header: head, dateline: date,
                documentNumber: docNo, isEditorialNote: isEd
            ))
        }
        if ordering == .stratified { docs = Self.stratifyByVolume(docs, limit: limit) }
        return (docs, totalCount)
    }

    /// Escapes SQL `LIKE` wildcards (`%`, `_`) and the escape character itself so
    /// corpus text can be embedded in a `LIKE` pattern with `ESCAPE '\'`.
    private static func likeEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Whether a volume-source repository string names a presidential library (or an
    /// equivalent manuscript repository) — the gate that routes a volume-level source
    /// entry through the presidential-library match path instead of the record-group
    /// one. Mirrors `SourcesParserDelegate.repoKeywords`' library entries: the
    /// "…Library" names, the Nixon Presidential Materials, and the Hoover Institution.
    static func isLibraryRepository(_ repository: String) -> Bool {
        let r = repository.lowercased()
        return r.contains("library") || r.contains("nixon") || r.contains("hoover institution")
    }

    /// Extracts a short keyword from a presidential library name for LIKE queries.
    ///
    /// Example: `"Kennedy Library"` → `"Kennedy"`, `"LBJ Library"` → `"LBJ"`
    private static func libraryKeyword(from name: String) -> String {
        let parts = name.components(separatedBy: " ")
        // Skip "Library", "Presidential", "Institution" suffixes
        let skip: Set<String> = ["Library", "Presidential", "Institution", "The"]
        let meaningful = parts.filter { !skip.contains($0) && $0.count > 2 }
        return meaningful.first ?? (parts.first ?? "")
    }

    /// Returns the raw source-note text for a single document from `document_cache`.
    ///
    /// Used by `CollectionEditorView` when the export footnote style is `.sourceNoteOnly`
    /// so the exporter can append the archival provenance note without emitting all
    /// editorial/explanatory footnotes.
    ///
    /// - Returns: The source note string, or `nil` if the document is not indexed or has no note.
    public func fetchDocumentSourceNote(volumeId: String, documentId: String) throws -> String? {
        let sql = """
            SELECT source_note FROM document_cache
            WHERE volume_id = ? AND document_id = ?
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId,   -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 2, documentId, -1, SQLITE_TRANSIENT_IP)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return auxColumnString(stmt, 0)
    }

    ///
    /// Documents not present in `document_dates` (e.g. genuinely undated, or
    /// volumes not yet indexed) are absent from the returned dictionary —
    /// callers should treat that as a missing date and sort accordingly.
    ///
    /// - Parameter keys: `(volumeId, documentId)` pairs to look up.
    /// - Returns: Dictionary mapping `"volumeId/documentId"` → date_iso string.
    public func documentDates(
        for keys: [(volumeId: String, documentId: String)]
    ) throws -> [String: String] {
        guard !keys.isEmpty else { return [:] }
        var out: [String: String] = [:]
        // 400 pairs × 2 params/pair = 800 — safely under the SQLite 999-variable cap.
        let chunkSize = 400
        for chunk in stride(from: 0, to: keys.count, by: chunkSize)
                .map({ Array(keys[$0..<min($0 + chunkSize, keys.count)]) }) {
            let valuePlaceholders = chunk.map { _ in "(?, ?)" }.joined(separator: ", ")
            let sql = """
                WITH keys(v, d) AS (VALUES \(valuePlaceholders))
                SELECT dc.volume_id || '/' || dc.document_id, dc.date_iso
                FROM document_dates dc
                JOIN keys ON dc.volume_id = keys.v AND dc.document_id = keys.d
                WHERE dc.date_iso IS NOT NULL
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, pair) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(2 * i + 1), pair.volumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, Int32(2 * i + 2), pair.documentId, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let k = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                    out[k] = d
                }
            }
        }
        return out
    }

    private func fetchCache(volumeId: String, documentId: String) throws -> DocumentCacheRow? {
        let sql = """
            SELECT document_number, header, dateline, source_note, body_text,
                   subject_tag_ids, user_tag_ids, summary_text, note_text,
                   is_editorial_note, is_front_matter
            FROM document_cache WHERE volume_id = ? AND document_id = ?
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 2, documentId, -1, SQLITE_TRANSIENT_IP)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return DocumentCacheRow(
            volumeId: volumeId, documentId: documentId,
            documentNumber: auxColumnString(stmt, 0),
            header: auxColumnString(stmt, 1) ?? "",
            dateline: auxColumnString(stmt, 2),
            sourceNote: auxColumnString(stmt, 3),
            bodyText: auxColumnString(stmt, 4) ?? "",
            subjectTagIds: auxColumnString(stmt, 5),
            userTagIds: auxColumnString(stmt, 6),
            summaryText: auxColumnString(stmt, 7),
            noteText: auxColumnString(stmt, 8),
            isEditorialNote: sqlite3_column_int(stmt, 9) != 0,
            isFrontMatter:   sqlite3_column_int(stmt, 10) != 0
        )
    }

    /// Returns the authoritative printed document number for a single document from the
    /// index (`document_cache.document_number`), or `nil` if the document is unindexed or
    /// genuinely numberless.
    ///
    /// Used by citation surfaces that hold only a `(volumeId, documentId)` — e.g. the macOS
    /// citation popover — so a citation always carries the document number regardless of how
    /// the document was navigated to (a cross-reference tap, say, builds a
    /// `DocumentBrowserEntry` without the number even though the index has it).
    public func documentNumber(volumeId: String, documentId: String) throws -> String? {
        try fetchCache(volumeId: volumeId, documentId: documentId)?.documentNumber
    }

    /// Applies column assignments to a single `document_cache` row, skipping the
    /// write entirely when every assigned column already holds its new value.
    ///
    /// The `SET` list is built from `assignments` (column names are compile-time
    /// constants at every call site, never user input). Naming only the columns
    /// being changed matters: the FTS5 sync triggers are `AFTER UPDATE OF <cols>`,
    /// so a summary/note write re-tokenizes only `user_content`, and a tags-only
    /// write touches no FTS5 index at all.
    ///
    /// The value guard (`col IS NOT ?` disjunction — `IS NOT` so NULLs compare
    /// correctly) makes redundant writes match zero rows, so no trigger fires and
    /// no text is re-tokenized. This is what lets the boot-time SwiftData → index
    /// sync replay every stored summary and note each launch at negligible cost:
    /// in the steady state every statement is a no-op.
    ///
    /// Logs a warning when the document is not in the cache at all (the write is
    /// then a no-op, matching the previous fetch-then-update behaviour).
    private func updateCacheColumns(
        volumeId: String,
        documentId: String,
        label: String,
        assignments: [(column: String, value: String?)]
    ) throws {
        let setList = assignments.map { "\($0.column) = ?" }.joined(separator: ", ")
        let changedList = assignments.map { "\($0.column) IS NOT ?" }.joined(separator: " OR ")
        let sql = """
            UPDATE document_cache SET \(setList)
            WHERE volume_id = ? AND document_id = ? AND (\(changedList))
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        var bind: Int32 = 1
        for assignment in assignments {
            auxBindOptional(stmt, bind, assignment.value)
            bind += 1
        }
        sqlite3_bind_text(stmt, bind, volumeId, -1, SQLITE_TRANSIENT_IP)
        bind += 1
        sqlite3_bind_text(stmt, bind, documentId, -1, SQLITE_TRANSIENT_IP)
        bind += 1
        for assignment in assignments {
            auxBindOptional(stmt, bind, assignment.value)
            bind += 1
        }
        try auxStep(stmt)

        if sqlite3_changes(auxDb) == 0 {
            // Zero changes means either "already current" (fine, common during the
            // boot sync) or "document not indexed" (worth a warning). Distinguish
            // with a cheap primary-key existence probe.
            let probe = try auxPrepare(
                "SELECT 1 FROM document_cache WHERE volume_id = ? AND document_id = ?")
            defer { sqlite3_finalize(probe) }
            sqlite3_bind_text(probe, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
            sqlite3_bind_text(probe, 2, documentId, -1, SQLITE_TRANSIENT_IP)
            if sqlite3_step(probe) != SQLITE_ROW {
                logger.warning("\(label, privacy: .public): \(volumeId, privacy: .public)/\(documentId, privacy: .public) not in cache")
            }
        }
    }

    // MARK: - Raw SQLite Helpers

    private func inTransaction(_ body: () throws -> Void) throws {
        try auxExec("BEGIN")
        do {
            try body()
            try auxExec("COMMIT")
        } catch {
            try? auxExec("ROLLBACK")
            throw error
        }
    }

    /// Runs `body` inside a `BEGIN`/`COMMIT` unless `externalTx` is `true`,
    /// in which case the caller is responsible for the surrounding transaction.
    ///
    /// Used by `auxInsert*` helpers so they can be called both standalone (with
    /// their own transaction) and from within the single outer transaction in
    /// `storeIndexData` without nesting `BEGIN` inside an active `BEGIN`.
    @inline(__always)
    private func withTransactionIfNeeded(_ externalTx: Bool, body: () throws -> Void) throws {
        if externalTx { try body() }
        else          { try inTransaction(body) }
    }

    private func auxExec(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(auxDb, sql, nil, nil, &errmsg)
        guard rc == SQLITE_OK else {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw IndexingError.sqliteError(code: rc, message: msg)
        }
    }

    private func auxPrepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(auxDb, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = auxDb.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw IndexingError.sqliteError(code: rc, message: msg)
        }
        return s
    }

    @discardableResult
    private func auxStep(_ stmt: OpaquePointer) throws -> Bool {
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_ROW  { return true  }
        if rc == SQLITE_DONE { return false }
        let msg = auxDb.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        throw IndexingError.sqliteError(code: rc, message: msg)
    }

    private func auxBindOptional(_ stmt: OpaquePointer, _ col: Int32, _ value: String?) {
        if let v = value { sqlite3_bind_text(stmt, col, v, -1, SQLITE_TRANSIENT_IP) }
        else              { sqlite3_bind_null(stmt, col) }
    }

    private func auxBindOptionalInt(_ stmt: OpaquePointer, _ col: Int32, _ value: Int?) {
        if let v = value { sqlite3_bind_int64(stmt, col, Int64(v)) }
        else             { sqlite3_bind_null(stmt, col) }
    }

    private func auxColumnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }

    private func auxColumnIntOptional(_ stmt: OpaquePointer, _ col: Int32) -> Int? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(stmt, col))
    }

    /// Runs a single-column, single-row integer query on the auxiliary connection.
    private func auxScalarInt(_ sql: String) throws -> Int {
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard try auxStep(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }
}

// MARK: - Combined Search Types

/// One row from the combined corpus + user-content search query
/// (`IndexingPipeline.searchDocuments`).
///
/// Carries every field `SearchService` needs to build a `SearchResult` — display
/// text, the unstemmed body for snippet generation, the canonical ISO date, and
/// flags — so a search completes in a single SQL round-trip.
public struct IndexedSearchRow: Sendable {
    /// Document identifier (e.g. `"d1"`), unique within its volume.
    public let documentId: String
    /// Volume this document belongs to.
    public let volumeId: String
    /// Printed document number, if present.
    public let documentNumber: String?
    /// Original (unstemmed) document header.
    public let header: String
    /// Original dateline, if present.
    public let dateline: String?
    /// Source note, if present.
    public let sourceNote: String?
    /// Full plain-text body — used by `SearchService` to build context snippets.
    public let bodyText: String
    /// Space-separated subject tag IDs, if any. **Inert since Session 09** (the
    /// document-level subject taxonomy was retired) — non-nil only on rows indexed
    /// before the retirement; new/re-indexed rows are NULL.
    public let subjectTagIds: String?
    /// Space-separated user tag IDs, if any.
    public let userTagIds: String?
    /// Whether this document is a FRUS editorial note.
    public let isEditorialNote: Bool
    /// Whether this document is promoted front matter (preface, introduction, …).
    public let isFrontMatter: Bool
    /// Canonical ISO 8601 date from `document_dates`, if known.
    public let dateISO: String?
    /// BM25 relevance score (lower = more relevant). When the document matched in
    /// both FTS5 tables, this is the better of the two scores.
    public let score: Double
}

/// Structured filters applied inside the SQL of
/// `IndexingPipeline.searchDocuments` / `searchDocumentsCount`.
/// The live-versus-reclaimable split of the search index file.
///
/// Produced by ``IndexingPipeline/indexPageStatistics()``. The distinction matters because the
/// filesystem reports the *file*, which after a few reindexes can be substantially larger than the
/// data inside it — see that method for the measured example.
///
/// Version history:
///   1.0 — build 37: initial implementation
/// How an archival candidate pool is cut down to its limit (#645).
///
/// The archival queries `ORDER BY (volume_id, document_id)` and then `LIMIT`, which for a container
/// larger than the pool keeps whichever documents sort first — an alphabetical accident. That is
/// **correct** for a finding aid, where the list is the collection and there is nothing to be
/// relevant *to*, and wrong for the similarity axis, where the pool exists so the scorers can
/// promote a document the generator ranked low. A scorer can only promote a document that is in
/// the pool.
///
/// Measured on the owner's index: Nixon's NSC Files hold 7,056 documents across 67 volumes, and the
/// first 120 reach **five** of them. Lot 54 D 270 holds 1,063 across 5 volumes, and the first 120
/// are distributed 1 / 24 / 95 / 0 / 0 — the 434 documents in `frus1946v10` are unreachable by any
/// scorer, for any anchor, ever.
///
/// Version history:
///   1.0 — #645: initial implementation
public enum RelatedPoolOrdering: Sendable {

    /// Keep the query's own `(volume_id, document_id)` order. The default, and the right answer
    /// for every anchorless finding-aid caller.
    case alphabetical

    /// Round-robin across volumes, so the pool is a *representative* slice of the container rather
    /// than its alphabetical head.
    ///
    /// Only `archivalNeighbors(forVolumeId:documentId:)` asks for this — the one path with an
    /// anchor to be relevant to.
    case stratified
}

public struct IndexPageStatistics: Sendable, Equatable {

    /// The whole index file, as the filesystem sees it.
    public let fileBytes: Int

    /// Pages on SQLite's freelist — space a compaction would return to the filesystem.
    public let reclaimableBytes: Int

    /// Pages holding actual data.
    public var liveBytes: Int { max(0, fileBytes - reclaimableBytes) }

    /// Reclaimable space as a fraction of the file, `0...1`. Zero when the file is empty.
    public var reclaimableFraction: Double {
        fileBytes > 0 ? Double(reclaimableBytes) / Double(fileBytes) : 0
    }

    /// Creates the split.
    public init(fileBytes: Int, reclaimableBytes: Int) {
        self.fileBytes = fileBytes
        self.reclaimableBytes = min(max(0, reclaimableBytes), max(0, fileBytes))
    }
}

public struct SearchSQLFilters: Sendable {
    /// Restrict results to these volume IDs. `nil` (or empty) = all volumes.
    public var volumeIds: [String]?
    /// Restrict results to this explicit set of `"volumeId/documentId"` keys (Project History
    /// scope, #377 Phase 2). `nil` (or empty) = no document-set restriction.
    public var documentIds: [String]?
    /// **Exclude** this explicit set of `"volumeId/documentId"` keys (Project Focus "only new"
    /// option, #377 Phase 2b). `nil` (or empty) = exclude nothing.
    public var excludeDocumentIds: [String]?
    /// Restrict results to documents whose date range overlaps this range.
    /// Undated documents are excluded when non-nil.
    public var dateRange: DateRange?
    /// When `false`, front-matter documents are excluded.
    public var includeFrontMatter: Bool
    /// Restrict results to documents mentioning this person ref.
    public var personRef: String?
    /// Restrict results to documents mentioning any member of this person rollup (cross-corpus).
    public var personRollupId: Int?
    /// Subject tag IDs. **Inert since Session 09** — the document-level subject
    /// taxonomy was retired, so these no longer contribute a WHERE condition; the
    /// field survives for `SearchParameters`/`SavedSearch` plumbing stability.
    public var subjectTagIds: [String]
    /// User tag IDs that must all be present (AND).
    public var userTagIds: [String]
    /// Editorial-note / primary-document type filter.
    public var documentTypeFilter: DocumentTypeFilter

    /// Words the researcher marked exact with `=`, which must appear **literally** —
    /// not merely as a stem-mate — in at least one searched column (Q-3b).
    ///
    /// The stemmed MATCH has already narrowed the candidate set to a superset of these,
    /// so this is a post-filter, applied in SQL rather than in Swift precisely so that
    /// `searchDocumentsCount` sees it too. A count that ignored it would be a silent lie
    /// about a number the researcher is about to publish.
    public var exactTerms: [String]

    /// The `document_cache` columns the query actually searched, which are the columns
    /// an exact term may satisfy.
    ///
    /// Scope-dependent: a search with summaries off must not be rescued by a literal
    /// match inside a summary the query never looked at.
    public var exactColumns: [String]

    public init(
        volumeIds: [String]? = nil,
        documentIds: [String]? = nil,
        excludeDocumentIds: [String]? = nil,
        dateRange: DateRange? = nil,
        includeFrontMatter: Bool = true,
        personRef: String? = nil,
        personRollupId: Int? = nil,
        subjectTagIds: [String] = [],
        userTagIds: [String] = [],
        documentTypeFilter: DocumentTypeFilter = .all,
        exactTerms: [String] = [],
        exactColumns: [String] = []
    ) {
        self.volumeIds = volumeIds
        self.documentIds = documentIds
        self.excludeDocumentIds = excludeDocumentIds
        self.dateRange = dateRange
        self.includeFrontMatter = includeFrontMatter
        self.personRef = personRef
        self.personRollupId = personRollupId
        self.subjectTagIds = subjectTagIds
        self.userTagIds = userTagIds
        self.documentTypeFilter = documentTypeFilter
        self.exactTerms = exactTerms
        self.exactColumns = exactColumns
    }
}

// MARK: - Private Data Structures

private struct DocumentSourceRow: Sendable {
    let volumeId: String
    let documentId: String
    let repository: String?
    let recordGroup: String?
    let lotFile: String?
    let seriesName: String?
    let citationEra: String
    let rawText: String
    /// Classification markings from sentence 2 of the source note (frus-sources sentence
    /// model), e.g. `"Secret; Nodis"`. `nil` when the second sentence does not look like
    /// markings (Source Explorer Phase 1; store-only, no UI yet).
    var classification: String? = nil
    /// Canonical compact lot key (`SourceNoteParser.lotFileNorm`, e.g. `"64D199"`),
    /// set for lot-bearing rows only (Source Explorer Phase 2; the Phase 3 matcher
    /// reads it for single-equality neighbor lookups).
    var lotFileNorm: String? = nil
    /// Canonical decimal / subject-numeric class location
    /// (`SourceNoteParser.decimalClassKey`, e.g. `"POL 27 ARAB-ISR"`, `"788.5"`), set
    /// for central-files-shaped citations only — the same normal form
    /// `volume_sources.decimal_class` stores, so front-matter class leaves resolve
    /// neighbors with an indexed lookup (Source Explorer Phase 3 verification).
    var decimalClass: String? = nil
}

private struct VolumeSourceRow: Sendable {
    let volumeId: String
    let repository: String?
    let recordGroup: String?
    let lotFile: String?
    /// Canonical compact lot key (`SourceNoteParser.lotFileNorm`), matching
    /// `document_sources.lot_file_norm`.
    let lotFileNorm: String?
    let seriesName: String?
    /// Decimal / subject-numeric class-leaf location key (doc-side verbatim normal form).
    let decimalClass: String?
    let entryText: String
    let kind: String
    let depth: Int
    let isHeading: Bool
    let sortOrder: Int
}

private struct VolumeIndexData: Sendable {
    let volumeId: String
    let crossReferences: [CrossReferenceRow]
    let pageRanges: [PageRangeRow]
    let documentDates: [DocumentDateRow]
    let documentCache: [DocumentCacheRow]
    let personMentions: [PersonMentionRow]
    let persons: [PersonRow]
    let terms: [TermRow]
    let documentSources: [DocumentSourceRow]
    let volumeSources: [VolumeSourceRow]
    /// JSON-encoded `VolumeStructure` for the Browser cache, or `nil` if encoding failed.
    let structureJSON: String?
}

private struct PersonMentionRow: Sendable {
    let volumeId: String
    let documentId: String
    let personRef: String
}

private struct PersonRow: Sendable {
    let volumeId: String
    let ref: String
    let name: String
    let description: String?
    let role: String?
    let startYear: Int?
    let endYear: Int?
}

/// Aggregated metadata for one person-rollup row, computed from a cluster's members (Phase 2).
private struct RollupAggregate {
    let canonicalName: String
    let namekey: String
    let description: String?
    let role: String?
    let startYear: Int?
    let endYear: Int?
    let volumeCount: Int
}

private struct TermRow: Sendable {
    let volumeId: String
    let ref: String
    let term: String
    let definition: String?
}

struct CrossReferenceRow: Sendable {
    let sourceVolumeId: String
    let sourceDocumentId: String
    let targetVolumeId: String?
    let targetDocumentId: String
    let referenceType: String?
    let context: String?
}

struct PageRangeRow: Sendable {
    let volumeId: String
    let documentId: String
    let sectionId: String
    let pageNumberType: String
    let pageNumberInt: Int?
    let pageNumberRaw: String
}

/// One structured `document_sources` row: the archival-provenance fields the indexer
/// parsed from a document's source note (Session 130 tables), returned by
/// `IndexingPipeline.documentSourcesByKey` for the collections Sources & Archives block.
///
/// Version history:
///   1.0 — Authoring Phase 6 (blocks): initial implementation
public struct DocumentArchivalSource: Sendable {
    /// The document's volume.
    public let volumeId: String
    /// The document's id within the volume.
    public let documentId: String
    /// The holding repository, when parsed.
    public let repository: String?
    /// The NARA record-group number, when parsed.
    public let recordGroup: String?
    /// The lot-file citation, when parsed.
    public let lotFile: String?
    /// The series/collection name, when parsed.
    public let seriesName: String?
    /// The raw source-note text.
    public let rawText: String

    /// Creates a structured source row.
    public init(volumeId: String, documentId: String, repository: String?,
                recordGroup: String?, lotFile: String?, seriesName: String?, rawText: String) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.repository = repository
        self.recordGroup = recordGroup
        self.lotFile = lotFile
        self.seriesName = seriesName
        self.rawText = rawText
    }
}

/// Full date metadata for a single document, returned by
/// `IndexingPipeline.dateMetadataByDocumentKey`.
///
/// Carries the stored `[dateISO, dateISOMax]` interval plus the original `precision`
/// and `certainty` (both `nil` for rows indexed before version 9) so date-based UI can
/// render and place dates at their true granularity.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct DocumentDateMetadata: Sendable {
    /// Earliest bound (`date_iso`), normalized to `yyyy-MM-dd`.
    public let dateISO: String
    /// Latest bound (`date_iso_max`), normalized to `yyyy-MM-dd`; `nil` for legacy rows.
    public let dateISOMax: String?
    /// Original granularity of the source date; `nil` when unknown / heuristic-derived.
    public let precision: DatePrecision?
    /// Nature of the source date; `nil` for legacy rows.
    public let certainty: DateCertainty?

    public init(dateISO: String, dateISOMax: String?, precision: DatePrecision?, certainty: DateCertainty?) {
        self.dateISO = dateISO
        self.dateISOMax = dateISOMax
        self.precision = precision
        self.certainty = certainty
    }
}

private struct DocumentDateRow: Sendable {
    let volumeId: String
    let documentId: String
    /// Earliest bound of the document date range, normalized to `yyyy-MM-dd`.
    /// Stored in the `date_iso` column (name preserved for schema compatibility).
    let dateISOMin: String?
    /// Latest bound of the document date range, normalized to `yyyy-MM-dd`.
    /// Stored in the `date_iso_max` column added in version 5.
    let dateISOMax: String?
    /// Original granularity of the source date (`day`/`month`/`year`), stored in
    /// `date_precision`. `nil` when the date came from the plain-text heuristic.
    let precision: String?
    /// Nature of the source date (`exact`/`range`/`approximate`/`textOnly`), stored in
    /// `date_certainty`. `nil` when no date could be extracted.
    let certainty: String?
}

struct DocumentCacheRow: Sendable {
    let volumeId: String
    let documentId: String
    let documentNumber: String?
    let header: String
    let dateline: String?
    let sourceNote: String?
    let bodyText: String
    let subjectTagIds: String?
    let userTagIds: String?
    let summaryText: String?
    let noteText: String?
    let isEditorialNote: Bool
    /// `true` when the document was promoted from a prose-only front-matter structural
    /// section (preface, introduction, prefatoryNote, terms, etc.).
    let isFrontMatter: Bool
}

// MARK: - FRUSASTNode Extensions

extension FRUSASTNode {
    /// All plain text content of this node and its descendants.
    var plainText: String {
        switch self {
        case .text(let s):   return s
        case .formula(let s): return s
        case .lineBreak:     return " "
        case .pageBreak, .document: return ""
        case .head(let c), .dateline(let c), .paragraph(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .term(let c), .editorialNote(let c), .titlePage(let c),
             .supplied(let c), .sic(let c), .corr(let c):
            return c.map(\.plainText).joined(separator: " ")
        case .attachment(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .date(_, _, _, _, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .emphasis(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .persName(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .gloss(_, let c):    return c.map(\.plainText).joined(separator: " ")
        case .crossReference(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .figure(_, let c):   return c.map(\.plainText).joined(separator: " ")
        case .footnote(_, _, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .table(let rows):    return rows.map(\.plainText).joined(separator: " ")
        case .tableRow(let cells): return cells.map(\.plainText).joined(separator: " ")
        case .tableCell(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .list(_, let items): return items.map(\.plainText).joined(separator: " ")
        case .listItem(let c):    return c.map(\.plainText).joined(separator: " ")
        case .unknown(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        }
    }

    /// Like `plainText`, but with every `.footnote` subtree excluded — at any depth,
    /// not just among direct children. Used by `IndexingPipeline.extractHeader` so
    /// footnotes nested inside `<hi>`/`<persName>`/`<p>` markup within `<head>` cannot
    /// leak into the stored document title.
    var plainTextExcludingFootnotes: String {
        switch self {
        case .footnote:
            return ""
        case .text, .formula, .lineBreak, .pageBreak, .document:
            return plainText
        default:
            return children.map(\.plainTextExcludingFootnotes).joined(separator: " ")
        }
    }

    /// Direct and indirect child nodes (used for recursive cross-reference and page-range extraction).
    var children: [FRUSASTNode] {
        switch self {
        case .text, .formula, .lineBreak, .pageBreak: return []
        case .document(_, _, let c): return c
        case .head(let c), .dateline(let c), .paragraph(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .term(let c), .editorialNote(let c), .titlePage(let c),
             .supplied(let c), .sic(let c), .corr(let c):
            return c
        case .attachment(_, let c): return c
        case .date(_, _, _, _, _, let c): return c
        case .emphasis(_, let c): return c
        case .persName(_, let c): return c
        case .gloss(_, let c):    return c
        case .crossReference(_, _, let c): return c
        case .figure(_, let c):   return c
        case .footnote(_, _, _, let c): return c
        case .table(let rows):    return rows
        case .tableRow(let cells): return cells
        case .tableCell(_, _, let c): return c
        case .list(_, let items): return items
        case .listItem(let c):    return c
        case .unknown(_, _, let c): return c
        }
    }
}

// MARK: - String helper

private extension String {
    var normalizedWhitespace: String {
        split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - IndexingError

/// Errors thrown by `IndexingPipeline`.
public enum IndexingError: Error, Sendable {
    /// The volume XML file was not found in the volumes directory.
    case volumeNotFound(volumeId: String)
    /// The SQLite database could not be opened at the given path.
    case databaseOpenFailed(message: String)
    /// A SQLite operation returned a non-OK result code.
    case sqliteError(code: Int32, message: String)
}
