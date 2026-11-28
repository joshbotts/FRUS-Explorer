// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ZoteroJSONExporter

/// Formats FRUS citation metadata as Zotero's JSON exchange format
/// (`{"version": 5, "items": [...]}`), the format produced by the Zotero
/// Connector and read by the Better BibTeX "Zotero JSON" translator.
///
/// Each FRUS document maps to a `bookSection` item. User tags and research
/// notes attached to the document are carried along as Zotero `tags`/`notes`
/// so they survive the round trip into a Zotero library.
///
/// ## Example output
/// ```json
/// {
///   "version" : 5,
///   "items" : [
///     {
///       "itemType" : "bookSection",
///       "title" : "Document 1: Memorandum of Conversation",
///       "bookTitle" : "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
///       "creators" : [ { "creatorType" : "editor", "name" : "Louis J. Smith" } ],
///       "date" : "1972",
///       "publisher" : "Government Printing Office",
///       "place" : "Washington, D.C.",
///       "url" : "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
///       "accessDate" : "2026-06-10",
///       "tags" : [ { "tag" : "NATO" } ],
///       "notes" : [ { "note" : "My research note" } ]
///     }
///   ]
/// }
/// ```
///
/// Version history:
///   1.0 — Session 155
///   1.1 — FRUS Explorer Light: moved into the kit with its items, for the web edition's BibTeX and
///          RIS, which render them; `fetchTagsAndNotes`, which reads SwiftData, stays in the app, in
///          `ZoteroJSONExporter+App.swift`
///   1.2 — L34 (decision 165): an item's title names the document's number once, the volume's own number
///          that opens its heading read by its form and left out (#2002)
public struct ZoteroJSONExporter: Sendable {

    public init() {}

    // MARK: - Item

    /// One entry in the Zotero JSON `items` array.
    public struct Item: Codable, Sendable, Equatable {
        public var itemType: String
        public var title: String
        public var creators: [Creator]?
        public var bookTitle: String?
        public var date: String?
        public var publisher: String?
        public var place: String?
        public var url: String?
        public var accessDate: String?
        public var extra: String?
        public var tags: [Tag]?
        public var notes: [Note]?

        public init(
            itemType: String,
            title: String,
            creators: [Creator]? = nil,
            bookTitle: String? = nil,
            date: String? = nil,
            publisher: String? = nil,
            place: String? = nil,
            url: String? = nil,
            accessDate: String? = nil,
            extra: String? = nil,
            tags: [Tag]? = nil,
            notes: [Note]? = nil
        ) {
            self.itemType = itemType
            self.title = title
            self.creators = creators
            self.bookTitle = bookTitle
            self.date = date
            self.publisher = publisher
            self.place = place
            self.url = url
            self.accessDate = accessDate
            self.extra = extra
            self.tags = tags
            self.notes = notes
        }
    }

    /// A creator entry, e.g. `{"creatorType": "editor", "name": "Louis J. Smith"}`.
    public struct Creator: Codable, Sendable, Equatable {
        public var creatorType: String
        public var name: String

        public init(creatorType: String, name: String) {
            self.creatorType = creatorType
            self.name = name
        }
    }

    /// A Zotero tag entry, e.g. `{"tag": "NATO"}`.
    public struct Tag: Codable, Sendable, Equatable {
        public var tag: String

        public init(tag: String) {
            self.tag = tag
        }
    }

    /// A Zotero child-note entry, e.g. `{"note": "My research note"}`.
    public struct Note: Codable, Sendable, Equatable {
        public var note: String

        public init(note: String) {
            self.note = note
        }
    }

    /// The top-level Zotero JSON exchange envelope.
    public struct Envelope: Codable, Sendable, Equatable {
        public var version: Int
        public var items: [Item]

        public init(version: Int = 5, items: [Item]) {
            self.version = version
            self.items = items
        }
    }

    // MARK: - Item construction

    /// Builds a Zotero `bookSection` item for a single FRUS document.
    ///
    /// **The title takes the one reading of the heading** (L34; decision 165): "Document 1: Letter From
    /// President Carter…", the document's number once. The volume's own number that opens the heading is
    /// read by its form (`DocumentHeadingReading.splitNumber(_:)`) and left out, since the title names the
    /// number history.state.gov cites (decision 197); until L34 the record read "Document 1: 1. Letter
    /// From…" (#2002), and a collection's ended in "[1]" where the heading called a numbered note (#1992).
    /// A heading that is its number alone, and a record that names no number of history.state.gov's, keep
    /// the heading as it stands. The "Document date:" line is the dateline the caller read, which a
    /// collection reads through the same reading (decision 198).
    ///
    /// - Parameters:
    ///   - document: Metadata for the specific document being cited.
    ///   - volume: Metadata for the containing volume.
    ///   - year: Effective publication year string (e.g. `"1972"` or `"n.d."`).
    ///   - url: Canonical URL, or `nil` if unavailable.
    ///   - isEditorialNote: When `true`, notes in `extra` that this is an editorial note.
    ///   - tags: User tag names to attach as Zotero `tags`.
    ///   - notes: Research note bodies to attach as Zotero child `notes`.
    public static func makeItem(
        document: FRUSDocumentMetadata,
        volume: FRUSVolumeMetadata,
        year: String,
        url: String?,
        isEditorialNote: Bool,
        tags: [String] = [],
        notes: [String] = []
    ) -> Item {
        let whole = document.header.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        if let number = document.documentNumber {
            let words = DocumentHeadingReading.splitNumber(whole).words
            let heading = words.isEmpty ? whole : words
            title = "Document \(number): \(heading.isEmpty ? document.documentId : heading)"
        } else {
            // No number of history.state.gov's to name: the heading's own, where it prints one, stays.
            title = whole.isEmpty ? document.documentId : whole
        }

        var extraLines: [String] = []
        if isEditorialNote {
            extraLines.append("Editorial note")
        }
        if let dateline = document.dateline, !dateline.isEmpty {
            extraLines.append("Document date: \(dateline)")
        }

        return Item(
            itemType: "bookSection",
            title: title,
            creators: volume.editors.isEmpty ? nil : volume.editors.map { Creator(creatorType: "editor", name: $0) },
            bookTitle: volume.title,
            date: year,
            publisher: volume.publisher,
            place: volume.publicationPlace,
            url: url,
            accessDate: accessDateString(),
            extra: extraLines.isEmpty ? nil : extraLines.joined(separator: "\n"),
            tags: tags.isEmpty ? nil : tags.map { Tag(tag: $0) },
            notes: notes.isEmpty ? nil : notes.map { Note(note: $0) }
        )
    }

    /// Returns today's date as `yyyy-MM-dd`, used for `accessDate`.
    private static func accessDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - Encoding

    /// Encodes `items` into a pretty-printed `{"version": 5, "items": [...]}` document.
    public func exportData(items: [Item]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(items: items))
    }

    // MARK: - Editorial-Note Flags

    /// Resolves which documents in `volumeIds` are editorial notes, from the
    /// `document_cache.is_editorial_note` column via
    /// `IndexingPipeline.documents(forVolume:)`.
    ///
    /// Returns a map keyed `"<volumeId>/<documentId>"` holding `true` for
    /// editorial notes only — look up with `flags[key] ?? false`. Volumes that
    /// are not indexed (or when `pipeline` is `nil`) contribute no entries, so
    /// the flag degrades to `false` for them, mirroring how the document-level
    /// export path only knows `isEditorialNote` for indexed documents.
    ///
    /// Shared by `resolveDocuments()` and `resolveSmartDocuments()` in the
    /// collection export flow so collection-level items carry the same
    /// "Editorial note" `extra` line as document-level exports.
    public static func editorialNoteFlags(
        volumeIds: some Sequence<String>,
        pipeline: IndexingPipeline?
    ) async -> [String: Bool] {
        guard let pipeline else { return [:] }
        var flags: [String: Bool] = [:]
        for volumeId in volumeIds {
            guard let docs = try? await pipeline.documents(forVolume: volumeId) else { continue }
            for doc in docs where doc.isEditorialNote {
                flags["\(volumeId)/\(doc.documentId)"] = true
            }
        }
        return flags
    }
}
