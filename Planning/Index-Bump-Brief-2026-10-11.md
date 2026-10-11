# The index bump after build 49 — brief

**Written 2026-10-11**, five days before the date the plan of record gave it (§0c, *Not this week*), because the owner asked for the sessions to begin. It is the brief for the work the plan calls "one index bump": #1535, #1536, #1599 and #1613, with what pull request 4 of §0c handed it and the leftovers §0c listed "for the brief to take or decline".

**Read against** `v2` @ `54506caa`, corpus `99d851c79`, `IndexingPipeline.currentDateIndexVersion` 65. **Measured on** the 553 catalogue volumes' XML at that corpus, and on a full index of them built 2026-10-08 at version 65 (the `iPhone 17e` simulator's `frus.db`, opened read-only; 316,768 rows of `document_cache`). The scripts were scratch files and are not committed; each figure below says which of the two it was read from.

Nothing here is decided for the owner. §4 lists six decisions, each with a recommendation and what a session does if none is given.

## 1. What it carries

| | Item | Changes what indexing stores | Measured | Lands in |
|---|---|---|---|---|
| a | #1535, Browse opens a prose-only chapter, subchapter or compilation | **No** | 1,136 sections in 144 volumes, every one already an indexed row | Pull request 0, with this brief |
| b | #1613, whole-volume references stored as edges to a document | Yes | 6,944 rows in 406 volumes | Pull request A |
| c | Web and mail addresses stored the same way (found here) | Yes | 80 and 46 rows | Pull request A |
| d | Terms and definitions keep the source's line breaks (#1582's cause) | Yes | 198 terms and 49,517 of 66,203 definitions | Pull request A |
| e | The film sections' text holds the video player's script | Yes | 2 rows, not the 12 the plan estimated | Pull request A |
| f | "until January, 1953" in a persons-list entry | Yes | About 20 years, by lane PAGE's count; not measured again | Pull request A |
| g | #1599, 1981–88 vol. XVI's people and terms | Yes | 88 documents, 1,041 pointers | Pull request B |
| h | #1536, text printed at a section's own level | Yes | 1,332 sections in 137 volumes, 1,287,278 characters | Pull request C |
| i | References to a footnote stored as edges to a document named after the note (found here) | Yes | 17,087 rows in 232 volumes | Owner decision 4 |
| j | Subject-Numeric files stored without a designation | Yes | Not measured again | **Declined** (§3.7) |

## 2. How it lands

- **#1535 needs no bump** (§3.1), so it leaves this group and goes first, on its own.
- **The rest is three pull requests in series**, each raising the version in its own commit as the bump rule asks: A to 66, B to 67, C to 68, in whatever order they land. This is how build 49 took versions 63, 64 and 65. A reader re-indexes once, at the build that carries all three.
- **A build is cut before the first of them merges or after the last, never between** (decision 6). A build cut between would give readers two re-indexes and the web edition two pin moves.
- **The web edition.** Each pull request says in its "For the web edition" line that it raises the index version. None of the three adds a table or a column as designed here. The web side moves its pin once, after the last.
- **How each is developed** (§0c's rules): A inline, in one session. B and C are the lanes with design risk, so each is one `lane-dev` run of one lane, or inline if its session judges the design settled by then. One session per pull request, and the next starts when the owner has merged the one before.
- **Each lane edits the manuals** where it changes what they describe, and leaves the AI Generated notice (§0b).
- **Build 50's TestFlight notes** owe one line saying the library re-indexes once on first launch, and a line each for #1535, #1536 and #1599.

## 3. The items

### 3.1 #1535 — a prose-only chapter, subchapter or compilation cannot be opened in Browse

- **Cause.** `VolumeSection.canReadDirectly` answers from `proseReadableKinds`, which lists the front-matter kinds and `appendix` and leaves out `compilation`, `chapter` and `subchapter`. Such a section with no documents and no sections inside it reaches the document list, which says "No documents in this section."
- **It is not an indexing defect.** The parser promotes these sections (`promotableQuasiDocumentKinds` holds all three kinds), so each is a row of `document_cache` and Search already finds it. In the index: **1,136 sections in 144 volumes** (660 chapters, 422 subchapters, 54 compilations), every one with an indexed row and every one with an `xml:id` of its own. The issue counted 1,137 in 145 at corpus `550a8c5c5`.
- **What they hold**, by the stored text after the heading: 774 are a short referral ("See …", 400 characters or fewer), 357 hold other text, in 79 volumes, and 5 are a heading alone.
- **Fix.** The three kinds join `proseReadableKinds`. On iPhone and iPad the section then shows the **Read** button a preface shows; on the Mac its row opens in the reader. No stored value changes, so no version and no re-index.
- **Kit code** (`FRUSCoreKit/Browser/VolumeStructure.swift`), so the landing owes `swift test`.

### 3.2 #1536 — text printed at a section's own level is discarded

- **Cause.** A `<div>` that is neither a document nor a promoted section is transparent: its children pass to the element around it, and at the root they are dropped. A section that holds documents is never promoted (`!frame.hasChildDocuments`), so its own paragraphs, tables and lists reach nothing.
- **Measured in the XML:** **1,332** document-holding sections print text of their own, in **137 volumes**: 2,205 paragraphs, 554 tables, 137 lists; 1,287,278 characters, median 249, the longest 85,724 (`frus1872p2v1` `comp3`). By `@type`: 656 subchapters, 501 chapters, 51 compilations, 2 referral chapters, and 122 `section` divisions (107 `subsection`, 14 `historical-document`, 1 plain). The issue's 1,237 in 141 was the count for the first three kinds at an earlier corpus; it is 1,210 now.
- **What the text is:**
  - **485 are the list of those present at a meeting**, a table and nothing else, in five wartime conference volumes (`frus1941-43` 138, `frus1943` 123, `frus1945Berlinv02` 113, `frus1943CairoTehran` 70, `frus1944Quebec` 41). The app shows a meeting's minutes and not who attended.
  - The longest are statements of a case with the documents filed under them (`frus1902app1`, `frus1872p2v1`).
  - The rest were sampled, not classified. The samples read: a treaty's signature and ratification dates under its title (`frus1912` `ch6`), a chapter's synopsis (`frus1921v01` `ch16`), a bibliographical note (`frus1941v06` `ch6`), an introductory note (`frus1969-76ve07` `ch5`), and a President's message (`frus1898` `ch83`). By the volume's year, 412 are in 1900–1919 and 746 in 1940–1959.
  - `frus1902app1`'s `s05sub04` and `s12`, which the Office of the Historian re-typed from documents to sections on 2026-10-09 (§0c), are two of the 1,332. Their 12,783 characters were in the app until a reader takes the corrected volume.
- **The text carries 1,609 cross-references**, in 217 of the sections. None is in `cross_references` today, so no graph, count or broken-reference mark reaches them.
- **538 of the sections have a page break in or beside their own text.** This is where the design risk is.
- **Recommended design (decision 1).** Give the section a row of its own under its `xml:id`, holding its heading and its own text and none of what its documents hold. This is what #1510 (owner decision D1) already does for the 33 sections that hold other sections and print text of their own (32 in `frus1919Parisv13`), and the page rules written for those apply: the row has no start page, its span is its own breaks, and breaks that follow its text go to the section that begins after them. Browse shows the row first in the section, above its sections and documents, and it opens in the reader. Search finds it.
- **What the lane must measure before it lands**, each on a full index built from the lane:
  - how many page references (`pg_N`) and Citation Lookup answers change document, and that none moves from a document to a section;
  - what Search shows for a section row, and what the document counts in Browse, in a volume's metadata and in Corpus Analytics do with 1,332 more rows that are not documents. A chapter's row is neither front matter nor an editorial note by its stored flags, and the research database export's documents view takes every such row;
  - the reader's previous and next from a section row;
  - `frus1902app1`: `s05sub04` and `s12` come back with their statements, and rows 150 and 174 of the bundled semantic index name ids that exist again, with text that is now shorter than the text their vectors were made from;
  - Spotlight, the exports and a citation of a section row;
  - which bundled indexes read these sections' cross-references or sources, and so are regenerated.
- **Not read for this brief:** `VolumeStructureParserDelegate`, which builds the outline Browse draws, and so how Browse learns that a section has a row of its own (a flag stored with the outline, or a lookup in the index). The lane decides.

### 3.3 #1599 — 1981–88 vol. XVI names its people and terms on `@ana`

- **Measured in the XML:** the volume holds 88 documents, in the four chapters released so far (Ecuador, Paraguay, Uruguay, Venezuela; the manifest marks it partly published). All 88 carry `ana`: 1,041 pointers, 622 to people and 419 to terms, naming 117 people and 104 terms, and every pointer resolves to an `xml:id` in the volume. No document has an inline `persName corresp` or `gloss`. No other of the 744 files has `ana` on a `<div>`.
- **In the index:** 120 people and 108 terms from the volume's lists, and **0 rows of `person_mentions`**, so none of its people gains a mention from it.
- **What history.state.gov does** (seen 2026-10-11, document 368): the document's text has no person or term link, and the sidebar lists 7 Persons and 5 Abbreviations & Terms, which are that document's 12 pointers. Document 1 of the volume is a placeholder there, as its chapter is not released.
- **The app has no list of a document's people.** `PersonMentionStore.personRefs(forDocumentId:volumeId:)` exists and nothing calls it; a reader meets a person only through an inline link.
- **Recommended design (decision 2).**
  - The parser reads `ana` on a document's `<div>` and the document's AST carries the pointers.
  - Indexing stores a `person_mentions` row for each `#p_` pointer, beside any inline ones. People, Find all mentions and Person Analytics then count the volume. No table is added: terms have no mentions table, and none is needed for the list below.
  - The reader draws two lists at the foot of such a document, **Persons** and **Abbreviations & Terms**, each entry the link an inline name or term would be, so the existing person card and term definition open from it. The lists are drawn outside the document's flat text, as a figure's caption is, so stored highlights and `body_text` stay where they are.
  - A document with inline links gets no list. Giving every document one is a feature and is not proposed here.
- **Kit code throughout**, which the web edition's reader shares.

### 3.4 #1613 — a reference to a whole volume is stored as an edge to a document

- **In the index:** 6,944 rows in 406 source volumes have a volume's id as `target_document_id` and no `target_volume_id`: 6,408 from footnotes and 536 from editorial notes.
- **What reads them** (read in `CrossReferenceStore`, not run):
  - A document's graph draws each as a placeholder node, a document named `frus1861` in the reader's own volume (`graph(forDocumentId:…)` makes a placeholder for any endpoint it finds no row for).
  - The collection inspector's cross-reference count and the store's `edgeCount` count them.
  - The research database export's `research_cross_references` view exports every row not marked broken, these among them.
  - The rankings, the histogram, PageRank and Related Documents do not: `documentTargetPredicate` already refuses `frus*`, and Related Documents joins `document_cache`.
  - The volume-to-volume counts do not either, because the row has no target volume. 52,506 rows name another volume now; 5,688 of the 6,944 name a volume this index holds, and they are not among them.
- **Two choices (decision 3).** (a) Store no row. (b) Store the row with the volume as `target_volume_id` and an empty `target_document_id`, so the volume graph counts it, and guard the document-level queries against the empty id: the two edge lists, `edgeCount`, the per-node counts and `documentTargetPredicate`, as read here. The corpus holds 8,266 such references in the catalogue volumes, 6,997 to a catalogue volume.
- **Web and mail addresses** (item c) are stored the same way: 80 rows whose target begins `http` and 46 that are `mailto:history@state.gov`. They are not cross-references. Recommended: store no row, in the same change.
- **References to a footnote** (item i): 17,087 rows in 232 volumes have a note's id (`d748fn3`) as `target_document_id`. #988 fixed the tap; the stored row still names no document. `inboundEdges` matches `target_document_id` exactly, so a document cited through one of its notes does not list the citing document, and `documentTargetPredicate` refuses `*fn*`, so the rankings do not count it. Storing the document that holds the note would add 17,087 edges to the 116,602 that name a document now. That is decision 4.
- **Not worked out:** why 6,944 is below the corpus's 8,266. References printed in a section's own text (§3.2) and in sections the index leaves out are not stored, which accounts for some of it. The lane counts it with the kit's own extraction.
- **`markBrokenCrossReferences` matches a row by its raw target**, so whichever choice is taken is applied after that pass, as page resolution is.
- **`CrossRefKit`'s mirror grammar** has no whole-volume case (§0c). The generators that use it read the corpus themselves; the lane says in its pull request whether any bundled file changes.

### 3.5 Terms and definitions keep the source's line breaks

- **In the index:** 198 of 66,203 terms and 49,517 definitions hold a line break, in 313 volumes. #1582 made the lookup fold them as it reads. The parser folds them here, and the lookup's fold stays.

### 3.6 Two small leftovers, taken

- **The film sections' text.** §0a estimated 12 sections of `frus1917-72PubDip` from the code. In the index it is **2 rows**, `appendix-5` and `appendix-11`, whose text holds `298x530` and `brightcove.createExperiences();`. The transcripts in the other volumes are printed text and stay.
- **"until January, 1953".** `PersonsParserDelegate`'s month-and-day pattern takes a comma only after a day, so the year reads as a start. Lane PAGE counted about 20 such years, 7 of them an entry's only year. The fix is the one its entry gives; the lane measures every list entry through the kit's parser before and after.

### 3.7 Declined: Subject-Numeric files stored without a designation

Lane NOTE left 126 central-file notes, 55 `AID` notes and about 778 notes led by the National Archives; its entry adds that the Archives Visit packet prints no designation for any note of that last kind, 5,951 of them citing `RG 59, Central Files`. A fix changes `SourceNoteKit`'s routing and the bundled indexes built from it, which is a lane of its own with its own measurements, and lane CFPF's version 65 may have moved the counts. It is not in this bump. It waits for an issue, and for the next build's bump if it is taken.

## 4. Owner decisions

Each has a recommendation. A session goes ahead on the recommendation unless the owner has said otherwise by the time it starts, and says so in its pull request.

1. **#1536, how a section's own text is kept.** *Recommended:* a row of its own, searchable, first in the section in Browse (§3.2). *The other choice:* shown in Browse only and kept out of Search, stored with the volume's outline. It is less work in Search and the counts, and it leaves 485 lists of those present at a meeting unsearchable.
2. **#1599, where a document's people and terms show.** *Recommended:* stored as mentions, and listed at the foot of the document (§3.3). *The other choice:* stored as mentions only, so People counts them and the reader shows nothing.
3. **#1613, a reference to a whole volume.** *Recommended:* (b), a volume-to-volume row, because the reference is a link between two volumes and the volume graph is where those are counted: about one more row for every nine it counts now. *The other choice:* (a), no row, which is the smaller change and leaves the volume graph as it is. Either way the placeholder nodes go. Taking (a) now and (b) in a later build costs readers a second re-index. If (b)'s guards turn out to reach past the queries §3.4 names, the session takes (a) and says so.
4. **References to a footnote.** *Recommended:* store the document that holds the note, in pull request A, so a citation of a note counts as a citation of its document. It moves the cross-reference rankings: 17,087 more edges on 116,602. *The other choice:* leave them, and file it.
5. **The leftovers.** *Recommended:* take the three small ones (§3.5, §3.6) and decline Subject-Numeric (§3.7).
6. **Build 50.** §0c left open whether it goes out before the bump or carries it. *Recommended:* it goes out before pull request A merges, carrying #1576, #1577's lanes so far and #1535, since through build 49 a fresh download of the two re-packed shards is refused, and pull request C is the longest lane of the three. The bump then ships together in build 51.

## 5. Order

| | Pull request | Issues | Version | Session starts from |
|---|---|---|---|---|
| 0 | Browse opens prose-only sections; this brief | #1535 | — | Done with this brief |
| A | Stored values that name nothing or carry noise | #1613, items c to f, and i if decision 4 says so | 66 | §3.4 to §3.6 |
| B | Vol. XVI's people and terms | #1599 | 67 | §3.3 |
| C | A section's own text | #1536 | 68 | §3.2 |

B and C can change places. C is the largest and the one a corrected volume has already made worse, so if only one more can land before a build, it is C.

## 6. Not measured, and not verified

- **Nothing in this brief was seen in the app.** The index figures are SQL over a stored index and the corpus figures are counts over the XML; the consumers of §3.4 were read in the code.
- The index was built on 2026-10-08, before the corpus moved to `99d851c79`. The corpus counts are at `99d851c79`. No figure here compares the two.
- The XML counts use `@type` and a plain reading of each division's children. The kit's parser decides a section's kind through `VolumeStructureParserDelegate.structuralKind`, which was not run, so §3.2's counts by kind may differ from what a lane measures by a few sections.
- Whether any of the web edition's three fixture volumes holds a section of §3.2, a whole-volume reference or a line-broken definition was not checked; if one does, its golden files move when its pin does.
- What the semantic map, Related Documents' other signals and the summarizer do with a section row was not read.
