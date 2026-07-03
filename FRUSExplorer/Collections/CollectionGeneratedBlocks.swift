// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionGeneratedBlockType

/// The vocabulary of generated apparatus blocks (Authoring Phase 6, decision A11):
/// placeable `CollectionEntryKind.generated` entries whose content is computed from the
/// collection's resolved document set at resolve time — never authored, never stored.
///
/// The raw value is the persisted `CollectionEntry.generatedBlockType` string AND the
/// `.fruscollection` `generatedBlockType` key, so it must never be renamed. An unknown
/// raw value (written by a newer app version, via CloudKit sync or a shared file) reads
/// as `nil` here; the entry stays inert (see `CollectionEntry.generatedBlockType`) and
/// the resolver skips it — degraded, never corrupted.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): the five block types, display metadata, and the
///          default-position hint driving the Apparatus menu's live insertion point
enum CollectionGeneratedBlockType: String, CaseIterable, Identifiable, Sendable {
    /// Deduplicated, sorted citations of every document in the collection.
    case bibliography
    /// The collection's documents in date order (the `document_dates` data).
    case chronology
    /// The archival collections the documents draw on, with NARA links where resolved.
    case archivalSources
    /// Persons mentioned across the collection's documents, rolled up by identity.
    case personsIndex
    /// The researcher's tags mapped to the documents that carry them.
    case thematicIndex

    var id: String { rawValue }

    /// Where the Apparatus menu inserts a new block by default. The entry remains fully
    /// movable afterwards — this is an insertion hint, not a constraint.
    enum DefaultPosition: Sendable {
        /// Inserted before the first entry (e.g. a chronology that opens the reader).
        case frontMatter
        /// Appended after the last entry (classic back-matter apparatus).
        case backMatter
    }

    /// The localized block title — used by the editors' rows and menus AND as the
    /// resolved block's rendered section title, so the artifact and the editor agree.
    var displayName: String {
        switch self {
        case .bibliography:
            return String(localized: "collection.generated.bibliography",
                          defaultValue: "Bibliography")
        case .chronology:
            return String(localized: "collection.generated.chronology",
                          defaultValue: "Chronology")
        case .archivalSources:
            return String(localized: "collection.generated.archivalSources",
                          defaultValue: "Sources & Archives")
        case .personsIndex:
            return String(localized: "collection.generated.personsIndex",
                          defaultValue: "Persons Index")
        case .thematicIndex:
            return String(localized: "collection.generated.thematicIndex",
                          defaultValue: "Thematic Index")
        }
    }

    /// SF Symbol for the editors' rows and the Apparatus menu.
    var systemImage: String {
        switch self {
        case .bibliography:    return "books.vertical"
        case .chronology:      return "calendar"
        case .archivalSources: return "archivebox"
        case .personsIndex:    return "person.2"
        case .thematicIndex:   return "tag"
        }
    }

    /// The default insertion position: a chronology reads naturally as front matter;
    /// every other apparatus block is classic back matter.
    var defaultPosition: DefaultPosition {
        switch self {
        case .chronology: return .frontMatter
        case .bibliography, .archivalSources, .personsIndex, .thematicIndex:
            return .backMatter
        }
    }
}

// MARK: - CollectionGeneratedBlocks

/// The block-resolution seam (Authoring Phase 6): turns a generated entry's block type
/// plus the collection's resolved document membership into the pre-resolved
/// `CollectionGeneratedBlock` payload exporters render. Called only by
/// `CollectionContentResolver` — the single resolve pipeline — so `.preview` and
/// `.export` produce identical blocks by construction (block resolution is read-only:
/// it never downloads volumes and never generates content).
///
/// ## Stage plan
/// This core PR ships the seam with a **placeholder resolution** for every block type
/// (title + a single explanatory row), proving the entry → item → renderer pipe end to
/// end. Stage 3 (PRs 6a–6c) replaces the placeholder per type with the real resolvers
/// (citations dedupe, `document_dates` chronology, `volume_sources`/NAID lookups, the
/// person-rollup path, tag assignments), switching inside `resolve(type:documents:)`
/// — one arm per type, no renderer or serialization changes required.
///
/// Rows are **never serialized** (not into `.fruscollection` files, not into SwiftData):
/// only the block TYPE persists, and every device re-resolves rows against its own data.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): the seam + placeholder resolution for all types
enum CollectionGeneratedBlocks {

    /// Resolves one generated block from the collection's resolved document membership.
    ///
    /// - Parameters:
    ///   - type: The block type to resolve.
    ///   - documents: The collection's resolved document membership — `(volumeId,
    ///     documentId)` in collection order, deduplicated (the same universe the A10
    ///     related-documents line uses; for smart collections it is the resolved search
    ///     result set, so blocks work there identically).
    /// - Returns: The pre-resolved block payload (today: the placeholder rows).
    static func resolve(
        type: CollectionGeneratedBlockType,
        documents: [(volumeId: String, documentId: String)]
    ) -> CollectionGeneratedBlock {
        // Placeholder resolution (this PR): every type renders its title plus one
        // explanatory row, so placement, ToCs, and all three renderers are testable
        // before the real per-type resolvers land (stage 3).
        CollectionGeneratedBlock(
            type: type,
            title: type.displayName,
            rows: [CollectionGeneratedRow(text: placeholderRowText(for: type))]
        )
    }

    /// The placeholder row's text: names the block and states that its rows resolve
    /// from the collection's documents in an upcoming update.
    private static func placeholderRowText(for type: CollectionGeneratedBlockType) -> String {
        String(localized: "collection.generated.placeholderRow",
               defaultValue: "This \(type.displayName) is generated from the collection’s documents. Block content arrives in an upcoming FRUS Explorer update.")
    }
}
