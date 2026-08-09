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

// MARK: - ResolvedEdgeIndexTests

/// The shipped `resolved-edge-index.json` (#262) and its reader.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
@Suite("Resolved edge index — artifact")
struct ResolvedEdgeIndexTests {

    private func index() throws -> ResolvedEdgeIndex {
        try #require(ResolvedEdgeIndexStore.shared, """
            resolved-edge-index.json must decode from the app bundle. If it was just regenerated \
            it needs `xcodegen generate` to be enrolled — followed by \
            `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
            """)
    }

    @Test("The artifact decodes and every endpoint points inside its vocabulary")
    func shape() throws {
        let edges = try index()
        #expect(edges.schemaVersion == 1)
        #expect(edges.volumes == edges.volumes.sorted())
        #expect(edges.documents.count == edges.volumes.count)
        for row in edges.documents { #expect(row == row.sorted()) }

        var checked = 0
        for target in edges.targets {
            #expect(edges.volumes.indices.contains(target.volume))
            #expect(edges.documents[target.volume].indices.contains(target.document))
            #expect(target.sources.count.isMultiple(of: 2), "a ragged source row")
            for offset in stride(from: 0, to: target.sources.count, by: 2) {
                let volume = target.sources[offset]
                #expect(edges.volumes.indices.contains(volume))
                #expect(edges.documents[volume].indices.contains(target.sources[offset + 1]))
                checked += 1
            }
            #expect(target.footnoteSources <= target.sources.count / 2)
        }
        #expect(checked > 5_000, "guard is vacuous — only \(checked) edges checked")
    }

    @Test("Nothing in the index is a same-volume citation")
    func noSameVolumeEdges() throws {
        // The whole size argument rests on this: 69,164 of the corpus's 77,792 document-to-document
        // citations are same-volume, and every one of them is already in the reader's local table
        // whenever they can see the document at all. One leaking through would be dead weight and,
        // worse, would be merged as a duplicate of an edge the graph already has.
        let edges = try index()
        for target in edges.targets {
            for offset in stride(from: 0, to: target.sources.count, by: 2) {
                #expect(target.sources[offset] != target.volume, """
                    \(edges.volumes[target.volume]) cites itself in the index. Same-volume edges \
                    belong to cross_references, not here.
                    """)
            }
        }
    }

    @Test("The funnel is internally consistent and matches the cross-reference harvest")
    func coverageIsConsistent() throws {
        let coverage = try index().coverage
        #expect(coverage.referencesInsideDocuments <= coverage.referencesScanned)
        #expect(coverage.documentEdges <= coverage.referencesInsideDocuments)
        #expect(coverage.sameVolumeEdges < coverage.documentEdges)
        #expect(coverage.storedEdges == coverage.documentEdges - coverage.sameVolumeEdges)
        // The same harvest #764 reports, so the two artifacts cannot disagree about the corpus.
        #expect(coverage.documentEdges == 77_792, """
            \(coverage.documentEdges) document edges, not the 77,792 the provenance flow index \
            reports from the same harvester. Two artifacts disagreeing about the corpus means one \
            of them is reading it differently.
            """)
        #expect(coverage.sameVolumeEdges == 69_164)
    }

    @Test("Most citations are same-volume, which is why this artifact is small")
    func theSizeArgumentHolds() throws {
        let coverage = try index().coverage
        let share = Double(coverage.sameVolumeEdges) / Double(coverage.documentEdges)
        #expect(share > 0.8, """
            Same-volume citations are \(Int(share * 100))% of the corpus. #262 estimated this \
            artifact from 2.70M resolved references; it is 281 KB because two filters — \
            document-to-document only, then cross-volume only — remove three orders of magnitude. \
            If that share collapsed, the size design would need revisiting rather than inheriting.
            """)
        #expect(coverage.storedEdges > 5_000)
        #expect(coverage.targetCount > 1_000)
    }

    // MARK: - The reader

    @Test("A cited document resolves to its citing documents, none of them local")
    func readerResolves() throws {
        let edges = try index()
        // Pick the most-cited document from the artifact, so the test cannot pass by naming an id
        // that has drifted.
        let busiest = try #require(edges.targets.max { $0.sources.count < $1.sources.count })
        let volumeId = edges.volumes[busiest.volume]
        let documentId = edges.documents[busiest.volume][busiest.document]

        let sources = edges.inboundSources(volumeId: volumeId, documentId: documentId)
        #expect(sources.count == busiest.sources.count / 2)
        #expect(!sources.isEmpty)
        for source in sources {
            #expect(source.volumeId != volumeId, "a same-volume source reached the reader")
            #expect(edges.volumes.contains(source.volumeId))
        }
        #expect(edges.footnoteSourceCount(volumeId: volumeId, documentId: documentId)
                <= sources.count)
    }

    @Test("An unknown document reads as empty rather than resolving to something")
    func unknownDocumentIsEmpty() throws {
        let edges = try index()
        #expect(edges.inboundSources(volumeId: "frusNotAVolume", documentId: "d1").isEmpty)
        #expect(edges.footnoteSourceCount(volumeId: "frusNotAVolume", documentId: "d1") == 0)
    }
}

// MARK: - InboundCompletionTests

/// The merge that closes #262 in the graph itself.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
@Suite("Resolved edge index — inbound completion")
struct InboundCompletionTests {

    private func fixture(volumes: [String], documents: [[String]],
                         targets: [(volume: Int, document: Int, sources: [Int], footnotes: Int)])
        throws -> ResolvedEdgeIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1, "generated": "2026-08-09",
            "volumes": volumes, "documents": documents,
            "targets": targets.map {
                ["v": $0.volume, "d": $0.document, "s": $0.sources, "f": $0.footnotes]
            },
            "coverage": ["volumesScanned": 2, "referencesScanned": 10,
                          "referencesInsideDocuments": 5, "documentEdges": 3,
                          "sameVolumeEdges": 1, "targetCount": targets.count,
                          "citingVolumeCount": 1],
        ]
        return try JSONDecoder().decode(
            ResolvedEdgeIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    private func edge(from source: (String, String), to target: (String, String))
        -> CrossReferenceEdge {
        CrossReferenceEdge(sourceDocumentId: source.1, sourceVolumeId: source.0,
                           targetDocumentId: target.1, targetVolumeId: target.0,
                           context: "local context", referenceType: .footnote)
    }

    @Test("A corpus citation the local table lacks is added")
    func completionAddsMissingEdges() throws {
        let index = try fixture(volumes: ["volA", "volB"], documents: [["d1"], ["d9"]],
                                targets: [(volume: 1, document: 0, sources: [0, 0], footnotes: 1)])
        let merged = CrossReferenceStore.completingInboundEdges(
            local: [], documentId: "d9", volumeId: "volB", index: index)
        #expect(merged.count == 1)
        #expect(merged.first?.sourceVolumeId == "volA")
        #expect(merged.first?.sourceDocumentId == "d1")
        #expect(merged.first?.targetVolumeId == "volB")
    }

    @Test("A local edge always wins, because it carries context the index does not store")
    func localEdgesAreNotDuplicated() throws {
        let index = try fixture(volumes: ["volA", "volB"], documents: [["d1"], ["d9"]],
                                targets: [(volume: 1, document: 0, sources: [0, 0], footnotes: 1)])
        let local = [edge(from: ("volA", "d1"), to: ("volB", "d9"))]
        let merged = CrossReferenceStore.completingInboundEdges(
            local: local, documentId: "d9", volumeId: "volB", index: index)
        #expect(merged.count == 1, """
            The merge produced \(merged.count) edges for one citation. A duplicated edge would \
            draw two arrows between the same pair of documents and double every inbound count.
            """)
        #expect(merged.first?.context == "local context",
                "the local edge, with its context text, is the one that survives")
    }

    @Test("A missing index leaves the local answer exactly as it was")
    func missingIndexIsANoOp() {
        let local = [edge(from: ("volA", "d1"), to: ("volB", "d9"))]
        let merged = CrossReferenceStore.completingInboundEdges(
            local: local, documentId: "d9", volumeId: "volB", index: nil)
        #expect(merged.count == 1)
        #expect(merged.first?.sourceVolumeId == "volA")
    }

    @Test("Completion is scoped to the document asked about")
    func completionDoesNotLeakAcrossDocuments() throws {
        let index = try fixture(volumes: ["volA", "volB"], documents: [["d1"], ["d8", "d9"]],
                                targets: [(volume: 1, document: 1, sources: [0, 0], footnotes: 1)])
        let merged = CrossReferenceStore.completingInboundEdges(
            local: [], documentId: "d8", volumeId: "volB", index: index)
        #expect(merged.isEmpty, """
            Asking about d8 returned \(merged.count) edges, but only d9 is cited. A lookup that \
            ignored the document id would attribute every citation in a volume to every document \
            in it.
            """)
    }
}
