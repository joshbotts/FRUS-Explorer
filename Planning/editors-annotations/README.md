# Editors' annotations: the measurements of 2026-11-06

The design is `../Editors-Annotations-Design-2026-11-06.md`. Every figure it gives comes from
`tables.out`, which `tables.py` writes from the three extracts committed here. No subagent ran, and
nothing outside this folder and the session's scratchpad was written.

**Amended later on 2026-11-06, after #1853 (index version 72).** Classification is now counted by
the marking the index stores, read from a full index at version 72. Until then it was a word search
over the TEI, which #1853 and this re-count showed to miss what the app stores (§ "Limits" below).
`index-extract-v72.json` and `note-marking-gap.json` are new, `index-extract.json` gained the
`values` tally, and `tables.out` and the CSV were regenerated. The re-count found a second gap, in
the note form the app always read (`tables.out` §12). No other figure moved.

**Amended again after #1857 (index version 73).** Classification is now counted at 73.
- **How the figures are derived:** a volume's figure at 73 is its figure in `index-extract-v72.json`
  plus its count in `note-marking-gap.json` (`tables.py`'s `stored73`).
- **Why that holds:** #1857 built indexes at 72 and 73 and found the 8,865 markings 73 adds to be
  exactly that gap, note for note and value for value.
- **No index at 73 was built for this folder.**
- **What moved:** `tables.out` and the CSV were regenerated, and only classification's figures and
  the artifact size estimate changed.

**The inputs.**
- **The TEI:** the 553 volumes of `FRUSExplorer/Resources/manifest.json` at `v2` `7ac8ee00`. They
  were read from the corpus clone `~/Development/frus/volumes` at commit `6170e4b32`
  (2026-10-14), where all 553 files were present.
- **The index:** a copy of the Mac app's index at version 71, holding the same 553 volumes. It was
  made on 2026-11-04 from the app's container with the app not running: `cp` of `frus.db` and its
  `-wal`, then `PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE` on the copy. It was
  opened read-only. The copy is not committed (3.7 GB); its per-volume extract is.
- **The index at version 72:** built on 2026-11-06 by `ResolvedEdgeIndexGenerator` at `v2`
  `dcf178ed` (#1853's merge), from the same 553 files. `INDEX_DIR` keeps the index the generator
  builds through the kit's own pipeline. Its two JSON outputs went to the scratchpad, not over the
  shipped files, which are its defaults. It ran in the classification lane's worktree, whose tree
  is `v2`'s (`28de0a14`), to reuse its release build. It agrees with the app's index at 71 on every
  per-volume figure the extracts hold but classification, which only grows (`tables.out` §1). Not
  committed; its extract is.

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
- `index_extract.py` → `index-extract.json` from the copy at 71, and `index-extract-v72.json` from
  the index at 72. Per volume:
  - its rows outside front matter;
  - the rows with a person mention that resolves to a `persons` row (the People browser's rule);
  - its `persons` rows;
  - the rows whose stored heading opens with a printed number;
  - the rows with a despatch serial;
  - the rows with a stored classification.

  Over the whole index, `values` counts the rows storing each classification value. Re-run on the
  copy at 71, the script wrote per-volume figures identical to the extract first committed.
- `note_marking_gap.py` → `note-marking-gap.json`, from the index at 72. It replicates
  `SourceNoteParser.classificationMarking(fromSourceNote:)` and checks the replica against every
  stored value. It then counts, per volume and by cause, the notes whose marking the parser does
  not reach but its own gates accept in a later sentence. It also records how sentence 1 ends where
  a period inside the citation is the cause, the causes in the microfiche supplements alone, and one
  sample note per volume. Its figures are #1856's.
- `tables.py` → `tables.out` and `editorial-annotations-by-volume.csv` (one row per volume, with
  every category's document count and every section's presence).

To run again, from the repository root:

```bash
Scripts/heavy.sh python3 -I Planning/editors-annotations/inventory.py ~/Development/frus/volumes FRUSExplorer/Resources/manifest.json Planning/editors-annotations/inventory.json
```

```bash
python3 -I Planning/editors-annotations/index_extract.py <copy of frus.db> FRUSExplorer/Resources/manifest.json Planning/editors-annotations/index-extract.json
```

The index at 72, from a checkout of `v2` at `dcf178ed` or later (set `OUTPUT` and
`PAGE_MAP_OUTPUT`, or the run overwrites the two shipped files):

```bash
VOLUMES_DIR=~/Development/frus/volumes MANIFEST=FRUSExplorer/Resources/manifest.json OUTPUT=<scratch>/resolved-edge-index.json PAGE_MAP_OUTPUT=<scratch>/cited-page-map.json GENERATED_DATE=2026-11-06 INDEX_DIR=<scratch>/index Scripts/heavy.sh swift run -c release ResolvedEdgeIndexGenerator
```

```bash
python3 -I Planning/editors-annotations/index_extract.py <scratch>/index/<the index's .db> FRUSExplorer/Resources/manifest.json Planning/editors-annotations/index-extract-v72.json
```

```bash
python3 -I Planning/editors-annotations/note_marking_gap.py <scratch>/index/<the index's .db> FRUSExplorer/Resources/manifest.json Planning/editors-annotations/note-marking-gap.json
```

```bash
cd Planning/editors-annotations && python3 -I tables.py inventory.json index-extract.json index-extract-v72.json note-marking-gap.json ../../FRUSExplorer/Resources/manifest.json editorial-annotations-by-volume.csv > tables.out
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
| `classification` | a classification word in a source note, or in a `seg` or `hi` inside the `opener`. The words: `top secret`, `secret`, `confidential`, `limited official use`, `unclassified`, `eyes only`, `nodis`, `exdis`, `limdis`, `strictly confidential`. **Superseded** as the design's count by the stored marking (see "Limits"); `tables.out` §7 keeps it as the comparison |
| `not_declassified` | the text "not declassified" anywhere |
| `footnote` | any other `note`, outside a source note |
| `xref_*` | a `ref[@target]`, by target: `#d…` (`doc`), `#…fn…` (`footnote`), `#pg_…` (`page`), `frus…` (`other-volume`), a URL |
| `editorial_note` | the document is `subtype="editorial-note"` |
| `doc_dated`, `date_when`, `place` | the corpus build's `frus:doc-dateTime-min`, a `date` with `@when`, `@from` or `@notBefore`, and a `placeName` |

**Limits the design states.**
- **Classification is the marking the index stores at version 73:** the source note's, from any
  sentence after the first (#1857), else the opener's (#1853), derived as above. `inventory.json`'s word search, which the design first
  counted with, is kept only as `tables.out` §7's comparison. It went wrong in two ways:
  - its vocabulary lacked "No classification marking", "Restricted" and "Official Use Only",
    which 7,201 stored documents read;
  - `itertext()` glued the lines of an `<lb/>` nested in `<hi>` into one word.
- **Until #1857 the stored marking undercounted what the notes print.** Over the index at 72,
  `note_marking_gap.py` finds 8,865 notes from 1955 on whose marking sat in a sentence the parser
  did not read (`tables.out` §12). Version 73 stores them.
  - Its replica of the parser at 72 reproduces every marking that index stores from a note (62,094).
  - Its relaxed reading is a measurement, not the app's rule. Twenty of its notes drawn at random
    all print a real marking.
- **One volume's "source notes" are its paper numbers.** `frus1870` encodes "No. 3.", the number
  its List of Papers gives, as `note[@type="source"]` in 295 of its 300 documents, and every one
  is "unrecognized" in `source-provenance-index.json`. `tables.out` gives the source-note count
  with and without it. This entry called them despatch numbers until `../OH-Note-2026-11-06.md`
  read them against the list.
- **Sections:** read by the app's own rule, `FRUSDocumentParser.structuralKind`: `@subtype`, else
  `@xml:id`. The second clause is what finds `frus1969-76ve09p2`'s Sources.
