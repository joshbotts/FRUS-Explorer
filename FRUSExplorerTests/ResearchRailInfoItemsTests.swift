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

// MARK: - ResearchRailInfoItemsTests

/// The Research rail's ⓘ popover explains exactly the tiles the rail shows, in the order it shows
/// them, on each platform.
///
/// ## The bug this exists to stop happening again (#1351)
/// #941 added the On the Map tile to both tile grids and never added it to
/// `RailTileCopy.infoItems`, the rows of the header's "Document tools" popover. Nothing was red:
/// the tile carried its own `help` sentence, so its tooltip and VoiceOver hint were right, and the
/// popover — which draws whatever array it is handed — simply explained six of the seven tiles on
/// screen. The two lists live some eight hundred lines apart in one file, and nothing related them.
///
/// ## Why half of this reads source
/// The popover half is called for real: `RailTileCopy.infoItems` is the array `FeatureInfoButton`
/// is handed. It is evaluated once, in the iOS test host — the macOS scheme has no test action —
/// and that single evaluation stands for macOS only because `RailTileCopy` carries no `#if` and
/// sits under none, which ``railTileCopyIsPlatformNeutral()`` checks. The grid half cannot be
/// called at all — `tileGrid` is a private SwiftUI body with a different `#if os` branch per
/// platform, and the tiles register nothing a unit test can query. So the grid is read from
/// `ResearchRailView.swift`: each tile is a `railTile(` or `tileLabel(` call whose second argument
/// names a `RailTileCopy` member, and the members, in order, must name the rows.
///
/// ## What it cannot see
/// A tile built from neither helper — a bespoke `Button`, or a `Label` inside a `Menu` — makes no
/// call this scan recognises, and a tile factored out of `tileGrid` into a property of its own
/// leaves its call outside the body this scan reads; either is invisible here. Every tile today is
/// a helper call written inside the grid, and the call count is checked against the member count,
/// so a tile that uses a helper but spells its caption as a literal instead of a `RailTileCopy`
/// entry fails rather than slipping past.
///
/// Version history:
///   1.0 — #1351: initial implementation
@Suite("Research rail info popover")
struct ResearchRailInfoItemsTests {

    // MARK: - Source reading

    /// The repo root, derived from this file's location.
    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads `ResearchRailView.swift`, refusing an implausibly small read — a truncated file would
    /// make every assertion below fail for the wrong reason.
    private static func railSource() throws -> String {
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/DocumentView/ResearchRailView.swift"),
                              encoding: .utf8)
        #expect(text.count > 20_000, "ResearchRailView.swift is implausibly small — did it move or get truncated?")
        return text
    }

    /// The body of `tileGrid`: everything between its opening brace and the brace that closes it.
    ///
    /// Brace-counted rather than cut at the next declaration, so a comment or a new helper placed
    /// after the grid cannot be swallowed into it. The grid holds no string or comment containing a
    /// brace; if one is ever added the count goes wrong loudly (the body stops short and the tile
    /// comparison fails), not silently.
    static func tileGridBody(in source: String) -> String? {
        body(openedBy: "private var tileGrid: some View {", in: source)
    }

    /// Everything between the brace that ends `opener` and the brace that closes it, or `nil` when
    /// `opener` is absent or its brace never closes.
    static func body(openedBy opener: String, in source: String) -> String? {
        guard let declaration = source.range(of: opener) else { return nil }
        var depth = 1
        var index = declaration.upperBound
        while index < source.endIndex {
            switch source[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(source[declaration.upperBound..<index]) }
            default: break
            }
            index = source.index(after: index)
        }
        return nil
    }

    /// The platforms a grid tile can be compiled for.
    enum Platform: String, CaseIterable, CustomTestStringConvertible {
        case macOS, iOS

        var testDescription: String { rawValue }

        /// The other platform — what an `#else` under this one's `#if` compiles for.
        var other: Platform { self == .macOS ? .iOS : .macOS }
    }

    /// The code lines of `grid` that compile on `platform`, comments dropped.
    ///
    /// A small `#if` stack: `os(macOS)` / `os(iOS)` and their negations select a platform, `#else`
    /// flips it, and any other condition (`DEBUG`, say) is neither, so it excludes nothing. A line
    /// under no platform condition compiles on BOTH — a tile written outside the two branches is
    /// shown on both rails and must be counted for both, which is why this is a stack and not a
    /// search for the two `#if` blocks the grid happens to use today.
    static func codeLines(of grid: String, for platform: Platform) -> [String] {
        var stack: [Platform?] = []
        var kept: [String] = []
        for rawLine in grid.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if ") || line.hasPrefix("#elseif ") {
                let condition = line.hasPrefix("#if ") ? String(line.dropFirst(4)) : String(line.dropFirst(8))
                let selected = Self.platform(selectedBy: condition.trimmingCharacters(in: .whitespaces))
                if line.hasPrefix("#elseif "), !stack.isEmpty { stack.removeLast() }
                stack.append(selected)
                continue
            }
            if line.hasPrefix("#else") {
                if let top = stack.popLast() { stack.append(top?.other) }
                continue
            }
            if line.hasPrefix("#endif") {
                _ = stack.popLast()
                continue
            }
            if line.hasPrefix("//") { continue }
            guard stack.allSatisfy({ $0 == nil || $0 == platform }) else { continue }
            // Drop a trailing `//` comment. No tile line carries a URL or a `//` inside a string.
            let code = rawLine.components(separatedBy: "//").first ?? rawLine
            kept.append(code)
        }
        return kept
    }

    /// The platform an `#if` condition selects, or `nil` for a condition that is not a platform test.
    private static func platform(selectedBy condition: String) -> Platform? {
        switch condition {
        case "os(macOS)", "!os(iOS)": return .macOS
        case "os(iOS)", "!os(macOS)": return .iOS
        default: return nil
        }
    }

    /// The tiles one platform's grid builds, in order, as the `RailTileCopy` members they name —
    /// plus how many tile calls there were, so a tile whose caption is not a `RailTileCopy` entry
    /// shows up as a call with no member.
    static func tiles(inGrid grid: String, for platform: Platform) throws -> (members: [String], calls: Int) {
        let code = codeLines(of: grid, for: platform).joined(separator: "\n")
        let whole = NSRange(code.startIndex..., in: code)
        // Every tile is `railTile(<glyph>, RailTileCopy.<member>…)` or, for iOS's Share menu,
        // `tileLabel(<glyph>, RailTileCopy.<member>.title)`. The glyph is a string literal or a
        // `…Glyph.symbol`-style constant, neither of which contains a comma.
        let member = try NSRegularExpression(
            pattern: #"\b(?:railTile|tileLabel)\(\s*[^,()]+,\s*RailTileCopy\.(\w+)"#)
        let call = try NSRegularExpression(pattern: #"\b(?:railTile|tileLabel)\("#)
        let members = member.matches(in: code, range: whole).compactMap { match in
            Range(match.range(at: 1), in: code).map { String(code[$0]) }
        }
        return (members, call.numberOfMatches(in: code, range: whole))
    }

    /// The copy a `RailTileCopy` member names, or `nil` for a member this suite does not know.
    ///
    /// Hand-kept on purpose: a new tile makes this return `nil`, and the test says which member to
    /// add, rather than the scan quietly skipping a tile it cannot resolve.
    static func entry(named member: String) -> RailTileCopy.Entry? {
        switch member {
        case "cite": return RailTileCopy.cite
        case "wordCloud": return RailTileCopy.wordCloud
        case "sources": return RailTileCopy.sources
        case "graph": return RailTileCopy.graph
        case "related": return RailTileCopy.related
        case "semanticMap": return RailTileCopy.semanticMap
        case "share": return RailTileCopy.share
        default: return nil
        }
    }

    // MARK: - The popover explains the grid

    @Test("The info popover's rows are the rail's tiles, in tile order", arguments: Platform.allCases)
    func infoItemsMatchTheGrid(platform: Platform) throws {
        let grid = try #require(Self.tileGridBody(in: try Self.railSource()),
                                "`private var tileGrid: some View {` not found — was the grid renamed?")
        let (members, calls) = try Self.tiles(inGrid: grid, for: platform)

        // Fixture guards: a scan that finds nothing must fail here, not agree with an empty list.
        #expect(members.count >= 5, "found only \(members.count) \(platform) tiles — the scan is broken")
        #expect(calls == members.count,
                """
                \(platform): \(calls) tile calls but \(members.count) name a `RailTileCopy` member. \
                Every tile's caption must come from `RailTileCopy`, or the info popover cannot list it.
                """)

        var gridRows: [(title: String, detail: String)] = []
        for name in members {
            let entry = try #require(Self.entry(named: name),
                                     "`RailTileCopy.\(name)` is a tile this suite does not know — add it to `entry(named:)`")
            gridRows.append((entry.title, entry.detail))
        }
        let popoverRows = RailTileCopy.infoItems.map { (title: $0.title, detail: $0.detail) }

        #expect(popoverRows.map(\.title) == gridRows.map(\.title),
                """
                The \(platform) rail shows \(gridRows.map(\.title)) \
                but its info popover explains \(popoverRows.map(\.title)). \
                Add the tile to `RailTileCopy.infoItems`, in tile order.
                """)
        #expect(popoverRows.map(\.detail) == gridRows.map(\.detail))
    }

    /// `FeatureInfoItem` is `Identifiable` by its title, so two rows sharing one would collide in
    /// the popover's `ForEach` and one of them would not draw as itself.
    @Test("Every info-popover row has its own title")
    func infoItemTitlesAreDistinct() {
        let titles = RailTileCopy.infoItems.map(\.title)
        #expect(!titles.isEmpty)
        #expect(Set(titles).count == titles.count, "duplicate titles in \(titles)")
        #expect(titles.allSatisfy { !$0.isEmpty })
    }

    /// This suite evaluates `infoItems` in the iOS host and compares the MACOS grid against that
    /// same array. That is only sound while `RailTileCopy` compiles identically on both platforms:
    /// an `#if os(macOS)` inside it could drop a row from the Mac popover alone and every other
    /// test here would stay green.
    @Test("RailTileCopy has no platform branch, so one evaluation of infoItems stands for both")
    func railTileCopyIsPlatformNeutral() throws {
        let source = try Self.railSource()
        let opener = "enum RailTileCopy {"
        let lines = source.components(separatedBy: "\n")
        let declaration = try #require(lines.firstIndex { $0.hasPrefix(opener) },
                                       "`\(opener)` not found at the start of a line — was it renamed or nested?")
        var openConditionals = 0
        for line in lines[..<declaration] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#if ") { openConditionals += 1 }
            if trimmed.hasPrefix("#endif") { openConditionals -= 1 }
        }
        #expect(openConditionals == 0, "`RailTileCopy` is declared inside an `#if` — the suite can no longer speak for both platforms")

        let body = try #require(Self.body(openedBy: opener, in: source), "`RailTileCopy`'s braces never close")
        #expect(body.contains("static var infoItems"), "fixture guard: the brace count stopped short of `infoItems`")
        let conditionals = body.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("#if") || $0.hasPrefix("#else") }
        #expect(conditionals.isEmpty,
                "`RailTileCopy` carries \(conditionals) — the popover rows may differ by platform, and this suite checks only one")
    }

    // MARK: - The rows reach the screen

    /// The comparison above is only worth something if the popover is handed `infoItems` — on both
    /// platforms, and whole. This matches the one call: an `#if` around it fails the other
    /// platform, and a trimmed or wrapped argument fails the exact match.
    @Test("The rail header hands infoItems, whole, to its info button", arguments: Platform.allCases)
    func headerHandsInfoItemsToThePopover(platform: Platform) throws {
        let header = try #require(Self.body(openedBy: "private var header: some View {", in: try Self.railSource()),
                                  "`private var header: some View {` not found — was it renamed?")
        let code = Self.codeLines(of: header, for: platform).joined(separator: "\n")
        let call = try NSRegularExpression(
            pattern: #"FeatureInfoButton\(\s*heading:\s*Self\.toolsInfoHeading,\s*items:\s*RailTileCopy\.infoItems\s*\)"#)
        #expect(call.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code)) == 1,
                "the \(platform) rail header does not pass `RailTileCopy.infoItems` to its `FeatureInfoButton`")
    }

    /// The seventh row made the popover taller than the iPhone rail's medium detent, where the
    /// popover is a sheet, and the heading was clipped away (measured, iPhone 17, default text
    /// size). `FeatureInfoButton` now scrolls whenever its space is shorter than its rows. The
    /// popover registers nothing a unit test can measure, so this pins the construct, in order: the
    /// plain stack FIRST, so a popover asked for its ideal size still hugs it, and the scroll view
    /// only as the fallback. Swapping them, or dropping either, keeps every other test here green.
    @Test("On iOS the info popover scrolls when it is shorter than its rows, and only then")
    func shortPopoverScrolls() throws {
        let theme = try String(contentsOf: Self.root.appending(path: "FRUSExplorer/Theme/FRUSTheme.swift"),
                               encoding: .utf8)
        let button = try #require(Self.body(openedBy: "struct FeatureInfoButton<Footer: View>: View {", in: theme),
                                  "`FeatureInfoButton` not found — was it renamed?")
        let code = button.components(separatedBy: "\n")
            .map { $0.components(separatedBy: "//").first ?? $0 }
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        #expect(code.contains(
            "#if os(iOS) ViewThatFits(in: .vertical) { explanation ScrollView { explanation } .scrollBounceBehavior(.basedOnSize) } #else explanation #endif"))
        #expect(code.components(separatedBy: "ScrollView").count == 2, "exactly one scroll view, the fallback")
    }

    // MARK: - The scan itself

    /// The scan is the half of the comparison nothing else checks, so it gets a fixture that can
    /// tell the rules apart: a tile outside both branches must count on BOTH platforms, `#else`
    /// must flip the branch, an unrelated `#if` must exclude nothing, a tile commented out — on a
    /// line of its own or after code — must not count, and a caption spelled as a literal must be a
    /// call with no member.
    @Test("The grid scan reads branches, shared tiles and comments the way the compiler does")
    func scanReadsPlatformBranches() throws {
        let grid = """
            railTile("a", RailTileCopy.cite) { }
            #if os(macOS)
            railTile(Glyph.symbol, RailTileCopy.graph,
                     action: open)
            // railTile("x", RailTileCopy.related) { }
            #else
            railTile("b", RailTileCopy.sources) { }  // railTile("q", RailTileCopy.related) { }
            #if DEBUG
            Menu { } label: { tileLabel("c", RailTileCopy.share.title) }
            #endif
            #endif
            railTile("d", "Literal") { }
            """
        let mac = try Self.tiles(inGrid: grid, for: .macOS)
        #expect(mac.members == ["cite", "graph"])
        #expect(mac.calls == 3)

        let ios = try Self.tiles(inGrid: grid, for: .iOS)
        #expect(ios.members == ["cite", "sources", "share"])
        #expect(ios.calls == 4)
    }

    /// Each expectation kills a different wrong way to find the body: stopping at the first `}`
    /// loses `graph`, after the first tile's closed block; counting from zero instead of one stops
    /// at the grid's own nested close and loses `sources`, in the modifier after it; cutting at the
    /// next declaration swallows the commented-out `related`; and running on to the end of the file
    /// takes the helper's `share`.
    @Test("The grid body stops at the grid's own closing brace")
    func gridBodyIsBraceCounted() throws {
        let source = """
            private var tileGrid: some View {
                LazyVGrid {
                    railTile("a", RailTileCopy.cite) { }
                    railTile("b", RailTileCopy.graph) { }
                }
                .overlay { railTile("c", RailTileCopy.sources) { } }
            }
            // railTile("y", RailTileCopy.related) { }
            static var heading: String { tileLabel("z", RailTileCopy.share.title) }
            """
        let grid = try #require(Self.tileGridBody(in: source))
        #expect(grid.contains("RailTileCopy.graph"))
        #expect(grid.contains("RailTileCopy.sources"))
        #expect(!grid.contains("RailTileCopy.related"))
        #expect(!grid.contains("RailTileCopy.share"))
    }
}
