ID: A11Y-1
Severity: S2
Claim: In the web page, which §3.8 names as an accessible export, the contents list is an ordered list whose own markers number every row, section labels and apparatus titles included, so under §4.3 the document headed "4." in the record's sample collection is row 6 of its contents list.
What a person meets: A reader of the web-page export of "Kennan from Moscow, 1946" as the boards build it (two sections, six documents, three blocks). The browser numbers the Contents rows 1 to 11. "The Long Telegram" is the sixth; its head reads "4. The Long Telegram"; the Note on the Text says the documents are numbered 1 to 6. If the plan's number is also written into the row it reads "6. 4. The Long Telegram". A listener is given the list's own number (how VoiceOver and NVDA speak an ordered list's markers is from memory, not fetched). The PDF of the same collection says 4.
Evidence:
- Record §4.3: "the documents numbered 1 to n in its order, at each lead and in each contents row". §3.3: the number "is what tells eight documents with one heading apart, in the contents list and to a reader moving by headings". §7.4: "no numbering … what 1.0 prints". §2.3's table lists no difference in how the formats number contents rows. Lane 2 names Word's contents list and not the web page's.
- FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:560-583: one `<ol>`; a document is `<li><a href="#…">`, a section heading `<li class="toc-section">`, a generated block `<li class="toc-section">`. :859-860: `nav ol { padding-left: 1.25rem; }` and `nav li  { margin: 0.3rem 0; }`, no `list-style`; the one rule that drops a marker is `nav li.toc-sub` (:971). Pinned by FRUSExplorerTests/CollectionTests.swift:2055-2059.
- The project met this defect once already: FRUSCoreKit/TEI/ReaderPage.swift:743-749, "#985: the <ol> counter is positional, so it numbered the source note 1".
- The other two formats count documents only: FRUSExplorer/Collections/PDFCollectionExporter.swift:627-638 ("documents are numbered; authored section headings appear as bold, un-numbered labels"); FRUSCoreKit/Collections/DocxCollectionExporter.swift:1896-1906 (`out.append("\(n). \(cite)")`, until Word rebuilds the field).
- Boards: Marks.dc.html:26-27 draws 1.0's rows for documents 474 and 475 as "3." and "4."; OptionA.dc.html:65-89 draws the two section labels unnumbered.
Refutation: a rule that removes the contents list's markers, or a line of §3.8 or §9 that rebuilds the list. Searched the renderer and ReaderPage.swift for `list-style`, and the record for the web page's list: none. NEEDS A RUN: open a 1.0 web-page export of a collection with one section heading and read its Contents; not run.
Direction: Put the contents rows' numbering in the plan for all three formats, say in lane 2 what the web page's list element becomes, and hold a row's number to its lead's by a test.

ID: A11Y-2
Severity: S2
Claim: §5.3's rule that keyboard focus goes to the clicked part's row can hold, at the Mac's own keyboard behaviour, for two of a document's nine rows, and those two are text fields, so a click on the proof ends with the insertion point in "Your title".
What a person meets: Mac, Show Parts on, reading the proof. They click the title on the page to see its setting, then press Space or an arrow key to move down the page. Built as written, the key goes to the "Your title" field, which writes the entry at each keystroke (from memory, not fetched: a Mac text field given focus by code selects its whole text, so one key replaces the title). If they click Highlights or Text, the row is a switch or a menu; on the Mac those take focus only in full keyboard access mode, so either nothing takes focus and lane 6's check fails, or the app makes a switch focusable against the platform and Space flips it. A click on the printed heading has no row to go to.
Evidence:
- Record §5.3: "A click on a part selects that document's row and opens that part's row in the column. Keyboard focus goes with it". Lane 6: "A click on a part moves keyboard focus to that part's row and VoiceOver announces what is selected." Lane 5: "On the Mac, every row by keyboard alone", with no keyboard setting named.
- OptionB.dc.html:98-105 (two text fields), :108-116 (four switches), :122-133 (three menus). OptionC.dc.html:153-163 (nine rows), :172 ("The printed heading has no settings").
- HIG, Focus and selection, fetched today: "in iPadOS and macOS, a full keyboard access mode helps people use the keyboard to reach every control, so you only need to support focus for content elements like list items, text fields, and search fields, and not for controls like buttons, sliders, and toggles"; and "Avoid changing focus without people's interaction."
- The title commits as typed (FRUSExplorer/Collections/CollectionEntryInspector.swift:390-397), and "Nothing registers undo for collection entries" (CollectionEntryRows.swift:294).
- Nothing in the tree moves keyboard focus to a control: the two `@FocusState`s under Collections are text fields (MacCollectionManagerView.swift:730; CollectionEntryRows.swift:95), there is no `.focusable(`, and the outline's keys are ↑/↓ and ↩ (MacCollectionManagerView.swift:1285-1292, :1352-1359).
- Three other controls move the selection and have no focus rule at all: the gear (§4.2), "Go to the section" (§4.1 rule 4), a name in the "documents differ" list (§4.2).
- No suite can hold any of it: the UI test target is iOS (project.yml:607-609), and the Mac is walked by hand (tools/mac-check-copy/README.md:3, :88, :117).
Refutation: a line saying which element takes focus for a switch or a menu row and under which keyboard setting, or that focus stays on the page. Read §5.3, §9 and §12: none. NEEDS A RUN: on macOS 27 with keyboard navigation off, set focus by code on a SwiftUI Toggle and on a TextField in an inspector column; note where the next Space goes and whether the field's text is selected.
Direction: Let a click select and reveal the row and leave keyboard focus where the click was, announce the selection, and move focus only when the person asks for the row.

ID: A11Y-3
Severity: S2
Claim: By the board's own sizes the export sheet's sentence of what will print is below the fold when the sheet opens at the default text size, nothing has it spoken when a look is chosen, and at AX5 one pinned button still leaves less than one look wholly in view on either iPhone, with the format control six to eight screens down.
What a person meets: iPhone. At the default size they choose "Citations with your notes"; the line that would say "1 document keeps its own settings" changes out of view, and VoiceOver says only that the row is selected. At AX5 on an iPhone SE the collection's name, its count and the LOOK label fill the sheet; to change PDF to Word they pass seven two-line looks. Today the format cards are the second thing in the sheet, and the button scrolls with the form.
Evidence:
- Record §4.4: "The sheet's sentence counts them". §5.1: look, then format, then the sentence, and "the one button pinned under the list". Lane 1's check: "each look speaks its name, its line and whether it is chosen, and the group says once that the choice is for this export"; it names no sentence and nothing that must be in view.
- Main.dc.html:24 (the scrolling region), :25-28 (name and count first), :33-43 (seven looks, a caption), :46-57 (format), :59-62 (the sentence, last), :65-67 (the dock), :75-90 (sentences of up to about 275 characters).
- Arithmetic, mine, at half an em a character: at the board's sizes the content is about 883 px in a 714 px viewport and "What will print" starts at about 734; on an SE's 667 pt the format control, at about 601, is below the fold too. With the HIG's AX5 sizes (Body 53/62, Callout 51/60, Footnote 44/52, fetched today) the first look starts 333 to 398 pt down and is about 455 pt tall in a viewport of 489 to 620 pt; the format control starts about 3,700 to 3,900 pt down and the sentence about 4,100 to 4,300. At AX3 on the SE no look is wholly in view either.
- Today: FRUSExplorer/Collections/CollectionExportSheet.swift:342-356 (the sentence, then the format grid), :374-397 (the button inside the form).
- HIG Typography, fetched: "keep primary elements toward the top of a view even when the font size is very large". HIG VoiceOver, fetched: "Inform VoiceOver when visible content or layout changes occur." WCAG 4.1.3, fetched from w3c/wcag.
Refutation: NEEDS A RUN: the built sheet on iPhone 17 and iPhone SE (3rd generation) at L, AX3 and AX5: on opening, are one look, the format control and the button in view; at L is the sentence in view; with VoiceOver on a look, is the sentence spoken after the choice. Screen sizes are from memory.
Direction: Say what lane 1's fit suite requires in view when the sheet opens, and put the sentence where the choice is made and in what VoiceOver hears.

ID: A11Y-4
Severity: S2
Claim: In the opening §4.3 gives a new collection and three templates, the citation is drawn before the heading it belongs to, so in the web page and in Word the heading a reader navigates to neither is nor is followed by its citation, and §3.8's accessibility sentence and lane 2's check describe only the opening that has a title.
What a person meets: A reader of a web-page or Word export made under "Full text as printed", moving by headings with VoiceOver or NVDA or by Word's navigation pane. They land on "4. The Chargé in the Soviet Union (Kennan) to the Secretary of State" and read on into the telegram. Which volume, the volume's own number 475 and the link to history.state.gov were in the line before the heading; read straight through, that line is heard as the end of document 3. In the volumes before 1955 the source note's marker is before the heading too. In Word the line sits 8 points under document 3's last paragraph and 12 above its own heading, and nothing keeps it on the heading's page. In 1.0 the citation is the heading.
Evidence:
- Record §3.3, second opening (the citation "small", then "4. The Chargé … ← heading size"); "Everything of the author's stands above the first of them"; "The source note's marker stands on a line above the printed heading". §4.3's table and "A new collection starts under Full text as printed". §3.8: "the title is the document's heading, and the printed heading is a heading one level down". Lane 2's check repeats that sentence and no other.
- Today: CollectionItemHTMLRenderer.swift:296-309 (the `<h2>` is the citation, linked), :297 (`<section id>` with no name). DocxCollectionExporter.swift:689-695.
- Levels the rule does not reach: FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:741 (`<h2 class="doc-heading">`), :769 (`<h3 class="attachment-heading">`, which becomes a peer of a printed heading moved to h3), :701 (an `<h2>` "Footnotes" for each document); CollectionItemHTMLRenderer.swift:178 (sections h2 to h4, a document always h2).
- Word: DocxCollectionExporter.swift:403-405 (Normal: 8 pt after), :415-423 (Heading 2: 12 pt before, no keep-with-next; `keepNext` occurs only at :1187 and :1653). The package is six parts with no document properties (:292-306), and `w:lang` occurs nowhere in the file.
- HIG VoiceOver, fetched: "Examine your app for places where relationships among elements are visual only." WCAG 1.3.1 and 1.3.2, fetched.
- The revision made this: the first form put the citation beneath the heading (the review's A11Y-4 quotes it as "small" beneath).
Refutation: a role, a named region or an order in §3.8 that ties the citation to the heading after it, or a check for the other two openings. Read §3.3, §3.8 and §9: none. How a screen reader treats a line before a heading is from memory, not fetched. NEEDS A RUN: the second opening exported as a web page and as Word, moved through by headings in Safari with VoiceOver and in Word.
Direction: Have the plan say which line is each document's heading for navigation and keep what belongs to a document after it, or name each document's region, and write lane 2's check for all three openings.

ID: A11Y-5
Severity: S2
Claim: The gallery the record puts first is, on iPad and Mac, today's grid, whose text is fixed-point and cut at three lines, and the way into a section on iPhone and iPad is a pill in fixed 12-point type; lane 5's fit check names two iPhones and reads frames, so it passes on text that never grows.
What a person meets: iPad at AX3. The collection's settings open on six cards in 14 and 11.5 point type above title-page fields in 40. If the cards are given text styles, two columns in a form sheet hold about nine characters a line of description at AX5 (the sheet's width is from memory), which three lines cannot hold. On iPhone and iPad the one labelled way into a section's nine settings reads "Section defaults" at 12 points.
Evidence:
- Record §5.2 ("The template gallery first"); §5.4 (Templates: Mac "A grid, three rows of two", iPad "The same grid"; a section: "The heading's pill" on iPad and iPhone); lane 4 ("a plain control in today's surfaces"); lane 5's check: "Fit at AX3 and AX5 for the gallery and the rows, on iPhone 17 and iPhone SE".
- FRUSExplorer/Collections/CollectionCompositionRows.swift:289, :294 (a card: `.system(size: 14, weight: .semibold)`, `.system(size: 11.5)`), :296 (`.lineLimit(3)`), :328, :331 (a chip: 13 and 10), :49-53 (the iPad sheet forces the grid). CollectionEntryRows.swift:539 (the pill: `.system(size: 12, weight: .semibold)`), :168-171 (on every heading row).
- The project's own rule: FRUSExplorerTests/MacChromeHonestyTests.swift:339-348, "Fixed sizes ignore the user's text-size setting", which guards five files, none under Collections; a search finds ten such sites under FRUSExplorer/Collections.
- A fit assertion passes on text that did not grow: FRUSExplorerUITests/CollectionEditorTitleTests.swift:790-793, "an unrecognised category name renders at the default size and every other assertion would still pass". The project's fit suites are iPhone-only (CLAUDE.md:114, :116, :119).
- HIG Accessibility, fetched: minimum 11 pt on iOS and iPadOS; "Support larger text sizes". HIG Typography, fetched: "Keep text truncation to a minimum as font size increases"; "Reduce the number of columns when the font size increases".
Refutation: a text style on the cards or the pill, or a line that rebuilds them. Read both files and §5: none. NEEDS A RUN: the built gallery on iPad Pro 13-inch at AX3 and AX5.
Direction: Give the gallery and the pill text styles in the lane that makes them the first screen and the way in, and have the fit suite prove on the card's own label that the size took effect, on an iPad as well.

ID: A11Y-6
Severity: S2
Claim: No board draws a row's way back, its way there or its "documents differ" count as something that can be operated, and on the iPhone board the way back's words are part of a switch's name, so §11's answer to A11Y-1 holds for the words and not for the control, and §5.5 counts each row as one control.
What a person meets: iPhone, a document's settings, as drawn. VoiceOver reads "Highlights, Changed for this document · Use the section's, switch, off"; a double tap turns Highlights on for this document, which is a second change of its own and not the section's value. A tap on the words does the same, since the whole row is the switch. Text reads "From the section …" with no "Go to the section". Nothing on the board leads to which notes, which highlights or the headnote's card. Today one picker a row does both jobs: Default, On, Off.
Evidence:
- Record §4.1 rules 2 to 4 ("A changed row carries its own way back"; "offers the way there"); §4.2 ("The count opens the list of them"); §5.2 ("the headnote and its card, your notes and which, highlights and which"); §5.5 ("A document … 10, then the same"); §11, A11Y-1: "Words on the row, spoken, with the row's own way back"; lane 5 ("a way back says what it removes … Hit areas of 44 points").
- PartsPhone.dc.html:54-60 (one `<button role="switch">` holds the name and the note; the drawn switch is `aria-hidden`), :95, :100 (no way there), :92-97 (four rows; no card, no row for a note).
- OptionB.dc.html:109-115 (the note is a `div`; the switch's name is `aria-label="{{ r.name }}"` alone), :158, :163. OptionA.dc.html:140-146 (each row one `<button>`), :240-242 ("On · 2 documents differ"; "Your change · Use the template's"). OptionC.dc.html:120-126, :158, :161.
- Today: CollectionEntryInspector.swift:657-680 (one menu picker: Default, On, Off), :631-636, :444-468 (a row for each note).
- HIG Toggles, fetched: "A toggle always lets people manage the state of something, so if you need to support other types of actions … use a different component". WCAG 2.5.3, fetched.
- The project's VoiceOver suite can read an action's name and cannot perform one (Planning/UI-Test-Destinations-Runbook.md:1310-1315).
Refutation: a board or a line that draws the way back as a control of its own. Read all seven boards and §4 and §5: lane 5's check implies one, and nothing draws or counts one.
Direction: Fix each row's anatomy before lane 5 is sized: one control for the value, and where the second action lives for touch, for VoiceOver and for the keyboard, then count it.

ID: A11Y-7
Severity: S2
Claim: §11's "A check for each lane" is true of five lanes of seven, and the checks named for the Mac can be made by no suite the project has.
What a person meets: A VoiceOver user whose collection waits for its upgrade meets an editor in which nothing can be changed, one line saying why and one button, and no lane says the line is heard or the button reached. On the Mac, the focus and speech lane 6 promises are held by a walk and by no test, so a later change that breaks them fails nothing.
Evidence:
- Record §9's table has rows for lanes 1, 2, 4, 5 and 6. Lane 3 ("No screen changes but what the upgrade adds") adds: a collection that "opens for reading there, with one line saying why" (§7.3 rule 2); "not editable, with one button to upgrade it now" and the report (§7.4); "Upgrade That Version as a Copy" and a question before a delete (§7.5).
- Lane 4's check hears the exported words only; its new controls (the question with its lines to untick, Review, the wording table's eleven fields, the date line) have none. Lanes 1 and 4 name no hit-area check. No lane names a keyboard check on iPad (HIG Keyboards, fetched: "Support Full Keyboard Access when possible").
- project.yml:607-609 (`FRUSExplorerUITests`, `platform: iOS`). tools/mac-check-copy/README.md:3 ("by-eye checks"), :88 ("Leave every hover step to a person"), :117 (names read by a script).
- Planning/UI-Test-Destinations-Runbook.md:1306-1315 ("It returns the first 64 characters of what VoiceOver speaks"; "no test can make VoiceOver do a custom action"), :1342-1343 ("run each test alone, on a simulator shut down before it"). CLAUDE.md:109; :85 ("the iPhone's drill-in and the iPad's Configure sheet are different code"), so lane 5's three lists are six tests on iOS, and its table names no iPad.
Refutation: a row for lane 3 or lane 7, or a Mac UI test target. Read §9 and project.yml: none.
Direction: Add lane 3's states and lane 4's new controls to the table, and mark each check as a suite, with its devices, or a walk, with who walks it.

ID: A11Y-8
Severity: S3
Claim: The opening drawn at the head of a document's settings, which §5.2 gives as where a title typed on iPhone or iPad "is seen at once", cannot share the screen with the field at accessibility sizes, and nothing says how a VoiceOver user learns of the change.
What a person meets: iPhone at AX3. The card is taller than the space above the keyboard, so while they type a title the line that shows it is off screen. At AX5 the card is taller than the screen and two screens of it come before the first control.
Evidence:
- Record §5.2 ("this is where a title typed there is seen at once"); §5.3 (on iPad and iPhone it "is what shows a change as it is made"); lane 5's fit check names "the gallery and the rows".
- PartsPhone.dc.html:30-36 (the card: a label and four lines), :41-45 (the field under it).
- Arithmetic, mine, with the HIG's sizes fetched today: the card is about 165 px at the board's sizes, 580 to 620 pt at AX3 and 960 to 1,130 pt at AX5, against 340 to 430 pt above the keyboard (keyboard heights from memory).
- HIG Typography, fetched: "keep primary elements toward the top of a view even when the font size is very large".
Refutation: NEEDS A RUN: the built screen on iPhone 17 and iPhone SE at AX3 and AX5 with the title field focused; and with VoiceOver, type a title and note what is spoken.
Direction: Say what the card shows at accessibility sizes and what VoiceOver is told when its lines change, and put the card in lane 5's checks.

ID: A11Y-9
Severity: S3
Claim: Three controls the lanes keep or add fall outside every check in §9's table and break the project's own rules as they stand: the list's Export… is a context-menu item with no VoiceOver action, the per-note and per-highlight switches all speak one name, and the pill §5.4 makes the way into a section is about 24 points high.
What a person meets: VoiceOver on iPhone. On the Collections list a row offers no Export action, as it offers none for Rename or Duplicate today. In a document with five notes, five switches each say "Include this research note when notes apply". A finger on "Section defaults" has a target about half the 44 points lane 5 asks of its new rows.
Evidence:
- Record §5.1 ("Export… in a collection's context menu", with Export Again "beside each of those"). FRUSExplorer/Collections/CollectionListView.swift:333-387 (a tap gesture, a swipe and a context menu; no accessibility action). The project's rule: CollectionEntryRows.swift:1028, "also exposed as a VoiceOver action, since a context menu alone is not" (:1040-1043).
- Record §5.5 ("then the same"). CollectionEntryInspector.swift:446-460 and :501-515 (each switch: `.labelsHidden()`, `.controlSize(.mini)`, one shared label).
- CollectionEntryRows.swift:537-547 (the pill: 12-point type, 5 points above and below). `minimumHitTarget()` (FRUSExplorer/Theme/ControlHelp.swift:252-270) is used nowhere under FRUSExplorer/Collections. HIG Buttons, fetched: "a button needs a hit region of at least 44x44 pt"; HIG Accessibility, fetched: 28x28 pt minimum on iOS and iPadOS.
Refutation: an accessibility action on the list's row, a per-note name, or a hit shape on the pill, in the code or in a lane's row. Searched: none. Whether VoiceOver's long press opens the row's menu is from memory, not fetched.
Direction: Name these three in lanes 1 and 5, each with the suite that holds it.

§11 rows in my scope
- A11Y-1 (the dot): PARTLY. The words are on every row of every board and no hidden dot remains; the way back is text on all four boards that have rows (A11Y-6). The outline row's named chips, which the review asked to keep and the Mac manual describes (Docs/macOS-User-Manual.md:828), are on no board and in no line.
- A11Y-9 (the PDF): ANSWERED, as a statement. The sheet still opens on PDF for a first export (Main.dc.html:94), and the two formats called accessible have the gaps of A11Y-1 and A11Y-4 here.
- A11Y-10 (two pinned buttons): PARTLY. One is pinned; by the HIG's AX5 sizes the title block and one look still exceed the list's viewport (A11Y-3). It needs the run.
- G16 (no lane carries a check): PARTLY. Five lanes of seven, and the Mac's by walk alone (A11Y-7).
- G4 (A11Y-2's half, the scope where a change is made): ANSWERED. No scope control; each surface is titled by what it holds; each row names its source.
- G9 (A11Y-3's half, a mark that is spoken): ANSWERED for the title. The date line under it and the number have no words on the page.
- G12 (A11Y-4's half, identical headings): PARTLY. The number tells them apart only where Numbering is on and only if the contents list's own numbers agree with it (A11Y-1); Word waits on §12's run.
- G13 (A11Y-7, names with no margin): ANSWERED. Mac only, names on each outline's corner (OptionC.dc.html:62-97). What it left is the focus rule (A11Y-2).
- G6 (A11Y-5's half, a control that shows what is in force): PARTLY. Both document boards show Opening as "Your title leads", dimmed (OptionB.dc.html:162; PartsPhone.dc.html:99), a value §4.1 does not list, where rule 5 says such a row "keeps its value".
- G3 (A11Y-6, a smart collection): ANSWERED in §4.5's text; see the last line of this report.

Attacked and held
- Text contrast on the seven boards: every text pair is 5.2:1 or better by WCAG's formula (lowest #e6eeff on #0A5BD3, 5.23:1, OptionA.dc.html:39; the changed note's #8a4107 is 7.39:1 on white and 6.70:1 on a selected row).
- The mark is words: "Printed heading:" is text inside the heading line wherever it is drawn (Marks.dc.html:83; OptionB.dc.html:70, :92; PartsPhone.dc.html:35; OptionC.dc.html:78), so it survives speech, braille and copying.
- No change is told by colour or a dot alone: every changed row carries "Changed for this document" or "Your change" besides its colour, and the only elements hidden from assistive technology are chevrons, a check that repeats `aria-pressed`, a switch's drawn knob and an ellipsis (a search of all seven boards).
- Sizes as drawn: every control on the two iPhone boards is 44 px or more (Main.dc.html:19, :34, :50, :53, :66; PartsPhone.dc.html:20, :25, :43, :48, :54, :69); the Mac boards' controls are at or over the HIG's 20 pt minimum for macOS and their smallest type is at its 10 pt minimum (HIG Accessibility, fetched).
- The scope is not a mode: no board has a scope control, the phone's bar reads "Document 475" (PartsPhone.dc.html:24), each Mac column names what it holds (OptionA.dc.html:95-96; OptionB.dc.html:83; OptionC.dc.html:115), and each of the nine parts that has a setting has a row (OptionC.dc.html:153-163).

Not read
- Both manuals beyond a search for numbering and the contents list; Docs/EditableContent; the plan of record; the designs under Planning/Completed.
- CollectionAddDocumentsSheet.swift, CollectionRichTextEditor.swift, CollectionPickerSheet.swift beyond a search; CollectionEditorView.swift outside :690-1109; MacCollectionManagerView.swift outside :846-1175, :1262-1391, :1640-1814 and :1985-2117; CollectionEntryInspector.swift from :1139; CollectionPreviewView.swift outside :780-932 and a search; DocxCollectionExporter.swift outside :56-155, :284-345, :384-470, :672-700 and :1856-1925; PDFCollectionExporter.swift outside :228-240 and :560-709; the serializer outside :684-783 and a search.
- The runbook outside :312-331 and :1276-1357; the UI suites' sources beyond searches; the first review's INT, ENG, DATA and EDI reports and skeptics A and B.
- Not fetched: how VoiceOver, NVDA and JAWS speak a list's markers or a line before a heading; macOS's default for keyboard navigation and what a text field selects when focused by code; iPhone and iPad screen, sheet and keyboard sizes.
- Nothing was built or run. Every fit figure is arithmetic at half an em a character.
- Where things are: the tree is /home/user/FRUS-Explorer; the boards are in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project; the HIG pages (from developer.apple.com as .md) and WCAG criteria (from w3c/wcag on GitHub) I fetched today are in /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/fetch-A11Y; my three scripts are /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-A11Y/sheet_fit.py, /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-A11Y/card_fit.py and /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review2/scripts-A11Y/contrast.py.

Outside my scope
- EDI and ENG: §7.4 and §4.3 call 1.0 "no numbering", but 1.0 numbers the contents rows of all three formats (PDFCollectionExporter.swift:630-638; DocxCollectionExporter.swift:1899-1906; the web page's `<ol>`), so "Numbering: Off" either takes numbers off an upgraded collection's contents list or leaves numbers on.
- EDI: the author's date line and the collection's number carry no words on the page (§3.3, third opening), only the Note on the Text, which may be removed (§3.6); and §5.2's wording table lists "Printed heading", the mark §3.6 says cannot be removed, among the words an author may rename.
- INT: §4.5's "Selecting one" has nothing to select, since a smart collection's Contents lists only its apparatus (FRUSCoreKit/Collections/CollectionOutline.swift:48-49; MacCollectionManagerView.swift:1312-1315).