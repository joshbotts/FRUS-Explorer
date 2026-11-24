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

/// The app's half of Related Documents' shared-word chips: the entry over `AppState`, the pass behind
/// NaturalLanguage's readiness gate, and the reload identity that follows the gate's verdict.
///
/// `SemanticSharedTerms` moved into FRUSCoreKit (FRUS Explorer Light, S29b), where its pass counts with
/// the tagger and the stopwords its caller gives; what reads the app's state, its bundled references and
/// its gate stays here, so the chips are what they were.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29b): out of `SemanticSharedTerms.swift`, which moved into
///          FRUSCoreKit: ``SemanticSharedTerms/sharedTerms(anchor:candidates:appState:)`` and
///          ``SemanticSharedTerms/reloadToken(for:)`` unchanged, and the gated
///          ``SemanticSharedTerms/evidence(anchor:candidates:pipeline:reference:)`` over the kit's pass
extension SemanticSharedTerms {

    /// The part of Related Documents' reload identity that follows the tagger (#1608): the form the
    /// settled verdict counts in, and dictionary forms until there is one.
    ///
    /// The list reloads when this changes, and at no other re-check. A re-check that adopts a
    /// lemmatiser turns shared words compared as printed into ones compared in dictionary forms,
    /// and the note above the rows says "right now", so they are compared again and the note goes.
    /// A re-check that adopts names or lexical classes changes nothing this list shows; reloading
    /// for it would re-rank an open list and lose the reader's place for the same rows, on a launch
    /// whose lemmatiser works, which is why the identity does not take the monitor's revision.
    /// Before a verdict exists the pass waits for one, so "dictionary" then is a placeholder that a
    /// verdict with a lemmatiser leaves as it is.
    /// - Parameter status: `LanguageAnalysisMonitor.shared.status`.
    static func reloadToken(for status: NaturalLanguageReadiness.Status) -> String {
        guard case .settled(let verdict) = status else { return WordCloudWordForm.dictionary.rawValue }
        return verdict.health.wordForm.rawValue
    }

    /// Computes the shared distinctive terms between an anchor and each candidate.
    ///
    /// Reads every text in one keyed query and tokenises each document once, so the cost is linear in
    /// the displayed rows rather than quadratic. The lexical assessment measured this class of query
    /// at ~50 ms for a comparable row count.
    ///
    /// - Parameters:
    ///   - anchor: The document the rows are related to.
    ///   - candidates: The displayed candidates to explain.
    ///   - appState: Supplies the index and the tokenisation payloads.
    /// - Returns: Display-form terms per candidate — a candidate with no distinctive overlap is
    ///   absent rather than present with an empty list — and the form they were compared in.
    @MainActor
    static func sharedTerms(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async -> Evidence {
        guard !candidates.isEmpty, let pipeline = appState.indexingPipeline else { return .none }

        // The corpus reference. Unavailable means unpriced, not "every term is rare" — ranking
        // without it would put the anchor's most ordinary words first. Awaited, so a panel opened
        // while the launch decode is still in flight reads the reference rather than its absence.
        await BundledKeynessBaseline.prepare()
        let tuning = WordCloudTuning.standard
        // The terms below are counted in this process, so its tagger verdict decides the form they
        // are counted in and the reference that prices them (#1373, #1608): lemmas against the
        // reference counted in lemmas, or, with no lemmatiser, printed forms against the one
        // counted as printed. Never one against the other, which would skip every inflected word
        // as unpriced and name only the uninflected ones. Awaited on every call, so the main actor
        // is not blocked while the warm-up waits on its assets, and a re-check that replaced the
        // verdict is read (#1539).
        let languageAnalysis = await NaturalLanguageReadiness.verdictWhenReady().health
        guard case .available(let reference) = BundledKeynessBaseline.baseline(
            for: lens, tuning: tuning, includeDiplomatic: true,
            languageAnalysis: languageAnalysis)
        else { return .none }
        return await evidence(anchor: anchor, candidates: candidates, pipeline: pipeline,
                              reference: reference)
    }

    /// The pass itself, against a reference the caller read: fetch the texts, count each in the
    /// reference's form, and name the rarest words the anchor shares with each candidate: the kit's pass
    /// (FRUS Explorer Light, S29b), with NaturalLanguage's tagger and the bundled stopwords, once the
    /// readiness gate has its verdict.
    ///
    /// ``sharedTerms(anchor:candidates:appState:)`` reads the reference for this process's verdict
    /// and calls it; nothing else in the app does. It is a function of its own so a test can run the
    /// pass in a form its host's verdict would not choose (#1608).
    ///
    /// - Parameters:
    ///   - anchor: The document the rows are related to.
    ///   - candidates: The displayed candidates to explain.
    ///   - pipeline: The index the texts are read from.
    ///   - reference: The corpus reference, which also fixes the form the texts are counted in.
    /// - Returns: Display-form terms per candidate, and the reference's form.
    @MainActor
    static func evidence(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        pipeline: IndexingPipeline,
        reference: KeynessReference
    ) async -> Evidence {
        // The warm-up before anything below tags (#1373). The app's caller has awaited it already,
        // to read the reference; awaited here too, so a caller that was handed a reference cannot
        // make this the process's first tagging and hold the main thread for as long as the
        // warm-up waits on its assets.
        _ = await NaturalLanguageReadiness.verdictWhenReady()
        // The kit's pass, on the main actor as before, with NaturalLanguage's tagger through the gate
        // and the bundled stopwords.
        return await evidence(anchor: anchor, candidates: candidates, pipeline: pipeline,
                              reference: reference, stopwords: WordCloudStopwords.shared,
                              tagger: NaturalLanguageWordCloudTagger())
    }
}
