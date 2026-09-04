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

// MARK: - CorrectedClaimsTests

/// User-facing sentences that described behaviour the app does not have.
///
/// Each test below pins one corrected claim AND asserts the false wording is gone, because the
/// failure mode is a revert rather than a typo: every one of these sentences was true when it was
/// written and was falsified by a later change nobody traced back to the copy.
///
/// The negative assertions are scoped to CODE, not to the whole file: the corrections carry
/// comments quoting the wording they replaced, and a file-wide scan would match the quotation —
/// the trap this repo's source-scan tests have hit three phases running.
///
/// Version history:
///   1.0 — B-6 + the honesty batch: initial implementation
@Suite("Claims the code stopped supporting")
struct CorrectedClaimsTests {

    /// Strips `//` comment lines so a negative scan cannot match a quotation of the old wording.
    private static func code(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - The storage-hub footer

    /// It promised that every changed document "opens with a banner". Since R-5 P3b-1 a VANISHED
    /// document opens the REVIEW SHEET — no document view can load a document the update removed —
    /// and `ResearchDocumentAggregation.rowDestination` is where that is decided. The same section
    /// prints a "no longer in the volume" count two rows above the footer, so the old text
    /// contradicted its own screen.
    @Test("The After an Update footer no longer promises a banner for every changed document")
    func footerDoesNotPromiseABannerForVanishedDocuments() throws {
        let source = try Self.code("FRUSExplorer/Settings/VolumeUpdateReviewSection.swift")
        #expect(source.contains("settings.updateReview.footer.v2"))
        #expect(source.contains("settings.updateReview.footer.mac.v2"))
        #expect(!source.contains("\"settings.updateReview.footer\""),
                "the shipped key must not be reused for reworded text")
        #expect(!source.contains("and each opens with a banner"),
                "false since P3b-1 for a vanished document")
        // Both wordings must name the sheet as the exception, or the correction is cosmetic.
        #expect(source.contains("opens the review sheet, the only surface that can still reach it"))
        // And the rule they now describe must be the one that actually ships.
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: false) == .document)
    }

    /// Research is a TAB on iOS and a WINDOW on macOS, and this one section is mounted by both
    /// hubs. One key with one noun was wrong on one platform every time it rendered.
    @Test("The footer names the right noun on each platform")
    func footerNamesTheRightSurface() throws {
        let source = try Self.code("FRUSExplorer/Settings/VolumeUpdateReviewSection.swift")
        // SCOPED to the footer closure. The file carries an unrelated `#if os(macOS)` at property
        // scope (guarding `@Environment(\.openWindow)`), so a file-wide scan for the directive is
        // satisfied by that one — a mutation flipping the FOOTER's gate to `os(iOS)` survived it.
        let footerStart = try #require(source.range(of: "} footer: {")).upperBound
        let footer = String(source[footerStart...])
        let macGate = try #require(footer.range(of: "#if os(macOS)")).upperBound
        let macArm = try #require(footer.range(of: "#else", range: macGate..<footer.endIndex)).lowerBound
        let macBranch = String(footer[macGate..<macArm])
        #expect(macBranch.contains("settings.updateReview.footer.mac.v2"))
        #expect(macBranch.contains("The Research window lists the changed ones"),
                "the window wording must be the one macOS compiles")
        let iosBranch = String(footer[macArm...].prefix(while: { $0 != "\u{23}" || true }))
        #expect(iosBranch.contains("The Research tab lists the changed ones"),
                "and the tab wording the one iOS compiles")
        #expect(!iosBranch.contains("The Research window lists"))
    }

    /// P3b-4 made a frozen quotation count toward the changed-document set via
    /// `countsAsAnnotation`; the footer's list of what makes a document "yours" never gained it.
    @Test("The footer's list of what counts matches countsAsAnnotation")
    func footerListsQuotations() throws {
        let source = try Self.code("FRUSExplorer/Settings/VolumeUpdateReviewSection.swift")
        #expect(source.contains("highlight, quotation, collection entry"))
        #expect(ResearchDocumentAggregation.countsAsAnnotation(CollectionEntryKind.excerpt.rawValue),
                "the string is only true while an excerpt still counts")
    }

    // MARK: - The catalogue refresh

    /// Both platforms promised that refreshing surfaces newly published volumes. It cannot: every
    /// download surface reads `diffResult.known`, which filters the BUNDLED manifest and so can
    /// only shrink. Decision D-1 left that gap silent; the copy went on claiming it was closed.
    @Test("Refresh Available List no longer promises newly published volumes")
    func catalogRefreshDoesNotPromiseNewVolumes() throws {
        for file in ["FRUSExplorer/Settings/VolumesStorageHubView.swift",
                     "FRUSExplorer/Settings/MacVolumesStorageHub.swift"] {
            let source = try Self.code(file)
            #expect(!source.contains("Look for newly published volumes"), "\(file)")
            #expect(!source.contains("so newly published volumes appear in the download browser"),
                    "\(file)")
        }
        #expect(try Self.code("FRUSExplorer/Settings/VolumesStorageHubView.swift")
            .contains("settings.hub.catalog.detail.v2"))
        #expect(try Self.code("FRUSExplorer/Settings/MacVolumesStorageHub.swift")
            .contains("settings.hub.catalog.help.v2"))
    }

    // MARK: - The facet enumerations

    /// Three strings enumerate what the facets panel breaks a result set down by. The panel has
    /// SIX sections and renders them unconditionally on both platforms; the tip named three and
    /// the two help strings named five, all of them missing Subjects, which arrived with #308.
    @Test("Every facet enumeration names all six sections")
    func facetEnumerationsAreComplete() throws {
        #expect(FacetSection.allCases.count == 6, "the strings below are written against six")
        let sites = [
            ("FRUSExplorer/App/DiscoveryTips.swift", "tip.examine.message.v2"),
            ("FRUSExplorer/Search/SearchView.swift", "search.mode.help.v2"),
            ("FRUSExplorer/App/SearchSheet.swift", "search.facets.on.help.v3"),
        ]
        for (file, key) in sites {
            let source = try Self.code(file)
            #expect(source.contains(key), "\(file) must use the new key")
            #expect(source.contains("document type, archival provenance and subject"),
                    "\(file) must name the full set")
            #expect(!source.contains("person, type and provenance"), "\(file) stale enumeration")
        }
        #expect(!(try Self.code("FRUSExplorer/App/DiscoveryTips.swift"))
            .contains("down by year, volume and person"))
    }

    /// The indexing education said "Any of those facets becomes a filter with one tap" over a list
    /// that included archival provenance — which `FacetNarrowing.isNarrowable` excludes, and which
    /// the panel itself discloses in place as descriptive only.
    @Test("The education text does not claim provenance narrows")
    func educationDoesNotClaimProvenanceNarrows() throws {
        let source = try Self.code("FRUSExplorer/Onboarding/IndexingEducationView.swift")
        #expect(!source.contains("Any of those facets becomes a filter with one tap"))
        #expect(source.contains("archival provenance is the exception — it is descriptive only"))
        // The correction must not cost the guide its only mention of the subjects facet —
        // `ResearchGuideCoverageTests` pins that, and the first draft of this fix dropped it.
        #expect(source.contains("the subjects facet narrows a result set to a single topic area"))
        #expect(!FacetNarrowing.isNarrowable(.provenance), "the claim is only false while this holds")
        #expect(FacetNarrowing.isNarrowable(.years))
    }
}
