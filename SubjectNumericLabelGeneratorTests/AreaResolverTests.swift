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

// MARK: - AreaResolverTests

/// Reading the country, region or organization element of a subject-numeric key (#1254).
///
/// NARA describes the element as generated rather than controlled: names "may be spelled out in
/// full or … abbreviated using a common abbreviation (USSR … UN …) or the first few letters of the
/// name (POL for Poland and KOR N for North Korea)". These pin that rule and, as importantly, the
/// refusals that keep it from inventing countries.
@Suite("Area element — NARA's three abbreviation forms")
struct AreaResolverTests {

    private let names = [
        "Vietnam", "Korea", "Poland", "Iran", "Cambodia", "Saudi Arabia", "Bali", "Germany",
        "United States", "Union of Soviet Socialist Republics", "India", "Pakistan", "Israel",
    ]
    private let organizations = ["NATO": "North Atlantic Treaty Organization",
                                 "UN": "United Nations"]
    private let curated = ["ARAB-ISR": "Arab–Israeli"]

    private func resolve(_ tail: String) -> String? {
        AreaResolver.resolve(tail, names: names, organizations: organizations, curated: curated)
    }

    @Test("A name spelled in full, a common abbreviation, and the first few letters")
    func theThreeFormsNARADescribes() {
        #expect(resolve("IRAN") == "Iran")
        #expect(resolve("POL") == "Poland")
        #expect(resolve("UN") == "United Nations")
        #expect(resolve("USSR") == "Union of Soviet Socialist Republics")
        // "The first few letters of the NAME", taken across the whole name rather than word by
        // word — which is what `SAUD` needs and a word-wise cover refuses.
        #expect(resolve("SAUD") == "Saudi Arabia")
        #expect(resolve("CAMB") == "Cambodia")
    }

    @Test("The two spellings of a divided country read the same")
    func theCompassQualifierIsOrderFree() {
        // The corpus writes `VIET S` and the 1963 handbook prints `S VIET`; NARA's own `KOR N`
        // example shows the filer working from the index form of the name. Both are the same rule
        // on the same name, and 830 documents ride on them agreeing.
        #expect(resolve("VIET S") == "Vietnam, South")
        #expect(resolve("S VIET") == "Vietnam, South")
        #expect(resolve("KOR N") == "Korea, North")
    }

    @Test("A hyphen is the filer's own division and is taken before any other")
    func pairsSplitAtTheHyphenFirst() {
        // Searching cut positions first splits `KOR N-US` after `KOR`, leaving `N US` as the
        // second half and handing the compass qualifier to the wrong country — measured, that
        // shipped "Korea and United States, North" over 87 documents.
        // The fixture's name list has `Korea` and not `North Korea`, so this half resolves
        // through the compass rule; against the shipped artifact, which carries both, it reads
        // "North Korea and United States". Either way the qualifier stays with Korea, which is
        // what the hyphen-first split is for.
        #expect(resolve("KOR N-US") == "Korea, North and United States")
        #expect(resolve("US-IRAN") == "United States and Iran")
        #expect(resolve("INDIA PAK") == "India and Pakistan")
    }

    @Test("A single letter is not a country")
    func oneLetterHalvesAreRefused() {
        // `B` fully covers a four-letter island, so without a floor `GER B` reads as "Germany and
        // Bali" — over 51 documents, where the record almost certainly means Berlin. Refusing
        // leaves the tail printed as written, which is what the reader had before.
        #expect(resolve("GER B") == nil)
        #expect(resolve("S") == nil)
    }

    @Test("A name only partly accounted for is refused, however well it reads")
    func partialCoversAreRefused() {
        // Measured against the handbook's own appendix, a partial cover matched `GER W` to
        // *Saar (West Germany)* — GER on GERMANY, W on WEST, SAAR left over — so a caption naming
        // one town would have stood over every West German document in the corpus.
        #expect(AreaResolver.fullyCovers("Saar (West Germany)", ["GER", "W"]) == false)
        #expect(AreaResolver.fullyCovers("Germany", ["GER"]))
        #expect(AreaResolver.fullyCovers("Korea, North", ["KOR", "N"]))
    }

    @Test("Two equally good readings are refused rather than guessed between")
    func ambiguityIsRefused() {
        // BOTH names must actually MATCH, and be the same length, or the fixture cannot fail:
        // a code matching neither returns nil whether the refusal is there or not.
        #expect(AreaResolver.match("CHA", names: ["Chad", "Chat"]) == nil, """
            Two four-letter names both truncate to CHA. Picking either is a coin toss, and a \
            wrong country is worse than a bare code.
            """)
        // A shorter unique reading still wins — this is not a blanket refusal of overlap.
        #expect(AreaResolver.match("IND", names: ["India", "Indonesia"]) == "India")
    }

    @Test("Blends and collectives are curated, because no rule over names reaches them")
    func blendsAreCurated() {
        // Left to the rules `ARAB-ISR` resolved to "Arabia and Israel", naming a country for what
        // is a conflict between a bloc and a state, over 313 documents.
        #expect(resolve("ARAB-ISR") == "Arab–Israeli")
    }

    @Test("Initials skip the words English does not initialise")
    func initialsSkipStopWords() {
        #expect(AreaResolver.initials(of: "Union of Soviet Socialist Republics") == "USSR")
        #expect(AreaResolver.initials(of: "United Nations") == "UN")
    }
}
