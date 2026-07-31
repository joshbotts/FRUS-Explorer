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

// MARK: - ResultSetScope

/// Which set a search surface is actually looking at, and the sentences that say so.
///
/// ## The problem this exists to fix
/// The search screen used the word **"results"** for three different sets, on adjacent lines,
/// without ever naming which:
///
/// - `"%lld results"` renders `resultCount`, which is `displayedResults.count` — the
///   checklist-**filtered** set.
/// - `"Showing the first 1,000 results"` renders `searchHardLimit` — the **fetched** set
///   (`isResultsCapped` keys on `results.count`).
/// - the collocation caveat's `"your %lld results"` is `displayedResults` again.
///
/// So with checklist mode hiding thirteen documents, iOS renders **"987 results"** directly above
/// **"Showing the first 1,000 results."** Two numbers, two sets, one word, no label.
///
/// The surfaces behind the examine menu then compound it, because they genuinely do run over
/// different sets — the timeline and collocates over the retained set, the concordance over one
/// page, the facets over the whole match in SQL. Most of those differences are **correct**: facets
/// that described only the fetched 1,000 could not be used to narrow, and a collocation over
/// twenty-five documents cannot clear its own significance floor. What was missing was never
/// uniformity. It was that no surface said which set it had been handed.
///
/// ## The vocabulary, which is the actual fix
/// One word per set, fixed here and used everywhere:
///
/// | Word | Means | Member |
/// |---|---|---|
/// | **loaded** | what the fetch returned, capped | ``loaded`` |
/// | **shown** | loaded, minus checklist-hidden | ``shown`` |
/// | **match** | every document matching the query | ``totalMatchCount`` |
///
/// Because the sentences are computed properties on this type rather than string literals at four
/// call sites, it is not possible to write "loaded" over a `shown` number — which is exactly the
/// error that kept recurring while this was being designed. It also makes every sentence testable
/// with no search service, no fixture, and no simulator.
///
/// The precedent is ``WorkingCorpusResolution``, a non-view value type that emits a sentence and
/// carries the note "always states both numbers, even when complete".
///
/// ## What must NOT go in a panel
/// On macOS `overCapAdvisory` renders above the branch into every analysis panel, so it is already
/// on screen inside all of them saying "Showing 7,500 of 195,519 matches". Panel copy therefore
/// states only its own narrowing and never restates the cap. The capture sheet is the exception:
/// it is a modal with nothing visible behind it, so it states the whole chain.
///
/// Version history:
///   1.0 — Q wave: initial implementation
struct ResultSetScope: Equatable, Sendable {

    // MARK: - The sets

    /// What the fetch returned. Capped at ``fetchLimit``.
    let loaded: Int
    /// ``loaded`` minus documents checklist mode is hiding. What the user can see.
    let shown: Int
    /// The fetch ceiling — 1,000 on iOS, 7,500 on macOS.
    let fetchLimit: Int
    /// Every document matching the query, or `nil` where the platform does not compute one.
    ///
    /// iOS is `nil` today: it has never held a whole-query count, and reporting the fetched count
    /// as a total would be the lie `totalMatchCountForFacets` already refuses to tell.
    let totalMatchCount: Int?

    // MARK: - The page

    /// Documents on the page currently displayed.
    let documentsOnPage: Int
    /// How many pages the shown set divides into.
    let pageCount: Int

    // MARK: - Derived

    /// Whether more documents match the query than were loaded.
    ///
    /// Two ways to know, and macOS's `isResultSetTruncated` already uses both: the fetch hit its
    /// ceiling, or a known total exceeds what was fetched. The second matters because a total can
    /// exceed the fetch below the ceiling — a filter applied after the fetch, say — and reporting
    /// only the ceiling case would call that set complete.
    var didHitFetchLimit: Bool {
        if loaded >= fetchLimit { return true }
        if let totalMatchCount { return totalMatchCount > loaded }
        return false
    }

    /// How many documents checklist mode is withholding.
    var hiddenByChecklist: Int { max(0, loaded - shown) }

    /// Whether the shown set fits on one page, in which case "on this page" says nothing.
    var isSinglePage: Bool { pageCount <= 1 }

    // MARK: - Capture (the modal — states the whole chain)

    /// Why the captured set may not be the whole answer to the query.
    ///
    /// `nil` when the fetch did not hit its ceiling, because then the loaded set *is* every
    /// matching document and a caveat would be noise.
    ///
    /// This is the one place in the app where getting it wrong becomes a wrong published claim:
    /// a working corpus is durable, synced, and cited, and the same query captured on an iPhone
    /// and a Mac at the same instant against the same index yields 1,000 keys and 7,500.
    var captureTruncationWarning: String? {
        guard didHitFetchLimit else { return nil }
        if let totalMatchCount {
            return String(format: String(
                localized: "corpus.save.truncated.total %lld %lld",
                defaultValue: "These %1$lld documents are the highest-scoring of %2$lld matching documents. Counts taken inside this corpus are counts inside that subset."),
                Int64(loaded), Int64(totalMatchCount))
        }
        return String(format: String(
            localized: "corpus.save.truncated.unknown %lld",
            defaultValue: "These %lld documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset."),
            Int64(loaded))
    }

    /// What checklist mode is keeping out of the capture.
    ///
    /// The capture deliberately takes the checklist-filtered set — what you see is what you save —
    /// which is defensible and silent. Saying so at the moment of capture is what makes it a
    /// choice rather than a surprise.
    var captureChecklistWarning: String? {
        guard hiddenByChecklist > 0 else { return nil }
        return String(format: String(
            localized: "corpus.save.checklistHiding %lld",
            defaultValue: "Checklist mode is hiding %lld reviewed documents. They will not be in this corpus."),
            Int64(hiddenByChecklist))
    }

    /// The provenance sentence stored on the corpus itself.
    ///
    /// Goes into `WorkingCorpus.sourceDescription`, an **existing** stored property — so the record
    /// becomes self-describing at zero CloudKit schema cost, which is what makes this affordable.
    /// A corpus read on another device, or a year later, carries its own truncation with it.
    var captureProvenanceDescription: String {
        var description = String(localized: "corpus.save.source.search", defaultValue: "Search results")
        if didHitFetchLimit {
            if let totalMatchCount {
                description += String(format: String(
                    localized: "corpus.save.source.truncated.total %lld %lld",
                    defaultValue: " — the highest-scoring %1$lld of %2$lld matches"),
                    Int64(loaded), Int64(totalMatchCount))
            } else {
                description += String(format: String(
                    localized: "corpus.save.source.truncated.unknown %lld",
                    defaultValue: " — the highest-scoring %lld of a larger match"),
                    Int64(loaded))
            }
        }
        if hiddenByChecklist > 0 {
            description += String(format: String(
                localized: "corpus.save.source.checklist %lld",
                defaultValue: "; %lld reviewed documents excluded"),
                Int64(hiddenByChecklist))
        }
        return description
    }

    // MARK: - Panels (state only their own narrowing — never restate the cap)

    /// The concordance's occurrence count, qualified by the set it came from.
    ///
    /// A bare "214 occurrences" travels out of context in a screenshot or a quotation, with nothing
    /// to say that 214 came from twenty-five documents rather than a thousand. Unqualified when
    /// there is only one page, where "on this page" would be a distinction without a difference.
    func concordanceCountDescription(occurrences: Int) -> String {
        guard !isSinglePage else {
            return String(format: String(localized: "search.kwic.count %lld",
                                         defaultValue: "%lld occurrences"), Int64(occurrences))
        }
        return String(format: String(
            localized: "search.kwic.count.paged %lld %lld",
            defaultValue: "%1$lld occurrences in the %2$lld documents on this page"),
            Int64(occurrences), Int64(documentsOnPage))
    }

    /// What the collocation measured over.
    ///
    /// Carries **no numbers** deliberately: on macOS the over-cap advisory sits two lines above
    /// with the same two figures, and the sort bar's result count is a third. The distinction this
    /// draws — the whole loaded set, not the page — is the one nothing else on screen states.
    var collocationScopeDescription: String {
        var description = didHitFetchLimit
            ? String(localized: "search.collocation.caveat.scope.loaded.capped",
                     defaultValue: "Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.")
            : String(localized: "search.collocation.caveat.scope.loaded.complete",
                     defaultValue: "Measured over every result this search loaded, which is every matching document.")
        if hiddenByChecklist > 0 {
            description += String(format: String(
                localized: "search.collocation.caveat.scope.checklist %lld",
                defaultValue: " %lld reviewed documents are excluded."),
                Int64(hiddenByChecklist))
        }
        return description
    }

    /// That the timeline's **shape** is skewed, not merely its size.
    ///
    /// The highest-value sentence here, and it appears nowhere in the app today. Every other capped
    /// surface reports a number a reader can mentally discount. A timeline is read as a
    /// distribution, and a BM25 top-1,000 is not date-neutral — so a caveat about *size* cannot
    /// correct a *shape*. `nil` when the fetch did not hit its ceiling: an uncapped "plotting all
    /// 412 results" caption is chrome carrying no information.
    var timelineBiasCaption: String? {
        guard didHitFetchLimit else { return nil }
        return String(localized: "search.timeline.bias",
                      defaultValue: "These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.")
    }
}
