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

// MARK: - CollocationConfiguration, live

/// The app's half of Collocates' pass: the configuration resolved from the user's live settings, and the
/// scan behind NaturalLanguage's readiness gate.
///
/// `CollocationConfiguration`, Collocates' window scan and its ranking moved into FRUSCoreKit (FRUS
/// Explorer Light, S29b), where a host builds a configuration over its own values and scans with a tagger
/// of its own. What reads the app's settings and its gate stays here.
///
/// Version history:
///   1.0 — S-2: initial implementation (the configuration and `live`)
///   1.1 — #1608: ``CollocationConfiguration/live(languageAnalysis:)`` takes the verdict
///   1.2 — 2026-11-24 (FRUS Explorer Light, S29b): the configuration moved into FRUSCoreKit; `live` builds
///          it over the app's bundled lists, and the scan the app calls awaits the gate here
extension CollocationConfiguration {

    /// Resolves the live settings once and builds the tokenizer from them and the verdict.
    /// - Parameter languageAnalysis: This process's tagger verdict, awaited by the caller for this
    ///   rebuild (`NaturalLanguageReadiness.verdictWhenReady()`).
    @MainActor
    static func live(languageAnalysis: NaturalLanguageHealth) -> CollocationConfiguration {
        let tuning = WordCloudSettings.tuning
        let includeDiplomatic = UserDefaults.standard
            .object(forKey: WordCloudSettings.Keys.excludeBoilerplate) as? Bool ?? true
        // The kit's configuration over the app's bundled lists: All terms, in the verdict's form.
        return .configured(tuning: tuning, includeDiplomatic: includeDiplomatic,
                           languageAnalysis: languageAnalysis,
                           stopwords: WordCloudStopwords.shared, lexicons: WordCloudLexicons.shared)
    }
}

// MARK: - SearchService + collocation, behind the gate

extension SearchService {

    /// Words the query's matches keep company with, counted with NaturalLanguage's tagger once the
    /// readiness gate has its verdict: the kit's pass (`collocation(for:parameters:windowSize:configuration:reference:tagger:maxMatches:)`,
    /// FRUS Explorer Light, S29b), as the app ran it before it moved.
    ///
    /// - Parameters:
    ///   - results: the retained result set — everything the user could page to, not the page.
    ///   - parameters: the executed query, for its positive terms.
    ///   - windowSize: words either side of each match.
    ///   - configuration: the resolved live tokenisation. The caller resolves it on the main actor.
    ///   - reference: the corpus reference the caller read for `configuration.languageAnalysis`, so
    ///     it is counted in the form the tokenizer counts in (#1608).
    func collocation(
        for results: [SearchResult],
        parameters: SearchParameters,
        windowSize: Int,
        configuration: CollocationConfiguration,
        reference: KeynessReference,
        maxMatches: Int? = nil
    ) async throws -> CollocationAnalysis.Outcome {
        // The tagger's verdict before anything below tokenizes (#1373). Both callers await it on the
        // main actor already; awaiting it here too means a caller that forgets cannot make the
        // process's first tagging block this actor — and every search behind it — for as long as
        // the warm-up waits on its assets.
        _ = await NaturalLanguageReadiness.verdictWhenReady()
        return try await collocation(
            for: results, parameters: parameters, windowSize: windowSize,
            configuration: configuration, reference: reference,
            tagger: NaturalLanguageWordCloudTagger(), maxMatches: maxMatches)
    }
}
