// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ZoteroCollectionExporter

/// Exports a collection's documents as a single RIS file, one `TY  - CHAP`
/// record per document.
///
/// Each document's `CollectionExportDocument.zoteroItem` already carries its
/// own tags and notes (resolved by `CollectionEditorView.resolveDocuments()` /
/// `.resolveSmartDocuments()` via `ZoteroJSONExporter.fetchTagsAndNotes`); those
/// `Item`s are rendered to RIS by `RISExporter.export(zoteroItem:)`.
/// `options.includeNotes == false` strips child notes from every item so the
/// exported file contains tags but not research-note text.
///
/// RIS is used (rather than the Zotero web-API JSON envelope) because standard
/// Zotero imports RIS on every platform — including iOS, where the Better BibTeX
/// plugin that the JSON envelope relied on is unavailable. Importing the file
/// adds every record in one operation.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Session 155: initial implementation
///   2.0 — Session 164: switched output from Zotero JSON envelope to RIS so the
///         file imports into standard Zotero (incl. iOS) without a plugin
final class ZoteroCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions
    ) async throws -> URL {
        var items = documents
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.zoteroItem)

        if !options.includeNotes {
            for index in items.indices {
                items[index].notes = nil
            }
        }

        let exporter = RISExporter()
        let ris = items.map { exporter.export(zoteroItem: $0) }.joined(separator: "\n\n")
        let data = Data(ris.utf8)

        let filename = sanitized(metadata.name) + "-zotero.ris"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - Helpers

    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }
}
