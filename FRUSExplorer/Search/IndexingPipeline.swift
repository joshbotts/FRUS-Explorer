// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

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
    /// Increment this value when the `frus_documents` FTS5 schema changes in a way
    /// that requires all downloaded volumes to be re-indexed.
    ///
    /// - Version 3: `is_editorial_note UNINDEXED` column added (Session 38/48).
    ///   Prior databases lacked this column (FTS5 `ALTER TABLE` is silently ignored);
    ///   `FTS5Connection.createSchema` detects and rebuilds when absent.
    public static let currentFTSSchemaVersion: Int = 3

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
    public static let currentDateIndexVersion: Int = 5

    /// UserDefaults key under which the installed date-index version is persisted.
    public static let dateIndexVersionKey = "frusExplorer.dateIndexVersion"

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

    // MARK: - Logger

    private let logger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "IndexingPipeline")

    // MARK: - Dependencies (let — accessible from nonisolated methods)

    private let fts5Store: FTS5Store
    private let volumesDirectory: URL
    private let subjectTagStore: SubjectTagStore
    private let stateTracker: IndexingStateTracker?

    // MARK: - Auxiliary SQLite connection

    nonisolated(unsafe) private var auxDb: OpaquePointer?
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
    /// an inline progress capsule. The stream is unbuffered (`.bufferingNewest(1)`) so
    /// a slow consumer never causes memory growth.
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
    ///   - subjectTagStore: Provides subject tag IDs for indexed documents.
    ///   - stateTracker: Optional tracker for interrupted-indexing sentinel persistence.
    ///   - concurrencyLimit: Maximum simultaneous XML parsers. Default 4.
    public init(
        fts5Store: FTS5Store,
        databaseURL: URL,
        volumesDirectory: URL,
        subjectTagStore: SubjectTagStore,
        stateTracker: IndexingStateTracker? = nil,
        concurrencyLimit: Int = 4
    ) throws {
        self.fts5Store = fts5Store
        self.databaseURL = databaseURL
        self.volumesDirectory = volumesDirectory
        self.subjectTagStore = subjectTagStore
        self.stateTracker = stateTracker
        self.concurrencyLimit = concurrencyLimit

        let (stream, continuation) = AsyncStream.makeStream(of: IndexingProgress.self)
        _progress = stream
        progressContinuation = continuation

        let (updateStream, updateContinuation) = AsyncStream.makeStream(
            of: IndexingProgressUpdate.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        _progressStream = updateStream
        progressUpdateContinuation = updateContinuation

        let (metaStream, metaContinuation) = AsyncStream.makeStream(
            of: VolumeMetadataDiscovered.self,
            bufferingPolicy: .bufferingNewest(1)
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
        auxDb = h

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
        logger.info("indexVolume: \(volumeId, privacy: .public) parsed \(data.documents.count, privacy: .public) docs in \(String(format: "%.1f", parseElapsed), privacy: .public)s")

        // Emit a second .reading update now that the total document count is known.
        // This lets progress bars render a determinate state before storage begins.
        emitUpdate(IndexingProgressUpdate(
            volumeId: volumeId, stage: .reading,
            completedDocuments: 0, totalDocuments: data.documents.count, docsPerSecond: 0
        ))
        emitMetadata(buildMetadata(from: data))

        let storeStart = Date()
        try await storeIndexData(data)
        let storeElapsed = Date().timeIntervalSince(storeStart)
        logger.info("indexVolume: \(volumeId, privacy: .public) stored in \(String(format: "%.1f", storeElapsed), privacy: .public)s")

        // Run optimize() once after a single-volume index. This is acceptable here
        // because single-volume indexing is always an interactive user action.
        let optStart = Date()
        try await fts5Store.optimize()
        let optElapsed = Date().timeIntervalSince(optStart)
        logger.info("indexVolume: \(volumeId, privacy: .public) optimize in \(String(format: "%.1f", optElapsed), privacy: .public)s")

        submitSpotlightItems(for: data)
        await stateTracker?.markCompleted(volumeId: volumeId)
        emit(.completed(volumeCount: 1, documentCount: data.documents.count))
        emitUpdate(IndexingProgressUpdate(
            volumeId: volumeId, stage: .complete,
            completedDocuments: data.documents.count,
            totalDocuments: data.documents.count,
            docsPerSecond: currentDocsPerSecond(forTotal: data.documents.count)
        ))
        let totalElapsed = Date().timeIntervalSince(volumeIndexingStartTime ?? Date())
        logger.info("indexVolume: \(volumeId, privacy: .public) complete — \(data.documents.count, privacy: .public) docs, total \(String(format: "%.1f", totalElapsed), privacy: .public)s")
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
                        completedDocuments: 0, totalDocuments: data.documents.count,
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
                        totalDocuments += data.documents.count
                        // Snapshot mutable counters before use in emit/log to satisfy Swift 6
                        // strict-concurrency: OSLog interpolation creates an autoclosure that
                        // would otherwise capture the mutable vars across an actor hop.
                        let progressNow = completedVolumes + failedVolumes
                        emit(.indexing(volumeId: data.volumeId, current: progressNow, total: total))
                        logger.info("indexAllVolumes: [\(progressNow, privacy: .public)/\(total, privacy: .public)] stored \(data.volumeId, privacy: .public) — \(data.documents.count, privacy: .public) docs in \(String(format: "%.1f", storeElapsed), privacy: .public)s")
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
    /// Enumerates document IDs from `document_cache`, calls `FTS5Store.delete` for
    /// each, then deletes auxiliary rows in a single transaction per table.
    public func removeVolume(_ volumeId: String) async throws {
        let docIds = try fetchDocumentIds(forVolume: volumeId)
        for docId in docIds {
            try await fts5Store.delete(documentId: docId)
        }
        try auxDeleteVolume(volumeId)
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [volumeId]) { _ in }

        logger.info("removeVolume: removed \(docIds.count, privacy: .public) FTS5 documents for \(volumeId, privacy: .public)")
    }

    /// Removes all indexed data for every volume in a single bulk operation.
    ///
    /// Issues one `DELETE` statement per table rather than iterating manifest entries,
    /// making it suitable for the app-reset path where iterating 500+ entries would
    /// cause the UI to hang for tens of seconds.
    public func removeAllVolumesFromIndex() async throws {
        try await fts5Store.deleteAll()
        for table in ["cross_references", "page_ranges", "document_dates",
                      "document_cache", "person_mentions", "persons", "terms"] {
            let stmt = try auxPrepare("DELETE FROM \(table)")
            defer { sqlite3_finalize(stmt) }
            try auxStep(stmt)
        }
        logger.info("removeAllVolumesFromIndex: complete")
    }

    /// Updates the FTS5 index and document cache with a plain-text summary.
    ///
    /// Use this overload when the `GeneratedSummary` SwiftData model cannot safely cross
    /// actor boundaries (e.g. boot-time sync from a background `ModelContext`).
    func updateSummaryText(volumeId: String, documentId: String, responseText: String) async throws {
        guard let cached = try fetchCache(volumeId: volumeId, documentId: documentId) else {
            logger.warning("updateSummaryText: \(volumeId, privacy: .public)/\(documentId, privacy: .public) not in cache")
            return
        }
        let updated = cached.toFTS5Document(summaryText: responseText, noteText: cached.noteText)
        try await fts5Store.update(document: updated)
        try updateCacheFields(volumeId: volumeId, documentId: documentId,
                              summaryText: responseText, noteText: cached.noteText)
    }

    /// Updates the FTS5 index and document cache with research note content and user tag IDs.
    ///
    /// Use this overload when the `ResearchNote` SwiftData model cannot safely cross
    /// actor boundaries (e.g. boot-time sync or post-download sync from a background
    /// `ModelContext`). Converts the note's `[UUID]` tag array to the space-separated
    /// string format stored in FTS5 before calling this method.
    func updateNoteText(
        volumeId: String,
        documentId: String,
        bodyText: String,
        userTagIds: String?
    ) async throws {
        guard let cached = try fetchCache(volumeId: volumeId, documentId: documentId) else {
            logger.warning("updateNoteText: \(volumeId, privacy: .public)/\(documentId, privacy: .public) not in cache")
            return
        }
        let updated = cached.toFTS5Document(
            summaryText: cached.summaryText,
            noteText: bodyText,
            updatedUserTagIds: userTagIds
        )
        try await fts5Store.update(document: updated)
        try updateCacheNoteFields(volumeId: volumeId, documentId: documentId,
                                  userTagIds: userTagIds, noteText: bodyText)
    }

    /// Updates the summary text for a document that is already in the index.
    ///
    /// Reads original field text from `document_cache`, merges in `summary.responseText`,
    /// and calls `FTS5Store.update` so the new text is immediately searchable.
    func updateSummary(_ summary: GeneratedSummary) async throws {
        guard let cached = try fetchCache(volumeId: summary.volumeId, documentId: summary.documentId) else {
            logger.warning("updateSummary: \(summary.volumeId, privacy: .public)/\(summary.documentId, privacy: .public) not in cache")
            return
        }
        let updated = cached.toFTS5Document(summaryText: summary.responseText, noteText: cached.noteText)
        try await fts5Store.update(document: updated)
        try updateCacheFields(volumeId: summary.volumeId, documentId: summary.documentId,
                              summaryText: summary.responseText, noteText: cached.noteText)
    }

    /// Updates the research note text for a document that is already in the index.
    ///
    /// Reads original field text from `document_cache`, merges in `note.bodyText`,
    /// and calls `FTS5Store.update` so the new text is immediately searchable.
    func updateResearchNote(_ note: ResearchNote) async throws {
        guard let cached = try fetchCache(volumeId: note.volumeId, documentId: note.documentId) else {
            logger.warning("updateResearchNote: \(note.volumeId, privacy: .public)/\(note.documentId, privacy: .public) not in cache")
            return
        }
        let updated = cached.toFTS5Document(summaryText: cached.summaryText, noteText: note.bodyText)
        try await fts5Store.update(document: updated)
        try updateCacheFields(volumeId: note.volumeId, documentId: note.documentId,
                              summaryText: cached.summaryText, noteText: note.bodyText)
    }

    // MARK: - Spotlight

    /// Submits CSSearchableItem records for all documents in `data` to the default
    /// Spotlight index. Errors are silently ignored — Spotlight is best-effort.
    private func submitSpotlightItems(for data: VolumeIndexData) {
        let items = data.documents.map { doc -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = doc.header.isEmpty ? doc.id : doc.header
            attrs.contentDescription = String(doc.bodyText.prefix(300))
            attrs.keywords = [data.volumeId, doc.id]
            return CSSearchableItem(
                uniqueIdentifier: "\(data.volumeId)/\(doc.id)",
                domainIdentifier: data.volumeId,
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
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

    // MARK: - Date Lookup (used by DocumentTimelineView)

    /// Returns ISO date strings keyed by `"volumeId/documentId"` for the given document pairs.
    ///
    /// Only pairs with a parseable `date_iso` value in `document_dates` are included.
    /// Unindexed or genuinely undated documents are absent from the result dictionary.
    ///
    /// - Parameter docs: `(volumeId, documentId)` pairs to query. Capped at 500 to stay
    ///   within SQLite's default variable limit; excess pairs are silently ignored.
    /// - Returns: Dictionary mapping composite key → `date_iso` string (e.g. `"1969-02-15"`).
    public func datesByDocumentKey(
        _ docs: [(volumeId: String, documentId: String)]
    ) throws -> [String: String] {
        let capped = Array(docs.prefix(500))
        guard !capped.isEmpty else { return [:] }
        let keys = capped.map { "\($0.volumeId)/\($0.documentId)" }
        let placeholders = keys.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT volume_id || '/' || document_id, date_iso
            FROM document_dates
            WHERE volume_id || '/' || document_id IN (\(placeholders))
            AND date_iso IS NOT NULL
            """
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        for (i, key) in keys.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
        }
        var result: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let k = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                result[k] = d
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
    /// dates for the entire indexed corpus. At ~83,000 rows maximum the
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

    // MARK: - Parsing (nonisolated — runs off the actor's executor for concurrency)

    nonisolated private func parseAndExtract(volumeId: String, url: URL) async throws -> VolumeIndexData {
        let parser = FRUSDocumentParser()
        // Single-pass parse: documents, persons, and terms extracted in one XML read.
        // Replaces three sequential XMLParser(contentsOf:) calls (passes 1-3) that
        // previously each read the entire volume file from disk.
        let fullResult = try await parser.parseVolumeFull(volumeURL: url)
        let astDocs = fullResult.documents

        var fts5Docs: [FTS5Document] = []
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
            let docNumber  = Self.extractDocumentNumber(from: astDoc.nodes)

            let isEditorialNote: Bool = {
                guard let first = astDoc.nodes.first, case .editorialNote = first else { return false }
                return true
            }()

            let subjectTags   = await subjectTagStore.tags(forDocumentId: did)
            let subjectTagStr = subjectTags.isEmpty ? nil : subjectTags.map(\.subjectId).joined(separator: " ")

            fts5Docs.append(FTS5Document(
                id: did, volumeId: volumeId, documentNumber: docNumber,
                header: header, dateline: dateline, sourceNote: sourceNote,
                bodyText: bodyText, subjectTagIds: subjectTagStr,
                userTagIds: nil, summaryText: nil, noteText: nil,
                isEditorialNote: isEditorialNote
            ))

            crossRefs.append(contentsOf: Self.extractCrossReferences(
                from: astDoc.nodes, sourceVolumeId: volumeId, sourceDocumentId: did))
            pageRangeRows.append(contentsOf: Self.extractPageRanges(
                from: astDoc.nodes, volumeId: volumeId, documentId: did))
            let (dateMin, dateMax) = Self.extractDateRange(
                from: astDoc.nodes,
                dateTimeMin: astDoc.dateTimeMin,
                dateTimeMax: astDoc.dateTimeMax
            )
            dateRows.append(DocumentDateRow(
                volumeId: volumeId, documentId: did,
                dateISOMin: dateMin, dateISOMax: dateMax
            ))
            cacheRows.append(DocumentCacheRow(
                volumeId: volumeId, documentId: did, documentNumber: docNumber,
                header: header, dateline: dateline, sourceNote: sourceNote,
                bodyText: bodyText, subjectTagIds: subjectTagStr,
                userTagIds: nil, summaryText: nil, noteText: nil,
                isEditorialNote: isEditorialNote
            ))

            let personRefs = Self.extractPersonRefs(from: astDoc.nodes)
            for ref in personRefs {
                personMentionRows.append(PersonMentionRow(
                    volumeId: volumeId, documentId: did, personRef: ref
                ))
            }
        }

        // Persons and terms were extracted in the same single-pass parse above.
        let personRows = fullResult.persons.map { p in
            PersonRow(volumeId: volumeId, ref: p.ref, name: p.name, description: p.description)
        }
        let termRows = fullResult.terms.map { t in
            TermRow(volumeId: volumeId, ref: t.ref, term: t.term, definition: t.definition)
        }

        return VolumeIndexData(
            volumeId: volumeId, documents: fts5Docs, crossReferences: crossRefs,
            pageRanges: pageRangeRows, documentDates: dateRows, documentCache: cacheRows,
            personMentions: personMentionRows,
            persons: personRows,
            terms: termRows
        )
    }

    // MARK: - Storage

    private func storeIndexData(_ data: VolumeIndexData) async throws {
        guard !data.documents.isEmpty else { return }

        // --- FTS5 + document_cache insertion, co-batched for iOS memory throttle ---
        //
        // Both arrays are written in the same chunk so that each batch's allocations
        // can be freed by ARC before the next batch begins. On iOS, batchSize == 50
        // (or 20 under memory pressure); on macOS it is effectively unlimited.
        // Clamp to totalDocs so ceiling-division and chunk-end arithmetic are
        // overflow-safe even when effectiveBatchSize == Int.max (the macOS sentinel
        // meaning "process everything in one pass").
        let totalDocs = data.documents.count
        let batchSize = min(effectiveBatchSize, max(totalDocs, 1))
        let totalBatches = (totalDocs + batchSize - 1) / batchSize
        var processed = 0
        var batchNumber = 0

        // Delete any existing FTS5 rows for this volume before inserting the fresh batch.
        // Without this, re-indexing accumulates duplicate rows because document IDs like
        // "d1" are not globally unique — only (document_id, volume_id) is unique.
        try await fts5Store.deleteVolume(volumeId: data.volumeId)

        for chunkStart in stride(from: 0, to: totalDocs, by: batchSize) {
            batchNumber += 1
            let chunkEnd = min(chunkStart + batchSize, totalDocs)
            let fts5Chunk  = Array(data.documents[chunkStart..<chunkEnd])
            let cacheChunk = Array(data.documentCache[chunkStart..<chunkEnd])

            emitUpdate(IndexingProgressUpdate(
                volumeId: data.volumeId,
                stage: .storingBatch(current: batchNumber, total: totalBatches),
                completedDocuments: processed,
                totalDocuments: totalDocs,
                docsPerSecond: currentDocsPerSecond(forTotal: max(processed, 1))
            ))

            try await fts5Store.insertBatch(fts5Chunk)
            try auxInsertDocumentCache(cacheChunk)

            processed += fts5Chunk.count
            volumeDocumentsProcessed = processed
            // Yield between batches so the OS can reclaim per-batch allocations.
            await Task.yield()
        }

        // --- Remaining auxiliary tables ---
        //
        // `cross_references`, `person_mentions`, and `page_ranges` all use plain INSERT
        // (no UNIQUE constraint or ON CONFLICT clause). Without pre-deletion, re-indexing
        // a volume accumulates duplicate rows — doubling page-range rows on every re-index
        // corrupts citation lookup silently. Delete existing rows before inserting.
        // `document_dates` uses INSERT OR REPLACE (safe), but is also pre-deleted so
        // that stale rows for documents removed from the XML are cleaned up.
        try auxDeleteCrossReferences(forVolumeId: data.volumeId)
        try auxDeletePersonMentions(forVolumeId: data.volumeId)
        try auxDeletePageRanges(forVolumeId: data.volumeId)

        try auxInsertCrossReferences(data.crossReferences)
        try auxInsertPageRanges(data.pageRanges)
        try auxInsertDocumentDates(data.documentDates)
        try auxInsertPersonMentions(data.personMentions)
        try auxInsertPersons(data.persons)
        try auxInsertTerms(data.terms)
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
            totalDocuments: data.documents.count,
            editorialNoteCount: data.documents.filter { $0.isEditorialNote }.count,
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

    nonisolated static func extractHeader(from nodes: [FRUSASTNode]) -> String {
        for node in nodes {
            if case .head(let c) = node { return c.map(\.plainText).joined(separator: " ").normalizedWhitespace }
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

    nonisolated static func extractSourceNote(from nodes: [FRUSASTNode]) -> String? {
        for node in nodes {
            if case .footnote(_, let type, _, let c) = node, type == .source {
                let t = c.map(\.plainText).joined(separator: " ").normalizedWhitespace
                return t.isEmpty ? nil : t
            }
        }
        return nil
    }

    nonisolated static func extractBodyText(from nodes: [FRUSASTNode]) -> String {
        nodes.map(\.plainText).joined(separator: " ").normalizedWhitespace
    }

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

    /// Recursively collects all `ref` attribute values from `.persName` nodes.
    ///
    /// Returns a `Set<String>` so each `person_ref` appears at most once per document,
    /// regardless of how many times the name is mentioned. This matches the
    /// `person_mentions` table design: one row per unique person per document.
    ///
    /// Only `.persName` nodes whose `ref` is non-nil and non-empty are included.
    nonisolated static func extractPersonRefs(from nodes: [FRUSASTNode]) -> Set<String> {
        var result = Set<String>()
        for node in nodes {
            if case .persName(let ref, let children) = node {
                if let ref, !ref.isEmpty { result.insert(ref) }
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

    /// Returns the last calendar day of `month` in `year` (Gregorian).
    nonisolated private static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year  = year
        comps.month = month + 1
        comps.day   = 0  // Day 0 of the following month = last day of this month.
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return 30 }
        return cal.component(.day, from: date)
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
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        try exec("""
            CREATE TABLE IF NOT EXISTS cross_references (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_volume_id TEXT NOT NULL,
                source_document_id TEXT NOT NULL,
                target_volume_id TEXT,
                target_document_id TEXT NOT NULL
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_crossref_source ON cross_references(source_volume_id, source_document_id)")
        try exec("CREATE INDEX IF NOT EXISTS idx_crossref_target ON cross_references(target_document_id)")
        // Migrate existing databases that predate Session 17. ALTER TABLE ignores
        // "duplicate column" errors so re-running on an up-to-date DB is safe.
        try? exec("ALTER TABLE cross_references ADD COLUMN reference_type TEXT")
        try? exec("ALTER TABLE cross_references ADD COLUMN context TEXT")
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
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        // Idempotent migration for databases that predate Session 76.
        try? exec("ALTER TABLE document_dates ADD COLUMN date_iso_max TEXT")
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
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        // Idempotent migration for databases that predate Session 38.
        try? exec("ALTER TABLE document_cache ADD COLUMN is_editorial_note INTEGER NOT NULL DEFAULT 0")
        try exec("""
            CREATE TABLE IF NOT EXISTS person_mentions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                person_ref TEXT NOT NULL
            )
            """)
        try exec("CREATE INDEX IF NOT EXISTS idx_person_mentions_ref ON person_mentions(person_ref)")
        try exec("CREATE INDEX IF NOT EXISTS idx_person_mentions_doc ON person_mentions(volume_id, document_id)")
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
    }

    // MARK: - Auxiliary Table DML

    private func auxInsertCrossReferences(_ rows: [CrossReferenceRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT INTO cross_references
            (source_volume_id, source_document_id, target_volume_id, target_document_id,
             reference_type, context)
            VALUES (?, ?, ?, ?, ?, ?)
            """
        try inTransaction {
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

    private func auxInsertPageRanges(_ rows: [PageRangeRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = "INSERT INTO page_ranges (volume_id, document_id, section_id, page_number_type, page_number_int, page_number_raw) VALUES (?, ?, ?, ?, ?, ?)"
        try inTransaction {
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

    private func auxInsertDocumentDates(_ rows: [DocumentDateRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO document_dates
            (volume_id, document_id, date_iso, date_iso_max)
            VALUES (?, ?, ?, ?)
            """
        try inTransaction {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,   -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.documentId, -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 3, row.dateISOMin)
                auxBindOptional(stmt, 4, row.dateISOMax)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private func auxInsertDocumentCache(_ rows: [DocumentCacheRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO document_cache
            (volume_id, document_id, document_number, header, dateline, source_note, body_text,
             subject_tag_ids, user_tag_ids, summary_text, note_text, is_editorial_note)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try inTransaction {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
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
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }
    }

    private func auxInsertPersonMentions(_ rows: [PersonMentionRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = "INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES (?, ?, ?)"
        try inTransaction {
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

    private func auxInsertPersons(_ rows: [PersonRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO persons (volume_id, ref, name, description)
            VALUES (?, ?, ?, ?)
            """
        try inTransaction {
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for row in rows {
                sqlite3_bind_text(stmt, 1, row.volumeId,    -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 2, row.ref,         -1, SQLITE_TRANSIENT_IP)
                sqlite3_bind_text(stmt, 3, row.name,        -1, SQLITE_TRANSIENT_IP)
                auxBindOptional(stmt, 4, row.description)
                try auxStep(stmt)
                sqlite3_reset(stmt)
            }
        }

        logger.debug("Inserted \(rows.count, privacy: .public) persons for \(rows.first?.volumeId ?? "?", privacy: .public)")
    }

    private func auxInsertTerms(_ rows: [TermRow]) throws {
        guard !rows.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO terms (volume_id, ref, term, definition)
            VALUES (?, ?, ?, ?)
            """
        try inTransaction {
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

    private func auxDeleteVolume(_ volumeId: String) throws {
        for (table, col) in [
            ("cross_references", "source_volume_id"),
            ("page_ranges", "volume_id"),
            ("document_dates", "volume_id"),
            ("document_cache", "volume_id"),
            ("person_mentions", "volume_id"),
            ("persons", "volume_id"),
            ("terms",   "volume_id"),
        ] {
            let stmt = try auxPrepare("DELETE FROM \(table) WHERE \(col) = ?")
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
            try auxStep(stmt)
        }
    }

    private func fetchDocumentIds(forVolume volumeId: String) throws -> [String] {
        let stmt = try auxPrepare("SELECT document_id FROM document_cache WHERE volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_IP)
        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let id = auxColumnString(stmt, 0) { ids.append(id) }
        }
        return ids
    }

    /// Returns the indexed body text for a single document, or `nil` if not yet indexed.
    public func fetchDocumentBodyText(volumeId: String, documentId: String) throws -> String? {
        try fetchCache(volumeId: volumeId, documentId: documentId)?.bodyText
    }

    /// Returns the structured `date_iso` value for each of the given document keys.
    ///
    /// Sources `document_dates.date_iso` — the canonical ISO 8601 date string
    /// (typically `yyyy-MM-dd`, occasionally just `yyyy` for partial-precision
    /// dates). Used by `SearchService` to attach a sortable date to each
    /// `SearchResult` so the macOS search window's date-asc / date-desc sort
    /// orders results chronologically instead of by the free-text dateline.
    ///
    /// One batched SQL statement with an `IN (...)` clause is used; the call
    /// chunks at 400 keys to stay within SQLite's 999-host-parameter cap.
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
        let chunkSize = 400
        for chunk in stride(from: 0, to: keys.count, by: chunkSize)
                .map({ Array(keys[$0..<min($0 + chunkSize, keys.count)]) }) {
            let composite = chunk.map { "\($0.volumeId)/\($0.documentId)" }
            let placeholders = composite.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT volume_id || '/' || document_id, date_iso
                FROM document_dates
                WHERE volume_id || '/' || document_id IN (\(placeholders))
                AND date_iso IS NOT NULL
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, key) in composite.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let k = auxColumnString(stmt, 0), let d = auxColumnString(stmt, 1) {
                    out[k] = d
                }
            }
        }
        return out
    }

    /// Returns the unstemmed `body_text` for each of the given document keys.
    ///
    /// The values come from `document_cache.body_text`, which stores the original
    /// AST-derived plain text **before** Porter stemming was applied for FTS5. This
    /// is the correct source for user-facing search snippets: it preserves the actual
    /// spelling of every word in the document, whereas the FTS5 `frus_documents.body_text`
    /// column contains stemmed tokens (`negoti` instead of `negotiating`) and would
    /// mislead the reader if surfaced directly.
    ///
    /// One SQL statement with an `IN (?, ?, …)` clause is used, so the call cost
    /// scales as a single SQLite round-trip regardless of result count. SQLite's
    /// default variable cap of 999 is respected by chunking; callers requesting
    /// thousands of documents will incur a small number of sequential queries.
    ///
    /// - Parameter keys: `(volumeId, documentId)` pairs to look up.
    /// - Returns: Dictionary mapping `"volumeId/documentId"` → body text.
    ///   Documents not present in `document_cache` are absent from the result.
    public func documentBodyTexts(
        for keys: [(volumeId: String, documentId: String)]
    ) throws -> [String: String] {
        guard !keys.isEmpty else { return [:] }
        var out: [String: String] = [:]
        // Chunk to stay inside SQLite's default 999 host-parameter cap.
        let chunkSize = 400
        for chunk in stride(from: 0, to: keys.count, by: chunkSize)
                .map({ Array(keys[$0..<min($0 + chunkSize, keys.count)]) }) {
            let composite = chunk.map { "\($0.volumeId)/\($0.documentId)" }
            let placeholders = composite.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT volume_id || '/' || document_id, body_text
                FROM document_cache
                WHERE volume_id || '/' || document_id IN (\(placeholders))
                """
            let stmt = try auxPrepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, key) in composite.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), key, -1, SQLITE_TRANSIENT_IP)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let k = auxColumnString(stmt, 0), let b = auxColumnString(stmt, 1) {
                    out[k] = b
                }
            }
        }
        return out
    }

    private func fetchCache(volumeId: String, documentId: String) throws -> DocumentCacheRow? {
        let sql = """
            SELECT document_number, header, dateline, source_note, body_text,
                   subject_tag_ids, user_tag_ids, summary_text, note_text, is_editorial_note
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
            isEditorialNote: sqlite3_column_int(stmt, 9) != 0
        )
    }

    private func updateCacheFields(volumeId: String, documentId: String, summaryText: String?, noteText: String?) throws {
        let sql = "UPDATE document_cache SET summary_text = ?, note_text = ? WHERE volume_id = ? AND document_id = ?"
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        auxBindOptional(stmt, 1, summaryText)
        auxBindOptional(stmt, 2, noteText)
        sqlite3_bind_text(stmt, 3, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 4, documentId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
    }

    private func updateCacheNoteFields(volumeId: String, documentId: String, userTagIds: String?, noteText: String?) throws {
        let sql = "UPDATE document_cache SET user_tag_ids = ?, note_text = ? WHERE volume_id = ? AND document_id = ?"
        let stmt = try auxPrepare(sql)
        defer { sqlite3_finalize(stmt) }
        auxBindOptional(stmt, 1, userTagIds)
        auxBindOptional(stmt, 2, noteText)
        sqlite3_bind_text(stmt, 3, volumeId, -1, SQLITE_TRANSIENT_IP)
        sqlite3_bind_text(stmt, 4, documentId, -1, SQLITE_TRANSIENT_IP)
        try auxStep(stmt)
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

    private func auxColumnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - Private Data Structures

private struct VolumeIndexData: Sendable {
    let volumeId: String
    let documents: [FTS5Document]
    let crossReferences: [CrossReferenceRow]
    let pageRanges: [PageRangeRow]
    let documentDates: [DocumentDateRow]
    let documentCache: [DocumentCacheRow]
    let personMentions: [PersonMentionRow]
    let persons: [PersonRow]
    let terms: [TermRow]
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

private struct DocumentDateRow: Sendable {
    let volumeId: String
    let documentId: String
    /// Earliest bound of the document date range, normalized to `yyyy-MM-dd`.
    /// Stored in the `date_iso` column (name preserved for schema compatibility).
    let dateISOMin: String?
    /// Latest bound of the document date range, normalized to `yyyy-MM-dd`.
    /// Stored in the `date_iso_max` column added in version 5.
    let dateISOMax: String?
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

    func toFTS5Document(summaryText: String?, noteText: String?) -> FTS5Document {
        FTS5Document(
            id: documentId, volumeId: volumeId, documentNumber: documentNumber,
            header: header, dateline: dateline, sourceNote: sourceNote,
            bodyText: bodyText, subjectTagIds: subjectTagIds, userTagIds: userTagIds,
            summaryText: summaryText, noteText: noteText,
            isEditorialNote: isEditorialNote
        )
    }

    /// Overload that also replaces the stored `userTagIds` value.
    /// Used by `updateNoteText` to sync user-tag assignments from SwiftData into FTS5.
    func toFTS5Document(summaryText: String?, noteText: String?, updatedUserTagIds: String?) -> FTS5Document {
        FTS5Document(
            id: documentId, volumeId: volumeId, documentNumber: documentNumber,
            header: header, dateline: dateline, sourceNote: sourceNote,
            bodyText: bodyText, subjectTagIds: subjectTagIds, userTagIds: updatedUserTagIds,
            summaryText: summaryText, noteText: noteText,
            isEditorialNote: isEditorialNote
        )
    }
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
