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

/// The bundled cloud-vector artifact: pre-computed word-cloud term lists for every
/// scope the onboarding backdrop can show, so the cloud renders before a single volume
/// is downloaded.
///
/// ## Two files, split by access pattern
/// The generator writes `cloud-vectors-core.json` (the corpus plus all 107 subseries —
/// loaded eagerly and off-main at startup) and `cloud-vectors-volumes.json` (the 552-volume
/// tail — loaded lazily when the Volume segment is first selected). Not one monolith: the
/// splash cannot afford a ~1.5 MB decode on the path to its first frame, and the cloud *is*
/// the splash. Not 552 slices: they would forfeit the shared vocabulary that makes
/// int-indexing pay and add 552 bundle entries to sign and enumerate.
///
/// ## Raw counts, not normalised weights
/// The design hand-off specifies `[term, weight]` with weight normalised 0–100, and
/// separately that "future multi-volume scopes sum raw counts then re-rank". **Those two
/// are incompatible** — summing normalised weights is meaningless, because a term at 100 in
/// a 40-document volume and 100 in a 4,000-document volume are not the same quantity. Since
/// 4b's Subseries segment is already a multi-volume scope, this artifact stores **raw
/// counts** and lets the loader normalise (divide by the first entry, which is the largest
/// because entries are sorted descending). Summation stays exact; the renderer still gets
/// its 0–100.
///
/// Version history:
///   1.0 — O-1: initial implementation
///   1.1 — O-2: moved from `CloudVectorsGeneratorCore` into `WordCloudKit`. The app has to
///         DECODE what the generator ENCODES, and a second app-side copy of this schema is
///         exactly the drift `WordCloudLexiconSet` was created to prevent. One type, one
///         shape, both sides.
public struct CloudVectorsFile: Codable, Sendable, Equatable {

    /// Schema version. Bump when the shape changes in a way a shipped reader would misread.
    public let version: Int

    /// The date stamp of the run that produced this file (`GENERATED_DATE` or today).
    public let generated: String

    /// How this file was made — enough to tell whether a rebuild is warranted.
    public let provenance: Provenance

    /// The lenses carried, in cycle order (`WordCloudLens` raw values).
    public let lenses: [String]

    /// The shared term vocabulary. Entries index into this array.
    ///
    /// Int-indexing is what keeps the volumes file near ~1.5 MB rather than ~2.2 MB: FRUS
    /// vocabulary repeats heavily across 552 volumes, so the same string is stored once.
    /// Each file carries its **own** self-contained vocabulary, so the two can be loaded
    /// and decoded independently.
    public let vocabulary: [String]

    /// Scope key → its per-lens term lists.
    ///
    /// Keys are `"corpus"`, a subseries identifier (`"1969-76"`), or a volume id
    /// (`"frus1969-76v32"`), depending on which file this is.
    public let scopes: [String: ScopeVectors]

    /// Creates a file. Callers should prefer ``CloudVectorsAggregator``.
    public init(version: Int, generated: String, provenance: Provenance,
                lenses: [String], vocabulary: [String], scopes: [String: ScopeVectors]) {
        self.version = version
        self.generated = generated
        self.provenance = provenance
        self.lenses = lenses
        self.vocabulary = vocabulary
        self.scopes = scopes
    }

    /// Run provenance.
    public struct Provenance: Codable, Sendable, Equatable {
        /// Number of volume files tokenised.
        public let volumeCount: Int
        /// Number of `<div type="document">` elements tokenised across them.
        public let documentCount: Int
        /// The tuning the vectors were generated under — always `WordCloudTuning.standard`,
        /// recorded because a user who changes their own tuning will see a live cloud that
        /// differs from this preview, and that is a property worth being able to check.
        public let tuning: WordCloudTuning
        /// Terms kept per (scope, lens) before truncation is reported as such.
        public let topTermsPerList: Int

        /// Creates a provenance stamp.
        public init(volumeCount: Int, documentCount: Int, tuning: WordCloudTuning, topTermsPerList: Int) {
            self.volumeCount = volumeCount
            self.documentCount = documentCount
            self.tuning = tuning
            self.topTermsPerList = topTermsPerList
        }
    }

    /// One scope's lists, keyed by lens raw value.
    public struct ScopeVectors: Codable, Sendable, Equatable {
        /// Lens raw value → its term list.
        public let lists: [String: TermList]

        /// Creates a scope's vectors.
        public init(lists: [String: TermList]) { self.lists = lists }
    }

    /// One lens's terms for one scope, ranked.
    public struct TermList: Codable, Sendable, Equatable {

        /// Total occurrences of **all** matching terms in this scope and lens, before the
        /// top-N truncation. Lets a caller weight a volume by how much of the lens it
        /// actually contains, which the entry counts alone cannot say.
        public let total: Int

        /// Ranked entries, descending by count. The first entry's count is the maximum,
        /// which is what a renderer normalises against.
        public let entries: [Entry]

        /// `true` when this list holds fewer than the lens's `minimumSignalTerms`.
        ///
        /// **Recorded, not suppressed.** The design hand-off specifies a silent fallback to
        /// the subseries list for a thin volume, but a user reading a volume's cloud to
        /// decide whether to download it would then be reading its *era's* vocabulary and
        /// attributing it to the volume. The flag exists so the chip can say so
        /// (`"Topics · 1969–76 (era)"` rather than `"Topics · SALT I"`) — decision O-4-2.
        public let belowSignalThreshold: Bool

        /// Creates a term list.
        public init(total: Int, entries: [Entry], belowSignalThreshold: Bool) {
            self.total = total
            self.entries = entries
            self.belowSignalThreshold = belowSignalThreshold
        }

        /// One ranked term.
        ///
        /// Encoded as a compact array — `[termIndex, count]`, or `[termIndex, count, polarity]`
        /// on the sentiment lens — because at ~110,000 volume entries the JSON key names of an
        /// object encoding would dominate the file.
        public struct Entry: Codable, Sendable, Equatable {
            /// Index into ``CloudVectorsFile/vocabulary``.
            public let term: Int
            /// Raw occurrence count in this scope.
            public let count: Int
            /// `+1` / `-1` for sentiment terms, `nil` on every other lens.
            public let polarity: Int?

            /// Creates an entry.
            public init(term: Int, count: Int, polarity: Int? = nil) {
                self.term = term
                self.count = count
                self.polarity = polarity
            }

            public init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                term = try c.decode(Int.self)
                count = try c.decode(Int.self)
                polarity = c.isAtEnd ? nil : try c.decode(Int.self)
            }

            public func encode(to encoder: any Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode(term)
                try c.encode(count)
                if let polarity { try c.encode(polarity) }
            }
        }
    }
}

// MARK: - KeynessBaselineFile

/// Corpus term frequencies for keyness — the reference side of "what is distinctive about these
/// documents?".
///
/// ## Why this is a third artifact and not more of `cloud-vectors-core.json`
/// The cloud vectors keep the **top 50** terms per list, because a word cloud draws fifty words.
/// A keyness baseline has to answer "how common is *this* term corpus-wide" for whatever terms the
/// researcher's documents happen to contain — a question the top fifty cannot answer for anything
/// outside them. `cloud-vectors-core.json`'s corpus scope holds three terms per lens; using it as a
/// baseline would score every real term against a reference count of zero.
///
/// ## Why not `fts5vocab`, which already has corpus counts
/// Because it counts something else. `fts5vocab` holds SQLite `porter unicode61` **stems** over
/// header, dateline, source note and body; the word-cloud pipeline that produces the *scope* side
/// counts NLTagger **lemmas** over `body_text`. Keyness divides one by the other, so the two must
/// be the same tokenisation of the same field or the ratio is between two different vocabularies —
/// and it fails systematically, mis-scoring every word whose lemma and stem diverge in the same
/// direction. This artifact is produced by the same tokenizer, over the same field, as the scope
/// side, precisely so the division is legitimate.
///
/// The *extraction path* to that field is not identical, and the difference is stated rather than
/// glossed: the generator byte-scans TEI with `TEIBodyTextExtractor` while the app reads
/// `document_cache.body_text` written by `IndexingPipeline`. `CloudVectorsAggregator`'s own
/// "Known divergence from the live cloud" note is the authority on what that costs.
///
/// ## `totalTokens` is not the sum of `terms`
/// It is the true total for the lens, across every term including the ones truncation dropped.
/// A relative frequency computed against the sum of a truncated list is inflated for every term,
/// and inflated *unevenly* between a scope and its reference — which is exactly the error keyness
/// exists to avoid.
///
/// ## The configuration is pinned, because the scope side's is not
/// The generator runs at `WordCloudTuning.standard` with the diplomatic stopword layer on. The app
/// assembles its tokenizer from **live user settings** — and `excludeBoilerplate` is one tap away
/// in the word cloud's own overflow menu. Turn it off and the scope fills with `department`,
/// `telegram`, `washington`, none of which this reference has ever counted; keyness would rank the
/// boilerplate as the corpus's most distinctive vocabulary. ``configuration`` records what the
/// artifact was built under and ``Configuration/mismatches(against:includeDiplomatic:lexiconsDigest:stopwordsDigest:)``
/// is how a caller refuses rather than reports that.
///
/// Version history:
///   1.0 — S-1: initial implementation
public struct KeynessBaselineFile: Codable, Sendable, Equatable {

    /// Schema version.
    public let version: Int
    /// Generation date stamp.
    public let generated: String
    /// The same provenance block the cloud vectors carry.
    public let provenance: CloudVectorsFile.Provenance
    /// The nominal cap on terms retained per lens.
    ///
    /// A lens may hold slightly **more** than this: the cut is extended through the whole tied
    /// band so membership depends only on a term's frequency, never on its spelling. See
    /// `CloudVectorsAggregator.baseline(corpus:...)`.
    public let termsPerLens: Int
    /// The tokenisation the counts were produced under. A scope counted differently is not
    /// comparable to them.
    public let configuration: Configuration
    /// Lens raw value → that lens's baseline.
    public let lenses: [String: Lens]

    // MARK: - Configuration

    /// Everything about the tokenisation that a scope must match for the division to be legitimate.
    public struct Configuration: Codable, Sendable, Equatable {

        /// The tuning the generator ran at.
        public let tuning: WordCloudTuning
        /// Whether the diplomatic-boilerplate stopword layer was active (the app's
        /// `excludeBoilerplate` setting).
        public let includeDiplomatic: Bool
        /// SHA-256 of the lexicon payload the concepts and sentiment lenses were built from.
        public let lexiconsDigest: String
        /// SHA-256 of the stopword payload every lens was filtered by.
        public let stopwordsDigest: String

        /// Creates a configuration stamp.
        public init(tuning: WordCloudTuning, includeDiplomatic: Bool,
                    lexiconsDigest: String, stopwordsDigest: String) {
            self.tuning = tuning
            self.includeDiplomatic = includeDiplomatic
            self.lexiconsDigest = lexiconsDigest
            self.stopwordsDigest = stopwordsDigest
        }

        /// A way in which a scope's tokenisation makes it incomparable to this reference.
        public enum Mismatch: String, Codable, Sendable, Equatable, CaseIterable {
            /// The scope folded plurals differently, so `treaties` and `treaty` are one term on one
            /// side and two on the other.
            case foldPlurals
            /// The scope kept classification markings the reference dropped, or the reverse.
            case filterMarkings
            /// The scope kept diplomatic boilerplate the reference dropped — the
            /// `excludeBoilerplate` toggle.
            case diplomaticLayer
            /// The scope admits tokens shorter than any the reference could have counted.
            case minimumLength
            /// The bundled lexicon payload has changed since the artifact was built.
            case lexicons
            /// The bundled stopword payload has changed since the artifact was built.
            case stopwords
        }

        /// Every way the given scope tokenisation is incomparable to this reference. Empty means
        /// the division is legitimate.
        ///
        /// The test is deliberately **asymmetric**, because the two directions are not equally
        /// harmful. A scope setting that only *removes* terms — a higher `minimumLength`, a higher
        /// `minimumCount`, the user's own hidden words — costs at most a missing row and a slightly
        /// smaller scope total; every term that survives still has a reference count. A setting
        /// that lets a term into the scope which the reference could never have counted gives that
        /// term a reference frequency of zero and floats it to the top of the ranking. Only the
        /// second kind is reported.
        ///
        /// - Parameters:
        ///   - tuning: The tuning the scope was counted under.
        ///   - includeDiplomatic: Whether the scope had the diplomatic stopword layer active.
        ///   - lexiconsDigest: SHA-256 of the lexicon payload the scope used.
        ///   - stopwordsDigest: SHA-256 of the stopword payload the scope used.
        public func mismatches(against tuning: WordCloudTuning,
                               includeDiplomatic: Bool,
                               lexiconsDigest: String,
                               stopwordsDigest: String) -> [Mismatch] {
            var found: [Mismatch] = []
            if tuning.foldPlurals != self.tuning.foldPlurals { found.append(.foldPlurals) }
            if tuning.filterMarkings != self.tuning.filterMarkings { found.append(.filterMarkings) }
            if includeDiplomatic != self.includeDiplomatic { found.append(.diplomaticLayer) }
            // Only a SHORTER minimum admits terms the reference never saw. A longer one just
            // trims the scope.
            if tuning.minimumLength < self.tuning.minimumLength { found.append(.minimumLength) }
            if lexiconsDigest != self.lexiconsDigest { found.append(.lexicons) }
            if stopwordsDigest != self.stopwordsDigest { found.append(.stopwords) }
            return found
        }
    }

    /// One lens's corpus frequencies.
    public struct Lens: Codable, Sendable, Equatable {
        /// **True** total occurrences for this lens across the whole corpus, including terms
        /// truncation dropped. The keyness denominator.
        public let totalTokens: Int
        /// How many distinct terms the corpus had, before truncation — so a reader can see what
        /// fraction `terms` represents.
        public let distinctTerms: Int
        /// The retained terms and their corpus occurrence counts.
        public let terms: [String: Int]
        /// The smallest corpus count that is priced. Every term at or above it is present; no term
        /// below it is.
        ///
        /// This is what makes "absent from `terms`" mean something precise — a caller can say
        /// "occurs fewer than `cutoffCount` times corpus-wide" rather than guessing between
        /// *unpriced* and *absent from the corpus*.
        public let cutoffCount: Int

        /// Creates a lens baseline.
        public init(totalTokens: Int, distinctTerms: Int, terms: [String: Int], cutoffCount: Int) {
            self.totalTokens = totalTokens
            self.distinctTerms = distinctTerms
            self.terms = terms
            self.cutoffCount = cutoffCount
        }
    }

    /// Creates a baseline file.
    public init(version: Int, generated: String, provenance: CloudVectorsFile.Provenance,
                termsPerLens: Int, configuration: Configuration, lenses: [String: Lens]) {
        self.version = version
        self.generated = generated
        self.provenance = provenance
        self.termsPerLens = termsPerLens
        self.configuration = configuration
        self.lenses = lenses
    }
}
