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

import Testing
import Foundation
@testable import FRUSExplorer

/// The Query Inspector's model: what it claims about a query, against a real index (Q-2a).
///
/// Every claim here is one a researcher may copy into a method appendix, so each is tested
/// against a real pipeline rather than a stub. The inspector's whole value is that its
/// numbers are the search's numbers; a mocked count would prove nothing.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
@Suite("Query inspection")
struct QueryInspectionTests {

    // MARK: - Fixture

    /// d1 carries *containment* and *europe*; d2 carries *contain*; d3 carries *europe*
    /// alone. Nothing anywhere carries *formosa* — the empty conjunct.
    private func makeVolumeXML() -> String {
        """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum</head>
          <p>The doctrine of containment shaped policy toward europe.</p>
        </div>
        <div type="document" xml:id="d2">
          <head>2. Telegram</head>
          <p>We must contain the threat.</p>
        </div>
        <div type="document" xml:id="d3">
          <head>3. Report</head>
          <p>Economic recovery in europe proceeded.</p>
        </div>
        <div type="document" xml:id="d4">
          <head>4. Alliance Politics</head>
          <p>The atlantic alliance and its alliances were debated.</p>
        </div>
        </body></text></TEI>
        """
    }

    private func makeFixture() async throws -> (dir: URL, inspector: QueryInspector) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSInspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML().data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)
        return (dir, QueryInspector(fts5Store: fts5, searchService: service))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - The expression

    @Test("The inspector shows the expression the search actually executed")
    func expressionIsTheExecutedOne() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment europe"), indexedVolumeCount: 1)
        let displayed = try #require(inspection.expression?.displayed)
        #expect(displayed == "\"containment\" AND \"europe\"")
    }

    /// The mock in the design bundle shows a `{header dateline source_note body_text}:`
    /// prefix. The app cannot emit that — the corpus expression renders with `columns: nil`
    /// — and displaying it would make the expression non-reproducible.
    @Test("No column prefix is synthesized onto the corpus expression")
    func noSynthesizedColumnPrefix() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment"), indexedVolumeCount: 1)
        let displayed = try #require(inspection.expression?.displayed)
        #expect(!displayed.contains("{"), "a prefix the engine never saw: \(displayed)")
    }

    @Test("Under shipped defaults the two expressions are identical, and say so")
    func expressionsAgreeUnderDefaults() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment"), indexedVolumeCount: 1)
        let expression = try #require(inspection.expression)
        #expect(expression.corpus != nil && expression.userContent != nil)
        #expect(!expression.expressionsDiffer)
    }

    @Test("With only summaries in scope the expressions diverge, and that is reported")
    func expressionsDivergeWhenScopeSplits() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        var params = SearchParameters(keywords: "containment")
        params.includeSummaries = true
        params.includeNotes = false
        let expression = try #require(await inspector.inspect(
            parameters: params, indexedVolumeCount: 1).expression)
        #expect(expression.expressionsDiffer,
                "a summary-only scope column-prefixes the user-content expression")
        #expect(expression.userContent?.contains("{summary_text}") == true)
    }

    /// A person-only query has no FTS terms at all — `makeMatchExpressions` returns
    /// `(nil, nil)` and the search runs filter-only. Saying so beats an empty strip.
    @Test("A filter-only query reports itself rather than showing an empty expression")
    func filterOnlyQueryIsLabelled() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        var params = SearchParameters(keywords: nil)
        params.personRef = "#p-acheson"
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        #expect(inspection.expression == nil)
        #expect(inspection.isFilterOnly)
        #expect(!inspection.hasOperands)
    }

    // MARK: - Operands and stems

    @Test("Each operand is described, in the order typed")
    func operandsInOrder() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment \"cold war\" negoti*"),
            indexedVolumeCount: 1)
        #expect(inspection.operands.map(\.operand.text) == ["containment", "cold war", "negoti*"])
        #expect(inspection.operands.map(\.operand.kind) == [.word, .phrase, .prefix])
    }

    @Test("The stem shown names the real index term")
    func stemNamesTheIndexTerm() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment"), indexedVolumeCount: 1)
        let first = try #require(inspection.operands.first)
        #expect(first.stem == "contain")
        #expect(first.isStemBroadening, "containment → contain is the trap worth flagging")
    }

    /// The claim Q-3a exists to support, tested on the word that actually discriminates.
    ///
    /// `containment` stems to `contain` in *both* implementations, so it cannot tell them
    /// apart — an earlier version of this test used it and passed while the inspector was
    /// mutated to use `PorterStemmer`. `alliance` is the case: Swift says `alli`, SQLite
    /// says `allianc`, and only the latter is a term the index contains.
    @Test("The stem is SQLite's, not PorterStemmer's, where the two disagree")
    func stemIsSQLitesNotSwifts() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        // Guard the premise: if either stemmer ever changed, this test would quietly stop
        // discriminating rather than fail.
        #expect(PorterStemmer.stem("alliance") == "alli",
                "the Swift stem for alliance changed — pick a new discriminating word")

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "alliance"), indexedVolumeCount: 1)
        let first = try #require(inspection.operands.first)
        #expect(first.stem == "allianc",
                "the inspector must report SQLite's stem, not PorterStemmer's `alli`")
        #expect(first.corpusDocumentFrequency == 1,
                "and that stem must resolve in the vocabulary — `alli` would return nothing")
    }

    @Test("A word the tokenizer leaves alone is not flagged as broadening")
    func unbroadenedWordIsNotFlagged() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        // "contain" is already its own stem, so nothing was silently widened.
        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "contain"), indexedVolumeCount: 1)
        let first = try #require(inspection.operands.first)
        #expect(first.stem == "contain")
        #expect(!first.isStemBroadening)
    }

    @Test("Phrases, prefixes and NEAR carry no stem — one would be a lie of convenience")
    func onlyWordsHaveStems() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "\"cold war\" negoti* NEAR(a b, 5)"),
            indexedVolumeCount: 1)
        for item in inspection.operands where item.operand.kind != .word {
            #expect(item.stem == nil, "\(item.operand.text) should carry no stem")
            #expect(!item.isStemBroadening)
        }
    }

    // MARK: - The two counts

    @Test("The corpus frequency comes from the vocabulary, unscoped and search-free")
    func corpusFrequencyIsPopulated() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment"), indexedVolumeCount: 1)
        let first = try #require(inspection.operands.first)
        // d1 (containment) and d2 (contain) both carry the stem.
        #expect(first.corpusDocumentFrequency == 2)
        #expect(first.scopedCount == nil, "the cheap pass must not run a search")
    }

    @Test("Scoped counts are exact and agree with the search itself")
    func scopedCountsAreExact() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment europe")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let counted = await inspector.scopedCounts(for: inspection, parameters: params)

        #expect(counted.count == 2)
        for item in counted {
            let alone = QueryInspector.parameters(params, narrowedTo: item.operand)
            let direct = try await inspector.searchService.searchCount(parameters: alone)
            #expect(item.scopedCount == direct,
                    "\(item.operand.text): inspector=\(item.scopedCount as Int?) direct=\(direct)")
        }
    }

    /// The gap between the two counts is the point of showing both.
    @Test("Scoped and corpus counts can differ, and both are reported")
    func scopedAndCorpusCanDiffer() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        var params = SearchParameters(keywords: "containment")
        params.documentTypeFilter = .editorialNotesOnly   // narrows to nothing in this corpus
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        let first = try #require(counted.first)
        #expect(first.scopedCount == 0, "no editorial notes carry the term")
        #expect(first.corpusDocumentFrequency == 2, "but the corpus does — that gap is the finding")
    }

    @Test("A negated operand is not given a hit count")
    func negatedOperandIsNotCounted() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "europe -containment")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        let negated = try #require(counted.first { $0.operand.isNegated })
        #expect(negated.scopedCount == nil,
                "counting an excluded term reads as a hit count for something not in the results")
    }

    // MARK: - Zero-result decomposition

    @Test("The empty conjunct is named — the whole point of the zero path")
    func emptyConjunctIsNamed() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        // "europe" matches; "formosa" matches nothing; together they match nothing.
        let params = SearchParameters(keywords: "europe formosa")
        #expect(try await inspector.searchService.searchCount(parameters: params) == 0)

        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let empty = await inspector.emptyConjuncts(in: inspection, parameters: params)
        #expect(empty.map(\.text) == ["formosa"],
                "only the conjunct that is actually empty may be blamed")
    }

    @Test("A query that returns results names no empty conjunct")
    func noFalseBlame() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment europe")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        #expect(await inspector.emptyConjuncts(in: inspection, parameters: params).isEmpty)
    }

    @Test("Decomposition keeps the filters — the question is 'empty here', not 'anywhere'")
    func decompositionKeepsFilters() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        var params = SearchParameters(keywords: "containment europe")
        params.documentTypeFilter = .editorialNotesOnly
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let empty = await inspector.emptyConjuncts(in: inspection, parameters: params)
        // Under this filter *both* terms are empty, which is itself the answer: the filter
        // is the problem, not either word. A decomposition that dropped the filter would
        // report neither and leave the researcher with "no results" and no explanation.
        #expect(Set(empty.map(\.text)) == ["containment", "europe"])
    }

    @Test("An excluded term is never blamed for an empty result")
    func negatedOperandsAreNotBlamed() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "formosa -zzznothing")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        let empty = await inspector.emptyConjuncts(in: inspection, parameters: params)
        #expect(!empty.contains { $0.isNegated })
        #expect(empty.map(\.text) == ["formosa"])
    }

    // MARK: - Per-operand re-query fidelity

    @Test("An operand's solo query reproduces its own marks, not a plainer version")
    func soloQueryPreservesMarks() {
        let exact = ParsedOperand(text: "containment", rendered: "\"containment\"",
                                  kind: .word, isNegated: false, isExact: true)
        #expect(QueryInspector.queryText(for: exact) == "=containment",
                "counting an exact term as a stemmed one reports a number the query never used")

        let phrase = ParsedOperand(text: "cold war", rendered: "\"cold war\"",
                                   kind: .phrase, isNegated: false, isExact: false)
        #expect(QueryInspector.queryText(for: phrase) == "\"cold war\"")

        let prefix = ParsedOperand(text: "negoti*", rendered: "\"negoti\"*",
                                   kind: .prefix, isNegated: false, isExact: false)
        #expect(QueryInspector.queryText(for: prefix) == "negoti*")
    }

    @Test("Narrowing to one operand clears the structured keyword fields")
    func narrowingClearsStructuredFields() {
        var base = SearchParameters(keywords: "a b")
        base.phrase = "cold war"
        base.prefixWildcard = "negoti"
        base.excludedTerms = ["korea"]
        base.volumeIds = ["v1"]

        let operand = ParsedOperand(text: "a", rendered: "\"a\"",
                                    kind: .word, isNegated: false, isExact: false)
        let narrowed = QueryInspector.parameters(base, narrowedTo: operand)
        #expect(narrowed.keywords == "a")
        #expect(narrowed.phrase == nil, "a stale phrase would AND into a per-operand count")
        #expect(narrowed.prefixWildcard == nil)
        #expect(narrowed.excludedTerms.isEmpty)
        #expect(narrowed.volumeIds == ["v1"], "but the scope must survive")
    }

    // MARK: - The denominator

    @Test("The indexed-volume denominator is whatever the caller measured")
    func denominatorIsPassedThrough() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "europe"), indexedVolumeCount: 37)
        #expect(inspection.indexedVolumeCount == 37,
                "the denominator is per-device, never the manifest's 552")
    }
}
