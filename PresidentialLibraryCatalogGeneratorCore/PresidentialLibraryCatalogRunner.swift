// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - PresidentialLibraryCatalogRunner

/// Harvests the NARA Catalog's presidential-library collections and series into a bundled
/// offline index (#681).
///
/// ## Environment
/// - `CATALOG_API_KEY` — required unless `PUBLIC_PROXY=1`.
/// - `PUBLIC_PROXY=1` — use the keyless website endpoint instead of the v2 API. See
///   `CatalogRoute.publicProxy` for why that is opt-in.
/// - `LIBRARIES` — comma-separated prefixes to harvest (default: all eleven).
/// - `OUTPUT` — default `FRUSExplorer/Resources/presidential-library-catalog.json`.
/// - `CACHE_DIR` — default `.cache/presidential-library-catalog`. Raw pages land here so a
///   re-run costs nothing and `PROJECT_ONLY=1` can rebuild the index with no network.
/// - `PROJECT_ONLY=1` — rebuild from the cache. The reason a wrong projection costs seconds
///   rather than a re-harvest.
/// - `GENERATED_DATE` — pin the stamp for a reproducible build.
///
/// ## Determinism
/// Libraries in declaration order, collections by identifier, series by NAID, `.sortedKeys` on
/// the encoder. Two runs over the same cache produce byte-identical output.
public enum PresidentialLibraryCatalogRunner {

    public static let schemaVersion = 1

    public static func run() async throws {
        let env = ProcessInfo.processInfo.environment
        let useProxy = env["PUBLIC_PROXY"] == "1"
        let route: CatalogRoute = useProxy ? .publicProxy : .apiV2
        let apiKey = env["CATALOG_API_KEY"]
        guard !route.needsKey || (apiKey?.isEmpty == false) else {
            throw HarvestError(
                "CATALOG_API_KEY is required for the v2 route. Set it, or pass PUBLIC_PROXY=1 to "
                + "use the keyless website endpoint (see CatalogRoute.publicProxy).")
        }
        let projectOnly = env["PROJECT_ONLY"] == "1"
        let cacheDir = URL(fileURLWithPath: env["CACHE_DIR"] ?? ".cache/presidential-library-catalog")
        let output = URL(fileURLWithPath:
            env["OUTPUT"] ?? "FRUSExplorer/Resources/presidential-library-catalog.json")
        let wanted: Set<String>? = env["LIBRARIES"].map {
            Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() })
        }
        let libraries = PresidentialLibraryCatalog.harvestedLibraries
            .filter { wanted?.contains($0.prefix.uppercased()) ?? true }
        guard !libraries.isEmpty else {
            throw HarvestError("LIBRARIES matched none of the known prefixes")
        }
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let client = CatalogSearchClient(route: route, apiKey: apiKey)
        var built: [PresidentialLibraryCatalog.Library] = []

        for library in libraries {
            generatorLog("harvesting \(library.prefix)-* (\(library.citedAs))…")
            let collections = try await fetch(level: "collection", library: library.prefix,
                                              client: client, cacheDir: cacheDir,
                                              projectOnly: projectOnly)
            let series = try await fetch(level: "series", library: library.prefix,
                                         client: client, cacheDir: cacheDir,
                                         projectOnly: projectOnly)
            built.append(project(prefix: library.prefix, citedAs: library.citedAs,
                                 collections: collections, series: series))
        }

        let catalog = PresidentialLibraryCatalog(
            schemaVersion: schemaVersion,
            generated: generatorDateStamp(override: env["GENERATED_DATE"]),
            source: route.rawValue,
            libraries: built)
        try write(catalog, to: output)
        report(catalog)
    }

    // MARK: - Fetch (cached)

    /// One level for one library, from the cache when present.
    static func fetch(level: String, library: String, client: CatalogSearchClient,
                      cacheDir: URL, projectOnly: Bool) async throws -> [[String: Any]] {
        let file = cacheDir.appending(path: "\(library)-\(level).json")
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        }
        guard !projectOnly else {
            throw HarvestError(
                "PROJECT_ONLY=1 but \(file.lastPathComponent) is not cached — run the harvest first")
        }
        let records = try await client.allRecords(collectionIdentifier: "\(library)-*", level: level)
        try JSONSerialization.data(withJSONObject: records).write(to: file)
        return records
    }

    // MARK: - Projection

    /// Groups series under their collection by the ancestry link.
    ///
    /// A series does **not** carry `collectionIdentifier` itself — it carries
    /// `ancestors[].collectionIdentifier`, which is exactly why the live filter works and why
    /// this projection has to read the ancestry rather than the record's own fields. Reading the
    /// top level would silently produce a catalogue of collections with no series under any.
    static func project(prefix: String, citedAs: String,
                        collections: [[String: Any]], series: [[String: Any]])
    -> PresidentialLibraryCatalog.Library {
        var seriesByCollection: [String: [PresidentialLibraryCatalog.Series]] = [:]
        for record in series {
            guard let naId = record["naId"] as? Int,
                  let title = record["title"] as? String,
                  let identifier = collectionIdentifier(ofDescendant: record) else { continue }
            seriesByCollection[identifier, default: []].append(
                .init(naId: naId, title: title, inclusiveDates: dateSpan(record)))
        }
        let built = collections.compactMap { record -> PresidentialLibraryCatalog.Collection? in
            guard let identifier = record["collectionIdentifier"] as? String,
                  let naId = record["naId"] as? Int,
                  let title = record["title"] as? String else { return nil }
            return .init(identifier: identifier, title: title, naId: naId,
                         statedSeriesCount: record["seriesCount"] as? Int,
                         series: (seriesByCollection[identifier] ?? []).sorted { $0.naId < $1.naId })
        }.sorted { $0.identifier < $1.identifier }
        return .init(prefix: prefix, citedAs: citedAs, collections: built)
    }

    /// The collection a descendant record belongs to, read from its ancestry.
    static func collectionIdentifier(ofDescendant record: [String: Any]) -> String? {
        if let own = record["collectionIdentifier"] as? String { return own }
        guard let ancestors = record["ancestors"] as? [[String: Any]] else { return nil }
        return ancestors.compactMap { $0["collectionIdentifier"] as? String }.first
    }

    /// `inclusiveStartDate`/`inclusiveEndDate` rendered as a span, when NARA states them.
    static func dateSpan(_ record: [String: Any]) -> String? {
        func year(_ key: String) -> String? {
            ((record[key] as? [String: Any])?["year"] as? Int).map(String.init)
        }
        switch (year("inclusiveStartDate"), year("inclusiveEndDate")) {
        case let (start?, end?): return start == end ? start : "\(start)–\(end)"
        case let (start?, nil):  return start
        case let (nil, end?):    return end
        default:                 return nil
        }
    }

    // MARK: - Output

    static func write(_ catalog: PresidentialLibraryCatalog, to output: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(catalog).write(to: output)
    }

    /// Prints the completeness check. NARA states each collection's `seriesCount`, so a harvest
    /// that paged short is self-detecting — this is where it gets reported rather than assumed.
    static func report(_ catalog: PresidentialLibraryCatalog) {
        var collections = 0, series = 0, incomplete: [String] = []
        for library in catalog.libraries {
            collections += library.collections.count
            for collection in library.collections {
                series += collection.series.count
                if collection.isComplete == false {
                    incomplete.append("\(collection.identifier) "
                                      + "(\(collection.series.count)/\(collection.statedSeriesCount ?? -1))")
                }
            }
        }
        generatorLog("libraries \(catalog.libraries.count) · collections \(collections) · series \(series)")
        if incomplete.isEmpty {
            generatorLog("completeness: every collection matches NARA's own seriesCount")
        } else {
            generatorLog("completeness: \(incomplete.count) collection(s) short of NARA's stated "
                         + "seriesCount — \(incomplete.prefix(8).joined(separator: ", "))")
        }
    }
}
