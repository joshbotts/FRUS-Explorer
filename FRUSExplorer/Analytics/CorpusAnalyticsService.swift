// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Result Types

/// Document frequency broken down by year of origin.
///
/// `year` is the four-digit start year extracted from the volume ID
/// (e.g. `frus1969-76v01` → 1969). Documents whose volume IDs cannot
/// be parsed are omitted.
///
/// Version history:
///   1.0 — Session 98: initial implementation
struct YearFrequency: Sendable, Identifiable {
    let year: Int
    let count: Int
    var id: Int { year }
}

/// Document frequency for a single `(year, volumeId)` pair — the per-source breakdown
/// behind the By-Year / By-Decade charts, used to color-code each period by the
/// volumes contributing the matches (the analytics analogue of the Chronology
/// distribution chart).
///
/// Version history:
///   1.0 — Session 165: source color-coding for the time-series analytics charts
struct YearVolumeFrequency: Sendable, Identifiable {
    let year: Int
    let volumeId: String
    let count: Int
    var id: String { "\(year)/\(volumeId)" }
}

/// Document frequency broken down by FRUS subseries.
///
/// The subseries is the volume ID's leading year (or year range) — the same
/// publication-era bucket the Corpus Browser groups on (e.g. `frus1969-76v01` →
/// `1969-76`, `frus1945Berlinv01` → `1945`); see `subseries(fromVolumeId:)`.
/// Documents whose volume IDs cannot be parsed are omitted.
///
/// Version history:
///   1.0 — Session 98: initial implementation
///   1.1 — #208: subseries derived by the leading-year algorithm (Corpus Browser parity)
struct SubseriesFrequency: Sendable, Identifiable {
    let subseries: String
    let count: Int
    var id: String { subseries }
}

/// Document frequency broken down by individual FRUS volume.
///
/// `volumeId` is the full volume identifier (e.g. `frus1969-76v01`). The display
/// label (the human-readable volume title) is resolved by the view from the
/// manifest — only the ID and count are computed here. Volumes in which the query
/// term does not appear are omitted entirely, mirroring `SubseriesFrequency`.
///
/// Version history:
///   1.0 — Session 163: initial implementation (By-Volume analytics axis)
struct VolumeFrequency: Sendable, Identifiable {
    let volumeId: String
    let count: Int
    var id: String { volumeId }
}

// `TermCount` moved to `WordCloudKit` in O-1 — the generator emits the same type.

/// Document frequency aggregated into ten-year buckets (1860s, 1870s, …).
///
/// The decade is the year floored to the nearest ten: a document dated 1973
/// is counted under `decadeStart = 1970`. Documents whose date cannot be
/// resolved to a year are excluded.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct DecadeFrequency: Sendable, Identifiable {
    /// The first calendar year of the ten-year bucket (e.g. `1960` for the 1960s).
    let decadeStart: Int
    let count: Int
    var id: Int { decadeStart }
}

/// Document frequency aggregated per calendar month.
///
/// Documents whose `date_iso` lacks a month component (e.g. only `"1969"`) are
/// excluded — they cannot be placed in a specific month bucket.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct MonthFrequency: Sendable, Identifiable {
    /// First day of the month, used for Swift Charts date-axis positioning.
    let date: Date
    /// Display label in `yyyy-MM` form (e.g. `"1969-02"`).
    let label: String
    let count: Int
    var id: String { label }
}

/// Document frequency aggregated per calendar day.
///
/// Documents whose `date_iso` lacks a day component (e.g. only `"1969-02"` or
/// only `"1969"`) are excluded — they cannot be placed on a specific day.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct DayFrequency: Sendable, Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

/// Snapshot of an `AnalyticsView` query, used to hand a term and date window
/// off between Corpus Analytics and Search.
///
/// ## Cross-view handoff
/// This struct mirrors the role `SearchParameters` plays for `pendingSearch`:
/// a lightweight, `Sendable`/`Equatable` value placed on `AppState.pendingAnalytics`
/// that the destination view observes, applies, and clears.
///
/// - `Search → Analytics` (Direction B): when a search hits `SearchViewModel
///   .searchHardLimit`, `SearchView` offers to open Analytics seeded with the
///   submitted keywords (and the active date filter, if any) so the user can
///   visualize the result distribution over time and pick a narrower range.
/// - `Analytics → Search` (Direction A): `AnalyticsView` offers to jump to
///   Search pre-filled with `committedTerm` and the current year-range filter
///   (via `SearchParameters`, not this type) so the user can see the matching
///   documents directly.
///
/// `yearRangeStart`/`yearRangeEnd` are plain integer years — `AnalyticsView`
/// stores its range that way — and are converted to `DateRange`'s ISO strings
/// only when building `SearchParameters` for the reverse handoff.
///
/// ## Word Cloud → Analytics scope
/// `scopeVolumeIds` carries an optional volume-ID scope used by the
/// `WordCloud → Analytics` handoff: tapping a word in a volume- or subseries-scoped
/// cloud opens Analytics restricted to those volumes (`scopeLabel` names the scope
/// for the UI). Scopes Corpus Analytics cannot express at volume granularity
/// (a single document, a collection, a user tag, a saved search) fall back to the
/// whole corpus — `scopeVolumeIds == nil` — per the cross-surface contract.
///
/// Version history:
///   1.0 — Session 2026-06-07: introduced for Search ↔ Analytics integration
///   1.1 — Session 164: `scopeVolumeIds` / `scopeLabel` for the Word Cloud → Analytics
///          handoff (volume / subseries scope, with whole-corpus fallback)
struct AnalyticsParameters: Sendable, Equatable {
    /// The keyword term to chart. Required — `AnalyticsView.runSearch()` is a
    /// no-op for an empty term.
    var term: String

    /// Optional lower bound for the chart's year-range filter. When `nil`,
    /// `AnalyticsView` keeps its default (1861).
    var yearRangeStart: Int?

    /// Optional upper bound for the chart's year-range filter. When `nil`,
    /// `AnalyticsView` keeps its default (current calendar year).
    var yearRangeEnd: Int?

    /// Optional volume-ID scope. When non-empty, Corpus Analytics restricts every
    /// count to documents in these volumes (the Word Cloud → Analytics handoff for
    /// volume / subseries scopes). `nil` or empty means the whole indexed corpus.
    var scopeVolumeIds: [String]?

    /// Human-readable label for the active scope (e.g. a volume or subseries title),
    /// surfaced in the Analytics UI so the user knows the counts are scoped. `nil`
    /// for a corpus-wide query.
    var scopeLabel: String?

    /// Creates a parameter snapshot to seed `AnalyticsView`.
    init(term: String, yearRangeStart: Int? = nil, yearRangeEnd: Int? = nil,
         scopeVolumeIds: [String]? = nil, scopeLabel: String? = nil) {
        self.term = term
        self.yearRangeStart = yearRangeStart
        self.yearRangeEnd = yearRangeEnd
        self.scopeVolumeIds = scopeVolumeIds
        self.scopeLabel = scopeLabel
    }
}

// MARK: - CorpusAnalyticsService

/// Provides corpus-level frequency analytics over the FTS5 search index.
///
/// All query methods run on the actor's executor (off the main thread),
/// so callers on `@MainActor` automatically get background execution via
/// `await` without needing `Task.detached`.
///
/// ## Caching
/// Results are cached in memory using the query term as key, bounded at
/// 50 entries per cache dictionary. The full `document_dates` table is
/// fetched once from `IndexingPipeline` and cached in `documentDateCache`;
/// it is cleared alongside the other caches when `invalidateCache()` is
/// called (e.g. after a volume is indexed or deleted).
///
/// ## Year bucketing
/// `termFrequencyByYear(term:)` groups results by the **actual date** of
/// each matching document, taken from the `date_iso` column of the
/// `document_dates` auxiliary table (e.g. `"1969-02-15"` → year 1969).
/// Documents with no stored date fall back to the start year of their
/// volume ID. This replaces the previous approach of bucketing every
/// document in a volume under the volume's start year.
///
/// ## Volume ID Parsing
/// FRUS volume IDs follow the pattern `frus{subseries}{area?}v{number}[suffix]`,
/// for example `frus1969-76v01`. The start year is the first four digits after
/// "frus". The subseries is the **leading year (or year range)** only — the same
/// value `ManifestGeneratorCore.VolumeIDParser` bakes into `manifest.json` and the
/// Corpus Browser groups on (`subseries(fromVolumeId:)`, #208).
///
/// ## Analytics Coverage
/// - `termFrequencyByYear(term:)` — matching docs per year (actual document date)
/// - `termFrequencyBySubseries(term:)` — matching docs per subseries (volume ID)
/// - `termFrequencyByVolume(term:)` — matching docs per individual volume (volume ID)
///
/// Version history:
///   1.0 — Session 98: initial implementation
///   1.1 — Session 119: `termFrequencyByYear` now uses per-document `date_iso`
///          from `IndexingPipeline.allDocumentDates()` instead of bucketing by
///          volume start year; `pipeline` dependency added; `documentDateCache`
///          lazy-populated and cleared with other caches on `invalidateCache()`
///   1.2 — Session 121: add `termFrequencyByDecade`, `termFrequencyByMonth`, and
///          `termFrequencyByDay`; new `DecadeFrequency`/`MonthFrequency`/`DayFrequency`
///          result types; multi-word queries are now split on whitespace and ANDed
///          (each word individually Porter-stemmed) rather than treated as a single
///          opaque keyword
///   1.3 — Session 163: add `termFrequencyByVolume` (and `VolumeFrequency`) for the
///          By-Volume analytics axis; mirrors `termFrequencyBySubseries` but buckets
///          by full volume ID. New `volumeFrequencyCache` cleared in `invalidateCache()`.
///   1.4 — Session 163: queries now parse the term with `FTS5InlineQueryParser` (the same
///          parser the main Search box uses) instead of a naive whitespace split, so
///          quoted phrases, `OR`/`NOT`, and wildcards behave identically in Analytics and
///          Search. Fixes analytics over-reporting hits for quoted phrase queries (it had
///          been silently downgrading `"a b"` to a loose `a AND b`).
///   1.5 — Prep-B (analytics CA-track): add `documentTotalsByYear`/`documentTotalsByDecade`
///          — the per-period count of ALL indexed documents (the normalization
///          denominator CA-4 consumes), derived from the cached `resolvedDocumentDates()`
///          and cached in `documentTotalsByYearCache` (cleared on `invalidateCache()`).
///   1.6 — CA-4 review fix: `documentTotalsByYear` now counts the SAME document
///          population as the numerator (`termFrequencyByYear`) — every indexed document
///          via `IndexingPipeline.allDocumentKeysWithDates()`, dated docs by `date_iso`
///          year and undated docs by volume start year — instead of only the dated
///          subset. Fixes normalized shares exceeding 100% when a volume's start year
///          received undated matched documents the dated-only denominator lacked.
///          New `allDocumentKeysWithDatesCache` cleared in `invalidateCache()`.
///   1.7 — CA-5 (analytics CA-track): removed the dead `topTermsByYear(year:limit:)`
///          stub (it returned `[]` and was wired to no UI). Per-era person analytics
///          in `PersonAnalyticsView` are the honest replacement, computed over
///          `person_mentions × document_dates` in `PersonMentionStore` (CA-5).
actor CorpusAnalyticsService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline

    // MARK: - Caches

    private var yearFrequencyCache: [String: [YearFrequency]] = [:]
    private var yearVolumeFrequencyCache: [String: [YearVolumeFrequency]] = [:]
    private var subseriesFrequencyCache: [String: [SubseriesFrequency]] = [:]
    private var volumeFrequencyCache: [String: [VolumeFrequency]] = [:]
    private var decadeFrequencyCache: [String: [DecadeFrequency]] = [:]
    private var monthFrequencyCache: [String: [MonthFrequency]] = [:]
    private var dayFrequencyCache: [String: [DayFrequency]] = [:]
    /// Lazily populated on the first `termFrequencyByYear` call; maps
    /// `"volumeId/documentId"` → `date_iso` string (e.g. `"1969-02-15"`).
    private var documentDateCache: [String: String]? = nil
    /// Lazily populated on the first `documentTotalsByYear` call: **every** indexed
    /// document (including undated ones), each with its optional `date_iso`. This is
    /// the population the normalization denominator counts — the same population the
    /// term-frequency numerator draws from (dated docs by `date_iso`, undated docs by
    /// volume start year), so a normalized share never exceeds 100%.
    private var allDocumentKeysWithDatesCache: [(volumeId: String, documentId: String, dateISO: String?)]? = nil
    /// Cache for `documentTotalsByYear` keyed by the volume-ID scope
    /// (`scopedCacheKey(term:volumeIds:)` with an empty term is the whole-corpus key).
    /// Reused by `documentTotalsByDecade`, which buckets from the per-year totals.
    private var documentTotalsByYearCache: [String: [Int: Int]] = [:]
    /// Cache for the `rowid → (volumeId, documentId)` map behind the occurrence numerator (PR-D).
    /// One entry for the whole index; cleared with everything else by `invalidateCache()`.
    private var rowidKeyCache: [Int64: (volumeId: String, documentId: String)]? = nil
    private let cacheLimit = 50

    // MARK: - Initialiser

    init(fts5Store: FTS5Store, pipeline: IndexingPipeline) {
        self.fts5Store = fts5Store
        self.pipeline = pipeline
    }

    // MARK: - Cache Management

    /// Flushes all in-memory caches, including the document-date lookup table.
    ///
    /// Call after the FTS5 index has been modified (e.g. a volume was indexed
    /// or deleted) so stale analytics results are not served.
    func invalidateCache() {
        yearFrequencyCache.removeAll()
        yearVolumeFrequencyCache.removeAll()
        subseriesFrequencyCache.removeAll()
        volumeFrequencyCache.removeAll()
        decadeFrequencyCache.removeAll()
        monthFrequencyCache.removeAll()
        dayFrequencyCache.removeAll()
        documentTotalsByYearCache.removeAll()
        documentDateCache = nil
        allDocumentKeysWithDatesCache = nil
        rowidKeyCache = nil
    }

    // MARK: - Private Helpers

    /// Returns the cached document-date dictionary, fetching it from the
    /// pipeline on first call.
    ///
    /// The dictionary maps `"volumeId/documentId"` → ISO 8601 date string.
    /// Populated once per cache lifetime; cleared by `invalidateCache()`.
    private func resolvedDocumentDates() async throws -> [String: String] {
        if let cached = documentDateCache { return cached }
        let dates = try await pipeline.allDocumentDates()
        documentDateCache = dates
        return dates
    }

    /// Returns the cached "every indexed document with its optional date" list,
    /// fetching it from the pipeline on first call.
    ///
    /// Each entry is `(volumeId, documentId, dateISO?)` for one indexed document —
    /// undated documents carry a `nil` `dateISO`. This is the population the
    /// normalization denominator counts. Populated once per cache lifetime; cleared
    /// by `invalidateCache()`.
    private func allDocumentKeysWithDates() async throws
        -> [(volumeId: String, documentId: String, dateISO: String?)]
    {
        if let cached = allDocumentKeysWithDatesCache { return cached }
        let keys = try await pipeline.allDocumentKeysWithDates()
        allDocumentKeysWithDatesCache = keys
        return keys
    }

    /// Builds the FTS5 query for an analytics term using the **same** inline-syntax
    /// parser as the main Search box (`FTS5InlineQueryParser`).
    ///
    /// This is what keeps Corpus Analytics and Search in agreement: a quoted
    /// `"defense materials"` becomes an ordered **phrase** match (not a loose AND of
    /// the two words), and `OR` / `NOT` / `term*` / `(grouping)` all behave exactly as
    /// they do in Search. Previously analytics split on whitespace and let
    /// `FTS5Query.sanitizeTerm` strip the quotes, silently downgrading every phrase to
    /// an AND — so analytics over-reported hits relative to Search for any quoted query.
    ///
    /// Returns `nil` when `term` carries no positive search content (empty, or only
    /// excluded terms), mirroring `SearchService`.
    nonisolated private static func makeQuery(from term: String) -> FTS5Query? {
        let parsed = FTS5InlineQueryParser.parseDetailed(term)
        guard let expression = parsed.expression else { return nil }
        // Refuse exact-word queries rather than answer a different question.
        //
        // `=word` is a POST-filter: the MATCH expression is the stem, and Search narrows the
        // matched rows afterwards with the `frus_exact_word` SQL function
        // (`IndexingPipeline.swift`). This service goes straight to `FTS5Store.matchedDocumentKeys`,
        // a bare MATCH with nowhere to apply that filter — so charting the expression would count
        // every document containing the STEM. `=containment` would plot "containment", "contains"
        // and "container" together, while the chart's own "View N documents" hand-off sends the
        // researcher to Search, which filters, and shows fewer. Two numbers for one query, both
        // presented as authoritative, differing by an amount nobody could predict.
        //
        // Q-3b shipped exact-word mode specifically so a count could not lie; silently widening the
        // query here would undo that in the surface where a wrong count becomes a chart, and a
        // chart becomes an argument. `nil` propagates to an explicit, explained empty state in
        // `AnalyticsView` — see `unsupportedExactTerms`.
        guard parsed.exactTerms.isEmpty else { return nil }
        return FTS5Query(keywordExpression: expression)
    }

    /// The `=word` operands in `term`, which this service cannot honour.
    ///
    /// Non-empty means every frequency function will return no data for `term`, by the deliberate
    /// refusal in ``makeQuery(from:)``. Callers use this to explain the empty result instead of
    /// showing a bare "No Results", which would read as "this word never appears" — the opposite of
    /// what an exact-word query with matches actually means.
    ///
    /// `nonisolated` and cheap: a parse, no I/O. Safe to call from a view body.
    nonisolated static func unsupportedExactTerms(in term: String) -> [String] {
        FTS5InlineQueryParser.parseDetailed(term).exactTerms
    }

    /// Helper for the four date-bucketed methods. Returns the matched
    /// `(documentId, volumeId)` keys for the given term along with the cached
    /// document-date dictionary. Returns nil if `term` contains no searchable
    /// keywords.
    ///
    /// - Parameters:
    ///   - term: The keyword term, parsed with `FTS5InlineQueryParser`.
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only keys whose
    ///     `volumeId` is in the set are returned (the Word Cloud → Analytics scope).
    private func matchedDocsAndDates(term: String, volumeIds: Set<String>? = nil) async throws
        -> (keys: [(documentId: String, volumeId: String)], dates: [String: String])?
    {
        guard let query = Self.makeQuery(from: term) else { return nil }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }
        let dates = try await resolvedDocumentDates()
        return (keys, dates)
    }

    /// Builds the in-memory cache key for a query, folding in any volume-ID scope so
    /// scoped and corpus-wide results never collide. A corpus-wide query (`nil` or
    /// empty scope) keys on the bare term, preserving existing unscoped cache entries.
    ///
    /// - Parameters:
    ///   - term: The query term.
    ///   - volumeIds: The active volume-ID scope, or `nil`/empty for the whole corpus.
    /// - Returns: A stable cache key unique to the `(term, scope)` pair.
    private func scopedCacheKey(term: String, volumeIds: Set<String>?) -> String {
        guard let volumeIds, !volumeIds.isEmpty else { return term }
        return term + "\u{1}" + volumeIds.sorted().joined(separator: "|")
    }

    // MARK: - Frequency Queries

    /// Returns the count of documents matching `term`, grouped by year.
    ///
    /// The year for each document is taken from the `date_iso` value stored
    /// in the `document_dates` auxiliary table (the actual document date, e.g.
    /// `"1969-02-15"` → 1969). Documents with no stored date fall back to the
    /// start year parsed from their volume ID. Documents for which neither
    /// source yields a valid year are silently omitted.
    ///
    /// Results are sorted by year ascending.
    ///
    /// - Parameters:
    ///   - term: A single keyword to search (no FTS5 operators).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted (the Word Cloud → Analytics handoff scope).
    /// - Returns: Array of `YearFrequency` sorted by `year` ascending.
    func termFrequencyByYear(term: String, volumeIds: Set<String>? = nil) async throws -> [YearFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = yearFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        var counts: [Int: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            let year: Int?
            if let iso = dates[compositeKey] {
                // date_iso is "yyyy-MM-dd" or occasionally just "yyyy"; either way
                // the first four characters encode the year.
                year = Int(iso.prefix(4))
            } else {
                // Fall back to volume start year for undated documents.
                year = Self.startYear(fromVolumeId: key.volumeId)
            }
            guard let y = year else { continue }
            counts[y, default: 0] += 1
        }

        let result = counts
            .map { YearFrequency(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }

        insertIntoCache(&yearFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, broken down by
    /// `(year, volumeId)` — the per-source data behind the color-coded By-Year /
    /// By-Decade charts.
    ///
    /// Uses the same per-document year derivation as `termFrequencyByYear`
    /// (`date_iso` prefix, with the volume start year as a fallback), so summing the
    /// per-volume counts for a year reproduces that year's `termFrequencyByYear`
    /// total exactly. Results are sorted by year, then volume ID.
    ///
    /// - Parameters:
    ///   - term: A keyword query (same inline syntax as the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    /// - Returns: Array of `YearVolumeFrequency`.
    func termFrequencyByYearAndVolume(term: String, volumeIds: Set<String>? = nil) async throws -> [YearVolumeFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = yearVolumeFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        // Key the counts by "year\u{1}volumeId" to avoid allocating a struct per hit.
        var counts: [String: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            let year: Int?
            if let iso = dates[compositeKey] {
                year = Int(iso.prefix(4))
            } else {
                year = Self.startYear(fromVolumeId: key.volumeId)
            }
            guard let y = year else { continue }
            counts["\(y)\u{1}\(key.volumeId)", default: 0] += 1
        }

        let result: [YearVolumeFrequency] = counts.compactMap { pair, count in
            let parts = pair.split(separator: "\u{1}", maxSplits: 1)
            guard parts.count == 2, let y = Int(parts[0]) else { return nil }
            return YearVolumeFrequency(year: y, volumeId: String(parts[1]), count: count)
        }
        .sorted { $0.year != $1.year ? $0.year < $1.year : $0.volumeId < $1.volumeId }

        insertIntoCache(&yearVolumeFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped into ten-year
    /// decade buckets.
    ///
    /// Each year is floored to the nearest ten — 1973 → 1970 — and counts are
    /// summed within the resulting bucket. Documents with no parseable year
    /// (neither in `date_iso` nor in the volume ID) are silently omitted.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords. Multiple keywords are
    ///     AND-combined and individually Porter-stemmed (matching the main search
    ///     behaviour).
    ///   - volumeIds: Optional volume-ID scope, forwarded to `termFrequencyByYear`.
    /// - Returns: Array of `DecadeFrequency` sorted by `decadeStart` ascending.
    func termFrequencyByDecade(term: String, volumeIds: Set<String>? = nil) async throws -> [DecadeFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = decadeFrequencyCache[cacheKey] { return cached }

        // Reuse the per-year computation rather than re-walking the FTS5 result set.
        let yearData = try await termFrequencyByYear(term: term, volumeIds: volumeIds)
        var bucket: [Int: Int] = [:]
        for entry in yearData {
            let decade = (entry.year / 10) * 10
            bucket[decade, default: 0] += entry.count
        }
        let result = bucket
            .map { DecadeFrequency(decadeStart: $0.key, count: $0.value) }
            .sorted { $0.decadeStart < $1.decadeStart }

        insertIntoCache(&decadeFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped per calendar month.
    ///
    /// Documents whose `date_iso` lacks a month component (e.g. `"1969"`) are
    /// excluded — they cannot be placed in a specific month. There is no fallback
    /// to the volume start year here because the granularity demands month-level
    /// precision that volume IDs do not encode.
    ///
    /// Results are sorted by date ascending.
    ///
    /// - Parameters:
    ///   - term: One or more keywords (parsed identically to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    func termFrequencyByMonth(term: String, volumeIds: Set<String>? = nil) async throws -> [MonthFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = monthFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        var counts: [String: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            guard let iso = dates[compositeKey], iso.count >= 7 else { continue }
            // Require a literal "yyyy-MM" prefix with a parseable two-digit month.
            let parts = iso.split(separator: "-")
            guard parts.count >= 2,
                  let year  = Int(parts[0]),
                  let month = Int(parts[1]),
                  (1...12).contains(month),
                  year > 0
            else { continue }
            let label = String(format: "%04d-%02d", year, month)
            counts[label, default: 0] += 1
        }

        let calendar = Calendar(identifier: .gregorian)
        let result: [MonthFrequency] = counts.compactMap { (label, count) in
            let parts = label.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1])
            else { return nil }
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let date = calendar.date(from: comps) else { return nil }
            return MonthFrequency(date: date, label: label, count: count)
        }.sorted { $0.date < $1.date }

        insertIntoCache(&monthFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped per calendar day.
    ///
    /// Documents whose `date_iso` is not a full `yyyy-MM-dd` are excluded.
    /// Results are sorted by date ascending. Note: for high-frequency terms
    /// spanning many decades this returns a very large number of points; callers
    /// should restrict the displayed range via the year-range filter.
    ///
    /// - Parameters:
    ///   - term: One or more keywords (parsed identically to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    func termFrequencyByDay(term: String, volumeIds: Set<String>? = nil) async throws -> [DayFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = dayFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        var counts: [Date: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            guard let iso = dates[compositeKey],
                  iso.count == 10,
                  let date = formatter.date(from: iso)
            else { continue }
            counts[date, default: 0] += 1
        }

        let result = counts
            .map { DayFrequency(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }

        insertIntoCache(&dayFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped by subseries.
    ///
    /// Results are sorted by subseries string ascending. Documents in volumes
    /// whose IDs cannot be parsed are silently omitted.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords (AND-combined).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    /// - Returns: Array of `SubseriesFrequency` sorted by `subseries` ascending.
    func termFrequencyBySubseries(term: String, volumeIds: Set<String>? = nil) async throws -> [SubseriesFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = subseriesFrequencyCache[cacheKey] { return cached }

        guard let query = Self.makeQuery(from: term) else { return [] }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }

        var counts: [String: Int] = [:]
        for key in keys {
            guard let sub = Self.subseries(fromVolumeId: key.volumeId) else { continue }
            counts[sub, default: 0] += 1
        }

        let result = counts
            .map { SubseriesFrequency(subseries: $0.key, count: $0.value) }
            .sorted { $0.subseries < $1.subseries }

        insertIntoCache(&subseriesFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped by individual volume.
    ///
    /// Results are sorted by volume ID ascending. Volumes in which the term never
    /// appears are omitted (the same zero-omission behaviour as
    /// `termFrequencyBySubseries`). The caller resolves each `volumeId` to a display
    /// title via the manifest.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords (AND-combined,
    ///     individually Porter-stemmed — identical handling to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    /// - Returns: Array of `VolumeFrequency` sorted by `volumeId` ascending.
    func termFrequencyByVolume(term: String, volumeIds: Set<String>? = nil) async throws -> [VolumeFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = volumeFrequencyCache[cacheKey] { return cached }

        guard let query = Self.makeQuery(from: term) else { return [] }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }

        var counts: [String: Int] = [:]
        for key in keys {
            counts[key.volumeId, default: 0] += 1
        }

        let result = counts
            .map { VolumeFrequency(volumeId: $0.key, count: $0.value) }
            .sorted { $0.volumeId < $1.volumeId }

        insertIntoCache(&volumeFrequencyCache, key: cacheKey, value: result)
        return result
    }

    // MARK: - Corpus Document Totals (normalization denominator)

    /// Returns the count of **all** indexed documents per year — the denominator for
    /// the "% of documents" normalization mode (CA-4), independent of any search term.
    ///
    /// This counts exactly the same document population, and derives each document's
    /// year with exactly the same logic, as the term-frequency numerator
    /// (`termFrequencyByYear`): a document's year comes from the first four characters
    /// of its stored `date_iso` (e.g. `"1969-02-15"` → 1969) when present, else it
    /// falls back to the start year parsed from its volume ID. **Undated** documents
    /// are therefore counted here (via the volume-start-year fallback), not dropped —
    /// which is what keeps the normalized share `matches / total ≤ 100%`. Enumerating
    /// only the dated subset (as an earlier version did) undercounted the denominator
    /// while the numerator still counted undated matches, so a share could exceed 100%.
    /// Documents whose year cannot be resolved from either source are omitted from both.
    ///
    /// - Parameter volumeIds: Optional volume-ID scope. When non-empty, only documents
    ///   whose `volumeId` is in the set are counted, so the denominator matches a
    ///   scoped numerator's coverage.
    /// - Returns: A `[year: totalDocuments]` dictionary. Empty when the index is empty.
    func documentTotalsByYear(volumeIds: Set<String>? = nil) async throws -> [Int: Int] {
        let cacheKey = scopedCacheKey(term: "", volumeIds: volumeIds)
        if let cached = documentTotalsByYearCache[cacheKey] { return cached }

        let all = try await allDocumentKeysWithDates()
        let scope = (volumeIds?.isEmpty == false) ? volumeIds : nil

        var totals: [Int: Int] = [:]
        for entry in all {
            if let scope, !scope.contains(entry.volumeId) { continue }
            let year: Int?
            if let iso = entry.dateISO {
                // date_iso is "yyyy-MM-dd" or occasionally just "yyyy"; the first four
                // characters encode the year — identical to `termFrequencyByYear`.
                year = Int(iso.prefix(4))
            } else {
                // Fall back to the volume start year for undated documents — the same
                // fallback the numerator uses — so both sides count the same population.
                year = Self.startYear(fromVolumeId: entry.volumeId)
            }
            guard let y = year else { continue }
            totals[y, default: 0] += 1
        }

        insertIntoCache(&documentTotalsByYearCache, key: cacheKey, value: totals)
        return totals
    }

    /// Returns the count of **all** indexed documents per ten-year decade bucket — the
    /// By-Decade denominator for the "% of documents" normalization mode (CA-4).
    ///
    /// Buckets the per-year totals from `documentTotalsByYear(volumeIds:)` by flooring
    /// each year to the nearest ten (1973 → 1970), so numerator and denominator share
    /// the exact same bucketing the By-Decade chart uses.
    ///
    /// - Parameter volumeIds: Optional volume-ID scope, forwarded to
    ///   `documentTotalsByYear`.
    /// - Returns: A `[decadeStart: totalDocuments]` dictionary.
    func documentTotalsByDecade(volumeIds: Set<String>? = nil) async throws -> [Int: Int] {
        let byYear = try await documentTotalsByYear(volumeIds: volumeIds)
        var totals: [Int: Int] = [:]
        for (year, count) in byYear {
            let decade = (year / 10) * 10
            totals[decade, default: 0] += count
        }
        return totals
    }

    // MARK: - Cache Helpers

    private func insertIntoCache<V>(_ cache: inout [String: V], key: String, value: V) {
        if cache.count >= cacheLimit {
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[key] = value
    }

    // MARK: - Volume ID Parsing

    /// Extracts the four-digit start year from a FRUS volume ID.
    ///
    /// For `frus1969-76v01` this returns `1969`. Returns `nil` if the
    /// volume ID does not begin with "frus" followed by four digits.
    // MARK: - Occurrences (R-2 PR-D)

    /// Whether `term` can be counted by occurrence, resolved through SQLite's own tokenizer.
    ///
    /// Cheap: a parse plus one tokenizer probe, no index scan.
    func occurrenceAvailability(for term: String) async -> OccurrenceAvailability {
        var resolved: [String: String?] = [:]
        // `classify` is synchronous, so the stem is pre-resolved for the one word it can ask about.
        let parsed = FTS5InlineQueryParser.parseDetailed(term)
        for operand in parsed.operands where operand.kind == .word {
            resolved[operand.text] = try? await fts5Store.indexStem(of: operand.text)
        }
        return OccurrenceAvailability.classify(term: term) { resolved[$0] ?? nil }
    }

    /// Total occurrences of `term`'s stem per year, over the same document population as
    /// ``termFrequencyByYear(term:volumeIds:)``.
    ///
    /// ## The population trap this is written around
    /// The document numerator dates a matched document by `date_iso`'s first four characters and, for
    /// an undated one, by its volume's start year (`startYear(fromVolumeId:)`). If this method bucketed
    /// with a SQL `GROUP BY` on `date_iso`, every undated document's occurrences would silently vanish
    /// while its *document* stayed in the other series — producing an "occurrences per document fell"
    /// trend out of nothing, and the exact mirror image of the bug CA-4's review fixed on the
    /// normalisation denominator. So the bucketing happens **here, in Swift, against the same rule**.
    ///
    /// ## Why it does not join in SQL
    /// `FTS5Store.termOccurrencesByDocument(stem:)` returns rowids, and this resolves them against a
    /// cached rowid → key map. Joining in SQL costs 40–90× more on the real index: one page fault per
    /// matched document, on a table whose rows average 5.7 KB. Measured — `state` is 0.233 s this way
    /// and 12.91 s joined.
    ///
    /// - Parameters:
    ///   - term: the analytics term. Must be occurrence-countable; see ``occurrenceAvailability(for:)``.
    ///   - volumeIds: optional scope. Applied to the same key space as the document numerator.
    /// - Returns: one entry per year with occurrences, ascending. Empty when the term is not
    ///   occurrence-countable or the index has never seen its stem — callers must distinguish those
    ///   two with `occurrenceAvailability(for:)` rather than reading emptiness as zero.
    func termOccurrencesByYear(term: String, volumeIds: Set<String>? = nil) async throws -> [YearFrequency] {
        guard let stem = await occurrenceAvailability(for: term).stem else { return [] }
        let cacheKey = scopedCacheKey(term: "occ:\(stem)", volumeIds: volumeIds)
        if let cached = yearFrequencyCache[cacheKey] { return cached }

        let perDocument = try await fts5Store.termOccurrencesByDocument(stem: stem)
        guard !perDocument.isEmpty else { return [] }

        let keysByRowid = try await resolvedRowidKeys()
        let dates = try await resolvedDocumentDates()

        var counts: [Int: Int] = [:]
        for entry in perDocument {
            guard let key = keysByRowid[entry.documentRowid] else { continue }
            if let volumeIds, !volumeIds.contains(key.volumeId) { continue }
            // Byte-for-byte the numerator's year rule (see `termFrequencyByYear`).
            let year: Int?
            if let iso = dates["\(key.volumeId)/\(key.documentId)"] {
                year = Int(iso.prefix(4))
            } else {
                year = Self.startYear(fromVolumeId: key.volumeId)
            }
            guard let y = year else { continue }
            counts[y, default: 0] += entry.occurrences
        }

        let result = counts
            .map { YearFrequency(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
        insertIntoCache(&yearFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Cached `rowid → (volumeId, documentId)` map for the whole index.
    ///
    /// One sequential pass served by a covering index — 0.114 s for 316,839 rows. Cleared by
    /// ``invalidateCache()`` with the rest.
    private func resolvedRowidKeys() async throws -> [Int64: (volumeId: String, documentId: String)] {
        if let cached = rowidKeyCache { return cached }
        var map: [Int64: (volumeId: String, documentId: String)] = [:]
        for row in try await pipeline.allDocumentRowidKeys() {
            map[row.rowid] = (volumeId: row.volumeId, documentId: row.documentId)
        }
        rowidKeyCache = map
        return map
    }

    nonisolated static func startYear(fromVolumeId volumeId: String) -> Int? {
        guard volumeId.hasPrefix("frus") else { return nil }
        let afterFrus = volumeId.dropFirst(4)
        let digits = afterFrus.prefix(while: { $0.isNumber })
        guard digits.count == 4, let year = Int(digits) else { return nil }
        return year
    }

    /// Extracts the subseries string from a FRUS volume ID, using the **leading-year** algorithm —
    /// the single source of truth the Corpus Browser groups on (#208).
    ///
    /// This matches `ManifestGeneratorCore.VolumeIDParser.subseries`, whose output is baked into
    /// `manifest.json`'s `subseries` field. It takes the 4-digit year (plus an optional `-YY`/`-YYYY`
    /// range) immediately after `"frus"` and ignores everything after it — volume markers, part
    /// numbers, and conference/area/supplement tokens. So `frus1945Berlinv01` → `"1945"` (not
    /// `"1945Berlin"`), `frus1863p2` → `"1863"`, `frus1969-76ve01` → `"1969-76"`. It is the
    /// manifest-free fallback; consumers that have a `ManifestStore` prefer its precomputed
    /// `VolumeManifestEntry.subseries` field, which this exactly mirrors.
    ///
    /// The previous trailing-`v\d+`-strip algorithm diverged from the browser for ~158 of the 552
    /// bundled volumes: it returned `nil` for any id without a `vNN` marker (all pre-1918 annuals,
    /// Vietnam extras, conference-only ids) and kept the area token for the rest.
    ///
    /// Returns `nil` only when the id does not begin with `"frus"` followed by a 4-digit year.
    nonisolated static func subseries(fromVolumeId volumeId: String) -> String? {
        guard volumeId.hasPrefix("frus") else { return nil }
        let afterFrus = volumeId.dropFirst(4)
        guard let range = afterFrus.range(of: #"^\d{4}(-\d{2,4})?"#, options: .regularExpression) else {
            return nil
        }
        return String(afterFrus[range])
    }
}
