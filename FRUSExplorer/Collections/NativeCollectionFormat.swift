// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - UTType.fruscollection

extension UTType {
    /// The exported `.fruscollection` document type, matching the
    /// `UTExportedTypeDeclarations` entry in both platforms' Info.plists (Phase 4, D6/D9
    /// OS file-association work). Used by the in-app import `fileImporter`s so the open
    /// panel only offers native collection files rather than any `.data` file
    /// (Authoring Phase 1 housekeeping).
    static var fruscollection: UTType {
        UTType(exportedAs: "bottsywattsy.FRUS-Explorer.fruscollection")
    }
}

// MARK: - FRUSCollectionFile

/// The portable, round-trippable representation of a `Collection` — the on-disk shape of a
/// native `.fruscollection` file (Collections rework Phase 4, D9).
///
/// Unlike the PDF/HTML/DOCX/RIS/BibTeX exporters, which render a *product*, this format
/// serializes the collection's **source**: its composition settings, ordered structural
/// entries (documents / headings / prose), and — opt-in — the researcher's inline notes.
/// Documents are carried as portable `volumeId` + `documentId` references (universal FRUS
/// identifiers), so a collection authored on one device reconstructs on another once the
/// referenced volumes are downloaded; nothing device-local (SwiftData ids, timestamps,
/// `projectIds`) is serialized.
///
/// It is a plain `Codable` struct, decoupled from the SwiftData `@Model` types, so the file
/// schema can evolve independently of the persistence layer. Prose rich text (`Entry.richText`)
/// is RTF `Data`, which `JSONEncoder` emits as base64.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D9): initial implementation
///   1.1 — Authoring Phase 1: `UTType.fruscollection` added; serializer omits
///          `.unrecognized` entries; importer skips unknown entry kinds instead of
///          misdecoding them as documents (mixed-version guard)
///   2.0 — Authoring Phase 4 (the program's one format bump): `minimumReaderVersion`
///          (defaulted 1 on decode when absent), front-matter block (`subtitle`,
///          `authorLine`, `introductionText`/`introductionRichText`, `includeColophon`),
///          and `Entry.level` — all optional keys, absent from write-minimum v1 files
///   2.1 — Authoring Phase 5 (rides formatVersion 2 under the tolerant reader — no new
///          bump, `minimumReaderVersion` stays 1): `Composition.includeFootnotes` +
///          `Composition.includeSourceNote` (the Bool pair; the legacy `footnoteStyle`
///          keeps being written) and `Entry.includeHeadnote` + `Entry.headnoteSummaryId`
///          — all optional keys, absent from write-minimum files
///   2.2 — Authoring Phase 5 (excerpts; still formatVersion 2, floor stays 1): the
///          `"excerpt"` entry kind — `text` (the frozen passage) + `documentId`/`volumeId`
///          (provenance) + optional `excerptStart`/`excerptEnd`/`excerptRenderingVersion`/
///          `excerptColorTag` anchors. **Content + colour + provenance + anchors only —
///          never device-local highlight UUIDs.** A pre-excerpt reader skips the unknown
///          kind (degraded, not corrupted); any excerpt forces the file to v2, so v1
///          readers never see one
///   2.3 — Authoring Phase 5 (overrides; still formatVersion 2, floor stays 1): the
///          per-entry override keys `applyHighlightsOverride`/`includeNotesOverride`/
///          `includeSourceNoteOverride`/`includeFootnotesOverride`/
///          `summaryPromptIdOverride`/`includeRelatedDocuments` on document AND heading
///          entries (heading = section defaults). A reader ignoring them degrades to
///          collection-level composition — never corrupts, so the floor stays 1.
///          `selectedHighlightIds` is **deliberately NOT serialized**: those are
///          device-local `DocumentHighlight` UUIDs, and the referenced highlights don't
///          travel in the file — a recipient's export falls back to
///          all-their-highlights semantics (the field's documented empty-set meaning)
///   2.4 — Authoring Phase 6 (generated apparatus; still formatVersion 2, floor stays
///          1): the `"generated"` entry kind + its `generatedBlockType` key. **Only the
///          block TYPE serializes — never resolved rows**: blocks re-resolve against
///          the recipient's own data on import. Any generated entry forces the file to
///          v2 (`usesV2Features`), so v1-only readers never see the kind; a v2-aware
///          reader that doesn't know a future `generatedBlockType` STRING imports the
///          entry as an inert generated block (placement preserved, skipped at
///          resolve/render, re-exported intact) — degraded, never corrupted
///   2.5 — Collections Manager M3 (still formatVersion 2, floor stays 1): `Entry.titleOverride`
///          on document entries — a per-document plain-text override of the ToC label +
///          export heading (D4). **Portable content** (no device-local UUIDs), so unlike
///          `selectedHighlightIds`/`selectedNoteIds` it DOES travel; write-minimum omits
///          the key when empty (byte-identical to pre-M3), a non-empty value forces v2
///          (`usesV2Features`), and a reader ignoring it degrades to the derived title —
///          floor stays 1
struct FRUSCollectionFile: Codable, Sendable, Equatable {

    /// Format discriminator; always `NativeCollectionSerializer.formatIdentifier`. Checked on
    /// decode so an unrelated JSON file is rejected rather than silently imported as empty.
    var format: String
    /// Monotonic schema version — what the *writer* understood. Readers gate on
    /// `minimumReaderVersion` (falling back to this when absent), so a v2-aware reader
    /// accepts any newer file whose features are merely degradable (tolerant-reader rule).
    var formatVersion: Int
    /// The oldest reader version that can open this file without corrupting meaning.
    /// Carried by v2+ files; `nil` (v1 files) defaults to 1 on decode. Writers raise it
    /// only when *ignoring* a field would corrupt meaning, never for degradable features
    /// (ignored `level` → flat headings and ignored front matter are degraded, not raised).
    var minimumReaderVersion: Int?
    /// The collection title.
    var name: String
    /// The optional collection-level note/description (the one-line title-page description).
    var note: String?
    /// Optional title-page subtitle (v2 front matter; absent in write-minimum files).
    var subtitle: String?
    /// Optional title-page author/byline (v2 front matter; absent in write-minimum files).
    var authorLine: String?
    /// Optional introduction, plain-text projection (v2 front matter).
    var introductionText: String?
    /// Optional introduction rich text, RTF `Data` (base64 in JSON; v2 front matter).
    var introductionRichText: Data?
    /// Whether exports append a colophon. Emitted only when `true`; `nil` means `false`.
    var includeColophon: Bool?
    /// Whether exports stamp the active project's provenance on the title page (#377 Phase 4).
    /// Emitted only when `true`; `nil` means `false`.
    var includeProjectProvenance: Bool?
    /// The persisted composition settings (what an export of this collection contains).
    var composition: Composition
    /// The ordered structural entries. Array order *is* the collection order.
    var entries: [Entry]

    // MARK: - Composition

    /// The persisted export-content settings carried with the collection (mirrors the
    /// `Collection` composition fields). Enum-backed values are raw strings, matching the model.
    /// Device-local `summaryPromptId` is intentionally omitted — a `.summaryOnly` collection
    /// regenerates summaries with the recipient's own prompt.
    struct Composition: Codable, Sendable, Equatable {
        /// `CollectionBodyDepth` raw value (`"full"` / `"summaryOnly"` / `"index"`).
        var defaultBodyDepth: String
        /// `CollectionFootnoteStyle` raw value (`"none"` / `"sourceNoteOnly"` / `"all"`).
        /// Legacy tri-state, always written — v1 readers and untouched collections keep
        /// composing from it; the Phase 5 Bool pair below supersedes it when present.
        var footnoteStyle: String
        /// Phase 5 footnote pair: whether footnotes render (v2 optional key; `nil` in
        /// write-minimum files and files from pre-Phase-5 writers = derive from
        /// `footnoteStyle`).
        var includeFootnotes: Bool?
        /// Phase 5 footnote pair: whether the archival source note renders (v2 optional
        /// key; `nil` = derive from `footnoteStyle`).
        var includeSourceNote: Bool?
        /// `CollectionToCStyle` raw value (`"citation"` / `"headerAndDateline"`).
        var tocStyle: String
        /// Whether user highlights annotate exported bodies.
        var applyHighlights: Bool
        /// Whether attached research notes appear in exports.
        var includeNotes: Bool
        /// Whether a word-cloud overview is prepended to PDF/HTML exports.
        var includeWordCloud: Bool
        /// The collection-level headnote default (Composer redesign; v2 optional key). `nil` (its
        /// default `false`) is omitted so collections without a headnote default stay byte-identical.
        var defaultIncludeHeadnote: Bool?
    }

    // MARK: - Entry

    /// One structural entry. `kind` selects which fields apply: `document` uses
    /// `documentId`/`volumeId` (+ optional `bodyDepthOverride` and inline `notes`);
    /// `heading` uses `text` (+ optional `bodyDepthOverride` as the section depth);
    /// `prose` uses `text` and optional `richText` (RTF); `excerpt` uses `text` (the
    /// frozen passage) + `documentId`/`volumeId` (provenance) + the `excerpt*` anchors;
    /// `generated` uses only `generatedBlockType`.
    struct Entry: Codable, Sendable, Equatable {
        /// `CollectionEntryKind` raw value (`"document"` / `"heading"` / `"prose"` /
        /// `"excerpt"` / `"generated"`).
        var kind: String
        /// FRUS document id (document entries only).
        var documentId: String?
        /// FRUS volume id (document entries only).
        var volumeId: String?
        /// `CollectionBodyDepth` raw value overriding the collection default — per-document
        /// (document entries) or per-section (heading entries). `nil` = use the default.
        var bodyDepthOverride: String?
        /// Per-document title override (M3, D4; document entries only; v2 optional key).
        /// Plain text replacing the derived ToC label + export heading. **This is portable
        /// content** — unlike `selectedHighlightIds`/`selectedNoteIds` it carries no
        /// device-local UUIDs, so it travels with the file. Emitted only when non-empty; a
        /// non-empty value makes the file `formatVersion 2` (`usesV2Features`). A v1 reader
        /// ignoring the key degrades to the derived title (no `minimumReaderVersion` bump).
        var titleOverride: String?
        /// Heading nesting level (heading entries only; v2). `nil` = 1. Written as the
        /// outline-resolved level, so files never carry orphan jumps; readers clamp
        /// defensively anyway. Absent from write-minimum files (all headings level 1).
        var level: Int?
        /// Section title (heading) or plain-text body (prose).
        var text: String?
        /// RTF rich-text prose body (prose entries only); base64 in JSON.
        var richText: Data?
        /// Whether this document entry renders a headnote (Phase 5; v2 optional key).
        /// Emitted only when `true`; `nil`/absent = `false`.
        var includeHeadnote: Bool?
        /// The chosen `GeneratedSummary.id` for the headnote (Phase 5; v2 optional key).
        /// Summary ids are meaningful across the author's own CloudKit-synced devices;
        /// on another user's device the id simply won't resolve and the resolver falls
        /// back to any stored summary (or the placeholder).
        var headnoteSummaryId: UUID?
        /// Excerpt anchor: unicode-scalar start offset in the source document's flat
        /// text (excerpt entries only; v2 optional key). Anchors travel so precision
        /// rendering (A9) stays possible on the recipient's device; the frozen `text`
        /// remains the rendering source of truth. **Never a highlight UUID.**
        var excerptStart: Int?
        /// Excerpt anchor: unicode-scalar end offset (exclusive) — see `excerptStart`.
        var excerptEnd: Int?
        /// Excerpt anchor: the source document's `renderingVersion` at excerpt creation
        /// (excerpt entries only; v2 optional key).
        var excerptRenderingVersion: String?
        /// The source highlight's colour raw value (`"yellow"`/`"green"`/`"blue"`/
        /// `"pink"`; excerpt entries only; v2 optional key) — the quote's accent colour.
        var excerptColorTag: String?
        /// Per-entry highlight override (Phase 5 overrides; v2 optional key; document
        /// and heading entries — a heading's is its section default). `nil` = inherit.
        var applyHighlightsOverride: Bool?
        /// Per-entry research-notes override (Phase 5 overrides; v2 optional key).
        var includeNotesOverride: Bool?
        /// Per-entry source-note override (Phase 5 overrides; v2 optional key).
        var includeSourceNoteOverride: Bool?
        /// Per-entry footnote override (Phase 5 overrides; v2 optional key).
        var includeFootnotesOverride: Bool?
        /// Per-entry summary-prompt override (Phase 5 overrides; v2 optional key).
        /// Like `headnoteSummaryId`, prompt ids are meaningful across the author's own
        /// CloudKit-synced devices; on another user's device the id simply won't
        /// resolve and the collection-level prompt behavior applies.
        var summaryPromptIdOverride: UUID?
        /// Per-entry related-documents opt-in (A10; v2 optional key). `nil` = inherit
        /// (ultimately off). NOTE: `selectedHighlightIds` has **no** key here by design
        /// — device-local highlight UUIDs never serialize (see the 2.3 version note).
        var includeRelatedDocuments: Bool?
        /// The apparatus block type raw value (generated entries only; v2 optional key,
        /// Phase 6). The block's rows are **never** serialized — they re-resolve from
        /// the recipient's data. An unknown raw value imports as an inert generated
        /// entry (see the 2.4 version note).
        var generatedBlockType: String?
        /// Inline research-note texts for this document (opt-in — populated only when the
        /// exporter's "include my research notes" toggle is on). `nil`/absent otherwise.
        /// These are the *resolved* note texts the entry's `selectedNoteIds` filter chose
        /// (empty = all of the document's notes, D5); the device-local `selectedNoteIds`
        /// ids themselves are **never** serialized — like `selectedHighlightIds` they
        /// reference records the recipient lacks (see the 2.7 version note).
        var notes: [String]?
    }
}

// MARK: - NativeCollectionError

/// Errors surfaced when decoding or importing a `.fruscollection` file.
enum NativeCollectionError: Error, LocalizedError {
    /// The file is valid JSON but not a FRUS collection file (wrong `format`).
    case notACollectionFile
    /// The file's `formatVersion` is newer than this app understands.
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .notACollectionFile:
            return String(localized: "collection.import.error.notACollection",
                          defaultValue: "This file isn’t a FRUS Explorer collection.")
        case .unsupportedVersion(let version):
            return String(localized: "collection.import.error.version",
                          defaultValue: "This collection was made with a newer version of FRUS Explorer (format \(version)). Update the app to open it.")
        }
    }
}

// MARK: - NativeCollectionSerializer

/// Encodes a `Collection` to a `.fruscollection` file and reconstructs one on import.
///
/// The serializer is the sibling of the `CollectionExporter` family: those turn *resolved,
/// rendered* content into a shareable artifact, whereas this reads the `Collection` model
/// directly to serialize its *source* (references + composition + structure) with no content
/// resolution and no downloaded volume required at export.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D9): initial implementation
///   1.1 — Session 2026-07-02 data-loss fix: `makeFile` heals a legacy Phase 3b JSON
///          `richText` blob to RTF before emitting a prose entry, so shared files honour
///          the schema's "richText is RTF" promise instead of propagating the old encoding
///   1.2 — Authoring Phase 4 (format v2): `currentVersion` = 2; decode gates on
///          `minimumReaderVersion ?? formatVersion` (tolerant-reader rule); `makeFile`
///          computes `usesV2Features` from content and **writes minimum** — a collection
///          using no v2 feature emits a byte-identical v1 file so already-fielded readers
///          keep opening it; v2 files carry `minimumReaderVersion: 1` (levels and front
///          matter are degradable, never meaning-corrupting); `apply` reconstructs the
///          front-matter fields and clamped heading levels
///   1.3 — Authoring Phase 5: the footnote Bool pair and headnote keys ride v2 as
///          optional keys (no bump; `minimumReaderVersion` stays 1 — a reader ignoring
///          them degrades to the legacy footnoteStyle / no headnote, never corrupts);
///          `usesV2Features` extended so untouched collections keep emitting v1 files
///   1.4 — Authoring Phase 5 (excerpts): `.excerpt` entries serialize as kind
///          `"excerpt"` with passage + provenance + anchors (never highlight UUIDs);
///          any excerpt forces v2 (`usesV2Features`), and a reader that doesn't know
///          the kind skips it under the Phase 1 skip-with-warning rule; `apply`
///          reconstructs excerpt entries with their anchors
///   1.5 — Authoring Phase 5 (overrides): the six per-entry override keys ride v2 on
///          document and heading entries (no bump, floor stays 1 — ignored overrides
///          degrade to collection composition); `usesV2Features` extended so untouched
///          collections keep emitting byte-identical v1 files; `apply` reconstructs
///          them. `selectedHighlightIds` is intentionally omitted from files — the
///          device-local highlights it references don't travel, so a recipient's
///          export uses all-their-highlights semantics
///   1.6 — Authoring Phase 6 (generated apparatus): `.generated` entries serialize as
///          kind `"generated"` with `generatedBlockType` only — resolved rows never
///          serialize (they re-resolve on the recipient's data). Any generated entry
///          forces v2 (`usesV2Features`); `apply` reconstructs the entry, importing an
///          unknown block-type STRING as an inert generated entry (placement preserved,
///          skipped at resolve — the CloudKit path delivers the same string to old
///          builds anyway, so inert-entry is the one coherent decision; only an unknown
///          entry KIND is skipped on import, per the Phase 1 rule)
///   1.7 — Collections Manager M2 (D5, notes default = all): no schema/format change.
///          `selectedNoteIds` now means empty = all of the document's notes (mirroring
///          `selectedHighlightIds`), so the exporter resolves *which* note texts travel
///          in the existing `notes: [String]?` field; the ids themselves stay device-local
///          and are still **never** serialized. Import unchanged — recreated notes are
///          pinned via `selectedNoteIds`, and an entry with no `notes` keeps the empty
///          set (= all of the recipient's notes when notes apply)
///   1.8 — Collections Manager M3 (D4, per-entry title override): `Entry.titleOverride`
///          rides v2 as an optional key on document entries (no bump, floor stays 1 — a
///          reader ignoring it degrades to the derived title). **Unlike the id-set
///          overrides it IS serialized** — it is portable plain text, so it travels with
///          the file. Write-minimum omits an empty override (byte-identical to pre-M3);
///          `usesV2Features` extended so a non-empty override forces v2; `apply`
///          reconstructs it in the `.document` branch
enum NativeCollectionSerializer {

    /// The `FRUSCollectionFile.format` discriminator.
    static let formatIdentifier = "fruscollection"
    /// The newest schema version this build understands. `makeFile` emits the *minimum*
    /// version the content needs (v1 when no v2 feature is used), never this constant
    /// unconditionally.
    static let currentVersion = 2
    /// The file extension for exported collection files.
    static let fileExtension = "fruscollection"

    // MARK: - Encode / Decode

    /// Encodes a file DTO to pretty-printed, key-sorted JSON `Data` (stable and diff-friendly).
    static func encode(_ file: FRUSCollectionFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// Decodes and validates a `.fruscollection` file under the tolerant-reader rule:
    /// the gate is `minimumReaderVersion` (defaulted 1 when absent, i.e. every v1 file),
    /// **not** `formatVersion` — a newer file whose features merely degrade here (e.g. a
    /// v3 writer that kept `minimumReaderVersion: 1`) still opens; unknown JSON keys are
    /// ignored by decoding and unknown entry kinds are skipped-with-warning by `apply`.
    ///
    /// - Throws: `NativeCollectionError.notACollectionFile` if `format` doesn't match, or
    ///   `.unsupportedVersion` if the file *requires* a newer reader than this build; a
    ///   `DecodingError` if the data isn't the expected JSON shape.
    static func decode(_ data: Data) throws -> FRUSCollectionFile {
        let file = try JSONDecoder().decode(FRUSCollectionFile.self, from: data)
        guard file.format == formatIdentifier else {
            throw NativeCollectionError.notACollectionFile
        }
        let requiredReader = file.minimumReaderVersion ?? file.formatVersion
        guard requiredReader <= currentVersion else {
            throw NativeCollectionError.unsupportedVersion(requiredReader)
        }
        return file
    }

    // MARK: - Build the DTO from a live Collection

    /// Builds the portable file DTO from a live `Collection`, **writing the minimum
    /// version the content needs**: when the collection uses no v2 feature (no front
    /// matter, no colophon, every heading at level 1), the DTO is `formatVersion: 1`
    /// with no v2 keys — byte-identical to a pre-Phase-4 file, so already-fielded
    /// readers keep opening it. Otherwise it is `formatVersion: 2` with
    /// `minimumReaderVersion: 1`, because every v2 feature is *degradable* on a v1
    /// reader (levels flatten, front matter is ignored) — never meaning-corrupting.
    ///
    /// Heading levels are emitted as `CollectionOutline`-resolved depths (single-
    /// linearizer discipline), so files never carry clamp violations or orphan jumps.
    ///
    /// - Parameters:
    ///   - collection: The collection to serialize. Its entries are emitted in `sortOrder`.
    ///   - includeNotes: When `true`, each document entry carries the inline note texts from
    ///     `resolveNoteTexts`; when `false` (the D9a default), notes are omitted entirely.
    ///   - resolveNoteTexts: Supplies the research-note bodies for a document entry (the caller
    ///     resolves `selectedNoteIds`/`researchNoteId` against its store). Only invoked when
    ///     `includeNotes` is `true`.
    static func makeFile(
        from collection: Collection,
        includeNotes: Bool,
        resolveNoteTexts: (CollectionEntry) -> [String]
    ) -> FRUSCollectionFile {
        let composition = FRUSCollectionFile.Composition(
            defaultBodyDepth: collection.defaultBodyDepth,
            footnoteStyle: collection.footnoteStyle,
            // Phase 5 pair: carried verbatim — a nil pair stays nil so untouched
            // collections keep emitting the byte-identical legacy composition block.
            includeFootnotes: collection.includeFootnotes,
            includeSourceNote: collection.includeSourceNote,
            tocStyle: collection.tocStyle,
            applyHighlights: collection.applyHighlights,
            includeNotes: collection.includeNotes,
            includeWordCloud: collection.includeWordCloud,
            // Only a set (true) headnote default serializes; false omits, keeping byte-compat.
            defaultIncludeHeadnote: collection.defaultIncludeHeadnote ? true : nil
        )

        let entries: [FRUSCollectionFile.Entry] = CollectionOutline
            .linearize(collection.documentEntries ?? [])
            .compactMap { item in
                let entry = item.entry
                switch entry.entryKind {
                case .document:
                    let notes = includeNotes
                        ? resolveNoteTexts(entry).filter { !$0.isEmpty }
                        : []
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.document.rawValue,
                        documentId: entry.documentId,
                        volumeId: entry.volumeId,
                        bodyDepthOverride: entry.bodyDepthOverride,
                        // M3 title override — portable plain text (document entries only).
                        // Write-minimum: an empty/nil override omits the key, keeping the
                        // file byte-identical to pre-M3.
                        titleOverride: entry.titleOverride.flatMap { $0.isEmpty ? nil : $0 },
                        text: nil,
                        richText: nil,
                        // Phase 5 headnote keys — Default (nil) and Off (false) both omit the key,
                        // so a headnote-free entry stays byte-identical; only an explicit On (true)
                        // serializes (Composer redesign widened the field to optional).
                        includeHeadnote: entry.includeHeadnote == true ? true : nil,
                        headnoteSummaryId: entry.headnoteSummaryId,
                        // Phase 5 override keys — nil (every untouched entry) emits
                        // nothing. selectedHighlightIds NEVER serializes (device-local
                        // highlight UUIDs; the highlights don't travel with the file).
                        applyHighlightsOverride: entry.applyHighlightsOverride,
                        includeNotesOverride: entry.includeNotesOverride,
                        includeSourceNoteOverride: entry.includeSourceNoteOverride,
                        includeFootnotesOverride: entry.includeFootnotesOverride,
                        summaryPromptIdOverride: entry.summaryPromptIdOverride,
                        includeRelatedDocuments: entry.includeRelatedDocuments,
                        notes: notes.isEmpty ? nil : notes
                    )
                case .heading:
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.heading.rawValue,
                        documentId: nil,
                        volumeId: nil,
                        bodyDepthOverride: entry.bodyDepthOverride,
                        // The outline-resolved level; the default (1) is omitted so a
                        // flat collection's entries carry no v2 key at all.
                        level: item.depth == 1 ? nil : item.depth,
                        text: entry.text,
                        richText: nil,
                        // Phase 5 override keys — a heading's are its section defaults.
                        applyHighlightsOverride: entry.applyHighlightsOverride,
                        includeNotesOverride: entry.includeNotesOverride,
                        includeSourceNoteOverride: entry.includeSourceNoteOverride,
                        includeFootnotesOverride: entry.includeFootnotesOverride,
                        summaryPromptIdOverride: entry.summaryPromptIdOverride,
                        includeRelatedDocuments: entry.includeRelatedDocuments,
                        notes: nil
                    )
                case .prose:
                    // The file schema promises RTF, but a pre-RTF (Phase 3b) entry still
                    // holds a JSON-encoded AttributedString — heal it before emitting so
                    // shared files never propagate the legacy encoding.
                    ProseRichText.migrateLegacyJSONIfNeeded(entry)
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.prose.rawValue,
                        documentId: nil,
                        volumeId: nil,
                        bodyDepthOverride: nil,
                        text: entry.text,
                        richText: entry.richText,
                        notes: nil
                    )
                case .excerpt:
                    // Passage + provenance + anchors — content only, NEVER the
                    // device-local highlight UUID the excerpt may have come from.
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.excerpt.rawValue,
                        documentId: entry.documentId.isEmpty ? nil : entry.documentId,
                        volumeId: entry.volumeId.isEmpty ? nil : entry.volumeId,
                        bodyDepthOverride: nil,
                        text: entry.text,
                        richText: nil,
                        excerptStart: entry.excerptStart,
                        excerptEnd: entry.excerptEnd,
                        excerptRenderingVersion: entry.excerptRenderingVersion,
                        excerptColorTag: entry.excerptColorTag,
                        notes: nil
                    )
                case .generated:
                    // Only the block TYPE travels (Phase 6): rows are resolve-time
                    // output, recomputed from the recipient's own data.
                    return FRUSCollectionFile.Entry(
                        kind: CollectionEntryKind.generated.rawValue,
                        documentId: nil,
                        volumeId: nil,
                        bodyDepthOverride: nil,
                        text: nil,
                        richText: nil,
                        generatedBlockType: entry.generatedBlockType,
                        notes: nil
                    )
                case .unrecognized:
                    // A kind written by a newer app version: this build cannot represent
                    // it faithfully, so it is omitted from the file rather than exported
                    // as a mislabeled entry (Authoring Phase 1 guard).
                    return nil
                }
            }

        // Empty strings count as "not set": the editor treats a cleared field and a
        // never-set field identically, and neither should force a v2 file.
        let subtitle = collection.subtitle.flatMap { $0.isEmpty ? nil : $0 }
        let authorLine = collection.authorLine.flatMap { $0.isEmpty ? nil : $0 }
        let introductionText = collection.introductionText.flatMap { $0.isEmpty ? nil : $0 }
        let introductionRichText = collection.introductionRichText
            .flatMap { $0.isEmpty ? nil : $0 }

        // Write-minimum: computed from content, never hardcoded. Any front-matter field
        // set, a colophon opt-in, any heading deeper than level 1, any member of the
        // Phase 5 footnote Bool pair, any headnote request/pick, any excerpt or
        // generated entry (so a v1-only reader can never see either kind), or any
        // per-entry override requires v2.
        let usesV2Features = subtitle != nil
            || authorLine != nil
            || introductionText != nil
            || introductionRichText != nil
            || collection.includeColophon
            || collection.includeProjectProvenance
            || entries.contains { $0.level != nil }
            || composition.includeFootnotes != nil
            || composition.includeSourceNote != nil
            || composition.defaultIncludeHeadnote != nil
            || entries.contains { $0.includeHeadnote == true || $0.headnoteSummaryId != nil }
            || entries.contains { $0.kind == CollectionEntryKind.excerpt.rawValue }
            || entries.contains { $0.kind == CollectionEntryKind.generated.rawValue }
            // M3: any non-empty per-entry title override is a v2 feature (the DTO already
            // holds nil for an empty override, so this is a pure presence check).
            || entries.contains { $0.titleOverride != nil }
            || entries.contains {
                $0.applyHighlightsOverride != nil
                    || $0.includeNotesOverride != nil
                    || $0.includeSourceNoteOverride != nil
                    || $0.includeFootnotesOverride != nil
                    || $0.summaryPromptIdOverride != nil
                    || $0.includeRelatedDocuments != nil
            }

        guard usesV2Features else {
            // No v2 feature: a pure v1 file, byte-identical to a pre-Phase-4 export
            // (every v2 key nil, so the sorted-keys encoder omits them all).
            return FRUSCollectionFile(
                format: formatIdentifier,
                formatVersion: 1,
                name: collection.name,
                note: collection.note,
                composition: composition,
                entries: entries
            )
        }

        return FRUSCollectionFile(
            format: formatIdentifier,
            formatVersion: 2,
            // Levels and front matter degrade on a v1 reader (flat headings, ignored
            // title page) — degradation never raises the floor (Migration rule 3).
            minimumReaderVersion: 1,
            name: collection.name,
            note: collection.note,
            subtitle: subtitle,
            authorLine: authorLine,
            introductionText: introductionText,
            introductionRichText: introductionRichText,
            includeColophon: collection.includeColophon ? true : nil,
            includeProjectProvenance: collection.includeProjectProvenance ? true : nil,
            composition: composition,
            entries: entries
        )
    }

    // MARK: - Apply the DTO into a context (import)

    /// Reconstructs a new `Collection` (plus its entries and any inline notes) from a decoded
    /// file, inserting everything into `context`.
    ///
    /// The imported collection gets fresh identity: new `id`/timestamps, no `projectIds`
    /// (device-local), and entry order normalized to `0..<n`. Inline notes are recreated as new
    /// `ResearchNote` records in the recipient's store and linked via `selectedNoteIds`.
    ///
    /// - Returns: The newly inserted `Collection` (the caller saves the context).
    @discardableResult
    static func apply(_ file: FRUSCollectionFile, into context: ModelContext) -> Collection {
        let collection = Collection(name: file.name, note: file.note)
        collection.defaultBodyDepth = file.composition.defaultBodyDepth
        collection.footnoteStyle = file.composition.footnoteStyle
        // Phase 5 pair (absent in v1 / pre-Phase-5 files → nil, i.e. derive from the
        // legacy footnoteStyle just applied above).
        collection.includeFootnotes = file.composition.includeFootnotes
        collection.includeSourceNote = file.composition.includeSourceNote
        collection.tocStyle = file.composition.tocStyle
        collection.applyHighlights = file.composition.applyHighlights
        collection.includeNotes = file.composition.includeNotes
        collection.includeWordCloud = file.composition.includeWordCloud
        // Absent (older files / no headnote default) → false, unchanged behavior.
        collection.defaultIncludeHeadnote = file.composition.defaultIncludeHeadnote ?? false
        // v2 front matter (all absent in v1 files → the model defaults, i.e. today's behavior).
        collection.subtitle = file.subtitle
        collection.authorLine = file.authorLine
        collection.introductionText = file.introductionText
        collection.introductionRichText = file.introductionRichText
        collection.includeColophon = file.includeColophon ?? false
        collection.includeProjectProvenance = file.includeProjectProvenance ?? false
        context.insert(collection)

        for (index, dto) in file.entries.enumerated() {
            // Skip-with-warning, never misdecode: an entry kind this build doesn't know
            // (a file from a newer app version) is omitted rather than imported as a
            // junk document entry (Authoring Phase 1 guard). `sortOrder` keeps the
            // enumeration index, so relative order of the imported entries is preserved.
            guard let kind = CollectionEntryKind(rawValue: dto.kind), kind != .unrecognized else {
                #if DEBUG
                print("[NativeCollectionSerializer] Skipping entry with unrecognized kind '\(dto.kind)'")
                #endif
                continue
            }
            let entry = CollectionEntry(
                collectionId: collection.id,
                documentId: dto.documentId ?? "",
                volumeId: dto.volumeId ?? "",
                sortOrder: index
            )
            entry.entryKind = kind
            entry.bodyDepthOverride = dto.bodyDepthOverride
            entry.text = dto.text
            entry.richText = dto.richText
            if kind == .document {
                // Phase 5 headnote keys (absent in older files → nil = Default, which resolves to
                // the collection default — false for imported collections, so unchanged behavior).
                entry.includeHeadnote = dto.includeHeadnote
                entry.headnoteSummaryId = dto.headnoteSummaryId
                // M3 title override (absent in pre-M3 files → nil → derived title).
                entry.titleOverride = dto.titleOverride
            }
            if kind == .document || kind == .heading {
                // Phase 5 override keys (absent → nil, i.e. inherit — the model
                // defaults). A heading's are its section defaults. selectedHighlightIds
                // has no file key: the imported entry keeps the default empty set,
                // which means "all of the recipient's highlights" when highlights apply.
                entry.applyHighlightsOverride = dto.applyHighlightsOverride
                entry.includeNotesOverride = dto.includeNotesOverride
                entry.includeSourceNoteOverride = dto.includeSourceNoteOverride
                entry.includeFootnotesOverride = dto.includeFootnotesOverride
                entry.summaryPromptIdOverride = dto.summaryPromptIdOverride
                entry.includeRelatedDocuments = dto.includeRelatedDocuments
            }
            if kind == .excerpt {
                // Phase 5 excerpt anchors (content + provenance travel on the shared
                // fields above; anchors keep precision rendering possible per A9).
                entry.excerptStart = dto.excerptStart
                entry.excerptEnd = dto.excerptEnd
                entry.excerptRenderingVersion = dto.excerptRenderingVersion
                entry.excerptColorTag = dto.excerptColorTag
            }
            if kind == .generated {
                // Phase 6: the block TYPE reconstructs verbatim — including a raw
                // value this build doesn't know (a newer writer's vocabulary), which
                // stays an inert generated entry: placement preserved, skipped at
                // resolve/render, re-exported intact. Rows never travel; they
                // re-resolve from the recipient's own data.
                entry.generatedBlockType = dto.generatedBlockType
            }
            if kind == .heading {
                // Defensive clamp on import: a level outside 1...maxLevel (a hand-edited
                // or future-writer file) degrades to the nearest valid depth, never
                // corrupts. Non-heading levels are ignored (tolerant reader).
                entry.level = min(max(dto.level ?? 1, 1), CollectionOutline.maxLevel)
            }
            entry.collection = collection

            if kind == .document, let noteTexts = dto.notes {
                var noteIds: [UUID] = []
                for body in noteTexts where !body.isEmpty {
                    let note = ResearchNote(
                        documentId: dto.documentId ?? "",
                        volumeId: dto.volumeId ?? "",
                        bodyText: body
                    )
                    context.insert(note)
                    noteIds.append(note.id)
                }
                entry.selectedNoteIds = noteIds
            }

            context.insert(entry)
        }

        return collection
    }

    // MARK: - Import a file from disk

    /// Reads a `.fruscollection` file at `url`, decodes + validates it, and reconstructs the
    /// collection into `context`. Handles security-scoped access for a user-picked URL. The
    /// caller is responsible for saving the context and presenting/selecting the result.
    ///
    /// - Throws: `NativeCollectionError` for a non-collection/unsupported file, a `DecodingError`
    ///   for malformed JSON, or a file-read error.
    @discardableResult
    static func importCollection(from url: URL, into context: ModelContext) throws -> Collection {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let file = try decode(data)
        return apply(file, into: context)
    }
}
