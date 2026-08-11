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

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ArchivalLibraryQueryTests

/// The two whole-library queries behind Your Library (#765 rider E), driven through the real
/// indexer rather than hand-inserted rows — the column values they group on are written by
/// `baseDocumentSourceRow` from a parsed source note, and a fixture that inserts its own rows
/// would pass while the parser wrote something else entirely.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — whole-library queries")
struct ArchivalLibraryQueryTests {

    // MARK: - Fixtures

    private func writeVolume(_ volumeId: String, sourceNotes: [(id: String, note: String)],
                             to directory: URL) throws {
        let divs = sourceNotes.map { document in
            """
            <div type="document" xml:id="\(document.id)"><head>\(document.id)</head>
            <note type="source">\(document.note)</note>
            <p>Body text.</p></div>
            """
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>2003</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">
        \(divs)
          </div></body></text>
        </TEI>
        """
        try Data(xml.utf8).write(to: directory.appendingPathComponent("\(volumeId).xml"))
    }

    private func withIndex(
        _ volumes: [(id: String, notes: [(id: String, note: String)])],
        _ body: (IndexingPipeline) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("archival-library-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volumesDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumesDir, withIntermediateDirectories: true)
        for volume in volumes {
            try writeVolume(volume.id, sourceNotes: volume.notes, to: volumesDir)
        }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumesDir, concurrencyLimit: 2)
        for volume in volumes { try await pipeline.indexVolume(volume.id) }
        try await body(pipeline)
    }

    // MARK: - Tests

    @Test("Groups carry one row per source note, keyed by volume, citation form, and repository")
    func groupsCoverEveryNote() async throws {
        try await withIndex([
            (id: "frus1958-60v01", notes: [
                (id: "d1", note: "Source: Department of State, Central Files, 611.51/1-1558."),
                (id: "d2", note: "Source: Department of State, Central Files, 611.51/2-1758."),
                (id: "d3", note: "Source: Department of State, Conference Files: Lot 60 D 627, CF 1."),
                (id: "d4", note: "Source: Eisenhower Library, Whitman File, Dulles-Herter Series."),
            ]),
            (id: "frus1969-76v01", notes: [
                (id: "d1", note: "Source: National Archives, RG 59, Central Files 1970–73, POL 27."),
                // Deliberately the SAME citation form and repository as the early volume's first
                // two notes. Without a form shared across volumes, a query that dropped
                // `volume_id` from its GROUP BY would still return the right per-volume answers
                // by accident — the first version of this fixture did exactly that, and the
                // mutation sweep caught it rather than the test.
                (id: "d2", note: "Source: Department of State, Central Files, 611.51/3-1071."),
            ]),
        ]) { pipeline in
            let groups = try await pipeline.archivalLibraryGroups()
            let total = groups.reduce(0) { $0 + $1.documentCount }
            #expect(total == 6, "the six source notes produced \(total) counted documents")
            #expect(Set(groups.map(\.volumeId)) == ["frus1958-60v01", "frus1969-76v01"])

            // The grain is per volume: the shared decimal form must stay split 2 / 1, not
            // collapse into one row of 3 attributed to whichever volume the database picked.
            let decimalByVolume = Dictionary(
                grouping: groups.filter { $0.citationEra == "decimal" },
                by: \.volumeId).mapValues { $0.reduce(0) { $0 + $1.documentCount } }
            #expect(decimalByVolume == ["frus1958-60v01": 2, "frus1969-76v01": 1], """
                Decimal notes came back as \(decimalByVolume). Both volumes cite the central files \
                through the same form, so a query grouping only by form would attribute one \
                volume's documents to the other — and every era chart is built on that split.
                """)

            // The two decimal notes are one group; the lot and library notes are their own.
            let early = groups.filter { $0.volumeId == "frus1958-60v01" }
            let byCategory = Dictionary(
                grouping: early,
                by: { SourceProvenanceCategory.from(citationEra: $0.citationEra,
                                                    repository: $0.repository) })
                .mapValues { $0.reduce(0) { $0 + $1.documentCount } }
            #expect(byCategory[.centralDecimalFile] == 2)
            #expect(byCategory[.lotFile] == 1)
            #expect(byCategory[.presidentialLibrary] == 1, """
                The Eisenhower Library note landed in \(byCategory). It is written with \
                citation_era "structured", which it shares with NARA and CIA citations — the \
                repository is what separates them.
                """)
        }
    }

    @Test("The collection query excludes the central-file forms and keeps the rest")
    func collectionGroupsExcludeCentralFiles() async throws {
        try await withIndex([
            (id: "frus1958-60v01", notes: [
                // A decimal citation: its series_name is a file identifier, not a collection.
                (id: "d1", note: "Source: Department of State, Central Files, 611.51/1-1558."),
                (id: "d2", note: "Source: Department of State, Conference Files: Lot 60 D 627, CF 1."),
                (id: "d3", note: "Source: Eisenhower Library, Whitman File, Dulles-Herter Series."),
            ]),
        ]) { pipeline in
            let all = try await pipeline.archivalLibraryGroups()
            let collections = try await pipeline.archivalLibraryCollectionGroups()
            #expect(all.reduce(0) { $0 + $1.documentCount } == 3)
            #expect(collections.reduce(0) { $0 + $1.documentCount } == 2, """
                The collection query returned \
                \(collections.reduce(0) { $0 + $1.documentCount }) documents. The decimal \
                citation must be excluded: grouping on a file identifier such as 611.51/1-1558 \
                produces one-document groups that resolve to nothing.
                """)
            #expect(collections.contains { $0.lotFileNorm == "60D627" }, """
                The lot group is missing its canonical key: \
                \(collections.map { $0.lotFileNorm ?? "nil" }). Without it nothing resolves by \
                lot, which is the first step of the authority lookup.
                """)
            #expect(collections.contains { $0.repository == "Eisenhower Library" })
        }
    }

    @Test("The library total is source notes, never documents")
    func documentsWithoutNotesAreNotCounted() async throws {
        // The distinction the intro line and the footer both rest on: an indexed document with
        // no source note contributes no row, so this total is always smaller than the document
        // count, and calling it a document total would overstate the library.
        try await withIndex([
            (id: "frus1958-60v01", notes: [
                (id: "d1", note: "Source: Department of State, Central Files, 611.51/1-1558."),
            ]),
        ]) { pipeline in
            let groups = try await pipeline.archivalLibraryGroups()
            #expect(groups.reduce(0) { $0 + $1.documentCount } == 1)

            let profile = ArchivalLibraryProfile.make(
                groups: groups,
                collectionGroups: try await pipeline.archivalLibraryCollectionGroups(),
                coverage: ["frus1958-60v01": ArchivalVolumeCoverage(firstYear: 1958,
                                                                    lastYear: 1960)],
                authority: CollectionAuthorityStore.shared)
            #expect(profile.noteCount == 1)
            #expect(profile.volumeCount == 1)
            #expect(profile.centralFileNoteCount == 1)
            #expect(profile.bands.map(\.band.index) == [1],
                    "a 1958–1960 volume belongs to the 1948–1960 band")
        }
    }
}

// MARK: - ArchivalAnalyticsEntryPointTests

/// The surface is reachable on both platforms (#765).
///
/// A view nobody can open is the failure mode this project has shipped before — #363's
/// unreachable pane, #338's dropped sheets. These read the source rather than driving the UI,
/// which is weaker than a UI test but strong enough to catch a deleted menu row or a window
/// scene that was never registered.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — entry points")
struct ArchivalAnalyticsEntryPointTests {

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The iOS Analysis Tools menu offers it, presents it, and names it in its help")
    func iOSEntryPoint() throws {
        let source = try Self.source("Browser/BrowserView.swift")
        // #833 moved the presentation to the tab shell. The row and the presenter are now in
        // different files, so this test spans both — the property it protects is unchanged and is
        // the #363 unreachable-pane shape: a row that sets state nothing presents.
        #expect(source.contains("appState.openArchivalScope(.unscoped, from: sceneID)"),
                "the Analysis Tools menu has no row that opens Archival Analytics")
        let shell = try Self.source("App/MainTabView.swift")
        #expect(shell.contains(".sheet(item: $presentedArchivalScope)"),
                "the row produces a hand-off nothing presents — the #363 unreachable-pane shape")
        #expect(shell.contains("ArchivalAnalyticsView(initialScope:"))
        // R-8: the iPadOS toolbar-overflow row re-derives its name from the label closure, so a
        // bare Image would ship an unnamed item.
        #expect(source.contains("browse.archivalAnalytics.a11y"),
                "the menu row needs a named Label, not a bare icon")
        #expect(source.contains("browse.analysisTools.help.v2"),
                "the Analysis Tools help string enumerates the tools by name and must list this one")
    }

    @Test("The macOS window scene exists and the Analytics menu fronts it")
    func macOSEntryPoint() throws {
        let source = try Self.source("App/FRUSExplorerApp.swift")
        #expect(source.contains("id: \"frus.archivalAnalytics\""),
                "no Window scene is registered for the archival analytics window")
        #expect(source.contains("openWindow.fronting(id: \"frus.archivalAnalytics\")"), """
            The Analytics menu item must use the fronting helper (#749): plain openWindow(id:) \
            re-opens a buried window without raising it, so the menu item appears to do nothing.
            """)
        #expect(source.contains("appState.bindTool(.archivalAnalytics, to: nil)"), """
            An explicit launch must clear stale provenance, like its four siblings — otherwise a \
            closed host keeps capturing this window's document opens.
            """)
    }

    @Test("The main window's toolbar Analytics menu offers it too")
    func macOSToolbarEntryPoint() throws {
        // A SECOND file, deliberately. `macOSEntryPoint` reads FRUSExplorerApp.swift, where the
        // menu-bar item has always lived — which is exactly why it passed for the whole of #795
        // while the toolbar menu, the door a reader actually finds, had no row at all.
        let source = try Self.source("App/MainWindowView.swift")
        #expect(source.contains("openWindow.fronting(id: \"frus.archivalAnalytics\")"), """
            The toolbar Analytics menu lists every other analytics window and must list this one \
            (#795). The menu-bar assertion above cannot see this file.
            """)
        #expect(source.contains("appState.bindTool(.archivalAnalytics, to: hostID)"), """
            A toolbar launch binds THIS window as provenance (hostID), unlike the menu-bar item, \
            which clears it — a menu-bar launch has no spawning window to inherit.
            """)
    }

    @Test("The SA-3 dashboard points at it")
    func seriesDashboardCrossLink() throws {
        // The #765 D-1 rider: the provenance dashboard's ten categories are the coarse view of
        // what Archival Analytics names collection by collection.
        let source = try Self.source("SeriesAnalytics/SourceProvenanceDashboard.swift")
        #expect(source.contains("openWindow.fronting(id: \"frus.archivalAnalytics\")"),
                "the SA-3 dashboard has no cross-link into Archival Analytics (#795)")
        #expect(source.contains("series.provenance.archivalLink"),
                "the cross-link needs a named, localized label")
    }
}
