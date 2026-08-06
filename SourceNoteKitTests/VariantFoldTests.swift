// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - VariantFoldTests

/// Pins the orthographic and lexical folds that stop one collection becoming several authority
/// records because FRUS spelled its name two ways.
///
/// Measured by regenerating `collection-authority.json` with and without them: **4,431 → 4,423
/// records, 10 real merges, 0 records losing a volume, 0 NAIDs changed**, and corpus-wide
/// resolution 74,682 → 74,695 documents. Every fixture below is a verbatim corpus spelling.
///
/// These are deliberately the *only* folds applied. Name-prefix (`Matlock` ⊂ `Jack Matlock`),
/// inversion (`Papers of George Ball` / `Ball Papers`) and abbreviation (`Sp. Asst. for Nat.
/// Sec.`) are curation judgements, not normalization — and one of them would be wrong, because
/// the Eisenhower Library genuinely holds both `C. D. Jackson Papers` and `C. D. Jackson
/// Records`.
///
/// Version history:
///   1.0 — Session 2026-08-06: N-4 curation follow-up
@Suite("CollectionKeying — spelling-variant folds")
struct VariantFoldTests {

    // MARK: - Orthographic (normalized)

    /// The corpus writes one collection with two different apostrophe codepoints.
    @Test("Every apostrophe variant folds to one form")
    func apostrophesFold() {
        let curly = "President\u{2019}s Office Files"      // U+2019, the common form
        let modifier = "President\u{02BC}s Office Files"   // U+02BC, Kennedy volumes
        #expect(curly != modifier, "fixture guard: these must be different strings")
        #expect(CollectionKeying.segmentNorm(curly) == CollectionKeying.segmentNorm(modifier))
        for variant in ["\u{2018}", "\u{0060}", "\u{00B4}"] {
            #expect(CollectionKeying.normalized("Secretary\(variant)s Letters")
                    == CollectionKeying.normalized("Secretary's Letters"),
                    "variant \(variant) did not fold")
        }
    }

    @Test("A collection's own name in quotation marks folds to the bare name")
    func quoteMarksAreDropped() {
        #expect(CollectionKeying.segmentNorm("Project \u{201C}Clean Up\u{201D} Records")
                == CollectionKeying.segmentNorm("Project Clean Up Records"))
        #expect(CollectionKeying.segmentNorm("James W. \u{201C}Bud\u{201D} Nance Files")
                == CollectionKeying.segmentNorm("James W. Bud Nance Files"))
    }

    // MARK: - Lexical (segmentNorm)

    @Test("adviser and advisor are one collection")
    func adviserFolds() {
        #expect(CollectionKeying.segmentNorm("National Security Adviser")
                == CollectionKeying.segmentNorm("National Security Advisor"))
        #expect(CollectionKeying.segmentNorm("National Security Adviser Files")
                == CollectionKeying.segmentNorm("National Security Advisor Files"))
    }

    /// This one only works *because* the apostrophe fold runs first — the corpus writes the
    /// possessive with U+2019, so a rule looking for an ASCII `'` would match nothing.
    @Test("President's and Presidential are one collection")
    func possessiveFolds() {
        #expect(CollectionKeying.segmentNorm("President\u{2019}s Handwriting File")
                == CollectionKeying.segmentNorm("Presidential Handwriting File"))
        #expect(CollectionKeying.segmentNorm("Vice President\u{2019}s Security File")
                == CollectionKeying.segmentNorm("Vice Presidential Security File"))
        // The fold is applied to the normal form, so it must survive the plural fold too.
        #expect(CollectionKeying.segmentNorm("President\u{2019}s Daily Briefing")
                == CollectionKeying.segmentNorm("Presidential Daily Briefings"))
    }

    /// The possessive rule must not eat a possessive that is not the President's.
    @Test("Other possessives are untouched")
    func otherPossessivesSurvive() {
        #expect(CollectionKeying.segmentNorm("Staff Secretary\u{2019}s Records") == "staff secretary's record")
        #expect(CollectionKeying.segmentNorm("Rusk\u{2019}s Appointment Books") == "rusk's appointment book")
    }

    // MARK: - Repository containment

    /// `canonicalRepository` falls through to the raw string outside its keyword list, so a
    /// university and its library were different buckets — while
    /// `manuscriptRepositoriesConflict` already treated that containment as *agreement*.
    @Test("A university's library is the university")
    func universityLibraryFolds() {
        for (library, university) in [("Yale University Library", "Yale University"),
                                      ("University of Montana Library", "University of Montana"),
                                      ("University of Arkansas Libraries", "University of Arkansas"),
                                      ("Princeton University Library", "Princeton University")] {
            #expect(CollectionKeying.canonicalRepository(library) == university,
                    "\(library) did not fold to \(university)")
        }
    }

    /// The rule invented a repository called "University" when it first ran, and moved a real
    /// collection under it. The remainder has to NAME a university, not be the word.
    @Test("Stripping never leaves a bare University")
    func bareUniversityIsRefused() {
        #expect(CollectionKeying.canonicalRepository("University Libraries") == "University Libraries")
        #expect(CollectionKeying.canonicalRepository("University Library") == "University Library")
    }

    /// Repositories resolved by keyword are settled before the fallthrough and must not move.
    @Test("Keyword repositories are untouched by the library rule")
    func keywordRepositoriesUnaffected() {
        #expect(CollectionKeying.canonicalRepository("Library of Congress") == "Library of Congress")
        #expect(CollectionKeying.canonicalRepository("Truman Library") == "Truman Library")
        #expect(CollectionKeying.canonicalRepository("Harry S. Truman Library") == "Truman Library")
        #expect(CollectionKeying.canonicalRepository("Hoover Institution") == "Hoover Institution")
    }

    // MARK: - What must NOT fold

    /// The Eisenhower Library holds both, and the corpus cites both. A fold that merged them
    /// would be a wrong answer, not a tidier one.
    @Test("Papers and Records stay distinct")
    func papersAndRecordsStayDistinct() {
        #expect(CollectionKeying.segmentNorm("C. D. Jackson Papers")
                != CollectionKeying.segmentNorm("C. D. Jackson Records"))
        #expect(CollectionKeying.segmentNorm("Project Clean Up")
                != CollectionKeying.segmentNorm("Project Clean Up Records"))
    }

    @Test("Different people and different collections stay distinct")
    func distinctCollectionsStayDistinct() {
        #expect(CollectionKeying.segmentNorm("Matlock Files")
                != CollectionKeying.segmentNorm("Jack Matlock Files"))
        #expect(CollectionKeying.segmentNorm("Ball Papers")
                != CollectionKeying.segmentNorm("Papers of George Ball"))
        #expect(CollectionKeying.segmentNorm("Frank Carlucci Files")
                != CollectionKeying.segmentNorm("Frank Carlucci Papers"))
    }
}
