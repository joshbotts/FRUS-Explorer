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
import FTS5Store
import Foundation
import SQLite3
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
///   1.2 — A18b: every build builds its full index in a folder of its own (`build(_:generated:in:)`);
///          a page of another volume cites under rule C, the map the run writes, and the parity
///          of the run's pairs with the rows a device's index stores from the same map
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

    /// The run over `files`, building its full index in a folder of its own under `directory`
    /// (A18b): the edge index and the page map.
    private func build(_ files: [URL], generated: String,
                       in directory: URL) async throws -> (edges: ResolvedEdgeIndex, pages: CitedPageMap) {
        let index = directory.appendingPathComponent("index-\(UUID().uuidString)", isDirectory: true)
        return try await ResolvedEdgeIndexRunner.build(files: files, generated: generated,
                                                       index: .build(in: index))
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

            let index = try await build([a, b], generated: "2026-08-09", in: directory).edges

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
            let index = try await build([a, b], generated: "2026-08-09", in: directory).edges

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
                _ = try await build([a, b], generated: "2026-08-09", in: directory).edges
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
            let index = try await build([a, b], generated: "2026-08-09", in: directory).edges
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

            let index = try await build([a, b], generated: "2026-10-20", in: directory).edges

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
            let index = try await build([a, b], generated: "2026-10-20", in: directory).edges
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
            let index = try await build([a, b], generated: "2026-10-20", in: directory).edges
            #expect(sources(of: "volB", "cr_d6", in: index) == ["volA/d1"])
            #expect(sources(of: "volB", "d705", in: index) == ["volA/d1"])
            #expect(index.coverage.documentEdges == 2)
        }
    }

    @Test("A row's references are its <ref>s in order, a note's marked as a note's, a page of another volume with its form and hint")
    func rowReferences() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("Introduction")]),
            .paragraph(children: [
                .crossReference(target: "volB#d1", targetVolumeId: "volB",
                                children: [.crossReference(target: "#d2", targetVolumeId: nil,
                                                           children: [])]),
                .footnote(id: "fn1", type: .unclassified, printedNumber: "1", children: [
                    .paragraph(children: [
                        .crossReference(target: "volB#d3fn1", targetVolumeId: "volB", children: []),
                        .text(" See Document 7, "),
                        .crossReference(target: "volB#pg_12", targetVolumeId: "volB",
                                        children: [.text("pp. 12")]),
                        .text("–"),
                        .crossReference(target: "volB#pg_14", targetVolumeId: "volB",
                                        children: [.text("14")]),
                        .text(", and "),
                        .crossReference(target: "#pg_3", targetVolumeId: nil,
                                        children: [.text("p. 3")]),
                        .text(" ff."),
                        .editorialNote([.crossReference(target: "volB#pg_21", targetVolumeId: "volB",
                                                        children: [.text("p. 21")])]),
                    ]),
                ]),
            ]),
        ]
        let hint = PageCitationHint(documentNumbers: ["7"], days: [])
        #expect(ResolvedEdgeIndexRunner.references(in: nodes, volumeId: "volA") == [
            .init(target: "volB#d1", isInsideNote: false, page: nil, pageForm: nil, citing: nil),
            .init(target: "#d2", isInsideNote: false, page: nil, pageForm: nil, citing: nil),
            .init(target: "volB#d3fn1", isInsideNote: true, page: nil, pageForm: nil, citing: nil),
            // A page of another volume: its form, from its siblings, and the note's hint.
            .init(target: "volB#pg_12", isInsideNote: true, page: ("volB", 12),
                  pageForm: .rangeStart(end: 14), citing: hint),
            .init(target: "volB#pg_14", isInsideNote: true, page: ("volB", 14),
                  pageForm: .rangeEnd(start: 12), citing: hint),
            // A page of the volume itself carries the hint, as the index's row does, and no form:
            // the same-volume pass resolves it against the volume's own pages.
            .init(target: "#pg_3", isInsideNote: true, page: nil, pageForm: nil, citing: hint),
            // An editorial note's own text is in no footnote, as the index reads it: no hint.
            .init(target: "volB#pg_21", isInsideNote: false, page: ("volB", 21), pageForm: .single, citing: nil),
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
                _ = try await build([a], generated: "2026-08-09", in: directory).edges
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
            let first = try await build(files, generated: "2026-08-09", in: directory).edges
            let second = try await build(files.reversed(), generated: "2026-08-09", in: directory).edges
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

    // MARK: - A page of another volume (A18b)

    /// A cited volume with pages: Document 1 begins on p. 5; Document 2 begins on p. 7 and runs
    /// through pp. 8–9; Documents 3 and 4 both begin on p. 10, dated July 1 and July 2.
    private static let pagedVolumeBody = """
        <div type="compilation" xml:id="comp1">
        <div type="document" xml:id="d1" n="1"><pb n="5" xml:id="pg_5"/><head>1. Telegram</head>\
        <dateline><date when="1945-06-30">June 30, 1945</date></dateline><p>First.</p></div>
        <div type="document" xml:id="d2" n="2"><pb n="7" xml:id="pg_7"/><head>2. Memorandum</head>\
        <p>Second.<pb n="8" xml:id="pg_8"/> More.<pb n="9" xml:id="pg_9"/> End.</p></div>
        <div type="document" xml:id="d3" n="3"><pb n="10" xml:id="pg_10"/><head>3. Note</head>\
        <dateline><date when="1945-07-01">July 1, 1945</date></dateline><p>Third.</p></div>
        <div type="document" xml:id="d4" n="4"><head>4. Letter</head>\
        <dateline><date when="1945-07-02">July 2, 1945</date></dateline><p>Fourth.</p></div>
        </div>
        """

    /// A citing volume: a document citing the paged volume's pages in every printed form, and an
    /// errata list citing one page.
    private static let citingVolumeBody = """
        <div type="section" subtype="errata" xml:id="errata">
        <head>Errata</head><p>See <ref target="volB#pg_5">p. 5</ref>.</p>
        </div>
        <div type="compilation" xml:id="comp1">
        <div type="document" xml:id="d1" n="1"><head>1. Report</head><p>See \
        <ref target="volB#pg_5">p. 5</ref>, \
        <ref target="volB#pg_7">pp. 7</ref>–<ref target="volB#pg_8">8</ref>, \
        <ref target="volB#pg_5">pp. 5</ref>–<ref target="volB#pg_9">9</ref>, \
        <ref target="volB#pg_7">pp. 7 ff.</ref>, and <ref target="volB#pg_99">p. 99</ref>.\
        <note n="1" xml:id="d1fn1">For the letter of July 2, see <ref target="volB#pg_10">p. 10</ref>.</note></p></div>
        </div>
        """

    @Test("A page of another volume cites the document on it under rule C, through the map the run writes")
    func pagesCite() async throws {
        try await withCorpus { directory in
            let a = try write("volA", body: Self.citingVolumeBody, to: directory)
            let b = try write("volB", body: Self.pagedVolumeBody, to: directory)
            let built = try await build([a, b], generated: "2026-10-21", in: directory)
            let index = built.edges

            // The single page, the range within Document 2, and the page the note's day settles.
            #expect(sources(of: "volB", "d1", in: index) == ["volA/d1", "volA/errata"], """
                p. 5 is Document 1's first page: a single-page reference from Document 1 and one \
                from the errata list cite it, the second under the section's own id.
                """)
            #expect(sources(of: "volB", "d2", in: index) == ["volA/d1"],
                    "pp. 7–8 lie within Document 2, so both ends of the range cite it")
            #expect(sources(of: "volB", "d4", in: index) == ["volA/d1"], """
                p. 10 is where Documents 3 and 4 begin; the note names July 2, Document 4's day, \
                so #1509's tie-break stores Document 4, as a same-volume reference and a tap would.
                """)
            #expect(sources(of: "volB", "d3", in: index).isEmpty)
            // The note's reference is a footnote citation.
            let d4Row = try #require(index.targets.first {
                index.volumes[$0.volume] == "volB" && index.documents[$0.volume][$0.document] == "d4"
            })
            #expect(d4Row.footnoteSources == 1)

            // The funnel: nine references to a page of another volume (eight in Document 1, one in
            // the errata list), five resolving — p. 5 twice, both ends of pp. 7–8, and p. 10. The
            // ends of pp. 5–9, which runs across two documents, "pp. 7 ff.", a compilation's
            // opening, and p. 99, which names nothing, stay references to the volume.
            #expect(index.coverage.crossVolumePageReferences == 9)
            #expect(index.coverage.pageEdges == 5)
            #expect(index.coverage.documentEdges == 0)
            #expect(index.coverage.storedEdges == 5)
            #expect(index.coverage.citingVolumeCount == 1)

            // The map: an entry for every page a single reference cites and for both ends of the
            // range within one document; none for p. 9 (an end of a range across documents only)
            // and none for p. 99. Facts for the two documents on p. 10, the page naming several.
            let map = built.pages
            #expect(map.volumes == ["volB"])
            #expect(map.documents == [["d1", "d2", "d3", "d4"]])
            #expect(map.pages == [[[5, 0, 0], [7, 0, 1], [8, 1, 1], [10, 0, 2, 3]]], """
                The map's pages are \(map.pages). p. 5 and p. 7 are where a document begins \
                (claim 0), p. 8 is printed inside Document 2 (claim 1), and p. 10 names two.
                """)
            #expect(map.facts == [[.init(document: 2, printedNumber: "3", day: "1945-07-01"),
                                   .init(document: 3, printedNumber: "4", day: "1945-07-02")]])
            #expect(map.indexVersion == IndexingPipeline.currentDateIndexVersion)
            #expect(map.entry(volumeId: "volB", page: 9) == nil)
            #expect(map.entry(volumeId: "volB", page: 99) == nil)

            // Built again in another file order, the map is the same file.
            let again = try await build([b, a], generated: "2026-10-21", in: directory)
            #expect(again.pages == map)
            #expect(again.edges == index)
        }
    }

    @Test("The pairs the run writes are the rows a device's index stores from the same map")
    func pairsEqualTheIndex() async throws {
        try await withCorpus { directory in
            let a = try write("volA", body: Self.citingVolumeBody, to: directory)
            let b = try write("volB", body: Self.pagedVolumeBody, to: directory)
            let built = try await build([a, b], generated: "2026-10-21", in: directory)

            // A device's resources: the map the run wrote, beside the four other files, which a
            // host must have and which answer nothing here.
            let resources = directory.appendingPathComponent("resources", isDirectory: true)
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(built.pages).write(to: resources.appendingPathComponent("cited-page-map.json"))
            for name in IndexingResources.indexResourceNames where name != "cited-page-map" {
                try Data("{}".utf8).write(to: resources.appendingPathComponent("\(name).json"))
            }

            // The citing volume indexed through the kit's pipeline, alone: the cited volume is
            // not on this device, and the map stands in for it.
            let volumes = directory.appendingPathComponent("device", isDirectory: true)
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: a, to: volumes.appendingPathComponent("volA.xml"))
            let database = directory.appendingPathComponent("device.sqlite")
            let pipeline = try IndexingPipeline(
                fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                volumesDirectory: volumes,
                resources: try IndexingResources.loading(fromDirectory: resources),
                concurrencyLimit: 1, defaults: InMemoryIndexingStampStore())
            try await pipeline.indexVolume("volA")

            // Every cross-volume row the device stores against a document, as (citer, target).
            var db: OpaquePointer?
            #expect(sqlite3_open_v2(database.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
            defer { sqlite3_close_v2(db) }
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, """
                SELECT source_document_id, target_volume_id, target_document_id FROM cross_references
                WHERE source_volume_id = 'volA' AND target_volume_id IS NOT NULL
                  AND target_volume_id <> source_volume_id AND is_broken = 0
                ORDER BY rowid
                """, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            var stored = Set<String>()
            var left: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let citer = String(cString: sqlite3_column_text(stmt, 0))
                let target = "\(String(cString: sqlite3_column_text(stmt, 1)))/\(String(cString: sqlite3_column_text(stmt, 2)))"
                if target.contains("/pg_") { left.append(target) } else { stored.insert("volA/\(citer) → \(target)") }
            }

            // The run's pairs, as (citer, target).
            var pairs = Set<String>()
            for row in built.edges.targets {
                let target = "\(built.edges.volumes[row.volume])/\(built.edges.documents[row.volume][row.document])"
                for offset in stride(from: 0, to: row.sources.count, by: 2) {
                    let sv = row.sources[offset]
                    pairs.insert("\(built.edges.volumes[sv])/\(built.edges.documents[sv][row.sources[offset + 1]]) → \(target)")
                }
            }
            #expect(pairs == stored, """
                The run's pairs are \(pairs.sorted()); the device stored \(stored.sorted()). The \
                two must be the same rows, since both come from one map through one function.
                """)
            #expect(pairs.count == 4)
            // What the device leaves on the volume is what the run left: the range across two
            // documents, "ff." and the page naming nothing.
            #expect(left.sorted() == ["volB/pg_5", "volB/pg_7", "volB/pg_9", "volB/pg_99"], """
                The device left \(left.sorted()) as references to the volume.
                """)
        }
    }

    @Test("A run given no index refuses rather than writing an empty map")
    func missingIndexThrows() async throws {
        try await withCorpus { directory in
            let a = try write("volA", body: Self.citingVolumeBody, to: directory)
            let b = try write("volB", body: Self.pagedVolumeBody, to: directory)
            await #expect(throws: ResolvedEdgeError.self) {
                _ = try await ResolvedEdgeIndexRunner.build(
                    files: [a, b], generated: "2026-10-21",
                    index: .existing(directory.appendingPathComponent("nowhere.db")))
            }
        }
    }
}
