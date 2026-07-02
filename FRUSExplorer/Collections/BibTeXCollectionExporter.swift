// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BibTeXCollectionExporter

/// Exports a collection's documents as a single BibTeX `.bib` file, one
/// `@incollection` record per document — for LaTeX bibliographies and reference
/// managers (Zotero via Better BibTeX, JabRef, Mendeley, etc.) that prefer BibTeX
/// over RIS.
///
/// Each document's `CollectionExportDocument.zoteroItem` carries the resolved
/// bibliographic fields, tags, and research notes (built by
/// `CollectionEditorView.resolveDocuments()` / `.resolveSmartDocuments()`); the
/// document's own `volumeId`/`documentId` supply the citation key
/// (`{volumeId}_{documentId}`). Records are rendered by
/// `BibtexExporter.export(zoteroItem:volumeId:documentId:)`.
/// `options.includeNotes == false` strips research-note text (`annote`) from every
/// record; tags (`keywords`) are always kept.
///
/// A `.bib` file is a flat reference list, so only `.document` items apply — section
/// headings and prose blocks have no BibTeX representation and are dropped.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D7): initial implementation
final class BibTeXCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        let documents = items.documents.sorted { $0.sortOrder < $1.sortOrder }
        let exporter = BibtexExporter()

        let records: [String] = documents.compactMap { doc in
            guard var item = doc.zoteroItem else { return nil }
            if !options.includeNotes { item.notes = nil }
            return exporter.export(zoteroItem: item, volumeId: doc.volumeId, documentId: doc.documentId)
        }

        let bib = records.joined(separator: "\n\n") + (records.isEmpty ? "" : "\n")
        let data = Data(bib.utf8)

        let filename = sanitized(metadata.name) + ".bib"
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
