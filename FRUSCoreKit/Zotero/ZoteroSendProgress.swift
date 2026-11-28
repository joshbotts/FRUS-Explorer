// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - ZoteroSendProgress

/// How far a send to Zotero got (#1923): what Zotero took, and the write whose answer the send did not read,
/// so that a second send can finish the first and write nothing twice.
///
/// A send writes the Zotero collection (a collection's send only), then its items fifty at a time, then their
/// notes fifty at a time (`ZoteroAPIClient.send`). It keeps this value as it goes: each item Zotero took, by
/// its identity, with the key Zotero gave it and the notes written under it; the collection's key; and, while
/// a write is out, that write with its `Zotero-Write-Token`. A send that stops once Zotero may have taken
/// something throws `ZoteroSendStopped` with it, and `ZoteroAPIClient.send(…, resuming:)` finishes from it.
///
/// **The write in flight.** A write whose answer the send did not read may have landed: the connection
/// dropped, Zotero or something in front of it answered a 5xx, or the answer could not be read. A finish sends
/// it again under its own token before it writes anything else, so a progress holds one write in flight at
/// most. Zotero keeps the token of a request that succeeded for 12 hours, and refuses a second request under
/// it with a 412; it keeps none for a request that failed (Web API v3, *Write Requests*, read 2026-11-28). So
/// a write that landed is refused, and one that did not is written then. After a 412 the finish reads what
/// the write made:
/// - an items write's keys, from the Zotero collection's items, or from the library's hundred newest where the
///   send makes no collection;
/// - a collection write's key, from the account's collections: the newest of its name with no items yet, or,
///   where there is none, the collection is made anew.
/// A notes write needs no read, since no later write names a note's key: its notes are counted as written,
/// so a note Zotero refused inside a batch whose answer was lost is counted too. A write Zotero refused with a
/// 4xx wrote nothing, and is no write in flight.
///
/// **An item's identity** is its URL, or its title where it has none, with its place among the send's items
/// of that URL: a document entered twice in a collection is two items, the first and the second. So a finish
/// over a collection edited since the stop still lines up: an item added is sent, and one removed stays in the
/// library, counted in `ZoteroSendResult.itemsLeftInLibrary`. A note is known by its text's SHA-256, under its
/// item, so the notes an item gained since are sent, and those sent are not sent again.
///
/// **Twelve hours.** From `expiresAt` Zotero may have forgotten the token of the write in flight, and a finish
/// could write that write twice: a host offers no finish then (`canFinish(for:at:)`).
///
/// It is `Codable`, so a host can keep it between a stop and a finish. A host that keeps it as the send goes,
/// from `send`'s `progress` closure, can also finish a send its process did not live to see end.
///
/// Version history:
///   1.0 — L64 of the plan of record from 2026-11-25 (#1923)
public struct ZoteroSendProgress: Codable, Sendable, Equatable {

    /// How long a write's token may be in Zotero's memory, counted from when the write was first sent: Zotero
    /// keeps the token of a request that succeeded for 12 hours from the success, which comes after the send.
    public static let lifetime: TimeInterval = 12 * 60 * 60

    /// The Zotero user ID the send wrote to.
    public let userID: Int

    /// The key of the Zotero collection the send made, once Zotero has said it: nil for a send with no
    /// collection, and before the collection's write is answered.
    public internal(set) var collectionKey: String?

    /// When the send last changed this progress: a write sent, an answer read, or a write refused.
    public internal(set) var updatedAt: Date

    /// Each item Zotero took, in the order it took them.
    var written: [WrittenItem]

    /// The write whose answer the send has not read, if one is out.
    var inFlight: WriteInFlight?

    /// What a write carries: the Zotero collection, items, or notes.
    public enum WriteKind: String, Codable, Sendable {
        case collection
        case items
        case notes
    }

    /// A progress with nothing written, for `userID`, made at `now`.
    init(userID: Int, at now: Date) {
        self.userID = userID
        self.collectionKey = nil
        self.updatedAt = now
        self.written = []
        self.inFlight = nil
    }

    /// How many items Zotero took.
    public var writtenItemCount: Int { written.count }

    /// How many notes Zotero took. A write in flight's are not counted.
    public var writtenNoteCount: Int { written.reduce(0) { $0 + $1.noteDigests.count } }

    /// What the write in flight carries, or nil when none is out: Zotero may have taken it, and a finish
    /// learns whether it did.
    public var writeInFlight: WriteKind? { inFlight?.kind }

    /// Whether nothing was written and no write is out: a finish would do nothing a new send does not, so a
    /// host keeps no record of it.
    public var isEmpty: Bool { collectionKey == nil && written.isEmpty && inFlight == nil }

    /// The moment from which no finish may start: `lifetime` after the write in flight was first sent, or
    /// after `updatedAt` when none is out.
    public var expiresAt: Date { (inFlight?.firstSentAt ?? updatedAt).addingTimeInterval(Self.lifetime) }

    /// Whether a finish for `userID` may start from this progress at `now`: it wrote to that account, `now`
    /// is before `expiresAt`, and it is not empty.
    public func canFinish(for userID: Int, at now: Date = Date()) -> Bool {
        userID == self.userID && now < expiresAt && !isEmpty
    }
}

// MARK: - The parts

extension ZoteroSendProgress {

    /// An item's identity across a send and its finish: its URL, or its title where it has none, with its
    /// place among the send's items of that name.
    struct ItemIdentity: Codable, Hashable, Sendable {
        /// The item's URL, or `title:` and its title where it has no URL.
        let name: String
        /// Its place among the send's items of `name`, from 1.
        let occurrence: Int

        /// The name an item goes by: its URL, or `title:` and its title where it has none. A Zotero item read
        /// back goes by the same rule, over its `url` and `title` fields.
        static func name(url: String?, title: String?) -> String {
            if let url, !url.isEmpty { return url }
            return "title:" + (title ?? "")
        }

        /// Each of `items`' identities, in order.
        static func of(_ items: [ZoteroJSONExporter.Item]) -> [ItemIdentity] {
            var seen: [String: Int] = [:]
            return items.map { item in
                let name = Self.name(url: item.url, title: item.title)
                let occurrence = seen[name, default: 0] + 1
                seen[name] = occurrence
                return ItemIdentity(name: name, occurrence: occurrence)
            }
        }
    }

    /// An item Zotero took: its identity, the key Zotero gave it, and the notes written under it.
    struct WrittenItem: Codable, Equatable, Sendable {
        /// The item's identity in the send.
        let identity: ItemIdentity
        /// The key Zotero gave it.
        let key: String
        /// The SHA-256 of each note's text written under it (`digest(of:)`), in the order written.
        var noteDigests: [String]
    }

    /// A note of the send: its item, and its text's SHA-256.
    struct NoteRef: Codable, Hashable, Sendable {
        /// The identity of the note's item.
        let item: ItemIdentity
        /// The SHA-256 of the note's text (`digest(of:)`).
        let digest: String
    }

    /// A write whose answer the send has not read.
    struct WriteInFlight: Codable, Equatable, Sendable {
        /// What it carries.
        let kind: WriteKind
        /// Its `Zotero-Write-Token`, which a finish sends it under again.
        let writeToken: String
        /// When it was first sent, from which its token may be in Zotero's memory for `lifetime`.
        let firstSentAt: Date
        /// An items write's items, in order; empty for any other.
        var items: [ItemIdentity]
        /// A notes write's notes, in order; empty for any other.
        var notes: [NoteRef]
    }

    /// The SHA-256 of a note's text, in lowercase hex: how a note is known across a send and its finish.
    static func digest(of note: String) -> String {
        SHA256.hash(data: Data(note.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ZoteroSendStopped

/// A send to Zotero that stopped once Zotero may have taken part of it (#1923).
///
/// `cause` is what stopped it: a `ZoteroAPIError`, or a `CancellationError` when its task was cancelled.
/// `progress` is how far it got, which `ZoteroAPIClient.send(…, resuming:)` finishes from. A send that stops
/// before Zotero can have taken anything throws its cause alone, as it did before.
///
/// Version history:
///   1.0 — L64 of the plan of record from 2026-11-25 (#1923)
public struct ZoteroSendStopped: Error, LocalizedError {

    /// What stopped the send: a `ZoteroAPIError`, or a `CancellationError`.
    public let cause: any Error

    /// How far the send got.
    public let progress: ZoteroSendProgress

    /// Creates the error for a send that `cause` stopped with `progress` made.
    public init(cause: any Error, progress: ZoteroSendProgress) {
        self.cause = cause
        self.progress = progress
    }

    /// The cause's description, so a host that shows a send's error shows the same sentence as before.
    public var errorDescription: String? {
        (cause as? LocalizedError)?.errorDescription ?? cause.localizedDescription
    }
}
