// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
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
