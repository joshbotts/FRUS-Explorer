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

// MARK: - RefreshBypassAuditTests

/// That the macOS Refresh button cannot re-open the hole #677 closed (#680).
///
/// ## The bug
/// `load()` pre-fills `manualQuery` with the bare lot number for a `.lotFile` note. The toolbar
/// Refresh button — tooltip *"Re-run the current NARA Catalog search"* — called
/// `runManualSearch()`, which sends that lot number to the **v1** endpoint with `rows=1`, no
/// record-group filter and no acceptance test, overwriting the same `catalogResults` array that
/// Copy and Export serialize from. One click on a document citing `Lot 90 D 234` replaced a
/// correctly refused resolution with the Census Bureau record.
///
/// These are source-scan assertions: the behaviour is a SwiftUI button action calling a
/// network method, which no unit test can reach. What they can prove is the wiring — that
/// Refresh no longer routes to the free-text path, and that manual results are still marked.
///
/// Version history:
///   1.0 — Session 2026-08-05: #680
@Suite("Refresh bypass")
struct RefreshBypassAuditTests {

    private static var source: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
            let text = try String(
                contentsOf: root.appending(path: "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"),
                encoding: .utf8)
            #expect(text.count > 5_000, "MacSourceExplorerView.swift is implausibly small")
            return text
        }
    }

    /// `text` with full-line `//` comments removed. Necessary here for the same reason it was
    /// in the curated-lot audit: this file's own comment explains that Refresh *used to* call
    /// `runManualSearch()`, and a naive scan reads that as the call still being present.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The body of the toolbar item whose label is Refresh, comments stripped.
    private static func refreshItem(_ src: String) throws -> String {
        let marker = "source.explorer.toolbar.refresh\""
        let idx = try #require(src.range(of: marker), "Refresh toolbar item not found")
        // Walk back to the enclosing ToolbarItem so the action closure is inside the slice.
        let head = src[..<idx.lowerBound]
        let start = try #require(head.range(of: "ToolbarItem {", options: .backwards))
        return code(String(src[start.lowerBound..<idx.upperBound]))
    }

    @Test("Refresh re-runs the automatic lookup, not the free-text search")
    func refreshDoesNotCallManualSearch() throws {
        let item = try Self.refreshItem(try Self.source)
        #expect(!item.contains("runManualSearch()"),
                "Refresh routes back through the unguarded free-text query — the #680 bypass")
        #expect(item.contains("await load()"),
                "Refresh does not re-run the acceptance-tested lookup")
    }

    @Test("Manual search still marks its results unverified")
    func manualSearchMarksResults() throws {
        let src = try Self.source
        #expect(src.contains("fetchResults(verified: false)"),
                "runManualSearch no longer flags its results as unverified")
        // Declaration-vs-use, again: a first draft asserted `src.contains(...)`, which a
        // rename to `unverifiedResultBannerUnused` satisfies as a substring while the banner
        // is no longer rendered anywhere. Drop the declaration line before looking.
        let used = Self.code(src)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains("var unverifiedResultBanner") }
            .joined(separator: "\n")
        #expect(used.contains("unverifiedResultBanner"),
                "the banner is declared but never rendered — no on-screen marker distinguishes a manual result")
        #expect(!used.contains("unverifiedResultBannerUnused"),
                "the banner identifier was renamed; the render site is stale")
    }

    @Test("A copied or exported manual result carries the caveat in its text")
    func exportCarriesTheCaveat() throws {
        let src = try Self.source
        // The chip does not travel into a research note; the text has to say it.
        guard let fn = src.range(of: "private func naraExportText(") else {
            Issue.record("naraExportText not found"); return
        }
        let body = String(src[fn.upperBound...].prefix(900))
        #expect(body.contains("resultsAreVerified"),
                "naraExportText does not mention provenance — an unverified result exports as if checked")
    }
}
