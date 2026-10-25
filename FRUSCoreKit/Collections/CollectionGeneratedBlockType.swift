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
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public and otherwise unchanged,
///          from `CollectionGeneratedBlocks.swift`, with the export payloads that name it; the blocks'
///          resolution stays in the app
public enum CollectionGeneratedBlockType: String, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    /// Where the Apparatus menu inserts a new block by default. The entry remains fully
    /// movable afterwards — this is an insertion hint, not a constraint.
    public enum DefaultPosition: Sendable {
        /// Inserted before the first entry (e.g. a chronology that opens the reader).
        case frontMatter
        /// Appended after the last entry (classic back-matter apparatus).
        case backMatter
    }

    /// The localized block title — used by the editors' rows and menus AND as the
    /// resolved block's rendered section title, so the artifact and the editor agree.
    public var displayName: String {
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
    public var systemImage: String {
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
    public var defaultPosition: DefaultPosition {
        switch self {
        case .chronology: return .frontMatter
        case .bibliography, .archivalSources, .personsIndex, .thematicIndex:
            return .backMatter
        }
    }
}
