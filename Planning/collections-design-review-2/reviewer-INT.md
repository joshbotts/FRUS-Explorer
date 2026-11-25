ID: INT-1
Severity: S2
Claim: Counted the way §2.4 counts today's 24, the collection's settings hold at least 41 controls with Customize open, not the 31 that §1 and §5.5 give, and the counts for a document, a section and the export sheet each leave out controls the record's own rules put there.
What a person meets: Any platform. Customize opens on nine rows under Each document, two under Lists and citations, five under Back matter, and a Wording row that opens eleven text fields: 27 more than the 14 in view, against 24 in all today. On the Mac board three of those rows also carry "Use the template's" and one "2 documents differ". The export sheet is counted at 12; More formats holds three more and .fruscollection a switch of its own.
Evidence:
- /home/user/FRUS-Explorer/Planning/Collections-Customization-Design-2026-11-25.md §5.5: "14 in view; 31 with Customize open … Six new settings: Opening, Numbering, See also for the collection, the citation style, the Note on the Text, the wording table"; "Counted from §5.2's own lists, the way §2.4 counts today's". §1: "Opened fully they are 31, seven more than today".
- §5.2: the wording table is "the words the app prints, each with a field: Contents, Headnote, Summary, Research Note, See also, Printed heading, and the five apparatus titles". That is eleven fields, and /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionA.dc.html:256 draws the row as "11 labels".
- §2.4 counts fields one by one: its 24 holds "8 name and title page" (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEditorView.swift:811-813, :1044-1102). §5.5 counts the title page's five fields the same way and the eleven labels as one. My count from §5.2: 14 + 9 (seven settings, the summary prompt, Numbering) + 2 + 5 + 11 = 41, seventeen more than today.
- The first review made this point of the first form ("47 with the title page's fields and the labels counted singly", /home/user/FRUS-Explorer/Planning/Collections-Design-Adversarial-Review-2026-11-25.md:98). §11 answers G5 with "Counted the same way".
- Counted at no scope: a way back on each changed row and a way there on each row set elsewhere (§4.1 rules 3, 4), a count that "opens the list" (§4.2), and "Use the template's" in Review (§4.3). OptionA.dc.html:240-242 draws four of these. 1.0's picker holds Default inside one control (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryInspector.swift:657-680).
- Export sheet: §5.5 "12: Seven looks, three formats, More formats, the Zotero row". §5.1: "More formats opens BibTeX, RIS and .fruscollection". Today's sheet also shows "Include my research notes" for .fruscollection (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExportSheet.swift:593-596), which §5.1 does not list. That is 16 against today's 7 (:103, :138).
- A template tap opens one more surface. By §4.3's table and the shipped recipes (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:226-250), leaving Full text as printed for any other template lists six to nine lines, each with a tick.
- Today's 24, 9, 6 + 1 and 7 hold on my recount (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionCompositionRows.swift:113-204; CollectionEntryInspector.swift:390-397, :687-737, :765-782, :937-941; /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryRows.swift:177-185).
Refutation: A rule by which eleven text fields are one control while five are five. §2.4 and §5.5 give none. Checked.
Direction: Put the figure counted field by field, with each row's own controls, beside 24 before Q1 is answered.

ID: INT-2
Severity: S2
Claim: For one document the design adds two rows to what 1.0's inspector offers (Opening and Your date line), Opening goes inert once a title is given, and three of §2.2's five "cannot change" items stay unchangeable.
What a person meets: The owner opens document 475's settings. Eight of its ten rows are 1.0's under new names: title, text, summary prompt, the two note switches as one choice, headnote, notes, highlights, See also. Opening is dimmed because 475 has a title. What they can now do to this document that 1.0 could not is type a date line.
Evidence:
- The record's title: "fine-tune every part of a document". Its ask 2: "every part of a document adjustable, in a simpler interface than today's".
- §2.2, "What the author cannot change": "which of the two headings leads; anything about a date; the address line; any label …; the order of the parts".
- §5.5: "A document: 9 … 10 … Two switches became one choice; Opening and the date line are new". 1.0's nine: CollectionEntryInspector.swift:390-397, :691-737, :765-782, :937-941.
- §3.3: "Your title, which leads wherever one is given, under either setting". /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionB.dc.html:162 and PartsPhone.dc.html:99 (same folder) draw Opening dimmed with "Your title leads".
- §3.2: the address "rides with" the citation; the printed heading "prints wherever the text prints"; "Three things the first form offered are gone".
- §5.2: the words are "the collection's", none for one document, and "None is a word of the volume's". The order of parts is candidate 3 of §8.
- Q7 prints the date line "under the title". §3.2 lets it be "given or not, for one document", and the boards offer the field apart from the title (OptionB.dc.html:102-106). What it does on a document with no title is unstated.
Refutation: A row of §5.2's document list that changes the address line, the order, or a label for one document. None; Q2, Q7 and §8 ask about parts of this, and no section sets the tally against §2.2.
Direction: Set §5.2's document list against §2.2's five items in the record, and name the §8 candidate that would close each.

ID: INT-3
Severity: S2
Claim: The export sheet offers seven looks above every format, but for BibTeX and RIS a look decides one thing only (whether research notes are written into the file), for the Zotero send nothing, and for .fruscollection the record gives no rule; "What will print" describes a rendering none of the four makes.
What a person meets: iPhone. Their collection has Your notes on. They tap Full text as printed, then More formats, BibTeX, Export BibTeX. The .bib carries no notes, because that recipe turns notes off. The sentence had promised "the full text of each document under its printed heading". With Citations with archival sources (notes off) and Send to Zotero Library, the notes are sent anyway. With any look and .fruscollection, the file either carries the template's settings to the recipient or ignores the checked row.
Evidence:
- §5.1: Look, then Format, then "What will print, in a sentence". §4.4: "takes the template as it is for what a recipe has a say in". No sentence in §4.4, §5.1, §5.5, §7.6 or lane 1 makes the look depend on the format (searched).
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/BibTeXCollectionExporter.swift:63 `if !options.includeNotes { item.notes = nil }`; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/ZoteroCollectionExporter.swift:65-69. Recipes: notes false for Full text as printed and Citations with archival sources, true for the other four (CollectionExporter.swift:227-247).
- The Web-API send takes each document's item with its notes and reads no option (CollectionExportSheet.swift:734-735; caption :662-663 "carries your tags & research notes").
- .fruscollection "Bypasses document resolution entirely — the native format carries the collection's source" (CollectionExportSheet.swift:604-608).
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:77-90: the sentence depends on the look alone. :54 files Zotero under More formats, where §5.1 says "The Zotero row stays as it is". :95-99: the control has three segments, so a remembered BibTeX has no segment to show as chosen.
- By the board's own sizes (header 57, pinned bar 75, 712 px of scroll on the 844 board; rows at their stated minimum of 56) the sentence starts no higher than 677. At most its label and one line are in view when a look is tapped. A sketch; NEEDS A RUN.
Refutation: A rule per format for what a look does. Searched; none.
Direction: Say per format what a look changes, and show the look list only where it applies.

ID: INT-4
Severity: S2
Claim: "Changed for this document", "N documents differ" and "N documents keep their own settings" will name documents whose author changed nothing, because the record has no rule for a held key equal to what it would inherit, while the upgrade turns every explicit 1.0 override into a held key.
What a person meets: The owner, with a reader whose entries predate the headnote cascade. After the upgrade each document's Headnote row reads "Changed for this document", though nobody touched it. They export once under Full text with your annotations: none of those documents takes a headnote, and the sheet says they keep their own settings. Clearing them is one "Use the collection's" per document. On the iPhone board that way back is words inside the switch itself, so tapping it flips the switch. Any user: a switch turned off and on again either stays "Changed" at the inherited value, or silently stops being a pin.
Evidence:
- /home/user/FRUS-Explorer/FRUSExplorer/Models/Collection.swift:570-577: `includeHeadnote` "Was a non-optional Bool … Existing entries migrate to their stored value (explicit on/off)". This is the model's comment; not checked on a store.
- §7.4: "the eight override fields; Default | the keys the entry changes; a Default is a key not held". §4.4: a look "keeps what the author set for particular sections and documents". §4.1 rule 3: the way back is per row. §8 item 8 copies settings; it clears none.
- 1.0 also writes an override as a side effect: unselecting the last note or highlight (CollectionEntryInspector.swift:881-883, :833-835).
- §4.2 gives one example of the count and does not say whether it counts values or keys. §4.3 counts the collection's changes "by comparing its values"; §4.4 counts documents that hold keys.
- PartsPhone.dc.html:54-60 with :95: the row is one `button role="switch"` whose label includes "Changed for this document · Use the section's"; :100 has no "Go to the section". OptionB.dc.html:109-114, :123-127: both phrases are caption text.
- §5.5: "none asks the author to choose Default". A changed row offers switch on, switch off and "Use the section's", which are the picker's three states (CollectionEntryInspector.swift:657-668).
- The first review asked for this rule (reviewer-INT.md, INT-5 c and e, in /home/user/FRUS-Explorer/Planning/collections-design-review/). §11 answers G6 for the title alone; "equal" appears in the record only for template matching.
Refutation: A rule in §4.1 or §7.4 for a key equal to its parent, or a way back for many documents at once. Searched §4.1, §4.2, §4.4, §7.4, §8; none.
Direction: Give one rule for a held key that equals what it would inherit, apply it in the upgrade, and add a way back for many documents at once.

ID: INT-5
Severity: S2
Claim: For any collection upgraded from 1.0, and for every collection in lane 1's release, a look chosen at export cannot print "the template's blocks": every block the collection holds counts as the author's and prints as well.
What a person meets: The owner's collection once tried Everything included and holds all five blocks. In the export sheet they choose Citations with your notes. By §4.4's words the five print where they stand and a Bibliography and a Thematic Index print again at the end. If a builder skips types already present, all five print where the template calls for two. Either way the board's sentence, "A Bibliography and a Thematic Index follow", is wrong. In the editor, no template can remove any of them.
Evidence:
- §4.4: "prints the template's blocks at the end, with any block the author placed where it stands, and without the blocks the collection's own template placed".
- §7.4: "an apparatus block | the block, as the author's own, since 1.0 did not record what placed it". §4.3: "no template removes it".
- §2.5: "Apparatus only accumulates … a collection that has tried all six holds all five blocks"; "nothing records which template the author started from".
- 1.0 skips a type already present (CollectionExporter.swift:196-198; CollectionEditorView.swift:1935-1943), and a block may be inserted twice (/home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:1087). The record states neither rule for a look.
- §9: "Lanes 1 and 2 … work on 1.0's values". §7.2 adds "the template that placed it" only in lane 3.
- Main.dc.html:85-86.
Refutation: A sentence in §4.4 on a block of a type the collection already holds, or one in §7.4 that tells a 1.0 template's blocks from the author's. §7.4 says the opposite. Checked.
Direction: State how a look's blocks meet blocks of the same type already in the collection, and what the upgrade and lane 1 treat as placed by a template.

ID: INT-6
Severity: S2
Claim: Two of §5.7's four rows do not differ in kind from what was withdrawn: on the Mac the collection's and a document's settings share one column, either one or the other, and the Note on the Text is a collection-level switch beside a placeable row.
What a person meets:
(a) Mac. While tuning document 475 they press the gear to look at a collection default. Today a popover opens, and the column and the outline's selection stay on 475. In this design the gear "selects" the collection's row and its settings are "shown in the column": 475's settings leave the column, the one selection moves to row 1, and they must find 475's row again. "Go to the section" and a name in the "N documents differ" list are the same one-way jump.
(b) A new collection's outline ends with a Note on the Text row, and Back matter says "Note on the Text: On". They drag the row up, then switch it off. Whether the row is deleted (and its place lost), or stays and prints nothing, is unstated. So is whether deleting the row turns the switch off.
Evidence:
- §4.2: "the gear selects it. It is reachable whatever else is selected, which the build-28 tester asked for". §5.4: "Its first row, or the gear; shown in the column". §5.7: "never drawn beside a document's".
- Today: the gear is a popover (/home/user/FRUS-Explorer/FRUSExplorer/Collections/MacCollectionManagerView.swift:1743-1757); the column follows `inspectedEntryId` and the outline `selectedEntryId`, "Distinct" (:855-864, :1046-1077, :1292).
- The tester asked for "a top section for collection-level attributes so they're reachable after refocusing on a document". The state reported: "not reachable without clearing the selection" (/home/user/FRUS-Explorer/Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md:260-262, :271-274). The app's own name for that arrangement: "one inspector surface, either/or" (CollectionEditorView.swift:252-256).
- The first form kept a route inside the inspector, which is why the first skeptic held this row "not the same thing" (/home/user/FRUS-Explorer/Planning/collections-design-review/skeptic-A-INT-DATA.md:22). The second form took it out.
- Three of the outline's six kinds of row have no list in §5.2 (note block, passage, apparatus block; `isInspectable`, MacCollectionManagerView.swift:1801-1804). What the column holds when one is selected is unstated.
- §4.2 and lane 5 put the collection in the outline's first row "on three platforms". §5.4 gives iPad "The gear's sheet, as now".
- §3.6: "The author may move it as any block, or remove it". §5.2: "Back matter: Note on the Text, …". §7.2: "the five back-matter switches". §5.7: "Rows, as now. The first form's five switches are gone". OptionA.dc.html:57 (row) and :249 (switch, "It has 2 things to say"). A11's reason: "toggles create a parallel structure system" (/home/user/FRUS-Explorer/Planning/Completed/Collections-Authoring-Scope.md:198).
Refutation: A way back from the gear, or a rule tying the Note's switch to its row. OptionA.dc.html:26 draws the gear as a pressed button, but §4.2 gives it one direction; §3.6, §4.3, §5.2 and §7.2 each speak of the row or the switch, never both. NEEDS A RUN for how much of today's popover and column show together at the default width.
Direction: Keep the collection's settings reachable on the Mac without giving up the selected document, and make the Note on the Text either a row or a switch.

ID: INT-7
Severity: S3
Claim: §4.5's "Selecting one says so, and offers Create Static Snapshot" has nowhere to happen, because neither editor lists a smart collection's documents.
What a person meets: Any platform. A smart collection's Contents shows one sentence and its apparatus rows. There is no document row to select, so the explanation and the offer never appear. On the Mac a click in the preview "selects that document's row", and there is none. Numbering, on under the default template, counts a list made again at each resolve, so a document's number can change between two exports.
Evidence:
- §4.5; §5.3 ("A click on a part selects that document's row"); §11's G3 row.
- /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionOutline+App.swift:214-224 keeps only generated and unknown kinds for a smart collection; Collection.swift:1016-1022; MacCollectionManagerView.swift:1797-1800 ("a smart collection has nothing to inspect").
- iOS-User-Manual.md:1154 and /home/user/FRUS-Explorer/Docs/macOS-User-Manual.md:879: "Contents itself lists only the collection's apparatus blocks".
- The snapshot is offered only in the lists (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionListView.swift:372-380; MacCollectionManagerView.swift:773-779).
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:181-182.
Refutation: A lane that lists the search's documents in the editor. Lane 5 says only "a smart collection's one scope". Checked.
Direction: Say where the sentence and the snapshot offer appear in an editor that lists none of the documents.

ID: INT-8
Severity: S3
Claim: Export Again saves one step of four and cannot repeat an export: it keeps the format alone, so after a look it exports something else, and the .fruscollection notes choice exists only in the sheet it skips.
What a person meets: They export a handout as PDF under Citations with your notes, fix a note, and choose Export Again. They get the full reader, "as this collection is set". They share a .fruscollection with notes included, then Export Again: the notes are either left out without a word or included without the question. From the Collections list nothing says where the render's wait or its result shows.
Evidence:
- §5.1: "Export Again: PDF, as this collection is set"; the sheet "opens on As this collection is set and on the format this collection last exported as". Lane 1 keeps "the format remembered on the device" and moves "the export's run … out of the sheet's view".
- CollectionExportSheet.swift:67-70 (`includeNotesInSharedFile = false`, sheet state), :593-596.
- Waits and delivery exist only in the sheet (:72-74, :295-308, :375-386, :325-327, :434-437). The record has no word on progress, cancel or delivery (searched).
- Since the sheet already opens on the last format and the collection's own look, Export… then Export is the same export, one tap more.
Refutation: A sentence that Export Again repeats the last look and the file's notes choice. None in §5.1 or lane 1.
Direction: Have Export Again repeat the last export exactly or be named for what it does, and say where its wait and result show.

ID: INT-9
Severity: S3
Claim: Starting every new collection under Full text as printed changes two things 1.0 does that Q4 does not name: its export stops carrying the author's research notes, and a new collection left untouched is no longer empty.
What a person meets: From the reader they add a document they have written notes on to a new collection, then export. 1.0 prints the notes; this default leaves them out of the PDF and out of a .bib. Separately, a ＋ tapped by mistake and backed out of is discarded today. With the template's two blocks "in place" it holds entries, and as the rule reads now it is kept as "Untitled Collection".
Evidence:
- §4.3: "A new collection starts under Full text as printed, with that template's two blocks in place". §2.5: 1.0's defaults are "the full text with footnotes and research notes".
- Collection.swift:218 `includeNotes: Bool = true`; CollectionExporter.swift:227 (`notes: false`); iOS-User-Manual.md:1121 ("your notes, highlights and headnotes stay out").
- OptionA.dc.html:240-242: the board's own collection needed three "Your change" rows to bring them back.
- CollectionEditorView.swift:2396-2403: `isUntouched` requires "no entry the context still holds"; iOS-User-Manual.md:1039.
Refutation: Q4 or §4.3 saying either. Neither does.
Direction: Tell the owner in Q4 what the new default stops printing, and say how an untouched new collection is known.

ID: INT-10
Severity: S3
Claim: §4.6's table leaves out the revision's own collisions: one list under two names, five things called a note, a "Back matter" group that holds front matter, and a row whose drawn value is outside its table.
What a person meets: The export sheet heads its list LOOK and captions it "A template chosen here…"; two of the six "looks" take the documents' text away. In the editor "Your notes: Off" leaves the author's Note Blocks printing. Under Back matter sit the project stamp, which prints on the title page, and the word cloud, which is prepended.
Evidence:
- Main.dc.html:31 against :43; §5.1; §4.3 ("A different look is a new template"). §4.6 has no row for "look".
- Notes: "Your notes" (§4.1); "Research Note", the label over the same notes (§5.2; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionC.dc.html:97-98 draws both on one part); "Add Note Block" (CollectionEditorView.swift:1337); "The volume's notes"; "Note on the Text". §4.6 names "two kinds of note".
- §4.2 itself writes "Footnotes: All · 2 documents differ" for the row §4.1 names "The volume's notes".
- §5.2 "Back matter: … project stamp, query log, word cloud"; CollectionEditorView.swift:220 ("on the title page"); Collection.swift:222-223 ("prepended").
- §4.1: Opening has two values. OptionB.dc.html:162, PartsPhone.dc.html:99 and OptionC.dc.html:160 draw a third, "Your title leads", against rule 5's "keeps its value". §5.2 files Opening under "From the volume" and See also under "Yours"; §3.2 files the citation under the author's lines.
- The first review held that Footnotes and Source note "keep today's labels … so they need no relearning" (reviewer-INT.md, Attacked and held). Both names go here (CollectionCompositionRows.swift:146-152).
Refutation: A row of §4.6 for each. It has eight rows and none of these.
Direction: Add look, the kinds of note and Back matter to §4.6, and hold §4.2 and the boards to the table.

§11 rows in my scope
- G2: ANSWERED as to the tap, which now writes nothing and asks first in the editor; what the export then holds is not settled (INT-3, INT-5).
- G3: PARTLY. One scope and the snapshot's copy are stated; "Selecting one" has no list to select from (INT-7).
- G4: ANSWERED. No control changes the scope. The price on the Mac is INT-6(a), and the count's meaning is INT-4.
- G5: PARTLY. The record now says the count rises, but 31 is not "counted the same way"; it is 41 (INT-1).
- G6, the half that was INT-5: PARTLY. The title keeps its place and the outline shows it; overrides equal to what they inherit, and a switch set back by hand, have no rule (INT-4).
- G13: ANSWERED in the text. The drawn opening that stands in on iPad and iPhone shows a title, a date line and Opening, three of a document's ten rows.
- G14: ANSWERED by §4.3's rule.
- INT-4: PARTLY. All four are named; rows 2 and 4 do not differ as claimed (INT-6); row 3 is conceded and asked in Q3.
- INT-8: ANSWERED. One value at every scope, See also for the collection, the prompt under Text, rule 5.
- INT-10: PARTLY. The five words named are gone; the revision brings its own (INT-10).
- DATA-10: ANSWERED for the case named; Export Again's other gaps are INT-8.
- A11Y-1, as it touches §4.1's rows: PARTLY. The words are on the row; both boards draw the way back as caption text (INT-4).

Attacked and held
- "14 in view" holds by §5.2's list and OptionA.dc.html:102-133, in the sense in which today's 24 are "all in view": not behind a disclosure.
- Today's 24, 9, 6 + 1 and 7 hold on a recount from the code (lines in INT-1).
- No control changes the scope by itself, so G4's snap-back cannot occur (§4.2), and on iPhone the screen's title names the scope (PartsPhone.dc.html:24).
- The drawn opening does show a typed title where it is typed: on the phone board the card and the title field end above about y 360 of 844 (PartsPhone.dc.html:30-45), clear of a keyboard (its height from memory, not fetched; a sketch).
- A look that "writes nothing" fits the sheet as it is: it never writes the collection (CollectionExportSheet.swift:19-22), and options are built from values (CollectionExporter.swift:592-604).

Not read
- CollectionAddDocumentsSheet.swift, CollectionRichTextEditor.swift, CollectionPickerSheet.swift, CollectionContentResolver.swift, PDFCollectionExporter.swift, DocxCollectionExporter.swift, CollectionItemHTMLRenderer.swift.
- CollectionPreviewView.swift beyond its head notes, cap, debounce and reload; CollectionListView.swift before line 60 and after 460; CollectionEditorView.swift after line 2410 beyond its outline.
- The code §7 rests on, the UI suites and their runbook, Docs/EditableContent, Collections-Rework-Scope.md, Collections-Manager-UX-Scope.md, and the first review's other reports beyond reviewer-INT.md and the skeptic's INT-4 to INT-7.
- The TEI volumes were not opened. Marks.dc.html and Citations.dc.html were read and not judged.
- Nothing was fetched, built or run. Every statement about how a control behaves is from the code, the record or a board's source, or is marked.

Outside my scope
- EDI: a date line given without a title would print under the volume's heading with nothing marking it; §3.6's Note speaks only of "a date line under a title".
- EDI: §5.2 quotes the ask as "my own … labels" and offers the app's eleven words; the ask reads "other labels derived from the source TEI", and the table's rule excludes every word the volume prints.
- ENG: lane 1 "on 1.0's values" has neither a recorded template nor a record of what placed a block, which §5.1's first row ("follows … · n changes") and §4.4's last bullet both need.