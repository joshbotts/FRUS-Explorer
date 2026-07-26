// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchTrailActivity

/// One recorded thing the user did, flattened out of whichever trail table holds it.
///
/// The three typed tables — ``ReadingHistoryEntry``, ``SearchHistoryEntry``,
/// ``ExportHistoryEntry`` — have nothing in common structurally but a timestamp and a
/// `projectId`. This is the shape they share once loaded, and the input to
/// ``ResearchTrailSessions/group(_:idleInterval:)``.
///
/// Deliberately carries **structured** values rather than rendered copy: the row wording is the
/// view's business and belongs in `String(localized:)` there, not in a model type where it would
/// be untranslatable in half the places it is used.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
struct ResearchTrailActivity: Identifiable, Equatable, Sendable {

    /// What kind of activity this is, with the fields that kind carries.
    enum Kind: Equatable, Sendable {
        /// A document was opened.
        case documentOpen(volumeId: String, documentId: String, displayTitle: String?)
        /// A search was submitted.
        case search(query: String, resultCount: Int)
        /// A collection was exported.
        case export(format: String, documentCount: Int, collectionName: String?)

        /// The SF Symbol the session log draws for this kind. Not user-facing, so not localised —
        /// the same three glyphs the old `SessionEventRowView` used, minus `note.text`, whose
        /// event kind the contract dropped (D2).
        var symbolName: String {
            switch self {
            case .documentOpen: return "doc.text"
            case .search:       return "magnifyingglass"
            case .export:       return "square.and.arrow.up"
            }
        }
    }

    /// The source row's own identifier, so a session-log row and a History row for the same
    /// activity agree, and so grouping is stable across re-fetches.
    let id: UUID

    /// What happened.
    let kind: Kind

    /// When it happened. Non-optional here even though every source column is optional for
    /// CloudKit compatibility: an activity with no timestamp cannot be placed in a session at all,
    /// so ``ResearchTrailSessions/activities(in:limit:)`` drops those rows rather than inventing a
    /// time for them.
    let timestamp: Date

    /// The project active at write time, or `nil`. Carried so a future project-scoped session log
    /// needs no second fetch; the log itself is global today.
    let projectId: UUID?
}

// MARK: - DerivedResearchSession

/// A bounded window of activity, computed from timestamps alone.
///
/// ## The bug this shape removes
/// Sessions used to be *stored*: `AppState.logEvent` held the open `ResearchSession` in memory and
/// stamped `endedAt` only when a **later** event arrived after the idle interval, in the same
/// process. A session that ended because the app quit was therefore never closed — its `endedAt`
/// stayed `nil` forever, and `SessionLogView` had to paper over it by falling back to "the last
/// event's timestamp" and re-deriving "Ongoing" itself. The Wave R contract calls this an
/// "inherited defect to fix, not carry over".
///
/// Deriving the boundaries from the timestamps removes it by construction: ``endedAt`` is the last
/// activity in the group, always, whatever the app did afterwards. "Ongoing" becomes a question
/// about *now* (``isOngoing(asOf:idleInterval:)``) rather than a stored fact that a crash can
/// falsify.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
struct DerivedResearchSession: Identifiable, Equatable, Sendable {

    /// The first activity's id. Stable across re-fetches of the same data, which is what a
    /// `ForEach` needs, and unique because it is a source row's id.
    let id: UUID

    /// When the session's first activity happened.
    let startedAt: Date

    /// When its last activity happened. Never `nil`, never open-ended — see the type's note.
    let endedAt: Date

    /// The session's activities, oldest first.
    let activities: [ResearchTrailActivity]

    /// How many activities the session holds.
    var activityCount: Int { activities.count }

    /// How long the session lasted. Zero for a single-activity session, which is most of them.
    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    /// Whether the next activity would still join this session rather than start a new one.
    ///
    /// - Parameters:
    ///   - now: The reference time, injected so the boundary is testable.
    ///   - idleInterval: The idle rule; defaults to ``ResearchTrailSessions/idleInterval``.
    /// - Returns: `true` while the session is still within the idle window.
    func isOngoing(asOf now: Date = .now,
                   idleInterval: TimeInterval = ResearchTrailSessions.idleInterval) -> Bool {
        now.timeIntervalSince(endedAt) <= idleInterval
    }
}

// MARK: - ResearchTrailSessions

/// Turns the trail tables into sessions at **read** time (Wave R-0 Q1a, contract "What the app
/// will track").
///
/// `ResearchSession`/`SessionEvent` are retired: they carried no `projectId`, their payload was an
/// untyped JSON blob, and they recorded a second copy of events the typed tables already held.
/// What they did provide — the 30-minute grouping — is a dozen lines of arithmetic over data the
/// app stores anyway, and that is this type.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
///   1.1 — Wave R-2a review fixes: ``datedActivityCount(in:)`` added, so a page that skips
///          `nil`-timestamped rows is compared against a total that skips them too
enum ResearchTrailSessions {

    /// After this much inactivity, the next activity starts a new session.
    ///
    /// 30 minutes, unchanged from `AppState.sessionExpiryInterval`, which this replaces. The
    /// number is quoted to users in the Research Sessions footers on both platforms, so it is not
    /// free to change.
    static let idleInterval: TimeInterval = 30 * 60

    // MARK: - Grouping

    /// Groups activities into sessions on the idle rule.
    ///
    /// A pure function over values: no context, no fetch, no clock. That is what makes the
    /// boundary behaviour — including the case the stored model got wrong, a session whose app was
    /// killed — testable at all.
    ///
    /// - Parameters:
    ///   - activities: The activities to group, in any order. Sorted here, ascending by timestamp
    ///     and then by id so two runs over the same set always produce the same sessions even when
    ///     two rows share a timestamp to the microsecond.
    ///   - idleInterval: The gap that ends a session. Defaults to ``idleInterval``.
    /// - Returns: Sessions **newest first**, each holding its activities oldest first.
    static func group(_ activities: [ResearchTrailActivity],
                      idleInterval: TimeInterval = idleInterval) -> [DerivedResearchSession] {
        guard !activities.isEmpty else { return [] }

        let ordered = activities.sorted {
            $0.timestamp == $1.timestamp
                ? $0.id.uuidString < $1.id.uuidString
                : $0.timestamp < $1.timestamp
        }

        var sessions: [DerivedResearchSession] = []
        var current: [ResearchTrailActivity] = []

        func closeCurrent() {
            guard let first = current.first, let last = current.last else { return }
            sessions.append(DerivedResearchSession(id: first.id,
                                                   startedAt: first.timestamp,
                                                   endedAt: last.timestamp,
                                                   activities: current))
        }

        for activity in ordered {
            if let previous = current.last,
               activity.timestamp.timeIntervalSince(previous.timestamp) > idleInterval {
                closeCurrent()
                current = []
            }
            current.append(activity)
        }
        closeCurrent()

        return sessions.reversed()
    }

    // MARK: - Loading

    /// Reads a bounded, newest-first window of the whole trail as activities.
    ///
    /// ## Why the window is computed twice
    /// Each table is fetched with its own `fetchLimit`, and the merged result is then truncated to
    /// `limit` again. Without the second truncation the window would be *skewed*: five hundred
    /// document visits might span a week while five hundred searches span three years, so the
    /// older half of the merged list would show searches with the reading around them missing, and
    /// the derived sessions there would be wrong rather than merely partial.
    ///
    /// Truncating the merge is sound because any activity newer than the cut-off is, by
    /// definition, among the newest `limit` of its own table too — so it was fetched.
    ///
    /// Rows with a `nil` timestamp are skipped. Every one of those columns is optional only for
    /// CloudKit schema compatibility and is non-nil in practice; an activity with no time cannot
    /// be placed on a timeline, and guessing one would fabricate a session boundary.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - limit: How many activities to load, at most.
    /// - Returns: The activities, newest first. Fetch failures degrade to an empty section rather
    ///   than throwing — a log that cannot read is a log that shows nothing, not a crash.
    @MainActor
    static func activities(in context: ModelContext, limit: Int) -> [ResearchTrailActivity] {
        var visitPage = FetchDescriptor<ReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)])
        visitPage.fetchLimit = limit
        var searchPage = FetchDescriptor<SearchHistoryEntry>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)])
        searchPage.fetchLimit = limit
        var exportPage = FetchDescriptor<ExportHistoryEntry>(
            sortBy: [SortDescriptor(\.exportedAt, order: .reverse)])
        exportPage.fetchLimit = limit

        var merged: [ResearchTrailActivity] = []
        for visit in (try? context.fetch(visitPage)) ?? [] {
            guard let at = visit.accessedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: visit.id,
                kind: .documentOpen(volumeId: visit.volumeId,
                                    documentId: visit.documentId,
                                    displayTitle: visit.displayTitle),
                timestamp: at,
                projectId: visit.projectId))
        }
        for query in (try? context.fetch(searchPage)) ?? [] {
            guard let at = query.executedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: query.id,
                kind: .search(query: query.queryText, resultCount: query.resultCount),
                timestamp: at,
                projectId: query.projectId))
        }
        for export in (try? context.fetch(exportPage)) ?? [] {
            guard let at = export.exportedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: export.id,
                kind: .export(format: export.format,
                              documentCount: export.documentCount,
                              collectionName: export.collectionName),
                timestamp: at,
                projectId: export.projectId))
        }

        return Array(merged.sorted {
            $0.timestamp == $1.timestamp
                ? $0.id.uuidString > $1.id.uuidString
                : $0.timestamp > $1.timestamp
        }.prefix(limit))
    }

    /// How many **rows** the whole trail holds, across all three tables — timestamp or not.
    ///
    /// Three `fetchCount`s. This is the number a delete would remove, so it is what the Settings
    /// row quotes and what decides whether the delete control is enabled. It is deliberately *not*
    /// what the session log compares its page against; see ``datedActivityCount(in:)``.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func totalActivityCount(in context: ModelContext) -> Int {
        let visits = (try? context.fetchCount(FetchDescriptor<ReadingHistoryEntry>())) ?? 0
        let searches = (try? context.fetchCount(FetchDescriptor<SearchHistoryEntry>())) ?? 0
        let exports = (try? context.fetchCount(FetchDescriptor<ExportHistoryEntry>())) ?? 0
        return visits + searches + exports
    }

    /// How many trail rows carry a timestamp, and can therefore appear in a session.
    ///
    /// ## Why this is separate from ``totalActivityCount(in:)``
    /// ``activities(in:limit:)`` skips rows with a `nil` timestamp — it has to, since an activity
    /// with no time cannot be placed on a timeline. Comparing that page against a count that
    /// *included* those rows desynchronises the two: `loadedActivities < totalActivities` stays
    /// true no matter how far the reader pages, so "Show More" never exhausts, and a store whose
    /// rows are all undated reports itself non-empty and draws a blank list instead of the empty
    /// state. Counting the same population the page is drawn from removes both.
    ///
    /// The three predicates compare an optional column against a **typed** `nil` binding, the form
    /// `HistoryScope.unfiled` established here — `$0.accessedAt != nil` alone leaves the macro
    /// without a type for the literal.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func datedActivityCount(in context: ModelContext) -> Int {
        let noDate: Date? = nil
        let visits = (try? context.fetchCount(FetchDescriptor<ReadingHistoryEntry>(
            predicate: #Predicate { $0.accessedAt != noDate }))) ?? 0
        let searches = (try? context.fetchCount(FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { $0.executedAt != noDate }))) ?? 0
        let exports = (try? context.fetchCount(FetchDescriptor<ExportHistoryEntry>(
            predicate: #Predicate { $0.exportedAt != noDate }))) ?? 0
        return visits + searches + exports
    }
}

// MARK: - SessionLogSnapshot

/// The Session Log's data, read once (Wave R-2a).
///
/// ## Not a `@Query`
/// `SessionLogView` held a live, unbounded `@Query` over every `ResearchSession` and walked each
/// one's `events` relationship in a computed property on every render. Both types were
/// CloudKit-mirrored and nothing prunes the trail (contract D5), so the pane re-rendered its whole
/// list once per drip-import batch — the shape `NotesPaneSnapshot` and ``HistoryPaneSnapshot``
/// were written to stop. This does the work once, bounded, and hands the view plain values.
///
/// ## The known limit
/// The window is the newest ``defaultPageLimit`` activities. The **oldest** session shown may
/// therefore extend further back than the rows loaded — everything newer than it is complete. The
/// view says so rather than implying the page is the whole trail; the alternative, loading
/// everything to make one session's start time exact, is what the `@Query` did.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
///   1.1 — Wave R-2a review fixes: ``totalActivities`` counts *datable* rows, so `hasMore` can
///          actually reach `false` and an all-undated store draws its empty state
struct SessionLogSnapshot: Equatable, Sendable {

    /// The derived sessions, newest first.
    let sessions: [DerivedResearchSession]
    /// How many activities were loaded into ``sessions``.
    let loadedActivities: Int
    /// How many activities the trail holds that **could** be loaded — rows carrying a timestamp.
    ///
    /// Not the row count: see ``ResearchTrailSessions/datedActivityCount(in:)`` for why the two
    /// have to describe the same population.
    let totalActivities: Int
    /// The activity limit this snapshot was fetched with.
    let pageLimit: Int

    /// The state before the first fetch.
    static let empty = SessionLogSnapshot(sessions: [], loadedActivities: 0,
                                          totalActivities: 0, pageLimit: defaultPageLimit)

    /// How many activities the log loads to begin with.
    ///
    /// Higher than ``HistoryPaneSnapshot/defaultPageLimit`` because this page is split across
    /// three tables and then grouped: 500 would be 500 *total*, which on a busy trail is a few
    /// days. A thousand small rows is still a cheap main-thread fetch.
    static let defaultPageLimit = 1_000

    /// How much "Show More" adds each time.
    static let pageIncrement = 1_000

    /// Whether the trail holds more than this page loaded.
    var hasMore: Bool { loadedActivities < totalActivities }

    /// Whether there is any session to show. An all-undated store is empty **here** even though it
    /// still holds deletable rows — the log draws sessions, and there are none. The delete control
    /// asks a different question and reads `ResearchSessionsSummary.isEmpty` instead.
    var isEmpty: Bool { totalActivities == 0 }

    /// Reads one page of the trail and groups it.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - limit: Maximum activities to load. Defaults to ``defaultPageLimit``.
    @MainActor
    static func fetch(from context: ModelContext,
                      limit: Int = defaultPageLimit) -> SessionLogSnapshot {
        let activities = ResearchTrailSessions.activities(in: context, limit: limit)
        return SessionLogSnapshot(
            sessions: ResearchTrailSessions.group(activities),
            loadedActivities: activities.count,
            totalActivities: ResearchTrailSessions.datedActivityCount(in: context),
            pageLimit: limit)
    }
}
