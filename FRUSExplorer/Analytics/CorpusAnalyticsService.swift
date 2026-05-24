// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Result Types

/// Document frequency broken down by year of origin.
///
/// `year` is the four-digit start year extracted from the volume ID
/// (e.g. `frus1969-76v01` → 1969). Documents whose volume IDs cannot
/// be parsed are omitted.
///
/// Version history:
///   1.0 — Session 98: initial implementation
struct YearFrequency: Sendable, Identifiable {
    let year: Int
    let count: Int
    var id: Int { year }
}

/// Document frequency broken down by FRUS subseries.
///
/// The subseries is the volume ID with the "frus" prefix and trailing
/// `v\d+[a-z0-9]*` volume suffix stripped (e.g. `frus1969-76v01` →
/// `1969-76`). Documents whose volume IDs cannot be parsed are omitted.
///
/// Version history:
///   1.0 — Session 98: initial implementation
struct SubseriesFrequency: Sendable, Identifiable {
    let subseries: String
    let count: Int
    var id: String { subseries }
}

/// A term and its occurrence count within a scope (year, subseries, etc.).
///
/// Version history:
///   1.0 — Session 98: initial implementation
struct TermCount: Sendable, Identifiable {
    let term: String
    let count: Int
    var id: String { term }
}

// MARK: - CorpusAnalyticsService

/// Provides corpus-level frequency analytics over the FTS5 search index.
///
/// All query methods run on the actor's executor (off the main thread),
/// so callers on `@MainActor` automatically get background execution via
/// `await` without needing `Task.detached`.
///
/// ## Caching
/// Results are cached in memory using the query term as key, bounded at
/// 50 entries per cache dictionary. When the underlying index changes
/// (e.g. after a new volume is indexed), call `invalidateCache()` to
/// flush all caches.
///
/// ## Volume ID Parsing
/// FRUS volume IDs follow the pattern `frus{subseries}v{number}[suffix]`,
/// for example `frus1969-76v01`. The start year is the first four digits
/// after "frus". The subseries is everything between "frus" and the
/// trailing volume suffix (`v\d+[a-z0-9]*`).
///
/// ## Analytics Coverage
/// - `termFrequencyByYear(term:)` — how many matching docs per year
/// - `termFrequencyBySubseries(term:)` — how many matching docs per subseries
/// - `topTermsByYear(year:limit:)` — stub; returns empty array (FTS5 vocabulary
///   tables are implementation-specific and not available in the current schema)
///
/// Version history:
///   1.0 — Session 98: initial implementation
actor CorpusAnalyticsService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store

    // MARK: - Caches

    private var yearFrequencyCache: [String: [YearFrequency]] = [:]
    private var subseriesFrequencyCache: [String: [SubseriesFrequency]] = [:]
    private let cacheLimit = 50

    // MARK: - Initialiser

    init(fts5Store: FTS5Store) {
        self.fts5Store = fts5Store
    }

    // MARK: - Cache Management

    /// Flushes all in-memory caches.
    ///
    /// Call after the FTS5 index has been modified (e.g. a volume was indexed
    /// or deleted) so stale analytics results are not served.
    func invalidateCache() {
        yearFrequencyCache.removeAll()
        subseriesFrequencyCache.removeAll()
    }

    // MARK: - Frequency Queries

    /// Returns the count of documents matching `term`, grouped by year.
    ///
    /// Results are sorted by year ascending. Documents in volumes whose IDs
    /// cannot be parsed into a start year are silently omitted.
    ///
    /// - Parameter term: A single keyword to search (no FTS5 operators).
    /// - Returns: Array of `YearFrequency` sorted by `year` ascending.
    func termFrequencyByYear(term: String) async throws -> [YearFrequency] {
        let cacheKey = term
        if let cached = yearFrequencyCache[cacheKey] { return cached }

        let query = FTS5Query(keywords: [term])
        let keys = try await fts5Store.matchedDocumentKeys(query: query)

        var counts: [Int: Int] = [:]
        for key in keys {
            guard let year = Self.startYear(fromVolumeId: key.volumeId) else { continue }
            counts[year, default: 0] += 1
        }

        let result = counts
            .map { YearFrequency(year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }

        insertIntoCache(&yearFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped by subseries.
    ///
    /// Results are sorted by subseries string ascending. Documents in volumes
    /// whose IDs cannot be parsed are silently omitted.
    ///
    /// - Parameter term: A single keyword to search (no FTS5 operators).
    /// - Returns: Array of `SubseriesFrequency` sorted by `subseries` ascending.
    func termFrequencyBySubseries(term: String) async throws -> [SubseriesFrequency] {
        let cacheKey = term
        if let cached = subseriesFrequencyCache[cacheKey] { return cached }

        let query = FTS5Query(keywords: [term])
        let keys = try await fts5Store.matchedDocumentKeys(query: query)

        var counts: [String: Int] = [:]
        for key in keys {
            guard let sub = Self.subseries(fromVolumeId: key.volumeId) else { continue }
            counts[sub, default: 0] += 1
        }

        let result = counts
            .map { SubseriesFrequency(subseries: $0.key, count: $0.value) }
            .sorted { $0.subseries < $1.subseries }

        insertIntoCache(&subseriesFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the most frequent terms in documents published in `year`.
    ///
    /// - Note: This is currently a stub that always returns an empty array.
    ///   Computing per-year term frequencies requires access to FTS5 vocabulary
    ///   shadow tables, which are not available in the current schema.
    ///
    /// - Parameters:
    ///   - year: Four-digit year (e.g. 1969).
    ///   - limit: Maximum number of terms to return.
    /// - Returns: Always `[]` in the current implementation.
    func topTermsByYear(year: Int, limit: Int = 20) async -> [TermCount] {
        return []
    }

    // MARK: - Cache Helpers

    private func insertIntoCache<V>(_ cache: inout [String: V], key: String, value: V) {
        if cache.count >= cacheLimit {
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[key] = value
    }

    // MARK: - Volume ID Parsing

    /// Extracts the four-digit start year from a FRUS volume ID.
    ///
    /// For `frus1969-76v01` this returns `1969`. Returns `nil` if the
    /// volume ID does not begin with "frus" followed by four digits.
    nonisolated static func startYear(fromVolumeId volumeId: String) -> Int? {
        guard volumeId.hasPrefix("frus") else { return nil }
        let afterFrus = volumeId.dropFirst(4)
        let digits = afterFrus.prefix(while: { $0.isNumber })
        guard digits.count == 4, let year = Int(digits) else { return nil }
        return year
    }

    /// Extracts the subseries string from a FRUS volume ID.
    ///
    /// For `frus1969-76v01` this returns `"1969-76"`. Strips the "frus"
    /// prefix and the trailing `v\d+[a-z0-9]*` volume suffix. Returns `nil`
    /// if the volume ID does not begin with "frus" or has no volume suffix.
    nonisolated static func subseries(fromVolumeId volumeId: String) -> String? {
        guard volumeId.hasPrefix("frus") else { return nil }
        let afterFrus = String(volumeId.dropFirst(4))
        // Find the last occurrence of "v" followed by at least one digit.
        guard let range = afterFrus.range(of: #"v\d+[a-z0-9]*$"#, options: .regularExpression) else {
            return nil
        }
        let sub = String(afterFrus[..<range.lowerBound])
        return sub.isEmpty ? nil : sub
    }
}
