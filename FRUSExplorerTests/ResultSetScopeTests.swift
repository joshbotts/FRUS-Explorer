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

// MARK: - ResultSetScopeTests

/// The sentences that name which set a surface is looking at.
///
/// Every one is a computed property on a value type precisely so it can be checked here — with no
/// search service, no fixture and no simulator. The alternative was four string literals at four
/// call sites, which is how the app came to use the word "results" for three different sets.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Result set scope")
struct ResultSetScopeTests {

    /// The iPhone shape: 1,000-document ceiling, no whole-query count.
    private func iOS(loaded: Int, shown: Int? = nil,
                     onPage: Int = 25, pages: Int = 1) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: 1_000,
                       totalMatchCount: nil, documentsOnPage: onPage, pageCount: pages)
    }

    /// The Mac shape: 7,500-document ceiling, and a real total.
    private func mac(loaded: Int, total: Int?, shown: Int? = nil,
                     onPage: Int = 25, pages: Int = 1) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: 7_500,
                       totalMatchCount: total, documentsOnPage: onPage, pageCount: pages)
    }

    /// A meaning search: the top-N nearest neighbours, and no total by construction.
    private func meaning(loaded: Int = 100, shown: Int? = nil,
                         onPage: Int = 25, pages: Int = 4) -> ResultSetScope {
        // 100 mirrors `SemanticSearchBackend.hitLimit`, which is `@MainActor` and so cannot be
        // read here. It is what both view models pass after a Meaning run (`lastFetchLimit`).
        // Nothing here depends on the value: no member reads `fetchLimit` for a Meaning search,
        // which `ResultSetScopeMeaningTests` checks across three ceilings.
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: 100,
                       totalMatchCount: nil, documentsOnPage: onPage, pageCount: pages,
                       route: .meaning)
    }

    // MARK: - A meaning search has no total to be unavailable (#1193)

    /// **The sentence the bug was.** With `totalMatchCount` nil and the fetch at its ceiling, the
    /// keyword grammar renders "100 loaded · total unavailable" — which says a number exists and
    /// could not be got. For a similarity ranking no number exists: every document is a match at
    /// some distance, and N is the shape of the answer rather than a ceiling it hit.
    @Test("A meaning search names the closest matches, not an unavailable total")
    func meaningSearchDoesNotClaimAnUnavailableTotal() {
        let scope = meaning()
        #expect(scope.headerDescription == "100 closest matches")
        #expect(!scope.headerDescription.contains("unavailable"),
                "a similarity ranking has no total, so none can be unavailable")
        #expect(!scope.headerDescription.contains("loaded"),
                "\"loaded\" belongs to the keyword grammar, where a larger match exists")
    }

    /// The keyword grammar is untouched — the same numbers still read the old way.
    @Test("The keyword grammar is unchanged by the meaning branch")
    func keywordGrammarIsUnchanged() {
        let capped = ResultSetScope(loaded: 100, shown: 100, fetchLimit: 100,
                                    totalMatchCount: nil, documentsOnPage: 25, pageCount: 4)
        #expect(capped.headerDescription.contains("total unavailable"),
                "a capped keyword fetch with no count still says so")
        #expect(iOS(loaded: 412).headerDescription == "412 results")
    }

    /// The clause is shared so the two platforms cannot word one fact differently — macOS renders
    /// it inside its own page-range dialect, iOS as the whole header.
    @Test("Both platforms draw the meaning clause from one place")
    func meaningClauseIsShared() {
        let scope = meaning(loaded: 100)
        #expect(scope.closestMatchesClause == "100 closest matches")
        #expect(scope.headerDescription == scope.closestMatchesClause)
    }

    /// An empty meaning search is still "No results" — the mode does not change that.
    @Test("A meaning search with nothing found still reads as no results")
    func emptyMeaningSearchIsUnchanged() {
        #expect(meaning(loaded: 0, onPage: 0, pages: 0).headerDescription == "No results")
    }

    // MARK: - Which set is which

    @Test("A fetch below its ceiling with no known total is complete")
    func completeFetch() {
        #expect(!iOS(loaded: 412).didHitFetchLimit)
    }

    @Test("A fetch at its ceiling is truncated")
    func cappedFetch() {
        #expect(iOS(loaded: 1_000).didHitFetchLimit)
        #expect(mac(loaded: 7_500, total: 195_519).didHitFetchLimit)
    }

    /// macOS's own `isResultSetTruncated` counts this case, so the type must too — otherwise a set
    /// that a filter reduced below the ceiling would be reported as the whole match.
    @Test("A known total above the fetch is truncated even below the ceiling")
    func totalExceedsFetchBelowCeiling() {
        #expect(mac(loaded: 300, total: 5_000).didHitFetchLimit)
        #expect(!mac(loaded: 300, total: 300).didHitFetchLimit)
    }

    @Test("Checklist-hidden documents are the gap between loaded and shown")
    func checklistGap() {
        #expect(iOS(loaded: 1_000, shown: 987).hiddenByChecklist == 13)
        #expect(iOS(loaded: 412).hiddenByChecklist == 0)
        // Never negative, whatever a host hands over.
        #expect(iOS(loaded: 10, shown: 99).hiddenByChecklist == 0)
    }

    // MARK: - Capture: the sentences with citation consequences

    @Test("A complete capture carries no truncation warning")
    func completeCaptureIsSilent() {
        #expect(iOS(loaded: 412).captureTruncationWarning == nil)
        #expect(iOS(loaded: 412).captureChecklistWarning == nil)
    }

    @Test("A capped capture says so, and names the total when it has one")
    func cappedCaptureWarns() throws {
        let withoutTotal = try #require(iOS(loaded: 1_000).captureTruncationWarning)
        #expect(withoutTotal.contains("1000") || withoutTotal.contains("1,000"))
        #expect(withoutTotal.contains("larger match"),
                "with no total it must not imply one is known")

        let withTotal = try #require(mac(loaded: 7_500, total: 195_519).captureTruncationWarning)
        #expect(withTotal.contains("195519") || withTotal.contains("195,519"))
    }

    @Test("A capture that checklist mode is filtering says what it will leave out")
    func checklistCaptureWarns() throws {
        let warning = try #require(iOS(loaded: 1_000, shown: 987).captureChecklistWarning)
        #expect(warning.contains("13"))
    }

    // MARK: - Capture: the record's own description

    @Test("A complete capture's stored description stays plain")
    func plainProvenance() {
        #expect(iOS(loaded: 412).captureProvenanceDescription == "Search results")
    }

    /// This string is written to `WorkingCorpus.sourceDescription` and syncs. A corpus read on
    /// another device, or a year later, has only this to say what it is a capture of.
    @Test("A truncated capture's stored description carries its truncation")
    func truncatedProvenance() {
        let iPhone = iOS(loaded: 1_000).captureProvenanceDescription
        #expect(iPhone.contains("highest-scoring"))
        #expect(iPhone.contains("1000") || iPhone.contains("1,000"))

        let macOS = mac(loaded: 7_500, total: 195_519).captureProvenanceDescription
        #expect(macOS.contains("195519") || macOS.contains("195,519"))
    }

    @Test("A checklist-filtered capture's stored description says so too")
    func checklistProvenance() {
        let description = iOS(loaded: 1_000, shown: 987).captureProvenanceDescription
        #expect(description.contains("13"))
        #expect(description.contains("highest-scoring"), "both facts, not whichever came first")
    }

    // MARK: - Panels

    @Test("The concordance count is unqualified on a single page")
    func singlePageConcordance() {
        let text = iOS(loaded: 20, onPage: 20, pages: 1).concordanceCountDescription(occurrences: 214)
        #expect(text.contains("214"))
        #expect(!text.contains("this page"), "there is no other page to distinguish it from")
    }

    @Test("The concordance count names its page when there is more than one")
    func multiPageConcordance() {
        let text = iOS(loaded: 1_000, onPage: 25, pages: 40)
            .concordanceCountDescription(occurrences: 214)
        #expect(text.contains("214"))
        #expect(text.contains("25"))
        #expect(text.contains("this page"))
    }

    /// macOS renders `overCapAdvisory` above every analysis panel with the loaded count and the
    /// total already on it. A panel line repeating them puts the same fact on screen three times.
    @Test("The collocation scope line carries no numbers of its own")
    func collocationScopeIsNumberless() {
        let text = mac(loaded: 7_500, total: 195_519).collocationScopeDescription
        #expect(!text.contains("7500") && !text.contains("7,500"))
        #expect(!text.contains("195519") && !text.contains("195,519"))
        #expect(text.contains("not the page on screen"))
    }

    @Test("An uncapped collocation says the set is every matching document")
    func collocationComplete() {
        #expect(iOS(loaded: 412).collocationScopeDescription.contains("every matching document"))
    }

    @Test("The collocation line adds the checklist exclusion, and only then")
    func collocationChecklist() {
        #expect(iOS(loaded: 1_000, shown: 987).collocationScopeDescription.contains("13"))
        #expect(!iOS(loaded: 1_000).collocationScopeDescription.contains("excluded"))
    }

    // MARK: - The timeline's shape

    @Test("An uncapped timeline gets no caption")
    func uncappedTimelineIsSilent() {
        #expect(iOS(loaded: 412).timelineBiasCaption == nil)
    }

    /// The distinction the whole caption exists for: every other capped surface reports a size,
    /// which a reader can discount. This one has to say the SHAPE is not the whole match's.
    @Test("A capped timeline states that the shape is skewed, not merely the size")
    func cappedTimelineNamesTheShape() throws {
        let caption = try #require(iOS(loaded: 1_000).timelineBiasCaption)
        #expect(caption.contains("shape"))
        #expect(caption.contains("highest-scoring"))
    }
}

// MARK: - ResultHeaderTests

/// The results-count header — the line the whole diagnosis started from.
///
/// It rendered `"%lld results"` over the checklist-FILTERED count while the line beneath rendered
/// `"Showing the first 1,000 results"` over the FETCHED count. These pin that every number is now
/// labelled, and — just as important — that an ordinary search is left alone, because labelling a
/// number that means only one thing is noise.
///
/// Version history:
///   1.0 — Q wave step 6: initial implementation
@Suite("Results header grammar")
struct ResultHeaderTests {

    private func scope(loaded: Int, shown: Int? = nil, total: Int?,
                       limit: Int = 1_000) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: limit,
                       totalMatchCount: total, documentsOnPage: 25, pageCount: 1)
    }

    @Test("An ordinary complete search is left unlabelled")
    func plainCount() {
        // 412 loaded, 412 shown, and the fetch did not cap: one number, one meaning.
        #expect(scope(loaded: 412, total: 412).headerDescription == "412 results")
        #expect(scope(loaded: 412, total: nil).headerDescription == "412 results")
    }

    @Test("An empty result set says so")
    func noResults() {
        #expect(scope(loaded: 0, total: 0).headerDescription == "No results")
    }

    @Test("A checklist-filtered but complete search names both numbers")
    func filteredComplete() {
        let text = scope(loaded: 412, shown: 399, total: 412).headerDescription
        #expect(text.contains("399"))
        #expect(text.contains("412"))
        #expect(text.contains("shown"), "the smaller number must be labelled as the shown one")
    }

    /// The exact collision this work exists to remove.
    @Test("A capped search labels loaded and total, and never repeats a bare count")
    func cappedLabelled() {
        let text = scope(loaded: 1_000, total: 195_519).headerDescription
        #expect(text.contains("loaded"))
        #expect(text.contains("total"))
        #expect(!text.contains("results"),
                "'results' is the word that meant three things — a labelled line must not reuse it")
    }

    @Test("A capped search with no total says the total is unavailable, not a wrong number")
    func cappedWithoutTotal() {
        let text = scope(loaded: 1_000, total: nil).headerDescription
        #expect(text.contains("total unavailable"))
        #expect(!text.contains("1000 total") && !text.contains("1,000 total"),
                "the fetched count must never be presented as the total")
    }

    @Test("Capped and filtered together names all three")
    func cappedAndFiltered() {
        let text = scope(loaded: 1_000, shown: 987, total: 195_519).headerDescription
        #expect(text.contains("987"))
        #expect(text.contains("shown"))
        #expect(text.contains("loaded"))
        #expect(text.contains("total"))
    }

    @Test("The over-cap guidance carries advice, not a second unlabelled count")
    func guidanceHasNoNumber() throws {
        #expect(scope(loaded: 412, total: 412).overCapGuidance == nil)
        let guidance = try #require(scope(loaded: 1_000, total: 195_519).overCapGuidance)
        #expect(!guidance.contains("1000") && !guidance.contains("1,000"),
                "the header states the numbers; this line would be the second unlabelled one")
        #expect(guidance.contains("filters"))
    }
}

// MARK: - CaptureTruncationTests

/// What the app says inside a corpus that was itself a capped capture.
///
/// Every truncation question `ResultSetScope` could ask used to be about the CURRENT fetch — and a
/// fetch inside a corpus never caps, the corpus already being smaller than the ceiling. So each
/// one silently answered "complete" about a set frozen from a capped capture. These pin the four
/// sentences that changed, and the one state that must NOT trigger them.
///
/// Version history:
///   1.0 — Q wave half 2: initial implementation
@Suite("Capture truncation inside a corpus")
struct CaptureTruncationTests {

    /// A search inside a corpus: small, well under the ceiling, so the fetch never caps.
    private func inCorpus(_ truncation: WorkingCorpus.CaptureTruncation?,
                          shown: Int = 267) -> ResultSetScope {
        ResultSetScope(loaded: shown, shown: shown, fetchLimit: 1_000, totalMatchCount: nil,
                       documentsOnPage: 25, pageCount: 11,
                       appliedCorpusTruncation: truncation)
    }

    // MARK: - The model's read surface

    @Test("The three states are kept apart")
    func threeStates() {
        let corpus = WorkingCorpus(name: "n", documentKeys: ["v/d"])
        #expect(corpus.truncationAtCapture == .unrecorded,
                "a corpus that recorded nothing must not claim to be complete")

        corpus.wasTruncatedAtCapture = false
        #expect(corpus.truncationAtCapture == .complete)

        corpus.wasTruncatedAtCapture = true
        corpus.totalMatchCountAtCapture = 195_519
        #expect(corpus.truncationAtCapture == .truncated(total: 195_519))

        corpus.totalMatchCountAtCapture = nil
        #expect(corpus.truncationAtCapture == .truncated(total: nil),
                "truncated-with-no-total is a real state, not a defect — it is the iPhone case")
    }

    // MARK: - isPartialEvidence

    @Test("A truncated corpus makes the evidence partial though the fetch did not cap")
    func truncatedCorpusIsPartial() {
        let scope = inCorpus(.truncated(total: 195_519))
        #expect(!scope.didHitFetchLimit, "the fetch inside a corpus does not cap — that is the trap")
        #expect(scope.isPartialEvidence)
    }

    @Test("A complete corpus leaves the evidence whole")
    func completeCorpusIsNotPartial() {
        #expect(!inCorpus(.complete).isPartialEvidence)
        #expect(!inCorpus(nil).isPartialEvidence, "no corpus applied")
    }

    /// The state that must stay silent. A corpus captured before the fields existed *might* have
    /// been complete; captioning every legacy corpus as partial is a different false claim, not a
    /// repair of the first.
    @Test("An unrecorded capture does not make the evidence partial")
    func unrecordedIsNotPartial() {
        #expect(!inCorpus(.unrecorded).isPartialEvidence)
        #expect(inCorpus(.unrecorded).timelineBiasCaption == nil)
    }

    // MARK: - The four sentences

    @Test("The timeline caption fires inside a truncated corpus")
    func timelineCaptionInsideCorpus() throws {
        // The highest-value line in the change: the caption was guarded on the fetch, so it
        // vanished exactly when the skew had been frozen, synced and made citable.
        let caption = try #require(inCorpus(.truncated(total: 195_519)).timelineBiasCaption)
        #expect(caption.contains("shape"))
        #expect(inCorpus(.complete).timelineBiasCaption == nil)
    }

    @Test("The collocation stops claiming it saw every matching document")
    func collocationStopsClaimingCompleteness() {
        let truncated = inCorpus(.truncated(total: 195_519)).collocationScopeDescription
        #expect(!truncated.contains("every matching document"),
                "a positive assertion of completeness atop a frozen relevance-ranked sample")
        #expect(inCorpus(.complete).collocationScopeDescription.contains("every matching document"))
    }

    /// Nesting. A capture taken inside a truncated corpus is itself partial, for a reason the
    /// capturing fetch cannot see — it did not cap, because the corpus was already under the
    /// ceiling. The value written to `wasTruncatedAtCapture` has to be the one that knows that.
    @Test("A capture taken inside a truncated corpus is recorded as partial")
    func nestedCaptureIsPartial() {
        let nested = inCorpus(.truncated(total: 195_519))
        #expect(!nested.didHitFetchLimit)
        #expect(nested.isPartialEvidence,
                "this is the value the capture must store, not didHitFetchLimit")
    }

    @Test("The header names the corpus capture rather than printing a bare count")
    func headerInsideTruncatedCorpus() {
        let withTotal = inCorpus(.truncated(total: 195_519)).headerDescription
        #expect(withTotal.contains("in this corpus"))
        #expect(withTotal.contains(195_519.formatted()))

        let withoutTotal = inCorpus(.truncated(total: nil)).headerDescription
        #expect(withoutTotal.contains("partial capture"))

        // Unchanged where nothing is truncated — the bare count is still correct there.
        #expect(inCorpus(.complete).headerDescription == "267 results")
        #expect(inCorpus(.unrecorded).headerDescription == "267 results")
    }
}

// MARK: - CorpusCaptureClauseTests

/// The one clause both count lines share.
///
/// The two search surfaces do not share a count line — iOS renders `headerDescription`, macOS
/// renders `SearchSheet.resultCountLabel` with its own "loaded · total" dialect and page ranges.
/// Sharing the *clause* is what stops a third grammar for the same facts appearing, and is why
/// these tests are worth having: the clause is the contract between two sentences neither of which
/// can see the other.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Corpus capture clause")
struct CorpusCaptureClauseTests {

    private func scope(_ truncation: WorkingCorpus.CaptureTruncation?) -> ResultSetScope {
        ResultSetScope(loaded: 267, shown: 267, fetchLimit: 1_000, totalMatchCount: nil,
                       documentsOnPage: 20, pageCount: 14, appliedCorpusTruncation: truncation)
    }

    @Test("The clause is silent unless the corpus was a truncated capture")
    func silentWhenNotTruncated() {
        #expect(scope(nil).corpusCaptureClause == nil, "no corpus applied")
        #expect(scope(.complete).corpusCaptureClause == nil)
        // The state that must stay quiet: a pre-fields capture might have been complete.
        #expect(scope(.unrecorded).corpusCaptureClause == nil)
    }

    @Test("The clause names the capture's own total when there was one")
    func namesTheCaptureTotal() throws {
        let clause = try #require(scope(.truncated(total: 195_519)).corpusCaptureClause)
        #expect(clause.contains(195_519.formatted()))
        #expect(clause.contains("captured from"))
    }

    @Test("A capture with no total says so rather than inventing one")
    func partialWithoutTotal() throws {
        let clause = try #require(scope(.truncated(total: nil)).corpusCaptureClause)
        #expect(clause.contains("partial capture"))
        #expect(!clause.contains("267"), "the corpus size is not the capture's total")
    }

    /// Both count lines must be built from this clause, or they drift. iOS is checked directly;
    /// macOS's is a `View` and is checked by the source audit below.
    @Test("The iOS header is built from the shared clause")
    func headerUsesTheClause() throws {
        let scope = scope(.truncated(total: 195_519))
        let clause = try #require(scope.corpusCaptureClause)
        #expect(scope.headerDescription.contains(clause))
    }
}

// MARK: - MacResultCountLabelAuditTests

/// macOS's count line, which no runtime test in this target can render.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("macOS result count label")
struct MacResultCountLabelAuditTests {

    private static func sheet() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/App/SearchSheet.swift"),
                              encoding: .utf8)
        #expect(text.count > 1_000)
        return text
    }

    @Test("macOS builds its corpus case from the shared clause, not its own wording")
    func usesSharedClause() throws {
        let sheet = try Self.sheet()
        #expect(sheet.contains("resultSetScope.corpusCaptureClause"))
        // If macOS spelled the clause itself, the two platforms could drift silently — which is
        // exactly how the header ended up iOS-only in the first place.
        #expect(!sheet.contains("captured from"),
                "the wording belongs to ResultSetScope, not to this view")
    }

    /// The corpus branches must precede the ordinary `total` branches, or they are unreachable:
    /// inside a corpus a total is always present, so `else if let total` would win first.
    @Test("The corpus branches are reachable")
    func corpusBranchesComeFirst() throws {
        let sheet = try Self.sheet()
        let corpusAt = try #require(sheet.range(of: "} else if let corpusClause, loaded <= searchVM.pageSize {"))
        let totalAt = try #require(sheet.range(of: "} else if let total, loaded <= searchVM.pageSize {"))
        #expect(corpusAt.lowerBound < totalAt.lowerBound,
                "a total is always present inside a corpus, so the total branch would win first")
    }
}


// MARK: - ResultSetScopeMeaningTests (#1584, #1595, #1598)

/// What the scope says of a Meaning list, and of a complete browse, wherever a ceiling could be mistaken for one.
///
/// Until #1598 only the header had a Meaning branch, so a Meaning list's capture was described in the keyword
/// search's words: "Search results", with no warning, stored as every matching document. And every sentence here
/// was given the keyword ceiling by its host whatever had been fetched (#1584).
///
/// Version history:
///   1.0 — #1584, #1595, #1598: initial implementation
@Suite("Result set scope: Meaning lists and browses")
struct ResultSetScopeMeaningTests {

    private func meaning(loaded: Int, shown: Int? = nil, fetchLimit: Int = 100) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: fetchLimit,
                       totalMatchCount: nil, documentsOnPage: min(loaded, 25),
                       pageCount: max(1, (loaded + 24) / 25), route: .meaning)
    }

    /// A full list, a short one and a single row, under the Meaning engine's own list length and under both keyword
    /// ceilings, which are what the two hosts passed before they passed the recorded one.
    private var everyMeaningShape: [ResultSetScope] {
        [100, 1_000, 7_500].flatMap { limit in
            [1, 37, 100].map { meaning(loaded: $0, fetchLimit: limit) }
        }
    }

    @Test("A Meaning list never reads as a fetch that hit its ceiling, at any length or ceiling")
    func meaningIsNeverAFetchAtItsCeiling() {
        for scope in everyMeaningShape {
            #expect(!scope.didHitFetchLimit, "\(scope.loaded) rows under \(scope.fetchLimit)")
            #expect(scope.overCapGuidance == nil,
                    "narrowing a Meaning search loads nothing more, so it is not advised to")
            #expect(scope.timelineBiasCaption == nil)
            #expect(!scope.isPartialEvidence)
        }
    }

    @Test("A Meaning capture names its engine, warns in the sheet and is stored as partial")
    func meaningCaptureSaysWhatItIs() throws {
        for scope in everyMeaningShape {
            let warning = try #require(scope.captureTruncationWarning,
                                       "the sheet says nothing of a Meaning capture (#1598)")
            #expect(warning.contains("Meaning search"))
            #expect(warning.contains("not every document"))
            #expect(!warning.contains("highest-scoring"), "the keyword sentence is about a match, which this is not")
            #expect(scope.captureProvenanceDescription.hasPrefix("Meaning search — the "))
            #expect(!scope.captureProvenanceDescription.contains("Search results"))
            #expect(!scope.captureProvenanceDescription.contains("larger match"))
            #expect(scope.isCapturePartial)
        }
        #expect(meaning(loaded: 100).captureProvenanceDescription == "Meaning search — the 100 closest matches")
        #expect(meaning(loaded: 37).captureProvenanceDescription == "Meaning search — the 37 closest matches")
        #expect(meaning(loaded: 1).captureProvenanceDescription == "Meaning search — the closest match")
    }

    @Test("A Meaning capture made with Checklist Mode hiding rows says so, as a keyword capture does")
    func meaningCaptureNamesTheChecklist() {
        let scope = meaning(loaded: 100, shown: 96)
        #expect(scope.captureProvenanceDescription
                    == "Meaning search — the 100 closest matches; 4 reviewed documents excluded")
        #expect(scope.captureChecklistWarning?.contains("4") == true)
    }

    /// The corpus lists tell a Meaning capture by the sentence it stored, since a corpus records no route (#1688).
    @Test("Every sentence a Meaning capture stores reads back as one, and no other capture's does")
    func theStoredSentenceIsRecognised() {
        for scope in everyMeaningShape + [meaning(loaded: 100, shown: 96)] {
            #expect(ResultSetScope.isMeaningCaptureProvenance(scope.captureProvenanceDescription),
                    "\(scope.captureProvenanceDescription)")
        }
        func scope(_ route: ExecutedSearchRoute, totalMatchCount: Int? = nil) -> ResultSetScope {
            ResultSetScope(loaded: 40, shown: 40, fetchLimit: 1_000, totalMatchCount: totalMatchCount,
                           documentsOnPage: 25, pageCount: 2, route: route)
        }
        let others = [scope(.keywords, totalMatchCount: 40), scope(.keywords),
                      scope(.wordsInMatches(base: 100)), scope(.rankedByMeaning(unranked: 3))]
            .map(\.captureProvenanceDescription)
            + ["Semantic map selection", "Semantic map selection, scoped to Berlin", "Semantic cluster, browsed", ""]
        for other in others {
            #expect(!ResultSetScope.isMeaningCaptureProvenance(other), "\(other)")
        }
        #expect(!ResultSetScope.isMeaningCaptureProvenance(nil), "a corpus with no provenance")
    }

    /// The numbers of #1584: 3,000 tagged documents, all loaded. Under the ceiling the browse was fetched at they are
    /// a complete set; under the keyword ceiling, which the screen passed, they are "truncated".
    @Test("3,000 loaded of 3,000 is complete under the browse ceiling and was truncated under the keyword one")
    func aCompleteBrowseIsComplete() {
        func browse(fetchLimit: Int) -> ResultSetScope {
            ResultSetScope(loaded: 3_000, shown: 3_000, fetchLimit: fetchLimit, totalMatchCount: 3_000,
                           documentsOnPage: 25, pageCount: 120)
        }
        let recorded = browse(fetchLimit: 7_500)
        #expect(recorded.headerDescription == "3,000 results")
        #expect(recorded.overCapGuidance == nil)
        #expect(recorded.captureTruncationWarning == nil)
        #expect(recorded.captureProvenanceDescription == "Search results")
        #expect(!recorded.isCapturePartial)

        // What the screen composed before: the constant. Kept so the difference stays visible.
        let constant = browse(fetchLimit: 1_000)
        #expect(constant.headerDescription == "3,000 loaded · 3,000 total")
        #expect(constant.captureProvenanceDescription == "Search results — the highest-scoring 3,000 of 3,000 matches")
        #expect(constant.isCapturePartial)
    }

    @Test("A keyword capture is partial exactly when its evidence is: at its ceiling, or inside a truncated corpus")
    func keywordCaptureFollowsItsEvidence() {
        let complete = ResultSetScope(loaded: 412, shown: 412, fetchLimit: 1_000, totalMatchCount: 412,
                                      documentsOnPage: 25, pageCount: 17)
        #expect(!complete.isCapturePartial)
        let atCeiling = ResultSetScope(loaded: 1_000, shown: 1_000, fetchLimit: 1_000, totalMatchCount: 14_462,
                                       documentsOnPage: 25, pageCount: 40)
        #expect(atCeiling.isCapturePartial)
        var insideTruncatedCorpus = complete
        insideTruncatedCorpus.appliedCorpusTruncation = .truncated(total: 9_000)
        #expect(insideTruncatedCorpus.isCapturePartial)
        var insideCompleteCorpus = complete
        insideCompleteCorpus.appliedCorpusTruncation = .complete
        #expect(!insideCompleteCorpus.isCapturePartial)
        var insideUnrecordedCorpus = complete
        insideUnrecordedCorpus.appliedCorpusTruncation = .unrecorded
        #expect(!insideUnrecordedCorpus.isCapturePartial, "an unrecorded capture is not known to be partial")
    }
}

// MARK: - ResultSetScopeRouteTests

/// The four routes a list of results can have come by, and what each makes the scope say (#1577 lane 2).
///
/// One fixture to a route for each rule and each sentence, so that a route which borrowed another's answer fails a
/// test of its own. Two of the routes, words found in a Meaning list and a keyword list ranked by a question, are
/// produced by no search until lanes 4 and 5: these are the sentences those lanes are to adopt.
///
/// Version history:
///   1.0 — #1577 lane 2: initial implementation
@Suite("Result set scope: the route that produced the rows")
struct ResultSetScopeRouteTests {

    /// A scope of `loaded` rows, `shown` of them on screen, that came by `route` under `fetchLimit`.
    private func scope(_ route: ExecutedSearchRoute, loaded: Int, shown: Int? = nil,
                       fetchLimit: Int = 1_000, total: Int? = nil) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: fetchLimit,
                       totalMatchCount: total, documentsOnPage: min(loaded, 25),
                       pageCount: max(1, (loaded + 24) / 25), route: route)
    }

    // MARK: The route's own answers

    @Test("Facets describe the list for every route but a keyword match")
    func facetsDescribeTheListForEveryRouteButKeywords() {
        #expect(!ExecutedSearchRoute.keywords.facetsDescribeTheList)
        #expect(ExecutedSearchRoute.meaning.facetsDescribeTheList)
        #expect(ExecutedSearchRoute.wordsInMatches(base: 100).facetsDescribeTheList)
        #expect(ExecutedSearchRoute.rankedByMeaning(unranked: 0).facetsDescribeTheList)
    }

    @Test("Readings are offered where the last step was a keyword match: a keyword search, and words found in a Meaning list")
    func readingsFollowTheKeywordMatch() {
        #expect(ExecutedSearchRoute.keywords.offersReadings)
        #expect(!ExecutedSearchRoute.meaning.offersReadings)
        #expect(ExecutedSearchRoute.wordsInMatches(base: 100).offersReadings)
        #expect(!ExecutedSearchRoute.rankedByMeaning(unranked: 0).offersReadings)
    }

    @Test("A scope built with no route is a keyword search's, and only a Meaning search is one")
    func theDefaultRouteIsKeywords() {
        let plain = ResultSetScope(loaded: 5, shown: 5, fetchLimit: 1_000, totalMatchCount: 5,
                                   documentsOnPage: 5, pageCount: 1)
        #expect(plain.route == .keywords)
        #expect(!plain.isMeaningSearch)
        #expect(scope(.meaning, loaded: 5).isMeaningSearch)
        #expect(!scope(.wordsInMatches(base: 100), loaded: 5).isMeaningSearch)
        #expect(!scope(.rankedByMeaning(unranked: 0), loaded: 5).isMeaningSearch)
    }

    // MARK: Whether the fetch stopped short

    @Test("A list at its ceiling stopped short for a keyword search and a ranked keyword list, and for neither Meaning route")
    func theCeilingMeansAFetchOnlyForAKeywordFetch() {
        #expect(scope(.keywords, loaded: 1_000).didHitFetchLimit)
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000).didHitFetchLimit)
        #expect(!scope(.meaning, loaded: 100, fetchLimit: 100).didHitFetchLimit)
        #expect(!scope(.wordsInMatches(base: 100), loaded: 100, fetchLimit: 100).didHitFetchLimit)
    }

    @Test("A total above what was loaded stops a ranked keyword list short too, and says nothing of a Meaning route")
    func aLargerTotalMeansAFetchOnlyForAKeywordFetch() {
        #expect(scope(.keywords, loaded: 40, total: 90).didHitFetchLimit)
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 40, total: 90).didHitFetchLimit)
        #expect(!scope(.meaning, loaded: 40, fetchLimit: 100, total: 90).didHitFetchLimit)
        #expect(!scope(.wordsInMatches(base: 100), loaded: 40, fetchLimit: 100, total: 90).didHitFetchLimit)
        #expect(!scope(.keywords, loaded: 40, total: 40).didHitFetchLimit, "the control: a complete keyword search")
    }

    @Test("Words found in a Meaning list are partial evidence with nothing else said; the other routes are not")
    func wordsInMatchesArePartialEvidence() {
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100).isPartialEvidence)
        #expect(!scope(.keywords, loaded: 7, total: 7).isPartialEvidence)
        #expect(!scope(.meaning, loaded: 7, fetchLimit: 100).isPartialEvidence)
        #expect(!scope(.rankedByMeaning(unranked: 0), loaded: 7, total: 7).isPartialEvidence)
    }

    // MARK: The header

    @Test("A keyword search's header counts its results, and one result is singular")
    func keywordHeader() {
        #expect(scope(.keywords, loaded: 412, total: 412).headerDescription == "412 results")
        #expect(scope(.keywords, loaded: 1, total: 1).headerDescription == "1 result")
        #expect(scope(.keywords, loaded: 2, total: 2).headerDescription == "2 results")
        #expect(scope(.keywords, loaded: 1_204, fetchLimit: 7_500, total: 1_204).headerDescription == "1,204 results")
        #expect(scope(.keywords, loaded: 412, total: 412).layeredHeaderClause == nil)
    }

    @Test("A Meaning search's header is its closest matches, one of them singular, with no layered clause")
    func meaningHeader() {
        let list = scope(.meaning, loaded: 100, fetchLimit: 100)
        #expect(list.headerDescription == "100 closest matches")
        #expect(list.layeredHeaderClause == nil)
        #expect(scope(.meaning, loaded: 1, fetchLimit: 100).headerDescription == "1 closest match")
        #expect(scope(.meaning, loaded: 2, fetchLimit: 100).headerDescription == "2 closest matches")
        // The clause counts what is shown, and its number follows that count.
        #expect(scope(.meaning, loaded: 3, shown: 1, fetchLimit: 100).closestMatchesClause == "1 closest match")
        #expect(scope(.meaning, loaded: 1, fetchLimit: 100).closestMatchesClause == "1 closest match")
        #expect(scope(.meaning, loaded: 1_204, fetchLimit: 7_500).closestMatchesClause == "1,204 closest matches")
    }

    @Test("Words in matches: how many of the list hold the words, one, none, and a list of one")
    func wordsInMatchesHeader() {
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100).headerDescription
                == "7 of your 100 closest matches contain these words")
        #expect(scope(.wordsInMatches(base: 100), loaded: 1, fetchLimit: 100).headerDescription
                == "1 of your 100 closest matches contains these words")
        #expect(scope(.wordsInMatches(base: 100), loaded: 0, fetchLimit: 100).headerDescription
                == "None of your 100 closest matches contains these words")
        #expect(scope(.wordsInMatches(base: 1), loaded: 1, fetchLimit: 100).headerDescription
                == "Your closest match contains these words")
        #expect(scope(.wordsInMatches(base: 1), loaded: 0, fetchLimit: 100).headerDescription
                == "Your closest match does not contain these words")
        // The two numbers are not interchangeable: seven of a hundred, never a hundred of seven.
        #expect(scope(.wordsInMatches(base: 37), loaded: 12, fetchLimit: 100).headerDescription
                == "12 of your 37 closest matches contain these words")
    }

    @Test("Words in matches with rows the checklist hides: what is shown, beside what was found")
    func wordsInMatchesHeaderUnderTheChecklist() {
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, shown: 5, fetchLimit: 100).headerDescription
                == "5 shown · 7 of your 100 closest matches contain these words")
        // Every found row hidden is still a find: neither "No results" nor "None of your…", which is for a search
        // that found nothing.
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, shown: 0, fetchLimit: 100).headerDescription
                == "0 shown · 7 of your 100 closest matches contain these words")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, shown: 0, total: 212).headerDescription
                == "0 shown · 212 results, closest first")
        // The routes that had a header before keep the one they had.
        #expect(scope(.keywords, loaded: 7, shown: 0, total: 7).headerDescription == "No results")
        #expect(scope(.meaning, loaded: 7, shown: 0, fetchLimit: 100).headerDescription == "No results")
    }

    @Test("Ranked by meaning: the keyword list's count, closest first, and the split when some rows were not ranked")
    func rankedByMeaningHeader() {
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212).headerDescription
                == "212 results, closest first")
        #expect(scope(.rankedByMeaning(unranked: 9), loaded: 212, total: 212).headerDescription
                == "212 results · 203 ranked · 9 not ranked")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1, total: 1).headerDescription
                == "1 result, closest first")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_204, fetchLimit: 7_500, total: 1_204).headerDescription
                == "1,204 results, closest first")
        #expect(scope(.rankedByMeaning(unranked: 1_100), loaded: 1_204, fetchLimit: 7_500, total: 1_204)
                    .headerDescription == "1,204 results · 104 ranked · 1,100 not ranked")
    }

    @Test("Ranked by meaning with rows the checklist hides, and at the keyword ceiling")
    func rankedByMeaningHeaderUnderTheChecklistAndAtTheCeiling() {
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, shown: 200, total: 212).headerDescription
                == "200 shown · 212 results, closest first")
        // Cut where the keyword fetch was cut: the header keeps the layer's words, and the scope still knows.
        let cut = scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275)
        #expect(cut.headerDescription == "1,000 results, closest first")
        #expect(cut.didHitFetchLimit)
        // A ranked list of nothing has no sentence of its own: there is no list to be closest first.
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 0, total: 0).headerDescription == "No results")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 0, total: 0).layeredHeaderClause == nil)
    }

    // MARK: The capture

    @Test("What a capture is warned of, by route")
    func captureWarningByRoute() {
        #expect(scope(.keywords, loaded: 412, total: 412).captureTruncationWarning == nil)
        #expect(scope(.meaning, loaded: 100, fetchLimit: 100).captureTruncationWarning
                == "These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.")
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100).captureTruncationWarning
                == "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 212, total: 212).captureTruncationWarning == nil,
                "a keyword list is the same set in any order")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275).captureTruncationWarning
                == "These 1,000 documents are the highest-scoring of 35,275 matching documents. Counts taken inside this corpus are counts inside that subset.")
    }

    @Test("Words in matches: the capture's caution is singular when the capture is one document")
    func captureWarningForOneDocumentFound() {
        let one = "This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set."
        #expect(scope(.wordsInMatches(base: 100), loaded: 1, fetchLimit: 100).captureTruncationWarning == one)
        // The capture is of what is shown: three found, two of them hidden by the checklist, is a capture of one.
        #expect(scope(.wordsInMatches(base: 100), loaded: 3, shown: 1, fetchLimit: 100).captureTruncationWarning == one)
        #expect(scope(.wordsInMatches(base: 100), loaded: 2, fetchLimit: 100).captureTruncationWarning?
                    .hasPrefix("These documents are the ones") == true)
    }

    @Test("The advice to add keywords is given under a keyword list at its ceiling, and not under one a question has ranked")
    func overCapGuidanceByRoute() {
        #expect(scope(.keywords, loaded: 1_000, total: 35_275).overCapGuidance
                == "Add more keywords or filters to see more specific results.")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275).overCapGuidance == nil)
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275).didHitFetchLimit,
                "the precondition: it is cut, and the advice is withheld for the route's sake")
        #expect(scope(.meaning, loaded: 100, fetchLimit: 100).overCapGuidance == nil)
        #expect(scope(.wordsInMatches(base: 100), loaded: 100, fetchLimit: 100).overCapGuidance == nil)
    }

    @Test("What a capture's record says it came from, by route")
    func captureProvenanceByRoute() {
        #expect(scope(.keywords, loaded: 412, total: 412).captureProvenanceDescription == "Search results")
        #expect(scope(.meaning, loaded: 100, fetchLimit: 100).captureProvenanceDescription
                == "Meaning search — the 100 closest matches")
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100).captureProvenanceDescription
                == "Words found in a Meaning search’s closest matches — 7 of 100")
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, shown: 5, fetchLimit: 100).captureProvenanceDescription
                == "Words found in a Meaning search’s closest matches — 7 of 100; 2 reviewed documents excluded")
        // A corpus stores a set and not an order, but since #1577 lane 4 the record says the list was ranked, as it
        // names words found in a Meaning list: it outlives the screen that said so. `SearchLayeringTests` holds the
        // sentence that also names the list (`layerBaseLabel`).
        #expect(scope(.rankedByMeaning(unranked: 9), loaded: 212, total: 212).captureProvenanceDescription
                == "Search results, ranked by a question")
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275).captureProvenanceDescription
                == "Search results, ranked by a question — the highest-scoring 1,000 of 35,275 matches")
    }

    @Test("Whether a capture is stored as partial, by route")
    func capturePartialByRoute() {
        #expect(!scope(.keywords, loaded: 412, total: 412).isCapturePartial)
        #expect(scope(.meaning, loaded: 100, fetchLimit: 100).isCapturePartial)
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100).isCapturePartial)
        #expect(!scope(.rankedByMeaning(unranked: 9), loaded: 212, total: 212).isCapturePartial)
        #expect(scope(.rankedByMeaning(unranked: 0), loaded: 1_000, total: 35_275).isCapturePartial)
    }

    /// The two captions a reading shows over partial evidence say "the highest-scoring matches", which is what a
    /// keyword fetch at its ceiling holds. Words found in a Meaning list were chosen by a question and kept for their
    /// words, so they have captions of their own, and the keyword captions are unchanged.
    @Test("A reading taken over words found in a Meaning list is captioned in its own words")
    func readingsOverWordsInMatchesHaveTheirOwnCaptions() {
        let found = scope(.wordsInMatches(base: 100), loaded: 7, fetchLimit: 100)
        #expect(found.timelineBiasCaption
                == "These are the closest matches that contain your words, not a sample across time — this shape is theirs, not the whole match’s.")
        #expect(found.collocationScopeDescription
                == "Measured over every result this search loaded, not the page on screen — those are the closest matches that contain your words, not every document that contains them.")
        #expect(scope(.wordsInMatches(base: 100), loaded: 7, shown: 5, fetchLimit: 100).collocationScopeDescription
                == "Measured over every result this search loaded, not the page on screen — those are the closest matches that contain your words, not every document that contains them. 2 reviewed documents are excluded.")

        let complete = scope(.keywords, loaded: 7, total: 7)
        #expect(complete.timelineBiasCaption == nil)
        #expect(complete.collocationScopeDescription
                == "Measured over every result this search loaded, which is every matching document.")
        let cut = scope(.keywords, loaded: 1_000, total: 35_275)
        #expect(cut.timelineBiasCaption
                == "These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.")
        #expect(cut.collocationScopeDescription
                == "Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.")
    }
}

// MARK: - What narrowed the list (#1758)

/// What a working corpus records of the filters its rows were found under, beside its query
/// (`ResultSetScope.narrowing`, `ResultSetScope.narrowing(ofRowsSignedBy:)`).
///
/// S1's capture on an iPad Pro: *"long telegram"* narrowed by Facets to 1945, five documents, recorded as
/// *From "long telegram"* and nothing else, so neither the sheet nor the corpus said how the five were chosen.
///
/// Version history:
///   1.0 — #1758: initial implementation
@Suite("Result set scope: what narrowed the list")
struct ResultSetScopeNarrowingTests {

    /// The phrases for the rows of a search run with `parameters`.
    private func narrowing(_ parameters: SearchParameters) -> [String] {
        ResultSetScope.narrowing(ofRowsSignedBy: SearchScopeSignature.signature(for: parameters))
    }

    @Test("A search narrowed by nothing but its words records no narrowing")
    func nothingNarrowed() {
        #expect(narrowing(SearchParameters(keywords: "long telegram")).isEmpty)
        #expect(ResultSetScope.narrowing(ofRowsSignedBy: nil).isEmpty, "no rows have arrived")
        #expect(ResultSetScope.narrowing(ofRowsSignedBy: "not a signature").isEmpty, "a key that does not decode")
    }

    @Test("A facet's narrowing is said in the method appendix's words")
    func facetsInTheAppendixWords() {
        #expect(narrowing(SearchParameters(keywords: "long telegram", yearKeys: ["1945"])) == ["years 1945"])
        #expect(narrowing(SearchParameters(keywords: "x", yearKeys: ["1946", "1945"])) == ["years 1945, 1946"])
        #expect(narrowing(SearchParameters(keywords: "x", dateRange: DateRange(earliest: "1945-01-01",
                                                                               latest: "1945-12-31")))
                == ["dated 1945-01-01..1945-12-31"])
        #expect(narrowing(SearchParameters(keywords: "x", yearKeys: ["1945"], documentTypeFilter: .documentsOnly))
                == ["years 1945", "documents only"])
        #expect(narrowing(SearchParameters(keywords: "x", personRollupId: 77, personLabel: "Acheson, Dean"))
                == ["filtered to one person"])
    }

    /// The appendix's "12 volumes" and "312 documents" would read, after "Search results", as counts of the
    /// corpus itself; and its "1 volumes" has no singular.
    @Test("A set of volumes or documents is said as what the search ran within, with its singular")
    func setsAreSaidAsWhatTheSearchRanWithin() {
        #expect(narrowing(SearchParameters(keywords: "x", volumeIds: ["frus1945v05"])) == ["within 1 volume"])
        let volumes = (1...12).map { "frus1945v\($0)" }
        #expect(narrowing(SearchParameters(keywords: "x", volumeIds: volumes)) == ["within 12 volumes"])
        let documents = (1...312).map { "frus1945v05/d\($0)" }
        #expect(narrowing(SearchParameters(keywords: "x", documentIds: documents)) == ["within a set of 312 documents"])
        #expect(narrowing(SearchParameters(keywords: "x", documentIds: ["frus1945v05/d1"]))
                == ["within a set of 1 document"])
        #expect(narrowing(SearchParameters(keywords: "x", yearKeys: ["1945"], volumeIds: ["frus1945v05"]))
                == ["years 1945", "within 1 volume"], "the sets come last")
        #expect(narrowing(SearchParameters(keywords: "x", documentIds: [])) == ["no documents selected"])
    }

    @Test("The fields searched are said only when they are not every field")
    func fieldsOnlyWhenNarrowed() throws {
        let phrases = narrowing(SearchParameters(keywords: "x", includeSummaries: false, includeNotes: false))
        let first = try #require(phrases.first)
        #expect(first.hasPrefix("searched document text"), "\(phrases)")
        #expect(!first.contains("summaries"))
    }

    @Test("A capture's record says what narrowed it, after what it is and before how it was cut")
    func theRecordSaysWhatNarrowedIt() {
        let five = ResultSetScope(loaded: 5, shown: 5, fetchLimit: 1_000, totalMatchCount: 5,
                                  documentsOnPage: 5, pageCount: 1, narrowing: ["years 1945"])
        #expect(five.captureProvenanceDescription == "Search results (years 1945)")

        let cut = ResultSetScope(loaded: 7_500, shown: 7_500, fetchLimit: 7_500, totalMatchCount: 195_519,
                                 documentsOnPage: 20, pageCount: 375, narrowing: ["years 1945", "documents only"])
        #expect(cut.captureProvenanceDescription
                == "Search results (years 1945; documents only) — the highest-scoring 7,500 of 195,519 matches")

        let meaning = ResultSetScope(loaded: 37, shown: 37, fetchLimit: 100, totalMatchCount: nil,
                                     documentsOnPage: 25, pageCount: 2, route: .meaning, narrowing: ["years 1945"])
        #expect(meaning.captureProvenanceDescription == "Meaning search — the 37 closest matches (years 1945)")
        #expect(ResultSetScope.isMeaningCaptureProvenance(meaning.captureProvenanceDescription),
                "the corpus lists still know a Meaning capture by how its record begins")

        let unnarrowed = ResultSetScope(loaded: 5, shown: 5, fetchLimit: 1_000, totalMatchCount: 5,
                                        documentsOnPage: 5, pageCount: 1)
        #expect(unnarrowed.captureProvenanceDescription == "Search results")
    }
}
