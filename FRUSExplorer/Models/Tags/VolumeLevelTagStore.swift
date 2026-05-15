// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

/// Loads the bundled volume-tag taxonomy and resolves tag slugs to `VolumeLevelTag` values.
///
/// `VolumeLevelTagStore` is the single point of contact for tag display data. It decodes
/// `volume-tag-taxonomy.json` and `manifest.json` once at init, providing O(1) slug
/// resolution and O(n) volume-by-tag queries for the Browse-by-Tag volume list.
///
/// ## Volume-by-Tag Index
/// At init, the store reads `manifest.json` to build a reverse index mapping each tag slug
/// to the list of volume IDs that carry it. Call `volumes(forTagSlug:)` for single-tag
/// lookup and `volumes(forTagSlugs:)` for AND-filtered multi-tag intersection.
///
/// ## Unknown Slugs
/// Tags present in `manifest.json` but absent from the taxonomy return `nil` from
/// `resolve(slug:)`. This can occur when a volume's TEI references a tag that post-dates
/// the last `TaxonomyGenerator` run. Callers should handle `nil` gracefully and display
/// the raw slug as a fallback.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 08: volume-by-tag index; allTags/volumes query methods
@Observable
@MainActor
public final class VolumeLevelTagStore {

    // MARK: - Public State

    /// All taxonomy entries decoded from the bundle, keyed by slug.
    /// Populated synchronously at init.
    public private(set) var entries: [String: TagTaxonomyEntry] = [:]

    /// All entries as an array, sorted by display name within category.
    public var allEntries: [TagTaxonomyEntry] {
        entries.values.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return lhs.displayName < rhs.displayName
        }
    }

    // MARK: - Private State

    /// Reverse index: tag slug → sorted volume IDs that carry it.
    private var volumesByTag: [String: [String]] = [:]

    // MARK: - Initialization

    public init() {
        entries = Self.loadBundledTaxonomy()
        let manifest = Self.loadBundledManifest()
        volumesByTag = Self.buildVolumesByTag(from: manifest)
        #if DEBUG
        print("[FRUSExplorer] VolumeLevelTagStore initialised: \(entries.count) tags, \(manifest.count) volumes.")
        #endif
    }

    /// Testing initialiser — skips bundle I/O and uses provided data directly.
    init(taxonomyEntries: [TagTaxonomyEntry], manifestEntries: [VolumeManifestEntry]) {
        entries = Dictionary(uniqueKeysWithValues: taxonomyEntries.map { ($0.slug, $0) })
        volumesByTag = Self.buildVolumesByTag(from: manifestEntries)
    }

    // MARK: - Resolution

    /// Resolves a tag slug to a `VolumeLevelTag`, or `nil` if the slug is unknown.
    ///
    /// A `nil` result means the taxonomy file predates this tag's addition to history.state.gov.
    /// The caller should display the raw slug as a fallback (the tag may be valid).
    public func resolve(slug: String) -> VolumeLevelTag? {
        guard let entry = entries[slug] else { return nil }
        let category = TagCategory(rawValue: entry.category) ?? .topics
        return VolumeLevelTag(
            slug: entry.slug,
            displayName: entry.displayName,
            category: category,
            subcategory: entry.subcategory,
            parentSlug: entry.parentSlug,
            description: entry.description
        )
    }

    /// Resolves an array of slugs into `VolumeLevelTag` values.
    ///
    /// Slugs that resolve to `nil` are silently skipped. Call `resolve(slug:)` directly
    /// if you need to detect unknown slugs.
    public func resolve(slugs: [String]) -> [VolumeLevelTag] {
        slugs.compactMap { resolve(slug: $0) }
    }

    // MARK: - Tag Queries

    /// All resolved tags sorted by display name within category.
    public func allTags() -> [VolumeLevelTag] {
        allEntries.compactMap { resolve(slug: $0.slug) }
    }

    /// All resolved tags in the given category, sorted by display name.
    public func allTags(inCategory category: TagCategory) -> [VolumeLevelTag] {
        allTags().filter { $0.category == category }
    }

    /// All resolved tags in the given subcategory slug, sorted by display name.
    public func allTags(inSubcategory subcategory: String) -> [VolumeLevelTag] {
        allTags().filter { $0.subcategory == subcategory }
    }

    // MARK: - Volume Queries

    /// Returns the volume IDs that carry the given tag slug.
    ///
    /// Returns an empty array if the slug is unknown or no volume uses it.
    public func volumes(forTagSlug slug: String) -> [String] {
        volumesByTag[slug] ?? []
    }

    /// Returns the volume IDs that carry **all** of the given tag slugs (AND logic).
    ///
    /// An empty input returns an empty array. A single slug delegates to `volumes(forTagSlug:)`.
    public func volumes(forTagSlugs slugs: [String]) -> [String] {
        guard let first = slugs.first else { return [] }
        var result = Set(volumes(forTagSlug: first))
        for slug in slugs.dropFirst() {
            result.formIntersection(volumes(forTagSlug: slug))
        }
        return result.sorted()
    }

    // MARK: - Private

    private static func loadBundledTaxonomy() -> [String: TagTaxonomyEntry] {
        guard let url = Bundle.main.url(forResource: "volume-tag-taxonomy", withExtension: "json") else {
            #if DEBUG
            print("[FRUSExplorer] VolumeLevelTagStore: volume-tag-taxonomy.json not found in bundle.")
            #endif
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([TagTaxonomyEntry].self, from: data)
            return Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        } catch {
            #if DEBUG
            print("[FRUSExplorer] VolumeLevelTagStore: failed to decode taxonomy — \(error)")
            #endif
            return [:]
        }
    }

    private static func loadBundledManifest() -> [VolumeManifestEntry] {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json") else {
            #if DEBUG
            print("[FRUSExplorer] VolumeLevelTagStore: manifest.json not found in bundle.")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        } catch {
            #if DEBUG
            print("[FRUSExplorer] VolumeLevelTagStore: failed to decode manifest — \(error)")
            #endif
            return []
        }
    }

    private static func buildVolumesByTag(from entries: [VolumeManifestEntry]) -> [String: [String]] {
        var index: [String: [String]] = [:]
        for entry in entries {
            for slug in entry.tags {
                index[slug, default: []].append(entry.volumeId)
            }
        }
        // Sort volume lists for deterministic output
        for key in index.keys { index[key]?.sort() }
        return index
    }
}
