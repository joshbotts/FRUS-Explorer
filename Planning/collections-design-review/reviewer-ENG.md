ID: ENG-1
Severity: S1
Claim: Built as §3.5 writes it, a heading that is replaced or hidden takes with it the in-text marker of every footnote anchored in that heading, which from the 1955 volumes on is the document's source note, so Word drops the note and the HTML and PDF print it with no marker in the text.
What a person meets: On any platform the owner gives a document from the 1961–1963 Cuba volume a heading of their own and exports under an existing collection's settings (footnotes on, source note off). The Word file shows no source note: its text is in the package and nothing refers to it. The HTML and the PDF list it under the document with no marker in the text. The Note on the Text says the heading is the compiler's and nothing about the note.
Evidence:
- Record §3.5: "a heading that is replaced or hidden is still walked by each exporter's offset counter and is not drawn".
- `FRUSCoreKit/Search/IndexingPipeline.swift:7520-7521`: "`<head>`-nested `<note type="source">` — the encoding used by every volume from 1955 on". The pinned fixture is encoded so (`FRUSExplorerTests/FRUSCoreKit/CollectionRenderingTests.swift:78`).
- The marker is a child of the heading (`FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:386-387`, `:436-437`) and is drawn only with it: HTML `FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:740-741`, `:876-882`; PDF `FRUSExplorer/Collections/PDFCollectionExporter.swift:1062-1063`, `:1369-1375`; Word `FRUSCoreKit/Collections/DocxCollectionExporter.swift:1124-1126`, `:1584-1585`.
- The note's text prints regardless in HTML (`FRUSRenderNodeHTMLSerializer.swift:364-366`) and PDF (`PDFCollectionExporter.swift:1034-1053`). Word registers every note (`DocxCollectionExporter.swift:1078-1103`) and writes the reference only where the marker is drawn.
- Counted from the public TEI, fetched 2026-11-25 from raw.githubusercontent.com/HistoryAtState/frus: the first `<head>` holds a source note in 361 of 390 documents of `frus1961-63v11` and 263 of 280 of `frus1969-76v17`. In the canvas's `frus1946v06`, 79 of 692 heads hold a note of any kind, which is why no board shows this.
- The source note part is off unless asked for: `FRUSCoreKit/Collections/CollectionExporter.swift:548`.
Refutation: A rule that moves a replaced heading's markers to whatever leads the document, or that names the loss in the Note on the Text. I read §3.5 and §5 for one and found none. That Word shows nothing for a footnote no reference names is from memory, not fetched. NEEDS A RUN: export the pinned telegram with its heading skipped and open the file in Word and in Pages.
Direction: §3.5 should say where a marker anchored in a replaced or hidden heading or dateline goes, the same in all three formats.

ID: ENG-2
Severity: S1
Claim: As §3.4 describes the two values, a build that does not know a key of `styleJSON` or `displayJSON` erases that key on every device the first time it changes any other key of the same value.
What a person meets: A later lane adds the collection's own words as a new key. The owner's Mac has that build and the iPhone the one before. On the Mac they rename *Research Note* to *Commentary*. On the iPhone they change the same collection's citation style, or pick a template in the export sheet. When iCloud brings the iPhone's write, *Commentary* is gone from the Mac, with nothing shown.
Evidence:
- Record §3.4: "each a small object of optional keys that FRUSCoreKit declares, with a decoder that reads a key it does not know as absent"; "a key added later is not a schema change"; "Later: the notes' place, the collection's own numbering, the page". Its stated cost covers only two devices on one build changing different keys before syncing.
- The tree's one JSON object in a synced text property is written this way: `FRUSExplorer/Models/ListOrderPreferences.swift:71-74` (a fixed `Payload`) and `:277-285` (decode, set one member, encode the whole, store).
- §1 says "what a later lane adds needs no further deploy", yet Q7 recommends "a field of `SyncedPreferences`" for saved templates. Each stored property there is an identifier in the gate (`FRUSExplorer/Models/CloudKitSchemaInventory.swift:384-397`; `CLAUDE.md:355`).
Refutation: A rule in §3.4 that a write keeps the keys it did not decode. There is none, and no code yet. Not run.
Direction: Put the write rule in §3.4, with a test that an older decoder's round trip keeps a newer key, before Q6 is answered.

ID: ENG-3
Severity: S2
Claim: In the canvas's own volume the heading is not the body's first block in 690 of 692 documents and the dateline is a child of an opener that also holds the classification marking in 564, so §3.1's parts "top to bottom" are not blocks that an exporter can show, hide, reorder or outline.
What a person meets: On the Mac with Adjust on over document 470, the app's page opens with the source note's marker on a line of its own above the volume's heading, and prints "confidential" and the dateline in one opener block. Board C shows neither. *Your own* for the dateline also replaces "[Received February 5—4:56 p.m.]", which the volume prints inside the same dateline. In 23 of the 692 documents the only dateline is in the closer: the Dateline part finds none, and *Your own* prints a bracketed dateline at the head while the volume's still prints at the foot.
Evidence:
- TEI fetched 2026-11-25: d470 and d475 open `<note rend="inline" type="source">`, then `<head>`, then `<opener><seg rendition="#left">…</seg><dateline …>…<lb/>[Received …]</dateline></opener>`. The counts above are of `frus1946v06`. The dateline is inside `<opener>` in 663 documents.
- The leading note stays a footnote and its marker is emitted in place: `FRUSCoreKit/TEI/FRUSDocumentParser.swift:1719-1727`; `ASTToRenderNodeConverter.swift:436-437`. An opener is one block: `FRUSRenderNodeHTMLSerializer.swift:749-750`. The stored dateline is "the first `<dateline>`, at the top level or inside an `<opener>`": `IndexingPipeline.swift:7340-7358`. The marking beside it: `:7361-7364`.
- Board C draws Heading first and Text as one block: `OptionC.dc.html:84-95`, `:114-125`, `:127-137`. Record §2.2 item 4 says the text "opens with the volume's own heading".
- The order is given two ways. §3.1 and `PartsPhone.dc.html:69-76` put Dateline before Headnote; `OptionB.dc.html:83-94` and `OptionC.dc.html:104-125` draw the headnote above the dateline. Today's HTML prints the headnote between the citation heading and the volume's heading, and *See also* before the notes (`FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:296-319`, `:384-409`), and the pinned page holds a headnote (`CollectionRenderingTests.swift:168`, `:315`). So §8's "the HTML's should not move" needs the plan to carry today's order as well as §3.1's.
Refutation: A volume whose documents open `<head>` then a top-level `<dateline>`. Of three counted, none: the two later volumes open with `<head>` and keep the dateline in the opener (362 of 390, 268 of 280). The corpus was not counted.
Direction: Define each part against the render model (which node, inside what, what rides with it) before lane 2 fixes the plan's shape.

ID: ENG-4
Severity: S2
Claim: After lane 2, Word's contents rows still will not "come from the same label as the other two" once Word updates the field, because the list is a dirty TOC field built from heading styles.
What a person meets: The owner exports the six Kennan documents to Word under *Full text as printed* as Q4 proposes it. Pages and Quick Look show the cached rows. Word rebuilds the list: each row is the paragraph in the Heading 2 style, so six rows reading "The Chargé in the Soviet Union (Kennan) to the Secretary of State" if the volume's heading takes that style, or no document rows if it stays Heading 3. Neither is the PDF's list, and §6's short form cannot appear.
Evidence: `DocxCollectionExporter.swift:1865` ("`w:dirty="true"` causes Word to rebuild on first open"), `:1873-1874` (`TOC \o "1-2" \h \z \u`), `:610-615` (in-document headings "stay out of Word's regenerated contents"), `:690-691` (the leading paragraph is Heading 2), `:1124-1126` (the volume's heading is Heading 3). `FRUSExplorerTests/CollectionTests.swift:5707-5713`. Record §3.5; §2.3 already says "a Word field, with rows cached until Word rebuilds it".
Refutation: A Word contents list that is not a heading-driven field. The record proposes none. What Word does with a dirty field is the code's own statement; not run.
Direction: Lane 2 should choose between a field Word can update and a list that matches the other two.

ID: ENG-5
Severity: S2
Claim: Under form (i) as §4.6 writes it, a person on iPad or iPhone cannot see the part while changing it, because the inspector is a modal sheet over the editor on iPad and a pushed screen on iPhone.
What a person meets: On iPad they tap the heading in the preview and a sheet comes up over the editor. The part's outline, the reload and the kept place all happen behind it. To point at the dateline next they close the sheet and tap again. A row's tap opens the same sheet, so "choosing a row brings its document into view" happens under it. On iPhone the page and the inspector are never on screen together, and §4.6 offers the phone "Tap its row" only, though §4.4 says Adjust was added for a finger.
Evidence: `FRUSExplorer/Collections/CollectionEditorView.swift:863-873` (the sheet; `:868-869` calls it "a form sheet"), `:681-691` (the push), `:738-745` (Outline or Preview, never both). `FRUSExplorer/Collections/CollectionEntryRows.swift:1026` (a row's tap opens the settings). Record §4.6, rows *Layout* and *A document*; §4.5 "That gives Option C's directness". A trailing `.inspector` on iPad is the trap already paid for: `CLAUDE.md:290`; `Planning/Plan-Of-Record-2026-11-15.md` lines 856 and 860. No board draws Adjust on a phone or an iPad, and board C names the parts in a 104-point gutter (`OptionC.dc.html:19`, `:80`).
Refutation: A presentation that leaves the page in view and takes touches behind it. The record asks for the sheet "as Configure is now", a plain sheet. NEEDS A RUN: on iPad Pro 13-inch and iPad mini with Configure up, how much of the preview shows beside the sheet; and on iPhone whether the preview's `.task(id:)` runs under the pushed inspector (the editor's note at `:389-391` says a covered, pushed view runs no `onChange`).
Direction: Say per platform where the controls sit so the page stays in view, or say that pointing is the Mac's alone.

ID: ENG-6
Severity: S2
Claim: Form (ii) anchors a native popover to a rectangle of a page that is discarded and reloaded about a second after each change made in that popover, and it builds the second set of controls §4.5 chose form (i) to avoid.
What a person meets: On iPad they tap the heading, pick *Your own* and type. Each letter is saved. A second after a pause the page reloads from the top and the popover's arrow points at whatever now lies under the old rectangle. On iPhone the popover is a sheet unless adapted, or else a popover holding a text field over a 390-point page with the keyboard up. A tap on the next part first closes the popover.
Evidence: `FRUSExplorer/Collections/CollectionPreviewView.swift:434-437` (one-second settle), `:882-887` (`loadHTMLString` of the whole page), `:66-67` (no scroll keeping, no patching). A field writes as it is typed: `FRUSExplorer/Collections/CollectionEntryInspector.swift:393-395`. The app's one control anchored to a rectangle the page reports is the reader's selection bar: retired on iPhone and iPad (`FRUSExplorer/DocumentView/FloatingSelectionBar.swift:120-123`), and on the Mac dismissed when the page moves because "a viewport-anchored floating bar goes stale" (`FRUSCoreKit/TEI/ReaderAnnotationScripts.swift:304-307`, `:321-327`). Board C's popover repeats the inspector's choices with its own scope control, Reset and Done (`OptionC.dc.html:186-225`); record §4.5: "one set of controls to build, test and translate". Under iOS 27 the app's dialogs became popovers on the iPhone, each with a dismissal rule its suite had to learn (`CLAUDE.md:82`, `:87`, `:98`). The board gives the popover a 264-point column beside a 600-point page in a 1,280-point window (`OptionC.dc.html:82`, `:184`); the Mac window opens at 1,180 with a 340-to-460-point outline (`FRUSExplorer/App/FRUSExplorerApp.swift:1592`; `FRUSExplorer/Collections/MacCollectionManagerView.swift:917`).
Refutation: NEEDS A RUN on iPhone 17 and iPad Pro 13-inch under iOS 27.0 and on the Mac: change a presented popover's anchor rectangle and reload the web view under it; see whether it follows, stays or closes, and whether a tap behind it reaches the page. The adaptation and dismissal statements are from memory, not fetched.
Direction: If (ii) is chosen, the page must stop reloading whole first, and the popover should hold the inspector's own rows.

ID: ENG-7
Severity: S2
Claim: The page a person points at holds the first 20 documents of a static collection and, in a smart collection, documents that have no entry, so past document 20 a row has nothing to bring into view and in a smart collection a tap has no row to select and nowhere to store *this document*.
What a person meets: On the Mac, in a 40-document reader, the owner clicks row 30 and the preview does not move: document 30 is not in the page. *Render All* puts it there, and from then every settled change parses again each document the cache cannot hold. In a smart collection Adjust outlines every heading, Contents lists no documents, and *Your own* for one heading has no entry to write to.
Evidence: the cap at `CollectionPreviewView.swift:153`, applied `:481-487`, `:544-556`; its reason `:146-152` ("the textbook LRU worst case, missing (and re-parsing) every document every refresh"). A miss parses the volume file from its start (`FRUSExplorer/TEI/DocumentASTCache.swift:19-21`, capacity `:47`; `FRUSExplorer/Collections/CollectionContentResolver.swift:649-663`). Smart collections: `FRUSExplorer/Collections/CollectionOutline+App.swift:201-205`, `:219-223`; `FRUSCoreKit/Collections/CollectionContentAssembly.swift:731-734`, `:743` ("smart collections keep collection-level behavior by construction"). Record §3.4 keeps a document's display on `CollectionEntry.displayJSON`, and names smart collections only in §2.1 and §2.4. A document may be in a collection twice (`CollectionEditorView.swift:86-88`) and both copies share one element id (`CollectionItemHTMLRenderer.swift:784-788`).
Refutation: A lane-5 line that lifts the cap under Adjust and patches the page per document, and a rule for smart collections. §8's lane 5 reads "a tap selects the part; a row brings its document into view; the page keeps its place" and no more.
Direction: Say what Adjust and the row-to-page link do past the cap and in a smart collection, and size lane 5 with per-document patching in it.

ID: ENG-8
Severity: S2
Claim: Lane 1 does change stored data and exports: its template row overwrites the collection's eight synced composition fields and inserts apparatus entries with no way back, from a sheet reached without opening the collection; and lane 3's remedy keeps one set of the author's settings, which the next collection-wide change under a tried template replaces.
What a person meets: On iPhone with lane 1 shipped alone, they long-press a collection, choose *Export…* and tap *Citations with your notes* to see what it is. The collection now prints citations only and has gained a Bibliography and a Thematic Index. *Your settings* cannot be chosen back, since nothing recorded them. After lane 3 they try a template and flip one switch for all documents: the three changes that were *Your settings* are replaced by a version with one.
Evidence: record §8, lane 1: "applying a template as Collection settings does today", "Stored data: None", "Changes exports: No", and "it changes no stored data and no export". Record §2.5: "One tap, at once, with no undo"; "Apparatus only accumulates". `FRUSExplorer/Collections/CollectionExporter+App.swift:29-39` (the eight fields). `CollectionEditorView.swift:1929-1943` and `MacCollectionManagerView.swift:1866-1871`: the blocks are inserted through the open editor's own outline, which a sheet opened from the list does not have. Record §4.1: "Choosing a template here is choosing it for the collection" and "A collection that exists today opens on *Your settings*". Record §3.4: "the template the author's own settings began from" (one set); §3.3: "Changing a setting while a template is in force makes the collection's own version of it".
Refutation: A lane-1 sheet that holds the choice and writes nothing, which §4.1 rules out; or more than one kept set in §3.4.
Direction: Keep the template row out of the export sheet until the collection can keep what a template replaces, and say whether a second edit keeps the first set.

ID: ENG-9
Severity: S2
Claim: §8's "What each lane owes" leaves out at least five things in the tree that the lanes break, bypass or do not reach.
What a person meets: On iPhone they swipe away a document whose only change is a dateline of their own: no question is asked and it goes from every device. On iPad or Mac a heading typed in the inspector does not show in the preview until something else changes. On the Mac, Add to Collection ▸ New Collection still opens the old composition form.
Evidence:
- The question before a row is deleted reads a hand-kept list of fields (`CollectionEntryRows.swift:357-375`), and an apparatus block "goes at once" (`:292-294`, `:344-345`). Nothing there would read `displayJSON`.
- The preview's refresh list hashes no `titleOverride` today (`CollectionPreviewView.swift:211-266`), and the preview builds its options by hand (`:521-531`), where §3.4 says `CollectionExportOptions(composing:)` "is already the one place". NEEDS A RUN: on the Mac with the preview on, type a Title override and wait five seconds.
- A fourth Mac settings surface: `CollectionEditorView.swift:481-510` (`macBody`, with the composition section and no preview), opened from `FRUSExplorer/Collections/CollectionPickerSheet.swift:323-325`. Record §2.4 counts three Mac places and §4.3 does not name it.
- `CollectionTests.swift:5644-5653` pins two source lines of the export sheet, which lane 1 rewrites; the export runs inside that view (`FRUSExplorer/Collections/CollectionExportSheet.swift:447` on), which Export Again "with no sheet" must leave.
- Lane 3's two properties go into `FRUSExplorer/Models/Collection.swift` (`:30`, `:394`), above all 14 ranged EditableContent blocks that cite that file (lines 915 to 1078). §8 names the ranges for lanes 1, 4 and 5 only (`CLAUDE.md:431`).
Refutation: A line of §8 that names any of these. I re-read §8 against each and found none.
Direction: Add each to its lane's row.

ID: ENG-10
Severity: S3
Claim: The short form §6 proposes names two volumes at once for at least six year-and-volume pairs and has no volume number to print for 96 of the manifest's 553 volumes, so it cannot be "held to the parser by a round trip" as written.
What a person meets: A reader of an exported contents list sees "*FRUS*, 1945, vol. I, doc. 12." and cannot tell the Potsdam volume from the General: United Nations volume.
Evidence: `FRUSExplorer/Resources/manifest.json`: `frus1945Berlinv01` and `frus1945v01`, both subseries 1945 and both "Volume I"; the same for volume II, and for 1918 (Russia; Supplement 1) and 1919 (Paris Peace Conference) volumes I and II. 96 ids carry no volume number, from `frus1861` to `frus1945Malta` and `frus1952-54Guat`. Record §6, table row "Short (proposed)"; `Citations.dc.html:61-66`.
Refutation: A short form that carries the series' name where it is needed. The record's example and board give the year and volume only.
Direction: Write the short form's rule over the whole manifest before pinning it.

Attacked and held
- §3.5's premise holds: the heading and dateline count in highlight offsets (`FRUSCoreKit/TEI/FRUSRenderNode.swift:666-672`, `:827-833`), so removing the node would move stored highlights.
- A tap can be reported and classified with no change to the exported HTML: the page already carries `section#doc-…`, `h2.doc-heading`, `p.dateline` and `section.footnotes-section` (`CollectionItemHTMLRenderer.swift:297`; `FRUSRenderNodeHTMLSerializer.swift:741`, `:744`, `:701`), and preview-only switches that leave the export's bytes alone have precedent (`CollectionItemHTMLRenderer.swift:120-146`, `:688`).
- On the Mac, form (i) keeps the page beside the controls: the entry inspector is a trailing `.inspector` next to the preview (`MacCollectionManagerView.swift:1039-1049`), and the Mac never meets F8's narrowing (plan of record, line 856).
- No index version is owed: `body_hash` is taken over the conversion (`IndexingPipeline.swift:7329-7338`), and nothing proposed changes the parse or the converter.
- The `.fruscollection` claim holds: `usesV2Features` is where §3.4 says, and a title override already forces a v2 file (`FRUSCoreKit/Collections/NativeCollectionFormat.swift:615-639`).

Not read
- `OptionA.dc.html`, and most of `Marks.dc.html` and `Citations.dc.html`.
- Both manuals; `Planning/UI-Test-Destinations-Runbook.md`; `Planning/UI-UX-Adversarial-Review-2026-11-15.md`; the two earlier Collections designs under `Planning/Completed/`.
- `CollectionRichTextEditor.swift`, `CollectionAddDocumentsSheet.swift`, `CollectionGeneratedBlocks.swift`, `CitationFormatter.swift`; the PDF exporter outside lines 560 to 1380; the web edition's repository.
- Nothing was built or run. Three TEI volumes were fetched and counted; the rest of the corpus was not.