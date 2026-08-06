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
        let projectOnly = env["PROJECT_ONLY"] == "1"
        // A re-projection reads the store and touches no network, so demanding a key for it made
        // the documented "rebuild offline, so a wrong projection costs seconds rather than a
        // re-harvest" path impossible to actually take.
        guard projectOnly || !route.needsKey || (apiKey?.isEmpty == false) else {
            throw HarvestError(
                "CATALOG_API_KEY is required for the v2 route. Set it, or pass PUBLIC_PROXY=1 to "
                + "use the keyless website endpoint (see CatalogRoute.publicProxy).")
        }
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
        var unplaced: [String: [Int]] = [:]

        for library in libraries {
            generatorLog("harvesting \(library.prefix)-* (\(library.citedAs))…")
            for level in levels {
                try await harvest(level: level, library: library.prefix, client: client,
                                  cacheDir: cacheDir, projectOnly: projectOnly)
            }
            let projected = project(
                prefix: library.prefix, citedAs: library.citedAs,
                collections: try records(level: "collection", library: library.prefix, cacheDir: cacheDir),
                series: try records(level: "series", library: library.prefix, cacheDir: cacheDir))
            built.append(projected.library)
            unplaced[library.prefix] = projected.unplaced
        }

        let catalog = PresidentialLibraryCatalog(
            schemaVersion: schemaVersion,
            generated: generatorDateStamp(override: env["GENERATED_DATE"]),
            source: route.rawValue,
            libraries: built)
        try write(catalog, to: output)
        report(catalog, unplaced: unplaced)
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
    /// ## Keyed on the parent's NAID, not its identifier
    /// A `collectionIdentifier` is **not unique**: measured over the full harvest, 22 of them
    /// name two collection records each. `HH-BDN` is two accessions of the Bradley DeLamater
    /// Nash Papers — NAID 872174 with three series, NAID 17408503 with one — and keying by
    /// identifier gave *both* entries all four, emitting 55 series twice and making NARA's
    /// perfectly correct counts read as `4/3` and `4/1`.
    ///
    /// The ancestry carries the parent's `naId` beside its identifier, which disambiguates
    /// exactly. The identifier survives only as a fallback for a record whose ancestry omits it.
    ///
    /// - Returns: the library, and the NAIDs of harvested series that could not be placed —
    ///   accounted for rather than dropped. Silently losing them is how 16 series vanished from
    ///   a harvest whose own level-total check had passed.
    static func project(prefix: String, citedAs: String,
                        collections: [[String: Any]], series: [[String: Any]])
    -> (library: PresidentialLibraryCatalog.Library, unplaced: [Int]) {
        var byParentNaId: [Int: [PresidentialLibraryCatalog.Series]] = [:]
        var byIdentifier: [String: [PresidentialLibraryCatalog.Series]] = [:]
        var seen = Set<Int>()
        for record in series {
            guard let naId = record["naId"] as? Int, let title = record["title"] as? String,
                  seen.insert(naId).inserted else { continue }
            let entry = PresidentialLibraryCatalog.Series(
                naId: naId, title: title, inclusiveDates: dateSpan(record))
            if let parent = collectionAncestor(of: record) {
                byParentNaId[parent, default: []].append(entry)
            } else if let identifier = collectionIdentifier(ofDescendant: record) {
                byIdentifier[identifier, default: []].append(entry)
            }
        }
        var placed = Set<Int>()
        let built = collections.compactMap { record -> PresidentialLibraryCatalog.Collection? in
            guard let identifier = record["collectionIdentifier"] as? String,
                  let naId = record["naId"] as? Int,
                  let title = record["title"] as? String else { return nil }
            // A collection takes the series naming it by NAID, plus any that named only its
            // identifier — and that bucket is *consumed*, so two collections sharing one
            // identifier cannot both claim it.
            var mine = byParentNaId[naId] ?? []
            if let loose = byIdentifier.removeValue(forKey: identifier) { mine.append(contentsOf: loose) }
            mine.forEach { placed.insert($0.naId) }
            return .init(identifier: identifier, title: title, naId: naId,
                         statedSeriesCount: record["seriesCount"] as? Int,
                         series: mine.sorted { $0.naId < $1.naId })
        }.sorted { $0.identifier < $1.identifier }
        return (.init(prefix: prefix, citedAs: citedAs, collections: built),
                seen.subtracting(placed).sorted())
    }

    /// The NAID of a record's collection-level ancestor, when its ancestry names one.
    static func collectionAncestor(of record: [String: Any]) -> Int? {
        guard let ancestors = record["ancestors"] as? [[String: Any]] else { return nil }
        for ancestor in ancestors
        where (ancestor["levelOfDescription"] as? String) == "collection" {
            if let naId = ancestor["naId"] as? Int { return naId }
        }
        return nil
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
    static func report(_ catalog: PresidentialLibraryCatalog, unplaced: [String: [Int]]) {
        var collections = 0, series = 0, distinct = Set<Int>()
        var fewer: [String] = [], more: [String] = []
        for library in catalog.libraries {
            collections += library.collections.count
            for collection in library.collections {
                series += collection.series.count
                collection.series.forEach { distinct.insert($0.naId) }
                guard let stated = collection.statedSeriesCount,
                      stated != collection.series.count else { continue }
                let line = "\(collection.identifier) (\(collection.series.count)/\(stated))"
                // Both directions are NARA's stated figure disagreeing with NARA's catalogue, and
                // neither implicates this projection: duplication is caught by the
                // distinct-vs-emitted check below, a dropped series by the unplaced one. Verified
                // for FDR-MORGEN (25/24) — one collection record, stated 24, and 25 series
                // genuinely naming it as their collection ancestor.
                if collection.series.count < stated { fewer.append(line) } else { more.append(line) }
            }
        }
        generatorLog("libraries \(catalog.libraries.count) · collections \(collections) "
                     + "· series \(series)")
        // A series belongs to exactly one collection, so emitted must equal distinct. A gap means
        // the projection attached one to more than one entry.
        if series != distinct.count {
            generatorLog("PROJECTION BUG: emitted \(series) series but only \(distinct.count) are "
                         + "distinct — \(series - distinct.count) attached to more than one "
                         + "collection")
        }
        let lost = unplaced.filter { !$0.value.isEmpty }
        if !lost.isEmpty {
            let n = lost.values.reduce(0) { $0 + $1.count }
            generatorLog("UNPLACED: \(n) harvested series name a collection that was not "
                         + "harvested, so they are absent from the index — "
                         + lost.map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: " "))
        }
        if !more.isEmpty {
            generatorLog("over NARA's stated seriesCount (NARA's count is stale; the catalogue "
                         + "holds more than it claims): \(more.count) — "
                         + "\(more.prefix(8).joined(separator: ", "))")
        }
        if fewer.isEmpty && more.isEmpty {
            generatorLog("completeness: every collection matches NARA's own seriesCount")
        } else if !fewer.isEmpty {
            generatorLog("completeness: \(fewer.count) collection(s) short of NARA's stated "
                         + "seriesCount — \(fewer.prefix(8).joined(separator: ", "))")
            generatorLog("  (collections NARA describes but has not fully catalogued; a paging "
                         + "failure would have thrown instead of reaching this line)")
        }
    }
}
