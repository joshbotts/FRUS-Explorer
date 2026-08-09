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
@testable import ResolvedEdgeIndexGeneratorCore

// MARK: - ResolvedEdgeIndexRunnerTests

/// The #262 generator: the same-volume exclusion, the interning, and the empty-result refusal.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
@Suite("Resolved edge index — generator")
struct ResolvedEdgeIndexRunnerTests {

    // MARK: - Fixtures

    /// Writes a volume whose documents carry the given inner XML.
    private func write(_ volumeId: String, documents: [(id: String, body: String)],
                       to directory: URL) throws -> URL {
        let divs = documents.map { document in
            "<div type=\"document\" xml:id=\"\(document.id)\">\(document.body)</div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="compilation" xml:id="comp1">
        \(divs)
        </div></body></text></TEI>
        """
        let url = directory.appendingPathComponent("\(volumeId).xml")
        try Data(xml.utf8).write(to: url)
        return url
    }

    private func withCorpus<T>(_ body: (URL) throws -> T) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resolved-edges-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }

    // MARK: - The same-volume exclusion

    @Test("A same-volume citation is excluded; a cross-volume one is stored")
    func sameVolumeEdgesAreExcluded() throws {
        try withCorpus { directory in
            // d1 cites d2 in its own volume, and d1 of the other volume.
            let a = try write("frus1969-76v01", documents: [
                (id: "d1", body: """
                    <p>See <ref target="d2">Document 2</ref> and \
                    <ref target="frus1969-76v02#d1">Document 1</ref>.</p>
                    """),
                (id: "d2", body: "<p>Text.</p>"),
            ], to: directory)
            let b = try write("frus1969-76v02", documents: [(id: "d1", body: "<p>Text.</p>")],
                              to: directory)

            let index = try ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")

            #expect(index.coverage.documentEdges == 2, "both references resolve to real documents")
            #expect(index.coverage.sameVolumeEdges == 1)
            #expect(index.coverage.storedEdges == 1, """
                Stored \(index.coverage.storedEdges) edges. The same-volume citation must not be \
                here: a reader looking at frus1969-76v01/d2 already has the volume, so the local \
                cross_references table holds that edge and shipping it again is pure duplication.
                """)
            #expect(index.targets.count == 1)
            let target = try #require(index.targets.first)
            #expect(index.volumes[target.volume] == "frus1969-76v02")
            #expect(index.documents[target.volume][target.document] == "d1")
            #expect(target.edgeCount == 1)
        }
    }

    @Test("Only the volumes and documents at an endpoint are interned")
    func vocabularyIsTheArtifactsOwn() throws {
        try withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"volB#d1\">x</ref></p>"),
                (id: "unused", body: "<p>Nothing points here and it points nowhere.</p>"),
            ], to: directory)
            let b = try write("volB", documents: [
                (id: "d1", body: "<p>Text.</p>"),
                (id: "alsoUnused", body: "<p>Text.</p>"),
            ], to: directory)
            let index = try ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")

            #expect(index.volumes == ["volA", "volB"])
            #expect(index.documents == [["d1"], ["d1"]], """
                The vocabulary is \(index.documents). Interning every document in every volume \
                would make this a copy of the corpus rather than an index of its citations — the \
                corpus has 316,839 documents and 5,740 of them are cited across a volume boundary.
                """)
        }
    }

    @Test("A reference to something that is not a document div is not an edge")
    func phantomTargetsAreRejected() throws {
        try withCorpus { directory in
            // `in42` is an index-entry anchor: the grammar resolves it as a document, and #764
            // measured 49,799 of them corpus-wide. Minting nodes for those would invent
            // citations into documents that do not exist.
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"volB#in42\">x</ref></p>"),
            ], to: directory)
            let b = try write("volB", documents: [(id: "d1", body: "<p>Text.</p>")], to: directory)
            #expect(throws: ResolvedEdgeError.self) {
                _ = try ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")
            }
        }
    }

    @Test("Two references from the same document to the same target are one citation")
    func repeatedReferencesCollapse() throws {
        try withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: """
                    <p><ref target="volB#d1">x</ref> and again <ref target="volB#d1">x</ref>.</p>
                    """),
            ], to: directory)
            let b = try write("volB", documents: [(id: "d1", body: "<p>Text.</p>")], to: directory)
            let index = try ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")
            #expect(index.coverage.documentEdges == 2, "both references are counted in the funnel")
            #expect(index.targets.first?.edgeCount == 1, """
                Stored \(index.targets.first?.edgeCount ?? -1) edges. A reader counting "documents \
                that cite this" means documents, not mentions.
                """)
        }
    }

    // MARK: - Refusal and determinism

    @Test("A corpus with no cross-volume citation refuses to write")
    func emptyResultThrows() throws {
        try withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"d2\">x</ref></p>"),
                (id: "d2", body: "<p>Text.</p>"),
            ], to: directory)
            #expect(throws: ResolvedEdgeError.self) {
                _ = try ResolvedEdgeIndexRunner.build(files: [a], generated: "2026-08-09")
            }
        }
    }

    @Test("The build is deterministic and its rows are sorted")
    func deterministicAndSorted() throws {
        try withCorpus { directory in
            var files: [URL] = []
            for volume in ["volC", "volA", "volB"] {
                files.append(try write(volume, documents: [
                    (id: "d2", body: "<p><ref target=\"volA#d1\">x</ref></p>"),
                    (id: "d1", body: "<p><ref target=\"volB#d1\">y</ref></p>"),
                ], to: directory))
            }
            let first = try ResolvedEdgeIndexRunner.build(files: files, generated: "2026-08-09")
            let second = try ResolvedEdgeIndexRunner.build(files: files.reversed(),
                                                           generated: "2026-08-09")
            #expect(first == second, """
                Two runs over the same corpus in a different file order produced different \
                artifacts. A generator whose output depends on directory enumeration order makes \
                every diff unreadable.
                """)
            #expect(first.volumes == first.volumes.sorted())
            for row in first.documents { #expect(row == row.sorted()) }
            let keys = first.targets.map { [$0.volume, $0.document] }
            #expect(keys == keys.sorted { $0.lexicographicallyPrecedes($1) })
        }
    }

    @Test("A row whose source array is not endpoint-aligned refuses to decode")
    func raggedRowsAreRefused() throws {
        let payload = """
            {"v":0,"d":0,"s":[0,1,2],"f":0}
            """
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ResolvedEdgeIndex.TargetEdges.self,
                                         from: Data(payload.utf8))
        }
    }
}
