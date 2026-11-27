// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

#if DEBUG
import notify

// MARK: - UITestBrowseSeams

/// The launch seams a UI test needs to stand in a Browse state a normal run cannot produce
/// (#1301 round 2; the fifth, a download finishing while a compilation is open, round 4).
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
/// delays a real assignment; the finished-download seam hands a volume already on disk to
/// `DownloadManager`'s real completion router.
///
/// ## The two late seams wait for the test, not for a clock
/// The attach seam and the finished-download seam each need the test to be standing on a
/// compilation first. Both used to fire a fixed number of seconds after launch (25 and 30), on
/// the measurement that the walk there took less. On 2026-10-11 the same walk took 46 to 50
/// seconds on iPhone 17 under iOS 27.0 (each element query cost 2 to 3.5 seconds, as it did on
/// an iPhone 17 under iOS 26.5), so the pipeline had attached and the download had finished
/// before the test arrived, and both tests failed on their own check of that premise, on `v2`
/// as on a branch. A longer delay is the same race with a longer fuse, and it costs every run
/// the wait. So each seam now holds until the test sends it a ``Signal``, which the test does
/// once it has seen the state it came for: no clock is involved.
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
/// ## The three kicks, and the seam each one needed
/// Three `.onChange` kicks in `CompilationView` re-ask for a declined section's rows, and each now
/// has a seam: kick 1 (`vm.isIndexing` falling) a cold volume indexed from the compilation itself;
/// kick 3 (the pipeline back-filled) a pipeline held back past the first render; and kick 2
/// (`AppState.currentIndexingProgress` returning to `nil`) a download that finishes while the
/// compilation is open — ``finishSeededDownloadOnSignal(_:in:)``, added in round 4.
///
/// **Round 3 accepted kick 2 as unreachable, and understated it.** It called kick 2 the kick for a
/// bulk index started from Settings, "where the reader is not standing on a compilation". But
/// `currentIndexingProgress` goes `nil` on EVERY pipeline `.complete`, and the automatic index
/// `onVolumeDownloaded` starts after each download is one of them, while `vm.isIndexing` — kick 1's
/// trigger — is set only by Index Now. So kick 2 serves every index not started from this view,
/// above all the automatic index after a download, which makes it the only loader on the ordinary
/// download → open → browse path; a regression there reproduces #1301's permanent spinner.
/// Gutting it — both guards kept, the `loadDocuments` call removed — left every suite green each
/// time it was measured: by round 1's mutation attack, and twice by round 2's.
/// `BrowseNestedSectionTests.testAnIndexStartedElsewhereFillsTheOpenCompilation` is the walk that
/// sees it.
///
/// Its precondition is pinned at the model grain too:
/// `CompilationDocumentLoadingTests.aDeclinedLoadLeavesAKickSomethingToDo` asserts that a declined
/// load leaves the section not-loaded, which is what every kick stands on — a refactor recording
/// `.loaded` on a decline would make all three call the loader and all three return immediately.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
///   1.1 — #1301 round 3: the two boot stand-downs and the seeded-fixture repair are values with
///          unit tests (``bootIndexingStandDown(coldVolumeRequested:)``, ``SeedPreparation``);
///          both were previously branches whose deletion no suite could see
///   1.2 — #1301 round 4: a fifth seam, `finishSeededDownload(_:after:in:)`, starts the automatic
///          post-download index through `DownloadManager`'s own completion router while a
///          compilation is open — kick 2's scenario, which round 3 accepted as unstageable on a
///          premise that was false
///   1.3 — 2026-10-11: the attach seam and the finished-download seam fire on a ``Signal`` the
///          test sends, where each fired a fixed time after launch
///          (`FRUS_UI_TEST_DELAY_PIPELINE`, `FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_AFTER`). The
///          walk to a compilation had outgrown both delays, and `BrowseNestedSectionTests`' two
///          tests of them failed on `v2`
///   1.4 — #1918 (L18, A11Y-2): a sixth seam, a search Search runs on the test's signal
///          (``searchesOnSignal``), so that VoiceOver can listen to a search no input the test synthesizes ran
///   1.5 — #1920 (L20, HCD-2): downloads that wait or fail, with no network (``downloadSeam``), and a
///          queue of volumes at launch (``downloadsToQueue``)
///   1.6 — #1920 (L20, HCD-3): a download the test starts by signal (``downloadsOnSignal``)
///   1.7 — R6a (F4): the signals that add and delete a note from outside All Notes
///   1.8 — #2013 (L57): the search seam's hand-off can carry two days (``searchOnSignalDates``), as Chronology's
///          Search in this range hands them
///   1.9 — #2012 (L56): Chronology can open on a range a test names (``chronologyRange``), which its date
///          pickers cannot be set to in a test
enum UITestBrowseSeams {

    // MARK: - 0. A signal from the test

    /// What a UI test can tell the running app, as a Darwin notification: the one channel from
    /// the test runner's process into the app's that needs nothing drawn on screen.
    ///
    /// The test posts the raw value with `notify_post`; `BrowseNestedSectionTests` keeps a copy of
    /// each string, since a UI suite cannot reference the app's constants.
    enum Signal: String, CaseIterable {
        /// Release the pipeline the attach seam is holding (``holdsPipeline``).
        case attachPipeline = "bottsywattsy.FRUS-Explorer.uitest.attach-pipeline"
        /// Finish the seeded volume's download (``finishesSeededDownloadOnSignal``).
        case finishSeededDownload = "bottsywattsy.FRUS-Explorer.uitest.finish-seeded-download"
        /// Hand Search a search for the armed words (``searchesOnSignal``).
        case search = "bottsywattsy.FRUS-Explorer.uitest.search"
        /// Start the armed volume's download (``downloadsOnSignal``).
        case startDownload = "bottsywattsy.FRUS-Explorer.uitest.start-download"
        /// Add a note as another device's import would (`UITestResearchSeeder.changeNotesOnSignalIfRequested`).
        case addNote = "bottsywattsy.FRUS-Explorer.uitest.add-note"
        /// Delete the seeded note as another device's import would (the same seam).
        case deleteNote = "bottsywattsy.FRUS-Explorer.uitest.delete-note"
    }

    /// Runs `action` on the main actor the first time `signal` arrives, and not again.
    ///
    /// - Parameters:
    ///   - signal: The signal to wait for.
    ///   - action: What to do when it arrives.
    /// - Returns: Whether the app is listening. `false` means the system refused the
    ///   registration, and the action will never run.
    @MainActor
    @discardableResult
    static func onSignal(_ signal: Signal, _ action: @escaping @MainActor () -> Void) -> Bool {
        var token: Int32 = 0
        let status = notify_register_dispatch(signal.rawValue, &token, DispatchQueue.main) { token in
            // One signal, one run: a second post must not attach or finish anything twice.
            notify_cancel(token)
            MainActor.assumeIsolated { action() }
        }
        guard status == NOTIFY_STATUS_OK else {
            print("[UITestBrowseSeams] Could not listen for \(signal.rawValue): status \(status)")
            return false
        }
        print("[UITestBrowseSeams] Listening for \(signal.rawValue)")
        return true
    }

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
    /// shows an empty list for a section that has documents (nothing at all, since #1690, under a
    /// section that lists sections), and then corrects itself. Held open for a few seconds, the
    /// missing spinner is assertable.
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

    /// What both boot indexing passes must answer while the cold seam is armed, or `nil` when boot
    /// should decide for itself (#1301 round 3).
    ///
    /// ## Why this is a function and not two `if` statements a hundred lines apart
    /// `FRUSExplorerApp` runs two passes that each index every downloaded volume they find, and
    /// **both** have to stand down or the seam's `removeVolume(_:)` is undone before Browse can be
    /// walked. Round 2 wrote them as two separate `if UITestBrowseSeams.coldVolumeRequested`
    /// lines, and they are not equally load-bearing: deleting the reconcile arm fails the
    /// cold-volume UI test, while deleting the date-re-index arm leaves it PASSING on any
    /// simulator that has run the suite before — a date-index version is recorded there, so
    /// `needsDateReindex` is already `false` and that arm is inert. Which half is pinned therefore
    /// depended on the machine's history, and a green run on a warm device proved only one of them.
    ///
    /// Answering both from one function makes the decision a value with a unit test over its two
    /// outputs, so deleting either arm is a unit failure rather than an environment-dependent UI
    /// one. The residue is stated rather than implied: nothing here catches the deletion of a CALL
    /// SITE in `FRUSExplorerApp`, which is what a cold UI run on a freshly erased device would.
    ///
    /// - Parameter coldVolumeRequested: ``coldVolumeRequested``, passed in because a Swift Testing
    ///   run cannot set its own process environment — the same lift
    ///   `UITestVolumeSeeder.seed(volumeId:in:)` makes.
    /// - Returns: `(false, false)` while the seam is armed; `nil` otherwise.
    static func bootIndexingStandDown(
        coldVolumeRequested: Bool
    ) -> (dateReindexNeeded: Bool, reconcileUnindexedDownloads: Bool)? {
        guard coldVolumeRequested else { return nil }
        return (dateReindexNeeded: false, reconcileUnindexedDownloads: false)
    }

    /// ``bootIndexingStandDown(coldVolumeRequested:)`` for this process.
    static var bootIndexingStandDown: (dateReindexNeeded: Bool,
                                       reconcileUnindexedDownloads: Bool)? {
        bootIndexingStandDown(coldVolumeRequested: coldVolumeRequested)
    }

    // MARK: - 2b. What a seeded fixture needs before the pipeline is published

    /// What ``prepareSeededVolume(_:pipeline:)`` should do to a freshly written fixture
    /// (#1301 round 3).
    ///
    /// A value rather than a branch inside the `do` block, because the branch that matters is
    /// invisible in every run that would notice it: `reindex` repairs the NEXT launch on a machine
    /// where the fixture's bytes changed, and deleting it left 31 tests in four suites and every UI
    /// suite green. `SeedPreparation.plan(cold:contentChanged:)` has one assertion per input pair.
    ///
    /// Version history:
    ///   1.0 — #1301 round 3: initial implementation
    enum SeedPreparation: Equatable {

        /// Remove the volume's index rows: this run wants it cold.
        case unindex

        /// Re-index it: the bytes on disk changed, so anything indexed from the old fixture — the
        /// persisted `volume_structures` row included — describes a file that no longer exists.
        case reindex

        /// Leave it alone.
        case none

        /// The plan for one seeded volume.
        ///
        /// Cold wins over changed: the cold seam's whole purpose is a volume with no index rows,
        /// and re-indexing one it was about to strip would defeat it.
        ///
        /// - Parameters:
        ///   - cold: ``UITestBrowseSeams/coldVolumeRequested``.
        ///   - contentChanged: `UITestVolumeSeeder.SeedResult.contentChanged`.
        /// - Returns: What to do.
        static func plan(cold: Bool, contentChanged: Bool) -> SeedPreparation {
            if cold { return .unindex }
            if contentChanged { return .reindex }
            return .none
        }
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
            switch SeedPreparation.plan(cold: coldVolumeRequested,
                                        contentChanged: seeded.contentChanged) {
            case .unindex:
                try await pipeline.removeVolume(seeded.volumeId)
                print("[UITestBrowseSeams] Un-indexed \(seeded.volumeId): this run wants it cold")
            case .reindex:
                try await pipeline.indexVolume(seeded.volumeId)
                print("[UITestVolumeSeeder] Re-indexed \(seeded.volumeId) after a fixture change")
            case .none:
                break
            }
        } catch {
            print("[UITestBrowseSeams] Could not prepare \(seeded.volumeId): \(error)")
        }
    }

    // MARK: - 3. A late pipeline

    /// Launch key for the attach seam: set to `1` to leave `AppState` without a pipeline until the
    /// test sends ``Signal/attachPipeline``.
    static let holdPipelineKey = "FRUS_UI_TEST_HOLD_PIPELINE"

    /// Whether the attach seam is armed.
    static var holdsPipeline: Bool {
        ProcessInfo.processInfo.environment[holdPipelineKey] == "1"
    }

    /// Runs `attach` when the test sends ``Signal/attachPipeline``, instead of now.
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
    /// - Parameter attach: The assignment to run when the signal arrives.
    @MainActor
    static func attachPipelineOnSignal(_ attach: @escaping @MainActor () -> Void) {
        print("[UITestBrowseSeams] Holding the pipeline back until the test releases it")
        onSignal(.attachPipeline) {
            attach()
            print("[UITestBrowseSeams] Pipeline attached on the test's signal")
        }
    }

    // MARK: - 4. A download that finishes while a compilation is open

    /// Launch key for the finished-download seam: set to `1` to finish the seeded volume's
    /// download when the test sends ``Signal/finishSeededDownload``.
    static let finishSeededDownloadKey = "FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL"

    /// Whether the finished-download seam is armed.
    static var finishesSeededDownloadOnSignal: Bool {
        ProcessInfo.processInfo.environment[finishSeededDownloadKey] == "1"
    }

    /// Hands the seeded volume to `DownloadManager`'s completion router when the test sends
    /// ``Signal/finishSeededDownload``, as though its download had just finished (#1301 round 4).
    ///
    /// Armed with the cold seam, this is the ordinary download → open → browse path: the fixture is
    /// on disk and unindexed, the reader opens its compilation and sees "Index Required", and then —
    /// with nothing touched — the automatic post-download index runs and finishes. Kick 1 cannot
    /// answer that (`vm.isIndexing` is set only by Index Now), kick 3 cannot (the pipeline already
    /// exists), and the keyed task's key has not changed, so the progress kick is the only thing
    /// left that asks for the rows. See the type's doc comment.
    ///
    /// The index is the app's own: `DownloadManager.replayFinishedTransferForUITest(volumeId:)` runs
    /// the `onVolumeDownloaded` closure `FRUSExplorerApp` supplied, and nothing here calls the
    /// pipeline directly.
    ///
    /// - Parameters:
    ///   - volumeId: The seeded volume, already on disk.
    ///   - manager: The app's download manager.
    @MainActor
    static func finishSeededDownloadOnSignal(_ volumeId: String, in manager: DownloadManager) {
        print("[UITestBrowseSeams] Finishing \(volumeId)'s download when the test asks for it")
        onSignal(.finishSeededDownload) {
            Task { @MainActor in
                await manager.replayFinishedTransferForUITest(volumeId: volumeId)
                print("[UITestBrowseSeams] Finished \(volumeId)'s download: its automatic index runs now")
            }
        }
    }

    // MARK: - 5. A search no synthesized input ran (#1918, A11Y-2)

    /// Launch key for the search seam: the words Search is handed when the test sends ``Signal/search``.
    static let searchOnSignalKey = "FRUS_UI_TEST_SEARCH_ON_SIGNAL"

    /// Launch key for the two days the search seam's hand-off also carries, as `yyyy-MM-dd/yyyy-MM-dd`: a date range
    /// as Chronology's Search in this range hands one (#2013, L57). Unset, the hand-off carries none.
    static let searchOnSignalDatesKey = "FRUS_UI_TEST_SEARCH_ON_SIGNAL_DATES"

    /// The armed words, or `nil` when the seam is not armed.
    static var searchesOnSignal: String? {
        ProcessInfo.processInfo.environment[searchOnSignalKey].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The armed date range, or `nil` when the hand-off carries none.
    static var searchOnSignalDates: DateRange? {
        ProcessInfo.processInfo.environment[searchOnSignalDatesKey].flatMap(handOffDateRange(from:))
    }

    /// The date range a `yyyy-MM-dd/yyyy-MM-dd` value names, or `nil` when it does not name two days.
    ///
    /// The two days go into the range as they are written, as a hand-off passes them; Search reads them
    /// (`SearchViewModel.applyParameters(_:)`), and that reading is what `FilterDateRangeHandOffTests` watches.
    ///
    /// - Parameter value: The launch key's value.
    /// - Returns: The range, or `nil`.
    static func handOffDateRange(from value: String) -> DateRange? {
        let days = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard days.count == 2, days.allSatisfy({ !$0.isEmpty }) else { return nil }
        return DateRange(earliest: days[0], latest: days[1])
    }

    /// Hands Search a keyword search for `words` when the test sends ``Signal/search``, as a hand-off does
    /// (`AppState.openSearch(_:from:)`, consumed by the Search tab), on the armed days when there are some
    /// (``searchOnSignalDates``).
    ///
    /// `SearchResultVoiceOverTests` listens to VoiceOver while that search finishes. With VoiceOver on, a tap or
    /// typing the test synthesized left VoiceOver on in the simulator after the service's `disable()` (measured
    /// 2026-11-15, iPhone 17, iOS 27.0), and every test after it met VoiceOver's cursor; a search this signal runs
    /// needs no input at all. `FilterDateRangeHandOffTests` arms the days too, and reads Filters' two date pickers
    /// after the hand-off.
    ///
    /// - Parameters:
    ///   - words: The words to search for.
    ///   - appState: The app's state, whose pending search the Search tab runs.
    @MainActor
    static func searchOnSignal(_ words: String, in appState: AppState) {
        let dates = searchOnSignalDates
        let between = dates.map { " between \($0.earliest ?? "") and \($0.latest ?? "")" } ?? ""
        print("[UITestBrowseSeams] Handing Search \"\(words)\"\(between) when the test asks for it")
        onSignal(.search) {
            appState.openSearch(SearchParameters(keywords: words, dateRange: dates), from: nil)
            print("[UITestBrowseSeams] Handed Search \"\(words)\"\(between)")
        }
    }

    // MARK: - 6. Downloads that wait, or fail (#1920, L20)

    /// Launch key for the download seam: `hold` keeps every transfer waiting until it is cancelled;
    /// `fail` fails every transfer, as with no connection, after ``failingAttemptDuration``, its
    /// retries ``seamRetryBackoff`` apart. Either way nothing reaches the network.
    ///
    /// `DownloadCancelAllTests` holds a queue to cancel it; `VolumeDownloadFailureTests` fails a
    /// download to read what the volume's page says. Before it, a UI test could neither keep a
    /// download running nor make one fail: the app downloaded from GitHub.
    static let downloadsKey = "FRUS_UI_TEST_DOWNLOADS"

    /// What the download seam does with every transfer.
    enum DownloadSeam: String {
        /// Each transfer waits until it is cancelled.
        case hold
        /// Each transfer fails with `URLError(.notConnectedToInternet)`, after ``failingAttemptDuration``.
        case fail
    }

    /// The armed download seam, or `nil` when it is not armed.
    static var downloadSeam: DownloadSeam? {
        ProcessInfo.processInfo.environment[downloadsKey].flatMap(DownloadSeam.init(rawValue:))
    }

    /// The wait before a failed transfer's retry under the seam, so a failure's retries are spent in
    /// well under a second where the app's own wait is five seconds, then ten.
    static let seamRetryBackoff: Duration = .milliseconds(200)

    /// The transfer the seam puts where the network would be.
    ///
    /// - Parameter seam: The armed seam.
    /// - Returns: A transfer that waits until cancelled, or one that fails.
    static func transfer(for seam: DownloadSeam) -> DownloadManager.DownloadTask {
        switch seam {
        case .hold:
            return { _ in
                try await Task.sleep(for: .seconds(86_400))
                throw URLError(.timedOut)
            }
        case .fail:
            // Each attempt takes a moment before it fails, so that a test sees "Downloading…" on the
            // volume's page before the failure, and so knows Retry queued the volume again.
            return { _ in
                try await Task.sleep(for: failingAttemptDuration)
                throw URLError(.notConnectedToInternet)
            }
        }
    }

    /// How long each of `fail`'s attempts runs before it fails: three attempts, with the two retries'
    /// waits, come to about five seconds.
    static let failingAttemptDuration: Duration = .seconds(1.5)

    /// The defaults the download manager keeps its queue in under the seam: a suite of the seam's
    /// own, emptied at each launch that arms it. A queue a test leaves behind in the app's own
    /// defaults would be downloaded from GitHub by the next launch without the seam, and every suite
    /// after it would run beside those downloads.
    ///
    /// - Returns: The emptied suite.
    static func seamPreferences() -> UserDefaults {
        let name = "bottsywattsy.FRUS-Explorer.uitest.downloads"
        UserDefaults.standard.removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    /// Launch key: how many catalogue volumes not on the device to queue once the download manager
    /// is up, in the bundled manifest's order. With `hold`, the queue then stays as it is.
    static let queueDownloadsKey = "FRUS_UI_TEST_QUEUE_DOWNLOADS"

    /// How many volumes to queue, or `nil` when the key is absent or not a positive number.
    static var downloadsToQueue: Int? {
        ProcessInfo.processInfo.environment[queueDownloadsKey].flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Queues `count` catalogue volumes that are not on the device.
    ///
    /// - Parameters:
    ///   - count: How many to queue.
    ///   - entries: The catalogue, in the bundled manifest's order.
    ///   - manager: The app's download manager.
    static func queueDownloads(_ count: Int, of entries: [VolumeManifestEntry], in manager: DownloadManager) async {
        var queued = 0
        for entry in entries where queued < count && !manager.isVolumeDownloaded(entry.volumeId) {
            if await manager.enqueueDownload(entry) == .queued { queued += 1 }
        }
        print("[UITestBrowseSeams] Queued \(queued) downloads")
    }

    // MARK: - 7. A download the test starts by signal (#1920, L20, HCD-3)

    /// Launch key: the volume whose download starts when the test sends ``Signal/startDownload``.
    static let downloadOnSignalKey = "FRUS_UI_TEST_DOWNLOAD_ON_SIGNAL"

    /// The armed volume, or `nil` when the seam is not armed.
    static var downloadsOnSignal: String? {
        ProcessInfo.processInfo.environment[downloadOnSignalKey].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Starts `volumeId`'s download when the test sends ``Signal/startDownload``, as its page's
    /// Download Volume does.
    ///
    /// `VolumeDownloadFailureAnnouncementTests` listens to VoiceOver while that download fails, with
    /// the volume's page on screen. With VoiceOver on a tap only moves its cursor, and a test that has
    /// read speech leaves VoiceOver on under Xcode 27.2 (#1918's seam has why), so the download is
    /// started with no input at all.
    ///
    /// - Parameters:
    ///   - volumeId: A catalogue volume that is not on the device.
    ///   - appState: The app's state, whose catalogue and download manager the download goes through.
    @MainActor
    static func downloadOnSignal(_ volumeId: String, in appState: AppState) {
        print("[UITestBrowseSeams] Downloading \(volumeId) when the test asks for it")
        onSignal(.startDownload) {
            guard let manager = appState.downloadManager,
                  let entry = appState.manifestStore.entry(forVolumeId: volumeId) else {
                print("[UITestBrowseSeams] Could not download \(volumeId): no manager or no catalogue entry")
                return
            }
            Task {
                await manager.enqueueDownload(entry)
                print("[UITestBrowseSeams] Queued \(volumeId)'s download")
            }
        }
    }

    // MARK: - 8. Chronology opened on a range (#2012, L56)

    /// Launch key for the range Chronology loads when it opens, as `yyyy-MM-dd/yyyy-MM-dd`: two days the screen
    /// would otherwise be set to by its two date pickers and Show (#2012, L56). Unset, it opens on the manifest's
    /// latest year, as it does for a reader.
    ///
    /// The pickers are compact date pickers, which a UI test can set only through their calendars, a month at a
    /// time: 1962 is 64 years from the manifest's latest. `ChronologyRangeHandOffTests` and
    /// `ChronologyRangeSaveTests` open the screen on the browse fixture's three months instead.
    static let chronologyRangeKey = "FRUS_UI_TEST_CHRONOLOGY_RANGE"

    /// The armed range as Chronology's parameters, or `nil` when the seam is not armed.
    static var chronologyRange: ChronologyParameters? {
        ProcessInfo.processInfo.environment[chronologyRangeKey].flatMap(chronologyParameters(from:))
    }

    /// The parameters a `yyyy-MM-dd/yyyy-MM-dd` value names, or `nil` when it does not name two days.
    ///
    /// Each day is its midnight in the device's zone, which is the date the screen's pickers hold for a day they
    /// show, so the screen loads, and shows, the two days written. A test that runs the app in another zone (`TZ`)
    /// gets those days there.
    ///
    /// - Parameter value: The launch key's value.
    /// - Returns: The parameters, or `nil`.
    static func chronologyParameters(from value: String) -> ChronologyParameters? {
        let days = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard days.count == 2 else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let dates = days.compactMap { day -> Date? in
            let parts = day.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
        guard dates.count == 2 else { return nil }
        return ChronologyParameters(rangeStart: dates[0], rangeEnd: dates[1])
    }
}

#endif
