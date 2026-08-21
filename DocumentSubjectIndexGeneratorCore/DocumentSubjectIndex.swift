// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentSubjectIndexArtifact

/// `document-subject-index.json` (#308 Phase 3) — every document's detected subjects.
///
/// ## Everything is stored; nothing is filtered
/// This is the **Option A** artifact, by owner decision 2026-08-21: all 491 subjects and all
/// 877,817 (document, subject) pairs. Three features read it and they want different things, so the
/// tuning happens at USE time rather than at build time:
///
/// - **Document display** wants completeness — order by distinctiveness so the informative tag
///   leads, but show what is there.
/// - **Facets** want membership truth. Today they read the volume profiles, which are TOP-15 per
///   volume, so of 76,574 (subject, volume) memberships only **8,268 are selectable — 11.7%**.
///   Scoping to *Agriculture* offers 51 volumes when 526 contain it. This artifact is the complete
///   map that fixes it.
/// - **Similarity** wants distinctiveness amplified — see `SharedSubjectScorer`.
///
/// **A breadth filter was measured and rejected.** The upstream exporter recommends `--max-volumes
/// 200` for "size-constrained bundles", and it is right that a subject in 552 volumes discriminates
/// nothing. But the median tagged document carries only **2** subjects, and for most a broad
/// subject is the ONLY one it has: at that threshold **170,563 of 238,302 documents (72%) lose
/// every tag**. Filtering at build time also does badly by the other two features — it entrenches
/// the facet ceiling, and it makes a scoring decision that can never be retuned. So the breadth
/// penalty lives in the scorer, where it can be weighted, and the artifact stays complete.
///
/// **No era-sanity gate.** Retired for both grains (#1015): it tested the subject HEADING's year
/// while tags come from match VARIANTS that predate the heading, and all 92 of its drops were
/// wrong.
///
/// ## Identity is stored, never derived
/// Document ids are written out. The semantic program's §4.1 implicit keying — document ordinal
/// plus an exception table — mis-keyed 15,097 documents (4.8%) because one letter-suffixed id
/// shifts every document behind it, and a wrong key there does not fail: it shows the wrong
/// documents at plausible scores forever.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 Phase 3
public struct DocumentSubjectIndexArtifact: Codable, Sendable, Equatable {

    /// One subject in the shared vocabulary. Field names mirror
    /// `volume-subject-profiles-index.json`'s `vocab` so the two grains decode alike.
    public struct VocabEntry: Codable, Sendable, Equatable {
        /// Stable subject ref from the source dataset.
        public let ref: String
        /// Display name.
        public let name: String
        /// Top-level category.
        public let category: String
        /// Second-level subcategory.
        public let subcategory: String
        /// **Document frequency** — how many documents carry this subject.
        ///
        /// Stored rather than the derived IDF, because a count is a fact about the corpus while
        /// IDF is one consumer's transformation of it. The scorer computes `log(N / df)`; a display
        /// surface may want the raw count ("in 526 volumes") and should not have to invert a
        /// logarithm to get it back.
        public let documentFrequency: Int

        enum CodingKeys: String, CodingKey {
            case ref = "r", name = "n", category = "c", subcategory = "s"
            case documentFrequency = "df"
        }

        public init(ref: String, name: String, category: String, subcategory: String,
                    documentFrequency: Int) {
            self.ref = ref
            self.name = name
            self.category = category
            self.subcategory = subcategory
            self.documentFrequency = documentFrequency
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// What this was built from, including the source drop's md5 — the same pin
    /// `volume-subject-profiles-index.json` carries, so a mismatch between the two grains is
    /// visible rather than silent.
    public let provenance: String
    /// Total documents carrying at least one subject — the `N` in `log(N / df)`.
    public let documentCount: Int
    /// The subject vocabulary, sorted by ref. Indices into this array are what `documents` stores.
    public let vocab: [VocabEntry]
    /// `volumeId → documentId → [vocab index]`, all sorted.
    ///
    /// Grouped by volume rather than keyed `"volumeId/documentId"`: measured, the flat form the
    /// design sketched costs **8.52 MB** against **5.37 MB** here, and 56% of the difference is the
    /// repeated volume prefix. Same data, same identities, one fewer copy of every volume id.
    public let documents: [String: [String: [Int]]]

    /// How often each pair of subjects appears on the SAME document — the co-occurrence counts the
    /// similarity axis needs for pointwise mutual information (#308, owner decision: PMI in v1).
    ///
    /// ## Why PMI and not IDF alone
    /// IDF prices a shared subject by how rare it is on its own. PMI prices a shared PAIR by how
    /// much rarer their co-occurrence is than chance — two documents sharing
    /// {Korean War, Economic sanctions} is stronger evidence than the two subjects' separate
    /// rarities multiplied, because that combination is itself unusual.
    ///
    /// ## Stored rather than derived, and why that is safe here
    /// It is redundant with ``documents`` — 62,445 pairs, 0.63 MB — and duplicated data is
    /// normally a second thing that can drift. It cannot here: both come out of one generator pass,
    /// and `DocumentSubjectIndexTests` recomputes every count from `documents` and fails on a
    /// mismatch. What it buys is a launch that does not walk 238,302 documents taking pairwise
    /// combinations (one document carries 85 subjects, which alone is 3,570 pairs).
    ///
    /// Parallel arrays under one-letter names, as `CollectionUsageIndex` uses: spelling three field
    /// names out over 62,445 rows costs more than the data.
    public let coOccurrence: CoOccurrence

    /// Symmetric pair counts. `a[i] < b[i]` always, so a lookup canonicalises its pair before
    /// searching and never has to try both orders.
    public struct CoOccurrence: Codable, Sendable, Equatable {
        /// Lower vocab index of each pair.
        public let lower: [Int]
        /// Higher vocab index of each pair.
        public let higher: [Int]
        /// Documents carrying both.
        public let counts: [Int]

        enum CodingKeys: String, CodingKey { case lower = "a", higher = "b", counts = "n" }

        public init(lower: [Int], higher: [Int], counts: [Int]) {
            self.lower = lower
            self.higher = higher
            self.counts = counts
        }

        /// Decodes, refusing arrays that have drifted apart — a truncated read would pair one
        /// subject's index with another pair's count and produce a plausible wrong PMI.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lower = try c.decode([Int].self, forKey: .lower)
            higher = try c.decode([Int].self, forKey: .higher)
            counts = try c.decode([Int].self, forKey: .counts)
            guard lower.count == higher.count, higher.count == counts.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .counts, in: c,
                    debugDescription: "co-occurrence arrays differ: \(lower.count)/\(higher.count)/\(counts.count)")
            }
        }
    }

    public init(schemaVersion: Int, generated: String, provenance: String,
                documentCount: Int, vocab: [VocabEntry],
                documents: [String: [String: [Int]]], coOccurrence: CoOccurrence) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.provenance = provenance
        self.documentCount = documentCount
        self.vocab = vocab
        self.documents = documents
        self.coOccurrence = coOccurrence
    }
}

// MARK: - DocumentSubjectIndexError

/// The fatal conditions this generator refuses to write through.
public enum DocumentSubjectIndexError: Error, CustomStringConvertible {
    /// The source drop yielded no document mappings.
    case noMappings(path: String)
    /// A subject in the mappings is absent from the source's own `subjectsIndex`.
    case unknownSubject(ref: String)

    public var description: String {
        switch self {
        case let .noMappings(path):
            return """
                Refusing to write an empty document-subject index: \(path) produced no document \
                mappings. The corrected export carries 877,817 pairs over 238,302 documents, so \
                zero means the source path or its shape is wrong — check that `subjects` is a \
                subjectId → volumeId → "d1, d2, …" map.
                """
        case let .unknownSubject(ref):
            return """
                Subject \(ref) appears in the document mappings but not in `subjectsIndex`, so it \
                has no name, category or subcategory. Writing it would put an unlabelled row in \
                the vocabulary that every display surface would render as a bare id.
                """
        }
    }
}
