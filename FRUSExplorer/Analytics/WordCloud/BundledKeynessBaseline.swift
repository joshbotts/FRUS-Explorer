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
//
// Moved to FRUSCoreKit (`FRUSCoreKit/Analytics/WordCloud/KeynessReferences.swift`, FRUS Explorer Light, S29b),
// with this loader's lookup and refusals over values (`KeynessReferences`), which a host reads by URL.

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
///   1.3 — 2026-11-23 (FRUS Explorer Light, S29a): the reference is held to the tokenizer the scope
///          was counted by, NaturalLanguage's, as to its settings (`Mismatch.tokenizer`)
///   1.4 — 2026-11-24 (FRUS Explorer Light, S29b): the lookup, its refusals and a file's reading by URL
///          are FRUSCoreKit's (`KeynessReferences`), which this loader asks over what it holds
///          (``references``); `Availability` is the kit's; `KeynessCloud.rank` reads it here
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

    /// What this loader holds, as the kit's lookup reads it (S29b): the loaded files and the bundled
    /// payloads' digests. With nothing loaded it is `KeynessReferences.none`, so the digests are hashed
    /// only once a reference is there to compare them with, as before.
    static var references: KeynessReferences {
        guard !files.isEmpty else { return .none }
        let digests = bundledPayloadDigests()
        return KeynessReferences(files: files, lexiconsDigest: digests.lexicons,
                                 stopwordsDigest: digests.stopwords)
    }

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
        adopt(await task.value)
    }

    /// Stores what a load read, unless something is already there: an earlier waiter stored the
    /// same files, or a test injected a fixture, while this caller was suspended on the load.
    ///
    /// ``prepare()`` is its one caller in the app. It is a function of its own so the rule can be
    /// tested with no suspension between the fixture and the read (`PrintedFormReferenceLoadingTests`):
    /// every suite that injects a reference shares this loader's one static.
    /// - Parameter loaded: What ``loadBundled()`` returned.
    static func adopt(_ loaded: [WordCloudWordForm: KeynessBaselineFile]) {
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
            // Read and held to what the file says of itself by the kit (S29b): a file counted in the
            // other form is not this form's reference whatever it is named
            // (`KeynessReferences.file(at:for:)`).
            switch KeynessReferences.file(at: url, for: wordForm) {
            case .success(let file): loaded[wordForm] = file
            case .failure(let failure): report(failure, name: name, wordForm: wordForm)
            }
        }
        return loaded
    }

    /// Says in a debug build why `name`.json is not `wordForm`'s reference, in the words the loader
    /// has always printed.
    nonisolated private static func report(_ failure: KeynessReferences.LoadFailure, name: String,
                                           wordForm: WordCloudWordForm) {
        #if DEBUG
        switch failure {
        case .otherForm(let stated):
            print("[BundledKeynessBaseline] \(name).json says its words are counted as "
                  + "\(stated.rawValue), not \(wordForm.rawValue); not used.")
        case .unreadable(let error):
            print("[BundledKeynessBaseline] Failed to decode \(name).json — \(error)")
        }
        #endif
    }

    /// Whether `file` is the reference for `wordForm`: its own stamp says its words are counted in
    /// that form. The kit's rule (`KeynessReferences.isReference(_:for:)`) since S29b.
    nonisolated static func isReference(_ file: KeynessBaselineFile, for wordForm: WordCloudWordForm) -> Bool {
        KeynessReferences.isReference(file, for: wordForm)
    }

    // MARK: - Reading

    /// What a caller gets when it asks for a baseline: the kit's (`KeynessReferences.Availability`) since
    /// S29b, a usable reference or why there is none.
    typealias Availability = KeynessReferences.Availability

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
        // The kit's lookup and refusals (S29b) over what this loader holds. Every count the app makes
        // is NaturalLanguage's, through the readiness gate (S29a).
        references.baseline(for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                            languageAnalysis: languageAnalysis, tokenizer: .naturalLanguage)
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

// MARK: - KeynessCloud, against the bundled references

extension KeynessCloud {

    /// Ranks a computed cloud's terms by keyness against the bundled corpus reference: the kit's ranking
    /// (FRUS Explorer Light, S29b) against the reference ``BundledKeynessBaseline`` holds for the scope,
    /// NaturalLanguage's counts' (`KeynessCloud.rank(terms:scopeTotal:fetchedTermCount:termLimit:availability:minimumScopeCount:)`).
    /// On the main actor, as the loader is.
    ///
    /// - Parameters:
    ///   - terms: The scope's terms, as the cloud computed them — already truncated to the cloud's
    ///     limit, and already minus any words hidden from this cloud.
    ///   - scopeTotal: The scope's **true** token total. `WordCloudResult.totalTokenCount` is
    ///     accumulated across every document before truncation, so it is the right value; the sum of
    ///     `terms` is not, and would inflate every relative frequency.
    ///   - fetchedTermCount: How many terms the cloud actually FETCHED, before any per-cloud
    ///     hides. `terms` is the post-hide set, and judging truncation from it is wrong: hiding a
    ///     single word takes a full 220-term fetch to 219 and would flip the disclosure from
    ///     "ranked among the top 220" to "ranked over everything", which is false.
    ///   - termLimit: The limit the cloud requested, so a ranking can tell whether the candidate set
    ///     was cut by that limit or by the floor.
    ///   - lens: The lens the terms were counted under.
    ///   - tuning: The **live** tuning the terms were counted under — not `.standard`. The reference
    ///     is fixed at build time while the app's tokenizer follows user settings, and this is the
    ///     value that decides whether the two are comparable.
    ///   - includeDiplomatic: Whether the diplomatic stopword layer was active. In this codebase
    ///     that is the `excludeBoilerplate` setting **verbatim, not inverted** — see
    ///     `WordCloudLoader.load`.
    ///   - languageAnalysis: What the tagger could do when `terms` were counted — the result's own
    ///     `WordCloudResult.languageAnalysis`, not this process's verdict, since a cloud read from
    ///     the disk cache was counted by another process (#1373). It also chooses the reference
    ///     (#1608): `WordFrequencyService` counts a scope in the verdict's own form, and the
    ///     reference counted in that form is the one read.
    @MainActor
    static func rank(
        terms: [TermCount],
        scopeTotal: Int,
        fetchedTermCount: Int,
        termLimit: Int,
        lens: WordCloudLens,
        tuning: WordCloudTuning,
        includeDiplomatic: Bool,
        languageAnalysis: NaturalLanguageHealth,
        minimumScopeCount: Int = Keyness.defaultMinimumScopeCount
    ) -> Outcome {
        rank(terms: terms, scopeTotal: scopeTotal, fetchedTermCount: fetchedTermCount, termLimit: termLimit,
             availability: BundledKeynessBaseline.baseline(
                for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                languageAnalysis: languageAnalysis),
             minimumScopeCount: minimumScopeCount)
    }
}
