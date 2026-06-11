# Session 155 — Zotero Export (Options A + B)

## Goal
Implement Options A and B from `Planning/BigPicture-ZoteroExport.md` for both
iOS and macOS:

- **Option A** — "Send to Zotero (BibTeX)…": share/save a `.bib` file built
  from the existing `BibtexExporter`.
- **Option B** — "Send to Zotero (JSON)…": export Zotero's JSON exchange
  envelope `{"version": 5, "items": [...]}` with `bookSection` items carrying
  tags (from `UserTag`/`DocumentTagAssignment`) and notes (from
  `ResearchNote.bodyText`).

Scoping decisions (per user direction, 2026-06-10):
1. Both options ship on iOS **and** macOS.
2. Option B is wired to the **Document View** (not just the Collection view).
3. Option B is **also** available at the Collection level, exporting every
   document in a collection as one multi-item Zotero JSON file.

## Research finding — collections in Zotero JSON import

Zotero's native File → Import dialog recognizes RDF, BibTeX, RIS,
Refer/BibIX, EndNote XML, MODS, and CSL JSON — not the raw
`{"version": 5, "items": [...]}` "Connector"/Better-BibTeX item-JSON format.
That envelope's `items` array, however, natively supports **multiple items in
one file** — i.e. it already represents "a collection of items". Importing
such a file (via the Better BibTeX plugin's "Zotero JSON" translator, which
most academic-history Zotero users have installed, or via the Connector) adds
every item from the file in one operation, and Zotero's general "place
imported items into a new collection" import option lets the user recreate a
named collection from that one file.

**Conclusion:** export the whole FRUS Explorer collection as a single
`{"version": 5, "items": [...]}` file (one item per document, each with its
own tags/notes) — this *is* "Option B at the collection level". No additional
per-item `collections` field is added (not part of the documented schema and
its cross-library semantics are unreliable).

## Architecture

### New file: `FRUSExplorer/Citation/ZoteroJSONExporter.swift`
- `ZoteroJSONExporter` (mirrors `BibtexExporter`/`RISExporter`: `public
  struct … Sendable`, `init()`).
- Nested `Codable`/`Sendable`/`Equatable` types: `Item`, `Creator`, `Tag`,
  `Note`, `Envelope` (`version: Int = 5`, `items: [Item]`).
- `static func makeItem(document:volume:year:url:isEditorialNote:tags:notes:)
  -> Item` — `itemType: "bookSection"`, `title` = "Document N: <header>" (or
  bare header when `documentNumber == nil`), `bookTitle` = volume title,
  `creators` = volume editors as `creatorType: "editor"`, `date` = year,
  `publisher`/`place` from volume metadata, `accessDate` = today
  (`yyyy-MM-dd`), `extra` = "Editorial note" / "Document date: <dateline>"
  (joined by newline) when applicable, `tags`/`notes` from the supplied
  arrays.
- `func exportData(items:) throws -> Data` — pretty-printed
  `{"version": 5, "items": [...]}`.
- `static func fetchTagsAndNotes(documentId:volumeId:context:) -> (tags:
  [String], notes: [String])` — resolves `DocumentTagAssignment` +
  `ResearchNote.userTagIds` → `UserTag.name`, and `ResearchNote.bodyText` for
  the document. Shared by iOS and macOS document-level export.

### `DocumentViewModel` additions
- `public var bibtexCitation: String?`
- `public var risCitation: String?`
- `public func zoteroItem(tags: [String], notes: [String]) ->
  ZoteroJSONExporter.Item?`
- Private `effectivePublicationYear(volMeta:)` helper shared by all three
  (uses `FRUSVolumeMetadata.firstYear(in:)`, falls back to "n.d.").

### iOS — `CitationSheetView` (`DocumentView.swift`)
- Change `let citation: String` → `let vm: DocumentViewModel` (citation text
  derived from `vm.formattedCitation`).
- Update `DocumentSheet.citation(String)` → `case citation` (no payload); the
  "View Citation" toolbar button checks `vm.formattedCitation != nil`.
- Add an Export `Menu`: Copy BibTeX, Copy RIS, divider, `ShareLink` "Send to
  Zotero (BibTeX)…" (Option A) and "Send to Zotero (JSON)…" (Option B), each
  backed by a temp file written in `.task`.

### macOS — `CitationPopoverView` (`App/SupportingViews.swift`)
- Add `@Environment(\.modelContext) private var modelContext`.
- Extend the existing Export `Menu` with "Send to Zotero (BibTeX)…" and "Send
  to Zotero (JSON)…", each via a small `NSSavePanel` + "open with Zotero if
  installed, else reveal in Finder" helper
  (`NSWorkspace.shared.urlForApplication(withBundleIdentifier:
  "org.zotero.zotero")`).

### Collection level (`Collections/`)
- `CollectionExportDocument` gains `let zoteroItem: ZoteroJSONExporter.Item?
  = nil` (default preserves existing call sites).
- `CollectionEditorView.resolveDocuments()` and `.resolveSmartDocuments()`
  populate `zoteroItem` using the `FRUSDocumentMetadata`/`FRUSVolumeMetadata`
  values they already compute for `citation`, plus
  `ZoteroJSONExporter.fetchTagsAndNotes(...)` for tags (notes reuse
  `resolvedNoteTexts` where available).
- New `ExportFormat.zoteroJSON` case (`fileExtension` override → `"json"`,
  short `displayName` "Zotero" to fit the iOS segmented picker).
- New `FRUSExplorer/Collections/ZoteroCollectionExporter.swift` conforming to
  `CollectionExporter`: `documents.compactMap(\.zoteroItem)` → strip `.notes`
  when `!options.includeNotes` → `ZoteroJSONExporter().exportData(items:)` →
  write to a temp `<collection-name>-zotero.json`.

## Testing
- New `FRUSExplorerTests/ZoteroJSONExporterTests.swift`: `makeItem` field
  mapping (title/document-number formatting, editorial-note `extra`, dateline
  `extra`, tags/notes), `exportData` round trip
  (`{"version":5,"items":[...]}`), and `fetchTagsAndNotes` against an
  in-memory `ModelContainer` (pattern from `ResearchDataExporterTests`).
- Full `FRUSExplorerTests` run + iOS/macOS build verification.

## Out of scope
- Option C (Zotero Web API OAuth) — explicitly deferred.
- Settings → Integrations entry point — not needed; both options are
  discoverable from the existing citation Export menus.
