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
/// - `DEPTH` — `seriesOnly` (default) or `all`. `all` additionally harvests **file units and
///   items**: ~934,000 records the app does not read, kept because the harvest is the expensive
///   part and re-running it later to answer a new question would cost the same again. They land
///   in the store as NDJSON and are **never projected into the bundled index**, which stays at
///   collection + series.
/// - `LIBRARIES` — comma-separated prefixes to harvest (default: all eleven).
/// - `OUTPUT` — default `FRUSExplorer/Resources/presidential-library-catalog.json`.
/// - `CACHE_DIR` — default `.cache/presidential-library-catalog`. Raw pages are appended here as
///   NDJSON, one file per (library, level), with a `.cursor` sidecar and a `.done` marker. So a
///   re-run costs nothing, an **interrupted run resumes from its cursor** rather than restarting,
///   and `PROJECT_ONLY=1` rebuilds the index with no network. At `DEPTH=all` this store is
///   hundreds of megabytes — it is a local cache like `nara-record-group-catalog`, not a bundled
///   resource, and it is gitignored.
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

        let depth = env["DEPTH"] ?? "seriesOnly"
        guard ["seriesOnly", "all"].contains(depth) else {
            throw HarvestError("DEPTH must be seriesOnly or all, not \(depth)")
        }
        // The projection only ever reads the first two. The rest are harvested for later use and
        // deliberately not projected — see the type doc for why the app does not want them.
        let levels = depth == "all"
            ? ["collection", "series", "fileUnit", "item"]
            : ["collection", "series"]

        let client = CatalogSearchClient(route: route, apiKey: apiKey)
        var built: [PresidentialLibraryCatalog.Library] = []

        for library in libraries {
            generatorLog("harvesting \(library.prefix)-* (\(library.citedAs))…")
            for level in levels {
                try await harvest(level: level, library: library.prefix, client: client,
                                  cacheDir: cacheDir, projectOnly: projectOnly)
            }
            built.append(project(
                prefix: library.prefix, citedAs: library.citedAs,
                collections: try records(level: "collection", library: library.prefix, cacheDir: cacheDir),
                series: try records(level: "series", library: library.prefix, cacheDir: cacheDir)))
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

    /// Harvests one level for one library into the store, resuming an interrupted run.
    ///
    /// Nothing is held in memory: pages are appended as NDJSON as they arrive. The `.done`
    /// marker is written only after the completeness check passes, so a store without one is
    /// known-partial rather than ambiguously so.
    static func harvest(level: String, library: String, client: CatalogSearchClient,
                        cacheDir: URL, projectOnly: Bool) async throws {
        let store = LevelStore(cacheDir: cacheDir, library: library, level: level)
        if store.isComplete { return }
        guard !projectOnly else {
            throw HarvestError(
                "PROJECT_ONLY=1 but \(library)/\(level) is not completely cached — run the harvest")
        }
        let resume = store.savedCursor
        if resume != nil { generatorLog("  \(library)/\(level): resuming from a saved cursor") }
        let have = resume == nil ? 0 : try store.count()
        if resume == nil { try store.reset() }
        try await client.streamRecords(collectionIdentifier: "\(library)-*", level: level,
                                       resumeAfter: resume, alreadyHave: have) { page, next in
            try store.append(page, cursor: next)
        }
        try store.markComplete()
        generatorLog("  \(library)/\(level): \(try store.count()) records")
    }

    /// The stored records for one level. Only ever called for `collection` and `series`; the
    /// deeper levels stay on disk.
    static func records(level: String, library: String, cacheDir: URL) throws -> [[String: Any]] {
        try LevelStore(cacheDir: cacheDir, library: library, level: level).load()
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
