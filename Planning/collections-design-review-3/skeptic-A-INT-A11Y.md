Skeptic A, third review of the Collections design (row CR): every finding of INT.md and A11Y.md. Read at REPO 0fa40e16 (claude/cr-collections-review-3), the boards under SCRATCH/canvas/project/, the earlier reviews' reports, and the public TEI at 216cdb764. Nothing was built or run. My scripts: SCRATCH/work-A/heads.py (repeated headings) and SCRATCH/work-A/doc_parts.py (attachments, tables, figures, person and term links, inside document divs), both stdlib ElementTree over the 553 manifest volumes, run with python3 -I; outputs beside them (heads_all.json, doc_parts.json).

ID: INT-1
Verdict: DUPLICATE of ENG-1 and DATA-1; as one finding, CONFIRMED
Severity: S1
Why: L47 says only "one document's settings copied to others. It writes the fields 1.0 has, and stores nothing new" (plan:707) and §8.1 item 9 only "Copy one document's settings to others" (design:786), while §4.1's own table makes a document's title, date line, "which" highlights and notes, and headnote "with its card" its settings (design:414-422). The kit takes each by id with no check of its document: chosen notes from the whole pool (CollectionContentAssembly.swift:1006-1009), the headnote by `source.summary(id:)` (:1364-1366), highlights from the target's own document filtered by the copied ids, so none survive (:1057-1060). `swapHeadnoteDraft` deletes the draft the entry points at before it mints one (CollectionEntryInspector.swift:1158-1173), and a row's delete deletes it too (GeneratedSummary.swift:238-243), so an edit or a delete on a target takes the source's written headnote. The one copier in the tree, Duplicate, copies all of these (Collection.swift:843-857), and no earlier form defined the fields either (aad7636 and 58cc047: "Copy one document's changes to others, or to its section"). Built as §4.1 defines a document's settings, the export prints another document's title, notes and headnote unmarked and an edit loses written work, so S1 stands.
Where it is answered: L47's brief, as the reviewer says: the fields copied and those never copied (title, date line, note and highlight selections, the headnote's summary), the direction, and what a following value does to a target's own.
Duplicates: ENG-1, DATA-1; INT's own Outside-my-scope DATA line.

ID: INT-2
Verdict: CONFIRMED
Severity: S2
Why: On export the summary phase calls `generateSummaries` for every summary-depth group (CollectionContentAssembly.swift:1416-1430), and the app's `resolveSummaries` opens with `guard AppleIntelligenceProvider.shared.isAvailable else { throw ExportError.renderingFailed }` before it looks for a stored summary (CollectionContentResolver.swift:776-778, :799-804); `isAvailable` is `SystemLanguageModel.default.isAvailable` (AppleIntelligenceProvider.swift:146-148), and the sheet shows `error.localizedDescription`, "The export could not be rendered." (CollectionExportSheet.swift:487; CollectionExporter.swift:1727-1729), while the preview attaches the stored summaries without asking (CollectionContentAssembly.swift:1435-1447). The prompt's error names "the collection's Composition section" (CollectionContentAssembly.swift:41-42), a word left only on the inspector's segment, which no caller shows (`showsCompositionSegment: false`, CollectionEditorView.swift:2049). The need itself is the second review's H11, which §11 (design:1095) and §1c (plan:424) leave to this review; what is new is that a card in L44 speaks on the device and day a template is chosen, and that the guard fails an export whose summaries are all stored, a 1.0 defect no issue names. Read from code; the path admits no other outcome.
Where it is answered: L35's brief for what the sheet says before Export. The guard order is a 1.0 defect in `CollectionContentResolver.swift`, outside L35's files (plan:268), so it is filed on the owner's word (plan §0) and given a row; the prompt error's wording goes with L44, which renames the groups.
Duplicates: none in this review; related to INT-3 and A11Y-4; the second review's H11.

ID: INT-3
Verdict: CONFIRMED
Severity: S2
Why: The plan gives the headnote count two homes: "The sheet 1.0 has already opens with a sentence of what will print, and that sentence can say it" (plan:425) and L44's "a template's needs, and how many headnotes will print, are said here, if CR agrees" (plan:680); §4.4 reports only the second (design:507). §1c and A1 leave the sheet's line for A1 "L50's to propose" (plan:426; design:843), and L50's brief names only the tick, the outline's row and the page (plan:724-731). 1.0's sentence "Reads the collection defaults" and adds "headnotes" whenever the default is on (Collection.swift:240-243, :258-259). §4.4 and §11's H11 promise "No placeholder line is printed in an exported file" (design:504, :1095), the word "placeholder" is nowhere in the plan, and all three exporters print "No stored summary for this document — generate one in the document view to fill this headnote." (CollectionItemHTMLRenderer.swift:463-466; DocxCollectionExporter.swift:2071-2073; PDFCollectionExporter.swift:923-929).
Where it is answered: the owner at C2, as the reviewer says, since §1c asks CR where each goes (plan:423). The natural homes: L35 for the sentence (it owns the sheet's file) and L34 for the placeholder (it rewrites how all three exporters draw a document).
Duplicates: FMT-2 (its placeholder evidence); A11Y's Outside-my-scope first line; ENG's starting-point line on the count; EDI's Outside-my-scope placeholder line.

ID: INT-4
Verdict: CONFIRMED
Severity: S2
Why: Composer v2 replaced "the 3-pane layout (a persistent metadata/composition `.inspector` column plus a toggled preview)" so "the reading surface stays clear" (CollectionEditorView.swift:832-836), and its diff (git show fa28f2d3) shows that column also held a document's inspector, "either/or". §5.7 lists four withdrawn arrangements without it (design:661-668), §5.4 still gives the iPad "settings as sheets, as now" (design:599) against §5.3 (design:587) and decision 164, and L45 says only "A settings column on the iPad, with pointing there" (plan:687). The app has paid this cost before: Browse measured list 340 + reader 451.5 + rail 240 on a 13-inch iPad and the rail overlaying "~213 pt of visible prose" on an 11-inch, and wrote a width rule (BrowseTwoPaneMetrics.swift:27-35, :106, :122); the editor's outline is up to 460 pt (CollectionEditorView.swift:845), so a third column beside it repeats the case, which L45 neither names nor sizes. §8.1 item 13's "as the reader draws its Research rail since R6a" (design:790) implies 280 pt and a sheet at compact width, but L45's brief does not carry even that.
Where it is answered: L45's brief (the widths at which the column shows, what the outline and preview give up, after Browse's rule), and §5.4's iPad row brought to decision 164.
Duplicates: A11Y-3 (the same column at the accessibility sizes); A11Y's Outside-my-scope §5.4 line.

ID: INT-5
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: The arithmetic holds: a new collection is full text, footnotes on ("all" → (true, false), CollectionExporter.swift:361-368), source note off, research notes on, highlights and headnotes off (Collection.swift:132, :143, :213, :218, :231), heading leading (decision 159), and against decision 158's recipes (CollectionExporter.swift:226-251) *Full text as printed* and *Summaries* each differ by two, the rest by three to five. The design's own example, "Like Full text as printed · 2 differ" (design:555; OptionA.dc.html:108), is that state, §4.3's "names the nearest" (design:489) has no rule for a tie, and the Mac form's "two steps, each a menu" (design:576; plan:678) needs an item for a state no template is. But the row's words are true, a card's change is shown with Undo (design:475), a tie broken by the grid's order is a line of code, and nothing is lost: no one is misled or stuck, so S3. The caption that stops naming a template (CollectionEditorView.swift:771-775) follows from §4.3's stated *1 differs* (design:495).
Where it is answered: L44's brief, with §4.3's rule for a tie and §5.2's Mac form, as the reviewer says.
Duplicates: none.

ID: INT-6
Verdict: CONFIRMED
Severity: S2 (S3 if L44 settles the tap as add-only)
Why: §4.3 says "1.0's templates add blocks and remove none. A shortcut does both, in view, with Undo" (design:480), then that "step 2's row offers its suggested set in one tap: Suggested for Full text as printed: Bibliography, Sources & Archives. Add." (design:481); L44 repeats only "Step 2's row then offers the suggested set in one tap (decision 157)" (plan:675). The table's set also holds a contents style and the Note on the Text (design:462, :469), which the drawn words omit, and Q3 put the set "one item away" (design:1042), which reads as the shortcut; so the label "Add" and the rule for a suggested set disagree on what the tap does. The row is on the main screen (design:556), outside step 2 where the change and its Undo are "in view", no board draws the offer (TwoSteps.dc.html:69-103; OptionA.dc.html:136-160), and the Mac's settings are a `.popover` (MacCollectionManagerView.swift:1749) with no undo manager in Collections but the rich-text editor's. Whether the popover closes on a click outside is from memory and does not carry the S2; the replace reading does.
Where it is answered: L44's brief, as the reviewer says.
Duplicates: A11Y-5 (the same row's anatomy).

ID: INT-7
Verdict: CONFIRMED
Severity: S2
Why: L47 leaves "What a saved template holds is the owner's: step 1's seven settings, as each of the six holds; or both steps" (plan:705), is held only by "the VoiceOver suite, for both actions' names" (plan:708), and with §8.1 item 2 (design:779) says nowhere where saved templates are listed, applied, renamed or deleted. Step 1's grid is built from `CollectionPreset.allCases` (CollectionCompositionRows.swift:274-277), "In force" compares "seven settings against six recipes" (design:489) and *Suggested for…* "lists the six sets" (design:480), so a seventh card has no rule in any of them. "Both steps" chosen where the six are chosen would change step 2, which decision 157 rules out for the six (design:481), and the owner is asked to choose without being told. §7.1's "designs none of them here" (design:712) states the gap in general; the conflict with decision 157 and the unbudgeted management screens on three platforms are worse than stated and change L47's size.
Where it is answered: L47's brief; the owner, for what a saved template holds, told first what "both steps" does to decision 157, as the reviewer says.
Duplicates: DATA's starting-point line on candidate 2 (the stored half of the same row).

ID: INT-8
Verdict: CONFIRMED
Severity: S3
Why: §5.2's words are "Contents, Headnote, Summary, Research Note, See also, and the five apparatus titles" (design:571), §5.5 counts Wording 10 and the four screens 51 (design:616, :623), and L51 owes each new block type "its title among the collection's words" (plan:738), which L52 and L53 inherit (plan:745, :752): 13 labels, 54 controls, and fifteen new facts where §5.5 says twelve. The rest of the recount (56 to 60, step 1 at 16 or 18) places controls where no text places them, which §5.5 itself asks the review to do (design:621). "No screen holds more than 17" (design:630) breaks only if two saved templates are step 1's cards, which no text says.
Where it is answered: §5.5's text, and L44's brief for which later rows may add to its ten, as the reviewer says.
Duplicates: A11Y-6 (the wording check's thirteen fields); FMT's Outside-my-scope second line; A11Y's Outside-my-scope third line.

ID: INT-9
Verdict: CONFIRMED
Severity: S3
Why: Each of L48's three choices has a 1.0 value per format: the PDF is 612 by 792 (PDFCollectionExporter.swift:177-178), opens a page for each document (:682) and numbers every page (:1721-1725); the web page's print stylesheet breaks after each document's text (`@media print { .frus-document { page-break-after: always; } }`, CollectionItemHTMLRenderer.swift:1164-1166, embedded at :800-805, around the text at FRUSRenderNodeHTMLSerializer.swift:337), so §2.3's "no break" (design:165) holds on screen only; Word writes an empty `<w:sectPr/>` (DocxCollectionExporter.swift:674). So "What 1.0 prints stays the default" (plan:713) is up to three defaults a choice, which one control cannot show. That a device-kept choice must sit in the sheet is weaker (a Settings pane could hold it), but L48's "kept as the remembered format is" (plan:712) points there.
Where it is answered: L48's brief; the owner, for where the choices are kept, as the reviewer says.
Duplicates: ENG's starting-point line on candidate 7.

ID: INT-10
Verdict: CONFIRMED
Severity: S3
Why: L46's four open questions are the dateline, a document with no highlight, a stale highlight and the scopes (plan:698), and neither they nor §8.1 item 1 ("the passages the author highlighted", design:778) say whether *Highlights in body* or the per-highlight switch chooses the passages. 1.0 has both: `applyHighlights` defaults to false (Collection.swift:213) and is disabled at every depth but Full (CollectionCompositionRows.swift:166-169), and each highlight's switch is "Include this passage when highlights apply" (CollectionEntryInspector.swift:514-515); the assembly resolves highlights at Full only, filtered by the entry's selection (CollectionContentAssembly.swift:1057-1060). So at the new depth one switch either decides two things or nothing.
Where it is answered: L46's brief, as the reviewer says.
Duplicates: none (ENG-10, DATA-5 and FMT-3 are L46's other gaps).

ID: A11Y-1
Verdict: CONFIRMED
Severity: S2
Why: §3.8 says "Where the volume's heading leads, the citation is a line before it. The plan names each document's region by its heading, so that a reader moving by headings is told which document the line belongs to" (design:397), §3.3 puts no number at a document's head (design:312), and decisions 158 and 159 give that opening to four templates and every new collection (plan:100-104). My count (work-A/heads.py: first direct <head> of each document div, notes dropped) gives 171,402 of 222,189 headings before 1952 shared with another document of their volume as the heading reads, 5,987 of 92,420 from 1952, 177,389 of 314,609 in all (56.4%), and frus1946v06's two commonest headings at 45 each: the reviewer's figures. So a region named by its heading is named as its neighbours are, and the design's "is told which document" is false for most volumes before 1952; in 1.0 the document's `<h2>` and Word's Heading2 are the citation, ending in its number (CollectionItemHTMLRenderer.swift:296-309; DocxCollectionExporter.swift:691), and keepNext is used only for figures and tables (:1187, :1653). The first review's A11Y-4 raised identical headings, the second form's number answered it, and the third form removed the number (§3.3; H14), so the third form re-opened it; L34's test reads the plan and the HTML only (plan:641; design:1013).
Where it is answered: L34's brief and §3.8's sentence, as the reviewer says.
Duplicates: EDI-7 (the same headings under Summaries; "hears the same heading 45 times"); EDI's Outside-my-scope A11Y line.

ID: A11Y-2
Verdict: CONFIRMED
Severity: S2
Why: The design drops a template's question because "Each step's change is small, shown where it is made, and undone there" (design:33), with the seven settings "under the template cards" and "A line says what changed ... with Undo while the screen is open" (design:475), which the board draws after the six cards (TwoSteps.dc.html:30-55, the line and Undo at :42-43). §9's fit check is "Step 1's cards and the section pill at AX3 and AX5, proved on the card's own label" and its spoken check covers step 1's line alone (design:1016-1017); step 2's column has no line or Undo on the board (TwoSteps.dc.html:69-103) nor in a check, though "A shortcut does both, in view, with Undo" (design:480). The positions are the reviewer's arithmetic, but the conclusion needs no precision: six cards with names and descriptions of several lines each at Body 53/62 fill more than an iPhone screen at AX5 before the line begins, so a sighted reader at that size taps a card and sees nothing change. VoiceOver alone is covered, by the spoken line.
Where it is answered: L44's brief, with what is in view after a choice in its fit suite, as the reviewer says.
Duplicates: none.

ID: A11Y-3
Verdict: CONFIRMED
Severity: S2
Why: §8.1 item 13 builds the column "as the reader draws its Research rail since R6a" (design:790); the rail is `researchRailWidth = 280`, "drawn at this width and never compressed" (BrowseTwoPaneMetrics.swift:97-100), and turns into a sheet by width alone (`isPhone || horizontalSizeClass != .regular`, DocumentView.swift:426), so at AX5 its 248 pt of text hold about nine Body characters a line. Today the iPad's document settings are a sheet (CollectionEditorView.swift:863-873), and L45 names no device and no assertion ("a suite on the iPad", plan:691). Two corrections: the drawn opening at AX3 and AX5 is already L45's to show first (plan:688), so that half is NOT NEW; and the reviewer's own figures (opening ~2,950 pt, pickers ~2,900) put the first control about three landscape screens of a 13-inch iPad down, not six, which is where the pickers end. What is new and holds is the column's own width at the accessibility sizes, with no fallback in the design or the brief.
Where it is answered: L45's brief, as the reviewer says.
Duplicates: INT-4 (the same column at the default sizes).

ID: A11Y-4
Verdict: CONFIRMED
Severity: S2
Why: L35 wants "its sentence, its format and Export in view when it opens" at AX5 (plan:646) on a sheet "otherwise 1.0's" (plan:647). 1.0's iOS sheet sets the sentence in `.callout` (CollectionExportSheet.swift:345), a grid of two flexible columns at every size with a one-line caption (:100-113), and Export inside the Form below the Zotero section (:373-394), not pinned, so §5.1's "Export, the one button pinned under the list" (design:541) is a change L35 does not name. Its longest sentence, "Exports the full text of each document, with headnotes, your notes, footnotes, source notes, highlights, and a word-cloud overview." (Collection.swift:244-280), runs to a dozen lines at Callout AX5 in an iPhone SE's width, more than the room above a pinned button whatever the exact margins; the two Citations sentences miss by 8 pt, inside the estimate's error, so "for every template" overstates by two. The second review's H21 was answered with "a fit suite, and a run" (design:1105); this shows the run fails on 1.0's sheet unless L35 changes it.
Where it is answered: L35's brief, weighed against §1c's additions to the sentence, as the reviewer says.
Duplicates: INT-3 (what the sentence would say); the second review's A11Y-3 and H21.

ID: A11Y-5
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: Two rows do hold a second control: "Footnotes: On · 2 set their own. The count opens the list of them" (design:436) is a picker with a button, and step 2's row both opens a screen (design:556, :563) and offers "Add" (design:481); no board draws either as a control (TwoSteps.dc.html:47-50; OptionA.dc.html:127). But the count is specified as its own control, "2 set their own is a button with that name", held by the VoiceOver suite (design:1015), and the Note's line "with Add" (design:371) is one control on a line, not a second on a row. What remains is step 2's row and its Add, whose meaning is INT-6's, and the count's layout at the large sizes: a sentence in L44, which is S3, as the second review's skeptic rated this row anatomy (collections-design-review-2/skeptic-A-INT-A11Y.md:93-96).
Where it is answered: L44's brief, as the reviewer says, and §11's A11Y-6 line corrected.
Duplicates: INT-6 (the one-tap offer); the second review's A11Y-6.

ID: A11Y-6
Verdict: CONFIRMED, RE-RATED
Severity: S3
Why: §11 says "A check for each lane that has a screen" (design:1127), and §9's table has rows for lanes 1, 2, 3, 4, 5 (withdrawn), 6 and 8 and none for lane 7 (design:1009-1022), whose nine candidates add screens; its wording check counts "ten fields" (design:1014), where L51's brief makes thirteen (plan:738). The reviewer's "L47 and L48 name a check, the rest none" misreads L45, which names "a walk on the Mac ... and a suite on the iPad" (plan:691), devices unnamed, and L50, which names its spoken line (plan:731). The 64-character limit does not stop a tick's name being read: the suite reads "the whole label ... from the element" (UI-Test-Destinations-Runbook.md:1308-1309). The cure is rows in a table and a line in each brief before any lane ships, which the second review's skeptic rated S3 for the same shape (collections-design-review-2/skeptic-A-INT-A11Y.md:99-102).
Where it is answered: §9's table and §11, and the briefs of L45 to L49 and L51 to L53, as the reviewer says.
Duplicates: INT-8 (the thirteen labels); the second review's A11Y-7.

ID: A11Y-7
Verdict: CONFIRMED
Severity: S3
Why: The outline nests three deep (CollectionOutline.swift:58); sections are h2 to h4 (CollectionItemHTMLRenderer.swift:178) and SectionHeading to SectionHeading3 at outline levels 0 to 2 in Word (DocxCollectionExporter.swift:640-645, :430-462), while a document is h2 (CollectionItemHTMLRenderer.swift:301, :308) and Heading2 at outline level 1 (DocxCollectionExporter.swift:691, :415-423), and an attachment's heading is h3 (FRUSRenderNodeHTMLSerializer.swift:769). §3.8's rules stop at the lead, the volume's heading one level down under a title, and Footnotes one below the document's (design:396-398). My count (work-A/doc_parts.py) gives 23,768 documents in 530 volumes with an attachment holding a direct <head>, against the reviewer's 23,855 in 532 from a looser match. The second review listed these levels (collections-design-review-2/reviewer-A11Y.md:49) and this form added only the Footnotes rule, so it stands.
Where it is answered: L34's brief, as the reviewer says. A11's heading inside the Chronology also needs an exporter, which L54's files do not name (plan:281).
Duplicates: the second review's A11Y-4 ("Levels the rule does not reach"); FMT's Outside-my-scope third line.

ID: A11Y-8
Verdict: CONFIRMED
Severity: S3
Why: L48 scopes the tagged PDF as "a title, links, and tags from the roles the plan gives each line (L34)" (plan:714), and the PDF draws what is not a line of the plan: table cells joined by " | " (PDFCollectionExporter.swift:1131-1143), the word cloud as an image (:533-554), a figure (:1145-1148) and a page number on every page (:1721-1725), from a context with no info dictionary (`CGContext(consumer:mediaBox:nil)`, :236); the document's language is unnamed. L55's files include the PDF exporter (plan:282) while its brief and §9 name only the web page and Word (plan:762; design:1022). Inside document divs I count 8,820 documents with a table in 503 volumes (not 9,358 in 504) and 197 with a figure's graphic in 86 (not 217 in 97); the reviewer's regex chunks run past a document's end, which changes nothing in the claim.
Where it is answered: L48's and L55's briefs, as the reviewer says; L55 first owes whether the PDF prints A12's table at all (FMT-6).
Duplicates: FMT-6 (A12's table and the PDF); ENG-3 (the drawing a tagged PDF needs).

ID: A11Y-9
Verdict: CONFIRMED
Severity: S3
Why: The board makes every part a `<button type="button" … aria-pressed>` around its content, the text part holding footnote call 44 (OptionC.dc.html:62-106), and in the real page a footnote call is itself a `<button class="fn-marker" … popovertarget=…>` (FRUSRenderNodeHTMLSerializer.swift:879-882). The design's words are that each part "is outlined, with its name on the outline's own corner" (design:589), which does not make a part a control, and "Every part is reachable without the page" (design:591; plan:686) already gives VoiceOver and the keyboard their way, so the risk rests on the board alone. L45 touches the renderer only "if a part needs a mark on the page" (plan:272) and says nothing of how, so a line saying a part is marked and not made a control is cheap and owed.
Where it is answered: L45's brief, as the reviewer says.
Duplicates: none.

ID: A11Y-10
Verdict: CONFIRMED
Severity: S3
Why: Every persName becomes a link, to `frusexplorer://person/…` or, with no corresp or ref, to `#` (FRUSDocumentParser.swift:1782-1790; FRUSRenderNodeHTMLSerializer.swift:894-897), links that "have always been inert" in exported HTML (AppActivityTypes.swift:43-47); decision 174 changes only the term's (plan:127), though §8.2's reason, the browser and the app's refusal (design:861), holds for the person's too. The preview allows "in-page anchor navigation" and cancels only activated http(s) links (CollectionPreviewView.swift:837-851), so a term's link will jump the preview to the block, which collides with L45's click on a part selecting its row (plan:686). Inside document divs I count 1,763,737 persName with a target, 359,740 without and 1,300,839 gloss with a target, a little under the reviewer's counts, which run to each volume's end; the proportion stands.
Where it is answered: L52's brief, as the reviewer says, and L45's for a click that lands on a link inside a part.
Duplicates: FMT-5 (its last bullet); ENG's starting-point A2 line (a gloss-link option in the serializer).


The reviewers' starting-point lines in my files

INT.md
- "Recount §5.5 ... the 51 and 'No screen holds more than 17' do not": the 51 does not hold (54 by L51's brief), but "No screen holds more than 17" is not shown false: step 1 reaches 16 with See also and Save as Template placed there, and 18 only if two saved templates are its cards, a placement no text makes.
- "The three things the withdrawn §4.4 said ... L35 ... says the needs ... and the headnote count": add that 1.0's sentence already overflows L35's own fit check at AX5 on an iPhone SE (A11Y-4), so each addition must be weighed against it, and that the guard failing a stored-summary export is in CollectionContentResolver.swift, outside L35's files (plan:268).
- "See also at the collection (L43 ... with it, §4.2's Not set above has no case left)": §4.2 already says "whether Not set above survives, is that candidate's to settle" (design:434), so that half is stated.

A11Y.md
- "A12: L55 must say how its table is tagged in the PDF once L48 has landed": first L55 must say whether the PDF prints the table at all; its brief and §9 name the web page and Word only (plan:762; design:1022), as FMT-6 found.
- "A11's heading where the presidency changes needs a level under the block's h2 (A11Y-7; L54)": agreed, and L54's files name no exporter (plan:281), so as briefed it can only be a row, an <li> in the web page (CollectionItemHTMLRenderer.swift:203-218).
- "L45: the iPad column at the accessibility sizes, where the drawn opening goes there": where the drawn opening goes at AX3 and AX5 is already L45's to show before it builds it (plan:688); only the column's own width is new.
- "A2, beyond the index ... L52 must say what the page writes for the person and reference links": incomplete, not wrong: L52 must also key each row and anchor by volume and the editors' id (EDI-1, FMT-5), since one abbreviation means two things within and across volumes.


Errors in the design or the plan found on the way

- Design §5.4 (line 599): the iPad's layout "Outline · preview, with settings as sheets, as now" contradicts §5.3 (line 587), §8.1 item 13 (line 790) and decision 164.
- Plan §1c (line 425) gives the headnote count to the sheet's sentence, and L44 (line 680) to L44; design §4.4 (line 507) reports only the second as "the plan of record reads the first two as step 1's".
- Design §4.4 (line 504) and §11's H11 (line 1095): "No placeholder line is printed in an exported file"; no row of the plan does it (the word is nowhere in the plan), and all three exporters print one.
- Design §1 (line 116), §5.2 (line 565), §5.5 (line 617) and plan L44 (line 677): a section's sheet holds "six" pickers; decision 164's section headnote default makes seven.
- Design §5.5 (lines 616, 623): Wording 10 and 51 controls; plan L51 (line 738) puts each new block's title among the words, making 13 and 54.
- Design §11 (line 1126): "One control a row" for the second review's A11Y-6, against §4.2 (line 436) and §4.3 (line 481).
- Design §11 (line 1127): "A check for each lane that has a screen", against §9's table (lines 1009-1022), which has no lane 7 row.
- Design §3.8 (line 397): "a reader moving by headings is told which document the line belongs to" is false where headings repeat, 77.1% of the documents before 1952.
- Design §5.1 (line 541): "Export, the one button pinned under the list" under "The sheet 1.0 has": 1.0's iOS Export sits inside the Form (CollectionExportSheet.swift:373-394); only the Mac's is pinned, in a button bar under a Divider (:278-321).
- Design §5.1 (line 546): "Export… then Export is that export" is false after a Zotero web send, which is a row and not a format (CollectionExportSheet.swift:133-138; CollectionExporter+App.swift:176-179), as INT's starting point says.
- Design §4.3 (line 481): the drawn offer lists two blocks and "Add", where the table's set (lines 462, 469) holds a contents style and the Note too; TwoSteps.dc.html:122 puts the one tap "in step 2", the text on step 2's row.
- Design §8.1 item 2 (line 779): "with a deploy of its own", against §7.1 (line 721) and plan §0's one promotion; plan §1c (line 429) quotes §4.1 for words it lost at b3542992 (9325f79d:414 had them), as DATA-9 found.
- Plan §1c, the third departure (line 443): "lane 4 then adds its new settings to the refresh list L36 completes"; lane 4 (L44) stores nothing, and the new settings are L43's, whose brief does not name the list (ENG-4).
- Board SectionSheet.dc.html:50 ("A section has no headnote setting, as in 1.0") and the boards' "Not set above: Off" for See also (OptionB.dc.html:171; PartsPhone.dc.html:89; SectionSheet.dc.html:69) are superseded by decision 164, beyond the three superseded items the reviewer brief names.


Not checked

- No run of any kind, as the brief forbids: INT-2's failure on a device without Apple Intelligence, INT-6's popover on the Mac, A11Y-1's screen readers and Word's Navigation pane, A11Y-2, -3 and -4's fit at AX3 and AX5 (I checked the reviewers' arithmetic by hand at their sizes, not by their scripts), A11Y-8's tags in Preview or Safari.
- No Apple, W3C, WHATWG or PowerMapper page was fetched; the reviewers' quotations of the HIG, WAI-ARIA, the HTML parser and CGPDFTagType are taken as quoted.
- Index version 76's branch: no finding of mine rests on it.
- The second review's skeptic reports beyond their A11Y-3, A11Y-6 and A11Y-7 verdicts; the first review beyond its A11Y-4 and INT's withdrawn-arrangements finding.
- ENG, DATA, FMT and EDI were read for duplicates and not verified, except the lines that overlap mine (ENG-1, ENG-4, DATA-1, DATA-9, FMT-2, FMT-6).
- Both manuals, the Agentic Analysis Guide and the web edition's repository.
