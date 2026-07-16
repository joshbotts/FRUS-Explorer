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

/// Tests for #258 Phase 1 — centred on the feature's load-bearing invariant:
/// **no FTS surface may ever receive a bare empty set from a custom scope.**
///
/// The #327 review found (two lenses, independently) that every pre-existing scope
/// consumer maps an empty/nil set to "no filter" — so an empty-after-intersection
/// custom scope would silently invert into a whole-corpus query under the scope's own
/// label. `IndexedResolution` exists to make that unrepresentable; these tests pin it.
struct CustomVolumeScopeTests {

    // MARK: - The invariant (pure functions, no container needed)

    @Test("Members intersected with the indexed set resolve non-empty")
    func resolvesIndexedMembers() {
        let r = CustomScopeResolver.indexedResolution(
            memberVolumeIds: ["frus1961-63v06", "frus1969-76v01", "frus1950v03"],
            indexed: ["frus1961-63v06", "frus1969-76v01"])
        #expect(r == .resolved(["frus1961-63v06", "frus1969-76v01"]))
    }

    /// The inversion case the review found: a scope whose members are all un-downloaded
    /// must yield the EXPLICIT outcome — never an empty set a consumer would read as
    /// "no filter".
    @Test("A scope with no indexed members yields .noIndexedMembers, never an empty set")
    func emptyIntersectionIsExplicit() {
        let r = CustomScopeResolver.indexedResolution(
            memberVolumeIds: ["frus1950v03", "frus1952-54v08"],
            indexed: ["frus1969-76v01"])
        #expect(r == .noIndexedMembers)
        if case .resolved(let ids) = r {
            #expect(!ids.isEmpty, "resolved must be non-empty by construction")
        }
    }

    @Test("An empty scope yields .noIndexedMembers")
    func emptyMembershipIsExplicit() {
        #expect(CustomScopeResolver.indexedResolution(memberVolumeIds: [], indexed: ["x"])
                == .noIndexedMembers)
    }

    @Test("Manifest-grain resolution keeps un-indexed members but drops dangling ids")
    func manifestGrainFiltersDangling() {
        let ids = CustomScopeResolver.manifestVolumeIds(
            memberVolumeIds: ["frus1950v03", "frus9999v99-dangling"],
            manifestIds: ["frus1950v03", "frus1969-76v01"])
        #expect(ids == ["frus1950v03"])
    }

    // MARK: - Identity resolution + the deletion story (needs a container)

    /// In-memory, CloudKit-disabled container per the repo's test rules: keep the
    /// container alive (the context does not retain it) and pass `.none`, or the
    /// entitled host spins up real sync and traps.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: CustomVolumeScope.self, configurations: config)
    }

    @Test("Resolving a stored scope id round-trips through the invariant")
    @MainActor
    func resolvesByIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let scope = CustomVolumeScope(name: "Vietnam", volumeIds: ["v1", "v2"])
        context.insert(scope)
        try context.save()

        #expect(CustomScopeResolver.resolve(scopeId: scope.id, context: context,
                                            indexed: ["v2", "v9"])
                == .resolved(["v2"]))
        #expect(CustomScopeResolver.resolve(scopeId: scope.id, context: context,
                                            indexed: ["v9"])
                == .noIndexedMembers)
    }

    /// The deletion story (sketch §8): a dangling scope reference resolves to the
    /// explicit `.scopeUnavailable` — never to an unscoped query.
    @Test("A dangling scope id yields .scopeUnavailable")
    @MainActor
    func danglingIdIsExplicit() throws {
        let container = try makeContainer()
        #expect(CustomScopeResolver.resolve(scopeId: UUID(),
                                            context: container.mainContext,
                                            indexed: ["v1"])
                == .scopeUnavailable)
    }

    // MARK: - Model hygiene

    @Test("Membership is deduplicated and sorted on init")
    @MainActor
    func initDedupesAndSorts() throws {
        let container = try makeContainer()
        let scope = CustomVolumeScope(name: "S", volumeIds: ["b", "a", "b", "c", "a"])
        container.mainContext.insert(scope)
        #expect(scope.volumeIds == ["a", "b", "c"])
    }
}
