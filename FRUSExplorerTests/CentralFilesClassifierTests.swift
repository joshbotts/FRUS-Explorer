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

/// The W-8 remainder's cues: domestic and special-agent routing.
struct DomesticAndSpecialAgentClassifierTests {

    @Test("Another executive department's dateline → Letters Received, date-only")
    func classifiesLetterReceived() {
        for dateline in ["War Department, Washington, March 3, 1898.",
                         "Treasury Department, Washington, July 1, 1885.",
                         "Navy Department, Washington, May 2, 1861."] {
            let c = CentralFilesClassifier.classify(
                header: "The Secretary of War to Mr. Sherman.",
                dateline: dateline, chapterCountry: "Spain")
            #expect(c.map(\.category) == [.lettersReceived], "\(dateline)")
            #expect(c.first?.geoKeys.isEmpty == true)
            #expect(c.first?.confidence == .high)
        }
    }

    @Test("Department outbound to a cabinet office adds the Domestic Letters candidate")
    func classifiesDomesticLetter() {
        let c = CentralFilesClassifier.classify(
            header: "Mr. Sherman to the Secretary of War.",
            dateline: "Department of State, Washington, March 5, 1898.",
            chapterCountry: "Spain")
        #expect(c.map(\.category).contains(.domesticLetters))
        // The diplomatic pair still rides along — the chapter country resolves.
        #expect(c.map(\.category).prefix(2) == [.instructions, .notesTo])
    }

    @Test("The office BEFORE the header's 'to' is the sender, not a domestic addressee")
    func senderOfficeIsNotAddressee() {
        // "The Secretary of War to Mr. Sherman" — the office is the SENDER; without the
        // department dateline cue this is not a Domestic Letter.
        #expect(!CentralFilesClassifier.domesticAddressee(
            inHeader: "the secretary of war to mr. sherman."))
        #expect(CentralFilesClassifier.domesticAddressee(
            inHeader: "mr. sherman to the secretary of war."))
    }

    @Test("A special-agent phrase routes by direction, overriding the generic branches")
    func classifiesSpecialAgents() {
        // Outbound: an instruction in the Special Missions volumes.
        let instruction = CentralFilesClassifier.classify(
            header: "Mr. Webster to Mr. Cushing, Special Commissioner.",
            dateline: "Department of State, Washington, May 8, 1843.",
            chapterCountry: "China")
        #expect(instruction.map(\.category) == [.specialAgentsInstructions])
        // Inbound: the agent's despatch — even from a dateline the generic fallback would
        // have called a diplomatic despatch.
        let despatch = CentralFilesClassifier.classify(
            header: "Mr. Blount, Special Commissioner, to Mr. Gresham.",
            dateline: "Honolulu, April 26, 1893.",
            chapterCountry: "Hawaii")
        #expect(despatch.map(\.category) == [.specialAgentsDespatches])
        #expect(despatch.first?.geoKeys.isEmpty == true)
    }
}

// MARK: - Chapter-title forms (2026-09-13)

/// FRUS chapter titles the pre-1906 classifier used to read as non-countries, taken verbatim from
/// the corpus, and what each now classifies to.
///
/// Measured before the change by compiling the real classifier over every pre-1906 document in the
/// live index: 7,497 of 32,478 documents from 1861–1899 got no suggestion, and these title forms
/// are the share of that a normaliser can recover. Every case drives `GeoKeyNormalizer.keys(from:)`
/// or `CentralFilesClassifier.classify` — the functions Source Explorer calls — never a copy.
struct ChapterTitleFormTests {

    @Test("A chapter number, a (Continued.) suffix and an en dash no longer hide the country")
    func decoratedCountryTitles() {
        let cases: [(String, [String])] = [
            ("III.—Argentine Republic.", ["argentina"]),        // frus1873p1v1
            ("XXIX.—Spain.", ["spain"]),                        // frus1873p1v2
            ("XXVIII.— Salvador.", ["el salvador"]),            // frus1873p1v2
            ("1.—Ottoman Porte.", ["turkey"]),                  // frus1873p1v2
            ("[199] *I.—France.", ["france"]),                  // frus1872p2v2
            ("[347] *III. — Portugal.", ["portugal"]),          // frus1872p2v2
            ("Great Britain. (Continued.)", ["great britain"]), // frus1864p2
            ("IV.—Austria–Hungary.", ["austria"]),              // frus1873p1v1, an en dash
            ("Chili.", ["chile"]),
            ("Chili", ["chile"]),
            ("VII.—Chili.", ["chile"]),
        ]
        for (title, expected) in cases {
            #expect(GeoKeyNormalizer.keys(from: title) == expected, "\(title)")
        }
    }

    @Test("A chapter of correspondence with a foreign legation in Washington names that country")
    func foreignLegationTitles() {
        let cases: [(String, [String])] = [
            ("British legation.", ["great britain"]),                                          // frus1863p1
            ("Correspondence with British legation.", ["great britain"]),                      // frus1865p2
            ("Correspondence with the Mexican legation.", ["mexico"]),                         // frus1866p3
            ("French legation.", ["france"]),                                                  // frus1864p3
            ("Correspondence with the legation of Chili at Washington.", ["chile"]),           // frus1881
            ("Correspondence with the legation of Sweden and Norway at Washington.", ["sweden", "norway"]),
            ("Correspondence with the legation of the United States of Colombia at Washington.", ["colombia"]),
            ("Correspondence Between the Department of State and the German Embassy.", ["germany"]), // frus1894app1
            ("Correspondence with the Netherlands legation in the United States", ["netherlands"]),  // frus1864p3
            ("German Legation in Washington.", ["germany"]),                                   // frus1872p1
        ]
        for (title, expected) in cases {
            #expect(GeoKeyNormalizer.keys(from: title) == expected, "\(title)")
            #expect(GeoKeyNormalizer.foreignLegationName(inChapterTitle: title) != nil, "\(title)")
        }
    }

    @Test("A U.S. mission, or a legation that is only the subject of a chapter, is not a foreign-legation chapter")
    func notForeignLegationTitles() {
        for title in [
            "I.—Correspondence with the embassy of the United States at Paris.",   // frus1895p1
            "I. Correspondence with the Legation of the United States at Madrid.",
            "Correspondence with the American legation.",
            "Correspondence with the United States legation.",
            "Marine guard at the legation at Peking",                               // frus1898
            "Raising of United States legation to Austria-Hungary and Austro-Hungarian legation to embassies",
            "Protection of legation by United States troops",                       // frus1895p1
            "Great Britain.",
        ] {
            #expect(GeoKeyNormalizer.foreignLegationName(inChapterTitle: title) == nil, "\(title)")
        }
    }

    @Test("Titles that already resolved keep exactly the key they had, and a consular post key does not move")
    func resolvingTitlesUnchanged() {
        #expect(GeoKeyNormalizer.keys(from: "Great Britain.") == ["great britain"])
        #expect(GeoKeyNormalizer.keys(from: "Sweden and Norway") == ["sweden", "norway"])
        #expect(GeoKeyNormalizer.keys(from: "Volume 5: Great Britain: Aug. 17, 1861 - Sept. 2, 1863") == ["great britain"])
        #expect(GeoKeyNormalizer.keys(from: "Argentine Republic") == ["argentina"])
        #expect(GeoKeyNormalizer.keys(from: "Austria-Hungary.") == ["austria"])
        #expect(GeoKeyNormalizer.keys(from: "Central America.") == ["central america"])
        // "Rome" is the Papal States only as a whole chapter title; `canonicalize` is what the
        // consular post keys go through, and the Rome consulate's key must stay `rome`.
        #expect(GeoKeyNormalizer.canonicalize("Rome") == "rome")
        #expect(GeoKeyNormalizer.canonicalize("Naples") == "two sicilies")
        // "Turkish Empire" stays unread on purpose. In frus1876 it is the PARENT chapter of
        // "Egypt.", and Source Explorer stops at the first title from the root that resolves, so
        // reading it as Turkey moved frus1876/d334 from the Egypt instruction roll to Turkey's.
        #expect(GeoKeyNormalizer.keys(from: "XXXII.—Turkish Empire.") == ["turkish empire"])
    }

    @Test("A chapter titled Rome files under the Papal States and resolves to its instruction roll")
    func romeIsThePapalStates() throws {
        #expect(GeoKeyNormalizer.keys(from: "Rome.") == ["papal states"])
        let index = try #require(CentralFilesIndexStore.shared)
        // frus1862/d680: Mr. Seward to Mr. Blatchford, the minister resident at Rome.
        let outbound = CentralFilesClassifier.classify(
            header: "Mr. Seward to Mr. Blatchford .",
            dateline: "Department of State, Washington, September 25, 1862.",
            chapterCountry: "Rome.")
        let instruction = try #require(outbound.first { $0.category == .instructions })
        let rolls = index.series(category: .instructions)?
            .rolls(geoKey: instruction.geoKeys[0], dateISO: "1862-09-25") ?? []
        // "Volume 1: Papal States: Apr. 1, 1848 - May 22, 1868"
        #expect(rolls.contains { $0.naId == "149327614" })
        // A despatch from Rome resolves to nothing: the index keys the Papal States despatch roll
        // under `italian states`, beside the Kingdom of Italy's, and a guess there would name both.
        let despatch = try #require(CentralFilesClassifier.classify(
            header: "Mr. Blatchford to Mr. Seward",
            dateline: "Legation of the United States , Rome , November 29, 1862.",
            chapterCountry: "Rome.").first)
        #expect(despatch.category == .despatches)
        let despatchRolls = index.series(category: .despatches)?
            .rolls(geoKey: despatch.geoKeys[0], dateISO: "1862-11-29") ?? []
        #expect(despatchRolls.isEmpty)
    }

    @Test("In a foreign-legation chapter the Department's letter is a note TO the legation, never an instruction")
    func legationChapterDepartmentOutbound() throws {
        // frus1863p1/d606
        let inLegationChapter = CentralFilesClassifier.classify(
            header: "Mr. Seward to Lord Lyons .",
            dateline: "Department of State, Washington, August 10, 1863.",
            chapterCountry: "British legation.")
        #expect(inLegationChapter.map(\.category) == [.notesTo])
        #expect(inLegationChapter.first?.geoKeys == ["great britain"])
        #expect(inLegationChapter.first?.confidence == .medium)
        // The same letter under the country chapter keeps both readings.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Seward to Lord Lyons .",
            dateline: "Department of State, Washington, August 10, 1863.",
            chapterCountry: "Great Britain.").map(\.category) == [.instructions, .notesTo])
        let index = try #require(CentralFilesIndexStore.shared)
        let rolls = index.series(category: .notesTo)?
            .rolls(geoKey: "great britain", dateISO: "1863-08-10") ?? []
        // "Great Britain: May 8, 1863 - February 17, 1864"
        #expect(rolls.contains { $0.naId == "216910345" })
    }

    @Test("In a foreign-legation chapter a Washington letter is a note FROM the legation, and nothing else places")
    func legationChapterInbound() {
        // frus1864p2/d466: a bare "Washington" dateline, the form most of Lord Lyons's notes take.
        let bare = CentralFilesClassifier.classify(
            header: "Lord Lyons to Mr. Seward .",
            dateline: "Washington, August 17, 1864.",
            chapterCountry: "British legation.")
        #expect(bare.map(\.category) == [.notesFrom])
        #expect(bare.first?.geoKeys == ["great britain"])
        #expect(bare.first?.confidence == .medium)
        // frus1864p2/d183: the dateline names the legation — the existing high-confidence note.
        let named = CentralFilesClassifier.classify(
            header: "Lord Lyons to Mr. Seward .",
            dateline: "British Legation, Washington, July 3, 1863.",
            chapterCountry: "British legation.")
        #expect(named.map(\.category) == [.notesFrom])
        #expect(named.first?.confidence == .high)
        // frus1864p3/d304: the French legation writing from New York is still the legation.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Geofroy to Mr. Seward",
            dateline: "Legation of France to the United States, New York, November 10, 1864.",
            chapterCountry: "French legation.").map(\.category) == [.notesFrom])
        // frus1865p2/d41: a Foreign Office letter. Under a country chapter it would fall back to a
        // despatch from the U.S. mission; in the legation's chapter it must not.
        #expect(CentralFilesClassifier.classify(
            header: "Lord Russell to Mr. Burnley",
            dateline: "Foreign Office, December 24, 1864.",
            chapterCountry: "Correspondence with British legation.").isEmpty)
        #expect(CentralFilesClassifier.classify(
            header: "Lord Russell to Mr. Burnley",
            dateline: "Foreign Office, December 24, 1864.",
            chapterCountry: "Great Britain.").map(\.category) == [.despatches])
        // A U.S. legation's dateline under a foreign legation's chapter names no mission country.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Adams to Mr. Seward",
            dateline: "Legation of the United States, London, May 1, 1863.",
            chapterCountry: "British legation.").isEmpty)
    }

    @Test("In a foreign-legation chapter a letter the Secretary signs is a note TO the legation, whatever its dateline")
    func legationChapterSecretarySender() {
        // frus1863p1/d402: Seward's reply under a bare "Washington" had read as a note FROM Lord Lyons.
        let bare = CentralFilesClassifier.classify(
            header: "Mr. Seward to Lord Lyons .",
            dateline: "Washington , February 24, 1863.",
            chapterCountry: "British legation.")
        #expect(bare.map(\.category) == [.notesTo])
        #expect(bare.first?.geoKeys == ["great britain"])
        // frus1891/d549: Blaine writing from his house.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Blaine to Sir Julian Pauncefote .",
            dateline: "17 Madison Place , Washington , February 12, 1892 .",
            chapterCountry: "Correspondence with the British Legation at Washington.").map(\.category) == [.notesTo])
        // frus1885/d310: the Department's own dateline, OCR-damaged.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Bayard to Mr. von Alvensleben .",
            dateline: "Dapartment of State , Washington , April 6, 1885 .",
            chapterCountry: "Correspondence with the Legation of Germany at Washington.").map(\.category) == [.notesTo])
        // frus1892/d280: the President's letter to a sovereign is neither note.
        #expect(CentralFilesClassifier.classify(
            header: "The President to King Humbert .",
            dateline: "Washington , July 21, 1892 .",
            chapterCountry: "Correspondence with the legation of Italy at Washington.").isEmpty)
        // frus1897/d290: outside a legation chapter the same surnames sign despatches home. Hay was
        // ambassador in London, and the sender rule must not turn his despatch into an instruction.
        #expect(CentralFilesClassifier.classify(
            header: "Mr. Hay to Mr. Sherman .",
            dateline: "London , September 24, 1897 .",
            chapterCountry: "Great Britain").map(\.category) == [.despatches])
    }

    @Test("The sender is the part before \" to \", and a foreign Secretary of State for Foreign Affairs is not the Secretary")
    func senderHelpersReadTheSender() {
        #expect(CentralFilesClassifier.secretaryOfStateSender(inHeader: "no. 189. mr. bayard to sir l. west ."))   // frus1886/d193
        #expect(CentralFilesClassifier.secretaryOfStateSender(inHeader: "the secretary of state to minister dawson ."))  // frus1905/d321
        // The Assistant Secretary signing for the Secretary, and a header that drops the period.
        #expect(CentralFilesClassifier.secretaryOfStateSender(inHeader: "mr. f. w. seward to lord lyons ."))         // frus1863p1/d415
        #expect(CentralFilesClassifier.secretaryOfStateSender(inHeader: "no. 62. mr bayard to count de foresta ."))  // frus1888p2/d624
        #expect(!CentralFilesClassifier.secretaryOfStateSender(inHeader: "lord lyons to mr. seward ."))
        // frus1925v02/d569
        #expect(!CentralFilesClassifier.secretaryOfStateSender(
            inHeader: "the secretary of state for foreign affairs of san marino ( gozi ) to the secretary of state"))
        // frus1881/d499
        #expect(CentralFilesClassifier.presidentialSender(
            inHeader: "no. 495. the president of the united states to the president of mexico ."))
        #expect(!CentralFilesClassifier.presidentialSender(inHeader: "lord lyons to mr. seward ."))
    }

    @Test("A numbered country chapter classifies exactly as its bare title does")
    func numberedChapterClassifies() throws {
        // frus1873p1v2: a despatch from Madrid filed under "XXIX.—Spain."
        let numbered = CentralFilesClassifier.classify(
            header: "Mr. Sickles to Mr. Fish.",
            dateline: "Legation of the United States, Madrid, March 1, 1873.",
            chapterCountry: "XXIX.—Spain.")
        #expect(numbered == CentralFilesClassifier.classify(
            header: "Mr. Sickles to Mr. Fish.",
            dateline: "Legation of the United States, Madrid, March 1, 1873.",
            chapterCountry: "Spain."))
        #expect(numbered.map(\.category) == [.despatches])
        let index = try #require(CentralFilesIndexStore.shared)
        let rolls = index.series(category: .despatches)?.rolls(geoKey: "spain", dateISO: "1873-03-01") ?? []
        #expect(!rolls.isEmpty)
    }

    @Test("The generator's GeoKeyNormalizer is the app's, line for line")
    func mirrorCopiesAreIdentical() throws {
        // Two copies exist because the app cannot import the SPM generator target, and they are kept
        // in sync by hand. The roll keys the generator writes and the chapter keys the app looks up
        // come out of these two files, so a drift between them silently empties a lookup.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/SourceExplorer/GeoKeyNormalizer.swift"),
                             encoding: .utf8)
        let generator = try String(contentsOf: root.appendingPathComponent("CentralFilesIndexGeneratorCore/GeoKeyNormalizer.swift"),
                                   encoding: .utf8)
        func comparable(_ source: String) -> [String] {
            var lines: [String] = []
            for raw in source.components(separatedBy: "\n") {
                guard !raw.hasPrefix("/// > ") else { continue }          // the app copy's mirror note
                let line = raw.replacingOccurrences(of: #"^(\s*)public "#, with: "$1",
                                                    options: .regularExpression)
                if line == "///", lines.last == "///" { continue }          // the note's blank doc line
                lines.append(line)
            }
            return lines
        }
        #expect(comparable(app) == comparable(generator))
    }
}

// MARK: - The addressee rule (2026-09-13)

/// The rule that tells a Department letter to the U.S. chief of mission (an instruction) from one to a
/// foreign minister in Washington (a note), by matching the header's addressee against the Office of
/// the Historian's register.
///
/// **Every roster here is injected**, built from `POCOMChiefOfMission` values carrying the register's
/// measured tenures, so no test depends on the bundled `chiefs` table. Each refusal fixture breaks
/// exactly ONE of the rule's conditions and sits beside a positive control that differs from it in
/// that condition alone — a refusal that would also happen for another reason proves nothing.
/// Assertions read `.confidence` explicitly, because `CentralFilesClassification.==` ignores it.
///
/// Version history:
///   1.0 — 2026-09-13: initial implementation
struct AddresseeRuleTests {

    // MARK: Fixtures

    /// A resolved chief, built the way `POCOMIndex.chiefs(territoryId:)` resolves one.
    static func chief(_ slug: String, surname: String, forename: String, display: String,
                      role: String = "Envoy Extraordinary and Minister Plenipotentiary",
                      territory: String, first: String, last: String?) -> POCOMChiefOfMission {
        POCOMChiefOfMission(slug: slug, surname: surname, forename: forename, displayName: display,
                            roleLabel: role, territoryId: territory, firstDayISO: first, lastDayISO: last)
    }

    /// fr-1861-dayt-01: minister to France, died at post.
    static let dayton = chief("dayton-william-lewis", surname: "Dayton", forename: "William Lewis",
                              display: "William L. Dayton", territory: "france",
                              first: "1861-03-18", last: "1864-12-01")
    /// fr-1865-bige-01.
    static let bigelow = chief("bigelow-john", surname: "Bigelow", forename: "John", display: "John Bigelow",
                               territory: "france", first: "1865-03-15", last: "1866-12-23")
    /// mx-1861-corw-01.
    static let thomasCorwin = chief("corwin-thomas", surname: "Corwin", forename: "Thomas", display: "Thomas Corwin",
                                    territory: "mexico", first: "1861-03-22", last: "1864-04-27")
    /// mx-1864-corw-01: `1864-04` … `1866-04`, floored and ceiled.
    static let williamCorwin = chief("corwin-william-henry", surname: "Corwin", forename: "William Henry",
                                     display: "William H. Corwin", role: "Chargé d’Affaires ad interim",
                                     territory: "mexico", first: "1864-04-01", last: "1866-04-30")
    /// mx-1885-jack-01.
    static let jackson = chief("jackson-henry-rootes", surname: "Jackson", forename: "Henry Rootes",
                               display: "Henry R. Jackson", territory: "mexico",
                               first: "1885-03-23", last: "1886-10-07")
    /// ru-1899-towe-01.
    static let tower = chief("tower-charlemagne", surname: "Tower", forename: "Charlemagne", display: "Charlemagne Tower",
                             role: "Ambassador Extraordinary and Plenipotentiary", territory: "russia",
                             first: "1899-01-12", last: "1902-11-19")
    /// it-1861-mars-01.
    static let marsh = chief("marsh-george-perkins", surname: "Marsh", forename: "George Perkins",
                             display: "George P. Marsh", territory: "italy", first: "1861-03-20", last: "1882-07-23")
    /// py-1863-wash-01.
    static let washburn = chief("washburn-charles-ames", surname: "Washburn", forename: "Charles Ames",
                                display: "Charles A. Washburn", role: "Minister Resident", territory: "paraguay",
                                first: "1863-01-19", last: "1868-09-10")

    /// `frus1863p2/d573`, the type case: opened from the iPad Research tab, it showed no reels at all.
    static let d573Header = "Mr. Seward to Mr. Dayton."
    static let d573Dateline = "Department of State , Washington , November 10, 1863."
    static let d573Path = ["Supplement.", "France."]
    static let daytonRoster = ChiefsOfMissionRoster(chiefsByTerritory: ["france": [dayton]])

    private func index() throws -> CentralFilesIndex { try #require(CentralFilesIndexStore.shared) }

    // MARK: The grammar

    @Test("The header grammar reads the addressee, its style and the sender, row by row")
    func addresseeGrammarTable() {
        typealias A = CentralFilesAddressee
        let rows: [(String, A?)] = [
            ("Mr. Seward to Mr. Dayton.", A(style: .usStyle, names: ["dayton"], senderIsForeign: false)),
            ("No. 163. Mr. Davis to General Schenck .", A(style: .usStyle, names: ["schenck"], senderIsForeign: false)),
            ("The Acting Secretary of State to Ambassador White .", A(style: .usStyle, names: ["white"], senderIsForeign: false)),
            ("Mr. Davis to Mr. De Long", A(style: .usStyle, names: ["de", "long"], senderIsForeign: false)),
            ("Mr. Seward to Mr. W. L. Dayton.", A(style: .usStyle, names: ["dayton"], senderIsForeign: false)),
            ("Mr. Seward to Mr. Charles Francis Adams Jr.", A(style: .usStyle, names: ["charles", "francis", "adams"], senderIsForeign: false)),
            ("Mr. Seward to Air. Dayton.", A(style: .usStyle, names: ["dayton"], senderIsForeign: false)),
            ("Mr. Seward to Mr. Adams; (same to Mr. Dayton, No. 501.)", A(style: .usStyle, names: ["adams"], senderIsForeign: false)),
            ("Mr. Seward to Mr. Dayton through Mr. Bigelow.", A(style: .usStyle, names: ["dayton"], senderIsForeign: false)),
            ("Mr. Evarts to Dr. Aceval.", A(style: .usStyle, names: ["aceval"], senderIsForeign: false)),
            ("Mr. Seward to Lord Lyons .", A(style: .foreign, names: ["lyons"], senderIsForeign: false)),
            ("No. 333. Mr. Bayard to M. Jackson .", A(style: .foreign, names: ["jackson"], senderIsForeign: false)),
            ("Mr. Fish to Baron Gerolt.", A(style: .foreign, names: ["gerolt"], senderIsForeign: false)),
            ("Mr. Frelinghuysen to Señor Romero .", A(style: .foreign, names: ["romero"], senderIsForeign: false)),
            ("Mr. Seward to Mons. Drouyn de Lhuys", A(style: .foreign, names: ["drouyn", "de", "lhuys"], senderIsForeign: false)),
            ("Mr. Seward to Mavroyeni Bey", A(style: .foreign, names: ["mavroyeni", "bey"], senderIsForeign: false)),
            ("Mr. Hay to Tevfik Pasha", A(style: .foreign, names: ["tevfik", "pasha"], senderIsForeign: false)),
            ("Mr. Seward to Romero", A(style: .none, names: ["romero"], senderIsForeign: false)),
            ("Mr. Hay to the Japanese Minister", A(style: .descriptive(foreignEnvoy: true), names: [], senderIsForeign: false)),
            ("Instructions sent mutatis mutandis to the United States ambassadors at London",
             A(style: .descriptive(foreignEnvoy: false), names: [], senderIsForeign: false)),
            ("Mr. Blaine to Messrs. Norton & Co.", A(style: .multiple, names: [], senderIsForeign: false)),
            ("Mr. Seward to Mr. Adams and Mr. Dayton", A(style: .multiple, names: [], senderIsForeign: false)),
            ("Señor Benitez to Mr. Washburn .", A(style: .usStyle, names: ["washburn"], senderIsForeign: true)),
            ("M. Seward to Mr. Dayton.", A(style: .usStyle, names: ["dayton"], senderIsForeign: false)),
            ("[Untitled]", nil),
        ]
        var checked = 0
        for (header, expected) in rows {
            #expect(CentralFilesClassifier.addressee(inHeader: header) == expected, "\(header)")
            checked += 1
        }
        #expect(checked == 25)
    }

    /// A missing foreign title turns straight into a false "Likely", so every entry is driven through
    /// the parser — as an addressee, and as a sender — rather than trusting the table's membership.
    @Test("Every honorific in both tables classifies as its table says, as addressee and as sender")
    func honorificTablesTokenByToken() {
        var foreign = 0
        for token in CentralFilesClassifier.foreignHonorifics.sorted() {
            let capitalised = token.prefix(1).uppercased() + token.dropFirst()
            let asAddressee = CentralFilesClassifier.addressee(inHeader: "Mr. Seward to \(capitalised) Smith .")
            // `Señores` is a plural title, and a plural addressee reads as several people before any title
            // is consulted — which refuses just the same, and says why more precisely.
            let expected: CentralFilesAddressee.Style = token == "señores" ? .multiple : .foreign
            #expect(asAddressee?.style == expected, "\(capitalised) as an addressee read \(String(describing: asAddressee?.style))")
            let asSender = CentralFilesClassifier.addressee(inHeader: "\(capitalised) Smith to Mr. Dayton .")
            #expect(asSender?.senderIsForeign == (token != "m."), "\(capitalised) as a sender")
            foreign += 1
        }
        var usStyle = 0
        for token in CentralFilesClassifier.usStyleHonorifics.sorted() {
            let capitalised = token.prefix(1).uppercased() + token.dropFirst()
            let parsed = CentralFilesClassifier.addressee(inHeader: "Mr. Seward to \(capitalised) Smith .")
            #expect(parsed?.style == .usStyle && parsed?.names == ["smith"], "\(capitalised) read \(String(describing: parsed))")
            usStyle += 1
        }
        #expect(foreign == CentralFilesClassifier.foreignHonorifics.count && foreign >= 40)
        #expect(usStyle == CentralFilesClassifier.usStyleHonorifics.count && usStyle >= 30)
        #expect(CentralFilesClassifier.usStyleHonorifics.isDisjoint(with: CentralFilesClassifier.foreignHonorifics))
    }

    // MARK: The roster

    @Test("Territory ids reach the historical chapter keys, and Germany is not Prussia")
    func rosterOverrides() {
        for id in ["guatemala", "costa-rica", "honduras", "nicaragua", "el-salvador"] {
            let keys = ChiefsOfMissionRoster.geoKeys(forTerritoryId: id)
            #expect(keys.contains("central america"), "\(id): \(keys)")
            #expect(keys.first == id.replacingOccurrences(of: "-", with: " "), "\(id) lost its own key: \(keys)")
        }
        #expect(ChiefsOfMissionRoster.geoKeys(forTerritoryId: "iran") == ["iran", "persia"])
        #expect(ChiefsOfMissionRoster.geoKeys(forTerritoryId: "thailand") == ["thailand", "siam"])
        #expect(ChiefsOfMissionRoster.geoKeys(forTerritoryId: "holy-see") == ["holy see", "papal states"])
        #expect(ChiefsOfMissionRoster.geoKeys(forTerritoryId: "united-kingdom") == ["great britain"])
        #expect(ChiefsOfMissionRoster.geoKeys(forTerritoryId: "germany") == ["germany"],
                "a Prussia chapter must not borrow the German Empire's chiefs")
        // Through the injection initializer, the path `.bundled` takes: a chief keyed at Guatemala answers
        // a letter printed in a "Central America." chapter. (A synthetic chief — the keying is under test.)
        let envoy = Self.chief("fixture-envoy", surname: "Fixture", forename: "Test", display: "Test Fixture",
                               territory: "guatemala", first: "1880-01-01", last: "1882-12-31")
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["guatemala": [envoy]])
        #expect(roster.decide(header: "Mr. Evarts to Mr. Fixture .",
                              dateline: "Department of State, Washington, May 1, 1881.",
                              geoKeys: GeoKeyNormalizer.keys(from: "Central America."))?.slug == "fixture-envoy")
    }

    /// Measured over the register: 51 territories carry a served chief of mission between 1861 and 1906.
    /// A territory whose keys reach no diplomatic roll can never decide anything, which is a silent loss
    /// of reach — the three historical names the overrides exist for were found exactly this way.
    ///
    /// The ids are pinned here rather than read from the bundled `chiefs` table, which this test must
    /// not depend on; a test over the bundled table belongs with the regenerated artifact.
    @Test("Every register territory's keys reach the central-files vocabulary, Bulgaria excepted")
    func rosterKeysJoinCentralFilesVocabulary() throws {
        let index = try index()
        var vocabulary = Set<String>()
        for category in [CentralFilesSeriesCategory.despatches, .instructions, .notesFrom, .notesTo] {
            let series = try #require(index.series(category: category))
            for roll in series.rolls { vocabulary.formUnion(roll.geoKeys) }
        }
        let territories = [
            "argentina", "austria", "belgium", "bolivia", "brazil", "bulgaria", "chile", "china", "colombia",
            "costa-rica", "cuba", "denmark", "dominican-republic", "ecuador", "egypt", "el-salvador", "france",
            "germany", "greece", "guatemala", "haiti", "hawaii", "holy-see", "honduras", "iran", "italy", "japan",
            "korea", "liberia", "luxembourg", "mexico", "montenegro", "morocco", "netherlands", "nicaragua",
            "norway", "panama", "paraguay", "peru", "portugal", "romania", "russia", "serbia", "spain", "sweden",
            "switzerland", "thailand", "turkey", "united-kingdom", "uruguay", "venezuela",
        ]
        // Bulgaria: the bundled index files no diplomatic roll under it, so its chiefs have nothing to
        // decide. Asserted below as well, so the exception cannot go stale silently.
        let allowList: Set<String> = ["bulgaria"]
        var checked = 0
        for territory in territories {
            let keys = ChiefsOfMissionRoster.geoKeys(forTerritoryId: territory)
            let joined = keys.contains(where: vocabulary.contains)
            #expect(joined != allowList.contains(territory), "\(territory) → \(keys), joined: \(joined)")
            checked += 1
        }
        #expect(checked == 51)
    }

    // MARK: The rule, end to end against the bundled central-files index

    @Test("d573: a letter to Dayton is Diplomatic Instructions only, at Likely, naming him")
    func addresseeRuleDecidesD573() throws {
        let index = try index()
        // Control: with no roster, the same letter shows both reels at Possible.
        let undecided = CentralFilesClassifier.documentHomes(
            header: Self.d573Header, dateline: Self.d573Dateline, sectionPath: Self.d573Path,
            index: index, roster: .empty)
        #expect(undecided.map(\.classification.category) == [.instructions, .notesTo])
        #expect(undecided.flatMap { $0.rolls.map(\.naId) } == ["149305041", "216905138"])
        #expect(undecided.allSatisfy { $0.classification.confidence == .medium && $0.chiefOfMission == nil })

        let homes = CentralFilesClassifier.documentHomes(
            header: Self.d573Header, dateline: Self.d573Dateline, sectionPath: Self.d573Path,
            index: index, roster: Self.daytonRoster)
        #expect(homes.map(\.classification.category) == [.instructions])
        #expect(homes.flatMap { $0.rolls.map(\.naId) } == ["149305041"])
        let lead = try #require(homes.first)
        #expect(lead.classification.confidence == .high)
        #expect(lead.classification.geoKeys == ["france"])
        #expect(lead.chiefOfMission == Self.dayton)
        #expect(lead.classification.rationale
                == "From the Department of State to William L. Dayton, U.S. Envoy Extraordinary and Minister Plenipotentiary to France (1861–1864): an instruction.")
    }

    @Test("frus1863p1/d573: a Department note in the British legation chapter is unchanged by the rule")
    func legationChapterUnchanged() throws {
        let adams = Self.chief("adams-charles-francis", surname: "Adams", forename: "Charles Francis",
                               display: "Charles Francis Adams", territory: "united-kingdom",
                               first: "1861-03-20", last: "1868-05-13")
        let homes = CentralFilesClassifier.documentHomes(
            header: "Mr. Seward to Lord Lyons .", dateline: "Department of State, Washington, June 18, 1863.",
            sectionPath: ["Correspondence.", "British legation."], index: try index(),
            roster: ChiefsOfMissionRoster(chiefsByTerritory: ["united-kingdom": [adams]]))
        #expect(homes.map(\.classification.category) == [.notesTo])
        #expect(homes.flatMap { $0.rolls.map(\.naId) } == ["216910345"])
        #expect(homes.first?.classification.confidence == .medium)
        #expect(homes.first?.chiefOfMission == nil)
    }

    /// frus1861/d212. The title classifies to both series but only an Instructions reel covers the date;
    /// the rule decides, so that one reel is promoted — the draft left these at "Possible".
    @Test("An Instructions-only home is promoted when the rule decides")
    func instructionsOnlyHomePromoted() throws {
        let header = "Mr. Seward to Mr. Marsh ."
        let dateline = "Department of State , Washington , May 9, 1861 ."
        let path = ["Instructions and despatches", "Italy"]
        let control = CentralFilesClassifier.documentHomes(header: header, dateline: dateline, sectionPath: path,
                                                           index: try index(), roster: .empty)
        #expect(control.map(\.classification.category) == [.instructions], "fixture guard: one reel, Instructions")
        #expect(control.first?.classification.confidence == .medium)

        let homes = CentralFilesClassifier.documentHomes(
            header: header, dateline: dateline, sectionPath: path, index: try index(),
            roster: ChiefsOfMissionRoster(chiefsByTerritory: ["italy": [Self.marsh]]))
        #expect(homes.map(\.classification.category) == [.instructions])
        #expect(homes.flatMap { $0.rolls.map(\.naId) } == ["149319723"])
        #expect(homes.first?.classification.confidence == .high)
        #expect(homes.first?.chiefOfMission == Self.marsh)
    }

    /// frus1861/d119. The rule decides this letter is an instruction, but the only reel covering the date is
    /// Notes to Foreign Missions. Removing it would leave "no match", which is false; it stays at Possible (D2).
    @Test("A Notes-to-only home is kept at Possible even when the rule decides")
    func notesToOnlyHomeKept() throws {
        let header = "Mr. Seward to Mr. Dayton ."
        let dateline = "Department of State , Washington , April 22, 1861 ."
        #expect(Self.daytonRoster.decide(header: header, dateline: dateline, geoKeys: ["france"]) == Self.dayton,
                "fixture guard: the rule must decide, or keeping the reel proves nothing")
        let homes = CentralFilesClassifier.documentHomes(
            header: header, dateline: dateline, sectionPath: ["Instructions and despatches", "France"],
            index: try index(), roster: Self.daytonRoster)
        #expect(homes.map(\.classification.category) == [.notesTo])
        #expect(homes.flatMap { $0.rolls.map(\.naId) } == ["216905138"])
        #expect(homes.first?.classification.confidence == .medium)
        #expect(homes.first?.chiefOfMission == nil)
    }

    // MARK: Uniqueness

    /// The register's one same-surname pair at one post: Thomas Corwin leaves Mexico on 1864-04-27, and
    /// William H. Corwin is chargé from April 1864. The date is synthetic; the pair is real.
    @Test("Two register people with the header's surname at the post refuse, and both reels stay")
    func corwinCollisionKeepsBoth() throws {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["mexico": [Self.thomasCorwin, Self.williamCorwin]])
        let dateline = "Department of State, Washington, April 20, 1864."
        #expect(roster.decide(header: "Mr. Seward to Mr. Corwin .", dateline: dateline, geoKeys: ["mexico"]) == nil)
        let homes = CentralFilesClassifier.documentHomes(
            header: "Mr. Seward to Mr. Corwin .", dateline: dateline, sectionPath: ["Mexico."],
            index: try index(), roster: roster)
        #expect(homes.map(\.classification.category) == [.instructions, .notesTo])
        #expect(homes.allSatisfy { $0.classification.confidence == .medium })
    }

    @Test("The same roster decides a date only Thomas Corwin covers")
    func corwinSingleTenureDecides() throws {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["mexico": [Self.thomasCorwin, Self.williamCorwin]])
        let dateline = "Department of State, Washington, June 1, 1863."
        #expect(roster.decide(header: "Mr. Seward to Mr. Corwin .", dateline: dateline, geoKeys: ["mexico"])
                == Self.thomasCorwin)
        let homes = CentralFilesClassifier.documentHomes(
            header: "Mr. Seward to Mr. Corwin .", dateline: dateline, sectionPath: ["Mexico."],
            index: try index(), roster: roster)
        #expect(homes.map(\.classification.category) == [.instructions])
        #expect(homes.first?.classification.confidence == .high)
    }

    /// Two chiefs of DIFFERENT surnames at the post on the date — a turnover. The rule counts people
    /// matching the NAME, so this decides; counting chiefs at post would refuse 290 real documents.
    @Test("A turnover overlap still decides for the one chief the header names")
    func turnoverOverlapDecides() {
        let successor = Self.chief("fixture-successor", surname: "Successor", forename: "Test", display: "Test Successor",
                                   territory: "france", first: "1864-11-15", last: "1866-12-23")
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["france": [Self.dayton, successor]])
        #expect(roster.decide(header: "Mr. Seward to Mr. Dayton .",
                              dateline: "Department of State, Washington, November 20, 1864.",
                              geoKeys: ["france"]) == Self.dayton)
    }

    // MARK: Refusals, one condition each

    /// frus1899/d292: Hay writes to "Mr. Tower" in the Great Britain chapter, while the register's
    /// Charlemagne Tower is at St. Petersburg. Only the country differs from the control.
    @Test("A U.S. chief at another post refuses; the same letter under his own post decides")
    func towerOtherCountryKeepsBoth() throws {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["russia": [Self.tower]])
        let header = "Mr. Hay to Mr. Tower ."
        let dateline = "Department of State , Washington , September 6, 1899 ."
        #expect(roster.decide(header: header, dateline: dateline, geoKeys: ["russia"]) == Self.tower, "control")
        #expect(roster.decide(header: header, dateline: dateline, geoKeys: ["great britain"]) == nil)
        let homes = CentralFilesClassifier.documentHomes(header: header, dateline: dateline, sectionPath: ["Great Britain"],
                                                         index: try index(), roster: roster)
        #expect(homes.map(\.classification.category) == [.instructions, .notesTo])
        #expect(homes.allSatisfy { $0.classification.confidence == .medium })
    }

    /// frus1886/d337, "No. 333. Mr. Bayard to M. Jackson .". Henry R. Jackson WAS at post (1885-03-23 …
    /// 1886-10-07), so the name and the date match and only the honorific refuses — which a Lord Lyons
    /// fixture, having no roster match at all, could never show. It pins a known cost: `M.` is OCR here.
    @Test("A foreign honorific refuses even when the name and tenure match")
    func foreignHonorificKeepsBoth() throws {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["mexico": [Self.jackson]])
        let dateline = "Department of State, Washington, August 14, 1886."
        #expect(roster.decide(header: "No. 333. Mr. Bayard to Mr. Jackson .", dateline: dateline,
                              geoKeys: ["mexico"]) == Self.jackson, "control")
        #expect(roster.decide(header: "No. 333. Mr. Bayard to M. Jackson .", dateline: dateline, geoKeys: ["mexico"]) == nil)
        let homes = CentralFilesClassifier.documentHomes(header: "No. 333. Mr. Bayard to M. Jackson .", dateline: dateline,
                                                         sectionPath: ["Mexico"], index: try index(), roster: roster)
        #expect(homes.map(\.classification.category) == [.instructions, .notesTo])
        #expect(homes.allSatisfy { $0.classification.confidence == .medium })
    }

    @Test("A foreign sender refuses under an ordinary Department dateline")
    func foreignSenderRefused() {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["paraguay": [Self.washburn]])
        let dateline = "Department of State, Washington, March 27, 1868."
        #expect(roster.decide(header: "Mr. Seward to Mr. Washburn .", dateline: dateline, geoKeys: ["paraguay"])
                == Self.washburn, "control")
        #expect(roster.decide(header: "Señor Benitez to Mr. Washburn .", dateline: dateline, geoKeys: ["paraguay"]) == nil)
    }

    /// Paraguay's foreign ministry styled itself "Department of State and Foreign Relations", which the
    /// classifier reads as Department outbound. `frus1868p2/d409` has a foreign sender as well, so it
    /// would refuse for two reasons and test neither; this fixture keeps the U.S. sender.
    @Test("A foreign ministry's 'Department of State and Foreign …' dateline refuses")
    func foreignMinistryDatelineRefused() {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["paraguay": [Self.washburn]])
        #expect(roster.decide(header: "Mr. Seward to Mr. Washburn .",
                              dateline: "Department of State, Washington, March 27, 1868.",
                              geoKeys: ["paraguay"]) == Self.washburn, "control")
        #expect(roster.decide(header: "Mr. Seward to Mr. Washburn .",
                              dateline: "Department of State and Foreign Relations, Luque, March 27, 1868.",
                              geoKeys: ["paraguay"]) == nil)
        #expect(roster.decide(header: "Mr. Seward to Mr. Washburn .",
                              dateline: "Department of State for Foreign Affairs, Lisbon, March 27, 1868.",
                              geoKeys: ["paraguay"]) == nil)
    }

    // MARK: Dates

    /// Dayton died at post on 1864-12-01; Seward's letters to him kept coming for days after. Ninety days
    /// past the last day is 1865-03-01.
    @Test("Ninety days of grace after the last day, and not one more")
    func graceAfterEnd() {
        func decides(_ date: String) -> Bool {
            Self.daytonRoster.decide(header: "Mr. Seward to Mr. Dayton .",
                                     dateline: "Department of State, Washington, \(date).",
                                     geoKeys: ["france"]) != nil
        }
        #expect(decides("December 5, 1864"))
        #expect(decides("March 1, 1865"), "day 90")
        #expect(!decides("March 2, 1865"), "day 91")
        #expect(!decides("March 15, 1865"))
        #expect(decides("March 18, 1861"), "the first day is inclusive")
    }

    /// Bigelow headed the Paris legation before his 1865-03-15 appointment; the register does not make him
    /// its chief then, and the rule gives no grace before the first day.
    @Test("No grace before the first day")
    func noGraceBeforeStart() {
        let roster = ChiefsOfMissionRoster(chiefsByTerritory: ["france": [Self.bigelow]])
        #expect(roster.decide(header: "Mr. Seward to Mr. Bigelow .",
                              dateline: "Department of State, Washington, March 15, 1865.",
                              geoKeys: ["france"]) == Self.bigelow, "control: the first day decides")
        #expect(roster.decide(header: "Mr. Seward to Mr. Bigelow .",
                              dateline: "Department of State, Washington, March 14, 1865.",
                              geoKeys: ["france"]) == nil)
        #expect(roster.decide(header: "Mr. Seward to Mr. Bigelow .",
                              dateline: "Department of State, Washington, January 10, 1865.",
                              geoKeys: ["france"]) == nil)
    }

    /// The rule drops only the Notes-to-Foreign-Missions home. A header that names a consul adds the
    /// consular pair, and whatever of it resolves must survive a decision untouched. (Consular
    /// Instructions end in 1834 in the bundled index, so at this date only the Notes-to-Foreign-Consuls
    /// run resolves — roll 40038220.) The path is `France.` alone: a date-only consular run resolves
    /// under any title, so behind `Supplement.` the title loop would stop before reaching the country.
    @Test("A decided letter keeps its consular candidates exactly as they were")
    func consularPairUntouched() throws {
        let header = "Mr. Seward to Mr. Dayton, consul."
        let control = CentralFilesClassifier.documentHomes(
            header: header, dateline: Self.d573Dateline, sectionPath: ["France."], index: try index(), roster: .empty)
        #expect(control.map(\.classification.category) == [.instructions, .notesTo, .notesToForeignConsuls],
                "fixture guard: the consular run must resolve beside the diplomatic pair")

        let homes = CentralFilesClassifier.documentHomes(
            header: header, dateline: Self.d573Dateline, sectionPath: ["France."], index: try index(),
            roster: Self.daytonRoster)
        #expect(homes.map(\.classification.category) == [.instructions, .notesToForeignConsuls])
        #expect(homes.first?.classification.confidence == .high)
        let consular = try #require(homes.last)
        let controlConsular = try #require(control.last)
        #expect(consular == controlConsular)
        #expect(consular.classification.confidence == .medium && consular.chiefOfMission == nil)
        #expect(consular.rolls.map(\.naId) == ["40038220"])
    }

    @Test("A chief with no last day never matches, and neither does a dateline with no date")
    func openTenureAndUndatedRefuse() {
        let open = Self.chief("fixture-open", surname: "Dayton", forename: "William Lewis", display: "William L. Dayton",
                              territory: "france", first: "1861-03-18", last: nil)
        #expect(ChiefsOfMissionRoster(chiefsByTerritory: ["france": [open]])
            .decide(header: "Mr. Seward to Mr. Dayton .", dateline: "Department of State, Washington, November 10, 1863.",
                    geoKeys: ["france"]) == nil)
        #expect(Self.daytonRoster.decide(header: "Mr. Seward to Mr. Dayton .", dateline: "Department of State, Washington.",
                                         geoKeys: ["france"]) == nil)
    }
}

// MARK: - Source Explorer's shared evaluation (2026-09-13)

/// The gate, the outcome states, the serial label and the year both Source Explorer views now take from
/// `CentralFilesClassifier` rather than deciding each for themselves.
///
/// Version history:
///   1.0 — 2026-09-13: initial implementation
struct SourceExplorerEvaluationTests {

    private static let d573Facts = IndexingPipeline.SourceExplorerFacts(
        header: AddresseeRuleTests.d573Header, dateline: AddresseeRuleTests.d573Dateline, despatchSerial: "428")

    /// The d573 History route — no dateline, no year — with every gate condition passing unless overridden.
    private static func input(facts: SourceExplorerFactsLookup = .found(d573Facts), routeYear: Int? = nil,
                              volumeId: String? = "frus1863p2", documentId: String? = "d573",
                              pipeline: Bool = true, index: Bool = true,
                              path: CountrySeriesSectionPathRead = .path(AddresseeRuleTests.d573Path)) -> CountrySeriesGateInput {
        CountrySeriesGateInput(
            routeYear: routeYear, volumeId: volumeId, documentId: documentId, pipelineAvailable: pipeline,
            facts: facts,
            context: SourceExplorerDocumentContext.hydrate(routeHeader: documentId, routeDateline: nil,
                                                           routeYear: routeYear, documentId: documentId,
                                                           indexed: facts.facts),
            centralFilesIndexAvailable: index, sectionPath: path)
    }

    private static func facts(dateline: String?) -> SourceExplorerFactsLookup {
        .found(IndexingPipeline.SourceExplorerFacts(header: "Mr. Seward to Mr. Dayton.", dateline: dateline,
                                                    despatchSerial: nil))
    }

    // MARK: The gate

    @Test("Each gate refusal is reached by breaking exactly one condition")
    func gateReasons() {
        #expect(CentralFilesClassifier.gate(Self.input()) == nil, "every condition holds")
        #expect(CentralFilesClassifier.gate(Self.input(path: .unread)) == nil, "an unread structure passes")
        #expect(CentralFilesClassifier.gate(Self.input(routeYear: 1905)) == nil, "1905 is pre-1906")

        let cases: [(CountrySeriesGateInput, CountrySeriesOutcome)] = [
            (Self.input(routeYear: 1906), .notApplicable),
            (Self.input(volumeId: nil), .notChecked(.noDocumentIdentity)),
            (Self.input(documentId: nil), .notChecked(.noDocumentIdentity)),
            (Self.input(pipeline: false), .notChecked(.indexStarting)),
            (Self.input(facts: .failed), .notChecked(.indexReadFailed)),
            (Self.input(facts: .missing), .notChecked(.documentNotIndexed)),
            (Self.input(facts: Self.facts(dateline: nil)), .notChecked(.noDateline)),
            (Self.input(facts: Self.facts(dateline: "Department of State, Washington.")), .notChecked(.noYear)),
            (Self.input(facts: Self.facts(dateline: "Department of State, Washington, March 1, 1906.")), .notApplicable),
            (Self.input(index: false), .notChecked(.centralFilesIndexMissing)),
            (Self.input(path: .noStructure), .notChecked(.noVolumeStructure)),
            (Self.input(path: .path([])), .notChecked(.documentNotInStructure)),
        ]
        var reasons = Set<String>()
        for (input, expected) in cases {
            let outcome = CentralFilesClassifier.gate(input)
            #expect(outcome == expected, "\(input) → \(String(describing: outcome))")
            #expect(outcome != .noMatch)
            if case .notChecked(let reason) = outcome { reasons.insert("\(reason)") }
        }
        #expect(reasons == Set(CountrySeriesOutcome.NotCheckedReason.allCases.map { "\($0)" }),
                "the gate reaches \(reasons.count) of the \(CountrySeriesOutcome.NotCheckedReason.allCases.count) reasons")
    }

    @Test("Every state says something different, and none claims a prediction was attempted")
    func notCheckedMessagesDistinct() {
        let reasons = CountrySeriesOutcome.NotCheckedReason.allCases
        #expect(reasons.count == 9)
        let messages = reasons.map(\.message) + [CountrySeriesOutcome.loadingMessage, CountrySeriesOutcome.notApplicableMessage]
        #expect(Set(messages).count == messages.count, "two states share a sentence")
        for message in messages {
            #expect(!message.isEmpty)
            #expect(!message.contains("couldn’t be predicted") && !message.contains("couldn't be predicted"),
                    "only a check that ran and found nothing may say that: \(message)")
        }
        // Indexing a volume does not change the load key, so this state must not promise to fill in.
        let notIndexed = CountrySeriesOutcome.NotCheckedReason.documentNotIndexed.message
        #expect(!notIndexed.contains("fills in") && !notIndexed.contains("when it is ready"))
    }

    // MARK: The year

    @Test("documentYear(fromDateline:) agrees with the platform's extractYear")
    @MainActor
    func documentYearParity() {
        func platform(_ dateline: String?) -> Int? {
            #if os(iOS)
            return DocumentView.extractYear(from: dateline)
            #elseif os(macOS)
            return MacDocumentView.extractYear(from: dateline)
            #else
            return nil
            #endif
        }
        let datelines: [String?] = [
            "Department of State, Washington, November 30, 1862.", "Department of State , Washington , November 10, 1863.",
            "Legation of the United States, Berne, September 28, 1875.", "American Legation, Tokyo, March 14, 1905.",
            "Washington, January 1, 1906.", "Washington, January 1, 2029.", "Meeting held in room 2030.",
            "An antique note dated 1799.", "Department of State, Washington.",
            "Ref. telegram No. 1805. Tokyo, March 14, 1905.", "Executive Mansion , Washington, D. C. , 1861 .", nil,
        ]
        var checked = 0
        for dateline in datelines {
            #expect(CentralFilesClassifier.documentYear(fromDateline: dateline) == platform(dateline), "\(String(describing: dateline))")
            checked += 1
        }
        #expect(checked == 12)
        #expect(CentralFilesClassifier.documentYear(fromDateline: "Executive Mansion , Washington, D. C. , 1861 .") == 1861,
                "fixture guard: the loose scan must be exercised")
    }

    // MARK: The serial label

    @Test("d573's serial is an instruction's, not the post's")
    func serialLabelD573IsInstruction() throws {
        let homes = CentralFilesClassifier.documentHomes(
            header: AddresseeRuleTests.d573Header, dateline: AddresseeRuleTests.d573Dateline,
            sectionPath: AddresseeRuleTests.d573Path, index: try #require(CentralFilesIndexStore.shared),
            roster: AddresseeRuleTests.daytonRoster)
        let label = CentralFilesSerialLabel(homes: homes)
        #expect(label == .instruction)
        #expect(label.title(serial: "428") == "Instruction No. 428")
        #expect(!label.caption.contains("post’s own"))
        #expect(label.title(serial: "4 (Greek Series)") == "Instruction No. 4 (Greek Series)")
    }

    @Test("A despatch from the legation keeps Despatch No.")
    func serialLabelDespatch() throws {
        let homes = CentralFilesClassifier.documentHomes(
            header: "Mr. Dayton to Mr. Seward.", dateline: "Paris, December 11, 1863.", sectionPath: ["France."],
            index: try #require(CentralFilesIndexStore.shared), roster: .empty)
        #expect(homes.map(\.classification.category) == [.despatches], "fixture guard")
        let label = CentralFilesSerialLabel(homes: homes)
        #expect(label == .despatch)
        #expect(label.title(serial: "74") == "Despatch No. 74")
        #expect(label.caption.contains("post’s own serial"))
    }

    @Test("A note leads to a neutral No.")
    func serialLabelNotesNeutral() throws {
        let homes = CentralFilesClassifier.documentHomes(
            header: "Mr. Seward to Lord Lyons .", dateline: "Department of State, Washington, June 18, 1863.",
            sectionPath: ["Correspondence.", "British legation."],
            index: try #require(CentralFilesIndexStore.shared), roster: .empty)
        #expect(homes.map(\.classification.category) == [.notesTo], "fixture guard")
        let label = CentralFilesSerialLabel(homes: homes)
        #expect(label == .neutral)
        #expect(label.title(serial: "12") == "No. 12")
        #expect(Set([label.caption, CentralFilesSerialLabel.instruction.caption, CentralFilesSerialLabel.despatch.caption]).count == 3)
    }

    /// An enclosure's series can run the other way from the document's — a consul's despatch enclosed in
    /// an instruction — so enclosure homes alone name no direction for the document's own serial.
    @Test("Only enclosure homes → neutral")
    func serialLabelEnclosureOnlyNeutral() {
        let enclosure = CentralFilesResolution(
            classification: CentralFilesClassification(category: .consularDespatches, geoKeys: ["havana"],
                                                       confidence: .high, rationale: "test"),
            rolls: [], part: .enclosure(label: "1"))
        #expect(CentralFilesSerialLabel(homes: [enclosure]) == .neutral)
        #expect(CentralFilesSerialLabel(homes: []) == .neutral)
    }

    @Test("The document's home decides even when an enclosure's comes first")
    func serialLabelIgnoresEnclosures() throws {
        let enclosure = CentralFilesResolution(
            classification: CentralFilesClassification(category: .consularDespatches, geoKeys: ["havana"],
                                                       confidence: .high, rationale: "test"),
            rolls: [], part: .enclosure(label: "1"))
        let document = CentralFilesClassifier.documentHomes(
            header: AddresseeRuleTests.d573Header, dateline: AddresseeRuleTests.d573Dateline,
            sectionPath: AddresseeRuleTests.d573Path, index: try #require(CentralFilesIndexStore.shared),
            roster: AddresseeRuleTests.daytonRoster)
        #expect(!document.isEmpty, "fixture guard")
        #expect(CentralFilesSerialLabel(homes: [enclosure] + document) == .instruction)
    }
}
