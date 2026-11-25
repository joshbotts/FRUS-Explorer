# Collections: export in two taps, and fine-tune every part of a document — a design, 2026-11-25

**Status: PROPOSED on 2026-11-25; third form, revised after two adversarial reviews and amended the same day on the owner's direction. Nothing is built, and no code changed.** §10 asks the owner for eleven decisions. §9's lanes are written so that the next plan of record can take them as rows. §12 lists the runs that need a device before a lane starts.

**This is the record's third form.**

- The first recommended a parts inspector entered from the preview. `Collections-Design-Adversarial-Review-2026-11-25.md` found 50 findings in it, none refuted.
- The second kept the document as the volume prints it, and added two record types with an upgrade, a number at each document's head, the notes as one choice, a template in the export sheet and a table of words. `Collections-Design-Second-Review-2026-11-25.md` found 59 findings in it, none refuted, most of them in what it added.
- The owner then asked for this revision. **It does less than either.** What changed from the second form:

| | The second form | This form |
|---|---|---|
| **Storage** | two new record types and a one-way upgrade | the two record types 1.0 has, with four optional properties added; no upgrade (§7) |
| **The collection file** | version 3, refused by 1.0 | the same version and the same floor; new settings as optional keys (§7.4) |
| **The notes** | one choice of three | 1.0's two switches, with the source note printed once (§3.5) |
| **Numbers** | the collection's own number at each document's head | none there; the contents rows numbered alike in every format (§3.8) |
| **The mark** | *Printed heading:*, in a table of words the author may change | *In the volume:*, fixed, over the document; a date line only under a title (§3.4) |
| **The Note on the Text** | a block and a switch | a block (§3.6) |
| **A template** | one recipe of settings and blocks, as in 1.0 | two steps: how the documents are presented, then what apparatus is added (§4.3) |
| **A template in the export sheet** | for every format, with the collection's blocks told apart by who placed them | for PDF, Word and Web page, as the same two steps (§4.4) |
| **The settings** | a new list for each thing selected, with no *Default* | 1.0's three surfaces, trimmed, with a *Default* that says what it is (§4.2, §5.2) |

§11 lists every finding of the second review with the section that answers it. The earlier forms are in the repository's history: the first at `aad7636`, the second at `58cc047`. The reviews cite their section numbers, which this form does not keep.

**Amended the same day, on the owner's direction.** After reading this form the owner said:

> "Let's treat templates as a two-step process. The first focuses on how documents are presented. The second focuses on what apparatus complements to the documents are added."

So a template is two choices, made in that order and each alone (§4.3). What moved with it:

- **The export sheet** has two rows where this form first had a list of seven (§4.4, §5.1).
- **The collection's settings** are the two steps, each behind a row that says what is set. *Customize* is gone (§5.2).
- **The question a template asked** before it changed a collection is gone. Each step's change is small, shown where it is made, and undone there (§4.3).
- **For one export the apparatus is its own choice,** so nothing has to tell a template's blocks from the author's (§4.4).

This form as first written is at `f7d40e6`. The amendment has not been reviewed either, and §11 says where a reviewer would start.

**The defects of 1.0 that the two reviews met are filed,** on the owner's word: #1991 to #2007, beside the owner's own #1984 (§2.8).

**What this is.** The owner's words of 2026-11-25:

> "I am not satisfied with the Collections feature. I am not able to customize how each document is displayed, yet the interface is very complicated. I want to be able to export a collection very quickly using sensible default templates (the new ones we created last week are good starting points). I also want to be able to fine-tune any aspect of the collection, including overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately. I want to be able to choose what citation format to use if the contents are listed that way. Consider other authorial capabilities along these lines as well. Consider what kinds of user interface alternatives might help me preserve clean simplicity for default situations and also wield powerful customizability for other times."

That is five asks:

1. a quick export from a template (§4.4, §5.1);
2. every part of a document adjustable, in a simpler interface than today's (§3 to §5);
3. the author's own headings, datelines and labels, marked (§3);
4. a citation style for the collection (§6);
5. other authorial capabilities (§8).

**How far this form goes on each, said plainly.** It meets 1 and 4. On 3 it gives the author a title, a date line and their own words for the app's labels, and it does not give them a page from which the volume's heading or dateline is gone (§3.1; Q2 asks). On 2 it fixes how a document is drawn and trims the three settings surfaces; it does not replace them with a new one (Q1 asks).

**How it was read.** In a cloud session with no Xcode, on 2026-11-25, from `v2` at `efd73ec` (#1988's merge). Nothing was built or run. Every statement about behaviour is read from the code, from both manuals, from the Agentic Analysis Guide or from the public TEI, and carries its file and line at that commit.

- §2 is the first form's reading of the app, with the nineteen corrections the two reviews made to it and to later sections.
- The examples are real: document 475 of `frus1946v06` and its neighbours, from the public TEI (`HistoryAtState/frus`). The counts over volumes are the reviews', made by parsing eight volumes, and recounted by a skeptic with scripts of its own.
- Before the seventeen issues were filed, the session read each defect again at its lines. One was narrower than the review had it, and its issue says so (#1997).
- **Nothing in §3 to §9 of this form has been reviewed.**

**The mockups** are on a design canvas, private to the owner's account: <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>. Its nine boards were redrawn for this form:

- the export sheet on iPhone, with the two steps as two menus;
- the collection's settings behind the Mac's gear, ten controls in view, each step opening in place;
- the two steps drawn open, side by side, with the six of decision 139 divided between them;
- a document's settings on the Mac and on iPhone, and a section's sheet;
- *Show Parts* in the Mac's preview, which is a later lane;
- three openings of document 475 with the mark, and a contents list in three citation styles.

The session wrote the boards and did not see them rendered: this container cannot open the canvas. They draw one example collection, six of Kennan's telegrams from `frus1946v06`, whose headings, datelines and source notes were read from the public TEI.

---

## 1. In brief

**What is wrong today** (§2):

- **Every document is drawn one way, and the three formats disagree about that way.** A document prints the citation as a heading and then the volume's own heading under it. The PDF prints one line of a source note above the text and ends its contents list where its first page ends. Word numbers the volume's footnotes by its own count. With both note switches on, the source note prints twice.
- **The controls are many, and they are sorted by where a value is stored.** Collection settings holds 24. A document's inspector holds nine settings, eight of them a picker with a *Default* choice that does not say what the default is. A section's sheet shows 21 controls, of which six are the section's.
- **A template is a one-way trip, and it is not offered at export.** One tap overwrites eight fields with no undo. Nothing exports a collection from the Collections list.
- **Collections cite in one style.**

**What is proposed:**

- **The document prints as the volume prints it, and the author's words stand above it.** A title and a date line are the author's; the words *In the volume:* then mark where the volume's own begin (§3.1 to §3.4).
- **One plan for three formats.** The kit resolves each document's lines once, and the web page, the PDF and Word draw that plan. That is where most of the filed defects end (§3.8).
- **A template is two steps:** how the documents are presented, then what apparatus is added around them. The six of decision 139 divide into six document templates, each with an apparatus suggested for it (§4.3).
- **Both steps in the export sheet,** for that export, for the three formats that are renderings. They write nothing to the collection (§4.4).
- **1.0's three settings surfaces, trimmed.** The collection's opens on ten controls where there are 24: the two steps, each a row that says what is set, and the title page. A section's sheet holds the section's six where it shows 21. A picker's *Default* says what it follows and what that is (§5.2, §5.5).
- **Four new facts, stored where collections are stored today:** a citation style, which line leads a document, the collection's own words for the app's labels, and a document's date line. One CloudKit promotion of four fields (§7).
- **The collection file keeps its version.** A 1.0 app opens a file the new version writes (§7.4).

---

## 2. What 1.0 (1861) does, against each ask

### 2.1 "Export a collection very quickly"

- **The export sheet chooses a format and nothing else.** It shows the collection's one-line composition summary, six format cards and the Zotero row (`CollectionExportSheet.swift:220-240`, `:342-371`). It opens on PDF every time (`:60`), whatever the collection last exported as. It writes nothing to a collection (`:19-22`).
- **A template is applied somewhere else.** On an iPhone the path from the Collections list to a PDF under another template is: the collection's row, *Collection settings*, a template chip, Back, scroll to *Actions*, *Export…*, *Export PDF*. On the Mac the templates are in a 420-point popover behind the toolbar's gear (`MacCollectionManagerView.swift:1172-1262`).
- **Nothing exports from a list.** The iOS Collections list's context menu offers Rename, Duplicate, Word Cloud, Create Static Snapshot and Delete (`CollectionListView.swift:350-387`). On the Mac both ways in, the toolbar's *Export…* and the Collection menu's *Export Collection…* (⇧⌘E), open the same sheet (`MacCollectionManagerView.swift:1759`, `:1111`).

### 2.2 "Customize how each document is displayed"

Every document is drawn in one order, whatever the template. From the HTML renderer (`CollectionItemHTMLRenderer.swift:291-413`), which the live preview shows:

1. the citation as an `<h2>`, linked to history.state.gov, or the entry's title override in its place (`:296-309`);
2. the document's address, as a paragraph of its own (`:304-306`);
3. the headnote, when on (`:317-319`);
4. the text, with **the volume's own heading, a second `<h2>`** (`FRUSRenderNodeHTMLSerializer.swift:740-741`), and its dateline. In the volumes before 1955 the text opens with the source note's mark, on a line above that heading. In most documents the dateline is drawn inside an opener's block, beside the classification marking (`:749-750`);
5. the source note under the word *Source:* (`:379-382`);
6. the *See also:* line (`:386-394`);
7. each research note, under *Research Note* (`:397-409`).

What the author can change in that, for one document: the text of line 1 (*Title override*), how much of the text prints, and six switches (highlights, research notes, source note, footnotes, related documents, headnote).

What the author cannot change: which of the two headings leads; anything about a date; the address line; any label (*Contents*, *Summary*, *Source:* and *Research Note* are literals in the renderer, `:560`, `:359`, `:380`, `:400`); the order of the parts.

**Why a title of one's own matters.** Documents 470, 473, 474, 475, 476, 477, 480 and 486 of `frus1946v06` all carry one heading: *The Chargé in the Soviet Union (Kennan) to the Secretary of State*. Under *Header & Dateline* the eight contents rows are identical and carry no date (#1994). Under *Citation* every row is the same citation of some 200 characters, ending in a different number. Document 475 is the telegram a reader knows as the Long Telegram.

**The outline does not show the override.** A document's row reads the indexed header (`CollectionEntryRows.swift:972`), on the Mac too (`MacCollectionManagerView.swift:2022-2028`).

### 2.3 Three formats, three layouts

The preview is the HTML export, and its own caption says so (`CollectionPreviewView.swift:419`). The other two formats differ in more than pagination:

| | HTML and the preview | PDF | Word |
|---|---|---|---|
| The source note | after the text, whole | **above** the headnote and the text, in a rectangle one line high (`PDFCollectionExporter.swift:752-762`, `:1523-1538`) | after the text, whole |
| A research note | under the document | **a page of its own for each**, in one frame, so a long note is cut off (`:852-889`) | under the document |
| The contents list | every row | **the first page only** (`:634`; #1984) | a Word field, with rows cached until Word rebuilds it |
| The contents rows' numbers | the list's own, which also count section headings and blocks (#1993) | each document's, documents alone (`:630-638`) | each document's, in the cached rows (`DocxCollectionExporter.swift:1898-1906`) |
| The contents-list style | honoured | honoured (`:638`) | **never read** (`:1905`) |
| A footnote's number | the volume's printed label | the volume's printed label | **Word's own count** (#2001) |
| The volume's heading | a second `<h2>` | 13 points bold, the citation heading's own size (`:1063`, `:688`) | Heading 3 under Heading 2 |
| *Summary* over a summary | printed | not printed | printed |
| Between documents | no break | a new page | no break |
| Page numbers | none | every page | none |

### 2.4 "Yet the interface is very complicated"

Counted from the code, field by field. Both reviews recounted these and they held.

| Surface | Controls | Of which |
|---|---|---|
| **Collection settings** (iPhone screen, iPad sheet; `CollectionEditorView.swift:806-830`, `:880-913`) | 24 | 8 name and title page (three of them switches for the colophon, the project stamp and the query log), 6 templates, 9 composition (one of them conditional), 1 smart-collection link |
| **A document's inspector** (`CollectionEntryInspector.swift:348-366`) | 9 settings, and more | Title override; *Body depth* and *Summary prompt*, each with a *Default* choice; six *Default / On / Off* pickers. Then a switch per research note, a switch per highlight, and the headnote card's Edit and Generate |
| **Section Defaults** (a heading's sheet; `CollectionEntryRows.swift:192-195`) | 21 | **15 are the whole collection's** and 6 are the section's. The section's text depth is a menu on its row, and its title a field there |
| **The export sheet** | 7 | six format cards and the Zotero row; the collection file adds a switch for research notes |

What makes the count hard to carry:

- **The same setting is in more than one place under more than one name.** The Section Defaults sheet is the inspector opened with one default that shows the collection's own settings (`showsCollectionSettings = true`, `CollectionEntryInspector.swift:159`). So a heading's sheet opens on the collection's *Description*, *Subtitle*, *Author line* and *Append colophon page on export*, which Collection settings calls *Note*, *Subtitle (title page)*, the author field and *Include colophon* (`CollectionCompositionRows.swift:388-427`; `CollectionEditorView.swift:1044-1075`).
- **Eight pickers ask the author to think in inheritance.** Each offers *Default*, and under it a caption, *Default → On*, which does not say whether the section or the collection decided (`CollectionEntryInspector.swift:631-650`).
- **The Mac has four places of its own:** the gear's popover for the collection; a trailing column for a document; the New Collection form that Add to Collection opens, which carries the whole composition section (`CollectionEditorView.swift:481-510`); and the preview, which the Collection menu's *Show Preview* (⌥⌘P) turns on and off.

### 2.5 The templates

- **One tap, at once, with no undo** (`CollectionCompositionRows.swift:284-286`; `CollectionEditorView.swift:1935-1943`). It overwrites eight fields (`CollectionExporter+App.swift:29-39`).
- **Apparatus only accumulates.** A template adds the blocks it calls for and removes none.
- **"In force" is a comparison.** A card is marked when the collection's eight fields equal its recipe (`matches`, `CollectionExporter+App.swift:46-56`). Nothing is stored about which template was applied (`CollectionExporter.swift:50-51`).
- **A new collection follows none of the six.** The model's defaults are the full text with footnotes and research notes, and no source note (`Collection.swift:132`, `:143`, `:218`).
- **A template cannot say how a document is laid out**, since no setting does (§2.2).
- **Its recipe is one thing, of two kinds.** Six of its eight settings are about each document. The other two, the contents-list style and the word cloud, and its blocks are about what is added around the documents. The settings screen already sorts its nine controls so, under *Document content*, *Your annotations* and *Analysis & apparatus* (`CollectionCompositionRows.swift:156`, `:180`, `:201`).

### 2.6 The preview

- **It forgets the author's place.** Each edit regenerates the page a second later and loads it whole (`CollectionPreviewView.swift:882-887`).
- **It is not joined to the outline.** Choosing a row does not bring its document into view, and tapping a document in the preview does nothing.
- **It shows the first 20 documents** until *Render All* (`:153`), and one format.
- **It builds its export options by hand** (`:519-531`), apart from the options the export sheet takes. It draws neither the project stamp nor the query log.

### 2.7 Citations, and the exports that are not renderings

- **The assembly names its formatter.** `BatchContext.formatter` is typed `HistoryAtStateCitationFormatter` (`CollectionContentAssembly.swift:797`, `:917`). The document heading, a *Citation* contents row, an excerpt's source line, the *See also* line and the Bibliography's rows all come from it.
- **The app has three styles and a preference** (`CitationFormatter.swift:30-43`). It is mirrored to the reader's other devices only while a device's own sync switch is on, which is off by default (`SettingsSyncCoordinator.swift:12-14`). A collection does not read it.
- **The exporters read one kind of italics**, `_…_`, where Chicago and Turabian write `*…*` (`CollectionItemHTMLRenderer.swift:1222`).
- **Four of the sheet's seven exports are not renderings:** BibTeX, RIS, the Zotero send and the collection file.
  - BibTeX and RIS read one of the collection's settings, whether research notes are on (`BibTeXCollectionExporter.swift:63`, `ZoteroCollectionExporter.swift:65-69`).
  - The Zotero send reads none (`CollectionExportSheet.swift:734-735`).
  - None of the three reads a section's or a document's (#2000).
  - The file is the collection's source and reads none.

### 2.8 Defects of 1.0, filed as seventeen issues

The two reviews met rows 1 to 17 on the way. Each was confirmed by a skeptic's re-read of the code, row 17 excepted, and read again by the session before it was filed. **None was seen in a running app.** Row 18 is the owner's own report of the day before.

| | The defect | Issue |
|---|---|---|
| 1 | A *Header & Dateline* contents list prints no dateline for most documents: the collection reads one only where it is a top-level block | #1994 |
| 2 | With Footnotes and Source note both on, the source note prints twice, in every era | #1991 |
| 3 | An entry added to a collection lands after its back-matter blocks | #1995 |
| 4 | A numbered footnote call is written "[n]" into the heading the collection reads, so contents rows and citation records' titles end in "[1]" | #1992 |
| 5 | Duplicate does not copy the project stamp or the query log; the snapshot copies fields by name and none of a smart collection's blocks | #1996 |
| 6 | The preview does not refresh on a title override or the Headnotes default | #1997 |
| 7 | A title override prints with nothing of the volume's beside it at Summary or Index depth and in every contents row | #1998 |
| 8 | The collection file carries a headnote as its draft's id, so a file opened on its author's account shares the original's drafts | #1999 |
| 9 | BibTeX, RIS, the Zotero send and a shared file's note texts ignore a section's or a document's research-notes setting | #2000 |
| 10 | The three formats number contents rows differently | #1993 |
| 11 | Word numbers the volume's footnotes by its own count | #2001 |
| 12 | The heading the collection reads carries the volume's own number, so a row reads "4.  1. Letter From…" and a citation record's title "Document 1: 1. Letter From…" | #2002 |
| 13 | An editorial note has no heading in a collection: its heading is inside a wrapper the collection does not look into | #2003 |
| 14 | A document entered twice has duplicate element ids in the web page | #2004 |
| 15 | An Apple Intelligence headnote adds no source to the export's statement of sources | #2005 |
| 16 | Four accessibility defects: the list's row actions, the per-note switches' names, the section pill's height, the template cards' fixed type | #2006 |
| 17 | With footnotes left out of a web page, each footnote call is still a button whose popover was not written | #2007 |
| 18 | The PDF's contents list stops at the end of its first page | #1984, the owner's, of 2026-11-24 |

---

## 3. The document on the page

### 3.1 Nothing the volume prints is replaced

This stands from the second form, and both reviews left it standing.

- **A dateline is the document's text.** Document 475's reads *Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]*, in the telegram's own opener, beside the classification marking. A date line typed in its place takes the hour of dispatch and the time of receipt off the page.
- **A heading carries more than its words.** From 1955 the source note is a footnote on the heading: in 361 of 390 documents of `frus1961-63v11`. A heading that is not drawn leaves a note that nothing calls.
- **Brackets already mean something.** The first line of document 475 reads *Answer to Dept's 284, Feb 3 [13]*, and the bracketed *13* is the editors' correction.

So: **a document prints as the volume prints it, whole or not at all, and the author's words are added above it.** The author's title leads; it takes the heading's size and the contents row. The volume's own heading and dateline follow, untouched.

**What the author does not get** is a page from which the volume's heading or dateline is gone. Q2 asks whether that is wanted, and says what it would owe.

**1.0's titles keep their meaning.** A title override prints above the volume's heading today (§2.2). It still does.

### 3.2 What a document is made of

Each part is named against the render model (`FRUSDocumentRenderModel`, `FRUSRenderNode.swift:510-528`).

| Part | What it is in the model | The choices |
|---|---|---|
| ***The author's lines*** | | |
| **Title** | the entry's `titleOverride`, as now | given or not, for one document |
| **Date line** | a new field of the entry's (Q7) | given or not, for a document that has a title |
| **Headnote** | the entry's headnote draft, with its line of attribution | on or off |
| ***The citation*** | made from the volume and the document's number, in the collection's style (§6), with its link | leads the document, or is a small line above it (§3.3) |
| ***The document, as the volume prints it*** | | |
| **The volume's heading** | the document's one heading node (`.heading`, `:62`), with its footnote calls | prints wherever the text prints. Where the text does not, its words are a line of their own (§3.4) |
| **Text** | every other body node, in order: the opener with its marking and dateline, the paragraphs, the closer | Full · Summary only · Index / outline, as now |
| **Footnotes** | the footnote bodies | on or off, as now |
| **Source note** | one of those bodies (`type: .source`, `:84`), and the copy the index stores | on or off, as now; printed once (§3.5) |
| ***The author's research*** | | |
| **Highlights**, **Research notes**, **See also** | as now | on or off, and which, as now |

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

**The volume's heading leads**, with the citation as a small line above it:

```
Foreign Relations of the United States, 1946, … Document 475.     ← small

The Chargé in the Soviet Union (Kennan) to the Secretary of State   ← heading size
SECRET              Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]
511. Answer to Dept's 284, Feb 3 [13] involves questions so intricate …
```

**A title of the author's**, which leads wherever one is given:

```
The Long Telegram                                                 ← heading size
Moscow, 22 February 1946                                          ← the author's date line
Foreign Relations of the United States, 1946, … Document 475.     ← small

In the volume: The Chargé in the Soviet Union (Kennan) to the Secretary of State
SECRET              Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]
511. Answer to Dept's 284, Feb 3 [13] involves questions so intricate …
```

- **No number stands at a document's head.** The second form put the collection's own there. From the volumes for 1952–1954 on, the volume's number already opens the heading ("1. Letter From…"), and the indexes and the volumes' notes cite by it, so a second number beside it misdirects (#2002; the second review's H14).
- **Which line leads is one setting of the collection's,** *Opening*, with two values. A title leads under either.
- **The words *In the volume:* are no part of the document's text.** Each exporter adds them outside the walk that counts highlight offsets, as *Source:* is added today. The second review tested that claim and it held.

### 3.4 The author's lines are marked by where the volume's begin

**One fixed label.** *In the volume:* prints before the volume's heading whenever a title of the author's stands above the document. Everything above it is the author's or the citation; everything from it down is the volume's.

- **It is not the author's to change.** It is not in the table of §5.2, and it cannot be emptied. The second form's *Printed heading* was in that table.
- **It is true of every volume.** 22 of the manifest's 553 are electronic-only, of which "printed" is untrue.
- **A date line is given only under a title,** so it always stands above the label. The second form let one be typed alone, with no rule for where it printed.
- **It is words,** so it is read aloud, and it collides with nothing the volumes print.

**A title never prints without the volume's own words beside it** (#1998):

- **At the document's head, at every depth of text:** the title, the citation, and the volume's heading after the label. Where the text does not print, the heading's words are a line read from the reading below.
- **In a contents row:** the title, and the author's date line where there is one. Under it, a second line in small type: in *Header & Dateline* style, *In the volume:* and the volume's heading and dateline; in *Citation* style, the citation.
- **In the outline:** the title, with the volume's heading as the row's second line.

**One reading of a heading and a dateline,** in the kit, which every one of those places calls. It returns, apart from each other:

- the heading's words;
- the number the volume prints before them, from the 1952–1954 volumes on (#2002);
- the heading's footnote calls (#1992);
- the dateline's words, from the top level, the opener or the closer, and its calls (#1994);
- for an editorial note, the heading inside its wrapper (#2003).

Where the volume is on the device it reads the model. Where it is not, it reads the index, which holds less: no dateline that sits only in a closer, and a note inside a dateline run into its text (`IndexingPipeline.swift:7347-7358`). The outline reads the index always, as it does today.

**The citation records.** A BibTeX, RIS or Zotero item is built from the volume's heading and never from the author's title; that stays. Whether its title takes the new reading, and so loses "[1]" and the doubled number, is Q9.

### 3.5 The notes stay two switches, and the source note prints once

The second form made Footnotes and Source note one choice of three. The second review showed that one key cannot hold a section or a document that sets one of 1.0's two switches and inherits the other (its H12). So the switches stay as they are stored, and the plan decides what prints:

| Where the volume has the source note | Both on | Footnotes on, Source note off | Footnotes off, Source note on | Both off |
|---|---|---|---|---|
| **A footnote on the heading** (from 1955) | among the footnotes, once | among the footnotes, as now | *Source:* after the text, as now | not printed; its call stays at the heading |
| **A line above the heading, unnumbered** (before 1955) | *Source:* after the text, once; the unlabelled copy among the footnotes is left out | among the footnotes, as now | *Source:* after the text, as now | not printed |

- **That ends #1991.** Which copy stays differs by era for a reason: from 1955 the heading's call must keep its note, and before 1955 the footnote copy carries no label, where the *Source:* line does.
- **The app's glyph on the line above the heading,** before 1955, prints only where its note is in the footnote list. Today it stays when the note does not.
- **Where the text is not printed,** Source note on prints the *Source:* line, whatever Footnotes says, as now.
- **A call whose note is not printed is text, not a button** (#2007). The calls stay: they are in the volume's text, and they tell a reader that a note exists.
- **Word prints the volume's numbers** (#2001): the plan carries each note's printed label.

### 3.6 The Note on the Text

A block the collection generates, as it generates a Bibliography. It is the collection's statement of method, written from the plan that prints:

- that titles, and date lines under them, are the compiler's, and that each stands above the words *In the volume*;
- what is left out: footnotes, with their numbers remaining in the text; source notes; the text itself where a document is a citation or a summary. Each is said for the whole collection, or with the documents named;
- that summaries were written by Apple Intelligence, and which headnotes the compiler wrote;
- that quoted passages are excerpts, and how they were checked;
- which of the app's labels the compiler renamed (§5.2).

**It is a block and nothing else.** It is a row in the outline, placed, moved and removed as a Bibliography is. It prints where its row is, and only if it has something to say. There is no switch for it.

- **It is one of the apparatus of step 2** (§4.3), and each suggested set has it, last. A collection that exists today has none until its author adds one.
- **Where it would have something to say and the collection has none,** the collection's settings say so in a line, with *Add*.
- **In 1.0 it is inert.** It is a new block type, and 1.0 keeps a block type it does not know in its place and skips it (`CollectionContentAssembly.swift:964-965`).

Its sentences are written from the volumes actually in the collection, since the series' conventions differ by era: the volumes before 1952 print no document numbers, and the statement that the editors supplied each heading is in the prefaces from 1961–63 on, of the eight volumes read. The wording is the owner's, as every string in `Docs/EditableContent/` is.

### 3.7 The export's own statement of sources

With the colophon on, an export says where its content came from. Two sentences of that statement are shared with the analytics exports, the Archives Visit packet and the method appendix (`ProvenanceStatement.swift:51-59`), and are left alone.

- **A collection gets a sentence of its own** for the author's lines: that titles, date lines and headnotes the compiler wrote stand apart from the volumes' text and are named.
- **A generated headnote adds the app's model as a source** (#2005). Today only a summary body does.

### 3.8 One plan for three formats

Today each exporter decides for itself what a document's parts are, in what order, under what words. §2.3 is the result.

- **FRUSCoreKit resolves each document into a plan:** the lines that will print, in order, each with its text, its role, its heading level and its label. The assembly builds it where it already resolves the cascade (`resolveEntry`, `CollectionContentAssembly.swift:944-1165`).
- **The web page, the PDF and Word draw the plan in order.** None decides a part's presence, place or wording. A format keeps its own typography and pagination.
- **What ends as a consequence:** the source note follows the text in the PDF and prints whole; a research note flows under its document; the contents list runs past the first page (#1984); the rows are numbered alike, documents only (#1993); the contents-list style holds in Word.
- **The highlight walk is untouched.** Every node of the document is drawn, so each exporter's counter walks what it walks today.

**Word's contents list needs a decision of its own.** It is a field that Word rebuilds on first open from the heading styles (`DocxCollectionExporter.swift:1865`, `:1873-1874`), after which no label of the plan's survives. Two ways to make the rows the plan's: plain rows, each linked to its document, with a page-number field at its end (recommended); or a field built from entries the app marks. Which of the two Word and Pages show correctly is not known here, and §12 owes that run.

**The export's own accessibility,** for all three openings:

- The line that leads a document is its heading. Under a title the volume's heading is one level down, with *In the volume:* inside its text.
- Where the volume's heading leads, the citation is a line before it. The plan names each document's region by its heading, so that a reader moving by headings is told which document the line belongs to.
- The web page's *Footnotes* heading over each document's notes is one level below the document's, and is carried in the plan.
- The PDF has no tags, title or links, and this design adds none. The web page and the Word file are the accessible exports; a tagged PDF is a candidate (§8).

---

## 4. Settings

### 4.1 What is stored today is kept

The second form put one value at every scope. This form keeps 1.0's fields and says which exist where, with nothing invented for a cell that is empty.

| Setting | The collection | A section | A document |
|---|---|---|---|
| Text depth | yes | yes | yes |
| Summary prompt | yes | yes | yes |
| Footnotes; Source note | yes | yes | yes |
| Highlights; Research notes | yes | yes | yes, and which |
| Headnote | yes | **no** | yes, with its card |
| See also | **no** | yes | yes |
| Contents-list style; word cloud; colophon; project stamp; query log | yes | | |
| **Opening** (new) | yes | | |
| **Citation style** (new) | yes | | |
| **The collection's words** (new) | yes | | |
| Title | | | yes, as now |
| **Date line** (new) | | | yes |

- **A value comes from the nearest scope that sets it:** the document; else the section that encloses it, and each section outside that one, since sections nest three deep (`CollectionOutline.swift:275-282`); else the collection. That is 1.0's cascade.
- **The two empty cells stay empty.** A section's headnote default and the collection's See also are candidates (§8), each a field and a deploy of its own.

### 4.2 A *Default* that says what it is

1.0's pickers offer *Default*, *On* and *Off*. The second form took *Default* away and gave each row a way back. The second review showed what that leaves undefined: a setting held at the value it would inherit anyway, and a second control on every row that no board drew.

- **The three states stay, in one control.** The first choice is renamed for what it does: *Follow the section: On*, or *Follow the collection: Off*. It names the scope that decides and the value in force there.
- **Where nothing above sets a value, the first choice says so:** *Not set above: Off*. That is See also outside a section that sets it, since the collection has no setting for it (§4.1).
- **A document set to *On* under a collection that is on reads *On*.** It is set on purpose and does not follow a later change, which is what it does in 1.0. Nothing calls it "changed".
- **At the collection, a row says how many set their own:** *Footnotes: On · 2 set their own*. The count opens the list of them, with each one's value, and *Clear* returns the ones chosen to following. That is the way back for many documents at once.

### 4.3 A template is two steps

The owner's direction of 2026-11-25. In 1.0 a template is one recipe: eight settings and a list of blocks (`CollectionPreset.Recipe`, `CollectionExporter.swift:201-250`). It becomes two, chosen in order and each alone.

**Step 1, Documents: how each document is presented.** A document template sets seven of the collection's settings and nothing else:

- *Opening*, which is new (§3.3);
- *Body depth*, *Footnotes* and *Archival source note*, which 1.0 groups as *Document content*;
- *Research notes*, *Highlights in body* and *Headnotes*, which it groups as *Your annotations*.

**Step 2, Apparatus: what is added around the documents.** Eight complements:

- the *Contents list*, which always prints and has two styles (`CollectionToCStyle`, `CollectionExporter.swift:19-23`), and the *Word-cloud overview*: 1.0's *Analysis & apparatus*;
- the five blocks, which are Chronology, Bibliography, Sources & Archives, Persons Index and Thematic Index;
- the Note on the Text (§3.6).

1.0 already sorts its controls under those three heads (§2.5), so the split follows a line the app has drawn.

**The six of decision 139, divided.** Each is a document template, and what it added becomes the apparatus *suggested* for it:

| Decision 139's template | Step 1: its documents | Opening (a proposal, Q4) | Step 2: the apparatus suggested for it |
|---|---|---|---|
| Full text as printed | the full text; footnotes and source notes | the volume's heading leads | contents by citation; Bibliography; Sources & Archives |
| Full text with your annotations | the full text; source notes; headnotes, highlights and research notes | the volume's heading leads | contents by heading and dateline; Chronology; Persons Index |
| Summaries with overview | a summary of each; research notes | the volume's heading leads | contents by heading and dateline; word cloud; Chronology; Thematic Index |
| Citations with your notes | the citation alone; research notes | the citation leads | contents by citation; Bibliography; Thematic Index |
| Citations with archival sources | the citation alone; source notes | the citation leads | contents by citation; Sources & Archives; Persons Index |
| Everything included | the full text; every option | the citation leads | contents by citation; word cloud; all five blocks |

Each suggested set also has the Note on the Text. Three of the six names describe apparatus that step 1 no longer adds, and Q11 proposes others for them.

**What each step does when it is chosen for the collection** (§5.2 says where):

- **Step 1 changes the seven settings, in view.** The seven controls are under the template cards and change as a card is chosen. A line says what changed, old to new, with *Undo* while the screen is open. 1.0's one tap overwrites eight fields at once, says nothing of what changed, and has no way back.
- **Step 2 is a list of the eight.** The contents list has its style and the word cloud its switch, both as 1.0 stores them. Each of the six blocks has a tick, and a tick is not a setting: it says the outline has that block's row, and nothing more is stored.
  - Ticking adds the row at its usual place: a Chronology first, the others at the end (`CollectionGeneratedBlockType.swift:87-93`), the Note last.
  - Unticking removes the row. A block's row stores its type and its place (`CollectionEditorView.swift:1907-1910`), so its place is all that is lost.
  - The outline's *Apparatus* menu still adds a block, and a row is still moved and removed as now.
- **Three shortcuts in step 2:** *Suggested for…*, which lists the six sets of the table by their template's name, with the one for this collection's documents first; *All*; and *None*. 1.0's templates add blocks and remove none. A shortcut does both, in view, with *Undo*.
- **Choosing in step 1 does not change step 2.** After a document template is chosen, step 2's row offers its suggested set in one tap: *Suggested for Full text as printed: Bibliography, Sources & Archives. Add.*
- **Neither step touches** what a section or a document sets for itself, a title or a date line, the summary prompt, the citation style, the wording or the title page. Each row of step 1 says how many set their own (§4.2).

**What is and is not stored:**

- **"In force" stays a comparison,** as in 1.0, and is step 1's alone: seven settings against six recipes. Nothing is stored about which template was chosen, so no other build or file can leave that record stale. Where no recipe equals the collection's settings, step 1's row names the nearest and counts the differences: *Like Full text as printed · 2 differ*. Step 2 needs no comparison: its row lists what the collection has.
- **1.0 goes on comparing its own eight fields** (`CollectionExporter+App.swift:46-56`), two of which are now step 2's. A collection set here can show no template *Active* there, or a different one. That is a mark on a card, and nothing prints by it.
- **A block can be in a collection twice,** since the outline's menu adds one each time it is chosen (`CollectionEditorView.swift:1350-1356`). A tick then stands for both rows, and unticking removes both.
- **Nothing records what placed a block.** The second form did, and could say nothing true of a block placed before it existed.
- **An entry added to a collection goes ahead of the blocks at its end** (#1995): a document, a passage, a heading or a note block alike.

A collection that exists today has no Opening set, which reads as *The citation leads*: it prints as it does. Under the table above it would then stand one setting away from a document template it equals today.

### 4.4 The two steps for one export

The export sheet offers both steps for the export in hand (§5.1).

- **For PDF, Word and Web page.** BibTeX, RIS, the Zotero send and the collection file are not renderings, and the sheet shows neither step for them.
- **Neither writes anything to the collection.** The kit resolves a copy of the collection's values (`CollectionContentAssembly` already resolves from values), which can be computed on what 1.0 stores.
- **Documents:** *As this collection is set*, chosen when the sheet opens, or one of the six. A template replaces step 1's seven settings in the copy.
- **Apparatus:** *As this collection has it*, chosen when the sheet opens; *Suggested for* the template chosen above, where one is; *All*; or *None*.
  - *As this collection has it* is its contents-list style, its word cloud and its blocks' rows, where they are.
  - A set prints exactly its blocks. One the collection has prints where the collection put it. One it lacks prints at its usual place. A block outside the set is left out.
  - A suggested set brings its own contents-list style and word cloud. *All* and *None* keep the collection's style.
  - *None* leaves out the word cloud and every block, the Note on the Text among them. The contents list still prints, as it always does.
- **A choice of documents does not move the apparatus.** It stays the collection's own until it is changed (Q3 asks). The second review's tenth finding was that a template chosen for one export could not tell its own blocks from the author's. Here nothing has to.
- **What stays the collection's under any choice:** its documents, sections, note blocks and passages; each title and date line; what a section or a document sets for itself; the citation style, the words, the title page, the colophon, the stamp and the query log.
- **A choice says what it needs before the export.**
  - The summaries need Apple Intelligence and a summary prompt. A template holds no prompt, so the collection's own is used, and where it has none the item says so and cannot be chosen. It writes a summary for each document that has none, and keeps them, as any summary export does.
  - The two document templates with headnotes on print a headnote only where one is stored. The sheet's sentence counts them: *Headnotes for 4 of 6 documents*. No placeholder line is printed in an exported file.
  - *None*, where the Note on the Text would have something to say, says so: *No Note on the Text: one title of yours goes unexplained.*
- **The sheet's sentence says what will print,** from the resolved copy: how much text, which notes, which apparatus, and how many sections and documents set something of their own.

The source note printed twice (#1991) has to be ended first, or the first document template listed prints it.

### 4.5 A smart collection

A collection linked to a saved search prints that search's documents, and the preview shows them. Neither editor lists them: its outline holds one sentence and its apparatus rows (`CollectionOutline+App.swift:214-224`).

- **It has the collection's settings and no others,** as today.
- **The sentence in its outline gains *Create Static Snapshot*,** which is the way to a collection whose documents can be set one by one. Today the snapshot is offered only in the two lists.
- **The snapshot carries every setting and the smart collection's own blocks** (#1996).

### 4.6 Words

| Elsewhere it was | This form says | Why |
|---|---|---|
| *Look* (the second form's sheet); *Template for this export* (this form, as first written) | **Documents**, then **Apparatus** | the two steps; *Apparatus* is the editor's own word for its blocks' menu |
| *Printed heading* | **In the volume:** | true of every volume, and fixed |
| *The volume's notes*, one choice of three | **Footnotes**; **Archival source note** | 1.0's labels, which need no relearning |
| *Text depth*, *Source note*, *Highlights*: this record's short forms | **Body depth**, **Archival source note**, **Highlights in body** | 1.0's labels, which the controls keep |
| *Your notes* | **Research notes** | 1.0's name; a *note block* and the *Note on the Text* are different things |
| *Not printed* (the first form) | **Left out** | the volumes' own footnotes say *Not printed.* |
| *Back matter*, for switches that print at the front | no such group | the project stamp is on the title page and the word cloud opens the collection |
| *Default* | **Follow the section: On** | §4.2 |

---

## 5. The interface

### 5.1 Export

The sheet 1.0 has, with two rows added and its order kept: what will print, then the format, as now.

- **What will print**, in a sentence, first, as now.
- **Format.** The six cards and the Zotero row, as now. It opens on the format this collection last exported as on this device.
- **Two rows, shown for PDF, Word and Web page,** each a menu (§4.4):
  - *1 · Documents*, which opens on *As this collection is set* and lists the six;
  - *2 · Apparatus*, which opens on *As this collection has it* and lists *Suggested for…*, *All* and *None*.
- **A line under them:** *Chosen here, these are for this export. The collection keeps its own.*
- **Export**, the one button pinned under the list.

Where it opens from: the editor's *Export…*, as now; **the Collections list**, in a collection's context menu on iOS and in the Mac's Manage Collections sheet, each with a VoiceOver action (#2006); and the Mac's Collection menu (⇧⌘E, as now).

- **The four exports that are not renderings** show neither row, and say why. Which research notes they carry is #2000: today BibTeX and RIS follow the collection's switch alone, the Zotero send follows none, and the file's own switch carries every note.
- **There is no Export Again.** The sheet opens on the last format and on the collection as it is set, so *Export…* then *Export* is that export.

This puts a choice about content back in the export sheet, which `Collections-Rework-Scope.md` took out. What differs: the six switches it removed do not return; the choices are two, each of a named thing, for three formats; the collection's own is what each opens on; and the sheet still writes nothing. Q3 asks.

### 5.2 The three surfaces, trimmed

**The collection's settings** (the gear, on every platform, as now):

- **In view when it opens,** ten controls:
  - *1 · Documents*, a row that says what is set: *Like Full text as printed · 2 differ*;
  - *2 · Apparatus*, a row that lists what is added: *Contents by citation · Bibliography · Sources & Archives · Note on the Text*;
  - the title page's five fields (name, description, subtitle, author line, introduction);
  - *Citation style*; *Wording*, a row; and the linked saved search.
- **Step 1, Documents,** behind its row: the six document templates, and under them the seven settings they set and the summary prompt. That is 1.0's *Document content* and *Your annotations*, with *Opening*.
- **Step 2, Apparatus,** behind its row: the three shortcuts and the eight complements (§4.3). Under them are the three that print on export and that no shortcut sets: the colophon, the project stamp and the query log.
- **There is no *Customize*.** Each step holds its templates and, under them, its own controls. An author who wants only a template reads no further than the cards.
- **The steps are numbered, and step 1 ends with *Next: Apparatus*.** Either can be opened by itself at any time.
- **Where a step opens:** in place in the Mac's popover; as a screen pushed in the settings' own stack on iPhone and iPad.

**A section's sheet** holds the section's six pickers and nothing of the collection's. Its title and its text depth stay on its row.

**A document's inspector** is 1.0's: the title; the date line under it, once there is a title; text depth and the summary prompt; six pickers; then which notes, which highlights and the headnote's card.

**The same setting has one name everywhere.** Today the collection's description is *Note* in one place and *Description* in another, and three more differ likewise (§2.4).

**The collection's words.** A table of the labels the app prints over the author's own material and over the apparatus, each with a field: *Contents*, *Headnote*, *Summary*, *Research Note*, *See also*, and the five apparatus titles. A course reader's *Research Note* becomes *Commentary*, and a Bibliography *Works Cited*.

- **Not in the table:** *In the volume:*, which is the mark; *Source:*, which the volumes print themselves from the 1955–57 volumes at least; and *Footnotes*, which heads the volume's notes.
- **A field cannot be emptied,** and the Note on the Text lists the labels that were renamed.

**The Mac's New Collection form,** which Add to Collection opens, becomes a name and the two steps, each a menu.

### 5.3 The preview

**Four repairs, on every platform,** in a lane of their own:

- it keeps the author's place when the page reloads;
- choosing a row brings its document into view, and renders it if it is past the first 20;
- each document on the page is named by its entry, so that a document entered twice is two places (#2004);
- it refreshes on every setting its page draws (#1997).

**Pointing is the Mac's, and later.** There the settings are a column beside the page.

- ***Show Parts*** is a switch on the preview and in the View menu. On, each part of a document is outlined, with its name on the outline's own corner.
- **A click on a part selects that document's row and brings that part's control into view in the column.** Keyboard focus stays where the click was, and VoiceOver is told what is selected. The second form moved focus to the control, which for a text field could put the next keystroke into a title.
- **Every part is reachable without the page.**

On iPad a document's settings are a sheet over both columns (`CollectionEditorView.swift:863-873`), and on iPhone the outline and the preview are never on screen together (`:738-745`), so a tap on the page cannot be answered beside it on either.

### 5.4 On each platform

| | Mac | iPad | iPhone |
|---|---|---|---|
| **Layout** | Outline · preview · settings column, as now, with a toolbar control for the preview | Outline · preview, with settings as sheets, as now | Outline, with Preview behind the segmented control, as now |
| **The collection** | The gear's popover, as now | The gear's sheet, as now | The *Collection settings* row, as now |
| **A section** | Its heading's row | The heading's pill | The heading's pill |
| **A document** | Its row | Its row or its Configure pill | Its row |
| **The two steps** | Each opens in place in the gear's popover | Each a screen pushed in the gear's sheet | Each a screen pushed from *Collection settings* |
| **Document templates** | A grid, three rows of two | The same grid | Rows, each with its line of description |
| **Export** | The sheet; the Collection menu; Manage Collections | The sheet; the list's context menu | The sheet; the list's context menu |

### 5.5 The count

Counted field by field, the way §2.4 counts today's.

| Surface | Today | This design | |
|---|---|---|---|
| **The collection's settings, when they open** | 24 | **10** | The two steps' rows, the title page's five fields, the citation style, *Wording* and the saved search |
| **Step 1, Documents** | in the 24 | **14** | Six templates; seven of 1.0's nine composition controls; *Opening* |
| **Step 2, Apparatus** | 5 in the 24, and 5 more in the outline's menu | **14** | Three shortcuts; 1.0's other two composition controls; six ticks for the blocks; the three export switches |
| **Wording** | none | **10** | The ten labels |
| **A section's sheet** | 21 | **6** | The collection's 15 leave it |
| **A document's inspector** | 9 | **10** | The date line |
| **The export sheet** | 7 | **9** for PDF, Word and Web page; 7 for the others | Two rows, each a menu of up to seven |

Uncounted in both columns: a switch for each note and each highlight, the headnote's card, the file's switch for research notes, and, new, the list a row's *2 set their own* opens.

**The design does not reduce the number of settings.** The collection's are 48 over four screens where they are 24 on one. The 24 more:

- **twelve are new facts:** *Opening*, the citation style, and the ten labels the owner asked for;
- **six are the blocks' ticks,** which stand for rows that the outline's *Apparatus* menu adds today and that §2.4 does not count;
- **three are step 2's shortcuts;**
- **three are rows that lead somewhere:** to each step and to *Wording*.

No screen holds more than 14. What it reduces:

- **what is in view** when the collection's settings open, from 24 to 10;
- **a section's sheet,** from 21 to the 6 that are the section's;
- **what a picker leaves unsaid:** *Default* names what it follows and what that is;
- **what a first export needs,** which is no setting at all, from the list as well as from the editor.

### 5.6 What the earlier forms proposed, and why it is gone

| Proposed | In | Why it is gone |
|---|---|---|
| A heading or dateline of the author's in the volume's place, in brackets | the first | The volumes use brackets for their own editors' additions; a dateline is the document's text |
| One inspector with a switch for the scope | the first | The switch was a mode |
| Popovers on the page | the first | The page is discarded and reloaded under them, and is not in view on iPad or iPhone |
| The collection as the first row of its own outline | the second | On the Mac its settings then replaced the selected document's in the one column |
| Rows with no *Default* and a way back | the second | A value held at what it would inherit had no rule; the way back was a second control nobody drew |
| The notes as one choice of three | the second | It cannot hold half of 1.0's pair |
| The collection's number at each document's head | the second | The volumes' own numbers are already there |
| Two record types and an upgrade | the second | Two devices could each delete the other's copy (§7.5) |
| Version 3 of the collection file | the second | Nothing required it (§7.4) |
| A record of what placed each block | the second | Nothing true could be said of a block placed before it |
| The opening drawn at the head of a document's settings | the second | It could not share the screen with the field at the largest text sizes. A candidate now (§8) |
| Export Again | the second | It could not repeat an export, and saved one tap |
| One template of settings and blocks together | this form, as first written | The owner's direction: two steps (§4.3) |
| The gallery first, with the rest under *Customize* | this form, as first written | Each step holds its templates and its own controls |
| A question before a template changed a collection | this form, as first written | Each step's change is small, in view, and undone where it is made |
| For one export, the template's own blocks in place of the collection's | this form, as first written | The apparatus is its own choice (§4.4) |

### 5.7 Four arrangements this app built and withdrew

| Arrangement | What happened before | This form |
|---|---|---|
| An inspector headed by a segmented switch | Built as *Document \| Composition*, and removed by Composer v2 (`CollectionEditorView.swift:2045-2049`) | None |
| The collection's settings shown in the inspector when nothing is selected | A build-28 tester asked for them to be reachable "after refocusing on a document"; the session that took the report found them "not reachable without clearing the selection" (`Completed/188-189-Tester-Feedback-Build28-Plan.md`, 188-E). Composer v2 moved them behind the gear | Behind the gear, as now |
| Content choices in the export sheet | Six controls, deleted by the Collections rework | Two choices, each of a named thing, for three formats, that write nothing. A partial return, and Q3 asks |
| Collection-level switches for apparatus | Decision A11 chose placeable rows (`Completed/Collections-Authoring-Scope.md:198`) | Rows, as now, the Note on the Text among them |

---

## 6. Citation styles

- **One setting for the collection:** History at State, Chicago, Turabian. It governs every place a citation prints: at a document's head, a contents row in *Citation* style, an excerpt's source line, the *See also* line, and the Bibliography's and the Chronology's rows.
- **A collection that exists today has none set, which reads as History at State.** Q5 asks what a new collection starts with.

For document 475, as the three formatters write it:

| Style | The citation |
|---|---|
| History at State | *Foreign Relations of the United States*, 1946, Eastern Europe, The Soviet Union, Volume VI, eds. Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Chicago | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*, edited by Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Turabian | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*. Edited by Rogers P. Churchill and William Slany. Washington, D.C.: Government Printing Office, 1969. Document 475. |

**What it takes in the kit.** `BatchContext.formatter` becomes `any CitationFormatter`, made from the collection's style. The assembly hands every exporter one kind of italics. The Bibliography sorts by volume and number, so a style changes no order. Both reviews tested these and they held.

**Three things still open,** and Q5 puts them to the owner:

- **Whether each style is right in each place.** The app's Chicago may have a note's shape and its Turabian a bibliography entry's, while a collection has both places, and neither names the document cited. The two manuals could not be fetched.
- **The *See also* line joins its citations with a semicolon** after taking one period off each (`CollectionItemHTMLRenderer.swift:390-392`), which runs Turabian's three sentences together.
- **A short form** (*FRUS*, 1946, vol. VI, doc. 475) is not in the core. Year, volume and document name more than one volume for 133 of the manifest's 553. It is a candidate (§8).

---

## 7. What is stored

### 7.1 Four optional properties on the two record types 1.0 has

| Property | Holds | When it is absent |
|---|---|---|
| `Collection.citationStyle` | the style's name | History at State |
| `Collection.opening` | which line leads | the citation leads |
| `Collection.labelsJSON` | the collection's own words, as a map from a label's name to its text | the app's words |
| `CollectionEntry.dateLine` | a document's date line (Q7) | none |

- **The Note on the Text needs no property.** It is a new value of a field every block already has.
- **Nothing else moves.** The eight composition fields, the entry's override fields and `titleOverride` stay what they are and stay the store of what they hold.
- **No record of a template** is kept (§4.3).

**One CloudKit promotion of four fields.** Each has its control in the lane that adds it (§9, lane 3), so the owner's write on a Development build can set all four before the deploy. CloudKit makes a field only from the first record that carries a value (`CloudKitSchemaInventory.swift:514-516`), which is why a property must not land in one lane and its control in the next. The second form cut its lanes that way.

### 7.2 What build 1861 does

It reads none of the four, so it prints 1.0's layout: the citation leading, History at State, the app's words, no date line. Nothing the volume prints is ever left out by the new settings, so nothing 1861 prints is false.

**What is not established** is what happens to the four on a record that a 1.0 device then changes, and what a device updated later holds for them on a record it imported before. The first review left that as a run (its G17), and it is still owed before lane 3 (§12). What is at risk is a style, an opening, a set of labels and a date line, which can be given again.

### 7.3 The labels value

It is one text property holding a map, as `SyncedPreferences.listOrderJSON` holds two lists (`ListOrderPreferences.swift:31-33`). The first review's first finding was that a build which decodes the keys it knows and writes the value back erases the rest, which is how that property is read (`:71-74`). Here the value is read and written as a plain map from name to text, so a build that does not know a label's name carries it through. A test holds that: a value with a name the build does not know survives an edit of another.

### 7.4 The collection file

The file stays what it is (the second review's §2 sets out its rules, each with its line).

- **No change of version, and the floor stays 1.** Five rounds of additions have ridden version 2 as optional keys, by the format's rule that the floor rises "only when *ignoring* a field would corrupt meaning" (`NativeCollectionFormat.swift:91-93`).
- **New optional keys:** the collection's `citationStyle`, `opening` and `labels`; an entry's `dateLine`. Each is written only where it is set.
- **Writing the minimum stays.** A collection that uses nothing new, and has no headnote, is written as the bytes 1.0 writes today, so the manuals' sentence stays true and the Guide's fixtures stay green.
- **The Note on the Text travels as a block.** A 1.0 app keeps a block type it does not know, inert.
- **A headnote travels as its text, with who wrote it, and not as a draft's id** (#1999; Q10).
  - Every import makes a draft of its own.
  - A file from 1.0 that carries an id is given a copy of the draft where the id resolves.
  - A 1.0 app that opens the new file shows no headnote. That is what a recipient on another account sees today. On its author's own account 1.0 found the draft by its id, and that is lost.
- **A 1.0 app, given a file the new version writes,** ignores the new keys and shows 1.0's layout.
- **The new version, given a file from 1.0 or from an outside tool,** reads it as today. Nothing says of it that its settings "came from 1.0".

**What the lane owes for the file:** the Guide's §15 (its two examples, its checker, its account of versions), both manuals' sentence, the sheet's hint, two ranged blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` (`:897`, `:3226`), and the format's own tests. And one run first: a hand-made file with the new keys opened in build 1861 by each of its three paths (§12).

### 7.5 The other carriers

- **The research export** takes format version 8, with a `Fields` case for each of the four properties (`CLAUDE.md`, *Import from JSON*) and a fixture of version 8. An older file imported over a newer library then keeps the library's four, by the plan's own rule (`ResearchImportPlan.swift:31-33`). A version-7 importer refuses a version-8 file whole, as it would any later file.
- **Duplicate and Create Static Snapshot** copy every stored property, held by a test that walks the schema (#1996).
- **No index version.**
- **The web edition** reads collections through the same kit values and follows by its own rules (`CLAUDE.md`, *Web edition*).

### 7.6 The route not taken

The owner offered a new model type with a one-way upgrade, and the second form took it. The second review found that the upgrade as designed could delete the work done after it:

- Two devices that upgrade one collection make twins with one id and one set of dates. For such copies the tree's own comment says its cleanup "can keep a different copy and delete the one the first device kept, and after sync no copy is left" (`DuplicateRecordCleanup.swift:243-245`). The owner's library already holds copies made this way by an earlier migration (`:249-251`).
- Nothing but the twin recorded the upgrade, so a new device or a rebuilt store could upgrade again from the 1.0 state.

**The reason for new types has gone with the notes as one choice.** The second form needed them because one value at every scope did not fit 1.0's fields. With the fields kept (§4.1), the new facts are four, and they fit.

If new record types are wanted for another reason, they need a different upgrade: started by the owner on one device and not by a launch; recorded on the 1.0 record, or by its removal, so that no other device repeats it; the new types read one copy of each id and never deleted by the cleanup, as #1791 ruled for notes; and a rule for an older export imported over an upgraded library. Q6 asks.

---

## 8. Other authorial capabilities

Candidates, in the order this design would take them. Q8 asks which.

1. **Selected passages as a document's text.** A fourth choice for text depth: the passages the author highlighted, in the document's order, with a sign where text is left out. It is what a course reader does most: abridge. The passages must then travel in the collection file as text, as a quoted passage does, since highlights do not travel (`NativeCollectionFormat.swift:55-58`). The sign for an omission is not brackets (§3.1).
2. **Save as Template.** An edited set of settings kept under a name for other collections. It is authored content, so it is a record type of its own, with a deploy of its own, and a collection file can carry the settings but not the template.
3. **The collection's own numbers,** at each document's head and in its indexes together, or not at all: the Persons and Thematic indexes would cite *Documents 3, 7 and 12* of the collection. In a form and a word that no volume prints.
4. **Where notes go.** Before the text, as an introduction to a document, or after it, as now.
5. **A date alone in contents rows.** *22 February 1946*, from the date the index stores, in the form the Chronology prints. It is a choice of form for every row, where a date line is one document's.
6. **A section's headnote default, and See also for the collection** (§4.1's two empty cells).
7. **The page.** Letter or A4; each document on a new page, or run on; page numbers in Word.
8. **Several formats in one export**, such as the PDF with its `.bib`.
9. **Same settings as…** Copy one document's settings to others.
10. **See also, by page.** The line matches a reference's target against the collection's documents, and a reference to a printed page is stored under its page (`CrossReferenceStore.swift:757-759`), so it matches none. The volumes through the 1950s refer by page. The app already maps a cited page to the documents on it.
11. **A short citation form**, once it has a rule that is unique over the manifest.
12. **A tagged PDF**, with a title and links, from the roles the plan gives each line.
13. **The opening drawn in a document's settings,** and **a settings column on iPad** with pointing there, as the reader draws its Research rail since R6a.

Considered and not proposed: editing a source note's text or a footnote; a document printed without its heading or its dateline (§3.1; Q2 asks); fonts and colours (no theming engine, item 9 of `Collections-Authoring-Scope.md`); editing inside the preview (its item 1).

---

## 9. Lanes

None needs an index version. No estimate of time is given; a lane's size is said by what it touches.

| Lane | What | Stored data | Changes exports | Before it starts |
|---|---|---|---|---|
| **1. Export from the lists** | *Export…* in the Collections list and Manage Collections; the format remembered on the device; the export sheet's fit at the largest text sizes | None | No | Nothing |
| **2. One plan for three formats** | §3.8; the one reading (§3.4); the source note once (§3.5); a title never alone, with *In the volume:* (§3.4); Word's contents list and its footnote numbers | None | **Yes.** It ends #1984, #1991, #1992, #1993, #1994, #1998, #2001, #2002, #2003 and #2007 | Q2, Q9; the Word and Pages run |
| **3. The four new facts** | §7: the four properties, each with a plain control in today's surfaces; the Note on the Text as a block; the statement of sources (#2005); the collection file's keys and a headnote's text (#1999); the research export's version 8 | Four properties: **one CloudKit promotion** | Only where used | Lane 2; Q4, Q5, Q6, Q7, Q10; the two-device run and the file run |
| **4. The three surfaces, trimmed** | §5.2, §4.2 and §4.3: the two steps in the collection's settings, with the recipe divided in the kit; a section's sheet without the collection's 15; *Default* that says what it is; *n set their own*; the snapshot from a smart collection's editor; the Mac's New Collection form; #2006 | None | No | Lane 3; Q1, Q11 |
| **5. The two steps for one export** | §4.4 and §5.1 | None | No: two new choices, and nothing an existing export prints moves | Lanes 2 and 4; Q3 |
| **6. The preview** | §5.3's four repairs on every platform (#1997, #2004); then, on the Mac, *Show Parts* | None | No, if the web page's ids keep their form for a document entered once | Lane 4 |
| **7. From §8** | As Q8 decides | As each needs | Only where used | Lane 3 |

**Three issues stand outside the lanes,** each a small change of its own: #1995 (where an added entry goes), #1996 (what Duplicate and the snapshot copy) and #2000 (the four exports and a document's research notes).

**Lanes 1 and 2 need nothing new stored.** Either could ship as a small release's row.

**What each lane owes, beyond the landing runs the plan of record names.**

- **Shared code** (lanes 2 to 6): `swift build --target FRUSCoreKit` and `swift test`, with the unit target and the Mac build.
  - Lane 4 divides `CollectionPreset.Recipe` in two. Decision 139's table stays as data, each case a document recipe with its suggested apparatus, and `CollectionTests.swift:3450-3565` goes on holding it. That suite's tests of what a template writes and of which card is *Active* (`:3546-3550`) move to the two steps.
  - `CollectionRenderingPinTests` pins the HTML page, the Word package, and the BibTeX and RIS files by SHA-256. Lane 2 moves the first two, and the last two if Q9 is yes; each is re-taken with its reason.
  - `CollectionResolutionTests` pins a dateline in an opener as absent (`:450-452`) and a digest of a dump that prints the header, the dateline and the Zotero title (`:706`). Lane 2 moves both.
  - `CollectionExportContrastTests` fails on a rule of the export's layer that draws text and is not in its list. Lanes 2 and 3 add rules.
  - The PDF has no pin. `CollectionExportParityTests` (#960) holds the three exporters to one inventory of blocks. Lane 2 takes it to the blocks' order, a source note longer than a line, a research note longer than a page, a contents list longer than a page, and a row's number.
- **The CloudKit gate** (lane 3; `CLAUDE.md`, *CloudKit schema-deploy gate*), with the research export's version 8, its fixture and its `Fields` cases.
- **Strings and screens.** `Docs/EditableContent/08-Reading-Research-Collections.md` has 26 ranged blocks that cite `CollectionExporter.swift`, which lane 2 rewrites, and 14 that cite `Collection.swift`, which lane 3 adds properties to. Both manuals' chapter 12; the captures that show the editor; the tour's step 16. `CollectionTests.swift:5644-5653` pins two source lines of the export sheet.
- **The six UI suites of `CollectionEditorTitleTests.swift`** hold the editor's name, subtitle and note fields, the colophon switch, the saved-search link and Open Document. They drive no composition control, so they are no evidence about one. Lane 4 brings each to its surface in the same change.
- **Accessibility, in the lane and not after it.** Each check says what holds it: a suite, with its devices, or a walk by a person. The UI test target is iOS; nothing automated holds the Mac.

| Lane | The check | Held by |
|---|---|---|
| 1 | The export sheet at the default size, AX3 and AX5: when it opens, the sentence, the format and *Export* are in view | A fit suite on iPhone 17 and iPhone SE |
| 1 | The list row's *Export…* as a VoiceOver action | A suite that reads the action's name; the service cannot perform one |
| 2 | In the web page and in Word, for each of the three openings: which line is the document's heading, and that *In the volume:* is inside the volume's heading | A kit test over the plan and the HTML |
| 3 | The four new controls speak their name and value; the wording table's ten fields each have a label | A VoiceOver suite on iPhone 17 and iPad Pro 13-inch |
| 4 | A picker's first choice is spoken as *Follow the section: On*; *2 set their own* is a button with that name | The same suite |
| 4 | Step 1's cards and the section pill at AX3 and AX5, proved on the card's own label; the pill's hit area | A fit suite on an iPhone and an iPad; a hit-area suite |
| 4 | Each of step 2's ticks speaks its block's name and whether the collection has it; the line that says what a template changed is spoken when it appears, with *Undo* reachable after it | The same VoiceOver suite |
| 4 | On the Mac, a step opened in place in the gear's popover: what is reachable by keyboard alone, and what scrolls | A walk |
| 5 | A menu's item that cannot be chosen says why, in words that are spoken | The VoiceOver suite |
| 6 | On the Mac, a click on a part announces what is selected and leaves focus where it was; every part reachable from the column by keyboard alone | A walk |

**Order.** 1 and 2 first, in either order; then 3, 4, 5, 6.

---

## 10. Decisions for the owner

Each with a recommendation. Nothing in §9 starts before the questions in its row are answered.

- **Q1. The interface.** **1.0's three surfaces, trimmed and renamed, with the collection's settings as the two steps (recommended, §5.2).** Or a new single inspector, which two forms of this record proposed and two reviews took apart; it could be tried again later, on the plan and the four facts this form adds.
- **Q2. The mark, and what the author may not do.**
  - **The words *In the volume:*, fixed, before the volume's heading wherever a title stands above it (recommended, §3.4).** The wording is yours.
  - **A document printed without its volume's heading or dateline is not offered (recommended).** If it is wanted, it owes: the source note's call re-homed in the volumes from 1955; each such document listed in a Note that cannot be removed; and a word on the page.
- **Q3. The two steps in the export sheet.**
  - **Both, for PDF, Word and Web page, for that export, writing nothing (recommended, §4.4).** Or the sheet stays format and destination, as the Collections rework left it.
  - **A choice of documents leaves the apparatus as the collection has it, with the suggested set one item away (recommended).** Or it moves the apparatus to the suggested set, in view: one tap then gives all that one of decision 139's templates gives, and a block the author placed can be left out without having been asked for.
- **Q4. What leads a document, and what a new collection starts with.**
  - **§4.3's table: the volume's heading leads in the two full-text document templates and in the summaries (recommended);** or the citation leads in all six.
  - **A new collection keeps 1.0's settings, with the volume's heading leading and no apparatus (recommended):** the full text, footnotes and the author's research notes. Or it starts under *Full text as printed*, which leaves the author's research notes out. Or it is exactly as 1.0 makes it.
- **Q5. Citation styles.** **A new collection takes the style chosen in Settings ▸ Display (recommended)**, or History at State always. And whether the app's Chicago and Turabian are right as they stand for a line at a document's head, a row of a list and a *See also* line (§6).
- **Q6. Storage.** **Four optional properties on the record types 1.0 has (recommended, §7.1)**; or new record types, with the upgrade §7.6 says they would need.
- **Q7. A date line of the author's.** **Kept, for a document that has a title, above the words *In the volume:* (recommended, since it was asked for)**; or dropped, now that the volume's dateline stays and a contents row carries it.
- **Q8. Which of §8's thirteen,** and in what order. **Recommended for the first pass: 1 (selected passages).**
- **Q9. Whether a citation record's title takes the new reading of a heading** (#1992, #2002). **Yes (recommended):** a Zotero item is then titled "Document 1: Letter From President Carter…", without the doubled number or "[1]". It changes what a send or a file carries.
- **Q10. Whether a headnote travels in the collection file as its text** (#1999). **Yes, always, with who wrote it (recommended):** it was written for the collection, as a note block was. Or only when research notes are included; or not at all, which is what a recipient gets today.

- **Q11. The two steps' lists** (§4.3).
  - **Step 1 keeps decision 139's six, with three renamed for what they now do (recommended):** *Summaries* for *Summaries with overview*, *Citations with source notes* for *Citations with archival sources*, and *Full text with everything* for *Everything included*. Or the six names stay as they shipped.
  - **Step 2 is the eight complements with three shortcuts,** *Suggested for…*, *All* and *None* **(recommended).** Or named sets of your own choosing in their place.
  - **The contents-list style and the word cloud are step 2's (recommended),** as 1.0 heads them *Analysis & apparatus*. Or the contents-list style goes with the documents.
  - **The colophon, the project stamp and the query log sit under step 2 and no shortcut sets them (recommended).** Or they stay with the title page, where 1.0 has them.

And one that is not a question of design: **whether lanes 1 and 2 go ahead by themselves**, before the answers to the rest.

---

## 11. The second review's findings, and where each is answered

Each is answered in the design's text. None is tested, and §12 says which need a run.

| Finding | Answer | Where |
|---|---|---|
| **H1** Two devices that upgrade can each delete the other's copy | There is no upgrade | §7.6 |
| **H2** Only the twin records an upgrade | None | §7.6 |
| **H3** The fork's test reads one date | No fork: 1.0 and the new version write the same records | §7.2 |
| **H4** An older export over an upgraded library | The plan's own rule, with a `Fields` case for each new property | §7.5 |
| **H5** "One promotion" beside a later first writer | Four properties, each with its control in the same lane | §7.1 |
| **H6** The file need not change version | It does not | §7.4 |
| **H7** A headnote as its draft's id | Its text travels; an import makes its own draft; filed | §7.4, #1999 |
| **H8** Four exports ignore a document's notes setting | Filed; until then the sheet says so | §5.1, #2000 |
| **H9** A look and the four that are not renderings | The two steps are for three formats | §4.4 |
| **H10** A template's blocks and the author's | The apparatus is its own choice, for the collection and for one export; nothing records a placer | §4.3, §4.4 |
| **H11** Three templates need what the collection may lack | Each choice says what it needs before the export; no placeholder in an exported file; #1991 first | §4.4 |
| **H12** The notes as one choice | The two switches stay; the plan prints the source note once | §3.5 |
| **H13** 1.0 numbers its rows in three ways | The plan numbers documents only, alike; no setting | §3.8, #1993 |
| **H14** Two numberings on one page | No number at a document's head | §3.3, #2002 |
| **H15** The date line has no words | It is given only under a title, above *In the volume:*; or dropped | §3.4, Q7 |
| **H16** The Note under a look; row and switch | A block, among step 2's apparatus and in every suggested set, written from the plan that prints. Its tick is its row and stores nothing | §3.6, §4.3 |
| **H17** Word numbers footnotes itself | The plan carries each note's label; filed | §3.5, #2001 |
| **H18** The mark could be renamed | Fixed, and true of every volume; a contents row's second line has it | §3.4, §5.2 |
| **H19** The count is 41 | Recounted field by field | §5.5 |
| **H20** A value held at what it would inherit | It is set, and shown as set; *Default* says what it follows; a way back for many | §4.2 |
| **H21** The sheet at the largest sizes | The sheet's order is 1.0's; a fit suite, and a run | §5.1, §9, §12 |
| INT-2 What is new for one document | Said: a date line | §5.5, the head of this record |
| INT-6 The Mac's column | The gear's popover, as now | §5.4 |
| INT-7, ENG-9 A smart collection has nothing to select | Nothing is selected; the snapshot is offered in the editor | §4.5 |
| INT-8, FMT-10 Export Again | Gone | §5.1 |
| INT-9 A new collection's default | Put to the owner with what each choice leaves out | Q4 |
| INT-10, ENG-10 Words | A table; *Footnotes* is not renamed and is in the plan | §4.6, §5.2, §3.8 |
| ENG-4 Where an added entry goes | Every kind; filed | §4.3, #1995 |
| ENG-5, FMT-6 What the lanes left out | Named | §9, §7.4 |
| ENG-6, FMT-8, EDI-10 One reading, two sources; the records; a dateline's calls | The reading returns each apart and says what the index lacks; the records are Q9 | §3.4 |
| ENG-7, EDI-7 The shared sentences | Left alone; a sentence of the collection's own | §3.7 |
| ENG-8 The preview's repairs | A lane for every platform | §5.3, §9 |
| DATA-7, DATA-8, DATA-9 The upgrade's table; other writers; the copy test | No upgrade and no value of keys but the labels' map; the copy test walks properties | §7.3, §7.5 |
| DATA-10 The snapshot's blocks | Carried; filed | §4.5, #1996 |
| FMT-7 A round trip of every field | Not claimed; the file writes what it is set to write | §7.4 |
| FMT-9 Candidates that cannot travel | Said of each | §8 |
| EDI-8 Statements true of one era | Corrected; the Note is written from the volumes in the collection | §3.6 |
| EDI-9 The source note before 1955 | A row of its own | §3.5 |
| A11Y-2 Focus on the Mac | Focus stays where the click was | §5.3 |
| A11Y-4 The citation before the heading | The plan names each document's region; a check for all three openings | §3.8, §9 |
| A11Y-5, A11Y-9 Fixed type, the pill, the list's actions, the switches' names | Filed, and in lane 4 | #2006 |
| A11Y-6 A row's second control | One control a row | §4.2 |
| A11Y-7 Checks for five lanes of seven | A check for each lane that has a screen, each with what holds it | §9 |
| A11Y-8 The drawn opening | Not in the core | §8 |

**From the first review, still open under this form:** what a device updated later holds for a new property (its G17), which is §12's first run; and Word's contents list (its G12), which is §12's fourth.

**Where a reviewer would start on the amendment,** which no one has reviewed:

- **A tick that stands for a row.** The second review's H16 was a block that was both a row and a switch. Here the tick is the row's existence and nothing is stored beside it, but decision A11 chose rows over switches for a reason (§5.7), and a list of ticks is a second way to the same rows.
- ***None* leaves out the Note on the Text,** in a collection whose documents carry the author's titles. The sheet says so; it does not prevent it.
- **48 controls where there are 24** (§5.5), on four screens where there is one.
- **A step opened in place in the Mac's popover** is 14 controls in 420 points, above the ten already there.
- **The first tap no longer gives what a template of decision 139 gives.** It gives the documents; the apparatus is a second tap (Q3).

---

## 12. Runs owed, each needing a device, an app or an opened file

| When | The run |
|---|---|
| **Before lane 3** | Two devices on one iCloud account, B kept on 1861. On A, a build with one of the new properties sets it on a collection B already holds. Let B import; rename the collection on B and read the property on A. Update B; read the property on B before A touches the collection again; then rename on B and read on A |
| **Before lane 3** | A hand-made collection file carrying the new keys, opened in build 1861 from *Import Collection…*, from Finder and from Files |
| **Before lane 3** | In 1.0: export a collection with a written headnote, import the file on the same device, edit the copy's headnote and read the original's (#1999) |
| **Before lane 2** | A `.docx` whose contents list is plain linked rows with a page-number field each, and one whose list is a field over marked entries, each opened in Word and in Pages. And a note with the volume's own number as its mark |
| **Before lane 2** | In 1.0: export `frus1961-63v11` d1 under *Full text as printed* and count the source note (#1991); export a collection with one section heading as a web page and read its contents rows' numbers (#1993); export `frus1946v06` d475 to Word and read the number after "[13]" (#2001) |
| **In lane 1** | The built sheet on iPhone 17 and iPhone SE at the default size, AX3 and AX5 |
| **In lane 4** | The Mac's gear popover with step 2 opened in place: what is in view at 420 points, and what scrolls |
| **In lane 6** | In 1.0, with the preview on, switch Headnotes alone and wait five seconds (#1997). Then the Mac's preview keeping its place across a reload, with a long collection |
| **A desk, any time** | The app's Chicago and Turabian against the two manuals, for a note, a list and a bibliography's entry |

---

## 13. Files

- **This document,** and the two reviews of its earlier forms: `Planning/Collections-Design-Adversarial-Review-2026-11-25.md` with `Planning/collections-design-review/`, and `Planning/Collections-Design-Second-Review-2026-11-25.md` with `Planning/collections-design-review-2/`.
- **The issues:** #1991 to #2007, filed on 2026-11-25, and #1984.
- **The canvas:** <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>, nine boards of this form as amended, its Version 13. It is private to the owner's account; its source is not in the repository.
- **Read, at `efd73ec`:**
  - the model: `FRUSExplorer/Models/Collection.swift`, `GeneratedSummary.swift`, `ModelContainer+FRUS.swift`, `CloudKitSchemaInventory.swift`, `DuplicateRecordCleanup.swift`;
  - the kit: `FRUSCoreKit/Collections/CollectionExporter.swift`, `CollectionContentAssembly.swift`, `CollectionItemHTMLRenderer.swift`, `DocxCollectionExporter.swift`, `BibTeXCollectionExporter.swift`, `ZoteroCollectionExporter.swift`, `CollectionGeneratedBlocks.swift`, `NativeCollectionFormat.swift`; `FRUSCoreKit/Citation/CitationFormatter.swift`, `ZoteroJSONExporter.swift`; `FRUSCoreKit/TEI/FRUSRenderNode.swift`, `FRUSRenderNodeHTMLSerializer.swift`, `FRUSDocumentParser.swift`, `ASTToRenderNodeConverter.swift`; `FRUSCoreKit/Search/IndexingPipeline.swift` where it stores a heading and a dateline; `FRUSCoreKit/Export/ResearchImportPlan.swift`;
  - the app: `FRUSExplorer/Collections/` (`CollectionEditorView.swift`, `CollectionEntryInspector.swift`, `CollectionEntryRows.swift`, `CollectionEntryData.swift`, `CollectionCompositionRows.swift`, `MacCollectionManagerView.swift`, `CollectionListView.swift`, `CollectionExportSheet.swift`, `CollectionPreviewView.swift`, `PDFCollectionExporter.swift`, `CollectionExporter+App.swift`, `NativeCollectionFormat+App.swift`);
  - the manuals' chapter 12, `Docs/Agentic-Analysis-Guide.md` §15, and the three earlier designs under `Completed/`;
  - the public TEI of eight volumes.
- **Not read:** `CollectionAddDocumentsSheet.swift`, `CollectionRichTextEditor.swift`, `CollectionPickerSheet.swift` beyond its purpose, and the web edition's repository.
- **Not done:** no build, no test run, no capture, and no review of this form. The counts of §2.4 and §5.5 are of lists, not of a running screen.
