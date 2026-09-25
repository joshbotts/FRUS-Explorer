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
/// it too, and when #752 was written nothing in the app activated a scene — a repo-wide grep
/// returned zero hits — so the consuming window was never brought forward. On a Stage Manager iPad
/// the tap looked like nothing happened while another stage silently changed. When the launcher had
/// closed, or the app had restored the window (which captures no origin at all), the target degraded
/// to `.anyWindow`: some third window, or for the word cloud, **no window at all**.
///
/// Since #1368 the app activates a scene in exactly one place, and only when an auxiliary window
/// CLOSES: its Done, and the exits that hand content to a main window and then close, bring that
/// main window forward. A door that hands off and leaves the window open still fronts nothing, so
/// #752's in-place navigation is still the answer for the standalone document window.
///
/// ## What the tests pin
/// 1. The standalone window navigates **in place** — it owns a path and a router (H-7, M-30).
/// 2. The word-cloud channel accepts `.anyWindow` like its four siblings, and **consumes** rather
///    than holding the shared slot for its presentation lifetime (H-9, M-31, M-33).
/// 3. Every sheet that can host a reader injects `\.sceneID` (L-39).
/// 4. Closing an iPad auxiliary window brings a main window forward instead of leaving the reader
///    on the Home Screen (#1368): the one activation site, the destination rule, the close action,
///    and every Done and hand-off exit that closes a window.
///
/// Version history:
///   1.0 — Session 2026-08-08: #752
///   1.1 — Session 2026-09-24: #1368 — `noSceneActivationYet` inverted into
///          `activationExistsAtExactlyOneSite`; the aux-window close suite added
///   1.2 — #1368 review round 1: an aux window launched from another aux window closes back to it
///          (4a′, the launch-recording tests), a hand-off close with no target is still a hand-off,
///          and every closing exit's hand-off is addressed to the window its close fronts
///          (`everyClosingExitAddressesTheWindowItFronts`)
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

    // MARK: - The macOS Window menu lists only windows (#824)

    /// SwiftUI generates the Window menu from the `Window` scenes, one entry each, and exposes no
    /// API to section or suppress an entry — `CommandGroup(before: .windowList)` can only insert
    /// *around* the list, which is what produced the duplicate #823 had to remove.
    ///
    /// So a scene leaves that menu by not being a `Window`. It does **not** have to stop being a
    /// window: `WindowGroup(id:for:)` keyed on an always-equal marker is one reused window that the
    /// menu does not list — the shape `frus.crossReferenceGraph` already uses, and the one the
    /// Research Guide moved to "so the guide no longer clutters the macOS Window menu".
    ///
    /// About was listed only as an implementation artefact — it already has its home in the app
    /// menu — and New Project is an action rather than a place.
    @Test("About and New Project are not Window scenes, so the Window menu does not list them")
    func aboutAndNewProjectAreNotWindowScenes() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        let code = Self.codeLines(app).map(\.text)

        for id in ["\"about\"", "\"frus.newProject\""] {
            let declared = code.contains { $0.hasPrefix("Window(") && $0.contains(id) }
                || code.contains { $0.contains("id: \(id))") && $0.hasPrefix("Window(") }
            #expect(!declared, "\(id) is declared as a Window scene, so it is back in the Window menu")
        }
        #expect(app.contains("id: \"about\", for: AboutWindowID.self"))
        #expect(app.contains("id: \"frus.newProject\", for: NewProjectWindowID.self"))
    }

    /// The explicit `id:` on those two groups is load-bearing, and is why they are not the Research
    /// Guide's bare `WindowGroup(for:)`. `bringMacWindowToFront(id:)` matches on the window
    /// identifier, so without an id the #749 fronting guarantee is silently forfeited and choosing
    /// the menu item again while the window sits buried does nothing — the defect #749 found at
    /// 11 of 56 call sites.
    @Test("Both windows are still opened through a fronting call")
    func bothStillFront() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        #expect(app.contains("openWindow.fronting(id: \"about\", value: AboutWindowID())"))
        #expect(app.contains("openWindow.fronting(id: \"frus.newProject\", value: NewProjectWindowID())"))

        let main = try Self.source("App/MainWindowView.swift")
        #expect(main.contains("func fronting<V: Codable & Hashable>(id: String, value: V)"),
                "the value-based fronting overload is what keeps #749's guarantee for these scenes")
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
        // Matches the CALL, not the literal `jump == .replace`. The rule now lives in ONE place
        // (DocumentJump.apply) that a real test drives; a scan for the old literal was satisfied by
        // an `if` whose body had been deleted, which is measured — see DocumentJumpPathTests.
        #expect(navigate.contains("jump.apply(to: &navigationPath, appending: entry)"), """
            the standalone window must route its jump through DocumentJump.apply — a page-turn \
            replaces the reading position, and this is the one window with no breadcrumb at all \
            (#751 / M-17a).
            """)
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

    // MARK: - 4. Closing an aux window fronts a main window (#1368)

    /// The two UIKit calls that front a scene: the iOS 17 API the app uses, and the deprecated one
    /// the #752 marker used to look for. Declared once so the vacuity control below and the real
    /// scan cannot drift apart — a control that tests a different string proves nothing.
    ///
    /// **The old needle alone would have passed on the fix.** `noSceneActivationYet` looked for
    /// `requestSceneSessionActivation` only, and #1368 activates through `activateSceneSession`,
    /// so the marker would have gone on reporting "no activation" beside the one it exists to see.
    private static let activationNeedles = ["activateSceneSession", "requestSceneSessionActivation"]

    /// Every code line under `FRUSExplorer/` that calls a scene-activation API, and how many Swift
    /// files the walk read — so a scan that found nothing because it read nothing is told apart
    /// from one that found nothing because there is nothing.
    private static func activationSites() throws -> (sites: [String], filesRead: Int) {
        var sites: [String] = []
        var filesRead = 0
        let root = Self.appSourceRoot
        let walker = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil),
                                  "could not enumerate \(root.path)")
        for case let url as URL in walker where url.pathExtension == "swift" {
            filesRead += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for entry in Self.codeLines(text)
            where Self.activationNeedles.contains(where: { entry.text.contains($0) }) {
                sites.append("\(url.lastPathComponent):\(entry.line)")
            }
        }
        return (sites, filesRead)
    }

    /// The #752 marker, inverted (#1368). It called itself "a marker, not an endorsement": M-25
    /// needed the app to ACTIVATE a scene, and it never had. #1368 is that activation, so the pin
    /// turns positive — and stays narrow. One site means one place deciding which window comes
    /// forward and when; a second would be a second policy, which is how a window ends up fronted by
    /// a door that did not mean to leave.
    @Test("Scene activation exists at exactly one site, in AppState")
    func activationExistsAtExactlyOneSite() throws {
        // Vacuity control FIRST, one fixture per needle: prove the scan can match each spelling
        // before trusting what it counts (measured on the old marker: M9 survived a broken needle).
        for fixture in ["UIApplication.shared.activateSceneSession(for: request) { _ in }",
                        "UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil)"] {
            #expect(Self.codeLines(fixture).contains { line in
                Self.activationNeedles.contains { line.text.contains($0) }
            }, "the scan must detect \(fixture)")
        }
        #expect(Self.codeLines("// UIApplication.shared.activateSceneSession(for: request)").isEmpty,
                "and a comment naming the call is not a call")

        let (sites, filesRead) = try Self.activationSites()
        #expect(filesRead > 100, "read only \(filesRead) Swift files under FRUSExplorer/ — moved?")
        #expect(sites.count == 1, """
            Scene activation must happen at exactly ONE site (#1368) — AppState's aux-window \
            front(_:). Found \(sites.count): \(sites.joined(separator: ", ")). Zero means an iPad \
            aux window's Done drops the reader on the Home Screen again; two means a second policy \
            for which window comes forward.
            """)
        #expect(sites.allSatisfy { $0.hasPrefix("AppState.swift:") },
                "the one site belongs in AppState's front(_:); found \(sites.joined(separator: ", "))")
    }

    // MARK: 4a. The destination rule

    /// A registry of two main windows, `A` (older) and `B` (newer), with their sessions.
    private static let twoWindows: [String: RegisteredMainWindow] = [
        "A": RegisteredMainWindow(sessionID: "session-A", sequence: 1),
        "B": RegisteredMainWindow(sessionID: "session-B", sequence: 2),
    ]

    @Test("A live launcher is the window a Done brings forward")
    func launcherWins() {
        // B is newer and also open, so a rule that ignored the origin would pick B.
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: "A", registry: Self.twoWindows,
            openSessions: ["session-A": .background, "session-B": .foreground])
        #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"),
                "the launcher must win even when another main window is in front of it")
    }

    @Test("A hand-off's own live target outranks the launcher")
    func handOffTargetWins() {
        let destination = AuxWindowDestination.resolve(
            target: SceneID("B"), origin: "A", registry: Self.twoWindows,
            openSessions: ["session-A": .foreground, "session-B": .background])
        #expect(destination == .mainWindow(SceneID("B"), sessionID: "session-B"),
                "an exit fronts the window its content was addressed to, not merely the launcher")
    }

    @Test("A target no window registered falls through to the launcher")
    func unregisteredTargetFallsToLauncher() {
        // `.anyWindow` and the `frus.sceneID.unreached` sentinel name no window.
        for target in [SceneID.anyWindow, SceneID("frus.sceneID.unreached")] {
            let destination = AuxWindowDestination.resolve(
                target: target, origin: "A", registry: Self.twoWindows,
                openSessions: ["session-A": .background, "session-B": .foreground])
            #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"), "\(target.raw)")
        }
    }

    @Test("A target whose window has closed falls through to the launcher")
    func closedTargetFallsToLauncher() {
        let destination = AuxWindowDestination.resolve(
            target: SceneID("B"), origin: "A", registry: Self.twoWindows,
            openSessions: ["session-A": .background])
        #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"))
    }

    @Test("A closed launcher falls back to another open main window")
    func closedLauncherFallsBack() {
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: "A", registry: Self.twoWindows,
            openSessions: ["session-B": .background])
        #expect(destination == .mainWindow(SceneID("B"), sessionID: "session-B"))
    }

    @Test("With no launcher, a foreground main window beats a newer background one")
    func fallbackPrefersForeground() {
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: nil, registry: Self.twoWindows,
            openSessions: ["session-A": .foreground, "session-B": .background])
        #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"),
                "the older window is in front, so it is the one the reader can see")
    }

    @Test("With no launcher, a background main window beats an unattached one")
    func fallbackPrefersAttached() {
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: nil, registry: Self.twoWindows,
            openSessions: ["session-A": .background, "session-B": .unattached])
        #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"))
    }

    @Test("Between two equally placed main windows, the newer registration wins")
    func fallbackPrefersNewerRegistration() {
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: nil, registry: Self.twoWindows,
            openSessions: ["session-A": .foreground, "session-B": .foreground])
        #expect(destination == .mainWindow(SceneID("B"), sessionID: "session-B"))
    }

    @Test("Two scene tokens on the same sequence are ordered by token, not by dictionary order")
    func fallbackIsTotal() {
        // Unreachable through `registerSceneSession`, which numbers every registration, but the rule
        // must still be a total order: a `Dictionary` walks in a different order every launch.
        let tied: [String: RegisteredMainWindow] = [
            "Y": RegisteredMainWindow(sessionID: "session-Y", sequence: 7),
            "X": RegisteredMainWindow(sessionID: "session-X", sequence: 7),
        ]
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: nil, registry: tied,
            openSessions: ["session-X": .foreground, "session-Y": .foreground])
        #expect(destination == .mainWindow(SceneID("X"), sessionID: "session-X"))
    }

    @Test("With no main window left, the close asks for a new one rather than the Home Screen")
    func noMainWindowRequestsANewOne() {
        #expect(AuxWindowDestination.resolve(target: nil, origin: "A", registry: Self.twoWindows,
                                             openSessions: [:]) == .newMainWindow,
                "every registered window is closed")
        #expect(AuxWindowDestination.resolve(target: nil, origin: nil, registry: [:],
                                             openSessions: ["session-aux": .foreground]) == .newMainWindow,
                "an open session no main window registered — an aux window's own — is not a main window")
    }

    @Test("A hand-off is addressed to the window the close fronts, or to any window when it is new")
    func handOffTargetFollowsTheDestination() {
        #expect(AuxWindowDestination.mainWindow(SceneID("A"), sessionID: "session-A").handOffTarget
                == SceneID("A"))
        // `.anyWindow` is drained by the channels that accept it (tab, search, Browse, word cloud);
        // `BrowserView` consumes Analytics and Chronology strictly, so those two do not arrive.
        #expect(AuxWindowDestination.newMainWindow.handOffTarget == .anyWindow,
                "a window that does not exist yet has no token, so the hand-off is addressed to `.anyWindow`")
    }

    // MARK: 4a′. An aux window that launched this one (#1368 review round 1)

    /// The standalone document window `D`, by the token its `AuxWindowOriginModifier` minted and the
    /// session it registered. It borrowed main window `A`'s identity, so `A` is the ORIGIN a rail
    /// tool opened there records, and `D` its LAUNCHER.
    private static let documentWindow = ["frus.auxWindow.D": "session-D"]

    @Test("A plain close goes back to the aux window it was launched from, not the main window behind it")
    func auxLauncherWinsForAPlainClose() {
        // B is newer and in front, A is the origin; the reader came from D, so D must win.
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: "A", registry: Self.twoWindows,
            openSessions: ["session-A": .background, "session-B": .foreground, "session-D": .background],
            launcher: "frus.auxWindow.D", auxWindows: Self.documentWindow)
        #expect(destination == .launchingAuxWindow(
            sessionID: "session-D", fallback: .mainWindow(SceneID("A"), sessionID: "session-A")),
            "Source Explorer opened from the document window's rail must bring that window back")
        #expect(destination.activationSteps == [.session("session-D"), .session("session-A"), .newMainWindow],
                "and if iPadOS refuses it, the main window the rule would have chosen, then a new one")
    }

    @Test("With its main window gone, the document window comes back rather than a new main window")
    func auxLauncherBeatsANewMainWindow() {
        // Review scenario 2: A closed in Stage Manager, D still open. Round 0 asked iPadOS for a
        // brand-new main window beside D.
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: "A", registry: Self.twoWindows, openSessions: ["session-D": .foreground],
            launcher: "frus.auxWindow.D", auxWindows: Self.documentWindow)
        #expect(destination == .launchingAuxWindow(sessionID: "session-D", fallback: .newMainWindow))
        #expect(destination.activationSteps.first == .session("session-D"),
                "the first request must be for the open document window, not for a new main window")
    }

    @Test("A close that follows a hand-off never goes to an aux window, even the one it came from")
    func handOffSkipsTheAuxLauncher() {
        // `.anyWindow` names no main window, so it falls through — but it is still a hand-off.
        for target in [SceneID.anyWindow, SceneID("A")] {
            let destination = AuxWindowDestination.resolve(
                target: target, origin: "A", registry: Self.twoWindows,
                openSessions: ["session-A": .background, "session-D": .foreground],
                launcher: "frus.auxWindow.D", auxWindows: Self.documentWindow)
            #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"),
                    "\(target.raw): the content went to a main window, so that is where the reader lands")
        }
    }

    @Test("A launching aux window that has closed falls back to the main-window rule")
    func closedAuxLauncherFallsBack() {
        let destination = AuxWindowDestination.resolve(
            target: nil, origin: "A", registry: Self.twoWindows, openSessions: ["session-A": .background],
            launcher: "frus.auxWindow.D", auxWindows: Self.documentWindow)
        #expect(destination == .mainWindow(SceneID("A"), sessionID: "session-A"))
    }

    @Test("An aux-window destination addresses hand-offs to the main window behind it")
    func auxDestinationHandsOffToItsFallback() {
        #expect(AuxWindowDestination.launchingAuxWindow(
            sessionID: "session-D", fallback: .mainWindow(SceneID("A"), sessionID: "session-A")).handOffTarget
                == SceneID("A"))
        #expect(AuxWindowDestination.launchingAuxWindow(sessionID: "session-D", fallback: .newMainWindow)
                .handOffTarget == .anyWindow, "an aux window consumes no hand-off")
    }

    @Test("A destination activates its session, and asks for a new window if that fails")
    func activationStepsFallBackToANewWindow() {
        #expect(AuxWindowDestination.mainWindow(SceneID("A"), sessionID: "session-A").activationSteps
                == [.session("session-A"), .newMainWindow])
        #expect(AuxWindowDestination.newMainWindow.activationSteps == [.newMainWindow])
    }

    @Test("Activation moves to the next step only when a step fails, and stops at the end")
    @MainActor
    func activationRunnerAdvancesOnFailureOnly() {
        let succeeding = CloseLog()
        AppState.activate([.session("s"), .newMainWindow]) { step, _ in succeeding.steps.append(step) }
        #expect(succeeding.steps == [.session("s")], "a step that did not fail must end the run")

        let failing = CloseLog()
        AppState.activate([.session("s"), .newMainWindow]) { step, failed in
            failing.steps.append(step)
            failed()
        }
        #expect(failing.steps == [.session("s"), .newMainWindow],
                "every step is tried once, in order, and a failure after the last one ends the run")
    }

    // MARK: 4b. The registry the rule reads

    @Test("A window's session outlives its onDisappear, so the launcher is still found")
    @MainActor
    func registryIsNotLiveSceneIDs() {
        // The plan's reason for resolving against open sessions rather than `liveSceneIDs`:
        // `MainTabView.onDisappear` clears the latter while the window's session survives.
        let state = AppState()
        state.registerScene(SceneID("A"))
        state.registerSceneSession("session-A", for: SceneID("A"))
        state.unregisterScene(SceneID("A"))
        #expect(!state.liveSceneIDs.contains(SceneID("A")), "precondition: onDisappear ran")
        #expect(state.auxWindowDestination(target: nil, origin: "A",
                                           openSessions: ["session-A": .background])
                == .mainWindow(SceneID("A"), sessionID: "session-A"))
    }

    @Test("Re-registering the same session keeps its place; a new session takes a new one")
    @MainActor
    func reregistrationIsStable() {
        let state = AppState()
        state.registerSceneSession("session-A", for: SceneID("A"))
        state.registerSceneSession("session-B", for: SceneID("B"))
        state.registerSceneSession("session-A", for: SceneID("A"))
        let open: [String: AuxWindowSessionState] = ["session-A": .foreground, "session-B": .foreground]
        #expect(state.auxWindowDestination(target: nil, origin: nil, openSessions: open)
                == .mainWindow(SceneID("B"), sessionID: "session-B"),
                "a repeated registration must not make A the newest window")

        state.registerSceneSession("session-A2", for: SceneID("A"))
        #expect(state.auxWindowDestination(target: nil, origin: nil,
                                           openSessions: ["session-A2": .foreground, "session-B": .foreground])
                == .mainWindow(SceneID("A"), sessionID: "session-A2"),
                "a token that moved to a new session is re-registered, and is now the newest")
    }

    @Test("A launch from an aux window records that window as the launcher and its borrowed scene as the origin")
    @MainActor
    func launchRecordsWhereTheReaderStood() {
        let state = AppState()
        state.recordAuxWindowLaunch(from: SceneID("A"))
        #expect(state.pendingAuxWindowOriginRaw == "A")
        #expect(state.pendingAuxWindowLauncherRaw == "A", "from a main window the two are the same window")

        state.recordAuxWindowLaunch(from: SceneID("A").borrowed(by: "frus.auxWindow.D"))
        #expect(state.pendingAuxWindowOriginRaw == "A", "routing still follows the borrowed scene")
        #expect(state.pendingAuxWindowLauncherRaw == "frus.auxWindow.D",
                "but the reader was standing in D, and D is where Done goes back to")

        state.recordAuxWindowLaunch(from: nil)
        #expect(state.pendingAuxWindowOriginRaw == nil && state.pendingAuxWindowLauncherRaw == nil,
                "every open overwrites both, so a parked value cannot leak into the next window")
    }

    @Test("Source Explorer opened from the document window's rail closes back to the document window")
    @MainActor
    func documentWindowRailToolClosesBackToIt() {
        // The whole chain in the model: D publishes A's identity carrying its own token; the rail
        // records the launch from it; Source Explorer drains both; its Done resolves.
        let state = AppState()
        state.registerScene(SceneID("A"))
        state.registerSceneSession("session-A", for: SceneID("A"))
        state.registerAuxWindowSession("session-D", for: "frus.auxWindow.D")
        let published = state.auxWindowSceneID(forOrigin: "A", standingIn: "frus.auxWindow.D")
        #expect(published == SceneID("A") && published.isBorrowed,
                "D still addresses A, and is still marked borrowed (#1351)")
        #expect(published.borrowingWindow == "frus.auxWindow.D")

        state.recordAuxWindowLaunch(from: published)
        let open: [String: AuxWindowSessionState] = ["session-A": .background, "session-D": .background]
        #expect(state.auxWindowDestination(target: nil, origin: state.pendingAuxWindowOriginRaw,
                                           launcher: state.pendingAuxWindowLauncherRaw, openSessions: open)
                == .launchingAuxWindow(sessionID: "session-D",
                                       fallback: .mainWindow(SceneID("A"), sessionID: "session-A")))
        #expect(state.auxWindowDestination(target: nil, origin: nil, openSessions: ["session-D": .foreground])
                == .newMainWindow,
                "an aux window's session is never a MAIN-window fallback — only the launcher it was named as")
    }

    @Test("The host app's own window is reported open and on screen")
    @MainActor
    func openSessionStatesReadsTheLiveApp() {
        // The one part of the rule's input that comes from UIKit rather than a fixture. The unit
        // tests run hosted in the app, so its main window is a real open session, in front — and a
        // snapshot that lost it, or filed it under `.unattached`, would send every Done to a new
        // window instead of the one on screen.
        let states = AppState.openSessionStates()
        #expect(!states.isEmpty, "the test host's own scene session is missing from the snapshot")
        #expect(states.values.contains(.foreground),
                "the host's window is on screen, so at least one session must read .foreground; got \(states)")
    }

    // MARK: 4c. The close action a Done performs

    /// Records what an ``AuxWindowCloseAction`` or the activation runner did, in order. A class, so
    /// the `@Sendable` closures under test can append to it without capturing a mutable local.
    @MainActor
    private final class CloseLog {
        /// The close action's calls, as `"front:<target>"` and `"dismiss"`.
        var events: [String] = []
        /// The activation steps the runner attempted.
        var steps: [AuxWindowActivationStep] = []
        /// A window-close payload that resolves every hand-off to `resolved` and logs each front.
        func window(resolving resolved: SceneID) -> AuxWindowClosing {
            AuxWindowClosing(
                handOffTarget: { _ in resolved },
                front: { [weak self] target in self?.events.append("front:\(target?.raw ?? "nil")") })
        }
    }

    @Test("Without a window payload, Done only dismisses and hand-offs keep their own target")
    @MainActor
    func sheetCloseOnlyDismisses() {
        let log = CloseLog()
        let action = AuxWindowCloseAction(dismiss: { log.events.append("dismiss") },
                                          isPresented: false, window: nil)
        action()
        action(frontingHandOffTo: SceneID("X"))
        #expect(log.events == ["dismiss", "dismiss"])
        #expect(action.handOffTarget(from: SceneID("mine")) == SceneID("mine"))
        #expect(action.handOffTarget(from: nil) == nil,
                "a sheet's nil scene stays nil, so the openers' own fallbacks are unchanged")
    }

    @Test("At a window's root, Done fronts the launcher and then dismisses")
    @MainActor
    func windowCloseFrontsThenDismisses() {
        let log = CloseLog()
        let action = AuxWindowCloseAction(dismiss: { log.events.append("dismiss") },
                                          isPresented: false, window: log.window(resolving: SceneID("L")))
        action()
        #expect(log.events == ["front:nil", "dismiss"], "front first: dismissing ends this scene")

        log.events = []
        #expect(action.handOffTarget(from: nil) == SceneID("L"),
                "a window with no scene of its own addresses the window it will front")
        action(frontingHandOffTo: SceneID("L"))
        #expect(log.events == ["front:L", "dismiss"])
    }

    @Test("A close after a hand-off with no target is still a hand-off, never a plain close")
    @MainActor
    func nilHandOffTargetIsStillAHandOff() {
        // `front(nil)` means a PLAIN close, which may go back to a launching aux window (round 1).
        // Content was handed to a main window here, so the reader must not be sent to that window.
        let log = CloseLog()
        let action = AuxWindowCloseAction(dismiss: { log.events.append("dismiss") },
                                          isPresented: false, window: log.window(resolving: SceneID("L")))
        action(frontingHandOffTo: nil)
        #expect(log.events == ["front:frus.anyWindow", "dismiss"])
    }

    @Test("A Done in a sheet inside an aux window closes only the sheet")
    @MainActor
    func presentedViewNeverFronts() {
        // The environment reaches a sheet the window presents, and there the view's `dismiss`
        // closes the sheet, not the window — fronting the launcher would yank the reader out of a
        // window that is staying open.
        let log = CloseLog()
        let action = AuxWindowCloseAction(dismiss: { log.events.append("dismiss") },
                                          isPresented: true, window: log.window(resolving: SceneID("L")))
        action()
        action(frontingHandOffTo: SceneID("L"))
        #expect(log.events == ["dismiss", "dismiss"])
        #expect(action.handOffTarget(from: SceneID("mine")) == SceneID("mine"))
    }

    // MARK: 4d. Every Done and every closing exit uses it

    /// The text of the balanced block that opens at the first `open` at or after `start`, with
    /// string literals and `//` line comments skipped so a brace or paren inside them does not count.
    /// A `/* … */` block comment is NOT skipped — none of the scanned blocks holds one.
    ///
    /// This is how the scans below match a CALL rather than a text window: a window long enough to
    /// reach a closure's body also reaches the next declaration, and a scan that read the wrong
    /// block has passed in this repository before (see `readerSheetsInjectSceneID`).
    static func balancedBlock(in source: String, from start: String.Index,
                              open: Character = "{", close: Character = "}") -> Substring? {
        var depth = 0
        var first: String.Index?
        var index = start
        var inString = false
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if inString {
                if character == "\\", next < source.endIndex {
                    index = source.index(after: next)
                    continue
                }
                if character == "\"" { inString = false }
            } else if character == "\"" {
                inString = true
            } else if character == "/", next < source.endIndex, source[next] == "/" {
                index = source[index...].firstIndex(of: "\n") ?? source.endIndex
                continue
            } else if character == open {
                if first == nil { first = index }
                depth += 1
            } else if character == close, let first {
                depth -= 1
                if depth == 0 { return source[first...index] }
            }
            index = next
        }
        return nil
    }

    @Test("balancedBlock reads the whole call, and skips braces in strings and line comments")
    func balancedBlockMatchesTheCall() throws {
        let sample = """
            Button(String(localized: "k", defaultValue: "Done {")) { // a } in a comment
                doThing { inner() }
            }
            let after = 1
            """
        let buttonBlock = try #require(Self.balancedBlock(in: sample, from: sample.startIndex))
        #expect(buttonBlock.hasSuffix("inner() }\n}"), "got: \(buttonBlock)")
        #expect(!buttonBlock.contains("after"))
        let args = try #require(Self.balancedBlock(in: sample, from: sample.startIndex,
                                                   open: "(", close: ")"))
        #expect(args == "(String(localized: \"k\", defaultValue: \"Done {\"))")
    }

    /// A bare `dismiss()` call — not `closeWindow.dismiss`, not `onDismiss()`.
    ///
    /// Written as a scan rather than a regex: Swift's `Regex` does not support the lookbehind the
    /// pattern needs.
    private static func callsBareDismiss(_ text: some StringProtocol) -> Bool {
        let text = String(text)
        var searchStart = text.startIndex
        while let hit = text.range(of: "dismiss()", range: searchStart..<text.endIndex) {
            guard hit.lowerBound > text.startIndex else { return true }
            let before = text[text.index(before: hit.lowerBound)]
            if !(before.isLetter || before.isNumber || before == "_" || before == ".") { return true }
            searchStart = hit.upperBound
        }
        return false
    }

    @Test("the bare-dismiss scan finds a call and nothing that merely contains the word")
    func bareDismissScanIsExact() {
        #expect(Self.callsBareDismiss("{ dismiss() }"))
        #expect(Self.callsBareDismiss("dismiss()"), "a call at the very start of the text")
        #expect(Self.callsBareDismiss("{ onDismiss(); dismiss() }"), "a second, bare call after a named one")
        #expect(!Self.callsBareDismiss("{ onDismiss() }"))
        #expect(!Self.callsBareDismiss("{ closeWindow() }"))
        #expect(!Self.callsBareDismiss("{ self.presentation.dismiss() }"))
    }

    /// The nine iOS aux windows' Done buttons, by file and localization key (#1368).
    private static let doneButtons: [(file: String, key: String)] = [
        ("Semantic/SemanticAnalyticsView.swift", "semanticAnalytics.done"),
        ("SourceExplorer/SourceExplorerView.swift", "source.explorer.done"),
        ("CrossReference/CrossReferenceGraphView.swift", "graph.done"),
        ("Analytics/CrossReferenceAnalyticsView.swift", "crossRefAnalytics.done"),
        ("Analytics/AnalyticsView.swift", "analytics.done"),
        ("Chronology/ChronologyView.swift", "chronology.done"),
        ("Analytics/PersonAnalyticsView.swift", "personAnalytics.done"),
        ("Analytics/ArchivalAnalyticsView.swift", "archival.done"),
        ("Analytics/WordCloud/WordCloudView.swift", "common.done"),
    ]

    @Test("Every aux window's Done goes through the close action, never a bare dismiss()")
    func everyDoneUsesTheCloseAction() throws {
        var offenders: [String] = []
        for (file, key) in Self.doneButtons {
            let source = try Self.source(file)
            let anchor = try #require(source.range(of: "Button(String(localized: \"\(key)\""),
                                      "\(file): no Done button keyed \(key) — moved or renamed?")
            // The call's own argument list, then the trailing closure that follows it.
            let arguments = try #require(Self.balancedBlock(in: source, from: anchor.lowerBound,
                                                            open: "(", close: ")"))
            let action = try #require(Self.balancedBlock(in: source, from: arguments.endIndex),
                                      "\(file): the Done has no trailing action closure")
            if Self.callsBareDismiss(action) || !action.contains("closeWindow()") {
                offenders.append("\(file) \(key): \(action.split(separator: "\n").joined(separator: " "))")
            }
        }
        #expect(offenders.isEmpty, """
            These Done buttons still call dismiss() directly (#1368). At the root of an iPad \
            WindowGroup that closes the app's only foreground scene and shows the Home Screen: \
            \(offenders.joined(separator: " | "))
            """)
    }

    /// The exits that hand content to a main window and then close their own (#1368), by file and
    /// the declaration that opens the block they live in.
    private static let closingExits: [(file: String, anchor: String)] = [
        ("SourceExplorer/SourceExplorerView.swift", "ForEach(relatedDocs, id: \\.compositeKey)"),
        ("Chronology/ChronologyView.swift", "private func openWordCloudForRange()"),
        ("Chronology/ChronologyView.swift", "private func searchInRange()"),
        ("Analytics/AnalyticsView.swift", "private func navigateToSearch("),
        ("Analytics/WordCloud/WordCloudView.swift", "private func analyze(for term: String"),
        ("Analytics/WordCloud/WordCloudView.swift", "private func search(for term: String)"),
        ("Analytics/WordCloud/WordCloudView.swift", "private func viewInChronology()"),
        ("Analytics/ArchivalAnalyticsView.swift", ".onNavigateAwayFromCollection {"),
    ]

    @Test("Every exit that hands off and then closes fronts the hand-off's window first")
    func everyClosingExitFrontsItsTarget() throws {
        var offenders: [String] = []
        for (file, anchorText) in Self.closingExits {
            let source = try Self.source(file)
            let anchor = try #require(source.range(of: anchorText),
                                      "\(file): \(anchorText) not found — moved or renamed?")
            let block = try #require(Self.balancedBlock(in: source, from: anchor.lowerBound),
                                     "\(file): \(anchorText) has no body")
            if Self.callsBareDismiss(block) || !block.contains("closeWindow(frontingHandOffTo:") {
                offenders.append("\(file) — \(anchorText)")
            }
        }
        #expect(offenders.isEmpty, """
            These exits hand content to a main window and then close their own with a bare \
            dismiss(), which on iPad leaves the content in a window nobody brings forward (#1368): \
            \(offenders.joined(separator: " | "))
            """)
    }

    /// The argument text of every call that begins with `prefix` — e.g. `closeWindow(frontingHandOffTo:`
    /// — in `code`: what follows the label, up to the call's own closing paren, trimmed.
    static func labelledArguments(of prefix: String, in code: String) -> [String] {
        guard let parenOffset = prefix.firstIndex(of: "(").map({ prefix.distance(from: prefix.startIndex, to: $0) })
        else { return [] }
        var found: [String] = []
        var searchStart = code.startIndex
        while let hit = code.range(of: prefix, range: searchStart..<code.endIndex) {
            let open = code.index(hit.lowerBound, offsetBy: parenOffset)
            if let call = balancedBlock(in: code, from: open, open: "(", close: ")") {
                let label = prefix[prefix.index(prefix.startIndex, offsetBy: parenOffset + 1)...]
                found.append(call.dropFirst().dropLast().replacingOccurrences(of: label, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            }
            searchStart = hit.upperBound
        }
        return found
    }

    /// The `from:` argument of every `appState.open…(…)` hand-off in `code` — the scene each one is
    /// addressed to — read at the call's own top level, so a `from:` inside a nested argument is not
    /// mistaken for the call's.
    static func handOffAddresses(in code: String) -> [String] {
        var found: [String] = []
        var searchStart = code.startIndex
        while let hit = code.range(of: "appState.open", range: searchStart..<code.endIndex) {
            searchStart = hit.upperBound
            guard let open = code[hit.upperBound...].firstIndex(of: "("),
                  let call = balancedBlock(in: code, from: open, open: "(", close: ")") else { continue }
            var depth = 0
            var argument = ""
            var arguments: [String] = []
            for character in call {
                switch character {
                case "(", "[", "{": depth += 1; if depth > 1 { argument.append(character) }
                case ")", "]", "}": depth -= 1; if depth >= 1 { argument.append(character) }
                case "," where depth == 1: arguments.append(argument); argument = ""
                default: argument.append(character)
                }
            }
            arguments.append(argument)
            if let from = arguments.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { $0.hasPrefix("from:") }) {
                found.append(from.dropFirst("from:".count).trimmingCharacters(in: .whitespaces))
            }
        }
        return found
    }

    @Test("labelledArguments and handOffAddresses read the call they claim, and nothing nested")
    func addressScanReadsTheCall() {
        let sample = """
            let target = closeWindow.handOffTarget(from: sceneID)
            appState.openSearch(SearchParameters(keywords: k, from: x), from: target)
            appState.openTab(.search,
                             from: sceneID)
            closeWindow(frontingHandOffTo: target)
            """
        #expect(Self.handOffAddresses(in: sample) == ["target", "sceneID"],
                "the nested `from: x` is SearchParameters', not the hand-off's")
        #expect(Self.labelledArguments(of: "closeWindow(frontingHandOffTo:", in: sample) == ["target"])
        #expect(Self.labelledArguments(of: "navigateToSearch(frontingHandOffTo:", in: sample).isEmpty)
    }

    /// Each closing exit, with how its hand-off target is bound: `let target =` in its own body, or
    /// the `frontingHandOffTo target:` parameter its caller fills (`AnalyticsView.navigateToSearch`),
    /// and how many hand-offs it makes — so a scan that read the wrong block reads zero, not a pass.
    private static let addressedExits: [(file: String, anchor: String, handOffs: Int)] = [
        ("Chronology/ChronologyView.swift", "private func openWordCloudForRange()", 1),
        ("Chronology/ChronologyView.swift", "private func searchInRange()", 2),
        ("Analytics/AnalyticsView.swift", "private func openMatchingDocumentsInSearch()", 1),
        ("Analytics/AnalyticsView.swift", "private func openScopedDocumentsInSearch(", 1),
        ("Analytics/AnalyticsView.swift", "private func navigateToSearch(", 1),
        ("Analytics/WordCloud/WordCloudView.swift", "private func analyze(for term: String", 2),
        ("Analytics/WordCloud/WordCloudView.swift", "private func search(for term: String)", 2),
        ("Analytics/WordCloud/WordCloudView.swift", "private func viewInChronology()", 2),
        ("App/FRUSExplorerApp.swift", "onRelatedDocumentTapped: { vid, did in", 2),
    ]

    /// The expression every exit's hand-off target is taken from — the close action's own answer.
    private static let targetBinding = "let target = closeWindow.handOffTarget(from: sceneID)"

    /// Review round 1 (#1368): the half of the design `everyClosingExitFrontsItsTarget` could not
    /// see. That scan pins that each exit CLOSES through the action; it never read which window the
    /// content went to, so reverting any `from: target` to `from: sceneID` — `nil` in an analytics
    /// window, so `.anyWindow` or `frus.sceneID.unreached` — passed while the close fronted the
    /// launcher and the content went elsewhere or nowhere.
    @Test("Every closing exit addresses its hand-off to the same window its close brings forward")
    func everyClosingExitAddressesTheWindowItFronts() throws {
        var offenders: [String] = []
        for (file, anchorText, expected) in Self.addressedExits {
            let source = try Self.source(file)
            let anchor = try #require(source.range(of: anchorText),
                                      "\(file): \(anchorText) not found — moved or renamed?")
            let block = try #require(Self.balancedBlock(in: source, from: anchor.lowerBound),
                                     "\(file): \(anchorText) has no body")
            let code = Self.codeLines(String(block)).map(\.text).joined(separator: "\n")
            let addresses = Self.handOffAddresses(in: code)
            let closes = Self.labelledArguments(of: "closeWindow(frontingHandOffTo:", in: code)
                + Self.labelledArguments(of: "navigateToSearch(frontingHandOffTo:", in: code)
            // `balancedBlock` returns the body, so the signature is read from the anchor itself.
            let isParameter = source[anchor.lowerBound...]
                .hasPrefix("private func navigateToSearch(frontingHandOffTo target: SceneID?)")
            let bound = code.contains(Self.targetBinding) || isParameter
            // `SourceExplorerWindowContent`'s half closes nothing itself: `SourceExplorerView`'s row
            // closes, fronting `closeWindow.handOffTarget(from: sceneID)` — checked below.
            let closesItself = !anchorText.hasPrefix("onRelatedDocumentTapped")
            if addresses.count != expected || !addresses.allSatisfy({ $0 == "target" }) || !bound
                || (closesItself && (closes.isEmpty || !closes.allSatisfy({ $0 == "target" }))) {
                offenders.append("\(file) — \(anchorText): hand-offs \(addresses), closes \(closes), "
                                 + "target bound \(bound)")
            }
        }

        // The Source Explorer row fronts the expression its window content addresses through.
        let explorer = try Self.source("SourceExplorer/SourceExplorerView.swift")
        let row = try #require(explorer.range(of: "ForEach(relatedDocs, id: \\.compositeKey)"))
        let rowBlock = try #require(Self.balancedBlock(in: explorer, from: row.lowerBound))
        let rowCloses = Self.labelledArguments(of: "closeWindow(frontingHandOffTo:",
                                               in: Self.codeLines(String(rowBlock)).map(\.text).joined(separator: "\n"))
        if rowCloses != ["closeWindow.handOffTarget(from: sceneID)"] {
            offenders.append("SourceExplorerView related-document row: closes \(rowCloses)")
        }

        // Archival's citing volume goes through the collection sheet's injected scene, so its close
        // must front exactly that scene.
        let archival = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        let sheet = try #require(archival.range(of: ".sheet(item: $collectionDetail) { record in"))
        let sheetCode = Self.codeLines(String(try #require(Self.balancedBlock(in: archival, from: sheet.lowerBound))))
            .map(\.text).joined(separator: "\n")
        let injected = Self.labelledArguments(of: ".environment(\\.sceneID,", in: sheetCode)
        let archivalCloses = Self.labelledArguments(of: "closeWindow(frontingHandOffTo:", in: sheetCode)
        if injected.count != 1 || archivalCloses != injected {
            offenders.append("ArchivalAnalyticsView citing volume: sheet scene \(injected), closes \(archivalCloses)")
        }

        #expect(offenders.isEmpty, """
            These exits hand content to one window and bring another forward (#1368): each hand-off \
            must be addressed to `closeWindow.handOffTarget(from: sceneID)`, the window the close \
            then fronts. \(offenders.joined(separator: " | "))
            """)
    }

    // MARK: 4e. Where the payload comes from

    /// The six analytics windows, which learn where to go back to without borrowing the launcher's
    /// `\.sceneID` (#1368; see `AuxWindowOriginModifier`).
    private static let closeOnlyScenes = ["semanticMapScene", "corpusAnalyticsScene", "chronologyScene",
                                          "archivalAnalyticsScene", "personAnalyticsScene",
                                          "crossReferenceAnalyticsScene"]

    @Test("The six analytics windows publish the close payload and do not borrow a scene")
    func analyticsScenesAreCloseOnly() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        for scene in Self.closeOnlyScenes {
            let anchor = try #require(app.range(of: "private var \(scene): some Scene"),
                                      "\(scene) not found — moved or renamed?")
            let body = try #require(Self.balancedBlock(in: app, from: anchor.lowerBound))
            #expect(body.contains(".auxWindowCloseOnly(appState)"),
                    "\(scene) must record its launcher so its Done knows where to go back to")
            // Republishing the launcher's `\.sceneID` here would let `ArchivalAnalyticsView`'s
            // hand-off guard claim scope requests addressed to the launcher, racing
            // `MainTabView.consumePendingArchivalScope`, and retarget a dozen analytics producers.
            #expect(!body.contains(".auxWindowOrigin("),
                    "\(scene) must not borrow the launcher's scene identity")
        }
    }

    @Test("The four document-anchored windows still borrow their launcher's scene")
    func documentAnchoredScenesStillBorrow() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        for value in ["DocumentWindowID", "SourceExplorerRequest", "GraphWindowRequest", "WordCloudScope"] {
            // With the opening brace: the file's version history names
            // `WindowGroup(for: DocumentWindowID.self)` in prose first, and a block read from there
            // is the wrong block (measured: this test failed on `v2` until the anchor said so).
            let anchor = try #require(app.range(of: "WindowGroup(for: \(value).self) {"),
                                      "the iOS \(value) scene not found")
            let body = try #require(Self.balancedBlock(in: app, from: anchor.lowerBound))
            #expect(body.contains(".auxWindowOrigin(appState)"), "\(value)'s window lost its origin")
        }
    }

    @Test("The aux-window modifier publishes the close payload in both of its forms")
    func originModifierPublishesTheClosePayload() throws {
        let appState = try Self.source("App/AppState.swift")
        let anchor = try #require(appState.range(of: "struct AuxWindowOriginModifier: ViewModifier"))
        let body = try #require(Self.balancedBlock(in: appState, from: anchor.lowerBound))
        let code = Self.codeLines(String(body)).map(\.text)
        #expect(code.contains(".environment(\\.auxWindowClosing, appState.auxWindowClosing(origin: originRaw, launcher: launcherRaw))"),
                "the close payload must be published whether or not the scene identity is, and carry the launcher")
        #expect(code.contains("if republishesSceneID {"),
                "the scene identity is published only by the windows that borrow it")
        // Review round 1: an aux window is a launcher too.
        #expect(code.contains(".environment(\\.sceneID, appState.auxWindowSceneID(forOrigin: originRaw, standingIn: windowToken))"),
                "the borrowed identity must carry this window's own token, or a tool opened here records the main window")
        #expect(code.contains("SceneSessionReader { appState.registerAuxWindowSession($0, for: windowToken) }"),
                "and register this window's session under that token, or nothing can bring it back")
        #expect(code.contains("launcherRaw = appState.pendingAuxWindowLauncherRaw")
                && code.contains("appState.pendingAuxWindowLauncherRaw = nil"),
                "and drain the launcher it was opened from, beside its origin")
    }

    @Test("Each main window registers its UIKit session beside its scene token")
    func mainTabViewRegistersItsSession() throws {
        let code = Self.codeLines(try Self.source("App/MainTabView.swift")).map(\.text)
        #expect(code.contains { $0.contains("SceneSessionReader {") },
                "MainTabView must read its window's UISceneSession — a SwiftUI view cannot see it")
        #expect(code.contains { $0.contains("appState.registerSceneSession($0, for: SceneID(sceneIDToken))") },
                "and register it under the same token it registers as a live scene")
    }
}
