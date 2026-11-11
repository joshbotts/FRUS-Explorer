// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsSearchHandoff

/// The search Corpus Analytics' "View N documents ↗" link opens, and the count the link shows
/// (#1756).
///
/// ## One value, both counted and opened
/// The link used to print the chart's own sum: the documents its bars place in the chosen years,
/// each at the year it begins, with an undated document at its volume's first year. The search it
/// opened read the same years by Search's rule — a document whose dates overlap them, and nothing
/// undated — so the two parted wherever a document's dates crossed the range's edge or a volume
/// held undated matches. Over a full index (553 volumes, index v71), *Berlin* over Eisenhower's
/// years read **2,803** on the link, 2,775 documents beginning in 1953–1961 and 28 undated ones in
/// volumes beginning then, and **2,833** in Search: the 2,775 and the 58 that begin before 1953
/// and run into it.
///
/// So the link now prints Search's own count of the very parameters it opens, taken through
/// ``SearchService/matchKeys(parameters:)``, the whole match the result count counts, and the
/// dispersion line beside it is computed from the same keys, so it describes the documents the
/// link opens. The chart's footnote still sums its bars, which can differ from the link by the
/// documents the two rules place differently; the link's tooltip and the manuals say why.
///
/// ## Years only when the reader narrowed them
/// The years go to Search only on a date-based axis whose range the reader moved off its default.
/// At the default range the reader has narrowed nothing, and a date range would have dropped
/// every undated match from the search: *Berlin* across the whole corpus counted 16,126 documents
/// that way, of its 16,273.
///
/// A working corpus applied in Search still narrows the search it opens, under Search's banner
/// (#1646): the link counts the parameters it hands over, which never carry one.
///
/// Version history:
///   1.0 — 2026-10-22: #1756 — initial implementation
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): out of `AnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public
public enum AnalyticsSearchHandoff {

    /// The search the link opens.
    ///
    /// - Parameters:
    ///   - term: The committed term, Search's keywords.
    ///   - axis: The chart's axis; only a date-based axis passes years.
    ///   - startYear: The first year of the chart's range.
    ///   - endYear: The last year of the chart's range.
    ///   - yearsNarrowed: Whether the reader moved the range off its default.
    ///   - scopeVolumeIds: The chart's volume scope, or `nil` for the whole corpus.
    /// - Returns: The parameters, over document text only.
    public static func parameters(term: String, axis: AnalyticsChartAxis, startYear: Int, endYear: Int,
                           yearsNarrowed: Bool, scopeVolumeIds: [String]?) -> SearchParameters {
        let range: DateRange? = axis.isDateBased && yearsNarrowed
            ? DateRange(earliest: String(format: "%04d-01-01", startYear),
                        latest: String(format: "%04d-12-31", endYear))
            : nil
        // #1306: notes and summaries OFF. This link is the one place the app invites a reader to
        // compare a chart's count against Search's, and Search's default scope unions
        // `user_content` — the reader's own summaries and notes — while Analytics runs a bare
        // `frus_documents MATCH`. The scope narrows for this search and stays narrowed, exactly as
        // the date range and the volume scope on the same lines already do.
        return SearchParameters(keywords: term, dateRange: range, volumeIds: scopeVolumeIds,
                                includeSummaries: false, includeNotes: false)
    }

    /// Search's count of one hand-off search.
    public struct Match: Equatable, Sendable {
        /// The search counted.
        public let parameters: SearchParameters
        /// How many documents it lists.
        public let count: Int
        /// How many of them each volume holds, largest first: the dispersion line's input.
        public let volumeCounts: [Int]
    }

    /// Counts `parameters` as Search counts them.
    ///
    /// - Parameters:
    ///   - parameters: The search the link opens.
    ///   - service: The app's search service.
    /// - Returns: The count, and the count in each volume.
    /// - Throws: What ``SearchService/matchKeys(parameters:)`` throws: `CancellationError` when the
    ///   task is cancelled, and `FTS5Error.emptyQuery` for a search Search would refuse.
    public static func match(for parameters: SearchParameters, in service: SearchService) async throws -> Match {
        let keys = try await service.matchKeys(parameters: parameters)
        var perVolume: [Substring: Int] = [:]
        for key in keys {
            perVolume[key.prefix { $0 != "/" }, default: 0] += 1
        }
        return Match(parameters: parameters, count: keys.count,
                     volumeCounts: perVolume.values.sorted(by: >))
    }
}
