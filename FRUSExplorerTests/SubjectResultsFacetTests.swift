// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SubjectResultsFacetTests

/// Pins the #308 subject results facet: the bucket vocabulary, the `document_subjects` backfill,
/// the aggregate, and the narrowing.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 subject results facet
@Suite("Subject results facet (#308)")
struct SubjectResultsFacetTests {

    // MARK: - Fixtures

    /// Four subjects over three `(category, subcategory)` buckets, with `General` deliberately
    /// under two categories and two distinct subjects sharing one bucket.
    private static let indexJSON = """
    {
      "vocab": [
        {"r": "s1", "n": "War",    "c": "Warfare",                 "s": "General", "df": 3},
        {"r": "s2", "n": "Peace",  "c": "Global Issues",           "s": "General", "df": 1},
        {"r": "s3", "n": "Trade",  "c": "Foreign Economic Policy", "s": "Trade",   "df": 1},
        {"r": "s4", "n": "Battle", "c": "Warfare",                 "s": "General", "df": 1}
      ],
      "documents": {
        "vol1": {"d0": [0, 1], "d1": [0], "d2": [2], "d3": [0, 3]}
      },
      "documentCount": 4,
      "coOccurrence": {"a": [0], "b": [1], "n": [1]}
    }
    """

    private func index() throws -> DocumentSubjectIndex {
        try JSONDecoder().decode(DocumentSubjectIndex.self, from: Data(Self.indexJSON.utf8))
    }

    /// Bucket ids under the fixture's sort (category, then subcategory).
    private enum Bucket {
        static let trade = 0            // Foreign Economic Policy / Trade
        static let globalGeneral = 1    // Global Issues / General
        static let warfareGeneral = 2   // Warfare / General
    }

    // MARK: - The vocabulary

    @Test("Buckets key on the pair, so a reused subcategory name is not fused")
    func bucketsKeyOnThePair() throws {
        let vocabulary = try index().bucketVocabulary
        #expect(vocabulary.buckets.count == 3, """
            `General` appears under two categories. Keyed on the bare subcategory this collapses \
            to two buckets — which on the real artifact fuses 13 categories into one \
            181,517-document row covering 76.2% of the tagged corpus.
            """)
        #expect(vocabulary.id(category: "Warfare", subcategory: "General") == Bucket.warfareGeneral)
        #expect(vocabulary.id(category: "Global Issues", subcategory: "General") == Bucket.globalGeneral)
        #expect(vocabulary.id(category: "Nowhere", subcategory: "General") == nil)
    }

    @Test("A shared subcategory name is qualified; a unique one is not")
    func labelsDisambiguateOnlyWhenNeeded() throws {
        let vocabulary = try index().bucketVocabulary
        #expect(vocabulary.label(at: Bucket.warfareGeneral) == "Warfare · General")
        #expect(vocabulary.label(at: Bucket.globalGeneral) == "Global Issues · General")
        #expect(vocabulary.label(at: Bucket.trade) == "Trade", """
            A subcategory belonging to exactly one category is shown alone. Qualifying every row \
            would put the category in front of all 106 labels to fix the 13 that need it.
            """)
        #expect(vocabulary.label(at: 99) == nil, "an out-of-range id must not be invented")
    }

    @Test("The digest is order-independent for the same set and changes when the set does")
    func digestPinsTheVocabulary() {
        let a = SubjectBucketVocabulary(pairs: [(category: "B", subcategory: "y"),
                                                (category: "A", subcategory: "x")])
        let b = SubjectBucketVocabulary(pairs: [(category: "A", subcategory: "x"),
                                                (category: "B", subcategory: "y")])
        #expect(a.digest == b.digest, """
            The vocabulary sorts its input, so the same set must fingerprint the same however it \
            arrives — otherwise every rebuild would look like a data change and force a full \
            repopulate of 744,054 rows.
            """)
        let c = SubjectBucketVocabulary(pairs: [(category: "A", subcategory: "b"),
                                                (category: "A", subcategory: "x"),
                                                (category: "B", subcategory: "y")])
        #expect(a.digest != c.digest, """
            Adding a bucket that sorts FIRST shifts every stored id by one. If the digest did not \
            move, the backfill would keep rows meaning something else and the facet would mislabel \
            silently.
            """)
    }

    // MARK: - Rows

    @Test("A document's buckets are de-duplicated, so the facet counts documents not tags")
    func bucketRowsDeduplicate() throws {
        let rows = Dictionary(uniqueKeysWithValues:
            try index().bucketRows(forVolume: "vol1").map { ($0.documentId, $0.buckets) })
        #expect(rows["d0"] == [Bucket.globalGeneral, Bucket.warfareGeneral])
        #expect(rows["d1"] == [Bucket.warfareGeneral])
        #expect(rows["d2"] == [Bucket.trade])
        #expect(rows["d3"] == [Bucket.warfareGeneral], """
            d3 carries two DIFFERENT subjects (War, Battle) that share one bucket. Two rows here \
            would make the bucket's count a tag count while every other facet section counts \
            documents, so the two would not be comparable.
            """)
        #expect(try index().bucketRows(forVolume: "absent").isEmpty)
    }

    // MARK: - The shipped artifact

    @Test("The shipped vocabulary is bounded, fully labelled, and unambiguous")
    func shippedVocabularyIsSane() throws {
        guard let store = DocumentSubjectStore.shared else {
            Issue.record("document-subject-index.json did not load from the test host bundle")
            return
        }
        let vocabulary = store.bucketVocabulary
        #expect(vocabulary.buckets.count == 106, """
            The section declares `hasBoundedDomain`, which means it opens showing every row. \
            \(vocabulary.buckets.count) buckets.
            """)
        let labels = vocabulary.buckets.map(\.label)
        #expect(Set(labels).count == labels.count, """
            Two buckets share a display label, so the panel would show two identical rows that \
            narrow to different documents.
            """)
        #expect(labels.allSatisfy { !$0.isEmpty })
        let general = vocabulary.buckets.filter { $0.subcategory == "General" }
        #expect(general.count == 13)
        #expect(general.allSatisfy { $0.label.contains(" · ") },
                "every `General` bucket must carry its category, or 13 rows read identically")
    }
}

// MARK: - SubjectResultsFacetSQLTests

/// The half that runs against a real index: the `document_subjects` backfill, the aggregate over
/// `temp.facet_mset`, and the narrowing predicate.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 subject results facet
@Suite("Subject results facet — SQL (#308)")
struct SubjectResultsFacetSQLTests {

    private typealias Rows = [String: [(documentId: String, buckets: [Int])]]

    /// Eight documents in `vol1` matching `containment`, four in `vol2` that do not.
    private func makeVolumeXML(volume: String, ids: Range<Int>) -> String {
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in ids {
            xml += """
            <div type="document" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
              <p>The doctrine of \(index < 8 ? "containment" : "rollback") shaped policy.</p>
            </div>

            """
        }
        return xml + "</body></text></TEI>"
    }

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSubjFacet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML(volume: "vol1", ids: 0..<8).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol1.xml"))
        try makeVolumeXML(volume: "vol2", ids: 8..<12).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol2.xml"))
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        try await pipeline.indexVolume("vol2")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func facets(_ pipeline: IndexingPipeline, _ service: SearchService,
                        query: String = "containment",
                        configure: (inout SearchParameters) -> Void = { _ in })
        async throws -> ResultSetFacets {
        var params = SearchParameters(keywords: query)
        configure(&params)
        let expressions = try await service.matchExpressions(for: params)
        return try await pipeline.resultSetFacets(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params), request: .all)
    }

    /// `vol1`: d0 and d1 in bucket 2, d2 in bucket 0. `vol3` is not indexed.
    private var rows: Rows {
        ["vol1": [(documentId: "d0", buckets: [2]), (documentId: "d1", buckets: [2]),
                  (documentId: "d2", buckets: [0])],
         "vol3": [(documentId: "d0", buckets: [5])]]
    }

    // MARK: - The backfill

    @Test("Only indexed volumes are populated, and every indexed one is marked")
    func populatesIndexedVolumesOnly() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        let populated = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])
        #expect(populated == 2, """
            Both indexed volumes must be visited — vol2 carries no subject rows and still has to be \
            marked done, or it is rescanned on every launch forever.
            """)
        let breakdown = try await facets(pipeline, service)
        #expect(breakdown.subjects.map(\.key).sorted() == ["0", "2"], """
            vol3 is in the artifact but not in the index, so bucket 5 must not appear: it would put \
            documents in the breakdown that no search can return.
            """)
    }

    @Test("A second run does nothing")
    func backfillIsIdempotent() async throws {
        let (dir, _, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])
        let second = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])
        #expect(second == 0)
    }

    @Test("A changed digest rebuilds rather than merges")
    func digestChangeRebuilds() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "old", volumeIds: ["vol1", "vol2"])
        _ = try await pipeline.applyDocumentSubjects(
            rows: { $0 == "vol1" ? [(documentId: "d0", buckets: [7])] : [] },
            digest: "new", volumeIds: ["vol1", "vol2"])
        let breakdown = try await facets(pipeline, service)
        #expect(breakdown.subjects.map(\.key) == ["7"], """
            Bucket ids are positions in the vocabulary, so a digest change invalidates every stored \
            row. Merging would leave rows from the old vocabulary meaning a different subject.
            """)
    }

    // MARK: - Lifecycle (the review's findings)

    /// Indexing a volume must populate its subject rows THEN, not at the next launch. Asserted
    /// through the marker: if indexing recorded the volume as done, a later populate has no work.
    @Test("Indexing a volume populates its subject rows immediately")
    func indexingPopulatesWithoutWaitingForLaunch() async throws {
        let (dir, _, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        let outstanding = try await pipeline.applyDocumentSubjects(
            rows: { _ in [] }, digest: currentStamp(), volumeIds: ["vol1", "vol2"])
        #expect(outstanding == 0, """
            Both volumes were indexed by the fixture, so both must already be marked. \
            \(outstanding) were still outstanding, which means the table is only ever written at \
            launch — and a volume downloaded mid-session is missing from the breakdown until the \
            app is relaunched.
            """)
    }

    /// Removing a volume must take its done-marker with its rows. Keeping the marker is the worse
    /// half: the volume is then permanently absent from the facet, even if it is re-added.
    @Test("Removing a volume clears its rows AND its done-marker")
    func removalClearsTheMarkerToo() async throws {
        let (dir, _, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        try await pipeline.removeVolume("vol1")
        let outstanding = try await pipeline.applyDocumentSubjects(
            rows: { _ in [] }, digest: currentStamp(), volumeIds: ["vol1"])
        #expect(outstanding == 1, """
            vol1 was removed, so it must read as outstanding again. Left marked, a re-added volume \
            is never repopulated and its documents never appear in the Subjects breakdown.
            """)
    }

    /// The stamp has to cover the DATA, not only the vocabulary's order: a re-dropped artifact can
    /// keep all 106 buckets in place while every document's tags change.
    @Test("A new artifact generation rebuilds even when the vocabulary is unchanged")
    func dataOnlyRedropRebuilds() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { $0 == "vol1" ? [(documentId: "d0", buckets: [1])] : [] },
            digest: "vocab-abc@2026-08-21", volumeIds: ["vol1", "vol2"])
        _ = try await pipeline.applyDocumentSubjects(
            rows: { $0 == "vol1" ? [(documentId: "d0", buckets: [4])] : [] },
            digest: "vocab-abc@2026-09-01", volumeIds: ["vol1", "vol2"])
        let breakdown = try await facets(pipeline, service)
        #expect(breakdown.subjects.map(\.key) == ["4"], """
            Same vocabulary fingerprint, later generation date. Keyed on the vocabulary alone the \
            table would still describe the previous drop, forever.
            """)
    }

    /// A pair the vocabulary no longer has must match NOTHING. Falling back to "no filter" would
    /// widen a saved search to the whole corpus under a name promising the opposite.
    @Test("A key whose pair is gone narrows to nothing, never to everything")
    func retiredKeyMatchesNothing() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])
        var params = SearchParameters(keywords: "containment")
        params.subjectBucketKey = "Nonexistent\u{1F}Retired"
        let expressions = try await service.matchExpressions(for: params)
        let breakdown = try await pipeline.resultSetFacets(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params), request: .all)
        #expect(breakdown.matchCount == 0, """
            A retired subject must yield nothing. Degrading to "no subject filter" would return all \
            8 matches under a saved search the reader named for one subject.
            """)
    }

    /// A helper matching what `applyDocumentSubjectsIfNeeded` stamps, so these tests exercise the
    /// same marker the shipping path writes rather than an arbitrary one.
    private func currentStamp() -> String {
        guard let index = DocumentSubjectStore.shared else { return "none" }
        return "\(index.bucketVocabulary.digest)@\(index.generated)"
    }

    // MARK: - The aggregate

    @Test("Buckets count documents, and coverage states how much of the match is tagged")
    func aggregateCountsDocuments() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])
        let breakdown = try await facets(pipeline, service)
        #expect(breakdown.matchCount == 8)
        let byKey = Dictionary(uniqueKeysWithValues: breakdown.subjects.map { ($0.key, $0.count) })
        #expect(byKey["2"] == 2)
        #expect(byKey["0"] == 1)
        #expect(breakdown.subjectCoverage == 3, """
            Three of the eight matches carry a subject. Without this figure the largest bucket \
            reads as a share of the match when it is a share of the tagged part of it — and on the \
            real corpus a quarter of documents carry no subject at all.
            """)
    }

    // MARK: - Narrowing

    @Test("A subjects row narrows the search through the bucket predicate")
    func narrowingRestrictsTheMatch() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])

        let bucket = FacetBucket(key: "2", label: "Warfare · General", count: 2)
        let narrowing = FacetNarrowing.forBucket(bucket, in: .subjects)
        #expect(narrowing == .subject(2))

        var params = SearchParameters(keywords: "containment")
        narrowing?.apply(to: &params)
        #expect(params.subjectBucket == 2)

        let narrowed = try await facets(pipeline, service) { $0.subjectBucket = 2 }
        #expect(narrowed.matchCount == 2, """
            The row promised 2 documents, so the narrowed search must deliver exactly 2. A facet \
            whose count and whose click disagree is worse than no facet.
            """)
    }

    // MARK: - Saved searches

    /// #756 replaced eight scalar columns with a JSON archive of the whole `SearchParameters`
    /// value, on the argument that "a new field is persisted by construction". `subjectBucket` is
    /// field nineteen — the first new one since — so this is that claim's first real test.
    ///
    /// It also means the subject narrowing needs **no CloudKit schema deploy**: `parametersData`
    /// is an identifier that already exists.
    @Test("A saved search carries the subject narrowing without a new stored property")
    func savedParametersRoundTripTheBucket() throws {
        var params = SearchParameters(keywords: "containment")
        params.subjectBucket = 42
        let data = try JSONEncoder().encode(params)
        let restored = try JSONDecoder().decode(SearchParameters.self, from: data)
        #expect(restored.subjectBucket == 42, """
            The archive dropped the field. `SearchParameters` must keep its SYNTHESISED Codable \
            conformance — adding CodingKeys would silently reintroduce the drop class #756 removed, \
            and a saved search would run broader than the one the user named.
            """)
    }

    @Test("A record archived before this build recalls with no subject filter")
    func olderArchiveDecodesToNoFilter() throws {
        var params = SearchParameters(keywords: "containment")
        params.subjectBucket = 7
        var object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(params))
            as! [String: Any]
        object.removeValue(forKey: "subjectBucket")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(SearchParameters.self, from: legacy)
        #expect(restored.subjectBucket == nil, """
            Every SavedSearch written before this build lacks the key. Decoding must yield "no \
            subject filter" rather than throwing — a throw here would make older saved searches \
            unrecallable.
            """)
    }

    @Test("The scope signature distinguishes two subject buckets")
    func scopeSignatureSeesTheBucket() {
        var a = SearchParameters(keywords: "containment")
        a.subjectBucket = 2
        var b = SearchParameters(keywords: "containment")
        b.subjectBucket = 7
        let plain = SearchParameters(keywords: "containment")
        #expect(SearchScopeSignature.signature(for: a) != SearchScopeSignature.signature(for: b))
        #expect(SearchScopeSignature.signature(for: a) != SearchScopeSignature.signature(for: plain))
    }
}

// MARK: - SubjectNarrowingLifecycleTests

/// The findings an adversarial review of the first implementation raised — every one of them a
/// silent wrong answer rather than a crash, and every one now pinned.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 subject results facet, post-review
@Suite("Subject narrowing lifecycle (#308)")
@MainActor
struct SubjectNarrowingLifecycleTests {

    private func makeViewModel() async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSubjLife-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// The archive round-trip alone does NOT prove this: `SearchParameters` encodes the field by
    /// construction, and iOS still lost it, because `applyParameters` copies field by field into
    /// the view model and had no line for it. Testing the encoder tested the wrong thing.
    @Test("A recalled search restores the subject narrowing")
    func applyParametersRestoresTheBucket() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }
        var saved = SearchParameters(keywords: "containment")
        saved.subjectBucket = 12
        vm.applyParameters(saved)
        #expect(vm.subjectBucket == 12)
        #expect(vm.searchParameters.subjectBucket == 12, "and it must reach the executed search")
    }

    /// The other half, and the one that leaks: these fields outlive a single search.
    @Test("A recalled search WITHOUT a subject clears one already in force")
    func applyParametersClearsAStaleBucket() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }
        vm.subjectBucket = 12
        vm.applyParameters(SearchParameters(keywords: "rollback"))
        #expect(vm.subjectBucket == nil, """
            A conditional assignment would leave the previous search's subject filter in force, so \
            every later hand-off would silently run narrower than it says.
            """)
    }

    @Test("Clear Filters clears it, and the filter glyph reports it")
    func clearFiltersReachesTheBucket() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }
        vm.subjectBucket = 3
        #expect(vm.hasActiveFilters, """
            A filter set by a single facet tap, with nothing else on screen naming it, is exactly \
            the one the glyph has to announce.
            """)
        vm.clearFilters()
        #expect(vm.subjectBucket == nil)
        #expect(!vm.hasActiveFilters)
    }

    // MARK: - Surviving a data drop

    /// The narrowing must carry a DURABLE identity, not a position. `subjectBucket` is an index
    /// into the vocabulary, and `SavedSearch` archives the whole parameters value to disk and
    /// iCloud — so without this a regenerated artifact with one extra subcategory would leave every
    /// saved search pointing at a different subject, silently and for good.
    @Test("A facet tap records the durable pair key, not only the position")
    func narrowingCarriesTheDurableKey() {
        guard let vocabulary = DocumentSubjectStore.shared?.bucketVocabulary else {
            Issue.record("subject vocabulary unavailable in the test host"); return
        }
        var params = SearchParameters(keywords: "containment")
        FacetNarrowing.subject(5).apply(to: &params)
        #expect(params.subjectBucket == 5)
        #expect(params.subjectBucketKey == vocabulary.key(at: 5), """
            Only the position was stored. That is the identity error the subject artifact's own \
            doc comment warns about — a wrong key here does not fail, it shows a different subject \
            at entirely plausible counts.
            """)
    }

    /// The key does not merely DETECT drift, it repairs it: the same pair resolves to whatever
    /// position it occupies now.
    @Test("The durable key re-resolves to the pair's current position")
    func durableKeyResolvesAcrossRenumbering() {
        let before = SubjectBucketVocabulary(pairs: [(category: "B", subcategory: "y"),
                                                     (category: "C", subcategory: "z")])
        let after = SubjectBucketVocabulary(pairs: [(category: "A", subcategory: "x"),
                                                    (category: "B", subcategory: "y"),
                                                    (category: "C", subcategory: "z")])
        let key = before.key(at: 0)          // B / y, position 0 before the drop
        #expect(before.label(at: 0) == "y")
        #expect(after.id(forKey: key ?? "") == 1, """
            Adding a subcategory that sorts first shifts every position by one. Resolved by key the \
            filter still means B/y; read as the raw position 0 it would silently become A/x.
            """)
        #expect(after.label(at: after.id(forKey: key ?? "") ?? -1) == "y")
    }

    /// The appendix exists so someone can reproduce the search. A positional index into an
    /// artifact they do not have is not reproducible.
    @Test("The methods appendix names the subject rather than numbering it")
    func appendixNamesTheSubject() {
        var params = SearchParameters(keywords: "containment")
        params.subjectBucket = 0
        let phrases = SearchScopeSignature.describe(
            SearchScopeSignature.signature(for: params)) ?? []
        let described = phrases.joined(separator: "; ")
        #expect(described.lowercased().contains("subject"), """
            The subject narrowing is missing from the exported methods appendix entirely, so the \
            appendix describes a broader scope than the one the numbers came from. Got: \(described)
            """)
        if let label = DocumentSubjectStore.shared?.bucketVocabulary.label(at: 0) {
            #expect(described.contains(label), "expected the bucket's NAME, got: \(described)")
        }
    }
}

// MARK: - SharedSubjectEvidenceTests

/// `sharedSubjectNames(anchor:candidates:)` — the evidence behind the `sharedSubjects` "why
/// related" chip (#1020).
///
/// Version history:
///   1.0 — Session 2026-08-21: #1020
@Suite("Shared-subject evidence (#1020)")
struct SharedSubjectEvidenceTests {

    private func decode(_ json: String) throws -> DocumentSubjectIndex {
        try JSONDecoder().decode(DocumentSubjectIndex.self, from: Data(json.utf8))
    }

    /// `d0` = War + Peace, `d1` = War, `d2` = Trade, `d3` = War + Battle.
    private func fixture() throws -> DocumentSubjectIndex {
        try decode("""
        {
          "vocab": [
            {"r": "s1", "n": "War",    "c": "Warfare",                 "s": "General", "df": 3},
            {"r": "s2", "n": "Peace",  "c": "Global Issues",           "s": "General", "df": 1},
            {"r": "s3", "n": "Trade",  "c": "Foreign Economic Policy", "s": "Trade",   "df": 1},
            {"r": "s4", "n": "Battle", "c": "Warfare",                 "s": "General", "df": 1}
          ],
          "documents": {"vol1": {"d0": [0, 1], "d1": [0], "d2": [2], "d3": [0, 3]}},
          "documentCount": 4,
          "coOccurrence": {"a": [0], "b": [1], "n": [1]}
        }
        """)
    }

    private func key(_ d: String) -> DocumentKey { DocumentKey(volumeId: "vol1", documentId: d) }

    @Test("A candidate sharing nothing is ABSENT, not present with an empty list")
    func nonSharingCandidateIsAbsent() throws {
        let shared = try fixture().sharedSubjectNames(
            anchor: key("d0"), candidates: [key("d1"), key("d2"), key("d3")])
        #expect(shared[key("d1")] == ["War"])
        #expect(shared[key("d3")] == ["War"])
        #expect(shared[key("d2")] == nil, """
            d2 carries only Trade, which the anchor does not have. Returning `[]` for it would make \
            every caller write two checks where one should do, and would render an empty chip.
            """)
    }

    /// The chip shows at most a few names, so the ones that survive the cut have to be the ones
    /// that discriminate. Sharing a corpus-wide subject is not evidence; sharing a rare one is.
    @Test("Shared subjects come back most-distinctive-first")
    func mostDistinctiveFirst() throws {
        let index = try decode("""
        {
          "vocab": [
            {"r": "common", "n": "Everywhere", "c": "C", "s": "S", "df": 90},
            {"r": "rare",   "n": "Seldom",     "c": "C", "s": "S", "df": 2}
          ],
          "documents": {"vol1": {"d0": [0, 1], "d1": [0, 1]}},
          "documentCount": 100,
          "coOccurrence": {"a": [0], "b": [1], "n": [1]}
        }
        """)
        #expect(index.sharedSubjectNames(anchor: key("d0"), candidates: [key("d1")])[key("d1")]
                    == ["Seldom", "Everywhere"], """
            Ordering is inherited from `subjects(forDocument:)`, which is IDF-descending. If that \
            ever stops being true the chip silently starts showing the least informative topics.
            """)
    }

    @Test("The limit caps the list and keeps the most distinctive")
    func limitKeepsTheRarest() throws {
        let index = try decode("""
        {
          "vocab": [
            {"r": "a", "n": "Common",  "c": "C", "s": "S", "df": 90},
            {"r": "b", "n": "Middling","c": "C", "s": "S", "df": 20},
            {"r": "c", "n": "Rare",    "c": "C", "s": "S", "df": 2}
          ],
          "documents": {"vol1": {"d0": [0, 1, 2], "d1": [0, 1, 2]}},
          "documentCount": 100,
          "coOccurrence": {"a": [0], "b": [1], "n": [1]}
        }
        """)
        #expect(index.sharedSubjectNames(anchor: key("d0"), candidates: [key("d1")], limit: 2)[key("d1")]
                    == ["Rare", "Middling"])
        #expect(index.sharedSubjectNames(anchor: key("d0"), candidates: [key("d1")], limit: 0).isEmpty)
    }

    @Test("An anchor with no subjects yields nothing rather than every candidate's own topics")
    func untaggedAnchorSharesNothing() throws {
        let shared = try fixture().sharedSubjectNames(
            anchor: key("absent"), candidates: [key("d0"), key("d1")])
        #expect(shared.isEmpty, """
            A quarter of the corpus carries no subject at all. An untagged anchor must share \
            nothing — not fall through to listing the candidate's own topics as if they were common \
            ground.
            """)
    }
}

// MARK: - FilterOnlySearchTests

/// Pins #1022's enabler: a subject filter is a **standalone** search constraint, admitted by one
/// rule rather than four independent enumerations.
///
/// ## What was wrong
/// A filter-only search — no keyword, phrase, or prefix — had to be admitted separately by
/// `SearchViewModel.search()`, `MacSearchViewModel.performSearch(service:)`,
/// `SearchService.makeMatchExpressions(from:)` and `QueryInspection.isFilterOnly`, and each site
/// enumerated the admissible filters itself. All four listed only person filters, so a subject
/// filter with no keyword threw `FTS5Error.emptyQuery` even though the SQL beneath it has applied
/// the bucket predicate end-to-end since #1018. Four parallel edits across two hand-maintained
/// platform twins is the shape this repo has been bitten by before; `supportsFilterOnlySearch` is
/// the single rule they now share.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1022 enabler B
@Suite("Filter-only search admits subject filters (#1022)")
struct FilterOnlySearchTests {

    // MARK: - The rule

    @Test("Every standalone filter qualifies, and nothing else does")
    func theRuleAdmitsWhatItShould() {
        #expect(SearchParameters().supportsFilterOnlySearch == false,
                "an empty parameter set is not a search")

        var person = SearchParameters()
        person.personRef = "p1"
        #expect(person.supportsFilterOnlySearch)

        var rollup = SearchParameters()
        rollup.personRollupId = 7
        #expect(rollup.supportsFilterOnlySearch)

        var bucket = SearchParameters()
        bucket.subjectBucket = 2
        #expect(bucket.supportsFilterOnlySearch, "the resolved bucket position is a real predicate")

        var key = SearchParameters()
        key.subjectBucketKey = "Warfare\u{1F}General"
        #expect(key.supportsFilterOnlySearch, "the durable key resolves to one in makeFilters")

        // Scope flags are not filters: they choose which columns a MATCH searches, and a
        // filter-only query has no MATCH to scope.
        var scopeOnly = SearchParameters()
        scopeOnly.includeSummaries = true
        scopeOnly.includeNotes = true
        #expect(scopeOnly.supportsFilterOnlySearch == false)
    }

    /// The regression this guards: a filter kind added to one site and not the others. Anything
    /// the service will run filter-only, the inspector must also explain that way.
    @Test("The service and the inspector agree on what runs without a MATCH")
    func serviceAndInspectorAgree() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFilterOnly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fts5 = try FTS5Store(databaseURL: dir.appendingPathComponent("t.sqlite"))
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dir.appendingPathComponent("t.sqlite"),
            volumesDirectory: dir, concurrencyLimit: 1)
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)
        let inspector = QueryInspector(searchService: service)

        for (label, mutate) in [
            ("personRef", { (p: inout SearchParameters) in p.personRef = "p1" }),
            ("personRollupId", { (p: inout SearchParameters) in p.personRollupId = 7 }),
            ("subjectBucket", { (p: inout SearchParameters) in p.subjectBucket = 2 }),
            ("subjectBucketKey", { (p: inout SearchParameters) in p.subjectBucketKey = "A\u{1F}B" }),
        ] {
            var params = SearchParameters()
            mutate(&params)
            let expressions = try await service.matchExpressions(for: params)
            #expect(expressions.corpus == nil,
                    "\(label): a filter-only query must render no MATCH expression")
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(inspection.isFilterOnly, """
                \(label): the service runs this without a MATCH but the Query Inspector does not \
                call it filter-only, so the panel would say the query has no terms and no filters.
                """)
        }
    }
}

// MARK: - SubjectOnlySearchTests

/// The end-to-end half of #1022 enabler B, against a real index: a search carrying **only** a
/// subject filter returns exactly that bucket's documents.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1022 enabler B
@Suite("Subject-only search (#1022)")
struct SubjectOnlySearchTests {

    private func makeVolumeXML(ids: Range<Int>) -> String {
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in ids {
            xml += """
            <div type="document" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
              <p>The doctrine of \(index < 8 ? "containment" : "rollback") shaped policy.</p>
            </div>

            """
        }
        return xml + "</body></text></TEI>"
    }

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSubjOnly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML(ids: 0..<8).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol1.xml"))
        try makeVolumeXML(ids: 8..<12).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol2.xml"))
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        try await pipeline.indexVolume("vol2")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    /// `vol1`: d0 and d1 in bucket 2, d2 in bucket 0. `vol2`: d8 in bucket 2.
    private var rows: [String: [(documentId: String, buckets: [Int])]] {
        ["vol1": [(documentId: "d0", buckets: [2]), (documentId: "d1", buckets: [2]),
                  (documentId: "d2", buckets: [0])],
         "vol2": [(documentId: "d8", buckets: [2])]]
    }

    /// The headline: no keyword at all, and the bucket's documents come back — across volumes,
    /// and without the documents in the other bucket.
    @Test("A bucket with no keyword returns exactly that bucket's documents")
    func bucketOnlySearchReturnsTheBucket() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])

        var params = SearchParameters()
        params.subjectBucket = 2
        let results = try await service.search(parameters: params, limit: 100)
        let keys = results.map { "\($0.volumeId)/\($0.documentId)" }.sorted()
        #expect(keys == ["vol1/d0", "vol1/d1", "vol2/d8"], """
            A subject-only search returned \(keys). Before #1022 this threw emptyQuery; if it now \
            returns all 12 documents the bucket predicate is being dropped rather than applied, \
            which is the failure mode that widens a filter under a name promising the opposite.
            """)
    }

    /// The other half of the same guarantee: a bucket nothing is tagged with returns nothing,
    /// rather than degrading to the whole corpus.
    @Test("An empty bucket with no keyword returns nothing, not everything")
    func emptyBucketReturnsNothing() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await pipeline.applyDocumentSubjects(
            rows: { rows[$0] ?? [] }, digest: "d1", volumeIds: ["vol1", "vol2"])

        var params = SearchParameters()
        params.subjectBucket = 99
        let results = try await service.search(parameters: params, limit: 100)
        #expect(results.isEmpty, "an untagged bucket returned \(results.count) documents")
    }
}
