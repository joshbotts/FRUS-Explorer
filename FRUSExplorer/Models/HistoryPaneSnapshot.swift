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

    /// The export-history predicate for this scope, or `nil` for ``all``.
    ///
    /// Rows migrated from a legacy `SessionEvent` always carry `nil`, so they land in
    /// ``unfiled`` — the old event type had no project at all and inventing one would be a
    /// fabricated attribution.
    var exportPredicate: Predicate<ExportHistoryEntry>? {
        switch self {
        case .all:
            return nil
        case .unfiled:
            let none: UUID? = nil
            return #Predicate<ExportHistoryEntry> { $0.projectId == none }
        case .project(let target):
            return #Predicate<ExportHistoryEntry> { $0.projectId == target }
        }
    }
}

// MARK: - HistoryRowID

/// A loaded row's **display** identity: the entry it came from, plus which copy of that entry it
/// is.
///
/// ## Why a row's id is not just the entry's id
/// `SearchHistoryEntry.id` is not unique in practice. Two devices that migrate the same legacy
/// event in the same window both write a row with that event's id, and `ResearchTrailMigration`
/// accepts that residual deliberately — contract D5 forbids anything from silently deleting this
/// table, and `DuplicateRecordCleanup`'s tiebreak is vacuous for a same-`id` group, so collapsing
/// them risks two devices deleting each other's copy and losing the record entirely.
///
/// The accepted mitigation was "a duplicate is visible and individually deletable". Neither half
/// worked while the id was the row id: `ForEach` over two elements with the same `Identifiable`
/// id is documented-undefined in SwiftUI, and the delete re-fetched with `fetchLimit = 1`, so the
/// swipe reported success and left the row on screen. This type is the first half of the fix —
/// every loaded row gets a distinct identity — and `HistoryTrailAdmin` deleting **every** copy is
/// the second.
struct HistoryRowID: Hashable, Sendable {

    /// The source entry's `id`, which is what a delete re-fetches on.
    let entryID: UUID

    /// Which copy of that entry this row is: `0` for the first one loaded, `1` for the next, and
    /// so on. Almost always `0`.
    let copy: Int
}

// MARK: - ReadingHistoryTitle

/// What a recorded document visit is called on screen (#1361).
///
/// ## Why a stored title is not always the document's
/// Until #1361 the writer stored whatever label the opener put in the entry. A `frusexplorer://`
/// link opens a document with its VOLUME's manifest title, the only title the handler has before
/// the volume is downloaded, so every visit opened that way was stored under the volume's name —
/// all 17 rows on the four #1081 capture simulators, each equal character for character to its
/// volume's manifest title. The writer now stores the parsed title
/// (`DocumentViewModel.readingHistoryTitle`), but rows already written keep what they hold, and
/// rewriting them would be a migration of a CloudKit-mirrored table — a write on every device —
/// for a repair that can be made where the title is read. So a stored title that IS its volume's
/// manifest title names the volume, not the document, and is treated as absent.
///
/// ## Why equality and not a looser match
/// The stored strings equal the manifest entry's `title` exactly: the manifest collapses its
/// whitespace on decode and the handler passed that value through unchanged. A prefix or fuzzy
/// test could suppress a document whose own heading merely begins like its volume's.
///
/// ## Where it applies
/// Of the surfaces that read `displayTitle`: the History list on both platforms
/// (``HistoryPaneSnapshot/DocumentRow``), the macOS History menu, and Project Home's Recently
/// Read. Not Browse's Continue Reading, whose fallback is the bare document id and whose row names
/// the volume nowhere else, so a stored volume title is the only volume context it has; not the
/// Session Log, whose row view is handed a derived activity and no manifest to compare against;
/// and not the research-data export, which carries the stored value as data. The writer's fix
/// reaches all of them for every visit recorded from now on.
enum ReadingHistoryTitle {

    /// `"volumeId · documentId"` — the identifier pair a visit is always known by.
    ///
    /// - Parameters:
    ///   - volumeId: The visit's volume identifier.
    ///   - documentId: The visit's document identifier.
    static func identifier(volumeId: String, documentId: String) -> String {
        "\(volumeId) · \(documentId)"
    }

    /// The document's own title from a stored visit title.
    ///
    /// - Parameters:
    ///   - stored: `ReadingHistoryEntry.displayTitle`, as stored.
    ///   - volumeTitle: The visit's volume title in the manifest, or `nil` when it lists none —
    ///     in which case there is nothing to compare against and the stored title stands.
    /// - Returns: The stored title, or `nil` when none was stored, it is empty, or it is exactly
    ///   the volume's title.
    static func documentTitle(stored: String?, volumeTitle: String?) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        if let volumeTitle, stored == volumeTitle { return nil }
        return stored
    }

    /// A recorded visit's one-line label: its document title, else its identifier pair.
    ///
    /// For the surfaces that draw a visit on a single line from the entry itself — the macOS
    /// History menu and Project Home's Recently Read. The History list draws two lines and reads
    /// ``HistoryPaneSnapshot/DocumentRow`` instead.
    ///
    /// - Parameters:
    ///   - visit: The recorded visit.
    ///   - manifest: The manifest whose title for the visit's volume is compared.
    @MainActor
    static func label(for visit: ReadingHistoryEntry, in manifest: ManifestStore) -> String {
        documentTitle(stored: visit.displayTitle,
                      volumeTitle: manifest.entry(forVolumeId: visit.volumeId)?.title)
            ?? identifier(volumeId: visit.volumeId, documentId: visit.documentId)
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
///   1.1 — Wave R-2a review fixes: exports are loaded, filtered and counted like the other two
///          types (the migration's duplicate residual was justified by "individually deletable",
///          which an unloaded table cannot be), and every row carries a distinct
///          ``HistoryRowID`` so a same-`id` pair is two rows to `ForEach` rather than SwiftUI's
///          documented-undefined case
///   1.2 — #1298 follow-up: the search filter folds typographic double quotation marks on the row's text and the
///          term, so the one row a curly and a straight run refresh is found by a filter typed in either spelling
///   1.3 — #1361: a document row's caption names the document (`volumeId · documentId`), and a
///          stored title that is only its volume's manifest title reads as no title
///          (``ReadingHistoryTitle``); `fetch` takes the manifest lookup that rule needs
struct HistoryPaneSnapshot: Equatable, Sendable {

    // MARK: - Rows

    /// One recorded document visit, with everything the row draws already resolved.
    struct DocumentRow: Identifiable, Equatable, Sendable {
        /// This row's display identity — see ``HistoryRowID`` for why it is not the entry's id.
        let id: HistoryRowID
        /// The entry's own id: the key a per-row delete re-fetches on.
        var entryID: UUID { id.entryID }
        /// FRUS volume identifier.
        let volumeId: String
        /// Document identifier within the volume.
        let documentId: String
        /// The title stored with the visit, exactly as written. `nil` on pre-1.1 entries (F-021),
        /// and the volume's own title on many rows written before #1361 — read ``title``, which
        /// knows both cases, rather than this.
        let displayTitle: String?
        /// The volume's title in the manifest when the snapshot was read, or `nil` when the
        /// manifest does not list the volume. Read only to recognise a stored title that names the
        /// volume rather than the document (see ``ReadingHistoryTitle``).
        let volumeTitle: String?
        /// When the document was opened. `nil` only on rows written before the field existed.
        let accessedAt: Date?
        /// The project active at write time, or `nil`. Attribution is recorded when the entry is
        /// written and is never retroactively re-pointed by switching projects.
        let projectId: UUID?

        /// The document's own title, when the row has one: the stored title, unless it is empty
        /// or is only its volume's title (``ReadingHistoryTitle/documentTitle(stored:volumeTitle:)``).
        var documentTitle: String? {
            ReadingHistoryTitle.documentTitle(stored: displayTitle, volumeTitle: volumeTitle)
        }

        /// The row's primary line: the document's own title, else `"volumeId · documentId"` — the
        /// same fallback the macOS window has always drawn for pre-1.1 entries, and since #1361 for
        /// a row whose stored title is only its volume's.
        var title: String {
            documentTitle ?? ReadingHistoryTitle.identifier(volumeId: volumeId, documentId: documentId)
        }

        /// The row's second line, before the time: `"volumeId · documentId"` under a document
        /// title, so repeat visits to one document read alike and two documents sharing a heading
        /// do not (#1361 — the line drew the volume id alone, and `documentId`, though loaded and
        /// matched by the filter, was never shown). `nil` when ``title`` already is that pair:
        /// drawing it twice says nothing.
        var caption: String? {
            documentTitle == nil
                ? nil
                : ReadingHistoryTitle.identifier(volumeId: volumeId, documentId: documentId)
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
        /// This row's display identity — see ``HistoryRowID``.
        let id: HistoryRowID
        /// The entry's own id: the key a per-row delete re-fetches on.
        var entryID: UUID { id.entryID }
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
        /// Case- and diacritic-insensitive via `localizedStandardContains`, with the typographic double quotation marks
        /// on both sides folded to U+0022 first (`FTS5InlineQueryParser.normalizingQuotationMarks(_:)`, #1298).
        /// `localizedStandardContains` does not equate `“`, `«` or `＂` with `"`, and a curly and a straight run of one
        /// query refresh ONE row that keeps the later spelling (`SearchHistoryWriter`), so without the fold a filter
        /// typed in the other spelling hid the row — and an iPad's filter field types the curly marks itself. A double
        /// prime and the single marks are not folded, as the writer does not fold them.
        ///
        /// - Parameter term: The already-trimmed search term. An empty term matches everything.
        func matches(_ term: String) -> Bool {
            guard !term.isEmpty else { return true }
            return FTS5InlineQueryParser.normalizingQuotationMarks(queryText)
                .localizedStandardContains(FTS5InlineQueryParser.normalizingQuotationMarks(term))
        }
    }

    /// One recorded collection export.
    ///
    /// The third trail type had no rows in this snapshot at all until the R-2a review: the
    /// migration's accepted duplicate residual was justified by "visibly and individually
    /// deletable", and an export the History surface never loaded is neither.
    struct ExportRow: Identifiable, Equatable, Sendable {
        /// This row's display identity — see ``HistoryRowID``.
        let id: HistoryRowID
        /// The entry's own id: the key a per-row delete re-fetches on.
        var entryID: UUID { id.entryID }
        /// `ExportFormat.rawValue`, or `"zotero-api"` for the Zotero Web-API push.
        let format: String
        /// How many documents went out.
        let documentCount: Int
        /// The collection's name at export time. Always `nil` on rows migrated from a legacy
        /// `SessionEvent`, whose payload carried only the format and the count.
        let collectionName: String?
        /// When the export completed.
        let exportedAt: Date?
        /// The project active at write time, or `nil`.
        let projectId: UUID?

        /// The format's human name — `ExportFormat`'s own wording where the raw value is one of
        /// its cases, plus the one value that is not (`"zotero-api"`, the Web-API push), and the
        /// raw string itself for anything a future build writes that this one does not know.
        var formatDisplayName: String {
            if format == "zotero-api" {
                return String(localized: "history.exports.format.zoteroAPI",
                              defaultValue: "Zotero (web)")
            }
            return ExportFormat(rawValue: format)?.displayName ?? format
        }

        /// The row's primary line: the collection's name where it was recorded, else the format.
        var title: String { collectionName?.isEmpty == false ? collectionName! : formatDisplayName }

        /// Whether this row matches a free-text filter term. Matches the collection name and both
        /// spellings of the format, so "pdf" and "PDF" both find a PDF export.
        ///
        /// - Parameter term: The already-trimmed search term. An empty term matches everything.
        func matches(_ term: String) -> Bool {
            guard !term.isEmpty else { return true }
            return title.localizedStandardContains(term)
                || format.localizedStandardContains(term)
                || formatDisplayName.localizedStandardContains(term)
        }
    }

    // MARK: - Contents

    /// The loaded page of document visits, newest first.
    let documents: [DocumentRow]
    /// The loaded page of searches, newest first.
    let searches: [SearchRow]
    /// The loaded page of exports, newest first.
    let exports: [ExportRow]
    /// How many document visits exist **in this scope**, before the page limit.
    let totalDocuments: Int
    /// How many searches exist **in this scope**, before the page limit.
    let totalSearches: Int
    /// How many exports exist **in this scope**, before the page limit.
    let totalExports: Int
    /// Project ids paired with their names, sorted by name — the scope picker's options.
    let projects: [(id: UUID, name: String)]
    /// The row limit this snapshot was fetched with, per section.
    let pageLimit: Int

    /// The state before the first fetch.
    static let empty = HistoryPaneSnapshot(
        documents: [], searches: [], exports: [],
        totalDocuments: 0, totalSearches: 0, totalExports: 0,
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

    /// Whether more exports exist in this scope than the page loaded.
    var hasMoreExports: Bool { exports.count < totalExports }

    /// Whether the trail is empty in this scope — nothing to browse, filter, or delete.
    var isEmpty: Bool { totalDocuments == 0 && totalSearches == 0 && totalExports == 0 }

    /// Tuples are not `Equatable` by synthesis, so `projects` is compared field-wise — the same
    /// shape ``NotesPaneSnapshot`` uses for the identical reason.
    static func == (lhs: HistoryPaneSnapshot, rhs: HistoryPaneSnapshot) -> Bool {
        lhs.documents == rhs.documents
            && lhs.searches == rhs.searches
            && lhs.exports == rhs.exports
            && lhs.totalDocuments == rhs.totalDocuments
            && lhs.totalSearches == rhs.totalSearches
            && lhs.totalExports == rhs.totalExports
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

    /// The loaded export rows matching a free-text term.
    ///
    /// - Parameter term: Raw filter text; trimmed here so callers need not.
    func filteredExports(matching term: String) -> [ExportRow] {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return exports }
        return exports.filter { $0.matches(trimmed) }
    }

    // MARK: - Building

    /// Reads one page of the trail for one scope, in seven fetches.
    ///
    /// Three bounded page fetches, three unbounded counts (so the view can be honest about what it
    /// is not showing), and one project fetch for the picker. The counts are separate
    /// descriptors because `fetchCount` honours `fetchLimit` — reusing the page descriptor would
    /// report the page size as the total and the "Show More" affordance would never appear.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - scope: Which slice of the trail to load.
    ///   - limit: Maximum rows per section. Defaults to ``defaultPageLimit``.
    ///   - volumeTitle: A volume's manifest title, or `nil` when the manifest does not list it —
    ///     how a row recognises a stored title that only names its volume (#1361). Required, not
    ///     defaulted, so no caller can forget it and draw volume titles as document titles.
    /// - Returns: The snapshot. Fetch failures degrade to empty sections rather than throwing;
    ///   a History surface that cannot read is a surface that shows nothing, not one that crashes.
    @MainActor
    static func fetch(from context: ModelContext,
                      scope: HistoryScope = .all,
                      limit: Int = defaultPageLimit,
                      volumeTitle: (String) -> String?) -> HistoryPaneSnapshot {
        let readingPredicate = scope.readingPredicate
        let searchPredicate = scope.searchPredicate
        let exportPredicate = scope.exportPredicate

        var readingPage = FetchDescriptor<ReadingHistoryEntry>(
            predicate: readingPredicate,
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)])
        readingPage.fetchLimit = limit

        var searchPage = FetchDescriptor<SearchHistoryEntry>(
            predicate: searchPredicate,
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)])
        searchPage.fetchLimit = limit

        var exportPage = FetchDescriptor<ExportHistoryEntry>(
            predicate: exportPredicate,
            sortBy: [SortDescriptor(\.exportedAt, order: .reverse)])
        exportPage.fetchLimit = limit

        let visits = (try? context.fetch(readingPage)) ?? []
        let queries = (try? context.fetch(searchPage)) ?? []
        let sends = (try? context.fetch(exportPage)) ?? []

        let visitTotal = (try? context.fetchCount(
            FetchDescriptor<ReadingHistoryEntry>(predicate: readingPredicate))) ?? visits.count
        let queryTotal = (try? context.fetchCount(
            FetchDescriptor<SearchHistoryEntry>(predicate: searchPredicate))) ?? queries.count
        let exportTotal = (try? context.fetchCount(
            FetchDescriptor<ExportHistoryEntry>(predicate: exportPredicate))) ?? sends.count

        let projects = (try? context.fetch(
            FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []

        var visitIDs = RowIDMinter()
        var queryIDs = RowIDMinter()
        var sendIDs = RowIDMinter()

        return HistoryPaneSnapshot(
            documents: visits.map {
                DocumentRow(id: visitIDs.next(for: $0.id),
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            displayTitle: $0.displayTitle,
                            volumeTitle: volumeTitle($0.volumeId),
                            accessedAt: $0.accessedAt,
                            projectId: $0.projectId)
            },
            searches: queries.map {
                SearchRow(id: queryIDs.next(for: $0.id),
                          queryText: $0.queryText,
                          resultCount: $0.resultCount,
                          executedAt: $0.executedAt,
                          projectId: $0.projectId)
            },
            exports: sends.map {
                ExportRow(id: sendIDs.next(for: $0.id),
                          format: $0.format,
                          documentCount: $0.documentCount,
                          collectionName: $0.collectionName,
                          exportedAt: $0.exportedAt,
                          projectId: $0.projectId)
            },
            totalDocuments: visitTotal,
            totalSearches: queryTotal,
            totalExports: exportTotal,
            projects: projects.map { (id: $0.id, name: $0.name) },
            pageLimit: limit)
    }

    /// Hands out a distinct ``HistoryRowID`` per loaded row, numbering repeats of one entry id.
    ///
    /// One per section, because the sections are three different tables and an id shared across
    /// them is not a duplicate of anything.
    private struct RowIDMinter {
        private var seen: [UUID: Int] = [:]

        /// The next identity for this entry id.
        mutating func next(for entryID: UUID) -> HistoryRowID {
            let copy = seen[entryID, default: 0]
            seen[entryID] = copy + 1
            return HistoryRowID(entryID: entryID, copy: copy)
        }
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
/// ## And why the trail-wide delete followed it here in R-2a
/// R-3 left ``deleteAll(context:)`` to R-5. Wave R-2a forced it early rather than by choice: once
/// sessions are *derived* from these tables, the Research Sessions pane's "Delete Recorded
/// Sessions…" — which summarises the derived sessions — would otherwise announce "12 sessions will
/// be permanently deleted", call `ResearchSessionAdmin.deleteAll`, and remove nothing the user can
/// see. A button that lies about what it deletes is worse than one that does not exist.
///
/// **Both closed by R-5.** The Data & Recovery **Contents** inventory now counts the three trail
/// tables alongside notes, tags, highlights, collections, prompts and projects, and the JSON
/// research-data export carries them (`ResearchDataEnvelope` format version 3). The inventory was
/// never a section of `DataRecoveryView` itself — it is `DataExportSections`' *Contents* section,
/// declared in `ResearchDataExportView.swift` and hosted by that pane on both platforms.
///
/// ## Why the per-entry deletes are unbounded
/// Each one used to re-fetch with `fetchLimit = 1`. `id` is not unique in this store: two devices
/// that migrate the same legacy `SessionEvent` in the same window both write a row carrying that
/// event's id, and ``ResearchTrailMigration`` accepts that residual on purpose. With a limit of
/// one, deleting such a row removed a single copy, returned `true`, and left the other on screen —
/// so the swipe reported success and did nothing visible. Deleting every copy is what the user
/// asked for: they are identical rows standing for one recorded thing.
///
/// Version history:
///   1.0 — Wave R-3: per-entry delete for both trail types
///   1.1 — Wave R-2a: `deleteAll(context:)` — the whole trail, plus the retired session tables
///   1.2 — Wave R-2a review fixes: the per-entry deletes remove **every** row sharing the id, and
///          ``deleteExport(id:in:)`` closes the third trail type, which had no per-entry delete at
///          all
enum HistoryTrailAdmin {

    /// Deletes every recorded document visit carrying this id.
    ///
    /// - Parameters:
    ///   - id: The entry's id, as carried by ``HistoryPaneSnapshot/DocumentRow/entryID``.
    ///   - context: The SwiftData context to mutate.
    /// - Returns: `false` when no entry with that id exists — the snapshot the caller is holding
    ///   is stale and should be re-read rather than silently left alone.
    @MainActor
    @discardableResult
    static func deleteDocumentVisit(id: UUID, in context: ModelContext) -> Bool {
        // Scalar `==` on a UUID is safe in a `#Predicate`; the documented SwiftData hazard is
        // `contains` on a transformable array column, which this is not.
        let descriptor = FetchDescriptor<ReadingHistoryEntry>(predicate: #Predicate { $0.id == id })
        let entries = (try? context.fetch(descriptor)) ?? []
        guard !entries.isEmpty else { return false }
        for entry in entries { context.delete(entry) }
        // Flush, so the removal reaches the other contexts that read this table — Project Home's
        // recents, the storage hubs' "opened" dates, the search History scope — and CloudKit,
        // promptly rather than whenever the autosave timer next fires.
        try? context.save()
        return true
    }

    /// Deletes every recorded search carrying this id.
    ///
    /// - Parameters:
    ///   - id: The entry's id, as carried by ``HistoryPaneSnapshot/SearchRow/entryID``.
    ///   - context: The SwiftData context to mutate.
    /// - Returns: `false` when no entry with that id exists.
    @MainActor
    @discardableResult
    static func deleteSearch(id: UUID, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SearchHistoryEntry>(predicate: #Predicate { $0.id == id })
        let entries = (try? context.fetch(descriptor)) ?? []
        guard !entries.isEmpty else { return false }
        for entry in entries { context.delete(entry) }
        try? context.save()
        return true
    }

    /// Deletes every recorded export carrying this id.
    ///
    /// - Parameters:
    ///   - id: The entry's id, as carried by ``HistoryPaneSnapshot/ExportRow/entryID``.
    ///   - context: The SwiftData context to mutate.
    /// - Returns: `false` when no entry with that id exists.
    @MainActor
    @discardableResult
    static func deleteExport(id: UUID, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ExportHistoryEntry>(predicate: #Predicate { $0.id == id })
        let entries = (try? context.fetch(descriptor)) ?? []
        guard !entries.isEmpty else { return false }
        for entry in entries { context.delete(entry) }
        try? context.save()
        return true
    }

    /// What one trail-wide delete removed.
    struct DeletedCounts: Equatable, Sendable {
        /// Document visits removed.
        var visits = 0
        /// Searches removed.
        var searches = 0
        /// Exports removed.
        var exports = 0
        /// Everything the user would think of as "a thing that was recorded".
        var trailTotal: Int { visits + searches + exports }
    }

    /// Deletes the **whole** research trail: every document visit, every recorded search, every
    /// export — and the retired session tables with them.
    ///
    /// ## What it deliberately does not touch
    /// Notes, highlights, tags, collections, prompts and projects. The confirmation copy in
    /// Settings promises exactly that, and this is the code that has to keep the promise.
    ///
    /// ## Why the legacy tables go too
    /// A user asking to delete their recorded sessions means all of them. Any `SessionEvent` still
    /// present is one ``ResearchTrailMigration`` has not reached yet — typically synced in from a
    /// device on an older build — and leaving it would let the trail silently repopulate at the
    /// next launch from rows the user just deleted. Events are removed before their sessions
    /// because the relationship is `.nullify`; ``ResearchSessionAdmin/deleteAll(context:)`` is the
    /// one place that hazard is written down, so this delegates rather than repeating it.
    ///
    /// - Parameter context: The SwiftData context to mutate.
    /// - Returns: How many rows of each kind were removed.
    @MainActor
    @discardableResult
    static func deleteAll(context: ModelContext) -> DeletedCounts {
        var counts = DeletedCounts()

        let visits = (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>())) ?? []
        for visit in visits { context.delete(visit) }
        counts.visits = visits.count

        let searches = (try? context.fetch(FetchDescriptor<SearchHistoryEntry>())) ?? []
        for search in searches { context.delete(search) }
        counts.searches = searches.count

        let exports = (try? context.fetch(FetchDescriptor<ExportHistoryEntry>())) ?? []
        for export in exports { context.delete(export) }
        counts.exports = exports.count

        try? context.save()

        // Always-on, like `DuplicateRecordCleanup`'s: this removes CloudKit-mirrored user records
        // and propagates the removal to every device.
        print("[HistoryTrailAdmin] Deleted the research trail: \(counts.visits) visit(s), "
              + "\(counts.searches) search(es), \(counts.exports) export(s).")
        return counts
    }
}
