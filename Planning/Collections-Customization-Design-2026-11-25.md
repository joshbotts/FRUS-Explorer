# Collections: export in two taps, and fine-tune every part of a document — a design, 2026-11-25

**Status: PROPOSED on 2026-11-25, and revised the same day after an adversarial review. Nothing is built, and no code changed.** §10 asks the owner for nine decisions. §9's lanes are written so that the next plan of record can take them as rows. §12 lists the checks that need a device before a lane starts.

**This is the record's second form.** The first recommended a parts inspector entered from the preview. `Collections-Design-Adversarial-Review-2026-11-25.md` found that it did not stand as written: 50 findings, none refuted, 17 distinct at S1 or S2. The owner then asked for this revision, and offered a new model type with a one-way upgrade as its base. Five things changed:

- **Nothing the volume prints is replaced.** A title or a date line of the author's is added above the document, and the volume's heading stays under it, named in words. The first form replaced the heading and marked the replacement with brackets (§3).
- **A template chosen at export is for that export, and a template chosen for the collection asks first.** The first form rewrote the collection at the tap (§4.3, §4.4).
- **The settings on screen are those of what is selected.** The first form had a switch for the scope (§4.2).
- **Pointing at the page is the Mac's alone** (§5.3).
- **Collections move to two new record types, by a one-way upgrade that deletes nothing** (§7).

§11 lists every finding of the review with the section that answers it. The first form is in the repository's history at `aad7636`. The review cites its section numbers, which this form does not keep.

**Reviewed adversarially the same day, and it does not stand as written either.** `Collections-Design-Second-Review-2026-11-25.md` records six reviewers' 59 findings, none refuted: once merged, 1 at S1, 20 at S2 and 27 at S3. Its §2 is on the `.fruscollection` file, where §7.6 below is wrong: the file need not change version, and a 1.0 app should go on opening it. Its §8 says what the design becomes, and withdraws the upgrade of §7.4 as designed.
- This record is left as it was reviewed, so that the review can be read against it.
- Thirteen statements about the app as it ships, or about the volumes, were false. Each is corrected where it stands and marked *(corrected, second review …)*.
- The proposal's own claims that the review supersedes are listed in the review's §5 and are not edited here. Read §3 to §9 with the review beside them.

**What this is.** The owner's words of 2026-11-25:

> "I am not satisfied with the Collections feature. I am not able to customize how each document is displayed, yet the interface is very complicated. I want to be able to export a collection very quickly using sensible default templates (the new ones we created last week are good starting points). I also want to be able to fine-tune any aspect of the collection, including overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately. I want to be able to choose what citation format to use if the contents are listed that way. Consider other authorial capabilities along these lines as well. Consider what kinds of user interface alternatives might help me preserve clean simplicity for default situations and also wield powerful customizability for other times."

That is five asks:

1. a quick export from a template (§5.1);
2. every part of a document adjustable, in a simpler interface than today's (§3 to §5);
3. the author's own headings, datelines and labels, marked (§3);
4. a citation style for the collection (§6);
5. other authorial capabilities (§8).

§2 says where the feature, as 1.0 (1861) ships it, falls short of each.

**How it was read.** In a cloud session with no Xcode, on 2026-11-25, from `v2` at `efd73ec` (#1988's merge). Nothing was built or run. Every statement about behaviour is read from the code, from both manuals or from the public TEI, and carries its file and line at that commit.

- §2 is the first form's reading of the app, with the six corrections the review made to it and the seven defects the review met on the way (§2.8).
- The examples are real: document 475 of `frus1946v06` and its neighbours, from the public TEI (`HistoryAtState/frus`), with the volume's title, editors and year from the bundled manifest. The counts over volumes are the review's, made by parsing eight volumes.
- The revision read, besides: the review and its eight reports; `Completed/Collections-Rework-Scope.md`, which the first form had not read; the Editorial Methodology of `frus1977-80v06`; and, for §7, the model container, the CloudKit inventory, the duplicate cleanup, the research import plan and the collection file's format.
- §3 to §9 were reviewed after they were written; the notice above says where.

**The mockups** are on a design canvas, private to the owner's account: <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>. Its seven boards were redrawn for this form:

- the export sheet on an iPhone (§5.1);
- the collection's settings on the Mac, with the template gallery first (§5.2);
- a document's settings on the Mac, and on an iPhone (§5.2);
- the Mac's preview with *Show Parts* on (§5.3);
- the three openings of document 475, with their contents rows, and the volume's own uses of brackets (§3.3);
- a contents list in the three citation styles (§6).

The session wrote the boards and did not see them rendered: this container cannot open the canvas. One error of the first form's boards is corrected in these: they drew the editors' bracketed *13* in document 475's first line as a footnote's number.

---

## 1. In brief

**What is wrong today** (§2):

- **Every document is drawn one way, and the three formats disagree about that way.** A document prints the citation as a heading and then the volume's own heading under it. The PDF prints one line of a source note above the text, ends its contents list where the cover page ends, and gives each research note a page of its own. The Word file ignores the contents-list style.
- **The controls are many, and they are sorted by where a value is stored.** Collection settings holds 24. A document's inspector holds nine settings, eight of them a picker with a *Default* choice. A section's sheet shows 21 controls, of which six are the section's.
- **A template is a one-way trip, and it is not offered at export.** One tap overwrites eight fields with no undo. The export sheet chooses a format and nothing else, and nothing exports a collection from the Collections list.
- **Collections cite in one style.** The app has three formatters, and the collection's assembly names one of them in its code.

**What is proposed:**

- **The document prints as the volume prints it, and the author's words stand above it.** A title, a date line, the collection's own number and the citation are the author's lines. The volume's heading follows as *Printed heading:*, with its footnote calls, and the dateline stays in the text where the volume has it (§3.1 to §3.4).
- **Marked in words.** No brackets, which the volumes use for their own editors' additions. A generated *Note on the Text* says what the author added and what the collection leaves out (§3.6).
- **Export is a look, a format and a button**, from the editor, the Collections list and the Mac's menu. A template chosen there is for that export and writes nothing (§5.1).
- **One list of settings for each thing that can be selected:** the collection, a section, a document. Each row shows what is in force and says in words where the value comes from. There is no *Default* choice and no switch for the scope (§4, §5.2).
- **The template gallery first.** The collection's settings open on the six templates and the title page: 14 controls in view against today's 24. Opened fully they are 31, seven more than today (§5.5).
- **A citation style per collection**, over the three formatters the app has (§6).
- **One plan for three formats:** the kit resolves each document's lines once, and HTML, PDF and Word draw that plan (§3.8).
- **Two new record types and one CloudKit deploy.** 1.0's collections are upgraded once, by a function tested over values, and are left where they are (§7).

---

## 2. What 1.0 (1861) does, against each ask

### 2.1 "Export a collection very quickly"

- **The export sheet chooses a format and nothing else.** It shows the collection's one-line composition summary, six format cards and the Zotero row (`CollectionExportSheet.swift:220-240`, `:342-371`). It opens on PDF every time (`@State private var selectedFormat: ExportFormat = .pdf`, `:60`), whatever the collection last exported as. It writes nothing to a collection (`:19-22`).
- **A template is applied somewhere else.** On an iPhone the path from the Collections list to a PDF under another template is: the collection's row, *Collection settings*, a template chip, Back, scroll to *Actions*, *Export…*, *Export PDF* *(corrected, second review: this record first counted a format card, which a PDF does not need, since the sheet opens on PDF)*. On the Mac the templates are in a 420-point popover behind the toolbar's gear (`MacCollectionManagerView.swift:1172-1262`).
- **Nothing exports from a list.** The iOS Collections list's context menu offers Rename, Duplicate, Word Cloud, Create Static Snapshot and Delete (`CollectionListView.swift:350-387`), and the file names no exporter. On the Mac both ways in, the toolbar's *Export…* and the Collection menu's *Export Collection…* (⇧⌘E), set the same flag that opens the sheet (`MacCollectionManagerView.swift:1759`, `:1111`).

### 2.2 "Customize how each document is displayed"

Every document is drawn in one order, whatever the template. From the HTML renderer (`CollectionItemHTMLRenderer.swift:291-413`), which the live preview shows:

1. the citation as an `<h2>`, linked to history.state.gov, or the entry's title override in its place (`:296-309`);
2. the document's address, as a paragraph of its own (`:304-306`);
3. the headnote, when on (`:317-319`);
4. the text, with **the volume's own heading, a second `<h2>`** (`FRUSRenderNodeHTMLSerializer.swift:740-741`), and its dateline. In the volumes before 1955 the text opens with the source note's marker, on a line above that heading. In most documents the dateline is drawn inside an opener's block, beside the classification marking (`:749-750`), and not as a block of its own;
5. the source note under the word *Source:* (`:379-382`);
6. the *See also:* line (`:386-394`);
7. each research note, under *Research Note* (`:397-409`).

What the author can change in that, for one document:

- the text of line 1 (*Title override*, `CollectionEntryInspector.swift:385-403`), which leaves the volume's heading standing under it;
- how much of the text prints (full, a summary, none);
- six switches: highlights, research notes, source note, footnotes, related documents, headnote.

What the author cannot change:

- which of the two headings leads;
- anything about a date;
- the address line;
- any label. *Contents*, *Summary*, *Source:* and *Research Note* are literals in the renderer (`CollectionItemHTMLRenderer.swift:560`, `:359`, `:380`, `:400`); *Headnote* and *See also:* are the app's strings (`:450`, `:387`);
- the order of the parts.

**Why a title of one's own matters.** Documents 470, 473, 474, 475, 476, 477, 480 and 486 of `frus1946v06` all carry one heading: *The Chargé in the Soviet Union (Kennan) to the Secretary of State*. Under *Header & Dateline* the eight contents rows are identical and carry no date. The collection reads a dateline only where it is a document's own top-level block (`CollectionContentAssembly.swift:1468-1482`), all eight keep theirs inside an opener, and a test pins the result (`CollectionResolutionTests.swift:450-452`). Under *Citation* every row is the same citation of some 200 characters, ending in a different number. Document 475 is the telegram a reader knows as the Long Telegram.

**The outline does not show the override.** A document's row reads the indexed header (`CollectionEntryRows.swift:972`), on the Mac too (`MacCollectionManagerView.swift:2022-2028`), so a title the author gave appears in the preview and the export and not in the list they arrange.

### 2.3 Three formats, three layouts

The preview is the HTML export, and its own caption says so: *Preview of the HTML export — PDF and Word pagination will differ* (`CollectionPreviewView.swift:419`). The other two formats differ in more than pagination:

| | HTML and the preview | PDF | Word |
|---|---|---|---|
| The source note | after the text, whole | **above** the headnote and the text, in a rectangle 14 points high, which at 9 points is one line (`PDFCollectionExporter.swift:752-762`; `draw` lays out only the lines its rectangle holds, `:1523-1538`) | after the text, whole |
| A research note | under the document | **a page of its own for each**, in one frame, so a note longer than the page is cut off (`:852-889`) | under the document |
| The contents list | every row | **the cover page only**: the loop stops when the page is full (`guard y >= M + 50 else { break }`, `:634`) | a Word field, with rows cached until Word rebuilds it |
| The contents-list style | honoured | honoured (`:638`) | **never read**: the file names neither `tocStyle` nor `tocLabel`; the cached rows print the citation even where the entry has a title override (`DocxCollectionExporter.swift:1905`) |
| The volume's heading | a second `<h2>` | 13 points bold, the citation heading's own size and weight (`:1063`, `:688`) | Heading 3 under Heading 2 |
| *Summary* over a summary | printed (`CollectionItemHTMLRenderer.swift:359`) | not printed | printed (`:737`) |
| Between documents | no break | a new page | no break; a page of the volume turning inside a text is a hard page break (`:1164-1167`) |
| Page numbers | none | every page | none |

By the arithmetic of its row heights, a PDF's cover holds about ten documents in *Citation* style: a row is capped at 40 points with 6 below it, on a page with some 500 points left under the title. That figure is read from the code and was not measured on a build.

### 2.4 "Yet the interface is very complicated"

Counted from the code, on iOS and iPadOS. The review recounted these and they held.

| Surface | Controls | Of which |
|---|---|---|
| **Collection settings** (iPhone screen, iPad sheet; `CollectionEditorView.swift:806-830`, `:880-913`) | 24 | 8 name and title page, 6 templates, 9 composition (one of them conditional), 1 smart-collection link |
| **A document's inspector** (`CollectionEntryInspector.swift:348-366`) | 9 settings, and more | Title override; *Body depth* and *Summary prompt*, each with a *Default* choice; six *Default / On / Off* pickers. Then a switch per research note, a switch per highlight, and the headnote card's Edit and Generate |
| **Section Defaults** (a heading's sheet; `CollectionEntryRows.swift:192-195`) | 21 | **15 are the whole collection's** (six attributes and nine composition controls) and 6 are the section's |

What makes the count hard to carry:

- **The same setting is in more than one place under more than one name.** The Section Defaults sheet is the inspector opened with its defaults, and one default shows the collection's own settings (`showsCollectionSettings = true`, `CollectionEntryInspector.swift:159`; `:301-303`). So a heading's sheet opens on the collection's *Description*, *Subtitle*, *Author line* and *Append colophon page on export*, which Collection settings calls *Note*, *Subtitle (title page)*, the author field and *Include colophon* (`CollectionCompositionRows.swift:388-427`; `CollectionEditorView.swift:1044-1075`).
- **A section's text depth is not in its sheet.** It is the *Section body* menu on the heading's row (`CollectionEntryRows.swift:177-185`).
- **Eight pickers ask the author to think in inheritance.** Each offers *Default*, and under it a caption, *Default → On*, which does not say whether the section or the collection decided (`CollectionEntryInspector.swift:631-650`).
- **The settings are sorted by where they are stored.** To change how one document looks, the author must first know whether the thing is a collection setting, a section default or a document override, and go there.
- **The Mac has four places of its own:** the gear's popover for the collection; a trailing column for a document; the New Collection form that Add to Collection opens, which carries the whole composition section (`CollectionEditorView.swift:481-510`); and no toolbar control for the preview, which the Collection menu's *Show Preview* (⌥⌘P) turns on and off (`MacCollectionManagerView.swift:1648-1793`; `FRUSExplorerApp.swift:4543-4551`).

### 2.5 The templates

- **One tap, at once, with no undo** (`CollectionCompositionRows.swift:284-286`; `CollectionEditorView.swift:1935-1943`). It overwrites eight fields (`CollectionExporter+App.swift:29-39`).
- **Apparatus only accumulates.** A template adds the blocks it calls for and removes none, so a collection that has tried all six holds all five blocks.
- **"In force" is a comparison.** A card is marked when the collection's eight fields equal its recipe (`matches`, `CollectionExporter+App.swift:46-56`). Change one switch and no card is marked; nothing records which template the author started from.
- **A new collection follows none of the six.** The model's defaults are the full text with footnotes and research notes, and no source note (`Collection.swift:132`, `:143`, `:218`), which is no template's recipe.
- **A template cannot say how a document is laid out**, since no setting does (§2.2).

### 2.6 The preview

- **It forgets the author's place.** Each edit regenerates the page a second later and loads it whole (`webView.loadHTMLString`, `CollectionPreviewView.swift:882-887`), and the file holds no code that keeps or restores a scroll position.
- **It is not joined to the outline.** Choosing a row does not bring its document into view, and tapping a document in the preview does nothing.
- **It shows the first 20 documents** until *Render All* (`initialDocumentCap`, `:153`), and one format (§2.3).
- **It builds its export options by hand** (`:521-531`), apart from `CollectionExportOptions(composing:)`, which the export sheet and the assembly use (`CollectionExporter.swift:592-604`).

### 2.7 Citations

- **The assembly names its formatter.** `BatchContext.formatter` is typed `HistoryAtStateCitationFormatter` and built as one (`CollectionContentAssembly.swift:797`, `:917`). The document heading, a *Citation* contents row, an excerpt's source line, the *See also* line and the Bibliography's rows all come from it.
- **The app has three styles and a preference.** `CitationStyle` is *History at State*, *Chicago* and *Turabian* (`CitationFormatter.swift:30-43`). Settings ▸ Display chooses one. It is mirrored to the reader's other devices only while a device's own sync switch is on, and that switch is off by default (`SettingsSyncCoordinator.swift:12-14`; `SettingsView.swift:93`). The reader's Copy Citation uses it (`DocumentViewModel.swift:213`). A collection does not read it.
- **The exporters read one kind of italics.** Chicago and Turabian mark the title `*…*`; the history.state.gov style marks the series' name `_…_`. All three exporters turn `_…_` into italics and nothing else (`CollectionItemHTMLRenderer.swift:1222`, `DocxCollectionExporter.swift:1982`, `PDFCollectionExporter.swift:1569`).

### 2.8 Seven defects of 1.0, met on the way

The review's skeptics confirmed each by re-reading the code. None was seen in a running app, and none is filed (Q9). The lane that would end each is in §9.

1. **A *Header & Dateline* contents list prints no dateline for most documents** (§2.2).
2. **With Footnotes and Source note both on, the source note prints twice:** once among the footnotes and once as *Source:*. That holds before 1955 too, where the source note is also a footnote and the index stores it *(corrected, second review: this record first said in the volumes from 1955)*. *Full text as printed* and *Everything included* turn both on (`CollectionExporter.swift:226-229`, `:246-250`).
3. **After a template is applied, a document added later lands after its back-matter blocks** (`CollectionEditorView.swift:1922-1925`; `CollectionAddDocumentsSheet.swift:154`; `CollectionDocumentAppend.swift:101-103`).
4. **A footnote call in a heading is written "[1]" into the heading the collection reads** (`CollectionContentAssembly.swift:1522`).
5. **Duplicate does not copy *Stamp active project* or *Append the query log*** (`Collection.swift:799-831`), though its comment says every setting is copied.
6. **A title override typed in the inspector may not reach the preview until something else changes:** the preview's refresh list hashes no `titleOverride` (`CollectionPreviewView.swift:211-266`).
7. **A title override at Summary or None depth, and in every contents row, prints alone and unmarked**, but for the document's address (`CollectionExporter.swift:747-763`).

---

## 3. The document on the page

### 3.1 Nothing the volume prints is replaced

The first form let the author's heading stand in place of the volume's, and the author's date line in place of the printed dateline. The volumes themselves say what that costs.

- **A dateline is the document's text.** Document 475's reads *Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]*. It sits in the telegram's own opener, beside the classification marking. A date line typed in its place takes the hour of dispatch and the time of receipt off the page.
- **A heading carries more than its words.** From 1955 the source note is a footnote on the heading: in 361 of 390 documents of `frus1961-63v11`, 263 of 280 of `frus1969-76v17` and 323 of 374 of `frus1955-57v24`. A heading that is not drawn leaves a note that nothing calls.
- **Brackets already mean something.** The first line of document 475 reads *Answer to Dept's 284, Feb 3 [13]*, and the bracketed *13* is the editors' correction. Its dateline's *[Received …]* is the editors' addition. 24 of the 852 datelines of `frus1950v06` are wholly bracketed by the volume, as *[Washington, undated.]* is. The volumes' own statement of method, from `frus1977-80v06`:

  > "The documents are reproduced as exactly as possible … A heading has been supplied by the editors for each document included in this volume. … Other mistakes and omissions in documents are corrected by bracketed insertions: a correction is set in italic type; an addition in roman type. … All brackets that appear in the original text are so identified in footnotes."

So this form's rule: **a document prints as the volume prints it, whole or not at all, and the author's words are added above it.**

That is the series' own practice in its later volumes. Their editors supply a heading for every document and say so once, in the statement of method; no heading carries a sign *(corrected, second review EDI-8: this record first said it of the series. Of the eight volumes read, the four from 1961–63 on carry the sentence and the four earlier ones do not)*. A collection does the same, one level up:

- the author's title **leads**: it takes the heading's size and the contents row;
- the volume's heading stays under it, smaller, after the words *Printed heading:*, with its footnote calls;
- the words are the mark. They are read aloud, where a bracket is not (NVDA at its default speaks none), and they collide with nothing the volumes print;
- the Note on the Text says it once more, for the whole collection (§3.6).

**Is this what "overriding" asked for?** In what a reader of the export sees first, yes: the contents list and each document's head carry the author's words. What the author does not get is a page from which the volume's heading is gone. Q2 asks whether that is wanted, and says what it would owe.

**1.0's titles keep their meaning.** A title override prints above the volume's heading today (§2.2). Under this rule it still does, so no title already typed changes what it says.

### 3.2 What a document is made of

Each part is named here against the render model (`FRUSDocumentRenderModel`, `FRUSRenderNode.swift:510-528`), since a part a setting names must be something an exporter can draw or leave out whole.

| Part | What it is in the model | What rides with it | The choices |
|---|---|---|---|
| ***The author's lines*** | | | |
| **Your title** | the entry's own field, which is 1.0's `titleOverride` | the collection's number, where the collection numbers its documents | given or not, for one document |
| **Your date line** | a second field of the entry's (Q7) | nothing. No date the app computes with changes, so the Chronology keeps the volume's | given or not, for one document |
| **Citation** | made from the volume and the document's number, in the collection's style (§6) | its link to history.state.gov, and the address 1.0 prints under it | leads the document, or is a small line above it |
| **Headnote** | the entry's headnote draft | its line of attribution | on or off |
| ***The document, as the volume prints it*** | | | |
| **Printed heading** | the document's own heading node (`.heading`, `:62`) | its footnote calls, which from 1955 include the source note's; the collection's number, where this heading leads | prints wherever the text prints. Where the text does not, it is a line read from the index (§3.4) |
| **Text** | every other body node, in order: the source note's marker where the volume leads with it, the opener with its classification marking and dateline (`.letterOpener`, `:68`), the paragraphs, the closer | the printed dateline, the marking, the signature | Full · Summary · None |
| **The volume's notes** | the footnote bodies, with the source note among them (`type: .source`, `:84`) | the calls stay in the text in every case | All · The source note only · None (§3.5) |
| ***The author's research*** | | | |
| **Highlights** | the reader's highlights, painted over the text | | on or off, and which |
| **Your notes** | the reader's research notes on the document | their label | on or off, and which |
| **See also** | the documents this one cites that are also in the collection | | on or off |

Three things the first form offered are gone, each because the model has no such block:

- **A hidden or replaced heading.** The heading carries calls, and in the volumes before 1955 it is not the first block: the source note's marker leads 690 of the 692 documents of `frus1946v06`.
- **A hidden or replaced dateline.** It is inside the opener, beside the marking, in 663 of those 692, and an opener is drawn as one block (`FRUSRenderNodeHTMLSerializer.swift:749-750`).
- **Footnotes and Source note as two switches.** The source note is one of the footnotes (§3.5).

### 3.3 Three openings

Document 475, as each opening prints it. The first is 1.0's.

**The citation leads**, and the volume's heading follows it:

```
Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union,
Volume VI, eds. Rogers P. Churchill and William Slany (Washington, D.C.:
Government Printing Office, 1969), Document 475.                 ← heading size

The Chargé in the Soviet Union (Kennan) to the Secretary of State
SECRET              Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]
511. Answer to Dept's 284, Feb 3 [13] involves questions so intricate …
```

**The printed heading leads**, with the citation as a small line above it:

```
Foreign Relations of the United States, 1946, … Document 475.     ← small

4. The Chargé in the Soviet Union (Kennan) to the Secretary of State   ← heading size
SECRET              Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]
511. Answer to Dept's 284, Feb 3 [13] involves questions so intricate …
```

**Your title**, which leads wherever one is given, under either setting:

```
4. The Long Telegram                                              ← heading size
Moscow, 22 February 1946                                          ← your date line
Foreign Relations of the United States, 1946, … Document 475.     ← small

Printed heading: The Chargé in the Soviet Union (Kennan) to the Secretary of State
SECRET              Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]
511. Answer to Dept's 284, Feb 3 [13] involves questions so intricate …
```

- **The document's own blocks are never parted.** Everything of the author's stands above the first of them, so no exporter draws a line between two nodes of the volume's.
- **The words *Printed heading:* are no part of the document's text.** Each exporter adds them outside the walk that counts highlight offsets, as *Source:* is added today, and as the reader draws a figure's caption outside it. No stored highlight moves.
- **The number is the collection's** (§4.3): 4 of 6 here. It is what tells eight documents with one heading apart, in the contents list and to a reader moving by headings. The volume's own number stays in the citation. Its form is a question for the owner: the later volumes number their documents in print, and *4.* beside *Document 475* must not be taken for the volume's.
- **The source note's marker** stands on a line above the printed heading in the volumes before 1955, where the volume has it. The figures leave it out.

### 3.4 A title never prints without the volume's own words beside it

1.0 breaks this in two places (§2.8, defect 7). The rule, for every place a title of the author's prints:

- **At the document's head, at every depth of text:** the title, the citation, and the printed heading. Where the text does not print, the printed heading is a line read from the index's stored heading, with its calls taken out.
- **In a contents row:** the title, with a second line under it in small type, which is the printed heading and dateline in *Header & Dateline* style, and the citation in *Citation* style.
- **In the outline:** the title, with the printed heading as the row's second line (§2.2).
- **In Word's contents list:** the same two lines (§3.8).
- **In no citation record.** The BibTeX, RIS and Zotero items are built from the volume's heading, and stay so.

**One reading of the printed heading and dateline.** Today the collection reads them from the top-level blocks only. The kit would hold one function that every one of those places calls. It reads:

- the heading, with its calls kept apart from its words;
- the dateline, at the top level, in the opener, or in the closer (23 documents of `frus1946v06` have it only there);
- for an editorial note, its own heading;
- from the index, where the volume is not on the device. The index already stores the dateline of an opener (`IndexingPipeline.extractDateline`, `IndexingPipeline.swift:7347-7358`). Where neither has it, the line is not printed and the citation leads.

That ends defects 1 and 4.

### 3.5 The volume's notes are one choice of three

1.0 has two switches, Footnotes and Source note. They are not two things:

- From 1955 the source note is the first footnote, and it prints with the others whenever footnotes are on, with no test of its type. The Source-note switch decides only a second copy, printed as *Source:* from the index. That is defect 2.
- Before 1955 it is the note that leads the document, and it is a footnote in the model too (`FRUSDocumentParser.swift:1719-1726`).

So the part has three values, which are the three the kit's own first enumeration had (`CollectionFootnoteStyle`, `CollectionExporter.swift:339-346`):

| Value | What prints |
|---|---|
| **All** | every note the volume prints, the source note among them, once |
| **The source note only** | the source note, as *Source:* after the text; the other notes' calls stay in the text |
| **None** | no note; the calls stay in the text |

1.0's pair maps onto them with nothing lost: footnotes on gives *All* whatever the other switch says, which is what prints today less the second copy. The six templates' recipes give *All* for two, *The source note only* for two and *None* for two.

### 3.6 The Note on the Text

A block the collection generates, as it generates a Bibliography. It is the collection's statement of method, and it says, from what the collection does:

- **Titles.** *The compiler has supplied a title for 3 documents. Each stands above its document, and the heading the volume prints follows it as "Printed heading".*
- **Dates.** That a date line under a title is the compiler's, and that the document's own dateline is in its text.
- **Numbers.** That the documents are numbered in the order of the collection, and that each volume's own number is in the citation.
- **What is left out.** Footnotes, and that their numbers remain in the text; source notes; the text itself where a document is a citation or a summary. Each is said for the whole collection, or with the documents named where it holds for some.
- **Summaries and headnotes.** That summaries were written by Apple Intelligence, and which headnotes the compiler wrote or edited.
- **Excerpts.** That quoted passages are excerpts, and how they were checked.

**When it prints.** By default, whenever it has something to say about a document whose text prints: a title or a date line added, a number given, or notes left out. A collection of citations alone gets none. It prints at the end, before the colophon. The author may move it as any block, or remove it (Q2).

**What cannot be removed** is on the page itself: the words *Printed heading:* under a title, and the line of attribution under a summary.

Every sentence above is a draft. The wording is the owner's, as every string in `Docs/EditableContent/` is.

### 3.7 The export's own statement of sources

With the colophon on, every rich format prints a block of sources. For a collection of documents it says: *Read from the text and editorial apparatus of the FRUS volumes, and from no other source*; and where the author wrote prose, *The app never mixes them into the published text* (`ProvenanceSource.swift:141-142`, `:151-152`). The set is derived from the kinds of item (`CollectionExporter.swift:1313-1333`).

A title above a document makes both sentences doubtful. So:

- the plan derives a source for the author's own lines, as the set is derived from the items now;
- the two sentences are reworded to say what stays true: that the documents' text and apparatus are the volumes', and that the author's lines stand apart from them and are named.

### 3.8 One plan for three formats

Today each exporter decides for itself what a document's parts are, in what order, under what words. §2.3 is the result.

- **FRUSCoreKit resolves each document into a plan:** the lines that will print, in order, each with its text, its role (title, citation, printed heading, text, note …), its label and its number. The assembly builds it where it already resolves the cascade (`resolveEntry`, `CollectionContentAssembly.swift:944-1165`).
- **HTML, PDF and Word draw the plan in order.** None decides a part's presence, place or wording. A format keeps its own typography and pagination.
- **§2.3's differences end as a consequence:** the source note follows the text in the PDF and prints whole, a research note flows under its document, and the contents list continues onto further pages.
- **The highlight walk is untouched.** The volume's heading and dateline are part of a document's flat text (`appendFlatText`, `FRUSRenderNode.swift:666`), which highlight offsets count. Under §3.1 every node of the document is drawn, so each exporter's counter walks what it walks today.

**Word's contents list needs a decision of its own.** It is a field, `TOC \o "1-2" \h \z \u`, written dirty so that Word rebuilds it on first open from the heading styles (`DocxCollectionExporter.swift:1865`, `:1873-1874`). After that rebuild its rows are whatever the Heading 2 paragraphs say, and no label of the plan's survives. Two ways to make the rows the plan's:

- **Plain rows, each linked to its document, with a page-number field at its end** (recommended). The rows are text the app wrote, so they match the other two formats and carry a title's second line. Only the page numbers are fields.
- **A contents field built from entries the app marks** in place of heading styles, which Word can rebuild whole.

Which of the two Word and Pages show correctly is not known here. §12 owes that run before the lane writes either.

**The export's own accessibility.** In the HTML and in Word the title is the document's heading, and the printed heading is a heading one level down whose text begins with its two words. The PDF has no tags, title or links today, and this design adds none: the web page and the Word file are the accessible exports, and a tagged PDF is a candidate (§8).

---

## 4. A template, and the author's changes on top of it

### 4.1 One set of settings, at three scopes

Every setting of §3.2 that is a choice, and not a document's own content, is a key of one value, the same value at every scope:

| Setting | Values |
|---|---|
| Opening | The citation leads · The printed heading leads |
| Text | Full · Summary · None, and the prompt a summary is written with |
| The volume's notes | All · The source note only · None |
| Headnote | on, off |
| Your notes | on, off |
| Highlights | on, off |
| See also | on, off |

- **The collection holds every key.** A section or a document holds only the keys it changes.
- **A value comes from the nearest scope that sets it:** the document; else the section that encloses it, and then each section outside that one, since sections nest three deep (`CollectionOutline.swift:275-282`); else the collection.
- **Content is not a setting.** A document's title and date line, which notes and which highlights, and its headnote's text belong to that document and to no scope above it.

The first form's grid of parts and scopes had cells with nothing to store them, and this value closes them. The collection gets a setting for See also, which 1.0 lacks. A section's headnote is followed by its documents, which 1.0's cascade does not do; a section's See also is followed in 1.0 already *(corrected, second review: this record first said 1.0 followed neither; `CollectionContentAssembly.swift:611-612`, `:1103`)*. The summary prompt has a row, under Text.

**What every row does:**

1. **It shows what is in force**, as a switch or a menu that names its value in full. No row offers *Default*.
2. **It says in words where the value comes from:** *From the collection*, *From the section "Kennan's reporting"*, or *Changed for this document*. The words are on the row and are spoken. No dot stands in for them.
3. **A changed row carries its own way back:** *Use the section's* or *Use the collection's*, which removes the change.
4. **A row whose value is set elsewhere offers the way there:** *Go to the section*. So a change is always made where it is seen, or the author is taken to where it is set.
5. **A row that cannot apply says why, and keeps its value:** Highlights reads *Prints with the text* and is dimmed while the text is left out.

### 4.2 The settings on screen are those of what is selected

No control changes the scope. The scope is the selection:

- **The collection** is the first row of its own outline, and the gear selects it. It is reachable whatever else is selected (§5.7) *(corrected, second review INT-6: this record first said this is what the build-28 tester asked for. The tester asked that the collection's attributes be reachable "after refocusing on a document", and the state reported was "not reachable without clearing the selection", which selecting the collection's row is)*.
- **A section** is its heading's row.
- **A document** is its row.

The surface is titled by what it holds: *Kennan from Moscow, 1946*; *Section: Kennan's reporting*; *Document 475*.

At a wider scope a row cannot show what is in force for every document under it, so it says how many differ: *Footnotes: All · 2 documents differ*. The count opens the list of them, and each name selects that document.

### 4.3 A template

- **A template is a recipe for the collection's set of §4.1**, with the contents-list style, the word cloud and the apparatus blocks it calls for. That is L25's recipe (`CollectionPreset.Recipe`, `CollectionExporter.swift:201-250`) with two keys added, Opening and Numbering.
- **The collection records the template it follows.** "In force" is a stored fact, and the gallery marks that card. The collection's own changes are counted by comparing its values with the recipe: *Following Full text as printed · 3 changes of your own*. *Review* lists them, each with *Use the template's*.
- **Choosing a template for the collection asks first**, and lists what the choice would do: each setting that would change, old to new; each block it would add; each block the last template placed that this one does not call for, which it would remove. The author may untick any line. Changes made to sections and documents are not touched, and the question says how many there are.
- **A template owns only the blocks it placed and the author left alone.** A block the author added, moved or retitled is theirs, and no template removes it. The apparatus stays rows in the outline, as decision A11 made it (§5.7).
- **A document arrives ahead of the back matter.** A document added to a collection goes before the run of apparatus blocks at its end, and not after it (defect 3).
- **A shipped template's recipe is fixed** from the version that ships it. A different look is a new template with a new name.

**The six of decision 139, with the two new keys.** A proposal, for Q4:

| Template | Opening | Numbering | Text | The volume's notes |
|---|---|---|---|---|
| Full text as printed | The printed heading leads | On | Full | All |
| Full text with your annotations | The printed heading leads | On | Full | The source note only |
| Summaries with overview | The printed heading leads | On | Summary | None |
| Citations with your notes | The citation leads | Off | None | None |
| Citations with archival sources | The citation leads | Off | None | The source note only |
| Everything included | The citation leads | Off | Full | All |

The last two columns are L25's recipes, restated in §3.5's terms.

- **Numbering is the collection's alone:** the documents numbered 1 to *n* in its order, at each lead and in each contents row.
- **A new collection starts under *Full text as printed*,** with that template's two blocks in place and its first document arriving ahead of them.
- **An upgraded collection keeps 1.0's layout.** 1.0 had no say about the opening, so the upgrade records *The citation leads* and no numbering as that collection's own, whatever template its other settings match (§7.4) *(corrected, second review H13: 1.0 does number the documents in its contents list, in all three formats and in three ways; what it does not print is a number at a document's head)*. It prints as it did, apart from §2.8's defects.

### 4.4 A template at export is for that export

The export sheet lists *As this collection is set* first, and then the six (§5.1). Choosing one of the six:

- **writes nothing.** The kit resolves a copy of the collection's values in which the recipe's keys are the template's. The assembly already resolves from values (`CollectionContentAssembly` over `CollectionExport`), so no stored record is touched;
- **takes the template as it is** for what a recipe has a say in, and the collection's own for what no template touches: the citation style, the labels, the title page, the colophon;
- **keeps what the author set for particular sections and documents:** a title, a date line, the notes chosen, and a document set to print in full. The sheet's sentence counts them: *6 documents as citations with your notes. 1 document keeps its own settings.*
- **prints the template's blocks at the end,** with any block the author placed where it stands, and without the blocks the collection's own template placed.

To make a template the collection's own is an act in the editor (§4.3).

### 4.5 A smart collection

A collection linked to a saved search prints that search's documents, and the preview shows them; neither editor lists them *(corrected, second review INT-7: this record first said it lists them; `CollectionOutline+App.swift:214-224`)*. They are made from the results at each resolve and are not stored (`CollectionContentAssembly.swift:181-182`, `:731-756`). So:

- **It has one scope, the collection's:** the template, the set of §4.1, the title page, the citation style.
- **A document of its list has no settings.** Selecting one says so, and offers *Create Static Snapshot*, which is the way to a collection whose documents can be changed one by one.
- **The snapshot carries every setting.** It is made by copying the collection's value whole, and not field by field (§7.6).

### 4.6 Words

The first form's words collided with the app's and the volumes' own. This form's:

| The first form said | This form says | Why |
|---|---|---|
| Heading | **Your title**; **Printed heading** | a section has a heading too |
| Reference | **Citation** | *references* are the app's cross-references |
| Dateline, as printed, your own or hidden | **Your date line**; the printed dateline is part of the text | §3.1 |
| Not printed | **Left out** | the volumes' own footnotes say *Not printed.* Document 475's first one begins with those words |
| Footnotes; Source note | **The volume's notes** | §3.5 |
| 4 notes; 2 notes | **4 footnotes**; **2 of your notes** | two kinds of note |
| This document · This section · Whole collection | no control | §4.2 |
| Your settings | **3 changes of your own** | nothing is kept aside |

---

## 5. The interface

### 5.1 Export

The same sheet on every platform.

- **Look.** *As this collection is set* leads, and names the template the collection follows and the count of the author's changes. Then the six templates. One line under the list: *A template chosen here is for this export.*
- **Format.** PDF, Word and Web page as one control. *More formats* opens BibTeX, RIS and `.fruscollection`. The Zotero row stays as it is.
- **What will print**, in a sentence (§4.4).
- **Export**, which is the one button pinned under the list. The first form pinned two, which the review judged would leave under one row in view at the largest text sizes on an iPhone SE.

It opens on *As this collection is set* and on the format this collection last exported as on this device. That memory is the device's own and is not a fact about the collection.

Where it opens from:

- the editor's *Export…*, as now;
- **the Collections list:** *Export…* in a collection's context menu, on iOS and in the Mac's Manage Collections sheet;
- **the Mac's Collection menu:** *Export Collection…* (⇧⌘E, as now);
- **Export Again**, beside each of those, once the collection has been exported on this device. Its label says what it will do: *Export Again: PDF, as this collection is set*. Before a first export it is not offered.

The quotation check (the manuals' *The Excerpt Check*) and the missing-volume and summary-generation waits stay in the sheet. Export Again runs them too, and stops on the sheet when one has something to say.

**This puts a choice about content back in the export sheet,** which `Collections-Rework-Scope.md` took out so that export would be "format + destination". What differs: the six switches it removed do not return; the choice is of one named recipe; the collection's own look is the default; and the sheet still writes nothing.

### 5.2 Settings, by what is selected

**The collection** (its first row, or the gear):

- **In view when it opens:** the template gallery, with the line *Following … · 3 changes of your own · Review*; the title page's five fields (name, description, subtitle, author line, introduction); the linked saved search; and *Customize*.
- **Under *Customize*:**
  - *Each document:* the seven settings of §4.1, and Numbering;
  - *Lists and citations:* the contents-list style, the citation style;
  - *Back matter:* Note on the Text, colophon, project stamp, query log, word cloud;
  - *Wording:* the collection's own words (below).

**A section** (its heading's row): its title, and the seven settings of §4.1 as its documents' own.

**A document** (its row):

- *Yours:* your title, your date line, the headnote and its card, your notes and which, highlights and which, See also;
- *From the volume:* Opening, Text, the volume's notes.

**The opening, drawn where it is set.** A document's settings begin with its opening as it will print: the lines of §3.3, drawn natively from the plan. On iPad and iPhone the settings cover the page (§5.3), so this is where a title typed there is seen at once. It is new in this form.

**The collection's own words.** The owner asked for "my own … labels". A table of the words the app prints, each with a field: *Contents*, *Headnote*, *Summary*, *Research Note*, *See also*, *Printed heading*, and the five apparatus titles. So a course reader's *Research Note* becomes *Commentary*, and a Bibliography *Works Cited*.

- They are the collection's apparatus and carry no mark. None is a word of the volume's.
- ***Source:* is not in the table.** From the 1955–57 volumes at least, the volumes print that word themselves, at the head of the source note *(corrected, second review EDI-8: this record first said from 1961; 323 of the 332 source notes of `frus1955-57v24` open with it)*. A word the volume prints is not the collection's to change.

**The Mac's New Collection form,** which Add to Collection opens, becomes a name and the gallery. Today it carries the whole composition section (§2.4).

### 5.3 The preview, and pointing at it

**On every platform the preview is the proof of the export.** Three things it lacks today come first, since anything else depends on them:

- it keeps the author's place when the page reloads;
- choosing a row brings its document into view, and renders it if it is past the first 20;
- each document on the page is named by its entry and not by its document, so that a document entered twice is two places.

**Pointing is the Mac's.** There the settings are a column beside the page, and both stay in view.

- ***Show Parts*** is a switch on the preview and in the View menu. On, each part of a document is outlined, with its name on the outline's own corner, and a line under the document names what is left out. Off, the page is the proof, and its links work.
- **A click on a part selects that document's row and opens that part's row in the column.** Keyboard focus goes with it, and the column's title says what is now selected. Nothing opens over the page.
- **Every part is reachable without the page,** through the column, by keyboard and by VoiceOver. The page is never the only way.

**On iPad and iPhone the way in is the row.** On iPad a document's settings are a sheet over both columns (`CollectionEditorView.swift:863-873`). On iPhone the outline and the preview are never on screen together (`:738-745`). So a tap on the page cannot be answered beside the page on either, and the opening drawn in the settings (§5.2) is what shows a change as it is made. Pointing on iPad would need a settings column that the editor draws itself, as the reader draws its Research rail since R6a. That is a candidate (§8) and no part of the lanes.

### 5.4 On each platform

| | Mac | iPad | iPhone |
|---|---|---|---|
| **Layout** | Outline · preview · settings column, as now, with a toolbar control for the preview | Outline · preview, with settings as a sheet, as now | Outline, with Preview behind the segmented control, as now |
| **The collection** | Its first row, or the gear; shown in the column | The gear's sheet, as now | The *Collection settings* row, as now |
| **A section** | Its heading's row | The heading's pill | The heading's pill |
| **A document** | Its row, or a click on it in the preview | Its row or its Configure pill | Its row |
| **Templates** | A grid, three rows of two | The same grid | Rows, each with its line of description |
| **Show Parts** | Yes | No | No |
| **Export** | The sheet; the Collection menu; Manage Collections | The sheet; the list's context menu | The sheet; the list's context menu |

An outline row leads with the author's title where there is one, with the printed heading as its second line.

### 5.5 The count

Counted from §5.2's own lists, the way §2.4 counts today's.

| Scope | Today | This design | |
|---|---|---|---|
| **The collection** | 24, all in view | **14 in view; 31 with *Customize* open** | Six new settings: Opening, Numbering, See also for the collection, the citation style, the Note on the Text, the wording table. Two new controls: *Review* and *Customize*. One fewer where two switches became one choice |
| **A section** | 21 in its sheet, and one menu on its row; 7 are the section's | **9** | The collection's 15 leave the sheet. The section's own go from 7 to 9, its title and Opening among them |
| **A document** | 9, then a switch per note and per highlight | **10**, then the same | Two switches became one choice; Opening and the date line are new |
| **The export sheet** | 7 | **12** | Seven looks, three formats, More formats, the Zotero row |

Each count includes the summary prompt, which shows only where the text is a summary, as §2.4's does.

*(Corrected, second review INT-1: two of today's figures stand on a different basis from the design's. Today's 7 for a section leaves out the heading's own title field, which the design's 9 counts. Today's 7 for the sheet counts each of six format cards, where the design's 12 counts More formats as one. The review's H19 recounts the design's own figures.)*

The design does not reduce the number of settings. It adds six to the collection's, each one asked for or owed. What it reduces:

- **what is in view** when the collection's settings open, from 24 to 14;
- **the places a setting can be,** from three surfaces under two sets of names to one list for each thing selected;
- **what a row asks:** none asks the author to choose *Default*;
- **what a first export needs,** which is no setting at all.

### 5.6 The alternatives, and why this one

The first form set out three interfaces. Where each stands now:

- **Templates only (Option A).** Two surfaces and nothing to learn. It cannot meet *fine-tune any aspect*, and it removes what the app does today. It is this design's first screen and not its only one.
- **One inspector with a scope switch (Option B as first drawn).** Withdrawn. The switch was a mode: it moved back to *This document* when a row was selected, so a change meant for the collection landed on one document. The app built an inspector headed by a two-way switch once and took it out (§5.7).
- **Popovers on the page (Option C as first drawn).** Withdrawn. A native popover would be anchored to a rectangle of a page that is discarded and reloaded a second after each change made in it, and on iPad and iPhone the page is not in view while a setting is changed.

What is recommended is Option B's list without its switch, behind Option A's gallery, with Option C's pointing where the page and the settings can be seen together, which is the Mac.

### 5.7 Four arrangements this app built and withdrew

The first form proposed each of these without naming its history.

| Arrangement | What happened before | This form |
|---|---|---|
| An inspector headed by a segmented switch | Built as *Document \| Composition*, and removed by Composer v2 (`CollectionEditorView.swift:2045-2049`) | No switch. The selection is the scope (§4.2) |
| The collection's settings shown in the inspector when nothing is selected | A build-28 tester reported them out of reach once a document was focused (`Completed/188-189-Tester-Feedback-Build28-Plan.md`, 188-E). Composer v2 moved them behind the gear | The gear always reaches them, whatever is selected, and they are never drawn beside a document's (`MacCollectionManagerView.swift:1068-1072`) |
| Content choices in the export sheet | Six controls, deleted by the Collections rework | One choice of a named recipe that writes nothing (§5.1). It is a partial return, and Q3 asks |
| Collection-level switches for apparatus | Decision A11 chose placeable rows, since "toggles create a parallel structure system" (`Completed/Collections-Authoring-Scope.md:198`) | Rows, as now. The first form's five switches are gone |

---

## 6. Citation styles

- **One setting for the collection:** History at State, Chicago, Turabian. It governs every place a citation prints: the citation at a document's head, a contents row in *Citation* style, an excerpt's source line, the *See also* line, and the Bibliography's and the Chronology's rows.
- **An upgraded collection keeps history.state.gov style**, so its exports do not move. Q5 asks what a new collection starts with.

For document 475, as the three formatters write it:

| Style | The citation |
|---|---|
| History at State | *Foreign Relations of the United States*, 1946, Eastern Europe, The Soviet Union, Volume VI, eds. Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Chicago | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*, edited by Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Turabian | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*. Edited by Rogers P. Churchill and William Slany. Washington, D.C.: Government Printing Office, 1969. Document 475. |

**What it takes in the kit.**

- `BatchContext.formatter` becomes `any CitationFormatter`, made from the collection's style (`CollectionContentAssembly.swift:797`, `:917`).
- The assembly hands every exporter one kind of italics, turning `*…*` into `_…_` where a citation is made, so no exporter learns a second marker (§2.7).
- The Bibliography sorts by volume and number, not by the citation's text (`CollectionGeneratedBlocks.swift:304-333`), so a style changes no order.

**Two things the first form claimed and this one does not.**

- **A short form** (*FRUS*, 1946, vol. VI, doc. 475) is not in the core. Year, volume and document name more than one volume for 133 of the manifest's 553, and for 48 even with a part added; 99 titles have no volume number. *FRUS, 1945, vol. I* is both the Potsdam volume and the general one, which the app met in #1388 (`VolumeLabels.swift:60-66`). A short form needs a rule that is unique over the whole manifest before it is shown to anyone. It is a candidate (§8).
- **That each style is right in every place.** The review found it plausible that the app's Chicago has a note's shape and its Turabian a bibliography entry's, while a collection has both places, and that neither names the document cited. The two manuals could not be fetched. Q5 puts it to the owner, who can judge it at sight; §12 owes the desk check.

---

## 7. What is stored: two new record types, and a one-way upgrade

### 7.1 Why new types

The owner offered it: "you can base the collections revamp on a new model type and make conversion a one-way upgrade process." It would help, for three reasons, and the first is the weightiest.

1. **The settings of §4 do not fit 1.0's fields without two forms of the same fact.** 1.0 stores eight composition fields on a collection and eight override fields on an entry, with footnotes and source note as a pair. §4 needs one value at every scope, a three-way choice where the pair was, and a recorded template. On the existing types that means new fields beside the old ones, and build 1861 goes on writing the old ones. A template chip tapped on an iPhone running 1861 would rewrite the eight fields under a recorded template that no longer describes them, which is the review's DATA-4. With new types, 1861 cannot write a record it does not know.
2. **Every stored state of a 1.0 collection gets one stated meaning,** by a function that takes the old values and gives the new, with a fixture for each state and a report the author can read (§7.4). The review asked for that table (INT-5).
3. **Every copy can go through one value.** Duplicate copies its fields by name and misses two (§2.8, defect 5). Create Static Snapshot copies eight (`SmartCollectionSnapshot.swift:112-134`). Built value-first, a copy is the value read and written back under new ids (§7.6).

**What new types do not settle:**

- two builds that both know the new types but differ in what settings they know (§7.3 gives the rule);
- two devices changing one record's settings before either syncs: the later writer's value stands;
- whether a device updated later receives records of a type it did not know when they were uploaded. §12 owes that run before the lane starts.

### 7.2 The two types

Working names: `DocumentCollection` and `DocumentCollectionEntry`. The lane may choose others, and the choice is permanent, since a CloudKit record type is never renamed. They follow CloudKit's rules as the existing models do: every property optional or with a default, the relationship optional with an inverse.

| | `DocumentCollection` | `DocumentCollectionEntry` |
|---|---|---|
| **Identity and structure** | `id`, `createdAt`, `lastModified`, `formatVersion` | the same four; `collectionId` and the relationship; `sortOrder`, `level`, `kind` |
| **Content**, each a property, since the app queries or sorts by several and each one's meaning is fixed | name, description, subtitle, author line, introduction and its rich text; the projects; the linked saved search | the document and its volume; **title** and **date line**; a heading's or a note block's text and rich text; an excerpt's four anchors; an apparatus block's type, and the template that placed it; the notes and highlights chosen; the headnote draft |
| **Presentation**, one value | the template it follows; **the settings value**: every key of §4.1, and the collection's alone (numbering, contents-list style, citation style, the wording table, the five back-matter switches) | **the settings value**: only the keys this row changes |
| **Where it came from** | when it was upgraded, and the 1.0 record's date at that moment (§7.5) | |

**Presentation is one value for each record,** stored as text, with keys FRUSCoreKit declares. `SyncedPreferences.listOrderJSON` already has that shape. The reason is the same as in the first form, and the review found it sound: *fine-tune any aspect* is a list that will grow, and a key added later is not a CloudKit schema change, where a property added later is a deploy.

### 7.3 The rule for writing a settings value

The review's first finding was that a build which decodes the keys it knows and writes the value back erases the rest. The rule:

1. **Each record carries `formatVersion`:** the lowest version of the collections format that can write the record without loss. Everything in §3 to §6 is version 1.
2. **A build writes a record only where the record's version is no higher than its own.** Otherwise the collection opens for reading there, with one line saying why. It can be read, previewed and exported, with a notice that settings from a later version are not applied.
3. **A later setting raises a record's version only when the record first uses it.** That is the collection file's own rule, write the minimum (`NativeCollectionFormat.swift:347-351`).
4. **A decoder passes over a key it does not know,** and rule 2 means it is never asked to write one back.
5. **A test holds it:** a value with an unknown key and a higher version, given to the current code, is not written.

The app already has the habit in one place: an entry kind a later build wrote is never written back (`Collection.swift:684-691`).

### 7.4 The upgrade

**A function in FRUSCoreKit, over values.** It takes a 1.0 collection as the research export already carries one (`CollectionExport` with its entries) and gives the new value. It reads no store and writes none, so it runs in `swift test`, with a fixture for every stored state. The app writes what it answers through its own context, as it applies the rows an Archives Visit's rules answer.

| 1.0 holds | The new record holds |
|---|---|
| name, note, subtitle, author line, introduction, projects, saved-search link | the same |
| the eight composition fields | the collection's settings, every key set |
| those eight equal to a template's recipe (`matches`) | that template, recorded; otherwise none, and the gallery says the settings came from 1.0 |
| nothing about the opening, numbering or a citation style | *The citation leads*, no numbering, History at State: what 1.0 prints *(corrected, second review H13: 1.0 numbers its contents rows; it prints no number at a document's head)* |
| Footnotes and Source note, as a pair | the volume's notes, as §3.5 maps them |
| colophon, project stamp, query log, word cloud | the same four switches |
| an entry's kind, level, order, document, text, rich text, excerpt anchors, block type, notes and highlights chosen | the same, under the same ids |
| `titleOverride` | the title, with the meaning it has now (§3.1) |
| the eight override fields; *Default* | the keys the entry changes; a *Default* is a key not held |
| an apparatus block | the block, as the author's own, since 1.0 did not record what placed it |
| an entry's headnote draft | a copy of it, so that a delete on a 1.0 device cannot remove it (`Collection.swift:885-889`) |
| a kind this build does not know | carried as stored, and inert |

**The same ids.** The new collection and its entries take the ids of the old. So every pointer the app keeps to a collection still finds it, a second run finds the work done, and two devices that both upgrade produce records the duplicate cleanup can pair *(corrected, second review H1: the cleanup names ten types and neither of these, and for copies that share an id and a creation date the device's own fetch order decides which is kept, `DuplicateRecordCleanup.swift:64-66`, `:243-245`)*. A headnote draft's copy takes an id derived from its entry's, as an Archives Visit derives a child row's (`ArchiveVisitPlanWrites.swift:76`), so two devices make the same copy.

**When it runs.** On a build that has the new types, after the first iCloud import of a launch has settled, which is where the app's other repairs wait (`SummarizationPromptSeeder.swift:165-168`) *(corrected, second review H2: the wait those repairs use is eight seconds of quiet after any import event, `FRUSExplorerApp.swift:3379-3384`, and not the end of a first import)*; or at once on a device with no iCloud account. Until then a 1.0 collection is listed, previewed and exported through the same function, and is not editable, with one button to upgrade it now.

**It writes, and deletes nothing.** The 1.0 records stay as they are. A build that has the new types no longer lists them. Settings ▸ Data & Recovery says how many there are and keeps the report.

- The inventory's interlock binds a pass that "both writes an undeployed type and destroys its source" (`CloudKitSchemaInventory.swift:485-490`). This one destroys nothing, so an undeployed write would cost a failed upload and no data. What keeps such a build from shipping is the archive's schema check (#1531) *(corrected, second review H5: the check does not require an identifier listed as awaiting a writer, `Scripts/check_cloudkit_schema.py:151-154`)*.
- It writes on a context the modification stamper does not observe, as Import from JSON does, so an upgraded record keeps the 1.0 record's dates.

**The report,** shown once and kept: each collection, the template it now follows or that its settings came from 1.0, and what will print differently. That last list is §2.8's defects where they touch the collection, and the Note on the Text where it has something to say.

### 7.5 The hard cases

| Case | What happens |
|---|---|
| **Two devices upgrade one collection** before either has the other's records | The same ids, and the same content where both held the same 1.0 state. The cleanup keeps one: the copy changed since its upgrade, else the one made from the later 1.0 state. An entry deleted on one device after its upgrade can come back from the other's copy, and can be deleted again |
| **A device on 1.0 changes a collection after it was upgraded** | The new record does not follow. A newer build sees that the 1.0 record is later than the date kept at the upgrade, says so on that collection, and offers *Upgrade That Version as a Copy*. Nothing is merged *(corrected, second review H3: in 1.0 an edit to an entry does not move its collection's date, `Collection.swift:28-29`, so this test misses most changes)* |
| **A collection made in the new version** | Does not appear on a device running 1.0. The release notes say so |
| **A collection deleted in the new version** | Its 1.0 record is deleted with it, after one question that says devices on 1.0 will lose it too. Otherwise another device would upgrade it again |
| **A collection deleted on a 1.0 device after its upgrade** | The upgraded collection stays |
| **A research export of format 7 or earlier, or a collection file of version 1 or 2, is imported** | Its collections pass through the same function |
| **A smart collection** | Its link is carried, and so are any entries from before the link, as stored |
| **A device offline at its first launch of the new build** | Its 1.0 collections are listed, previewed and exported, and each can be upgraded by its button |

### 7.6 What carries the new types

- **The research export takes format version 8.** It carries the new types, and a 1.0 collection not yet upgraded is exported as its upgrade. `ResearchImportPlan.ModelType` gains the two types at version 8 (`ResearchImportPlan.swift:216`), and a fixture of version 8 joins the seven. A version-7 importer refuses a version-8 file whole, as it would any later file.
- **The collection file takes version 3,** and a 1.0 app refuses to open one, with the message it has for a later file (`NativeCollectionFormat.swift:318`). Writing the minimum, so that an untouched collection is still a version-2 file, would need a second function from the new values back to the old. This design does not propose it: one-way is what the owner offered.
- **Duplicate and Create Static Snapshot** read the value and write it under new ids.
- **One test walks every copy.** It reads the two models' stored properties from the schema, as `CloudKitSchemaInventoryTests` does, and fails when a property is in no mapping. Duplicate, the snapshot, the file, the export and the upgrade are each held to a round trip of a fixture with every field set.
- **What asks before a delete** reads the value too. Today the question before a row is deleted reads a hand-kept list of fields (`CollectionEntryRows.swift:357-375`), and so does the preview's refresh list (§2.8, defect 6).
- **No index version.** Nothing here changes what is indexed, the reader's page or `renderingVersion`.
- **The web edition** resolves collections through the same kit values, and follows by its own rules (CLAUDE.md, *Web edition*). The lane writes its line of hand-over.

### 7.7 What it costs

- **About fifty files of the app and twenty-five of its tests name the two model types** (53 and 26 by a search at `efd73ec`), in twelve of the app's folders. Each changes, most of them by the type's name alone.
- **One CloudKit promotion of two record types and their fields**, by the R-7 gate: the inventory, `identifiersAwaitingDeploy`, the owner's write on a Development build, the Dashboard's deploy, and `check_cloudkit_schema.py` before an archive. The two 1.0 types stay in Production, which is append-only. A later release may take them out of the model, as R-2b took out the session models, which needs no deploy.
- **A fork while devices are on different versions** (§7.5, rows 2 and 3).
- **A collection file made by the new version cannot be opened by 1.0** (§7.6).

### 7.8 The other way

Keep `Collection` and `CollectionEntry`, and add properties. It costs no renaming and no fork. It keeps the first reason of §7.1: two forms of the same fact, one of which 1861 goes on writing. And it leaves a device updated from 1861 holding nothing in the new properties of a record it had already imported, if the mirror does not fetch such a record again, which the review could not settle (its G17). Q6 asks.

---

## 8. Other authorial capabilities

Candidates, in the order this design would take them. Q8 asks which. Two of the first form's nine moved into the core: the collection's own words (§5.2), and its numbering at the lead and in the contents list (§4.3) *(corrected, second review H13: a number in the contents list is not new; 1.0 prints one)*.

1. **Selected passages as a document's text.** A fourth choice for Text: the passages the author highlighted in the document, in its order, with a sign where text is left out, under the document's own heading and dateline. It is what a course reader does most: abridge. The highlights, their stored passages and the per-document choice of which already exist (`selectedHighlightIds`); the excerpt check would cover them. The sign for an omission is not brackets (§3.1), and is the lane's first question.
2. **The collection's numbers in its indexes.** The Persons and Thematic indexes could cite *Documents 3, 7 and 12* of the collection, where they now cite each volume's number.
3. **Where notes go.** Before the text, as an introduction to a document, or after it, as now.
4. **Save as Template.** An edited look kept under a name for other collections. It is authored content, so it is a record type of its own and not a field of the one-record preferences, whose rules would lose it. If it is wanted, it should be decided before §7's deploy, so that its type rides the same promotion.
5. **A date alone in contents rows.** *22 February 1946* in place of the printed dateline, from the date the index stores, in the form the Chronology prints.
6. **The page.** Letter or A4; each document on a new page, or run on; page numbers in Word as in the PDF.
7. **Several formats in one export**, such as the PDF with its `.bib`.
8. **Same settings as…** Copy one document's changes to others, or to its section.
9. **See also, by page.** The line lists the documents a document cites that are also in the collection (`relatedDocumentTargets`, `CollectionContentAssembly.swift:1182-1194`). A reference to a printed page is stored under its page (`CrossReferenceStore.swift:757-759`), so it matches none, and the volumes through the 1950s refer by page: of the six documents the canvas uses, none cites another by its number. The app already maps a cited page to the documents on it (`cited-page-map.json`).
10. **A short citation form** (§6), once it has a rule over the manifest.
11. **A tagged PDF**, with a title and links, from the roles the plan gives each line (§3.8).
12. **A settings column on iPad,** drawn by the editor itself, and pointing there once it exists (§5.3).

Considered and not proposed: editing a source note's text or a footnote (it is the volume's editors' annotation of the text); a document printed without its heading or its dateline (§3.1; Q2 asks); fonts and colours (no theming engine, item 9 of `Collections-Authoring-Scope.md`); editing inside the preview (its item 1), which this design keeps to: on the Mac a click selects, and nothing on the page becomes editable.

---

## 9. Lanes

None needs an index version. Each lane's own size is said by what it touches; no estimate of time is given.

| Lane | What | Stored data | Changes exports | Before it starts |
|---|---|---|---|---|
| **1. Export from anywhere, under a look for one export** | The sheet's look row, resolving a changed copy of the values and writing nothing; *Export…* in the Collections list and Manage Collections; the format remembered on the device; Export Again; the export's run moved out of the sheet's view, where it sits today (`CollectionExportSheet.swift:447`) | None | No | Q3 |
| **2. One plan for three formats** | §3.8; the parts named against the render model (§3.2); the one reading of a printed heading and dateline (§3.4); the volume's notes printed once (§3.5); a title never alone (§3.4); Word's contents list; defects 1, 2, 4, 6 and 7 | None | **Yes**, and the list is §2.8's with §2.3's | The Word and Pages run (§12) |
| **3. The new record types and the upgrade** | §7 whole, under today's screens: the composition controls and the *Default / On / Off* pickers write the new values. No screen changes but what the upgrade adds | Two record types: **one CloudKit deploy**; research export 8; collection file 3 | No | Q6; the two-device run (§12) |
| **4. What the settings can say** | The template recorded and asked before; Opening, Numbering, the citation style, the date line, the wording table; the Note on the Text; the statement of sources; a document arriving ahead of the back matter (defect 3). Each with a plain control in today's surfaces, so that it can be used and checked | Keys of the settings value; no deploy | Only where used, and the Note where it has something to say | Lanes 2 and 3; Q2, Q4, Q5, Q7 |
| **5. Settings by what is selected** | §5.2 on three platforms: the collection as the outline's first row, the gallery first, the lists for a section and a document, the opening drawn in the settings, a smart collection's one scope, the Mac's New Collection form | None | No | Lane 4; Q1 |
| **6. The Mac's preview points** | §5.3: the page keeps its place, a row brings its document into view, *Show Parts*, a click selects | None | No | Lane 5 |
| **7. From §8** | As Q8 decides | Keys of the settings value; a record type if saved templates are taken | Only where used | Lane 3 |

**Lanes 1 and 2 do not wait for the new types.** Both work on 1.0's values, and either could ship as a small release's row. Lane 1 answers the first ask by itself.

**What each lane owes, beyond the landing runs the plan of record names.**

- **Shared code** (lanes 1, 2, 3, 4 and 7): `swift build --target FRUSCoreKit` and `swift test`, with the unit target and the Mac build.
  - `CollectionRenderingPinTests` pins the HTML page and the Word package by SHA-256. Lane 2 moves both, and re-takes each with its reason: the source note printed once is a change to the HTML too.
  - The PDF has no pin. `CollectionExportParityTests` (#960) holds the three exporters to one inventory of blocks, which a source note cut to a line and a contents list cut at a page both pass. Lane 2 takes it to the blocks' order, a source note longer than a line, a research note longer than a page and a contents list longer than the cover.
  - `CollectionResolutionTests.swift:450-452` pins a dateline in an opener as absent from the header. Lane 2 changes that expectation, and says why there.
- **The CloudKit gate** (lane 3; CLAUDE.md, *CloudKit schema-deploy gate*), and with it the research export's version 8, its fixture and its `ModelType` cases; the copy test of §7.6; the upgrade's fixtures; the report.
- **The six UI suites of `CollectionEditorTitleTests.swift`** hold the editor. Lane 3 must leave them green without a change, which is the evidence that the storage moved and the behaviour did not. Lane 5 rewrites what several walk; each is brought to the new surface in the same change, with its reason, and read first in `UI-Test-Destinations-Runbook.md`.
- **Strings and screens** (lanes 1, 4, 5, 6): the blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` and the ranges they move. For lane 3 those include the fourteen ranged blocks that cite `Collection.swift`, whose strings the new types must use too; both manuals' chapter 12; the captures that show the editor (`ipad/collections-editor`, `macos/collections`), store frame 07 if its screen changes, and the tour's step 16. `CollectionTests.swift:5644-5653` pins two source lines of the export sheet, which lane 1 rewrites.
- **Accessibility, in the lane and not after it.** The first form named none.

| Lane | The check |
|---|---|
| 1 | The sheet at the largest text sizes on iPhone 17 and iPhone SE, with one button pinned, as a fit suite. VoiceOver: each look speaks its name, its line and whether it is chosen, and the group says once that the choice is for this export |
| 2 | In the HTML and in Word, the title is the document's heading and the printed heading is one level down, with its two words inside its text |
| 4 | *Printed heading:* and a collection's number, heard in VoiceOver on iPhone and Mac at its defaults |
| 5 | VoiceOver, for each of the three lists: a row speaks its name, its value and where the value comes from, and a way back says what it removes. Fit at AX3 and AX5 for the gallery and the rows, on iPhone 17 and iPhone SE. Hit areas of 44 points, by a suite, as `SearchHitAreaTests` holds Search's. On the Mac, every row by keyboard alone |
| 6 | A click on a part moves keyboard focus to that part's row and VoiceOver announces what is selected. Every part reachable without the page. *Show Parts* says its state |

**Order.** 1 and 2 first, in either order. Then 3, 4, 5, 6. Lane 3 is the largest by files touched; lane 5 is the one that answers *very complicated*.

---

## 10. Decisions for the owner

Each with a recommendation. Nothing in §9 starts before the questions in its row are answered.

- **Q1. The interface.** **The gallery first; one list of settings for each thing selected; pointing on the Mac (recommended, §5)**. Or templates only. Or wait for a settings column on iPad before any of it.
- **Q2. The author's title, and its mark.**
  - **The title leads, and the volume's heading follows it as *Printed heading:* (recommended, §3.1).** Or the volume's heading follows with no words, and the Note on the Text alone says which is whose.
  - **The Note on the Text prints by default and the author may remove it (recommended, §3.6).** Or it cannot be removed.
  - **A document printed without its volume's heading is not offered (recommended).** If it is wanted, it owes three things: the source note's call re-homed in the volumes from 1955; each such document listed in a Note that then cannot be removed; and a word on the page, since a bracket would be read as the volume's.
- **Q3. Templates.** **A template chosen in the export sheet is for that export and writes nothing; one chosen for the collection is recorded, and asks first (recommended, §4.3, §4.4).** Or the export sheet stays format and destination, as the Collections rework left it, and templates are chosen in the editor alone.
- **Q4. What leads a document, and what a new collection starts under.** **§4.3's table: the printed heading leads, with the collection's number, in *Full text as printed*, *Full text with your annotations* and *Summaries with overview*, and the citation leads in the other three; a new collection starts under *Full text as printed*; an upgraded collection keeps 1.0's layout (recommended).** Or the citation leads in all six and nothing is numbered, which is 1.0's layout everywhere. And the form of the number (§3.3).
- **Q5. Citation styles.** **A new collection takes the style chosen in Settings ▸ Display (recommended)**, or history.state.gov always. And whether the app's Chicago and Turabian are right as they stand for a line at a document's head and for a bibliography's row (§6).
- **Q6. Storage.** **Two new record types and a one-way upgrade that deletes nothing (recommended, §7)**; or new properties on the existing types (§7.8). And the two types' names, which are permanent.
- **Q7. A date line of the author's.** **Kept, for one document at a time, printed under the title, with the printed dateline untouched (recommended, since it was asked for)**; or dropped, now that the printed dateline stays and a contents row can carry it.
- **Q8. Which of §8's twelve,** and in what order. **Recommended for the first pass: 1 (selected passages) and 4 (Save as Template), the second because its record type should ride §7's deploy.**
- **Q9. The seven defects of §2.8.** **File each as an issue now (recommended)**, so that they are tracked whether or not these lanes are taken; or leave them to lanes 2, 3 and 4.

And one that is not a question of design: **whether lanes 1 and 2 go ahead by themselves**, before the answers to the rest.

---

## 11. The review's findings, and where each is answered

Each is answered in the design's text. None is tested, and §12 says which need a run.

| Finding | Answer | Where |
|---|---|---|
| **G1** A build that does not know a key erases it | A version on each record, and a build writes only what it can write whole; a test | §7.3 |
| **G2** A template chosen at export rewrites the collection | At export it writes nothing; for the collection it asks first and lists each change and each block; nothing is kept aside to be lost | §4.3, §4.4 |
| **G3** A smart collection has no place for any of it | One scope; a document of its list has no settings; the snapshot copies the value whole | §4.5, §7.6 |
| **G4** The scope is a mode | No switch; the selection is the scope; a wider row counts the documents that differ | §4.2 |
| **G5** The control count goes up | Counted the same way, and said: seven more controls at the collection, 14 in view where there were 24 | §5.5 |
| **G6** A title already typed has no rule | It keeps its meaning; it never prints without the volume's words; the upgrade's table | §3.1, §3.4, §7.4 |
| **G7** The ten parts are not blocks | Each part named against the render model; no hidden heading or dateline; the notes one choice of three; one reading of a printed heading and dateline | §3.2, §3.4, §3.5 |
| **G8** A dateline is not the editors' to replace | It stays in the text; the author's date line stands above, for one document | §3.1, §3.2 |
| **G9** Brackets are the volumes' own sign | The mark is words | §3.1 |
| **G10** A collection that only hides prints no Note | It prints whenever it has something to say of a document whose text prints | §3.6 |
| **G11** The export's sources block would be false | A source for the author's lines, and the two sentences reworded | §3.7 |
| **G12** Word's contents list is a field Word rebuilds | Two ways to make the rows the plan's, and a run before either | §3.8, §12 |
| **G13** Pointing works on the Mac alone | It is the Mac's; nothing opens over the page; names on each outline; documents named by entry; the cap | §5.3 |
| **G14** Back matter after the first document | A document arrives ahead of the back matter | §4.3 |
| **G15** The short form names more than one volume | Out of the core until it has a rule over the manifest | §6, §8 |
| **G16** No lane carries an accessibility check | A check for each lane, in the lane | §9 |
| **G17** A device updated later may hold nothing for the new values | No field is added to a type 1.0 knows. The same question for a new type is the first run owed | §7.1, §12 |
| INT-4 Arrangements built and withdrawn before | Named, each with what differs | §5.7 |
| INT-8 Cells of the grid with nothing to store them | One value at every scope; the summary prompt under Text; a row that cannot apply says why | §4.1 |
| INT-10 Words that already mean something else | A table of the words | §4.6 |
| DATA-4 Build 1861 changes what the recorded template describes | 1861 cannot write the new types; an older file's template is found by comparison as it is upgraded | §7.1, §7.4 |
| DATA-8 A carrier, a consequence and a gate left out | The snapshot carries the value; a version-7 importer refuses a version-8 file; one test over every copy | §7.6 |
| DATA-9 "No further deploy" | Withdrawn. A setting added later is no deploy; a record type is, and a saved template is one | §7.2, §8 |
| DATA-10 Export Again with no remembered format | Not offered before a first export on the device | §5.1 |
| ENG-9 Five things the lanes left out | The delete question and the preview's refresh list read the value; the Mac's New Collection form; the pinned source lines; the ranges that cite `Collection.swift` | §7.6, §5.2, §9 |
| EDI-9 *Source:* replaced with no mark | Not in the wording table | §5.2 |
| EDI-10 One formatter for every place | Open, and put to the owner | §6, Q5 |
| A11Y-1 The change shown by a dot alone | Words on the row, spoken, with the row's own way back | §4.1 |
| A11Y-9 The PDF has no tags | Said; the web page and Word are the accessible exports; a candidate | §3.8, §8 |
| A11Y-10 Two pinned buttons at the largest sizes | One | §5.1 |

**What the review found sound, and this form still relies on:** §2's counts; one deploy, with a later key no schema change; no index version; the highlight-offset premise; that a title reaches no citation record; that AI text keeps its label; that a citation style changes no order; that a click can be classified with no change to the exported HTML, since the page already carries `section#doc-…`, `h2.doc-heading` and `section.footnotes-section`.

---

## 12. Checks owed, each needing a device, an app or a desk

| Before | The check |
|---|---|
| **Lane 3** | Two devices on one iCloud account, B kept on 1861. On A, a build with a new record type creates a record of it. (1) Does B, on 1861, go on syncing its own data? (2) Update B: does it show A's record, with A not touching it again? If not, does Fix iCloud Sync bring it? (3) With a 1.0 collection on both, upgrade on A, then on B before B has imported: what does the cleanup keep? |
| **Lane 2, its Word half** | A `.docx` whose contents list is plain linked rows with a page-number field each, and one whose list is a field over marked entries, each opened in Word and in Pages, with fields updated |
| **Lane 2** | Export `frus1961-63v11` d1 under *Full text as printed* in 1.0 and count the source note (defect 2). On the Mac with the preview on, type a title override and wait five seconds (defect 6) |
| **Lane 4** | *Printed heading:* and a numbered lead, read by VoiceOver on iPhone and Mac at its default punctuation. The app's Chicago and Turabian against the two manuals, for a note and for a bibliography's entry |
| **Lane 5** | On iPad Pro 13-inch and iPad mini with a document's settings up, how much of the preview shows beside the sheet |
| **Lane 6** | The Mac's preview keeping its place across a reload, with a long collection |

Two checks the review owed no longer apply: a heading not drawn, opened in Word (no heading is undrawn); and a bracketed heading read by VoiceOver (no bracket is added).

---

## 13. Files

- **This document**, and the review of its first form: `Planning/Collections-Design-Adversarial-Review-2026-11-25.md`, with the eight reports under `Planning/collections-design-review/`.
- **The canvas:** <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>, seven boards. It is private to the owner's account; its source is not in the repository.
- **Read, at `efd73ec`:**
  - the model: `FRUSExplorer/Models/Collection.swift`, `ModelContainer+FRUS.swift`, `CloudKitSchemaInventory.swift`, `DuplicateRecordCleanup.swift`, `ListOrderPreferences.swift`;
  - the kit: `FRUSCoreKit/Collections/CollectionExporter.swift`, `CollectionContentAssembly.swift`, `CollectionItemHTMLRenderer.swift`, `DocxCollectionExporter.swift`, `CollectionGeneratedBlocks.swift`, `NativeCollectionFormat.swift`; `FRUSCoreKit/Citation/CitationFormatter.swift`, `CitationParser.swift`; `FRUSCoreKit/TEI/FRUSRenderNode.swift`, `FRUSRenderNodeHTMLSerializer.swift`, `FRUSDocumentParser.swift`, `ASTToRenderNodeConverter.swift`; `FRUSCoreKit/Search/IndexingPipeline.swift` (the stored heading and dateline); `FRUSCoreKit/Export/ResearchDataEnvelope.swift`, `ResearchImportPlan.swift`; `FRUSCoreKit/TripPacket/ArchiveVisitPlanWrites.swift`;
  - the app: `FRUSExplorer/Collections/` (`CollectionEditorView.swift`, `CollectionEntryInspector.swift`, `CollectionEntryRows.swift`, `CollectionCompositionRows.swift`, `MacCollectionManagerView.swift`, `CollectionListView.swift`, `CollectionExportSheet.swift`, `CollectionPreviewView.swift`, `PDFCollectionExporter.swift`, `CollectionExporter+App.swift`);
  - the manuals' chapter 12, and the three earlier designs under `Completed/`;
  - the public TEI of eight volumes, among them `frus1946v06` and the Editorial Methodology of `frus1977-80v06`.
- **Not read:** `CollectionAddDocumentsSheet.swift`, `CollectionRichTextEditor.swift`, `CollectionPickerSheet.swift` beyond its purpose, and the web edition's repository.
- **Not done:** no build, no test run and no capture. This form was reviewed after it was written (the notice at its head). The counts of §2.4 and §5.5 are of lists, not of a running screen, and §2.3's page arithmetic is an estimate.
