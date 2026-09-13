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
