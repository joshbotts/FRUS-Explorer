# R6 — the device pass of 1.0 (1823)

*Written 2026-11-18 by R6's session, for row R6 of the plan of record (`Plan-Of-Record-2026-11-15.md`, §1), from the R6 bullet, R2c's pass (`Completed/Plan-Of-Record-2026-10-21.md` §4), the review's device-only checks (`UI-UX-Adversarial-Review-2026-11-15.md` §6), the log entries of L11 to R5, both TestFlight notes and sitting T2's four findings (the plan's §5). The owner tests the devices; the session records each result here by ID, then in the R6 bullet and the session log.*

## The pass as set up

- **Devices**, from the owner's answers of 2026-11-18: an iPhone on iOS 27.2, an iPad on iPadOS 27.2 and the Mac on macOS 27.2. Each already runs 1.0 (1823) from TestFlight (`build-54`), all three are signed in to one Apple Account, and a printer reaches the Mac. There is no small iPhone and no iPad mini.
- **Each library has already made its one re-index, 74 → 75,** at its first launch of 1823. Every device ran 1.0 (1812) before, and none dates from 1.0 (1787) or earlier. So the pass reads what the re-index left (PH1–PH3, PD1–PD3, MC1–MC3) rather than timing it. The 71 → 75 path stands on R5's simulator census (727 s, under iOS 26.5).
- **An export from 1.0 (1823) stands in for one from 1.0 (1812),** on the owner's word ("Use an 1823 export"). Both builds write format version 7. Since `build-53`, L24 changed how the exporter is built (each record now an initialiser the import shares) but not the records it writes, and the envelope's change is doc comments alone (`git diff build-53 75364cec`).
- **The FRUS Explorer Light file is the owner's own export** from the web edition.
- **Not checked, by the answers:**
  - IPH-9, onboarding at AX3 and AX5 on an SE: there is no small iPhone, and onboarding opens again only through Reset or Fix iCloud Sync, neither of which belongs in a pass on a real library. L20's onboarding caption (HCD-1) goes unchecked for the same reason.
  - #1835: there is no iPad mini.
  - A file's synced settings taken at once with Sync Settings Across Devices on, and the report saying they wait with it off: the owner chose "Skip it". (X4 records it if the web file happens to carry newer settings.)
  - The 71 → 75 re-index on a device: no such library.
- **Not checkable on these devices:**
  - T2's first finding under iOS 27.0 itself: no device runs 27.0, so PD15 checks 27.2.
  - #1892's banner at two and three hops: a library that holds every citing volume draws no banner.

## How to report

Give each ID one of:
- **pass**;
- **fail**, with what you saw;
- **not checked**, with why.

An item marked *See* records what the device shows: an observation for §5, not a pass or a fail.

Tags:
- `iPhone only` and `iPad only`: the behaviour belongs to that idiom.
- `iCloud`: needs the other devices on the same account.
- `printer`, `Voice Control`.
- `optional`: worth doing only if time allows.

## The cheapest order

1. PH1–PH3, PD1–PD3 and MC1–MC3, each device's re-index: about two minutes a device.
2. X1–X2 on the Mac: the export, then the scratch note's deletion. iCloud carries the deletion while you go on.
3. PH4–PH5 on the iPhone: start a queue, lock the iPhone and leave it.
4. The iPad, from PD4, with X3–X4.
5. The Mac, from MC4, with the printer, and X6.
6. The iPhone again: PH5's result, then from PH6, and X5.
7. X7, the cleanup.

---

## iPhone (iOS 27.2) — PH

### The re-index (decisions 117 to 119 and 131; R2c's pass)

| ID | Check | Result |
|---|---|---|
| PH1 | **Settings ▸ Library ▸ Volumes & Storage ▸ Advanced:** Index Health reads *Format version 75*, nothing pending. The storage figures: roughly 3.3 GB of XML and 3 to 3.5 GB of index, though R5's freshly re-indexed library read 3.88 GB, 0.7 GB of it free pages that Compact Database gives back. | **Pass** (2026-11-18) |
| PH2 | **Research tab:** your notes, highlights, tags and collections are all there, in the same numbers as on the iPad and the Mac. | **Pass** (2026-11-18) |
| PH3 | *From memory:* at the iPhone's first launch of 1823, did the re-index run (the banner, the Live Activity) and finish, about how long did it take, and did anything look wrong? The same for its update to 1812, the re-index to 74 that R2c's pass still owes. "Not watched" is an answer. | **Pass** (2026-11-18): the re-index ran and finished in about 5–6 minutes, against R5's 904 s for an 1812 library on a simulator iPad under load |

### Downloads, and a queue left in the background (start these first)

| ID | Check | Result |
|---|---|---|
| PH4 | **Volumes & Storage ▸ Download from GitHub…:** queue six volumes not on the iPhone. If it holds all 553, first remove six small ones you hold no notes in, then queue those. Active Downloads shows **Cancel All**, which asks *Stop downloading 6 volumes?* **Keep Downloading** keeps the queue. Cancel All again, then **Cancel All Downloads**: the queue empties, and volumes already on the iPhone stay. (L20, HCD-2) | |
| PH5 | Queue the six again, go to the Home Screen and lock the iPhone. *See:* the Lock Screen's Live Activity shows one volume's progress or *N of M* (IPH-7). Leave it 10 to 15 minutes, on power if you can. Expected: when you come back the queue is done, or finishes with no tap. (L11–L14) | |
| PH6 | `iPhone only` *See:* with the app open as a queue's last volume finishes indexing, does an end-of-queue card show? If it does, does **Search →** search one volume or all of them, and how long does the card stay? (IPH-8) | |
| PH7 | `optional` Start one volume's download, then turn on Airplane Mode. *See:* does its page show *The download failed: no connection.* with **Retry**, or wait? Turn Airplane Mode off; the download finishes. (L20, HCD-3) | |

### What changed since 1812: R5's Mac walk, on the iPhone

| ID | Check | Result |
|---|---|---|
| PH8 | `frus1952-54v02p1` d41 ▸ rail ▸ **Sources:** *S/S – NSC files, lot 63 D 351* resolves to RG 59, A1 1586E, cited in 98 volumes. (#1894) | |
| PH9 | **Browse ▸ Analysis Tools ▸ Cross-Reference Analytics,** Most-Referenced: each name sits beside its own bar, and none is cut at the top (decision 141). A bar opens its document (R5's opened No. 1383, the Berlin protocol), and its **Graph** draws at two hops and on Timeline. (#1891, L16) | |
| PH10 | **Corpus Analytics,** *Berlin* over 1961–1963: **View N documents ↗** opens Search on *Berlin* over those years with the same N (R5's Mac read 1,470). Add *Cuba* and *Laos*: the lines are solid, dashed and dotted, each pattern beside its term in the legend. (#1896; L21, IPS-3) | |
| PH11 | **Person Analytics:** each ranking name beside its own bar, none cut (decision 141); the co-mention network and Chronology draw. (#1899) | |
| PH12 | **About the Series ▸ Geography,** Most-covered countries: each name beside its own bar, none cut. (decision 141; #1899) | |
| PH13 | **Archival Analytics:** each ranking name beside its own bar, at the chart's leading edge, none cut (decision 141); the network draws. (#1901) | |
| PH14 | **Word Cloud** of one scope (R5 used Soviet Union 1945–1950) in the All terms, People and Topics lenses, with **Distinctive** sizing on Topics. People's Distinctive saying it has no corpus reference is as built. (#1900) | |
| PH15 | **Kissinger's person sheet:** lifespan 1923–2023; Career, *Secretary of State, 1973-09-22 – 1977-01-20*; Subjects with the data's caption; View on VIAF and View on Wikidata. A scope bar offers **Subjects**. (#1906; L15) | |
| PH16 | **The reader's links,** at Small and at Medium text: `frus1961-63v06`'s index page numbers are each a box of their own, easy to tap; its contents line *Kennedy-Khrushchev Exchanges* opens page 1. In `frus1873p1v1`'s index, the *See* reference *De Long* reaches De Long's entry, and *JAY, JOHN* its own. In `frus1964-68v12` d238, *Martin* in *Bill Martin* opens his card. (#1898, #1902) | |
| PH17 | **T2's fourth finding,** on every platform: in `frus1961-63v06`'s Contents, tap a front-matter link (`#pg_III` …) and an Index link (`#pg_315`). R5 found that on the Mac they do nothing. *See:* what the iPhone does. | |
| PH18 | `frus1977-80v12` ▸ **Sources:** every CIA job row has an Archival Neighbors count, and Job 09–00438R's opens its two documents. (L22, #1929) | |

### Each row's own surface

| ID | Check | Result |
|---|---|---|
| PH19 | `iPhone only` **Browse ▸ Subjects:** the header *491 subjects across the whole series…* with the caption. Pull the list down: the *Search subjects* field appears from the navigation bar's drawer; search *Berlin*. *See:* would a reader find the field there, and does the large title read plainly? Then a volume page: its Top subjects, with the caption under them. (L15; R5's finding) | |
| PH20 | **Search** *Berlin*, then **Filters:** change Years and tap **Done**, and the search runs again under the new chip (IPS-1). **Facets:** select two rows in Years, and a bar at the foot reads *Years: 2 included*, with **Clear** and **Apply**; Apply narrows the results and adds a chip (IPH-3). A tap just beside Filter, and one just beside More, each opens its control (IPH-5). (L18) | |
| PH21 | **A new note** on any document: type a line and swipe the sheet down, and it asks *Discard Changes?* **Keep Editing** keeps the words; **Discard Changes** closes it with nothing saved. (L19, IPA-2) | |
| PH22 | **Add to Collection** from the reader, into *R6 scratch* (made on the iPad in PD22): it says *Added to “R6 scratch”*. Add the same document again: the hollow check, *Already here*. (L19, A11Y-3) | |
| PH23 | `iPhone only` *R6 scratch* ▸ **Collection settings:** six template chips in a row that scrolls. Tap each in turn: only that chip is selected, and the settings row names it. Then **Export ▸ PDF**, and the PDF opens. (L25) | |
| PH24 | In *R6 scratch*, add a note block with a line of text and swipe it: *Delete Note Block?* **Cancel** keeps it (MAC-2). A document entry's settings (the drill-in) have **Open Document** at the head: it opens the document, and Back returns to the settings (IPA-4). (L19) | |
| PH25 | **Research tab,** a list of documents: each row has a *Document N* line above its head. (L21, MAC-5) | |
| PH26 | **Settings ▸ System ▸ About ▸ Legal:** **Privacy Policy** and **Support** open in the in-app browser. On the policy page, the footer's *Source code* (GitHub) opens in Safari, and the sheet stays on the policy. (L17, ASR-2, ASR-3) | |
| PH27 | `frus1902app1` d31: long-press its map where it holds no text ▸ **Save to Photos.** The Photos prompt comes up; after Allow the image is saved and the app keeps running. (L17, ASR-1) | |
| PH28 | **Long-press a word** in a document. *See:* does the edit menu with the app's items (the four colours, Excerpt, Look Up in NARA) come up on the first press? The iOS 27.0 simulator raised it only when the selection landed before the press lifted (#1943). | |
| PH29 | `Voice Control`, here or on the iPad: turn on **Settings ▸ Accessibility ▸ Voice Control**. On Browse's first screen, say *Tap Archives*, *Tap Administrations*, *Tap Editors* and *Tap Clusters*: each opens its level. (L21, A11Y-5) | |
| PH30 | `optional` Turn off Apple Intelligence in Settings; it may remove its model until the model downloads again. The rail's Summary and **Settings ▸ Summarization** should then say it is turned off and where to turn it on. (L20, HCD-5) | |

---

## iPad (iPadOS 27.2) — PD

### The re-index

| ID | Check | Result |
|---|---|---|
| PD1 | **Settings ▸ Library ▸ Volumes & Storage ▸ Advanced:** Index Health reads *Format version 75*, nothing pending; the storage figures, as in PH1. | **Pass** (2026-11-18) |
| PD2 | **Research tab:** your notes, highlights, tags and collections are all there, in the same numbers as on the iPhone and the Mac. | **Pass** (2026-11-18) |
| PD3 | *From memory:* the iPad's re-index at its first launch of 1823, and at its update to 1812 (R2c's pass), as in PH3. | **Pass** (2026-11-18): the re-index ran and finished in about 7–10 minutes. Finding **F1** seen during it: see *Findings*, below, and row R6a |

### What changed since 1812: R5's Mac walk, on the iPad

| ID | Check | Result |
|---|---|---|
| PD4 | `frus1952-54v02p1` d41 ▸ rail ▸ **Sources:** the lot resolves to RG 59, A1 1586E, cited in 98 volumes. (#1894, as PH8) | **Pass** (2026-11-18) |
| PD5 | **Cross-Reference Analytics,** Most-Referenced: each name beside its own bar, none cut (decision 141). A bar opens its document; its Graph draws at two hops and on Timeline. (#1891, L16) | **Pass** (2026-11-18) |
| PD6 | **Corpus Analytics,** *Berlin* over 1961–1963: **View N documents ↗** opens Search with the same N. With *Cuba* and *Laos*: solid, dashed and dotted lines, each in the legend. (#1896; L21, IPS-3) | **Pass** (2026-11-18) |
| PD7 | **Person Analytics:** each ranking name beside its own bar, none cut; the co-mention network and Chronology draw. (decision 141; #1899) | **Pass** (2026-11-18), but the co-mention network, zoomed in, draws outside its window, over the window's own header and the main window behind it: finding **F5**, below |
| PD8 | **About the Series ▸ Geography,** Most-covered countries: each name beside its own bar, none cut. (decision 141) | **Pass** (2026-11-18) |
| PD9 | **Archival Analytics:** each ranking name beside its own bar, none cut; the network draws. (decision 141; #1901) | **Pass** (2026-11-18) |
| PD10 | **Word Cloud** in the All terms, People and Topics lenses, with Distinctive sizing on Topics. (#1900) | **Pass** (2026-11-18) |
| PD11 | **Kissinger's person sheet:** lifespan, Career, Subjects with the caption, VIAF and Wikidata. (#1906; L15) | **Pass** (2026-11-18) |
| PD12 | **The reader's links,** as in PH16: v06's index and contents, *De Long*, *JAY, JOHN* and *Bill Martin*. (#1898, #1902) | **Fail, in two parts** (2026-11-18): v06's contents line *Kennedy-Khrushchev Exchanges* opened a document list, not page 1, and *See … De Long* jumped to the beginning of the index, not to De Long's entry. Finding **F6**, below. *JAY, JOHN*, *Bill Martin* and the index's page-number boxes were not reported |
| PD13 | **T2's fourth finding:** `frus1961-63v06`'s Contents, a front-matter link and an Index link. *See:* what the iPad does. | **Seen** (2026-11-18): the contents line *Kennedy-Khrushchev Exchanges* opened document 1 this time, where in PD12 the same line had opened a document list, so F6's first part does not happen every time. A page link in the index opened the document holding the term or person. The Contents' links to the front matter (`#pg_III` …) and to the Index (`#pg_315`), which T2 found doing nothing on the Mac, were not reported |
| PD14 | `frus1977-80v12` ▸ **Sources:** every CIA job row has its Archival Neighbors count, and Job 09–00438R's opens its two documents. (L22, #1929) | |

### T2's findings, and each row's own surface

| ID | Check | Result |
|---|---|---|
| PD15 | **T2's first finding:** `frus1946v06` d475, the Long Telegram ▸ rail ▸ **Related.** The Related Documents window opens and draws. The iOS 27.0 simulator's render server aborted here; under 27.2 it did not. | |
| PD16 | `iPad only` **T2's second finding:** in Browse ▸ Archives ▸ the **Collections** lens, search *Bohlen*. *See:* does the tab sidebar's toggle, at the top, keep its icon? Clear the search and show the sidebar again. T2 saw the icon blank once, until a relaunch. | |
| PD17 | **Subjects** (L15): the rail's **Subjects** with the caption; Search ▸ Filters ▸ **By Subject**, with the caption; Facets ▸ Subjects; Related's *Shared subjects*; and a volume page's Top subjects, with the caption under them. | |
| PD18 | **Search** on the iPad: Filters' **Done** runs the search again, and Facets' foot bar reads *Years: 2 included* with **Apply**. (L18, as PH20) | |
| PD19 | `iPad only` **A new note:** type a line, then tap beside the sheet. Nothing happens, and the words stay. Swipe the sheet down: *Discard Changes?* (L19, IPA-2) | |
| PD20 | `iPad only` **Research ▸ All Notes:** delete a scratch note you made for it. The app does not crash; this is the fix in the notes' *Fixed since 1.0 (1812)* line. (L19) | |
| PD21 | `iPad only` **The rail at a narrow width:** open a document with the rail on, then put FRUS Explorer in Split View or a narrow window. The rail's toggle raises a sheet. Widen the window: the column is back, with the toggle on. A document opened at full width afterwards still has its rail. (L19, IPA-6) | |
| PD22 | `iPad only` Make the collection *R6 scratch* here if it is not there yet, and add a document to it from the reader; it syncs to the other two devices. Its **⚙ Collection settings:** six template cards in three rows of two, every name and subtitle whole. Each tap selects only that card. (L25) | |
| PD23 | `iPad only` A document entry in *R6 scratch* ▸ **Configure ▸ Open Document:** the sheet closes and the document opens. (L19, IPA-4) | |
| PD24 | `frus1961-63v04` d6 ▸ rail ▸ **Graph:** it opens on Timeline, with its picker enabled and a brush under the axis. Rotate the iPad, and it is still Timeline. (L16, #1914) | |
| PD25 | **Research tab,** a list of documents: each row has its *Document N* line. (L21, MAC-5) | |

---

## Mac (macOS 27.2) — MC

| ID | Check | Result |
|---|---|---|
| MC1 | **Settings ▸ Library ▸ Volumes & Storage:** Index Health reads *Format version 75*, nothing pending. | **Pass** (2026-11-18) |
| MC2 | **The Research window:** your notes, highlights, tags and collections are all there, in the same numbers as on the iPhone and the iPad. | **Pass** (2026-11-18) |
| MC3 | *From memory:* the Mac's re-index at its first launch of 1823, and at its update to 1812 (R2c's pass). R5 timed the owner's Mac library, copied into the check copy, at 1,001 s. | **Pass** (2026-11-18): about 3 minutes. The session read the installed app's index read-only afterwards: 553 volumes, every one with its file record (#1909), and 321,749 documents, R5's census figures; installed version 75, last written at 07:27 Eastern |
| MC4 | **Settings ▸ System ▸ Data & Recovery:** under Export Research Database…, *The copy will carry index version 75.* **Import from JSON…** sits under Export as JSON. (L22, #1910; L24) | |
| MC5 | `printer` Open Console (Applications ▸ Utilities), start streaming and search *sandbox*. In FRUS Explorer, open a document and print it to the printer with **File ▸ Print**. It prints, and Console shows no sandbox *deny* naming FRUS Explorer. (L17, ASR-4: the check copy is unsandboxed and could not make it) | **Pass** (2026-11-18): it printed. The session read the Mac's system log read-only (`log show`). `FRUS Explorer[24232]` started sandboxed at 19:18:30 Eastern (*AppSandbox request successful*). At 19:18:55 its print operation connected to `com.apple.printtool.agent` and `com.apple.PrintKit.PrinterTool`, which opened a session for `bottsywattsy.FRUS-Explorer`. No sandbox *deny* from that process appears in the two hours searched |
| MC6 | **A document in the main window:** the title bar shows its head, and the toolbar's centre the volume and number (*Eastern Europe, The Soviet Union · 1946 v6 · Doc 475* for `frus1946v06` d475). **⌘N** and another document: the Window menu tells the two apart. (L21, MAC-1) | **Pass** (2026-11-18), but the document's head in the title bar is almost always cut short: finding **F2**, below |
| MC7 | **File ▸ New ▸ New Window,** with nothing open in it: the grey hint, with **Search** and **Browse the Corpus** buttons, each bringing its window forward. (L21, MAC-6) | **Pass** (2026-11-18) |
| MC8 | **The Search window** (⌥⌘F): at its default size every tool is in the title bar, with no »; a window you have resized before keeps its size. Search *Berlin*: matched words are bold black on a yellow wash. `optional`: in Dark Mode, a selected row's matched words stay black. (L21, MAC-3; L18, A11Y-1) | **Pass** (2026-11-18) |
| MC9 | **Facets** in the Search window: select two rows in Years, and the foot bar reads *Years: 2 included*, **Clear**, **Apply**. Apply runs one search, with a chip. (L18, IPH-3) | |
| MC10 | **T2's third finding, filed by L21 as #1946:** open the Research window soon after launch. *See:* do the rows read *Document 475* over their heads, or ids (*d475*) until the sidebar's selection changes? | |
| MC11 | **A new note window:** type a line. **Discard** asks *Discard Changes?*, and so do **Esc** and the close button. **Save** saves the note and closes the window. **Delete** asks *Delete Note?* and closes it. (L19, IPA-2) | |
| MC12 | **Collections** (⇧⌘K), *R6 scratch* ▸ **⚙:** six cards in three rows of two, names and subtitles whole, and each click makes only that card active. A note block's trash asks *Delete Note Block?* **Add to Collection** from a document's research panel says *Already here* for a collection that holds it. (L25; L19, MAC-2, A11Y-3) | |
| MC13 | **Export *R6 scratch*** as PDF and as Word: both open. (TestFlight's What to Test 3) | |
| MC14 | **The four charts under macOS 27.2,** in the installed build: Analytics ▸ Cross-Reference, Person and Archival Analytics, and About the Series ▸ Geography. Each name sits beside its own bar, none cut. R5 saw this only in the check copy. (decision 141) | |
| MC15 | **T2's fourth finding:** in `frus1961-63v06`'s Contents, click a front-matter link and an Index link. *See:* whether they still do nothing in the installed build. **And PD12's two links, the Mac's side of F6:** the contents line *Kennedy-Khrushchev Exchanges* (R5's walk found it opening page 1), and in `frus1873p1v1`'s index *See … De Long* (Mac check 27 found it reaching De Long's entry). | |
| MC16 | **Help ▸ Privacy Policy** and **FRUS Explorer Support** open in Safari; About ▸ Legal's two rows open in the in-app browser. (L17, ASR-2) | |
| MC17 | `optional` **Volumes & Storage ▸ Download from GitHub…** a few volumes: the hub's line *N volumes in the download queue*, with **Cancel All**, which asks first. (L20, HCD-2) | |
| MC18 | `optional`, with the NARA key: **Source Explorer** on FRUS 1955–57, Volume II, d1 ▸ the lot lookup. If NARA's API answers, it finds series 2839192; if not, it shows an error, not *No matching records found*. (N1, #1908) | |

---

## Across the devices: Import from JSON (L24, decision 140) — X

Each platform reads both files. One device writes each file, and iCloud carries what it wrote to the other two.

| ID | Check | Result |
|---|---|---|
| X1 | `Mac` Add a note, *R6 import test*, to any document. **Settings ▸ System ▸ Data & Recovery ▸ Export as JSON** to iCloud Drive: this is the stand-in for 1812's export. Then **Import from JSON…** that file: *0 to add, 0 to replace, and N already here*, and *…importing it would change nothing*, with **Import** dimmed. Cancel. | **Pass** (2026-11-18), but Export as JSON opened only a share menu, with no way to save the file to a folder: the owner shared it to Mail and saved it from the draft. That is finding **F3**, below |
| X2 | `Mac` Delete *R6 import test*, and wait until the iPad's All Notes no longer lists it. | **Pass** (2026-11-18), but only after the iPad's app was force-quit and relaunched: finding **F4**, below |
| X3 | `iPad` `iCloud` **Import from JSON…** the Mac's file (Files ▸ iCloud Drive). The report shows Notes *1 to add*, and the rest *already here*: anything deleted since the export also shows as *to add*, and a record the iPad held older may show as *to replace*. The footer says a record deleted since the file was made comes back. **Import:** *Added 1…*. The note is back on the iPad, and within a few minutes on the iPhone and the Mac. | **Pass** (2026-11-18). The note came back on the iPad, but on the Mac it reappeared only after the app was restarted: F4, below, on the Mac too |
| X4 | `iPad` `iCloud` **Import from JSON…** your FRUS Explorer Light export. *Since the Mac imported it first (X6), this is the read-back.* First check that the tagged document, its note and its highlight have reached the iPad through iCloud. Then the report reads **Made by FRUS Explorer Light** and *…importing it would change nothing*, with **Import** dimmed. | **Pass** (2026-11-18): the records the Mac imported had reached the iPad through iCloud, and the file then changed nothing |
| X5 | `iPhone` Import each file again: each reads *…importing it would change nothing*, since both arrived through iCloud. | |
| X6 | `Mac` Import the FRUS Explorer Light file: *…importing it would change nothing*. | **Pass** (2026-11-18), in the other order: the Mac was the first device to import the file, so it wrote it. The file held one document tagged, with a note and a highlight, and the Mac imported all of them. X4, on the iPad, becomes the read-back |
| X7 | **Cleanup,** on any one device: delete *R6 import test*, *R6 scratch* and the other scratch notes and collections. They leave all three devices. | |

---

## Findings

| Finding | Seen at | What the owner saw | Placed |
|---|---|---|---|
| **F1** | PD3, during the iPad's re-index to 75 at its first launch of 1823 | **On Browse, two-pane:** the indexing banner hung across both columns about a third of the way up the window. Documents 57–58 of `frus1977-80v24`'s *Argentina* were behind it, 59–60 showed below it, and below it the sidebar was empty ([the screenshot](R6-Device-Pass-2026-11-18-PD3-banner.webp)). **In the reader:** a blank band between the document's text and the banner, gone once the Research rail was opened. | **Row R6a, before R7,** on the owner's word: "make this one issue for the pre-R7 session" |
| **F2** | MC6 | **On the Mac, the main window's title, the document's head, is almost always cut short.** L21's walk met the same thing at the window's default 1,200 pt: AppKit gives the title about 140 pt before it moves a toolbar item into ». The toolbar's centre names the volume and number whole, and the Window menu and the centre's tooltip name the document. Not a crash, a loss of work or a store check. | **The first update after 1.0,** on the owner's word ("First update"): among §3's candidates |
| **F3** | X1 | **On the Mac, Export as JSON opens only a share menu, with no way to save the file to a folder.** The owner shared the file to Mail and saved it from the draft. `ResearchDataExportView.swift` sends all three of Data & Recovery's file exports through `ShareLink`, on both platforms: Export as JSON, Export Notes as Markdown and Export Query Log. iOS's share sheet has Save to Files; a Mac's share menu has no save destination. In the same file, only Export Research Database… uses a save panel (`NSSavePanel`). 1.0 (1812) was the same (`build-53`), so this is not a regression, but 1823's Import from JSON makes the file one to keep and carry. Not a crash, a loss of work or a store check. | **Row R6a, before R7,** on the owner's word ("Before R7, in R6a"): R6a's bullet has its brief |
| **F4** | X2, X3 | **All Notes kept a note's old state until the app relaunched.** On the iPad (X2), it listed a note deleted on the Mac; on the Mac (X3), a note the iPad's import brought back showed only after a restart. Read from the code: `ResearchView` keeps the notes snapshot it hands to All Notes in step with a live `@Query` of the notes (`.onChange(of: allNotes.count)` and `.onChange(of: allNotes.first?.lastModified)`), so an iCloud import refreshes it. But `AllNotesScreen` (`FRUSExplorer/Research/AllNotesScreen.swift`) fetches a snapshot of its own in `.task` when it appears, and draws that one first (`current = localSnapshot ?? snapshot`). The parent's refreshes are never seen while it is on screen, although its doc comment says the local copy should take over only "once this sheet has deleted something". That `.task` came with #1281 on 2026-09-12. A stale row is safe to tap: it finds no note and refreshes. The screen the owner watched on the Mac is not recorded; if it was All Notes, the cause is the same line. 1.0 (1812) was the same (`build-53`), so this is not a regression. Not a crash, a loss of work or a store check. | **Row R6a, before R7.** First placed in the first update ("First update"), then moved on the owner's word ("Move to R6a") once its cause was found to be one override. R6a's bullet has its brief |
| **F5** | PD7 | **A network graph zoomed in draws outside its own frame.** On the iPad, under iPadOS 27.2 in Windowed Apps, Person Analytics' co-mention network, zoomed into Kissinger's neighbours, drew its nodes and names over its window's own header (*Trends*, *Network*, the scope and focus lines) and past the window's edges, over the main window behind it ([the screenshot](R6-Device-Pass-2026-11-18-PD7-graph-overflow.webp)). Read from the code: four network graphs zoom and pan their canvas with `.scaleEffect` and `.offset`, and none clips it to its frame: `PersonCoMentionGraphView.swift:824`, `CrossReferenceGraphView.swift:443`, `VolumeConnectionGraphView.swift:613` and `ArchivalNetworkView.swift:326`. The fix may need to keep a zoomed node's tap area off the window's own controls as well. Not a crash, a loss of work or a store check. | **Row R6a, before R7,** on the owner's word ("Before R7, in R6a"): R6a's bullet has its brief |
| **F6** | PD12 | **Two of the reader's links went somewhere other than where the Mac sent them.** On the iPad, `frus1961-63v06`'s contents line *Kennedy-Khrushchev Exchanges* opened a document list (the volume's page in Browse), where R5's walk saw it open page 1 on the Mac. In `frus1873p1v1`'s index, *See … De Long* jumped to the beginning of the index, where Mac check 27 (13 November) saw it reach De Long's entry. Read from the code, the iOS and Mac hosts handle both identically: `resolvePageReference` and `revealIndexEntry` in `DocumentView` and `MacDocumentView`, and the web view's `revealIndexEntry(on:)` with `IndexEntryLanding`. A document list is `PageLink`'s fallback, `.volume(volumeId:page:)`, when the device's page index names no document for the page. So the cause is in what this device resolves (its page index, the link's target) or in WebKit, or it has changed on both platforms since 13 November. MC15 taps both on the Mac to tell which. **In PD13 the same contents line opened document 1:** the first part does not happen every time. A tap the page index cannot yet answer would fall back to the volume's page by `PageLink`'s rule, which is to be tested. | *Waiting for the Mac's side (MC15), then the owner's word* |

## Results

*To be recorded as the owner reports.* Each finding is placed by the R6 bullet's rule. A defect goes to a row on the owner's word, and the next upload takes a build number above 1823 and below 1861. One that is not a crash, a loss of work or a store check may go to the first update instead, or to §5.
