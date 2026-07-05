// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - AdministrationProfilesIndex

/// The bundled `administration-profiles-index.json` aggregate (Series Analytics
/// SA-2a), mirroring the artifact the `AdministrationProfilesIndexGenerator`
/// writes.
///
/// The generator attributes every dated FRUS document to the presidential
/// administration(s) whose term its coverage date falls within — under an
/// *any-overlap* rule, so a volume spanning two administrations counts in both.
/// Point-dated documents carry a single coverage date; editorial-note documents
/// carry a date *range* and are aggregated separately (`rangeDocCount`) so the
/// dashboard can include or exclude them via a toggle.
///
/// Every field is optional-tolerant on decode: a missing key must not crash. This
/// is a pure `Codable`/`Sendable` value with no SwiftUI dependency; the view
/// derives its chart-ready `AdministrationProfilesData` from it.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
struct AdministrationProfilesIndex: Codable, Sendable {
    /// The artifact schema version (currently `1`).
    let schemaVersion: Int
    /// The generation date (`yyyy-MM-dd`), for provenance display.
    let generated: String
    /// Total point-dated documents attributed across all administrations.
    let totalDocumentsPointDated: Int
    /// Total range-dated (editorial-note) documents attributed.
    let totalDocumentsRangeDated: Int
    /// Total documents that could not be dated at all.
    let totalDocumentsUndated: Int
    /// How many volumes contributed documents.
    let volumesCovered: Int
    /// Per-administration profiles, in the artifact's order (chronological by
    /// `number`).
    let administrations: [AdministrationProfile]
    /// Per-volume document totals, keyed by `volumeId` — the denominators for the
    /// per-administration volume-proportion breakdown.
    let volumeTotals: [String: VolumeTotals]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated
        case totalDocumentsPointDated, totalDocumentsRangeDated, totalDocumentsUndated
        case volumesCovered, administrations, volumeTotals
    }

    /// Decodes tolerantly: any missing key falls back to a benign default (zero,
    /// empty string, or empty collection) rather than throwing, so a partially
    /// written or older artifact still yields a usable — if empty — index.
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion)) ?? 0
        generated = (try? container.decode(String.self, forKey: .generated)) ?? ""
        totalDocumentsPointDated = (try? container.decode(Int.self, forKey: .totalDocumentsPointDated)) ?? 0
        totalDocumentsRangeDated = (try? container.decode(Int.self, forKey: .totalDocumentsRangeDated)) ?? 0
        totalDocumentsUndated = (try? container.decode(Int.self, forKey: .totalDocumentsUndated)) ?? 0
        volumesCovered = (try? container.decode(Int.self, forKey: .volumesCovered)) ?? 0
        administrations = (try? container.decode([AdministrationProfile].self, forKey: .administrations)) ?? []
        volumeTotals = (try? container.decode([String: VolumeTotals].self, forKey: .volumeTotals)) ?? [:]
    }

    /// Memberwise initializer for tests and previews that construct a fixture
    /// index directly.
    ///
    /// - Parameters mirror the stored properties.
    init(
        schemaVersion: Int,
        generated: String,
        totalDocumentsPointDated: Int,
        totalDocumentsRangeDated: Int,
        totalDocumentsUndated: Int,
        volumesCovered: Int,
        administrations: [AdministrationProfile],
        volumeTotals: [String: VolumeTotals]
    ) {
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

// MARK: - AdministrationProfile

/// One presidential administration's document/volume attribution.
///
/// Administrations are **per-president** — Nixon and Ford are distinct entries,
/// as are Grover Cleveland's two non-consecutive terms. Later administrations for
/// which FRUS is not yet published carry all-zero counts and are hidden from the
/// dashboard's charts and lists.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
struct AdministrationProfile: Codable, Sendable, Hashable {
    /// A stable slug (e.g. `"nixon"`, `"cleveland-1"`).
    let id: String
    /// The presidency number (16 = Lincoln … 47 = Trump's second term), the
    /// chronological sort key.
    let number: Int
    /// The president's display name.
    let president: String
    /// The party label (`"Republican"` / `"Democratic"` / `"National Union"`).
    let party: String
    /// The term's ISO start date (`yyyy-MM-dd`).
    let start: String
    /// The term's ISO end date, or `nil` for the sitting administration.
    let end: String?
    /// Point-dated documents attributed to this administration (any-overlap).
    let pointDocCount: Int
    /// Range-dated (editorial-note) documents attributed to this administration.
    let rangeDocCount: Int
    /// Volumes touching this administration (any-overlap, counting range docs).
    let volumeCount: Int
    /// Volumes touching this administration counting point-dated docs only.
    let volumeCountPointOnly: Int
    /// The earliest coverage year attributed here, or `nil` when none.
    let coverageEarliest: Int?
    /// The latest coverage year attributed here, or `nil` when none.
    let coverageLatest: Int?
    /// The per-volume breakdown, pre-sorted by `pointDocs` descending.
    let volumes: [AdministrationVolume]

    private enum CodingKeys: String, CodingKey {
        case id, number, president, party, start, end
        case pointDocCount, rangeDocCount, volumeCount, volumeCountPointOnly
        case coverageEarliest, coverageLatest, volumes
    }

    /// Tolerant decode: missing scalar keys default to `0`/`""`/`nil`, missing
    /// `volumes` to `[]`.
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        number = (try? container.decode(Int.self, forKey: .number)) ?? 0
        president = (try? container.decode(String.self, forKey: .president)) ?? ""
        party = (try? container.decode(String.self, forKey: .party)) ?? ""
        start = (try? container.decode(String.self, forKey: .start)) ?? ""
        end = try? container.decodeIfPresent(String.self, forKey: .end)
        pointDocCount = (try? container.decode(Int.self, forKey: .pointDocCount)) ?? 0
        rangeDocCount = (try? container.decode(Int.self, forKey: .rangeDocCount)) ?? 0
        volumeCount = (try? container.decode(Int.self, forKey: .volumeCount)) ?? 0
        volumeCountPointOnly = (try? container.decode(Int.self, forKey: .volumeCountPointOnly)) ?? 0
        coverageEarliest = try? container.decodeIfPresent(Int.self, forKey: .coverageEarliest)
        coverageLatest = try? container.decodeIfPresent(Int.self, forKey: .coverageLatest)
        volumes = (try? container.decode([AdministrationVolume].self, forKey: .volumes)) ?? []
    }

    /// Memberwise initializer for fixtures.
    ///
    /// - Parameters mirror the stored properties.
    init(
        id: String, number: Int, president: String, party: String,
        start: String, end: String?, pointDocCount: Int, rangeDocCount: Int,
        volumeCount: Int, volumeCountPointOnly: Int,
        coverageEarliest: Int?, coverageLatest: Int?, volumes: [AdministrationVolume]
    ) {
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

// MARK: - AdministrationVolume

/// One volume's contribution to an administration — the numerator of that
/// volume's proportion for the administration.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
struct AdministrationVolume: Codable, Sendable, Hashable {
    /// The volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// Point-dated documents from this volume attributed to the administration.
    let pointDocs: Int
    /// Range-dated documents from this volume attributed to the administration.
    let rangeDocs: Int

    private enum CodingKeys: String, CodingKey {
        case volumeId, pointDocs, rangeDocs
    }

    /// Tolerant decode.
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        volumeId = (try? container.decode(String.self, forKey: .volumeId)) ?? ""
        pointDocs = (try? container.decode(Int.self, forKey: .pointDocs)) ?? 0
        rangeDocs = (try? container.decode(Int.self, forKey: .rangeDocs)) ?? 0
    }

    /// Memberwise initializer for fixtures.
    ///
    /// - Parameters mirror the stored properties.
    init(volumeId: String, pointDocs: Int, rangeDocs: Int) {
        self.volumeId = volumeId
        self.pointDocs = pointDocs
        self.rangeDocs = rangeDocs
    }
}

// MARK: - VolumeTotals

/// A single volume's document totals — the denominator of the per-administration
/// volume-proportion math.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
struct VolumeTotals: Codable, Sendable, Hashable {
    /// Point-dated documents in the volume.
    let pointDocs: Int
    /// Range-dated (editorial-note) documents in the volume.
    let rangeDocs: Int
    /// Undated documents in the volume.
    let undatedDocs: Int

    private enum CodingKeys: String, CodingKey {
        case pointDocs, rangeDocs, undatedDocs
    }

    /// Tolerant decode.
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pointDocs = (try? container.decode(Int.self, forKey: .pointDocs)) ?? 0
        rangeDocs = (try? container.decode(Int.self, forKey: .rangeDocs)) ?? 0
        undatedDocs = (try? container.decode(Int.self, forKey: .undatedDocs)) ?? 0
    }

    /// Memberwise initializer for fixtures.
    ///
    /// - Parameters mirror the stored properties.
    init(pointDocs: Int, rangeDocs: Int, undatedDocs: Int) {
        self.pointDocs = pointDocs
        self.rangeDocs = rangeDocs
        self.undatedDocs = undatedDocs
    }
}

// MARK: - PoliticalParty

/// A stable mapping from the artifact's raw party string to a display label and a
/// chart color.
///
/// The color is deliberately routed through this enum so the two overview charts
/// share one party palette, and so the `chartForegroundStyleScale(domain:range:)`
/// call passes BOTH a domain (the display labels present) and a matching range
/// (their colors) — without an explicit range Swift Charts silently reassigns
/// its own hues (the CA-5 gotcha), which for a party palette would be misleading.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
enum PoliticalParty: String, CaseIterable, Sendable, Hashable {
    /// The Republican Party.
    case republican
    /// The Democratic Party.
    case democratic
    /// The National Union Party (Andrew Johnson's 1864–68 ticket).
    case nationalUnion
    /// Any party string the mapping does not recognise.
    case other

    /// Maps a raw artifact party string to a `PoliticalParty`, case-insensitively.
    ///
    /// - Parameter raw: The `party` field from the artifact.
    /// - Returns: The matching case, or `.other` when unrecognised.
    static func from(raw: String) -> PoliticalParty {
        switch raw.lowercased() {
        case "republican": return .republican
        case "democratic", "democrat": return .democratic
        case "national union": return .nationalUnion
        default: return .other
        }
    }

    /// The stable display label used on chart legends and profile cards.
    var displayName: String {
        switch self {
        case .republican:
            return String(localized: "series.admin.party.republican", defaultValue: "Republican")
        case .democratic:
            return String(localized: "series.admin.party.democratic", defaultValue: "Democratic")
        case .nationalUnion:
            return String(localized: "series.admin.party.nationalUnion", defaultValue: "National Union")
        case .other:
            return String(localized: "series.admin.party.other", defaultValue: "Other")
        }
    }

    /// The stable chart color for this party — the `range` half of the party
    /// color scale.
    var color: Color {
        switch self {
        case .republican: return .red
        case .democratic: return .blue
        case .nationalUnion: return .orange
        case .other: return .gray
        }
    }

    /// The parties in stable legend order.
    static var ordered: [PoliticalParty] {
        [.republican, .democratic, .nationalUnion, .other]
    }
}

// MARK: - AdministrationProfilesData

/// Pure, deterministic derivation of per-administration FRUS coverage from the
/// bundled `AdministrationProfilesIndex`, parameterised by the editorial-note
/// toggle.
///
/// This carries no SwiftUI beyond the party palette and depends only on the
/// decoded aggregate, so it is fully unit-testable. Everything it derives measures
/// **coverage** — which administration's foreign policy the published documents
/// concern — not production (when volumes were printed). Because attribution is
/// *any-overlap*, a volume spanning two administrations is counted in both, so
/// summed volume counts exceed the 552-volume corpus and per-volume proportions
/// can sum to over 100% across administrations. That is expected and disclosed.
///
/// Zero-document administrations (later presidencies FRUS has not yet published)
/// are hidden from every derived collection.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
struct AdministrationProfilesData: Sendable {

    // MARK: Point types

    /// One administration's derived profile — the row behind both overview charts
    /// and the detail card.
    struct Profile: Identifiable, Sendable, Hashable {
        /// The administration slug (also the `Identifiable` id).
        let id: String
        /// The presidency number, the chronological sort key.
        let number: Int
        /// The president's display name.
        let president: String
        /// The mapped political party (drives chart color).
        let party: PoliticalParty
        /// The ISO term start (`yyyy-MM-dd`).
        let start: String
        /// The ISO term end, or `nil` for the sitting administration.
        let end: String?
        /// Point-dated documents attributed to this administration.
        let pointDocCount: Int
        /// Range-dated documents attributed to this administration.
        let rangeDocCount: Int
        /// Documents counted under the current toggle (`pointDocCount` alone, or
        /// `+ rangeDocCount` when editorial notes are included).
        let documentCount: Int
        /// Volumes touching this administration (any-overlap).
        let volumeCount: Int
        /// The term length in years, derived from the ISO dates (`0` when the end
        /// is `nil` or the span is non-positive).
        let termYears: Double
        /// `volumeCount / termYears`, or `0` when `termYears` is `0`.
        let volumesPerAdministrationYear: Double
        /// The earliest attributed coverage year, or `nil`.
        let coverageEarliest: Int?
        /// The latest attributed coverage year, or `nil`.
        let coverageLatest: Int?
    }

    /// One volume's proportion within one administration — a row of the detail
    /// card's volume list.
    struct VolumeShare: Identifiable, Sendable, Hashable {
        /// The volume identifier (also the `Identifiable` id).
        let id: String
        /// Documents from this volume attributed to the administration, under the
        /// current toggle.
        let documentCount: Int
        /// This administration's documents as a fraction of the *whole volume's*
        /// documents (under the same toggle), in `0.0...` — can exceed `1.0`
        /// summed across administrations under any-overlap, but never per row.
        let proportion: Double
    }

    // MARK: Derived collections

    /// The populated administrations (any document under the *point* count, so the
    /// set is stable across the toggle), chronological by `number`.
    let profiles: [Profile]

    /// Per-administration volume breakdowns, keyed by administration id; each
    /// array is sorted by `documentCount` descending.
    let volumeShares: [String: [VolumeShare]]

    // MARK: Stats

    /// Total point-dated documents across the whole artifact.
    let totalDocumentsPointDated: Int
    /// Total range-dated documents across the whole artifact.
    let totalDocumentsRangeDated: Int
    /// The artifact's covered-volume count.
    let volumesCovered: Int
    /// Whether editorial-note (range-dated) documents are included in the counts.
    let includesEditorialNotes: Bool

    // MARK: Init

    /// Computes every derived collection and statistic from the decoded index,
    /// under the given editorial-note toggle.
    ///
    /// A `nil` index (resource missing/malformed) yields empty collections and
    /// zeroed stats — never a crash or divide-by-zero. Administrations with no
    /// point *and* no range documents are hidden. Term years and per-volume
    /// proportions guard against a `nil` end date, a zero-length term, and a
    /// zero-document volume total.
    ///
    /// - Parameters:
    ///   - index: The decoded `administration-profiles-index.json`, or `nil`.
    ///   - includeEditorialNotes: When `true`, range-dated documents are added to
    ///     every document count and to the proportion numerator/denominator.
    init(index: AdministrationProfilesIndex?, includeEditorialNotes: Bool) {
        includesEditorialNotes = includeEditorialNotes

        guard let index else {
            profiles = []
            volumeShares = [:]
            totalDocumentsPointDated = 0
            totalDocumentsRangeDated = 0
            volumesCovered = 0
            return
        }

        totalDocumentsPointDated = index.totalDocumentsPointDated
        totalDocumentsRangeDated = index.totalDocumentsRangeDated
        volumesCovered = index.volumesCovered

        // Populated = at least one attributed document of either kind (stable
        // across the toggle so the chart's bar set does not appear/disappear).
        let populated = index.administrations
            .filter { $0.pointDocCount > 0 || $0.rangeDocCount > 0 }
            .sorted { $0.number < $1.number }

        profiles = populated.map { admin in
            let docCount = admin.pointDocCount + (includeEditorialNotes ? admin.rangeDocCount : 0)
            let years = Self.termYears(start: admin.start, end: admin.end)
            let perYear = years > 0 ? Double(admin.volumeCount) / years : 0
            return Profile(
                id: admin.id,
                number: admin.number,
                president: admin.president,
                party: PoliticalParty.from(raw: admin.party),
                start: admin.start,
                end: admin.end,
                pointDocCount: admin.pointDocCount,
                rangeDocCount: admin.rangeDocCount,
                documentCount: docCount,
                volumeCount: admin.volumeCount,
                termYears: years,
                volumesPerAdministrationYear: perYear,
                coverageEarliest: admin.coverageEarliest,
                coverageLatest: admin.coverageLatest
            )
        }

        // Per-administration volume proportions.
        var shares: [String: [VolumeShare]] = [:]
        for admin in populated {
            let rows: [VolumeShare] = admin.volumes.map { vol in
                let numerator = vol.pointDocs + (includeEditorialNotes ? vol.rangeDocs : 0)
                let totals = index.volumeTotals[vol.volumeId]
                let denominator = (totals?.pointDocs ?? 0)
                    + (includeEditorialNotes ? (totals?.rangeDocs ?? 0) : 0)
                let proportion = denominator > 0 ? Double(numerator) / Double(denominator) : 0
                return VolumeShare(id: vol.volumeId, documentCount: numerator, proportion: proportion)
            }
            .sorted { $0.documentCount > $1.documentCount }
            shares[admin.id] = rows
        }
        volumeShares = shares
    }

    // MARK: Helpers

    /// The default focus administration — the most-documented one under the
    /// current toggle, or `nil` when there are none.
    var mostDocumentedProfile: Profile? {
        profiles.max { $0.documentCount < $1.documentCount }
    }

    /// The volume-share rows for one administration, or `[]` when unknown.
    ///
    /// - Parameter id: The administration slug.
    /// - Returns: Its volume breakdown, sorted by document count descending.
    func volumeShares(for id: String) -> [VolumeShare] {
        volumeShares[id] ?? []
    }

    /// Term length in years from ISO `yyyy-MM-dd` endpoints.
    ///
    /// Returns `0` when the end date is `nil` (the sitting administration), when
    /// either date fails to parse, or when the computed span is non-positive —
    /// so callers can divide by it only after a `> 0` guard.
    ///
    /// - Parameters:
    ///   - start: The ISO start date.
    ///   - end: The ISO end date, or `nil`.
    /// - Returns: The span in years (fractional), or `0`.
    static func termYears(start: String, end: String?) -> Double {
        guard let end,
              let startDate = isoFormatter.date(from: start),
              let endDate = isoFormatter.date(from: end) else {
            return 0
        }
        let seconds = endDate.timeIntervalSince(startDate)
        guard seconds > 0 else { return 0 }
        return seconds / Self.secondsPerYear
    }

    /// Average seconds per year (accounts for leap years), the term-length divisor.
    private static let secondsPerYear: Double = 365.2425 * 24 * 60 * 60

    /// A fixed `yyyy-MM-dd` parser, UTC, POSIX — deterministic regardless of the
    /// device locale/time zone.
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
