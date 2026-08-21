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

/// Opening a macOS singleton window must also raise it (#749).
///
/// ## The invariant
/// `openWindow(id:)` reliably *creates* a closed singleton window, but does not always re-raise one
/// that is already open behind another — a gap the codebase measured and documented on
/// `bringMacWindowToFront(id:)` long before this issue. Every launcher therefore had to call the two
/// in sequence, by hand, at every site.
///
/// That is a rule, and rules get forgotten: the 2026-08 navigation audit found **11 of 56 sites**
/// unpaired, including seven of the nine main-window toolbar launchers, while the menu-bar
/// equivalents of those same actions all paired correctly. Two Analytics-menu items fronted and the
/// three beside them did not.
///
/// The consequence was worse than a dead button, because several tool windows retarget their content
/// from shared state as soon as a producer writes it, visible or not:
///
/// - the Word Cloud toolbar item seeds `.corpus` scope and the window's `onChange` consumes it, so a
///   buried cloud configured on a volume or collection was silently reset — the researcher's scope
///   gone, the window never surfacing to say so;
/// - `CrossReferenceGraphWindowView` binds `currentGraphEntry` live, so a buried graph switched to a
///   different document and only revealed it whenever the user next brought that window forward.
///
/// ## Why the fix is a single call rather than a lint rule
/// `OpenWindowAction.fronting(id:)` does both. There is no longer a second step to omit — the defect
/// is unrepresentable rather than merely discouraged. This suite exists to keep it that way: a bare
/// `openWindow(id:)` anywhere in app code fails the build.
///
/// Version history:
///   1.0 — Session 2026-08-08: #749
@Suite("macOS window fronting")
struct MacWindowFrontingTests {

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every `.swift` file under `FRUSExplorer/`, with its repo-relative path.
    private static func allSources() throws -> [(path: String, source: String)] {
        let root = appSourceRoot
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate \(root.path)")
            return []
        }
        var result: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            result.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    /// Code lines only — comments describe the old API constantly and must not trip the guard.
    private static func codeLines(_ source: String) -> [(line: Int, text: String)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.hasPrefix("//") && !$0.text.hasPrefix("///") && !$0.text.hasPrefix("*") }
    }

    // MARK: - The invariant

    /// Code lines that open a window without raising it.
    ///
    /// Extracted so it can be exercised against a literal fixture below. Inlined in the assertion,
    /// a mutation of the needle made the whole invariant pass vacuously — measured, not imagined:
    /// changing the match string to one that occurs nowhere left this suite green while every
    /// launcher was free to skip the raise again.
    ///
    /// `self(id: id)` inside `fronting(id:)` is the one legitimate raw invocation, and it is not
    /// spelled `openWindow(id:` — so it needs no exemption.
    static func bareOpenWindowSites(in source: String) -> [(line: Int, text: String)] {
        codeLines(source).filter { $0.text.contains("openWindow(id:") }
    }

    @Test("The bare-call matcher detects one, and does not flag the fronting helper")
    func matcherIsNotVacuous() {
        let offending = """
            Button {
                openWindow(id: "frus.search")
            } label: { Text("Search") }
            """
        #expect(Self.bareOpenWindowSites(in: offending).count == 1,
                "the matcher must detect a bare openWindow(id:), or the invariant passes vacuously")

        let correct = """
            Button {
                openWindow.fronting(id: "frus.search")
            } label: { Text("Search") }
            """
        #expect(Self.bareOpenWindowSites(in: correct).isEmpty,
                "openWindow.fronting(id:) is the correct call and must not be flagged")

        let commented = """
            // Producers open the window directly (openWindow(id: "frus.search")) alongside…
            /// Set immediately before openWindow(id: "frus.corpusBrowser") on macOS —
            """
        #expect(Self.bareOpenWindowSites(in: commented).isEmpty,
                "prose about the old API is everywhere in this codebase and must not fail the build")
    }

    @Test("Every launcher in the app uses the fronting helper")
    func everySiteConverted() throws {
        // The companion half of the vacuity guard: the matcher finding nothing is only meaningful
        // if there is a substantial population of converted sites to have found. 56 were converted
        // in #749; asserting a floor rather than the exact number keeps this from failing every
        // time a legitimate new window is added.
        var frontingSites = 0
        for (_, source) in try Self.allSources() {
            frontingSites += Self.codeLines(source).filter { $0.text.contains("openWindow.fronting(id:") }.count
        }
        #expect(frontingSites >= 50, """
            Only \(frontingSites) call sites use openWindow.fronting(id:). #749 converted 56. \
            A sharp drop means the launchers were removed or the helper was renamed — either way \
            the "no bare calls" invariant above is no longer proving anything.
            """)
    }

    @Test("No app code calls openWindow(id:) without fronting")
    func noBareOpenWindowByID() throws {
        var offenders: [String] = []
        for (path, source) in try Self.allSources() {
            for entry in Self.bareOpenWindowSites(in: source) {
                offenders.append("\(path):\(entry.line)  \(entry.text)")
            }
        }
        #expect(offenders.isEmpty, """
            These call openWindow(id:) directly, which leaves an already-open window buried (#749):
            \(offenders.joined(separator: "\n"))
            Use openWindow.fronting(id:) — it opens AND raises. The audit found 11 sites that had \
            split the pair; several silently retargeted a buried window's content (a Word Cloud's \
            scope, a Cross-Reference Graph's document) without ever surfacing it.
            """)
    }

    @Test("The helper actually opens and fronts — it is not a rename of one of them")
    func helperDoesBoth() throws {
        // Without this, `fronting(id:)` could be a thin alias for `openWindow(id:)` and the
        // invariant above would pass while every window stayed buried — a rename that reads as a fix.
        let source = try Self.source("App/MainWindowView.swift")
        let start = try #require(source.range(of: "func fronting(id: String)"))
        let body = String(source[start.lowerBound...].prefix(220))
        #expect(body.contains("self(id: id)"), "fronting(id:) must actually open the window")
        #expect(body.contains("bringMacWindowToFront(id: id)"), "fronting(id:) must actually raise it")
    }

    @Test("Fronting is applied to the same id that was opened")
    func helperUsesOneID() throws {
        // A pair that opened one window and raised another would be invisible in review and is
        // exactly the kind of copy-paste slip that hand-pairing invited.
        let source = try Self.source("App/MainWindowView.swift")
        let start = try #require(source.range(of: "func fronting(id: String)"))
        let body = String(source[start.lowerBound...].prefix(220))
        #expect(!body.contains("bringMacWindowToFront(id: \""),
                "fronting(id:) must raise the id it was given, never a literal")
    }

    // MARK: - The sites the audit named

    @Test("The nine main-window toolbar launchers all front")
    func toolbarLaunchersFront() throws {
        // Named individually because the invariant above also passes if a launcher is deleted.
        // `frus.archivalAnalytics` (#795) and `frus.history` (#652) were both added in 2026-08;
        // each had existed as a window with no toolbar door for months, which is the failure this
        // roster exists to make loud.
        let source = try Self.source("App/MainWindowView.swift")
        for windowId in ["frus.search", "frus.corpusBrowser", "frus.analytics",
                         "frus.archivalAnalytics", "frus.chronology", "frus.wordcloud",
                         "frus.research", "frus.collections", "frus.history"] {
            #expect(source.contains("openWindow.fronting(id: \"\(windowId)\")"),
                    "the main-window toolbar launcher for \(windowId) must front it (#749 / M-12)")
        }
    }

    @Test("Document graph openings are keyed by document, so nothing retargets")
    func graphContextMenusOpenByValue() throws {
        // **M-13's concern is dissolved, not relaxed, and the difference matters.** That finding
        // was: these menus retarget `currentGraphEntry`, which the window bound LIVE, so a buried
        // graph silently became a different document's graph. #749's remedy was to make the
        // retarget VISIBLE (open-and-raise) — the best available fix while one window read one
        // global.
        //
        // M-2 removed the global from the path: a document opening is now `openWindow(value:)`
        // with a `GraphWindowRequest`, so a second document opens a SECOND WINDOW and there is no
        // retarget left to make visible. Asserting `fronting(id:)` here would now be asserting the
        // absence of the fix.
        for relative in ["App/MacCorpusBrowserWindow.swift", "Research/ResearchView.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("openWindow(value: GraphWindowRequest(entry:"),
                    "\(relative) must open a document's graph BY VALUE — an id-based open would reuse one window and retarget it, which is #749 / M-13 all over again")
        }

        // The volume hand-off keeps its id-based fronting deliberately: a volume graph has no
        // document to key on, and the window consumes `pendingVolumeGraph` itself. The scene keeps
        // an `id` precisely so this and the cold Window-menu door still have a way in.
        let browser = try Self.source("App/MacCorpusBrowserWindow.swift")
        #expect(browser.contains("openWindow.fronting(id: \"frus.crossReferenceGraph\")"),
                "the VOLUME graph hand-off must still front by id — it has no request to key on")
    }

    @Test("Complete History… and About front their windows")
    func lowSeveritySitesFront() throws {
        #expect(try Self.source("App/HistoryWindowView.swift")
            .contains("openWindow.fronting(id: \"frus.history\")"),
                "Complete History… must front the History window (#749 / L-34)")
        // Matches the CALL, not a closing paren. The About window still fronts; #824 gave it a
        // `value:` (`fronting(id:value:)`, MainWindowView.swift:569, a real fronting overload) and
        // this literal stopped matching a working call. That is the failure mode of asserting a
        // spelling instead of a behaviour, and it left v2 red rather than catching anything.
        #expect(try Self.source("App/FRUSExplorerApp.swift")
            .contains("openWindow.fronting(id: \"about\""),
                "About FRUS Explorer must front the About window (#749 / L-34)")
    }

    // MARK: - L-37: the shortcut has to run code

    @Test("⌘⇧B is a menu command, not a bare scene shortcut")
    func corpusBrowserShortcutRunsCode() throws {
        let source = try Self.source("App/FRUSExplorerApp.swift")

        // A shortcut declared on a Window scene runs no app code, so it can never front a buried
        // window. Assert it is gone from the scene by checking the scene declaration's own region.
        let sceneStart = try #require(source.range(of: #"Window("Corpus Browser", id: "frus.corpusBrowser")"#))
        let sceneRegion = String(source[sceneStart.lowerBound...].prefix(700))
        #expect(!sceneRegion.contains(#".keyboardShortcut("b", modifiers: [.command, .shift])"#), """
            ⌘⇧B is declared on the Corpus Browser Window scene again. A scene-level shortcut runs no \
            code (AppState.bindTool's doc comment relies on exactly that), so it cannot front an \
            open-but-buried browser — and it appears on no menu item (#749 / L-37).
            """)

        // And it must exist as a real command that fronts.
        // It lives in FIND, beside Search and Citation Lookup — all three answer "find me
        // something in the corpus". Not Window: macOS auto-generates an entry there for every
        // `Window` scene, so an item of ours beside it was a visible duplicate (#822).
        #expect(!source.contains("menu.research.corpusBrowser"),
                "stale key: the item no longer sits in the Research menu")
        #expect(!source.contains("menu.window.corpusBrowser"), """
            stale key: an item in the Window menu duplicates the entry macOS generates there for \
            the Corpus Browser `Window` scene.
            """)
        let menuStart = try #require(source.range(of: "menu.find.corpusBrowser"))
        let menuRegion = String(source[menuStart.lowerBound...].prefix(400))
        #expect(menuRegion.contains("openWindow.fronting(id: \"frus.corpusBrowser\")"),
                "the Corpus Browser menu command must front the window")
        #expect(menuRegion.contains(#".keyboardShortcut("b", modifiers: [.command, .shift])"#),
                "the Corpus Browser menu command must carry ⌘⇧B")
    }

    // MARK: - L-35: the Search window takes keyboard focus

    @Test("The Search window focuses its query field on open and on every re-summon")
    func searchWindowTakesFocus() throws {
        let source = try Self.source("App/SearchSheet.swift")
        #expect(source.contains("@FocusState private var queryFieldFocused"),
                "MacSearchWindowView needs focus state — it had none at all (#749 / L-35)")
        #expect(source.contains(".focused($queryFieldFocused)"),
                "the query field must be bound to that focus state")
        #expect(source.contains("appState.searchQueryFocusToken"), """
            the Search window must observe searchQueryFocusToken. Re-fronting a singleton window \
            runs no code inside it and never resets first responder, so without this ⌘S left the \
            caret whereever it was — typing a query drove the result-list selection.
            """)
    }

    @Test("Only the two type-a-query producers bump the focus token")
    func onlyDeliberateProducersStealFocus() throws {
        // Parameter hand-offs (Corpus Analytics → Search, a saved search, a facet drill-in) arrive
        // pre-filled and the user's next action is reading results. Stealing focus there would be
        // its own bug, so the token must NOT be bumped by every producer.
        var bumpSites: [String] = []
        for (path, source) in try Self.allSources() {
            for entry in Self.codeLines(source) where entry.text.contains("searchQueryFocusToken &+=") {
                bumpSites.append(path)
            }
        }
        #expect(Set(bumpSites) == ["App/FRUSExplorerApp.swift", "App/MainWindowView.swift"], """
            searchQueryFocusToken should be bumped only by ⌘S (Find menu) and the main-window \
            toolbar Search button — the two places the user is asking to type. Found: \
            \(bumpSites.sorted().joined(separator: ", ")).
            """)
    }

    // MARK: - L-36: the label matches what the action does

    @Test("The Research context item no longer promises the main window")
    func researchLabelIsHonest() throws {
        let source = try Self.source("Research/ResearchView.swift")
        // Code lines only: the replacement's own comment quotes the old label to explain why it
        // changed, and that explanation is worth keeping.
        let stillPromises = Self.codeLines(source).filter { $0.text.contains("Open in Main Window") }
        #expect(stillPromises.isEmpty, """
            The Research context item claims "Open in Main Window", but the macOS action routes \
            through the provenance chain — the window Research was launched from, else the \
            most-recently-key host, else a freshly minted standalone window. None is necessarily a \
            main window (#749 / L-36).
            """)
        #expect(source.contains("research.action.openDocument.v2"),
                "the replacement label must use a NEW key — defaultValue is the shipped string")
    }
}
