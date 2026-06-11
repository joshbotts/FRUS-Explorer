// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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
        let header = document.header.isEmpty ? document.documentId : document.header
        let title = document.documentNumber.map { "Document \($0): \(header)" } ?? header

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

    // MARK: - Tags & Notes

    /// Resolves the Zotero `tags` and `notes` for a single FRUS document.
    ///
    /// `tags` combines `DocumentTagAssignment`s made directly on the document
    /// with tags applied to any of the document's `ResearchNote`s. `notes`
    /// carries the body text of every `ResearchNote` for the document.
    @MainActor
    public static func fetchTagsAndNotes(
        documentId: String,
        volumeId: String,
        context: ModelContext
    ) -> (tags: [String], notes: [String]) {
        let allTags = (try? context.fetch(FetchDescriptor<UserTag>())) ?? []
        let tagNameById = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0.name) })

        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate { $0.volumeId == volumeId && $0.documentId == documentId }
        ))) ?? []

        let notes = (try? context.fetch(FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.volumeId == volumeId && $0.documentId == documentId }
        ))) ?? []

        var tagNames = Set<String>()
        for assignment in assignments {
            if let name = tagNameById[assignment.tagId] {
                tagNames.insert(name)
            }
        }
        for note in notes {
            for tagId in note.userTagIds {
                if let name = tagNameById[tagId] {
                    tagNames.insert(name)
                }
            }
        }

        let noteBodies = notes.map(\.bodyText).filter { !$0.isEmpty }
        return (tags: tagNames.sorted(), notes: noteBodies)
    }
}
