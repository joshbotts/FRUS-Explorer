// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionEntryKind

/// What a `CollectionEntry` contributes to the composed collection (Phase 3a).
///
/// A collection is an ordered sequence of these: `document` entries are the FRUS documents;
/// `heading` entries start a section; `prose` entries are the researcher's own editorial note
/// blocks; `excerpt` entries are frozen verbatim quotations from a document (Authoring
/// Phase 5). This turns a flat document list into an authored, sectioned reader.
///
/// Version history:
///   1.0 — Collections Phase 3a: initial implementation; `excerpt`, `generated` and `unrecognized`
///          joined it in the Authoring phases
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit from the app's
///          `Models/Collection.swift`, unchanged but `public`, for the rules of the Research page and the
///          method appendix's coverage that read an entry's kind
public enum CollectionEntryKind: String, CaseIterable, Sendable {
    /// A FRUS document (uses `documentId`/`volumeId`).
    case document
    /// A section heading (uses `text` as the title).
    case heading
    /// An editorial prose block (uses `text` as the body).
    case prose
    /// A frozen verbatim quotation from a document (Authoring Phase 5): `text` is the
    /// passage, `documentId`/`volumeId` its provenance for the auto-citation source line,
    /// and the `excerpt*` fields carry the anchoring metadata copied at creation. On
    /// pre-Phase-5 builds this raw value rides the `.unrecognized` sync guard: the entry
    /// is inert and skipped, never misread as a junk document.
    case excerpt
    /// A placeable generated apparatus block (Authoring Phase 6, decision A11): the
    /// entry stores only `generatedBlockType` — the block's rows are computed from the
    /// collection's resolved document set at every resolve, never persisted. Uses no
    /// other content fields. On pre-Phase-6 builds this raw value rides the
    /// `.unrecognized` sync guard: the entry is inert and skipped.
    case generated
    /// A `kind` raw value written by a newer app version that this build does not
    /// understand (synced via CloudKit). Never persisted by this build; surfaced as an
    /// inert row and skipped by resolve/export so future entry kinds degrade gracefully
    /// instead of being misread as junk document entries (Authoring Phase 1 sync guard).
    case unrecognized

    /// Excludes `.unrecognized`: it is a decode fallback, not an authorable kind, so any
    /// menu or picker iterating the cases never offers it.
    public static var allCases: [CollectionEntryKind] { [.document, .heading, .prose, .excerpt, .generated] }
}
