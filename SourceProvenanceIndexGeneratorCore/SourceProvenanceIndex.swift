// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The bundled aggregate of document source-note provenance by coverage decade (SA-3a).
///
/// Small enough (<~15 KB) to ship in the app bundle; the SA-3 dashboard renders it
/// offline / zero-index. Each `byDecade` bucket holds the total note count, the number
/// of distinct volumes contributing to that decade, and a per-`ProvenanceCategory` tally.
///
/// Version history:
///   1.0 — SA-3a (Session 2026-07-04): initial implementation
public struct SourceProvenanceIndex: Codable, Sendable, Equatable {

    /// One coverage decade's provenance breakdown.
    public struct DecadeBucket: Codable, Sendable, Equatable {
        /// The decade's first year (e.g. `1910` for the 1910s).
        public let decade: Int
        /// Total source notes parsed for volumes whose coverage midpoint falls in this decade.
        public let totalNotes: Int
        /// Number of distinct volumes contributing to this decade.
        public let volumeCount: Int
        /// Per-category note counts, keyed by `ProvenanceCategory.rawValue`. Categories
        /// with a zero count are omitted to keep the artifact small.
        public let counts: [String: Int]

        /// Creates a decade bucket.
        public init(decade: Int, totalNotes: Int, volumeCount: Int, counts: [String: Int]) {
            self.decade = decade
            self.totalNotes = totalNotes
            self.volumeCount = volumeCount
            self.counts = counts
        }
    }

    /// The artifact schema version.
    public let schemaVersion: Int
    /// The generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Total source notes parsed across every covered volume.
    public let totalSourceNotes: Int
    /// Number of volumes with at least one bucketed source note.
    public let volumesCovered: Int
    /// The provenance categories, in stable display order (`ProvenanceCategory.orderedCases`).
    public let categories: [String]
    /// The per-decade breakdown, sorted ascending by `decade`.
    public let byDecade: [DecadeBucket]

    /// Creates a source-provenance index.
    public init(schemaVersion: Int, generated: String, totalSourceNotes: Int,
                volumesCovered: Int, categories: [String], byDecade: [DecadeBucket]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.totalSourceNotes = totalSourceNotes
        self.volumesCovered = volumesCovered
        self.categories = categories
        self.byDecade = byDecade
    }
}

// MARK: - Manifest decoding

/// The minimal slice of a bundled `manifest.json` entry the generator needs: the volume
/// id and its coverage date range (used to compute the coverage decade).
public struct ManifestVolumeEntry: Decodable, Sendable {
    /// The coverage span (ISO-8601 timestamps).
    public struct DateRange: Decodable, Sendable {
        /// The earliest covered date (ISO-8601, e.g. `1920-01-01T00:00:00-05:00`).
        public let earliest: String?
        /// The latest covered date (ISO-8601).
        public let latest: String?
    }
    /// The stable volume id (e.g. `frus1920v01`).
    public let volumeId: String
    /// The volume's coverage span, if present.
    public let dateRange: DateRange?
}

// MARK: - Coverage-decade bucketing

/// Computes the coverage decade for a manifest date range: the decade containing the
/// midpoint of the coverage span.
///
/// Years are read the same way SA-1a/SA-1b read them — the leading four digits of the
/// ISO string. The midpoint of `firstYear(earliest)...firstYear(latest)` is floored to
/// the decade (`year - year % 10`). Returns `nil` when neither endpoint yields a year.
///
/// - Parameter range: The manifest coverage range.
/// - Returns: The decade's first year (e.g. `1910`), or `nil`.
public func coverageDecade(for range: ManifestVolumeEntry.DateRange?) -> Int? {
    guard let range else { return nil }
    let first = firstYear(range.earliest)
    let last = firstYear(range.latest)
    switch (first, last) {
    case let (f?, l?):
        let midpoint = (min(f, l) + max(f, l)) / 2
        return midpoint - midpoint % 10
    case let (f?, nil):
        return f - f % 10
    case let (nil, l?):
        return l - l % 10
    default:
        return nil
    }
}

/// Extracts the leading four-digit year from an ISO-8601 date string, matching the
/// SA-1a/SA-1b convention.
///
/// - Parameter iso: An ISO-8601 timestamp (or `nil`).
/// - Returns: The four-digit year, or `nil` when the string does not start with one.
public func firstYear(_ iso: String?) -> Int? {
    guard let iso, iso.count >= 4 else { return nil }
    let digits = iso.prefix(4)
    guard digits.allSatisfy(\.isNumber), let year = Int(digits) else { return nil }
    return year
}
