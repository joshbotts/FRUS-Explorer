// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - CollectionAddDocumentsHostTests

/// What Add Documents' Citations and Tags tabs read of the kit, called as a host outside the app
/// calls them (FRUS Explorer Light's S18d): `CollectionCitationLineResolver` over the kit's parser and
/// matching engine, wired as such a host wires its engine — over the published catalogue alone, and
/// over an index it serves, whose volumes are the ones it holds — and
/// `CollectionGeneratedBlocks.tagDocumentRefs(tagId:noteTags:assignments:)` over a host's notes and
/// assignments as values. The kit's suites already run the resolver's links over the real engine
/// (`CitationLookupIndexedTests`) and the union through the Thematic Index (`CollectionResolutionTests`),
/// and the sheet's bucketing over stubs is the app's (`CollectionTests`); beside them this suite holds
/// what a host relies on: a paste's lines, the rows of the sheet's case with no matcher, each bucket
/// and its words over both engines a host builds, and the union's own order. It imports the kit
/// `@testable`, so it cannot show that these are public; a host's own build does.
///
/// Version history:
///   1.0 — 2026-10-28 (FRUS Explorer Light, S18d): initial implementation
@Suite("FRUSCoreKit — Add Documents' Citations and Tags, as a host calls them")
struct CollectionAddDocumentsHostTests {

    // MARK: The paste

    @Test("A paste is split into its lines, trimmed, whatever line breaks it carries, and a blank line is none")
    func aPasteSplitsIntoItsTrimmedLines() {
        // A browser's form sends a text area's line breaks as CR LF; a paste can carry a lone CR,
        // a tab or a line of spaces.
        let text = "  FRUS, 1961–1963, vol. V, doc. 84 \r\n\r\n\tline two\rline three\n   \n\nline four"
        #expect(CollectionCitationLineResolver.lines(from: text)
                == ["FRUS, 1961–1963, vol. V, doc. 84", "line two", "line three", "line four"])
        #expect(CollectionCitationLineResolver.lines(from: "").isEmpty)
        #expect(CollectionCitationLineResolver.lines(from: " \n\t\r\n").isEmpty)
    }

    @Test("With no matcher to ask, a host lists every line as the sheet does, each a row of its own")
    func withNoMatcherEveryLineIsARow() {
        let reason = "Citation lookup is unavailable"
        let rows = CollectionCitationLineResolver.lines(from: "first\n\nsecond\nfirst").map {
            CollectionCitationLineResolver.LineResult(line: $0, outcome: .unresolved(reason: reason))
        }
        #expect(rows.map(\.line) == ["first", "second", "first"])
        #expect(rows.allSatisfy { $0.outcome == .unresolved(reason: reason) })
        // A row's id is its own, so a line pasted twice is two rows.
        #expect(Set(rows.map(\.id)).count == 3)
    }

    // MARK: Citations

    /// A resolver as the sheet builds one: the kit's parser and the engine's `match(input:)`.
    private static func resolver(over engine: CitationMatchingEngine) -> CollectionCitationLineResolver {
        let parser = CitationParser()
        return CollectionCitationLineResolver(parse: { parser.parse($0) },
                                              match: { try await engine.match(input: $0) })
    }

    /// A row of the published catalogue.
    private static func entry(_ volumeId: String, _ subseries: String, _ title: String) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId, filename: "\(volumeId).xml", subseries: subseries, title: title,
            dateRange: DateRange(earliest: "1961-01-01", latest: "1963-12-31"),
            publicationDate: "1990", status: .published, editors: [], generalEditor: nil,
            sizeBytes: 0, tags: [])
    }

    /// Volume V and Volume XIV of 1961–63, each with a document 84, and the Paris Peace
    /// Conference's Volume I, whose id is mixed-case, as 51 of the catalogue's are.
    private static let catalogue: [VolumeManifestEntry] = [
        entry("frus1961-63v05", "1961-63",
              "Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union"),
        entry("frus1961-63v14", "1961-63",
              "Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962"),
        entry("frus1919Parisv01", "1919",
              "Papers Relating to the Foreign Relations of the United States, The Paris Peace Conference, 1919, Volume I"),
    ]

    @Test("Over the catalogue alone, as a host matches before it serves an index, a link to a numbered document is added by the catalogue's ids, and nothing else is")
    func overTheCatalogueAlone() async {
        // The engine a host builds when it serves no index: every volume is one to download.
        let engine = CitationMatchingEngine(manifestStore: await makeTestCatalogue(Self.catalogue),
                                            searchService: nil, pageRangeStore: nil, downloadedVolumeIds: [])
        let results = await Self.resolver(over: engine).resolve(text: """
              https://history.state.gov/historicaldocuments/frus1919parisv01/D12

            FRUS, 1961–1963, vol. V, doc. 84
            https://history.state.gov/historicaldocuments/frus1961-63v14/ch3
            With thanks to the archivists
            """)
        #expect(results.map(\.line) == [
            "https://history.state.gov/historicaldocuments/frus1919parisv01/D12",
            "FRUS, 1961–1963, vol. V, doc. 84",
            "https://history.state.gov/historicaldocuments/frus1961-63v14/ch3",
            "With thanks to the archivists",
        ])
        // A retyped link takes the catalogue's spelling of its volume, and its document's `d` in
        // lower case (#1502).
        #expect(results.first?.outcome == .resolved(volumeId: "frus1919Parisv01", documentId: "d12", note: nil))
        // A citation of a volume not held is the engine's "download" row, and so is a link to what
        // may be a chapter, which only the volume's index can tell from a document. None is dropped.
        #expect(results.map(\.outcome).dropFirst().prefix(2).allSatisfy {
            $0 == .unresolved(reason: ConfidenceLabels.manifestOnly)
        }, "\(results.map(\.outcome))")
        // A line that is no citation says so in the resolver's words: its parse names nothing to
        // match, so the matcher is never asked. No strings file holds the resolver's keys, so every
        // platform shows their default text.
        #expect(results.last?.outcome
                == .unresolved(reason: "Couldn’t read this line as a FRUS citation or document link"))
        #expect(Set(results.map(\.id)).count == results.count)
    }

    /// One fixture document: its id and its printed number.
    private struct Doc {
        let id: String
        let number: String
    }

    /// Writes a minimal TEI volume whose documents carry `@n` and a head, as the corpus writes them.
    private static func writeVolume(_ volumeId: String, _ docs: [Doc], to volumes: URL) throws {
        let divs = docs.map { doc in
            "<div type=\"document\" xml:id=\"\(doc.id)\" n=\"\(doc.number)\">"
                + "<head>\(doc.number). Memorandum \(doc.id)</head><p>Text of \(doc.id).</p></div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>1990</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">
          \(divs)
          </div></body></text>
        </TEI>
        """
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
    }

    @Test("Over an index a host serves, its volumes the ones it holds, a citation and a link resolve to their documents, one naming no volume is offered for review, a document the index lacks is not added, and a link into a volume it does not hold is added by its id")
    func overAnIndexAHostServes() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSAddDocumentsHostTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        let volumes = dir.appendingPathComponent("volumes")
        let held: [(volumeId: String, docs: [Doc])] = [
            ("frus1961-63v05", [Doc(id: "d83", number: "83"), Doc(id: "d84", number: "84")]),
            ("frus1961-63v14", [Doc(id: "d7", number: "7"), Doc(id: "d84", number: "84")]),
        ]
        for volume in held {
            try Self.writeVolume(volume.volumeId, volume.docs, to: volumes)
            try await pipeline.indexVolume(volume.volumeId)
        }
        // The engine a host builds over the index it serves: the catalogue, the index's search
        // and page ranges, and the volumes the index holds as the ones downloaded.
        let engine = CitationMatchingEngine(
            manifestStore: await makeTestCatalogue(Self.catalogue),
            searchService: SearchService(fts5Store: store, pipeline: pipeline),
            pageRangeStore: try PageRangeStore(databaseURL: dir.appendingPathComponent("test.sqlite")),
            downloadedVolumeIds: Set(held.map(\.volumeId)))
        let results = await Self.resolver(over: engine).resolve(text: """
            FRUS, 1961–1963, vol. V, doc. 84
            https://history.state.gov/historicaldocuments/frus1961-63v14/d84
            Document 84
            https://history.state.gov/historicaldocuments/frus1961-63v14/d999
            https://history.state.gov/historicaldocuments/frus1919Parisv01/d12
            """)
        let outcomes = results.map(\.outcome)
        #expect(outcomes.count == 5)
        #expect(Array(outcomes.prefix(2)) == [
            .resolved(volumeId: "frus1961-63v05", documentId: "d84", note: nil),
            .resolved(volumeId: "frus1961-63v14", documentId: "d84", note: nil),
        ])
        // A citation that names no volume is at most a guess, whatever the engine calls its match:
        // the engine's top match, in the first volume that holds the number, for review, its note
        // the engine's label and why it is a guess.
        #expect(outcomes.dropFirst(2).first == .ambiguous(
            volumeId: "frus1961-63v05", documentId: "d84",
            note: "\(ConfidenceLabels.exactMatch) — the citation doesn’t identify a volume, so this match is a guess"))
        // A link into a volume the index holds is not taken on its word (#1502); one into a
        // catalogued volume the index does not hold is, as the app takes one into a volume it has
        // not downloaded, so its entry names a document the host cannot show yet.
        #expect(Array(outcomes.suffix(2)) == [
            .unresolved(reason: ConfidenceLabels.linkVolumeOnly),
            .resolved(volumeId: "frus1919Parisv01", documentId: "d12", note: nil),
        ])
    }

    // MARK: Tags

    @Test("A tag's documents are its notes' and then its assignments', each document once, in the order the host gives them")
    func aTagsDocumentsAreItsNotesThenItsAssignments() {
        let tag = UUID(), other = UUID()
        let refs = CollectionGeneratedBlocks.tagDocumentRefs(
            tagId: tag,
            noteTags: [
                (volumeId: "frus1961-63v05", documentId: "d84", tagIds: [other, tag]),
                (volumeId: "frus1961-63v05", documentId: "d9", tagIds: [other]),
                (volumeId: "frus1961-63v14", documentId: "d7", tagIds: [tag]),
                // A second note on a document the tag already reaches.
                (volumeId: "frus1961-63v05", documentId: "d84", tagIds: [tag]),
            ],
            assignments: [
                (volumeId: "frus1961-63v14", documentId: "d8", tagId: tag),
                // A document a note already carries the tag on.
                (volumeId: "frus1961-63v14", documentId: "d7", tagId: tag),
                (volumeId: "frus1961-63v05", documentId: "d1", tagId: other),
                (volumeId: "frus1961-63v05", documentId: "d2", tagId: tag),
            ])
        #expect(refs.map { "\($0.volumeId)/\($0.documentId)" }
                == ["frus1961-63v05/d84", "frus1961-63v14/d7", "frus1961-63v14/d8", "frus1961-63v05/d2"])
        // The same document in another volume is another document.
        let twoVolumes = CollectionGeneratedBlocks.tagDocumentRefs(
            tagId: tag, noteTags: [(volumeId: "frus1961-63v05", documentId: "d84", tagIds: [tag])],
            assignments: [(volumeId: "frus1961-63v14", documentId: "d84", tagId: tag)])
        #expect(twoVolumes.map(\.volumeId) == ["frus1961-63v05", "frus1961-63v14"])
    }

    @Test("A tag that no note or assignment carries gathers nothing")
    func aTagNothingCarriesGathersNothing() {
        let tag = UUID(), other = UUID()
        #expect(CollectionGeneratedBlocks.tagDocumentRefs(tagId: tag, noteTags: [], assignments: []).isEmpty)
        #expect(CollectionGeneratedBlocks.tagDocumentRefs(
            tagId: tag,
            noteTags: [(volumeId: "frus1961-63v05", documentId: "d84", tagIds: [other]),
                       (volumeId: "frus1961-63v05", documentId: "d83", tagIds: [])],
            assignments: [(volumeId: "frus1961-63v14", documentId: "d7", tagId: other)]).isEmpty)
    }
}
