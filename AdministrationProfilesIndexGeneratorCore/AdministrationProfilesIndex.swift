// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The bundled aggregate mapping FRUS document coverage to presidential administrations
/// (SA-2a) — the data half of the SA-2 "Administration Production Profiles" dashboard.
///
/// Attribution is by **document date keyed to who was in office** (coverage, not
/// production): a single-dated ("point") document counts toward the one administration
/// whose half-open interval contains its date; a range-dated document (chiefly editorial
/// notes) counts toward **every** administration its range overlaps (any-overlap), and is
/// tracked separately from point documents so the dashboard can offer an include/exclude
/// filter. A volume counts toward every administration it has a point-or-range document
/// in. Undated documents are counted (as a disclosed denominator component) but attributed
/// to no administration.
///
/// Version history:
///   1.0 — SA-2a (Session 2026-07-05): initial implementation
public struct AdministrationProfilesIndex: Codable, Sendable, Equatable {

    /// One administration's aggregated profile plus its per-volume breakdown.
    public struct AdministrationProfile: Codable, Sendable, Equatable {
        /// Stable slug id (e.g. `truman`).
        public let id: String
        /// Presidential ordinal number.
        public let number: Int
        /// President's full name.
        public let president: String
        /// Party label.
        public let party: String
        /// Inclusive start date (`yyyy-MM-dd`).
        public let start: String
        /// Exclusive end date (`yyyy-MM-dd`), or `nil` for the sitting administration.
        public let end: String?
        /// Count of point-dated documents whose date falls in this administration.
        public let pointDocCount: Int
        /// Count of range-dated documents whose range overlaps this administration.
        public let rangeDocCount: Int
        /// Distinct volumes with at least one point-or-range document in this administration.
        public let volumeCount: Int
        /// Distinct volumes with at least one **point** document in this administration.
        public let volumeCountPointOnly: Int
        /// Earliest point-document year attributed to this administration, or `nil`.
        public let coverageEarliest: Int?
        /// Latest point-document year attributed to this administration, or `nil`.
        public let coverageLatest: Int?
        /// Per-volume breakdown, sorted by `pointDocs` descending (ties by `volumeId`).
        public let volumes: [VolumeBreakdown]

        /// Creates an administration profile.
        public init(id: String, number: Int, president: String, party: String,
                    start: String, end: String?, pointDocCount: Int, rangeDocCount: Int,
                    volumeCount: Int, volumeCountPointOnly: Int,
                    coverageEarliest: Int?, coverageLatest: Int?,
                    volumes: [VolumeBreakdown]) {
            self.id = id
            self.number = number
            self.president = president
            self.party = party
            self.start = start
            self.end = end
            self.pointDocCount = pointDocCount
            self.rangeDocCount = rangeDocCount
            self.volumeCount = volumeCount
            self.volumeCountPointOnly = volumeCountPointOnly
            self.coverageEarliest = coverageEarliest
            self.coverageLatest = coverageLatest
            self.volumes = volumes
        }
    }

    /// One volume's contribution to a single administration.
    public struct VolumeBreakdown: Codable, Sendable, Equatable {
        /// The volume id (e.g. `frus1945v01`).
        public let volumeId: String
        /// Point documents from this volume attributed to the enclosing administration.
        public let pointDocs: Int
        /// Range documents from this volume attributed to the enclosing administration.
        public let rangeDocs: Int

        /// Creates a per-volume breakdown row.
        public init(volumeId: String, pointDocs: Int, rangeDocs: Int) {
            self.volumeId = volumeId
            self.pointDocs = pointDocs
            self.rangeDocs = rangeDocs
        }
    }

    /// A volume's global document totals (the denominators for proportions).
    public struct VolumeTotals: Codable, Sendable, Equatable {
        /// Total point-dated documents in the volume.
        public let pointDocs: Int
        /// Total range-dated documents in the volume.
        public let rangeDocs: Int
        /// Total undated documents in the volume.
        public let undatedDocs: Int

        /// Creates a volume-totals row.
        public init(pointDocs: Int, rangeDocs: Int, undatedDocs: Int) {
            self.pointDocs = pointDocs
            self.rangeDocs = rangeDocs
            self.undatedDocs = undatedDocs
        }
    }

    /// The artifact schema version.
    public let schemaVersion: Int
    /// The generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Total point-dated documents across every covered volume.
    public let totalDocumentsPointDated: Int
    /// Total range-dated documents across every covered volume.
    public let totalDocumentsRangeDated: Int
    /// Total undated documents across every covered volume.
    public let totalDocumentsUndated: Int
    /// Number of volumes with at least one document of any kind.
    public let volumesCovered: Int
    /// The per-administration profiles, in the `administrations.json` order.
    public let administrations: [AdministrationProfile]
    /// Per-volume global totals, keyed by volume id.
    public let volumeTotals: [String: VolumeTotals]

    /// Creates an administration-profiles index.
    public init(schemaVersion: Int, generated: String,
                totalDocumentsPointDated: Int, totalDocumentsRangeDated: Int,
                totalDocumentsUndated: Int, volumesCovered: Int,
                administrations: [AdministrationProfile],
                volumeTotals: [String: VolumeTotals]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.totalDocumentsPointDated = totalDocumentsPointDated
        self.totalDocumentsRangeDated = totalDocumentsRangeDated
        self.totalDocumentsUndated = totalDocumentsUndated
        self.volumesCovered = volumesCovered
        self.administrations = administrations
        self.volumeTotals = volumeTotals
    }
}
