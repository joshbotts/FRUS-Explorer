// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// The research layer's rules, over the values a host's rows map to (S17b). The app's own suites hold
// the same rules through its models (`SavedSearchFreshnessTests`, `WorkingCorpusTests`,
// `CustomVolumeScopeTests`, `ResearchTrailSessionsTests`, `TrailRecordedCountTests`,
// `DocumentEngagementServiceTests`, `ResearchDocumentAggregationTests`, `ResearchItemCountsTests`,
// `NotesPaneSnapshotTests`); these hold the kit's own API, as FRUS Explorer Light calls it, on every
// platform the kit compiles for.

private func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012lld", Int64(number)))!
}

private let english = Locale(identifier: "en_US")

// MARK: - SavedSearchFreshnessKitTests

/// "+N since last run", over a saved search's mark and its count now.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("A saved search's freshness, in the kit")
struct SavedSearchFreshnessKitTests {

    private let ran = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("A search never run shows no badge, and needs no count")
    func neverRun() {
        let mark = SavedSearchFreshness(lastRunAt: nil, matchCountAtLastRun: 12, indexedVolumeCountAtLastRun: 3)
        #expect(!mark.hasRun)
        #expect(mark.evaluation(currentCount: 40) == .noBadge)
    }

    @Test("A count that failed shows no badge")
    func noCount() {
        #expect(SavedSearchFreshness.run(at: ran, matchCount: 10, indexedVolumeCount: 5)
                    .evaluation(currentCount: nil) == .noBadge)
    }

    @Test("A run without a count is backfilled with the count now, keeping its time, and shows no badge")
    func backfill() {
        let mark = SavedSearchFreshness.run(at: ran, matchCount: nil, indexedVolumeCount: 5)
        #expect(mark.hasRun && mark.matchCountAtLastRun == nil)
        #expect(mark.evaluation(currentCount: 17) == .backfill(SavedSearchFreshness(
            lastRunAt: ran, matchCountAtLastRun: 17, indexedVolumeCountAtLastRun: 5)))
    }

    @Test("Growth is the badge; the same count and a smaller one are none")
    func growth() {
        let mark = SavedSearchFreshness.run(at: ran, matchCount: 10, indexedVolumeCount: nil)
        #expect(mark.evaluation(currentCount: 13) == .newResults(3))
        #expect(mark.evaluation(currentCount: 10) == .noBadge)
        #expect(mark.evaluation(currentCount: 4) == .noBadge)
        #expect(SavedSearchFreshness.verdict(current: 13, baseline: 10) == 3)
        #expect(SavedSearchFreshness.verdict(current: 9, baseline: 10) == nil)
    }

    @Test("The stored blob: a plain encoder's keys, the date in seconds since 2001, read back whole")
    func blob() throws {
        let mark = SavedSearchFreshness.run(at: ran, matchCount: 3, indexedVolumeCount: nil)
        let data = try #require(mark.encoded)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["lastRunAt", "matchCountAtLastRun"])
        #expect((object["lastRunAt"] as? NSNumber)?.doubleValue == 800_000_000)
        #expect(SavedSearchFreshness.decoded(from: data) == mark)
        #expect(SavedSearchFreshness.decoded(from: nil) == nil)
        #expect(SavedSearchFreshness.decoded(from: Data("not json".utf8)) == nil)
    }

    @Test("A blob with a field of the wrong type keeps the fields that parse")
    func tolerantBlob() {
        let data = Data(#"{"lastRunAt": 800000000, "matchCountAtLastRun": "twelve", "indexedVolumeCountAtLastRun": 4}"#.utf8)
        #expect(SavedSearchFreshness.decoded(from: data) == SavedSearchFreshness(
            lastRunAt: ran, matchCountAtLastRun: nil, indexedVolumeCountAtLastRun: 4))
    }
}

// MARK: - WorkingCorpusRulesTests

/// How a working corpus becomes a search's filter: resolved by volume, composed by the gate.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("Working corpora and the document gate, in the kit")
struct WorkingCorpusRulesTests {

    @Test("A corpus resolves by volume: the indexed keys in their order, the rest named by volume")
    func resolvesByVolume() {
        let resolver = WorkingCorpusResolver(indexedVolumeIds: ["v1", "v3"])
        let resolution = resolver.resolve(documentKeys: ["v1/d1", "v2/d1", "v3/d9", "v2/d4", "v4/d2", "v1/d2"])
        #expect(resolution.indexedKeys == ["v1/d1", "v3/d9", "v1/d2"])
        #expect(resolution.totalCount == 6 && resolution.indexedCount == 3 && !resolution.isComplete)
        #expect(resolution.missingVolumeIds == ["v2", "v4"])
        #expect(resolver.resolve(documentKeys: ["v1/d1", "v3/d2"]).isComplete)
    }

    @Test("The gate intersects what was asked for, and an empty intersection stays an empty array")
    func gate() {
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: nil) == nil)
        #expect(DocumentScopeGate.combine(corpus: ["a"], projectGate: nil) == ["a"])
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: ["b"]) == ["b"])
        #expect(DocumentScopeGate.combine(corpus: ["c", "a", "b"], projectGate: ["b", "c", "d"]) == ["b", "c"])
        #expect(DocumentScopeGate.combine(corpus: ["a"], projectGate: ["b"]) == [])
        #expect(DocumentScopeGate.combine(corpus: ["a", "b"], projectGate: nil, pin: ["b", "z"]) == ["b"])
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: nil, pin: ["z"]) == ["z"])
        #expect(DocumentScopeGate.combine(corpus: ["a"], projectGate: ["a"], pin: nil) == ["a"])
    }

    @Test("A recalled search runs inside the applied corpus, under no gate of its own")
    func runningInside() {
        var parameters = SearchParameters(keywords: "berlin")
        parameters.documentIds = ["v9/d9"]
        parameters.excludeDocumentIds = ["v9/d8"]
        let inside = parameters.runningInside(workingCorpus: ["v1/d1"])
        #expect(inside.documentIds == ["v1/d1"] && inside.excludeDocumentIds == nil && inside.keywords == "berlin")
        let outside = parameters.runningInside(workingCorpus: nil)
        #expect(outside.documentIds == nil && outside.excludeDocumentIds == nil)
        #expect(parameters.runningInside(workingCorpus: []).documentIds == [])
    }

    @Test("A corpus saved from a Meaning search is known by the sentence its capture stored")
    func meaningProvenance() {
        #expect(WorkingCorpusProvenance.meaningSearch == "Meaning search — the %@ closest matches")
        #expect(WorkingCorpusProvenance.isMeaningCapture("Meaning search — the 100 closest matches"))
        #expect(WorkingCorpusProvenance.isMeaningCapture("Meaning search — the closest match"))
        #expect(WorkingCorpusProvenance.isMeaningCapture("Meaning search — the 1,200 closest matches (years 1945)"))
        #expect(!WorkingCorpusProvenance.isMeaningCapture("Search results"))
        #expect(!WorkingCorpusProvenance.isMeaningCapture(nil))
    }

    @Test("A capture's truncation is read from its two fields, in three states")
    func truncationFromFields() {
        #expect(CorpusCaptureTruncation(wasTruncated: true, totalMatchCount: 40_000) == .truncated(total: 40_000))
        #expect(CorpusCaptureTruncation(wasTruncated: true, totalMatchCount: nil) == .truncated(total: nil))
        #expect(CorpusCaptureTruncation(wasTruncated: false, totalMatchCount: 12) == .complete)
        #expect(CorpusCaptureTruncation(wasTruncated: nil, totalMatchCount: 12) == .unrecorded)
    }

    @Test("The truncation line, its counts grouped for the locale as Foundation groups them")
    func truncationLine() {
        #expect(CorpusCaptureTruncation.truncated(total: 40_000).line(documentCount: 7_500, locale: english)
                == "Saved 7,500 of 40,000 matches")
        #expect(CorpusCaptureTruncation.truncated(total: 40_000)
                    .line(documentCount: 7_500, locale: Locale(identifier: "de_DE"))
                == "Saved 7.500 of 40.000 matches")
        #expect(CorpusCaptureTruncation.truncated(total: nil).line(documentCount: 7_500, locale: english)
                == "The capture stopped short of every match")
        #expect(CorpusCaptureTruncation.truncated(total: nil)
                    .line(documentCount: 1_200, isMeaningCapture: true, locale: english)
                == "The 1,200 closest matches of a Meaning search")
        #expect(CorpusCaptureTruncation.truncated(total: 100)
                    .line(documentCount: 1, isMeaningCapture: true, locale: english)
                == "The closest match of a Meaning search")
        #expect(CorpusCaptureTruncation.complete.line(documentCount: 3, locale: english) == nil)
        #expect(CorpusCaptureTruncation.unrecorded.line(documentCount: 3, locale: english)
                == "Capture completeness not recorded")
    }
}

// MARK: - CustomScopeResolutionTests

/// How a volume scope becomes a search's filter: never a bare, possibly empty set.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("Volume scopes, in the kit")
struct CustomScopeResolutionTests {

    @Test("A scope resolves to its indexed members, or says it has none")
    func indexedResolution() {
        #expect(CustomScopeResolver.indexedResolution(memberVolumeIds: ["v1", "v2", "v2"], indexed: ["v2", "v3"])
                == .resolved(["v2"]))
        #expect(CustomScopeResolver.indexedResolution(memberVolumeIds: ["v1"], indexed: ["v2"]) == .noIndexedMembers)
        #expect(CustomScopeResolver.indexedResolution(memberVolumeIds: [], indexed: ["v2"]) == .noIndexedMembers)
    }

    @Test("At the manifest's grain, an id the manifest does not know is skipped")
    func manifestGrain() {
        #expect(CustomScopeResolver.manifestVolumeIds(memberVolumeIds: ["v1", "gone"], manifestIds: ["v1", "v2"])
                == ["v1"])
    }
}

// MARK: - ResearchTrailWindowTests

/// The trail's sessions, split by a 30-minute gap, and the newest window they are read from.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("The trail's sessions, in the kit")
struct ResearchTrailWindowTests {

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func activity(_ number: Int, minutes: Double) -> ResearchTrailActivity {
        ResearchTrailActivity(id: id(number), kind: .search(query: "q\(number)", resultCount: number),
                              timestamp: start.addingTimeInterval(minutes * 60), projectId: nil)
    }

    @Test("A gap of more than 30 minutes starts a session; sessions newest first, activities oldest first")
    func splitsOnTheGap() {
        let activities = [activity(1, minutes: 0), activity(2, minutes: 30), activity(3, minutes: 60.02),
                          activity(4, minutes: 61)]
        let sessions = ResearchTrailSessions.group(activities.reversed())
        #expect(sessions.map { $0.activities.map(\.id) } == [[id(3), id(4)], [id(1), id(2)]])
        #expect(sessions.map(\.id) == [id(3), id(1)])
        #expect(sessions[1].duration == 1_800 && sessions[0].startedAt == activities[2].timestamp)
        #expect(sessions[0].endedAt == activities[3].timestamp && sessions[0].activityCount == 2)
        #expect(ResearchTrailSessions.idleInterval == 1_800)
        #expect(ResearchTrailSessions.group([]).isEmpty)
    }

    @Test("Two activities at one instant keep one order, by id, whatever order they arrive in")
    func tiesByID() {
        let a = ResearchTrailActivity(id: id(9), kind: .export(format: "pdf", documentCount: 3, collectionName: nil),
                                      timestamp: start, projectId: nil)
        let b = ResearchTrailActivity(id: id(2), kind: .documentOpen(volumeId: "v1", documentId: "d1", displayTitle: nil),
                                      timestamp: start, projectId: nil)
        #expect(ResearchTrailSessions.group([a, b])[0].activities.map(\.id) == [id(2), id(9)])
        #expect(ResearchTrailSessions.group([b, a])[0].activities.map(\.id) == [id(2), id(9)])
        #expect(ResearchTrailSessions.newestFirst([b, a], limit: 2).map(\.id) == [id(9), id(2)])
    }

    @Test("A session is ongoing while the next activity would still join it")
    func ongoing() throws {
        let session = try #require(ResearchTrailSessions.group([activity(1, minutes: 0)]).first)
        #expect(session.isOngoing(asOf: session.endedAt.addingTimeInterval(1_800)))
        #expect(!session.isOngoing(asOf: session.endedAt.addingTimeInterval(1_801)))
        #expect(session.duration == 0)
    }

    @Test("The newest window merges the tables newest first and is cut to its limit")
    func newestWindow() {
        let visits = [activity(1, minutes: 5), activity(2, minutes: 50)]
        let searches = [activity(3, minutes: 40), activity(4, minutes: 1)]
        let exports = [activity(5, minutes: 45)]
        #expect(ResearchTrailSessions.newestFirst(visits + searches + exports, limit: 3).map(\.id)
                == [id(2), id(5), id(3)])
        #expect(ResearchTrailSessions.newestFirst(exports, limit: 3).map(\.id) == [id(5)])
    }

    @Test("A page of the trail groups its window and counts the dated rows it is drawn from")
    func page() {
        let window = ResearchTrailSessions.newestFirst(
            [activity(1, minutes: 0), activity(2, minutes: 10), activity(3, minutes: 100)], limit: 3)
        let page = SessionLogSnapshot.page(of: window, datedActivityCount: 5, limit: 3)
        #expect(page.sessions.count == 2 && page.loadedActivities == 3 && page.totalActivities == 5)
        #expect(page.hasMore && !page.isEmpty && page.pageLimit == 3)
        #expect(SessionLogSnapshot.empty.isEmpty && !SessionLogSnapshot.empty.hasMore)
        #expect(SessionLogSnapshot.empty.pageLimit == SessionLogSnapshot.defaultPageLimit)
        #expect(SessionLogSnapshot.page(of: [], datedActivityCount: 0, limit: 1_000).isEmpty)
    }
}

// MARK: - RecordedSearchCountTests

/// A recorded search's count, read in four states, never a floor as a total.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("A recorded search's count, in the kit")
struct RecordedSearchCountTests {

    private typealias Count = RecordedSearch.RecordedCount

    @Test("A row's fields are read in four states")
    func fourStates() {
        let keyword = "mode=and;dates=none"
        #expect(Count(resultCount: 412, loadedCount: nil, matchCount: nil, fetchLimit: nil, scopeSignature: nil)
                == .unrecorded(reported: 412))
        #expect(Count(resultCount: 412, loadedCount: 412, matchCount: nil, fetchLimit: nil, scopeSignature: keyword)
                == .unrecorded(reported: 412))
        #expect(Count(resultCount: 7_500, loadedCount: 7_500, matchCount: 40_000, fetchLimit: 7_500,
                      scopeSignature: keyword) == .exact(match: 40_000, loaded: 7_500))
        #expect(Count(resultCount: 7_500, loadedCount: 7_500, matchCount: nil, fetchLimit: 7_500,
                      scopeSignature: keyword) == .floor(loaded: 7_500, fetchLimit: 7_500))
        #expect(Count(resultCount: 212, loadedCount: 212, matchCount: nil, fetchLimit: 7_500,
                      scopeSignature: keyword) == .completeWithoutTotal(loaded: 212))
    }

    @Test("A Meaning list with no match count is the list it recorded, never a floor")
    func meaningList() {
        #expect(Count(resultCount: 100, loadedCount: 100, matchCount: nil, fetchLimit: 100,
                      scopeSignature: SearchScopeSignature.semanticRouteSignature) == .exact(match: 100, loaded: 100))
    }

    @Test("A floor, or a count inside a capture cut short, is partial evidence")
    func partialEvidence() {
        #expect(Count.floor(loaded: 7_500, fetchLimit: 7_500).isPartialEvidence())
        #expect(!Count.exact(match: 3, loaded: 3).isPartialEvidence())
        #expect(Count.exact(match: 3, loaded: 3).isPartialEvidence(corpusTruncation: .truncated(total: nil)))
        #expect(!Count.exact(match: 3, loaded: 3).isPartialEvidence(corpusTruncation: .unrecorded))
    }

    @Test("A recorded search reads its count by the rule, and the appendix prints each kind")
    func recordedSearch() {
        let search = RecordedSearch(id: id(1), queryText: "x", resultCount: 3, loadedCount: 3, matchCount: nil,
                                    fetchLimit: 1_000)
        #expect(search.recordedCount == .completeWithoutTotal(loaded: 3))
        #expect(Count.floor(loaded: 7_500, fetchLimit: 7_500).appendixDescription(locale: english) == "at least 7,500")
        #expect(Count.unrecorded(reported: 1_204).appendixDescription(locale: english) == "1,204 (as reported)")
        #expect(Count.floor(loaded: 7_500, fetchLimit: 7_500).basisToken == "floor")
        let numbers = Count.floor(loaded: 7_500, fetchLimit: 7_500).csvNumbers
        #expect(numbers.match == "" && numbers.loaded == "7500" && numbers.limit == "7500" && numbers.reported == "")
        #expect(Count.unrecorded(reported: 9).displayedTotal == 9)
    }
}

// MARK: - DocumentEngagementRulesTests

/// What counts as opened, annotated and collected, over values, and a corpus partitioned by it.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("A corpus's coverage, in the kit")
struct DocumentEngagementRulesTests {

    private typealias Service = DocumentEngagementService
    private let mine = id(100)
    private let theirs = id(200)

    @Test("Opened: the project's visits, or every visit with none; a visit to no document is none")
    func opened() {
        let visits = [Service.Visit(volumeId: "v1", documentId: "d1", projectId: mine),
                      Service.Visit(volumeId: "v1", documentId: "d2", projectId: theirs),
                      Service.Visit(volumeId: "v1", documentId: "", projectId: mine),
                      Service.Visit(volumeId: "v2", documentId: "d3", projectId: nil)]
        #expect(Service.openedKeys(among: visits, forProject: mine) == ["v1/d1"])
        #expect(Service.openedKeys(among: visits, forProject: nil) == ["v1/d1", "v1/d2", "v2/d3"])
    }

    @Test("Annotated: the project's notes, and highlights through their note; a standalone highlight only with none")
    func annotated() {
        let notes = [Service.Note(id: id(1), volumeId: "v1", documentId: "d1", projectIds: [mine]),
                     Service.Note(id: id(2), volumeId: "v1", documentId: "d2", projectIds: [theirs]),
                     Service.Note(id: id(3), volumeId: "", documentId: "", projectIds: [mine])]
        let highlights = [Service.Highlight(volumeId: "v1", documentId: "d5", noteId: id(1)),
                          Service.Highlight(volumeId: "v1", documentId: "d6", noteId: id(2)),
                          Service.Highlight(volumeId: "v1", documentId: "d7", noteId: nil)]
        #expect(Service.annotatedKeys(among: notes, highlights: highlights, forProject: mine) == ["v1/d1", "v1/d5"])
        #expect(Service.annotatedKeys(among: notes, highlights: highlights, forProject: nil)
                == ["v1/d1", "v1/d2", "v1/d5", "v1/d6", "v1/d7"])
    }

    @Test("Collected: documents entered in the project's collections; an excerpt or a heading is not one")
    func collected() {
        let collections = [
            Service.CollectionDocuments(projectIds: [mine], entries: [
                .init(kind: "document", volumeId: "v1", documentId: "d1"),
                .init(kind: "excerpt", volumeId: "v1", documentId: "d2"),
                .init(kind: "heading", volumeId: "", documentId: "")]),
            Service.CollectionDocuments(projectIds: [theirs], entries: [
                .init(kind: "document", volumeId: "v1", documentId: "d4")]),
        ]
        #expect(Service.collectedKeys(among: collections, forProject: mine) == ["v1/d1"])
        #expect(Service.collectedKeys(among: collections, forProject: nil) == ["v1/d1", "v1/d4"])
        #expect(Service.isInScope([theirs, mine], forProject: mine) && Service.isInScope([], forProject: nil))
        #expect(!Service.isInScope([], forProject: mine))
    }

    @Test("Gathered once, a corpus is partitioned by kind, each kind counted inside the corpus")
    func partition() {
        let keys = Service.gather(among: Service.Sources(
            visits: [.init(volumeId: "v1", documentId: "d1", projectId: nil),
                     .init(volumeId: "v9", documentId: "d9", projectId: nil)],
            notes: [.init(id: id(1), volumeId: "v1", documentId: "d1", projectIds: [])],
            highlights: [.init(volumeId: "v1", documentId: "d2", noteId: nil)],
            collections: [.init(projectIds: [], entries: [.init(kind: "document", volumeId: "v1", documentId: "d2")])]),
            forProject: nil)
        let coverage = Service.partition(corpusKeys: ["v1/d1", "v1/d2", "v1/d3"], keys: keys, isOpenedComplete: false)
        #expect(coverage.engagedCount == 2 && coverage.untouchedCount == 1)
        #expect(coverage.openedCount == 1 && coverage.annotatedCount == 2 && coverage.collectedCount == 1)
        #expect(coverage.state(for: "v1/d1") == .annotated && coverage.state(for: "v1/d3") == .untouched)
        #expect(coverage.coverageDescription(locale: english) == "2 of 3 documents worked on")
        #expect(coverage.breakdownDescription(locale: english) == "1 opened · 2 annotated · 1 collected")
        #expect(coverage.untouchedDescription(locale: english) == "1 untouched")
        #expect(coverage.loggingCaveat != nil)
        let none = Service.partition(corpusKeys: (1...1_200).map { "v1/d\($0)" }, keys: keys, isOpenedComplete: true)
        #expect(none.coverageDescription(locale: english) == "2 of 1,200 documents worked on")
        #expect(none.loggingCaveat == nil)
        let empty = Service.partition(corpusKeys: ["v2/d1"], keys: keys, isOpenedComplete: true)
        #expect(empty.breakdownDescription(locale: english) == nil)
    }
}

// MARK: - ResearchAggregationRulesTests

/// The Research page's documents, over values: what an annotation is, and the six sources.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("The Research page's documents, in the kit")
struct ResearchAggregationRulesTests {

    private typealias Aggregation = ResearchDocumentAggregation

    @Test("A document or an excerpt entry counts; the other kinds, a newer build's among them, do not")
    func kinds() {
        #expect(Aggregation.countsAsAnnotation("document") && Aggregation.countsAsAnnotation("excerpt"))
        for kind in ["heading", "prose", "generated", "unrecognized", "a kind from a newer build"] {
            #expect(!Aggregation.countsAsAnnotation(kind), "\(kind)")
        }
    }

    @Test("A collection's distinct documents, under that rule")
    func distinctDocuments() {
        #expect(Aggregation.distinctDocumentKeys(among: [
            .init(kind: "document", volumeId: "v1", documentId: "d1"),
            .init(kind: "excerpt", volumeId: "v1", documentId: "d1"),
            .init(kind: "excerpt", volumeId: "v1", documentId: "d2"),
            .init(kind: "heading", volumeId: "", documentId: ""),
            .init(kind: "document", volumeId: "", documentId: ""),
        ]) == ["v1/d1", "v1/d2"])
    }

    @Test("Every annotated document across the six sources, headnote drafts left out")
    func sixSources() {
        let sources = Aggregation.Sources(
            notes: [.init(volumeId: "v1", documentId: "d1"), .init(volumeId: "", documentId: "")],
            tagAssignments: [.init(volumeId: "v1", documentId: "d2")],
            collections: [[.init(kind: "document", volumeId: "v1", documentId: "d3"),
                           .init(kind: "prose", volumeId: "", documentId: "")],
                          [.init(kind: "excerpt", volumeId: "v1", documentId: "d4")]],
            highlights: [.init(volumeId: "v1", documentId: "d5")],
            summaries: [.init(volumeId: "v1", documentId: "d6", isHeadnoteDraft: false),
                        .init(volumeId: "v1", documentId: "d7", isHeadnoteDraft: true)],
            visitDocumentKeys: ["v1/d8", ""])
        #expect(Aggregation.annotatedKeys(among: sources)
                == ["v1/d1", "v1/d2", "v1/d3", "v1/d4", "v1/d5", "v1/d6", "v1/d8"])
    }

    @Test("Summary counts per document, drafts left out")
    func summaryCounts() {
        #expect(Aggregation.summaryCounts(among: [
            .init(volumeId: "v1", documentId: "d1", isHeadnoteDraft: false),
            .init(volumeId: "v1", documentId: "d1", isHeadnoteDraft: false),
            .init(volumeId: "v1", documentId: "d1", isHeadnoteDraft: true),
            .init(volumeId: "v1", documentId: "d2", isHeadnoteDraft: false),
            .init(volumeId: "", documentId: "", isHeadnoteDraft: false),
        ]) == ["v1/d1": 2, "v1/d2": 1])
    }

    @Test("A vanished document opens the review sheet; a change is said in what two hashes prove")
    func changes() {
        func revision(_ kind: String?) -> IndexingPipeline.DocumentRevision {
            .init(volumeId: "v1", documentId: "d1", contentHash: "c", bodyHash: "b",
                  changedAt: "2026-09-03T00:00:00Z", changeKind: kind, reviewedAt: nil)
        }
        #expect(Aggregation.rowDestination(revision: nil, isVanished: true) == .reviewSheet)
        #expect(Aggregation.rowDestination(revision: revision("vanished"), isVanished: false) == .reviewSheet)
        #expect(Aggregation.rowDestination(revision: revision("body"), isVanished: false) == .document)
        #expect(Aggregation.changeLine(for: revision("body"))
                == "Text changed in an update — highlight positions may have moved")
        #expect(Aggregation.changeLine(for: revision("vanished")) == Aggregation.vanishedLine)
        #expect(Aggregation.changeLine(for: revision("a kind from a newer build")) == nil)
    }
}

// MARK: - ResearchItemTallyTests

/// What hangs off each project and tag, counted once per id.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("Projects' and tags' tallies, in the kit")
struct ResearchItemTallyTests {

    @Test("Each note, collection and assignment counts once per id; an id nothing carries is absent")
    func tally() {
        let (p1, p2, t1, t2) = (id(1), id(2), id(11), id(12))
        let counts = ResearchItemCounts.tally(noteProjectIds: [[p1, p1], [p1, p2], []],
                                              noteTagIds: [[t1], [t1, t1], []],
                                              collectionProjectIds: [[p2], [p2, p2]],
                                              assignmentTagIds: [t1, t2, t2])
        #expect(counts.project(p1) == ResearchItemCounts.ProjectTally(notes: 2, collections: 0))
        #expect(counts.project(p2) == ResearchItemCounts.ProjectTally(notes: 1, collections: 2))
        #expect(counts.tag(t1) == ResearchItemCounts.TagTally(notes: 2, documents: 1))
        #expect(counts.tag(t2) == ResearchItemCounts.TagTally(notes: 0, documents: 2))
        #expect(counts.projects[id(3)] == nil && counts.project(id(3)) == ResearchItemCounts.ProjectTally())
        #expect(ResearchItemCounts.empty.projects.isEmpty && ResearchItemCounts.empty.tags.isEmpty)
    }

    @Test("A row's summary: its counts, or the words for none")
    func summaries() {
        #expect(ResearchItemCounts.ProjectTally().summary == "Nothing filed yet")
        #expect(ResearchItemCounts.TagTally().summary == "Not applied to anything")
        #expect(ResearchItemCounts.ProjectTally(notes: 1, collections: 2).summary == "1 note · 2 collections")
        #expect(ResearchItemCounts.TagTally(notes: 3, documents: 1).summary == "3 notes · 1 document")
    }
}

// MARK: - NotesPaneRulesTests

/// All Notes: its rows, built from a note's values, its filters and its count.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation
@Suite("All Notes, in the kit")
struct NotesPaneRulesTests {

    private typealias Snapshot = NotesPaneSnapshot

    private func note(_ number: Int, _ body: String, projects: [UUID] = [], tags: [UUID] = [],
                      volume: String = "v1", document: String = "d1") -> Snapshot.Note {
        Snapshot.Note(id: id(number), volumeId: volume, documentId: document, bodyText: body,
                      lastModified: nil, projectIds: projects, userTagIds: tags)
    }

    @Test("A row names its projects and tags in its note's order, leaving out the gone, the first name winning")
    func build() throws {
        let (p1, p2, gone, t1) = (id(1), id(2), id(3), id(11))
        let snapshot = Snapshot.build(notes: [note(20, "Body\nmore", projects: [p2, gone, p1], tags: [t1])],
                                      projects: [(id: p1, name: "Alpha"), (id: p2, name: "Beta"),
                                                 (id: p1, name: "Alpha again")],
                                      tags: [(id: t1, name: "Cables")])
        let row = try #require(snapshot.rows.first)
        #expect(row.projectNames == ["Beta", "Alpha"] && row.tagNames == ["Cables"])
        #expect(row.detail == "v1 / d1 · Beta · Alpha · Cables" && row.title == "Body")
        #expect(snapshot.projects.map(\.name) == ["Alpha", "Beta", "Alpha again"] && snapshot.total == 1)
    }

    @Test("A row's title: the first line with anything in it, trimmed, cut at 90 characters")
    func title() {
        func title(_ body: String) -> String {
            Snapshot.build(notes: [note(1, body)], projects: [], tags: []).rows[0].title
        }
        #expect(title("\r\n   \r\n  First line  \r\nsecond") == "First line")
        #expect(title(String(repeating: "a", count: 90)) == String(repeating: "a", count: 90))
        #expect(title(String(repeating: "a", count: 95)) == String(repeating: "a", count: 90) + "…")
        #expect(title(String(repeating: "a", count: 89) + " bcdef") == String(repeating: "a", count: 89) + "…")
        #expect(title("") == "Empty note" && title(" \n\t") == "Empty note")
        #expect(Snapshot.Row.titleLimit == 90)
    }

    @Test("The filters: a project, no project at all, a tag, and the search field's text")
    func filters() {
        let (p1, p2, t1) = (id(1), id(2), id(11))
        let snapshot = Snapshot.build(notes: [
            note(1, "Berlin airlift cables", projects: [p1], tags: [t1], volume: "frus1948v02", document: "d4"),
            note(2, "Nothing filed", volume: "frus1961-63v06", document: "d42"),
            note(3, "An éclair in Paris", projects: [p2]),
        ], projects: [], tags: [])
        func ids(_ rows: [Snapshot.Row]) -> [UUID] { rows.map(\.id) }
        #expect(ids(snapshot.filtered()) == [id(1), id(2), id(3)])
        #expect(ids(snapshot.filtered(project: .unfiled)) == [id(2)])
        #expect(ids(snapshot.filtered(project: .id(p2))) == [id(3)])
        #expect(ids(snapshot.filtered(tagId: t1)) == [id(1)])
        #expect(ids(snapshot.filtered(project: .id(p2), tagId: t1)).isEmpty)
        #expect(ids(snapshot.filtered(query: " \tBERLIN  ")) == [id(1)])
        #expect(ids(snapshot.filtered(query: "1961-63")) == [id(2)])
        #expect(ids(snapshot.filtered(query: "D42")) == [id(2)])
        #expect(ids(snapshot.filtered(query: "e\u{301}clair")) == [id(3)])
        #expect(ids(snapshot.filtered(query: "   ")) == [id(1), id(2), id(3)])
        #expect(ids(snapshot.filtered(project: .id(p1), query: "cables")) == [id(1)])
    }

    @Test("The count line: of every note, when the filters show fewer")
    func countLine() {
        #expect(Snapshot.noteCount(1) == "1 note")
        #expect(Snapshot.showingCount(shown: 5, of: 312) == "Showing 5 of 312 notes")
        #expect(Snapshot.showingCount(shown: 3, of: 3) == "3 notes")
    }
}
