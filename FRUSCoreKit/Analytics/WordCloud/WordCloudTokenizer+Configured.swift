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

/// The assembly of a `WordCloudTokenizer` from a reader's settings and the word lists, over lists its
/// host gives (FRUS Explorer Light, S29b).
///
/// The app's assembly (`WordCloudTokenizer.configured(tuning:lens:includeDiplomatic:extraStopwords:wordForm:)`,
/// in the app) reads its bundled lists and calls this one, so the app's count, its collection-cloud
/// exporter, its settings bench and a host's count build their tokenizer by one rule from the same kind
/// of values. The generator builds its own from injected sets and `WordCloudTuning.standard`.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29b): the app's assembly, over the lists a host gives
extension WordCloudTokenizer {

    /// Builds the tokenizer a count uses, from a tuning, a lens and the word lists.
    ///
    /// A settings preview built from a *different* assembly than the cloud would be a preview of
    /// nothing, so the assembly is stated once, here, for the app and its hosts alike.
    ///
    /// - Parameters:
    ///   - tuning: The user's tunable criteria.
    ///   - lens: The semantic filter in force.
    ///   - includeDiplomatic: Whether the diplomatic-boilerplate stopword layer is active
    ///     (the `excludeBoilerplate` setting — deliberately not a `WordCloudTuning` field,
    ///     since it selects a stopword layer rather than tuning a threshold).
    ///   - extraStopwords: The user's global + per-lens hidden words, plus any per-scope ones.
    ///   - wordForm: The form to count words in (#1608): the form of the verdict the count is made
    ///     under, `NaturalLanguageHealth.wordForm`. Required, with no default, because a count
    ///     that will be compared with a keyness reference has to be in that reference's form, and a
    ///     default of dictionary forms is the assumption a launch with no lemmatiser breaks.
    ///   - stopwords: The stopword lists: the always-on English layer, the diplomatic layer and the
    ///     classification markings (the app's bundled `word-cloud-stopwords.json`).
    ///   - lexicons: The lexicons a lexicon-backed lens keeps its words from (the app's bundled
    ///     `word-cloud-lexicons.json`).
    public static func configured(tuning: WordCloudTuning,
                                  lens: WordCloudLens = .allTerms,
                                  includeDiplomatic: Bool,
                                  extraStopwords: Set<String> = [],
                                  wordForm: WordCloudWordForm,
                                  stopwords: WordCloudStopwordSet,
                                  lexicons: WordCloudLexiconSet) -> WordCloudTokenizer {
        WordCloudTokenizer(
            stopwords: stopwords.active(includeDiplomatic: includeDiplomatic)
                .union(extraStopwords),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            lexicon: lexicons.filter(for: lens),
            markings: tuning.filterMarkings ? stopwords.markings : [],
            wordForm: wordForm
        )
    }
}
