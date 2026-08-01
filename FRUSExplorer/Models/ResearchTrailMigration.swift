// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchTrailMigration

/// Moves what is worth keeping out of `ResearchSession`/`SessionEvent` and into the typed trail
/// (Wave R-2a).
///
/// ## What moves, and what does not
///
/// | Legacy event | Fate | Why |
/// |---|---|---|
/// | `.searchSubmit` | migrated to ``SearchHistoryEntry``, collapsed exactly as the live writer collapsed | iOS had no `SearchHistoryEntry` producer before Wave R-4, so pre-R-4 events are the *only* record of those searches |
/// | `.export` | migrated to ``ExportHistoryEntry`` | contract D1 — nothing else records that an export happened, and the Zotero push had a real external side effect |
/// | `.documentOpen` | **dropped** | every one already has a matching ``ReadingHistoryEntry``; migrating would double every user's reading history |
/// | `.noteSave` | **dropped** | contract D2 — `ResearchNote` timestamps itself |
///
/// ### Why dropping `.documentOpen` is safe, and the one thing it costs
/// `AppState.logEvent(.documentOpen)` and `DocumentViewModel.recordReadingHistory` fired from the
/// same two views (`DocumentView`, `MacDocumentView`), and the containment ran one way: before
/// Wave R-1 `logEvent` was gated and `recordReadingHistory` was not, so
/// `SessionEvent.documentOpen ⊆ ReadingHistoryEntry` and never the reverse.
///
/// The containment is not quite total, and the exceptions are worth naming because they are what
/// this drops. `recordReadingHistory` runs only after the document actually loads: on iOS
/// `DocumentView.bootstrapViewModel` returns early when the volume is not downloaded, and records
/// only when `renderModel != nil`; on macOS `MacDocumentView.loadDocument` returns early when the
/// download manager has not appeared within two seconds. `logEvent` fired in all three cases. So
/// what is lost is a record of **opens that failed** — an undownloaded volume, an unparseable
/// document — which no surface has ever displayed and which does not belong in a list of documents
/// the user read.
///
/// ## How searches are collapsed — the live writer's rule, not a time window
/// The two producers did **different** jobs, and one of them fired far more often than it recorded:
///
/// - `AppState.logEvent(.searchSubmit)` fired on **every** execution of `SearchViewModel.search()`.
/// - `SearchViewModel.recordSearchHistory` wrote a `SearchHistoryEntry` only when the query differed
///   from the writer's anchor — the last query it had recorded. Consecutive identical
///   queries collapsed to one row **regardless of the gap between them**.
///
/// iOS re-ran `search()` for the same keywords from two documented sites: `clearVolumeScope()` and
/// the result-row tag chip. So one submitted query followed by two filter toggles is *three* events
/// and *one* recorded search, and the gap between them is a human tap — seconds, sometimes longer.
///
/// An earlier draft of this pass tried to fix that with a ±2s window sized from the gap between the
/// two *writers* (sub-millisecond, same main-actor continuation). One constant cannot do both jobs:
/// tuned for the writers it splits a filter toggle into a second row, and tuned for the taps it
/// starts pairing unrelated searches. So there is no window. This replays the events **in timestamp
/// order** and applies the producer's own rule:
///
/// 1. Existing ``SearchHistoryEntry`` rows and legacy `.searchSubmit` events are merged into one
///    stream, ordered by time (ties broken deterministically — entries first, then id).
/// 2. The stream is cut into maximal **runs of consecutive items carrying the same query text**.
///    That is precisely what the writer's anchor computed live.
/// 3. A run that already contains a real `SearchHistoryEntry` writes nothing — the app recorded
///    that search at the time, and the events beside it are the re-runs the producer suppressed.
/// 4. A run with no entry writes exactly **one** row, from its first event.
///
/// A different query in between ends the run, so `A A B A` migrates as three searches, which is what
/// the user actually ran and what the live writer would have recorded. The one thing this
/// deliberately does *not* do is split `A … A` with nothing in between into two rows because the two
/// are hours apart: the live writer did not, and inventing a threshold here would re-introduce the
/// constant this change exists to remove.
///
/// `ExportHistoryEntry` is new in this change, so no export can already have a counterpart and
/// exports migrate one-for-one.
///
/// ## The schema interlock (why this may do nothing at all)
/// The pass **writes** `SearchHistoryEntry` and `ExportHistoryEntry` rows and **deletes** the
/// `SessionEvent` rows they replace. Those are two CloudKit operations with very different
/// reliability: a delete of an already-deployed record type always syncs, while a write of a record
/// type whose Production schema has not been promoted always fails — that is #488, and
/// ``CloudKitSchemaInventory/identifiersAwaitingDeploy`` is the app's own record of being in that
/// state. Running anyway would propagate the deletions to every device and none of the
/// replacements: on a second device, or after a reinstall, the export history would simply be gone.
///
/// So R-7's marker is an **interlock**, not a notice. If any identifier awaiting deploy belongs to
/// a record type this pass writes, the pass defers, logs why, and touches nothing. It runs by
/// itself at the launch after the owner clears the marker (step 4 of the CloudKit checklist in
/// `CLAUDE.md`); nothing needs to be remembered.
///
/// ## Idempotence
/// Every migrated row takes **the source event's own `id`**. Re-running therefore finds the row
/// already present and does nothing, whether the re-run is on the same device, on a second device
/// that has already imported the first one's rows, or against events an older build has since
/// re-synced. There is no "migration done" flag anywhere — see *Why there is no marker*.
///
/// ## Why there is no marker
/// A `UserDefaults` flag would make this a one-shot, and one-shot is wrong here. A device still on
/// a build **without** this change goes on writing `SessionEvent`s and syncing them; a device that
/// had already flipped its flag would never look again and those events would sit in the store
/// unread and unmigrated forever. Instead the pass is *self-limiting*: its first act is a
/// `fetchCount`, and once the legacy tables are empty it returns having touched nothing.
///
/// ## Multi-device safety
/// Two devices can both hold the same legacy events and both migrate them. Three things bound
/// what that can do:
///
/// 1. **Deterministic ids.** A device that has already imported the other's migrated rows skips
///    them outright — the id is the event's, so both devices compute the same one.
/// 2. **It runs after imports settle.** `FRUSExplorerApp` calls this from the debounced
///    import-settled observer on CloudKit installs, the same placement `OrphanedTagRepair` uses and
///    for the same reason: never against a partial store mid-sync. It *also* runs unconditionally
///    at boot, because a device signed out of iCloud gets no import-settled event at all and would
///    otherwise never migrate — and nothing reads `SessionEvent` any more, so on that device the
///    searches and exports would be invisible for as long as it stayed signed out. The pass is
///    self-limiting, so the extra call costs one `fetchCount`.
/// 3. **The residual failure is benign.** In that window both devices write a row with the same
///    `id` and identical fields, and the trail shows the query twice. It is visible, it is
///    per-entry deletable (Wave R-3), and it is not data loss. `HistoryPaneSnapshot` gives every
///    loaded row a distinct *display* identity so `ForEach` behaves, and
///    `HistoryTrailAdmin.deleteSearch` removes **every** copy sharing the id, so the swipe does
///    what it says.
///
/// Those duplicates are deliberately **not** auto-collapsed. `DuplicateRecordCleanup` groups by
/// `id` and then breaks ties on `createdAt` and `id.uuidString` — but every member of a same-`id`
/// group ties on `id.uuidString` by definition, and two rows written by the same migration tie on
/// their timestamp too, so the keeper falls out of fetch order and two devices can pick
/// *different* keepers and delete each other's copy, removing both. Showing a row twice is a
/// smaller harm than deleting the user's research record on a coin-flip, and contract D5 is
/// explicit that nothing may silently delete this table.
///
/// ## The gate does not apply
/// This runs whether or not "Log Research Sessions" is on. It collects nothing new — it moves
/// records the user already has into a store where they can finally be seen and deleted. Skipping
/// it when the switch is off would silently destroy them instead, which is the opposite of what
/// the switch promises ("anything recorded before you turned it off stays until you delete it").
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
///   1.1 — Wave R-2a review fixes: the ±2s `pairingTolerance` is **gone**, replaced by the live
///          writer's consecutive-identical rule over a merged, time-ordered stream (it collapsed
///          three events from one query into three rows on every shipped iOS build); the pass now
///          defers while any record type it writes is awaiting a CloudKit Production deploy; every
///          fetch that feeds a decision is explicitly ordered; a `SessionEvent` with a `nil`
///          `timestamp` falls back to its `createdAt` instead of being destroyed; and the legacy
///          sweep no longer runs when the event fetch disagrees with the count that preceded it
@MainActor
enum ResearchTrailMigration {

    // MARK: - The schema interlock

    /// The CloudKit record types this pass writes rows into.
    ///
    /// Deliberately not derived from anything: it is the list a reader has to check against the
    /// `context.insert` calls below, and a derived version would be a second thing to get wrong.
    static let writtenRecordTypes: Set<String> = [
        "CD_SearchHistoryEntry",
        "CD_ExportHistoryEntry",
    ]

    /// The identifiers awaiting a Production deploy that belong to a record type this pass writes.
    ///
    /// Non-empty means running would push deletions CloudKit accepts and replacements it rejects.
    ///
    /// - Parameter awaitingDeploy: The pending list; defaults to
    ///   ``CloudKitSchemaInventory/identifiersAwaitingDeploy``. A parameter so the interlock is
    ///   testable from both sides without editing a checked-in constant.
    /// - Returns: The blocking identifiers, in the order given.
    static func blockingIdentifiers(
        in awaitingDeploy: [String] = CloudKitSchemaInventory.identifiersAwaitingDeploy
    ) -> [String] {
        awaitingDeploy.filter { identifier in
            writtenRecordTypes.contains(String(identifier.prefix(while: { $0 != "." })))
        }
    }

    /// Whether the legacy sweep may run, given what the two reads of the event table saw.
    ///
    /// The sweep deletes the whole `SessionEvent` table. It is only safe to do that when the rows
    /// this pass actually read are *all* the rows: if the fetch failed — `try?` degrades to `[]` —
    /// or came back short, everything would be deleted and nothing migrated, and the counters would
    /// report a clean run.
    ///
    /// A free function so the rule is testable without contriving a SwiftData fetch failure.
    ///
    /// - Parameters:
    ///   - fetched: How many events the migration read.
    ///   - counted: How many `fetchCount` said there were, moments earlier.
    static func maySweepLegacyTables(fetched: Int, counted: Int) -> Bool { fetched == counted }

    // MARK: - Result

    /// What one pass did — returned so the outcome is assertable without re-reading the store, and
    /// logged so a device that migrated thousands of rows leaves a trace.
    struct Result: Equatable, Sendable {

        /// Whether there was anything to look at. `false` means the legacy tables were empty and
        /// the pass exited after one `fetchCount` — or that it never got that far, in which case
        /// one of the two flags below says why.
        var didRun = false

        /// Whether the pass declined to run because a record type it writes is still awaiting a
        /// CloudKit Production deploy. See the type's *schema interlock* note.
        var deferredAwaitingSchemaDeploy = false

        /// Whether the pass abandoned itself because the `SessionEvent` fetch disagreed with the
        /// `fetchCount` that preceded it. Nothing is migrated and nothing is swept; the next launch
        /// tries again.
        var abandonedIncompleteLegacyRead = false

        /// Searches written to ``SearchHistoryEntry``.
        var searchesMigrated = 0
        /// Search events whose row was already present — a re-run, or another device's work.
        var searchesAlreadyMigrated = 0
        /// Search events suppressed because a real ``SearchHistoryEntry`` already stands for that
        /// run of the query — the post-R-4 shape, where the app wrote both records.
        var searchesPairedWithExistingEntry = 0
        /// Search events suppressed as re-runs of the row this pass just wrote — the filter-toggle
        /// shape, which fired the event but wrote no entry live.
        var searchesCollapsedAsRepeat = 0

        /// Exports written to ``ExportHistoryEntry``.
        var exportsMigrated = 0
        /// Export events whose row was already present.
        var exportsAlreadyMigrated = 0

        /// `.documentOpen` events dropped — reading history already holds them.
        var documentOpensDropped = 0
        /// `.noteSave` events dropped (contract D2).
        var noteSavesDropped = 0
        /// Events whose type or payload could not be read.
        var unreadableDropped = 0

        /// Legacy `SessionEvent` rows removed.
        var legacyEventsDeleted = 0
        /// Legacy `ResearchSession` rows removed.
        var legacySessionsDeleted = 0

        /// Whether the pass wrote anything.
        var wroteAnything: Bool { searchesMigrated > 0 || exportsMigrated > 0 }
    }

    // MARK: - Running

    /// Migrates what is worth keeping, then removes the legacy tables' contents.
    ///
    /// Safe to call on every launch: it costs one array-literal check plus one `fetchCount` when
    /// there is nothing to do.
    ///
    /// The write and the delete are **separate saves**, in that order. An interruption between
    /// them leaves the migrated rows in place and the legacy rows still present, which the next
    /// pass resolves without duplicating anything (the ids match). The reverse order would risk
    /// deleting the source before its replacement was durable.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read and mutate.
    ///   - awaitingDeploy: The CloudKit identifiers not yet promoted to Production; defaults to
    ///     ``CloudKitSchemaInventory/identifiersAwaitingDeploy``. See ``blockingIdentifiers(in:)``.
    /// - Returns: What the pass did.
    @discardableResult
    static func run(
        context: ModelContext,
        awaitingDeploy: [String] = CloudKitSchemaInventory.identifiersAwaitingDeploy
    ) -> Result {
        var result = Result()

        let blocking = blockingIdentifiers(in: awaitingDeploy)
        guard blocking.isEmpty else {
            result.deferredAwaitingSchemaDeploy = true
            // Always-on: this is the state #488 describes, and the console of a TestFlight device
            // is where it would otherwise have to be noticed.
            print("[ResearchTrailMigration] Deferred: \(blocking.joined(separator: ", ")) "
                  + "await a CloudKit Production deploy. Migrating now would sync the deletion of "
                  + "the legacy events and not their replacements. Nothing was changed.")
            return result
        }

        let legacyEventCount = (try? context.fetchCount(FetchDescriptor<SessionEvent>())) ?? 0
        let legacySessionCount = (try? context.fetchCount(FetchDescriptor<ResearchSession>())) ?? 0
        guard legacyEventCount > 0 || legacySessionCount > 0 else { return result }
        result.didRun = true

        // Full fetches, deliberately. Their cost is paid only while legacy rows exist — which is
        // once per device, plus whenever an older build syncs more in — never on an ordinary
        // launch. The bounded alternative would be a `#Predicate` over the optional `timestamp`
        // window, and this codebase has already recorded that SwiftData's translation of optional
        // comparisons is the kind of thing that fails at runtime rather than at compile time
        // (see `HistoryPaneSnapshot`'s note on the free-text filter).
        //
        // Every one of them is **sorted**. Fetch order is not defined, and all three feed
        // decisions: an unordered event fetch would collapse runs differently from one run to the
        // next, and an unordered entry fetch would decide which run an entry lands in by accident.
        let events = (try? context.fetch(FetchDescriptor<SessionEvent>(
            sortBy: [SortDescriptor(\.timestamp), SortDescriptor(\.sortOrder)]))) ?? []

        guard maySweepLegacyTables(fetched: events.count, counted: legacyEventCount) else {
            result.abandonedIncompleteLegacyRead = true
            print("[ResearchTrailMigration] Abandoned: read \(events.count) of "
                  + "\(legacyEventCount) legacy event(s). Nothing was migrated and nothing was "
                  + "deleted; the next launch tries again.")
            return result
        }

        // `SortDescriptor` needs a `Comparable` value and `UUID` is not one, so the id tie-break
        // is applied in memory (see `searchRuns`) rather than in the fetch.
        let existingSearches = (try? context.fetch(FetchDescriptor<SearchHistoryEntry>(
            sortBy: [SortDescriptor(\.executedAt)]))) ?? []
        let existingExportIds = Set(
            ((try? context.fetch(FetchDescriptor<ExportHistoryEntry>(
                sortBy: [SortDescriptor(\.exportedAt)]))) ?? []).map(\.id))

        let searchIdsPresent = Set(existingSearches.map(\.id))
        var exportIdsPresent = existingExportIds

        // Pass 1: everything that is decided event by event, plus the search events the run
        // grouping in pass 2 needs.
        var searchEvents: [SearchEvent] = []
        for event in events {
            // A `nil` timestamp is not a reason to destroy a readable record: `SessionEvent.init`
            // set `createdAt` to the very same instant, so the fallback is exact rather than a
            // guess. Only an event with neither is genuinely undatable.
            guard let timestamp = event.timestamp ?? event.createdAt,
                  let kind = ResearchEventKind.decode(from: event) else {
                result.unreadableDropped += 1
                continue
            }

            switch kind {
            case .documentOpen:
                result.documentOpensDropped += 1

            case .noteSave:
                result.noteSavesDropped += 1

            case .searchSubmit(let rawQuery, let resultCount):
                let query = normalized(rawQuery)
                guard !query.isEmpty else {
                    result.unreadableDropped += 1
                    continue
                }
                // Its row is already here — this device's earlier pass, or another device's.
                // Dropping it from the stream rather than counting it twice: the row itself is in
                // `existingSearches` and stands for the event in the grouping below.
                if searchIdsPresent.contains(event.id) {
                    result.searchesAlreadyMigrated += 1
                    continue
                }
                searchEvents.append(SearchEvent(id: event.id, query: query, rawQuery: rawQuery,
                                                resultCount: resultCount, at: timestamp))

            case .export(let format, let documentCount):
                if exportIdsPresent.contains(event.id) {
                    result.exportsAlreadyMigrated += 1
                    continue
                }
                context.insert(ExportHistoryEntry(
                    id: event.id,
                    format: format,
                    documentCount: documentCount,
                    collectionName: nil,
                    projectId: nil,
                    exportedAt: timestamp))
                exportIdsPresent.insert(event.id)
                result.exportsMigrated += 1
            }
        }

        // Pass 2: the live writer's rule, replayed. See the type's note.
        for run in searchRuns(events: searchEvents, entries: existingSearches) {
            if run.holdsExistingEntry {
                result.searchesPairedWithExistingEntry += run.events.count
                continue
            }
            guard let first = run.events.first else { continue }
            context.insert(SearchHistoryEntry(
                id: first.id,
                queryText: first.rawQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                resultCount: first.resultCount,
                projectId: nil,
                executedAt: first.at))
            result.searchesMigrated += 1
            result.searchesCollapsedAsRepeat += run.events.count - 1
        }

        // Durable before the source goes.
        try? context.save()

        let removed = ResearchSessionAdmin.deleteAll(context: context)
        result.legacyEventsDeleted = removed.events
        result.legacySessionsDeleted = removed.sessions

        // Always-on, like `DuplicateRecordCleanup`'s: this deletes CloudKit-mirrored user records,
        // and a persistent line is the only post-hoc evidence of what a pass did.
        print("[ResearchTrailMigration] Retired \(removed.events) event(s) in "
              + "\(removed.sessions) session(s): \(result.searchesMigrated) search(es) migrated, "
              + "\(result.searchesPairedWithExistingEntry) already had an entry, "
              + "\(result.searchesCollapsedAsRepeat) collapsed as re-runs of one query, "
              + "\(result.exportsMigrated) export(s) migrated, "
              + "\(result.documentOpensDropped) document open(s) and "
              + "\(result.noteSavesDropped) note save(s) dropped as redundant.")

        return result
    }

    // MARK: - The search stream

    /// One legacy `.searchSubmit`, decoded, waiting to be grouped.
    private struct SearchEvent {
        /// The source event's id — which the migrated row takes.
        let id: UUID
        /// The comparison form of the query (see ``normalized(_:)``).
        let query: String
        /// The query exactly as recorded, which is what a migrated row stores.
        let rawQuery: String
        /// The match count the event carried.
        let resultCount: Int
        /// When it fired.
        let at: Date
    }

    /// A maximal stretch of consecutive stream items carrying the same query.
    private struct SearchRun {
        /// Whether a real ``SearchHistoryEntry`` falls inside it — in which case the app already
        /// recorded this search and none of the events beside it should be written.
        let holdsExistingEntry: Bool
        /// The events in the run, oldest first.
        let events: [SearchEvent]
    }

    /// Cuts the merged event + entry stream into runs of consecutive identical queries.
    ///
    /// The whole of the collapsing rule lives here, as a pure function over values, so the
    /// behaviour that decides whether a user's query log gains a duplicate row can be tested
    /// without a store.
    ///
    /// Entries with no `executedAt` are left out: an item with no time cannot be placed in a
    /// sequence, and putting it at `.distantPast` would let it absorb a genuinely separate search.
    /// Its id is still known to the caller, which is what prevents a re-migration.
    ///
    /// - Parameters:
    ///   - events: The decoded search events.
    ///   - entries: Every ``SearchHistoryEntry`` already in the store.
    /// - Returns: The runs holding at least one event, oldest first.
    private static func searchRuns(events: [SearchEvent],
                                   entries: [SearchHistoryEntry]) -> [SearchRun] {
        guard !events.isEmpty else { return [] }

        /// A stream position: an event to decide about, or an entry that decides for it.
        struct Item {
            let query: String
            let at: Date
            let id: UUID
            let event: SearchEvent?
            /// Entries sort before events at an identical instant, so an entry that ties with an
            /// event of the same query is inside its run rather than adjacent to it. With
            /// different queries the choice is arbitrary but must be *fixed*, which is the point.
            var rank: Int { event == nil ? 0 : 1 }
        }

        var stream: [Item] = events.map {
            Item(query: $0.query, at: $0.at, id: $0.id, event: $0)
        }
        stream.append(contentsOf: entries.compactMap { entry in
            guard let at = entry.executedAt else { return nil }
            return Item(query: normalized(entry.queryText), at: at, id: entry.id, event: nil)
        })
        stream.sort {
            if $0.at != $1.at { return $0.at < $1.at }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.id.uuidString < $1.id.uuidString
        }

        var runs: [SearchRun] = []
        var currentQuery: String?
        var currentEvents: [SearchEvent] = []
        var currentHasEntry = false

        func closeCurrent() {
            guard !currentEvents.isEmpty else { return }
            runs.append(SearchRun(holdsExistingEntry: currentHasEntry, events: currentEvents))
        }

        for item in stream {
            if item.query != currentQuery {
                closeCurrent()
                currentQuery = item.query
                currentEvents = []
                currentHasEntry = false
            }
            if let event = item.event {
                currentEvents.append(event)
            } else {
                currentHasEntry = true
            }
        }
        closeCurrent()

        return runs
    }

    // MARK: - Helpers

    /// The comparison form for query grouping.
    ///
    /// The two writers trimmed differently — `logEvent` used `.whitespaces`, `recordSearchHistory`
    /// `.whitespacesAndNewlines` — so a query the user pasted with a trailing newline would not
    /// match itself byte for byte. Case is **not** folded: the recorded text is the user's own
    /// wording, and two searches differing only in case are two searches — which is also what the
    /// live anchor comparison did.
    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
