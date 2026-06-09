// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# Volume Front Matter — First-Class Reading Experience

**Status:** Planning  
**Priority:** Medium (near-term backlog)  
**Estimated effort:** 3–5 sessions

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

Currently the app's `FRUSASTNode` parser handles `<front>` element children but the Browser and DocumentView surfaces them only incidentally (the front-matter documents appear in the document list but with no special UI treatment, no structured data extraction, and no search indexing).

A researcher opening a volume for the first time has no natural path to the prefatory context that historians rely on before reading documents.

---

## Goals

1. **Discoverable front matter navigation** — every volume's front matter appears as a named, navigable section before the document list.
2. **Persons list as structured data** — the front-matter `<listPerson>` is parsed into typed entries and linked bidirectionally with the Person Index.
3. **Sources and Abbreviations as structured data** — archive source references are parsed and surfaced in the Source Explorer context.
4. **FTS5 indexing of front matter** — preface/prefatory note/editorial note text becomes searchable (with a "Front matter" scope toggle in the search UI).
5. **Glossary and Abbreviations as in-document popover** — when a document body references a term in the volume glossary, a long-press popover shows the definition (mirrors the existing `<gloss>` TEI cross-reference flow).

---

## TEI Structure Reference

```xml
<text>
  <front>
    <div type="preface">...</div>
    <div type="prefatoryNote">...</div>
    <div type="editorialNote">...</div>
    <div type="sources">
      <listBibl>
        <bibl xml:id="RG59">...</bibl>
        ...
      </listBibl>
    </div>
    <div type="persons">
      <listPerson>
        <person xml:id="p1">
          <persName>Dean Rusk</persName>
          <note type="role">Secretary of State, 1961–1969</note>
        </person>
        ...
      </listPerson>
    </div>
    <div type="terms">
      <list type="gloss">
        <label>SEATO</label>
        <item>Southeast Asia Treaty Organization</item>
        ...
      </list>
    </div>
  </front>
  <body>...</body>
</text>
```

---

## Implementation Plan

### Phase 1 — Navigation Surface (1–2 sessions)

**Goal:** Front matter appears as a named section before the document list in `BrowserView`/`MainWindowView`'s volume detail pane.

Tasks:
- Add `FrontMatterEntry` struct with `type: FrontMatterType` (preface, prefatoryNote, editorialNote, sources, persons, terms) and `volumeId: String`
- Extend `IndexingPipeline.indexVolume(_:)` to detect `<front>` children and store their types in a new `front_matter_sections` SQLite table:
  ```sql
  CREATE TABLE front_matter_sections (
    volume_id TEXT NOT NULL,
    section_type TEXT NOT NULL,   -- "preface", "persons", etc.
    display_order INTEGER NOT NULL,
    PRIMARY KEY (volume_id, section_type)
  );
  ```
- Add `FTS5Store.frontMatterSections(forVolumeId:)` async method
- In `BrowserView` / macOS `MainWindowView` volume detail, add a "Front Matter" header row above the document list; tapping expands to show the available sections
- Each section row navigates to a new `FrontMatterSectionView`

**`FrontMatterSectionView`:**
- For text sections (preface, prefatoryNote, editorialNote): render via `FRUSDocumentRenderer` (the same TEI rendering pipeline used for body documents)
- For persons, sources, terms: delegate to their respective structured-data views (Phase 2)

**Platform notes:**
- iOS: front matter section rows appear in the volume's document list, grouped under a "Front Matter" section header
- macOS: front matter rows appear in the sidebar list; selecting one pushes content into the main pane

---

### Phase 2 — Structured Persons List (1 session)

**Goal:** Volume persons list is parsed and bidirectionally linked to the Person Index.

Tasks:
- Add `<listPerson>` parsing to `FRUSDocumentParser`:
  - Each `<person xml:id>` → `PersonEntry(id:, name:, role:, volumeId:)`
  - Store in existing `persons` FTS5 table with `source = "front_matter"`
- `PersonDetailSheet` gains a "Volume context" section showing this person's role for the current volume (e.g., "Secretary of State, 1961–1969") when viewed from a document in that volume
- `FrontMatterPersonsView`: a searchable list of persons with role notes, tapping opens `PersonDetailSheet`

---

### Phase 3 — Sources and Abbreviations (1 session)

**Goal:** Archive source references are parsed and surfaced in Source Explorer.

Tasks:
- Parse `<listBibl>` in the `<div type="sources">` section:
  - Each `<bibl xml:id>` → `SourceEntry(id:, citation:, volumeId:, archiveCode:)`
  - Store in a new `source_entries` table
- `SourceExplorerView` gains a "Volume Sources" tab showing the volume's source list
- Cross-reference: when a source note body in a document contains a `<bibl>` reference, long-press shows the full bibliographic entry from the front matter

---

### Phase 4 — FTS5 Indexing of Front Matter Text (0.5 sessions)

**Goal:** Text in front matter sections is searchable.

Tasks:
- Add `source = 'front_matter'` rows to the `frus_documents` FTS5 virtual table with:
  - `document_id = "{volumeId}/front/{sectionType}"` (stable synthetic ID)
  - `body` = extracted plain text of the section
  - `is_editorial_note = 0`
- Add "Front matter" scope toggle to `SearchFilterView` (iOS) and the macOS scope row
- Search results from front matter show a "Front matter" badge (distinct from the editorial-note purple badge)

---

### Phase 5 — Glossary Popovers in Document Body (0.5 sessions)

**Goal:** In-document long-press on abbreviations shows glossary definition.

Tasks:
- During indexing, extract `<list type="gloss">` entries into `glossary_entries(volume_id, term, definition)`
- In `FRUSDocumentRenderer`, recognize `<abbr>` elements whose text matches a glossary term
- Add a long-press gesture on these spans that presents a `GlossaryPopover` with the definition

---

## Testing Criteria

- [ ] Opening a downloaded volume shows a "Front Matter" section above the document list on both iOS and macOS
- [ ] Tapping Preface/Prefatory Note/Editorial Note renders the full TEI text via `FRUSDocumentRenderer`
- [ ] Persons list shows all `<listPerson>` entries with role notes
- [ ] Tapping a person opens `PersonDetailSheet` with the volume-context role note
- [ ] Front matter text appears in search results when "Front matter" scope is toggled on
- [ ] Search result badge distinguishes "Front matter" from "Editorial note"
- [ ] Volumes without front matter (older digitizations) degrade gracefully — "Front Matter" section header is suppressed

---

## Open Questions

1. Should front matter sections appear in the Collections editor (add front matter preface to a collection)? Probably yes — researchers annotate prefaces just like documents.
2. Should front matter text be summarizable via Apple Intelligence? Probably yes — long prefatory notes are a good summarization target.
3. For the `<div type="persons">` list, volumes before ~1980 may use a different XML structure. Needs a TEI survey before Phase 2 implementation.
