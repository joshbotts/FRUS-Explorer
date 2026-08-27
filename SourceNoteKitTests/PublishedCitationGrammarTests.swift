// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

/// Fixtures for the published-source citation grammar (W-11). Every string here is a
/// real note shape from the live index (2026-08-27) — including the two measured
/// landmines: the spurious space before punctuation the TEI-to-text pass leaves around
/// unwrapped italics, and roman-numeral *Bulletin* volume numbers.
@Suite("PublishedCitationGrammar")
struct PublishedCitationGrammarTests {

    // MARK: - Treaty Series

    @Test("Bracketed-note Treaty Series head with trailing junk")
    func treatySeriesBracketed() {
        let parsed = PublishedCitationGrammar.parse("Treaty Series No. 592.]")
        #expect(parsed == PublishedCitation(publication: .treatySeries, designation: "No. 592"))
    }

    @Test("Comma-form Treaty Series head")
    func treatySeriesComma() {
        let parsed = PublishedCitationGrammar.parse("Treaty Series, No. 589.")
        #expect(parsed == PublishedCitation(publication: .treatySeries, designation: "No. 589"))
    }

    @Test("Letter-suffixed treaty number survives the capture")
    func treatySeriesLetterSuffix() {
        let parsed = PublishedCitationGrammar.parse("Treaty Series No. 673–A.")
        #expect(parsed == PublishedCitation(publication: .treatySeries, designation: "No. 673–A"))
    }

    @Test("OCR colon-for-period in the number lead")
    func treatySeriesOCRColon() {
        let parsed = PublishedCitationGrammar.parse("Treaty Series No: 596:]")
        #expect(parsed == PublishedCitation(publication: .treatySeries, designation: "No. 596"))
    }

    @Test("Treaty Series head with no readable number still names the family")
    func treatySeriesNoNumber() {
        let parsed = PublishedCitationGrammar.parse("Treaty Series.")
        #expect(parsed == PublishedCitation(publication: .treatySeries, designation: nil))
    }

    @Test("Miller's Treaties is not the Treaty Series")
    func millerIsNotTreatySeries() {
        #expect(PublishedCitationGrammar.parse("Reprinted from Miller, Treaties, vol. 2, p. 3.") == nil)
    }

    // MARK: - Executive Agreement Series

    @Test("EAS head")
    func executiveAgreementSeries() {
        let parsed = PublishedCitationGrammar.parse("Executive Agreement Series No. 37")
        #expect(parsed == PublishedCitation(publication: .executiveAgreementSeries,
                                            designation: "No. 37"))
    }

    // MARK: - Department of State Bulletin

    @Test("Bulletin head with the italic-space landmine")
    func bulletinHead() {
        let parsed = PublishedCitationGrammar.parse(
            "Department of State Bulletin , September 5, 1948, p. 300.")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "September 5, 1948, p. 300"))
    }

    @Test("Bulletin head keeps only its own citation out of trailing editorial prose")
    func bulletinHeadWithTrailingProse() {
        let parsed = PublishedCitationGrammar.parse(
            "Department of State Bulletin , April 17, 1949, p. 495. This reply, bearing only "
            + "the heading “Memorandum”, was handed to the Luxembourg Minister in Washington "
            + "on April 6, together with copies for the British Embassy (840.00/4–549).")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "April 17, 1949, p. 495"))
    }

    @Test("Reprinted-from form with comma and roman-numeral volume")
    func bulletinReprintedRomanVolume() {
        let parsed = PublishedCitationGrammar.parse(
            "Reprinted from Department of State, Bulletin , November 4, 1939 (vol. i , No. 19), p. 465.")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "November 4, 1939, p. 465"))
    }

    @Test("Release-clause reprint phrase mid-note")
    func bulletinReleaseClause() {
        let parsed = PublishedCitationGrammar.parse(
            "Delivered before the Foreign Affairs Council; reprinted from Department of State, "
            + "Bulletin , September 28, 1940 (vol. iii , No. 66), p. 243.")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "September 28, 1940, p. 243"))
    }

    @Test("Page range yields pp.")
    func bulletinPageRange() {
        let parsed = PublishedCitationGrammar.parse(
            "Source: Department of State Bulletin , May 5, 1946, pp. 778–779.")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "May 5, 1946, pp. 778–779"))
    }

    @Test("Monthly-issue month-year date with lettered front-matter pages")
    func bulletinMonthlyLetteredPages() {
        let parsed = PublishedCitationGrammar.parse(
            "Source: Department of State Bulletin, September 1980, pp. A–C. Muskie delivered "
            + "his address before the United Nations General Assembly.")
        #expect(parsed == PublishedCitation(publication: .stateBulletin,
                                            designation: "September 1980, pp. A–C"))
    }

    @Test("The Official U. S. Bulletin is a different publication")
    func officialBulletinExcluded() {
        #expect(PublishedCitationGrammar.parse(
            "Reprinted from Official U. S. Bulletin , vol. 2, No. 460, Nov. 11, 1918.") == nil)
    }

    @Test("The ARA Bulletin is a different publication")
    func araBulletinExcluded() {
        #expect(PublishedCitationGrammar.parse(
            "Reprinted from American Relief Administration, Bulletin No. 1 , Mar. 17, 1919, p. 12.") == nil)
    }

    // MARK: - Public Papers

    @Test("Long form with president, year, page")
    func publicPapersLongForm() {
        let parsed = PublishedCitationGrammar.parse(
            "Source: Public Papers of the Presidents of the United States: Harry S. Truman , 1945, p. 331. "
            + "On the same date Truman also sent a letter to General Donovan.")
        #expect(parsed == PublishedCitation(publication: .publicPapers,
                                            designation: "Harry S. Truman, 1945, p. 331"))
    }

    @Test("Short form with book number and the italic-space landmine")
    func publicPapersShortForm() {
        let parsed = PublishedCitationGrammar.parse(
            "Source: Public Papers: Johnson , 1965 , Book II, pp. 1003–1006. The President "
            + "delivered his remarks at the Smithsonian Institution.")
        #expect(parsed == PublishedCitation(publication: .publicPapers,
                                            designation: "Johnson, 1965, Book II, pp. 1003–1006"))
    }

    @Test("OCR-bent president name ships as printed")
    func publicPapersOCRName() {
        let parsed = PublishedCitationGrammar.parse(
            "Public Papers of the Presidents of the United States: John E Kennedy , 1963, pp. 650-653.")
        #expect(parsed == PublishedCitation(publication: .publicPapers,
                                            designation: "John E Kennedy, 1963, pp. 650-653"))
    }

    // MARK: - The honest tail

    @Test("Tail publications parse to nil", arguments: [
        "Foreign Relations of the United States, 1917, Supplement 2, vol. I, p. 516.",
        "Documents on Disarmament, 1945–1959, vol. II, pp. 1553–1557.",
        "42 Stat. 122–141.",
        "United States–Vietnam Relations, 1945–1967, Book 10, pp. 937–940.",
        "S. Doc. No. 515, 60th Cong., 1st sess.",
        "Issued by the White House as a press release.",
    ])
    func tailParsesToNil(citation: String) {
        #expect(PublishedCitationGrammar.parse(citation) == nil)
    }
}
