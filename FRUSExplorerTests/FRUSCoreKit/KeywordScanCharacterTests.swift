// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

/// How the keyword scan reads a body's characters: a letter, which opens or goes on with a word; an
/// apostrophe or a hyphen, which goes on with one; anything else, which ends it.
///
/// The scan reads one ASCII character from a table, and any other character as `Character` reads it,
/// which is what it did for every character before the table. The characters here are the ones a table
/// keyed on a character's first byte would misread: those of several scalars that open with an ASCII
/// one, an apostrophe or a letter followed by a combining mark, and a letter outside ASCII that
/// lowercases into it. `SearchSnippetCostTests` holds the scan to the naive one over bodies whose
/// characters are each one scalar, so it reaches none of them. Each expectation here is what the scan
/// before the table made.
///
/// Version history:
///   1.0 — the scan's ASCII fast path (plan of record §5, found in L2)
@Suite("The keyword scan's characters")
struct KeywordScanCharacterTests {

    @Test("An apostrophe or a hyphen with a combining mark ends a word, where a bare one goes on with it")
    func aMarkedApostropheOrHyphenEndsTheWord() {
        // U+0301 joins the mark before it into one character, which is neither an apostrophe nor a hyphen.
        #expect(SearchService.makeContextSnippet(body: "Re aid'\u{301}s to Bonn", stemmedTerms: ["aid"])
                == "Re <b>aid</b>'\u{301}s to Bonn")
        #expect(SearchService.makeContextSnippet(body: "Re aid-\u{301}s to Bonn", stemmedTerms: ["aid"])
                == "Re <b>aid</b>-\u{301}s to Bonn")
        // A bare one is part of the word, which is stemmed without it.
        #expect(SearchService.makeContextSnippet(body: "Re aid's to Bonn", stemmedTerms: ["aid"])
                == "Re <b>aid's</b> to Bonn")
    }

    @Test("An ASCII letter with a combining mark is one letter of its word")
    func aMarkedLetterIsALetter() {
        // "résumé" decomposed: each *e* and its accent are one character, which opens with an ASCII scalar.
        #expect(SearchService.makeContextSnippet(body: "the re\u{301}sume\u{301} of the talks",
                                                 stemmedTerms: ["re\u{301}sume\u{301}"])
                == "the <b>re\u{301}sume\u{301}</b> of the talks")
    }

    @Test("A word that opens with a letter outside ASCII is gated on that letter lowercased")
    func aLetterOutsideASCIIOpensAWord() {
        // The Kelvin sign, U+212A, lowercases to an ASCII k.
        #expect(SearchService.makeContextSnippet(body: "at 300 \u{212A}elvin", stemmedTerms: ["kelvin"])
                == "at 300 <b>\u{212A}elvin</b>")
    }
}
