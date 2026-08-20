// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SourceNoteKit

// MARK: - DespatchSerialGrammarTests

/// Pins `DespatchSerialGrammar` (#965) — the pre-1906 despatch/instruction serial.
///
/// ## Every fixture below is a real corpus shape
/// They were taken from a census of `<seg>` contents across all 69 pre-1906 volumes (28,139
/// serial-like occurrences, 119 distinct shapes), not invented. The issue as filed listed six
/// forms; the census found a long tail of series qualifiers and oddities, and coding to the list
/// would have dropped exactly the posts that kept more than one sequence — the ones where a bare
/// serial is ambiguous.
///
/// ## The refusals matter more than the matches
/// `<seg>` is FRUS's general bracketed-editorial marker. `[Inclosure 1 in No. 74.]` and its
/// wrapped variants name the serial of the despatch the enclosure travelled *in* — another
/// document's number. Measured by running the shipped grammar over all 69 pre-1906 volumes:
/// **28,112 serials accepted and 17,078 enclosure markers refused**, so a substring scan would
/// have mis-attributed more than a third of everything that looks like a serial. That is the
/// defect this suite exists to prevent, and it is why the grammar requires the WHOLE segment to
/// be a serial.
///
/// Version history:
///   1.0 — Session 2026-08-20: #965
@Suite("Pre-1906 despatch serials")
struct DespatchSerialGrammarTests {

    private func serial(_ text: String) -> DespatchSerial? {
        DespatchSerialGrammar.serial(inSegment: text)
    }

    // MARK: - The common forms

    @Test("The four commonest printed forms all read as the same serial")
    func commonFormsParse() throws {
        for text in ["No. 74.]", "No. 74.", "No. 74]", "No 74.]", "No. 74", "No.74.]", "No. 74.]."] {
            let s = try #require(serial(text), "\(text) is a real corpus shape and must parse")
            #expect(s.number == 74, "\(text) yielded \(s.number)")
            #expect(s.qualifier == nil, "\(text) invented a qualifier: \(s.qualifier ?? "")")
            #expect(s.rawText == text, "the printed text is kept verbatim for display")
        }
    }

    // MARK: - The tail the issue's six-item list would have dropped

    /// A post that kept several sequences numbered each from 1, so the serial alone is ambiguous
    /// and the qualifier is part of the identity — not decoration to be trimmed.
    @Test("Series qualifiers are captured, in both the cases the corpus prints")
    func seriesQualifiersAreCaptured() throws {
        let cases = [
            ("No. 4, Greek Series.]", "Greek Series"),
            ("No. 4, Greek series.]", "Greek series"),
            ("No. 4.—Greek Series.]", "Greek Series"),
            ("No. 9, Servian series.]", "Servian series"),
            ("No. 9, Roumanian series.]", "Roumanian series"),
            ("No. 9, Haitian series.]", "Haitian series"),
            ("No. 9, Santo Domingo Series.]", "Santo Domingo Series"),
            ("No. 3, Dip. Ser.]", "Dip. Ser"),
        ]
        for (text, expected) in cases {
            let s = try #require(serial(text), "\(text) must parse")
            #expect(s.number == (text.contains("No. 4") ? 4 : (text.contains("No. 3") ? 3 : 9)))
            #expect(s.qualifier == expected, "\(text) gave qualifier \(s.qualifier ?? "nil")")
        }
    }

    @Test("Handling words are qualifiers too, not part of the number")
    func handlingWordsAreQualifiers() throws {
        #expect(serial("No. 12, confidential.]")?.qualifier == "confidential")
        #expect(serial("No. 12, official.]")?.qualifier == "official")
        #expect(serial("No. 12, confidential.]")?.number == 12)
    }

    /// `25½` is a different despatch from `25` — a half-step inserted after the fact. An `Int`
    /// cannot carry it, so dropping the fraction would silently merge two documents.
    @Test("A half-step fraction is kept, because it is part of the identifier")
    func halfStepIsKept() throws {
        let s = try #require(serial("No. 25½.]"))
        #expect(s.number == 25)
        #expect(s.isHalf)
        #expect(s.displayNumber == "25½")
        #expect(serial("No. 25.]")?.isHalf == false)
        #expect(serial("No. 25.]")?.displayNumber == "25")
    }

    @Test("A letter suffix is a suffix, not a qualifier")
    func letterSuffixIsCaptured() throws {
        let s = try #require(serial("No. 12 B.]"))
        #expect(s.number == 12)
        #expect(s.letterSuffix == "B")
        #expect(s.displayNumber == "12 B")
        #expect(s.qualifier == nil)
    }

    // MARK: - The refusals

    /// **The defect this grammar exists to avoid.** An enclosure marker carries the serial of the
    /// despatch it was enclosed in. Attributing it to the carrying document is wrong 17,078 times.
    @Test("An inclosure marker is refused, though it contains a well-formed serial")
    func inclosureMarkersAreRefused() {
        for text in [
            "[Inclosure 1 in No. 74.]",
            "[Inclosure in No. 74.]",
            "[Inclosure 1 in No. 74.—Translation.]",
            "[Inclosure 2 in No. 86.]",
            // The corpus wraps inside <seg>; collapsing must not turn a wrapped marker into a
            // bare serial.
            "[Inclosure 1 in No.\n                                74.]",
            // American spelling, in case a later volume uses it.
            "[Enclosure 1 in No. 74.]",
        ] {
            #expect(serial(text) == nil, """
                \(text) parsed as this document's own serial. It names the despatch the enclosure \
                travelled in — another document's number — and admitting it mis-attributes \
                17,078 markers corpus-wide.
                """)
        }
    }

    /// The inclosure guard, exercised on its own.
    ///
    /// **This fixture is SYNTHETIC and the corpus contains nothing like it** — measured, segments
    /// that start with `No` and also name an inclosure number: zero. Every real marker begins with
    /// `[Inclosure` or `Inclosure`, which the anchoring rule already refuses, so without a made-up
    /// shape the guard is unfalsifiable: deleting it changes no outcome and a mutation sweep
    /// SURVIVES, which is exactly what happened before this test existed.
    ///
    /// It is kept rather than deleted because it defends one specific and likely edit — relaxing
    /// `hasPrefix("no")` to tolerate a leading bracket "for robustness" would admit all 17,495
    /// markers at once. This test is what makes that defence real instead of decorative.
    @Test("The inclosure guard holds even if the anchoring is relaxed")
    func inclosureGuardHoldsEvenIfAnchoringIsRelaxed() {
        for text in ["No. 74, inclosure 2.]", "No. 74—Inclosure 2.]", "No. 74, enclosure 2.]"] {
            #expect(serial(text) == nil, """
                \(text) parsed as a document's own serial. It names an inclosure, and the guard \
                exists so that a future loosening of the prefix rule cannot admit the corpus's \
                17,495 enclosure markers wholesale.
                """)
        }
    }

    @Test("The other bracketed editorial markers are refused")
    func otherSegMarkersAreRefused() {
        for text in ["[Translation.]", "[Telegram.]", "[Extract.]", "[Telegram.—Paraphrase.]",
                     "[12]", "[Inclosure 1.]", "", "   "] {
            #expect(serial(text) == nil, "\(text) is not a serial")
        }
    }

    /// `No.—.]` really appears. A serial with no number is not a serial, and inventing one — or
    /// reading the dash as a zero — would put a fabricated identifier on a document.
    @Test("A segment with no number is refused rather than defaulted")
    func numberlessSerialIsRefused() {
        #expect(serial("No.—.]") == nil)
        #expect(serial("No.]") == nil)
        #expect(serial("No.") == nil)
    }

    // MARK: - Shape

    /// The corpus wraps freely inside `<seg>`, so a serial split across lines must still read.
    @Test("Wrapped whitespace inside the segment is collapsed")
    func wrappedWhitespaceIsCollapsed() throws {
        let s = try #require(serial("No.\n                                74.]"))
        #expect(s.number == 74)
    }

    @Test("Parsing is idempotent on its own raw text")
    func rawTextRoundTrips() throws {
        let first = try #require(serial("No. 4, Greek Series.]"))
        let second = try #require(serial(first.rawText))
        #expect(first == second)
    }
}
