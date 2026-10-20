// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - IndexingPipeline + reading order

/// A volume's indexed rows in its reading order, for the two lists that offer a volume's documents to pick from: Add
/// Documents' Browse list (`CollectionAddDocumentsSheet`) and the Mac graph window's document picker
/// (`CrossReferenceGraphWindowView`) (#1690's first line).
///
/// Both had listed `documents(forVolume:)`, whose query is `ORDER BY rowid`: the order the store pass wrote the rows in,
/// in which a section's own text, a row of its own since index version 68 (#1536), follows the documents it holds.
/// Browse puts that text first in the section, and the reader steps through the volume in that order
/// (`readingSequence(forVolume:)`). These lists now take their order from the same walk,
/// `mergeReadingSequence(structure:cached:volumeId:)`, and keep only the index's rows: the walk also makes up an entry
/// for a section the index leaves out (Persons, Sources, the table of contents, the index), which the reader opens as a
/// page and which is no document to add to a collection or to graph.
///
/// App code that calls the kit; the kit is unchanged.
///
/// Version history:
///   1.0 — #1690's first line, plan of record A14: initial implementation
extension IndexingPipeline {

    /// The rows the index holds for `volumeId`, in the volume's reading order (`indexedRowsInReadingOrder(_:structure:volumeId:)`).
    ///
    /// - Parameter volumeId: The volume to list.
    /// - Returns: `documents(forVolume:)`'s rows, reordered; in its own order when the index holds no outline of the
    ///   volume, as for a volume whose last store pass did not finish.
    func indexedDocumentsInReadingOrder(forVolume volumeId: String) throws -> [DocumentBrowserEntry] {
        let rows = try documents(forVolume: volumeId)
        return Self.indexedRowsInReadingOrder(rows, structure: try cachedVolumeStructure(forVolumeId: volumeId),
                                              volumeId: volumeId)
    }

    /// `rows` in the order the volume's outline reads them, as the reader steps through it: each section's own text,
    /// then its documents, then its sections, depth first.
    ///
    /// Nothing is added and nothing is lost: each of `rows` once, any row the outline does not reach after the rest in
    /// its own order (`mergeReadingSequence`'s safety net), and none of the entries the walk makes up for sections the
    /// index leaves out. Pure, so it is tested without a database.
    ///
    /// - Parameters:
    ///   - rows: The volume's rows from the index.
    ///   - structure: The volume's outline; with none, or an empty one, `rows` comes back as it is.
    ///   - volumeId: The volume.
    nonisolated static func indexedRowsInReadingOrder(_ rows: [DocumentBrowserEntry], structure: VolumeStructure?,
                                                      volumeId: String) -> [DocumentBrowserEntry] {
        guard let structure, !structure.isEmpty else { return rows }
        let held = Set(rows.map(\.documentId))
        return mergeReadingSequence(structure: structure, cached: rows, volumeId: volumeId)
            .filter { held.contains($0.documentId) }
    }
}
