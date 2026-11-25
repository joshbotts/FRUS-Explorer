ID: ENG-1
Severity: S2
Claim: Three of the six looks §5.1 offers cannot be exported "for that export" from a collection not already set up for them, and one of the three stores records, so §4.4's "writes nothing" and lane 1's "Stored data: None" are false for it.
What a person meets: On iPhone, from the Collections list, the owner picks Export…, Summaries with overview, Export PDF for a full-text reader. The export stops on "Choose a summarization prompt in the collection's Composition section to export summaries." The prompt's picker shows in Collection settings only while the collection's own Body depth is Summary only, so the way through is to change the collection, which the look exists to avoid. Without Apple Intelligence the same look ends in "The export could not be rendered." Where a prompt is set, the export writes a summary per document with the on-device model, and each is saved to the synced store and indexed for search; all stay after the export. Under Full text with your annotations or Everything included, each document with no stored summary prints "No stored summary for this document — generate one in the document view to fill this headnote." in the PDF, Word file and web page, and the sheet shows no page first. If lane 1 ships before lane 2, as §9 allows, the first look listed prints each source note twice (§2.8, defect 2).
Evidence:
- Record §4.4: "writes nothing … so no stored record is touched"; "takes the template as it is for what a recipe has a say in, and the collection's own for what no template touches: the citation style, the labels, the title page, the colophon". §9: "Stored data: None"; "Lane 1 answers the first ask by itself." Main.dc.html:83-84: "For this export: an AI summary of each document, with your notes and a word-cloud overview."
- A recipe holds no prompt (FRUSCoreKit/Collections/CollectionExporter.swift:201-220, :234-237); a collection's is nil until chosen (FRUSExplorer/Models/Collection.swift:236); the picker shows only under Summary only (FRUSExplorer/Collections/CollectionCompositionRows.swift:130-137).
- No prompt throws (FRUSCoreKit/Collections/CollectionContentAssembly.swift:1420-1423; the words at :40-42). No Apple Intelligence throws (FRUSExplorer/Collections/CollectionContentResolver.swift:776-778). A summary not stored is generated (:806-819), then inserted, saved and pushed into the index (FRUSExplorer/Summarization/SummarizationService.swift:160-179).
- Two recipes turn headnotes on (CollectionExporter.swift:230-233, :246-250); a headnote is never generated (CollectionContentAssembly.swift:1080-1091); its placeholder prints in exports (CollectionItemHTMLRenderer.swift:463-466; DocxCollectionExporter.swift:2072-2073; PDFCollectionExporter.swift:923-928).
- §4.4 prints the look "without the blocks the collection's own template placed"; on 1.0's values nothing records that (§7.4: "1.0 did not record what placed it"), so in lane 1 no block can be left out. It prints "the template's blocks at the end", where a Chronology's place is the front (FRUSCoreKit/Collections/CollectionGeneratedBlockType.swift:87-91; Main.dc.html:82 "A Chronology and a Persons Index follow").
Refutation: A line of §4.3–§4.5, §5.1 or lane 1 that gives a look a prompt, tests for Apple Intelligence, generates without storing, or says what a headnote look prints where no summary is stored. I read them and the board and found none. Not run.
Direction: State each look's preconditions in the sheet and what the Summaries look stores, or keep that look out of the sheet.

ID: ENG-2
Severity: S2
Claim: §3.5's "1.0's pair maps onto them with nothing lost" is false for two stored states, and lane 3 cannot have "today's screens" write the one notes key with "no screen changes".
What a person meets: (a) On any platform, a Full text as printed collection (footnotes on, source note on) with one document or section at Index / outline or Summary only prints, today, the citation and "Source: …" for it. Mapped to All, whose notes are "the footnote bodies", a document with no text has no notes list, and the line is gone; §3.5 does not say what All prints there. (b) A section whose sheet has Footnotes: Off and Source note: Default prints text and "Source:" under such a collection. The upgrade must write one key for it: None loses the line; The source note only fixes what was inherited, so the section stops following the collection. (c) In lane 3's build the default 1.0 collection (footnotes on, source note off) and an Everything included one (both on) hold the same value, All; the Archival source note switch must read the same for both, so for one it is not what the author left, and switching it changes nothing.
Evidence:
- Record §3.5 (quoted); §4.1: "A section or a document holds only the keys it changes"; §7.4: "Footnotes and Source note, as a pair | the volume's notes, as §3.5 maps them" and "a Default is a key not held"; §9, lane 3: "the composition controls and the Default / On / Off pickers write the new values. No screen changes but what the upgrade adds".
- Two independent three-state fields per entry and per heading (Collection.swift:526, :535), two pickers (FRUSExplorer/Collections/CollectionEntryInspector.swift:701-710), two collection switches (CollectionCompositionRows.swift:146-152), each cascaded on its own through nested sections (CollectionContentAssembly.swift:601-612, :1047-1050). See also cascades from a section the same way (:611-612, :1103), which §4.1 says "1.0's cascade does not do".
- The source note is fetched and printed whatever the depth (CollectionContentAssembly.swift:1071-1078; CollectionItemHTMLRenderer.swift:378-382, after the switch that prints notes only at full depth, :325-347; DocxCollectionExporter.swift:762-765; PDFCollectionExporter.swift:751-762).
- §9 names the six UI suites of FRUSExplorerUITests/CollectionEditorTitleTests.swift as "the evidence that the storage moved and the behaviour did not". A search of that file finds no composition control, template or picker.
Refutation: A rule in §3.5, §4.1 or §7.4 for a pair with one half set and one inherited, and for All where the text is left out. None found. Not run.
Direction: Define the key for a document without text, and say how a half-set pair is upgraded and which control writes the key in lane 3.

ID: ENG-3
Severity: S2
Claim: 1.0 already numbers every contents row, in three ways, so §4.3's Numbering key either takes the numbers off an upgraded collection's lists or leaves the web page's list numbers at odds with the number at the lead; §2.3's table omits the difference and the boards contradict §4.3.
What a person meets: After the upgrade, with "no numbering" recorded, the owner's PDF contents list, which read "1.  …, 2.  …", prints no numbers, though §4.3 says "It prints as it did". If instead each format keeps its list's numbers, the record's own example (two sections of three telegrams) prints "4. The Long Telegram" at the lead and in the PDF, while the web page lists that row sixth, since its ordered list counts the two section rows; a Chronology at the front shifts every row by one.
Evidence:
- §4.3: "the documents numbered 1 to n in its order, at each lead and in each contents row"; "the upgrade records The citation leads and no numbering … It prints as it did, apart from §2.8's defects". §3.8: "None decides a part's presence, place or wording."
- PDF numbers documents: "\(docNumber).  \(doc.tocLabel…)" (PDFCollectionExporter.swift:630-638). Word's cached rows too: "\(n). \(cite)" (DocxCollectionExporter.swift:1898-1906). The web page's list is an <ol> whose items are documents, section rows and block rows (CollectionItemHTMLRenderer.swift:560, :567, :578-583); only .toc-sub loses its marker (:859-860, :971; no other list-style rule reaches it in that file or ReaderPage.swift). That an <ol> shows numbers by default is from memory, not fetched.
- Marks.dc.html:21, :26-27 and Citations.dc.html:21, :25-27 draw rows "3." and "4." under "what an upgraded collection keeps", where §4.3 records no numbering. OptionA.dc.html:41-48, :75 draws "4." under two sections.
Refutation: A line of §2.3, §3.8 or §4.3 on the three lists' own numbers. None. No exported page was opened here.
Direction: Add the lists' numbers to §2.3 and say, per format, what Numbering off and on print in a contents row.

ID: ENG-4
Severity: S3
Claim: §4.3's cure for defect 3 is one sentence against six append sites built on the opposite rule, and it covers documents alone.
What a person meets: Every new collection has two blocks at its end (§4.3), so each Add to Collection from the reader or Search must move those blocks' positions as well as write the document, on synced records, where today it writes one. A section heading, a note block or an excerpt still lands after the Bibliography. In the lane-1 look and on the board a Chronology "follows"; applied in the editor it goes first.
Evidence: §4.3: "A document added to a collection goes before the run of apparatus blocks at its end". FRUSExplorer/Collections/CollectionEntryData.swift:224-227: "every append takes nextSortOrder … An appended document or excerpt renumbers nothing"; :249-260 (one past the highest position); :229-232 (two devices). Sites: CollectionAddDocumentsSheet.swift:154, :208; CollectionExcerpts.swift:159, :187; CollectionEntryData.swift:319; CollectionDocumentAppend.swift:101-103 ("no entry is renumbered"), :158. Chronology: CollectionGeneratedBlockType.swift:87-91; CollectionEditorView.swift:1922-1925. Lane 4's row gives the cure "Keys of the settings value; no deploy". The record also has the Note on the Text both ways: "The author may move it as any block" (§3.6; OptionA.dc.html:57) and one of "the five back-matter switches" (§7.2, §5.2; OptionA.dc.html:249), though §5.7 says "The first form's five switches are gone".
Refutation: A statement of where the rule lives and what it does for the other kinds. Not in §4.3 or §9.
Direction: Say whether it is a rule at the append sites or a rule of order where entries are read, for every kind appended.

ID: ENG-5
Severity: S3
Claim: §9's "What each lane owes" leaves out at least seven things lanes 2, 5 and 6 move.
What a person meets: The session taking lane 2 meets a red swift test and unit target on pins §9 does not name. The owner, on iPad or Mac, turns the collection's Headnotes switch on and the preview does not change until something else does.
Evidence:
- Lane 2's row has no question, and §10 lets it "go ahead … before the answers to the rest", yet it carries "a title never alone (§3.4)", the words Printed heading:, which are Q2's subject, and must settle ENG-3 before Q4.
- FRUSExplorerTests/FRUSCoreKit/CollectionResolutionTests.swift:701-706 pins a digest of a dump whose line "header=… dateline=…" (:378) holds the fact :450-452 asserts. §9 names one of the two.
- CollectionExportContrastTests fails on any rule of the export's layer that draws text and is not listed, and counts them (FRUSExplorerTests/FRUSCoreKit/ReaderPageTests.swift:690-734, "measured == 30"). Lane 2's and lane 4's new lines add rules. CLAUDE.md names the gate; §9 does not.
- §9 lists strings for lanes 1, 4, 5, 6. Lane 2 rewrites kit files that 29 ranged blocks of Docs/EditableContent/08-Reading-Research-Collections.md cite (CollectionExporter.swift 26, CollectionContentAssembly.swift 2, CollectionItemHTMLRenderer.swift 1; my count of SOURCE lines with a range), adds a string, and changes the outline's rows on three platforms (§3.4; CollectionEntryRows.swift:972; MacCollectionManagerView.swift:2022-2028).
- Defect 6 is four fields: the refresh list also omits defaultIncludeHeadnote, includeProjectProvenance and includeMethodAppendix, which the page draws (CollectionPreviewView.swift:211-266; CollectionContentAssembly.swift:1086; CollectionExportSheet.swift:937-953). NEEDS A RUN: preview on, switch Headnotes alone, wait five seconds.
- "Shared code (lanes 1, 2, 3, 4 and 7)": lane 5's drawn opening and "N documents differ" need the outline's context in the kit (resolveItem says section values "resolve as unset here", CollectionContentAssembly.swift:395-399); lane 6 needs marks in the shared renderer, whose preview page is pinned (CollectionRenderingTests.swift:321).
Refutation: A line of §9 naming any of these. I re-read §9 against each.
Direction: Add each to its lane's row.

ID: ENG-6
Severity: S3
Claim: §3.4's "one reading" has two sources that give different lines, and it changes the titles of BibTeX, RIS and Zotero items, which lane 2's list of changed exports omits.
What a person meets: The outline's second line and a contents row of an undownloaded volume come from the index, where a dateline that sits only in a closer is absent and a note in a dateline is run into it as text; the export reads the model. After lane 2 a Zotero send titles an editorial note "Document 12: 12. Editorial Note" where 1.0 sends "Document 12: d12", and "…Brezhnev[1]" loses its "[1]".
Evidence: §3.4: "one function that every one of those places calls"; "from the index, where the volume is not on the device"; "In no citation record … and stay so". The index reads the first dateline at the top level or in an opener, notes kept in (FRUSCoreKit/Search/IndexingPipeline.swift:7347-7358). The model's reading scans top-level nodes (CollectionContentAssembly.swift:1468-1482) and writes a call as "[n]" in a dateline as in a heading (:1518-1522). An editorial note's heading is inside its wrapper (FRUSCoreKit/TEI/FRUSDocumentParser.swift:1183-1184), so its header is empty and the item's title falls to the id (FRUSCoreKit/Citation/ZoteroJSONExporter.swift:159-160). Counted over the eight volumes with /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-ENG/count_parts.py: 35 documents with a dateline only in a closer; 10 of 3,726 datelines hold a note; 241 of 3,965 documents are editorial notes; 721 heads in the three volumes before 1955 hold a numbered note.
Refutation: A rule in §3.4 for which source wins and for a dateline's calls. It names the heading's calls only.
Direction: Name the index as the outline's one source, say what it lacks, and list the reference formats among lane 2's changes.

ID: ENG-7
Severity: S3
Claim: Rewording "the two sentences" (§3.7) changes exports lane 4 says it does not touch, since one of them is the sentence every other export prints.
What a person meets: A reader of an Archives Visit packet, an analytics CSV or the semantic map's export finds its sources line speaking of "the author's lines".
Evidence: §3.7: "the two sentences are reworded". Lane 4: "Changes exports: Only where used". The sentence is frusText's methodSentence (FRUSCoreKit/Provenance/ProvenanceSource.swift:138-142), printed by ProvenanceStatement.lines for any export naming that source (FRUSCoreKit/Provenance/ProvenanceStatement.swift:51-59): FRUSCoreKit/Analytics/Export/AnalyticsProvenance.swift:132, :155; FRUSCoreKit/TripPacket/TripPacketExporter.swift:843; FRUSCoreKit/Semantic/SemanticMapExport.swift:165; FRUSCoreKit/Analytics/Export/SeriesAnalyticsExport.swift:102. FRUSExplorerTests/ProvenanceStatementTests.swift:43-45, :403 hold the sentences.
Refutation: A collection-only sentence in §3.7. It has none.
Direction: Add a sentence or a source for collections and leave the shared one alone.

ID: ENG-8
Severity: S3
Claim: §5.3 calls three repairs of the preview due "on every platform" and §9 puts all three in the Mac's lane; one of them cannot be had with "Changes exports: No" as the page is built.
What a person meets: On iPad, after lane 5, each change in a document's sheet reloads the page beside the outline from its top a second later, and no lane or §12 check owns that. On the Mac, clicking row 30 of a 40-document reader lifts the 20-document cap, and from then each settled edit parses again what the 24-slot cache cannot hold.
Evidence: §5.3: "On every platform … Three things it lacks today come first"; "renders it if it is past the first 20"; "each document on the page is named by its entry". Lane 6: "The Mac's preview points … None | No". §12 owes only "The Mac's preview keeping its place". iPad: CollectionEditorView.swift:837-855, :863-873. Reload: CollectionPreviewView.swift:433-437, :882-887. Cap and its reason: :144-153, :544-556. A resolved document carries no entry id (CollectionExporter.swift:650-656); its anchor is doc-volume-document, "shared by the ToC links, the exported sections, and the preview's scroll-to-row targets" (CollectionItemHTMLRenderer.swift:778-788), and scopes its footnote ids (:340-342), so a document entered twice already has duplicate ids in the exported page.
Refutation: A lane for the three on iPad and iPhone, and a way to name by entry that leaves the export's ids. Neither is in §9.
Direction: Move place-keeping into lane 5, and say whether the export's anchors change.

ID: ENG-9
Severity: S3
Claim: §4.5's "Selecting one says so" has nothing to select: neither editor lists a smart collection's documents (the first review's ENG-7, left standing).
What a person meets: On iPhone and iPad, a smart collection's Contents shows one sentence and its apparatus. On the Mac, with Show Parts on, a click on a document in the preview has no "row" to select (§5.3).
Evidence: §4.5: "A document of its list has no settings. Selecting one says so, and offers Create Static Snapshot". FRUSExplorer/Collections/CollectionOutline+App.swift:199-224 keeps, for a smart collection, "only the entries it keeps — its generated apparatus"; both editors call it (CollectionEditorView.swift:1153; MacCollectionManagerView.swift:1293-1315).
Refutation: Rows for a smart collection's results in §4.5 or lane 5. None.
Direction: Say where the message appears, or list the results as rows.

ID: ENG-10
Severity: S3
Claim: The plan and §5.2's wording table miss a word one format prints for every document with notes: "Footnotes".
What a person meets: The owner renames Research Note to Commentary. The web page and the preview still print "Footnotes" as a second-level heading over each document's notes; the PDF prints a rule and Word its own footnotes. So "None decides a part's … wording" (§3.8) fails for the notes, and lane 2's heading check passes over a heading that ranks with the document's.
Evidence: FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:701 (a literal in the reader's serializer); PDFCollectionExporter.swift:1034-1037; DocxCollectionExporter.swift:1584-1585. §5.2's table has eleven words; §2.2's list of literals omits this one. Also outside it: "Project" (CollectionItemHTMLRenderer.swift:529), Word's "Exported" line (DocxCollectionExporter.swift:606-607), "Most frequent terms in this collection" (CollectionItemHTMLRenderer.swift:624), "Undated" (CollectionGeneratedBlocks.swift:374-375).
Refutation: A row for it in §5.2 or a line in §3.8. Neither.
Direction: Carry the notes' heading in the plan, or say the web page keeps its own.

§11 rows in my scope
- G2: PARTLY. Nothing is written to the collection, but one look stores summaries, three need what the collection lacks, and on 1.0's values lane 1 cannot tell a template's blocks from the author's (ENG-1).
- G3: PARTLY. "No settings" settles storage; "Selecting one" still has no row (ENG-9).
- G7: PARTLY. The parts are named against the model and hold on a recount, but the notes key is undefined where the text is left out and does not fit a half-set pair (ENG-2), and the one reading has two sources (ENG-6).
- G12: PARTLY. Two ways are named and none chosen, so lane 2's Word half cannot be sized before §12's run; neither says what becomes of the cached rows' numbers (ENG-3).
- G13: PARTLY. Pointing is the Mac's, but the cap, the reload and naming by entry are answered by a clause each, in a Mac-only lane (ENG-8).
- G14: PARTLY. Where a document goes is said; how, against the append rule and for other kinds, is not (ENG-4).
- G15: ANSWERED. The short form is out of the core (§6, §8).
- ENG-9: ANSWERED. Each of the five has a line (§7.6, §5.2, §9); the preview's hand-built options are named in §2.6 and given to no lane by name.

Attacked and held
- The highlight claim (§3.3, §3.8): a label or number inside the heading stays outside the offset walk in all three exporters (FRUSRenderNodeHTMLSerializer.swift:541-580; PDFCollectionExporter.swift:1286-1291; DocxCollectionExporter.swift:1616-1629), and no model, renderingVersion or index version moves (ASTToRenderNodeConverter.swift:134, :177-184).
- "The document's own heading node" is one node: each of 3,965 documents in the eight volumes has exactly one head that becomes a .heading, and the record's counts hold on recount (690 of 692; datelines 663 in an opener, 23 only in a closer; source note in the head 361/390, 263/280, 323/374).
- §6's kit changes: the three formatters read only the volume and the number (FRUSCoreKit/Citation/CitationFormatter.swift:458-482, :538-555, :579-595); none of the manifest's 553 titles holds "_" or "*"; the Bibliography orders by number (CollectionGeneratedBlocks.swift:313-327).
- At full depth All does print the source note once: the index reads it only from notes, which are always among the model's (IndexingPipeline.swift:7545-7583); the recipes give 2, 2 and 2 as §3.5 says.
- Every file:line the record cites in §3.2–§3.5, §3.8, §5.3, §6 and §9 holds; the code is unchanged since efd73ec. No UI suite walks the export sheet, so lane 1 breaks none.

Not read
The web edition's repository; NativeCollectionFormat.swift, DuplicateRecordCleanup, the CloudKit inventory and Collection.swift beyond the fields cited; CollectionRichTextEditor.swift, CollectionPickerSheet.swift; the Word exporter's styles and lists (lines 330-540, 1280-1540) and the PDF exporter after line 1600; both manuals and UI-Test-Destinations-Runbook.md; the first review's INT, DATA and A11Y reports. Nothing was built or run, Word and Pages were not opened, and no volume beyond the eight was counted.

Outside my scope
- EDI: in the five volumes from 1955 on, every head opens with the volume's own number (1,694 of 1,694, "7. Telegram From…"; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-ENG/count_headnum.py), so "the printed heading leads" with numbering prints "4. 7. Telegram From…" under the three templates §4.3 gives it to.
- EDI: Word numbers every footnote itself through the whole file (DocxCollectionExporter.swift:1584-1585, :1728), so under All the calls in a Word export are not the volume's numbers, while under the other two values they are (:1761-1763).
- INT: on the Mac a row's selection opens no settings and retargets the column only if it is already open (MacCollectionManagerView.swift:1140-1146, :1405-1418), so "the selection is the scope" changes the Mac and is not "as now" (§5.4).