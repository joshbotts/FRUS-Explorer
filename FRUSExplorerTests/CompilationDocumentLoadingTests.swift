// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - CompilationDocumentLoadingTests

/// The per-section document load state and the rule that decides what to draw from it (#1301).
///
/// ## What had no coverage at all
/// Before this suite, `grep` for `loadDocuments`, `compilationDocuments` or `isLoadingDocuments`
/// across both test targets returned **nothing**. The pipeline *query* was covered several times
/// over in `IndexingPipelineTests`; its caller, and the state machine that decided what to draw
/// while waiting for it, were not. That is the gap #1301 lived in: a section whose load never ran
/// showed a spinner forever, because the spinner's condition was
/// `isLoadingDocuments || compilationDocuments[key] == nil` — the *absence of a result*, which no
/// amount of waiting turns into anything else.
///
/// ## Driving the real loader, not a mirror
/// Every test here runs a real `IndexingPipeline` over a real SQLite file in a temp directory,
/// indexing `UITestVolumeSeeder`'s own fixture — the same XML the UI suites seed — and takes its
/// sections from the structure the pipeline persisted. Nothing is hand-built, so a change to the
/// parse, to `documents(forVolume:)`, or to the section grammar shows up here rather than passing
/// against a fixture that agrees with itself.
///
/// The fixture's shape is Malta's, which is why it is the right one: a compilation with three
/// direct documents, a chapter under it with **none of its own**, and a subchapter under that with
/// two. The middle rung is the case the old code could not express — "loaded and empty" and "never
/// loaded" rendered identically.
///
/// ## Two things deliberately NOT tested here
/// **View identity.** Whether the iPad detail pane reuses one `CompilationView` across a
/// `.compilation → .compilation` step is not observable from a view model, so it is a UI test:
/// `FRUSExplorerUITests/BrowseNestedSectionTests`.
///
/// **The presence of `.task(id:)` in the source.** A source scan for that shape is the thing this
/// repo has already MEASURED to be vacuous — `VolumeStructure.swift:200` records a guard that
/// asserted a literal over raw source and stayed green while a mutant reinstated the bug in full.
///
/// Version history:
///   1.0 — #1301: initial implementation
///   1.1 — #1301 round 2: `.loading` is observed WHILE a load runs (a mutation sweep deleted the
///          one write that produces it and all 12 tests here stayed green, because the rule's
///          four-state sweep does not care whether a state is reachable); and the unindexed-volume
///          trap is measured rather than described in a comment — it records `.loaded` with no
///          rows, which is the one state that short-circuits. The closing note on
///          `routedSectionKindsOutrankTheLoadState` said those kinds never call `loadDocuments`;
///          they do, and the reason the branch order is safe is stated instead
@Suite("Compilation document loading — per-section state and the render rule")
@MainActor
struct CompilationDocumentLoadingTests {

    // MARK: - Fixture

    /// The volume the fixture is written for. Any manifest ID works; this is the one the UI suites
    /// seed, so both halves of #1301's coverage exercise the same XML.
    private static let volumeId = "frus1961-63v06"

    /// A real pipeline over a temp database, with `UITestVolumeSeeder`'s fixture indexed, plus the
    /// three sections of its nested branch read back from the persisted structure.
    private struct Fixture {
        /// The temp directory holding the volumes folder and the database. Callers remove it.
        let dir: URL
        /// The SQLite file, so a test can reach it through a second connection.
        let databaseURL: URL
        /// The pipeline under test.
        let pipeline: IndexingPipeline
        /// The compilation — three direct documents and one subsection.
        let compilation: VolumeSection
        /// The chapter under it — **no** direct documents, one subsection. Malta's `ch8`.
        let chapter: VolumeSection
        /// The subchapter under that — two documents, no subsections. Malta's `ch11`.
        let subchapter: VolumeSection
    }

    /// Builds the fixture: a temp pipeline with the seeder's XML indexed into it.
    ///
    /// - Returns: The pipeline and the three nested sections.
    private func makeFixture() async throws -> Fixture {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-1301-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volumes
        )
        try UITestVolumeSeeder.fixtureXML(volumeId: Self.volumeId)
            .write(to: volumes.appendingPathComponent("\(Self.volumeId).xml"),
                   atomically: true, encoding: .utf8)
        try await pipeline.indexVolume(Self.volumeId)

        // Read the sections back from the index rather than hand-building them: `documentIds` is
        // what `loadDocuments` filters on, and a hand-built section would make this suite agree
        // with itself instead of with the parser.
        let structure = try #require(
            try await pipeline.cachedVolumeStructure(forVolumeId: Self.volumeId),
            "the fixture must index a volume structure"
        )
        let compilation = try #require(
            structure.sections.first { $0.sectionId == "uitestcomp" },
            "the fixture's compilation is missing from the persisted structure"
        )
        let chapter = try #require(
            compilation.subsections.first { $0.sectionId == "uitestchapter" },
            "#1301's nested chapter is missing — the fixture's branch did not parse"
        )
        let subchapter = try #require(
            chapter.subsections.first { $0.sectionId == "uitestsubchapter" },
            "#1301's nested subchapter is missing"
        )
        return Fixture(dir: dir, databaseURL: dbURL, pipeline: pipeline,
                       compilation: compilation, chapter: chapter, subchapter: subchapter)
    }

    /// A view model with **no manifest entries**, deliberately.
    ///
    /// `loadDocuments` never reads the manifest, and before #1301 `CompilationView`'s `.task`
    /// gated the load on `volume != nil` — a lookup through `allSubseriesGroups` that the load
    /// does not need and that a side-loaded volume can fail. An empty store here is the standing
    /// check that the loader has no such dependency.
    ///
    /// - Parameter pipeline: The pipeline to attach, or `nil` for the unavailable-index case.
    /// - Returns: A fresh view model.
    private func makeViewModel(pipeline: IndexingPipeline?) -> BrowserViewModel {
        BrowserViewModel(
            manifestStore: ManifestStore(bundledEntries: []),
            tagStore: VolumeLevelTagStore(),
            downloadManager: nil,
            indexingPipeline: pipeline
        )
    }

    // MARK: - The loader

    @Test("A successful load records loaded, with the section's own rows")
    func successfulLoadRecordsLoadedRows() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        #expect(vm.documentLoadState(forKey: key).isLoaded == false,
                "precondition: nothing has been loaded for this key yet")

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)

        #expect(vm.documentLoadState(forKey: key).isLoaded, """
            A completed load must record `.loaded`, not merely fill the cache. The cache being \
            non-nil is what #1301's spinner condition tested, and it cannot distinguish a load \
            that failed from one that never ran.
            """)
        #expect(vm.compilationDocuments[key]?.map(\.documentId) == ["n1", "n2"], """
            The subchapter's two documents, and only those: `loadDocuments` filters the volume's \
            rows down to the section's DIRECT documentIds.
            """)
    }

    @Test("A section with no documents of its own records loaded-and-empty, never loading")
    func emptySectionRecordsLoadedNotLoading() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let key = vm.compilationKey(volumeId: Self.volumeId, sectionId: fixture.chapter.sectionId)

        #expect(fixture.chapter.documentIds.isEmpty, """
            Fixture guard: the chapter is the Malta `ch8` shape — subsections, no documents of \
            its own. If it grows one, this test stops being about anything.
            """)

        await vm.loadDocuments(for: fixture.chapter, volumeId: Self.volumeId)

        #expect(vm.documentLoadState(forKey: key).isLoaded, """
            An empty result is a RESULT. This is the case the old condition could not express, \
            because it drew the spinner on the cache entry's absence.
            """)
        #expect(vm.compilationDocuments[key]?.isEmpty == true)
        #expect(
            CompilationDocumentsPresentation.resolve(
                canReadDirectly: fixture.chapter.canReadDirectly,
                isPersonsList: fixture.chapter.isPersonsList,
                isSourcesList: fixture.chapter.isSourcesList,
                isIndexing: false,
                isIndexed: true,
                loadState: vm.documentLoadState(forKey: key)
            ) == .documents,
            """
            And it must DRAW as the document list, which renders "No documents in this section." \
            for an empty array — the fingerprint that separates a load that ran from one that \
            never did.
            """
        )
    }

    @Test("Loading one section leaves its sibling's state untouched")
    func eachSectionKeyIsIndependent() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let compKey = vm.compilationKey(volumeId: Self.volumeId,
                                        sectionId: fixture.compilation.sectionId)
        let chapterKey = vm.compilationKey(volumeId: Self.volumeId,
                                           sectionId: fixture.chapter.sectionId)

        await vm.loadDocuments(for: fixture.compilation, volumeId: Self.volumeId)

        #expect(vm.documentLoadState(forKey: compKey).isLoaded)
        #expect(vm.documentLoadState(forKey: chapterKey).isLoaded == false, """
            The state is per SECTION, so stepping into the chapter still needs a load — which is \
            exactly why the view's `.task` has to be keyed on the cache key rather than on \
            appearance.
            """)
        #expect(
            CompilationDocumentsPresentation.resolve(
                canReadDirectly: false, isPersonsList: false, isSourcesList: false,
                isIndexing: false, isIndexed: true,
                loadState: vm.documentLoadState(forKey: chapterKey)
            ) == .awaitingLoad,
            """
            And until that load runs the chapter draws the spinner — #1301's screen exactly. The \
            fix is that the keyed task always runs it; the terminal states are what make the \
            failure visible when it cannot.
            """
        )

        await vm.loadDocuments(for: fixture.chapter, volumeId: Self.volumeId)
        #expect(vm.documentLoadState(forKey: chapterKey).isLoaded)
    }

    @Test("Reloading a loaded section is idempotent")
    func reloadingALoadedSectionIsIdempotent() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)
        let first = vm.compilationDocuments[key]?.map(\.documentId)
        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)

        #expect(vm.documentLoadState(forKey: key).isLoaded)
        #expect(vm.compilationDocuments[key]?.map(\.documentId) == first, """
            `.loaded` is the one state that short-circuits, so the three `.onChange` kicks and \
            the keyed task can all fire for a section already answered without re-querying it.
            """)
    }

    @Test("`.loading` is observable WHILE the load runs, not only before and after it")
    func loadingIsObservableWhileTheLoadRuns() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        // `LoadingIsProducedOnlyByAnInFlightLoad` sweeps the RULE and would stay green if nothing
        // could ever produce `.loading` — it would then be pinning the mapping of a value the app
        // cannot reach, and its headline claim ("if and only if a load is genuinely in flight")
        // would be satisfied from the wrong side. `loadDocuments` holds the ONLY write of
        // `.loading` in the tree, so this is the test that says the state is real.
        //
        // The observation is deterministic rather than timed: `documents(forVolume:)` is a method
        // on a different actor, so the load always suspends at that hop with `.loading` already
        // written, and this task's continuation is enqueued behind the write.
        let task = Task { await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId) }
        var sawLoading = false
        var terminatedFirst = false
        for _ in 0..<200 {
            await Task.yield()
            if case .loading = vm.documentLoadState(forKey: key) { sawLoading = true; break }
            if vm.documentLoadState(forKey: key).isLoaded { terminatedFirst = true; break }
        }
        await task.value

        let observed = terminatedFirst
            ? "The load reached `.loaded` without ever passing through it"
            : "The state never left `.notStarted`"
        #expect(sawLoading, """
            A load in flight must be observable as `.loading`. \(observed) — so nothing in the \
            app produces `.loading`, and the rule's sweep is pinning a dead value.
            """)
        #expect(vm.documentLoadState(forKey: key).isLoaded, "and it still finishes")
    }

    @Test("An unindexed volume caches as loaded-and-empty — the trap the caller's guard exists for")
    func unindexedVolumeCachesAsLoadedAndEmpty() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        // A volume that exists in no index. `documents(forVolume:)` answers it with an empty set,
        // exactly as it answers a volume with no matching rows.
        let unindexedVolumeId = "frus1958-60v01"
        let key = vm.compilationKey(volumeId: unindexedVolumeId,
                                    sectionId: fixture.subchapter.sectionId)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: unindexedVolumeId)

        #expect(vm.documentLoadState(forKey: key).isLoaded, """
            This is the hazard, stated as a measurement rather than as a warning in a comment: an \
            unindexed volume does not fail and does not stay `.notStarted`. It records `.loaded`.
            """)
        #expect(vm.compilationDocuments[key]?.isEmpty == true, """
            …with no rows. And `.loaded` is the ONE state `loadDocuments` short-circuits on, so \
            after the volume is indexed the keyed task (same key), the Retry button and all three \
            `.onChange` kicks would every one of them return early, leaving the reader on "No \
            documents in this section." for the life of the process — #1301 with a different \
            label on it. That is why the caller must not call this for an unindexed volume, and \
            why the gate it calls instead is pinned separately.
            """)
    }

    @Test("A cancelled load still reaches a terminal state")
    func cancelledLoadStillReachesATerminalState() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        // `.task(id:)` cancels the outgoing load on every section change, so a fast drill-down
        // cancels loads routinely. This is the tolerance that makes that safe, asserted rather
        // than assumed: `documents(forVolume:)` is a synchronous method on an actor, so the await
        // is a bare actor hop and not a cancellation point, and the load runs to completion and
        // writes ITS OWN key. Adding a `Task.checkCancellation()` to that path would start leaving
        // sections stranded at `.loading` again, and this test is what would say so.
        let task = Task { await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId) }
        task.cancel()
        await task.value

        #expect(vm.documentLoadState(forKey: key).isLoaded, """
            A cancelled load must not strand the section mid-flight: a `.loading` that nothing \
            will ever finish is #1301's permanent spinner in a new costume.
            """)
        #expect(vm.compilationDocuments[key]?.count == 2)
    }

    // MARK: - Failure

    @Test("No pipeline records failed, naming the unavailable index")
    func missingPipelineRecordsFailed() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: nil)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)

        let failure = try #require(vm.documentLoadState(forKey: key).failure, """
            A load with no pipeline must RECORD a failure. It used to `return` silently, which \
            the view drew as a spinner.
            """)
        #expect(failure as? BrowserIndexingError == .pipelineUnavailable)
        #expect(vm.compilationDocuments[key] == nil, """
            And it must not mint an empty cache entry, which would read as loaded-and-empty.
            """)
    }

    @Test("A failed section reloads on retry rather than short-circuiting")
    func retryAfterFailureLoads() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: nil)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)
        #expect(vm.documentLoadState(forKey: key).failure != nil, "precondition: it failed")

        // What the Retry button does, and what the pipeline back-fill's `.onChange` kick does:
        // call the loader again. Only `.loaded` short-circuits, so a failure is always retryable.
        vm.attachIndexingPipelineIfNeeded(fixture.pipeline)
        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)

        #expect(vm.documentLoadState(forKey: key).isLoaded)
        #expect(vm.compilationDocuments[key]?.count == 2)
    }

    @Test("A query that throws records failed, not an empty list")
    func queryFailureRecordsFailed() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)

        // Drop the table through a SECOND connection, the seam `DespatchSerialExtractionTests`
        // established. The pipeline's first read afterwards prepares against its cached schema and
        // fails at the STEP, which SQLite reports as end-of-rows; that failure reloads the schema,
        // so the second read fails at the PREPARE and throws. Both halves matter here, because the
        // two land in different states and only the second is the one this test is about.
        var handle: OpaquePointer?
        #expect(sqlite3_open(fixture.databaseURL.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, "DROP TABLE document_cache", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)
        await vm.loadDocuments(for: fixture.chapter, volumeId: Self.volumeId)

        let chapterKey = vm.compilationKey(volumeId: Self.volumeId,
                                           sectionId: fixture.chapter.sectionId)
        let failure = try #require(vm.documentLoadState(forKey: chapterKey).failure, """
            A throwing read must record `.failed`. The old loader swallowed the throw in a \
            DEBUG-only `print`, left the cache entry nil, and the view drew that as a spinner \
            with no error row and no retry.
            """)
        #expect(vm.compilationDocuments[chapterKey] == nil, """
            A failure must not leave rows behind for the view to draw. \
            Rows found: \(vm.compilationDocuments[chapterKey]?.count ?? -1); failure: \(failure).
            """)
    }

    // MARK: - What the failure row says, and what its button asks for

    @Test("A reachable failure reads as a sentence, never as a Swift type and an error number")
    func aReachableFailureReadsAsASentence() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: fixture.pipeline)

        // The same seam as `queryFailureRecordsFailed`: the only failure this row can reach in
        // production is a throwing `documents(forVolume:)`, so the error under test is a real one
        // the pipeline threw, not a hand-made stand-in.
        var handle: OpaquePointer?
        #expect(sqlite3_open(fixture.databaseURL.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, "DROP TABLE document_cache", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)
        await vm.loadDocuments(for: fixture.chapter, volumeId: Self.volumeId)
        let chapterKey = vm.compilationKey(volumeId: Self.volumeId,
                                           sectionId: fixture.chapter.sectionId)
        let failure = try #require(vm.documentLoadState(forKey: chapterKey).failure)

        // The control, and the reason this test exists: left to Foundation, THIS is what the row
        // showed a historian. If this line ever fails because `IndexingError` gained a
        // `LocalizedError` conformance, the row is fine and this control is what needs rewriting.
        #expect(failure.localizedDescription.contains("IndexingError"), """
            Control: the raw description names the Swift type. Got: \(failure.localizedDescription)
            """)

        let shown = BrowserDocumentLoadFailure.readable(failure)
        #expect(!shown.contains("couldn’t be completed") && !shown.contains("couldn't be completed"),
                "the row shows Foundation's fallback sentence: \(shown)")
        #expect(!shown.contains("IndexingError") && !shown.contains("FRUSExplorer."),
                "the row names an internal Swift type: \(shown)")
        #expect(shown.contains("search index"), """
            And it says something true and useful instead — the section could not be read out of \
            the search index, with Retry beside it. Got: \(shown)
            """)
    }

    @Test("An error that already has a reader-facing sentence keeps it")
    func aLocalizedErrorKeepsItsOwnSentence() throws {
        let expected = try #require(BrowserIndexingError.pipelineUnavailable.errorDescription)
        #expect(BrowserDocumentLoadFailure.readable(BrowserIndexingError.pipelineUnavailable)
                == expected, """
            `pipelineUnavailable` carries a real recovery instruction — relaunch, and reinstall if \
            it comes back — which is better than anything this mapping could say about it. The \
            substitution is for errors with NO description, not for all of them.
            """)
    }

    @Test("Retry asks for the section it is shown under, and for no other")
    func retryAsksForItsOwnSection() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.dir) }
        let vm = makeViewModel(pipeline: nil)
        let key = vm.compilationKey(volumeId: Self.volumeId,
                                    sectionId: fixture.subchapter.sectionId)
        let neighbourKey = vm.compilationKey(volumeId: Self.volumeId,
                                             sectionId: fixture.chapter.sectionId)

        await vm.loadDocuments(for: fixture.subchapter, volumeId: Self.volumeId)
        #expect(vm.documentLoadState(forKey: key).failure != nil, "precondition: it failed")

        let retry = vm.retryAction(for: fixture.subchapter, volumeId: Self.volumeId)
        #expect(retry.targetKey == key, """
            The button is shown INSIDE the failed section's row, so it must ask for that section. \
            A retry wired to a neighbour is indistinguishable from a correct one by any count of \
            calls: it fills another section's cache while this one keeps its error row.
            """)
        #expect(retry.targetKey != neighbourKey, "control: the neighbour's key is a different one")

        vm.attachIndexingPipelineIfNeeded(fixture.pipeline)
        await retry.run()

        #expect(vm.documentLoadState(forKey: key).isLoaded, "and pressing it clears the failure")
        #expect(vm.compilationDocuments[key]?.map(\.documentId) == ["n1", "n2"])
        #expect(vm.documentLoadState(forKey: neighbourKey).isLoaded == false,
                "and it loaded THIS section, not the one beside it")
    }

    // MARK: - The render rule

    @Test("Loading is produced if and only if a load is genuinely in flight")
    func loadingIsProducedOnlyByAnInFlightLoad() {
        let states: [(String, BrowserDocumentLoadState, CompilationDocumentsPresentation)] = [
            ("notStarted", .notStarted, .awaitingLoad),
            ("loading", .loading, .loading),
            ("loaded", .loaded, .documents),
            ("failed", .failed(BrowserIndexingError.pipelineUnavailable), .failed),
        ]
        var sawLoading = 0
        for (name, state, expected) in states {
            let drawn = CompilationDocumentsPresentation.resolve(
                canReadDirectly: false, isPersonsList: false, isSourcesList: false,
                isIndexing: false, isIndexed: true, loadState: state
            )
            #expect(drawn == expected, "\(name) must draw as \(expected), got \(drawn)")
            if drawn == .loading { sawLoading += 1 }
        }
        #expect(sawLoading == 1, """
            Exactly one of the four load states may resolve to `.loading`, and it is the one with \
            a load in flight. #1301's condition resolved to it for `.notStarted`, `.loading` AND \
            every failure, which is why a failure was indistinguishable from a slow load, forever.
            """)
    }

    @Test("An unindexed volume draws Index Required, whatever its load state")
    func indexRequiredWinsOverEveryLoadState() {
        // This is the pin for the ONE early return `CompilationView`'s task still takes. It
        // declines for an unindexed volume, and it must: `document_cache` answers an unindexed
        // volume with an empty set, which would cache as `.loaded` and never reload after
        // indexing. The decline leaves the state at `.notStarted` — and is observable only
        // because that same condition resolves here to a real screen with a real button.
        let states: [BrowserDocumentLoadState] = [
            .notStarted, .loading, .loaded, .failed(BrowserIndexingError.pipelineUnavailable),
        ]
        for state in states {
            #expect(
                CompilationDocumentsPresentation.resolve(
                    canReadDirectly: false, isPersonsList: false, isSourcesList: false,
                    isIndexing: false, isIndexed: false, loadState: state
                ) == .indexRequired,
                "an unindexed volume must never fall through to the load state"
            )
        }
    }

    @Test("Indexing in progress outranks the index check")
    func indexingProgressOutranksIndexRequired() {
        #expect(
            CompilationDocumentsPresentation.resolve(
                canReadDirectly: false, isPersonsList: false, isSourcesList: false,
                isIndexing: true, isIndexed: false, loadState: .notStarted
            ) == .indexingProgress,
            """
            Mid-run `isIndexed` flips partway, and the reader should watch the progress bar \
            rather than the banner it is about to replace.
            """
        )
    }

    @Test("Each presentation draws its own row, and only the two pre-terminal states share one")
    func eachPresentationDrawsItsOwnRow() {
        // One assertion per case, not a sweep that counts: a sweep survives a SWAP, and the
        // mutation this exists for is exactly that — the failure drawn as the spinner, which left
        // the error row and its Retry button declared, localized, referenced by
        // `EditableContentKeyTests`, and rendered by nothing.
        #expect(CompilationDocumentsPresentation.readDirectly.rowKind == .readDirectly)
        #expect(CompilationDocumentsPresentation.personsList.rowKind == .personsList)
        #expect(CompilationDocumentsPresentation.sourcesList.rowKind == .sourcesList)
        #expect(CompilationDocumentsPresentation.indexingProgress.rowKind == .indexingProgress)
        #expect(CompilationDocumentsPresentation.indexRequired.rowKind == .indexRequired)
        #expect(CompilationDocumentsPresentation.failed.rowKind == .errorRow, """
            A load that failed draws the ERROR ROW — the headline, the readable sentence and \
            Retry. Drawn as the spinner it is #1301's screen again: a terminal state that looks \
            like a slow load, for ever, with no way to ask again.
            """)
        #expect(CompilationDocumentsPresentation.documents.rowKind == .documentRows)

        // The one collapse, asserted as two facts rather than as "some state draws the spinner".
        #expect(CompilationDocumentsPresentation.awaitingLoad.rowKind == .spinner, """
            Before the first attempt, the spinner: an error row here would be a lie and a blank \
            gap reads as a rendering failure.
            """)
        #expect(CompilationDocumentsPresentation.loading.rowKind == .spinner)

        // And nothing else shares a row kind — a second collapse would hide a state on screen.
        let all: [CompilationDocumentsPresentation] = [
            .readDirectly, .personsList, .sourcesList, .indexingProgress,
            .indexRequired, .awaitingLoad, .loading, .failed, .documents,
        ]
        #expect(Set(all.map(\.rowKind)).count == all.count - 1, """
            Nine presentations, eight rows: `awaitingLoad` and `loading` share the spinner and \
            nothing else shares anything.
            """)
    }

    @Test("The three routed section kinds outrank everything, including a failure")
    func routedSectionKindsOutrankTheLoadState() {
        let failed = BrowserDocumentLoadState.failed(BrowserIndexingError.pipelineUnavailable)
        #expect(CompilationDocumentsPresentation.resolve(
            canReadDirectly: true, isPersonsList: false, isSourcesList: false,
            isIndexing: true, isIndexed: false, loadState: failed) == .readDirectly)
        #expect(CompilationDocumentsPresentation.resolve(
            canReadDirectly: false, isPersonsList: true, isSourcesList: false,
            isIndexing: true, isIndexed: false, loadState: failed) == .personsList)
        #expect(CompilationDocumentsPresentation.resolve(
            canReadDirectly: false, isPersonsList: false, isSourcesList: true,
            isIndexing: true, isIndexed: false, loadState: failed) == .sourcesList)
        // WHY THE ORDER IS SAFE, measured rather than assumed. These three kinds DO load: the
        // keyed `.task` tests only `isIndexed`, so on an indexed volume it calls `loadDocuments`
        // for a persons, sources or prose-readable section exactly as for any other — a
        // full-volume `documents(forVolume:)` query filtered against an empty `documentIds`,
        // recording `.loaded` with no rows. (`VolumeView.sectionRow` appends `.compilation` for
        // every section the structure lists, front matter included, so they really do arrive
        // here.) Nothing breaks because the rule returns their branch BEFORE it consults the load
        // state — which is what these three assertions pin, each against a `.failed` state that
        // would otherwise draw the error row over a persons list.
    }
}
