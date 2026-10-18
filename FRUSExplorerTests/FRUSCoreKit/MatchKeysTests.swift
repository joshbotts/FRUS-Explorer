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
// SQLite3 is the system's on Apple platforms; on Linux the web edition supplies CSQLite.
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

// MARK: - Fixture

/// Three volumes, indexed, with summaries and tags on some documents: the whole match of a search is
/// read over them.
///
/// - `frus1951v01`: sixty documents whose bodies hold "quillon" one to four times; every third an
///   editorial note; dated across 1950–1959; every fifth also holds "zircaloy"; every seventh names a
///   person (`p_acheson`); and a preface that holds the word, front matter.
/// - `frus1952v02`: thirty documents, the even ones holding "quillon" in a phrase ("identical quillon").
/// - `frus1953v03`: 520 short documents that all hold "quillon", so that a match is larger than a
///   search's window, and a gate holds more than 499 members.
///
/// Every fourth main document has a summary that says "quillon", and every ninth one that says
/// "pellucid", a word no document's own text holds, so that a search of the summaries alone finds what
/// a search of the documents cannot. Every sixth main document carries a user tag.
private enum KeysFixture {

    static let mainVolume = "frus1951v01"
    static let phraseVolume = "frus1952v02"
    static let bulkVolume = "frus1953v03"
    static let mainCount = 60
    static let phraseCount = 30
    static let bulkCount = 520
    static let tagId = "5C1E0A0B-7E43-4C79-9A3D-2E8D0F6B9A10"

    static func key(_ volume: String, _ index: Int) -> String { "\(volume)/d\(index)" }

    private static func volume(_ volumeId: String, front: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date when="2010">2010</date></publicationStmt>
          <sourceDesc><p>Match keys fixture</p></sourceDesc></fileDesc></teiHeader>
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

    static func write(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let main = (1...mainCount).map { index -> String in
            let subtype = index.isMultiple(of: 3) ? "editorial-note" : "historical-document"
            let words = Array(repeating: "quillon", count: 1 + index % 4).joined(separator: " ")
            let rare = index.isMultiple(of: 5) ? " The zircaloy cladding was discussed." : ""
            let person = index.isMultiple(of: 7)
                ? " <persName corresp=\"#p_acheson\">Acheson</persName> attended." : ""
            let year = 1950 + index % 10
            return """
                  <div type="document" subtype="\(subtype)" n="\(index)" xml:id="d\(index)">
                    <head>\(index). Memorandum \(index)</head>
                    <dateline><date when="\(year)-0\(1 + index % 9)-15">\(year)</date></dateline>
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

        let phrases = (1...phraseCount).map { index in
            """
                  <div type="document" subtype="historical-document" n="\(index)" xml:id="d\(index)">
                    <head>\(index). Memo</head>
                    <dateline><date when="1952-03-01">March 1, 1952</date></dateline>
                    <p>\(index.isMultiple(of: 2) ? "Identical quillon text" : "Different text") for the record.</p>
                  </div>
            """
        }.joined(separator: "\n")
        try volume(phraseVolume, front: "", body: phrases)
            .write(to: dir.appendingPathComponent("\(phraseVolume).xml"), atomically: true, encoding: .utf8)

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

    /// Indexes the three volumes, then gives some documents a summary and some a user tag.
    static func makeService(in dir: URL) async throws -> (service: SearchService, pipeline: IndexingPipeline,
                                                          database: URL) {
        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        try write(to: dir.appendingPathComponent("volumes"))
        for volume in [mainVolume, phraseVolume, bulkVolume] {
            try await pipeline.indexVolume(volume)
        }
        for index in stride(from: 1, through: mainCount, by: 4) {
            try await pipeline.updateSummaryText(volumeId: mainVolume, documentId: "d\(index)",
                                                 responseText: "A summary that mentions quillon.")
        }
        for index in stride(from: 2, through: mainCount, by: 9) {
            try await pipeline.updateSummaryText(volumeId: mainVolume, documentId: "d\(index)",
                                                 responseText: "A pellucid summary.")
        }
        for index in stride(from: 1, through: mainCount, by: 6) {
            try await pipeline.updateUserTagIds(volumeId: mainVolume, documentId: "d\(index)", userTagIds: tagId)
        }
        return (SearchService(fts5Store: store, pipeline: pipeline), pipeline,
                dir.appendingPathComponent("test.sqlite"))
    }

    /// A gate scattered over all three volumes: every other main document, a third of the phrase
    /// volume and every third of the bulk volume (174 of its 520, so the gate holds more than 499
    /// members), with the preface, a member the index does not hold, a member written twice and one
    /// with no `/`.
    static var gate: [String] {
        var gate = stride(from: 1, through: mainCount, by: 2).map { key(mainVolume, $0) }
        gate += stride(from: 1, through: phraseCount, by: 3).map { key(phraseVolume, $0) }
        gate += stride(from: 1, through: bulkCount, by: 3).map { key(bulkVolume, $0) }
        gate += ["\(mainVolume)/preface", "\(mainVolume)/d999", key(mainVolume, 9), "nonsense"]
        return gate
    }

    /// The words of the searches the suite asks about: a word, a rare word, a phrase, a prefix, an
    /// `OR`, an exclusion, `NEAR`, an `=exact` word, and a word only the summaries hold.
    static let words = ["quillon", "zircaloy", "\"identical quillon\"", "quill*", "zircaloy OR pellucid",
                        "quillon -zircaloy", "NEAR(quillon record, 8)", "=quillon", "pellucid"]

    /// The three match scopes: the documents' own text, the reader's summaries and notes, and both.
    static func scoped(_ parameters: SearchParameters) -> [(String, SearchParameters)] {
        var documents = parameters
        documents.includeSummaries = false
        documents.includeNotes = false
        var userContent = parameters
        userContent.includeDocumentText = false
        return [("documents", documents), ("summaries and notes", userContent), ("both", parameters)]
    }

    /// Every filter the search applies, alone and beside the gate.
    static var filterShapes: [(String, SearchParameters)] {
        [
            ("no filter", SearchParameters()),
            ("a gate alone", SearchParameters(documentIds: gate)),
            ("an empty gate", SearchParameters(documentIds: [])),
            ("a gate and a date range",
             SearchParameters(dateRange: DateRange(earliest: "1952-01-01", latest: "1955-12-31"), documentIds: gate)),
            ("one volume", SearchParameters(volumeIds: [mainVolume])),
            ("a date range", SearchParameters(dateRange: DateRange(earliest: "1951-01-01", latest: "1953-06-30"))),
            ("two years", SearchParameters(yearKeys: ["1951", "1953"])),
            ("no front matter", SearchParameters(includeFrontMatter: false)),
            ("documents only", SearchParameters(documentTypeFilter: .documentsOnly)),
            ("editorial notes only", SearchParameters(documentTypeFilter: .editorialNotesOnly)),
            ("a person", SearchParameters(personRef: "p_acheson")),
            ("a subject area", SearchParameters(subjectBucket: 3)),
            ("a tag", SearchParameters(userTagIds: [tagId])),
            ("excluded documents",
             SearchParameters(excludeDocumentIds: [key(mainVolume, 1), key(bulkVolume, 2)])),
            ("a gate, a volume and no front matter",
             SearchParameters(volumeIds: [mainVolume, bulkVolume], documentIds: gate, includeFrontMatter: false)),
        ]
    }

    /// Every search the suite asks about: each of ``words`` in each scope under each filter shape.
    static var searches: [(label: String, parameters: SearchParameters)] {
        var searches: [(String, SearchParameters)] = []
        for word in words {
            for (filterLabel, filters) in filterShapes {
                var parameters = filters
                parameters.keywords = word
                for (scopeLabel, scoped) in scoped(parameters) {
                    searches.append(("\(word), \(filterLabel), \(scopeLabel)", scoped))
                }
            }
        }
        return searches
    }

    /// The browses with no words: a person's mentions, alone and inside the gate, and with the front
    /// matter left out.
    static let browses: [(label: String, parameters: SearchParameters)] = [
        ("a person", SearchParameters(personRef: "p_acheson")),
        ("a person inside the gate", SearchParameters(documentIds: gate, personRef: "p_acheson")),
        ("a person, documents only", SearchParameters(documentTypeFilter: .documentsOnly, personRef: "p_acheson")),
        ("a person, no front matter, a date range",
         SearchParameters(dateRange: DateRange(earliest: "1950-01-01", latest: "1954-12-31"),
                          personRef: "p_acheson", includeFrontMatter: false)),
    ]
}

/// What a search answers: its keys or the error it threw.
private struct KeysAnswer: Equatable {
    var keys: Set<String> = []
    var keyCount = 0
    var count: Int?
    var error: String?
}

/// Counts the calls of the pipeline's statement hook, from whichever thread the statement runs on.
private final class StatementMoments: @unchecked Sendable {
    private let lock = NSLock()
    private var prepared = 0
    private var ranToItsEnd = 0

    /// Counts one moment.
    func record(_ moment: SearchStatementMoment) {
        lock.lock()
        switch moment {
        case .prepared: prepared += 1
        case .ranToItsEnd: ranToItsEnd += 1
        }
        lock.unlock()
    }

    /// The moments counted so far.
    var counts: (prepared: Int, ranToItsEnd: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (prepared, ranToItsEnd)
    }
}

// MARK: - MatchKeysTests

/// `SearchService.matchKeys(parameters:)` (#1577 lane 6): the key of every document a search matches,
/// which Search Within These Results ranks by a question when the list on screen was cut at its ceiling.
///
/// ## What is pinned
/// - The keys are as many as `searchCount` says, each once, for every match scope (the documents, the
///   summaries and notes, both), every query shape (a word, a phrase, a prefix, `OR`, an exclusion,
///   `NEAR`, `=exact`) and every filter the search applies, a document gate among them.
/// - They are the documents the search lists: the same set when the search's window holds the whole
///   match, and a superset of its window when it does not.
/// - A browse with no words lists what its filters admit, as the browse does.
/// - An index opened read-only and immutable, as the web edition opens one, answers with the same keys.
/// - The plan: under every filter but a user tag or an exact word, `document_cache` is read only through
///   an index, and no matched row is looked up in the table, which is what made the keys of a common word
///   cost 6.4 s cold on a full index; under those two, each matched row is joined, as the count joins it.
/// - The edges: an empty gate, a search with nothing to run, and a cancelled task.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
@Suite("The whole match: matchKeys lists every document a search matches")
struct MatchKeysTests {

    /// A temporary directory for `body`, removed after it.
    private func withKeysTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("match-keys-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// What `service` answers for `parameters`: the keys, as a set and a count, and the search's count.
    private func answer(_ service: SearchService, _ parameters: SearchParameters) async -> KeysAnswer {
        var answer = KeysAnswer()
        do {
            let keys = try await service.matchKeys(parameters: parameters)
            answer.keys = Set(keys)
            answer.keyCount = keys.count
            answer.count = try await service.searchCount(parameters: parameters)
        } catch {
            answer.error = String(describing: error)
        }
        return answer
    }

    @Test("The keys are as many as the count, each once, for every match scope, query shape and filter, =exact included")
    func theKeysAreAsManyAsTheCount() async throws {
        try await withKeysTempDir { dir in
            let (service, _, _) = try await KeysFixture.makeService(in: dir)
            var matched = 0
            var shapesWithKeys: Set<String> = []
            for (label, parameters) in KeysFixture.searches {
                let keys = try await service.matchKeys(parameters: parameters)
                let count = try await service.searchCount(parameters: parameters)
                #expect(keys.count == count, "\(label): \(keys.count) keys where the count is \(count)")
                #expect(Set(keys).count == keys.count, "\(label): a key is listed twice")
                if count > 0 {
                    matched += 1
                    shapesWithKeys.insert(String(label.split(separator: ",").last ?? ""))
                }
            }
            // Anti-vacuity: most of the searches match something, in each of the three scopes.
            #expect(matched > KeysFixture.searches.count / 3,
                    "fixture guard: only \(matched) of \(KeysFixture.searches.count) searches matched anything")
            #expect(shapesWithKeys == [" documents", " summaries and notes", " both"],
                    "fixture guard: every scope matches somewhere, not \(shapesWithKeys)")
            // The largest is larger than a search's 500-row window below, and an exclusion and =exact
            // each narrow it.
            let whole = try await service.searchCount(parameters: SearchParameters(keywords: "quillon"))
            #expect(whole > 500, "fixture guard: the whole match of quillon is \(whole)")
            #expect(try await service.searchCount(parameters: SearchParameters(keywords: "quillon -zircaloy")) < whole)
        }
    }

    @Test("The keys are the documents the search lists: all of them inside its window, and more beyond it")
    func theKeysAreTheSearchsDocuments() async throws {
        try await withKeysTempDir { dir in
            let (service, _, _) = try await KeysFixture.makeService(in: dir)
            var cut = 0
            for (label, parameters) in KeysFixture.searches {
                let keys = Set(try await service.matchKeys(parameters: parameters))
                let all = try await service.search(parameters: parameters, limit: 10_000)
                #expect(Set(all.map(\.id)) == keys, "\(label): the keys are not the search's documents")
                let window = try await service.search(parameters: parameters, limit: 500)
                #expect(Set(window.map(\.id)).isSubset(of: keys), "\(label): a row of the window is not a key")
                if keys.count > window.count { cut += 1 }
            }
            #expect(cut > 0, "fixture guard: no search was larger than its window")
        }
    }

    @Test("A browse with no words lists the documents its filters admit")
    func aBrowseListsWhatItsFiltersAdmit() async throws {
        try await withKeysTempDir { dir in
            let (service, pipeline, _) = try await KeysFixture.makeService(in: dir)
            for (label, parameters) in KeysFixture.browses {
                let keys = try await service.matchKeys(parameters: parameters)
                let count = try await service.searchCount(parameters: parameters)
                let listed = try await service.search(parameters: parameters, limit: 10_000)
                #expect(count > 0, "\(label): fixture guard, the browse lists something")
                #expect(keys.count == count, "\(label): \(keys.count) keys where the count is \(count)")
                #expect(Set(keys) == Set(listed.map(\.id)), "\(label): the keys are not the browse's documents")
            }
            // A person's mentions are every seventh main document.
            let person = Set(try await service.matchKeys(parameters: SearchParameters(personRef: "p_acheson")))
            #expect(person == Set(stride(from: 7, through: KeysFixture.mainCount, by: 7)
                .map { KeysFixture.key(KeysFixture.mainVolume, $0) }))
            // With no words and no filter there is nothing to run: the pipeline lists nothing, and the
            // service refuses the search, as `search` does.
            #expect(try await pipeline.documentKeysMatching(corpusMatch: nil, userContentMatch: nil,
                                                            filters: SearchSQLFilters()).isEmpty)
            await #expect(throws: FTS5Error.self) { try await service.matchKeys(parameters: SearchParameters()) }
            await #expect(throws: FTS5Error.self) { _ = try await service.search(parameters: SearchParameters()) }
        }
    }

    @Test("An empty gate matches nothing, a gate's members the index lacks match nothing, and a member written twice is one key")
    func theGatesEdges() async throws {
        try await withKeysTempDir { dir in
            let (service, _, _) = try await KeysFixture.makeService(in: dir)
            #expect(try await service.matchKeys(parameters: SearchParameters(keywords: "quillon", documentIds: [])).isEmpty)
            #expect(try await service.matchKeys(parameters: SearchParameters(
                keywords: "quillon", documentIds: ["\(KeysFixture.mainVolume)/d999", "nonsense", "/d1"])).isEmpty)
            let twice = [KeysFixture.key(KeysFixture.mainVolume, 4), KeysFixture.key(KeysFixture.mainVolume, 4)]
            #expect(try await service.matchKeys(parameters: SearchParameters(keywords: "quillon", documentIds: twice))
                    == [KeysFixture.key(KeysFixture.mainVolume, 4)])
        }
    }

    @Test("An index opened read-only and immutable answers with the same keys")
    func aReadOnlyIndexAnswersTheSame() async throws {
        try await withKeysTempDir { dir in
            let (service, _, database) = try await KeysFixture.makeService(in: dir)
            let all = KeysFixture.searches + KeysFixture.browses
            var written: [KeysAnswer] = []
            for (_, parameters) in all { written.append(await answer(service, parameters)) }
            #expect(written.contains { !$0.keys.isEmpty }, "fixture guard: the index answers with keys")

            let copy = try exportCopy(of: database, in: dir)
            let store = try FTS5Store(readingDatabaseAt: copy)
            let pipeline = try IndexingPipeline(readingIndexAt: copy, fts5Store: store, resources: .none,
                                                volumesDirectory: dir.appendingPathComponent("volumes"))
            #expect(pipeline.isReadOnly)
            let readOnly = SearchService(fts5Store: store, pipeline: pipeline)
            for (index, search) in all.enumerated() {
                let read = await answer(readOnly, search.parameters)
                #expect(read == written[index], "\(search.label): the read-only index answered otherwise")
            }
        }
    }

    /// Whether `plan` reads `document_cache` only through an index that holds what the statement needs of
    /// it: never a lookup of a row by its rowid, and never a scan of the table itself.
    private func readsTheTableThroughAnIndex(_ plan: String) -> Bool {
        let steps = plan.components(separatedBy: " | ").filter { $0.hasPrefix("SCAN dc") || $0.hasPrefix("SEARCH dc") }
        return !steps.isEmpty && steps.allSatisfy { $0.contains("USING COVERING INDEX") }
    }

    @Test("Under every filter but a tag or an exact word the keys are read from an index, and no matched row from the table")
    func thePlanReadsAnIndex() async throws {
        try await withKeysTempDir { dir in
            let (service, pipeline, _) = try await KeysFixture.makeService(in: dir)
            let indexed: [(String, SearchSQLFilters)] = [
                ("no filter", SearchSQLFilters()),
                ("a gate alone", SearchSQLFilters(documentIds: KeysFixture.gate)),
                ("an empty gate", SearchSQLFilters(documentIds: [])),
                ("a date range", SearchSQLFilters(dateRange: DateRange(earliest: "1952-01-01", latest: "1955-12-31"))),
                ("two years", SearchSQLFilters(yearKeys: ["1951", "1953"])),
                ("one volume", SearchSQLFilters(volumeIds: [KeysFixture.mainVolume])),
                ("no front matter", SearchSQLFilters(includeFrontMatter: false)),
                ("documents only", SearchSQLFilters(documentTypeFilter: .documentsOnly)),
                ("a person", SearchSQLFilters(personRef: "p_acheson")),
                ("a subject area", SearchSQLFilters(subjectBucket: 3)),
                ("excluded documents", SearchSQLFilters(excludeDocumentIds: [KeysFixture.key(KeysFixture.mainVolume, 1)])),
                ("a gate, a volume and a date range",
                 SearchSQLFilters(volumeIds: [KeysFixture.mainVolume], documentIds: KeysFixture.gate,
                                  dateRange: DateRange(earliest: "1952-01-01", latest: "1955-12-31"))),
            ]
            for (label, filters) in indexed {
                for (match, user) in [("quillon", nil), (nil, "quillon"), ("quillon", "quillon")] as [(String?, String?)] {
                    let plan = try await pipeline.documentKeysMatchingPlanForTesting(
                        corpusMatch: match, userContentMatch: user, filters: filters)
                    #expect(readsTheTableThroughAnIndex(plan),
                            "\(label): document_cache is read only through an index — plan was: \(plan)")
                }
            }
            // With no filter the whole index is scanned, the match's rowids tested against it.
            let unfiltered = try await pipeline.documentKeysMatchingPlanForTesting(
                corpusMatch: "quillon", userContentMatch: nil, filters: SearchSQLFilters())
            #expect(unfiltered.contains("SCAN dc USING COVERING INDEX"), "plan was: \(unfiltered)")

            // A tag or an exact word reads a column no index holds: each matched row is joined, as the count
            // joins it, and the table is never scanned.
            let lookup = "SEARCH dc USING INTEGER PRIMARY KEY"
            for (label, filters) in [
                ("a tag", SearchSQLFilters(userTagIds: [KeysFixture.tagId])),
                ("an exact word", SearchSQLFilters(exactTerms: ["quillon"],
                                                   exactColumns: ["header", "dateline", "source_note", "body_text"])),
            ] {
                let plan = try await pipeline.documentKeysMatchingPlanForTesting(
                    corpusMatch: "quillon", userContentMatch: nil, filters: filters)
                #expect(plan.contains(lookup) && !plan.components(separatedBy: " | ").contains("SCAN dc"),
                        "\(label): each matched row is joined — plan was: \(plan)")
            }
            // And the statements the plans are of are the ones that run: the same keys as the count.
            for parameters in [SearchParameters(keywords: "quillon", documentIds: KeysFixture.gate),
                               SearchParameters(keywords: "quillon", userTagIds: [KeysFixture.tagId]),
                               SearchParameters(keywords: "=quillon", dateRange: DateRange(earliest: "1952-01-01",
                                                                                           latest: "1955-12-31"))] {
                #expect(try await service.matchKeys(parameters: parameters).count
                        == (try await service.searchCount(parameters: parameters)))
            }
        }
    }

    @Test("A cancelled task gets no keys: refused before the statement, or stopped while it runs")
    func aCancelledTaskGetsNoKeys() async throws {
        try await withKeysTempDir { dir in
            let (service, pipeline, _) = try await KeysFixture.makeService(in: dir)
            let quillon = SearchParameters(keywords: "quillon")
            // Anti-vacuity: uncancelled, the statement answers and runs to its end.
            let moments = StatementMoments()
            await pipeline.setSearchStatementTestHook { moments.record($0) }
            #expect(try await service.matchKeys(parameters: quillon).count > 500)
            #expect(moments.counts.prepared == 1 && moments.counts.ranToItsEnd == 1)

            // Cancelled before the call: no statement is prepared.
            let early = Task { () async throws -> [String] in
                withUnsafeCurrentTask { $0?.cancel() }
                return try await service.matchKeys(parameters: quillon)
            }
            await #expect(throws: CancellationError.self) { try await early.value }
            #expect(moments.counts.prepared == 1, "a statement was prepared for a task already cancelled")

            // Cancelled once the statement is prepared: the progress handler stops it before its end.
            await pipeline.setSearchStatementTestHook { moment in
                moments.record(moment)
                if moment == .prepared { withUnsafeCurrentTask { $0?.cancel() } }
            }
            let late = Task { () async throws -> [String] in try await service.matchKeys(parameters: quillon) }
            await #expect(throws: CancellationError.self) { try await late.value }
            #expect(moments.counts.prepared == 2, "fixture guard: the statement was prepared")
            #expect(moments.counts.ranToItsEnd == 1, "the statement whose task was cancelled ran to its end")

            // The connection is left as it was.
            await pipeline.setSearchStatementTestHook(nil)
            #expect(try await service.matchKeys(parameters: quillon).count
                    == (try await service.searchCount(parameters: quillon)))
        }
    }

    /// Copies the index at `built` page for page with SQLite's backup API into a folder of its own and
    /// takes the copy out of write-ahead-log mode, as an export is made. Returns the copy, alone in its
    /// folder.
    private func exportCopy(of built: URL, in dir: URL) throws -> URL {
        let served = dir.appendingPathComponent("served", isDirectory: true)
        try FileManager.default.createDirectory(at: served, withIntermediateDirectories: true)
        let database = served.appendingPathComponent("frus.db")
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(database.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: served.appendingPathComponent("frus.db-shm"))
        return database
    }
}
