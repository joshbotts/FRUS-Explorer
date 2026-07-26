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
