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

// MARK: - Fixture

/// A private temp directory, named so it cannot collide with the `withTempDir` helpers other suites
/// declare privately.
private func withGateTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("document-gate-parity-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// The fixture's three volumes, indexed, with summaries and tags on some of their documents.
///
/// - `frus1951v01`: sixty documents whose bodies hold "quillon" one to four times, so bm25 orders
///   them; every third an editorial note; dated across 1950–1959; every fifth also holds "zircaloy";
///   every seventh names a person (`p_acheson`); and a preface that holds the word, front matter.
/// - `frus1952v02`: twelve documents with byte-identical bodies, so they share one bm25 score: a tie
///   is where two plans could legitimately return rows in different orders.
/// - `frus1953v03`: 520 short documents, so that a gate can pass 499 keys, the size of one of the
///   key test's `IN` groups.
private enum GateFixture {

    static let mainVolume = "frus1951v01"
    static let tieVolume = "frus1952v02"
    static let bulkVolume = "frus1953v03"
    static let mainCount = 60
    static let tieCount = 12
    static let bulkCount = 520
    static let tagId = "8F0B4B1E-9C5D-4E1A-B1E3-0C6A7D5E4F21"

    /// Whether the main volume's document `index` is an editorial note.
    static func isNote(_ index: Int) -> Bool { index.isMultiple(of: 3) }

    static func key(_ volume: String, _ index: Int) -> String { "\(volume)/d\(index)" }

    static func write(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let main = (1...mainCount).map { index -> String in
            let subtype = isNote(index) ? "editorial-note" : "historical-document"
            let words = Array(repeating: "quillon", count: 1 + index % 4).joined(separator: " ")
            let rare = index.isMultiple(of: 5) ? " The zircaloy cladding was discussed." : ""
            let person = index.isMultiple(of: 7)
                ? " <persName corresp=\"#p_acheson\">Acheson</persName> attended." : ""
            let year = 1950 + index % 10
            let month = 1 + index % 9
            return """
                  <div type="document" subtype="\(subtype)" n="\(index)" xml:id="d\(index)">
                    <head>\(index). Memorandum \(index)</head>
                    <dateline><date when="\(year)-0\(month)-15">\(year)</date></dateline>
                    <p>Item \(index) on \(words) and the matter of record number \(index * 37).\(rare)\(person)</p>
                  </div>
            """
        }.joined(separator: "\n")
        try volume(mainVolume, front: """
              <front>
                <div type="section" subtype="preface" xml:id="preface">
                  <head>Preface</head>
                  <p>Prefatory remarks on quillon documentation.</p>
                </div>
              </front>
            """, body: main).write(to: dir.appendingPathComponent("\(mainVolume).xml"), atomically: true, encoding: .utf8)

        let ties = (1...tieCount).map { index in
            """
                  <div type="document" subtype="historical-document" n="\(index)" xml:id="d\(index)">
                    <head>\(index). Memo</head>
                    <dateline><date when="1952-03-01">March 1, 1952</date></dateline>
                    <p>Identical quillon text for tie scoring.</p>
                  </div>
            """
        }.joined(separator: "\n")
        try volume(tieVolume, front: "", body: ties)
            .write(to: dir.appendingPathComponent("\(tieVolume).xml"), atomically: true, encoding: .utf8)

        let bulk = (1...bulkCount).map { index in
            """
                  <div type="document" subtype="historical-document" n="\(index)" xml:id="d\(index)">
                    <head>\(index). Telegram</head>
                    <dateline><date when="1953-0\(1 + index % 9)-01">1953</date></dateline>
                    <p>Telegram \(index) on quillon\(index.isMultiple(of: 2) ? " quillon" : "") and item \(index * 11).</p>
                  </div>
            """
        }.joined(separator: "\n")
        try volume(bulkVolume, front: "", body: bulk)
            .write(to: dir.appendingPathComponent("\(bulkVolume).xml"), atomically: true, encoding: .utf8)
    }

    private static func volume(_ volumeId: String, front: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date when="2010">2010</date></publicationStmt>
          <sourceDesc><p>Gate fixture</p></sourceDesc></fileDesc></teiHeader>
          <text>
        \(front)
            <body>
              <div type="compilation">
        \(body)
              </div>
            </body>
          </text>
        </TEI>
        """
    }

    /// Indexes the three volumes, then gives some documents a summary that holds the word, so that a
    /// search of both scopes merges two matches, and some a user tag.
    static func makePipeline(in dir: URL) async throws -> IndexingPipeline {
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        try write(to: dir.appendingPathComponent("volumes"))
        for volume in [mainVolume, tieVolume, bulkVolume] {
            try await pipeline.indexVolume(volume)
        }
        // Odd documents, which `scatteredGate` holds, and on every fourth so the gate also holds
        // documents with none.
        for index in stride(from: 1, through: mainCount, by: 4) {
            try await pipeline.updateSummaryText(volumeId: mainVolume, documentId: "d\(index)",
                                                 responseText: "A summary that mentions quillon.")
        }
        for index in stride(from: 1, through: mainCount, by: 6) {
            try await pipeline.updateUserTagIds(volumeId: mainVolume, documentId: "d\(index)",
                                                userTagIds: tagId)
        }
        return pipeline
    }

    /// A gate scattered over all three volumes: every other main document, half the tied ones and
    /// every seventh of the bulk volume, with the preface (front matter), a member the index does not
    /// hold, a member written twice and one with no `/`.
    static var scatteredGate: [String] {
        var gate = stride(from: 1, through: mainCount, by: 2).map { key(mainVolume, $0) }
        gate += stride(from: 2, through: tieCount, by: 2).map { key(tieVolume, $0) }
        gate += stride(from: 3, through: bulkCount, by: 7).map { key(bulkVolume, $0) }
        gate += ["\(mainVolume)/preface", "\(mainVolume)/d999", key(mainVolume, 9), "nonsense"]
        return gate
    }
}

// MARK: - DocumentGateParityTests

/// Decision 53 (plan of record, #1577 lane 4): a search inside a set of documents tests the set as
/// rowids found through `document_cache`'s primary key, where it tested each matched row's key, and
/// it returns the same rows, in the same order, with the same counts.
///
/// ## Why the equivalence is asserted, not argued
/// The rowid gate changes which statement SQLite runs: with no other filter the ranking phase and
/// the count lose their joins, and the gate becomes a subquery tested against the match's own rowid.
/// That two shapes return the same rows is a claim about how a key splits and about SQLite's
/// planner, which deserves a test. `searchDocumentsGateByKeyForTesting` and
/// `searchDocumentsCountGateByKeyForTesting` keep the key test reachable, so both run against the
/// same fixture in the same process; the facet path's joined parity shape renders it too.
///
/// ## What the plan tests are for
/// Equal rows cannot show the joins coming back: the answer is the same either way. Only the plan
/// says that every matched row is looked up again, which is what cost a common word 6.8 s cold
/// inside 327 documents on a full index.
///
/// Version history:
///   1.0 — #1577 lane 4 (decision 53): initial implementation
@Suite("Document gate: the rowid gate returns what the key test returned")
struct DocumentGateParityTests {

    /// Compares the rowid gate's search and count with the key test's, row by row, and fails naming
    /// the first row that differs.
    private func assertParity(
        _ pipeline: IndexingPipeline,
        _ label: String,
        corpusMatch: String?,
        userContentMatch: String? = nil,
        filters: SearchSQLFilters,
        limit: Int = 1_000,
        offset: Int = 0,
        expectRows: Bool = true
    ) async throws {
        let gated = try await pipeline.searchDocuments(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch,
            filters: filters, limit: limit, offset: offset)
        let byKey = try await pipeline.searchDocumentsGateByKeyForTesting(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch,
            filters: filters, limit: limit, offset: offset)
        // A control: two empty answers agree with each other whatever the code does.
        if expectRows {
            #expect(!byKey.isEmpty, "\(label): precondition, the key test must find rows here")
        }
        #expect(gated.count == byKey.count,
                "\(label): \(gated.count) rows where the key test gave \(byKey.count)")
        for (index, pair) in zip(gated, byKey).enumerated() {
            let (new, old) = pair
            #expect(new.volumeId == old.volumeId && new.documentId == old.documentId,
                    "\(label): row \(index) is \(new.volumeId)/\(new.documentId) where the key test gave \(old.volumeId)/\(old.documentId)")
            #expect(new.score == old.score, "\(label): row \(index) score differs")
            #expect(new.bodyText == old.bodyText && new.header == old.header
                        && new.dateISO == old.dateISO && new.userTagIds == old.userTagIds,
                    "\(label): row \(index) columns differ")
        }
        let count = try await pipeline.searchDocumentsCount(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters)
        let countByKey = try await pipeline.searchDocumentsCountGateByKeyForTesting(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch, filters: filters)
        #expect(count == countByKey, "\(label): count \(count) where the key test gave \(countByKey)")
    }

    @Test("Every filter beside the gate gives the same rows in the same order")
    func everyFilterShapeMatches() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            let gate = GateFixture.scatteredGate
            let shapes: [(String, SearchSQLFilters)] = [
                ("gate alone", SearchSQLFilters(documentIds: gate)),
                ("gate, front matter excluded",
                 SearchSQLFilters(documentIds: gate, includeFrontMatter: false)),
                ("gate, documents only",
                 SearchSQLFilters(documentIds: gate, documentTypeFilter: .documentsOnly)),
                ("gate, editorial notes only",
                 SearchSQLFilters(documentIds: gate, documentTypeFilter: .editorialNotesOnly)),
                ("gate, date range",
                 SearchSQLFilters(documentIds: gate,
                                  dateRange: DateRange(earliest: "1952-01-01", latest: "1955-12-31"))),
                ("gate, years", SearchSQLFilters(documentIds: gate, yearKeys: ["1951", "1953"])),
                ("gate, one volume",
                 SearchSQLFilters(volumeIds: [GateFixture.mainVolume], documentIds: gate)),
                ("gate, a person", SearchSQLFilters(documentIds: gate, personRef: "p_acheson")),
                ("gate, a tag", SearchSQLFilters(documentIds: gate, userTagIds: [GateFixture.tagId])),
                ("gate, excluded documents",
                 SearchSQLFilters(documentIds: gate,
                                  excludeDocumentIds: [GateFixture.key(GateFixture.mainVolume, 1)])),
                ("gate, an exact word",
                 SearchSQLFilters(documentIds: gate, exactTerms: ["quillon"],
                                  exactColumns: ["header", "dateline", "source_note", "body_text"])),
            ]
            for (label, filters) in shapes {
                try await assertParity(pipeline, label, corpusMatch: "quillon", filters: filters)
            }
            // The rare word, a phrase, a prefix and NEAR, each inside the gate.
            for (label, match) in [("rare word", "zircaloy"), ("phrase", "\"identical quillon\""),
                                   ("prefix", "quill*"), ("NEAR", "NEAR(quillon record, 8)")] {
                try await assertParity(pipeline, label, corpusMatch: match,
                                       filters: SearchSQLFilters(documentIds: gate))
            }
        }
    }

    @Test("A search of the documents and the reader's summaries merges alike inside the gate")
    func bothScopesMatch() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            let gate = GateFixture.scatteredGate
            // The summaries hold the word on every fourth main document: the precondition is that the
            // user-content match reaches rows inside the gate, so the merge is exercised there.
            let summaryOnly = try await pipeline.searchDocuments(
                corpusMatch: nil, userContentMatch: "quillon",
                filters: SearchSQLFilters(documentIds: gate), limit: 1_000, offset: 0)
            #expect(!summaryOnly.isEmpty, "precondition: a summary inside the gate holds the word")
            try await assertParity(pipeline, "both scopes", corpusMatch: "quillon",
                                   userContentMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: gate))
            try await assertParity(pipeline, "both scopes, documents only", corpusMatch: "quillon",
                                   userContentMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: gate,
                                                             documentTypeFilter: .documentsOnly))
            try await assertParity(pipeline, "summaries alone", corpusMatch: nil,
                                   userContentMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: gate))
        }
    }

    @Test("Pages and tied scores come back in the key test's order")
    func pagesAndTiesMatch() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            // Every tied document, and nothing else: bm25 cannot order them, so the order is the plan's.
            let ties = (1...GateFixture.tieCount).map { GateFixture.key(GateFixture.tieVolume, $0) }
            let tied = try await pipeline.searchDocuments(
                corpusMatch: "quillon", userContentMatch: nil,
                filters: SearchSQLFilters(documentIds: ties), limit: 100, offset: 0)
            #expect(tied.count == GateFixture.tieCount, "precondition: every tied document matches")
            #expect(Set(tied.map(\.score)).count == 1, "precondition: the tied documents share one score")
            for attempt in 1...6 {
                try await assertParity(pipeline, "ties, attempt \(attempt)", corpusMatch: "quillon",
                                       filters: SearchSQLFilters(documentIds: ties))
                try await assertParity(pipeline, "ties, second page, attempt \(attempt)",
                                       corpusMatch: "quillon",
                                       filters: SearchSQLFilters(documentIds: ties), limit: 4, offset: 4)
            }
            // A window drawn from the wrong set would show first on a later page.
            for (limit, offset) in [(1, 0), (1, 1), (10, 10), (25, 50), (5, 9_999)] {
                try await assertParity(pipeline, "limit \(limit) offset \(offset)",
                                       corpusMatch: "quillon",
                                       filters: SearchSQLFilters(documentIds: GateFixture.scatteredGate),
                                       limit: limit, offset: offset, expectRows: offset < 9_999)
            }
        }
    }

    @Test("The gate's edge cases: empty, absent, repeated, malformed, one member, more than one IN group")
    func gateEdgeCasesMatch() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            // An empty gate matches nothing, by its contract, and is no gate at all for neither shape.
            let empty = try await pipeline.searchDocuments(
                corpusMatch: "quillon", userContentMatch: nil,
                filters: SearchSQLFilters(documentIds: []), limit: 100, offset: 0)
            #expect(empty.isEmpty, "an empty gate matches nothing")
            try await assertParity(pipeline, "empty gate", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: []), expectRows: false)
            // Members the index does not hold, and a key with no slash, match nothing in either shape.
            try await assertParity(pipeline, "absent and malformed members", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: [
                                       "\(GateFixture.mainVolume)/d999", "nonsense", "frus1861/d1",
                                       "/d1", "\(GateFixture.mainVolume)/"]),
                                   expectRows: false)
            try await assertParity(pipeline, "one member", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(
                                       documentIds: [GateFixture.key(GateFixture.mainVolume, 4)]))
            // A member written twice counts once.
            let twice = [GateFixture.key(GateFixture.mainVolume, 4), GateFixture.key(GateFixture.mainVolume, 4)]
            let once = try await pipeline.searchDocumentsCount(
                corpusMatch: "quillon", userContentMatch: nil,
                filters: SearchSQLFilters(documentIds: twice))
            #expect(once == 1, "a repeated member is one document")
            try await assertParity(pipeline, "a repeated member", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: twice))
            // 520 members: more than one of the key test's IN groups of 499.
            let bulk = (1...GateFixture.bulkCount).map { GateFixture.key(GateFixture.bulkVolume, $0) }
            try await assertParity(pipeline, "520 members", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: bulk))
            try await assertParity(pipeline, "520 members, dated", corpusMatch: "quillon",
                                   filters: SearchSQLFilters(documentIds: bulk,
                                                             dateRange: DateRange(earliest: "1953-03-01",
                                                                                  latest: "1953-06-30")))
        }
    }

    @Test("A browse with no words inside the gate lists and counts the same documents")
    func filterOnlyBrowseMatches() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            // A person's Find all mentions inside a working corpus: no MATCH, so the statement is
            // driven by `document_cache` and the gate tests `dc.rowid`.
            try await assertParity(pipeline, "a person browse", corpusMatch: nil,
                                   filters: SearchSQLFilters(documentIds: GateFixture.scatteredGate,
                                                             personRef: "p_acheson"))
            try await assertParity(pipeline, "a gate with front matter excluded and no words",
                                   corpusMatch: nil,
                                   filters: SearchSQLFilters(documentIds: GateFixture.scatteredGate,
                                                             includeFrontMatter: false))
            // The Meaning mode's filter key set reads the same clause.
            let keys = try await pipeline.documentKeysMatchingFilters(
                SearchSQLFilters(documentIds: GateFixture.scatteredGate,
                                 documentTypeFilter: .documentsOnly))
            // The preface is front matter, which is not an editorial note; d999 and "nonsense" are not
            // in the index.
            let expected = Set(GateFixture.scatteredGate.filter { key in
                if key == "\(GateFixture.mainVolume)/preface" { return true }
                guard key.hasPrefix("\(GateFixture.mainVolume)/d"),
                      let index = Int(key.dropFirst("\(GateFixture.mainVolume)/d".count)) else {
                    return key.hasPrefix("\(GateFixture.tieVolume)/") || key.hasPrefix("\(GateFixture.bulkVolume)/")
                }
                return index <= GateFixture.mainCount && !GateFixture.isNote(index)
            })
            #expect(keys == expected, "the gate's indexed documents, less its editorial notes")
        }
    }

    @Test("A facet match set inside the gate counts what the key test counted")
    func facetsMatch() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            for (label, filters) in [
                ("gate alone", SearchSQLFilters(documentIds: GateFixture.scatteredGate)),
                ("gate, documents only", SearchSQLFilters(documentIds: GateFixture.scatteredGate,
                                                          documentTypeFilter: .documentsOnly)),
                ("empty gate", SearchSQLFilters(documentIds: [])),
            ] {
                let facets = try await pipeline.resultSetFacets(
                    corpusMatch: "quillon", userContentMatch: "quillon", filters: filters, request: .all)
                let byKey = try await pipeline.resultSetFacetsJoinedMaterializationForTesting(
                    corpusMatch: "quillon", userContentMatch: "quillon", filters: filters, request: .all)
                #expect(facets == byKey, "\(label): facets diverged")
                if label != "empty gate" {
                    #expect(facets.matchCount > 0, "\(label): precondition, the facets count something")
                }
            }
        }
    }

    @Test("Inside a gate alone no matched row is looked up in document_cache")
    func thePlanDropsThePerMatchLookup() async throws {
        try await withGateTempDir { dir in
            let pipeline = try await GateFixture.makePipeline(in: dir)
            let gate = SearchSQLFilters(documentIds: GateFixture.scatteredGate)
            let lookup = "SEARCH dc USING INTEGER PRIMARY KEY"

            // The search: `document_cache` is read once a row, for the window that survives, and not
            // for every row the words match. The key test reads it in the ranking phase as well.
            let plan = try await pipeline.searchDocumentsPlanForTesting(
                corpusMatch: "quillon", userContentMatch: "quillon", filters: gate, limit: 1_000, offset: 0)
            let planByKey = try await pipeline.searchDocumentsPlanForTesting(
                corpusMatch: "quillon", userContentMatch: "quillon", filters: gate, limit: 1_000, offset: 0,
                gateByKeyForParity: true)
            #expect(planByKey.components(separatedBy: lookup).count - 1 == 2,
                    "control: the key test joins in the ranking phase and to hydrate the window — plan was: \(planByKey)")
            #expect(plan.components(separatedBy: lookup).count - 1 == 1,
                    "the rowid gate joins only to hydrate the window — plan was: \(plan)")
            // The gate is found through the primary key, not by reading the table.
            #expect(plan.contains("sqlite_autoindex_document_cache_1"),
                    "the gate's members are found through the primary key — plan was: \(plan)")
            #expect(!plan.components(separatedBy: " | ").contains { $0 == "SCAN gate" || $0.hasPrefix("SCAN gate ") },
                    "the gate does not scan document_cache — plan was: \(plan)")

            // The count reads no row of document_cache at all.
            let count = try await pipeline.searchDocumentsCountPlanForTesting(
                corpusMatch: "quillon", userContentMatch: "quillon", filters: gate)
            let countByKey = try await pipeline.searchDocumentsCountPlanForTesting(
                corpusMatch: "quillon", userContentMatch: "quillon", filters: gate, gateByKeyForParity: true)
            #expect(countByKey.contains(lookup), "control: the key test's count joins — plan was: \(countByKey)")
            #expect(!count.contains(lookup) && !count.contains("SCAN dc"),
                    "the rowid gate's count reads no document_cache row — plan was: \(count)")

            // With another filter the joins stay: a date reads `document_dates`.
            let dated = try await pipeline.searchDocumentsPlanForTesting(
                corpusMatch: "quillon", userContentMatch: nil,
                filters: SearchSQLFilters(documentIds: GateFixture.scatteredGate,
                                          dateRange: DateRange(earliest: "1952-01-01", latest: "1955-12-31")),
                limit: 1_000, offset: 0)
            #expect(dated.contains("SEARCH dd"), "a date filter still joins document_dates — plan was: \(dated)")
        }
    }
}
