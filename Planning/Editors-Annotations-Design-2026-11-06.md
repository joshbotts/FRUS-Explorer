# Editors' annotations: what each volume carries, on its page and in Browse — a design, 2026-11-06

**Status: BUILT, 2026-11-06.** Lanes A to D merged as #1859, #1860, #1861 and #1862. The owner's "proceed with annotations design plan" took §9's recommendations 1–4, and lane B took decision 5 as B shipping alone. Decision 6 is drafted and not filed: `OH-Note-2026-11-06.md`, for the owner to file. §11 records where each lane departs from the design, and the fix of two of the axis's marks at index version 74.

**Amended the same day, after #1853 (index version 72).** That pull request closed the gap §3 found, so §3 now records it.
- Classification is now counted by the marking the index stores, re-counted from a full index at version 72.
- The word search that stood in for it missed what the app stores, and wrongly listed the four Public Diplomacy volumes as unmarked (§2.4, §3.2).
- The re-count found a second gap, in the note form the app always read: 8,865 markings the notes printed were not stored (§3.3, #1856).
- No other figure moved.

**Amended again after #1857 (index version 73),** which closed that second gap. The classification figures are now version 73's (§2, §4, §5), and §3.3 and decision 7 record the fix. Only classification's figures and the artifact's size estimate moved.

**Amended again for index version 74 (plan of record decision 119),** which reads `frus1941-43`'s Index of Persons as an index and counts the terms `frus1981-88v16`'s documents name on `@ana` (§11, after lane D). The survey's figures in §2 to §4 are its TEI pass's, `gloss/@target` alone, and stand as measured; the artifact links abbreviations in 310 volumes, not 309.

**Amended on 2026-11-08, for Lane 1 of `Editors-Annotations-Followups-2026-11-08.md`: a sixteenth layer, *Marked editorial omissions*.** Where the editors left out part of a document, the volumes published from Secretary Kellogg's 1925 order could say so in brackets, "[Here follows discussion of …]", "[Omitted here is the Table of Contents.]"; measured over the 553 volumes (`editors-annotations/omission-markers.out`), 482 volumes and 11,442 documents carry such a bracket, and 26 of the volumes were published before the order, so 456 carry the layer. The kit's `AnnotationCategory.editorialOmissions` sits beside `.excisions` in *Where it came from*, counted when one document does, and the file (schema version 2) stores each volume's publication year, on which the kit gates the layer; §5.2's table gains the row, and §11 the lane's departures. The design's other figures are as they were.

**What this is.** The owner asked two questions, two days apart.
- **2026-11-04:** when people tagging began, and in which volumes. The answer went into the Research Guide (#1851).
- **2026-11-06:**
  - Which other editorial annotation categories change across the corpus?
  - How could each be labelled on a volume's page in Browse?
  - How could a Browse surface be built around the categories?

§2 and §3 answer the first question from measurement. §4 to §7 are the design, §8 splits it into lanes and §9 asks for decisions.

**How it was measured.** Read-only, on 2026-11-06, with no subagent. The scripts, their outputs and their exact commands are in `Planning/editors-annotations/` (its `README.md`).
- **The TEI:**
  - One `ElementTree` pass over the 553 manifest volumes, read from the corpus clone at `6170e4b32`.
  - Each element is credited to its innermost `<div type="document">`.
  - A volume's figure for a category is the number of its documents that carry it.
- **The index:**
  - A copy of the Mac app's index at version 71, holding the same 553 volumes.
  - It answers what the TEI pass cannot: people tagging by the People browser's own rule, printed document numbers, despatch serials, and the classification the app stores.
  - For classification, a full index at version 72, built by `ResolvedEdgeIndexGenerator` through the kit's own pipeline at `v2` `dcf178ed`. It agrees with the copy at 71, volume by volume, on rows, people, persons, numbering and despatch serials.
  - Version 73's figures are version 72's plus the 8,865 markings #1857 stores. #1857 built both indexes and found those markings to be §3.3's gap, note for note (`tables.py`'s `stored73`).
- **The bases:**
  - 314,510 documents in the TEI, or 320,646 index rows wherever a figure says "rows". The rows also count a section's own printed text.
  - A volume **carries** a category in one of three ways:
    - a pervasive layer, when at least half its documents carry it;
    - a counted one (cross-references, excisions, editorial notes, Subject lines, participant lists, marginal notes), when one document does;
    - a front- or back-matter section, when the volume prints it.
- **Eras** are keyed by the subseries' first year. The manifest's earliest date is no use: it reaches back to enclosures centuries older than the volume (`frus1872p2v5` starts in 1620).
  - The nine late retrospective volumes are a band of their own, called "retro" below: Public Diplomacy ×4, the two Intelligence volumes, Iran and its second edition, and Guatemala. Their editors worked in the modern format, whatever era they cover.

## 1. In brief

- **The annotation layers arrive at different times.**
  - Abbreviations were linked a decade before people were tagged.
  - Source notes began in 1907, and changed form in 1955.
  - Marking senders and recipients runs the other way: universal in the 1860s, gone by the 1980s.
  - So no single "early or modern volume" flag describes a volume. Per-category labels do.
- **Four generations,** keyed to the era covered (§2.2):
  - **1861–1906:** headings name sender and recipient; there is an analytical List of Papers and no source notes.
  - **1907–1944:** file-number source notes, and footnotes become routine.
  - **1945–1954:** abbreviations, classification markings and editorial notes arrive; from 1951 also Lists of Persons, Notes on Sources, Subject lines and participant lists.
  - **1955 on:** the modern format, with numbered documents, "Source:" citations, marked excisions and document-to-document references.
- **What the app reads.**
  - It reads people, abbreviations, source notes, classification markings, cross-references, editorial notes, despatch numbers and footnotes.
  - It does not yet read Subject lines, participant lists, senders and recipients, or excisions.
  - Classification had two gaps, and this survey opened the lanes that closed both (§3):
    - the opener's marking, which the volumes covering 1932–1954 print, stored since index version 72 (#1853);
    - 8,865 notes from 1955 on whose marking sat past the note's second sentence, stored since version 73 (#1857).
- **The proposal:**
  - one bundled artifact, `volume-annotations-index.json`, from a new Tier 1 generator;
  - an **Editors' Annotations** section on every volume's page, on both platforms, before download;
  - an **Editors' Annotations** Browse axis, whose drills reuse the shared volume list and so get **Save as Scope…** with no new code.
- **What it costs:**
  - a new generator: one parse of the corpus (the measuring pass took 51 seconds), and an artifact of about 55 KB;
  - no index-version bump and no CloudKit schema change.

## 2. What the corpus shows

### 2.1 The categories

| Category | What the editors did, in the TEI | Volumes | Documents |
|---|---|---|---|
| **People tagged** | `persName/@corresp` into the volume's List of Persons (or `@ana`, one volume) | 288 | 115,302 (36.7%) |
| **Abbreviations explained** | `gloss/@target` into the List of Abbreviations | 309 | 112,938 (35.9%) |
| **Senders and recipients** | `persName`/`gloss` `type="from"`/`"to"` in the heading | 432 | 239,793 (76.2%) |
| **Subject lines** | `list type="subject"` | 256 | 32,645 (10.4%) |
| **Meeting participants** | `list type="participants"` | 297 | 12,798 (4.1%) |
| **Source notes, file-number form** | `note type="source" rend="inline"` above the heading: `File No. 763.72119/1098` | 248 | 190,875 (60.7%) |
| **Source notes, "Source:" form** | a source footnote with the full archival citation | 230 | 74,702 (23.8%) |
| **Classification markings** | in the opener above the dateline (to 1954), then inside the source note | 309 | 114,130 rows (35.6%) |
| **Excisions marked** | "[… not declassified]" | 208 | 6,724 (2.1%) |
| **Despatch numbers** | the post's own serial, `No. 74.]` (#965) | 147 | 45,145 rows (14.1%) |
| **Documents numbered in print** | the heading opens "12. Telegram From …" | 229 | 78,902 rows (24.6%) |
| **Cross-references to documents** | `ref target="#d…"` | 254 | 31,493 (10.0%) |
| **Cross-references to footnotes** | `ref target="#d…fn…"` | 231 | 12,653 (4.0%) |
| **Cross-references to other volumes** | `ref target="frus…"` | 390 | 8,644 (2.7%) |
| **Page references** | `ref target="#pg_…"`: "see p. 123" | 407 | 51,489 (16.4%) |
| **Editorial notes** | `div subtype="editorial-note"` | 296 | 8,466 (2.7%) |
| **Footnotes in most documents** | untyped `note` | 427 | 186,665 (59.4%) |
| **Marginal notes** | `seg type="margin"` | 76 | 1,517 (0.5%) |

The front and back matter changes too: List of Persons 284 volumes (by the three section ids the parser names), List of Abbreviations 313, Note on Sources 259, Preface 377, the analytical List of Papers 152, a printed index 456, the Note on U.S. Covert Actions 45, a press release 56, a volume summary 23, errata 57.

The figures above need five readings:
- **People tagged:** 288 is the People browser's rule, read from the index, and the TEI rule picks out the same 288 volumes. Against the 284 Lists of Persons:
  - One list has no links: `frus1977-80v27`'s.
  - Five tagged volumes have no list under those ids. Three are the split-set second parts that borrow a sibling's list. The other two are the 1873 parts, whose lists the indexer finds under other ids.
  - `frus1981-88v16` names its people in a document-level `@ana` and is counted with the 288.
- **Source notes:** `frus1870` is left out. It encodes its paper numbers ("No. 3.", the number its List of Papers gives) as source notes in 295 of 300 documents, and every one is "unrecognized" in `source-provenance-index.json`. This line called them despatch numbers until the note to the Office (`OH-Note-2026-11-06.md`) read them against the list; the despatch grammar reads both forms alike, so the rule below keeps them out either way.
- **Note on Sources** is read by the app's own section rule (`FRUSDocumentParser.structuralKind`). That rule finds `frus1969-76ve09p2`'s untyped one, which a `@subtype`-only rule misses (258).
- **Classification** is the marking the index stores at version 73: the source note's, from any sentence after the first, or else the opener's. That is what Search's rows and Source Explorer show. A word search over the TEI stood here until #1855 (§3.2).
- **Editorial notes** are what the TEI tags as such. 138 of them carry their own source note, and 119 of those print an opener and a dateline: they are printed documents, 132 of them in the volumes covering 1932–1954 (#1854).

### 2.2 By era covered

Volumes carrying each category, out of the volumes in each era (`tables.out` §4):

| | 1861–98 | 1899–1913 | 1914–19 | 1920–31 | 1932–44 | 1945–50 | 1951–54 | 1955–68 | 1969–80 | 1981–92 | retro |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **volumes** | 62 | 20 | 35 | 32 | 77 | 59 | 38 | 114 | 93 | 14 | 9 |
| People tagged | 2 | 0 | 14 | 0 | 7 | 8 | 28 | 114 | 92 | 14 | 9 |
| Abbreviations explained | 0 | 0 | 0 | 0 | 3 | 41 | 38 | 113 | 92 | 13 | 9 |
| Senders and recipients | 58 | 18 | 27 | 31 | 76 | 55 | 37 | 98 | 29 | 0 | 3 |
| Subject lines | 0 | 0 | 0 | 0 | 0 | 2 | 26 | 114 | 91 | 14 | 9 |
| Meeting participants | 3 | 2 | 15 | 15 | 6 | 1 | 27 | 114 | 92 | 14 | 8 |
| Source notes, file numbers | 0 | 8 | 34 | 32 | 77 | 59 | 38 | 0 | 0 | 0 | 0 |
| Source notes, "Source:" | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 114 | 93 | 14 | 9 |
| Classification markings | 0 | 0 | 0 | 0 | 3 | 40 | 38 | 114 | 91 | 14 | 9 |
| Excisions marked | 0 | 0 | 0 | 0 | 0 | 2 | 5 | 89 | 91 | 14 | 7 |
| Despatch numbers | 55 | 18 | 13 | 25 | 33 | 1 | 2 | 0 | 0 | 0 | 0 |
| Numbered in print | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 113 | 93 | 14 | 9 |
| Cross-refs to documents | 2 | 0 | 0 | 0 | 0 | 4 | 22 | 111 | 92 | 14 | 9 |
| Cross-refs to other volumes | 13 | 10 | 12 | 7 | 52 | 53 | 34 | 97 | 90 | 14 | 8 |
| Page references | 38 | 19 | 35 | 32 | 77 | 59 | 38 | 99 | 8 | 0 | 2 |
| Editorial notes | 1 | 0 | 3 | 0 | 6 | 43 | 38 | 110 | 76 | 11 | 8 |
| Footnotes in most documents | 1 | 0 | 15 | 27 | 72 | 58 | 38 | 110 | 83 | 14 | 9 |
| Marginal notes | 27 | 18 | 21 | 9 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |
| List of Persons | 0 | 0 | 12 | 0 | 6 | 8 | 28 | 114 | 93 | 14 | 9 |
| Note on Sources | 0 | 0 | 0 | 0 | 0 | 1 | 29 | 113 | 93 | 14 | 9 |
| List of Papers (analytical) | 48 | 17 | 23 | 32 | 28 | 4 | 0 | 0 | 0 | 0 | 0 |
| Printed index | 34 | 18 | 33 | 32 | 74 | 58 | 24 | 110 | 62 | 6 | 5 |
| Note on U.S. Covert Actions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 9 | 33 | 3 | 0 |

The file-number row's first cell is 1 in `tables.out`: `frus1870`, whose "source notes" are despatch numbers (§2.1).

The classification row counts what the index stores at version 73. At 72, §3.3's gap held four volumes for 1955–68, two for 1969–80 and one for 1981–92 under half, and those cells read 110, 89 and 13 (`tables.out` §7).

**Read as four generations:**

1. **1861–1906, the annual "Papers Relating…".**
   - **What the volumes carry:**
     - Nearly every heading names sender and recipient (58 of 62 volumes for 1861–98).
     - They carry despatch numbers (55) and open on an analytical List of Papers (48).
     - Many carry "see p." references (38), marginal notes (27) and a printed index (34).
   - **What they don't:** source notes; and footnotes in most documents (1 volume of 62).
2. **1907–1944.**
   - Source notes arrive with the volumes for 1907, as the file number printed above the heading. Eight of the 20 volumes for 1899–1913 carry them, and 34 of 35 for 1914–19.
   - Footnotes become routine (27 of 32 for 1920–31).
   - Prefaces appear (42 of 77 for 1932–44), and the List of Papers fades (28 of 77).
   - Lists of Persons appear only in special volumes: the WWI supplements and the Russia volumes (12 of 35 for 1914–19), and 6 of 77 for 1932–44.
3. **1945–1954.**
   - **From 1945:** abbreviations are listed and linked (41 of 59). Classification markings are printed above the dateline (40 of 59), and editorial notes appear (43 of 59).
   - **From 1951:** Lists of Persons (28 of 38), the Note on Sources (29), Subject lines (26), participant lists (27) and references to documents (22).
   - **What stays:** source notes keep the file-number form, documents stay unnumbered, and page references remain (38 of 38).
4. **1955 on, the modern format.**
   - **New:**
     - Documents are numbered in print (113 of 114 for 1955–68, all after).
     - Source notes become "Source:" citations (all), which carry the classification (§2.4 has the exceptions).
     - Excisions are marked (89 of 114; 91 of 93; 14 of 14).
   - **Fading:**
     - Page references (8 of 93 for 1969–80).
     - Sender and recipient markup (29 of 93, then 0 of 14).
     - The printed index (62 of 93, then 6 of 14).
   - **Late arrivals:** the Note on U.S. Covert Actions (45 volumes, all but one published since 2000) and press releases (55 of 56 published since 2000).

The same tables by publication year are `tables.out` §5. Publication year explains the 1979–1989 transition. The 1952–54 volumes were published 1979–1989 and carry the new lists. The 1955–57 volumes, published from 1985, are where numbering and "Source:" notes begin (20 of the 33 volumes published 1985–89).

### 2.3 Coverage inside the volumes that carry a category

Being carried does not mean every document carries it, and the gap means nothing. A document that names no one cannot be tagged.
- **People:** the 288 tagged volumes have a median 98.0% of documents linked. Fifteen fall below 90%, the lowest at 72.5% (`frus1873p1v2`).
- **Abbreviations:** median 91.5%, and 135 of 309 below 90%. Many documents use no abbreviation.
- **Numbered documents:** median 100%; the lowest is 95.5%.

That is why §5 gives a category no "partial" state.

### 2.4 The exceptions inside the modern format

Of the 230 volumes covering 1955 on, retrospectives included (`tables.out` §6):
- **People tagged:** missing only in `frus1977-80v27`. It prints a 153-name List of Persons, and its TEI links no name to it.
- **Abbreviations:** missing in `frus1955-57v03mSupp`, `frus1977-80v27`, and `frus1981-88v16`. The last names abbreviations in its document-level `@ana`. The reader has listed them below each document since #1599; the artifact counts them since index version 74's change (§11), so the app does not count the volume as lacking them.
- **Numbered in print:** missing only in `frus1958-60v05mSupp`.
- **Cross-references to documents:** missing in the three microfiche supplements and `frus1969-76v42`.
- **Classification:** under half the rows store a marking in 2 volumes, `frus1969-76v01` (40 of 123) and `frus1977-80v01` (74 of 163).
  - **At version 72 there were 9.** The other seven print one in at least half their documents (50% to 96%), in a note sentence the parser did not read until #1857 (§3.3): the three microfiche supplements, `frus1964-68v07`, `frus1969-76v29`, `frus1969-76v38p1` and `frus1989-92v31`.
  - **The word search listed 14,** the four Public Diplomacy volumes among them. It had no word for "No classification marking", which half of PubDip Vol. VI's markings stored at 72 read.
- **Abbreviation lists before 1945:** four volumes, `frus1941-43`, `frus1943`, `frus1943CairoTehran` and `frus1944Quebec`.

### 2.5 Layers that need no label

These are constant across the corpus, so a label would tell a reader nothing:
- **Machine-readable dates:** every document has the corpus build's `frus:doc-dateTime-min`. 13,142 documents (4.2%) have a date the build inferred and flagged (`date@ana="#date_undated-inferred-from-document-head"`).
- **Places in datelines.**
- **Printed page numbers and page scans:** 552 and 551 volumes.
- **HSG's document number:** every document has one.

Machine-derived layers stay out too: the Topic Index's string-matched subjects, semantic vectors and archival resolution. They are the app's readings, not the editors'.

### 2.6 What the app reads today

| Category | Read by |
|---|---|
| People tagged | The People browser, Person analytics, name links in the reader, related documents by shared people |
| Abbreviations | Term definitions in the reader (`gloss` → `glossLookup`), the `terms` table |
| Source notes | Source Explorer, the Archives axis, archival facets (`document_sources`) |
| Classification | `ClassificationChip`: in the reader beside the source note, for the note's marking; in Search's rows and Source Explorer for either form, the opener's since index version 72 (#1853, §3.1). The reader prints the opener's marking as the volume does |
| Despatch numbers | `document_cache.despatch_serial` (#965, index v45) |
| Numbered documents | `document_number` is HSG's `@n` for every document (index v10); nothing records whether the volume printed it |
| Cross-references | The cross-reference graph, page links, whole-volume links |
| Editorial notes | `is_editorial_note` |
| Footnotes | The reader; footnote citations feed `external-citation-index.json` |
| Sections | The volume's structure list once downloaded; the List of Persons and Sources views |
| Senders and recipients | **Not read.** The heading renders; `gloss type="from"` is deliberately not a link (`ASTToRenderNodeConverter`) |
| Subject lines, participant lists | **Not read.** `ListType` knows `ordered`, `unordered` and `simple`, so both render as plain lists |
| Excisions | **Not read** as a category |

## 3. Gaps found on the way: classification the index did not store

### 3.1 The opener's marking, closed by #1853

The marking moved. Volumes covering 1932–1954 print it above the dateline:

```xml
<opener><seg rendition="#left"><hi rend="smallcaps">secret</hi></seg>…
```

From the 1955–57 subseries on, it is a sentence of the "Source:" note instead, and until index version 72 the index read only that form. This survey found the gap, and a lane of its own closed it.
- **#1853** (`dcf178ed`) reads the opener's marking and stores it where the note prints none.
- **Where it shows:** Search's rows and Source Explorer. The reader prints the marking as the volume does.

Documents with a marking, by era (`tables.out` §7):

| | 1932–44 | 1945–50 | 1951–54 | 1955–68 | 1969–80 | 1981–92 | retro |
|---|---|---|---|---|---|---|---|
| stored at version 71 | 0 | 0 | 0 | 34,558 | 22,068 | 3,603 | 1,865 |
| stored at version 72 (#1853) | 1,117 | 22,786 | 19,260 | 34,558 | 22,068 | 3,603 | 1,865 |
| **stored at version 73 (#1857, §3.3)** | 1,117 | 22,786 | 19,260 | 39,200 | 25,517 | 4,131 | 2,111 |
| this survey's word search | 1,157 | 21,640 | 16,146 | 37,555 | 23,222 | 3,824 | 1,741 |

- **The gain:** the 174 regular volumes covering 1932–1954 went from no stored marking to 43,163, and 81 of them now have one in at least half their rows. Three volumes for 1919 gained 8 more.
- **What #1853 leaves unstored**, by its own count:
  - 107 marked documents the TEI wraps as editorial notes (#1854);
  - 18 whose only typed source note is a footnote on a lot designation;
  - 10 with no source note;
  - 83 whose marking is an enclosure's.

### 3.2 The word search this design first counted with

It found 38,943 marked documents in those 174 volumes, where the index now stores 43,163. It made two errors:
- **Vocabulary.** 7,201 documents store a value it had no word for (`tables.out` §7). The commonest are "No classification marking" (4,793), "Restricted" (1,288) and "Official Use Only" (674), and their compounds. That is how it listed the four Public Diplomacy volumes as unmarked.
- **Tokenizing.** It read text with `itertext()`, which glues the lines of an `<lb/>` nested in `<hi>` into one word ("secretpriority"). #1853 counts 2,841 markings printed that way.

### 3.3 A second gap, in the note form the app always read, closed by #1857

Until index version 73, the note's parser, `SourceNoteParser.classificationMarking(fromSourceNote:)`, took the marking from the note's second sentence. A sentence ends at any `.` followed by a space and a capital. So **8,865 notes in 218 volumes, all from 1955 on, printed a marking the index did not store** (`tables.out` §12):

| Notes | Why the parser misses the marking | For example |
|---:|---|---|
| 4,679 | a period inside the citation moves it out of second place: an abbreviation ("Gen.", "Vol. IX"), an initial, "U.S." | "…Lot 61 D 167, Iran, U.S. Policy Towards (NSC 5504). Top Secret." |
| 2,216 | the citation ends on a volume or part number | "…Country Files, Far East, China, Vol. I. Secret. Sent for action." |
| 1,970 | it is second, but a remark that opens with a digit joins its sentence, and the parser refuses digits | "…China. Secret; Sensitive; Eyes Only. 1 page of source text not declassified." |

- **How it was counted.** `note_marking_gap.py` replicates the parser.
  - The replica reproduces all 62,094 markings the index at 72 stores from notes.
  - It then reads every later sentence, and a sentence's head before a digit-led remark, through the parser's own gates.
  - Twenty notes drawn at random from the 8,865 all print a real marking.
- **Where it fell.**
  - China, 1969–1972, stored a marking for 182 of its 280 documents at version 72, and stores 260 at 73.
  - The three microfiche supplements went from 33, 10 and 19 to 553, 418 and 703.
- **Filed as #1856, and fixed by #1857** (`cc1fea21`, index version 73). It ships with 72 in the next release, so one re-index covers both (plan of record decision 118).
  - **The reading:** the parser offers its gates every sentence after the first, each as far as a stop followed by a digit, and keeps the first that passes. Sentence 2 is offered first, so every marking read before reads the same. The gates are unchanged.
  - **The boundary regex is unchanged.** It also splits the citation sentence, which keys `collection-authority.json`.
  - **`secondSentenceClassificationMarking(fromSourceNote:)` keeps the old reading** for the Archives Visit packet's designation cut (`TripPacketBuilder.centralFileDesignation(_:)`). Otherwise "…China, Vol. I. Secret." would be cut at "Vol.".
  - **What #1857 measured:** the 8,865 markings it stores are this gap, note for note and value for value. No value stored at 72 changed, and nothing else in the index moved.
  - **When readers see it:** the chips follow the code at once, since every surface re-parses the note before it reads the stored value. The stored column follows each library's re-index.

### 3.4 What this means for the design

- §4's generator counts what the index stores, through the index's own extractors, so a label and the chips agree. Both gaps are closed, so the counts in this design are version 73's.
- A later change to either extractor moves the labels and the chips together, and regenerates the artifact (§4).

## 4. The data: `volume-annotations-index.json`

**Why a bundled artifact, not the device's index.** The labels earn their place before download. "Does this volume tag people?" is a question asked when choosing what to download, and the device's index answers only for volumes already downloaded. The volume page already shows Top subjects for undownloaded volumes from a bundled aggregate. This follows that precedent.

**What it holds,** per volume: counts, never verdicts. The kit decides what a count means, so a threshold can change without regenerating. A sketch:

```json
{
  "schemaVersion": 1,
  "generated": "2026-11-06",
  "corpusCommit": "6170e4b32",
  "volumes": {
    "frus1969-76v17": {
      "documents": 280, "historicalDocuments": 268,
      "lists": { "persons": 325, "terms": 470 },
      "counts": { "people": 279, "abbreviations": 278, "correspondents": 161,
                  "subjects": 137, "participants": 67,
                  "sourceCitation": 263, "sourceFileNumber": 5, "classification": 260,
                  "excisions": 31, "despatch": 0, "numbered": 280,
                  "xrefDocuments": 131, "xrefFootnotes": 65, "xrefVolumes": 89, "xrefPages": 0,
                  "editorialNotes": 12, "footnotes": 243, "marginalNotes": 0 },
      "sections": ["preface", "sources", "terms", "persons",
                   "note-on-covert-actions", "index", "errata"]
    }
  }
}
```

The sketch is keyed by name, for reading. Its size (`tables.out` §11):
- Keyed by name in every volume, it is 257,803 bytes compact.
- Columnar, it is 55,333 bytes: the 19 count names once, each volume's counts as one array in that order, and its sections as indices into one list of 74 section names.

The columnar form is recommended.

**The generator,** `VolumeAnnotationsIndexGenerator`, takes the usual shape: a `…Core` library, a thin executable and a `…Tests` suite. It links FRUSCoreKit, as `ResolvedEdgeIndexGenerator` has since #1693, and SourceNoteKit. Each category is counted **by the app's own rule wherever the app has one**, because a label that disagrees with the People browser is worse than no label:
- **People:** a `persName` link that resolves into the volume's List of Persons, or into the sibling's list for the three split-set second parts. Plus the document-level `@ana` (`IndexingPipeline.annotatedPersonRefs`).
- **Abbreviations:** a `gloss` link that resolves into the volume's List of Abbreviations.
- **Source notes:** a `note[@type="source"]`, unless the despatch grammar reads its whole text as a despatch number. That rule is what keeps `frus1870` out.
  - **The form:** "Source:" when the note opens with that word, otherwise the file-number form. The TEI pass split them by `@rend="inline"`; the lane checks that the two rules agree.
- **Classification:** a document the index stores a marking for, since version 73. Into the document's `document_sources` row, the index writes the source note's marking (`SourceNoteParser.classificationMarking(fromSourceNote:)`, the first sentence after the first that passes its gates) or, where the note prints none, the opener's (`IndexingPipeline.extractOpenerClassification(from:)` over the parser's nodes, through `SourceNoteParser.classificationMarking(fromOpenerLines:)`).
  - **What that leaves out:** a document with no source note has no row, so stores none. Nor does one the TEI wraps as an editorial note, whose nodes the extractors do not enter (#1854). §3.1 lists the four groups #1853 leaves unstored. The generator calls the same extractors on the same nodes, so it leaves out the same documents.
  - **Lane A makes two kit functions public.** `IndexingPipeline.extractSourceNote(from:)` and `extractOpenerClassification(from:)` are internal to FRUSCoreKit, and the generator is a package target outside it. The two `SourceNoteParser` functions are public already.
  - **Never a copy of the rule.** The word search this design first counted with missed thousands of the markings the app shows (§3.2).
- **Numbered in print:** the heading opens with the document's number. This is the same test `index_extract.py` applies to the stored heading.
- **Sections:** `FRUSDocumentParser.structuralKind`.

**Its contracts:**
- Inputs `VOLUMES_DIR` and `MANIFEST`, so it is **Tier 1** in `BundledArtifactProvenance.table` (`.frusText`); that suite fails until the row exists.
- `CORPUS_COMMIT` is required and recorded, like `CorpusStructureSweepGenerator`'s.
- A re-run at a pinned commit and `GENERATED_DATE` is byte-identical.
- It refuses to write on a manifest volume missing from `VOLUMES_DIR`, or on a corpus where no volume carries people tagging.
- The run is one parse of each volume. The Python pass that measured this design took 51 seconds.
- It calls the index's own extractors, so an index bump that changes one of them regenerates it, as every bump regenerates `cited-page-map.json`.
- It joins Tier 1 of `New-Volume-Release-Plan.md` §3, which becomes 19 artifacts and 13 runs.

**In the code:**
- `FRUSCoreKit/Browser/VolumeAnnotations.swift` holds the category list, its families, what each count means, `carries(_:)` and the onset rule. It is Foundation-only, so the generator, the app and the web edition read one definition.
- The app's `VolumeAnnotationsStore` reads the bundle, as `VolumeSubjectProfilesStore` does.

**The onset rule** gives each category the era its absence explains. It is the first era band in §2.2 from which every later band has at least 75% of its volumes carrying the category. The retrospectives are left out, since they sit at no single point in the series' chronology. On today's corpus (`tables.out` §11):

| Category | Onset |
|---|---|
| Source notes | 1914–19 (first carried in 1907) |
| Abbreviations, Note on Sources | 1951–54 |
| Classification | 1951–54 (68% for 1945–50) |
| Editorial notes | 1951–54 (82% and 79% in the last two bands) |
| People | 1955–68 (28 of 38 for 1951–54 is 74%, just under the line) |
| Numbering, "Source:" notes, document references, excisions | 1955–68 |

The tighter rule, every later *subseries* at 90%, lands editorial notes on 1989–92 because of a handful of exceptions. It lands classification on the 1950 subseries. At version 72 it found no onset for classification at all, because §3.3's gap held the last subseries, 1989–92's one volume, under half (`tables.out` §10 and §12). That is why the rule works by band.

## 5. On each volume's page: "Editors' Annotations"

### 5.1 Name and place

- **Section title: "Editors' Annotations".**
  - It sits beside the app's own "Your Annotations", the reader's notes and highlights.
  - It avoids "Apparatus", which the Collections editor already uses for its generated blocks.
- **iPhone and iPad:** in `VolumeView`, the first section after the metadata header, above Tags and Top subjects.
  - When a page link opened the page (#1766), the not-downloaded section keeps its place first: the reason comes before anything else.
- **Mac:** in `CorpusVolumeDetailView`, below the title and Top subjects.
  - It is height-bounded as `BoundedSubjectsBlock` is. That file's history (1.5, 1.7) records how an unbounded block blanked the column.
- **One view, `VolumeAnnotationsSection`, mounted by both pages.** This is the #900 precedent: `SemanticStorageSection` serves both storage hubs.
  - The two volume pages are hand-maintained twins, and a section written twice is two places to drift.
- **It renders for every volume, downloaded or not.**

### 5.2 Rows

Three groups, each row a symbol, a label and one line of counts. The symbols are proposals for the lane to check in SF Symbols.

| Group | Label | Symbol | Line, when the volume carries it |
|---|---|---|---|
| Who is named | People tagged | `person.2` | 279 of 280 documents · 325 people listed |
| | Abbreviations explained | `character.book.closed` | 278 of 280 documents · 470 terms listed |
| | Senders and recipients | `arrow.left.arrow.right` | 502 document headings |
| | Subject lines | `text.alignleft` | 137 documents |
| | Meeting participants | `person.3` | 67 documents list who attended |
| Where it came from | Source notes | `archivebox` | 268 documents · archival citations ("Source: …"), *or* · file numbers above the heading |
| | Classification markings | `lock` | 260 documents |
| | Excisions marked | `eye.slash` | 31 documents with text not declassified |
| | Marked editorial omissions (2026-11-08, the follow-ups plan's Lane 1) | `text.badge.minus` | 32 documents with editorial omissions marked |
| | Despatch numbers | `number.circle` | 347 documents |
| How it connects | Numbered documents | `number` | Documents 1–280 |
| | Cross-references | `arrow.triangle.branch` | 131 documents cite this volume's documents · 89 cite other volumes · 226 cite printed pages |
| | Editorial notes | `text.bubble` | 12 |
| | Footnotes | `note.text` | 243 of 280 documents |
| | Marginal notes | `text.append` | 1 document |
| | Printed aids | `books.vertical` | Preface · Sources · Abbreviations · Persons · Note on U.S. Covert Actions · Index · Errata |

**States.**
- **No partial state.** A row is either in the volume or not, and its counts carry the coverage. §2.3 is why: 15 fully tagged volumes sit below 90% of documents, and a half-filled glyph would read as missing tags.
- **"Not in this volume (n)"** is a disclosure, collapsed by default.
  - It lists only the categories that are series-wide: people, abbreviations, source notes, classification, numbering, references to documents, editorial notes and the Note on Sources.
  - The era-bound features (senders and recipients, despatch numbers, marginal notes, the List of Papers, page references) appear when present and are never listed as missing. An 1890 volume is not "missing" a 1955 practice in the same sense that a 1955 volume would be.
  - Each absent row gives its onset (§4): "Standard in the volumes covering 1955 on." People adds "Search the names instead."

### 5.3 Three volumes, as they would read

```
China, 1969–1972 · 280 documents
WHO IS NAMED
  People tagged            279 of 280 documents · 325 people listed
  Abbreviations explained  278 of 280 documents · 470 terms listed
  Subject lines            137 documents
  Meeting participants     67 documents list who attended
WHERE IT CAME FROM
  Source notes             268 documents · archival citations (“Source: …”)
  Classification markings  260 documents
  Excisions marked         31 documents with text not declassified
HOW IT CONNECTS
  Numbered documents       Documents 1–280
  Cross-references         131 cite this volume’s documents · 89 cite other volumes
  Editorial notes          12
  Footnotes                243 of 280 documents
  Printed aids             Preface · Sources · Abbreviations · Persons ·
                           Note on U.S. Covert Actions · Index · Errata
```

```
Indochina, 1952–1954, Part 1 · 801 documents
WHO IS NAMED
  People tagged            787 of 801 documents · 176 people listed
  Abbreviations explained  633 of 801 documents · 264 terms listed
  Subject lines            130 documents · Meeting participants 81
WHERE IT CAME FROM
  Source notes             759 documents · file numbers above the heading
  Classification markings  736 documents
HOW IT CONNECTS
  Cross-references         60 cite this volume’s documents · 91 cite other volumes ·
                           226 cite printed pages
  Editorial notes          47 · Footnotes 650 of 801 documents
  Printed aids             Preface · Introduction · List of Sources ·
                           List of Abbreviations · List of Persons
▸ Not in this volume (2)   Numbered documents · Excisions marked
```

```
1890 · 502 documents
WHO IS NAMED
  Senders and recipients   502 document headings
WHERE IT CAME FROM
  Despatch numbers         347 documents
HOW IT CONNECTS
  Cross-references         12 cite printed pages
  Footnotes                27 of 502 documents
  Marginal notes           1 document
  Printed aids             List of Papers · Alphabetical Index
▸ Not in this volume (8)   People tagged · Abbreviations · Source notes · Classification ·
                           Numbered documents · References to documents · Editorial notes ·
                           Note on Sources
```

### 5.4 Behaviour and copy

- **Tapping or clicking a row** opens that category's page (§6), with this volume marked in its lists. An absent row opens it too: the page explains the practice.
- **VoiceOver:** each row is one element. It reads "People tagged: 279 of 280 documents; 325 people listed." An absent row reads "Not in this volume: people tagged. Standard in the volumes covering 1955 on." The group headers are headers.
- **Dynamic Type:** rows wrap and never truncate.
- **The rows describe the volume, never the app.**
  - "Classification markings 736 documents" says what the editors printed in vol. XIII.
  - Where the app reads less than the print, the count is the app's, so a row never claims a marking the app cannot show. At version 72 China's row would have read 182; since #1857 it reads 260.
  - It promises nothing about the app. Since #1853 a marked document in vol. XIII does show a chip, in Search's rows and Source Explorer, but the category page is where the app's use of each layer is said.
- **Copy:**
  - Every new string is `String(localized:)` and brings its EditableContent block (`07-Search-and-Browse.md`), with a line in `Amendment-Log.md`.
  - The category explanations are owner-editable prose.
  - No count and no era is written into copy. Each comes from the artifact. `New-Volume-Release-Plan.md` §7.1 is the cost of the other way: ten strings hard-coded "552".

## 6. In Browse: an "Editors' Annotations" axis

It follows #1051's axis pattern:
- **The logic:** a pure `AnnotationsAxis` enum, testable without views.
- **iPhone and iPad:** a "Browse by" tile in `CorpusView`, with `BrowserViewModel` levels `.annotations` and `.annotationCategory(id)`.
- **Mac:** a `CorpusSidebarItem.annotations` in the corpus browser's Browse section, with a `CorpusNavValue.annotationCategory(id)`.
- **Drills:** every list is a `VolumeListSpec` in the shared `VolumeListView`. That list already gives selection, the row badges and **Save as Scope…**.

**The root.** The categories in §5's three groups.
- Each row shows "288 of 553 volumes" and an era strip: eleven cells, one per §2.2 band, shaded by the share of its volumes that carry the category.
- The strip's accessibility value is a sentence: "288 of 553 volumes; standard in the volumes covering 1955 on."
- **On regular width** (iPad, the Mac), the strips stack into one matrix: categories by eras, §2.2's table drawn. A cell opens that era's volumes for that category.
- The matrix is the place to see the four generations at once.

**A category's page:**
- **What the editors did,** in a paragraph (owner-editable).
- **When it became standard:** the onset.
- **What the app does with it,** linked: the People browser and Person analytics for people; Source Explorer for source notes. Or plainly "Not used by the app yet".
- **The strip at full size.**
- **Two drills:** "Volumes with it (288)" and "Volumes without it (265)". Source notes adds one drill per form.

**The drill's spec,** for people:

| Field | Value |
|---|---|
| `axisKey` | `annotation:people:with` |
| `title` | People Tagged |
| `caption` | "288 of 553 volumes. A volume counts when at least half its documents link a name to its List of Persons." |
| `accessories` | per volume, "279/280" |
| `notes` | the amber line for an anomaly: "Prints a List of Persons; its documents' names are not linked." for `frus1977-80v27` |

**Save as Scope** makes "volumes with people tagged" a search scope at once. That is the most direct answer to the problem the people analysis started from.

**Later, not in the first lane:**
- Combining categories, for example people tagged and "Source:" citations and excisions marked, as one filter that builds one spec.
- Captions on the People browser and Person analytics ("People are tagged in 288 of 553 volumes"), linking to the people page. Today a reader studying an 1890s figure finds nothing and is not told why.

## 7. Documentation owed

- Both user manuals: the volume page's section and the new axis, in each platform's Browse chapter.
- The Research Guide: one contract sentence. Pages 5–7 state what a reader can do, never where the controls are (`ArchivalLibraryQueryTests` and `EmbeddedMarkdownLinkTests`). The People section's paragraph from #1851 is the natural place to point at it.
- `Docs/Agentic-Analysis-Guide.md`: the new artifact's contract, and a version-history entry.
- `Planning/Generators-Runbook.md`: the generator's entry. `CLAUDE.md`'s generator table: its row.
- `New-Volume-Release-Plan.md` §3: the Tier 1 row.
- `Planning/UI-Test-Destinations-Runbook.md` and `CLAUDE.md`'s suite table: any new UI suite's devices.
- `Planning/DEVELOPMENT-PLAN.md` once built.

## 8. Lanes

| Lane | What | Depends on | Gates |
|---|---|---|---|
| **A. Data** | The kit's `VolumeAnnotations`; `IndexingPipeline.extractSourceNote(from:)` and `extractOpenerClassification(from:)` made public (§4); the generator, its tests and the artifact; the provenance row; `VolumeAnnotationsStore`; the runbook, `CLAUDE.md` and release-plan rows; `xcodegen` for the new resource, then the scheme restore | — | `swift build --target FRUSCoreKit`, `swift test`, the unit target, the Mac build. No index bump, no CloudKit change |
| **B. Volume page** | `VolumeAnnotationsSection` on both platforms; copy and EditableContent; both manuals | A | iPhone 17 and iPad Pro 13-inch (M5) UI runs, `OS=27.0`; the Mac in the check copy; VoiceOver labels; AX5 |
| **C. Browse axis** | `AnnotationsAxis`, the tile, the sidebar item, the category page, the drills | A | The same devices. C touches `MacCorpusBrowserWindow.swift`, as B does, so B and C run one after the other, not side by side |
| **D. Matrix and links** | The regular-width matrix; the People browser and Person analytics captions; the guide's sentence | B, C | The same |

**The generator's parity suite is lane A's real guard.** Its fixtures are trimmed real TEI, one per case:
- `frus1890`;
- `frus1918Supp01v01`;
- `frus1952-54v13p1`, with its opener classification;
- `frus1969-76v17`;
- `frus1932v04`, a borrower, with its sibling's list;
- `frus1981-88v16`, with `@ana`;
- `frus1870`, with its paper numbers as source notes;
- `frus1917-72PubDipv06`, whose notes record "No classification marking";
- a document whose opener nests an `<lb/>` inside `<hi>` (#1853's `OpenerClassificationTests` names them), and one from `frus1941-43` that the TEI wraps as an editorial note (#1854).

For each fixture, the generator's people, abbreviation, source-note, classification and numbering counts must equal what `IndexingPipeline` stores for the same file. Package tests can run the pipeline (`IndexingTestSupport.swift`). A label that disagrees with the People browser is the failure this suite exists to catch.

## 9. Decisions for the owner

1. **The name**, "Editors' Annotations", for the section and the tile. *Recommended:* it pairs with "Your Annotations" and stays clear of the Collections editor's "Apparatus".
2. **Whether the page shows layers the app does not read yet:** Subject lines, participants, senders and recipients, excisions. *Recommended: yes.* They describe the volume, and what the owner asked was what each volume carries. The category page says plainly that the app does not use them yet.
3. **No partial state:** in or not, with counts (§5.2). *Recommended.*
4. **The thresholds:** half the documents for a pervasive layer, and 75% by band for the onset. *Recommended,* with the figures in §2.3 and §4 behind them.
5. **The order:** A, then B, then C, then D. Should B or C ship alone if the other slips?
6. **What to report to the Office of the Historian: drafted, not filed** (`OH-Note-2026-11-06.md`, 2026-11-06, at the owner's "Draft it"). The owner files it; its B.1 says where. The draft reports:
   - `frus1870`: three papers, Nos. 216, 284 and 303, encoded inside the paper before them, which its own List of Papers settles, so that from `d216` each document's `@n` is one or two below its printed number; and two numbers and a name misread;
   - `frus1977-80v27`: a 153-name List of Persons and a 143-entry List of Abbreviations, with no inline links to either;
   - `frus1981-88v16`: people and terms named only by a document-level `@ana`, as a question;
   - printed numbers encoded as `note[@type="source"]` in `frus1870`, `frus1872p2v5` and seven more volumes, as a question. `frus1870`'s are its paper numbers, not the despatch numbers this list first called them.
   - `frus1870`: 21 `@when` values that contradict the date they mark, 16 of them taking their month from the dateline's "(Received …)".

   These are corpus facts. The app states `frus1977-80v27`'s faithfully whether or not upstream changes. The draft's B.3 named two lines that did not state their volume faithfully, `frus1941-43`'s and `frus1981-88v16`'s; index version 74's change fixes both (plan of record decision 119; §11).
7. **The note parser's gap (§3.3, #1856): resolved.** #1857 stores the 8,865 markings at index version 73, which ships with 72 in the next release (plan of record decision 118). The counts in this design are version 73's.

## 10. Files

`Planning/editors-annotations/`:
- `inventory.py` and its output `inventory.json`, the TEI pass;
- `index_extract.py`, with `index-extract.json`, the figures of the app's index at 71, and `index-extract-v72.json`, those of a full index at 72, which classification is counted from;
- `note_marking_gap.py` and `note-marking-gap.json`, the notes' markings the index at 72 did not store, which 73 does (§3.3);
- `tables.py` and `tables.out`, every figure above;
- `editorial-annotations-by-volume.csv`, one row per volume;
- `README.md`, the inputs, commands, definitions and limits.

## 11. As built

Where the lanes depart from §4 to §8, each for a reason measured on the way.

**Lane A (#1859), the data.**
- **A full index, not one parse.** The generator counts the categories the app reads from a full index built through the kit's own pipeline, so the labels agree with the People browser and the chips by construction. No kit function was made public, so §4's and §8's "made public" are moot.
- **A source note's form is where the TEI prints it** (`note[@rend="inline"]`, a file number above the heading), not the note's opening word. Read by its opening, the microfiche supplements' summary notes ("NSC Actions 2374–2377 on Polaris program. Confidential. 3 pp. …") went with the file numbers.
- **A despatch number holds no "/".** The grammar had taken seven file numbers printed "No. 8130/11." or "No. 711.1215/448a." (1909–1917) for serials.
- **The parity suite is an end-to-end fixture** indexed through the pipeline, with every category, and a corpus-wide cross-check against this design's extracts, in place of §8's trimmed real volumes.

**Lane B, the volume page.**
- **The Mac's section is a disclosure,** collapsed until the reader clicks its title or its triangle, and open from then on. Open, its rows take at most half the room below Top subjects, between about two rows and 200 pt, and scroll; the volume's structure keeps the rest. §5.1's "height-bounded as `BoundedSubjectsBlock` is" was built first, as a fixed 200 pt, and in the 440 pt minimum window it left the structure no room: in the check copy, Front Matter and Contents fell below the window's edge.
- **Every line counts documents.** "Senders and recipients" reads "161 documents" for China, not "502 document headings"; "Meeting participants" reads "67 documents"; "Editorial notes" reads "12 editorial notes". "Numbered documents" reads "280 of 280 documents": the file holds a count, not the first and last numbers that "Documents 1–280" needs. Each part of the cross-reference line names its documents ("131 documents cite others in this volume").
- **A source-note line with both forms** reads "archival citations and file numbers".
- **The printed aids** list only the kinds a reader knows by name. The containers, the table of contents and a President's message are left out.
- **The symbols are §5.2's,** drawn in a column as wide as the widest of them, `person.3`, so that every row's text starts at the same place.
- **A row opens nothing** until lane C builds the category pages (decision 5).

**Lane C, the Browse axis.**
- **One table of layers.** The axis's categories are a volume page's fifteen rows, read from one table (`AnnotationLayer`) that the page now reads too, so the two cannot disagree on a layer's name, symbol or rule.
- **The iPhone and iPad door is full width,** below the grid, as Subseries' is. A grid tile holds one line, and in the iPad's list pane "Editors’ Annotations" would truncate to "Editors’ A…".
  - **Changed 2026-11-10, at the owner's request:** the door is a half-width tile in the grid, titled *Annotations*, between Editors and Archives, and its caption is gone. The grid's rows are All Volumes and Administrations, Editors and Annotations, Archives and Clusters. Measured with Core Text at the tile's 14 pt medium, the full name needs 114 pt even at the tile's 85% minimum scale, and "Annotations" needs 80. On an iPad Pro 13-inch (iOS 27.0) the list pane's tiles are 145 pt wide beside the tab sidebar and 149 pt without it, and give a title 85 to 91.5 pt beside its icon; "Annotations" fits in both, and "Administrations" truncates in both, as it did before.
- **A row says its sentence itself.** "People tagged: 288 of 553 volumes. Standard in the volumes covering 1955 on." is the row's VoiceOver label, and the strip is hidden from VoiceOver in a row; on a layer's page each era's cell reads its own count ("1955–1968: 114 of 114 volumes").
- **"In the app" links within Browse.** People links to the People browser, and source notes to the Archives axis, which is built from them; Source Explorer is named in the text. On iOS Source Explorer opens from a document, scoped to it, and has no entry of its own to link to. Every layer says what the app does with it, or that nothing reads it yet, rather than a bare "Not used by the app yet".
- **For a practice no era made standard,** the page names the era where it is most common.
- **The printed aids have one drill per aid,** not "with" and "without": nearly every volume prints one.
- **A drill's title** reads "With: People tagged" or "Without: People tagged"; its caption is §6's. Its rows show "279/280" for a layer that runs through a volume, "37 docs" for one found here and there, "12 notes" for editorial notes, and nothing for references and aids, which no one count says.
- **The marked volume comes first.** Opened from a volume's row, a drill lists that volume first, with "You came here from this volume." In the 288 volumes that tag people, `frus1961-63v06` would otherwise be the 126th row.
- **The amber line is computed.** It marks a volume whose index holds a List of Persons, or of Abbreviations, and none of whose documents links one to it. It finds `frus1977-80v27`'s two lists, as it should. As built it marked two more, and both marks were wrong:
  - `frus1941-43`'s "Index of Persons", a back-of-book index of 350 entries with page references and no ids. The persons-list parser keyed an entry with no id by its text and kept the 6 that passed its name heuristic;
  - `frus1981-88v16`'s List of Abbreviations, whose 88 documents point at it 419 times by `@ana`. The index reads those pointers for people (#1599), and the reader lists both kinds below each document, but the artifact counted abbreviations by `gloss` alone.

  Until the check for the note to the Office (`OH-Note-2026-11-06.md`, B.3), this bullet called both lists that nothing links to. Index version 74's change removes both marks (after lane D, below).
- **The regular-width matrix is lane D's,** as §8 planned.

**Lane D, the matrix and the links.**
- **The matrix is the axis's own rows at regular width.** On an iPad's regular width and on the Mac, each group opens with the eras' first years, and each layer's row is its name, which opens its page, beside eleven cells. A cell opens its era's volumes that carry the layer, its list's caption naming the era ("1955–1968: 114 of 114 volumes." and the rule). A cell no volume of its era fills is drawn, read and disabled, never hidden. On an iPhone the strip stays a picture: a cell there would be about 20 pt wide, under a tap's 44.
- **One line for both people surfaces.** "People are tagged in 288 of 553 volumes, and only those volumes' people appear here. In the others, search for the names." It sits over the People browser's list and in its empty state, which a reader whose volumes tag no one used to reach with only "Index some volumes", and under Person analytics' scope bar.
- **Its link is a hand-off,** `AppState.openAnnotationLayer`, as a volume's is. On the Mac the Corpus Browser comes forward, selects the axis and pushes People tagged's page once the split view shows the axis. On iOS Browse opens the axis with the page above it, assigned rather than appended, as the topic index is, so the crumbs read the axis and not People. In Person analytics' own iPad window, where Browse is in another window, the link is withheld, the Topic-index door's rule.
- **The guide's sentence** ends the People section: "For any volume you can see whether its editors tagged its people, and list the volumes that do, era by era." It says what a reader can do and names no control.
- **Not built:** combining layers into one filter (§6, "Later").

**After lane D: two of the axis's marks, at index version 74** (plan of record decision 119).
- **`frus1941-43`'s Index of Persons is read as an index.** The TEI gives its division a List of Persons' attributes (`xml:id="persons"`, `subtype="index"`); only its `<list type="index">` says what it is, and of the 287 persons sections in the 553 volumes no other has one. Such a list now opens no person, and the outline gives its division the kind `index`, so Browse opens it as the printed text it is. The index stores none of the six fragments, the file records no List of Persons for the volume, and its printed aids name its Index and not Persons.
  - **The volume's page never said "6 people listed",** as this section and the note's B.3 had it: the People row shows only for a volume that carries the layer. The six showed in the volume's persons view ("Persons (6)": among them "Meetings" and "Views on") and, with no mention each, in the People browser, which lists every rollup row; and they were counted in the file.
- **`frus1981-88v16`'s terms on `@ana` are counted.** The scan reads the ids a document div's own `@ana` names, as the reader's lists do (`FRUSDocumentAST.annotatedId`), and Abbreviations counts a document whose `gloss` or `@ana` names one of the volume's terms. This needs no index version: the index stores no term mention for any volume, and the count is the scan's. All 88 documents name one, so the volume carries the layer, which 310 volumes do.
- **What else moved:** nothing. The two files regenerated for the version are as they were, the map's `indexVersion` aside, and the two indexes differ in the six `persons` rows, the volume's outline and the version stamp alone.

**After the follow-ups plan's Lane 1 (2026-11-08): the sixteenth layer.** `Editors-Annotations-Followups-2026-11-08.md` has the measurement and the rule; what departs from its text:
- **The 1925 gate is the kit's, not the generator's.** The plan had the generator count the layer only from 1925. §4's rule, counts and never verdicts, holds instead: the file stores every volume's bracketed omissions and its publication year, and `VolumeAnnotations.carries(_:)` returns `false` for the layer in a volume published before `editorialOmissionsFromYear`, so the gate can move without a regeneration, and a drill's row can say both that a volume is kept out and how many brackets it holds.
- **The rule took two clauses from the sweep's residue,** "… here omitted …" and "Omitted here is …" after a stage direction, every sample an omission; and its first two patterns are case-sensitive, as the plan wrote them, which leaves 27 lower-case openers out.
- **Schema version 2.** Each volume's row gains a fourth element, the publication year; a three-element row still reads, with no year and no gate.
