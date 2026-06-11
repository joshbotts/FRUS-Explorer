// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ZoteroCollectionExporter

/// Exports a collection's documents as a single Zotero JSON exchange file
/// (`{"version": 5, "items": [...]}`), one `bookSection` item per document.
///
/// Each document's `CollectionExportDocument.zoteroItem` already carries its
/// own tags and notes (resolved by `CollectionEditorView.resolveDocuments()` /
/// `.resolveSmartDocuments()` via `ZoteroJSONExporter.fetchTagsAndNotes`).
/// `options.includeNotes == false` strips child notes from every item so the
/// exported file contains tags but not research-note text.
///
/// Importing the resulting file (e.g. via the Better BibTeX "Zotero JSON"
/// translator) adds every item in one operation — see
/// `Planning/155-Zotero-Export.md` for why this satisfies "Option B at the
/// collection level" without a non-standard `collections` field.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Session 155: initial implementation
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

        let data: Data
        do {
            data = try ZoteroJSONExporter().exportData(items: items)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }

        let filename = sanitized(metadata.name) + "-zotero.json"
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
