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
