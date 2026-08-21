// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentSubjectCategoryGroup

/// One category group of a document's detected subjects — the second-level grouping the Phase 3
/// on-document subject hierarchy renders.
struct DocumentSubjectCategoryGroup: Sendable, Identifiable {
    /// The category label (e.g. `"Warfare"`).
    let category: String
    /// The subjects in this category, in the index's order.
    let subjects: [VolumeSubjectProfiles.ResolvedSubject]

    var id: String { category }

    /// Creates a category group.
    init(category: String, subjects: [VolumeSubjectProfiles.ResolvedSubject]) {
        self.category = category
        self.subjects = subjects
    }
}

// MARK: - DocumentSubjectIndex

/// A **document-grain** subject lookup: the detected topics for one document (#308 Phase 3).
///
/// Reuses the volume profiles' `ResolvedSubject` so the on-document display and the volume display
/// speak the same shape. Its `score` here is the subject's **distinctiveness** (IDF), not the
/// volume profiles' within-volume TF-IDF: at document grain there is no ranking within a volume to
/// express, and what a reader and a scorer both want to know is how much a tag narrows things down.
///
/// ## The artifact is complete; the tuning is here
/// `document-subject-index.json` carries every subject and every pair, unfiltered, because three
/// features want different things from it (see the artifact's own note). This type does the
/// display-side tuning — ordering by distinctiveness — and exposes ``idf(_:)`` and
/// ``pointwiseMutualInformation(_:_:)`` so `SharedSubjectScorer` can do the similarity-side tuning
/// without a second copy of the data.
///
/// ## What this data is
/// Machine-detected topics from case-insensitive string matching of subject names and variants —
/// **not** semantic analysis. Upstream's own `KNOWN-ISSUES.md` says to treat them as
/// recall-oriented candidates rather than ground truth, and every surface that shows them owes the
/// reader that framing.
///
/// Version history:
///   1.0 — #308 Phase 2: seam type, filled by the Phase 3 data drop
///   2.0 — Session 2026-08-21: #308 Phase 3 — filled
struct DocumentSubjectIndex: Decodable, Sendable {

    /// One subject in the shared vocabulary.
    struct Entry: Decodable, Sendable {
        let ref: String
        let name: String
        let category: String
        let subcategory: String
        let documentFrequency: Int

        enum CodingKeys: String, CodingKey {
            case ref = "r", name = "n", category = "c", subcategory = "s"
            case documentFrequency = "df"
        }
    }

    /// Symmetric subject-pair co-occurrence counts, as parallel arrays.
    struct CoOccurrence: Decodable, Sendable {
        let lower: [Int]
        let higher: [Int]
        let counts: [Int]
        enum CodingKeys: String, CodingKey { case lower = "a", higher = "b", counts = "n" }
    }

    private let vocab: [Entry]
    private let documents: [String: [String: [Int]]]
    /// Canonical pair key → documents carrying both. Built once at decode from the stored arrays.
    private let pairCounts: [Int64: Int]
    /// Documents carrying at least one subject — the `N` in `log(N / df)`.
    private let documentCount: Int
    /// Precomputed `log(N / df)` per vocab index, so scoring never recomputes a logarithm.
    private let idfByIndex: [Double]
    /// Subject ref → vocab index.
    ///
    /// **Stored, not computed.** As a computed property this rebuilt a 491-entry dictionary on
    /// every call — and `pointwiseMutualInformation` calls it twice, inside the scorer's loop over
    /// candidates × shared pairs. A related-documents query would have rebuilt it thousands of
    /// times and simply felt slow, with nothing to point at.
    private let indexByRef: [String: Int]

    /// Decodes from the bundled artifact.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vocab = try c.decode([Entry].self, forKey: .vocab)
        documents = try c.decode([String: [String: [Int]]].self, forKey: .documents)
        documentCount = try c.decode(Int.self, forKey: .documentCount)
        let co = try c.decode(CoOccurrence.self, forKey: .coOccurrence)
        guard co.lower.count == co.higher.count, co.higher.count == co.counts.count else {
            throw DecodingError.dataCorruptedError(
                forKey: .coOccurrence, in: c,
                debugDescription: "co-occurrence arrays differ in length")
        }
        var pairs: [Int64: Int] = [:]
        pairs.reserveCapacity(co.counts.count)
        for i in co.counts.indices {
            pairs[Int64(co.lower[i]) << 32 | Int64(co.higher[i])] = co.counts[i]
        }
        pairCounts = pairs
        indexByRef = Dictionary(uniqueKeysWithValues: vocab.enumerated().map { ($1.ref, $0) })
        let n = Double(max(documentCount, 1))
        idfByIndex = vocab.map { entry in
            entry.documentFrequency > 0 ? log(n / Double(entry.documentFrequency)) : 0
        }
    }

    enum CodingKeys: String, CodingKey {
        case vocab, documents, documentCount, coOccurrence
    }

    // MARK: - Lookups

    /// The detected subjects for a document, **most distinctive first**; `[]` when it has none.
    ///
    /// Ordering is the display-side tuning: a document tagged `War` and `Berlin blockade` should
    /// lead with the one that narrows the corpus, not the one that appears in all 552 volumes.
    func subjects(forDocument key: DocumentKey) -> [VolumeSubjectProfiles.ResolvedSubject] {
        guard let indices = documents[key.volumeId]?[key.documentId] else { return [] }
        return indices
            .filter { vocab.indices.contains($0) }
            .map { index in
                let entry = vocab[index]
                return .init(ref: entry.ref, name: entry.name, category: entry.category,
                             subcategory: entry.subcategory, score: idfByIndex[index])
            }
            .sorted { ($0.score, $1.name) > ($1.score, $0.name) }
    }

    /// The detected subjects for a document grouped by category; `[]` when it has none.
    ///
    /// Categories are ordered by their most distinctive member, so the grouping does not bury the
    /// informative subject under an alphabetically earlier category.
    func hierarchy(forDocument key: DocumentKey) -> [DocumentSubjectCategoryGroup] {
        let all = subjects(forDocument: key)
        guard !all.isEmpty else { return [] }
        var byCategory: [String: [VolumeSubjectProfiles.ResolvedSubject]] = [:]
        for subject in all { byCategory[subject.category, default: []].append(subject) }
        return byCategory
            .map { DocumentSubjectCategoryGroup(category: $0.key, subjects: $0.value) }
            .sorted { a, b in
                let sa = a.subjects.first?.score ?? 0, sb = b.subjects.first?.score ?? 0
                return sa == sb ? a.category < b.category : sa > sb
            }
    }

    // MARK: - Distinctiveness, for the similarity axis


    /// `log(N / df)` for a subject ref — how much knowing this tag narrows the corpus.
    ///
    /// Ranges from **1.40** for `War` (58,480 documents) to **12.38** for a subject on one
    /// document. A shared `War` is nearly no evidence; a shared singleton is nearly conclusive.
    func idf(_ ref: String) -> Double {
        guard let index = indexByRef[ref] else { return 0 }
        return idfByIndex[index]
    }

    /// Pointwise mutual information for a pair of subjects: `log( P(a,b) / (P(a)·P(b)) )`.
    ///
    /// Positive when two subjects co-occur **more** than chance would predict — which is what makes
    /// a shared *combination* evidence in its own right rather than the sum of two coincidences.
    /// Zero when the pair never co-occurs in the corpus (no evidence either way, rather than
    /// negative infinity, which would let one absent pair annihilate a whole score).
    func pointwiseMutualInformation(_ a: String, _ b: String) -> Double {
        guard a != b,
              let ia = indexByRef[a], let ib = indexByRef[b] else { return 0 }
        let key = ia < ib ? Int64(ia) << 32 | Int64(ib) : Int64(ib) << 32 | Int64(ia)
        guard let together = pairCounts[key], together > 0 else { return 0 }
        let n = Double(max(documentCount, 1))
        let pa = Double(vocab[ia].documentFrequency) / n
        let pb = Double(vocab[ib].documentFrequency) / n
        guard pa > 0, pb > 0 else { return 0 }
        return log((Double(together) / n) / (pa * pb))
    }
}

// MARK: - DocumentSubjectStore

/// The document-grain subject seam (design §5.2): the single access point every document-level
/// subject consumer reads — the on-document subject hierarchy, the subject drill-down, and the
/// find-related shared-subjects axis.
///
/// Loaded lazily on first access rather than at `AppState` init, mirroring
/// `VolumeSubjectProfilesStore`. `nil` when the resource is missing or unreadable, and every
/// consumer degrades to "no subjects" — a section that does not appear, and a scorer that returns
/// nothing — never a crash and never an inversion.
///
/// Version history:
///   1.0 — #308 Phase 2: the seam, deliberately empty
///   2.0 — Session 2026-08-21: #308 Phase 3 — the bundle is real
enum DocumentSubjectStore {

    /// The document-grain subject index, or `nil` when it isn't bundled or won't decode.
    static let shared: DocumentSubjectIndex? = load()

    private static func load() -> DocumentSubjectIndex? {
        guard let url = Bundle.main.url(forResource: "document-subject-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[DocumentSubjectStore] document-subject-index.json not found in bundle; "
                + "document subjects unavailable, as they were before #308 Phase 3.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(DocumentSubjectIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[DocumentSubjectStore] document-subject-index.json failed to decode: \(error)")
            #endif
            return nil
        }
    }
}
