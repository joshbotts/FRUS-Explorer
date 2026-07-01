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
/// This RIS file is the **Zotero desktop** path: it imports via File → Import
/// (no Better BibTeX plugin required), bringing in every record — with notes
/// (`N1`), tags (`KW`), and the document number in Extra (`M2`) — in one
/// operation. **Note:** the iOS Zotero app has no RIS/file import (no document-type
/// registration; its share extension is a web-translator, not a citation-file
/// importer), so on iOS the Zotero Web API path is used instead and this file is
/// offered only as a "send to a Mac" artifact. Collection *hierarchy* is not
/// expressible in RIS; File → Import groups the records into a single new
/// collection.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Session 155: initial implementation
///   2.0 — Session 164: switched output from Zotero JSON envelope to RIS
///   2.1 — Zotero strategy: RIS scoped to desktop (iOS has no RIS import);
///         document number moved from N1 (Notes) to M2 (Extra)
final class ZoteroCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        // A Zotero RIS file is a flat reference list — only `.document` items apply; section
        // headings and prose blocks have no Zotero representation and are dropped.
        var zoteroItems = items.documents
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.zoteroItem)

        if !options.includeNotes {
            for index in zoteroItems.indices {
                zoteroItems[index].notes = nil
            }
        }

        let exporter = RISExporter()
        let ris = zoteroItems.map { exporter.export(zoteroItem: $0) }.joined(separator: "\n\n")
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
