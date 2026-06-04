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
public enum SummarizationScope: Sendable, Equatable {
    /// All documents in one specific volume.
    case volume(volumeId: String)
    /// All documents in all volumes that share the given subseries identifier.
    case subseries(subseries: String)
    /// All documents that have the given user tag applied.
    /// `documentKeys` is a pre-computed set of `"volumeId/documentId"` strings
    /// built by the settings view from `DocumentTagAssignment` records.
    case userTag(documentKeys: Set<String>)
    /// All documents whose volume date range overlaps [earliest, latest] (ISO 8601 strings).
    case dateRange(earliest: String, latest: String)
}

// MARK: - BackgroundSummarizationState

/// The current state of the `BackgroundSummarizationService`.
public enum BackgroundSummarizationState: Sendable, Equatable {
    case idle
    case running(processed: Int, total: Int, currentDocumentId: String?)
    case completed(processed: Int)
    case cancelled
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
///     subjectTagStore: appState.subjectTagStore,
///     activeProjectId: appState.activeProjectId
/// )
/// ```
///
/// ## Skip Logic
/// Before summarizing a document, the service checks SwiftData for a `GeneratedSummary`
/// with matching `documentId`, `volumeId`, and `promptId`. Existing summaries are skipped.
///
/// ## Retry
/// Any error from the provider is treated as potentially transient and retried with
/// exponential backoff (base 2 s, max 5 attempts). After 5 consecutive failures the
/// document is skipped and processing continues.
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
/// After 5 failures the document is skipped; processing continues with the next.
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
            p.state = .cancelled
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
        case .userTag:
            // All downloaded volumes — document filtering happens per-document
            // using the pre-computed documentKeys set
            candidates = Array(downloadedVolumeIds)
        case .dateRange(let earliest, let latest):
            candidates = manifestEntries
                .filter { overlaps(range: $0.dateRange, earliest: earliest, latest: latest) }
                .map(\.volumeId)
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
        await MainActor.run { p.state = .running(processed: 0, total: 0, currentDocumentId: nil) }

        #if DEBUG
        print("[BackgroundSummarizer] Run started scope=\(scope)")
        #endif

        let downloadedIds = Set(downloadedVolumeURLs.keys)
        let volumeIds = resolvedVolumeIds(for: scope, in: manifestEntries, downloadedVolumeIds: downloadedIds)

        guard !volumeIds.isEmpty else {
            #if DEBUG
            print("[BackgroundSummarizer] No downloaded volumes in scope — stopping")
            #endif
            await MainActor.run { p.state = .completed(processed: 0) }
            return
        }

        // Build the full job list: parse each volume to enumerate document IDs
        var jobs: [(volumeId: String, documentId: String, text: String)] = []
        for volumeId in volumeIds {
            guard !Task.isCancelled else { break }
            guard let url = downloadedVolumeURLs[volumeId] else { continue }
            do {
                let docs = try await parser.parse(volumeURL: url)
                for doc in docs {
                    guard !Task.isCancelled else { break }
                    // For userTag scope, only include documents in the pre-computed key set
                    if case .userTag(let keys) = scope {
                        guard keys.contains("\(volumeId)/\(doc.documentId)") else { continue }
                    }
                    let text = doc.nodes
                        .map(\.plainText)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: "\n\n")
                    guard !text.isEmpty else { continue }
                    jobs.append((volumeId: volumeId, documentId: doc.documentId, text: text))
                }
            } catch {
                #if DEBUG
                print("[BackgroundSummarizer] Failed to parse volume \(volumeId): \(error)")
                #endif
            }
        }

        guard !Task.isCancelled, !jobs.isEmpty else {
            await MainActor.run { p.state = Task.isCancelled ? .cancelled : .completed(processed: 0) }
            return
        }

        let total = jobs.count
        await MainActor.run { p.state = .running(processed: 0, total: total, currentDocumentId: nil) }

        #if DEBUG
        print("[BackgroundSummarizer] Processing \(total) documents with concurrency=\(concurrencyLimit)")
        #endif

        let semaphore = ConcurrencySemaphore(limit: concurrencyLimit)
        let counter = ProcessedCounter()
        let context = ModelContext(modelContainer)

        await withTaskGroup(of: Void.self) { group in
            for job in jobs {
                guard !Task.isCancelled else { break }

                // Skip documents with an existing summary for this prompt
                if shouldSkip(volumeId: job.volumeId, documentId: job.documentId,
                               promptId: promptId, context: context) {
                    #if DEBUG
                    print("[BackgroundSummarizer] Skipping \(job.volumeId)/\(job.documentId) — already summarized")
                    #endif
                    continue
                }

                await semaphore.wait()

                let vid = job.volumeId
                let did = job.documentId
                let text = job.text

                group.addTask { [weak self] in
                    defer { Task { await semaphore.signal() } }
                    guard !Task.isCancelled, let self else { return }

                    let currentCount = await counter.value
                    await MainActor.run {
                        p.state = .running(
                            processed: currentCount,
                            total: total,
                            currentDocumentId: did
                        )
                    }

                    do {
                        try await self.withRetry(maxAttempts: 5) {
                            try await self.summarizationService.summarizeDiscarding(
                                documentId: did,
                                volumeId: vid,
                                documentText: text,
                                prompt: snapshot,
                                provider: provider,
                                activeProjectId: activeProjectId
                            )
                        }
                        #if DEBUG
                        print("[BackgroundSummarizer] Summarized \(vid)/\(did)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[BackgroundSummarizer] Failed after retries \(vid)/\(did): \(error)")
                        #endif
                    }

                    let newCount = await counter.increment()
                    await MainActor.run {
                        p.state = .running(processed: newCount, total: total, currentDocumentId: nil)
                    }
                }
            }
        }

        guard !Task.isCancelled else {
            await MainActor.run { p.state = .cancelled }
            return
        }

        let finalCount = await counter.value
        await MainActor.run { p.state = .completed(processed: finalCount) }

        #if DEBUG
        print("[BackgroundSummarizer] Completed. Processed \(finalCount)/\(total) documents.")
        #endif

        await deliverCompletionNotification(processed: finalCount, total: total)
    }

    // MARK: - Retry

    /// Retries `operation` with exponential backoff on any thrown error.
    ///
    /// Non-cancellation errors are retried up to 4 more times (5 attempts total).
    /// `CancellationError` propagates immediately.
    /// Delays: 2 s, 4 s, 8 s, 16 s.
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

    private func deliverCompletionNotification(processed: Int, total: Int) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "background.summarizer.notification.title",
                               defaultValue: "Summarization Complete")
        content.body = String(
            localized: "background.summarizer.notification.body",
            defaultValue: "\(processed) of \(total) documents summarized."
        )
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

// MARK: - ProcessedCounter

/// Thread-safe counter for tracking documents processed across concurrent tasks.
private actor ProcessedCounter {
    private(set) var value: Int = 0

    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }
}
