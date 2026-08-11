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
            countryArrangedClasses: ["6", "7", "8"],
            countries: ["61": "Union of Soviet Socialist Republics", "62": "Germany",
                        "11": "United States", "51": "France", "51r": "Algeria", "91": "Iran"],
            subjects: ["8": ["11": "Public order, safety, health, works"]],
            sources: .init(schedule: "test", countries: "test"))
    }

    /// The 1950 renumbering, where the same digits mean something else.
    private var schedule1959: DecimalClassLabels.Schedule {
        DecimalClassLabels.Schedule(
            id: "1950-1959", startYear: 1950, endYear: 1959, source: "test",
            classes: ["7": "Internal Political and National Defense Affairs"],
            countryArrangedClasses: ["3", "4", "5", "6", "7", "8", "9"],
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
