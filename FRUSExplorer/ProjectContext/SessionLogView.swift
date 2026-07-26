// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SessionLogView

/// Reverse-chronological list of research sessions, **derived** from the trail (Wave R-2a).
///
/// Each row shows the session's start time, duration, and activity count. Expanding it reveals the
/// individual activities — a document opened, a search run, a collection exported — each with an
/// icon, a human-readable line, and a time.
///
/// ## What changed under this view
/// It used to hold a live `@Query` over `ResearchSession` and walk each one's `events`
/// relationship. Nothing writes those types any more: sessions are computed from the timestamps in
/// ``ReadingHistoryEntry``, ``SearchHistoryEntry`` and ``ExportHistoryEntry`` by
/// ``ResearchTrailSessions``, loaded once into a ``SessionLogSnapshot``.
///
/// Two defects go with the old model:
/// - **"Ongoing" forever.** `endedAt` was stamped only when a later event arrived in the same
///   process, so a session ended by quitting the app never closed. This view had to guess an end
///   from the last event's timestamp; the derived form computes it, always.
/// - **A `@Query` per drip-import.** Both source types are CloudKit-mirrored and nothing prunes
///   them (contract D5), so the pane re-rendered its whole list once per import batch — the shape
///   `NotesPaneSnapshot` and `HistoryPaneSnapshot` exist to stop.
///
/// ## Empty State
/// A `ContentUnavailableView` when nothing is recorded (logging off, fresh install, or a delete).
///
/// ## Activity Icons
/// - document opened  → `doc.text`
/// - search run       → `magnifyingglass`
/// - collection export → `square.and.arrow.up`
///
/// (`note.text` is gone with the `.noteSave` event the contract dropped — D2: `ResearchNote`
/// timestamps itself.)
///
/// Version history:
///   1.0 — Session 101: initial implementation
///   1.1 — First presented (from Settings ▸ Research ▸ Research Sessions). Two bugs that had
///          been invisible while the view was unreachable: every session read "Ongoing", because
///          `endedAt` is only stamped when a later event closes a session in the same process,
///          so anything ended by quitting the app stayed open forever; and the event count had a
///          single `%lld events` form, so a one-event session read "1 events".
///   1.2 — Wave R-2a: reads the derived trail (`SessionLogSnapshot`) instead of a `@Query` over
///          the retired session tables. The "Ongoing" fallback 1.1 added is gone with the defect
///          that made it necessary. Bounded page + "Show More", like the History surface.
struct SessionLogView: View {

    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    /// The log is a sheet inside the Settings window on macOS; the user can go on working in the
    /// main window and come back, so re-read when this window becomes active again.
    @Environment(\.controlActiveState) private var controlActiveState
    #else
    @Environment(\.scenePhase) private var scenePhase
    #endif

    @State private var snapshot: SessionLogSnapshot = .empty
    @State private var pageLimit = SessionLogSnapshot.defaultPageLimit

    var body: some View {
        Group {
            if snapshot.isEmpty {
                ContentUnavailableView(
                    String(localized: "sessionLog.empty.title",
                           defaultValue: "No Sessions Yet"),
                    systemImage: "clock.badge.xmark",
                    description: Text(String(
                        localized: "sessionLog.empty.detail.trail",
                        defaultValue: "Your research activity will appear here as you open documents, run searches, and export collections."
                    ))
                )
            } else {
                List {
                    ForEach(snapshot.sessions) { session in
                        SessionRowView(session: session)
                    }
                    if snapshot.hasMore { showMoreSection }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle(
            String(localized: "sessionLog.title", defaultValue: "Session Log")
        )
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { refresh() }
        #if os(macOS)
        .onChange(of: controlActiveState) { _, state in
            if state != .inactive { refresh() }
        }
        #else
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        #endif
    }

    // MARK: - Sections

    /// The bound on what is loaded, stated rather than implied, plus the control that widens it.
    ///
    /// The oldest session on screen is the only one that can be partial — everything newer than it
    /// is complete by construction — so that is what the note says.
    private var showMoreSection: some View {
        Section {
            Button {
                pageLimit += SessionLogSnapshot.pageIncrement
                refresh()
            } label: {
                Text(String(localized: "sessionLog.showMore", defaultValue: "Show More"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "sessionLog.showing %lld %lld",
                                           defaultValue: "Showing the most recent %lld of %lld recorded activities."),
                            Int64(snapshot.loadedActivities), Int64(snapshot.totalActivities)))
                Text(String(localized: "sessionLog.oldestPartial",
                            defaultValue: "The oldest session listed may reach further back than the activity loaded."))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - State

    private func refresh() {
        snapshot = SessionLogSnapshot.fetch(from: modelContext, limit: pageLimit)
    }
}

// MARK: - SessionRowView

private struct SessionRowView: View {
    let session: DerivedResearchSession
    @State private var isExpanded = false

    /// "Ongoing" while the next activity would still join this session; otherwise a duration.
    ///
    /// No `endedAt`-is-nil fallback: a derived session always has both bounds.
    private var durationString: String {
        if session.isOngoing() {
            return String(localized: "sessionLog.ongoing", defaultValue: "Ongoing")
        }
        let interval = session.duration
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3_600 {
            return "\(Int(interval / 60))m"
        } else {
            let h = Int(interval / 3_600)
            let m = Int((interval.truncatingRemainder(dividingBy: 3_600)) / 60)
            return "\(h)h \(m)m"
        }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(session.activities) { activity in
                SessionActivityRowView(activity: activity)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.startedAt, style: .date)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(session.startedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(durationString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    // Two forms, via the shared helper: the single `%lld events` format
                    // rendered "1 events" for every one-event session, which is most of them.
                    Text(ResearchSessionsSummary.events(session.activityCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - SessionActivityRowView

private struct SessionActivityRowView: View {
    let activity: ResearchTrailActivity

    /// The row's line. Composed here rather than in ``ResearchTrailActivity`` so every string is a
    /// `String(localized:)` in a view, which is where this codebase keeps them.
    ///
    /// Both counts are spelled out in two forms. No String Catalog ships, so a lone `%lld results`
    /// renders "1 results" — the defect this view's own 1.1 entry records for the session count.
    private var descriptionText: String {
        switch activity.kind {
        case .documentOpen(let volumeId, let documentId, let displayTitle):
            if let displayTitle, !displayTitle.isEmpty { return displayTitle }
            return "\(volumeId) · \(documentId)"
        case .search(let query, let count):
            let results = count == 1
                ? String(localized: "sessionLog.results.one", defaultValue: "1 result")
                : String(format: String(localized: "sessionLog.results.many %lld",
                                        defaultValue: "%lld results"), Int64(count))
            return String(format: String(localized: "sessionLog.search %@ %@",
                                         defaultValue: "“%1$@” — %2$@"),
                          query, results)
        case .export(let format, let documentCount, let collectionName):
            let what = collectionName ?? format
            let documents = documentCount == 1
                ? String(localized: "sessionLog.documents.one", defaultValue: "1 document")
                : String(format: String(localized: "sessionLog.documents.many %lld",
                                        defaultValue: "%lld documents"), Int64(documentCount))
            return String(format: String(localized: "sessionLog.export %@ %@",
                                         defaultValue: "Exported %1$@ — %2$@"),
                          what, documents)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: activity.kind.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(descriptionText)
                    .font(.caption)
                    .lineLimit(2)
                Text(activity.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
    }
}
