**The duplicate cleanup and the settle wait, as the tree has them (asked for before DATA-1 and DATA-2)**

- **Deletes copies of ten types.** `DuplicateRecordCleanup.run(context:)` (FRUSExplorer/Models/DuplicateRecordCleanup.swift:91-101) groups by `id` and deletes all but one of: UserTag, Project, Collection, CollectionEntry, CustomVolumeScope, ArchiveVisitPlan, ArchiveVisitDocument, ArchiveVisitTarget, DocumentClassificationOverride, AnnotationReview. For Collection and ArchiveVisitPlan it first moves the copies' children to the keeper (:177-181, :206-208).
- **Leaves thirteen of the 23 in `frusModelTypes` alone** (ModelContainer+FRUS.swift:100-147).
  - Five by a stated ruling, #1791, read one copy of each id and never deleted (:68-71, :235-258): ResearchNote, SavedSearch, ReadingHistoryEntry, SearchHistoryEntry, ExportHistoryEntry.
  - Eight it does not name: GeneratedSummary, SummarizationPrompt, DocumentHighlight, DocumentTagAssignment, PersonClusterOverride, SyncedPreferences, ProjectLeadEntry, WorkingCorpus. Two of these have passes of their own: standard prompts are collapsed by name (SummarizationPromptSeeder.swift:186-222), and the settings coordinator keeps the earliest set (SettingsSyncCoordinator.swift:138-147).
- **It is a list of types.** It would not touch `DocumentCollection` or `DocumentCollectionEntry` until a lane added them. A headnote draft's copy is a GeneratedSummary, which nothing collapses.
- **Keeper.** Earliest `createdAt`, then lower `id` (FRUSCoreKit/Models/DuplicateRecordOrder.swift:37-40). For a collection: most entries, then earliest `createdAt` (:171-176). For a tag: a real name over a placeholder first (:139-149). A group shares its id, so copies that also share `createdAt` are "kept in the device's own fetch order, which two devices need not share" (:64-66).
- **When.** At boot (FRUSExplorerApp.swift:2762), and again 8 seconds after each successful import event, the timer restarted by every such event (:3379-3384). That is the "settle" the record cites. It is a quiet interval, not an import's end: the block's own comments say an earlier debounce can act before "the real tag has since arrived in a later import" (:3374-3378), and that a second device "will usually have delivered its rows by now" (:3438-3442).

ID: DATA-1
Verdict: CONFIRMED
Severity: S1
Why: §7.4 gives the two copies one id and one set of dates ("take the ids of the old"; "an upgraded record keeps the 1.0 record's dates"). §7.5's keeper, "the copy changed since its upgrade, else the one made from the later 1.0 state", parts no two copies made from one state; §7.2 keeps "when it was upgraded" on the collection alone and the rule does not read it. For such copies the tree's text is DuplicateRecordCleanup.swift:243-245: "a device that updates later can keep a different copy and delete the one the first device kept, and after sync no copy is left" (also HistoryPaneSnapshot.swift:113-115, SummarizationPromptSeeder.swift:226-230). The tie is the design's own making: every derived-id row the pass collapses today is dated by the device that made it (ArchiveVisitPlan.swift:411-413, :424, :509; AnnotationReview.swift:168-171), and keeping the 1.0 dates removes that. The chain has a measured precedent: the owner's library holds exact copies "from R-2a's migration running on two devices" (:249-251), a pass that waited for the same settle, and #1791 ruled such copies are read, not deleted. What is lost is the work done after the upgrade, since the 1.0 record stays and is upgraded again. The mutual deletion is the tree's statement and was not seen in a run; §12's third check as worded watches one device.
Duplicates: none. DATA-2 shares its root, the twin as the only mark.

ID: DATA-2
Verdict: CONFIRMED
Severity: S2
Why: The only mark is the twin: "a second run finds the work done" by the same ids (§7.4), "No field is added to a type 1.0 knows" (§11, G17), and "The 1.0 records stay as they are". §7.5's fourth row concedes the mechanism: without the 1.0 record's deletion "another device would upgrade it again". The wait is 8 seconds of quiet after an import event (FRUSExplorerApp.swift:3379-3384), which the same block says can end before a later import (:3374-3378) and calls "usually" enough (:3438-3442). A store rebuilt from iCloud is in no row of §7.5: Fix iCloud Sync discards the store's files (ModelContainer+FRUS.swift:249-251, :298-303), and §12's second check offers it as a remedy. How often the quiet falls between the 1.0 records and their twins on an empty store is a run's to say, so S2 stands until that run; the R-2a copies (DuplicateRecordCleanup.swift:249-251) show the guard has failed once.
Duplicates: none.

ID: DATA-3
Verdict: CONFIRMED
Severity: S2
Why: §7.5's test is one date, "the 1.0 record is later than the date kept at the upgrade", and §7.2 keeps that date on the collection alone. Collection.swift:28-29: "Editing an entry updates the entry's own `lastModified`; the collection is not touched in that case." The stamper stamps only models a save reports changed (ModelModificationStamper.swift:146-149), and the collection's date is set by hand at two lines only (CollectionDocumentAppend.swift:160, :218). So a retitle, a rewritten note block, a section default or a reorder on a 1.0 device raises no notice, and once that device updates "A build that has the new types no longer lists them" (§7.4). It also fires unasked: a project merge rewrites `projectIds` on each collection (ProjectAdminService.swift:130-135), and the prompt collapse, which runs by itself after imports, rewrites `summaryPromptId` (SummarizationPromptSeeder.swift:252-256). S2 and not S1 because nothing is deleted; but no build shows the stranded records. Whether adding or removing one entry moves the collection's date needs a run.
Duplicates: none.

ID: DATA-4
Verdict: CONFIRMED
Severity: S2
Why: The record gives one sentence (§7.5: "Its collections pass through the same function") and one enum case (§7.6). The plan compares a record by id within one model type (ResearchImportPlan.swift:602-609), and a type new at a version is one "an earlier file holds none of" (:264-265). So a format-7 collection is either planned against the 1.0 record no build lists, or upgraded and planned against the new record. In the second case the function's output sets "every key" (§7.4), where the plan's rule is that a replacement "keeps the library's for the rest ... so an older file never blanks what it could not say" (:31-33; today at :1057-1064, :1131-1136). The web edition writes this file from the kit at its pin (:742-748 reads its key), so a newer format-7 file over an upgraded library is not a rare case.
Duplicates: none.

ID: DATA-5
Verdict: DUPLICATE of INT-5; the pair is CONFIRMED
Severity: S2
Why: §4.4's fourth bullet needs to know which blocks a template placed. Lane 1 works "on 1.0's values" with "Stored data: None" (§9), and 1.0 stores no placer: "A template is never stored, only the fields it writes" (CollectionExporter.swift:50-51); "Only the TYPE is ever stored" (Collection.swift:654). The upgrade then fixes every existing block as "the author's own, since 1.0 did not record what placed it" (§7.4), which §4.3 says no template removes. By the recipes (CollectionExporter.swift:226-250), a collection made under Full text with your annotations and exported under Citations with your notes prints four blocks where the sheet's sentence names two.
Duplicates: INT-5; ENG-1 (its last evidence line).

ID: DATA-6
Verdict: CONFIRMED
Severity: S2
Why: §7.2 makes the date line and "the template that placed it" properties. Lane 3 has "No screen changes but what the upgrade adds"; lane 4 first writes both under "Keys of the settings value; no deploy" (§9); Q7 is not among lane 3's preconditions. CloudKitSchemaInventory.swift:514-516: a field exists only after "the first record that carries a non-nil value"; :528-535 puts the promotion on "Whichever phase adds the first writer"; and the archive's check does not require awaiting-writer identifiers (Scripts/check_cloudkit_schema.py:151-154). One overstatement in the claim: the inventory records the way round it, the twelfth promotion's `cktool import-schema` of fifteen unwritten fields (:127-130), so "cannot be promoted" should read "is not promoted by the owner's write". The record names neither that step nor a default for these properties.
Duplicates: none.

ID: DATA-7
Verdict: CONFIRMED
Severity: S3
Why: `summaryPromptId` (Collection.swift:236) is not one of the eight fields a template writes (CollectionExporter+App.swift:31-38) and is in no row of §7.4. Nor is `researchNoteId` (:473), which the assembly still honours (CollectionContentAssembly.swift:1010-1015). The pair is two independent optionals on an entry (Collection.swift:526, :535), set by two pickers (CollectionEntryInspector.swift:701-710) and cascaded apart (CollectionContentAssembly.swift:605-608, :1049-1050), so one three-valued key cannot hold one half. §3.5's "nothing lost" is shown for a full pair only. Rare states, small consequence.
Duplicates: ENG-2 (b), for the half-set pair.

ID: DATA-8
Verdict: CONFIRMED
Severity: S3
Why: §7.3's rule 2 gives one consequence, "the collection opens for reading there", and rule 5's test names only "the current code". The five writers are at the lines cited (ProjectAdminService.swift:130-135; SummarizationPromptSeeder.swift:252-261; DuplicateRecordCleanup.swift:177-181; CollectionDocumentAppend.swift:160; ResearchImportPlan.swift:62-63). It is narrower than written: three of them write a property or a relationship outside the settings value (§7.2 lists the projects as a property) and cannot erase a key. The prompt collapse and an import's replacement are the two that would rewrite the value, since §4.1 puts the summary prompt inside it. Its last clause, a build that has not yet imported the raise, is §7.1's own stated limit ("the later writer's value stands").
Duplicates: none.

ID: DATA-9
Verdict: CONFIRMED
Severity: S3
Why: §7.6's test "reads the two models' stored properties from the schema", and that walk lists properties (CloudKitSchemaInventory.swift:607-618), while §7.2 stores every setting as a key of one property. The round-trip half catches a dropped key only if the fixture sets it, and nothing forces a new key into the fixture. A copy that takes the value whole cannot drop one, so the exposure is the mappings that go key by key (the file, the older export, the upgrade). The 1.0 types stay in the model under the same ids (§7.7), so a reader lane 3 misses still compiles and still finds a record, as WordCloudScopeResolver.swift:92-99 would. The 20 files reproduce on my search.
Duplicates: none. FMT-7 meets the same test from the file's side.

ID: DATA-10
Verdict: CONFIRMED
Severity: S3
Why: §3.6 says "The author may move it as any block, or remove it"; §5.2 lists the Note under Back matter and §7.2 stores it among "the five back-matter switches". The record says which nowhere. The reading of §5.7 is loose (the five switches "gone" there are the first form's apparatus switches), but that row's own reason, "toggles create a parallel structure system", applies. For the snapshot: "the source's own entries are not copied" (SmartCollectionSnapshot.swift:97-98), and a smart collection's blocks are its own generated entries (Collection.swift:987-988). So a copy of "the collection's value whole" (§4.5) follows a template whose blocks it lacks; 1.0's snapshot has the same gap.
Duplicates: for the Note, INT-6 (b), EDI-3 (its last evidence line) and ENG-4 (its last sentence).

ID: FMT-1
Verdict: CONFIRMED
Severity: S2
Why: The floor rises "only when *ignoring* a field would corrupt meaning" (NativeCollectionFormat.swift:91-93; :657-659). A version-3 file with a floor of 1 is a pinned case (CollectionTests.swift:2946-2948, :2993-2995) and a published one (Docs/Agentic-Analysis-Guide.md:2960-2963), and both manuals promise "a collection using no newer features is written in a form older app versions open unchanged" (iOS :1152, macOS :897). I looked for a setting of §4.1, §4.3 or §5.2 that a 1.0 reader would misread and found none: each is an unknown key, which is ignored, or has a 1.0 key already (`footnoteStyle` holds the same three values, :151-154). The reason given does not hold: §7.6 declines "a second function from the new values back to the old", yet lane 3 keeps today's two switches over the new key (§9; CollectionCompositionRows.swift:88-96), and the refusal message itself needs the six old keys (FMT-2). Not NOT NEW: §7.7 states the refusal as a cost; the finding shows it is a choice against the format's own rules. The first form kept the floor (aad7636, line 243), the review found that sound (review :220), and §11 drops it with no row.
Duplicates: none.

ID: FMT-2
Verdict: CONFIRMED
Severity: S2
Why: `decode` decodes the whole struct (NativeCollectionFormat.swift:435) before it reads `format` (:436) or the floor (:439-442), and `composition` with its six members is not optional (:116, :150-169). A version-3 file without them throws a decoding error and never reaches the message at :327-328. All three import paths show `error.localizedDescription` (CollectionListView.swift:304-306; MacCollectionManagerView.swift:505-507; FRUSExplorerApp.swift:2477). The fetched standard library gives such an error Cocoa code 4865 or 4864; its words are not established here. The gate reads `minimumReaderVersion ?? formatVersion` (:439), so a writer that keeps today's floor of 1 (:659) is opened by 1.0, not refused; §7.6 states neither the keys nor the floor. So §7.6's promise and its reason cannot both hold. Which of the two alerts on one flag 1861 presents (FRUSExplorerApp.swift:2219-2225 without a message, :2235-2243 with one) is a run's to say, for today's files too.
Duplicates: none.

ID: FMT-3
Verdict: CONFIRMED
Severity: S2
Why: `headnoteSummaryId` is written whenever set (NativeCollectionFormat.swift:521) and read back unchanged (:760; NativeCollectionFormat+App.swift:141), so a file imported on its author's account makes entries that point at the original's drafts. Edit and Regenerate delete the draft with that id (CollectionEntryInspector.swift:1158-1165), and so do a row's and a collection's delete (GeneratedSummary.swift:238-243, :258-262; Collection.swift:885-889). Duplicate copies the draft (Collection.swift:866) and the import does not. One correction: §7.5 sends a version-1 or version-2 file "through the same function", whose table copies a draft under an id derived from the new entry's, so the record may cure old files without saying so. A version-3 file has no such rule, and §7.6's round trip "with every field set" would hold the id. Read, not run; it is a 1.0 defect to file with §2.8's.
Duplicates: none.

ID: FMT-4
Verdict: CONFIRMED
Severity: S2
Why: The three rendered formats read `doc.includeNotesOverride ?? options.includeNotes` (CollectionItemHTMLRenderer.swift:397; DocxCollectionExporter.swift:781; PDFCollectionExporter.swift:854). BibTeX and RIS read `options.includeNotes` alone (BibTeXCollectionExporter.swift:63; ZoteroCollectionExporter.swift:65-69), on items whose notes are attached whatever the cascade says (CollectionContentAssembly.swift:1131). The Zotero send reads no option (CollectionExportSheet.swift:734-735), and the file's notes follow the sheet's one switch (:621-644). This is 1.0's behaviour, in no row of §2.8; under §4.1's "It shows what is in force", a row reading off for one document would be untrue of four of the sheet's seven exports. S2 because a note the author turned off is sent out.
Duplicates: none. INT-3 cites the same lines for another point.

ID: FMT-5
Verdict: DUPLICATE of INT-3; the pair is CONFIRMED
Severity: S2
Why: §4.4 and §5.1 put the look above every format and say nothing of the four that are not renderings. BibTeX and RIS read one flag a recipe sets, notes (CollectionExporter.swift:227, :243); the RIS path takes the stored collection's options by a pinned source line (CollectionExportSheet.swift:712; CollectionTests.swift:5652); the Zotero send reads none. The board files Zotero under More formats (Main.dc.html:54) where §5.1 says "The Zotero row stays as it is". One trim: "it is written into a `.fruscollection`" is one of two readings the record leaves open, not something it says.
Duplicates: INT-3.

ID: FMT-6
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: All of it is true: the Guide pins its bytes as a fixture (Docs/Agentic-Analysis-Guide.md:2829-2830; CollectionTests.swift:3015), its checker fails a gate above 2 (:2933-2936), two ranged blocks cite the format (08-Reading-Research-Collections.md:897, :3226), and the record never names the Guide. It is S3 because it is a list of what lane 3's row leaves out, the class the first review held at S3 (its ENG-9), in a lane the record already calls the largest. What a person meets, a refused file and a manual sentence made false, is FMT-1's.
Duplicates: none.

ID: FMT-7
Verdict: CONFIRMED
Severity: S3
Why: §7.6 holds "the file" to "a round trip of a fixture with every field set". By rule the file carries no ids, dates or projects (NativeCollectionFormat.swift:19-22, :679-683), no chosen notes or highlights (:268-273, :55-58), no saved-search link (:681) and not the collection's summary prompt (:146-147). §4.1 puts that prompt inside the one value, so the file's writer cannot take the value whole, which is §7.1's third reason.
Duplicates: none.

ID: FMT-8
Verdict: DUPLICATE of ENG-6; the pair is CONFIRMED
Severity: S3
Why: One reading feeds the citation and the citation record (CollectionContentAssembly.swift:986, :992-995, :1124-1132); it is top-level only (:1468-1482) and writes a labelled call as "[n]" (:1518-1522). The item's title and Extra are that heading and dateline (ZoteroJSONExporter.swift:159-168). §3.4's "stay so" speaks of the author's title; whether the records take lane 2's reading is unsaid. §9 names CollectionResolutionTests.swift:450-452 but not the digest at :706, whose dump prints the header, dateline and Zotero title. My own count over the eight volumes (review2/scripts-C/recount.py) reproduces the figures: 3,965 documents; 1,930 heads with a labelled note; 308 of 315 in frus1977-80v06 and none in frus1961-63v11; 17 with a dateline as a direct child.
Duplicates: ENG-6.

ID: FMT-9
Verdict: CONFIRMED
Severity: S3
Why: Q8 recommends candidates 1 and 4 for the first pass. Candidate 1 rests on `selectedHighlightIds` (§8.1), which "NEVER serializes" and whose highlights do not travel (NativeCollectionFormat.swift:55-58, :523-524, :755). Candidate 4 is "a record type of its own" (§8.4), §4.3 has the collection record the template it follows, and §7.6 and §8 say nothing of a recipient who lacks it. Both are candidates, not the core.
Duplicates: none.

ID: FMT-10
Verdict: CONFIRMED
Severity: S3
Why: §5.1's Export Again keeps a format and "as this collection is set". The file's notes switch is sheet state, off at each opening (CollectionExportSheet.swift:67-70, :594-596), and the file is not offered for a smart collection (CollectionExporter+App.swift:176-179). The trail row holds a format, a count, a name and a project (ExportHistoryEntry.swift:60-84), and the Zotero send writes one too (CollectionExportSheet.swift:753). The since-linked case was left open by the first review's skeptic and is still unanswered.
Duplicates: INT-8, in part.

**The file section, checked**

**The rules (1).** Each re-read at its line in FRUSCoreKit/Collections/NativeCollectionFormat.swift; all hold.
- Decoupled from the models: :24-26.
- Required keys: :80, :84, :96, :116, :118, :150-169, :201.
- Versions: :412, :81-94.
- The gate's order: :435, then :436-438, then :439-442.
- Write-the-minimum: :448-454, :615-652; version 2 with a floor of 1: :654-659; `footnoteStyle` always written: :151-154, :479; an unknown kind left out: :594-598.
- Never serialized: :21-22, :55-58, :146-147, :268-273, :681.
- One writer in the app: CollectionExportSheet.swift:641-645. Three readers: CollectionListView.swift:290, MacCollectionManagerView.swift:491, FRUSExplorerApp.swift:2459-2460.
- Two things the section could add. The coding is synthesized (no `init(from:)` in the file or its app half), which is why every non-optional key is required and every unknown key ignored. And the legacy single-note link has no key either, though the sheet's closure resolves its text when notes are included (CollectionExportSheet.swift:632-635).

**The table (2).** Eleven rows tested against the code; each holds.
1. A key 1.0 does not know (Opening, Numbering, date line, citation style, wording, template, placer) is ignored: pinned at CollectionTests.swift:2946-2971, where an unknown top-level key and an unknown entry key decode and an unknown kind is skipped.
2. The volume's notes: `footnoteStyle` is required with the same three values (:151-154), the pair optional (:158-161, :251-253). "all" with no pair reads on 1.0 as footnotes on, source note off (Collection.swift:165-183), so no second copy prints.
3. Headnote on or off: a heading's is dropped at import (:759).
4. Headnote's text: the id alone (:231, :521, :760).
5. Your notes: which, never; texts on the sheet's switch (:268-274, :503-505, :705-715).
6. See also: on a document and a heading (:262, :721, :756), none for the collection; 1.0 follows a heading's (CollectionContentAssembly.swift:611-612, :1103).
7. The Note on the Text as a new block type: kept, inert (:741-746; CollectionContentAssembly.swift:964-965).
8. The template followed: the Guide's write-minimum (Docs/Agentic-Analysis-Guide.md:2812-2819) equals none of the six recipes (CollectionExporter.swift:226-250), so an agent's fresh file would be shown as settings that "came from 1.0".
9. Ids: fresh at every import (:695, :723; NativeCollectionFormat+App.swift:107, :128).
10. A smart collection: no key, and not offered (:681; CollectionExporter+App.swift:176-179; CollectionExportSheet.swift:613-617).
11. What the importer returns: a `CollectionExport` with its entries, and the notes (:693-793, :804-809), the type §7.4's function takes.

Two cells are loose.
- In the last column, a file "without" Text, Your notes, Highlights, the contents-list style or the word cloud cannot exist. Those five are required composition keys (:150-169) and such a file does not decode. "Full", "on" and "off" there are the writer's fallbacks for values that lack a field (:478-487).
- "An import shows no report" is an inference. §7.4 describes the report for the upgrade pass, and the record says nothing of one at an import.

**The judgements (3).**
- **Necessary: no. Holds.** The old keys can say every core value: Text as `defaultBodyDepth`; the notes as `footnoteStyle` and the pair; headnote, notes and highlights; See also on an entry and a heading; the contents style; the four switches; the title. What a 1.0 reader loses (date line, wording, opening, numbering, citation style) is ignored, which is the format's "degradable" (:91-93). The mapping back is a small total function that lane 3's screens need anyway.
- **Sufficient: no. Holds.** §7.6 gives the file two sentences. Unsaid: the keys version 3 writes; its floor; that it keeps the required old block; what carries a headnote; whether a look reaches the file; the template and a block's placer; how the record's one `formatVersion` (§7.3) becomes the file's two numbers; the Guide's readers.
- **Consistent: no. Holds on two of its three grounds, and on a fourth.**
  - Holds: §7.3's rule 3 adopts "the collection file's own rule, write the minimum" and §7.6 drops it for the file.
  - Holds: the round trip against the never-serialized list.
  - Does not hold as a contradiction: §7.3's rules 2 and 5 against an import. Those rules govern a synced record written back. An import makes a new record, and the format already says unknown keys are dropped (Guide :2976). This is silence, and belongs under Sufficient.
  - The fourth is FMT-2's: 1.0's message is reached only by a file that carries the six old keys, which is the mapping §7.6 declines.
- **The closing paragraph holds too.** A version-1 or version-2 file reaches the upgrade as the type it takes, and the web edition at its pin is a second 1.0 reader with the same message.

**The reviewers' "§11 rows" verdicts in your files**

- DATA.md, the row for the first review's DATA-4 ("ANSWERED"): PARTLY. Sync is closed, since 1861 cannot write the new types. But an older writer can still change what the recorded template describes through a format-7 file imported over an upgraded library, which this report's own DATA-4 shows §7.5's sentence does not settle.
- FMT.md, G1 ("PARTLY"): for the file the row is answered or does not apply. G1 was a synced record a build writes back. A later file is refused at the gate or imported as a new record with unknown keys dropped, by the format's published rule (Guide :2976). What is missing is §7.6's statement, which is "Sufficient", not G1.

**Errors in the design record found on the way**

1. §4.1: a section's See also "followed by its documents, which 1.0's cascade does not do". 1.0 does (CollectionContentAssembly.swift:611-612, :1103); only the headnote is new (:1086).
2. §7.4 and §4.3: "no numbering ... what 1.0 prints". 1.0 numbers every document row of the contents list (PDFCollectionExporter.swift:630-638; DocxCollectionExporter.swift:1898-1906).
3. §4.3: an upgraded collection "prints as it did, apart from §2.8's defects". §3.3 and §3.4 give a titled document a citation line and the words Printed heading: at every depth, where 1.0 prints the title in the citation's place (CollectionExporter.swift:747-750). §7.4's report lists neither.
4. §3.5: "1.0's pair maps onto them with nothing lost". Not for a section or document that sets one half (Collection.swift:526, :535; CollectionContentAssembly.swift:1049-1050).
5. §7.4: upgraded records are ones "the duplicate cleanup can pair"; §7.5: "The cleanup keeps one". The pass names ten types and neither new one (DuplicateRecordCleanup.swift:91-101), and for copies with one id and one creation date its own text says the device's fetch order decides (:64-66).
6. §7.4: a headnote draft's derived id means "two devices make the same copy". They make two records under one id, of a type the pass does not collapse (:91-101).
7. §7.4: the pass runs "after the first iCloud import of a launch has settled". The wait cited is 8 seconds of quiet after any import event (FRUSExplorerApp.swift:3379-3384), "usually" enough by the tree's own word (:3438-3442).
8. §7.5, second row, rests on the collection's date moving when a 1.0 device changes it. Collection.swift:28-29: an entry's edit leaves the collection untouched.
9. §7.3's rule 3 calls write-the-minimum "the collection file's own rule"; §7.6 drops it for the file.
10. §7.6: 1.0 refuses a version-3 file "with the message it has for a later file", and no function back to the old values is proposed. The message comes only after the whole file decodes, six old keys included (NativeCollectionFormat.swift:435, :439-442, :150-169).
11. §7.6: the file "held to a round trip of a fixture with every field set", against the format's never-serialized list (NativeCollectionFormat.swift:19-22, :55-58, :146-147, :268-273, :681).
12. §9, lane 4: "Keys of the settings value; no deploy", for work that first writes the date line and a block's placing template, which §7.2 lists as properties.
13. §7.4: "What keeps such a build from shipping is the archive's schema check". The check does not require identifiers listed as awaiting a writer (Scripts/check_cloudkit_schema.py:151-154).
14. §3.6 ("move it as any block") against §5.2 and §7.2, which store the Note on the Text among "the five back-matter switches".
15. §7.4's table has no row for the collection's summary prompt (Collection.swift:236) or an entry's single-note link (:473). It lists the word cloud twice: among the eight fields a template writes (CollectionExporter+App.swift:31-38) and among "the same four switches".
16. §5.1 ("The Zotero row stays as it is") and §5.5's count of it, against the board's "More formats: BibTeX, RIS, .fruscollection, Zotero" (Main.dc.html:54).
17. §11's "found sound, and this form still relies on" omits the review's "`.fruscollection` keeps `minimumReaderVersion` 1" (review :220), which §7.6 reverses, with no row.
18. §7.4, third row: a collection that matches no recipe is shown as settings that "came from 1.0". By §7.5 that would be said of a file an outside tool wrote that day (Docs/Agentic-Analysis-Guide.md:2812-2819 against CollectionExporter.swift:226-250).

**Not checked**

- Nothing was built or run. Not established from anything readable here:
  - the order of an unsorted SwiftData fetch;
  - how the mirror batches a first import, and whether 8 seconds of quiet falls inside one;
  - whether a device updated later receives records of a type it did not know;
  - whether adding or removing one entry stamps its collection;
  - which of the two open-with alerts 1861 presents, and the words of a decoding error's description.
- The web edition's repository: its pin and the version its export writes.
- Counts I did not reproduce exactly:
  - the record's 53 and 26 files (a rougher search gave 44 and 24);
  - DATA-9's 27 sites (its 20 files reproduce; a looser pattern gave 30 sites);
  - FMT-6's counts of tests (I found three test files that name the serializer, and counted lines, not tests).
- The first review's reports beyond its summary's §5 and skeptic A's DATA-10 lines; the boards beyond Main.dc.html:28-70; the PDF and Word exporters beyond the lines cited; ResearchDataEnvelope.swift; the UI suites.
- ENG.md was not there when I began. It arrived while I worked, and I read it whole for duplicates.