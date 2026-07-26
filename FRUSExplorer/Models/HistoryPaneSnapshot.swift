// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - HistoryScope

/// What slice of the research trail a History surface is showing (Wave R contract, D4).
///
/// Both trail types carry a **scalar** `projectId: UUID?`, so — unlike the notes and
/// collections filters, which have to fetch-then-filter a transformable `[UUID]` column —
/// this one translates into a `#Predicate` and runs in the fetch. `ProjectEngagedDocuments`
/// establishes the precedent (`#Predicate { $0.projectId == pid }`); ``HistoryPaneSnapshot``
/// follows it, which is what makes a *bounded* fetch correct: the row limit applies to rows
/// that already match the scope, rather than truncating a global page that the scope then
/// mostly filters away.
///
/// The three-way shape deliberately mirrors `NotesPaneSnapshot.ProjectFilter`
/// (`any` / `unfiled` / `id`) rather than inventing a fourth convention, and — like it —
/// spells "no project" as its own case instead of a sentinel UUID. The sentinel form is a
/// recorded defect in this codebase twice over: the old Notes pane tagged its "Untagged"
/// item with the all-zeros UUID and matched nothing, and `GlobalContextView` mints a fresh
/// `UUID()` per render so the selection cannot even stick.
enum HistoryScope: Hashable, Sendable {

    /// Every entry, whatever project was active when it was recorded. The default (D4:
    /// "global by default").
    case all
    /// Only entries recorded with no active project.
    case unfiled
    /// Only entries recorded while this project was active.
    case project(UUID)

    /// Whether an entry's recorded `projectId` satisfies this scope.
    ///
    /// The in-memory mirror of the fetch predicates below. Kept so the scope's meaning is
    /// testable as a pure function and so a caller holding rows it did not fetch itself can
    /// still ask the question.
    ///
    /// - Parameter projectId: The project attributed to the entry at write time, or `nil`.
    /// - Returns: `true` when the entry belongs in this scope.
    func matches(_ projectId: UUID?) -> Bool {
        switch self {
        case .all:                 return true
        case .unfiled:             return projectId == nil
        case .project(let target): return projectId == target
        }
    }

    /// The reading-history predicate for this scope, or `nil` for ``all`` (no constraint).
    ///
    /// Returned rather than applied so the caller can reuse one predicate for both the
    /// bounded page fetch and the unbounded `fetchCount` that reports the honest total.
    var readingPredicate: Predicate<ReadingHistoryEntry>? {
        switch self {
        case .all:
            return nil
        case .unfiled:
            // A typed `nil` binding: `$0.projectId == nil` alone leaves the macro without a
            // type for the literal.
            let none: UUID? = nil
            return #Predicate<ReadingHistoryEntry> { $0.projectId == none }
        case .project(let target):
            return #Predicate<ReadingHistoryEntry> { $0.projectId == target }
        }
    }

    /// The search-history predicate for this scope, or `nil` for ``all``.
    var searchPredicate: Predicate<SearchHistoryEntry>? {
        switch self {
        case .all:
            return nil
        case .unfiled:
            let none: UUID? = nil
            return #Predicate<SearchHistoryEntry> { $0.projectId == none }
        case .project(let target):
            return #Predicate<SearchHistoryEntry> { $0.projectId == target }
        }
    }
}

// MARK: - HistoryPaneSnapshot

/// The research trail, flattened into display-ready rows for one scope and one page.
///
/// ## Why this exists rather than a `@Query`
/// The macOS History window held two live `@Query`s over **every** `ReadingHistoryEntry` and
/// **every** `SearchHistoryEntry`, unbounded, and filtered them in a computed property on each
/// render. Nothing prunes either table — the Wave R contract makes that a deliberate choice
/// (D5: no auto-pruning; the query log is a method appendix, not a cache) — so those queries
/// grow without limit for the life of the install.
///
/// That is the shape this codebase has been bitten by repeatedly: a `@Query` re-renders its
/// whole pane on every CloudKit drip-import, and both of these types are CloudKit-mirrored, so
/// a sync that imports history a batch at a time re-renders the list once per batch. The Tags
/// pane's per-row full-table fetch and the Storage pane's per-row `isVolumeIndexed()` (which
/// pegged a CPU core overnight in Session 160) are the same defect wearing different clothes;
/// ``NotesPaneSnapshot`` is the settled answer to it.
///
/// This does the work **once**, and does it bounded:
/// - the scope constrains the *fetch* (see ``HistoryScope``), not a post-hoc filter;
/// - `fetchLimit` caps how many rows are materialised — ``defaultPageLimit`` per section, which
///   the reader raises in ``pageIncrement`` steps with "Show More";
/// - a second, unlimited `fetchCount` reports the true total, so the view can say
///   "Showing 500 of 12,904" instead of implying the page is the whole trail;
/// - rows are plain `Sendable` values afterwards, so no `@Model` object is retained by the view.
///
/// ## What is *not* pushed into the fetch
/// The free-text filter runs in memory over the rows already loaded — see ``DocumentRow/matches(_:)``.
/// So typing in the History search field narrows **the loaded page**, not the whole store; the
/// view states the page size for exactly this reason, and "Show More" widens what a search can
/// reach. Pushing the text down would mean `localizedStandardContains` inside a `#Predicate`
/// against `displayTitle`, which is optional, and SwiftData's translation of optional string
/// operations is the kind of thing that fails at runtime rather than at compile time. Bounded
/// and honest beats clever and fragile.
///
/// Version history:
///   1.0 — Wave R-3: initial implementation
struct HistoryPaneSnapshot: Equatable, Sendable {

    // MARK: - Rows

    /// One recorded document visit, with everything the row draws already resolved.
    struct DocumentRow: Identifiable, Equatable, Sendable {
        /// The entry's own id — also the key a per-row delete re-fetches on.
        let id: UUID
        /// FRUS volume identifier.
        let volumeId: String
        /// Document identifier within the volume.
        let documentId: String
        /// Human-readable title captured at read time. `nil` on pre-1.1 entries (F-021).
        let displayTitle: String?
        /// When the document was opened. `nil` only on rows written before the field existed.
        let accessedAt: Date?
        /// The project active at write time, or `nil`. Attribution is recorded when the entry is
        /// written and is never retroactively re-pointed by switching projects.
        let projectId: UUID?

        /// The row's primary line: the captured title, else `"volumeId · documentId"` — the
        /// same fallback the macOS window has always drawn for pre-1.1 entries.
        var title: String {
            if let displayTitle, !displayTitle.isEmpty { return displayTitle }
            return "\(volumeId) · \(documentId)"
        }

        /// Whether this row matches a free-text filter term.
        ///
        /// Matches the displayed title and both identifiers, so a reader who remembers only
        /// "frus1969-76v01" or "d42" finds the visit. Case- and diacritic-insensitive via
        /// `localizedStandardContains`, the same comparison the Notes screen's filter uses.
        ///
        /// - Parameter term: The already-trimmed search term. An empty term matches everything.
        func matches(_ term: String) -> Bool {
            guard !term.isEmpty else { return true }
            return title.localizedStandardContains(term)
                || volumeId.localizedStandardContains(term)
                || documentId.localizedStandardContains(term)
        }
    }

    /// One recorded search execution.
    struct SearchRow: Identifiable, Equatable, Sendable {
        /// The entry's own id — the key a per-row delete re-fetches on.
        let id: UUID
        /// The submitted query text, as stored.
        let queryText: String
        /// The uncapped match count at execution time. Not refreshed if the index changes later.
        let resultCount: Int
        /// When the search ran.
        let executedAt: Date?
        /// The project active at write time, or `nil`.
        let projectId: UUID?

        /// Whether this row matches a free-text filter term.
        ///
        /// - Parameter term: The already-trimmed search term. An empty term matches everything.
        func matches(_ term: String) -> Bool {
            guard !term.isEmpty else { return true }
            return queryText.localizedStandardContains(term)
        }
    }

    // MARK: - Contents

    /// The loaded page of document visits, newest first.
    let documents: [DocumentRow]
    /// The loaded page of searches, newest first.
    let searches: [SearchRow]
    /// How many document visits exist **in this scope**, before the page limit.
    let totalDocuments: Int
    /// How many searches exist **in this scope**, before the page limit.
    let totalSearches: Int
    /// Project ids paired with their names, sorted by name — the scope picker's options.
    let projects: [(id: UUID, name: String)]
    /// The row limit this snapshot was fetched with, per section.
    let pageLimit: Int

    /// The state before the first fetch.
    static let empty = HistoryPaneSnapshot(
        documents: [], searches: [], totalDocuments: 0, totalSearches: 0,
        projects: [], pageLimit: defaultPageLimit)

    /// How many rows each section loads to begin with.
    ///
    /// Large enough that the great majority of readers never meet the boundary, small enough
    /// that the fetch stays a cheap main-thread operation on a trail with tens of thousands of
    /// entries in it.
    static let defaultPageLimit = 500

    /// How much "Show More" adds to the limit each time.
    static let pageIncrement = 500

    /// Whether more document visits exist in this scope than the page loaded.
    var hasMoreDocuments: Bool { documents.count < totalDocuments }

    /// Whether more searches exist in this scope than the page loaded.
    var hasMoreSearches: Bool { searches.count < totalSearches }

    /// Whether the trail is empty in this scope — nothing to browse, filter, or delete.
    var isEmpty: Bool { totalDocuments == 0 && totalSearches == 0 }

    /// Tuples are not `Equatable` by synthesis, so `projects` is compared field-wise — the same
    /// shape ``NotesPaneSnapshot`` uses for the identical reason.
    static func == (lhs: HistoryPaneSnapshot, rhs: HistoryPaneSnapshot) -> Bool {
        lhs.documents == rhs.documents
            && lhs.searches == rhs.searches
            && lhs.totalDocuments == rhs.totalDocuments
            && lhs.totalSearches == rhs.totalSearches
            && lhs.pageLimit == rhs.pageLimit
            && lhs.projects.map(\.id) == rhs.projects.map(\.id)
            && lhs.projects.map(\.name) == rhs.projects.map(\.name)
    }

    // MARK: - Filtering

    /// The loaded document rows matching a free-text term.
    ///
    /// - Parameter term: Raw filter text; trimmed here so callers need not.
    func filteredDocuments(matching term: String) -> [DocumentRow] {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return documents }
        return documents.filter { $0.matches(trimmed) }
    }

    /// The loaded search rows matching a free-text term.
    ///
    /// - Parameter term: Raw filter text; trimmed here so callers need not.
    func filteredSearches(matching term: String) -> [SearchRow] {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return searches }
        return searches.filter { $0.matches(trimmed) }
    }

    // MARK: - Building

    /// Reads one page of the trail for one scope, in five fetches.
    ///
    /// Two bounded page fetches, two unbounded counts (so the view can be honest about what it
    /// is not showing), and one project fetch for the picker. The counts are separate
    /// descriptors because `fetchCount` honours `fetchLimit` — reusing the page descriptor would
    /// report the page size as the total and the "Show More" affordance would never appear.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - scope: Which slice of the trail to load.
    ///   - limit: Maximum rows per section. Defaults to ``defaultPageLimit``.
    /// - Returns: The snapshot. Fetch failures degrade to empty sections rather than throwing;
    ///   a History surface that cannot read is a surface that shows nothing, not one that crashes.
    @MainActor
    static func fetch(from context: ModelContext,
                      scope: HistoryScope = .all,
                      limit: Int = defaultPageLimit) -> HistoryPaneSnapshot {
        let readingPredicate = scope.readingPredicate
        let searchPredicate = scope.searchPredicate

        var readingPage = FetchDescriptor<ReadingHistoryEntry>(
            predicate: readingPredicate,
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)])
        readingPage.fetchLimit = limit

        var searchPage = FetchDescriptor<SearchHistoryEntry>(
            predicate: searchPredicate,
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)])
        searchPage.fetchLimit = limit

        let visits = (try? context.fetch(readingPage)) ?? []
        let queries = (try? context.fetch(searchPage)) ?? []

        let visitTotal = (try? context.fetchCount(
            FetchDescriptor<ReadingHistoryEntry>(predicate: readingPredicate))) ?? visits.count
        let queryTotal = (try? context.fetchCount(
            FetchDescriptor<SearchHistoryEntry>(predicate: searchPredicate))) ?? queries.count

        let projects = (try? context.fetch(
            FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []

        return HistoryPaneSnapshot(
            documents: visits.map {
                DocumentRow(id: $0.id,
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            displayTitle: $0.displayTitle,
                            accessedAt: $0.accessedAt,
                            projectId: $0.projectId)
            },
            searches: queries.map {
                SearchRow(id: $0.id,
                          queryText: $0.queryText,
                          resultCount: $0.resultCount,
                          executedAt: $0.executedAt,
                          projectId: $0.projectId)
            },
            totalDocuments: visitTotal,
            totalSearches: queryTotal,
            projects: projects.map { (id: $0.id, name: $0.name) },
            pageLimit: limit)
    }
}

// MARK: - Row copy

extension HistoryPaneSnapshot {

    /// "Showing 500 of 12,904" — the honest version of a list that shows only its head.
    ///
    /// Returns `nil` when the page *is* everything, so the caller can omit the line entirely
    /// rather than draw a redundant "Showing 12 of 12".
    ///
    /// - Parameters:
    ///   - shown: How many rows the section is actually drawing.
    ///   - total: How many exist in the current scope.
    static func showingCount(shown: Int, of total: Int) -> String? {
        guard shown < total else { return nil }
        return String(format: String(localized: "history.showing %lld %lld",
                                     defaultValue: "Showing %lld of %lld"),
                      Int64(shown), Int64(total))
    }
}

// MARK: - HistoryTrailAdmin

/// Deleting entries from the research trail.
///
/// Separated from the view for the reason ``ResearchSessionAdmin`` is: a destructive operation
/// should be one named thing that can be read, reviewed, and tested, not a closure inside a
/// swipe action.
///
/// ## Why per-entry delete had to land here
/// Before this, `SearchHistoryEntry` had **no delete path anywhere in the app**. The app
/// recorded the user's search text, mirrored it to their iCloud private database, and offered
/// no way to remove it: `ResearchSessionAdmin.deleteAll` reaches only `ResearchSession` and
/// `SessionEvent`, and `EraseEverythingView.performReset` reaches only `ReadingHistoryEntry`.
/// That is a privacy gap rather than a polish item, and the surface that lists the entries is
/// where the reader expects to be able to remove one.
///
/// A trail-wide delete — one action that reaches every type, wired into the Data & Recovery
/// inventory and the research-data export — is **R-5's**, deliberately not attempted here. This
/// type is the extension point for it.
///
/// Version history:
///   1.0 — Wave R-3: per-entry delete for both trail types
enum HistoryTrailAdmin {

    /// Deletes one recorded document visit.
    ///
    /// - Parameters:
    ///   - id: The entry's id, as carried by ``HistoryPaneSnapshot/DocumentRow``.
    ///   - context: The SwiftData context to mutate.
    /// - Returns: `false` when no entry with that id exists — the snapshot the caller is holding
    ///   is stale and should be re-read rather than silently left alone.
    @MainActor
    @discardableResult
    static func deleteDocumentVisit(id: UUID, in context: ModelContext) -> Bool {
        // Scalar `==` on a UUID is safe in a `#Predicate`; the documented SwiftData hazard is
        // `contains` on a transformable array column, which this is not.
        var descriptor = FetchDescriptor<ReadingHistoryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entry = (try? context.fetch(descriptor))?.first else { return false }
        context.delete(entry)
        // Flush, so the removal reaches the other contexts that read this table — Project Home's
        // recents, the storage hubs' "opened" dates, the search History scope — and CloudKit,
        // promptly rather than whenever the autosave timer next fires.
        try? context.save()
        return true
    }

    /// Deletes one recorded search.
    ///
    /// - Parameters:
    ///   - id: The entry's id, as carried by ``HistoryPaneSnapshot/SearchRow``.
    ///   - context: The SwiftData context to mutate.
    /// - Returns: `false` when no entry with that id exists.
    @MainActor
    @discardableResult
    static func deleteSearch(id: UUID, in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<SearchHistoryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entry = (try? context.fetch(descriptor))?.first else { return false }
        context.delete(entry)
        try? context.save()
        return true
    }
}
