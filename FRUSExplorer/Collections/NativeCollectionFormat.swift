// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - FRUSCollectionFile

/// The portable, round-trippable representation of a `Collection` — the on-disk shape of a
/// native `.fruscollection` file (Collections rework Phase 4, D9).
///
/// Unlike the PDF/HTML/DOCX/RIS/BibTeX exporters, which render a *product*, this format
/// serializes the collection's **source**: its composition settings, ordered structural
/// entries (documents / headings / prose), and — opt-in — the researcher's inline notes.
/// Documents are carried as portable `volumeId` + `documentId` references (universal FRUS
/// identifiers), so a collection authored on one device reconstructs on another once the
/// referenced volumes are downloaded; nothing device-local (SwiftData ids, timestamps,
/// `projectIds`) is serialized.
///
/// It is a plain `Codable` struct, decoupled from the SwiftData `@Model` types, so the file
/// schema can evolve independently of the persistence layer. Prose rich text (`Entry.richText`)
/// is RTF `Data`, which `JSONEncoder` emits as base64.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D9): initial implementation
struct FRUSCollectionFile: Codable, Sendable, Equatable {

    /// Format discriminator; always `NativeCollectionSerializer.formatIdentifier`. Checked on
    /// decode so an unrelated JSON file is rejected rather than silently imported as empty.
    var format: String
    /// Monotonic schema version. Decoding rejects a file newer than the app understands.
    var formatVersion: Int
    /// The collection title.
    var name: String
    /// The optional collection-level note/description.
    var note: String?
    /// The persisted composition settings (what an export of this collection contains).
    var composition: Composition
    /// The ordered structural entries. Array order *is* the collection order.
    var entries: [Entry]

    // MARK: - Composition

    /// The persisted export-content settings carried with the collection (mirrors the
    /// `Collection` composition fields). Enum-backed values are raw strings, matching the model.
    /// Device-local `summaryPromptId` is intentionally omitted — a `.summaryOnly` collection
    /// regenerates summaries with the recipient's own prompt.
    struct Composition: Codable, Sendable, Equatable {
        /// `CollectionBodyDepth` raw value (`"full"` / `"summaryOnly"` / `"index"`).
        var defaultBodyDepth: String
        /// `CollectionFootnoteStyle` raw value (`"none"` / `"sourceNoteOnly"` / `"all"`).
        var footnoteStyle: String
        /// `CollectionToCStyle` raw value (`"citation"` / `"headerAndDateline"`).
        var tocStyle: String
        /// Whether user highlights annotate exported bodies.
        var applyHighlights: Bool
        /// Whether attached research notes appear in exports.
        var includeNotes: Bool
        /// Whether a word-cloud overview is prepended to PDF/HTML exports.
        var includeWordCloud: Bool
    }

    // MARK: - Entry

    /// One structural entry. `kind` selects which fields apply: `document` uses
    /// `documentId`/`volumeId` (+ optional `bodyDepthOverride` and inline `notes`);
    /// `heading` uses `text` (+ optional `bodyDepthOverride` as the section depth);
    /// `prose` uses `text` and optional `richText` (RTF).
    struct Entry: Codable, Sendable, Equatable {
        /// `CollectionEntryKind` raw value (`"document"` / `"heading"` / `"prose"`).
        var kind: String
        /// FRUS document id (document entries only).
        var documentId: String?
        /// FRUS volume id (document entries only).
        var volumeId: String?
        /// `CollectionBodyDepth` raw value overriding the collection default — per-document
        /// (document entries) or per-section (heading entries). `nil` = use the default.
        var bodyDepthOverride: String?
        /// Section title (heading) or plain-text body (prose).
        var text: String?
        /// RTF rich-text prose body (prose entries only); base64 in JSON.
        var richText: Data?
        /// Inline research-note texts for this document (opt-in — populated only when the
        /// exporter's "include my research notes" toggle is on). `nil`/absent otherwise.
        var notes: [String]?
    }
}

// MARK: - NativeCollectionError

/// Errors surfaced when decoding or importing a `.fruscollection` file.
enum NativeCollectionError: Error, LocalizedError {
    /// The file is valid JSON but not a FRUS collection file (wrong `format`).
    case notACollectionFile
    /// The file's `formatVersion` is newer than this app understands.
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .notACollectionFile:
            return String(localized: "collection.import.error.notACollection",
                          defaultValue: "This file isn’t a FRUS Explorer collection.")
        case .unsupportedVersion(let version):
            return String(localized: "collection.import.error.version",
                          defaultValue: "This collection was made with a newer version of FRUS Explorer (format \(version)). Update the app to open it.")
        }
    }
}

// MARK: - NativeCollectionSerializer

/// Encodes a `Collection` to a `.fruscollection` file and reconstructs one on import.
///
/// The serializer is the sibling of the `CollectionExporter` family: those turn *resolved,
/// rendered* content into a shareable artifact, whereas this reads the `Collection` model
/// directly to serialize its *source* (references + composition + structure) with no content
/// resolution and no downloaded volume required at export.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D9): initial implementation
enum NativeCollectionSerializer {

    /// The `FRUSCollectionFile.format` discriminator.
    static let formatIdentifier = "fruscollection"
    /// The current on-disk schema version written by `makeFile`.
    static let currentVersion = 1
    /// The file extension for exported collection files.
    static let fileExtension = "fruscollection"

    // MARK: - Encode / Decode

    /// Encodes a file DTO to pretty-printed, key-sorted JSON `Data` (stable and diff-friendly).
    static func encode(_ file: FRUSCollectionFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// Decodes and validates a `.fruscollection` file.
    ///
    /// - Throws: `NativeCollectionError.notACollectionFile` if `format` doesn't match, or
    ///   `.unsupportedVersion` if the file is newer than `currentVersion`; a `DecodingError`
    ///   if the data isn't the expected JSON shape.
    static func decode(_ data: Data) throws -> FRUSCollectionFile {
        let file = try JSONDecoder().decode(FRUSCollectionFile.self, from: data)
        guard file.format == formatIdentifier else {
            throw NativeCollectionError.notACollectionFile
        }
        guard file.formatVersion <= currentVersion else {
            throw NativeCollectionError.unsupportedVersion(file.formatVersion)
        }
        return file
    }

    // MARK: - Build the DTO from a live Collection

    /// Builds the portable file DTO from a live `Collection`.
    ///
    /// - Parameters:
    ///   - collection: The collection to serialize. Its entries are emitted in `sortOrder`.
    ///   - includeNotes: When `true`, each document entry carries the inline note texts from
    ///     `resolveNoteTexts`; when `false` (the D9a default), notes are omitted entirely.
    ///   - resolveNoteTexts: Supplies the research-note bodies for a document entry (the caller
    ///     resolves `selectedNoteIds`/`researchNoteId` against its store). Only invoked when
    ///     `includeNotes` is `true`.
    static func makeFile(
        from collection: Collection,
        includeNotes: Bool,
        resolveNoteTexts: (CollectionEntry) -> [String]
    ) -> FRUSCollectionFile {
        let composition = FRUSCollectionFile.Composition(
            defaultBodyDepth: collection.defaultBodyDepth,
            footnoteStyle: collection.footnoteStyle,
            tocStyle: collection.tocStyle,
            applyHighlights: collection.applyHighlights,
            includeNotes: collection.includeNotes,
            includeWordCloud: collection.includeWordCloud
        )

        let entries: [FRUSCollectionFile.Entry] = (collection.documentEntries ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { entry in
                switch entry.entryKind {
                case .document:
                    let notes = includeNotes
                        ? resolveNoteTexts(entry).filter { !$0.isEmpty }
                        : []
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.document.rawValue,
                        documentId: entry.documentId,
                        volumeId: entry.volumeId,
                        bodyDepthOverride: entry.bodyDepthOverride,
                        text: nil,
                        richText: nil,
                        notes: notes.isEmpty ? nil : notes
                    )
                case .heading:
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.heading.rawValue,
                        documentId: nil,
                        volumeId: nil,
                        bodyDepthOverride: entry.bodyDepthOverride,
                        text: entry.text,
                        richText: nil,
                        notes: nil
                    )
                case .prose:
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.prose.rawValue,
                        documentId: nil,
                        volumeId: nil,
                        bodyDepthOverride: nil,
                        text: entry.text,
                        richText: entry.richText,
                        notes: nil
                    )
                }
            }

        return FRUSCollectionFile(
            format: formatIdentifier,
            formatVersion: currentVersion,
            name: collection.name,
            note: collection.note,
            composition: composition,
            entries: entries
        )
    }

    // MARK: - Apply the DTO into a context (import)

    /// Reconstructs a new `Collection` (plus its entries and any inline notes) from a decoded
    /// file, inserting everything into `context`.
    ///
    /// The imported collection gets fresh identity: new `id`/timestamps, no `projectIds`
    /// (device-local), and entry order normalized to `0..<n`. Inline notes are recreated as new
    /// `ResearchNote` records in the recipient's store and linked via `selectedNoteIds`.
    ///
    /// - Returns: The newly inserted `Collection` (the caller saves the context).
    @discardableResult
    static func apply(_ file: FRUSCollectionFile, into context: ModelContext) -> Collection {
        let collection = Collection(name: file.name, note: file.note)
        collection.defaultBodyDepth = file.composition.defaultBodyDepth
        collection.footnoteStyle = file.composition.footnoteStyle
        collection.tocStyle = file.composition.tocStyle
        collection.applyHighlights = file.composition.applyHighlights
        collection.includeNotes = file.composition.includeNotes
        collection.includeWordCloud = file.composition.includeWordCloud
        context.insert(collection)

        for (index, dto) in file.entries.enumerated() {
            let kind = CollectionEntryKind(rawValue: dto.kind) ?? .document
            let entry = CollectionEntry(
                collectionId: collection.id,
                documentId: dto.documentId ?? "",
                volumeId: dto.volumeId ?? "",
                sortOrder: index
            )
            entry.entryKind = kind
            entry.bodyDepthOverride = dto.bodyDepthOverride
            entry.text = dto.text
            entry.richText = dto.richText
            entry.collection = collection

            if kind == .document, let noteTexts = dto.notes {
                var noteIds: [UUID] = []
                for body in noteTexts where !body.isEmpty {
                    let note = ResearchNote(
                        documentId: dto.documentId ?? "",
                        volumeId: dto.volumeId ?? "",
                        bodyText: body
                    )
                    context.insert(note)
                    noteIds.append(note.id)
                }
                entry.selectedNoteIds = noteIds
            }

            context.insert(entry)
        }

        return collection
    }

    // MARK: - Import a file from disk

    /// Reads a `.fruscollection` file at `url`, decodes + validates it, and reconstructs the
    /// collection into `context`. Handles security-scoped access for a user-picked URL. The
    /// caller is responsible for saving the context and presenting/selecting the result.
    ///
    /// - Throws: `NativeCollectionError` for a non-collection/unsupported file, a `DecodingError`
    ///   for malformed JSON, or a file-read error.
    @discardableResult
    static func importCollection(from url: URL, into context: ModelContext) throws -> Collection {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let file = try decode(data)
        return apply(file, into: context)
    }
}
