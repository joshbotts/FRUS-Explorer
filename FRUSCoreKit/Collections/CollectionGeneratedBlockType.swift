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
///   1.2 — L58: `noteOnTheText`, the Note on the Text (the Collections design's §3.6), the first block that is not a
///          list of the collection's documents: the assembly writes it from the resolved entries
///          (`CollectionNoteOnTheText`), outside the block seam (the third review's J18), and it prints nothing when it
///          has nothing to say. `listsMembership` tells it from the five lists. A build before L58 keeps it as an inert
///          block, in its place, and prints nothing for it
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
    /// The Note on the Text (L58; the design's §3.6): the collection's statement of method, written from what its
    /// documents print — the compiler's titles and date lines, what is left out, who wrote the summaries and
    /// headnotes, the quoted passages and the labels reworded. Not a list of the documents: see `listsMembership`.
    case noteOnTheText

    public var id: String { rawValue }

    /// Whether the block is a list the block seam resolves from the collection's documents alone
    /// (`CollectionGeneratedBlocks.resolve`), printing *Nothing to list* when it finds nothing: every block but the
    /// Note on the Text, which needs every entry's resolved title, depth and switches and prints nothing when it has
    /// nothing to say (the third review's J18), so the assembly writes it from the resolved entries.
    public var listsMembership: Bool {
        self != .noteOnTheText
    }

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
        case .noteOnTheText:
            return String(localized: "collection.generated.noteOnTheText",
                          defaultValue: "Note on the Text")
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
        case .noteOnTheText:   return "text.book.closed"
        }
    }

    /// The default insertion position: a chronology reads naturally as front matter;
    /// every other apparatus block is classic back matter, the Note on the Text last of all, as it is added after
    /// every row the collection has (the design's §4.3).
    public var defaultPosition: DefaultPosition {
        switch self {
        case .chronology: return .frontMatter
        case .bibliography, .archivalSources, .personsIndex, .thematicIndex, .noteOnTheText:
            return .backMatter
        }
    }
}
