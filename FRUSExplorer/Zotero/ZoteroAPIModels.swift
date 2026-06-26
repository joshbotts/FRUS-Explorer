// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Request payloads

/// A creator for a Zotero API item. Encodes as either a two-field
/// (`firstName`/`lastName`) or single-field (`name`) creator — synthesised
/// `encodeIfPresent` omits the unused form.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroAPICreator: Encodable, Sendable, Equatable {
    var creatorType: String
    var firstName: String?
    var lastName: String?
    var name: String?

    /// Builds a creator from a full-name string, splitting on the last space into
    /// first/last (the form Zotero alphabetises on). Falls back to a single-field
    /// `name` when the name can't be split (e.g. an institution).
    static func from(type: String, fullName: String) -> ZoteroAPICreator {
        let trimmed = fullName.trimmingCharacters(in: .whitespaces)
        if let space = trimmed.lastIndex(of: " ") {
            let first = String(trimmed[..<space]).trimmingCharacters(in: .whitespaces)
            let last = String(trimmed[trimmed.index(after: space)...])
            if !first.isEmpty, !last.isEmpty {
                return ZoteroAPICreator(creatorType: type, firstName: first, lastName: last, name: nil)
            }
        }
        return ZoteroAPICreator(creatorType: type, firstName: nil, lastName: nil, name: trimmed)
    }
}

/// A tag on a Zotero API item.
struct ZoteroAPITag: Encodable, Sendable, Equatable {
    var tag: String
}

/// A Zotero API item ready to POST. Optional fields are omitted when nil.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroAPIItem: Encodable, Sendable, Equatable {
    var itemType: String
    var title: String
    var bookTitle: String?
    var creators: [ZoteroAPICreator]
    var date: String?
    var publisher: String?
    var place: String?
    var url: String?
    var accessDate: String?
    var extra: String?
    var tags: [ZoteroAPITag]
    var collections: [String]

    /// Maps a `ZoteroJSONExporter.Item` (already resolved with tags) onto an API
    /// item, optionally placing it in `collectionKey`. Notes are *not* included
    /// here — they are created separately as child items once parent keys are known.
    init(item: ZoteroJSONExporter.Item, collectionKey: String?) {
        itemType = item.itemType
        title = item.title
        bookTitle = item.bookTitle
        creators = (item.creators ?? []).map { ZoteroAPICreator.from(type: $0.creatorType, fullName: $0.name) }
        date = item.date
        publisher = item.publisher
        place = item.place
        url = item.url
        accessDate = item.accessDate
        extra = item.extra
        tags = (item.tags ?? []).map { ZoteroAPITag(tag: $0.tag) }
        collections = collectionKey.map { [$0] } ?? []
    }
}

/// A Zotero API child note item (`itemType: "note"`) attached to a parent.
struct ZoteroAPINote: Encodable, Sendable, Equatable {
    var itemType = "note"
    var parentItem: String
    var note: String

    /// Wraps plain-or-markdown note text as minimal HTML (Zotero notes are HTML),
    /// escaping entities and converting newlines to paragraph breaks.
    static func htmlNote(parentItem: String, text: String) -> ZoteroAPINote {
        ZoteroAPINote(parentItem: parentItem, note: Self.htmlify(text))
    }

    /// Escapes HTML-special characters and turns blank-line-separated blocks into
    /// `<p>` paragraphs.
    static func htmlify(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let paragraphs = escaped
            .components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: "<br>") }
            .filter { !$0.isEmpty }
        return paragraphs.map { "<p>\($0)</p>" }.joined()
    }
}

// MARK: - Response payloads

/// The response to a Zotero write request (`POST /items` or `/collections`).
///
/// `successful` maps the input array index (as a string) to the created object;
/// `failed` maps an input index to an error. Index keys let callers correlate
/// created keys back to their source items (needed to attach child notes).
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroWriteResponse: Decodable, Sendable {
    let successful: [String: Created]
    let failed: [String: Failure]

    struct Created: Decodable, Sendable {
        let key: String
        let version: Int
    }

    struct Failure: Decodable, Sendable {
        let code: Int
        let message: String
    }

    /// `index → key` for every successfully created object.
    var keysByIndex: [Int: String] {
        var result: [Int: String] = [:]
        for (indexString, created) in successful {
            if let index = Int(indexString) { result[index] = created.key }
        }
        return result
    }
}

/// The response to `GET /keys/<key>` — identifies the key's owner and permissions.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroKeyInfo: Decodable, Sendable {
    let userID: Int
    let username: String?
    let access: Access

    struct Access: Decodable, Sendable {
        let user: UserAccess?
    }

    struct UserAccess: Decodable, Sendable {
        let library: Bool?
        let write: Bool?
        let notes: Bool?
    }

    /// Whether the key can write items and notes to the user's personal library.
    var canWriteNotes: Bool {
        (access.user?.write ?? false) && (access.user?.library ?? false)
    }
}

// MARK: - Errors & result

/// Errors surfaced by `ZoteroAPIClient`.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
enum ZoteroAPIError: Error, LocalizedError, Sendable {
    case missingCredentials
    case invalidKey
    case insufficientPermissions
    case network(String)
    case http(Int)
    case decoding
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return String(localized: "zotero.error.missingCredentials",
                          defaultValue: "Connect a Zotero account in Settings first.")
        case .invalidKey:
            return String(localized: "zotero.error.invalidKey",
                          defaultValue: "That Zotero API key was rejected. Check it and try again.")
        case .insufficientPermissions:
            return String(localized: "zotero.error.permissions",
                          defaultValue: "This Zotero key lacks write access to your library. Create a key with write and notes permission.")
        case .network:
            return String(localized: "zotero.error.network",
                          defaultValue: "Couldn't reach Zotero. Check your connection and try again.")
        case let .http(code):
            return String(format: String(localized: "zotero.error.http %lld",
                                          defaultValue: "Zotero returned an unexpected error (HTTP %lld)."),
                          Int64(code))
        case .decoding:
            return String(localized: "zotero.error.decoding",
                          defaultValue: "Zotero returned a response FRUS Explorer couldn't read.")
        case .rateLimited:
            return String(localized: "zotero.error.rateLimited",
                          defaultValue: "Zotero is rate-limiting requests. Please try again shortly.")
        }
    }
}

/// Summary of a completed "send to Zotero" operation.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroSendResult: Sendable {
    let addedItems: Int
    let failedItems: Int
    let addedNotes: Int
    let collectionKey: String?
    /// Web URL of the destination collection/library, for a "View in Zotero" link.
    let webURL: URL?
}
