# The index bump after build 49 — brief

**Status: COMPLETE, 2026-10-11.** Its four pull requests merged that day as #1638 (version 66), #1639 (67), #1640 (68) and #1645 (69), after #1637 took #1535 with no bump. Build 50 carries all four. This file stays at the Planning root, where a finished brief would otherwise move to `Completed/`, because `FRUSCoreKit/Search/IndexingPipeline.swift` cites it by this path in four places. "The plan of record" below is `Completed/Plan-Of-Record-2026-09-28.md`, and §0a, §0b and §0c are that plan's sections. What the four pull requests measured and did not build is in `Completed/Plan-Of-Record-2026-10-11.md` §5a and §5b, carried forward in the live plan's §6d and §6e.

**Written 2026-10-11**, five days before the date the plan of record gave it (§0c, *Not this week*), because the owner asked for the sessions to begin. It is the brief for the work the plan calls "one index bump": #1535, #1536, #1599 and #1613, with what pull request 4 of §0c handed it and the leftovers §0c listed "for the brief to take or decline".

**Read against** `v2` @ `54506caa`, corpus `99d851c79`, `IndexingPipeline.currentDateIndexVersion` 65. **Measured on** the 553 catalogue volumes' XML at that corpus, and on a full index of them built 2026-10-08 at version 65 (the `iPhone 17e` simulator's `frus.db`, opened read-only; 316,768 rows of `document_cache`). The scripts were scratch files and are not committed; each figure below says which of the two it was read from.

**The owner answered §4's six decisions on 2026-10-11**, after joshbotts/FRUS-Explorer#1637 merged; §4 records each. The first five are as recommended, except that the Subject-Numeric files, which this brief declined, are now pull request D. The sixth is not as recommended: build 50 carries the bump.

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
| i | References to a footnote stored as edges to a document named after the note (found here) | Yes | 17,087 rows in 232 volumes | Pull request A (decision 4) |
| j | Subject-Numeric files stored without a designation | Yes | 9,443 citations at version 65: 2,419 with a series and no class key, 194 with neither | Pull request D (§3.7) |

## 2. How it lands

- **#1535 needs no bump** (§3.1), so it leaves this group and goes first, on its own.
- **The rest is four pull requests in series**, each raising the version in its own commit as the bump rule asks: A to 66, B to 67, C to 68 and D to 69, in whatever order they land. This is how build 49 took versions 63, 64 and 65. A reader re-indexes once, at the build that carries all four.
- **Build 50 carries the bump** (decision 6, the owner's, 2026-10-11): no build is cut until A, B, C and D have merged. A build cut between would give readers two re-indexes and the web edition two pin moves.
- **The web edition.** Each pull request says in its "For the web edition" line that it raises the index version. None of A, B and C adds a table or a column as designed here; D is not designed yet. The web side moves its pin once, after the last.
- **How each is developed** (§0c's rules): A inline. B and C are the lanes with design risk, so each is one `lane-dev` run of one lane, or inline if its session judges the design settled by then. D begins with a measurement of its own (§3.7). The next starts when the owner has merged the one before.
- **Each lane edits the manuals** where it changes what they describe, and leaves the AI Generated notice (§0b).
- **Build 50's TestFlight notes** owe one line saying the library re-indexes once on first launch, and a line each for #1535, #1536 and #1599, with what D changes for a reader.

## 3. The items

### 3.1 #1535 — a prose-only chapter, subchapter or compilation cannot be opened in Browse

- **Cause.** `VolumeSection.canReadDirectly` answers from `proseReadableKinds`, which lists the front-matter kinds and `appendix` and leaves out `compilation`, `chapter` and `subchapter`. Such a section with no documents and no sections inside it reaches the document list, which says "No documents in this section."
- **It is not an indexing defect.** The parser promotes these sections (`promotableQuasiDocumentKinds` holds all three kinds), so each is a row of `document_cache` and Search already finds it. In the index: **1,136 sections in 144 volumes** (660 chapters, 422 subchapters, 54 compilations), every one with an indexed row and every one with an `xml:id` of its own. The issue counted 1,137 in 145 at corpus `550a8c5c5`.
- **What they hold**, by the stored text after the heading: 774 are a short referral ("See …", 400 characters or fewer), 357 hold other text, in 79 volumes, and 5 are a heading alone.
- **Fix.** The three kinds join `proseReadableKinds`. On iPhone and iPad the section then shows the **Read** button a preface shows; on the Mac its row opens in the reader. No stored value changes, so no version and no re-index.
- **Kit code** (`FRUSCoreKit/Browser/VolumeStructure.swift`), so the landing owes `swift test`.

### 3.2 #1536 — text printed at a section's own level is discarded

**Done on 2026-10-11 as pull request C, index version 68**, as recommended below, with four things the design did not have. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was seen.

- **Which page breaks are the row's.** A break is part of the row only when text of the section's own follows it before the next division inside it. The design said "its span is its own breaks", and 324 of the rows have breaks that sit between their documents: read that way, a first build made a section an answer for every page between its first and last break, 114 pages in six volumes where the page had named one document.
- **The reader's page is the row.** A parse for one section now makes the index's decisions from the section's opening tag. Until now it decided nothing, so the reader opened a section that holds sections with everything inside it, while the index held its own text alone (the 33 rows of #1510). A section the index leaves out still opens whole, by a second reading of the file.
- **Browse finds the row in the index's rows** it already loads for the section (`VolumeSection.ownTextEntry(among:)`). Nothing is added to the stored outline.
- **The reading order** puts a section's own row first in the section. A row of this kind used to come after everything else in the volume.

**What the lane measured**, on two full indexes of the 553 volumes built through the kit's own pipeline, one from `v2` at version 67 and one from the branch, and compared by SQL:

- **The rows.** 1,337 rows in 139 volumes (316,814 to 318,151), 1,421,459 characters of stored text, median 351. They are the 1,332 counted from the XML and five whose own content is an image and no words. No other row changed, in text or in order. 14 are front matter by their kind, all in `frus1902app1`.
- **Page references:** two stored references change, both from a page that named nothing to the section that prints a diagram on it (`frus1919Parisv01`, "See diagram on page 112."). None moves from a document to a section.
- **Citation Lookup's page answers:** of 504,863 pages that name something in either index, 208 in 20 volumes named nothing and now name a section; in `frus1969-76ve05p2`, which numbers its pages in every document, one page number gains a section among the 158 documents that already shared it; no other answer changes.
- **Cross-references:** 1,789 rows from 316 of the sections, 445 of them into another volume (62 to a whole volume); one is marked broken, by the bundled index, which is read by volume and target and so needs no regeneration.
- **People:** 4,461 mentions in 358 of the sections, most of them the lists of those present (`frus1945Berlinv02` 1,245, `frus1943CairoTehran` 1,012, `frus1945Malta` 911). In `frus1945Berlinv02`, 30 people its list of persons names had no mention and now have one.
- **Dates and sources:** 110 of the rows are dated, by a date their own text prints (86 are meetings of `frus1952-54v05p1` and `p2`, which print a dateline under the heading); 15 have a source note, of which 8 are a decimal file number, 2 a named file and 5 no archival citation ("[Translation.]", "No. 131."); 33 footnote citations in 3 sections are stored as external citations.
- **Search, the counts, Spotlight, the exports, a citation:** a section's row is treated as a prose section's row already was, since it is stored the same way. The volume and series document counts the app shows come from bundled files and do not move. Read in the code; Search was also seen.
- **Previous and next:** from a section's row, Next is its first document and Previous the row before the section. Seen.
- **`frus1902app1`:** `s05sub04` and `s12` are rows again, 8,410 and 4,370 characters. The item about rows 150 and 174 of the semantic index no longer applies: the re-pack of 2026-10-10 gave the volume 196 rows, `d1` to `d196`. No section row has a vector, so a Meaning search does not return one.
- **Bundled indexes:** none is regenerated. `resolved-edge-index.json` takes only references inside a document, so it lacks the 383 references to documents of other volumes that sections' own text makes; `external-citation-index.json` lacks the 33 citations and `source-provenance-index.json` the 15 source rows.

*What follows is the item as the brief first gave it.*

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

**Done on 2026-10-11 as pull request B, index version 67**, as designed below, with one thing the design did not have: the app answers a tap on a person or a term from the page it registered, so the listed entries carry the volume's whole entries and `FRUSURLSchemeHandler` registers them. The first build listed the names and opened "Person Information Unavailable" for each. The session entry in `DEVELOPMENT-PLAN.md` has what was measured and seen.

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

### 3.7 Pull request D: Subject-Numeric files stored without a designation

This brief first declined the item, on lane NOTE's counts of 2026-10-01. The owner asked for the reasons, was given them with the figures below, and on 2026-10-11 asked for it to be pull request D.

**Done on 2026-10-11, at index version 69.** The session entry in `DEVELOPMENT-PLAN.md` has the method. What this section said before the measurement is kept under it, because two of its three changes turned out differently.

- **Measured first**, on a full index at version 68 of the 553 catalogue volumes (corpus `99d851c79`), every stored source note read again through `SourceNoteKit`: 9,443 documents cite a Subject-Numeric file, 6,830 stored a class key and 2,613 did not.
  - 285 needed no new grammar. The rule that places a citation by its form already read their class, and the index stored none: the parsed series was the record group's own name (`RG 59, Records of the Department of State, Central Files …`), or a classification ran on after the designation with no full stop.
  - 768 print a subject number in a spelling the class grammar refused: a space beside a dash, a country word longer than six letters, a post in parentheses (`DEF 18–3 USSR (MO)`), stops (`U.S.`), an ampersand, a dash joining the number to what is around it, or a country not in capitals.
  - 1,498 print no subject number (`POL US–USSR`). The 1963 handbook lets an office file papers under the primary subject alone and arrange them by country, so these are files, not designations cut short.
  - 62 are still without a key: 7 give a block of years and nothing else, and 55 print something the app does not read as a designation (a handling caption, prose run on after the number, a country that is no area code with no number before it).
- **What version 69 stores.** 9,381 of the 9,443 have a class key, on 1,929 distinct keys (1,361 before). 2,593 rows gain one: the 2,551 above, 40 decimal numbers worded through the National Archives, and 2 whose second sentence cites a file. 178 keys change spelling, each to restore a dash a space followed (`POL 27 INDIA PAK` is `POL 27 INDIA-PAK`). None is lost and no row changes its form. 62 still have none. By two full indexes compared table by table, nothing else in the index moves but 172 front-matter rows that gain a class.
- **A file with no subject number has a class** (`POL US-USSR`, `AID (US) INDIA`), 303 keys over 1,498 documents. In the rankings it is grouped under its category, as a numbered file is under its category and number: 30 such groups, of which `POL` holds 1,242 documents and is now the second-largest row of the Subject-Numeric file after `POL 27`.
- **One list of neighbours for one file.** A file was matched by its class when cited through the National Archives and by its printed designation when cited through the Department, so each wording missed the other. Both are matched by class now: 271 files are cited both ways, by 2,180 documents in one wording and 2,499 in the other.
- **The country word list** is the bundled label table's own area codes (155 words). A country printed in title case is read when its words are among them (`POL 27 S Viet`), or, in a document's own citation, when one or two words follow a subject number (`POL 28 Berlin`): 23 such words in 142 notes, all names. In a volume's list of sources the second rule is off, because an embassy's files are listed there by subject title (`DEF 18–4 Defense Affairs`).
- **The Archives Visit packet was already done**, by #1543.
- **Bundled files.** `collection-authority.json`, `collection-usage-index.json`, `provenance-flow-index.json` and `external-citation-index.json` are regenerated; each was first reproduced byte for byte from the unchanged generator. Four that could have moved did not (`volume-sources-index.json`, `source-provenance-index.json`, `series-facts-index.json`, `lot-claimants-index.json`).
- **`subject-numeric-labels.json` is not regenerated.** On this Mac under macOS 27.0.1 the unchanged generator no longer reproduces the shipped table from the same handbooks, and what it writes instead has wrong country names. So a new key's country is named only where the shipped table already has its code: for 84.2% of documents under the 1963 schedule and 79.5% under 1964–1973 (94.6% and 89.3% at version 68, whose keys the table was generated from). A key that got its dash back is new to the table too: of the 178 respelled documents, 44 and 30 lose the reading the table holds under the old spelling. The runbook's entry has the differences, and the wrong entries the shipped table already carries (under 1964–1973, `UK` reads *Ukraine* and every numbered `AID` file a piece of another line). #1644 is the issue for the table and its generator.

*As written on 2026-10-11, before the measurement:*

- **In the index at version 65** (lane CFPF's `subject_numeric` form): 9,443 documents cite a Subject-Numeric file.
  - 6,830 store a designation and a class key, so the file is matched.
  - 2,419 store a series and no class key: 1,496 worded through the National Archives, where the stored series is the block of years (`Central Files 1970–73`, for `RG 59, Central Files 1970–73, AID 3 India`); 911 worded through the Department, where it is the designation (`POL GER W–US`); 12 worded as neither.
  - 194 store neither: 184 through the Department (`AID (US) S VIET`, `INCO–GRAINS GATT`, `POL Pol–US`) and 10 through the National Archives.
- **It is three changes.**
  - *A country element that is not in capitals.* Roughly 1,100 of the 2,613 without a class key print a category and a subject number the parser does not read (`AID 3 India`, `POL 27–14 Arab-Israeli`); the figure is from a rough pattern over the note text. The rule refuses lower case so that prose stays out, and admitting these needs a word list of countries. Whether the bundled `subject-numeric-labels.json` can supply one was not checked.
  - *No subject number.* The rest print no number (`POL US–USSR`), so there is no class key to store, only a designation, which the notes worded through the National Archives do not store.
  - *The Archives Visit packet.* `TripPacketBuilder.fileDesignation` prints no designation for a note parsed as a National Archives collection. Lane NOTE counted 5,951 notes citing `RG 59, Central Files` that way; how many reach that rule since version 65 was not counted.
- **What it touches.** `SourceNoteKit`, which the generators and the web edition share. A change to what it stores moves `collection-usage-index.json` and the files regenerated after it (CLAUDE.md's central-files chain), and `subject-numeric-labels.json`, which is regenerated from the handbooks on the owner's Mac and whose coverage block is already out of date.
- **What a reader has meanwhile.** These documents are in the Subject-Numeric File category already. For those without a class key, Source Explorer matches by series or says the citation is not in a form it can match on. Nothing shown is wrong.
- **The session starts by measuring**, over every document source note through `SourceNoteKit` itself: each shape's count, what a word list would admit that is prose, and what the packet prints. Lane NOTE's 126, 55 and "about 778" are not today's 184, 10 and 1,496.

## 4. Owner decisions

**Answered by the owner on 2026-10-11**, after #1637 merged: "take first five recommendations. build 50 will carry the bump.", and then "add subject-numeric to the brief as pull request D."

1. **#1536, how a section's own text is kept.** *Decided:* a row of its own, searchable, first in the section in Browse (§3.2). The other choice was Browse only, kept out of Search.
2. **#1599, where a document's people and terms show.** *Decided:* stored as mentions, and listed at the foot of the document (§3.3). The other choice was mentions only.
3. **#1613, a reference to a whole volume.** *Decided:* (b), a volume-to-volume row. If its guards reach past the queries §3.4 names, the session takes (a), no row, and says so.
4. **References to a footnote.** *Decided:* store the document that holds the note, in pull request A. It moves the cross-reference rankings: 17,087 more edges on 116,602.
5. **The leftovers.** *Decided:* take the three small ones (§3.5, §3.6). The Subject-Numeric designations, which this brief recommended declining, are **pull request D** (§3.7).
6. **Build 50.** *Decided, and not as recommended:* build 50 carries the bump. No build is cut until A, B, C and D have merged. Until it is out, builds through 49 refuse a fresh download of the two re-packed shards (§0c).

## 5. Order

| | Pull request | Issues | Version | Session starts from |
|---|---|---|---|---|
| 0 | Browse opens prose-only sections; this brief | #1535 | — | Merged, #1637 |
| A | Stored values that name nothing or carry noise | #1613, items c to f, and i | 66 | Merged, #1638 |
| B | Vol. XVI's people and terms | #1599 | 67 | Merged, #1639 |
| C | A section's own text | #1536 | 68 | Merged, #1640 |
| D | Subject-Numeric files stored without a designation | none filed | 69 | Merged, #1645 |

C and D could change places; C went first, as the largest and the one a corrected volume had already made worse. All four merged on 2026-10-11, and build 50 carries them.

## 6. Not measured, and not verified

- **Nothing in this brief was seen in the app.** The index figures are SQL over a stored index and the corpus figures are counts over the XML; the consumers of §3.4 were read in the code.
- The index was built on 2026-10-08, before the corpus moved to `99d851c79`. The corpus counts are at `99d851c79`. No figure here compares the two.
- The XML counts use `@type` and a plain reading of each division's children. The kit's parser decides a section's kind through `VolumeStructureParserDelegate.structuralKind`, which was not run, so §3.2's counts by kind may differ from what a lane measures by a few sections.
- Whether any of the web edition's three fixture volumes holds a section of §3.2, a whole-volume reference or a line-broken definition was not checked; if one does, its golden files move when its pin does.
- What the semantic map, Related Documents' other signals and the summarizer do with a section row was not read.
