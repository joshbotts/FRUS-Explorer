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
}
