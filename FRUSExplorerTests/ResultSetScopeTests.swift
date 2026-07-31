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
