Skeptic B: ENG and EDI. Read from REPO at 0fa40e16; index version 76 on claude/plan-of-record-pr2011-2cc493, which has moved on since the reviewers read it (its newest commits are now 78b172cf, 254283cc and 20eabba9: decisions 188, 189 and 190); the public TEI at 216cdb764, the 553 manifest volumes. I wrote my own scripts under SCRATCH/work-B/. Nothing was built or run.

ID: ENG-1
Verdict: DUPLICATE of INT-1 and DATA-1. The three together are CONFIRMED.
Severity: S1
Why: L47's brief says only "one document's settings copied to others. It writes the fields 1.0 has" (plan:707). The tree's own definitions of a document's settings include the fields that name its records: hasDocumentSettings lists titleOverride, headnoteSummaryId, selectedNoteIds, researchNoteId and selectedHighlightIds (CollectionEntryRows.swift:368-374), and Duplicate copies every one of them (Collection.swift:843-857). The kit then resolves them with no check of the document:
- the chosen notes are found by id over every note (CollectionContentAssembly.swift:1007-1011);
- the headnote is `source.summary(id: sid)` (:1365);
- the highlights are filtered to the target's own, so the source's ids leave the target none (:1057-1060);
- resolvedNoteTexts go into the Zotero item, which BibTeX and RIS write (:1131; BibTeXCollectionExporter.swift:61-64).
A shared draft id is lost through either entry. Its edit deletes the draft it points at (CollectionEntryInspector.swift:1160-1165), and so does its row delete (GeneratedSummary.swift:238-243). The delete half needs the id copied without Duplicate's duplicateHeadnoteDraft (Collection.swift:866). The false print does not need it: the source's headnote and notes print under the target either way. That is a common use of the feature and an unmarked false attribution in every format, so S1 stands.
Where it is answered: L47's brief. I agree.
Duplicates: INT-1, DATA-1, and the first line of INT's "Outside my scope".

ID: ENG-2
Verdict: CONFIRMED for the Note on the Text. The L52 half is NOT NEW.
Severity: S2
Why: The seam gives a block the membership alone and a source that is "read-only by contract … answer identically for .preview and .export" (CollectionGeneratedBlocks.swift:21-22, :155-160). It is called inside the entry loop with batch.collectionDocuments (CollectionContentAssembly.swift:964-968). It turns an empty result into the "Nothing to list" row (:184), and generatedBlockEmptyStates holds every case of allCases to that row (CollectionTests.swift:4801-4810). §3.6's Note, by contrast, must read each entry's resolved title, date line, depth, note switches and headnote authorship, and must print nothing when it has nothing to say. §3.6's line in the settings is a second caller of the same rule, outside any export.
Two of ENG-2's points are overstated:
- Document summaries are Apple Intelligence's by construction. Only a headnote draft is ever made aiEdited or userWritten (CollectionEntryInspector.swift:1138-1142), and drafts are out of every summary lookup (CollectionContentAssembly.swift:1371-1376). So "summaries were written by Apple Intelligence" can be said from the resolved depths, before the summary phase.
- A Note moved above the documents "describes none of them" only if it reads resolved items in loop order. The membership is computed before the loop.
The L52 half is the review's own first finding (a2-what-the-index-owes.md:94-97). Decision 188 on the v76 branch says CR's pull request writes it into L52's brief.
Where it is answered: L43's brief, as ENG says. L52's brief by decision 188's note.
Duplicates: none among the six reports. The L52 half is the a2 note's.

ID: ENG-3
Verdict: CONFIRMED
Severity: S2
Why: The PDF's body is one attributed string per document, laid out frame by frame (PDFCollectionExporter.swift:796-842). It is drawn with one CTFrameDraw per frame in drawFrameWithHighlights (:817, :1460-1494). The cover, the contents, the notes and the blocks are drawn the same way (:335, :380, :445, :884), and nothing in the tree tags.
ENG's API claims, made from memory, can be read in the SDK on this Mac:
- CGPDFContext.h:442: a tag marks "any series of draw commands with balanced series of push / pops";
- a link needs a rect its caller computes (CGPDFContextSetURLForRect, :83).
So tagging a heading, a paragraph or a note inside one frame means drawing it as its own run or line. L48's proof (plan:715) is two pages of its own and exercises none of that drawing.
One correction: a document's own heading today is a separate draw (`let cit = doc.exportHeading`, :687-691), so a citation-led heading could be tagged at today's grain. Under decision 158, though, the volume's heading leads in four templates and in every new collection, and it sits inside the body string.
The header also shows a cost neither brief states. The structure-tree API, and CGPDFTagTypeArtifact (which marks page numbers), are API_AVAILABLE(macos(27.0), ios(27.0)) (CGPDFContext.h:397, :480). The app targets 26.0 (project.yml:78), so L48 must build on the legacy CGPDFContextBeginTag (:461, 10.15 / 13.0) or gate by OS. What VoiceOver announces is still a run, but the finding does not rest on it.
Where it is answered: L34's and L48's briefs. I agree.
Duplicates: none. A11Y-8 (what the tags must cover) is related.

ID: ENG-4
Verdict: CONFIRMED
Severity: S2
Why: The preview refreshes on a hash kept by hand (CollectionPreviewView.swift:210-266, `.task(id: contentFingerprint)` :287). The hash lacks titleOverride and defaultIncludeHeadnote today. The preview also builds its own export options (:519-531). No test reads either: `git grep contentFingerprint` over both test targets finds nothing.
The plan's third departure says "lane 4 then adds its new settings to the refresh list L36 completes" (plan:443). Lane 4 is L44, which stores nothing (its row, plan:271; design §9, lane 4: "Stored data: None"). The new settings are L43's, and L43's row of files (plan:270) does not name CollectionPreviewView.swift.
So the departure names the wrong row, and #1997 recurs for each of L43's five or six fields: an author changes a setting with the preview open, and the page does not change. A false line in the plan, and a control that seems to do nothing on a common task: S2.
Where it is answered: L43's brief and the third departure. I agree, and add L48 and L49 if either keeps a choice on the collection.
Duplicates: none.

ID: ENG-5
Verdict: CONFIRMED
Severity: S3
Why: Eight types conform to the blocks' data source:
- AssembledBlockDataSource (CollectionContentAssembly.swift:1256);
- TripPacketDataSource, through TripPacketReferenceDataSource (TripPacketBuilder.swift:718, :740);
- the two fixtures (CollectionTests.swift:5434; CitationFormatterTests.swift:950);
- four packet stubs (ArchiveVisitAppWritesTests.swift:26; ArchiveVisitPhase3Tests.swift:26; FRUSCoreKit/ArchiveVisitRecordDerivationTests.swift:30; FRUSCoreKit/TripPacketBuilderTests.swift:68).
So §9's "which both must answer" and L50's "which both fixture sources answer" (plan:731) undercount. The refinement exists, by its own comment, because "a requirement there would force every collections conformer to implement a query only the packet runs" (TripPacketBuilder.swift:712-716), and A3 reads that very query. The cost is stubs: the packet's source already returns empty for the block members it never reads (its doc comment, above :740). That makes it S3.
Where it is answered: L50's, L53's and L54's briefs, and §9's sentence. I agree.
Duplicates: none.

ID: ENG-6
Verdict: CONFIRMED
Severity: S3
Why: everyApparatusBlockInTwoTemplates runs over CollectionGeneratedBlockType.allCases. It requires exactly one recipe that carries every type, and two others that carry each type (CollectionTests.swift:3561-3571). generatedBlockTypeVocabulary pins allCases to the five raw values (:4508-4512). The recipes carry no Note (CollectionExporter.swift:226-250), and decision 173 keeps A2 to A4 out of every set.
So the suite goes red at L43, and stays red until L44 puts the Note in every set (§4.3). It goes red again at L51, L52 and L53. §9's "CollectionTests.swift:3450-3565 goes on holding it" cannot be true of a test written over allCases. A session meets this at once, and it is test upkeep, so S3.
Where it is answered: L43's brief, and §9's sentence. I agree.
Duplicates: none.

ID: ENG-7
Verdict: CONFIRMED
Severity: S3
Why: My count of ranged SOURCE lines in Docs/EditableContent/08-Reading-Research-Collections.md reproduces ENG's:

| Source file | Ranged blocks |
|---|---|
| CollectionExporter.swift | 26, of which 24 are collection.preset.* keys |
| CollectionEditorView.swift | 9 |
| CollectionEntryInspector.swift | 8 |
| CollectionEntryRows.swift | 7 |
| MacCollectionManagerView.swift | 3 |
| CollectionCompositionRows.swift | 1 |

L44 edits all five app files (plan:271), and its "What it owes" (plan:682) names none of these blocks. EditableContentKeyTests.everyRangedBlockHoldsItsKey fails on a range that has moved. The subtitles still name apparatus that step 1 will no longer add (CollectionExporter.swift:119-135).
The UI half is partly stated already: §9 says "Lane 4 brings each [suite] to its surface". But three tests (CollectionEditorTitleTests.swift:296, :315, :340) reach the collection's fields through a section's sheet (openSectionDefaults, :590-597), and that is the surface L44 removes.
Where it is answered: L44's brief. I agree.
Duplicates: none.

ID: ENG-8
Verdict: CONFIRMED
Severity: S3
Why: The export keeps every term counted at minimumCount, whose default is 1 (WordCloudExport.swift:172; WordCloudTuning.swift:36-37), and places only terms.prefix(140) (:187). Neither §8.2's A12 nor L55 bounds the table.
My own script reproduces ENG's figure for the eight telegrams exactly: 2,283 forms, 1,377 seen once, with notes left out. With notes kept, which is what bodyText holds, it is 2,363.
There is counter-evidence: the design's own citation, KeynessCloud's list, holds "the same terms" as the cloud because it is the cloud's accessibility representation (KeynessCloud.swift:40-41). That rule points to the bound, and L55's brief should state it. The app's exact figure, after stopwords and lemmas, would need a run.
Where it is answered: L55's brief, not the owner, since the design's own cited rule gives the answer.
Duplicates: none. EDI-4 and FMT-6 are related.

ID: ENG-9
Verdict: CONFIRMED
Severity: S3
Why: §3.4 gives the outline "the title, with the volume's heading as the row's second line". Both outline rows read the indexed header and no override (CollectionEntryRows.swift:972; MacCollectionManagerView.swift:2015-2027, documentLabel then documentHeader). L34's app files are PDFCollectionExporter.swift alone (plan:267), and L44's brief does not name the outline's line. L35, "developed beside L34" (plan:645), edits MacCollectionManagerView.swift (plan:268). The second review's ENG-5 named these two rows. The third form's §11 answers it with "Named | §9, §7.4", but §9 does not name them, so the finding is left standing.
Where it is answered: L34's brief. I agree.
Duplicates: none. It re-raises the second review's ENG-5 and shows it still standing.

ID: ENG-10
Verdict: CONFIRMED, with one overstatement
Severity: S3
Why: Highlights are read only at full depth (CollectionContentAssembly.swift:1057, `effectiveDepth == .full`). Each exporter walks the render model with its own highlight counter (CollectionItemHTMLRenderer.swift:340-346; DocxCollectionExporter.swift:1570-1574; PDFCollectionExporter.swift:186-197). A footnote call is data-skip, not flat text (FRUSRenderNodeHTMLSerializer.swift:31-46), so a passage's offsets do not say which calls it keeps, and L46's four questions (plan:698) leave out which notes print.
The overstatement is "rules out". §3.8's "Every node of the document is drawn" describes the core at full depth. It is not a rule against a new depth: Summary already draws no node. The real gaps are where the cut is made (once in the kit, or three times in the exporters) and what happens to the notes.
Where it is answered: L46's brief. I agree.
Duplicates: none. Related: INT-10 (which highlights make the passages), DATA-5 and FMT-3 (where an imported passage is kept).

ID: EDI-1
Verdict: DUPLICATE of FMT-5 (rows and anchors not keyed by volume and the editors' id) and of DATA-2 (the 809 pairs). The pair is CONFIRMED, RE-RATED.
Severity: S2
Why: My own counts reproduce EDI's:
- The manifest's lists hold 66,203 entries. 112 volumes list one abbreviation in two items, 220 words in all; frus1946v11's are BA, CAB, CPA, CTC, MA, SD and TACA.
- In frus1946v11, t_BA1 ("Buenos Aires") is linked in d201 and d485. t_BA2 ("Division of Brazilian Affairs") is linked in eleven documents: 41, 114, 119, 436, 441, 442, 450, 461, 465, 471 and 480.
- AP is the Associated Press in frus1949v01, v02 and v05. frus1949v04 lists both meanings and links only t_AP2, "Atlantic Pact", in d191.
Neither text says how a row is keyed. The design says "Each abbreviation … with the volume's definition" (§8.2). L52 says "as the Persons Index reads the people's", and that block merges rows by an identity across volumes (CollectionGeneratedBlocks.swift:538-545).
S1 is too high. The store's own key is (volume_id, ref): it is the `terms` primary key (IndexingPipeline.swift:8877-8883), and `term_mentions` on the v76 branch is indexed on (volume_id, term_ref). v76's read returns each ref with its definition (termsLinked, PersonMentionStore.swift:1140-1160 on the branch). So the false row needs a session to merge by the word or by the bare id, which the design's one-volume example invites but its text does not instruct. What is false in the text is its presupposition of one definition per abbreviation, and that is S2.
The 809 pairs are answered: decision 189, on the v76 branch at 254283cc, gives each spelling its own row.
Where it is answered: L52's brief, for the key and the anchor. The 809 pairs by decision 189.
Duplicates: FMT-5, DATA-2.

ID: EDI-2
Verdict: CONFIRMED. The finding is what its evidence shows, apart from two overstatements given below.
Severity: S2
Why: The same-volume pass rewrites each arabic page target where it stands: `UPDATE cross_references SET target_document_id = ? WHERE rowid = ?` (IndexingPipeline.swift:10697-10717). It writes PageSpanResolver's pick: a document that begins on the page, else one printed on it, then the one the note names by number or day, else the first (PageSpanResolver.swift:259-280, with the tie-break below it). The v71 note says the other-volume pass stores the form and the hint "neither" (:1636-1638), and the table has no other column for them (:8607-8625).
The line the design cites, CrossReferenceStore.swift:757-759 at efd73ec, is relatedByCitation's comment on a filter for the page anchors that remain. The See also line reads outboundEdges (CollectionContentResolver.swift:533-537), which keeps every non-empty target (CrossReferenceStore.swift:727, :731-751). So 1.0's See also line already matches same-volume page references, and §8.1's item 10 and L51's "The join both need" are mostly shipped already. A1's row reads xrefDocuments, which counts only `#d…` targets (VolumeAnnotations.swift:58-59), while page references are xrefPages and references to other volumes are xrefVolumes (:62-65).
My own replica counts:

| | My count | EDI | The index |
|---|---|---|---|
| Same-volume #pg_N references inside documents | 55,049 | 55,171 | 55,007 |
| …to a page that several documents begin on | 12,753 | 12,769 | 12,749 |
| …to a page that no document begins on | 8,368 | 8,402 | — |

d470's p. 676 is where d463 begins, and d486's p. 776 is where d529 and d530 begin.
The two overstatements:
- Not "every" same-volume page reference is rewritten: one whose page names no document keeps pg_N.
- L51's "every document on it, or none" still has a stored page to apply to in the 19,186 rows from other volumes that v71 left on their page: 10,633 "ff.", 8,326 range ends and 227 single pages naming nothing (:1628-1632).
Where it is answered: by the owner, as EDI said. Decision 190, on the v76 branch at 20eabba9, stores cited_page_id and page_resolution (one, range, number, day or first) on every such edge. Still owed: §8.1's item 10, A1's row for A4, A4's third bullet and L51's "The join both need" rewritten from what the index stores; and L50's line reading more than xrefDocuments.
Duplicates: none in the six reports. It is the second line of DATA's "Outside my scope" and the ENG line of EDI's own.

ID: EDI-3
Verdict: CONFIRMED
Severity: S2
Why: The harvest stores a central file only as a decimal class that carries a serial, is not subject-numeric and composes under the decimal schedule (IndexingPipeline.swift:6734-6739). The footnote grammar has "only two anchors", lot files and presidential libraries (FootnoteCitationGrammar.swift:71-77). So neither the subject-numeric files of 1963 to 1973 nor the Central Foreign Policy File is ever read.
My own pattern count of body footnotes (not source notes, and not inside a heading) finds:
- in the volumes from 1977 on, 6,211 that name the Central Foreign Policy File, 5,976 of them naming no lot and no library (EDI: 5,987);
- before 1955, 2,556 that name a lot or a library, so central files are not "the only pointers there are" before 1955 either.
This is worse than §11 states ("A3 is as complete as a grammar … It lists the ones a footnote gives a file for"), because from 1963 on a footnote gives a file the grammar does not read.
"Can list no central file at all" from 1964 overstates by a handful: EDI's own count finds 6 decimal pointers in 1964–68. My narrow subject-numeric pattern undercounts EDI's 3,339 for 1964–68, but the samples of EDI's broader pattern I read in five volumes (frus1964-68v01, v02, v12, v18, v21) were real file citations ("RG 59, Central Files 1964-66, POL 7 USSR").
Where it is answered: L53's brief, with the block's title the owner's. I agree.
Duplicates: none.

ID: EDI-4
Verdict: CONFIRMED
Severity: S2
Why: All three exporters hand the cloud every document's bodyText (HTMLCollectionExporter.swift:96-97; DocxCollectionExporter.swift:238-239; PDFCollectionExporter.swift:208-211). bodyText is set at every depth (CollectionContentAssembly.swift:999, filled at :878-893) and is "every node's text, footnotes included" (IndexingPipeline.swift:7756). The count runs under the device's verdict on lemmas, and under WordCloudSettings' tuning and hidden words (WordCloudExport.swift:158-172; WordCloudSettings.swift:29-49). Distinctive refuses a scope whose plural folding, markings, diplomatic layer or minimum length differ (CloudVectors.swift:468-476).
§8.2's A12 gives caveats to Distinctive alone, and calls the table "the same data". Under Summaries, whose suggested set has the cloud (§4.3), the table's numbers count text the export never prints. The image already carries a line of method where it counted printed forms (WordCloudExport.swift:180), so the remedy has a precedent.
Where it is answered: L55's brief. I agree.
Duplicates: none. ENG-8 and FMT-6 are related.

ID: EDI-5
Verdict: CONFIRMED
Severity: S2
Why: My count of first headings, with notes left out, reproduces EDI's:
- Before 1952, 13,669 headings open with "No. N" or "N.", in 39 volumes (31 of them with 50 or more). 6,091 of these numbers are not the division's @n (EDI: 6,093).
- Of the 28 volumes for 1952–1954, 16 print no number in the heading.
The number is the volume's own. frus1873p1v2 d1's heading is "No. 307.", while its opener carries the despatch serial, "No. 46.]". frus1874 d100's heading is "No. 98.".
So three statements are false: §3.3's "From the volumes for 1952–1954 on, the volume's number already opens the heading", §3.4's "from the 1952–1954 volumes on", and §3.6's "the volumes before 1952 print no document numbers". The one reading needs a rule by the number's form.
One sub-claim is not new to this design: every style, History at State's included, prints the index's @n after the imprint, "so citations resolve to the HSG source" (IndexingPipeline.swift:6667-6671), as 1.0 does in every export today.
Where it is answered: L34's brief, and L43's for the Note's sentences; the citation's number is the owner's. I agree.
Duplicates: none.

ID: EDI-6
Verdict: DUPLICATE of FMT-4. The pair is CONFIRMED.
Severity: S2
Why: The captions are 1.0's. aiEdited prints "AI-generated summary, edited by you", and userWritten prints none (CollectionExporter.swift:1127-1137; CollectionItemHTMLRenderer.swift:458-462). The editor's chip reads "Yours" (CollectionEntryInspector.swift:1043-1045).
Decision 166 carries the three-valued SummaryAuthorship with the text (§7.4: "with who wrote it"; SummaryTypes.swift:85-92), and "every import makes a draft of its own". So a recipient's draft of the sender's words reads "Yours", prints with no caption, or says "edited by you", and neither the design nor the plan states any of these.
EDI-6's first clause on its own is weaker. No caption on a user-written headnote is 1.0's deliberate rule (CollectionExporter.swift:1119-1123), and §3.7 names the compiler's headnotes in the statement of sources. Its other points are S3 on their own:
- §3.3's openings draw no headnote, so where it prints under a leading heading is unsaid.
- "Headnote" can be renamed "Editorial Note". By my count that is the exact heading of 7,639 documents in 277 volumes, and 8,468 divisions in 296 volumes are editorial notes. The Note on the Text lists renamed labels (§5.2).
Where it is answered: L43's brief, with the attribution's wording the owner's. I agree.
Duplicates: FMT-4, and the second line of DATA's "Outside my scope".

ID: EDI-7
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: Under decision 158 the volume's heading leads in Summaries, and where the text does not print §3.4 prints only "the heading's words" (§3.2:267; §3.4:327), so no date stands at a document's head. In frus1946v06 two headings are each carried by 45 documents, and 562 of its 692 documents share their heading (my count).
Two things do not hold:
- The date is not lost against 1.0. 1.0 prints none at summary depth either (CollectionItemHTMLRenderer.swift:296-309, :356-372), and no exporter prints doc.date.
- The documents can still be told apart. The citation, with its number, still prints as the small line above the heading (§3.3), and that set's contents rows carry the dateline once #1994 is fixed.
For a sighted reader what is left is an improvement missed (the one reading already returns the dateline), so S3. The harm to a reader moving by headings is A11Y-1's.
Where it is answered: L34's brief. I agree.
Duplicates: partly A11Y-1, for the shared heading at a document's head under decision 158.

ID: EDI-8
Verdict: CONFIRMED
Severity: S3
Why: §3.4 says "A title never prints without the volume's own words beside it" (line 325). It then gives a titled contents row in Citation style "the citation" as its second line (line 328): the app's rendering of the volume's metadata, not the volume's words, and with no As published:. Citation style is the model's default (Collection.swift:207), and four of the six recipes set `toc: .citation` (CollectionExporter.swift:226-250). Nothing printed is false, since the citation names the document and the document's own head carries the mark. It is an inconsistency between two lines of §3.4, so S3.
Where it is answered: L34's brief. I agree.
Duplicates: none.

ID: EDI-9
Verdict: CONFIRMED
Severity: S3
Why: The bundled table's provenance says the classification "was RENUMBERED in 1950 … so a key resolves only against the schedule governing its own era" (decimal-class-labels.json). DecimalClassLabelTable.swift:82-84 calls a label for a span across 1950 a guess. The packet that A8 follows keys a central file as `class|611.51`, the bare class (TripPacketBuilder.swift:441-442, :496).
My count of each source note's first decimal number gives the same later halves as EDI's: 761.00, 76 documents from 1950; 762.00, 374; 793.00, 320; 740.00, 110; 711.00, 11. My earlier halves are lower over a narrower range of volumes: 761.00, 45 before 1950, where EDI has 56.
Source Explorer's two routes "need different sentences" (RollScansIndex.swift:107-115), while L54 gives one. And the block's group row holds the only link (CollectionGeneratedBlocks.swift:459-464), where a range belongs to one document's serial.
Where it is answered: L54's brief. I agree.
Duplicates: none.

ID: EDI-10
Verdict: CONFIRMED
Severity: S3
Why: In the bundled administrations each term ends on the day the next begins (administration-profiles-index.json): Roosevelt to 1945-04-12 and Truman from 1945-04-12; Nixon to 1974-08-09 and Ford from 1974-08-09. Documents are attributed under an any-overlap rule (AdministrationProfilesData.swift:16-18), and the Chronology sorts by a padded dateISO (CollectionGeneratedBlocks.swift:360-363; IndexingPipeline.swift:8435-8449).
Counting by the date attributes alone, I find 26 documents dated 1945-04-12 and 17 dated 1974-08-09, as EDI does. EDI's 122 for 1865-04-15 come from datelines; by attributes I find 14. Neither §8.2's A11 nor L54 has a rule for a shared day or for a range that straddles a change.
Where it is answered: L54's brief. I agree.
Duplicates: none.

The reviewers' starting-point lines in my files

ENG:
- "A section's headnote default: NEEDS THE OWNER on DATA's evidence (which field)." The plan gives this to the review ("CR settles which", plan:432). On the evidence the review holds (DATA-3), it is the review's to settle and the owner's to accept at C2. It is not an open question to put to the owner.
- "10's join is SETTLED BY THE TEXT (a page target already reaches the See also line and is dropped as no member …)." This is wrong. A same-volume page target reaches the line as a document id, rewritten at index time (IndexingPipeline.swift:10697-10717), and it matches whenever that document is in the collection; since v71, most targets in other volumes do the same. The text (§8.1, item 10) says the opposite, so the text does not settle it. What still reaches the line as a page is the 19,186 rows from other volumes left on their page, and since decision 190 L51 can read cited_page_id and page_resolution for them.
- "A8 is SETTLED BY THE TEXT." Not for its key: grouping by the bare class merges two different files across the renumbering of 1950 (EDI-9).

EDI:
- "A2 … NEEDS THE OWNER for the 809 rows." Answered since by decision 189, on the v76 branch at 254283cc.
- "A4 and a page that holds several documents: NEEDS THE OWNER before L26 lands." Answered since by decision 190 (20eabba9). The question was also wider than a page several documents begin on: every edge resolved from a page had lost its page, one-document pages included.
- The sign for an omission. "[omission]" and its variants are bracketed, and the design and L46 already rule brackets out for the sign (§3.1; plan:697). The collision is with whichever word is chosen, which is the owner's wording, so the line overstates. I did not recount the ellipsis figure.

Errors in the design or the plan found on the way
- Plan §1c, third departure (plan:443): "lane 4 then adds its new settings to the refresh list L36 completes". Lane 4 is L44, which stores nothing (plan:271); the new settings are L43's.
- Design §8.1, item 10 (787); §8.2, A4 (892); plan, L51 (734): "a reference to a printed page is stored under its page (CrossReferenceStore.swift:757-759)". IndexingPipeline.swift:10697-10717 rewrites the target. The cited lines (at efd73ec) are relatedByCitation's doc comment.
- Plan, L51 (735): "for a collection of them the line prints more than it did". For same-volume references it already prints them (outboundEdges). It prints more only for the rows from other volumes that v71 left on their page.
- Design §8.2, A1's table (836): A4 and the See also line fill from "a reference to a document (xrefDocuments)", with "299, of which 271 refer by page". They also fill from page references and from references to other volumes (xrefPages, xrefVolumes; VolumeAnnotations.swift:62-65).
- Design §8.2, A1's first bullet (841): "no document cites another by document … the See also line is empty". That is true of the eight telegrams, but not for the reason given: frus1946v06's 229 same-volume page references are stored as document edges (d470 to d463, d486 to d530).
- Design §9 (1000) and plan, L50 (731): "two fixture data sources … which both must answer". Eight types conform (ENG-5).
- Design §9 (991) and plan, L44 (682): "CollectionTests.swift:3450-3565 goes on holding it". The test runs over allCases (:3561-3571) and fails from L43 on.
- Design §11, the row "ENG-5, FMT-6 … Named | §9, §7.4" (1113): §9 does not name the outline rows that §3.4 (329) changes.
- Design §3.3 (312), §3.4 (334) and §3.6 (374): the rules for the volume's own number are false (EDI-5).
- Design §8.2, A3 (883) and plan, L53 (750): "In the volumes before 1955 they are the only pointers there are". 2,556 body footnotes before 1955 name a lot or a presidential library. §11 (1145), "It lists the ones a footnote gives a file for", is false from 1963 on.
- Design §3.4, line 325 against line 328 (EDI-8).
- Design §3.6 (368): "only if it has something to say" contradicts the seam's contract that a block never renders empty (CollectionGeneratedBlocks.swift:114-115, :184), and the design does not acknowledge it.
- Design §8.1, item 2 (779): "with a deploy of its own", against §7.1 (721): "One CloudKit promotion". DATA-9 names this.
- Design §5.4's iPad row (599): "settings as sheets, as now", against §5.3 (587) and §8.1's item 13, which was taken. INT-4 names this.
- Design §4.4 (507) has the plan read the headnote count as step 1's cards, where plan §1c (425) gives it to the sheet's sentence. INT-3 names this.

Not checked
- No index, app, simulator or device. So not checked: the edges stored for EDI-2 (the code is unambiguous), what VoiceOver announces for ENG-3, the tokenizer's count for ENG-8, and the preview's behaviour for ENG-4.
- The web edition's conformers of the blocks' data source and of the content data source (ENG-5).
- The boards. No ENG or EDI finding cites one.
- Some TEI figures were recounted only in part:
  - EDI-3's 3,339 subject-numeric footnotes for 1964–68: my narrow pattern finds 985, and I read samples of EDI's broader pattern but did not recount it.
  - EDI-10's 243, which come from datelines: I counted by the date attributes only.
  - EDI-6's 8,116: my exact-heading count is 7,639, and my count of editorial-note divisions is 8,468.
  - EDI-5's 1952–54 split between "No. N" and "N.": I checked only the totals.
  - The ellipsis figure and the "not printed" figures in EDI's report.
- On the v76 branch I read decisions 188 to 190 in its plan of record and its commit messages, and the new UPDATE lines by grep. I did not read the code behind its new columns.
