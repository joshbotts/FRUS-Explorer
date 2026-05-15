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
/// `volume-tag-taxonomy.json` once at init and provides O(1) slug resolution for the
/// Browse-by-Tag volume list and other tag-displaying UI.
///
/// ## Unknown Slugs
/// Tags present in `manifest.json` but absent from the taxonomy return `nil` from
/// `resolve(slug:)`. This can occur when a volume's TEI references a tag that post-dates
/// the last `TaxonomyGenerator` run. Callers should handle `nil` gracefully and display
/// the raw slug as a fallback.
///
/// Version history:
///   1.0 — Session 02: initial implementation
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

    // MARK: - Initialization

    public init() {
        entries = Self.loadBundledTaxonomy()
        #if DEBUG
        print("[FRUSExplorer] VolumeLevelTagStore initialised with \(entries.count) entries.")
        #endif
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
}
