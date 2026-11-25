ID: INT-1
Severity: S1
Claim: As §3.3, §3.4 and §4.1 are written, a template tapped in the export sheet rewrites the collection at the tap, and the way back the record promises ("Your settings") is one stored copy that the next collection-scope edit replaces without asking.
What a person meets: iPhone, from the Collections list: Export…, tap down the six templates to read the sentence that changes under each, then Close. Nothing was exported, and the collection now follows the last template tapped, with apparatus rows added and removed, on every device once it syncs. Any platform: a reader tuned over an afternoon ("Your settings · 7 changes"), one handout exported under Citations with your notes, then one switch flipped at Whole collection. That edit becomes "the collection's own version" of the tried template, and the 7-change version has nowhere left to be. Export Again then prints it with no sheet. A person exporting a .bib sees the same checked list, which changes nothing in the file and everything in the collection.
Evidence:
- record §4.1: "Choosing a template here is choosing it for the collection"; §3.3: "is saved as every edit is", "A block that came with a template goes when the collection changes template", "Changing a setting while a template is in force makes the collection's own version of it"; §3.4 stores one "author's own settings" and one "template the author's own settings began from", in the same text value as the citation style, the labels and the mark; §3.3: "No template is a one-way trip".
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:19 (Close, no Cancel), :33-41 with :107 (a row tap selects at once), :58 with :74-85 (the sentence follows the tap), :47-55 (Format and More formats beside it).
- Today the sheet changes nothing (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExportSheet.swift:19-22, :60), and both manuals say so (/home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:1035 "the export sheet is just format + destination"; /home/user/FRUS-Explorer/Docs/macOS-User-Manual.md:777).
- The app's own rule is that a reader's choices in a collection are not removed without asking, because "Nothing registers undo for collection entries" (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryRows.swift:288-296; iOS-User-Manual.md:1049). That rule is why this is S1 and not S2. Grep finds no undo registration under FRUSExplorer/Collections outside the text editor.
Refutation: A sentence that keeps every displaced version, or that holds the sheet's choice until Export. I searched §1, §3.3, §3.4, §4.1 and Q3: neither is there. Q3's other branch (one-way, with an Undo while the sheet is open) is not the option under review.
Direction: Keep the sheet's template a choice for that export until the person asks to keep it, or keep each displaced version by name.

ID: INT-2
Severity: S2
Claim: The scope is a mode whose only signal is its own segment, it changes when the selection changes, and at "Whole collection" a control cannot show "what is in force" for any document or section that overrides it.
What a person meets: Mac. With document 470 selected, switch to Whole collection and turn Footnotes off; click 473 to check it, and the inspector is back at This document (§3.2: the scope "follows what is selected"), so the next switch meant for the collection is stored on 473 alone. If instead the scope stays, 470 is still highlighted in the outline and still the page in the preview, the rows look the same, and a switch meant for 470 changes every document. Where a document or its section overrides, the collection's row reads on with no dot while the page in front of the person shows none, and flipping it changes nothing they can see. With a section inside a section, "This section" names one of two; with no headings it names nothing. The card "Template · Full text as printed · 1 change · Reset" counts the document's change at one scope and the collection's at another, and Reset at the widest scope leaves every section's and document's changes standing.
Evidence:
- record §3.2 rules 1 to 4; §4.3 "the template, with its changes counted and Reset"; §4.5 (a preview tap sets document scope).
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionB.dc.html:39-42 (the selected row does not depend on scope), :133-140 (one card at every scope; its count is the one on document 470's row, :41), :227-233 (the scopes differ by an 11-px caption, which at collection scope reads "WHAT EVERY DOCUMENT SHOWS"), :269-271 (Reset clears every part).
- The cascade is not three layers. Sections nest three deep and a value walks up the ancestors (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionOutline.swift:56-58, :275-282, :311-312; iOS-User-Manual.md:1070), so a document can sit under itself, three headings, the collection and the template; entries before the first heading have depth 0 (:28-29).
- No undo, as in INT-1.
Refutation: A rule that a chosen scope outlives a selection change under a standing signal, and a count of overriding documents on each row at the wider scopes. Neither is in §3.2 or §4.3, and the board draws neither. NEEDS A RUN for how often it bites: ask someone to hide footnotes everywhere and then title one document.
Direction: Say on each row at a wider scope how many documents and sections differ, and never change the scope without the person's own act.

ID: INT-3
Severity: S2
Claim: By the record's own list the parts inspector holds more controls than what it replaces at every scope (at least 34 against 24 for the collection, 15 against 9 for a document, 13 against 7 for a section), and §4.3's "ten rows and two groups" counts today's controls one by one and tomorrow's by the row and the group.
What a person meets: iPhone. The Collection settings row opens one pushed list holding the scope switch, the six templates, Reset, ten part rows, thirteen rows "around the documents" and three of "wording". Every document's screen opens with three controls about the collection above its ten. New things to learn that today's interface lacks: a recorded template as a layer, "Your settings", blocks a template owns, the dot, three scopes, Reset at three reaches, Adjust, the mark, the Note on the Text, Reference, Export Again. Gone: the word Default, and the collection's block repeated in a heading's sheet.
Evidence:
- record §4.3: the head (scope, template, Reset), ten parts, "title page, introduction, contents list, the five apparatus blocks as five switches, word cloud, Note on the Text, colophon, project stamp, query log", and "citation style, labels, the mark": 1 + 6 + 1 + 10 + 13 + 3 = 34. It is 47 when the title page's four fields and §7 candidate 2's eleven labels are counted singly, as §2.4 counts today's name, subtitle and author line.
- Today's summary prompt and smart-collection link, both inside the 24, are placed nowhere in §3 to §6 (grep "prompt", "smart").
- Document: scope, template, Reset, ten parts, the heading's field and the dateline's. Section: scope, template, Reset, ten parts. Both before the gallery's six are counted.
- Today's counts hold on a recount: 24 (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEditorView.swift:806-816 with /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionCompositionRows.swift:113-204); 9 (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryInspector.swift:385-401, :687-742, :937-941); a section's 6 and its Section body menu (CollectionEntryInspector.swift:799-808; CollectionEntryRows.swift:177-185).
- The title's "two taps" is today's count from the editor: Export…, then Export PDF (CollectionExportSheet.swift:60, :85-88).
Refutation: A count of the hybrid by §2.4's rule that comes out under 24. The record gives a figure ("about a dozen") for Option A only.
Direction: Put the hybrid in §2.4's table beside today's, scope by scope, before §8 says lane 4 "answers very complicated".

ID: INT-4
Severity: S2
Claim: Four structural choices of the hybrid are arrangements this app has already built and withdrawn, or decided against in writing, and the record, which says it read "the two earlier Collections designs", names none of them in §3.6.
What a person meets: The owner, on iPad and Mac. (1) An inspector headed by a segmented scope control: Composer redesign 2b built it as "Document | Composition" and Composer v2 took it out. (2) The collection's settings in the inspector "with nothing selected": the arrangement a build-28 tester reported on iPad, mirrored on the Mac, as leaving them out of reach once a document was focused. (3) A content choice back in the export sheet, which the Collections rework removed so that export is "format + destination". (4) Five collection-level switches for apparatus beside the placeable rows: the option A11 rejected because "toggles create a parallel structure system". A row can be moved or inserted twice, and a switch can say neither.
Evidence:
- (1) CollectionEntryInspector.swift:119-124, :147-152, :286-295; CollectionEditorView.swift:2045-2049 ("the Document | Composition segment is gone"); no caller passes true (grep showsCompositionSegment); :832-836 ("Replaces the earlier 3-pane layout").
- (2) record §4.6; CollectionEditorView.swift:252-256 ("one inspector surface, either/or"); /home/user/FRUS-Explorer/Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md:260-262, :271-274; /home/user/FRUS-Explorer/FRUSExplorer/Collections/MacCollectionManagerView.swift:1068-1072 (the collection section left the inspector "to avoid rendering — and letting the user edit — the same recipe twice").
- (3) /home/user/FRUS-Explorer/Planning/Completed/Collections-Rework-Scope.md:5-6, :55; CollectionCompositionRows.swift:14-15, :26; iOS-User-Manual.md:1032-1035.
- (4) /home/user/FRUS-Explorer/Planning/Completed/Collections-Authoring-Scope.md:198; record §4.3 against §3.6 ("A11 … which §3.3 keeps"); iOS-User-Manual.md:1087 ("drag anywhere, delete, or insert more than once").
- The Mac's collection settings have already gone popover, inline, popover (MacCollectionManagerView.swift:48-51, :1165-1171), and the ribbon the 2026-07-04 design chose was removed by Composer v2 (:1148-1151).
Refutation: A record of why each was withdrawn that shows the cause is absent here. The code gives two reasons (CollectionEditorView.swift:832-836 "so the reading surface stays clear", and the Mac line above). Grep finds no Composer design document under Planning.
Direction: Have §3.6 name these four and say what is different this time, before Q1 is answered.

ID: INT-5
Severity: S2
Claim: For a collection that exists today the new controls cannot "show what is in force": a stored title override is a heading state outside §3.1's four choices, the drawn control lacks the choice every such collection is in, and stored overrides equal to the inherited value carry no dot yet do not follow a later change.
What a person meets: The owner, any platform, with a reader made under 1.0. (a) Document 475 has the title override "The Long Telegram", which today prints unbracketed above the volume's heading. The Heading control has no segment for that. If "Your own" is lit, its caption says "Yours prints in brackets, and the Note on the Text gives the volume's", which is not what this collection exports. (b) They pick Full text with your annotations in the export sheet. The record does not say whether each titled document then loses its title or prints it bracketed in place of the volume's heading with a Note on the Text added. Either way all of them move on one tap, in the contents list too. (c) Entries that existed when headnotes became a cascade store an explicit "off". Under the template's headnotes they print none, and each now shows a dot the owner never set; clearing them is one Reset per document. (d) The card applied last week as Full text as printed lays the page out differently under the same name. (e) A switch flipped off and on again either leaves a stored "on" with no dot, or removes a pin today's picker allows; the record does not say which.
Evidence:
- record §3.1 (four choices; titleOverride "is the field the app already has"); §3.3 ("A collection that exists today keeps The citation, then the volume's heading … until its author chooses a template again"; "A shipped template's recipe does not change afterwards. A different look is a new template with a new name", then "each gains a value for the three new parts"); §5 ("Neither: … a title that prints above the volume's heading, as today's override does"); §3.2 rules 1, 3, 4; §3.4 ("the entry's override fields stay as they are").
- OptionB.dc.html:236-240 and /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/PartsPhone.dc.html:50-54 (three segments: Volume's, Citation, Your own); OptionB.dc.html:158.
- Today's layout: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:296-309 with /home/user/FRUS-Explorer/FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:740-741. The field's own caption: CollectionEntryInspector.swift:398-399.
- /home/user/FRUS-Explorer/FRUSExplorer/Models/Collection.swift:570-577 ("Existing entries migrate to their stored value (explicit on/off)"); today's picker stores nil, true or false (CollectionEntryInspector.swift:657-668).
- The six names shipped on 2026-11-18 (/home/user/FRUS-Explorer/Planning/Plan-Of-Record-2026-11-15.md:484).
Refutation: A rule for a title override that has no heading choice, and for an override equal to its parent (dot or none, kept or cleared). I searched §3.1 to §3.4 and §5: none.
Direction: Write the table of what each stored state of a 1.0 collection shows and prints, before and after a template is chosen.

ID: INT-6
Severity: S2
Claim: With Q4 as recommended and the append rule as it stands, every document added after a new collection's first lands after the Bibliography and Sources & Archives, so the default quick export prints its back matter after document 1.
What a person meets: Any platform. Make a collection from the reader's Add to Collection, add five more documents the same way over a week, then Export… and Export PDF without opening the outline, which is the path §4.1 exists for. The PDF runs document 1, Bibliography, Sources & Archives, documents 2 to 6, while the sheet's sentence says the two "follow".
Evidence:
- record §4.1 ("A new collection starts under Full text as printed … so it exports as a PDF with no choice made"); Q4 ("whose two apparatus blocks arrive with its first document").
- Back-matter blocks go to the end when inserted (CollectionEditorView.swift:1922-1925; /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionGeneratedBlockType.swift:87-93).
- Every later document takes the highest position plus one (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionAddDocumentsSheet.swift:129-131, :154; /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionDocumentAppend.swift:101-103; the editor's own footer, CollectionEditorView.swift:1818-1819).
- Main.dc.html:75.
Refutation: A rule that documents arrive ahead of a template's trailing blocks, or that those blocks are not rows until export. Not in §3.3, §4.1, Q4 or lane 1; §3.6 keeps apparatus as placeable entries.
Direction: State where a template's blocks sit as documents arrive after them.

ID: INT-7
Severity: S2
Claim: Both forms of the preview tap put the change at the wrong layer or under a second, conflicting scope control: form (i) always lands at document scope and re-targets the selection, and form (ii) adds an "Apply to" control with the inspector's three words and the opposite meaning.
What a person meets: Form (i), Mac: someone who wants no footnotes points at a footnote block, as the design invites. The inspector opens at This document, the switch hides that one document's footnotes, and each repeat stores one more per-document override, the layer today's manual calls "the exception", which then survives every template and collection change. iPad: the same tap opens the inspector as a modal sheet over the page they pointed at. Form (ii): "Apply to" opens on whatever was last chosen; "All documents" is offered beside "Your own" with a typed heading; and "All documents" does not reach a document whose section or own setting overrides, the one pointed at included. With the inspector column open there are two three-way scope controls on screen, one that changes what is viewed and one that changes what is written.
Evidence:
- record §4.5 ("at document scope"); §4.4 ("Apply to: this document · this section · all documents"); §3.1 ("Your own, for one document"); §3.3 ("Per-document and per-section changes stay through every switch"); iOS-User-Manual.md:1097.
- /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/OptionC.dc.html:213-220 and :305 (Apply to), :292 and :352 (neither picking a part nor Done resets it), :347-350 (never disabled), :265.
- iPad's inspector is a sheet (CollectionEditorView.swift:863-873), against the Mac's own reason for a column: a toggle "would have hidden [the preview] at exactly the moment it matters" (MacCollectionManagerView.swift:1039-1045).
- The page identifies a document by volume and id (CollectionItemHTMLRenderer.swift:784-788) and a collection may hold one twice (CollectionAddDocumentsSheet.swift:126-129), so "that document's row" is not determined for a repeat.
- The names "in the margin" need a gutter the page lacks: body is max-width 780px with padding 2rem 1.5rem (CollectionItemHTMLRenderer.swift:819-824); the board reserves 104 px for an 84-px label (OptionC.dc.html:19, :80); with outline and inspector at their minimums of 340 each (MacCollectionManagerView.swift:917; CollectionEntryInspector.swift:263) a 1,280-pt window leaves the page 600.
Refutation: A drawing of the recommended option itself. There is none: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/canvas.json lists seven boards, none of B with Adjust and none on iPad. NEEDS A RUN: whether an iPad form sheet leaves the tapped part in view.
Direction: Choose one scope idiom for both routes, and have the tap show the layer it will write to before it writes.

ID: INT-8
Severity: S2
Claim: "The same ten parts at three scopes" is not what the model holds or what §3.4 adds: at least five cells of that grid have no layer, a smart collection has one scope and no rows, and three rows stop meaning what they show when another row changes.
What a person meets: At Whole collection, See also is a row with nothing to store it. At This section, Headnote is a row with no section layer. "Your own" exists for one document, yet the heading and dateline rows are drawn at every scope. The summary prompt, set today for a collection, a section and a document, is on no row. In a smart collection (Mac or iPad) the preview shows the search's documents, Adjust would outline their parts, and a tap has no row to select and nowhere to keep a heading; two of the three scope segments do nothing. Reference stays a live switch reading "The citation" while the heading is the citation and no reference prints. Footnotes and Highlights stay live when Text is not Full.
Evidence:
- record §3.1 (See also: "the collection has no setting for it … Unchanged"; "Every surface in §4 lists these ten and no others"); §3.4 (a heading entry gets "the same keys": heading, dateline, reference).
- /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionContentAssembly.swift:1103 (ref.includeRelatedDocuments ?? section.includeRelatedDocuments ?? false), :1084-1086 (headnote: the entry, else the collection); iOS-User-Manual.md:1102 ("headnotes have no section default").
- Summary prompt at three layers: CollectionCompositionRows.swift:130-137; CollectionEntryInspector.swift:712-731.
- Smart collections: CollectionContentAssembly.swift:182 ("carry no overrides or note selections"); MacCollectionManagerView.swift:1797-1800 ("a smart collection has nothing to inspect"); iOS-User-Manual.md:1154.
- OptionB.dc.html:198-226 (the rows do not depend on scope), :199 with :259 (the reference line is hidden while its switch stays); OptionC.dc.html:300-302; CollectionCompositionRows.swift:170 (today's Highlights is disabled unless the depth is Full).
Refutation: A table, scope by scope, of which rows exist and what stores each. §3.4 lists stored keys for three parts only.
Direction: Draw the list at each scope, and for a smart collection, with the rows that have no layer taken out.

ID: INT-9
Severity: S2
Claim: On iPhone the design's way in (the preview pointing into the inspector) is absent from §4.6 and undrawn, so lane 4 leaves the loop for changing one visible thing as long as today's, and Option B's stated weakness ("a list beside the page") is worse there than stated: the list replaces the page.
What a person meets: iPhone. See a dateline in Preview; switch to Outline; find the document among rows that read alike (the record's own eight documents under one heading); tap; scroll to Dateline; switch; Back; Preview; find the place again. Inside the pushed screen titled "Document 470", with Back reading "Contents", one tap on the scope switch puts the whole collection's settings, its template and its Reset under that title. If Adjust does reach the iPhone, its names have no margin to sit in.
Evidence:
- record §4.6 (iPhone, a document: "Tap its row", where Mac and iPad add the preview); §4.4 (Adjust was added because "a reader on an iPhone or iPad would have had to tap to find out"); §4.3 "Against it".
- CollectionEditorView.swift:725-747 (Outline or Preview, one at a time), :681-691 (the inspector is pushed); CollectionEntryRows.swift:972 (rows read the indexed header).
- PartsPhone.dc.html:19-25, :30-34, :36-43.
- The page's side padding is 1.5rem (CollectionItemHTMLRenderer.swift:819-824) against an 84-px label in a 104-px gutter on the Mac board (OptionC.dc.html:19, :80); canvas.json lists no iPhone or iPad board of Adjust.
- A popover adapts to a sheet at compact width (from memory, not fetched), so form (ii) on iPhone is a sheet for each tap.
Refutation: A phone board of Adjust, or a route from the preview pane on iPhone in §4.6. Neither exists.
Direction: Say whether Adjust ships on iPhone, and draw it there before lane 5 is sized.

ID: INT-10
Severity: S3
Claim: Five of the proposed words already mean something else on the same screen or elsewhere in the app.
What a person meets: With Adjust on, the strip under a document is labelled "Not printed" directly beneath that document's own footnotes "33 Not printed.", which is FRUS's phrase for a paper the volume omits and the sense the app's graph already gives the words. "Reference" is the row for the document's own citation, styled by "citation style", while the app's references are the cross-references that the row "See also" lists. "Heading" is the first part and also what the app's dialogs call a section heading. Footnotes reads "4 notes" a few rows above Your notes' "2 notes", and the outline's existing chip "N notes" means research notes. The scopes are named three ways on three boards.
Evidence:
- OptionC.dc.html:176 against :151; /home/user/FRUS-Explorer/FRUSExplorer/CrossReference/CrossReferenceGraphView.swift:1008, :1028, :1323.
- OptionB.dc.html:199 (name 'Reference', on 'The citation'); record §6; "References from" (CrossReferenceGraphView.swift:1317); "Unprinted references" (/home/user/FRUS-Explorer/FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift:1394).
- "Delete Heading?" and "Delete Heading Only" (CollectionEntryRows.swift:383, :251); record §4.6 "Select its heading".
- OptionB.dc.html:203, :206; CollectionEntryRows.swift:1186-1189.
- OptionB.dc.html:228-232; PartsPhone.dc.html:31-33; OptionC.dc.html:305.
- "Reset" beside "Template" meets the prompt editor's "Reset to Template" (/home/user/FRUS-Explorer/FRUSExplorer/Summarization/PromptEditorView.swift:240).
Refutation: A glossary in the record that fixes one word per thing. There is none.
Direction: Fix the vocabulary against the app's existing strings before any board is redrawn.

Attacked and held
- A row tap opening the settings on iPhone is not a change of behaviour: it has done so since Composer v2 (CollectionEntryRows.swift:1022-1026; /home/user/FRUS-Explorer/Planning/Completed/DEVELOPMENT-PLAN-to-2026-09.md:2602).
- §2.4's counts of 24, 9 and 21 hold on a recount (CollectionEditorView.swift:806-816; CollectionCompositionRows.swift:113-204, :388-427; CollectionEntryInspector.swift:385-401, :687-742, :937-941).
- §2.1 and §2.5 hold: the sheet opens on PDF and changes nothing, nothing exports from the list, and a template is one tap that only adds blocks (CollectionExportSheet.swift:60; /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionListView.swift:350-387; CollectionEditorView.swift:1935-1943).
- The four part names that exist today keep today's labels (Footnotes, Source note, Highlights, Headnote: CollectionEntryInspector.swift:691-710, :932), so they need no relearning.
- Selecting a heading to reach its section on the Mac is today's behaviour, not a new gesture (MacCollectionManagerView.swift:1352-1358, :1434).

Not read
- CollectionPreviewView.swift beyond its header notes and its reload path; PDFCollectionExporter.swift, DocxCollectionExporter.swift, CollectionGeneratedBlocks.swift, NativeCollectionFormat.swift, CollectionPickerSheet.swift, CollectionRichTextEditor.swift; CollectionAddDocumentsSheet.swift beyond its append rule.
- MacCollectionManagerView.swift lines 155-787, 1502-1639 and 1810 to the end; CollectionEditorView.swift after line 2096; Collections-Rework-Scope.md after line 60.
- Marks.dc.html, OptionA.dc.html and Citations.dc.html were skimmed for words only; the marks and the citation styles are not judged here.
- The UI suites, Docs/EditableContent, the lanes' costs, CloudKit and sync, and the web edition.
- Nothing was built or run. Every statement about how a control behaves on a device is from the code or the boards' source, or is marked.