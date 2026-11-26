# A2 first: what *Abbreviations & Terms* needs from index version 76

**Row CR's step before the review, 2026-11-26.** The plan of record (§1c) has CR read A2 first, because the block reads
a table that index version 76 stores and row L26 builds. Anything more the block needs from the index joins version 76
before L26 lands, or waits for the build after 1.1. Read from L26's branch at `40f70883` and the public TEI at corpus
`216cdb764`, the commit L26 measured. Nothing was built or run in the app.

**The verdict, and the owner's word.** The block needs one thing more: **which part of a document each term is linked in.**
`term_mentions (volume_id, document_id, term_ref)` records that a document links a term, and not where. A quarter of the
document–term pairs are linked only inside notes. So a block that lists every row lists terms the page does not print,
under four of the six document templates. Put to the owner the same day ("Should L26 add a parts column to
term_mentions before it lands?"), the owner answered: "Add it to v76". The proposal below went to the L26 session with
those words.

## The measurement

`a2_where_terms.py`, beside this file, reads every `volumes/*.xml` with the standard library alone, in about 30 seconds.
It walks each `<div type="document">` and each editorial-note division, and classes each `<gloss target>` by its nearest
enclosing part:

- `source`: inside a `<note type="source">`, in either era;
- `note`: inside any other `<note>`;
- `head`: inside the `<head>`, outside a note;
- `body`: anywhere else;
- `ana`, in addition: a term of its list that `frus1981-88v16` names on a division's `@ana`.

It counts one pair per document and term. The totals are 497,026 pairs, 113,045 documents and 312 volumes. L26's index
has 498,757 rows for 113,714 documents, because the index counts a few more divisions as documents.

| The parts a pair is linked in | Pairs | Share |
|---|---|---|
| text only | 325,432 | 65.5% |
| the source note only | 72,771 | 14.6% |
| other footnotes only | 41,579 | 8.4% |
| text and footnotes | 25,725 | 5.2% |
| text and the source note | 12,064 | 2.4% |
| footnotes and the source note | 10,141 | 2.0% |
| text, footnotes and the source note | 4,876 | 1.0% |
| the heading only | 1,966 | 0.4% |
| the rest (heading combinations; `@ana` alone, 419) | 2,472 | 0.5% |

**Only in notes: 124,491 pairs, 25.0%.**

| Volumes, by the year in their id | Volumes | Pairs | Only in notes | Only in the source note | Only in other footnotes |
|---|---|---|---|---|---|
| before 1955 | 93 | 142,162 | 16.2% | 4.8% | 10.4% |
| 1955 to 1968 | 113 | 172,687 | 28.6% | 18.2% | 8.0% |
| 1969 on | 105 | 181,758 | 28.6% | 19.0% | 7.2% |

207 of the 311 volumes that link a term in their text or notes have at least a fifth of their pairs only in notes. (The
312th, `frus1981-88v16`, names its terms on `@ana` alone.)

**The design's example hides it.** The eight telegrams of `frus1946v06` (§2.2) link every term in their text, and the
script reproduces A2's five rows from them. Two documents of `frus1969-76v06` show the rest:

- **d1** links *NIE*, *SNIE* and *Limdis* only in its source note: "…NIC Files, Job 74–R1012A, NIEs and SNIEs. Secret;
  Sensitive; Limdis; Controlled Dissem."
- **d4** links *CINCPAC* and *COMUSMACV* only in its footnote 3.

## What prints, by document template

From the design's §4.3 table and its §3.5:

- ***Full text as printed***, ***Full text with everything***: every part prints, and the block is exact either way.
- ***Full text with your annotations***: footnotes off and source notes on, so a term linked only in other footnotes
  does not print.
- ***Summaries***, ***Citations with your notes***, ***Citations with source notes***: the text does not print. The
  heading's words print as a line (§3.4). The source note prints as the *Source:* line where Source note is on, as plain
  text from the index's copy (`doc.sourceNoteText`, `CollectionItemHTMLRenderer.swift:379-382`). About four pairs in five
  then name a term the page does not show.

Decision 173 puts the block in no suggested set. But step 2's *All* adds it to any collection, one that prints citations
alone included.

## What was proposed for L26, and taken

- `term_mentions` gains `parts INTEGER NOT NULL`, flags OR'd over the document: the text 1, the heading 2, a footnote
  4, the source note 8, named on `@ana` 16. One row per document and term, as now, so L26's counts stand.
- The walk carries the part down (`IndexingPipeline.collectDocumentRefs`):
  - `.head` → the heading;
  - `.footnote(type: .source)`, and everything inside it, → the source note;
  - any other `.footnote` → a footnote;
  - a note inside the heading takes the note's part, since from 1955 the source note is a footnote on the heading;
  - an `.editorialNote` inside a document → the text;
  - `@ana` → 16.
- `termsLinked(inDocument:volumeId:)` returns the flags, or a read beside it does. The read's shape can change in L52;
  only the column has to be in version 76.
- A test: one fixture document with a term in each part, and the flags read back.
- No bundled file reads `term_mentions`. On `40f70883` only `IndexingPipeline.swift`, `PersonMentionStore.swift` and
  `IndexingPipelineTests.swift` name it, so `cited-page-map.json` and `volume-annotations-index.json` stand.

## What L52 owes, which is not the index's

- **The block knows the documents, not what prints.** A block is given the collection's documents and not its entries
  (`CollectionGeneratedBlocks.swift:155-160`). So the blocks' data source passes, for each document, the parts its
  resolved settings print: text depth, Footnotes and Source note, as the assembly resolves them (`resolveEntry`). A term
  is listed for a document where any part it is linked in prints.
- **Decision 174's links need a row for every printed gloss.** With the column the rows are exact. Without it they would
  be a superset, which links would still reach.
- **1.0's Persons Index has the same gap.** `person_mentions` has no part either, so a person named only in a footnote is
  indexed under Footnotes off. That is not this block's to change. The review may say whether the same column is wanted
  for people at the next index version.
