# Issue #1576, "Bulk actions on search results": assessment

Assessed 2026-10-07 at v2 f384d2d5 (build 49, index version 65). Read from the code; nothing was built or run.

**Decided 2026-10-08.** The owner took every recommended default in section 8. So "clear" is Mark Reviewed with Undo, the Mac picks with a Select toggle and checkboxes, #1565 is fixed before lane 3, and this issue's selection lanes land before #1577's interface lanes. The implementation plan to work from is on the issue: https://github.com/joshbotts/FRUS-Explorer/issues/1576#issuecomment-6058253884. Two things this document says in the future tense have since happened: the manual update has merged (#1580), and lanes edit the manuals themselves, leaving the AI Generated notice in place (owner, 2026-10-07; `Planning/Manual-Revisions-Pending.md` says so).

Every statement about behaviour comes from reading source at the line cited; paths are relative to the repository root. The one exception is two synthetic timings, quoted in sections 2 and 9, taken on a Mac with stand-in models and not the app's. Nothing is measured on an iPhone or through CloudKit.

**In short**

- The feature can ship with no CloudKit deploy, no index-version bump, no export change, no re-index and no shared-kit file edited. All of it is app code.
- It is six pull requests, and they land strictly one after another: each needs the one before it or edits the same two view files. The first two ship something useful before any selection UI exists.
- Three obvious ways to build it are wrong, and the design below is shaped around them: reusing the tag picker's writer (it replaces a document's whole tag set), writing the index's tag column from the row on screen (a snapshot from when the search ran), and letting "select all" mean more than the rows shown.
- The Mac half has no machine test of any kind, so every rule lives in types the iOS test target compiles, and each Mac lane owes a check by eye.
- No coordination rule with the web edition is touched. The Mac's checklist behaviour does change, and the web specification promises to match it; section 5 shows the options both ways.
- Eight decisions are yours (section 8). The first is what "clear" means.

## 1. The request, restated, and what it leaves open

From a search results list, one action should (1) add several documents to a collection, (2) give several documents a tag, and (3) in checklist mode, clear several documents. Today each works on one document at a time. Collection and tag are reachable only from an open document: all seven places that present the two pickers belong to the reader, its Research rail or its change-review sheet (`FRUSExplorer/DocumentView/DocumentView.swift:942`, `:948`, `:950`; `FRUSExplorer/DocumentView/ResearchRailView.swift:225`, `:231`; `FRUSExplorer/App/MacDocumentView.swift:476`; `FRUSExplorer/DocumentView/DocumentChangeReviewSheet.swift:224`). Clearing is a swipe or a menu item per row. Neither platform lets the reader pick more than one result.

| Left open | Recommended reading | Why |
| --- | --- | --- |
| "Clear" | Mark Reviewed: hide the rows. Not un-hide | Both manuals say the banner "counts what you've cleared" (`Docs/iOS-User-Manual.md:548`, `Docs/macOS-User-Manual.md:441` at this commit). None of the eleven `search.checklist.*` strings uses "clear", and nothing un-hides a single row today |
| "Multiple documents" | Rows the reader picks, plus "this page" and "all shown". Never matches that are not loaded | The list holds at most 1,000 rows on iOS for keywords, 7,500 for a filter-only browse and on the Mac, 100 for a Meaning search. No call returns the uncapped keys of a keyword match; in the measurement the code records, `negotiations` under a date-range filter matches 35,275 (`FRUSExplorer/Search/SearchViewModel.swift:349-355`) |
| "A single action" | Pick rows once, then one command per operation. The picks stay, so a second command is one more tap | "Into a collection and tagged" is the likely pairing |
| "Assign to a tag" | Add the tag. Every other tag on each document stays | The only route that adds a tag today deletes a document's assignments and inserts the picker's set (`FRUSExplorer/DocumentView/UserTagPickerSheet.swift:327-349`). The other tag writers remove one tag, delete or merge a tag, or migrate at launch |
| A document already in the collection | Skip it and say how many were skipped | The per-document picker refuses a second copy (`FRUSExplorer/Collections/CollectionPickerSheet.swift:316-324`). The editor's Add Documents allows one (decision A4), but there the reader sees the outline; from Search they cannot |
| How long the picks last | For the search on screen. A page turn and a sort keep them. A re-run of the same query (a filter or facet change) keeps the picks still shown and says how many it dropped. A new query, a Keywords/Meaning flip and Done empty them | The Mac already uses "same query" as the life of checklist marks (`FRUSExplorer/App/MacSearchViewModel.swift:1034-1039`, `:1131-1136`). That rule compares the typed text alone (`FRUSExplorer/Search/SearchHistoryWriter.swift:141-145`), so two filter-only browses, whose text is empty, count as one query; decision 4 settles whether to tighten it. No pick is ever outside the shown set, so a command cannot act on a document the reader has no way to see |
| Which rows | Result rows in the list reading, Keywords or Meaning. Not the "In volumes you have not downloaded" rows, which have no index row to tag. Not the concordance, timeline or collocates | Meaning rows are ordinary `SearchResult` values; the beyond-library rows are not (`SearchViewModel.swift:624-626`) |
| One row | The same two commands on a single row's menu | Neither platform's row offers a collection or tag action today |
| Whether "cleared" survives a relaunch | No. It stays in memory, per session, as now | Persisting it is a new stored field and a CloudKit Production deploy |
| Undo | Offered after every bulk command | Model writes have no `UndoManager`. Two lists already carry an Undo that deletes a model row, re-applies the index and announces to VoiceOver, which is the pattern to copy (`FRUSExplorer/Settings/ClassificationCorrectionsView.swift:122-132`, `:173-219`; `FRUSExplorer/Browser/PersonCorrectionsView.swift:299-305`, `:356-374`). The only bulk removal is deleting a tag, which takes its every assignment with it (`FRUSExplorer/Models/UserTagAdmin.swift:52-81`); short of that, a mis-tag of 40 documents would mean opening 40 documents |

## 2. What exists today that it builds on

**iPhone and iPad** share one view, `SearchView` (`FRUSExplorer/Search/SearchView.swift:231`), mounted only by the Search tab.

- The list is `List { ForEach(vm.pagedResults) }` with a plain `Button` per row that pushes the document (`:2075-2110`). There is no selection and no edit mode. The list is rebuilt on a page turn (`:2089`). A page is 25 rows (`SearchViewModel.swift:545`).
- Each row offers a tap, a tag-chip tap that re-runs the search (`:2102-2107`), a swipe "Reviewed" in checklist mode (`:2114-2125`), and a long-press menu with Mark Reviewed, Open in New Window (Stage Manager only) and Archival Neighbors… (`:2130-2181`).
- The actions bar is one `HStack` of five identified controls that "cannot wrap, scroll or fold" (`:1369-1393`). `SearchActionsBarFitTests` pins those five identifiers and their outer frames (`FRUSExplorerUITests/SearchTipsSheetTests.swift:327-335`).
- The tab shell draws its indexing or Local Only banner over the bottom of the Search content and publishes its height as `\.tabShellBottomOverlay` (`FRUSExplorer/App/MainTabView.swift:183-191`). Only the pre-search screen reads that height (`SearchView.swift:378`, `:1726`); the results list does not, so its last rows already sit under the banner, which is open issue #1565. A bottom inset also floats onto the keyboard's accessory row (#1070, `MainTabView.swift:90-93`).

**Mac** is a separate implementation, `MacSearchWindowView` with `MacSearchViewModel` (`FRUSExplorer/App/SearchSheet.swift`, `MacSearchViewModel.swift`).

- The list is `List(selection: $selectedResultId)`, a single optional id used for arrow-key traversal (`SearchSheet.swift:253`, `:2054`). A single click selects and opens (`:2060-2063`); ↩ opens (`:2131-2137`). A page is 10, 20, 50 or 100 rows (`MacSearchViewModel.swift:246-248`).
- The row menu has Open, Open in New Window, Archival Neighbors… and, in checklist mode, Mark Reviewed (`:2064-2121`).
- The toolbar acts on the whole result set, with a recorded decision against shortcuts until a menu-bar channel exists (`:1053-1061`). The `.commands` block is at the builder's cap and has already had to wrap entries in a `Group` (`FRUSExplorer/App/FRUSExplorerApp.swift:1917-1920`).
- No test compiles for the Mac: both test targets are `platform: iOS` (`project.yml:546-548`, `:593-595`), and `MacSearchViewModelTests` sits inside `#if os(macOS)` (`FRUSExplorerTests/SearchViewTests.swift:853-867`).

**Checklist mode, both platforms.** It is in-memory state, never stored: four properties on iOS (`SearchViewModel.swift:424-490`) and five on the Mac, which adds the query its marks are anchored to (`MacSearchViewModel.swift:397-480`, `:432`). `markReviewed` inserts one key (`SearchViewModel.swift:482-484`, `MacSearchViewModel.swift:473-475`). Nothing marks several rows or un-marks one. On iOS every completed search wipes the marks, including the re-run a tag-chip tap makes (`SearchViewModel.swift:712-716`, `:790-794`); the Mac keeps them while the query is the same (`MacSearchViewModel.swift:1034-1039`). On both, the "N reviewed hidden" line is drawn only once N is above zero (`SearchView.swift:1766`, `SearchSheet.swift:1914`).

**Writers and sheets, shared by both platforms.**

| Piece | Where | What matters here |
| --- | --- | --- |
| `CollectionPickerSheet` | `FRUSExplorer/Collections/CollectionPickerSheet.swift:47` | Takes one document (`:50`). Has an iOS and a Mac body. Lists every collection, smart ones included (`:58`). Does not call `save()`. Shows a fixed "FRUS text" provenance chip (`:143`, `:261`) |
| `CollectionDocumentDiscovery.appendEntries` | `FRUSExplorer/Collections/CollectionAddDocumentsSheet.swift:145-164` | Appends many documents from one `nextSortOrder`, linking each by the inverse. Allows duplicates. Does not save |
| `UserTagPickerSheet` | `FRUSExplorer/DocumentView/UserTagPickerSheet.swift:54` | One document; replaces its whole tag set on Done (`:327-349`) |
| `UserTagAdmin` | `FRUSExplorer/Models/UserTagAdmin.swift:52-136` | The house place for tag writes that touch many rows: three unscoped fetches (notes, assignments, projects) and one save per call |
| `IndexingPipeline.updateUserTagIds` | `FRUSCoreKit/Search/IndexingPipeline.swift:2619-2628` | Kit code. Overwrites one document's `user_tag_ids` with the string it is given |
| `PlanPickerSheet` | `FRUSExplorer/TripPacket/PlanPickerSheet.swift:22-68` | Already takes a document list behind an `Identifiable` request with an `onAdded` callback: the shape to copy |
| Hand-rolled multi-select | `CollectionAddDocumentsSheet.swift:315-327`, `:1252-1383`; `FRUSExplorer/Browser/VolumeCatalogueView.swift:412-435` | A set of keys, a `checkmark.circle.fill` or `circle` (leading in the Add Documents sheet, trailing in the catalogue), the `.isSelected` trait, a commit bar. No list in the app binds a `Set` selection |

**Five facts settled by reading.**

1. `appendEntries` does not need an open editor. Its array parameter is `inout`, which suggests one, but `nextSortOrder(in:outline:)` defaults the outline to `[]` and reads the model (`FRUSExplorer/Collections/CollectionEntryData.swift:255-258`). A scratch array works.
2. One index tag write is a guarded single-row `UPDATE` (`IndexingPipeline.swift:11596-11638`). The picker's comment about a 100–500 ms "delete + full re-insert" (`UserTagPickerSheet.swift:302-303`) is stale. Measured on a synthetic index of 60,000 rows: 1,000 such writes, one commit each, took 44 ms.
3. The toast helper posts no VoiceOver announcement, whatever its comment says, and clears after 2.6 s with no button (`FRUSExplorer/Theme/ControlHelp.swift:137-166`). It cannot carry an Undo.
4. The launch sync pushes a tag string only for documents that still have an assignment (`FRUSExplorerApp.swift:3238-3253`). A document whose last tag was removed on another device keeps the tag in this device's index for good. `UserTagAdmin`'s comment says the column is rebuilt at every launch (`:43-47`); the loop does not clear. Its fetch (`:3238`) is written `(try? …) ?? []`, so a failed fetch looks like no assignments at all.
5. The existing iOS test that a new search resets the marks changes the query from "alpha" to "beta" (`FRUSExplorerTests/SearchViewTests.swift:803-850`). So giving iOS the Mac's same-query rule leaves its assertions true. It reads `vm.markedReviewedKeys` (`:846`, and `:780` in an earlier test), so that name has to survive (lane 1).

## 3. Recommended design

The design starts from the rules the code must hold. The lane order is chosen so that every pull request ships something visible and reuses existing helpers. For the reader it adds one-row menu actions, VoiceOver row actions and an outcome line that stays with an Undo, and it keeps click-to-open on the Mac.

### Rules the code must hold

1. **A selection is a set of `SearchResult.id` keys drawn from the results shown for the search on screen:** the loaded results less whatever checklist mode hides (`displayedResults`), which is the set Save as Working Corpus captures (`SearchView.swift:2064-2069`). It is pruned whenever that set shrinks. Its count is always on screen. Section 1 gives its life. The rule is written on the shown set, not the loaded one, because checklist mode hides a row the moment it is opened (`SearchViewModel.swift:460-464`, `MacSearchViewModel.swift:447-453`) and the design keeps click-to-open on the Mac: on the loaded set, an opened row would stay picked and out of sight.
2. **A command acts on a frozen list.** The list is built, in the order on screen, when the command is chosen. The sheet's title carries its count, and the write uses that list and nothing live (the `.sheet(item:)` stale-sibling trap, #862).
3. **Add to Collection** skips a document that already has a `.document` entry (an excerpt from the same document does not count), adds the rest from one `nextSortOrder`, links by the inverse, sets `collection.lastModified`, and saves once, explicitly. #1415 was an edit lost for want of a save (`FRUSExplorer/Collections/CollectionCompositionRows.swift:335-339`). A smart collection is refused. Over 1,000 documents the command is disabled and says why (decision 5).
4. **Add Tags** only adds. It makes one fetch of every assignment, grouped by document, inserts only the missing (document, tag) pairs, and saves once. A fetch that fails stops the command; it is never read as "no tags yet". Each touched document's index string is built from that grouping at the moment of the write, never from the row on screen. The same 1,000 limit applies.
5. **Mark Reviewed** is one set union, with keys built by `reviewedKey`, not by rewriting `/` to `|`. No limit. Undo restores exactly that batch.
6. **The outcome stays** in the selection bar, with Undo, until the next command, search or Done, and is announced to VoiceOver. Example: "Added 31 to "Chile". 6 were already in it. Undo". Undo re-fetches the rows it inserted by id and treats a miss as already undone, as the two corrections lists do (`ClassificationCorrectionsView.swift:173-182`).

### What the reader sees

**iPhone.**

- *Without selecting.* A row's long-press menu gains Add to Collection…, Add Tags… and Select. Each row carries the same as VoiceOver custom actions. In checklist mode a strip sits above the list whenever the mode is on, not only once something is hidden as the line does today. It holds "N reviewed hidden" when N is above zero, **Mark Page Reviewed** and, after a bulk mark, **Undo**.
- *Entering.* More menu ▸ Select Results, placed after the two save items so they stay adjacent (`ExamineMenuAuditTests.saveLivesInMoreMenu`), or Select on a row's menu, which starts with that row picked. No sixth control in the actions bar.
- *While selecting.* The actions-bar slot shows a selection bar of the same height: Done, "N selected" in a reserved width, and a Select menu (This Page, All N Shown, None). The five-control bar and its fit test are untouched. Each row gains a leading circle with the `.isSelected` trait; a tap toggles it; the swipe and the tag chips are off; long-press offers Open. With checklist on, opening a picked row hides it and un-picks it: the count drops by one and "N reviewed hidden" rises by one. A row that comes back, by Undo or by turning checklist off, comes back unpicked.
- *Commands.* A bottom bar holds Add to Collection, Add Tags and, in checklist mode, Mark Reviewed. It hides while the keyboard is up and sits above the tab shell's banner. That banner already covers the list's last rows (#1565), so the bar is built after that fix (decision 7). If it still cannot clear banner and keyboard at 375 pt and accessibility sizes, the fallback is one Actions menu in the top selection bar. With more than 1,000 picked, Add to Collection and Add Tags are disabled and say why; Mark Reviewed still runs.
- *Sheets.* The existing collection picker, titled "Add 37 Documents to Collection", with smart collections dimmed and the reason given. It keeps its "FRUS text" chip and, for a selection made from a Meaning search, adds "This app's model" (decision 6). The existing tag picker in a new adding mode, titled "Tag 37 Documents": every toggle starts off, each tag shows how many of the 37 already carry it, and a footer says tags a document already has are kept.
- *After.* The picks stay after Add and Tag. Mark Reviewed drops what it hides. Tagged rows show the new chip at once, without a re-search.

**iPad.** The same view and code. Three differences in use: the facet inspector can stay open beside the list, so narrowing re-runs the same query and the picks still shown are kept; under Stage Manager, Open in New Window lets the reader check a document without leaving selection (with checklist on, that open hides and un-picks the row, by rule 1); and the sheets stay sheets, so no confirmation popover needs an anchor. No hardware-keyboard commands in these lanes.

**Mac.**

- *Without selecting.* The row menu gains Add to Collection… and Add Tags…. The checklist strip shows whenever checklist mode is on and gains Mark Page Reviewed and Undo.
- *Entering.* A titled **Select** toggle in the toolbar, beside Checklist.
- *While selecting.* Every row shows a leading checkbox, placed outside the private row struct that `InAppCitationNumberTests` reads. A click on the checkbox toggles it. **A click elsewhere on the row still opens the document, as now**, so the reader can read while picking; with checklist on, that open hides and un-picks the row, as on the iPhone. Space toggles the highlighted row; ↑, ↓ and ↩ are unchanged. A strip above the list holds the count, the Select menu, the three commands, the outcome with Undo, and Done. On a checked row with several checked, the menu reads "Add 12 Selected to Collection…". All N Shown can be 7,500 here, so the over-limit state will be seen often.
- *Not in these lanes.* ⌘-click, ⇧-click, ⌘A and menu-bar commands. How a modifier click meets the row's tap gesture on a selectable list cannot be read from source, and no test can run there.

### Model and service changes

No new `@Model` and no new stored property. New app code, each piece in a new file so the large files gain only hooks:

| Piece | What it is |
| --- | --- |
| `ReviewedMarks` | Value type: the hand marks and the last bulk batch. `mark`, `markBulk`, `undoLastBulk`, `reset`. Both view models store one. `markedReviewedKeys` stays as a read-only computed property over it, so its two compiled readers (`SearchViewTests.swift:780`, `:846`) pass unchanged and the three Mac-only readers no target compiles (`:976`, `:1050`, `:1083`) do not rot unseen |
| `ChecklistAnchor` | Value type: the folded query and, for a filter-only run, the person or subject it browses. Both view models compare it where the Mac compares a string today (decision 4) |
| `ResultSelection` | Value type: whether selecting, and the key set. Toggle, select page, select all shown, clear, prune against the shown set, resolve to rows in display order |
| `BulkResultRequest` | `Identifiable` item carrying the command, its frozen document list, and whether the search was a Meaning run |
| `ResultSelectionBar`, the row mark, the command bar | Shared views, used by both hosts |
| One host modifier | Owns the request and presents both sheets, so `SearchView` and `MacSearchWindowView` each add a few lines |
| `CollectionDocumentDiscovery.appendDocuments(_:to:modelContext:)` | An extension in a new file. Calls `appendEntries` with a scratch outline. Returns what it inserted and how many were already present |
| `UserTagAdmin.assign(tagIds:to:context:)` | An extension in a new file, beside `merge` in kind. Returns the rows it inserted and each touched document's full tag string |
| `SearchResult.replacingUserTagIds(_:)` | An extension in an app file over the kit type's public initialiser, to refresh rows in memory. On iOS, reassigning `results` only re-clamps the page (`SearchViewModel.swift:338-340`); the Mac's `results` has no observer (`MacSearchViewModel.swift:275`) |
| The launch tag sync's clear | The sync lifted out of `FRUSExplorerApp.swift` (`:3196-3272`) into a function a test can drive, with a guarded clear (lane 5) |

**Reused as they are:** `appendEntries` and `nextSortOrder`; `CollectionPickerSheet` (given a documents initialiser; its four call sites in three files do not change); `UserTagPickerSheet`'s new-tag field, ordering and cancel clean-up; `IndexingPipeline.updateUserTagIds`, looped; `CollectionEntriesModelSync`, so an open editor follows; `ResultSetScope`'s words loaded, shown and match; `CountCopy`; `.controlHelp`; the checkmark-circle row with `.isSelected`.

## 4. Lanes

Each is one pull request based on `v2`, landed through the serial merge queue in this order, none stacked on another. They cannot be developed side by side. Lanes 3, 4 and 5 each need types the lane before them adds, so each can start only when its predecessor has merged. Lanes 1 and 2 are independent of each other, but both edit `SearchView.swift`, `SearchSheet.swift` and the same ranged documentation blocks, so the second would conflict at landing. Sizes: small is about a day of work with review, medium two to three days, large about a week. By those sizes the six take eleven to twenty working days end to end.

| # | Lane | Size | Needs |
| --- | --- | --- | --- |
| 1 | Checklist: Mark Page Reviewed, with Undo | Small to medium | — |
| 2 | Add to Collection from a result row | Medium | — (lands after 1, to avoid the conflict) |
| 3 | Select results on iPhone and iPad | Medium to large | 1, 2; #1565's fix, or the fallback (decision 7) |
| 4 | Select results on the Mac | Medium | 3 |
| 5 | Add Tags, to one row and to a selection | Medium | 3, 4 |
| 6 | Manuals and notes | Small | 5 |

Lanes 1 to 5 close #1576. Lanes 3 and 4 can be one pull request if you prefer fewer; they are split so the Mac's check by eye has one target and the iPhone work does not wait on it.

Every code lane also owes two things. It re-points the `Docs/EditableContent` blocks whose cited lines it moves: sixteen cite the two view files, and six more cite files these lanes edit above the cited line (`SearchViewModel.swift`, one; `MacSearchViewModel.swift`, two; `FRUSExplorerApp.swift` below the launch sync, three). And it edits both user manuals where it changes behaviour they describe (lane 6).

**Lane 1. Checklist: Mark Page Reviewed, with Undo.**
- *Scope.* `ReviewedMarks`, with `markedReviewedKeys` kept as a computed read; `markReviewed(_ results:)` and `undoLastBulkMark()` on both view models; the strip on both platforms, shown whenever checklist mode is on, which means lifting the `hidden > 0` test at `SearchView.swift:1766` and `SearchSheet.swift:1914`; `ChecklistAnchor`, and iOS taking the same-query rule as decision 4 settles it; the manuals' checklist section.
- *Acceptance.* `ReviewedMarksTests`, one fixture per branch: a bulk mark returns only the keys it newly hid; undo removes exactly the last batch and leaves hand marks; reset clears both. In `SearchChecklistModeTests`: 60 results with page 1 marked leaves 35 shown, first row `d26`, page 0; undo restores 60; a same-query re-run keeps the marks; a new query clears them and the undo; a browse for one person and then another clears them, if decision 4's default stands. The existing reset test passes unchanged, its `markedReviewedKeys` reads included. For the Mac, source scans matched on the call: the strip calls `searchVM.markReviewed(searchVM.pagedResults)` and is mounted outside any `hidden > 0` test, the Mac view model stores `ReviewedMarks`, and `performSearch` builds its anchor from the parameters it runs.

**Lane 2. Add to Collection from a result row.**
- *Scope.* `appendDocuments`; the picker's documents mode; smart collections disabled in the picker with the reason, in both modes; `BulkResultRequest` and the host modifier; Add to Collection… on a row's menu on both platforms, and as a VoiceOver action. The picker's own checkmark is the feedback for one row.
- *Acceptance.* Additions to `CollectionAttachmentTests` that drive `appendDocuments` itself: a never-saved collection, whose `documentEntries` is `nil`, links both ways; 5 documents with 2 present gives 3 inserted and 2 skipped, at ascending positions after the maximum; an excerpt of the same document does not count as present; a repeated document is added once; a second context sees the rows, which proves the save; a smart collection and a list over the limit are refused. Source scans: each host presents `CollectionPickerSheet(documents:` from the request, not from live state. One UI test adds a row to a new collection and reads the collection's count; the six-document seeded volume is enough for it.

**Lane 3. Select results on iPhone and iPad.**
- *Scope.* `ResultSelection` and its hooks on `SearchViewModel`, pruned against the shown set; the selection bar, row marks and bottom command bar; both ways in; Add to Collection and Mark Reviewed for the selection; the outcome line with Undo and its announcement; the limit and its disabled state; the picker's second chip for a Meaning selection. A new UI-test seed flag that writes a second fixture volume of 30 or more documents sharing one word, removed by any launch without the flag as the storage-row and matrix seeds are; the shared fixture is left alone, because two suites depend on its shape (`FRUSExplorer/App/UITestVolumeSeeder.swift:71-72`). The More menu's help string re-keyed, since it lists that menu's contents (`search.moreActions.help.v2`, `SearchView.swift:1211`): that also means editing `SearchTipsWiringTests.moreMenuOpensTips`, which pins the key (`FRUSExplorerTests/SearchTipsWiringTests.swift:375-376`), and the block that names it (`Docs/EditableContent/07-Search-and-Browse.md:1120`).
- *Acceptance.* `ResultSelectionTests`, one fixture per rule in section 3, among them: a picked row that an open hides leaves the selection and returns unpicked after Undo. The UI suite and the fit test in section 7. `SearchActionsBarFitTests` and `SearchTipsWiringTests.actionsBarIsUnchanged` pass unchanged.

**Lane 4. Select results on the Mac.**
- *Scope.* The same value types on `MacSearchViewModel`; the toolbar toggle; the strip; the checkbox; Space; the menu's selected-rows branch; both sheets on the Search window; the disabled state for a selection over the limit.
- *Acceptance.* Source scans, each matched on the call: the host constructs `ResultSelectionBar`, presents from the request, and branches its menu on membership. `InAppCitationNumberTests` passes unchanged. The pull request lists a check by eye: the toolbar at the window's 640 pt minimum width; a row click still opens; a checkbox click does not; with checklist on, a picked row that is opened leaves the list and the count; Space; the menu on a checked and an unchecked row; All N Shown over 1,000; both sheets; VoiceOver reading the checkbox.

**Lane 5. Add Tags.**
- *Scope.* `UserTagAdmin.assign`; the tag picker's adding mode, whose Done can never reach the replace-set writer; the index loop in one detached task; the in-memory row refresh; Undo; Add Tags… on a row's menu and in both selection bars. Also the launch sync clears a document whose assignments are gone (fact 4), because Undo on one device otherwise leaves the tag in another device's search filter for good. That clear is safe only behind three guards. It runs only after an assignment fetch that succeeded: today's `(try? …) ?? []` (`FRUSExplorerApp.swift:3238`) would let one failed fetch erase every tag string in the index. It runs after the one-time migration that promotes legacy strings (`:3204-3232`). And it lists the rows to clear with `CrossReferenceStore.documentsWithUserTags()` (`FRUSExplorer/CrossReference/CrossReferenceStore.swift:576-594`), which is app code, so the lane still edits no kit file.
- *Acceptance.* A new suite, `UserTagAdminTests`, in its own file, chosen over adding to `OrphanedTagRepairTests.swift`, the only place `UserTagAdmin` is tested today: a document tagged A and B gains C and keeps A and B, a test first run once against the picker's writer to prove it fails there; a second run inserts nothing; an existing duplicate counts as present; the returned string includes a tag added after the row's snapshot. With a real pipeline on a temporary index, as `UserTagCountTests` build one: a search filtered by the tag returns exactly the tagged documents. A view-model test: the refresh changes `userTagIds` on the named rows only and leaves selection, page and marks alone. Launch-sync tests, one per guard: a row with no assignments is cleared; a failed fetch clears nothing; a legacy string not yet migrated is promoted, not cleared.

**Lane 6. Manuals and notes.** Both user manuals are being brought up to date in a separate pull request, and each will carry an "AI Generated" notice directly under its title until you have reviewed it, which will be at least two weeks. So lanes 1 to 5 edit the manuals themselves, in the pull request that changes the behaviour, and leave the notice in place: lane 1 the checklist section (§7.7 at this commit; the update will move it), lanes 2 to 5 a short bulk-actions part. Lane 6 is what remains: the two side effects in section 9 stated plainly, one read of the bulk-actions part as a whole, and TestFlight notes at the next build bump. `Planning/Manual-Revisions-Pending.md` still records the earlier rule, that lanes propose manual changes there and do not edit; this assessment follows the newer instruction, and that file should say so before lane 1 starts.

**Later, not needed to close the issue:** a menu-bar and keyboard channel on Mac and iPad (Find-menu commands, ⌘-click and ⇧-click, ⌘A); Save Selection as Working Corpus…, which is the bridge to #1577; Add Selection to an Archives Visit…, since `PlanPickerSheet` already takes a document list; removing a tag from a selection; collapsing duplicate (document, tag) assignments at launch; acting on every match and not only the rows loaded, which no call supports today (a caller would have to page `SearchService.search` by offset).

## 5. The web edition

**Shared code touched.** No shared file is edited. Four shared declarations are called as they stand: `SearchResult` and its public initialiser (`FRUSCoreKit/Search/SearchParameters.swift:483-575`), `IndexingPipeline.updateUserTagIds` (`FRUSCoreKit/Search/IndexingPipeline.swift:2619-2628`), `DocumentBrowserEntry` (`FRUSCoreKit/Browser/VolumeStructure.swift:219`) and `CountCopy` (`FRUSCoreKit/Models/CountCopy.swift:43`). The new tests also drive `SearchService`, `IndexingPipeline` and `FTS5Store`, from app test files. Calling is not editing.

**What the four coordination rules require.** Nothing beyond the normal unit run. Rules 1 to 3 bind edits to kit files, and there are none. Rule 2 permits the `SearchResult` extension to live in an app file; it does not require it, since the member reads no app state. Rule 4's `swift test` is owed only after a change to shared code. `FRUSCoreKitBoundaryTests` runs in the unit run regardless; none of the new type names appears in any kit or in the app today.

**Where the app's work and the web edition pull apart.** By the rules, nowhere. No lane gains anything from breaking rules 1 to 4, because the new writers are SwiftData and belong in the app, and nothing here moves the index version, the FTS generation or the export the web server checks. The lanes change the source digest the web edition's golden files record, as nearly every merge does, and a web session remakes those at its next pin move whatever lands. Two choices still cost the web side something. Each is shown inside the arrangement and outside it.

*The Mac's checklist and search behaviour changes.* The web repository's docs/SPEC.md (read at its commit `51dbaf2`) gives checklist mode as "Browser memory, per session, as on the Mac" (`:101`) and says checklist mode, saved searches and Save as Working Corpus "behave as on the Mac" (`:348`), both for its phase 2. Lanes 1 and 4 change what those lines point at: a strip that is always there, Mark Page Reviewed, Undo, and whatever decision 4 makes of "same query". The specification also has no row for bulk actions under its phase-2 tags (`:106`) or collections (`:112`).

| Option | Cost to the app | Cost to the web edition |
| --- | --- | --- |
| Inside the rules, saying nothing. This is the arrangement's default | None | It meets the change when it next reads the Mac's behaviour, at phase 2 or a pin move. It then writes its own version, in TypeScript and against its own user store, because the app's is SwiftUI and SwiftData and cannot compile on Linux |
| Inside the rules, with one sentence in each pull request that changes Mac checklist or search behaviour. The rules list notifying as not asked; they do not forbid it | A sentence in up to five pull requests | It can add the rows to its specification now and size phase 2 with them |
| Outside the arrangement, under which app sessions do nothing for the web edition beyond the four rules: put the Foundation-only value types (`ReviewedMarks`, `ChecklistAnchor`, `ResultSelection`) in `FRUSCoreKit`, public | Lanes 1 and 3 become shared-code lanes. Their suites move to `FRUSExplorerTests/FRUSCoreKit/` and compile twice, every later edit owes `swift build --target FRUSCoreKit` and `swift test`, and the types may never name an app type | Little gained. Its checklist lives in the browser (`:101`), in a TypeScript app (`:18`), where a Swift type cannot run. Only a server-side use could compile them |

Recommended: the second (decision 8).

*Persisting cleared rows, which is decision 1's alternative and not the recommendation.* It would be a stored field: an array of document keys on an existing model, as `WorkingCorpus` holds its members (`FRUSExplorer/Models/WorkingCorpus.swift:43-46`), not a new model type.

| Option | Cost to the app | Cost to the web edition |
| --- | --- | --- |
| Inside the rules: add the field, deploy the schema, and carry it in the JSON export if wanted. The rules ask the app to hold back no export change | The Production deploy, and nothing on the web's account | Line 101 stops describing the Mac. If the field sits on the search-history row, which the JSON export carries (`FRUSExplorer/Export/ResearchDataExporter.swift:98`), the exporter's own practice is a format bump (`:508-523`), and the next number, 7, is the one the web plan gives to a pull request of its own (the web repository's docs/SPEC.md `:956`). That pull request would take 8 or merge the two |
| Outside the arrangement: hold the field out of the JSON export until the web's `formatVersion` 7 has landed | Persisted marks are missing from the JSON research-data export in the meantime | None |

Two smaller points offer no real choice. The `SearchResult` extension costs nothing in an app file, and in the kit it would cost a `swift test` run for no gain to the web side. A batched tag write, wanted only if a limit goes above 1,000, can only be a kit change, because the single-row helper it would sit beside is `private` to the kit's file (`IndexingPipeline.swift:11596`); it stays inside the rules, costs a `swift test` run, and gives the web side a method it never calls, since its design keeps tags out of the corpus index (the web repository's docs/SPEC.md `:16`).

## 6. Release constraints

| Constraint | Needed? | Why |
| --- | --- | --- |
| CloudKit schema deploy | No | No `@Model` and no stored property is added. The lanes write rows of existing types, with the fields the single-document paths already set. `identifiersAwaitingDeploy` is empty (`FRUSExplorer/Models/CloudKitSchemaInventory.swift:501-509`) and stays so |
| Index version bump | No | Nothing changes what indexing parses or stores per volume. Writes to the user columns of `document_cache`, the launch sync's clear among them, take no bump. The version stays 65 (`IndexingPipeline.swift:1324`), so the published web server goes on accepting exports |
| Export format | No | JSON `formatVersion` stays 6 (`FRUSExplorer/Export/ResearchDataExporter.swift:523`): tag assignments and collection entries are already carried. The database export's strip already clears `user_tag_ids` (`:1309-1322`) |
| Re-index | No | A re-index keeps `user_tag_ids` (`IndexingPipeline.swift:7364-7365`), and nothing here is derived from the corpus |
| Project file | Yes, mechanical | New source files need `xcodegen generate` and then the scheme restore. `README.md` and the TestFlight notes change only at the next build bump |

## 7. Tests

**Unit, in the iOS-hosted target, on any iPhone simulator.** In-memory containers built with `cloudKitDatabase: .none`. One fixture per rule, and each hazard test run once against the code it guards before it is trusted. The suites are named in section 4. Existing gates the lanes must satisfy: `EditableContentKeyTests` (the 22 ranged blocks counted in section 4), `ExamineMenuAuditTests`, `SearchTipsWiringTests`, `ToolbarAccessibilityAuditTests`, `UnconstructedViewAuditTests`, `ResearchLoggingGateTests`, the license-header audit on new files, and a clean `build-for-testing` with no warnings.

**UI: a new suite `SearchBulkActionsTests`, in its own file, on an iPhone and an iPad.** It runs on lane 3's new 30-document seed with `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`, finds controls by identifier, and closes any sheet and leaves selection in `tearDown`. The shared `FRUS_UI_TEST_SEED_VOLUME` fixture cannot carry it: it holds six documents (`UITestVolumeSeeder.swift:101-105`, `:122-125`, `:144`), fewer than one 25-row page, so no search over it has a second page and 25 rows cannot be hidden. The suite needs a collection and a tag: none of the 17 `FRUS_UI_TEST_*` flags seeds either, so it creates them through the pickers or the lane adds a flag. It compares frames and does not trust `isHittable`, which #1565 records as true for a row under the banner.

| Test | iPhone 17 | iPad Pro 13-inch (M5) |
| --- | --- | --- |
| Pick two rows; read two `.isSelected` traits and the count | Runs | Runs |
| Turn to page 2 of the 30; the count holds | Runs | Runs |
| Add to a new collection; read the outcome; add again and read "already in it"; Undo | Runs | Runs |
| Tag the rows; find the chip with no re-search | Runs | Runs |
| Checklist on; select the page; Mark Reviewed; read "25 reviewed hidden"; Undo | Runs | Runs |

Expect no skips on either: the list and both sheets are the same code on the two idioms, and the suite is the first to drive a result row in the Search tab. Pass the iOS 27 timeout flags.

**Fit, iPhone only, at two widths.** The selection bar's and the command bar's frames at five text sizes on an iPhone 17 (402 pt) and an iPhone SE 3rd generation (375 pt), with the tab shell's banner showing and each frame required to sit above the banner's, each accessibility size proved to have taken effect as `SearchActionsBarFitTests` proves it. It skips on iPad, where the row fits either way.

**Mac.** No target exists. The rules are covered by the shared types' unit tests and by source scans; the wiring is covered by the check by eye that lanes 1, 2, 4 and 5 list.

**Kit.** Nothing.

## 8. Decisions for the owner

| # | Decision | Recommended default | Alternative |
| --- | --- | --- | --- |
| 1 | What "clear" means | Mark Reviewed (hide), with Undo, in memory per session | Persist cleared rows: a new stored field and a Production deploy before any archive, with the web costs in section 5 |
| 2 | The Mac's way of picking | A Select toggle that shows checkboxes; a row click still opens | Checkboxes always shown plus ⌘-click and ⇧-click; or native selection, where a click selects and a double-click opens, which changes a documented behaviour for every Mac user |
| 3 | A document already in the collection | Skip it and report the count | Add it again, as the editor's Add Documents does |
| 4 | iOS checklist marks across a re-run of the same query, and what "same" means | Keep them, as the Mac does, and on both platforms count two filter-only browses as the same only when they browse the same person or subject. This changes iOS behaviour and tightens the Mac's, whose own comment says a stale mark "must not leak into an unrelated query" (`MacSearchViewModel.swift:1032-1033`) | Take the Mac's rule as it is: typed text only, so marks made in one "Find all mentions" browse hide documents in the next person's. Or leave iOS as it is: one tag-chip tap then undoes a 200-row clear |
| 5 | The limit per command, and what the reader sees over it | 1,000 documents for Add to Collection and Add Tags; none for Mark Reviewed. Over it the two commands are disabled and say why. All N Shown reaches 7,500 on the Mac and in a filter-only browse on iOS, so this will be common | Take the first 1,000 in the order on screen and say so in the sheet's title; or a higher limit once sync has been watched |
| 6 | The collection picker's provenance chip for a selection made from a Meaning search | Keep "FRUS text", since each entry is a FRUS document, and add "This app's model", since the picker's own comment names "a model-derived set" as the point where one chip stops being enough (`CollectionPickerSheet.swift:138-143`). A single row keeps "FRUS text" alone | Keep the one chip everywhere and reword the comment to say why |
| 7 | Lane 3 and open issue #1565 | Fix #1565 first, in its own pull request, landed before lane 3 starts. Its suggested fix changes `MainTabView` for all five tabs and touches #1070's keyboard rule, the two things lane 3's bottom bar must also get right | Do not wait: lane 3 ships its commands as one Actions menu in the top selection bar, and the bottom bar follows the fix |
| 8 | Telling the web side that the Mac's checklist and search behaviour changed | One sentence in each pull request that changes it | Say nothing, as the arrangement allows; or move the value types into the kit (section 5) |

Defaults taken without asking; say so if any is wrong: tagging only adds; a selection never reaches matches that are not loaded; a pick that checklist mode hides leaves the selection; documents are added in the order on screen; no extra confirmation dialog, because each sheet's title carries the count and every command has an Undo; a new query ends selection without asking; smart collections cannot be picked as targets; the launch tag sync gains a guarded clear; each lane edits the manuals itself; no shortcuts until the later lane.

Also asked of you: the Mac check by eye on four lanes, and one watched run of a 1,000-document add and tag on a Development build signed into iCloud with a second device. Development builds share one store, so use a throwaway collection and tag for that run and UI-test launches for everything else.

## 9. Risks

- **The Mac wiring has no executable test.** Shared types and scans cover the rules; only your check covers the gestures.
- **The iPhone bottom bar.** It must clear the tab shell's banner and yield to the keyboard, at 375 pt and accessibility sizes. Not run; the fit test decides, and the fallback is named in section 3. #1565 covers the same ground, which is why decision 7 orders the two.
- **The calendar is serial.** No two lanes can be in development at once (section 4), so a slow review of one holds every lane after it.
- **Write and sync cost is measured only on a Mac, with stand-in models.** Linking entries one at a time, as `appendEntries` does, slows with the square of the collection's size: 1,000 into an empty collection took 0.13 s to link and 0.12 s to save, 1,000 into one holding 3,000 took 0.69 s, and 7,500 took 6.7 s. Handing the relationship one array linked 7,500 in 0.37 s with the inverse set on every row. That was on a collection already saved; it was not tried on a never-saved one, where the relationship is `nil` and the code's own note measures only the inverse assignment as correct in both states (`CollectionAddDocumentsSheet.swift:171-188`). So the linking cost belongs to the helper the design reuses, not to the feature, and the limit rests as much on sync cost, which is unmeasured: no figure exists for an iPhone or for CloudKit exporting a thousand records. A collection grown past a few thousand entries by repeated commands will feel the link cost, and the picker reads every collection's count.
- **The launch sync's clear trusts this device's store.** The three guards in lane 5 cover a failed fetch and the legacy migration. They do not cover a device whose store is still importing from iCloud at launch while its index already holds tag strings: the clear would remove the strings for assignments that have not arrived, and the next launch would restore them. Reasoned from the code, not run.
- **A project side effect to state in the manual.** A project's collections feed its History scope and its "Only new to this project" exclusion (`FRUSExplorer/ProjectContext/ProjectEngagedDocuments.swift:77-83`). A thousand unread results added to a project collection become history, and Project Leads re-seed.
- **Two devices before sync.** The same bulk tag on both leaves two rows per document. They display once, because the rail reads a set of tag ids, but they accumulate; a comment in the kit records that 14 of the 67 tagged rows on the real store repeated an id when it was measured (`IndexingPipeline.swift:3757-3759`). Two devices appending to one collection share positions, as they do today.
- **Things that stay stale.** My Tags counts are taken when the filter sheet opens, from the index at that moment (`FRUSExplorer/Search/SearchFilterView.swift:590-597`), so they are stale only in a sheet left open across a bulk tag. A new tag's name reaches the index's name table at the next launch, as with single tagging. Another device's tag filter follows at its next launch.
- **A narrow race.** The index strings are computed before the loop runs. A tag removed in the rail in that fraction of a second can be overwritten in the index until the next launch.
- **A lost selection.** A new query empties the picks without asking, and with checklist on, opening a picked row un-picks it. Picks are cheap to remake, and nothing durable is lost.
- **Project mechanics.** 26 test files read one or both search view files as text (20 name `SearchView.swift`, 21 `SearchSheet.swift`), `SearchView`'s body is near the type-checker's budget, and 22 documentation blocks cite by line the files these lanes edit. New code belongs in new files.
- **Existing defects this work makes more visible,** none caused by it: with research logging off, opening a document does not hide it in checklist mode, though both manuals say it does and neither mentions the logging switch (`FRUSExplorer/DocumentView/DocumentViewModel.swift:630-636`); the single-document picker accepts a smart collection, where export drops the entry (`FRUSExplorer/Models/Collection.swift:114-117`); the toast's comment claims a VoiceOver announcement it does not make; the results list's last rows sit under the banner (#1565). Lane 2 fixes the second and #1565 tracks the fourth; the others deserve issues of their own.
