# Adversarial review of the Collections design's recommended hybrid — 2026-11-25

**Status: LIVE, 2026-11-25.** The review the owner asked for the same day ("Adversarially review the hybrid C option"), of `Collections-Customization-Design-2026-11-25.md` as it stood at `617b36b`: its recommended hybrid (§4.5), which is the parts inspector entered from the preview through the Adjust switch, with the template gallery first. Both forms of the preview's tap were reviewed: opening the inspector on a part, and opening a popover on the page. Read against `v2` at `efd73ec`. Nothing in the app or its tests changed.

**The design was revised afterwards, on the owner's word.** This review is of its first form, which is in history at `aad7636`, and the section numbers below are that form's. The second form's §11 lists each finding here with where it is answered, and its §12 the checks still owed. No one has reviewed the second form.

**The verdict in one line:** the hybrid does not stand as written. No finding was refuted, and the design's central claims about marks, datelines, the ten parts, templates and simplicity each fail on evidence in the tree or in the volumes.

---

## 0. What it found

Five reviewers returned **50 findings**. Three skeptics then tried to refute each against the code, the record and the public TEI. **None was refuted outright**; one half of one finding was (A11Y-7's size minimums). After duplicates were merged the count stands at:

| | Distinct findings | Of them, needing a run to settle |
|---|---|---|
| **S1 or S2** | **17** | 2 (the CloudKit import, G17; the popover over a reloading page, inside G13), and the severity of a third (G7, in Word) |
| **S3** | **12** | 2 |

- The reviewers rated seven findings S1. The skeptics kept one at S1 (ENG-2, the stored values) and re-rated six to S2, among them DATA-1, which is ENG-2's own finding as the other skeptic judged it. Most came down because the same thing happens in the app today or because what is lost can be made again.
- Sixteen of the fifty were re-rated down. Four of the ten accessibility findings went to S3, chiefly because they were defects of the session's sketches and not of the design as its text states it.
- The skeptics also listed **19 statements in the design record that are false or contradict each other** (§4). Six are about the app as it ships and have been corrected in the record; the rest are claims of the proposal, which this review supersedes.

**What the findings say, in seven sentences.**

1. **Brackets cannot be the mark.** The volumes print datelines of their own wholly in brackets, and their own method statement uses brackets for the editors' additions (G9).
2. **A dateline is the document's text with the editors' additions, not the editors' words,** and replacing it whole takes the hour of dispatch and the time of receipt off the page (G8).
3. **The ten parts are not blocks.** From 1955 a document's source note hangs off its heading; the dateline sits in an opener beside the classification marking; the source note is also one of the footnotes (G7).
4. **Templates as designed still lose work.** A template tapped in the export sheet rewrites the collection at the tap, one kept copy of the author's settings is not a way back, and lane 1 would ship the tap with no way back at all (G2).
5. **The interface is not simpler by the record's own way of counting:** at least 34 controls at collection scope against today's 24 (G5), under a scope switch that is a mode (G4).
6. **Pointing works on the Mac alone.** On iPad the inspector is a sheet over the page pointed at; on iPhone the page and the inspector are never on screen together (G13).
7. **Whole kinds of collection are unaddressed:** a smart collection (G3), a collection that already has title overrides (G6), and a library on two builds at once (G1, G17).

---

## 1. Method

It follows `UI-UX-Adversarial-Review-2026-11-15.md`, at a smaller size.

**Five reviewers**, each with one scope and the same brief (`collections-design-review/reviewer-brief.md`): interaction and comprehension (INT), engineering feasibility and regressions (ENG), stored data and sync (DATA), accessibility (A11Y), and editorial and scholarly integrity (EDI). None was given the session's reasoning for the design, only the record, the boards' source and the code. Each returned at most ten findings, strongest first, with what would refute each and whether that was checked.

**The severity scale**, adapted to a design:
- **S1:** built as written, it fails one of the owner's asks, loses or corrupts a person's work, states something false or unmarked to a reader of an export, or cannot be built as described.
- **S2:** a first-time user misled or stuck on a common task; a claim of the record false or materially overstated; a clear accessibility or HIG rule broken on a primary surface; a cost left out that would change a lane's size.
- **S3:** real but secondary.

**Three skeptics** (`skeptic-brief.md`), given the findings: A took INT and DATA, B took ENG and EDI, C took A11Y. Verdicts: CONFIRMED, CONFIRMED and RE-RATED, PLAUSIBLE (with the check owed), REFUTED, NOT NEW, DUPLICATE.

**Sources.** The code at `efd73ec`; the design record; the seven boards' source; both manuals; the plan of record; the three earlier Collections designs. From the public TEI (`HistoryAtState/frus`), eight volumes fetched and counted by XML parse: `frus1946v06`, `frus1950v06`, `frus1952-54v08`, `frus1955-57v24`, `frus1961-63v11`, `frus1964-68v14`, `frus1969-76v17`, `frus1977-80v06`. Six HIG pages, five WCAG criteria and three NVDA source files, fetched the same day.

**What no one could do.** No app was built or run. Word was not opened. VoiceOver's and JAWS's defaults, the Chicago and Turabian manuals and history.state.gov's page on citing the series could not be fetched.

**The reports themselves** are in `Planning/collections-design-review/`, as returned: five reviewers' and three skeptics'. Every `file:line` this document gives is one a skeptic re-read.

---

## 2. The findings, merged

Each names the findings it merges, the skeptics' verdict, and the direction the session would take. A direction is not a decision.

### G1 — A build that does not know a key erases it (DATA-1, ENG-2)

*CONFIRMED by both skeptics; S1 by one, S2 by the other.*

- **What a person meets.** A later lane adds a key to a collection's style, such as its own labels. The Mac has that build and the iPhone the one before. A label is renamed on the Mac; on the iPhone the citation style is changed. The iPhone decodes the value into the keys it knows and writes the whole back, and the Mac's labels are gone, with nothing shown.
- **Evidence.** The design's §3.4 gives a rule for reading ("reads a key it does not know as absent") and none for writing. The tree's one JSON object in a synced text property is written by decoding a fixed type and encoding it whole (`ListOrderPreferences.swift:71-74`, `:275-288`), and no codec in the tree keeps a key it does not know. The app's rule elsewhere runs the other way: an entry kind a newer build wrote is never written back (`Collection.swift:684-691`).
- **Where the skeptics differ.** S1: the loss is silent and reaches every device. S2: it needs two builds on one account after a second build adds a key, and what goes is settings and a few typed words.
- **Direction.** If the two-value storage is kept: a write changes only the keys a build knows and keeps the rest as stored, each value carries a version an older build will not overwrite, and a test holds an older decoder's round trip to a newer value.

### G2 — A template chosen in the export sheet rewrites the collection at the tap (INT-1, DATA-2, DATA-6, ENG-8)

*CONFIRMED, S2.*

- **What a person meets.** From the Collections list: Export…, tap down the templates to read the sentence under each, Close. Nothing was exported, and the collection now follows the last template tapped, on every device. After lane 1 alone nothing brings the old settings back. After lane 3 one copy of "Your settings" is kept, and the next collection-wide change under a tried template replaces it. A template's block the author deleted comes back on the return trip, because its removal is recorded nowhere.
- **Evidence.** §4.1: "Choosing a template here is choosing it for the collection". §3.4 stores one set of the author's settings. Lane 1: "applying a template as Collection settings does today", which is one tap, eight fields and inserted blocks with no undo (`CollectionExporter+App.swift:29-39`; `CollectionEditorView.swift:1935-1943`). Today's sheet writes nothing to a collection (`CollectionExportSheet.swift:19-22`).
- **Direction.** A template chosen in the export sheet applies to that export and writes nothing. The assembly already resolves a collection from values (`CollectionContentAssembly` over `CollectionExport`), so an export under another template is a resolve of a changed copy. Making a template the collection's own is an act in the editor, and it asks first when it would replace settings the author made.

### G3 — A smart collection has no place for any of it (DATA-3, A11Y-6, ENG-7, INT-8)

*CONFIRMED, S2.*

- **What a person meets.** In a collection linked to a saved search the preview shows the search's documents, Adjust would outline their headings, and a tap has no row to select and no entry to store a heading in. Create Static Snapshot, the one way to get entries, copies eight named fields and would leave the style behind.
- **Evidence.** A smart collection's entries are "synthesized from search results and carry no overrides" (`CollectionContentAssembly.swift:181-182`, `:731-756`). The design names smart collections only in §2. The snapshot copies fields by name (`SmartCollectionSnapshot.swift:112-134`).
- **Direction.** A smart collection takes collection scope only; a tap on one of its documents opens that scope; the snapshot carries the collection's style.

### G4 — The scope is a mode (INT-2, A11Y-2)

*CONFIRMED, S2.*

- **What a person meets.** With document 470 selected they switch to *Whole collection* and turn footnotes off, click 473 to check it, and the scope is back at *This document*, so the next switch meant for the collection lands on 473 alone. On the iPhone board nothing but the lit segment says which scope a switch writes to, and the screen's title still reads *Document 470*. At a wider scope a row cannot say that some documents override it.
- **Evidence.** §3.2 rule 2: the scope "follows what is selected". The cascade is not three layers: sections nest three deep and a value walks its ancestors (`CollectionOutline.swift:275-282`).
- **Direction.** The scope is what is selected and nothing else: a document's settings on a document, a section's on its heading, the collection's from the gear, as the Mac works today. No control changes the scope by itself, and a row at a wider scope says how many documents differ.

### G5 — By the record's own rule the control count goes up (INT-3)

*CONFIRMED, S2.*

- **Evidence.** §2.4 counts today's controls one by one: 24, 9 and 21. §4.3 then says they "become one list of ten rows and two groups". Counted the same way, the collection's scope holds the scope control, six templates, Reset, ten parts, thirteen items "around the documents" and three of "wording": 34, or 47 with the title page's fields and the labels counted singly. A document holds 15 against 9. Only a heading's sheet on iPhone and iPad shrinks, from 21.
- **Direction.** What the design reduces is places and vocabulary, not controls, and the record should say that. If fewer controls in view is the aim, the default surface is the gallery alone, with everything else one step further in.

### G6 — A title the author already typed has no rule (INT-5, DATA-5, EDI-2, A11Y-5)

*CONFIRMED, S2.*

- **What a person meets.** Twelve documents retitled under 1.0, in a field captioned "Overrides the document title in the table of contents and the export heading". At the first template chosen, each title either becomes a bracketed replacement of the volume's heading, with a Note on the Text they did not ask for, or stops printing. The record does not say which. Every board's heading control has three choices where §3.1 has four, and the missing one is the one every existing collection is in.
- **Also true today.** At Summary or None depth, and in every contents row, an override prints with neither the volume's heading nor the citation beside it and no mark; the document's address under the heading is all that identifies it (`CollectionExporter.swift:747-763`). So the design's "always marked" and "nothing there needs a mark" are false of those places.
- **Direction.** See §7: a heading of the author's is printed above the volume's and never in its place, which is what an override does today, so no stored title changes meaning.

### G7 — The ten parts are not blocks (ENG-1, ENG-3, EDI-6, EDI-7)

*CONFIRMED, S2; S1 if a run shows Word leaving a note out.*

- **The heading carries the source note's call.** From 1955 the source note is a footnote on the heading: the document's first head holds one in 361 of 390 documents of `frus1961-63v11`, 263 of 280 of `frus1969-76v17` and 323 of 374 of `frus1955-57v24`. The call is the heading node's child (`ASTToRenderNodeConverter.swift:386-387`, `:436-437`) and is drawn only with it. A heading "not drawn", as §3.5 has it, leaves the note with no call in HTML and PDF and no reference in Word.
- **The heading is not the first block.** Before 1955 the source note leads the document: in `frus1946v06` the first child is the inline source note in 690 of 692 documents, and its marker prints on a line above the heading.
- **The dateline is inside an opener**, beside the classification marking, in 663 of those 692; 23 have a dateline only in the closer. An opener is drawn as one block (`FRUSRenderNodeHTMLSerializer.swift:749-750`).
- **The collection does not read such a dateline at all.** The assembly reads a head and a dateline among the top-level nodes only (`CollectionContentAssembly.swift:1468-1482`), and a test pins the result: "the dateline, inside an opener, prints with the body rather than in the header" (`CollectionResolutionTests.swift:450-452`). So the Note on the Text would have no printed dateline to quote.
- **The source note is also a footnote.** Every footnote body prints when footnotes are on, with no test of its type, and the *Source:* line is printed apart from it, from the index. The Source-note switch decides only the second copy.
- **Direction.** Before lane 2 fixes the plan's shape, define each part against the render model: which node, inside what, and what rides with it. Give lane 3 one reading of the printed head and dateline (opener, closer, an editorial note's wrapper, calls, a volume not on the device).

### G8 — A dateline is not the editors' to replace (EDI-4)

*CONFIRMED, S2.*

- **Evidence.** The volumes' own Editorial Methodology (`frus1977-80v06`): "A heading has been supplied by the editors for each document"; the documents "are reproduced as exactly as possible"; additions are bracketed. Document 475's dateline sits in the document's own opener and carries the editors' "[Received February 22—3:52 p.m.]" in brackets. The design's §3.1 calls the dateline "the volume's editors' words … not the document's words"; its §5 claims only "its dateline's form".
- **What a person meets.** They type *Moscow, 22 February 1946*; the hour of dispatch and the time of receipt leave the page. The popover that takes the typed line also offers *Apply to: all documents*. The Chronology goes on printing the stored date.
- **Direction.** The printed dateline stays on the page. A date line of the author's may stand above it, for one document at a time, marked in words.

### G9 — Brackets are the volumes' own sign for something else (EDI-1, A11Y-3)

*CONFIRMED, S2.*

- **Evidence.** 24 of 852 datelines of `frus1950v06` and 18 of 671 of `frus1952-54v08` are wholly bracketed by the volume: "[Washington, undated.]", "[Washington?, October 1, 1953.]". `frus1946v06` prints "[Received" in 395 datelines and the signatures "[Kennan]" and "[Byrnes]". Heads the volumes print include "[Editorial Note]" and "[Untitled]" (`DocumentDisplayTitle.swift:36-37`). In the series a bracketed place or date means the editors supplied it.
- **So** a reader who knows the series takes "[Moscow, 22 February 1946]" to say the telegram bore no date. The design's "They need no key" is false, and its own board prints a key that is false of the volume's brackets on the same page (`Marks.dc.html:40`, against `:26`).
- **Read aloud:** NVDA at its default does not speak brackets (its `symbols.dic:80-81`), so a listener hears the compiler's heading as the document's. VoiceOver's default could not be established.
- **Direction.** The mark is words, not punctuation: the design's second convention, a line beneath. It collides with nothing the volumes print and it is spoken.

### G10 — A collection that only hides prints no Note on the Text (EDI-3)

*CONFIRMED, S2.* §5 prints the Note "whenever the collection replaces a heading or a dateline" and also says a hidden part is "Stated in the Note on the Text". Both cannot hold. A shipped template turns footnotes off, and the calls stay in the text in all three formats (`PDFCollectionExporter.swift:717-718`). **Direction:** the Note prints whenever a part the volume prints is left out, and each entry names the document as its page names it.

### G11 — The export's own sources block would be false (EDI-5)

*CONFIRMED, S2.* With the colophon on, every rich format prints, for a collection of documents: "Read from the text and editorial apparatus of the FRUS volumes, and from no other source", and where there is prose of the author's, "The app never mixes them into the published text" (`ProvenanceSource.swift:141-142`, `:151-152`). The set is derived from the kinds of item (`CollectionExporter.swift:1313-1333`), and the design gives the compiler's headings no source. **Direction:** derive a source for the compiler's words from the plan, and reword the two sentences so that they stay true.

### G12 — Word's contents list is a field Word rebuilds (ENG-4, A11Y-4)

*CONFIRMED, S2.* The list is `TOC \o "1-2" \h \z \u`, written dirty, which "causes Word to rebuild on first open" (`DocxCollectionExporter.swift:1865`, `:1873-1874`); the app's rows are its cached result. After an update the rows are the Heading 2 paragraphs, whatever label the plan carries. Under Q4's recommended default the eight Kennan telegrams give eight identical rows. §3.5's "Word's contents rows come from the same label as the other two" does not follow. **Direction:** lane 2 chooses between a field Word can update and a list that matches the other two.

### G13 — Pointing works on the Mac alone (ENG-5, ENG-6, INT-7, INT-9, A11Y-7)

*CONFIRMED, S2; the popover half PLAUSIBLE.*

- **iPad:** a document's settings are a sheet over both columns (`CollectionEditorView.swift:863-873`), so the outline, the reload and the kept place all happen under it.
- **iPhone:** the outline and the preview are never on screen together (`:738-745`), and §4.6 gives the phone "Tap its row" alone, though §4.4 says Adjust was added for a finger.
- **The names have no margin.** The exported page is 780 points wide at most; at the Collections window's default 1,180 points, with the outline and the inspector at their minimums, the preview is 500.
- **Past document 20 a row has nothing to bring into view** (`CollectionPreviewView.swift:153`), and a document entered twice shares one element id.
- **The popover form** anchors a native popover to a rectangle of a page that is discarded and reloaded a second after each change made in it. The app's one control anchored to a web page's rectangle was retired on iPhone and iPad (`FloatingSelectionBar.swift:120-123`).
- **Direction.** Say that pointing is the Mac's, where the inspector is a column beside the page. On iPad it waits for a presentation that leaves the page in view, which is the `.inspector` trap F8 already cost. Names go on each part's own outline.

### G14 — The quick export would print its back matter after the first document (INT-6)

*CONFIRMED, S2.* A back-matter block goes to the end when inserted (`CollectionEditorView.swift:1922-1925`), and every document added afterwards takes one past the highest position (`CollectionAddDocumentsSheet.swift:154`; `CollectionDocumentAppend.swift:101-103`). Q4 has a new collection's two blocks "arrive with its first document". **This is today's behaviour after any template** (§6). **Direction:** a document arrives ahead of trailing apparatus.

### G15 — The short form names more than one volume (EDI-8, ENG-10)

*CONFIRMED, S2.* Year, volume and document is shared by 133 of the manifest's 553 volumes, and by 48 with a part added; 99 titles have no volume number. *FRUS, 1945, vol. I* is both the Potsdam volume and the general one. The app met this in #1388 (`VolumeLabels.swift:60-66`). One form is shown for three styles, so the style chosen would not show in the list the owner asked about. **Direction:** write the short form's rule over the whole manifest, per style, before promising a round trip.

### G16 — No lane carries an accessibility check (A11Y-8)

*CONFIRMED, S2.* §8 names pins, the CloudKit gate, strings, captures and six UI suites, none of which listens to VoiceOver. The plan's comparable rows carried a VoiceOver case, hit areas with a suite, and fit runs at AX3 (`Plan-Of-Record-2026-11-15.md:277-278`, `:286`, `:306`, `:473`). The record states no focus or speech for the tap. **Direction:** add the focus rule, the announcement and their suites to lanes 4 and 5, and size the lanes with them.

### G17 — A device updated later may hold nothing for the new values (DATA-7)

*PLAUSIBLE; S2 unsettled; not particular to this design.* The mirror fetches from a stored change token (`ModelContainer+FRUS.swift:478-482`). If it does not fetch again a record it imported before its model had the field, a device updated from 1861 holds nothing for a style set elsewhere, and its first write replaces the whole of it. Nothing readable settles it, and it would be as true of a property per setting. **Check owed:** §8.

---

## 3. Secondary findings

| ID | S3 | Verdict |
|---|---|---|
| INT-4 | Two of the hybrid's arrangements were built and withdrawn before (an inspector headed by a segmented switch; content choices in the export sheet), and the record names neither. The skeptic found the recorded cause of each absent here | CONFIRMED |
| INT-8 (half) | Three cells of "ten parts at three scopes" have nothing to store them: See also for the collection, a headnote for a section, a dateline for the collection. The summary prompt is on no row | CONFIRMED |
| INT-10 | *Not printed* sits under a footnote reading "Not printed."; *Reference* beside the app's cross-references; *Heading* beside section headings; "4 notes" for footnotes beside "2 notes" for research notes | CONFIRMED |
| DATA-4 | Build 1861 and an import of an older file change what "the template in force" describes without updating it | CONFIRMED |
| DATA-8 | The static snapshot is not among what carries the values; a version-8 export is refused whole by a version-7 importer; no test walks the copy paths | CONFIRMED |
| DATA-9 | "No further deploy" is contradicted by Q7's own recommendation; one-record preferences lose a saved template | CONFIRMED |
| DATA-10 | What Export Again does where no format is remembered is unsaid | CONFIRMED |
| ENG-9 | Five things §8 leaves out, among them the question before a row is deleted, which reads a hand-kept list of fields | CONFIRMED |
| EDI-9 | *Source:* is a word the volumes print from 1961, and the design lets it be replaced with no mark | CONFIRMED |
| EDI-10 | The app's Chicago is a note's shape and its Turabian a bibliography's, and a collection has both places | PLAUSIBLE |
| A11Y-1 | The boards hide the change dot from assistive technology and give no part its own Reset; the record's text asks for more than they draw | CONFIRMED |
| A11Y-9, -10 | The PDF has no tags, title or links (true of 1861); the export sheet's pinned buttons at AX5 on an iPhone SE | CONFIRMED; PLAUSIBLE |

---

## 4. Errors in the design record

**About the app as it ships. Each is corrected in the record, marked with the finding that named it.**

1. §2.2: a *Header & Dateline* contents list of the eight Kennan telegrams "differs only in its dates". The rows are identical and carry no date (G7).
2. §2.2: the text "opens with the volume's own heading". Before 1955 it opens with the source note's marker, and the dateline is drawn inside the opener's block.
3. §2.7: the citation preference "syncs". It is mirrored only while a device-local switch is on, and that switch is off by default (`SettingsSyncCoordinator.swift:12-14`; `SettingsView.swift:93`).
4. §2.4: "The Mac has three places". A fourth is the New Collection form opened from Add to Collection (`CollectionEditorView.swift:481-510`).
5. The header: "the two earlier Collections designs". There are three, and the one not read, `Collections-Rework-Scope.md`, is where the export sheet was made format and destination.
6. §3.4: "`CollectionExportOptions(composing:)` is already the one place". The preview builds its own by hand (`CollectionPreviewView.swift:521-531`).

**Claims of the proposal, which this review supersedes** (the record's text is left as reviewed): "always marked" and "nothing there needs a mark" (G6); brackets "need no key" (G9); the dateline as "the volume's editors' words" (G8); "what a later lane adds needs no further deploy" (DATA-9); lane 1 "changes no stored data and no export" (G2); "Word's contents rows come from the same label" (G12); the 24, 9 and 21 controls "become one list of ten rows and two groups" (G5); short forms "held to the parser by a round trip" (G15); "A shipped template's recipe does not change afterwards", beside a table that changes three; "That is today's cascade", which a headnote and See also do not follow; the Note's two rules for when it prints (G10); the source note as a block apart from the footnotes (G7); §4.4's three heading choices against §3.1's four.

---

## 5. Found sound

Each was attacked and held.

- **§2's counts of today's controls** (24, 9, 21) hold on a recount, and so do §2.1 and §2.5: the sheet changes nothing, nothing exports from a list, and a template is one tap that only adds blocks.
- **One Production deploy, and a later key is no CloudKit schema change.** `listOrderJSON` already has that shape.
- **No index version.** Nothing proposed changes the parse or the converter.
- **The highlight-offset premise of §3.5.** The heading and dateline count in the flat text, so removing the node would move stored highlights.
- **`.fruscollection` keeps `minimumReaderVersion` 1:** a reader that ignores the keys prints more, never less.
- **A compiler's title reaches no citation record.** The BibTeX, RIS and Zotero items are built from the volume's head.
- **AI text keeps its label.** The attribution is none of the ten parts, so no switch or wording removes it.
- **A citation style changes no order,** and two styles cannot meet inside one export.
- **A tap can be classified with no change to the exported HTML.** The page already carries `section#doc-…`, `h2.doc-heading`, `p.dateline` and `section.footnotes-section`.
- **On the Mac the inspector stays beside the page.**
- **The boards' text contrast and the iPhone boards' touch targets,** as drawn.

---

## 6. Defects of the app as it ships, met on the way

None is this design's doing. Each was confirmed by a skeptic's re-read of the code; none was seen in a running app, and none is filed.

1. **A *Header & Dateline* contents list prints no dateline for most documents,** since the collection reads a dateline only where it is the document's own top-level block (G7). A test pins this as intended.
2. **With Footnotes and Source note both on, the source note is printed twice** in volumes from 1955: once among the footnotes and once as *Source:*. *Full text as printed* and *Everything included* turn both on (`CollectionExporter.swift:226-229`).
3. **After a template is applied, documents added later land after its back-matter blocks** (G14).
4. **A footnote call in a heading is written "[1]" into the heading the collection reads** (`CollectionContentAssembly.swift:1522`), so a 1977–1980 head in a *Header & Dateline* row would read "…to Soviet General Secretary Brezhnev[1]".
5. **Duplicate does not copy *Stamp active project* or *Append the query log*,** though its comment says every setting is copied (`Collection.swift:794-795`, `:809-814`).
6. **A title override typed in the inspector may not reach the preview until something else changes:** the preview's refresh list hashes no `titleOverride` (`CollectionPreviewView.swift:211-266`).
7. **A title override at Summary or None depth, and in every contents row, prints unmarked and alone** but for the document's address (G6).

---

## 7. What the recommendation becomes

The session's own reading of the findings. Nothing here is decided, and the design record is not rewritten: it carries a notice that points here.

**Three changes do most of the work.**

1. **Nothing the volume prints is replaced; the author's words are added above it, in words.** A heading of the author's prints above the volume's heading, which stays beneath it in small type as *Printed heading: …*, with its footnote calls. A date line of the author's prints above the printed dateline. This is G9's mark in words, G8's printed line kept, G7's calls kept where they are, and G6's stored titles unchanged in meaning, since an override prints above the volume's heading today. It also drops the heading's *hidden* and *replaced* states, which were the source of most of G7.
2. **A template chosen at export is for that export.** It writes nothing (G2), so lane 1 is free of stored data in fact, and the question of one kept copy does not arise there. A template becomes the collection's own in the editor.
3. **The scope is the selection.** No switch (G4): a document's settings on a document, a section's on its heading, the collection's from the gear. That is also where today's Mac already is.

**What follows from them.**

- **The parts are defined against the render model before lane 2,** with the source note and the footnotes made disjoint (G7), and the plan carries a part's role as well as its text, so that Word's contents list and a reader's heading list can use it (G12).
- **Pointing is the Mac's** (G13), and the record says so. iPad and iPhone get the inspector by the row.
- **A smart collection takes collection scope only** (G3).
- **The Note on the Text prints whenever anything the volume prints is left out or anything is added** (G10), and the sources block tells the truth about it (G11).
- **The storage question is open again** (G1, G17): the two-value scheme needs a write rule and a version, and both schemes need the two-device run of §8 first.
- **The short form is not promised** until it is specified over the manifest (G15).
- **The record stops claiming fewer controls** (G5) and says what the gallery-first default leaves in view.

**Questions of the design's §9 that this reopens:** Q1 (the interface, now without a scope switch and with pointing on the Mac alone), Q2 (the mark: words beneath, recommended in place of brackets), Q3 (templates: chosen at export for that export), Q4 (a new collection's blocks, given G14), Q6 (storage, after the run). And one it adds: **whether a dateline of the author's is wanted at all**, now that the printed one stays.

---

## 8. Checks owed, each needing a device or an app

- **G17:** two devices on one iCloud account. Keep B on 1861. On A, with a build that has the new property, set it on a collection. Let B import; rename the collection on B and read the value on A. Update B; read the value on B before A touches the collection again; then change the collection's name on B and read the value on A.
- **G7:** export the pinned telegram with its heading not drawn and open the file in Word and in Pages: does the note with no reference show?
- **G12:** a `.docx` with the volume's heading leading, opened in Word, its field updated.
- **§6, item 2:** export `frus1961-63v11` d1 under *Full text as printed* and count the source note.
- **§6, item 6:** on the Mac with the preview on, type a title override and wait five seconds.
- **G13:** on iPad Pro 13-inch and iPad mini with Configure up, how much of the preview shows beside the sheet; and a popover on a rectangle the page reports, with the page reloaded under it.
- **G9:** `[The Long Telegram]` as a heading, read by VoiceOver on iPhone and Mac at its default punctuation.

---

## 9. Files

- **This document.**
- `Planning/collections-design-review/`: `reviewer-brief.md` and `skeptic-brief.md`; the five reviewers' reports (`reviewer-INT.md`, `-ENG.md`, `-DATA.md`, `-A11Y.md`, `-EDI.md`); the three skeptics' (`skeptic-A-INT-DATA.md`, `skeptic-B-ENG-EDI.md`, `skeptic-C-A11Y.md`). They are as returned, and they name files under the session's scratch folder, which is gone: the boards' source there is what the canvas holds.
- **The design it reviews:** `Planning/Collections-Customization-Design-2026-11-25.md` in its first form, at `aad7636`, which opens with a notice of this review and carries §4's six corrections. The file now holds the second form.
- **Not done:** no build, test or run. The session wrote §2's directions and §7; no reviewer or skeptic was asked to judge them.
