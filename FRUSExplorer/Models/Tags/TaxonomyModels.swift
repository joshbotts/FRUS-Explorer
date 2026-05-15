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
/// ## Distinction from SubjectTag
/// - `VolumeLevelTag`: per-**volume**, authoritative, no confidence distinction,
///   derived from the TEI header's `keywords[@scheme="https://history.state.gov/tags"]`.
/// - `SubjectTag` (Session 08): per-**document**, experimental pipeline, confidence
///   `.curated | .stringMatch`.
///
/// These two tag systems coexist in the app. `VolumeLevelTag` drives the Browse-by-Tag
/// volume list; `SubjectTag` drives document-level search filtering.
///
/// Version history:
///   1.0 — Session 02: initial implementation
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

// MARK: - SubjectTag

/// A document-level subject tag produced by the experimental tagging pipeline.
///
/// Unlike `VolumeLevelTag` (which is per-volume and authoritative), `SubjectTag` is
/// per-document and carries a `confidence` tier that reflects how the tag was assigned.
///
/// `.curated` tags are manually verified; `.stringMatch` tags are algorithmically
/// derived and may have false positives.
///
/// Version history:
///   1.0 — Session 08: initial implementation
public struct SubjectTag: Identifiable, Sendable, Equatable {
    /// Stable primary key. Shares the namespace with `VolumeLevelTag.slug`.
    public let subjectId: String

    /// Human-readable display name.
    public let displayName: String

    /// Top-level category.
    public let category: TagCategory

    /// Confidence tier assigned by the tagging pipeline.
    public let confidence: SubjectTagConfidence

    public var id: String { subjectId }
}

/// Confidence tier for a document-level `SubjectTag`.
public enum SubjectTagConfidence: String, Codable, Sendable, CaseIterable {
    /// Manually verified by OH staff or the data pipeline operator.
    case curated
    /// Derived algorithmically via string matching. May include false positives.
    case stringMatch
}

// MARK: - SubjectTagEntry

/// A single entry decoded from `taxonomy.json` (the document-level subject taxonomy).
///
/// Decoded by `SubjectTagStore` at launch and used to resolve `SubjectTag` values.
///
/// Version history:
///   1.0 — Session 08: initial implementation
public struct SubjectTagEntry: Codable, Sendable, Equatable {
    public let subjectId: String
    public let displayName: String
    public let category: String
}

// MARK: - SubjectAppearance

/// A record linking a subject to a specific document, decoded from `subject-appearances.json`.
///
/// `SubjectTagStore` uses these records to answer "which subjects appear in document X?"
/// and "which documents mention subject Y?".
///
/// Version history:
///   1.0 — Session 08: initial implementation
public struct SubjectAppearance: Codable, Sendable, Equatable {
    public let subjectId: String
    public let documentId: String
    public let volumeId: String
    public let confidence: SubjectTagConfidence
}
