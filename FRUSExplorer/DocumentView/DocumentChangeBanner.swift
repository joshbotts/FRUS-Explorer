// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - DocumentChangeBanner

/// The strip above a document that changed in a volume update, or whose stored highlights were
/// made against an earlier rendering — one view for both document-view twins.
///
/// `DocumentView` and `MacDocumentView` each used to carry a byte-identical `staleHighlightBanner`,
/// which is two places for one sentence to drift (the Source Explorer twins drifted by four spaces
/// of indent and a scripted patch no-op'd on one of them). The sentence now lives here and the
/// twins mount it.
///
/// The truth table is the Volume-Update-Annotation-Integrity design's §6 (R-5 P2):
///
/// | recorded change | highlights stale | says |
/// |---|---|---|
/// | none | no | nothing — the view is empty |
/// | none | yes | the pre-P2 hedge, word for word (`highlight.stale.warning`) |
/// | body | no | the text changed; highlight positions may have moved |
/// | body | yes | the text changed; some highlights may be misaligned |
/// | apparatus | no | footnotes, source note, or heading changed; the text did not |
/// | apparatus | yes | both facts, because both are true |
/// | vanished | any | no longer in the volume (unreachable from an open document, but stated) |
///
/// "Stale" is the caller's fact — each highlight's own `renderingVersion` against the document's —
/// and the recorded change is the index's fact (`document_revisions`). They usually agree, since
/// `body_hash` IS `renderingVersion`, but a highlight made before the table existed has no row to
/// agree with, and a row is only consulted while it is unreviewed.
///
/// Version history:
///   1.0 — R-5 P2: lifted from the twins' `staleHighlightBanner`; revision-aware
///   1.1 — R-5 P3: optional `onReview` control
struct DocumentChangeBanner: View {

    /// This document's row in `document_revisions`, if the caller loaded one.
    let revision: IndexingPipeline.DocumentRevision?
    /// Whether any stored highlight's `renderingVersion` differs from the document's current one.
    let highlightsStale: Bool
    /// Opens the per-document review sheet (R-5 P3). Nil renders the banner without a control.
    var onReview: (() -> Void)? = nil

    var body: some View {
        if let line = Self.line(revision: revision, highlightsStale: highlightsStale) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let onReview {
                    Spacer(minLength: 8)
                    Button(String(localized: "document.changed.review", defaultValue: "Review…"), action: onReview)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("document.changeBanner.review")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08))
            .accessibilityIdentifier("document.changeBanner")
        }
    }

    /// This document's row, read through the pipeline both twins already hold. Nil when there is
    /// no pipeline yet, no row (the volume was never re-indexed with the table present), or the
    /// read fails — all three render as "nothing recorded", which is the only honest default.
    static func revision(volumeId: String, documentId: String,
                         pipeline: IndexingPipeline?) async -> IndexingPipeline.DocumentRevision? {
        guard let pipeline else { return nil }
        return try? await pipeline.documentRevision(volumeId: volumeId, documentId: documentId)
    }

    /// The sentence for one (change, staleness) pair, or `nil` when there is nothing to say.
    ///
    /// Pure and static so a test can drive the whole table without a view host. A row counts as
    /// a change only while it is stamped (`changedAt`) and unreviewed (`reviewedAt == nil`): the
    /// first index of a volume stamps nothing, and a review — when a later phase adds one — must
    /// silence the banner without deleting the row.
    static func line(revision: IndexingPipeline.DocumentRevision?, highlightsStale: Bool) -> String? {
        let kind: String? = {
            guard let revision, revision.changedAt != nil, revision.reviewedAt == nil else { return nil }
            return revision.changeKind
        }()
        switch (kind, highlightsStale) {
        case (nil, false):
            return nil
        case (nil, true):
            return String(localized: "highlight.stale.warning",
                          defaultValue: "Some highlights may be misaligned — the document has been updated since they were created.")
        case ("body", false):
            return String(localized: "document.changed.body",
                          defaultValue: "The text of this document changed in a volume update. Highlight positions may have moved.")
        case ("body", true):
            return String(localized: "document.changed.body.stale",
                          defaultValue: "The text of this document changed in a volume update. Some highlights may be misaligned.")
        case ("apparatus", false):
            return String(localized: "document.changed.apparatus",
                          defaultValue: "Footnotes, the source note, or the heading changed in a volume update. The text did not.")
        case ("apparatus", true):
            return String(localized: "document.changed.apparatus.stale",
                          defaultValue: "Footnotes, the source note, or the heading changed in a volume update, and some highlights may be misaligned.")
        case ("vanished", _):
            return String(localized: "document.changed.vanished",
                          defaultValue: "This document is no longer in the volume after an update.")
        case (_, true):
            // A kind this build does not know, with stale highlights: the hedge still holds.
            return String(localized: "highlight.stale.warning",
                          defaultValue: "Some highlights may be misaligned — the document has been updated since they were created.")
        case (_, false):
            return nil
        }
    }
}
