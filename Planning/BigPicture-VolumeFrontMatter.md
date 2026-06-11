// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# Volume Front Matter — First-Class Reading Experience

**Status:** ✅ Implemented
**Original priority:** Medium (near-term backlog)
**Original estimate:** 3–5 sessions

---

## Implementation Summary (Session 2026-06-10 update)

All five phases below shipped during Session 2026-06-08. However, the parser
keyed front/back-matter detection on literal `type` attribute values
(`type="preface"`, `type="editorialNote"`, `type="sources"`, …) that exist
**only in this app's own test fixtures**. The published corpus actually
encodes:

- Front/back matter sections as `<div type="section" subtype="…" xml:id="…">`
- Editorial notes as `<div type="document" subtype="editorial-note">`

On real downloaded volumes this meant the Browser's "Front Matter" row was
dead, editorial notes were never detected, `volume_sources` stayed empty, and
the "Front matter" search scope was a no-op on both platforms — i.e. Phases
1, 3, and 4 *looked* done but didn't actually work outside the test suite.

Commit `3fb7f17` ("Teach corpus browser the real TEI vocabulary: front/back
matter now navigable", Session 2026-06-10) fixed the vocabulary mismatch:

- `VolumeStructureParserDelegate.structuralKind(type:subtype:xmlId:)` resolves
  the *effective* section kind from `type`/`subtype`/`xml:id`, covering both
  the real encoding and the legacy fixture vocabulary.
- Unknown wrapper `<div>`s now push a *transparent frame* whose children
  bubble to the parent, instead of detaching `<front>`'s subsections (every
  unmatched `</div>` previously popped the `<front>` frame itself).
- `currentDateIndexVersion` 6 → 7 forces a full re-parse so the corrected
  parse output (editorial flags, front-matter quasi-documents, volume
  structures, sources) repopulates on existing installs.
- A new `RealCorpusEncodingTests` suite (in
  `FRUSExplorerTests/IndexingPipelineTests.swift`) builds fixtures in the
  **real** encoding so this class of regression can no longer pass CI.

Verified against nine real volumes spanning 1861–1988; zero unknown `type`
values remain. 708/708 app tests pass.

The sections below are kept for reference but annotated with what actually
shipped and where it diverges from the original plan.

---

## Problem Statement

FRUS volumes contain substantial scholarly apparatus in their `<front>` matter:

- **Preface** — provenance, declassification notes, series context
- **Prefatory Note** — scope, methodology, source selection criteria
- **Editorial Note** — how documents were selected and edited
- **Sources and Abbreviations** — list of all archive sources cited
- **Persons** — list of principals (name, title, dates of service)
- **Abbreviations** — acronyms and short-forms used throughout the volume
- **Glossary** — specialized terms (especially for volumes with non-English sources)
- **Errata** — corrections to earlier volumes

**Resolved.** The Browser now surfaces a "Front Matter" group (and a "Back
Matter" group) above/below the document list on both platforms; Persons and
Sources route to dedicated structured views; preface / prefatory note /
editorial note / press release / volume summary / about-the-series prose is
indexed and searchable via a "Front matter" search scope; and in-document
abbreviations link to glossary definitions via a tap. See "Implementation
Notes by Phase" below.

---

## Goals

1. ✅ **Discoverable front matter navigation** — every downloaded volume's
   front matter appears as a "Front Matter" group (and back matter as a "Back
   Matter" group) before/after the document list, on both platforms.
2. ✅ **Persons list as structured data** — the front-matter persons list is
   parsed into `PersonEntry` records and shown via `FrontMatterPersonsView`,
   which opens the same `PersonIndexDetailSheet` used by the cross-volume
   Person Index (including a "Find all mentions" cross-corpus search).
3. ◐ **Sources and Abbreviations as structured data** — archival source
   references are parsed into `VolumeSourceEntry` records (`volume_sources`
   table) and shown via `VolumeSourcesView`. The planned in-document
   `<bibl>`-reference long-press cross-link back to this list was not built.
4. ✅ **FTS5 indexing of front matter** — preface/prefatory-note/editorial-note/
   etc. text is indexed with `is_front_matter = 1` and searchable via the
   "Front matter" scope toggle in `SearchFilterView`.
5. ✅ **Glossary and Abbreviations as in-document popover** — `<abbr>` elements
   matching a volume glossary term render as `.glossLink` nodes; tapping opens
   a `glossDetail` sheet with the definition (mirrors the `<gloss ref="…">`
   flow).

---

## TEI Structure Reference

### As originally assumed (fixture-only — never occurs in the published corpus)

```xml
<front>
  <div type="preface">...</div>
  <div type="prefatoryNote">...</div>
  <div type="editorialNote">...</div>
  <div type="sources"><listBibl>...</listBibl></div>
  <div type="persons"><listPerson>...</listPerson></div>
  <div type="terms"><list type="gloss">...</list></div>
</front>
```

### Real corpus encoding (verified against HistoryAtState/frus, 2026-06-10)

```xml
<front>
  <div type="section" subtype="table-of-contents" xml:id="toc">...</div>
  <div type="section" subtype="preface" xml:id="preface">...</div>
  <div type="section" subtype="sources" xml:id="sources">
    <list>
      <item>RG 59, Central Files 1969 POL 1, Lot File 70 D 150</item>
      ...
    </list>
  </div>
  <!-- Persons / Terms & Abbreviations are both subtype="index",
       disambiguated by xml:id -->
  <div type="section" subtype="index" xml:id="terms">
    <list><item xml:id="t_AEC"><term>AEC</term>: Atomic Energy Commission</item>...</list>
  </div>
  <div type="section" subtype="index" xml:id="persons">
    <list><item xml:id="p_kissinger"><persName>Kissinger, Henry A.</persName>, ...</item>...</list>
  </div>
</front>
<body>
  <div type="compilation" xml:id="comp1">
    <div type="document" subtype="editorial-note" xml:id="d1">...</div>
    <div type="document" subtype="historical-document" xml:id="d2">...</div>
  </div>
</body>
<back>
  <div type="section" subtype="errata" xml:id="errata">...</div>
  <div type="section" subtype="index" xml:id="index">...</div> <!-- name index, navigation only -->
</back>
```

`structuralKind(type:subtype:xmlId:)` resolves `subtype="index"` to
`"persons"` or `"terms"` by `xml:id` (`persons`/`persName`/`listofpersons` and
`terms`/`abbreviations`/`listofabbreviations`), and to `"index"` (back-matter
name index — navigation only) for anything else. A bare `type="toc"`
(1861-era volumes) normalises to `"table-of-contents"`.

---

## Implementation Notes by Phase

### Phase 1 — Navigation Surface — ✅ Done

Shipped, but **not** as originally specced — there is no separate
`FrontMatterEntry` struct, `front_matter_sections` table, or
`FrontMatterSectionView`. Instead:

- `VolumeSection` (`FRUSExplorer/Browser/VolumeStructure.swift`) carries the
  section's *effective kind* (`divType`) directly from the structure parser,
  with kind-classification helpers as the single source of truth:
  `frontMatterKinds`, `proseReadableKinds`, `canReadDirectly`, `isPersonsList`,
  `isSourcesList`.
- `VolumeView` (iOS) and the macOS corpus browser (`SupportingViews.swift`)
  split the section list into **Front Matter** / **Contents** / **Back
  Matter** groups, expanding the `<front>`/`<back>` wrapper divs inline.
- Tapping a front-matter row navigates to `CompilationView`, which routes by
  kind: `canReadDirectly` sections show a "Read [Title]" button that opens
  `DocumentView` directly (the parser matches the structural `<div>` by
  `xml:id`); `isPersonsList`/`isSourcesList` route to
  `FrontMatterPersonsView` / `VolumeSourcesView` (Phases 2–3).
- Volumes without front matter degrade gracefully — the "Front Matter" header
  is omitted whenever `extractFrontMatter` returns an empty array.

### Phase 2 — Structured Persons List — ✅ Done

- `PersonsParserDelegate` parses the front-matter persons list into
  `PersonEntry` records, stored in the existing `persons` table (no new
  table).
- `FrontMatterPersonsView` (`FRUSExplorer/Browser/FrontMatterPersonsView.swift`)
  loads `PersonMentionStore.allPersons(forVolumeId:)`, with local search.
  Tapping a row opens `PersonIndexDetailSheet` — the **same** sheet used by
  the cross-volume Person Index — showing name, role/description, and a
  "Find all mentions" cross-corpus search action.
- Difference from plan: there is no separate "Volume context" section in the
  detail sheet distinguishing per-volume role notes from a corpus-wide bio —
  `PersonEntry.description` (the role note from *this* volume's `<front>`
  listing) is shown directly as the sheet's description. Considered
  sufficient; revisit only if a person's role text needs to differ across
  volumes in a way that's confusing as-is.

### Phase 3 — Sources and Abbreviations — ◐ Mostly done

- `SourcesParserDelegate` parses the front-matter sources list — now
  triggering on `subtype`/`xml:id` `"sources"` (not just the legacy
  `type="sources"`/`<listBibl>` fixture encoding) — into `VolumeSourceEntry`
  records (`repository`, `recordGroup`, `lotFile`, `seriesName`, `rawText`),
  stored in `volume_sources`.
- `VolumeSourcesView` (`FRUSExplorer/Browser/VolumeSourcesView.swift`) lists
  them with local search, on both platforms.
- **Not implemented**: the planned cross-reference where a `<bibl>`/source-note
  reference inside a document body long-presses to show the matching
  front-matter source entry. Document source notes are currently rendered as
  plain text (`SourceNoteParser`) with no link back to `volume_sources`.
  Low priority — revisit if researchers ask for it.

### Phase 4 — FTS5 Indexing of Front Matter Text — ✅ Done

- Quasi-document promotion (`TEIParserDelegate.promotableQuasiDocumentKinds`)
  indexes prose front/back-matter sections (preface, prefatory note, errata,
  press release, volume summary, about-the-series, front historical
  documents, etc.) as synthetic `document_cache`/FTS5 rows keyed by the
  section's `xml:id`, with `is_front_matter = 1`. `persons`/`sources`
  (structured views) and `table-of-contents`/`index` (navigation noise) are
  excluded by design.
- `SearchFilterView` has a "Front matter" scope toggle
  (`search.scope.frontMatter`); `SearchResult.isFrontMatter` drives a "Front
  matter" badge in `SearchView`, distinct from the "Editorial Note" badge.
- This phase's plumbing existed since Session 2026-06-08 but was a no-op on
  real volumes until commit `3fb7f17` fixed `is_front_matter` population.

### Phase 5 — Glossary Popovers in Document Body — ✅ Done

- `parseTerms`/`TermsParserDelegate` extract `GlossEntry(ref:term:definition:)`
  records from the front-matter terms/abbreviations list.
- `ASTToRenderNodeConverter.abbrLookup` resolves `<abbr>` elements (no
  `@ref`) whose text matches a glossary term to a `.glossLink` render node,
  identical to explicit `<gloss ref="…">` links.
- `DocumentView`/`DocumentViewModel` wire `onGlossTap` → `selectedGloss` →
  a `.glossDetail(GlossEntry)` sheet showing the term and definition.
- Difference from plan: the trigger is a **tap**, not a long-press —
  consistent with the existing `<gloss>`/person-name link interaction
  pattern elsewhere in `DocumentView`.

---

## Testing Criteria

- [x] Opening a downloaded volume shows a "Front Matter" section above the
      document list on both iOS and macOS (and "Back Matter" below, when
      present)
- [x] Tapping Preface / Prefatory Note / Editorial Note / Press Release /
      Volume Summary / About the Series renders the full TEI text via
      `FRUSDocumentRenderer`
- [x] Persons list shows all front-matter persons entries with role/description
- [x] Tapping a person opens `PersonIndexDetailSheet` with the cross-corpus
      mention count and "Find all mentions"
- [x] Front matter text appears in search results when "Front matter" scope is
      toggled on
- [x] Search result badge distinguishes "Front matter" from "Editorial note"
- [x] Volumes without front matter degrade gracefully — "Front Matter" section
      header is suppressed
- [x] `RealCorpusEncodingTests` — real `<div type="section" subtype="…">` /
      `<div type="document" subtype="editorial-note">` encoding round-trips
      through structure parsing, quasi-document promotion, editorial-note
      detection, and sources extraction
- [ ] In-document source-note references long-press/link to the matching
      `volume_sources` entry (Phase 3 cross-reference — not implemented)

---

## Open Questions — Resolved

1. **Should front matter sections appear in the Collections editor?** Yes,
   automatically — front-matter prose sections promoted in Phase 4 are
   regular `document_cache` rows with their own `documentId` (the section's
   `xml:id`) and open in the same `DocumentView` as any other document, so
   "Add to Collection" works unchanged. No special-casing was needed.
2. **Should front matter text be summarizable via Apple Intelligence?** Yes,
   for the same reason — front-matter quasi-documents are ordinary documents
   from `SummarizationService`'s perspective. No special-casing was needed or
   added.
3. **Does `<div type="persons">` differ before ~1980?** Surveyed as part of
   the nine-volume (1861–1988) real-corpus verification in commit `3fb7f17`.
   The 1861-era volume uses a bare `type="toc"` (→ `"table-of-contents"`) and
   `subtype="index"` + `xml:id` for Persons/Terms, the same pattern as later
   volumes — `structuralKind` handles both eras with one code path.

---

## Remaining Work

- Phase 3's `<bibl>`/source-note long-press cross-link to `volume_sources`
  (see Phase 3 notes above) — the only originally-scoped item not built.
