// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import DecimalClassLabelGeneratorCore

// MARK: - DecimalClassKeyTests

/// The decomposition rule that turns `761.62` into "political relations between the Soviet Union
/// and Germany" (#828).
///
/// These run against a hand-built schedule rather than the parsed artifact on purpose: the rule is
/// what the app will apply to every class key it draws, and it has to be pinned independently of
/// whether a particular scan parsed well.
@Suite("Decimal class keys — decomposition")
struct DecimalClassKeyTests {

    /// A miniature 1910–49 schedule carrying the codes the tests name.
    private var schedule1949: DecimalClassLabels.Schedule {
        DecimalClassLabels.Schedule(
            id: "1910-1949", startYear: 1910, endYear: 1949, source: "test",
            classes: ["7": "Political Relations of States", "8": "Internal Affairs of States"],
            countryArrangedClasses: ["6", "7", "8"], relationsClasses: ["7"],
            countries: ["61": "Union of Soviet Socialist Republics", "62": "Germany",
                        "11": "United States", "51": "France", "51r": "Algeria", "91": "Iran",
                        "93": "China"],
            subjects: ["8": ["11": "Public order, safety, health, works"]],
            sources: .init(schedule: "test", countries: "test"))
    }

    /// The 1950 renumbering, where the same digits mean something else.
    private var schedule1959: DecimalClassLabels.Schedule {
        DecimalClassLabels.Schedule(
            id: "1950-1959", startYear: 1950, endYear: 1959, source: "test",
            classes: ["7": "Internal Political and National Defense Affairs"],
            countryArrangedClasses: ["3", "4", "5", "6", "7", "8", "9"],
            relationsClasses: ["6"],
            countries: ["88": "Iran", "62": "Germany"],
            subjects: [:],
            sources: .init(schedule: "test", countries: "test"))
    }

    @Test("A relations key reads as two countries, not a country and a subject")
    func relationsKey() throws {
        let key = try #require(DecimalClassKey.decompose("761.62", in: schedule1949))
        #expect(key.classDigit == "7")
        #expect(key.countryNumber == "61")
        #expect(key.secondCountry == "62", """
            `761.62` is the political relations of the Soviet Union with Germany. Read as a \
            subject suffix it would gloss as a topic that does not exist.
            """)
        #expect(key.subject == nil)
    }

    @Test("An internal-affairs key reads as a country and a subject")
    func subjectKey() throws {
        let key = try #require(DecimalClassKey.decompose("811.114", in: schedule1949))
        #expect(key.countryNumber == "11")
        #expect(key.subject == "114")
        #expect(key.secondCountry == nil, """
            `114` is not a country number in this schedule, so the suffix must read as a subject. \
            The two shapes are otherwise identical.
            """)
    }

    @Test("A lettered colonial number resolves")
    func letteredCountry() throws {
        // Colonies were numbered off the parent — France 51, Algeria 51r — and 270 of the 353
        // codes in the 1910–49 column carry a letter. A digits-only reading loses most of them.
        let key = try #require(DecimalClassKey.decompose("851r.00", in: schedule1949))
        #expect(key.countryNumber == "51r")
        #expect(key.subject == "00")
    }

    @Test("A key resolves only in a class the schedule arranges by country")
    func nonCountryClass() {
        // Class 1 is administration of the US government — `111.11` is not "country 11".
        #expect(DecimalClassKey.decompose("111.11", in: schedule1949) == nil)
    }

    @Test("A country the schedule does not carry yields nothing, never a guess")
    func unknownCountry() {
        #expect(DecimalClassKey.decompose("799.1", in: schedule1949) == nil, """
            A wrong gloss on an archival citation is worse than a bare number: the reader cannot \
            tell it is wrong.
            """)
    }

    @Test("The same key decomposes differently in the two schedules — or not at all")
    func eraScoping() throws {
        // Iran is 91 before 1950 and 88 after. `891.00` is Iran's internal affairs in the earlier
        // schedule and resolves to no country at all in the later one.
        let early = try #require(DecimalClassKey.decompose("891.00", in: schedule1949))
        #expect(early.countryNumber == "91")
        #expect(DecimalClassKey.decompose("891.00", in: schedule1959) == nil, """
            Resolving a 1910–49 key against the 1950s table would name the wrong country with \
            full confidence — the failure mode era-scoping exists to prevent.
            """)
        let late = try #require(DecimalClassKey.decompose("888.00", in: schedule1959))
        #expect(late.countryNumber == "88")
    }

    @Test("Only a relations class reads its suffix as a second country")
    func relationsClassesAreASubset() throws {
        // `893.51` is CHINA'S INTERNAL AFFAIRS, subject .51 — not "China and France". Class 8 is
        // arranged by country and its keys are shaped exactly like class 7's, so the reading is a
        // property of the schedule and cannot be inferred from the key. Reading every
        // country-arranged class as relations produced exactly that mislabel.
        let internalAffairs = try #require(DecimalClassKey.decompose("893.51", in: schedule1949))
        #expect(internalAffairs.countryNumber == "93")
        #expect(internalAffairs.secondCountry == nil, """
            Class 8 is Internal Affairs of States. A suffix that merely looks like a country code \
            is a subject here, and glossing it as a second nation invents a relationship.
            """)
        #expect(internalAffairs.subject == "51")

        // The same shape in class 7 IS two countries.
        let relations = try #require(DecimalClassKey.decompose("793.51", in: schedule1949))
        #expect(relations.secondCountry == "51")
    }

    @Test("A schedule knows which years it governs")
    func scheduleSpan() {
        #expect(schedule1949.governs(year: 1910))
        #expect(schedule1949.governs(year: 1949))
        #expect(!schedule1949.governs(year: 1950), "the renumbering is a hard boundary")
        #expect(schedule1959.governs(year: 1950))
    }

    @Test("Malformed keys are refused rather than partially read")
    func malformed() {
        for key in ["", "POL 27 VIET S", "abc", ".72", "7"] {
            #expect(DecimalClassKey.decompose(key, in: schedule1949) == nil, "\(key) decomposed")
        }
    }
}

// MARK: - NestedSubjectTests

/// The class-8 subdivision tree — the children the manual writes without repeating their class
/// (#828 follow-up).
///
/// These drive the real parser over hand-built manual text rather than asserting against the
/// shipped artifact, so each trap is pinned by the shape that causes it. Every fixture below is
/// transcribed from the 1910–49 manual; the line numbers in the comments are its own.
@Suite("Decimal class labels — nested class-8 subjects")
struct NestedSubjectTests {

    /// Wraps `body` in the heading and terminator `classBody` looks for.
    private func manual(_ body: String) -> String {
        "Class 7\n700 Political relations of states.\nClass 8\nInternal Affairs of States\n"
            + body + "\nCountry Numbers\n51 France.\n"
    }

    @Test("A bare child inherits the class from the stem above it")
    func childrenInheritTheClass() {
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.42 Education.
            .421 Academic.
            .4211 Popular.
            .428 Libraries.
            """), ofClass: "8")
        #expect(subjects["42"] == "Education")
        #expect(subjects["421"] == "Academic", """
            The manual states the class once and prints the tree beneath it bare. A pattern \
            demanding `8**.` on every entry sees 61 of several hundred.
            """)
        #expect(subjects["4211"] == "Popular")
        #expect(subjects["428"] == "Libraries")
    }

    @Test("A cross-reference is not a definition")
    func crossReferencesAreNotDefinitions() {
        // The failure that killed the first attempt at this: splitting the text at every suffix
        // occurrence turns each mid-entry pointer into a fragment whose remainder is the NEXT
        // entry's prose, and first-writer-wins locks it in — `8**.42` came back as "Division of
        // Trade Agreements". Anchoring at the line start is what removes the failure mode.
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.42 Education.
            For apprenticeship, see 8**.605 Trades.
            .421 Academic.
            For armament control, United States, see 711.00111 Armament control.
            visa fees are recorded as 811.11101 Waivers ††.
            """), ofClass: "8")
        #expect(subjects["42"] == "Education")
        #expect(subjects["421"] == "Academic")
        #expect(subjects["605"] == nil, "a pointer to another entry states nothing about this one")
        #expect(subjects["00111"] == nil)
        #expect(subjects["11101"] == nil)
    }

    @Test("A country-scoped stem does not lend its children to every country")
    func countryScopedBlock() {
        // `800.88` is Foreign carrying trade of country 00, The World, and the eight route termini
        // beneath it are its subdivisions — not suffix `.8810` of any country. Inherited by the
        // class they would gloss `862.8810` as Germany's North America.
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.86 Seamen.
            .867 Relief.
            800.88 Foreign carrying trade.
            .8810 North America.
            .8840 Europe.
            8**.90 Other internal affairs.
            .911 Newspapers.
            """), ofClass: "8")
        #expect(subjects["867"] == "Relief")
        #expect(subjects["8810"] == nil, """
            A subdivision of one country's file is not a subdivision of the class. The block runs \
            until the next `8**.` stem.
            """)
        #expect(subjects["8840"] == nil)
        #expect(subjects["911"] == "Newspapers", "the next stem reopens the class")
    }

    @Test("The facing column, welded on by the scan, is cut or the entry is dropped")
    func columnBleed() {
        // Transcribed verbatim. Four left-column entries with a right-column note run into them;
        // "Patents is sought" is the kind of confident nonsense this table must not print.
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.54 Intellectual and industrial property.
            .541 Industrial property. ** Country in which protection
            .542 Patents is sought. For treaties, conventions,
            .543 Trade-marks. Trade names. arrangements, ect., add country number ††,
            .544 Copyrights. using smaller number of country for **.
            """), ofClass: "8")
        for suffix in ["541", "542", "543"] {
            #expect(subjects[suffix] == nil, "\(suffix) shipped the facing column's note")
        }
        #expect(subjects["544"] == "Copyrights", """
            This one ends in a full stop and is still two columns; a sentence resuming in LOWER \
            CASE is the second column starting.
            """)
    }

    @Test("A wrapped entry takes its tail; a new sentence below it does not")
    func wrappedEntries() {
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.04 Judicial branch of Government.
            .0492 Requirements of country ** regarding authentication of documents for
            use therein.
            .512 Taxation
            Processing tax.
            """), ofClass: "8")
        #expect(subjects["0492"]?.hasSuffix("use therein") == true, """
            A wrapped phrase resumes in lower case, which is what separates it from a \
            sub-descriptor of the entry above.
            """)
        #expect(subjects["512"] == nil, """
            `Processing tax.` is a descriptor under Taxation, not the rest of its name. Joining it \
            would read "Taxation Processing tax"; the manual left the entry unpunctuated and the \
            table stays silent rather than guessing which it is.
            """)
    }

    @Test("A gloss that begins with a number is dropped")
    func splitNumbers() {
        // The scan puts a space inside some numbers. Filed as written, suffix `42` takes the gloss
        // "31 Engineering" and overwrites Education with a fragment; which of the two numbers is
        // the real suffix cannot be recovered from the line.
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.40 Social matters.
            .42 31 Engineering.
            .4232 Manual training.
            """), ofClass: "8")
        #expect(subjects["42"] == nil)
        #expect(subjects["4232"] == "Manual training")
    }

    @Test("An OCR mark before the number is tolerated; a word before it is not")
    func leadingJunk() {
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            ]8**.77 Railway.
            See also 8**.775 Accidents.
            """), ofClass: "8")
        #expect(subjects["77"] == "Railway", "`]8**.77 Railway.` is how the scan renders the stem")
        #expect(subjects["775"] == nil, "a `See also` line is prose, whatever it points at")
    }

    @Test("The scan stops at the class body's edges")
    func bodyIsBounded() throws {
        // Class 7's bare children belong to the whole numbers heading them — `.01` sits under
        // `701 Diplomatic representation`, meaning `701.01`, not "suffix .01 of any country" — and
        // the manual's own country list at the back prints `51 France.` in the same shape.
        let text = """
            Class 7
            701 Diplomatic representation.
            .01 Right of residence, transit, ect.
            Class 8
            8**.00 Political affairs.
            .001 Chief executive. Sovereign.
            Country Numbers
            .0999 Not a subject at all.
            """
        let body = try #require(DecimalClassLabelRunner.classBody(text, ofClass: "8"))
        #expect(body.contains("Right of residence") == false, """
            Class 7's subdivisions would gloss `761.01` as the Soviet Union's right of residence, \
            which the manual does not say.
            """)
        #expect(body.contains("Not a subject at all") == false)
        let subjects = DecimalClassLabelRunner.nestedSubjects(text, ofClass: "8")
        #expect(subjects["01"] == nil)
        #expect(subjects["001"] == "Chief executive. Sovereign")
        #expect(subjects["0999"] == nil, "the body ends where the country table begins")
        #expect(DecimalClassLabelRunner.classBody(text, ofClass: "9") == nil,
                "the 1910–49 schedule has no class 9")
    }

    @Test("A second country in the suffix is a compound key, not a subject")
    func compoundKeysRefused() {
        let subjects = DecimalClassLabelRunner.nestedSubjects(manual("""
            8**.04 Judicial branch of Government.
            .045 Procurement of evidence.
            .045†† Procurement of evidence from country †† for use in country **.
            .†† 62 Patents.
            """), ofClass: "8")
        #expect(subjects["045"] == "Procurement of evidence")
        #expect(subjects["045††"] == nil)
        #expect(subjects.keys.contains { $0.contains("†") } == false, """
            A `††` suffix names a second country, so the key it belongs to is `8**.045††` — a \
            shape this table's one-suffix lookup cannot express.
            """)
    }
}
