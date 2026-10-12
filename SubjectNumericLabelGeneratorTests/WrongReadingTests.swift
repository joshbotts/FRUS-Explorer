// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import SubjectNumericLabelGeneratorCore

// MARK: - AreaWrongReadingTests

/// The wrong readings #1644 lists, each driven through the real resolver over the rows that
/// produced it.
///
/// The fixture is the smallest slice of the real sources that holds each trap: the names the
/// decimal tables and the appendix carry, the two appendix entries whose codes the scan misread,
/// and the printed codes that settle them.
@Suite("Area element — the wrong readings of #1644")
struct AreaWrongReadingTests {

    private let names = [
        "Ukraine", "United Kingdom", "United States", "Finland", "Cuba", "Vietnam", "Siam",
        "Soviet Union", "Union of Soviet Socialist Republics", "Niger, Republic of", "East Africa",
        "Near East", "Ghana", "Germany", "Uganda", "Iran (Azerbaijan)", "Africa", "Czechoslovakia",
    ]
    /// The common abbreviations appendix, with two of its entries as the scan gives them:
    /// `FLN` read `FIN`, and `CUSA` read `CUBA`.
    private let organizations = [
        "FIN": "Algerian National Liberation Front",
        "CUBA": "Council for U.S. Aid (Nationalist China)",
        "CHICOM": "Connnunist China",
        "AF": "Air Force (U.S.)",
        "JCS": "Joint Chiefs of Staff",
        "COAS": "Council for the Organization of American States",
    ]
    private let curated = ["CHICOM": "China (Communist)", "S VIET": "Vietnam, South",
                           "N VIET": "Vietnam, North"]
    /// The 1963 appendix's printed codes, keyed as ``AreaResolver/codeKey(_:)`` keys them.
    private let codes = [
        "UK": "United Kingdom", "FIN": "Finland", "CUBA": "Cuba", "US": "United States",
        "EAST NR": "Near East", "USSR": "Union of Soviet Socialist Republics",
        "CZ": "Canal Zone, U. S.", "AFR": "Africa",
    ]

    private func resolve(_ tail: String, refused: Set<String> = []) -> String? {
        AreaResolver.resolve(tail, names: names, organizations: organizations, curated: curated,
                             codes: codes, refused: refused)
    }

    @Test("UK is the United Kingdom, because the handbook prints it so")
    func ukIsNotUkraine() {
        #expect(resolve("UK") == "United Kingdom")
        #expect(resolve("UK-US") == "United Kingdom and United States")
        // The control: without the printed codes the first two letters of the shorter name win,
        // which is the reading the 1964–1973 schedule shipped.
        #expect(AreaResolver.resolve("UK", names: names, organizations: [:], curated: [:])
                    == "Ukraine")
    }

    @Test("A printed country code outranks a common abbreviation the scan misread")
    func aCountryOutranksAMisreadAbbreviation() {
        #expect(resolve("FIN") == "Finland")
        #expect(resolve("FIN-US") == "Finland and United States")
        #expect(resolve("CUBA") == "Cuba")
        #expect(resolve("CUBA-US") == "Cuba and United States")
        // The control: with the abbreviations first, as they were, the misread entry answers.
        #expect(AreaResolver.resolve("FIN", names: [], organizations: organizations, curated: [:])
                    == "Algerian National Liberation Front")
    }

    @Test("A code is found whichever side its qualifier is written on")
    func aPrintedCodeIsOrderFree() {
        #expect(AreaResolver.codeKey("NR EAST") == AreaResolver.codeKey("EAST NR"))
        #expect(resolve("NR EAST") == "Near East")
        // Read by the rules it was Niger and East Africa: NR are the initials of the first, and
        // EAST the first word of the second.
        #expect(AreaResolver.resolve("NR EAST", names: names, organizations: [:], curated: [:])
                    == "Niger, Republic of and East Africa")
    }

    @Test("Half of a paired tail is read as a whole tail is, the curated readings included")
    func aHalfConsultsTheCuratedReadings() {
        #expect(resolve("CHICOM") == "China (Communist)")
        #expect(resolve("CHICOM-US") == "China (Communist) and United States")
    }

    @Test("North Vietnam is not Vietnam")
    func northVietnam() {
        #expect(resolve("VIET N") == "Vietnam, North")
        #expect(resolve("VIET S") == "Vietnam, South")
        #expect(resolve("S VIET") == "Vietnam, South")
        // The first-few-letters form is one token's. Run together, VIET N is the first five
        // letters of Vietnam, which is what the shipped table read.
        #expect(AreaResolver.match("VIET N", names: ["Vietnam"]) == nil)
        #expect(AreaResolver.match("VIETN", names: ["Vietnam"]) == "Vietnam")
    }

    @Test("A compass qualifier written with a hyphen is still a qualifier")
    func aHyphenatedQualifier() {
        #expect(resolve("VIET-S") == "Vietnam, South")
    }

    @Test("Letters set apart are initials, not two first letters")
    func spacedInitials() {
        // U and S cover Soviet Union in full, and it is the shorter name.
        #expect(resolve("GHANA-U S") == "Ghana and United States")
        #expect(AreaResolver.match("U S", names: ["Soviet Union", "United States"])
                    == "United States")
    }

    @Test("One letter is not a place, whole or half")
    func oneLetterIsRefused() {
        // ORG 7 S and ORG 7 U are the Secretary's and the Under Secretary's files.
        #expect(resolve("S") == nil)
        #expect(resolve("U") == nil)
        #expect(resolve("VIET-B") == nil)
        #expect(AreaResolver.match("U", names: names) == "Uganda", "the reading the refusal stops")
    }

    @Test("A tail whose every reading is another thing's is left unread, as a half too")
    func aRefusedTailIsRefusedAsAHalf() {
        // IA is Inter-American; by its initials it is a row of the country list.
        #expect(resolve("IA") == "Iran (Azerbaijan)")
        #expect(resolve("IA", refused: ["IA"]) == nil)
        #expect(resolve("COAS-IA", refused: ["IA"]) == nil)
    }

    @Test("An agency's abbreviation is read where the appendix prints no such country code")
    func anAgencyTail() {
        // ORG 7 JCS: field trips by the Joint Chiefs of Staff.
        #expect(resolve("JCS") == "Joint Chiefs of Staff")
        #expect(resolve("AFR") == "Africa")
        #expect(resolve("CZ") == "Canal Zone, U. S.", "not the first two letters of Czechoslovakia")
    }

    @Test("A curated reading outranks the appendix's entry for the same letters")
    func aCuratedReadingOutranksTheAppendix() {
        // ORG 7 AF is field trips by the Department's officers for Africa, and the volumes that
        // cite it gloss it so. The appendix's AF is the Air Force.
        #expect(resolve("AF") == "Air Force (U.S.)", "the reading the curation stops")
        #expect(AreaResolver.resolve("AF", names: names, organizations: organizations,
                                     curated: ["AF": "Africa"], codes: codes) == "Africa")
        #expect(SubjectNumericLabelRunner.curatedAreas["AF"] == "Africa")
    }
}

// MARK: - CountryCodeTableTests

/// The name each printed country code is given (#1644).
@Suite("Country codes — the appendix's own name for each")
struct CountryCodeTableTests {

    private func table(_ rows: [(String, String, Bool)],
                       verified: Set<String> = []) -> [String: String] {
        CountryAbbreviationReader.codeNames(
            from: rows.map { (name: $0.0, code: $0.1, reverse: $0.2) }, verified: verified)
    }

    @Test("The code-first table's row names the code, less the places filed under it")
    func theReverseRowNamesTheCode() {
        let codes = table([
            ("England ( United Kingdom)", "UK", false),
            ("United Kingdom (England, Great Britain, Wales)", "UK", true),
        ])
        #expect(codes["UK"] == "United Kingdom")
    }

    @Test("A verified spelling is taken over the scan's")
    func aVerifiedSpellingWins() {
        let codes = table([("Belgimn", "BEL", true), ("Belgium", "BEL", false)],
                          verified: ["Belgium"])
        #expect(codes["BEL"] == "Belgium")
    }

    @Test("The verified name is the code's where the appendix only adds a formal ending")
    func theShortForm() {
        let verified: Set<String> = ["United States", "Kuwait"]
        let codes = table([("United States of America", "US", false),
                           ("Kuwait, state of", "KUW", true),
                           ("Congo, Republic of the", "THE CONGO", true)], verified: verified)
        #expect(codes["US"] == "United States")
        #expect(codes["KUW"] == "Kuwait")
        #expect(codes[AreaResolver.codeKey("THE CONGO")] == "Congo, Republic of the",
                "no verified name to shorten it to, so the two Congos stay apart")
    }

    @Test("A name the code cannot abbreviate belongs to another code")
    func aNameMustBeTheCodes() {
        // PORT INDIA, its first word lost to the scan, pairs INDIA with Portuguese India's name;
        // a row cut after its first letter pairs S with South Viet-Nam's.
        let codes = table([("Portuguese fudia paRr", "INDIA", false),
                           ("VIEr South Viet-Nam", "S", true)])
        #expect(codes["INDIA"] == nil)
        #expect(codes["S"] == nil)
        #expect(CountryAbbreviationReader.abbreviates("EAST NR", "Near East"))
        #expect(CountryAbbreviationReader.abbreviates("AUSTL", "Australia"))
        #expect(CountryAbbreviationReader.abbreviates("CZ", "Canal Zone, U. S."))
        #expect(!CountryAbbreviationReader.abbreviates("INDIA", "Portuguese fudia paRr"))
    }

    @Test("A visibly damaged name is not a code's, and the name-first table's plain row is")
    func aDamagedNameIsPassedOver() {
        let codes = table([("Aden Colony &ld Protectorate (Hadhramaut, Perim Island)", "ADEN", true),
                           ("Aden Colony and Protectorate", "ADEN", false),
                           ("Hadhramaut (Aden)", "ADEN", false)])
        #expect(codes["ADEN"] == "Aden Colony and Protectorate")
        #expect(!CountryAbbreviationReader.isCleanName("Det:lIl:l.S.!'k"))
        #expect(CountryAbbreviationReader.isCleanName("Canal Zone, U. S."))
    }

    @Test("The scan's marks at a name's ends are dropped, an initial's full stop kept")
    func trimming() {
        #expect(CountryAbbreviationReader.trimmedName("Canada.") == "Canada")
        #expect(CountryAbbreviationReader.trimmedName("Mexico'") == "Mexico")
        #expect(CountryAbbreviationReader.trimmedName("Canal Zone, U. S.") == "Canal Zone, U. S.")
        #expect(CountryAbbreviationReader.ownName("Canada (Alberta, British Columbia)") == "Canada")
    }
}

// MARK: - HandbookStructureTests

/// How the pages of a handbook are told apart (#1644).
@Suite("Handbook pages — index, appendix and outline")
struct HandbookStructureTests {

    private func page(_ lines: [PageLine]) -> HandbookPage {
        HandbookPage(width: 612, height: 792, lines: lines)
    }

    private func outlinePage(strip: String, entries: [String]) -> HandbookPage {
        var lines = [PageLine(text: strip, x: 430, y: 755, height: 9)]
        for (index, entry) in entries.enumerated() {
            lines.append(PageLine(text: entry, x: 84, y: 700 - Double(index) * 20, height: 9))
        }
        return page(lines)
    }

    @Test("An index page is known by its leaders, whatever its corner mark reads")
    func anIndexPageByItsLeaders() {
        let index = page((0..<6).map {
            PageLine(text: "BRANCH BANKS ••.•.••..••.••• FN \($0)", x: 60, y: 700 - Double($0) * 12,
                     height: 9)
        })
        #expect(OutlinePageReader.isIndexPage(index))
        // Two such lines is the most any page outside an index holds, in either handbook; three
        // are still short of the six that make an index page.
        let outline = page((0..<3).map {
            PageLine(text: "Final Salary Clearance......", x: 60, y: 700 - Double($0) * 12, height: 9)
        })
        #expect(!OutlinePageReader.isIndexPage(outline))
        #expect(OutlinePageReader.minimumLeaderLines == 6)
    }

    @Test("An index page is given to no category, by either pass")
    func anIndexPageTakesNoCategory() {
        // An index page whose top strip holds a category code, as its first entry does.
        var lines = [PageLine(text: "WATERWAY ACCESS TO BERLIN ••••••••• POL 38", x: 60, y: 750,
                              height: 9)]
        lines += (1..<7).map {
            PageLine(text: "\($0)-1 Aliens •••••••••••• V 11", x: 60, y: 750 - Double($0) * 12,
                     height: 9)
        }
        let book = Handbook(pages: [
            outlinePage(strip: "POL (p. 7)", entries: ["27 MILITARY OPERATIONS"]), page(lines),
        ])
        #expect(SubjectNumericLabelRunner.pageCodes(book) == [0: "POL"])
    }

    @Test("A page with no mark of its own is attributed by a category lent from elsewhere")
    func aLentCategoryAttributesAPage() {
        // The 1965 outline for AID: the code alone at the head of the page, no page number.
        let book = Handbook(pages: [outlinePage(strip: "RECORDS CLASSIFICATION AID",
                                                entries: ["10 SUPPORTING ASSISTANCE"])])
        #expect(SubjectNumericLabelRunner.pageCodes(book).isEmpty)
        #expect(SubjectNumericLabelRunner.pageCodes(book, vocabulary: ["AID"]) == [0: "AID"])
        let outlines = SubjectNumericLabelRunner.readOutlines(book, layout: .rightColumn,
                                                              vocabulary: ["AID"])
        #expect(outlines["AID"]?["10"]?.label == "SUPPORTING ASSISTANCE")
        // The guard is unchanged: a strip that names two categories is refused.
        #expect(SubjectNumericLabelRunner.pageCodes(book, vocabulary: ["AID", "RECORDS"]).isEmpty)
    }

    @Test("The scan's short reading of INCO is put right, on the corner and in the strip")
    func theMisreadCode() {
        #expect(OutlinePageReader.correctedCode("NCO") == "INCO")
        #expect(OutlinePageReader.correctedCode("POL") == "POL")
        let book = Handbook(pages: [
            outlinePage(strip: ".!NCO (p. 4)", entries: ["13 MARKETING & DISTRIBUTION"]),
            outlinePage(strip: "RECORDS CLASSIFICATION I NCO", entries: ["14 PRICES"]),
        ])
        #expect(SubjectNumericLabelRunner.pageCodes(book) == [0: "INCO", 1: "INCO"])
    }

    @Test("The appendix's first page is found though its mark reads Corn. for Com.")
    func theAppendixsFirstPage() {
        let misread = page([PageLine(text: "Corn. Abbrev. (p. 1)", x: 442, y: 754, height: 8.4)])
        let read = page([PageLine(text: "Com. Abbrev. (p. 2)", x: 442, y: 754, height: 8.4)])
        let other = page([PageLine(text: "Ctry. Abbrev. (p. 2)", x: 442, y: 754, height: 8.4)])
        #expect(SubjectNumericLabelRunner.isAbbreviationPage(misread))
        #expect(SubjectNumericLabelRunner.isAbbreviationPage(read))
        #expect(!SubjectNumericLabelRunner.isAbbreviationPage(other))
    }

    @Test("A column of the appendix begins where two or more codes do, not wherever a line does")
    func theAppendixsColumns() {
        // The last page of the 1963 appendix: a full left column, two entries in the right one,
        // and one line that begins mid-page.
        var lines = (0..<5).map {
            PageLine(text: "VHF", x: 70.4 + Double($0) * 0.3, y: 700 - Double($0) * 20, height: 9.6)
        }
        lines.append(PageLine(text: "XMB", x: 323.81, y: 712, height: 9.2))
        lines.append(PageLine(text: "Zebra - Greenwich Meridian Time", x: 323.06, y: 648, height: 9.6))
        lines.append(PageLine(text: "in Africa South of Sahara", x: 219.2, y: 576, height: 9.6))
        #expect(SubjectNumericLabelRunner.abbreviationColumnStarts(lines) == [70.4, 323.06])
        // The control: one stray beginning between the columns closes the gap that used to find
        // them, and the page read as one column.
        let every = lines.filter { SubjectNumericLabelRunner.opensWithCode($0.text) }.map(\.x).sorted()
        #expect(OutlinePageLayout.columnStarts(every) == [70.4])
    }

    @Test("A section letter is not the last word of the entry above it")
    func theSectionLetter() {
        #expect(SubjectNumericLabelRunner.isSectionLetter(PageLine(text: "G", x: 422, y: 545, height: 16.1)))
        #expect(!SubjectNumericLabelRunner.isSectionLetter(PageLine(text: "E", x: 70, y: 545, height: 9.6)))
        #expect(!SubjectNumericLabelRunner.isSectionLetter(PageLine(text: "GA", x: 316, y: 517, height: 16)))
    }

    @Test("An organization's name is its entry up to the gloss")
    func theOrganizationsName() {
        #expect(SubjectNumericLabelRunner.organizationName(
            "Central Treaty Organization (Iran, Pakistan, U.S. and Turkey). Headquarters in Ankara.")
                    == "Central Treaty Organization")
        #expect(SubjectNumericLabelRunner.organizationName("Security Council (UN)")
                    == "Security Council (UN)")
        #expect(SubjectNumericLabelRunner.organizationName("Federal Aviation Agency (u.s.)")
                    == "Federal Aviation Agency (U.S.)")
        #expect(SubjectNumericLabelRunner.organizationName("Office of Secretary of Defense (U. S. )")
                    == "Office of Secretary of Defense (U.S.)")
        #expect(SubjectNumericLabelRunner.organizationName(
            "European Monetary Agreement. A monetary arrangement among OEEC members")
                    == "European Monetary Agreement")
    }
}

// MARK: - SubjectCurationTests

/// The hand-checked subject labels, and the refusal of what the capture could not read (#1644).
@Suite("Subject labels — curated readings and the capture's unread mark")
struct SubjectCurationTests {

    private func source(_ label: String) -> SubjectNumericLabelRunner.LabelSource {
        .init(label: label, page: 25, y: 633)
    }

    @Test("A label holding the capture's mark stops the run until it is read")
    func anUnreadMarkIsRefused() {
        var outlines = ["ZZ": ["10": source("PRESIDENT'S BUDG~T")]]
        #expect(throws: GenerationError.self) {
            try SubjectNumericLabelRunner.curate(&outlines, schedule: "no-such-schedule")
        }
        var clean = ["ZZ": ["10": source("PRESIDENT'S BUDGET")]]
        #expect(throws: Never.self) {
            try SubjectNumericLabelRunner.curate(&clean, schedule: "no-such-schedule")
        }
    }

    @Test("A curated reading corrects a label, adds one the parse could not open, and refuses one")
    func curationCorrectsAddsAndRefuses() throws {
        var outlines = [
            "AE": ["11": source("RESEARCH & DEVELOPMENT 11-~ Isotopes Development")],
            "BUD": ["10": source("PRESIDENT'S BUDG~T"),
                    "14-2": source("Annual Authorizations l4~3 Allocations (Transfers Out)")],
            "PER": ["11-4": source("Final Salary Clearance ~';......")],
            "POL": ["15-6": source("National Symbols. Anthem~")],
            "PPT": ["13": source("Marriage of Citizens Abroad -------------------~ Belgium")],
        ]
        try SubjectNumericLabelRunner.curate(&outlines, schedule: "1963")
        #expect(outlines["BUD"]?["10"]?.label == "PRESIDENT'S BUDGET")
        #expect(outlines["AE"]?["11"]?.label == "RESEARCH & DEVELOPMENT")
        #expect(outlines["AE"]?["11-1"]?.label == "Isotopes Development",
                "the row whose designator the capture could not read")
        #expect(outlines["BUD"]?["14-3"]?.label == "Allocations (Transfers Out)")
        #expect(outlines["BUD"]?["10"]?.page == 25, "a corrected label keeps its place on the scan")

        var later: [String: [String: SubjectNumericLabelRunner.LabelSource]] = [
            "SCI": ["44-49": source("The")], "PS": ["1": source("John J.")],
            "POL": ["33-8": source("law af the Sea")],
            "EP": ["1": source("EMERGENCY RElOCATION PROGRAM"), "1-5": source("Emergency Action Documents (EAD)")],
        ]
        try SubjectNumericLabelRunner.curate(&later, schedule: "1964-1973")
        #expect(later["SCI"]?["44-49"] == nil)
        #expect(later["PS"]?["1"] == nil)
        #expect(later["POL"]?["33-8"]?.label == "Law of the Sea")
        // The capture read the 7 of five EP designators as 1.
        #expect(later["EP"]?["1"]?.label == "GENERAL POLICY. PLANS. COORDINATION.")
        #expect(later["EP"]?["7"]?.label == "EMERGENCY RELOCATION PROGRAM")
        #expect(later["EP"]?["1-5"] == nil)
        #expect(later["EP"]?["7-5"]?.label == "Emergency Action Documents (EAD)")
    }

    @Test("A row whose designator the capture misread is given back to its own entry")
    func aMisreadDesignatorsRow() throws {
        // The 1965 defense outline: the 1 of DEF 1 unread and the 7 of VISITS. MISSIONS. read 1,
        // and a first subdivision read `15-l`, which is no designator.
        var outlines: [String: [String: SubjectNumericLabelRunner.LabelSource]] = [
            "DEF": ["1": source("VISITS. MISSIONS. S EXHIBITIONS. SHOWS. PARADES."),
                    "15": source("BASES. IMST ALLATIOMS. 15-l Policy. Plans. Background.")],
            "SOC": ["14": source("HUMAN RIGHTS. RACE RELATIONS. 14-l General Pol")],
            "POL": ["32-1": source("Territory & Boundary Disputes. Violations.")],
        ]
        try SubjectNumericLabelRunner.curate(&outlines, schedule: "1964-1973")
        #expect(outlines["DEF"]?["1"]?.label == "POLICY. PLANS. READINESS.")
        #expect(outlines["DEF"]?["7"]?.label == "VISITS. MISSIONS.")
        #expect(outlines["DEF"]?["8"]?.label == "EXHIBITIONS. SHOWS. PARADES.")
        #expect(outlines["DEF"]?["15"]?.label == "BASES. INSTALLATIONS.")
        #expect(outlines["DEF"]?["15-1"]?.label == "Policy. Plans. Background.")
        #expect(outlines["SOC"]?["14"]?.label == "HUMAN RIGHTS. RACE RELATIONS.")
        #expect(outlines["SOC"]?["14-1"]?.label == "General Policy.")
        // A label that wraps onto a line set at the instructions' indent.
        #expect(outlines["POL"]?["32-1"]?.label
                    == "Territory & Boundary Disputes. Violations. Incidents.")
    }

    @Test("The list of administrative subjects is curated as the outlines are")
    func theOrganizationSubjectsAreCurated() throws {
        // A speck before `8-4` and `16-6` kept each row from opening.
        var list = ["8-3": source("Secretariat - 8-4 Committees. Working Groups."),
                    "16-5": source("Public Inquiries & Opinion.16-6 Nongovernmental Liaison")]
        try SubjectNumericLabelRunner.curate(organizationSubjects: &list, schedule: "1963")
        #expect(list["8-3"]?.label == "Secretariat")
        #expect(list["8-4"]?.label == "Committees. Working Groups.")
        #expect(list["16-5"]?.label == "Public Inquiries & Opinion")
        #expect(list["16-6"]?.label == "Nongovernmental Liaison")
        #expect(list["8-3"]?.page == 25, "a corrected entry keeps its place on the scan")
        // The other schedule's list keeps what it read, and gains the entries the capture did not
        // open: its first, and three of a last page whose corner mark is short of its page number.
        var later = ["8-3": source("Secretariat")]
        try SubjectNumericLabelRunner.curate(organizationSubjects: &later, schedule: "1964-1973")
        #expect(later["8-3"] == source("Secretariat"))
        #expect(later["1"]?.label == "ADMINISTRATION (GENERAL)")
        #expect(later["22-2"]?.label == "Foreign Country Delegations. Representatives.")
        #expect(later.count == 5)
        // A schedule the curation does not name is left exactly as read.
        var other = ["8-3": source("Secretariat")]
        try SubjectNumericLabelRunner.curate(organizationSubjects: &other, schedule: "no-such-schedule")
        #expect(other == ["8-3": source("Secretariat")])
        var marked = ["3": source("MEETI~GS")]
        #expect(throws: GenerationError.self) {
            try SubjectNumericLabelRunner.curate(organizationSubjects: &marked,
                                                 schedule: "no-such-schedule")
        }
    }

    @Test("Every curated key names a category and a designator, and no curated label holds the mark")
    func theCuratedMapsAreWellFormed() {
        var keys = 0
        for (_, entries) in SubjectNumericLabelRunner.curatedSubjects {
            for (key, label) in entries {
                keys += 1
                #expect(key.split(separator: " ").count == 2, "\(key)")
                #expect(label?.contains(SubjectNumericLabelRunner.unreadMark) != true, "\(key)")
            }
        }
        #expect(keys > 60, "the maps hold \(keys) keys")
        #expect(SubjectNumericLabelRunner.refusedAreas == ["EA", "FAA", "IA", "IS"])
        #expect(SubjectNumericLabelRunner.misreadAbbreviations == ["FM"])
    }
}

// MARK: - ShippedLabelTableTests

/// The table in the repository, read as the app reads it (#1644).
///
/// The handbooks are not in the repository, so no test here can regenerate the table. These pin
/// what a regeneration must not undo: the readings #1644 put right, and the three properties
/// that would have caught them.
@Suite("Shipped subject-numeric labels — what #1644 put right")
struct ShippedLabelTableTests {

    private struct Table: Decodable {
        struct Schedule: Decodable {
            let id: String
            let startYear: Int
            let endYear: Int
            let source: String
            let categories: [String: String]
            let subjects: [String: [String: String]]
            let organizationSubjects: [String: String]
            let abbreviations: [String: String]
            let areas: [String: String]
        }
        struct Coverage: Decodable {
            struct Measurement: Decodable, Equatable {
                let scheduleId: String
                let corpusKeys: Int
                let namedKeys: Int
                let corpusDocuments: Int
                let namedDocuments: Int
                let areaKeys: Int
                let namedAreaKeys: Int
                let areaDocuments: Int
                let namedAreaDocuments: Int
            }
            let measured: [Measurement]
            let measuredAgainst: String
            let unnamedCategories: [String]
        }
        let schedules: [Schedule]
        let coverage: Coverage
    }

    private func resource(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer/Resources/\(name)")
    }

    private func table() throws -> Table {
        try JSONDecoder().decode(Table.self,
                                 from: Data(contentsOf: resource("subject-numeric-labels.json")))
    }

    @Test("The readings the issue lists are the right ones, under both schedules")
    func theListedReadings() throws {
        let table = try table()
        #expect(table.schedules.map(\.id) == ["1963", "1964-1973"])
        for schedule in table.schedules {
            let areas = schedule.areas
            #expect(areas["UK"] == "United Kingdom", "\(schedule.id)")
            #expect(areas["UK-US"] == "United Kingdom and United States", "\(schedule.id)")
            #expect(areas["UAR"] == "United Arab Republic", "\(schedule.id)")
            #expect(areas["USSR"] == "Union of Soviet Socialist Republics", "\(schedule.id)")
            #expect(areas["US-USSR"] == "United States and Union of Soviet Socialist Republics",
                    "\(schedule.id)")
            #expect(areas["FIN"] == "Finland", "\(schedule.id)")
            #expect(areas["CUBA"] == "Cuba", "\(schedule.id)")
            #expect(areas["NR EAST"] == "Near East", "\(schedule.id)")
            #expect(areas["CHICOM-US"] == "China (Communist) and United States", "\(schedule.id)")
            #expect(areas["IA"] == nil, "\(schedule.id)")
            #expect(areas["VIET S"] == "Vietnam, South", "\(schedule.id)")
            #expect(areas["VIET N"] == "Vietnam, North", "\(schedule.id)")
        }
    }

    /// `ORG 7` is *VISITS*, and its files are named for whoever travelled. Each reading here
    /// was held against the documents that cite the file, and against the gloss the citing
    /// volume's own list of sources gives it.
    @Test("The files under ORG 7 read as the volumes that cite them gloss them")
    func theVisitsFiles() throws {
        for schedule in try table().schedules {
            let areas = schedule.areas
            #expect(schedule.subjects["ORG"]?["7"] == "VISITS", "\(schedule.id)")
            #expect(areas["AF"] == "Africa", "\(schedule.id): not the appendix's Air Force")
            #expect(areas["EA"] == nil, "\(schedule.id): a bureau, not East Africa")
            #expect(areas["FAA"] == nil, "\(schedule.id): two things in two files")
            #expect(areas["TR"] == "Travel Request", "\(schedule.id)")
            #expect(areas["JCS"] == "Joint Chiefs of Staff", "\(schedule.id)")
            // The Secretary, the Under Secretary and the Deputy Secretary: one letter is no place.
            #expect(areas["S"] == nil && areas["U"] == nil && areas["D"] == nil, "\(schedule.id)")
        }
    }

    @Test("IND is the Indian Ocean, as the volume that cites it says, and India is INDIA")
    func theIndianOcean() throws {
        for schedule in try table().schedules {
            #expect(schedule.areas["IND"] == "Indian Ocean", "\(schedule.id)")
            #expect(schedule.areas["IND-US"] == "Indian Ocean and United States", "\(schedule.id)")
            #expect(schedule.areas["INDIA"] == "India", "\(schedule.id)")
            #expect(schedule.areas["INDIA-PAK"] == "India and Pakistan", "\(schedule.id)")
        }
    }

    /// Labels no comparison of old with new would have shown, because they had not changed
    /// since #1211: each said another entry's words, or lost a line of its own, over the
    /// documents that cite it. Found by reading every label a document cites, and each read on
    /// the scan.
    @Test("The labels the corpus cites say their own entry's words")
    func theCitedLabelsSayTheirOwnWords() throws {
        let schedules = try table().schedules
        let earlier = schedules[0], later = schedules[1]
        #expect(later.subjects["DEF"]?["1"] == "POLICY. PLANS. READINESS.", "61 documents")
        #expect(later.subjects["DEF"]?["7"] == "VISITS. MISSIONS.")
        #expect(later.subjects["DEF"]?["15"] == "BASES. INSTALLATIONS.", "86 documents")
        #expect(later.subjects["DEF"]?["15-1"] == "Policy. Plans. Background.")
        #expect(later.subjects["SOC"]?["14"] == "HUMAN RIGHTS. RACE RELATIONS.")
        #expect(later.subjects["SOC"]?["14-1"] == "General Policy.", "68 documents")
        #expect(later.subjects["POL"]?["5"] == "LAW")
        #expect(later.subjects["POL"]?["31-1"] == "Air Disputes. Violations.")
        #expect(later.subjects["POL"]?["32-1"]
                    == "Territory & Boundary Disputes. Violations. Incidents.", "209 documents")
        #expect(later.subjects["POL"]?["27-7"] == "Prisoners of War. Hostages. Civilian Internees.")
        #expect(later.subjects["ORG"]?["8"] == "ESTABLISHMENT. FUNCTIONS. REORGANIZATION.")
        #expect(later.subjects["ORG"]?["11"] == "INSPECTIONS")
        #expect(later.subjects["SCI"]?["11-1"] == "Area Research Programs")
        #expect(earlier.subjects["POL"]?["14"] == "ELECTIONS", "85 documents")
        #expect(earlier.organizationSubjects["8-3"] == "Secretariat")
        #expect(earlier.organizationSubjects["8-4"] == "Committees. Working Groups.")
        #expect(later.organizationSubjects["8-3"] == "Secretariat")
    }

    /// The category and designator of every numbered key the corpus cites, by the generator's own
    /// division.
    private func citedDesignators() throws -> Set<[String]> {
        let usage = try JSONSerialization.jsonObject(
            with: Data(contentsOf: resource("collection-usage-index.json"))) as? [String: Any]
        let keys = try #require(usage?["classKeys"] as? [String])
        return Set(keys.compactMap { key in
            SubjectNumericLabelRunner.splitSubjectNumeric(key).map { [$0.0, $0.1] }
        })
    }

    /// The letter-level damage the capture leaves in a label, by the five shapes that can be
    /// told from the text alone. A wrong letter inside a word (*ECTIOMS*, *Sole*) cannot, which
    /// is why every cited label was read on the scan and the worst are pinned by name below.
    ///
    /// - Parameters:
    ///   - label: A subject label.
    ///   - isHeading: Whether its designator is a whole number, whose label both handbooks set
    ///     in capitals.
    /// - Returns: What is wrong with it, or nothing.
    private func damage(in label: String, isHeading: Bool) -> [String] {
        var found: [String] = []
        func has(_ pattern: String) -> Bool {
            label.range(of: pattern, options: .regularExpression) != nil
        }
        if has(#"[a-z][A-Z]"#) { found.append("a lower-case letter runs into a capital") }
        let words: Set<String> = ["a", "of", "in", "to", "at", "by", "or", "on", "re", "as", "an"]
        let pieces = label.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if pieces.contains(where: { $0.count <= 2 && $0 == $0.lowercased() && !words.contains($0) }) {
            found.append("a piece of a broken word")
        }
        // `F inancia I`, `Country T earn`: the first letter of a word, set apart from it. A, E,
        // I and U stand alone in labels as words, numerals and initials (`E & E`, `Title I`).
        if has(#"(^| )[B-DF-HJ-TV-Z]( |$)"#) { found.append("a capital consonant standing alone") }
        // `&:`, and a full stop run into the word after it (`CONFE.RENCES`, `MONEY.CURRENCY.`).
        if has(#"&:|[A-Za-z]\.[A-Za-z]{2}"#) { found.append("a mark the page does not print") }
        if isHeading, label.contains(where: \.isLowercase) {
            found.append("a lower-case letter in a heading")
        }
        return found
    }

    @Test("No label a document cites carries the capture's letter damage")
    func theCitedLabelsAreClean() throws {
        let cited = try citedDesignators()
        var checked = 0
        for schedule in try table().schedules {
            for pair in cited {
                guard let label = schedule.subjects[pair[0]]?[pair[1]] else { continue }
                checked += 1
                // INCO 17 and 18 are the commodity breakdown's own entries, which that list
                // sets in lower case (`17 Trade`).
                let isHeading = !pair[1].contains("-") && !(pair[0] == "INCO" && ["17", "18"].contains(pair[1]))
                #expect(damage(in: label, isHeading: isHeading) == [],
                        "\(schedule.id) \(pair[0]) \(pair[1]): \(label)")
            }
        }
        // 279 under 1963 and 252 under 1964–1973 when the follow-up to #1644 read them.
        #expect(checked > 500, "checked \(checked) cited labels")
        // The control: the check does see the damage it is for.
        #expect(damage(in: "ORGANIZATIONS & AliGNMENTS", isHeading: true).count == 2)
        #expect(damage(in: "Sale. Purc ha se. Transfer.", isHeading: false) == ["a piece of a broken word"])
        #expect(damage(in: "El ECTIOMS", isHeading: true) == ["a lower-case letter in a heading"])
        #expect(damage(in: "Country T earn", isHeading: false) == ["a capital consonant standing alone"])
        #expect(damage(in: "MONEY.CURRENCY.", isHeading: true) == ["a mark the page does not print"])
        #expect(damage(in: "Use of Foreign Country Forces", isHeading: false) == [])
        #expect(damage(in: "Shipments of Non-U.S. Origin Goods", isHeading: false) == [])
        #expect(damage(in: "E & E Policy. Plans.", isHeading: false) == [])
    }

    /// Wrong letters inside a word, which no shape gives away, and a label cut short that read
    /// as whole English. Each was read on the scan.
    @Test("The most cited labels spell their words as the page does")
    func theCitedLabelsAreSpeltAsPrinted() throws {
        let schedules = try table().schedules
        let earlier = schedules[0], later = schedules[1]
        #expect(later.subjects["DEF"]?["12-5"] == "Procurement. Sale.", "226 documents, read Sole")
        #expect(later.subjects["POL"]?["14"] == "ELECTIONS", "85 documents, read El ECTIOMS")
        #expect(later.subjects["POL"]?["3"] == "ORGANIZATIONS & ALIGNMENTS")
        #expect(later.subjects["POL"]?["23"] == "INTERNAL SECURITY. COUNTER-INSURGENCY.")
        #expect(later.subjects["POL"]?["13"] == "NON-PARTY BLOCS", "read NOH-PARTY")
        #expect(later.subjects["POL"]?["12-1"] == "Policy. Plans. Ideology.", "read Pions")
        #expect(later.subjects["SP"]?["10"] == "SPACE FLIGHT & EXPLORATION")
        #expect(later.subjects["CUL"]?["11"] == "LIBRARIES & CENTERS", "read CEHTERS")
        #expect(later.subjects["FN"]?["2"] == "GENERAL REPORTS & STATISTICS", "read GEMERAL")
        #expect(later.subjects["STR"]?["5"] == "EXPORT CONTROL REGULATIONS & PROCEDURES")
        #expect(later.subjects["AV"]?["12-1"] == "Production. Repair.", "a comma for a full stop")
        #expect(earlier.subjects["POL"]?["17"] == "DIPLOMATIC & CONSULAR REPRESENTATION")
        #expect(earlier.subjects["POL"]?["8"] == "NEUTRALISM. NON-ALIGNMENT.", "cut short of its second line")
        #expect(earlier.subjects["DEF"]?["19-3"] == "Equipment & Supplies (Mil. Assistance)")
        #expect(earlier.subjects["INT"]?["8"] == "DISSEMINATION OF INTELLIGENCE")
        // The organizations' list under 1964–1973: its first entry and its last page.
        #expect(later.organizationSubjects["1"] == "ADMINISTRATION (GENERAL)")
        #expect(later.organizationSubjects["17-1"] == "Headquarters Site. Building.")
        #expect(later.organizationSubjects["22-2"] == "Foreign Country Delegations. Representatives.")
        #expect(earlier.organizationSubjects["22-2"] == "Foreign Country Delegations")
    }

    @Test("AID has an outline under 1964–1973, and is no organization's file")
    func aidHasItsOutline() throws {
        let later = try #require(try table().schedules.last)
        #expect(later.subjects["AID"]?["15"] == "PL 480. FOOD FOR PEACE PROGRAM")
        #expect(later.subjects["AID"]?["8"] == "GRANTS. TECHNICAL ASSISTANCE.")
        #expect(later.abbreviations["AID"] == nil)
        #expect(later.subjects["PET"]?["10"] == "RESOURCES. OIL FIELDS.")
        #expect(later.subjects["POL"]?["33-8"] == "Law of the Sea")
        #expect(later.subjects["NCO"] == nil, "the scan's short reading of INCO")
    }

    @Test("No label holds the capture's mark for a character it could not read")
    func noLabelHoldsTheUnreadMark() throws {
        var read = 0
        for schedule in try table().schedules {
            let labels = schedule.subjects.values.flatMap(\.values)
                + schedule.organizationSubjects.values + schedule.abbreviations.values
                + schedule.areas.values
            read += labels.count
            #expect(labels.filter { $0.contains("~") } == [], "\(schedule.id)")
        }
        #expect(read > 4_000, "read \(read) labels")
    }

    @Test("The two schedules name a country alike, since the list of country codes is one list")
    func theSchedulesAgreeOnAreas() throws {
        let schedules = try table().schedules
        #expect(schedules[0].areas == schedules[1].areas)
        #expect(schedules[0].areas.count > 400)
    }

    @Test("The abbreviations shipped are organizations the corpus cites, with no outline")
    func theAbbreviationsAreTheCitedOrganizations() throws {
        for schedule in try table().schedules {
            #expect(!schedule.abbreviations.isEmpty)
            #expect(schedule.abbreviations.count < 20, "\(schedule.abbreviations.count)")
            #expect(schedule.abbreviations.keys.allSatisfy { schedule.subjects[$0] == nil })
            #expect(schedule.abbreviations["UN"] == "United Nations")
            #expect(schedule.abbreviations["FM"] == nil)
        }
    }

    /// The block the issue found describing an older index, held to the index in the repository.
    ///
    /// Counted again by the generator's own ``SubjectNumericLabelRunner/measure(_:usagePath:)``
    /// over the shipped schedules, and not compared by build stamp: a usage index regenerated
    /// with the same keys and the same documents owes this table nothing, and one that gains a
    /// key or a tail moves a figure here. `areas` holds the tails the corpus writes, so a new
    /// tail is also a row the table does not have yet.
    @Test("The coverage block is what the generator counts over the usage index in the repository")
    func theCoverageBlockIsCurrent() throws {
        let table = try table()
        let schedules = table.schedules.map {
            Schedule(id: $0.id, startYear: $0.startYear, endYear: $0.endYear, source: $0.source,
                     categories: $0.categories, subjects: $0.subjects,
                     organizationSubjects: $0.organizationSubjects,
                     abbreviations: $0.abbreviations, areas: $0.areas)
        }
        let counted = try SubjectNumericLabelRunner.measure(
            schedules, usagePath: resource("collection-usage-index.json").path)
        let owed: Comment = """
            The usage index in the repository no longer gives the figures this table states. \
            Regenerate subject-numeric-labels.json after collection-usage-index.json (the \
            generator's entry in Planning/Generators-Runbook.md), and read each label that \
            changes against the handbook before it ships.
            """
        #expect(counted.count == 2)
        #expect(table.coverage.measured == counted.map {
            .init(scheduleId: $0.scheduleId, corpusKeys: $0.corpusKeys, namedKeys: $0.namedKeys,
                  corpusDocuments: $0.corpusDocuments, namedDocuments: $0.namedDocuments,
                  areaKeys: $0.areaKeys, namedAreaKeys: $0.namedAreaKeys,
                  areaDocuments: $0.areaDocuments, namedAreaDocuments: $0.namedAreaDocuments)
        }, owed)
        #expect(Set(table.coverage.unnamedCategories) == Set(counted.flatMap(\.unnamed)), owed)
        #expect(table.coverage.measuredAgainst.hasPrefix("collection-usage-index.json generated 20"))
        for measurement in table.coverage.measured {
            // A count of nothing would agree with a table of nothing.
            #expect(measurement.corpusKeys > 1_500 && measurement.areaKeys > 1_500)
            #expect(measurement.namedAreaKeys * 10 > measurement.areaKeys * 9,
                    "\(measurement.namedAreaKeys) of \(measurement.areaKeys) keys' areas named")
        }
    }
}
