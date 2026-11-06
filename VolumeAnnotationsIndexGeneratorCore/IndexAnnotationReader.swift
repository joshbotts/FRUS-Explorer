// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FRUSCoreKit
import SQLite3

// MARK: - IndexVolumeFacts

/// What a full index holds for one volume, by the app's own rules: the rows the People browser,
/// Search's chips and the volume's structure list read.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
struct IndexVolumeFacts: Sendable, Equatable {
    /// Every row of the volume outside front matter, by document id.
    var rowIds: Set<String> = []
    /// Rows with a person mention that resolves to one of the volume's `persons` rows.
    var peopleDocuments: Set<String> = []
    /// The volume's `persons` rows.
    var personsListed = 0
    /// The volume's `terms` refs, without a leading `#`.
    var termRefs: Set<String> = []
    /// Each row's stored source note.
    var sourceNotes: [String: String] = [:]
    /// Rows with a stored classification marking.
    var classified: Set<String> = []
    /// Rows with a despatch serial.
    var despatch: Set<String> = []
    /// Each row's stored heading.
    var headers: [String: String] = [:]
    /// The kinds of the sections the volume's stored structure names.
    var sections: [String] = []
}

// MARK: - IndexFacts

/// A full index read for annotation counts.
struct IndexFacts: Sendable {
    /// The lowest and highest `document_revisions.index_version` stamp, or `nil` when none is set.
    var indexVersions: ClosedRange<Int>?
    /// Each volume's facts, by volume id.
    var volumes: [String: IndexVolumeFacts] = [:]
}

// MARK: - IndexAnnotationReader

/// Reads the counts the app's index answers from a full index, opened read-only.
enum IndexAnnotationReader {

    /// The body containers a volume's structure holds documents in, which are not printed aids.
    static let organizingKinds: Set<String> = ["compilation", "chapter", "subchapter"]

    /// Reads every volume's facts from the index at `database`.
    static func read(database: URL) throws -> IndexFacts {
        let index = try SQLiteReader(path: database.path)
        var facts = IndexFacts()

        try index.each("""
            SELECT MIN(index_version), MAX(index_version) FROM document_revisions
            WHERE index_version IS NOT NULL
            """) { row in
            if let low = row.int(0), let high = row.int(1) { facts.indexVersions = low...high }
        }
        try index.each("""
            SELECT volume_id, document_id, header, source_note, despatch_serial
            FROM document_cache WHERE is_front_matter = 0
            """) { row in
            guard let volume = row.text(0), let document = row.text(1) else { return }
            var entry = facts.volumes[volume] ?? IndexVolumeFacts()
            entry.rowIds.insert(document)
            if let header = row.text(2) { entry.headers[document] = header }
            if let note = row.text(3), !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entry.sourceNotes[document] = note
            }
            if let serial = row.text(4), !serial.isEmpty { entry.despatch.insert(document) }
            facts.volumes[volume] = entry
        }
        try index.each("""
            SELECT DISTINCT pm.volume_id, pm.document_id FROM person_mentions pm
            JOIN persons p ON p.volume_id = pm.volume_id AND p.ref = pm.person_ref
            """) { row in
            guard let volume = row.text(0), let document = row.text(1) else { return }
            facts.volumes[volume, default: IndexVolumeFacts()].peopleDocuments.insert(document)
        }
        try index.each("SELECT volume_id, COUNT(*) FROM persons GROUP BY volume_id") { row in
            guard let volume = row.text(0) else { return }
            facts.volumes[volume, default: IndexVolumeFacts()].personsListed = row.int(1) ?? 0
        }
        try index.each("SELECT volume_id, ref FROM terms") { row in
            guard let volume = row.text(0), let ref = row.text(1) else { return }
            let pointer = ref.hasPrefix("#") ? String(ref.dropFirst()) : ref
            facts.volumes[volume, default: IndexVolumeFacts()].termRefs.insert(pointer)
        }
        try index.each("""
            SELECT volume_id, document_id FROM document_sources
            WHERE classification IS NOT NULL AND TRIM(classification) <> ''
            """) { row in
            guard let volume = row.text(0), let document = row.text(1) else { return }
            facts.volumes[volume, default: IndexVolumeFacts()].classified.insert(document)
        }
        let decoder = JSONDecoder()
        try index.each("SELECT volume_id, structure_json FROM volume_structures") { row in
            guard let volume = row.text(0), let json = row.text(1),
                  let structure = try? decoder.decode(VolumeStructure.self, from: Data(json.utf8)) else { return }
            facts.volumes[volume, default: IndexVolumeFacts()].sections = sectionKinds(of: structure.sections)
        }
        return facts
    }

    /// The kinds of `sections` and their subsections, less the containers that organize documents,
    /// plus `list-of-papers` for an analytical List of Papers (`xml:id` `papers…` or `toc-papers…`),
    /// which the parser names by its `@type`.
    static func sectionKinds(of sections: [VolumeSection]) -> [String] {
        var kinds = Set<String>()
        func visit(_ section: VolumeSection) {
            if !organizingKinds.contains(section.divType) { kinds.insert(section.divType) }
            let id = section.sectionId.lowercased()
            if id.hasPrefix("papers") || id.hasPrefix("toc-papers") { kinds.insert("list-of-papers") }
            section.subsections.forEach(visit)
        }
        sections.forEach(visit)
        return kinds.sorted()
    }
}

// MARK: - SQLiteReader

/// A read-only SQLite connection that runs a statement and hands each row to a closure.
final class SQLiteReader {

    /// One result row.
    struct Row {
        fileprivate let statement: OpaquePointer

        /// Column `index` as text, or `nil` when it is NULL.
        func text(_ index: Int32) -> String? {
            guard let bytes = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: bytes)
        }

        /// Column `index` as an integer, or `nil` when it is NULL.
        func int(_ index: Int32) -> Int? {
            sqlite3_column_type(statement, index) == SQLITE_NULL
                ? nil : Int(sqlite3_column_int64(statement, index))
        }
    }

    private var handle: OpaquePointer?

    /// Opens the database at `path` read-only.
    init(path: String) throws {
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open"
            sqlite3_close(handle)
            throw VolumeAnnotationsIndexError.unreadableIndex(path: path, message: message)
        }
    }

    deinit { sqlite3_close(handle) }

    /// Runs `sql` and calls `body` for each row.
    func each(_ sql: String, _ body: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot prepare"
            throw VolumeAnnotationsIndexError.unreadableIndex(path: sql, message: message)
        }
        defer { sqlite3_finalize(statement) }
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { return }
            guard step == SQLITE_ROW else {
                let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "step failed"
                throw VolumeAnnotationsIndexError.unreadableIndex(path: sql, message: message)
            }
            try body(Row(statement: statement))
        }
    }
}
