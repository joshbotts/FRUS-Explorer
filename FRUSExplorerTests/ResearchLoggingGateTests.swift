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

    /// No fourth writer has appeared without a gate.
    ///
    /// Scans every app source file for `ReadingHistoryEntry(` / `SearchHistoryEntry(`
    /// construction and asserts the producing files are exactly the two gated ones. Adding a
    /// third producer — R-4's planned iOS search-history writer is the obvious candidate — fails
    /// this test until it is listed here, which is the moment to check it consults the gate.
    @Test("Every producer of a history entry is a known, gated writer")
    func noUngatedHistoryWriterExists() throws {
        let expected: Set<String> = [
            "DocumentViewModel.swift",   // ReadingHistoryEntry — gated
            "MacSearchViewModel.swift",  // SearchHistoryEntry  — gated
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
