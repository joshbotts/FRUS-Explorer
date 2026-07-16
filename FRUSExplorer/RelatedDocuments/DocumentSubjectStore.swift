// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentSubjectCategoryGroup

/// One category group of a document's detected subjects — the second-level grouping the Phase 3
/// on-document subject hierarchy renders.
struct DocumentSubjectCategoryGroup: Sendable, Identifiable {
    /// The category label (e.g. `"Warfare"`).
    let category: String
    /// The subjects in this category, in the index's order.
    let subjects: [VolumeSubjectProfiles.ResolvedSubject]

    var id: String { category }

    /// Creates a category group.
    init(category: String, subjects: [VolumeSubjectProfiles.ResolvedSubject]) {
        self.category = category
        self.subjects = subjects
    }
}

// MARK: - DocumentSubjectIndex

/// A **document-grain** subject lookup: the detected topics for one document.
///
/// The shape of the Phase 3 bundled `document-subject-index.json` consumer (design §5.2). It reuses
/// the volume profiles' `ResolvedSubject` value type so the on-document display and the volume
/// display speak the same shape.
///
/// Phases 1–2 ship this type but never instantiate it — the document-grain data is gated on #261
/// (see `DocumentSubjectStore`), so both queries are the empty Phase-3 stubs. When the index is
/// bundled, this becomes the decoded lookup and its consumers light up with no call-site change.
///
/// Version history:
///   1.0 — #308 Phase 2: seam type, filled by the Phase 3 data drop
struct DocumentSubjectIndex: Sendable {

    /// The detected subjects for a document, ranked; `[]` when the document has none (or, in
    /// Phases 1–2, always — the index is never bundled yet).
    func subjects(forDocument key: DocumentKey) -> [VolumeSubjectProfiles.ResolvedSubject] { [] }

    /// The detected subjects for a document grouped by category; `[]` when the document has none.
    func hierarchy(forDocument key: DocumentKey) -> [DocumentSubjectCategoryGroup] { [] }
}

// MARK: - DocumentSubjectStore

/// The document-grain subject seam (design §5.2): the single access point every document-level
/// subject consumer reads — the on-document subject hierarchy, the subject drill-down, and the
/// find-related shared-subjects axis.
///
/// **`shared` is `nil` in Phases 1–2** — the document-grain `document-subject-index.json` is not
/// bundled, because the upstream document↔subject mappings are ~97% raw string-match and gated on
/// the #261 regeneration (owner decision pending). Every consumer degrades to "no subjects yet"
/// (a visibility-gated section that simply does not appear, and an inert similarity scorer), never
/// crashes and never inverts. Phase 3 flips `shared` to the lazily-decoded bundle — nil-tolerant and
/// loaded on first access, not at `AppState` init, mirroring `VolumeSubjectProfilesStore`.
///
/// Version history:
///   1.0 — #308 Phase 2: the seam, deliberately empty
enum DocumentSubjectStore {

    /// The document-grain subject index, or `nil` when it isn't bundled — which is always the case in
    /// Phases 1–2. This nil-ness is the seam: it gates the on-document subject disclosure off and
    /// keeps the shared-subjects similarity axis inert until the Phase 3 data drop.
    static let shared: DocumentSubjectIndex? = nil
}
