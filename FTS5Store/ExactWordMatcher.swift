// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExactWordMatcher

/// Decides whether a piece of stored text contains a word *literally*, on the same
/// boundaries SQLite's `unicode61` tokenizer uses.
///
/// ## Why this exists
/// The index is stemmed, so a search for `containment` is really a search for `contain`
/// and cannot distinguish the researcher's term from *contains*, *containing* or
/// *container*. Exact-word mode narrows that back down. The stemmed result set is a
/// strict **superset** of the exact matches — every document containing the literal word
/// also contains its stem — so exact mode is the stemmed query plus this post-filter. No
/// second index, no reindex.
///
/// ## Agreeing with the tokenizer is the whole job
/// This must split text exactly where `unicode61` splits it, or the filter removes
/// documents FTS5 legitimately matched. Verified against a real `unicode61` table:
///
/// - Runs of **alphanumeric** characters are tokens; everything else separates.
///   `containment.`, `(containment)` and `containment,` all yield `containment`;
///   `co-operate` yields two tokens; `containment42` stays one.
/// - **Diacritics are folded.** `naïve` indexes as `naive` and `Führer` as `fuhrer`.
///   This is the trap: a matcher that compared raw scalars would reject a document FTS5
///   had already matched, and the result would look like a mysterious missing hit rather
///   than a bug. `ExactWordMatcherTests` pins this against SQLite's own output.
/// - Case is folded.
///
/// Stemming is deliberately **not** applied here — that is the entire point.
///
/// ## Reading a text as bytes
/// The filter runs over every row the stemmed match returns, which for a common stem is most of the corpus:
/// `=Soviet` reads 58,679 documents, 425 million characters, in FRUS Explorer 1.0's full index. Folding and
/// splitting each whole text took about 21 seconds for that on Linux and on a Mac, and a search takes it twice,
/// for its count and for its page. ``contains(_:inUTF8:)`` reaches the same answer from the text's UTF-8 bytes,
/// and folds only where a scalar it cannot read alone asks it to: under half a second on both. The answer is
/// still the fold's: ``containsByFolding(word:in:)`` keeps the definition, and the tests hold the bytes to it.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
///   1.1 — #1297 round-4 parser fixes: `word(_:)`, the one index word a term is, which `contains(word:in:)` and
///          `isSingleToken(_:)` now compare through and the query parser keys `=` marks on, so two spellings of one
///          word are one filter by the same code that filters (no behaviour change here)
///   1.2 — FRUS Explorer Light S13b: `Word` and `contains(_:inUTF8:)`, the same answers read from a text's UTF-8
///          bytes, which `frus_exact_word` calls and `contains(word:in:)` goes through; `containsByFolding(word:in:)`,
///          the answer by definition, for the tests (no behaviour change)
public enum ExactWordMatcher {

    /// Normalises text the way `unicode61` does before comparison: diacritics folded,
    /// lowercased.
    ///
    /// Folding uses the POSIX locale rather than the user's. With a Turkish locale,
    /// `I` lowercases to a dotless `ı`, which would silently change which documents
    /// match based on a device setting the corpus knows nothing about.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Splits `text` into index tokens on `unicode61`'s boundaries.
    public static func tokens(in text: String) -> [String] {
        normalize(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// The one index word `text` is — its only token, normalised by this matcher's fold — or `nil` when `text` is
    /// not exactly one token.
    ///
    /// The fold is close to `unicode61`'s and not the same. Both fold case and a single accent on a Latin letter
    /// (`café`, `cafe`), and neither folds a letter such as `ø`, `ł` or `đ`. This fold also removes stacked diacritics,
    /// `ß` and Greek accents, which `unicode61` at its default `remove_diacritics=1` keeps, so `Diệm` and `Diem`,
    /// `Straße` and `Strasse`, `Αθήνα` and `Αθηνα` are one word here and two terms in the index.
    ///
    /// This is what `contains(word:in:)` compares, so two terms with the same word are the same filter however they
    /// were spelled: `Cold`, `cold.` and `cold` are all `cold`, and `café` and `cafe` are both `cafe`. The query
    /// parser keys its `=` marks on it for that reason, rather than on the spelling a mark was typed with.
    static func word(_ text: String) -> String? {
        let found = tokens(in: text)
        return found.count == 1 ? found[0] : nil
    }

    /// Whether `word` is a usable exact term — that is, whether it is exactly one token.
    ///
    /// Multi-token input (`co-operate`, `U.S.S.R.`) has no single-word answer, so the
    /// sigil degrades to an ordinary stemmed search rather than silently filtering on
    /// one fragment of what the researcher typed.
    public static func isSingleToken(_ word: String) -> Bool {
        self.word(word) != nil
    }

    /// Whether `text` contains `word` as a whole token.
    ///
    /// Returns `false` for a `word` that is not exactly one token — callers should have
    /// rejected those earlier via ``isSingleToken(_:)``; returning `false` here rather
    /// than `true` keeps a mistake visible as missing results instead of a filter that
    /// silently does nothing.
    ///
    /// The answer is ``containsByFolding(word:in:)``'s, read from the text's bytes by ``contains(_:inUTF8:)``.
    public static func contains(word: String, in text: String) -> Bool {
        guard !text.isEmpty, let word = Word(word) else { return false }
        var text = text
        return text.withUTF8 { contains(word, inUTF8: $0) }
    }

    /// Whether `text` contains `word` as a whole token, by definition: the whole text folded by `normalize(_:)` and
    /// split by `tokens(in:)`, which is how ``contains(word:in:)`` answered before it read bytes. Kept so the tests
    /// can hold the bytes to it.
    static func containsByFolding(word: String, in text: String) -> Bool {
        guard !text.isEmpty, let needle = self.word(word) else { return false }
        return tokens(in: text).contains(needle)
    }

    /// Whether any of `texts` contains `word` as a whole token.
    ///
    /// The searched columns are ORed: a term appearing exactly in a header but only in
    /// stemmed form in the body still satisfies an exact search, because the header is
    /// one of the columns the query actually searched.
    public static func contains(word: String, inAnyOf texts: [String?]) -> Bool {
        texts.contains { text in
            guard let text else { return false }
            return contains(word: word, in: text)
        }
    }

    // MARK: - Reading a text as bytes

    /// A word made ready once to be looked for in many texts, as `frus_exact_word` looks for one word in every row a
    /// statement reads: its index word, folded once.
    public struct Word: Sendable {
        /// The index word, `word(_:)`'s.
        let indexWord: String
        /// The index word's bytes when it is ASCII, as an English word is however it was typed (`Argüello` folds to
        /// `arguello`); a text is then read as bytes. Nil for a word the fold leaves a letter such as `ł` in
        /// (`gomułka`), which `tokens(in:)` looks for as before.
        let ascii: [UInt8]?

        /// Nil when `word` is not exactly one token, which no text contains.
        public init?(_ word: String) {
            guard let indexWord = ExactWordMatcher.word(word) else { return nil }
            self.indexWord = indexWord
            ascii = indexWord.utf8.allSatisfy { $0 < 0x80 } ? Array(indexWord.utf8) : nil
        }
    }

    /// Whether the UTF-8 bytes `text` contain `word` as a whole token: the answer ``containsByFolding(word:in:)`` gives
    /// for `String(decoding: text, as: UTF8.self)`, which repairs an ill-formed sequence as `String(cString:)` does.
    ///
    /// ## Regions
    /// The text is read in *regions*, divided at each ASCII separator (an ASCII byte that is not a letter or a digit)
    /// whose neighbours are ASCII bytes or the text's ends. The fold changes no ASCII character but `A`–`Z`, which it
    /// lowercases, and leaves an ASCII character beside ASCII ones as it found it; and no grapheme joins two ASCII
    /// characters but CR LF, two separators. So such a separator divides the folded text where it divides the text, no
    /// token crosses it, and each region's tokens are the ones the fold gives that region alone. Two passes find a token
    /// that is the word:
    /// - a region of ASCII alone holds no separator, since every one in it would divide it, and is one token, the region
    ///   lowercased: `asciiRegionIs(_:in:)` finds the word as such a region, as an occurrence of it between two dividing
    ///   separators or the text's ends;
    /// - a region holding a non-ASCII byte is read by `regionHolds(_:_:)`, scalar by scalar where `scalarClass(of:)`
    ///   classes every one of its non-ASCII scalars, and by `tokens(in:)` otherwise.
    ///
    /// A word whose index word is not ASCII is looked for by `tokens(in:)` over the whole text, as before.
    public static func contains(_ word: Word, inUTF8 text: UnsafeBufferPointer<UInt8>) -> Bool {
        guard !text.isEmpty else { return false }
        guard let needle = word.ascii else {
            return tokens(in: String(decoding: text, as: UTF8.self)).contains(word.indexWord)
        }
        return asciiRegionIs(needle, in: text) || nonASCIIRegionHolds(needle, in: text)
    }

    @inline(__always) private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        byte &- 0x30 < 10 || (byte | 0x20) &- 0x61 < 26
    }

    @inline(__always) private static func isASCIISeparator(_ byte: UInt8) -> Bool {
        byte < 0x80 && !isASCIIAlphanumeric(byte)
    }

    @inline(__always) private static func lowercased(_ byte: UInt8) -> UInt8 {
        byte &- 0x41 < 26 ? byte | 0x20 : byte
    }

    /// Whether the byte at `index` divides `text` into regions: an ASCII separator whose neighbours are ASCII bytes or
    /// the text's ends.
    @inline(__always) private static func dividesRegions(_ text: UnsafeBufferPointer<UInt8>, at index: Int) -> Bool {
        isASCIISeparator(text[index])
            && (index == 0 || text[index - 1] < 0x80)
            && (index + 1 == text.count || text[index + 1] < 0x80)
    }

    /// Whether a region of ASCII alone is `needle`, an ASCII index word: an occurrence of it in either case whose
    /// neighbours are dividing separators or the text's ends.
    private static func asciiRegionIs(_ needle: [UInt8], in text: UnsafeBufferPointer<UInt8>) -> Bool {
        let length = needle.count
        guard length > 0, text.count >= length else { return false }
        let last = text.count - length
        var from = 0
        while let at = nextPossibleStart(of: needle[0], in: text, from: from, through: last) {
            var matched = 0
            while matched < length, lowercased(text[at + matched]) == needle[matched] { matched += 1 }
            let end = at + length
            if matched == length,
               at == 0 || (isASCIISeparator(text[at - 1]) && (at == 1 || text[at - 2] < 0x80)),
               end == text.count || (isASCIISeparator(text[end]) && (end + 1 == text.count || text[end + 1] < 0x80)) {
                return true
            }
            from = at + 1
        }
        return false
    }

    /// Whether a region holding a non-ASCII byte holds a token that is `needle`. Each such region is found from a
    /// non-ASCII byte in it, and read once.
    private static func nonASCIIRegionHolds(_ needle: [UInt8], in text: UnsafeBufferPointer<UInt8>) -> Bool {
        var from = 0
        while let found = nextNonASCII(in: text, from: from) {
            var lower = found
            while lower > from, !dividesRegions(text, at: lower - 1) { lower -= 1 }
            var upper = found + 1
            while upper < text.count, !dividesRegions(text, at: upper) { upper += 1 }
            if regionHolds(UnsafeBufferPointer(rebasing: text[lower..<upper]), needle) { return true }
            from = upper
        }
        return false
    }

    /// An eight-byte step's constants: 0x01, 0x20, 0x7F and 0x80 in every byte.
    private static let everyByte: UInt64 = 0x0101_0101_0101_0101
    private static let caseBits: UInt64 = 0x2020_2020_2020_2020
    private static let lowBits: UInt64 = 0x7F7F_7F7F_7F7F_7F7F
    private static let highBits: UInt64 = 0x8080_8080_8080_8080

    /// The first index from `from` through `last` whose byte is `first`, an ASCII index word's first byte, in either
    /// case, or one of the few others that read the same with 0x20 set, which the caller rules out. Eight bytes at a
    /// step: the scan is most of the time a word that a text lacks takes.
    private static func nextPossibleStart(of first: UInt8, in text: UnsafeBufferPointer<UInt8>,
                                          from: Int, through last: Int) -> Int? {
        guard let base = text.baseAddress, from <= last else { return nil }
        let raw = UnsafeRawPointer(base)
        let pattern = UInt64(first) &* everyByte
        var index = from
        while index + 8 <= text.count, index <= last {
            let bytes = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: index, as: UInt64.self))
            let difference = (bytes | caseBits) ^ pattern
            // The high bit of each byte of `difference` that is zero, and of no other: no carry crosses a byte.
            let zeros = ~(((difference & lowBits) &+ lowBits) | difference | lowBits)
            if zeros != 0 {
                let found = index + zeros.trailingZeroBitCount / 8
                return found <= last ? found : nil
            }
            index += 8
        }
        while index <= last {
            if text[index] | 0x20 == first { return index }
            index += 1
        }
        return nil
    }

    /// The first index from `from` whose byte is not ASCII, eight bytes at a step.
    private static func nextNonASCII(in text: UnsafeBufferPointer<UInt8>, from: Int) -> Int? {
        guard let base = text.baseAddress else { return nil }
        let raw = UnsafeRawPointer(base)
        var index = from
        while index + 8 <= text.count {
            let high = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: index, as: UInt64.self)) & highBits
            if high != 0 { return index + high.trailingZeroBitCount / 8 }
            index += 8
        }
        while index < text.count {
            if text[index] >= 0x80 { return index }
            index += 1
        }
        return nil
    }

    /// Whether `region`, which holds a non-ASCII byte, holds a token that is `needle`: read scalar by scalar when
    /// `scalarClass(of:)` classes each of its non-ASCII scalars, and by `tokens(in:)` otherwise.
    ///
    /// A classed scalar folds alone and joins no grapheme with its neighbours, so the region's folded text is its
    /// scalars' folds one after another, and its tokens are the runs of letters and digits among them: an ASCII byte
    /// lowercased, a scalar's ASCII letters, or a letter that stays itself, which no ASCII word's token holds.
    private static func regionHolds(_ region: UnsafeBufferPointer<UInt8>, _ needle: [UInt8]) -> Bool {
        var holds = false
        // The token being read: whether it has begun, and whether it is still `needle`'s first `matched` bytes.
        var begun = false, isNeedle = true, matched = 0
        func add(_ byte: UInt8) {
            begun = true
            guard isNeedle else { return }
            if matched < needle.count, needle[matched] == byte { matched += 1 } else { isNeedle = false }
        }
        func end() {
            if begun, isNeedle, matched == needle.count { holds = true }
            begun = false
            isNeedle = true
            matched = 0
        }
        var index = 0
        while index < region.count {
            let byte = region[index]
            if byte < 0x80 {
                if isASCIIAlphanumeric(byte) { add(lowercased(byte)) } else { end() }
                index += 1
                continue
            }
            guard let (value, length) = scalarValue(in: region, at: index), let kind = scalarClass(of: value) else {
                return tokens(in: String(decoding: region, as: UTF8.self)).contains(String(decoding: needle, as: UTF8.self))
            }
            switch kind {
            case .separator:
                end()
            case .asciiLetters(let letters):
                for letter in letters { add(letter) }
            case .otherLetter:
                begun = true
                isNeedle = false
            }
            index += length
        }
        end()
        return holds
    }

    /// The scalar a well-formed two- or three-byte sequence at `index` encodes, and its length; nil for any other
    /// bytes, which `tokens(in:)` reads.
    @inline(__always) private static func scalarValue(in region: UnsafeBufferPointer<UInt8>,
                                                      at index: Int) -> (UInt32, Int)? {
        let lead = UInt32(region[index])
        if (0xC2...0xDF).contains(lead), index + 1 < region.count, region[index + 1] & 0xC0 == 0x80 {
            return ((lead & 0x1F) << 6 | UInt32(region[index + 1] & 0x3F), 2)
        }
        if (0xE0...0xEF).contains(lead), index + 2 < region.count,
           region[index + 1] & 0xC0 == 0x80, region[index + 2] & 0xC0 == 0x80 {
            let value = (lead & 0x0F) << 12 | UInt32(region[index + 1] & 0x3F) << 6 | UInt32(region[index + 2] & 0x3F)
            // Not an overlong form, nor a surrogate's.
            if value >= 0x800, !(0xD800...0xDFFF).contains(value) { return (value, 3) }
        }
        return nil
    }

    /// What a non-ASCII scalar is in a token, as `tokens(in:)` reads it between two ASCII letters.
    enum ScalarClass: Equatable, Sendable {
        /// It ends a token, as a space does: `’`, `—`, `§`.
        case separator
        /// It joins the letters beside it and folds to these ASCII letters or digits: `é` to `e`.
        case asciiLetters([UInt8])
        /// It joins the letters beside it and folds to itself: `ʼ`, `½`, a Cyrillic letter. No token that holds one is
        /// an ASCII word.
        case otherLetter
    }

    /// The scalars `scalarClass(of:)` classes: Latin-1 Supplement to Cyrillic, and General Punctuation to Number Forms,
    /// which hold nearly every non-ASCII scalar of the corpus. A region with any other goes to `tokens(in:)`.
    static let classifiedScalars: [ClosedRange<UInt32>] = [0x80...0x4FF, 0x2000...0x218F]

    /// Each classified scalar's class, made once from what `normalize(_:)` and `tokens(in:)` do with it
    /// (`probedClass(of:)`), so it is this platform's answer; nil for a scalar with none.
    private static let scalarClasses: [[ScalarClass?]] = classifiedScalars.map { range in
        range.map { Unicode.Scalar($0).flatMap(probedClass(of:)) }
    }

    /// The class of the scalar `value`, or nil when it has none or lies outside `classifiedScalars`.
    static func scalarClass(of value: UInt32) -> ScalarClass? {
        for (range, classes) in zip(classifiedScalars, scalarClasses) where range.contains(value) {
            return classes[Int(value - range.lowerBound)]
        }
        return nil
    }

    /// The class `normalize(_:)` and `tokens(in:)` give `scalar`, read from the token or tokens it makes between two
    /// ASCII letters; nil for a scalar that is not a letter, a number, punctuation, a symbol or a space, that is not a
    /// starter, that joins a grapheme with an ASCII letter on either side, or that folds otherwise than a class says.
    /// The first two rule out what folds or joins with its neighbours: a combining mark, a format character, ZWJ.
    static func probedClass(of scalar: Unicode.Scalar) -> ScalarClass? {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber,
             .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol, .spaceSeparator:
            break
        default:
            return nil
        }
        guard scalar.properties.canonicalCombiningClass == .notReordered else { return nil }
        let alone = String(scalar)
        let probe = "a" + alone + "b"
        guard probe.count == 3 else { return nil }
        let folded = normalize(alone)
        let probeTokens = tokens(in: probe)
        if probeTokens == ["a" + folded + "b"] {
            if !folded.isEmpty, folded.utf8.allSatisfy(isASCIIAlphanumeric) { return .asciiLetters(Array(folded.utf8)) }
            return folded == alone ? .otherLetter : nil
        }
        if probeTokens == ["a", "b"], folded == alone || (!folded.isEmpty && folded.utf8.allSatisfy(isASCIISeparator)) {
            return .separator
        }
        return nil
    }
}
