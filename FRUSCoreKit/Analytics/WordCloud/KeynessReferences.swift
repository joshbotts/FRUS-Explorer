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

// MARK: - KeynessReference

/// A corpus reference a keyness comparison divides by, with the form its words are counted in and
/// the facts a surface states about it (#1608).
///
/// One value, so a surface that ranks against a reference cannot name another one when it says what
/// it ranked against: the counts, the form, the coverage and the stamp all come from the file
/// lookup chose for the scope (``KeynessReferences``, which the app's `BundledKeynessBaseline` asks).
///
/// Version history:
///   1.0 — #1608: initial implementation, replacing the `(terms, totalTokens, cutoffCount)` triple
///          and `BundledKeynessBaseline`'s separate `coverage(for:)` and `generated`
///   1.1 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public, with the lookup that
///          chooses it (``KeynessReferences``)
public struct KeynessReference: Equatable, Sendable {
    /// The retained terms and their corpus occurrence counts.
    public let terms: [String: Int]
    /// The corpus's **true** total for the lens, across every term including the ones truncation
    /// dropped — not the sum of ``terms``.
    public let totalTokens: Int
    /// The smallest corpus count that is priced, so a term absent from ``terms`` can be described
    /// precisely ("occurs fewer than N times corpus-wide") rather than confused with a term absent
    /// from the corpus.
    public let cutoffCount: Int
    /// The form ``terms`` are counted in. A scope counted in the other form is not comparable.
    public let wordForm: WordCloudWordForm
    /// How many distinct terms the corpus had for the lens before truncation, for the provenance
    /// line: ``terms`` holds a head of them.
    public let distinctTerms: Int
    /// The generation stamp of the file the reference came from.
    public let generated: String

    /// A reference of `terms`, spelt out so a host can make one (FRUS Explorer Light, S29b).
    public init(terms: [String: Int], totalTokens: Int, cutoffCount: Int, wordForm: WordCloudWordForm,
                distinctTerms: Int, generated: String) {
        self.terms = terms
        self.totalTokens = totalTokens
        self.cutoffCount = cutoffCount
        self.wordForm = wordForm
        self.distinctTerms = distinctTerms
        self.generated = generated
    }
}

// MARK: - KeynessReferences

/// The corpus references keyness measures against, one for each form their words are counted in, with
/// the digests of the word lists a scope's tokenizer reads; and the lookup that gives a scope the
/// reference it can be compared with, or says why there is none.
///
/// `BundledKeynessBaseline`'s lookup and refusals, out of the app (FRUS Explorer Light, S29b), over files
/// a host reads by URL (``init(dictionaryAt:printedAt:lexiconsAt:stopwordsAt:)``): the app's loader reads
/// its bundle, decodes off the main actor and keeps what it read, and asks this value; a host keeps one of
/// its own, of the references its own tokenizer counted.
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
/// A fourth, added by #1373: **language analysis unavailable** — the scope side was counted
/// without a tagger the reference was counted with, so the two sides are different vocabularies
/// however the settings match.
///
/// ## A scope counted as printed has a reference of its own (#1608)
/// There are two files, one for each `WordCloudWordForm`, and
/// ``baseline(for:tuning:includeDiplomatic:languageAnalysis:tokenizer:)`` reads the one whose form the
/// verdict counts in (`NaturalLanguageHealth.wordForm`). What it returns says which
/// (``KeynessReference/wordForm``), because every surface that compares printed forms has to say that it
/// did. A file is held to the form its own stamp names (``isReference(_:for:)``), whatever it was offered
/// as.
///
/// ## The tokenizer (S29a)
/// A reference names the tokenizer that counted it, and refuses a scope another tokenizer counted
/// (`KeynessBaselineFile.Configuration.Mismatch.tokenizer`): the app's counts are NaturalLanguage's, and a
/// host's are its tagger's (`WordCloudTagger.identity`).
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29b): `BundledKeynessBaseline`'s lookup and refusals over
///          values, and the references loaded by URL
public struct KeynessReferences: Sendable, Equatable {

    /// The decoded references, by the form their words are counted in, each the reference of the form its
    /// own stamp names.
    public let files: [WordCloudWordForm: KeynessBaselineFile]
    /// SHA-256 of the lexicons payload the scope's tokenizer reads (`WordCloudPayloadDigest`), which a
    /// reference's configuration records; empty when unreadable, which matches no recorded value.
    public let lexiconsDigest: String
    /// SHA-256 of the stopwords payload the scope's tokenizer reads, as ``lexiconsDigest``.
    public let stopwordsDigest: String

    /// No references: every lookup is ``Availability/Reason/noArtifact``.
    public static let none = KeynessReferences(files: [:], lexiconsDigest: "", stopwordsDigest: "")

    /// References of the files given, each kept only under the form its own stamp names, as the app's
    /// loader keeps a bundled file (``isReference(_:for:)``), with the payloads' digests.
    /// - Parameters:
    ///   - files: The references, by the form each was offered as.
    ///   - lexiconsDigest: SHA-256 of the lexicons payload the scope's tokenizer reads.
    ///   - stopwordsDigest: SHA-256 of the stopwords payload the scope's tokenizer reads.
    public init(files: [WordCloudWordForm: KeynessBaselineFile], lexiconsDigest: String, stopwordsDigest: String) {
        self.files = files.filter { Self.isReference($0.value, for: $0.key) }
        self.lexiconsDigest = lexiconsDigest
        self.stopwordsDigest = stopwordsDigest
    }

    /// The reference counted in dictionary forms and the one counted as printed, either of which may be
    /// missing, with the payloads' digests.
    /// - Parameters:
    ///   - dictionary: The reference counted in dictionary forms, or `nil` for none.
    ///   - printed: The reference counted as printed, or `nil` for none (#1608).
    ///   - lexiconsDigest: SHA-256 of the lexicons payload the scope's tokenizer reads.
    ///   - stopwordsDigest: SHA-256 of the stopwords payload the scope's tokenizer reads.
    public init(dictionary: KeynessBaselineFile?, printed: KeynessBaselineFile?,
                lexiconsDigest: String, stopwordsDigest: String) {
        var files: [WordCloudWordForm: KeynessBaselineFile] = [:]
        files[.dictionary] = dictionary
        files[.printed] = printed
        self.init(files: files, lexiconsDigest: lexiconsDigest, stopwordsDigest: stopwordsDigest)
    }

    /// The references read from their files, `keyness-baseline.json` and `keyness-baseline-printed.json`
    /// as the generator names them (`KeynessBaselineFile.resourceName(for:)`), and the digests of the two
    /// payloads the scope's tokenizer reads. A file that is missing, unreadable or of the other form is
    /// left out, as the app's loader leaves it out, and its lookups say so; a payload that is unreadable
    /// has an empty digest, which matches no reference.
    /// - Parameters:
    ///   - dictionaryAt: The reference counted in dictionary forms, or `nil` for none.
    ///   - printedAt: The reference counted as printed, or `nil` for none.
    ///   - lexiconsAt: The lexicons payload the scope's tokenizer reads (`word-cloud-lexicons.json`).
    ///   - stopwordsAt: The stopwords payload the scope's tokenizer reads (`word-cloud-stopwords.json`).
    public init(dictionaryAt: URL?, printedAt: URL?, lexiconsAt: URL?, stopwordsAt: URL?) {
        func read(_ url: URL?, _ wordForm: WordCloudWordForm) -> KeynessBaselineFile? {
            guard let url, case .success(let file) = Self.file(at: url, for: wordForm) else { return nil }
            return file
        }
        self.init(dictionary: read(dictionaryAt, .dictionary), printed: read(printedAt, .printed),
                  lexiconsDigest: Self.payloadDigest(ofFileAt: lexiconsAt),
                  stopwordsDigest: Self.payloadDigest(ofFileAt: stopwordsAt))
    }

    /// Why a reference's file was not read.
    public enum LoadFailure: Error {
        /// The file could not be read, or would not decode.
        case unreadable(any Error)
        /// The file's own stamp says its words are counted in another form.
        case otherForm(WordCloudWordForm)
    }

    /// Reads and decodes the reference at `url`, held to what the file says of itself: a file counted in
    /// the other form is not this form's reference whatever it is named, and offering it would score
    /// printed forms against dictionary-form counts — the error the second file exists to end.
    /// - Parameters:
    ///   - url: The file.
    ///   - wordForm: The form it is read as the reference of.
    /// - Returns: The file, or why it is not this form's reference.
    public static func file(at url: URL, for wordForm: WordCloudWordForm) -> Result<KeynessBaselineFile, LoadFailure> {
        let file: KeynessBaselineFile
        do {
            file = try KeynessBaselineFile(contentsOf: url)
        } catch {
            return .failure(.unreadable(error))
        }
        guard isReference(file, for: wordForm) else { return .failure(.otherForm(file.configuration.wordForm)) }
        return .success(file)
    }

    /// Whether `file` is the reference for `wordForm`: its own stamp says its words are counted in
    /// that form.
    public static func isReference(_ file: KeynessBaselineFile, for wordForm: WordCloudWordForm) -> Bool {
        file.configuration.wordForm == wordForm
    }

    /// SHA-256 of the payload at `url`, or an empty string, which matches no recorded digest, when there
    /// is none or it cannot be read: the failure withholds keyness rather than computing it against
    /// something unverified.
    public static func payloadDigest(ofFileAt url: URL?) -> String {
        url.flatMap(WordCloudPayloadDigest.digest(ofFileAt:)) ?? ""
    }

    /// Whether a reference is held. This says nothing about whether it is *usable* for a given lens,
    /// configuration and tagger verdict — ``baseline(for:tuning:includeDiplomatic:languageAnalysis:tokenizer:)``
    /// is the answer to that.
    public var isAvailable: Bool { !files.isEmpty }

    // MARK: - Reading

    /// What a caller gets when it asks for a baseline.
    public enum Availability: Equatable, Sendable {
        /// A usable reference, in the form the scope was counted in.
        case available(KeynessReference)
        /// No baseline, and why.
        case unavailable(Reason)

        /// Why keyness cannot be offered.
        public enum Reason: Equatable, Sendable {
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
    ///   - tokenizer: The tokenizer the scope side was counted by: NaturalLanguage's for the app's counts,
    ///     a host's tagger's identity for its own (S29a). A reference counted by another is refused.
    public func baseline(for lens: WordCloudLens,
                         tuning: WordCloudTuning,
                         includeDiplomatic: Bool,
                         languageAnalysis: NaturalLanguageHealth,
                         tokenizer: WordCloudTokenizerIdentity) -> Availability {
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
        let mismatches = file.configuration.mismatches(
            against: tuning, includeDiplomatic: includeDiplomatic,
            lexiconsDigest: lexiconsDigest, stopwordsDigest: stopwordsDigest,
            tokenizer: tokenizer)
        guard mismatches.isEmpty else { return .unavailable(.configurationMismatch(mismatches)) }
        guard let lensFile = file.lenses[lens.rawValue], lensFile.totalTokens > 0 else {
            return .unavailable(.lensNotPriced(lens))
        }
        return .available(KeynessReference(
            terms: lensFile.terms, totalTokens: lensFile.totalTokens,
            cutoffCount: lensFile.cutoffCount, wordForm: wordForm,
            distinctTerms: lensFile.distinctTerms, generated: file.generated))
    }
}
