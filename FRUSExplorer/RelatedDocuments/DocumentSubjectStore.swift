// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CryptoKit

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
    /// Subject ref → **every** volume containing it, sorted.
    ///
    /// ## This is the fix for a 12% facet
    /// The subject facets resolve through `VolumeSubjectProfiles.volumesBySubjectRef`, documented
    /// as "the volumes whose PROFILE carries the subject" — accurate, and easy to read past,
    /// because a profile is the volume's TOP-15. Measured: of 76,574 (subject, volume) memberships
    /// in the data, only **8,268 are selectable — 10.8%**. Scoping a search to *Agriculture* offers
    /// 51 volumes when 526 contain it; *Water* offers 79 of 545. That is not a filter over the
    /// corpus, it is a filter over a TF-IDF-ranked sample of it.
    ///
    /// A ranking artifact was being used as a membership index. Those are different questions: the
    /// top-15 cut is right for "what is this volume about" and wrong for "which volumes touch this
    /// subject".
    private let volumesByRef: [String: [String]]

    /// The artifact's generation date. Read so the facet table's done-markers can be stamped with
    /// the DATA's identity and not only the vocabulary's order — see `applyDocumentSubjectsIfNeeded`.
    let generated: String

    /// The `(category, subcategory)` facet vocabulary, built once at decode.
    let bucketVocabulary: SubjectBucketVocabulary
    /// Vocab index → facet bucket id, so mapping a document's subjects to buckets is an array read.
    private let bucketByVocabIndex: [Int]

    /// Subject ref → vocab index.
    ///
    /// **Stored, not computed.** As a computed property this rebuilt a 491-entry dictionary on
    /// every call — and `pointwiseMutualInformation` calls it twice, inside the scorer's loop over
    /// candidates × shared pairs. A related-documents query would have rebuilt it thousands of
    /// times and simply felt slow, with nothing to point at.
    private let indexByRef: [String: Int]

    /// `volumeId → [ResolvedSubject]`, built once at decode. Backs ``subjectsByVolume``.
    ///
    /// **Stored, not computed — for the same reason `indexByRef` above is, at 155x the scale.**
    /// As a computed property this rebuilt all 76,574 entries on EVERY read: allocate a
    /// `ResolvedSubject` per (subject, volume) pair, append each into a per-volume array through a
    /// dictionary lookup, then sort all 552 arrays. Measured on an iPhone 17 simulator, **278 ms
    /// per access, on the main actor**.
    ///
    /// That cost multiplied at the call sites, because six scope surfaces read the property and one
    /// reads it inside a loop. `SearchFilterView.categories` reads it once and then calls
    /// `ScopeFacets.subCategoryCatalog(resolvedByVolume:)` once per category inside a `filter`
    /// closure — so **typing one character into the topic picker's search field cost 3,623 ms** and
    /// **expanding one category cost 3,204 ms**, both as a single main-actor block.
    ///
    /// There is nothing to invalidate. Every stored property here is a `let`, the type is a
    /// `Sendable` struct, and the only instance is `DocumentSubjectStore.shared`, decoded once from
    /// a bundled artifact that cannot change while the app runs. A re-decode produces a new value
    /// with its own map, so the cache cannot outlive the data it was built from.
    private let subjectsByVolumeCache: [String: [VolumeSubjectProfiles.ResolvedSubject]]

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
        generated = (try? c.decode(String.self, forKey: .generated)) ?? ""
        indexByRef = Dictionary(uniqueKeysWithValues: vocab.enumerated().map { ($1.ref, $0) })
        // Invert to complete subject → volumes membership. 76,574 pairs over 491 subjects; the
        // walk is over volumes, not documents, so it is cheap relative to the decode itself.
        var byRef: [String: Set<String>] = [:]
        for (volumeId, byDocument) in documents {
            for (_, indices) in byDocument {
                for index in indices where vocab.indices.contains(index) {
                    byRef[vocab[index].ref, default: []].insert(volumeId)
                }
            }
        }
        volumesByRef = byRef.mapValues { $0.sorted() }
        let n = Double(max(documentCount, 1))
        idfByIndex = vocab.map { entry in
            entry.documentFrequency > 0 ? log(n / Double(entry.documentFrequency)) : 0
        }

        let vocabulary = SubjectBucketVocabulary(
            pairs: vocab.map { (category: $0.category, subcategory: $0.subcategory) })
        bucketVocabulary = vocabulary
        bucketByVocabIndex = vocab.map { vocabulary.id(category: $0.category, subcategory: $0.subcategory) ?? -1 }

        // Built here rather than on demand — see `subjectsByVolumeCache`. Uses the local `byRef`
        // inversion above rather than re-walking `documents`, and indexes `vocab` positionally
        // instead of through `indexByRef`, so it adds one pass over the 76,574 membership pairs.
        var byVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]] = [:]
        byVolume.reserveCapacity(byRef.count)
        for (index, entry) in vocab.enumerated() {
            guard let volumeIds = byRef[entry.ref] else { continue }
            let resolved = VolumeSubjectProfiles.ResolvedSubject(
                ref: entry.ref, name: entry.name, category: entry.category,
                subcategory: entry.subcategory, score: idfByIndex[index])
            for volumeId in volumeIds { byVolume[volumeId, default: []].append(resolved) }
        }
        for volumeId in byVolume.keys {
            byVolume[volumeId]!.sort { ($0.score, $1.name) > ($1.score, $0.name) }
        }
        subjectsByVolumeCache = byVolume
    }

    enum CodingKeys: String, CodingKey {
        case vocab, documents, documentCount, coOccurrence, generated
    }

    // MARK: - Lookups

    /// Every `(documentId, facet buckets)` row for one volume — the unit the `document_subjects`
    /// table is populated in.
    ///
    /// Buckets are de-duplicated per document: a document tagged with three subjects that share a
    /// subcategory contributes **one** row, so the facet counts documents rather than tags. That is
    /// what makes a bucket count comparable with the years and volumes sections, which count
    /// documents too.
    func bucketRows(forVolume volumeId: String) -> [(documentId: String, buckets: [Int])] {
        guard let byDocument = documents[volumeId] else { return [] }
        return byDocument.compactMap { documentId, indices in
            var seen = Set<Int>()
            for index in indices where bucketByVocabIndex.indices.contains(index) {
                let bucket = bucketByVocabIndex[index]
                if bucket >= 0 { seen.insert(bucket) }
            }
            return seen.isEmpty ? nil : (documentId, seen.sorted())
        }
    }

    /// Every `(documentId, facet buckets, subject positions)` row for one volume — the unit BOTH
    /// subject tables are populated from, in one pass (#1022).
    ///
    /// ## Why one call rather than a sibling of `bucketRows`
    /// The two tables are written inside a single transaction per volume, so a second closure would
    /// walk the same `documents[volumeId]` dictionary twice for rows that must agree by
    /// construction. It also makes the invariant local: a bucket here is
    /// `bucketByVocabIndex[subject]` for one of the subjects in the same tuple, so the grains
    /// cannot drift apart between passes.
    ///
    /// Buckets are de-duplicated (several subjects share a subcategory, and the facet counts
    /// documents); subject positions are de-duplicated too, since a document's index entry can
    /// repeat a subject. A document with subjects but no resolvable bucket still yields a row, so
    /// the subject table does not silently inherit the bucket vocabulary's gaps.
    ///
    /// Positions, not refs. See the `document_subject_refs` schema comment for why, and for what
    /// makes that safe across an artifact re-drop.
    func subjectRows(forVolume volumeId: String)
        -> [(documentId: String, buckets: [Int], subjects: [Int])] {
        guard let byDocument = documents[volumeId] else { return [] }
        return byDocument.compactMap { documentId, indices in
            var buckets = Set<Int>()
            var subjects = Set<Int>()
            for index in indices where vocab.indices.contains(index) {
                subjects.insert(index)
                if bucketByVocabIndex.indices.contains(index) {
                    let bucket = bucketByVocabIndex[index]
                    if bucket >= 0 { buckets.insert(bucket) }
                }
            }
            return subjects.isEmpty ? nil : (documentId, buckets.sorted(), subjects.sorted())
        }
    }

    /// The vocabulary position for a subject ref, or `nil` when the ref is not in this drop.
    ///
    /// The conversion `SearchService.makeFilters` performs to turn a durable `subjectRef` into the
    /// integer `document_subject_refs` stores — the subject-grain counterpart of
    /// ``SubjectBucketVocabulary/id(forKey:)``.
    func subjectPosition(forRef ref: String) -> Int? { indexByRef[ref] }

    /// The vocabulary position for a subject NAME, or `nil` when no subject carries it.
    ///
    /// The fallback half of the durable key. **Measured: 470 opaque upstream record ids, and 21
    /// name-derived refs** — 19 plain slugs plus 2 wearing a `rec_` prefix, which a
    /// `hasPrefix("rec")` test would wrongly call stable. A name-derived ref IS its display name
    /// reduced to alphanumerics, exactly, so renaming a subject re-mints it. A saved search
    /// therefore carries both and resolves ref-first: the ref is exact, and the name catches a ref
    /// that has moved. See `SubjectRefShapeTests`.
    /// Ambiguity is resolved by taking the LOWEST position rather than by refusing, because a
    /// duplicate display name is indistinguishable to the reader who saved the search — measured,
    /// no two subjects in the shipped vocabulary share a name, so this is a guard rather than a
    /// routine path.
    func subjectPosition(forName name: String) -> Int? {
        vocab.enumerated().first { $0.element.name == name }?.offset
    }

    /// Volume ids the index carries subjects for — the population work-list.
    var taggedVolumeIds: [String] { documents.keys.sorted() }

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

    /// The subjects an anchor shares with each candidate, most distinctive first — the evidence
    /// behind the `sharedSubjects` axis's "why related" chip (#1020).
    ///
    /// ## Why the anchor is resolved once and the shape mirrors the semantic pass
    /// Signature deliberately matches `SemanticSharedTerms.sharedTerms(anchor:candidates:)`: that
    /// is the working precedent for an axis naming its own evidence, and a second shape would be a
    /// second thing to keep in step. Unlike that pass this one needs no `await` — the subject index
    /// is an in-memory dictionary — so it is cheap enough to run over displayed rows synchronously.
    ///
    /// Ranking is inherited, not recomputed: ``subjects(forDocument:)`` already returns IDF-descending,
    /// so the shared set arrives most-distinctive-first and `prefix(limit)` is the whole selection.
    /// That matters for the chip — two documents sharing *Berlin blockade* is a finding, and sharing
    /// *War* is not, so the rare one has to be the one that survives the cut.
    ///
    /// - Returns: candidate key → up to `limit` shared subject NAMES. A candidate sharing nothing is
    ///   absent from the result rather than present with `[]`, so a caller can skip it in one check.
    func sharedSubjectNames(anchor: DocumentKey, candidates: [DocumentKey],
                            limit: Int = 3) -> [DocumentKey: [String]] {
        let anchorRefs = Set(subjects(forDocument: anchor).map(\.ref))
        guard !anchorRefs.isEmpty, limit > 0 else { return [:] }
        var out: [DocumentKey: [String]] = [:]
        out.reserveCapacity(candidates.count)
        for candidate in candidates {
            let shared = subjects(forDocument: candidate)
                .lazy.filter { anchorRefs.contains($0.ref) }.prefix(limit).map(\.name)
            if !shared.isEmpty { out[candidate] = Array(shared) }
        }
        return out
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

    // MARK: - Membership, for the facets

    /// **Every** volume containing a subject — the complete map the facets should resolve through.
    func volumeIds(forSubjectRef ref: String) -> Set<String> {
        Set(volumesByRef[ref] ?? [])
    }

    /// The complete subject → volumes map, for building a facet catalogue in one pass.
    var volumesBySubjectRef: [String: [String]] { volumesByRef }

    /// `volumeId → [ResolvedSubject]` covering **every** subject appearing in any of the volume's
    /// documents — the complete counterpart to `VolumeSubjectProfiles.resolvedByVolume`.
    ///
    /// The category and sub-category facets resolve through that profile map, so they inherit its
    /// top-15 cut: a category's volume set is the union of volumes where one of its subjects
    /// happens to RANK, not where its subjects occur. This is the same shape from the same data
    /// without the cut, so `ScopeFacets.categoryCatalog` and `volumeIds(forCategory:)` answer
    /// completely with no change to their signatures.
    ///
    /// `score` is the subject's IDF, as everywhere at this grain — the facets use it only for
    /// ordering, and distinctiveness is the ordering a reader wants (see
    /// ``VolumeSubjectProfiles/ResolvedSubject/score`` for why that matters).
    ///
    /// A stored map since the topic picker was measured freezing the main actor for 3.6 s per
    /// keystroke — see ``subjectsByVolumeCache``.
    var subjectsByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]] { subjectsByVolumeCache }

    /// The full subject vocabulary — all 491, including the **111 that never reach any volume's
    /// top-15** and are therefore invisible to a profile-derived catalogue.
    var subjectVocabulary: [(ref: String, name: String, category: String, subcategory: String)] {
        vocab.map { ($0.ref, $0.name, $0.category, $0.subcategory) }
    }

    /// How many documents in the whole CORPUS carry a subject, from the artifact's own
    /// `documentFrequency`; `nil` when the ref is not in this drop.
    ///
    /// **Corpus-wide, not device-wide, and every surface showing it owes that sentence.** The
    /// bundled index covers all 552 volumes while the SQL tables carry only the volumes this reader
    /// has indexed, so a browse can truthfully say a subject appears in 4,000 documents and then
    /// return 60 — the same split the volume scope menus already face. This is the numerator the
    /// IDF is computed from (`idf(_:)` is `log(N / documentFrequency)`), so the two cannot disagree.
    func documentFrequency(forSubjectRef ref: String) -> Int? {
        indexByRef[ref].map { vocab[$0].documentFrequency }
    }

    /// Every subject in the vocabulary with its corpus reach — the Subject Explorer's catalogue.
    ///
    /// Built from the vocabulary rather than from `volumesBySubjectRef`, so it includes the **111
    /// subjects that reach no volume's top-15** and are invisible to any profile-derived list.
    /// Those are not curiosities: a subject spread thinly across many volumes is precisely what a
    /// reader wants an index for.
    ///
    /// Sorted by name. Reach is deliberately NOT the sort key here — the facet catalogues sort by
    /// reach because a filter is chosen by how much it narrows, while an index is READ
    /// alphabetically, and a 491-row list ordered by a number the reader did not ask about is
    /// unnavigable.
    var subjectCatalogue: [(ref: String, name: String, category: String, subcategory: String,
                            documentCount: Int, volumeCount: Int)] {
        vocab.map { entry in
            (ref: entry.ref, name: entry.name, category: entry.category,
             subcategory: entry.subcategory, documentCount: entry.documentFrequency,
             volumeCount: volumesByRef[entry.ref]?.count ?? 0)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

// MARK: - SubjectBucketVocabulary

/// The facet vocabulary: the distinct `(category, subcategory)` pairs in the subject index, in a
/// fixed order, so a bucket can be stored in SQLite as one integer.
///
/// ## Why the pair, and not the subcategory
/// Exactly one subcategory name is reused — `General`, under **all 13** categories — and it is not a
/// small case: keyed on the bare name it fuses *Warfare / General* (65,958 documents) with
/// *Bilateral Relations / General* (62,013) and eleven more into a single 181,517-document row
/// covering 76.2% of the tagged corpus. That row is the facet's largest and means nothing. Keying on
/// the pair gives 106 buckets whose median is 1,593 documents.
///
/// ## Why an integer, and what protects it
/// `document_subjects` stores 744,054 rows; a text key costs ~19 MB more than an index. The cost of
/// the integer is that it is positional — regenerate the artifact with a new subcategory and every
/// stored row silently means something else. So the order is fixed (sorted by category then
/// subcategory), and ``digest`` pins it: the backfill records the digest it populated under and
/// **rebuilds from scratch** when it changes, rather than trusting indices across a data drop.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 subject results facet
struct SubjectBucketVocabulary: Sendable, Equatable {

    /// One facet bucket.
    struct Bucket: Sendable, Equatable {
        /// Top-level category.
        let category: String
        /// Second-level subcategory.
        let subcategory: String
        /// What the facet row shows — see ``SubjectBucketVocabulary/label(at:)``.
        let label: String
    }

    /// The buckets, sorted by category then subcategory. A bucket's position **is** its stored id.
    let buckets: [Bucket]

    /// A stable fingerprint of the vocabulary and its order. Changes whenever a bucket is added,
    /// removed or reordered, which is exactly when stored bucket ids stop meaning what they meant.
    let digest: String

    /// `"category\u{1F}subcategory"` → bucket id.
    private let idByPair: [String: Int]

    /// Builds the vocabulary from the subject index's entries.
    ///
    /// The label rule is derived from the data rather than special-casing `General`: a subcategory
    /// whose name belongs to exactly one category is shown alone (*Covert Action*), and one shared
    /// by several is qualified (*Warfare · General*). If a future drop reuses a second name, it is
    /// disambiguated automatically instead of shipping two identical rows.
    init(pairs: [(category: String, subcategory: String)]) {
        var categoriesPerName: [String: Set<String>] = [:]
        for pair in pairs { categoriesPerName[pair.subcategory, default: []].insert(pair.category) }

        let distinct = Set(pairs.map { Self.key($0.category, $0.subcategory) })
        let ordered = distinct.sorted()
        buckets = ordered.map { key in
            let parts = key.split(separator: "\u{1F}", maxSplits: 1, omittingEmptySubsequences: false)
            let category = String(parts.first ?? "")
            let subcategory = parts.count > 1 ? String(parts[1]) : ""
            let shared = (categoriesPerName[subcategory]?.count ?? 0) > 1
            return Bucket(category: category, subcategory: subcategory,
                          label: shared ? "\(category) · \(subcategory)" : subcategory)
        }
        idByPair = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
        digest = Self.digest(of: ordered)
    }

    /// The bucket id for a pair, or `nil` when the pair is not in the vocabulary.
    func id(category: String, subcategory: String) -> Int? {
        idByPair[Self.key(category, subcategory)]
    }

    /// The DURABLE identity of a bucket — the `category`/`subcategory` pair itself, not its
    /// position. `nil` when the id is out of range.
    ///
    /// Anything that OUTLIVES a data drop must persist this and never the integer. The integer is
    /// a position, so a regenerated artifact that adds one subcategory shifts every id after it
    /// and a stored `4` silently becomes a different subject. That is fine inside
    /// `document_subjects`, which is rebuilt whenever the stamp moves, and not fine at all in a
    /// saved search, which is archived to iCloud and read back months later.
    func key(at id: Int) -> String? {
        guard buckets.indices.contains(id) else { return nil }
        return Self.key(buckets[id].category, buckets[id].subcategory)
    }

    /// Resolves a durable key back to the CURRENT bucket id; `nil` when the pair no longer exists.
    func id(forKey key: String) -> Int? { idByPair[key] }

    /// The display label for a stored bucket id, or `nil` when the id is out of range — which is
    /// what a row populated under an older ``digest`` looks like.
    func label(at id: Int) -> String? {
        buckets.indices.contains(id) ? buckets[id].label : nil
    }

    private static func key(_ category: String, _ subcategory: String) -> String {
        "\(category)\u{1F}\(subcategory)"
    }

    /// Order-sensitive, so a reordering that preserved the set would still invalidate stored ids.
    private static func digest(of orderedKeys: [String]) -> String {
        let joined = orderedKeys.joined(separator: "\u{1E}")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.prefix(8).map { String(format: "%02hhx", $0) }.joined()
    }
}
