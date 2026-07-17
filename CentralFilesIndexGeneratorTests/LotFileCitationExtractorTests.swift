// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CentralFilesIndexGeneratorCore

/// Tests for extracting and normalizing lot-file citations, using real citation strings.
struct LotFileCitationExtractorTests {

    @Test("Normalizes spacing and dash variants to the compact key")
    func normalizes() {
        #expect(LotFileCitationExtractor.normalize("63D135") == "63D135")
        #expect(LotFileCitationExtractor.normalize("63 D 135") == "63D135")
        #expect(LotFileCitationExtractor.normalize("61–D 146") == "61D146")
        #expect(LotFileCitationExtractor.normalize("64 D199") == "64D199")
    }

    @Test("Assigns RG 59 to D-designators and RG 84 to F-designators")
    func recordGroups() {
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "63D135") == "59")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "56F28") == "84")
    }

    @Test("RG 84 for F-designators wherever the F sits; RG 59 for letter-first non-F lots (#352)")
    func recordGroupsLetterFirstAndSuffix() {
        // Letter-first F lots were previously mis-classified RG 59 by the digits-required pattern.
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "F96") == "84")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "F73") == "84")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "79F80") == "84")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "59F59") == "84")
        // Letter-first non-F lots (CFM Files M-, S/S W-) are RG 59.
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "M88") == "59")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "W130") == "59")
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "52M45") == "59")
        // A trailing-letter suffix does not change the RG.
        #expect(LotFileCitationExtractor.recordGroup(forNormalized: "61D282A") == "59")
    }

    @Test("Extracts letter-first, trailing-suffix, plural, and Lot File forms (#352)")
    func extractsWidenedForms() {
        // Letter-first — the class the digits-required pattern silently dropped (M-88 = 697 records).
        #expect(LotFileCitationExtractor.citations(in: "CFM Files: Lot M–88, Box 12")
            .map(\.normalizedLot) == ["M88"])
        #expect(LotFileCitationExtractor.citations(in: "Records of the Bonn Embassy, Lot F 96")
            .map(\.normalizedLot) == ["F96"])
        #expect(LotFileCitationExtractor.citations(in: "S/S Files: Lot W-130")
            .map(\.normalizedLot) == ["W130"])
        // Trailing-letter suffix must be kept, not truncated to a different lot.
        #expect(LotFileCitationExtractor.citations(in: "EUR Files: Lot 61 D 282A")
            .map(\.normalizedLot) == ["61D282A"])
        // "Lot File(s)" infix and a plural lead (first lot captured).
        #expect(LotFileCitationExtractor.citations(in: "Lot File 74 D 471")
            .map(\.normalizedLot) == ["74D471"])
        #expect(LotFileCitationExtractor.citations(in: "RG 59, Lots 64 D 563 and 65 D 101")
            .map(\.normalizedLot) == ["64D563"])
    }

    @Test("Extracts lots from inline, narrative, and dashed citation forms")
    func extractsForms() {
        #expect(LotFileCitationExtractor.citations(in: "CU Files: Lot 63D135 (Entry A1-5072)")
            .map(\.normalizedLot) == ["63D135"])
        #expect(LotFileCitationExtractor.citations(in: "Not printed. A copy is in National Archives, RG 59, S/S – NSC Files: Lot 72D316.")
            .map(\.normalizedLot) == ["72D316"])
        #expect(LotFileCitationExtractor.citations(in: "INR/IL Historical Files, Lot 61–D 146, Box 4581")
            .map(\.normalizedLot) == ["61D146"])
    }

    @Test("Deduplicates repeated lots within one citation; ignores non-lot text")
    func dedupesAndIgnores() {
        let multi = LotFileCitationExtractor.citations(
            in: "RG 59, Lot 64 D 199 and also Lot 64D199 again, plus Lot 55F44")
        #expect(multi.map(\.normalizedLot) == ["64D199", "55F44"])
        #expect(LotFileCitationExtractor.citations(in: "740.0011/12-3145, no lot here").isEmpty)
    }

    @Test("lotVariants produces the compact/spaced/mixed query spellings")
    func variants() {
        // Digit-letter-digit shape keeps its historical three-form output and order.
        #expect(NARACatalogHarvestClient.lotVariants("63D135") == ["63D135", "63 D 135", "63 D135"])
    }

    @Test("lotVariants also spaces letter-first and trailing-suffix lots (#352)")
    func variantsLetterFirstAndSuffix() {
        // Letter-first: compact leads, spaced fallback (previously only ["M88"]).
        #expect(NARACatalogHarvestClient.lotVariants("M88") == ["M88", "M 88"])
        #expect(NARACatalogHarvestClient.lotVariants("F96") == ["F96", "F 96"])
        // Digit-F-digit keeps the three-form shape.
        #expect(NARACatalogHarvestClient.lotVariants("79F80") == ["79F80", "79 F 80", "79 F80"])
        // Trailing suffix: fully-spaced fallback, compact first.
        #expect(NARACatalogHarvestClient.lotVariants("61D282A") == ["61D282A", "61 D 282 A"])
    }

    @Test("Index lot lookup resolves a normalized key")
    func indexLookup() {
        let index = CentralFilesIndex(
            generated: "2026-06-16",
            numericalFile: NumericalFileIndex(seriesNaId: "654171", microfilm: "M862", rolls: []),
            lotFiles: [
                LotFileEntry(lotNumber: "63D135", recordGroup: "59", naId: "111",
                             title: "CU Files", catalogURL: "https://catalog.archives.gov/id/111"),
            ])
        #expect(index.lotFile(normalized: "63D135")?.naId == "111")
        #expect(index.lotFile(normalized: "99Z9") == nil)
    }
}
