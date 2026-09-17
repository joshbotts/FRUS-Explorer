// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

#if DEBUG

// MARK: - UITestBrowseSeams

/// The three launch seams a UI test needs to stand in a Browse state a normal run cannot produce
/// (#1301 round 2).
///
/// ## Why seams rather than cleverer tests
/// #1301 shipped four things a UI test could not reach at all, and a mutation sweep found every
/// one of them undefended: the failure row and its **Retry** control (nothing in the app can be
/// made to fail a document load), and the three `.onChange` kicks that turn a *declined* load into
/// a completed one (each needs an indexing event that the seeded, already-indexed fixture never
/// produces). A test that cannot reach a state cannot pin it, and the row that draws that state is
/// then free to be deleted by a refactor with every suite still green.
///
/// Each seam is shaped after ``UITestVolumeSeeder``: the whole file is `#if DEBUG`, so none of it
/// exists in AppStore or DirectDistribution builds, and each seam is inert unless its own launch
/// key is set. None of them fakes an outcome — the failure seam **throws** where the real query
/// would throw and leaves the recording, the rendering and the retry to production code; the cold
/// seam removes real index rows through `IndexingPipeline.removeVolume(_:)`; the attach seam
/// delays a real assignment.
///
/// ## The cold seam is why three suites' "Index Now" branch was never entered
/// `CompilationDocumentsTests`, `TwoPaneDocumentTests` and `BrowseNestedSectionTests` all tolerate
/// the Index Now button rather than requiring it (`if indexNow.waitForExistence(…)`), because on a
/// warm simulator the seeded volume is already indexed. It is never *cold* either: a freshly
/// erased simulator has no date-index version recorded, so boot's own `indexAllVolumes()` pass
/// indexes the fixture before Browse can be walked, and the reconcile pass beside it catches
/// anything that misses. Measured across every logged run of this branch, the tap has fired zero
/// times. ``coldVolumeRequested`` makes the cold state explicit instead of incidental, and both
/// boot passes stand down while it is armed so nothing re-indexes what the seam just removed.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
enum UITestBrowseSeams {

    // MARK: - 1. An injected document-load failure

    /// Launch key for the failure seam. Its value is the `sectionId` whose **first** document load
    /// should throw (`uitestsubchapter`, say).
    static let failSectionKey = "FRUS_UI_TEST_FAIL_DOCUMENT_LOAD"

    /// Section ids whose injected failure has already been spent.
    ///
    /// The seam is deliberately ONE-SHOT per section, which is what lets one test assert both
    /// halves of the terminal state: the error row appears, and tapping **Retry** — which calls
    /// the same loader again — reaches the section's own rows. A permanently failing seam could
    /// only ever show that the row appears.
    @MainActor private static var spentFailures: Set<String> = []

    /// Throws once for the section named by ``failSectionKey``, in the place the real query throws.
    ///
    /// Called from inside `BrowserViewModel.loadDocuments`'s `do` block, so the error it throws
    /// travels the production path: the same `catch`, the same `.failed` recording, the same row.
    /// It throws `IndexingError.sqliteError` because that is the only error a reachable failure
    /// can carry — `documents(forVolume:)` throws solely through `auxPrepare` — and because that
    /// type has no `LocalizedError` conformance, which is the fact the row's message has to
    /// survive.
    ///
    /// - Parameter sectionId: The section whose load is about to run.
    @MainActor
    static func throwInjectedFailureIfRequested(sectionId: String) throws {
        guard let wanted = ProcessInfo.processInfo.environment[failSectionKey],
              wanted == sectionId,
              !spentFailures.contains(sectionId) else { return }
        spentFailures.insert(sectionId)
        print("[UITestBrowseSeams] Injecting a one-shot document-load failure for \(sectionId)")
        throw IndexingError.sqliteError(code: 1,
                                        message: "injected by \(failSectionKey) for \(sectionId)")
    }

    // MARK: - 1b. A document load held open

    /// Launch key for the slow-load seam: `<sectionId>:<seconds>`, e.g. `uitestsubchapter:8`.
    static let slowSectionKey = "FRUS_UI_TEST_DELAY_DOCUMENT_LOAD"

    /// Holds a named section's load open, so a test can see the screen a load IN FLIGHT produces.
    ///
    /// Real loads finish in milliseconds, which makes the in-flight row unobservable: by the time
    /// a UI test can assert anything the rows are up. That is why the mutation which drew the
    /// pre-load and in-flight states as the *document list* survived every suite — on screen it
    /// shows "No documents in this section." for a section that has documents, and then corrects
    /// itself. Held open for a few seconds, the lie is assertable.
    ///
    /// Sleeps AFTER `.loading` is recorded and before the query, which is exactly the window the
    /// spinner exists for.
    ///
    /// - Parameter sectionId: The section whose load is about to run.
    @MainActor
    static func delayLoadIfRequested(sectionId: String) async {
        guard let raw = ProcessInfo.processInfo.environment[slowSectionKey] else { return }
        let parts = raw.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, String(parts[0]) == sectionId,
              let seconds = Double(parts[1]), seconds > 0 else { return }
        print("[UITestBrowseSeams] Holding \(sectionId)'s load open for \(seconds)s")
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: - 2. A genuinely cold seeded volume

    /// Launch key for the cold seam: set to `1` to leave the seeded fixture **unindexed**, so the
    /// compilation opens on "Index Required" and the reader must tap **Index Now**.
    static let coldVolumeKey = "FRUS_UI_TEST_COLD_SEEDED_VOLUME"

    /// Whether the cold seam is armed.
    static var coldVolumeRequested: Bool {
        ProcessInfo.processInfo.environment[coldVolumeKey] == "1"
    }

    /// Brings the seeded fixture to the state this run asks for, **before** `AppState` publishes
    /// the pipeline — so the first render of any Browse level already sees it.
    ///
    /// Armed cold, it removes the volume's index rows. Otherwise it re-indexes a fixture whose
    /// bytes changed, which is the repair #1301 round 1 added: the volumes directory and the index
    /// both survive between runs, and `BrowserViewModel.loadVolumeStructure` prefers the persisted
    /// `volume_structures` row over parsing the file, so a warm simulator served the OLD structure
    /// from a NEW fixture. Re-indexing one 2 KB fixture is near-instant and, unlike deleting the
    /// database, leaves a developer's real volumes alone.
    ///
    /// - Parameters:
    ///   - seeded: What `UITestVolumeSeeder.seedIfRequested(in:)` returned, or `nil`.
    ///   - pipeline: The freshly constructed pipeline.
    static func prepareSeededVolume(_ seeded: UITestVolumeSeeder.SeedResult?,
                                    pipeline: IndexingPipeline) async {
        guard let seeded else { return }
        do {
            if coldVolumeRequested {
                try await pipeline.removeVolume(seeded.volumeId)
                print("[UITestBrowseSeams] Un-indexed \(seeded.volumeId): this run wants it cold")
            } else if seeded.contentChanged {
                try await pipeline.indexVolume(seeded.volumeId)
                print("[UITestVolumeSeeder] Re-indexed \(seeded.volumeId) after a fixture change")
            }
        } catch {
            print("[UITestBrowseSeams] Could not prepare \(seeded.volumeId): \(error)")
        }
    }

    // MARK: - 3. A late pipeline

    /// Launch key for the attach seam. Its value is a number of seconds.
    static let pipelineDelayKey = "FRUS_UI_TEST_DELAY_PIPELINE"

    /// How long `AppState` should go without a pipeline, or `nil` when the seam is not armed.
    static var pipelineAttachDelay: Double? {
        guard let raw = ProcessInfo.processInfo.environment[pipelineDelayKey],
              let seconds = Double(raw), seconds > 0 else { return nil }
        return seconds
    }

    /// Runs `attach` after ``pipelineAttachDelay`` seconds instead of now.
    ///
    /// This reproduces R-9's boot race on purpose. `BrowserViewModel.isIndexed(_:)` answers
    /// `false` without a pipeline, so a compilation opened during the delay draws "Search Index
    /// Unavailable" and its keyed `.task` declines — and the task will not re-run afterwards,
    /// because its key has not changed. The `.onChange(of: vm.indexingPipeline == nil)` kick is
    /// the only thing that asks for the rows once the pipeline arrives, and this is the only way
    /// a test can stand where it matters.
    ///
    /// Nothing else in boot is delayed: every other statement uses the local pipeline value.
    ///
    /// - Parameters:
    ///   - delay: Seconds to wait.
    ///   - attach: The assignment to run afterwards.
    @MainActor
    static func attachPipeline(after delay: Double, _ attach: @escaping @MainActor () -> Void) {
        print("[UITestBrowseSeams] Holding the pipeline back for \(delay)s")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            attach()
            print("[UITestBrowseSeams] Pipeline attached after \(delay)s")
        }
    }
}

#endif
