// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

/// Two macOS chrome defects from the UI review, both fixable and testable without a Mac
/// (UI review M-10 and M-8).
///
/// Version history:
///   1.0 — CW-10b
///   1.1 — 2026-10-21: #1761 — the Search window's filter chip ✕
///   1.2 — L21 (#1921): MAC-1, the main window's title and centre, beside M-8's tests; MAC-6, the
///          empty main window's two ways in
@Suite("Mac chrome honesty")
struct MacChromeHonestyTests {

    // MARK: - M-10 · the search-scope chip wired to nothing

    /// The repository root, found by walking up from this file.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads a source file under the app target.
    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// One property's declaration, ending where the next property at the same indent begins.
    ///
    /// **A fixed-length window does not work here, and mutation testing is what proved it.** The
    /// first version of this helper took 400 characters from the declaration; re-introducing the
    /// dead `scopeCollections` immediately above `scopeNotes` put *that* property's `didSet`
    /// inside the window, so the test passed with the defect restored. It looked like coverage
    /// and was measuring the wrong property.
    ///
    /// - Parameters:
    ///   - property: The property name.
    ///   - source: The view model's source.
    /// - Returns: The declaration text, or `""` when the property is absent.
    private static func declarationBody(of property: String, in source: String) -> String {
        guard let start = source.range(of: "var \(property): Bool") else { return "" }
        let rest = source[start.upperBound...]
        // The next stored property at type scope. Everything before it belongs to this one.
        guard let next = rest.range(of: "\n    var ") else { return String(rest) }
        return String(rest[..<next.lowerBound])
    }

    /// Every scope the Mac search chrome offers must reach the query.
    ///
    /// **This is the invariant, not "the Collections chip is gone".** The defect was a control
    /// whose stored property nothing read: `scopeCollections` had no `didSet`, no projection into
    /// `parameters`, and exactly one reader in the codebase — the chip's own binding. So the test
    /// asserts the *rule* — that each `ScopeChip` in the scope row binds to a property the view
    /// model actually forwards — which a re-added Collections chip would also have to satisfy.
    @Test("every scope chip binds to a scope the view model forwards")
    func everyScopeChipIsWired() throws {
        let sheet = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let viewModel = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")

        // The properties each `ScopeChip(...)` in the scope row binds to.
        var bound: [String] = []
        for line in sheet.components(separatedBy: .newlines) where line.contains("ScopeChip(") {
            guard let range = line.range(of: "isOn: $searchVM.") else { continue }
            let tail = line[range.upperBound...]
            let name = tail.prefix { $0.isLetter || $0.isNumber }
            if !name.isEmpty { bound.append(String(name)) }
        }

        // Guard against a vacuous pass: if the parse finds nothing, every assertion below is
        // trivially true and the suite would go green having measured nothing.
        #expect(bound.count >= 3, "expected the scope chips, parsed \(bound)")

        for property in bound {
            // A forwarded scope declares a `didSet`. The dead one was `var x: Bool = false` with
            // a trailing comment and nothing else.
            #expect(viewModel.contains("var \(property): Bool") ,
                    "\(property) is bound by a ScopeChip but is not declared on MacSearchViewModel")
            let declaration = Self.declarationBody(of: property, in: viewModel)
            #expect(declaration.contains("didSet"),
                    "The '\(property)' scope chip is a live control bound to a property that nothing reads — toggling it cannot change the results. Wire it through `parameters`, disable it with a visible reason, or remove the chip (M-10).")
        }
    }

    // MARK: - M-8 · the toolbar centre

    @Test("a resolved volume and document number name the location")
    func principalNamesLocation() {
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "Soviet Union · 1969-76 v20",
                                                documentNumber: "475",
                                                documentId: "frus1969-76v20/d475")
                == "Soviet Union · 1969-76 v20 · Doc 475")
    }

    @Test("a document with no number still names its volume")
    func noDocumentNumber() {
        // Editorial notes and front-matter sections carry no document number; the volume is
        // still the orientation this strip exists to give.
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "1969-76 v20",
                                                documentNumber: nil,
                                                documentId: "frus1969-76v20/comp1")
                == "1969-76 v20")
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "1969-76 v20",
                                                documentNumber: "",
                                                documentId: "frus1969-76v20/comp1")
                == "1969-76 v20")
    }

    @Test("an unknown volume falls back to the id rather than inventing one")
    func unknownVolumeFallsBack() {
        // A window restored for a volume no longer in the manifest. The id is what this strip
        // showed before M-8, so the degraded state keeps the old behaviour.
        #expect(MacDocumentTitle.principalLabel(volumeLabel: nil,
                                                documentNumber: "475",
                                                documentId: "frus1946v06/d475")
                == "frus1946v06/d475")
        #expect(MacDocumentTitle.principalLabel(volumeLabel: "",
                                                documentNumber: "475",
                                                documentId: "frus1946v06/d475")
                == "frus1946v06/d475")
    }

    @Test("the fallback is what keeps the monospaced face")
    func fallbackDrivesTypeface() {
        // The view branches on this: an id stays monospaced, prose does not. A monospaced head
        // reads as machine output, which is half of what M-8 objects to in the first place. Since
        // L38 (F2) the centre is the head, so the fallback is a head that is empty.
        #expect(MacDocumentTitle.isFallback(header: ""))
        #expect(!MacDocumentTitle.isFallback(header: "The Chargé in the Soviet Union (Kennan) to the Secretary of State"))
    }

    @Test("the strip never carries the volume-title boilerplate")
    func noBoilerplate() {
        // The regression guarded: passing `entry.title` instead of the distilled form would fill
        // the window's most valuable strip with "Foreign Relations of the United States, …" —
        // the exact problem #237 built the iOS two-line title to see past.
        let distilled = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1946v06",
            subseries: "1946",
            title: "Foreign Relations of the United States, 1946, Volume VI, Eastern Europe")
        let label = MacDocumentTitle.principalLabel(volumeLabel: distilled,
                                                   documentNumber: "475",
                                                   documentId: "frus1946v06/d475")
        #expect(!label.contains("Foreign Relations"))
        #expect(label.contains("Doc 475"))
    }

    // MARK: - MAC-1 · the main window's title and centre (L21, #1921)

    /// F2 (L38, decision 213): the title is where the document is, the centre what it is. L21's
    /// test here held the title to the head; the owner chose this layout over it after R6 found the
    /// head cut in almost every window (at 1,200 pt, "The Chargé in the Soviet Union (Kenn…").
    @Test("a document window is titled with its volume's tag and its number, and its centre is the head (F2)")
    func windowTitleIsTheVolumeAndNumber() {
        #expect(MacDocumentTitle.windowTitle(volumeTag: "1946 v6", documentNumber: "475", documentId: "d475")
                == "1946 v6 · Doc 475")
        // A document the volume prints without a number, as the centre named it until L38.
        #expect(MacDocumentTitle.windowTitle(volumeTag: "1945 Berlin v02",
                                             documentNumber: "[Unnumbered document following Document 710 (#1)]",
                                             documentId: "d710a-1")
                == "1945 Berlin v02 · Unnumbered (d710a-1)")
        // One with no number of its own adds its id, so two on one volume read apart.
        #expect(MacDocumentTitle.windowTitle(volumeTag: "1946 v6", documentNumber: nil, documentId: "persons")
                == "1946 v6 · persons")
        #expect(MacDocumentTitle.windowTitle(volumeTag: "1946 v6", documentNumber: "", documentId: "terms")
                == "1946 v6 · terms")
        // A volume the manifest does not hold leaves the id alone.
        #expect(MacDocumentTitle.windowTitle(volumeTag: nil, documentNumber: "475", documentId: "d475") == "d475")
        // The centre: the head, or the id when there is none.
        #expect(MacDocumentTitle.headTitle(header: "The Chargé in the Soviet Union (Kennan) to the Secretary of State",
                                           documentId: "d475")
                == "The Chargé in the Soviet Union (Kennan) to the Secretary of State")
        #expect(MacDocumentTitle.headTitle(header: "", documentId: "d475") == "d475")
    }

    /// The entry's form, as both windows call it: the tag from the bundled manifest, and the number
    /// from the id when the entry carries none, as Research's rows open documents.
    @Test("an entry opened from Research is titled with its volume's tag and the number its id spells (F2)")
    @MainActor
    func windowTitleForAnEntry() throws {
        let volume = try #require(ManifestStore().entry(forVolumeId: "frus1946v06"),
                                  "the bundled manifest has no frus1946v06")
        let entry = DocumentBrowserEntry(documentId: "d475", volumeId: "frus1946v06",
                                         header: "The Chargé in the Soviet Union (Kennan) to the Secretary of State")
        #expect(MacDocumentTitle.windowTitle(for: entry, volume: volume) == "1946 v6 · Doc 475")
        #expect(MacDocumentTitle.windowTitle(for: entry, volume: nil) == "d475")
    }

    @Test("the centre names the number the entry carries, or the one its id spells")
    func principalNumberFallsBackToTheId() {
        // A stored number wins, the editors' bracketed description included, which the label
        // turns into "Unnumbered (d710a-1)".
        #expect(MacDocumentTitle.principalNumber(stored: "475", documentId: "d475") == "475")
        let bracketed = "[Unnumbered document following Document 710 (#1)]"
        #expect(MacDocumentTitle.principalNumber(stored: bracketed, documentId: "d710a-1") == bracketed)
        // Research's rows and the Corpus Browser open documents with no number: the id stands in
        // where it is the number, and nowhere else.
        #expect(MacDocumentTitle.principalNumber(stored: nil, documentId: "d475") == "475")
        #expect(MacDocumentTitle.principalNumber(stored: "", documentId: "d373a") == "373a")
        #expect(MacDocumentTitle.principalNumber(stored: nil, documentId: "ch1") == nil)
        #expect(MacDocumentTitle.principalNumber(stored: nil, documentId: "d710a-1") == nil)
        // So three same-headed telegrams opened from Research no longer read alike in the centre.
        let labels = ["d474", "d475", "d476"].map {
            MacDocumentTitle.principalLabel(volumeLabel: "1946 v6",
                                            documentNumber: MacDocumentTitle.principalNumber(stored: nil, documentId: $0),
                                            documentId: $0)
        }
        #expect(labels == ["1946 v6 · Doc 474", "1946 v6 · Doc 475", "1946 v6 · Doc 476"])
    }

    /// The source gate for MAC-1 (#1921): the main window titles itself by the open document and
    /// draws the standalone window's centre, by the same rule and the same view as the standalone
    /// window. Since L38 (F2) the rule's title is the volume and number, and the centre the head.
    ///
    /// Before L21 the main window set no `.navigationTitle`, so every main window read "FRUS
    /// Explorer" in the Window menu, and its centre was `Text(entry.id)`, the raw
    /// `frus1946v06/d475`. The unit target runs no Mac code, so this reads the source, comments
    /// blanked; the check copy shows the windows themselves.
    @Test("both document windows take their title and their centre from one rule and one view (MAC-1)")
    func bothWindowsShareTheTitleAndTheCentre() throws {
        let main = NaturalLanguageReadinessScanTests.code(try Self.source("FRUSExplorer/App/MainWindowView.swift"))
        let standalone = NaturalLanguageReadinessScanTests.code(try Self.source("FRUSExplorer/App/MacDocumentView.swift"))
        let flat = { (text: String) in text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

        // The main window: a title from the open document, the app's name only while none is open.
        #expect(main.contains(".navigationTitle(windowTitle)"), "the main window sets no title of its own")
        let title = try #require(main.range(of: "private var windowTitle: String"),
                                 "MainWindowView has no windowTitle")
        let titleBody = try #require(NaturalLanguageReadinessScanTests.braceBody(in: main, after: title.upperBound))
        #expect(flat(String(main[titleBody])).contains(
            "return MacDocumentTitle.windowTitle(for: entry, volume: appState.manifestStore.entry(forVolumeId: entry.volumeId))"),
                "the main window's title does not follow the standalone window's rule: \(main[titleBody])")

        // Its centre: the shared view, capped by the width budget; never the raw id again.
        let centre = try #require(main.range(of: "private var documentTitle: some View"),
                                  "MainWindowView has no documentTitle")
        let centreBody = flat(String(main[try #require(
            NaturalLanguageReadinessScanTests.braceBody(in: main, after: centre.upperBound))]))
        #expect(centreBody.contains("MacDocumentPrincipalTitle(entry: entry) .frame(maxWidth: pillBudget)"),
                "the main window's centre is not the shared view under its width budget: \(centreBody)")
        #expect(!centreBody.contains("Text(entry.id)"), "the main window's centre prints the raw id again")

        // The standalone window takes the same two.
        #expect(flat(standalone).contains(
            ".navigationTitle(MacDocumentTitle.windowTitle(for: currentEntry, volume: appState.manifestStore.entry(forVolumeId: currentEntry.volumeId)))"),
                "the standalone window's title no longer goes through MacDocumentTitle.windowTitle")
        #expect(flat(standalone).contains(
            "ToolbarItem(placement: .principal) { MacDocumentPrincipalTitle(entry: currentEntry) }"),
                "the standalone window's centre is not the shared view")
    }

    // MARK: - MAC-6 · the empty first window (L21, #1921)

    /// The source gate for MAC-6 (#1921): the empty main window offers **Search** and **Browse the
    /// Corpus** as buttons that run the toolbar's own actions, and its hint is `.secondary`.
    ///
    /// Before L21 the window said "Select a document to begin" with nothing to select, and its one
    /// instruction was `.tertiary`, the grey the HIG reserves for what is unavailable (1.88:1 on
    /// the `macos/research` capture). Each action is one function both doors call, so a click in
    /// the window and a click in the toolbar cannot come to differ: the provenance bind, the
    /// Search field's focus and the fronting of an open window go with both.
    @Test("the empty main window offers Search and Browse the Corpus, the toolbar's own actions, under a secondary hint (MAC-6)")
    func emptyWindowOffersTheTwoWaysIn() throws {
        let main = NaturalLanguageReadinessScanTests.code(try Self.source("FRUSExplorer/App/MainWindowView.swift"))
        let flat = { (text: String) in text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let body = { (anchor: String) throws -> String in
            let start = try #require(main.range(of: anchor), "MainWindowView has no \(anchor)")
            return flat(String(main[try #require(NaturalLanguageReadinessScanTests.braceBody(in: main, after: start.upperBound))]))
        }

        let placeholder = try body("private struct DocumentPlaceholderView: View")
        #expect(placeholder.contains(
            #"defaultValue: "Use Search (⌥⌘F) or open the Corpus Browser (⇧⌘B)")) .font(.callout) .foregroundStyle(.secondary)"#),
                "the hint is not drawn in .secondary: \(placeholder)")
        #expect(!placeholder.contains(".font(.callout) .foregroundStyle(.tertiary)"),
                "the hint is back in .tertiary, the grey for what is unavailable")
        #expect(placeholder.contains("Button(action: onSearch)"), "the empty window offers no Search button")
        #expect(placeholder.contains("Button(action: onBrowse)"), "the empty window offers no Browse the Corpus button")

        // The window hands the placeholder the toolbar's own two actions.
        #expect(flat(main).contains(
            "DocumentPlaceholderView(onResume: { navigationPath.append($0) }, onSearch: openSearch, onBrowse: openCorpusBrowser)"),
                "the placeholder is not handed the toolbar's actions")
        let tools = try body("private var trailingTools: some View")
        #expect(tools.contains("Button { openSearch() } label:"), "the toolbar's Search button runs another action")
        #expect(tools.contains("Button { openCorpusBrowser() } label:"), "the toolbar's Browse button runs another action")
        let search = try body("private func openSearch()")
        #expect(search == "appState.bindTool(.search, to: hostID) appState.searchQueryFocusToken &+= 1 openWindow.fronting(id: \"frus.search\")",
                "openSearch() no longer binds, focuses and fronts: \(search)")
        let browse = try body("private func openCorpusBrowser()")
        #expect(browse == "appState.bindTool(.corpusBrowser, to: hostID) openWindow.fronting(id: \"frus.corpusBrowser\")",
                "openCorpusBrowser() no longer binds and fronts: \(browse)")
    }

    // MARK: - #1761 · the Search window's filter chip ✕

    /// S4 of the build-51 screenshot sweep measured the Date chip's *Clear Date filter* at 8 by 8 points by
    /// accessibility, a click 2 points off it doing nothing, and read the chip's own help on it. The chip's padding now
    /// belongs to its two parts, and its help to its editor alone; the click and the help themselves are checked in the
    /// Mac check copy, since the unit target runs no Mac code.
    @Test("the filter chip's ✕ takes the chip's trailing end at its full height, and the editor's help is the editor's")
    func filterChipClearTargetAndHelp() throws {
        let source = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let start = try #require(source.range(of: "private func filterTokenView(_ token: SearchFilterToken) -> some View"),
                                 "filterTokenView is no longer in SearchSheet.swift")
        let range = try #require(NaturalLanguageReadinessScanTests.braceBody(in: source, after: start.upperBound))
        let body = NaturalLanguageReadinessScanTests.code(String(source[range]))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(body.contains("filterTokenEditor(token) .padding(.leading, 9) .padding(.vertical, 3) "
                              + ".help(editorHelpText(for: token.field))"),
                "the editor carries the leading and vertical padding and its own help: \(body)")
        #expect(body.contains("Image(systemName: \"xmark\") .font(.caption2.weight(.bold)) "
                              + ".foregroundStyle(Color.accentColor) .padding(.leading, 4) .padding(.trailing, 9) "
                              + ".frame(maxHeight: .infinity) .contentShape(Rectangle())"),
                "the ✕'s label is its glyph alone again: \(body)")
        #expect(body.components(separatedBy: ".help(editorHelpText(").count - 1 == 1,
                "the editor's help is set more than once, so it reaches the ✕ again")
        #expect(!body.contains(".padding(.horizontal, 9)"), "the chip's own padding is back outside the ✕")
    }
}

// MARK: - Mac W-11 · text scaling holds its ground

/// The macOS text-scaling conversion's regrowth guard (Mac W-11 / M-5, shipped in W-2c).
///
/// ## What was converted, and why a guard rather than a memory
/// M-5 deferred "262 fixed-point text sites" in six macOS chrome files. Re-measured at W-2c,
/// 150 of them had already evaporated in the Settings/History consolidations — and SearchSheet
/// had GROWN by 13, because the convention existed and nothing enforced it. The remaining 112
/// were converted to semantic styles by the macOS column of `FRUSTheme`'s table (macOS resolves
/// the same styles smaller than iOS, so the iOS column would have shrunk the chrome). This
/// suite is what stops the file list re-growing after the pass.
///
/// ## The survivor is pinned as EXACTLY present, not merely tolerated
/// A ceiling alone goes vacuous when a refactor deletes the carve-out sites; asserting them
/// present keeps the allowlist honest. There were two until L21 (MAC-1), when the main window's
/// monospaced identity pill became prose and its file joined the zero-literal list.
@Suite("Mac text scaling (W-11)")
struct MacTextScalingAuditTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Lines carrying a fixed-point text size — a numeric literal inside `system(size:`.
    /// A scaled metric (`system(size: FRUSTheme.cappedGlyphSize(…)`) is not a literal and
    /// does not count.
    private static func fixedSizeLines(_ relativePath: String) throws -> [String] {
        let source = try String(contentsOf: repoRoot.appending(path: "FRUSExplorer/\(relativePath)"),
                                encoding: .utf8)
        return source.components(separatedBy: .newlines).filter {
            $0.range(of: #"system\(size:\s*[0-9]"#, options: .regularExpression) != nil
        }
    }

    @Test("The converted files carry no fixed-point text sites beyond the carve-out")
    func convertedFilesStayConverted() throws {
        // Zero-literal files: a new `.font(.system(size: N))` here is the debt returning —
        // use the macOS column of FRUSTheme's size→style table instead. MainWindowView joined the
        // list at L21 (MAC-1): its monospaced 12 pt pill, the carve-out it held, became the
        // standalone window's `MacDocumentPrincipalTitle`, prose in `.body`.
        for file in ["App/SupportingViews.swift", "App/SearchSheet.swift",
                     "Settings/FRUSSettingsView.swift", "App/HistoryWindowView.swift",
                     "App/MainWindowView.swift"] {
            let lines = try Self.fixedSizeLines(file)
            #expect(lines.isEmpty, """
                \(file) gained a fixed-point text site after the W-11 conversion: \
                \(lines.first ?? ""). Fixed sizes ignore the user's text-size setting — convert \
                by the macOS column of FRUSTheme's table (11 → .subheadline, 12 → .callout, \
                13 → .body, ≤10 → .caption2), chaining .weight() where the site had one.
                """)
        }

        // The documented carve-out, pinned as present so the allowlist cannot go vacuous: the
        // chevron centred in a fixed 34×34 hit circle, LEAVE-FIXED with its reason at the site.
        // (The width-budgeted monospaced identity pill was the other until L21; see above.)
        let reader = try Self.fixedSizeLines("App/MacDocumentView.swift")
        #expect(reader.count == 1, "MacDocumentView allows exactly the 34×34 chevron: \(reader)")
        #expect(reader.first?.contains("weight: .semibold") == true)
    }
}

// MARK: - SelectGlyphTests

/// The glyph beside a "Select a bar" hint is the platform's own (#1380).
///
/// #1380 moved the Mac off `hand.tap` to a clicking pointer, behind `#if os(macOS)` in
/// `FRUSTheme.selectGlyph`. This target runs on iOS only, so it cannot see the Mac branch — the
/// source scan `CodingStandardsAuditTests.macTextNeverSaysTap` holds that side, refusing any
/// `hand.tap` literal the Mac compiles. What this holds is the other side: iPhone and iPad keep the
/// tapping hand they had. It passes on `v2`'s behaviour by design, so it is a control, not a
/// regression guard for the Mac, and it fails on any iOS destination if the iOS branch changes.
///
/// Version history:
///   1.0 — 2026-09-25: #1380
struct SelectGlyphTests {

    /// iOS draws the tapping hand, as it did before #1380.
    @Test("iOS keeps the tapping hand beside a select hint (#1380)")
    func iOSKeepsTheTappingHand() {
        #expect(FRUSTheme.selectGlyph == "hand.tap")
    }
}

// MARK: - MacShortcutCopyTests

/// The shortcuts the Mac's on-screen text names are the ones its Find menu registers (lane HYG).
///
/// ## The defect it stops
/// Full-text Search has had three key equivalents: ⌘F, then ⌘S when ⌘F became Find in Document
/// (#363 #5), then ⌥⌘F when UI review M-14 gave ⌘S back to Save. Each move changed the
/// `.keyboardShortcut` and left text behind. Until lane HYG the main window's toolbar tooltip
/// still read "Open the full-text search window (⌘F)" — the key that opens the find bar — and its
/// empty-state hint read "Use Search (⌘S)", a key the app binds to nothing. A reader who pressed
/// what the screen told them got a find bar, or nothing.
///
/// ## The rule
/// The shortcut is read from `FindMenuContent`, where it is registered — the `.keyboardShortcut(`
/// that follows the menu item's own key, parsed by its balanced parentheses — and each string that
/// names it is read from its `defaultValue:`. Their parenthesised glyph groups are compared as
/// SETS, because the app writes ⌘⇧B in one string and ⇧⌘B in another and both are the same keys.
///
/// This target runs on iOS and these strings are the Mac's, so the test reads source and gives the
/// same result on every destination. What a Mac window shows is the owner's check.
///
/// Version history:
///   1.0 — lane HYG (2026-10-01): initial implementation
///   1.1 — FRUSCoreKit, part 1: the stale-shortcut scan reads `FRUSCoreKit/` as well as
///          `FRUSExplorer/`, through `AppSourceTree`, and names each file from the repository root
@Suite("Mac shortcut copy")
struct MacShortcutCopyTests {

    /// The repository root, found by walking up from this file.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads a source file under the app target.
    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Why a reader below could not read what it was asked for. Thrown, not recorded with
    /// `#require`, so the fixture test can expect it without the expectation itself failing.
    struct ReadError: Error, CustomStringConvertible {
        let description: String
    }

    /// The keys a registered shortcut presses: its modifier glyphs and its key, upper-cased.
    ///
    /// Reads the first `.keyboardShortcut(` after the menu item keyed `menuKey` in `source`, and
    /// requires that no other `Button(` comes between them, so the shortcut is that item's own.
    static func registeredKeys(of menuKey: String, in source: String) throws -> Set<Character> {
        guard let anchor = source.range(of: "localized: \"\(menuKey)\"") else {
            throw ReadError(description: "no menu item is keyed \(menuKey)")
        }
        guard let call = source.range(of: ".keyboardShortcut(", range: anchor.upperBound..<source.endIndex) else {
            throw ReadError(description: "no .keyboardShortcut( follows \(menuKey)")
        }
        guard !source[anchor.upperBound..<call.lowerBound].contains("Button(") else {
            throw ReadError(description: "another Button( sits between \(menuKey) and the next shortcut, "
                                + "so that shortcut is not this item's")
        }
        let open = source.index(before: call.upperBound)
        var depth = 0
        var close = open
        for index in source[open...].indices {
            if source[index] == "(" { depth += 1 }
            if source[index] == ")" { depth -= 1 }
            if depth == 0 { close = index; break }
        }
        guard close > open else {
            throw ReadError(description: "\(menuKey)'s .keyboardShortcut( never closes")
        }
        let arguments = String(source[source.index(after: open)..<close])
        // `"f", modifiers: [.command, .option]` — the key is the one quoted character.
        let quoted = arguments.split(separator: "\"", omittingEmptySubsequences: false)
        guard quoted.count == 3, quoted[1].count == 1 else {
            throw ReadError(description: "\(menuKey)'s shortcut is not a one-character key: \(arguments)")
        }
        var keys: Set<Character> = [Character(quoted[1].uppercased())]
        let glyphs: [(modifier: String, glyph: Character)] = [
            (".command", "⌘"), (".option", "⌥"), (".shift", "⇧"), (".control", "⌃"),
        ]
        for (modifier, glyph) in glyphs where arguments.contains(modifier) { keys.insert(glyph) }
        return keys
    }

    /// The parenthesised groups of `text` that name a shortcut — each holds ⌘ — as key sets, in order.
    static func namedShortcuts(in text: String) -> [Set<Character>] {
        var groups: [Set<Character>] = []
        var rest = text[...]
        while let open = rest.firstIndex(of: "("), let close = rest[open...].firstIndex(of: ")") {
            let inside = rest[rest.index(after: open)..<close]
            if inside.contains("⌘") { groups.append(Set(inside)) }
            rest = rest[rest.index(after: close)...]
        }
        return groups
    }

    /// Whether `text` names ⌘S itself: not ⇧⌘S or ⌥⌘S, which are other shortcuts, and not the
    /// start of a word such as ⌘Space.
    static func namesBareCommandS(_ text: String) -> Bool {
        var rest = text[...]
        while let hit = rest.range(of: "⌘S") {
            let before = hit.lowerBound > text.startIndex ? text[text.index(before: hit.lowerBound)] : " "
            let after = hit.upperBound < text.endIndex ? text[hit.upperBound] : " "
            if !"⌥⇧⌃".contains(before), !after.isLetter { return true }
            rest = rest[hit.upperBound...]
        }
        return false
    }

    /// The `defaultValue:` of the string keyed `key` in `source`.
    static func defaultValue(of key: String, in source: String) throws -> String {
        guard let anchor = source.range(of: "localized: \"\(key)\"") else {
            throw ReadError(description: "no string is keyed \(key)")
        }
        guard let label = source.range(of: "defaultValue: \"", range: anchor.upperBound..<source.endIndex) else {
            throw ReadError(description: "\(key) has no defaultValue")
        }
        let rest = source[label.upperBound...]
        guard let close = rest.firstIndex(of: "\"") else {
            throw ReadError(description: "\(key)'s defaultValue never closes")
        }
        return String(rest[..<close])
    }

    /// The premise: what the Find menu registers. If Search moves again, this fails first and the
    /// strings below fail with it until they are moved too.
    @Test("The Mac Find menu registers ⌥⌘F for Search and ⇧⌘B for the Corpus Browser")
    func findMenuRegistersTheShortcuts() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        #expect(try Self.registeredKeys(of: "menu.find.search.mac", in: app) == ["⌥", "⌘", "F"])
        #expect(try Self.registeredKeys(of: "menu.find.corpusBrowser", in: app) == ["⇧", "⌘", "B"])
        // ⌘F is Find in Document's, which is why a Search string naming it is wrong.
        #expect(try Self.registeredKeys(of: "menu.find.inDocument", in: app) == ["⌘", "F"])
    }

    /// Each main-window string that names a Search or Corpus Browser shortcut names the one the
    /// Find menu registers for it.
    @Test("The main window's tooltips and hint name the shortcuts the Find menu registers")
    func mainWindowNamesTheRegisteredShortcuts() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        let window = try Self.source("FRUSExplorer/App/MainWindowView.swift")
        let search = try Self.registeredKeys(of: "menu.find.search.mac", in: app)
        let browser = try Self.registeredKeys(of: "menu.find.corpusBrowser", in: app)
        let expected: [(key: String, shortcuts: [Set<Character>])] = [
            ("mainwindow.tools.search.help", [search]),
            ("mainwindow.tools.browse.help", [browser]),
            ("mainwindow.placeholder.hint", [search, browser]),
        ]
        for (key, shortcuts) in expected {
            let text = try Self.defaultValue(of: key, in: window)
            #expect(Self.namedShortcuts(in: text) == shortcuts,
                    "\(key) reads “\(text)”, which does not name the registered shortcut(s)")
        }
    }

    /// Tree-wide, for the two stale spellings: no string the app shows names ⌘S, which the app
    /// binds to nothing, and none that speaks of Search names a bare ⌘F, which is Find in
    /// Document. Read line by line with comment lines dropped; a string literal is what sits
    /// between two unescaped quotes on one line.
    @Test("No string in the app names ⌘S, or a bare ⌘F for Search")
    func noStringNamesAStaleSearchShortcut() throws {
        // `FRUSExplorer/` and `FRUSCoreKit/`, each file named from the repository root.
        let paths = AppSourceTree.swiftFiles(in: Self.repoRoot)
            .map { String($0.path.dropFirst(Self.repoRoot.path.count + 1)) }
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        var shortcutLiterals = 0
        var stale: [String] = []
        var bound = 0
        for path in paths {
            let text = try String(contentsOf: Self.repoRoot.appending(path: path), encoding: .utf8)
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//") else { continue }
                if code.contains(#".keyboardShortcut("s""#) { bound += 1 }
                for match in literal.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    guard let range = Range(match.range(at: 1), in: line) else { continue }
                    let value = String(line[range])
                    guard value.contains("⌘") else { continue }
                    shortcutLiterals += 1
                    let groups = Self.namedShortcuts(in: value)
                    if Self.namesBareCommandS(value) || (value.contains("earch") && groups.contains(["⌘", "F"])) {
                        stale.append("\(path):\(number + 1) — \(value)")
                    }
                }
            }
        }
        // A scan that reads no literal finds none stale, so both counts are asserted.
        print("[MacShortcutCopy] \(paths.count) files, \(shortcutLiterals) string literals naming a ⌘ shortcut")
        #expect(paths.count > 400, "Read only \(paths.count) Swift files under FRUSExplorer/ and FRUSCoreKit/")
        #expect(shortcutLiterals >= 5, "Found only \(shortcutLiterals) string literal(s) naming a ⌘ shortcut")
        #expect(bound == 0, """
            The app binds ⌘S now (\(bound) `.keyboardShortcut("s"` call(s)), so a string naming it \
            may be right — re-derive this test's ⌘S rule from what the key is bound to.
            """)
        #expect(stale.isEmpty, """
            A string names a shortcut full-text Search does not have. It is ⌥⌘F; ⌘F is Find in \
            Document and ⌘S is unbound:
            \(stale.joined(separator: "\n"))
            """)
    }

    /// The readers, driven: a registered shortcut is its own item's, and a group of glyphs is a
    /// shortcut only when it holds ⌘.
    @Test("The shortcut readers read one item's shortcut and only glyph groups")
    func readersReadWhatTheySay() throws {
        let menu = """
            Button(String(localized: "a.search", defaultValue: "Search…")) { open() }
            // ⌥⌘F, not ⌘S
            .keyboardShortcut("f", modifiers: [.command, .option])
            Button(String(localized: "a.plain", defaultValue: "Plain")) { open() }
            Button(String(localized: "a.find", defaultValue: "Find")) { find() }
            .keyboardShortcut("g", modifiers: .command)
            """
        #expect(try Self.registeredKeys(of: "a.search", in: menu) == ["⌥", "⌘", "F"])
        #expect(try Self.registeredKeys(of: "a.find", in: menu) == ["⌘", "G"])
        // `a.plain` has no shortcut of its own: the next one belongs to the button after it.
        #expect(throws: ReadError.self) { try Self.registeredKeys(of: "a.plain", in: menu) }
        #expect(throws: ReadError.self) { try Self.registeredKeys(of: "a.absent", in: menu) }
        #expect(throws: ReadError.self) { try Self.defaultValue(of: "a.absent", in: menu) }
        #expect(Self.namedShortcuts(in: "Use Search (⌥⌘F) or open the Corpus Browser (⇧⌘B)")
                == [["⌥", "⌘", "F"], ["⇧", "⌘", "B"]])
        #expect(Self.namedShortcuts(in: "Open it (see below) with ⌘F") == [])
        #expect(Self.namedShortcuts(in: "Browse (⌘⇧B)") == Self.namedShortcuts(in: "Browse (⇧⌘B)"))
        #expect(Self.namesBareCommandS("Use Search (⌘S) or open the Corpus Browser (⇧⌘B)"))
        #expect(!Self.namesBareCommandS("Save As (⇧⌘S)"))
        #expect(!Self.namesBareCommandS("Save As (⌥⌘S)"))
        #expect(!Self.namesBareCommandS("Spotlight (⌘Space)"))
        #expect(!Self.namesBareCommandS("Use Search (⌥⌘F)"))
        #expect(try Self.defaultValue(
            of: "a.find", in: #"String(localized: "a.find", defaultValue: "Find (⌘G)")"#) == "Find (⌘G)")
    }
}
