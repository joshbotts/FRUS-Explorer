// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SearchHistoryEntry

/// Records a single full-text search execution.
///
/// Created automatically when the user submits a query — in the macOS Search window
/// (`MacSearchViewModel.recordSearchHistory`) or the iOS Search tab
/// (`SearchViewModel.recordSearchHistory`). Mirrors `ReadingHistoryEntry`, which records
/// each document access. The project active at that moment is captured in `projectId`
/// (`nil` if in global context). Search history entries are immutable historical records —
/// a new entry is created each time a distinct query is submitted; re-running the same
/// query because a filter or scope toggle changed does not create a duplicate.
///
/// Both producers are gated on `AppState.isResearchLoggingEnabled`, so nothing is recorded
/// while "Log Research Sessions" is off.
///
/// Surfaced in the macOS "History" menu (last ten queries) and the "Complete
/// History" window (`HistoryWindowView`), both filterable by project, and — on both
/// platforms — in Project Home's "Searches Run" tile and Recent Searches card.
///
/// ## No `lastModified`
/// Search history entries are immutable after creation — like
/// `ReadingHistoryEntry`, no `lastModified` field is present.
///
/// Version history:
///   1.0 — Session 2026-06-07: initial implementation, added alongside the
///          macOS "History" menu and "Complete History" window
///   1.1 — Wave R-4 (2026-07-26): iOS gained a producer, so the type is no longer
///          macOS-only. `resultCount`'s doc corrected — the two producers derive it
///          differently (see the property).
@Model final class SearchHistoryEntry {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Query

    /// The submitted query text (`SearchParameters.keywords`), trimmed of
    /// surrounding whitespace.
    var queryText: String = ""

    /// How many documents the search matched, at the time it was executed. Captured for
    /// display only — it is not refreshed if the index changes later.
    ///
    /// The two producers derive it differently, and the difference shows only on very broad
    /// queries. macOS records the true uncapped total from `SearchService.searchCount`, which
    /// `MacSearchViewModel.performSearch` already fetches in parallel for its truncation
    /// banner. iOS records `SearchViewModel.results.count`, capped at
    /// `SearchViewModel.searchHardLimit` (1,000), because that view model runs no count query
    /// and adding one would cost a second FTS5 `COUNT(*)` on every search.
    var resultCount: Int = 0

    // MARK: - Project Context

    /// The project active when the search was executed. `nil` for global context.
    var projectId: UUID?

    // MARK: - Timestamp

    /// When the search was executed. Optional for CloudKit schema compatibility — always non-nil in practice.
    var executedAt: Date?

    // MARK: - Initializer

    init(
        queryText: String,
        resultCount: Int = 0,
        projectId: UUID? = nil
    ) {
        self.id = UUID()
        self.queryText = queryText
        self.resultCount = resultCount
        self.projectId = projectId
        executedAt = Date.now

        #if DEBUG
        print("[SwiftData] SearchHistoryEntry created: \"\(queryText)\" results=\(resultCount) project=\(projectId?.uuidString ?? "nil")")
        #endif
    }
}
