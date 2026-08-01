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
///   1.2 — Wave R-2a: `init` gained `id` and `executedAt` so ``ResearchTrailMigration`` can
///          re-home a legacy `SessionEvent.searchSubmit` with its original identity and time.
///          No stored property changed, so the CloudKit schema is untouched by this.
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

    // MARK: - M-2: what makes an entry reproducible

    /// What the fetch returned, capped at ``fetchLimit``. The Q wave's **loaded**.
    ///
    /// ``resultCount`` remains the headline number both platforms already display; this records
    /// the fetch alongside it so `RecordedCount` can tell an exact total from a floor.
    ///
    /// All seven M-2 fields are optional, and none defaults. A non-optional default would make
    /// every row written before this build positively assert a value it never had — the argument
    /// `WorkingCorpus.wasTruncatedAtCapture` makes, for the same reason.
    var loadedCount: Int?

    /// Every document matching the query. The Q wave's **match**.
    ///
    /// `nil` when the count was unavailable *or* the row predates M-2 — ``fetchLimit`` tells those
    /// apart. Never a substitute number: not the fetch, not the cap. An appendix that prints a
    /// stand-in as a total is the defect the whole wave removed.
    var matchCount: Int?

    /// The fetch ceiling in force — 1,000 on iOS, 7,500 on macOS.
    ///
    /// Two jobs. It distinguishes a `loadedCount` of exactly 1,000 that *is* the answer from one
    /// that is a floor. And it is the **legacy discriminator**: `nil` if and only if the row was
    /// written before M-2, which is what lets an appendix caveat those rows specifically rather
    /// than hedging every row it prints. Load-bearing because one synced trail mixes platforms
    /// with different ceilings.
    var fetchLimit: Int?

    /// How many volumes this device had indexed when the search ran — the denominator every count
    /// needs, and M-2's named one. A count of nine means something different against 40 volumes
    /// than against 552.
    var indexedVolumeCount: Int?

    /// The scope the query ran under, as a canonical non-localized key.
    ///
    /// Deterministic `key=value` pairs in fixed order, so a French iPad and an English Mac
    /// produce the same string for the same scope and `==` is all the de-duplication needs. The
    /// volume list is recorded as a stable hash rather than a count, because two different
    /// twelve-volume scopes must not collapse into one another.
    ///
    /// Not prose: a sentence drifts with locale and cannot be compared.
    var scopeSignature: String?

    /// The working corpus the search ran inside, by id.
    ///
    /// Typed rather than described, because a consumer branches on it — resolving to
    /// `WorkingCorpus.truncationAtCapture` to decide whether the entry's own count is partial
    /// evidence. A `String` cannot be tested in a guard.
    var appliedCorpusId: UUID?

    /// The FTS5 expression the engine actually executed.
    ///
    /// M-2's named deliverable and the reason Q-2 is its prerequisite: a query text alone is not
    /// reproducible, because stemming, the boolean mode and the scope flags all shape what ran.
    var renderedExpression: String?

    // MARK: - Initializer

    /// Creates a search record.
    ///
    /// - Parameters:
    ///   - id: The entry's identifier. Defaults to a fresh `UUID`; ``ResearchTrailMigration``
    ///     passes the migrated `SessionEvent`'s id so a second pass over the same event is a no-op.
    ///   - queryText: The submitted query, trimmed by the caller.
    ///   - resultCount: Matches at execution time (see the property — the two producers differ).
    ///   - projectId: The active project, or `nil`.
    ///   - executedAt: When the search ran. Defaults to now; the migration passes the source
    ///     event's timestamp so a migrated search keeps its real place in the trail.
    init(
        id: UUID = UUID(),
        queryText: String,
        resultCount: Int = 0,
        projectId: UUID? = nil,
        executedAt: Date = .now,
        loadedCount: Int? = nil,
        matchCount: Int? = nil,
        fetchLimit: Int? = nil,
        indexedVolumeCount: Int? = nil,
        scopeSignature: String? = nil,
        appliedCorpusId: UUID? = nil,
        renderedExpression: String? = nil
    ) {
        self.id = id
        self.queryText = queryText
        self.resultCount = resultCount
        self.projectId = projectId
        self.executedAt = executedAt
        self.loadedCount = loadedCount
        self.matchCount = matchCount
        self.fetchLimit = fetchLimit
        self.indexedVolumeCount = indexedVolumeCount
        self.scopeSignature = scopeSignature
        self.appliedCorpusId = appliedCorpusId
        self.renderedExpression = renderedExpression

        #if DEBUG
        print("[SwiftData] SearchHistoryEntry created: \"\(queryText)\" results=\(resultCount) project=\(projectId?.uuidString ?? "nil")")
        #endif
    }

    // MARK: - Reading the recorded count

    /// What an entry's count actually asserts.
    ///
    /// Four states, not one number. `resultCount` alone cannot say whether 1,000 is the answer or
    /// a floor, nor whether a row predates the fields that would tell you — and an appendix built
    /// on "1,000" where the truth is "at least 1,000, of an unknown total" is the defect the Q
    /// wave spent nine PRs removing from the screen.
    ///
    /// Modelled on ``WorkingCorpus/CaptureTruncation``, and for the same reason: `unrecorded` is
    /// not a synonym for any of the others, and a consumer that collapses it into one re-tells the
    /// claim the type exists to prevent.
    enum RecordedCount: Equatable, Sendable {
        /// A real whole-query total, with the fetch that accompanied it.
        case exact(match: Int, loaded: Int)
        /// The count failed and the fetch capped: the answer is **at least** `loaded`.
        case floor(loaded: Int, fetchLimit: Int)
        /// The count failed but the fetch did not cap, so `loaded` *is* every matching document.
        case completeWithoutTotal(loaded: Int)
        /// Written before M-2. The number is whatever that build recorded; nothing more is known.
        case unrecorded(reported: Int)
    }

    /// The only supported way to read this entry's count.
    ///
    /// Reading `resultCount`, `matchCount` or `loadedCount` directly loses the distinction between
    /// a measured total and a floor, which is the distinction the appendix exists to preserve.
    var recordedCount: RecordedCount {
        // `fetchLimit` is nil if and only if the row predates M-2 — it is the one field with no
        // legitimate nil on a new row, which is what makes it the discriminator.
        guard let fetchLimit, let loadedCount else { return .unrecorded(reported: resultCount) }
        if let matchCount { return .exact(match: matchCount, loaded: loadedCount) }
        // The same predicate `ResultSetScope.didHitFetchLimit` uses. Sound because `loadedCount`
        // is the unfiltered fetch: checklist filtering happens after, and never lowers it.
        if loadedCount >= fetchLimit { return .floor(loaded: loadedCount, fetchLimit: fetchLimit) }
        return .completeWithoutTotal(loaded: loadedCount)
    }

    /// Whether this entry's count describes less than the whole answer to its query.
    ///
    /// A corpus the search ran inside may itself have been a truncated capture, which this entry
    /// cannot know alone — hence the parameter. Resolve it from ``appliedCorpusId``.
    func isPartialEvidence(corpusTruncation: WorkingCorpus.CaptureTruncation? = nil) -> Bool {
        if case .truncated = corpusTruncation { return true }
        if case .floor = recordedCount { return true }
        return false
    }
}
