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

// MARK: - CentralFilesClassifierTests

/// Tests for classifying pre-1906 documents into a Central Files series and resolving the
/// result against the bundled index, using the five reference-data documents (Docs 1–5).
struct CentralFilesClassifierTests {

    // MARK: Classification (dateline + chapter → series + country)

    @Test("Despatch: U.S. mission abroad → high-confidence despatches")
    func classifiesDespatch() throws {
        // Doc 4 (frus1905/d544) and Doc 5 (frus1876/d311).
        let d4 = CentralFilesClassifier.classify(
            header: "Minister Griscom to the Secretary of State.",
            dateline: "American Legation, Tokyo, March 14, 1905.",
            chapterCountry: "Japan")
        #expect(d4.count == 1)
        #expect(d4.first?.category == .despatches)
        #expect(d4.first?.geoKeys == ["japan"])
        #expect(d4.first?.confidence == .high)

        let d5 = CentralFilesClassifier.classify(
            header: "No. 302. Mr. Rublee to Mr. Fish.",
            dateline: "Legation of the United States, Berne, September 28, 1875.",
            chapterCountry: "Switzerland")
        #expect(d5.first?.category == .despatches)
        #expect(d5.first?.geoKeys == ["switzerland"])
    }

    @Test("Note from: foreign legation in Washington → high-confidence notesFrom")
    func classifiesNoteFrom() {
        // Doc 2 (frus1894/d815).
        let d2 = CentralFilesClassifier.classify(
            header: "Dr. Lobo to Mr. Gresham.",
            dateline: "Legation of Venezuela, Washington, October 26, 1893.",
            chapterCountry: "Venezuela")
        #expect(d2.count == 1)
        #expect(d2.first?.category == .notesFrom)
        #expect(d2.first?.geoKeys == ["venezuela"])
        #expect(d2.first?.confidence == .high)
    }

    // MARK: Dateline year extraction (issue #215 — the pre-1906 gate)

    @Test("extractYear parses 18xx datelines so pre-1906 docs reach country-series resolution")
    @MainActor
    func extractYearCoversPre1906Datelines() {
        // Route to whichever platform's extractor is compiled; both must behave identically.
        func year(_ dateline: String?) -> Int? {
            #if os(iOS)
            return DocumentView.extractYear(from: dateline)
            #elseif os(macOS)
            return MacDocumentView.extractYear(from: dateline)
            #else
            return nil
            #endif
        }

        // The regression: an 1862 dateline used to yield nil under the 20th-century-only regex,
        // tripping the `year < 1906` guard and suppressing the reel-level country-series section.
        #expect(year("Department of State, Washington, November 30, 1862.") == 1862)
        // Other pre-1906 reference datelines (Docs 1/4/5 in the classifier fixtures).
        #expect(year("Department of State, Washington, July 6, 1863.") == 1863)
        #expect(year("Legation of the United States, Berne, September 28, 1875.") == 1875)
        #expect(year("American Legation, Tokyo, March 14, 1905.") == 1905)
        // Boundaries around the pre-1906 / numerical-file (1906–1910) / modern branches.
        #expect(year("Washington, January 1, 1899.") == 1899)
        #expect(year("Washington, January 1, 1900.") == 1900)
        #expect(year("Washington, January 1, 1906.") == 1906)
        #expect(year("Washington, January 1, 1910.") == 1910)
        // Upper bound: 2029 accepted, 2030 rejected.
        #expect(year("Washington, January 1, 2029.") == 2029)
        #expect(year("Meeting held in room 2030.") == nil)
        // Out of range: pre-1800 (FRUS starts 1861) and no year at all.
        #expect(year("An antique note dated 1799.") == nil)
        #expect(year("Department of State, Washington.") == nil)
        // A stray 4-digit token BEFORE the real "Month D, YYYY" (e.g. a telegram/file number
        // in a footnote-bearing dateline blob) must not hijack the year: the strict date parse
        // wins, so this resolves to 1905, not the leading 1805 (issue #215 review hardening).
        #expect(year("Ref. telegram No. 1805. Tokyo, March 14, 1905.") == 1905)
    }

    @Test("Department of State outbound → ambiguous instruction / note-to candidates")
    func classifiesDeptOutbound() {
        // Doc 1 (instruction) and Doc 3 (note to) both date from the Department of State.
        let d1 = CentralFilesClassifier.classify(
            header: "Mr. Seward to Mr. Adams.",
            dateline: "Department of State, Washington, July 6, 1863.",
            chapterCountry: "Great Britain")
        #expect(d1.map(\.category) == [.instructions, .notesTo])
        #expect(d1.allSatisfy { $0.geoKeys == ["great britain"] })
        #expect(d1.allSatisfy { $0.confidence == .medium })

        let d3 = CentralFilesClassifier.classify(
            header: "No. 407. Mr. Evarts to Dr. Aceval.",
            dateline: "Department of State, Washington, November 13, 1878.",
            chapterCountry: "Paraguay")
        #expect(d3.map(\.category) == [.instructions, .notesTo])
        #expect(d3.first?.geoKeys == ["paraguay"])
    }

    @Test("Consular despatch → consular series keyed on the dateline post city (Phase 3)")
    func classifiesConsular() {
        // Doc 8: consular despatch from Havana. Geo is the post city, not the FRUS chapter.
        let c = CentralFilesClassifier.classify(
            header: "Mr. Springer to Mr. Uhl.",
            dateline: "Consulate-General, of the United States, Havana, June 19, 1895.",
            chapterCountry: "Spain")
        #expect(c.count == 1)
        #expect(c.first?.category == .consularDespatches)
        #expect(c.first?.geoKeys == ["havana"])
        #expect(c.first?.confidence == .high)
    }

    @Test("Consular post city extraction handles the comma and 'at' dateline forms")
    func consularPostKeyExtraction() {
        #expect(CentralFilesClassifier.consularPostKey(
            fromDateline: "Consulate-General, of the United States, Havana, June 19, 1895.") == "havana")
        #expect(CentralFilesClassifier.consularPostKey(
            fromDateline: "American Consulate, Amoy, March 2, 1899.") == "amoy")
        #expect(CentralFilesClassifier.consularPostKey(
            fromDateline: "Consulate of the United States at Canton, July 4, 1860.") == "canton")
        #expect(CentralFilesClassifier.consularPostKey(fromDateline: "no consulate city here") == nil)
    }

    @Test("No resolvable country → no classification")
    func noCountryNoClassification() {
        let none = CentralFilesClassifier.classify(
            header: "Mr. X to Mr. Y.",
            dateline: "American Legation, Tokyo, March 14, 1905.",
            chapterCountry: nil)
        #expect(none.isEmpty)
    }

    @Test("Bare-city foreign dateline (no 'Legation' marker) → despatch")
    func classifiesBareCityDespatch() {
        // frus1864p3/d6: U.S. Minister Dayton to Secretary Seward, datelined only "Paris…".
        let d6 = CentralFilesClassifier.classify(
            header: "Mr. Dayton to Mr. Seward.",
            dateline: "Paris, December 11, 1863.",
            chapterCountry: "France")
        #expect(d6.count == 1)
        #expect(d6.first?.category == .despatches)
        #expect(d6.first?.geoKeys == ["france"])
        #expect(d6.first?.confidence == .medium)

        // A Washington / Department dateline must NOT be swept into the despatch fallback.
        let outbound = CentralFilesClassifier.classify(
            header: "Mr. Seward to Mr. Dayton.",
            dateline: "Department of State, Washington, December 11, 1863.",
            chapterCountry: "France")
        #expect(outbound.map(\.category) == [.instructions, .notesTo])
    }

    // MARK: Dateline date parsing

    @Test("Parses the sent date from a dateline, ignoring a Received clause")
    func parsesDatelineDate() {
        #expect(CentralFilesClassifier.datelineDateISO(
            from: "Legation of the United States, Buenos Ayres, February 3, 1900.") == "1900-02-03")
        #expect(CentralFilesClassifier.datelineDateISO(
            from: "Legation of the United States, Berne, September 28, 1875. (Received October 14.)") == "1875-09-28")
        #expect(CentralFilesClassifier.datelineDateISO(from: "no date here") == nil)
    }

    // MARK: Chapter-country resolution from volume structure

    @Test("documentSectionPath returns the full ancestor chain, including a nested country")
    func resolvesSectionPath() {
        // Mirrors the real "Papers Relating to Foreign Affairs" nesting: a compilation
        // wraps the country chapter, whose subject subchapters hold the documents.
        let subchapter = VolumeSection(
            sectionId: "sc1", divType: "subchapter",
            title: "Correspondence respecting the capture of the Saxon.",
            documentIds: ["d229"], subsections: [])
        let country = VolumeSection(
            sectionId: "ch1", divType: "chapter", title: "Great Britain.",
            documentIds: [], subsections: [subchapter])
        let compilation = VolumeSection(
            sectionId: "comp1", divType: "compilation", title: "Correspondence.",
            documentIds: [], subsections: [country])
        let structure = VolumeStructure(volumeId: "frus1864p1", sections: [compilation])

        // The country sits in the middle of the chain — a flat top-level lookup would miss it.
        #expect(CentralFilesClassifier.documentSectionPath(in: structure, documentId: "d229")
                == ["Correspondence.", "Great Britain.", "Correspondence respecting the capture of the Saxon."])
        #expect(CentralFilesClassifier.documentSectionPath(in: structure, documentId: "d999").isEmpty)
    }

    // MARK: End-to-end against the bundled index

    @Test("Classification + bundled index resolve the reference docs to their golden rolls")
    func resolvesReferenceDocsEndToEnd() throws {
        let index = try #require(CentralFilesIndexStore.shared)

        // Doc 5: despatch / Switzerland / 1875-09-28 → roll 189376306.
        let d5 = CentralFilesClassifier.classify(
            header: "Mr. Rublee to Mr. Fish.",
            dateline: "Legation of the United States, Berne, September 28, 1875.",
            chapterCountry: "Switzerland").first
        let d5cat = try #require(d5)
        let d5rolls = index.series(category: d5cat.category)?
            .rolls(geoKey: d5cat.geoKeys[0], dateISO: "1875-09-28") ?? []
        #expect(d5rolls.contains { $0.naId == "189376306" })

        // Doc 1: instruction / Great Britain / 1863-07-06 → roll 149311973 (the instruction
        // candidate; the note-to candidate may also match a GB roll — both are shown).
        let instr = CentralFilesClassifier.classify(
            header: "Mr. Seward to Mr. Adams.",
            dateline: "Department of State, Washington, July 6, 1863.",
            chapterCountry: "Great Britain").first { $0.category == .instructions }
        let instrCat = try #require(instr)
        let instrRolls = index.series(category: instrCat.category)?
            .rolls(geoKey: "great britain", dateISO: "1863-07-06") ?? []
        #expect(instrRolls.contains { $0.naId == "149311973" })

        // Doc 2: note from / Venezuela / 1893-10-26 → roll 188287901.
        let nf = index.series(category: .notesFrom)?
            .rolls(geoKey: "venezuela", dateISO: "1893-10-26") ?? []
        #expect(nf.contains { $0.naId == "188287901" })
    }

    @Test("Bare-city Paris despatch resolves to the France despatch roll (NAID 188687259)")
    func resolvesParisDespatchEndToEnd() throws {
        let index = try #require(CentralFilesIndexStore.shared)
        // frus1864p3/d6 — datelined only "Paris…", so the despatch fallback applies.
        let c = try #require(CentralFilesClassifier.classify(
            header: "Mr. Dayton to Mr. Seward.",
            dateline: "Paris, December 11, 1863.",
            chapterCountry: "France").first)
        #expect(c.category == .despatches)
        let dateISO = CentralFilesClassifier.datelineDateISO(from: "Paris, December 11, 1863.")
        #expect(dateISO == "1863-12-11")
        let rolls = index.series(category: c.category)?
            .rolls(geoKey: c.geoKeys[0], dateISO: dateISO) ?? []
        // "Oct. 23, 1863 – June 8, 1864" — the roll that holds the document's date.
        #expect(rolls.contains { $0.naId == "188687259" })
    }
}

// MARK: - W-8: the chronological-run consular tail

/// The three consular-tail series' classifier cues (W-8): a foreign consulate in the
/// U.S. is a note FROM a foreign consul; Department outbound whose header names a consul
/// gains the consular twin of the instructions/notes-to ambiguity. All chronological-run
/// candidates carry NO geography — they resolve by date alone.
struct ConsularTailClassifierTests {

    @Test("A foreign consulate in the U.S. → note from a foreign consul, date-only")
    func classifiesForeignConsulate() {
        for dateline in ["Consulate-General of Spain, New York, June 5, 1895.",
                         "Spanish Consulate-General, Washington, June 5, 1895.",
                         "British Consulate, New York, March 2, 1880."] {
            let c = CentralFilesClassifier.classify(
                header: "The Spanish consul to Mr. Olney.",
                dateline: dateline, chapterCountry: "Spain")
            #expect(c.map(\.category) == [.notesFromForeignConsuls], "\(dateline)")
            #expect(c.first?.geoKeys.isEmpty == true)
            #expect(c.first?.confidence == .high)
        }
    }

    @Test("U.S. consulates abroad stay on the consular-despatch path")
    func usConsulatesUnchanged() {
        // Every U.S. marker form, including the tokenization trap ("United States
        // Consulate" — the word before 'consulate' is 'states', not a demonym).
        for dateline in ["Consulate-General, of the United States, Havana, June 19, 1895.",
                         "United States Consulate, Amoy, March 2, 1899.",
                         "American Consulate, Amoy, March 2, 1899.",
                         "Consulate of the United States at Canton, July 4, 1860."] {
            #expect(!CentralFilesClassifier.isForeignConsulateDateline(dateline.lowercased()),
                    "\(dateline)")
        }
        // A bare consulate with no marker either way stays on the U.S. path too — the
        // pre-W-8 behavior, and the honest default for U.S.-published despatches.
        #expect(!CentralFilesClassifier.isForeignConsulateDateline(
            "consulate-general, havana, june 19, 1895."))
    }

    @Test("Department outbound with a consul in the header adds the consular pair")
    func deptOutboundConsularPair() {
        let c = CentralFilesClassifier.classify(
            header: "Mr. Fish to the consul at Havana.",
            dateline: "Department of State, Washington, July 6, 1873.",
            chapterCountry: "Spain")
        #expect(c.map(\.category) == [.instructions, .notesTo,
                                      .consularInstructions, .notesToForeignConsuls])
        // The consular pair is date-only: no geography.
        #expect(c[2].geoKeys.isEmpty && c[3].geoKeys.isEmpty)
        #expect(c[2].confidence == .medium && c[3].confidence == .medium)
    }

    @Test("Department outbound, consul header, NO chapter country → only the consular pair")
    func deptOutboundConsularPairWithoutCountry() {
        let c = CentralFilesClassifier.classify(
            header: "Mr. Fish to the consul at Havana.",
            dateline: "Department of State, Washington, July 6, 1873.",
            chapterCountry: nil)
        #expect(c.map(\.category) == [.consularInstructions, .notesToForeignConsuls])
    }

    @Test("Department outbound without a consul header is unchanged")
    func deptOutboundUnchangedWithoutConsul() {
        let c = CentralFilesClassifier.classify(
            header: "Mr. Seward to Mr. Adams.",
            dateline: "Department of State, Washington, July 6, 1863.",
            chapterCountry: "Great Britain")
        #expect(c.map(\.category) == [.instructions, .notesTo])
    }
}
