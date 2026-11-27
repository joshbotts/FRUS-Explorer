Reviewer A11Y, third review of the Collections design (row CR). Read in REPO at claude/cr-collections-review-3 (0fa40e16), the boards under SCRATCH/canvas/project/, and the public TEI at 216cdb764. Nothing was built or run. Scripts are in /private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-l25-collection-templates-8f58f6/f6d777ba-c969-4f0e-bff4-c72a64a567ce/scratchpad/review3/work-A11Y/ (called work-A11Y/ below). Pages "fetched today": Apple's HIG Typography, Accessibility and VoiceOver pages (their JSON at developer.apple.com/tutorials/data/design/human-interface-guidelines/), Apple's CGPDFTagType page, WAI-ARIA 1.2's button role, the WHATWG HTML parser's in-body rule for a button start tag, and PowerMapper's tagged-PDF headings test.

ID: A11Y-1
Severity: S2
Claim: Under the opening that four of the six document templates and every new collection take (decisions 158, 159), a reader who moves by headings in the web page or in Word lands on the volume's heading and skips the citation line before it, which is the one line that tells same-headed documents apart; 56.4% of the corpus's documents share their heading's words with another document of their volume, and §3.8's answer, a region named by the heading, names them all alike and has no counterpart in Word.
What a person meets: A VoiceOver user in Safari (or NVDA in a browser) opens the web page of a collection of frus1946v06's eight telegrams made under Full text as printed, or of any new collection. The headings rotor lists "The Chargé in the Soviet Union (Kennan) to the Secretary of State" eight times, and the landmarks rotor lists eight regions with that name. Only the small citation line above each heading says which is document 475, and H or VO-Command-H jumps past it. In Word, the Navigation pane lists the same eight headings. Each citation line is a Normal paragraph before its heading, so Word files it under the document before it (it collapses and moves with document N−1; from memory, not fetched), and nothing keeps it on its heading's page. In 1.0 the heading is the citation, which ends in the document's number.
Evidence:
- Design §3.8, lines 396-397: "The line that leads a document is its heading." and "Where the volume's heading leads, the citation is a line before it. The plan names each document's region by its heading, so that a reader moving by headings is told which document the line belongs to." §3.3 line 312: "No number stands at a document's head." §2.2 line 147: the eight telegrams "all carry one heading".
- Decisions 158 and 159 (plan lines 100-104).
- §9 line 1013: "In the web page and in Word, for each of the three openings: which line is the document's heading … | A kit test over the plan and the HTML". L34's brief (plan line 641) owes the same kit test. Neither names a test over the Word package, although A12's check has one (line 1022).
- Today: CollectionItemHTMLRenderer.swift:301-309 (the citation is the document's <h2>); DocxCollectionExporter.swift:691 (the citation is Heading2) and :1126 (the volume's heading is Heading3); :415-423 (Heading2 has no keepNext). keepNext appears only for a figure's head and a table's caption (:1187, :1653), "so a page never ends on the caption with its table on the next".
- TEI count (work-A11Y/same_headings.py, over the manifest's 553 volumes: the first <head> of each <div type="document">, with notes removed and tags stripped). 314,605 documents have a heading, and 177,389 of them share its words with another document of the same volume, in 292 volumes. Before 1952 that is 171,402 of 222,185 (77.1%); from 1952, 5,987 of 92,420. frus1946v06's commonest heading occurs 45 times.
- History: the first review's A11Y-4 raised identical headings (collections-design-review/reviewer-A11Y.md:43). The second form answered it with a number at each head, which this form removed (§3.3; H14). §11 line 1124 answers the second review's A11Y-4 with the named region alone.
Refutation: A rule in §3.8, L34 or L43 that gives each document's heading or region a name that differs from document to document, or a Word rule for the line, would refute this. I read §3.3, §3.8, §9, §11, L34 and L43 and found none. NEEDS A RUN: the eight telegrams under Full text as printed, moved through by headings and by landmarks with VoiceOver in Safari, and in Word's Navigation pane.
Where it is answered: §3.8 and §11 answer it, for the web page's region only. L34's brief must say it.
Direction: Give each document's heading in the web page and in Word something a navigator hears that tells it apart (in HTML the region's name or the heading's description can carry the citation's number without printing anything new), keep the citation line with its heading in Word, and hold both with a kit test over the HTML and the Word package.

ID: A11Y-2
Severity: S2
Claim: At AX3 and AX5 on an iPhone, the settings a document template changes, the line that says so and its Undo sit one to four screens below the card that was tapped, and step 2's shortcuts rewrite up to nine ticks as far below them; the design dropped a template's question because each change is "shown where it is made", yet no check holds what is in view after a choice, and step 2's Undo is on no board and in no check.
What a person meets: On an iPhone SE at AX5, without VoiceOver, a person taps Full text as printed near the top of step 1. Nothing on screen changes except the card's checkmark. The line "Full text as printed applied. 2 settings changed…" and its Undo are about 2,400 pt down, below the other five cards, and the seven settings that changed run from about 2,900 to 4,800 pt. In step 2 they tap None. The ticks it clears run from about 1,000 to 3,300 pt, and each cleared block's row loses its place in the outline.
Evidence:
- The design's head, line 33: "The question a template asked before it changed a collection is gone. Each step's change is small, shown where it is made, and undone there (§4.3)."
- §4.3: line 475, "Step 1 changes the seven settings, in view … A line says what changed, old to new, with Undo while the screen is open"; line 478, "its place is all that is lost"; line 480, "A shortcut does both, in view, with Undo". §5.6 line 657. L44's brief (plan line 673): "Choosing one changes the seven in view, with a line that says what changed and Undo".
- §9 lines 1016-1017: the fit check is "Step 1's cards and the section pill at AX3 and AX5, proved on the card's own label", and the spoken check is "the line that says what a template changed is spoken when it appears". Neither covers step 2's shortcuts or what is in view after a choice.
- Board TwoSteps.dc.html: the line and Undo come after the six cards (:30-44) and the settings after them (:45-55). Step 2's column (:69-103) has shortcuts (:71-75) and no line or Undo anywhere. The board's Undo is 32 px tall (:43) and the shortcuts 40 px (:72-74). The HIG (fetched today) gives "iOS, iPadOS | 44x44 pt" as the default control size, and SearchHitAreaTests holds 44 pt (.claude/rules/ui-tests.md:45). §9's hit-area check names only the section pill.
- Arithmetic (work-A11Y/steps_fit.py): HIG sizes fetched today (Body 40/48 at AX3 and 53/62 at AX5; Footnote 33/40 and 44/52), half an em a character, margins from memory. On an iPhone 17, step 1's line falls at about 1,380 pt at AX3 and 2,230 pt at AX5; on an SE, at about 1,520 and 2,410, against about 685 and 554 pt of screen. Step 2's ticks run from about 900 to 3,130 pt on the iPhone 17 at AX5. At the default size the line is in view, at about 420 pt.
- HIG Typography, fetched today: "keep primary elements toward the top of a view even when the font size is very large, so that people don't lose track of these elements." HIG VoiceOver, fetched today: "Inform VoiceOver when visible content or layout changes occur."
Refutation: A rule that places the line and Undo where the choice was made, or a check of what is in view after a choice at AX3 and AX5, would refute this. I read §4.3, §5.2, §9 and L44 and found none. NEEDS A RUN: the built steps on an iPhone SE and an iPhone 17 at AX3 and AX5, with a card and then None tapped and the frames read.
Where it is answered: L44's brief must say it.
Direction: Put each step's line of change and its Undo where the control that made the change is, for step 2's shortcuts as for step 1's cards, and add what is in view after a choice to L44's fit suite.

ID: A11Y-3
Severity: S2
Claim: Built as §8.1's item 13 says, "as the reader draws its Research rail since R6a", the iPad's settings column is 280 pt wide at every text size, so at AX5 a document's eight pickers take about 2,900 pt and the drawn opening L45 puts above them about 2,950 pt more, some six landscape screens of an iPad Pro 13-inch before the first control; no check in §9 names the iPad's column, its pointing, or the drawn opening there.
What a person meets: On an iPad at AX5 the document's settings are a narrow column beside the preview. "Follow the collection: Brief summary" wraps to about five lines, and the drawn opening's citation alone runs to some twenty. Reaching Footnotes takes several screens of scrolling inside the column. The form sheet the column replaces is about twice as wide.
Evidence:
- Design §8.1 item 13, line 790: "a settings column on iPad with pointing there, as the reader draws its Research rail since R6a".
- §5.3 lines 587-593; §5.6 line 653: the drawn opening "could not share the screen with the field at the largest text sizes".
- §9 line 1020: lane 6's check is the Mac's alone, "A walk".
- L45's brief (plan lines 685-691): "this row shows it at AX3 and AX5 before it builds it", which names no device and no rule for going on, and "a suite on the iPad", which names neither devices nor assertions.
- The rail it is modelled on: BrowseTwoPaneMetrics.swift:97-100, "drawn at this width and never compressed", with researchRailWidth = 280. DocumentView.swift:426 (railIsSheet is isPhone || horizontalSizeClass != .regular, a width rule and not a text-size rule) and :1071-1076 (.frame(width: Self.railColumnWidth)).
- Today the iPad shows a document's settings as a sheet (CollectionEditorView.swift:863-873), beside an outline of at most 460 pt and the preview (:837-855). PartsPhone.dc.html:81-89 gives the rows' words.
- Arithmetic (work-A11Y/ipad_column_fit.py; HIG sizes fetched today), in 248 pt of text: about 12 characters of Body a line at AX3 and 9 at AX5. The eight pickers take about 1,810 and 2,900 pt. The drawn opening (title, date line, the citation in Footnote, "As published:" and the heading, the dateline) takes about 1,760 and 2,950 pt. In a 540-pt sheet (width from memory) the same take about 1,090/780 and 1,660/1,400 pt.
- HIG Typography, fetched today: "Reduce the number of columns when the font size increases to avoid truncation and enhance readability."
Refutation: A width or a rule for the column at the accessibility sizes in §8.1, §5.3 or L45, or a fallback to the sheet, would refute this. I read them and found none. NEEDS A RUN: the built column on an iPad Pro 13-inch and an iPad mini at AX3 and AX5.
Where it is answered: L45's brief must say it.
Direction: Say in L45 what the iPad's column does at the accessibility sizes (falls back to the sheet it replaces, or grows), where the drawn opening goes there, and which suite on which iPads holds it.

ID: A11Y-4
Severity: S2
Claim: L35's check, that the export sheet opens with its sentence, the format and Export in view at AX5 on an iPhone SE, cannot pass on the sheet its brief calls "otherwise 1.0's": for every template and for a new collection, 1.0's sentence plus the first row of its two-column format grid is taller than the room between the bar and a pinned Export, and the plan proposes adding to that sentence.
What a person meets: On an iPhone SE at AX5 the sheet opens on "Exports the full text of each document, with headnotes, your notes, footnotes, source notes, highlights, and a word-cloud overview." in about 13 lines. The format cards are below it, two to a row, with each caption cut to one line.
Evidence:
- L35's brief, plan line 646: "the sheet at the default size, AX3 and AX5, with its sentence, its format and Export in view when it opens". Line 647: "The sheet is otherwise 1.0's (decision 156)". Line 649.
- The design: §9 line 1011; §12 line 1163; §5.1 line 541, "Export, the one button pinned under the list"; §11 line 1105, which answers H21 with "The sheet's order is 1.0's; a fit suite, and a run".
- 1.0's sheet: CollectionExportSheet.swift:345 (the sentence, in .callout), :353 (the grid), and :373-394 (the button, inside the form). The grid has two flexible columns at every size (:101), and its caption is cut to one line (:113, .lineLimit(1)). The sentence is built by Collection.swift:244-280 from the recipes in CollectionExporter.swift:226-249.
- Plan §1c line 425, on how many headnotes will print: "The sheet 1.0 has already opens with a sentence of what will print, and that sentence can say it". Line 426, on A1: "Whether the sheet's sentence says it too is L50's to propose".
- Arithmetic (work-A11Y/sheet_fit.py; HIG sizes fetched today, Callout 38/46 at AX3 and 51/60 at AX5). At AX5 on the SE, the sentence and the first row of cards need 475 to 1,015 pt against about 467 for all seven sentences. The two Citations templates miss by 8 pt, inside the estimate's error; the other five miss by 128 to 548. At AX3 on the SE, Full text with everything's sentence fails (609 against 481). On the iPhone 17 at AX5, three of the seven fail and two pass by 3 pt.
- HIG Typography, fetched today: "Keep text truncation to a minimum as font size increases"; "Reduce the number of columns when the font size increases".
Refutation: A cap on the sentence at the accessibility sizes, or a one-column grid there, in L35 or §5.1, would refute this. I read both and found none. NEEDS A RUN: §12's lane 1 run (the built sheet on an iPhone 17 and an iPhone SE at L, AX3 and AX5).
Where it is answered: L35's brief must say it. Whether the headnote count goes in the sentence is §1c's, and the owner's.
Direction: Say in L35 what the sheet does with its sentence and its grid at AX3 and AX5 (as #1721 did for the Meaning strip), and weigh §1c's additions to the sentence against that.

ID: A11Y-5
Severity: S2
Claim: §11 answers the second review's A11Y-6 with "One control a row", yet three rows of this form carry a second control, and no board draws any of the three as a control: the collection's picker row with its count ("Footnotes: On · 2 set their own"), step 2's row, which opens a screen and also offers the suggested set's Add (decision 157), and the settings' line for the Note on the Text with its Add.
What a person meets: On an iPhone with VoiceOver on, a person chooses a template in step 1 and goes back. The "2 · Apparatus" row is one element. Its Add is reachable only as a custom action, if one is written, and a tap on the row opens step 2 rather than adding the set (how such a row behaves is from memory, not fetched). In step 1 the Footnotes picker and its count share one row, and at AX5 the count wraps under the value.
Evidence:
- Design §11 line 1126: "A11Y-6 A row's second control | One control a row | §4.2".
- §4.2 line 436: "At the collection, a row says how many set their own: Footnotes: On · 2 set their own. The count opens the list of them".
- §4.3 line 481: "step 2's row offers its suggested set in one tap: Suggested for Full text as printed: Bibliography, Sources & Archives. Add."
- §3.6 line 371: "the collection's settings say so in a line, with Add".
- §5.2 lines 556 and 563: the row leads to a screen pushed in the settings' stack on iPhone and iPad.
- §9 line 1015: "2 set their own is a button with that name", which holds the button's name only.
- Boards: on TwoSteps.dc.html a settings row is a div (:47) and the count a span (:50); on OptionA.dc.html the count is an underlined span (:127). None of the nine boards draws the suggestion's Add or the Note's line with Add (searched).
- Runbook :1311-1316: "no test can make VoiceOver do a custom action".
Refutation: An anatomy for these three rows in §4 or §5, or a board that draws them as controls, would refute this. I read §4, §5 and every board and found none.
Where it is answered: §11 claims it is answered. L44's brief must say it.
Direction: Give each of the three its own row or its own control, say where each lives for touch, for VoiceOver and for the keyboard, and count them in §5.5.

ID: A11Y-6
Severity: S2
Claim: §11 answers the second review's A11Y-7 with "A check for each lane that has a screen", but §9's table has no row for lane 7, whose taken candidates add screens and an export, and its two rows for lane 8 leave out the three new blocks' ticks (added by L51 to L53 after L44's suite is written) and decision 174's links.
What a person meets: After L53, a VoiceOver user on iPhone meets nine ticks in step 2, of which only the six L44 wrote are checked. An iPad user meets L45's column, held by "a suite on the iPad" that names no device and no assertion. A reader of L46's selected passages meets an omission sign chosen because "words are read aloud", which nothing checks is spoken.
Evidence:
- §11 line 1127. §9 line 1007: "Each check says what holds it: a suite, with its devices, or a walk by a person". The table (lines 1009-1022) has rows for lanes 1, 2, 3, 4, 5 (withdrawn), 6 and 8.
- The nine taken candidates: §8.1 lines 778-790. They add the iPad's settings column with pointing, the drawn opening, Save as Template, Same settings as…, the page's choices, a fourth text depth and a tagged PDF.
- Their rows: L45 line 691 ("a suite on the iPad"); L46 lines 693-699 (no check; line 697, "words are read aloud"); L47 line 708 (the VoiceOver suite); L48 line 716 ("where one can be written"); L49 lines 718-722 (no check); L51 line 738 ("a tick in step 2; its title among the collection's words"); L52 lines 740-745 (no check of the links); L53 line 752.
- §9 line 1014 checks "the wording table's ten fields". By L51's brief each new block's title joins the collection's words, which makes thirteen.
- The suite the lanes share has limits. It returns 64 characters of speech (runbook :1308-1309), and a tick's name and value use about thirty of them before A1's line begins. Each test runs alone, on a simulator shut down before it (:1343-1344). No brief counts either.
Refutation: A row for lane 7 in §9, or a check in each of L45 to L49 and L51 to L53, would refute this. I read them: L47 and L48 name a check, the rest none.
Where it is answered: §9 and §11. The rows' briefs must say it.
Direction: Give §9's table a row for each of lane 7's candidates and for lane 8's new blocks and links, each naming the suite and its devices, or the walk.

ID: A11Y-7
Severity: S3
Claim: §3.8 states three heading rules and none for a document inside a section or for an attachment's heading, which has three consequences: a document in a level-2 or level-3 section stands beside or above its own section in a heading list; under a title the volume's heading becomes a peer of its own attachments' headings in 23,855 documents; and nesting the rules under the outline's third level calls for a seventh heading level.
What a person meets:
- Web page, VoiceOver in Safari: in a collection whose level-2 section "The Long Telegram and after" is an h3, that section's documents are h2s, beside its parent section.
- A titled document with an attachment reads "heading level 3, As published: …" and then "heading level 3" for the enclosure, two sections of equal rank.
- In Word's Navigation pane a level-3 section's heading nests under the document before it.
Evidence:
- The outline nests three levels: CollectionOutline.swift:58 (maxLevel = 3).
- HTML today: sections are h2 to h4 (CollectionItemHTMLRenderer.swift:178), every document is h2 (:301, :308) and the collection is h1 (:521).
- The volume's text: FRUSRenderNodeHTMLSerializer.swift:741 (<h2 class="doc-heading">), :769 (<h3 class="attachment-heading">), :701 (an <h2> Footnotes) and :400 (<h2> lists named on @ana).
- Word today: sections are SectionHeading, SectionHeading2 and SectionHeading3 (DocxCollectionExporter.swift:643) at outline levels 0, 1 and 2 (:433-460). A document is Heading2 at outline level 1 (:691, :415-423), and the volume's heading is Heading3 (:1126).
- Design §3.8: line 387 gives each line "its heading level"; lines 396 and 398: "Under a title the volume's heading is one level down" and "Footnotes heading … one level below the document's".
- TEI count (work-A11Y/attachments_and_links.py): 23,855 of 314,616 documents, in 532 volumes, hold a frus:attachment with a head.
- The second review listed these as "Levels the rule does not reach" (collections-design-review-2/reviewer-A11Y.md:49). This form added the Footnotes rule only.
- Nested under a level-3 section, a titled document needs h5 for its title, h6 for the volume's heading and a seventh level for an attachment's heading. HTML stops at h6; ARIA allows aria-level above 6, and support for it varies (both from memory, not fetched).
Refutation: A nesting rule in §3.8 or L34 would refute this. I read both and found none.
Where it is answered: L34's brief must say it.
Direction: Give the plan one rule for a document's level under its section and for every heading inside a document, say what happens past six levels, and have L34's kit test check the levels' order in HTML and in Word.

ID: A11Y-8
Severity: S3
Claim: L48 scopes the tagged PDF to "a title, links, and tags from the roles the plan gives each line", which names neither the document's language nor the four things the PDF draws that are not lines of the plan: 9,358 documents' tables (printed as text joined by " | "), the word-cloud page, 217 documents' figures, and a page number on every page; and L55, which lands later, adds A12's table to the PDF's file while its brief and §9's check name only the web page and Word.
What a person meets: A VoiceOver user opens a tagged PDF of a collection that holds a table. They hear its cells run together with the separating bars (how the bars are spoken is from memory), the word cloud as an unnamed image or as nothing, and a page number between two paragraphs at every page turn.
Evidence:
- Plan L48, lines 710-716; design §8.1 item 12 (line 789) and §3.8 line 399.
- PDFCollectionExporter.swift:236 (CGContext(consumer:mediaBox:nil), so no document info); :1118-1142 (a table's cells joined with " | ", one line a row); :533-553 (the word cloud drawn with ctx.draw(image, in:)); :1145 (a figure); :1721-1725 (a page number on every page); :99-102 (no link annotations).
- L55: plan line 282 (its touch list includes Collections/PDFCollectionExporter.swift); line 762 ("in the web page and in Word"); design §9 line 1022.
- The structure can be written: Core Graphics' CGPDFTagType includes table, tableHeaderCell, figure and artifact (fetched today). PowerMapper's test (fetched today) reports VoiceOver in Safari announcing a tagged PDF's headings on macOS 10.14 to 15.7 and iOS 12.4 to 18.6, so L48's proof can pass.
- TEI counts (work-A11Y/tables_figures.py): 9,358 documents hold a <table>, in 504 volumes; 217 hold a figure's graphic, in 97.
- What PDF/UA asks of figures, tables, artifacts and language: from memory, not fetched.
Refutation: A line in L48 or L55 for tables, images, page furniture and language would refute this. I read both and found none.
Where it is answered: L48's and L55's briefs must say it.
Direction: Name in L48 what the tagged PDF marks beyond the plan's lines (tables as tables, figures with text, page numbers as artifacts, the language), and in L55 how A12's table is tagged.

ID: A11Y-9
Severity: S3
Claim: The only drawing of Show Parts makes each part of the page a button around its content, and §5.3 and L45 do not say how a part is marked; built that way, VoiceOver would read a part's text as one button's name, the links and footnote calls inside it would become unreachable, and each footnote call's own <button> would close the part's button where it starts.
What a person meets: On the Mac with VoiceOver and Show Parts on (and on the iPad, if L45's pointing marks parts the same way), the Long Telegram's text part is one button whose name is its dateline and first paragraph. The "Dept" link and footnote call 44 inside it cannot be reached, and the part's outline ends at the first footnote call.
Evidence:
- The board: OptionC.dc.html:62-106 makes each part a <button type="button" … aria-pressed>. The text part (:82-90) wraps the dateline and the paragraph, and the paragraph holds the footnote call 44 (:88).
- In the real page: FRUSRenderNodeHTMLSerializer.swift:879-882 (a footnote call is <button class="fn-marker" … popovertarget=…>), :902 (a term is <a class="gloss">) and :897 (a person is <a class="pers-name">).
- WAI-ARIA 1.2 (fetched today): the button role's Children Presentational is "True", and "The DOM descendants are presentational." The WHATWG parser (fetched today): at a button start tag, "If the stack of open elements has a button element in scope", the open button is popped.
- Design §5.3 lines 589-591. L45: plan line 686, and its touch list (line 272), which changes the HTML renderer only "if a part needs a mark on the page".
Refutation: A line in §5.3 or L45 saying a part is not a control on the page would refute this. I read both and found none.
Where it is answered: L45's brief must say it.
Direction: Say in L45 that a part on the page is marked without becoming a control (its name in text, its click caught by the page), and that VoiceOver and the keyboard reach a part from the column.

ID: A11Y-10
Severity: S3
Claim: Decision 174 makes the web page's term links lead somewhere where the block is, but beside them, with the same role and look, it leaves 1,823,714 person links that no browser can follow and 379,907 names with no target written as links to "#", against 1,326,671 term links; and in the preview, which allows in-page jumps and has no Back, a click on any term now moves the page to the block.
What a person meets: A keyboard user tabs through the web page of a volume whose editors tag people, with Abbreviations & Terms in the collection. "Dept" goes to its row. A tagged person's name tries to open frusexplorer://person/… (a browser error, or the app's refusal). An untagged name scrolls to the top of the page. In the app's preview on the Mac or the iPad, a click on "Dept", perhaps made while pointing at a part (L45), jumps to the end of the collection.
Evidence:
- Decision 174 (plan line 127). Design §8.2 A2 lines 859-862: the "Why" names the term link alone. L52, plan lines 740-745.
- FRUSRenderNodeHTMLSerializer.swift:896-897 (a person's link goes to frusexplorer://person/…, or to "#" when there is no target); :1069-1070 ("a name with no @corresp, which is written as a link to `#`").
- FRUSDocumentParser.swift:1782-1790 (every persName, with its target taken from corresp or ref).
- AppActivityTypes.swift:43-47: person, gloss, doc and brokenref links "are also serialized into exported collection HTML, where they have always been inert".
- CollectionPreviewView.swift:837-851: the preview "Allows the loadHTMLString load and in-page anchor navigation".
- TEI counts (work-A11Y/persname_nocorresp.py and link_hosts.py, after each volume's first document): 1,823,714 persName with corresp, in 287 volumes; 379,907 without; 1,326,671 gloss with target, in 311 volumes.
Refutation: A line in L52 or in the design about the other links, or about the preview's jumps, would refute this. I read both and found none.
Where it is answered: L52's brief must say it.
Direction: Say in L52 what the web page writes for a person and a reference beside a working term link (plain text, or the Persons Index's row where that block is), and what the preview does with an in-page jump.

The starting points in my scope
- A2, beyond the index (the block, its rows, decision 174's links): A ROW'S BRIEF MUST SAY IT. L52 must say what the page writes for the person and reference links beside a working term link, and what the preview does with an in-page jump (A11Y-10). §9 needs a check of the links (A11Y-6).
- The three things the withdrawn §4.4 said: A ROW'S BRIEF MUST SAY IT. Whatever the sheet's sentence is made to say, L35 must hold the sentence at AX3 and AX5, and 1.0's sentence already fails at AX5 on an iPhone SE (A11Y-4). Where the headnote count goes has three answers; that is INT's (below).
- A section's headnote default: not in my scope.
- The nine candidates of §8.1 that were taken: A ROW'S BRIEF MUST SAY IT. L45: the iPad column at the accessibility sizes, where the drawn opening goes there, the iPad suite, and how a part is marked (A11Y-3, A11Y-9). L48: tables, images, page furniture and language (A11Y-8). L46 and L49: their checks (A11Y-6).
- A8, A10, A11 and A12: A ROW'S BRIEF MUST SAY IT for A12: L55 must say how its table is tagged in the PDF once L48 has landed (A11Y-8). A8 and A10 are SETTLED BY THE TEXT as far as access goes: they are rows of the one shape a block's rows have (CollectionItemHTMLRenderer.swift:199-221). A11's heading where the presidency changes needs a level under the block's h2 (A11Y-7; L54).
- Step 2 with three more ticks: A ROW'S BRIEF MUST SAY IT. L44 must say what is in view after a shortcut at AX3 and AX5, and where the shortcuts' Undo is (A11Y-2). L51 to L53 must add their ticks to L44's VoiceOver suite (A11Y-6).

Attacked and held
- "As published:" is spoken. It is words inside the volume's heading (§3.8 line 396; §3.4 line 323, "It is words, so it is read aloud"), and lane 2's kit test holds it in the HTML (§9 line 1013).
- New text on the export page is gated for contrast. CollectionExportContrastTests fails on any rule that draws text and is not listed with its background (ReaderPageTests.swift:680-681, :719-720), and §9 line 994 says lanes 2 and 3 add rules. Borders, such as Show Parts' outlines, are not measured.
- The list's Export… as a VoiceOver action can be held as briefed. The service reads an action's words though it cannot perform one (runbook :1314-1316), and that is all §9's lane 1 row asks (line 1012).
- A footnote call whose note is not printed becomes text (§3.5 line 355; #2007), which takes a button with no popover out of the web page's tab order.
- The Mac's pointing leaves keyboard focus where the click was (§5.3 line 590), as the second review's A11Y-2 asked.

Not read
- Index version 76's branch, and the boards Main, Marks, Citations, SectionSheet and OptionB beyond searches.
- Both manuals, Docs/EditableContent, the Agentic Analysis Guide, and the earlier reviews' reports other than both A11Y reports and the second review's H20, H21 and verdict table.
- CollectionEntryInspector.swift, CollectionCompositionRows.swift and CollectionEntryRows.swift.
- MacCollectionManagerView.swift outside :1150-1262; DocxCollectionExporter.swift outside :384-473, :626-700, :1118-1130, :1180-1190 and :1644-1656; PDFCollectionExporter.swift outside :90-250, :528-560, :1110-1150 and :1716-1727.
- Not settled: whether L36's "keeps the author's place" restores VoiceOver's cursor or keyboard focus after the page is reloaded whole at each edit (CollectionPreviewView.swift:882-887). NEEDS A RUN with VoiceOver on in the Mac's preview.
- Not fetched: how screen readers treat a line before a heading and a fragment link's target; Word's Navigation pane; macOS Preview's support for PDF tags (Safari's was fetched); PDF/UA.
- Nothing was built or run. Every fit figure is arithmetic at half an em a character, with layout margins from memory.

Outside my scope
- INT: where the headnote count is said has three answers. The design's §4.4 (line 507) says the plan reads it as step 1's cards in L44; the plan's §1c (line 425) says the sheet's sentence can say it; L44's brief (line 680) says L44, "if CR agrees".
- INT: §5.4's table (line 599) still gives the iPad "settings as sheets, as now", against §5.3 (line 587) and §8.1's item 13 (taken, line 790).
- INT: §5.5 counts Wording as 10 fields and the collection's settings as 51 over four screens, but L51's brief (line 738) puts each new block's title "among the collection's words", three more fields.
