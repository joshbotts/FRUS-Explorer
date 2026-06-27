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

/// Loads and provides the bundled lexicons backing the concept and sentiment
/// word-cloud lenses (`word-cloud-lexicons.json`).
///
/// These lenses can't be derived from `NaturalLanguage` alone — Apple's framework
/// offers no abstract-concept tagger and only document-level (not per-word)
/// sentiment — so each is filtered against a curated, lowercased base-form word
/// set. Membership is an exact match against the tokenizer's lemmatised output.
///
/// The lists are decoded once and cached for the process lifetime.
///
/// Version history:
///   1.0 — Word Cloud v2: sentiment & concept lenses
enum WordCloudLexicons {

    /// On-disk shape of `word-cloud-lexicons.json`.
    private struct Payload: Decodable {
        let concepts: [String]
        let sentimentPositive: [String]
        let sentimentNegative: [String]
    }

    /// Decoded payload, loaded lazily from the app bundle on first access.
    private static let payload: Payload = {
        guard
            let url = Bundle.main.url(forResource: "word-cloud-lexicons", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            #if DEBUG
            print("[WordCloudLexicons] Failed to load word-cloud-lexicons.json; using empty lexicons.")
            #endif
            return Payload(concepts: [], sentimentPositive: [], sentimentNegative: [])
        }
        return decoded
    }()

    /// The abstract-concept lexicon (lowercased).
    static let concepts: Set<String> = Set(payload.concepts.map { $0.lowercased() })

    /// Positively-valenced words (lowercased).
    static let sentimentPositive: Set<String> = Set(payload.sentimentPositive.map { $0.lowercased() })

    /// Negatively-valenced words (lowercased).
    static let sentimentNegative: Set<String> = Set(payload.sentimentNegative.map { $0.lowercased() })

    /// The union of positive and negative words — the set the sentiment lens keeps.
    static let sentimentAll: Set<String> = sentimentPositive.union(sentimentNegative)

    /// The membership set a lexicon-backed lens filters tokens against, or `nil`
    /// for lenses that don't use a bundled lexicon.
    ///
    /// - Parameter lens: The active lens.
    /// - Returns: The concept set for `.concepts`, the combined sentiment set for
    ///   `.sentiment`, and `nil` otherwise.
    static func filter(for lens: WordCloudLens) -> Set<String>? {
        switch lens {
        case .concepts:  return concepts
        case .sentiment: return sentimentAll
        default:         return nil
        }
    }

    /// The sentiment polarity of a term, or `nil` if it carries none.
    ///
    /// - Parameter term: A lowercased base-form word.
    /// - Returns: `.positive`, `.negative`, or `nil`.
    static func polarity(of term: String) -> WordSentiment? {
        let lower = term.lowercased()
        if sentimentPositive.contains(lower) { return .positive }
        if sentimentNegative.contains(lower) { return .negative }
        return nil
    }
}
