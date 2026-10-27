// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with an
///          initialiser, for the web edition's history
public struct ResearchTrailActivity: Identifiable, Equatable, Sendable {

    /// What kind of activity this is, with the fields that kind carries.
    public enum Kind: Equatable, Sendable {
        /// A document was opened.
        case documentOpen(volumeId: String, documentId: String, displayTitle: String?)
        /// A search was submitted.
        case search(query: String, resultCount: Int)
        /// A collection was exported.
        case export(format: String, documentCount: Int, collectionName: String?)

        /// The SF Symbol the session log draws for this kind. Not user-facing, so not localised —
        /// the same three glyphs the old `SessionEventRowView` used, minus `note.text`, whose
        /// event kind the contract dropped (D2).
        public var symbolName: String {
            switch self {
            case .documentOpen: return "doc.text"
            case .search:       return "magnifyingglass"
            case .export:       return "square.and.arrow.up"
            }
        }
    }

    /// The source row's own identifier, so a session-log row and a History row for the same
    /// activity agree, and so grouping is stable across re-fetches.
    public let id: UUID

    /// What happened.
    public let kind: Kind

    /// When it happened. Non-optional here even though every source column is optional for
    /// CloudKit compatibility: an activity with no timestamp cannot be placed in a session at all,
    /// so the app's `ResearchTrailSessions.activities(in:limit:)` drops those rows rather than
    /// inventing a time for them.
    public let timestamp: Date

    /// The project active at write time, or `nil`. Carried so a future project-scoped session log
    /// needs no second fetch; the log itself is global today.
    public let projectId: UUID?

    /// Creates an activity from a trail row's values.
    ///
    /// - Parameters:
    ///   - id: The source row's id.
    ///   - kind: What happened, with its fields.
    ///   - timestamp: When it happened.
    ///   - projectId: The project active at write time, or `nil`.
    public init(id: UUID, kind: Kind, timestamp: Date, projectId: UUID?) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.projectId = projectId
    }
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
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with an
///          initialiser, for the web edition's history
public struct DerivedResearchSession: Identifiable, Equatable, Sendable {

    /// The first activity's id. Stable across re-fetches of the same data, which is what a
    /// `ForEach` needs, and unique because it is a source row's id.
    public let id: UUID

    /// When the session's first activity happened.
    public let startedAt: Date

    /// When its last activity happened. Never `nil`, never open-ended — see the type's note.
    public let endedAt: Date

    /// The session's activities, oldest first.
    public let activities: [ResearchTrailActivity]

    /// Creates a session from its bounds and activities, as ``ResearchTrailSessions/group(_:idleInterval:)``
    /// derives them.
    public init(id: UUID, startedAt: Date, endedAt: Date, activities: [ResearchTrailActivity]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activities = activities
    }

    /// How many activities the session holds.
    public var activityCount: Int { activities.count }

    /// How long the session lasted. Zero for a single-activity session, which is most of them.
    public var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    /// Whether the next activity would still join this session rather than start a new one.
    ///
    /// - Parameters:
    ///   - now: The reference time, injected so the boundary is testable.
    ///   - idleInterval: The idle rule; defaults to ``ResearchTrailSessions/idleInterval``.
    /// - Returns: `true` while the session is still within the idle window.
    public func isOngoing(asOf now: Date = .now,
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
///   1.1 — Wave R-2a review fixes: `datedActivityCount(in:)` added, so a page that skips
///          `nil`-timestamped rows is compared against a total that skips them too
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with the
///          newest window's merge (``newestFirst(_:limit:)``), for the web edition's history; the loaders,
///          which read the store, stay in the app's `ResearchTrailSessions+App.swift`
public enum ResearchTrailSessions {

    /// After this much inactivity, the next activity starts a new session.
    ///
    /// 30 minutes, unchanged from `AppState.sessionExpiryInterval`, which this replaces. The
    /// number is quoted to users in the Research Sessions footers on both platforms, so it is not
    /// free to change.
    public static let idleInterval: TimeInterval = 30 * 60

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
    public static func group(_ activities: [ResearchTrailActivity],
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

    // MARK: - The newest window

    /// The newest `limit` of a trail's activities, newest first — the window the Session Log and the
    /// History read.
    ///
    /// ## Why the window is computed twice
    /// A host reads each table with its own limit, and the merged result is then truncated to `limit`
    /// again, here. Without the second truncation the window would be *skewed*: five hundred
    /// document visits might span a week while five hundred searches span three years, so the
    /// older half of the merged list would show searches with the reading around them missing, and
    /// the derived sessions there would be wrong rather than merely partial.
    ///
    /// Truncating the merge is sound because any activity newer than the cut-off is, by
    /// definition, among the newest `limit` of its own table too — so it was read.
    ///
    /// A row with no timestamp has no activity: an activity with no time cannot be placed on a
    /// timeline, and guessing one would fabricate a session boundary, so a host skips such rows, as
    /// the app's loader does.
    ///
    /// - Parameters:
    ///   - activities: The newest `limit` rows of each table, as activities, in any order.
    ///   - limit: How many activities the window holds, at most.
    /// - Returns: The activities, newest first, ties broken by id so two reads of the same rows agree.
    public static func newestFirst(_ activities: [ResearchTrailActivity],
                                   limit: Int) -> [ResearchTrailActivity] {
        Array(activities.sorted {
            $0.timestamp == $1.timestamp
                ? $0.id.uuidString > $1.id.uuidString
                : $0.timestamp > $1.timestamp
        }.prefix(limit))
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
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with
///          ``page(of:datedActivityCount:limit:)``, the page a fetch makes of what it read, for the web
///          edition's history; `fetch(from:limit:)` stays in the app's `ResearchTrailSessions+App.swift`
public struct SessionLogSnapshot: Equatable, Sendable {

    /// The derived sessions, newest first.
    public let sessions: [DerivedResearchSession]
    /// How many activities were loaded into ``sessions``.
    public let loadedActivities: Int
    /// How many activities the trail holds that **could** be loaded — rows carrying a timestamp.
    ///
    /// Not the row count: see the app's `ResearchTrailSessions.datedActivityCount(in:)` for why the
    /// two have to describe the same population.
    public let totalActivities: Int
    /// The activity limit this snapshot was fetched with.
    public let pageLimit: Int

    /// Creates a snapshot from its parts, as ``page(of:datedActivityCount:limit:)`` makes them.
    public init(sessions: [DerivedResearchSession], loadedActivities: Int,
                totalActivities: Int, pageLimit: Int) {
        self.sessions = sessions
        self.loadedActivities = loadedActivities
        self.totalActivities = totalActivities
        self.pageLimit = pageLimit
    }

    /// The state before the first fetch.
    public static let empty = SessionLogSnapshot(sessions: [], loadedActivities: 0,
                                                 totalActivities: 0, pageLimit: defaultPageLimit)

    /// How many activities the log loads to begin with.
    ///
    /// Higher than ``HistoryPaneSnapshot/defaultPageLimit`` because this page is split across
    /// three tables and then grouped: 500 would be 500 *total*, which on a busy trail is a few
    /// days. A thousand small rows is still a cheap main-thread fetch.
    public static let defaultPageLimit = 1_000

    /// How much "Show More" adds each time.
    public static let pageIncrement = 1_000

    /// Whether the trail holds more than this page loaded.
    public var hasMore: Bool { loadedActivities < totalActivities }

    /// Whether there is any session to show. An all-undated store is empty **here** even though it
    /// still holds deletable rows — the log draws sessions, and there are none. The delete control
    /// asks a different question and reads `ResearchSessionsSummary.isEmpty` instead.
    public var isEmpty: Bool { totalActivities == 0 }

    /// One page of the trail, grouped: what a fetch makes of the window it read.
    ///
    /// - Parameters:
    ///   - activities: The window, as ``ResearchTrailSessions/newestFirst(_:limit:)`` gives it.
    ///   - datedActivityCount: How many trail rows carry a timestamp — the population the window is
    ///     drawn from, not the row count.
    ///   - limit: The activity limit the window was read with.
    /// - Returns: The snapshot.
    public static func page(of activities: [ResearchTrailActivity], datedActivityCount: Int,
                            limit: Int) -> SessionLogSnapshot {
        SessionLogSnapshot(
            sessions: ResearchTrailSessions.group(activities),
            loadedActivities: activities.count,
            totalActivities: datedActivityCount,
            pageLimit: limit)
    }
}
