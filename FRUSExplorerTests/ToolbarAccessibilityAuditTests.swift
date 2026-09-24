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
/// A segment built from `Label(…, systemImage:)` (or the `Label { … } icon: { Image(systemName:) }`
/// form) or from `Image(systemName:)` must carry `.accessibilityLabel` in its own modifier chain,
/// the shape `AnalyticsViewModePicker` uses. A `Label` segment is also named when the Picker's own
/// chain forces `.labelStyle(.titleAndIcon)`, so that the segment draws its words; the Search
/// window's reading switch does this. That style does not name an `Image` segment. An
/// `.accessibilityLabel` on the Picker itself names the control, not its segments, so it does not
/// count either.
///
/// ## What is in scope, and how it is found
/// A `Picker` is segmented when `.pickerStyle(.segmented)` is in its own trailing modifier chain.
/// The chain is read across `#if` / `#else` lines, because several pickers are segmented on one
/// platform only. A Picker is also segmented when a bare `name.pickerStyle(.segmented)` names a
/// `var name: some View` in the same file that declares it (`ArchivalAnalyticsView`'s
/// `modePicker`). Every match is on a call's balanced parentheses and braces, with comments and
/// string literals blanked first; nothing is matched on a window of lines. Every
/// `.pickerStyle(.segmented)` in the tree must reach a Picker by one of those two routes. A style
/// the scanner cannot trace, such as one set on a container, FAILS the suite rather than leaving
/// its segments unread.
///
/// Not in scope: a segment drawn by a helper function that the picker calls, and a segment drawn
/// from an asset image (`Image("name")`, `Label(_:image:)`). No segmented picker in the tree
/// builds either today.
///
/// ## What it cannot see
/// This reads source, so it gives the same result on every test destination, and it cannot prove
/// what a rendered segment announces. #1381's names were read on a Mac, which has no UI-test
/// target, so the proof that a fix took is the Word Cloud window read in Accessibility Inspector.
///
/// Version history:
///   1.0 — #1381: initial implementation
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
        var violations: [String] = []
        for file in try Self.tree.get() {
            for picker in file.scan.pickers {
                for segment in picker.unnamedSegments {
                    let shape = segment.kind == .label ? "Label(…, systemImage:)" : "Image(systemName:)"
                    violations.append(
                        "\(file.path):\(segment.line) — a \(shape) segment of the segmented Picker at "
                        + ":\(picker.line)")
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

            \(violations.joined(separator: "\n"))
            """))
    }

    @Test("SegmentedPickerAccessibility: every segmented style reaches the Picker it styles")
    func everySegmentedStyleReachesItsPicker() throws {
        let files = try Self.tree.get()
        let styles = files.reduce(0) { $0 + $1.scan.segmentedStyleCount }
        let pickers = files.reduce(0) { $0 + $1.scan.pickers.count }
        // Anti-vacuity: a moved directory or a scanner that stopped matching turns every other
        // assertion here green by finding nothing.
        #expect(files.count > 100, "Scanned only \(files.count) Swift files under \(Self.sourceRoot.path)")
        #expect(styles > 20, "Found only \(styles) `.pickerStyle(.segmented)` modifiers in code")
        #expect(pickers > 20, "Traced only \(pickers) segmented pickers")

        let untraced = files.flatMap { file in
            file.scan.untraced.map { "\(file.path):\($0.line) — \($0.reason)" }
        }
        #expect(untraced.isEmpty, Comment(rawValue: """
            Each `.pickerStyle(.segmented)` below reached no Picker, so the scan never read its \
            segments. Move the style onto the Picker's own chain, or teach the scanner the shape:

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
        var testDescription: String { file }
    }

    /// The five files that held a segmented picker with icon segments when #1381 was fixed, each
    /// read the way it is built. `AnalyticsChartChrome` and `CrossReferenceGraphView` are the
    /// `Image` + `.accessibilityLabel` shape. Of the five, only `SearchSheet`'s reading switch is
    /// named by `.labelStyle(.titleAndIcon)`, which makes it the tree's witness for that branch.
    /// `WordCloudView` and `DocumentTimelineView` are #1381's two sites. A new file with an icon
    /// picker is not added here automatically; ``everyIconSegmentNamesItself()`` still reads it.
    static let knownIconPickers: [KnownIconPicker] = [
        KnownIconPicker(file: "AnalyticsChartChrome.swift", kind: .image, segments: 2, namedByTitleAndIcon: false),
        KnownIconPicker(file: "CrossReferenceGraphView.swift", kind: .image, segments: 2, namedByTitleAndIcon: false),
        KnownIconPicker(file: "SearchSheet.swift", kind: .label, segments: 1, namedByTitleAndIcon: true),
        KnownIconPicker(file: "WordCloudView.swift", kind: .label, segments: 1, namedByTitleAndIcon: false),
        KnownIconPicker(file: "DocumentTimelineView.swift", kind: .label, segments: 2, namedByTitleAndIcon: false),
    ]

    @Test("SegmentedPickerAccessibility: the known icon pickers are read the way they are built",
          arguments: knownIconPickers)
    func knownIconPickerIsReadAsBuilt(_ known: KnownIconPicker) throws {
        let files = try Self.tree.get().filter { ($0.path as NSString).lastPathComponent == known.file }
        let iconPickers = files.flatMap { $0.scan.pickers }.filter { !$0.iconSegments.isEmpty }
        let picker = try #require(iconPickers.count == 1 ? iconPickers.first : nil,
            "\(known.file): expected one segmented picker with icon segments, found \(iconPickers.count)")
        #expect(picker.iconSegments.count == known.segments)
        #expect(picker.iconSegments.allSatisfy { $0.kind == known.kind })
        #expect(picker.forcesTitleAndIcon == known.namedByTitleAndIcon)
        #expect(picker.iconSegments.allSatisfy { $0.hasAccessibilityLabel != known.namedByTitleAndIcon },
                "\(known.file): segment labels \(picker.iconSegments.map(\.hasAccessibilityLabel))")
        #expect(picker.unnamedSegments.isEmpty,
                "\(known.file): unnamed segments at lines \(picker.unnamedSegments.map(\.line))")
    }

    @Test("SegmentedPickerAccessibility: the tree's by-reference picker is traced")
    func theTreesByReferencePickerIsTraced() throws {
        let files = try Self.tree.get().filter {
            ($0.path as NSString).lastPathComponent == "ArchivalAnalyticsView.swift"
        }
        let pickers = files.flatMap { $0.scan.pickers }
        #expect(pickers.count == 1 && pickers.allSatisfy(\.segmentedByReference),
                "ArchivalAnalyticsView's `modePicker.pickerStyle(.segmented)`: \(pickers.map(\.line))")
    }

    // MARK: - Scanner fixtures (one per rule the scan applies)

    /// Scans `source`, requiring it to trace every style and to hold exactly one segmented picker.
    private func onlyPicker(in source: String) throws -> SegmentedPicker {
        let scan = Self.scan(source)
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
        let scan = Self.scan(#"""
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

    @Test("Scanner: the chain is read across #if / #else lines")
    func theChainIsReadAcrossCompilerDirectives() throws {
        let picker = try onlyPicker(in: #"""
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
            """#)
        #expect(picker.forcesTitleAndIcon)
        #expect(picker.unnamedSegments.isEmpty)
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
        let scan = Self.scan(source)
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
    ]

    @Test("Scanner: a segmented style it cannot trace is reported, not skipped",
          arguments: untraceableShapes)
    func untraceableStyleIsReported(_ shape: UntraceableShape) {
        let scan = Self.scan(shape.source)
        #expect(scan.pickers.isEmpty)
        #expect(scan.untraced.map(\.line) == [shape.line], "reasons: \(scan.untraced.map(\.reason))")
    }

    // MARK: - Model

    /// What an icon segment is built from.
    enum SegmentKind: String, Sendable {
        /// `Label(…, systemImage:)`, or `Label { … } icon: { Image(systemName:) }`.
        case label
        /// A bare `Image(systemName:)`.
        case image
    }

    /// One segment of a segmented picker that is drawn from an SF Symbol.
    struct IconSegment: Sendable {
        /// What the segment is built from.
        let kind: SegmentKind
        /// 1-based line of the `Label` / `Image` call.
        let line: Int
        /// Whether the segment's own modifier chain carries `.accessibilityLabel`.
        let hasAccessibilityLabel: Bool
    }

    /// One segmented `Picker` declaration.
    struct SegmentedPicker: Sendable {
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

    /// A `.pickerStyle(.segmented)` whose Picker's segments the scanner could not read.
    struct UntracedStyle: Sendable {
        /// 1-based line of the modifier, or of the Picker when the Picker was found.
        let line: Int
        /// Why the segments were not read.
        let reason: String
    }

    /// What one file's scan found.
    struct FileScan: Sendable {
        /// Every segmented picker whose segments were read, in source order.
        let pickers: [SegmentedPicker]
        /// Every segmented style whose picker's segments were not read.
        let untraced: [UntracedStyle]
        /// How many `.pickerStyle(.segmented)` modifiers the file's code holds.
        let segmentedStyleCount: Int
    }

    // MARK: - Scanner

    /// Every Swift file under the app source root, scanned, with its path relative to the root.
    static func scanTree() throws -> [(path: String, scan: FileScan)] {
        try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { path in
                let source = try String(contentsOf: sourceRoot.appendingPathComponent(path), encoding: .utf8)
                return (path, scan(source))
            }
    }

    /// Scans one Swift source file for segmented pickers and their icon segments.
    static func scan(_ source: String) -> FileScan {
        let code = MaskedSwift(source)
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
            guard let content = picker.trailingClosure else {
                untraced.append(UntracedStyle(
                    line: code.line(at: picker.start),
                    reason: "the segmented Picker has no trailing content closure, so its segments were not read"))
                return
            }
            let chain = code.modifierChain(after: picker.end)
            pickers.append(SegmentedPicker(
                line: code.line(at: picker.start),
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
        return FileScan(pickers: pickers.sorted { $0.line < $1.line },
                        untraced: untraced.sorted { $0.line < $1.line },
                        segmentedStyleCount: styleSites.count)
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
/// newlines kept, plus the few parsing primitives the segmented-picker audit needs.
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

    /// Like ``skipBlanks(from:)``, but also steps over `#if`, `#elseif`, `#else` and `#endif`
    /// lines, so a modifier chain split by a platform branch is read whole.
    func skipTrivia(from offset: Int) -> Int {
        var index = skipBlanks(from: offset)
        while index < bytes.count, bytes[index] == ASCII.pound {
            var end = index + 1
            while end < bytes.count, Self.isIdentifier(bytes[end]) { end += 1 }
            guard ["if", "elseif", "else", "endif"].contains(text(index + 1..<end)) else { break }
            while end < bytes.count, bytes[end] != ASCII.newline { end += 1 }
            index = skipBlanks(from: end)
        }
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

    /// The modifiers chained onto the expression that ends at `offset`, in order.
    func modifierChain(after offset: Int) -> [Call] {
        var chain: [Call] = []
        var index = offset
        while true {
            let dot = skipTrivia(from: index)
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

    /// The segments drawn from an SF Symbol inside a picker's content closure, in source order.
    /// An `Image` inside a `Label`'s own icon closure belongs to that `Label`, not to a second segment.
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
                if let arguments = segment.arguments {
                    drawnFromSymbol = passesLabel("systemImage", arguments)
                } else {
                    drawnFromSymbol = segment.labelledClosures.contains { $0.label == "icon" && holdsSymbolImage($0.range) }
                }
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
