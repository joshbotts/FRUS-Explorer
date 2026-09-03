// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - Collection

/// A user-curated ordered list of FRUS documents.
///
/// Collections are used for export (PDF/HTML, Session 22), citation management,
/// and sharing related documents across a research project. Like research notes,
/// collections can carry multiple project tags and follow the same cross-project
/// visibility rules.
///
/// `documentEntries` is a relationship to `CollectionEntry` records. Entries are
/// ordered by `CollectionEntry.sortOrder`. Deleting a `Collection` cascades to
/// delete all its entries.
///
/// ## `lastModified`
/// Stamped at **save time** by `ModelModificationStamper`, and used by CloudKit last-write-wins
/// conflict resolution. The `didSet` observers below do **not** fire — the `@Model` macro discards
/// property observers — and are left pending a mechanical sweep. Editing an entry updates the
/// entry's own `lastModified`; the collection is not touched in that case.
@Model final class Collection {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Content

    var name: String = "" {
        didSet { lastModified = .now }
    }

    var note: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Front Matter (Authoring Phase 4)

    /// Optional subtitle rendered under the collection title on exported title pages.
    /// `nil` (the default) renders nothing, so pre-Phase-4 exports are byte-identical.
    var subtitle: String? {
        didSet { lastModified = .now }
    }

    /// Optional author/byline rendered on exported title pages (e.g. the researcher's name;
    /// the editor defaults it from the active `Project` name, but it is freely editable).
    /// `nil` (the default) renders nothing.
    var authorLine: String? {
        didSet { lastModified = .now }
    }

    /// Optional introduction rendered as the first prose flow of an export, before the
    /// table of contents' documents. Always the plain-text projection of the introduction —
    /// the fallback for plain contexts and the source when no rich formatting exists
    /// (the same plain-projection pattern as `CollectionEntry.text`/`richText`).
    var introductionText: String? {
        didSet { lastModified = .now }
    }

    /// Rich-text form of the introduction, stored as **RTF** `Data` (the
    /// `CollectionEntry.richText` pattern). `nil` when the introduction has no rich
    /// formatting; `introductionText` is kept in sync as the plain-text projection.
    var introductionRichText: Data? {
        didSet { lastModified = .now }
    }

    /// When `true`, exports append a colophon page (how/when the artifact was produced).
    /// Defaults to `false` so collections that never opt in export exactly as today.
    var includeColophon: Bool = false {
        didSet { lastModified = .now }
    }

    /// When `true`, exports stamp the **active project**'s name (and research question, if any) onto
    /// the title page (#377 Phase 4). Off by default so the project — and especially the research
    /// question — is never disclosed on a shared/published artifact unless the researcher opts in.
    /// The toggle is persisted per-collection, but the *value* stamped is the project active at
    /// export time (like the `authorLine` placeholder), not a value stored here.
    var includeProjectProvenance: Bool = false {
        didSet { lastModified = .now }
    }

    /// When `true`, exports append the **method appendix** — the queries run under the active
    /// project, with the scope each ran under and how its count must be read (M-2).
    ///
    /// Off by default, and for a stronger reason than its two siblings: the appendix carries the
    /// *text of every search* the researcher ran on this project. That is the point of it — Wave R
    /// decision D5 keeps the trail precisely so a claim of absence can be checked — but it is also
    /// exactly the kind of thing that must never appear on a shared artifact by accident.
    ///
    /// Narrowed to the active project at export time, never the whole trail. See
    /// ``QueryMethodAppendix/scoped(toProject:)``.
    var includeMethodAppendix: Bool = false {
        didSet { lastModified = .now }
    }

    // MARK: - Project Tags

    /// IDs of `Project` records this collection is visible in.
    var projectIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Smart Collection

    /// When non-nil, this collection is a "smart collection" — its documents are resolved
    /// dynamically at export time by executing the `SavedSearch` with this ID.
    /// Static `documentEntries` are ignored during export when this is set.
    var savedSearchId: UUID? {
        didSet { lastModified = .now }
    }

    // MARK: - Composition (persisted export-content settings)

    /// These describe *what the exported product contains* — the editorial decisions that
    /// used to be re-chosen ephemerally in the export sheet (before Session-… Phase 1a).
    /// They are edited in the collection manager and read by `buildExportOptions` at export
    /// time, so a collection's composition is stable and re-exportable to any format.
    /// Enum-backed fields store the `rawValue` for CloudKit compatibility.

    /// Default document-body depth for exports — a `CollectionBodyDepth` raw value
    /// (`"full"`, `"summaryOnly"`, `"index"`). Per-entry overrides may refine it (Phase 1b).
    var defaultBodyDepth: String = "full" {
        didSet { lastModified = .now }
    }

    /// Footnote inclusion style for exports — a `CollectionFootnoteStyle` raw value
    /// (`"none"`, `"sourceNoteOnly"`, `"all"`).
    ///
    /// **Legacy field (Authoring Phase 5).** Superseded as the read surface by the
    /// `includeFootnotes`/`includeSourceNote` Bool pair, but it is a synced field on
    /// fielded builds, so it is never deleted or re-purposed: the effective setters keep
    /// writing a best-fit raw value here so old readers and old devices behave sensibly.
    var footnoteStyle: String = "all" {
        didSet { lastModified = .now }
    }

    /// Whether exported documents include their footnotes (Authoring Phase 5).
    /// `nil` (every pre-Phase-5 collection) means "derive from the legacy
    /// `footnoteStyle`" — see `effectiveIncludeFootnotes`, the read surface.
    /// Prefer the effective accessors; write through them so `footnoteStyle` stays
    /// consistent for old readers.
    var includeFootnotes: Bool? {
        didSet { lastModified = .now }
    }

    /// Whether exported documents append their archival source note (Authoring Phase 5).
    /// `nil` (every pre-Phase-5 collection) means "derive from the legacy
    /// `footnoteStyle`" — see `effectiveIncludeSourceNote`, the read surface.
    /// Prefer the effective accessors; write through them so `footnoteStyle` stays
    /// consistent for old readers.
    var includeSourceNote: Bool? {
        didSet { lastModified = .now }
    }

    /// The effective "include footnotes" flag: the stored Bool when set, else the value
    /// derived from the legacy `footnoteStyle` (`all` → `true`; `sourceNoteOnly`/`none` →
    /// `false`) — so an untouched collection composes exactly as it always has.
    ///
    /// Setting writes **both** stored Bools (freezing the currently-derived pair so a
    /// later `footnoteStyle` rewrite cannot shift the other flag) **and** a best-fit
    /// `footnoteStyle` raw value for old readers — see `bestFitFootnoteStyleRawValue`.
    var effectiveIncludeFootnotes: Bool {
        get { includeFootnotes ?? Self.derivedFootnoteFlags(fromStyleRawValue: footnoteStyle).footnotes }
        set { writeFootnoteFlags(footnotes: newValue, sourceNote: effectiveIncludeSourceNote) }
    }

    /// The effective "include archival source note" flag: the stored Bool when set, else
    /// the value derived from the legacy `footnoteStyle` (`sourceNoteOnly` → `true`;
    /// `all`/`none` → `false`). Setting mirrors `effectiveIncludeFootnotes`.
    var effectiveIncludeSourceNote: Bool {
        get { includeSourceNote ?? Self.derivedFootnoteFlags(fromStyleRawValue: footnoteStyle).sourceNote }
        set { writeFootnoteFlags(footnotes: effectiveIncludeFootnotes, sourceNote: newValue) }
    }

    /// Maps a legacy `footnoteStyle` raw value to the Bool pair it always meant:
    /// `all` → (true, false), `sourceNoteOnly` → (false, true), `none` → (false, false).
    /// An unknown raw value falls back to `all`, matching every pre-Phase-5 read site's
    /// `CollectionFootnoteStyle(rawValue:) ?? .all`.
    static func derivedFootnoteFlags(fromStyleRawValue raw: String) -> (footnotes: Bool, sourceNote: Bool) {
        switch raw {
        case "sourceNoteOnly": return (false, true)
        case "none":           return (false, false)
        default:               return (true, false)   // "all" + unknown values (legacy fallback)
        }
    }

    /// The best-fit legacy `footnoteStyle` raw value for a Bool pair, written alongside
    /// the pair so old readers/devices keep behaving sensibly: (true, false) → `all`,
    /// (false, true) → `sourceNoteOnly`, (false, false) → `none`. The one combination the
    /// tri-state cannot express — footnotes **and** the source note — writes `all`
    /// (documented lossy mapping: an old build shows the footnotes and drops the source
    /// note, which is the closer of the two degradations to the author's intent).
    static func bestFitFootnoteStyleRawValue(footnotes: Bool, sourceNote: Bool) -> String {
        switch (footnotes, sourceNote) {
        case (true, false):  return "all"
        case (false, true):  return "sourceNoteOnly"
        case (false, false): return "none"
        case (true, true):   return "all"   // inexpressible in the tri-state; see doc
        }
    }

    /// Writes the Bool pair and the best-fit legacy `footnoteStyle` in one step — the
    /// single write path used by both effective setters.
    private func writeFootnoteFlags(footnotes: Bool, sourceNote: Bool) {
        includeFootnotes = footnotes
        includeSourceNote = sourceNote
        footnoteStyle = Self.bestFitFootnoteStyleRawValue(footnotes: footnotes, sourceNote: sourceNote)
    }

    /// Table-of-contents label style for exports — a `CollectionToCStyle` raw value
    /// (`"citation"`, `"headerAndDateline"`).
    var tocStyle: String = "citation" {
        didSet { lastModified = .now }
    }

    /// When `true`, user highlights are annotated inline in exported document bodies.
    var applyHighlights: Bool = false {
        didSet { lastModified = .now }
    }

    /// When `true`, attached research notes appear below each document in exports.
    var includeNotes: Bool = true {
        didSet { lastModified = .now }
    }

    /// When `true`, a word-cloud overview is prepended to PDF/HTML exports.
    var includeWordCloud: Bool = false {
        didSet { lastModified = .now }
    }

    /// The collection-level default for per-document headnotes (Composer redesign): a document
    /// entry whose `includeHeadnote` is `nil` (Default) inherits this. `false` by default, so
    /// existing collections render exactly as before. Set from the composition "Headnotes" control.
    var defaultIncludeHeadnote: Bool = false {
        didSet { lastModified = .now }
    }

    /// The `SummarizationPrompt.id` used when the body depth is `"summaryOnly"`.
    var summaryPromptId: UUID? {
        didSet { lastModified = .now }
    }

    /// A plain-language, one-sentence description of what this collection will export, shown in the
    /// export sheet (Composer redesign 5): the resolved body depth plus the content the composition
    /// turns on — e.g. "Exports an AI summary of each document, with headnotes, your notes, and
    /// footnotes." Reads the *collection defaults*; a per-document override can still differ.
    var compositionSummarySentence: String {
        let lead: String
        switch CollectionBodyDepth(rawValue: defaultBodyDepth) ?? .full {
        case .full:
            lead = String(localized: "collection.export.summary.lead.full",
                          defaultValue: "Exports the full text of each document")
        case .summaryOnly:
            lead = String(localized: "collection.export.summary.lead.summary",
                          defaultValue: "Exports an AI summary of each document")
        case .index:
            lead = String(localized: "collection.export.summary.lead.index",
                          defaultValue: "Exports a citation-only index")
        }
        var included: [String] = []
        if defaultIncludeHeadnote {
            included.append(String(localized: "collection.export.summary.headnotes", defaultValue: "headnotes"))
        }
        if includeNotes {
            included.append(String(localized: "collection.export.summary.notes", defaultValue: "your notes"))
        }
        if effectiveIncludeFootnotes {
            included.append(String(localized: "collection.export.summary.footnotes", defaultValue: "footnotes"))
        }
        if effectiveIncludeSourceNote {
            included.append(String(localized: "collection.export.summary.sourceNotes", defaultValue: "source notes"))
        }
        if applyHighlights {
            included.append(String(localized: "collection.export.summary.highlights", defaultValue: "highlights"))
        }
        if includeWordCloud {
            included.append(String(localized: "collection.export.summary.wordCloud", defaultValue: "a word-cloud overview"))
        }
        guard !included.isEmpty else { return lead + "." }
        let list = ListFormatter.localizedString(byJoining: included)
        return String(format: String(localized: "collection.export.summary.with %1$@ %2$@",
                                     defaultValue: "%1$@, with %2$@."), lead, list)
    }

    // MARK: - Entries

    /// Ordered document entries. Sorted by `CollectionEntry.sortOrder` at display time.
    ///
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    /// Use `documentEntries ?? []` when iterating.
    ///
    /// `deleteRule: .nullify` is required for CloudKit sync compatibility — cascade delete
    /// rules are not supported by CloudKit. Callers must delete associated `CollectionEntry`
    /// records explicitly before deleting the parent `Collection`.
    @Relationship(deleteRule: .nullify, inverse: \CollectionEntry.collection)
    var documentEntries: [CollectionEntry]? {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        name: String,
        note: String? = nil,
        projectIds: [UUID] = []
    ) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.projectIds = projectIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] Collection created: \(id) '\(name)'")
        #endif
    }
}

// MARK: - CollectionEntryKind

/// What a `CollectionEntry` contributes to the composed collection (Phase 3a).
///
/// A collection is an ordered sequence of these: `document` entries are the FRUS documents;
/// `heading` entries start a section; `prose` entries are the researcher's own editorial note
/// blocks; `excerpt` entries are frozen verbatim quotations from a document (Authoring
/// Phase 5). This turns a flat document list into an authored, sectioned reader.
enum CollectionEntryKind: String, CaseIterable, Sendable {
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
    static var allCases: [CollectionEntryKind] { [.document, .heading, .prose, .excerpt, .generated] }
}

// MARK: - CollectionEntry

/// A single item in a `Collection` — a document, a section heading, or a prose block — with
/// an explicit sort order.
///
/// `collectionId` carries the parent collection's `id` for reference without
/// requiring the full `Collection` object to be in memory. The relationship
/// to the parent collection is managed by `Collection.documentEntries`.
///
/// `researchNoteId` optionally links a specific `ResearchNote` to this entry,
/// used in export to include the note alongside the document.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — Session 128: added `selectedNoteIds` for multi-note per-entry selection;
///          `researchNoteId` retained for backward compatibility
///   1.2 — Session 153: removed `includeDocumentBody` (moved to export-level `CollectionBodyDepth`)
///   1.3 — Collections rework Phase 1b: added `bodyDepthOverride` (per-entry body depth)
///   1.4 — Collections rework Phase 3a: added `kind` + `text` (heterogeneous entries:
///          document / section heading / editorial prose block)
///   1.5 — Collections rework Phase 3b: added `richText` (rich-text prose body, an encoded
///          `AttributedString`; `text` retained as the plain-text projection)
///   1.6 — Authoring Phase 1: unknown `kind` raw values read as `.unrecognized` instead of
///          `.document` (mixed-build CloudKit sync guard); the setter never persists it
///   1.7 — Authoring Phase 4: added `level` (heading nesting depth, default 1) — the tree is
///          level-encoded on the flat list; `sortOrder` semantics are untouched
///   1.8 — Authoring Phase 5: added `includeHeadnote` (default `false`) + `headnoteSummaryId`
///          — an opt-in italic abstract (a chosen `GeneratedSummary`) rendered above the
///          document body in exports/preview; defaults reproduce pre-Phase-5 output exactly
///   1.9 — Authoring Phase 5 (excerpts): added the `.excerpt` kind and its anchoring
///          fields `excerptStart`/`excerptEnd`/`excerptRenderingVersion`/`excerptColorTag`
///          — all additive and optional (nil on every existing entry), copied from the
///          source highlight/selection at creation. Per decision A9 the frozen `text`
///          is the rendering source of truth today; the anchors make precision slicing
///          a later rendering-only flip
///   1.10 — Authoring Phase 5 (overrides): per-entry composition overrides —
///          `applyHighlightsOverride`, `includeNotesOverride`, `includeSourceNoteOverride`,
///          `includeFootnotesOverride`, `summaryPromptIdOverride`, `selectedHighlightIds`
///          (A8), and `includeRelatedDocuments` (A10). All optional-or-defaulted;
///          `nil`/empty on every existing entry, reproducing pre-override behavior
///          exactly. On a `.heading` entry the same fields act as **section-level
///          defaults** for the documents it owns. Resolution happens in exactly one
///          place — `CollectionContentResolver`, via the `CollectionOutline` ancestor
///          cascade (entry override → nearest ancestor heading → collection default)
///   1.11 — Authoring Phase 6 (generated apparatus): added the `.generated` kind +
///          `generatedBlockType` (a `CollectionGeneratedBlockType` raw value) — a
///          placeable apparatus block (bibliography / chronology / sources & archives /
///          persons index / thematic index, decision A11). Additive and optional (`nil`
///          on every existing entry); generated entries use no other content fields, and
///          block rows are re-resolved from the collection's documents at every resolve,
///          never stored. Old builds see the kind as `.unrecognized` (inert)
///   1.12 — Collections Manager M2 (D5): `selectedNoteIds` empty now means **all** of the
///          document's notes (mirroring `selectedHighlightIds`), not none — so enabling
///          notes on an untouched entry exports them and future notes auto-flow in. No
///          schema/format change; the ids are still never serialized into
///          `.fruscollection`. Resolution lives in `CollectionContentResolver` and the
///          native-export closure; both honor empty = all
///   1.13 — Collections Manager M3 (D4): added `titleOverride` (document entries only) — a
///          shared plain-text override driving **both** the ToC label and the export
///          heading. Additive/optional (`nil` on every existing entry, unchanged output).
///          Unlike the id-set overrides it **is** portable content, so it travels in
///          `.fruscollection`; a non-empty value promotes the file to `formatVersion 2`
///          while untouched entries stay byte-identical. No `minimumReaderVersion` bump —
///          a v1 reader ignoring the key degrades to the derived title
@Model final class CollectionEntry {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Parent Relationship

    /// Back-reference to the owning `Collection`. Required by CloudKit sync (all relationships must have inverses).
    /// Managed by `Collection.documentEntries`; do not set directly.
    var collection: Collection?

    /// The parent `Collection.id`. Carried explicitly for fast lookups that don't need the full collection graph.
    var collectionId: UUID = UUID() {
        didSet { lastModified = .now }
    }

    // MARK: - Document Reference

    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Title Override (Collections Manager M3)

    /// Per-entry title override (decision D4) — plain text that replaces the *derived*
    /// document title in **both** the collection table-of-contents label **and** the
    /// top-of-document export heading. `nil`/empty (every existing entry) uses the derived
    /// default (the source note header, else the citation, else `"{volumeTitle} — {documentId}"`),
    /// so untouched entries render exactly as before.
    ///
    /// **Document entries only.** Section headings edit their own title inline via
    /// `CollectionHeadingRow`; the heading inspector variant does not expose this field.
    ///
    /// One shared field (not separate ToC/heading overrides): the name is deliberately
    /// generic so a future ToC-vs-heading split is a *purely additive* field, not a
    /// migration. Unlike `selectedHighlightIds`/`selectedNoteIds` this **is** portable
    /// content (plain text, no device-local UUIDs), so it **travels in `.fruscollection`
    /// files** — a non-empty value makes an entry a v2 feature (the serializer emits
    /// `formatVersion 2`); an entry without one keeps the file byte-identical to pre-M3.
    var titleOverride: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Ordering

    /// Position within the parent collection. Lower values appear first.
    var sortOrder: Int = 0 {
        didSet { lastModified = .now }
    }

    // MARK: - Outline Level (Authoring Phase 4)

    /// Heading nesting depth, meaningful on `.heading` entries only (documents/prose
    /// ignore it). Defaults to `1`, so every pre-Phase-4 heading — and every heading a
    /// user never indents — renders exactly as today.
    ///
    /// **Level-encoding rationale.** The section tree is *derived*, never stored: the
    /// entry list stays flat with global `sortOrder` retained, and `CollectionOutline`
    /// (the single linearizer) computes the tree from heading levels. This is explicitly
    /// *not* a parent-pointer scheme, because fielded builds reindex `sortOrder` globally
    /// `0..<n` on every move — re-scoping that synced field's semantics to sibling order
    /// would corrupt structure across mixed-build iCloud accounts. Nesting is UI-capped
    /// at `CollectionOutline.maxLevel` (3); a synced value outside `1...3` (from a future
    /// build or a merge) is clamped at read time by `CollectionOutline`, never migrated —
    /// degradation is a flattened heading, never corruption.
    var level: Int = 1 {
        didSet { lastModified = .now }
    }

    // MARK: - Optional Note Link

    /// An optional `ResearchNote.id` included with this entry in exports.
    /// Retained for backward compatibility. When `selectedNoteIds` is non-empty,
    /// it takes precedence over this field during export resolution.
    var researchNoteId: UUID? {
        didSet { lastModified = .now }
    }

    /// IDs of `ResearchNote` records to include with this entry in exports (decision D5,
    /// mirroring `selectedHighlightIds`). **Empty means all of the document's research
    /// notes** — the write-on-first-deselect convention: an untouched entry keeps the
    /// empty set, so future notes on the document auto-flow into exports, and the set is
    /// only populated once the user deselects a specific note in the inspector. The
    /// legacy single-note `researchNoteId` link is honored only while `selectedNoteIds`
    /// is empty *and* `researchNoteId` is set (an un-migrated entry). CloudKit-compatible
    /// (same pattern as `Collection.projectIds`); like `selectedHighlightIds`, note ids
    /// are meaningful across the author's own synced devices but are **never serialized
    /// into `.fruscollection` files** (a recipient lacks the referenced notes).
    ///
    /// > **D5 behavior change (2026-07-04).** Empty previously meant "no notes." It now
    /// > means "all notes," matching `selectedHighlightIds`. Existing untouched-note
    /// > entries therefore gain their notes on the next export when notes are enabled —
    /// > the one intentional export-default change of the Collections Manager M2 program,
    /// > applied with no data migration (empty is never written until the first deselect).
    var selectedNoteIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Composition Override

    /// Per-entry document-body depth — a `CollectionBodyDepth` raw value that overrides the
    /// collection's `defaultBodyDepth` for this one document. `nil` means "use the collection
    /// default", letting a single collection mix full documents, summaries, and citation-only
    /// entries into one product (Collections rework Phase 1b).
    var bodyDepthOverride: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Composition Overrides (Authoring Phase 5)

    /// Per-entry override of the collection's `applyHighlights` composition flag.
    /// `nil` (every existing entry) inherits — the nearest ancestor heading's override
    /// when one is set, else the collection default. On a `.heading` entry this is the
    /// section-level default for the documents it owns. Resolved only by
    /// `CollectionContentResolver` via the `CollectionOutline` cascade.
    var applyHighlightsOverride: Bool? {
        didSet { lastModified = .now }
    }

    /// Per-entry override of the collection's `includeNotes` composition flag
    /// (`nil` = inherit; section default on headings — see `applyHighlightsOverride`).
    var includeNotesOverride: Bool? {
        didSet { lastModified = .now }
    }

    /// Per-entry override of the collection's effective include-source-note flag
    /// (`nil` = inherit; section default on headings — see `applyHighlightsOverride`).
    var includeSourceNoteOverride: Bool? {
        didSet { lastModified = .now }
    }

    /// Per-entry override of the collection's effective include-footnotes flag
    /// (`nil` = inherit; section default on headings — see `applyHighlightsOverride`).
    /// Like the collection-level flag, footnote gating applies where footnote rendering
    /// is gated — the shared HTML renderer and the live preview (the PDF/DOCX footnote
    /// gap predates this field and is deliberately unchanged).
    var includeFootnotesOverride: Bool? {
        didSet { lastModified = .now }
    }

    /// Per-entry override of the collection's `summaryPromptId` — which summarization
    /// prompt supplies this document's `.summaryOnly` body and headnote-fallback pick.
    /// `nil` = inherit (section default on headings — see `applyHighlightsOverride`).
    var summaryPromptIdOverride: UUID? {
        didSet { lastModified = .now }
    }

    /// IDs of the `DocumentHighlight` records to include when highlights apply to this
    /// entry (decision A8, mirroring `selectedNoteIds`). **Empty means all highlights**
    /// — the pre-override behavior — so every existing entry is unchanged. Highlight ids
    /// are meaningful across the author's own CloudKit-synced devices; they are
    /// deliberately **never serialized into `.fruscollection` files** (the referenced
    /// highlights don't travel, so a recipient's export falls back to all-their-highlights
    /// semantics).
    var selectedHighlightIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// Per-entry opt-in for the related-documents line (decision A10): when it resolves
    /// `true`, exports append a "See also:" citation line listing the documents this one
    /// cross-references **that are also in the collection** (in-collection targets only —
    /// bounded and meaningful, never the full cross-reference fan-out). `nil` (every
    /// existing entry) inherits the nearest ancestor heading's value, else **off** — the
    /// collection has no related-documents default, so untouched collections are
    /// unchanged. Section default on headings — see `applyHighlightsOverride`.
    var includeRelatedDocuments: Bool? {
        didSet { lastModified = .now }
    }

    // MARK: - Headnote (Authoring Phase 5)

    /// Per-document headnote opt-in (Composer redesign: `nil` = Default = inherit the collection's
    /// `defaultIncludeHeadnote`; `true` = on; `false` = off). When effectively on, exports and the
    /// live preview render an italic abstract (a `GeneratedSummary`) **above** the document body —
    /// a headnote, versus the body-depth `summaryOnly` summary-*instead-of*-body. Was a non-optional
    /// `Bool` (default `false`) through Authoring Phase 5; widened to optional so a collection-level
    /// default can cascade like the other overrides. Existing entries migrate to their stored value
    /// (explicit on/off), so nothing renders differently.
    var includeHeadnote: Bool? {
        didSet { lastModified = .now }
    }

    /// The specific `GeneratedSummary.id` to render as this entry's headnote. `nil` with
    /// `includeHeadnote == true` falls back to a stored summary for the document
    /// (preferring one generated with the collection's `summaryPromptId`).
    var headnoteSummaryId: UUID? {
        didSet { lastModified = .now }
    }

    // MARK: - Excerpt Anchors (Authoring Phase 5)

    /// UTF-16 start offset of the excerpted passage within the source document's
    /// flat text (the `DocumentHighlight.startOffset` coordinate space), copied from the
    /// source highlight/selection when the excerpt was created. `nil` when the creation
    /// path had no offsets (e.g. a footnote selection reported text only).
    ///
    /// **Decision A9.** The frozen `text` is the excerpt's rendering source of truth
    /// today; these anchors are stored at creation — they are free to capture — so a
    /// precision styled slice of the render model stays a later rendering-only decision.
    var excerptStart: Int? {
        didSet { lastModified = .now }
    }

    /// UTF-16 end offset (exclusive) of the excerpted passage — see
    /// `excerptStart` for the coordinate space and the A9 rationale. `nil` when the
    /// creation path had no offsets.
    var excerptEnd: Int? {
        didSet { lastModified = .now }
    }

    /// The source document's `renderingVersion` at excerpt creation (the
    /// `DocumentHighlight.renderingVersion` scheme: a 16-char SHA-256 prefix over the
    /// render model's flat text + converter version). A future precision-rendering flip (A9) compares it
    /// against the current document version to decide whether the offsets still align;
    /// today it is stored, never read at render time. `nil` when unavailable at creation.
    var excerptRenderingVersion: String? {
        didSet { lastModified = .now }
    }

    /// The source highlight's `colorTag` (`"yellow"`/`"green"`/`"blue"`/`"pink"`), when
    /// the excerpt was created from a `DocumentHighlight` — renderers use it as the
    /// quote block's accent. `nil` for excerpts created from a plain text selection.
    var excerptColorTag: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Entry Kind (Phase 3a)

    /// What this entry contributes to the composed collection — a `CollectionEntryKind` raw
    /// value. Defaults to `"document"` so every existing entry stays a document. A `"heading"`
    /// starts a section; a `"prose"` is an editorial note block; an `"excerpt"` is a frozen
    /// quotation (Phase 5); a `"generated"` is a placeable apparatus block (Phase 6).
    /// Heading/prose entries use `text` and ignore `documentId`/`volumeId`; excerpt
    /// entries use `text` (the passage) AND `documentId`/`volumeId` (provenance);
    /// generated entries use only `generatedBlockType`. Stored raw for CloudKit
    /// compatibility.
    var kind: String = "document" {
        didSet { lastModified = .now }
    }

    // MARK: - Generated Block (Authoring Phase 6)

    /// Which apparatus block a `.generated` entry produces — a
    /// `CollectionGeneratedBlockType` raw value (`"bibliography"` / `"chronology"` /
    /// `"archivalSources"` / `"personsIndex"` / `"thematicIndex"`). `nil` on every other
    /// kind (and on every pre-Phase-6 entry). Only the TYPE is ever stored: the block's
    /// rows are computed from the collection's resolved document set at resolve time, so
    /// they always reflect the current documents and the current device's data. A raw
    /// value this build doesn't know (written by a newer version) leaves the entry inert
    /// — shown as an unsupported block and skipped by resolve/export, never misread.
    var generatedBlockType: String? {
        didSet { lastModified = .now }
    }

    /// The section title (for a `heading` entry), the editorial body (for a `prose` entry),
    /// or the frozen verbatim passage (for an `excerpt` entry, Phase 5).
    /// `nil` for document entries. Always the plain-text form — a fallback for plain contexts
    /// and the source for a `prose` entry with no rich formatting.
    var text: String? {
        didSet { lastModified = .now }
    }

    /// Rich-text form of a `prose` entry's body, stored as **RTF** `Data`. `nil` for
    /// headings/documents and for plain prose; `text` is kept in sync as the plain-text
    /// projection so search and plain renderers keep working. Entries written by a Phase 3b
    /// build (or synced from one) instead hold that era's JSON-encoded `AttributedString` —
    /// readers go through `ProseRichText`/`CollectionProse`, which decode both formats and
    /// migrate legacy blobs to RTF (`ProseRichText.migrateLegacyJSONIfNeeded`).
    var richText: Data? {
        didSet { lastModified = .now }
    }

    /// Typed accessor for `kind` (not persisted; `kind` is the stored raw value).
    /// An unknown raw value — written by a newer app version — reads as `.unrecognized`
    /// rather than silently becoming a junk `.document`.
    var entryKind: CollectionEntryKind {
        get { CollectionEntryKind(rawValue: kind) ?? .unrecognized }
        set {
            // `.unrecognized` is a decode fallback; persisting its raw value would
            // round-trip as an unknown kind on every other device. Never write it.
            guard newValue != .unrecognized else { return }
            kind = newValue.rawValue
        }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        collectionId: UUID,
        documentId: String,
        volumeId: String,
        sortOrder: Int,
        researchNoteId: UUID? = nil,
        selectedNoteIds: [UUID] = []
    ) {
        self.id = UUID()
        self.collectionId = collectionId
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.researchNoteId = researchNoteId
        self.selectedNoteIds = selectedNoteIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] CollectionEntry created: \(id) doc=\(volumeId)/\(documentId)")
        #endif
    }
}

// MARK: - Collection Manager scope filter

extension Collection {
    /// The Collection Manager's default scope (issue #213): both the iOS `CollectionListView`
    /// and the macOS `MacCollectionManagerView` open showing collections from *every* project.
    /// Kept here (rather than inline in each view's `@State`) so a single test can pin the
    /// default and catch a silent revert to project-scoped.
    static let managerDefaultShowAllCollections = true

    /// Applies the Collection Manager's project-scope filter shared by the iOS
    /// `CollectionListView` and the macOS `MacCollectionManagerView`, so both surfaces
    /// agree on which collections are visible for a given scope.
    ///
    /// - Parameters:
    ///   - all: every collection (typically the `@Query` result, newest-first).
    ///   - activeProjectId: the currently active project, or `nil` in Global Context.
    ///   - showAll: the user's scope override. When `true` (the default in both managers as
    ///     of issue #213) every collection is shown regardless of project association.
    /// - Returns: `all` when `showAll` is set or there is no active project; otherwise only
    ///   collections tagged to `activeProjectId`.
    static func visibleCollections(_ all: [Collection],
                                   activeProjectId: UUID?,
                                   showAll: Bool) -> [Collection] {
        guard let projectId = activeProjectId, !showAll else { return all }
        return all.filter { $0.projectIds.contains(projectId) }
    }
}

// MARK: - Duplication (#300)

extension Collection {
    /// Creates an independent, fully-editable deep copy of this collection and inserts it — with a
    /// copy of every entry and each entry's own headnote draft — into `context`. All composition,
    /// front-matter, headnote, and smart-link settings are copied; ids are new throughout, so the
    /// original is untouched and the two share no state (#300). Returns the new collection; the caller
    /// saves the context.
    @discardableResult
    func duplicate(in context: ModelContext) -> Collection {
        let base = name.isEmpty
            ? String(localized: "collection.untitled.name", defaultValue: "Untitled Collection")
            : name
        let copy = Collection(
            name: String(format: String(localized: "collection.duplicate.name %@",
                                        defaultValue: "%@ copy"), base),
            note: note,
            projectIds: projectIds)

        // Front matter (Authoring Phase 4)
        copy.subtitle = subtitle
        copy.authorLine = authorLine
        copy.introductionText = introductionText
        copy.introductionRichText = introductionRichText
        copy.includeColophon = includeColophon

        // Smart-collection link
        copy.savedSearchId = savedSearchId

        // Composition (persisted export-content settings)
        copy.defaultBodyDepth = defaultBodyDepth
        copy.footnoteStyle = footnoteStyle
        copy.includeFootnotes = includeFootnotes
        copy.includeSourceNote = includeSourceNote
        copy.tocStyle = tocStyle
        copy.applyHighlights = applyHighlights
        copy.includeNotes = includeNotes
        copy.includeWordCloud = includeWordCloud
        copy.defaultIncludeHeadnote = defaultIncludeHeadnote
        copy.summaryPromptId = summaryPromptId

        context.insert(copy)

        // Deep-copy every entry in order, preserving all per-entry overrides.
        for entry in (documentEntries ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let e = CollectionEntry(
                collectionId: copy.id,
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                researchNoteId: entry.researchNoteId,
                selectedNoteIds: entry.selectedNoteIds)
            e.collection = copy
            e.titleOverride = entry.titleOverride
            e.level = entry.level
            e.kind = entry.kind
            e.text = entry.text
            e.richText = entry.richText
            e.bodyDepthOverride = entry.bodyDepthOverride
            e.applyHighlightsOverride = entry.applyHighlightsOverride
            e.includeNotesOverride = entry.includeNotesOverride
            e.includeSourceNoteOverride = entry.includeSourceNoteOverride
            e.includeFootnotesOverride = entry.includeFootnotesOverride
            e.summaryPromptIdOverride = entry.summaryPromptIdOverride
            e.selectedHighlightIds = entry.selectedHighlightIds
            e.includeRelatedDocuments = entry.includeRelatedDocuments
            e.includeHeadnote = entry.includeHeadnote
            e.headnoteSummaryId = entry.headnoteSummaryId
            e.generatedBlockType = entry.generatedBlockType
            e.excerptStart = entry.excerptStart
            e.excerptEnd = entry.excerptEnd
            e.excerptRenderingVersion = entry.excerptRenderingVersion
            e.excerptColorTag = entry.excerptColorTag
            context.insert(e)
            // Give the copy its own headnote draft (remaps headnoteSummaryId when the source's is a
            // draft; a real document summary stays shared). #300 full-independence.
            GeneratedSummary.duplicateHeadnoteDraft(from: entry, to: e, in: context)
        }

        #if DEBUG
        print("[Collection] Duplicated \(id) → \(copy.id) with \(documentEntries?.count ?? 0) entries")
        #endif
        return copy
    }
}
