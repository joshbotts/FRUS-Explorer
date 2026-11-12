// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeLevelTag

/// A volume-level subject tag, resolved from its slug against the bundled taxonomy.
///
/// Sourced from the published TEI `<teiHeader>` (curated by OH staff). Authoritative.
///
/// `VolumeLevelTag` is per-**volume** and authoritative (no confidence distinction),
/// derived from the TEI header's `keywords[@scheme="https://history.state.gov/tags"]`.
/// It drives the Browse-by-Tag volume list.
///
/// (The former per-**document** `SubjectTag` system was retired in Session 09 along with
/// the experimental document-level subject taxonomy; the successor is the volume-level
/// subject-profiles feature over `volume-subject-profiles-index.json`.)
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 09: retired the document-level `SubjectTag` family (dropped for low
///         signal-to-noise); `VolumeLevelTag`, `TagCategory`, `TagTaxonomyEntry` remain
public struct VolumeLevelTag: Identifiable, Sendable, Equatable {
    /// URL path segment slug. e.g. `"kissinger-henry-a"`. Stable primary key.
    public let slug: String

    /// Humanised display name. e.g. `"Kissinger, Henry A."`, `"Iran"`.
    public let displayName: String

    /// Top-level category.
    public let category: TagCategory

    /// Second-level grouping slug. e.g. `"secretaries-of-state"`, `"near-east"`.
    public let subcategory: String

    /// Parent tag slug in the hierarchy, if any.
    public let parentSlug: String?

    /// Optional descriptive text from history.state.gov/tags/all.
    public let description: String?

    public var id: String { slug }
}

/// Top-level category for volume-level tags.
public enum TagCategory: String, Codable, Sendable, CaseIterable {
    case people
    case places
    case topics
}

extension TagCategory {

    /// What a reader sees this category called — the Subjects browser's section headings.
    ///
    /// **This is the whole of how the three categories are told apart, and it moved here to be
    /// testable.** It sat as a `private extension` inside `SubseriesView`, out of reach of the
    /// suite, while `ColorIndependenceTests` nominally guarded a *colour* mapping that had been
    /// deleted three months earlier — so nothing checked either channel. There is no
    /// category-to-colour mapping in the app any more; the name is the signal.
    var displayName: String {
        switch self {
        case .people: return String(localized: "browser.tag.category.people", defaultValue: "People")
        case .places: return String(localized: "browser.tag.category.places", defaultValue: "Places")
        case .topics: return String(localized: "browser.tag.category.topics", defaultValue: "Topics")
        }
    }
}

// MARK: - TagTaxonomyEntry

/// A single entry decoded from `volume-tag-taxonomy.json`.
///
/// Decoded at app launch by `VolumeLevelTagStore` and used to resolve `VolumeLevelTag`
/// values from slug strings stored in `manifest.json`.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct TagTaxonomyEntry: Codable, Sendable, Equatable {
    public let slug: String
    public let displayName: String
    public let category: String
    public let subcategory: String
    public let parentSlug: String?
    public let description: String?
}
