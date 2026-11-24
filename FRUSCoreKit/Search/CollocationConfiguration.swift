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

#if canImport(WordCloudKit)
import WordCloudKit
#endif

// MARK: - CollocationConfiguration

/// The tokenisation a collocation pass runs under, resolved **once**.
///
/// This type exists because of a failure mode the configuration guard cannot catch on its own:
/// the reference lookup (`KeynessReferences.baseline`, which the app's `BundledKeynessBaseline` asks) validates the
/// values a caller *claims*, not the ones its tokenizer was actually built with. Passing
/// `includeDiplomatic: true` to the guard while constructing the tokenizer with `false` passes every
/// check and produces a confident, wrong ranking.
///
/// So the two are derived from one value. The tokenizer and the reference lookup both come from
/// here, and there is no second reading of the settings in between.
///
/// The tagger verdict is the same kind of value since #1608, and for the same reason: it decides
/// the form the neighbours are counted in *and* which reference they are ranked against. A host
/// that built the tokenizer under one verdict and looked the reference up under another — a
/// re-check can replace the verdict between two awaits — would rank printed forms against
/// dictionary-form counts. So the verdict is resolved once, held here, and read from here by both.
///
/// Version history:
///   1.0 — S-2: initial implementation
///   1.1 — #1608: ``languageAnalysis``; the tokenizer counts in that verdict's form
///   1.2 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public, out of the app's
///          `CollocationService.swift`, built over values (``configured(tuning:includeDiplomatic:languageAnalysis:stopwords:lexicons:)``);
///          the app's `live(languageAnalysis:)` reads its settings and calls it
public struct CollocationConfiguration: Sendable {

    /// The live word-cloud tuning the scope is counted under.
    public let tuning: WordCloudTuning
    /// Whether the diplomatic stopword layer is active. In this codebase that is the
    /// `excludeBoilerplate` setting **verbatim, not inverted** — see `WordCloudLoader.load`.
    public let includeDiplomatic: Bool
    /// The tagger verdict the pass runs under (#1608). The tokenizer counts in its form, and the
    /// host hands this same value to its reference lookup (`KeynessReferences.baseline`; the app's
    /// `BundledKeynessBaseline.baseline`), which reads the reference counted in that form.
    public let languageAnalysis: NaturalLanguageHealth
    /// The tokenizer built from exactly those values.
    public let tokenizer: WordCloudTokenizer

    /// A configuration of the values given, its tokenizer built from exactly them; a host builds one with
    /// ``configured(tuning:includeDiplomatic:languageAnalysis:stopwords:lexicons:)``.
    public init(tuning: WordCloudTuning, includeDiplomatic: Bool, languageAnalysis: NaturalLanguageHealth,
                tokenizer: WordCloudTokenizer) {
        self.tuning = tuning
        self.includeDiplomatic = includeDiplomatic
        self.languageAnalysis = languageAnalysis
        self.tokenizer = tokenizer
    }

    /// Resolves the settings given, once, and builds the tokenizer from them, the verdict and the word
    /// lists: All terms, in the verdict's word form (FRUS Explorer Light, S29b).
    ///
    /// The app's `live(languageAnalysis:)` reads its settings and calls this with its bundled lists; a host
    /// passes a reader's settings, its lists and its tagger's health, and hands the same configuration to
    /// its reference lookup and to the scan.
    /// - Parameters:
    ///   - tuning: The word-cloud tuning the neighbours are counted under.
    ///   - includeDiplomatic: Whether the diplomatic stopword layer is active (`excludeBoilerplate`,
    ///     verbatim).
    ///   - languageAnalysis: The verdict the pass runs under: the tokenizer counts in its form.
    ///   - stopwords: The stopword lists the tokenizer reads.
    ///   - lexicons: The lexicons the tokenizer reads (All terms keeps none).
    public static func configured(tuning: WordCloudTuning, includeDiplomatic: Bool,
                                  languageAnalysis: NaturalLanguageHealth,
                                  stopwords: WordCloudStopwordSet,
                                  lexicons: WordCloudLexiconSet) -> CollocationConfiguration {
        CollocationConfiguration(
            tuning: tuning,
            includeDiplomatic: includeDiplomatic,
            languageAnalysis: languageAnalysis,
            // `.allTerms` — the lens the reference prices most deeply, and the one a collocate list
            // wants: a neighbour is interesting whatever part of speech it is.
            tokenizer: WordCloudTokenizer.configured(
                tuning: tuning, lens: .allTerms, includeDiplomatic: includeDiplomatic,
                wordForm: languageAnalysis.wordForm, stopwords: stopwords, lexicons: lexicons))
    }
}
