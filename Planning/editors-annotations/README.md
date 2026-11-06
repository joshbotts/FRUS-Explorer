# Editors' annotations: the measurements of 2026-11-06

The design is `../Editors-Annotations-Design-2026-11-06.md`. Every figure it gives comes from
`tables.out`, which `tables.py` writes from the two extracts committed here. No subagent ran, and
nothing outside this folder and the session's scratchpad was written.

**The inputs.**
- **The TEI:** the 553 volumes of `FRUSExplorer/Resources/manifest.json` at `v2` `7ac8ee00`. They
  were read from the corpus clone `~/Development/frus/volumes` at commit `6170e4b32`
  (2026-10-14), where all 553 files were present.
- **The index:** a copy of the Mac app's index at version 71, holding the same 553 volumes. It was
  made on 2026-11-04 from the app's container with the app not running: `cp` of `frus.db` and its
  `-wal`, then `PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE` on the copy. It was
  opened read-only. The copy is not committed (3.7 GB); its per-volume extract is.

**The scripts, and what each wrote.**
- `inventory.py` → `inventory.json` (1.1 MB). One `ElementTree` parse per volume, 51 seconds on
  the M5 MacBook, run through `Scripts/heavy.sh`. Each element is credited to its innermost
  `<div type="document">`, and for each document the script records which annotation features
  it carries. So a volume's figure for a feature is the number of documents that carry it. It
  also records:
  - a generic inventory of tags and `@type` values, for discovering layers nobody named;
  - the front- and back-matter sections;
  - the sizes of the lists of persons and of abbreviations;
  - page breaks.
- `index_extract.py` → `index-extract.json`. Per volume, from the index copy:
  - its rows outside front matter;
  - the rows with a person mention that resolves to a `persons` row (the People browser's rule);
  - its `persons` rows;
  - the rows whose stored heading opens with a printed number;
  - the rows with a despatch serial;
  - the rows with a stored classification.
- `tables.py` → `tables.out` and `editorial-annotations-by-volume.csv` (one row per volume, with
  every category's document count and every section's presence).

To run again, from the repository root:

```bash
Scripts/heavy.sh python3 -I Planning/editors-annotations/inventory.py ~/Development/frus/volumes FRUSExplorer/Resources/manifest.json Planning/editors-annotations/inventory.json
```

```bash
python3 -I Planning/editors-annotations/index_extract.py <copy of frus.db> FRUSExplorer/Resources/manifest.json Planning/editors-annotations/index-extract.json
```

```bash
cd Planning/editors-annotations && python3 -I tables.py inventory.json index-extract.json ../../FRUSExplorer/Resources/manifest.json editorial-annotations-by-volume.csv > tables.out
```

**What each feature in `inventory.json` means.** "Documents" are `<div type="document">` inside
`<body>`; there are 314,510 of them. The index's 320,646 rows outside front matter also count a
section's own printed text.

| Feature | A document carries it when it contains |
|---|---|
| `pers_linked` | a `persName` with `@corresp` or `@ref`. The link is not resolved against the list. The index's rule does resolve it, and the two pick out the same 288 volumes |
| `ana_persons` | a document-level `@ana` naming a `#p_` entry (`frus1981-88v16` alone) |
| `terms_linked` | a `gloss` with `@target` or `@ref` |
| `from_to` | any element typed `from` or `to`: a sender or recipient marked in the heading |
| `source_note` | a `note[@type="source"]`. `_inline` is the `rend="inline"` file-number form printed above the heading; `_footnote` is any other, the "Source:" form |
| `classification` | a classification word in a source note, or in a `seg` or `hi` inside the `opener`. The words: `top secret`, `secret`, `confidential`, `limited official use`, `unclassified`, `eyes only`, `nodis`, `exdis`, `limdis`, `strictly confidential` |
| `not_declassified` | the text "not declassified" anywhere |
| `footnote` | any other `note`, outside a source note |
| `xref_*` | a `ref[@target]`, by target: `#d…` (`doc`), `#…fn…` (`footnote`), `#pg_…` (`page`), `frus…` (`other-volume`), a URL |
| `editorial_note` | the document is `subtype="editorial-note"` |
| `doc_dated`, `date_when`, `place` | the corpus build's `frus:doc-dateTime-min`, a `date` with `@when`, `@from` or `@notBefore`, and a `placeName` |

**Limits the design states.**
- **Classification is a word search, not the parser.** The opener form it finds is what a separate
  lane (opened 2026-11-06) is to read properly.
- **One volume's "source notes" are despatch numbers.** `frus1870` encodes "No. 3." as
  `note[@type="source"]` in 295 of its 300 documents, and every one is "unrecognized" in
  `source-provenance-index.json`. `tables.out` gives the source-note count with and without it.
- **Sections:** read by the app's own rule, `FRUSDocumentParser.structuralKind`: `@subtype`, else
  `@xml:id`. The second clause is what finds `frus1969-76ve09p2`'s Sources.
