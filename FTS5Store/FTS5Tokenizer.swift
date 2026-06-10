// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - Porter Stemmer
//
// Reference: M.F. Porter, "An Algorithm for Suffix Stripping", Program 14(3) 1980.
// https://tartarus.org/martin/PorterStemmer/
//
// The Porter stemmer reduces English words to their stem form so that morphological
// variants of a query term match the same index entries. For example:
//   "negotiations" → "negoti"
//   "negotiated"   → "negoti"
//   "negotiate"    → "negoti"
//
// This implementation covers all five steps of the original 1980 algorithm. It is
// intentionally conservative (understemming is preferred over overstemming for a
// historical document corpus where proper nouns and archaic spellings are common).
//
// ## Role of this stemmer (since the Session 2026-06-09 redesign)
//
// Index- and query-side stemming is performed by SQLite's built-in
// `porter unicode61` FTS5 tokenizer — no application-layer stemming touches the
// text that reaches the database in either direction.
//
// This Swift implementation remains for one job: **snippet highlighting**.
// `SearchService.makeContextSnippet` walks a result's body text word-by-word and
// stems each word to decide whether it matches a query term; that comparison has
// to happen in Swift, after the search returns. Both sides of the comparison are
// stemmed by this same implementation, so highlighting is internally consistent.
// In rare edge cases this stemmer may disagree with SQLite's porter implementation
// (the row matched but no word highlights); the snippet then falls back to the
// header/dateline form, which is cosmetic only.

/// Reduces an English word to its Porter stem.
///
/// Input is expected to be a single lowercase alphabetic word.
///
/// Version history:
///   1.0 — Session 03: initial implementation
public struct PorterStemmer {

    private init() {}

    public static func stem(_ word: String) -> String {
        var chars = Array(word.unicodeScalars.map { Character($0) })
        guard chars.count > 2 else { return word }
        step1a(&chars)
        step1b(&chars)
        step1c(&chars)
        step2(&chars)
        step3(&chars)
        step4(&chars)
        step5a(&chars)
        step5b(&chars)
        return String(chars)
    }

    // MARK: - Utility Predicates

    private static func isConsonant(_ chars: [Character], _ i: Int) -> Bool {
        switch chars[i] {
        case "a", "e", "i", "o", "u": return false
        case "y": return i == 0 ? true : !isConsonant(chars, i - 1)
        default: return true
        }
    }

    /// Count of VC sequences (the "measure" m in the Porter paper).
    private static func measure(_ chars: [Character], _ j: Int) -> Int {
        var n = 0
        var i = 0
        while i < j, isConsonant(chars, i) { i += 1 }
        while i < j {
            while i < j, !isConsonant(chars, i) { i += 1 }
            n += 1
            while i < j, isConsonant(chars, i) { i += 1 }
        }
        return n
    }

    private static func containsVowel(_ chars: [Character], _ j: Int) -> Bool {
        (0..<j).contains { !isConsonant(chars, $0) }
    }

    private static func endsWithDoubleConsonant(_ chars: [Character], _ j: Int) -> Bool {
        guard j >= 2 else { return false }
        return isConsonant(chars, j - 1) && chars[j - 1] == chars[j - 2]
    }

    private static func endsCVC(_ chars: [Character], _ j: Int) -> Bool {
        guard j >= 3 else { return false }
        let c = chars[j - 1]
        return isConsonant(chars, j - 1) &&
               !isConsonant(chars, j - 2) &&
               isConsonant(chars, j - 3) &&
               c != "w" && c != "x" && c != "y"
    }

    // MARK: - Steps 1–5

    private static func step1a(_ chars: inout [Character]) {
        let n = chars.count
        if hasSuffix(chars, "sses") {
            chars = Array(chars.prefix(n - 2))
        } else if hasSuffix(chars, "ies") {
            chars = Array(chars.prefix(n - 2))
        } else if !hasSuffix(chars, "ss"), hasSuffix(chars, "s") {
            chars = Array(chars.prefix(n - 1))
        }
    }

    private static func step1b(_ chars: inout [Character]) {
        let n = chars.count
        var flag = false
        if hasSuffix(chars, "eed") {
            if measure(chars, n - 3) > 0 { chars = Array(chars.prefix(n - 1)) }
        } else if hasSuffix(chars, "ed") {
            if containsVowel(chars, n - 2) { chars = Array(chars.prefix(n - 2)); flag = true }
        } else if hasSuffix(chars, "ing") {
            if containsVowel(chars, n - 3) { chars = Array(chars.prefix(n - 3)); flag = true }
        }
        if flag {
            let m = chars.count
            if hasSuffix(chars, "at") || hasSuffix(chars, "bl") || hasSuffix(chars, "iz") {
                chars.append("e")
            } else if endsWithDoubleConsonant(chars, m) {
                let last = chars.last!
                if last != "l" && last != "s" && last != "z" { chars = Array(chars.prefix(m - 1)) }
            } else if measure(chars, m) == 1, endsCVC(chars, m) {
                chars.append("e")
            }
        }
    }

    private static func step1c(_ chars: inout [Character]) {
        let n = chars.count
        if hasSuffix(chars, "y"), containsVowel(chars, n - 1) { chars[n - 1] = "i" }
    }

    private static func step2(_ chars: inout [Character]) {
        applyMeasuredSuffixMap(&chars, map: [
            ("ational", "ate"), ("tional", "tion"), ("enci", "ence"), ("anci", "ance"),
            ("izer", "ize"), ("abli", "able"), ("alli", "al"), ("entli", "ent"),
            ("eli", "e"), ("ousli", "ous"), ("ization", "ize"), ("ation", "ate"),
            ("ator", "ate"), ("alism", "al"), ("iveness", "ive"), ("fulness", "ful"),
            ("ousness", "ous"), ("aliti", "al"), ("iviti", "ive"), ("biliti", "ble"),
        ])
    }

    private static func step3(_ chars: inout [Character]) {
        applyMeasuredSuffixMap(&chars, map: [
            ("icate", "ic"), ("ative", ""), ("alize", "al"), ("iciti", "ic"),
            ("ical", "ic"), ("ful", ""), ("ness", ""),
        ])
    }

    private static func step4(_ chars: inout [Character]) {
        let suffixes = ["al","ance","ence","er","ic","able","ible","ant","ement","ment",
                        "ent","ou","ism","ate","iti","ous","ive","ize"]
        let n = chars.count
        for suffix in suffixes {
            if hasSuffix(chars, suffix) {
                let stem = n - suffix.count
                if measure(chars, stem) > 1 { chars = Array(chars.prefix(stem)); return }
            }
        }
        if hasSuffix(chars, "ion") {
            let stem = n - 3
            if stem >= 1, measure(chars, stem) > 1 {
                let p = chars[stem - 1]
                if p == "s" || p == "t" { chars = Array(chars.prefix(stem)) }
            }
        }
    }

    private static func step5a(_ chars: inout [Character]) {
        let n = chars.count
        guard hasSuffix(chars, "e") else { return }
        let m = measure(chars, n - 1)
        if m > 1 { chars = Array(chars.prefix(n - 1)) }
        else if m == 1, !endsCVC(chars, n - 1) { chars = Array(chars.prefix(n - 1)) }
    }

    private static func step5b(_ chars: inout [Character]) {
        let n = chars.count
        if measure(chars, n) > 1, endsWithDoubleConsonant(chars, n), chars.last == "l" {
            chars = Array(chars.prefix(n - 1))
        }
    }

    // MARK: - Helpers

    private static func hasSuffix(_ chars: [Character], _ suffix: String) -> Bool {
        let s = Array(suffix)
        guard chars.count >= s.count else { return false }
        return Array(chars.suffix(s.count)) == s
    }

    private static func applyMeasuredSuffixMap(
        _ chars: inout [Character],
        map: [(String, String)]
    ) {
        let n = chars.count
        for (suffix, replacement) in map {
            if hasSuffix(chars, suffix) {
                let stem = n - suffix.count
                if measure(chars, stem) > 0 {
                    chars = Array(chars.prefix(stem)) + Array(replacement)
                    return
                }
            }
        }
    }
}
