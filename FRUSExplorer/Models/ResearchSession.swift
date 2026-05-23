// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchEventKind

/// Typed payload for a `SessionEvent`.
///
/// Each case carries the data needed to reconstruct a human-readable
/// activity entry. Encoded to `SessionEvent.eventType` (the case name)
/// and `SessionEvent.payload` (a JSON dictionary of associated values).
///
/// Version history:
///   1.0 — Session 100: initial implementation
enum ResearchEventKind: Sendable {
    case documentOpen(volumeId: String, documentId: String, title: String)
    case noteSave(noteId: UUID, documentId: String, volumeId: String)
    case searchSubmit(query: String, resultCount: Int)
    case export(format: String, documentCount: Int)
}

extension ResearchEventKind {

    var typeString: String {
        switch self {
        case .documentOpen:  return "documentOpen"
        case .noteSave:      return "noteSave"
        case .searchSubmit:  return "searchSubmit"
        case .export:        return "export"
        }
    }

    var payloadData: Data? {
        let dict: [String: Any]
        switch self {
        case .documentOpen(let v, let d, let t):
            dict = ["volumeId": v, "documentId": d, "title": t]
        case .noteSave(let id, let d, let v):
            dict = ["noteId": id.uuidString, "documentId": d, "volumeId": v]
        case .searchSubmit(let q, let count):
            dict = ["query": q, "resultCount": count]
        case .export(let format, let count):
            dict = ["format": format, "documentCount": count]
        }
        return try? JSONSerialization.data(withJSONObject: dict)
    }
}

// MARK: - ResearchSession

/// A single research session — a bounded window of user activity.
///
/// A new session is created automatically by `AppState.logEvent(_:)` whenever
/// no session is active or the previous session has been idle for
/// `AppState.sessionExpiryInterval` (30 minutes). When a session expires,
/// its `endedAt` is set to the timestamp of the last event.
///
/// `events` is a `@Relationship(deleteRule: .nullify)` for CloudKit compatibility —
/// see `Collection.documentEntries` for the same pattern. Callers must delete
/// associated `SessionEvent` records explicitly before deleting a `ResearchSession`.
///
/// Version history:
///   1.0 — Session 100: initial implementation
@Model final class ResearchSession {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Time bounds

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var startedAt: Date?
    var endedAt: Date?

    // MARK: - Events

    /// Ordered event entries. Sorted by `SessionEvent.sortOrder` at display time.
    ///
    /// `deleteRule: .nullify` is required for CloudKit sync compatibility.
    /// Callers must delete associated `SessionEvent` records before deleting
    /// a `ResearchSession`.
    @Relationship(deleteRule: .nullify, inverse: \SessionEvent.session)
    var events: [SessionEvent]?

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?

    // MARK: - Initialiser

    init(startedAt: Date = .now) {
        self.id = UUID()
        self.startedAt = startedAt
        self.createdAt = startedAt

        #if DEBUG
        print("[SwiftData] ResearchSession created: \(id)")
        #endif
    }
}

// MARK: - SessionEvent

/// A single logged action within a `ResearchSession`.
///
/// `eventType` is the `ResearchEventKind` case name ("documentOpen", "noteSave",
/// "searchSubmit", "export"). `payload` is a JSON-encoded dictionary of the
/// associated values; decode with `JSONSerialization` as needed.
///
/// `sessionId` carries the parent session's `id` for fast lookups that don't
/// need the full `ResearchSession` graph.
///
/// Version history:
///   1.0 — Session 100: initial implementation
@Model final class SessionEvent {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Parent Relationship

    /// Back-reference to the owning `ResearchSession`. Required by CloudKit
    /// (all relationships must have inverses). Managed by `ResearchSession.events`.
    var session: ResearchSession?

    /// Parent session ID carried explicitly for fast lookups.
    var sessionId: UUID = UUID()

    // MARK: - Event Data

    /// Case name of the `ResearchEventKind` that produced this event.
    var eventType: String = ""

    /// JSON-encoded associated values for this event. `nil` for events with no payload.
    var payload: Data?

    // MARK: - Ordering

    /// Position within the parent session (ascending). Set at insertion time
    /// to the session's current event count.
    var sortOrder: Int = 0

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var timestamp: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?

    // MARK: - Initialiser

    init(
        sessionId: UUID,
        timestamp: Date = .now,
        kind: ResearchEventKind,
        sortOrder: Int
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.eventType = kind.typeString
        self.payload = kind.payloadData
        self.sortOrder = sortOrder
        self.createdAt = timestamp

        #if DEBUG
        print("[SwiftData] SessionEvent created: \(eventType) in session \(sessionId)")
        #endif
    }
}
