// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

/// Every full-screen tool the Browser presents as an iOS sheet must carry an explicit exit.
///
/// ## Why this is a source scan, and why that is defensible here
/// A `ToolbarItem` cannot be asserted from a unit test without standing up the whole view
/// hierarchy, and this repo's standard is that a test drives the real emitter rather than a mirror
/// of it. This test cannot meet that standard, so it aims at the next best thing: it does not
/// hardcode the views to check. It **reads `BrowserView`'s own `.sheet` presentations** and
/// requires an exit of whatever it finds there. A new analytics sheet added without a Done button
/// therefore fails this test on the commit that adds it, which is the only property that makes a
/// scan worth having.
///
/// ## What went wrong without it
/// Three of the six shipped without one — `PersonAnalyticsView`, `CrossReferenceAnalyticsView` and
/// `SemanticAnalyticsView` — while `AnalyticsView`, `ChronologyView` and the word cloud all had one
/// from the start. Nothing distinguished the two groups; the button was simply forgotten three
/// times over, which is what an invariant is for. The semantic map was the sharpest case: its
/// canvas carries a `DragGesture(minimumDistance: 1)` for panning, so the interactive swipe-down
/// never reaches the sheet from most of its own surface.
///
/// Version history:
///   1.0 — CW-12: created with the three missing exits
///   1.1 — #1051 B-7: the scanner also matches `.sheet(item:)` — the semantic-map sheet
///         moved to the item form (the #862 sibling-state fix) and vanished from the scan
@Suite("Sheet exits")
struct SheetExitTests {

    /// The repository root, found by walking up from this file.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
    }

    /// Reads a source file under the app target.
    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// The root view type of every `.sheet(isPresented:)` and `.sheet(item:)` in `BrowserView`.
    ///
    /// Deliberately parsed rather than listed: a hardcoded list would pass forever after someone
    /// adds the seventh sheet, which is exactly the failure this suite exists to catch. Both
    /// presentation spellings are matched because #1051 B-7 converted the semantic-map sheet to
    /// `item:` (the #862 sibling-state fix) — a scanner pinned to one spelling silently dropped
    /// that sheet from every assertion below.
    private static func browserSheetViewTypes() throws -> [String] {
        let browser = try source("FRUSExplorer/Browser/BrowserView.swift")
        let lines = browser.components(separatedBy: .newlines)
        var found: [String] = []
        for (index, line) in lines.enumerated()
        where line.contains(".sheet(isPresented:") || line.contains(".sheet(item:") {
            // The presented view is the first type-like call in the closure. Comment lines are
            // skipped: three of these sheets open with a paragraph of rationale before the view.
            for candidate in lines[(index + 1)..<min(index + 12, lines.count)] {
                let trimmed = candidate.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                guard let name = typeName(startingLine: trimmed) else { continue }
                found.append(name)
                break
            }
        }
        return found
    }

    /// The leading `SomeView(` of a line, if it has one.
    private static func typeName(startingLine line: String) -> String? {
        let name = line.prefix { $0.isLetter || $0.isNumber }
        guard let first = name.first, first.isUppercase,
              line.dropFirst(name.count).hasPrefix("("),
              name.hasSuffix("View") else { return nil }
        return String(name)
    }

    /// Every source file in the app target, by type name.
    private static func fileDeclaring(_ typeName: String) throws -> String? {
        let appRoot = repoRoot.appending(path: "FRUSExplorer")
        guard let walker = FileManager.default.enumerator(at: appRoot,
                                                          includingPropertiesForKeys: nil) else {
            return nil
        }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("struct \(typeName): View") { return text }
        }
        return nil
    }

    @Test("BrowserView's sheets are found at all")
    func sheetsAreDiscovered() throws {
        let types = try Self.browserSheetViewTypes()
        // The scan finding nothing would make every assertion below vacuously true — the classic
        // way a source-scanning test goes green while measuring nothing.
        #expect(types.count >= 5, "expected the analytics sheets, found \(types)")
        #expect(types.contains("PersonAnalyticsView"))
        #expect(types.contains("CrossReferenceAnalyticsView"))
        #expect(types.contains("SemanticAnalyticsView"))
    }

    @Test("every Browser sheet ships an iOS exit")
    func everySheetHasAnExit() throws {
        for typeName in try Self.browserSheetViewTypes() {
            guard let text = try Self.fileDeclaring(typeName) else {
                Issue.record("could not locate the source of \(typeName)")
                continue
            }
            #expect(text.contains("confirmationAction"),
                    "\(typeName) is presented as an iOS sheet but ships no Done button — its only exit is the interactive swipe-down, which is undiscoverable, unavailable to switch control, and (on the semantic map) swallowed by the canvas's own drag gesture.")
        }
    }
}
