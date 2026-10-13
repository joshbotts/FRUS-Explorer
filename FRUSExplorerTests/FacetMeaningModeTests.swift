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
/// **#1220 fixed this by withholding the facets; this suite now guards the real fix.** The panel
/// computes them over the semantic result keys instead — `IndexingPipeline.resultSetFacets` takes a
/// `documentKeys:` set and materialises `temp.facet_mset` from it, so every section runs the same
/// SQL it always did. `ResultSetFacetsTests.keySetFacetsEqualMatchFacets` pins the two routes
/// against each other; what is left here is the wiring that decides which route runs.
///
/// The issue reported **two** numbers, so this suite covers both: the facet panel that counted a
/// different set, and the header that said "total unavailable" — which asserts a total exists and
/// could not be got, when a similarity ranking has none to begin with.
///
/// Version history:
///   1.0 — #1193: initial implementation
///   1.1 — FRUS Explorer Light: the route is chosen in `SearchService.resultSetFacets`, which the
///          controller hands its keys, so the expression check reads the service
@Suite("Meaning-mode result reporting")
struct FacetMeaningModeTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// What each host calls its view model.
    private static func owner(_ path: String) -> String {
        path.hasSuffix("SearchSheet.swift") ? "searchVM" : "vm"
    }

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
    @Test("Both search hosts give the facet panel its count and its wording from the view model")
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
            // #1577 lane 2: both are the view model's, which answers from the route recorded with the
            // rows. The host took them from the picker, which names the engine of the NEXT search:
            // between a switch and the new rows it described keyword rows as a Meaning list, and a
            // Meaning list as a keyword match. The host passes them through and decides nothing, so
            // that the rule is in a place a test can drive (`SearchResultRouteTests`).
            let owner = Self.owner(path)
            #expect(arguments.contains("matchCount: \(owner).facetMatchCount,"),
                    Comment(rawValue: "\(path) works out the panel's count itself"))
            #expect(arguments.contains("isMeaningSearch: \(owner).resultsAreSemantic,"),
                    Comment(rawValue: "\(path) words the panel by something other than the rows' route"))
            #expect(!arguments.contains("searchMode"),
                    Comment(rawValue: "\(path) describes the facet panel's rows by the picker"))
            #expect(!arguments.contains("executedRoute"),
                    Comment(rawValue: "\(path) asks the route itself, where the view model's members are the rule"))
            checked += 1
        }
        #expect(checked == 2, "the host sweep ran over \(checked) hosts")
    }

    /// **Both hosts must hand over the keys**, or the panel falls back to the keyword expression
    /// and the counts describe a different set again — the #1193 defect, returning by omission.
    @Test("Both search hosts give the panel the view model's keys, and choose none themselves")
    func bothHostsPassTheKeys() throws {
        var checked = 0
        for path in ["FRUSExplorer/Search/SearchView.swift",
                     "FRUSExplorer/App/SearchSheet.swift"] {
            let file = try code(path)
            guard let call = file.range(of: "facetController.load(") else {
                Issue.record(Comment(rawValue: "\(path) no longer loads facets"))
                continue
            }
            let arguments = String(file[call.lowerBound...].prefix(700))
            #expect(arguments.contains("documentKeys:"),
                    Comment(rawValue: "\(path) does not hand the panel its result keys"))
            // The whole argument, to its closing parenthesis: a host that chose between the keys and
            // `nil` itself could choose the wrong way round, and nothing on iOS would run it.
            #expect(arguments.contains("documentKeys: \(Self.owner(path)).facetDocumentKeys)"),
                    Comment(rawValue: "\(path) does not pass the view model's keys through as they are"))
            #expect(!arguments.contains("searchMode"),
                    Comment(rawValue: "\(path) hands over keys by the picker, which names the next search's engine"))
            checked += 1
        }
        #expect(checked == 2, "the host sweep ran over \(checked) hosts")
    }

    /// The controller must not ask for a match expression when it has keys.
    ///
    /// Computing one and discarding it would be waste; computing one and *using* it is exactly how
    /// the keyword interpretation leaked into these counts in the first place. The controller hands
    /// its keys to the search service, which chooses the route, so the web edition's facets take
    /// it too; `ResultSetFacetsTests.serviceFacetsDescribeTheKeys` drives the service's choice.
    @Test("The controller skips the match expression when it has keys")
    func controllerSkipsTheExpressionForKeys() throws {
        let controller = try code("FRUSExplorer/Search/FacetPanelView.swift")
        #expect(controller.contains("service.resultSetFacets("),
                "the controller computes a section without the search service, which chooses the route")
        #expect(controller.contains("documentKeys: documentKeys"),
                "the controller does not forward the keys to the search service")
        let service = try code("FRUSCoreKit/Search/SearchService.swift")
        #expect(service.contains("documentKeys == nil"),
                "the search service builds a match expression regardless of route")
        #expect(service.contains("documentKeys: documentKeys"),
                "the search service does not forward the keys to the pipeline")
    }

    /// A meaning search's facets describe the results themselves, so the panel must not repeat the
    /// keyword promise that they read past the list into the whole match.
    @Test("The preamble says what the counts actually cover in each mode")
    func preambleSaysWhatIsCounted() throws {
        let file = try source("FRUSExplorer/Search/FacetPanelView.swift")
        for key in ["facets.preamble.meaning %@", "facets.preamble.detail.meaning",
                    "facets.preamble", "facets.preamble.detail"] {
            #expect(file.contains(key), Comment(rawValue: "\(key) is missing from the preamble"))
        }
        #expect(file.contains("Counted over the results themselves"),
                "the meaning preamble still claims to read the whole match")
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

}
