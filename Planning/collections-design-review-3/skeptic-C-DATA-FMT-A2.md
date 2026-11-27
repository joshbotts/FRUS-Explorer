ID: DATA-1
Verdict: DUPLICATE of ENG-1 and INT-1; the three are CONFIRMED.
Severity: S1
Why: L47's brief says only "one document's settings copied to others. It writes the fields 1.0 has, and stores nothing new" (plan §1c), and the design's own table of a document's settings (§4.1) lists "Title … yes, as now", "Date line (new)", "Highlights; Research notes … yes, and which" and "Headnote … yes, with its card". The kit takes a chosen note by id over every note the app holds (CollectionContentAssembly.swift:1004-1007, `notes.first { $0.id == nid }`) and a chosen headnote by id with no test of its document (:1364-1366), while highlights are filtered to the target's own document first (:1057-1060); the one copier in the tree copies all of these and then gives the copy its own draft (Collection.swift:834-866), which is right only for the same document. Re-read, the harm is worse than DATA-1 says, as ENG-1 and INT-1 say: two entries sharing a draft lose it to either one's Edit or Regenerate (CollectionEntryInspector.swift:1158-1166 deletes the draft the entry points at) and to either row's delete (GeneratedSummary.swift:238-243, called at CollectionEditorView.swift:1616, :1770 and MacCollectionManagerView.swift:1569, :1585). The S1 rests on §4.1's table, not on the brief's phrase "the fields 1.0 has", which is about storage; nothing in either text excludes the id fields, and the chain is the feature's ordinary use, so S1 stands.
Where it is answered: L47's brief, as the reviewer says: the fields copied (depth, prompt, the switches, headnote on or off) and the ones never copied (title, date line, the note and highlight selections, the headnote's pick).
Duplicates: ENG-1, INT-1; INT's "Outside my scope" DATA line.

ID: DATA-2
Verdict: CONFIRMED. It is what its evidence shows, and it is already answered: decision 189, on L26's branch at 254283cc.
Severity: S2
Why: On v2 the terms delegate overwrites `currentId` with each `<term xml:id>` and takes the word at the first `</term>` only (FRUSDocumentParser.swift:2730-2733, :2748-2752), appending one GlossEntry per item (:2785). My own walk (work-C/c_multi_term.py: the parser's section rule, innermost items, the 553 manifest volumes at 216cdb764) reproduces every figure: 66,203 stored rows; 200 items with two spellings or more, in 31 volumes; 809 document–term pairs naming a dropped spelling, in 27 volumes; 335 naming an item's last spelling, in 21; 30 volumes in all; PubDipv08 155, PubDipv06 133, PubDipv07 119, frus1977-80v02 58, frus1981-88v11 47 (whose item is `t_MX_1` "MX" / `t_MX_2` "M–X", frus1981-88v11.xml:13754-13755). The branch now gives each spelling its own row ("terms 66,203 rows -> 66,426, 223 added, none removed … The 809 term_mentions rows that named no terms row all name one", 254283cc's message; decision 189 in the branch's plan). It also overturns FMT's "Attacked and held" 3: every gloss target names a TEI term id, but until decision 189 not a stored row. S2 fits: §8.2 A2's "each in the words of the volume's own List" was false for these 200 entries.
Where it is answered: L26 (decision 189), done on its branch; L52 inherits one row per spelling. The design's A2 should cite decisions 188 and 189 (its "Reach" of 113,012 documents is the v75 annotations file; v76's reads 113,026).
Duplicates: EDI-1 (its last part, the 809).

ID: DATA-3
Verdict: CONFIRMED, RE-RATED.
Severity: S3
Why: The history holds: `includeHeadnote` was `Bool = false` from ebae6ba1 (2026-07-02) until 80972f81 (2026-07-11); builds 28 to 32 were bumped between (project.yml at 7c9aff43, a7faf23e, 5aaecd86, dabc386a, 43a9ac53); headings arrived the day before (000e758e, 2026-07-01); and no shipped build drew the headnote toggle for a heading (build 32's inspector: `if isHeading { headingIdentitySection; sectionDefaultsSection }`, 43a9ac53:CollectionEntryInspector.swift; at ebae6ba1 the inspector opened from document rows alone). Today the only writer of the field is a document's toggle (CollectionEntryInspector.swift:940), besides the copy paths (Collection.swift:856; ResearchDataImporter.swift:712; ResearchImportPlan.swift:1159), so a heading's `false` was never chosen. No pass can single out the old values: `lastModified` is stamped by every renumber (Collection.swift:445-447), and `createdAt` (:697) would miss a Duplicate made later, which gets a new date (:719) and the old `false`. So the settlement, a new optional property, stands; the rating does not: in 1.0 (1861) nothing writes `false` on a heading, so the population is headings made under pre-release builds between 2026-07-01 and 07-11 and their copies, and the harm, a section's headnotes off and shown so on its sheet, can be undone there. Its two claims about the mirror (that 1.0 re-sends the field with every renumber, and what a lightweight migration left on a heading untouched since July) are from memory and nothing here settles them; the settlement does not rest on either.
Where it is answered: L43's brief: a new optional property read on headings only, the sixth field (the plan's §0 already allows "five fields, or six"), with its `Fields` case at version 8.
Duplicates: FMT-1 (its section-default half); INT's and ENG's starting-point lines on the section's headnote default.

ID: DATA-4
Verdict: CONFIRMED, RE-RATED.
Severity: S3
Why: 1.0 renumbers the outline on "a reorder, a delete, Sort by Date or an added heading, note or apparatus block" (CollectionEditorView.swift:2262-2264; CollectionEntryData.swift:296-302 writes every entry's `sortOrder`; the Mac the same, MacCollectionManagerView.swift:1619-1626, :1817-1819), and a `sortOrder` write stamps the entry modified (Collection.swift:445-447; "a position written, even unchanged, stamps the entry modified", CollectionEditorView.swift:1899-1900). §12's run, the plan's §2 ("A runs a branch with one property") and R12 have 1.0 rename the collection, which writes the Collection record alone. So §7.2's "a style, an opening, a set of labels and a date line" understates the reach: one drag on 1.0 sends every date line of the collection through 1.0's save. But the run is not blind: made with any of the three Collection properties it exercises the same handling of a field 1.0 lacks, so "passes either way" holds only for a date-line run; what is at risk is values that can be retyped, on devices still on 1.0, and the mechanism is already stated as unestablished with a run owed before L43 (§7.2). The direction is right and cheap: set date lines on three entries and drag a document on the 1.0 device.
Where it is answered: the design's §7.2 and §12; the plan's §2 and R12, as the reviewer says.
Duplicates: none (DATA-8 rests on the same run).

ID: DATA-5
Verdict: CONFIRMED; FMT-3 is its DUPLICATE.
Severity: S2
Why: L46's brief says "Nothing new is stored in CloudKit" and "The passages travel in the collection file as text" (plan §1c), and its row of files names NativeCollectionFormat.swift but neither Models/Collection.swift nor NativeCollectionFormat+App.swift. A document entry's `text` is "`nil` for document entries" (Collection.swift:663-666); the writer writes `text: nil` for one (NativeCollectionFormat.swift:515); the reader carries `text: dto.text` for every kind (:733) and gives every entry `selectedHighlightIds: []` (:755), which means all of the recipient's own highlights (:55-58); and the assembly reads `text` for headings and excerpts only (CollectionContentAssembly.swift:951-956, :1206). This is the second review's FMT-9 ("A teacher shares an abridged reader"), which §11 marks answered "Said of each" (§8); saying the passages travel gives them no home, so it stands.
Where it is answered: L46's brief: where an imported passage is kept (a document entry's `text`, which adds no field, or a new property, which joins the promotion and version 8), which prints when an entry has both, and that it is checked as an excerpt is (FMT-3).
Duplicates: FMT-3; ENG's "Outside my scope" DATA/FMT line; the second review's FMT-9.

ID: DATA-6
Verdict: CONFIRMED
Severity: S3
Why: L29's brief has "the snapshot copies what its comment says it copies", and the kit's comment says "the headnote default, the front matter and the settings are left at their defaults, and the source's own entries are not copied" (SmartCollectionSnapshot.swift:92-98), which the kit (:99-120) and the app (SmartCollectionSnapshot+App.swift:33-55) already do, so the sentence asks for nothing. A smart collection's blocks are its own `.generated` entries (Collection.swift:987-988), and the design promises "The snapshot carries every setting and the smart collection's own blocks (#1996)" (§4.5), which is how §11 answers the second review's DATA-10 ("Carried; filed"); §1c says L29 ends #1996. L43's walk covers stored properties, which block rows are not, and read literally it would copy `savedSearchId`, which the snapshot exists to drop (SmartCollectionSnapshot.swift:92-93).
Where it is answered: L29's brief (the `.generated` rows in their places), and L43's walk with its exclusions, as the reviewer says.
Duplicates: none (the second review's DATA-10 is its lineage).

ID: DATA-7
Verdict: CONFIRMED
Severity: S3
Why: The bundled count takes a document whose `gloss` pointers or `@ana` name a terms row (VolumeAnnotationsAssembly.swift:29-31, :66-67), and the scanner records every gloss in the division, notes included (TEIAnnotationScanner.swift:210-217). No export prints a document's `@ana`: the serializer writes the named lists for the reader alone ("An export keeps the default `false`", FRUSRenderNodeHTMLSerializer.swift:194-197, :369-372), and v76 names the flag "`@ana`, which prints nothing" (the branch's PersonMentionStore.swift, `TermMentionParts.annotation`). My walk (work-C/c_term_parts.py) finds 419 pairs whose only part is `@ana`, all in frus1981-88v16, so by the a2 note's rule ("A term is listed for a document where any part it is linked in prints") that volume's block is empty under every template, against §8.2 A2's own "It would also read the terms that frus1981-88v16 names on each document's @ana". The reviewer quotes the a2 note's "about four pairs in five" for Citations with your notes; my count there is 99.2% (only the heading prints), so the line and the block disagree more than stated.
Where it is answered: L52's brief (what an `@ana`-only term counts as; the block saying where it left terms out) and L50's (what A1's line may claim for A2), as the reviewer says.
Duplicates: ENG-2 (the per-document parts through the seam); A2.

ID: DATA-8
Verdict: CONFIRMED
Severity: S3
Why: 1.0's title field writes nil when emptied ("clearing the field restores it (empty → nil)", CollectionEntryInspector.swift:385-395), and 1.0's entry has no date line, so a 1.0 device can leave a stored date line under no title, if the mirror keeps a field 1.0 lacks (DATA-4's run). §3.4 ("A date line is given only under a title, so it always stands above the label") and L43 ("given only under a title (decision 163)") state a rule for the control, and none for a stored date line under no title or for what clearing a title in 1.1 does to it. A file can carry `dateLine` without `titleOverride` too, since §7.4 reads an outside tool's file "as today".
Where it is answered: L43's brief.
Duplicates: none.

ID: DATA-9
Verdict: CONFIRMED
Severity: S3
Why: §8.1 item 2 still reads "a record type of its own, with a deploy of its own" (design :779), and the plan's §1c quotes §4.1 as "a field and a deploy of its own" (:429): words §4.1 had at 9325f79d (:414) and has not now (:425-427). Both stand against §7.1's "One CloudKit promotion" and the plan's §0 rule ("deploys the schema to Production, once", R11).
Where it is answered: the design's §8.1 item 2 and the plan's §1c, *The promotion*.
Duplicates: none.

ID: FMT-1
Verdict: CONFIRMED
Severity: S2
Why: The writer says "Default (nil) and Off (false) both omit the key … only an explicit On (true) serializes" (NativeCollectionFormat.swift:517-520), yet writes `headnoteSummaryId` whatever the switch (:521) and the collection's default when on (:489); the reader turns the absent key into nil (:757-758), which inherits the collection's value (CollectionContentAssembly.swift:1086), and a test pins the omission (CollectionTests.swift:3939-3942). Two recipes turn the default on (CollectionExporter.swift:230-232, :246-248), so today an Off document arrives On and prints a fallback or the placeholder; decision 166 as §7.4 words it ("as its text … always") would put an abandoned draft in that place instead. Neither §7.4 nor L43 ("new optional keys, each written only where it is set") gives Off a key, and the heading case writes no headnote key at all (:533-552).
Where it is answered: L43's brief; the owner, for whether "always" covers an entry switched off, as the reviewer says.
Duplicates: DATA-3 (the section default's key).

ID: FMT-2
Verdict: CONFIRMED
Severity: S2
Why: §7.4 says "A 1.0 app that opens the new file shows no headnote". Nothing in §7.4 stops the new writer writing `includeHeadnote: true`, which the 1.1 reader needs, and with the id gone 1.0 falls back to "any stored summary (or the placeholder)" (NativeCollectionFormat.swift:227-231; CollectionContentAssembly.swift:1348-1382), and each exporter prints "No stored summary for this document — generate one in the document view to fill this headnote." where nothing is found (CollectionItemHTMLRenderer.swift:316-318, :463-466; DocxCollectionExporter.swift:2068-2072; PDFCollectionExporter.swift:923-929). The sentence's second half holds (a recipient on another account gets that fallback today) and the author's loss is stated ("that is lost"); the false part is "no headnote", and on the author's own 1.0 devices it is an AI summary of the document under *Headnote*. §4.4's "No placeholder line is printed in an exported file" (:504; §11, H11) is in no row's brief.
Where it is answered: §7.4's text and L43's brief; the placeholder in L34's, where INT-3 also puts it.
Duplicates: INT-3 (the placeholder half).

ID: FMT-3
Verdict: DUPLICATE of DATA-5, CONFIRMED there.
Severity: S2
Why: Its two additions hold. The quotation check runs over `.excerpt` entries alone (CollectionExportSheet.swift:519-522), which the Guide promises "before every export and again when a corrected volume arrives" (Agentic-Analysis-Guide.md:2862), so a passage kept as a document's text would print as the volume's words unchecked. A 1.0 re-export keeps an unknown depth string (NativeCollectionFormat.swift:478, :510) and writes `text: nil` for a document (:515), so it keeps the depth and drops the passages.
Where it is answered: L46's brief.
Duplicates: DATA-5; the second review's FMT-9.

ID: FMT-4
Verdict: CONFIRMED
Severity: S2
Why: A structured prompt's draft stores "a JSON object in `GeneratedSummary.responseText`" (StructuredSummaryDisplay.swift:16), shown as fields only when its format is `.structured` (:67-71); Regenerate keeps the prompt's format (CollectionEntryInspector.swift:1222-1223) and the assembly carries it to the exporters (CollectionContentAssembly.swift:1093-1094), while a summary made without a format is `.general` (GeneratedSummary.swift:92, :197). So "its text, with who wrote it" (§7.4) prints such a headnote as JSON unless its format travels too. The authorship's three values speak to the device's user ("Yours", CollectionEntryInspector.swift:1033-1045; "AI-generated summary, edited by you", CollectionExporter.swift:1127-1137), and §3.6's Note would list a sender's headnotes among "which headnotes the compiler wrote". The Guide's §15.1a limit 1, "Headnotes cannot be supplied" (Agentic-Analysis-Guide.md:2907-2908), stops being true, and §7.4's list of what the lane owes the Guide does not name it.
Where it is answered: L43's brief (keys for the text, its format and its authorship; what an import makes of a sender's authorship); the owner for Q10's "who wrote it", as the reviewer says.
Duplicates: EDI-6 (the attribution's words); EDI's "Outside my scope" DATA/FMT line.

ID: FMT-5
Verdict: CONFIRMED
Severity: S2
Why: A block's row is a text, a second text, a URL and an indent (CollectionExporter.swift:1196-1218); the web page writes a block and its rows with no id (CollectionItemHTMLRenderer.swift:199-221); and the Apparatus menu adds a block on every choice (CollectionEditorView.swift:1349-1356, :1911-1927), as §4.3 says. My own count (work-C/c_term_ids.py, the 553 manifest volumes) gives the reviewer's figures exactly, 66,426 `<term xml:id>` under `<text>` in 313 volumes and 6,592 ids that recur in more than one volume, and my crude no-shared-word test between two volumes that link an id gives 920 against its 933. Re-read: `t_ADA1` is "Atomic Development Authority" with 50 links in frus1946v01 and "Area Division IV (American Republics)…" with one in frus1948v09; `t_NATO1` has 2 links in frus1943 and 49 in frus1949v04. Decision 174 and L52 say only "links to its row".
Where it is answered: L52's brief, as the reviewer says.
Duplicates: EDI-1 (rows and anchors keyed by volume and id); A11Y-10 (the person and cross-reference links beside it); ENG's starting-point line (a row has no id) and its "Outside my scope" (two blocks, duplicate ids).

ID: FMT-6
Verdict: CONFIRMED
Severity: S3
Why: The PDF draws its cloud from `WordCloudExporter.collectionCloudImage(texts:title:)?.cgImage` (PDFCollectionExporter.swift:208-212), which returns an image and a PNG (WordCloudExport.swift:153-157) and never passes through `CollectionWordCloud`, the handoff L55 extends; it draws the image on a page of its own (:250-256), and its tables are cells joined by " | " (:1132-1143). L55's brief puts the table "in the web page and in Word" and its test over "the HTML and the Word package", while its own row of files lists PDFCollectionExporter.swift and §8.2 says "A block that needs columns would change all three exporters". The parity suite exists because "DOCX silently dropped the word cloud" (CollectionTests.swift:5494-5496) and holds all three formats to the cloud (:5576).
Where it is answered: L55's brief.
Duplicates: A11Y-8 (L55 and the PDF).

ID: FMT-7
Verdict: CONFIRMED
Severity: S3
Why: At 1.0-release `exportHeading` and `tocLabel` return a non-empty title in place of the citation and of the heading (CollectionExporter.swift:747-765); the page's heading is that title with the URL under it (CollectionItemHTMLRenderer.swift:296-309), and Index depth prints no body (:373-374). The new file keeps writing `titleOverride` (NativeCollectionFormat.swift:514). So a 1.0 reader of a 1.1 file meets #1998 at every title (§2.8 row 7), which §7.2's "nothing 1861 prints is false" and the plan's §1c "What a reader still on 1.0 (1861) sees" leave out: no title is false, but none is marked.
Where it is answered: the text of §7.2 and §7.4 (state the cost), as the reviewer says.
Duplicates: none.

ID: FMT-8
Verdict: CONFIRMED
Severity: S3
Why: A record's "Document date:" line comes from `docMeta.dateline` (ZoteroJSONExporter.swift:166-167, written into BibTeX's note and RIS's M2, BibtexExporter.swift:132, RISExporter.swift:107-111), which the assembly reads from the render model's top-level nodes alone (CollectionContentAssembly.swift:986, :1467-1481), while an opener's dateline sits inside `.letterOpener` (FRUSRenderNode.swift:65-68). My count (work-C/c_datelines.py) reproduces the reviewer's exactly: of 314,616 documents, 14,882 have a dateline as a direct child, 286,178 only in an opener, 5,260 only in a closer and 8,296 none outside a note. §3.4 says of the records only "Its title takes the new reading", and L34 the same. This is the date half of the second review's FMT-8 ("titles ending in '[1]' and no document date"), which §11 marks answered by Q9, a question about titles; the third form leaves that half standing.
Where it is answered: L34's brief, or the owner, as the reviewer says.
Duplicates: the second review's FMT-8; ENG's "Outside my scope" line on `makeItem`, which the reader's own sends also call.

ID: FMT-9
Verdict: CONFIRMED
Severity: S3
Why: The research export writes summaries, headnote drafts among them, only when `includeGeneratedSummaries` is on (ResearchDataExporter.swift:96-99), while each entry carries its `headnoteSummaryId` (Collection.swift:1119-1120). Both manuals promise collections "their whole composition" and say AI summaries are excluded by default (macOS-User-Manual.md:1309; iOS-User-Manual.md:1523), so a restore from a default file leaves every headnote the author wrote to the fallback or the placeholder. §7.5 gives version 8 the new properties and the saved templates and nothing of headnotes, though Q10's reason ("it was written for the collection, as a note block was") fits this carrier as well; the chain, a default file restored outside iCloud, keeps it at S3.
Where it is answered: L43's brief, which raises version 8.
Duplicates: none.

ID: A2
Verdict: CONFIRMED, with three slips in its text that do not move the verdict; already answered (decision 188, on L26's branch at 78b172cf).
Severity: S2
Why: My own walk (work-C/c_term_parts.py: an iterparse with an ancestor stack, the 553 manifest volumes at 216cdb764; the 191 other files add no pair) reproduces its table exactly: 497,026 pairs, 113,045 documents, 312 volumes; 325,432 text only, 72,771 the source note only, 41,579 other footnotes only, 419 `@ana` only; 124,491 (25.05%) only in notes; 207 of 311 volumes with a fifth or more; and the branch reports the index's rows carry the same flags pair by pair (the branch's IndexingPipeline.swift version note). Its template table matches the recipes (CollectionExporter.swift:226-251) and its seam reading holds (CollectionGeneratedBlocks.swift:155-160: documents, not entries). The slips: "About four pairs in five then name a term the page does not show" is Citations with source notes alone (79.1%), and under Summaries and Citations with your notes, where only the heading prints, it is 99.2%; d1 of frus1969-76v06 also links SNIE in its text (a `<gloss target="#t_SNIE1">` in the paragraph "SNIE 14–69"), so "only in its source note" holds of NIE and Limdis; and "the block is exact either way" under the two full-text templates fails for the 419 `@ana`-only pairs, which no export prints (DATA-7).
Where it is answered: L26 (decision 188), done on its branch. What L52 owes, the per-document parts passed through the blocks' data source and what `@ana` counts as, is in neither branch's L52 brief, which still reads "It reads version 76's table, as the Persons Index reads the people's": L52's brief must say it (ENG-2).
Duplicates: ENG-2 (the seam); DATA-7 (`@ana`).

The reviewers' starting-point lines in my files

DATA:
- "A2, beyond the index … L26 now, for one terms row per term (DATA-2)": done since, as decision 189 (254283cc). The rest of the line stands.
- "Candidate 7 … kept on the device, it is in neither the file nor the export, so one collection prints two page sizes on two devices": L48's brief already weighs this ("A paper size follows the person who prints; a page break before each document follows the work"), so two sizes on two devices is that brief's stated trade, not a gap.
- "What the blocks read: SETTLED BY THE TEXT": not for A4, whose account in the text (§8.1 item 10 and A4: a page reference "is stored under its page", `CrossReferenceStore.swift:757-759`) the index contradicts: it replaces a same-volume page target with one document (`resolvePageBasedCrossReferences`, IndexingPipeline.swift:10631, its UPDATE at :10697; EDI-2). And not for A2, whose `@ana` rule the text leaves contradictory (DATA-7).

FMT:
- "9 (Same settings as…) … SETTLED. None stores anything new, so nothing new travels": not for the file. Under decision 166 a copied headnote pick becomes the source's headnote text, written into every target's entry, and a copied note selection the source's notes when research notes are included, since the file's note texts are also taken by id over every note (CollectionExportSheet.swift:627-630); so what the file carries depends on L47's field list (DATA-1).
- "7, the page: SETTLED BY L48's brief, which names the file's keys": the brief says the choices "join the promotion, the collection file's keys and version 8" and names no key; settled in principle only.

Errors in the design or the plan found on the way
- Design §7.4: "A 1.0 app that opens the new file shows no headnote": it prints a stored summary or the placeholder (FMT-2).
- Design §8.1 item 2, "with a deploy of its own", and the plan's §1c quoting §4.1 as "a field and a deploy of its own": against §7.1's "One CloudKit promotion" (DATA-9).
- Design §4.5, "The snapshot carries every setting and the smart collection's own blocks (#1996)", against L29's brief, "the snapshot copies what its comment says it copies", which the code already does (DATA-6).
- Design §8.2 A2: "It would also read the terms that frus1981-88v16 names on each document's @ana" against the same section's "So the block lists, for each document, the terms linked in a part its settings print", with v76's flag for `@ana` "which prints nothing" (DATA-7).
- Design §8.2 A2: "each in the words of the volume's own List" was false for 200 entries until decision 189; its "Reach … 113,012 documents" is the v75 file's figure and v76's reads 113,026; the design cites neither decision 188 nor 189.
- Design §7.2: "What is at risk is a style, an opening, a set of labels and a date line": every entry-level value of a collection goes through 1.0's save on a drag (DATA-4).
- Design §3.4: "A date line is given only under a title, so it always stands above the label": a rule for the control, not for what is stored (DATA-8).
- Design §11, the row "ENG-6, FMT-8, EDI-10 … the records are Q9, yes (decision 165)": Q9 is about titles; the records' date line stands (FMT-8).
- Design §4.4: "No placeholder line is printed in an exported file", stated as wanted, is in no row (FMT-2, INT-3).
- Plan §1c contradicts itself on the headnote count: "that sentence can say it" (the sheet's sentence, :425) against L44's "a template's needs, and how many headnotes will print, are said here, if CR agrees" (:680); design §4.4 reads only the second (INT-3).
- Plan §1c, *The promotion*: "a heading made before the Composer redesign holds an explicit false" leaves out its copies, Duplicate's and Import from JSON's (DATA-3).
- The a2 note: the three slips under A2 above.

Not checked
- Whether the CloudKit mirror keeps a field an older model lacks when that build saves the record (DATA-3's re-send, DATA-4, DATA-8): from memory nowhere settled here; the two-device run.
- How many headings hold `includeHeadnote = 0` in the owner's stores (DATA-3's size).
- That build 1861 prints the placeholder for a hand-made 1.1 file (FMT-2); how common structured headnotes are in the owner's library (FMT-4).
- The stored page targets EDI-2 names (needs an index); L26's walk (`collectDocumentRefs`) line by line, where I relied on its own pair-by-pair comparison with the a2 script; the boards; the web edition.
- Nothing was built or run.
