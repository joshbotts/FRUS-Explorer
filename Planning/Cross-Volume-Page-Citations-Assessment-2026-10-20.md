# Cross-volume page references as citations: an assessment, 2026-10-20

**What this is.** A read-only assessment for the owner, asked for after A17 (#1693). The question: should a reference to a printed page of another volume (`frus1955-57v17#pg_313`) count as a citation of the document on that page? The places it would count are the reader's citing list, the cross-reference graph, Cross-Reference Analytics and the bundled `resolved-edge-index.json`.

It was measured on `v2` at `b8be1631` (A16 merged). A17's branch (`claude/gallant-diffie-a645f8`, not yet merged) was read for the generator. Nothing is built, and nothing in build 51's queue changes. The options are for a build after 51 (§6). The owner has not chosen yet.

**How it was measured.**
- **The index.** The full v69 library of the "iPhone 17e A8 timing" simulator (`89404205`): 553 volumes, 318,104 documents and 187,302 `cross_references` rows. It was cloned (APFS) into a scratch folder, checkpointed and opened read-only. The device was not booted.
  - Its 553 volume files were cloned too. They were copied there on 2 October, and 27 differ from the corpus at `6170e4b32`. Every TEI figure below is read from those copies, so the TEI and the index describe the same text.
- **The resolver.** The kit's own `PageSpanResolver.swift` was compiled verbatim into a throwaway command-line harness. Only `PageCitationHint.init?(noteChildren:)` was left out, the one initialiser that needs the AST.
  - Each target volume's rows and facts came from the resolver's own two SQL strings, `arabicPageRowsSQL` and `citedDocumentFactsSQL`. Those are the inputs `resolvePageBasedCrossReferences` and the reader's page link use.
  - The #1509 hint was built with `PageCitationHint(citingText:)` from the row's stored `context`, wherever the indexer would build one: for a reference inside a footnote.
  - `context` is the same printed text cut at 500 characters. So the hint equals the indexer's except in long footnotes: 336 of the 9,556 rows whose page names several documents sit in a footnote longer than that.
- **The printed form.** The same 553 files were scanned for each cross-volume page `<ref>`, with its text and its neighbour. Each was joined back to the index row it was stored as, and 44,022 of 44,022 rows matched.
- **The bundled file.** The size estimates in §4 re-encode the pairs into the file's own format. That encoder rebuilds A17's regenerated `resolved-edge-index.json` byte for byte: 291,446 bytes.

The scripts and their outputs are in the session notes folder, listed in §9. They are not committed.

## 1. In brief

- **The population is the older volumes' way of citing.** There are 44,022 live rows:
  - 43,040 from documents, 380 from a division's own text and 602 from prose sections;
  - from 405 citing volumes into 387 target volumes, naming 22,327 distinct pages.

  **96.6% come from volumes covering 1960 and earlier.** By contrast, 79.6% of today's 8,700 cross-volume document citations come from the volumes covering 1961 on. Before 1961 the series cites another volume by its page. So today the citation graph across volumes is mostly the modern volumes'.
- **The resolver answers almost all of them**: one document for 77.0%, several for 21.7% and none for 1.3%.
- **Not every page reference cites the document on that page.** A single page does: 27,294 rows (62.0%). So does a range that lies within one document. The rest do not:
  - **"ff." (8,704 rows, 19.8%)** is mostly "For documentation on …, see … pp. 865 ff.": a compilation, not its first document.
  - **Ranges (8,024 rows)** are the two ends of 4,012 printed ranges, each end its own `<ref>`. Only 971 of the ranges lie within one document. Read on its own, the last page of a long range credits whatever document is printed there.
- **Rule C counts single pages and ranges within one document.** Under it, 26,395 citing pairs join today's 8,519, and the documents cited from another volume go from 5,803 to 20,032.
  - The Roosevelt–Churchill joint statement of 14 August 1941, the Atlantic Charter (`frus1941v01` d372), goes from 0 citing documents to 156.
  - The Potsdam communiqué (`frus1945Berlinv02` d1384) goes from 0 to 120.
- **Recommended for build 52: option (c) under rule C.** The generator resolves the references and ships them in `resolved-edge-index.json`.
  - No index version, no schema change and no CloudKit change.
  - The file grows from 291 KB to about 1.10 MB.
  - Every reader's citing list and graph gains these citers, whatever is downloaded.
  - Analytics, the outbound list and Related keep reading the local table, where the rows stay `pg_N`. Resolving them there is option (a), which needs an index version. It is left for a build that takes one anyway.
- **Five side findings (§8):**
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
- 6,062 are in tables of contents, lists of papers and chapter headings.
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
  - 971 lie within one document, and both ends name it;
  - 1,645 span 2–3 documents, 605 span 4–10 and 773 span 11 or more;
  - 18 name no document or run backwards.

  An example of a long one: in `frus1933v05` d750, "ibid., 1914, pp. 443–895 passim" spans 952 documents.
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
| **C: single pages, and ranges within one document** | **26,395** | **20,032** | **512** | **1.10 MB** |
| C′: rule C, but a page that names several documents counts only when its note says which | 22,381 | 17,408 | | |
| E: rule C, but only pages that name one document | 20,299 | 15,939 | 511 | 0.89 MB |

- **What decides rule C's rows.** It resolves 29,027 rows:
  - 22,782 name one document;
  - the note settles 2,120;
  - 4,125 take the first of several. Same-volume edges and the tap use that same default. Over same-volume references, #1509 measured the first as the right document 2,502 times in 4,327, where the note named the day of one of them.
- **Little overlaps today.** Only 3 of the new pairs are a citation already: a document citing the same document by its id and by its page.
- **Some pairs name a section.** 128 of rule C's pairs name a prose section printed on the page, not a document division.

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
| **Research rail ▸ Graph**: Cites This Document, the graph's inbound half and its banner | The local `inboundEdges`, completed from the bundled index (`completingInboundEdges`) | Never match | Gains citers, for a library holding both volumes | As (a) | Gains citers from the whole corpus, downloaded or not |
| **The graph's outbound half**: Cited By This Document | The local `outboundEdges` | A node `frus…/pg_N`, titled by its key, with Open disabled (`makeEntry` needs a header) | Becomes the document | Becomes the document even with the target absent (untitled then, like any document of an absent volume) | Unchanged |
| **Cross-Reference Analytics**: most cited, the in- and out-degree histograms, PageRank | The local table, whose `documentTargetPredicate` drops `pg_*` | Left out | Counted, for a library holding both volumes | Counted, for a library holding the citing volume | Unchanged |
| **Analytics' volume heat matrix; Cross-Volume Connections** | The local table, by `target_volume_id` | Already counted | Unchanged | Unchanged | Unchanged |
| **Related, by citation** (#308, `relatedByCitation`) | The local table | Left out | Counted | Counted | Unchanged |
| **The research data export** (`research_cross_references`) | The local table | Raw `pg_N` rows | Resolved | Resolved | Unchanged |
| **`resolved-edge-index.json`** | The generator | None | Unchanged | A second artifact beside it | Rule C's pairs added |
| **The reader's page link** | The target's page rows, at tap time | Works when the target is indexed, and does nothing otherwise (§8) | Unchanged | Could name the document and offer the volume | Unchanged |

## 6. The options and their costs

### (a) Resolve at index time when the target volume is indexed, and again when it is indexed later

- **It runs in both directions.** Each store pass would resolve its own volume's rows into volumes already indexed, and every other volume's rows into it. Then the result does not depend on the order volumes are indexed in. A target re-indexed as a corrected volume re-resolves the rows that cite it.
- **It needs three things per row that the table does not keep:**
  - the page, once the row is rewritten;
  - the printed form, and a range's other end;
  - the note's hint, which the indexer builds from the whole note and then discards. `context` holds that note cut at 500 characters.

  Three new columns could hold them (`ALTER TABLE … ADD COLUMN`, as `reference_type` and `context` were added). Only a parse can fill them, so this needs an index version.
- **The cost is v71**, since A18's v70 is build 51's (decision 60).
  - Every library re-indexes once at its upgrade. A8's run took 13 minutes to bring all 553 volumes from v65 to v69 on the iPhone 17e simulator, with build 50's AppStore build. Debug builds took 20–28 minutes, beside other work.
  - The web edition's server refuses exports from the new build until its pin moves.
  - No CloudKit change.
- **It reaches only libraries that hold both volumes.** A reader with ten volumes gains only the page citations among those ten.

### (b) A bundled page-to-document map

- **What it is.** A generator writes, for each page that another volume cites, the documents on that page and their facts: printed number and day. That is 16,264 pages under rule C and 22,327 in all. The index then resolves at store time without the target volume.
- **What it costs.** About 0.35 MB plus the id vocabularies. It is a new bundled resource, which needs `xcodegen generate`, the scheme restore and a `BundledArtifactProvenance` row.
- **What it saves.** It removes (a)'s second pass and reaches any library that holds the citing volume.
- **What it does not save.**
  - It still needs each row's printed form and hint, so it still needs an index version.
  - It does nothing for a citing volume that is not downloaded, so the inbound half still needs (c).
  - A volume re-published with new pagination disagrees with the map until the map is regenerated.

### (c) Resolve in the generator and ship the edges

- **The generator already parses.** Since A17, `ResolvedEdgeIndexGenerator` parses every volume with the kit's parser. For each cross-volume page `<ref>` in a document or section row, it would add:
  - the printed form, read from the AST: the reference's text and its neighbour;
  - the hint, from its footnote, through `PageCitationHint(noteChildren:)` as the indexer builds it;
  - the answer from `PageSpanResolver`, over the target volume's page rows and facts.
- **The page rows and facts must be the ones the device holds.** The safe source is a full index built by the kit's own `IndexingPipeline`, through the public initialiser the web edition's indexer uses. That takes about 7–11 minutes and 2.9 GB of scratch on this Mac. The generator reads it with the same two SQL strings.
  - A parity test can hold the generator's answers to the tap's (`PageRangeStore.document(forPage:inVolume:citing:)`) over a fixture, as A17's suite holds the grammar's twin to the app.
- **The pairs ship as ordinary pairs.** Optionally, each target also gets a count of the citers that came by page, beside `f`, so a surface can say how many did. The funnel gains its coverage fields, which the app's decoder requires, as A17's did.
- **The cost is small.** No index version, no schema change and no CloudKit change. The file grows from 291 KB to about 1.10 MB under rule C. The generator's run grows by the full index build. The pull request owes the web edition a line about the file, as A17's does.
- **The limit.** Only the inbound half changes. In a library that holds both volumes, the graph lists the citer and Analytics does not count it.

## 7. Recommendation

**Option (c), under rule C, in build 52.**
- It answers the question where readers ask it: "what cites this?" in the reader and the graph. It answers for every reader, not only one who holds both volumes.
- It needs no index version, and build 51 has just taken v70.
- It can apply the printed-form rule, which the index cannot apply without a re-parse.
- What it changes is one generator and one bundled file. The app takes the new pairs as they are; its reader needs only the new coverage fields.

**Then option (a), under the same rule,** in the first later build that takes an index version for reasons of its own. It adds no citer that (c) does not already list. It brings Analytics, the outbound half, Related and the export into line with the citing list.

**Not option (b).** It still needs an index version and still needs (c). What it saves is (a)'s second pass.

**For the owner to decide:**
1. **Rule C, or the stricter C′?** C′ counts a page that names several documents only when its note says which: 22,381 new pairs against 26,395. Rule C keeps the default the same-volume edges and the tap already use.
2. **Does "ff." stay a reference to the volume?** Rule C keeps it there. Alternatively, a narrower rule could count the 1,833 "ff." rows that name a document running past the page, in a note that says neither "documentation" nor "correspondence".
3. **Should a section printed on the page count as a cited target?** That is 128 pairs. Since A17 the file holds sections as citers. As targets it has held only document divisions.
4. **Optionally, without an index version:** draw an outbound page node as the document a tap would open, read at draw time through `PageRangeStore` when the target is indexed. That would let build 52's lane carry the outbound half too.

## 8. Side findings, not acted on

1. **43 same-volume page references are never resolved.** `resolvePageBasedCrossReferences` requires `target_volume_id IS NULL`. So a reference written with its own volume's prefix keeps `pg_N`, as `frus1950v06#pg_N` inside `frus1950v06` does, 14 times. All 43 resolve, 37 to one document and 6 to several. The fix is one condition (`OR target_volume_id = source_volume_id`) and the next index version.
2. **The outbound half draws a cross-volume page as a node keyed `volume/pg_N`.** It has no title, and Open is disabled, even when the target volume is indexed (`CrossReferenceGraphViewModel.makeEntry`).
3. **A page link into a volume that is not on the device does nothing.** On iOS and the Mac alike (`resolvePageReference` in `DocumentView` and `MacDocumentView`), a nil answer only prints in Debug. A document link into an absent volume falls back to that volume's Browse page.
4. **The Agentic Analysis Guide's §6.6 sample query returns page anchors.** Run over this index, its top 25 rows are all page anchors, led by `frus1941v01` `pg_367` with 155.
5. **Provenance flows count no page reference.** `ProvenanceFlowIndexGenerator` takes `RefDestination.citedDocument`, which is `nil` for a page, so it skips same-volume pages too. #1509 measured 55,007 such references at `550a8c5c5`, and the app's own index resolves them. The same resolution step could serve it, if the owner wants the flows to count them.

## 9. Reproducing

The notes folder `~/Library/Application Support/Claude/side-session-notes/local_925b2d09-089c-43b0-970e-137754b57ede/page-citations/` holds the following, outside the repository. Run the Python with `python3 -I`.
- `docids.py`: document and division ids from the volume files.
- `population.py`: §2.
- `main.swift`: the harness, compiled with `xcrun swiftc -O -swift-version 5 main.swift PageSpanResolver.swift`. `PageSpanResolver.swift` is the kit's file minus `init?(noteChildren:)`. Its modes are `cross`, `selfnamed` and `ranges`.
- `outcomes.py`: §3.
- `refforms.py` and `joinforms.py`: the printed forms.
- `semantics.py` and `ffsplit.py`: §4's rules.
- `sizes.py`: the file sizes.
- Each script's output.
