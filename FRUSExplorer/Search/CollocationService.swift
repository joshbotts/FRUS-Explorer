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

// MARK: - CollocationConfiguration

/// The tokenisation a collocation pass runs under, resolved **once**.
///
/// This type exists because of a failure mode the configuration guard cannot catch on its own:
/// `BundledKeynessBaseline.baseline(for:tuning:includeDiplomatic:languageAnalysis:)` validates the
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
struct CollocationConfiguration: Sendable {

    /// The live word-cloud tuning the scope is counted under.
    let tuning: WordCloudTuning
    /// Whether the diplomatic stopword layer is active. In this codebase that is the
    /// `excludeBoilerplate` setting **verbatim, not inverted** — see `WordCloudLoader.load`.
    let includeDiplomatic: Bool
    /// The tagger verdict the pass runs under (#1608). The tokenizer counts in its form, and the
    /// host hands this same value to `BundledKeynessBaseline.baseline`, which reads the reference
    /// counted in that form.
    let languageAnalysis: NaturalLanguageHealth
    /// The tokenizer built from exactly those values.
    let tokenizer: WordCloudTokenizer

    /// Resolves the live settings once and builds the tokenizer from them and the verdict.
    /// - Parameter languageAnalysis: This process's tagger verdict, awaited by the caller for this
    ///   rebuild (`NaturalLanguageReadiness.verdictWhenReady()`).
    @MainActor
    static func live(languageAnalysis: NaturalLanguageHealth) -> CollocationConfiguration {
        let tuning = WordCloudSettings.tuning
        let includeDiplomatic = UserDefaults.standard
            .object(forKey: WordCloudSettings.Keys.excludeBoilerplate) as? Bool ?? true
        return CollocationConfiguration(
            tuning: tuning,
            includeDiplomatic: includeDiplomatic,
            languageAnalysis: languageAnalysis,
            // `.allTerms` — the lens the reference prices most deeply, and the one a collocate list
            // wants: a neighbour is interesting whatever part of speech it is.
            tokenizer: WordCloudTokenizer.configured(
                tuning: tuning, lens: .allTerms, includeDiplomatic: includeDiplomatic,
                wordForm: languageAnalysis.wordForm))
    }
}
