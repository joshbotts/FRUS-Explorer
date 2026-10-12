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

// MARK: - KeynessReference

/// A corpus reference a keyness comparison divides by, with the form its words are counted in and
/// the facts a surface states about it (#1608).
///
/// One value, so a surface that ranks against a reference cannot name another one when it says what
/// it ranked against: the counts, the form, the coverage and the stamp all come from the file
/// ``BundledKeynessBaseline`` chose for the scope.
///
/// Version history:
///   1.0 — #1608: initial implementation, replacing the `(terms, totalTokens, cutoffCount)` triple
///          and `BundledKeynessBaseline`'s separate `coverage(for:)` and `generated`
struct KeynessReference: Equatable, Sendable {
    /// The retained terms and their corpus occurrence counts.
    let terms: [String: Int]
    /// The corpus's **true** total for the lens, across every term including the ones truncation
    /// dropped — not the sum of ``terms``.
    let totalTokens: Int
    /// The smallest corpus count that is priced, so a term absent from ``terms`` can be described
    /// precisely ("occurs fewer than N times corpus-wide") rather than confused with a term absent
    /// from the corpus.
    let cutoffCount: Int
    /// The form ``terms`` are counted in. A scope counted in the other form is not comparable.
    let wordForm: WordCloudWordForm
    /// How many distinct terms the corpus had for the lens before truncation, for the provenance
    /// line: ``terms`` holds a head of them.
    let distinctTerms: Int
    /// The generation stamp of the file the reference came from.
    let generated: String
}

// MARK: - BundledKeynessBaseline

/// The corpus reference frequencies keyness measures against, read from `keyness-baseline.json`
/// and, for a scope counted as printed, from `keyness-baseline-printed.json` (#1608).
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
/// A fourth, added by #1373: **language analysis unavailable** — the scope side was counted
/// without a tagger the reference was counted with, so the two sides are different vocabularies
/// however the settings match.
///
/// ## A scope counted as printed has a reference of its own (#1608)
/// Until #1608 a scope counted without the lemmatiser had no reference at all, and Collocates, the
/// word cloud's Distinctive sizing and Related Documents' shared-word chips were refused or
/// withheld for the whole launch. On the owner's iPhone under iOS 27.0.1 iOS never answered the
/// request for the English lemma data, which no change to the app's check can fix. So there are
/// two files, one for each ``WordCloudWordForm``, and ``baseline(for:tuning:includeDiplomatic:languageAnalysis:)``
/// reads the one whose form the verdict counts in (`NaturalLanguageHealth.wordForm`). What it
/// returns says which (``KeynessReference/wordForm``), because every surface that compares printed
/// forms has to say that it did. *Language analysis unavailable* is still returned in two cases: a
/// part-of-speech lens counted without lexical classes, which counted nothing; and a launch with no
/// lemmatiser whose printed-form file did not load.
///
/// Version history:
///   1.0 — S-1: initial implementation
///   1.1 — #1373: `baseline` takes the tagger verdict the scope was counted under
///   1.2 — #1608: the reference counted as printed, read for a verdict with no lemmatiser;
///          `Availability.available` carries a ``KeynessReference``; a second caller of
///          ``prepare()`` waits for the load in flight
@MainActor
enum BundledKeynessBaseline {

    // MARK: - State

    /// The decoded artifacts, by the form their words are counted in; empty before ``prepare()``
    /// completes and after a load that found neither.
    private static var files: [WordCloudWordForm: KeynessBaselineFile] = [:]
    /// The load, once one has started, so a second caller waits for it instead of starting another.
    private static var loading: Task<[WordCloudWordForm: KeynessBaselineFile], Never>?
    /// Set once a load has finished, so a missing file is not re-read on every call.
    private static var loadFinished = false
    /// Memoised digests of the bundled payloads. Hashing two small files is cheap, but not so
    /// cheap that it should happen on every cloud rebuild.
    private static var payloadDigests: (lexicons: String, stopwords: String)?

    /// Whether an artifact is resident. This says nothing about whether it is *usable* for a given
    /// lens, configuration and tagger verdict — ``baseline(for:tuning:includeDiplomatic:languageAnalysis:)``
    /// is the answer to that.
    static var isAvailable: Bool { !files.isEmpty }

    // MARK: - Loading

    /// Decodes both artifacts off the main actor, once. Idempotent; call from a `.task`.
    ///
    /// A caller that arrives while the load is in flight waits for it (#1608). Until then it
    /// returned at once, and a read taken straight after was `.noArtifact` for a file that was a few
    /// milliseconds from being there; two files to decode make that window longer.
    static func prepare() async {
        guard !loadFinished else { return }
        let task = loading ?? Task.detached(priority: .utility) { Self.loadBundled() }
        loading = task
        let loaded = await task.value
        // An injected fixture, or an earlier waiter, got there while this one was suspended.
        guard !loadFinished else { return }
        files = loaded
        loadFinished = true
    }

    /// Reads and decodes the bundled reference of each form. Off the main actor.
    nonisolated static func loadBundled() -> [WordCloudWordForm: KeynessBaselineFile] {
        var loaded: [WordCloudWordForm: KeynessBaselineFile] = [:]
        for wordForm in WordCloudWordForm.allCases {
            let name = KeynessBaselineFile.resourceName(for: wordForm)
            guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                #if DEBUG
                print("[BundledKeynessBaseline] \(name).json not found in bundle.")
                #endif
                continue
            }
            do {
                let file = try JSONDecoder().decode(KeynessBaselineFile.self, from: Data(contentsOf: url))
                // Held to what the file says of itself: a file counted in the other form is not
                // this form's reference whatever it is named, and offering it would score printed
                // forms against dictionary-form counts — the error the second file exists to end.
                guard Self.isReference(file, for: wordForm) else {
                    #if DEBUG
                    print("[BundledKeynessBaseline] \(name).json says its words are counted as "
                          + "\(file.configuration.wordForm.rawValue), not \(wordForm.rawValue); not used.")
                    #endif
                    continue
                }
                loaded[wordForm] = file
            } catch {
                #if DEBUG
                print("[BundledKeynessBaseline] Failed to decode \(name).json — \(error)")
                #endif
            }
        }
        return loaded
    }

    /// Whether `file` is the reference for `wordForm`: its own stamp says its words are counted in
    /// that form.
    nonisolated static func isReference(_ file: KeynessBaselineFile, for wordForm: WordCloudWordForm) -> Bool {
        file.configuration.wordForm == wordForm
    }

    // MARK: - Reading

    /// What a caller gets when it asks for a baseline.
    enum Availability: Equatable {
        /// A usable reference, in the form the scope was counted in.
        case available(KeynessReference)
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
            /// The scope has no reference it can be compared with, for a reason no setting mends
            /// (#1373): a part-of-speech lens was counted without lexical classes, so it counted
            /// nothing; or the scope was counted as printed and the reference counted as printed is
            /// not loaded (#1608).
            case languageAnalysisUnavailable
        }
    }

    /// The corpus reference for one lens, under the tokenisation the caller is actually using.
    ///
    /// The caller must pass its **live** settings, not the defaults: the whole point of the check is
    /// that the app's tokenizer follows user settings while the artifact is fixed at build time.
    ///
    /// The reference is the one counted in the form `languageAnalysis` counts in (#1608): dictionary
    /// forms when its lemmatiser worked, printed forms when it did not. The caller must have counted
    /// the scope in that same form — a tokenizer built with `languageAnalysis.wordForm` — which is
    /// why the form is taken from the verdict here and not passed beside it.
    ///
    /// - Parameters:
    ///   - lens: The lens whose corpus frequencies are wanted.
    ///   - tuning: The tuning the scope side is being counted under.
    ///   - includeDiplomatic: Whether the scope side has the diplomatic stopword layer active
    ///     (the `excludeBoilerplate` setting).
    ///   - languageAnalysis: What the tagger could do when the scope side was counted (#1373) —
    ///     `WordCloudResult.languageAnalysis` for a stored cloud, `NaturalLanguageReadiness`'s
    ///     verdict for a count made now. Required, with no default: a default of "working" is
    ///     exactly the unchecked assumption this parameter exists to remove.
    static func baseline(for lens: WordCloudLens,
                         tuning: WordCloudTuning,
                         includeDiplomatic: Bool,
                         languageAnalysis: NaturalLanguageHealth) -> Availability {
        // Nothing loaded at all reads as missing, whatever the tagger did.
        guard !files.isEmpty else { return .unavailable(.noArtifact) }
        // Before the settings check: a mismatch's message tells the reader to restore a setting,
        // and here no setting would help. A lens the tagger could not serve counted nothing, so
        // there is nothing to compare in either form. Entity lenses fall through to
        // `lensNotPriced`, which is the structural answer for them whatever the tagger does.
        if !lens.isEntity, !languageAnalysis.supports(lens) {
            return .unavailable(.languageAnalysisUnavailable)
        }
        // The entity lenses read no lemma; their answer is the dictionary file's `lensNotPriced`.
        let wordForm: WordCloudWordForm = lens.isEntity ? .dictionary : languageAnalysis.wordForm
        guard let file = files[wordForm] else {
            // The scope was counted as printed and its reference is not here: what was true of
            // every such scope before #1608 is still true of this one.
            return .unavailable(wordForm == .printed ? .languageAnalysisUnavailable : .noArtifact)
        }
        let digests = bundledPayloadDigests()
        let mismatches = file.configuration.mismatches(
            against: tuning, includeDiplomatic: includeDiplomatic,
            lexiconsDigest: digests.lexicons, stopwordsDigest: digests.stopwords)
        guard mismatches.isEmpty else { return .unavailable(.configurationMismatch(mismatches)) }
        guard let lensFile = file.lenses[lens.rawValue], lensFile.totalTokens > 0 else {
            return .unavailable(.lensNotPriced(lens))
        }
        return .available(KeynessReference(
            terms: lensFile.terms, totalTokens: lensFile.totalTokens,
            cutoffCount: lensFile.cutoffCount, wordForm: wordForm,
            distinctTerms: lensFile.distinctTerms, generated: file.generated))
    }

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
    /// Test seam: injects decoded artifacts, and optionally the payload digests, without touching
    /// the bundle.
    ///
    /// Each file is stored under the form its own stamp names, and one that names the other form is
    /// dropped, exactly as a bundled file is (``isReference(_:for:)``). `nil` for both clears the
    /// seam, so the next ``prepare()`` reads the bundle.
    /// - Parameters:
    ///   - injected: The reference counted in dictionary forms, or `nil` for none.
    ///   - printed: The reference counted as printed, or `nil` for none (#1608).
    ///   - digests: The payload digests the configuration check compares with.
    static func injectForTesting(_ injected: KeynessBaselineFile?,
                                 printed: KeynessBaselineFile? = nil,
                                 digests: (lexicons: String, stopwords: String)? = nil) {
        var injectedFiles: [WordCloudWordForm: KeynessBaselineFile] = [:]
        if let injected, isReference(injected, for: .dictionary) { injectedFiles[.dictionary] = injected }
        if let printed, isReference(printed, for: .printed) { injectedFiles[.printed] = printed }
        files = injectedFiles
        loadFinished = !injectedFiles.isEmpty
        loading = nil
        payloadDigests = digests
    }
    #endif
}
