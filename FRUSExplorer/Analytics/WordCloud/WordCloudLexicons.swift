// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Sentiment polarity of a word, used to colour the sentiment lens.
///
/// Version history:
///   1.0 — Word Cloud v2: sentiment & concept lenses
enum WordSentiment: Sendable {
    /// A positively-valenced word ("cooperation", "agreement").
    case positive
    /// A negatively-valenced word ("crisis", "hostility").
    case negative
}

/// The app's bundle-backed `WordCloudLexiconSet`, plus the display helpers only the UI needs.
///
/// The lists, lowercasing, `filter(for:)` and raw polarity all live in `WordCloudKit`, so
/// the app and the offline generator decode the same JSON through the same code. What
/// stays here is the `Bundle.main` lookup and the Differentiate-Without-Color marks, which
/// are presentation.
///
/// A missing or malformed file degrades to empty lexicons rather than trapping — the
/// concept and sentiment lenses then show their "insufficient signal" state, which is the
/// honest result.
///
/// Version history:
///   1.0 — Word Cloud v2: sentiment & concept lenses
///   1.1 — Session 2026-07-04 (UI audit A8): `noColorMark`/`markedTerm`/`bareTerm` —
///          the +/- prefix encoding the sentiment lens and its exports use under
///          Differentiate Without Color
///   2.0 — O-1: reduced to a bundle loader over `WordCloudLexiconSet`; the payload shape,
///          lowercasing, `filter(for:)` and polarity moved to `WordCloudKit`
enum WordCloudLexicons {

    /// The decoded set, loaded once from the app bundle on first access.
    static let shared: WordCloudLexiconSet = {
        guard let url = Bundle.main.url(forResource: "word-cloud-lexicons", withExtension: "json") else {
            #if DEBUG
            print("[WordCloudLexicons] word-cloud-lexicons.json not found in bundle; using empty lexicons.")
            #endif
            return .empty
        }
        do {
            return try WordCloudLexiconSet(contentsOf: url)
        } catch {
            #if DEBUG
            print("[WordCloudLexicons] Failed to load word-cloud-lexicons.json - \(error); using empty lexicons.")
            #endif
            return .empty
        }
    }()

    /// The abstract-concept lexicon (lowercased).
    static var concepts: Set<String> { shared.concepts }

    /// Positively-valenced words (lowercased).
    static var sentimentPositive: Set<String> { shared.sentimentPositive }

    /// Negatively-valenced words (lowercased).
    static var sentimentNegative: Set<String> { shared.sentimentNegative }

    /// The union of positive and negative words - the set the sentiment lens keeps.
    static var sentimentAll: Set<String> { shared.sentimentAll }

    /// The membership set a lexicon-backed lens filters tokens against, or `nil` for
    /// lenses that don't use a bundled lexicon.
    static func filter(for lens: WordCloudLens) -> Set<String>? {
        shared.filter(for: lens)
    }

    /// The sentiment polarity of a term, or `nil` if it carries none.
    ///
    /// - Parameter term: A lowercased base-form word.
    /// - Returns: `.positive`, `.negative`, or `nil`.
    static func polarity(of term: String) -> WordSentiment? {
        switch shared.polarity(of: term.lowercased()) {
        case 1:  return .positive
        case -1: return .negative
        default: return nil
        }
    }

    // MARK: - Differentiate Without Color marks (UI audit A8)

    /// The visible prefix mark for the Differentiate Without Color sentiment
    /// encoding (UI audit A8): "+" for positive terms, "\u{2212}" for negative,
    /// `nil` for neutral - so the sentiment lens is never a hue-only encoding.
    static func noColorMark(for term: String) -> String? {
        switch polarity(of: term) {
        case .positive: return "+"
        case .negative: return "\u{2212}"
        case .none:     return nil
        }
    }

    /// The display form of a term under the no-color sentiment encoding: the term
    /// prefixed with its ``noColorMark(for:)``, or unchanged when neutral.
    static func markedTerm(_ term: String) -> String {
        guard let mark = noColorMark(for: term) else { return term }
        return mark + term
    }

    /// Strips a leading no-color mark from a display term, recovering the bare
    /// term for polarity lookups and analyze/search hand-offs. Tokenised terms
    /// never begin with "+" or "\u{2212}", so the strip is unambiguous.
    static func bareTerm(_ display: String) -> String {
        if display.hasPrefix("+") || display.hasPrefix("\u{2212}") {
            return String(display.dropFirst())
        }
        return display
    }
}
