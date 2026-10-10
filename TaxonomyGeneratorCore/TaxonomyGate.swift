// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TaxonomyRefusal

/// Why a parsed taxonomy is not written over `volume-tag-taxonomy.json` (#1600).
///
/// Version history:
///   1.0 — #1600: initial implementation
public enum TaxonomyRefusal: Error, Equatable, Sendable, CustomStringConvertible {

    /// The page gave no tag at all.
    case noEntries

    /// `count` tags sit under a category the app does not have. `slug` and `category` are the
    /// first of them, in slug order.
    case unknownCategory(slug: String, category: String, count: Int)

    /// More than one in ten of the `existing` slugs in the file being replaced are missing from
    /// the new list. `lost` holds them, sorted.
    case slugsLost(lost: [String], existing: Int)

    public var description: String {
        switch self {
        case .noEntries:
            return "the page gave no tags. Its markup has probably changed: TaxonomyParser reads "
                + "<ul class=\"hsg-tag-list\"> lists of href=\"/tags/…\" links."
        case .unknownCategory(let slug, let category, let count):
            let named = category.isEmpty ? "no category" : "the category \"\(category)\""
            return "\(count) tag(s) were read under a category the app does not have "
                + "(the first is \"\(slug)\", under \(named)). The page's three roots, "
                + "people, places and topics, were not read as the parser expects."
        case .slugsLost(let lost, let existing):
            let shown = lost.prefix(8).joined(separator: ", ") + (lost.count > 8 ? ", …" : "")
            return "\(lost.count) of the \(existing) tags in the file this would replace are missing "
                + "from the page (\(shown)), which is more than one in ten. If the taxonomy has "
                + "really changed that much, delete the file and run again."
        }
    }
}

// MARK: - TaxonomyGate

/// Decides whether a parsed taxonomy may replace the one on disk (#1600).
///
/// ## The defect it ends
/// `TaxonomyParser` turns on the literal `<ul class="hsg-tag-list">`. When the page's markup
/// changes, the parse finds nothing; the runner wrote that nothing over the bundled file, 508
/// tags, and printed a tick. That file is where the app gets each volume tag's name and its place
/// in the hierarchy (`TagTaxonomyFileEntry`).
///
/// ## The three rules
/// 1. **No tags**: refused.
/// 2. **A tag outside people, places and topics**: refused. The parser sets a tag's category from
///    the root it sits under, so a page whose roots are renamed or restructured yields tags with
///    an empty category, in any number.
/// 3. **More than one in ten of the replaced file's slugs gone**: refused. Volumes carry tags by
///    slug (`manifest.json`), so a list that keeps its size and loses its slugs breaks the join
///    as surely as an empty one. Measured against the file at the output path; with no file
///    there, or one that does not decode, this rule has nothing to compare and the first two
///    stand alone.
///
/// Version history:
///   1.0 — #1600: initial implementation
public enum TaxonomyGate {

    /// The taxonomy's three categories: the page's roots, and what the app groups tags by.
    public static let categories: Set<String> = ["people", "places", "topics"]

    /// Why `entries` must not be written over `existing`, or `nil` when they may be. Pure.
    ///
    /// - Parameters:
    ///   - entries: The taxonomy just parsed.
    ///   - existing: The taxonomy in the file about to be replaced, or `nil` when there is none.
    public static func refusal(for entries: [TagTaxonomyFileEntry],
                               replacing existing: [TagTaxonomyFileEntry]?) -> TaxonomyRefusal? {
        guard !entries.isEmpty else { return .noEntries }

        let strays = entries.filter { !categories.contains($0.category) }.sorted { $0.slug < $1.slug }
        if let first = strays.first {
            return .unknownCategory(slug: first.slug, category: first.category, count: strays.count)
        }

        let lost = slugs(of: existing ?? [], missingFrom: entries)
        let existingCount = Set((existing ?? []).map(\.slug)).count
        if lost.count * 10 > existingCount {
            return .slugsLost(lost: lost, existing: existingCount)
        }
        return nil
    }

    /// The slugs `taxonomy` has and `other` lacks, sorted.
    public static func slugs(of taxonomy: [TagTaxonomyFileEntry],
                             missingFrom other: [TagTaxonomyFileEntry]) -> [String] {
        Set(taxonomy.map(\.slug)).subtracting(other.map(\.slug)).sorted()
    }
}
