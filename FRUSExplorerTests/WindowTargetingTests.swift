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

/// An action taken inside an iPad window must happen in **that** window (#752).
///
/// ## The family
/// `.anyWindow` is a correct *rescue* for a scene-less producer — a Spotlight continuation has no
/// window to name. It is wrong as the destination for something the user just did inside a live
/// window, and the standalone document window turned it into exactly that.
///
/// That window republishes the **launching** window's scene as its own `\.sceneID`
/// (`.auxWindowOrigin`), so rail producers have somewhere to present. Document navigation inherited
/// it too, and nothing in the app calls `requestSceneSessionActivation` — a repo-wide grep returns
/// zero hits — so the consuming window was never brought forward. On a Stage Manager iPad the tap
/// looked like nothing happened while another stage silently changed. When the launcher had closed,
/// or the app had restored the window (which captures no origin at all), the target degraded to
/// `.anyWindow`: some third window, or for the word cloud, **no window at all**.
///
/// ## What the tests pin
/// 1. The standalone window navigates **in place** — it owns a path and a router (H-7, M-30).
/// 2. The word-cloud channel accepts `.anyWindow` like its four siblings, and **consumes** rather
///    than holding the shared slot for its presentation lifetime (H-9, M-31, M-33).
/// 3. Every sheet that can host a reader injects `\.sceneID` (L-39).
///
/// Version history:
///   1.0 — Session 2026-08-08: #752
@Suite("iPad window targeting")
struct WindowTargetingTests {

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

    private static func functionBody(_ name: String, in source: String, limit: Int = 1_400) throws -> String {
        let start = try #require(source.range(of: name), "\(name) not found — moved or renamed?")
        return String(source[start.lowerBound...].prefix(limit))
    }

    // MARK: - The word cloud opens where it was launched (#752 / M-31, second half)

    /// M-31's title is "opens in another window — **or** nowhere at all if the launcher closed."
    /// #769 fixed the second clause: `consumePendingWordCloud` accepts `.anyWindow`, so a closed
    /// launcher no longer black-holes the tap. The **first** clause survived it.
    ///
    /// With the launcher alive — the ordinary Stage Manager case — a standalone document window
    /// republishes the launcher's scene as its own `\.sceneID` (`.auxWindowOrigin`), so the rail's
    /// hand-off addressed that scene and the cloud presented in the *launching* window, which
    /// iPadOS does not raise. Offscreen, the tap looked like it did nothing.
    ///
    /// The cause was structural rather than an OS gap, and that is what these tests pin. Four rail
    /// tools resolve `supportsMultipleWindows ? openAuxWindow : sheet` **locally**, so they open
    /// where they were launched. The word cloud was the only one riding the app-level hand-off,
    /// because it was the only one with no scene of its own.
    @Test("The document rail's word cloud resolves locally, like its four siblings")
    func wordCloudResolvesInTheLaunchingView() throws {
        let source = try Self.source("DocumentView/DocumentView.swift")
        let body = try Self.functionBody("private func openWordCloud()", in: source, limit: 700)

        #expect(body.contains("supportsMultipleWindows"),
                "the word cloud must branch on multi-window like graph/sources/map/related")
        #expect(body.contains("openAuxWindow"), "the multi-window branch must open its own scene")
        #expect(body.contains("activeSheet = .wordCloud"),
                "the single-window branch must present in THIS view, not an ancestor's sheet")

        // The rail tile must route here rather than back to the app-level hand-off. Asserted over
        // CODE ONLY: `functionBody` returns raw text, and the explanatory comment on that case is
        // long enough to fill any sensible character window — the first draft of this test failed
        // because the call it was looking for sat past the end of the slice, behind the prose.
        let tileCode = Self.codeLines(source)
            .drop { !$0.text.hasPrefix("case .wordCloud:") }
            .prefix { !$0.text.hasPrefix("case .sources:") }
            .map(\.text)
            .joined(separator: "\n")
        #expect(tileCode.contains("openWordCloud()"),
                "the rail tile must call the local opener; got: \(tileCode)")
        #expect(!tileCode.contains("appState.openWordCloud"),
                "the document rail must not use the cross-window hand-off — that is the M-31 bug")
    }

    /// The local branch needs somewhere to go. Without an iOS scene, `openAuxWindow` opens nothing
    /// at all — which is why the cloud rode the hand-off in the first place.
    @Test("iOS declares a word-cloud scene for the multi-window branch to open")
    func iOSHasAWordCloudScene() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        let scene = try #require(app.range(of: "WindowGroup(for: WordCloudScope.self)"),
                                 "no iOS word-cloud scene — openAuxWindow would open nothing")
        // It must sit on the iOS side: `frus.wordcloud` is a macOS singleton and serves macOS only.
        let preceding = String(app[..<scene.lowerBound])
        let opens = preceding.components(separatedBy: "#if os(iOS)").count - 1
        let closes = preceding.components(separatedBy: "#if os(macOS)").count - 1
        #expect(opens > closes, "the word-cloud WindowGroup must be declared on the iOS side")
    }

    /// Every other producer — Browser, Search, Collections, Chronology, the volume and subseries
    /// clouds — still routes through the hand-off, and for those the launching window IS the right
    /// destination. Removing it would be a different bug, so the channel must survive this fix.
    @Test("The app-level hand-off survives for the producers that still need it")
    func handOffSurvivesForOtherProducers() throws {
        let appState = try Self.source("App/AppState.swift")
        #expect(appState.contains("func openWordCloud("))
        let mainTab = try Self.source("App/MainTabView.swift")
        #expect(mainTab.contains("consumePendingWordCloud"),
                "MainTabView still presents the hand-off for scene-less and non-document producers")
    }

    // MARK: - The helper earns its trust

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // .anyWindow was the old target
            /// .anyWindow again, in a doc comment
            handoff.target == .anyWindow
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text == "handoff.target == .anyWindow")
    }

    // MARK: - 1. The standalone document window navigates in place (H-7, M-30)

    @Test("The standalone iPad document window owns a navigation path and a router")
    func standaloneWindowNavigatesInPlace() throws {
        let source = try Self.source("App/FRUSExplorerApp.swift")
        #expect(source.contains("struct StandaloneDocumentWindowContent"), """
            The standalone document window must host its own reader. It used to be a bare \
            NavigationStack { DocumentView(entry:) } with no path, so every cross-reference and \
            page-turn was delivered to the LAUNCHING window — which nothing brings forward (#752).
            """)

        let body = try Self.functionBody("struct StandaloneDocumentWindowContent", in: source, limit: 2_600)
        #expect(body.contains("@State private var navigationPath"),
                "it needs a stack of its own to push into")
        // BOTH DocumentViews must route — the root and the pushed destination. `contains` passed
        // with one of them stripped (measured: mutation M1 survived), which would leave every jump
        // after the first still leaving the window.
        let routed = body.components(separatedBy: "onNavigateToDocument: navigate").count - 1
        #expect(routed == 2, """
            \(routed) of the 2 DocumentViews in the standalone window pass a router. The root \
            reader AND the pushed destination both need one, or jumps leave the window (#752).
            """)
        #expect(body.contains("navigationDestination(for: DocumentBrowserEntry.self)"),
                "a pushed entry needs a destination, or the push renders nothing")
    }

    @Test("The standalone window honours push vs replace")
    func standaloneWindowHonoursJumpKind() throws {
        // #751's distinction has to hold here too, or page-turns stack a level per page in the one
        // window with no breadcrumb at all.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        let navigate = try Self.functionBody(
            "private func navigate(_ entry: DocumentBrowserEntry, _ jump: DocumentJump)",
            in: source, limit: 400)
        #expect(navigate.contains("jump == .replace"),
                "a page-turn must replace the reading position in the standalone window too (#751)")
        #expect(navigate.contains("navigationPath.append(entry)"),
                "and every jump must land somewhere")
    }

    // MARK: - 2. The word-cloud channel (H-9, M-31, M-33)

    @Test("The word-cloud hand-off is consumed into window-local state, not read from the shared slot")
    func wordCloudIsConsumed() throws {
        let source = try Self.source("App/MainTabView.swift")

        #expect(source.contains("@State private var presentedWordCloud"), """
            Presentation must own its value (#752 / M-33). The old binding read the shared slot on \
            every render, so opening a cloud in window B overwrote it and window A's sheet — whose \
            getter then returned nil — dismissed itself.
            """)
        #expect(source.contains(".sheet(item: $presentedWordCloud)"),
                "the sheet must be bound to that local state")

        let consumer = try Self.functionBody("private func consumePendingWordCloud()", in: source, limit: 800)
        #expect(consumer.contains("appState.pendingWordCloud = nil"),
                "adoption must CLEAR the shared slot — that is what makes it a consume")
        #expect(consumer.contains("presentedWordCloud = handoff"),
                "and move the value into this window's own state")
    }

    @Test("The word-cloud channel accepts .anyWindow, like its four siblings")
    func wordCloudAcceptsAnyWindow() throws {
        // H-9 / M-31: this was the ONE channel of five demanding an exact scene match. A standalone
        // document window whose launcher had closed — or which the app restored, capturing no
        // origin — targets `.anyWindow`, so no presenter matched and the tile did nothing, forever,
        // while every other rail tile worked.
        let source = try Self.source("App/MainTabView.swift")
        let consumer = try Self.functionBody("private func consumePendingWordCloud()", in: source, limit: 800)
        #expect(consumer.contains(".anyWindow"), """
            consumePendingWordCloud must accept the .anyWindow wildcard. AppState's own doc comment \
            promises .anyWindow "never black-holes"; for this channel that was untrue (#752 / H-9).
            """)
    }

    @Test("An already-presented cloud is not replaced mid-flight")
    func consumerDoesNotStealFromItself() throws {
        // Without the guard, a second hand-off arriving while this window's sheet is up would swap
        // the content underneath the user.
        let source = try Self.source("App/MainTabView.swift")
        let consumer = try Self.functionBody("private func consumePendingWordCloud()", in: source, limit: 800)
        #expect(consumer.contains("guard presentedWordCloud == nil"),
                "a window already showing a cloud must not adopt another one")
    }

    @Test("Both entry points feed the same consumer")
    func bothEntryPointsDelegate() throws {
        // Same reasoning as #750's analytics/chronology drain: `.onChange` misses a value set
        // before the window attached.
        let source = try Self.source("App/MainTabView.swift")
        #expect(source.contains(".onChange(of: appState.pendingWordCloud) { _, _ in consumePendingWordCloud() }"),
                "a hand-off arriving while this window is live must be adopted")
        #expect(source.contains(".onAppear { consumePendingWordCloud() }"),
                "and one that arrived before it attached must be drained")
    }

    // MARK: - 3. Sheets that can host a reader inject the scene (L-39)

    @Test("Every reader-hosting sheet injects the window's sceneID")
    func readerSheetsInjectSceneID() throws {
        // The codebase's own rule: a sheet does not reliably inherit `\.sceneID`. Four sheets
        // injected it; Citation Lookup and the cross-reference graph did not, so a document pushed
        // inside them read nil and its cross-references posted to `.anyWindow` — first-wins across
        // every open iPad window.
        // Assert ADJACENCY, not "sceneID appears somewhere nearby": a generous character window
        // spilled into the ArchivalNeighbors sheet three lines below, which injects it too, so the
        // assertion passed with Citation Lookup's own injection deleted (measured: M8 survived).
        let searchView = try Self.source("Search/SearchView.swift")
        let searchCode = Self.codeLines(searchView)
        let citationIndex = try #require(searchCode.firstIndex { $0.text == "CitationLookupView()" },
                                         "CitationLookupView() presentation not found — moved?")
        let next = searchCode[(citationIndex + 1)...].prefix(2).map(\.text)
        #expect(next.contains { $0.contains(".environment(\\.sceneID") }, """
            The Citation Lookup sheet must inject \\.sceneID on CitationLookupView() itself \
            (#752 / L-39). Found instead: \(next.joined(separator: " | ")). Without it a document \
            pushed inside the sheet reads a nil sceneID and its cross-references post to \
            .anyWindow, first-wins across every open iPad window.
            """)

        let documentView = try Self.source("DocumentView/DocumentView.swift")
        // Anchored on the sheet BUILDER, not the bare case label — `case .crossReferenceGraph:`
        // also appears in the sheet-identity switch far earlier in the file, and matching that one
        // made this assertion read a completely unrelated block.
        let graph = try Self.functionBody(
            "case .crossReferenceGraph:\n                if let store = appState.crossReferenceStore {",
            in: documentView, limit: 1_200)
        #expect(graph.contains("\\.sceneID"),
                "the cross-reference graph sheet must inject \\.sceneID (#752 / L-39)")
    }

    // MARK: - The scope this PR did not close

    /// The symbol that would front a scene. Declared once so the vacuity control below and the
    /// real scan cannot drift apart — a control that tests a different string proves nothing.
    private static let needle = "requestSceneSessionActivation"

    @Test("Nothing has quietly started activating scenes")
    func noSceneActivationYet() throws {
        // M-25 (Spotlight/deep-link content can land in a background window) needs the app to
        // ACTIVATE the consuming scene, which it has never done anywhere. This test is a marker,
        // not an endorsement: if someone adds scene activation, M-25's analysis — and this suite's
        // account of why the standalone-window fix was necessary — both need revisiting.
        // Vacuity control FIRST: prove the scan can match before trusting that it found nothing.
        // Without this, breaking the needle makes the whole assertion pass (measured: M9 survived —
        // the same defect #749's M9 exposed).
        let fixture = "appState.requestSceneSessionActivation(role: .windowApplication)"
        #expect(!Self.codeLines(fixture).filter { $0.text.contains(Self.needle) }.isEmpty,
                "the scan must be able to detect a scene activation, or finding none proves nothing")

        var activations: [String] = []
        let root = Self.appSourceRoot
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate \(root.path)"); return
        }
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for entry in Self.codeLines(text) where entry.text.contains(Self.needle) {
                activations.append("\(url.lastPathComponent):\(entry.line)")
            }
        }
        #expect(activations.isEmpty, """
            Scene activation has appeared at \(activations.joined(separator: ", ")). That is not \
            forbidden — it is the missing piece M-25 needs — but it changes the reasoning behind \
            the #752 fixes, which route around the fact that no window can be fronted.
            """)
    }
}
