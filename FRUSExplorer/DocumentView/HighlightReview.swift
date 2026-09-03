// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - HighlightReview

/// What a reader can do to one highlight after a volume update, and the one fact the review
/// surface states about it (Volume-Update-Annotation-Integrity design §5.4, R-5 P3).
///
/// Two of the design's three verbs live here — **confirm** and **delete**. *Modify* (the
/// unique-match re-anchor) is deliberately absent: it needs the current flat text, a UTF-16
/// search that honours the `"\n\n"` block seams `selectedText` carries, and a preview the reader
/// confirms before anything moves, and §7 forbids getting it wrong silently. It is the next
/// phase's, not a corner of this one.
///
/// Confirm rewrites `renderingVersion`, which is the only per-highlight review state the model
/// has — and it is a CloudKit-mirrored field, so a confirmation made on one device clears the amber
/// on every device. Since R-5 P3b-2 the document-level stamp travels too, through the
/// `AnnotationReview` ledger, so both halves of a review now reach the reader's other devices;
/// highlights keep this field rather than gaining a ledger row, because the two key on different
/// hashes (`renderingVersion` against the revision row's `body_hash`, the ledger against its
/// `content_hash`) and an apparatus-only correction moves one and not the other.
///
/// Version history:
///   1.0 — R-5 P3: initial implementation
enum HighlightReview {

    /// How a stored highlight stands against the text the reader would see now.
    enum Status: Equatable, Sendable {
        /// Its `renderingVersion` is the document's current one: the offsets are exact.
        case aligned
        /// Made against an earlier rendering; positions may have moved. `hasPassage` says whether
        /// the highlight stored the words it covered — without them it can only be reviewed by eye.
        case stale(hasPassage: Bool)
        /// Nothing to compare against: no open render model and no revision row on this device.
        case unverifiable
    }

    /// The status of `highlight` against `currentVersion` — the open document's
    /// `renderingVersion`, or the revision row's `bodyHash` (P1 pinned the two equal), or nil.
    static func status(of highlight: DocumentHighlight, currentVersion: String?) -> Status {
        guard let currentVersion, !currentVersion.isEmpty else { return .unverifiable }
        if highlight.renderingVersion == currentVersion { return .aligned }
        return .stale(hasPassage: !highlight.selectedText.isEmpty)
    }

    /// Confirm: the reader has looked and the highlight stands. Rewrites the version the highlight
    /// carries to the current one, which un-stales the paint and makes it tappable again. The
    /// offsets are NOT touched — that would be a silent re-anchor.
    static func confirm(_ highlight: DocumentHighlight, currentVersion: String) {
        guard !currentVersion.isEmpty else { return }
        highlight.renderingVersion = currentVersion
    }

    /// Delete, once the caller has confirmed it with the same weight as the in-document path.
    /// A note linked through `noteId` is kept — the link was always one-directional and dangling
    /// links are tolerated everywhere else; §7 forbids deleting anything on the app's initiative.
    static func delete(_ highlight: DocumentHighlight, in context: ModelContext) {
        context.delete(highlight)
    }
}

// MARK: - HighlightSignature

/// What the web view compares to decide whether to repaint highlights.
///
/// Until R-5 P3 it compared ID lists, so an in-place confirm — same id, new `renderingVersion` —
/// left the highlight amber until the document reloaded, and a future re-anchor would not have
/// moved on screen. The signature carries the three facts the painter reads.
struct HighlightSignature: Hashable, Sendable {
    let id: UUID
    let startOffset: Int
    let endOffset: Int
    let renderingVersion: String

    init(_ highlight: DocumentHighlight) {
        id = highlight.id
        startOffset = highlight.startOffset
        endOffset = highlight.endOffset
        renderingVersion = highlight.renderingVersion
    }

    /// The signature of a whole list, in order.
    static func signature(of highlights: [DocumentHighlight]) -> [HighlightSignature] {
        highlights.map(HighlightSignature.init)
    }
}
