ID: FMT-1
Severity: S2
Claim: §7.6's "version 3, which a 1.0 app refuses" is required by nothing in the format; the format's two rules, its tests, the Guide, both manuals and the record's own first form all keep a new file openable by 1.0, and §7.7 understates the cost because this form closes the other two carriers in the same direction.
What a person meets: A teacher on the new version sends a class a reading list as a `.fruscollection`, the use both manuals name. Every student still on 1.0 is refused, though the list is documents under two headings and uses no new setting. A person with the new version on an iPhone and 1.0 on an iPad has no way to put a collection made on the phone onto the iPad: it "does not appear on a device running 1.0" (§7.5), "a version-7 importer refuses a version-8 file whole" (§7.6), and the file is refused (§7.6).
Evidence:
- The floor's rule: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/NativeCollectionFormat.swift:91-93 "Writers raise it only when *ignoring* a field would corrupt meaning, never for degradable features"; :657-659 "degradation never raises the floor (Migration rule 3)"; /home/user/FRUS-Explorer/Planning/Completed/Collections-Authoring-Scope.md:177-178.
- The version's rule: NativeCollectionFormat.swift:448-454, :610-652. Five rounds of additions since version 2 raised neither number (:37-73).
- The file is "decoupled from the SwiftData `@Model` types, so the file schema can evolve independently of the persistence layer" (:24-25), and is read once into a record with fresh identity (:679-683). §7.1's reason for a clean break is two builds writing one synced record, which a file never is.
- A version-3 writer with a floor of 1 is already a pinned case: /home/user/FRUS-Explorer/FRUSExplorerTests/CollectionTests.swift:2946-2960 ("A hypothetical v3 writer ... minimumReaderVersion 1 because it is all degradable"), :2993-2995; published in /home/user/FRUS-Explorer/Docs/Agentic-Analysis-Guide.md:2960-2963.
- The manuals promise it: /home/user/FRUS-Explorer/Docs/iOS-User-Manual.md:1152 and /home/user/FRUS-Explorer/Docs/macOS-User-Manual.md:897, "a collection using no newer features is written in a form older app versions open unchanged"; the class use at iOS :1596, macOS :1380.
- The first form kept it (`git show aad7636:Planning/Collections-Customization-Design-2026-11-25.md`, line 243: "the file's `minimumReaderVersion` stays 1"; line 248), and the review found it sound (/home/user/FRUS-Explorer/Planning/Collections-Design-Adversarial-Review-2026-11-25.md:220, "a reader that ignores the keys prints more, never less"). §11's list of what "this form still relies on" drops it with no row. Under §3.1 nothing the volume prints is ever left out, so that argument is stronger now.
- The record's reason (§7.6): writing the minimum "would need a second function from the new values back to the old. This design does not propose it: one-way is what the owner offered." The offer was of "a new model type" and a one-way "conversion". Lane 3 needs that reading anyway, to show the new three-way value in today's two switches and Default/On/Off pickers (§9, lane 3; /home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionCompositionRows.swift:89-96).
Refutation: a setting of §4.1, §4.3 or §5.2 that a 1.0 reader would misread, not merely ignore. I went through each (the table below) and found none.
Direction: Keep both of the format's rules for version 3: the keys 1.0 reads written beside the new ones, and a floor of 1.

ID: FMT-2
Severity: S2
Claim: What build 1861 does with a version-3 file is not what §7.6 says unless three things the record does not state hold, and one of them needs the back-mapping §7.6 declines.
What a person meets: On 1.0, someone opens a colleague's file and reads "The data couldn't be read because it is missing" (text from memory, not fetched), or an alert with a title and no message, where the record promises "Update the app to open it."
Evidence:
- The reader decodes the whole struct before it looks at any version: NativeCollectionFormat.swift:435, then :436-438, then the gate at :439-442. `format`, `formatVersion`, `name`, `entries`, each entry's `kind`, and `composition` with six members are not optional (:80, :84, :96, :116, :118, :150, :154, :163, :165, :167, :169, :201; the Guide says so at :2806, :2837). A file without them throws a `DecodingError` and never reaches the gate.
- A `DecodingError` is a Cocoa error 4865 or 4864 (fetched today: swiftlang/swift, stdlib/public/core/Codable.swift:3740-3747, saved under review2/fetch-FMT/). All three import paths show `error.localizedDescription` (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionListView.swift:304-306; /home/user/FRUS-Explorer/FRUSExplorer/Collections/MacCollectionManagerView.swift:505-507; /home/user/FRUS-Explorer/FRUSExplorer/App/FRUSExplorerApp.swift:2477).
- §7.2 makes the eight composition fields "one value"; §7.6 proposes no function "from the new values back to the old". Six required keys then have no source.
- The gate reads `minimumReaderVersion ?? formatVersion` (:439). A writer that keeps today's `minimumReaderVersion: 1` (:659) is not refused: 1.0 opens the file and silently drops every new key.
- The open-with path, "the path a shared file most often arrives by" (FRUSExplorerApp.swift:2463-2464), has two alerts on one flag: :2219-2225 with no message, :2235-2243 with one. NEEDS A RUN: which one 1861 presents.
Refutation: a custom `init(from:)` or an earlier version check. There is none; the struct's coding is synthesized (:76-310).
Direction: Before the format is fixed, open a hand-made version-3 file in 1861 by each of its three paths, and write into §7.6 the keys every version-3 file carries and the floor it declares. §12 owes this run and does not list it.

ID: FMT-3
Severity: S2 for the design; the loss itself is 1.0's, today
Claim: A `.fruscollection` carries a headnote as the id of its draft, so a file opened on its author's own account makes a second collection sharing that draft, and editing, regenerating or deleting in either deletes the other's headnote; §2.8 does not list this, §7.4 copies drafts for the upgrade only, and §7.6's round-trip test would pin the shared id.
What a person meets: On a Mac, the author exports a collection whose headnotes they wrote, later double-clicks the file ("you reimporting it later", iOS manual :919), edits one headnote in the copy, and the original's headnote is gone. Deleting the copy as a duplicate takes all of them.
Evidence:
- Written whenever set: NativeCollectionFormat.swift:521. Read back verbatim: :759-760; /home/user/FRUS-Explorer/FRUSExplorer/Collections/NativeCollectionFormat+App.swift:140-141.
- Edit and Regenerate delete "any prior dedicated headnote draft" by that id (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionEntryInspector.swift:1158-1173). A row's or a collection's delete does the same (/home/user/FRUS-Explorer/FRUSExplorer/Models/GeneratedSummary.swift:238-243, :258-262; /home/user/FRUS-Explorer/FRUSExplorer/Models/Collection.swift:885-889).
- Duplicate avoids it by copying the draft (Collection.swift:864-866; GeneratedSummary.swift:272-291). The import does not.
- The id resolves exactly where the harm is: "meaningful across the author's own CloudKit-synced devices" (NativeCollectionFormat.swift:227-231).
- Record: §7.4 "an entry's headnote draft | a copy of it, so that a delete on a 1.0 device cannot remove it"; §7.6 "the file ... held to a round trip of a fixture with every field set".
Refutation: an import path that copies the draft or clears the id. I read `importedValues`, `apply` and the three callers; none does. NEEDS A RUN to see it: export, import on the same device, edit the copy's headnote, read the original's.
Direction: The file carries a headnote's text or nothing, never a draft's id, and every import makes its own draft; file this with §2.8's seven.

ID: FMT-4
Severity: S2
Claim: The settings value "at three scopes" is read by HTML, PDF and Word alone; BibTeX, RIS, the Zotero send and the file's note texts ignore a section's or a document's "Your notes", so a row reading "off · Changed for this document" is false for four of the sheet's exports.
What a person meets: An author turns their notes off for one document, exports BibTeX for a class, and that document's notes are in its `annote`. The same in an RIS file, in their Zotero library, and in a shared file made with "Include my research notes" on.
Evidence:
- The rendered formats read the document's value: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionItemHTMLRenderer.swift:397; DocxCollectionExporter.swift:781; /home/user/FRUS-Explorer/FRUSExplorer/Collections/PDFCollectionExporter.swift:854.
- BibTeX and RIS read the collection's alone: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/BibTeXCollectionExporter.swift:63; ZoteroCollectionExporter.swift:65-69. The item's notes are attached whatever the cascade says (CollectionContentAssembly.swift:1001-1033, :1048, :1131).
- The Zotero send strips nothing (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExportSheet.swift:734-749). The file's note closure reads neither switch (:621-640).
- Record: §4.1 "It shows what is in force"; §4.4 "1 document keeps its own settings"; §3.8 "HTML, PDF and Word draw the plan in order", with the other four outside it.
Refutation: a per-document test in those four paths. None; the only option read is `options.includeNotes`. The pinned fixture gives its notes-off document no citation record (/home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CollectionRenderingTests.swift:194-202, :398-399).
Direction: Put the four under the same resolved values, or say on the sheet and in §4 that they follow the collection's switch alone.

ID: FMT-5
Severity: S2
Claim: A look has no stated meaning for the four exports that are not renderings: by §4.4's own mechanism it is written into a `.fruscollection`, for BibTeX and RIS it changes one thing nobody would predict, the Zotero send ignores it, and the board contradicts the text about where Zotero is.
What a person meets: On an iPhone: *Citations with your notes*, More formats, `.fruscollection`, Export. The colleague receives either a collection set to that template, which the author never had, or the author's own, in which case the ticked look and "What will print" were false. With *Full text as printed* and BibTeX, the `.bib` loses every `annote`, since that recipe's notes are off.
Evidence:
- §4.4: "writes nothing. The kit resolves a copy of the collection's values in which the recipe's keys are the template's"; it "prints the template's blocks at the end ... without the blocks the collection's own template placed". The file is written from a collection's values and is a stored collection for whoever opens it (NativeCollectionFormat.swift:472-476; CollectionExportSheet.swift:641-645).
- Recipes: /home/user/FRUS-Explorer/FRUSCoreKit/Collections/CollectionExporter.swift:226-250, notes `false` at :227 and :243. BibTeX and RIS read that flag and no other.
- The RIS path takes the stored collection's options, pinned as a source line: CollectionExportSheet.swift:712; CollectionTests.swift:5652.
- §5.1: "*More formats* opens BibTeX, RIS and `.fruscollection`. The Zotero row stays as it is"; §5.5 counts "the Zotero row". The board has no such row: /tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/Main.dc.html:54, "More formats: BibTeX, RIS, .fruscollection, Zotero". It draws no state for any of the four.
Refutation: a sentence limiting a look to the three rendered formats. I searched §4.4, §5.1, §5.5 and the board; none.
Direction: Say that a look applies to PDF, Word and Web page only, and draw what the sheet shows for the other four.

ID: FMT-6
Severity: S2
Claim: The file is a published contract with fixtures, a checker and promises, and lane 3's list of what it owes names none of them.
What a person meets: An outside tool that follows the Guide checks a file the new version exported and fails it at "format gate (§15.3)". A reader of either manual is told an untouched collection opens in older versions.
Evidence:
- Guide: "Those bytes are a test fixture" (:2829-2830); the checker's `v > 2` (:2933-2936); §15.4's "a collection exported *out* of the app is the same format and you can read the researcher's curation back" (:2982-2985); "the values shown are the app's own defaults for a new collection" (:2837), false once a new collection starts under *Full text as printed* (§4.3; recipe notes off, CollectionExporter.swift:227-229).
- Pinned: CollectionTests.swift:3015-3077 and :3079-3126.
- Manuals: iOS :1152, macOS :897. Sheet string: "Recipients open it in FRUS Explorer" (CollectionExportSheet.swift:597-598).
- Two ranged blocks cite the format's lines: /home/user/FRUS-Explorer/Docs/EditableContent/08-Reading-Research-Collections.md:897-901, :3226-3230.
- By a regex count over the four test files, 20 tests call the writer, 25 the reader or importer, and 13 assert a version of 1 or 2, a floor of 1 or none, or byte identity with a version-1 file. I read four in full.
- §9 names for lane 3 the CloudKit gate, export 8, the copy test, the upgrade's fixtures, six UI suites and "the fourteen ranged blocks that cite `Collection.swift`". The record never names the Guide.
Refutation: a mention of the Guide or the format's suites in §9 or §12. None.
Direction: Add the Guide's §15, its two fixtures and checker, both manuals' sentence, the sheet's hint, the two blocks and the format's suites to lane 3's row.

ID: FMT-7
Severity: S3
Claim: §7.6's test, with the file "held to a round trip of a fixture with every field set", cannot pass under the file's own rules, and §7.1's "every copy can go through one value" is false of the file.
What a person meets: The lane's author, who must either write a hand-kept list of exemptions, which §7.6 criticises two bullets later, or let a shared file carry what the format says never leaves a device.
Evidence:
- Never serialized: ids, timestamps and `projectIds` (NativeCollectionFormat.swift:19-22, :679-683); `selectedNoteIds` (:268-273; Collection.swift:484-486); `selectedHighlightIds` (:55-58, :755); the collection's summary prompt, "intentionally omitted" (:146-147); the saved-search link (:681). Note texts travel only on opt-in (:467-471).
- §7.2 puts "the prompt a summary is written with" inside the one settings value (§4.1), so the writer must take that value apart key by key to keep :146-147.
- §7.2's "when it was upgraded, and the 1.0 record's date" must not travel either.
Refutation: a list in the record of what version 3 writes and omits. There is none: §7.6 gives the file two sentences.
Direction: Replace "a round trip of every field" for the file with a stated list of what version 3 writes, what it leaves out and why, tested as that list.

ID: FMT-8
Severity: S3
Claim: Lane 2's "one reading of the printed heading and dateline" either changes most BibTeX, RIS and Zotero records or leaves a second reading alive for them; §3.4 says they "stay so", and §9 lists neither the change nor the pin it moves.
What a person meets: Today, a collection of 1977–80 documents sent to Zotero has titles ending in "[1]" and no document date, where the reader's own Cite gives neither fault. After lane 2 the same send differs, unannounced, or still disagrees with the contents row beside it.
Evidence:
- One reading feeds the citation and the record: CollectionContentAssembly.swift:986, :992-995, :1124-1132. It is top-level only (:1468-1482), and a labelled call becomes "[n]" (:1518-1522).
- `makeItem` puts the heading in the title and the dateline in Extra (/home/user/FRUS-Explorer/FRUSCoreKit/Citation/ZoteroJSONExporter.swift:159-168).
- The reader's Cite uses the index's heading, "its footnotes left out", and an opener's dateline (/home/user/FRUS-Explorer/FRUSCoreKit/Search/IndexingPipeline.swift:7294-7307, :7347-7358).
- My counts over the eight volumes on disk, by Python's ElementTree (review2/scripts-FMT/): 1,930 of 3,965 document heads carry a note whose `@n` is non-empty and not "0", the app's rule for a label (/home/user/FRUS-Explorer/FRUSCoreKit/TEI/ASTToRenderNodeConverter.swift:161-165). That is 308 of 315 in frus1977-80v06 and none in frus1961-63v11. 17 of 3,965 have a dateline as a direct child of the document.
- The pin §9 does not name: /home/user/FRUS-Explorer/FRUSExplorerTests/FRUSCoreKit/CollectionResolutionTests.swift:706, whose dump prints the header, the dateline and the Zotero title and Extra (:378, :391-393). §9 names :450-452 only.
Refutation: a statement that the records take, or do not take, the new reading. §3.4 says only "stay so". I derived the "[1]" title from the code and the TEI; I did not see it in a running app.
Direction: Decide in lane 2 whether the citation records take the new reading, list it among the export changes, and name the second pin.

ID: FMT-9
Severity: S3
Claim: The two candidates Q8 recommends for the first pass cannot travel in the file under its rules, and the recorded template has no rule for a reader that lacks the template.
What a person meets: A teacher shares an abridged reader (*selected passages*). Each student's copy prints that student's own highlights as the document's text, or none. A collection following a saved template arrives following nothing its recipient has.
Evidence:
- §8.1: "The highlights, their stored passages and the per-document choice of which already exist (`selectedHighlightIds`)". Highlights do not travel and the ids never serialize; an import means "all of the recipient's highlights" (NativeCollectionFormat.swift:55-58, :717-720, :755). The format froze excerpts as text for this reason (Collections-Authoring-Scope.md:179).
- §8.4 makes a saved template "a record type of its own". §4.3: "The collection records the template it follows", with changes "counted by comparing its values with the recipe".
Refutation: a line saying how a passage or a template is written to the file. None in §7.6 or §8.
Direction: Before Q8, say how a passage and a template travel in the file, or that they do not.

ID: FMT-10
Severity: S3
Claim: Export Again has no rule for the shareable file's one option, for a format no longer offered, or for whether a Zotero send can be done "again"; and the export trail cannot tell two looks apart without a stored field lane 1 says it does not add.
What a person meets: After exporting a file with notes included, Export Again either sends notes written since with no question, or quietly leaves them out. After linking the collection to a saved search, its label promises a format the writer refuses.
Evidence:
- §5.1: "Export Again: PDF, as this collection is set"; "the format this collection last exported as on this device".
- The notes option is a privacy default, off at each opening (CollectionExportSheet.swift:67-70, :594-598).
- The file is not offered for a smart collection (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExporter+App.swift:176-179; sheet :613-617). The first review's skeptic raised this case (/home/user/FRUS-Explorer/Planning/collections-design-review/skeptic-A-INT-DATA.md:119); §11's answer to DATA-10 does not reach it.
- Four paths record a "format", the Zotero send among them, which "has a real external side effect" (sheet :484, :647, :714, :750-753).
- The trail row holds a format, a count, a name and a project, with no look and no collection id (/home/user/FRUS-Explorer/FRUSExplorer/Models/ExportHistoryEntry.swift:60-84). A property there is a CloudKit deploy; lane 1 says "Stored data: None".
Refutation: a rule in §5.1 for any of the three. None.
Direction: Give Export Again a rule for each, and say whether the trail records the look.

**The file today, and what the proposal does to it**

(1) The file's rules, as the code states them (lines of /home/user/FRUS-Explorer/FRUSCoreKit/Collections/NativeCollectionFormat.swift unless another file is named)

- **What it is:** JSON of a plain `Codable` struct, "decoupled from the SwiftData `@Model` types" (:24-26); the collection's source, not a rendering (:16-22). Type `bottsywattsy.FRUS-Explorer.fruscollection`, conforming to `public.json`, with no version in the type or the extension (/home/user/FRUS-Explorer/project.yml:212-225, :412-425).
- **Required keys:** `format`, `formatVersion`, `name`, `composition` (`defaultBodyDepth`, `footnoteStyle`, `tocStyle`, `applyHighlights`, `includeNotes`, `includeWordCloud`), `entries`, and each entry's `kind` (:80, :84, :96, :116, :118, :150-169, :201). Everything else is optional.
- **Versions:** `currentVersion = 2` (:412). `formatVersion` is "what the *writer* understood" (:81-84); `minimumReaderVersion` is "the oldest reader version that can open this file without corrupting meaning" (:85-94).
- **Reader's gate:** decode, then `format`, then `minimumReaderVersion ?? formatVersion <= currentVersion` (:434-443). Unknown keys are ignored. An unknown entry kind is skipped (:699-704). An unknown block-type string is kept, inert (:741-746). A level is clamped (:729-732).
- **Writer's rule:** the minimum version the content needs: a version-1 file "byte-identical to a pre-Phase-4 file" when no version-2 feature is used (:448-454, :610-652), otherwise version 2 with `minimumReaderVersion: 1` (:654-659). The floor rises "only when *ignoring* a field would corrupt meaning" (:91-93). The legacy `footnoteStyle` is always written (:151-154). A kind this build does not know is left out (:594-598).
- **Serialized:** name and note; front matter and three back-matter switches (:99-114); composition (:148-172); entries in order with kind, document pair, level, text, RTF, excerpt anchors, block type, `titleOverride`, the body-depth override, six override keys, `includeHeadnote` (:198-274). Two ids travel: `headnoteSummaryId` (:227-231) and `summaryPromptIdOverride` (:254-258).
- **Never serialized:** ids, timestamps, `projectIds` (:21-22); `selectedNoteIds` (:268-273); `selectedHighlightIds` (:55-58); the collection's summary prompt (:146-147); the saved-search link (:681); a block's rows (:59-66). Note texts travel only on the exporter's opt-in, as bare strings (:467-471), and become new notes of the recipient's (:705-715).
- **Who writes:** the export sheet only (/home/user/FRUS-Explorer/FRUSExplorer/Collections/CollectionExportSheet.swift:452-455, :608-652), never for a smart collection (:613-617), and the kit's public writer for a host outside the app (:74-75, :472-476).
- **Who reads:** Import Collection… on iOS and the Mac, and a file opened from Files, Finder or AirDrop, which remembers a file's digest for the session (/home/user/FRUS-Explorer/FRUSExplorer/App/FRUSExplorerApp.swift:397-403, :2436-2479). Also the web edition through the same kit, and outside tools by the Guide's §15 (/home/user/FRUS-Explorer/Docs/Agentic-Analysis-Guide.md:2793-2989).

(2) What each element does to it

Under §7.6 a 1.0 app refuses the whole file, so the third column is what 1.0's reader does with the key if the file kept the floor the format's rule gives. The last column is §7.4's upgrade, through which §7.5 sends every version-1 or version-2 file.

| Element | In the file today | Must version 3 write it | A 1.0 reader | The new version, given a file without it |
|---|---|---|---|---|
| Text | `defaultBodyDepth`, `bodyDepthOverride` | yes, as now | reads it | Full |
| Summary prompt | the collection's left out by rule; an entry's id travels | unsaid; one value would carry the collection's id for the first time | ignores it | the recipient's own |
| The volume's notes | `footnoteStyle`, required, the same three values; the optional pair; per entry the pair | yes; `footnoteStyle` alone carries the collection's choice | reads it; *All* written as the pair (true, true) prints the source note twice there (defect 2) | pair or style mapped to three values (§3.5) |
| Opening | none | yes, at three scopes | ignores: the citation leads | the citation leads |
| Numbering | none | yes | ignores: no numbers | none |
| Headnote on or off | collection and document | yes; a section's is new | drops a heading's (:759) | off |
| Headnote's text | the draft's id only | unsaid; the id is FMT-3 | reads the id | the id resolves on the author's account alone |
| Your notes | on or off, by scope; which, never; texts on opt-in | as now | reads it | on; every note |
| Highlights | on or off; which, never; none travel | as now | reads it | off |
| See also | entry and heading; none for the collection | the collection's is new | follows a heading's (see Outside my scope) | off |
| Your title | `titleOverride` | as now | reads it | none |
| Your date line | none | yes; it is portable content | ignores: dropped | none |
| Contents-list style | `tocStyle` | as now | reads it | as written |
| Citation style | none | yes | ignores: history.state.gov | history.state.gov, whatever Settings ▸ Display says |
| Wording table | none | yes | ignores: the app's words | the app's words |
| Note on the Text | none | a switch, and a new block type where placed | an unknown block type is inert | prints when it has something to say; an import shows no report |
| Colophon, stamp, query log, word cloud | four keys | as now | reads them | off |
| The template followed | none | yes, or the recipient's gallery marks nothing | ignores | found by `matches`; the Guide's write-minimum matches no recipe, so "the settings came from 1.0" is said of a file an agent wrote that day |
| What placed a block | none | yes, or every block becomes the recipient's own | ignores | the author's own |
| The record's `formatVersion` | none | unsaid; the file has two numbers of its own | n/a | n/a |
| Upgrade date, 1.0 date | none | no; timestamps never travel | n/a | n/a |
| The two record types, the ids | never | no | n/a | fresh ids, as now |
| A look chosen at export | n/a | no; §4.4 does not say (FMT-5) | n/a | n/a |
| A smart collection's link | never; not offered | no change | n/a | n/a |

(3) What the record proposes for the file, and whether the format requires it

The record speaks of the file in six places: §5.1 (it moves behind *More formats*), §7.3 (its write-minimum cited as the model for records), §7.5 (version 1 and 2 files go through the upgrade), §7.6 (version 3, refused by 1.0, no write-minimum, a round-trip test), §7.7 (the cost) and §9 (lane 3, "collection file 3").

- **Necessary: no.** Nothing in §3 to §6 is misread by a 1.0 reader; all of it is ignored, and 1.0 then prints its own layout. The format's rule for that case is a floor of 1. The break is chosen, for a reason about records.
- **Sufficient: no.** The record does not say what version 3 carries, which floor it declares, that it keeps the keys 1.0 must decode, what happens to a headnote, a look, the template or a block's origin, nor who else reads the file.
- **Consistent: no.** §7.3 invokes the write-minimum rule that §7.6 drops for the file itself. §7.6's round trip contradicts the never-serialized list. §7.3's rules 2 and 5 say a value with an unknown key and a higher version "is not written", but an import must write one as a new record, and the file's own rule is that unknown keys are ignored and not preserved (Guide :2970-2978). The record does not say which holds, nor how the file's two numbers follow from the record's one.

A 1.0 app, given a file the new version writes: see FMT-2. The new version, given a file from 1.0 or an outside tool: `importedValues` already returns the `CollectionExport` the upgrade takes, so §7.5's row is mechanically sound. Such a collection keeps 1.0's layout and history.state.gov style, and gains a Note on the Text where it has a title or leaves notes out. The web edition, at its pinned commit, is a second 1.0 reader whose refusal says "Update the app"; by CLAUDE.md's rules that is the web side's to follow.

§11 rows in my scope

- G1: PARTLY. The rule covers a record a build is asked to write back, not a file it must import as a new record.
- G2: PARTLY. Nothing is written to the store, but a `.fruscollection` is itself a stored collection, and §4.4 does not keep the look out of it (FMT-5).
- G3: PARTLY. The value is copied, but the snapshot still takes none of the smart collection's own entries, its apparatus blocks among them (/home/user/FRUS-Explorer/FRUSCoreKit/Collections/SmartCollectionSnapshot.swift:97-98, :117-121), so it would follow a template with none of its blocks.
- G6, and "a title reaches no citation record": ANSWERED for the title. The heading those records read is FMT-8.
- DATA-4: ANSWERED for a file. All eight fields `matches` compares are in the file.
- DATA-8: PARTLY. The consequence is now stated, but the one test cannot hold for the file (FMT-7), and the Guide's readers are still left out (FMT-6).
- DATA-10: PARTLY. A first export is covered; a remembered `.fruscollection` on a collection since linked, and the file's notes option, are not (FMT-10).
- ENG-9: PARTLY. The two pinned source lines are named; the format's own suites and the Guide are not.
- Found sound and withdrawn with no row: "`.fruscollection` keeps `minimumReaderVersion` 1" (review :220). NOT ANSWERED.

Attacked and held

- A version-1 or version-2 file through the upgrade: the importer's output is the upgrade's input type, and the file carries every field `matches` reads (NativeCollectionFormat.swift:693-793; CollectionExporter+App.swift:46-56).
- A title reaches no citation record: the item is built from the volume's head and `titleOverride` is not read there (CollectionContentAssembly.swift:1120-1132; BibTeXCollectionExporter.swift:30-33).
- A citation style cannot reach `.bib`, `.ris` or Zotero: `makeItem` calls no formatter (ZoteroJSONExporter.swift:150-184).
- The file-type declarations need no change, and the open-with memory is by the file's bytes (project.yml:212-225, :412-425; FRUSExplorerApp.swift:2452-2457).
- The Note on the Text can travel as a `generated` entry: an unknown block type imports inert and is skipped at resolve (NativeCollectionFormat.swift:741-746; CollectionContentAssembly.swift:964-965).

Not read

- The web edition's repository.
- `ResearchDataEnvelope.swift` and `ResearchImportPlan.swift` beyond the two collection records' declarations and `ModelType`.
- `CollectionPickerSheet.swift`, `CollectionAddDocumentsSheet.swift`, `CollectionRichTextEditor.swift`; the PDF exporter beyond its notes line; `CollectionContentResolver.swift` beyond its entry points.
- The six boards other than `Main.dc.html`, which I only searched for the formats' names.
- `SESSION-notes-on-the-file.md` and `skeptic-brief.md` in the review folder, left unopened to stay independent.
- Nothing was built or run. The two-alert question and the 1.0 texts are marked where they matter.

Outside my scope

- §4.1 says 1.0's cascade does not follow a section's See also. It does (CollectionContentAssembly.swift:611-612, :1103; CollectionResolutionTests.swift:441-449); only a section's headnote is new.
- The upgrade's "pair to one value" has no answer for an entry or heading with one flag set and the other inherited: the two cascade separately today (CollectionContentAssembly.swift:1049-1050), so the inherited half must be frozen at the upgrade.
- The Note on the Text is a back-matter switch in §5.2 and §7.2 and a block "the author may move" in §3.6; the record does not say which is stored.