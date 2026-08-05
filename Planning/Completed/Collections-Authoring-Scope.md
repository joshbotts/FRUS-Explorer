# Collections Authoring — Scope

**The ask (owner, 2026-07-02):** "I do not like the collection editor UI. I would like this to be a fully-featured tool for users to turn their selected documents into rich historical products with as many or as few of the app-provided enhancement and annotation tools as they want."

**The premise:** design backwards from the product. The Collections rework (Phases 1a–4, PRs #120–#136) made the manager the editorial place and export pure sharing — but the manager is still a Form over a SwiftData model. This program makes it the tool that authors a specific artifact, defined in §0. Every enhancement is **opt-in with inherit-by-default**: a user can ship a bare document reader or a fully-apparatused edited volume from the same tool.

This document follows `Collections-Rework-Scope.md` conventions: phases with concrete work items, decision points framed cheap/expensive (**A1–A12**, resolved by the owner at implementation time), cross-cutting gates, and a sequencing table. The prior rework's D1 (nested sections), D3 (excerpting), and D4 (includable cross-refs/persons) shipped only their cheap options; their expensive columns are seeds here.

---

## 0. The target artifact: "the FRUS Reader"

The export (PDF/DOCX/HTML + the round-trippable `.fruscollection` source) is a small edited documentary volume in FRUS's own genre conventions, because the users are people who read FRUS:

1. **Title page** — title, subtitle, author line, date, one-line description (today's `Collection.note`).
2. **Editorial introduction** — the researcher's framing essay (rich text, existing RTF path).
3. **Table of contents** — nested sections, existing citation/header-dateline label styles.
4. **Chronology** *(optional, placeable front matter)* — date-ordered table of the collection's documents.
5. **Body sections** — nestable heading → optional section prose → documents. Each document: citation line + dateline → optional **headnote** (AI summary *above* a full body, not only instead of it) → body at chosen depth **or selected excerpts** → highlights, footnotes/source note per composition, research notes, optional "related documents" line.
6. **Back matter** *(each opt-in, placeable)* — Persons index; Sources & Archives (NARA links); Bibliography; Thematic (tag) index; word cloud.
7. **Colophon** *(opt-in)* — "Compiled with FRUS Explorer" + metadata.

Today the pipeline produces items 3, 5-partially, and the word cloud. That gap list is this program. The editor that authors this artifact must (a) look like the artifact (real document rows, visible structure, live preview), (b) expose every knob at the point of the affected content (read-write inspector), (c) let the user pull documents in without leaving the room (in-editor discovery).

---

## Phase 1 — Editor shell: a place, not a sheet *(1–2 PRs; zero schema/format change)*

The direct answer to the complaint, plus one critical future-proofing fix that must age in the field.

**Work items**
1. **iOS: dedicated screen.** Replace the `.sheet` presentation off `CollectionListView.swift:125–130` with a value-based `navigationDestination` push. Retire the iPhone-single-Form / iPad-two-Forms-in-an-HStack split (`CollectionEditorView.swift:353/:367`) for one adaptive layout: entry list primary; metadata + composition in an `.inspector` on iPad (the app's established iPad pattern), collapsible section on iPhone.
2. **Unify draft semantics: all-live autosave** (A1). Kill the hybrid model (`CollectionEditorView.swift:829` doc comment; Save/Cancel commit path at `:803`) — macOS already autosaves (`MacCollectionManagerView.swift:358`), and CloudKit semantics imply it. One special case: a newly created, still-empty collection is discarded on back. Net code deletion.
3. **Shared `CollectionEntryRowModel`.** Extract `MacEntryRow`'s async loading (`MacCollectionManagerView.swift:728`, headers via `CrossReferenceStore.documentHeaders` `:361`) into one row model (header, date, volume title, citation, note count) consumed by both platforms' rows; iOS `EntryRow` (`CollectionEditorView.swift:1069`) stops showing bare `documentId`/`volumeId` (`:1096/:1113`). First dual-manager convergence — build shared, style per-platform; pays down every later phase.
4. **Sort-by-Date unification.** One helper on the row model: per-document `date_iso` with volume fallback (mac `:687`) replaces the iOS volume-only sort (`:786`).
5. **macOS: composition inline.** Replace the 380×440 popover (`MacCollectionManagerView.swift:451`) with an inline collapsible group / trailing inspector; `CollectionCompositionRows` (`:2763`) reused unchanged.
6. **Unknown-kind hardening (ship now).** Change the `entryKind` fallback (`Models/Collection.swift:283`) from `?? .document` to an `.unrecognized` presentation: an inert "Unsupported entry — update FRUS Explorer" row, skipped by resolve (resolver also defensively skips document items with empty `volumeId`). New entry kinds arrive in Phases 5–6; without this guard, an entry kind synced from a newer build renders on older builds as a junk document row and resolves into a junk export item. The guard only protects devices that have installed it, so it must ship as early as possible.
7. **Housekeeping:** `fileImporter` accepts `.data` instead of the declared `.fruscollection` UTI — fix both call sites (`CollectionListView.swift:132`, `MacCollectionManagerView.swift:86`). Split the 2,836-line `CollectionEditorView.swift` into editor / `ExportSheetView` / inspector / composition rows / `AddByTagSheet` files, or every later phase pays merge tax.

**Reused:** `MacEntryRow` internals, `CollectionCompositionRows`, `CollectionEntryInspector`, existing navigation and inspector patterns. **Built:** navigation restructure, shared row model, inert-kind presentation, file split.

**Risks.** Cancel behavior change (release notes); iPad layout regressions from retiring the HStack hack (audit `.inspector` and Stage Manager scene entry points); the file split is mechanical but touches everything — do it first inside the PR.

**Sequencing rationale.** Cheapest phase, most direct response to the complaint, zero model/format risk — and item 6 has a hard external clock.

---

## Phase 2 — One resolver + live preview: the program's spine *(2–3 PRs)*

**PR 2a — `CollectionContentResolver`.** Extract `ExportSheetView.resolveItems()` (`CollectionEditorView.swift:1996`) and its ~200-line near-clone `resolveSmartDocuments` (`:2316`) into one new `@MainActor` service (`Collections/CollectionContentResolver.swift`) whose single job is `Collection → [CollectionExportItem]`:
- Unify the smart path — it currently drops per-entry overrides, notes, highlights, and source notes (`:2413–:2427`); after this, smart collections resolve identically (composition-level only, since synthetic entries carry no overrides — document that).
- **Render-model cache:** reuse the existing `DocumentASTCache` actor (`TEI/DocumentASTCache.swift:33`), keyed `(volumeId, documentId)`, validated by `ASTToRenderNodeConverter.renderingVersion(for:)` (`ASTToRenderNodeConverter.swift:61`) — the fresh-parser-per-document cost (`:2044`) is paid once per session, not per export; the same cached model later feeds excerpt slicing and the inspector.
- `prepareVolumes()` (`:1925`) and on-demand summary generation (`:2188`) move in behind an explicit `purpose: .export | .preview` parameter. **Preview never auto-downloads and never triggers AI generation** — it renders placeholder cards instead.
- Per-item incremental API (`resolveItem(entry)`) for the preview's refresh path.
- Golden-file test: a pre-program fixture collection resolves to byte-identical `[CollectionExportItem]` before/after extraction.

**PR 2b — Shared HTML item renderer + preview pane.** Factor the per-item HTML `switch` out of `HTMLCollectionExporter` (private `buildHTML`, `HTMLCollectionExporter.swift:76`) into `CollectionItemHTMLRenderer` (uses `FRUSRenderNodeHTMLSerializer`, `HTMLTemplate.documentCSS`, `FRUSTheme.cssVariables`, `injectHighlights`, the existing per-document `anchorId` `:424`). HTML export becomes a thin file-writing wrapper; the preview consumes the same function — **preview and HTML export cannot drift by construction.** Preview view: `WKWebView` per the `FRUSDocumentWebView`/`FRUSWebViewConfiguration` pattern. iPhone: Outline|Preview segmented toggle; iPad + macOS: side-by-side split. Debounce ~1s; cap initial render (~25 documents + "Render all"); un-downloaded volumes render as citation cards with a download affordance.

**PR 2c (optional within phase) — incremental refresh + scroll-sync** (A3). Per-entry re-resolve on edit; row-tap → preview scrolls to anchor; preview-tap → row selects.

Also in this phase: an **exporter contract test** asserting every exporter (`PDFCollectionExporter`, `HTMLCollectionExporter`, `DocxCollectionExporter`, `ZoteroCollectionExporter`, `BibTeXCollectionExporter`) handles every `CollectionExportItem` case (Zotero/BibTeX legitimately skip non-documents) — extended each time a case is added in Phases 4–6. Do **not** pre-add speculative cases: Swift's exhaustive switches make each future case addition compiler-guided.

**Reused:** the entire TEI render pipeline, HTML serializer, theme CSS, `DocumentASTCache`, web-view infrastructure. **Built:** the resolver, the shared item renderer, the preview view, the contract test.

**Risks.** Performance on 100+-document collections (cache + cap + lazy resolution); WKWebView memory on iPhone (recycle); resolver extraction touches all export formats — the golden-file test is the mitigation. The preview is a **reader proof, not a page proof** — PDF pagination and DOCX styling will differ; label it honestly (A2).

**Sequencing rationale.** The enabling spine. Every later phase adds *content types*, and each must appear in preview and all exporters; with one resolver and one shared item renderer, each new type is one resolver addition + one HTML function + PDF/DOCX switch arms instead of five divergent code paths. Doing preview before content depth is the most important sequencing decision in the program — Phases 4–6 then ship with visible feedback for free.

---

## Phase 3 — In-editor discovery: build the set without leaving the room *(1–2 PRs; zero schema/format change)*

**Work items**
1. **`CollectionAddDocumentsSheet`** (shared core, platform shells), opened from the Documents section (beside today's Add-by-Tag entry points, `CollectionEditorView.swift:682` / mac toolbar `:590`), four tabs:
   - **Search** — a slim results list backed by `SearchService` (FTS5/BM25); multi-select → append entries. Reuse `SearchView`'s row rendering, not the whole view.
   - **Browse** — flat volume → document drill-down via `ManifestStore` + `CrossReferenceStore.documentHeaders`. Two levels suffice; do not rebuild the Browser.
   - **Paste citations** — the Citation module's parser + lookup engine turns pasted footnotes, history.state.gov URLs, or a bibliography into resolved references, with per-line resolution shown and confirmed before insert. A genuinely differentiating scholar feature at near-zero infra cost.
   - **By tag** — the existing `AddByTagSheet` (`:1202`) as a tab, generalized to `DocumentTagAssignment` (not just note-carried tags).
2. **Multi-select everywhere in the sheet;** insertion after the current selection (or list end). Upgraded to section-aware placement in Phase 4.
3. **Un-downloaded volumes are addable** (manifest/index-only); rows show the Phase-2 "not downloaded" badge with the existing `prepareVolumes` download affordance.

**Reused:** `SearchService`, `ManifestStore`, Citation parser/lookup, `CrossReferenceStore`, `AddByTagSheet`, `DownloadManager`. **Built:** the tabbed sheet and insertion logic.

**Risks.** Citation-parse ambiguity UX (show what each line resolved to; coverage varies by era); scope creep into a second Search tab — keep it insert-focused.

**Sequencing rationale.** Ahead of content depth deliberately: it removes the assembly bottleneck for *every* user, has zero model/format impact, and ships while the owner resolves the Phase 4–6 decisions — decision latency is a resource for a solo maintainer. Phases 1–3 (~5 PRs) deliver the entire "this feels like an authoring tool" transformation with no schema risk.

---

## Phase 4 — The publication frame: front matter, nested sections, format v2 *(2–3 PRs)*

The biggest visible jump in artifact quality: the export starts reading as a publication instead of a printout.

**Work items**
1. **Front matter on `Collection`** (all additive, defaulted, CloudKit-safe): `subtitle: String?`, `authorLine: String?` (default from the active `Project` name, editable), `introductionText: String?` + `introductionRichText: Data?` (the same plain-projection pattern as `CollectionEntry.text`/`richText`; editor = the existing `RichTextEditor`), `includeColophon: Bool = false` (default off so the byte-identical fixture regression holds). `note` stays the one-line title-page description.
2. **Nested sections — D1 expensive, encoded safely:** `CollectionEntry.level: Int = 1`, meaningful on `heading` entries only. The list stays flat with **global `sortOrder` retained** — explicitly *not* parent pointers, because old fielded builds reindex `sortOrder` globally 0..n on every move; re-scoping that field's semantics would corrupt structure across mixed-build iCloud accounts. The tree is derived by a new pure type, **`CollectionOutline`** (single-linearizer discipline): one function `[CollectionEntry] → [OutlineItem(entry, depth)]` consumed by editor lists, resolver, exporters, and serializer — nothing else re-derives structure. Extend the body-depth cascade (`CollectionBodyDepth.resolve`, `CollectionExporter.swift:84`) from "nearest preceding heading" to "nearest ancestor heading by level" — **D5 per-section overrides fall out for free.** Normalize pass after every mutation (no orphaned levels); defensive clamp at resolve.
3. **Editor outline interaction (both platforms):** indent/outdent on heading rows, collapse/expand (view state, not persisted), **move-section-as-a-unit** (contiguous range under a heading at its level, moved and reindexed), section context menu (rename; delete heading vs heading+contents; set section body depth). Custom move handling: stock `onMove` doesn't understand cross-section drops — budget real time here; it is the phase's hard part.
4. **Exporter frame:** `.heading` gains `level:` (the one breaking enum edit; compile-caught, contract test extended); title page (extend `PDFCollectionExporter`'s cover, HTML header block, DOCX title paragraphs); introduction as the first prose flow; nested ToC (PDF indentation, DOCX field-code `\o "1-3"` with Heading1–3 style mapping, HTML nested `<nav>`); colophon.
5. **`.fruscollection` v2 — the program's one format bump** (see Migration): `minimumReaderVersion`, tolerant-reader rule, front-matter block, `Entry.level`, write-minimum behavior.

**Reused:** `RichTextEditor` + `CollectionProse` RTF bridge, PDF cover code, `tocLabel(style:)`, existing `onMove` machinery. **Built:** `CollectionOutline` + section-move logic, title-page rendering ×3, nested ToC ×3, v2 serializer work.

**Risks.** Level invariants under CloudKit merge (normalize + clamp; degradation is a flattened heading, never corruption); DOCX ToC style mapping is fiddly; first format bump — the policy must be right here (see Migration).

**Sequencing rationale.** Highest visible-quality-per-effort phase; needs only Phase 2. Landing the outline and v2 here gives Phases 5–6 rails: section-aware insertion, section-level overrides, placeable apparatus, and optional keys on an already-bumped format.

---

## Phase 5 — The annotated document: inspector, headnotes, excerpts *(2–3 PRs, sliced by feature, not by layer)*

**Work items**
1. **Footnote tri-state fix** (prior-rework Phase-1 leftover): `includeFootnotes: Bool` + `includeSourceNote: Bool` on `Collection`, lazily derived from `footnoteStyle` on first read (`all`→(true,false), `sourceNoteOnly`→(false,true), `none`→(false,false)); keep writing `footnoteStyle` for old readers and old devices. "All footnotes AND the source note" becomes expressible; the resolver stops gating `sourceNoteText` on `.sourceNoteOnly` (`:2137` logic, by then in `CollectionContentResolver`).
2. **Headnotes:** `includeHeadnote: Bool = false` + `headnoteSummaryId: UUID?` on `CollectionEntry` — a chosen `GeneratedSummary` rendered as an italic abstract *above* a full body, versus today's summary-instead-of-body. Also fixes the inspector's "first non-empty summary" pick (`:2731`) with prompt-aware selection.
3. **Excerpt entries — D3 expensive, hybridized:** new `CollectionEntryKind.excerpt`. The always-works baseline is a **frozen verbatim quotation**: `text` = the passage (copied from `DocumentHighlight.selectedText` or a live selection), `documentId`/`volumeId` = provenance for the auto-citation; renders as a styled block quote + source line in all three rich formats (one new `CollectionExportItem.excerpt(...)` case; Zotero/BibTeX skip). *Additionally* store `excerptStart/excerptEnd: Int?` + `excerptRenderingVersion: String?` copied from the source highlight at creation — free to capture, keeps precision rendering (A9) a rendering-only decision later. Creation paths: (a) bulk "Add highlighted passages" generator from `DocumentHighlight` rows; (b) document-view text-selection action via the existing `CollectionPickerSheetView` (`DocumentView.swift:2651`); (c) per-highlight "Insert as excerpt" in the inspector. Serialization carries **content + color + provenance, never device-local highlight UUIDs**. Requires Phase 1's inert-fallback guard to be broadly fielded first.
4. **Read-write inspector.** `CollectionEntryInspector` (`:2583`) becomes the per-entry control surface: note selection (exists), highlights override, per-highlight selection, headnote pick, source-note toggle, summary-prompt choice, related-documents toggle, excerpt management. All overrides are optional-`nil`-means-inherit fields on `CollectionEntry` (`applyHighlightsOverride`, `includeNotesOverride`, `includeSourceNoteOverride`, `summaryPromptIdOverride: UUID?`, `selectedHighlightIds: [UUID]`), resolved in exactly one place — the resolver, via the outline cascade. A heading-entry inspector variant carries section-level overrides (D5, nearly free after Phase 4). Anything not yet exportable keeps an honest "not yet exportable" caption.
5. **Related-documents line** (the per-document half of D4): `includeRelatedDocuments: Bool?` — outbound `cross_references` edges rendered as a "See also:" citation line.

**Reused:** `DocumentHighlight` offsets/snapshot/renderingVersion (do not invent a second anchoring scheme), `GeneratedSummary`/`SummarizationService`, `CrossReferenceStore`, the inspector shell, the Phase-2 cache. **Built:** excerpt entry + item case + renderers ×3, inspector edit affordances ×2 platforms, override cascade in the resolver.

**Risks.** Option-matrix growth (contain it: every override optional-inherit, inspector-only, resolved in one place); this phase touches resolver + three exporters + preview + both inspectors — slice PRs by feature (footnotes+headnotes / excerpts / overrides+related-docs); mixed-build sync of the new kind (mitigated by Phase 1's guard + release sequencing).

**Sequencing rationale.** After the book has its frame, deepen each page. Excerpts are the single biggest scholarly-expressiveness win in the program — a quotation-driven argument becomes possible — and they convert the highlight workflow historians already use directly into the artifact.

---

## Phase 6 — Generated apparatus: the app's indexes become the book's apparatus *(2–3 PRs, one thin slice each)*

**Work items**
1. **One item case, one entry kind.** `CollectionExportItem.generated(CollectionGeneratedBlock)` where the payload is a **pre-resolved structured value** (title + rows + optional links) so each exporter adds exactly one switch arm total, styling rows per format. Blocks are **placeable entries** (A11): `CollectionEntryKind.generated` + `generatedBlockType: String?` (`bibliography | chronology | archivalSources | personsIndex | thematicIndex`) so the *user* decides placement — chronology as front matter, persons in back matter, per §0. Inserted from an "Apparatus" menu with sensible default positions; moved/deleted like any entry; flows through outline, ToC, and preview naturally. Live counts on rows ("Persons (34)").
2. **PR 6a — Bibliography + Chronology.** Bibliography: dedupe + sort the already-resolved `CollectionExportDocument.citation`/`zoteroItem` set — near-free. Chronology: `document_dates.date_iso` per entry → date-ordered table (the data `DocumentTimelineView` already displays; finally exported).
3. **PR 6b — Sources & Archives + Persons index.** Sources: `volume_sources` + `document_sources` + bundled `volume-sources-index.json` NAIDs (`SourceExplorer/VolumeSourcesIndex.swift` — the PR #114–#117 harvest payoff) → each archival collection used, with NARA hyperlinks in HTML/PDF and DOCX hyperlink relationships. Persons: `person_mentions`/`persons` restricted to the collection's documents, rolled up via `PersonAuthorityIndex` + `PersonClusterOverride` — **reuse the People-browser resolution path, do not reimplement** — name + description + "Documents 3, 7, 12" references, thresholded (mentioned in ≥N docs, no knob initially).
4. **PR 6c — Thematic index + polish.** `UserTag`/`DocumentTagAssignment` → tag → document references (fixes "tags reach only Zotero"); Apparatus menu polish; preview/exporter refinements.
5. `.fruscollection`: generated entries ride v2 as optional keys under the tolerant-reader rule — no new bump.

**Reused:** every SQLite table and store prior programs built (person rollup, volume-sources harvest, chronology, citations, tags) — this phase is almost pure connection. **Built:** block resolvers in `CollectionContentResolver`, one renderer arm ×3 + preview, Apparatus UI ×2 platforms.

**Risks.** Rollup correctness at collection scale (reuse the existing path); batched SQLite reads for big collections (pattern exists in `IndexingPipeline`); DOCX hyperlink plumbing in the inline ZIP writer.

**Sequencing rationale.** High product value, strictly additive, zero new user input — every collection ever made gains apparatus by inserting a block. It sells best once the frame (Phase 4) exists, and each PR slice is independently shippable or droppable.

---

## Standing gates (every PR, every phase)

- `String(localized:)` for all new UI strings; doc comments; Apache headers; `Version history` bumps on `Collection`, `CollectionEntry`, exporters, and touched views; `CodingStandardsAuditTests` green.
- **Dual-manager parity** verified per work item (`CollectionEditorView` + `MacCollectionManagerView`) — build shared, style per-platform.
- Contract test extended per new `CollectionExportItem` case; additive-migration load test per model change; **byte-identical fixture regression** (a pre-program collection resolves and exports identically until the user opts into new features).
- **Docs rider per phase** + a closing consolidated docs pass (Docs/ manuals, TestFlight notes, README, `ResearchGuideView`/`IndexingEducationView`) per the feature-session docs rule.

---

## Explicitly NOT building (and why)

1. **A WYSIWYG page-layout editor or direct editing inside the preview.** The exporters are template-driven with a coherent FRUS-derived design (`FRUSTheme`); a contenteditable↔model bridge is the worst cost/benefit item on the table, and per-user layout control produces worse output than the opinionated template.
2. **Editing or redlining primary-source text.** The product's scholarly credibility rests on untouched TEI; all user voice lives in prose, headnotes, notes, and excerpt *selection*.
3. **`parentEntryId` restructure / a new `Section` `@Model` / a Notion-style block engine.** Parent pointers force re-scoping `sortOrder` to sibling order — re-purposing a synced field whose global-reindex semantics are baked into fielded builds; a block engine rebuilds the TEI pipeline's job. The level-derived tree delivers D1-expensive without either hazard.
4. **A second excerpt-anchoring scheme** (XPath/TEI-id anchors). The flat-offset + `renderingVersion` + verbatim-snapshot system is proven by highlights; two coordinate systems would be reconciled forever.
5. **Replacing RTF prose** with markdown or archived `AttributedString`, or images in prose. Breaks `.fruscollection` v1 round-trip, the PR-#127 native editor, and three exporter paths. Extend the decoder (lists, links) instead if needed.
6. **Real-time collaboration / CKShare.** CloudKit last-write-wins + `.fruscollection` hand-off is the collaboration story; shared-zone semantics are hazardous under the app's CloudKit constraints.
7. **Cross-reference graph images in exports.** The related-documents line + apparatus block carry the information in the artifact's native idiom; the interactive graph stays in-app (Session 161 contract preserved).
8. **New export formats (EPUB/LaTeX/InDesign)** — each triples the cost of every content type forever; DOCX is the publisher on-ramp. And **no print-to-PDF-from-HTML exporter rewrite** — it forfeits CoreText pagination and native DOCX structure; the `[CollectionExportItem]` contract is the discipline instead.
9. **A theming/templates engine.** House style is a feature; if ever demanded, 2–3 presets as an `ExportOptions` enum.
10. **AI-generated editorial voice** (introductions, provenance essays). Summarizing documents is established; generating the researcher's own voice is a different product promise. Flagged only.
11. **A mass data-migration pass** writing levels/structure onto existing collections — defaults make it unnecessary; structure is written only when the user edits it.
12. **Rebuilding the Browser inside the add-documents sheet** — a flat two-level list suffices.

---

## Migration & compatibility

**SwiftData/CloudKit.** Every field in every phase is additive and optional-or-defaulted (no unique constraints, no cascades; `.nullify` + manual cleanup stays the pattern). Every default reproduces current behavior exactly: `level = 1`, `includeHeadnote = false`, all overrides `nil` = inherit, all apparatus opt-in, `includeColophon = false`. `footnoteStyle` is derived-not-destroyed: the new Bool pair computes lazily from the old raw value, and the old field keeps being written — **never delete or re-purpose a synced field** (this rule is also why `sortOrder` stays global).

**Mixed app versions on one iCloud account (the real hazard).** Old builds map unknown `kind` values to `.document` with empty ids (`Collection.swift:283`) — junk rows and junk export items. Mitigations, in order: (1) Phase 1 ships the inert `.unrecognized` fallback, ending this bug class with the next update; (2) release sequencing — Phases 1–3 (no new kinds) reach users broadly before Phase 5–6 kinds can appear in synced data; (3) the resolver defensively skips document items with empty `volumeId` forever.

**`.fruscollection` versioning — one bump, three mechanisms.** Current state: v1, decode hard-rejects `formatVersion > 1` (`NativeCollectionFormat.swift:154`); nothing shipped can change already-fielded readers, so the strategy optimizes both directions:
1. **One bump to v2, at Phase 4** (the first serialized feature). v2 adds the front-matter block, `Entry.level`, and — as they land — excerpt/generated entry payloads, overrides, and footnote flags as optional keys.
2. **Write-minimum (protects old readers):** the serializer emits `formatVersion: 1` whenever the collection uses no v2 feature — computed from content, not hardcoded — so already-shipped apps keep opening files for as long as authors haven't used new features.
3. **`minimumReaderVersion` + tolerant reader (protects future readers):** v2 files carry `minimumReaderVersion` (defaulted 1 on decode when absent); v2-aware readers check `minimumReaderVersion <= currentVersion` instead of `formatVersion`, and decode unknown entry kinds/keys by **skip-with-importer-warning, never misdecode**. Raise `minimumReaderVersion` only when ignoring a field would *corrupt meaning*, not merely degrade it (ignored `level` → flat headings: degraded, acceptable; an ignored introduction: degraded, warn on import; unrepresentable entry semantics: raise).
4. **Excerpts serialize content + color + provenance, never device-local highlight UUIDs**, so files survive transfer to devices without the source highlights.
5. **Tests per version written:** round-trip invariant (export → import → export byte-identical under the sorted-keys encoder); forward-compat decode (vN reader on a v(N+1) fixture with extra keys); a checked-in v1 fixture import test; import path + `apply(_:into:)` reconstruction updated with every schema addition.

---

## Decision points (A1–A12, owner resolves at implementation time)

| # | Decision | Cheap option | Expensive option | Lean |
|---|----------|--------------|------------------|------|
| **A1** | Draft semantics (Phase 1) | All-live autosave (deletes code; matches macOS + CloudKit) | Snapshot-and-rollback draft (fights SwiftData + sync merge) | Cheap |
| **A2** | Preview fidelity (Phase 2) | Static HTML — "the HTML export, live"; a reader proof, not a page proof | Paginated PDF-accurate preview via `PDFCollectionExporter` + PDFKit (possible later without new architecture) | Cheap |
| **A3** | Scroll-sync (Phase 2) | Read-only scrolling | Bidirectional row↔preview sync (modest — anchors exist) | Either; fine as fast-follow |
| **A4** | Duplicates on add (Phase 3) | Allow with a badge (a document legitimately appears in two sections) | Dedupe prompts | Cheap |
| **A5** | Drag-and-drop add (Phase 3) | Skip | `Transferable` document reference for macOS/iPad cross-window drops | Defer |
| **A6** | Nesting depth (Phase 4) | Cap at 2 levels | Arbitrary | Cap at 3, UI-enforced only, so the model never migrates |
| **A7** | Introduction editor (Phase 4) | `RichTextEditor` as-is | Structured front-matter blocks (epigraph, acknowledgments) | Cheap |
| **A8** | Per-highlight selection (Phase 5) | Per-entry all-or-nothing toggle | `selectedHighlightIds` mirroring `selectedNoteIds` | Expensive (genuinely cheap here) |
| **A9** | Excerpt rendering (Phase 5) | Frozen text as quote block (always works) | Precise styled slice of the cached render model when `excerptRenderingVersion` matches; verbatim fallback with staleness marker | Ship cheap; anchors stored either way, flip later |
| **A10** | Related documents (Phase 5) | Targets inside the collection only (bounded, meaningful) | All cross-refs (noisy) | Cheap |
| **A11** | Apparatus placement (Phase 6) | Collection-level toggles at fixed positions | Placeable `generated` entries | Expensive (small delta once entries move/reorder; toggles create a parallel structure system) |
| **A12** | Notes rendering (Phase 5) | Trailing "Researcher's note" block | Numbered editorial footnotes interleaved with FRUS's own, typographically distinguished | Owner call |

---

## Sequencing summary

| # | Phase | PRs | Schema/format impact | Payoff |
|---|-------|-----|----------------------|--------|
| 1 | Editor shell + kind-guard | 1–2 | none (one enum fallback) | The complaint answered; the sync guard starts aging in the field |
| 2 | Resolver + live preview | 2–3 | none | See the product while authoring; one code path for everything after |
| 3 | In-editor discovery | 1–2 | none | Assembly bottleneck removed; ships while owner decisions pend |
| 4 | Publication frame | 2–3 | additive fields + format v2 | Title page, intro, nested sections, nested ToC — a publication, not a printout |
| 5 | Annotated document | 2–3 | additive fields + excerpt kind (rides v2) | Headnotes, excerpts, footnote fix, read-write inspector — scholarly depth per page |
| 6 | Generated apparatus | 2–3 | additive kind + item case (rides v2) | Bibliography, chronology, sources, persons, thematic index — years of index-building become back matter |

Fix the room (1), install the mirror (2), fill the shelves fast (3), give the book its shape (4), deepen each page (5), let the indexes write the apparatus (6). Phases 1–3 carry zero schema risk and complete the "authoring tool" transformation; Phases 4–6 each ship a visible jump in the exported artifact, are independently re-prioritizable as owner decisions land, and leave every existing collection and every existing `.fruscollection` file working unmodified.

**Status:** scoped 2026-07-02; no implementation started. Known pre-existing export bug to fix before or alongside Phase 2 (separate task, already spun off): legacy Phase-3b JSON `richText` prose is silently dropped from PDF/DOCX/HTML exports.
