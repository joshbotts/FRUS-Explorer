// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
@testable import DecimalClassLabelGeneratorCore

/// The co-claimant list, which exists because one country number files several places (#1257).
///
/// The Department filed a territory under the number of the power holding it, so `11g` is three
/// islands and `51g` is a federation of five. One name has to be vended; these tests pin what the
/// other names do afterwards.
@Suite("Country co-claimants")
struct CountryAlternatesTests {

    /// The defect this function was extracted to make testable.
    ///
    /// A curated correction overrides the tie-break's winner AFTER the tie-break has recorded who
    /// it displaced, so a list built from the displaced names carries the vended one and omits the
    /// name it replaced. Measured on the real table, that shipped
    /// `11f = Panama Canal Zone (and others: … Panama Canal Zone)`.
    @Test("A curated winner is subtracted, and the name it replaced is not")
    func curatedWinnerIsNotItsOwnAlternate() {
        // The tie-break took "Naos Island" (shortest); curation replaced it with the whole.
        let claimants = ["11f": Set(["Naos Island", "Perico Island", "Panama Canal Zone"])]
        let vended = ["11f": "Panama Canal Zone"]

        let out = DecimalClassLabelRunner.alternates(claimants: claimants, vended: vended)

        #expect(out["11f"] == ["Naos Island", "Perico Island"])
        #expect(out["11f"]?.contains("Panama Canal Zone") == false, "a code is never its own other")
        // Subtracting the tie-break's `displaced` set instead is the shipped bug: it holds
        // ["Perico Island", "Panama Canal Zone"] here — the vended name present, the replaced one
        // gone — and the two lists differ, which is what makes this fixture a control.
        #expect(out["11f"] != ["Panama Canal Zone", "Perico Island"])
    }

    @Test("A code naming one place discloses nothing")
    func singleClaimantIsAbsent() {
        let out = DecimalClassLabelRunner.alternates(
            claimants: ["42": Set(["Canada"]), "60f": Set(["Czechoslovakia", "Ruthenia"])],
            vended: ["42": "Canada", "60f": "Czechoslovakia"])

        // ABSENT, not present-and-empty: a consumer testing `!= nil` and one testing `!isEmpty`
        // must reach the same verdict, or one surface shows an "and 0 others" link.
        #expect(out["42"] == nil)
        #expect(out["60f"] == ["Ruthenia"])
        #expect(out.count == 1)
    }

    @Test("A claimant set with no vended name is dropped, not vended from")
    func unvendedCodeIsDropped() {
        // `74` (Bulgaria) was structurally unanswerable until #1256, and a code the schedule does
        // not name has no gloss for a link to hang off. Emitting alternates for it would put a
        // bare "and 2 others" beside a number with no reading at all.
        let out = DecimalClassLabelRunner.alternates(
            claimants: ["74": Set(["Bulgaria", "Roumania"])], vended: [:])

        #expect(out.isEmpty)
    }

    @Test("The list is sorted, so a rebuild that changed nothing is a no-op")
    func sortedForReproducibility() {
        // `claimants` is a Set, whose iteration order is not stable across runs. Unsorted, a
        // rebuild would diff against itself and every consumer would re-fetch the artifact.
        let out = DecimalClassLabelRunner.alternates(
            claimants: ["51g": Set(["Tongking", "Annam", "Laos", "Cambodia", "Indo China"])],
            vended: ["51g": "Indo China"])

        #expect(out["51g"] == ["Annam", "Cambodia", "Laos", "Tongking"])
    }
}
