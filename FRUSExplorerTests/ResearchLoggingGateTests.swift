// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - ResearchLoggingGateTests

/// Pins that the "Log Research Sessions" switch governs **every** writer of the research trail.
///
/// ## Why this suite exists
/// Before Wave R-1 the app recorded what you read twice, through two independent systems, and the
/// switch governed only one of them. Opening a document fired `AppState.logEvent(.documentOpen)`
/// — gated — and `DocumentViewModel.recordReadingHistory` — gated by nothing at all. The gated
/// recorder feeds the session log and nothing else; the ungated one feeds the History window,
/// Project Home's recents, Project Leads' engaged documents, the search checklist and the storage
/// hub's last-opened dates. Turning the switch off therefore did not stop the app remembering what
/// you read. The same shape held for searches with the platforms swapped: the iOS `.searchSubmit`
/// event was gated, the macOS `SearchHistoryEntry` was not.
///
/// No test covered any of the three writers. These do.
///
/// ## What each writer gets
/// | Writer | Reachable from the iOS test bundle? | Covered by |
/// |---|---|---|
/// | `AppState.logEvent` (document open, iOS + macOS) | yes | behavioural test |
/// | `AppState.logEvent` (search submit, iOS only) | yes | behavioural test |
/// | `DocumentViewModel.recordReadingHistory` (iOS + macOS) | yes | behavioural test |
/// | `SearchViewModel.recordSearchHistory` (iOS, Wave R-4) | yes | behavioural test, over a real FTS5 index |
/// | `MacSearchViewModel.recordSearchHistory` (macOS only) | **no** — the type is `#if os(macOS)` and this bundle builds for iOS | source-shape test |
///
/// `FRUSExplorerTests` is an iOS-only target (`project.yml`) and the macOS scheme has no test
/// action, so a behavioural test of the macOS search writer would compile nowhere and run never.
/// It is guarded instead by ``macSearchWriterChecksTheGateBeforeInserting``, which reads the
/// source the same way `CodingStandardsAuditTests` does and fails if the gate is removed or moved
/// after the insert.
///
/// ## Test hygiene
/// Every test drives the gate through a throwaway `UserDefaults` suite rather than
/// `UserDefaults.standard`, so nothing here can leave the host app's real preference flipped for
/// a later suite — the reason the writers take a `defaults:` parameter at all.
///
/// Version history:
///   1.0 — Wave R-1: initial implementation
///   1.1 — Wave R-4: the iOS `SearchHistoryEntry` producer this suite's fourth-writer guard was
///          written to catch now exists, so it is listed there and covered behaviourally —
///          off / on / de-duplicated — plus a guard that every `SearchView` search entry point
///          still routes through the one recorder
@MainActor
struct ResearchLoggingGateTests {

    // MARK: - Fixtures

    /// A throwaway defaults suite, plus a teardown handle. Callers must invoke `destroy()`.
    private struct ScratchDefaults {
        let store: UserDefaults
        private let suiteName: String

        init() {
            suiteName = "frus.tests.researchLoggingGate.\(UUID().uuidString)"
            // `UserDefaults(suiteName:)` only returns nil for reserved names (the bundle id and
            // the global domain); a UUID-suffixed name is neither.
            store = UserDefaults(suiteName: suiteName)!
        }

        /// Sets the research-logging preference in this scratch suite.
        func setLogging(_ enabled: Bool) {
            store.set(enabled, forKey: AppState.researchLoggingPreferenceKey)
        }

        /// Removes the whole suite so nothing survives the test.
        func destroy() {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }

    /// A browser entry to open. Fields match `DocumentViewTests`' fixture shape.
    private func makeEntry(documentId: String = "d1",
                           volumeId: String = "frus1969-76v01") -> DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            documentNumber: "1",
            header: "Memorandum of Conversation",
            dateline: "Washington, January 20, 1969.",
            sourceNote: nil
        )
    }

    /// A view model over `makeEntry()`. No load is performed — `recordReadingHistory` reads only
    /// `entry`, which is set at init.
    private func makeViewModel(documentId: String = "d1",
                               volumeId: String = "frus1969-76v01") -> DocumentViewModel {
        DocumentViewModel(
            entry: makeEntry(documentId: documentId, volumeId: volumeId),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        )
    }

    // MARK: - The gate itself

    /// An absent value means **on**, so the switch does not silently disable recording for every
    /// existing user the first time someone tidies the default. `SettingsSyncCoordinator`'s push
    /// relies on the same convention, which is why both now read through this one function.
    @Test("An absent preference means research logging is on")
    func absentPreferenceMeansOn() {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }

        #expect(AppState.isResearchLoggingEnabled(in: scratch.store))
    }

    /// And an explicit value is honoured in both directions.
    @Test("An explicit preference is honoured in both directions")
    func explicitPreferenceIsHonoured() {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }

        scratch.setLogging(false)
        #expect(AppState.isResearchLoggingEnabled(in: scratch.store) == false)

        scratch.setLogging(true)
        #expect(AppState.isResearchLoggingEnabled(in: scratch.store))
    }

    // MARK: - Document open — the headline case

    /// **The test Wave R-1 exists to make pass.** With the preference off, opening a document
    /// inserts neither a `SessionEvent` nor a `ReadingHistoryEntry`. Before R-1 the second half of
    /// this assertion failed: the reading-history writer had no gate at all.
    @Test("With logging off, opening a document records neither a session event nor reading history")
    func documentOpenRecordsNothingWhenLoggingOff() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(false)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let appState = AppState()
        appState.loggingContext = context

        // Exactly the pair `DocumentView` fires on open, ~50 lines apart.
        appState.logEvent(.documentOpen(volumeId: "frus1969-76v01",
                                        documentId: "d1",
                                        title: "Memorandum of Conversation"),
                          defaults: scratch.store)
        makeViewModel().recordReadingHistory(projectId: UUID(),
                                             in: context,
                                             defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<SessionEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ResearchSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ReadingHistoryEntry>()).isEmpty)
    }

    /// The control. Without it the test above would pass just as happily if both writers were
    /// broken outright, which is the failure mode a gate test is most likely to hide.
    @Test("With logging on, opening a document records both a session event and reading history")
    func documentOpenRecordsBothWhenLoggingOn() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let projectId = UUID()

        let appState = AppState()
        appState.loggingContext = context

        appState.logEvent(.documentOpen(volumeId: "frus1969-76v01",
                                        documentId: "d42",
                                        title: "Memorandum of Conversation"),
                          defaults: scratch.store)
        makeViewModel(documentId: "d42").recordReadingHistory(projectId: projectId,
                                                              in: context,
                                                              defaults: scratch.store)

        let events = try context.fetch(FetchDescriptor<SessionEvent>())
        #expect(events.count == 1)
        #expect(events.first?.eventType == "documentOpen")
        #expect(try context.fetch(FetchDescriptor<ResearchSession>()).count == 1)

        let visits = try context.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(visits.count == 1)
        #expect(visits.first?.documentId == "d42")
        #expect(visits.first?.projectId == projectId)
    }

    /// Absent the preference entirely — a fresh install — recording still happens. Pins the
    /// default the same way the gate test does, but through the writers rather than the helper.
    @Test("With no preference set, opening a document still records")
    func documentOpenRecordsWhenPreferenceAbsent() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let appState = AppState()
        appState.loggingContext = context

        appState.logEvent(.documentOpen(volumeId: "frus1969-76v01",
                                        documentId: "d1",
                                        title: "Memorandum of Conversation"),
                          defaults: scratch.store)
        makeViewModel().recordReadingHistory(projectId: nil, in: context, defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<SessionEvent>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ReadingHistoryEntry>()).count == 1)
    }

    // MARK: - Search submit (iOS producer)

    /// The iOS search writer. `SearchViewModel.search()` calls `appState.logEvent(.searchSubmit…)`
    /// after a completed search; the gate is `logEvent`'s, so it is tested at that boundary rather
    /// than by standing up a `SearchService` and an FTS5 database.
    @Test("With logging off, submitting a search records no session event")
    func searchSubmitRecordsNothingWhenLoggingOff() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(false)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let appState = AppState()
        appState.loggingContext = context
        appState.logEvent(.searchSubmit(query: "détente", resultCount: 12), defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<SessionEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ResearchSession>()).isEmpty)
    }

    /// The control — and a reminder of what is at stake: the payload carries the user's raw query
    /// text into a CloudKit-mirrored store.
    @Test("With logging on, submitting a search records the query text")
    func searchSubmitRecordsQueryWhenLoggingOn() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let appState = AppState()
        appState.loggingContext = context
        appState.logEvent(.searchSubmit(query: "détente", resultCount: 12), defaults: scratch.store)

        let events = try context.fetch(FetchDescriptor<SessionEvent>())
        #expect(events.count == 1)
        #expect(events.first?.eventType == "searchSubmit")
        let payload = try #require(events.first?.payload)
        let decoded = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        #expect(decoded?["query"] as? String == "détente")
    }

    // MARK: - Search history (iOS producer, Wave R-4)

    /// A real FTS5 index over a two-document fixture, plus the view model that searches it.
    ///
    /// `recordSearchHistory` reads state that only a completed `search()` sets — the frozen
    /// `submittedQuery`, `searchError`, `results` — so these tests drive the whole path rather
    /// than poking the view model's fields. The temporary directory is the caller's to remove.
    ///
    /// Explicitly `@MainActor`: a nested type does not inherit its enclosing type's isolation,
    /// and `SearchViewModel` is main-actor-isolated.
    @MainActor
    private struct SearchHarness {
        let directory: URL
        let viewModel: SearchViewModel

        /// Builds the index and returns a view model wired to it.
        static func make() async throws -> SearchHarness {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("FRUSLoggingGate-\(UUID().uuidString)", isDirectory: true)
            let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)

            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>frus1969-76v01</title></titleStmt>
              <publicationStmt><date>2003</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
                <div type="compilation" xml:id="comp1">
                  <div type="document" xml:id="d1"><head>Memorandum of Conversation</head>\
            <dateline>Washington, January 20, 1969.</dateline>\
            <p>Discussed détente policy with the Soviet delegation.</p></div>
                  <div type="document" xml:id="d2"><head>Telegram</head>\
            <dateline>Moscow, February 5, 1969.</dateline>\
            <p>Routine administrative message about staff assignments.</p></div>
                </div>
              </body></text>
            </TEI>
            """
            try xml.write(to: volumes.appendingPathComponent("frus1969-76v01.xml"),
                          atomically: true,
                          encoding: .utf8)

            let dbURL = dir.appendingPathComponent("gate.sqlite")
            let store = try FTS5Store(databaseURL: dbURL)
            let pipeline = try IndexingPipeline(fts5Store: store,
                                                databaseURL: dbURL,
                                                volumesDirectory: volumes,
                                                concurrencyLimit: 1)
            try await pipeline.indexVolume("frus1969-76v01")

            return SearchHarness(
                directory: dir,
                viewModel: SearchViewModel(
                    searchService: SearchService(fts5Store: store, pipeline: pipeline)))
        }

        /// Removes the temporary index.
        func destroy() { try? FileManager.default.removeItem(at: directory) }
    }

    /// **The R-4 half of what R-1 protected.** With the preference off, running a search on iOS
    /// inserts no `SearchHistoryEntry`. Shipping this producer ungated would have started
    /// collecting the user's search text on a platform that was not collecting it — strictly more
    /// collection than before — which is why R-1 had to land first.
    @Test("With logging off, an iOS search records no search history")
    func iOSSearchRecordsNothingWhenLoggingOff() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(false)

        let harness = try await SearchHarness.make()
        defer { harness.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        harness.viewModel.keywords = "détente"
        await harness.viewModel.search()
        harness.viewModel.recordSearchHistory(projectId: UUID(),
                                              in: context,
                                              defaults: scratch.store)

        #expect(!harness.viewModel.results.isEmpty, "the search itself must still run")
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).isEmpty)
    }

    /// The control, and the feature: one row per distinct query, stamped with the active project.
    /// Before R-4 this count was structurally zero on iOS no matter how much the user searched,
    /// which is why Project Home's "Searches Run" tile never left 0 for anyone without a Mac.
    @Test("With logging on, an iOS search records exactly one row per distinct query")
    func iOSSearchRecordsOneRowPerDistinctQueryWhenLoggingOn() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let harness = try await SearchHarness.make()
        defer { harness.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let projectId = UUID()
        let vm = harness.viewModel

        vm.keywords = "détente"
        await vm.search()
        vm.recordSearchHistory(projectId: projectId, in: context, defaults: scratch.store)

        let afterFirst = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(afterFirst.count == 1)
        #expect(afterFirst.first?.queryText == "détente")
        #expect(afterFirst.first?.projectId == projectId)
        #expect(afterFirst.first?.resultCount == vm.results.count)

        // A different query is a different row.
        vm.keywords = "telegram"
        await vm.search()
        vm.recordSearchHistory(projectId: projectId, in: context, defaults: scratch.store)

        let afterSecond = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(afterSecond.count == 2)
        #expect(Set(afterSecond.map(\.queryText)) == ["détente", "telegram"])
    }

    /// The de-duplication, which is the whole reason `submittedQuery` is frozen and
    /// `lastRecordedHistoryQuery` exists. `SearchView` re-runs `search()` for the **same** query
    /// whenever a filter moves — clearing the volume scope, tapping a tag chip on a result row —
    /// and each of those must not read as another search the user ran.
    @Test("A scope-only re-run of the same iOS query does not duplicate the row")
    func iOSScopeOnlyRerunDoesNotDuplicate() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let harness = try await SearchHarness.make()
        defer { harness.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let vm = harness.viewModel

        vm.keywords = "détente"
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 1)

        // Narrow the volume scope and re-run — the query text has not changed.
        vm.selectedVolumeIds = ["frus1969-76v01"]
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 1)

        // And widening it again is still the same query.
        vm.selectedVolumeIds = []
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 1)
    }

    /// The skip conditions inherited from the macOS writer. An empty keyword box records nothing
    /// — `search()` refuses it outright — so a person-only "find all mentions" hand-off leaves no
    /// query row rather than a blank one.
    @Test("An iOS search with no keywords records no search history")
    func iOSEmptyQueryRecordsNothing() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let harness = try await SearchHarness.make()
        defer { harness.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let vm = harness.viewModel

        vm.keywords = "   "
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)

        #expect(vm.searchError != nil, "an all-whitespace query is rejected by search()")
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).isEmpty)
    }

    // MARK: - Source-shape guards

    /// The repository root, located the same way `CodingStandardsAuditTests` does.
    private static let projectRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let sourceRoot: URL = projectRoot.appendingPathComponent("FRUSExplorer")

    /// The macOS search writer, checked by reading its source: the gate must appear **between**
    /// the function signature and the `context.insert`, which pins both its presence and its
    /// position. Placement matters — the function mutates `lastRecordedHistoryQuery` on the way
    /// through, and a gate placed after that mutation would silently swallow the first query the
    /// user runs after switching logging back on.
    ///
    /// A source test rather than a behavioural one because `MacSearchViewModel` is `#if os(macOS)`
    /// and this bundle builds for iOS; see the suite doc comment.
    @Test("MacSearchViewModel.recordSearchHistory checks the gate before inserting")
    func macSearchWriterChecksTheGateBeforeInserting() throws {
        let url = Self.sourceRoot.appendingPathComponent("App/MacSearchViewModel.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let signature = "func recordSearchHistory("
        let insert = "context.insert(record)"
        let signatureRange = try #require(source.range(of: signature),
                                          "recordSearchHistory has been renamed or removed")
        let insertRange = try #require(source.range(of: insert, range: signatureRange.upperBound..<source.endIndex),
                                       "recordSearchHistory no longer inserts a record")

        let body = source[signatureRange.upperBound..<insertRange.lowerBound]
        #expect(body.contains("AppState.isResearchLoggingEnabled(in: defaults)"),
                """
                MacSearchViewModel.recordSearchHistory must consult the research-logging gate \
                before inserting a SearchHistoryEntry (Wave R-1)
                """)
    }

    /// No further writer has appeared without a gate.
    ///
    /// Scans every app source file for `ReadingHistoryEntry(` / `SearchHistoryEntry(`
    /// construction and asserts the producing files are exactly the known gated ones. R-4's iOS
    /// search-history writer — the candidate this guard was written for — is now the third, and
    /// it is gated. A fourth fails this test until it is listed here, which is the moment to
    /// check it consults the gate.
    @Test("Every producer of a history entry is a known, gated writer")
    func noUngatedHistoryWriterExists() throws {
        let expected: Set<String> = [
            "DocumentViewModel.swift",   // ReadingHistoryEntry — gated
            "MacSearchViewModel.swift",  // SearchHistoryEntry  — gated (macOS)
            "SearchViewModel.swift",     // SearchHistoryEntry  — gated (iOS, Wave R-4)
        ]

        let enumerator = try #require(
            FileManager.default.enumerator(at: Self.sourceRoot,
                                           includingPropertiesForKeys: nil))
        var producers: Set<String> = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let content = try String(contentsOf: url, encoding: .utf8)
            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Prose that names the initialiser is not a producer.
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }
                if trimmed.contains("ReadingHistoryEntry(") || trimmed.contains("SearchHistoryEntry(") {
                    producers.insert(url.lastPathComponent)
                }
            }
        }

        #expect(producers == expected,
                """
                A history-entry producer appeared or moved: \(producers.sorted()). Every writer \
                of the research trail must honour AppState.isResearchLoggingEnabled (Wave R-1). \
                Update this list once the new writer is gated.
                """)
    }

    /// Every iOS search entry point still routes through the one recorder (Wave R-4).
    ///
    /// `SearchView` runs a search from five places — the keyboard Return, the Saved Searches
    /// sheet, an incoming `pendingSearch` hand-off, clearing the volume scope, and tapping a tag
    /// chip on a result row. Each calls `runSearch()`, which awaits `vm.search()` and then
    /// records. A sixth site added later that calls `vm.search()` directly would run the search
    /// and leave no `SearchHistoryEntry` — invisible in review, and untestable behaviourally
    /// because the omission is in the view, not the view model. So the shape is pinned instead:
    /// `vm.search()` may appear exactly once in the file, inside `runSearch()`, immediately
    /// followed by the recorder.
    @Test("Every iOS search entry point routes through the one history recorder")
    func iOSSearchEntryPointsRouteThroughTheRecorder() throws {
        let url = Self.sourceRoot.appendingPathComponent("Search/SearchView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)

        // Prose that names the call is not a call site — the same exclusion the scans above use.
        let callSites = lines.indices.filter {
            let trimmed = lines[$0].trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*") else { return false }
            return trimmed.contains("vm.search()")
        }
        #expect(callSites.count == 1,
                """
                SearchView must call vm.search() from exactly one place — runSearch() — so every \
                search entry point records a SearchHistoryEntry (Wave R-4). Found \
                \(callSites.count) call sites at lines \(callSites.map { $0 + 1 }).
                """)

        let callSite = try #require(callSites.first)
        let follows = lines[(callSite + 1)...].prefix(2).joined(separator: "\n")
        #expect(follows.contains("recordSearchHistory("),
                "the vm.search() call in SearchView must be followed by vm.recordSearchHistory(…)")

        // And the gate is the view model's, checked before the insert — the same shape the macOS
        // writer is held to above.
        let vmURL = Self.sourceRoot.appendingPathComponent("Search/SearchViewModel.swift")
        let vmSource = try String(contentsOf: vmURL, encoding: .utf8)
        let signatureRange = try #require(vmSource.range(of: "func recordSearchHistory("),
                                          "SearchViewModel.recordSearchHistory is missing")
        let insertRange = try #require(
            vmSource.range(of: "context.insert(record)",
                           range: signatureRange.upperBound..<vmSource.endIndex),
            "SearchViewModel.recordSearchHistory no longer inserts a record")
        #expect(vmSource[signatureRange.upperBound..<insertRange.lowerBound]
            .contains("AppState.isResearchLoggingEnabled(in: defaults)"),
                """
                SearchViewModel.recordSearchHistory must consult the research-logging gate \
                before inserting a SearchHistoryEntry (Wave R-1 / R-4)
                """)
    }

    /// The preference key is read in exactly one place. `SettingsSyncCoordinator`, the two
    /// `@AppStorage` bindings and the three writers all route through `AppState`, so a future
    /// call site that reaches for `UserDefaults` directly — and gets the absent-means-on
    /// convention wrong — is caught here rather than in a bug report.
    @Test("The research-logging key string is written down in exactly one place")
    func preferenceKeyHasOneDeclaration() throws {
        let literal = "\"researchSessionLoggingEnabled\""
        let enumerator = try #require(
            FileManager.default.enumerator(at: Self.sourceRoot,
                                           includingPropertiesForKeys: nil))
        var files: Set<String> = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let content = try String(contentsOf: url, encoding: .utf8)
            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }
                if trimmed.contains(literal) { files.insert(url.lastPathComponent) }
            }
        }

        #expect(files == ["AppState.swift"],
                """
                The researchSessionLoggingEnabled literal must appear only in AppState \
                (as researchLoggingPreferenceKey); found in \(files.sorted())
                """)
    }
}
