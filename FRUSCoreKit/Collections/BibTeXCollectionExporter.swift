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
/// The M3 per-entry `titleOverride` is a **display** heading (ToC label + document
/// heading) and is deliberately **not** applied here: BibTeX/Zotero records carry the
/// document's true bibliographic `title` from `zoteroItem`, so a reference manager
/// imports the real citation, not the author's collection-local relabel.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D7): initial implementation
///   1.1 — #1463: the file is named through `CollectionExportNaming`, so an unnamed collection
///          writes `Untitled Collection.bib` rather than a hidden `.bib`
///   1.2 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, over the kit's
///          `BibtexExporter`; `bibTeX(for:options:)` gives the text `export` writes
public final class BibTeXCollectionExporter: CollectionExporter {

    /// Creates an exporter.
    public init() {}

    /// The `.bib` file's text for `items`: one record per document that carries a Zotero item, in
    /// collection order, blank-line separated, with a closing newline when there is any — what
    /// `export` writes, for a host that keeps the text rather than a file.
    ///
    /// - Parameters:
    ///   - items: The ordered, pre-resolved items; only `.document` items apply.
    ///   - options: The export's options; `includeNotes == false` strips `annote`.
    /// - Returns: The BibTeX text.
    public func bibTeX(for items: [CollectionExportItem], options: CollectionExportOptions) -> String {
        let documents = items.documents.sorted { $0.sortOrder < $1.sortOrder }
        let exporter = BibtexExporter()

        let records: [String] = documents.compactMap { doc in
            guard var item = doc.zoteroItem else { return nil }
            if !options.includeNotes { item.notes = nil }
            return exporter.export(zoteroItem: item, volumeId: doc.volumeId, documentId: doc.documentId)
        }

        return records.joined(separator: "\n\n") + (records.isEmpty ? "" : "\n")
    }

    // MARK: - CollectionExporter

    @MainActor
    public func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        let data = Data(bibTeX(for: items, options: options).utf8)

        let url = CollectionExportNaming.temporaryFileURL(savedName: metadata.name, suffix: ".bib")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }
}
