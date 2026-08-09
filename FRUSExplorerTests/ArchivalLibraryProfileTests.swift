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
import Testing
@testable import FRUSExplorer

// MARK: - StoredProvenanceCategoryTests

/// `SourceProvenanceCategory.from(citationEra:repository:)` — the inverse of what
/// `IndexingPipeline.baseDocumentSourceRow` writes (#765 rider E).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — stored rows map back to provenance categories")
struct StoredProvenanceCategoryTests {

    @Test("Every citation form the indexer writes maps back to the category it came from")
    func everyWrittenFormRoundTrips() {
        // Mirrors `baseDocumentSourceRow`'s ten cases in order. If a case is added there and
        // not here, the new form falls to `unrecognized` and the composition card quietly
        // reports it as unclassified.
        let expected: [(era: String, repository: String?, category: SourceProvenanceCategory)] = [
            ("decimal", "Department of State", .centralDecimalFile),
            ("lot_file", "Department of State", .lotFile),
            ("structured", "National Archives", .naraCollection),
            ("structured", "Johnson Library", .presidentialLibrary),
            ("structured", "Central Intelligence Agency", .intelligence),
            ("foreign", nil, .foreignArchive),
            ("published", nil, .previouslyPublished),
            ("cfpf", "Department of State", .centralForeignPolicyFile),
            ("named_series", nil, .namedFileSeries),
            ("unrecognized", nil, .unrecognized),
        ]
        for row in expected {
            #expect(SourceProvenanceCategory.from(citationEra: row.era,
                                                  repository: row.repository) == row.category,
                    "(\(row.era), \(row.repository ?? "nil")) did not map to \(row.category)")
        }
    }

    @Test("`structured` alone is ambiguous — the repository is what splits it three ways")
    func structuredNeedsTheRepository() {
        // The single most load-bearing detail of the mapping: three provenance categories share
        // one citation_era. Grouping the library card by citation_era alone would collapse every
        // presidential library, every NARA record group, and the CIA into one segment.
        let splits = Set([
            SourceProvenanceCategory.from(citationEra: "structured", repository: "National Archives"),
            SourceProvenanceCategory.from(citationEra: "structured", repository: "Ford Library"),
            SourceProvenanceCategory.from(citationEra: "structured",
                                          repository: "Central Intelligence Agency"),
        ])
        #expect(splits.count == 3)
        // An unattributed structured row is a library citation by elimination — that is what the
        // writer's `.presidentialLibrary` case does with a repository it did not canonicalise.
        #expect(SourceProvenanceCategory.from(citationEra: "structured",
                                              repository: nil) == .presidentialLibrary)
    }

    @Test("An unknown form is classified, not dropped")
    func unknownFormsAreClassified() {
        #expect(SourceProvenanceCategory.from(citationEra: "footnote",
                                              repository: nil) == .unrecognized, """
            Every row in document_sources is a real source note. Returning nil for an \
            unrecognised form would let the totals the card presents as complete silently \
            shrink — and `footnote` is precisely the value an index built before #783 still \
            holds until it is re-opened.
            """)
    }
}

// MARK: - ArchivalLibraryProfileTests

/// The Your Library fold (#765 rider E).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — your library profile")
struct ArchivalLibraryProfileTests {

    private func group(_ volumeId: String, _ era: String, _ repository: String?,
                       _ count: Int) -> IndexingPipeline.ArchivalLibraryGroup {
        IndexingPipeline.ArchivalLibraryGroup(volumeId: volumeId, citationEra: era,
                                              repository: repository, documentCount: count)
    }

    private func coverage(_ pairs: [(String, Int)]) -> [String: ArchivalVolumeCoverage] {
        var result: [String: ArchivalVolumeCoverage] = [:]
        for (id, year) in pairs {
            result[id] = ArchivalVolumeCoverage(firstYear: year, lastYear: year)
        }
        return result
    }

    @Test("An empty index yields the empty profile, not a zero-filled chart")
    func emptyIndex() {
        let profile = ArchivalLibraryProfile.make(groups: [], collectionGroups: [],
                                                  coverage: [:], authority: nil)
        #expect(profile.isEmpty)
        #expect(profile.composition.isEmpty)
        #expect(profile.bands.isEmpty)
    }

    @Test("Totals count notes and note-carrying volumes, and bands split them by coverage")
    func totalsAndBands() {
        let groups = [
            group("v1", "decimal", "Department of State", 100),
            group("v1", "lot_file", "Department of State", 20),
            group("v2", "structured", "Nixon", 300),
        ]
        let profile = ArchivalLibraryProfile.make(
            groups: groups, collectionGroups: [],
            coverage: coverage([("v1", 1950), ("v2", 1972)]), authority: nil)
        #expect(profile.noteCount == 420)
        #expect(profile.volumeCount == 2)
        #expect(profile.composition.map(\.documentCount) == [300, 100, 20],
                "composition is heaviest-first")
        #expect(profile.bands.count == 2)
        #expect(profile.bands.map(\.band.index) == [1, 3], "bands stay in era order")
        #expect(profile.bands[0].documentCount == 120)
        #expect(profile.bands[0].volumeCount == 1)
        #expect(profile.centralFileNoteCount == 100)
    }

    @Test("A volume whose coverage is unknown still counts in the totals, just not in a band")
    func unknownCoverageStillCounts() {
        let profile = ArchivalLibraryProfile.make(
            groups: [group("mystery", "lot_file", "Department of State", 7)],
            collectionGroups: [], coverage: [:], authority: nil)
        #expect(profile.noteCount == 7, """
            A volume missing from the manifest must not vanish from the library total — the \
            intro line calls that total the reader's whole index.
            """)
        #expect(profile.bands.isEmpty)
    }

    @Test("Band segments keep a fixed category order, so the card can be read across")
    func bandSegmentsAreOrdered() {
        let profile = ArchivalLibraryProfile.make(
            groups: [
                group("v1", "structured", "Ford Library", 500),
                group("v1", "decimal", "Department of State", 3),
            ],
            collectionGroups: [], coverage: coverage([("v1", 1972)]), authority: nil)
        let categories = profile.bands.first?.categories.map(\.category) ?? []
        let described = categories.map(String.init(describing:)).joined(separator: ", ")
        #expect(categories == [.centralDecimalFile, .presidentialLibrary], """
            The segments came back as [\(described)]. Sorting each band's stack by size would \
            reorder the colours band to band, and this card is read as one shape across the bands.
            """)
    }

    // MARK: - Collection resolution

    private func authorityIndex(_ records: [AuthorityCollectionRecord]) throws
        -> CollectionAuthorityIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "generated": "2026-08-09",
            "collections": records.map { record -> [String: Any] in
                var row: [String: Any] = ["id": record.id, "name": record.name]
                if let repository = record.repository { row["repository"] = repository }
                if let lot = record.lotFileNorm { row["lotFileNorm"] = lot }
                if !record.volumeIds.isEmpty { row["volumeIds"] = record.volumeIds }
                return row
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
    }

    @Test("Collections resolve by lot key and by repository plus leading segment, and sum")
    func collectionsResolveAndSum() throws {
        let lot = AuthorityCollectionRecord(id: "lot:63D351", name: "S/S–NSC Files",
                                            repository: "Department of State",
                                            lotFileNorm: "63D351")
        let library = AuthorityCollectionRecord(id: "txt:johnson library|national security file",
                                                name: "National Security File",
                                                repository: "Johnson Library")
        let index = try authorityIndex([lot, library])
        let groups = [
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: "Department of State",
                seriesName: "S/S–NSC Files", documentCount: 40),
            // A second stored group for the same collection — a different box, same records.
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: "Department of State",
                seriesName: "S/S–NSC Files, Box 12", documentCount: 5),
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: nil, repository: "Johnson Library",
                seriesName: "National Security File, Country File, Vietnam",
                documentCount: 60),
        ]
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "lot_file", "Department of State", 45)],
            collectionGroups: groups, coverage: coverage([("v1", 1965)]), authority: index)
        #expect(profile.collections.map(\.id) == ["txt:johnson library|national security file",
                                                  "lot:63D351"])
        #expect(profile.collections.map(\.documentCount) == [60, 45], """
            The two lot groups must sum onto one record — a citation naming a different box is \
            the same body of records.
            """)
        #expect(profile.unresolvedCollectionNoteCount == 0)
    }

    @Test("A library citation never resolves onto a State lot cluster")
    func libraryCitationsDoNotBridgeToLots() throws {
        // #351: a Carter Library "Presidential Files" note resolved to `lot:66D204` through the
        // shared alias grammar, offering the reader a confidently wrong archive.
        let lot = AuthorityCollectionRecord(id: "lot:66D204", name: "Presidential Files",
                                            repository: "Department of State",
                                            lotFileNorm: "66D204")
        let index = try authorityIndex([lot])
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "structured", "Carter Library", 9)],
            collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: nil, repository: "Carter Library",
                seriesName: "Presidential Files", documentCount: 9)],
            coverage: coverage([("v1", 1978)]), authority: index)
        #expect(profile.collections.isEmpty, """
            Resolved to \(profile.collections.map(\.id)). A presidential-library citation must \
            never land on a State Department lot cluster.
            """)
        #expect(profile.unresolvedCollectionNoteCount == 9,
                "the notes are still counted — they are simply not attributed")
    }

    @Test("An unavailable authority reports every collection note as unresolved")
    func missingAuthorityIsDisclosed() {
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "lot_file", "Department of State", 3)],
            collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: nil, seriesName: nil, documentCount: 3)],
            coverage: coverage([("v1", 1960)]), authority: nil)
        #expect(profile.collections.isEmpty)
        #expect(profile.unresolvedCollectionNoteCount == 3, """
            With no authority the list is empty for a reason the footer states, rather than \
            implying the reader's library cites nothing recognisable.
            """)
    }
}
