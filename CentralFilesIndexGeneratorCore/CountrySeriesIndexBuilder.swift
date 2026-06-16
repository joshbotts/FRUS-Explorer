// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CountrySeriesHarvestResult

/// The built series index plus survey diagnostics from the harvest pass.
public struct CountrySeriesHarvestResult: Sendable, Equatable {
    public let index: CountrySeriesIndex
    /// Total descendant records returned for the series.
    public let totalRecords: Int
    /// Records at the series' resolution level (the candidate rolls).
    public let resolutionRecords: Int
    /// Rolls whose geographic key could not be determined.
    public let rollsWithoutGeo: Int
    /// Rolls whose date range could not be parsed.
    public let rollsWithoutDate: Int
    /// Sample titles whose geo did not resolve (capped).
    public let sampleNoGeo: [String]
    /// Sample titles whose date did not parse (capped).
    public let sampleNoDate: [String]

    public var rollCount: Int { index.rolls.count }
}

// MARK: - CountrySeriesIndexBuilder

/// Builds a `CountrySeriesIndex` from harvested catalog records for one diplomatic series.
///
/// Pure (no I/O): all logic is testable without the network.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2
public enum CountrySeriesIndexBuilder {

    public static func build(
        category: CountrySeriesCategory,
        records: [CatalogRecord],
        maxSamples: Int = 25
    ) -> CountrySeriesHarvestResult {
        var rolls: [CountryRoll] = []
        var seenNaIds = Set<String>()
        var resolutionRecords = 0
        var noGeo: [String] = []
        var noDate: [String] = []

        for record in records {
            guard let parsed = CountrySeriesParser.parse(record, category: category) else { continue }
            guard seenNaIds.insert(record.naId).inserted else { continue }
            resolutionRecords += 1

            if parsed.geoKeys.isEmpty { noGeo.append(record.title) }
            if parsed.dateRange?.startISO == nil && parsed.dateRange?.endISO == nil {
                noDate.append(record.title)
            }

            rolls.append(CountryRoll(
                naId: record.naId,
                title: record.title,
                geoKeys: parsed.geoKeys,
                startISO: parsed.dateRange?.startISO,
                endISO: parsed.dateRange?.endISO,
                catalogURL: NARACatalogHarvestClient.catalogIDBase + record.naId,
                fileUnitNaId: record.parentFileUnitNaId,
                fileUnitTitle: record.parentFileUnitTitle))
        }

        let index = CountrySeriesIndex(
            category: category.rawValue,
            seriesNaId: category.seriesNaId,
            displayName: category.displayName,
            rolls: rolls)

        return CountrySeriesHarvestResult(
            index: index,
            totalRecords: records.count,
            resolutionRecords: resolutionRecords,
            rollsWithoutGeo: noGeo.count,
            rollsWithoutDate: noDate.count,
            sampleNoGeo: Array(noGeo.prefix(maxSamples)),
            sampleNoDate: Array(noDate.prefix(maxSamples)))
    }
}
