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

// MARK: - MacSearchWithinResultsWiringTests

/// Search Within These Results in the Mac's Search window (#1577 lane 5), read from source.
///
/// `MacSearchViewModel` and `MacSearchWindowView` are compiled for the Mac alone and this target runs on iOS, so no
/// test here runs them. The rules they follow are shared types' and are driven in `SearchLayerHoldingRulesTests` and,
/// through the iPhone's view model, in `SearchWithinResultsModelTests`. What is pinned here is that the Mac's window
/// calls them where the assessment's lane 5 says: the held list is built from `displayedResults`; the four values a
/// search runs with call the gate composer and nothing writes the list into `parameters`; `applyParameters` leaves the
/// list; the filter summary and the token caption are given `parameters`; the trigger runs nothing for a list put back
/// and nothing for an empty field inside one; no search inside a list re-anchors the checklist; and the toolbar button,
/// the row and the label are mounted where the design puts them; and #1683's lines in these files, the checklist's
/// marks, a highlighted row's colours and the Reading picker's dimming. Each scan matches a call, read with comments
/// set aside, never a window of text. What the window then does was walked in the running Mac check copy, and the pull
/// request lists it.
///
/// Version history:
///   1.0 — #1577 lane 5: initial implementation
///   1.1 — #1577 lane 6: a list cut at its ceiling is ranked whole, and the trail signs the set it ranked inside
@Suite("Search within results on the Mac, the wiring (#1577 lane 5)")
struct MacSearchWithinResultsWiringTests {

    private static let model = "FRUSExplorer/App/MacSearchViewModel.swift"
    private static let window = "FRUSExplorer/App/SearchSheet.swift"

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `text` without its comment lines.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// `text` without its comment lines, each line trimmed, the empty ones dropped.
    private static func codeLines(_ text: String) -> [String] {
        code(text).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// `text` with every run of whitespace removed.
    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    /// `text` without its comment lines and with every run of whitespace removed.
    private static func squeezedCode(_ text: String) -> String { squeezed(code(text)) }

    /// The text of the declaration that starts with `header`, through its closing brace.
    private static func declaration(_ header: String, in path: String) throws -> String {
        let source = try Self.source(path)
        let start = try #require(source.range(of: header), "\(path) no longer declares `\(header)`")
        var depth = 0
        var opened = false
        var index = start.lowerBound
        while index < source.endIndex {
            let character = source[index]
            if character == "{" { depth += 1; opened = true }
            if character == "}" { depth -= 1 }
            index = source.index(after: index)
            if opened && depth == 0 { break }
        }
        #expect(opened && depth == 0, "\(path): `\(header)` has no balanced body")
        return String(source[start.lowerBound..<index])
    }

    // MARK: Holding a list

    /// The list is the one on screen: `displayedResults`, by `PinnedResultBase`'s rules, which keep the search's order
    /// and the review's phrase-list finding. The submitted words empty with the field: the engine is part of this
    /// window's search trigger, so with the words left the switch would run the list's own words through the other
    /// engine at once (the assessment's first Mac trap).
    @Test("The window holds the list shown, by the rules iPhone and iPad hold one by, and empties the submitted words")
    func holdingTakesTheListShown() throws {
        let hold = Self.squeezedCode(try Self.declaration(
            "func holdBase(meaningAvailable: Bool) -> PinnedResultBase? {", in: Self.model))
        for call in ["guard let direction = layerDirection(meaningAvailable: meaningAvailable) else { return nil }",
                     "let members = PinnedResultBase.members(of: results, shown: displayedResults)",
                     "PinnedResultBase.kind(route: executedRoute, query: query, ran: ran,",
                     "browseName: PinnedResultBase.browseName(of: ran ?? parameters))",
                     "let ran = userTagCountScope?.ranParameters",
                     "filterSignature: filterSignatureOfTheRows ?? SearchScopeSignature.signature(for: parameters),",
                     "completedSearchAnchor: lastCompletedSearchAnchor,",
                     "pinnedBase = base",
                     "baseRowsVersion = executedSearchVersion",
                     "historyAnchor = nil",
                     "searchMode = direction.fieldEngine",
                     "queryText = \"\"",
                     "submittedQuery = \"\""] {
            #expect(hold.contains(Self.squeezed(call)), "holdBase(meaningAvailable:) lost `\(call)`")
        }
        let direction = Self.squeezedCode(try Self.declaration(
            "func layerDirection(meaningAvailable: Bool) -> SearchLayerDirection? {", in: Self.model))
        #expect(direction.contains(Self.squeezed("""
            guard pinnedBase == nil, !isSearching, searchError == nil, !displayedResults.isEmpty,
                  let direction = SearchLayerDirection.starting(over: executedRoute) else { return nil }
            if direction == .rankByMeaning, !meaningAvailable { return nil }
            """)), "a layer starts over a list from one engine, with no list held, no search under way and no error")
    }

    // MARK: The gate

    /// The four values a search runs with call the composer, and only they and the Meaning strip's count do. A pin
    /// written into `parameters` would reach the filter summary, which calls a gate "project" when Advanced… has never
    /// been opened, and the token caption, "also narrowed by a document scope — see Advanced" (rule 3).
    @Test("The four values a search runs with gate it to the held list, and nothing writes the list into the parameters")
    func theFourSitesCallTheComposer() throws {
        for (header, call) in [
            ("var liveSearchParameters: SearchParameters {",
             "var params = LayeredResultComposer.gating(parameters, inside: pinnedBase)"),
            ("var submittedSearchParameters: SearchParameters {",
             "var params = LayeredResultComposer.gating(parameters, inside: pinnedBase)"),
            ("func performSearch(service: SearchService?) async -> Bool {",
             "var params = LayeredResultComposer.gating(parameters, inside: base)"),
            ("private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)",
             "parameters: LayeredResultComposer.gating(parameters, inside: base))"),
        ] {
            let body = Self.squeezedCode(try Self.declaration(header, in: Self.model))
            #expect(body.contains(Self.squeezed(call)), "`\(header)` does not gate its value by the composer")
        }
        let model = Self.code(try Self.source(Self.model))
        // Since #1577 lane 6 a list cut at its ceiling is ranked inside its whole match, which the property names first
        // (`aCutListIsRankedWhole` reads that branch); every other list, as here, by the composer's gate.
        #expect(Self.squeezedCode(try Self.declaration("var documentSetSize: Int? {", in: Self.model)).contains(
            Self.squeezed("return LayeredResultComposer.gating(parameters, inside: pinnedBase).documentIds?.count")),
                "the Meaning strip names a set other than the one a ranking runs inside")
        #expect(model.components(separatedBy: "LayeredResultComposer.gating(").count - 1 == 5,
                "a value a search runs with is gated somewhere this test does not read")
        #expect(!model.contains("memberKeys"), "the held list's keys reach a search through the composer alone")
        // Every write of the stored parameters, or of their document gate, is one of four, none of them the list's.
        let writes = Self.codeLines(model).filter { $0.hasPrefix("parameters = ") || $0.hasPrefix("parameters.documentIds ") }
        #expect(writes.count == 4, "the parameters are written in \(writes.count) places: \(writes)")
        #expect(writes.allSatisfy {
            $0 == "parameters = params.runningInside(workingCorpus: filterVM?.appliedWorkingCorpusKeys)"
                || $0 == "parameters.documentIds        = scoped.documentIds"
        }, "the stored parameters are given a gate that is not the corpus's or the project's: \(writes)")
        // The keyword run reads the held list once, before its wait, and gates and composes by that one value.
        let perform = Self.codeLines(try Self.declaration("func performSearch(service: SearchService?) async -> Bool {",
                                                          in: Self.model))
        let read = try #require(perform.firstIndex(of: "let base = pinnedBase"))
        let wait = try #require(perform.firstIndex { $0.contains("await ") && !$0.hasPrefix("return ") })
        #expect(read < wait, "the held list is read after the run's first wait")
        #expect(perform.filter { $0.contains("pinnedBase") }.count == 2,
                "the run reads the held list in more places than its empty-field guard and its one read")
    }

    /// The filter summary and the token caption read `parameters`, so the list is never named by them.
    @Test("The filter summary and the token caption are given the parameters, which never hold the list")
    func filterSummaryAndCaptionReadTheParameters() throws {
        let summary = Self.code(try Self.declaration("var activeFilterSummary: String? {", in: Self.model))
        #expect(summary.contains("if parameters.documentIds != nil {"))
        for name in ["pinnedBase", "gating(", "submittedSearchParameters", "liveSearchParameters", "documentSetSize"] {
            #expect(!summary.contains(name), "the filter summary reads `\(name)`, which can hold the list")
        }
        let window = Self.code(try Self.source(Self.window))
        #expect(window.contains("SearchFilterTokens.tokens(parameters: searchVM.parameters, labels: filterTokenLabels)"))
        #expect(Self.squeezed(window).contains(Self.squeezed(
            "SearchFilterTokens.caption(parameters: searchVM.parameters, hasTokens: !filterTokens.isEmpty)")))
        #expect(!window.contains("LayeredResultComposer") && !window.contains("memberKeys"),
                "the window gates a value of its own")
    }

    // MARK: Leaving

    @Test("A hand-off or a recalled search leaves the held list before it takes its parameters")
    func handOffsLeaveTheList() throws {
        let apply = Self.codeLines(try Self.declaration("func applyParameters(_ params: SearchParameters) {", in: Self.model))
        #expect(apply.dropFirst().first == "leaveBaseForHandoff()", "applyParameters does not leave the held list first")
        let leave = Self.squeezedCode(try Self.declaration("private func leaveBaseForHandoff() {", in: Self.model))
        #expect(leave.contains(Self.squeezed("foldShownTagsIntoBase() guard let base = pinnedBase else { return } dropBase() restoreRows(of: base)")))
        #expect(leave.contains(Self.squeezed("if let sort = sortOrderBeforeBase { sortOrder = sort }")),
                "a hand-off loses the sort a ranking set aside")
        let drop = Self.squeezedCode(try Self.declaration("private func dropBase() {", in: Self.model))
        #expect(drop.contains(Self.squeezed("pinnedBase = nil")) && drop.contains(Self.squeezed("historyAnchor = base.historyAnchor")))
        let handoff = Self.squeezedCode(try Self.declaration("func applyHandoff(_ params: SearchParameters) {", in: Self.model))
        #expect(handoff.contains(Self.squeezed("""
            let heldListEngine = pinnedBase?.direction.baseEngine
            if namesASearch { searchMode = .keywords }
            applyParameters(params)
            if !namesASearch, let heldListEngine { searchMode = heldListEngine }
            """)), "a hand-off that runs nothing leaves the field's engine over the list's rows")
        let rebuilt = Self.code(try Self.declaration(".onChange(of: appState.indexGeneration) {", in: Self.window))
        #expect(rebuilt.contains("searchVM.letGoOfBaseForRebuiltIndex()"), "a rebuilt index leaves the old index's list held")
    }

    /// Leaving puts the list's engine and words back, which changes this window's search trigger; the restored rows
    /// answer that search unless a filter changed since. Rows put back must not write the submitted words: inside a
    /// held list that would run the list's words through the field's engine.
    @Test("Leaving puts back the list, its engine and its words, and answers the trigger only for the filters it was found under")
    func leavingAnswersTheTrigger() throws {
        let leave = Self.squeezedCode(try Self.declaration("func leaveBase() -> Bool {", in: Self.model))
        #expect(leave.contains(Self.squeezed("""
            dropBase()
            restoreRows(of: base)
            searchMode = base.direction.baseEngine
            queryText = base.query
            submittedQuery = base.query
            """)))
        #expect(leave.contains(Self.squeezed("""
            guard base.wasFound(under: parameters) else { return false }
            answeredTrigger.answer(searchTrigger)
            return true
            """)), "the rows put back answer the trigger whatever the filters, or never")
        let restore = Self.codeLines(try Self.declaration("private func restoreRows(of base: PinnedResultBase) {", in: Self.model))
        #expect(!restore.contains { $0.hasPrefix("submittedQuery") || $0.hasPrefix("queryText") || $0.hasPrefix("searchMode") },
                "rows put back inside a held list change the search trigger")
        for statement in ["results = base.rows", "executedRoute = base.route", "totalMatchCount = base.totalMatchCount",
                          "lastFetchLimit = base.fetchLimit", "lastCompletedSearchAnchor = base.completedSearchAnchor",
                          "userTagCountScope = base.userTagCountScope", "executedSearchVersion &+= 1"] {
            #expect(restore.contains(statement), "restoreRows(of:) does not put back `\(statement)`")
        }
        let window = Self.squeezedCode(try Self.declaration("private func leaveBase() {", in: Self.window))
        #expect(window.contains(Self.squeezed("if searchVM.leaveBase() { facetController.invalidate(signature: searchVM.searchTrigger) }")),
                "the facets go on describing the layer over the rows put back")
    }

    // MARK: The search

    /// The search task's first steps, in order: number the run; do nothing for rows that answer it; carry the shown
    /// rows' tags into the list; and inside a held list an empty field shows the list's rows, before the engine is chosen.
    @Test("The search runs nothing for rows put back, and an empty field inside a held list shows the list")
    func theTriggerAndTheEmptyField() throws {
        let perform = Self.codeLines(try Self.declaration("func performSearch(service: SearchService?) async -> Bool {",
                                                          in: Self.model))
        let order = ["let run = searchRuns.startRun()",
                     "if answeredTrigger.consume(searchTrigger) { return false }",
                     "foldShownTagsIntoBase()",
                     "if pinnedBase != nil, submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {",
                     "guard isSearching || !isShowingBase || searchError != nil else { return false }",
                     "showBaseRows()",
                     "return true",
                     "if searchMode == .meaning {"]
        let found = order.map { line in perform.firstIndex(of: line) }
        #expect(found.allSatisfy { $0 != nil }, "performSearch lost one of \(order)")
        let indices = found.compactMap { $0 }
        #expect(indices == indices.sorted() && indices.count == order.count, "performSearch's first steps are out of order")
        let show = Self.squeezedCode(try Self.declaration("private func showBaseRows() {", in: Self.model))
        #expect(show.contains(Self.squeezed("restoreRows(of: base) baseRowsVersion = executedSearchVersion")))
        let meaning = Self.squeezedCode(try Self.declaration("private func performMeaningSearch(run: Int) async -> Bool {",
                                                             in: Self.model))
        #expect(meaning.contains(Self.squeezed("""
            if let base = pinnedBase {
                return try await rankHeldList(run: run, base: base, backend: backend)
            }
            let outcome = try await backend.run(query: query, parameters: parameters)
            """)), "a question over a held list runs the plain Meaning search")
    }

    /// Words found in a held Meaning list keep its order and scores, and record no total; a ranking keeps the list's
    /// ceiling and total. The rules are `LayeredResultComposer`'s, driven in `SearchLayeringTests`.
    @Test("Words found in a held list are composed in its order, and a ranking keeps its list's ceiling and total")
    func layersComposeTheirRows() throws {
        let perform = Self.squeezedCode(try Self.declaration("func performSearch(service: SearchService?) async -> Bool {",
                                                             in: Self.model))
        #expect(perform.contains(Self.squeezed("let filtersNarrowed = base?.filtersNarrow(parameters) ?? false")))
        #expect(perform.contains(Self.squeezed("""
            if let base {
                results = LayeredResultComposer.wordsInMatches(keywordRows: fetched, base: base)
                executedRoute = .wordsInMatches(base: base.members.count)
                endSelecting()
                lastLayerFiltersNarrowed = filtersNarrowed
            } else {
            """)))
        #expect(perform.contains(Self.squeezed("if base != nil { totalMatchCount = nil } else if let total = counted {")),
                "a layer records the whole match's count, which a capture would read back as its own")
        #expect(perform.contains(Self.squeezed(
            "lastRenderedExpression = base.map { inside in expression.map { $0 + inside.renderedExpressionSuffix } } ?? expression")))
        #expect(perform.contains(Self.squeezed("filterSignatureOfTheRows = SearchScopeSignature.signature(for: params)")))
        let rank = Self.squeezedCode(try Self.declaration(
            "private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)", in: Self.model))
        for statement in ["results = ranking.results",
                          "executedRoute = .rankedByMeaning(unranked: ranking.results.filter { $0.semanticScore == nil }.count)",
                          "totalMatchCount = base.totalMatchCount",
                          "lastFetchLimit = base.fetchLimit",
                          "lastRenderedExpression = SemanticSearchBackend.renderedExpression(rankingAll: base.members.count) + base.renderedExpressionSuffix",
                          "let ranking = try await backend.rerank(query: query, base: base.members,"] {
            #expect(rank.contains(Self.squeezed(statement)), "rankHeldList lost `\(statement)`")
        }
        let model = Self.code(try Self.source(Self.model))
        #expect(model.contains(
            ".describingLayer(over: pinnedBase, filtersNarrowed: lastLayerFiltersNarrowed, sortOrder: sortOrder)"),
                "the Mac's scope says a layer's sentences by a rule of its own")
        #expect(model.contains(
            "LayeredResultComposer.unrankedTail(of: displayedResults, route: executedRoute, sortOrder: sortOrder)"))
    }

    /// A layer runs inside its list's search. The Mac's window anchors the checklist to a search before it runs, by
    /// its words: a layer's second query would clear the marks made on the list, so neither layer settles it.
    @Test("No search inside a held list re-anchors the checklist, and the checklist turned on inside one is the list's")
    func layersKeepTheChecklist() throws {
        let perform = Self.squeezedCode(try Self.declaration("func performSearch(service: SearchService?) async -> Bool {",
                                                             in: Self.model))
        #expect(perform.contains(Self.squeezed(
            "if base == nil { settleChecklist(for: ChecklistAnchor(query: query, parameters: params)) }")))
        let meaning = Self.squeezedCode(try Self.declaration("private func performMeaningSearch(run: Int) async -> Bool {",
                                                             in: Self.model))
        #expect(meaning.contains(Self.squeezed(
            "if pinnedBase == nil { settleChecklist(for: ChecklistAnchor(query: query, parameters: parameters)) }")))
        let settles = Self.codeLines(try Self.source(Self.model))
            .filter { $0.contains("settleChecklist(for:") && !$0.contains("func ") }
        #expect(settles.count == 2, "the checklist is settled in \(settles.count) places")
        let rank = Self.code(try Self.declaration(
            "private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)", in: Self.model))
        #expect(rank.contains("endSelecting()") && !rank.contains("settleSelection") && !rank.contains("settleChecklist"))
        let checklist = Self.squeezedCode(try Self.declaration("func setChecklistMode(_ on: Bool) {", in: Self.model))
        #expect(checklist.contains(Self.squeezed("""
            checklistAnchor = pinnedBase?.completedSearchAnchor
                ?? ChecklistAnchor(query: submittedQuery, parameters: submittedSearchParameters)
            """)))
    }

    /// A layer's trail row is its own and records the list it shows whole, signed with `base=`; the list's own row
    /// is set aside while one is held (rule 5). As on iPhone and iPad (`ResearchLoggingGateTests`).
    @Test("A layer's trail row records its rows whole and names its list")
    func aLayerRecordsItsRows() throws {
        let record = Self.squeezedCode(try Self.declaration("func recordSearchHistory(projectId: UUID?,", in: Self.model))
        for line in ["let layer = executedRoute.isLayer ? pinnedBase : nil",
                     "resultCount: layer != nil ? results.count : resultCountForDisplay,",
                     "matchCount: layer != nil ? results.count : totalMatchCount,",
                     "signatureOverride: SearchScopeSignature.layered(",
                     "parameters: submittedSearchParameters, base: layer),"] {
            #expect(record.contains(Self.squeezed(line)), "recordSearchHistory lost `\(line)`")
        }
    }

    // MARK: The window

    /// A titled toolbar button after Save as Working Corpus…, as the assessment's design puts it, with no shortcut,
    /// for the reason the toolbar's own comment gives: a shortcut waits for the Search command channel.
    @Test("The toolbar holds a list with a titled Search Within Results after Save as Working Corpus…, and no shortcut")
    func theToolbarButton() throws {
        let toolbar = try Self.declaration("private var searchToolbar: some ToolbarContent {", in: Self.window)
        let save = try #require(toolbar.range(of: "\"tray.full\""))
        let within = try #require(toolbar.range(of: "Label(SearchLayerCopy.searchWithinResults,"))
        let checklist = try #require(toolbar.range(of: "searchVM.setChecklistMode(!searchVM.checklistMode)"))
        #expect(save.upperBound < within.lowerBound && within.upperBound < checklist.lowerBound,
                "Search Within Results is not between Save as Working Corpus… and Checklist")
        let item = Self.squeezedCode(String(toolbar[save.upperBound..<checklist.lowerBound]))
        #expect(item.contains(Self.squeezed("""
            ToolbarItem(placement: .automatic) {
                let direction = searchVM.layerDirection(meaningAvailable: appState.semanticQuerySearcher != nil)
                Button {
                    holdBase()
                } label: {
            """)))
        // The help's call gained lane 6's `cutAt:`, which `aCutListIsRankedWhole` reads whole.
        for modifier in [".labelStyle(.titleAndIcon)", ".disabled(direction == nil)",
                         ".help(SearchLayerCopy.searchWithinResultsHelp(direction, isHolding: searchVM.pinnedBase != nil,"] {
            #expect(item.contains(Self.squeezed(modifier)), "the button lost `\(modifier)`")
        }
        #expect(!Self.code(toolbar).contains("keyboardShortcut"))
        let hold = Self.squeezedCode(try Self.declaration("private func holdBase() {", in: Self.window))
        #expect(hold.contains(Self.squeezed(
            "guard let base = searchVM.holdBase(meaningAvailable: appState.semanticQuerySearcher != nil) else { return }")))
        #expect(hold.contains("queryFieldFocused=true") && hold.contains(Self.squeezed(
            "AccessibilityNotification.Announcement(base.accessibilityLabel).post()")))
    }

    /// The row names the list where the corpus banner sits, under it; the control gives way to a label naming the
    /// engine; the field says what to type; and Save this search is off while a list is held (decision 4).
    @Test("The list is named under the corpus banner, a label takes the picker's place, and Save this search is off")
    func theRowAndTheLabel() throws {
        let body = Self.squeezedCode(try Self.declaration("private var loadedBody: some View {", in: Self.window))
        #expect(body.contains(Self.squeezed("WorkingOnBanner() workingCorpusBanner heldListRow Divider()")),
                "the held list is not named beside the corpus it runs inside")
        let row = Self.squeezedCode(try Self.declaration("private var heldListRow: some View {", in: Self.window))
        for call in ["if let base = searchVM.pinnedBase {", "Text(base.rowDescription)",
                     "if let leftOut = base.leftOutDescription {",
                     ".accessibilityLabel([base.accessibilityLabel, base.leftOutDescription]",
                     "leaveBase()", "defaultValue: \"Stop searching within these results\"",
                     ".accessibilityElement(children: .contain)"] {
            #expect(row.contains(Self.squeezed(call)), "the held list's row lost `\(call)`")
        }
        let input = Self.squeezedCode(try Self.declaration("private var searchInputRow: some View {", in: Self.window))
        #expect(input.contains(Self.squeezed("""
            if let base = searchVM.pinnedBase {
                heldEngineLabel(base.direction.fieldEngine)
            } else if appState.semanticQuerySearcher != nil {
                Picker(
            """)), "the Keywords | Meaning control does not give way to a label while a list is held")
        #expect(input.contains(Self.squeezed("searchVM.pinnedBase?.direction.fieldPrompt ?? searchVM.searchMode.fieldPrompt(")))
        #expect(input.contains(Self.squeezed("""
            .disabled(searchVM.submittedQuery.trimmingCharacters(in: .whitespaces).isEmpty
                      || searchVM.pinnedBase != nil)
            """)), "Save this search runs while a list is held")
        let label = Self.squeezedCode(try Self.declaration("private func heldEngineLabel(_ engine: SearchMode) -> some View {",
                                                           in: Self.window))
        #expect(label.contains(Self.squeezed("Text(engine.label)"))
                && label.contains(Self.squeezed(".help(SearchLayerCopy.heldEngineHelp(engine))")))
    }

    /// What the window draws for a held list's rows reads the view model's members: the facets' match, the capture's
    /// words, the count line's sentence, the layer's empty state and a ranking's unranked line.
    @Test("The window's facets, capture, count line, empty layer and unranked line read the view model's layer members")
    func theWindowReadsTheLayer() throws {
        let window = Self.code(try Self.source(Self.window))
        #expect(window.contains("parameters: searchVM.facetParameters,"),
                "a held list's facets aggregate the emptied field")
        #expect(window.contains("layerRoute: searchVM.facetLayerRoute)"))
        #expect(window.contains("queryText: searchVM.wordsOfTheRowsShown,"), "a capture of a held list records no words")
        let layer = try #require(window.range(of:
            "} else if let base = searchVM.pinnedBase, hasZeroResults, !searchVM.semanticNeedsModel {"))
        let meaning = try #require(window.range(of: "} else if searchVM.searchMode == .meaning && hasZeroResults {"))
        let keyword = try #require(window.range(of: "} else if hasZeroResults {"))
        #expect(layer.upperBound < meaning.lowerBound && meaning.upperBound < keyword.lowerBound,
                "a zero-state that diagnoses the library shows over a held list (rule 7)")
        let label = Self.squeezedCode(try Self.declaration("private var resultCountLabel: some View {", in: Self.window))
        #expect(label.contains(Self.squeezed("let layered = resultSetScope.route.isLayer")))
        #expect(label.contains(Self.squeezed("if layered { Text(resultSetScope.headerDescription)")))
        #expect(label.contains(Self.squeezed("let truncated = searchVM.isResultSetTruncated && !layered")))
        #expect(window.contains("if searchVM.isResultSetTruncated, !resultSetScope.route.isLayer {"))
        let list = Self.squeezedCode(try Self.declaration("private var resultsList: some View {", in: Self.window))
        #expect(list.contains(Self.squeezed("""
            let unrankedTail = searchVM.unrankedTail
            ForEach(searchVM.pagedResults, id: \\.id) { result in
            if result.id == unrankedTail?.firstId, let count = unrankedTail?.count {
                Text(SearchLayerCopy.unrankedHeader(count))
            """)))
        let bar = Self.squeezedCode(try Self.declaration("private var sortBar: some View {", in: Self.window))
        #expect(bar.contains(Self.squeezed("} else if !searchVM.queryText.isEmpty || searchVM.pinnedBase != nil {")),
                "a held list's rows are not counted while the field is empty")
        let empty = Self.squeezedCode(try Self.declaration("private func layerEmptyState(_ base: PinnedResultBase) -> some View {",
                                                           in: Self.window))
        #expect(empty.contains(Self.squeezed("searchLibrary: { searchVM.leaveBaseKeepingTheWords() },")))
        let model = Self.squeezedCode(try Self.source(Self.model))
        #expect(model.contains(Self.squeezed("if isShowingBase, let ran = pinnedBase?.ranParameters { return ran }")))
        #expect(model.contains(Self.squeezed("if isShowingBase, let base = pinnedBase { return base.query }")))
        #expect(model.contains(Self.squeezed("var facetLayerRoute: ExecutedSearchRoute? { executedRoute.isLayer ? executedRoute : nil }")))
        let keeping = Self.squeezedCode(try Self.declaration("func leaveBaseKeepingTheWords() {", in: Self.model))
        #expect(keeping.contains(Self.squeezed("dropBase() sortOrderBeforeBase = nil parametersVersion += 1")),
                "the words found nowhere in the list are not searched across the library")
    }

    // MARK: #1683, in this lane's files

    /// The Mac's window anchors its checklist to a search before the search runs, and keeps the last search's rows on
    /// screen until the new ones arrive: a mark made in that gap is kept under the new search. #1576 lane 4 closed it
    /// for the selection's Mark Reviewed; a row's Mark Reviewed and Mark Page Reviewed wait by the same rule now.
    @Test("A row's Mark Reviewed and Mark Page Reviewed wait for the rows of the search they mark (#1683)")
    func marksWaitForTheirRows() throws {
        let model = Self.squeezedCode(try Self.source(Self.model))
        #expect(model.contains(Self.squeezed("""
            var canMarkReviewed: Bool {
                checklistMode && (checklistAnchor?.isOnTheSearch(shown: lastCompletedSearchAnchor) ?? true)
            }
            """)))
        #expect(model.contains(Self.squeezed("var canMarkSelectionReviewed: Bool { canMarkReviewed }")))
        let mark = Self.squeezedCode(try Self.declaration("func markReviewed(volumeId: String, documentId: String) {",
                                                          in: Self.model))
        #expect(mark.contains(Self.squeezed("guard canMarkReviewed else { return }")))
        let bulk = Self.squeezedCode(try Self.declaration("func markReviewed(_ results: [SearchResult]) -> Int {",
                                                          in: Self.model))
        #expect(bulk.contains(Self.squeezed("guard canMarkReviewed else { return 0 }")))
        let window = Self.squeezedCode(try Self.source(Self.window))
        #expect(window.contains(Self.squeezed(
            "pageRowCount: activeReading.isPaged && searchVM.canMarkReviewed ? searchVM.pagedResults.count : 0,")))
        #expect(window.contains(Self.squeezed("""
            searchVM.markReviewed(volumeId: result.volumeId, documentId: result.documentId)
            } label: {
                Label(
                    String(localized: "search.checklist.markReviewed",
                           defaultValue: "Mark Reviewed"),
                    systemImage: "checklist"
                )
            }
            .disabled(!searchVM.canMarkReviewed)
            """)))
    }

    /// On the list's emphasised highlight, the accent fill, a row's location and chips were drawn in fixed colours and
    /// all but vanished (#1683); the title and the snippet, in `.primary` and `.secondary`, turn white by themselves. The
    /// row reads its background prominence and draws them through `tint(_:)` and `chipFill(_:opacity:)`, and no fixed
    /// colour is left on its text. And the Reading picker, which macOS 27 draws at full strength while it is off, is
    /// dimmed by the condition that turns it off. Both were walked in the check copy.
    @Test("A highlighted row draws its location and chips white, and the Reading picker is drawn dimmed while off (#1683)")
    func aHighlightedRowAndTheReadingPickerRead() throws {
        let row = Self.squeezedCode(try Self.declaration("private struct SearchResultRow: View {", in: Self.window))
        #expect(row.contains(Self.squeezed("@Environment(\\.backgroundProminence) private var backgroundProminence")))
        #expect(row.contains(Self.squeezed("backgroundProminence == .increased ? .white : color")))
        #expect(row.contains(Self.squeezed(
            "backgroundProminence == .increased ? .white.opacity(0.22) : color.opacity(opacity)")))
        for call in [".background(chipFill(.purple))", ".foregroundStyle(tint(.purple))",
                     ".background(chipFill(.teal))", ".foregroundStyle(tint(.teal))",
                     ".background(chipFill(Color.accentColor, opacity: 0.08))"] {
            #expect(row.contains(Self.squeezed(call)), "the row no longer draws `\(call)`")
        }
        // Twice: the location, and the tags.
        #expect(row.components(separatedBy: Self.squeezed(".foregroundStyle(tint(Color.accentColor))")).count - 1 == 2)
        for fixed in [".foregroundStyle(Color.accentColor)", ".foregroundStyle(.purple)", ".foregroundStyle(.teal)",
                      "Color.purple.opacity(", "Color.teal.opacity(", "Color.accentColor.opacity("] {
            #expect(!row.contains(Self.squeezed(fixed)), "the row draws `\(fixed)`, which a highlighted row does not change")
        }
        let toolbar = Self.squeezedCode(try Self.declaration("private var searchToolbar: some ToolbarContent {",
                                                             in: Self.window))
        #expect(toolbar.contains(Self.squeezed("""
            .disabled(searchVM.results.isEmpty || !searchVM.offersReadings)
            .opacity(searchVM.results.isEmpty || !searchVM.offersReadings ? 0.45 : 1)
            """)), "the Reading picker is dimmed by the condition that turns it off")
    }

    // MARK: A list cut at its ceiling (#1577 lane 6)

    /// A question over a list held at its 7,500-row ceiling ranks the list's whole match, as on iPhone and iPad, where
    /// `WholeMatchViewModelTests` runs the twin: the branch is the held list's own rule, the ranking is handed the
    /// parameters outside the list and its ceiling, its rows are written with the ranking's route and the list keeps the
    /// match's keys, and the trail signs the set ranked inside. The toolbar's help says so over a cut list.
    @Test("A list cut at its ceiling is ranked whole, by the iPhone's rule, and the trail signs the set it ranked inside (#1577 lane 6)")
    func aCutListIsRankedWhole() throws {
        let rank = Self.squeezedCode(try Self.declaration(
            "private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning)", in: Self.model))
        #expect(rank.contains(Self.squeezed("""
            if base.ranksWholeMatch, let ran = base.ranParameters {
                return try await rankWholeMatch(run: run, base: base, match: ran, backend: backend)
            }
            """)), "rankHeldList no longer hands a cut list to the whole-match ranking")
        let whole = Self.squeezedCode(try Self.declaration(
            "private func rankWholeMatch(run: Int, base: PinnedResultBase, match ran: SearchParameters,", in: Self.model))
        for statement in [
            "let whole = try await backend.rankWholeMatch(query: query, base: base, match: ran, parameters: parameters, limit: base.fetchLimit)",
            "guard searchRuns.isLatest(run) else { return false }",
            "pinnedBase?.keepWholeMatch(whole.matchKeys)",
            "results = whole.outcome.results",
            "executedRoute = .rankedByMeaning(unranked: whole.outcome.results.filter { $0.semanticScore == nil }.count, wholeMatch: whole.ranking)",
            "endSelecting()",
            "semanticDisclosure = whole.outcome.disclosure",
            "rankedSetSignature = whole.setSignature",
            "totalMatchCount = base.totalMatchCount",
            "lastFetchLimit = base.fetchLimit",
            "lastRenderedExpression = SemanticSearchBackend.renderedExpression(rankingAll: whole.ranking.size, listing: base.fetchLimit) + (pinnedBase ?? base).renderedExpressionSuffix",
            "executedSearchVersion &+= 1",
        ] {
            #expect(whole.contains(Self.squeezed(statement)), "rankWholeMatch lost `\(statement)`")
        }
        // Handed `parameters`, never the list's gated value: the gate a search inside the list runs with is its rows.
        #expect(!whole.contains("LayeredResultComposer.gating"), "the whole match is narrowed by the gate outside the list")
        #expect(!whole.contains("settleChecklist") && !whole.contains("settleSelection"),
                "a ranking inside a held list keeps the list's checklist")
        // The Meaning strip names the whole match a question would rank, or waits where only reading it could say.
        let size = Self.squeezedCode(try Self.declaration("var documentSetSize: Int? {", in: Self.model))
        #expect(size.contains(Self.squeezed(
            "if let base = pinnedBase, base.ranksWholeMatch { return base.wholeMatchSetSize(inside: parameters.documentIds) }")))
        let holds = Self.squeezedCode(try Self.declaration("var holdsTheMeaningStripBack: Bool {", in: Self.model))
        #expect(holds.contains(Self.squeezed(
            "isShowingBase && pinnedBase?.ranksWholeMatch == true && documentSetSize == nil")))
        #expect(Self.squeezedCode(try Self.source(Self.window)).contains(Self.squeezed("""
            if !searchVM.holdsTheMeaningStripBack {
                SemanticModeStrip(disclosure: searchVM.semanticDisclosure,
                                  beyondCount: searchVM.beyondLibraryHits.count,
                                  pendingSetSize: searchVM.documentSetSize)
            }
            """)), "the window holds the strip back over a cut list whose ranked set is not known")
        let signature = Self.squeezedCode(try Self.declaration("private var meaningSignature: String {", in: Self.model))
        #expect(signature.contains(Self.squeezed(
            "if case .rankedByMeaning(_, _?) = executedRoute, let rankedSetSignature { return rankedSetSignature }")))
        let record = Self.squeezedCode(try Self.declaration("func recordSearchHistory(projectId: UUID?,", in: Self.model))
        #expect(record.contains(Self.squeezed("lastRunWasSemantic ? meaningSignature : nil,")),
                "the trail signs a Meaning row through the whole match's signature")
        let toolbar = Self.squeezedCode(try Self.declaration("private var searchToolbar: some ToolbarContent {",
                                                             in: Self.window))
        #expect(toolbar.contains(Self.squeezed("""
            .help(SearchLayerCopy.searchWithinResultsHelp(
                direction, isHolding: searchVM.pinnedBase != nil,
                cutAt: searchVM.isResultSetTruncated ? searchVM.lastFetchLimit : nil))
            """)), "the toolbar's help says a question ranks a cut list whole")
    }
}
