// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

/// A relaunch gives the researcher their document back, and never lies about the rest (#754).
///
/// ## The decision this encodes
/// The app's entire restoration surface was three `@SceneStorage` keys — the selected tab and two
/// inspector toggles. No navigation, search or reading state survived a relaunch, and iOS terminates
/// backgrounded apps routinely (audit H-6). The owner's decision was **resume reading, offered**:
/// restore the *document*, not the ladder climbed to reach it, from the `ReadingHistoryEntry` trail
/// the app already writes and syncs.
///
/// That choice beats encoding navigation paths into `@SceneStorage` on three counts — it survives a
/// reinstall, it works on a second device, and a volume removed since the last read is a row to
/// filter rather than a restored path that dead-ends at launch.
///
/// And the second half: `search.facets.shown` **did** survive, while the query and results it
/// describes did not, so the Search window could reopen with the facet inspector extended over
/// nothing (L-45). Restoring only the half that is cheap to restore is worse than restoring
/// neither, because the surviving half asserts the other one exists.
///
/// Version history:
///   1.0 — Session 2026-08-08: #754 (audit H-6, L-45)
@Suite("Resume reading")
struct ResumeReadingTests {

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func codeLines(_ source: String) -> [(line: Int, text: String)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.hasPrefix("//") && !$0.text.hasPrefix("///") && !$0.text.hasPrefix("*") }
    }

    // MARK: - The helper earns its trust

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // @SceneStorage was the old spelling
            /// @SceneStorage again, in prose
            @State private var showFacetPanel = false
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text.hasPrefix("@State") == true)
    }

    // MARK: - The resume rule, exercised against a real store

    /// The selection rule the row applies: newest read whose volume is still indexed.
    ///
    /// Expressed here as the same predicate the view uses, driven against a real `ModelContainer`,
    /// so this is a behavioural test rather than another source read.
    private func resumable(from history: [ReadingHistoryEntry],
                           indexed: Set<String>) -> ReadingHistoryEntry? {
        history.first { indexed.contains($0.volumeId) }
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Schema(ModelContainer.frusModelTypes), configurations: config)
    }

    private func history(in context: ModelContext) throws -> [ReadingHistoryEntry] {
        try context.fetch(FetchDescriptor<ReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)]))
    }

    @Test("The newest read wins")
    @MainActor
    func newestReadWins() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let older = ReadingHistoryEntry(documentId: "d1", volumeId: "v1")
        older.accessedAt = Date(timeIntervalSince1970: 1_000)
        let newer = ReadingHistoryEntry(documentId: "d2", volumeId: "v2")
        newer.accessedAt = Date(timeIntervalSince1970: 2_000)
        context.insert(older); context.insert(newer)
        try context.save()

        let pick = resumable(from: try history(in: context), indexed: ["v1", "v2"])
        #expect(pick?.documentId == "d2")
    }

    @Test("A read whose volume was removed is skipped, not offered")
    @MainActor
    func removedVolumeIsSkipped() throws {
        // The whole reason this beats path-encoding: a stale target is a row to filter, not a
        // restored navigation path that dead-ends at launch.
        let container = try makeContainer()
        let context = container.mainContext
        let stale = ReadingHistoryEntry(documentId: "d9", volumeId: "removed")
        stale.accessedAt = Date(timeIntervalSince1970: 3_000)
        let live = ReadingHistoryEntry(documentId: "d8", volumeId: "kept")
        live.accessedAt = Date(timeIntervalSince1970: 2_000)
        context.insert(stale); context.insert(live)
        try context.save()

        let pick = resumable(from: try history(in: context), indexed: ["kept"])
        #expect(pick?.documentId == "d8", "the newest READABLE entry wins, not the newest entry")
    }

    @Test("Nothing is offered when no read targets an indexed volume")
    @MainActor
    func nothingToResume() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stale = ReadingHistoryEntry(documentId: "d1", volumeId: "gone")
        stale.accessedAt = Date(timeIntervalSince1970: 1_000)
        context.insert(stale)
        try context.save()

        #expect(resumable(from: try history(in: context), indexed: ["other"]) == nil,
                "an offer that opens an empty reader is worse than no offer")
    }

    // MARK: - Wiring

    @Test("The row applies the indexed-volume filter and waits for boot")
    func rowFiltersAndWaits() throws {
        let source = try Self.source("Browser/ResumeReadingRow.swift")
        #expect(source.contains("appState.indexedVolumeIds.contains"), """
            The row must filter on indexedVolumeIds, or it offers documents whose volume was \
            removed and opens an empty reader (#754).
            """)
        #expect(source.contains("appState.isBootComplete"), """
            It must also wait for boot: indexedVolumeIds is populated during startup, so an early \
            render would filter every entry out and hide a real offer (#753's signal, reused).
            """)
    }

    @Test("Nothing auto-opens — the row is a Button the user taps")
    func nothingAutoOpens() throws {
        // The owner's decision was "offered, never forced". An .onAppear that navigated would make
        // the first frame depend on history the user may have moved on from, with no way to decline.
        let source = try Self.source("Browser/ResumeReadingRow.swift")
        let autoNavigation = Self.codeLines(source).filter {
            ($0.text.contains(".onAppear") || $0.text.contains(".task")) && !$0.text.contains("//")
        }
        #expect(autoNavigation.isEmpty, """
            ResumeReadingRow must not navigate on appear (#754): the offer is a Button. Found: \
            \(autoNavigation.map(\.text).joined(separator: " | ")).
            """)
        #expect(source.contains("onResume("), "the row must hand its entry to the host to open")
    }

    @Test("Both platforms offer it")
    func bothPlatformsOfferResume() throws {
        // codeLines, not `contains` on the raw source: the call site carries a comment that NAMES
        // ResumeReadingRow, so a raw `contains` passed with the call itself deleted (measured —
        // mutation M4 survived). Same trap as #752's M8: prose satisfying a code assertion.
        for (relative, why) in [("Browser/CorpusView.swift", "the iOS Browse root"),
                                ("App/MainWindowView.swift", "the macOS placeholder")] {
            let calls = Self.codeLines(try Self.source(relative))
                .filter { $0.text.contains("ResumeReadingRow") }
            #expect(!calls.isEmpty, "\(why) must offer resume-reading (#754 / H-6)")
        }
    }

    @Test("Dismissing the offer sticks for the session")
    func dismissalSticks() throws {
        // An offer has to be refusable, and a refusal that the next render undoes is not one.
        let source = try Self.source("Browser/ResumeReadingRow.swift")
        #expect(source.contains("guard !dismissed"), """
            The resumable lookup must respect `dismissed` (#754). Without it the row reappears             immediately after the user swipes it away, which makes the dismiss control a lie.
            """)
        #expect(source.contains("dismissed = true"),
                "and the Dismiss action must actually set it")
    }

    // MARK: - L-45: no half-restore

    @Test("The Search UI flags that describe a reset search are no longer persisted")
    func searchFlagsNoLongerPersist() throws {
        for relative in ["App/SearchSheet.swift", "Search/SearchView.swift"] {
            let source = try Self.source(relative)
            let persisted = Self.codeLines(source).filter { $0.text.contains("@SceneStorage") }
            #expect(persisted.isEmpty, """
                \(relative) still persists a Search UI flag: \
                \(persisted.map(\.text).joined(separator: " | ")). The query and results it \
                describes are @State and reset on relaunch, so the window reopened with the facet \
                inspector extended over nothing (#754 / L-45).
                """)
        }
    }

    @Test("The selected tab is still restored — the one thing that legitimately persists")
    func selectedTabStillPersists() throws {
        // Guards against over-correcting L-45 into "persist nothing". The tab selection describes
        // no content, so it cannot become incoherent.
        let source = try Self.source("App/MainTabView.swift")
        #expect(source.contains("@SceneStorage(\"frus.selectedTab\")"),
                "frus.selectedTab must keep restoring (#316) — it describes no content")
    }
}
