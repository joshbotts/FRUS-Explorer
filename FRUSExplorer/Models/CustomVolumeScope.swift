// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - CustomVolumeScope

/// A user-defined, named set of volumes usable as a search/analytics scope (#258).
///
/// Design per the reviewed sketch (`Planning/258-Custom-Volume-Scopes-Design.md`, PR #327):
/// a **flat, all-defaulted record whose membership is a `[String]` of manifest `volumeId`s** —
/// the `Collection.projectIds` value-array pattern. No child `@Model`, no relationship, no
/// non-optional custom enum (the #297 trap). Membership is a **static snapshot** (§8-Q2(a));
/// ids are **raw manifest ids** (§8-Q1(a)) so a scope keeps its meaning as the user downloads
/// more volumes — FTS surfaces intersect with the indexed set at resolution time, via
/// `CustomScopeResolver`, whose `IndexedResolution` contract is this feature's load-bearing
/// invariant.
///
/// ## CloudKit compatibility
/// All properties have default values or are optional (the repo's hard rule — see
/// `SavedSearch`). Enrolled in `frusModelTypes` (**a new CloudKit record type: deploy the
/// schema to Production before shipping**, per the standing note in `ModelContainer+FRUS`)
/// and in `DuplicateRecordCleanup` (`dedupeSimple` — no children to re-parent), because a
/// schema-change import can materialize duplicate records sharing one logical `id`.
///
/// ## Editing rule
/// Replace `volumeIds` **wholesale** on every edit — never mutate the array in place
/// (`Project.swift`'s shipped warning: in-place array mutation has a documented sync hazard).
/// Deduplicate on write; order is not meaningful.
///
/// Version history:
///   1.0 — #258 Phase 1: initial implementation (model + resolver + editor + iOS Search
///          + iOS management pane)
///   1.1 — #258 Phase 4: `ScopeFacets` pure facet→volume-set helpers (subject / manifest
///          tag / coverage+editor); #332 review: subject-catalog name derivation made
///          order-deterministic
@Model final class CustomVolumeScope {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display

    /// User-visible scope name. Not unique — duplicates are allowed and disambiguated by
    /// `id` (uniqueness across CloudKit devices is un-guaranteeable; see the sketch §3).
    var name: String = ""

    // MARK: - Membership

    /// Member volumes as **raw manifest `volumeId`s** (§8-Q1(a)): stable across downloads,
    /// meaningful to both the indexed-corpus and whole-manifest grains. May legitimately
    /// name volumes the user has not downloaded — which is exactly why FTS consumers must
    /// go through `CustomScopeResolver.indexedResolution` and never treat the raw array as
    /// a query filter directly.
    var volumeIds: [String] = []

    // MARK: - Bookkeeping

    /// Creation timestamp; optional for CloudKit schema compatibility. Also the
    /// `DuplicateRecordCleanup` stable-keeper key.
    var createdAt: Date?
    /// Last membership/name edit; optional for CloudKit schema compatibility.
    var lastModified: Date?

    /// Creates a named scope. Membership is deduplicated and sorted on write.
    init(name: String, volumeIds: [String] = []) {
        self.id = UUID()
        self.name = name
        self.volumeIds = Array(Set(volumeIds)).sorted()
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

// MARK: - IndexedResolution

/// The FTS-grain resolution contract (#258, review finding — HIGH, found independently by
/// two lenses): **never a bare, possibly-empty set.**
///
/// Every pre-existing scope consumer in the app treats an empty/`nil` volume set as
/// "no filter" (e.g. `SearchViewModel` maps empty → `nil` → whole corpus) — so a custom
/// scope whose members are not yet downloaded would silently *invert* into a whole-corpus
/// query under the scope's own label. This enum makes that state unrepresentable: an FTS
/// surface either gets a non-empty set, or an explicit outcome it must render as an empty
/// state / warning — never pass through as unscoped.
enum IndexedResolution: Equatable {
    /// The scope resolves to these indexed volumes. Non-empty by construction.
    case resolved(Set<String>)
    /// The scope has members, but none are indexed yet — show "no volumes of this scope
    /// are indexed" (or warn in the picker); NEVER fall back to unscoped.
    case noIndexedMembers
    /// The scope reference did not resolve (deleted on another device; dangling
    /// `.custom(UUID)`) — show "this scope is no longer available"; NEVER unscoped.
    case scopeUnavailable
}

// MARK: - CustomScopeResolver

/// Resolves a `CustomVolumeScope` to a volume-id set at one of the two grains the scope
/// census identified (sketch §2): **indexed** (FTS surfaces — search, analytics) and
/// **manifest** (the Series dashboards, which render undownloaded volumes).
///
/// The grain methods are pure static functions over plain values so the `IndexedResolution`
/// invariant is unit-testable without a SwiftData container.
enum CustomScopeResolver {

    /// FTS-grain resolution: intersect membership with the indexed set, with
    /// empty-after-intersection as an **explicit, non-passthrough outcome**.
    ///
    /// - Parameters:
    ///   - memberVolumeIds: The scope's raw membership (may include un-downloaded ids).
    ///   - indexed: The currently indexed volume ids (`AppState.indexedVolumeIds`).
    /// - Returns: `.resolved` (non-empty) or `.noIndexedMembers`. (`.scopeUnavailable` is
    ///   produced by identity-based lookups — `resolve(scopeId:context:indexed:)` — when
    ///   the referenced record no longer exists.)
    static func indexedResolution(memberVolumeIds: [String],
                                  indexed: Set<String>) -> IndexedResolution {
        let hits = Set(memberVolumeIds).intersection(indexed)
        return hits.isEmpty ? .noIndexedMembers : .resolved(hits)
    }

    /// Series/manifest-grain resolution: raw membership filtered to ids the current
    /// manifest actually knows, so a dangling id (manifest churn — measured byte-stable
    /// across all six historical revisions, tolerated anyway) is skipped rather than
    /// silently counted.
    static func manifestVolumeIds(memberVolumeIds: [String],
                                  manifestIds: Set<String>) -> Set<String> {
        Set(memberVolumeIds).intersection(manifestIds)
    }

    /// Identity-based FTS-grain resolution for adopters that persist a scope *reference*
    /// (`.custom(UUID)` cases — word cloud signatures, future bars): dereferences the id
    /// and maps a missing record to `.scopeUnavailable` (the deletion story — sketch §8),
    /// never to an unscoped query.
    @MainActor
    static func resolve(scopeId: UUID, context: ModelContext,
                        indexed: Set<String>) -> IndexedResolution {
        var descriptor = FetchDescriptor<CustomVolumeScope>(
            predicate: #Predicate { $0.id == scopeId })
        descriptor.fetchLimit = 1
        guard let scope = try? context.fetch(descriptor).first else { return .scopeUnavailable }
        return indexedResolution(memberVolumeIds: scope.volumeIds, indexed: indexed)
    }
}

// MARK: - ScopeFacets

/// Pure facet→volume-set resolution for the scope editor's rich selection facets
/// (#258 Phase 4, sketch §5): given the bundled data sources, each facet answers
/// "which manifest volumes match?" as plain set math — no stores, no async — so every
/// facet is unit-testable and the editor only performs the union.
///
/// The one facet that genuinely needs the database — people-mentions — resolves through
/// `PersonMentionStore.volumeMentionCounts(forRollupId:)` (the #264 primitive) at the
/// call site; everything here is in-memory.
enum ScopeFacets {

    /// One entry of the subject catalog: a frus-subjects subject with its volume reach.
    struct SubjectEntry: Identifiable, Equatable {
        /// The stable subject ref (dataset-scoped).
        let ref: String
        /// Display name (e.g. `"Vietnamization"`).
        let name: String
        /// Top-level category (e.g. `"Warfare"`).
        let category: String
        /// Second-level sub-category (e.g. `"Vietnam Conflict"`). Added for #308's two-level
        /// facets — the decoded `ResolvedSubject` already carries it.
        let subcategory: String
        /// How many volumes' profiles carry the subject.
        let volumeCount: Int
        var id: String { ref }
    }

    /// The searchable subject catalog, derived from the bundled profiles' two indexes:
    /// every subject any volume profile carries, with display name, category, and
    /// volume reach, sorted by reach (ties by name). Takes the dictionaries rather than
    /// `VolumeSubjectProfiles` so the function is constructible-fixture testable (the
    /// profiles struct has only a wire-format decoder, no memberwise init).
    static func subjectCatalog(
        resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]],
        volumesBySubjectRef: [String: [String]]
    ) -> [SubjectEntry] {
        // First-wins name derivation over SORTED volume keys (#332 review): dictionary
        // iteration order is unspecified, so if a ref ever carried different names across
        // volumes, the displayed name (and its tie-break sort slot) could flip between
        // launches. Sorting pins it. The volume SET is unaffected either way.
        var byRef: [String: (name: String, category: String, subcategory: String)] = [:]
        for volumeId in resolvedByVolume.keys.sorted() {
            for subject in resolvedByVolume[volumeId] ?? [] where byRef[subject.ref] == nil {
                byRef[subject.ref] = (subject.name, subject.category, subject.subcategory)
            }
        }
        return byRef.map { ref, info in
            SubjectEntry(ref: ref, name: info.name, category: info.category,
                         subcategory: info.subcategory,
                         volumeCount: volumesBySubjectRef[ref]?.count ?? 0)
        }
        .sorted { $0.volumeCount != $1.volumeCount ? $0.volumeCount > $1.volumeCount
                                                   : $0.name < $1.name }
    }

    /// The volumes whose profile carries a subject (the frus-subjects facet).
    static func volumeIds(forSubjectRef ref: String,
                          volumesBySubjectRef: [String: [String]]) -> Set<String> {
        Set(volumesBySubjectRef[ref] ?? [])
    }

    // MARK: Subject category / sub-category facets (#308 Phase 1)

    /// The taxonomy's catch-all second-level label, folded into its parent category rather
    /// than shown as a drill-down child (#308 review F4): 105/371 bundled subjects sit in a
    /// `"General"` sub-category, and for some categories (Information Programs is entirely
    /// General) the drill-down would otherwise dead-end there. Matched exactly — "General
    /// Agreement on Tariffs and Trade" is a real, distinct sub-category and is NOT folded.
    static let generalSubcategory = "General"

    /// A taxonomy **category** (top level) with its volume reach.
    struct CategoryEntry: Identifiable, Equatable {
        /// Category label (e.g. `"Warfare"`).
        let label: String
        /// Volumes whose profile carries any subject in this category.
        let volumeCount: Int
        var id: String { label }
    }

    /// A taxonomy **sub-category** (second level) with its parent category and volume reach.
    struct SubCategoryEntry: Identifiable, Equatable {
        /// Parent category label.
        let category: String
        /// Sub-category label (e.g. `"Vietnam Conflict"`).
        let subcategory: String
        /// Volumes whose profile carries any subject in this (category, sub-category).
        let volumeCount: Int
        // Sub-category labels repeat across categories (e.g. "Foreign Protest against U.S.
        // Activity" under two categories), so identity is the PAIR.
        var id: String { category + "\u{001f}" + subcategory }
    }

    /// The **category catalog**: every category any volume profile touches, with its volume
    /// reach, sorted by reach (ties by label).
    ///
    /// Semantics (#308 review F3): a volume is counted when the category appears among its
    /// TOP-15 *characteristic* subjects — "characteristic," not "about." A broad category
    /// (Foreign Economic Policy reaches ~90% of volumes) is therefore a coarse grouping, not
    /// a discriminating filter; surface the reach so that is visible, and lean on the
    /// sub-category drill-down (which discriminates) for real narrowing.
    static func categoryCatalog(
        resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> [CategoryEntry] {
        var volumesByCategory: [String: Set<String>] = [:]
        for (volumeId, subjects) in resolvedByVolume {
            for subject in subjects {
                volumesByCategory[subject.category, default: []].insert(volumeId)
            }
        }
        return volumesByCategory.map { CategoryEntry(label: $0.key, volumeCount: $0.value.count) }
            .sorted { $0.volumeCount != $1.volumeCount ? $0.volumeCount > $1.volumeCount
                                                       : $0.label < $1.label }
    }

    /// The **sub-category catalog** for one category (the drill-down), **excluding** the
    /// folded `"General"` bucket (#308 review F4), sorted by reach. Sub-category grain is
    /// where the facet discriminates (median reach ~4% of volumes). A volume reachable only
    /// via a General subject is still covered by `volumeIds(forCategory:)`.
    static func subCategoryCatalog(
        forCategory category: String,
        resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> [SubCategoryEntry] {
        var volumesBySub: [String: Set<String>] = [:]
        for (volumeId, subjects) in resolvedByVolume {
            for subject in subjects
            where subject.category == category && subject.subcategory != generalSubcategory {
                volumesBySub[subject.subcategory, default: []].insert(volumeId)
            }
        }
        return volumesBySub.map {
            SubCategoryEntry(category: category, subcategory: $0.key, volumeCount: $0.value.count)
        }
        .sorted { $0.volumeCount != $1.volumeCount ? $0.volumeCount > $1.volumeCount
                                                   : $0.subcategory < $1.subcategory }
    }

    /// The volumes whose profile carries any subject in a **category** (#308 Phase 1).
    static func volumeIds(
        forCategory category: String,
        resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> Set<String> {
        var ids: Set<String> = []
        for (volumeId, subjects) in resolvedByVolume
        where subjects.contains(where: { $0.category == category }) {
            ids.insert(volumeId)
        }
        return ids
    }

    /// The volumes whose profile carries any subject in a **(category, sub-category)** (#308
    /// Phase 1). Resolves the folded `"General"` sub-category too if asked, so the resolver
    /// is complete even though the catalog hides it.
    static func volumeIds(
        forCategory category: String, subcategory: String,
        resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> Set<String> {
        var ids: Set<String> = []
        for (volumeId, subjects) in resolvedByVolume
        where subjects.contains(where: { $0.category == category && $0.subcategory == subcategory }) {
            ids.insert(volumeId)
        }
        return ids
    }

    /// One entry of the manifest-tag catalog: an OH slug with its volume reach.
    struct TagEntry: Identifiable, Equatable {
        /// The manifest tag slug (e.g. `"cold-war"`).
        let slug: String
        /// How many manifest volumes carry the tag.
        let volumeCount: Int
        var id: String { slug }
    }

    /// The manifest-tag catalog: every distinct `VolumeManifestEntry.tags` slug with its
    /// reach, sorted by reach (ties by slug) — the OH-slug facet (sketch §5 row a).
    static func tagCatalog(_ entries: [VolumeManifestEntry]) -> [TagEntry] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for slug in entry.tags { counts[slug, default: 0] += 1 }
        }
        return counts.map { TagEntry(slug: $0.key, volumeCount: $0.value) }
            .sorted { $0.volumeCount != $1.volumeCount ? $0.volumeCount > $1.volumeCount
                                                       : $0.slug < $1.slug }
    }

    /// The volumes carrying a manifest tag slug.
    static func volumeIds(taggedWith slug: String,
                          entries: [VolumeManifestEntry]) -> Set<String> {
        Set(entries.filter { $0.tags.contains(slug) }.map(\.volumeId))
    }

    /// The coverage facet (sketch §5 "other indexed metadata"): volumes whose coverage
    /// `dateRange` INTERSECTS `[fromYear, toYear]`, optionally further filtered by an
    /// editor-name substring. A volume with no parseable coverage years is EXCLUDED —
    /// absent evidence, do not claim coverage (the repo's standing posture).
    ///
    /// Year semantics: a volume intersects when `earliestYear ≤ toYear` and
    /// `latestYear ≥ fromYear`, where a missing `latest` falls back to `earliest`
    /// (single-year coverage) and vice versa.
    static func volumeIds(coverageIntersecting fromYear: Int, toYear: Int,
                          editorContains editorFilter: String? = nil,
                          entries: [VolumeManifestEntry]) -> Set<String> {
        let folded = editorFilter?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        return Set(entries.compactMap { entry -> String? in
            guard let earliest = year(from: entry.dateRange.earliest)
                    ?? year(from: entry.dateRange.latest),
                  let latest = year(from: entry.dateRange.latest)
                    ?? year(from: entry.dateRange.earliest),
                  earliest <= toYear, latest >= fromYear else { return nil }
            if let folded, !folded.isEmpty {
                let match = entry.editors.contains {
                    $0.folding(options: [.caseInsensitive, .diacriticInsensitive],
                               locale: .current).contains(folded)
                }
                guard match else { return nil }
            }
            return entry.volumeId
        })
    }

    /// The leading year of an ISO 8601 date string, or `nil`.
    static func year(from iso: String?) -> Int? {
        guard let iso, iso.count >= 4 else { return nil }
        return Int(iso.prefix(4))
    }
}
