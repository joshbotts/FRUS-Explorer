// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import NaturalLanguage

// MARK: - PersonMention

/// One detected person mention, in the coordinate space the whole #234 program uses.
///
/// `start`/`end` are **Unicode code-point offsets**, half-open, into a document's R-0 text —
/// the same text `harvest_embeddings.py` wrote to `text/<volume>.jsonl.gz` and chunked into the
/// vectors, and the same offsets `harvest_ner.py` writes for the editors' `<persName>` spans.
///
/// Code points, not characters and not UTF-16 units. Python indexes strings by code point, and
/// every other producer and consumer in this program is Python; a Swift harness that used
/// `String.count` (grapheme clusters) or `utf16Offset` would produce spans that look right in
/// ASCII and drift the moment a combining accent or an astral character appears. That is the
/// whole reason ``PersonMentionDetector/mentions(in:tokenRanges:)`` exists as a separate,
/// tested function rather than as arithmetic inside the tagger loop.
public struct PersonMention: Sendable, Equatable {

    /// Code-point offset of the first scalar of the mention.
    public let start: Int

    /// Code-point offset one past the last scalar of the mention.
    public let end: Int

    /// The text the span covers, carried so a row is readable on its own and so any consumer
    /// can check the offsets against the text it holds.
    public let surface: String

    /// Creates a mention.
    public init(start: Int, end: Int, surface: String) {
        self.start = start
        self.end = end
        self.surface = surface
    }
}

// MARK: - DetectorError

/// Fatal conditions in the control detector.
public enum DetectorError: Error, CustomStringConvertible {

    /// A computed span did not slice back to the text the tagger reported.
    case spanMismatch(start: Int, end: Int, expected: String)

    /// A volume's text layer could not be read.
    case unreadableTextLayer(String)

    /// A required input was absent.
    case missingInput(String)

    public var description: String {
        switch self {
        case .spanMismatch(let start, let end, let expected):
            return "computed span [\(start),\(end)) does not slice back to \(expected.debugDescription)"
        case .unreadableTextLayer(let detail):
            return "cannot read text layer: \(detail)"
        case .missingInput(let path):
            return "required input not found: \(path)"
        }
    }
}

// MARK: - PersonMentionDetector

/// Apple's `NLTagger` as the free control detector for #234 R-1.
///
/// This is the baseline every LLM run has to beat: the ride-along priced it at ~1–2 h over the
/// 267-volume scope and it measured at ~8 min (NER-RUNBOOK.md §4.7), against ~18 days for the
/// shortlisted 14 B chat model (§4.8.2), so a hosted detector that merely ties it has no reason to exist. `NER-RUNBOOK.md` §4.2 makes that argument; this type is what lets
/// anyone check it.
///
/// The tagger walk is deliberately the same one `WordCloudKit` already runs corpus-wide —
/// `unit: .word`, `scheme: .nameType`, `[.omitPunctuation, .omitWhitespace, .omitOther,
/// .joinNames]`, language pinned to English — so "the control" means the recogniser this app
/// already ships, not a differently-tuned one.
///
/// A value type with no stored mutable state, so it is `Sendable`. The `NLTagger` itself is
/// created inside the call and never stored: it is a non-`Sendable` class, and the repo's rule
/// (`WordCloudTokenizer`) is that it never becomes part of a `Sendable` type's state.
///
/// Version history:
///   1.0 — Session 2026-08-11: #234 R-1 control detector.
public struct PersonMentionDetector: Sendable {

    /// Whether to pin the tagger to English rather than letting it detect per string.
    ///
    /// Default `true`, matching `WordCloudTokenizer`, whose comment states the reason: the corpus
    /// is English and pinning avoids per-call detection. FRUS does print French and Spanish
    /// enclosures, and on those a pinned tagger is working out of distribution — which is a
    /// property of the control worth knowing rather than hiding, so it is recorded in the run
    /// manifest and can be turned off with `LANGUAGE=auto`.
    public let forceEnglish: Bool

    /// Creates a detector.
    ///
    /// - Parameter forceEnglish: Pin the tagger's language to English (default `true`).
    public init(forceEnglish: Bool = true) {
        self.forceEnglish = forceEnglish
    }

    /// Every personal-name span `NLTagger` finds in one document's text.
    ///
    /// - Parameter text: A document's R-0 text.
    /// - Returns: Mentions in document order, with code-point offsets.
    /// - Throws: ``DetectorError/spanMismatch(start:end:expected:)`` if a computed span does not
    ///   slice back to the tagger's own token text — a corrupt result rather than a wrong one,
    ///   and worth stopping for.
    public func mentions(in text: String) throws -> [PersonMention] {
        var tokenRanges: [Range<String.Index>] = []
        // A fresh tagger per document, deliberately: it is a non-Sendable class and the repo's
        // rule is that it never becomes stored state. WordCloudKit pays the same cost corpus-wide
        // (`SearchService`: "accumulate builds a fresh NLTagger on every call") and lands inside
        // the hour, which is the budget this detector is priced against.
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        if forceEnglish {
            tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        }
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        ) { tag, tokenRange in
            // `return true` continues; it is also how a token is skipped. Returning false would
            // abort the whole enumeration — the inversion this walk is easy to get wrong on.
            if tag == .personalName {
                tokenRanges.append(tokenRange)
            }
            return true
        }
        return try Self.mentions(in: text, tokenRanges: tokenRanges)
    }

    /// Converts tagger token ranges into code-point spans, verifying each one.
    ///
    /// Separated from the tagger walk so the arithmetic — the part that is easy to get wrong and
    /// impossible to notice, because it is right for ASCII — is testable without invoking a
    /// closed-source recogniser whose output changes between OS releases.
    ///
    /// The scan is linear: `tokenRanges` arrives in document order and a cursor walks forward
    /// once, so the cost is one pass over the text rather than one `distance(from:)` from the
    /// start per token.
    ///
    /// - Parameters:
    ///   - text: The document text the ranges index into.
    ///   - tokenRanges: Ranges in `text`, in ascending, non-overlapping order.
    /// - Returns: One mention per range.
    /// - Throws: ``DetectorError/spanMismatch(start:end:expected:)``.
    public static func mentions(in text: String,
                                tokenRanges: [Range<String.Index>]) throws -> [PersonMention] {
        let scalars = Array(text.unicodeScalars)
        var mentions: [PersonMention] = []
        mentions.reserveCapacity(tokenRanges.count)
        var cursor = text.startIndex
        var cursorOffset = 0
        for rawRange in tokenRanges {
            // Whitespace is trimmed off the range BEFORE the offsets are taken, because a person
            // name never begins or ends with it and a span that carries one is off by that much
            // against the gold. `WordCloudTokenizer.accumulateEntities` — the walk this detector
            // deliberately mirrors — trims the same ranges, but only to normalise a string for
            // counting; it produces no offsets, so its trim could not protect this one.
            //
            // It matters here because the error is invisible: an untrimmed span still slices back
            // to its own surface, so `spanMismatch` never fires and the scorer's own span check
            // passes. It would surface only as a systematically zeroed strict-precision column,
            // which reads as a weakness in the recogniser rather than a bug in the harness — the
            // exact misattribution this control exists to rule out.
            guard let tokenRange = Self.trimmingWhitespace(rawRange, in: text) else { continue }
            cursorOffset += text.unicodeScalars.distance(from: cursor, to: tokenRange.lowerBound)
            cursor = tokenRange.lowerBound
            let length = text.unicodeScalars.distance(from: tokenRange.lowerBound,
                                                      to: tokenRange.upperBound)
            let start = cursorOffset
            let end = start + length
            let surface = String(text[tokenRange])
            // start >= 0 and start <= end are checked BEFORE the slice, not implied by it:
            // ranges out of ascending order drive the cursor negative, and `scalars[start..<end]`
            // would trap rather than throw — a crash where a diagnosable error belongs.
            // Compared elementwise rather than by building two Arrays: this runs once per
            // detected mention over the whole 268-volume scope, and the wall-clock argument for
            // this detector existing at all is what makes its constant factors worth a thought.
            guard start >= 0, start <= end, end <= scalars.count,
                  surface.unicodeScalars.count == end - start,
                  zip(scalars[start..<end], surface.unicodeScalars).allSatisfy({ $0 == $1 }) else {
                throw DetectorError.spanMismatch(start: start, end: end, expected: surface)
            }
            mentions.append(PersonMention(start: start, end: end, surface: surface))
            cursorOffset = end
            cursor = tokenRange.upperBound
        }
        return mentions
    }

    /// `range` with leading and trailing whitespace removed, or `nil` when nothing is left.
    ///
    /// Trimming by INDEX rather than by trimming the substring and searching for it again: the
    /// offsets are the product here, and a re-search would find the first occurrence rather than
    /// this one — wrong for any name that appears twice in a document, which is most of them.
    ///
    /// - Parameters:
    ///   - range: A tagger token range.
    ///   - text: The document the range indexes into.
    /// - Returns: The trimmed range, or `nil` if it held only whitespace.
    static func trimmingWhitespace(_ range: Range<String.Index>,
                                   in text: String) -> Range<String.Index>? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, text[lower].isWhitespace { lower = text.index(after: lower) }
        while lower < upper, text[text.index(before: upper)].isWhitespace {
            upper = text.index(before: upper)
        }
        return lower < upper ? lower..<upper : nil
    }
}
