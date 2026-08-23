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

/// Can a reader actually reach Semantic Analytics?
///
/// Modelled on the archival family's entry-point suite, and written because promoting the semantic
/// map reproduced the defect that suite exists for. **#795 is a window that existed, was listed in
/// the menu-bar Analytics menu, and was unreachable from the main window** — the toolbar dropdown
/// had never been updated. The first draft of this promotion made exactly that mistake again: the
/// menu-bar item was added and the toolbar one was not, and nothing failed.
///
/// These are source assertions, which this repo rightly distrusts — a source scan cannot see a
/// default, a guard, or a control that renders under a status banner. What it *can* see is the class
/// of defect that actually recurs here: **two parallel lists that must agree and quietly stop
/// agreeing.** That is a text property, and text is what a text test is good for.
///
/// Version history:
///   1.0 — V-4: added when the semantic map became an analytics surface
///   1.1 — #1051 B-7: the iOS presentation pins follow the sheet to its `item:` form
///         (`SemanticMapSheetItem` — the #862 sibling-state fix)
@Suite("Semantic analytics — entry points")
struct SemanticAnalyticsEntryPointTests {

    /// Reads a source file from the app target.
    /// - Parameter relative: Path under `FRUSExplorer/`.
    /// - Returns: Its text.
    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The macOS window scene exists and both launchers front it")
    func macOSEntryPoints() throws {
        let app = try Self.source("App/FRUSExplorerApp.swift")
        #expect(app.contains("id: \"frus.semanticAnalytics\""),
                "no Window scene is registered for the semantic analytics window")
        #expect(app.contains("openWindow.fronting(id: \"frus.semanticAnalytics\")"), """
            The Analytics menu item must use the fronting helper (#749): a plain openWindow(id:) \
            leaves an already-open window buried behind the one in front.
            """)

        // The defect this file exists for. The toolbar dropdown's own comment says its membership
        // and order mirror the menu-bar menu deliberately, and names #795 as what happens when they
        // drift — so a window in one and not the other is the bug, not an omission of taste.
        let mainWindow = try Self.source("App/MainWindowView.swift")
        #expect(mainWindow.contains("openWindow.fronting(id: \"frus.semanticAnalytics\")"), """
            The main-window Analytics toolbar menu does not offer Semantic Analytics, so the window \
            is unreachable from the main window — the #795 shape exactly.
            """)
        // A toolbar launch binds THIS window as provenance where the menu bar clears it; getting
        // that backwards sends documents opened from the map to the wrong host.
        #expect(mainWindow.contains("appState.bindTool(.semanticAnalytics, to: hostID)"),
                "the toolbar launcher must bind its host window as provenance")
        #expect(app.contains("appState.bindTool(.semanticAnalytics, to: nil)"),
                "the menu-bar launcher must clear provenance, falling back to recency")

        // The two assertions above are only *about* anything if something reads the binding. It
        // shipped for a day written by both launchers and read by nobody, because the map's open
        // button minted a window directly — a provenance claim in the plan, the comments and this
        // very test, describing a route the code did not take.
        let map = try Self.source("Semantic/Map/SemanticMapSpikeView.swift")
        #expect(map.contains("from: .tool(.semanticAnalytics)"), """
            Nothing reads ToolWindowID.semanticAnalytics, so both bindTool calls above are dead and \
            the provenance assertions pass whichever way they are written. Route the map's open \
            through appState.openDocument(_:from:using:) — or drop the enum case and these tests.
            """)

        // The tooltip enumerates the tools by name, so a new window that is not in it is #795's
        // shape one layer down. This lagged a release behind its iOS twin.
        #expect(mainWindow.contains("Archival, and Semantic analytics"), """
            The macOS Analytics toolbar help string omits Semantic Analytics.
            """)
        // The text and the KEY are separate assertions on purpose: editing the string under the old
        // key is precisely the failure the versioned-key convention exists to prevent, and a test
        // that pinned only the text would pass through it.
        #expect(mainWindow.contains("mainwindow.tools.analytics.menu.help.v3"), """
            The tooltip text changed but the localization key did not. A new meaning needs a new \
            key (menu.help.vN), or every existing translation silently keeps the old wording.
            """)
        let browser = try Self.source("Browser/BrowserView.swift")
        #expect(browser.contains("browse.analysisTools.help.v3"),
                "same rule on iOS: the text changed, so the key must have too")
    }

    @Test("The iOS Analysis Tools menu offers it, presents it, and names it in its help")
    func iOSEntryPoint() throws {
        let source = try Self.source("Browser/BrowserView.swift")
        // #1051 B-7: the presentation is ONE item that carries the continuation — the
        // #862 sibling-state fix; the old `isPresented:` Bool beside a request var
        // measurably presented the sheet with the request still nil.
        #expect(source.contains("semanticMapSheet = SemanticMapSheetItem(request:"),
                "the Analysis Tools menu has no row that opens Semantic Analytics")
        // #363's unreachable-pane shape: a row that sets state nothing presents.
        #expect(source.contains(".sheet(item: $semanticMapSheet)"),
                "the row sets state nothing presents — the #363 unreachable-pane shape")
        // Prefix, not the whole call: CW-7c added a `continued:` argument for the Handoff
        // continuation, and this assertion is about the sheet presenting the view at all.
        #expect(source.contains("SemanticAnalyticsView(appState: appState"))
        // R-8: the iPadOS toolbar-overflow row re-derives its name from the label closure, so a
        // bare Image would ship an unnamed item.
        #expect(source.contains("browse.semanticAnalytics.a11y"),
                "the menu row needs a named Label, not a bare icon")
        #expect(source.contains("Semantic Analytics, and the corpus Word Cloud"), """
            The Analysis Tools help string enumerates the tools by name and must list this one. \
            Bump the key (help.vN) when the text changes rather than editing it in place.
            """)
    }

    /// The map is Metal, and a SwiftUI sheet on macOS never composites a Metal layer — the defect
    /// that cost two sessions. The window scene is the fix, so nothing may quietly turn it back into
    /// a sheet.
    @Test("macOS hosts the map in a window, never a sheet")
    func macOSNeverPresentsTheMapInASheet() throws {
        let dataRecovery = try Self.source("Settings/DataRecoveryView.swift")
        #expect(!dataRecovery.contains("SemanticMapSpikeView"), """
            Data & Recovery presents its sub-screens in a macOS sheet, where an MTKView draws, \
            presents, and never reaches the screen. The map must not return to that pane.
            """)
        #expect(!dataRecovery.contains("SemanticAnalyticsView"),
                "same reason: this pane's macOS presentation is a sheet")
    }
}
