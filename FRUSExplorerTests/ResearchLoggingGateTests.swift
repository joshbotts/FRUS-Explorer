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
/// recorder fed the session log and nothing else; the ungated one feeds the History surface,
/// Project Home's recents, the search checklist and the storage hubs' last-opened dates. Turning
/// the switch off therefore did not stop the app remembering what you read. The same shape held
/// for searches with the platforms swapped: the iOS `.searchSubmit` event was gated, the macOS
/// `SearchHistoryEntry` was not.
///
/// No test covered any of the three writers. These do.
///
/// ## What each writer gets
/// | Writer | Reachable from the iOS test bundle? | Covered by |
/// |---|---|---|
/// | `DocumentViewModel.recordReadingHistory` (iOS + macOS) | yes | behavioural test |
/// | `SearchViewModel.recordSearchHistory` (iOS, Wave R-4) | yes | behavioural test, over a real FTS5 index |
/// | `ExportHistoryRecorder.record` (iOS + macOS, Wave R-2a) | yes | behavioural test |
/// | `MacSearchViewModel.recordSearchHistory` (macOS only) | **no** — the type is `#if os(macOS)` and this bundle builds for iOS | source-shape test |
///
/// `AppState.logEvent` used to be the first two rows of that table. Wave R-2a retired it — nothing
/// writes a `SessionEvent` any more, so its gate is no longer a thing that can regress.
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
///   1.2 — Wave R-2a: the `AppState.logEvent` tests go with the method. `ExportHistoryRecorder` is
///          the new third writer and is covered behaviourally; the producer guard now scans for
///          `ExportHistoryEntry(` too, which is what made it fail until the two files that
///          construct one were listed
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
    /// records no `ReadingHistoryEntry`. Before R-1 this failed outright: the reading-history
    /// writer had no gate at all.
    ///
    /// Until Wave R-2a this also asserted that no `SessionEvent` was written. That writer is
    /// retired; reading history is now the only record of a document open, which is precisely why
    /// the migration does not carry `.documentOpen` events across.
    @Test("With logging off, opening a document records no reading history")
    func documentOpenRecordsNothingWhenLoggingOff() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(false)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        makeViewModel().recordReadingHistory(projectId: UUID(),
                                             in: context,
                                             defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<ReadingHistoryEntry>()).isEmpty)
    }

    /// The control. Without it the test above would pass just as happily if the writer were broken
    /// outright, which is the failure mode a gate test is most likely to hide.
    @Test("With logging on, opening a document records reading history")
    func documentOpenRecordsWhenLoggingOn() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let projectId = UUID()

        makeViewModel(documentId: "d42").recordReadingHistory(projectId: projectId,
                                                              in: context,
                                                              defaults: scratch.store)

        let visits = try context.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(visits.count == 1)
        #expect(visits.first?.documentId == "d42")
        #expect(visits.first?.projectId == projectId)
    }

    /// Absent the preference entirely — a fresh install — recording still happens. Pins the
    /// default the same way the gate test does, but through the writer rather than the helper.
    @Test("With no preference set, opening a document still records")
    func documentOpenRecordsWhenPreferenceAbsent() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        makeViewModel().recordReadingHistory(projectId: nil, in: context, defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<ReadingHistoryEntry>()).count == 1)
    }

    // MARK: - Collection export (the Wave R-2a producer)

    /// The third writer. Exports are the one event kind the contract keeps (D1), because nothing
    /// else records that a collection left the app — and the Zotero Web-API push really does put
    /// items in the user's library. An ungated writer here would have been a fourth recorder the
    /// switch does not govern, which is the defect this whole wave exists for.
    @Test("With logging off, a completed export records nothing")
    func exportRecordsNothingWhenLoggingOff() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(false)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let wrote = ExportHistoryRecorder.record(format: "pdf",
                                                 documentCount: 12,
                                                 collectionName: "Détente",
                                                 projectId: UUID(),
                                                 in: context,
                                                 defaults: scratch.store)

        #expect(wrote == false)
        #expect(try context.fetch(FetchDescriptor<ExportHistoryEntry>()).isEmpty)
    }

    /// The control, and the shape of the record: format, count, collection name, project.
    @Test("With logging on, a completed export records format, count, name and project")
    func exportRecordsEverythingWhenLoggingOn() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let projectId = UUID()

        let wrote = ExportHistoryRecorder.record(format: "zotero-api",
                                                 documentCount: 7,
                                                 collectionName: "  Détente  ",
                                                 projectId: projectId,
                                                 in: context,
                                                 defaults: scratch.store)

        #expect(wrote)
        let rows = try context.fetch(FetchDescriptor<ExportHistoryEntry>())
        #expect(rows.count == 1)
        #expect(rows.first?.format == "zotero-api")
        #expect(rows.first?.documentCount == 7)
        #expect(rows.first?.collectionName == "Détente", "the name is trimmed")
        #expect(rows.first?.projectId == projectId)
        #expect(rows.first?.exportedAt != nil)
    }

    /// An unnamed collection stores `nil` rather than an empty string, so the session log falls
    /// back to the format instead of drawing "Exported  — 3 documents".
    @Test("A blank collection name is stored as nil")
    func blankExportNameIsNil() throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        ExportHistoryRecorder.record(format: "pdf", documentCount: 3, collectionName: "   ",
                                     projectId: nil, in: context, defaults: scratch.store)

        #expect(try context.fetch(FetchDescriptor<ExportHistoryEntry>())
            .first?.collectionName == nil)
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
    /// `SearchHistoryWriter.Anchor` exists. `SearchView` re-runs `search()` for the **same** query
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

    /// The other half of that rule, and the M-2 fix (commit 5).
    ///
    /// Staying at one row is only half right. Since #613 the row also carries the **scope** it ran
    /// under, and the old writer skipped a re-run outright — which froze the scope at whatever the
    /// first run used. A researcher who searched, then narrowed to twelve volumes, then read the
    /// method appendix would find a corpus-wide scope printed against a search that ran over
    /// twelve. The appendix would be stating a method that was not used, which is the precise
    /// defect M-2 exists to remove.
    @Test("A scope-only re-run refreshes the row rather than freezing its scope")
    func scopeOnlyRerunRefreshesTheRow() async throws {
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
        let wide = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        let wideSignature = try #require(wide.scopeSignature)
        let wideRunAt = try #require(wide.executedAt)

        vm.selectedVolumeIds = ["frus1969-76v01"]
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)

        let rows = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(rows.count == 1, "still one row — a filter tap is not a search the researcher ran")
        let narrowed = try #require(rows.first)
        #expect(narrowed.id == wide.id, "it must be the SAME row, brought up to date")
        #expect(narrowed.scopeSignature != wideSignature,
                "the row still claims the scope of a run it no longer describes")
        #expect(try #require(narrowed.executedAt) >= wideRunAt,
                "a refreshed row is dated by the run it describes")
    }

    /// A genuine later re-run — after other queries in between — is a new row. Only *consecutive*
    /// re-runs collapse, because only those are the same search being adjusted.
    @Test("The same query after another query is a new row")
    func returningToAQueryStartsANewRow() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.destroy() }
        scratch.setLogging(true)

        let harness = try await SearchHarness.make()
        defer { harness.destroy() }

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let vm = harness.viewModel

        for query in ["détente", "telegram", "détente"] {
            vm.keywords = query
            await vm.search()
            vm.recordSearchHistory(projectId: nil, in: context, defaults: scratch.store)
        }
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 3)
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
    /// position. Placement matters — the function mutates the caller's anchor on the way
    /// through, and a gate placed after that mutation would silently swallow the first query the
    /// user runs after switching logging back on.
    ///
    /// Now one writer for both platforms (M-2). The audit moved with it, and gained a second
    /// assertion the two-copy version could not make: that neither view model can still reach the
    /// initialiser on its own, which is how the gate would come back apart.
    @Test("The shared history writer checks the gate before writing")
    func sharedWriterChecksTheGateBeforeWriting() throws {
        let url = Self.sourceRoot.appendingPathComponent("Search/SearchHistoryWriter.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let signature = "static func record("
        let insert = "context.insert(record)"
        let signatureRange = try #require(source.range(of: signature),
                                          "SearchHistoryWriter.record has been renamed or removed")
        let insertRange = try #require(source.range(of: insert, range: signatureRange.upperBound..<source.endIndex),
                                       "SearchHistoryWriter.record no longer inserts a record")

        let body = source[signatureRange.upperBound..<insertRange.lowerBound]
        #expect(body.contains("AppState.isResearchLoggingEnabled(in: defaults)"),
                """
                SearchHistoryWriter.record must consult the research-logging gate before \
                writing a SearchHistoryEntry (Wave R-1)
                """)
        // The gate is checked before the ANCHOR moves, too: a gate placed after that mutation
        // would silently swallow the first query the user runs after switching logging back on.
        let anchorRange = try #require(source.range(of: "anchor = Anchor(",
                                                    range: signatureRange.upperBound..<source.endIndex))
        #expect(source[signatureRange.upperBound..<anchorRange.lowerBound]
            .contains("AppState.isResearchLoggingEnabled(in: defaults)"))

        // And a refresh is gated too — it is a write, and it moves `executedAt`.
        let refreshRange = try #require(source.range(of: "row.scopeSignature = signature",
                                                     range: signatureRange.upperBound..<source.endIndex))
        #expect(source[signatureRange.upperBound..<refreshRange.lowerBound]
            .contains("AppState.isResearchLoggingEnabled(in: defaults)"),
                "the refresh path must be behind the same gate as the insert")
    }

    /// No further writer has appeared without a gate.
    ///
    /// Scans every app source file for `ReadingHistoryEntry(` / `SearchHistoryEntry(` /
    /// `ExportHistoryEntry(` construction and asserts the producing files are exactly the known
    /// ones. R-4's iOS search-history writer — the candidate this guard was written for — was the
    /// third; R-2a's export recorder is the fourth, and both are gated. A fifth fails this test
    /// until it is listed here, which is the moment to check that it consults the gate.
    ///
    /// The list carries one deliberate non-writer: `ResearchTrailMigration`, which constructs both
    /// migrated types and must **not** be gated. The comment beside it is the record of that
    /// decision, which is the point of asserting on an exact set rather than a lower bound.
    @Test("Every producer of a history entry is a known, gated writer")
    func noUngatedHistoryWriterExists() throws {
        let expected: Set<String> = [
            "DocumentViewModel.swift",   // ReadingHistoryEntry — gated
            // SearchHistoryEntry — one gated writer for BOTH platforms since M-2. It used to be
            // two (`MacSearchViewModel` and `SearchViewModel`), which is how #612 shipped a synced
            // trail whose platforms recorded different counts for the same query.
            "SearchHistoryWriter.swift",
            // ExportHistoryEntry — gated inside `ExportHistoryRecorder` (Wave R-2a). The four
            // `ExportSheetView` call sites route through that recorder precisely so the gate is
            // written once rather than copied four times into a view.
            "ExportHistoryEntry.swift",
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
                if trimmed.contains("ReadingHistoryEntry(")
                    || trimmed.contains("SearchHistoryEntry(")
                    || trimmed.contains("ExportHistoryEntry(") {
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

        // And the view model delegates to the shared writer, which is where the gate now lives
        // (see `sharedWriterChecksTheGateBeforeWriting`). Asserting delegation rather than a local
        // gate is the point: a second gate here would be a second thing to get wrong.
        let vmURL = Self.sourceRoot.appendingPathComponent("Search/SearchViewModel.swift")
        let vmSource = try String(contentsOf: vmURL, encoding: .utf8)
        let signatureRange = try #require(vmSource.range(of: "func recordSearchHistory("),
                                          "SearchViewModel.recordSearchHistory is missing")
        #expect(vmSource[signatureRange.upperBound...].prefix(2_000)
            .contains("SearchHistoryWriter.record("),
                """
                SearchViewModel.recordSearchHistory must delegate to SearchHistoryWriter \
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

// MARK: - TrailCountParityTests

/// What the two platforms write into the one synced trail.
///
/// `SearchHistoryEntry.resultCount` is a number a researcher may later cite, and the trail syncs —
/// so a project's log holds whatever every device wrote. macOS has recorded
/// `totalMatchCount ?? results.count` since Q-M2, naming this iOS catch-up as M-2's; iOS recorded
/// the FETCHED count, capped at `searchHardLimit`. A query matching 195,519 documents was logged
/// as "1,000" on iPhone and 195,519 on Mac, in the same trail, for the same query.
///
/// Version history:
///   1.0 — M-2 commit 1: initial implementation
@Suite("Trail count parity")
struct TrailCountParityTests {

    /// The rule both platforms now apply, extracted so it can be checked without a search service.
    /// Mirrors `resultCountForDisplay` on macOS and the expression in `recordSearchHistory` on iOS.
    private func recorded(total: Int?, fetched: Int) -> Int { total ?? fetched }

    @Test("A known total is what gets recorded, not the capped fetch")
    func totalWins() {
        // The iPhone case that motivated this: 1,000 fetched of 195,519 matching.
        #expect(recorded(total: 195_519, fetched: 1_000) == 195_519)
    }

    @Test("Without a total, the honest fallback is what was actually seen")
    func fallbackIsTheFetch() {
        // NOT the fetch cap. Before Q-M2 macOS wrote exactly the cap here, which reads as a
        // measured figure rather than a floor.
        #expect(recorded(total: nil, fetched: 412) == 412)
        #expect(recorded(total: nil, fetched: 1_000) == 1_000)
    }

    @Test("A complete small search is unaffected")
    func smallSearchUnchanged() {
        #expect(recorded(total: 412, fetched: 412) == 412)
    }

    /// Source parity: both platforms must apply the same rule, or the trail disagrees with itself.
    ///
    /// The guarantee got stronger in M-2 commit 5. It used to be textual — two writers asserted to
    /// spell the same thing — and now there is one writer, so what is checked is that both view
    /// models still feed it and neither has grown a second path to the initialiser. That is what
    /// `noUngatedHistoryWriterExists` enforces from the other side.
    @Test("Both platforms record the total when they have one, through one writer")
    func bothWritersAgree() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let iOS = try String(contentsOf: root.appending(path: "FRUSExplorer/Search/SearchViewModel.swift"),
                             encoding: .utf8)
        let mac = try String(contentsOf: root.appending(path: "FRUSExplorer/App/MacSearchViewModel.swift"),
                             encoding: .utf8)
        #expect(iOS.contains("resultCount: totalMatchCount ?? results.count"))
        // macOS reaches the same value through `resultCountForDisplay`, which is defined as
        // `totalMatchCount ?? results.count`.
        #expect(mac.contains("resultCount: resultCountForDisplay"))
        #expect(mac.contains("var resultCountForDisplay: Int { totalMatchCount ?? results.count }"))
        // Both go through the shared writer, and neither constructs an entry itself.
        for (name, source) in [("iOS", iOS), ("macOS", mac)] {
            #expect(source.contains("SearchHistoryWriter.record("), "\(name) stopped delegating")
            #expect(!source.contains("SearchHistoryEntry("),
                    "\(name) grew a second path to the initialiser, which is how the two drift")
        }
        // Neither may go back to logging the raw fetch as the hit count.
        #expect(!iOS.contains("resultCount: results.count"))
        #expect(!mac.contains("resultCount: results.count"))
    }
}
