ID: ENG-1
Verdict: CONFIRMED
Severity: S2
Why: A recipe carries no prompt (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:201-220), and an export at summary depth with none throws "Choose a summarization prompt in the collection’s Composition section to export summaries." (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1421-1423, :40-42); the manual says of this template "choose its **Summary prompt** yourself" (/home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:1123), and §4.4 and §5.1 give a look none. The two recipes with headnotes on (CollectionExporter.swift:230-233, :246-250) do export, printing "No stored summary for this document — generate one in the document view to fill this headnote." wherever none is stored (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:463-466; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:2072-2073; /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:923-928), so "cannot be exported" is exact for one look of the three. A summary made at export is inserted, saved and indexed (/home/user/FRUS-Explorer/FRUSExplorer/Summarization/SummarizationService.swift:172-179), against §4.4's "no stored record is touched"; but any 1.0 export at summary depth does that, §5.1 keeps the "summary-generation waits", and lane 1's "Stored data: None" is the table's column for stored types, so that clause of the finding does not hold. S2 fits: on the owner's first ask, three of six offered looks end in an error or a placeholder line, with no page shown first.
Duplicates: DATA-5 and INT-5 (its last bullet only, a look's blocks on 1.0's values)

ID: ENG-2
Verdict: CONFIRMED
Severity: S2
Why: Each half of 1.0's pair is its own optional field on an entry and a heading (/home/user/FRUS-Explorer/FRUSExplorer/Models/Collection.swift:526, :535), has its own picker (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryInspector.swift:701-710) and walks the cascade alone (CollectionContentAssembly.swift:1049-1050), so "Footnotes: Off, Source note: Default" has no image in one three-valued key, and §7.4's "a Default is a key not held" cannot express it. All three exporters print "Source:" whatever the depth (CollectionItemHTMLRenderer.swift:378-382; DocxCollectionExporter.swift:761-764; PDFCollectionExporter.swift:751-762), and §3.5 does not say what All prints where the text is left out, so "maps onto them with nothing lost" is shown only for a fully set pair at full depth. Lane 3's "No screen changes" cannot hold for two controls writing one key. The six UI suites it names as evidence drive only the name, subtitle and note fields, the colophon switch, the saved-search link and Open Document (my search of /home/user/FRUS-Explorer/FRUSExplorerUITests/CollectionEditorTitleTests.swift for control identifiers), so "no composition control" is exact but for the colophon. S2 stands: two claims of the record are false for stored states of a one-way upgrade.
Duplicates: DATA-7 (the half-set pair, rated S3 there); the first "Outside my scope" line of EDI and the second of FMT

ID: ENG-3
Verdict: CONFIRMED
Severity: S2
Why: PDF: PDFCollectionExporter.swift:630-638 writes "\(docNumber).  \(doc.tocLabel(style: options.tocStyle))" and counts documents alone; section labels and block titles are unnumbered rows (:645-664). Word: DocxCollectionExporter.swift:1898-1906 writes "\(n). \(cite)" into the contents field's cached rows, documents alone, and writes the field dirty (:1873); what Word shows after it rebuilds the field from the heading styles, none of which holds an "n.", only an opened file would settle. Web page: CollectionItemHTMLRenderer.swift:560-583 writes no number but makes documents, section labels and block titles items of one <ol>, the stylesheet removes the marker from li.toc-sub alone (:859-860, :971), and the HTML Standard's default sheet has "ol { list-style-type: decimal; }" (fetched today, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-B/whatwg-html-source.txt, line 155313); so a browser numbers every row, sections and blocks included, and only whether the digits are drawn in the list's 1.25rem of padding is left to an opened file. So "no numbering … what 1.0 prints" (§7.4) and "It prints as it did" (§4.3) are false of contents rows, §2.3 has no row for the three ways, and §8 calls numbering "in the contents list" new. The boards draw "3." and "4." under "what an upgraded collection keeps" (Marks.dc.html:21, :26-27; Citations.dc.html:21, :25-27, both in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/).
Duplicates: EDI-5 (the same finding); A11Y-1 (the web page's half)

ID: ENG-4
Verdict: CONFIRMED
Severity: S3
Why: §4.3 gives the cure one sentence, for "A document". Every append takes one past the highest position (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryData.swift:249-260) under a rule that reads "An appended document or excerpt renumbers nothing" (:224-227), at the six sites the finding lists, and a heading or note block is appended the same way (:315-325). A Chronology goes first when a template is applied (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlockType.swift:87-91; /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEditorView.swift:1922-1925; Docs/iOS-User-Manual.md:1087), where §4.4 prints "the template's blocks at the end". S3 fits: the record says where a document lands and leaves out how; nothing shows it cannot be built.
Duplicates: none for the append rule; INT-6, DATA-10 and EDI-3 for its last sentence (the Note as both a row and a switch)

ID: ENG-5
Verdict: CONFIRMED
Severity: S3
Why: /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CollectionResolutionTests.swift:706 pins a digest of a dump holding "header=… dateline=…" and the Zotero title (:378, :391-393), and /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CollectionRenderingTests.swift:316-324 pins everything.bib and everything.ris beside the HTML and Word; §9 names :450-452 and "the HTML page and the Word package" only. CollectionExportContrastTests fails on a text rule that is not listed and counts "measured == 30" (/home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/ReaderPageTests.swift:690-734), and 26 ranged blocks of /home/user/FRUS-Explorer/Docs/EditableContent/08-Reading-Research-Collections.md cite CollectionExporter.swift (my count), while §9's "Strings and screens" names lanes 1, 4, 5 and 6. The preview's refresh list hashes none of titleOverride, defaultIncludeHeadnote, includeProjectProvenance and includeMethodAppendix (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionPreviewView.swift:211-266); what a person then sees needs a run. Lane 2 carries "a title never alone", whose words are Q2's, with no question in its row. Each is a line for a lane's row, which is S3.
Duplicates: FMT-8 (the second pin)

ID: ENG-6
Verdict: CONFIRMED
Severity: S3
Why: The index's dateline is "the first `<dateline>`, at the top level or inside an `<opener>`" with "Footnotes stay in" (/home/user/FRUS-Explorer/FRUSCoreKit/Search/IndexingPipeline.swift:7340-7358), while §3.4's reading adds the closer and keeps calls apart. By my count 35 of the 3,965 documents have a dateline only in a closer, 10 of 3,726 datelines hold a numbered note, 241 documents are editorial notes, and 725 heads of the three volumes before 1955 hold a numbered note (the finding says 721). A Zotero item's title is the header or else the id (/home/user/FRUS-Explorer/FRUSCoreKit/Citation/ZoteroJSONExporter.swift:159-160), fed by the same top-level reading (CollectionContentAssembly.swift:986-994, :1124-1132), and an editorial note's children are wrapped (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSDocumentParser.swift:1183-1184). So the one reading either changes those records or leaves a second reading alive; the finding states the first as fact, and §3.4's "stay so" allows either.
Duplicates: FMT-8; EDI-10 (a dateline's calls)

ID: ENG-7
Verdict: CONFIRMED
Severity: S3
Why: The two sentences §3.7 cites are the method sentences of two shared sources (/home/user/FRUS-Explorer/FRUSCoreKit/Provenance/ProvenanceSource.swift:138-153), printed for every export that names them (/home/user/FRUS-Explorer/FRUSCoreKit/Provenance/ProvenanceStatement.swift:51-59): analytics (/home/user/FRUS-Explorer/FRUSCoreKit/Analytics/Export/AnalyticsProvenance.swift:327, :352), the Archives Visit packet (/home/user/FRUS-Explorer/FRUSCoreKit/TripPacket/TripPacketExporter.swift:843) and the method appendix (/home/user/FRUS-Explorer/FRUSCoreKit/Export/QueryMethodAppendix.swift:590). /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/QueryMethodAppendixFixtureTests.swift:180, :210 and :241 hold the first sentence as literal text; the two lines of ProvenanceStatementTests the finding cites compare by reference and would not catch a rewording. So "reworded" moves other exports, against lane 4's "Only where used". S3 fits: the remedy is one sentence of §3.7.
Duplicates: EDI-7

ID: ENG-8
Verdict: CONFIRMED
Severity: S3
Why: §5.3 puts the three repairs "On every platform", §9's only row for them is lane 6, "The Mac's preview points", after lane 5, and §12 owes only "The Mac's preview keeping its place"; on iPad the preview is permanent beside the outline and a document's settings are a sheet over it (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEditorView.swift:837-873). The cap is 20 because the document cache holds 24 (CollectionPreviewView.swift:144-153), and "renders it if it is past the first 20" says nothing of that cost. The anchor is doc-volume-document, shared with the export (CollectionItemHTMLRenderer.swift:784-787). But the renderer already has preview-only branches (:321, :367), so a preview-only mark could name an entry without changing the export, and "cannot be had" is too strong.
Duplicates: none

ID: ENG-9
Verdict: CONFIRMED
Severity: S3
Why: For a smart collection both editors list "only the entries it keeps — its generated apparatus" (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionOutline+App.swift:199-224), and the Mac's rule reads "a smart collection has nothing to inspect" (/home/user/FRUS-Explorer/FRUSExplorer/Collections/MacCollectionManagerView.swift:1797-1804). So §4.5's "Selecting one says so" and §5.3's "selects that document's row" have no row. The first review's G3 said "a tap has no row to select", and §11 answers its storage half only.
Duplicates: INT-7; the third "Outside my scope" line of A11Y

ID: ENG-10
Verdict: CONFIRMED
Severity: S3
Why: The shared serializer writes `<h2 class="fn-section-heading">Footnotes</h2>` as a literal over each document's notes (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:701), where the PDF writes a spacer and each note's label (PDFCollectionExporter.swift:1034-1043) and Word its own footnotes. §5.2's eleven words and §2.2's list of literals leave it out, and §2.3 has no row for the difference. "Exported" (DocxCollectionExporter.swift:606-607) and "Undated" (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlocks.swift:374-375) are outside the table too.
Duplicates: A11Y-4 in part (that heading's level)

ID: EDI-1
Verdict: CONFIRMED, RE-RATED
Severity: S2
Why: The counts hold on my own scripts: the heading opens "N. " with the document's own number in 1,694 of 1,694 documents of the five volumes from 1955–57, "No. N" in 720 of 720 of frus1952-54v08, and no number in the 1,551 of the two earliest; 1,698 same-volume references print a document number by the reviewer's definition (1,540 print the word "Document", 158 are a bare number in a list), 1,645 inside a note, in 1,004 of 2,414 documents. Three kinds of block print the volume's number bare in a one-volume collection, "Document \(token.text)" and "Documents \(joined)" (CollectionGeneratedBlocks.swift:465-468, :566-569, :598-601, :716-738), each numbered template places one (CollectionExporter.swift:226-237), and §8 item 2 names two of the three while Q8 leaves it out. Held to the brief's S1: the line that misdirects is a block's row, "Document 4" under an archive or "Documents 2, 4, 5" after a name, read beside leads numbered 1 to 6 and under the Note's drafted "numbered in the order of the collection"; the reader turns to the lead "4.", which is the volume's document 6. No line is false: every "Document N" on the page (the citation at each head, the rows, the volume's notes) is the volume's own number, and the collection's is the bare number at the lead, whose form the record leaves open ("must not be taken for the volume's", §3.3; Q4). That is two unlabelled numberings, which is ambiguity; the brief's S1 names false or unmarked, and 1.0's PDF already prints the collection's row number beside the volume's (PDFCollectionExporter.swift:638). So S2: a reader misled on the default path, and a remedy left out of the core.
Duplicates: none as a whole; the first "Outside my scope" line of ENG is its first half

ID: EDI-2
Verdict: CONFIRMED, RE-RATED
Severity: S2
Why: The evidence holds: §3.6's "What cannot be removed" lists the words Printed heading: and the attribution only, the Note's draft covers "a date line under a title", both boards draw the two fields apart (OptionB.dc.html:98-105; PartsPhone.dc.html:41-50), and Marks.dc.html:73 prints the author's date after the dash where :71 prints the volume's, which §3.4's row does not provide for; my recount gives the same 24 of 852, 46 of 47, 5 of 5 and 323 of 323. Held to S1: the line is "Moscow, 22 February 1946" under the title (§3.3; Marks.dc.html:80), which a reader may take for the dateline the volume prints. It is the compiler's own words and not false, the volume's dateline prints whole three lines down under the words Printed heading:, nothing is replaced, and by default the Note says whose it is (§3.6: "a title or a date line added"). It is unmarked only when the author removes the Note, which Q2 puts to the owner, or types a date line with no title, for which the record has no rule, or exports under a look (EDI-3). So S2: the first review's direction for G8, "marked in words", is half met.
Duplicates: the first "Outside my scope" line of INT; the second of A11Y

ID: EDI-3
Verdict: CONFIRMED
Severity: S2
Why: §3.6 prints the Note "By default, whenever it has something to say about a document whose text prints"; §4.4 lists what a look prints as three kinds of block, none of them the Note; and the board names a Note for "As this collection is set" alone (Main.dc.html:78) and for none of the six looks (:80-90). Two of those recipes leave footnotes out (CollectionExporter.swift:231, :235) while the calls stay (FRUSRenderNodeHTMLSerializer.swift:339-344, :876-882). "Does not print" is the reviewer's inference from that silence, and a fair one: the record never says the Note prints under a look. §3.6's rule also gives none to an all-summary collection, whose template numbers its leads (§4.3) and whose summaries the Note's own bullets speak of. The Note is a row at §3.6 and OptionA.dc.html:57 and a switch at §5.2, §7.2 and OptionA.dc.html:249, against §5.7's "The first form's five switches are gone".
Duplicates: INT-6, DATA-10, ENG-4 (the row-and-switch bullet only)

ID: EDI-4
Verdict: CONFIRMED
Severity: S2
Why: By my script, frus1946v06 d475 holds an unnumbered inline source note and notes numbered 44 and 45, and 580 of that volume's 592 documents with a numbered note open on a number other than 1 (the reviewer's 575 of 691 tests the lowest number). The web page prints the volume's label ("The label span is the PRINTED number", FRUSRenderNodeHTMLSerializer.swift:705-711), and so does the PDF (PDFCollectionExporter.swift:1039-1043). Word, with footnotes on, writes a native footnote: `<w:footnoteReference w:id=…/>` in the text (DocxCollectionExporter.swift:1584-1585) and `<w:footnoteRef/>` in the note (:1728); the note's label is dropped where the entry is made (:1082, :1099) and written nowhere, and the package is six parts with no settings and no customMarkFollows (:292-306). Microsoft's Open XML SDK names that attribute "Suppress Footnote/Endnote Reference Mark" (fetched today, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-B/open-xml-sdk-main-wordprocessingml.g.cs:11663-11664), so the mark is Word's to generate and the file cannot supply 44; which number Word shows after "[13]" needs an opened file. With footnotes off Word prints the volume's label (:1761-1763), so the Note's "their numbers remain in the text" does hold in Word, and the finding is right for All only.
Duplicates: the second "Outside my scope" line of ENG

ID: EDI-5
Verdict: DUPLICATE of ENG-3 (CONFIRMED; the pair is judged there)
Severity: S2
Why: The three exporters print what ENG-3's entry says. Its one addition holds: the collection's header already carries the volume's number (CollectionExporter.swift:682-683, "1. Memorandum From…"; frus1977-80v06 d1's head reads "1. Letter From President Carter to Soviet General Secretary Brezhnev" with its source note inside), so a Header & Dateline row of the PDF reads "4.  1. Letter From…[1]" today.
Duplicates: ENG-3; A11Y-1

ID: EDI-6
Verdict: CONFIRMED
Severity: S2
Why: §3.6 says the words Printed heading: "cannot be removed", and §5.2 lists Printed heading among the eleven fields of the wording table (OptionA.dc.html:256, "11 labels") with no rule for an emptied or reworded field. A contents row's second line carries no words (§3.4; Marks.dc.html:74; Citations.dc.html:28). By my counts 22 of the manifest's 553 ids are electronic-only volumes and 240 of 3,965 heads read Editorial Note, a word the table would accept for Headnote; a headnote the author wrote prints no attribution (CollectionExporter.swift:1134-1135).
Duplicates: the second "Outside my scope" line of A11Y

ID: EDI-7
Verdict: DUPLICATE of ENG-7 in its second claim; the pair CONFIRMED, RE-RATED
Severity: S3
Why: The shared-sentence half is ENG-7's and holds. A document adds the volumes' source, and the app's model only for a summary body (CollectionExporter.swift:1317-1319), so an Apple Intelligence headnote adds no source today; that is a gap of 1.0 which §3.7 does not name, and the headnote keeps its own attribution line (:1127-1131). The "untrue of two lines" half follows from EDI-1 and EDI-2 and from wording that §3.7 gives as intent. The remedy is a sentence of the collection's own, which is S3.
Duplicates: ENG-7

ID: EDI-8
Verdict: CONFIRMED
Severity: S3
Why: "A heading has been supplied by the editors" is in the four volumes from 1961–63 and in none of the four earlier (my search of each file). 323 of the 332 source notes of frus1955-57v24 open "Source:" against 2 of 2,175 in the three earlier volumes (my count), so §5.2's "From 1961" is late by a volume. No heading of the two earliest volumes prints a number, and the parser's comment says the number is present "including early-volume documents that were unnumbered in print" (FRUSDocumentParser.swift:1173-1176), against the Note's "each volume's own number". A note of type "summary" has no case of its own and is an ordinary footnote (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSASTNode.swift:501-507).
Duplicates: none

ID: EDI-9
Verdict: CONFIRMED
Severity: S3
Why: By my count an inline source note is the first child in 2,145 of the 2,271 documents of the three volumes before 1955; it is a footnote in the model (FRUSDocumentParser.swift:1716-1727), marked by the app's archive glyph (FRUSRenderNodeHTMLSerializer.swift:243-247), and the copy that carries a label is the second one, "Source:" from the index (CollectionItemHTMLRenderer.swift:378-382), which All drops. Seven documents hold only a head, an opener and one inline "[Source: … not declassified]" note (d362; d64, d107, d153, d265, d267; d286). §3.5 does not say what each value prints for either case. S3 fits: with footnotes off 1.0 prints these the same way.
Duplicates: none

ID: EDI-10
Verdict: CONFIRMED
Severity: S3
Why: The collection's reading writes a labelled call as "[n]" (CollectionContentAssembly.swift:1518-1522) and today reads top-level datelines only (:1472-1478). By my count 10 of 3,726 datelines hold a numbered note, all in openers, frus1950v06 d702 among them, and the index runs the note's text into the dateline (IndexingPipeline.swift:7346-7351). §3.4 keeps a heading's calls apart and says nothing of a dateline's.
Duplicates: ENG-6; FMT-8

The reviewers' "§11 rows" verdicts in your files
- ENG, G12 (PARTLY): I read it as ANSWERED with its check owed. §3.8 marks plain linked rows "(recommended)", so "none chosen" is not what the record says, and the run that would size the Word half is listed in §12, which makes it a stated weakness. What becomes of the cached rows' numbers is ENG-3's matter.
- No other row in either file is disputed.

Errors in the design record found on the way
- §4.3 and §7.4, "no numbering … what 1.0 prints" and "It prints as it did"; §8, numbering "in the contents list" as new: 1.0 numbers contents rows (PDFCollectionExporter.swift:638; DocxCollectionExporter.swift:1906; the <ol> at CollectionItemHTMLRenderer.swift:560).
- §4.3, "It prints as it did, apart from §2.8's defects": a titled document at full depth gains a citation line and the words Printed heading: (§3.3, third opening), where 1.0 prints the title in the citation's place (CollectionExporter.swift:747-750).
- §4.1, "A section's headnote and See also are followed by its documents, which 1.0's cascade does not do": See also is followed (CollectionContentAssembly.swift:1103; Collection.swift:557-563); only the headnote is not (CollectionContentAssembly.swift:1085-1086).
- §5.2, "From 1961 the volumes print that word themselves": the source notes of frus1955-57v24 open "Source:" (323 by my count).
- §2.8, defect 2, "in the volumes from 1955": before 1955 the source note is a footnote too (the record's own §3.5) and the index stores it (IndexingPipeline.swift:7568-7576), so it prints twice there as well.
- §3.6, the words Printed heading: "cannot be removed", against §5.2's wording table, which gives them a field.
- §3.6, the Note moved "as any block", against §5.2 and §7.2 ("the five back-matter switches") and §5.7 ("The first form's five switches are gone").
- §3.6, the Note prints for "a document whose text prints", against its own bullets for a citation, a summary and Apple Intelligence summaries, and §4.3's numbering for the summaries template.
- §3.5, "maps onto them with nothing lost": not for a half-set pair, nor where the text is left out (ENG-2).
- §3.3, "Everything of the author's stands above the first of them": the collection's number and the words Printed heading: stand at the heading, which follows the source note's marker in 690 of 692 documents of frus1946v06 (the record's own §3.2).
- §3.4's contents row (the title, then the printed heading and dateline), against Marks.dc.html:73, which prints the author's date line in the row.
- §4.4, "prints the template's blocks at the end": a Chronology's place is the front (CollectionGeneratedBlockType.swift:87-91; Docs/iOS-User-Manual.md:1087).
- §4.4, "no stored record is touched", against §5.1's own "summary-generation waits" (SummarizationService.swift:172-174 inserts and saves).
- §9, lanes 1 and 2 "work on 1.0's values", against §5.1's first row, which "names the template the collection follows", and §4.4's "the blocks the collection's own template placed": "A template is never stored" (CollectionExporter.swift:50-51).
- §9, lane 4, "Only where used", against §3.7's "the two sentences are reworded" (ENG-7).
- §5.3, "On every platform", against §9's lane 6 and §12's Mac-only check.
- Boards: Marks.dc.html:43-49 draws Header & Dateline rows for "the two of full text", where three recipes print full text and Full text as printed lists by citation (CollectionExporter.swift:227-229, :246-250); Main.dc.html:80 drops "numbered 1 to 6" for a template §4.3 numbers.

Not checked
- Nothing was built, run or opened: the number Word displays at a footnote reference, what Word's contents field reads once rebuilt, whether WebKit draws the list's digits, and whether the preview refreshes on the Headnotes switch alone.
- The corpus beyond the eight volumes; frus1969-76ve01 only by a search of the EDI reviewer's fetched copy for three phrases; EDI-8's quotation of the earlier prefaces' regulation; the 439 of 444 summary notes (a line count only).
- The web edition; both manuals beyond searches of chapter 12; the UI test runbook; the three earlier designs under Completed/; the first review's reports other than its summary and ENG-9; the editor views beyond the lines cited. INT, DATA, FMT and A11Y were read once for duplicates and not judged.
- My counts are by Python's ElementTree, not the app's parser. The scripts: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/common.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/headnum.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/docrefs.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/docrefs2.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/d475.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/datelines.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/datelines2.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/sourcenotes.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-B/heads.py.