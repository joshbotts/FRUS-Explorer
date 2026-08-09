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

// MARK: - CollectionUsageIndexTests

/// The shipped `collection-usage-index.json` (#763) and the reader that consumes it.
///
/// The artifact is generated from a corpus this test target does not have, so what can be pinned
/// here is its shape, its internal consistency, and its agreement with the *other* bundled
/// artifacts it will be joined against. That last one is the load-bearing check: a usage index
/// keyed to a stale authority loses whole collections silently, which is exactly what a
/// mid-session regeneration produced before this suite existed.
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
@Suite("Collection usage index — artifact")
struct CollectionUsageIndexTests {

    private func index() throws -> CollectionUsageIndex {
        try #require(CollectionUsageIndexStore.shared, """
            collection-usage-index.json must decode from the app bundle. If it was just \
            regenerated it needs `xcodegen generate` to be enrolled — followed by \
            `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
            """)
    }

    // MARK: - Shape

    @Test("The artifact decodes with the expected schema and internally consistent vocabularies")
    func shape() throws {
        let usage = try index()
        #expect(usage.schemaVersion == 1)
        #expect(usage.volumes.count == usage.volumeNoteCounts.count)
        #expect(usage.volumes == usage.volumes.sorted(), "volumes must be sorted")
        #expect(usage.collectionIds == usage.collectionIds.sorted())
        #expect(usage.classKeys == usage.classKeys.sorted())
        #expect(usage.categories.count == 10, "the ten provenance categories")
        #expect(usage.volumes.count > 500)
        #expect(usage.collectionIds.count > 1_000)
        #expect(usage.classKeys.count > 5_000)
    }

    @Test("Every row's indices are in range, ascending, and paired with a positive count")
    func rowsAreWellFormed() throws {
        let usage = try index()
        var checked = 0
        for (label, rows, vocabulary) in [
            ("collections", usage.collections, usage.collectionIds),
            ("classes", usage.classes, usage.classKeys),
            ("categories", usage.volumeCategories, usage.categories),
        ] {
            #expect(rows.map(\.key) == rows.map(\.key).sorted(), "\(label) rows are unsorted")
            for row in rows {
                #expect(vocabulary.indices.contains(row.key),
                        "\(label) row key \(row.key) is outside its vocabulary")
                #expect(row.volumes.count == row.counts.count, "\(label) row \(row.key) is ragged")
                #expect(row.volumes == row.volumes.sorted(), "\(label) row \(row.key) is unsorted")
                #expect(row.volumes.allSatisfy { usage.volumes.indices.contains($0) },
                        "\(label) row \(row.key) points outside the volume vocabulary")
                #expect(row.counts.allSatisfy { $0 > 0 },
                        "\(label) row \(row.key) stores a zero — absent and zero must not both exist")
                checked += 1
            }
        }
        #expect(checked > 5_000, "guard is vacuous — only \(checked) rows checked")
    }

    // MARK: - Agreement with the artifacts it is joined against

    @Test("Every collection id exists in the shipped authority")
    func collectionIdsJoinToTheAuthority() throws {
        // The failure this catches is not hypothetical: the 2026-07-29 export, joined against the
        // 2026-08-06 authority, carried 28 ids that no longer existed — 2,040 documents including
        // the largest presidential-library collection — because #696 folded "president's " to
        // "presidential ". A usage index built against a stale authority loses them in silence.
        let usage = try index()
        let authority = try #require(CollectionAuthorityStore.shared)
        let known = Set(authority.collections.map(\.id))
        let orphans = usage.collectionIds.filter { !known.contains($0) }
        #expect(orphans.isEmpty, """
            \(orphans.count) usage ids are absent from collection-authority.json — the two \
            artifacts were generated against different clusterings. Regenerate the usage index. \
            First few: \(orphans.prefix(5).joined(separator: ", "))
            """)
        #expect(usage.coverage.authorityCollectionCount == authority.collections.count, """
            The usage index recorded \(usage.coverage.authorityCollectionCount) authority records \
            but the shipped authority has \(authority.collections.count) — the coverage line the \
            UI would print is measured against a file that is no longer here.
            """)
    }

    @Test("Every scanned volume is a manifest volume")
    func volumesJoinToTheManifest() throws {
        let usage = try index()
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let known = Set(entries.map(\.volumeId))
        let strays = usage.volumes.filter { !known.contains($0) }
        #expect(strays.isEmpty, "usage index scanned volumes outside the manifest: \(strays.prefix(5))")
    }

    // MARK: - Coverage is honest

    @Test("Coverage adds up, and reports the gap between what exists and what was reached")
    func coverageIsInternallyConsistent() throws {
        let usage = try index()
        let coverage = usage.coverage
        #expect(coverage.volumesScanned == usage.volumes.count)
        #expect(coverage.volumesWithNotes <= coverage.volumesScanned)
        #expect(coverage.authorityCollectionsReached == usage.collectionIds.count)
        #expect(coverage.authorityCollectionsReached < coverage.authorityCollectionCount, """
            The index claims every authority record carries documents. Measured, 1,828 of 4,423 \
            do — the rest are named in front matter and never resolved from a document note, and \
            that gap is a disclosure the UI owes the reader.
            """)

        // The category table holds one entry per note, so it is the one total that must match.
        let categorised = usage.volumeCategories.reduce(0) { $0 + $1.counts.reduce(0, +) }
        #expect(categorised == coverage.noteCount, """
            Categories total \(categorised) but \(coverage.noteCount) notes were scanned. Every \
            note has exactly one category, so any difference is notes lost in aggregation.
            """)

        let inCollections = usage.collections.reduce(0) { $0 + $1.counts.reduce(0, +) }
        #expect(inCollections == coverage.notesInACollection)
        let inClasses = usage.classes.reduce(0) { $0 + $1.counts.reduce(0, +) }
        #expect(inClasses == coverage.notesWithAClassKey)
        #expect(coverage.noteCount == usage.volumeNoteCounts.reduce(0, +))
    }

    // MARK: - The reader

    @Test("Lookups resolve a real collection to real per-volume counts")
    func lookupsResolve() throws {
        let usage = try index()
        // The corpus's largest lot-keyed collection by documents; picked from the artifact so the
        // test cannot pass by matching a name that has drifted.
        let biggest = try #require(usage.collectionIds
            .max { usage.documentCount(forCollectionId: $0) < usage.documentCount(forCollectionId: $1) })
        let total = usage.documentCount(forCollectionId: biggest)
        #expect(total > 1_000, "\(biggest) is the largest collection and holds only \(total) documents")

        let byVolume = usage.documentsByVolume(forCollectionId: biggest)
        #expect(!byVolume.isEmpty)
        #expect(byVolume.values.reduce(0, +) == total, "per-volume counts must sum to the total")
        for volumeId in byVolume.keys {
            #expect(usage.volumes.contains(volumeId))
        }
    }

    @Test("An unreached collection reads as zero, not as a missing answer")
    func unreachedCollectionsReadAsZero() throws {
        let usage = try index()
        let authority = try #require(CollectionAuthorityStore.shared)
        let reached = Set(usage.collectionIds)
        let unreached = try #require(authority.collections.first { !reached.contains($0.id) })
        #expect(usage.documentCount(forCollectionId: unreached.id) == 0)
        #expect(usage.documentsByVolume(forCollectionId: unreached.id).isEmpty)
        // …and it is a real collection with citing volumes, which is the whole point: volume-grain
        // and document-grain disagree, and the UI must not read the zero as "unused".
        #expect(!unreached.volumeIds.isEmpty,
                "fixture is wrong — pick an unreached collection that volumes still cite")
    }

    @Test("A volume's note total is the denominator its category counts sum to")
    func perVolumeCountsAgree() throws {
        let usage = try index()
        var checked = 0
        for volumeId in usage.volumes.prefix(60) {
            guard let notes = usage.noteCount(forVolumeId: volumeId), notes > 0 else { continue }
            let categories = usage.categoryCounts(forVolumeId: volumeId)
            #expect(categories.values.reduce(0, +) == notes, """
                \(volumeId): categories total \(categories.values.reduce(0, +)) against \(notes) \
                notes. Any share computed from these two would be wrong.
                """)
            checked += 1
        }
        #expect(checked > 20, "guard is vacuous — only \(checked) volumes checked")
        #expect(usage.noteCount(forVolumeId: "not-a-volume") == nil,
                "an unscanned volume must be nil, distinguishable from a scanned volume with none")
    }

    // MARK: - The two filing systems in one vocabulary

    @Test("Class keys carry both filing systems, and the subject-numeric fold is usable")
    func classVocabularyHoldsTwoSystems() throws {
        let usage = try index()
        let subject = usage.classKeys.filter { CollectionKeying.isSubjectNumericClass($0) }
        let decimal = usage.classKeys.filter { !CollectionKeying.isSubjectNumericClass($0) }
        #expect(decimal.count > 5_000, "the decimal era should dominate the class vocabulary")
        #expect(subject.count > 500, """
            Only \(subject.count) subject-numeric class keys. Owner decision D-3 admits the \
            1963–73 lens on the strength of this vocabulary; if it has collapsed, the lens must \
            be withdrawn rather than shipped empty.
            """)

        // D-3's grain: folded to category+number, the leaves become a list a reader can work with.
        let groups = Set(subject.compactMap { CollectionKeying.subjectNumericGroup($0) })
        #expect(groups.count < subject.count / 2, """
            Folding barely reduced the vocabulary (\(subject.count) leaves to \(groups.count) \
            groups), so the fold is not doing its job and the lens would ship at leaf grain.
            """)
        #expect(groups.contains("POL 27"), "POL 27 is the largest subject-numeric group")
        #expect(CollectionKeying.subjectNumericGroup("763.72") == nil,
                "a decimal class has no subject-numeric group")
    }
}
