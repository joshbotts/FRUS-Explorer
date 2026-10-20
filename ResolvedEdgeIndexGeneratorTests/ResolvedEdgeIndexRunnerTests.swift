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

import FRUSCoreKit
import Foundation
import Testing
@testable import ResolvedEdgeIndexGeneratorCore

// MARK: - ResolvedEdgeIndexRunnerTests

/// The #262 generator: the same-volume exclusion, the interning, the empty-result refusal, and
/// (#1693) a reference to a note and a section's row as citations.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
///   1.1 — #1693: async, for the kit's parser; a section's row cites, and a note's reference
///          cites its document under the app's widened pattern
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

    private func withCorpus<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resolved-edges-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    /// Writes a volume from its body's XML as written, for a fixture that needs sections.
    private func write(_ volumeId: String, body: String, to directory: URL) throws -> URL {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        \(body)
        </body></text></TEI>
        """
        let url = directory.appendingPathComponent("\(volumeId).xml")
        try Data(xml.utf8).write(to: url)
        return url
    }

    /// The citing endpoints of `volume/document`, as `"volume/document"` strings.
    private func sources(of volume: String, _ document: String,
                         in index: ResolvedEdgeIndex) -> [String] {
        guard let v = index.volumes.firstIndex(of: volume),
              let d = index.documents[v].firstIndex(of: document),
              let row = index.targets.first(where: { $0.volume == v && $0.document == d })
        else { return [] }
        return stride(from: 0, to: row.sources.count, by: 2).map { offset in
            let sv = row.sources[offset]
            return "\(index.volumes[sv])/\(index.documents[sv][row.sources[offset + 1]])"
        }
    }

    // MARK: - The same-volume exclusion

    @Test("A same-volume citation is excluded; a cross-volume one is stored")
    func sameVolumeEdgesAreExcluded() async throws {
        try await withCorpus { directory in
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

            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")

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
    func vocabularyIsTheArtifactsOwn() async throws {
        try await withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"volB#d1\">x</ref></p>"),
                (id: "unused", body: "<p>Nothing points here and it points nowhere.</p>"),
            ], to: directory)
            let b = try write("volB", documents: [
                (id: "d1", body: "<p>Text.</p>"),
                (id: "alsoUnused", body: "<p>Text.</p>"),
            ], to: directory)
            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")

            #expect(index.volumes == ["volA", "volB"])
            #expect(index.documents == [["d1"], ["d1"]], """
                The vocabulary is \(index.documents). Interning every document in every volume \
                would make this a copy of the corpus rather than an index of its citations — the \
                corpus has 316,839 documents and 5,747 of them are cited across a volume boundary.
                """)
        }
    }

    @Test("A reference to something that is not a document div is not an edge")
    func phantomTargetsAreRejected() async throws {
        try await withCorpus { directory in
            // `in42` is an index-entry anchor: the grammar resolves it as a document, and #764
            // measured 49,799 of them corpus-wide. Minting nodes for those would invent
            // citations into documents that do not exist.
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"volB#in42\">x</ref></p>"),
            ], to: directory)
            let b = try write("volB", documents: [(id: "d1", body: "<p>Text.</p>")], to: directory)
            await #expect(throws: ResolvedEdgeError.self) {
                _ = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")
            }
        }
    }

    @Test("Two references from the same document to the same target are one citation")
    func repeatedReferencesCollapse() async throws {
        try await withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: """
                    <p><ref target="volB#d1">x</ref> and again <ref target="volB#d1">x</ref>.</p>
                    """),
            ], to: directory)
            let b = try write("volB", documents: [(id: "d1", body: "<p>Text.</p>")], to: directory)
            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-08-09")
            #expect(index.coverage.documentEdges == 2, "both references are counted in the funnel")
            #expect(index.targets.first?.edgeCount == 1, """
                Stored \(index.targets.first?.edgeCount ?? -1) edges. A reader counting "documents \
                that cite this" means documents, not mentions.
                """)
        }
    }

    // MARK: - Sections and notes (#1693)

    @Test("A section's own text cites, under the id the app's index stores it under")
    func sectionsCite() async throws {
        try await withCorpus { directory in
            // An introduction (a prose section, a row whole), and a compilation that holds a
            // document and prints text of its own above it (#1536: a row of that text alone).
            let a = try write("frus1945Berlinv02", body: """
                <div type="section" subtype="preface" xml:id="introduction">
                <head>Introduction</head>
                <p>See <ref target="frus1945Berlinv01#d1">volume I, Document 1</ref>.<note n="1" \
                xml:id="introductionfn1">Printed as <ref target="frus1945Berlinv01#d2">Document \
                2</ref>.</note></p>
                </div>
                <div type="compilation" xml:id="comp1">
                <head>Meeting of the Heads of Government</head>
                <p>Present: see <ref target="frus1945Berlinv01#d3fn2">footnote 2 to Document 3</ref>.</p>
                <div type="document" xml:id="d1"><p>Minutes. <ref target="frus1945Berlinv01#d1">x</ref></p></div>
                </div>
                """, to: directory)
            let b = try write("frus1945Berlinv01", documents: [
                (id: "d1", body: "<p>Text.</p>"),
                (id: "d2", body: "<p>Text.</p>"),
                (id: "d3", body: "<p>Text.<note n=\"2\" xml:id=\"d3fn2\">A note.</note></p>"),
            ], to: directory)

            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-10-20")

            #expect(sources(of: "frus1945Berlinv01", "d1", in: index)
                    == ["frus1945Berlinv02/d1", "frus1945Berlinv02/introduction"], """
                The introduction cites Document 1 of volume I and is not among its citers. The app's \
                index stores a section's references under the section's id (index version 68), so \
                a reader with volume II downloaded sees the introduction cite it, and one without \
                volume II must see the same.
                """)
            #expect(sources(of: "frus1945Berlinv01", "d2", in: index)
                    == ["frus1945Berlinv02/introduction"])
            // A reference to a note, from the text a compilation prints above its document.
            #expect(sources(of: "frus1945Berlinv01", "d3", in: index) == ["frus1945Berlinv02/comp1"])

            // The note's reference is a footnote citation; the introduction's body text is not.
            let d2Row = try #require(index.targets.first {
                index.volumes[$0.volume] == "frus1945Berlinv01"
                    && index.documents[$0.volume][$0.document] == "d2"
            })
            #expect(d2Row.footnoteSources == 1)

            // The document's own reference is counted once, in the document funnel.
            #expect(index.coverage.documentEdges == 1)
            #expect(index.coverage.referencesInSections == 3, """
                \(index.coverage.referencesInSections) references in sections' rows. Three are \
                written in the introduction and the compilation; the document's reference is the \
                document's, which the compilation's own row leaves out.
                """)
            #expect(index.coverage.sectionEdges == 3)
            #expect(index.coverage.sameVolumeSectionEdges == 0)
            #expect(index.coverage.storedEdges == 4)
            #expect(index.coverage.citingVolumeCount == 1)
        }
    }

    @Test("A section citing its own volume is counted and not stored")
    func sameVolumeSectionCitationsAreExcluded() async throws {
        try await withCorpus { directory in
            let a = try write("volA", body: """
                <div type="section" subtype="errata" xml:id="errata">
                <head>Errata</head><p>In <ref target="#d1">Document 1</ref>, for X read Y.</p>
                </div>
                <div type="compilation" xml:id="comp1">
                <div type="document" xml:id="d1"><p><ref target="volB#d1">x</ref></p></div>
                </div>
                """, to: directory)
            let b = try write("volB", documents: [(id: "d1", body: "<p>Text.</p>")], to: directory)
            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-10-20")
            #expect(index.coverage.sectionEdges == 1)
            #expect(index.coverage.sameVolumeSectionEdges == 1)
            #expect(!index.documents.joined().contains("errata"), """
                The errata list cites a document of its own volume, which the reader's local table \
                holds whenever the volume is downloaded. It belongs to the funnel, not the index.
                """)
        }
    }

    @Test("A reference to a note under the app's widened pattern cites the note's document")
    func widenedNotesCiteTheirDocument() async throws {
        try await withCorpus { directory in
            // `cr_d6fn4` and `d705fn-sym1` are corpus shapes only the app's widened pattern reads
            // (#988); the twin's old `d\d+[A-Za-z]?fn\d+` read each as a document of that name,
            // which no volume has, so neither was an edge.
            let a = try write("volA", documents: [
                (id: "d1", body: """
                    <p><ref target="volB#cr_d6fn4">x</ref> and <ref target="volB#d705fn-sym1">y</ref></p>
                    """),
            ], to: directory)
            let b = try write("volB", documents: [
                (id: "cr_d6", body: "<p>Text.<note n=\"4\" xml:id=\"cr_d6fn4\">A note.</note></p>"),
                (id: "d705", body: "<p>Text.<note n=\"*\" xml:id=\"d705fn-sym1\">A note.</note></p>"),
            ], to: directory)
            let index = try await ResolvedEdgeIndexRunner.build(files: [a, b], generated: "2026-10-20")
            #expect(sources(of: "volB", "cr_d6", in: index) == ["volA/d1"])
            #expect(sources(of: "volB", "d705", in: index) == ["volA/d1"])
            #expect(index.coverage.documentEdges == 2)
        }
    }

    @Test("A row's references are its <ref>s in order, a note's marked as a note's")
    func rowReferences() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("Introduction")]),
            .paragraph(children: [
                .crossReference(target: "volB#d1", targetVolumeId: "volB",
                                children: [.crossReference(target: "#d2", targetVolumeId: nil,
                                                           children: [])]),
                .footnote(id: "fn1", type: .unclassified, printedNumber: "1", children: [
                    .paragraph(children: [.crossReference(target: "volB#d3fn1",
                                                          targetVolumeId: "volB", children: [])]),
                ]),
            ]),
        ]
        #expect(ResolvedEdgeIndexRunner.references(in: nodes) == [
            .init(target: "volB#d1", isInsideNote: false),
            .init(target: "#d2", isInsideNote: false),
            .init(target: "volB#d3fn1", isInsideNote: true),
        ])
    }

    // MARK: - Refusal and determinism

    @Test("A corpus with no cross-volume citation refuses to write")
    func emptyResultThrows() async throws {
        try await withCorpus { directory in
            let a = try write("volA", documents: [
                (id: "d1", body: "<p><ref target=\"d2\">x</ref></p>"),
                (id: "d2", body: "<p>Text.</p>"),
            ], to: directory)
            await #expect(throws: ResolvedEdgeError.self) {
                _ = try await ResolvedEdgeIndexRunner.build(files: [a], generated: "2026-08-09")
            }
        }
    }

    @Test("The build is deterministic and its rows are sorted")
    func deterministicAndSorted() async throws {
        try await withCorpus { directory in
            var files: [URL] = []
            for volume in ["volC", "volA", "volB"] {
                files.append(try write(volume, documents: [
                    (id: "d2", body: "<p><ref target=\"volA#d1\">x</ref></p>"),
                    (id: "d1", body: "<p><ref target=\"volB#d1\">y</ref></p>"),
                ], to: directory))
            }
            let first = try await ResolvedEdgeIndexRunner.build(files: files, generated: "2026-08-09")
            let second = try await ResolvedEdgeIndexRunner.build(files: files.reversed(),
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
    func raggedRowsAreRefused() async throws {
        let payload = """
            {"v":0,"d":0,"s":[0,1,2],"f":0}
            """
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ResolvedEdgeIndex.TargetEdges.self,
                                         from: Data(payload.utf8))
        }
    }
}
