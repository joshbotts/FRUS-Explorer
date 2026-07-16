// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Typed identifier for iPadOS Stage Manager document windows.
///
/// Passed to `WindowGroup(for: DocumentWindowID.self)` so SwiftUI can
/// open and restore individual document windows on M-chip iPads running
/// Stage Manager. Each value uniquely identifies one document in the corpus.
///
/// `Codable` conformance lets SwiftUI persist and restore window state
/// across scene lifecycle events (backgrounding, system kills, etc.).
///
/// ## Identity
/// Equality and hashing are deliberately keyed on `(volumeId, documentId)` only —
/// `header` is a display placeholder, not part of the document's identity. SwiftUI
/// reuses an existing window when the presented value compares equal, so without
/// this the *same* document opened with a different placeholder header (e.g. from a
/// search result vs. a cross-reference tap, which build entries with different
/// header strings) would wrongly spawn a duplicate window instead of focusing the
/// one already open.
struct DocumentWindowID: Codable, Hashable {
    var volumeId: String
    var documentId: String
    /// Placeholder heading shown in the window title bar while the document loads.
    /// Not part of the value's identity — see the `Equatable`/`Hashable` note above.
    var header: String

    static func == (lhs: DocumentWindowID, rhs: DocumentWindowID) -> Bool {
        lhs.volumeId == rhs.volumeId && lhs.documentId == rhs.documentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(volumeId)
        hasher.combine(documentId)
    }
}

// MARK: - SourceExplorerRequest

/// Value-based request describing which document's source note the iPad Source Explorer
/// window shows (#317).
///
/// Passed to `WindowGroup(for: SourceExplorerRequest.self)` so the `.ios` Source Explorer scene
/// restores CORRECTLY after backgrounding / a system kill: the payload fully describes the
/// content, so SwiftUI rebuilds the window from the restored value with no `AppState` hand-off.
/// The old id-based scene read the process-global `currentSourceNote` + 5 siblings, which died
/// with the process and left a restored window blank. Same pattern as `DocumentWindowID` and the
/// `ArchivalNeighborsRequest` scene ported in #241.
///
/// Identity is the full payload (each distinct source note / document gets its own window),
/// matching the multi-instance value-based behaviour of the Archival Neighbors window.
struct SourceExplorerRequest: Codable, Hashable, Sendable {
    /// The raw source-note XML the Source Explorer parses.
    var rawSourceNote: String
    /// Coverage year parsed from the dateline, seeding NARA finding-aid period routing.
    var documentYear: Int?
    /// Document heading, for display.
    var documentHeader: String?
    /// Document dateline, for display.
    var documentDateline: String?
    /// The document's volume id.
    var documentVolumeId: String?
    /// The document's `xml:id`.
    var documentId: String?
}

// MARK: - GraphWindowRequest

/// Value-based request describing which document's cross-reference graph the iPad graph window
/// shows (#317).
///
/// Passed to `WindowGroup(for: GraphWindowRequest.self)` so the `.ios` graph scene restores
/// correctly — the old id-based scene read the process-global `currentGraphEntry`, which died
/// with the process. Carries the `DocumentBrowserEntry` display fields so the graph rebuilds from
/// the value; the cross-reference store, manifest, and download state stay read from `AppState`
/// inside the scene (live services, not restorable payload).
///
/// ## Identity
/// Like `DocumentWindowID`, equality/hashing key on `(volumeId, documentId)` ONLY — the display
/// fields are not identity. This preserves the old scene's `.id(entry.id)` retarget behaviour:
/// reopening the same document's graph focuses the existing window instead of spawning a duplicate
/// when a different entry-source supplies a different header/sourceNote.
struct GraphWindowRequest: Codable, Hashable, Sendable {
    /// The document's `xml:id`.
    var documentId: String
    /// The document's volume id.
    var volumeId: String
    /// Printed document number, if present.
    var documentNumber: String?
    /// Document heading / title line.
    var header: String
    /// Dateline string, if present.
    var dateline: String?
    /// Source note, if present.
    var sourceNote: String?
    /// Whether the entry is a FRUS editorial note rather than a primary-source document.
    var isEditorialNote: Bool

    /// Flattens a `DocumentBrowserEntry` into the restorable payload.
    init(entry: DocumentBrowserEntry) {
        documentId = entry.documentId
        volumeId = entry.volumeId
        documentNumber = entry.documentNumber
        header = entry.header
        dateline = entry.dateline
        sourceNote = entry.sourceNote
        isEditorialNote = entry.isEditorialNote
    }

    /// Rebuilds the `DocumentBrowserEntry` the graph view renders.
    var entry: DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: documentId, volumeId: volumeId, documentNumber: documentNumber,
            header: header, dateline: dateline, sourceNote: sourceNote,
            isEditorialNote: isEditorialNote
        )
    }

    static func == (lhs: GraphWindowRequest, rhs: GraphWindowRequest) -> Bool {
        lhs.volumeId == rhs.volumeId && lhs.documentId == rhs.documentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(volumeId)
        hasher.combine(documentId)
    }
}
