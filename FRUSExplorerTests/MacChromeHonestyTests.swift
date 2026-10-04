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
        // The view branches on this: an id stays monospaced, prose does not. A monospaced
        // "Soviet Union · 1969-76 v20 · Doc 475" reads as machine output, which is half of what
        // M-8 objects to in the first place.
        #expect(MacDocumentTitle.isFallback(volumeLabel: nil))
        #expect(MacDocumentTitle.isFallback(volumeLabel: ""))
        #expect(!MacDocumentTitle.isFallback(volumeLabel: "1969-76 v20"))
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
/// ## The two survivors are pinned as EXACTLY present, not merely tolerated
/// A ceiling alone goes vacuous when a refactor deletes the carve-out sites; asserting them
/// present keeps the allowlist honest.
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

    @Test("The converted files carry no fixed-point text sites beyond the two carve-outs")
    func convertedFilesStayConverted() throws {
        // Zero-literal files: a new `.font(.system(size: N))` here is the debt returning —
        // use the macOS column of FRUSTheme's size→style table instead.
        for file in ["App/SupportingViews.swift", "App/SearchSheet.swift",
                     "Settings/FRUSSettingsView.swift", "App/HistoryWindowView.swift"] {
            let lines = try Self.fixedSizeLines(file)
            #expect(lines.isEmpty, """
                \(file) gained a fixed-point text site after the W-11 conversion: \
                \(lines.first ?? ""). Fixed sizes ignore the user's text-size setting — convert \
                by the macOS column of FRUSTheme's table (11 → .subheadline, 12 → .callout, \
                13 → .body, ≤10 → .caption2), chaining .weight() where the site had one.
                """)
        }

        // The two documented carve-outs, pinned as present so the allowlist cannot go vacuous:
        // the width-budgeted monospaced identity pill, and the chevron centred in a fixed
        // 34×34 hit circle. Each is LEAVE-FIXED with its reason at the site.
        let main = try Self.fixedSizeLines("App/MainWindowView.swift")
        #expect(main.count == 1, "MainWindowView allows exactly the monospaced pill: \(main)")
        #expect(main.first?.contains("design: .monospaced") == true)
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
