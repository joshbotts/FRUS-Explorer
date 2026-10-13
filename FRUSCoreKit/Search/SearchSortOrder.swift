// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchSortOrder

/// Ordering applied to search results, shared by the iOS `SearchView` and the macOS Search window
/// (#305). `relevance` keeps the FTS5 BM25 order as returned; the date orders use the structured
/// `dateISO` value (undated rows last, BM25 tie-break) — see ``sorted(_:)``, which
/// `SearchViewModel.sortedResults` and `MacSearchViewModel.allSortedResults` both return.
///
/// Version history:
///   1.0 — #305: shared by both search surfaces, in the app's `SearchModels.swift`
///   1.1 — FRUS Explorer Light: moved into the kit and public, with the date order each view model
///          kept a copy of as ``sorted(_:)``, for the web edition's list
public enum SearchSortOrder: String, CaseIterable, Sendable {
    case relevance
    case dateAscending
    case dateDescending

    /// Short control label.
    public var label: String {
        switch self {
        case .relevance:      return String(localized: "search.sort.relevance", defaultValue: "Relevance")
        case .dateAscending:  return String(localized: "search.sort.dateAscending", defaultValue: "Date ↑")
        case .dateDescending: return String(localized: "search.sort.dateDescending", defaultValue: "Date ↓")
        }
    }

    /// `results` in this order.
    ///
    /// Date sorting uses the structured `dateISO` value (`yyyy-MM-dd`, from
    /// `document_dates.date_iso`) — NOT the raw `dateline` string, which begins
    /// with a place name and a textual month and therefore cannot be sorted
    /// chronologically. Documents without a stored date are pushed to the **end**
    /// of the list in both ascending and descending order so the dated stream
    /// remains contiguous (mirrors history.state.gov's `empty greatest`/`empty
    /// least` XQuery behaviour).
    ///
    /// Ties on the ISO date are broken by BM25 score (more relevant first) so
    /// the order within a single day is stable and meaningful.
    public func sorted(_ results: [SearchResult]) -> [SearchResult] {
        switch self {
        case .relevance:      return results
        case .dateAscending:  return results.sorted { Self.dateOrder($0, $1, ascending: true) }
        case .dateDescending: return results.sorted { Self.dateOrder($0, $1, ascending: false) }
        }
    }

    /// Tuple comparator for date-asc / date-desc. Undated rows always go last;
    /// ties are broken by BM25 score (lower is better, so ascending bm25 = more
    /// relevant first).
    static func dateOrder(_ lhs: SearchResult, _ rhs: SearchResult, ascending: Bool) -> Bool {
        switch (lhs.dateISO, rhs.dateISO) {
        case let (a?, b?):
            if a == b { return lhs.bm25Score < rhs.bm25Score }
            return ascending ? a < b : a > b
        case (.some, .none):
            return true                      // lhs dated → comes before undated rhs
        case (.none, .some):
            return false                     // lhs undated → goes after dated rhs
        case (.none, .none):
            return lhs.bm25Score < rhs.bm25Score
        }
    }
}
