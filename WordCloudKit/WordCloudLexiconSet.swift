// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// The curated lexicons backing the concept and sentiment lenses, passed in rather
/// than read from a bundle.
///
/// These lenses cannot be derived from `NaturalLanguage` alone — Apple's framework offers
/// no abstract-concept tagger and only document-level (not per-word) sentiment — so each
/// filters the lemmatised token stream against a curated, lowercased base-form set.
/// Membership is an exact match against the tokenizer's output.
///
/// See ``WordCloudStopwordSet`` for why these are injected rather than bundle-loaded.
///
/// Version history:
///   1.0 — O-1: extracted from the app's `WordCloudLexicons` with payloads injected
public struct WordCloudLexiconSet: Sendable {

    /// On-disk shape of `word-cloud-lexicons.json`.
    public struct Payload: Codable, Sendable {
        public let concepts: [String]
        public let sentimentPositive: [String]
        public let sentimentNegative: [String]

        /// Creates a payload (used by tests; production decodes it).
        public init(concepts: [String], sentimentPositive: [String], sentimentNegative: [String]) {
            self.concepts = concepts
            self.sentimentPositive = sentimentPositive
            self.sentimentNegative = sentimentNegative
        }
    }

    /// The abstract-concept lexicon (lowercased).
    public let concepts: Set<String>
    /// Positively-valenced words (lowercased).
    public let sentimentPositive: Set<String>
    /// Negatively-valenced words (lowercased).
    public let sentimentNegative: Set<String>
    /// The union of positive and negative words — the set the sentiment lens keeps.
    public let sentimentAll: Set<String>

    /// Builds a set from a decoded payload, lowercasing every entry.
    public init(payload: Payload) {
        let positive = Set(payload.sentimentPositive.map { $0.lowercased() })
        let negative = Set(payload.sentimentNegative.map { $0.lowercased() })
        self.concepts = Set(payload.concepts.map { $0.lowercased() })
        self.sentimentPositive = positive
        self.sentimentNegative = negative
        self.sentimentAll = positive.union(negative)
    }

    /// Decodes `word-cloud-lexicons.json` from `url`.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(payload: try JSONDecoder().decode(Payload.self, from: data))
    }

    /// An empty set — both lexicons absent.
    public static let empty = WordCloudLexiconSet(
        payload: Payload(concepts: [], sentimentPositive: [], sentimentNegative: [])
    )

    /// The membership set a lexicon-backed lens filters tokens against, or `nil` for
    /// lenses that don't use a bundled lexicon.
    ///
    /// A `nil` means "no lexicon filter", **not** "reject everything" — the POS and entity
    /// lenses reach the tokenizer with `lexicon: nil` and are filtered by `NLTagger`
    /// instead.
    public func filter(for lens: WordCloudLens) -> Set<String>? {
        switch lens {
        case .concepts:  return concepts
        case .sentiment: return sentimentAll
        default:         return nil
        }
    }

    /// The polarity of a sentiment-lens term: `+1`, `-1`, or `0` when unknown.
    ///
    /// The bundled cloud vectors carry this alongside each sentiment term, which is how a
    /// splash rendered before any volume is downloaded can still colour by polarity.
    public func polarity(of term: String) -> Int {
        if sentimentPositive.contains(term) { return 1 }
        if sentimentNegative.contains(term) { return -1 }
        return 0
    }
}
