Reviewer FMT: the .fruscollection file and whatever else carries a collection. Read from REPO at 0fa40e16 (v2 b3acd7ad plus the two planning commits), 1.0 (1861) read at the tag 1.0-release (08e8bac8), index version 76 at claude/plan-of-record-pr2011-2cc493, and the public TEI at corpus 216cdb764. Nothing was built or run. Scripts are under SCRATCH/work-FMT/.

ID: FMT-1
Severity: S2
Claim: The collection file cannot carry a headnote that is switched Off, so under decision 166 (the headnote's text in the file, always) a recipient's copy prints a headnote its author switched off in any collection whose Headnotes default is on; and neither §7.4 nor L43's brief gives a section's headnote default a file key or a write rule that could carry Off either.
What a person meets: On a Mac, an author sets twelve telegrams to Full text with your annotations, which turns the collection's Headnotes default on. They write headnotes for nine. They switch the other three Off so that no export prints the placeholder, and one of the three keeps a draft they decided against. They send the .fruscollection to a colleague on 1.1. In the colleague's copy the three are Default, so On. The abandoned draft prints as a headnote, because its text now travels, and the other two print a stand-in summary of the colleague's own, or the placeholder as the code stands. A section the author sets Off under L43 arrives the same way. A colleague on 1.0 gets a stand-in or the placeholder for all three (FMT-2).
Evidence:
- The writer, FRUSCoreKit/Collections/NativeCollectionFormat.swift:517-520, says Default and Off "both omit the key". Only `includeHeadnote: entry.includeHeadnote == true ? true : nil` is written. `headnoteSummaryId` is written whatever the switch (:521), and the collection's default travels when it is on (:489).
- The reader turns an absent key into nil, Default (:757-760). Default inherits the collection's value (CollectionContentAssembly.swift:1086).
- A test pins the omission: FRUSExplorerTests/CollectionTests.swift:3939-3942 (`d.includeHeadnote = false` gives `formatVersion == 1`). All of these lines are the same at 1.0-release.
- Two of the six recipes turn the default on: `headnotes: true` in fullTextWithAnnotations and everythingIncluded (CollectionExporter.swift:230-232, :246-248).
- Design §7.4 (:741) reads "A headnote travels as its text, with who wrote it, and not as a draft's id ... decision 166: always". §7.4 gives no rule for Off, and says "Writing the minimum stays" (:739).
- A section, today: the writer writes no `includeHeadnote` for a heading (the heading case of makeFile, NativeCollectionFormat.swift:533-552), and the reader drops one (:759).
- §7.4's new keys (:738) are lane 3's four, and neither candidate 6 field is among them. L43's brief (Plan-Of-Record-2026-11-25.md:661, :664) says only "new optional keys, each written only where it is set".
- If the default rides `includeHeadnote` (plan §1c, :430-432), every heading made before the Composer redesign holds `false` (Collection.swift:570-576). A rule that writes Off would send each of those as a section switched off.
Refutation: A rule in §7.4, §8.1, Q10 or L43's brief that writes Off, or that leaves out the draft of an entry that is off, would refute this. I searched all four and found none.
Where it is answered: L43's brief, for the keys and rules of the headnote and of the section default. The owner, for whether decision 166's "always" covers an entry that is switched off.
Direction: Write Off as Off for documents and for sections, and decide whether an Off entry's draft travels at all. Settle the section default's key together with what a pre-Composer heading's `false` means.

ID: FMT-2
Severity: S2
Claim: §7.4's "A 1.0 app that opens the new file shows no headnote. That is what a recipient on another account sees today" is false. The new file still says a headnote is on and carries no id that resolves. Given that, 1.0 prints in all three formats either another stored summary of the document under "Headnote" or the sentence "No stored summary for this document — generate one in the document view to fill this headnote." On the author's own 1.0 devices, where 1.0's own file finds the draft by its id, every headnote the author wrote is replaced this way.
What a person meets: The author's iPad, still on 1.0 (1861), opens the 1.1 file from Files and exports a PDF for a seminar. Every headnote the author wrote is gone. In its place, under "Headnote", is the AI summary the author once made of that document in the reader, captioned "AI-generated summary · Apple Intelligence (on-device)", or an instruction to generate one. A colleague on 1.0 gets the same, which is also what a 1.0 recipient gets today. Neither sees "no headnote".
Evidence:
- The new writer drops the id (§7.4, :741-744). Nothing in the design stops it writing the two 1.0 keys that request a headnote (NativeCollectionFormat.swift:489, :520).
- 1.0's resolve:
  - An effective headnote looks up `headnoteText` (CollectionContentAssembly.swift:1086-1091).
  - With no id that resolves, it takes "the document's summary for preferredPromptId ... else any non-empty stored summary" (:1348-1382), headnote drafts left out (:1372-1376).
  - The format's own comment says the same: "the resolver falls back to any stored summary (or the placeholder)" (NativeCollectionFormat.swift:227-231).
- With nothing found, each exporter prints the placeholder: CollectionItemHTMLRenderer.swift:317-319 and :463-467; DocxCollectionExporter.swift:2068-2074; PDFCollectionExporter.swift:923-929. All three are the same at 1.0-release.
- §4.4 (:504) and §11's row H11 (:1095) say "No placeholder line is printed in an exported file". All three exporters print one today, and no row's brief removes it: plan §1c has no "placeholder".
Refutation: A 1.0 path that prints nothing for a requested headnote with no id would refute this. There is none in the assembly or in the three exporters. NEEDS A RUN to see it in 1861: §12's hand-made file (:1158), with "includeHeadnote": true and no id, imported and exported as a PDF.
Where it is answered: §7.4's text and L43's brief. The placeholder belongs in L34's brief or L44's.
Direction: State what 1.0 prints. To make "no headnote" true, write the headnote's state under a key 1.0 does not read, and stop writing the two keys it does read.

ID: FMT-3
Severity: S2
Claim: L46's brief says both "Nothing new is stored in CloudKit" and "The passages travel in the collection file as text", but no field, record or rule can keep passages that arrive as text, and once kept as frozen text they would print as the volume's own words with none of the check an excerpt gets.
What a person meets: A teacher on 1.1 abridges six telegrams to Selected passages, which is "what a course reader does most" (§8.1 item 1), and sends the class the file. A student on 1.1 imports it. The passages are in the file, but nothing in the student's store can hold them. So the student's copy prints, at that depth, the student's own highlights of those telegrams, or nothing: the imported entry's list of highlights is empty, and empty means all of the reader's own. If L46 adds a place to keep them, they print under the volume's heading as the document's text, and nothing reads them against the volume. An excerpt is read against it every time the export sheet opens. A file re-exported from 1.0 keeps the depth and drops the passages.
Evidence:
- L46's brief is plan :693-699. Its row in "What each row touches" (plan :273) reads "A new value of a stored string, so no CloudKit change. The collection file carries the passages as text". It names NativeCollectionFormat.swift, and neither Models/Collection.swift nor NativeCollectionFormat+App.swift, where an import is inserted (:104-150).
- Design §8.1 item 1 (:778) says the passages travel "as a quoted passage does, since highlights do not travel".
- No existing field can hold them:
  - `CollectionEntry.text` is "nil for document entries" (Collection.swift:663-667).
  - The import gives every entry an empty highlight list (NativeCollectionFormat.swift:755), which means "all-their-highlights" (:55-58).
  - A highlight needs offsets and a rendering version (DocumentHighlight.swift:81-110), and "as text" sends neither.
- A quoted passage is checked: the sheet runs ExcerptVerifier over every excerpt entry when it opens (CollectionExportSheet.swift:514-547), and the Guide promises the check "before every export and again when a corrected volume arrives" (Agentic-Analysis-Guide.md:2862). L46's brief names no check.
- 1.0 keeps an unknown depth string verbatim through import and re-export (NativeCollectionFormat.swift:478, :510, :749, :779; NativeCollectionFormat+App.swift:108, :136). It drops keys it does not know (Guide :2976-2978).
Refutation: A field or record named for the passages, or a rule that makes them the recipient's highlights, would refute this. There is none in §7, §8.1, L46's brief or its row of files.
Where it is answered: L46's brief.
Direction: Say where an imported passage is kept: a stored field, which joins the one promotion and version 8, or highlights made in the recipient's library, with anchors in the file. Run the excerpt check over passages that came from a file.

ID: FMT-4
Severity: S2
Claim: §7.4 sends a headnote "as its text, with who wrote it", but the app's headnote is a GeneratedSummary, and the design names neither key. Its text is a JSON object when a structured prompt drafted it, and its "who" has three values worded for the device's own user. Carried as written, the recipient's copy prints such a headnote as raw JSON unless its format travels too. It labels the sender's words "Yours" in the inspector and the Note on the Text credits them to the compiler. The export prints "edited by you" for the sender's edit. An outside writer, the Guide's reader, has no true value to give.
What a person meets:
- (a) A historian on 1.1 imports a colleague's collection.
  - The inspector's chip reads "Yours" on the headnotes the colleague wrote, and the historian's PDF prints them with no caption.
  - §3.6's Note on the Text lists them among "which headnotes the compiler wrote".
  - One the colleague edited from an AI draft prints "AI-generated summary, edited by you".
  - One the colleague's model drafted from a structured prompt prints as {"KeyParticipants": "...", ...} if only its text travels.
- (b) An agent writing a file by the Agentic Analysis Guide.
  - §15.1a's first limit, "Headnotes cannot be supplied", stops being true.
  - The agent's only choices are userWritten, which shows its words as the historian's own with no caption, or aiGenerated, which captions them "Apple Intelligence (on-device)".
Evidence:
- SummaryAuthorship has three cases (FRUSCoreKit/Models/SummaryTypes.swift:85-92).
- The export captions are CollectionExporter.swift:1127-1137: .aiEdited reads "AI-generated summary, edited by you", and .userWritten has none. The chip is CollectionEntryInspector.swift:1033-1045 ("Yours").
- A structured summary "stores a JSON object in GeneratedSummary.responseText" (StructuredSummaryDisplay.swift:15-16). It is shown as fields only when its format is .structured (:67-71), and a summary made without a format is .general (GeneratedSummary.swift:92, :197).
- The design: §7.4 (:741-742) and Q10 (:1058). §3.6 (:364) has the Note say "which headnotes the compiler wrote". §3.7 (:380) has the statement of sources say "headnotes the compiler wrote".
- The manuals say "the attribution follows the true author" (iOS-User-Manual.md:1190).
- The Guide's limits: limit 1 is Agentic-Analysis-Guide.md:2907-2908, and limit 2 is the rule that an agent's text opens with an attribution line (:2909-2911). §7.4 owes "the Guide's §15 (its two examples, its checker, its account of versions)" (:748), and does not name §15.1a's limits.
- The sheet goes on saying "Your research notes stay private unless you include them above" (CollectionExportSheet.swift:598), while a headnote now always leaves.
Refutation: A key in §7.4 for the headnote's format, or for a writer other than "you" and the model, would refute this. There is none.
Where it is answered: L43's brief. The owner, for Q10's "who wrote it": the AI-or-person flag, or a person.
Direction: Name the headnote's keys (text, format, authorship) and what an import makes of a sender's authorship. Bring §15.1a's limits and the sheet's line to the new rule.

ID: FMT-5
Severity: S2
Claim: Decision 174's link needs anchors the web page does not have. No generated row carries an id. A block can be placed twice. 6,592 term ids recur across volumes, and in 933 of them two volumes that link the term give definitions sharing no word. L52's brief does not say how a term's link names its row.
What a person meets:
- A reader of the web page of a collection spanning 1946 to 1948, with Abbreviations & Terms. In frus1946v01 "ADA" is the Atomic Development Authority (50 links); in frus1948v09 it is "Area Division IV (American Republics), in the Office of Information and Educational Exchange". Both volumes give it the id t_ADA1.
- If a row's anchor is the TEI's id, the page holds two elements with one id, and a click on either "ADA" lands on the first. If rows are one per term, one row holds two definitions.
- With the block placed twice, every id is doubled: #2004's defect, inside a block.
- A person's name or a cross-reference in the same paragraph still opens the app to a refusal, which is the reason §8.2 gives for changing the term's link.
Evidence:
- Rows have no id:
  - CollectionGeneratedRow is a text, a secondary text, a URL and an indent (CollectionExporter.swift:1196-1218).
  - The web page writes a block as <section class="generated-block ..."> and each row as <li class="generated-row...">, with no id on either (CollectionItemHTMLRenderer.swift:199-223).
  - The contents list names a block by its title, unlinked (:580-582).
  - L52's files (plan :279) do not include CollectionExporter.swift.
- Twice: the Apparatus menu adds a block on every choice, with no check for one already there (CollectionEditorView.swift:1349-1356, :1911-1927). The design says so too (§4.3, :491).
- The TEI count:
  - Method: work-FMT/gloss_targets2.py and work-FMT/id_collisions.py, stdlib ElementTree, over the 553 manifest volumes. Term ids are the <term xml:id> under <text>: 66,426 terms in 313 volumes.
  - 6,592 ids recur in more than one volume, 4,081 of them with differing words.
  - 933 recur where two volumes that link the id give definitions sharing no word of three or more letters. That test is crude: it also separates "air gram" from "Airgram".
  - Re-read in the files: t_ADA1 (frus1946v01:11524, frus1948v09:6402); t_CIA1 (frus1946v08:8383, "Constitution Investigation Association, Japan", 12 links; frus1948v01p1:5107, "Central Intelligence Agency"); t_NATO1 (frus1943:11719, "North African Theater of Operations"; frus1949v04:7211, "North Atlantic Treaty (Organization)", 49 links).
- The other links in the page:
  - They stay frusexplorer://person/ and frusexplorer://doc/ (FRUSRenderNodeHTMLSerializer.swift:894-897, :946).
  - The app refuses them when they arrive from outside (AppActivityTypes.swift:39-51).
  - The design's reason for changing the term's link is that same refusal (§8.2, :861).
Refutation: A rule for the anchor in §8.2, in decision 174 or in L52's brief would refute this. There is none. The case where every link has a row does hold (Attacked and held, 3).
Where it is answered: L52's brief.
Direction: Key each row's anchor by block instance, volume and term id, and link a term only where its row exists. Say whether the person and cross-reference links in the web page stay frusexplorer://.

ID: FMT-6
Severity: S3
Claim: L55's brief and design §9 put A12's table in the web page and Word only. So the PDF keeps printing the word cloud as an image with no text, which is the disagreement between formats that lane 2 and the parity suite exist to end. The plan's own table of files puts the PDF exporter in L55, and design §8.2 says a block that needs columns changes all three exporters.
What a person meets: The reader of a collection's PDF with its word cloud on; the Summaries and Full text with everything sets turn it on. The web page and the Word file print under the cloud each term with its count, and the distinctive terms with their caveats. The PDF prints the cloud alone, on a page of its own. From L48 it is a tagged PDF whose figure has no text to give.
Evidence:
- L55's brief (plan :762) puts the table "in the web page and in Word", and it is "Held by a kit test over the HTML and the Word package" (:766). The design's check (:1022) names the same two formats.
- L55's row of files (plan :282) lists Collections/PDFCollectionExporter.swift. §8.2 (:804) says "A block that needs columns would change all three exporters."
- The PDF's cloud comes from a different path:
  - It calls WordCloudExporter.collectionCloudImage(texts:title:)?.cgImage (PDFCollectionExporter.swift:208-212), which returns an image and a PNG and drops the terms (WordCloudExport.swift:153-157).
  - The brief extends CollectionWordCloud (plan :763; CollectionExporter.swift:1696-1715), which the PDF does not use.
  - The PDF draws the image alone (PDFCollectionExporter.swift:251-257, :533-554). Its tables are rows of cells joined by " | " (:1118-1143), so it has no table to draw into.
- The parity suite exists because "DOCX silently dropped the word cloud" (CollectionTests.swift:5490-5498). Its wordCloudReachesEveryFormat (:5576) holds all three formats to the cloud.
Refutation: A sentence in L55 or §8.2 that leaves the PDF out on purpose, with its reason, would refute this. There is none.
Where it is answered: L55's brief.
Direction: Say whether the PDF prints the table, and how, since its tables are joined lines; or say why it does not. Then hold the three formats to that in the parity suite.

ID: FMT-7
Severity: S3
Claim: §7.2's "nothing 1861 prints is false" and §7.4's "shows 1.0's layout" leave out that 1.0's layout for a titled document is #1998. A 1.0 reader of a 1.1 file prints each of the author's titles alone, as the document's heading and its contents row. At Summary and Index depth there is no citation and no heading of the volume's beside it, so the marking the owner asked for never reaches a reader on 1.0.
What a person meets: A 1.1 author titles six telegrams (The Long Telegram among them) under Citations with your notes and shares the file. On 1.1 each row reads the title, with the citation as its second line (§3.4). A colleague on 1.0 exports it. The contents list is six titles of the author's own. Each document is its title linked to history.state.gov, with no citation and no heading of the volume's.
Evidence:
- At 1.0-release, exportHeading and tocLabel put a title in place of the citation and of the heading (CollectionExporter.swift:747-765).
- The page's heading and contents rows read them (CollectionItemHTMLRenderer.swift:296-309, :566), and Index depth prints no body (:373-374).
- The design: §2.8 row 7 (#1998), §3.4 (:325-329), §7.2 (:725), §7.4 (:745). The plan says the same at §1c (:435).
- The file keeps writing titleOverride, a 1.0 key (NativeCollectionFormat.swift:514; design §7.1, :709).
Refutation: A 1.0 path that prints the citation beside a title at Index depth would refute this. There is none.
Where it is answered: The text of §7.2 and §7.4, or L43's brief if the writer is to change.
Direction: State the cost. Or write titleOverride only where 1.0 also prints the volume's words, and carry the title under a new key everywhere else.

ID: FMT-8
Severity: S3
Claim: Decision 165 gives a citation record's title the new reading, but each BibTeX, RIS and Zotero record also carries a "Document date:" line. That line comes from the old top-level reading, which finds no dateline for 291,438 of the 314,616 documents. So after lane 2 either most records gain a line nobody announced, or the records keep a second reading of the dateline beside the contents rows' new one.
What a person meets: A researcher re-sends a collection of 1961–63 documents to Zotero after the update. Either items that had no date line now carry "Document date: Washington, October 22, 1962" in Extra, and every record's note changes in a .bib regenerated for a paper. Or the items still carry none, while the same export's contents rows print the dateline (#1994's fix).
Evidence:
- The record's fields: ZoteroJSONExporter.swift:163-168 (Extra); BibtexExporter.swift:131-135 (note); RISExporter.swift:109-112 (M2).
- The item is built from docMeta (CollectionContentAssembly.swift:986, :992-994, :1124-1132). Its dateline comes from renderModelHeadAndDateline, which reads top-level nodes only (:1467-1481). An opener's dateline sits inside .letterOpener (FRUSRenderNode.swift:65, :68).
- §3.4 (:331-341) has the one reading return the dateline "from the top level, the opener or the closer". Of the records it says only "Its title takes the new reading". L34's brief (plan :638) says the same, and §11 (:1114) counts the second review's FMT-8 as answered by Q9.
- The TEI count, work-FMT/datelines.py, stdlib ElementTree over the 553 manifest volumes:
  - 314,616 documents.
  - A dateline is a direct child in 14,882.
  - Only inside an opener in 286,178.
  - Only inside a closer in 5,260.
  - No dateline outside a note in 8,296.
Refutation: A statement in §3.4, §11, Q9 or L34 that the records' date line keeps the old reading or takes the new one would refute this. There is none.
Where it is answered: L34's brief, or the owner: whether Q9's "yes" covers the date line.
Direction: Decide in L34 whether the records' date line takes the new reading, and list the change among what L34 changes in what a send or a file carries.

ID: FMT-9
Severity: S3
Claim: Decision 166's reason, that a headnote "was written for the collection, as a note block was", reaches the collection file but not the research data export. That export carries a collection's entries and prose whole, but no headnote unless Include AI-Generated Summaries is on. So a library restored from a JSON made with the defaults loses every headnote its author wrote.
What a person meets: An author who wrote 30 headnotes runs Export as JSON with its defaults, then imports the file on a Mac outside iCloud, or after a rebuilt store. Every collection, section and prose block comes back. Every headnote prints a stand-in summary or the placeholder (FMT-2), because the drafts were left out with the AI summaries.
Evidence:
- The export writes summaries only when includeGeneratedSummaries is on (FRUSExplorer/Export/ResearchDataExporter.swift:96-98), and every GeneratedSummary counts as one, headnote drafts included.
- The entries carry headnoteSummaryId (Collection.swift:1119-1120), which a restore cannot resolve.
- The manuals say both that collections keep "their whole composition" and that "AI summaries are excluded from the JSON by default ... the model, the model then edited by you, or you" (macOS-User-Manual.md:1309; iOS-User-Manual.md:1523).
- Q10 (:1058) gives the reason quoted above. §7.5 (:752) gives version 8 the new properties and the saved templates, and says nothing of headnotes.
Refutation: A path in makeEnvelope that writes a collection's headnote drafts whatever the switch would refute this. There is none.
Where it is answered: L43's brief, which owns the research export's version 8.
Direction: Carry a collection's headnote drafts with its entries in version 8, whatever the AI-summaries switch, as decision 166 carries them in the file.

The starting points in my scope
- A2 beyond the index, its block, rows and decision 174's links: A ROW'S BRIEF MUST SAY IT. L52 must give the anchor's key (block instance, volume, term id), make a term a link only where its row exists, add the new field to CollectionGeneratedRow, and say what becomes of the page's other frusexplorer:// links (FMT-5).
- The three things the withdrawn §4.4 said, where the file is concerned: A ROW'S BRIEF MUST SAY IT. L34 or L44 must say that a requested headnote with no stored text prints nothing in an exported file. All three exporters print the placeholder today (FMT-2). Where the template's needs and the count are said is INT's.
- A section's headnote default: A ROW'S BRIEF MUST SAY IT. L43 must give its file key and a write rule that carries Off, after settling what a pre-Composer heading's false means (FMT-1).
- The taken candidates of §8.1, for the file:
  - 1, selected passages: A ROW'S BRIEF MUST SAY IT. L46 must say where the passages are kept and that they are checked (FMT-3).
  - 2, Save as Template: SETTLED BY THE TEXT. The file carries the settings and not the template (§8.1 item 2; L47).
  - 6, See also at the collection: A ROW'S BRIEF MUST SAY IT. L43 must name its composition key, and say that an absent key reads as off, which is 1.0's behaviour.
  - 7, the page: SETTLED BY L48's brief, which names the file's keys if the choice is kept on the collection. Where it is kept is the owner's call, and the brief already puts that question.
  - 9 (Same settings as…), 10 (See also by page), 12 (a tagged PDF) and 13 (the drawn opening and the iPad column): SETTLED. None stores anything new, so nothing new travels.
  - 11, the short form: A ROW'S BRIEF MUST SAY IT. If the choice is kept on the collection, L49 must name a file key. Its brief names only the promotion and version 8 (plan :722).
- A8, A10 and A11: SETTLED for the file. Only a block's type travels, and its rows are resolved again at the recipient's (NativeCollectionFormat.swift:59-66).
- A12: A ROW'S BRIEF MUST SAY IT. L55 must say what the PDF prints (FMT-6).
- Step 2's 17 controls: not in my scope.

Attacked and held
- A new block type in 1.0: the Note on the Text and A2 to A4 are kept as inert strings on import, skipped at resolve and kept again on re-export. The outline names each "Unsupported block" with "Update FRUS Explorer to resolve this block." (NativeCollectionFormat.swift:741-746; CollectionContentAssembly.swift:962-965; CollectionEntryRows.swift:841-858).
- The file's version stays 2 with a floor of 1. 1.0's gate is minimumReaderVersion ?? formatVersion against 2 (NativeCollectionFormat.swift:439-442), and the decoder ignores keys it does not know. So a file of the new version opens in 1861, and the Guide's checker (v > 2, Agentic-Analysis-Guide.md:2933-2936) passes it. The headnote is the exception (FMT-2).
- Every term link can have a row. 1,301,141 of the 1,301,142 gloss targets inside documents name a term their own volume defines; the one exception is the malformed "_#t_PNE_1" in frus1977-80v26 d190 (work-FMT/gloss_targets2.py). A collection's converter has no abbrLookup (CollectionContentAssembly.swift:887-890), so the page links exactly the <gloss target>s that version 76 walks.
- BibTeX keys stay {volumeId}_{documentId} (BibTeXCollectionExporter.swift:21-22), so decision 165's titles break no LaTeX \cite. No citation style reaches a record, since makeItem calls no formatter (ZoteroJSONExporter.swift:150-185).
- A term's in-page link works in the preview as in the file. The preview allows every navigation except an activated http(s) link (CollectionPreviewView.swift:838-851).

Not read
- The web edition's repository.
- Version 76 beyond the terms and term_mentions tables and the .gloss case of the walk.
- CollectionGeneratedBlocks.swift and CollectionContentResolver.swift.
- The PDF and Word exporters beyond the word cloud, tables and headnote.
- The research import beyond its rules.
- The boards, which I only searched.
- No count was made of how many documents decision 165's titles change.
- Nothing was built or run. The 1.0 behaviour in FMT-2 and FMT-7 is read from the code at 1.0-release, and was not seen in 1861.

Outside my scope
- SectionSheet.dc.html:50 says "A section has no headnote setting, as in 1.0", which decision 164's candidate 6 made untrue. That is a fourth superseded board line beyond the brief's three (INT).
- L51 puts a new block's "title among the collection's words" (plan :738). A2, A3, A4 and the Note would then add up to four labels to §5.2's ten, so §5.5's Wording count of 10, and the 51, may be short (INT).
- L54's files include no exporter (plan :281). A11's "heading where the presidency changes" can then only be a CollectionGeneratedRow: an <li> in the web page and a plain paragraph in Word, with no heading semantics (A11Y, ENG).
