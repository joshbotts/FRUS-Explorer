ID: A11Y-1
Severity: S2
Claim: On both inspector boards, that a part is changed at this scope exists only as a 6–8 px dot hidden from assistive technology, where the shipping app says it in words on the control and on the outline row.
What a person meets: iPhone or Mac, with VoiceOver or unable to make out a 6 px dot. The template row says "1 change" and the outline row "Document 475 · … · 1 change". Each of the ten rows then reads as its name, its value and on or off; none says it is the changed one, which layer it departs from, or offers to reset it alone. Today the same person hears a picker's value as Default, On or Off, and reads "Notes off", "Highlights off", "Summary" as named chips on the row.
Evidence:
- Record §3.2 rule 3: "A dot marks a part that differs … and the part's detail says which layer: Changed for this document. The section shows footnotes." §4.3 gives a detail to five parts only ("the heading's choice and text, the dateline's, which notes, which highlights, the headnote's card"), so the record's own example, footnotes, has none.
- PartsPhone.dc.html:47 (the dot, `aria-hidden="true"`), :62 (its empty place on an unchanged row); OptionB.dc.html:146, :166 the same; :169 the switch's `aria-label="{{ r.name }}"`; :168 the value ("Hidden", "4 notes"). The only words are counts (OptionB:138, :54; PartsPhone:41).
- Reset "for one part" (§3.2 rule 4) is drawn only in Option C's popover (OptionC.dc.html:222); each inspector has one Reset, for the scope (OptionB:139, PartsPhone:42).
- Today: CollectionEntryInspector.swift:657-680 (Default / On / Off as the value), :631-636 ("Default → On"); CollectionEntryRows.swift:1158-1215 and :1124-1126 ("the word alone … carries the meaning").
- The project's own rule: Plan-Of-Record-2026-11-15.md:306 ("where the mark is the whole of the feedback, says …").
- WCAG 1.3.1, and HIG Accessibility: "Perceivable. Your interface doesn't rely on any single method to convey information." Both fetched today (WCAG from W3C's GitHub repository).
Refutation: a line of the record or a board that gives every part's changed state as text or an accessibility value. Checked the record ("dot" occurs in §1, §3.2 and §4.3 only) and all seven boards: none.
Direction: Say the change on the row in words, visible and spoken, naming the layer it departs from; give each row its own Reset; keep the outline row's named chips rather than a count.

ID: A11Y-2
Severity: S2
Claim: The scope a switch writes to is a mode set in a segmented control at the head of a list that scrolls, and on the iPhone board nothing at a row, in the title or on Reset says which scope is in force.
What a person meets: iPhone, VoiceOver or an accessibility text size. In Document 470's inspector they tap "Collection" to see what the collection does, move down to "Footnotes" (ten-odd swipes, or about three screens at AX3 on an SE by my arithmetic) and turn it off, meaning this document. It goes off for every document. "Reset" now clears the collection's changes, not the document's. The title still reads "Document 470".
Evidence:
- Record §3.2 rule 2 ("Changing it stores a change at the scope being edited. The scope is a choice of three at the head of the inspector") and rule 4 (Reset "for one part or for the scope"). §4.4 credits the popover because "choosing the scope at the moment of change teaches the cascade in plain words".
- PartsPhone.dc.html:24 (title), :30-34 (scope), :42 ("Reset"), :61-114 (rows: name, value, switch). By its own sizes the board holds about 850 px of content in an 844 px frame with no status bar or home indicator, so it scrolls at the default size.
- The Mac board has a caption, "WHAT DOCUMENT 470 SHOWS" (OptionB.dc.html:142, :228-233), which scrolls with the rows; the iPhone board has none.
- Today each scope is its own titled group: CollectionEntryInspector.swift:786-808 ("Export Overrides", "Section Defaults"), :245-249 ("Collection" … "These settings apply to the whole collection.").
- HIG Typography, fetched today: Body is 40 pt at AX3 and 53 pt at AX5; "keep primary elements toward the top of a view even when the font size is very large, so that people don't lose track of these elements."
Refutation: the scope stated where each control is operated, or a list that cannot scroll. Checked the record and the board: neither. That a system segmented control's titles do not grow with Dynamic Type is from memory, not fetched. NEEDS A RUN: the built inspector at AX3 and AX5 on an iPhone SE, and one VoiceOver pass from the scope control to the last row.
Direction: Name the scope where the change is made, in a pinned header and in each control's spoken label, and make Reset say what it resets.

ID: A11Y-3
Severity: S2
Claim: The recommended mark is punctuation that a screen reader does not speak at its default, so a listener hears the compiler's heading as the document's, and the Note on the Text's key points at a sign they never heard.
What a person meets: A reader of the web-page export with NVDA as shipped hears "heading level 2, The Long Telegram", then the reference and the text, and at the end "Headings and datelines in square brackets are the compiler's." With the dagger they would hear "The Long Telegram dagger", in a page where a dagger already means two other things.
Evidence:
- Record §5: brackets "need no key, cost no line, and survive every format"; "A replacement with no mark is not offered, as an AI summary without its line of attribution is not". That attribution is a line of words (CollectionItemHTMLRenderer.swift:365).
- Marks.dc.html:30, :40 (brackets and their Note), :88, :98 (dagger).
- NVDA, fetched today from nvaccess/nvda master: source/locale/en/symbols.dic:80-81 "[ left bracket most", "] right bracket most"; :180 "† dagger some"; source/config/configSpec.py:38 `symbolLevel = integer(default=100)`, which characterProcessing.py:160 names SOME.
- In this app's own page: † is a printed footnote label on 944 notes (FRUSRenderNodeHTMLSerializer.swift:240), and the mark of a dead cross-reference, where the code hides the glyph and speaks a label (:931-935, `aria-hidden="true"` beside `aria-label`).
- The volume's supplied words already print in brackets (same file :843-844), and the board's own volume dateline carries them (Marks.dc.html:26, "[Received 4:58 p.m.]"). So "in square brackets are the compiler's" is not true of every bracket a reader meets.
Refutation: a spoken form for the mark in the record, or screen readers that speak brackets by default. The record has no word on an export read aloud. NVDA checked. VoiceOver and JAWS could not be fetched. NEEDS A RUN: `[The Long Telegram]` as a heading, read by VoiceOver on iPhone and Mac at default punctuation.
Direction: Give the mark words in the markup, as the dead-reference dagger has, or make "Printed heading:" the web page's form; and withdraw the dagger from Q2.

ID: A11Y-4
Severity: S2
Claim: Under Q4's recommended default a document's only heading is the volume's, so same-headed documents get identical headings with the number in none of them; and Word rebuilds its contents list from those headings, which makes §3.5's "Word's contents rows come from the same label as the other two" false after Word's first update.
What a person meets: The record's own eight Kennan telegrams, exported as "Full text as printed". A screen-reader user's heading list is "The Chargé in the Soviet Union (Kennan) to the Secretary of State" eight times; today each document's first heading ends "Document 470." In Word, the contents field is rebuilt on first open: eight identical rows whatever contents style or short citation was chosen, or no documents at all if the volume's heading stays Heading 3.
Evidence:
- Record §2.2 (eight documents, one heading); §3.3's table and Q4 ("The volume's heading", with the citation "small" beneath); §3.5 (the plan carries each part's "final text, its label and its mark": no role, no level).
- Web page: FRUSRenderNodeHTMLSerializer.swift:740-741 (`<h2 class="doc-heading">`); today's first heading is the citation (CollectionItemHTMLRenderer.swift:296-309); sections are h2 to h4 (:178); "Footnotes" is another h2 per document (serializer :701).
- Word: DocxCollectionExporter.swift:691 (the document's heading, Heading2), :1124-1127 (the volume's, Heading3), :1873-1874 (`w:dirty="true"`, `TOC \o "1-2" \h \z \u`), :1865 ("causes Word to rebuild on first open"), :75-82 (why Heading3 is kept out of the field).
- The project rated identical rows for these same telegrams S2 and fixed them by prefixing the number: Planning/UI-UX-Adversarial-Review-2026-11-15.md:358-360 (MAC-5).
Refutation: a plan that gives the lead heading the document's number, or Word's field replaced by rows the app writes. Neither is in the record. NEEDS A RUN: a .docx with the volume's heading leading, opened in Word and its field updated.
Direction: Put a level and a distinguishing number into the plan's heading, and decide in lane 2 whether Word keeps a field or takes the plan's rows.

ID: A11Y-5
Severity: S2
Claim: The inspector boards cannot show what is in force for the two parts the owner named: Heading has four values in §3.1 and three segments on every board, the missing one being what every existing collection has; Dateline has three values and is drawn as a switch, with no way in to type one.
What a person meets: iPhone or Mac, an existing collection. The Heading control shows nothing selected (VoiceOver: three unselected buttons, "Volume's", "Citation", "Your own"), though its documents print the citation and then the volume's heading. To give a dateline of their own in the inspector there is nothing to tap: on the iPhone the whole row is the switch. "Dateline, As printed, on" is all VoiceOver can say, whether the dateline is the volume's or theirs.
Evidence:
- Record §3.1 (Heading: four choices, the third "today's, and what an untouched collection keeps"; Dateline: "As printed · Your own · Hidden"); §3.3 ("A collection that exists today keeps The citation, then the volume's heading"); §3.2 rule 1 ("It shows what is in force").
- OptionB.dc.html:236-240 and PartsPhone.dc.html:51-53 (three segments); OptionB:200 (`on: 'As printed', off: 'Hidden'`); PartsPhone:67-72 (`role="switch"` on the row's whole button, as on seven more rows). Only Option C's popover has the dateline's three and its field (OptionC.dc.html:270, :206-212).
- Widths: three segments are 109 px each in the 334 px card; a fourth leaves 81 px.
- PartsPhone:32-33 already shortens the record's "This section" and "Whole collection" to "Section" and "Collection"; whichever becomes the spoken name, Voice Control needs the other as an input label (the project's own A11Y-5, review :372-377).
- HIG Toggles: "choose between two opposing values … if you need to support other types of actions — such as choosing from a list of items — use a different component". HIG Segmented controls: "Use nouns or noun phrases for segment labels." Both fetched today.
Refutation: a board or a line of the record with the fourth heading value and a dateline control in the inspector. Checked all seven boards.
Direction: Draw each many-valued part as a control that names its current value in full, a menu or a pushed list, before lane 4 is sized.

ID: A11Y-6
Severity: S2
Claim: In a smart collection the tap has no row to select and no document scope to open, because its documents are search results with no stored entry.
What a person meets: (Outside accessibility; met while attacking the hand-off.) Any platform, a collection linked to a saved search. The preview shows its documents and Adjust outlines their headings, but the outline lists only apparatus, and "This document" and a heading of one's own have nowhere to be stored.
Evidence:
- Record §4.5 ("selects that document's row in the outline and opens the inspector on that part, at document scope"); §3.4 (a document's display is kept in `CollectionEntry.displayJSON`). The record's one mention of smart collections is §2.4's count.
- CollectionContentAssembly.swift:502-515 ("Synthetic entries have no per-entry overrides or note selections").
- Collection.swift:1009-1022 (`leavesOut`: a document or heading entry in a linked collection is one "the resolver never reads").
- CollectionEditorView.swift:1150-1151 ("A smart collection's are only the entries it keeps, its apparatus"); MacCollectionManagerView.swift:1797-1803 ("a smart collection has nothing to inspect"); the preview's smart path, CollectionPreviewView.swift:462-477.
Refutation: a rule for smart collections in the record. Searched it for "smart" and "saved search": nothing in §3 to §9.
Direction: Say what a smart collection may adjust, and where a change to one of its documents would be kept, before lane 3 fixes the storage.

ID: A11Y-7
Severity: S2
Claim: Adjust's part names have no margin to stand in on any iPhone or iPad layout, nor in the Mac's three-column window at the board's own 1,280 px; and as drawn its labels and chips are under the HIG's minimums for iPad.
What a person meets: iPad, where the record adds Adjust for fingers. The page fills the preview pane, so the names must sit on the text or reflow it, and the page is then not the page that exports. "Heading" and "Reference" are 10 px labels that do not follow Dynamic Type. The "Not printed" chips are 24 px high, under a footnote that itself reads "Not printed."
Evidence:
- Record §4.4 ("its name in the margin beside it"; added because "a finger does not have" a pointer); §4.6 (iPad: "or tap it in the preview").
- OptionC.dc.html:19 (`left:-118px; width:84px; font-size:10px`), :20 (`height:24px; font-size:11px`), :80 (a 104 px gutter), :82 (a 600 px page in 12 px type). The board's 1,000 px are gutter 104, page 600, popover column 264 and gaps; with the hybrid's inspector column (minimum 340, CollectionEntryInspector.swift:263) the preview is 660 px and even this shrunken page with its gutter needs 704.
- The real page: `max-width: 780px; margin: 0 auto; padding: 2rem 1.5rem` under a device-width viewport (CollectionItemHTMLRenderer.swift:819-825, :694), at one fixed text size (:801; `-webkit-text-size-adjust: none`, ReaderPage.swift:376). The iPad's outline takes up to 460 pt (CollectionEditorView.swift:845).
- The phrase: OptionC.dc.html:151 and :169 against :176.
- HIG Accessibility, fetched today: minimum type 11 pt on iOS and iPadOS; controls "44x44 pt" by default and "28x28 pt" at least. The app's own rule is 44 pt on iPhone and iPad (ControlHelp.swift:255-257).
- The dashed outline, computed: 3.25:1 on white; 2.95:1 on the summary block's #f0f4ff (CollectionItemHTMLRenderer.swift:919).
Refutation: a board of Adjust at iPad or iPhone width, or a layout with a gutter of 118 px beside a 780 px page, which needs a preview about 970 px wide (device widths from memory, not fetched). canvas.json lists seven boards and none is one.
Direction: Draw Adjust for a touch layout, with each name on its own outline and 44 pt targets, before lane 5 is sized; and give the strip a name that FRUS's notes do not use.

ID: A11Y-8
Severity: S2
Claim: The record states no focus or speech behaviour for either form of the tap, and §8 lists no accessibility check for any lane, though the project's rows for comparable changes carried them.
What a person meets:
- Form (i), the inspector. On iPad it is a sheet over the page at every tap; VoiceOver lands at the sheet's top, not "on that part", and returns to a page that has reloaded whole. On the Mac the column changes and nothing is said.
- Form (ii), the popover. A second set of controls to label and test, so §4.5's "one set of controls to build, test and translate" becomes two; its one board is Mac-sized (26–32 px controls, OptionC.dc.html:193, :202, :217, :222); and the HIG keeps popovers off compact widths, which an iPhone and an iPad form sheet both are (CollectionCompositionRows.swift:51-52).
Evidence:
- Record §4.5 ("opens the inspector on that part"; "the preview keeps its place when the page reloads", which is scroll); §4.6 ("the inspector as a sheet, as Configure is now"; CollectionEditorView.swift:863-873).
- CollectionPreviewView.swift:882-887 (`loadHTMLString` at every change). FRUSExplorer/Collections posts one announcement (CollectionPickerSheet.swift:476) and moves VoiceOver's focus nowhere; the app's one `@AccessibilityFocusState` is UserTagPickerSheet.swift:90. ControlHelp.swift:148-153 records that an announcement posted as a sheet opens "can be dropped or cut off".
- §8, "What each lane owes", names pins, the CloudKit gate, strings, captures and "the six in CollectionEditorTitleTests.swift". None of the six listens to VoiceOver.
- What comparable rows carried: Plan-Of-Record-2026-11-15.md:277-278, :286, :306, :473 (a VoiceOver case, 44 pt hit areas with a suite, fit runs on the iPhone 17 and the SE, a look at AX3). CLAUDE.md:89 and :109 (each VoiceOver test alone on a simulator shut down before it, 600 s a test), :95, :116, :119 (hit areas; fit at AX3 and AX5), under :31's one heavy job at a time.
- `CollectionExportContrastTests` lists every text rule of the export's stylesheet with its ground and counts them (FRUSExplorerTests/FRUSCoreKit/ReaderPageTests.swift:690-734), so lane 3's and lane 5's CSS owe it entries.
- HIG VoiceOver: "Inform VoiceOver when visible content or layout changes occur." HIG Popovers: "Avoid displaying popovers in compact views." Both fetched today.
Refutation: an accessibility item in §8, or focus and speech stated for the tap. Read §4.5, §4.6 and §8 whole: none. NEEDS A RUN: with VoiceOver on a document in the preview, change a switch and return; where does the cursor land?
Direction: Add the focus rule, the announcement and their suites to lanes 4 and 5, and size the lanes with them.

ID: A11Y-9
Severity: S3
Claim: The format the quick path defaults to is written with no tags, title, language or links, and lane 2 redraws it from a plan that knows each part's role without adding any.
What a person meets: A reader with a screen reader, given the two-tap export: a PDF with no headings to move by and no document title. The mark, the reference's address and the Note on the Text are glyphs in reading order.
Evidence:
- Record §4.1 ("exports as a PDF with no choice made"); §3.5 ("A format keeps its own typography and pagination, and nothing else").
- PDFCollectionExporter.swift:236 (`CGContext(consumer: consumer, mediaBox: &mediaBox, nil)`: no document information); :99-102 ("bare CoreText frame drawing has no link annotations"). No `CGPDFContextBeginTag`, title or outline call anywhere under FRUSExplorer/ or FRUSCoreKit/ (searched).
- How reading software treats an untagged PDF is from memory, not fetched.
Refutation: a tag or metadata call in the exporter, or a line of §3.5 or §8 that adds one. Checked both.
Direction: Let the plan's parts carry a role that the PDF writes as tags, or say in the record that the accessible export is the web page.

ID: A11Y-10
Severity: S3
Claim: The export sheet pins two full-width buttons under a scrolling list of six or seven two-line rows, and at the accessibility sizes the project tests on an iPhone SE the dock leaves less than one template row in view.
What a person meets: iPhone SE at AX5. "Change what each document shows" (31 characters at Callout, 51 pt) runs to about three lines and the export button to one or two, so the dock takes some 300 of 667 pt and the templates scroll through a slot shorter than one row. Today's sheet is one Form with the button inside it.
Evidence:
- Main.dc.html:24 (the scrolling region), :33-41 (rows: a 16 px name over a 12.5 px line), :61-64 (the dock outside it, 50 px and 44 px buttons).
- CollectionExportSheet.swift:342-397 (today: a `Form`, the button in a `Section`).
- HIG Typography, fetched today: AX5 Body 53 pt, Callout 51 pt, Caption 1 43 pt; "Make sure your app's layout adapts to all font sizes."
- The same pattern is in the project's backlog: Planning/UI-UX-Adversarial-Review-2026-11-15.md:389 (IPH-9), :386 (IPH-6).
- The line counts are my arithmetic at half an em a character; the SE's 375 × 667 pt is from memory.
Refutation: NEEDS A RUN: the built sheet at AX3 and AX5 on an iPhone SE (3rd generation), with a template row and both buttons in view.
Direction: Keep only the export button pinned, and let the second action scroll with the list.

**Attacked and held**
- Text contrast as drawn: every text colour on the seven boards is 5.2:1 or better on its ground (lowest, #e6eeff on #0A5BD3, OptionB.dc.html:41; secondary #5a5a60 6.1–6.9:1; the margin tags 8.8:1), computed with WCAG's formula.
- Touch targets on the two iPhone boards: every control is 44 px or more (PartsPhone.dc.html:20, :31, :42, :56, :61; Main.dc.html:19, :34, :49, :52, :62-63).
- Nothing is told by colour alone to a sighted reader: the dot is present or absent at 5.0:1 (OptionB.dc.html:166), the chosen template has a check (Main.dc.html:39), the format retitles the button (:95-97), and Adjust reads "Adjust: on" (OptionC.dc.html:308).
- The second route holds for form (i): nothing in the web view is editable (§3.6, item 1), and all ten parts and both collection groups are native rows (§4.3). Only the per-part Reset lives on the page alone, and only in form (ii).
- "Printed heading:" (mark 2) is words, so it survives speech and plain text; and every mark is characters in every format, so a braille display shows the brackets.

**Not read**
- Both manuals' chapter 12 and Docs/EditableContent; Planning/UI-Test-Destinations-Runbook.md's entries.
- CollectionAddDocumentsSheet, CollectionRichTextEditor, and CollectionPickerSheet beyond one line; MacCollectionManagerView outside :1020-1130, :1640-1810 and :1985-2117; the Word exporter beyond its headings and contents field; the PDF exporter beyond its context and header comments.
- VoiceOver's and JAWS's punctuation defaults, and w3.org itself, could not be fetched. The WCAG wording is from W3C's GitHub repository; the HIG pages fetched today as Apple's .md were accessibility, voiceover, typography, toggles, segmented-controls and popovers.
- Nothing was built or run.