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

// MARK: - ExecutedSearchRoute

/// The route that produced the rows on screen, recorded when they arrived (#1577 lane 2).
///
/// It is a description of results that is frozen with them, as `UserTagCountScope` is. The
/// Keywords | Meaning picker names the engine the NEXT search will run through: between a switch
/// and the new rows' arrival it names an engine the rows on screen did not come from. Whatever
/// describes those rows asks this, and whatever concerns the field asks the picker.
///
/// **No search produces two of the four yet.** ``wordsInMatches(base:)`` and
/// ``rankedByMeaning(unranked:)`` are the two layers of Search Within These Results (#1577 lanes 4
/// and 5). They are here, with their sentences in ``ResultSetScope``, so that those lanes adopt one
/// vocabulary that was tested before the control existed.
///
/// Version history:
///   1.0 — #1577 lane 2: initial implementation, in place of `ResultSetScope`'s `isMeaningSearch` flag
enum ExecutedSearchRoute: Equatable, Sendable {

    /// A keyword match, or a browse with no words: rows the index matched.
    case keywords
    /// A Meaning search: the nearest documents of a ranking of the whole series.
    case meaning
    /// Words found inside a held Meaning list of `base` rows: the rows of it that a keyword match
    /// kept, still closest first.
    ///
    /// Owed by lane 4, which is to produce it. The header's sentence attributes the whole count to
    /// the words, so a filter that removes rows of the layer has to be said beside it. And a capture
    /// stores `totalMatchCount` beside its partial flag, so the run must leave that total `nil`: its
    /// own row count there would read back as "captured from 7 matches".
    case wordsInMatches(base: Int)
    /// A held keyword list reordered by a question: every row of it, closest first, with the
    /// `unranked` rows that could not be scored last.
    ///
    /// Owed by lane 4. The header says "closest first", which is false of a list sorted by date, so
    /// that sort must not be offered over a ranked list or the clause not shown under it. And
    /// ``ResultSetScope/didHitFetchLimit`` reads the keyword fetch's ceiling for this route, so the
    /// ranking must not overwrite `lastFetchLimit` as a Meaning run does.
    case rankedByMeaning(unranked: Int)

    /// Whether the facet panel describes the rows on screen and not a match in the index.
    ///
    /// A keyword match is aggregated in SQL over every document it matched, of which the list may be
    /// a sample. For every other route the list is the unit the reader is looking at: a Meaning list
    /// is a ranking with no match expression to aggregate (#1193), and a layer is made of a list that
    /// is held. Their facets count the rows of the list itself.
    var facetsDescribeTheList: Bool {
        switch self {
        case .keywords: return false
        case .meaning, .wordsInMatches, .rankedByMeaning: return true
        }
    }

    /// Whether the Timeline, Concordance and Collocates readings are offered over these rows: whether
    /// the last step that produced them was a keyword match. A keyword search's was, and so was the
    /// search for words inside a Meaning list, whose rows carry the words. A Meaning list's was a
    /// ranking. So was a keyword list's once a question has reordered it, and the design keeps its
    /// readings shut as it does a Meaning list's.
    var offersReadings: Bool {
        switch self {
        case .keywords, .wordsInMatches: return true
        case .meaning, .rankedByMeaning: return false
        }
    }
}

// MARK: - SearchRunLedger

/// The searches a screen has sent, numbered, so that a run a later one replaced writes nothing when
/// it comes back (#1648).
///
/// A run's rows could come back however long ago the reader moved on. Until #1680 nothing under a
/// search checked for cancellation. The kit now stops a keyword search when the task running it is
/// cancelled, which iPhone and iPad do as a later run starts and the Mac's window does when its search
/// task is replaced, and a cancelled keyword search gets no rows; but the Meaning engine does not stop
/// at all. Two runs that overlapped landed in the order they finished, so the older one could take the
/// list: a Meaning search still under way when the reader switched to Keywords and searched landed
/// over the keyword rows.
///
/// So each run takes a number as it starts and, once its last wait is over, asks whether it is still
/// the latest. A run that is not writes nothing more: no rows, count or error, no trail entry, and
/// not `isSearching`, which is the later run's to clear. Emptying the list without a search replaces
/// the runs under way too (``replaceRunsUnderWay()``), so a run cannot put rows back under a field the
/// reader has just cleared.
///
/// Both search view models hold one, so iPhone, iPad and the Mac drop a run by one rule.
///
/// Version history:
///   1.0 — #1648: initial implementation
///   1.1 — #1680: the kit stops a cancelled keyword search; this still drops every Meaning run a later
///          one replaced, and is the one rule both screens drop a replaced run by, whatever its engine
struct SearchRunLedger: Equatable, Sendable {

    /// The number of the latest run, or of the latest replacement of the runs under way.
    private(set) var latest = 0

    /// Starts a run, which replaces every run still under way, and returns its number.
    mutating func startRun() -> Int {
        latest &+= 1
        return latest
    }

    /// Replaces every run still under way without starting another, for a list emptied with no
    /// search.
    mutating func replaceRunsUnderWay() {
        latest &+= 1
    }

    /// Whether `run` is still the latest: `false` once another run has started, or the runs under
    /// way have been replaced, since it did.
    func isLatest(_ run: Int) -> Bool {
        run == latest
    }
}

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
/// ## Who builds one
/// The two search view models, as `SearchViewModel.resultSetScope` and `MacSearchViewModel.resultSetScope`, from what
/// they recorded when the rows on screen arrived: the ceiling that fetch ran under and the route that produced them
/// (``ExecutedSearchRoute``).
/// Until #1584 each search view built its own from a constant and from the Keywords | Meaning picker, so a complete
/// browse of 3,000 documents was measured against the 1,000-row keyword ceiling and read as truncated, and a browse's
/// rows read "closest matches" as soon as the picker moved (#1597).
///
/// Version history:
///   1.0 — Q wave: initial implementation
///   1.1 — #1584, #1595, #1597, #1598: ``fetchLimit`` is the ceiling the fetch recorded; a Meaning search never
///         reads as a fetch that hit one; the capture sentences and ``isCapturePartial`` have a Meaning branch
///   1.2 — #1577 lane 2: ``route`` in place of the `isMeaningSearch` flag, with the header and capture sentences of
///         the two layered routes
struct ResultSetScope: Equatable, Sendable {

    // MARK: - The sets

    /// What the fetch returned. Capped at ``fetchLimit``.
    let loaded: Int
    /// ``loaded`` minus documents checklist mode is hiding. What the user can see.
    let shown: Int
    /// The ceiling this fetch ran under, as the view model recorded it with the rows (`lastFetchLimit`).
    ///
    /// On iPhone and iPad that is 1,000 for a search with text in it and 7,500 for a browse with none; on the Mac both
    /// are 7,500. Never a constant: passing the keyword ceiling for every search is what made a complete browse of
    /// 1,000 to 7,499 documents read as cut off (#1584). After a Meaning search it is that engine's list length, and
    /// ``didHitFetchLimit`` does not read it.
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

    // MARK: - The corpus this search is inside

    /// What is known about the truncation of the applied working corpus, or `nil` when the search
    /// is not scoped to one.
    ///
    /// This is the member that makes the sentences correct inside a corpus. Without it every
    /// truncation question on this type is about **this fetch**, and a fetch inside a corpus never
    /// caps — the corpus is already smaller than the ceiling — so each one silently answered
    /// "complete" about a set that was frozen from a capped capture.
    var appliedCorpusTruncation: WorkingCorpus.CaptureTruncation? = nil

    // MARK: - The route that produced it

    /// The route that produced these rows: the view models record it where they assign the rows
    /// (`executedRoute`), so it is never the mode the picker shows.
    var route: ExecutedSearchRoute = .keywords

    /// Whether these results are a Meaning search's: ranked by MEANING, not matched by keyword.
    ///
    /// **A similarity search has no total, and "total unavailable" says the opposite** (#1193). The
    /// keyword grammar above is built on a match that exists and a fetch that may not have reached
    /// all of it, so "unavailable" means *there is a number and we could not get it*. A meaning
    /// search returns the N nearest neighbours: every document in the corpus is a match at some
    /// distance, so N is the answer's shape rather than a ceiling it ran into. Reported as
    /// "100 loaded · total unavailable" beside a facet panel counting 471.
    ///
    /// `MacSearchViewModel.performMeaningSearch` sets `totalMatchCount = nil` deliberately — a
    /// semantic number there would mint phantom deltas in the SavedSearch freshness watermark —
    /// so the nil is correct and it is the *sentence* that was wrong.
    var isMeaningSearch: Bool { route == .meaning }

    /// The header clause for a meaning search: the shape of the answer, not a count of a match.
    ///
    /// Shared so the two platforms cannot word it differently — `headerDescription` renders it on
    /// iOS and `SearchSheet.resultCountLabel` on macOS, which is the same division of labour the
    /// corpus clause above already uses.
    ///
    /// One row is "1 closest match" since #1577 lane 2, which gave the keyword header its singular: a Meaning search
    /// that filters leave one row of, or one inside a set of one document, read "1 closest matches".
    var closestMatchesClause: String {
        shown == 1
            ? String(localized: "search.count.closest.one", defaultValue: "1 closest match")
            : String(format: String(localized: "search.count.closest %@",
                                    defaultValue: "%@ closest matches"), grouped(shown))
    }

    // MARK: - Derived

    /// Whether more documents match the query than were loaded.
    ///
    /// Two ways to know, and macOS's `isResultSetTruncated` already uses both: the fetch hit its
    /// ceiling, or a known total exceeds what was fetched. The second matters because a total can
    /// exceed the fetch below the ceiling — a filter applied after the fetch, say — and reporting
    /// only the ceiling case would call that set complete.
    ///
    /// Always `false` for a Meaning search (#1595). Its list is the nearest documents of a ranking of the whole
    /// series, so there is no larger match the list stopped short of, and narrowing loads nothing more: filters are
    /// applied to the ranked list and can only remove rows. What a Meaning list is, the header and the capture say in
    /// their own words (``closestMatchesClause``, ``captureTruncationWarning``).
    ///
    /// By route (#1577 lane 2): words found inside a Meaning list are a subset of that list, so the same holds for
    /// them; a keyword list reordered by a question is still the keyword fetch, cut where that fetch was cut.
    var didHitFetchLimit: Bool {
        switch route {
        case .meaning, .wordsInMatches: return false
        case .keywords, .rankedByMeaning: break
        }
        if loaded >= fetchLimit { return true }
        if let totalMatchCount { return totalMatchCount > loaded }
        return false
    }

    /// Whether what is on screen is a subset of the answer to the question — for **either** reason:
    /// this fetch stopped short, or the corpus it is inside was itself a capped capture.
    ///
    /// Distinct from ``didHitFetchLimit``, which is only ever about this fetch. Every sentence
    /// that warns a reader about partial evidence keys on this; anything describing the mechanics
    /// of *this* fetch keys on the other.
    ///
    /// `unrecorded` does **not** count. A corpus captured before the app recorded truncation might
    /// have been complete, and captioning every legacy corpus as partial would be a different
    /// false claim rather than a repair of the first one.
    ///
    /// Words found inside a Meaning list always count (#1577 lane 2): they are some of a ranking's nearest documents,
    /// and no reading taken over them is a reading of every document that holds the words.
    var isPartialEvidence: Bool {
        if didHitFetchLimit { return true }
        if case .truncated = appliedCorpusTruncation { return true }
        if case .wordsInMatches = route { return true }
        return false
    }

    /// How many documents checklist mode is withholding.
    var hiddenByChecklist: Int { max(0, loaded - shown) }

    /// Whether the shown set fits on one page, in which case "on this page" says nothing.
    var isSinglePage: Bool { pageCount <= 1 }

    /// A count with the reader's thousands separators.
    ///
    /// `String(format: "%lld", …)` never groups, so a truncated capture read "the highest-scoring
    /// 7500 of 195519 matches". macOS's `resultCountLabel` and `overCapAdvisory` have always used
    /// `.formatted()`; these sentences now match. Caught by a test of this type's own that had
    /// hedged `"1000" || "1,000"` — the hedge was the tell.
    private func grouped(_ value: Int) -> String { value.formatted() }

    // MARK: - The results header

    /// The clause naming the applied corpus's OWN capture, for whichever count grammar a
    /// platform uses around it.
    ///
    /// The two search surfaces do not share a count line — iOS renders ``headerDescription`` and
    /// macOS renders `SearchSheet.resultCountLabel`, which has its own settled "loaded · total"
    /// dialect with page ranges. Importing one platform's phrasing into the other would give the
    /// app a third grammar for the same facts. Sharing the *clause* instead keeps the wording in
    /// one place, testable, and unable to drift, while each surface keeps its own sentence.
    ///
    /// `nil` unless the corpus was a truncated capture — including when no corpus is applied, and
    /// when the capture predates the fields (`unrecorded`), which must stay silent.
    var corpusCaptureClause: String? {
        guard case .truncated(let capturedTotal) = appliedCorpusTruncation else { return nil }
        if let capturedTotal {
            return String(format: String(localized: "search.corpus.capturedFrom %@",
                                         defaultValue: "captured from %@ matches"),
                          grouped(capturedTotal))
        }
        return String(localized: "search.corpus.partialCapture",
                      defaultValue: "a partial capture")
    }

    /// "1 result" or "412 results": the count the plain keyword header and the ranked header share.
    ///
    /// The header read "1 results" for a search that found one document until #1577 lane 2: its one string had no
    /// singular. The Mac's count label has had one all along.
    private func resultsPhrase(_ count: Int) -> String {
        count == 1
            ? String(localized: "search.count.one", defaultValue: "1 result")
            : String(format: String(localized: "search.count %@", defaultValue: "%@ results"), grouped(count))
    }

    /// The header clause of the two layered routes (#1577 lane 2), or `nil` for a search through one engine and for a
    /// ranked list of no rows.
    ///
    /// Shared for the reason ``closestMatchesClause`` is: iPhone and iPad render it through ``headerDescription``,
    /// and the Mac's count label is to render the same words when lane 5 gives that window a layer.
    ///
    /// - Words in matches: how many of the held Meaning list's rows hold the words, with the list's size, and a
    ///   sentence of its own when none does.
    /// - Ranked by meaning: the count the keyword list had, said to be closest first, and split into ranked and
    ///   not ranked when some rows could not be scored.
    var layeredHeaderClause: String? {
        switch route {
        case .keywords, .meaning:
            return nil
        case .wordsInMatches(let base):
            if base == 1 {
                return loaded == 0
                    ? String(localized: "search.count.wordsInMatches.single.none",
                             defaultValue: "Your closest match does not contain these words")
                    : String(localized: "search.count.wordsInMatches.single",
                             defaultValue: "Your closest match contains these words")
            }
            switch loaded {
            case 0:
                return String(format: String(localized: "search.count.wordsInMatches.none %@",
                                             defaultValue: "None of your %@ closest matches contains these words"),
                              grouped(base))
            case 1:
                return String(format: String(localized: "search.count.wordsInMatches.one %@",
                                             defaultValue: "1 of your %@ closest matches contains these words"),
                              grouped(base))
            default:
                return String(format: String(localized: "search.count.wordsInMatches %@ %@",
                                             defaultValue: "%1$@ of your %2$@ closest matches contain these words"),
                              grouped(loaded), grouped(base))
            }
        case .rankedByMeaning(let unranked):
            guard loaded > 0 else { return nil }
            guard unranked > 0 else {
                return String(format: String(localized: "search.count.rankedByMeaning %@",
                                             defaultValue: "%@, closest first"), resultsPhrase(loaded))
            }
            return String(format: String(localized: "search.count.rankedByMeaning.partial %@ %@ %@",
                                         defaultValue: "%1$@ · %2$@ ranked · %3$@ not ranked"),
                          resultsPhrase(loaded), grouped(max(0, loaded - unranked)), grouped(unranked))
        }
    }

    /// The results-count header — the line where the three-way collision lived.
    ///
    /// It read `"%lld results"` over the checklist-**filtered** count while the line beneath read
    /// `"Showing the first 1,000 results"` over the **fetched** count, so a filtered capped search
    /// rendered "987 results" directly above "Showing the first 1,000 results".
    ///
    /// Now every number is labelled, and only the numbers that mean something appear: an ordinary
    /// complete search still reads "412 results", because when nothing is hidden and nothing is
    /// truncated one number does mean one thing, and labelling it would be noise. The grammar
    /// follows macOS's existing `resultCountLabel` — "loaded", "total", "total unavailable" —
    /// rather than inventing a third dialect for the same facts.
    var headerDescription: String {
        // The layered routes first. A layer that found nothing says what it looked in, which "No results" would not.
        // And its clause counts what was loaded, so what the checklist hides is said beside it, down to "0 shown":
        // finds that are all hidden are still finds.
        if let layered = layeredHeaderClause {
            guard hiddenByChecklist > 0 else { return layered }
            return [String(format: String(localized: "search.count.shown %@", defaultValue: "%@ shown"),
                           grouped(shown)),
                    layered].joined(separator: " · ")
        }
        if shown == 0 {
            return String(localized: "search.count.none", defaultValue: "No results")
        }
        // Before every keyword branch: none of them can describe this set. See ``isMeaningSearch``.
        if isMeaningSearch { return closestMatchesClause }
        if !didHitFetchLimit, hiddenByChecklist == 0 {
            // Inside a corpus that was itself a capped capture, a bare count is the very claim
            // this type exists to stop: the number is exact for the corpus and says nothing about
            // the question the corpus was an answer to. The corpus's own total is the honest
            // second figure — not this fetch's, which has none.
            if let clause = corpusCaptureClause {
                return String(format: String(
                    localized: "search.count.inTruncatedCorpus %@ %@",
                    defaultValue: "%1$@ in this corpus · %2$@"),
                    grouped(shown), clause)
            }
            return resultsPhrase(shown)
        }
        if !didHitFetchLimit {
            return String(format: String(localized: "search.count.shownOf %@ %@",
                                         defaultValue: "%1$@ shown of %2$@ results"),
                          grouped(shown), grouped(loaded))
        }
        var parts: [String] = []
        if hiddenByChecklist > 0 {
            parts.append(String(format: String(localized: "search.count.shown %@",
                                               defaultValue: "%@ shown"), grouped(shown)))
        }
        parts.append(String(format: String(localized: "search.count.loaded %@",
                                           defaultValue: "%@ loaded"), grouped(loaded)))
        parts.append(totalMatchCount.map {
            String(format: String(localized: "search.count.total %@",
                                  defaultValue: "%@ total"), grouped($0))
        } ?? String(localized: "search.count.total.unavailable",
                    defaultValue: "total unavailable"))
        return parts.joined(separator: " · ")
    }

    /// The advice under a truncated result set — advice only, with no number of its own.
    ///
    /// It used to carry `searchHardLimit`, which is what put a second unlabelled "results" count
    /// on screen. ``headerDescription`` states the numbers now, once, with labels.
    ///
    /// None for a keyword list ranked by a question (#1577 lane 2). It was cut where the keyword fetch was cut, and the
    /// field now holds the question, so advice to add keywords is not advice the reader can take there.
    var overCapGuidance: String? {
        guard didHitFetchLimit else { return nil }
        if case .rankedByMeaning = route { return nil }
        return String(localized: "search.capped.guidance",
                      defaultValue: "Add more keywords or filters to see more specific results.")
    }

    // MARK: - Capture (the modal — states the whole chain)

    /// Why the captured set may not be the whole answer to the query.
    ///
    /// `nil` when the fetch did not hit its ceiling, because then the loaded set *is* every
    /// matching document and a caveat would be noise.
    ///
    /// This is the one place in the app where getting it wrong becomes a wrong published claim:
    /// a working corpus is durable, synced, and cited, and the same query captured on an iPhone
    /// and a Mac at the same instant against the same index yields 1,000 keys and 7,500.
    ///
    /// **Never `nil` for a Meaning search** (#1598). Its list is not a match at all, so no count of rows makes it
    /// "every matching document". The sentence carries no number: the sheet's Documents row is one line above it.
    var captureTruncationWarning: String? {
        if isMeaningSearch {
            return String(localized: "corpus.save.meaning",
                          defaultValue: "These documents are the closest matches a Meaning search found, not every document on your subject. Counts taken inside this corpus are counts inside that set.")
        }
        // Never `nil` for words found in a Meaning list either: they are some of that list (#1577 lane 2).
        if case .wordsInMatches = route {
            // The capture is of what is shown, so the number agrees with that.
            return shown == 1
                ? String(localized: "corpus.save.wordsInMatches.one",
                         defaultValue: "This document is the one among a Meaning search’s closest matches that contains your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.")
                : String(localized: "corpus.save.wordsInMatches",
                         defaultValue: "These documents are the ones among a Meaning search’s closest matches that contain your words, not every document that contains them. Counts taken inside this corpus are counts inside that set.")
        }
        guard didHitFetchLimit else { return nil }
        if let totalMatchCount {
            return String(format: String(
                localized: "corpus.save.truncated.total %@ %@",
                defaultValue: "These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset."),
                grouped(loaded), grouped(totalMatchCount))
        }
        return String(format: String(
            localized: "corpus.save.truncated.unknown %@",
            defaultValue: "These %@ documents are the highest-scoring of a larger match, not all of it. Counts taken inside this corpus are counts inside that subset."),
            grouped(loaded))
    }

    /// What checklist mode is keeping out of the capture.
    ///
    /// The capture deliberately takes the checklist-filtered set — what you see is what you save —
    /// which is defensible and silent. Saying so at the moment of capture is what makes it a
    /// choice rather than a surprise.
    var captureChecklistWarning: String? {
        guard hiddenByChecklist > 0 else { return nil }
        return String(format: String(
            localized: "corpus.save.checklistHiding %@",
            defaultValue: "Checklist mode is hiding %@ reviewed documents. They will not be in this corpus."),
            grouped(hiddenByChecklist))
    }

    /// The provenance sentence stored on the corpus itself.
    ///
    /// Goes into `WorkingCorpus.sourceDescription`, an **existing** stored property — so the record
    /// becomes self-describing at zero CloudKit schema cost, which is what makes this affordable.
    /// A corpus read on another device, or a year later, carries its own truncation with it.
    ///
    /// A Meaning search names its engine instead of "Search results" (#1598), as a lasso reads "Semantic map
    /// selection" and a cluster "Semantic cluster, browsed": the screen it was saved from said "closest matches", and
    /// the record that outlives the screen has to say so too.
    var captureProvenanceDescription: String {
        var description: String
        if isMeaningSearch {
            description = loaded == 1
                ? String(localized: "corpus.save.source.meaning.one",
                         defaultValue: "Meaning search — the closest match")
                : String(format: String(localized: "corpus.save.source.meaning %@",
                                        defaultValue: "Meaning search — the %@ closest matches"),
                         grouped(loaded))
        } else if case .wordsInMatches(let base) = route {
            // Named for what it is, as a Meaning list is: the record outlives the screen that said so.
            description = String(format: String(
                localized: "corpus.save.source.wordsInMatches %@ %@",
                defaultValue: "Words found in a Meaning search’s closest matches — %1$@ of %2$@"),
                grouped(loaded), grouped(base))
        } else {
            // A keyword list, in its own order or reordered by a question: a corpus stores a set and not an order.
            description = String(localized: "corpus.save.source.search", defaultValue: "Search results")
        }
        if didHitFetchLimit {
            if let totalMatchCount {
                description += String(format: String(
                    localized: "corpus.save.source.truncated.total %@ %@",
                    defaultValue: " — the highest-scoring %1$@ of %2$@ matches"),
                    grouped(loaded), grouped(totalMatchCount))
            } else {
                description += String(format: String(
                    localized: "corpus.save.source.truncated.unknown %@",
                    defaultValue: " — the highest-scoring %@ of a larger match"),
                    grouped(loaded))
            }
        }
        if hiddenByChecklist > 0 {
            description += String(format: String(
                localized: "corpus.save.source.checklist %@",
                defaultValue: "; %@ reviewed documents excluded"),
                grouped(hiddenByChecklist))
        }
        return description
    }

    /// What a capture of these results stores as `WorkingCorpus.wasTruncatedAtCapture`.
    ///
    /// ``isPartialEvidence``, and not ``didHitFetchLimit``, for a keyword search: a capture made inside a corpus that
    /// was itself cut short is partial for a reason this fetch cannot see.
    ///
    /// **Always `true` for a Meaning search** (#1598). The stored flag has two recorded values, and `false` reads back
    /// as `WorkingCorpus.CaptureTruncation.complete`, "the capture was every matching document", which a ranking's
    /// nearest documents are not. `true` with no total is the value every reader of the flag already treats with care:
    /// the corpus lists print their amber line, the method appendix prints its completeness note, and a search run
    /// inside the corpus is captioned as partial evidence.
    ///
    /// Words found inside a Meaning list are partial too, through ``isPartialEvidence``. A keyword list reordered by a
    /// question is as whole as the keyword fetch was.
    var isCapturePartial: Bool { isMeaningSearch || isPartialEvidence }

    // MARK: - Panels (state only their own narrowing — never restate the cap)

    /// The concordance's occurrence count, qualified by the set it came from.
    ///
    /// A bare "214 occurrences" travels out of context in a screenshot or a quotation, with nothing
    /// to say that 214 came from twenty-five documents rather than a thousand. Unqualified when
    /// there is only one page, where "on this page" would be a distinction without a difference.
    func concordanceCountDescription(occurrences: Int) -> String {
        guard !isSinglePage else {
            return String(format: String(localized: "search.kwic.count %@",
                                         defaultValue: "%@ occurrences"), grouped(occurrences))
        }
        return String(format: String(
            localized: "search.kwic.count.paged %@ %lld",
            defaultValue: "%1$@ occurrences in the %2$lld documents on this page"),
            grouped(occurrences), Int64(documentsOnPage))
    }

    /// What the collocation measured over.
    ///
    /// Carries **no numbers** deliberately: on macOS the over-cap advisory sits two lines above
    /// with the same two figures, and the sort bar's result count is a third. The distinction this
    /// draws — the whole loaded set, not the page — is the one nothing else on screen states.
    var collocationScopeDescription: String {
        var description: String
        if case .wordsInMatches = route {
            // Not "the highest-scoring matches": these rows were chosen by a question, and kept for their words.
            description = String(localized: "search.collocation.caveat.scope.loaded.wordsInMatches",
                                 defaultValue: "Measured over every result this search loaded, not the page on screen — those are the closest matches that contain your words, not every document that contains them.")
        } else {
            description = isPartialEvidence
                ? String(localized: "search.collocation.caveat.scope.loaded.capped",
                         defaultValue: "Measured over every result this search loaded, not the page on screen — those are the highest-scoring matches, not a sample of all of them.")
                : String(localized: "search.collocation.caveat.scope.loaded.complete",
                         defaultValue: "Measured over every result this search loaded, which is every matching document.")
        }
        if hiddenByChecklist > 0 {
            description += String(format: String(
                localized: "search.collocation.caveat.scope.checklist %@",
                defaultValue: " %@ reviewed documents are excluded."),
                grouped(hiddenByChecklist))
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
    ///
    /// Words found in a Meaning list have a caption of their own (#1577 lane 2): they are not the highest-scoring of a
    /// larger keyword match, they are the rows of a ranking that hold the words.
    var timelineBiasCaption: String? {
        guard isPartialEvidence else { return nil }
        if case .wordsInMatches = route {
            return String(localized: "search.timeline.bias.wordsInMatches",
                          defaultValue: "These are the closest matches that contain your words, not a sample across time — this shape is theirs, not the whole match’s.")
        }
        return String(localized: "search.timeline.bias",
                      defaultValue: "These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.")
    }
}
