// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ReadingHistoryEntry

/// Records a single document access event.
///
/// Created automatically when the user opens a document in the Document view.
/// The project active at that moment is captured in `projectId` (`nil` if in
/// global context). Reading history entries are immutable historical records —
/// unlike notes and collections they carry no cross-project visibility logic;
/// they are always visible in the project context that created them and in
/// the global context.
///
/// The same document may have multiple entries (one per visit). The most-recent
/// entry is used for "last read" display in the Browser view.
///
/// ## No `lastModified`
/// Reading history entries are immutable after creation. `lastModified` is not
/// present because entries are never mutated — a new entry is always created for
/// each access event.
///
/// Version history:
///   1.0 — Session 04: initial implementation
@Model final class ReadingHistoryEntry {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    var documentId: String = ""
    var volumeId: String = ""

    // MARK: - Project Context

    /// The project active when the document was accessed. `nil` for global context.
    var projectId: UUID?

    // MARK: - Timestamp

    /// When the document was opened. Optional for CloudKit schema compatibility — always non-nil in practice.
    var accessedAt: Date?

    // MARK: - Initializer

    init(
        documentId: String,
        volumeId: String,
        projectId: UUID? = nil
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.projectId = projectId
        accessedAt = Date.now

        #if DEBUG
        print("[SwiftData] ReadingHistoryEntry created: \(volumeId)/\(documentId) project=\(projectId?.uuidString ?? "nil")")
        #endif
    }
}
