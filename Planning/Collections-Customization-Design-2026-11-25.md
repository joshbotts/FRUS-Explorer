# Collections: export in two taps, and fine-tune every part of a document — a design, 2026-11-25

**Status: PROPOSED, 2026-11-25. Nothing is built, and no code changed.** §9 asks the owner for eight decisions; §8's lanes are written so that the next plan of record can take them as rows.

**What this is.** The owner's words of 2026-11-25:

> "I am not satisfied with the Collections feature. I am not able to customize how each document is displayed, yet the interface is very complicated. I want to be able to export a collection very quickly using sensible default templates (the new ones we created last week are good starting points). I also want to be able to fine-tune any aspect of the collection, including overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately. I want to be able to choose what citation format to use if the contents are listed that way. Consider other authorial capabilities along these lines as well. Consider what kinds of user interface alternatives might help me preserve clean simplicity for default situations and also wield powerful customizability for other times."

That is five asks, and this document takes them in order:

1. a quick export from a template (§4.1);
2. every part of a document adjustable, in a simpler interface than today's (§3, §4);
3. the volume's headings and datelines replaced by the compiler's own, and marked (§5);
4. a citation style for the collection (§6);
5. other authorial capabilities (§7).

§2 says where the feature, as 1.0 (1861) ships it, falls short of each.

**How it was read.** In a cloud session with no Xcode, on 2026-11-25, from `v2` at `efd73ec` (#1988's merge). Nothing was built or run, so every statement about behaviour below is read from the code and from both manuals, and each carries its file and line at that commit.

- Three sub-agents inventoried the iOS and iPadOS editor, the Mac's Collections window, and the three exporters. Each claim of theirs that this document relies on was then re-read in the code by the session; §2 cites the lines.
- The examples are real: document 475 of `frus1946v06` and its neighbours, read from the public TEI (`HistoryAtState/frus`, `volumes/frus1946v06.xml`), with the volume's title, editors and year from the bundled manifest. The citations are what `CitationFormatter.swift`'s three formatters write for it, worked by hand from their code.
- The two earlier Collections designs were read first: `Completed/Collections-Authoring-Scope.md` (2026-07-02) and `Completed/Collections-Manager-UX-Scope.md` (2026-07-04). §3.6 says where this design departs from them.

**The mockups** are on a design canvas, private to the owner's account: <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>. It holds seven boards:

- the export sheet on an iPhone (§4.1), which answers to its template and format;
- the three interfaces of §4, each drawn in the same Mac window over the same six documents, with document 470 printed whole. Option B's switches and Option C's parts answer to clicks;
- Option B on an iPhone;
- the three marks of §5, on the head of document 475;
- a contents list in four citation styles (§6).

The session wrote the boards and did not see them rendered: this container cannot open the canvas.

---

## 1. In brief

- **Every document is drawn one way, and the three formats disagree about that way.**
  - A document prints the citation as a heading and then the volume's own heading under it, at the same size in the HTML and the PDF. The author can replace the first of the two and neither hide nor replace the second (§2.2).
  - The PDF prints a source note above the text and only its first line, ends its contents list where the cover page ends, and gives each research note a page of its own. The Word file ignores the contents-list style. The live preview shows the HTML alone (§2.3).
- **The controls are many, and they are sorted by where a value is stored.** Collection settings holds 24. A document's inspector holds nine settings, eight of them a picker with a *Default* choice. A section's sheet shows 21 controls, of which six are the section's (§2.4).
- **A template is a one-way trip, and it is not offered at export.** One tap overwrites eight fields with no undo and adds apparatus that no other template takes away. The export sheet chooses a format and nothing else, and nothing exports a collection from the Collections list (§2.1, §2.5).
- **Collections cite in one style.** The app has three formatters and a synced preference for them; the collection's assembly names one formatter in its code (§2.7).

**What is proposed:**

- **A document has ten parts, and every surface speaks of those ten:** heading, reference, dateline, headnote, text, footnotes, source note, highlights, your notes, see also (§3.1).
- **Three layers, one rule.** A template gives every part a value; the collection, a section or one document may change one. A control shows what is in force, a dot marks a change, and Reset removes it. The *Default / On / Off* pickers go (§3.2).
- **Templates that switch back.** The collection records which template it follows and keeps the reader's own edited settings beside it, so a template tried at export is undone by choosing the old one (§3.3).
- **Export is a template, a format and a button**, from the editor, from the Collections list and from the Mac's menu (§4.1).
- **One inspector in place of three settings surfaces**, with the live preview as the way into it: tap a heading in the preview, and the inspector opens on Heading for that document (§4.3 to §4.5).
- **The compiler's heading or dateline is always marked**, in brackets by default, and a generated *Note on the Text* lists what the volumes print in their place (§5).
- **A citation style per collection**, with a short form for contents lists (§6).
- **One plan for three formats:** the kit resolves each document's parts once, and HTML, PDF and Word draw that plan, which is also what ends §2.3's differences (§3.5).
- **Two stored values and one CloudKit deploy** carry all of it, and what a later lane adds needs no further deploy (§3.4).

---

## 2. What 1.0 (1861) does, against each ask

### 2.1 "Export a collection very quickly"

- **The export sheet chooses a format and nothing else.** It shows the collection's one-line composition summary, six format cards and the Zotero row (`CollectionExportSheet.swift:220-240`, `:342-371`). It opens on PDF every time (`@State private var selectedFormat: ExportFormat = .pdf`, `:60`), whatever the collection last exported as.
- **A template is applied somewhere else.** On an iPhone the path from the Collections list to a PDF under another template is: the collection's row, *Collection settings*, a template chip, Back, scroll to *Actions*, *Export…*, a format card, *Export PDF*. On the Mac the templates are in a 420-point popover behind the toolbar's gear (`MacCollectionManagerView.swift:1172-1262`).
- **Nothing exports from a list.** The iOS Collections list's context menu offers Rename, Duplicate, Word Cloud, Create Static Snapshot and Delete (`CollectionListView.swift:350-387`), and the file names no exporter. On the Mac both ways in, the toolbar's *Export…* and the Collection menu's *Export Collection…* (⇧⌘E), set the same flag that opens the sheet (`MacCollectionManagerView.swift:1759`, `:1111`).

### 2.2 "Customize how each document is displayed"

Every document is drawn in one order, whatever the template. From the HTML renderer (`CollectionItemHTMLRenderer.swift:291-413`), which the live preview shows:

1. the citation as an `<h2>`, linked to history.state.gov, or the entry's title override in its place (`:296-309`);
2. the document's address, as a paragraph of its own (`:304-306`);
3. the headnote, when on (`:317-319`);
4. the text, which opens with **the volume's own heading, a second `<h2>`** (`FRUSRenderNodeHTMLSerializer.swift:740-741`), and its dateline (`:743-744`);
5. the source note under the word *Source:* (`:379-382`);
6. the *See also:* line (`:386-394`);
7. each research note, under *Research Note* (`:397-409`).

What the author can change in that, for one document:

- the text of line 1 (*Title override*, `CollectionEntryInspector.swift:385-403`), which leaves the volume's heading standing under it;
- how much of the text prints (full, a summary, none);
- six switches: highlights, research notes, source note, footnotes, related documents, headnote.

What the author cannot change:

- which of the two headings leads, or whether both print;
- the volume's heading or its dateline, in any way;
- the address line;
- any label. *Contents*, *Summary*, *Source:* and *Research Note* are literals in the renderer (`CollectionItemHTMLRenderer.swift:560`, `:359`, `:380`, `:400`); *Headnote* and *See also:* are the app's strings (`:450`, `:387`);
- the order of the parts.

**Why a heading of one's own matters.** Documents 470, 473, 474, 475, 476, 477, 480 and 486 of `frus1946v06` all carry one heading: *The Chargé in the Soviet Union (Kennan) to the Secretary of State*. Under *Header & Dateline* a contents list of them differs only in its dates. Under *Citation* every row is the same citation of some 200 characters, ending in a different number. Document 475 is the telegram a reader knows as the Long Telegram, and nothing in the collection can say so in its heading without leaving the volume's heading beside it.

**The outline does not show the override either.** A document's row reads the indexed header (`CollectionEntryRows.swift:972`), on the Mac too (`MacCollectionManagerView.swift:2022-2028`), so a title the author gave appears in the preview and the export and not in the list they arrange.

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

So a setting tuned in the preview is a setting tuned for one of three outputs, and a default that reads well in HTML can lose most of a source note in PDF.

### 2.4 "Yet the interface is very complicated"

Counted from the code, on iOS and iPadOS:

| Surface | Controls | Of which |
|---|---|---|
| **Collection settings** (iPhone screen, iPad sheet; `CollectionEditorView.swift:806-830`, `:880-913`) | 24 | 8 name and title page, 6 templates, 9 composition (one of them conditional), 1 smart-collection link |
| **A document's inspector** (`CollectionEntryInspector.swift:348-366`) | 9 settings, and more | Title override; *Body depth* and *Summary prompt*, each with a *Default* choice; six *Default / On / Off* pickers. Then a switch per research note, a switch per highlight, and the headnote card's Edit and Generate |
| **Section Defaults** (a heading's sheet; `CollectionEntryRows.swift:192-195`) | 21 | **15 are the whole collection's** (six attributes and nine composition controls) and 6 are the section's |

What makes the count hard to carry:

- **The same setting is in more than one place under more than one name.** The Section Defaults sheet is the inspector opened with its defaults, and one default shows the collection's own settings (`showsCollectionSettings = true`, `CollectionEntryInspector.swift:159`; `:301-303`). So a heading's sheet opens on the collection's *Description*, *Subtitle*, *Author line* and *Append colophon page on export*, which Collection settings calls *Note*, *Subtitle (title page)*, the author field and *Include colophon* (`CollectionCompositionRows.swift:388-427`; `CollectionEditorView.swift:1044-1075`).
- **A section's text depth is not in its sheet.** It is the *Section body* menu on the heading's row (`CollectionEntryRows.swift:177-185`), while the sheet's doc comment says the picker leads it (`CollectionEntryInspector.swift:763-764`).
- **Eight pickers ask the author to think in inheritance.** Each offers *Default*, and under it a caption, *Default → On*, which does not say whether the section or the collection decided (`CollectionEntryInspector.swift:631-650`). One sentence at the foot of the group explains the rule (`:790-791`).
- **The settings are sorted by where they are stored.** To change how one document looks, the author must first know whether the thing is a collection setting (the gear), a section default (a heading's pill or its row) or a document override (Configure), and go there.
- **The Mac has three places of its own:** the gear's popover for the collection, a trailing column for a document, and no toolbar control for the preview, which the Collection menu's *Show Preview* (⌥⌘P) turns on and off (`MacCollectionManagerView.swift:1648-1793`; `FRUSExplorerApp.swift:4543-4551`).

### 2.5 The templates

- **One tap, at once, with no undo** (`CollectionCompositionRows.swift:284-286`; `CollectionEditorView.swift:1935-1943`). It overwrites eight fields (`CollectionExporter+App.swift:29-39`).
- **Apparatus only accumulates.** A template adds the blocks it calls for and removes none, so a collection that has tried all six holds all five blocks.
- **"In force" is a comparison.** A card is marked when the collection's eight fields equal its recipe (`matches`, `CollectionExporter+App.swift:46-56`). Change one switch and no card is marked; nothing records which template the author started from, or what they changed.
- **A new collection follows none of the six.** The model's defaults are the full text with footnotes and research notes, and no source note (`Collection.swift:132`, `:143`, `:218`), which is no template's recipe: *Full text as printed* adds the source note and leaves the notes out. So the quickest export there is, of a collection just made, is under settings that have no name.
- **A template cannot say how a document is laid out**, since no setting does (§2.2). The six differ in how much text prints and in what comes with it.

### 2.6 The preview

- **It forgets the author's place.** Each edit regenerates the page a second later and loads it whole (`webView.loadHTMLString`, `CollectionPreviewView.swift:882-887`), and the file holds no code that keeps or restores a scroll position. Its own note says so: *Scroll-sync and per-item incremental DOM patching are explicitly out of scope here* (`:66-67`).
- **It is not joined to the outline.** Choosing a row does not bring its document into view, and tapping a document in the preview does nothing.
- **It shows the first 20 documents** until *Render All* (`initialDocumentCap`, `:153`), and one format (§2.3).

### 2.7 Citations

- **The assembly names its formatter.** `BatchContext.formatter` is typed `HistoryAtStateCitationFormatter` and built as one (`CollectionContentAssembly.swift:797`, `:917`). The document heading, a *Citation* contents row, an excerpt's source line, the *See also* line and the Bibliography's rows all come from it. The inspector's placeholder builds a second (`CollectionEntryInspector.swift:1306`).
- **The app has three styles and a preference.** `CitationStyle` is *History at State*, *Chicago* and *Turabian* (`CitationFormatter.swift:30-43`). Settings ▸ Display chooses one, it syncs (`SyncedPreferences.citationStyleRaw`), and the reader's Copy Citation uses it (`DocumentViewModel.swift:213`). A collection does not read it.
- **The exporters read one kind of italics.** Chicago and Turabian mark the title `*…*`; the history.state.gov style marks the series' name `_…_`. All three exporters turn `_…_` into italics and nothing else (`CollectionItemHTMLRenderer.swift:1222`, `DocxCollectionExporter.swift:1982`, `PDFCollectionExporter.swift:1569`), so the other two styles would print their asterisks.

---

## 3. The model

### 3.1 A document has ten parts

The parts are what a reader of the export sees, top to bottom. Every surface in §4 lists these ten and no others.

| Part | Today | Proposed choices |
|---|---|---|
| **Heading** | The citation, or a title override in its place; then the volume's heading again inside the text | *The volume's heading* · *The citation* · *The citation, then the volume's heading* (today's, and what an untouched collection keeps) · *Your own*, for one document |
| **Reference** | Not a part: the citation is the heading, and the address prints under it | The citation, small, in the collection's style, with the address behind it. Shown or hidden. When the heading is the citation, this part is the heading |
| **Dateline** | As printed, inside the text | *As printed* · *Your own* · *Hidden* |
| **Headnote** | On or off, with its card | Unchanged |
| **Text** | Full document · Summary only · Index / outline | The same three, as *Full · Summary · None*. *Selected passages* is §7's first candidate |
| **Footnotes** | On or off | Unchanged |
| **Source note** | On or off, under *Source:* | On or off, under the collection's word for it |
| **Highlights** | On or off, and which | Unchanged |
| **Your notes** | On or off, and which, under *Research Note* | The same, under the collection's word for them; before or after the text is §7's |
| **See also** | On or off | Unchanged |

Two things follow.

- **"Your own heading" is the field the app already has.** `CollectionEntry.titleOverride` means *what this collection calls this document*, in the contents list and at its head (decision D4 of 2026-07-04). What changes is where it prints: in place of the volume's heading, not above it.
- **The text is never among the choices.** The heading and the dateline are the volume's editors' words about a document. They are not the document's words, and that is why they may be replaced where the text may not (§5).

### 3.2 Three layers, one rule

A value comes from the nearest layer that sets it: **the document, else its section, else the collection, else the template.** That is today's cascade (`CollectionContentAssembly.swift:1035-1051`) with the template named as its last layer.

The rule every control follows:

1. **It shows what is in force**, on or off, or the choice. No control offers *Default*.
2. **Changing it stores a change at the scope being edited.** The scope is a choice of three at the head of the inspector, *This document*, *This section*, *Whole collection*, and it follows what is selected.
3. **A dot marks a part that differs** from the layer beneath, and the part's detail says which layer: *Changed for this document. The section shows footnotes.*
4. **Reset removes the change**, for one part or for the scope.

So *Hide the footnotes of this one document* is one switch, and the author never weighs *Off* against *Default → Off*.

### 3.3 Templates that switch back

- **The collection records the template it follows.** A template chosen anywhere, in the inspector or in the export sheet, becomes the collection's, and is saved as every edit is.
- **The author's own settings are kept beside it.** Changing a setting while a template is in force makes the collection's own version of it: *Full text as printed, edited · 3 changes*. Choosing another template leaves that version in the list as **Your settings**, one tap away. No template is a one-way trip.
- **A template owns the apparatus it placed.** A block that came with a template goes when the collection changes template and the new one does not call for it. A block the author added or moved is theirs and stays. Trying all six leaves what the sixth calls for.
- **Per-document and per-section changes stay through every switch.**
- **Save as Template** keeps an edited version for other collections (§7).
- **A shipped template's recipe does not change afterwards.** A different look is a new template with a new name, so a collection that follows a template never exports differently after an update. L25 already worked this way: six new names, and no stored collection moved.

The six of decision 139 stay, and each gains a value for the three new parts. A proposal, for Q4:

| Template | Heading | Reference | Dateline |
|---|---|---|---|
| Full text as printed | The volume's heading | Shown | As printed |
| Full text with your annotations | The volume's heading | Shown | As printed |
| Summaries with overview | The volume's heading | Shown | As printed |
| Citations with your notes | The citation | (the heading) | As printed |
| Citations with archival sources | The citation | (the heading) | As printed |
| Everything included | The citation, then the volume's heading | (the heading) | As printed |

A collection that exists today keeps *The citation, then the volume's heading* and exports as it does now, until its author chooses a template again.

### 3.4 What is stored: two values, one deploy

Every new setting lives in one of two values, each a small object of optional keys that FRUSCoreKit declares, with a decoder that reads a key it does not know as absent:

- **`CollectionStyle`**, the collection's. Stored as text in one new property, `Collection.styleJSON`.
  - The template in force, and the template the author's own settings began from.
  - The author's own settings, kept while a template is in force (§3.3).
  - The citation style (§6); the heading and the reference; the labels (§7); the mark (§5).
  - Later: the notes' place, the collection's own numbering, the page (§7).
- **`CollectionEntryDisplay`**, an entry's. Stored the same way in `CollectionEntry.displayJSON`.
  - On a document: its own heading choice, its own dateline or *hidden*, and its reference hidden.
  - On a heading: the same keys, as the section's.
  - On an apparatus block: that a template placed it (§3.3).

The eight composition fields and the entry's override fields stay as they are and stay authoritative for what they hold. `CollectionExportOptions(composing:)` is already the one place a collection's settings become options (`CollectionExporter.swift:592-604`), and it reads the style there.

**Why two values and not a property per setting.**

- **One Production deploy.** Each stored property is a CloudKit identifier, and each addition is the R-7 gate: the owner writes the field once on a Development build and deploys the schema. *Fine-tune any aspect* is a list that will grow. With two text properties, `CD_Collection.CD_styleJSON` and `CD_CollectionEntry.CD_displayJSON`, the program deploys once, and a key added later is not a schema change.
- **A template is a `CollectionStyle` value**, so *N changes* is a comparison of two values and *Reset* is the removal of a key.
- **The cost:** two devices that change different keys of one collection's style before either syncs keep the later writer's whole style, where separate properties would keep both changes. For one person's collection that is rare, and the loser's change is a setting to make again.

**What an older build does with them.** Build 1861 does not read either property, so it draws today's layout: the title override where the citation was, and the volume's heading under it. Nothing the volume printed is hidden on an old build, so nothing there needs a mark. The same holds for a `.fruscollection` file opened by a reader that ignores the keys, so the file's `minimumReaderVersion` stays 1.

**What else carries them.**

- **The research export** takes format version 8, with `ResearchImportPlan.Fields` a case for each (CLAUDE.md, *Import from JSON*) and a fixture of version 8 beside the seven. The web edition follows, by its own rules.
- **`.fruscollection`** takes two optional keys, each joining `usesV2Features` (`NativeCollectionFormat.swift:615-639`). They are portable content, as `titleOverride` is.
- **Duplicate** copies both properties (`Collection.duplicate(in:)`).
- **No index version.** Nothing here changes what is indexed, the reader's page or `renderingVersion`.

### 3.5 One plan for three formats

Today each exporter decides for itself what a document's parts are, in what order, under what words. §2.3 is the result.

- **FRUSCoreKit resolves each document into a plan:** the ordered parts that will print, each with its final text, its label and its mark. The assembly builds it where it already resolves the cascade (`resolveEntry`, `CollectionContentAssembly.swift:944-1165`).
- **HTML, PDF and Word draw the plan in order.** None decides a part's presence, place or wording. A format keeps its own typography and pagination, and nothing else.
- **§2.3's differences end as a consequence:** the source note follows the text in the PDF and prints whole, a research note flows under its document, the contents list continues onto further pages, and Word's contents rows come from the same label as the other two.
- **The preview becomes true of all three in everything but pagination.**

One constraint decides how a replaced heading is drawn. **The volume's heading and dateline are part of a document's flat text** (`appendFlatText`, `FRUSRenderNode.swift:666`), which highlight offsets count. So a heading that is replaced or hidden is still walked by each exporter's offset counter and is not drawn: hidden in the HTML, and consumed by `HighlightPaintTracker` in PDF and Word, whose contract is every chunk of flat text, once, in order (`CollectionExporter.swift:398-400`). Removing the node from the model would move every highlight after it.

### 3.6 Where this departs from the earlier designs

`Collections-Authoring-Scope.md` lists what the program would not build. Three of its items bear on this design.

- **Item 1, no editing inside the preview.** Kept. Option C (§4.4) and the recommendation select a part in the preview and change it in native controls. Nothing in the web view becomes editable, and the model stays the one source of the page.
- **Item 2, no editing of primary-source text.** Kept, and narrowed in words: what may be replaced is the volume's editors' heading and dateline, in display, with a mark and a record (§5). The document's text is offered no control.
- **Item 9, no theming engine.** Kept. Templates stay recipes over a fixed house style. §7's *Page* group is three switches and is a candidate, not part of the core.

It builds on two decisions as made: D4 (one title for the contents row and the heading) and A11 (apparatus as placeable entries, which §3.3 keeps).

---

## 4. Three interfaces

The canvas draws each of these in the same Mac window, on the same collection, so that they can be compared.

### 4.1 The default path: Export

The same sheet on every platform, opened from four places.

- **Template.** The six, the one in force checked. Where the author has edited the collection's settings, *Your settings* leads the list: *based on Full text as printed · 3 changes*. Choosing a template here is choosing it for the collection (§3.3).
- **Format.** PDF, Word and Web page as one control. *More formats* opens BibTeX, RIS and `.fruscollection`. The Zotero row stays as it is.
- **What will print**, in a sentence, as today's summary line gives it.
- **Export PDF.**

The sheet opens on the template in force and on the format this collection last exported as. A new collection starts under *Full text as printed* (Q4), so it exports as a PDF with no choice made. A collection that exists today opens on *Your settings*, which are its fields as they stand.

Where it opens from:

- the editor's *Export…*, as now;
- **the Collections list:** *Export…* in a collection's context menu, on iOS and in the Mac's Manage Collections sheet;
- **the Mac's Collection menu:** *Export Collection…* (⇧⌘E, as now), which works with a collection chosen and the editor's panes closed;
- **Export Again**, beside each of those: the last template and format, with no sheet.

The quotation check (the manuals' *The Excerpt Check*) and the missing-volume and summary-generation waits stay in the sheet as they are. Export Again runs them too, and stops on the sheet when one has something to say.

### 4.2 Option A: templates only

*The simplest thing that could meet the first ask.*

- The editor is the outline and the preview. Collection settings holds the template gallery, the title page and the citation style.
- A document's inspector holds four things: your heading, your dateline, how much text, which notes.
- Section Defaults and the six per-document switches go. A different look is a different template.

**For it:** two surfaces, about a dozen controls in all, nothing to learn. **Against it:** it removes what the app does today (footnotes off for one document, a source note for one section), and it cannot meet *fine-tune any aspect*. It is the right default surface and the wrong only surface.

### 4.3 Option B: the parts inspector

*One inspector, the same on every platform, listing the ten parts.*

- **At its head:** the scope, *This document · This section · Whole collection*, following the selection; then the template, with its changes counted and Reset.
- **Then the ten parts**, one row each: a switch or the current choice, a dot where the scope changes it, and a detail for the parts that have one (the heading's choice and text, the dateline's, which notes, which highlights, the headnote's card).
- **At collection scope, two more groups:** *Around the documents* (title page, introduction, contents list, the five apparatus blocks as five switches, word cloud, Note on the Text, colophon, project stamp, query log) and *Wording* (citation style, labels, the mark).
- **It replaces** Collection settings' composition, the inspector's Export Overrides, Section Defaults and the heading row's *Section body* menu: the 24, 9 and 21 controls of §2.4 become one list of ten rows and two groups.

**For it:** one place, one vocabulary, every part reachable by keyboard and VoiceOver, and it fits an iPhone as a list. **Against it:** it is still a list beside the page, and the author must connect a row called *Dateline* with the line they are looking at.

### 4.4 Option C: point at it

*The preview is where the author chooses.*

- Hovering a part in the preview outlines it. A click or tap opens a small popover on it, with that part's choices and nothing else: for a heading, *The volume's heading · The citation · Your own*, a field, and *Apply to: this document · this section · all documents*.
- The outline stays for structure: order, sections, adding.
- The settings shrink to the template and the collection-wide page.

**For it:** nothing to find. The author never needs to know that a line is called a dateline or where its setting lives, and choosing the scope at the moment of change teaches the cascade in plain words. **Against it:**

- a part that is hidden cannot be pointed at, so a list of parts is needed anyway to bring one back;
- a web view's contents are a poor home for VoiceOver and the keyboard, so every choice would need a second route;
- it is the most new machinery: the page must name its parts, report a tap, and keep its place through a reload (§2.6).

### 4.5 Recommendation

**Option B as the structure, entered the way Option C is, with Option A's gallery as its first row.**

- The **template gallery** is the first thing in the inspector and the first thing in the export sheet. An author who wants a default never goes further (§4.1).
- The **parts list** is the one place every setting lives, at three scopes.
- The **preview points into it:** a tap on a part in the preview selects that document's row in the outline and opens the inspector on that part, at document scope. The reverse holds too: choosing a row brings its document into view, and the preview keeps its place when the page reloads.

That gives Option C's directness for what can be seen and Option B's completeness for what cannot, with one set of controls to build, test and translate. The pointing arrives as its own lane (§8, lane 5), after the inspector works without it.

### 4.6 On each platform

| | Mac | iPad | iPhone |
|---|---|---|---|
| **Layout** | Outline · preview · inspector column, as now, with a toolbar control for the preview | Outline · preview, with the inspector as a sheet, as Configure is now | Outline, with Preview behind the segmented control, as now |
| **Whole collection** | The inspector with nothing selected, or the gear | The gear opens the inspector at collection scope | The *Collection settings* row opens it |
| **A document** | Select its row, or click it in the preview | Tap its row or its Configure pill, or tap it in the preview | Tap its row |
| **A section** | Select its heading | The heading's pill | Tap the heading's pill |
| **Templates** | A grid, three rows of two | The same grid | Rows, each with its line of description, in place of the chips' one-word names |
| **Export** | The sheet; the Collection menu; Manage Collections | The sheet; the list's context menu | The sheet; the list's context menu |

The outline's document row would lead with the author's own heading where there is one (§2.2), with the volume's heading as its second line.

---

## 5. "Marked appropriately"

**What may be replaced, and what it is.** The heading over a FRUS document was written by the volume's editors, and so was its dateline's form. A compiler who replaces either is one editor standing in for another. The reader of the export is owed two things: to see that the words are the compiler's, and to be able to recover what the volume prints.

**Three conventions,** drawn on the canvas with document 475:

| | On the page | In the contents list | The volume's form |
|---|---|---|---|
| **1. Brackets** | **[The Long Telegram]**, and the dateline *[Moscow, 22 February 1946]* | [The Long Telegram] | In the Note on the Text |
| **2. A line beneath** | **The Long Telegram**, then, small: *Printed heading: The Chargé in the Soviet Union (Kennan) to the Secretary of State* | The Long Telegram | On the page |
| **3. A dagger** | **The Long Telegram †** | The Long Telegram † | In the Note on the Text |

- **Brackets are FRUS's own sign** for words an editor supplied, and the reader of a collection drawn from FRUS already reads them so. They need no key, cost no line, and survive every format, plain text and a `.bib` file included.
- **A line beneath** loses nothing from the page and needs no note, at one line a document. It suits a teaching reader, where students should see both.
- **A dagger** is the cleanest page and depends wholly on the note at the back.

**Recommended: brackets, with the Note on the Text.** The second convention is offered as the other choice. A replacement with no mark is not offered, as an AI summary without its line of attribution is not.

**The Note on the Text** is a block the collection generates, as it generates a Bibliography. It says, from what the collection does:

- which headings and datelines are the compiler's, each with what the volume prints: *Document 475 of the 1946 volume VI is headed in that volume "The Chargé in the Soviet Union (Kennan) to the Secretary of State".*
- what is left out throughout or in places: footnotes, source notes, datelines, the text itself where a document is a citation or a summary;
- that summaries were written by Apple Intelligence, and which headnotes the compiler wrote or edited;
- that quoted passages are excerpts, and how they were checked.

It prints at the end, before the colophon, **whenever the collection replaces a heading or a dateline**, and the author may place it anywhere as a block, or add it to a collection that replaces nothing. It makes every other customization in this design a stated one.

**What is marked and what is not.**

- **Marked:** a heading or dateline of the compiler's standing in place of the volume's.
- **Stated in the Note on the Text, and not marked on the page:** a part that is hidden.
- **Neither:** the app's own words (*Contents*, *Research Note*, an apparatus block's title), which are the compiler's apparatus and read as such; and a title that prints above the volume's heading, as today's override does, where both are on the page.

---

## 6. Citation styles

- **One setting for the collection**, in *Wording*: History at State, Chicago, Turabian. It governs every place a citation prints: the reference under a heading or the heading itself, a contents row in *Citation* style, an excerpt's source line, the *See also* line, and the Bibliography's and the Chronology's rows.
- **A collection that exists today keeps history.state.gov style**, so its exports do not move. Q5 asks what a new collection starts with.
- **A short form for lists.** A contents list in *Citation* style repeats the volume's whole title and editors on every row (§2.2). The app's citation parser already reads the short forms scholars write (`CitationParser.swift:23-31`), and the formatters write none. Proposed: each style gains a short form, and the contents list and the *See also* line use it, with the Bibliography carrying the full one.

For document 475, as the three formatters write it and as a short form would:

| Style | The citation |
|---|---|
| History at State | *Foreign Relations of the United States*, 1946, Eastern Europe, The Soviet Union, Volume VI, eds. Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Chicago | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*, edited by Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), Document 475. |
| Turabian | *Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI*. Edited by Rogers P. Churchill and William Slany. Washington, D.C.: Government Printing Office, 1969. Document 475. |
| Short (proposed) | *FRUS*, 1946, vol. VI, doc. 475. |

**What it takes in the kit.**

- `BatchContext.formatter` becomes `any CitationFormatter`, made from the collection's style (`CollectionContentAssembly.swift:797`, `:917`). All three formatters read the volume and the number alone, as `shortCitation`'s note requires of the one (`:1226-1245`).
- The assembly hands every exporter one kind of italics, turning `*…*` into `_…_` where a citation is made, so no exporter learns a second marker (§2.7).
- The Bibliography sorts by volume and number, not by the citation's text (`CollectionGeneratedBlocks.swift:304-333`), so a style changes no order.
- `CitationFormatterTests` pins the three; the short forms would be pinned beside them, and held to the parser by a round trip, as the app's own citations are (`CitationMatchingEngineTests.ownCitationsAreNeverBestGuesses`).

---

## 7. Other authorial capabilities

Candidates, in the order this design would take them. Q8 asks which.

1. **Selected passages as a document's text.** A fourth choice for Text: the passages the author highlighted in the document, in its order, with *[…]* where text is left out, under the document's own heading and dateline, with its source note and notes. It is what a course reader does most: abridge. The highlights, their stored passages and the per-document choice of which already exist (`selectedHighlightIds`); the excerpt check (the manuals' *The Excerpt Check*) would cover them. An older build reads the unknown depth as *Full* (`CollectionBodyDepth.resolve`, `CollectionExporter.swift:307-311`), which prints more and hides nothing.
2. **The collection's own words.** A short table in *Wording*: *Contents*, *Headnote*, *Summary*, *Source*, *Research Note*, *See also*, and the five apparatus titles, each with a field. A course reader's *Research Note* becomes *Commentary* or *Questions for discussion*; a bibliography becomes *Works cited*. One apparatus block may also carry a title of its own, which the entry's unused `text` holds with no new field.
3. **The collection's own numbering.** Documents numbered 1 to *n* in the collection's order, at each heading and in the contents list, with the volume's number left in the reference. The Persons and Thematic indexes could then cite *Documents 3, 7 and 12* of the collection, as a printed reader does, where they now cite each volume's number and its identifier.
4. **Where notes go.** Before the text, as an introduction to a document, or after it, as now.
5. **Save as Template.** An edited look kept under a name for other collections, listed after the six. It needs a home that syncs: Q7.
6. **The page.** Letter or A4; each document on a new page, or run on; page numbers in Word as in the PDF. Three switches, no fonts.
7. **Several formats in one export**, such as the PDF with its `.bib`.
8. **Same settings as…** Copy one document's changes to others, or to its section.

Considered and not proposed: editing a source note's text or a footnote (it is the volume's editors' annotation of the text, and §5's reasoning for a heading does not reach it; hiding it, or adding a note of one's own, covers the need); fonts and colours (§3.6, item 9); a recipe written as text for the author to edit (the `.fruscollection` file already is one, for whoever wants it).

---

## 8. Lanes

Each is one session on the owner's Mac unless it says otherwise. None needs an index version.

| Lane | What | Stored data | Changes exports | Depends on |
|---|---|---|---|---|
| **1. Export from anywhere** | The sheet's template row, applying a template as Collection settings does today; *Export…* in the Collections list and Manage Collections; the format remembered per collection; Export Again | None (the remembered format is the device's) | No | Nothing |
| **2. One plan for three formats** | §3.5: the plan in the kit, and the three exporters drawing it; §2.3's differences of presence, place and wording ended | None | **Yes**, PDF and Word: Word's pins are re-taken with their reason, and the parity suite is taken to the PDF's order | Nothing |
| **3. Style and display** | §3.4's two values; the heading, reference and dateline parts; the mark and the Note on the Text; the citation style and the short forms; templates that switch back; minimal fields in today's inspector, so that it can be used and checked | Two properties: **one CloudKit deploy**; research export 8; two `.fruscollection` keys | Only for a collection that uses them | Lane 2 |
| **4. The parts inspector** | §4.3 on all three platforms, replacing Collection settings' composition, Export Overrides, Section Defaults and *Section body*; the outline row's own heading | None | No | Lane 3 |
| **5. The preview points** | §4.5: a tap selects the part; a row brings its document into view; the page keeps its place | None | No | Lane 4 |
| **6. From §7** | As Q8 decides, each a lane or a part of one | Keys in the two values; *Save as Template* per Q7 | Only where used | Lane 3 |

**What each lane owes, beyond the landing runs the plan of record names.**

- **Lanes 2, 3 and 6 change shared code.** `swift build --target FRUSCoreKit` and `swift test` with the unit target and the Mac build.
  - `CollectionRenderingPinTests` pins the HTML page and the Word package by SHA-256, with the BibTeX and RIS. Lane 2 re-takes Word's with the reason; the HTML's should not move.
  - The PDF has no pin. `CollectionExportParityTests` (#960) holds the three exporters to one inventory of blocks over one fixture, which a source note cut to a line and a contents list cut at a page both pass. Lane 2 takes it to the blocks' order, and to a source note longer than a line, a research note longer than a page and a contents list longer than the cover.
  - Lane 3's defaults must leave every pin where lane 2 put it, which is the proof that an untouched collection does not move.
- **Lane 3 is the CloudKit gate** (CLAUDE.md, *CloudKit schema-deploy gate*): the inventory, `identifiersAwaitingDeploy`, the owner's Development write and Production deploy, and `check_cloudkit_schema.py` before an archive. It also owes the research export's version 8 with its `Fields` cases and fixture, and a line for the web edition's hand-over.
- **Lanes 1, 4 and 5 change strings and screens.** Blocks in `Docs/EditableContent/08-Reading-Research-Collections.md` and the ranges they move; both manuals' chapter 12; the captures that show the editor (`ipad/collections-editor`, `macos/collections`), store frame 07 if its screen changes, and the tour's step 16.
- **The UI suites that hold the editor** are the six in `CollectionEditorTitleTests.swift`, on the devices the runbook's table names. Lane 4 rewrites what several of them walk (Configure, Section Defaults, the inspector's Open Document); each is brought to the new surface in the same change, with its reason, and read first in `UI-Test-Destinations-Runbook.md`.
- **Lane 1 alone could ship ahead of the rest**, as a small release's row: it changes no stored data and no export.

**Order.** 1, 2, 3, 4, 5 is the order of dependence. Lane 1 answers the first ask by itself. Lanes 2 and 3 together make the customization real in the export before any new interface exists, with lane 3's fields as the way to try it. Lane 4 is the largest and is the one that answers *very complicated*.

---

## 9. Decisions for the owner

Each with a recommendation. Nothing in §8 starts before its questions are answered.

- **Q1. The interface.** Option A (templates only), Option B (the parts inspector), Option C (point at it), or **B entered through the preview, with the gallery first (recommended, §4.5)**.
- **Q2. The mark.** **Brackets, with the Note on the Text (recommended)**; a line beneath; a dagger; or the choice of the first two as a collection setting (§5).
- **Q3. Templates.** **The collection records its template, keeps the author's own settings beside it, and a template owns the apparatus it placed (recommended, §3.3)**; or templates stay as L25 left them, one-way, with an Undo while the sheet is open.
- **Q4. What leads a document in the six templates, and what a new collection starts under.** **§3.3's table: the volume's heading with the citation as a reference beneath, in the three that print text; and a new collection starts under *Full text as printed*, whose two apparatus blocks arrive with its first document (recommended)**; or every template keeps the citation and then the volume's heading, a new collection keeps today's unnamed defaults (§2.5), and the new arrangement is the author's to choose. Either way a collection that exists today does not move.
- **Q5. A new collection's citation style.** **The one chosen in Settings ▸ Display (recommended)**, since that is the reader's stated preference and the reader's Copy Citation already follows it; or history.state.gov always. Either way a collection that exists today keeps history.state.gov.
- **Q6. Storage.** **Two text properties and one deploy (recommended, §3.4)**; or a property per setting, each with a deploy of its own.
- **Q7. Where saved templates live,** if Q8 takes them: a new model type, which is a CloudKit record type and a research-export type; **a field of `SyncedPreferences` (recommended as the smaller)**; or the device alone.
- **Q8. Which of §7's eight,** and in what order. **Recommended for the first pass: 1 (selected passages) and 2 (the collection's own words), with 3 (numbering) next.**

And one that is not a question of design: **whether lane 1 goes ahead by itself**, before the answers to the rest.

---

## 10. Files

- **This document.**
- **The canvas:** <https://claude.ai/artifact/VeyxgRtvZQG3noP8fExKci>, seven boards. It is private to the owner's account; its source is not in the repository.
- **Read, at `efd73ec`:**
  - the model: `FRUSExplorer/Models/Collection.swift`;
  - the kit: `FRUSCoreKit/Collections/CollectionExporter.swift`, `CollectionContentAssembly.swift`, `CollectionItemHTMLRenderer.swift`, `DocxCollectionExporter.swift`, `CollectionGeneratedBlocks.swift`, `NativeCollectionFormat.swift`; `FRUSCoreKit/Citation/CitationFormatter.swift`, `CitationParser.swift`; `FRUSCoreKit/TEI/FRUSRenderNode.swift`, `FRUSRenderNodeHTMLSerializer.swift`; `FRUSCoreKit/Export/ResearchDataEnvelope.swift`;
  - the app: `FRUSExplorer/Collections/` (`CollectionEditorView.swift`, `CollectionEntryInspector.swift`, `CollectionEntryRows.swift`, `CollectionCompositionRows.swift`, `MacCollectionManagerView.swift`, `CollectionListView.swift`, `CollectionExportSheet.swift`, `CollectionPreviewView.swift`, `PDFCollectionExporter.swift`, `CollectionExporter+App.swift`);
  - the manuals' chapter 12, and the two earlier designs under `Completed/`.
- **Not read:** `CollectionAddDocumentsSheet.swift`, `CollectionRichTextEditor.swift`, `CollectionPickerSheet.swift` beyond its purpose, and the web edition's repository.
- **Not done:** no build, no test run, no capture. The counts of §2.4 are of the code's controls, not of a running screen, and §2.3's page arithmetic is an estimate.
