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

/// Tests for normalizing country/post names into canonical geographic keys.
struct GeoKeyNormalizerTests {

    @Test("Extracts the country from a 2-level roll title, stripping Volume and dates")
    func extractsFromRollTitle() {
        // Doc 1: Diplomatic Instructions roll title.
        #expect(GeoKeyNormalizer.keys(from: "Volume 18: Great Britain: Aug. 17, 1861 - Sept. 2, 1863")
                == ["great britain"])
        // Doc 3: Notes to Foreign Missions — a combined-country roll.
        #expect(GeoKeyNormalizer.keys(from: "Uruguay and Paraguay: July 7, 1834 - June 26, 1906")
                == ["uruguay", "paraguay"])
    }

    @Test("Applies aliases so FRUS and NARA names converge")
    func appliesAliases() {
        #expect(GeoKeyNormalizer.keys(from: "Argentine Republic") == ["argentina"])
        #expect(GeoKeyNormalizer.canonicalize("Argentine Republic") == "argentina")
        // Historical names are canonical (the app classifies from FRUS chapters).
        #expect(GeoKeyNormalizer.canonicalize("Persia") == "persia")
        #expect(GeoKeyNormalizer.canonicalize("Siam") == "siam")
    }

    @Test("Maps Notes-from demonyms and FRUS chapter spellings to the country key")
    func mapsDemonymsAndSpellings() {
        // Notes-from demonyms (parent file-unit titles).
        #expect(GeoKeyNormalizer.canonicalize("Venezuelan") == "venezuela")
        #expect(GeoKeyNormalizer.canonicalize("Turkish") == "turkey")
        #expect(GeoKeyNormalizer.canonicalize("Swiss") == "switzerland")
        #expect(GeoKeyNormalizer.canonicalize("Ecuadorean") == "ecuador")
        #expect(GeoKeyNormalizer.canonicalize("Persian") == "persia")
        // FRUS chapter spellings converge with NARA forms.
        #expect(GeoKeyNormalizer.canonicalize("Hayti") == "haiti")
        #expect(GeoKeyNormalizer.canonicalize("Servia") == "serbia")
        #expect(GeoKeyNormalizer.canonicalize("Corea") == "korea")
        #expect(GeoKeyNormalizer.canonicalize("Santo Domingo") == "dominican republic")
    }

    @Test("Splits conjunction forms")
    func splitsConjunctions() {
        #expect(GeoKeyNormalizer.keys(from: "Brazil & Argentina") == ["brazil", "argentina"])
        #expect(GeoKeyNormalizer.keys(from: "Uruguay and Paraguay") == ["uruguay", "paraguay"])
    }

    @Test("Lower-cases and collapses whitespace")
    func canonicalForm() {
        #expect(GeoKeyNormalizer.canonicalize("  Great   Britain ") == "great britain")
        #expect(GeoKeyNormalizer.canonicalize("Switzerland.") == "switzerland")
    }

    @Test("Returns empty for unusable input")
    func emptyForUnusable() {
        #expect(GeoKeyNormalizer.keys(from: "") == [])
        #expect(GeoKeyNormalizer.keys(from: "   ") == [])
    }
}
