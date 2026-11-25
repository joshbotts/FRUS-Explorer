ID: EDI-1
Severity: S1
Claim: With Numbering on, which §4.3 gives three templates and every new collection, the export's own apparatus and the volumes' own notes say "Document N" by the volume's number, under leads that carry the collection's number in the volume's own form, so they send a reader to the wrong document; the remedy is a §8 candidate that Q8 does not recommend.
What a person meets: A reader of a PDF, Word or web export from a new collection (it starts under Full text as printed), made on any platform. Six documents of the 1977–1980 volume VI, the volume's 2, 4, 5, 6, 9 and 12, lead "1." to "6.". The first reads "1. 2. Memorandum From…", because from 1955 the volume's number opens the heading itself. A footnote under it says "See Document 4", which here is the collection's 2. Sources & Archives at the back lists "Document 2" and "Document 4" under each archive, and under Full text with your annotations the Persons Index lists "Documents 2, 4, 5". All of these are the volume's numbers. The Note says only that "each volume's own number is in the citation".
Evidence:
- Record §4.3: "the documents numbered 1 to n in its order, at each lead and in each contents row"; its table gives On to the first three templates; "A new collection starts under Full text as printed". §3.2: "the collection's number, where this heading leads". §3.3: "Its form is a question for the owner". §8 item 2: the indexes "could cite Documents 3, 7 and 12 of the collection, where they now cite each volume's number". Q8: "Recommended for the first pass: 1 … and 4".
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:716-724 ("Document \(token.text)"), :730-738 ("Documents \(joined)"), :465-468, :566-569, :598-601, :709-710. The number is the volume's.
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:226-237: each of the three templates places one of those blocks, and :227 turns footnotes on.
- TEI, counted with ElementTree (scripts in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-EDI/):
  - the head opens "N. " in 1,694 of 1,694 documents of the five volumes from 1955–57 to 1977–80, and "No. N" on its own line in 720 of 720 of frus1952-54v08;
  - no head opens with a number in the 1,551 documents of frus1946v06 and frus1950v06, which is where the record's only example comes from;
  - 1,698 same-volume references print a document number ("Document 12", "footnote 2, Document 14"), 1,645 of them inside a note, in 1,004 of the 2,414 documents of the six volumes from 1952–54.
- The prefaces of frus1969-76v17 and frus1977-80v06: "The numbers in the index refer to document numbers rather than to page numbers."
- /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:944: in the web page such a reference is a `frusexplorer://doc/…` link, which a browser cannot follow.
- /home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationFormatter.swift:188-191, :476-480: for the 217 documents a volume prints unnumbered the citation carries no number, so the collection's is the only one on the page.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:78 ("numbered 1 to 6"); OptionA.dc.html:236.
Refutation: A rule in the core lanes that makes the blocks cite by the collection's numbers, or a word on the page for the number. Checked §3.3, §3.6, §4.3, §8, §9, Q4 and Q8: Q4 asks the number's form only, and no form of "4." makes "Documents 2, 4" in an index point right.
Direction: Do not number the leads until the blocks cite by the same numbers, and give the number a form or a word that no volume prints.

ID: EDI-2
Severity: S1
Claim: A date line of the author's prints with no mark on the page, in the place and form of a volume's own dateline; the only statement of it is one sentence of a Note the author may remove, and that sentence speaks of a date line "under a title" while the field can be filled without one.
What a person meets: A reader of any export. "4. The Long Telegram / Moscow, 22 February 1946" stands as heading and dateline, the series' own opening. Three lines down the printed dateline follows, also unlabelled. In the contents list the row reads "4. The Long Telegram — Moscow, 22 February 1946", directly under a row whose words after the dash are the volume's. A listener hears no word that says whose date it is. Where the author typed a date line and no title, nothing says where it prints or what marks it.
Evidence:
- Record §3.1: "the words are the mark. They are read aloud, where a bracket is not". The only words are "Printed heading:".
- Record §3.6: "What cannot be removed is on the page itself: the words Printed heading: under a title, and the line of attribution under a summary". The date line is not in that list. The Note's draft covers "a date line under a title".
- Record §3.2: "Your date line … given or not, for one document". Q7: "printed under the title".
- The first review's direction for G8 (/home/user/FRUS-Explorer/Planning/Collections-Design-Adversarial-Review-2026-11-25.md:126): "marked in words".
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:71 against :73 (the same slot in two rows), :80, :115; OptionB.dc.html:98-105 (two independent fields); OptionC.dc.html:66-69. §3.4's contents row names no date line; the board prints one.
- TEI: from 1955 a plain dateline under the heading is the editors' own line. 46 of the 47 datelines reading "undated" in the five volumes from 1955–57 carry no bracket. In frus1950v06 5 of 5 are bracketed, and 24 of 852 datelines are bracketed whole. All 323 first datelines of frus1955-57v24 are in italic.
Refutation: A line of the record that puts words beside the date line on the page, or ties the field to a title. Checked §3.1 to §3.6, §5.2, Q2, Q7 and the four boards; none.
Direction: Give the date line the same kind of mark the title has, on the page and in a contents row, or drop it under Q7.

ID: EDI-3
Severity: S2
Claim: Under a look chosen in the export sheet the Note on the Text does not print, by §4.4's list of what prints and by the sheet's own board, though that is where notes are first left out and numbers first given; §3.6 says it prints by default, so the record contradicts itself and G10's own scenario stands.
What a person meets: On iPhone, from the Collections list, the owner picks "Full text with your annotations", PDF, Export. The reader gets leads numbered 1 to 6, two titles of the compiler's, footnote calls in the text with no notes, and no Note. The sheet's sentence for that look ends "A Chronology and a Persons Index follow." A collection of summaries alone gets no Note either, though its template numbers its leads.
Evidence:
- Record §3.6: "By default, whenever it has something to say about a document whose text prints: a title or a date line added, a number given, or notes left out."
- Record §4.4: "prints the template's blocks at the end, with any block the author placed where it stands, and without the blocks the collection's own template placed". The Note is none of the three.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:78: only "As this collection is set" ends "…and a Note on the Text follow". Lines :80 to :90, the six looks, name no Note. Line :80 also drops "numbered 1 to 6".
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:231 (`footnotes: false`), :235 (`.summaryOnly`).
- The calls stay: /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:339-344; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1579-1582.
- The Note is both a switch and a row. Switch: §5.2 Back matter, §7.2 "the five back-matter switches", OptionA.dc.html:249 ("On"). Row: §3.6 "move it as any block", OptionA.dc.html:57, OptionB.dc.html:61. §5.7 says "The first form's five switches are gone".
Refutation: A sentence of §4.4 or §5.1, or a board sentence for any of the six looks, that names the Note. Checked; none.
Direction: State the Note's rule over the plan that is printed, whichever look made it, summaries included, and give it one way of being absent.

ID: EDI-4
Severity: S2
Claim: The Word export numbers the volume's footnotes by Word's own running count through the file, so "the document prints as the volume prints it" and the Note's "their numbers remain in the text" are true of the web page and the PDF only; §2.3 does not list this difference and §3.8's plan does not carry it.
What a person meets: A reader of a Word export under Full text as printed. Document 475's "Feb 3 [13]" is followed by 8 or 14, wherever Word's count has reached, and not by 44. The unnumbered file note above the heading has a number too. A note that says "see footnote 2, Document 14" points at a number Word has changed. The same collection's PDF prints 44. With notes left out, Word prints 44.
Evidence:
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1584-1585 (`<w:footnoteReference w:id=…/>`, no custom mark), :1728 (`<w:footnoteRef/>`), :1761-1762 (the printed label only when notes are gated off). The file holds no `customMarkFollows`, `footnotePr` or `numRestart`.
- /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:706-712: "The label span is the PRINTED number". /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:1040-1043.
- Record §1: "The document prints as the volume prints it"; §3.8: "None decides a part's presence, place or wording". The §2.3 table has no row for it.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:36 and OptionB.dc.html:75 print "[13]" with 44.
- TEI: document 475's notes are an unnumbered source note, 44 and 45. In frus1946v06, 575 of the 691 documents with notes do not start at 1. 425 references in the six volumes from 1952–54 print a footnote's number.
- From memory, not fetched: Word numbers a footnote reference that carries no custom mark.
- NEEDS A RUN: export frus1946v06 d474 and d475 to Word under Full text as printed and read the number after "[13]".
Refutation: A custom mark or a numbering setting in the Word package, or a line of §2.3 or §3.8 that names footnote numbers. Checked; none.
Direction: Put each note's printed label in the plan and have Word print it, or say in the Note that Word renumbers.

ID: EDI-5
Severity: S2
Claim: "No numbering" is not what 1.0 prints: all three exporters number the documents in the contents list today. So an upgraded collection recorded as "no numbering" either stops printing as it did or goes on printing the collection's numbers with Numbering off, and the boards draw the second.
What a person meets: The owner's upgraded collection. Its PDF contents list reads "1.  …", "2.  …" today. After lane 2 the numbers are gone, which the upgrade's report does not list, or they stay under a row that reads Numbering: Off and that the Note does not explain. The web page of the same collection already counts its section headings and blocks as rows, so its numbers differ from the PDF's. In Header & Dateline style a 1977–1980 row reads "4.  1. Letter From President Carter…" today.
Evidence:
- /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:630-638: `"\(docNumber).  \(doc.tocLabel(style: options.tocStyle))"`.
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1896-1906: "numbered citations", `"\(n). \(cite)"`.
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:560 (`<nav>…<ol>`), :859, :971 (only `li.toc-sub` loses its marker), :578, :583 (headings and blocks are `<li>` too).
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:682-683: the header is "1. Memorandum From…".
- Record §4.3: "the upgrade records The citation leads and no numbering … It prints as it did". §7.4: "no numbering … what 1.0 prints". §5.5 counts Numbering as new. §2.3 cites `:638` and `:1905`, the two lines beside the numbers, and has no row for them.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:20-27 and Citations.dc.html:21-27 draw "3." and "4." on the rows of "What 1.0 prints, and what an upgraded collection keeps".
Refutation: An exporter whose contents rows carry no number. Checked all three.
Direction: Record what 1.0 prints (numbered rows, no number at the lead), and say what Off does to the rows in each format.

ID: EDI-6
Severity: S2
Claim: The mark §3.1 rests on is not fixed, not always true and not always there: "Printed heading" is one of the eleven fields of §5.2's wording table, it is untrue of the electronic-only volumes, and in a contents row the volume's words are a second line with no words at all.
What a person meets: On any platform the owner clears or rewords the Printed heading field in Wording, or renames Headnote to "Editorial Note" over a headnote he wrote, which prints with no attribution. The reader then has no word that separates the compiler's line from the volume's. For a document of volume E–1 the page says "Printed heading:" of a volume that was never printed. In the contents list a listener hears a title and then a heading, with nothing between them.
Evidence:
- Record §3.6: "What cannot be removed is on the page itself: the words Printed heading: under a title".
- Record §5.2: "each with a field: Contents, Headnote, Summary, Research Note, See also, Printed heading, and the five apparatus titles … carry no mark. None is a word of the volume's". OptionA.dc.html:256: "11 labels".
- §9's checks assume the two words: lane 2 ("with its two words inside its text") and lane 4.
- Record §3.4: a contents row is "the title, with a second line under it in small type". Marks.dc.html:74 and Citations.dc.html:28 show no words on that line.
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1134-1135 (a user-written headnote has no attribution); /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:449-462.
- TEI: 240 of the 3,965 documents of the eight volumes are headed "Editorial Note".
- /home/user/FRUS-Explorer/FRUSExplorer/Resources/manifest.json: 22 of 553 volume ids are E volumes. The preface of frus1969-76ve01 (fetched today to /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-EDI/frus1969-76ve01.xml): "This electronic–only volume".
Refutation: A rule in §5.2 that fixes those words, refuses an empty field or refuses a word the volumes print. Checked; none.
Direction: Take the mark out of the wording table, or bound what its field accepts, and put a word on the second line of a contents row.

ID: EDI-7
Severity: S2
Claim: §3.7's answer to G11 would print a sentence that is untrue of two of the author's lines, would change a sentence four other exports print, and leaves an Apple Intelligence headnote with no source.
What a person meets: A reader of an export with the colophon on. The footer says the author's lines "stand apart from them and are named", over pages where "4." stands in the volume's heading line and a date line has no name. A full-text collection with generated headnotes still says only "Read from the text and editorial apparatus of the FRUS volumes, and from no other source." The owner's next chart export or Archives Visit packet carries the collection's reworded sentence.
Evidence:
- Record §3.7: "the two sentences are reworded to say … that the author's lines stand apart from them and are named".
- /home/user/FRUS-Explorer/FRUSCoreKit/Provenance/ProvenanceSource.swift:138-153: the two are `methodSentence` values.
- The same sentences are printed by /home/user/FRUS-Explorer/FRUSCoreKit/Analytics/Export/AnalyticsProvenance.swift:327 and :352, /home/user/FRUS-Explorer/FRUSCoreKit/TripPacket/TripPacketExporter.swift:843 and /home/user/FRUS-Explorer/FRUSCoreKit/Export/QueryMethodAppendix.swift:590.
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1317-1319: a document adds `.frusText`, and `.appModel` only for a summary body. A headnote, notes and highlights add nothing.
- Record §3.2 lists Headnote among "The author's lines"; the number rides "where this heading leads".
Refutation: Sentences of the collection's own in §3.7, or a source for a headnote. Checked; §3.7 names the two shared sentences by their lines.
Direction: Give the collection's footer sentences of its own, written from the plan's roles, and leave the shared two alone.

ID: EDI-8
Severity: S3
Claim: Four things the record says of the volumes hold for one era only, and its Note, its reason for keeping Source: out of the table and its parts table rest on them.
What a person meets: The owner, reading the Note's drafts against a collection that mixes eras.
- "the document's own dateline is in its text" is said of a line the editors compose from 1955.
- Source: is called the volume's word for a 1946 telegram that prints a bare file number.
- An Apple Intelligence summary prints for an E volume document whose editors published their own.
Evidence:
- Record §5.2: "From 1961 the volumes print that word themselves". TEI: 323 of 323 source notes of frus1955-57v24 open "Source:", against 2 of 2,150 in the three earlier volumes.
- Record §3.1: "A dateline is the document's text". TEI: the counts under EDI-2.
- Record §3.1: "Its editors supply a heading for every document and say so once, in the statement of method". "A heading has been supplied by the editors" is in the prefaces of the four volumes from 1961–63 and in none of frus1946v06, frus1950v06, frus1952-54v08 and frus1955-57v24. Their prefaces quote the regulation instead: "no deletions without indicating where in the text the deletion is made".
- Record §3.6: "each volume's own number is in the citation". The two earliest volumes print no number (0 of 1,551 heads).
- frus1969-76ve01: "The editors have supplied a heading, a summary, and a source note". 439 of 444 heads carry a note of type "summary", which the app reads as an ordinary footnote (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSASTNode.swift:501-507). §3.5 would leave it out under two of its three values.
Refutation: The same statements in the earlier volumes' front matter. Checked each `front` by search for heading, bracket, italic, source note and numbered.
Direction: State each convention with the years it holds for, and write the Note from the volumes actually in the collection.

ID: EDI-9
Severity: S3
Claim: §3.5's three values do not mean one thing in every era: for the volumes before 1955 All drops the only copy of the source note that carries a label, None leaves the app's own glyph as the document's first mark, and for a withheld document None removes the one sentence its body holds.
What a person meets: A reader of 1946 to 1954 documents under Full text as printed. In 1.0 "Source: 861.00/2–2246: Telegram" followed the text. Now the file number is an unlabelled note at the end, behind an archive glyph (web), a bullet (PDF) or a Word number, where the volume prints it above the heading. Under None each document opens with that mark and nothing it calls. A document the volume lists as not declassified prints its heading and date and no more.
Evidence:
- Record §3.5: "maps onto them with nothing lost … what prints today less the second copy". §3.1: "whole or not at all". OptionB.dc.html:77: "nothing in it is moved, replaced or left out".
- TEI: an inline source note is the first child in 2,145 of the 2,271 documents of frus1946v06, frus1950v06 and frus1952-54v08. Seven documents of frus1961-63v11, frus1969-76v17 and frus1977-80v06 have a head, an opener and one inline note "[Source: … not declassified]" and nothing else (d286 of the last is one).
- /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSDocumentParser.swift:1716-1727; /home/user/FRUS-Explorer/FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:404-437; /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:243-247; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:379-382 (the labelled copy).
Refutation: A line of §3.5 that says what each value prints for an inline source note. Checked; none.
Direction: Say per era what each value prints of the source note, and keep a labelled statement of it where the volume printed it at the head.

ID: EDI-10
Severity: S3
Claim: The one reading of §3.4 keeps a heading's footnote calls apart from its words and says nothing of a dateline's, so reading opener datelines, which ends defect 1, newly puts an app-made "[n]" or a footnote's whole sentence into a contents row.
What a person meets: A reader of a Header & Dateline contents list. The row for frus1950v06 d702 ends "[New York,] April 7, 1950.[1]", the app's bracket beside the editors' own. Where the row is read from the index it ends "April 7, 1950. Date of conversation; the memorandum was prepared April 11 in Washington."
Evidence:
- Record §3.4: "the heading, with its calls kept apart from its words; the dateline, at the top level, in the opener, or in the closer … That ends defects 1 and 4."
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1518-1522 (`"[\($0)]"`); :1472-1478 (only top-level datelines are read today).
- /home/user/FRUS-Explorer/FRUSCoreKit/Search/IndexingPipeline.swift:7343-7352: "Footnotes stay in, as they always have".
- TEI: 10 of the 3,726 datelines read at the top level, in an opener or in a closer hold a call with a printed number. All 10 are in openers, so none reaches a row today.
Refutation: A clause of §3.4 that treats a dateline's calls as a heading's. Checked; none.
Direction: Have the one function return a dateline's calls apart, as it does a heading's.

§11 rows in my scope
- G6: ANSWERED. §3.4 names every place a title prints. Residue: in a contents row the volume's words carry no words (EDI-6).
- G7 (the editorial half): PARTLY. The heading keeps its calls and the notes are one choice. The source note before 1955 and a dateline's calls are not as §3.4 and §3.5 assume (EDI-9, EDI-10).
- G8: PARTLY. The printed dateline stays and the date line is one document's. "Marked in words" was dropped (EDI-2).
- G9: ANSWERED for the title. No bracket is added as a mark. Residue: the collection's own reading can still write "[n]" into a dateline (EDI-10).
- G10: PARTLY. The rule covers notes left out. It does not reach a look chosen at export or an all-summary collection, and it is both a switch and a row (EDI-3).
- G11: PARTLY. An intent, and a sentence that would itself be untrue; the shared wording and the headnote are not seen (EDI-7).
- G15: ANSWERED. Withdrawn to candidate 10; Citations.dc.html:70-72 shows it only as open.
- EDI-9: PARTLY. The unmarked replacement is gone, for a reason wrong by an era (EDI-8). No label the TEI supplies can now be changed, and no question in §10 puts that to the owner.
- EDI-10: NOT ANSWERED, as the record says. One place is worse than "open": all three formats join See also's citations with "; " after taking off one period (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:390-392), so Turabian's three sentences run "… 1969. Document 474; Foreign Relations…".

Attacked and held
- §3.1 and §3.2's seven counts over the volumes (361 of 390, 263 of 280, 323 of 374, 690 of 692, 663 of 692, 23, 24 of 852) all reproduce by an ElementTree parse.
- The Editorial Methodology quotation is word for word in frus1977-80v06 (`front`, div "about"), with its elisions marked. The boards' first line of document 475, its dateline and note 44 match the TEI.
- §6's three citations are what the formatters write (/home/user/FRUS-Explorer/FRUSCoreKit/Citation/CitationFormatter.swift:458-483, :538-555, :579-596) over the manifest's title, editors and 1969. A style changes no order (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:313-327).
- §3.5's reading of the six recipes as two each of three values holds (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:226-250). With footnotes on the source note prints among them whatever its type (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:700-719).
- §3.7's reading of the sources block holds (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:1313-1336). A title reaches no citation record (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:986-994, :1120-1132).

Not read
- The PDF and Word exporters beyond the lines cited; the editor, inspector and preview views.
- Both manuals, the Agentic Analysis Guide and the designs under `Completed/`.
- The first review's reports other than EDI's and the summary's §2 to §6.
- history.state.gov's page on citing the series and the Chicago and Turabian manuals. None was fetched.
- The corpus beyond the eight volumes on disk and frus1969-76ve01. All counts are by ElementTree over the TEI, not by the app's parser.
- OptionA, Main and PartsPhone beyond their visible text.
- Nothing was built or run.

Outside my scope
- DATA: an entry or section that sets one of 1.0's two switches and inherits the other (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1049-1050) has no image in one three-value key. §3.5's "nothing lost" is shown for a resolved pair only.
- A11Y: with notes left out, each call in the web page is still a `<button popovertarget>` whose target was not written (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:339-344, :876-882).
- INT: the template a new collection starts under keeps `toc: .citation` (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:229; OptionA.dc.html:245), so §2.2's eight near-identical rows are still its default contents list. Marks.dc.html:43-49 draws Header & Dateline rows for "the two of full text".