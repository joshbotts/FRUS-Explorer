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

// MARK: - CatalogQueryEvidenceTests

/// Pins which live catalogue results may be presented as the answer (#681).
///
/// Exactly one of the three queries checks its results against the thing that was asked for.
/// The other two were rendered identically to it — same heading, same rows, same button — and
/// this is the classification that stops them.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681
///   1.1 — Session 2026-08-06: #675/#680, the caveat that travels into a Copy or an Export
@Suite("CatalogQueryEvidence — what a live result set proves")
struct CatalogQueryEvidenceTests {

    /// The lot route is the only verified one, and it is verified because
    /// `resolveLotFileVariants` puts every candidate — including the free-text fallback's —
    /// through `LotResolutionAcceptance`.
    @Test("Only a control-number lookup counts as verified")
    func onlyLotLookupIsVerified() {
        let lot = ParsedSourceNote.lotFile(recordGroup: "RG-59", lotNumber: "74 D 476", fileIdentifier: nil)
        #expect(CatalogQueryEvidence.forNote(lot) == .controlNumberVerified)
        #expect(CatalogQueryEvidence.forNote(lot)?.isVerified == true)
        #expect(CatalogQueryEvidence.forNote(lot)?.caveat == nil)
        #expect(CatalogQueryEvidence.forNote(lot)?.sectionTitle == "NARA Catalog")
    }

    /// A record-group citation naming a lot is verified **because #704 reroutes it** to the
    /// guarded path. If that reroute is ever reverted this classification becomes a lie, which
    /// is why it is asserted here rather than assumed.
    @Test("A record-group citation is verified only when it names a lot")
    func recordGroupIsVerifiedOnlyWithALot() {
        let withLot = ParsedSourceNote.naraCollection(
            recordGroup: "59", series: "Office of the Secretariat Staff",
            lotFile: "81 D 113", box: nil)
        #expect(CatalogQueryEvidence.forNote(withLot) == .controlNumberVerified)

        let withoutLot = ParsedSourceNote.naraCollection(
            recordGroup: "84", series: "Saigon Embassy Files", lotFile: nil, box: nil)
        #expect(CatalogQueryEvidence.forNote(withoutLot) == .recordGroupOnly(recordGroup: "84"))
        #expect(CatalogQueryEvidence.forNote(withoutLot)?.isVerified == false)
        // The caveat has to name what *was* constrained, or it reads as "this is worthless".
        #expect(CatalogQueryEvidence.forNote(withoutLot)?.caveat?.contains("84") == true)
    }

    /// The weakest query in the app, and the one 28,456 documents take.
    @Test("A presidential-library query is never verified")
    func libraryQueryIsNeverVerified() {
        let library = ParsedSourceNote.presidentialLibrary(
            library: "Kennedy Library", collection: "National Security Files", fileIdentifier: nil)
        let evidence = CatalogQueryEvidence.forNote(library)
        #expect(evidence == .collectionNameOnly)
        #expect(evidence?.isVerified == false)
        #expect(evidence?.sectionTitle == "Candidate NARA Records")
        #expect(evidence?.caveat != nil)
    }

    /// Every unverified branch must carry a caveat, and the verified one must not — a caveat on
    /// a verified result would train the reader to ignore caveats.
    @Test("Caveat presence follows verification, both ways")
    func caveatFollowsVerification() {
        for evidence: CatalogQueryEvidence in [.controlNumberVerified,
                                               .recordGroupOnly(recordGroup: "59"),
                                               .collectionNameOnly] {
            #expect((evidence.caveat == nil) == evidence.isVerified,
                    Comment(rawValue: "\(evidence) caveat and verification disagree"))
            #expect(!evidence.sectionTitle.isEmpty)
        }
        #expect(CatalogQueryEvidence.recordGroupOnly(recordGroup: "59").sectionTitle
                == CatalogQueryEvidence.collectionNameOnly.sectionTitle,
                "both unverified branches are headed the same way")
    }

    /// A citation that takes no catalogue query classifies as nothing, rather than defaulting
    /// to verified and captioning a section that never renders.
    @Test("A note with no catalogue query has no evidence")
    func noQueryNoEvidence() {
        #expect(CatalogQueryEvidence.forNote(.unrecognized(rawText: "…")) == nil)
        #expect(CatalogQueryEvidence.forNote(.previouslyPublished(citation: "FRUS 1958, vol. I")) == nil)
    }
}

// MARK: - CatalogQueryEvidenceWiringTests

/// Source audits that both Source Explorer views apply the grammar (#681).
///
/// The behaviour lives in a SwiftUI `body` fed by an `async` query needing a live client and an
/// API key, so no unit test drives it. What an audit catches is the failure this codebase has
/// actually shipped: one platform wired and the other not.
@Suite("CatalogQueryEvidence — platform wiring")
struct CatalogQueryEvidenceWiringTests {

    private static let views = ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                                "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"]

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Both views classify the query and show the caveat")
    func bothViewsAdoptTheGrammar() throws {
        for path in Self.views {
            let code = try source(path)
            #expect(code.contains("CatalogQueryEvidence.forNote("),
                    Comment(rawValue: "\(path) never classifies the query it is about to issue"))
            #expect(code.contains("catalogEvidence?.caveat") || code.contains("catalogEvidence?.sectionTitle"),
                    Comment(rawValue: "\(path) classifies the query and then ignores the answer"))
        }
    }

    /// The chip is the visible half. Without it a reader scanning rows sees no difference
    /// between a verified resolution and an unconstrained free-text hit.
    @Test("Both views chip an unverified result row")
    func bothViewsChipUnverifiedRows() throws {
        for path in Self.views {
            let code = try source(path)
            #expect(code.contains("if !isVerified { ConfidenceChip("),
                    Comment(rawValue: "\(path) renders unverified rows with no confidence chip"))
        }
    }

    // MARK: - The caveat that leaves the app (#675 / #680)

    /// A Copy or an Export lands in a research note months later, headed "NARA Catalog
    /// Record". The chip does not travel with it, so the hedge has to.
    @Test("An automatic query that constrained on nothing exports a caveat")
    func unconstrainedAutomaticResultCarriesACaveat() throws {
        let recordGroup = try #require(
            CatalogQueryEvidence.exportCaveat(evidence: .recordGroupOnly(recordGroup: "59"),
                                              isManualSearch: false),
            "a record-group-only result must not export as a bare catalog record")
        #expect(recordGroup.contains("59"), "the caveat must name what the query constrained")

        #expect(CatalogQueryEvidence.exportCaveat(evidence: .collectionNameOnly,
                                                  isManualSearch: false) != nil,
                "a collection-name-only result must not export as a bare catalog record")
    }

    /// The one route whose every row was put through `LotResolutionAcceptance`. Caveating it
    /// would be crying wolf on the only results that earned the heading.
    @Test("A control-number-verified result exports without a caveat")
    func verifiedResultCarriesNoCaveat() {
        #expect(CatalogQueryEvidence.exportCaveat(evidence: .controlNumberVerified,
                                                  isManualSearch: false) == nil)
    }

    /// The manual field is the actual producer of those rows, so its caveat wins. Naming the
    /// automatic query's constraint would describe a query the rows did not come from — and
    /// the manual query has no record-group filter at all.
    @Test("A manual search wins over the automatic query's caveat")
    func manualSearchCaveatTakesPrecedence() throws {
        let manual = try #require(
            CatalogQueryEvidence.exportCaveat(evidence: .recordGroupOnly(recordGroup: "59"),
                                              isManualSearch: true))
        #expect(manual.contains("manual"), "expected the manual-search wording, got: \(manual)")
        #expect(!manual.contains("within record group"),
                "the manual rows did not come from the record-group query")

        // Still caveated when no automatic query ran at all — the commonest manual case.
        #expect(CatalogQueryEvidence.exportCaveat(evidence: nil, isManualSearch: true) != nil)
    }

    /// The regression this pair of tests exists to stop.
    ///
    /// #680 added the export caveat gated on "did this come from the manual field?", and #681
    /// then added a *second* way for an automatic result to be unverified. The export gate did
    /// not learn about it, so 26,667 documents' worth of unconstrained keyword hits copied
    /// clean. The export must ask the same question the rows are chipped from.
    @Test("The macOS export asks the same question the rows are chipped from")
    func exportGateMatchesTheRowGate() throws {
        let code = try source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift")
        #expect(code.contains("CatalogQueryEvidence.exportCaveat("),
                """
                MacSourceExplorerView builds its export caveat by hand instead of asking \
                CatalogQueryEvidence. That is how the record-group-only branch was missed: the \
                screen chipped it and the clipboard did not.
                """)
        // The old gate, which could only see the manual-search half.
        #expect(!code.contains("if !resultsAreVerified {\n            lines.append"),
                "the export is gated on resultsAreVerified alone — it cannot see #681's branch")
    }
}
