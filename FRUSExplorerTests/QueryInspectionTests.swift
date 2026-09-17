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
import SwiftUI
@testable import FRUSExplorer

/// The Query Inspector's model: what it claims about a query, against a real index (Q-2a).
///
/// Every claim here is one a researcher may copy into a method appendix, so each is tested
/// against a real pipeline rather than a stub. The inspector's whole value is that its
/// numbers are the search's numbers; a mocked count would prove nothing.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297: terms the expression leaves out are reported as not applied and never counted,
///         blamed or offered for counting; keyword `NOT` is inspected exactly like `-`
///   1.2 — #1297 join: typed exclusions beside a structured phrase or prefix are applied and listed,
///         structured operands are counted through their own field, and an approximation with no
///         operand to report is flagged
///   1.3 — #1297 fixes: the caption and ADVANCED tag gates are model properties checked at runtime, and the
///         strip scan matches each gate with its key, so an inverted or unrelated gate fails
///   1.4 — #1297 round 1: the term-row gate and the NOT APPLIED loop are matched as anchored calls; counting keeps
///         `isApproximate` through the controller and closes the offer beside an excluded operand; a refused query
///         beside a filter is not filters only, and the strip and both hosts explain it, while only a refused parse of
///         real text sets `isRefused`; an `=` parser 6.3 ignores is inspected and counted as the stemmed word the
///         search runs; the iOS refresh key covers every query part
///   1.5 — #1297 round 2: the EXACT tag and exact counts follow each operand's `isExactApplied` (A1); the refused line
///         needs something searchable that was refused, never punctuation alone (A2); `QueryInspector.Inputs`, the iOS
///         refresh key, holds exactly the parameter fields the passes read, checked field by field and by running the
///         passes (A3); a refresh that leaves the operands unchanged keeps the zero-result blame (A4)
///   1.6 — #1297 round 3: the EXACT tag and exact counts follow parser 6.5's D4 — every positive mark on a word marked in
///         every alternative, or required once, applies (A1); an excluded operator word is something refused, and an
///         excluded phrase and prefix are pinned beside it (A2); the zero-result blame decomposes the query that ran, and
///         a same-words negation flip clears it while counting and a scope toggle keep it (A3); each unread refresh input
///         is checked against a base where reading it would change a count (A5); the strip is rendered, so a NOT APPLIED
///         row that is gated out or hidden fails (A6)
@Suite("Query inspection")
struct QueryInspectionTests {

    // MARK: - Fixture

    /// d1 carries *containment* and *europe*; d2 carries *contain* twice, so the
    /// `contain` stem has more occurrences (3) than documents (2) and the dispersion
    /// ratio is a non-trivial 1.5; d3 carries *europe* alone. Nothing anywhere carries
    /// *formosa* — the empty conjunct.
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
          <p>We must contain the threat, and contain it quickly.</p>
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
        let (dir, inspector, _) = try await makeFixture(xml: makeVolumeXML())
        return (dir, inspector)
    }

    /// The fixture over `xml` as `vol1`, with the pipeline, for a test that also writes to the index.
    private func makeFixture(xml: String) async throws
        -> (dir: URL, inspector: QueryInspector, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSInspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)
        return (dir, QueryInspector(searchService: service), pipeline)
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

    @Test("Occurrences ride the same vocabulary row, and dispersion is their quotient")
    func dispersionIsComputedFromTheVocabularyRow() async throws {
        // W-16: this ratio is the app's ONE definition of the dispersion statistic —
        // `FTS5Vocabulary.occurrencesPerDocument` used to define it a second time with
        // zero callers and was deleted. These pins are what keep the surviving
        // definition honest.
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "containment"), indexedVolumeCount: 1)
        let first = try #require(inspection.operands.first)
        // The `contain` stem: once in d1 (containment), twice in d2 (contain, contain).
        #expect(first.corpusOccurrences == 3)
        #expect(first.corpusDocumentFrequency == 2)
        #expect(first.corpusOccurrencesPerDocument == 1.5)
    }

    @Test("Dispersion is nil, not a division error, when either half is missing")
    func dispersionGuardsItsDenominator() throws {
        let operand = try #require(
            FTS5InlineQueryParser.parseDetailed("containment").operands.first)
        // No vocabulary row reached (a phrase, an unindexed store): both halves nil.
        let unresolved = InspectedOperand(
            operand: operand, stem: nil, scopedCount: nil,
            corpusDocumentFrequency: nil, corpusOccurrences: nil)
        #expect(unresolved.corpusOccurrencesPerDocument == nil)
        // A zero document frequency must never become a division by zero.
        let unseen = InspectedOperand(
            operand: operand, stem: "contain", scopedCount: nil,
            corpusDocumentFrequency: 0, corpusOccurrences: 0)
        #expect(unseen.corpusOccurrencesPerDocument == nil)
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
                                  kind: .word, isNegated: false, isExact: true, isExactApplied: true)
        #expect(QueryInspector.queryText(for: exact) == "=containment",
                "counting an exact term as a stemmed one reports a number the query never used")

        // The mark the search applies, not the mark as typed (#1297 round 2, A1): parser 6.4 decides per operand, so a
        // typed `=` it ignores is re-spelled without one, and counted by the stem the search ran.
        let ignored = ParsedOperand(text: "containment", rendered: "\"containment\"",
                                    kind: .word, isNegated: false, isExact: true, isExactApplied: false)
        #expect(QueryInspector.queryText(for: ignored) == "containment",
                "counting an ignored mark as an exact term reports a number the query never used either")

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

    // MARK: - Terms the expression leaves out (#1297)

    /// What the inspector does with a parse that drops operands, independent of which queries
    /// the parser drops — so this holds on any parser that fills `droppedOperands`.
    ///
    /// The dropped pair is HAND-BUILT and is no longer a shape the parser produces. It was once the
    /// parse of `europe OR NOT (formosa -zzznothing)`; since negation is pushed inward that query
    /// renders `"europe" OR "zzznothing"`, applies `zzznothing` and leaves out only `formosa`, and
    /// no parse can now drop an operand that is not negated. The un-negated `zzznothing` stays in
    /// the fixture because it is what makes the blame assertion bite — `emptyConjuncts` skips
    /// negated operands anyway — and the control at the end proves `zzznothing` WOULD be blamed
    /// were it applied.
    @Test("Dropped operands become not-applied rows that are never counted, blamed or offered for counting")
    func droppedOperandsAreNotApplied() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let applied = try #require(FTS5InlineQueryParser.parseDetailed("europe").operands.first)
        let dropped = [
            ParsedOperand(text: "formosa", rendered: "NOT \"formosa\"",
                          kind: .word, isNegated: true, isExact: false),
            ParsedOperand(text: "zzznothing", rendered: "\"zzznothing\"",
                          kind: .word, isNegated: false, isExact: false),
        ]
        // `keywords` carries what the expression is equivalent to, so the rendered expression
        // and every per-operand count run against the same query the parse describes.
        let params = SearchParameters(keywords: "europe")
        let parsed = ParsedQuery(expression: "\"europe\"", exactTerms: [],
                                 operands: [applied], droppedOperands: dropped)

        let inspection = await inspector.inspect(parsed: parsed, parameters: params,
                                                 indexedVolumeCount: 1)
        #expect(inspection.operands.map(\.operand) == [applied])
        #expect(inspection.notApplied == dropped, "dropped operands are carried, in typed order")
        #expect(inspection.operands.first?.corpusDocumentFrequency == 2,
                "the applied operand still gets its vocabulary lookup")
        #expect(inspection.hasUncountedOperands, "europe has not been counted yet")

        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        #expect(counted.map(\.operand.text) == ["europe"], "a not-applied operand is never counted")
        #expect(counted.first?.scopedCount == 2)
        let afterCounting = inspection.replacingOperands(counted)
        #expect(!afterCounting.hasUncountedOperands,
                "with europe counted, not-applied operands must not keep the count offer open")
        #expect(afterCounting.notApplied == dropped, "and asking for counts must not drop the rows")

        #expect(await inspector.emptyConjuncts(in: inspection, parameters: params).isEmpty,
                "zzznothing matches nothing, but the search never used it, so it is not why anything is empty")

        // Control: applied, the same operand IS blamed — so the assertion above is about
        // `notApplied`, not about a fixture where nothing could be blamed.
        let controlParams = SearchParameters(keywords: "europe zzznothing")
        let appliedControl = ParsedQuery(expression: "\"europe\" AND \"zzznothing\"", exactTerms: [],
                                         operands: [applied, dropped[1]])
        let control = await inspector.inspect(parsed: appliedControl, parameters: controlParams,
                                              indexedVolumeCount: 1)
        #expect(await inspector.emptyConjuncts(in: control, parameters: controlParams)
                .map(\.text) == ["zzznothing"])
    }

    @Test("Term rows show for applied operands or not-applied ones, and not for neither")
    func showsTermRowsGate() throws {
        let expression = RenderedExpression(corpus: "\"and\"", userContent: "\"and\"")
        let korea = ParsedOperand(text: "korea", rendered: "NOT \"korea\"",
                                  kind: .word, isNegated: true, isExact: false)
        let europe = try #require(FTS5InlineQueryParser.parseDetailed("europe").operands.first)
        let applied = InspectedOperand(operand: europe, stem: "europ", scopedCount: nil,
                                       corpusDocumentFrequency: 2, corpusOccurrences: 2)
        // `and OR -korea`: no applied operand, one not-applied one — the row must still show.
        let onlyNotApplied = QueryInspection(expression: expression, operands: [],
                                             indexedVolumeCount: 1, isFilterOnly: false,
                                             notApplied: [korea])
        let neither = QueryInspection(expression: expression, operands: [],
                                      indexedVolumeCount: 1, isFilterOnly: false)
        let onlyApplied = QueryInspection(expression: expression, operands: [applied],
                                          indexedVolumeCount: 1, isFilterOnly: false)
        #expect(onlyNotApplied.showsTermRows)
        #expect(!neither.showsTermRows)
        #expect(onlyApplied.showsTermRows)
    }

    /// The gate and the rows are view code no model test can reach, so these two checks read the
    /// strip's own source — each scoped to the one member that must do it, not to the file.
    ///
    /// Each check matches the call as one anchored pattern, as `stripShowsStructuredTagAndApproximationCaption` does.
    /// The substring checks this replaced passed with the gate inverted, with the loop reduced to `.first`, and with
    /// `.prefix(0)` on the loop's array, which renders no row at all (#1297 round 1, F2 and X1).
    @Test("The strip gates its term rows on showsTermRows and renders every not-applied operand")
    func stripRendersNotAppliedRows() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Search/QueryInspectorView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        func member(_ signature: String) throws -> Substring {
            let start = try #require(source.range(of: signature), "\(signature) not found")
            var depth = 0, index = start.upperBound, opened = false
            while index < source.endIndex {
                if source[index] == "{" { depth += 1; opened = true }
                if source[index] == "}" { depth -= 1; if opened && depth == 0 { break } }
                index = source.index(after: index)
            }
            return source[start.lowerBound...index]
        }
        let stripStart = try #require(source.range(of: "struct QueryInspectorStrip"))
        let strip = source[stripStart.lowerBound...]
        let bodyStart = try #require(strip.range(of: "var body: some View {"))
        var depth = 0, index = bodyStart.upperBound
        while index < strip.endIndex {
            if strip[index] == "{" { depth += 1 }
            if strip[index] == "}" { if depth == 0 { break }; depth -= 1 }
            index = strip.index(after: index)
        }
        let body = strip[bodyStart.upperBound..<index]
        #expect(body.range(of: #"if inspection\.showsTermRows \{\s*operandRows\s*\}"#, options: .regularExpression) != nil,
                "the strip must render operandRows under showsTermRows, not under its inversion or another gate")
        #expect(body.components(separatedBy: "operandRows").count == 2, "and render operandRows nowhere else")
        #expect(!body.contains("inspection.hasOperands"), "hasOperands alone hides the row for `and OR -korea`")
        let rows = try member("private var operandRows: some View")
        #expect(rows.range(
            of: #"ForEach\(Array\(inspection\.notApplied\.enumerated\(\)\), id: \\\.offset\) \{ _, operand in\s*notAppliedRow\(for: operand\)\s*\}"#,
            options: .regularExpression) != nil,
                "operandRows must render one notAppliedRow for every not-applied operand, over the whole array")
        #expect(rows.components(separatedBy: "notAppliedRow(for:").count == 2, "and render the row nowhere else")
    }

    /// Round 3 (A6): `stripRendersNotAppliedRows` reads the loop, and it passed with the loop wrapped in
    /// `if inspection.notApplied.isEmpty` and with the row marked `.hidden()` — each renders no NOT APPLIED row on either
    /// platform (X1a, X1c). No scan can list every condition or modifier that empties a row, so this renders the strip.
    /// Two inspections that differ only in which word was left out must draw differently, which a row that is absent,
    /// hidden or transparent cannot do. The control shows the renderer draws the strip's text at all, so a failure of
    /// the first assertion is about the rows.
    @Test("The strip draws every NOT APPLIED row it is given")
    @MainActor
    func stripDrawsNotAppliedRows() throws {
        func rendered(expression: String, notApplied word: String) throws -> (width: Int, height: Int, pixels: [UInt8]) {
            let inspection = QueryInspection(
                expression: RenderedExpression(corpus: expression, userContent: expression), operands: [],
                indexedVolumeCount: 1, isFilterOnly: false,
                notApplied: [ParsedOperand(text: word, rendered: "NOT \"\(word)\"", kind: .word, isNegated: true, isExact: false)],
                isApproximate: true)
            #expect(inspection.showsTermRows, "precondition: the rows are gated in")
            let renderer = ImageRenderer(content: QueryInspectorStrip(inspection: inspection, isExpanded: true,
                                                                      isCountingScoped: false, onRequestScopedCounts: {})
                .frame(width: 360))
            renderer.scale = 2
            let image = try #require(renderer.cgImage, "ImageRenderer produced no image")
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(CGContext(
                data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return (image.width, image.height, pixels)
        }

        let control = try rendered(expression: "\"cold\"", notApplied: "korea")
        #expect(try rendered(expression: "\"war\"", notApplied: "korea").pixels != control.pixels,
                "control: the renderer draws the strip's text, so an identical pair below is about the rows")
        let other = try rendered(expression: "\"cold\"", notApplied: "formosa")
        #expect(other.width == control.width && other.height == control.height,
                "precondition: one row each, so the two strips are the same size")
        #expect(other.pixels != control.pixels,
                "a NOT APPLIED row that draws its word makes these differ; an absent, hidden or clear one does not")
    }

    @Test("Replacing the operands carries every other fact across, the not-applied ones included")
    func replacingOperandsKeepsEverythingElse() throws {
        let operand = try #require(FTS5InlineQueryParser.parseDetailed("europe").operands.first)
        let notApplied = [ParsedOperand(text: "korea", rendered: "NOT \"korea\"",
                                        kind: .word, isNegated: true, isExact: false)]
        let expression = RenderedExpression(corpus: "\"europe\"", userContent: "\"europe\"")
        let uncounted = InspectedOperand(operand: operand, stem: "europ", scopedCount: nil,
                                         corpusDocumentFrequency: 2, corpusOccurrences: 2)
        let counted = InspectedOperand(operand: operand, stem: "europ", scopedCount: 2,
                                       corpusDocumentFrequency: 2, corpusOccurrences: 2)
        // `isRefused` is set on a value no parse produces beside operands, so the equality below proves every field
        // is carried, not only the ones a real counting pass would have.
        let before = QueryInspection(expression: expression, operands: [uncounted],
                                     indexedVolumeCount: 37, isFilterOnly: false,
                                     notApplied: notApplied, isApproximate: true, isRefused: true)

        #expect(before.replacingOperands([counted])
                == QueryInspection(expression: expression, operands: [counted],
                                   indexedVolumeCount: 37, isFilterOnly: false,
                                   notApplied: notApplied, isApproximate: true, isRefused: true))
        #expect(before.replacingOperands([counted]).isApproximate,
                "a request for counts must not clear the narrower-than-typed caption")
        #expect(before.hasUncountedOperands)
        #expect(!before.replacingOperands([counted]).hasUncountedOperands)

        // Only not-applied operands: nothing the search used is waiting for a count.
        let onlyNotApplied = QueryInspection(expression: expression, operands: [],
                                             indexedVolumeCount: 37, isFilterOnly: false,
                                             notApplied: notApplied)
        #expect(!onlyNotApplied.hasUncountedOperands)
    }

    /// Needs the #1297 parser, which leaves an exclusion-only `OR` alternative out of the
    /// expression and reports its operands in `droppedOperands`.
    @Test("An OR alternative made only of an exclusion is reported as not applied")
    func exclusionOnlyAlternativeIsNotApplied() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "cold OR -korea")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        #expect(inspection.expression?.displayed == "\"cold\"",
                "the exclusion-only alternative has nothing to search for and is left out")
        #expect(inspection.operands.map(\.operand.text) == ["cold"])
        #expect(inspection.notApplied.map(\.text) == ["korea"])
        #expect(inspection.notApplied.map(\.isNegated) == [true])
        #expect(inspection.isApproximate, "the search is narrower than what was typed, and says so")

        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        #expect(counted.map(\.operand.text) == ["cold"], "korea was never searched, so never counted")
        // Neither word is in the fixture: cold is empty on its own and may be blamed; korea may not.
        #expect(await inspector.emptyConjuncts(in: inspection, parameters: params).map(\.text) == ["cold"])
    }

    /// Needs the #1297 parser: the not-applied rows must survive the controller's scoped-count
    /// update, which rebuilds the inspection.
    @Test("Asking the controller for scoped counts keeps the not-applied rows")
    @MainActor
    func controllerKeepsNotAppliedRowsThroughCounting() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        let params = SearchParameters(keywords: "europe OR -containment")
        await controller.refresh(parameters: params, service: inspector.searchService,
                                 indexedVolumeCount: 1)
        #expect(controller.inspection?.notApplied.map(\.text) == ["containment"])
        #expect(controller.inspection?.isApproximate == true, "precondition: the query is narrower than typed")

        await controller.loadScopedCounts(parameters: params, service: inspector.searchService)
        let inspection = try #require(controller.inspection)
        #expect(inspection.operands.map(\.scopedCount) == [2], "d1 and d3 carry europe")
        #expect(inspection.notApplied.map(\.text) == ["containment"],
                "a request for counts must not drop the not-applied rows")
        // The controller could rebuild the inspection with `notApplied` and still drop this flag, which clears the
        // narrower-than-typed caption; `replacingOperandsKeepsEverythingElse` cannot see the controller (X3).
        #expect(inspection.isApproximate, "a request for counts must not clear the narrower-than-typed caption")
    }

    /// Needs the #1297 parser, under which keyword `NOT` marks its operand negated exactly as
    /// `-` does. Before it, `cold NOT korea` listed korea as a second positive term: counted,
    /// and blamed when empty.
    @Test("NOT korea is inspected exactly like -korea: excluded, uncounted, never blamed")
    func keywordNotIsInspectedLikeDash() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let keyword = SearchParameters(keywords: "cold NOT korea")
        let dash = SearchParameters(keywords: "cold -korea")
        let viaKeyword = await inspector.inspect(parameters: keyword, indexedVolumeCount: 1)
        let viaDash = await inspector.inspect(parameters: dash, indexedVolumeCount: 1)

        #expect(viaKeyword.operands.map(\.operand.isNegated) == [false, true])
        #expect(viaKeyword.operands == viaDash.operands, "the operand rows must be identical")
        #expect(viaKeyword.expression == viaDash.expression)

        let counted = await inspector.scopedCounts(for: viaKeyword, parameters: keyword)
        #expect(counted.map(\.scopedCount) == [0, nil],
                "cold is counted (0 in this fixture); the excluded korea gets no hit count")
        // The excluded korea keeps a nil count for good, so it must not hold the count offer open once cold is
        // counted. No other test counts beside an excluded operand, so none could see the offer stay up (X2).
        #expect(!viaKeyword.replacingOperands(counted).hasUncountedOperands,
                "an excluded operand's nil count is not a count still to fetch")

        // Neither word is in the fixture, so each is empty on its own — only the applied,
        // non-excluded one may be blamed.
        #expect(await inspector.emptyConjuncts(in: viaKeyword, parameters: keyword).map(\.text) == ["cold"])
        #expect(await inspector.emptyConjuncts(in: viaDash, parameters: dash).map(\.text) == ["cold"])
    }

    // MARK: - Typed text beside the structured fields (#1297 join)

    /// Finding 1 in the app: a typed exclusion with nothing of its own to exclude from, beside a
    /// structured prefix, excludes from the prefix — it used to vanish, with no row saying so.
    @Test("A typed exclusion beside a structured prefix is applied, listed and excluded from the count")
    func typedExclusionBesideStructuredPrefixIsApplied() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "-containment", prefixWildcard: "europ")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        #expect(inspection.expression?.displayed == "\"europ\"* NOT \"containment\"")
        #expect(inspection.operands.map(\.operand.text) == ["containment", "europ*"])
        #expect(inspection.operands.map(\.operand.isNegated) == [true, false])
        #expect(inspection.operands.map(\.operand.source) == [.typed, .structured])
        #expect(inspection.notApplied.isEmpty)
        #expect(!inspection.isApproximate)
        #expect(inspection.hasUncountedOperands, "the structured prefix is a term the search used")

        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        #expect(counted.map(\.scopedCount) == [nil, 2], "europ* is in d1 and d3; the exclusion gets no hit count")
        #expect(try await inspector.searchService.searchCount(parameters: params) == 1,
                "d1 carries containment, so only d3 remains")
    }

    /// Finding 2 in the app: a typed complement that anchors on its own was approximated beside a
    /// prefix even though the prefix lets it be searched exactly.
    @Test("A typed OR with an exclusion-only alternative, beside a structured prefix, is searched exactly")
    func complementBesideStructuredPrefixIsExact() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "alliance OR -europe", prefixWildcard: "contain")
        let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
        #expect(inspection.expression?.displayed == "\"contain\"* NOT (\"europe\" NOT \"alliance\")")
        #expect(inspection.operands.map(\.operand.text) == ["alliance", "europe", "contain*"])
        #expect(inspection.operands.map(\.operand.isNegated) == [false, true, false])
        #expect(inspection.operands.map(\.operand.source) == [.typed, .typed, .structured])
        #expect(inspection.notApplied.isEmpty, "nothing is left out, so europe is not NOT APPLIED")
        #expect(!inspection.isApproximate)

        #expect(try await inspector.searchService.searchCount(parameters: params) == 1,
                "d2 carries contain and not europe; d1 carries both and no alliance")
        let counted = await inspector.scopedCounts(for: inspection, parameters: params)
        #expect(counted.map(\.scopedCount) == [1, nil, 2])
        #expect(await inspector.emptyConjuncts(in: inspection, parameters: params).isEmpty)
    }

    /// A structured operand cannot always be re-spelled as typed text, so its count must come from
    /// its own field — otherwise the count describes a different query.
    @Test("Narrowing to a structured operand keeps it in its own field, so the count is of what it rendered")
    func narrowingAStructuredOperandUsesItsOwnField() throws {
        var prefixBase = SearchParameters(prefixWildcard: "neg:oti")
        prefixBase.volumeIds = ["v1"]
        let prefix = try #require(SearchService.parsedQuery(for: prefixBase).operands.first)
        #expect(prefix.rendered == "\"neg oti\"*")
        #expect(prefix.source == .structured)
        let narrowedPrefix = QueryInspector.parameters(prefixBase, narrowedTo: prefix)
        #expect(narrowedPrefix.keywords == nil)
        #expect(narrowedPrefix.prefixWildcard == "neg oti")
        #expect(narrowedPrefix.phrase == nil)
        #expect(narrowedPrefix.excludedTerms.isEmpty)
        #expect(narrowedPrefix.volumeIds == ["v1"], "the scope survives narrowing")
        #expect(SearchService.parsedQuery(for: narrowedPrefix).expression == prefix.rendered)

        let phraseBase = SearchParameters(keywords: "containment", phrase: "Cold  War", excludedTerms: ["korea"])
        let phrase = try #require(SearchService.parsedQuery(for: phraseBase).operands.first { $0.kind == .phrase })
        #expect(phrase.rendered == "\"cold war\"")
        #expect(phrase.source == .structured)
        let narrowedPhrase = QueryInspector.parameters(phraseBase, narrowedTo: phrase)
        #expect(narrowedPhrase.keywords == nil, "the typed words must not AND into the phrase's count")
        #expect(narrowedPhrase.phrase == "cold war")
        #expect(narrowedPhrase.prefixWildcard == nil)
        #expect(narrowedPhrase.excludedTerms.isEmpty)
        #expect(SearchService.parsedQuery(for: narrowedPhrase).expression == phrase.rendered)

        // Control: re-spelled as typed text, the prefix is a different query.
        #expect(SearchService.parsedQuery(for: SearchParameters(keywords: "neg oti*")).expression
                == "\"neg\" AND \"oti\"*")
    }

    /// Pushing negation inward can leave out nothing but a demoted operator word, which has no
    /// operand to list — the flag is the only report.
    @Test("A query narrowed with no not-applied operand to show is still flagged approximate")
    func approximationWithNoNotAppliedRowIsFlagged() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let inspection = await inspector.inspect(
            parameters: SearchParameters(keywords: "-( -containment NOT )"), indexedVolumeCount: 1)
        #expect(inspection.expression?.displayed == "\"containment\"")
        #expect(inspection.notApplied.isEmpty)
        #expect(inspection.isApproximate)
    }

    /// The two gates the strip reads, run against real inspections: a scan of the view could not tell either gate
    /// from its inversion.
    @Test("The narrower-than-typed caption shows exactly for an approximation, and the ADVANCED tag exactly on a structured operand")
    func approximateCaptionAndStructuredTagGates() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let approximate = await inspector.inspect(
            parameters: SearchParameters(keywords: "-( -containment NOT )"), indexedVolumeCount: 1)
        #expect(approximate.isApproximate)
        #expect(approximate.showsApproximateCaption, "the caption is the only report of the left-out word")
        #expect(approximate.operands.map(\.operand.source) == [.typed])
        #expect(approximate.operands.map(\.showsStructuredTag) == [false], "a typed operand is not ADVANCED")

        let exact = await inspector.inspect(
            parameters: SearchParameters(keywords: "-containment", prefixWildcard: "europ"), indexedVolumeCount: 1)
        #expect(!exact.isApproximate)
        #expect(!exact.showsApproximateCaption, "an exact query is not narrower than typed")
        #expect(exact.operands.map(\.operand.source) == [.typed, .structured])
        #expect(exact.operands.map(\.showsStructuredTag) == [false, true], "only the restored prefix is ADVANCED")
    }

    /// The gates are the model's (`approximateCaptionAndStructuredTagGates`); these read the strip's own source to
    /// pin that each member renders its key under that gate and nowhere else. The gate and the key are matched as
    /// one pattern, so `if !inspection.showsApproximateCaption`, or the key under any other condition, fails.
    @Test("The strip tags structured operands ADVANCED and captions an approximation under the MATCH line")
    func stripShowsStructuredTagAndApproximationCaption() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Search/QueryInspectorView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        func member(_ signature: String) throws -> Substring {
            let start = try #require(source.range(of: signature), "\(signature) not found")
            var depth = 0, index = start.upperBound, opened = false
            while index < source.endIndex {
                if source[index] == "{" { depth += 1; opened = true }
                if source[index] == "}" { depth -= 1; if opened && depth == 0 { break } }
                index = source.index(after: index)
            }
            return source[start.lowerBound...index]
        }
        let expressionRow = try member("private var expressionRow: some View")
        #expect(expressionRow.range(
            of: #"if inspection\.showsApproximateCaption \{\s*Text\(String\(localized: "search\.inspector\.approximateCaption""#,
            options: .regularExpression) != nil,
                "the caption renders under showsApproximateCaption, in the expression row, which never collapses")
        #expect(expressionRow.components(separatedBy: "\"search.inspector.approximateCaption\"").count == 2,
                "and nowhere else in that row")
        let operandRows = try member("private var operandRows: some View")
        #expect(operandRows.range(
            of: #"if item\.showsStructuredTag \{\s*microTag\(String\(localized: "search\.inspector\.structuredTag""#,
            options: .regularExpression) != nil,
                "the ADVANCED tag renders under showsStructuredTag")
        #expect(operandRows.components(separatedBy: "\"search.inspector.structuredTag\"").count == 2,
                "and nowhere else in the operand rows")
    }

    // MARK: - Queries that cannot run (#1297 round 1)

    /// F8: the search throws `FTS5Error.emptyQuery` for a query with text and no expression, filter or not —
    /// `makeMatchExpressions` runs filter-only only under `runsAsFilterOnly`, which a query with text never is. The
    /// inspector read the looser `supportsFilterOnlySearch`, so beside a person or subject filter it said "filters only"
    /// while the search failed. Each refusal here is a different route to a nil expression: the 6.1 empty
    /// approximation, the 2.2 guard on a summaries-only scope, and the 6.3 nesting limit.
    @Test("A refused text query beside a standalone filter is not called filters only")
    func refusedTextQueryIsNotFilterOnly() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        var emptyApproximation = SearchParameters(keywords: "-(containment -europe) -europe")
        emptyApproximation.personRef = "#p-acheson"
        var guardedScope = SearchParameters(keywords: "=cold \"europe\" -europe OR -europe")
        guardedScope.includeDocumentText = false
        guardedScope.includeSummaries = true
        guardedScope.includeNotes = false
        guardedScope.subjectBucketKey = "A\u{1F}B"
        let nesting = String(repeating: "(", count: 33) + "europe" + String(repeating: ")", count: 33)
        var tooDeep = SearchParameters(keywords: nesting)
        tooDeep.personRef = "#p-acheson"

        for params in [emptyApproximation, guardedScope, tooDeep] {
            let label = params.keywords ?? ""
            #expect(params.supportsFilterOnlySearch, "\(label): precondition, a standalone filter is set")
            #expect(SearchService.parsedQuery(for: params).expression == nil, "\(label): precondition, the parse refuses")
            do {
                let pair = try await inspector.searchService.matchExpressions(for: params)
                Issue.record("\(label): expected emptyQuery, got \(String(describing: pair))")
            } catch FTS5Error.emptyQuery {
                // expected: the search fails
            }
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(inspection.expression == nil)
            #expect(!inspection.isFilterOnly, "\(label): the search throws, so the strip must not say filters only")
            #expect(inspection.isRefused, "\(label): it says instead that the query cannot run")
            #expect(inspection.showsStrip, "\(label): and the hosts show the strip that says it")
        }

        // Control: with no text the same filter does run filter-only, and says so.
        var filterOnly = SearchParameters()
        filterOnly.personRef = "#p-acheson"
        let filters = await inspector.inspect(parameters: filterOnly, indexedVolumeCount: 1)
        #expect(filters.isFilterOnly)
        #expect(!filters.isRefused)
        #expect(filters.showsStrip)
    }

    /// The other side of `isRefused`: it is about the parse, so it must not claim a query cannot run for what was
    /// typed when the parse renders or nothing was typed at all.
    @Test("isRefused is set only by a refused parse of real text, and showsStrip only when there is something to say")
    func refusalGateIsExact() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        // Refused with no filter at all: the case that used to show no strip.
        let bare = await inspector.inspect(parameters: SearchParameters(keywords: "-europe"), indexedVolumeCount: 1)
        #expect(bare.expression == nil && !bare.isFilterOnly)
        #expect(bare.isRefused && bare.showsStrip)

        // Rendering: an expression, nothing refused.
        let renders = await inspector.inspect(parameters: SearchParameters(keywords: "europe"), indexedVolumeCount: 1)
        #expect(renders.expression != nil && !renders.isRefused && renders.showsStrip)

        // Nothing typed and no filter: no strip, and no claim.
        let empty = await inspector.inspect(parameters: SearchParameters(), indexedVolumeCount: 1)
        #expect(!empty.isRefused && !empty.isFilterOnly && !empty.showsStrip)

        // Text whose parse renders, with every content scope off: no expression, but the reason is the scope, so the
        // refusal line would be false.
        var noScope = SearchParameters(keywords: "europe")
        noScope.includeDocumentText = false
        noScope.includeSummaries = false
        noScope.includeNotes = false
        let scopeless = await inspector.inspect(parameters: noScope, indexedVolumeCount: 1)
        #expect(scopeless.expression == nil)
        #expect(!scopeless.isRefused, "the parse renders; the scope is what is missing")

        // A restored excluded term alone is text with nothing positive: refused, like a typed one.
        let structured = await inspector.inspect(parameters: SearchParameters(excludedTerms: ["europe"]),
                                                 indexedVolumeCount: 1)
        #expect(structured.isRefused)
    }

    /// F8's view half. With `isFilterOnly` corrected, a refused query had nothing to say and both hosts hid the strip;
    /// the strip now names why there is no expression, and each host shows it on the model's own gate.
    @Test("The strip explains a refused query, and both hosts show the strip for it")
    func stripExplainsARefusedQuery() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/QueryInspectorView.swift"),
                              encoding: .utf8)
        #expect(view.range(
            of: #"\} else if inspection\.isFilterOnly \{\s*Text\(String\(localized: "search\.inspector\.filterOnly""#,
            options: .regularExpression) != nil, "the filters-only line stays under isFilterOnly")
        #expect(view.range(
            of: #"\} else if inspection\.isRefused \{\s*Text\(String\(localized: "search\.inspector\.refused""#,
            options: .regularExpression) != nil, "a refused query gets its own line under isRefused")
        #expect(view.components(separatedBy: "\"search.inspector.refused\"").count == 2, "and that line appears once")

        for host in ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(host), encoding: .utf8)
            #expect(source.range(
                of: #"if let inspection = inspectorController\.inspection,\s*inspection\.showsStrip \{"#,
                options: .regularExpression) != nil,
                    "\(host) must show the strip on QueryInspection.showsStrip, which a refused query sets")
        }
    }

    /// Parser 6.3 (D1) reports an `=` term only where every match must contain it. The operand still carries the typed
    /// mark, and the inspector showed it as typed: an EXACT tag on a word the search runs by its stem, and a scoped
    /// count that re-spelled it `=containment` and counted a narrower query than the one that ran.
    ///
    /// Round 2 (A1): the strip tags and counts on `ParsedOperand.isExactApplied`, the parser's own per-operand answer,
    /// and the operand keeps the mark as typed. Round 1 cleared `isExact` instead, deciding by the word.
    @Test("An = the search ignores is neither tagged EXACT nor counted exactly")
    func ignoredExactMarkIsInspectedAsStemmed() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let alternative = SearchParameters(keywords: "=containment OR alliance")
        #expect(SearchService.exactTerms(from: alternative).isEmpty,
                "precondition: parser 6.3 ignores the mark in an OR alternative")
        let inspection = await inspector.inspect(parameters: alternative, indexedVolumeCount: 1)
        #expect(inspection.operands.map(\.operand.text) == ["containment", "alliance"])
        #expect(inspection.operands.map(\.operand.isExactApplied) == [false, false],
                "no EXACT tag on a word the search does not filter")
        #expect(inspection.operands.map(\.operand.isExact) == [true, false],
                "the operand keeps the mark as typed; whether it applies is the parser's separate answer")
        #expect(inspection.operands.first?.isStemBroadening == true,
                "and the stem warning says containment is searched as contain, which it is")
        #expect(try await inspector.searchService.searchCount(parameters: alternative) == 3,
                "d1 and d2 by the stem contain, d4 by alliance")
        let counted = await inspector.scopedCounts(for: inspection, parameters: alternative)
        #expect(counted.map(\.scopedCount) == [2, 1], "containment is counted by its stem, as the search ran it")

        // Control: required, the mark is applied, tagged and counted exactly.
        let required = SearchParameters(keywords: "=containment europe")
        #expect(SearchService.exactTerms(from: required) == ["containment"])
        let applied = await inspector.inspect(parameters: required, indexedVolumeCount: 1)
        #expect(applied.operands.map(\.operand.isExactApplied) == [true, false])
        #expect(await inspector.scopedCounts(for: applied, parameters: required).map(\.scopedCount) == [1, 2],
                "=containment is d1 alone; europe is d1 and d3")
    }

    // MARK: - An = mark, operand by operand (#1297 round 2)

    /// A1: whether an `=` applies is the parser's per-operand answer (`ParsedOperand.isExactApplied`), and round 1's
    /// inspector decided it per WORD, keeping a typed mark whenever the operand's word was among `ParsedQuery.exactTerms`.
    /// The two still part on an excluded mark beside an applied one: in `=cold war -=cold` the word is reported, and
    /// only the first cold is filtered on.
    ///
    /// Round 3 (D4, parser 6.5): the parser decides the field by requirement over MARKED operands. A word every match
    /// must hold through a mark — a required mark, or a mark in every alternative — applies on every positive `=`
    /// operand on it, since inside the filtered documents each reads the same: `(=cold OR war) =cold` tags both colds,
    /// and `=cold war OR =cold peace` both. An unmarked occurrence never makes a mark apply, so `(=cold OR war) cold`
    /// and `=cold war OR cold peace` tag nothing. The inspected operands are the parser's, compared whole.
    @Test("The EXACT tag and the exact count follow each operand's applied mark, which the parser decides by requirement")
    func exactMarkIsReadPerOperand() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        let cases: [(text: String, typed: [Bool], applied: [Bool])] = [
            ("(=cold OR war) =cold", [true, false, true], [true, false, true]),
            ("-(war -=cold)", [true], [true]),
            ("(=cold OR war) cold", [true, false, false], [false, false, false]),
            ("=cold war OR =cold peace", [true, false, true, false], [true, false, true, false]),
            ("=cold OR =cold war", [true, true, false], [true, true, false]),
            ("=cold war OR cold peace", [true, false, false, false], [false, false, false, false]),
            ("=cold war -=cold", [true, false, true], [true, false, false]),
        ]
        for (text, typed, applied) in cases {
            let inspection = await inspector.inspect(parameters: SearchParameters(keywords: text), indexedVolumeCount: 1)
            #expect(inspection.operands.map(\.operand) == FTS5InlineQueryParser.parseDetailed(text).operands,
                    "\(text): the inspected operands are the parser's, unrewritten, in order")
            #expect(inspection.operands.map(\.operand.isExact) == typed, "\(text): each operand keeps its mark as typed")
            #expect(inspection.operands.map(\.operand.isExactApplied) == applied,
                    "\(text): EXACT is on exactly the operands the search filters to the literal word")
        }

        // Counted as the search ran them. The fixture: d1 containment, d2 contain (twice), d4 alliance — containment's
        // stem is contain, so a stemmed count of containment is 2 and a literal one is 1.
        func check(_ text: String, searched: Int, scoped: [Int?]) async throws {
            let params = SearchParameters(keywords: text)
            #expect(try await inspector.searchService.searchCount(parameters: params) == searched, "\(text): precondition")
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(await inspector.scopedCounts(for: inspection, parameters: params).map(\.scopedCount) == scoped,
                    "\(text): each operand is counted as the search applies it")
        }
        // The required mark applies, so both marks do, and each containment is counted as the literal word (d1).
        try await check("(=containment OR alliance) =containment", searched: 1, scoped: [1, 1, 1])
        // Beside an unmarked required containment no mark applies, so nothing is counted literally.
        try await check("(=containment OR alliance) containment", searched: 2, scoped: [2, 1, 2])
        // Excluding the group makes the marked word the whole search, and every match must hold it literally.
        try await check("-(alliance -=containment)", searched: 1, scoped: [1])
        // Marked in every alternative, the word applies in both (d1 only); unmarked in one, in neither (d1 and d2).
        try await check("=containment OR =containment alliance", searched: 1, scoped: [1, 1, 1])
        try await check("=containment OR containment alliance", searched: 2, scoped: [2, 2, 1])
    }

    /// The strip's EXACT tag must read the parser's per-operand field. The gate and the key are matched as one anchored
    /// pattern, so `if !item.operand.isExactApplied`, or the typed `isExact` the strip read before round 2, fails.
    @Test("The strip tags EXACT on the operand's applied mark")
    func stripTagsExactWhereTheMarkApplies() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Search/QueryInspectorView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "private var operandRows: some View"))
        var depth = 0, index = start.upperBound, opened = false
        while index < source.endIndex {
            if source[index] == "{" { depth += 1; opened = true }
            if source[index] == "}" { depth -= 1; if opened && depth == 0 { break } }
            index = source.index(after: index)
        }
        let operandRows = source[start.lowerBound...index]
        #expect(operandRows.range(
            of: #"if item\.operand\.isExactApplied \{\s*microTag\(String\(localized: "search\.inspector\.exactTag""#,
            options: .regularExpression) != nil,
                "the EXACT tag renders under the operand's isExactApplied")
        #expect(operandRows.components(separatedBy: "\"search.inspector.exactTag\"").count == 2,
                "and nowhere else in the operand rows")
        #expect(!operandRows.contains("operand.isExact {"), "the typed mark is not what the search applies")
    }

    // MARK: - The refused line needs something refused (#1297 round 2)

    /// A2: the refused line said "nothing is left to search for once its exclusions apply, or its parentheses nest more
    /// than 32 deep" for any text whose parse is nil — including a lone `"`, `(` or `=` typed on the way to a query,
    /// where neither reason is true, and which the strip shows while the researcher pauses mid-typing. The line now
    /// needs something searchable that was refused: an operand, or groups nested past the parser's own limit.
    ///
    /// Round 3 (A2): something searchable is also an operator word demoted to a search word, which has no operand row.
    /// `-(or)` and `NOT (AND)` exclude the word they hold and are refused as exclusions only, and round 2's gate, which
    /// looked for an operand, hid their line. A typed phrase and a prefix are pinned beside them (B3): a gate that
    /// counted only word operands passed every case above.
    @Test("The refused line shows only when something searchable was refused, never for punctuation typed on the way to a query")
    func refusedLineNeedsSomethingSearchable() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }

        for text in ["\"", "(", "=", "-(", "NEAR()", "?"] {
            var params = SearchParameters(keywords: text)
            #expect(params.hasTextTerms, "\(text): precondition, it counts as text")
            #expect(SearchService.parsedQuery(for: params).expression == nil, "\(text): precondition, the parse is nil")
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(!inspection.isRefused, "\(text): nothing searchable was refused, so neither reason would be true")
            #expect(!inspection.showsStrip, "\(text): and there is nothing to say")
            // Beside a standalone filter the search still throws, so it is not filters only either.
            params.personRef = "#p-acheson"
            let filtered = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(!filtered.isRefused && !filtered.isFilterOnly && !filtered.showsStrip, "\(text): beside a filter")
        }

        let limit = FTS5InlineQueryParser.maximumGroupDepth
        func nested(_ inner: String, _ levels: Int) -> String {
            String(repeating: "(", count: levels) + inner + String(repeating: ")", count: levels)
        }
        let refused: [(label: String, params: SearchParameters)] = [
            ("exclusions only", SearchParameters(keywords: "-europe")),
            ("an approximation that matches nothing", SearchParameters(keywords: "-(containment -europe) -europe")),
            ("one level past the limit", SearchParameters(keywords: nested("europe", limit + 1))),
            ("exclusions only, at the limit", SearchParameters(keywords: nested("-europe", limit))),
            ("punctuation beside a restored exclusion", SearchParameters(keywords: "(", excludedTerms: ["europe"])),
            ("an excluded group holding an operator word", SearchParameters(keywords: "-(or)")),
            ("NOT before a group holding an operator word", SearchParameters(keywords: "NOT (AND)")),
            ("an excluded phrase", SearchParameters(keywords: "-\"cold war\"")),
            ("an excluded prefix", SearchParameters(keywords: "-negoti*")),
        ]
        for (label, params) in refused {
            #expect(SearchService.parsedQuery(for: params).expression == nil, "\(label): precondition, the parse is nil")
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            #expect(inspection.isRefused && inspection.showsStrip, "\(label): the query cannot run, and the strip says so")
        }

        // Control: at the limit a query renders, so the depth that refuses is the parser's own.
        let atLimit = await inspector.inspect(parameters: SearchParameters(keywords: nested("europe", limit)),
                                              indexedVolumeCount: 1)
        #expect(atLimit.expression != nil && !atLimit.isRefused)
    }

    /// A3's model half: `QueryInspector.Inputs`, the iOS refresh key, holds exactly the `SearchParameters` fields the
    /// passes read. Every stored field is enumerated, so one added later fails here until it is placed on a side; each
    /// read field moves the inputs; and each unread field leaves both the inputs and what the passes produce unchanged —
    /// checked by running them, since a field a pass started to read would still leave the inputs equal.
    /// `SearchViewTests.inspectorRefreshKeyIgnoresDisplayOnlyFields` drives the same rule through the view model.
    ///
    /// Round 3 (A5): each unread field is run against a base where reading it would change a number. Round 2 changed all
    /// four on a query with no person filter and no user tag, where re-resolving `personAnchor`, looking a person up by
    /// `personLabel`, or scoping user tags by `projectId` alters no filter, so a pass that started to read any of them
    /// still passed. Here the anchor and the label name a person whose rollup counts differently from, and shares no
    /// document with, the one `personRollupId` filters on, and the project sits beside a user tag whose filter changes
    /// the counts — each difference asserted before the unread field is changed. `booleanMode` keeps the plain base: the inline parser is
    /// the only thing that could read it, and a parse that did would render a different expression.
    @Test("The refresh inputs hold exactly the parameter fields the inspection reads")
    func inputsHoldExactlyWhatTheInspectionReads() async throws {
        let (dir, inspector, pipeline) = try await makeFixture(xml: personAndTagVolumeXML())
        defer { cleanUp(dir) }
        try await pipeline.consolidatePersonRollup()

        let read: [String: (inout SearchParameters) -> Void] = [
            "keywords": { $0.keywords = "europe" },
            "phrase": { $0.phrase = "cold war" },
            "excludedTerms": { $0.excludedTerms = ["korea"] },
            "prefixWildcard": { $0.prefixWildcard = "negoti" },
            "dateRange": { $0.dateRange = DateRange(earliest: "1950-01-01", latest: "1951-01-01") },
            "yearKeys": { $0.yearKeys = ["1950"] },
            "subjectTagIds": { $0.subjectTagIds = ["t"] },
            "userTagIds": { $0.userTagIds = ["u"] },
            "volumeIds": { $0.volumeIds = ["vol1"] },
            "documentIds": { $0.documentIds = ["vol1/d1"] },
            "subjectBucket": { $0.subjectBucket = 3 },
            "subjectBucketKey": { $0.subjectBucketKey = "A\u{1F}B" },
            "subjectRef": { $0.subjectRef = "rec00812a40defabcb" },
            "subjectName": { $0.subjectName = "Containment" },
            "excludeDocumentIds": { $0.excludeDocumentIds = ["vol1/d1"] },
            "includeDocumentText": { $0.includeDocumentText = false },
            "includeSummaries": { $0.includeSummaries = false },
            "includeNotes": { $0.includeNotes = false },
            "documentTypeFilter": { $0.documentTypeFilter = .documentsOnly },
            "personRef": { $0.personRef = "p1" },
            "personRollupId": { $0.personRollupId = 1 },
            "includeFrontMatter": { $0.includeFrontMatter = false },
        ]
        let plain = SearchParameters(keywords: "containment europe")
        let stored = Set(Mirror(reflecting: plain).children.compactMap(\.label))
        let unreadFields: Set<String> = ["booleanMode", "personLabel", "personAnchor", "projectId"]
        #expect(stored.count == 26, "precondition: SearchParameters' stored fields, as enumerated")
        #expect(stored == Set(read.keys).union(unreadFields), "every stored field is either read or not, and says which")
        #expect(Set(read.keys).isDisjoint(with: unreadFields))

        for (field, change) in read {
            var changed = plain
            change(&changed)
            #expect(changed != plain, "\(field): precondition, the change is a change")
            #expect(QueryInspector.Inputs(changed) != QueryInspector.Inputs(plain), "\(field) is read, so it moves the key")
        }

        func counts(_ params: SearchParameters) async -> [Int?] {
            let inspection = await inspector.inspect(parameters: params, indexedVolumeCount: 1)
            return await inspector.scopedCounts(for: inspection, parameters: params).map(\.scopedCount)
        }
        #expect(await counts(plain) == [2, 2], "precondition: containment d1 and d2, europe d1 and d3")

        // The two people: Kennan is mentioned in d1 and d2, Acheson in d3 alone. Their rollups count differently and share
        // no document, so a pass that re-resolved the anchor, filtered on it, or looked the person up by the label would
        // change the numbers below.
        let people = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
        let kennan = try #require(try await people.rollupEntry(forVolumeId: "vol1", ref: "p_kennan")?.rollupId)
        let acheson = try #require(try await people.rollupEntry(forVolumeId: "vol1", ref: "p_acheson")?.rollupId)
        var personBase = plain
        personBase.personRollupId = kennan
        personBase.personLabel = "Kennan, George F."
        personBase.personAnchor = PersonRollupAnchor(volumeId: "vol1", ref: "p_kennan")
        var otherPerson = plain
        otherPerson.personRollupId = acheson
        #expect(await counts(personBase) == [2, 1], "precondition: Kennan's rollup filters to d1 and d2")
        #expect(await counts(otherPerson) == [0, 1], "precondition: Acheson's rollup counts differently, d3 alone")

        // The tag: d1 alone carries u1. Dropping the tag filter, or matching no tag, changes the numbers below.
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d1", userTagIds: "u1")
        var tagBase = plain
        tagBase.userTagIds = ["u1"]
        #expect(await counts(tagBase) == [1, 1], "precondition: the u1 tag filters to d1")
        #expect(await counts(plain) == [2, 2], "precondition: without the tag filter, d1 to d3")

        let unread: [(field: String, base: SearchParameters, change: (inout SearchParameters) -> Void)] = [
            ("booleanMode", plain, { $0.booleanMode = .or }),
            ("personLabel", personBase, { $0.personLabel = "Acheson, Dean" }),
            ("personAnchor", personBase, { $0.personAnchor = PersonRollupAnchor(volumeId: "vol1", ref: "p_acheson") }),
            ("projectId", tagBase, { $0.projectId = UUID() }),
        ]
        #expect(Set(unread.map(\.field)) == unreadFields)
        for (field, base, change) in unread {
            var changed = base
            change(&changed)
            #expect(changed != base, "\(field): precondition, the change is a change")
            #expect(QueryInspector.Inputs(changed) == QueryInspector.Inputs(base), "\(field) is not read, so the key holds")
            let baseInspection = await inspector.inspect(parameters: base, indexedVolumeCount: 1)
            let baseCounts = await counts(base)
            let inspection = await inspector.inspect(parameters: changed, indexedVolumeCount: 1)
            #expect(inspection == baseInspection, "\(field): the inspection is the same")
            #expect(await counts(changed) == baseCounts, "\(field): and so are the scoped counts")
        }
    }

    /// The fixture's four documents with two people and a persons list, for the checks that need a person filter to
    /// matter: *Kennan* is mentioned in d1 and d2, *Acheson* in d3. The words the counts read are the plain fixture's.
    private func personAndTagVolumeXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>vol1</title></titleStmt>
          <publicationStmt><date>1950</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1"><head>1. Memorandum</head>
              <p>The doctrine of containment shaped policy toward europe, wrote <persName ref="p_kennan">Kennan</persName>.</p></div>
            <div type="document" xml:id="d2"><head>2. Telegram</head>
              <p>We must contain the threat, and contain it quickly, said <persName ref="p_kennan">Kennan</persName>.</p></div>
            <div type="document" xml:id="d3"><head>3. Report</head>
              <p>Economic recovery in europe proceeded, <persName ref="p_acheson">Acheson</persName> reported.</p></div>
            <div type="document" xml:id="d4"><head>4. Alliance Politics</head>
              <p>The atlantic alliance and its alliances were debated.</p></div>
            <div type="persons"><list>
              <item xml:id="p_kennan">Kennan, George F.: Diplomat.</item>
              <item xml:id="p_acheson">Acheson, Dean: Secretary of State.</item>
            </list></div>
          </body></text>
        </TEI>
        """
    }

    /// A4: `refresh` cleared `emptyConjuncts` on every run, and the zero-result decomposition is keyed on the executed
    /// search, not on the refresh. So a filter change that re-ran a still-empty search could have its new blame wiped by
    /// the refresh landing after it, and the zero-result view fell back to "each of your terms matches something on its
    /// own", which nothing measured. A refresh whose operands are unchanged leaves the blame to the decomposition.
    ///
    /// Round 3 pins what "the operands" means, each against a rule that passed round 2's test (B1, C3, C24): the parsed
    /// operands, marks included, so flipping `formosa` to `-formosa` over the same words clears the blame; not the
    /// inspected rows, whose scoped counts a request for counts fills in, so a filter change after counting keeps it; and
    /// not the expression, which a scope toggle re-renders over the same operands, so that keeps it too.
    @Test("A refresh after a filter-only change keeps the zero-result blame; a refresh after editing the terms clears it")
    @MainActor
    func refreshKeepsBlameWhenTheOperandsAreUnchanged() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }
        let service = inspector.searchService

        let controller = QueryInspectorController()
        var params = SearchParameters(keywords: "formosa europe")
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        await controller.decomposeZeroResult(parameters: params, service: service)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"], "precondition: formosa is blamed")

        // Counted first, so the rows the next refresh replaces carry scoped counts its own rows lack.
        await controller.loadScopedCounts(parameters: params, service: service)
        #expect(controller.inspection?.operands.map(\.scopedCount) == [0, 2], "precondition: the counts filled in")
        params.volumeIds = ["vol1"]
        #expect(try await service.searchCount(parameters: params) == 0, "precondition: the narrowed search is still empty")
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"],
                "the same terms under a different filter: the blame is the decomposition's to replace, not the refresh's")

        // A scope toggle re-renders the user-content expression over the same operands.
        let expressionBefore = controller.inspection?.expression
        params.includeNotes = false
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        #expect(controller.inspection?.expression != expressionBefore, "precondition: the scope change moved the expression")
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"], "a scope change keeps the blame, as a filter change does")

        // The same words with formosa now excluded: the blame names a term the query no longer searches for.
        params.keywords = "-formosa europe"
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        #expect(controller.inspection?.operands.map(\.operand.text) == ["formosa", "europe"], "precondition: the same words")
        #expect(controller.emptyConjuncts.isEmpty, "an excluded term is never the reason a query is empty")

        params.keywords = "formosa europe"
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        await controller.decomposeZeroResult(parameters: params, service: service)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"], "precondition: blamed again")
        await controller.refresh(parameters: SearchParameters(keywords: "containment europe"), service: service,
                                 indexedVolumeCount: 1)
        #expect(controller.emptyConjuncts.isEmpty, "a blame naming a term the query no longer has would mislead")
    }

    /// Round 3 (A3): `decomposeZeroResult` counted the operands of the controller's inspection, which both hosts refresh
    /// from the text in the field, under the parameters of the search that ran. On macOS the two differ whenever text is
    /// typed without Return — submit `formosa europe`, type ` zzzasia`, change a filter — so the blame could name a term
    /// the empty search never held, and round 2's A4 kept that blame through the filter change's refresh. The
    /// decomposition now parses the parameters it is given.
    @Test("The zero-result blame names terms of the query that ran, not of the text in the field")
    @MainActor
    func zeroResultBlameDecomposesTheExecutedQuery() async throws {
        let (dir, inspector) = try await makeFixture()
        defer { cleanUp(dir) }
        let service = inspector.searchService
        let controller = QueryInspectorController()

        var submitted = SearchParameters(keywords: "formosa europe")
        var live = SearchParameters(keywords: "formosa europe zzzasia")
        #expect(try await service.searchCount(parameters: submitted) == 0, "precondition: the search that ran is empty")
        await controller.refresh(parameters: live, service: service, indexedVolumeCount: 1)
        #expect(controller.inspection?.operands.map(\.operand.text) == ["formosa", "europe", "zzzasia"],
                "precondition: the field holds a term the search never ran")
        await controller.decomposeZeroResult(parameters: submitted, service: service)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"],
                "zzzasia matches nothing either, but the search that came back empty never held it")

        // The filter change: the decomposition of the re-run lands, then the refresh of the unchanged field keeps it.
        submitted.volumeIds = ["vol1"]
        live.volumeIds = ["vol1"]
        await controller.decomposeZeroResult(parameters: submitted, service: service)
        await controller.refresh(parameters: live, service: service, indexedVolumeCount: 1)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"], "and what is kept names only what ran")

        // A field holding fewer terms than ran: every term of the executed query is still measured.
        await controller.refresh(parameters: SearchParameters(keywords: "europe"), service: service, indexedVolumeCount: 1)
        await controller.decomposeZeroResult(parameters: submitted, service: service)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"], "formosa ran and matched nothing, whatever the field now holds")
    }

    /// A3's host half: each host hands the decomposition the parameters of the search that ran. The iOS host passed the
    /// live `vm.searchParameters`, which differ from what ran once the researcher types after a search completes.
    @Test("Both hosts decompose the zero result under the submitted parameters")
    func hostsDecomposeTheSubmittedQuery() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for (host, model) in [("FRUSExplorer/Search/SearchView.swift", "vm"), ("FRUSExplorer/App/SearchSheet.swift", "searchVM")] {
            let source = try String(contentsOf: root.appendingPathComponent(host), encoding: .utf8)
            #expect(source.range(
                of: #"inspectorController\.decomposeZeroResult\(\s*parameters: "# + model + #"\.submittedSearchParameters,"#,
                options: .regularExpression) != nil,
                    "\(host) must decompose the executed query")
            #expect(source.components(separatedBy: "inspectorController.decomposeZeroResult(").count == 2,
                    "\(host): and decompose it once")
        }
    }

    /// F7: the inspection reads the combined parse of the typed text and a restored search's phrase, prefix and
    /// excluded terms, but the iOS host refreshed it only when `vm.keywords` changed — so Clear Filters could remove a
    /// restored phrase and leave the strip describing the search before it. macOS keys the same refresh on
    /// `queryText|parametersVersion`. The key now lives on the view model, where `SearchViewTests` runs it.
    @Test("The iOS inspector refreshes on the view model's whole-query key, not on the typed text alone")
    func iOSInspectorRefreshesOnEveryQueryPart() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Search/SearchView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.range(
            of: #"\.task\(id: vm\.queryInspectorRefreshKey\) \{\s*await inspectorController\.refresh\(\s*parameters: vm\.searchParameters,"#,
            options: .regularExpression) != nil,
                "the one refresh of the cheap pass must be keyed on vm.queryInspectorRefreshKey")
        #expect(source.components(separatedBy: "inspectorController.refresh(").count == 2,
                "and there must be no second refresh keyed on something narrower")
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
