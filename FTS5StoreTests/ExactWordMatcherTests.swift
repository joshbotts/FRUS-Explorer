// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
@testable import FTS5Store

// MARK: - ExactWordMatcherTests

/// The exact-word post-filter, and its agreement with the tokenizer it has to match (Q-3b).
///
/// The parity suite is the load-bearing part. `ExactWordMatcher` re-implements
/// `unicode61`'s token boundaries in Swift, and if the two ever drift the filter starts
/// removing documents FTS5 legitimately matched — which reads as a mysterious missing hit,
/// not as a bug. So the boundaries are not asserted from the documentation; they are
/// compared against what SQLite actually produces.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
///   1.1 — Session 2026-10-04: imports `CSQLite` where `SQLite3` cannot be imported (Linux), so these
///          tests compile there; Apple platforms still import `SQLite3`
///   1.2 — FRUS Explorer Light S13b: `ExactWordByteReadingTests`, which hold the matcher's reading of a
///          text as bytes to the whole text folded and split
@Suite("Exact-word matching")
struct ExactWordMatcherTests {

    // MARK: - Parity with unicode61

    /// Inputs chosen for the ways tokenization can differ: trailing and wrapping
    /// punctuation, internal hyphens and apostrophes, acronyms, digits, em-dashes, and —
    /// the one most likely to be got wrong — diacritics, which `unicode61` folds.
    private static let tokenizationCases: [String] = [
        "containment", "Containment", "CONTAINMENT",
        "containment.", "(containment)", "containment,", "containment;",
        "co-operate", "anti-communist", "re-entry",
        "don't", "policy's",
        "U.S.S.R.", "N.A.T.O.",
        "1948", "containment42", "42containment",
        "naïve", "Führer", "café", "Ångström",
        "containment—dash", "a—b",
        "  leading and trailing  ",
        "multiple   internal   spaces",
        "", "   ", "...", "-",
        "Truman's containment policy, 1948—1952.",
    ]

    /// Runs SQLite's own `unicode61` tokenizer over `text` and returns its terms.
    private func sqliteTokens(_ text: String) throws -> [String] {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        #expect(sqlite3_exec(db, "CREATE VIRTUAL TABLE p USING fts5(t, tokenize='unicode61');",
                             nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(db, "CREATE VIRTUAL TABLE pv USING fts5vocab('p','row');",
                             nil, nil, nil) == SQLITE_OK)
        var ins: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "INSERT INTO p(t) VALUES (?);", -1, &ins, nil) == SQLITE_OK)
        sqlite3_bind_text(ins, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        #expect(sqlite3_step(ins) == SQLITE_DONE)
        sqlite3_finalize(ins)

        var stmt: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "SELECT term FROM pv;", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var terms: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let raw = sqlite3_column_text(stmt, 0) { terms.append(String(cString: raw)) }
        }
        return terms.sorted()
    }

    @Test("Swift tokenization matches unicode61's, case by case")
    func parityWithUnicode61() throws {
        var mismatches: [String] = []
        for input in Self.tokenizationCases {
            let ours = Set(ExactWordMatcher.tokens(in: input))
            let theirs = Set(try sqliteTokens(input))
            if ours != theirs {
                mismatches.append("\(input.debugDescription): swift=\(ours.sorted()) sqlite=\(theirs.sorted())")
            }
        }
        #expect(mismatches.isEmpty,
                "the matcher must split text exactly where the index does — \(mismatches.joined(separator: " | "))")
    }

    /// Called out separately because it is the case a hand-rolled matcher gets wrong, and
    /// the symptom is a document FTS5 matched being filtered away with no explanation.
    @Test("Diacritics fold, exactly as the tokenizer folds them")
    func diacriticsFold() {
        #expect(ExactWordMatcher.contains(word: "naive", in: "a naïve assessment"))
        #expect(ExactWordMatcher.contains(word: "naïve", in: "a naive assessment"))
        #expect(ExactWordMatcher.contains(word: "fuhrer", in: "the Führer's order"))
        #expect(ExactWordMatcher.contains(word: "cafe", in: "met at the café"))
    }

    // MARK: - Whole-token semantics

    @Test("The literal word matches; its stem-mates do not")
    func stemMatesAreExcluded() {
        // This is the entire point of the feature.
        #expect(ExactWordMatcher.contains(word: "containment", in: "the policy of containment"))
        #expect(!ExactWordMatcher.contains(word: "containment", in: "we must contain them"))
        #expect(!ExactWordMatcher.contains(word: "containment", in: "containing the threat"))
        #expect(!ExactWordMatcher.contains(word: "containment", in: "a shipping container"))
    }

    @Test("Substrings do not match — the boundary is a token boundary, not a range")
    func substringsDoNotMatch() {
        #expect(!ExactWordMatcher.contains(word: "contain", in: "containment policy"))
        #expect(!ExactWordMatcher.contains(word: "ment", in: "containment policy"))
        #expect(!ExactWordMatcher.contains(word: "urope", in: "europe"))
    }

    @Test("Adjacent punctuation does not hide a word")
    func punctuationDoesNotHideAWord() {
        for text in ["containment.", "(containment)", "\"containment\"", "containment,",
                     "—containment—", "containment;", "[containment]"] {
            #expect(ExactWordMatcher.contains(word: "containment", in: text),
                    "punctuation hid the word in \(text)")
        }
    }

    @Test("Case is folded in both directions")
    func caseFolds() {
        #expect(ExactWordMatcher.contains(word: "containment", in: "CONTAINMENT POLICY"))
        #expect(ExactWordMatcher.contains(word: "CONTAINMENT", in: "containment policy"))
    }

    @Test("Empty text and empty word never match")
    func emptyInputs() {
        #expect(!ExactWordMatcher.contains(word: "containment", in: ""))
        #expect(!ExactWordMatcher.contains(word: "", in: "containment"))
        #expect(!ExactWordMatcher.contains(word: "   ", in: "containment"))
    }

    // MARK: - Multi-token terms

    @Test("A term that is not one token is rejected rather than partly applied")
    func multiTokenTermsAreRejected() {
        // Filtering on one fragment of what the researcher typed would be worse than
        // ignoring the sigil, so `contains` returns false and the parser drops the `=`.
        #expect(!ExactWordMatcher.isSingleToken("co-operate"))
        #expect(!ExactWordMatcher.isSingleToken("U.S.S.R."))
        #expect(!ExactWordMatcher.isSingleToken("cold war"))
        #expect(!ExactWordMatcher.contains(word: "co-operate", in: "we must co-operate"))

        #expect(ExactWordMatcher.isSingleToken("containment"))
        #expect(ExactWordMatcher.isSingleToken("1948"))
        #expect(ExactWordMatcher.isSingleToken("naïve"))
    }

    // MARK: - Column OR

    @Test("Any searched column can satisfy an exact term")
    func anyColumnSatisfies() {
        let columns: [String?] = ["Containment and the West", nil, nil, "we must contain them"]
        #expect(ExactWordMatcher.contains(word: "containment", inAnyOf: columns),
                "a literal match in the header counts — the header is a searched column")
        #expect(!ExactWordMatcher.contains(word: "rollback", inAnyOf: columns))
        #expect(!ExactWordMatcher.contains(word: "containment", inAnyOf: [nil, nil]))
    }

    // MARK: - Locale independence

    /// A device set to Turkish lowercases `I` to a dotless `ı`. If the matcher used the
    /// user's locale, which documents matched would depend on a setting the corpus knows
    /// nothing about — and it would differ between two people citing the same search.
    @Test("Matching does not depend on the device locale")
    func localeIndependence() {
        #expect(ExactWordMatcher.contains(word: "INDUSTRIAL", in: "industrial output"))
        #expect(ExactWordMatcher.contains(word: "industrial", in: "INDUSTRIAL OUTPUT"))
        #expect(ExactWordMatcher.tokens(in: "INDIA") == ["india"])
    }
}

// MARK: - ExactWordByteReadingTests

/// The matcher reads a text as UTF-8 bytes, and folds only where a scalar it cannot read alone asks it to
/// (`ExactWordMatcher.contains(_:inUTF8:)`). These hold every answer it gives to the answer by definition,
/// `containsByFolding(word:in:)`, which folds and splits the whole text: the scalars it classes, each beside a
/// word, inside one and alone; the ones it sends to the fold; random texts from both; and bytes that are not
/// UTF-8. A difference names the word and the text.
@Suite("Exact-word matching read as bytes")
struct ExactWordByteReadingTests {
    /// Words whose index words are ASCII, some of which a non-ASCII scalar folds into, and two that are not ASCII.
    static let words = ["soviet", "Soviet", "e", "ss", "fi", "k", "a", "i", "1948", "a1", "x2y", "naïve", "Argüello",
                        "gomułka", "café"]

    /// Scalars outside the classed ranges, each sent to the fold: a combining mark, ZWJ and ZWNJ, a variation
    /// selector, a soft hyphen, Arabic and Malayalam marks that join the next character, a spacing mark, Hangul
    /// jamo, CJK, emoji with a modifier, regional indicators, ligatures, the replacement character, a private
    /// scalar, astral letters and digits, and fullwidth letters.
    static let others: [String] = [
        "\u{0301}", "\u{0308}", "\u{200D}", "\u{200C}", "\u{FE0F}", "\u{00AD}", "\u{0600}", "\u{0D4E}", "\u{093E}",
        "\u{1100}", "\u{1161}", "\u{AC00}", "日", "😀", "👍🏽", "🇺🇸", "\u{1F1FA}", "ﬁ", "ﬀ", "ﬃ", "\u{FFFD}",
        "\u{E000}", "𝐀", "𝟏", "Ａ", "ａ", "\u{2028}", "\u{3000}", "\u{0085}", "\u{0670}", "ـ", "\u{1E9E}", "\u{FB06}",
    ]

    /// The texts each scalar is read in: beside a word, inside one, alone, twice, beside another scalar, and
    /// after CR LF.
    static func contexts(_ c: String) -> [String] {
        ["soviet\(c)", "\(c)soviet", "sov\(c)iet", "the \(c) soviet", "soviet \(c)x", c, c + c, "a\(c)", "\(c)b",
         "Soviet’s \(c)é", "\(c)ss", "s\(c)s", "f\(c)i", "\(c)1948", "1948\(c)", "x \(c)e y", "e\(c)", "\(c)k\(c)",
         "naïve\(c)", "\(c)cafe", "\r\n\(c)\r\nsoviet", "—\(c)—", "\(c)\u{0301}soviet", "soviet\u{0301}\(c)"]
    }

    func differences(_ texts: [String], words: [String] = Self.words) -> [String] {
        var found: [String] = []
        for text in texts {
            for word in words {
                let read = ExactWordMatcher.contains(word: word, in: text)
                let folded = ExactWordMatcher.containsByFolding(word: word, in: text)
                if read != folded { found.append("\(word.debugDescription) in \(text.debugDescription): \(read), not \(folded)") }
            }
        }
        return found
    }

    @Test("Every classed scalar is read as the fold reads it, in every context")
    func everyClassedScalar() throws {
        var texts: [String] = []
        for range in ExactWordMatcher.classifiedScalars {
            for value in range {
                guard let scalar = Unicode.Scalar(value) else { continue }
                texts += Self.contexts(String(scalar))
            }
        }
        let found = differences(texts)
        #expect(found.isEmpty, "\(found.count) differences, the first \(found.prefix(20).joined(separator: " | "))")
    }

    @Test("A scalar the matcher does not class is read by the fold, in every context")
    func everyOtherScalar() {
        for other in Self.others {
            for scalar in other.unicodeScalars where scalar.value >= 0x80 {
                #expect(ExactWordMatcher.scalarClass(of: scalar.value) == nil, "\(other.debugDescription) is classed")
            }
        }
        let found = differences(Self.others.flatMap(Self.contexts))
        #expect(found.isEmpty, "\(found.count) differences, the first \(found.prefix(20).joined(separator: " | "))")
    }

    /// The classes the documentation gives as examples, which every platform's fold gives.
    @Test("The scalars the documentation names have the classes it gives them")
    func documentedClasses() {
        #expect(ExactWordMatcher.scalarClass(of: 0x2019) == .separator)                      // ’
        #expect(ExactWordMatcher.scalarClass(of: 0x2014) == .separator)                      // —
        #expect(ExactWordMatcher.scalarClass(of: 0x00A7) == .separator)                      // §
        #expect(ExactWordMatcher.scalarClass(of: 0x00E9) == .asciiLetters(Array("e".utf8)))  // é
        #expect(ExactWordMatcher.scalarClass(of: 0x02BC) == .otherLetter)                    // ʼ
        #expect(ExactWordMatcher.scalarClass(of: 0x00BD) == .otherLetter)                    // ½
        #expect(ExactWordMatcher.scalarClass(of: 0x0436) == .otherLetter)                    // ж
        #expect(ExactWordMatcher.scalarClass(of: 0x0301) == nil)                             // a combining mark
        #expect(ExactWordMatcher.scalarClass(of: 0x200D) == nil)                             // ZWJ
    }

    /// The facts the regions rest on: the fold lowercases `A`–`Z` and leaves every other ASCII character as it is,
    /// a letter or digit joins the letters beside it and any other ASCII character divides them.
    @Test("The fold changes no ASCII character but A–Z, and every other ASCII byte divides tokens")
    func asciiBytes() {
        for value in UInt8(0)..<0x80 {
            let character = String(UnicodeScalar(value))
            let isLetterOrDigit = (0x30...0x39).contains(value) || (0x41...0x5A).contains(value) || (0x61...0x7A).contains(value)
            let lowered = (0x41...0x5A).contains(value) ? String(UnicodeScalar(value | 0x20)) : character
            #expect(ExactWordMatcher.normalize("x\(character)y") == "x\(lowered)y", "the fold of \(value)")
            #expect(ExactWordMatcher.tokens(in: "x\(character)y") == (isLetterOrDigit ? ["x\(lowered)y"] : ["x", "y"]),
                    "the tokens beside \(value)")
        }
    }

    /// A small generator with a seed, so a failure can be read again.
    struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Pieces of text from all of the above: words and parts of words, ASCII separators, classed scalars and
    /// others, CR LF and NUL.
    static let pieces: [String] = ["soviet", "Soviet", "SOV", "iet", "e", "s", "f", "i", "k", "1948", "a", "1", "naïve",
                                   "cafe", "café", "x", " ", ".", "-", "'", "\r", "\n", "\r\n", "\u{0}", "’", "“", "”",
                                   "—", "–", "§", "é", "É", "à", "ñ", "ß", "ʼ", "½", "ж", "Ω", "ł", "\u{00A0}", "\u{212A}",
                                   "\u{0130}", "ς", "ﬁ"] + others

    @Test("Random texts are read as the fold reads them")
    func randomTexts() {
        var generator = SplitMix64(state: 0x5EED_1776)
        var texts: [String] = []
        for _ in 0..<6_000 {
            let count = Int.random(in: 1...10, using: &generator)
            texts.append((0..<count).map { _ in Self.pieces.randomElement(using: &generator)! }.joined())
        }
        let found = differences(texts)
        #expect(found.isEmpty, "\(found.count) differences, the first \(found.prefix(20).joined(separator: " | "))")
    }

    /// Bytes that are not UTF-8 are read as `String(decoding:as:)` repairs them, as `String(cString:)` did in the SQL
    /// function: a lone continuation byte, a truncated sequence, an overlong form, a surrogate, four-byte forms, and
    /// bytes no sequence uses, among words and separators.
    @Test("Bytes that are not well-formed UTF-8 are read as their repair is")
    func illFormedBytes() throws {
        let fragments: [[UInt8]] = [Array("soviet".utf8), Array(" ".utf8), Array("e".utf8), Array("ss".utf8), Array(".".utf8),
                                    [0x80], [0xBF], [0xC3], [0xE2, 0x80], [0xC0, 0x80], [0xE0, 0x80, 0x80], [0xED, 0xA0, 0x80],
                                    [0xF0, 0x9F, 0x98, 0x80], [0xF4, 0x90, 0x80, 0x80], [0xF8], [0xFF], [0xC3, 0xA9],
                                    [0xE2, 0x80, 0x99], [0xCC, 0x81]]
        var generator = SplitMix64(state: 0x0BAD_B17E)
        var found: [String] = []
        for _ in 0..<4_000 {
            let count = Int.random(in: 1...8, using: &generator)
            let bytes = (0..<count).flatMap { _ in fragments.randomElement(using: &generator)! }
            let text = String(decoding: bytes, as: UTF8.self)
            for word in Self.words {
                let prepared = try #require(ExactWordMatcher.Word(word))
                let read = bytes.withUnsafeBufferPointer { ExactWordMatcher.contains(prepared, inUTF8: $0) }
                let folded = ExactWordMatcher.containsByFolding(word: word, in: text)
                if read != folded { found.append("\(word) in \(bytes): \(read), not \(folded)") }
            }
        }
        #expect(found.isEmpty, "\(found.count) differences, the first \(found.prefix(20).joined(separator: " | "))")
    }

    @Test("A word that is not one token is no word, and an empty text holds none")
    func noWord() {
        #expect(ExactWordMatcher.Word("co-operate") == nil)
        #expect(ExactWordMatcher.Word("") == nil)
        let word = ExactWordMatcher.Word("soviet")
        #expect(word != nil)
        if let word {
            #expect(!([] as [UInt8]).withUnsafeBufferPointer { ExactWordMatcher.contains(word, inUTF8: $0) })
            #expect(Array("Soviet".utf8).withUnsafeBufferPointer { ExactWordMatcher.contains(word, inUTF8: $0) })
        }
    }
}
