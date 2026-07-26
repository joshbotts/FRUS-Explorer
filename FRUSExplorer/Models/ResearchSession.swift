// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - Retirement note (Wave R-2a)
//
// Everything in this file is LEGACY. Nothing in the app writes a `ResearchSession` or a
// `SessionEvent` any more: `AppState.logEvent` is gone, sessions are derived from the typed trail
// at read time (`ResearchTrailSessions`), and `ResearchTrailMigration` moves the two event kinds
// worth keeping into `SearchHistoryEntry` / `ExportHistoryEntry`.
//
// The two `@Model` types stay in `ModelContainer.frusModelTypes` **on purpose**. Removing them in
// the same release as the migration would leave the app unable to READ the very rows it has to
// migrate on a device that has not launched since — and on a device whose second device is still
// on an older build and still writing them. Retiring the types from the schema is a follow-up
// release, **R-2b**, and must not happen until the migration has shipped for long enough that a
// device skipping straight past this build is no longer a realistic case.
//
// Until then, this file exists to be read by `ResearchTrailMigration` and deleted by R-2b.

// MARK: - ResearchEventKind

/// Typed payload for a `SessionEvent`. **Legacy — read-only since Wave R-2a.**
///
/// Each case carries the data needed to reconstruct a human-readable
/// activity entry. Encoded to `SessionEvent.eventType` (the case name)
/// and `SessionEvent.payload` (a JSON dictionary of associated values).
///
/// The encoding half (``typeString``, ``payloadData``) has no production writer left; it is kept
/// so that ``decode(from:)`` and the round-trip it is tested against describe **one** grammar
/// rather than two hand-copied ones. R-2b deletes the whole file.
///
/// Version history:
///   1.0 — Session 100: initial implementation
///   1.1 — Wave R-2a: `decode(from:)` added — the migration's payload reader; the type is now
///          read-only, and the app writes no `SessionEvent` at all
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

    /// Reads a stored event back into its case, or `nil` if it cannot be read.
    ///
    /// The inverse of ``typeString`` + ``payloadData``, and the only reader of the legacy payload
    /// format. `nil` on an unknown `eventType`, an absent or malformed payload, or a payload
    /// missing a field the case requires — all of which ``ResearchTrailMigration`` counts and
    /// discards rather than guessing at.
    ///
    /// Numeric fields are read through `NSNumber` because `JSONSerialization` may hand back either
    /// `Int` or `NSNumber` depending on how the value was written; `as? Int` alone silently
    /// yielded zero for counts in some payloads.
    ///
    /// - Parameter event: The stored event.
    static func decode(from event: SessionEvent) -> ResearchEventKind? {
        guard let data = event.payload,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        func string(_ key: String) -> String? { dict[key] as? String }
        func int(_ key: String) -> Int? { (dict[key] as? NSNumber)?.intValue }

        switch event.eventType {
        case "documentOpen":
            guard let volumeId = string("volumeId"), let documentId = string("documentId")
            else { return nil }
            return .documentOpen(volumeId: volumeId,
                                 documentId: documentId,
                                 title: string("title") ?? "")
        case "noteSave":
            guard let raw = string("noteId"), let noteId = UUID(uuidString: raw),
                  let documentId = string("documentId"), let volumeId = string("volumeId")
            else { return nil }
            return .noteSave(noteId: noteId, documentId: documentId, volumeId: volumeId)
        case "searchSubmit":
            guard let query = string("query") else { return nil }
            return .searchSubmit(query: query, resultCount: int("resultCount") ?? 0)
        case "export":
            guard let format = string("format") else { return nil }
            return .export(format: format, documentCount: int("documentCount") ?? 0)
        default:
            return nil
        }
    }
}

// MARK: - ResearchSession

/// A single research session — a bounded window of user activity. **Legacy; nothing writes one.**
///
/// Sessions used to be created by `AppState.logEvent(_:)` whenever no session was active or the
/// previous one had been idle for 30 minutes. That method is gone. Sessions are now
/// ``DerivedResearchSession``s, computed from the typed trail's timestamps at read time — which
/// among other things fixes the defect this stored form had: `endedAt` was stamped only when a
/// later event arrived in the same process, so a session ended by quitting the app stayed open
/// forever.
///
/// This type survives one release so ``ResearchTrailMigration`` can read the rows already in
/// users' stores. See the retirement note at the top of this file.
///
/// `events` is a `@Relationship(deleteRule: .nullify)` for CloudKit compatibility —
/// see `Collection.documentEntries` for the same pattern. Callers must delete
/// associated `SessionEvent` records explicitly before deleting a `ResearchSession`.
///
/// Version history:
///   1.0 — Session 100: initial implementation
///   1.1 — Wave R-2a: retired. No writer remains; read only by the migration
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
