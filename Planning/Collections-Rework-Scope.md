# Collections Rework — Scope

**Goal.** Realign the Collections feature to a clean split:

- **Manager = the editorial place** where the user determines a collection's *content*, with access to the full range of document-level data (volume-derived **and** user-generated) and flexibility to compose it into a meaningful product.
- **Export = the sharing place**, offering only the tools needed to get that content out of the app (format + destination + genuinely format-specific presentation).

This document scopes the whole arc. It marks each piece **Cheap / Moderate / Expensive**, and collects the expensive "push further" opportunities into a **Decision Points** section to resolve at implementation time.

---

## Current state (baseline)

- **Model.** `Collection` = name + one `note` + `projectIds` + optional `savedSearchId` (smart collection) + ordered `CollectionEntry` list. `CollectionEntry` = `documentId`/`volumeId` + `sortOrder` + attached research-note ids. A collection is a **flat ordered list of document references with per-entry note links**. Nothing more.
- **Manager** (`CollectionEditorView` iOS, `MacCollectionManagerView` macOS). Curates: name/note, add/remove/reorder, add-by-tag, sort-by-date, per-entry note attach, smart-collection link. Surfaces almost no document data while editing (iOS shows bare ids; macOS adds an async header). Highlights, tags, summaries, source notes, cross-refs are **absent** from the editing surface.
- **Export** (`ExportSheetView`, shared by both platforms). One dialog conflates **format** (1 sharing decision) with **six content decisions**: body depth (full / summary / index), summary prompt, footnote style, ToC label style, apply-highlights, include-notes, include-word-cloud. These are re-decided every export and **never persisted**.
- **Exporter contract.** `CollectionExporter.export(metadata, documents: [CollectionExportDocument], options)` → 4 implementations (PDF/HTML/DOCX rich; Zotero RIS metadata-only). `CollectionExportDocument` already carries body/renderModel/notes/citation/header/dateline/summary/highlights/sourceNote/zoteroItem. **Only `CollectionEditorView` constructs it** and calls export.
- **Infra facts that set the cost boundaries.**
  - Lightweight additive SwiftData migration only (no `VersionedSchema`). New optional/defaulted fields are cheap & CloudKit-safe.
  - Reusing `CollectionEntry` with a `kind` discriminator avoids registering a new `@Model` type.
  - Exporters already render headings and note callouts, and support markdown in notes — so heading/prose *rendering* is reuse, not new work.
  - Pipeline already serves per-document body, source note, dates, related documents, header; citation via formatter. Persons/cross-refs are **not** wired into any exporter.

---

## Architectural spine (two moves the whole arc hangs off)

**Move A — Persist composition on the model.** Promote the content decisions from the ephemeral export sheet to saved state: collection-wide defaults on `Collection`, per-entry overrides on `CollectionEntry`. Content becomes stable, inspectable, and re-exportable to multiple formats without re-deciding.

**Move B — Heterogeneous export items.** Refactor the exporter contract from a flat `[CollectionExportDocument]` to `[CollectionExportItem]`:

```
enum CollectionExportItem {
    case document(CollectionExportDocument)
    case heading(String)      // section title
    case prose(String)        // user commentary (markdown)
}
```

Blast radius: the **one** resolve site + each exporter's iteration loop (a `switch`). Do this refactor in **Phase 1** even while only `.document` cases exist, so Phase 3 only *adds cases* rather than re-touching all four exporters.

Everything below builds on A and B.

---

## Phase 1 — Move the boundary; persist composition  *(Cheap–Moderate; highest ROI)*

**What changes**

- **Model (additive, CloudKit-safe).**
  - `Collection`: `defaultBodyDepth: String = "full"`, `includeFootnotes: Bool = true`, `includeSourceNote: Bool = false`, `includeNotes: Bool = true`, `applyHighlights: Bool = false`, `tocStyle: String = "citation"`, `includeWordCloud: Bool = false`, `summaryPromptId: UUID?`.
  - `CollectionEntry`: `bodyDepthOverride: String?` (nil ⇒ use collection default).
  - **Fix the footnote tri-state:** replace the mutually-exclusive `CollectionFootnoteStyle` (none / source-note-only / all) with two independent flags — `includeFootnotes` and `includeSourceNote` — so "all footnotes **and** the source note" becomes expressible.
- **Resolve site** (`CollectionEditorView` resolve logic): read persisted composition instead of sheet state; compute each entry's *effective* body depth (`bodyDepthOverride ?? collection.defaultBodyDepth`).
- **Export sheet:** delete the six content controls. It becomes **format + destination** (+ the summary-prompt picker only if it isn't moved to the manager). Net: the sheet *shrinks* — a deletion, not new UI.
- **Manager:** add a **Composition** section (collection-level defaults) and a per-entry **body-depth** control (full / summary / citation-only), so a single collection can mix full documents, summaries, and citation-only entries — the first real step toward "meaningful products."

**Cost.** Low–moderate: additive migration + relocating existing logic + shrinking a sheet. No new infra. **Do Move B here too** (contract refactor with only `.document` cases).

---

## Phase 2 — Editorial data surface (see what you're composing)  *(Moderate; UI-heavy, no new infra)*

**What changes**

- **Entry inspector** (expand/detail on an entry) surfacing, for that document: citation, header, dateline, date; and the user's own data — **research notes** (already), **highlights** (count/preview), **user tags**, **AI summary** (if present), **source note**, **cross-references** (count/list). Each shown with an include/exclude affordance where it can flow to export.
- **Reuse existing stores** — `ResearchNote`, `DocumentHighlight`, `UserTag`/`DocumentTagAssignment`, `GeneratedSummary`, and `IndexingPipeline` (source note, related documents, dates, header). No new data plumbing.
- **iOS parity:** bring iOS entry rows up to macOS (headers) and add the inspector, so the editorial center is equally usable on both platforms.

**Cost.** Moderate but purely UI — all data is already queryable. Delivers the "full range of document-level data" objective.

**Decision-linked:** whether cross-refs/persons are merely *visible* here (cheap) or become *includable in the exported product* (needs Move B item types + new resolve/render — see Decision Points **D3**, **D4**).

---

## Phase 3 — Compositional ceiling  *(Cheap core via existing infra; expensive extensions flagged)*

**Cheap core (what the current infra supports).** Turn a collection from a flat list into an **authored, sectioned reader with interleaved commentary**:

- **Model:** add `CollectionEntry.kind: String = "document"` (`document | heading | prose`) and reuse a `text: String?` field for heading titles / prose bodies. One model + discriminator ⇒ no new `@Model` type, CloudKit-safe.
- **Exporters:** with Move B already done, add the `.heading` and `.prose` cases — `heading` reuses existing heading rendering; `prose` reuses the markdown note-callout path; Zotero skips non-documents (or emits prose as standalone notes).
- **Manager:** "Add section heading" / "Add note block" actions; a mixed-type reorderable list.
- **ToC:** headings become ToC sections; documents group one level under the preceding heading (flat 1-level grouping — cheap).

**Result of the cheap core:** an annotated reader / briefing / syllabus — a large expressiveness jump using existing render paths.

**Expensive extensions — flagged for decision (see Decision Points):** nested sections (**D1**), rich-text vs markdown prose (**D2**), per-document excerpting (**D3**), cross-ref/person inclusion as first-class elements (**D4**), per-section composition overrides (**D5**).

**Cost.** Core is Moderate (model discriminator + 4 small exporter switch-arms + manager actions). Extensions range Moderate→Expensive.

---

## Phase 4 — Sharing depth (export as pure sharing)  *(Cheap core; medium options flagged)*

**Cheap core.** With Phase 1 done, the export sheet is already just **format + destination**. Add only *genuinely format-specific* presentation: PDF page size/margins; HTML single-file vs. asset bundle. That's it — everything about *what's in the product* now lives in the manager.

**Options — flagged for decision:**

- **D6 — Unify the two Zotero paths.** Today "Zotero RIS" (a format) and "Send to Zotero Library" (a Web-API button) compete in one sheet with different tag/note behavior. Collapse into one "Send to Zotero" with a clear connected-account vs. RIS-fallback story.
- **D7 — Non-Zotero citation export.** Add an RIS/BibTeX *file* for other reference managers, reusing the Citation module's existing RIS/BibTeX generators. Cheap–moderate.
- **Destinations polish.** Explicit Print / Mail / Files affordances (iOS share sheet already covers most). Cheap; low priority.
- **D8 — Smart-collection snapshot.** Today membership resolves *at export* from a saved search, so content isn't inspectable in the manager. Option: materialize resolved entries into the manager with a "Refresh from search" action (keep dynamic, snapshot, or offer both).

---

## Sequencing & dependencies

1. **Phase 1** first — it establishes both spine moves (persisted composition + the item-list contract) and immediately realizes the boundary split with mostly relocation.
2. **Phase 2** next — makes the manager a real editorial surface; independent of 3/4.
3. **Phase 3 core** — depends on Move B (from Phase 1); adds the discriminator + exporter cases.
4. **Phase 4 core** — mostly falls out of Phase 1; do the flagged options as decisions land.

Expensive extensions (D1–D8) are slotted where they attach but are **not** on the critical path.

---

## Cross-cutting constraints (all phases)

- **CloudKit:** every new field optional-or-defaulted; no unique constraints; no cascade (manual entry cleanup already the pattern).
- **Coding standards:** `String(localized:)` for all new UI strings; doc comments on new/changed types & members; Apache headers; bump each model/exporter/view `Version history`. `CodingStandardsAuditTests` gate this.
- **Dual managers:** every manager change lands on **both** `CollectionEditorView` (iOS) and `MacCollectionManagerView` (macOS).
- **Tests:** additive-migration load test; a contract test that each exporter handles `.heading`/`.prose` items; a resolve test that per-entry `bodyDepthOverride` beats the collection default.

---

## Decision Points (resolve at implementation time)

| # | Decision | Cheap option | Expensive option |
|---|----------|--------------|------------------|
| **D1** | Section nesting | Flat 1-level headings (ToC groups docs under the preceding heading) | Multi-level sub-sections (recursive render + ToC depth) |
| **D2** | Prose block richness | Markdown (reuse existing markdown rendering) | Rich-text / WYSIWYG editor |
| **D3** | Document excerpting | Whole-body only (+ highlight annotation) | Include selected passages / highlight-excerpts (new passage model + render) |
| **D4** | Cross-refs / persons in export | Visible in inspector only (Phase 2) | First-class includable elements (new resolve + render + item type) |
| **D5** | Per-section composition | Per-entry overrides only | Section-level body-depth/inclusion overrides |
| **D6** | Zotero paths | Leave as two | Unify into one "Send to Zotero" |
| **D7** | Non-Zotero citation export | Skip (Zotero only) | RIS/BibTeX file reusing Citation module |
| **D8** | Smart collections | Keep dynamic-at-export | Snapshot into manager (inspectable/curatable) + refresh |

*Recommendation when we implement:* take the cheap option on D1/D2/D3 first (they deliver most of "meaningful products" for little cost), and treat D4/D5/D8 as the highest-value expensive follow-ups.
