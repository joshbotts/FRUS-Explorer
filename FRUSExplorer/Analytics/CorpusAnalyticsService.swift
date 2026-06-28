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

/// Document frequency broken down by individual FRUS volume.
///
/// `volumeId` is the full volume identifier (e.g. `frus1969-76v01`). The display
/// label (the human-readable volume title) is resolved by the view from the
/// manifest — only the ID and count are computed here. Volumes in which the query
/// term does not appear are omitted entirely, mirroring `SubseriesFrequency`.
///
/// Version history:
///   1.0 — Session 163: initial implementation (By-Volume analytics axis)
struct VolumeFrequency: Sendable, Identifiable {
    let volumeId: String
    let count: Int
    var id: String { volumeId }
}

/// A term and its occurrence count within a scope (year, subseries, etc.).
///
/// Version history:
///   1.0 — Session 98: initial implementation
struct TermCount: Sendable, Identifiable, Codable {
    let term: String
    let count: Int
    var id: String { term }
}

/// Document frequency aggregated into ten-year buckets (1860s, 1870s, …).
///
/// The decade is the year floored to the nearest ten: a document dated 1973
/// is counted under `decadeStart = 1970`. Documents whose date cannot be
/// resolved to a year are excluded.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct DecadeFrequency: Sendable, Identifiable {
    /// The first calendar year of the ten-year bucket (e.g. `1960` for the 1960s).
    let decadeStart: Int
    let count: Int
    var id: Int { decadeStart }
}

/// Document frequency aggregated per calendar month.
///
/// Documents whose `date_iso` lacks a month component (e.g. only `"1969"`) are
/// excluded — they cannot be placed in a specific month bucket.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct MonthFrequency: Sendable, Identifiable {
    /// First day of the month, used for Swift Charts date-axis positioning.
    let date: Date
    /// Display label in `yyyy-MM` form (e.g. `"1969-02"`).
    let label: String
    let count: Int
    var id: String { label }
}

/// Document frequency aggregated per calendar day.
///
/// Documents whose `date_iso` lacks a day component (e.g. only `"1969-02"` or
/// only `"1969"`) are excluded — they cannot be placed on a specific day.
///
/// Version history:
///   1.0 — Session 121: initial implementation
struct DayFrequency: Sendable, Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

/// Snapshot of an `AnalyticsView` query, used to hand a term and date window
/// off between Corpus Analytics and Search.
///
/// ## Cross-view handoff
/// This struct mirrors the role `SearchParameters` plays for `pendingSearch`:
/// a lightweight, `Sendable`/`Equatable` value placed on `AppState.pendingAnalytics`
/// that the destination view observes, applies, and clears.
///
/// - `Search → Analytics` (Direction B): when a search hits `SearchViewModel
///   .searchHardLimit`, `SearchView` offers to open Analytics seeded with the
///   submitted keywords (and the active date filter, if any) so the user can
///   visualize the result distribution over time and pick a narrower range.
/// - `Analytics → Search` (Direction A): `AnalyticsView` offers to jump to
///   Search pre-filled with `committedTerm` and the current year-range filter
///   (via `SearchParameters`, not this type) so the user can see the matching
///   documents directly.
///
/// `yearRangeStart`/`yearRangeEnd` are plain integer years — `AnalyticsView`
/// stores its range that way — and are converted to `DateRange`'s ISO strings
/// only when building `SearchParameters` for the reverse handoff.
///
/// ## Word Cloud → Analytics scope
/// `scopeVolumeIds` carries an optional volume-ID scope used by the
/// `WordCloud → Analytics` handoff: tapping a word in a volume- or subseries-scoped
/// cloud opens Analytics restricted to those volumes (`scopeLabel` names the scope
/// for the UI). Scopes Corpus Analytics cannot express at volume granularity
/// (a single document, a collection, a user tag, a saved search) fall back to the
/// whole corpus — `scopeVolumeIds == nil` — per the cross-surface contract.
///
/// Version history:
///   1.0 — Session 2026-06-07: introduced for Search ↔ Analytics integration
///   1.1 — Session 164: `scopeVolumeIds` / `scopeLabel` for the Word Cloud → Analytics
///          handoff (volume / subseries scope, with whole-corpus fallback)
struct AnalyticsParameters: Sendable, Equatable {
    /// The keyword term to chart. Required — `AnalyticsView.runSearch()` is a
    /// no-op for an empty term.
    var term: String

    /// Optional lower bound for the chart's year-range filter. When `nil`,
    /// `AnalyticsView` keeps its default (1861).
    var yearRangeStart: Int?

    /// Optional upper bound for the chart's year-range filter. When `nil`,
    /// `AnalyticsView` keeps its default (current calendar year).
    var yearRangeEnd: Int?

    /// Optional volume-ID scope. When non-empty, Corpus Analytics restricts every
    /// count to documents in these volumes (the Word Cloud → Analytics handoff for
    /// volume / subseries scopes). `nil` or empty means the whole indexed corpus.
    var scopeVolumeIds: [String]?

    /// Human-readable label for the active scope (e.g. a volume or subseries title),
    /// surfaced in the Analytics UI so the user knows the counts are scoped. `nil`
    /// for a corpus-wide query.
    var scopeLabel: String?

    /// Creates a parameter snapshot to seed `AnalyticsView`.
    init(term: String, yearRangeStart: Int? = nil, yearRangeEnd: Int? = nil,
         scopeVolumeIds: [String]? = nil, scopeLabel: String? = nil) {
        self.term = term
        self.yearRangeStart = yearRangeStart
        self.yearRangeEnd = yearRangeEnd
        self.scopeVolumeIds = scopeVolumeIds
        self.scopeLabel = scopeLabel
    }
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
/// - `termFrequencyByVolume(term:)` — matching docs per individual volume (volume ID)
/// - `topTermsByYear(year:limit:)` — stub; returns empty array (FTS5 vocabulary
///   tables are implementation-specific and not available in the current schema)
///
/// Version history:
///   1.0 — Session 98: initial implementation
///   1.1 — Session 119: `termFrequencyByYear` now uses per-document `date_iso`
///          from `IndexingPipeline.allDocumentDates()` instead of bucketing by
///          volume start year; `pipeline` dependency added; `documentDateCache`
///          lazy-populated and cleared with other caches on `invalidateCache()`
///   1.2 — Session 121: add `termFrequencyByDecade`, `termFrequencyByMonth`, and
///          `termFrequencyByDay`; new `DecadeFrequency`/`MonthFrequency`/`DayFrequency`
///          result types; multi-word queries are now split on whitespace and ANDed
///          (each word individually Porter-stemmed) rather than treated as a single
///          opaque keyword
///   1.3 — Session 163: add `termFrequencyByVolume` (and `VolumeFrequency`) for the
///          By-Volume analytics axis; mirrors `termFrequencyBySubseries` but buckets
///          by full volume ID. New `volumeFrequencyCache` cleared in `invalidateCache()`.
///   1.4 — Session 163: queries now parse the term with `FTS5InlineQueryParser` (the same
///          parser the main Search box uses) instead of a naive whitespace split, so
///          quoted phrases, `OR`/`NOT`, and wildcards behave identically in Analytics and
///          Search. Fixes analytics over-reporting hits for quoted phrase queries (it had
///          been silently downgrading `"a b"` to a loose `a AND b`).
actor CorpusAnalyticsService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline

    // MARK: - Caches

    private var yearFrequencyCache: [String: [YearFrequency]] = [:]
    private var subseriesFrequencyCache: [String: [SubseriesFrequency]] = [:]
    private var volumeFrequencyCache: [String: [VolumeFrequency]] = [:]
    private var decadeFrequencyCache: [String: [DecadeFrequency]] = [:]
    private var monthFrequencyCache: [String: [MonthFrequency]] = [:]
    private var dayFrequencyCache: [String: [DayFrequency]] = [:]
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
        volumeFrequencyCache.removeAll()
        decadeFrequencyCache.removeAll()
        monthFrequencyCache.removeAll()
        dayFrequencyCache.removeAll()
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

    /// Builds the FTS5 query for an analytics term using the **same** inline-syntax
    /// parser as the main Search box (`FTS5InlineQueryParser`).
    ///
    /// This is what keeps Corpus Analytics and Search in agreement: a quoted
    /// `"defense materials"` becomes an ordered **phrase** match (not a loose AND of
    /// the two words), and `OR` / `NOT` / `term*` / `(grouping)` all behave exactly as
    /// they do in Search. Previously analytics split on whitespace and let
    /// `FTS5Query.sanitizeTerm` strip the quotes, silently downgrading every phrase to
    /// an AND — so analytics over-reported hits relative to Search for any quoted query.
    ///
    /// Returns `nil` when `term` carries no positive search content (empty, or only
    /// excluded terms), mirroring `SearchService`.
    nonisolated private static func makeQuery(from term: String) -> FTS5Query? {
        guard let expression = FTS5InlineQueryParser.parse(term) else { return nil }
        return FTS5Query(keywordExpression: expression)
    }

    /// Helper for the four date-bucketed methods. Returns the matched
    /// `(documentId, volumeId)` keys for the given term along with the cached
    /// document-date dictionary. Returns nil if `term` contains no searchable
    /// keywords.
    ///
    /// - Parameters:
    ///   - term: The keyword term, parsed with `FTS5InlineQueryParser`.
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only keys whose
    ///     `volumeId` is in the set are returned (the Word Cloud → Analytics scope).
    private func matchedDocsAndDates(term: String, volumeIds: Set<String>? = nil) async throws
        -> (keys: [(documentId: String, volumeId: String)], dates: [String: String])?
    {
        guard let query = Self.makeQuery(from: term) else { return nil }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }
        let dates = try await resolvedDocumentDates()
        return (keys, dates)
    }

    /// Builds the in-memory cache key for a query, folding in any volume-ID scope so
    /// scoped and corpus-wide results never collide. A corpus-wide query (`nil` or
    /// empty scope) keys on the bare term, preserving existing unscoped cache entries.
    ///
    /// - Parameters:
    ///   - term: The query term.
    ///   - volumeIds: The active volume-ID scope, or `nil`/empty for the whole corpus.
    /// - Returns: A stable cache key unique to the `(term, scope)` pair.
    private func scopedCacheKey(term: String, volumeIds: Set<String>?) -> String {
        guard let volumeIds, !volumeIds.isEmpty else { return term }
        return term + "\u{1}" + volumeIds.sorted().joined(separator: "|")
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
    /// - Parameters:
    ///   - term: A single keyword to search (no FTS5 operators).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted (the Word Cloud → Analytics handoff scope).
    /// - Returns: Array of `YearFrequency` sorted by `year` ascending.
    func termFrequencyByYear(term: String, volumeIds: Set<String>? = nil) async throws -> [YearFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = yearFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

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

    /// Returns the count of documents matching `term`, grouped into ten-year
    /// decade buckets.
    ///
    /// Each year is floored to the nearest ten — 1973 → 1970 — and counts are
    /// summed within the resulting bucket. Documents with no parseable year
    /// (neither in `date_iso` nor in the volume ID) are silently omitted.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords. Multiple keywords are
    ///     AND-combined and individually Porter-stemmed (matching the main search
    ///     behaviour).
    ///   - volumeIds: Optional volume-ID scope, forwarded to `termFrequencyByYear`.
    /// - Returns: Array of `DecadeFrequency` sorted by `decadeStart` ascending.
    func termFrequencyByDecade(term: String, volumeIds: Set<String>? = nil) async throws -> [DecadeFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = decadeFrequencyCache[cacheKey] { return cached }

        // Reuse the per-year computation rather than re-walking the FTS5 result set.
        let yearData = try await termFrequencyByYear(term: term, volumeIds: volumeIds)
        var bucket: [Int: Int] = [:]
        for entry in yearData {
            let decade = (entry.year / 10) * 10
            bucket[decade, default: 0] += entry.count
        }
        let result = bucket
            .map { DecadeFrequency(decadeStart: $0.key, count: $0.value) }
            .sorted { $0.decadeStart < $1.decadeStart }

        insertIntoCache(&decadeFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped per calendar month.
    ///
    /// Documents whose `date_iso` lacks a month component (e.g. `"1969"`) are
    /// excluded — they cannot be placed in a specific month. There is no fallback
    /// to the volume start year here because the granularity demands month-level
    /// precision that volume IDs do not encode.
    ///
    /// Results are sorted by date ascending.
    ///
    /// - Parameters:
    ///   - term: One or more keywords (parsed identically to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    func termFrequencyByMonth(term: String, volumeIds: Set<String>? = nil) async throws -> [MonthFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = monthFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        var counts: [String: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            guard let iso = dates[compositeKey], iso.count >= 7 else { continue }
            // Require a literal "yyyy-MM" prefix with a parseable two-digit month.
            let parts = iso.split(separator: "-")
            guard parts.count >= 2,
                  let year  = Int(parts[0]),
                  let month = Int(parts[1]),
                  (1...12).contains(month),
                  year > 0
            else { continue }
            let label = String(format: "%04d-%02d", year, month)
            counts[label, default: 0] += 1
        }

        let calendar = Calendar(identifier: .gregorian)
        let result: [MonthFrequency] = counts.compactMap { (label, count) in
            let parts = label.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1])
            else { return nil }
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let date = calendar.date(from: comps) else { return nil }
            return MonthFrequency(date: date, label: label, count: count)
        }.sorted { $0.date < $1.date }

        insertIntoCache(&monthFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped per calendar day.
    ///
    /// Documents whose `date_iso` is not a full `yyyy-MM-dd` are excluded.
    /// Results are sorted by date ascending. Note: for high-frequency terms
    /// spanning many decades this returns a very large number of points; callers
    /// should restrict the displayed range via the year-range filter.
    ///
    /// - Parameters:
    ///   - term: One or more keywords (parsed identically to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    func termFrequencyByDay(term: String, volumeIds: Set<String>? = nil) async throws -> [DayFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = dayFrequencyCache[cacheKey] { return cached }

        guard let (keys, dates) = try await matchedDocsAndDates(term: term, volumeIds: volumeIds) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        var counts: [Date: Int] = [:]
        for key in keys {
            let compositeKey = "\(key.volumeId)/\(key.documentId)"
            guard let iso = dates[compositeKey],
                  iso.count == 10,
                  let date = formatter.date(from: iso)
            else { continue }
            counts[date, default: 0] += 1
        }

        let result = counts
            .map { DayFrequency(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }

        insertIntoCache(&dayFrequencyCache, key: cacheKey, value: result)
        return result
    }

    /// Returns the count of documents matching `term`, grouped by subseries.
    ///
    /// Results are sorted by subseries string ascending. Documents in volumes
    /// whose IDs cannot be parsed are silently omitted.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords (AND-combined).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    /// - Returns: Array of `SubseriesFrequency` sorted by `subseries` ascending.
    func termFrequencyBySubseries(term: String, volumeIds: Set<String>? = nil) async throws -> [SubseriesFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = subseriesFrequencyCache[cacheKey] { return cached }

        guard let query = Self.makeQuery(from: term) else { return [] }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }

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

    /// Returns the count of documents matching `term`, grouped by individual volume.
    ///
    /// Results are sorted by volume ID ascending. Volumes in which the term never
    /// appears are omitted (the same zero-omission behaviour as
    /// `termFrequencyBySubseries`). The caller resolves each `volumeId` to a display
    /// title via the manifest.
    ///
    /// - Parameters:
    ///   - term: One or more whitespace-separated keywords (AND-combined,
    ///     individually Porter-stemmed — identical handling to the other axes).
    ///   - volumeIds: Optional volume-ID scope; when non-empty, only documents in
    ///     these volumes are counted.
    /// - Returns: Array of `VolumeFrequency` sorted by `volumeId` ascending.
    func termFrequencyByVolume(term: String, volumeIds: Set<String>? = nil) async throws -> [VolumeFrequency] {
        let cacheKey = scopedCacheKey(term: term, volumeIds: volumeIds)
        if let cached = volumeFrequencyCache[cacheKey] { return cached }

        guard let query = Self.makeQuery(from: term) else { return [] }
        var keys = try await fts5Store.matchedDocumentKeys(query: query)
        if let volumeIds, !volumeIds.isEmpty {
            keys = keys.filter { volumeIds.contains($0.volumeId) }
        }

        var counts: [String: Int] = [:]
        for key in keys {
            counts[key.volumeId, default: 0] += 1
        }

        let result = counts
            .map { VolumeFrequency(volumeId: $0.key, count: $0.value) }
            .sorted { $0.volumeId < $1.volumeId }

        insertIntoCache(&volumeFrequencyCache, key: cacheKey, value: result)
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
