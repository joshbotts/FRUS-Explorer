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
@testable import FRUSExplorer

/// A collection is a list of documents, so it must be able to open one (#755).
///
/// ## The gap
/// Collections was the **only** document list in the app with no route into the reader. A
/// module-wide grep found no `openDocument`, `openBrowseDocument`, `DocumentView` or
/// `pendingBrowse*` reference anywhere in `FRUSExplorer/Collections/` — while search, history,
/// chronology, research, the graph, related documents and archival neighbours all open it.
///
/// So a researcher reviewing documents *they had deliberately curated* had to remember each one's
/// volume and re-find it through Browse or Search. On macOS the single "open" control on a row
/// launched **history.state.gov in a web browser** — the published text, without the notes,
/// highlights and cross-references the app exists to provide.
///
/// ## And a consumer with no producer
/// `CollectionListView.consumePendingCollectionSelection` has existed since #369 BUG-12, wired to
/// both `.task` and `.onChange`, documented as pushing "the imported collection's editor so the user
/// lands on it after an open-with import". The only writer of that slot in the entire codebase was
/// the **macOS** branch of `surfaceOpenedCollection`, so on iOS it could never fire: the collection
/// imported correctly and the user then had to find it by name (M-24).
///
/// Version history:
///   1.0 — Session 2026-08-08: #755 (audit M-18, M-19, M-24)
@Suite("Collections reader route")
struct CollectionsReaderRouteTests {

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

    private static func functionBody(_ name: String, in source: String, limit: Int = 1_200) throws -> String {
        let start = try #require(source.range(of: name), "\(name) not found — moved or renamed?")
        return String(source[start.lowerBound...].prefix(limit))
    }

    // MARK: - The helper earns its trust

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        // Directly relevant here: these files now discuss `openDocument` in comments at length, and
        // a raw `contains` would be satisfied by the prose rather than the call — the failure mode
        // #754's mutation M4 exposed in a guard of mine.
        let sample = """
            // openDocument was missing from this module entirely
            /// openDocument again, in a doc comment
            appState.openDocument(entry, from: .global, using: openWindow)
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text.hasPrefix("appState.openDocument") == true)
    }

    // MARK: - M-18 / M-19: the module can reach the reader

    @Test("The Collections module has a real route into the reader on both platforms")
    func moduleReachesTheReader() throws {
        // iOS: the scene-addressed hand-off, like every other iOS list.
        let editor = Self.codeLines(try Self.source("Collections/CollectionEditorView.swift"))
        #expect(editor.contains { $0.text.contains("appState.openBrowseDocument(browseEntry, from: sceneID)") }, """
            CollectionEditorView must hand the document to the Browse tab on iOS (#755 / M-18). The \
            whole Collections module previously contained no such call — it was the only document \
            list in the app with no way to open one.
            """)
        #expect(editor.contains { $0.text.contains("appState.openTab(.browse, from: sceneID)") },
                "…and bring the Browse tab forward, or the hand-off lands out of sight")

        // macOS: the provenance chain, which mints a window when no host is live.
        let mac = Self.codeLines(try Self.source("Collections/MacCollectionManagerView.swift"))
        #expect(mac.contains { $0.text.contains("appState.openDocument(") }, """
            MacCollectionManagerView must route through appState.openDocument (#755 / M-19). Its \
            only per-entry open launched history.state.gov in a web browser.
            """)
        #expect(mac.contains { $0.text.contains("using: openWindow") },
                "…with the mint tail, so an open never silently does nothing")
    }

    @Test("The external history.state.gov link survives — it is a different destination")
    func externalLinkIsNotReplaced() throws {
        // The fix ADDS the in-app reader; it must not remove the published-text link. Deleting it
        // would be a way to satisfy "Collections can open a document" while taking something away.
        let mac = try Self.source("Collections/MacCollectionManagerView.swift")
        #expect(mac.contains("history.state.gov/historicaldocuments"),
                "the external link must remain alongside the in-app open (#755)")
    }

    @Test("The row's existing tap behaviour is unchanged")
    func rowTapStillOpensTheInspector() throws {
        // Researchers have configured entries by tapping the row since Composer v2 §D. The reader
        // route is an ADDITION (long-press / VoiceOver action / macOS button), not a re-binding of
        // a gesture people rely on.
        let rows = try Self.source("Collections/CollectionEntryRows.swift")
        #expect(rows.contains(".onTapGesture { onInspect() }"),
                "the whole-row tap must still open the configure inspector (#755)")
        #expect(rows.contains("var onOpenDocument: (() -> Void)? = nil"),
                "and the reader route must be a separate, optional action")
    }

    @Test("The iOS row exposes the open action to VoiceOver, not only to long-press")
    func openIsAccessible() throws {
        // A context menu alone is not reachable by VoiceOver, which would make the app's only route
        // from a collection to the reader inaccessible — worse than the gap it replaces.
        let rows = try Self.source("Collections/CollectionEntryRows.swift")
        #expect(rows.contains("accessibilityAction(named:"),
                "the open action must be exposed as a VoiceOver action (#755)")
    }

    @Test("Both openers build the entry from the collection row, not a placeholder")
    func openersCarryTheRealDocument() throws {
        for (relative, function) in [
            ("Collections/CollectionEditorView.swift", "private func openInReader(_ entry: CollectionEntry)"),
            ("Collections/MacCollectionManagerView.swift", "private func openInReader(_ entry: CollectionEntry)")
        ] {
            let body = try Self.functionBody(function, in: try Self.source(relative), limit: 900)
            #expect(body.contains("entry.documentId") && body.contains("entry.volumeId"), """
                \(relative)'s opener must use the entry's own ids (#755) — a hard-coded or empty \
                target would open the wrong document, or none.
                """)
        }
    }

    // MARK: - M-24: the import hand-off has a producer on iOS

    @Test("An imported collection is selected on iOS, not just switched to")
    func importSelectsOnIOS() throws {
        let source = try Self.source("App/FRUSExplorerApp.swift")
        let body = try Self.functionBody("private func surfaceOpenedCollection(_ id: UUID)",
                                         in: source, limit: 1_400)

        // The iOS branch is everything before the #else.
        let iosBranch = String(body.prefix(body.range(of: "#else")?.lowerBound.utf16Offset(in: body)
                                           ?? body.count))
        #expect(iosBranch.contains("appState.pendingCollectionSelection = id"), """
            The iOS branch must write pendingCollectionSelection (#755 / M-24). \
            CollectionListView has consumed that slot since #369 BUG-12 — .task and .onChange, \
            documented as pushing the imported collection's editor — but the ONLY writer in the \
            codebase was the macOS branch, so the iOS consumer could never fire.
            """)
    }

    @Test("The hand-off is set before the tab switch, matching the macOS ordering")
    func handoffPrecedesTheTabSwitch() throws {
        // Same reason macOS sets it before openWindow: a freshly created consumer's `.task` has to
        // see it. Set it after and the drain races the value.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        let body = try Self.functionBody("private func surfaceOpenedCollection(_ id: UUID)",
                                         in: source, limit: 1_400)
        let set = try #require(body.range(of: "appState.pendingCollectionSelection = id"))
        let switchTab = try #require(body.range(of: "appState.openTab(.collections"))
        #expect(set.lowerBound < switchTab.lowerBound,
                "set the selection hand-off before switching tabs (#755 / M-24)")
    }

    @Test("The iOS consumer that was dead is still wired")
    func consumerStillWired() throws {
        // Guards the other half: a producer with no consumer is the same bug facing the other way.
        let source = try Self.source("Collections/CollectionListView.swift")
        #expect(source.contains("consumePendingCollectionSelection"),
                "CollectionListView must still consume the hand-off (#369 BUG-12 / #755)")
    }
}
