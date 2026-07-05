// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - GeographicRegion

/// A coarse geographic region used to colour the corpus's place-tag emphasis,
/// mapped one-to-one to the six State Department regional bureaus (plus an
/// `.other` catch-all for the taxonomy's dependency/territory/`"other"`
/// subcategories).
///
/// The bundled volume-tag taxonomy assigns each place tag a `subcategory` that,
/// for the six regional bureaus, is exactly the bureau slug (`"europe"`,
/// `"near-east"`, …). `from(subcategory:)` maps those slugs to a case; every
/// other subcategory — singleton territories and dependencies, `"other"` — folds
/// to `.other`, so the regions form a clean, exhaustive partition of the place
/// taxonomy.
///
/// Version history:
///   1.0 — Analytics SA-2: initial implementation
enum GeographicRegion: Int, CaseIterable, Sendable, Hashable {
    /// The Bureau of European and Eurasian Affairs (`"europe"`).
    case europe = 0
    /// The Bureau of Near Eastern Affairs (`"near-east"`).
    case nearEast = 1
    /// The Bureau of South and Central Asian Affairs (`"south-and-central-asia"`).
    case southCentralAsia = 2
    /// The Bureau of East Asian and Pacific Affairs (`"east-asia-and-pacific"`).
    case eastAsiaPacific = 3
    /// The Bureau of African Affairs (`"sub-saharan-africa"`).
    case subSaharanAfrica = 4
    /// The Bureau of Western Hemisphere Affairs (`"western-hemisphere"`).
    case westernHemisphere = 5
    /// Everything the six bureaus don't cover — dependencies, territories, and
    /// the taxonomy's `"other"` bucket.
    case other = 6

    /// Maps a taxonomy place-tag `subcategory` slug to a region.
    ///
    /// The six regional-bureau slugs map to their case; any other slug (a
    /// dependency, a territory, `"other"`) maps to `.other`.
    ///
    /// - Parameter subcategory: The `TagTaxonomyEntry.subcategory` slug of a
    ///   place tag.
    /// - Returns: The matching region, or `.other`.
    static func from(subcategory: String) -> GeographicRegion {
        switch subcategory {
        case "europe":                  return .europe
        case "near-east":               return .nearEast
        case "south-and-central-asia":  return .southCentralAsia
        case "east-asia-and-pacific":   return .eastAsiaPacific
        case "sub-saharan-africa":      return .subSaharanAfrica
        case "western-hemisphere":      return .westernHemisphere
        default:                        return .other
        }
    }

    /// Localised label for charts and legends.
    var displayName: String {
        switch self {
        case .europe:
            return String(localized: "series.region.europe", defaultValue: "Europe")
        case .nearEast:
            return String(localized: "series.region.nearEast", defaultValue: "Near East")
        case .southCentralAsia:
            return String(localized: "series.region.southCentralAsia", defaultValue: "South & Central Asia")
        case .eastAsiaPacific:
            return String(localized: "series.region.eastAsiaPacific", defaultValue: "East Asia & Pacific")
        case .subSaharanAfrica:
            return String(localized: "series.region.subSaharanAfrica", defaultValue: "Sub-Saharan Africa")
        case .westernHemisphere:
            return String(localized: "series.region.westernHemisphere", defaultValue: "Western Hemisphere")
        case .other:
            return String(localized: "series.region.other", defaultValue: "Other / Dependencies")
        }
    }

    /// The regions in stable display order (matches the raw-value ordering).
    static var ordered: [GeographicRegion] { allCases.sorted { $0.rawValue < $1.rawValue } }
}

// MARK: - SeriesGeographyData

/// Pure, deterministic derivation of the FRUS corpus's geographic emphasis from
/// the bundled volume manifest and its place-tag → region map.
///
/// This carries no SwiftUI and depends only on `VolumeManifestEntry` plus a
/// caller-supplied `placeRegions` slug→region map (the view builds that from the
/// tag store, keeping this model pure and unit-testable). All year parsing goes
/// through `FRUSVolumeMetadata.firstYear(in:)`, which extracts the first
/// four-digit run and therefore handles a bare year, an ISO date, and a full ISO
/// datetime identically.
///
/// Place tags are volume-level *editorial* tags: a volume "touches" a region if
/// it carries any place tag mapped to that region. A volume commonly touches
/// several regions. Two attribution schemes coexist here:
///
///   - **Overlap counts** (`regionTotals`): a volume touching *k* regions counts
///     once in each of those *k* regions.
///   - **Fractional attribution** (`regionShareByDecade`): a volume touching *k*
///     regions contributes `1/k` to *each* of its regions, so summing a
///     decade's per-region contributions and dividing by the count of
///     region-bearing volumes in that decade yields shares that sum to `1.0` — a
///     clean partition per decade. Volumes with no region are excluded from the
///     shares (but counted in `volumesWithoutRegion`).
///
/// A volume's decade is the decade of its coverage midpoint: the midpoint of
/// `firstYear(earliest)…firstYear(latest)`, floored to the decade.
///
/// Version history:
///   1.0 — Analytics SA-2: initial implementation
///   1.1 — Analytics SA (x-axis bounds): `regionShareByDecade(in:)` year-range
///          filter for the editable dashboard year range
struct SeriesGeographyData: Sendable {

    // MARK: Point types

    /// One region's fractional share within one coverage decade — a stacked-area
    /// datum. Shares within a decade sum to `1.0` across the ordered regions.
    struct RegionDecadeShare: Identifiable, Sendable, Hashable {
        /// The coverage decade (e.g. `1940` for the 1940s).
        let decade: Int
        /// The region this share is for.
        let region: GeographicRegion
        /// The region's fractional share of the decade, in `0.0...1.0`.
        let share: Double

        var id: String { "\(decade)-\(region.rawValue)" }
    }

    /// One region's overall overlap count — a bar-chart datum.
    struct RegionTotal: Identifiable, Sendable, Hashable {
        /// The region.
        let region: GeographicRegion
        /// How many volumes touch this region (a volume touching several
        /// regions is counted in each).
        let volumeCount: Int

        var id: Int { region.rawValue }
    }

    /// One place tag's volume count — a bar-chart datum for the most-covered
    /// countries.
    struct CountryCount: Identifiable, Sendable, Hashable {
        /// The place-tag slug (stable id).
        let slug: String
        /// How many volumes carry this place tag.
        let volumeCount: Int

        var id: String { slug }
    }

    // MARK: Derived collections

    /// Per-decade, per-region fractional shares (the stacked-area trend). Sorted
    /// ascending by decade, then by region display order. Within each decade the
    /// shares sum to `1.0` (subject to floating-point rounding); a region absent
    /// from a decade simply has no row.
    let regionShareByDecade: [RegionDecadeShare]

    /// Overall region overlap counts, in stable region display order (only
    /// regions with at least one volume are included).
    let regionTotals: [RegionTotal]

    /// Top place tags by volume count, descending, ties broken by slug for
    /// determinism. Length capped at `topCountryLimit`.
    let topCountries: [CountryCount]

    // MARK: Stats

    /// Total number of manifest entries considered.
    let totalVolumes: Int
    /// How many entries touch at least one region.
    let volumesWithAnyRegion: Int
    /// How many entries carry place tags but no region (all `.other`/unmapped),
    /// or no place tags at all — excluded from the stacked shares.
    let volumesWithoutRegion: Int
    /// Earliest coverage decade present, or `nil` when none is computable.
    let earliestDecade: Int?
    /// Latest coverage decade present, or `nil` when none is computable.
    let latestDecade: Int?

    // MARK: Init

    /// The maximum number of entries kept in `topCountries`.
    static let topCountryLimit = 15

    /// Computes every derived collection and statistic from manifest entries and
    /// a place-tag → region map.
    ///
    /// Empty input (or a map that resolves no volume to a region) yields empty
    /// collections and `nil` decade bounds — never a crash or a divide-by-zero.
    ///
    /// - Parameters:
    ///   - entries: The volume manifest entries to summarise.
    ///   - placeRegions: A map from place-tag slug to its `GeographicRegion`. A
    ///     tag slug absent from the map contributes no region; a slug mapped to
    ///     `.other` counts as `.other`.
    init(entries: [VolumeManifestEntry], placeRegions: [String: GeographicRegion]) {
        totalVolumes = entries.count

        // Per-decade fractional contribution sums, and per-decade counts of
        // region-bearing volumes (the divisor).
        var contributionByDecadeRegion: [Int: [GeographicRegion: Double]] = [:]
        var regionBearingVolumesByDecade: [Int: Int] = [:]

        // Overlap counts per region.
        var overlapByRegion: [GeographicRegion: Int] = [:]

        // Per-slug volume counts (only slugs that appear in placeRegions, i.e.
        // recognised place tags — the concrete detail behind the regions).
        var countBySlug: [String: Int] = [:]

        var withAnyRegion = 0
        var withoutRegion = 0

        for entry in entries {
            // The distinct regions this volume touches, via its place-tag slugs.
            var regions: Set<GeographicRegion> = []
            for slug in entry.tags {
                guard let region = placeRegions[slug] else { continue }
                regions.insert(region)
                countBySlug[slug, default: 0] += 1
            }

            // Overlap counts: each touched region gets +1.
            for region in regions {
                overlapByRegion[region, default: 0] += 1
            }

            if regions.isEmpty {
                withoutRegion += 1
                continue
            }
            withAnyRegion += 1

            // Fractional attribution needs a coverage decade.
            guard let decade = Self.coverageDecade(for: entry) else { continue }
            regionBearingVolumesByDecade[decade, default: 0] += 1
            let fraction = 1.0 / Double(regions.count)
            for region in regions {
                contributionByDecadeRegion[decade, default: [:]][region, default: 0] += fraction
            }
        }

        volumesWithAnyRegion = withAnyRegion
        volumesWithoutRegion = withoutRegion

        // ── Region shares by decade ─────────────────────────────────────────
        var shares: [RegionDecadeShare] = []
        for decade in contributionByDecadeRegion.keys.sorted() {
            let divisor = regionBearingVolumesByDecade[decade] ?? 0
            guard divisor > 0 else { continue }
            let contributions = contributionByDecadeRegion[decade] ?? [:]
            for region in GeographicRegion.ordered {
                guard let sum = contributions[region], sum > 0 else { continue }
                shares.append(
                    RegionDecadeShare(
                        decade: decade,
                        region: region,
                        share: sum / Double(divisor)
                    )
                )
            }
        }
        regionShareByDecade = shares

        // ── Region totals (overlap) ─────────────────────────────────────────
        regionTotals = GeographicRegion.ordered.compactMap { region in
            guard let count = overlapByRegion[region], count > 0 else { return nil }
            return RegionTotal(region: region, volumeCount: count)
        }

        // ── Top countries ───────────────────────────────────────────────────
        topCountries = countBySlug
            .map { CountryCount(slug: $0.key, volumeCount: $0.value) }
            .sorted {
                $0.volumeCount != $1.volumeCount
                    ? $0.volumeCount > $1.volumeCount
                    : $0.slug < $1.slug
            }
            .prefix(Self.topCountryLimit)
            .map { $0 }

        // ── Decade bounds ───────────────────────────────────────────────────
        let decades = regionBearingVolumesByDecade.keys.sorted()
        earliestDecade = decades.first
        latestDecade = decades.last
    }

    /// `regionShareByDecade` restricted to rows whose *decade* falls within
    /// `domain` — the range filter for the (coverage-valued) stacked-area trend.
    ///
    /// A decade is kept when the decade value itself lies in the inclusive range,
    /// so a `1861...1993` domain drops any stray pre-1861 retrospective decade
    /// (e.g. the 1740s bucket) while keeping every real decade.
    ///
    /// - Parameter domain: The inclusive coverage-year range to keep decades within.
    /// - Returns: The in-range decade shares, order preserved.
    func regionShareByDecade(in domain: ClosedRange<Int>) -> [RegionDecadeShare] {
        regionShareByDecade.filter { domain.contains($0.decade) }
    }

    /// The coverage-midpoint decade for one volume, or `nil` when neither
    /// endpoint parses.
    ///
    /// Uses `firstYear(earliest)` and `firstYear(latest)`; when only one
    /// endpoint parses it stands in for both. The midpoint is the integer
    /// average of the two years, floored to the decade.
    ///
    /// - Parameter entry: The volume manifest entry.
    /// - Returns: The coverage decade (e.g. `1940`), or `nil`.
    static func coverageDecade(for entry: VolumeManifestEntry) -> Int? {
        let earliest = FRUSVolumeMetadata.firstYear(in: entry.dateRange.earliest)
        let latest = FRUSVolumeMetadata.firstYear(in: entry.dateRange.latest)
        // Fall back to whichever endpoint exists when only one parses.
        guard let start = earliest ?? latest, let end = latest ?? earliest else {
            return nil
        }
        let midpoint = (start + end) / 2
        return (midpoint / 10) * 10
    }
}
