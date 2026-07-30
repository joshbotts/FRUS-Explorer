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

// MARK: - BundledKeynessBaseline

/// The corpus reference frequencies keyness measures against, read from `keyness-baseline.json`.
///
/// ## Why a bundled artifact and not a live query
/// The reference side has to be counted by the **same tokenizer over the same field** as the scope
/// side, or keyness compares two different vocabularies. The app's other corpus-wide frequency
/// source, `fts5vocab`, holds SQLite `porter unicode61` stems over four indexed columns; the
/// word-cloud pipeline that produces the scope side yields `NLTagger` lemmas over `body_text`.
/// Those two disagree on ordinary words — `alliance` is `allianc` to one and `alli` to the other —
/// so a cross-source comparison fails *systematically*, and every failure looks like a finding.
///
/// Computing the baseline on device instead would mean an `NLTagger` pass over the whole corpus on
/// first use. `CloudVectorsGenerator` does it once, offline, with the app's own tokenizer.
///
/// ## Nothing here returns a number it cannot stand behind
/// Every read returns an ``Availability`` that either carries a baseline or says why there is none.
/// The alternative — zero counts — is not a degraded answer: it scores *every* scope term as unique
/// to the scope, producing a complete, confident and entirely wrong ranking with nothing on screen
/// to say so.
///
/// Three distinct reasons a caller must be able to tell apart:
/// - **no artifact** — the resource is missing or unreadable.
/// - **lens not priced** — the generator emits `allTerms`, `descriptors` and the four bundled cloud
///   lenses. The three entity lenses have no baseline by construction, because the multi-lens
///   tokenizer refuses them.
/// - **configuration mismatch** — the live tokenisation differs from the artifact's in a way that
///   would put terms in the scope the reference could never have counted. This is not hypothetical:
///   `excludeBoilerplate` is one tap away in the word cloud's own overflow menu, and turning it off
///   fills the scope with `department` and `telegram` against a reference count of zero.
///
/// ## Loading
/// Lazily, off the main actor, like ``BundledCloudVectors`` and for the same reason: nothing on the
/// launch path needs it, and it is large enough that decoding it there would be felt.
///
/// Version history:
///   1.0 — S-1: initial implementation
@MainActor
enum BundledKeynessBaseline {

    // MARK: - State

    /// The decoded artifact; `nil` before ``prepare()`` completes and after a failed load.
    private static var file: KeynessBaselineFile?
    /// Set once a load has been attempted, so a missing file is not re-read on every call.
    private static var loadStarted = false
    /// Memoised digests of the bundled payloads. Hashing two small files is cheap, but not so
    /// cheap that it should happen on every cloud rebuild.
    private static var payloadDigests: (lexicons: String, stopwords: String)?

    /// Whether an artifact is resident. This says nothing about whether it is *usable* for a given
    /// lens and configuration — ``baseline(for:tuning:includeDiplomatic:)`` is the answer to that.
    static var isAvailable: Bool { file != nil }

    // MARK: - Loading

    /// Decodes the artifact off the main actor, once. Idempotent; call from a `.task`.
    static func prepare() async {
        guard file == nil, !loadStarted else { return }
        loadStarted = true
        file = await Task.detached(priority: .utility) { () -> KeynessBaselineFile? in
            guard let url = Bundle.main.url(forResource: "keyness-baseline", withExtension: "json")
            else {
                #if DEBUG
                print("[BundledKeynessBaseline] keyness-baseline.json not found in bundle.")
                #endif
                return nil
            }
            do {
                return try JSONDecoder().decode(KeynessBaselineFile.self, from: Data(contentsOf: url))
            } catch {
                #if DEBUG
                print("[BundledKeynessBaseline] Failed to decode keyness-baseline.json — \(error)")
                #endif
                return nil
            }
        }.value
    }

    // MARK: - Reading

    /// What a caller gets when it asks for a baseline.
    enum Availability: Equatable {
        /// A usable reference. `totalTokens` is the corpus's **true** total for the lens, across
        /// every term including the ones truncation dropped — not the sum of `terms`.
        ///
        /// `cutoffCount` is the smallest corpus count that is priced, so a term absent from `terms`
        /// can be described precisely ("occurs fewer than N times corpus-wide") rather than
        /// confused with a term absent from the corpus.
        case available(terms: [String: Int], totalTokens: Int, cutoffCount: Int)
        /// No baseline, and why.
        case unavailable(Reason)

        /// Why keyness cannot be offered.
        enum Reason: Equatable {
            /// The bundled resource is missing or would not decode.
            case noArtifact
            /// The generator does not price this lens — the three entity lenses.
            case lensNotPriced(WordCloudLens)
            /// The live tokenisation is not comparable to the artifact's.
            case configurationMismatch([KeynessBaselineFile.Configuration.Mismatch])
        }
    }

    /// The corpus reference for one lens, under the tokenisation the caller is actually using.
    ///
    /// The caller must pass its **live** settings, not the defaults: the whole point of the check is
    /// that the app's tokenizer follows user settings while the artifact is fixed at build time.
    ///
    /// - Parameters:
    ///   - lens: The lens whose corpus frequencies are wanted.
    ///   - tuning: The tuning the scope side is being counted under.
    ///   - includeDiplomatic: Whether the scope side has the diplomatic stopword layer active
    ///     (the `excludeBoilerplate` setting).
    static func baseline(for lens: WordCloudLens,
                         tuning: WordCloudTuning,
                         includeDiplomatic: Bool) -> Availability {
        guard let file else { return .unavailable(.noArtifact) }
        let digests = bundledPayloadDigests()
        let mismatches = file.configuration.mismatches(
            against: tuning, includeDiplomatic: includeDiplomatic,
            lexiconsDigest: digests.lexicons, stopwordsDigest: digests.stopwords)
        guard mismatches.isEmpty else { return .unavailable(.configurationMismatch(mismatches)) }
        guard let lensFile = file.lenses[lens.rawValue], lensFile.totalTokens > 0 else {
            return .unavailable(.lensNotPriced(lens))
        }
        return .available(terms: lensFile.terms, totalTokens: lensFile.totalTokens,
                          cutoffCount: lensFile.cutoffCount)
    }

    /// How much of the lens's corpus vocabulary the artifact prices, for the provenance line a
    /// keyness view shows. `nil` when the lens is unpriced.
    ///
    /// A term outside the retained head is not "absent from the corpus" — it is *unpriced*, and a
    /// keyness view that cannot say which is which is misleading about its own coverage.
    static func coverage(for lens: WordCloudLens) -> (retained: Int, distinct: Int, cutoffCount: Int)? {
        guard let lensFile = file?.lenses[lens.rawValue] else { return nil }
        return (retained: lensFile.terms.count, distinct: lensFile.distinctTerms,
                cutoffCount: lensFile.cutoffCount)
    }

    /// The artifact's generation stamp, for the provenance line.
    static var generated: String? { file?.generated }

    // MARK: - Payload digests

    /// SHA-256 of the two bundled payloads the tokenisation depends on.
    ///
    /// An unreadable payload yields an empty digest, which matches no recorded value — so the
    /// failure withholds keyness rather than computing it against something unverified.
    private static func bundledPayloadDigests() -> (lexicons: String, stopwords: String) {
        if let payloadDigests { return payloadDigests }
        func digest(_ resource: String) -> String {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
                  let value = WordCloudPayloadDigest.digest(ofFileAt: url)
            else { return "" }
            return value
        }
        let computed = (lexicons: digest("word-cloud-lexicons"),
                        stopwords: digest("word-cloud-stopwords"))
        payloadDigests = computed
        return computed
    }

    #if DEBUG
    /// Test seam: injects a decoded artifact, and optionally the payload digests, without touching
    /// the bundle.
    static func injectForTesting(_ injected: KeynessBaselineFile?,
                                 digests: (lexicons: String, stopwords: String)? = nil) {
        file = injected
        loadStarted = injected != nil
        payloadDigests = digests
    }
    #endif
}
