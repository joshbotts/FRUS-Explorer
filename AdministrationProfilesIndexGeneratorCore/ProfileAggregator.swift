// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Aggregates per-volume `DocumentDate` lists into the `AdministrationProfilesIndex`.
///
/// Pure and filesystem-free so the attribution + aggregation rules are unit-testable
/// directly from in-memory fixtures. The runner supplies the decoded administrations and,
/// per volume, the list of extracted `DocumentDate`s.
///
/// **Attribution rules.**
/// - A **point** document is attributed to the single administration whose half-open
///   `[start, end)` interval contains its date (`Administration.contains`). A point date
///   on a succession day lands in the successor.
/// - A **range** document is attributed to **every** administration whose interval
///   overlaps its `[start, end]` (`Administration.rangeOverlaps`) — the any-overlap rule.
/// - An **undated** document is attributed to no administration but is counted in that
///   volume's `undatedDocs` total.
///
/// Version history:
///   1.0 — SA-2a (Session 2026-07-05): initial implementation
public enum ProfileAggregator {

    /// One volume's extracted document dates, keyed by volume id.
    public struct VolumeDates: Sendable {
        /// The volume id (e.g. `frus1945v01`).
        public let volumeId: String
        /// The document dates extracted from the volume, in document order.
        public let dates: [DocumentDate]

        /// Creates a per-volume date list.
        public init(volumeId: String, dates: [DocumentDate]) {
            self.volumeId = volumeId
            self.dates = dates
        }
    }

    /// Mutable per-(administration) accumulator.
    private struct AdminAccumulator {
        var pointDocs = 0
        var rangeDocs = 0
        /// Per-volume point/range tallies for this administration.
        var volumes: [String: (point: Int, range: Int)] = [:]
        var coverageEarliest: Int?
        var coverageLatest: Int?
    }

    /// Builds the full index from the administrations table and per-volume date lists.
    ///
    /// - Parameters:
    ///   - administrations: The decoded administrations, in chronological order.
    ///   - volumes: Per-volume extracted document dates. Order does not affect output.
    ///   - schemaVersion: The artifact schema version to stamp.
    ///   - generated: The `yyyy-MM-dd` generation stamp.
    /// - Returns: The assembled, deterministic `AdministrationProfilesIndex`.
    public static func aggregate(
        administrations: [Administration],
        volumes: [VolumeDates],
        schemaVersion: Int,
        generated: String
    ) -> AdministrationProfilesIndex {

        var accByAdmin: [String: AdminAccumulator] = [:]
        var volumeTotals: [String: AdministrationProfilesIndex.VolumeTotals] = [:]
        var totalPoint = 0, totalRange = 0, totalUndated = 0
        var volumesCovered = 0

        // Deterministic volume order for accumulation (does not affect the final sorted
        // output, but keeps intermediate iteration stable).
        let orderedVolumes = volumes.sorted { $0.volumeId < $1.volumeId }

        for vol in orderedVolumes {
            var volPoint = 0, volRange = 0, volUndated = 0

            for date in vol.dates {
                switch date {
                case .point(let day):
                    volPoint += 1
                    let year = Int(day.prefix(4))
                    for admin in administrations where admin.contains(day: day) {
                        var acc = accByAdmin[admin.id] ?? AdminAccumulator()
                        acc.pointDocs += 1
                        var vt = acc.volumes[vol.volumeId] ?? (0, 0)
                        vt.point += 1
                        acc.volumes[vol.volumeId] = vt
                        if let year {
                            acc.coverageEarliest = acc.coverageEarliest.map { Swift.min($0, year) } ?? year
                            acc.coverageLatest = acc.coverageLatest.map { Swift.max($0, year) } ?? year
                        }
                        accByAdmin[admin.id] = acc
                    }

                case .range(let start, let end):
                    volRange += 1
                    for admin in administrations
                    where admin.rangeOverlaps(rangeStart: start, rangeEnd: end) {
                        var acc = accByAdmin[admin.id] ?? AdminAccumulator()
                        acc.rangeDocs += 1
                        var vt = acc.volumes[vol.volumeId] ?? (0, 0)
                        vt.range += 1
                        acc.volumes[vol.volumeId] = vt
                        accByAdmin[admin.id] = acc
                    }

                case .undated:
                    volUndated += 1
                }
            }

            volumeTotals[vol.volumeId] = .init(
                pointDocs: volPoint, rangeDocs: volRange, undatedDocs: volUndated)
            totalPoint += volPoint
            totalRange += volRange
            totalUndated += volUndated
            if volPoint + volRange + volUndated > 0 { volumesCovered += 1 }
        }

        // Assemble profiles in the administrations.json order.
        let profiles = administrations.map { admin -> AdministrationProfilesIndex.AdministrationProfile in
            let acc = accByAdmin[admin.id] ?? AdminAccumulator()
            let breakdown = acc.volumes
                .map { AdministrationProfilesIndex.VolumeBreakdown(
                    volumeId: $0.key, pointDocs: $0.value.point, rangeDocs: $0.value.range) }
                .sorted { lhs, rhs in
                    if lhs.pointDocs != rhs.pointDocs { return lhs.pointDocs > rhs.pointDocs }
                    if lhs.rangeDocs != rhs.rangeDocs { return lhs.rangeDocs > rhs.rangeDocs }
                    return lhs.volumeId < rhs.volumeId
                }
            let pointOnlyVolumes = acc.volumes.values.filter { $0.point > 0 }.count
            return AdministrationProfilesIndex.AdministrationProfile(
                id: admin.id, number: admin.number, president: admin.president,
                party: admin.party, start: admin.startDay, end: admin.endDay,
                pointDocCount: acc.pointDocs, rangeDocCount: acc.rangeDocs,
                volumeCount: acc.volumes.count, volumeCountPointOnly: pointOnlyVolumes,
                coverageEarliest: acc.coverageEarliest, coverageLatest: acc.coverageLatest,
                volumes: breakdown)
        }

        return AdministrationProfilesIndex(
            schemaVersion: schemaVersion, generated: generated,
            totalDocumentsPointDated: totalPoint,
            totalDocumentsRangeDated: totalRange,
            totalDocumentsUndated: totalUndated,
            volumesCovered: volumesCovered,
            administrations: profiles,
            volumeTotals: volumeTotals)
    }
}
