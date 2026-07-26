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

/// Reverse-chronological list of `ResearchSession` records.
///
/// Each row shows the session's start time, duration, and event count.
/// Tapping the disclosure triangle expands the row to reveal individual
/// `SessionEvent` entries with an event-type icon, a human-readable
/// description decoded from the JSON payload, and a formatted timestamp.
///
/// ## Empty State
/// A `ContentUnavailableView` is shown when the SwiftData store contains
/// no `ResearchSession` records (logging disabled, fresh install, or reset).
///
/// ## Event Icons
/// - documentOpen  → `doc.text`
/// - noteSave      → `note.text`
/// - searchSubmit  → `magnifyingglass`
/// - export        → `square.and.arrow.up`
///
/// Version history:
///   1.0 — Session 101: initial implementation
///   1.1 — First presented (from Settings ▸ Research ▸ Research Sessions). Two bugs that had
///          been invisible while the view was unreachable: every session read "Ongoing", because
///          `endedAt` is only stamped when a later event closes a session in the same process,
///          so anything ended by quitting the app stayed open forever; and the event count had a
///          single `%lld events` form, so a one-event session read "1 events".
struct SessionLogView: View {

    @Query(sort: \ResearchSession.startedAt, order: .reverse)
    private var sessions: [ResearchSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    String(localized: "sessionLog.empty.title",
                           defaultValue: "No Sessions Yet"),
                    systemImage: "clock.badge.xmark",
                    description: Text(String(
                        localized: "sessionLog.empty.detail",
                        defaultValue: "Your research activity will appear here as you open documents, save notes, and run searches."
                    ))
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        SessionRowView(session: session)
                    }
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
    }
}

// MARK: - SessionRowView

private struct SessionRowView: View {
    let session: ResearchSession
    @State private var isExpanded = false

    private var sortedEvents: [SessionEvent] {
        (session.events ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var eventCount: Int { session.events?.count ?? 0 }

    /// When the session actually stopped.
    ///
    /// `endedAt` is stamped only when a *later* event arrives after the expiry interval, in the
    /// same process — so a session that ended because the app quit is never closed and keeps a
    /// nil `endedAt` forever. Falling back to the last event's timestamp is what the data
    /// actually says; without it every session in the log reads "Ongoing", which is how this
    /// showed up the moment the view was first presented.
    private var effectiveEnd: Date? {
        session.endedAt ?? sortedEvents.compactMap(\.timestamp).max()
    }

    /// Whether this session could still be the open one — its last activity is recent enough that
    /// the next event would join it rather than start a new session.
    private var isOngoing: Bool {
        guard session.endedAt == nil, let last = effectiveEnd else { return false }
        return Date.now.timeIntervalSince(last) <= AppState.sessionExpiryInterval
    }

    private var durationString: String? {
        guard let start = session.startedAt else { return nil }
        if isOngoing {
            return String(localized: "sessionLog.ongoing", defaultValue: "Ongoing")
        }
        guard let end = effectiveEnd else { return nil }
        let interval = max(0, end.timeIntervalSince(start))
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
            ForEach(sortedEvents) { event in
                SessionEventRowView(event: event)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if let start = session.startedAt {
                    Text(start, style: .date)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(start, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dur = durationString {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(dur)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        // Two forms, via the shared helper: the single `%lld events` format
                        // rendered "1 events" for every one-event session, which is most of them.
                        Text(ResearchSessionsSummary.events(eventCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - SessionEventRowView

private struct SessionEventRowView: View {
    let event: SessionEvent

    private var icon: String {
        switch event.eventType {
        case "documentOpen":  return "doc.text"
        case "noteSave":      return "note.text"
        case "searchSubmit":  return "magnifyingglass"
        case "export":        return "square.and.arrow.up"
        default:              return "circle"
        }
    }

    private var descriptionText: String {
        guard let data = event.payload,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return event.eventType }
        switch event.eventType {
        case "documentOpen":
            let title = dict["title"] as? String ?? ""
            return title.isEmpty ? (dict["documentId"] as? String ?? event.eventType) : title
        case "noteSave":
            let docId = dict["documentId"] as? String ?? ""
            let volId = dict["volumeId"] as? String ?? ""
            return "\(volId) / \(docId)"
        case "searchSubmit":
            let query = dict["query"] as? String ?? ""
            let count = dict["resultCount"] as? Int ?? 0
            return "\"\(query)\" — \(count) results"
        case "export":
            let format = dict["format"] as? String ?? ""
            let count = dict["documentCount"] as? Int ?? 0
            return "\(format), \(count) doc\(count == 1 ? "" : "s")"
        default:
            return event.eventType
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(descriptionText)
                    .font(.caption)
                    .lineLimit(2)
                if let ts = event.timestamp {
                    Text(ts, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 1)
    }
}
