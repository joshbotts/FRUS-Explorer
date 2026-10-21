# Cross-volume page references as citations: an assessment, 2026-10-20

**What this is.** A read-only assessment for the owner, asked for after A17 (#1693). The question: should a reference to a printed page of another volume (`frus1955-57v17#pg_313`) count as a citation of the document on that page? The places it would count are the reader's citing list, the cross-reference graph, Cross-Reference Analytics and the bundled `resolved-edge-index.json`.

It was measured on `v2` at `b8be1631` (A16 merged). A17 was read on its branch, and has since merged as #1744 (`dcd5439a`); the `resolved-edge-index.json` it shipped is the file measured here. Nothing is built. The owner's choice is recorded in §12: plan of record decision 80.

**Amended the same day, at the owner's request**, to answer two more questions:
- How the change could ride build 51's index bump, A18's v69 → v70 (decision 60). That is §7.
- What it costs, and what it gains, to pair that bump with a generated bundled resource. That is §8.

The recommendation (§9) is revised to match. The first version recommended the bundled pairs alone, for build 52.

**How it was measured.**
- **The index.** The full v69 library of the "iPhone 17e A8 timing" simulator (`89404205`): 553 volumes, 318,104 documents and 187,302 `cross_references` rows. It was cloned (APFS) into a scratch folder, checkpointed and opened read-only. The device was not booted.
  - Its 553 volume files were cloned too. They were copied there on 2 October, and 27 differ from the corpus at `6170e4b32`. Every TEI figure below is read from those copies, so the TEI and the index describe the same text.
- **The resolver.** The kit's own `PageSpanResolver.swift` was compiled verbatim into a throwaway command-line harness. Only `PageCitationHint.init?(noteChildren:)` was left out, the one initialiser that needs the AST.
  - Each target volume's rows and facts came from the resolver's own two SQL strings, `arabicPageRowsSQL` and `citedDocumentFactsSQL`. Those are the inputs `resolvePageBasedCrossReferences` and the reader's page link use.
  - The #1509 hint was built with `PageCitationHint(citingText:)` from the row's stored `context`, wherever the indexer would build one: for a reference inside a footnote.
  - `context` is the same printed text cut at 500 characters. So the hint equals the indexer's except in long footnotes: 336 of the 9,556 rows whose page names several documents sit in a footnote longer than that.
- **The printed form.** The same 553 files were scanned for each cross-volume page `<ref>`, with its text and its neighbour. Each was joined back to the index row it was stored as, and 44,022 of 44,022 rows matched.
- **The bundled file.** The size estimates re-encode the pairs into the file's own format. That encoder rebuilds the `resolved-edge-index.json` A17 shipped (#1744) byte for byte: 291,446 bytes.
- **The amendment's figures** come from the same clone and files:
  - the harness again, listing each cited page's documents and facts, for the page map's size;
  - a comparison of the page and document layout of the 27 corrected volume files;
  - libraries drawn at random from the manifest.

The scripts and their outputs are in the session notes folder, listed in §11. They are not committed.

## 1. In brief

- **The population is the older volumes' way of citing.** There are 44,022 live rows:
  - 43,040 from documents, 380 from a division's own text and 602 from prose sections;
  - from 405 citing volumes into 387 target volumes, naming 22,327 distinct pages.

  **96.6% come from volumes covering 1960 and earlier.** By contrast, 79.6% of today's 8,700 cross-volume document citations come from the volumes covering 1961 on. Before 1961 the series cites another volume by its page. So today the citation graph across volumes is mostly the modern volumes'.
- **The resolver answers almost all of them**: one document for 77.0%, several for 21.7% and none for 1.3%.
- **Not every page reference cites the document on that page.** A single page does: 27,294 rows (62.0%). So does a range that lies within one document. The rest do not:
  - **"ff." (8,704 rows, 19.8%)** is mostly "For documentation on …, see … pp. 865 ff.": a compilation, not its first document.
  - **Ranges (8,024 rows)** are the two ends of 4,012 printed ranges, each end its own `<ref>`. Only 971 of the ranges lie within one document. Read on its own, the last page of a long range credits whatever document is printed there.
- **Rule C counts single pages, and ranges whose two end pages name the same one document.** Under it, 26,395 citing pairs join today's 8,519, and the documents cited from another volume go from 5,803 to 20,032.
  - The Roosevelt–Churchill joint statement of 14 August 1941, the Atlantic Charter (`frus1941v01` d372), goes from 0 citing documents to 156.
  - The Potsdam communiqué (`frus1945Berlinv02` d1384) goes from 0 to 120.
- **Build 51 can carry it without a second re-index.** A18 already re-indexes every library. The change can ride that re-index, either inside A18 or as a lane of its own right after it (A18b, v70 → v71). Build 50 carried four versions with a single re-index, so a reader still re-indexes once.
- **Recommended, and decided on 2026-10-20 (§12): A18b in build 51, with the index and the bundle from one generator run (§9).**
  - The indexer resolves rule C's references when it stores a volume, through a new bundled page map of 0.52 MB. A page cited from any volume on the device then resolves whether or not its target is downloaded. No new column, no second pass.
  - The same run adds rule C's pairs to `resolved-edge-index.json`, which grows from 291 KB to about 1.10 MB. The citing list then counts citers that are not downloaded too.
  - On a full library, 29,023 rows resolve and 14,999 stay `pg_N`. The documents Analytics counts as cited go from 67,881 to 77,376.
  - If A18b is not ready when A19 starts, it moves to the next build's index bump with nothing lost but time. The pairs alone can still ship in build 51, since they need no index version.
- **Five side findings (§10):**
  - 43 same-volume page references written with their own volume's prefix are never resolved.
  - A citing document's graph draws each cross-volume page as a node titled `frus1931-41v02/pg_131`, with Open disabled.
  - A page link into a volume that is not on the device does nothing, on either platform.
  - The Agentic Analysis Guide's §6.6 sample query returns 25 page anchors as its top 25.
  - Provenance flows count no page reference at all.

## 2. The population, re-measured

These are the rows whose `target_volume_id` names another volume and whose target is an arabic page (`pg_N`):

| Citing row | Live | Marked broken |
|---|---:|---:|
| A document | 43,040 | 21 (13 into catalogue volumes, 8 outside) |
| A division's own text (#1536's rows) | 380 | 1 |
| A prose section | 602 | 0 |
| **All** | **44,022** | **22** |

**The brief's figures, reconciled with these.**
- "982 from sections' own text" is 380 + 602, both kinds of section row.
- "613 from prose sections" adds 11 roman-numeral page references to the 602. No resolver reads those: `pg_XIII` is `.unresolved`.
- "43,053 from documents" is the 43,040 here plus 13 broken rows into catalogue volumes.

**Where the reference sits.** 40,469 are in a footnote that has text, which is where a #1509 hint can come from. 1,378 are in an editorial note, and 2,175 are in no note at all.

**By the citing volume's years**, against today's cross-volume rows to a document:

| Citing volume covers | Page rows | Document rows today |
|---|---:|---:|
| 1861–1918 | 3,624 | 439 |
| 1919–1945 | 25,338 | 411 |
| 1946–1960 | 13,578 | 925 |
| 1961 on | 1,482 | 6,925 |

**The largest volumes and pair.**
- Most citing: `frus1945v03` (685), `frus1945v05` (613) and `frus1961-63v05` (599).
- Most cited: `frus1931-41v01` (1,132), `frus1931-41v02` (857), `frus1945Malta` (800) and `frus1945Berlinv02` (715).
- The heaviest pair is `frus1941v04` → `frus1931-41v02`, with 402 rows.

**Outside the question, measured to bound it.** The TEI holds 173,933 cross-volume page `<ref>`s.
- 123,827 are in back-of-book indexes, mostly a split volume's second part indexing its first (`frus1952-54v13p2`: 14,928).
- 6,062 are in tables of contents, lists of papers and chapter headings. A18 may bring the headings in (§7).
- The index stores no row for any of those. The other 44,044 are the stored rows: 44,022 live and 22 marked broken.

## 3. What `PageSpanResolver` makes of them

| Citing row | One document | Several | None |
|---|---:|---:|---:|
| A document | 33,225 | 9,260 | 555 |
| A division's own text | 236 | 139 | 5 |
| A prose section | 439 | 157 | 6 |
| **All** | **33,900 (77.0%)** | **9,556 (21.7%)** | **566 (1.3%)** |

- **One.** The page is where one document begins (27,136 rows), or it lies within one that began earlier (6,764).
- **Several.** 9,555 rows cite a page where several documents begin: two on 8,164, three on 1,295, four on 92 and five on 5. One row cites a page that several documents run through. No target numbers its pages per document.
  - **What decides among several (#1509's rule).** The note names the day of one of them 2,277 times, and a document number 3 times.
  - 983 notes name a day or a number that matches none of them, and 6,293 rows have no hint.
  - Those 7,276 take the first document on the page, the one a tap opens. The rule's choice differs from the first document 1,140 times.
- **None.** The page lies before the target's first document (153 rows), after its last (152), or between documents (261): front matter, back matter, and apparatus no document claims.
- **What is chosen.** A document division 43,242 times, a prose section 212 times and a division's own text twice.

## 4. What a page reference cites

| Printed form | Rows | One | Several | None |
|---|---:|---:|---:|---:|
| A single page: "Foreign Relations, 1942, vol. i, p. 841." | 27,294 | 20,844 | 6,245 | 205 |
| A page and "ff." | 8,704 | 6,447 | 1,938 | 319 |
| A range's first page | 4,012 | 3,212 | 774 | 26 |
| A range's last page | 4,012 | 3,397 | 599 | 16 |

- **A range is two rows.** The TEI prints "pp. 131–149" as `<ref …#pg_131>pp. 131</ref>–<ref …#pg_149>149</ref>`, so each end is stored as its own reference. Of the 4,012 ranges:
  - 971 lie within one document, reading every page between;
  - 1,645 span 2–3 documents, 605 span 4–10 and 773 span 11 or more;
  - 18 name no document or run backwards.

  An example of a long one: in `frus1933v05` d750, "ibid., 1914, pp. 443–895 passim" spans 952 documents.
- **The two end pages alone decide a range.** "Both ends name the same one document" agrees with reading every page between for 4,008 of the 4,012 ranges. It takes 967 of the 971, and the other 4 have an end page that names no document. So a device needs nothing beyond the two pages it cites. Rule C uses this test, and the figures below are under it.
- **"ff." cites a compilation.**
  - 3,932 of the 8,704 notes say "documentation", as in "For documentation on the Guatemalan request, see Foreign Relations, 1950, Vol. ii, pp. 865 ff."
  - 8,385 of these rows resolve. 5,182 of those say "documentation" or "correspondence". The page is the first page of a compilation, and its first document is not what is cited.
  - 1,833 rows name a document that runs past the page, in a note with neither word. That is the share that may mean one long document.
- **A single page is a citation of a document.** "Foreign Relations, 1942, vol. i, p. 841." is a telegram.

**The counting rules compared.** A pair is a citing row and the document it cites. Today there are 8,519 pairs into 5,803 documents, from 185 citing volumes.

| Rule | New pairs | Documents cited from another volume | Citing volumes | `resolved-edge-index.json` |
|---|---:|---:|---:|---:|
| A: every row | 40,491 | 25,771 | 513 | 1.44 MB |
| B: every row except a range's last page | 37,590 | 24,077 | 513 | |
| D: rule C, plus "ff." | 34,675 | 22,685 | 512 | |
| **C: single pages, and ranges whose end pages name the same one document** | **26,395** | **20,032** | **512** | **1.10 MB** |
| C′: rule C, but a page that names several documents counts only when its note says which | 22,381 | 17,408 | 511 | |
| E: rule C, but only pages that name one document | 20,299 | 15,939 | 511 | 0.89 MB |

- **What decides rule C's rows.** It resolves 29,023 rows, which make 26,523 pairs:
  - 22,778 name one document: 20,844 single pages and 1,934 range ends;
  - the note settles 2,120;
  - 4,125 take the first of several. Same-volume edges and the tap use that same default. Over same-volume references, #1509 measured the first as the right document 2,502 times in 4,327, where the note named the day of one of them.
- **Little overlaps today.** Only 3 of the new pairs are a citation already: a document citing the same document by its id and by its page.
- **Some pairs name a section.** 125 of rule C's pairs name a prose section printed on the page, not a document division.

**The most cited documents from another volume, under rule C:**

| Document | Citing documents today | Under rule C |
|---|---:|---:|
| `frus1941v01` d372: Joint Statement by President Roosevelt and Prime Minister Churchill, August 14, 1941 | 0 | 156 |
| `frus1945Berlinv02` d1384: Communiqué | 0 | 120 |
| `frus1943v01` d684: Protocol, Signed at Moscow, November 1, 1943 | 0 | 116 |
| `frus1922v01` d84: Treaty between the United States of America, Belgium, the British Empire, China, France, Italy, Japan… | 0 | 104 |
| `frus1923v02` d28: Treaty between the United States of America and Germany, Signed at Washington, December 8, 1923 | 0 | 103 |

The most cited from another volume today is `frus1945Berlinv02` d1417, with 29.

## 5. The surfaces, today and under each option

| Surface | What it reads | The page rows today | (a) | (b) | (c) |
|---|---|---|---|---|---|
| **Research rail ▸ Graph**: Cites This Document, the graph's inbound half and its banner | The local `inboundEdges`, completed from the bundled index (`completingInboundEdges`) | Never match | Gains every citer on the device | As (a): the document is on the device, so its citers' rows resolve either way | Gains citers from the whole corpus, downloaded or not |
| **The graph's outbound half**: Cited By This Document | The local `outboundEdges` | A node `frus…/pg_N`, titled by its key, with Open disabled (`makeEntry` needs a header) | Becomes the document | Becomes the document even with the target absent (untitled then, like any document of an absent volume) | Unchanged |
| **Cross-Reference Analytics**: most cited, the in- and out-degree histograms, PageRank | The local table, whose `documentTargetPredicate` drops `pg_*` | Left out | Counted, for a library holding both volumes | Counted, for a library holding the citing volume | Unchanged |
| **Analytics' volume heat matrix; Cross-Volume Connections** | The local table, by `target_volume_id` | Already counted | Unchanged | Unchanged | Unchanged |
| **Related, by citation** (#308, `relatedByCitation`) | The local table | Left out | Counted | Counted | Unchanged |
| **The research data export** (`research_cross_references`) | The local table | Raw `pg_N` rows | Resolved | Resolved | Unchanged |
| **`resolved-edge-index.json`** | The generator | None | Unchanged | Unchanged; the map is a second file | Rule C's pairs added |
| **The reader's page link** | The target's page rows, at tap time | Works when the target is indexed, and does nothing otherwise (§10) | Unchanged | Could name the document and offer the volume | Unchanged |

## 6. The options and their costs

### (a) Resolve in the index against the target's own pages, when it is indexed and again when it is indexed later

- **It runs in both directions.** Each store pass would resolve its own volume's rows into volumes already indexed, and every other volume's rows into it. Then the result does not depend on the order volumes are indexed in. A target re-indexed as a corrected volume re-resolves the rows that cite it.
- **It needs three things per row that the table does not keep:**
  - the page, once the row is rewritten;
  - the printed form, and a range's other end;
  - the note's hint, which the indexer builds from the whole note and then discards. `context` holds that note cut at 500 characters.

  Three new columns could hold them (`ALTER TABLE … ADD COLUMN`, as `reference_type` and `context` were added). Only a parse can fill them, so this needs an index version. In build 51 that is the re-index A18 already makes.
- **It leaves most of a partial library's rows as pages.** It resolves a reference only when the reader holds both volumes.
  - That costs nothing in the citing list: a document the reader opens is on the device, so its citers' rows resolve.
  - It costs Analytics, the outbound half and the export. There, a reference into a volume the reader does not hold stays a page, where a document reference into the same volume counts.

  The share of rule C's rows it resolves:

  | Library | Rows resolved |
  |---|---:|
  | A random 10-volume library (median of 300) | 0.4% |
  | A random 25-volume library | 3.5% |
  | A random 100-volume library | 17.8% |
  | The 1941 volumes (8) | 15% (179 of 1,158) |
  | The 1945 volumes (13) | 55% (1,480 of 2,699) |
  | The Kennedy volumes (27) | 80% (438 of 545) |

- **No CloudKit change**, and no bundled file.

### (b) Resolve in the index through a bundled page map

- **What it is.** A generator writes an entry for each page a single-page reference cites, and for both end pages of each range that lies within one document. Each entry lists the documents on that page, in source order, and how they stand on it. For the documents on a page that names several, it adds their facts: printed number and day.
  - A range whose end pages are not both in the map stays a page on the device. That is the right answer for a range across documents.
  - The store pass resolves each row from the map, with the row's own hint and printed form. It runs once, against the citing volume only, and reaches every page that volume cites, downloaded or not.
- **What it weighs.** Prototyped in a compact form like the edge index's: 16,153 pages in 380 target volumes, naming 18,532 documents, with the number or day of the 8,358 documents on pages that name several. That is 519,368 bytes on disk and 135,524 compressed. A further 108 cited pages name nothing and need no entry.
- **What it saves over (a).**
  - No column and no second pass: a row is rewritten in place, as same-volume page references are, and the result does not depend on the order volumes are indexed in.
  - A page reference is stored as a document reference is, whatever the device holds. In a 25-volume library it resolves all of rule C's rows, against a median 3.5% under (a).
- **What it costs.**
  - A new bundled resource. It needs a kit type and a provider in `IndexingResources`, an app loader like `BrokenRefsIndexStore`, `xcodegen generate` with the scheme restore, and a `BundledArtifactProvenance` row.
  - Its name joins `indexResourceNames`, so the web edition's `loading(fromDirectory:)` refuses a folder without the file. That is right for a file that changes what an index holds, and it is one more thing for the web edition's v70 pin move.
- **It can go stale.** Volumes download from `HistoryAtState/frus` master, unpinned (`ManifestModels.swift`), so a device's copy can be older or newer than the build's corpus.
  - Of the 27 volume files that changed between 2 October and `6170e4b32`, 25 kept their page and document layout.
  - Two did not: `frus1902app1` (198 → 196 documents) and `frus1952-54v09p1` (899 → 946 documents, 1,700 → 1,781 page breaks).
  - Where a device holds such a copy, a stored edge can name a different document from the one a tap opens, until the map is regenerated with a later build.

### (c) Resolve in the generator and ship the edges

- **The generator already parses.** Since A17, `ResolvedEdgeIndexGenerator` parses every volume with the kit's parser. For each cross-volume page `<ref>` in a document or section row, it would add:
  - the printed form, read from the AST: the reference's text and its neighbour;
  - the hint, from its footnote, through `PageCitationHint(noteChildren:)` as the indexer builds it;
  - the answer from `PageSpanResolver`, over the target volume's page rows and facts. With (b), that is the map.
- **The page rows and facts must be the ones the device holds.** The safe source is a full index built by the kit's own `IndexingPipeline`, through the public initialiser the web edition's indexer uses. That takes about 7–11 minutes and 2.9 GB of scratch on this Mac.
  - A parity test can hold the generator's answers to the tap's (`PageRangeStore.document(forPage:inVolume:citing:)`) over a fixture, as A17's suite holds the grammar's twin to the app.
- **The pairs ship as ordinary pairs.** Optionally, each target also gets a count of the citers that came by page, beside `f`, so a surface can say how many did. The funnel gains its coverage fields, which the app's decoder requires, as A17's did.
- **The cost is small.** No index version, no schema change and no CloudKit change. The file grows from 291 KB to about 1.10 MB under rule C. The generator's run grows by the full index build. The pull request owes the web edition a line about the file, as A17's does.
- **The limit.** Only the inbound half changes. In a library that holds both volumes, the graph lists the citer and Analytics does not count it.

## 7. Folding it into build 51's index bump

**Where.** Either inside A18 (v70, one lane), or as A18b straight after it (v70 → v71) and before A19. Build 50 is the precedent for the second: it took versions 66 to 69 in four pull requests, and a reader re-indexed once, at the build that carried them all.
- A18b keeps A18's lane as planned, through `lane-dev.js`, one lane and one round. It can be reviewed on its own, and it can slip.
- The web edition still moves its pin once, after the last of them.
- Decisions 59 and 60 named A18 alone. The owner placed A18b on 2026-10-20 (decision 80, §12).

**What it carries**, with option (b) as §9 recommends:
- **Kit:**
  - At parse time, classify each cross-volume page reference's printed form: single, "ff.", or a range's first or last page, with its other end. The classifier needs to look at the reference's neighbour, which `collectDocumentRefs` does not do today.
  - Carry the form beside the hint the walk already builds for these rows and throws away, as `citing` and `settled` are carried today.
  - At store time, resolve rule C's rows from the map with `PageSpanResolver.citedDocument`, and leave "ff.", ranges across documents and pages naming nothing as `pg_N`.
  - Resolve the 43 self-prefixed same-volume rows against their own volume (§10).
  - The map's type, its decoder and its provider.
- **App:** the loader, the bundled file and its provenance row, `xcodegen generate` and the scheme restore.
- **Generator:** one run builds a full index at the lane's version (v71 as A18b) through the kit's pipeline. From it the generator writes the map, then rule C's pairs into `resolved-edge-index.json` with the same kit functions and the same map. It needs a runbook entry and its place in the regeneration chain.
- **Tests:**
  - the classifier, against a table of forms drawn from the corpus;
  - the store pass against a fixture map, covering a range whose end pages differ and the default on an ambiguous page;
  - the shipped map: it decodes, and it covers the pages the corpus cites;
  - the generator's pairs, which must equal the cross-volume document rows of a full index built with the map. A17's check had the same shape.
- **Docs:**
  - both manuals: the citing list counts a page citation, and "ff." and ranges across documents do not;
  - the Agentic Analysis Guide: what `cross_references` holds for a page, and its §6.6 query;
  - the runbook;
  - a TestFlight line.

**Order inside the bump.** The map has to come from the v70 parse, so it is generated after A18's own changes.
- A18 promotes sections and dates section rows (§6d), and both can move which documents a page names and their facts.
- #1640's heading footnotes, if A18 stores them, add 4,560 cross-volume page rows: 1,932 "ff.", 2,254 range rows and 374 single pages.
  - Rule C resolves 370 of them: 350 single pages and 10 ranges within one document.
  - The other 4,190 cite compilations and stay on the volume. That is what rule C is for.

**What A19's census would see**, on the census library's own files and before the heading rows:
- 29,023 cross-volume rows resolve, and 43 self-prefixed same-volume rows.
- 14,999 stay `pg_N`: 8,704 "ff.", 6,090 range rows (42 of them on a page naming nothing) and 205 single pages naming nothing.
- Analytics' in-degree:
  - documents cited at all: 67,881 → 77,376;
  - the Potsdam protocol (`frus1945Berlinv02` d1383): 103 → 218;
  - the Potsdam communiqué (d1384): 46 → 204;
  - the Moscow protocol (`frus1943v01` d684): 32 → 169;
  - the Atlantic Charter (`frus1941v01` d372): 6 → 162.
- The guide's §6.6 query: 3 of its top 25 rows are still page anchors, against 25 today.

The census already compares the device's re-index with a fresh index of the same files built by the kit's pipeline, and with the same map the two must agree row for row.

**Cost and risk.**
- **Size.** The work is about the size of A17 again. That is an estimate, not a measurement: A17 changed 24 files, +794 / −141 lines.
- **Run time.** It adds nothing a reader would notice to the re-index. The store pass gains one lookup per cross-volume page row and about 29,000 updates across a full library; the same-volume pass already makes about 55,000.
- **Where the risk sits.** It is in the indexer, in the release candidate's last code lane. Three things bound it:
  - this memo's figures give exact expectations;
  - the census checks them;
  - as A18b, the work can be left out without touching A18.

## 8. Pairing the index bump with a generated bundled resource: costs and benefits

Five ways to combine the options:

| | Re-index | New column | New bundled file | Citing list of a document on the device | Analytics, outbound half, export | Bundle added |
|---|---|---|---|---|---|---|
| (c) alone | None | No | No | Every citer in the corpus | Unchanged | +0.8 MB |
| (a) in v70/v71 | Rides build 51's | 3 | No | Every citer on the device | Rows whose target is on the device: a median 3.5% of a 25-volume library's | None |
| (a) + (c) | Rides build 51's | 3 | No | Every citer in the corpus | As (a) | +0.8 MB |
| **(b) + (c), one run** | **Rides build 51's** | **None** | **The map** | **Every citer in the corpus** | **Every row, as a document reference is counted** | **+1.3 MB** |
| (b) alone | Rides build 51's | None | The map | Every citer on the device | Every row | +0.5 MB |

**What one generator run for both gains:**
- **The index and the bundle agree by construction.** The device stores what the generator ships, through the same kit functions and the same map.
- **One re-index**, instead of one now and one at a later build. Builds 49, 50 and 51 each took a bump, so a later change would probably ride the next build's bump. The real difference is that version 1.0 ships with the citation surfaces agreeing.
- **A page reference counts as a document reference does**, in every surface, whatever the device holds. Under (a), Analytics and the export would count one only when the reader holds both volumes.
- **No ordering logic and no schema change.** The work (a) puts in a second pass and three columns, the map does instead.
- **No extra full-index build.** A bump lane builds full indexes to measure its items before and after anyway (§6d asks it of A18), and the generator needs the same build.

**What it costs:**
- **A second bundled file that changes what an index holds**, with its own staleness: two of 553 volumes changed layout in 18 days.
- **A web-edition step.** The file must ship before the web edition's v70 pin works.
- **A slower generator run, and one that leans on the kit's pipeline.**
- **More scope in the release candidate.** A18b keeps that scope out of A18 itself.

## 9. Recommendation

**Option (b) with (c), from one generator run, as A18b in build 51**: after A18, before A19, raising v70 → v71. It uses rule C and includes the self-prefixed same-volume fix.
- **What a reader gets.** The citing list, the graph, Analytics, Related and the export all count a page citation, from version 1.0 on. Readers re-index once, as A18 already makes them.
- **Why the map rather than (a).** The citing list is the same either way. But the map stores every page reference as a document reference is stored, whatever the device holds: in a 25-volume library, all of rule C's rows against a median 3.5% under (a). It also needs no new column and no second pass.
- **Why the pairs too.** They list citers that are not downloaded, and they cost no index version.

**If A18b cannot be ready when A19 starts**, ship (c) alone in build 51 or 52, since it needs no index version. The index side then takes the next build's index bump, with the same rule and the same map, so nothing built for it is lost.

**Not (a)**, in build 51 or later. Beside (b) it costs a schema change and a second pass, and reaches less.

**What was put to the owner**, and how each was settled on 2026-10-20 (§12). The owner decided the first three; the plan of record takes the other three by default, each the owner's to overturn.
1. **A18b as its own lane, or inside A18?** A18b keeps A18 as planned (decisions 59 and 60). Inside A18, it makes A18 larger. **Decided: its own lane, after A18 and before A19.**
2. **Rule C, or the stricter C′?** C′ counts a page that names several documents only when its note says which: 22,381 new pairs against 26,395. Rule C keeps the default the same-volume edges and the tap already use. **Decided: rule C.**
3. **Does "ff." stay a reference to the volume?** Rule C keeps it there. Alternatively, a narrower rule could count the 1,833 "ff." rows that name a document running past the page, in a note that says neither "documentation" nor "correspondence". **Decided with rule C: it stays.**
4. **Should a section printed on the page count as a cited target?** That is 125 pairs. Since A17 the file holds sections as citers. As targets it has held only document divisions. **By default: it counts**, as same-volume page references and the tap already treat it.
5. **The map's staleness.** Either regenerate the map with each build's corpus, which keeps every device deterministic, or let a device prefer its own copy of a target it holds. The second makes the result depend on the order volumes are indexed in, for the volumes that changed. **By default: regenerated with each build's corpus, and a device resolves from the map alone.**
6. **Optionally, without an index version:** draw an outbound page node that rule C leaves on the volume as "volume, p. N" rather than its raw key, or leave it out of the outbound list. **By default: not A18b's.** It stays a finding in the plan's §6g.

## 10. Side findings, not acted on

1. **43 same-volume page references are never resolved.** `resolvePageBasedCrossReferences` requires `target_volume_id IS NULL`. So a reference written with its own volume's prefix keeps `pg_N`, as `frus1950v06#pg_N` inside `frus1950v06` does, 14 times. All 43 resolve, 37 to one document and 6 to several. The fix is one condition (`OR target_volume_id = source_volume_id`) and an index version. §7 folds it in.
2. **The outbound half draws a cross-volume page as a node keyed `volume/pg_N`.** It has no title, and Open is disabled, even when the target volume is indexed (`CrossReferenceGraphViewModel.makeEntry`).
3. **A page link into a volume that is not on the device does nothing.** On iOS and the Mac alike (`resolvePageReference` in `DocumentView` and `MacDocumentView`), a nil answer only prints in Debug. A document link into an absent volume falls back to that volume's Browse page.
4. **The Agentic Analysis Guide's §6.6 sample query returns page anchors.** Run over this index, its top 25 rows are all page anchors, led by `frus1941v01` `pg_367` with 155.
5. **Provenance flows count no page reference.** `ProvenanceFlowIndexGenerator` takes `RefDestination.citedDocument`, which is `nil` for a page, so it skips same-volume pages too. #1509 measured 55,007 such references at `550a8c5c5`, and the app's own index resolves them. The same resolution step could serve it, if the owner wants the flows to count them.

## 11. Reproducing

The notes folder `~/Library/Application Support/Claude/side-session-notes/local_925b2d09-089c-43b0-970e-137754b57ede/page-citations/` holds the following, outside the repository. Run the Python with `python3 -I`.
- `docids.py`: document and division ids from the volume files.
- `population.py`: §2.
- `main.swift`: the harness, compiled with `xcrun swiftc -O -swift-version 5 main.swift PageSpanResolver.swift`. `PageSpanResolver.swift` is the kit's file minus `init?(noteChildren:)`. Its modes are `cross`, `selfnamed`, `ranges` and `pages`.
- `outcomes.py`: §3.
- `refforms.py` and `joinforms.py`: the printed forms.
- `semantics.py`, `ffsplit.py` and `devicerule.py`: §4's rules.
- `sizes.py`: the edge index's size.
- The amendment's scripts:
  - `rangetest.py`: the end-page test;
  - `headings.py`: A18's heading rows;
  - `layout.py`: the 27 corrected volumes;
  - `partial.py`: libraries;
  - `census.py`: §7's figures;
  - `mapsize.py`: the map's size.
- Each script's output.

## 12. The owner's choice

**The owner's word, 2026-10-20:** "Record A18b in the plan of record as the memo recommends: after A18 and before A19, v70 to v71, rule C, the page map and the bundled pairs from one generator run."

- **The record.** It is the plan of record's decision 80. Its §1 has A18b's row and entry; its §0 takes the other questions by default (§9's items 4 to 6); its §6g holds the three side findings A18b does not take.
- **The lane.** A18b, after A18 and before A19, raising `currentDateIndexVersion` 70 → 71, through `lane-dev.js`. Its brief is §7. A library still re-indexes once at build 51.
- **What the lane builds:**
  - in the kit: each cross-volume page reference's printed form at parse time, rule C's rows resolved from the page map at store time, and the 43 self-prefixed rows resolved against their own volume;
  - in the app: the page map, bundled, with its loader and provenance row;
  - in the generator: one run that writes the map and adds rule C's pairs to `resolved-edge-index.json`.
- **No CloudKit change.** It owes `swift build --target FRUSCoreKit`, `swift test`, the unit target, the Mac build and a line for the web edition, and A19's census checks its figures.
