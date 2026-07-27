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

/// The app's assembly of a `WordCloudTokenizer` from user settings and bundled lists.
///
/// This stayed in the app when the tokenizer moved to `WordCloudKit`: it is precisely the
/// step that reaches into `Bundle.main`, which the generator cannot do and must not need
/// to. The generator builds its own tokenizer from injected sets and `WordCloudTuning.standard`.
///
/// Version history:
///   1.0 — O-1: split out of `WordCloudTokenizer` when it moved to `WordCloudKit`
extension WordCloudTokenizer {

    /// Builds the tokenizer the app actually uses, from a tuning and a lens.
    ///
    /// Three call sites assembled this six-line expression independently — the frequency
    /// service, the collection-cloud exporter, and (as of S-5b) the settings bench. A settings
    /// preview built from a *different* assembly than the cloud would be a preview of nothing,
    /// so the assembly is stated once.
    ///
    /// - Parameters:
    ///   - tuning: The user's tunable criteria.
    ///   - lens: The semantic filter in force.
    ///   - includeDiplomatic: Whether the diplomatic-boilerplate stopword layer is active
    ///     (the `excludeBoilerplate` setting — deliberately not a `WordCloudTuning` field,
    ///     since it selects a stopword layer rather than tuning a threshold).
    ///   - extraStopwords: The user's global + per-lens hidden words, plus any per-scope ones.
    static func configured(tuning: WordCloudTuning,
                           lens: WordCloudLens = .allTerms,
                           includeDiplomatic: Bool,
                           extraStopwords: Set<String> = []) -> WordCloudTokenizer {
        WordCloudTokenizer(
            stopwords: WordCloudStopwords.active(includeDiplomatic: includeDiplomatic)
                .union(extraStopwords),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            lexicon: WordCloudLexicons.filter(for: lens),
            markings: tuning.filterMarkings ? WordCloudStopwords.markings : []
        )
    }
}
