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
        #expect(NARACatalogHarvestClient.lotVariants("63D135") == ["63D135", "63 D 135", "63 D135"])
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
