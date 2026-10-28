// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import UniformTypeIdentifiers

// The app's half of `.fruscollection` (FRUS Explorer Light, S18b): what reads or writes SwiftData, the
// file system or the index. The file's shape, its encoder and decoder, and the writer and importer over
// values are FRUSCoreKit's (`FRUSCoreKit/Collections/NativeCollectionFormat.swift`).

// MARK: - UTType.fruscollection

extension UTType {
    /// The exported `.fruscollection` document type, matching the
    /// `UTExportedTypeDeclarations` entry in both platforms' Info.plists (Phase 4, D6/D9
    /// OS file-association work). Used by the in-app import `fileImporter`s so the open
    /// panel only offers native collection files rather than any `.data` file
    /// (Authoring Phase 1 housekeeping).
    static var fruscollection: UTType {
        UTType(exportedAs: "bottsywattsy.FRUS-Explorer.fruscollection")
    }
}

// MARK: - NativeCollectionSerializer + the app's models

extension NativeCollectionSerializer {

    // MARK: - Write to a temporary file

    /// Encodes `file` and writes it to a temporary `.fruscollection` file named after the collection, returning its
    /// URL — the export sheet's native path.
    ///
    /// The file is named the way every rendered export is (`CollectionExportNaming`, #1463): a collection with no name
    /// writes `Untitled Collection.fruscollection`, where this path used to fall back to `collection.fruscollection`,
    /// and a name opening with a dot no longer hides the file. The file's own `name` is left as it was saved, so an
    /// import restores the collection as it was.
    static func writeTemporaryFile(_ file: FRUSCollectionFile) throws -> URL {
        let data = try encode(file)
        let url = CollectionExportNaming.temporaryFileURL(savedName: file.name, suffix: "." + fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Build the DTO from a live Collection

    /// Builds the portable file DTO from a live `Collection`: FRUSCoreKit's
    /// `makeFile(from:includeNotes:resolveNoteTexts:)` over its values, writing the minimum version
    /// the content needs.
    ///
    /// The file schema promises RTF, but a pre-RTF (Phase 3b) prose entry still holds a JSON-encoded
    /// AttributedString — so each prose entry is healed here first, in `sortOrder`, before its values
    /// are read, and shared files never propagate the legacy encoding.
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
        let entries = (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        for entry in entries where entry.entryKind == .prose {
            ProseRichText.migrateLegacyJSONIfNeeded(entry)
        }
        // Each value is answered with its own model: the writer asks for the document entries in
        // order, so the first unanswered model whose values are these is the one asked for, even where
        // sync left two copies of an entry under one id (#1791) that differ in their selection.
        let values = entries.map(CollectionEntryExport.init)
        var unanswered = Array(zip(values, entries))
        return makeFile(from: CollectionExport(collection, entries: values),
                        includeNotes: includeNotes,
                        resolveNoteTexts: { value in
                            guard let index = unanswered.firstIndex(where: { $0.0 == value }) else { return [] }
                            return resolveNoteTexts(unanswered.remove(at: index).1)
                        })
    }

    // MARK: - Apply the DTO into a context (import)

    /// Reconstructs a new `Collection` (plus its entries and any inline notes) from a decoded
    /// file, inserting everything into `context`: the values FRUSCoreKit's `importedValues(from:)`
    /// makes, inserted in the order a reader's store expects — the collection, then each entry after
    /// the notes it brought.
    ///
    /// The imported collection gets fresh identity: new `id`/timestamps, no `projectIds`
    /// (device-local), and entry order normalized to the file's positions. Inline notes are recreated
    /// as new `ResearchNote` records in the recipient's store and linked via `selectedNoteIds`. Every
    /// model mints its own id, as before, and every field the values leave out keeps the model's
    /// default.
    ///
    /// - Returns: The newly inserted `Collection` (the caller saves the context).
    @discardableResult
    static func apply(_ file: FRUSCollectionFile, into context: ModelContext) -> Collection {
        let imported = importedValues(from: file)
        let values = imported.collection
        let collection = Collection(name: values.name, note: values.note)
        collection.defaultBodyDepth = values.defaultBodyDepth ?? collection.defaultBodyDepth
        collection.footnoteStyle = values.footnoteStyle ?? collection.footnoteStyle
        collection.includeFootnotes = values.includeFootnotes
        collection.includeSourceNote = values.includeSourceNote
        collection.tocStyle = values.tocStyle ?? collection.tocStyle
        collection.applyHighlights = values.applyHighlights ?? collection.applyHighlights
        collection.includeNotes = values.includeNotes ?? collection.includeNotes
        collection.includeWordCloud = values.includeWordCloud ?? collection.includeWordCloud
        collection.defaultIncludeHeadnote = values.defaultIncludeHeadnote ?? collection.defaultIncludeHeadnote
        collection.subtitle = values.subtitle
        collection.authorLine = values.authorLine
        collection.introductionText = values.introductionText
        collection.introductionRichText = values.introductionRichText
        collection.includeColophon = values.includeColophon ?? collection.includeColophon
        collection.includeProjectProvenance = values.includeProjectProvenance ?? collection.includeProjectProvenance
        collection.includeMethodAppendix = values.includeMethodAppendix ?? collection.includeMethodAppendix
        context.insert(collection)

        let notesById = Dictionary(imported.notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for value in values.entries {
            let entry = CollectionEntry(
                collectionId: collection.id,
                documentId: value.documentId,
                volumeId: value.volumeId,
                sortOrder: value.sortOrder
            )
            if let kind = value.kind.flatMap(CollectionEntryKind.init(rawValue:)) {
                entry.entryKind = kind
            }
            entry.bodyDepthOverride = value.bodyDepthOverride
            entry.text = value.text
            entry.richText = value.richText
            entry.includeHeadnote = value.includeHeadnote
            entry.headnoteSummaryId = value.headnoteSummaryId
            entry.titleOverride = value.titleOverride
            entry.applyHighlightsOverride = value.applyHighlightsOverride
            entry.includeNotesOverride = value.includeNotesOverride
            entry.includeSourceNoteOverride = value.includeSourceNoteOverride
            entry.includeFootnotesOverride = value.includeFootnotesOverride
            entry.summaryPromptIdOverride = value.summaryPromptIdOverride
            entry.includeRelatedDocuments = value.includeRelatedDocuments
            entry.excerptStart = value.excerptStart
            entry.excerptEnd = value.excerptEnd
            entry.excerptRenderingVersion = value.excerptRenderingVersion
            entry.excerptColorTag = value.excerptColorTag
            entry.generatedBlockType = value.generatedBlockType
            entry.level = value.level ?? entry.level
            entry.collection = collection

            // The notes a document entry brought, recreated in the recipient's store and pinned to it.
            var noteIds: [UUID] = []
            for noteId in value.selectedNoteIds {
                guard let noteValues = notesById[noteId] else { continue }
                let note = ResearchNote(
                    documentId: noteValues.documentId,
                    volumeId: noteValues.volumeId,
                    bodyText: noteValues.bodyText
                )
                context.insert(note)
                noteIds.append(note.id)
            }
            entry.selectedNoteIds = noteIds

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

    // MARK: - Index an import's notes

    /// Puts the notes an import brought into the search index, so they are findable at once rather than
    /// at the next launch's replay (the 2026-09-28 audit, from #1280's session log).
    ///
    /// `apply` recreates each note a file carries as a new `ResearchNote` linked to its entry, and every
    /// import path only saved, so search could not see an imported note until the app relaunched. Each
    /// document an imported note sits on is rewritten through the column's one writer,
    /// `ResearchNote.reindexNoteText`, which reads every note on the document — the reader's own as well
    /// as the imported ones — so an import never narrows what the column held. All three import paths
    /// call it after they save, since that save is what the writer's read sees: Import Collection… in
    /// `CollectionListView` and in the Mac collection window, and a file opened from Files, Mail, AirDrop
    /// or Finder (`FRUSExplorerApp.importOpenedCollection`). `ImportedNoteIndexTests.everyImportPathIndexes`
    /// finds the paths by their call to `apply` or `importCollection(from:into:)`, not from a list.
    ///
    /// - Parameters:
    ///   - collection: The collection `apply` made.
    ///   - context: The context it was saved in.
    ///   - pipeline: The index to write through.
    @MainActor
    static func indexImportedNotes(of collection: Collection, in context: ModelContext,
                                   pipeline: IndexingPipeline) async {
        var indexed = Set<String>()
        let entries = (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        for entry in entries where entry.entryKind == .document && !entry.selectedNoteIds.isEmpty {
            let (volumeId, documentId) = (entry.volumeId, entry.documentId)
            guard !volumeId.isEmpty, !documentId.isEmpty,
                  indexed.insert("\(volumeId)/\(documentId)").inserted else { continue }
            await ResearchNote.reindexNoteText(volumeId: volumeId, documentId: documentId,
                                               in: context, pipeline: pipeline)
        }
    }
}
