// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - ToolbarAccessibilityAuditTests

/// Source-tree gate for the R-8 toolbar rule: **a toolbar item's name must live inside
/// its `label:` closure.**
///
/// ## What this catches that a UI test cannot
/// `ToolbarOverflowAccessibilityTests` proves the rule for one control on one screen. The
/// rule applies to every toolbar item in the app, and the failure mode is silent: an
/// icon-only item reads correctly in the bar and only mis-announces once the toolbar
/// happens to overflow — which depends on device width, Dynamic Type and how many items
/// a later change adds. Measured on iPad (iPadOS 26.5): the overflow row re-derives its
/// name from the label closure's content, so `Image(systemName: "chart.bar.xaxis")` +
/// `.accessibilityLabel("Analysis Tools")` announces "chart bar xaxis". `Label(name,
/// systemImage:)` announces `name` in both representations and still renders icon-only in
/// the bar. See `ControlHelpModifier`'s toolbar rule.
///
/// This scan therefore fails the suite for any *new* `ToolbarItem` whose label closure
/// opens with a bare `Image(systemName:)`.
///
/// ## Known exceptions
/// ``knownImageOnlyToolbarLabels`` records the sites this wave did not convert, with the
/// reason. It is an exception list, not permission: adding to it is a decision to leave a
/// control mis-announcing when its toolbar overflows.
///
/// Version history:
///   1.0 — Wave R / R-8: initial implementation
struct ToolbarAccessibilityAuditTests {

    // MARK: - Roots

    private static let projectRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private static let sourceRoot: URL =
        projectRoot.appendingPathComponent("FRUSExplorer")

    /// Files allowed to keep image-only toolbar labels, with the count expected in each.
    ///
    /// - `MacCorpusBrowserWindow.swift` (3): macOS-only sidebar toolbar. These three
    ///   buttons carry `.help(_:)` and **no** `accessibilityLabel` at all, and their
    ///   tooltips are raw English literals rather than `String(localized:)`, so
    ///   converting them is a localization change on a surface R-8 could not verify (the
    ///   verification for this wave was done on an iPad simulator). Reported, not fixed.
    ///
    /// The count is part of the contract: adding a fourth image-only label to one of
    /// these files fails the test rather than being absorbed silently.
    static let knownImageOnlyToolbarLabels: [String: Int] = [
        "MacCorpusBrowserWindow.swift": 3
    ]

    // MARK: - Test

    @Test("ToolbarAccessibilityAudit: no toolbar item uses a bare Image(systemName:) as its label")
    func toolbarItemsNameThemselvesInTheirLabelClosure() throws {
        let findings = try Self.scanForImageOnlyToolbarLabels()

        var grouped: [String: [Int]] = [:]
        for finding in findings {
            grouped[finding.fileName, default: []].append(finding.line)
        }

        var violations: [String] = []
        for (fileName, lines) in grouped.sorted(by: { $0.key < $1.key }) {
            let allowed = Self.knownImageOnlyToolbarLabels[fileName] ?? 0
            if lines.count > allowed {
                let locations = lines.sorted().map(String.init).joined(separator: ", ")
                violations.append(
                    "\(fileName): \(lines.count) image-only toolbar label(s) at line(s) \(locations) "
                    + "— \(allowed) allowed"
                )
            }
        }
        // A shrinking exception list should be tightened, not left stale.
        for (fileName, allowed) in Self.knownImageOnlyToolbarLabels.sorted(by: { $0.key < $1.key }) {
            let actual = grouped[fileName]?.count ?? 0
            if actual < allowed {
                violations.append(
                    "\(fileName): only \(actual) image-only toolbar label(s) remain but \(allowed) are "
                    + "allowed — lower the count in knownImageOnlyToolbarLabels"
                )
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: """
            Toolbar items must name themselves inside their `label:` closure:

                label: { Label(name, systemImage: "…") }      ✅
                label: { Image(systemName: "…") }             ❌

            When iPadOS collapses a toolbar item into the navigation-bar overflow it
            re-derives the row's accessible name from the label closure's content, so an
            `.accessibilityLabel` / `.controlHelp` applied outside it is discarded and
            VoiceOver reads the raw SF Symbol string. A bare `Label` still renders
            icon-only in the bar, so this costs nothing visually — and do NOT add
            `.labelStyle(.iconOnly)`, which strips the text the overflow needs.

            \(violations.joined(separator: "\n"))
            """))
    }

    /// The audit finds at least the sites it is meant to police — a scanner that silently
    /// stopped matching (a SwiftUI syntax change, a moved directory) would otherwise turn
    /// this suite green by finding nothing at all.
    @Test("ToolbarAccessibilityAudit: the scanner still recognises toolbar label closures")
    func scannerIsNotVacuous() throws {
        let scannedItems = try Self.countToolbarItems()
        #expect(scannedItems > 50, Comment(rawValue:
                "Expected the scan to walk many ToolbarItem declarations, found \(scannedItems). "
                + "The scanner has probably stopped matching and its green result means nothing."))
    }

    // MARK: - Scanner

    /// One image-only toolbar label.
    struct Finding {
        /// The source file's base name.
        let fileName: String
        /// 1-based line of the enclosing `ToolbarItem` declaration.
        let line: Int
    }

    /// Every Swift file under the app source root.
    private static func sourceFiles() throws -> [URL] {
        try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { sourceRoot.appendingPathComponent($0) }
    }

    /// Scans every source file for `ToolbarItem`/`ToolbarItemGroup` bodies containing a
    /// `label:` closure that opens with `Image(systemName:`.
    static func scanForImageOnlyToolbarLabels() throws -> [Finding] {
        var findings: [Finding] = []
        for url in try sourceFiles() {
            let source = try String(contentsOf: url, encoding: .utf8)
            for (body, line) in toolbarItemBodies(in: source) where hasImageOnlyLabel(body) {
                findings.append(Finding(fileName: url.lastPathComponent, line: line))
            }
        }
        return findings
    }

    /// How many toolbar item declarations the scanner walked — the anti-vacuity measure.
    static func countToolbarItems() throws -> Int {
        var count = 0
        for url in try sourceFiles() {
            count += toolbarItemBodies(in: try String(contentsOf: url, encoding: .utf8)).count
        }
        return count
    }

    /// Brace-matched bodies of every `ToolbarItem(...)`/`ToolbarItemGroup(...)` trailing
    /// closure in `source`, paired with the 1-based line the declaration starts on.
    private static func toolbarItemBodies(in source: String) -> [(body: Substring, line: Int)] {
        let chars = Array(source)
        var results: [(Substring, Int)] = []
        var searchStart = source.startIndex

        while let declRange = source.range(of: #"ToolbarItem(Group)?\s*\("#,
                                           options: .regularExpression,
                                           range: searchStart..<source.endIndex) {
            searchStart = declRange.upperBound

            // Step past the argument list, then take the trailing closure.
            var index = source.distance(from: source.startIndex, to: declRange.upperBound)
            var depth = 1
            while index < chars.count, depth > 0 {
                if chars[index] == "(" { depth += 1 }
                if chars[index] == ")" { depth -= 1 }
                index += 1
            }
            guard let open = chars[index...].firstIndex(of: "{") else { continue }
            var close = open + 1
            depth = 1
            while close < chars.count, depth > 0 {
                if chars[close] == "{" { depth += 1 }
                if chars[close] == "}" { depth -= 1 }
                close += 1
            }
            guard close <= chars.count else { continue }

            let bodyStart = source.index(source.startIndex, offsetBy: open)
            let bodyEnd = source.index(source.startIndex, offsetBy: close)
            let line = source[source.startIndex..<declRange.lowerBound]
                .reduce(into: 1) { total, character in if character == "\n" { total += 1 } }
            results.append((source[bodyStart..<bodyEnd], line))
        }
        return results
    }

    /// Whether a toolbar item body contains a `label:` closure whose first expression is a
    /// bare `Image(systemName:)`. Interleaved comment lines are skipped, so documenting
    /// the rule at the call site does not defeat the check.
    private static func hasImageOnlyLabel(_ body: Substring) -> Bool {
        // `(?s)` so a `/* … */` comment may span lines; `NSString.CompareOptions` has no
        // dot-matches-newline flag, only the inline one.
        let pattern = #"(?s)label:\s*\{\s*(?:(?://[^\n]*\n|/\*.*?\*/)\s*)*Image\(systemName:"#
        return body.range(of: pattern, options: [.regularExpression]) != nil
    }
}

// MARK: - SegmentedPickerAccessibilityAuditTests

/// Source-tree gate for #1381: **every icon segment of a segmented `Picker` names itself.**
///
/// ## The defect it stops
/// The Word Cloud's Cloud / List switch built each segment from `Label(mode.label,
/// systemImage:)` and set no accessibility label. On the Mac (build 48, macOS 27) the window's
/// accessibility tree named the two segments "Mostly Cloudy" and "Numbered List": the SF
/// Symbols' own descriptions of `cloud` and `list.number`. So a VoiceOver user switching views
/// heard a weather condition. There, a segment's `Label` took its accessible name from its image.
/// That is the opposite of what ``ToolbarAccessibilityAuditTests`` measured for a toolbar *button*,
/// and that audit reads only a `ToolbarItem`'s `label:` closure, so it never sees a picker's
/// segments.
///
/// ## The rule
/// A segment built from `Label(…, systemImage:)`, from a `Label` whose closures draw
/// `Image(systemName:)` (`Label { … } icon: { … }` or `Label(title: { … }, icon: { … })`), or from
/// `Image(systemName:)` must carry `.accessibilityLabel` in its own modifier chain, the shape
/// `AnalyticsViewModePicker` uses. A `Label` segment is also named when the Picker's own chain
/// forces `.labelStyle(.titleAndIcon)`, so that the segment draws its words; the Search window's
/// reading switch does this. That style does not name an `Image` segment. An `.accessibilityLabel`
/// on the Picker itself names the control, not its segments, so it does not count either.
///
/// ## Each platform is read as it compiles
/// Both app targets compile all of `FRUSExplorer/` (`project.yml`), so every file is read twice:
/// once as iOS compiles it and once as macOS does. A `#if` branch the platform does not take is
/// blanked before anything is matched, so a modifier counts only on a platform that compiles it.
/// The rule holds on every platform where a Picker is segmented: an `.accessibilityLabel` or a
/// `.labelStyle(.titleAndIcon)` behind `#if os(iOS)` does not name a segment on the Mac, which is
/// where #1381 was seen. The scanner decides `os(…)`, `canImport(UIKit)`, `canImport(AppKit)`,
/// `targetEnvironment(macCatalyst)`, `true`, `false`, `!`, `&&`, `||` and parentheses. Anything
/// else, such as `DEBUG` or `targetEnvironment(simulator)`, can ship either way, so every branch
/// is kept; when such a `#if` sits inside a segmented Picker's call or its trailing chain, the
/// Picker is reported rather than judged.
///
/// ## What is in scope, and how it is found
/// A `Picker` is segmented when `.pickerStyle(.segmented)` is in its own trailing modifier chain.
/// A Picker is also segmented when a bare `name.pickerStyle(.segmented)` names a
/// `var name: some View` in the same file that declares it (`ArchivalAnalyticsView`'s
/// `modePicker`). Every match is on a call's balanced parentheses and braces, with comments and
/// string literals blanked first; nothing is matched on a window of lines. Every
/// `.pickerStyle(.segmented)` in the tree must reach a Picker by one of those two routes. A style
/// the scanner cannot trace, such as one set on a container, FAILS the suite rather than leaving
/// its segments unread. So does a segmented Picker whose content holds no `Text`, `Label` or
/// `Image` call at all, because its segments are drawn somewhere the scanner does not read.
///
/// Not in scope, and not reported:
/// - a segment drawn by a helper function or a stored view, when the same content also holds a
///   `Text`, `Label` or `Image` call (a content with none of them is reported, above);
/// - a segment drawn from an asset (`Image("name")`, `Image(_:bundle:)`, `Image(decorative:)`,
///   `Image(uiImage:)`, `Image(nsImage:)`, `Label(_:image:)`);
/// - a style passed as a value (`.pickerStyle(style)`), which is not read as segmented, and any
///   other style that draws icons, such as `.palette`.
/// A name set through a custom modifier or a wrapper view is not credited either, so that shape is
/// reported rather than missed. No segmented picker in the tree builds any of these today.
///
/// ## What it cannot see
/// This reads source, so it gives the same result on every test destination, and it cannot prove
/// what a rendered segment announces. #1381's names were read on a Mac, which has no UI-test
/// target, so the proof that a fix took is the Word Cloud window read in Accessibility Inspector.
///
/// Version history:
///   1.0 — #1381: initial implementation
///   1.1 — #1381 review: each platform is read as it compiles, a `Label(title:icon:)` segment is
///         read, a segmented Picker with no `Text` / `Label` / `Image` call is reported, and the
///         anti-vacuity floors sit in the tree tests they guard
struct SegmentedPickerAccessibilityAuditTests {

    // MARK: - Roots

    private static let sourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// The tree scanned once and shared by the tree tests, which would otherwise read every
    /// source file once per test and once per ``knownIconPickers`` argument.
    private static let tree = Result { try scanTree() }

    // MARK: - Tree tests

    @Test("SegmentedPickerAccessibility: every icon segment of a segmented Picker names itself")
    func everyIconSegmentNamesItself() throws {
        let files = try Self.tree.get()
        // Anti-vacuity, here rather than in a sibling test, because this assertion passes on its
        // own when it reads nothing. A missing source root is not the risk (listing it throws, which
        // fails every tree test); a masker, scanner or `#if` evaluator that stops finding pickers on
        // one platform is, and it would leave this test green on that platform. The floors are
        // loose (`> 20`, not the measured count), so they catch a platform that reads almost
        // nothing, not one that loses a few pickers.
        #expect(files.count > 100, "Scanned only \(files.count) Swift files under \(Self.sourceRoot.path)")
        for platform in Platform.allCases {
            let scans = files.compactMap { $0.scans.first { $0.platform == platform } }
            let pickers = scans.flatMap(\.pickers)
            #expect(pickers.count > 20, "Read only \(pickers.count) segmented pickers as \(platform) compiles them")
            #expect(pickers.contains { !$0.iconSegments.isEmpty },
                    "Read no icon segment as \(platform) compiles the tree")
        }

        var violations: [String] = []
        for file in files {
            for scan in file.scans {
                for picker in scan.pickers {
                    for segment in picker.unnamedSegments {
                        let shape = segment.kind == .label ? "Label(…, systemImage:)" : "Image(systemName:)"
                        let site = "\(file.path):\(segment.line) — a \(shape) segment of the segmented "
                            + "Picker at :\(picker.line), unnamed on "
                        if let index = violations.firstIndex(where: { $0.hasPrefix(site) }) {
                            violations[index] += " and \(scan.platform)"
                        } else {
                            violations.append(site + "\(scan.platform)")
                        }
                    }
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: """
            A segmented Picker's icon segment must name itself. Unnamed, it is announced by its \
            SF Symbol's own description ("Mostly Cloudy" for `cloud`, #1381):

                Label(mode.label, systemImage: mode.systemImage)
                    .tag(mode)
                    .accessibilityLabel(mode.label)                    ✅
                Picker(…) { Label(…) }.pickerStyle(.segmented)
                    .labelStyle(.titleAndIcon)                         ✅ (Label segments only)
                Label(mode.label, systemImage: mode.systemImage).tag(mode)  ❌
                #if os(iOS)
                .accessibilityLabel(mode.label)                        ❌ on macOS
                #endif

            \(violations.joined(separator: "\n"))
            """))
    }

    @Test("SegmentedPickerAccessibility: every segmented style reaches the Picker it styles")
    func everySegmentedStyleReachesItsPicker() throws {
        let files = try Self.tree.get()
        // Anti-vacuity: this assertion also passes when it reads nothing, so it states how much it read.
        for platform in Platform.allCases {
            let styles = files.reduce(0) { total, file in
                total + (file.scans.first { $0.platform == platform }?.segmentedStyleCount ?? 0)
            }
            #expect(styles > 20, "Found only \(styles) `.pickerStyle(.segmented)` modifiers as \(platform) compiles the tree")
        }

        let untraced = files.flatMap { file in
            file.scans.flatMap { scan in
                scan.untraced.map { "\(file.path):\($0.line) (\(scan.platform)) — \($0.reason)" }
            }
        }
        #expect(untraced.isEmpty, Comment(rawValue: """
            Each segmented style or Picker below was not read, so its segments were never judged. \
            Move the style onto the Picker's own chain, draw the segments in the Picker's content, \
            move the `#if` out of the Picker, or teach the scanner the shape:

            \(untraced.joined(separator: "\n"))
            """))
    }

    /// One real picker that exercises a branch of the rule, as it is built today.
    struct KnownIconPicker: Sendable, CustomTestStringConvertible {
        /// The file's base name.
        let file: String
        /// What its icon segments are built from.
        let kind: SegmentKind
        /// How many icon segments its content declares.
        let segments: Int
        /// `true` when the picker forces `.labelStyle(.titleAndIcon)` and sets no segment label;
        /// `false` when every segment carries `.accessibilityLabel` and the style is not forced.
        let namedByTitleAndIcon: Bool
        /// The platforms that compile the picker; on the others the file holds no icon picker.
        let platforms: Set<Platform>
        var testDescription: String { file }
    }

    /// The five files that held a segmented picker with icon segments when #1381 was fixed, each
    /// read the way it is built. `AnalyticsChartChrome` and `CrossReferenceGraphView` are the
    /// `Image` + `.accessibilityLabel` shape; `CrossReferenceGraphView`'s is the graph's
    /// compact-width switch, inside `#if os(iOS)` and drawn only when the horizontal size class is
    /// compact, so an iPad at a compact width shows it as well as an iPhone. Of the five, only
    /// `SearchSheet`'s reading switch is named by `.labelStyle(.titleAndIcon)`, which makes it the
    /// tree's witness for that branch, and the whole file is `#if os(macOS)`. `WordCloudView` and
    /// `DocumentTimelineView` are #1381's two sites. A new file with an icon picker is not added
    /// here automatically; ``everyIconSegmentNamesItself()`` still reads it.
    static let knownIconPickers: [KnownIconPicker] = [
        KnownIconPicker(file: "AnalyticsChartChrome.swift", kind: .image, segments: 2, namedByTitleAndIcon: false,
                        platforms: [.iOS, .macOS]),
        KnownIconPicker(file: "CrossReferenceGraphView.swift", kind: .image, segments: 2, namedByTitleAndIcon: false,
                        platforms: [.iOS]),
        KnownIconPicker(file: "SearchSheet.swift", kind: .label, segments: 1, namedByTitleAndIcon: true,
                        platforms: [.macOS]),
        KnownIconPicker(file: "WordCloudView.swift", kind: .label, segments: 1, namedByTitleAndIcon: false,
                        platforms: [.iOS, .macOS]),
        KnownIconPicker(file: "DocumentTimelineView.swift", kind: .label, segments: 2, namedByTitleAndIcon: false,
                        platforms: [.iOS, .macOS]),
    ]

    @Test("SegmentedPickerAccessibility: the known icon pickers are read the way they are built",
          arguments: knownIconPickers)
    func knownIconPickerIsReadAsBuilt(_ known: KnownIconPicker) throws {
        let files = try Self.tree.get().filter { ($0.path as NSString).lastPathComponent == known.file }
        #expect(files.count == 1, "\(known.file): found \(files.count) files by that name")
        for platform in Platform.allCases {
            let iconPickers = files.flatMap { $0.scans.filter { $0.platform == platform } }
                .flatMap(\.pickers).filter { !$0.iconSegments.isEmpty }
            guard known.platforms.contains(platform) else {
                #expect(iconPickers.isEmpty,
                        "\(known.file): \(platform) compiles an icon picker at \(iconPickers.map(\.line))")
                continue
            }
            let picker = try #require(iconPickers.count == 1 ? iconPickers.first : nil,
                "\(known.file): expected one segmented picker with icon segments on \(platform), found \(iconPickers.count)")
            #expect(picker.iconSegments.count == known.segments, "\(known.file) on \(platform)")
            #expect(picker.iconSegments.allSatisfy { $0.kind == known.kind }, "\(known.file) on \(platform)")
            #expect(picker.forcesTitleAndIcon == known.namedByTitleAndIcon, "\(known.file) on \(platform)")
            #expect(picker.iconSegments.allSatisfy { $0.hasAccessibilityLabel != known.namedByTitleAndIcon },
                    "\(known.file) on \(platform): segment labels \(picker.iconSegments.map(\.hasAccessibilityLabel))")
            #expect(picker.unnamedSegments.isEmpty,
                    "\(known.file) on \(platform): unnamed segments at lines \(picker.unnamedSegments.map(\.line))")
        }
    }

    @Test("SegmentedPickerAccessibility: the tree's by-reference picker is traced")
    func theTreesByReferencePickerIsTraced() throws {
        let files = try Self.tree.get().filter {
            ($0.path as NSString).lastPathComponent == "ArchivalAnalyticsView.swift"
        }
        for platform in Platform.allCases {
            let pickers = files.flatMap { $0.scans.filter { $0.platform == platform } }.flatMap(\.pickers)
            #expect(pickers.count == 1 && pickers.allSatisfy(\.segmentedByReference),
                    "ArchivalAnalyticsView's `modePicker.pickerStyle(.segmented)` on \(platform): \(pickers.map(\.line))")
        }
    }

    // MARK: - Scanner fixtures (one per rule the scan applies)

    /// Scans a fixture that holds no `#if`, which every platform must read the same way, and returns
    /// the macOS reading.
    private func scanAlike(_ source: String) -> FileScan {
        let scans = Self.scan(source)
        let mac = scans.first { $0.platform == .macOS } ?? scans[0]
        for scan in scans where scan.platform != mac.platform {
            #expect(scan.pickers == mac.pickers, "\(scan.platform) and macOS read the fixture differently")
            #expect(scan.untraced.map(\.line) == mac.untraced.map(\.line))
            #expect(scan.segmentedStyleCount == mac.segmentedStyleCount)
        }
        return mac
    }

    /// Scans `source`, requiring it to trace every style and to hold exactly one segmented picker,
    /// read the same way on every platform.
    private func onlyPicker(in source: String) throws -> SegmentedPicker {
        let scan = scanAlike(source)
        #expect(scan.untraced.isEmpty, "untraced styles: \(scan.untraced.map(\.reason))")
        return try #require(scan.pickers.count == 1 ? scan.pickers.first : nil,
                            "expected one segmented picker, found \(scan.pickers.count)")
    }

    @Test("Scanner: a Label(…, systemImage:) segment with no name is flagged")
    func flagsAnUnnamedLabelSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            """#)
        #expect(picker.iconSegments.map(\.kind) == [.label])
        #expect(picker.unnamedSegments.map(\.line) == [3])
    }

    @Test("Scanner: a segment's own .accessibilityLabel names a Label segment")
    func segmentAccessibilityLabelNamesALabelSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                        .accessibilityLabel(mode.label)
                }
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.map(\.hasAccessibilityLabel) == [true])
        #expect(picker.unnamedSegments.isEmpty)
    }

    @Test("Scanner: .labelStyle(.titleAndIcon) on the Picker names its Label segments")
    func titleAndIconNamesLabelSegments() throws {
        let picker = try onlyPicker(in: #"""
            Picker(selection: $reading) {
                ForEach(Reading.allCases) { reading in
                    Label(reading.title, systemImage: reading.systemImage)
                        .tag(reading)
                }
            } label: {
                Text("Reading")
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            """#)
        #expect(picker.forcesTitleAndIcon)
        #expect(picker.iconSegments.map(\.hasAccessibilityLabel) == [false])
        #expect(picker.unnamedSegments.isEmpty)
    }

    @Test("Scanner: .labelStyle(.titleAndIcon) does not name an Image segment")
    func titleAndIconDoesNotNameAnImageSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("Display", selection: $mode) {
                Image(systemName: "chart.bar").tag(Mode.chart)
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            """#)
        #expect(picker.forcesTitleAndIcon)
        #expect(picker.unnamedSegments.map(\.kind) == [.image])
    }

    @Test("Scanner: a segment's own .accessibilityLabel names an Image segment")
    func segmentAccessibilityLabelNamesAnImageSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("Display", selection: $mode) {
                Image(systemName: "chart.bar")
                    .tag(Mode.chart)
                    .accessibilityLabel(String(localized: "k", defaultValue: "Chart"))
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.map(\.kind) == [.image])
        #expect(picker.unnamedSegments.isEmpty)
    }

    @Test("Scanner: each segment is judged on its own chain")
    func eachSegmentIsJudgedOnItsOwnChain() throws {
        let picker = try onlyPicker(in: #"""
            Picker("Display", selection: $mode) {
                Image(systemName: "chart.bar")
                    .tag(Mode.chart)
                Image(systemName: "list.bullet")
                    .tag(Mode.table)
                    .accessibilityLabel("Table")
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.count == 2)
        #expect(picker.unnamedSegments.map(\.line) == [2])
    }

    @Test("Scanner: an .accessibilityLabel on the Picker names no segment")
    func pickerAccessibilityLabelNamesNoSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("View", selection: $mode) {
                Label("Chart", systemImage: "chart.bar").tag(Mode.chart)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("View mode")
            """#)
        #expect(picker.unnamedSegments.map(\.line) == [2])
    }

    @Test("Scanner: only segmented pickers are read")
    func onlySegmentedPickersAreRead() throws {
        let scan = scanAlike(#"""
            Picker("Menu", selection: $a) {
                Label("One", systemImage: "1.circle").tag(1)
            }
            .pickerStyle(.menu)
            Picker("Default", selection: $b) {
                Label("Two", systemImage: "2.circle").tag(2)
            }
            Picker("Segmented", selection: $c) {
                Text("Three").tag(3)
            }
            .pickerStyle(.segmented)
            """#)
        #expect(scan.untraced.isEmpty)
        #expect(scan.segmentedStyleCount == 1)
        #expect(scan.pickers.map(\.line) == [8])
    }

    @Test("Scanner: a Text segment needs no name")
    func textSegmentNeedsNoName() throws {
        let picker = try onlyPicker(in: #"""
            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.isEmpty)
    }

    @Test("Scanner: the Picker's own label closure is not a segment")
    func thePickersLabelClosureIsNotASegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker(selection: $mode) {
                Text("Cloud").tag(Mode.cloud)
            } label: {
                Label("View", systemImage: "eye")
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.isEmpty)
    }

    @Test("Scanner: a chain split by #if / #else is read as each platform compiles it")
    func theChainIsReadAsEachPlatformCompilesIt() throws {
        let source = #"""
            Picker("Format", selection: $isStructured) {
                Label("General", systemImage: "text.alignleft").tag(false)
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.segmented)
            #endif
            #if os(iOS)
            .labelStyle(.titleAndIcon)
            #endif
            """#
        let mac = Self.scan(source, for: .macOS)
        #expect(mac.untraced.isEmpty)
        #expect(mac.segmentedStyleCount == 0)
        #expect(mac.pickers.isEmpty)
        let iOS = Self.scan(source, for: .iOS)
        #expect(iOS.untraced.isEmpty)
        #expect(iOS.pickers.map(\.line) == [1])
        #expect(iOS.pickers.map(\.forcesTitleAndIcon) == [true])
        #expect(iOS.pickers.flatMap(\.unnamedSegments).isEmpty)
    }

    /// A segment named on one platform only, in each place the name can sit.
    struct PlatformNaming: Sendable, CustomTestStringConvertible {
        /// What the shape is.
        let label: String
        /// The fixture source.
        let source: String
        /// The 1-based lines of the unnamed segments on iOS.
        let unnamedOnIOS: [Int]
        /// The 1-based lines of the unnamed segments on macOS.
        let unnamedOnMacOS: [Int]
        /// The platforms that compile the Picker at all.
        var compiledOn: Set<Platform> = [.iOS, .macOS]
        var testDescription: String { label }

        /// The unnamed segment lines expected on `platform`.
        func unnamed(on platform: Platform) -> [Int] {
            platform == .iOS ? unnamedOnIOS : unnamedOnMacOS
        }
    }

    /// One fixture per placement of a platform-gated name. #1381 was seen on the Mac, so a name
    /// only iOS compiles must leave the Mac's segment unnamed; the rule also holds on iOS wherever
    /// iOS compiles the Picker, so a Mac-only name leaves iOS's segment unnamed.
    static let platformNamings: [PlatformNaming] = [
        PlatformNaming(label: "segment label on iOS only", source: #"""
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                    #if os(iOS)
                        .accessibilityLabel(mode.label)
                    #endif
                }
            }
            .pickerStyle(.segmented)
            """#, unnamedOnIOS: [], unnamedOnMacOS: [3]),
        PlatformNaming(label: "segment label on macOS only", source: #"""
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                    #if os(macOS)
                        .accessibilityLabel(mode.label)
                    #endif
                }
            }
            .pickerStyle(.segmented)
            """#, unnamedOnIOS: [3], unnamedOnMacOS: []),
        PlatformNaming(label: "segment label in both branches", source: #"""
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                    #if os(iOS)
                        .accessibilityLabel(mode.label)
                    #else
                        .accessibilityLabel(mode.macLabel)
                    #endif
                }
            }
            .pickerStyle(.segmented)
            """#, unnamedOnIOS: [], unnamedOnMacOS: []),
        PlatformNaming(label: "titleAndIcon on iOS only", source: #"""
            Picker("View", selection: $mode) {
                Label("Cloud", systemImage: "cloud").tag(Mode.cloud)
            }
            .pickerStyle(.segmented)
            #if os(iOS)
            .labelStyle(.titleAndIcon)
            #endif
            """#, unnamedOnIOS: [], unnamedOnMacOS: [2]),
        // iOS takes the `#if`, so the `#elseif` is not taken there although its condition holds.
        PlatformNaming(label: "titleAndIcon under #elseif, after a branch iOS takes", source: #"""
            Picker("View", selection: $mode) {
                Label("Cloud", systemImage: "cloud").tag(Mode.cloud)
            }
            .pickerStyle(.segmented)
            #if canImport(UIKit)
            .labelStyle(.iconOnly)
            #elseif canImport(AppKit) || os(iOS)
            .labelStyle(.titleAndIcon)
            #endif
            """#, unnamedOnIOS: [2], unnamedOnMacOS: []),
        PlatformNaming(label: "nested: an iOS label inside a macOS-only picker", source: #"""
            #if !os(iOS)
            Picker("View", selection: $mode) {
                Label("Cloud", systemImage: "cloud")
                    .tag(Mode.cloud)
                #if os(iOS) || os(visionOS)
                    .accessibilityLabel("Cloud")
                #endif
            }
            .pickerStyle(.segmented)
            #endif
            """#, unnamedOnIOS: [], unnamedOnMacOS: [3], compiledOn: [.macOS]),
        PlatformNaming(label: "nested: a macOS label inside a picker both compile", source: #"""
            Picker("View", selection: $mode) {
                Image(systemName: "cloud")
                    .tag(Mode.cloud)
                #if os(macOS)
                #if canImport(AppKit) && !(os(iOS) || targetEnvironment(macCatalyst))
                    .accessibilityLabel("Cloud")
                #endif
                #endif
            }
            .pickerStyle(.segmented)
            """#, unnamedOnIOS: [2], unnamedOnMacOS: []),
    ]

    @Test("Scanner: a name counts only on a platform that compiles it", arguments: platformNamings)
    func aNameCountsOnlyWhereItIsCompiled(_ naming: PlatformNaming) {
        for platform in Platform.allCases {
            let scan = Self.scan(naming.source, for: platform)
            #expect(scan.untraced.isEmpty, "\(platform): \(scan.untraced.map(\.reason))")
            #expect(scan.pickers.count == (naming.compiledOn.contains(platform) ? 1 : 0), "\(platform)")
            #expect(scan.pickers.flatMap(\.unnamedSegments).map(\.line) == naming.unnamed(on: platform),
                    "\(platform)")
        }
    }

    @Test("Scanner: a #if it cannot decide inside a segmented Picker is reported, not judged")
    func anUndecidableDirectiveInsideAPickerIsReported() throws {
        let source = #"""
            Picker("View", selection: $mode) {
                Label("Cloud", systemImage: "cloud")
                    .tag(Mode.cloud)
                #if DEBUG
                    .accessibilityLabel("Cloud")
                #endif
            }
            .pickerStyle(.segmented)
            """#
        for platform in Platform.allCases {
            let scan = Self.scan(source, for: platform)
            #expect(scan.pickers.isEmpty, "\(platform)")
            #expect(scan.untraced.map(\.line) == [1], "\(platform): \(scan.untraced.map(\.reason))")
        }
        // Decided by the platform before the undecidable one is reached: nothing on iOS to judge.
        let gated = "#if os(macOS)\n" + source + "\n#endif"
        #expect(Self.scan(gated, for: .iOS).untraced.isEmpty)
        #expect(Self.scan(gated, for: .iOS).pickers.isEmpty)
        #expect(Self.scan(gated, for: .macOS).untraced.map(\.line) == [2])
        // Around the whole Picker it hides nothing inside it, so the Picker is read and judged.
        let around = "#if DEBUG\n" + #"""
            Picker("View", selection: $mode) {
                Label("Cloud", systemImage: "cloud").tag(Mode.cloud)
            }
            .pickerStyle(.segmented)
            """# + "\n#endif"
        let aroundPicker = try onlyPicker(in: around)
        #expect(aroundPicker.unnamedSegments.map(\.line) == [3])
    }

    @Test("Scanner: comments and string literals are not code")
    func commentsAndStringsAreNotCode() throws {
        let source = ##"""
            // Picker("Commented", selection: $x) { Label("x", systemImage: "x") }.pickerStyle(.segmented)
            /* .pickerStyle(.segmented) /* nested */ Picker( */
            Picker(String(localized: "k", defaultValue: "View ("), selection: $mode) {
                Label(String(localized: "k2", defaultValue: "Cloud :) {"), systemImage: "cloud").tag(Mode.cloud)
                Label(#"raw \(not an interpolation"#, systemImage: "list.number")
                    .tag(Mode.list)
                    .accessibilityLabel("List \(names[1]) \"(\"")
            }
            .pickerStyle(.segmented)
            """##
        let scan = scanAlike(source)
        #expect(scan.segmentedStyleCount == 1)
        let picker = try onlyPicker(in: source)
        #expect(picker.line == 3)
        #expect(picker.iconSegments.map(\.line) == [4, 5])
        #expect(picker.unnamedSegments.map(\.line) == [4])
    }

    @Test("Scanner: the Label builder form is one segment, not two")
    func labelBuilderFormIsOneSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("View", selection: $mode) {
                Label {
                    Text("Cloud")
                } icon: {
                    Image(systemName: "cloud")
                }
                .tag(Mode.cloud)
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.map(\.kind) == [.label])
        #expect(picker.unnamedSegments.map(\.line) == [2])
    }

    @Test("Scanner: Label(title:icon:) written with parentheses is one symbol segment")
    func labelTitleIconArgumentFormIsASymbolSegment() throws {
        let picker = try onlyPicker(in: #"""
            Picker("View", selection: $mode) {
                Label(title: { Text("Cloud") }, icon: { Image(systemName: "cloud") })
                    .tag(Mode.cloud)
                Label(title: { Text("List") }) {
                    Image(systemName: "list.number")
                }
                .tag(Mode.list)
                .accessibilityLabel("List")
                Label(title: { Text("Asset") }, icon: { Image("asset") })
                    .tag(Mode.asset)
            }
            .pickerStyle(.segmented)
            """#)
        #expect(picker.iconSegments.map(\.kind) == [.label, .label])
        #expect(picker.iconSegments.map(\.line) == [2, 4])
        #expect(picker.unnamedSegments.map(\.line) == [2])
    }

    @Test("Scanner: a style on a property reference reaches the Picker the property declares")
    func aStyleOnAPropertyReferenceReachesItsPicker() throws {
        let picker = try onlyPicker(in: #"""
            private var modePicker: some View {
                Picker("Mode", selection: $mode) {
                    Image(systemName: "chart.bar").tag(Mode.chart)
                }
            }
            var body: some View {
                if compact {
                    modePicker.pickerStyle(.menu)
                } else {
                    modePicker.pickerStyle(.segmented)
                }
            }
            """#)
        #expect(picker.segmentedByReference)
        #expect(picker.unnamedSegments.map(\.line) == [3])
    }

    /// A `.pickerStyle(.segmented)` the scanner must report rather than skip.
    struct UntraceableShape: Sendable, CustomTestStringConvertible {
        /// What the shape is.
        let label: String
        /// The fixture source.
        let source: String
        /// The 1-based line the report must name.
        let line: Int
        var testDescription: String { label }
    }

    /// One fixture per way a style can fail to reach a Picker's segments.
    static let untraceableShapes: [UntraceableShape] = [
        UntraceableShape(label: "style on a container", source: #"""
            VStack {
                Picker("Mode", selection: $mode) { Text("A").tag(1) }
            }
            .pickerStyle(.segmented)
            """#, line: 4),
        UntraceableShape(label: "reference with no declaration", source: #"""
            var body: some View {
                modePicker.pickerStyle(.segmented)
            }
            """#, line: 2),
        UntraceableShape(label: "declaration with no Picker", source: #"""
            private var modePicker: some View {
                Text("Mode")
            }
            var body: some View {
                modePicker.pickerStyle(.segmented)
            }
            """#, line: 5),
        UntraceableShape(label: "Picker with no trailing content closure", source: #"""
            Picker("Mode", selection: $mode, content: {
                Label("A", systemImage: "a.circle").tag(1)
            })
            .pickerStyle(.segmented)
            """#, line: 1),
        UntraceableShape(label: "segments drawn by a helper", source: #"""
            Picker("View", selection: $mode) {
                ForEach(WordCloudViewMode.allCases, id: \.self) { segment(for: $0) }
            }
            .pickerStyle(.segmented)
            func segment(for mode: WordCloudViewMode) -> some View {
                Label(mode.label, systemImage: mode.systemImage).tag(mode)
            }
            """#, line: 1),
    ]

    @Test("Scanner: a segmented style it cannot trace is reported, not skipped",
          arguments: untraceableShapes)
    func untraceableStyleIsReported(_ shape: UntraceableShape) {
        let scan = scanAlike(shape.source)
        #expect(scan.pickers.isEmpty)
        #expect(scan.untraced.map(\.line) == [shape.line], "reasons: \(scan.untraced.map(\.reason))")
    }

    // MARK: - Model

    /// A platform the app targets compile `FRUSExplorer/` for; every file is read once for each.
    enum Platform: String, CaseIterable, Sendable, CustomStringConvertible {
        /// The iOS target, iPadOS included.
        case iOS
        /// The macOS target, where #1381 was seen.
        case macOS
        var description: String { rawValue }
    }

    /// What an icon segment is built from.
    enum SegmentKind: String, Sendable {
        /// `Label(…, systemImage:)`, or a `Label` whose closures draw `Image(systemName:)`.
        case label
        /// A bare `Image(systemName:)`.
        case image
    }

    /// One segment of a segmented picker that is drawn from an SF Symbol.
    struct IconSegment: Sendable, Equatable {
        /// What the segment is built from.
        let kind: SegmentKind
        /// 1-based line of the `Label` / `Image` call.
        let line: Int
        /// Whether the segment's own modifier chain carries `.accessibilityLabel`.
        let hasAccessibilityLabel: Bool
    }

    /// One segmented `Picker` declaration, as one platform compiles it.
    struct SegmentedPicker: Sendable, Equatable {
        /// 1-based line of the `Picker(` call.
        let line: Int
        /// `true` when the picker is segmented through `name.pickerStyle(.segmented)` on a
        /// property that declares it, rather than through its own chain.
        let segmentedByReference: Bool
        /// Whether the picker's own chain forces `.labelStyle(.titleAndIcon)`.
        let forcesTitleAndIcon: Bool
        /// The segments drawn from an SF Symbol, in source order.
        let iconSegments: [IconSegment]

        /// Whether `segment` announces a name rather than its symbol's description.
        func names(_ segment: IconSegment) -> Bool {
            segment.hasAccessibilityLabel || (segment.kind == .label && forcesTitleAndIcon)
        }

        /// The icon segments that announce their symbol's description.
        var unnamedSegments: [IconSegment] { iconSegments.filter { !names($0) } }
    }

    /// A segmented style or Picker whose segments the scanner did not judge.
    struct UntracedStyle: Sendable {
        /// 1-based line of the modifier, or of the Picker when the Picker was found.
        let line: Int
        /// Why the segments were not judged.
        let reason: String
    }

    /// What one file's scan found, as one platform compiles the file.
    struct FileScan: Sendable {
        /// The platform whose compiled code was read.
        let platform: Platform
        /// Every segmented picker whose segments were read, in source order.
        let pickers: [SegmentedPicker]
        /// Every segmented style or Picker whose segments were not judged.
        let untraced: [UntracedStyle]
        /// How many `.pickerStyle(.segmented)` modifiers the platform compiles in the file.
        let segmentedStyleCount: Int
    }

    // MARK: - Scanner

    /// Every Swift file under the app source root with its path relative to the root, scanned once
    /// per platform.
    static func scanTree() throws -> [(path: String, scans: [FileScan])] {
        try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { path in
                let source = try String(contentsOf: sourceRoot.appendingPathComponent(path), encoding: .utf8)
                return (path, scan(source))
            }
    }

    /// Scans one Swift source file once for each platform, in ``Platform/allCases`` order.
    static func scan(_ source: String) -> [FileScan] {
        let masked = MaskedSwift(source)
        return Platform.allCases.map { scan(masked, for: $0) }
    }

    /// Scans one Swift source file as `platform` compiles it.
    static func scan(_ source: String, for platform: Platform) -> FileScan {
        scan(MaskedSwift(source), for: platform)
    }

    /// Scans masked source for segmented pickers and their icon segments, as `platform` compiles it.
    private static func scan(_ masked: MaskedSwift, for platform: Platform) -> FileScan {
        let (code, undecided) = masked.compiled(for: platform)
        let pickerCalls = code.occurrences(of: "Picker").compactMap { code.call(named: "Picker", at: $0) }
            .filter { $0.arguments != nil }
        let styleSites = code.occurrences(of: "pickerStyle").filter { offset in
            offset > 0 && code.bytes[offset - 1] == ASCII.dot
                && code.call(named: "pickerStyle", at: offset).map(code.isSegmentedStyle) == true
        }.map { $0 - 1 }

        var pickers: [SegmentedPicker] = []
        var untraced: [UntracedStyle] = []
        var traced: Set<Int> = []
        var recorded: Set<Int> = []

        func record(_ picker: MaskedSwift.Call, byReference: Bool) {
            guard recorded.insert(picker.start).inserted else { return }
            let line = code.line(at: picker.start)
            guard let content = picker.trailingClosure else {
                untraced.append(UntracedStyle(
                    line: line,
                    reason: "the segmented Picker has no trailing content closure, so its segments were not read"))
                return
            }
            let chain = code.modifierChain(after: picker.end)
            let extent = picker.start..<(chain.last?.end ?? picker.end)
            if let directive = undecided.first(where: extent.contains) {
                untraced.append(UntracedStyle(
                    line: line,
                    reason: "the `#if` at :\(code.line(at: directive)) inside the segmented Picker has a "
                        + "condition the scanner cannot decide for \(platform), so which of its modifiers "
                        + "\(platform) compiles is unknown"))
                return
            }
            guard code.holdsSegmentCall(content) else {
                untraced.append(UntracedStyle(
                    line: line,
                    reason: "the segmented Picker's content holds no Text, Label or Image call, so its "
                        + "segments are drawn somewhere the scanner does not read (a helper function?)"))
                return
            }
            pickers.append(SegmentedPicker(
                line: line,
                segmentedByReference: byReference,
                forcesTitleAndIcon: chain.contains(where: code.isTitleAndIconStyle),
                iconSegments: code.iconSegments(in: content)))
        }

        for picker in pickerCalls {
            let styles = code.modifierChain(after: picker.end).filter(code.isSegmentedStyle)
            guard !styles.isEmpty else { continue }
            styles.forEach { traced.insert($0.start) }
            record(picker, byReference: false)
        }
        for site in styleSites where !traced.contains(site) {
            switch code.pickersReferenced(beforeModifierAt: site, among: pickerCalls) {
            case .success(let referenced):
                referenced.forEach { record($0, byReference: true) }
            case .failure(let failure):
                untraced.append(UntracedStyle(line: code.line(at: site), reason: failure.reason))
            }
        }
        return FileScan(platform: platform,
                        pickers: pickers.sorted { $0.line < $1.line },
                        untraced: untraced.sorted { $0.line < $1.line },
                        segmentedStyleCount: styleSites.count)
    }
}

// MARK: - MacSheetToolbarPlacementAuditTests

/// Source-tree gate for #1377: **a view the Mac presents with `.sheet` puts no toolbar item where
/// a macOS sheet does not draw one.**
///
/// ## The defect it stops
/// On macOS, Export packet in the Archives Visits window opened `TripPacketSheet`, and the sheet
/// showed only Done. The sheet was one `NavigationStack` for both platforms, with Done at
/// `.confirmationAction`, the Options menu at `.secondaryAction`, and Share and Share as PDF at
/// `.primaryAction`. In the build-48 capture (macOS 27) the Mac sheet drew the `.confirmationAction`
/// item and nothing at `.primaryAction` or `.secondaryAction`. So a Mac reader could not share the
/// packet, scope it to one repository, copy a facility's inquiry draft, or change what it includes.
/// iOS gives the same `NavigationStack` a navigation bar, so all four items showed there, and
/// neither test target runs on macOS. (A Mac sheet does draw some toolbar items: #1461's Mac check
/// saw `Button`s drawn at `.primaryAction` and with no placement. See ``pendingMacChecks``.)
///
/// ## The rule
/// A toolbar item in a view the Mac presents with `.sheet` must sit at `.confirmationAction` or
/// `.cancellationAction`, the two placements #1377's rule admits. The capture saw a Mac sheet draw
/// the first; the second is the first's pair in the sheet's button row. Anything else fails:
/// `.primaryAction`, `.secondaryAction`, `.principal`, `.navigation`, `.destructiveAction`, and an
/// item that passes no `placement:` at all, which is `.automatic`. `.destructiveAction` fails
/// because no capture has shown a Mac sheet drawing it; the scan finds no Mac sheet that uses it.
/// The fix is a `#if os(macOS)` body that is a plain `VStack` with no `NavigationStack`, its buttons
/// laid out in the view: a header row, the content, and a bottom button bar whose confirming button
/// carries `.keyboardShortcut(.defaultAction)`. `ResearchNoteEditorView`'s Mac body is that shape
/// (Discard and Save in the bottom bar). `ArchiveVisitTierSheet`'s is the header-only form, with its
/// one Done in the header row.
///
/// ## How the sheets are found
/// The tree is read as macOS compiles it, through the `#if` evaluation
/// ``SegmentedPickerAccessibilityAuditTests`` uses, with comments and string literals blanked; every
/// match is on a call's balanced parentheses and braces, never on a window of lines.
/// 1. Every `.sheet(` call with an argument list is a presenter. Its content is the trailing
///    closure, or a `content:` closure in the argument list. A presenter whose content is not a
///    closure fails the suite rather than being skipped.
/// 2. The content is read together with the members of the presenting view it names
///    (`.sheet(…) { saveSearchSheet }`), the members those name, and so on.
/// 3. Each view type that code constructs (`Name(`, `Name {`, `Name<`, `Name.init(`) and the tree
///    declares as a `View` is presented. A view is read from its `body`, through the members `body`
///    reaches on the Mac, so an `iOSBody` that the Mac's `body` never names is not read
///    (`ResearchNoteEditorView`). The view types that code constructs are read the same way, to any
///    depth, because a toolbar item in a view the sheet composes is in the sheet too.
/// 4. Each `ToolbarItem(` / `ToolbarItemGroup(` in what was read is judged by the `placement:`
///    argument at the top level of its own argument list. A `placement:` in the item's content, in
///    a comment, or in a string literal is not the item's placement.
///
/// ## What it cannot see
/// - A view put straight into a `.toolbar { }` closure, with no `ToolbarItem` around it, also sits
///   at `.automatic`, and this scan does not read it. Measured 2026-09-24 over the tree as macOS
///   compiles it, with #1377's fix in: 66 `.toolbar { }` closures anywhere in the tree, none holding
///   a view outside a `ToolbarItem` or `ToolbarItemGroup` call.
/// - A view built by a function outside the presenting view, such as a factory on another type.
/// - A view presented by `.popover`, `.inspector`, or AppKit.
/// - Whether a macOS sheet really draws what it is given. This reads source, so it gives the same
///   result on every test destination, iPhone and iPad alike. The proof that a Mac sheet shows its
///   controls is the sheet opened on a Mac, which is the owner's check (the 2026-09-24 entry in
///   `Planning/DEVELOPMENT-PLAN.md`). The scan also cannot tell that a fix kept a sheet's controls
///   rather than deleting them; ``tripPacketSheetMacBodyHoldsItsControls()`` pins that for the
///   packet sheet, and ``archivalAllUnitsSheetMacBodyHoldsItsControls()`` for the Every Unit sheet.
///
/// ## Pending the owner's Mac check
/// ``pendingMacChecks`` lists the views the scan flags that #1377 does not fix, each with the
/// placements it holds and the files of the Mac `.sheet(` calls that reach it. It is not
/// permission. The plan (§4 item 14) has the owner open each one on a Mac before it is fixed or
/// split into its own issue. An entry is in one of two states: awaiting that check, or checked, its
/// controls seen drawn, and kept because this rule judges placement and no test has isolated what
/// else decides whether a Mac sheet draws an item; a checked entry's reason records what the check
/// saw. The list is exact on both placements and presenters: a listed view that gains an item, loses
/// one, gains a Mac presenter, loses one, or is fixed fails the suite until the list says so, and so
/// does a view listed twice.
///
/// Version history:
///   1.0 — #1377: initial implementation
///   1.1 — #1377 review, round 1: `pendingMacChecks` is exact on presenters as well as placements,
///          a view listed twice is reported rather than trapping, and `finish()`'s commit is pinned
///          (``tripPacketSheetFinishCommitsBeforeClosing()``)
///   1.2 — #1462: `ArchiveVisitEditorView` leaves `pendingMacChecks`, and a second rule keeps a view
///          whose Mac size and controls come from a window scene out of every Mac sheet
///          (``windowHostedViews``, read through the scan's new `reachedBy`)
///   1.3 — #1461: `ArchivalAllUnitsSheet` leaves `pendingMacChecks` with a Mac body of its own, and
///          ``archivalAllUnitsSheetMacBodyHoldsItsControls()`` pins that body's Export menu and Done;
///          the `ChartDataInspectorView` and `InAppBrowserView` entries record the same Mac check,
///          and the list's contract names its second state, checked and kept
struct MacSheetToolbarPlacementAuditTests {

    /// The platforms the scanner reads for; only the Mac's reading is judged.
    typealias Platform = SegmentedPickerAccessibilityAuditTests.Platform

    // MARK: - Roots

    private static let sourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// The tree read once, as macOS compiles it, and shared by the tree tests.
    private static let tree = Result { try scanTree(for: .macOS) }

    // MARK: - Pending the owner's Mac check

    /// A view the scan flags that #1377 does not fix: awaiting the owner's check on a Mac, or
    /// checked, its controls seen drawn, and kept under this rule, which judges placement alone.
    struct PendingMacCheck: Sendable {
        /// The view type that declares the items.
        let type: String
        /// The names of the placements its items sit at that the rule does not admit, sorted.
        let placements: [String]
        /// The file of each Mac `.sheet(` call that reaches the view, directly or through the views
        /// it presents or composes, sorted, once per call: a file with two such calls is listed
        /// twice. A file rather than `path:line`, so an edit above a presenter does not move the entry.
        let presenters: [String]
        /// Why it is listed and what the owner is to look at, and, once checked, what the check saw.
        let reason: String
    }

    /// The views the scan flags that #1377 left for the owner to confirm on a Mac first; two of the
    /// three have been checked and kept (the last paragraph).
    ///
    /// The first is one of the two #1377 names. The other, `ArchivalAllUnitsSheet`, left the list
    /// when #1461 gave it a Mac body, after the owner's Mac check found its Export menu undrawn
    /// (``archivalAllUnitsSheetMacBodyHoldsItsControls()`` pins that the body kept the menu). The
    /// last two were found by this scan and are not in the issue; a third, `ArchiveVisitEditorView`,
    /// left the list when #1462 moved both its Mac presenters to the Archives Visits window
    /// (``windowHostedViews`` now keeps it out of every Mac sheet). The `ArchivalNeighborsSheet`
    /// entry's reason is the one that rests on its presenters alone, which is why every entry
    /// records them: a new Mac presenter of a listed view fails the suite rather than widening a
    /// pending defect, or falsifying a reason, in silence.
    ///
    /// The same Mac check (2026-09-25, recorded in #1461) opened `ChartDataInspectorView` and
    /// `InAppBrowserView` and saw both draw their controls, which are `Button`s. They stay listed
    /// because this rule is by placement, and what has failed to draw so far — the Every Unit sheet's
    /// `Menu`, #1377's `Menu` and two `ShareLink`s — fits the KIND of control mattering, which no
    /// test has isolated. They are the list's checked-and-kept entries, and their reasons record the
    /// check.
    static let pendingMacChecks: [PendingMacCheck] = [
        PendingMacCheck(
            type: "ChartDataInspectorView", placements: ["primaryAction"],
            presenters: [
                "Analytics/ArchivalAnalyticsView.swift", "Analytics/ArchivalAnalyticsView.swift",
                "Analytics/CrossReferenceAnalyticsView.swift", "App/MacCorpusBrowserWindow.swift",
                "Browser/CompilationView.swift", "CrossReference/CrossReferenceGraphView.swift",
                "SeriesAnalytics/AdministrationProfilesDashboard.swift",
                "SeriesAnalytics/SeriesGeographyDashboard.swift", "SeriesAnalytics/SeriesProductionDashboard.swift",
                "SeriesAnalytics/SourceProvenanceDashboard.swift", "SeriesAnalytics/SourceProvenanceDashboard.swift",
                "SourceExplorer/CollectionBrowserView.swift", "SourceExplorer/CollectionDetailView.swift",
                "SourceExplorer/MacSourceExplorerView.swift",
            ],
            reason: "#1377 names it: Copy (the table as CSV) at .primaryAction, beside Done at "
                + ".cancellationAction; the analytics dashboards' and Source Explorer's table inspectors "
                + "present it on the Mac, and so does a collection's detail sheet (its timeline "
                + "inspector) wherever that sheet opens. Checked on a Mac 2026-09-25 (#1461), in "
                + "Archival Analytics' table inspector: Copy was drawn"),
        PendingMacCheck(
            type: "InAppBrowserView", placements: ["automatic"],
            presenters: [
                "Onboarding/IndexingEducationView.swift", "Settings/AboutView.swift", "Settings/AboutView.swift",
                "Settings/AboutView.swift",
            ],
            reason: "found by this scan: on the Mac, Back, Forward, Open in Browser and Close share one "
                + "ToolbarItemGroup with no placement, and About, Full Notices and the Research Guide "
                + "present the browser in a sheet — if the sheet draws none of them it has no Close. "
                + "Checked on a Mac 2026-09-25 (#1461), in About's browser sheet: all four were drawn"),
        PendingMacCheck(
            type: "ArchivalNeighborsSheet", placements: ["principal"],
            presenters: ["Search/SearchView.swift"],
            reason: "found by this scan: its title and archival-basis subtitle sit at .principal; the "
                + "Mac compiles SearchView's presenter, but only the iOS MainTabView mounts SearchView, "
                + "and the Mac opens Archival Neighbors as a window"),
    ]

    // MARK: - Tree tests

    @Test("MacSheetToolbarPlacement: every toolbar item a Mac sheet presents is one the sheet draws")
    func everyMacSheetToolbarItemIsDrawn() throws {
        let scan = try Self.tree.get()
        // Anti-vacuity, in the test it guards, because the assertions below pass on a scan that
        // reads nothing. Measured 2026-09-24: 479 files, 136 presenters, 74 presented types. The
        // floors are loose so they catch a scanner that stops matching, not a tree that loses a few.
        #expect(scan.filesRead > 100, "Read only \(scan.filesRead) Swift files under \(Self.sourceRoot.path)")
        #expect(scan.presenters.count > 100, "Found only \(scan.presenters.count) .sheet( presenters the Mac compiles")
        #expect(scan.presentedTypes.count > 40, "Resolved only \(scan.presentedTypes.count) presented view types")
        #expect(scan.presentedTypes.contains("TripPacketSheet"),
                "TripPacketSheet is not among the types the Mac's sheets present, so #1377's own sheet went unread")

        let violations = Self.violations(in: scan, pending: Self.pendingMacChecks)
        #expect(violations.isEmpty, Comment(rawValue: """
            In #1377's capture a macOS sheet drew its `.confirmationAction` item and nothing at \
            `.primaryAction` or `.secondaryAction`, and #1461's drew no `Menu` at `.primaryAction`; \
            this rule admits only `.confirmationAction` and `.cancellationAction`. Give the view a \
            `#if os(macOS)` body that lays its buttons out itself — a header row, the content, and a \
            bottom button bar with the confirming button as `.keyboardShortcut(.defaultAction)`, as \
            the Mac bodies of `ResearchNoteEditorView` and `TripPacketSheet` do:

            \(violations.joined(separator: "\n"))
            """))
    }

    /// Everything the tree test reports for `scan` against `pending`, one line each: a presenter
    /// whose content was not read; a view with undrawn items that `pending` does not list; a listed
    /// view whose undrawn placements differ from the entry; a listed view whose presenters' files
    /// differ from the entry; an undrawn item written in a sheet's own content; a listed view no
    /// sheet reaches an undrawn item in any more; and a view `pending` lists more than once.
    ///
    /// Grouped by the view that declares the items, the last link of a finding's chain, because the
    /// defect is that view's and the list is keyed by it. An item in a sheet's content belongs to that
    /// presenter alone and is never listable.
    static func violations(in scan: Scan, pending: [PendingMacCheck]) -> [String] {
        var violations = scan.presenters.compactMap { presenter in
            presenter.untraced.map { "\(presenter.path):\(presenter.line) — \($0)" }
        }
        var undrawnByOwner: [String: [ToolbarItemSite]] = [:]
        var presentersByOwner: [String: Set<String>] = [:]
        var inlineByPresenter: [String: [ToolbarItemSite]] = [:]
        for finding in scan.findings {
            if let owner = finding.chain.last {
                undrawnByOwner[owner] = (scan.readings[owner]?.items ?? []).filter { !$0.isDrawnInAMacSheet }
                presentersByOwner[owner, default: []].insert(finding.presenter)
            } else {
                inlineByPresenter[finding.presenter, default: []].append(finding.item)
            }
        }
        /// One line per site, for a message.
        func sites(_ items: [ToolbarItemSite]) -> String {
            items.map { "\($0.path):\($0.line) \($0.call) at \($0.placementName)" }.joined(separator: "; ")
        }
        /// The file of a `path:line` presenter site.
        func file(_ site: String) -> String { site.split(separator: ":").dropLast().joined(separator: ":") }
        // A view listed twice is reported below; `uniqueKeysWithValues` would trap on it instead,
        // taking the test process down with no message.
        let listed = Dictionary(pending.map { ($0.type, $0) }, uniquingKeysWith: { first, _ in first })
        for (owner, undrawn) in undrawnByOwner.sorted(by: { $0.key < $1.key }) {
            let placements = undrawn.map(\.placementName).sorted()
            let presenterSites = (presentersByOwner[owner] ?? []).sorted()
            let presentedBy = presenterSites.joined(separator: ", ")
            if let entry = listed[owner] {
                if entry.placements != placements {
                    violations.append("\(owner): pendingMacChecks lists \(entry.placements), the scan finds "
                        + "\(placements) (\(sites(undrawn))) — update the entry")
                }
                let presenters = presenterSites.map(file).sorted()
                if entry.presenters != presenters {
                    violations.append("\(owner): pendingMacChecks lists presenters \(entry.presenters), the scan "
                        + "finds \(presenters) (\(presentedBy)) — update the entry, and its reason if a new "
                        + "presenter changes it")
                }
            } else {
                violations.append("\(owner), presented by \(presentedBy): \(sites(undrawn))")
            }
        }
        for (presenter, items) in inlineByPresenter.sorted(by: { $0.key < $1.key }) {
            violations.append("the content of the sheet at \(presenter): \(sites(items))")
        }
        for entry in pending where undrawnByOwner[entry.type] == nil {
            violations.append("\(entry.type): listed in pendingMacChecks, but no Mac sheet reaches an undrawn "
                + "item in it any more — remove the entry")
        }
        for (type, entries) in Dictionary(grouping: pending, by: \.type).sorted(by: { $0.key < $1.key })
        where entries.count > 1 {
            violations.append("\(type): listed \(entries.count) times in pendingMacChecks — keep one entry")
        }
        return violations
    }

    // MARK: - Views the Mac hosts only in a window (#1462)

    /// A view whose size and controls, on the Mac, come from the window scene that hosts it.
    struct WindowHostedView: Sendable {
        /// The view type.
        let type: String
        /// The file that declares it, under the source root.
        let path: String
        /// The window scene that hosts it on the Mac.
        let windowId: String
        /// Why a Mac sheet cannot host it.
        let reason: String
    }

    /// The views no Mac sheet may present or compose (#1462).
    ///
    /// ``everyMacSheetToolbarItemIsDrawn()`` catches a view whose toolbar a Mac sheet does not draw;
    /// this catches the other half of #1462, a view with no size of its own, which a macOS sheet
    /// collapses to its intrinsic height. It holds even for a version of the view that moved its
    /// controls out of the toolbar, which the placement rule would pass.
    static let windowHostedViews: [WindowHostedView] = [
        WindowHostedView(
            type: "ArchiveVisitEditorView", path: "TripPacket/ArchiveVisitEditorView.swift",
            windowId: "frus.archiveVisits",
            reason: "on the Mac the editor's body is a List with no size of its own, sized by the window "
                + "(MacArchiveVisitManagerView's frame and the scene's default size), and every control — "
                + "the Targets | Documents switcher, Filter, Export packet, About research targets, ⋯ — is "
                + "the window's toolbar. In a sheet (#1462) it collapsed to a strip holding only Done. Open "
                + "a plan on the Mac with AppState.openArchiveVisitWindow(on:using:)"),
    ]

    @Test("MacSheetToolbarPlacement: a view sized and controlled by its Mac window is in no Mac sheet (#1462)")
    func windowHostedViewsAreInNoMacSheet() throws {
        let scan = try Self.tree.get()
        // Anti-vacuity: the scan reached views through sheets at all. The floor is the one the tree
        // test sets for directly presented types; `reachedBy` holds those and every view they compose.
        #expect(scan.reachedBy.count > 40, "The Mac's sheets reached only \(scan.reachedBy.count) view types")
        for view in Self.windowHostedViews {
            let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(view.path), encoding: .utf8)
            #expect(source.contains("struct \(view.type): View"),
                    "\(view.path) no longer declares \(view.type), so this rule checks nothing — re-derive it")
            let presenters = scan.reachedBy[view.type] ?? []
            #expect(presenters.isEmpty, """
                \(view.type) is in a Mac sheet, presented or composed, at \(presenters.joined(separator: ", ")). \
                It belongs in the \(view.windowId) window: \(view.reason).
                """)
        }
    }

    @Test("MacSheetToolbarPlacement: reachedBy names every view a Mac sheet presents or composes, and no other")
    func reachedByNamesPresentedAndComposedViews() {
        let scan = Self.scan([
            SourceFile(path: "Host.swift", source: """
                struct Host: View {
                    @State private var shown = false
                    var body: some View {
                        Text("Host")
                            .sheet(isPresented: $shown) { Packet() }
                            #if os(iOS)
                            .sheet(isPresented: $shown) { Phone() }
                            #endif
                    }
                }
                """),
            SourceFile(path: "Packet.swift", source: """
                struct Packet: View {
                    var body: some View { VStack { Middle() } }
                }
                struct Middle: View {
                    var body: some View { Text("x") }
                }
                struct Phone: View {
                    var body: some View { Text("x") }
                }
                struct Window: View {
                    var body: some View { Middle() }
                }
                """),
        ], for: .macOS)
        #expect(scan.reachedBy == ["Packet": ["Host.swift:5"], "Middle": ["Host.swift:5"]], """
            A presented view and the view it composes are each reached by the presenter; a view only an \
            iOS presenter holds, and one no sheet holds, are not: \(scan.reachedBy)
            """)
    }

    @Test("MacSheetToolbarPlacement: the pending list must match the scan exactly, entry by entry")
    func pendingListMatchesExactly() {
        let scan = Self.scan([
            Self.host("""
                NavigationStack {
                    Packet().toolbar { ToolbarItem(placement: .navigation) { Button("Back") {} } }
                }
                """),
            Self.sheet("Packet", toolbar: "ToolbarItem(placement: .primaryAction) { Button(\"Share\") {} }"),
            SourceFile(path: "Referenced.swift", source: """
                struct Referenced: View {
                    @State private var item: Item?
                    var body: some View { Text("x").sheet(item: $item, content: makeSheet) }
                }
                """),
            SourceFile(path: "Other.swift", source: """
                struct Other: View {
                    @State private var shown = false
                    var body: some View {
                        Text("x").sheet(isPresented: $shown) { Packet() }
                            .sheet(isPresented: $shown) { Packet() }
                    }
                }
                """),
        ], for: .macOS)
        let content = "the content of the sheet at Host.swift:5"
        func check(_ pending: [PendingMacCheck], _ expected: [String], _ comment: Comment) {
            let found = Self.violations(in: scan, pending: pending)
            #expect(found.count == expected.count, comment)
            for (line, prefix) in zip(found, expected) {
                #expect(line.hasPrefix(prefix), "\(comment): \(line)")
            }
        }
        let untraced = "Referenced.swift:3 — "
        // Packet's presenters: Host.swift's one call and Other.swift's two, a file once per call.
        let presenters = ["Host.swift", "Other.swift", "Other.swift"]
        func entry(_ type: String, _ placements: [String], _ presenters: [String] = presenters) -> PendingMacCheck {
            PendingMacCheck(type: type, placements: placements, presenters: presenters, reason: "fixture")
        }
        check([], [untraced, "Packet, presented by Host.swift:5, Other.swift:4, Other.swift:5", content],
              "an unlisted view, an item in a sheet's content and an untraced presenter are each reported")
        check([entry("Packet", ["primaryAction"])], [untraced, content],
              "a listed view whose placements and presenters match is not reported")
        check([entry("Packet", ["secondaryAction"])],
              [untraced, "Packet: pendingMacChecks lists [\"secondaryAction\"]", content],
              "a listed view whose placements differ is reported, to update the entry")
        check([entry("Packet", ["primaryAction"], ["Other.swift", "Other.swift"])],
              [untraced, "Packet: pendingMacChecks lists presenters [\"Other.swift\", \"Other.swift\"], the scan "
                + "finds [\"Host.swift\", \"Other.swift\", \"Other.swift\"]", content],
              "a listed view that a sheet in a new file presents is reported, to update the entry")
        check([entry("Packet", ["primaryAction"], ["Host.swift", "Other.swift"])],
              [untraced, "Packet: pendingMacChecks lists presenters [\"Host.swift\", \"Other.swift\"]", content],
              "a second presenter in a file the entry already names is reported: a file counts once per call")
        check([entry("Packet", ["primaryAction"], presenters + ["Gone.swift"])],
              [untraced, "Packet: pendingMacChecks lists presenters [\"Host.swift\", \"Other.swift\", "
                + "\"Other.swift\", \"Gone.swift\"]", content],
              "a listed presenter that no longer reaches the view is reported, to update the entry")
        check([entry("Packet", ["primaryAction"]), entry("Gone", ["principal"])],
              [untraced, content, "Gone: listed in pendingMacChecks, but no Mac sheet reaches"],
              "a listed view no sheet reaches is reported, to remove the entry")
        check([entry("Packet", ["primaryAction"]), entry(content, ["navigation"])],
              [untraced, content, "\(content): listed in pendingMacChecks"],
              "an item in a sheet's content cannot be listed away")
    }

    @Test("MacSheetToolbarPlacement: a view listed twice in the pending list is reported, not trapped on")
    func aViewListedTwiceIsReported() {
        let scan = Self.scan([
            Self.host("Packet()"),
            Self.sheet("Packet", toolbar: "ToolbarItem(placement: .primaryAction) { Button(\"Share\") {} }"),
        ], for: .macOS)
        let entry = PendingMacCheck(type: "Packet", placements: ["primaryAction"], presenters: ["Host.swift"],
                                    reason: "fixture")
        #expect(Self.violations(in: scan, pending: [entry]).isEmpty, "fixture guard: one matching entry reports nothing")
        #expect(Self.violations(in: scan, pending: [entry, entry])
                    == ["Packet: listed 2 times in pendingMacChecks — keep one entry"])
    }

    @Test("MacSheetToolbarPlacement: the packet sheet's Mac body draws Options, both Shares, and Done")
    func tripPacketSheetMacBodyHoldsItsControls() throws {
        let mac = try #require(try Self.tree.get().readings["TripPacketSheet"],
                               "TripPacketSheet was not read as macOS compiles it")
        // No toolbar at all on the Mac, not merely no undrawn item: a Mac sheet's toolbar is the
        // chrome #1377 left, and a Done moved to the bottom bar is a button, not a toolbar item.
        #expect(mac.items.isEmpty, "the Mac body still declares toolbar items: \(mac.items.map { "\($0.line) \($0.placementName)" })")
        // The scan above passes on a Mac body with the controls deleted, so this pins that they stayed.
        #expect(mac.members.contains("optionsMenu"), "the Mac body does not reach optionsMenu (the repository scope, Copy inquiry draft, What to Include)")
        #expect(mac.calls["ShareLink"] == 2, "the Mac body makes \(mac.calls["ShareLink"] ?? 0) ShareLink calls, not two (Share and Share as PDF)")
        #expect(mac.defaultActions == [["finish"]],
                "the Mac body's .defaultAction buttons call \(mac.defaultActions); expected one Done calling finish(), which commits a pending topic edit before closing")

        // The iOS chrome keeps the same four items in its NavigationStack's bar; the one change is
        // that Done closes through the same finish() as the Mac's rather than a bare dismiss(). The
        // sheet's own file is enough to read it, since every member it reaches is declared there.
        let path = "TripPacket/TripPacketSheet.swift"
        let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(path), encoding: .utf8)
        let iOS = try #require(Self.scan([SourceFile(path: path, source: source)], for: .iOS,
                                         alsoReading: ["TripPacketSheet"]).readings["TripPacketSheet"],
                               "TripPacketSheet was not read as iOS compiles it")
        #expect(iOS.items.map(\.placementName) == ["confirmationAction", "secondaryAction", "primaryAction", "primaryAction"])
        #expect(iOS.items.first?.reads.contains("finish") == true, "iOS Done reads \(iOS.items.first?.reads.sorted() ?? [])")
        #expect(iOS.calls["ShareLink"] == 2)
    }

    @Test("MacSheetToolbarPlacement: the Every Unit sheet's Mac body draws its Export menu and Done")
    func archivalAllUnitsSheetMacBodyHoldsItsControls() throws {
        // #1461: the owner's Mac check found the sheet drawing its list and Done and no Export menu,
        // which sat at `.primaryAction` in the one NavigationStack both platforms shared. So the
        // uncapped list — the reason the sheet exists (#825c) — could not leave the app on the Mac.
        let mac = try #require(try Self.tree.get().readings["ArchivalAllUnitsSheet"],
                               "ArchivalAllUnitsSheet was not read as macOS compiles it")
        #expect(mac.items.isEmpty, "the Mac body still declares toolbar items: \(mac.items.map { "\($0.line) \($0.placementName)" })")
        // The tree test passes on a Mac body with the menu deleted, so this pins that it stayed, and
        // that it still writes the uncapped table the screen draws.
        #expect(mac.calls["AnalyticsSectionExportControl"] == 1,
                "the Mac body makes \(mac.calls["AnalyticsSectionExportControl"] ?? 0) AnalyticsSectionExportControl calls, not one")
        #expect(mac.members.isSuperset(of: ["table", "provenance", "ranking"]),
                "the Mac body does not reach the uncapped table and its provenance: it reaches \(mac.members.sorted())")
        // One Done, as the sheet's default button. Its action is `dismiss()`, an environment value
        // rather than a member with a body, so the reading records no member for it.
        #expect(mac.defaultActions.count == 1,
                "the Mac body has \(mac.defaultActions.count) .defaultAction buttons, not one Done")

        // iOS keeps the NavigationStack's bar, which draws both items, and the same export.
        let path = "Analytics/ArchivalAllUnitsSheet.swift"
        let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(path), encoding: .utf8)
        let iOS = try #require(Self.scan([SourceFile(path: path, source: source)], for: .iOS,
                                         alsoReading: ["ArchivalAllUnitsSheet"]).readings["ArchivalAllUnitsSheet"],
                               "ArchivalAllUnitsSheet was not read as iOS compiles it")
        #expect(iOS.items.map(\.placementName) == ["primaryAction", "confirmationAction"])
        #expect(iOS.calls["AnalyticsSectionExportControl"] == 1)
        #expect(iOS.members.isSuperset(of: ["table", "provenance", "ranking"]))
    }

    /// `TripPacketSheet.finish()`, statement for statement, with its whitespace collapsed.
    ///
    /// Every token is load-bearing. The debounce is cancelled first, so it cannot re-apply the edit
    /// after the sheet has gone; the edit is applied only when ``TripPacketTopicSentence/isUncommitted(draft:edited:)``
    /// says the model has not taken it, reading the field and the model's committed edit in that
    /// order; and `dismiss()` comes last. A `finish()` that dropped the commit, inverted the test,
    /// swapped its arguments or closed first would still be called by both Done buttons, which is
    /// all ``tripPacketSheetMacBodyHoldsItsControls()`` checks.
    static let tripPacketFinishStatements = "topicRenderTask?.cancel() "
        + "if let model, TripPacketTopicSentence.isUncommitted(draft: topicDraft, edited: model.topicSentence.edited) "
        + "{ applyTopicEdit() } "
        + "dismiss()"

    @Test("MacSheetToolbarPlacement: the packet sheet's Done commits a pending topic edit before it closes")
    func tripPacketSheetFinishCommitsBeforeClosing() throws {
        // The view's private function cannot be driven from a test, so it is read, the way #1366's
        // round 2 pins `rebuild()`'s call to `openPlanDraft`: as each platform compiles the file,
        // comments and string literals blanked.
        let path = "TripPacket/TripPacketSheet.swift"
        let source = try String(contentsOf: Self.sourceRoot.appendingPathComponent(path), encoding: .utf8)
        for platform in [Platform.macOS, .iOS] {
            let code = MaskedSwift(source).compiled(for: platform).code
            let sheet = code.typeDeclarations(file: 0).filter { $0.name == "TripPacketSheet" && !$0.isExtension }
            try #require(sheet.count == 1, "\(platform): found \(sheet.count) TripPacketSheet declarations")
            let finish = code.members(in: sheet[0].body).filter { $0.name == "finish" }
            try #require(finish.count == 1, "\(platform): found \(finish.count) finish members")
            let body = finish[0].body
            let statements = code.text((body.lowerBound + 1)..<(body.upperBound - 1))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            #expect(statements == Self.tripPacketFinishStatements, "\(platform): finish() reads «\(statements)»")
        }
    }

    // MARK: - Scanner fixtures (one per rule the scan applies)

    /// A source file handed to the scanner.
    struct SourceFile: Sendable {
        /// The path the scan reports.
        let path: String
        /// The Swift source.
        let source: String
    }

    /// One shape of presenter and presented view, with what the Mac reading must find.
    struct SheetFixture: Sendable, CustomTestStringConvertible {
        /// What the shape is.
        let label: String
        /// The files, scanned together.
        let files: [SourceFile]
        /// The Mac presenters' directly presented types, in source order.
        let presented: [String]
        /// Each finding as `Chain>Owner.placement`, or `content.placement` for an item in the content.
        let findings: [String]
        var testDescription: String { label }
    }

    /// A presenter whose content is `content`, in a view named `Host`.
    private static func host(_ content: String) -> SourceFile {
        SourceFile(path: "Host.swift", source: """
            struct Host: View {
                @State private var shown = false
                var body: some View {
                    Text("Host")
                        .sheet(isPresented: $shown) {
                            \(content)
                        }
                }
            }
            """)
    }

    /// A view named `name` whose body holds `toolbar` inside a `NavigationStack`.
    private static func sheet(_ name: String, toolbar: String) -> SourceFile {
        SourceFile(path: "\(name).swift", source: """
            struct \(name): View {
                var body: some View {
                    NavigationStack {
                        Text("x")
                            .toolbar {
                                \(toolbar)
                            }
                    }
                }
            }
            """)
    }

    static let sheetFixtures: [SheetFixture] = [
        SheetFixture(label: "a .primaryAction and a .secondaryAction item are undrawn", files: [
            host("Packet()"),
            sheet("Packet", toolbar: """
                ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
                ToolbarItem(placement: .primaryAction) { ShareLink(item: "x") }
                ToolbarItemGroup(placement: .secondaryAction) { Menu("Options") {} }
                """),
        ], presented: ["Packet"], findings: ["Packet.primaryAction", "Packet.secondaryAction"]),
        SheetFixture(label: "confirmation and cancellation are drawn, spelled either way", files: [
            host("Packet()"),
            sheet("Packet", toolbar: """
                ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") {} }
                ToolbarItem(placement: ToolbarItemPlacement.confirmationAction) { Button("Save") {} }
                """),
        ], presented: ["Packet"], findings: []),
        SheetFixture(label: "an item that passes no placement is .automatic, and undrawn", files: [
            host("Packet()"),
            sheet("Packet", toolbar: """
                ToolbarItemGroup { Button("Back") {} }
                ToolbarItem { Button("Close") {} }
                ToolbarItem(id: "share") { Button("Share") {} }
                """),
        ], presented: ["Packet"], findings: ["Packet.automatic", "Packet.automatic", "Packet.automatic"]),
        SheetFixture(label: "the placement is the item's own argument, not a nearby placement: text", files: [
            host("Packet()"),
            sheet("Packet", toolbar: """
                // ToolbarItem(placement: .primaryAction) in a comment is not an item
                ToolbarItem(placement: .confirmationAction) {
                    TextField("placement: .primaryAction", text: .constant(""))
                        .searchable(text: .constant(""), placement: .toolbar)
                }
                ToolbarItem(id: "copy",
                            placement:
                                .primaryAction) { Button("Copy") {} }
                """),
        ], presented: ["Packet"], findings: ["Packet.primaryAction"]),
        SheetFixture(label: "the iOS branch of a split body is not read on the Mac", files: [
            host("Packet()"),
            SourceFile(path: "Packet.swift", source: """
                struct Packet: View {
                    var body: some View {
                        #if os(iOS)
                        NavigationStack {
                            Text("x").toolbar { ToolbarItem(placement: .primaryAction) { Button("Share") {} } }
                        }
                        #else
                        VStack { Text("x"); Button("Done") {}.keyboardShortcut(.defaultAction) }
                        #endif
                    }
                }
                """),
        ], presented: ["Packet"], findings: []),
        SheetFixture(label: "the #else of #if os(iOS) is read on the Mac", files: [
            host("Packet()"),
            SourceFile(path: "Packet.swift", source: """
                struct Packet: View {
                    var body: some View {
                        NavigationStack {
                            Text("x").toolbar {
                                #if os(iOS)
                                ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
                                #else
                                ToolbarItem(placement: .primaryAction) { Button("Done") {} }
                                #endif
                            }
                        }
                    }
                }
                """),
        ], presented: ["Packet"], findings: ["Packet.primaryAction"]),
        SheetFixture(label: "a presenter only iOS compiles presents nothing on the Mac", files: [
            SourceFile(path: "Host.swift", source: """
                struct Host: View {
                    @State private var shown = false
                    var body: some View {
                        Text("Host")
                            #if os(iOS)
                            .sheet(isPresented: $shown) { Packet() }
                            #endif
                    }
                }
                """),
            sheet("Packet", toolbar: "ToolbarItem(placement: .primaryAction) { Button(\"Share\") {} }"),
        ], presented: [], findings: []),
        SheetFixture(label: "a member the Mac's body never names is not read", files: [
            host("Editor()"),
            SourceFile(path: "Editor.swift", source: """
                struct Editor: View {
                    var body: some View {
                        #if os(macOS)
                        macBody
                        #else
                        iOSBody
                        #endif
                    }
                    #if os(macOS)
                    private var macBody: some View { VStack { Text("x") } }
                    #endif
                    private var iOSBody: some View {
                        NavigationStack { Text("x").toolbar { editorToolbar } }
                    }
                    @ToolbarContentBuilder
                    private var editorToolbar: some ToolbarContent {
                        ToolbarItem(placement: .destructiveAction) { Button("Delete") {} }
                    }
                }
                """),
        ], presented: ["Editor"], findings: []),
        SheetFixture(label: "a member the body reaches is read, through self. and a function", files: [
            host("Editor()"),
            SourceFile(path: "Editor.swift", source: """
                struct Editor: View {
                    var body: some View {
                        NavigationStack { Text("x").toolbar { self.editorToolbar(extra: true) } }
                    }
                    @ToolbarContentBuilder
                    private func editorToolbar(extra: Bool) -> some ToolbarContent {
                        ToolbarItem(placement: .confirmationAction) { Button("Save") {} }
                        ToolbarItem(placement: .destructiveAction) { Button("Delete") {} }
                    }
                }
                """),
        ], presented: ["Editor"], findings: ["Editor.destructiveAction"]),
        SheetFixture(label: "content that names a member of the presenting view is followed", files: [
            SourceFile(path: "Host.swift", source: """
                struct Host: View {
                    @State private var item: Item?
                    var body: some View {
                        Text("Host")
                            .sheet(item: $item) { item in
                                packetSheet(for: item)
                            }
                    }
                    private func packetSheet(for item: Item) -> some View {
                        Packet(item: item)
                    }
                }
                """),
            sheet("Packet", toolbar: "ToolbarItem(placement: .primaryAction) { Button(\"Share\") {} }"),
        ], presented: ["Packet"], findings: ["Packet.primaryAction"]),
        SheetFixture(label: "a labelled content: closure is the content", files: [
            SourceFile(path: "Host.swift", source: """
                struct Host: View {
                    @State private var item: Item?
                    var body: some View {
                        Text("Host").sheet(item: $item, onDismiss: { item = nil }, content: { Packet(item: $0) })
                    }
                }
                """),
            sheet("Packet", toolbar: "ToolbarItem(placement: .principal) { Text(\"Title\") }"),
        ], presented: ["Packet"], findings: ["Packet.principal"]),
        SheetFixture(label: "an item written in the sheet's content itself is read", files: [
            host("""
                NavigationStack {
                    Text("x").toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
                        ToolbarItem(placement: .primaryAction) { Button("Share") {} }
                    }
                }
                """),
        ], presented: [], findings: ["content.primaryAction"]),
        SheetFixture(label: "a view the presented view composes is read, to any depth", files: [
            host("Packet()"),
            SourceFile(path: "Packet.swift", source: """
                struct Packet: View {
                    var body: some View { NavigationStack { Middle(depth: 1) } }
                }
                struct Middle: View {
                    let depth: Int
                    var body: some View { Inner { Text("x") } }
                }
                struct Inner<Content: View>: View {
                    @ViewBuilder let content: Content
                    var body: some View {
                        content.toolbar { ToolbarItem(placement: .primaryAction) { Button("Copy") {} } }
                    }
                }
                """),
        ], presented: ["Packet"], findings: ["Packet>Middle>Inner.primaryAction"]),
        SheetFixture(label: "a view no sheet presents is not read", files: [
            host("Text(\"nothing\")"),
            sheet("Window", toolbar: "ToolbarItem(placement: .primaryAction) { Button(\"Share\") {} }"),
        ], presented: [], findings: []),
        SheetFixture(label: "a same-named private view is taken from the presenter's own file", files: [
            SourceFile(path: "Clean.swift", source: """
                struct Clean: View {
                    @State private var shown = false
                    var body: some View { Text("x").sheet(isPresented: $shown) { Row() } }
                }
                private struct Row: View {
                    var body: some View { NavigationStack { Text("clean").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") {} } } } }
                }
                """),
            SourceFile(path: "Dirty.swift", source: """
                struct Dirty: View {
                    @State private var shown = false
                    var body: some View { Text("x").sheet(isPresented: $shown) { Row() } }
                }
                private struct Row: View {
                    var body: some View { NavigationStack { Text("dirty").toolbar { ToolbarItem(placement: .primaryAction) { Button("Share") {} } } } }
                }
                """),
        ], presented: ["Row", "Row"], findings: ["Row (Dirty.swift).primaryAction"]),
        SheetFixture(label: "an #if the scanner cannot decide keeps both branches, since either build can ship", files: [
            host("Packet()"),
            sheet("Packet", toolbar: """
                #if DEBUG
                ToolbarItem(placement: .primaryAction) { Button("Debug") {} }
                #else
                ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
                #endif
                """),
        ], presented: ["Packet"], findings: ["Packet.primaryAction"]),
    ]

    @Test("MacSheetToolbarPlacement: the scanner reads each shape as the Mac compiles it", arguments: sheetFixtures)
    func scannerReadsEachShape(_ fixture: SheetFixture) {
        let scan = Self.scan(fixture.files, for: .macOS)
        #expect(scan.presenters.allSatisfy { $0.untraced == nil }, "\(scan.presenters.compactMap(\.untraced))")
        #expect(scan.presenters.flatMap(\.presentedTypes) == fixture.presented)
        #expect(scan.findings.map(\.description) == fixture.findings)
    }

    @Test("MacSheetToolbarPlacement: a presenter whose content is not a closure is reported, not skipped")
    func aContentReferenceIsReported() {
        let scan = Self.scan([SourceFile(path: "Host.swift", source: """
            struct Host: View {
                @State private var item: Item?
                var body: some View { Text("x").sheet(item: $item, content: makeSheet) }
                private func makeSheet(_ item: Item) -> some View { Text("x") }
            }
            """)], for: .macOS)
        #expect(scan.presenters.map(\.line) == [3])
        #expect(scan.presenters.compactMap(\.untraced).count == 1)
    }

    @Test("MacSheetToolbarPlacement: the chrome checks read a body's controls and its default button's action")
    func chromeReadingCountsControls() throws {
        let files = [Self.host("Packet()"), SourceFile(path: "Packet.swift", source: """
            struct Packet: View {
                var body: some View {
                    VStack {
                        HStack { Text("Title"); optionsMenu }
                        HStack {
                            share
                            Button("Cancel") { cancel() }.keyboardShortcut(.cancelAction)
                            Button("Done") { self.finish() }
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                }
                private var optionsMenu: some View { Menu("Options") {} }
                private var share: some View { ShareLink(item: "x") }
                private var unreached: some View { ShareLink(item: "y") }
                private func finish() {}
                private func cancel() {}
            }
            """)]
        let reading = try #require(Self.scan(files, for: .macOS).readings["Packet"])
        #expect(reading.items.isEmpty)
        #expect(reading.members.isSuperset(of: ["body", "optionsMenu", "share", "finish", "cancel"]))
        #expect(!reading.members.contains("unreached"))
        #expect(reading.calls["ShareLink"] == 1, "the ShareLink in a member body never reaches is not counted")
        #expect(reading.defaultActions == [["finish"]])

        // `alsoReading` reads a view no sheet presents — the route the packet sheet's iOS check
        // takes — and reads it the same way; without it, an unpresented view is not read at all.
        let unpresented = [files[1]]
        #expect(Self.scan(unpresented, for: .macOS).readings.isEmpty)
        let alone = try #require(Self.scan(unpresented, for: .macOS, alsoReading: ["Packet"]).readings["Packet"])
        #expect(alone.members == reading.members)
        #expect(alone.calls == reading.calls)
        #expect(alone.defaultActions == reading.defaultActions)
    }

    // MARK: - Model

    /// The placements a macOS sheet draws: as buttons, not in a toolbar.
    static let drawnPlacements: Set<String> = ["confirmationAction", "cancellationAction"]

    /// One `ToolbarItem(` / `ToolbarItemGroup(` call, as one platform compiles it.
    struct ToolbarItemSite: Sendable, Equatable {
        /// The file's path relative to the scanned root.
        let path: String
        /// 1-based line of the call.
        let line: Int
        /// `ToolbarItem` or `ToolbarItemGroup`.
        let call: String
        /// The `placement:` argument as written, or `nil` when the call passes none.
        let placement: String?
        /// The lower-case names the item's content closure reads — members, locals and keywords
        /// alike — so a test can ask what a control calls.
        var reads: Set<String> = []

        /// The placement's member name — `primaryAction` for `.primaryAction` and for
        /// `ToolbarItemPlacement.primaryAction` — or `automatic` when the call passes none.
        var placementName: String {
            guard let placement else { return "automatic" }
            let member = placement.hasPrefix("ToolbarItemPlacement")
                ? String(placement.dropFirst("ToolbarItemPlacement".count)) : placement
            return member.hasPrefix(".") ? String(member.dropFirst()) : member
        }

        /// Whether a macOS sheet draws the item.
        var isDrawnInAMacSheet: Bool { MacSheetToolbarPlacementAuditTests.drawnPlacements.contains(placementName) }
    }

    /// One `.sheet(` call, as one platform compiles it.
    struct Presenter: Sendable {
        /// The file's path relative to the scanned root.
        let path: String
        /// 1-based line of the `.sheet(`.
        let line: Int
        /// The view types the content constructs directly, in source order.
        let presentedTypes: [String]
        /// Why the content was not read, when it was not.
        let untraced: String?
    }

    /// What the scan read of one view type, from its `body`.
    struct TypeReading: Sendable {
        /// Every toolbar item the reachable code declares, in the order it was read.
        let items: [ToolbarItemSite]
        /// The members read, by name: `body` and every member it reaches.
        let members: Set<String>
        /// The view types the reachable code constructs, in the order they were read.
        let composes: [String]
        /// How many calls the reachable code makes to each capitalized callee (`ShareLink`, `Button`).
        let calls: [String: Int]
        /// For each `Button` whose modifier chain carries `.keyboardShortcut(.defaultAction)`, the
        /// member names its action reads.
        let defaultActions: [Set<String>]
    }

    /// One toolbar item a Mac sheet does not draw.
    struct Finding: Sendable, CustomStringConvertible {
        /// The presenter, `path:line`.
        let presenter: String
        /// The presented view, then each view it composes down to the one declaring the item; empty
        /// when the item is written in the presenter's content.
        let chain: [String]
        /// The item.
        let item: ToolbarItemSite

        /// `Chain>Owner.placement`, or `content.placement`.
        var description: String {
            (chain.isEmpty ? "content" : chain.joined(separator: ">")) + "." + item.placementName
        }
    }

    /// What one reading of a set of files found.
    struct Scan: Sendable {
        /// How many files were read.
        let filesRead: Int
        /// Every `.sheet(` call the platform compiles, in file order.
        let presenters: [Presenter]
        /// Every view type read, presented or composed, by name.
        let readings: [String: TypeReading]
        /// Every undrawn toolbar item, once per presenter that reaches it.
        let findings: [Finding]
        /// Every view type a sheet holds, presented or composed at any depth, by the name it is
        /// reported by, with each presenter (`path:line`) that reaches it, in file order (#1462).
        let reachedBy: [String: [String]]

        /// The view types the presenters construct directly.
        var presentedTypes: Set<String> { Set(presenters.flatMap(\.presentedTypes)) }
    }

    // MARK: - Scanner

    /// Every Swift file under the app source root, read as `platform` compiles it.
    static func scanTree(for platform: Platform) throws -> Scan {
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { SourceFile(path: $0, source: try String(contentsOf: sourceRoot.appendingPathComponent($0), encoding: .utf8)) }
        return scan(files, for: platform)
    }

    /// Reads `files` together, as `platform` compiles them. Each type named in `alsoReading` is read
    /// from its `body` too, whether or not a sheet presents it, so a test can read one file's view
    /// as a platform compiles it without scanning the tree for that platform.
    static func scan(_ files: [SourceFile], for platform: Platform, alsoReading: [String] = []) -> Scan {
        let code = files.map { MaskedSwift($0.source).compiled(for: platform).code }
        let lines = code.map { LineIndex($0.bytes) }
        let declarationsByFile = code.enumerated().map { $0.element.typeDeclarations(file: $0.offset) }
        let declarations = Dictionary(grouping: declarationsByFile.joined(), by: \.name)
        let viewTypes = Set(declarations.filter { $0.value.contains(where: \.conformsToView) }.keys)

        /// The declarations `name` resolves to from `file`, and the name the scan reports it by. A
        /// name declared as a type more than once (two files' `private struct Row`) is taken from
        /// `file` when `file` declares it, and reported with that file's path.
        func resolve(_ name: String, from file: Int) -> (display: String, owner: [SheetDeclaration]) {
            let all = declarations[name] ?? []
            guard all.filter({ !$0.isExtension }).count > 1,
                  all.contains(where: { $0.file == file && !$0.isExtension }) else { return (name, all) }
            return ("\(name) (\(files[file].path))", all.filter { $0.file == file })
        }

        /// Each declaration's members, read once: the big views present many sheets, and each
        /// presenter's content is read through its own view's members.
        var memberCache: [SheetDeclaration.Span: [(name: String, body: Range<Int>)]] = [:]
        func members(of declaration: SheetDeclaration) -> [(name: String, body: Range<Int>)] {
            let key = SheetDeclaration.Span(file: declaration.file, range: declaration.body)
            if let cached = memberCache[key] { return cached }
            let found = code[declaration.file].members(in: declaration.body)
            memberCache[key] = found
            return found
        }

        /// The ranges read from `roots`, following the members of `owner` they name; with the
        /// names of the members read.
        func reach(from roots: [SheetDeclaration.Span], through owner: [SheetDeclaration])
            -> (spans: [SheetDeclaration.Span], members: Set<String>) {
            var membersByName: [String: [SheetDeclaration.Span]] = [:]
            for declaration in owner {
                for member in members(of: declaration) {
                    membersByName[member.name, default: []].append(.init(file: declaration.file, range: member.body))
                }
            }
            var read: [SheetDeclaration.Span] = []
            var names = Set<String>()
            var queue = roots
            var seen = Set<SheetDeclaration.Span>()
            while !queue.isEmpty {
                let span = queue.removeFirst()
                guard seen.insert(span).inserted else { continue }
                read.append(span)
                for name in code[span.file].memberReferences(in: span.range) {
                    guard let bodies = membersByName[name] else { continue }
                    names.insert(name)
                    queue += bodies
                }
            }
            return (read, names)
        }

        /// The toolbar items in `span`.
        func items(in span: SheetDeclaration.Span) -> [ToolbarItemSite] {
            code[span.file].toolbarItems(in: span.range, path: files[span.file].path, lines: lines[span.file])
        }

        /// Every reading so far, by the name it is reported by.
        var readings: [String: TypeReading] = [:]
        /// Each reading's composed views, with the file each is constructed in.
        var composedFrom: [String: [(name: String, file: Int)]] = [:]

        /// Reads `type`, as resolved from `file`, from its `body` — once per resolution — and
        /// returns the name it is reported by, the reading, and the views it composes, each with the
        /// file that constructs it, so a chain resolves every link where that link is written.
        func reading(of type: String, from file: Int)
            -> (display: String, reading: TypeReading, composes: [(name: String, file: Int)]) {
            let (display, owner) = resolve(type, from: file)
            if let cached = readings[display] { return (display, cached, composedFrom[display] ?? []) }
            let bodies = owner.flatMap { declaration in
                members(of: declaration)
                    .filter { $0.name == "body" }
                    .map { SheetDeclaration.Span(file: declaration.file, range: $0.body) }
            }
            let memberNames = Set(owner.flatMap { members(of: $0).map(\.name) })
            let (spans, reached) = reach(from: bodies, through: owner)
            var composes: [(name: String, file: Int)] = []
            var calls: [String: Int] = [:]
            var defaultActions: [Set<String>] = []
            var found: [ToolbarItemSite] = []
            for span in spans {
                let masked = code[span.file]
                for name in masked.constructedTypes(in: span.range, among: viewTypes)
                where !composes.contains(where: { $0.name == name }) {
                    composes.append((name, span.file))
                }
                masked.capitalizedCalls(in: span.range).forEach { calls[$0, default: 0] += 1 }
                defaultActions += masked.defaultActionButtons(in: span.range).map { $0.intersection(memberNames) }
                found += items(in: span)
            }
            let result = TypeReading(items: found, members: reached.union(bodies.isEmpty ? [] : ["body"]),
                                     composes: composes.map(\.name), calls: calls, defaultActions: defaultActions)
            readings[display] = result
            composedFrom[display] = composes
            return (display, result, composes)
        }

        var presenters: [Presenter] = []
        var findings: [Finding] = []
        var reachedBy: [String: [String]] = [:]
        for (file, masked) in code.enumerated() {
            for offset in masked.wordOffsets("sheet") where offset > 0 && masked.bytes[offset - 1] == ASCII.dot {
                guard let call = masked.call(named: "sheet", at: offset), let arguments = call.arguments else { continue }
                let line = lines[file].line(at: offset)
                let site = "\(files[file].path):\(line)"
                var content = call.trailingClosure
                if content == nil, let value = masked.topLevelArgument("content", in: arguments) {
                    let open = masked.skipBlanks(from: value.lowerBound)
                    if open < masked.bytes.count, masked.bytes[open] == ASCII.openBrace, let close = masked.closing(open) {
                        content = open..<close
                    }
                }
                guard let content else {
                    presenters.append(Presenter(path: files[file].path, line: line, presentedTypes: [],
                                                untraced: "the sheet's content is not a closure, so what it presents was not read"))
                    continue
                }
                let enclosing = declarationsByFile[file]
                    .filter { $0.body.contains(offset) }
                    .min { $0.body.count < $1.body.count }
                let owner = enclosing.map { resolve($0.name, from: file).owner } ?? []
                let (spans, _) = reach(from: [.init(file: file, range: content)], through: owner)
                var presented: [(name: String, file: Int)] = []
                for span in spans {
                    items(in: span)
                        .filter { !$0.isDrawnInAMacSheet }
                        .forEach { findings.append(Finding(presenter: site, chain: [], item: $0)) }
                    for name in code[span.file].constructedTypes(in: span.range, among: viewTypes)
                    where !presented.contains(where: { $0.name == name }) {
                        presented.append((name, span.file))
                    }
                }
                presenters.append(Presenter(path: files[file].path, line: line,
                                            presentedTypes: presented.map(\.name), untraced: nil))
                // Each view the sheet holds, presented or composed, read once per presenter, along the
                // first chain that reaches it; each link resolved from the file that constructs it.
                var queue = presented.map { (chain: [String](), next: $0) }
                var visited = Set<String>()
                while !queue.isEmpty {
                    let (chain, next) = queue.removeFirst()
                    let (display, read, composes) = reading(of: next.name, from: next.file)
                    guard visited.insert(display).inserted else { continue }
                    reachedBy[display, default: []].append(site)
                    let path = chain + [display]
                    read.items.filter { !$0.isDrawnInAMacSheet }
                        .forEach { findings.append(Finding(presenter: site, chain: path, item: $0)) }
                    queue += composes.map { (chain: path, next: $0) }
                }
            }
        }
        for type in alsoReading {
            if let file = declarations[type]?.first?.file { _ = reading(of: type, from: file) }
        }
        return Scan(filesRead: files.count, presenters: presenters, readings: readings, findings: findings,
                    reachedBy: reachedBy)
    }
}

// MARK: - ArchiveVisitMacToolbarFitTests

/// Source gate for #1378: **in the Mac Archives Visits window, Export packet can be reached at any
/// width, each icon-only toolbar control names itself, and a long plan name cannot widen the toolbar.**
///
/// ## The defect it stops
/// The window opened at 900 × 640 and its toolbar did not fit: Filter, Export packet and About
/// research targets went behind the overflow chevron (**>>**). Export packet is the only way to open
/// the packet on a Mac. The plan picker's label is the plan's name with no line limit, so a long
/// name made the toolbar wider still. And the Mac manual sent readers to an Export packet item in
/// the ⋯ menu that the Mac did not have.
///
/// ## The fix it pins
/// - The ⋯ menu carries Export packet on the Mac only. The window's minimum width (640 pt) is below
///   the width the toolbar needs, and a saved window frame does not take a new default size, so
///   the toolbar can still overflow. With the item in the ⋯ menu, Export packet is still in
///   reach when that happens. iOS gets no such item: the iPhone's consolidated menu lists Export
///   packet first and then the ⋯ items, so the item would show twice there.
/// - Every Export packet control runs the toolbar button's own action and is disabled by the
///   same rule, so the menu item cannot come to do something else.
/// - The toolbar button, icon-only on the Mac, carries a `.help` tooltip, as the Collections
///   window's Export… does.
/// - So do its icon-only neighbours on the Mac — Filter, About research targets and the ⋯ menu —
///   each under a key of its own. The ⋯ menu's is compiled for the Mac alone, because it names
///   Export packet and Rename, which only the Mac's ⋯ menu holds.
/// - The plan picker's name keeps to one line, cut at the tail, within a fixed width.
/// - The window opens at least as wide as ``measuredToolbarFitWidth``.
///
/// ## How it reads
/// Each file is read as one platform compiles it, through `MaskedSwift`'s `#if` evaluation, with
/// comments and string literals blanked. A localization key is read from the unmasked source at the
/// same byte range. Every match is a whole call with its balanced parentheses and braces, never a
/// window of lines. Two fixture tests pin the reading's own rules, one fixture per rule: an action
/// in a trailing closure or an `action:` argument, the packet flag set directly or through a member,
/// the label key matched whole, a `#if os(iOS)` control, a width written as a number or as a
/// constant, and a tooltip read from the control whose `label:` closure carries the key, past other
/// modifiers and through a platform `#if`.
///
/// ## Where it can fail
/// These are source scans, so they give the same result on every test destination, iPhone and iPad
/// alike, and none of them can see a Mac toolbar overflow (neither test target runs on macOS). They
/// fail when the source loses the fix. Whether the toolbar fits at the window's default size is
/// checked by eye on a Mac, at the width recorded in ``measuredToolbarFitWidth``
/// (`Planning/Open-Issues-Resolution-Plan-2026-09-23.md`, §4 item 14).
///
/// Version history:
///   1.0 — #1378: initial implementation
///   1.1 — #1378 review, round 1: Filter, About research targets and the ⋯ menu carry tooltips of
///         their own, and the plan the by-eye check lives in is named by its file
struct ArchiveVisitMacToolbarFitTests {

    /// The platforms the files are read for.
    typealias Platform = SegmentedPickerAccessibilityAuditTests.Platform

    /// The app's source root.
    private static let sourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// The plan editor, whose toolbar and ⋯ menu the window shows.
    static let editorPath = "TripPacket/ArchiveVisitEditorView.swift"
    /// The Mac window's root, which adds the plan picker at `.navigation`.
    static let managerPath = "TripPacket/MacArchiveVisitManagerView.swift"
    /// The scene declarations, where the window's default size is set.
    static let appPath = "App/FRUSExplorerApp.swift"

    /// The Export packet label's localization key, quotes included so `….export.help` is not it.
    static let exportKey = "\"archiveVisit.editor.export\""
    /// The toolbar button's tooltip key.
    static let exportHelpKey = "\"archiveVisit.editor.export.help\""

    /// The narrowest window, in points, that shows every item of the Archives Visits toolbar with no
    /// overflow chevron, with a plan whose name the picker cuts to its maximum width.
    ///
    /// Measured on macOS 27 (#1378) with a 77-character plan name, which the picker cuts at its cap,
    /// and a five-digit document count, widening the window 2 pt at a time from 640 pt and
    /// reading `NSToolbar.visibleItems`. Narrowing gives 1,004 pt, 10 pt less; this is the larger
    /// figure. The Session 2026-09-25 entry in `Planning/DEVELOPMENT-PLAN.md` has every run. The
    /// window's `defaultSize` must be at least this wide.
    static let measuredToolbarFitWidth = 1014

    /// The cap on the picker's plan name that ``measuredToolbarFitWidth`` was measured with, in points.
    /// A wider cap widens the toolbar, so changing it means measuring again.
    static let measuredPlanNameMaxWidth = 260

    // MARK: - Reading

    /// One Export packet control: a `Button` whose own call (arguments and closures, not its
    /// modifiers) carries ``exportKey``.
    struct ExportControl {
        /// The member of `ArchiveVisitEditorView` whose body holds it.
        let member: String
        /// 1-based line of the `Button`.
        let line: Int
        /// The action — the trailing closure or the `action:` argument — braces and whitespace
        /// folded away.
        let action: String
        /// The byte range of the action, in the file's masked code.
        let actionRange: Range<Int>?
        /// The argument list of each `.disabled(…)` on the button, whitespace collapsed.
        let disabled: [String]
        /// The unmasked argument list of the button's `.help(…)`, when it has one.
        let help: String?
    }

    /// `ArchiveVisitEditorView` as `platform` compiles it. File-private because it holds the
    /// file-private `MaskedSwift`.
    fileprivate struct EditorReading {
        /// The file's masked code as the platform compiles it.
        let code: MaskedSwift
        /// The editor's members with a body, by name.
        let members: [String: Range<Int>]
        /// Every Export packet control, in source order.
        let controls: [ExportControl]
        /// The file's unmasked UTF-8 bytes, for the keys the masked code blanks.
        let raw: [UInt8]

        /// For each `call` in `member`'s body whose `label:` closure carries `labelKey`, the unmasked
        /// argument list of every `.help(…)` in its modifier chain. The key is looked for in the
        /// `label:` closure alone, so a menu is never taken for one of its own items.
        func helps(ofCall call: String, labelled labelKey: String, in member: String) -> [[String]] {
            guard let body = members[member] else { return [] }
            return code.wordOffsets(call, in: body)
                .compactMap { code.call(named: call, at: $0) }
                .filter { found in
                    found.labelledClosures.contains { $0.label == "label" && unmasked($0.range).contains(labelKey) }
                }
                .map { found in
                    code.modifierChain(after: found.end)
                        .filter { $0.name == "help" }
                        .map { $0.arguments.map(unmasked) ?? "" }
                }
        }

        /// The unmasked source in `range`.
        func unmasked(_ range: Range<Int>) -> String {
            String(decoding: raw[range], as: UTF8.self)
        }

        /// How many `Button` calls the body of `member` holds.
        func buttonCount(in member: String) -> Int {
            guard let body = members[member] else { return 0 }
            return code.wordOffsets("Button", in: body).filter { code.call(named: "Button", at: $0) != nil }.count
        }

        /// Whether `control`'s action sets `showShare = true`, the flag the packet sheet is presented
        /// on — itself, or in the body of an editor member it calls.
        func opensThePacketSheet(_ control: ExportControl) -> Bool {
            guard let range = control.actionRange else { return false }
            let reached = [range] + code.memberReferences(in: range).compactMap { members[$0] }
            return reached.contains { ArchiveVisitMacToolbarFitTests.collapse(code.text($0)).contains("showShare = true") }
        }
    }

    /// `text` with every run of whitespace collapsed to one space, trimmed.
    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The file at `path` under the source root.
    static func source(_ path: String) throws -> String {
        try String(contentsOf: sourceRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Reads the editor as `platform` compiles it.
    fileprivate static func readEditor(for platform: Platform) throws -> EditorReading {
        try readEditor(source: try source(editorPath), for: platform)
    }

    /// Reads `raw`, the source of a file declaring `ArchiveVisitEditorView`, as `platform` compiles it.
    fileprivate static func readEditor(source raw: String, for platform: Platform) throws -> EditorReading {
        let rawBytes = Array(raw.utf8)
        let code = MaskedSwift(raw).compiled(for: platform).code
        let editor = code.typeDeclarations(file: 0).filter { $0.name == "ArchiveVisitEditorView" && !$0.isExtension }
        try #require(editor.count == 1, "\(platform): found \(editor.count) ArchiveVisitEditorView declarations in \(editorPath)")
        let members = code.members(in: editor[0].body)
        var controls: [ExportControl] = []
        for offset in code.wordOffsets("Button", in: editor[0].body) {
            guard let button = code.call(named: "Button", at: offset),
                  String(decoding: rawBytes[offset..<button.end], as: UTF8.self).contains(exportKey) else { continue }
            let owner = members.filter { $0.body.contains(offset) }.min { $0.body.count < $1.body.count }
            let actionRange = button.arguments.flatMap { code.topLevelArgument("action", in: $0) } ?? button.trailingClosure
            var action = actionRange.map { collapse(code.text($0)) } ?? ""
            if action.hasPrefix("{"), action.hasSuffix("}") { action = collapse(String(action.dropFirst().dropLast())) }
            let chain = code.modifierChain(after: button.end)
            controls.append(ExportControl(
                member: owner?.name ?? "<no member>",
                line: code.line(at: offset),
                action: action,
                actionRange: actionRange,
                disabled: chain.filter { $0.name == "disabled" }.map { $0.arguments.map { collapse(code.text($0)) } ?? "" },
                help: chain.first { $0.name == "help" }?.arguments
                    .map { String(decoding: rawBytes[$0], as: UTF8.self) }))
        }
        return EditorReading(code: code,
                             members: Dictionary(members.map { ($0.name, $0.body) }, uniquingKeysWith: { first, _ in first }),
                             controls: controls,
                             raw: rawBytes)
    }

    // MARK: - Tests

    @Test("#1378: on the Mac the ⋯ menu carries Export packet, and on iOS it does not")
    func theMoreMenuCarriesExportOnTheMacOnly() throws {
        let mac = try Self.readEditor(for: .macOS)
        let iOS = try Self.readEditor(for: .iOS)
        // Anti-vacuity: the ⋯ menu's body was found and read on both platforms. It holds Priority
        // Tiers…, Duplicate, Re-seed from Project and Delete everywhere, and Rename on the Mac.
        for (platform, reading) in [(Platform.macOS, mac), (.iOS, iOS)] {
            #expect(reading.buttonCount(in: "moreMenuItems") >= 4,
                    "\(platform): read \(reading.buttonCount(in: "moreMenuItems")) Buttons in moreMenuItems, expected its four shared items at least")
        }
        let macMenu = mac.controls.filter { $0.member == "moreMenuItems" }
        #expect(macMenu.count == 1, """
            The Mac's ⋯ menu (moreMenuItems) holds \(macMenu.count) Export packet items; it must hold one. \
            The window can be narrower than its toolbar (its minimum width is 640 pt), and a saved frame \
            does not take a new default size, so the toolbar button can go behind the overflow chevron. \
            The ⋯ item keeps the packet in reach, and it is what Docs/macOS-User-Manual.md describes.
            """)
        let iOSMenu = iOS.controls.filter { $0.member == "moreMenuItems" }
        #expect(iOSMenu.isEmpty, """
            iOS compiles an Export packet item into moreMenuItems (line(s) \(iOSMenu.map(\.line))). The \
            iPhone's consolidated menu lists Export packet first and then includes moreMenuItems, so the \
            item shows twice there: put it behind `#if os(macOS)`, as Rename is.
            """)
        // Every Export packet control each platform compiles, by the member that holds it.
        #expect(mac.controls.map(\.member).sorted() == ["exportToolbarItem", "moreMenuItems"],
                "macOS compiles Export packet controls in \(mac.controls.map { "\($0.member):\($0.line)" })")
        #expect(iOS.controls.map(\.member).sorted() == ["editorToolbar", "exportToolbarItem"],
                "iOS compiles Export packet controls in \(iOS.controls.map { "\($0.member):\($0.line)" })")
    }

    @Test("#1378: every Export packet control runs the toolbar button's action and is disabled by its rule")
    func everyExportControlRunsTheButtonsAction() throws {
        for platform in [Platform.macOS, .iOS] {
            let reading = try Self.readEditor(for: platform)
            let buttons = reading.controls.filter { $0.member == "exportToolbarItem" }
            try #require(buttons.count == 1, "\(platform): found \(buttons.count) Export packet buttons in exportToolbarItem")
            let button = buttons[0]
            #expect(reading.opensThePacketSheet(button), """
                \(platform): the toolbar button's action «\(button.action)» does not set showShare = true, \
                itself or in an editor member it calls, so it no longer opens the packet sheet.
                """)
            #expect(button.disabled.count == 1 && button.disabled.first?.isEmpty == false,
                    "\(platform): the toolbar button carries \(button.disabled) as .disabled arguments; expected one rule")
            let others = reading.controls.filter { $0.member != "exportToolbarItem" }
            #expect(others.count == 1, "\(platform): expected one other Export packet control, found \(others.count)")
            for control in others {
                #expect(control.action == button.action, """
                    \(platform): the Export packet item in \(control.member) (line \(control.line)) runs \
                    «\(control.action)», but the toolbar button runs «\(button.action)». Every Export packet \
                    control must run the same action.
                    """)
                #expect(control.disabled == button.disabled, """
                    \(platform): the Export packet item in \(control.member) (line \(control.line)) is disabled \
                    by \(control.disabled), the toolbar button by \(button.disabled). A plan with no documents \
                    has nothing to export, whichever control is used.
                    """)
            }
        }
    }

    @Test("#1378: the Export packet toolbar button carries a tooltip on the Mac")
    func theExportButtonHasHelp() throws {
        let mac = try Self.readEditor(for: .macOS)
        let buttons = mac.controls.filter { $0.member == "exportToolbarItem" }
        try #require(buttons.count == 1, "found \(buttons.count) Export packet buttons in exportToolbarItem")
        let help = try #require(buttons[0].help, """
            The Export packet toolbar button has no .help. On the Mac it is drawn as an icon alone, so the \
            tooltip is where it says what it does, as the Collections window's Export… does.
            """)
        #expect(help.contains(Self.exportHelpKey) && help.contains("defaultValue:"),
                "the tooltip must be localized under \(Self.exportHelpKey) with a defaultValue: — found \(help)")
    }

    /// The Mac toolbar's other icon-only controls: the editor member holding each, its call, the key
    /// its `label:` closure carries, and the key of the tooltip that is its own.
    static let iconOnlyNeighbours: [(member: String, call: String, labelKey: String, helpKey: String)] = [
        ("filterToolbarMenu", "Menu", "\"archiveVisit.filter.menu\"", "\"archiveVisit.filter.menu.help\""),
        ("infoToolbarItem", "Button", "\"archiveVisit.editor.about\"", "\"archiveVisit.editor.about.help\""),
        ("moreToolbarItem", "Menu", "\"archiveVisit.editor.more\"", "\"archiveVisit.editor.more.help\""),
    ]

    @Test("#1378: on the Mac, Filter, About research targets and ⋯ each carry a tooltip of their own")
    func theToolbarsOtherIconsHaveHelp() throws {
        let mac = try Self.readEditor(for: .macOS)
        for control in Self.iconOnlyNeighbours {
            let helps = mac.helps(ofCall: control.call, labelled: control.labelKey, in: control.member)
            try #require(helps.count == 1, """
                macOS: found \(helps.count) \(control.call) calls whose label: carries \(control.labelKey) in \
                \(control.member), expected one — re-derive this test
                """)
            #expect(helps[0].count == 1 && helps[0].allSatisfy { $0.contains(control.helpKey) && $0.contains("defaultValue:") }, """
                macOS: the \(control.call) in \(control.member) carries \(helps[0].count) .help modifiers \(helps[0]). \
                It is drawn as its icon alone in the Mac toolbar, beside Export packet's button, so it needs \
                one tooltip of its own, localized under \(control.helpKey) with a defaultValue:.
                """)
        }
        // iOS compiles the ⋯ menu without its tooltip, which names Export packet and Rename.
        let iOS = try Self.readEditor(for: .iOS)
        let iOSMore = iOS.helps(ofCall: "Menu", labelled: "\"archiveVisit.editor.more\"", in: "moreToolbarItem")
        try #require(iOSMore.count == 1, "iOS: found \(iOSMore.count) ⋯ menus in moreToolbarItem, expected one")
        #expect(iOSMore[0].isEmpty, """
            iOS compiles the ⋯ menu's tooltip \(iOSMore[0]), which names Export packet and Rename; iPad's ⋯ \
            menu holds neither. Keep it behind `#if os(macOS)`.
            """)
    }

    @Test("#1378: the plan picker's name keeps to one line, cut at the tail, within a fixed width")
    func thePlanPickerLabelIsCapped() throws {
        let raw = try Self.source(Self.managerPath)
        let code = MaskedSwift(raw).compiled(for: .macOS).code
        let manager = code.typeDeclarations(file: 0).filter { $0.name == "MacArchiveVisitManagerView" && !$0.isExtension }
        try #require(manager.count == 1, "found \(manager.count) MacArchiveVisitManagerView declarations")
        let picker = try #require(code.members(in: manager[0].body).first { $0.name == "planPickerMenu" },
                                  "MacArchiveVisitManagerView has no planPickerMenu — re-derive this test")
        let menus = code.wordOffsets("Menu", in: picker.body).compactMap { code.call(named: "Menu", at: $0) }
        try #require(menus.count == 1, "planPickerMenu makes \(menus.count) Menu calls, expected one")
        let label = try #require(menus[0].labelledClosures.first { $0.label == "label" }?.range,
                                 "the plan picker's Menu has no label: closure")
        let names = code.wordOffsets("Text", in: label)
            .compactMap { code.call(named: "Text", at: $0) }
            .filter { $0.arguments.map { code.text($0).contains("selectedPlan?.displayName") } == true }
        try #require(names.count == 1, "the picker's label holds \(names.count) Texts of the plan's name, expected one")
        let chain = code.modifierChain(after: names[0].end)
        let modifiers = chain.map { "\($0.name)\($0.arguments.map { Self.collapse(code.text($0)) } ?? "")" }
        #expect(modifiers.contains("lineLimit(1)"), "the plan's name has no .lineLimit(1): its modifiers are \(modifiers)")
        #expect(modifiers.contains("truncationMode(.tail)"),
                "the plan's name is not cut at the tail (.truncationMode(.tail)): its modifiers are \(modifiers)")
        // A line limit alone narrows nothing in a toolbar, which gives an item its content's own width:
        // measured, the toolbar needed exactly as much room with it as without it. Only a maximum
        // width makes the name truncate.
        let caps = chain.filter { $0.name == "frame" }
            .compactMap { $0.arguments.flatMap { code.topLevelArgument("maxWidth", in: $0) } }
            .map { Self.collapse(code.text($0)) }
        try #require(caps.count == 1, "the plan's name must carry one .frame(maxWidth:), found \(caps)")
        let cap = try #require(Self.literalWidth(caps[0], in: code),
                               "the name's maximum width «\(caps[0])» is neither a number nor a static let set to one")
        #expect(cap == Self.measuredPlanNameMaxWidth, """
            The picker caps the plan's name at \(cap) pt, but measuredToolbarFitWidth \
            (\(Self.measuredToolbarFitWidth) pt) was measured with a \(Self.measuredPlanNameMaxWidth) pt cap. \
            A wider cap widens the toolbar: measure again on a Mac and update both numbers, and the \
            window's default size if the new fit is wider.
            """)
    }

    /// The value of a width written as `text`: a number, or the name of a `static let` in `code`
    /// set to one (`Self.planNameMaxWidth`); `nil` otherwise.
    fileprivate static func literalWidth(_ text: String, in code: MaskedSwift) -> Int? {
        if let value = Int(text) { return value }
        guard let name = text.split(separator: ".").last.map(String.init),
              let pattern = try? NSRegularExpression(
                pattern: #"static\s+let\s+"# + NSRegularExpression.escapedPattern(for: name)
                    + #"\s*(?::\s*CGFloat\s*)?=\s*([0-9]+)(?![0-9.])"#) else { return nil }
        let all = code.text(0..<code.bytes.count)
        let matches = pattern.matches(in: all, range: NSRange(all.startIndex..., in: all))
        guard matches.count == 1, let range = Range(matches[0].range(at: 1), in: all) else { return nil }
        return Int(all[range])
    }

    @Test("#1378: the Archives Visits window opens at least as wide as its toolbar")
    func theWindowOpensWideEnoughForItsToolbar() throws {
        let raw = try Self.source(Self.appPath)
        let rawBytes = Array(raw.utf8)
        let code = MaskedSwift(raw).compiled(for: .macOS).code
        let windows = code.wordOffsets("Window")
            .compactMap { code.call(named: "Window", at: $0) }
            .filter { String(decoding: rawBytes[$0.start..<$0.end], as: UTF8.self).contains("\"frus.archiveVisits\"") }
        try #require(windows.count == 1, "the Mac compiles \(windows.count) Window scenes with id frus.archiveVisits")
        let sizes = code.modifierChain(after: windows[0].end).filter { $0.name == "defaultSize" }
        try #require(sizes.count == 1, "the Archives Visits window carries \(sizes.count) .defaultSize modifiers")
        let width = try #require(sizes[0].arguments
            .flatMap { code.topLevelArgument("width", in: $0) }
            .flatMap { Int(Self.collapse(code.text($0))) }, "the window's .defaultSize passes no literal width:")
        #expect(Self.measuredToolbarFitWidth > 900,
                "the measured fit width must be recorded, and #1378 saw the toolbar overflow at 900 pt")
        #expect(width >= Self.measuredToolbarFitWidth, """
            The Archives Visits window opens \(width) pt wide, below the \(Self.measuredToolbarFitWidth) pt at \
            which its toolbar was measured to show every item, so a new window opens with Filter, Export \
            packet and About research targets behind the overflow chevron (#1378).
            """)
    }

    // MARK: - Scanner fixtures (one per rule the reading applies)

    /// A stand-in editor with one Export packet control per shape the reading must tell apart.
    static let editorFixture = #"""
        struct ArchiveVisitEditorView: View {
            @State private var showShare = false
            var body: some View { Text("x") }
            private var inline: some View {
                Button {
                    showShare = true
                } label: {
                    Label(String(localized: "archiveVisit.editor.export", defaultValue: "Export packet"),
                          systemImage: "square.and.arrow.up")
                }
                .disabled(isEmpty)
            }
            private var viaArgument: some View {
                Button(action: exportPacket) {
                    Label(String(localized: "archiveVisit.editor.export", defaultValue: "Export packet"),
                          systemImage: "square.and.arrow.up")
                }
                .help(String(localized: "archiveVisit.editor.export.help", defaultValue: "Tip"))
            }
            private var elsewhere: some View {
                Button { showTiers = true } label: {
                    Label(String(localized: "archiveVisit.editor.export", defaultValue: "Export packet"),
                          systemImage: "square.and.arrow.up")
                }
            }
            private var helpKeyOnly: some View {
                Button { showShare = true } label: {
                    Label(String(localized: "archiveVisit.editor.export.help", defaultValue: "Not an export label"),
                          systemImage: "x")
                }
            }
            #if os(iOS)
            private var iOSOnly: some View {
                Button { showShare = true } label: {
                    Label(String(localized: "archiveVisit.editor.export", defaultValue: "Export packet"),
                          systemImage: "square.and.arrow.up")
                }
            }
            #endif
            private func exportPacket() { showShare = true }
        }
        """#

    @Test("#1378 scanner: an action is read from a trailing closure or action:, directly or through a member")
    func readingTellsTheControlShapesApart() throws {
        let mac = try Self.readEditor(source: Self.editorFixture, for: .macOS)
        let iOS = try Self.readEditor(source: Self.editorFixture, for: .iOS)
        // The label key is matched with its closing quote, so `….export.help` is not an export control;
        // and a control inside `#if os(iOS)` is one on iOS only.
        #expect(mac.controls.map(\.member) == ["inline", "viaArgument", "elsewhere"])
        #expect(iOS.controls.map(\.member) == ["inline", "viaArgument", "elsewhere", "iOSOnly"])
        let byMember = Dictionary(mac.controls.map { ($0.member, $0) }, uniquingKeysWith: { first, _ in first })
        let inline = try #require(byMember["inline"])
        let viaArgument = try #require(byMember["viaArgument"])
        let elsewhere = try #require(byMember["elsewhere"])
        // A trailing closure: braces folded away, and the flag set in it directly.
        #expect(inline.action == "showShare = true")
        #expect(mac.opensThePacketSheet(inline))
        #expect(inline.disabled == ["(isEmpty)"])
        #expect(inline.help == nil)
        // An `action:` argument naming a member, which sets the flag in its own body.
        #expect(viaArgument.action == "exportPacket")
        #expect(mac.opensThePacketSheet(viaArgument))
        #expect(viaArgument.disabled.isEmpty)
        #expect(viaArgument.help?.contains(Self.exportHelpKey) == true)
        // A closure that sets some other flag does not open the sheet.
        #expect(elsewhere.action == "showTiers = true")
        #expect(!mac.opensThePacketSheet(elsewhere))
    }

    /// A stand-in toolbar with one tooltip per shape the reading must tell apart.
    static let tooltipFixture = #"""
        struct ArchiveVisitEditorView: View {
            var body: some View { Text("x") }
            private var pastAnotherModifier: some View {
                Menu {
                    Button("Item") { }
                } label: {
                    Label(String(localized: "fixture.menu", defaultValue: "Menu"), systemImage: "x")
                }
                .disabled(false)
                .help(String(localized: "fixture.menu.help", defaultValue: "Tip"))
            }
            private var keyInAnItem: some View {
                Menu {
                    Button { } label: { Label(String(localized: "fixture.menu", defaultValue: "Menu"), systemImage: "x") }
                } label: {
                    Label(String(localized: "fixture.other", defaultValue: "Other"), systemImage: "x")
                }
                .help(String(localized: "fixture.other.help", defaultValue: "Tip"))
            }
            private var macOnly: some View {
                Menu {
                    Button("Item") { }
                } label: {
                    Label(String(localized: "fixture.menu", defaultValue: "Menu"), systemImage: "x")
                }
                #if os(macOS)
                .help(String(localized: "fixture.mac.help", defaultValue: "Tip"))
                #endif
            }
        }
        """#

    @Test("#1378 scanner: a tooltip is read from the control whose label: carries the key, through a platform #if")
    func readingFindsATooltipByItsControlsLabel() throws {
        let mac = try Self.readEditor(source: Self.tooltipFixture, for: .macOS)
        let iOS = try Self.readEditor(source: Self.tooltipFixture, for: .iOS)
        let key = "\"fixture.menu\""
        // Read past another modifier in the chain.
        let past = mac.helps(ofCall: "Menu", labelled: key, in: "pastAnotherModifier")
        #expect(past.count == 1 && past.first?.count == 1 && past.first?.first?.contains("\"fixture.menu.help\"") == true,
                "read \(past)")
        // The key carried by one of the menu's items, not by its label:, is not the menu's.
        #expect(mac.helps(ofCall: "Menu", labelled: key, in: "keyInAnItem").isEmpty)
        // A tooltip behind `#if os(macOS)` is the Mac's alone.
        let macOnly = mac.helps(ofCall: "Menu", labelled: key, in: "macOnly")
        #expect(macOnly.count == 1 && macOnly.first?.first?.contains("\"fixture.mac.help\"") == true, "read \(macOnly)")
        let iOSOnly = iOS.helps(ofCall: "Menu", labelled: key, in: "macOnly")
        #expect(iOSOnly.count == 1 && iOSOnly.first?.isEmpty == true, "iOS read \(iOSOnly)")
    }

    @Test("#1378 scanner: a maximum width is read as a number or as a static let set to one")
    func literalWidthReadsANumberOrAConstant() {
        func code(_ source: String) -> MaskedSwift { MaskedSwift(source).compiled(for: .macOS).code }
        let declared = code("enum A { static let planNameMaxWidth: CGFloat = 260 }")
        #expect(Self.literalWidth("240", in: declared) == 240, "a number is its own value")
        #expect(Self.literalWidth("Self.planNameMaxWidth", in: declared) == 260, "a constant is read from its declaration")
        #expect(Self.literalWidth("planNameMaxWidth", in: code("enum A { static let planNameMaxWidth = 250 }")) == 250,
                "a declaration with no type annotation is read too")
        #expect(Self.literalWidth("Self.cap", in: code("enum A { static let cap: CGFloat = 2.5e2 }")) == nil,
                "a value that is not a whole number is not read as its leading digits")
        #expect(Self.literalWidth("Self.cap", in: code("enum A { static let cap = 1 }\nenum B { static let cap = 2 }")) == nil,
                "a name declared twice is not guessed between")
        #expect(Self.literalWidth("Self.cap", in: declared) == nil, "an undeclared name has no value")
    }
}

// MARK: - ArchiveVisitMacEntryPointTests

/// Source gate for #1462: **on the Mac, Project Home's Plan a Visit and Review Changes' Open the plan
/// open the plan in the Archives Visits window, and iOS keeps its sheet.**
///
/// ## The defect it stops
/// Both entry points presented `NavigationStack { ArchiveVisitEditorView }` in a `.sheet` on every
/// platform. On the Mac the editor's controls are all toolbar items, which a macOS sheet does not
/// draw, and its body is a `List` with no size of its own, which a macOS sheet collapses: the Mac
/// by-eye check of 2026-09-25 saw a strip about 40 pt tall holding only Done.
///
/// ## What it pins
/// ``MacSheetToolbarPlacementAuditTests/windowHostedViews`` keeps the editor out of every Mac sheet,
/// and a Mac entry point that did nothing at all would pass it. So this suite pins the other half:
/// each entry point's control reaches its opener, the opener's Mac branch hands the plan to the
/// window and its iOS branch sets the sheet's state, the hand-off names the plan before it fronts the
/// window by the scene's id, and the window passes its own selection and the request itself to
/// ``ArchiveVisitWindowHandoff/take(request:selection:planIds:)`` — which
/// `ArchiveVisitWindowHandoffTests` drives, both writes included — on appear, when the request
/// changes, and when its plans do.
///
/// ## Where it can fail
/// These read source as each platform compiles it, with comments and string literals blanked, so
/// they give the same answer on every test destination. None can see the window come forward; that
/// is the owner's check on a Mac, from both entry points.
///
/// Version history:
///   1.0 — #1462: initial implementation
///   1.1 — #1462 review, round 1: the window's consumer must hand `take` the window's selection and
///         `appState.pendingArchiveVisitSelection` themselves. It used to be checked only for calling
///         the resolver, so deleting its write to the selection, or its clearing of the request,
///         passed every test
struct ArchiveVisitMacEntryPointTests {

    /// The platforms the files are read for.
    typealias Platform = SegmentedPickerAccessibilityAuditTests.Platform

    /// The app's source root.
    private static let sourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// The Mac window's root, which also declares the hand-off.
    static let managerPath = "TripPacket/MacArchiveVisitManagerView.swift"

    /// One entry point to a plan.
    struct EntryPoint: Sendable {
        /// The file, under the source root.
        let path: String
        /// The view that declares it.
        let type: String
        /// The localization key of the control's label, quotes included.
        let labelKey: String
        /// The member that opens the plan.
        let opener: String
        /// The state the iOS sheet is presented on.
        let sheetState: String
    }

    /// Project Home's Plan a Visit and Review Changes' Open the plan.
    static let entryPoints: [EntryPoint] = [
        EntryPoint(path: "ProjectContext/ProjectHomeView.swift", type: "ProjectHomeView",
                   labelKey: "\"project.home.planVisit\"", opener: "planVisit", sheetState: "editingPlan"),
        EntryPoint(path: "DocumentView/DocumentChangeReviewSheet.swift", type: "DocumentChangeReviewSheet",
                   labelKey: "\"document.review.other.openPlan %@\"", opener: "openPlan", sheetState: "planToOpen"),
    ]

    /// A type as one platform compiles it. File-private because it holds the file-private `MaskedSwift`.
    fileprivate struct TypeReading {
        /// The file's masked code as the platform compiles it.
        let code: MaskedSwift
        /// The file's unmasked UTF-8 bytes, for the literals the masked code blanks.
        let raw: [UInt8]
        /// The type's braces.
        let body: Range<Int>
        /// Its members with a body, by name.
        let members: [String: Range<Int>]

        /// Every call of `name` in `range`.
        func calls(_ name: String, in range: Range<Int>) -> [MaskedSwift.Call] {
            code.wordOffsets(name, in: range).compactMap { code.call(named: name, at: $0) }
        }

        /// The text of `range`, whitespace collapsed.
        func collapsed(_ range: Range<Int>) -> String {
            ArchiveVisitMacToolbarFitTests.collapse(code.text(range))
        }

        /// The unmasked source in `range`.
        func unmasked(_ range: Range<Int>) -> String {
            String(decoding: raw[range], as: UTF8.self)
        }
    }

    /// Reads the one declaration of `type` in `path` — its extension when `extension` is set — as
    /// `platform` compiles it.
    fileprivate static func read(_ path: String, type: String, extension isExtension: Bool = false,
                                 for platform: Platform) throws -> TypeReading {
        let raw = try String(contentsOf: sourceRoot.appendingPathComponent(path), encoding: .utf8)
        let code = MaskedSwift(raw).compiled(for: platform).code
        let declarations = code.typeDeclarations(file: 0).filter { $0.name == type && $0.isExtension == isExtension }
        try #require(declarations.count == 1,
                     "\(platform): found \(declarations.count) \(isExtension ? "extensions of" : "declarations of") \(type) in \(path)")
        let members = code.members(in: declarations[0].body)
        return TypeReading(code: code, raw: Array(raw.utf8), body: declarations[0].body,
                           members: Dictionary(members.map { ($0.name, $0.body) }, uniquingKeysWith: { first, _ in first }))
    }

    @Test("#1462: on the Mac, Plan a Visit and Open the plan hand the plan to the window; iOS presents the sheet")
    func eachEntryPointOpensThePlanWhereItsPlatformCan() throws {
        for entry in Self.entryPoints {
            for platform in [Platform.macOS, .iOS] {
                let reading = try Self.read(entry.path, type: entry.type, for: platform)
                // The control reaches the opener.
                let controls = reading.calls("Button", in: reading.body).filter { button in
                    button.labelledClosures.contains { $0.label == "label" && reading.unmasked($0.range).contains(entry.labelKey) }
                }
                try #require(controls.count == 1,
                             "\(platform): \(entry.type) has \(controls.count) Buttons labelled \(entry.labelKey), expected one")
                let action = try #require(controls[0].trailingClosure, "\(platform): the \(entry.labelKey) Button has no action closure")
                #expect(reading.code.memberReferences(in: action).contains(entry.opener),
                        "\(platform): the \(entry.labelKey) Button's action «\(reading.collapsed(action))» does not call \(entry.opener)")

                let opener = try #require(reading.members[entry.opener], "\(platform): \(entry.type) has no \(entry.opener)")
                let handoffs = reading.calls("openArchiveVisitWindow", in: opener)
                let setsSheet = reading.collapsed(opener).contains("\(entry.sheetState) = ")
                switch platform {
                case .macOS:
                    #expect(handoffs.count == 1, """
                        macOS: \(entry.type).\(entry.opener) makes \(handoffs.count) openArchiveVisitWindow calls. On the \
                        Mac the plan opens in the Archives Visits window, whose toolbar is the editor's only chrome \
                        and whose frame its only size; a sheet showed a strip holding only Done (#1462).
                        """)
                    #expect(reading.code.wordOffsets(entry.sheetState, in: reading.body).isEmpty, """
                        macOS compiles \(entry.type).\(entry.sheetState), the state the editor's sheet is presented \
                        on. Keep the state and its .sheet behind `#if os(iOS)`.
                        """)
                case .iOS:
                    #expect(handoffs.isEmpty, "iOS: \(entry.type).\(entry.opener) calls openArchiveVisitWindow, a Mac-only hand-off")
                    #expect(setsSheet, "iOS: \(entry.type).\(entry.opener) no longer sets \(entry.sheetState), so the editor's sheet never opens")
                }
            }
        }
    }

    @Test("#1462: the hand-off names the plan before it brings the Archives Visits window forward")
    func theHandoffNamesThePlanThenFrontsTheWindow() throws {
        let reading = try Self.read(Self.managerPath, type: "AppState", extension: true, for: .macOS)
        let handoff = try #require(reading.members["openArchiveVisitWindow"],
                                   "MacArchiveVisitManagerView.swift's AppState extension has no openArchiveVisitWindow")
        let statements = reading.collapsed((handoff.lowerBound + 1)..<(handoff.upperBound - 1))
        #expect(statements.hasPrefix("pendingArchiveVisitSelection = plan.id openWindow.fronting(id:"), """
            openArchiveVisitWindow must set the request and then front the window, in that order: a window \
            fronted first appears on whichever plan it was last on. It reads «\(statements)».
            """)
        let fronts = reading.calls("fronting", in: handoff)
        try #require(fronts.count == 1, "openArchiveVisitWindow makes \(fronts.count) fronting calls")
        let id = try #require(fronts[0].arguments.map(reading.unmasked))
        #expect(id.contains("\"frus.archiveVisits\""), "the hand-off fronts «\(id)», not the Archives Visits window")
    }

    @Test("#1462: the window takes the request on appear, when the request changes, and when its plans change")
    func theWindowTakesTheRequest() throws {
        let reading = try Self.read(Self.managerPath, type: "MacArchiveVisitManagerView", for: .macOS)
        let takers = reading.members.filter { reading.collapsed($0.value).contains("ArchiveVisitWindowHandoff.take(") }
        try #require(takers.count == 1, "\(takers.count) members of the window take the request, expected one: \(takers.keys.sorted())")
        let taker = try #require(takers.first)
        let consumer = taker.key
        // Both writes are `take`'s, which ArchiveVisitWindowHandoffTests drives, so the window must hand
        // it the state itself: a copy would leave the window where it was, or the request set — and a
        // request left set snaps the window back to its plan on the next change to the plan list.
        let takes = reading.calls("take", in: taker.value)
        try #require(takes.count == 1, "\(consumer) makes \(takes.count) take calls")
        let expected = [("request", "&appState.pendingArchiveVisitSelection"), ("selection", "&selectedId"),
                        ("planIds", "plans.map(\\.id)")]
        for (label, value) in expected {
            let argument = takes[0].arguments
                .flatMap { reading.code.topLevelArgument(label, in: $0) }
                .map(reading.collapsed)
            #expect(argument == value, """
                \(consumer) passes take's \(label): «\(argument ?? "nothing")», expected «\(value)». The window's \
                selection and the pending request must be the ones written.
                """)
        }
        let selectedPlan = try #require(reading.members["selectedPlan"],
                                        "MacArchiveVisitManagerView no longer declares selectedPlan — re-derive this test")
        #expect(reading.collapsed(selectedPlan).contains("$0.id == selectedId"),
                "the window no longer shows the plan `selectedId` names, so writing it shows nothing")
        let body = try #require(reading.members["body"], "MacArchiveVisitManagerView has no body")
        /// The modifier calls named `name` in the body whose closure calls the consumer.
        func consuming(_ name: String) -> [String] {
            reading.calls(name, in: body)
                .filter { call in call.trailingClosure.map { reading.code.memberReferences(in: $0).contains(consumer) } == true }
                .map { call in call.arguments.map(reading.collapsed) ?? "" }
        }
        #expect(consuming("onAppear").count == 1, "the window does not take a request pending when it opens (\(consumer) in .onAppear)")
        let changes = consuming("onChange")
        #expect(changes.contains { $0.contains("appState.pendingArchiveVisitSelection") },
                "the window does not take a request made while it is open: its .onChange calls to \(consumer) observe \(changes)")
        #expect(changes.contains { $0.contains("plans") }, """
            The window does not retry a request when its plans change, so a plan not listed yet when the \
            request arrived is never selected: its .onChange calls to \(consumer) observe \(changes)
            """)
    }
}

/// A type declaration — `struct`, `class`, `enum`, `actor`, or an `extension` — as one platform
/// compiles it, for ``MacSheetToolbarPlacementAuditTests``.
private struct SheetDeclaration {
    /// A byte range in one file.
    struct Span: Hashable {
        /// The file's index in the scan.
        let file: Int
        /// The range, braces included.
        let range: Range<Int>
    }

    /// The file's index in the scan.
    let file: Int
    /// The declared name, the last component of a dotted extension name.
    let name: String
    /// Whether this is an `extension` rather than the type's own declaration.
    let isExtension: Bool
    /// The declaration's braces.
    let body: Range<Int>
    /// Whether the header names `View` (`: View`, `: View, Equatable`, `<Content: View>: View`).
    let conformsToView: Bool
}

/// The offset each line of a file starts at, so a line number is a binary search rather than a
/// count of every byte before it (``MaskedSwift/line(at:)``, which this audit would call hundreds
/// of times over files of 100 KB and more).
private struct LineIndex {
    /// The offset of each line's first byte, the first line's included.
    let starts: [Int]

    /// Indexes `bytes`, whose newlines are the source's own (masking keeps them).
    init(_ bytes: [UInt8]) {
        var starts = [0]
        var index = 0
        while index < bytes.count {
            if bytes[index] == ASCII.newline { starts.append(index + 1) }
            index += 1
        }
        self.starts = starts
    }

    /// The 1-based line holding `offset`: how many lines start at or before it.
    func line(at offset: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= offset { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

// MARK: - MaskedSwift: sheet reading

extension MaskedSwift {

    /// Whether `byte` is an ASCII capital, the first letter of a type name.
    static func isUppercase(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")
    }

    /// The identifier that starts at `offset`, when a whole identifier does.
    private func identifier(at offset: Int, before end: Int) -> Range<Int>? {
        guard offset < end, Self.isIdentifier(bytes[offset]),
              offset == 0 || !Self.isIdentifier(bytes[offset - 1]) else { return nil }
        var close = offset
        while close < end, Self.isIdentifier(bytes[close]) { close += 1 }
        return offset..<close
    }

    /// Whether the identifier `word` spells `spelling`, compared byte by byte.
    private func spells(_ spelling: [UInt8], _ word: Range<Int>) -> Bool {
        guard word.count == spelling.count else { return false }
        var index = 0
        while index < spelling.count {
            if bytes[word.lowerBound + index] != spelling[index] { return false }
            index += 1
        }
        return true
    }

    /// The whole identifiers in `range` (the whole file when `nil`), read with plain index loops.
    ///
    /// ``occurrences(of:in:)`` gives the same offsets for one word, but its generic range
    /// iteration dominated a Debug run of this audit, which reads every file in the tree as macOS
    /// compiles it and walks its words several times over: for type declarations, `.sheet(` calls,
    /// member references, constructed views and toolbar items.
    private func words(in range: Range<Int>? = nil) -> [Range<Int>] {
        let bounds = range ?? 0..<bytes.count
        var found: [Range<Int>] = []
        var index = bounds.lowerBound
        while index < bounds.upperBound {
            guard Self.isIdentifier(bytes[index]) else { index += 1; continue }
            var end = index + 1
            while end < bytes.count, Self.isIdentifier(bytes[end]) { end += 1 }
            // A word that starts before the range, or runs past it, is not a whole word in it.
            if index == 0 || !Self.isIdentifier(bytes[index - 1]), end <= bounds.upperBound {
                found.append(index..<end)
            }
            index = end
        }
        return found
    }

    /// Offsets of `word` as a whole identifier in `range` (the whole file when `nil`).
    func wordOffsets(_ word: String, in range: Range<Int>? = nil) -> [Int] {
        let spelling = Array(word.utf8)
        return words(in: range).filter { spells(spelling, $0) }.map(\.lowerBound)
    }

    /// Every type declaration in the file, nested ones included.
    func typeDeclarations(file: Int) -> [SheetDeclaration] {
        let keywords = ["struct", "class", "enum", "actor", "extension"].map { Array($0.utf8) }
        let extensionKeyword = Array("extension".utf8)
        var found: [SheetDeclaration] = []
        for word in words() {
            guard let keyword = keywords.first(where: { spells($0, word) }) else { continue }
            let nameStart = skipBlanks(from: word.upperBound)
            var nameEnd = nameStart
            while nameEnd < bytes.count, Self.isIdentifier(bytes[nameEnd]) || bytes[nameEnd] == ASCII.dot {
                nameEnd += 1
            }
            let qualified = text(nameStart..<nameEnd)
            let name = qualified.split(separator: ".").last.map(String.init) ?? qualified
            // `class func` and `class var` declare members, not types.
            guard let first = name.utf8.first, Self.isUppercase(first) else { continue }
            var open = nameEnd
            while open < bytes.count, bytes[open] != ASCII.openBrace { open += 1 }
            guard open < bytes.count, let close = closing(open) else { continue }
            let header = text(nameEnd..<open)
                .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") })
            found.append(SheetDeclaration(file: file, name: name, isExtension: keyword == extensionKeyword,
                                          body: open..<close, conformsToView: header.contains("View")))
        }
        return found
    }

    /// The members declared directly inside a type's braces `body` that have a body of their own —
    /// computed properties and functions — by name, with that body's braces.
    func members(in body: Range<Int>) -> [(name: String, body: Range<Int>)] {
        var found: [(name: String, body: Range<Int>)] = []
        let end = body.upperBound - 1
        var index = body.lowerBound + 1
        var depth = 0
        while index < end {
            if bytes[index] == ASCII.openBrace { depth += 1; index += 1; continue }
            if bytes[index] == ASCII.closeBrace { depth -= 1; index += 1; continue }
            guard depth == 0, let keyword = identifier(at: index, before: end) else { index += 1; continue }
            let word = text(keyword)
            guard word == "var" || word == "func",
                  let nameRange = identifier(at: skipBlanks(from: keyword.upperBound), before: end) else {
                index = keyword.upperBound
                continue
            }
            var scan = nameRange.upperBound
            if word == "func" {
                guard let open = bytes[scan..<end].firstIndex(of: ASCII.openParen), let close = closing(open) else {
                    index = nameRange.upperBound
                    continue
                }
                scan = close
            }
            // The body opens before the declaration ends: `=` begins a stored property's initialiser,
            // and a line break outside brackets ends a property's declaration.
            var bracketDepth = 0
            var bodyOpen: Int?
            while scan < end {
                let current = bytes[scan]
                if current == ASCII.openBrace, bracketDepth == 0 { bodyOpen = scan; break }
                if current == ASCII.openParen || current == UInt8(ascii: "[") || current == UInt8(ascii: "<") {
                    bracketDepth += 1
                } else if current == ASCII.closeParen || current == UInt8(ascii: "]") || current == UInt8(ascii: ">") {
                    bracketDepth = max(0, bracketDepth - 1)
                } else if bracketDepth == 0, current == UInt8(ascii: "=") {
                    break
                } else if word == "var", bracketDepth == 0, current == ASCII.newline {
                    break
                }
                scan += 1
            }
            guard let open = bodyOpen, let close = closing(open) else {
                index = nameRange.upperBound
                continue
            }
            found.append((text(nameRange), open..<close))
            index = close
        }
        return found
    }

    /// The identifiers in `range` that can name a member of the enclosing type: lower-case, and
    /// bare or after `self.` (`x.name` names a member of `x`).
    func memberReferences(in range: Range<Int>) -> Set<String> {
        var names = Set<String>()
        for word in words(in: range) where !Self.isUppercase(bytes[word.lowerBound]) {
            let start = word.lowerBound
            let dotted = start > 0 && bytes[start - 1] == ASCII.dot
            let afterSelf = dotted && start >= 5 && text(start - 5..<start - 1) == "self"
                && (start == 5 || !Self.isIdentifier(bytes[start - 6]))
            if !dotted || afterSelf { names.insert(text(word)) }
        }
        return names
    }

    /// Whether the identifier `word` is called: followed by `(`, or by a `{` after blanks.
    private func isCalled(_ word: Range<Int>) -> Bool {
        guard word.upperBound < bytes.count else { return false }
        if bytes[word.upperBound] == ASCII.openParen { return true }
        let brace = skipBlanks(from: word.upperBound)
        return brace < bytes.count && bytes[brace] == ASCII.openBrace
    }

    /// The view types among `viewTypes` that `range` constructs — `Name(`, `Name {`, `Name<`, or
    /// `Name.init(` — in the order first constructed. A name after a `.` is a member, not a type.
    func constructedTypes(in range: Range<Int>, among viewTypes: Set<String>) -> [String] {
        var names: [String] = []
        for word in words(in: range) where Self.isUppercase(bytes[word.lowerBound]) {
            let name = text(word)
            guard viewTypes.contains(name), word.lowerBound == 0 || bytes[word.lowerBound - 1] != ASCII.dot,
                  !names.contains(name) else { continue }
            let generic = word.upperBound < bytes.count && bytes[word.upperBound] == UInt8(ascii: "<")
            let initializer = text(word.upperBound..<min(word.upperBound + 6, bytes.count)) == ".init("
            if isCalled(word) || generic || initializer { names.append(name) }
        }
        return names
    }

    /// Every call in `range` to a capitalized callee — `ShareLink(`, `Button {` — by callee name.
    func capitalizedCalls(in range: Range<Int>) -> [String] {
        words(in: range)
            .filter { Self.isUppercase(bytes[$0.lowerBound]) && ($0.lowerBound == 0 || bytes[$0.lowerBound - 1] != ASCII.dot) }
            .filter(isCalled)
            .map(text)
    }

    /// For each `Button` in `range` whose modifier chain carries `.keyboardShortcut(.defaultAction)`,
    /// the member names its action reads: the trailing closure, or the `action:` argument.
    func defaultActionButtons(in range: Range<Int>) -> [Set<String>] {
        wordOffsets("Button", in: range).compactMap { offset -> Set<String>? in
            guard let button = call(named: "Button", at: offset),
                  modifierChain(after: button.end).contains(where: { modifier in
                      modifier.name == "keyboardShortcut"
                          && modifier.arguments.map { text($0).contains(".defaultAction") } == true
                  }) else { return nil }
            let action = button.arguments.flatMap { topLevelArgument("action", in: $0) } ?? button.trailingClosure
            return action.map { memberReferences(in: $0) } ?? []
        }
    }

    /// The value of the argument labelled `label` at the top level of `arguments` (parentheses
    /// included), or `nil` when the call does not pass it.
    func topLevelArgument(_ label: String, in arguments: Range<Int>) -> Range<Int>? {
        var depth = 0
        var segmentStart = arguments.lowerBound + 1
        var segments: [Range<Int>] = []
        for index in (arguments.lowerBound + 1)..<(arguments.upperBound - 1) {
            let byte = bytes[index]
            if byte == ASCII.openParen || byte == ASCII.openBrace || byte == UInt8(ascii: "[") {
                depth += 1
            } else if byte == ASCII.closeParen || byte == ASCII.closeBrace || byte == UInt8(ascii: "]") {
                depth -= 1
            } else if byte == UInt8(ascii: ","), depth == 0 {
                segments.append(segmentStart..<index)
                segmentStart = index + 1
            }
        }
        segments.append(segmentStart..<(arguments.upperBound - 1))
        for segment in segments {
            guard let word = identifier(at: skipBlanks(from: segment.lowerBound), before: segment.upperBound),
                  text(word) == label else { continue }
            let colon = skipBlanks(from: word.upperBound)
            guard colon < segment.upperBound, bytes[colon] == ASCII.colon else { continue }
            return (colon + 1)..<segment.upperBound
        }
        return nil
    }

    /// Every `ToolbarItem(` / `ToolbarItemGroup(` call in `range`, in source order, with the
    /// `placement:` it passes; `lines` is this file's line index.
    func toolbarItems(in range: Range<Int>, path: String,
                      lines: LineIndex) -> [MacSheetToolbarPlacementAuditTests.ToolbarItemSite] {
        ["ToolbarItem", "ToolbarItemGroup"]
            .flatMap { name in
                wordOffsets(name, in: range).compactMap { offset -> (Int, MacSheetToolbarPlacementAuditTests.ToolbarItemSite)? in
                    guard let item = call(named: name, at: offset),
                          item.arguments != nil || item.trailingClosure != nil else { return nil }
                    let placement = item.arguments
                        .flatMap { topLevelArgument("placement", in: $0) }
                        .map { text($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    return (offset, .init(path: path, line: lines.line(at: offset), call: name, placement: placement,
                                          reads: item.trailingClosure.map { memberReferences(in: $0) } ?? []))
                }
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }
}

// MARK: - Compilation branches

/// How one platform compiles each line of a Swift file whose comments and string literals are
/// already blanked: whether it takes the line, which `#if` branches enclose it, and the blocks the
/// file's directives open.
///
/// `MaskedSwift.compiled(for:)` is built on this walk — the segmented-picker, Mac sheet and toolbar
/// fit audits read a file through it — and the Mac tap-copy scan
/// (`CodingStandardsAuditTests.macTextNeverSaysTap`) reads it line by line. One walk, so the two
/// readings cannot disagree about what a platform compiles.
///
/// `os(…)`, `canImport(UIKit)`, `canImport(AppKit)`, `targetEnvironment(macCatalyst)`, `true`,
/// `false`, `!`, `&&`, `||` and parentheses are decided. Anything else, such as `DEBUG` or
/// `canImport(Accessibility)`, can ship either way, so a branch behind it is kept and its lines read
/// `nil`. `CodingStandardsAuditTests.compilationBranchRules` pins each gate kind, one fixture each.
///
/// Version history:
///   1.0 — 2026-09-25: #1380 — lifted out of `MaskedSwift.compiled(for:)`, which now blanks what
///         this walk decides, and extended to report each line's enclosing branches and the file's
///         blocks, so the Mac tap-copy scan could read a line's gate without a second evaluator
struct CompilationBranches {

    /// A platform the app targets compile `FRUSExplorer/` for.
    typealias Platform = SegmentedPickerAccessibilityAuditTests.Platform

    /// One `#if` / `#elseif` / `#else` branch enclosing a line.
    struct Branch: Equatable, Sendable {
        /// The directive that opens it: `if`, `elseif` or `else`.
        let keyword: String
        /// Its own condition as written, trimmed; empty for `#else`.
        let condition: String
        /// The conditions of the block's earlier branches, in order — for an `#else`, the ones it
        /// negates.
        let earlier: [String]
    }

    /// One `#if` … `#endif` block.
    struct Block: Equatable, Sendable {
        /// The 1-based line of its `#if`.
        let opens: Int
        /// The 1-based line of its `#endif`, or `nil` when the file ends first.
        var closes: Int?
        /// How many branches enclose its `#if`: zero for a top-level block.
        let depth: Int
    }

    /// One source line as the platform compiles it.
    struct Line: Equatable, Sendable {
        /// `true` when the platform compiles the line, `false` when it does not, and `nil` when an
        /// enclosing condition cannot be decided and either build can ship it.
        let compiled: Bool?
        /// Whether the line is a `#if` / `#elseif` / `#else` / `#endif` directive.
        let isDirective: Bool
        /// The branches enclosing the line, outermost first. A directive line is enclosed by the
        /// branches around its block, not by its own.
        let branches: [Branch]
    }

    /// The platform the lines were decided for.
    let platform: Platform
    /// Every line, in order: `lines[n - 1]` is line `n`.
    let lines: [Line]
    /// Each line's byte range in the source, newline excluded, indexed like `lines`.
    let lineRanges: [Range<Int>]
    /// Every block, in the order they open.
    let blocks: [Block]
    /// The byte offsets of the directive lines of every block with a branch the platform cannot
    /// decide, when the code around that block is not already excluded.
    let undecidedDirectives: [Int]
    /// The top-level block that holds every line of code in the file but its imports, when there
    /// is one — `SupportingViews.swift`'s `#if os(macOS)` … `#endif`.
    let fileWideBlock: Block?

    /// Decides every line of `masked`, a Swift file with its comments and string literals blanked,
    /// for `platform`.
    init(masked bytes: [UInt8], platform: Platform) {
        /// One open block, as the walk reads it.
        struct Frame {
            /// Whether the code around the block is compiled.
            let outer: Bool?
            /// Whether every earlier branch's condition was false.
            var noneTaken: Bool?
            /// Whether the current branch is taken, before `outer` is applied.
            var taken: Bool?
            /// The current branch.
            var branch: Branch
            /// The offsets of the block's directive lines so far.
            var directives: [Int]
            /// Whether any of its branches was undecidable.
            var undecided: Bool
            /// The block's index in `blocks`.
            let block: Int
        }
        var stack: [Frame] = []
        var lines: [Line] = []
        var lineRanges: [Range<Int>] = []
        var blocks: [Block] = []
        var undecided: [Int] = []
        func close(_ frame: Frame) {
            if frame.undecided, frame.outer != false { undecided += frame.directives }
        }
        var lineStart = 0
        while lineStart < bytes.count {
            var lineEnd = lineStart
            while lineEnd < bytes.count, bytes[lineEnd] != ASCII.newline { lineEnd += 1 }
            lineRanges.append(lineStart..<lineEnd)
            let number = lineRanges.count
            let enclosing = stack.last.map { Self.and($0.outer, $0.taken) } ?? true
            var first = lineStart
            while first < lineEnd, bytes[first] == ASCII.space || bytes[first] == ASCII.tab { first += 1 }
            var keywordEnd = min(first + 1, lineEnd)
            while keywordEnd < lineEnd, MaskedSwift.isIdentifier(bytes[keywordEnd]) { keywordEnd += 1 }
            let keyword = first < lineEnd && bytes[first] == ASCII.pound
                ? String(decoding: bytes[(first + 1)..<keywordEnd], as: UTF8.self) : ""
            let conditionBytes = Array(bytes[keywordEnd..<lineEnd])
            let condition = String(decoding: conditionBytes, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            switch keyword {
            case "if":
                let value = Self.evaluate(conditionBytes, for: platform)
                lines.append(Line(compiled: enclosing, isDirective: true, branches: stack.map(\.branch)))
                blocks.append(Block(opens: number, closes: nil, depth: stack.count))
                stack.append(Frame(outer: enclosing, noneTaken: Self.not(value), taken: value,
                                   branch: Branch(keyword: keyword, condition: condition, earlier: []),
                                   directives: [first], undecided: value == nil, block: blocks.count - 1))
            case "elseif", "else":
                guard var frame = stack.popLast() else {
                    lines.append(Line(compiled: enclosing, isDirective: true, branches: []))
                    break
                }
                lines.append(Line(compiled: frame.outer, isDirective: true, branches: stack.map(\.branch)))
                let value = keyword == "else" ? true : Self.evaluate(conditionBytes, for: platform)
                frame.taken = Self.and(frame.noneTaken, value)
                frame.noneTaken = Self.and(frame.noneTaken, Self.not(value))
                frame.branch = Branch(keyword: keyword, condition: keyword == "else" ? "" : condition,
                                      earlier: frame.branch.earlier + [frame.branch.condition])
                frame.directives.append(first)
                frame.undecided = frame.undecided || frame.taken == nil
                stack.append(frame)
            case "endif":
                guard var frame = stack.popLast() else {
                    lines.append(Line(compiled: enclosing, isDirective: true, branches: []))
                    break
                }
                lines.append(Line(compiled: frame.outer, isDirective: true, branches: stack.map(\.branch)))
                frame.directives.append(first)
                blocks[frame.block].closes = number
                close(frame)
            default:
                lines.append(Line(compiled: enclosing, isDirective: false, branches: stack.map(\.branch)))
            }
            lineStart = lineEnd + 1
        }
        stack.forEach(close)
        self.platform = platform
        self.lines = lines
        self.lineRanges = lineRanges
        self.blocks = blocks
        self.undecidedDirectives = undecided.sorted()
        self.fileWideBlock = blocks.first { block in
            guard block.depth == 0, let closes = block.closes else { return false }
            return lineRanges.indices.allSatisfy { index in
                let number = index + 1
                if number >= block.opens && number <= closes { return true }
                return Self.isBlankOrImport(bytes[lineRanges[index]])
            }
        }
    }

    /// The line numbered `number`, or `nil` past the end.
    func line(_ number: Int) -> Line? {
        number >= 1 && number <= lines.count ? lines[number - 1] : nil
    }

    /// Whether a masked line holds nothing but whitespace, or an `import` (with any attributes).
    static func isBlankOrImport(_ line: ArraySlice<UInt8>) -> Bool {
        let text = String(decoding: line, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        let words = text.split(separator: " ")
        guard let first = words.firstIndex(where: { !$0.hasPrefix("@") }) else { return false }
        return words[first] == "import"
    }

    // MARK: Conditions

    /// Decides a `#if` / `#elseif` condition for `platform`: `nil` when it cannot.
    static func evaluate(_ text: [UInt8], for platform: Platform) -> Bool? {
        var parser = Condition(text: text, platform: platform)
        return parser.parse()
    }

    /// `a && b`: false when either is false, true when both are true, otherwise undecided.
    static func and(_ lhs: Bool?, _ rhs: Bool?) -> Bool? {
        if lhs == false || rhs == false { return false }
        return lhs == true && rhs == true ? true : nil
    }

    /// `a || b`: true when either is true, false when both are false, otherwise undecided.
    static func or(_ lhs: Bool?, _ rhs: Bool?) -> Bool? {
        if lhs == true || rhs == true { return true }
        return lhs == false && rhs == false ? false : nil
    }

    /// `!a`, undecided when `a` is.
    static func not(_ value: Bool?) -> Bool? { value.map { !$0 } }

    /// A `#if` condition evaluator over three values: `true`, `false`, and `nil` for undecidable.
    private struct Condition {
        /// The condition's bytes.
        let text: [UInt8]
        /// The platform deciding `os(…)` and `canImport(…)`.
        let platform: Platform
        /// The read position.
        var index = 0
        /// Set when the text is not a condition this grammar reads; the result is then `nil`.
        var failed = false

        /// Starts an evaluator over `text`.
        init(text: [UInt8], platform: Platform) {
            self.text = text
            self.platform = platform
        }

        /// The whole condition's value.
        mutating func parse() -> Bool? {
            let value = disjunction()
            skipSpaces()
            return failed || index < text.count ? nil : value
        }

        /// Steps over spaces and tabs.
        mutating func skipSpaces() {
            while index < text.count, text[index] == ASCII.space || text[index] == ASCII.tab { index += 1 }
        }

        /// Consumes `token` when it is next.
        mutating func consume(_ token: String) -> Bool {
            skipSpaces()
            let bytes = Array(token.utf8)
            guard index + bytes.count <= text.count, Array(text[index..<index + bytes.count]) == bytes else {
                return false
            }
            index += bytes.count
            return true
        }

        /// `a || b || …`.
        mutating func disjunction() -> Bool? {
            var value = conjunction()
            while consume("||") { value = CompilationBranches.or(value, conjunction()) }
            return value
        }

        /// `a && b && …`.
        mutating func conjunction() -> Bool? {
            var value = unary()
            while consume("&&") { value = CompilationBranches.and(value, unary()) }
            return value
        }

        /// `!a`, or a primary.
        mutating func unary() -> Bool? {
            consume("!") ? CompilationBranches.not(unary()) : primary()
        }

        /// `( … )`, `name`, or `name(argument)`.
        mutating func primary() -> Bool? {
            if consume("(") {
                let value = disjunction()
                if !consume(")") { failed = true }
                return value
            }
            skipSpaces()
            let nameStart = index
            while index < text.count, MaskedSwift.isIdentifier(text[index]) { index += 1 }
            guard index > nameStart else { failed = true; return nil }
            let name = String(decoding: text[nameStart..<index], as: UTF8.self)
            guard index < text.count, text[index] == ASCII.openParen else {
                switch name {
                case "true": return true
                case "false": return false
                default: return nil
                }
            }
            let argumentStart = index + 1
            while index < text.count, text[index] != ASCII.closeParen { index += 1 }
            guard index < text.count else { failed = true; return nil }
            let argument = String(decoding: text[argumentStart..<index], as: UTF8.self)
                .trimmingCharacters(in: .whitespaces)
            index += 1
            switch (name, argument) {
            case ("os", "iOS"): return platform == .iOS
            case ("os", "macOS"): return platform == .macOS
            case ("os", _): return false
            case ("canImport", "UIKit"): return platform == .iOS
            case ("canImport", "AppKit"): return platform == .macOS
            case ("targetEnvironment", "macCatalyst"): return false
            default: return nil
            }
        }
    }
}

// MARK: - MaskedSwift

/// The ASCII bytes the source scanners compare against.
private enum ASCII {
    static let newline = UInt8(ascii: "\n")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let carriageReturn = UInt8(ascii: "\r")
    static let slash = UInt8(ascii: "/")
    static let star = UInt8(ascii: "*")
    static let quote = UInt8(ascii: "\"")
    static let pound = UInt8(ascii: "#")
    static let backslash = UInt8(ascii: "\\")
    static let openParen = UInt8(ascii: "(")
    static let closeParen = UInt8(ascii: ")")
    static let openBrace = UInt8(ascii: "{")
    static let closeBrace = UInt8(ascii: "}")
    static let colon = UInt8(ascii: ":")
    static let dot = UInt8(ascii: ".")
    static let underscore = UInt8(ascii: "_")
}

/// Swift source with every comment and string literal (interpolations included) blanked to spaces,
/// newlines kept, plus the `#if` blanking (over ``CompilationBranches``, above) and the few parsing
/// primitives the segmented-picker audit needs. The Mac sheet audit's own primitives are in the
/// extension above.
///
/// Blanking first is what lets a balanced-parenthesis match survive a `defaultValue:` holding an
/// unmatched "(", and what keeps a comment that *mentions* `.pickerStyle(.segmented)` from counting
/// as one. Offsets and line numbers are the source's own, because only non-newline bytes change.
private struct MaskedSwift {

    /// The masked UTF-8 bytes.
    let bytes: [UInt8]

    /// Masks `source`.
    init(_ source: String) {
        var masker = Masker(Array(source.utf8))
        masker.code(masking: false, insideInterpolation: false)
        bytes = masker.out
    }

    /// Wraps bytes that are already masked.
    private init(masked: [UInt8]) {
        bytes = masked
    }

    // MARK: Compilation conditions

    /// The code `platform` compiles, and the offsets of the `#if` / `#elseif` / `#else` / `#endif`
    /// lines of every block whose branch it cannot decide.
    ///
    /// A branch the platform does not take is blanked, and so is every directive line, so what is
    /// left reads as one platform's source and a modifier chain never has to step over a directive.
    /// A branch whose condition is undecidable (`DEBUG`) is kept, because either build can ship it;
    /// its directive lines are returned so a caller can refuse to judge a construct that spans one.
    /// Blanking keeps newlines, so offsets and line numbers stay the source's own.
    ///
    /// Which lines a platform takes is ``CompilationBranches``' walk — the one the Mac tap-copy
    /// scan reads line by line — so the two cannot disagree about what a platform compiles.
    func compiled(for platform: SegmentedPickerAccessibilityAuditTests.Platform) -> (code: MaskedSwift, undecided: [Int]) {
        let branches = CompilationBranches(masked: bytes, platform: platform)
        var out = bytes
        for (line, range) in zip(branches.lines, branches.lineRanges)
        where line.isDirective || line.compiled == false {
            for offset in range { out[offset] = ASCII.space }
        }
        return (MaskedSwift(masked: out), branches.undecidedDirectives)
    }

    // MARK: Lexing

    /// The comment and string-literal lexer behind ``init(_:)``.
    private struct Masker {
        /// The unmasked bytes.
        let source: [UInt8]
        /// The masked copy being written.
        var out: [UInt8]
        /// The read position.
        var index = 0

        /// Starts a masker over `source`.
        init(_ source: [UInt8]) {
            self.source = source
            out = source
        }

        /// The byte at `offset`, or `nil` past the end.
        func byte(_ offset: Int) -> UInt8? { offset < source.count ? source[offset] : nil }

        /// Blanks one byte, keeping newlines so line numbers survive.
        mutating func blank(_ offset: Int) {
            if source[offset] != ASCII.newline { out[offset] = ASCII.space }
        }

        /// Whether `count` pound signs start at `offset`.
        func pounds(_ count: Int, at offset: Int) -> Bool {
            (0..<count).allSatisfy { byte(offset + $0) == ASCII.pound }
        }

        /// How many `#` open a raw string at `offset`, or `nil` when none does (`#if`, `#selector`).
        func rawStringPounds(at offset: Int) -> Int? {
            var count = 0
            while byte(offset + count) == ASCII.pound { count += 1 }
            return count > 0 && byte(offset + count) == ASCII.quote ? count : nil
        }

        /// Reads code to the end of the source or, inside an interpolation, through the `)` that
        /// closes it. `masking` blanks the code too (an interpolation is part of its string).
        mutating func code(masking: Bool, insideInterpolation: Bool) {
            var depth = 0
            while index < source.count {
                let current = source[index]
                if current == ASCII.slash, byte(index + 1) == ASCII.slash {
                    while index < source.count, source[index] != ASCII.newline { blank(index); index += 1 }
                    continue
                }
                if current == ASCII.slash, byte(index + 1) == ASCII.star {
                    blockComment()
                    continue
                }
                if current == ASCII.quote || (current == ASCII.pound && rawStringPounds(at: index) != nil) {
                    stringLiteral()
                    continue
                }
                if insideInterpolation {
                    if current == ASCII.openParen {
                        depth += 1
                    } else if current == ASCII.closeParen {
                        if depth == 0 {
                            if masking { blank(index) }
                            index += 1
                            return
                        }
                        depth -= 1
                    }
                }
                if masking { blank(index) }
                index += 1
            }
        }

        /// Blanks a `/* … */` comment, which Swift lets nest.
        mutating func blockComment() {
            var depth = 0
            while index < source.count {
                if source[index] == ASCII.slash, byte(index + 1) == ASCII.star {
                    depth += 1
                } else if source[index] == ASCII.star, byte(index + 1) == ASCII.slash {
                    depth -= 1
                } else {
                    blank(index)
                    index += 1
                    continue
                }
                blank(index)
                blank(index + 1)
                index += 2
                if depth == 0 { return }
            }
        }

        /// Blanks a string literal's contents — single-line, multi-line or raw, interpolations
        /// included — and leaves its delimiters.
        mutating func stringLiteral() {
            var poundCount = 0
            while byte(index) == ASCII.pound { poundCount += 1; index += 1 }
            let multiline = byte(index + 1) == ASCII.quote && byte(index + 2) == ASCII.quote
            index += multiline ? 3 : 1
            while index < source.count {
                let current = source[index]
                if current == ASCII.quote {
                    if multiline, byte(index + 1) == ASCII.quote, byte(index + 2) == ASCII.quote,
                       pounds(poundCount, at: index + 3) {
                        index += 3 + poundCount
                        return
                    }
                    if !multiline, pounds(poundCount, at: index + 1) {
                        index += 1 + poundCount
                        return
                    }
                }
                if current == ASCII.backslash, pounds(poundCount, at: index + 1) {
                    let escaped = index + 1 + poundCount
                    let isInterpolation = byte(escaped) == ASCII.openParen
                    for offset in index...min(escaped, source.count - 1) { blank(offset) }
                    index = escaped + 1
                    if isInterpolation { code(masking: true, insideInterpolation: true) }
                    continue
                }
                // An unterminated single-line literal ends at its line, as the compiler would report.
                if current == ASCII.newline, !multiline { return }
                blank(index)
                index += 1
            }
        }
    }

    // MARK: Primitives

    /// Whether `byte` can continue an identifier (non-ASCII bytes are taken to be identifier text).
    static func isIdentifier(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == ASCII.underscore || byte >= 0x80
    }

    /// Whether `byte` is a space, tab or line break.
    static func isBlank(_ byte: UInt8) -> Bool {
        byte == ASCII.space || byte == ASCII.tab || byte == ASCII.newline || byte == ASCII.carriageReturn
    }

    /// The text of `range`.
    func text(_ range: Range<Int>) -> String {
        String(decoding: bytes[range], as: UTF8.self)
    }

    /// The 1-based line holding `offset`.
    func line(at offset: Int) -> Int {
        bytes[..<offset].reduce(into: 1) { total, byte in if byte == ASCII.newline { total += 1 } }
    }

    /// Offsets of `word` as a whole identifier, inside `range` when one is given.
    func occurrences(of word: String, in range: Range<Int>? = nil) -> [Int] {
        let needle = Array(word.utf8)
        let bounds = range ?? 0..<bytes.count
        guard bounds.count >= needle.count else { return [] }
        var found: [Int] = []
        for start in bounds.lowerBound...(bounds.upperBound - needle.count)
        where bytes[start] == needle[0] && Array(bytes[start..<start + needle.count]) == needle {
            let before = start == 0 ? nil : bytes[start - 1]
            let after = start + needle.count < bytes.count ? bytes[start + needle.count] : nil
            if before.map(Self.isIdentifier) != true, after.map(Self.isIdentifier) != true {
                found.append(start)
            }
        }
        return found
    }

    /// The first offset at or after `offset` that is not a space or line break.
    func skipBlanks(from offset: Int) -> Int {
        var index = offset
        while index < bytes.count, Self.isBlank(bytes[index]) { index += 1 }
        return index
    }

    /// The offset just past the bracket that closes the one at `open` (`(` or `{`).
    func closing(_ open: Int) -> Int? {
        let opener = bytes[open]
        let closer = opener == ASCII.openParen ? ASCII.closeParen : ASCII.closeBrace
        var depth = 0
        for index in open..<bytes.count {
            if bytes[index] == opener { depth += 1 }
            if bytes[index] == closer {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
        }
        return nil
    }

    // MARK: Calls

    /// A parsed call: `name(arguments) { trailing } label: { … }`.
    struct Call {
        /// Offset of the callee's name, or of the leading `.` for a modifier.
        let start: Int
        /// The argument list, parentheses included.
        let arguments: Range<Int>?
        /// The first, unlabelled trailing closure, braces included.
        let trailingClosure: Range<Int>?
        /// Labelled trailing closures (`label: { … }`), in order.
        let labelledClosures: [(label: String, range: Range<Int>)]
        /// Offset just past the call.
        let end: Int
        /// The callee's name.
        let name: String
    }

    /// Parses the call whose callee `name` starts at `offset`.
    func call(named name: String, at offset: Int) -> Call? {
        var end = offset + name.utf8.count
        var arguments: Range<Int>?
        var afterName = end
        while afterName < bytes.count, bytes[afterName] == ASCII.space || bytes[afterName] == ASCII.tab {
            afterName += 1
        }
        if afterName < bytes.count, bytes[afterName] == ASCII.openParen {
            guard let close = closing(afterName) else { return nil }
            arguments = afterName..<close
            end = close
        }
        var trailing: Range<Int>?
        var labelled: [(label: String, range: Range<Int>)] = []
        let brace = skipBlanks(from: end)
        if brace < bytes.count, bytes[brace] == ASCII.openBrace, let close = closing(brace) {
            trailing = brace..<close
            end = close
            while true {
                let labelStart = skipBlanks(from: end)
                var labelEnd = labelStart
                while labelEnd < bytes.count, Self.isIdentifier(bytes[labelEnd]) { labelEnd += 1 }
                let colon = skipBlanks(from: labelEnd)
                guard labelEnd > labelStart, colon < bytes.count, bytes[colon] == ASCII.colon else { break }
                let open = skipBlanks(from: colon + 1)
                guard open < bytes.count, bytes[open] == ASCII.openBrace, let close = closing(open) else { break }
                labelled.append((text(labelStart..<labelEnd), open..<close))
                end = close
            }
        }
        return Call(start: offset, arguments: arguments, trailingClosure: trailing,
                    labelledClosures: labelled, end: end, name: name)
    }

    /// The modifiers chained onto the expression that ends at `offset`, in order. Read on the code
    /// one platform compiles (``compiled(for:)``), a chain split by `#if` holds only that platform's
    /// modifiers, and the blanked directive lines are stepped over as blank lines.
    func modifierChain(after offset: Int) -> [Call] {
        var chain: [Call] = []
        var index = offset
        while true {
            let dot = skipBlanks(from: index)
            guard dot + 1 < bytes.count, bytes[dot] == ASCII.dot,
                  Self.isIdentifier(bytes[dot + 1]) else { break }
            var nameEnd = dot + 1
            while nameEnd < bytes.count, Self.isIdentifier(bytes[nameEnd]) { nameEnd += 1 }
            guard let modifier = call(named: text(dot + 1..<nameEnd), at: dot + 1) else { break }
            chain.append(Call(start: dot, arguments: modifier.arguments,
                              trailingClosure: modifier.trailingClosure,
                              labelledClosures: modifier.labelledClosures,
                              end: modifier.end, name: modifier.name))
            index = modifier.end
        }
        return chain
    }

    /// Whether `modifier` is `.pickerStyle(.segmented)` (or `SegmentedPickerStyle()`).
    func isSegmentedStyle(_ modifier: Call) -> Bool {
        guard modifier.name == "pickerStyle", let arguments = modifier.arguments else { return false }
        let value = text(arguments)
        return value.contains(".segmented") || value.contains("SegmentedPickerStyle")
    }

    /// Whether `modifier` is `.labelStyle(.titleAndIcon)` (or `TitleAndIconLabelStyle()`).
    func isTitleAndIconStyle(_ modifier: Call) -> Bool {
        guard modifier.name == "labelStyle", let arguments = modifier.arguments else { return false }
        let value = text(arguments)
        return value.contains(".titleAndIcon") || value.contains("TitleAndIconLabelStyle")
    }

    /// Whether the argument list `arguments` opens with the label `label:`.
    func opensWithLabel(_ label: String, _ arguments: Range<Int>) -> Bool {
        let start = skipBlanks(from: arguments.lowerBound + 1)
        let end = start + label.utf8.count
        guard end <= arguments.upperBound, text(start..<end) == label else { return false }
        let colon = skipBlanks(from: end)
        return colon < arguments.upperBound && bytes[colon] == ASCII.colon
    }

    /// Whether the argument list `arguments` passes `label:` anywhere at its top level or below.
    func passesLabel(_ label: String, _ arguments: Range<Int>) -> Bool {
        occurrences(of: label, in: arguments).contains { offset in
            let colon = skipBlanks(from: offset + label.utf8.count)
            return colon < arguments.upperBound && bytes[colon] == ASCII.colon
        }
    }

    /// Whether `range` holds an `Image(systemName:)` call.
    func holdsSymbolImage(_ range: Range<Int>) -> Bool {
        occurrences(of: "Image", in: range).contains { offset in
            call(named: "Image", at: offset)?.arguments.map { opensWithLabel("systemName", $0) } == true
        }
    }

    /// Whether `range` holds a `Text`, `Label` or `Image` call, the calls a segment is read from.
    func holdsSegmentCall(_ range: Range<Int>) -> Bool {
        ["Text", "Label", "Image"].contains { name in
            occurrences(of: name, in: range).contains { offset in
                call(named: name, at: offset).map { $0.arguments != nil || $0.trailingClosure != nil } == true
            }
        }
    }

    /// The segments drawn from an SF Symbol inside a picker's content closure, in source order.
    /// A `Label` is drawn from one when it passes `systemImage:` or when any of its closures, in
    /// its argument list or trailing, holds `Image(systemName:)`. An `Image` inside a `Label`
    /// belongs to that `Label`, not to a second segment.
    func iconSegments(in content: Range<Int>) -> [SegmentedPickerAccessibilityAuditTests.IconSegment] {
        typealias Kind = SegmentedPickerAccessibilityAuditTests.SegmentKind
        let candidates = (occurrences(of: "Label", in: content).map { ($0, Kind.label) }
                          + occurrences(of: "Image", in: content).map { ($0, Kind.image) })
            .sorted { $0.0 < $1.0 }
        var claimed: [Range<Int>] = []
        var segments: [SegmentedPickerAccessibilityAuditTests.IconSegment] = []
        for (offset, kind) in candidates where !claimed.contains(where: { $0.contains(offset) }) {
            guard let segment = call(named: kind == .label ? "Label" : "Image", at: offset) else { continue }
            let drawnFromSymbol: Bool
            switch kind {
            case .label:
                claimed.append(offset..<segment.end)
                drawnFromSymbol = segment.arguments.map { passesLabel("systemImage", $0) } == true
                    || holdsSymbolImage(offset..<segment.end)
            case .image:
                drawnFromSymbol = segment.arguments.map { opensWithLabel("systemName", $0) } ?? false
            }
            guard drawnFromSymbol else { continue }
            segments.append(.init(
                kind: kind,
                line: line(at: offset),
                hasAccessibilityLabel: modifierChain(after: segment.end).contains { $0.name == "accessibilityLabel" }))
        }
        return segments
    }

    // MARK: References

    /// Why a `.pickerStyle(.segmented)` reached no Picker.
    struct TraceFailure: Error {
        /// The explanation the audit prints.
        let reason: String
    }

    /// The pickers a bare `name.pickerStyle(…)` reaches: those declared inside `var name: some View`
    /// in the same file. `modifier` is the offset of the modifier's `.`.
    func pickersReferenced(beforeModifierAt modifier: Int, among pickers: [Call]) -> Result<[Call], TraceFailure> {
        var nameEnd = modifier
        while nameEnd > 0, Self.isBlank(bytes[nameEnd - 1]) { nameEnd -= 1 }
        var nameStart = nameEnd
        while nameStart > 0, Self.isIdentifier(bytes[nameStart - 1]) { nameStart -= 1 }
        guard nameStart < nameEnd else {
            return .failure(TraceFailure(reason:
                "the style is on neither a Picker's own chain nor a property reference"))
        }
        let name = text(nameStart..<nameEnd)
        for declaration in occurrences(of: "var") {
            let nameAt = skipBlanks(from: declaration + 3)
            let nameEnd = nameAt + name.utf8.count
            guard nameEnd < bytes.count, text(nameAt..<nameEnd) == name,
                  !Self.isIdentifier(bytes[nameEnd]) else { continue }
            let colon = skipBlanks(from: nameEnd)
            guard colon < bytes.count, bytes[colon] == ASCII.colon,
                  let open = bytes[colon...].firstIndex(of: ASCII.openBrace),
                  text(colon + 1..<open).split(whereSeparator: \.isWhitespace).map(String.init)
                    == ["some", "View"],
                  let close = closing(open) else { continue }
            let declared = pickers.filter { (open..<close).contains($0.start) }
            return declared.isEmpty
                ? .failure(TraceFailure(reason: "`\(name)` declares no Picker"))
                : .success(declared)
        }
        return .failure(TraceFailure(reason: "no `var \(name): some View` in this file declares its Picker"))
    }
}
