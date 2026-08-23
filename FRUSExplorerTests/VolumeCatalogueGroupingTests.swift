// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - VolumeCatalogueGroupingTests

/// Pure-logic tests for the All Volumes catalogue (#1051 B-1): the distinctive-title
/// extraction that makes an A–Z filing usable at all (409 of 552 titles share one
/// boilerplate prefix), the four sort modes' ordering contracts, and the year parse that
/// must survive the manifest's one full-ISO `publicationDate` among 551 bare years.
///
/// Also pins the B-1 foundations that live beside the catalogue: the R-2 accessor against
/// the real bundled artifact, `VolumeListSpec`'s axis-key identity, and the Q-5
/// pop-vs-push decision helper.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
@MainActor
struct VolumeCatalogueGroupingTests {

    // MARK: Fixtures

    /// A minimal entry; only the fields a given test reads are meaningful.
    private func entry(
        id: String,
        title: String = "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
        subseries: String = "1969-76",
        publicationDate: String? = "2003"
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id,
            filename: "\(id).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: publicationDate,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: []
        )
    }

    /// A count table the length tests read through.
    private func counts(_ table: [String: Int]) -> @MainActor (String) -> Int? {
        { table[$0] }
    }

    // MARK: Distinctive title keys

    @Test func modernVolumeFormYieldsSubjectSegment() {
        #expect(VolumeCatalogueGrouping.distinctiveTitleKey(
            "Foreign Relations of the United States, 1969–1976, Volume XVII, China, 1969–1972"
        ) == "China, 1969–1972")
    }

    @Test func trailingVolumeDesignatorIsDropped() {
        // The pre-war form puts the subject BEFORE the volume number.
        #expect(VolumeCatalogueGrouping.distinctiveTitleKey(
            "Foreign Relations of the United States, 1949, The Far East: China, Volume IX"
        ) == "The Far East: China")
    }

    @Test func partDesignatorIsSkipped() {
        #expect(VolumeCatalogueGrouping.distinctiveTitleKey(
            "Foreign Relations of the United States, 1952–1954, Volume XIV, Part 1, China and Japan"
        ) == "China and Japan")
    }

    @Test func earlyAnnualKeepsItsYearAndFilesUnderHash() {
        // "Papers Relating…" contains the shorter boilerplate as a substring — the longer
        // prefix must strip first, and a year that is the WHOLE remainder must survive.
        let key = VolumeCatalogueGrouping.distinctiveTitleKey(
            "Papers Relating to the Foreign Relations of the United States, 1894"
        )
        #expect(key == "1894")
        #expect(VolumeCatalogueGrouping.titleBucket(forKey: key) == "#")
    }

    @Test func unrecognizedTitleFallsBackToItself() {
        #expect(VolumeCatalogueGrouping.distinctiveTitleKey("My Sideloaded Volume")
                == "My Sideloaded Volume")
    }

    @Test func letterBucketUppercases() {
        #expect(VolumeCatalogueGrouping.titleBucket(forKey: "china, 1969") == "C")
    }

    // MARK: Publication year parse

    @Test func bareYearAndFullISOParseIdentically() {
        // The manifest holds 551 bare "YYYY" strings and exactly ONE full ISO date —
        // string sort would misfile it; `firstYear(in:)` must not.
        #expect(VolumeCatalogueGrouping.publicationYear(of: entry(id: "a", publicationDate: "1987")) == 1987)
        #expect(VolumeCatalogueGrouping.publicationYear(of: entry(id: "b", publicationDate: "2010-11-05")) == 2010)
        #expect(VolumeCatalogueGrouping.publicationYear(of: entry(id: "c", publicationDate: nil)) == nil)
    }

    // MARK: Published mode

    @Test func publishedModeSectionsByDecadeDescending_yearBeatsVolumeId() {
        // Fixture ids ASCEND with year, so an id-driven sort would produce the OPPOSITE
        // order — only the year rule yields newest-first.
        let entries = [
            entry(id: "frus-a", publicationDate: "1987"),
            entry(id: "frus-b", publicationDate: "2010-11-05"),
            entry(id: "frus-c", publicationDate: "2023"),
        ]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .published, query: "", documentCount: counts([:]))
        #expect(sections.map(\.title) == ["2020s", "2010s", "1980s"])
        #expect(sections.flatMap(\.entries).map(\.volumeId) == ["frus-c", "frus-b", "frus-a"])
    }

    @Test func publishedModeTieBreaksByVolumeId_yearsEqualSoOnlyIdDecides() {
        let entries = [
            entry(id: "frus-z", publicationDate: "1999"),
            entry(id: "frus-a", publicationDate: "1999"),
        ]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .published, query: "", documentCount: counts([:]))
        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.volumeId) == ["frus-a", "frus-z"])
    }

    @Test func publishedModeUndatedLandsInTrailingSection() {
        let entries = [
            entry(id: "frus-b", publicationDate: nil),
            entry(id: "frus-a", publicationDate: "2001"),
        ]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .published, query: "", documentCount: counts([:]))
        #expect(sections.count == 2)
        #expect(sections.last?.entries.map(\.volumeId) == ["frus-b"])
        #expect(sections.last?.title != nil)
    }

    // MARK: Title mode

    @Test func titleModeFilesByDistinctiveKeyWithHashLast() {
        // Under a FULL-title sort every fixture would file under "F"/"P" — the buckets
        // prove the distinctive key drives, and "#" sorts after the letters.
        let entries = [
            entry(id: "frus-1", title: "Foreign Relations of the United States, 1969–1976, Volume XVII, China, 1969–1972"),
            entry(id: "frus-2", title: "Papers Relating to the Foreign Relations of the United States, 1894"),
            entry(id: "frus-3", title: "Foreign Relations of the United States, 1969–1976, Volume XXXVII, Energy Crisis, 1974–1980"),
        ]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .title, query: "", documentCount: counts([:]))
        #expect(sections.map(\.title) == ["C", "E", "#"])
    }

    // MARK: Era mode

    @Test func eraModeGroupsBySubseriesNewestFirst() {
        let entries = [
            entry(id: "frus1861", subseries: "1861"),
            entry(id: "frus1969-76v01", subseries: "1969-76"),
            entry(id: "frus1914", subseries: "1914"),
        ]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .era, query: "", documentCount: counts([:]))
        #expect(sections.map(\.title) == ["1969-76", "1914", "1861"])
    }

    // MARK: Length mode

    @Test func lengthModeSortsByCountDescending_idOrderWouldInvert() {
        // Ids ASCEND against count, so an id sort gives the opposite order — only the
        // count rule yields largest-first.
        let entries = [entry(id: "frus-a"), entry(id: "frus-b"), entry(id: "frus-c")]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "",
            documentCount: counts(["frus-a": 10, "frus-b": 500, "frus-c": 900]))
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].entries.map(\.volumeId) == ["frus-c", "frus-b", "frus-a"])
    }

    @Test func lengthModeTieBreaksByVolumeId_countsEqualSoOnlyIdDecides() {
        let entries = [entry(id: "frus-z"), entry(id: "frus-a")]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "",
            documentCount: counts(["frus-z": 100, "frus-a": 100]))
        #expect(sections[0].entries.map(\.volumeId) == ["frus-a", "frus-z"])
    }

    @Test func lengthModeUnknownCountsSinkToEnd() {
        let entries = [entry(id: "frus-a"), entry(id: "frus-b")]
        let sections = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "",
            documentCount: counts(["frus-b": 5]))
        #expect(sections[0].entries.map(\.volumeId) == ["frus-b", "frus-a"])
    }

    // MARK: Query

    @Test func queryMatchesTitleAndVolumeId() {
        let entries = [
            entry(id: "frus1969-76v17", title: "Foreign Relations of the United States, 1969–1976, Volume XVII, China, 1969–1972"),
            entry(id: "frus1861", title: "Papers Relating to the Foreign Relations of the United States, 1861"),
        ]
        let byTitle = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "china", documentCount: counts([:]))
        #expect(byTitle.flatMap(\.entries).map(\.volumeId) == ["frus1969-76v17"])
        let byId = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "1861", documentCount: counts([:]))
        #expect(byId.flatMap(\.entries).map(\.volumeId) == ["frus1861"])
        let none = VolumeCatalogueGrouping.sections(
            entries: entries, mode: .length, query: "zzz", documentCount: counts([:]))
        #expect(none.isEmpty)
    }
}

// MARK: - VolumeDocumentCountAccessorTests

/// Pins the R-2 accessor against the REAL bundled artifact, so the number Browse shows is
/// the number the artifact states — 314,483 document divs over 552 volumes, the figure the
/// semantic pipeline counts independently.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
@MainActor
struct VolumeDocumentCountAccessorTests {

    @Test func bundledTotalsSumToTheCorpusDocumentCount() throws {
        let store = AdministrationProfilesStore()
        let index = try #require(store.index, "bundled administration-profiles-index.json must decode")
        let sum = index.volumeTotals.keys.reduce(0) { $0 + (store.documentCount(forVolumeId: $1) ?? 0) }
        #expect(sum == 314_483)
        #expect(index.volumeTotals.count == 552)
    }

    @Test func knownVolumeAndUnknownVolume() {
        let store = AdministrationProfilesStore()
        // frus1861 = 310 point + 2 range + 0 undated — verified against the raw TEI.
        #expect(store.documentCount(forVolumeId: "frus1861") == 312)
        #expect(store.documentCount(forVolumeId: "not-a-volume") == nil)
    }

    @Test func nilIndexYieldsNilNeverZero() {
        let store = AdministrationProfilesStore(index: nil)
        #expect(store.documentCount(forVolumeId: "frus1861") == nil)
    }
}

// MARK: - VolumeListSpecTests

/// The R-1 identity contract: a `volumeList` level is its AXIS, never its id array — a
/// recomputed member set under the same key must compare equal, or breadcrumb truncation
/// and path equality break on incidental recomputation.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
struct VolumeListSpecTests {

    @Test func identityIsTheAxisKeyNotTheIdArray() {
        let a = VolumeListSpec(axisKey: "administration:truman", title: "Truman",
                               volumeIds: ["frus1945v01", "frus1947v01"])
        let b = VolumeListSpec(axisKey: "administration:truman", title: "Truman (recomputed)",
                               volumeIds: ["frus1947v01"])
        let c = VolumeListSpec(axisKey: "administration:eisenhower", title: "Eisenhower",
                               volumeIds: ["frus1947v01"])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }

    @MainActor
    @Test func browserLevelEqualityFollowsTheSpec() {
        let a = BrowserViewModel.BrowserLevel.volumeList(
            VolumeListSpec(axisKey: "k", title: "A", volumeIds: ["x"]))
        let b = BrowserViewModel.BrowserLevel.volumeList(
            VolumeListSpec(axisKey: "k", title: "B", volumeIds: ["y", "z"]))
        #expect(a == b)
    }
}

// MARK: - TagFilterNavigationTests

/// The Q-5 pop-vs-push decision (#1051 B-1): with a `.subseries` ancestor on the path the
/// tag filter pops back to it; without one (the axis-list route to a volume) the caller
/// pushes the subseries level instead of silently setting latent state.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
@MainActor
struct TagFilterNavigationTests {

    private func group(_ subseries: String) -> SubseriesGroup {
        SubseriesGroup(subseries: subseries, volumes: [])
    }

    @Test func ancestorFoundYieldsItsIndex() {
        let path: [BrowserViewModel.BrowserLevel] = [.subseriesIndex, .subseries(group("1969-76"))]
        #expect(BrowserViewModel.subseriesAncestorIndex(in: path, subseries: "1969-76") == 1)
    }

    @Test func wrongSubseriesIsNotAnAncestor() {
        let path: [BrowserViewModel.BrowserLevel] = [.subseries(group("1861"))]
        #expect(BrowserViewModel.subseriesAncestorIndex(in: path, subseries: "1969-76") == nil)
    }

    @Test func axisListPathHasNoAncestor_theQ5PushCase() {
        // The catalogue route: [.catalogue, .volume] — no subseries level anywhere.
        let path: [BrowserViewModel.BrowserLevel] = [.catalogue]
        #expect(BrowserViewModel.subseriesAncestorIndex(in: path, subseries: "1969-76") == nil)
    }
}

// MARK: - CorpusRootHelpersTests

/// The 2a root's small pure helpers. The year scan lives on `VolumeCatalogueGrouping`, not
/// `CorpusView` — a `View`'s statics are MainActor-isolated, and the first draft of this
/// suite crashed at runtime calling one from this nonisolated context (the
/// move-the-rule-don't-annotate lesson, verified again here).
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
struct CorpusRootHelpersTests {

    @Test func fourDigitRunsFindEveryYearForm() {
        #expect(VolumeCatalogueGrouping.fourDigitRuns(in: "1969-76") == [1969])
        #expect(VolumeCatalogueGrouping.fourDigitRuns(in: "1981–1988") == [1981, 1988])
        #expect(VolumeCatalogueGrouping.fourDigitRuns(in: "1861") == [1861])
        #expect(VolumeCatalogueGrouping.fourDigitRuns(in: "no years") == [])
    }
}
