// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - BrowseScopeTests

/// Pure-logic tests for the custom-scopes browse axis (#1051 B-3, A-5): the Q-3
/// live-reference filter states (never a silent whole-corpus fallback — the #258 rule),
/// the hierarchy restriction, the R-1 drill spec, and the membership mutations whose
/// no-op and reassignment contracts the 3b menu relies on.
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
///   1.1 — #1364: the corpus root's Subseries tile caption under each filter state, Browse Within
///          This Scope's action (narrow, then open the list it narrows), and a source scan that
///          only the iOS mount offers it
@MainActor
struct BrowseScopeTests {

    // MARK: Fixtures

    private func scope(name: String = "Cold War Berlin",
                       volumeIds: [String] = []) -> CustomVolumeScope {
        CustomVolumeScope(name: name, volumeIds: volumeIds)
    }

    private func entry(id: String, subseries: String = "1969-76") -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: subseries,
            title: "Fixture \(id)",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2000", status: .published,
            editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: []
        )
    }

    // MARK: Filter states

    @Test func nilFilterIdIsInactive() {
        #expect(ScopeAxis.filterState(filterId: nil, scopes: [scope()], manifestIds: ["a"])
                == .inactive)
    }

    @Test func danglingIdIsUnavailable_neverWholeCorpus() {
        // A scope deleted on another device: the state is EXPLICIT, and the hierarchy
        // helpers below turn it into nothing — not into an unfiltered corpus under the
        // scope's name.
        let state = ScopeAxis.filterState(filterId: UUID(), scopes: [scope()], manifestIds: ["a"])
        #expect(state == .unavailable)
        #expect(ScopeAxis.scopedGroups([SubseriesGroup(subseries: "1969-76",
                                                       volumes: [entry(id: "a")])],
                                       state: state).isEmpty)
    }

    @Test func activeStateIntersectsMembershipWithTheManifest() {
        let s = scope(volumeIds: ["frus-a", "frus-ghost"])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s],
                                          manifestIds: ["frus-a", "frus-b"])
        #expect(state == .active(name: "Cold War Berlin", allowed: ["frus-a"]))
    }

    @Test func emptyMembershipIsItsOwnExplicitState() {
        let s = scope(volumeIds: [])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s], manifestIds: ["frus-a"])
        #expect(state == .empty(name: "Cold War Berlin"))
    }

    @Test func membershipOfOnlyUnresolvableIdsIsEmptyToo() {
        let s = scope(volumeIds: ["frus-ghost"])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s], manifestIds: ["frus-a"])
        #expect(state == .empty(name: "Cold War Berlin"))
    }

    // MARK: Hierarchy restriction

    @Test func scopedGroupsRestrictAndDropEmptied() {
        let groups = [
            SubseriesGroup(subseries: "1969-76", volumes: [entry(id: "frus-a"), entry(id: "frus-b")]),
            SubseriesGroup(subseries: "1861", volumes: [entry(id: "frus-c")]),
        ]
        let scoped = ScopeAxis.scopedGroups(groups,
                                            state: .active(name: "x", allowed: ["frus-b"]))
        #expect(scoped.count == 1)
        #expect(scoped[0].subseries == "1969-76")
        #expect(scoped[0].volumes.map(\.volumeId) == ["frus-b"])
    }

    @Test func inactiveStatePassesGroupsThrough() {
        let groups = [SubseriesGroup(subseries: "1861", volumes: [entry(id: "frus-c")])]
        #expect(ScopeAxis.scopedGroups(groups, state: .inactive).count == 1)
        #expect(ScopeAxis.scopedVolumes([entry(id: "frus-c")], state: .inactive).count == 1)
    }

    @Test func emptyAndUnavailableFilterToNothing() {
        let volumes = [entry(id: "frus-a")]
        #expect(ScopeAxis.scopedVolumes(volumes, state: .empty(name: "x")).isEmpty)
        #expect(ScopeAxis.scopedVolumes(volumes, state: .unavailable).isEmpty)
    }

    // MARK: The drill spec

    @Test func specResolvesInScopeOrderAndDisclosesTheUnresolvable() throws {
        let s = scope(volumeIds: ["frus-b", "frus-a", "frus-ghost"])
        // CustomVolumeScope sorts membership on init, so the scope's own order is sorted;
        // the spec must keep IT (frus-a, frus-b, frus-ghost minus the ghost).
        let spec = ScopeAxis.spec(for: s, manifestIds: ["frus-a", "frus-b"])
        #expect(spec.volumeIds == ["frus-a", "frus-b"])
        #expect(spec.axisKey == "scope:\(s.id.uuidString)")
        let caption = try #require(spec.caption)
        #expect(caption.contains("2 volumes"))
        #expect(caption.contains("catalogue: 1"))
    }

    @Test func untitledScopesGetThePlaceholderName() {
        let s = scope(name: "", volumeIds: ["frus-a"])
        let name = ScopeAxis.displayName(s)
        #expect(!name.isEmpty)
        #expect(ScopeAxis.spec(for: s, manifestIds: ["frus-a"]).title == name)
    }

    // MARK: Membership mutation (the 3b contracts)

    @Test func addIsSortedReassignmentAndTouchesLastModified() {
        let s = scope(volumeIds: ["frus-b"])
        #expect(ScopeAxis.add("frus-a", to: s))
        #expect(s.volumeIds == ["frus-a", "frus-b"])
        #expect(s.lastModified != nil)
    }

    @Test func addingAnExistingMemberIsANoOp_lastModifiedUntouched() {
        let s = scope(volumeIds: ["frus-a"])
        let before = s.lastModified
        #expect(!ScopeAxis.add("frus-a", to: s))
        #expect(s.volumeIds == ["frus-a"])
        #expect(s.lastModified == before)
    }

    @Test func removeFiltersAndNoOpsForNonMembers() {
        let s = scope(volumeIds: ["frus-a", "frus-b"])
        #expect(ScopeAxis.remove("frus-a", from: s))
        #expect(s.volumeIds == ["frus-b"])
        #expect(!ScopeAxis.remove("frus-ghost", from: s))
        #expect(s.volumeIds == ["frus-b"])
    }

    // MARK: Persistence (the #862 class, at unit grain)

    @Test func createInsertsIntoTheContextAndSurvivesAFetch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CustomVolumeScope.self, configurations: config)
        let context = ModelContext(container)
        let created = ScopeAxis.create(named: "Captured", volumeIds: ["frus-a"], in: context)
        // The #862 lesson at this grain: the model must BELONG to a context after create —
        // a save that had nothing to write is how work vanishes silently.
        #expect(created.modelContext != nil)
        let fetched = try context.fetch(FetchDescriptor<CustomVolumeScope>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Captured")
        #expect(fetched.first?.volumeIds == ["frus-a"])
    }

    // MARK: The corpus root's Subseries tile (#1364)

    /// Four volumes over three eras, 1861–1969; `frus-b` and `frus-c` alone span 1917–1969, so a
    /// caption that counted or spanned the whole list under a filter cannot pass for the scope's.
    private var tileVolumes: [VolumeManifestEntry] {
        [entry(id: "frus-a", subseries: "1861"),
         entry(id: "frus-b", subseries: "1917"),
         entry(id: "frus-c", subseries: "1969-76"),
         entry(id: "frus-d", subseries: "1969-76")]
    }

    @Test func tileCaptionCountsTheWholeSeriesWhenNothingNarrowsIt() {
        #expect(ScopeAxis.subseriesTileCaption(volumes: tileVolumes, state: .inactive)
                == "4 volumes by era, 1861–1969")
    }

    @Test func tileCaptionForOneEraHasNoSpan() {
        let oneEra = [entry(id: "frus-c"), entry(id: "frus-d")]
        #expect(ScopeAxis.subseriesTileCaption(volumes: oneEra, state: .inactive)
                == "2 volumes by era")
    }

    @Test func tileCaptionNamesTheScopeAndCountsAndSpansOnlyItsVolumes() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-b", "frus-c"]))
        #expect(caption == "Browsing within: Cold War Berlin · 2 volumes by era, 1917–1969")
    }

    @Test func tileCaptionForAOneEraScopeHasNoSpan() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-c", "frus-d"]))
        #expect(caption == "Browsing within: Cold War Berlin · 2 volumes by era")
    }

    @Test func tileCaptionForAOneVolumeScopeIsSingular() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-c"]))
        #expect(caption == "Browsing within: Cold War Berlin · 1 volume")
    }

    @Test func tileCaptionForAnEmptyScopeSaysItHasNothingToShow() {
        // The list below shows nothing; the tile must not count the series over it (#258).
        let caption = ScopeAxis.subseriesTileCaption(volumes: tileVolumes,
                                                     state: .empty(name: "Cold War Berlin"))
        #expect(caption == "Browsing within: Cold War Berlin · no volumes this device’s catalogue can show")
        #expect(!caption.contains("4 volumes"))
    }

    @Test func tileCaptionForAVanishedScopeNeverCountsTheSeries() {
        // A scope deleted on another device: the list is explicitly empty, so a whole-series
        // count here would be the #258 inversion moved to the root.
        let caption = ScopeAxis.subseriesTileCaption(volumes: tileVolumes, state: .unavailable)
        #expect(caption == "Browsing within a scope that is no longer available")
        #expect(!caption.contains("4 volumes"))
    }

    // MARK: Browse Within This Scope (#1364)

    /// Every `ScopeIndexView(` call in the app's sources, each read through its balanced
    /// parentheses, with the file it is in.
    private static func scopeIndexViewCalls() throws -> [(file: String, call: String)] {
        let appSources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
        let files = try #require(FileManager.default.enumerator(at: appSources,
                                                                includingPropertiesForKeys: nil))
        var calls: [(file: String, call: String)] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = Array(try String(contentsOf: url, encoding: .utf8))
            let needle = Array("ScopeIndexView(")
            var i = 0
            while i + needle.count <= text.count {
                guard Array(text[i..<(i + needle.count)]) == needle else { i += 1; continue }
                var depth = 0, end = i + needle.count - 1
                while end < text.count {
                    if text[end] == "(" { depth += 1 }
                    if text[end] == ")" { depth -= 1; if depth == 0 { break } }
                    end += 1
                }
                calls.append((url.lastPathComponent, String(text[i...min(end, text.count - 1)])))
                i = end + 1
            }
        }
        return calls
    }

    /// Only the iOS Browse mount offers Browse Within This Scope. The Mac corpus browser has no
    /// filter surface and no view there reads the filter, so the Mac manual says the item is iOS
    /// only; an `onBrowseWithin:` on the Mac mount would put an item there that narrows nothing.
    @Test func onlyTheIOSMountOffersBrowseWithin() throws {
        let calls = try Self.scopeIndexViewCalls()
        // Both mounts must be read, or "the Mac passes none" holds over nothing.
        #expect(calls.map(\.file).sorted() == ["MacCorpusBrowserWindow.swift", "ScopeBrowseView.swift"],
                "the scan found \(calls.map(\.file))")
        let offering = calls.filter { $0.call.contains("onBrowseWithin:") }.map(\.file)
        #expect(offering == ["ScopeBrowseView.swift"], """
            Browse Within This Scope is offered by \(offering) — it belongs to the iOS Browse mount \
            alone (#1364)
            """)
    }

    #if os(iOS)
    /// The action the iOS My Scopes level hands its menu: narrow Browse, then open the subseries
    /// list — the level the banner is on — replacing the path, as the root's own tile does.
    @Test func browseWithinNarrowsAndOpensTheSubseriesList() {
        let appState = AppState()
        // `browseScopeFilterId` writes UserDefaults, and this runs inside the app host.
        let before = appState.browseScopeFilterId
        defer { appState.browseScopeFilterId = before }
        let vm = BrowserViewModel(manifestStore: ManifestStore(bundledEntries: []),
                                  tagStore: VolumeLevelTagStore(),
                                  downloadManager: nil, indexingPipeline: nil)
        vm.navigationPath = [.scopes]
        let scopeId = UUID()

        BrowseScopesLevel.browseWithin(scopeId, vm: vm, appState: appState)

        #expect(appState.browseScopeFilterId == scopeId)
        #expect(vm.navigationPath == [.subseriesIndex],
                "the reader must land on the list the banner is on; path \(vm.navigationPath)")
    }
    #endif
}
