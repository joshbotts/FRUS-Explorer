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

// MARK: - QueryMethodAppendixTests

/// The appendix's one non-negotiable property: **a floor never renders as a total.**
///
/// Everything else here supports that. A methods section whose counts cannot be trusted is worse
/// than no methods section, because it invites a reader to check an assertion against a number that
/// was never a measurement.
///
/// Version history:
///   1.0 — M-2 commit 3: initial implementation
@Suite("Query method appendix")
struct QueryMethodAppendixTests {

    /// A search that hit the ceiling: 7,500 loaded against a 7,500 limit, with no total recorded.
    private func cappedSearch(query: String = "petroleum") -> SearchHistoryEntry {
        SearchHistoryEntry(queryText: query, resultCount: 7_500, executedAt: Date(timeIntervalSince1970: 100),
                           loadedCount: 7_500, fetchLimit: 7_500, indexedVolumeCount: 552,
                           scopeSignature: SearchScopeSignature.signature(for: SearchParameters(keywords: query)))
    }

    /// A search whose true total was counted: 41 matches, all 41 loaded.
    private func countedSearch(query: String = "tanganyika") -> SearchHistoryEntry {
        SearchHistoryEntry(queryText: query, resultCount: 41, executedAt: Date(timeIntervalSince1970: 200),
                           loadedCount: 41, matchCount: 41, fetchLimit: 7_500, indexedVolumeCount: 552,
                           scopeSignature: SearchScopeSignature.signature(for: SearchParameters(keywords: query)))
    }

    /// A row written before M-2 — a headline number and nothing else.
    private func legacySearch(query: String = "ambassador") -> SearchHistoryEntry {
        SearchHistoryEntry(queryText: query, resultCount: 1_000, executedAt: Date(timeIntervalSince1970: 50))
    }

    private func appendix(_ searches: [SearchHistoryEntry],
                          corpusNames: [UUID: String] = [:],
                          projectName: String? = nil,
                          researchQuestion: String? = nil) -> QueryMethodAppendix {
        QueryMethodAppendix.make(searches: searches, corpusNames: corpusNames,
                                 projectName: projectName, researchQuestion: researchQuestion,
                                 generatedAt: Date(timeIntervalSince1970: 1_000))
    }

    // MARK: - A floor is not a total

    @Test("A capped search renders as a floor, never as a bare number")
    func floorIsNotATotal() {
        let markdown = appendix([cappedSearch()]).markdown
        #expect(markdown.contains("at least \(7_500.formatted())"),
                "a ceiling-capped fetch is a lower bound and has to say so")
        // The anti-vacuity half: the bare number must not appear as the whole cell. A cell reading
        // "| 7,500 |" is the defect — the phrase above contains the digits, so asserting only on
        // the digits would pass either way.
        #expect(!markdown.contains("| \(7_500.formatted()) |"))
    }

    @Test("A counted search renders its match count, not what was loaded")
    func exactRendersTheMatch() {
        // 41 of 41: the two happen to agree here. The case that matters is where they do not —
        // a total of 12,884 fetched down to 7,500 must print 12,884.
        let wide = SearchHistoryEntry(queryText: "trade", resultCount: 12_884,
                                      loadedCount: 7_500, matchCount: 12_884, fetchLimit: 7_500)
        let markdown = appendix([wide]).markdown
        #expect(markdown.contains(12_884.formatted()))
        #expect(!markdown.contains("at least"), "a counted total is not a floor")
        #expect(!markdown.contains("| \(7_500.formatted()) |"),
                "the fetch size is not the answer and must not appear as one")
    }

    @Test("A complete fetch renders bare")
    func completeRendersBare() {
        let markdown = appendix([countedSearch()]).markdown
        #expect(markdown.contains("| 41 |"))
        #expect(!markdown.contains("at least"))
    }

    @Test("A pre-M-2 row is printed but marked")
    func legacyRowIsMarked() {
        let markdown = appendix([legacySearch()]).markdown
        #expect(markdown.contains("ambassador"), "dropping the row would silently shorten the log")
        #expect(markdown.contains("as reported"))
        #expect(markdown.contains("not recorded"), "it recorded no scope and must not be given one")
    }

    // MARK: - The CSV keeps the distinction a spreadsheet would erase

    @Test("count_basis discriminates, and a floor writes no match_count")
    func csvSeparatesFloorsFromTotals() {
        let csv = appendix([legacySearch(), cappedSearch(), countedSearch()]).csv
        let rows = csv.split(separator: "\n").filter { !$0.hasPrefix("#") }
        #expect(rows.count == 4, "header plus three rows, got \(rows.count)")

        let byBasis = Dictionary(uniqueKeysWithValues: ["unrecorded", "floor", "exact"].compactMap { basis in
            rows.first { $0.contains(",\(basis),") }.map { (basis, String($0)) }
        })
        #expect(byBasis.count == 3, "each row must carry a distinct basis token")

        // The floor row: loaded and limit, but the match column empty. A `7500` there is exactly
        // what a reader summing `match_count` would turn into a false total.
        let floor = byBasis["floor"] ?? ""
        #expect(floor.contains("floor,,7500,7500,"),
                "expected empty match_count between the basis and the loaded count: \(floor)")

        // The legacy row: only the reported number, and no denominator invented for it.
        let legacy = byBasis["unrecorded"] ?? ""
        #expect(legacy.contains("unrecorded,,,,1000,,"),
                "expected match/loaded/limit empty and reported=1000: \(legacy)")
    }

    @Test("Query text survives quotes, commas and pipes")
    func escaping() {
        let awkward = SearchHistoryEntry(queryText: #"oil, "gas" | coal"#, resultCount: 3,
                                         loadedCount: 3, matchCount: 3, fetchLimit: 1_000)
        let built = appendix([awkward])

        // CSV: one field, so the row still has the column count the header promises.
        let csv = built.csv
        let dataRow = csv.split(separator: "\n").first { !$0.hasPrefix("#") && !$0.hasPrefix("executed_at") }
        #expect(dataRow?.contains(#""oil, ""gas"" | coal""#) == true, "got: \(dataRow ?? "none")")

        // Markdown: the pipe is escaped, or it splits the row into extra cells.
        #expect(built.markdown.contains(#"oil, "gas" \| coal"#))
    }

    // MARK: - Caveats describe this log, not every possible log

    @Test("The floor caveat appears only when a floor row does")
    func floorCaveatIsConditional() {
        #expect(!appendix([countedSearch()]).markdown.contains("row ceiling"))
        #expect(appendix([cappedSearch()]).markdown.contains("row ceiling"))
    }

    @Test("The legacy caveat appears only when a legacy row does")
    func legacyCaveatIsConditional() {
        #expect(!appendix([countedSearch()]).markdown.contains("this app version"))
        // One legacy row, so the singular form — the plural spelling would read "1 searches".
        #expect(appendix([legacySearch()]).markdown.contains("One search predates this app version"))
    }

    @Test("The zero caveat appears only when a zero row does")
    func zeroCaveatIsConditional() {
        #expect(!appendix([countedSearch()]).markdown.contains("A zero is a finding"))
    }

    @Test("Zero-result searches are counted and named")
    func zerosAreCounted() {
        let nothing = SearchHistoryEntry(queryText: "chryselephantine", resultCount: 0,
                                         loadedCount: 0, matchCount: 0, fetchLimit: 7_500)
        let built = appendix([nothing, countedSearch()])
        #expect(built.zeroResultRowCount == 1)
        #expect(built.markdown.contains("One of these searches returned nothing"))
        // Plural agreement is spelled out, not interpolated — "1 searches" in a methods section
        // undercuts the document's whole claim to care.
        #expect(!built.markdown.contains("1 of these searches"))
    }

    // MARK: - Ordering and header

    @Test("Rows run oldest first, with undated rows last")
    func ordering() {
        let undated = SearchHistoryEntry(queryText: "migrated", resultCount: 5)
        undated.executedAt = nil
        let rows = appendix([countedSearch(), undated, legacySearch()]).rows
        #expect(rows.map(\.queryText) == ["ambassador", "tanganyika", "migrated"])
    }

    @Test("The project heads the appendix in both formats")
    func projectHeader() {
        let built = appendix([countedSearch()], projectName: "Suez",
                             researchQuestion: "Who knew what, and when?")
        #expect(built.markdown.contains("Suez"))
        #expect(built.markdown.contains("Who knew what, and when?"))
        // The CSV carries it too — the two files travel separately and each must stand alone.
        #expect(built.csv.contains("# Project: Suez"))
    }

    @Test("A working corpus is named in the scope cell")
    func corpusIsNamed() {
        let id = UUID()
        let inCorpus = SearchHistoryEntry(queryText: "minerals", resultCount: 12,
                                          loadedCount: 12, matchCount: 12, fetchLimit: 7_500,
                                          scopeSignature: SearchScopeSignature.signature(
                                            for: SearchParameters(keywords: "minerals")),
                                          appliedCorpusId: id)
        #expect(appendix([inCorpus], corpusNames: [id: "planning"]).markdown.contains("planning"))
        // A corpus deleted since the search: the row still prints, without inventing a name.
        #expect(!appendix([inCorpus]).markdown.contains("planning"))
    }
}

// MARK: - SearchScopeSignatureDecodingTests

/// The decoder `SearchScopeSignature`'s overview promised and M-2 commit 3 supplied.
///
/// Version history:
///   1.0 — M-2 commit 3: initial implementation
@Suite("Scope signature decoding")
struct SearchScopeSignatureDecodingTests {

    private func describe(_ parameters: SearchParameters) -> [String] {
        let signature = SearchScopeSignature.signature(for: parameters)
        guard let phrases = SearchScopeSignature.describe(signature) else {
            Issue.record("a signature this type wrote failed to decode: \(signature)")
            return []
        }
        return phrases
    }

    @Test("A default search states which fields it searched")
    func defaultScope() {
        let phrases = describe(SearchParameters(keywords: "oil"))
        #expect(phrases.contains { $0.contains("document text") })
        // Nothing was narrowed, so nothing else should be claimed.
        #expect(phrases.count == 1, "got \(phrases)")
    }

    @Test("A volume list is described by its size, not its digest")
    func volumeCount() {
        let scoped = SearchParameters(keywords: "oil", volumeIds: ["a", "b", "c"])
        #expect(describe(scoped).contains { $0.contains("3") && $0.contains("volume") })
        // The digest must not leak into prose — it is a comparison key, not a description.
        #expect(!describe(scoped).contains { $0.contains("/") })
    }

    /// The distinction the signature is careful to preserve has to survive the decoder too: `nil`
    /// is no constraint, `[]` is a scope that matches nothing.
    @Test("An empty document list is described; an absent one is not")
    func emptyIsNotNone() {
        let absent = describe(SearchParameters(keywords: "oil"))
        let empty = describe(SearchParameters(keywords: "oil", documentIds: []))
        #expect(!absent.contains { $0.contains("document") && $0.contains("selected") })
        #expect(empty.contains { $0.contains("no documents selected") })
    }

    @Test("Boolean mode, date range and document type are described")
    func narrowings() {
        var parameters = SearchParameters(keywords: "oil")
        parameters.booleanMode = .or
        parameters.dateRange = DateRange(earliest: "1949-01-01", latest: "1952-12-31")
        parameters.documentTypeFilter = .editorialNotesOnly
        let phrases = describe(parameters)
        #expect(phrases.contains { $0.contains("any term") })
        #expect(phrases.contains { $0.contains("1949-01-01") })
        #expect(phrases.contains { $0.contains("editorial") })
    }

    @Test("A string this type did not write does not decode")
    func refusesForeignInput() {
        #expect(SearchScopeSignature.describe("") == nil)
        #expect(SearchScopeSignature.describe("just some words") == nil)
        // Well-formed pairs but not a signature — no `mode`, so it must not be paraphrased.
        #expect(SearchScopeSignature.describe("colour=blue;size=3") == nil)
    }

    @Test("A search with fields switched off says so rather than staying silent")
    func noFields() {
        var parameters = SearchParameters(keywords: "oil")
        parameters.includeDocumentText = false
        parameters.includeSummaries = false
        parameters.includeNotes = false
        parameters.includeFrontMatter = false
        #expect(describe(parameters).contains { $0.contains("no fields searched") })
    }
}
