// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchNote

/// A user annotation attached to a specific FRUS document.
///
/// ## Project Tagging
/// `projectIds` carries the project tags applied to this note. A note is created
/// with the currently active project's ID (if any). Users can subsequently add or
/// remove project tags. A note is never deleted when a project tag is removed —
/// removal only hides the note from that project's lens.
///
/// ## Cross-Project Visibility
/// When a user views a document in a project that does not own this note, the note
/// is hidden by default but signaled via a disclosure indicator. The user can reveal
/// and optionally promote the note to the current project by adding its ID to
/// `projectIds`.
///
/// ## Selected Summaries
/// `selectedSummaryIds` lists `GeneratedSummary.id` values the user has promoted
/// to draft content in this note. The summaries are not embedded in the note —
/// they are referenced by ID so that note text remains the user's own words.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — #1275: `richText`, the formatted body, with `bodyText` kept as its plain projection
@Model final class ResearchNote {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    /// The FRUS document this note is attached to.
    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    /// The volume containing the document.
    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Content

    /// The user's note text as PLAIN text — and the authoritative copy for everything that reads a
    /// note without rendering it.
    ///
    /// Since #1275 it is the plain projection of ``richText`` when that is present, exactly as
    /// `CollectionEntry.text` projects `CollectionEntry.richText`. Search indexing, the Zotero and
    /// Obsidian exports, the JSON envelope and all five in-app previews read THIS and are unchanged
    /// by rich text existing — which is the whole reason the formatted copy is stored beside the
    /// plain one rather than replacing it.
    var bodyText: String = "" {
        didSet { lastModified = .now }
    }

    /// The note body as RTF, when the reader has formatted it (#1275).
    ///
    /// `nil` for a note written before rich text, or one whose body carries no formatting — and a
    /// reader of a note must treat `nil` as "use ``bodyText``", never as "empty". The exact shape
    /// `CollectionEntry.richText` established, down to the `Data?`: RTF rather than an encoded
    /// `AttributedString`, because the three collection exporters already render RTF spans, and
    /// rather than Markdown-in-`bodyText`, which would have shipped literal asterisks to five
    /// in-app previews, three export formats and the reader's Zotero library.
    ///
    /// **This property is why #1275 needed a CloudKit Production deploy** — see
    /// `CloudKitSchemaInventory`.
    ///
    /// ## What does NOT carry it
    /// A `.fruscollection` file writes a document's notes as bare strings and rebuilds them from
    /// `bodyText` alone, so formatting survives this device and iCloud but not a collection shared
    /// with a colleague and reimported — while a formatted prose block a few bytes away in the same
    /// file does survive, because that format carries `CollectionEntry.richText`. Widening the note
    /// payload is a file-format change and is deliberately not part of #1275; both manuals say so.
    var richText: Data? {
        didSet { lastModified = .now }
    }

    // MARK: - Tags and References

    /// IDs of `Project` records whose lens this note appears in.
    var projectIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `UserTag` records the user has applied to this note.
    var userTagIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `GeneratedSummary` records the user has promoted to draft content here.
    var selectedSummaryIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        documentId: String,
        volumeId: String,
        bodyText: String = "",
        projectIds: [UUID] = [],
        userTagIds: [UUID] = [],
        selectedSummaryIds: [UUID] = []
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.bodyText = bodyText
        self.projectIds = projectIds
        self.userTagIds = userTagIds
        self.selectedSummaryIds = selectedSummaryIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] ResearchNote created: \(id) for \(volumeId)/\(documentId)")
        #endif
    }
}
