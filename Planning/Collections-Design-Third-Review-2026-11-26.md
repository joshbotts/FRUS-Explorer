# Adversarial review of the Collections design's third form, as the owner's answers leave it — 2026-11-26

**Status: LIVE, 2026-11-26.** The plan of record's row CR (decision 149): the review of `Collections-Customization-Design-2026-11-25.md` in its third form, as twice amended and brought to the owner's answers (decisions 153 to 174), before any of its lanes is built. Read against `v2` at `b3acd7ad`, with index version 76 on `claude/plan-of-record-pr2011-2cc493`. Nothing in the app or its tests changed. The checkpoint after it, C2, was the owner's, and was made the same day (§8): decisions 191 to 202.

**The verdict in one line:** the third form stands as a design, but not yet as the briefs that will build it. No finding was refuted.
- The one S1 is in a candidate the design gave a line and no design: *Same settings as…* copies the ids that name a document's own headnote and notes.
- The design's text was right about the core and wrong about five facts of the volumes and the index.
- Three findings changed what index version 76 stores, and the owner took all three into it the same day.

**Where the findings fall.** Most are in what the design left to its rows:
- the nine §8.1 candidates the owner took, which it describes in a line or two each;
- the blocks of §8.2;
- the three things the withdrawn §4.4 said, which have no home.

Few are in the core of §3 to §7.

---

## 0. What it found

Six reviewers returned **58 findings**, and the session's own reading of A2 made a 59th. Three skeptics tried to refute each against the code, the record, the boards and the public TEI. **None was refuted.** Merged, the count stands at:

| | Distinct findings | Answered by the owner already | Written into the design or a row's brief | Also put to the owner (C2) |
|---|---|---|---|---|
| **S1** | **1** | | 1 | |
| **S2** | **22** | 3 (index version 76) | 19 | 7 |
| **S3** | **25** | | 25 | 1 |

Merged, the 59 are 48 distinct findings.

- **Seven were re-rated down** by the skeptics, chiefly because a harm is recoverable, or the design already holds half of it:
  - INT-5, A11Y-5, A11Y-6, DATA-3, DATA-4 and EDI-7, from S2 to S3;
  - EDI-1, from S1 to S2.
- **Merges** joined findings that two or three reviewers made independently. The strongest is J1: INT, ENG and DATA each found *Same settings as…* from a different code path.
- **The skeptics listed 41 errors** in the design or the plan, **29 once merged** (§5). Seven are about the volumes or the index, and are corrected in the design with a mark. The rest are inconsistencies the owner's answers left between sections, and are corrected likewise.
- **Seven defects of the app as it ships were met on the way** (§6), none seen in a running app and none filed.

**What the findings say, in nine sentences.**

1. ***Same settings as…*, built as its brief reads, prints one document's headnote, research notes and title under another, and an edit or a delete through either loses the source's written headnote** (J1).
2. **The design rested on three readings of the index that did not hold.** It said a page reference "is stored under its page", and the index resolves it to a document. It took each list entry to be one term, and 200 give two spellings. It took a document's terms as the terms its page prints, and a quarter are linked only in notes. Version 76 now records the page resolutions, the spellings and the parts (decisions 188 to 190; J2 to J4).
3. ***Abbreviations & Terms* must key its rows and links by volume and the editors' id**, since one abbreviation means two things within a volume and across volumes (J5).
4. **The headnote in the collection file is not yet a defined thing.** Off does not travel, a 1.0 app prints a stand-in where the design says it prints nothing, and "with who wrote it" has no key and no true words for a recipient (J6 to J8).
5. **No row owns the export sheet's sentence**, the one thing that speaks at export since decision 156. A *Summaries* export already fails on a device without Apple Intelligence, even with every summary stored (J9, J11).
6. **Selected passages have no home once imported, and print unchecked** (J12).
7. **The iPad settings column restores what Composer v2 removed,** with no width rule and no fallback at the large text sizes (J13).
8. **Where the volume's heading leads, a reader moving by headings cannot tell documents apart** before 1952, where 77% of headings repeat within their volume (J16).
9. **Four claims about the volumes were false** (J21, J23, §5): "Central files are in" (from 1964 the grammar reads almost none), "the only pointers there are" before 1955, the 1952–1954 rule for the volume's own number, and "the volumes before 1952 print no document numbers".

---

## 1. Method

As the second review, with the index read first.

**Before the review, the design's text was brought to the owner's answers,** decisions 153 to 174, in a commit of its own (`b3542992`), so that the reviewers read what will be built. The reviewers were told the text was the session's, and that a misstated decision is a finding. One was found: the design's §4.4 read the plan's §1c as giving the headnote count to step 1's cards, where §1c gives it to the sheet's sentence (§5).

**A2 was read before anything else,** because the block reads a table that index version 76 stores and L26 builds, and L26 was in its landing runs (§2).

**Six reviewers**, each with one scope and the same brief (`collections-design-review-3/reviewer-brief.md`):

- interaction and comprehension (INT);
- engineering feasibility and regressions (ENG);
- stored data, sync and CloudKit (DATA);
- the `.fruscollection` file and the other carriers (FMT);
- editorial and scholarly integrity (EDI);
- accessibility (A11Y).

None was given the session's reasoning, only the design, the plan, the earlier reviews, the boards' source and the code. Each returned at most ten findings. Each finding came with what would refute it and where it is answered: the design's text, a row's brief, or the owner. Each reviewer also judged, in its scope, the plan's list of where the review starts.

**The severity scale** is the first review's:
- **S1** fails an ask, loses or corrupts work, states something false or unmarked to a reader of an export, or cannot be built.
- **S2** misleads a first-time user, falsifies a claim, breaks a clear accessibility rule, or hides a cost that changes a row's size.
- **S3** is real but secondary.

**Three skeptics** (`skeptic-brief.md`): A took INT and A11Y, B took ENG and EDI, and C took DATA, FMT and the review's own A2. Each re-read every cited line and looked for counter-evidence. Each recounted at least one TEI figure of every finding that rests on one. Verdicts: CONFIRMED, CONFIRMED and RE-RATED, PLAUSIBLE, REFUTED, NOT NEW, DUPLICATE.

**Three findings could not wait for the skeptics.** Each would change what index version 76 stores, and L26 was about to land. The session re-read each one's code, recounted its figures with a script of its own and put it to the owner. The owner took all three into version 76 the same day (§2). The skeptics then gave each a verdict like the rest, and each was CONFIRMED.

**Sources.**
- The code at `v2` (`b3acd7ad`). 1.0 (1861) at the tag `1.0-release` (`08e8bac8`), read by FMT. Index version 76 on `claude/plan-of-record-pr2011-2cc493`, which moved during the review (its decisions 188 to 190 at `78b172cf`, `254283cc` and `20eabba9`).
- The design at `0fa40e16` and the plan of record.
- The nine boards' source, read from the canvas. The boards predate the owner's answers, and the reviewer brief said which parts are superseded.
- Both manuals, the Agentic Analysis Guide and the two earlier reviews.
- The public TEI, all of it, on disk at corpus `216cdb764`. Every count was made with standard-library Python; the scripts are under `collections-design-review-3/scripts/`, one folder per agent.
- Fetched the same day by A11Y: pages of Apple's Human Interface Guidelines, Apple's `CGPDFTagType` page, WAI-ARIA 1.2's button role, the HTML parser's rule for a button, and a published test of tagged PDFs in VoiceOver.
- Read by skeptic B in the SDK on the Mac: `CGPDFContext.h`.

**What no one could do.** No app was built or run, and no device, simulator, Word or browser was opened. Another session's landing runs held the Mac's one heavy-job lock, and the row is planning only. These are marked as runs (§7):
- what CloudKit's mirror does with a field an older build lacks;
- what VoiceOver announces in a tagged PDF;
- every fit figure at the accessibility sizes.

**The reports themselves** are in `Planning/collections-design-review-3/`, as returned. A report's `SCRATCH/work-<name>/` is that folder's `scripts/work-<name>/`. Every `file:line` this document gives is one a skeptic re-read.

---

## 2. A2 first: what the block needed from index version 76, and what the review added

The plan had CR read A2 before L26 lands, since anything more the block needs from the index joins version 76 or waits for the build after 1.1 (its §1c). Three findings asked something of the index. Each was put to the owner as soon as the session had confirmed it, and each is in version 76.

| | The finding | The owner's word | In version 76 (L26's shape) |
|---|---|---|---|
| **Decision 188** (A2, J2) | `term_mentions` recorded that a document links a term, and not where. 124,491 of 497,026 document–term pairs (25.0%; 28.6% from 1955) are linked only in notes, so under four of the six templates the block would list terms the page omits. Where only the heading prints (*Summaries*, *Citations with your notes*), 99.2% of pairs name a term the page does not show. The design's example, the eight 1946 telegrams, links every term in its text | "Add it to v76" | `term_mentions.parts`: the text, the heading, a footnote, the source note, `@ana`. `termsLinked(inDocument:volumeId:)` returns `[LinkedTerm]` with `TermMentionParts` |
| **Decision 189** (DATA-2, J3) | A list entry that gives two spellings ("HAD or HD, Henry A. Dunlap") was one row, under the second spelling's id with the first's word. In 30 volumes, 809 linked pairs found no term and 335 showed the other spelling. For the 809, 1.0's reader opens "Term Definition Unavailable", whose advice to re-index the volume cannot help | "Add it to v76 (Recommended)" | One row per spelling, its word as printed, with the definition printed after the last spelling: 223 rows added over 200 entries |
| **Decision 190** (EDI-2, J4) | The index already resolves a reference to a printed page to one document (the one the note names, else the first on the page), and kept neither the page nor the choice. A4 would have printed about 12,600 first-of-several picks as the editors' citations, unmarked. Where the index could check such a pick, about two in five were a neighbour of the document meant | "Add it to v76 (Recommended)" | `cross_references.cited_page_id` and `page_resolution` (`one`, `range`, `number`, `day`, `first`), empty on every other row |

Each went to the L26 session with the owner's words and a note in the shared notes folder. The A2 measurement is `a2-what-the-index-owes.md`, with its script; skeptic C reproduced it exactly. Its three slips are corrected in the note:
- the "four in five" figure holds only for *Citations with source notes*;
- *SNIE* is linked in the text of `frus1969-76v06` d1 as well;
- "exact either way" fails for the 419 pairs on `@ana` alone.

**What the three leave to the rows.**
- **L52** owes the per-document parts through the blocks' data source, a rule for an `@ana`-only term, and rows keyed by volume and id (J5).
- **L51** reads the page resolution (J4).
- **L50's line** must count what A4 and A2 really fill from (J40).

**One pattern was checked and left out:** a persons-list entry with two `<persName xml:id>` (Alsop, Joseph and Stewart; Chou En-lai and Zhou Enlai). There are three in three volumes, with six links to the id the parser drops.

---

## 3. The findings, merged

Sources are the reviewer IDs. Each finding names where it is answered: "brief" is a row of the plan of record's §1c, where this review writes it; "the owner" is a question for C2 (§8).

### J1 (S1) — *Same settings as…* copies the ids that name a document's own records (INT-1, ENG-1, DATA-1)

- **The brief.** L47 says "one document's settings copied to others. It writes the fields 1.0 has", and §4.1's own table gives a document's title, date line, which notes and highlights, and headnote as its settings.
- **How the kit resolves them:**
  - chosen notes by id over every note the app holds (`CollectionContentAssembly.swift:1004-1011`);
  - the headnote by `source.summary(id:)` with no check of its document (`:1364-1366`);
  - highlights filtered to the target's own, so the source's ids leave the target none (`:1057-1060`).
- **What a target prints:** the source's headnote and research notes, its own highlights none. Its BibTeX, RIS and Zotero records carry the source's notes.
- **What an edit or a delete does:** an edit or a Regenerate through a target deletes the draft it points at (`CollectionEntryInspector.swift:1158-1173`), and so does a row's delete (`GeneratedSummary.swift:238-243`). So the source loses the headnote its author wrote.
- **Answered:** L47's brief names the fields copied and the fields never copied, the direction, what a following value does to a target's own, and where the action is.
  - Copied: text depth, the summary prompt, the six switches, the headnote switch.
  - Never copied: the title, the date line, the note and highlight selections, the headnote's draft.

### J2 to J4 (S2) — the index (A2, DATA-2 and EDI-1's 809, EDI-2)

Answered by the owner (decisions 188 to 190; §2). Still owed: the design's text for A2, A4, A1 and §8.1's item 10, rewritten here, and L50's, L51's and L52's briefs.

### J5 (S2) — *Abbreviations & Terms* is keyed by the abbreviation, which means different things (EDI-1, FMT-5)

- **Within one volume.** In `frus1946v11`, "BA" is Buenos Aires (`t_BA1`, d201 and d485) and the Division of Brazilian Affairs (`t_BA2`, eleven documents).
- **Across volumes.** 1,063 abbreviations have two definitions that share no word, and 6,592 term ids recur across volumes. `t_ADA1` is the Atomic Development Authority in `frus1946v01` and an Area Division in `frus1948v09`.
- **The design never says how a row is keyed.** L52 says "as the Persons Index reads the people's", and that block merges across volumes (`CollectionGeneratedBlocks.swift:538-545`).
- **Decision 174's link needs an anchor nothing has.** A block row has no id (`CollectionExporter.swift:1196-1218`), and a block can be placed twice (`CollectionEditorView.swift:1349-1356`).
- **The store's own key is `(volume_id, ref)`**, which is why the skeptic re-rated this S2.
- **Answered:** L52's brief keys rows and anchors by block instance, volume and id. It names the volume beside a definition where the collection spans volumes, and links a term only where its row exists.

### J6 (S2) — the collection file cannot carry a headnote switched Off (FMT-1)

- **The writer omits Off:** it writes `includeHeadnote` only when on (`NativeCollectionFormat.swift:517-520`, pinned by `CollectionTests.swift:3939-3942`).
- **So Off arrives On:** the reader turns an absent key into Default (`:757-760`), which inherits the collection's on.
- **Under decision 166** an Off entry's abandoned draft would print at the recipient's. Neither §7.4 nor L43 gives a section's headnote default a key or a rule for Off.
- **Answered:** L43's brief writes Off as Off, for documents and sections. The owner is asked whether decision 166's "always" covers a headnote switched off (§8, C2-2).

### J7 (S2) — §7.4's "a 1.0 app that opens the new file shows no headnote" is false (FMT-2)

- **What 1.0 does:** with no id that resolves, it falls back to "any stored summary (or the placeholder)" (`NativeCollectionFormat.swift:227-231`; `CollectionContentAssembly.swift:1348-1382`).
- **What it prints:** in every format, an AI summary under *Headnote*, or "No stored summary for this document — generate one in the document view to fill this headnote." On the author's own 1.0 devices that replaces every headnote they wrote.
- **Answered:** §7.4's text states it. L43's brief, if "no headnote" is to be made true: the headnote's state goes under a key 1.0 does not read, and the two keys it does read are no longer written.

### J8 (S2) — "its text, with who wrote it" names no key and has no true words for a recipient (FMT-4, EDI-6)

- **A structured draft is JSON:** it "stores a JSON object" (`StructuredSummaryDisplay.swift:15-16`), so it prints as JSON unless its format travels too.
- **The authorship's three values are worded for the device's user:** "Yours" (`CollectionEntryInspector.swift:1033-1045`) and "AI-generated summary, edited by you" (`CollectionExporter.swift:1127-1137`). So a recipient's export presents the sender's headnote as the recipient's own, and §3.6's Note credits it to the compiler.
- **The Guide's §15.1a limit,** "Headnotes cannot be supplied", stops being true.
- **Answered:** L43's brief names the keys (text, format, authorship) and what an import makes of a sender's authorship, and brings the Guide's §15.1a to it. The attribution's words are the owner's (§8, C2-3).

### J9 (S2) — no row owns the export sheet's sentence, and 1.0's does not fit at AX5 (INT-3, A11Y-4)

- **Three homes for the headnote count.** The plan's §1c gives it to the sheet's sentence (`:425`), L44's brief to L44's cards (`:680`), and the design's §4.4 (before this review) read §1c as L44's. L50's brief drops the sheet's line §1c gives it.
- **1.0's sentence is not true at export:** it reads the collection's defaults and says "with headnotes" over documents that have none (`Collection.swift:240-259`).
- **It does not fit:** at AX5 on an iPhone SE it does not leave the format and Export in view, which L35's own check requires. In 1.0's iOS sheet Export is inside the form, not pinned (`CollectionExportSheet.swift:373-394`).
- **Answered:** the owner, at C2 (§8, C2-1). The session's reading is that L35 takes the sentence, written from what the export will print, and holds it at AX3 and AX5. L44's cards may add a template's needs.

### J10 (S2) — the design's "no placeholder line is printed in an exported file" is in no row (INT-3, FMT-2)

- **All three exporters print it:** "No stored summary for this document — generate one in the document view to fill this headnote." (`CollectionItemHTMLRenderer.swift:463-466`; `DocxCollectionExporter.swift:2068-2073`; `PDFCollectionExporter.swift:923-929`). Those are words for the author, in a file made for a reader.
- **Answered:** L34's brief, which rewrites how all three draw a document.

### J11 (S2) — a *Summaries* export fails without Apple Intelligence, even with every summary stored (INT-2)

- **The guard runs first.** `resolveSummaries` opens with `guard AppleIntelligenceProvider.shared.isAvailable else { throw ExportError.renderingFailed }`, before it looks for a stored summary (`CollectionContentResolver.swift:776-778`).
- **The preview does not ask** (`CollectionContentAssembly.swift:1435-1447`). So the preview shows every summary, and Export ends in "The export could not be rendered."
- **The prompt's error is wrong too:** it names a "Composition section" no screen has (`:40-42`).
- **This is a 1.0 defect.** Its file is outside L35's.
- **Answered:**
  - L35's brief: the sheet says, before Export, what this export needs that this device lacks.
  - L44's: the prompt error's words.
  - The guard's order goes to the owner, to be filed (§6, §8 C2-8).

### J12 (S2) — selected passages have no home once imported, and print unchecked (DATA-5, FMT-3)

- **L46 says two things that cannot both hold:** "Nothing new is stored in CloudKit" and "the passages travel in the collection file as text".
- **No field can keep them.** A document entry's `text` is nil by rule (`Collection.swift:663-666`). An import gives an empty highlight list, which means all of the recipient's own (`NativeCollectionFormat.swift:755`, `:55-58`).
- **Kept as frozen text, they would print unchecked,** as the volume's words, without the check an excerpt gets (`CollectionExportSheet.swift:519-522`).
- **Answered:** L46's brief says where an imported passage is kept and which prints when an entry has both. It runs the excerpt check over passages from a file. A new property joins the promotion and version 8.

### J13 (S2) — the iPad's settings column brings back what Composer v2 removed, with no width rule (INT-4, A11Y-3)

- **Composer v2 removed this column:** it dropped "a persistent metadata/composition `.inspector` column" so that "the reading surface stays clear" (`CollectionEditorView.swift:832-836`; `fa28f2d3`).
- **L45 says only** "A settings column on the iPad".
- **Browse met the same case and wrote a width rule** (`BrowseTwoPaneMetrics.swift:27-35`).
- **Built as the R6a rail, it is 280 pt wide at every size** (`:97-100`). At AX5 the eight pickers alone take about three landscape screens of a 13-inch iPad, and the drawn opening as much again above them.
- **The design contradicts itself:** §5.4 still gave the iPad "settings as sheets".
- **Answered:**
  - L45's brief: the widths at which the column shows and gives way, what it does at AX3 and AX5, and the iPad suite's devices.
  - The design's §5.4 and §5.7, corrected.

### J14 (S2) — step 2's one-tap *Add* is a shortcut that also removes (INT-6)

- **"A shortcut does both"** (§4.3). The offer on step 2's row is drawn as "…Bibliography, Sources & Archives. Add.", away from the ticks and their Undo.
- **Answered:** L44's brief says whether the tap replaces or adds, labels it by what it does, and puts its Undo where the change shows on each platform. If the tap only adds, this is S3.

### J15 (S2) — a saved template holding "both steps" breaks decision 157, and has no place (INT-7)

- **L47 leaves the owner** "step 1's seven settings … or both steps".
- **Nothing says where saved templates live:** where they are listed, applied, renamed or deleted, or how the "six recipes" comparison and *Suggested for…* treat one.
- **Answered:** L47's brief. The owner chooses what a saved template holds, told that "both steps" changes step 2 from step 1 (§8, C2-4).

### J16 (S2) — where the volume's heading leads, headings do not tell documents apart (A11Y-1, with EDI-7)

- **How often headings repeat.** 56.4% of documents share their heading's words with another document of their volume: 77.1% before 1952, and 45 times over for one heading of `frus1946v06`.
- **Who meets it.** Decisions 158 and 159 put the heading first in four templates and every new collection. A reader moving by headings skips the citation line, the one line that differs.
- **§3.8 was wrong:** its "region named by its heading" names them all alike.
- **Under *Summaries*** no date stands at a document's head either (EDI-7, S3).
- **Answered:** L34's brief. A heading or region carries something a navigator hears that differs (the citation's number), Word keeps the citation line with its heading, and a kit test covers the HTML and the Word package. Where the text does not print, the dateline prints under the heading's words. §3.8 is corrected.

### J17 (S2) — at AX3 and AX5 a template's changes and their *Undo* are out of view (A11Y-2)

- **The design's basis for dropping a template's question:** each change is "shown where it is made" (its head).
- **On an iPhone at AX5,** the line, its Undo and the changed settings sit one to four screens below the tapped card. Step 2 has no line or Undo on any board or in any check.
- **Answered:** L44's brief puts each step's line and Undo where the choice is made, and adds what is in view after a choice to its fit suite.

### J18 (S2) — the Note on the Text cannot be "a block and nothing else" through the block seam (ENG-2)

- **The seam is too thin for it.** A block gets the membership alone, read-only, in its row's place (`CollectionGeneratedBlocks.swift:155-160`; `CollectionContentAssembly.swift:957-968`). An empty block prints "Nothing to list" (`:184`), which `generatedBlockEmptyStates` holds for every type.
- **The Note needs every entry's resolved title, date line, depth and switches,** and must print nothing when it has nothing to say.
- **Answered:** L43's brief makes the Note a rule over the resolved entries, outside the block seam, shared with §3.6's line in the settings. §3.6 is corrected.

### J19 (S2) — a tagged PDF is a rewrite of the PDF's drawing, on an API newer than the app's floor (ENG-3, with A11Y-8)

- **The PDF draws in frames, not elements.** A document's body is one attributed string drawn frame by frame with one `CTFrameDraw` each (`PDFCollectionExporter.swift:796-847`, `:1494`). A tag brackets draw calls (`CGPDFContext.h:442`), so tagging a heading inside a frame means drawing it as its own run.
- **The new API is too new.** The structure-tree API and `CGPDFTagTypeArtifact` are `API_AVAILABLE(macos(27.0), ios(27.0))` (`:397`, `:480`), and the app targets 26.0 (`project.yml:78`).
- **L48 tags too little** (A11Y-8): it names neither the tables (drawn as cells joined by " | "), the figures, the page numbers nor the language.
- **Answered:**
  - L34's brief draws each plan line as its own run, carrying its role.
  - L48's brief builds on `CGPDFContextBeginTag`, or gates by OS. Its proof is the exporter's own document crossing a page break, and it names what it marks beyond the plan's lines.

### J20 (S2) — L43's new settings repeat #1997, since L36 closes the preview's refresh list before they exist (ENG-4)

- **The preview's hash is kept by hand** (`CollectionPreviewView.swift:210-266`), and no test reads it.
- **The plan gives the follow-up to the wrong row.** Its third departure gives it to "lane 4", which is L44 and stores nothing. L43's brief and file list never name the preview.
- **Answered:**
  - L43's brief adds each new setting to the list. So do L48 and L49 if either keeps a choice on the collection.
  - L36 adds a test that walks the two models' stored properties against the list.
  - The departure is corrected.

### J21 (S2) — A3's "Central files are in" holds for the decimal file alone, which ends in 1963 (EDI-3)

- **What the grammar reads:** lots and libraries (`FootnoteCitationGrammar.swift:71-77`), and decimal classes with a serial (`IndexingPipeline.swift:6734-6739`).
- **What it misses from 1964:** 11,659 of the 21,020 footnotes that name a file name only kinds it does not read, such as subject-numeric files and the Central Foreign Policy File. From 1977, 5,976 name the Central Foreign Policy File alone.
- **Before 1955 central files are not the only pointers:** 2,556 footnotes name a lot or a library.
- **Answered:** L53's brief says on the page which kinds are listed for which years. The block's title is the owner's (§8, C2-5). §8.2's A3 is corrected.

### J22 (S2) — A12's table counts text the export does not print, by rules the device sets (EDI-4, with ENG-8 and FMT-6)

- **It counts every document's whole text with its footnotes:** `bodyText` at every depth, under the device's lemmatiser, tuning and hidden words (`WordCloudExport.swift:158-172`; `WordCloudSettings.swift:29-49`).
- **It counts text that never prints:** a *Summaries* export prints summaries, and its table counts texts and notes.
- **It is unbounded:** every term counted once or more, about 2,300 forms for the eight telegrams.
- **It never reaches the PDF,** which draws the cloud from another path (`PDFCollectionExporter.swift:208-212`).
- **Answered:** L55's brief.
  - The table lists the terms the image places, the cloud's own accessible list (`KeynessCloud.swift:40-41`).
  - It says what was counted.
  - It says whether the PDF prints it, and the parity suite holds the three formats to that.

### J23 (S2) — the rules for the volume's own number are false both ways (EDI-5)

- **Numbers before 1952:** 13,669 headings in 39 volumes open with a number, and 6,091 of those numbers differ from the document's `@n`. For example, `frus1874` d100 prints "No. 98.".
- **No numbers in 1952–1954:** 16 of the 28 volumes print none.
- **So the design's rules fail:** "From the volumes for 1952–1954 on" (§3.3, §3.4) and "the volumes before 1952 print no document numbers" (§3.6) are false, and the one reading needs a rule by the number's form.
- **Answered:**
  - L34's brief reads a leading number by its form in every volume and keeps it in the *As published:* line.
  - L43's brief does the same for the Note's sentences.
  - Which number a citation names is the owner's (§8, C2-6).
  - §3.3, §3.4 and §3.6 are corrected.

### 3a. The S3 findings

| | Finding (sources) | Answered |
|---|---|---|
| J24 | A section's headnote default cannot ride `includeHeadnote`: headings made under the builds of 2026-07-01 to 07-11 hold an explicit `false` that no screen showed (DATA-3; the section half of FMT-1). **Settled:** a new optional property, read on headings only; the sixth field of the promotion | L43; the design's §4.1 and §7.1; the plan's §1c |
| J25 | A 1.0 device re-sends every entry record on a reorder, a delete, Sort by Date or an added block (`CollectionEditorView.swift:2262-2264`; `CollectionEntryData.swift:296-302`), so all of a collection's date lines go through 1.0's save at once; the run owed renames, which writes no entry (DATA-4) | §7.2 and §12; the plan's §2 and R12: the run drags a document on 1.0 and reads every date line |
| J26 | A new collection (decision 159) equals no template, and ties at two differences between *Full text as printed* and *Summaries*; the Mac's New Collection menu has no item for it (INT-5) | L44; §4.3 |
| J27 | §5.5 counts Wording at 10 where L51 adds each new block's title (13), and 51 controls where it is 54; the taken candidates' controls are placed nowhere (INT-8) | §5.5 |
| J28 | Each of L48's page choices has a 1.0 value that differs by format, so "what 1.0 prints stays the default" has no single value to show (INT-9) | L48 |
| J29 | Selected passages: which highlights make them (*Highlights in body*, the per-highlight switch); the cut made once in the kit with the notes the passages call; and the omission sign's word checked against the volumes' own bracketed "[omission]", printed 309 times (INT-10, ENG-10, EDI) | L46 |
| J30 | §11's "one control a row" is false: step 2's row opens a screen and offers *Add* (A11Y-5) | §11; L44 |
| J31 | §11's "a check for each lane that has a screen" is false: §9's table has no row for lane 7 or for the new blocks' ticks and links (A11Y-6) | §9 and §11; each row's brief |
| J32 | No heading rule for a document inside a section or for an attachment: a titled document's volume heading becomes a peer of its 23,768 attachments' headings, and three levels of section reach a seventh level (A11Y-7) | L34 |
| J33 | The only drawing of *Show Parts* makes each part a button, which would hide its links and footnote calls (A11Y-9) | L45 |
| J34 | Beside a working term link, 1.76 million person links still lead nowhere, and in the preview a term's link jumps the page (A11Y-10) | L52; L45 |
| J35 | A new read on the blocks' data source has eight conformers, not two, and A3's is the very query the Archives Visit packet's refinement keeps out (ENG-5) | L50, L53, L54; §9 |
| J36 | `everyApparatusBlockInTwoTemplates` runs over `allCases`, so the Note and A2 to A4 turn it red (ENG-6) | L43; §9 |
| J37 | L44 owes the 24 template blocks of `08-Reading-Research-Collections.md` and its 28 ranges, and three UI tests drive the Section Defaults surface it removes (ENG-7) | L44 |
| J38 | §3.4's outline line is in no row, and if L34 takes it, L34 and L35 both edit `MacCollectionManagerView.swift` (ENG-9) | L34 |
| J39 | No row copies a smart collection's own blocks into its snapshot, and L43's walk read literally would copy `savedSearchId` (DATA-6) | L29; L43 |
| J40 | A1's line counts A2's documents from any part and `@ana`, and A4's from document references alone; the blocks list from what prints and from page references (DATA-7, EDI-2) | L50; L52 |
| J41 | A date line can be stored with no title (1.0 clears a title and keeps it); no rule says what prints (DATA-8) | L43 |
| J42 | §8.1's item 2 gave a saved template "a deploy of its own", and the plan quoted words §4.1 no longer has (DATA-9) | §8.1; the plan's §1c |
| J43 | A 1.0 reader of a 1.1 file prints each title of the author's alone, with no citation at Summary and Index depth (#1998), which §7.2's "nothing 1861 prints is false" leaves out (FMT-7) | §7.2 and §7.4 |
| J44 | Decision 165 takes the records' title to the new reading, and their "Document date:" line still reads the top level alone, which finds no dateline for 291,438 of 314,616 documents (FMT-8) | L34; the owner (§8, C2-7) |
| J45 | The research export leaves out every headnote unless AI summaries are included, so a restore from a default file loses them (FMT-9) | L43 |
| J46 | In *Citation* contents rows a title and date line of the author's stand without *As published:* (EDI-8) | L34 |
| J47 | A8's class key spans the renumbering of 1 January 1950 (127 keys cited on both sides), and one caveat serves two kinds of scan (EDI-9) | L54 |
| J48 | A11's heading falls on a day that the app gives to both presidents: 26 documents dated 12 April 1945, 17 dated 9 August 1974, and 3,229 ranges straddle a change (EDI-10) | L54 |

---

## 4. Found sound

Each was attacked by a reviewer and held, and a skeptic agreed:

- ***As published:* is true of every manifest volume.** 550 are published and 3 partially published, and the TEI of those three holds published documents only.
- **Unticking a block loses only its place** (`CollectionEditorView.swift:1907-1927`).
- **`any CitationFormatter` in the batch is a change of type and nothing more** (`CitationFormatter.swift:20-22`).
- **Leaving out the pre-1955 source note's footnote copy moves no highlight,** since footnote bodies are not flat text.
- **A8 needs no index version:** `document_sources.decimal_class` is stored, and the block's read leaves it out.
- **The new blocks survive 1.0:** an unknown block type is kept, skipped and re-exported intact.
- **The collection file keeps version 2 with a floor of 1:** a new file opens in 1861 and passes the Guide's checker. The headnote is the exception (J7).
- **A field cannot reach an archive unpromoted:** the archive requires every identifier awaiting deploy (`check_cloudkit_schema.py:151-153`).
- **1.0 reads selected passages as the full text** (`CollectionExporter.swift:307-311`).
- **Today's 24 controls and the ten that open the settings recount;** step 2's 17 holds.
- **"The documents that use it" is close to the uses:** 2.8% of uses of a long abbreviation go unlinked in their document.

---

## 5. Errors in the design and the plan

Each is corrected in the design's text with a mark, or in the plan where the plan is wrong.

| | The error | Corrected in |
|---|---|---|
| 1 | §8.1's item 10, A1's table and A4 say a page reference "is stored under its page" (`CrossReferenceStore.swift:757-759`, which is a comment on another read). The index rewrites it (`IndexingPipeline.swift:10697`), so 1.0's See also line already matches same-volume page references | §8.1, §8.2; L51 |
| 2 | A3's "Central files are in … the only pointers there are" before 1955 | §8.2 A3; L53 |
| 3 | The volume's own number "from the 1952–1954 volumes on", and "the volumes before 1952 print no document numbers" | §3.3, §3.4, §3.6 |
| 4 | §3.8's "a reader moving by headings is told which document the line belongs to" | §3.8 |
| 5 | §7.4's "a 1.0 app that opens the new file shows no headnote" | §7.4 |
| 6 | §7.2's "nothing 1861 prints is false" leaves out #1998's unmarked titles; and what is at risk is every entry-level value, not four | §7.2 |
| 7 | §4.4, as brought to the answers, read the plan's §1c as giving the headnote count to step 1's cards; §1c gives it to the sheet's sentence and L44's brief to L44 | §4.4; the plan's §1c and L44 |
| 8 | §4.4 and §11 H11 promise no placeholder in an exported file, which no row does | L34 |
| 9 | §5.4 gives the iPad "settings as sheets, as now", against §5.3 and decision 164 | §5.4 |
| 10 | §5.7 lists four withdrawn arrangements and leaves out Composer v2's removal of the iPad's settings column | §5.7 |
| 11 | §5.5's Wording count (10) and total (51); and a section's sheet holds seven pickers, not six, with its headnote default | §5.2, §5.5; L44 |
| 12 | §11's "one control a row" (A11Y-6) and "a check for each lane" (A11Y-7) | §11 |
| 13 | §11's "ENG-5, FMT-6 … Named | §9, §7.4": §9 does not name the outline rows | §11 |
| 14 | §11's "the records are Q9": Q9 settled the title; the records' date line stands | §11 |
| 15 | §3.6's "only if it has something to say" against the block seam, which never renders empty | §3.6 |
| 16 | §5.1's "Export, the one button pinned under the list" under "the sheet 1.0 has": 1.0's iOS Export sits inside the form | §5.1; L35 |
| 17 | §5.1's "*Export…* then *Export* is that export" is false after a Zotero send, which is a row, not a format | §5.1 |
| 18 | §8.1's item 2, "with a deploy of its own"; the plan's §1c quoting §4.1's lost words | §8.1; the plan's §1c |
| 19 | §8.2 A2: its "Reach" of 113,012 documents is the version-75 file's (version 76's reads 113,026); "each in the words of the volume's own List" was false for 200 entries until decision 189; and its `@ana` sentence against the rule that a term lists where a part that links it prints | §8.2 A2 |
| 20 | §8.2 A1's first bullet: the eight telegrams' See also line is empty because their same-volume page references resolve outside the collection, not because none cites by document | §8.2 A1 |
| 21 | §4.5 has the snapshot carry the smart collection's blocks; L29's brief asks only what the code already does | L29 |
| 22 | The plan's third departure gives the preview's refresh list to "lane 4", which stores nothing | the plan's §1c |
| 23 | §9 and L50: "two fixture data sources … which both must answer"; there are eight conformers | §9; L50 |
| 24 | §9 and L44: `CollectionTests.swift:3450-3565` "goes on holding" decision 139's table; it runs over `allCases` | §9; L43 |
| 25 | The plan's §1c, *The promotion*: "a heading made before the Composer redesign" leaves out its copies (Duplicate, Import from JSON) | the plan's §1c |
| 26 | L51: "for a collection of them the line prints more than it did"; for same-volume references it already prints them | L51 |
| 27 | L46 gives the omission sign the design's reason, that words "collide with nothing the volumes print"; the volumes print "[omission]" 309 times, with variants, in brackets, which the design already rules out. So the reason holds only for a word the volumes do not print, and the chosen word must be checked against them (skeptic B: overstated as a collision) | L46 |
| 28 | The design's head said the canvas's boards print *In the volume:*; four more board lines are superseded: `SectionSheet.dc.html:50` and the three "Not set above: Off" for See also | the head of the design |
| 29 | The design cited neither decision 188 nor 189 | §8.2 A2 |

---

## 6. Defects of the app as it ships, met on the way

None was seen in a running app, and none is filed. Each needs the owner's word to file (the plan's §0).

1. **A *Summaries* export fails on a device without Apple Intelligence even with every summary stored**, since the guard runs before the stored summaries are read (`CollectionContentResolver.swift:776-778`; J11). Its error for a missing prompt names a "Composition section" no screen has (`CollectionContentAssembly.swift:40-42`).
2. **Every export prints, to its reader, an instruction meant for the author** where a requested headnote has nothing stored (J10).
3. **The research export leaves out every headnote unless AI summaries are included,** so a restore from a default file loses the headnotes an author wrote (J45).
4. **A tap on the first spelling of a two-spelling term opens a false "re-index this volume" sheet** in 27 volumes. Decision 189 ends it at the re-index to version 76, so it needs no issue.
5. **An exported collection file turns a headnote switched Off into On at the recipient's** (J6).
6. **The records' "Document date:" line reads the top level alone,** so 291,438 of 314,616 documents' records carry none (J44).
7. **In the web page every person's name is a link no browser can follow,** and an untagged name a link to `#` (A11Y-10). The app's own comment calls these links "always inert" (`AppActivityTypes.swift:43-47`).

The session's reading: 1 is a row's work and could join L35, if the owner widens L35's files, or a small row of its own. 2, 3, 5 and 6 are in L34's and L43's briefs already and need no issue. 7 is L52's to settle with decision 174.

---

## 7. Runs owed, each needing a device, an app or an opened file

| When | The run | For |
|---|---|---|
| Before L43 | The two-device run of the design's §12, widened. On the 1.0 device, drag a document and Sort by Date, besides the rename; then read every date line on the new build | J25 |
| Before L43 | A hand-made file with `"includeHeadnote": true` and no id, imported into 1861 and exported as a PDF | J7 |
| Before L35 | On a Mac with Apple Intelligence off, export as PDF a collection at *Summary only* whose summaries are all stored | J11 |
| In L35 | The sheet at AX3 and AX5 on an iPhone SE and an iPhone 17, with its sentence and grid as L35 changes them | J9 |
| In L34 | The eight telegrams under *Full text as printed*, moved through by headings and by landmarks with VoiceOver in Safari, and in Word's Navigation pane | J16 |
| In L44 | Step 1's card and step 2's *None* at AX3 and AX5, with what is in view after each | J17 |
| In L45 | The iPad's column on an iPad Pro 13-inch and an iPad mini at AX3 and AX5 | J13 |
| In L48 | A two-page proof on the exporter's own drawing, crossing a page break, tagged with `CGPDFContextBeginTag`, read with VoiceOver on a Mac and an iPad | J19 |
| In L55 | The app's own count of terms for the eight telegrams, after stopwords and lemmas | J22 |

---

## 8. What C2 is asked

Each with the session's recommendation. The rest of the findings are written into the rows' briefs.

**Answered on 2026-11-26,** in the CR session, one at a time. The answers are the plan of record's decisions 191 to 198. The owner took the recommendation on six. For C2-3 the owner chose the compiler's name. For C2-5 the owner asked that the grammar read the post-1963 central files, in index version 76, over the recommendation of a row after 1.1. Each answer is under its question.

- **C2-1. Who says, at export, what the export will print** (J9)? *Recommended:* L35 takes the sheet's sentence, written from what the export prints. That covers the headnote count, what this device lacks for the template and, if L50 proposes it, what a block cannot fill. L35 holds it at AX3 and AX5, and L44's cards may say a template's needs as well. *Or* L44's cards, as L44's brief has it. **Answered:** L35 (decision 192).
- **C2-2. Does decision 166's "always" cover a headnote switched off** (J6)? *Recommended:* no. Off travels as Off, and an Off entry's draft does not travel. **Answered:** no (decision 193).
- **C2-3. The words that say who wrote a headnote,** for any reader (J8). *Recommended:* the compiler, Apple Intelligence, or Apple Intelligence edited by the compiler; never "you"; the file carries which of the three and the draft's format. *Or* the compiler's name, typed once in the collection's settings. **Answered:** the compiler's name (decision 194). Each headnote then carries its writer's name, and the promotion is seven fields or eight.
- **C2-4. What a saved template holds** (J15). *Recommended:* step 1's seven settings, as each of the six holds, so that decision 157 holds for it. *Or* both steps, applied as two choices. **Answered:** step 1's seven settings (decision 195).
- **C2-5. A3's title,** since it lists lots, libraries and decimal files only (J21). *Recommended:* a title of the kind "Archival files cited", with a line on the page saying which kinds are listed for which years. The words are the owner's. **Answered:** the owner first asked whether the grammar could read the post-1963 central files, and had it do so in index version 76 (decision 191), with the title *Archival files cited* (decision 196).
- **C2-6. Which number a citation names** where the volume's own printed number differs from history.state.gov's (J23; 6,091 headings before 1952). *Recommended:* the citation keeps history.state.gov's number, as 1.0 does, and the *As published:* line keeps the volume's. **Answered:** so (decision 197).
- **C2-7. Does Q9's yes also take the records' "Document date:" line to the new reading** (J44)? *Recommended:* yes, said in L34 among what a send or a file carries. **Answered:** yes (decision 198).
- **C2-8. Filing:** the 1.0 defect of §6's item 1, as an issue for L35 or a small row of its own. *Recommended:* file it, and let L35 take it with its files widened. **Answered:** filed as #2018, for L35 (decision 198).

---

### 8a. C2's rest, answered the same day

- **C2-9, the re-cut:** L43, L45 and L48 are each split in two (decision 199).
  - **L58** takes the Note on the Text, the statement of sources and the collection file's keys.
  - **L59** takes the iPad's settings column and the drawn opening.
  - **L60** takes the tagged PDF, and lands last.
- **C2-10, the pace:** decisions 147 and 148 stand (decision 200). The owner was told the submission falls about 2026-12-22, inside the week App Review ran slowly in 2024. The Office has said early December, with no day.
- **C2-11, the design:** accepted as reviewed (decision 201). Its head reads ACCEPTED, and the plan's rows are what is built.
- **C2-12, a person's name in the web page:** it links like a term, to its Persons Index row where that block is, and is plain text elsewhere (decision 202, in L52).

## 9. Cost

Nine agents on Opus 5.5, as the owner chose ("Nine agents (Recommended)"). The harness reported, for each:

| Agent | Tokens | Tool calls | Minutes |
|---|---|---|---|
| INT | 507,631 | 109 | 26 |
| ENG | 560,835 | 123 | 34 |
| DATA | 541,355 | 119 | 36 |
| FMT | 530,021 | 151 | 35 |
| EDI | 634,047 | 184 | 58 |
| A11Y | 533,089 | 109 | 34 |
| Skeptic A | 486,869 | 104 | 23 |
| Skeptic B | 545,258 | 136 | 34 |
| Skeptic C | 529,570 | 130 | 30 |
| **All nine** | **4,868,675** | **1,165** | |

The account's weekly limit for all models stood at 17% before the review and at 24% after it, this session's own work included. Fable's stood at 29% both times.

---

## 10. Files

- **This document.**
- **`Planning/collections-design-review-3/`:**
  - the two briefs;
  - the six reviewers' reports (`reviewer-*.md`) and the three skeptics' (`skeptic-*.md`);
  - A2's measurement (`a2-what-the-index-owes.md`, `a2_where_terms.py`);
  - every agent's scripts, under `scripts/`.
- **The design,** `Collections-Customization-Design-2026-11-25.md`, brought to the owner's answers (`b3542992`), then to A2's finding (`0fa40e16`), then corrected and answered where this review says so.
- **The plan of record's §1c,** where the briefs of L29, L34 to L36 and L43 to L55, CR and C2 carry what this review sends them.
- **The shared notes folder** of the plan's session, with the three hand-overs to L26: `cr-a2-term-parts.md`, `cr-terms-two-spellings.md` and `cr-pages-resolution.md`.
