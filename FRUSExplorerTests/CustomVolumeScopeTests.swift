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

// MARK: - ScopeFacets (#258 Phase 4)

/// Tests for the pure facet→volume-set helpers behind the scope editor's rich facets.
/// All fixtures are memberwise-constructed — no bundle, no store, no container.
struct ScopeFacetsTests {

    /// A minimal manifest entry for facet fixtures.
    private func entry(_ id: String, subseries: String = "s", tags: [String] = [],
                       earliest: String? = nil, latest: String? = nil,
                       editors: [String] = []) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: subseries, title: "T\(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: nil, status: .published, editors: editors, generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: tags
        )
    }

    // MARK: Coverage facet

    @Test("Coverage intersection: overlap in, disjoint out, missing dates excluded")
    func coverageIntersection() {
        let entries = [
            entry("in-overlap",  earliest: "1960-01-01", latest: "1965-12-31"),
            entry("in-contained", earliest: "1962-01-01", latest: "1963-01-01"),
            entry("in-spanning", earliest: "1950-01-01", latest: "1980-01-01"),
            entry("out-before",  earliest: "1940-01-01", latest: "1959-12-31"),
            entry("out-after",   earliest: "1969-01-01", latest: "1975-01-01"),
            entry("no-dates"),
        ]
        let ids = ScopeFacets.volumeIds(coverageIntersecting: 1961, toYear: 1968,
                                        entries: entries)
        #expect(ids == ["in-overlap", "in-contained", "in-spanning"])
    }

    @Test("Coverage boundary years are inclusive")
    func coverageBoundaries() {
        let entries = [
            entry("ends-at-from",   earliest: "1950-01-01", latest: "1961-06-01"),
            entry("starts-at-to",   earliest: "1968-11-01", latest: "1970-01-01"),
        ]
        #expect(ScopeFacets.volumeIds(coverageIntersecting: 1961, toYear: 1968,
                                      entries: entries)
                == ["ends-at-from", "starts-at-to"])
    }

    @Test("Single-dated coverage falls back to the present endpoint")
    func coverageSingleEndpoint() {
        let entries = [
            entry("only-earliest-in",  earliest: "1965-01-01", latest: nil),
            entry("only-latest-out",   earliest: nil, latest: "1950-01-01"),
        ]
        #expect(ScopeFacets.volumeIds(coverageIntersecting: 1961, toYear: 1968,
                                      entries: entries)
                == ["only-earliest-in"])
    }

    @Test("Editor filter folds case and diacritics")
    func coverageEditorFilter() {
        let entries = [
            entry("match",   earliest: "1962-01-01", latest: "1963-01-01",
                  editors: ["Adrián Sánchez"]),
            entry("nomatch", earliest: "1962-01-01", latest: "1963-01-01",
                  editors: ["Louis J. Smith"]),
        ]
        #expect(ScopeFacets.volumeIds(coverageIntersecting: 1960, toYear: 1965,
                                      editorContains: "adrian sanchez",
                                      entries: entries)
                == ["match"])
    }

    @Test("ISO year parsing: 4-digit prefix or nil")
    func yearParsing() {
        #expect(ScopeFacets.year(from: "1961-05-06") == 1961)
        #expect(ScopeFacets.year(from: "1961") == 1961)
        #expect(ScopeFacets.year(from: "19") == nil)
        #expect(ScopeFacets.year(from: nil) == nil)
    }

    // MARK: Tag facet

    @Test("Tag catalog counts and orders by reach; taggedWith matches exactly")
    func tagFacet() {
        let entries = [
            entry("a", tags: ["cold-war", "asia"]),
            entry("b", tags: ["cold-war"]),
            entry("c", tags: ["asia", "cold-war"]),
            entry("d", tags: []),
        ]
        let catalog = ScopeFacets.tagCatalog(entries)
        #expect(catalog.map(\.slug) == ["cold-war", "asia"])
        #expect(catalog.first?.volumeCount == 3)
        #expect(ScopeFacets.volumeIds(taggedWith: "asia", entries: entries) == ["a", "c"])
        #expect(ScopeFacets.volumeIds(taggedWith: "absent", entries: entries).isEmpty)
    }

    // MARK: Subject facet

    @Test("Subject catalog derives names once and counts reach from the reverse index")
    func subjectFacet() {
        let vietnamization = VolumeSubjectProfiles.ResolvedSubject(
            ref: "s1", name: "Vietnamization", category: "Warfare",
            subcategory: "Strategy", score: 0.9)
        let detente = VolumeSubjectProfiles.ResolvedSubject(
            ref: "s2", name: "Détente", category: "Diplomacy",
            subcategory: "East-West", score: 0.8)
        let resolvedByVolume = [
            "v1": [vietnamization, detente],
            "v2": [vietnamization],
        ]
        let reverse = ["s1": ["v1", "v2"], "s2": ["v1"]]

        let catalog = ScopeFacets.subjectCatalog(resolvedByVolume: resolvedByVolume,
                                                 volumesBySubjectRef: reverse)
        #expect(catalog.map(\.ref) == ["s1", "s2"])
        #expect(catalog.first?.name == "Vietnamization")
        #expect(catalog.first?.subcategory == "Strategy")
        #expect(catalog.first?.volumeCount == 2)
        #expect(ScopeFacets.volumeIds(forSubjectRef: "s2", volumesBySubjectRef: reverse)
                == ["v1"])
    }

    // MARK: Category / sub-category facets (#308 Phase 1)

    /// A `ResolvedSubject` fixture.
    private func rs(_ ref: String, _ name: String, _ cat: String, _ sub: String)
        -> VolumeSubjectProfiles.ResolvedSubject {
        VolumeSubjectProfiles.ResolvedSubject(ref: ref, name: name, category: cat,
                                              subcategory: sub, score: 0.5)
    }

    @Test("Category catalog counts distinct volume reach; forCategory resolves the volume set")
    func categoryFacet() {
        let byVol = [
            "v1": [rs("w1", "Vietnamization", "Warfare", "Vietnam Conflict"),
                   rs("e1", "Export control", "Foreign Economic Policy", "Trade")],
            "v2": [rs("w2", "Deterrence", "Warfare", "Strategy")],
            "v3": [rs("e1", "Export control", "Foreign Economic Policy", "Trade")],
        ]
        let cats = ScopeFacets.categoryCatalog(resolvedByVolume: byVol)
        // Warfare = {v1,v2} = 2; Foreign Economic Policy = {v1,v3} = 2 — tie broken by label.
        #expect(cats.map(\.label) == ["Foreign Economic Policy", "Warfare"])
        #expect(cats.first(where: { $0.label == "Warfare" })?.volumeCount == 2)
        #expect(ScopeFacets.volumeIds(forCategory: "Warfare", resolvedByVolume: byVol)
                == ["v1", "v2"])
    }

    @Test("Sub-category catalog folds out General; category still covers General volumes")
    func subCategoryFacetFoldsGeneral() {
        let byVol = [
            "v1": [rs("a1", "Vietnamization", "Warfare", "Vietnam Conflict")],
            "v2": [rs("g1", "Misc War", "Warfare", "General")],
            "v3": [rs("b1", "Deterrence", "Warfare", "Strategy")],
            "v4": [rs("a1", "Vietnamization", "Warfare", "Vietnam Conflict"),
                   rs("b1", "Deterrence", "Warfare", "Strategy")],
        ]
        let subs = ScopeFacets.subCategoryCatalog(forCategory: "Warfare", resolvedByVolume: byVol)
        // "General" is folded out of the drill-down.
        #expect(subs.allSatisfy { $0.subcategory != ScopeFacets.generalSubcategory })
        #expect(Set(subs.map(\.subcategory)) == ["Vietnam Conflict", "Strategy"])
        // …but the General-only volume is still reachable via the category.
        #expect(ScopeFacets.volumeIds(forCategory: "Warfare", resolvedByVolume: byVol)
                == ["v1", "v2", "v3", "v4"])
        // Pair resolution is exact.
        #expect(ScopeFacets.volumeIds(forCategory: "Warfare", subcategory: "Vietnam Conflict",
                                      resolvedByVolume: byVol) == ["v1", "v4"])
        // The complete resolver can still resolve General even though the catalog hides it.
        #expect(ScopeFacets.volumeIds(forCategory: "Warfare", subcategory: "General",
                                      resolvedByVolume: byVol) == ["v2"])
    }
}

