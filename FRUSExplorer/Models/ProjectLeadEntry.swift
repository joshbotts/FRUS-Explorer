// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ProjectLeadEntry

/// A **Project Lead** (#377 Phase 3): a document the project has *not* engaged that is
/// related to the documents it has — surfaced by aggregating the multi-axis related-document
/// engine (#308) across the project's seed (its collection documents).
///
/// One entry per (project, document). `aggregateScore` sums the document's relatedness across
/// every seed it relates to, so a document related to *many* of the project's documents rises;
/// `contributingSeedKeys` records which seeds surfaced it (for a "related to N of your
/// documents" affordance). `firstSurfacedAt` drives the "new since you last looked" feed;
/// `dismissed` keeps a rejected lead from resurfacing.
///
/// A **new** CloudKit record type — additive, no migration of existing records — but the
/// CloudKit schema must be deployed to Production before a synced build ships (see
/// `ModelContainer+FRUS`'s schema note).
///
/// Version history:
///   1.0 — #377 Phase 3: initial implementation
@Model final class ProjectLeadEntry {

    /// Stable identity.
    var id: UUID = UUID()

    /// The project this lead belongs to.
    var projectId: UUID = UUID()

    /// The lead document's volume id.
    var volumeId: String = ""

    /// The lead document's volume-local document id.
    var documentId: String = ""

    /// Summed relatedness across the seed documents this lead relates to. Higher = more, or
    /// more strongly, related to the project's documents.
    var aggregateScore: Double = 0

    /// The `"volumeId/documentId"` seed documents that surfaced this lead.
    var contributingSeedKeys: [String] = []

    /// The lead document's header (title), captured at compute time so the leads list renders
    /// without a re-fetch. May be empty; the row falls back to the document key.
    var header: String = ""

    /// The lead document's number within its volume, if known.
    var documentNumber: String?

    /// Whether the lead is an editorial note rather than a primary document.
    var isEditorialNote: Bool = false

    /// When this lead first appeared — the anchor for the "new since you last looked" feed.
    var firstSurfacedAt: Date = Date.now

    /// The most recent recompute that re-confirmed this lead as a current candidate.
    var lastComputedAt: Date = Date.now

    /// Whether the researcher dismissed this lead (kept so it doesn't resurface).
    var dismissed: Bool = false

    /// Creates a lead entry.
    init(projectId: UUID,
         volumeId: String,
         documentId: String,
         aggregateScore: Double,
         contributingSeedKeys: [String],
         header: String = "",
         documentNumber: String? = nil,
         isEditorialNote: Bool = false,
         firstSurfacedAt: Date = .now,
         lastComputedAt: Date = .now,
         dismissed: Bool = false) {
        self.id = UUID()
        self.projectId = projectId
        self.volumeId = volumeId
        self.documentId = documentId
        self.aggregateScore = aggregateScore
        self.contributingSeedKeys = contributingSeedKeys
        self.header = header
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
        self.firstSurfacedAt = firstSurfacedAt
        self.lastComputedAt = lastComputedAt
        self.dismissed = dismissed
    }

    /// The `"volumeId/documentId"` key of the lead document.
    var documentKey: String { "\(volumeId)/\(documentId)" }
}
