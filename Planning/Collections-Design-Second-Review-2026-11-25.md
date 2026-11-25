# Adversarial review of the Collections design's second form, with the `.fruscollection` file — 2026-11-25

**Status: LIVE, 2026-11-25.** The review the owner asked for ("Adversarially review the revised design. Also check how the .fruscollection export format will be affected."), of `Collections-Customization-Design-2026-11-25.md` in its second form, as it stood at `88780fc`. Read against `v2` at `efd73ec`. Nothing in the app or its tests changed.

**The design was revised afterwards, on the owner's word, and the defects of §6 were filed.** This review is of the design's second form, which is in history at `58cc047`, and the section numbers below are that form's. The third form's §11 lists each finding here with where it is answered, and its §12 the runs still owed. No one has reviewed the third form.

**The verdict in one line:** the second form does not stand as written either. No finding was refuted. Its storage can lose work, and what it says of the `.fruscollection` file is wrong: the file need not change version, and a 1.0 app should go on opening it.

**Where the findings fall.** The first review's central objections are answered in part (§0). Most of the new findings are about what the revision added: the two record types and their upgrade, version 3 of the file, a number at each lead, the notes as one choice, a look chosen in the export sheet, and a wording table that holds the mark itself.

---

## 0. What it found

Six reviewers returned **59 findings**. Three skeptics then tried to refute each against the code, the record, the boards and the public TEI. **None was refuted.** After duplicates were merged the count stands at:

| | Distinct findings | Of them, waiting on a run |
|---|---|---|
| **S1** | **1** | It is the tree's own statement of what its cleanup does; nobody ran it |
| **S2** | **20** | 1 (the export sheet at the largest text sizes, H21) |
| **S3** | **27** | 2 |

- The reviewers rated three findings S1. The skeptics kept one (DATA-1, the upgrade on two devices) and re-rated two to S2: the collection's own number beside the volume's (EDI-1) and the unmarked date line (EDI-2). In each, no line on the page is false; the page is ambiguous, or unmarked only in stated cases.
- Ten of the 59 were re-rated down, chiefly because the thing is true of 1.0 today or is a list of what a lane's row leaves out. Three are plausible pending a run.
- The skeptics listed 54 statements of the design record that are false or contradict another part of it, **43 once merged** (§5). Thirteen are about the app as it ships or about the volumes, and are corrected in the record.

**What the findings say, in eight sentences.**

1. **The upgrade can delete the work done after it.** Two devices that upgrade one collection make exact twins, and the tree's own comment says its cleanup can then keep a different copy on each device, "and after sync no copy is left" (H1).
2. **Nothing but the twin says a collection was upgraded,** so a new device or a rebuilt store can upgrade it again from its 1.0 state (H2); the test for a fork reads one date that most edits do not move (H3); and an older export imported over an upgraded library has no rule (H4).
3. **The `.fruscollection` file need not change.** Every addition is one a 1.0 reader ignores, the format's own rule keeps the floor at 1 for exactly that case, and a refusal would break a pinned test, the published Guide and a sentence in both manuals (§2, H6).
4. **A look chosen in the export sheet is not yet a defined thing.** It has no meaning for four of the sheet's seven exports (H9), cannot tell a template's blocks from the author's (H10), and three of the six looks need a prompt, Apple Intelligence or stored summaries that the collection may lack (H11).
5. **The collection's own number collides with the volumes'.** From 1955 a heading opens with the volume's number, the indexes and the volumes' notes cite by it, and 1.0 already numbers its contents rows in three different ways (H13, H14).
6. **The date line has no words on the page, and the mark that has words is in the table of words an author may change** (H15, H18).
7. **The notes as one choice of three cannot hold every stored state:** a section or document that sets one of 1.0's two switches and inherits the other has no image in one key (H12).
8. **The count is 41, not 31,** counted the way the record counts today's 24 (H19).

**The first review's 17 merged findings, as the second form answers them.** The reviewers judged each row of the record's §11 in their scope, and the skeptics checked those judgements.

| | Findings |
|---|---|
| **Answered** (3) | G4 (the scope is no longer a mode), G9 (the mark is words, for the title), G15 (the short form is out of the core) |
| **Partly** (13) | G1, G2, G3, G5, G6, G7, G8, G10, G11, G12, G13, G14, G16. Skeptic B read G12 as answered with its run owed |
| **Not answered** (1) | G17, which the record moved to a new record type and left to a run. Under the same ids a device that does not receive the twins now upgrades again, which is more than holding nothing |

---

## 1. Method

As the first review, with one scope more.

**Six reviewers**, each with one scope and the same brief (`collections-design-review-2/reviewer-brief.md`): interaction and comprehension (INT), engineering feasibility and regressions (ENG), stored data, sync and the upgrade (DATA), the `.fruscollection` file and the other carriers (FMT), editorial and scholarly integrity (EDI), and accessibility (A11Y). None was given the session's reasoning, only the record, the boards' source, the first review and the code. Each returned at most ten findings, with what would refute each, and judged the rows of the record's §11 in its scope.

**The severity scale** is the first review's: S1 fails an ask, loses or corrupts work, states something false or unmarked to a reader of an export, or cannot be built; S2 misleads a first-time user, falsifies a claim of the record, breaks a clear accessibility rule or hides a cost that changes a lane's size; S3 is real but secondary.

**Three skeptics** (`skeptic-brief.md`): A took INT and A11Y, B took ENG and EDI, C took DATA and FMT. Verdicts: CONFIRMED, CONFIRMED and RE-RATED, PLAUSIBLE (with the check owed), REFUTED, NOT NEW, DUPLICATE. Skeptic B recounted the TEI figures with scripts of its own. Skeptic C was also asked to check the file reviewer's account of the format rule by rule.

**The session's own part.** It read `NativeCollectionFormat.swift` whole before any reviewer returned and wrote down what it found (`session-notes-on-the-file.md`). After the skeptics it re-read four citations the review turns on: the cleanup's comment (H1), the pinned test of a version-3 file with a floor of 1, the manuals' sentence (H6), and the prompt a summary export requires (H11). Each says what the finding says.

**Sources.** The code at `efd73ec`; the design record at `88780fc`; the seven boards' source; both manuals and the Agentic Analysis Guide; the first review and its reports. Eight volumes of the public TEI already on disk, and one fetched for this review (`frus1969-76ve01`). The HTML Standard's default style sheet, the Open XML SDK's schema source, the Swift standard library's `Codable.swift`, and pages of Apple's Human Interface Guidelines and of WCAG, fetched the same day.

**What no one could do.** No app was built or run, no device was used, and neither Word nor a browser was opened. How CloudKit's mirror batches a first import, what a device updated later receives, and how a screen reader speaks a list's markers were not established from anything readable here.

**The reports themselves** are in `Planning/collections-design-review-2/`, as returned. Every `file:line` this document gives is one a skeptic re-read.

---

## 2. The `.fruscollection` file

The owner asked for this by name. The file reviewer's account was checked by skeptic C at each cited line, and eleven rows of its table were tested against the code. Lines are of `FRUSCoreKit/Collections/NativeCollectionFormat.swift` unless another file is named.

### 2.1 The file today

- **What it is.** JSON of a plain `Codable` struct, "decoupled from the SwiftData `@Model` types, so the file schema can evolve independently of the persistence layer" (:24-26). It carries the collection's source, not a rendering (:16-22). Its type conforms to `public.json`, and neither the type nor the extension carries a version (`project.yml:212-225`, `:412-425`).
- **Required keys.** `format`, `formatVersion`, `name`, `entries`, each entry's `kind`, and `composition` with six members: `defaultBodyDepth`, `footnoteStyle`, `tocStyle`, `applyHighlights`, `includeNotes`, `includeWordCloud` (:80, :84, :96, :116, :118, :150-169, :201). The coding is synthesized, which is why every non-optional key is required and every unknown key is ignored.
- **Two numbers.** `formatVersion` is "what the *writer* understood" (:81-84). `minimumReaderVersion` is "the oldest reader version that can open this file without corrupting meaning" (:85-94). The app's `currentVersion` is 2 (:412).
- **The reader.** It decodes the whole file, then checks `format`, then the gate: `minimumReaderVersion ?? formatVersion`, which must be no higher than 2 (:434-443). An unknown entry kind is skipped (:699-704). An unknown block type is kept as an inert entry (:741-746). A level out of range is clamped (:729-732).
- **The writer.** It writes the minimum the content needs: a version-1 file "byte-identical to a pre-Phase-4 file" where no later feature is used, else version 2 with `minimumReaderVersion: 1` (:448-454, :610-659). `footnoteStyle`, the three-way value, is always written (:151-154, :479).
- **The rule for the floor.** "Writers raise it only when *ignoring* a field would corrupt meaning, never for degradable features" (:91-93); "degradation never raises the floor (Migration rule 3)" (:657-659). Five rounds of additions since version 2 raised neither number (:37-73).
- **What travels.** The name and note; the front matter and three switches; the composition; the entries in order, with kind, document, level, text, rich text, an excerpt's anchors, a block's type, `titleOverride`, the text-depth override, six override keys and `includeHeadnote` (:99-114, :148-172, :198-274). Two ids travel: `headnoteSummaryId` (:227-231) and an entry's `summaryPromptIdOverride` (:254-258).
- **What never travels.** Ids, timestamps and projects (:21-22); which notes and which highlights are chosen (:268-273, :55-58); the collection's summary prompt (:146-147); the saved-search link (:681); a block's rows (:59-66). Note texts travel only when the exporter switches them on, and become new notes of the recipient's (:467-471, :705-715).
- **Who writes it.** The export sheet alone, and never for a smart collection (`CollectionExportSheet.swift:608-652`, `:613-617`); and a host outside the app through the kit's public writer (:74-75, :472-476).
- **Who reads it.** *Import Collection…* on iOS and the Mac, and a file opened from Files, Finder or AirDrop (`CollectionListView.swift:290`; `MacCollectionManagerView.swift:491`; `FRUSExplorerApp.swift:2436-2479`). Each import makes a new collection with new ids (:695, :723). The web edition reads it through the same kit. Outside tools read and write it by the Guide.
- **What is published about it.**
  - `Docs/Agentic-Analysis-Guide.md` §15, *Writing a collection the app can open*: its example's "bytes are a test fixture in this repo" (:2829-2830); its checker fails a file whose gate is above 2 (:2933-2936); it says a file "declaring `formatVersion: 3` with no floor is *rejected* by a version-2 reader; the same file declaring `"minimumReaderVersion": 1` is accepted" (:2960-2963); and it promises the way back, "a collection exported *out* of the app is the same format" (:2982-2985).
  - Both manuals: "a collection using no newer features is written in a form older app versions open unchanged" (`iOS-User-Manual.md:1152`; `macOS-User-Manual.md:897`).
  - A pinned test of "a hypothetical v3 writer … minimumReaderVersion 1 because it is all degradable" (`CollectionTests.swift:2946-2960`), and the Guide's two examples as fixtures (`:3015-3126`).

### 2.2 What each element of the proposal does to the file

The third column is what build 1861 does with a file that carries the element and declares the floor the format's rule gives. The last is what the new version does with a file written by 1.0 or by an outside tool.

| Element | In the file today | Should the new version write it | A 1.0 reader | The new version, given a file without it |
|---|---|---|---|---|
| Text | `defaultBodyDepth` (required), `bodyDepthOverride` | as now | reads it | cannot occur: the key is required |
| The volume's notes | `footnoteStyle` (required), with the same three values; the optional pair; per entry, the pair | yes; `footnoteStyle` alone carries the collection's choice | reads it. *All* with no pair reads there as footnotes on, source line off, so nothing prints twice | maps the style or the pair |
| Your title | `titleOverride` | as now | reads it | none |
| Your date line | none | yes: it is portable content, as a title is | ignores it | none |
| Opening | none | yes | ignores it: the citation leads | the citation leads |
| Numbering | none | yes, if it is kept (H13, H14) | ignores it | none |
| Citation style | none | yes | ignores it: History at State | History at State |
| The wording table | none | yes | ignores it: the app's words | the app's words |
| Headnote on or off | the collection's and a document's | as now; a section's is new | drops a section's (:759) | off |
| A headnote's text | **the draft's id only** | **not the id** (H7) | reads the id | the id resolves on the author's account alone |
| Your notes, highlights | on or off; which, never; texts on the switch | as now | reads them | as written |
| See also | a document's and a section's | the collection's is new | follows a section's | off |
| The Note on the Text | none | as a block type, where it is a block | keeps an unknown block type, inert | prints when it has something to say |
| Colophon, stamp, query log, word cloud | four keys | as now | reads them | off |
| The template followed | none | a shipped template's id can travel; a saved one's cannot (FMT-9) | ignores it | finds it by comparison. The Guide's own example matches none of the six recipes |
| What placed a block | none | only if the design keeps the idea (H10) | ignores it | the author's own |
| The record's version, the upgrade's dates, ids | never | no | n/a | fresh ids, as now |
| The collection's summary prompt | left out by rule | no | n/a | the recipient's own |
| A look chosen at export | n/a | no: the file is the collection as it is set (H9) | n/a | n/a |
| A smart collection's link | never; the file is not offered | no change | n/a | n/a |

### 2.3 What the record proposed, and why it does not hold

The record's §7.6: "The collection file takes version 3, and a 1.0 app refuses to open one, with the message it has for a later file … Writing the minimum, so that an untouched collection is still a version-2 file, would need a second function from the new values back to the old. This design does not propose it: one-way is what the owner offered."

- **It is not necessary.** Skeptic C went through each setting of the record's §4.1, §4.3 and §5.2 looking for one that a 1.0 reader would misread and found none: each is an unknown key, which is ignored, or already has a 1.0 key. Under the record's own §3.1 nothing the volume prints is ever left out, so a 1.0 reader that ignores the new keys prints 1.0's layout and nothing false. That is the case the format's rule keeps the floor at 1 for. The first form kept the floor, the first review found that sound, and the second form reversed it with no row in its §11.
- **Its reason does not hold.** The owner offered a one-way conversion of the stored model. The file is not that model: its own comment says it is decoupled from it, and an import never writes back to the file it read. The "second function" is needed in any case: lane 3 keeps today's two switches and *Default / On / Off* pickers over the new values (the record's §9), which is the same mapping.
- **Build 1861 would not do what it says.** The reader decodes the whole file before it looks at any version (:435, then :439-442). A file without the six required composition keys throws a decoding error and never reaches the message "Update the app to open it" (:327-328). All three import paths then show that error's own description (`CollectionListView.swift:304-306`; `MacCollectionManagerView.swift:505-507`; `FRUSExplorerApp.swift:2477`). So the promised message needs the old keys, which is the mapping §7.6 declines.
- **It is not sufficient.** §7.6 gives the file two sentences. It does not say which keys version 3 writes, which floor it declares, what carries a headnote, whether a look reaches the file, or who else reads it.
- **It contradicts the record itself.** §7.3 adopts "the collection file's own rule, write the minimum" for records, and §7.6 drops that rule for the file. §7.6 also holds the file to "a round trip of a fixture with every field set", against the list of what never travels (FMT-7).
- **§7.7 understates the cost.** With the file refused, a version-8 export refused by a version-7 importer, and a new collection that "does not appear on a device running 1.0", a person with the new version on a phone and 1.0 on an iPad has no way at all to put a collection made on one onto the other.

### 2.4 What follows for the file

The session's reading, as §8 is. Nothing here is decided.

1. **A 1.0 app goes on opening a file the new version writes.** The floor stays 1.
2. **The new version writes the keys 1.0 reads, and its own beside them.** The six required composition keys and today's override keys are filled from the new values; each new setting is an optional key.
3. **Writing the minimum stays.** A collection that uses nothing new is written as the bytes 1.0 writes today, which keeps the manuals' sentence true and the Guide's fixtures green.
4. **Whether the number becomes 3 is a small choice.** A 3 with a floor of 1 is a pinned case and passes the Guide's checker. Five rounds of additions have ridden 2 without one.
5. **A headnote travels as its text or not at all,** never as a draft's id, and every import makes its own draft (H7).
6. **A look is not offered for the file.** The file is the collection as it is set (H9).
7. **An old file, or a tool's, is imported as it is today.** The upgrade's words for it, that its settings "came from 1.0", would be untrue of a file an agent wrote that morning.
8. **The lane that touches the file owes** the Guide's §15 (its two examples, its checker, its account of versions), both manuals' sentence, the sheet's hint "Recipients open it in FRUS Explorer", two ranged blocks of `Docs/EditableContent/08-Reading-Research-Collections.md` (`:897`, `:3226`), and the format's own tests. The record's §9 names none of these (FMT-6).
9. **One run before the format is fixed:** a hand-made file carrying new keys, the six required ones and a floor of 1, opened in build 1861 by each of its three paths (§7).

### 2.5 The other things a collection is carried by

- **BibTeX, RIS and the Zotero send.**
  - They read the collection's switch for research notes and no section's or document's (H8).
  - A look has no meaning for them but that one switch (H9).
  - Their titles come from the reading of a heading that lane 2 replaces; whether they take the new reading is unsaid (FMT-8).
  - Found sound: a title of the author's reaches none of them, and neither can a citation style.
- **The research export.** A version-7 importer refuses a version-8 file whole, as the record says. What an older file does to a library already upgraded is H4.
- **The export trail.** A row holds a format, a count, a name and a project (`ExportHistoryEntry.swift:60-84`), so it cannot tell two looks apart without a field that lane 1 says it does not add (FMT-10).
- **The web edition** compiles the kit at a pinned commit. Under §7.6 it would be a second reader that refuses the file. By `CLAUDE.md`'s rules that is the web side's to follow, but the file is the one carrier the two editions share today.

---

## 3. The findings, merged

Each names the findings it merges, the skeptics' verdict, and a direction. A direction is not a decision.

### H1 — Two devices that upgrade one collection can each delete the other's copy (DATA-1)

*CONFIRMED, S1. Read, not run.*

- **What a person meets.** iPad and Mac take the update the same evening, and each upgrades "Kennan from Moscow" before it has the other's records. iCloud then holds two records for the collection and for each entry, with one id and one set of dates. On the Mac they give document 475 a title. At each device's next launch the cleanup keeps the copy its own fetch returns first and deletes the other. After sync the upgraded collection is on neither device. The 1.0 record, untouched, now has no twin, so it is upgraded again as it stood in 1.0, and the title is gone.
- **Evidence.**
  - The record's §7.4 gives the twins one id ("take the ids of the old") and one set of dates ("an upgraded record keeps the 1.0 record's dates"). Its §7.5 keeper, "the copy changed since its upgrade, else the one made from the later 1.0 state", parts no two copies made from one state.
  - The cleanup keeps the earliest creation date, then the lower id (`DuplicateRecordOrder.swift:37-40`). Copies that share both "are kept in the device's own fetch order, which two devices need not share" (`DuplicateRecordCleanup.swift:64-66`).
  - The tree's own account of that case: "a device that updates later can keep a different copy and delete the one the first device kept, and after sync no copy is left" (`:243-245`).
  - It has happened once: "Measured on 2026-10-25 in the owner's library … The trail's came from R-2a's migration running on two devices" (`:249-251`). #1791 then ruled that such copies are read one of each and never deleted.
  - The pass is a list of ten types. It would not touch the new ones until a lane added them, which the record's "the duplicate cleanup can pair" assumes.
- **Direction.** Give each upgraded record a mark that orders its copies alike on every device, decide what the cleanup may delete with #1791's ruling in hand, and do not let a missing twin by itself start a second upgrade.

### H2 — The only record that a collection was upgraded is its twin (DATA-2)

*CONFIRMED, S2; it is S1 if a run shows it.*

- **What a person meets.** Six months on, a new iPhone, or *Fix iCloud Sync* on the Mac. The store starts empty and iCloud sends the 1.0 collections and their twins in batches. If imports go quiet for eight seconds between them, every 1.0 collection is upgraded again from the state it had on upgrade day. Every document removed since is an entry again.
- **Evidence.** The record's §7.4: "a second run finds the work done", by the same ids alone; "The 1.0 records stay as they are". Its §11 says no field is added to a type 1.0 knows. The wait it cites is eight seconds of quiet after any import event (`FRUSExplorerApp.swift:3379-3384`), which the same block calls "usually" enough (`:3438-3442`). *Fix iCloud Sync* discards the store's files (`ModelContainer+FRUS.swift:249-251`, `:298-303`), and the record's §12 offers it as a remedy.
- **Direction.** Record the upgrade, and an entry's removal after it, somewhere that reaches a device holding the 1.0 record, before relying on a wait.

### H3 — The test for a fork reads one date, which most edits do not move (DATA-3)

*CONFIRMED, S2.*

- **What a person meets.** Mac updated, iPhone on 1.0 for another week. On the iPhone they retitle three documents, rewrite a note block and reorder. None of it moves the collection record's date, so the Mac shows no notice. When the iPhone updates, it too stops listing the 1.0 record, and the week's work is in records no build shows. The other way round: merging two projects on the iPhone gives every collection of the merged project a later date, and the Mac marks each as changed.
- **Evidence.** The record's §7.5 compares "the date kept at the upgrade", and §7.2 keeps that date on the collection alone. "Editing an entry updates the entry's own `lastModified`; the collection is not touched in that case" (`Collection.swift:28-29`). A project merge rewrites `projectIds` on each collection (`ProjectAdminService.swift:130-135`).
- **Direction.** Compare the whole 1.0 collection, its entries and their drafts, with what was upgraded.

### H4 — An older export imported over an upgraded library has no rule (DATA-4)

*CONFIRMED, S2.*

- **What a person meets.** They also use the web edition, which writes format 7 until its pin moves, or they keep a device on 1.0. There they rename a collection, export, and choose *Import from JSON* on the Mac. The file's copy is newer, so it replaces. Passed through the upgrade it carries 1.0's layout with "every key set", and the Mac's opening, citation style, renamed words and date lines are overwritten by a file that could not say them. If the new types are planned as types the older file holds none of, each collection in the file arrives as an addition beside the upgraded record.
- **Evidence.** The record gives one sentence (§7.5) and one enum case (§7.6). The plan's rule is that a replacement "keeps the library's for the rest … so an older file never blanks what it could not say" (`ResearchImportPlan.swift:31-33`), and it compares by id within one model type (`:602-609`).
- **Direction.** Write the older file's rule as the plan's `Fields` cases for what version 8 adds, and test a version-7 file against a library already upgraded.

### H5 — "One CloudKit promotion" does not hold as the lanes are cut (DATA-6)

*CONFIRMED, S2.*

- **Evidence.** The record's §7.2 makes the date line and "the template that placed it" properties. Lane 3 has "No screen changes but what the upgrade adds"; lane 4 first writes both, under "no deploy". CloudKit "materialises a field from the first record that carries a non-nil value" (`CloudKitSchemaInventory.swift:514-516`), the promotion falls to "Whichever phase adds the first writer" (`:528-535`), and the archive's check does not require identifiers awaiting a writer (`Scripts/check_cloudkit_schema.py:151-154`). The tree records one way round it, a schema import of fields nothing had written (`:127-130`), which the record does not name.
- **Direction.** List the two types' properties, say which are always written, and name in lane 3 how each of the rest is written before the deploy.

### H6 — The file need not change version, and 1.0 would not refuse it as the record says (FMT-1, FMT-2)

*CONFIRMED, S2.* §2 above holds the evidence. **Direction:** keep both of the format's rules: the keys 1.0 reads written beside the new ones, and a floor of 1.

### H7 — The file carries a headnote as the id of its draft (FMT-3)

*CONFIRMED, S2. A defect of 1.0, read and not run.*

- **What a person meets.** The author exports a collection whose headnotes they wrote, later opens the file again on the same account, edits one headnote in the copy, and the original's headnote is gone. Deleting the copy takes all of them.
- **Evidence.** The id is written whenever set (:521) and read back unchanged (:760). Edit and Regenerate delete the draft with that id (`CollectionEntryInspector.swift:1158-1165`), and so do a row's and a collection's delete (`GeneratedSummary.swift:238-243`, `:258-262`). Duplicate copies the draft (`Collection.swift:866`); the import does not.
- **Direction.** The file carries a headnote's text or nothing, and every import makes its own draft.

### H8 — Four exports ignore a section's or a document's research-notes setting (FMT-4)

*CONFIRMED, S2. 1.0's behaviour, in no row of the record's §2.8.*

- **What a person meets.** They turn their notes off for one document, export BibTeX for a class, and that document's notes are in its `annote`. The same in an RIS file, in their Zotero library, and in a shared file made with notes included.
- **Evidence.** The rendered formats read the document's value (`CollectionItemHTMLRenderer.swift:397`; `DocxCollectionExporter.swift:781`; `PDFCollectionExporter.swift:854`). BibTeX and RIS read the collection's alone (`BibTeXCollectionExporter.swift:63`; `ZoteroCollectionExporter.swift:65-69`), the Zotero send reads no option (`CollectionExportSheet.swift:734-735`), and the file's notes follow the sheet's one switch (`:621-644`). Under the record's §4.1, "It shows what is in force", a row reading off for one document would be untrue of four of the sheet's seven exports.
- **Direction.** Put the four under the same resolved values, or say on the sheet that they follow the collection's switch alone.

### H9 — A look has no stated meaning for the four exports that are not renderings (INT-3, FMT-5)

*CONFIRMED, S2.*

- **What a person meets.** On an iPhone: *Full text as printed*, More formats, BibTeX, Export. The `.bib` carries no notes, because that recipe turns notes off, while the sheet's sentence promised "the full text of each document under its printed heading". With `.fruscollection` the colleague receives either a collection set to a template the author never had, or the author's own, in which case the ticked look was false.
- **Evidence.** No line of the record's §4.4, §5.1 or lane 1 ties a look to a format. The board's sentence follows the look alone (`Main.dc.html:77-90`), and files Zotero under More formats (`:54`) where §5.1 says "The Zotero row stays as it is".
- **Direction.** A look applies to PDF, Word and Web page; say what the sheet shows for the other four.

### H10 — A look cannot tell a template's blocks from the author's (INT-5, DATA-5, ENG-1 in part)

*CONFIRMED, S2.*

- **What a person meets.** After lane 1, which the record says may ship alone. A collection made last week under *Full text with your annotations* holds the Chronology and Persons Index that template appended. Exported under the look *Citations with your notes*, the PDF has that look's Bibliography and Thematic Index and also the other two, where the sheet's sentence names two. After lane 3 the same holds for every upgraded collection, for good.
- **Evidence.** The record's §4.4 prints a look "without the blocks the collection's own template placed". 1.0 holds no such fact: "A template is never stored, only the fields it writes" (`CollectionExporter.swift:50-51`); a block stores "Only the TYPE" (`Collection.swift:654`). §7.4 then upgrades each block "as the author's own". §4.4 also prints a look's blocks "at the end", where a Chronology's place is the front (`CollectionGeneratedBlockType.swift:87-91`).
- **Direction.** Say what a look does with blocks of unknown origin, in lane 1 and after the upgrade, and put it in the sheet's sentence.

### H11 — Three of the six looks need what the collection may lack (ENG-1)

*CONFIRMED, S2.*

- **What a person meets.** From the Collections list, *Summaries with overview*, Export PDF, for a full-text reader: the export stops on "Choose a summarization prompt in the collection's Composition section to export summaries." The prompt's picker shows only while the collection's own text depth is a summary, so the way through is to change the collection, which the look exists to avoid. Where a prompt is set, the export writes a summary for each document into the synced store. Under the two looks with headnotes on, each document with no stored summary prints "No stored summary for this document — generate one in the document view to fill this headnote."
- **Evidence.** A recipe holds no prompt (`CollectionExporter.swift:201-220`); none throws (`CollectionContentAssembly.swift:1421-1423`); a generated summary is inserted, saved and indexed (`SummarizationService.swift:172-179`), against §4.4's "no stored record is touched". The placeholder prints in all three formats (`CollectionItemHTMLRenderer.swift:463-466`). Skeptic B: "cannot be exported" is exact for one look of the three, and any 1.0 summary export stores summaries too.
- **Also.** If lane 1 ships before lane 2, as the record's §9 allows, the first look listed prints each source note twice.
- **Direction.** State each look's needs in the sheet before the export, and say what the summaries look stores.

### H12 — The notes as one choice of three cannot hold every stored state (ENG-2, DATA-7)

*CONFIRMED, S2.*

- **Evidence.**
  - Each half of 1.0's pair is its own optional field on an entry and a heading (`Collection.swift:526`, `:535`), has its own picker (`CollectionEntryInspector.swift:701-710`) and walks the cascade alone (`CollectionContentAssembly.swift:1049-1050`). "Footnotes: Off, Source note: Default" has no image in one key: pinning *The source note only* stops it following the collection, and holding no key prints the footnotes the author turned off.
  - All three exporters print *Source:* whatever the text depth (`CollectionItemHTMLRenderer.swift:378-382`). The record's §3.5 does not say what *All* prints for a document whose text is left out, so that line may go.
  - Lane 3 has "today's screens" write the new value with "No screen changes". Two switches cannot write one three-way key and both still read as the author left them.
  - The six UI suites named as the evidence that behaviour did not move drive no composition control but the colophon switch.
- **Direction.** Define the key for a document without text, and say how a half-set pair is upgraded and which control writes the key in lane 3.

### H13 — 1.0 already numbers its contents rows, in three ways (ENG-3, EDI-5, A11Y-1)

*CONFIRMED, S2.*

- **Evidence.** The PDF writes each document's row number and counts documents alone (`PDFCollectionExporter.swift:630-638`). Word's cached rows do the same (`DocxCollectionExporter.swift:1898-1906`). The web page's list is one `<ol>` whose items are documents, section labels and block titles (`CollectionItemHTMLRenderer.swift:560-583`); only `li.toc-sub` loses its marker (`:859-860`, `:971`), and the HTML Standard's default for an `<ol>` is decimal.
- **So.** The record's "no numbering … what 1.0 prints" (§7.4) and "It prints as it did" (§4.3) are false of contents rows. On the boards' own collection the web page's list has eleven rows and *The Long Telegram* is the sixth, under a lead of "4." Either *Numbering: Off* takes the numbers off an upgraded collection's lists, or they stay under a row that reads Off. The boards draw "3." and "4." under "what an upgraded collection keeps".
- **Direction.** Put the contents rows' numbers in the plan for all three formats, and say what Off and On print in a row.

### H14 — Two numberings on one page (EDI-1)

*CONFIRMED and RE-RATED, S2 (the reviewer rated it S1).*

- **What a person meets.** Six documents of the 1977–1980 volume VI, the volume's 2, 4, 5, 6, 9 and 12, lead "1." to "6." under *Full text as printed*. The first reads "1. 2. Memorandum From…", because the volume's number opens the heading itself. A footnote says "See Document 4", which here is the collection's 2. *Sources & Archives* lists "Document 2" and "Document 4" by the volume's numbers.
- **Evidence.** By skeptic B's own scripts:
  - the heading opens "N. " with the volume's number in 1,694 of 1,694 documents of the five volumes from 1955–57 to 1977–80, and "No. N" in 720 of 720 of `frus1952-54v08`; no heading of the 1,551 in the two earliest volumes carries one;
  - 1,698 references within a volume print a document number, 1,645 of them inside a note, in 1,004 of 2,414 documents.
  - Three kinds of block print "Document N" by the volume's number (`CollectionGeneratedBlocks.swift:465-468`, `:566-569`, `:716-738`), and each numbered template places one. The record's remedy is candidate 2 of its §8, which Q8 does not recommend.
- **Why S2.** No line is false: every "Document N" on the page is the volume's own, and the collection's is the bare number at the lead. That is two unlabelled numberings, and 1.0's PDF already prints a row number beside the volume's.
- **Direction.** Do not number the leads until the blocks cite by the same numbers, and give the number a form or a word that no volume prints.

### H15 — The author's date line has no words on the page (EDI-2)

*CONFIRMED and RE-RATED, S2 (the reviewer rated it S1).*

- **Evidence.** The record's §3.6 lists what cannot be removed: the words *Printed heading:* and a summary's attribution. The date line is not there. The Note's draft speaks of "a date line under a title", while both boards draw the two fields apart (`OptionB.dc.html:98-105`), and the record has no rule for a date line given without a title. In a contents row the board prints the author's date where the row above prints the volume's (`Marks.dc.html:71`, `:73`). From 1955 a plain dateline under a heading is the editors' own line.
- **Why S2.** It is the author's own words and not false; the volume's dateline prints whole three lines down; and by default the Note says whose it is. It is unmarked when the author removes the Note, gives no title, or exports under a look (H16).
- **Direction.** Give the date line the kind of mark the title has, on the page and in a contents row, or drop it under Q7.

### H16 — The Note on the Text does not print under a look, and is both a row and a switch (EDI-3, with INT-6, DATA-10 and ENG-4 in part)

*CONFIRMED, S2.*

- **Evidence.** The record's §3.6 prints the Note by default. Its §4.4 lists what a look prints as three kinds of block, none of them the Note, and the board names a Note for *As this collection is set* alone (`Main.dc.html:78`, `:80-90`). Two of the recipes leave footnotes out while the calls stay in the text. §3.6's rule gives no Note to a collection of summaries, whose template numbers its leads. The Note is a block the author "may move" (§3.6) and one of "the five back-matter switches" (§5.2, §7.2), with no rule joining the two, against §5.7's "The first form's five switches are gone".
- **Direction.** State the Note's rule over the plan that is printed, whichever look made it, summaries included, and give it one way of being absent.

### H17 — Word numbers the volume's footnotes by its own count (EDI-4)

*CONFIRMED, S2. A defect of 1.0. The number Word shows needs an opened file.*

- **Evidence.** With footnotes on, Word's file holds native footnotes with no custom mark (`DocxCollectionExporter.swift:1584-1585`, `:1728`), and the volume's label is dropped where the note is made (`:1082`, `:1099`). The web page and the PDF print the volume's label. Document 475's notes are numbered 44 and 45, and 580 of that volume's 592 documents with a numbered note open on a number other than 1. A note that says "see footnote 2, Document 14" then points at a number Word has changed.
- **So.** "The document prints as the volume prints it" is true of two formats of three, and the record's §2.3 has no row for the difference.
- **Direction.** Carry each note's printed label in the plan and have Word print it.

### H18 — The mark is in the table of words an author may change (EDI-6)

*CONFIRMED, S2.*

- **Evidence.** The record's §3.6: the words *Printed heading:* "cannot be removed". Its §5.2 lists *Printed heading* among the eleven fields of the wording table, with no rule for an emptied or reworded field. A contents row's second line, the volume's own words, carries no words at all (§3.4; `Marks.dc.html:74`). 22 of the manifest's 553 volumes are electronic-only, of which "Printed" is untrue. 240 of 3,965 headings read "Editorial Note", a word the table would accept for *Headnote* over a headnote the author wrote, which prints no attribution (`CollectionExporter.swift:1134-1135`).
- **Direction.** Take the mark out of the table, choose words true of every volume, and put a word on a contents row's second line.

### H19 — The count is 41, not 31 (INT-1)

*CONFIRMED, S2.*

- **Evidence.** The record's §2.4 counts today's 24 field by field. Its §5.5 counts the title page's five fields singly and the wording table's eleven as one. Counted alike: 14 in view, then 9, 2, 5 and 11, which is 41, seventeen more than today. "14 in view" holds. The export sheet is 15 against 7. Uncounted at any scope: a row's way back, its way there and a count that opens a list (the record's §4.1 and §4.2).
- **Direction.** Put the figure counted field by field beside 24 before Q1 is answered.

### H20 — A setting held at the value it would inherit has no rule (INT-4, with A11Y-6)

*CONFIRMED, S2. It is the first review's INT-5, left standing.*

- **What a person meets.** After the upgrade, documents whose headnote switch was written explicitly by an old migration read "Changed for this document" though nobody touched them, and are counted as documents that "keep their own settings" under a look. Clearing them is one "Use the collection's" for each. A switch turned off and on again either stays "Changed" at the inherited value or silently stops being a pin.
- **Evidence.** The record's §7.4 turns each override into "the keys the entry changes" and has no rule for a key equal to its parent; "equal" occurs in the record only for template matching. On the iPhone board the way back is words inside the switch itself (`PartsPhone.dc.html:54-60`).
- **Direction.** One rule for a held key that equals what it would inherit, applied in the upgrade, and a way back for many documents at once.

### H21 — The export sheet at the largest text sizes (A11Y-3, with INT-3)

*PLAUSIBLE, S2 if a run bears it out.*

- **Evidence.** The record orders the sheet look, format, sentence (§5.1), where today's leads with the sentence and the format cards. By the board's own sizes the sentence is below the fold when the sheet opens at the default size. With the HIG's sizes for AX5, seven two-line looks pass 900 points before the format control, against a viewport of some 500 to 620. Lane 1's check has each look speak its name, and names neither the sentence nor what must be in view.
- **Check owed.** §7.

---

## 3a. Secondary findings

| ID | S3 | Verdict |
|---|---|---|
| INT-2 | For one document the design adds two rows to 1.0's nine, and one of them, Opening, goes inert once a title is given. The record never sets its list against the five things §2.2 says an author cannot change | CONFIRMED, RE-RATED |
| INT-6 | On the Mac the gear now selects the collection and its settings replace the selected document's in the one column, which is the state the build-28 tester reported | CONFIRMED, RE-RATED |
| INT-7, ENG-9 | "Selecting one says so" has nothing to select: neither editor lists a smart collection's documents (`CollectionOutline+App.swift:214-224`) | CONFIRMED |
| INT-8, FMT-10 | Export Again keeps the format alone, so it cannot repeat an export made under a look, and has no rule for the file's notes switch or for a format no longer offered | CONFIRMED |
| INT-9 | A new collection started under *Full text as printed* stops printing the author's research notes, which 1.0's default prints; and with two blocks in place it is no longer "untouched" when left empty | CONFIRMED |
| INT-10 | The list is headed *Look* and captioned "A template"; five things are called a note; *Back matter* holds the stamp and the word cloud, which print at the front; three boards draw a third value for Opening | CONFIRMED |
| ENG-4 | The rule that a document arrives ahead of the back matter is one sentence against six append sites built on the opposite rule, and covers documents alone | CONFIRMED |
| ENG-5, FMT-6 | What the lanes leave out: a second pinned digest, the BibTeX and RIS pins, the export's contrast test, 26 ranged blocks for lane 2, the Guide and the format's suites for lane 3. Lane 2 carries the words *Printed heading*, which are Q2's subject, with no question in its row | CONFIRMED; FMT-6 RE-RATED |
| ENG-6, FMT-8, EDI-10 | The "one reading" has two sources that give different lines; it changes the titles of BibTeX, RIS and Zotero items unless a second reading stays; and a dateline's footnote calls are not kept apart as a heading's are | CONFIRMED |
| ENG-7, EDI-7 | The two sentences §3.7 rewords are shared by the analytics exports, the Archives Visit packet and the method appendix. An Apple Intelligence headnote adds no source today | CONFIRMED; EDI-7 RE-RATED |
| ENG-8 | The preview's three repairs are due "on every platform" and sit in the Mac's lane | CONFIRMED |
| ENG-10 | The web page prints "Footnotes" as a heading over each document's notes, a word in no table and no plan | CONFIRMED |
| DATA-7 | The upgrade's table has no row for the collection's summary prompt or an entry's older single-note link | CONFIRMED |
| DATA-8 | The rule for writing a settings value speaks of the editor. A prompt collapse and an import also rewrite the value | CONFIRMED |
| DATA-9 | The one copy test reads properties, and the settings are keys inside one property. A reader left on the 1.0 types still compiles and still finds a frozen record | CONFIRMED |
| DATA-10 | A smart collection's snapshot copies the value and none of the block rows it prints | CONFIRMED |
| FMT-7 | "A round trip of every field" cannot hold for the file, by its own list of what never travels | CONFIRMED |
| FMT-9 | The two candidates Q8 recommends cannot travel in the file: highlights do not, and a saved template is a record the recipient lacks | CONFIRMED |
| EDI-8 | Four statements about the volumes hold for one era only | CONFIRMED |
| EDI-9 | Before 1955 *All* drops the only copy of the source note that carries a label; for seven withheld documents *None* removes the one sentence the body holds | CONFIRMED |
| A11Y-2 | A click on a part moves keyboard focus to its row; for the two text rows a field focused by code may select its whole text | PLAUSIBLE |
| A11Y-4 | Where the printed heading leads, the citation is drawn before the heading it belongs to, and lane 2's check is written for the opening with a title alone | CONFIRMED, RE-RATED |
| A11Y-5 | The gallery's type is fixed in points and cut at three lines; the fit check names two iPhones and no iPad. All 1.0's | CONFIRMED, RE-RATED |
| A11Y-6 | No board draws a row's way back or way there as something that can be operated | CONFIRMED, RE-RATED |
| A11Y-7 | The accessibility table has rows for five lanes of seven; lane 3 adds screens and has none | CONFIRMED, RE-RATED |
| A11Y-8 | The opening drawn at the head of a document's settings cannot share the screen with the title field at the largest sizes | PLAUSIBLE |
| A11Y-9 | The list's *Export…* is a context-menu item with no VoiceOver action; each note's switch speaks one shared name; the section pill is about 24 points high | CONFIRMED |

---

## 4. Found sound

Each was attacked and held.

- **The counts over the volumes** in the record's §3.1 and §3.2 all reproduce, and the Editorial Methodology quotation is word for word. The boards' first line of document 475, its dateline and its note 44 match the TEI.
- **The highlight claim.** A label or a number at the heading stays outside the walk that counts offsets in all three exporters, and no rendering version or index version moves.
- **The printed heading is one node:** each of 3,965 documents in the eight volumes has exactly one.
- **The six recipes fall two, two and two** over the three note values, and a pair fully set maps onto them.
- **The three citations of §6** are what the formatters write, and a style changes no order.
- **A title reaches no citation record,** and a citation style cannot reach BibTeX, RIS or Zotero.
- **A look that writes nothing fits the sheet as it is,** which never writes the collection. No UI suite walks the export sheet, so lane 1 breaks none.
- **A file of version 1 or 2 through the upgrade:** the importer's output is the type the upgrade takes.
- **The interlock.** The pass writes and destroys nothing, which is the case the inventory itself exempts.
- **A headnote's copy cannot be removed from a 1.0 device.**
- **The new types cannot ship unstamped or outside Erase Everything:** two tests walk the schema.
- **On the boards:** every text pair is 5.2:1 or better; the mark is words inside the heading line; no change is told by colour or a dot alone; no board has a scope control.
- **Every `file:line` the record cites in §3.2 to §3.5, §3.8, §5.3, §6 and §9 holds.**

---

## 5. Errors in the design record

**About the app as it ships, or about the volumes. Each is corrected in the record where it stands, marked with the finding that named it.**

1. §4.1: a section's See also is followed by its documents in 1.0 (`CollectionContentAssembly.swift:611-612`, `:1103`). Only a section's headnote is new.
2. §4.3, §7.4 and §8: "no numbering" is not what 1.0 prints. It numbers the documents in the contents list of all three formats (H13).
3. §2.8, defect 2: the source note prints twice before 1955 too, where it is a footnote and the index stores it.
4. §5.2: the volumes print *Source:* from the 1955–57 volumes at least (323 of 332 source notes of `frus1955-57v24`), not "from 1961".
5. §3.1: "A heading has been supplied by the editors" is in the prefaces of the four volumes from 1961–63 and in none of the four earlier ones read.
6. §4.5: a smart collection's documents are shown in the preview; neither editor lists them.
7. §4.2: the build-28 tester asked for the collection's attributes to stay reachable "after refocusing on a document", and the state reported was "not reachable without clearing the selection".
8. §5.5: today's counts stand on unlike bases. The section's 7 leaves out the heading's own title field, which the design's 9 counts; the sheet's 7 counts each of six format cards, where the design's 12 counts *More formats* as one.
9. §7.4: the wait is eight seconds of quiet after any import event, not the end of a launch's first import.
10. §7.4 and §7.5: the cleanup names ten types and neither new one, and for exact copies the device's fetch order decides.
11. §7.4: the archive's schema check does not require identifiers listed as awaiting a writer.
12. §7.5: an edit to an entry does not move its collection's date.
13. §2.1: the path to a PDF counts "a format card", though the sheet opens on PDF.

**Claims of the proposal, which this review supersedes. The record's text is left as reviewed.**

- **The file:** version 3, refused by 1.0, with no function back (§7.6); "a round trip of a fixture with every field set" (§7.6); the file's own write-minimum rule adopted in §7.3 and dropped in §7.6; the floor of 1, found sound by the first review, reversed with no row in §11; "the settings came from 1.0", which would be said of a tool's file.
- **Storage:** a headnote draft's two copies, made under one id on two devices, as "the same copy" (§7.4), where they are two records of a type nothing collapses; "One CloudKit promotion" (§7.7) beside lane 4's "no deploy"; a table with no row for the summary prompt or the older note link, and the word cloud in it twice (§7.4).
- **The page:** "maps onto them with nothing lost" (§3.5); "It prints as it did, apart from §2.8's defects" (§4.3), where a titled document gains a citation line and the words *Printed heading:*; the words "cannot be removed" (§3.6) beside a field for them (§5.2); the Note as a block (§3.6) and as a switch (§5.2, §7.2), under "The first form's five switches are gone" (§5.7); the Note printing for "a document whose text prints" beside its own bullets for a citation and a summary; "Everything of the author's stands above the first of them" (§3.3), where the number and the two words stand at the heading; the draft "each volume's own number is in the citation", untrue of the volumes that print none; a contents row (§3.4) that the board draws with the author's date in it.
- **Templates and lanes:** a look's blocks "at the end" (§4.4), where a Chronology goes first; "no stored record is touched" (§4.4), where a summary export stores summaries; lanes 1 and 2 "work on 1.0's values" (§9), beside a first row that names the template followed and a rule about the blocks it placed; lane 4's "Only where used", beside two sentences that four other exports print; the preview's repairs "On every platform" (§5.3), in the Mac's lane.
- **The interface:** "31" (§1, §5.5, §11); the collection as the outline's first row "on three platforms" (§4.2, lane 5), beside "The gear's sheet, as now" for iPad (§5.4); "The Zotero row stays as it is" (§5.1), beside the board's *More formats*; Opening's two values (§4.1), beside three boards' "Your title leads"; "Footnotes: All" (§4.2) for the row named *The volume's notes*; *Back matter* for what prints at the front; "A check for each lane" (§11), for five of seven.
- **The boards:** `Marks.dc.html` draws *Header & Dateline* rows for the full-text templates, which list by citation; `Main.dc.html:80` drops "numbered 1 to 6" for a template the record numbers.

---

## 6. Defects of the app as it ships, met on the way

None is this design's doing. They are beyond the seven of the record's §2.8. Each was confirmed by a skeptic's re-read of the code unless it says otherwise; none was seen in a running app.

**Filed on 2026-11-25, on the owner's word,** after the session read each again at its lines: 8 is #1999, 9 #2000, 10 #1993, 11 #2001, 12 #2002, 13 #1992 and #2003, 14 #1997, 15 #2004, 16 #2005, 17 #2006 and 18 #2007. Items 13 and 14 are in part further cases of the first review's fourth and sixth, and share their issues.

8. **A `.fruscollection` carries a headnote as its draft's id,** so a file opened on its author's own account makes a collection that shares the original's drafts (H7).
9. **BibTeX, RIS, the Zotero send and the file's note texts ignore a section's or a document's research-notes setting** (H8).
10. **The three formats number contents rows differently:** the PDF and Word count documents; the web page's list also counts section labels and block titles (H13). Whether the digits are drawn needs an opened page.
11. **Word numbers the volume's footnotes by its own count** when footnotes are on, where the web page and the PDF print the volume's numbers (H17).
12. **A *Header & Dateline* row for a volume from 1955 carries two numbers,** the row's and the volume's: "4.  1. Letter From…" (`CollectionExporter.swift:682-683`).
13. **A citation record's title can end in "[1]",** and an editorial note's is its id, since the collection reads a heading at the top level and writes a footnote call into it (`CollectionContentAssembly.swift:1518-1522`; `ZoteroJSONExporter.swift:159-160`). Derived from the code and the TEI.
14. **The preview's refresh list omits two fields its page draws, not one:** the title override and the collection's headnote default (`CollectionPreviewView.swift:211-266`) *(corrected on filing, #1997: this review first said four. The project stamp and the query log are not in the list either, but the preview's own options draw neither, `:519-531`, so nothing on its page waits for them)*.
15. **A document entered twice has duplicate element ids in the exported web page** (`CollectionItemHTMLRenderer.swift:784-787`).
16. **An Apple Intelligence headnote adds no source to the export's statement of sources** (`CollectionExporter.swift:1317-1319`). The headnote keeps its own line of attribution.
17. **In the Collections list, Rename, Duplicate and the rest are context-menu items with no VoiceOver action;** each note's switch in a document's inspector speaks the same name; the section pill is about 24 points high; the template cards' type is fixed in points.
18. **With footnotes left out, each call in the web page is still a button whose target was not written** (`FRUSRenderNodeHTMLSerializer.swift:339-344`). Raised by a reviewer outside its scope and not checked by a skeptic.

---

## 7. Runs owed, each needing a device, an app or an opened file

- **The file (H6):** a hand-made file carrying new keys, the six required ones and a floor of 1, opened in build 1861 from *Import Collection…*, from Finder and from Files. Then one without the required keys: what does the alert say, and which of the two alerts on that flag shows.
- **The headnote (H7):** export a collection with a written headnote, import the file on the same device, edit the copy's headnote, read the original's.
- **The upgrade, if the two record types are kept (H1, H2):** two devices that both upgrade before either imports, each then launched twice; and, with upgraded collections in iCloud, *Fix iCloud Sync* on one device and a fresh install on another, logging whether the pass runs before every twin has arrived.
- **The fork (H3):** on 1861, retitle a document in a collection, save, and read the collection's modification date.
- **Word (H17):** export `frus1946v06` d474 and d475 under *Full text as printed* and read the number after "[13]".
- **The web page (H13):** a 1.0 export of a collection with one section heading; read the numbers of its Contents.
- **The preview:** with it on, switch Headnotes alone and wait five seconds.
- **The export sheet (H21):** the built sheet on iPhone 17 and iPhone SE at the default size, AX3 and AX5: what is in view when it opens, and what VoiceOver says after a look is chosen.
- **The Mac's focus (A11Y-2):** with keyboard navigation off, set focus by code on a switch, a menu and a text field in an inspector column; note what takes it, whether the field's text is selected, and where the next Space goes.
- **Still owed from the record's §12:** Word's contents list, in Word and in Pages; what a device updated later receives; the app's Chicago and Turabian against the two manuals.

---

## 8. What the design becomes

The session's own reading of the findings. **Nothing here is decided, and nobody reviewed it.** The design record is not rewritten: it carries a notice that points here, and the corrections of §5's first list.

Most of the findings fall on what the second form added, so most of what follows is a taking away.

1. **The file does not change version** (§2.4). This is the one place the second form was plainly wrong, and the remedy is to do less.
2. **The upgrade as designed is withdrawn.** Two routes are left, and the review moves the session's recommendation to the first.
   - **Keep the two record types, and add only the new facts.** There is then no upgrade pass, no twin, no fork between record types and nothing to run twice. The reason the second form gave for new types, two forms of one fact, came from replacing 1.0's pair of note switches and its override fields with one value. If those stay as they are (point 3), the new facts are few: the opening, the citation style, the words, a date line. Build 1861 ignores them and prints 1.0's layout, which under the rule that nothing is replaced is never false. What this route still owes is the first review's G1 and G17: a rule for a build that knows fewer keys, and the two-device run.
   - **Or new record types with a different upgrade:** started by the owner on one device and not by a launch; recorded on the 1.0 record or by its removal, so that no other device repeats it; with the new types read one copy of each id and never deleted by the cleanup; and with a rule for an older export (H1 to H4).
3. **The notes stay two switches,** as they are stored today, and the plan prints the source note once. There is then no new key, nothing to map and no control to change in lane 3 (H12). What each setting prints for a source note that leads the document, and for a document whose text is left out, is said per era (EDI-9).
4. **No number at the lead.** The plan numbers the contents rows, documents only, the same in all three formats, which is what 1.0 means to do. Where a volume prints its own numbers the heading already tells documents apart; where it prints none, the citation or a title does (H13, H14).
5. **The author's lines are marked as a block, in words that hold for every volume and that the author cannot change.** One label over the author's title and date line, and one over the document, such as *In the volume:*, would mark a date line as it marks a title, would hold where no title is given, and would be true of an electronic-only volume. A contents row's second line takes the same word (H15, H18). If that is too much for a date line, Q7's other answer is to drop it.
6. **The Note on the Text is a block and nothing else,** computed from the plan that prints, under a look too (H16). As a block type it travels in the file and is inert on 1.0.
7. **A look is for PDF, Word and Web page.** For that export it replaces the collection's settings and its generated blocks with the template's own, each block in the place the template gives it. That can be computed on 1.0's values. A look that needs a prompt, Apple Intelligence or stored summaries says so in the sheet before the export (H9, H10, H11).
8. **Nothing records what placed a block.** Choosing a template for the collection lists the blocks it would add and the generated blocks its recipe does not call for, and the author ticks each. There is then nothing to upgrade and nothing to guess (H10).
9. **The collection's settings stay behind the gear on every platform,** as today. A section's and a document's are those of the row selected (INT-6).
10. **Smaller things.** The count is restated as 41 (H19). Export Again repeats an export exactly or is dropped, since *Export…* then *Export* already does the same in one tap more (INT-8). A setting held at its parent's value is shown as set on purpose, with a way back for many documents at once (H20). The export's statement of sources gets a sentence of the collection's own (ENG-7). The four exports that ignore a document's notes setting are either brought under it or said to follow the collection's (H8).

**What stands.** Nothing the volume prints is replaced; the author's title leads and the volume's heading follows it in words; one plan for three formats, with one reading of a heading and a dateline; a template in the export sheet writes nothing to the collection; a section's and a document's settings are those of the row selected, with no *Default* choice; a citation style for the collection; pointing at the page on the Mac alone; the template gallery first.

**Questions of the record's §10 that this reopens:** Q2 (the words of the mark, and that they are fixed), Q3 (a look, for three formats), Q4 (no number at the lead; and what a new collection starts under, given that *Full text as printed* leaves the author's notes out), Q6 (storage), Q7 (the date line). And three it adds:

- whether the citation records take the new reading of a heading, which would end "[1]" in a title and change what Zotero receives;
- whether a headnote the author wrote should travel in the file as text;
- whether the defects of §6 are to be filed, with the seven of the record's §2.8.

---

## 9. Files

- **This document.**
- `Planning/collections-design-review-2/`: `reviewer-brief.md` and `skeptic-brief.md`; the six reviewers' reports (`reviewer-INT.md`, `-ENG.md`, `-DATA.md`, `-FMT.md`, `-EDI.md`, `-A11Y.md`); the three skeptics' (`skeptic-A-INT-A11Y.md`, `skeptic-B-ENG-EDI.md`, `skeptic-C-DATA-FMT.md`); and `session-notes-on-the-file.md`, the session's own reading of the format, written before any reviewer returned. The reports are as returned, and they name files under the session's scratch folder: the boards' source there is what the canvas holds, and the reviewers' scripts and fetched pages are not kept.
- **The design it reviews:** `Planning/Collections-Customization-Design-2026-11-25.md`, second form, at `88780fc`. The file now opens with a notice of this review and carries §5's thirteen corrections.
- **The first review:** `Planning/Collections-Design-Adversarial-Review-2026-11-25.md`.
- **The canvas** is the second form's and was not redrawn.
- **Not done:** no build, test or run. The session wrote §2.4, §8 and every direction; no reviewer or skeptic was asked to judge them.
