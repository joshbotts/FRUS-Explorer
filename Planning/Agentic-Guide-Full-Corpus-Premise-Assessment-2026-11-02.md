# Agentic Analysis Guide — the premise of a full corpus download: an assessment

**Status: ASSESSMENT, 2026-11-02.** Recommendations only. Nothing in the guide, the app, the
harness or the plan of record is changed by this document, and no tier was run. It is written
against the guide at v1.42 (`v2` at `9f384dbe`). The measurements in §2 were taken read-only on the
owner's Mac on 2026-11-02, between 21:41 and 21:56 EST; their scripts and outputs are in
`full-corpus-premise/`.

**The question.** On 2026-11-02 the owner asked how `Docs/Agentic-Analysis-Guide.md` would change
if its premise changed from "an agent handed the app's research database" to "an agent handed all
the app's data across a full corpus download". That data is the index (`frus.db`), the 553 TEI
volumes in the app's volumes folder, the bundled JSON, the vector artifacts with every Tier-2
shard, and the figure images. The owner also asked whether the researcher's own writing belongs
in it.

---

## 1. The answer in brief

1. **The measurements already had most of the full premise; the text did not.** C-0b's runner
   (2026-09-06) handed its agents the index copy, the TEI corpus and the bundled JSON, and C-0c ran
   on C-0b's design. Every C-3 runner did the same, and the last three C-3 tiers (2026-10-26 to
   2026-10-31) added the vector artifacts with all 553 Tier-2 shards (§3). None was pointed at the
   figure images, and none had a copy with the researcher's writing stripped, an app export, or the
   query encoder.
   Meanwhile the block those runs were scored against says, of the TEI and the JSON, "If a rule is
   marked [TEI] or [JSON] and you have not been given that surface, say so and stop". No measured
   run was ever in a position to close that gate. So the new premise does not invalidate §3a's
   figures or §12's compliance numbers. What has not been measured is a block written for it.
2. **Most of the change is in what the guide says about surfaces** (§5). That means §1's three
   truths, §2's copy and §4.7's export, and the block's opening, SURFACES, COVERAGE and one
   REPORTING line. It also means the routing table, §13's record, §14's preface and §A.1's
   asymmetry. Two things are new: a check that the surfaces describe one corpus (§5.7), and a
   short section on the figure images (§5.10).
3. **What the full premise buys, measured** (§2). One `ElementTree` pass over all 553 volumes took
   50.9 seconds on the M5 MacBook Air. That is cheap enough for the TEI to be the default surface
   for counting words. The pass and a reconciliation of the surfaces found two things the database
   alone would not have shown:
   - The guide's predicate for counting documents, `document_id GLOB 'd[0-9]*'` (§4.2, §4.3),
     drops 647 of the 314,616 documents the TEI holds. They are all 628 documents of
     `frus1958-60v05mSupp`, whose ids are `bl_d1`, `ch_d…` and the like, and 19 printed appendix
     documents (`appA`, `appxB`, `appendix-A`) in five 1981–1988 volumes.
   - Footnote text is 5.7% of the characters inside document divisions over the whole corpus. It
     runs from 0.5% in volumes dated 1861–1899 to 8.6% in those dated 1945–1964. That is the split
     §7.2 says "The database offers no column" for.
4. **The researcher's own writing: out** (§4). "All the app's data" should mean the corpus and what
   the app derives from it. The writing enters only as a separate, labelled surface the brief names,
   through the app's Export as JSON. It never enters through the index's mirrored columns or the
   SwiftData store.
5. **The query encoder: not the app's data** for this premise (§5.9). §A.7 stands as written.
6. **A tier before the block's text changes** (§6). It has two arms on the two recommended cells,
   with two runs each, under decision 115's guard. Its cost is about 17 to 20 weekly points and 31
   to 37 Fable points, over 3 to 6 hours. The vectors addendum stays outside the block in both arms
   (decision 115). Text outside the block needs no tier, and most of §5 is outside it.

---

## 2. What "all the app's data" is, measured

### 2.1 The surfaces on disk

From `full-corpus-premise/sizes.out`. The app data folder is the container's
`~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/`.
The bundle is the installed 1.0 (1787).

| Surface | Where | Files | Bytes |
|---|---|---|---|
| The index | `frus.db` in the app data folder (a `-wal` of 317,272 bytes beside it) | 1 | 3,743,547,392 |
| The TEI | `volumes/*.xml` in the app data folder | 553 | 3,339,186,418 |
| The figure images | `volumes/<volume>.figures/`, in 96 volumes' folders | 553 | 140,994,857 |
| The bundled JSON | the bundle's `Resources/*.json`, the vectors' three index files included | 38 | 29,136,429 |
| The vector binaries | the bundle's `semantic-vectors-binary.bin` and `semantic-map.bin` | 2 | 22,363,808 |
| The Tier-2 shards | `SemanticVectors/*.vec` in the app data folder | 553 | 162,377,248 |
| **All of it** | | **1,700** | **7,437,606,152** |

Three things sit beside these and are **not** counted. The first is the query encoder,
`SemanticModel/embeddinggemma-2-Q8_0.gguf` (309,855,456 bytes; §5.9). The second is the SwiftData
store, `default.store` one folder up (63,066,112 bytes with a 778,712-byte WAL; §4). The third is
the offline NARA harvest, which is owner-local and already its own `[HARVEST]` surface.

The TEI folder is spelled `volumes/` on disk. §1 writes `Volumes/`, which the Mac's case-insensitive
disk also opens. It holds 553 `.xml` files, the 96 `.figures` folders and one JSON file,
`.figure-images-complete.json`. So a `*.xml` glob there finds exactly the manifest's 553. §14.3's
"shell glob over the 694 files on disk" describes a corpus clone that holds more files than the
manifest names (the upstream clone on this Mac holds 744 today), not this folder.

Each surface carries its own pin, and the device holds no corpus commit:

| Surface | What pins its generation on the device | Read on 2026-11-02 |
|---|---|---|
| The index | `research_provenance` on an app export, and the Research-State Record (§13) | index version 71 (C-3's copy) |
| The TEI | only the manifest's `sizeBytes` per volume; no bundled file names the corpus commit | all 553 files match 1.0 (1787)'s manifest |
| The bundled JSON | the app build, and each file's own stamp | 1.0 (1787) |
| The vectors | `provenanceDigest` and `generated` in `semantic-vectors-index.json` | `89481b18…`, 2026-10-15 |
| The shards | `SemanticVectors/.generation` (the digest) and `semantic-shards-manifest.json` (a SHA-256 for each shard) | all 553 match their SHA-256 |
| The figure images | `.figure-images-complete.json`, which keys each volume to its XML's size and modification date | 553 files present |

### 2.2 One TEI parse pass

`full-corpus-premise/tei_pass.py`, run through `Scripts/heavy.sh` from 21:41:59 to 21:42:50, with
the load average at 3.9. It used Python 3.9.6's `xml.etree.ElementTree.parse` on each file, which
builds the whole tree as an agent's script usually does. The manifest was the file list. It then
walked the tree to attribute each text node to its document division and to the outermost
`<note>` it sits in.

- **553 files, 3,339,186,418 bytes: 50.9 s wall** (19.2 s parsing, 30.3 s walking), 49.1 s of
  processor time. Peak resident memory was 118.5 MB.
- **The largest volume** (`frus1958-60v03mSupp`, 13,140,139 bytes) took 0.2 s. The slowest 20
  consecutive volumes in manifest order took 2.6 s.
- **Controls.** The pass found 314,616 document divisions, which is the vectors' `documentCount`.
  It found 992 `<graphic>` elements inside a `<figure>`, which is `CLAUDE.md`'s figure. It found
  97,481 documents in the first 150 manifest volumes, two fewer than §14.3's 97,483. That is
  consistent with the two divisions of `frus1902app1`, the 68th volume, that the corpus at
  `deb6a04f8` made sections (guide v1.25). The era bands below reproduce §A.5's own denominators:
  34,046 documents in volumes dated 1861–1899, and 100,373 in volumes dated 1945–1964. The
  page-scan `<graphic>`s number 1,143,205, which is 162 more than `CLAUDE.md`'s count of
  2026-10-01. That difference was not traced; the corpus has changed since.

The parse itself fits in one 120-second call with room to spare. What makes a TEI scan long is
what the agent does per document. §3's "never scan all 553 volumes or all of `body_text` in one
call" stays for that work, for the 180-second watchdog and for checkpoints.

### 2.3 Document identity on three surfaces

`full-corpus-premise/ids.py` (28.2 s) compares three things, volume by volume. The first is the
TEI's `<div type="document">` ids, in document order. The second is the vector index's run-length
segments, decoded as §A.3 prints the decode. The third is the index copy's `document_cache` rows.

- **In all 553 volumes the vectors' ids are the TEI's document ids, in the same order.** Every TEI
  document has an index row. The index holds 321,749 rows, and 7,133 of them are not TEI documents:
  the 1,103 front-matter rows, and 6,030 rows for sections' own text, headings' footnotes and prose
  sections (§4.2's classes).
- **The guide's document predicate misses 647 documents.** 313,969 rows match
  `document_id GLOB 'd[0-9]*'`. The TEI documents it misses are of two kinds:
  - all 628 documents of `frus1958-60v05mSupp`, whose ids carry one of 17 prefixes (`bl_`, `ch_`,
    `co_` … `ve_`);
  - 19 printed appendix documents: 3 in `frus1981-88v01` (`appendix-A` to `-C`), 5 in
    `frus1981-88v04` (`appxA` to `appxE`, the first an editorial note), 3 in `frus1981-88v05`
    (`appA` to `appC`), 7 in `frus1981-88v11` (`appA` to `appG`) and 1 in `frus1981-88v44p1`
    (`appA`). Among them are Shultz's handwritten notes and a letter from Reagan to the Soviet
    General Secretary.
- **The database can match the TEI's set without the TEI.** The 647 are exactly the rows with a
  non-`d` id that also have a `page_ranges` row with `is_start = 1`; they were matched by id, not
  count. 103 `d` rows have no start row, so neither test alone is enough. Rows that match
  `document_id GLOB 'd[0-9]*'` **or** have a start row number 314,616, which is the TEI's set
  (`checks.out`, item 3).
- **§14.9's two overlap figures reconcile.** On the TEI the Iran pair shares 375 document ids, 358
  of them historical documents and 17 editorial notes. The `ve15p2` pair shares 343. That gives
  718, the vectors' figure. The index's 701 is the same set less the Iran pair's 17 editorial notes.

### 2.4 Footnotes inside document text

The surface is the text nodes of each document division in document order. The outermost `<note>`s
are split from the rest, and source notes (`type="source"`) are kept apart. Each part is joined and
its whitespace collapsed, which is §14.3's recommended surface. Over the corpus the document
divisions hold 1,329,530,881 characters: 1,228,962,132 of body, 24,616,006 in 268,476 source notes,
and 75,952,743 in 502,526 other notes (5.71%). By era band, with each volume dated by the mean of
its manifest years, rounded down (§A.5's rule; 544 of the 553 volumes fall in a band):

| Volumes dated | Volumes | Documents | Other notes, share of the characters | Source notes |
|---|---|---|---|---|
| 1861–1899 | 60 | 34,046 | 0.52% | 0.02% |
| 1900–1944 | 162 | 132,698 | 3.23% | 0.76% |
| 1945–1964 | 181 | 100,373 | 8.61% | 1.74% |
| 1965–1988 | 141 | 44,947 | 7.36% | 4.34% |

**Undated documents.** Every one of the 314,616 TEI document divisions carries
`frus:doc-dateTime-min`. In C-3's index copy, 0 of the 305,594 `d` rows outside front matter and
editorial notes has a NULL `date_iso`. §6.4's undated query, over every row outside front matter,
counts 1,187 of 320,646. All 1,187 are section rows (1,178) or editorial-note sections (9), and
none is a document.

---

## 3. What the measurements already had

| Measurement | Index copy | TEI | Bundled JSON | Vectors and all 553 shards | Figure images | The owner's writing in the copy |
|---|---|---|---|---|---|---|
| C-0b, 2026-09-06 (C-0c and C-0d on its design) | hand-made, 552 volumes | the upstream clone | the installed app's | — | — | in, unread by rule |
| C-3, 2026-10-25 (§3a's table) | `.backup`, 553 volumes | the app's 553 | 38, build 1776 | — | — | in: 6,558 summaries, 8 notes, 111 tag rows, 21 tag names |
| Vectors tier, 2026-10-26/27 | the same | the same | the same | yes, shards copied | — | the same |
| Steering tier, 2026-10-30 | the same | the same | the same | yes | — | the same |
| Reader-facing tier, 2026-10-31 | the same | the same | the same | yes | — | the same |

The sources are C-0b's `workflow.mjs`, `Planning/c3-reader-test/facts.md` and the RESOURCES
sections of `prompts/runner_A.txt` in `c3-steering-tier/` and `c3-reader-facing-tier/`. C-0's and
C-2's `workflow.mjs` name the same three surfaces as C-0b's, and C-0d ran on C-0c's frozen design
and harness. No run used
an app export: neither C-0b's copy nor C-3's has a `research_*` table, so none had
`research_provenance` or the views. The runs that had the vectors had no embedder (§3a), and the
last two tiers' prompts say so: "No embedder is available in this session".

So the agents behind §3a and behind every compliance figure in §12's preamble were already working
with the TEI and the JSON in hand. The last three tiers also had every shard. Those agents read a
block that called those surfaces conditional. The full premise adds the figure images to the
environment. By §4's recommendation, it adds a stripped copy. Everything else it changes is
wording.

---

## 4. The researcher's own writing: in or out

**What it is.** The writing lives in the SwiftData store: notes, highlights, collections, projects,
saved searches, working corpora, the research trail, corrections and synced preferences. The index
mirrors a slice of it. `summary_text` holds the newest non-draft summary, `note_text` every note on
a document joined into one value, and `user_tag_ids` with `user_tags` the tags (§4.6, §7.6).

**Recommendation: out.** Define "all the app's data" as the corpus and what the app derives from
it. Take the index from the app's export with the switch off, as §2 already describes.

1. **It adds nothing to a claim about the printed record, and it adds §1's hazard.** The guide warns
   that an agent "will happily quote a machine-generated summary back to you as though it were a
   1958 telegram". A copy with more surfaces is a copy with more ways to reach the summary.
2. **The app's default is already out.** In §2's words, "The switch is **off** by default, so the
   export excludes your notes, summaries and tag names unless you say otherwise."
3. **The block keeps working either way.** Every measured run had the writing in the copy and was
   told "NEVER read or quote summary_text or note_text". C-3's scorers checked that rule (E2) in
   all twelve runs, and it held. A stripped copy turns the rule into something that cannot fail.
4. **§11's decision stays a decision.** "Copying the database to a cloud AI tool overrides that
   choice". A full copy reaches a model's provider piece by piece as the agent reads it.
5. **The store is not a research surface.** It is a Core Data schema carrying CloudKit's mirroring
   metadata. The typed, documented form is **Export as JSON** (format version 7). It leaves AI
   summaries out unless asked, and each summary it includes records who wrote it, which the
   mirrored `summary_text` cannot. But the macOS manual says that file "contains the text of every
   search you ran", so "look before you share it".

**If the owner wants it in** for a question that needs it ("what have I already read on this?"),
it should come in as a named surface. The brief would hand over the Export as JSON file and label
counts from it `[WRITING]`, as it labels the harvest's `[HARVEST]`. Such counts are never summed
with corpus counts and never quoted as sources. E2 stays, and `research_provenance`'s
`my_writing_included` grows to say which writing came with the copy.

---

## 5. Section by section

Each entry quotes the guide and says what would change. It also says whether the change falls
**inside the §12 block**, which is the measured instrument and needs §6's tier, or **outside** it,
which needs none.

### 5.1 The title, the status line and the reader's path (outside)

- The subtitle, "point … at FRUS Explorer's local SQLite index and ask it questions", becomes the
  app's data. The title, *Agentic Analysis with the FRUS Explorer Database*, follows it.
- The status line's "The export it starts from is Mac only" stays true and grows. The TEI, the
  figures and the shards sit in the Mac container too, and §2 says iOS has "no supported route to
  the file".
- The reader's path ("§1 (what the database is and is not)") keeps its six sections.

### 5.2 §1's three truths (outside)

- **"It is a search index, not the edition."** This stays true of the index, and the edition now
  sits beside it. "If a finding depends on how something was encoded, go back to the XML" becomes
  the routing rule for every word count, and the path takes the spelling on disk (§2.1). The
  edition also includes the figure images, which the index cannot hold.
- **"It contains only what you downloaded."** This truth goes. In its place: the copy holds all
  553 volumes on every surface, and that is checked, not assumed (§5.7). The paragraph's warning
  that no row anywhere says how many volumes are missing turns around: under this premise a missing
  volume is a defect of the copy. The partial-library caveat gives way to §10's: "FRUS is a
  selection". A count is conditional on what the editors printed, not on what the reader
  downloaded.
- **"One number has two truthful values right now"** needs re-reading against 1.0 (1787). Its
  claim that "measuring from an installed app or a device index gives **552**" is not what either
  shows now. The installed manifest lists 553 volumes, with 1981–1988 vol. XVI marked
  `partiallyPublished`. C-3's copy of the owner's device index holds 553 volumes. The manifest's
  `status` field is the honest way to say it.
- **"It contains your own writing."** This truth goes under §4's recommendation, and the paragraph
  becomes the rule that the copy must not contain it. It names the export's switch, and it says
  how to confirm the switch was off: `research_provenance.my_writing_included = 0`.

### 5.3 §2 and §4.7: the copy and the export (outside, and an app question)

- **§2, "Getting a copy of the database."** The heading and "Where it lives" grow to four places:
  `frus.db`, `volumes/` (the TEI and, inside it, the `.figures` folders), `SemanticVectors/`, and
  the bundle's `Resources/`. "Copy it properly" keeps `.backup` for the index. The rest is a file
  copy, and "Quit FRUS Explorer first" now matters for every surface. The running app writes into
  `volumes/` when it downloads a volume or fetches figure images, which it does at launch and on
  reconnecting. It writes into `SemanticVectors/` when it fetches a shard. "Verify the copy" gains
  two checks: the TEI's sizes against the manifest's `sizeBytes`, and each shard's SHA-256 against
  `semantic-shards-manifest.json`. Both ran clean on 2026-11-02 in under a second (§2.1).
- **"Or let the app do it."** Export Research Database… copies the index alone. Either §2 says the
  export covers one surface and the rest are copied by hand, or the export grows. A grown export
  is an app change, outside this document's remit, and it is the owner's call.
- **§4.7's `research_provenance`** would have to say what each surface is. Its own principle sets
  the form: it "deliberately does **not** carry §13's two lists … a stored second copy is a second
  place for them to disagree." So it should carry pins and counts, not lists. The candidates are a
  TEI volume count and whether every size matched the manifest, the shards' generation and count,
  and the figure-image count. `semantic_provenance_digest` already covers the vectors, and today
  it can be "SQL `NULL` if they were not loaded"; under this premise a NULL there is a defect.
- **The views.** `research_documents` is "`document_cache` minus front matter, editorial notes and
  suppressed volumes", so it keeps the 7,133 rows that are no TEI document, less those that are
  front matter. §2.3's predicate gives a view of documents only, and that is the one change to the
  views this premise suggests.

### 5.4 §3, connecting an agent (outside)

"Give it SQL, not the file" becomes "give it SQL and the files". The rule to "never scan all 553
volumes or all of `body_text` in one call; slice by volume (ten to twenty per call)" stays as call
discipline. The reason under it changes, though. A whole parse pass is 51 seconds, so slicing
protects the per-document work, the watchdog and the checkpoints, not the parse (§2.2). §3a needs
a sentence saying what each measurement was handed (§3 above). Under this premise, the fact that
its table was measured with the TEI and the JSON present is a strength the paragraph does not
state.

### 5.5 §7's eight traps (outside)

The heading, "Eight ways this database will quietly mislead you", stays. All eight remain true of
the index. What changes is whether each can be checked, because every trap of the flattened text
has its answer in the TEI.

| Trap | Under the full premise |
|---|---|
| 7.1 stems, not words | **Checkable, and exact.** The literal share stops being "An evenly-spaced sample of 40 … a census for a load-bearing family" and becomes a census by default: the share of every FTS hit document whose TEI text carries the literal (§5.8). |
| 7.2 footnotes inside `body_text` | **Checkable.** "The database offers no column that separates them. If the distinction is load-bearing, parse the TEI." The TEI is now in hand, and the size of the contaminant is measured: 5.71% of document text, 0.52% to 8.61% by era (§2.4). A term count can be published as body and footnote. |
| 7.3 `reference_type` | **Checkable.** Whether a `<ref>` sits inside a `<note>` is in the TEI, so "N% of citations occur in footnotes", which this column "cannot support", has a route. Its roughly 95% can be re-measured rather than cited. |
| 7.4 `citation_era` | **Stays.** It is a misreading of a column, and no surface corrects a misreading. |
| 7.5 person clustering | **Stays for identity**, since clustering is a derived layer the TEI does not settle. Tagging coverage becomes measurable, as §14.5 already measured it ("4–10%"). "X is tagged in N documents in my indexed volumes" loses "my indexed volumes". |
| 7.6 summaries | **Stays as a rule.** Under §4's "out" the columns are NULL; the rule keeps a summary out of evidence when the writing comes in by the owner's choice. |
| 7.7 subject tags | **Stays for aboutness.** "excellent for *finding* documents and unsuitable as a measurement of what documents are *about*". The tag ∩ phrase check becomes exact. |
| 7.8 absent rows | **Partly checkable.** An absence can be classed against the TEI as by construction or by parse failure. One is measured: no document is undated, and every undated row is a section (§2.4). |

Two traps are new, and both belong in §13 rather than §7 (§5.7). The first is that the surfaces
disagree on what a document is. The second is that a re-published volume changes one surface
and not another.

### 5.6 §12: the block, the routing table and the addendum

**Inside the block: five places, all needing §6's tier.**

1. **The opening.** "You have read-only SQL access to a SQLite copy of the FRUS Explorer index"
   becomes read-only access to a complete copy of the app's data.
2. **SURFACES.** "If a rule is marked [TEI] or [JSON] and you have not been given that surface, say
   so and stop — do not answer it in SQL." The gate becomes a route. The tags stay as labels saying
   which surface answers; "say so and stop" stays only for a surface the brief names that turns out
   missing or incomplete, and for `[HARVEST]`.
3. **COVERAGE.** "The full series is 553 volumes. This database has only what I downloaded. Every
   count is conditional on that; say so in every summary, with the volume count." This becomes a
   completeness check on every surface.
4. **IDENTITY** gains the definition of a document. §2.3 measured why: the guide's own id pattern
   drops 647 documents, and an agent counting documents in SQL reaches for an id pattern.
5. **REPORTING.** "Flag when a result is thin enough that it may reflect my partial library rather
   than the corpus." This becomes §10's selection.

A draft of those five, for §6's treatment arm. It is a draft, not adopted, and written to the
block's 100-character lines:

```text
You have read-only access to a complete copy of FRUS Explorer's data for all 553 volumes: a SQLite
copy of its index, the volumes' TEI XML, and the app's bundled JSON. Follow these rules.

SURFACES — there are three, and most rules below belong to exactly one
- THIS DATABASE answers coverage, identity, exclusions, the citation graph, and every count of
  documents.
- THE TEI XML is the edition's text. Answer every counting-surface question, spelling-variant scan
  and apparatus/document split there: this index stores porter STEMS and a flattened text, so a
  variant count run here silently answers a different question. Marked [TEI] below.
- THE BUNDLED JSON resolves subjects, volume metadata, and EVERY archival question. Nothing in this
  database turns a lot number or a collection name into a shelf. Marked [JSON] below.
A rule marked [TEI] or [JSON] is answered on that surface, never approximated in SQL: an
approximation here is indistinguishable from an answer. If a surface your brief names is missing
or incomplete, say so and stop.

COVERAGE (its second bullet)
- The full series is 553 volumes, and this copy should hold all of them on every surface: 553 in
  this database, 553 TEI files, 553 vector shards if you were given them. Report the three counts.
  If one falls short, every count from that surface is conditional on what it holds; say so.

IDENTITY (a fourth bullet)
- A document is a TEI <div type="document">, and its xml:id is the document_id. This database also
  holds rows for front matter and sections' own text. To count documents in SQL, keep rows whose id
  is d and a digit OR that have a page_ranges row with is_start = 1; never an id pattern alone.

REPORTING (in place of the partial-library bullet)
- Flag when a result is thin enough that it may reflect the editors' selection rather than the
  record: FRUS prints a selection of the files.
```

Everything else in the block survives the premise word for word. One SCOPING line takes the
reconciliation if the owner wants it, at the cost of a line: "the overlap is 718 documents in the
vector artifacts and 701 in this index with apparatus excluded" could add that the TEI's count is
the vectors' 718.

**The routing table, outside the block.** Its preamble, "This is what an agent handed only the
database can and cannot do", becomes what each surface answers. Its third column, "If the surface
is missing", empties to "—" for the TEI, the JSON and the vectors. The TEI row's "Say the number is
unavailable" and the JSON row's "Say the archival half did not run" stop applying. v1.42's vectors
row, "Tier-2 shards for fetched volumes only", becomes all 553. Two rows join it: the figure images
(§5.10), and, if the owner wants it, `[WRITING]` (§4). The `[HARVEST]` row is unchanged, since the
harvest is not the app's data.

**§A.8's addendum stays outside the block** (decision 115). Under this premise it is pasted every
time, because the artifacts are always handed over. One of its bullets loses its premise: "Tier-1
covers all 553 volumes even when the SQLite index does not: flag any neighbor whose volume is absent
from document_cache, and cite it by its canonical URL." That flag cannot fire on a complete copy.
The bullet's place suits §5.7's identity check, drafted for §6's treatment arm:

```text
- Before any vector work, check that the vectors describe the same corpus as the TEI: decode each
  volume's id segments and compare them, in order, with its TEI <div type="document"> ids. Use no
  vector for a volume that disagrees, and say so: a re-published volume changes the XML, not the
  vectors.
```

The addendum is pasted into the prompt, so changing it is measured with the block. Putting a
SEMANTIC VECTORS section inside the block is the separate change decision 115 bars without a new
measurement, and nothing here proposes it.

### 5.7 §13: pinning every surface, and the identity check as a trap (outside)

**The record table** gains a row for each surface it lacks, from §2.1's pins:
- the TEI, as its volume count and its size match against the installed manifest, or a SHA-256 for
  each file if the copy will be cited (the device holds no corpus commit);
- the bundled JSON, as the app build, which the table already records;
- the shards, as `.generation` and the count that matched `semantic-shards-manifest.json`;
- the figure images, as their count and `.figure-images-complete.json`.

The vectors' row, "if the brief handed them over", loses its condition. The writing row reads
`my_writing_included = 0` under §4. "Downloading more volumes changes every count" stops applying,
and an app update still re-indexes.

**A new trap: the surfaces must describe one corpus.** The addendum says identity comes "ONLY
from semantic-vectors-index.json's id segments" (§A.3). `CLAUDE.md` gives the reason: "identity
NEVER comes from a shard's position in local XML … because a re-published volume changes the XML
and not the artifact". The index changes with the XML too, once the app re-indexes the volume.
Today all three agree in all 553 volumes, in order (§2.3). They stop agreeing when the Office of
the Historian re-publishes a volume and the app downloads it, until the next vectors generation.
The check takes 28 seconds and belongs at the start of every session. Three disagreements are
worth naming, each from §2.3:
- the TEI's documents against the index's rows: 7,133 rows are no document;
- the guide's own predicate against the TEI: 647 documents dropped;
- a volume's TEI ids against its vectors' ids: none today.

### 5.8 §14 (outside)

- **The preface.** "Note the scope shift: §§1–13 are about the SQLite index. This section is mostly
  about scanning the TEI corpus directly". The shift disappears. §14 describes the default way to
  count words, not a detour.
- **§14.3's counting surface becomes the default.** "Prefer tag-stripped and whitespace-collapsed,
  and state it" holds for every count of words. §14.3's file-shape rules (multi-line start tags,
  `subtype=` matched before `type=`, headings in `<back>`) move from a scoping aside to the
  guide's main path. The parse costs 51 seconds a pass (§2.2).
- **§7.1's literal share becomes an exact count.** A family's literal share is the TEI
  literal-match documents among the FTS hit documents, a census rather than a sample of 40. Strict
  and tolerant regexes run over the TEI text with `<note>` split off, so a share can be stated for
  the document's words and the editors' separately. The sample protocol stays only for reading the
  misses.
- **§14.9's 718/701 overlap gets a third surface and an explanation.** The TEI agrees with the
  vectors (718), and the index's 701 is that set less the Iran pair's 17 editorial notes (§2.3).
  The section's other figure goes: "the semantic artifacts count **314,616** documents, while this
  project's own settled corpus figure from its query work is **316,839**. The two count different
  surfaces." No surface measured here gives 316,839. The TEI's document divisions, the vectors'
  rows and the index's documents are all 314,616.
- **§14.11's archival half always runs.** The routing table's "Say the archival half did not run"
  and the block's `[JSON]` gate assume a copy without the JSON. With the JSON always present, a
  missing archival half is a failure of the round, not of the copy. What stays is the bundle's own
  reach: projection gaps, and "The offline stack barely reaches before 1940".
- **§14.17's coverage asymmetry goes.** Its anchors and neighbours can all be opened, read and
  quoted locally, and the strict reading of *vector-reached* is unchanged. One consequence, from
  its own text: "The strict count also depends on how wide the full-text scope was drawn". A
  premise that makes the TEI routine makes wide scopes cheap, so expect fewer documents to count as
  vector-reached, as its 12,256-document session already showed.
- **§14.10's and §14.11's bundle figures are stale under any premise.** §14.10 reads "The app ships
  34 bundled JSON resources", but builds 1776 and 1787 ship 38. §14.11 reads "11.83 MB of the 24.79
  MB the app ships", but the 38 total 29,136,429 bytes (§7).

### 5.9 Appendix A (outside)

- **§A.1's Tier-2 asymmetry goes.** "The Tier-2 shards … exist **only for volumes whose vectors have
  been fetched** … whereas Tier 1 and the map cover the **entire 553-volume corpus regardless of
  your library**. That asymmetry cuts both ways". With all 553 shards in hand it cuts neither way.
  Its last clause, that "the semantic tier is the one place in the app's data where a claim about
  the *whole* corpus is actually possible", stops being true, because the index and the TEI are
  whole too.
- **§A.6.** "Remember shards exist only for fetched volumes; a missing shard is
  *typed-unavailable*, not zero similarity." Under this premise a missing shard is a defect of the
  copy, and the reranking funnel runs for every document.
- **§A.7 and the encoder.** The encoder sits in the container, at `SemanticModel/`, and its
  309,855,456 bytes hash to the index's `provenance.modelFileSHA256` (`checks.out`, item 7). The
  recommendation is **not to count it as the app's data** for this premise, for three reasons:
  - It is a model, and using it needs a runtime the copy does not include (the app's own is
    `Vendor/llama.xcframework`).
  - Its quality on the one task it adds, free-text retrieval, is the measurement §A.7 says is
    missing: "Text-query retrieval has been measured only by the owner's 25 judged queries, in
    August and for the 300m".
  - Every measured run was told "No embedder is available in this session", so counting it would
    change the instrument.

  §A.7 already says where the validated copy is ("You probably already have the weights") for a
  researcher who wants it. If the owner counts it anyway, §A.7's title stops being a limit. The
  text-query measurement, owner-judged queries under EmbeddingGemma 2, would then come before any
  rule that lets a free-text neighbour into evidence.
- **§A.8** is unchanged except for the addendum bullet in §5.6.

### 5.10 New: the figure images (outside)

The guide never mentions them. A short section, a §4 table or an Appendix B, would say:
- **Where they are.** `volumes/<volume>.figures/`: 553 PNGs, 140,994,857 bytes, in 96 volumes'
  folders.
- **What names them.** The `<graphic url>` inside a `<figure>` outside the title page, with `.png`
  added (`CLAUDE.md`). The TEI holds 992 `<graphic>`s inside a `<figure>` (§2.2), and those on title
  pages are not fetched.
- **What is missing by construction.** There are 13 names the host refuses (`CLAUDE.md`, measured
  2026-10-01).
- **What records completeness.** `.figure-images-complete.json`.
- **What they cannot do.** An image's content is in neither the index nor the TEI; only the
  figure's head and caption are TEI text. §8's machine check cannot verify a quotation read off an
  image. So a claim from a map or chart cites the document that prints it, quotes only the caption
  as text, and says it was read from the image. A reading count (§9 item 8) says how many images
  were read.

Most questions never touch a figure, since 553 images sit among 314,616 documents. So the section
belongs outside the block, routed by the table, like the vectors (§5.6).

### 5.11 What does not change

§4's tables, §5's resolutions and §6's queries hold. Only §6.1's "`volumes` against the manifest's
553 is the denominator" becomes a check that it is 553. §6.6's "treat every degree as a **lower
bound**" no longer holds for missing citing volumes, but it still holds for broken references and
unresolved page anchors. §8's citation chain holds. Its quotation residue ("the TEI settles the
printed form") becomes something the agent settles. §9's protocol holds, and item 1's script route
("a multi-stage pass over the TEI, a script over the bundled JSON") becomes ordinary. §10 keeps
every caveat, though its example "Among the 43 volumes I have indexed" changes. §11 keeps
everything about the agent's own traffic: "an unpublished argument visible in the shape of your
queries". §15 holds, and the app opens a collection against its own index.

---

## 6. What needs a new measurement, and the tier

### 6.1 What was measured under what

- **§3a's model table** (C-3, 2026-10-25) was measured with the index, the TEI and the JSON. It
  needs no re-measurement for the new environment. It still rests on one question for its nine
  cells; that is the plan's §5 item, and this tier does not answer it.
- **§3a's vector paragraphs** (2026-10-27, 10-30, 10-31) were measured with the vectors and all 553
  shards. They need none either.
- **§12's compliance numbers** (C-0b, C-0c and C-0d at 143, 181 and 184 lines, and the C-3 tiers'
  35 items on the 205-line block and its revisions) were measured on the database-premise text.
  They stand as history of the texts they measured. v1.41's 221 lines have not been measured.
- **Unmeasured:** a block written for the full premise (§5.6), and the figure images in the
  environment. Two of the 35 items assume a partial library: **C2** ("Said the findings are
  conditional on the local library, naming the volume count") and **R4** ("Flags results thin
  enough to reflect the library rather than the corpus"). Both need wording that scores both arms
  the same way.

### 6.2 The design

- **Name.** A C-3 full-corpus tier, run on the owner's Mac, only on the owner's word and under a
  budget line the owner sets.
- **The question.** One of the owner's three unused candidates (the plan's §5), given in chat and
  written into no file until the record is written (C-0c's rule).
- **Arms.** A, the control, is the guide at v1.42: the §12 block with §A.8's addendum pasted after
  it, and Appendix A, as in the last three tiers. B, the treatment, is a v1.43 candidate on a
  branch of its own: §5.6's five block changes and its addendum bullet, with every other byte the
  same. Both arms are generated by script from their commits and verified by parsing the prompts
  back (runbook §8).
- **The environment, identical in both arms.** The reader-facing tier's RESOURCES: C-3's index
  copy, the app's 553 TEI files, the installed bundle's JSON, the vector artifacts and the 553-shard
  copy. To those it adds a fifth item, the figure folders. Keeping C-3's unstripped copy isolates
  the text. The stripped copy §4 recommends removes a temptation E2 already guards, and needs no
  run of its own. A's block is v1.42's 221 lines, which no tier has run, so A's runs are also the
  first measurement of v1.41's R9 clauses.
- **Cells.** Opus 5.5 at `medium` and Sonnet 5.5 at `high`, with two runs an arm a cell: eight runs.
  Each run gets a scorer, a refuter and a judge on Fable 5.1 at `max`, and the harness's checks
  after each run, as in the reader-facing tier.
- **The rubric.** The 35 items, with C2 and R4 worded for both arms. C2 becomes "Reported the
  volume count and what every count is conditional on". R4 becomes "Flags results thin enough to
  reflect something other than the record: the copy, or the editors' selection". V1 to V6, V8, O4
  and O2′ stay as before. Two new items are scored in both arms and kept out of the guard: **X1**,
  the identity check run and its result reported; and **X2**, documents counted by the TEI's
  divisions or §2.3's predicate, never by an id pattern alone.
- **Readings, registered before the first run.**
  1. **Adoption: decision 115's guard.** B loses at most one more of the 35 items than A over its
     four runs, and no B run loses more than A's worst run.
  2. **The new rules work.** X1 and X2 are obeyed in at least three of B's four runs. A's figures
     are reported as the baseline.
  3. **The expected benefit, reported and not a gate.** S2 (counting surface) and S3 (variant
     split) in B against A. The reader-facing tier lost S3 in three of its twelve runs, behind O2
     and P6 at four each.
  4. **Cost, reported and not a gate.** Wall clock and output tokens a run, B against A. The
     question is whether making the TEI the default surface lengthens a run.
- **Before the first run.** A canary runs on the exact RESOURCES text, with the identity check as
  its known answer: 553 of 553 volumes agree, in order. The scorer is calibrated on two earlier
  runs' records under the reworded C2 and R4 and the new X1 and X2. Appendix A's worked figures
  are re-checked at the digest (runbook §7). The digest has not moved since the 2026-10-26 re-take.

### 6.3 The cost, in the runbook's units

A run with its three instruments cost about 2 weekly points and 3.6 to 4 Fable points in each of
the last three tiers. The vectors tier spent 8 weekly and 16 Fable points over 4 runs, the steering
tier 19 and 34 over 9, and the reader-facing tier 25 and 43 over 12, its calibration and canary
included (`Planning/Agentic-Harness-Runbook.md` §7).

| Part | Agents | Weekly points | Fable points | Wall clock | Output tokens |
|---|---|---|---|---|---|
| Canary | 1 | under 1 | 0 | about 5 minutes | small |
| Scorer calibration (two records) | 2 to 4 on Fable | about 1 | 2 to 5 | about 20 minutes | about 0.3 M |
| 8 runs with their scorers, refuters and judges | 32 | 16 to 17 | 29 to 32 | 4.5 to 5.5 hours one at a time; about 3 hours with each run's instruments overlapping the next run | 7 to 9 M |
| **The tier** | **35 to 37** | **17 to 20** | **31 to 37** | **3 to 6 hours** | **about 7.5 to 9.5 M** |

A pipelined run is paced by the 5-hour window as well as the week. Five or six overlapping agents
filled it at about 30 points an hour in the reader-facing tier. The plan notes that the meters reset
on 2026-11-04, so a tier that starts after that date has the week's whole allowance.

Two options, each only on the owner's word:
- **Twelve runs** (three an arm a cell) cost about what the reader-facing tier did, 25 weekly and
  43 Fable points, and give the guard more runs.
- **A third arm** carrying R16's SEMANTIC VECTORS section inside the block, the change decision 115
  bars without a new measurement, costs about 8 to 9 weekly and 14 to 16 Fable points more for four
  runs.

### 6.4 What the tier does not cover

- **The figure images.** Their section is outside the block (§5.10), so it needs no tier. If the
  owner later wants a figure rule inside the block, a one-run probe on a question about a mapped
  boundary would show whether an agent uses a figure without quoting from its pixels. It would cost
  about 2 weekly and 4 Fable points with its instruments.
- **The encoder.** It is excluded (§5.9). If it were counted, its measurement is judged text
  queries, not an agent run.
- **The text outside the block** (§5.1 to §5.5, §5.7 to §5.11). The tiers' rule measures the block,
  and these changes, like v1.37's and v1.42's, can go in without a run.

---

## 7. Found along the way

These are wrong under the present premise too. They are listed here, not fixed, since this
document changes nothing in the guide.

1. **The document predicate** (§4.2, §4.3): `GLOB 'd[0-9]*'` drops 647 documents. They are 628 in
   `frus1958-60v05mSupp` and 19 printed appendix documents in five 1981–1988 volumes. A run that
   uses the predicate silently drops the American Republics supplement of 1958–1960 whole. Adding
   `OR` a `page_ranges` start row gives exactly the TEI's 314,616 (§2.3).
2. **The undated share** (§4.3: "A meaningful share of the corpus is undated"; §6.4's undated
   query). At index version 71 no document is undated; the 1,187 undated rows the query counts are
   sections (§2.4). Whether a document *prints* no date is a TEI question the index cannot answer.
3. **§1's 552** (§5.2): the installed 1.0 (1787) manifest lists 553, and the owner's device index
   holds 553.
4. **§14.10's "34 bundled JSON resources"**, where builds 1776 and 1787 ship 38. **§14.11's "24.79
   MB the app ships"**, where the 38 total 29,136,429 bytes.
5. **§1's path, `Volumes/`**: the folder is `volumes/` on disk. That makes no difference on the
   Mac and matters on a case-sensitive copy.
6. **§14.9's 316,839**: no surface measured here gives it (§5.8).

---

## 8. Sources

- `Docs/Agentic-Analysis-Guide.md` v1.42, read whole; `Planning/Plan-Of-Record-2026-10-21.md`,
  decisions 112 and 115, §1's G1 item and §5; `Planning/Agentic-Harness-Runbook.md` §1, §2, §7
  and §8.
- The measured runs' resources: `workflow.mjs` in `Planning/c0-falsifier/`,
  `Planning/c0b-falsifier/` and `Planning/c2-long-session/`; `Planning/C0c-Falsifier-2026-09-06.md`
  and `Planning/C0d-Falsifier-2026-09-06.md`; `Planning/c3-reader-test/facts.md` and
  `prompts/runner.txt`; `Planning/C-3-Results-2026-10-26.md` §4 item 8 and §6;
  `Planning/C-3-Vectors-Tier-Design.md` and its results file; `prompts/runner_A.txt` in
  `Planning/c3-steering-tier/` and `Planning/c3-reader-facing-tier/`; the rubric and the results
  table of the reader-facing tier (`Planning/c3-reader-facing-tier/RUBRIC.md`,
  `Planning/C-3-Reader-Facing-Tier-Results-2026-10-31.md`).
- The measurements: `Planning/full-corpus-premise/` (its README lists each script, its output and
  its run time).
- The app's own descriptions: `CLAUDE.md` (figure images; `SemanticVectorsKit`'s identity rule) and
  `Docs/macOS-User-Manual.md` (Export as JSON).
