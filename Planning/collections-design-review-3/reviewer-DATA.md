ID: DATA-1
Severity: S1
Claim: Built as L47's brief says ("It writes the fields 1.0 has"), *Same settings as…* copies to other documents the fields that name the source document's own words and records (its title, which research notes, which highlights, which headnote), and the assembly resolves the notes and the headnote by id alone, so each target prints the source's title, research notes and headnote as its own.
What a person meets: Mac. The owner sets up document 475 of the eight telegrams: the title "The Long Telegram", a date line, an edited headnote, two of its four research notes chosen. Then *Same settings as…* for 470, 473, 474, 476, 477, 480 and 486. The PDF and the web page open every telegram with "The Long Telegram" and *As published:* over its own heading, then 475's headnote, and print 475's two notes under it; none prints its own highlights. The Note on the Text then tells the reader that the compiler wrote those titles and headnotes for those documents.
Evidence:
- Plan §1c, L47: "*Same settings as…*: one document's settings copied to others. It writes the fields 1.0 has, and stores nothing new." Design §8.1 item 9: "Copy one document's settings to others." Nothing else in either says which fields.
- The design's own table of a document's settings (§4.1) has "Title | | | yes, as now", "Date line (new) | | | yes", "Highlights; Research notes | yes | yes | yes, and which" and "Headnote | yes | no | yes, with its card".
- The app's own list of what a document row's settings are, `hasDocumentSettings` (FRUSExplorer/Collections/CollectionEntryRows.swift:366-374): titleOverride, the overrides, includeHeadnote, headnoteSummaryId, selectedNoteIds, researchNoteId, selectedHighlightIds.
- The assembly holds "All research notes" (FRUSCoreKit/Collections/CollectionContentAssembly.swift:253, :266) and takes a selected note by id with no test of its document (:1004-1015: `selectedNoteIds.compactMap { nid in notes.first { $0.id == nid }?.bodyText }`; the legacy `researchNoteId` the same way). A chosen headnote is taken by id with no test of its document (:1364-1367, `source.summary(id: sid)`). Highlights are filtered to the target's own document first (:1057-1060), so the source's ids leave the target none.
- The one "copy the settings" code the tree has, Duplicate, copies every one of these (FRUSExplorer/Models/Collection.swift:843-857) and gives the copy its own draft of the source's headnote (:864-866): right for a copy of the same document, wrong for another.
Refutation: A sentence in the design or L47 that limits the copy to fields holding no id or words of the source (depth, prompt, the five switches, See also, headnote on or off). I read §4.1, §8.1 and L47: there is none. Read, not run.
Where it is answered: L47's brief.
Direction: Name in L47 what *Same settings as…* copies (depth, prompt, the switches, headnote on or off) and what it never copies (title, date line, the note and highlight selections, the headnote's pick), and test it on a source document with curated notes and an edited headnote.

ID: DATA-2
Severity: S2
Claim: The `terms` table that Abbreviations & Terms joins to for each term's words and definition keeps one row per list item, so in the 200 items of the catalogue volumes that list two spellings under one definition, 809 linked document–term pairs in 27 volumes have no row and 335 more print under the other spelling with a definition that opens with it; the repair changes what indexing stores, so it is version 76's (L26, built and not merged) or waits for the build after 1.1.
What a person meets: A collection from `frus1917-72PubDipv06`. The block lists "AID — or USAID, Agency for International Development" against the documents that print USAID, and omits the documents that print AID; in the web page those AID links have no row to go to (decision 174). The same for `frus1981-88v11`'s MX (47 documents) and `frus1917-72PubDipv08`'s HAD (one of its 155 pairs).
Evidence:
- The parser's terms delegate overwrites an item's id with each `<term xml:id>` (FRUSCoreKit/TEI/FRUSDocumentParser.swift:2724, :2730-2734), takes the word from the first `</term>` (:2748-2752), and appends one `GlossEntry` per item (:2785). The same on `claude/plan-of-record-pr2011-2cc493` (:2776, :2829).
- Version 76 keys `terms` on `(volume_id, ref)` and stores every gloss target in `term_mentions` without the list's filter (the branch's FRUSCoreKit/Search/IndexingPipeline.swift:9146-9170, :8085), and its own comment counts "498,757 rows … 809 of them naming a term the volume's list lacks" (:1742-1748). The reader looks a term up by that ref (FRUSCoreKit/Models/PersonMentionStore.swift:1103-1118, :1081-1097).
- My counts over `volumes/` at `216cdb764`, stdlib Python with `python3 -I` (SCRATCH/work-DATA/): with every `<term xml:id>` of a list counted, 496,554 gloss pairs and none outside the list (`listless_terms.py`); with the list stored as the parser stores it, 809 pairs in 27 volumes have no row (`parser_terms.py`, the branch's figure exactly). So all 809 are terms the volume lists and the parser drops. Restricted to `manifest.json`'s volumes (`multi_term_items.py`): 200 items list more than one term; 809 pairs name a dropped term; 335 name an item's last term, whose row carries the first term's word; 30 volumes in all. Largest: `frus1917-72PubDipv08` 155 pairs in 69 documents, `PubDipv06` 133, `PubDipv07` 119, `frus1977-80v02` 58, `frus1981-88v11` 47. TEI, `frus1917-72PubDipv08.xml:5282-5283`: `<term xml:id="t_HAD_1">HAD</term> or <term xml:id="t_HD_1">HD</term>, Henry A. Dunlap`.
- Design §8.2 A2: "each in the words of the volume's own *List of abbreviations, symbols, and code names*". Plan §1c, L26: "Anything more the block needs from the index joins this version, or waits for the build after 1.1"; §0: "One index bump a build".
Refutation: A read in L52 that recovers an item's other terms at export (it would need the parse decision 172 declined), or one `terms` row per term on the branch. I read the branch's delegate and schema: neither. Not run in the app.
Where it is answered: L26's brief, now (the owner's word, as for the parts); then L52's.
Direction: Store a `terms` row for each `<term>` of an item, each with the item's definition, in version 76 before L26 lands; failing that, say in L52 that these 30 volumes' shared entries print wrong until the next index version.

ID: DATA-3
Severity: S2
Claim: A section's headnote default cannot ride `CollectionEntry.includeHeadnote`: the explicit `false` that old headings hold cannot be told from a value set on purpose, and no pass can clear it safely, so it must be a new property, the sixth field of the promotion.
What a person meets: The owner's collections with sections from July 2026. In 1.1 they turn Headnotes on for one. Every document added since July under an old heading (its own value nil) now prints no headnote, where 1.0 printed one, because the heading's `false`, written by builds 28 to 32 and never shown on any screen, becomes the section's Off. If 1.1 instead clears those values at launch, a 1.0 device on the same account keeps a section's deliberate Off set in 1.1 (1.0 knows the field and sends it back with every renumber, DATA-4), and that device's own update later clears it.
Evidence:
- History: `var includeHeadnote: Bool = false` from `ebae6ba1` (2026-07-02) until `80972f81` (2026-07-11) widened it to `Bool?`: "Existing entries preserve their stored value (explicit on/off)" (the commit's message; Collection.swift:570-577). Builds 28 to 32 were all cut between the two (project.yml history: `7c9aff43` build 28, 2026-07-05, to `43a9ac53` build 32, 2026-07-10); build 28 went to testers (Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md).
- No screen has ever shown or set it on a heading. A heading's sheet holds its identity and Section Defaults only (FRUSExplorer/Collections/CollectionEntryInspector.swift:304-306; the headnote section is among the document's, :348-366); "Headnote has no heading-level section default" (:625-627; CollectionContentAssembly.swift:1084-1086); the heading row's own check leaves it out (CollectionEntryRows.swift:358-364).
- It is carried onward, so the population is wider than the plan's "a heading made before the Composer redesign" (§1c, *The promotion*): Duplicate copies it (Collection.swift:856); the research export writes "every stored field as stored" (Collection.swift:1086-1088, :1119) and Import from JSON writes it back on an entry of any kind (FRUSExplorer/Export/ResearchDataImporter.swift:712; FRUSCoreKit/Export/ResearchImportPlan.swift:1159).
- A clearing pass is a launch-time write of synced records on each device as it updates, the case §7.6 rules out for the upgrade and DuplicateRecordCleanup.swift:241-245 describes ("a device that updates later can keep a different copy and delete the one the first device kept").
- Reuse has one thing for it: 1.0 keeps and re-sends a field it knows, so DATA-4's question does not arise for it. A new property shares DATA-4's run, which the date line owes anyway.
- From memory, not fetched: a lightweight migration exports nothing, so a heading untouched since before 2026-07-02 may read `false` on a device that migrated through those builds and nil on one that synced it later.
Refutation: A marker on CollectionEntry that tells a 1.1 value from an older one; there is none (Collection.swift:394-699). The size of it NEEDS A RUN: count heading entries with `includeHeadnote = 0` in the owner's stores, on each device.
Where it is answered: the design leaves it to this review (§4.1, §7.1); L43 lands it.
Direction: Make it a new optional property of CollectionEntry read on headings only, count six fields in the promotion, and give it its `Fields` case at version 8.

ID: DATA-4
Severity: S2
Claim: §7.2 prices a 1.0 device's write of a changed record at "a style, an opening, a set of labels and a date line", but 1.0 sends every entry record of a collection back on its commonest edits, so whatever that write does to a field 1.0 lacks it does to every date line in the collection at once; and the run owed before L43, like R12's, has 1.0 rename the collection and never write an entry.
What a person meets: 1.1 is out and the owner's iPad has not updated. On the Mac they give the 52 documents of a collection titles and date lines. On the iPad, in 1.0, they drag one document, delete one, add a heading or tap Sort by Date: all 52 entry records go back to iCloud from a build with no date-line field. If that write drops the field, every date line is gone on the Mac, while the titles, which 1.0 knows, stay. The §12 run, made as written, passes either way.
Evidence:
- 1.0 renumbers the whole outline on "a reorder, a delete, Sort by Date or an added heading, note or apparatus block" (FRUSExplorer/Collections/CollectionEditorView.swift:2262-2264; CollectionEntryData.swift:296-302 writes every entry's `sortOrder`; the Mac the same, MacCollectionManagerView.swift:1619-1626, :1817-1819), and "a position written, even unchanged, stamps the entry modified" (CollectionEditorView.swift:1899-1900; MacCollectionManagerView.swift:1833).
- The date line is a property of CollectionEntry (§7.1), as a section's headnote default would be (DATA-3). A rename writes the Collection record alone.
- Design §12, first run: "On A, a build with one of the new properties sets it on a collection B already holds. Let B import; rename the collection on B and read the property on A. Update B; read the property on B before A touches the collection again; then rename on B and read on A". The plan's §2 repeats it; R12: "set each new fact on a collection the other device holds. Rename that collection on 1.0, and read the facts on the release candidate".
- Certain, from 1.0's code, on a mixed account: 1.0's Duplicate copies a fixed list (Collection.swift:809-862) and its snapshot another (FRUSExplorer/Collections/SmartCollectionSnapshot+App.swift:33-55), so a copy made on the 1.0 device has none of the new facts. The original keeps them.
Refutation: CloudKit's mirror keeping a field an older build does not know on a record that build saves: from memory, not fetched, which is why it is a run. NEEDS A RUN: on A set date lines on three entries; on B (1.0) drag one document; read all three on A; update B, drag again on B, read on A.
Where it is answered: the design's §7.2 and §12; the plan's §2 and R12.
Direction: Have the run write entries by a reorder on the 1.0 device and read every date line, and say in §7.2 that what is at risk is every entry-level value of a collection.

ID: DATA-5
Severity: S2
Claim: L46 says nothing new is stored in CloudKit and that the passages travel in the collection file as text, but names no field that holds a file's passages once a recipient imports it; the one existing field that could, `CollectionEntry.text`, is nil on every document entry by the model's own rule, and any other home is a stored property outside the promotion's count.
What a person meets: A teacher shares a course reader made at Selected passages. A student imports it on an iPad; the student holds none of the teacher's highlights. The student's export prints the passages only if the import stored them somewhere the brief does not name; otherwise it prints the student's own highlights, or nothing, at that depth, and the file carried the passages for nothing.
Evidence:
- Plan §1c, L46: "Nothing new is stored in CloudKit. Text depth is a stored string at each scope, and this is a new value of it." and "The passages travel in the collection file as text, as a quoted passage does, since highlights do not travel". Design §8.1 item 1 says the same.
- An entry's `text` is "nil for document entries" (Collection.swift:663-666). The file writes `text: nil` on a document entry (FRUSCoreKit/Collections/NativeCollectionFormat.swift:515) and reads `text: dto.text` for every kind (:733), which the app writes to the entry (NativeCollectionFormat+App.swift:138). 1.0 reads a document entry's `text` nowhere for display or export (a search of FRUSExplorer/Collections and FRUSCoreKit/Collections: CollectionEditorView.swift:2777-2781, CollectionExportSheet.swift:520-522 and CollectionContentAssembly.swift:952, :1206 read it for headings and excerpts only).
- An author's own entry draws its passages from live highlights (`selectedHighlightIds`, Collection.swift:546-555); an imported one would hold them frozen. Neither the design nor L46 says which prints when an entry has both.
- The plan's count, §0: "So five fields, or six. More, if L48 or L49 keeps a choice on the collection." L46 is not among them.
Refutation: A sentence in the design or L46 giving the stored home. I read §7, §8.1 and L46 and found none. The file's key is FMT's question.
Where it is answered: L46's brief.
Direction: Say in L46 where an imported passage is kept (the document entry's `text`, which keeps the count, or a new property, which joins the promotion) and which source prints at this depth when an entry has both.

ID: DATA-6
Severity: S3
Claim: No row's brief copies a smart collection's own block rows into its snapshot, though the design's §4.5 and #1996 ask for it: L29's sentence is met by the code as it stands, L43's covers stored properties, which a block row is not, and L43's read literally would copy `savedSearchId`, which a snapshot must not.
What a person meets: A smart collection with a Chronology and a Bibliography. After L29 and L43 have landed, Create Static Snapshot gives the documents and the settings and prints neither block.
Evidence:
- L29: "#1996. Duplicate copies *Stamp active project* and *Append the query log* … and the snapshot copies what its comment says it copies." The kit's comment says the headnote default and front matter "are left at their defaults, and the source's own entries are not copied" (FRUSCoreKit/Collections/SmartCollectionSnapshot.swift:92-98), and the code does exactly that (:99-120; SmartCollectionSnapshot+App.swift:33-55).
- A smart collection's apparatus is its own `.generated` entries (Collection.swift:987-988).
- Design §4.5: "The snapshot carries every setting and the smart collection's own blocks (#1996)"; §2.8 row 5. The plan's §1c says L29 ends #1996.
- L43: "Duplicate and Create Static Snapshot copy every stored property, held by a test that walks the schema." The snapshot's point is that it "carries **no** `savedSearchId`" (SmartCollectionSnapshot.swift:92-93).
Refutation: A brief that says the block rows are copied. I read L29, L43 and L44: none.
Where it is answered: L29's brief, and L43's for the walk.
Direction: Have L29 copy the source's `.generated` rows in their places, and give L43's schema walk the list of what a snapshot must not copy, `savedSearchId` first.

ID: DATA-7
Severity: S3
Claim: A1's line for Abbreviations & Terms and the block's rows count one layer two ways: the bundled count A1 reads takes a document whose terms are linked in any part or named on its `@ana`, while the block lists a term only where a part the document's settings print links it; so for `frus1981-88v16`'s 88 documents the line counts every one and the block lists none under any template, and under four templates the line cannot say why the block is short.
What a person meets: A collection from `frus1981-88v16` under *Full text as printed*: A1's line says the volume's editors gave the block its terms, and the block under it is empty. A collection of 1955-on volumes under *Citations with your notes*: the line says the volumes give terms; the block lists few, since "about four pairs in five then name a term the page does not show" (a2-what-the-index-owes.md:67-70).
Evidence:
- The bundled count: "a `gloss` pointer, or one of the document div's own `@ana`, that names one of the volume's `terms` rows" (VolumeAnnotationsIndexGeneratorCore/VolumeAnnotationsAssembly.swift:29-31, :66-67); the scanner records every gloss in the document's division, notes included (TEIAnnotationScanner.swift:210-217). L50: "What it reads: `VolumeAnnotationsIndex`".
- The block's rule: "A term is listed for a document where any part it is linked in prints", with `@ana` a flag of its own, 16 (Planning/collections-design-review-3/a2-what-the-index-owes.md:77-78, :94-97). No setting prints a document's `@ana`.
- `frus1981-88v16`: 419 pairs, all on `@ana` (the branch's IndexingPipeline.swift:1742-1748, :8325-8330; my `listless_terms.py`: 419 `@ana` pairs naming a listed term, all in that volume).
- §8.2 A1 already says the file cannot say which documents. This is a cause it cannot see at all: the collection's own settings.
Refutation: L52 counting `@ana` as printed at Full depth, or L50 reading the block's own count for A2. Neither brief says either.
Where it is answered: L50's and L52's briefs.
Direction: Let A2's block, not A1's line, say when the documents link terms only in parts this collection leaves out, and decide in L52 what an `@ana`-only term counts as.

ID: DATA-8
Severity: S3
Claim: §3.4's "A date line is given only under a title, so it always stands above the label" holds for the inspector and not for what is stored: 1.0 shows a document's title field and not its date line, so it can clear the one and leave the other, and neither the design nor L43 says what a stored date line under no title prints, or what clearing a title in 1.1 does to it.
What a person meets: On the iPad still on 1.0 the owner empties document 475's title; its date line stays stored. On the Mac, 1.1 hides the date line's field because there is no title; the export prints it alone or not, by whatever the plan's code does; a title typed later brings the old date line back under it unseen.
Evidence: §3.4; §5.2 ("the title; the date line under it, once there is a title"); L43 ("A document's date line, given only under a title (decision 163)"). 1.0's title field: "clearing the field restores it (empty → nil)" (CollectionEntryInspector.swift:385-388); 1.0's entry has no date line (Collection.swift:394-699). A file from another tool can carry one key without the other (§7.4 reads such files as today).
Refutation: A rule in §3.4 or L43 for a stored date line under no title. Not found.
Where it is answered: L43's brief.
Direction: Say in L43 that a date line prints only where a title prints, what clearing a title does to it, and where a stored one with no title is shown.

ID: DATA-9
Severity: S3
Claim: §8.1's item 2 still gives a saved template "a deploy of its own", and the plan's §1c quotes §4.1 as calling candidate 6's fields "a field and a deploy of its own", words §4.1 lost when it was brought to the answers; both contradict the one promotion that §7.1 and the plan's §0 rule set at R11.
What a person meets: The session that builds L47 reads its row as owing a Production deploy of its own, in a plan that has one, at R11.
Evidence: Design :779 ("a record type of its own, with a deploy of its own"); §7.1: "One CloudKit promotion, of these four and of what the candidates add"; plan §0: "One CloudKit promotion, before the release candidate" and "deploys the schema to Production, once"; plan §1c, *The promotion*: "The design says it is 'a field and a deploy of its own' (its §4.1)". `git show 9325f79d:` the design, :414, had the words; §4.1 now (:425-427) has not.
Refutation: Read; nothing to run.
Where it is answered: the design's §8.1 and the plan's §1c.
Direction: Strike "with a deploy of its own" and quote §4.1 as it now reads.

The starting points in my scope
- A2, beyond the index: A ROW'S BRIEF MUST SAY IT. L26 now, for one `terms` row per term (DATA-2); L52 for an `@ana`-only term and for what A1's line says over the block (DATA-7); decision 174's links need a row for each of the 809 or plain text there.
- A section's headnote default: SETTLED HERE as a new optional property of CollectionEntry (DATA-3); L43 must say so, which makes the promotion six fields.
- Candidate 1, selected passages (L46): a new value of the depth string, and 1.0 reads it as full (held, below); A ROW'S BRIEF MUST SAY IT (L46): where an imported passage is stored and which source wins (DATA-5).
- Candidate 2, Save as Template (L47): a record type in `frusModelTypes`; 1.0 never sees it; not in the file; in version 8. A ROW'S BRIEF MUST SAY IT (L47): it stays out of DuplicateRecordCleanup's list, and its list, count and export read one copy of each id (DuplicateCopies, DuplicateRecordCleanup.swift:266-296); what it holds is already the owner's; fix §8.1's "deploy of its own" (DATA-9).
- Candidate 6 (L43): see the section default above; See also for the collection, below.
- Candidate 7, the page (L48), and candidate 11, the short form (L49): A ROW'S BRIEF MUST SAY IT. A choice kept on the collection lands with its control, joins version 8 and the file, and L43's schema walk catches it for Duplicate and the snapshot; kept on the device, it is in neither the file nor the export, so one collection prints two page sizes on two devices.
- Candidate 9, Same settings as… (L47): A ROW'S BRIEF MUST SAY IT (DATA-1).
- Candidates 10, 12 and 13: store nothing. SETTLED BY THE TEXT.
- The four properties: SETTLED BY THE TEXT as optional properties whose absence prints 1.0's layout. A ROW'S BRIEF MUST SAY IT (L43): decision 159's opening is written where a person makes a collection (CollectionEditorView.swift:331, MacCollectionManagerView.swift:612), never as the property's default, which the file import, the snapshot, Import from JSON and Duplicate also pass through (`Collection.init`, NativeCollectionFormat+App.swift:107, SmartCollectionSnapshot+App.swift:34, ResearchDataImporter.swift:641, Collection.swift:803).
- See also at the collection, and its absence: A ROW'S BRIEF MUST SAY IT (L43). Absent must read Off, as 1.0's cascade ends (`?? false`, CollectionContentAssembly.swift:1103); stored as a Bool defaulting to false, as `defaultIncludeHeadnote` is (Collection.swift:231), absent and Off are one state, and §4.2's *Not set above* goes.
- What 1.0 does with each new property on a record it then changes: NEEDS A RUN, §12's first, widened to entries and a reorder (DATA-4).
- Duplicate and the snapshot: A ROW'S BRIEF MUST SAY IT (L29 and L43; DATA-6).
- The single promotion and the R-7 gate: SETTLED BY THE TEXT, once it counts six fields (DATA-3), a seventh if L46 adds one (DATA-5), and one record type; `CloudKitSchemaInventoryTests` catches each, and the archive requires every identifier awaiting deploy of Production (Scripts/check_cloudkit_schema.py:151-153, :242-279).
- What the blocks read: SETTLED BY THE TEXT. A8 reads the stored class (`decimal_class`, Subject-Numeric keys included since index version 69, IndexingPipeline.swift:1562-1566, :8921); A3 `external_citations` (:8974, :10186); A10 the device's `page_ranges` (PageRangeStore.swift:242-260), so a document whose volume the device lacks gets no pages; A11 `document_dates` (CollectionGeneratedBlocks.swift:45-50) and the kit's administrations; A4 the device's cross-references with the bundled map for other volumes' pages only (CitedPageMap.swift's header); A1 the bundled annotations index (DATA-7). None stores anything.

Attacked and held
- A8 needs no index version: `document_sources.decimal_class` holds decimal and Subject-Numeric keys (IndexingPipeline.swift:1562-1566, :8890-8900, :8921) and the block's read leaves it out (:6490-6492), as L54 says.
- 1.0 reads selected passages as the full text, at entry, section and collection alike: `CollectionBodyDepth.resolve` ends `?? .full` (CollectionExporter.swift:307-311).
- The Note on the Text and A2 to A4 survive 1.0: an unknown block type is kept and skipped (CollectionContentAssembly.swift:964-965), copied by 1.0's Duplicate (Collection.swift:858) and re-exported intact by its file writer (NativeCollectionFormat.swift:59-65).
- A field cannot reach an archive unpromoted: the archive requires every identifier in `identifiersAwaitingDeploy` (check_cloudkit_schema.py:151-153, :242-279). The gap is `identifiersAwaitingWriter`, which the archive exempts (:151-153), and the plan's rule that each field lands with its control closes it.
- The cleanup does not touch a new record type: DuplicateRecordCleanup.run lists each type it collapses (DuplicateRecordCleanup.swift:91-101), so a saved template is outside it, as §7.6 asks.

Not read
The eight boards; the web edition's repository; the UI suites; ResearchDataExporter's envelope beyond `CollectionExport`'s initialisers; ModelModificationStamper (I relied on the editor's own comment, CollectionEditorView.swift:1899-1900); StoreSchemaDiagnostic; the owner's stores, which the brief does not list, so the count of headings holding `false` is a run. No Apple page was fetched: how the CloudKit mirror treats a field an older build lacks, a lightweight migration's added column, and two writes to one field are from memory where a finding leans on them. Nothing was built or run.

Outside my scope
- 1.0's reader shares DATA-2's defect today: a tap on a dropped term ("HAD" in `frus1917-72PubDipv08`) does nothing (DocumentView.swift:1138-1143, terms from DocumentViewModel.swift:451-457), and an item's last term opens a card with the first term's word. I found no issue for it.
- The design's citation of `CrossReferenceStore.swift:757-759` for page targets now lands on the find-related read; the page-target rule is at :1107-1119.
- The persons list delegate has the same one-id-per-item pattern (FRUSDocumentParser.swift:2254, :2263); not measured.
