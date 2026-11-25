ID: INT-1
Verdict: CONFIRMED
Severity: S2
Why: Recounted from the record's §5.2: 14 in view (six templates, Review, five fields, the saved-search link, Customize), then nine for each document, two, five, and Wording, which as one row gives the record's 31 and as the eleven fields §5.2 lists ("each with a field"; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionA.dc.html:256, "11 labels") gives 41. Today's 24 is counted by field: its "8 name and title page" are the name, the note and six front-matter controls one by one (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEditorView.swift:806-816, :967-1103), with six templates, nine composition controls and the link (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionCompositionRows.swift:113-204). So §5.5's "the way §2.4 counts today's", §1's "Opened fully they are 31" and §11's "Counted the same way" are wrong for the collection by ten; "14 in view" holds. Two corrections to the finding: the export sheet is 15 against 7, not 16, since the .fruscollection notes switch is in today's sheet too and in neither count (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExportSheet.swift:359-361); and the ways back it adds are conditional, and text on every board.
Duplicates: A11Y-6 (the rows' second controls, uncounted).

ID: INT-2
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: Every fact holds, and each is the record's own: "Opening and the date line are new" (§5.5); "Your title, which leads wherever one is given, under either setting" (§3.3), drawn dimmed at /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionB.dc.html:162 and /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/PartsPhone.dc.html:99; the address rides with the citation and the printed heading "prints wherever the text prints" (§3.2). The chief limit is stated and asked: §3.1, "What the author does not get is a page from which the volume's heading is gone", with Q2 and Q7; the order of parts is §8's item 3. "Three of five" is one too many: §5.2 gives eleven of the app's words a field at the collection's scope, which is where 1.0's literals are, so the address line and the order are the two that stay. New here are the tally the record never draws against §2.2, and the date line with no title (§3.2 "given or not, for one document"; Q7 "under the title"). Nobody is misled or stuck by either, so S3.
Duplicates: EDI-2 (a date line with no title); INT-10 (Opening's drawn third value).

ID: INT-3
Verdict: CONFIRMED
Severity: S2
Why: No line of §4.4, §5.1, §5.5 or lane 1 ties a look to a format (I searched the record for each format's name and for "look"). BibTeX and RIS read one option, `includeNotes` (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/BibTeXCollectionExporter.swift:63; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/ZoteroCollectionExporter.swift:65-69), which two recipes set false (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:227, :243), so on §4.4's "copy of the collection's values" a look decides whether notes are written and nothing else. The Web-API send reads no option (CollectionExportSheet.swift:734-735), and the file "bypasses document resolution entirely" (:604-608). The board's sentence follows the look alone (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:77-90, :121), and its More formats line holds Zotero (:54) against §5.1's "The Zotero row stays as it is". The fit point is arithmetic on a sketch and holds as that: 844 less a 57-px bar and a 75-px dock leaves 712, and seven rows at 56 put the WHAT WILL PRINT label at about 676.
Duplicates: FMT-5 (the same finding, with the file's half developed); FMT-4 (adjacent); A11Y-3 (the sentence below the fold).

ID: INT-4
Verdict: CONFIRMED
Severity: S2
Why: "equal" occurs in the record only for template matching (§2.5, §7.4); §4.1 has a scope hold "only the keys it changes" and §7.4 turns each override into "the keys the entry changes", so a held key equal to what it would inherit has no rule, at the upgrade or after a switch goes off and on. Such keys are in the model's own words: `includeHeadnote` "Was a non-optional Bool … Existing entries migrate to their stored value (explicit on/off)" (/home/user/FRUS-Explorer/FRUSExplorer/Models/Collection.swift:570-577); no store was read, by the reviewer or by me. §4.4 keeps "what the author set for particular sections and documents" under a look and counts them, and §4.1's rule 3 gives the way back one row at a time, so the three phrases can name documents nobody changed. It is the first review's INT-5 (c) and (e), confirmed there at S2 (/home/user/FRUS-Explorer/Planning/collections-design-review/skeptic-A-INT-DATA.md:25-28), and §7.4's table leaves it standing. One softening: an explicit Off already resists a template's headnotes in 1.0; what is new is that the row says "Changed".
Duplicates: A11Y-6 (the way back drawn as words inside the switch, PartsPhone.dc.html:54-60). DATA-7 and ENG-2 are the neighbouring gap, a half-set pair, and not this one.

ID: INT-5
Verdict: CONFIRMED
Severity: S2
Why: §4.4 prints a look "without the blocks the collection's own template placed", and 1.0 holds no such fact: "A template is never stored, only the fields it writes" (CollectionExporter.swift:50-51), and a block entry stores "Only the TYPE" (Collection.swift:654). §9 has lane 1 "work on 1.0's values" with "Stored data: None", and §7.4 upgrades each block "as the author's own, since 1.0 did not record what placed it", so the rule can be kept in neither. No sentence says what a look does with a block of a type the collection already holds, where 1.0's own apply skips it (CollectionExporter.swift:196-198; CollectionEditorView.swift:1935-1943). So the board's "A Bibliography and a Thematic Index follow" (Main.dc.html:85-86) is true only of a collection made after lane 4.
Duplicates: DATA-5 (the same finding); ENG-1 (its last evidence line).

ID: INT-6
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: (a) holds on the Mac: today the gear opens a popover, and the column and the selection stay (/home/user/FRUS-Explorer/FRUSExplorer/Collections/MacCollectionManagerView.swift:1743-1757; `inspectedEntryId` and `selectedEntryId` "Distinct", :855-864), and §4.2 with §5.4 has it select the collection and show it "in the column". That is again "not reachable without clearing the selection" (/home/user/FRUS-Explorer/Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md:274), with one click to get there and one to come back, on one platform. (b) holds: the Note on the Text is a block the author "may move … or remove" (§3.6) and one of "the five back-matter switches" (§7.2; §5.2), both on one board (OptionA.dc.html:57, :249), with no rule joining them. But §5.7's "The first form's five switches are gone" is true of the five apparatus blocks, so both rows are overstated in part and neither is false. Neither misleads or strands anyone, which is S3; what the Note's two forms cost in print and in storage is EDI-3's and DATA-10's.
Duplicates: for (b), DATA-10 (a), and the last evidence lines of EDI-3 and ENG-4.

ID: INT-7
Verdict: CONFIRMED
Severity: S3
Why: For a smart collection `contentsRows` keeps only the entries `leavesOut` does not drop, its apparatus and unknown kinds (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionOutline+App.swift:214-224; Collection.swift:1016-1022), and `isInspectable` is false for all of them (MacCollectionManagerView.swift:1800-1804). So §4.5's "A collection linked to a saved search lists that search's documents" is true of the preview alone, "Selecting one" has no row, and §5.3's click that "selects that document's row" has none either. Create Static Snapshot is offered only in the two lists (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionListView.swift:372-380; MacCollectionManagerView.swift:776). Lane 5 says only "a smart collection's one scope".
Duplicates: ENG-9 (the same finding); A11Y's last "Outside my scope" line.

ID: INT-8
Verdict: CONFIRMED
Severity: S3
Why: §5.1 keeps "the format this collection last exported as on this device" and nothing else, and the file's notes choice is the sheet's own state, off at each opening (CollectionExportSheet.swift:67-70, :593-596), so a file exported again has no rule for its notes. Two parts are weaker than written. The label is the record's own, "Export Again: PDF, as this collection is set", so a person is told that a look is not repeated. And §5.1 does say where a wait shows: Export Again "stops on the sheet when one has something to say". Where plain progress and the finished file appear from the Collections list is unsaid, as the finding says (delivery is the sheet's today, :325-327, :434-437).
Duplicates: FMT-10.

ID: INT-9
Verdict: CONFIRMED
Severity: S3
Why: §4.3 starts a new collection under Full text as printed, whose recipe has `notes: false` (CollectionExporter.swift:227), where the model's default is `includeNotes = true` (Collection.swift:218); Q4 names the opening and the template and not this. The board's own collection needed "Your change" on three rows to print them (OptionA.dc.html:240-242). `isUntouched` requires that no entry be held (CollectionEditorView.swift:2396-2403), so with "that template's two blocks in place" a collection opened and left would be kept as "Untitled Collection" unless that rule is rewritten, which no lane names.
Duplicates: none.

ID: INT-10
Verdict: CONFIRMED
Severity: S3
Why: Each collision is on the page cited. The list is headed LOOK and captioned "A template chosen here…" (Main.dc.html:31, :43; §5.1). §4.2 writes "Footnotes: All · 2 documents differ" for the row §4.1 and §4.6 name The volume's notes. Back matter holds the project stamp, which prints "onto the title page", and the word cloud, which is "prepended" (Collection.swift:82-87, :222-224). Three boards draw Opening's value as "Your title leads" (OptionB.dc.html:162; PartsPhone.dc.html:99; /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionC.dc.html:160), which §4.1's table does not list and rule 5's "keeps its value" excludes; §4.6 has a row for none of them.
Duplicates: none.

ID: A11Y-1
Verdict: CONFIRMED (one finding with EDI-5 and ENG-3)
Severity: S2
Why: The web page's contents list is one `<ol>` whose items are documents, section headings and generated blocks (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:560-583), and only `nav li.toc-sub` loses its marker (:859-860, :971). The tree itself says such a row is numbered: the preview "printed an empty heading and a Contents row of '1.' and nothing" (:274-277). The PDF and Word number documents alone (/home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:627-638; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/DocxCollectionExporter.swift:1896-1906), so the formats already disagree in 1.0, which §2.3 omits and §7.4's "no numbering … what 1.0 prints" denies. Recounted on the boards' collection (two headings, six documents, three blocks): eleven rows, The Long Telegram the sixth, under a lead of "4.". §3.8 and lane 2 name Word's list and not this one; no screen reader is needed for the claim, since the printed marker disagrees by itself.
Duplicates: EDI-5 and ENG-3 (the same finding; ENG-3 states it most fully). The three deserve one S2.

ID: A11Y-2
Verdict: PLAUSIBLE
Severity: S3 as it stands; S2 if the run shows a keystroke replacing a title
Why: §5.3 and lane 6 do say focus "goes with it" and moves "to that part's row", and a document's nine rows are two text fields, four switches and three menus (OptionB.dc.html:98-133). But a "row" has two drawings, OptionB's bare controls and OptionC's selectable rows (OptionC.dc.html:118-127), and a list's row is content that takes focus on the Mac by the sentence the finding quotes (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-A11Y/hig-focus-and-selection.md:32), so the rule can be kept without focusing a switch. The other sentence, "Avoid changing focus without people's interaction" (:30), does not condemn it: the click is the interaction. That a field focused by code selects its text, and that a toggle refuses focus without full keyboard access, are from memory, and nothing in the tree settles either. True as cited: the title commits at each keystroke (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryInspector.swift:390-397) and no suite runs on the Mac (/home/user/FRUS-Explorer/project.yml:607-609).
Check owed: Fix the row's anatomy first (A11Y-6). Then on macOS 27 with Keyboard navigation off, set focus by code on a Toggle, a menu Picker and a TextField in an inspector column: what takes focus, whether the field's text is selected, and where the next Space goes.
Duplicates: A11Y-7 (no suite for the Mac).

ID: A11Y-3
Verdict: PLAUSIBLE
Severity: S2 if the run bears out the accessibility sizes; the default-size half alone is S3
Why: The arithmetic reproduces: the reviewer's script (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-A11Y/sheet_fit.py) gives 883 px of content in a 714-px viewport with WHAT WILL PRINT at 734, and my own count with every row at its 56-px minimum puts it at about 676 of 712. The order is the record's, look, then format, then the sentence (§5.1; Main.dc.html:30-62), where today's sheet leads with the sentence and the format grid (CollectionExportSheet.swift:342-356). The AX5 figures use the HIG's sizes as fetched (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-A11Y/hig-typography.md:387-400: Callout 51/60, Footnote 44/52), a half-em glyph and screen sizes from memory. What needs no run is that seven two-line looks at 60- and 52-point leading pass 900 points before the format control, against a viewport of some 500 to 620. Confirmed from the text: lane 1's check has each look speak "its name, its line and whether it is chosen" and names neither the sentence nor what must be in view.
Check owed: The built sheet on iPhone 17 and iPhone SE (3rd generation) at the default size, AX3 and AX5: on opening, whether one look, the format control and Export are in view; at the default size, whether the sentence is; with VoiceOver, what is spoken after a look is chosen.
Duplicates: INT-3 (its last evidence line).

ID: A11Y-4
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: The record draws it: in the second opening the citation is "small" above the heading (§3.3), §3.8 has each format "draw the plan in order", §4.3 gives that opening to three templates and to every new collection, and §3.8's sentence and lane 2's check speak only of the opening with a title. The levels left open are in the code: the volume's heading is an `<h2>`, an attachment's an `<h3>` and each document's "Footnotes" an `<h2>` (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:741, :769, :701). But no rule is clearly broken: the reading order is the drawn order, which is what the fetched 1.3.2 asks, and the citation stays adjacent, inside the document's `<section>` if lane 2 keeps it (CollectionItemHTMLRenderer.swift:297). What a listener hears of a line before a heading is from memory in the finding, and the Word spacing (DocxCollectionExporter.swift:402-423) assumes lane 2 gives the small line no style of its own. What stands is a check written for one opening of three, which is S3.
Duplicates: none.

ID: A11Y-5
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: The code is as cited: a card's name and line are `.system(size: 14, weight: .semibold)` and `.system(size: 11.5)` with `.lineLimit(3)` (CollectionCompositionRows.swift:289-296), the chips 13 and 10 (:328-331), the pill `.system(size: 12, weight: .semibold)` (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryRows.swift:539); a search finds ten fixed-size sites under Collections. Lane 5's fit check does name "iPhone 17 and iPhone SE" alone, while §5.4 gives iPad "The same grid". But all of it is 1.0's, in the same sheet and on the same rows: the design moves the grid from the sheet's fourth section to its first (CollectionEditorView.swift:885-889) and makes nothing worse, and the first review rated down what the app does today. What the lane owes is true and cheap: an iPad in the fit check, and proof on the card's own label that the size took effect (the trap in the suite's own words, /home/user/FRUS-Explorer/FRUSExplorerUITests/CollectionEditorTitleTests.swift:790-793).
Duplicates: A11Y-9 (the pill).

ID: A11Y-6
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: The boards are as described: on the phone the row is one `<button role="switch">` holding the name and "Changed for this document · Use the section's" (PartsPhone.dc.html:54-60, :95); on the Mac the note is a `div` beside a switch named by the row's name alone (OptionB.dc.html:109-115); in the collection's list each row is one button with "Your change · Use the template's" inside it (OptionA.dc.html:140-146, :240-242). But these are sketches, and the text asks for more than they draw: §4.1's rules 3 and 4 give the row a way back and a way there, and lane 5's check has "a way back says what it removes" with 44-point hit areas. That is the shape of the first review's A11Y-1, which stood at S3. What is left for the design is that a row's anatomy (a value, a way back, a way there, a count that opens a list) is fixed nowhere, and that §5.5 counts none of the second controls.
Duplicates: INT-4 (the same board lines); INT-1 (the count).

ID: A11Y-7
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: §9's table has rows for lanes 1, 2, 4, 5 and 6, and lane 3 does add screens: a collection "not editable, with one button to upgrade it now" and the report (§7.4), and "Upgrade That Version as a Copy" with a question before a delete (§7.5). Lane 4's row hears only the exported words. The UI test target is iOS (project.yml:607-609), and the VoiceOver service "returns the first 64 characters" and "no test can make VoiceOver do a custom action" (/home/user/FRUS-Explorer/Planning/UI-Test-Destinations-Runbook.md:1307, :1313). So §11's "A check for each lane" overstates by lane 3. It is S3: lane 7 has nothing to check yet, the table itself hides nothing, the Mac's walk is the project's standing way and no claim of this record, and the cure is rows added to a table; the first review's S2 was for no check in any lane.
Duplicates: none.

ID: A11Y-8
Verdict: PLAUSIBLE
Severity: S3
Why: The card is a label and four lines above the field (PartsPhone.dc.html:30-45), and §5.2 does give it as where a typed title "is seen at once". The reviewer's script reproduces (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-A11Y/card_fit.py): about 165 px at the board's sizes, 584 to 623 points at AX3 and 956 to 1,130 at AX5, against 343 to 432 above a keyboard whose height is from memory. The direction of the result does not hang on that height: four wrapped lines at 39- to 51-point leading cannot share some 400 points with a 70-point field. Lane 5's fit check names "the gallery and the rows" and not the card, and nothing says what VoiceOver is told when its lines change.
Check owed: The built screen on iPhone 17 and iPhone SE at AX3 and AX5 with the title field focused: whether any line of the card is in view; and with VoiceOver, what is spoken as a title is typed.
Duplicates: none.

ID: A11Y-9
Verdict: CONFIRMED
Severity: S3
Why: The list's row has a tap gesture, a swipe and a context menu and no accessibility action (CollectionListView.swift:333-387; a search of the file finds none), against the project's own note that a route is "also exposed as a VoiceOver action, since a context menu alone is not" (CollectionEntryRows.swift:1028). Every note's switch carries one label, "Include this research note when notes apply", and every highlight's another (CollectionEntryInspector.swift:459-460, :514-515), with the preview text outside the switch. The pill is 12-point type with 5 points above and below (CollectionEntryRows.swift:537-547), about 24 points, under the fetched 28-point minimum (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-A11Y/hig-accessibility.md:135), and a search finds `minimumHitTarget()` nowhere under Collections. All three are 1.0's, and the lanes keep them. One softening: lane 5's "Hit areas of 44 points, by a suite" is not scoped, so it can be read to take in the pill; whether VoiceOver's long press opens the row's menu was not established.
Duplicates: A11Y-5 (the pill).

**The reviewers' "§11 rows" verdicts in your files**

- INT, G2 ("ANSWERED as to the tap"): PARTLY. Its own INT-5 shows the look's fourth promise cannot be kept on 1.0's values or for an upgraded collection (§4.4 against §9 and §7.4). G2 as merged also held that a block the author deleted returns "because its removal is recorded nowhere" (/home/user/FRUS-Explorer/Planning/Collections-Design-Adversarial-Review-2026-11-25.md:74), which §4.3 answers only for blocks placed after lane 4.
- INT, G13 ("ANSWERED in the text"): PARTLY. §5.3 says the three repairs of the preview "come first" "on every platform", and §9 gives them to lane 6, "The Mac's preview points", with §12's check for the Mac alone.
- INT, G14 ("ANSWERED by §4.3's rule"): PARTLY. The rule is for "A document added". A section heading or a note block is still appended one past the highest position (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryData.swift:315-324), and under §4.3 every new collection has two blocks at its end from the start.
- A11Y, G3 ("ANSWERED in §4.5's text"): PARTLY, as that report's own last line concedes: "Selecting one" has no row (CollectionOutline+App.swift:214-224). INT, DATA, FMT and ENG each say PARTLY.
- INT, INT-4 ("PARTLY … rows 2 and 4 do not differ as claimed"): the label stands and the reason is too strong. Row 4 does differ for the five apparatus blocks, and row 2 by a route that is always there; see INT-6.

**Errors in the design record found on the way**

1. §4.1, "A section's headnote and See also are followed by its documents, which 1.0's cascade does not do": 1.0 follows a section's See also (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:611-612, :1103, `ref.includeRelatedDocuments ?? section.includeRelatedDocuments ?? false`); only the headnote is new (CollectionEntryInspector.swift:625-627).
2. §7.4 and §4.3, "no numbering … what 1.0 prints": 1.0 numbers the documents in the contents list of all three formats (PDFCollectionExporter.swift:630-638; DocxCollectionExporter.swift:1899-1906; the web page's `<ol>`, CollectionItemHTMLRenderer.swift:560), and the board draws "3." and "4." on rows captioned "What 1.0 prints, and what an upgraded collection keeps" (/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Marks.dc.html:21-27).
3. §4.3, "It prints as it did, apart from §2.8's defects": §7.4's own report adds "the Note on the Text where it has something to say", and by §3.3 a titled document at full depth gains a citation line and the words Printed heading:, where 1.0 prints the title in the citation's place (CollectionExporter.swift:747-750). Neither is one of §2.8's seven.
4. §1 "Opened fully they are 31", §5.5 "the way §2.4 counts today's", §11 G5 "Counted the same way": §5.2's wording table is eleven fields, and §2.4 counts fields singly.
5. §5.5, a section: today's "7 are the section's" leaves out the heading's own title field (CollectionEntryRows.swift:150-156), which the design's 9 counts as "its title".
6. §5.5, the export sheet: its 12 counts More formats as one, where today's 7 counts each of six cards (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExporter+App.swift:176-179).
7. §5.7, "Rows, as now. The first form's five switches are gone": §5.2 and §7.2 make the Note on the Text one of "the five back-matter switches", and §3.6 makes it a block the author "may move".
8. §4.5, "A collection linked to a saved search lists that search's documents" and "Selecting one says so": neither editor lists them (CollectionOutline+App.swift:214-224).
9. §4.4, "without the blocks the collection's own template placed", against §9 ("Lanes 1 and 2 … work on 1.0's values") and §7.4 ("as the author's own, since 1.0 did not record what placed it").
10. §4.2, "which the build-28 tester asked for": the state reported was "not reachable without clearing the selection" (188-189-Tester-Feedback-Build28-Plan.md:274), and on the Mac the gear of §4.2 "selects" the collection.
11. §4.2 and lane 5 (the collection as "the outline's first row", "on three platforms") against §5.4 (iPad: "The gear's sheet, as now").
12. §5.3, "On every platform … Three things it lacks today come first", against §9, which puts keeping the place and bringing a row's document into view in lane 6, "The Mac's preview points".
13. §5.1, "The Zotero row stays as it is", against Main.dc.html:54, "More formats: BibTeX, RIS, .fruscollection, Zotero".
14. §4.1 (Opening's two values; rule 5, "keeps its value") against three boards' "Your title leads" (OptionB.dc.html:162; PartsPhone.dc.html:99; OptionC.dc.html:160).
15. §4.2, "Footnotes: All · 2 documents differ", for the row §4.1 and §4.6 name The volume's notes.
16. §5.2 files the project stamp and the word cloud under Back matter: the stamp prints "onto the title page" and the cloud is "prepended" (Collection.swift:82-87, :222-224).
17. §11 G16, "A check for each lane": §9's table has rows for lanes 1, 2, 4, 5 and 6.
18. §2.1: "It opens on PDF every time", and in the next bullet the path to a PDF counts "a format card".
19. Main.dc.html:80: the sentence for Full text as printed has no "numbered 1 to 6", though §4.3 gives that template Numbering On and line :78 has the words for the collection that follows it.

**Not checked**

- Nothing was built or run, and no device was used. A11Y-2, A11Y-3 and A11Y-8 stay PLAUSIBLE for that reason.
- No store was read: whether entries hold an explicit `includeHeadnote` (INT-4) rests on the model's comment.
- Not established from anything readable here: how macOS gives focus by code to a toggle, a menu or a text field; how VoiceOver or NVDA speaks a list's markers or a line before a heading; whether VoiceOver's long press opens a row's context menu; iPhone screen, sheet and keyboard sizes.
- Nothing was fetched. The HIG and WCAG sentences were read in the reviewer's fetched copies under /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-A11Y/, where each quoted sentence is present; the copies were not fetched again.
- The TEI was not opened: no INT or A11Y finding rests on a count over it.
- Not read: the web edition's repository; Docs/EditableContent; the Agentic Analysis Guide; CollectionAddDocumentsSheet.swift, CollectionRichTextEditor.swift, CollectionPickerSheet.swift, CollectionContentResolver.swift and CollectionPreviewView.swift; the UI suites beyond CollectionEditorTitleTests.swift:770-800; the runbook beyond :1296-1346; the plan of record beyond a search for decision 139 and for fixed-size text; Collections-Manager-UX-Scope.md; the first review's reports beyond reviewer-INT's INT-5 and skeptic A's INT-1 to INT-7.
- The "Attacked and held" lines of INT.md and A11Y.md were not re-checked, and contrast.py was not rerun.
- ENG.md was absent when I began and arrived while I worked. I read it, DATA.md, EDI.md and FMT.md once each for duplicates and re-read none of their cited lines, so a finding of theirs named above as a duplicate is confirmed only in the part it shares with mine.
- Where things are: the tree is /home/user/FRUS-Explorer and the design record is /home/user/FRUS-Explorer/Planning/Collections-Customization-Design-2026-11-25.md; the boards are in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/; the six reports are in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/. I created no files.