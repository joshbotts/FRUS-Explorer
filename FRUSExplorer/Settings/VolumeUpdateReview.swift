// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeUpdateReview

/// What the last volume updates did, at the grain the reader acted: per volume.
///
/// The design's §5.5 asks for a volume-level entry point with document-level content —
/// *"frus1969-76v12 was updated. 3 documents you have annotated changed."* — and this is the
/// arithmetic behind that sentence, kept pure so the hub section that renders it and the test
/// that pins it read the same numbers. The inputs are the two facts the app already holds: the
/// unreviewed rows of `document_revisions`, and the set of `"volumeId/documentId"` keys carrying
/// any of the reader's research (`ResearchDocumentAggregation.annotatedKeys`, the same set
/// `ResearchView` filters on, so the hub's count and the sidebar's count cannot disagree).
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
enum VolumeUpdateReview {

    /// One updated volume's change set, split the way the reader will read it.
    struct VolumeSummary: Equatable, Identifiable, Sendable {
        /// The volume the update rewrote.
        let volumeId: String
        /// Every document the update changed, annotated or not — the denominator.
        let changedDocuments: Int
        /// Changed documents carrying at least one of the reader's annotations.
        let annotatedDocuments: Int
        /// Of the annotated ones: the text changed, so highlight positions may have moved.
        let body: Int
        /// Of the annotated ones: footnotes, source note, or heading changed; the text did not.
        let apparatus: Int
        /// Of the annotated ones: no longer in the volume.
        let vanished: Int

        var id: String { volumeId }
    }

    /// Per-volume summaries for every volume with an unreviewed, stamped change.
    ///
    /// Ordered so the volumes that touch the reader's research come first: annotated documents
    /// descending, then changed documents descending, then volume id — a total order, so the
    /// list is stable across reloads. A volume whose changes touch nothing the reader annotated
    /// is still listed (with `annotatedDocuments == 0`); the caller decides whether to show it.
    /// Rows without a stamp (the first index of a volume) and reviewed rows are not changes.
    static func summaries(revisions: [IndexingPipeline.DocumentRevision],
                          annotatedKeys: Set<String>) -> [VolumeSummary] {
        struct Tally { var changed = 0, annotated = 0, body = 0, apparatus = 0, vanished = 0 }
        var byVolume: [String: Tally] = [:]
        for r in revisions where r.changedAt != nil && r.reviewedAt == nil {
            var t = byVolume[r.volumeId, default: Tally()]
            t.changed += 1
            if annotatedKeys.contains("\(r.volumeId)/\(r.documentId)") {
                t.annotated += 1
                switch r.changeKind {
                case "body":      t.body += 1
                case "apparatus": t.apparatus += 1
                case "vanished":  t.vanished += 1
                default: break
                }
            }
            byVolume[r.volumeId] = t
        }
        return byVolume
            .map { VolumeSummary(volumeId: $0.key, changedDocuments: $0.value.changed,
                                 annotatedDocuments: $0.value.annotated, body: $0.value.body,
                                 apparatus: $0.value.apparatus, vanished: $0.value.vanished) }
            .sorted {
                if $0.annotatedDocuments != $1.annotatedDocuments { return $0.annotatedDocuments > $1.annotatedDocuments }
                if $0.changedDocuments != $1.changedDocuments { return $0.changedDocuments > $1.changedDocuments }
                return $0.volumeId < $1.volumeId
            }
    }

    /// The whole picture in three numbers: changed documents, volumes, annotated documents.
    struct Totals: Equatable, Sendable {
        let changedDocuments: Int
        let volumes: Int
        let annotatedDocuments: Int
    }

    /// Sums over `summaries` — the sentence the status row states.
    static func totals(of summaries: [VolumeSummary]) -> Totals {
        Totals(changedDocuments: summaries.reduce(0) { $0 + $1.changedDocuments },
               volumes: summaries.count,
               annotatedDocuments: summaries.reduce(0) { $0 + $1.annotatedDocuments })
    }
}
