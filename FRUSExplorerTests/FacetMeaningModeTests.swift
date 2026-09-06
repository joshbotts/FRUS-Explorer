// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - FacetMeaningModeTests

/// Facets are counted from an FTS5 MATCH, and a meaning search does not have one (#1193).
///
/// **The bug was not a mismatch between two counts — it was two counts over two different sets of
/// documents.** `FacetPanelController.load` asks `SearchService.matchExpressions(for:)` for a
/// keyword expression and aggregates the whole index against it. In meaning mode the results on
/// screen are the ranked nearest neighbours, so every facet count described the *keyword*
/// interpretation of the query text instead: reported as a list showing 100 beside a panel
/// counting 471. A reader narrowing by one of those rows believed they were narrowing their
/// semantic results.
///
/// The app already draws this line one surface over — `SearchSheet` swaps the MATCH inspector for
/// the Meaning strip because "no FTS expression exists". This is the same fact reaching the panel.
///
/// The issue reported **two** numbers, so this suite covers both: the facet panel that counted a
/// different set, and the header that said "total unavailable" — which asserts a total exists and
/// could not be got, when a similarity ranking has none to begin with.
///
/// Version history:
///   1.0 — #1193: initial implementation
@Suite("Meaning-mode result reporting")
struct FacetMeaningModeTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The file with its `//` comment lines removed, so a scan reads code and not documentation.
    private func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// **Both hosts must tell the panel which route ran.** They are hand-maintained twins, and a
    /// gate honoured by one is a panel that lies on the other platform.
    @Test("Both search hosts tell the facet panel when the search ran by meaning")
    func bothHostsPassTheRoute() throws {
        var checked = 0
        for path in ["FRUSExplorer/Search/SearchView.swift",
                     "FRUSExplorer/App/SearchSheet.swift"] {
            let file = try code(path)
            guard let call = file.range(of: "FacetPanelView(") else {
                Issue.record(Comment(rawValue: "\(path) no longer hosts the facet panel"))
                continue
            }
            let arguments = String(file[call.lowerBound...].prefix(1200))
            #expect(arguments.contains("isMeaningSearch:"),
                    Comment(rawValue: "\(path) does not tell the panel which route ran"))
            checked += 1
        }
        #expect(checked == 2, "the host sweep ran over \(checked) hosts")
    }

    /// The panel must both *say* why there are no facets and *compute* none.
    ///
    /// Computing them anyway would leave the keyword aggregation running behind the note — wasted
    /// work, and rows that would reappear the moment the gate was loosened.
    @Test("The panel explains itself and requests nothing in meaning mode")
    func panelGatesBothDisplayAndComputation() throws {
        let file = try code("FRUSExplorer/Search/FacetPanelView.swift")
        #expect(file.contains("if isMeaningSearch {"),
                "the panel does not branch on the route")
        #expect(file.contains("isMeaningSearch ? [] : controller.sectionsNeedingLoad"),
                "the panel still requests keyword aggregations for a meaning search")
    }

    /// The panel's own explanation must name the mechanism, because the remedy follows from it:
    /// a reader who knows facets come from the keyword index knows switching modes restores them.
    @Test("The explanation names the keyword index and the way back")
    func explanationNamesMechanismAndRemedy() throws {
        let file = try source("FRUSExplorer/Search/FacetPanelView.swift")
        for key in ["facets.meaning.title", "facets.meaning.detail", "facets.meaning.remedy"] {
            #expect(file.contains(key), Comment(rawValue: "\(key) is missing from the panel"))
        }
        #expect(file.contains("counted from the keyword index"),
                "the explanation does not say where facets come from")
    }

    /// **macOS renders its own header**, so the shared clause has to actually reach it — otherwise
    /// the two platforms word one fact differently, which is what `ResultSetScope` exists to stop.
    @Test("The macOS header renders the shared closest-matches clause")
    func macHeaderUsesTheSharedClause() throws {
        let file = try code("FRUSExplorer/App/SearchSheet.swift")
        guard let label = file.range(of: "private var resultCountLabel: some View {") else {
            Issue.record("resultCountLabel is gone — the macOS header moved")
            return
        }
        let body = String(file[label.lowerBound...].prefix(2600))
        // **Two branches, not one, and counting them is the point.** The keyword grammar has a
        // short form and a page-range form; the meaning grammar needs both, or a result set larger
        // than one page falls through to "total unavailable" while a smaller one reads correctly.
        // A first version of this test asserted only that the two strings appeared *somewhere* in
        // the label, and a mutation disabling the short-form branch passed it.
        let branches = body.components(separatedBy: "resultSetScope.isMeaningSearch").count - 1
        #expect(branches == 2,
                Comment(rawValue: "the macOS header branches on the route \(branches) times, not twice — a meaning search of more than one page would fall back to the keyword grammar"))
        #expect(body.components(separatedBy: "resultSetScope.closestMatchesClause").count - 1 == 2,
                "both meaning branches must render the shared clause rather than wording it again")
    }

    /// The load path is what made the counts wrong, and it is still keyword-only — so the gate
    /// above is load-bearing rather than belt-and-braces.
    @Test("The facet load path is still a keyword aggregation")
    func loadPathRemainsKeywordOnly() throws {
        let file = try code("FRUSExplorer/Search/FacetPanelView.swift")
        #expect(file.contains("service.matchExpressions(for: parameters)"),
                """
                The facet load no longer builds an FTS expression. If it learned to aggregate a \
                semantic result set, the meaning-mode gate is no longer needed and this suite \
                should be replaced rather than adjusted.
                """)
    }
}
