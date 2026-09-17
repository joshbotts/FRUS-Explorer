// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - SearchTipsWiringTests

/// Pins where Search Tips are reachable and what each host renders (#1299), by reading the source.
///
/// `SearchTipsTests` checks what the rows SAY against the parser and SQLite. This suite checks the other half, which no
/// runtime unit test can reach: that the macOS panel and the iOS sheet render that model rather than literals of their
/// own, that both replace the rows with the Meaning-mode note, and that every entry point the owner chose (2026-09-17)
/// is wired where it was decided — More ▸ Search Tips after the abbreviation lookup, a keyword-only link on the
/// pre-search screen, a link BELOW the Query Inspector's disclosure button on a refused or narrower-than-typed query,
/// and a Find-menu item on each platform — with no new keyboard shortcut and no sixth icon in the actions bar.
///
/// Every assertion is scoped to one brace-matched declaration or branch, never to a whole file or a fixed window:
/// `tipsPanel` and `TipItem` sit in one file beside a dozen other readers of `.meaning`, so a file-wide `contains`
/// passes for the wrong reason (`HybridSearchModeTests.bothSurfacesMountMeaningPieces` is the weak form this avoids).
/// The branch helper takes the THEN and ELSE blocks of one `if`, so a sheet that showed the rows in both modes, or the
/// note in neither, fails.
///
/// The macOS half is read from source because `SearchSheet.swift` and `FindMenuContent` are `#if os(macOS)` and this
/// target builds for iOS only; the iOS half is exercised at runtime too, by `SearchTipsSheetTests`.
///
/// Version history:
///   1.0 — #1299: initial implementation
@Suite("Search Tips are wired where the owner put them")
struct SearchTipsWiringTests {

    // MARK: - Source reading

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    private static let searchView = "FRUSExplorer/Search/SearchView.swift"
    private static let searchSheet = "FRUSExplorer/App/SearchSheet.swift"
    private static let app = "FRUSExplorer/App/FRUSExplorerApp.swift"
    private static let appState = "FRUSExplorer/App/AppState.swift"

    /// The declaration beginning at `signature`, from its first brace to the brace that closes it.
    private static func declaration(_ signature: String, in source: String) throws -> String {
        let start = try #require(source.range(of: signature), "no declaration: \(signature)")
        return try balanced(from: start.lowerBound, in: source)
    }

    /// From `index` to the brace that closes the first brace at or after it.
    private static func balanced(from index: String.Index, in source: String) throws -> String {
        var depth = 0
        var opened = false
        var cursor = index
        while cursor < source.endIndex {
            let character = source[cursor]
            if character == "{" { depth += 1; opened = true }
            if character == "}" {
                depth -= 1
                if opened, depth == 0 { return String(source[index...cursor]) }
            }
            cursor = source.index(after: cursor)
        }
        Issue.record("unbalanced braces from offset \(source.distance(from: source.startIndex, to: index))")
        return ""
    }

    /// The THEN and ELSE blocks of the `if` whose header is exactly `condition` (e.g. `if searchMode == .meaning {`),
    /// the first one in `scope`. The ELSE block is empty when the `if` has none.
    private static func branches(of condition: String, in scope: String) throws -> (then: String, else: String) {
        let header = try #require(scope.range(of: condition), "no branch: \(condition)")
        let then = try balanced(from: header.lowerBound, in: scope)
        let afterThen = scope.index(header.lowerBound, offsetBy: then.count)
        let rest = scope[afterThen...]
        let trimmed = rest.drop(while: { $0.isWhitespace })
        guard trimmed.hasPrefix("else {") else { return (then, "") }
        let elseStart = trimmed.startIndex
        return (then, try balanced(from: elseStart, in: scope))
    }

    // MARK: - The helpers themselves

    /// Without this, every absence assertion below could pass because a slice came back empty or overran.
    @Test("The slicer and the branch reader return bounded, non-empty blocks")
    func slicersAreSound() throws {
        let sheet = try Self.source(Self.searchSheet)
        let panel = try Self.declaration("private var tipsPanel: some View {", in: sheet)
        #expect(!panel.isEmpty)
        #expect(!panel.contains("struct TipItem"), "the panel slice ran into the row type")
        #expect(!panel.contains("func documentTypeHelpText"), "the panel slice ran into the next member")

        let fixture = """
        if flag == .on {
            A { }
        } else {
            B { }
        }
        C
        """
        let split = try Self.branches(of: "if flag == .on {", in: fixture)
        #expect(split.then.contains("A") && !split.then.contains("B"))
        #expect(split.else.contains("B") && !split.else.contains("A") && !split.else.contains("C"))
        let noElse = try Self.branches(of: "if flag == .on {", in: "if flag == .on { A }\nC")
        #expect(noElse.then.contains("A") && noElse.else.isEmpty)
    }

    // MARK: - macOS: the Tips panel

    @Test("macOS: the Tips panel renders the shared rows and the Mac notes, and none of its old literals")
    func macPanelReadsTheModel() throws {
        let sheet = try Self.source(Self.searchSheet)
        let panel = try Self.declaration("private var tipsPanel: some View {", in: sheet)
        #expect(panel.contains("SearchTip.syntaxRows"))
        #expect(panel.contains("SearchTipNote.filterNotesMac"))
        #expect(!panel.contains("SearchTipNote.filterNotesIOS"), "the Mac panel names the iOS scope controls")
        #expect(!panel.contains("TipItem(code:"), "a row typed beside the parser is back")
        #expect(!sheet.contains("TipItem(code: \""), "a literal row survives elsewhere in the file")
        #expect(!sheet.contains("Person filter searches"), "the person row the owner removed (Q1) is back")
        #expect(!sheet.contains("Scope toggles persist"), "the false scope row is back")
    }

    @Test("macOS: in Meaning mode the panel shows the Meaning-mode note INSTEAD of the rows")
    func macPanelBranchesOnMeaningMode() throws {
        let sheet = try Self.source(Self.searchSheet)
        let panel = try Self.declaration("private var tipsPanel: some View {", in: sheet)
        let split = try Self.branches(of: "if searchVM.searchMode == .meaning {", in: panel)
        #expect(split.then.contains(".meaningMode"))
        #expect(!split.then.contains("syntaxRows"), "the rows show in Meaning mode, where none of them applies")
        #expect(split.else.contains("SearchTip.syntaxRows"))
        #expect(!split.else.contains(".meaningMode"))
    }

    @Test("macOS: the panel's chrome is localized, its header is a heading, and the grid scrolls inside a cap")
    func macPanelChrome() throws {
        let sheet = try Self.source(Self.searchSheet)
        let panel = try Self.declaration("private var tipsPanel: some View {", in: sheet)
        #expect(panel.contains("\"search.tips.header\""))
        #expect(panel.contains(".accessibilityAddTraits(.isHeader)"))
        #expect(!panel.contains("Text(\"Search tips\")"))
        #expect(panel.contains("ScrollView"))
        #expect(panel.contains(".adaptive(minimum:"))
        #expect(panel.contains("maxHeight:"), "the grid is uncapped and takes the results' height at 640×500")

        let input = try Self.declaration("private var searchInputRow: some View {", in: sheet)
        #expect(input.contains("\"search.tips.button\""))
        #expect(!input.contains("Label(\"Tips\""), "the button label is a bare literal again")
        #expect(input.contains("\"search.tips.help.v2\""))
        #expect(!input.contains("\"search.tips.help\""), "the help text still promises a stemming tip it never had")
        #expect(input.contains(".accessibilityAddTraits(searchVM.showTips ? .isSelected : [])"),
                "the button's on state is carried by colour alone")
    }

    @Test("macOS: a tip row is one accessibility element, with the example verbatim")
    func macRowIsOneElement() throws {
        let sheet = try Self.source(Self.searchSheet)
        let row = try Self.declaration("private struct TipItem: View {", in: sheet)
        #expect(row.contains("let tip: SearchTip"))
        #expect(row.contains("Text(verbatim: tip.example)"))
        #expect(row.contains(".accessibilityElement(children: .ignore)"))
        #expect(row.contains(".accessibilityLabel(tip.accessibilityLabel)"))
    }

    @Test("macOS: Find ▸ Search Tips fronts the Search window and opens the panel, with no shortcut")
    func macFindMenuOpensThePanel() throws {
        let app = try Self.source(Self.app)
        let menu = try Self.declaration("struct FindMenuContent: View {", in: app)
        let item = try #require(menu.range(of: "\"menu.find.searchTips\""), "no Search Tips item in the Mac Find menu")
        // The item's own span: from its key to the next item.
        let tail = menu[item.upperBound...]
        let span = String(tail[..<(tail.range(of: "Button(")?.lowerBound ?? tail.endIndex)])
        #expect(span.contains("appState.openSearchTips(from: nil)"))
        #expect(span.contains("openWindow.fronting(id: \"frus.search\")"))
        #expect(!span.contains(".keyboardShortcut"), "Q2 decided no new keyboard shortcut")

        let sheet = try Self.source(Self.searchSheet)
        let consumers = sheet.components(separatedBy: "consumeHandoff(\\.pendingSearchTips, for: .macSearch)").count - 1
        #expect(consumers == 2, "the window must consume the request on first load AND while open; found \(consumers)")
        #expect(sheet.contains(".onChange(of: appState.pendingSearchTips)"))
    }

    @Test("macOS: a search that fails shows its message instead of an empty list")
    func macShowsSearchErrors() throws {
        let sheet = try Self.source(Self.searchSheet)
        let body = try Self.declaration("private var loadedBody: some View {", in: sheet)
        let branch = try #require(body.range(of: "} else if let searchError = searchVM.searchError"),
                                  "the refused-query message reaches the Mac model and never the screen")
        let zero = try #require(body.range(of: "} else if hasZeroResults {"))
        #expect(branch.lowerBound < zero.lowerBound, "the error branch must precede the zero-result branch")
        let tail = body[branch.upperBound...]
        #expect(tail.prefix(600).contains("searchErrorView(searchError)"))
        let view = try Self.declaration("private func searchErrorView(_ searchError: any Error) -> some View {", in: sheet)
        #expect(view.contains("Text(searchError.localizedDescription)"))
    }

    // MARK: - AppState

    @Test("AppState: a Search Tips request is a one-shot hand-off, addressed like a search")
    func appStateRequestIsAHandoff() throws {
        let state = try Self.source(Self.appState)
        #expect(state.contains("var pendingSearchTips: Handoff<Bool>? = nil"))
        let open = try Self.declaration("func openSearchTips(from sceneID: SceneID?) {", in: state)
        #expect(open.contains("pendingSearchTips = Handoff(target: .macSearch, payload: true)"))
        #expect(open.contains("pendingSearchTips = Handoff(target: sceneID ?? .anyWindow, payload: true)"))
    }

    // MARK: - iOS and iPadOS: the sheet

    @Test("iOS: the sheet renders the shared rows and the iOS notes, and the Meaning-mode note INSTEAD in Meaning mode")
    func iOSSheetBranchesOnMeaningMode() throws {
        let view = try Self.source(Self.searchView)
        let sheet = try Self.declaration("struct SearchTipsSheet: View {", in: view)
        let split = try Self.branches(of: "if searchMode == .meaning {", in: sheet)
        #expect(split.then.contains(".meaningMode"))
        #expect(!split.then.contains("syntaxRows"), "the rows show in Meaning mode, where none of them applies")
        #expect(split.else.contains("SearchTip.syntaxRows"))
        #expect(split.else.contains("SearchTipNote.filterNotesIOS"))
        #expect(!split.else.contains("filterNotesMac"), "the iOS sheet names the Mac's Search in chips")
    }

    @Test("iOS: the sheet is a navigation-bar sheet with Done, an inline title and medium and large detents")
    func iOSSheetShape() throws {
        let view = try Self.source(Self.searchView)
        let sheet = try Self.declaration("struct SearchTipsSheet: View {", in: view)
        #expect(sheet.contains("NavigationStack"))
        #expect(sheet.contains("List"))
        #expect(sheet.contains("\"search.tips.title\""))
        #expect(sheet.contains(".navigationBarTitleDisplayMode(.inline)"))
        // `UITestPresentation.dismissAnyPresentation` looks only in the navigation bar, so Done must live there.
        #expect(sheet.contains("ToolbarItem(placement: .confirmationAction)"))
        #expect(sheet.contains(".presentationDetents([.medium, .large])"))
    }

    @Test("iOS: a tip row is one accessibility element, with the example verbatim")
    func iOSRowIsOneElement() throws {
        let view = try Self.source(Self.searchView)
        let row = try Self.declaration("private struct SearchTipRow: View {", in: view)
        #expect(row.contains("Text(verbatim: tip.example)"))
        #expect(row.contains(".accessibilityElement(children: .ignore)"))
        #expect(row.contains(".accessibilityLabel(tip.accessibilityLabel)"))
    }

    // MARK: - iOS and iPadOS: the entry points

    @Test("iOS: More ▸ Search Tips follows the abbreviation lookup, clear of the two save items")
    func moreMenuOpensTips() throws {
        let view = try Self.source(Self.searchView)
        let more = try Self.declaration("private var moreMenu: some View {", in: view)
        let item = try #require(more.range(of: "\"search.tips.open\""), "no Search Tips item in the More menu")
        let glossary = try #require(more.range(of: "\"search.glossaryLookup.a11y\""))
        #expect(glossary.upperBound < item.lowerBound, "Search Tips must come after Look up an abbreviation")
        #expect(more.contains("showSearchTips = true"))
        #expect(more[item.upperBound...].prefix(200).contains("\"questionmark.circle\""))

        let save = try #require(more.range(of: "search.saveSearch.a11y"))
        let corpus = try #require(more.range(of: "search.corpus.save"))
        #expect(!more[save.upperBound..<corpus.lowerBound].contains("search.tips.open"))

        #expect(more.contains("\"search.moreActions.help.v2\""))
        #expect(!more.contains("\"search.moreActions.help\""), "the help text still omits the lookup and the tips")
    }

    @Test("iOS: no sixth icon in the actions bar")
    func actionsBarIsUnchanged() throws {
        let view = try Self.source(Self.searchView)
        let bar = try Self.declaration("private var searchActionsBar: some View {", in: view)
        let hstack = try Self.balanced(from: try #require(bar.range(of: "HStack(")).lowerBound, in: bar)
        #expect(!hstack.contains("questionmark.circle"))
        #expect(!hstack.contains("showSearchTips"))
    }

    @Test("iOS: the pre-search link shows in Keywords mode only, and runs no search")
    func preSearchLinkIsKeywordOnly() throws {
        let view = try Self.source(Self.searchView)
        let screen = try Self.declaration("private var initialPromptView: some View {", in: view)
        #expect(screen.contains("vm.searchMode.initialPrompt(scoped: !vm.effectiveVolumeIds.isEmpty)"))
        let split = try Self.branches(of: "if vm.searchMode == .keywords {", in: screen)
        #expect(split.then.contains("showSearchTips = true"))
        #expect(!split.then.contains("runSearch"), "a tips link must not become a search entry point")
        #expect(!split.then.contains("vm.search("))
        #expect(split.else.isEmpty, "the Meaning-mode screen must not offer a second link")
        #expect(screen.contains("ScrollView"), "the prompt and link clip at accessibility sizes without a scroll view")

        let results = try Self.declaration("private var resultsSection: some View {", in: view)
        #expect(results.contains("initialPromptView"))
    }

    @Test("iOS: the Query Inspector link is a sibling below the disclosure button, on a refused or narrowed query")
    func inspectorLinkIsASibling() throws {
        let view = try Self.source(Self.searchView)
        let card = try Self.declaration("private var queryInspectorCard: some View {", in: view)
        let split = try Self.branches(of: "if inspection.isRefused || inspection.isApproximate {", in: card)
        #expect(split.then.contains("showSearchTips = true"))
        #expect(split.else.isEmpty)

        // Below the disclosure button: after its accessibility label, which is the last modifier on that button.
        let disclosure = try #require(card.range(of: ".accessibilityLabel(inspectorExpanded"))
        let gate = try #require(card.range(of: "if inspection.isRefused || inspection.isApproximate {"))
        #expect(disclosure.upperBound < gate.lowerBound, "the link must sit below the disclosure button")
        // And never inside its label, where VoiceOver cannot reach a nested button.
        let label = try Self.balanced(from: try #require(card.range(of: "label: {")).lowerBound, in: card)
        #expect(label.contains("QueryInspectorStrip("), "the label slice missed the strip, so the check proves nothing")
        #expect(!label.contains("showSearchTips"))

        let strip = try Self.source("FRUSExplorer/Search/QueryInspectorView.swift")
        #expect(!strip.contains("showSearchTips") && !strip.contains("search.tips."))
    }

    @Test("iPadOS: Find ▸ Search Tips raises the Search tab and asks it for the sheet, with no shortcut")
    func iPadFindMenuRequestsTips() throws {
        let app = try Self.source(Self.app)
        let menu = try Self.declaration("struct IOSFindMenuContent: View {", in: app)
        let item = try #require(menu.range(of: "\"menu.find.searchTips\""), "no Search Tips item in the iPadOS Find menu")
        let tail = menu[item.upperBound...]
        let span = String(tail[..<(tail.range(of: "Button(")?.lowerBound ?? tail.endIndex)])
        #expect(span.contains("appState.openTab(.search, from: nil)"))
        #expect(span.contains("appState.openSearchTips(from: nil)"))
        #expect(!span.contains(".keyboardShortcut"), "Q2 decided no new keyboard shortcut")
        let shortcuts = menu.components(separatedBy: ".keyboardShortcut(").count - 1
        #expect(shortcuts == 2, "the iPadOS Find menu carries exactly ⌘F and ⌥⌘F; found \(shortcuts)")
    }

    @Test("iOS: SearchView consumes the request once, on appearing and while on screen, and presents from the stack")
    func searchViewConsumesTheRequest() throws {
        let view = try Self.source(Self.searchView)
        let consume = try Self.declaration("private func consumePendingSearchTips() {", in: view)
        #expect(consume.contains("consumeHandoff(\\.pendingSearchTips, for: sceneID, orAnyWindow: true)"))
        #expect(consume.contains("showSearchTips = true"))

        // One modifier on the body chain carries the sheet and the request.
        let body = try Self.declaration("var body: some View {", in: view)
        let mount = try #require(body.range(of: ".modifier(SearchTipsPresenter("),
                                 "SearchView's body does not mount the Search Tips presenter")
        let arguments = body[mount.upperBound...].prefix(260)
        #expect(arguments.contains("isPresented: $showSearchTips"))
        #expect(arguments.contains("pendingRequest: appState.pendingSearchTips"))
        #expect(arguments.contains("consume: consumePendingSearchTips"))

        let presenter = try Self.declaration("private struct SearchTipsPresenter: ViewModifier {", in: view)
        #expect(presenter.contains(".sheet(isPresented: $isPresented)"))
        let appear = try #require(presenter.range(of: ".onAppear {"),
                                  "a request made before Search appears is never read")
        #expect(presenter[appear.upperBound...].prefix(80).contains("consume()"))
        let observer = try #require(presenter.range(of: ".onChange(of: pendingRequest)"),
                                    "a request that arrives while Search is on screen is never read")
        #expect(presenter[observer.upperBound...].prefix(120).contains("if request != nil, isOnScreen { consume() }"),
                "a hidden tab's SearchView must leave the request for the one on screen")
    }
}
