// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import ProvenanceFlowIndexGeneratorCore
import CollectionAuthorityGeneratorCore
import CrossRefValidationGeneratorCore
import SourceExplorerExportGeneratorCore

// MARK: - DocumentIdInventoryTests

/// The narrower inventory the flow join needs: document divs only.
@Suite("Document id inventory")
struct DocumentIdInventoryTests {

    @Test("Only document divs are inventoried, and comments never contribute")
    func documentDivsOnly() {
        let xml = """
        <TEI><text><body>
          <div type="chapter" xml:id="ch1">
            <div type="document" xml:id="d1"><p>One</p></div>
            <div type="section" xml:id="index"><p>Back-of-book index</p></div>
            <div type="document" xml:id="d2"/>
          </div>
          <!-- <div type="document" xml:id="dCommented"/> -->
        </body></text></TEI>
        """
        let ids = DocumentIdInventory.documentIds(in: Data(xml.utf8))
        #expect(ids == ["d1", "d2"], """
            Got \(ids.sorted()). A section id in the inventory would let index-entry anchors — \
            49,799 of them corpus-wide — mint phantom nodes in the flow matrix, and a commented \
            div would invent a document that does not exist.
            """)
    }

    @Test("A subtype attribute cannot be mistaken for type")
    func subtypeIsNotType() {
        let xml = """
        <TEI><div subtype="document" xml:id="notADoc"/>
        <div type="document" subtype="historical-document" xml:id="realDoc"/></TEI>
        """
        #expect(DocumentIdInventory.documentIds(in: Data(xml.utf8)) == ["realDoc"])
    }
}

// MARK: - ProvenanceFlowIndexGeneratorTests

/// The flow aggregation (#764), driven over a fixture corpus through the real harvester, grammar,
/// parser and authority lookup.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
@Suite("Provenance flow index — generator")
struct ProvenanceFlowIndexGeneratorTests {

    private func fixtureAuthority() -> AuthorityLookup {
        AuthorityLookup(collections: [
            AuthorityCollection(id: "lot:64D199", name: "Conference Files", lotFileNorm: "64D199"),
            AuthorityCollection(id: "txt:johnson library|national security file",
                                name: "National Security File", repository: "Johnson Library"),
        ])
    }

    /// A volume of documents, each with a source note and optional outgoing refs.
    private func volume(_ id: String, documents: [(note: String, refs: [String])],
                        in directory: URL, refsInFootnotes: Bool = true) throws -> URL {
        let divs = documents.enumerated().map { index, document -> String in
            let links = document.refs
                .map { "<ref target=\"\($0)\">see</ref>" }
                .joined()
            let payload = refsInFootnotes ? "<note type=\"editorial\">\(links)</note>" : links
            return """
              <div type="document" xml:id="d\(index + 1)">
                <note type="source">\(document.note)</note>
                <p>Body.\(payload)</p>
              </div>
            """
        }.joined(separator: "\n")
        let url = directory.appendingPathComponent("\(id).xml")
        try Data("<TEI><text><body>\n\(divs)\n</body></text></TEI>".utf8).write(to: url)
        return url
    }

    private func corpus(refsInFootnotes: Bool = true) throws -> [URL] {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let lot = "Source: Department of State, Conference Files: Lot 64 D 199, CF 1."
        let nsf = "Source: Johnson Library, National Security File, Country File, Vietnam."
        let decimal = "Source: Department of State, Central Files, 611.41/3–553. Secret."
        return [
            // d1 (lot) → d2 (library): a between-unit edge. d2 → d1: the reverse.
            // d3 (decimal) → d1 (lot): a class-source with no class target.
            // d1 → dNope: a dangling target that must not become an edge.
            try volume("frus1964-68v01", documents: [
                (lot, ["d2", "dNope", "frus1964-68v02#d1"]),
                (nsf, ["d1"]),
                (decimal, ["d1"]),
            ], in: root, refsInFootnotes: refsInFootnotes),
            try volume("frus1964-68v02", documents: [
                // Same collection as v01/d1, so this pair is a same-unit edge in both directions.
                (lot, ["frus1964-68v01#d1"]),
            ], in: root, refsInFootnotes: refsInFootnotes),
        ]
    }

    private func build(_ files: [URL]) throws -> ProvenanceFlowIndex {
        try ProvenanceFlowIndexRunner.build(files: files, authority: fixtureAuthority(),
                                            generated: "2026-08-08")
    }

    private func flow(_ index: ProvenanceFlowIndex, _ from: String, _ to: String) -> Int {
        guard let s = index.collectionIds.firstIndex(of: from),
              let t = index.collectionIds.firstIndex(of: to) else { return 0 }
        return index.collectionFlows.first { $0.source == s && $0.target == t }?.count ?? 0
    }

    // MARK: - The join

    @Test("A reference between two collections becomes one directed flow each way")
    func directedFlows() throws {
        let index = try build(try corpus())
        let lot = "lot:64D199"
        let nsf = "txt:johnson library|national security file"
        #expect(flow(index, lot, nsf) == 1, "d1 (lot) references d2 (library)")
        #expect(flow(index, nsf, lot) == 1, "and d2 references d1 back — direction is preserved")
        #expect(flow(index, nsf, nsf) == 0)
    }

    @Test("A cross-volume reference between documents in the same collection is a same-unit flow")
    func sameUnitFlowsAreRetained() throws {
        let index = try build(try corpus())
        // frus…v01/d1 and frus…v02/d1 both cite Lot 64 D 199.
        #expect(flow(index, "lot:64D199", "lot:64D199") == 2, """
            Same-unit references must be stored, not dropped. The design excludes them from \
            display, and an artifact that had already dropped them could not say what the \
            exclusion removed.
            """)
        #expect(index.coverage.collections.sameUnitReferences == 2)
        #expect(index.coverage.collections.betweenUnitReferences
                == index.coverage.collections.joinedReferences - 2)
    }

    @Test("A reference to a target that is not a document div is not an edge")
    func danglingTargetsAreNotEdges() throws {
        let index = try build(try corpus())
        // Six refs sit inside documents; "dNope" resolves to no document div, so five are edges.
        #expect(index.coverage.referencesInsideDocuments == 6)
        #expect(index.coverage.documentEdges == 5, """
            Got \(index.coverage.documentEdges). A target that is not a document div must not \
            become an edge, or every index-entry anchor mints a node.
            """)
    }

    @Test("An unjoinable end drops the edge from that axis but not from the funnel")
    func unjoinableEndsAreCounted() throws {
        let index = try build(try corpus())
        // d3 is a decimal document referencing d1, which has no class — a class-axis miss that
        // is still a real edge.
        #expect(index.coverage.documentEdges > index.coverage.classes.joinedReferences)
        #expect(index.coverage.classes.joinedReferences == 0,
                "no fixture edge has a class at both ends")
        #expect(index.classFlows.isEmpty)
        #expect(index.classKeys.isEmpty)
    }

    // MARK: - What the matrix measures

    @Test("Footnote references are counted separately from body-text references")
    func footnoteEdgesAreDistinguished() throws {
        let inNotes = try build(try corpus(refsInFootnotes: true))
        #expect(inNotes.coverage.footnoteEdges == inNotes.coverage.documentEdges,
                "every fixture reference is inside a note")

        let inBody = try build(try corpus(refsInFootnotes: false))
        #expect(inBody.coverage.footnoteEdges == 0, """
            Body-text references were counted as footnotes. Measured on the corpus, 95.3% of \
            edges are footnotes, and that single number is what stops the matrix being read as a \
            relation between the archives rather than as the editors' annotation practice.
            """)
        #expect(inBody.coverage.documentEdges == inNotes.coverage.documentEdges,
                "moving a reference out of a note must not change whether it is an edge")
    }

    // MARK: - Shape and determinism

    @Test("Vocabularies are sorted, rows are sorted, and every count is positive")
    func shapeInvariants() throws {
        let index = try build(try corpus())
        #expect(index.collectionIds == index.collectionIds.sorted())
        #expect(index.collectionFlows.map { [$0.source, $0.target] }
                == index.collectionFlows.map { [$0.source, $0.target] }
                    .sorted { ($0[0], $0[1]) < ($1[0], $1[1]) })
        for row in index.collectionFlows {
            #expect(row.count > 0)
            #expect(index.collectionIds.indices.contains(row.source))
            #expect(index.collectionIds.indices.contains(row.target))
        }
        #expect(index.coverage.collections.unitCount == index.collectionIds.count)
        #expect(index.coverage.collections.pairCount == index.collectionFlows.count)
    }

    @Test("The same corpus in a different order produces the same bytes")
    func deterministic() throws {
        let files = try corpus()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(try encoder.encode(try build(files)) == encoder.encode(try build(files.reversed())))
    }

    @Test("A corpus that joins no flows at all throws instead of writing an empty index")
    func emptyJoinThrows() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flow-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = try volume("frus1900v01", documents: [
            ("Printed from an unsigned copy.", ["d2"]),
            ("The original is in a private collection.", []),
        ], in: root)
        #expect(throws: ProvenanceFlowError.self) {
            _ = try ProvenanceFlowIndexRunner.build(files: [file], authority: self.fixtureAuthority(),
                                                    generated: "2026-08-08")
        }
    }
}
