# External References as Optional Graph Nodes — Feasibility Analysis

**Session 130 investigation**

---

## What "external references" means in this context

FRUS documents frequently cite primary sources that lie outside the FRUS series itself:
NARA record groups, State Department decimal files, other agency archives, published
collections, oral histories, and foreign-government archives. These appear as **source
notes** in the TEI XML — the `<note type="source">` elements that the Source Explorer
feature already reads.

Adding external references to the cross-reference graph would mean: when the user
expands a document node, a new ring of nodes appears representing those archival
citations, visually connecting the FRUS text to its source materials.

---

## Technical components already in place

| Component | Status | Notes |
|-----------|--------|-------|
| `SourceNoteParser` | Planned (Session 23) | Will extract structured citations from TEI source notes |
| `SourceExplorerView` | Implemented | Opens NARA Catalog searches from source notes |
| `DisplayNode.Kind.extended` | Implemented | Model for grey degree-2+ nodes already exists |
| Cross-reference graph force layout | Implemented | Force-directed solver handles arbitrary node counts |
| `CrossReferenceStore` | Implemented | SQLite-backed; can be extended with new tables |

---

## Proposed data model

```sql
-- New table: one row per unique archival citation within a FRUS document
CREATE TABLE external_citations (
    rowid         INTEGER PRIMARY KEY,
    volume_id     TEXT NOT NULL,
    document_id   TEXT NOT NULL,
    citation_type TEXT NOT NULL,   -- 'nara_rg' | 'nara_file' | 'publication' | 'foreign' | 'other'
    archive       TEXT,            -- "National Archives" / "PRO" / etc.
    record_group  TEXT,            -- "RG 59" etc.
    display_label TEXT NOT NULL,   -- human-readable label for the node
    catalog_url   TEXT             -- NARA catalog deep-link when available
);
CREATE INDEX external_citations_doc ON external_citations(volume_id, document_id);
```

A new `DisplayNode.Kind.externalCitation(archive: String, type: String)` case would
render external nodes in a distinct colour (purple is conventional for archival sources
in diplomatic-history network visualisations).

---

## Key dependencies and risks

1. **`SourceNoteParser` completeness** — The parser must reliably extract structured
   citations (archive + record group + box/folder) from the varied TEI source-note
   formats used across different FRUS eras. Session 23 documents the known format
   variations. Until the parser handles at least 80% of source-note patterns, the
   external-citation data will be too sparse to be useful.

2. **Graph density** — A document with 30 source citations and 15 direct cross-refs
   would show 45+ nodes at degree 1. The force-directed solver handles this, but the
   user experience degrades without good clustering. A "show external refs" toggle
   (rather than always-on) is strongly preferred.

3. **Deduplification of citations** — The same NARA record group appears in hundreds
   of documents. The graph should collapse repeated citations to the same record group
   into a single node with an edge count, similar to how volume clusters work today.

4. **Navigation target** — Clicking an external citation node should open the Source
   Explorer (or trigger a NARA Catalog search), not re-centre the graph. A new
   `nodeHitArea` path is needed.

---

## Recommended implementation sequence

1. **Session 23 (SourceNoteParser)** — parse and store citations in `external_citations`.
2. **Post-session-23 spike** — verify coverage across a sample of 20 volumes; assess
   deduplication quality.
3. **Graph integration** — add `externalCitation` node kind; add toggle to degree toolbar;
   update `CrossReferenceStore.expandedGraph` to optionally JOIN `external_citations`.
4. **Source Explorer navigation** — wire external node tap to open Source Explorer with
   the citation pre-filled.

---

## Verdict

**Feasibility: HIGH** — all required infrastructure is either implemented or planned.
The main gate is `SourceNoteParser` maturity. Recommend revisiting this after Session 23
delivers reliable citation extraction across a representative sample of FRUS volumes.
