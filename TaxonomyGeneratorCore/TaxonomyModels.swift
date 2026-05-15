// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - File Format

/// A single entry in `volume-tag-taxonomy.json`.
///
/// Decoded at app launch by `VolumeLevelTagStore` to resolve tag slugs (stored in
/// `manifest.json`) to display names and hierarchy information for the Browse-by-Tag UI.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct TagTaxonomyFileEntry: Codable, Sendable, Equatable {
    /// URL path segment uniquely identifying this tag. e.g. `"kissinger-henry-a"`.
    public let slug: String

    /// Humanised display name. e.g. `"Kissinger, Henry A."`, `"Iran"`,
    /// `"Arms Control and Disarmament"`.
    public let displayName: String

    /// Top-level category: `"people"`, `"places"`, or `"topics"`.
    public let category: String

    /// Second-level grouping within the category.
    /// e.g. `"secretaries-of-state"`, `"near-east"`, `"arms-control-and-disarmament"`.
    public let subcategory: String

    /// Slug of the parent tag in the hierarchy, if any. `nil` for top-level tags.
    public let parentSlug: String?

    /// Optional descriptive text from history.state.gov/tags/all, if present on the page.
    public let description: String?

    public init(
        slug: String, displayName: String, category: String, subcategory: String,
        parentSlug: String?, description: String?
    ) {
        self.slug = slug
        self.displayName = displayName
        self.category = category
        self.subcategory = subcategory
        self.parentSlug = parentSlug
        self.description = description
    }
}

// MARK: - Parser Intermediate

/// Intermediate representation of a parsed tag before final serialisation.
/// Not part of the public file format.
public struct RawTaxonomyEntry: Sendable {
    public var slug: String
    public var displayName: String
    public var category: String
    public var subcategory: String
    public var parentSlug: String?
    public var description: String?

    public init(
        slug: String, displayName: String, category: String, subcategory: String,
        parentSlug: String? = nil, description: String? = nil
    ) {
        self.slug = slug
        self.displayName = displayName
        self.category = category
        self.subcategory = subcategory
        self.parentSlug = parentSlug
        self.description = description
    }

    public func asFileEntry() -> TagTaxonomyFileEntry {
        TagTaxonomyFileEntry(
            slug: slug, displayName: displayName, category: category,
            subcategory: subcategory, parentSlug: parentSlug, description: description
        )
    }
}
