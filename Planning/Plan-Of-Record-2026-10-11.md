# Plan of record — from 2026-10-11

**Base:** `v2` @ `845d57ea` · build 49 is out (tag `build-49` = `34a51205`) · index **v69** on `v2`, **v65** in build 49 · the bundle is at corpus `99d851c79`, where HistoryAtState/frus still stood when read on 2026-10-11. Thirteen issues are open, and no pull request.

**Status: LIVE — the plan of record from 2026-10-11.** It replaces `Completed/Plan-Of-Record-2026-09-28.md`. That plan's fifty issues, its week's queue, #1576, the first three lanes of #1577 and the index bump are done, and forty pull requests have merged since build 49. The owner reviewed it and the open issues on 2026-10-11 and took the seven recommendations of §0. What that plan left open is carried here, in §3 and §5; its own text is the record of how each item was found. **Amended 2026-10-12:** decision 8 of §0 puts the printed-form fallback for Collocates in the queue, before build 50.

§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 11, 14. (This is the Visual-Marketing-Plan §7 steps that are done, carried unchanged from the 2026-09-28 plan and checked by `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan`. It names that plan's §7; this file has no §7 of its own.)

---

## 0. Decisions of 2026-10-11, and the rules that still bind

**The owner's seven answers.**
1. **Before build 50:** the label table's repair (#1644), then one pull request of small fixes (#1643, #1617, and a Copy button for #1608's record), then the build.
2. **The grammar's country words stand on their own.** `ParsedSourceNote.subjectNumericAreaWords` is frozen at today's 155 words. `DepartmentSeriesTests.areaWordsMatchTheArtifact` holds it equal to the label table's area codes; #1644 replaces that test with one that pins the list itself. A change to the list changes what indexing stores, so it waits for the next index bump (§5a). A repaired table therefore needs no re-index.
3. **#1642:** a Live Activity that no index run is driving is ended at the next launch, and each update carries a stale date, so the system marks an activity stale when the app stops updating it.
4. **#1619:** the collection editors refuse a hand-added document, heading, note or passage in a smart collection, with the sentence the picker already uses ("Smart collection. Its documents come from its saved search."). Both Collections lists mark a collection as smart where they showed "0 documents".
5. **#1545:** the destination is the owner's to name. An email address needs no GitHub account from a tester. Nothing is built until it is named.
6. **Three findings a reader can meet were filed** on 2026-10-11: #1646, #1647 and #1648. The other unfiled findings stay in this plan (§5b). A finding is filed as an issue on the owner's word.
7. **This plan.** The 2026-09-28 plan and the #1576 assessment are in `Completed/`. The index bump's brief stays at the Planning root, marked complete, because `FRUSCoreKit/Search/IndexingPipeline.swift` cites it by path in four places.

**Added by the owner on 2026-10-12.**
8. **The printed-form fallback for Collocates is a lane, before build 50** (#1608). The iPhone's record was collected on 2026-10-11 and read the next day: on build 49, in the foreground, under iOS 27.0.1, iOS never answered the request for the English lemma data. That is the case no change to the app's check can fix, and the one the 2026-09-28 plan made the fallback wait on. The owner approved the fallback on 2026-09-29 on one condition, which stands: every surface that falls back says that it did, says why, and says that results can differ from a device whose language analysis reduces words to their dictionary forms.

**Rules carried from the 2026-09-28 plan.** Each is the owner's, and none is changed here.
- **The queue is serial.** The next pull request is pushed when the owner has merged the one before. Auto-merge is never enabled.
- **One fresh session per pull request**, started from this plan and the issue numbers, and ended at the merge.
- **Small defects are fixed inline**, several related issues to one pull request, with one review pass on the diff. `lane-dev.js` returns only for a lane with real design risk, one lane per run.
- **Tests are scoped with `-only-testing` while developing.** Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- **One index bump a build.** A change to what indexing stores waits for the next bump (§5a).
- **Lanes edit the manuals** where they change what a manual describes, and leave the AI Generated notice. The owner's review of the manuals is not before 2026-10-21 (`Planning/Manual-Update-Build-49-Owner-Review.md`).
- **The web edition.** Sessions follow `CLAUDE.md`'s four rules. Where an app goal complicates the web edition, the owner is shown the option that stays within the rules and the option that sets them aside.
- **The EditableContent range gate stays exact** (`EditableContentKeyTests.everyRangedBlockHoldsItsKey`).

---

## 1. The queue

| | Pull request | Issues | Index bump |
|---|---|---|---|
| 0 | This plan, and the two documents archived with it (merged, #1649) | — | no |
| 1 | The Subject-Numeric label table and its generator | #1644 | no (decision 2) |
| 2 | Small fixes | #1643, #1617, #1608's Copy button | no |
| 3 | The printed-form fallback for Collocates (decision 8) (done 2026-10-12, ahead of 2 on the owner's word) | #1608 | no |
| 4 | Build 50 | — | carries v66 to v69 |
| 5 | A Live Activity that nothing ends | #1642 | no |
| 6 | Smart collections in the editors and the lists | #1619 | no |
| 7 | Search: the document gate, Filters after a launch, and a superseded run | #1646, #1647, #1648 | no |
| 8 | Search inside a set, lanes 4 to 7 | #1577 | no |

- **1 — #1644.** The shipped table reads some files wrongly, and the build that is out shows it: under the 1964–1973 schedule `UK` reads *Ukraine*, `UAR` *United Arab Republic USCG US Coast Guard*, `USSR` is cut short, and every numbered `AID` file reads a piece of another line; under the 1963 schedule `CUBA`, `IA` and `NR EAST` are wrong; `FIN` is wrong under both. The table is also behind version 69's keys (a new key's country is named for about four documents in five, where it was nine in ten), and its `coverage` block describes an older index. The generator no longer reproduces the table on macOS 27.0.1 from the same handbooks. `Planning/Generators-Runbook.md`'s entry lists every wrong entry and what the generator writes today. The session needs the owner's handbooks in `SCHEDULE_DIR`. **It reads every label that changes** and lists them in the pull request, as `CLAUDE.md` requires before a regenerated table ships. Two shortcuts were measured in #1645 and rejected: a lookup that ignores dashes, and pairing countries at run time, each of which puts "Ukraine and United States" on `POL UK-US`.
- **2 — small fixes.** #1643: the Archival Network's legend reads "The 1 squares are central-file classes", Browse ▸ Archives reads "1 docs", and Archival Neighbors lists a volume's documents in the text order of their ids (292 before 73). #1617: a categorical Audio Graph gives each point the category's name for its x value, as the framework asks; the owner's listen follows the fix. #1608: Settings ▸ Data & Recovery ▸ Diagnostics ▸ Language Analysis gains a Copy button for the session's verdict and re-check lines. The owner's own record came from a Mac on 2026-10-11, so the button is no longer what #1608 waits on. It is kept because the phone holds those lines for about nine hours and a tester has no other way to send them.
- **3 — the printed-form fallback (#1608, decision 8). Done 2026-10-12.** It went ahead of pull request 2 on the owner's word that day; it depends on neither 1 nor 2. On a launch whose language check finds no lemmatiser, Collocates, the word cloud's Distinctive sizing and Related Documents' shared-word chips count printed forms and compare them with a second corpus reference counted as printed, `keyness-baseline-printed.json`, which `CloudVectorsGenerator` writes from the tagging pass that writes the first. Before, Collocates refused and the other two were withheld. A launch with a working lemmatiser shows what it showed. That is every launch of the Mac that has been measured: the fallback follows the launch's verdict and not the platform, so a Mac shows nothing new unless its own lemmatiser is missing.
  - **One sentence of this plan was wrong.** It said the fallback "counts "missile" and "missiles" apart". Under the default settings it does not. A printed count is the count a launch with no lemmatiser has made since #1373: the word lowercased, and then its regular plural folded by rule while *Merge plural and singular forms* is on. So "missiles" is counted under "missile" in both references, while "negotiate", "negotiated" and "negotiating" are three words (19,472, 9,272 and 15,267 in the corpus, against 44,011 for the dictionary form), "men" is not "man", and a name ending in s is clipped on both sides ("Dulles" is counted as "dulle", and shown as the page prints it). It is exact because a scope and the reference are counted by the same code, and the generator's verify run held the reference to a walk with no lemma scheme in all 553 volumes (314,616 documents). Every example in the new copy is the verb. Counting plurals apart would be another rule on both sides and a regeneration: it is the owner's to ask for (§3).
  - **Each surface that falls back says so**, says why, and says that results can differ from a device that reduces words to their dictionary forms: a Mac, or another iPhone or iPad. Six new strings and two changed ones, each with its EditableContent block, and both manuals. A Collocates count of printed forms that ranks nothing says so above its message, and Related Documents says how its rows' shared words were compared whether or not a row has a chip. For a Distinctive export the CSV says all three things; the image's caption and the axis label are short labels and say that the words were counted and compared as printed, as a cloud counted as printed has said in its caption since #1373 (§3 has the question). *Counted as printed* now says that counts can differ, which it did not, and the CSV caveat's example, "negotiation" and "negotiations", was false with plural folding on and is now the verb.
  - **Measured.** The new file is 1,238,773 bytes (about 439 KB deflated) and `keyness-baseline.json` gains 24 for the key naming its form, so each app's bundle grows by 1,238,797 bytes. A generator run is 21 minutes 24 seconds on the M5 MacBook, 77 seconds more than before, not the 50 to 60 minutes this plan gave, and longer with its new verify mode, which walks every document again as a device with no lemmatiser does, with each of the two taggers a device builds, and found no difference in any of the 553 volumes. The unchanged generator first reproduced the three shipped files byte for byte.
  - **No index bump and no CloudKit change.**
  - **The look was on a simulator, with the fault made.** The iPhone 17 simulator under iOS 27.0 kept its lemmatiser in fifteen launches of fifteen (fourteen relaunches and one after a fresh boot); the iPad Pro 13-inch (M5) lost it by itself once in three, in a test run and not where it could be looked at. So a debug-only launch argument, `FRUS_DEBUG_NO_LEMMA_ANSWER=1`, leaves the lemma request unanswered as iOS left it on the phone, and the verdict line then reads as the phone's did. All three surfaces were seen falling back with their notes, and seen without them on a launch that lemmatises. On the Mac, in the isolated check copy, Collocates, the word cloud and Related Documents were walked and show nothing new, and Language Analysis reads *Working*; the fallback itself cannot be made there, since the copy is a release build. Not seen on the owner's iPhone, where the fault is (§3).
  - **One review pass** found eight things, the first a test the full run would have failed (the new file had no provenance row). The session entry lists them and what each changed.
- **4 — build 50.** §2.
- **7 — the three Search issues** go before #1577's lane 4 because #1646's fix is in `MacSearchViewModel`, which lane 5 edits. #1648 changes `SearchService` or `FTS5Store`, which are kit code: it owes `swift test` and a line for the web edition. If its design carries risk, it is a pull request of its own.
- **8 — #1577.** Lanes 4 to 7 are as the implementation plan on the issue gives them; `Planning/Issue-1577-Search-Within-Results-Assessment.md` is the assessment. Lane 4 waits on the owner's three timings (§3). Lanes 4 and 5 adopt the two layered routes, whose header and capture sentences lane 2 wrote and no search produces yet. Lane 4's UI tests reach a Meaning list through lane 3's seam (`FRUS_UI_TEST_SEED_MEANING`); `Planning/UI-Test-Destinations-Runbook.md`'s entry for `MeaningResultsSeamTests` says what it lists.
- **The order after build 50 is this plan's.** The owner can reorder 5 to 8.

---

## 2. Build 50

Build 50 carries the index bump (the owner's decision of 2026-10-11): versions 66 to 69, merged as #1638, #1639, #1640 and #1645, so a library re-indexes once, at its first launch. Nothing in the queue holds the build but pull requests 1, 2 and 3.

**Steps.** `CLAUDE.md`'s list under "Bumping the build number or version" is the procedure. With it, as for build 49: one full unit run on iPhone 17 under iOS 27.0, `swift test`, a clean `build-for-testing` read for warnings, the Mac build and a walk of the Mac check copy; one full re-index census on a pinned device, since this build re-indexes every library from version 65 to 69; the window-fronting audit; `Scripts/check_repository_links.py --stamp`; and the Gemma policy re-check.

**CloudKit.** `CloudKitSchemaInventory.swift` has not changed since the commit build 49 was cut from, and no `@Model` or stored property has been added, so nothing awaits a deploy. `Scripts/check_cloudkit_schema.py` still has to be run before the archive.

**What the TestFlight notes owe.** They are written when the number is bumped, 4,000 characters each at most, with fixes in one line.
- The library re-indexes once at first launch.
- **Search results:** Mark Page Reviewed with Undo; Add to Collection and Add Tags from a result's menu; selecting results on iPhone, iPad and Mac (#1576). A Meaning search ranks inside a working corpus or a project's History scope (#1577 lane 1).
- **Browse and the reader:** a chapter of prose alone opens in Browse (#1535); the text a section prints at its own level is a **Read** row, and Search finds it (#1536); 1981–88 vol. XVI's documents list their persons and terms (#1599); a cross-reference to a whole volume opens the volume (#1603), and one to a footnote counts for the document that holds the note (#1638).
- **Collocates on iPhone and iPad:** where the device's language analysis has no dictionary forms, Collocates, Distinctive sizing and Related Documents' shared words compare printed forms and say so, where they refused or were withheld (#1608).
- **Archives:** a Subject-Numeric file has Archival Neighbors, one list for one file, and the files with no subject number are grouped under their category (#1645). A lot cited through the National Archives has its lot cards (#1589).
- **The reader's page:** it meets WCAG 2.2 AA contrast (#1578), and person names and cross-references print without their underline.
- **Accessibility:** all eleven About the Series charts have an Audio Graph (#1587).
- **The 47 documents restored to 1952–1954, vol. IX, Part 1.** A reader updates the volume to get them.
- **One line of fixes**, taking in the week's queue of 2026-10-09 (#1565 among them, the banner that covered a list's last rows), #1616, #1618 and pull requests 1 and 2 above.

**Fixed by the build's going out:** builds through 49 refuse a fresh download of the two semantic shards re-packed on 2026-10-10 (`frus1952-54v09p1`, `frus1902app1`) and score those two volumes from the bundled tier. The web edition's pinned manifest disagrees the same way until its pin moves.

**Owed by the owner before it:** the reading of the semantic map's 172 region labels (§3).

---

## 3. Waiting on the owner

**For the queue.**
- **The map's 172 labels**, read before build 50. With it, a yes or no on whether the cost of a relayout is an issue: adding 47 documents moved 79,067 between a region and none.
- **A destination for #1545** (decision 5).
- **The fallback on the iPhone**, once a build carries it (pull request 3): on a launch where Settings ▸ Data & Recovery ▸ Diagnostics ▸ Language Analysis reads *Limited*, Collocates ranks under its note, a cloud sized by Distinctive reads *Counted and compared as printed*, and Related Documents' rows carry *shares:* chips under theirs. And two questions it leaves. Whether a printed count should fold plurals at all: it does, as it has since #1373, so "missile" and "missiles" are one word on such a launch and "negotiate" and "negotiated" are two. And whether an exported image and a collection's cloud plate should say more than that the cloud was counted, or counted and compared, as printed: the screen and the CSV say that results can differ on another device, and those two short lines do not.
- **Three timings for #1577's lane 4**, on an iPhone with the search model downloaded, read in Console from `subsystem:bottsywattsy.FRUS-Explorer category:SearchTiming`: a Meaning search inside a working corpus of about 1,000 documents; the same inside a 7,500-row browse saved as a corpus; and a common word in Keywords mode inside a 100-document corpus.
- **One Audio Graph heard on a device** after #1617's fix. Not heard on a device either: #1587's eleven charts, #1616's two tables and #1594's toast.
- **`lgbtq-rights`.** Four volumes of the manifest carry the tag and the bundled taxonomy has no name for it, because the Office's file holds it inside a comment (#1622). Whether it joins is the owner's to decide.

**Not for the queue.**
- **The manuals' review**, not before 2026-10-21.
- **Looks on an iOS 27 device** (§4): the Topics lens, Corpus Analytics on an iPad, and Text Color in a collection's note on an iPad.
- **For a Feedback report to Apple on #1608**, if the owner wants one: five launches in a row (force-quit, reopen, wait 60 seconds, try Collocates) and a collection of the phone's last hour of log straight after, which would hold a good launch and a bad one side by side. The record that decided the lane is on the issue.
- **The Mac's Sync Log after any sync event** (#1606's check): whether the shipped app is refused its own log store, as a simulator's process is.
- **The Mac's Search window with a selection** (#1576's lane 4): VoiceOver heard aloud, dark appearance, Full Keyboard Access, and a search that fails.
- **From the build-49 wave, not read again for this plan:** the by-eye checks of each lane, lane READ's four questions (D3's sub-choices, whether the figure-image pass stays automatic, the privacy label, onboarding's "≈ 3.5 GB"), SYNC's device check and the five steps of the Mac check of 2026-09-25. `Completed/Plan-Of-Record-2026-09-28.md` §0a, *The release*, lists them.
- **App Store Connect and marketing:** the EULA, the privacy label and the listing (three sentences of `Store-Listing-Draft.md` wait on the owner's wording); three screenshot placeholders, and the Mac and iPad captures build 48 made stale; Visual-Marketing-Plan steps 5, 10, 12, 13, 15 and 16. Also from build 48: the by-eye checks of four of its pull requests (#1486, #1490, #1501, #1519), Mac hover, iPad Stage Manager, and confirming that the upload's dSYM warning is gone.
- **#234** is deferred indefinitely.

---

## 4. OS 27: what is left

**Done.**
- **The source builds clean** under Xcode 27.0 (Swift 6.4): no source warning in the app or in either test target, on a clean `build-for-testing`. The two residues `CLAUDE.md` names are not source.
- **The unit target passes on iPhone 17 under iOS 27.0**: 7,029 tests in 828 suites at #1645's landing, with 6 known issues.
- **The UI suites are adapted to iOS 27**: the reordered element tree, the idle counter, the allowance flags. `BrowseWithinScopeTests` passes there since #1565.
- **Nothing in the app is forced by the release.** The deployment target is 26.0 and no code is gated on 27. The exposure table of `OS27-Semantic-Retrieval-Design.md` §2 had one hit, `UIScreen.main` in a debug probe, and it is gone.

**Left.**
- **Siri, App Intents and `IndexedEntity`** (workstream A of `OS27-Semantic-Retrieval-Design.md`). Never built, and the app has no App Intents code. It was held for want of the SDK and has been unblocked since Xcode 27.0. It is the one OS 27 feature the plans name. It is parked, with no issue; its first session would be an assessment against the SDK, since whether Siri surfaces an indexed document is behaviour no declaration settles.
- **The lemmatiser on iOS 27 devices** (#1608). Measured on the owner's iPhone under iOS 27.0.1 on 2026-10-11, on build 49 and in the foreground: iOS answered the requests for lexical classes and names at once and never answered the one for English lemmas. Its own framework logged that the lemma data "are downloading" and queued the request, and no download was seen in the three minutes that followed. No change to the app's check can fix that, so the fallback was built as pull request 3 (decision 8, done 2026-10-12): on such a launch the three surfaces compare printed forms and say so. What it does not change: the lemmatiser is still missing on those launches, the clouds still count printed forms there, and a part-of-speech lens still counts nothing on a launch with no lexical classes. How often it happens is not measured: the phone keeps the app's log lines for about nine hours, and one session's record was left.
- **iPad simulators under iOS 27.0** (#1620). A UI test that opens Corpus Analytics is killed with the simulator, so those suites are read on `OS=26.5`. Measured on 2026-10-11 as well: a plain launch of the `845d57ea` build on the iPad Pro 11-inch (M5) under iOS 27.0, with no test involved, ended the simulator's `backboardd` about five seconds in, three times of three, in the Metal frames #1620 records; that simulator had last run the analytics suites, and setting the app's saved state aside did not prevent it. Not tried on a newly created iPad simulator, and not added to the issue. The owner's iPad runs these builds under iOS 27, so this reads as the simulator's. No one has recorded Corpus Analytics opened, closed and the app quit on that iPad.
- **`RichTextRestingCapTests` on an iPad host.** The host crash recorded on 2026-10-02 (iPad Pro 13-inch (M5), iOS 27.0) was not met on 2026-10-11, on other simulators: the suite ran its 21 tests on an iPad Pro 11-inch (M5) and an iPad Air 13-inch (M4) under iOS 27.0, and the same two failed on each. "The link alert takes focus…" fails under iOS 26.5 too, so it is the iPad host's. "While the colour picker is up…" fails only under 27.0: the host is never handed a `UIColorPickerViewController`. Both pass on iPhone 17 under 27.0, where the suite's 21 tests ran again on 2026-10-11. Whether Text Color presents its picker for a reader on an iPad under iOS 27 was not seen in the app, because of the item above.
- **Never looked at on an iOS 27 device:** the Topics lens, owed since build 48.
- **The Subject-Numeric label generator under macOS 27** (#1644, pull request 1).

---

## 5. Open, and not in the queue

None of this is designed or scheduled. Where a line names a pull request or an issue, that one's session entry in `DEVELOPMENT-PLAN.md` has the measurement.

### 5a. For the next index bump

Each changes what indexing stores. They go together, in the build after 50, if the owner asks for a bump.
- **The country words** (decision 2): any change to the 155.
- **A volume's list of sources is read only where it prints a subject number.** About 670 rows in 85 volumes name a file with none (`POL US-USSR: general U.S.-Soviet relations`), by a pattern that also catches 29 office files, and 259 rows in 67 volumes print a number in a form still refused (`POL 7 US/Harriman`). None has a neighbours badge, and each is still a collection of its own in the authority. Reading them also moves the four bundled files that follow the authority. (#1645)
- **62 citations of a Subject-Numeric file still store no class:** 7 give a block of years alone, and 55 print what the app does not read as a designation. (#1645)
- **A prose section of a kind the index does not promote** is not indexed, and Browse says "No documents in this section." of it. `note-on-covert-actions` is 866,558 characters in 45 volumes, `message` 644,638 in 9, and `frus1945-50Intel`'s eight chapter introductions 170,416. (#1640)
- **3,516 sections that hold documents have nothing of their own but a footnote on the heading:** 471,486 characters, and 5,173 cross-references that reach nothing. (#1640)
- **A section's row carries no date** unless its own text prints one: 1,227 of the 1,337 have none. Section divisions carry `frus:doc-dateTime-min` in the corpus, which the parser reads on documents alone. (#1640)
- **Whole-volume references in text the index does not hold:** 1,322 of the corpus's 8,266. Not broken down. (#1638)

### 5b. Found since 2026-10-09, and not filed

- **In files #1577's lanes 4 and 5 edit**, so those lanes should read them first:
  - Counts with no form for one, or not grouped: the facet panel's "Describing all 1 matches" and "Describing the 1 closest matches", the capture's caution for a Meaning list of one document, three sentences that say "1 reviewed documents", and the checklist strip's "1852 reviewed hidden".
  - Checklist Mode: Mark Page Reviewed and a row's own Mark Reviewed can mark the last search's rows while another search is under way, the gap #1576's lane 4 closed for a selection.
  - Selecting results: a selection begun while a Keywords or Meaning switch's search is under way lasts into the other engine's list when the words are the same (read, not run); a browse with no words can show All N Shown over the 1,000 one add takes (read, not run); from the picker's empty state, Done on an untouched new collection returns to a picker that still says No Collections (seen once); and on the Mac the volume id and the chips of a highlighted row keep their colours and are hard to read.
  - Under Meaning the Mac's Reading picker is not drawn dimmed. Collocates' "Within" picker has its label off-screen and its left cap clipped on the Mac, and its caveat prints counts ungrouped ("6387 matches, in 1512 documents").
- **VoiceOver on iPhone and iPad** reads neither a result row's tag chips nor its classification chip.
- **Wording:** the corpus lists say "The capture stopped short of every match" of a Meaning capture; a full Meaning list is recorded in search history as a floor, so the method appendix prints "at least 100"; the appendix's CSV prints `top=100` for a Meaning search inside a set and does not name the set; the Keywords prompt reads "Enter keywords to search the FRUS corpus." with a corpus applied; and the HTML format card reads "Web page + word cloud" though PDF and Word carry the cloud too.
- **Storage and tags:** the storage hubs' Index Remaining counts only volumes with no documents in the index, and `UserTagAdmin.merge` leaves the index's tag column to the next reconcile.
- **Sections (#1640):** Add Documents' list of a volume and the Mac graph window's document picker read the stored order, where a section's own text follows its documents (read, not seen); no section row has a vector, so a Meaning search returns none; "No documents in this section." still shows under a section that holds only sections on iPhone and iPad, because `BrowseNestedSectionTests` reads that sentence as its proof that a load finished; and a meeting's row does not say its day.
- **Subject-Numeric files (#1645):** a file with a country reaches no other country's file, and a numbered file still does (`POL 27 VIET` finds `POL 27 VIET S`; 18 numbered keys begin another at a space). 688 Department-worded notes store a class the Archives Visit packet does not key by, and keying them by it would move 688 more stored keys. In Archival Analytics a family's files are listed without their countries wherever the family's volumes span both handbooks, which for `POL` is everywhere; Browse ▸ Archives names them.
- **Archives Visit:** the packet's line for a divided lot cited through the National Archives is unchanged (#1589's optional fourth step).
- **Cross-references:** `CrossRefKit`'s mirror grammar has no whole-volume case. The bundled resolved-edge index leaves out the 273 references to a footnote in another volume and the 383 that sections' own text makes to other volumes' documents. The volume graph holds 1,256 references to volumes outside the catalogue where it held 12, and how it draws such a volume was not looked at.
- **Tests:** four UI suites still open the first row labelled "Subseries", which a simulator holding real volumes breaks (#1641). #1633's body says its Mac half was run where its session entry says it was not.
- **Upstream:** the 47 restored documents have no subject tags, since the Office's subject export of 2026-08-20 stops at Document 899, and nothing was posted to HistoryAtState/frus#469 about the restoration.

### 5c. Carried from the build-49 wave

The 2026-09-28 plan's §0a (*Not placed*), §4 and §4a hold the full text. Read again on 2026-10-11 where a line says so.
- **Done since, by the index bump:** the film sections' player text (2 rows, not 12), the persons list's "until January, 1953", and the Subject-Numeric files stored without a designation (62 remain, §5a). The label table that describes itself out of date is #1644.
- **Still so on 2026-10-11:** `FilterChip` and `CrossProjectNoteIndicator` are the two views nothing constructs; 14 Swift files outside every target have no license header; 9 Swift files cite #1210, #1211 or #1257 where the work merged as #1250, #1251 and #1256.
- **From #1558 (HYG), not read again:** Add to Archives Visit… on a smart collection whose search cannot run yet does nothing and says nothing; code only tests call (`TripPacketBuilder.build(documents:researchQuestion:dataSource:)`, `ProjectContextViewModel`, `CollectionFootnoteStyle`); ⚙ Collection on an iPad narrower than the Air, where the test helper has no overflow branch; `PROJECT_ONLY` with a store for some of the planned groups still rewrites the run-wide artifacts; a vector pack with no layout writes a volume's shard before it finds a later volume missing; and the map preflight counts by the store's heads.
- **From #1559 (READ), not read again:** two images are fetched that no document draws; the export header takes no dateline from an `<opener>`; an image that arrives late still moves the page under a reader who is not at a footnote; an image in flight when an update drops its name is stored after the prune; two things read in passing in `cancelDownload` and `PDFCollectionExporter.drawFrameWithHighlights`; and the figure fetch's run-level de-duplication has no test.
- **Left by the lanes themselves:** the Spotlight item of a left-out container and the export check's wording for one (PAGE); the bracketed `@n` on six more labels (MACCOL, CITE); Person Analytics' ranking chart, which sets the labels XREF fixed elsewhere; and the comment-only fixes in four Swift files (`Project.swift`, `SimilarityModel.swift`, `ProvenanceSource.swift`'s `curatedDisclosure`, `TripPacketSheet.swift`).
- **Unfiled, from the audit of 2026-09-27, not read again:** on iPhone and iPad Facets is disabled in Meaning mode, where the Mac offers it; the project reach scan and the off-index leads count second-edition reprints of documents the reader already holds; and Archives Visit derivations go stale when an indexed volume is updated, and an older derivation can finish last.
- **Designed and not built, parked.** The list is the 2026-09-28 plan's and was not read again; #1587 and #1616 have since given Audio Graphs to some charts. Dateline places (blocked on the owner's toponym curation); links from the map to Search and Related; a heat-matrix cell drill-down; a Search command menu and shortcuts; standalone token editors; a subseries pole picker; a region-share chart; an iPhone rail peek strip; an immersive Read mode; a reader that follows the system text size; `AXChartDescriptor` for four chart families; Differentiate Without Color on the map; and about 37 fixed-size text sites. The App Intents assessment is §4's.
- **Deferred or declined, no action:** #234 and its programs, W12's parallel editions, W14, the MCP server and `CSUserQuery`.
- **Residue of the documents archived on 2026-10-01** (that plan's §4a): subject tags and the person crosswalk for 1981–88 vol. XVI, when the upstream drops include it; lot `95D407`, to retry at the next keyed NARA run; the annotation-integrity design's three unbuilt cases, and `CD_AnnotationReview.CD_annotationId`, which has no writer; the Archives Visit list's "Seeded from …" caption, which waits on a stored field and so on a CloudKit deploy; the archival exports and the provenance dashboard, which rest on the source-note parse and do not print its residual; and the cross-platform review package, which waits on the owner's yes or no to the residue its `STATUS.md` §0 lists.
