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
/// 50 entries per cache dictionary. The full `document_dates` table is
/// fetched once from `IndexingPipeline` and cached in `documentDateCache`;
/// it is cleared alongside the other caches when `invalidateCache()` is
/// called (e.g. after a volume is indexed or deleted).
///
/// ## Year bucketing
/// `termFrequencyByYear(term:)` groups results by the **actual date** of
/// each matching document, taken from the `date_iso` column of the
/// `document_dates` auxiliary table (e.g. `"1969-02-15"` → year 1969).
/// Documents with no stored date fall back to the start year of their
/// volume ID. This replaces the previous approach of bucketing every
/// document in a volume under the volume's start year.
///
/// ## Volume ID Parsing
/// FRUS volume IDs follow the pattern `frus{subseries}v{number}[suffix]`,
/// for example `frus1969-76v01`. The start year is the first four digits
/// after "frus". The subseries is everything between "frus" and the
/// trailing volume suffix (`v\d+[a-z0-9]*`).
///
/// ## Analytics Coverage
/// - `termFrequencyByYear(term:)` — matching docs per year (actual document date)
/// - `termFrequencyBySubseries(term:)` — matching docs per subseries (volume ID)
/// - `topTermsByYear(year:limit:)` — stub; returns empty array (FTS5 vocabulary
///   tables are implementation-specific and not available in the current schema)
///
/// Version history:
///   1.0 — Session 98: initial implementation
///   1.1 — Session 119: `termFrequencyByYear` now uses per-document `date_iso`
///          from `IndexingPipeline.allDocumentDates()` instead of bucketing by
///          volume start year; `pipeline` dependency added; `documentDateCache`
///          lazy-populated and cleared with other caches on `invalidateCache()`
actor CorpusAnalyticsService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline

    // MARK: - Caches

    private var yearFrequencyCache: [String: [YearFrequency]] = [:]
    private var subseriesFrequencyCache: [String: [SubseriesFrequency]] = [:]
    /// Lazily populated on the first `termFrequencyByYear` call; maps
    /// `"volumeId/documentId"` → `date_iso` string (e.g. `"1969-02-15"`).
    private var documentDateCache: [String: String]? = nil
    private let cacheLimit = 50

    // MARK: - Initialiser

    init(fts5Store: FTS5Store, pipeline: IndexingPipeline) {
        self.fts5Store = fts5Store
        self.pipeline = pipeline
    }

    // MARK: - Cache Management

    /// Flushes all in-memory caches, including the document-date lookup table.
    ///
    /// Call after the FTS5 index has been modified (e.g. a volume was indexed
    /// or deleted) so stale analytics results are not served.
    func invalidateCache() {
        yearFrequencyCache.removeAll()
        subseriesFrequencyCache.removeAll()
        documentDateCache = nil
    }

    // MARK: - Private Helpers

    /// Returns the cached document-date dictionary, fetching it from the
    /// pipeline on first call.
    ///
    /// The dictionary maps `"volumeId/documentId"` → ISO 8601 date string.
    /// Populated once per cache lifetime; cleared by `invalidateCache()`.
    private func resolvedDocumentDates() async throws -> [String: String] {
        if let cached = documentDateCache { return cached }
        let dates = try await pipeline.allDocumentDates()
        documentDateCache = dates
        return dates
    }

    // MARK: - Frequency Queries

    /// Returns the count of documents matching `term`, grouped by year.
    ///
    /// The year for each document is taken from the `date_iso` value stored
    /// in the `document_dates` auxiliary table (the actual document date, e.g.
    /// `"1969-02-15"` → 1969). Documents with no stored date fall back to the
    /// start year parsed from their volume ID. Documents for which neither
    /// source yields a valid year are silently omitted.
    ///
    /// Results are sorted by year ascending.
    ///
    /// - Parameter term: A single keyword to search (no FTS5 operators).
    /// - Returns: Array of `YearFrequency` sorted by `year` ascending.
    func termFrequencyByYear(term: String) async throws -> [YearFrequency] {
        let cacheKey = term
        if let cached = yearFrequencyCache[cacheKey] { return cached }

        let query = FTS5Query(keywords: [term])
        let keys = try await fts5Store.matchedDocumentKeys(query: query)
        let dates = try await resolvedDocumentDates()

        var counts: [Int: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            let year: Int?
            if let iso = dates[compositeKey] {
                // date_iso is "yyyy-MM-dd" or occasionally just "yyyy"; either way
                // the first four characters encode the year.
                year = Int(iso.prefix(4))
            } else {
                // Fall back to volume start year for undated documents.
                year = Self.startYear(fromVolumeId: key.volumeId)
            }
            guard let y = year else { continue }
            counts[y, default: 0] += 1
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
