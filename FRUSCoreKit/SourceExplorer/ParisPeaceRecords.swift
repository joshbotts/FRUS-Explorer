// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ParisPeaceRecords

/// The NARA records behind a `Paris Peace Conf.` citation (#354 item 3).
///
/// ## What these citations are, and what they got before
/// `SourceNoteParser.tryParisPeaceConference` classifies `Paris Peace Conf. 180.03401/101`
/// as `.centralFiles(recordGroup: "RG-256", …)`. **1,547 documents** across the thirteen
/// 1919 Paris volumes and `frus1919Russia` take that branch, and until now every one of
/// them ended at the label "State Dept. Central Files (RG 256)" plus generic prose:
/// `SourceExplorerView`'s period section is gated on RG-59, the 1906–1910 numerical section
/// gates on the year, and `load()`'s switch has no `.centralFiles` case at all, so no live
/// query ever runs either.
///
/// macOS was worse than nothing. `MacSourceExplorerView.naraBox` routed **every**
/// `.centralFiles` note through `centralFilesPeriodBox`, so a 1919 Paris citation was
/// offered the RG **59** decimal-file finding aids and the RG 59 filing manual — a
/// different record group, a different filing system, and a confidently wrong destination.
/// Routing RG 256 here fixes that as a side effect.
///
/// ## Why a constant and not an index
/// Every one of the 1,547 resolves to the same two records, so this is two verified
/// identifiers and no dataset. The `series/rg_256.json` harvest is 178 MB and gitignored;
/// bundling it would ship a resource nobody could regenerate, to answer a question that
/// does not vary per document.
///
/// ## What is deliberately *not* claimed
/// The series holds 538 file units whose titles are decimal **ranges**, and one of them is
/// the roll a given citation sits on. Assigning it per document is not done here and should
/// not be done casually: the ranges do not tile (only 303 of 537 consecutive pairs chain by
/// serial+1; 14 adjacent pairs overlap; 10 titles carry literal transcription noise), and
/// three independent implementations of the same idea resolved 533, 1,036 and 1,294
/// documents respectively. NARA's own overlaps cannot be adjudicated from the harvest —
/// `180.034-180.03401A4` and `180.03401/65-104` both literally contain `180.03401/101`, and
/// **0 of 538** file units carry a scope note or a holdings measurement to break the tie.
/// A wrong roll sends the researcher into the wrong 700-image PDF, which is worse than no
/// roll at all. So the panel names the series and hands over NARA's own index to it
/// (`indexSeries`) instead of guessing.
///
/// ## Provenance of the identifiers
/// All five NAIDs were verified by hand against the live NARA Catalog on 2026-08-07, not
/// taken from a bundled artifact:
/// - `583` — `levelOfDescription: recordGroup`, `recordGroupNumber: 256`, title exact,
///   `seriesCount: 33` (matching the bulk-export harvest's own completeness check).
/// - `638859` — `levelOfDescription: series`, `fileUnitCount: 538`, 1918–1931, sole ancestor
///   `583`, `microformPublications: [M820 — General Records of the American Commission to
///   Negotiate Peace, 1918-1931]`, access and use both `Unrestricted`.
/// - `638858`, `638805`, `638831` — the three records `638859.findingAids` names as its
///   index, its classification manual, and its key, each confirmed present in RG 256's
///   33-series list.
///
/// RG 256 carries **two** series titled `General Records`. The other, `2922342`, is the
/// Greene Mission to Finland, Estonia, Latvia and Lithuania (22 file units) — a distinct
/// body of records that these citations never refer to. `638859` is the one with the
/// decimal file, which is why the identifier is pinned here rather than resolved by title.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 3, the Paris Peace Conference records
enum ParisPeaceRecords {

    // MARK: - Record

    /// One NARA Catalog record this panel links to.
    struct CatalogRecord: Identifiable, Sendable, Equatable {
        /// The NARA Archival Identifier, verified by hand (see the type's provenance note).
        let naId: String
        /// NARA's own title for the record — never the FRUS shorthand, so the researcher
        /// can confirm the destination rather than trust it.
        let title: String
        /// The inclusive dates NARA states, when the record carries them.
        let inclusiveDates: String?

        var id: String { naId }

        /// Canonical `catalog.archives.gov/id/<naId>` link.
        var catalogURL: URL? { URL(string: "https://catalog.archives.gov/id/\(naId)") }
    }

    // MARK: - Applicability

    /// Whether a `.centralFiles` record group is the American Commission to Negotiate Peace.
    ///
    /// The parser emits exactly `"RG-256"`, but the two views normalise record groups for
    /// display (`RG-59` → `RG 59`) and one of them passes the normalised form around, so the
    /// bare and spaced spellings are accepted too. Anything else — every RG-59 citation, the
    /// overwhelming majority — is refused, because this panel's identifiers are true only of
    /// RG 256.
    static func applies(recordGroup: String) -> Bool {
        let folded = recordGroup
            .replacingOccurrences(of: "RG-", with: "")
            .replacingOccurrences(of: "RG ", with: "")
            .trimmingCharacters(in: .whitespaces)
        return folded == "256"
    }

    // MARK: - The records

    /// RG 256 itself.
    static let recordGroup = CatalogRecord(
        naId: "583",
        title: "Records of the American Commission to Negotiate Peace",
        inclusiveDates: "1914–1931"
    )

    /// The series holding the Paris Peace Conference decimal file — where every
    /// `Paris Peace Conf.` citation in the corpus lives.
    static let series = CatalogRecord(
        naId: "638859",
        title: "General Records",
        inclusiveDates: "1918–1931"
    )

    /// NARA's index to `series`, and the honest answer to "which roll is my document on?".
    static let indexSeries = CatalogRecord(
        naId: "638858",
        title: "Index to the General Records",
        inclusiveDates: "1918–1931"
    )

    /// The Commission's own filing scheme — what the decimal number in the citation means.
    static let classificationManual = CatalogRecord(
        naId: "638805",
        title: "Records Classification Manual",
        inclusiveDates: "1918"
    )

    /// The Commission's guidance for using the general records.
    static let keyToRecords = CatalogRecord(
        naId: "638831",
        title: "Key to Records",
        inclusiveDates: "1918–1931"
    )

    /// The three finding aids `series.findingAids` names, in the order a researcher needs
    /// them: what the number means, where to look it up, how to use what comes back.
    static let findingAids: [CatalogRecord] = [classificationManual, indexSeries, keyToRecords]

    // MARK: - Wording

    /// Section/box header.
    static var sectionTitle: String {
        String(localized: "source.explorer.parisPeace.header",
               defaultValue: "Paris Peace Conference Records")
    }

    /// Row label for `recordGroup`.
    static var recordGroupLabel: String {
        String(localized: "source.explorer.parisPeace.recordGroup",
               defaultValue: "Record Group")
    }

    /// Row label for `series`.
    static var seriesLabel: String {
        String(localized: "source.explorer.parisPeace.series",
               defaultValue: "Series")
    }

    /// Why this is not the State Department central file the citation superficially
    /// resembles — the distinction that makes the RG-59 finding aids the wrong answer.
    static var provenanceNote: String {
        String(localized: "source.explorer.parisPeace.provenance",
               defaultValue: """
               The American Commission to Negotiate Peace kept its own decimal file, separate \
               from the State Department's. These records are Record Group 256, so the RG 59 \
               central-file finding aids and filing manual do not describe them.
               """)
    }

    /// The microfilm publication the series is reproduced on, and the roll caveat.
    ///
    /// Stated as a capability of the series rather than a promise about this document: most
    /// of the 538 file units are digitised roll PDFs, and which one holds a given decimal
    /// number is what the index resolves. Claiming a roll here is the failure this panel
    /// exists to avoid.
    static var rollNote: String {
        String(localized: "source.explorer.parisPeace.rolls",
               defaultValue: """
               Microfilm publication M820 reproduces the series. Most of its 538 file units \
               are digitized, each covering a range of decimal numbers. This panel does not \
               say which one holds this document. The ranges overlap and are not always \
               continuous, so use the index below to find it.
               """)
    }

    /// Header for the finding-aid list.
    static var findingAidsTitle: String {
        String(localized: "source.explorer.parisPeace.findingAids",
               defaultValue: "Finding Aids")
    }
}
