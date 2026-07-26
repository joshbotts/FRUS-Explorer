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
/// | `.searchSubmit` | migrated to ``SearchHistoryEntry``, de-duplicated | iOS had no `SearchHistoryEntry` producer before Wave R-4, so pre-R-4 events are the *only* record of those searches |
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
/// ### Why `.searchSubmit` needs de-duplication (and `.export` does not)
/// Historically `.searchSubmit` fired on iOS only and iOS had no `SearchHistoryEntry` producer, so
/// those events have no counterpart and must be migrated. **Wave R-4 added the iOS producer and
/// deliberately kept the event**, so anything recorded since R-4 shipped *does* have a counterpart
/// and migrating it would duplicate. Nothing on the record distinguishes the two — not the
/// platform, not the payload — so the pairing is done on content: see ``pairingTolerance``.
///
/// `ExportHistoryEntry` is new in this change, so no export can already have a counterpart.
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
///    import-settled observer on CloudKit installs (and directly at boot on local-only ones), the
///    same placement `OrphanedTagRepair` uses and for the same reason: never against a partial
///    store mid-sync. That narrows the race to two devices whose first post-update launches
///    overlap before either's push lands.
/// 3. **The residual failure is benign.** In that window both devices write a row with the same
///    `id` and identical fields, and the trail shows the query twice. It is visible, it is
///    per-entry deletable (Wave R-3), and it is not data loss.
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
@MainActor
enum ResearchTrailMigration {

    // MARK: - Tuning

    /// How far apart a legacy `.searchSubmit` event and an existing ``SearchHistoryEntry`` may be
    /// and still count as two records of **one** search.
    ///
    /// **Two seconds.** The two writers fired in the same main-actor continuation:
    /// `SearchViewModel.search()` logged the event as its last statement, and
    /// `SearchView.runSearch()` called `recordSearchHistory` on the next line, with nothing
    /// awaited in between. The real gap is sub-millisecond, so two seconds is roughly three orders
    /// of magnitude of headroom.
    ///
    /// It is deliberately not larger. A false **positive** (pairing two records that are not a
    /// pair) silently drops one search from a log the contract calls a method appendix; a false
    /// **negative** leaves a visible duplicate row. The tighter window favours keeping data, and
    /// the only thing it can miss is a pairing that never existed in the first place.
    static let pairingTolerance: TimeInterval = 2

    // MARK: - Result

    /// What one pass did — returned so the outcome is assertable without re-reading the store, and
    /// logged so a device that migrated thousands of rows leaves a trace.
    struct Result: Equatable, Sendable {

        /// Whether there was anything to look at. `false` means the legacy tables were empty and
        /// the pass exited after one `fetchCount`.
        var didRun = false

        /// Searches written to ``SearchHistoryEntry``.
        var searchesMigrated = 0
        /// Search events whose row was already present — a re-run, or another device's work.
        var searchesAlreadyMigrated = 0
        /// Search events paired with an existing entry and therefore not written (the post-R-4
        /// shape).
        var searchesPairedWithExistingEntry = 0

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
    /// Safe to call on every launch: it costs one `fetchCount` when there is nothing to do.
    ///
    /// The write and the delete are **separate saves**, in that order. An interruption between
    /// them leaves the migrated rows in place and the legacy rows still present, which the next
    /// pass resolves without duplicating anything (the ids match). The reverse order would risk
    /// deleting the source before its replacement was durable.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read and mutate.
    ///   - tolerance: The search-pairing window; defaults to ``pairingTolerance``. A parameter so
    ///     the pairing can be tested at both ends without waiting two seconds.
    /// - Returns: What the pass did.
    @discardableResult
    static func run(context: ModelContext,
                    tolerance: TimeInterval = pairingTolerance) -> Result {
        var result = Result()

        let legacyEventCount = (try? context.fetchCount(FetchDescriptor<SessionEvent>())) ?? 0
        let legacySessionCount = (try? context.fetchCount(FetchDescriptor<ResearchSession>())) ?? 0
        guard legacyEventCount > 0 || legacySessionCount > 0 else { return result }
        result.didRun = true

        let events = (try? context.fetch(FetchDescriptor<SessionEvent>())) ?? []

        // Full fetches, deliberately. Their cost is paid only while legacy rows exist — which is
        // once per device, plus whenever an older build syncs more in — never on an ordinary
        // launch. The bounded alternative would be a `#Predicate` over the optional `executedAt`
        // window, and this codebase has already recorded that SwiftData's translation of optional
        // comparisons is the kind of thing that fails at runtime rather than at compile time
        // (see `HistoryPaneSnapshot`'s note on the free-text filter).
        let existingSearches = (try? context.fetch(FetchDescriptor<SearchHistoryEntry>())) ?? []
        let existingExportIds = Set(
            ((try? context.fetch(FetchDescriptor<ExportHistoryEntry>())) ?? []).map(\.id))

        var searchIdsPresent = Set(existingSearches.map(\.id))

        /// A row an event can pair with instead of being migrated.
        ///
        /// Two kinds live here, and they behave differently on purpose:
        ///
        /// - **Pre-existing** rows (`migratedHere == false`) each stand for one search the app
        ///   really recorded, so each absorbs at most **one** event. Otherwise a single entry
        ///   would swallow every later re-submission of the same query.
        /// - Rows **this pass inserted** (`migratedHere == true`) stand for a migrated event, and
        ///   absorb any number of near-identical events that follow. That is what the live
        ///   producer's `lastRecordedHistoryQuery` did: a filter-only re-run fired the event but
        ///   wrote no entry, so N events moments apart are one search, not N.
        struct Pairable {
            let id: UUID
            let query: String
            let at: Date
            let migratedHere: Bool
        }
        var pairableSearches: [Pairable] = existingSearches.compactMap {
            guard let at = $0.executedAt else { return nil }
            return Pairable(id: $0.id, query: normalized($0.queryText), at: at,
                            migratedHere: false)
        }
        /// Pre-existing entries already claimed by an event this pass.
        var claimedSearchIds: Set<UUID> = []
        var exportIdsPresent = existingExportIds

        // Oldest first, so pairing and self-pairing are deterministic regardless of fetch order.
        let ordered = events.sorted {
            let l = $0.timestamp ?? .distantPast
            let r = $1.timestamp ?? .distantPast
            return l == r ? $0.id.uuidString < $1.id.uuidString : l < r
        }

        for event in ordered {
            guard let timestamp = event.timestamp,
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
                if searchIdsPresent.contains(event.id) {
                    result.searchesAlreadyMigrated += 1
                    continue
                }
                if let match = pairableSearches.first(where: {
                    ($0.migratedHere || !claimedSearchIds.contains($0.id))
                        && $0.query == query
                        && abs($0.at.timeIntervalSince(timestamp)) <= tolerance
                }) {
                    if !match.migratedHere { claimedSearchIds.insert(match.id) }
                    result.searchesPairedWithExistingEntry += 1
                    continue
                }
                context.insert(SearchHistoryEntry(
                    id: event.id,
                    queryText: rawQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                    resultCount: resultCount,
                    projectId: nil,
                    executedAt: timestamp))
                searchIdsPresent.insert(event.id)
                pairableSearches.append(Pairable(id: event.id, query: query, at: timestamp,
                                                 migratedHere: true))
                result.searchesMigrated += 1

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
              + "\(result.exportsMigrated) export(s) migrated, "
              + "\(result.documentOpensDropped) document open(s) and "
              + "\(result.noteSavesDropped) note save(s) dropped as redundant.")

        return result
    }

    // MARK: - Helpers

    /// The comparison form for query pairing.
    ///
    /// The two writers trimmed differently — `logEvent` used `.whitespaces`, `recordSearchHistory`
    /// `.whitespacesAndNewlines` — so a query the user pasted with a trailing newline would not
    /// match itself byte for byte. Case is **not** folded: the recorded text is the user's own
    /// wording, and two searches differing only in case are two searches.
    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
