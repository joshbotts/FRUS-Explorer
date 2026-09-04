// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import UserNotifications

// MARK: - SummarizationScope

/// Defines the set of documents to process in a background summarization run.
///
/// `Codable` so a run can be persisted (`BackgroundSummarizationRequest`) and
/// resumed by the iOS `BGProcessingTask` after the app is suspended.
public enum SummarizationScope: Sendable, Equatable, Codable {
    /// All documents in one specific volume.
    case volume(volumeId: String)
    /// All documents in all volumes that share the given subseries identifier.
    case subseries(subseries: String)
    /// All documents that have the given user tag applied.
    /// `documentKeys` is a pre-computed set of `"volumeId/documentId"` strings
    /// built by the settings view from `DocumentTagAssignment` records.
    case userTag(documentKeys: Set<String>)
    /// All documents returned by a saved search query.
    /// `documentKeys` is a pre-computed set of `"volumeId/documentId"` strings
    /// built by the settings view by executing the saved search before starting.
    case savedSearch(documentKeys: Set<String>)
    /// All documents whose volume date range overlaps [earliest, latest] (ISO 8601 strings).
    case dateRange(earliest: String, latest: String)
    /// All documents in the downloaded member volumes of a saved custom volume scope.
    /// `volumeIds` is a pre-resolved snapshot of the scope's downloaded members, built by
    /// the settings view at start time — mirroring how `userTag`/`savedSearch` pre-compute
    /// `documentKeys`, so a persisted run survives relaunch (no `ModelContext` at
    /// `BGProcessingTask` wake) and is unaffected by later edits or deletion of the scope.
    /// The gate is *downloaded* (not indexed) because summarization parses each volume's TEI
    /// directly and never reads the FTS index. Volume-grain: every document in each member
    /// volume is summarized (it takes the same path as `.volume`/`.subseries`).
    case customScope(volumeIds: Set<String>)
}

// MARK: - BatchRunTally

/// What a bulk-summarization run has actually done, as four separate numbers (#560).
///
/// This replaces a single `processed` count that meant three different things at once. The run it
/// was reported against — 1,378 documents over 5 hours — could have failed every document and
/// rendered as a green "1400 of 1400 documents summarized", because the counter was incremented
/// outside the `do/catch`.
///
/// The four numbers, and the invariants that make them worth trusting:
///  - ``succeeded`` counts documents for which `summarizeDiscarding` returned without throwing —
///    the same condition under which `SummarizationService` saved a `GeneratedSummary` row. It is a
///    count of summaries that now exist.
///  - ``failed`` counts documents that threw after their retry budget.
///  - ``skipped`` counts documents that already had a summary for this prompt and were never sent
///    to the model. They are excluded from ``attemptable``, so they cannot hold the bar below 100%.
///  - ``attemptable`` is the post-skip job count and is the **only** value ever used as a progress
///    denominator.
///
/// At any terminal state `succeeded + failed == attemptable`, unless the run was cancelled.
///
/// Version history:
///   1.0 — #560: initial implementation
public struct BatchRunTally: Sendable, Equatable {
    /// Documents whose summary was written.
    public var succeeded: Int
    /// Documents that threw after their retry budget.
    public var failed: Int
    /// Documents that already had a summary for this prompt and were never attempted.
    public var skipped: Int
    /// Documents this run will send to the model — the progress denominator.
    public var attemptable: Int

    /// Nothing attempted.
    public static let zero = BatchRunTally(succeeded: 0, failed: 0, skipped: 0, attemptable: 0)

    /// Creates a tally.
    public init(succeeded: Int = 0, failed: Int = 0, skipped: Int = 0, attemptable: Int = 0) {
        self.succeeded = succeeded
        self.failed = failed
        self.skipped = skipped
        self.attemptable = attemptable
    }

    /// Documents resolved either way — the progress numerator.
    public var finished: Int { succeeded + failed }

    /// Whether the run had nothing to do because every document was already summarized.
    public var isEntirelySkipped: Bool { attemptable == 0 && skipped > 0 }
}

// MARK: - BackgroundSummarizationState

/// The current state of the `BackgroundSummarizationService`.
public enum BackgroundSummarizationState: Sendable, Equatable {
    case idle
    /// A run in progress. `currentDocumentId` is the document most recently started, and stays set
    /// for as long as that document is working — a long document is the case where the user most
    /// needs to see something, and the previous implementation published `nil` after every
    /// completion, so the display went blank exactly when a run looked frozen.
    ///
    /// `step` is where that document has got to internally. It is the only thing that moves while a
    /// 131-chunk document is being summarized, so it is what distinguishes a slow run from a
    /// hung one.
    case running(tally: BatchRunTally, currentDocumentId: String?, step: SummarizationStep?)
    case completed(tally: BatchRunTally)
    case cancelled(tally: BatchRunTally)
    case failed(errorDescription: String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

// MARK: - BackgroundSummarizationProgress

/// Observable progress model for `BackgroundSummarizationService`.
///
/// The service updates this on the main actor; views observe it directly.
///
/// Version history:
///   1.0 — Session 21: initial implementation
@Observable
@MainActor
public final class BackgroundSummarizationProgress {
    public var state: BackgroundSummarizationState = .idle
}

// MARK: - BackgroundSummarizationService

/// Actor that processes documents concurrently against a user-defined scope.
///
/// ## Usage
/// ```swift
/// let snapshot = SummarizationPromptSnapshot(from: selectedPrompt)
/// await service.start(
///     scope: .volume(volumeId: "frus1969-76v01"),
///     promptSnapshot: snapshot,
///     provider: AppleIntelligenceProvider.shared,
///     concurrencyLimit: 3,
///     downloadedVolumeURLs: [volumeId: localURL],
///     manifestEntries: appState.manifestStore.allEntries,
///     activeProjectId: appState.activeProjectId
/// )
/// ```
///
/// ## Skip Logic
/// Documents that already have a `GeneratedSummary` for this prompt are resolved **during
/// enumeration**, in one fetch, before the job list is built (#560) — so they never materialise
/// their text and never enter the progress denominator. A re-run over an already-summarized scope
/// therefore reports "nothing to summarize" rather than sitting at 0 of 1,400.
///
/// ## Retry
/// Transient errors are retried with exponential backoff (base 2 s, max 5 attempts). Errors known
/// to be deterministic throw immediately — see `SummarizationRetryPolicy`. The concurrency permit
/// is held for the whole sequence, which is why the distinction matters.
///
/// ## What the numbers mean
/// `BatchRunTally` separates succeeded / failed / skipped / attemptable. `succeeded` counts
/// summaries that exist on disk, not documents attempted.
///
/// ## Completion Notification
/// On completion a `UNUserNotification` is delivered (if the app has notification
/// permission). The caller is responsible for requesting permission before starting.
///
/// ## Log prefix
/// `[BackgroundSummarizer]`
///
/// ## Backoff strategy
/// Attempt 1 — immediate
/// Attempt 2 — 2 s delay
/// Attempt 3 — 4 s delay
/// Attempt 4 — 8 s delay
/// Attempt 5 — 16 s delay
/// After 5 failures the document is recorded as failed; processing continues with the next.
/// A terminal error skips the schedule entirely.
///
/// Version history:
///   1.0 — Session 21: initial implementation
///   1.1 — Session 32: `start` takes `promptSnapshot: SummarizationPromptSnapshot` instead of
///          a live `SummarizationPrompt` model, eliminating a cross-actor SwiftData reference
public actor BackgroundSummarizationService {

    // MARK: - Public progress model (nonisolated — observed by views on @MainActor)

    public nonisolated let progress: BackgroundSummarizationProgress

    // MARK: - Private state

    private var currentTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let summarizationService: SummarizationService
    private let modelContainer: ModelContainer
    private let parser: FRUSDocumentParser

    // MARK: - Init

    init(
        summarizationService: SummarizationService,
        modelContainer: ModelContainer,
        progress: BackgroundSummarizationProgress
    ) {
        self.summarizationService = summarizationService
        self.modelContainer = modelContainer
        self.parser = FRUSDocumentParser()
        self.progress = progress
    }

    // MARK: - Public API

    /// Starts a background summarization run. Cancels any run already in progress.
    func start(
        scope: SummarizationScope,
        promptSnapshot: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        concurrencyLimit: Int,
        downloadedVolumeURLs: [String: URL],
        manifestEntries: [VolumeManifestEntry],
        activeProjectId: UUID?
    ) async {
        // Cancel any existing run
        currentTask?.cancel()

        let snapshot = promptSnapshot
        let promptId = promptSnapshot.id

        let task = Task {
            await self.run(
                scope: scope,
                snapshot: snapshot,
                promptId: promptId,
                provider: provider,
                concurrencyLimit: max(1, concurrencyLimit),
                downloadedVolumeURLs: downloadedVolumeURLs,
                manifestEntries: manifestEntries,
                activeProjectId: activeProjectId
            )
        }
        currentTask = task
    }

    /// Cancels the current run, if any. Progress state transitions to `.cancelled`.
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        let p = progress
        Task { @MainActor in
            p.state = .cancelled(tally: .zero)
        }
    }

    // MARK: - Internal (visible for tests)

    /// Returns the volumeIds in scope, filtered to those present in `downloadedVolumeIds`.
    func resolvedVolumeIds(
        for scope: SummarizationScope,
        in manifestEntries: [VolumeManifestEntry],
        downloadedVolumeIds: Set<String>
    ) -> [String] {
        let candidates: [String]
        switch scope {
        case .volume(let vid):
            candidates = [vid]
        case .subseries(let sub):
            candidates = manifestEntries
                .filter { $0.subseries == sub }
                .map(\.volumeId)
        case let .userTag(keys), let .savedSearch(keys):
            // Only the volumes referenced by the matched documents. Returning every
            // downloaded volume meant `run()` parsed the entire downloaded corpus
            // just to filter by `keys`, so a tag/saved-search run appeared to stall
            // at 0/0 (and never finished). The keys already name their volumes.
            candidates = Array(Set(keys.compactMap {
                $0.split(separator: "/", maxSplits: 1).first.map(String.init)
            }))
        case .dateRange(let earliest, let latest):
            candidates = manifestEntries
                .filter { overlaps(range: $0.dateRange, earliest: earliest, latest: latest) }
                .map(\.volumeId)
        case .customScope(let volumeIds):
            // Pre-resolved indexed member ids (snapshot). Volume-grain like `.volume` /
            // `.subseries`, so the per-document key switches in `run` / `processBackgroundBatch`
            // intentionally let it fall through their `default:` (no per-doc filter).
            candidates = Array(volumeIds)
        }
        return candidates.filter { downloadedVolumeIds.contains($0) }
    }

    /// Returns `true` if a `GeneratedSummary` already exists for the given document + prompt.
    func shouldSkip(volumeId: String, documentId: String, promptId: UUID, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { s in
                s.volumeId == volumeId && s.documentId == documentId && s.promptId == promptId
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    // MARK: - Background batch (BGProcessingTask)

    /// Processes up to `maxDocuments` not-yet-summarized documents in `scope`, one
    /// at a time with light pacing, honoring cancellation (the background-task
    /// budget).
    ///
    /// Conservative by design: serial (concurrency 1) to limit thermal load, a
    /// short retry budget, an inter-document delay, and a hard per-wake cap. Does
    /// **not** touch the foreground `progress` model. Posts a completion
    /// notification only when the entire scope is finished.
    ///
    /// - Returns: the number summarized this wake, and whether the scope is now
    ///   completely summarized (so the caller can clear the persisted request).
    func processBackgroundBatch(
        scope: SummarizationScope,
        snapshot: SummarizationPromptSnapshot,
        promptId: UUID,
        provider: any SummarizationProvider,
        downloadedVolumeURLs: [String: URL],
        manifestEntries: [VolumeManifestEntry],
        activeProjectId: UUID?,
        maxDocuments: Int,
        perDocumentDelay: Duration = .seconds(1)
    ) async -> (processed: Int, scopeComplete: Bool) {
        guard maxDocuments > 0, !Task.isCancelled, await provider.isAvailable else {
            return (0, false)
        }
        let context = ModelContext(modelContainer)
        let downloadedIds = Set(downloadedVolumeURLs.keys)
        let volumeIds = resolvedVolumeIds(for: scope, in: manifestEntries, downloadedVolumeIds: downloadedIds)

        // Lazily enumerate undone documents, stopping once we exceed the batch cap —
        // the overflow tells us work remains without parsing the whole scope.
        var batch: [(volumeId: String, documentId: String, text: String)] = []
        var moreRemain = false
        enumerate: for volumeId in volumeIds {
            if Task.isCancelled { break }
            guard let url = downloadedVolumeURLs[volumeId] else { continue }
            let docs = (try? await parser.parse(volumeURL: url)) ?? []
            for doc in docs {
                if Task.isCancelled { break enumerate }
                switch scope {
                case .userTag(let keys), .savedSearch(let keys):
                    guard keys.contains("\(volumeId)/\(doc.documentId)") else { continue }
                default:
                    break
                }
                if shouldSkip(volumeId: volumeId, documentId: doc.documentId,
                              promptId: promptId, context: context) { continue }
                let text = SummarizationService.documentText(from: doc.nodes)
                guard !text.isEmpty else { continue }
                if batch.count < maxDocuments {
                    batch.append((volumeId, doc.documentId, text))
                } else {
                    moreRemain = true
                    break enumerate
                }
            }
        }

        // Summarize serially with light pacing between documents.
        var processed = 0
        for (index, job) in batch.enumerated() {
            if Task.isCancelled { break }
            #if DEBUG && os(iOS)
            // Instrument the real background run so an unplugged soak self-records
            // throughput/latency/memory to the Summarization Probe log.
            let footprintBefore = SummarizationBackgroundProbe.footprintMB()
            let startedAt = Date()
            #endif
            var succeeded = false
            var failure: String?
            do {
                try await withRetry(maxAttempts: 2) {
                    try await self.summarizationService.summarizeDiscarding(
                        documentId: job.documentId, volumeId: job.volumeId,
                        documentText: job.text, prompt: snapshot,
                        provider: provider, activeProjectId: activeProjectId
                    )
                }
                processed += 1
                succeeded = true
            } catch {
                failure = String(describing: error)
                #if DEBUG
                print("[BackgroundSummarizer] BG batch failed \(job.volumeId)/\(job.documentId): \(error)")
                #endif
            }
            #if DEBUG && os(iOS)
            SummarizationBackgroundProbe.recordBackgroundRun(
                documentId: "\(job.volumeId)/\(job.documentId)",
                sequence: index,
                inputChars: job.text.count,
                inferenceMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
                footprintBeforeMB: footprintBefore,
                footprintAfterMB: SummarizationBackgroundProbe.footprintMB(),
                success: succeeded,
                error: failure
            )
            #endif
            if !Task.isCancelled, processed < batch.count {
                try? await Task.sleep(for: perDocumentDelay)
            }
        }

        let scopeComplete = !moreRemain && !Task.isCancelled && processed == batch.count
        if scopeComplete && processed > 0 {
            await deliverCompletionNotification(
                tally: BatchRunTally(succeeded: processed, attemptable: processed))
        }
        return (processed, scopeComplete)
    }

    // MARK: - Private run loop

    private func run(
        scope: SummarizationScope,
        snapshot: SummarizationPromptSnapshot,
        promptId: UUID,
        provider: any SummarizationProvider,
        concurrencyLimit: Int,
        downloadedVolumeURLs: [String: URL],
        manifestEntries: [VolumeManifestEntry],
        activeProjectId: UUID?
    ) async {
        guard !Task.isCancelled else { return }

        let p = progress
        await MainActor.run { p.state = .running(tally: .zero, currentDocumentId: nil, step: nil) }

        #if DEBUG
        print("[BackgroundSummarizer] Run started scope=\(scope)")
        #endif

        let downloadedIds = Set(downloadedVolumeURLs.keys)
        let volumeIds = resolvedVolumeIds(for: scope, in: manifestEntries, downloadedVolumeIds: downloadedIds)

        guard !volumeIds.isEmpty else {
            #if DEBUG
            print("[BackgroundSummarizer] No downloaded volumes in scope — stopping")
            #endif
            await MainActor.run { p.state = .completed(tally: .zero) }
            return
        }

        // Every document already summarized for this prompt, fetched once (#560).
        //
        // This used to be a per-job `fetchCount` inside the dispatch loop, which meant the skip was
        // discovered *after* `total` had been fixed — so a re-run over an already-summarized scope
        // counted toward a denominator it could never reach, and a fully-summarized scope sat at
        // "0 of 1400" for the whole run before reporting "0 documents summarized". Resolving it
        // during enumeration instead means `attemptable` is what the run will really attempt, and
        // a skipped document never materialises its text.
        let skipSet = existingSummaryKeys(promptId: promptId)

        // Build the full job list: parse each volume to enumerate document IDs
        var jobs: [(volumeId: String, documentId: String, text: String)] = []
        var skippedCount = 0
        for volumeId in volumeIds {
            guard !Task.isCancelled else { break }
            guard let url = downloadedVolumeURLs[volumeId] else { continue }
            do {
                let docs = try await parser.parse(volumeURL: url)
                for doc in docs {
                    guard !Task.isCancelled else { break }
                    // For userTag / savedSearch scope, only include documents in the
                    // pre-computed key set
                    switch scope {
                    case .userTag(let keys), .savedSearch(let keys):
                        guard keys.contains("\(volumeId)/\(doc.documentId)") else { continue }
                    default:
                        break
                    }
                    // Skip before the text is materialised, not after the denominator is fixed.
                    guard !skipSet.contains("\(volumeId)/\(doc.documentId)") else {
                        skippedCount += 1
                        continue
                    }
                    let text = SummarizationService.documentText(from: doc.nodes)
                    guard !text.isEmpty else { continue }
                    jobs.append((volumeId: volumeId, documentId: doc.documentId, text: text))
                }
            } catch {
                #if DEBUG
                print("[BackgroundSummarizer] Failed to parse volume \(volumeId): \(error)")
                #endif
            }
        }

        let ledger = RunLedger()
        await ledger.setSkipped(skippedCount)
        await ledger.setAttemptable(jobs.count)

        guard !Task.isCancelled, !jobs.isEmpty else {
            let tally = await ledger.snapshot().tally
            await MainActor.run {
                p.state = Task.isCancelled ? .cancelled(tally: tally) : .completed(tally: tally)
            }
            // A scope in which everything was already summarized is a real outcome, not a no-op —
            // it is also indistinguishable from total failure under the old counting, so it gets
            // its own sentence rather than a silent return.
            if !Task.isCancelled { await deliverCompletionNotification(tally: tally) }
            return
        }

        let total = jobs.count
        let startingTally = await ledger.snapshot().tally
        await MainActor.run { p.state = .running(tally: startingTally, currentDocumentId: nil, step: nil) }

        #if DEBUG
        print("[BackgroundSummarizer] Processing \(total) documents with concurrency=\(concurrencyLimit) (\(skippedCount) already summarized)")
        #endif

        let semaphore = ConcurrencySemaphore(limit: concurrencyLimit)

        // The only site that publishes `.running` (#560).
        //
        // Each task used to publish twice — once before its work with a stale read of the counter,
        // once after — so two racing tasks could interleave their main-actor writes and show a
        // number that went backwards. Polling one consistent snapshot removes the race by
        // construction, and coalescing to 2 Hz turns ~4,200 main-actor hops on a 1,400-document run
        // into ~600 regardless of how fast documents complete.
        let publisher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard self != nil, !Task.isCancelled else { return }
                let (tally, docId, step) = await ledger.snapshot()
                await MainActor.run {
                    p.state = .running(tally: tally, currentDocumentId: docId, step: step)
                }
            }
        }

        var modelBecameUnavailable = false

        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                guard !Task.isCancelled else { break }

                // Apple Intelligence can be switched off mid-run. Without this the remaining
                // documents each fail, and — before the retry policy — each burned 30 s of backoff
                // holding a permit while the progress bar advanced toward a green checkmark.
                guard await provider.isAvailable else {
                    modelBecameUnavailable = true
                    break
                }

                await semaphore.wait()

                let vid = job.volumeId
                let did = job.documentId
                let text = job.text

                group.addTask { [weak self] in
                    defer { Task { await semaphore.signal() } }
                    guard !Task.isCancelled, let self else { return }

                    await ledger.begin(did)

                    do {
                        try await self.withRetry(maxAttempts: 5) {
                            try await self.summarizationService.summarizeDiscarding(
                                documentId: did,
                                volumeId: vid,
                                documentText: text,
                                prompt: snapshot,
                                provider: provider,
                                activeProjectId: activeProjectId,
                                // Fires once per model call — 131 times for the corpus's longest
                                // document. It only writes to the ledger; the 2 Hz publisher owns
                                // every UI update, so the rate here cannot reach the main actor.
                                onStep: { step in
                                    Task { await ledger.note(step, for: did) }
                                }
                            )
                        }
                        // Inside the `do`: a document counts as succeeded only when
                        // `summarizeDiscarding` returned, which is the same condition under which
                        // a `GeneratedSummary` row was written.
                        await ledger.recordSuccess()
                        #if DEBUG
                        print("[BackgroundSummarizer] Summarized \(vid)/\(did)")
                        #endif
                    } catch {
                        await ledger.recordFailure(
                            volumeId: vid, documentId: did,
                            reason: SummarizationRetryPolicy.describe(error))
                        #if DEBUG
                        print("[BackgroundSummarizer] Failed after retries \(vid)/\(did): \(error)")
                        #endif
                    }
                }
            }
        }

        publisher.cancel()
        let (tally, _, _) = await ledger.snapshot()

        guard !Task.isCancelled else {
            await MainActor.run { p.state = .cancelled(tally: tally) }
            return
        }

        if modelBecameUnavailable {
            let message = String(
                localized: "bg.summarizer.failed.unavailable",
                defaultValue: "Apple Intelligence became unavailable. Stopped after \(tally.succeeded) of \(tally.attemptable) documents."
            )
            await MainActor.run { p.state = .failed(errorDescription: message) }
            #if DEBUG
            print("[BackgroundSummarizer] Stopped — provider unavailable after \(tally.succeeded)/\(tally.attemptable)")
            #endif
            return
        }

        // A run where nothing succeeded and something failed is a failure, whatever the bar said.
        if tally.succeeded == 0, tally.failed > 0 {
            let message = String(
                localized: "bg.summarizer.failed.allFailed",
                defaultValue: "No summaries were produced. All \(tally.failed) documents failed."
            )
            await MainActor.run { p.state = .failed(errorDescription: message) }
            #if DEBUG
            let reasons = await ledger.failures.map(\.reason)
            print("[BackgroundSummarizer] All \(tally.failed) documents failed. Reasons: \(Set(reasons).sorted())")
            #endif
            return
        }

        await MainActor.run { p.state = .completed(tally: tally) }

        #if DEBUG
        print("[BackgroundSummarizer] Completed. \(tally.succeeded) summarized, \(tally.failed) failed, \(tally.skipped) already had one.")
        #endif

        await deliverCompletionNotification(tally: tally)
    }

    /// Every `"volumeId/documentId"` that already has a summary for `promptId`.
    ///
    /// One fetch instead of one predicated `fetchCount` per document. On a 1,400-document run that
    /// replaced 1,400 queries — but the reason it moved is correctness, not speed: the skip has to
    /// be known during enumeration for the progress denominator to mean anything.
    private func existingSummaryKeys(promptId: UUID) -> Set<String> {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.promptId == promptId }
        )
        guard let existing = try? context.fetch(descriptor) else { return [] }
        return Set(existing.map { "\($0.volumeId)/\($0.documentId)" })
    }

    // MARK: - Retry

    /// Retries `operation` with exponential backoff on errors that could plausibly succeed later.
    ///
    /// Transient errors are retried up to 4 more times (5 attempts total); delays 2 s, 4 s, 8 s,
    /// 16 s. `CancellationError` propagates immediately.
    ///
    /// **Terminal errors throw on the first attempt without sleeping** (#560). The caller holds a
    /// concurrency permit for the entire sequence, so a document the model will never accept used
    /// to cost 30 seconds *and* a slot — and in a run where Apple Intelligence had gone away, every
    /// remaining document paid that in turn. `SummarizationRetryPolicy` decides, as a blocklist, so
    /// an unrecognised error keeps the old behaviour.
    ///
    /// Internal (not private) so unit tests can exercise the retry path directly.
    func withRetry<T: Sendable>(
        maxAttempts: Int = 5,
        baseDelayNanoseconds: UInt64 = 2_000_000_000, // 2 seconds in production
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var delayNanoseconds = baseDelayNanoseconds
        var lastError: Error?
        for attempt in 1...maxAttempts {
            guard !Task.isCancelled else { throw CancellationError() }
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                // A deterministic error will not become a different error in two seconds, and the
                // concurrency permit is held for the whole backoff — so retrying one costs a slot
                // as well as the time. Unrecognised errors stay retryable (blocklist, not
                // allowlist), so this cannot quietly stop retrying something transient.
                guard SummarizationRetryPolicy.isRetryable(error) else { throw error }
                if attempt < maxAttempts {
                    if delayNanoseconds > 0 {
                        #if DEBUG
                        print("[BackgroundSummarizer] Attempt \(attempt) failed: \(error). Retrying in \(delayNanoseconds / 1_000_000_000)s…")
                        #endif
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                        delayNanoseconds *= 2
                    }
                }
            }
        }
        throw lastError!
    }

    // MARK: - Date Range Overlap

    private func overlaps(range: DateRange, earliest: String, latest: String) -> Bool {
        // Treat nil bounds as open-ended
        let rangeEnd   = range.latest  ?? "9999-99-99"
        let rangeStart = range.earliest ?? "0000-00-00"
        return rangeStart <= latest && rangeEnd >= earliest
    }

    // MARK: - Notification

    private func deliverCompletionNotification(tally: BatchRunTally) async {
        let content = UNMutableNotificationContent()
        // "Complete" is a claim about the outcome, so it is reserved for runs where nothing failed.
        content.title = tally.failed == 0
            ? String(localized: "background.summarizer.notification.title",
                     defaultValue: "Summarization Complete")
            : String(localized: "background.summarizer.notification.title.partial",
                     defaultValue: "Summarization Finished")
        if tally.isEntirelySkipped {
            content.body = String(
                localized: "background.summarizer.notification.body.allSkipped",
                defaultValue: "Nothing to summarize — every document already had a summary for this prompt."
            )
        } else if tally.failed > 0 {
            content.body = String(
                localized: "background.summarizer.notification.body.partial",
                defaultValue: "\(tally.succeeded) summarized, \(tally.failed) failed."
            )
        } else {
            content.body = String(
                localized: "background.summarizer.notification.body.succeeded",
                defaultValue: "\(tally.succeeded) documents summarized."
            )
        }
        let request = UNNotificationRequest(
            identifier: "com.frusexplorer.summarization.complete.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - ConcurrencySemaphore

/// Actor-based semaphore for bounding concurrency in a `withTaskGroup`.
private actor ConcurrencySemaphore {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.available = limit
    }

    func wait() async {
        if available > 0 {
            available -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

// MARK: - RunLedger

/// The single source of truth for every number a bulk-summarization run shows the user (#560).
///
/// Replaces a bare `value += 1` counter that was incremented on success and failure alike. Every
/// tally the UI renders comes from here, and — importantly — the UI reads it by *snapshot* from one
/// publishing site rather than each task publishing its own view of the world. Two publish sites
/// racing is how the old implementation could show a count that went backwards.
///
/// Failures are kept as well as counted, capped at ``failureCap``, so a run can say which documents
/// did not make it rather than only how many. The list is session-scoped and deliberately not
/// persisted: a `@Model` here would change the CloudKit schema and turn a bug fix into a
/// release-blocking deploy.
///
/// Version history:
///   1.0 — #560: initial implementation, replacing `ProcessedCounter`
private actor RunLedger {

    /// How many individual failures to retain. Beyond this the tally still counts them; only the
    /// per-document detail stops accumulating, so a catastrophic run cannot grow unbounded.
    static let failureCap = 50

    private var tally = BatchRunTally.zero
    private(set) var failures: [(volumeId: String, documentId: String, reason: String)] = []
    private var currentDocumentId: String?
    private var currentStep: SummarizationStep?

    /// Records the post-skip job count — the denominator for everything the user sees.
    func setAttemptable(_ count: Int) { tally.attemptable = count }

    /// Records how many documents already had a summary and will never be attempted.
    func setSkipped(_ count: Int) { tally.skipped = count }

    /// Marks `documentId` as the document now being worked on, clearing any previous step.
    func begin(_ documentId: String) {
        currentDocumentId = documentId
        currentStep = nil
    }

    /// Records how far `documentId` has got. Ignored once another document has taken over, so a
    /// straggling callback from a finished document cannot overwrite the live one's step.
    func note(_ step: SummarizationStep, for documentId: String) {
        guard currentDocumentId == documentId else { return }
        currentStep = step
    }

    /// Records a written summary.
    func recordSuccess() { tally.succeeded += 1 }

    /// Records a document that threw after its retry budget.
    func recordFailure(volumeId: String, documentId: String, reason: String) {
        tally.failed += 1
        if failures.count < Self.failureCap {
            failures.append((volumeId: volumeId, documentId: documentId, reason: reason))
        }
    }

    /// The current tally, the document in flight, and its step, read as one consistent triple.
    func snapshot() -> (tally: BatchRunTally, currentDocumentId: String?, step: SummarizationStep?) {
        (tally, currentDocumentId, currentStep)
    }
}
