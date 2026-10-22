# Plan of record — from 2026-10-21

**Base:** `v2` @ `f962077e`. The tree reads version 1.0, build 1861, which has not been uploaded. Index **v71**, person rollup **v12**, and EmbeddingGemma 2 vectors under digest `89481b18`. Sixteen issues are open, and no pull request.

**Status: LIVE — the plan of record from 2026-10-21.** It supersedes `Completed/Plan-Of-Record-2026-10-14.md`, whose work is done: Track A (A1 to A19, all but A7, which its decision 57 deferred), Track B and the build-51 screenshot sweep S0 to S5 (#1670 to #1755).

It is written from two sources:
- `Planning/Planning-Review-2026-10-21.md`: the documents' dispositions, the backlog in tiers, and fifteen questions;
- the owner's answers to those questions, numbered here 84 to 98.

Its aim is **App Store submission of FRUS Explorer 1.0**: first the nine issues that gate it, then the retakes, a TestFlight pass, and the submission.

§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 14, 15. (These are the Visual Marketing Plan's §7 steps that are done; `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` checks the list. Steps 10 and 15 were struck on 2026-10-21, for the screenshot sweep and the composed store frames. The line names that plan's §7; this file has no §7 of its own.)

---

## 0. Decisions, and the rules that still bind

**Decisions carried from the 2026-10-14 plan.** Their full text stays in `Completed/Plan-Of-Record-2026-10-14.md`. This plan relies on these:
- 17: build 51 ships EmbeddingGemma 2 under Apache 2.0, so the custom EULA is not entered.
- 18: the encoder reaches a device as an opt-in download, 310 MB, with no agreement step.
- 25: the version is 1.0, and 1861 is the submission's build number.
- 27: 1.0 ships with the manuals' *AI Generated* notice.
- 28 to 31: the listing's three sentences, and free, in every storefront, English only.
- 32 to 34: the store's tenth frame, landscape iPad frames, and the README's hero row.
- 35: the privacy label is Data Not Collected.
- 36 and 58: the Privacy Policy and Support pages, and the two addresses.
- 55: build 51 takes none of the name-authority overlay's Wikidata and VIAF ids.
- 57: A7 is deferred.
- 61: sections stay out of Meaning search.
- 72: #1620 is re-tested on iOS 27.1.
- 82: the sittings' findings go to this plan.
- 83: 1861 stays until the app is ready for submission. Decision 87 refines it.

**The owner's answers of 2026-10-21** to the review's fifteen questions, given in four rounds in one sitting. Numbered on:

84. **Nine issues gate App Store submission**, all labelled *before App Store submission*: #1756 to #1763, and #1766 (decision 85).
85. **The dead page-link tap is #1766, in P0.** A page link into a volume not on the device does nothing, on iOS and the Mac. The tap resolves through the device's `PageRangeStore`, not A18b's bundled page map.
86. **#1761 takes #1726's three quote-doubling siblings and the two rows cut at the largest accessibility size** (its items 7 and 8). The method appendix's plain-text line stays the owner's call.
87. **The TestFlight pass is 1.0 (1776), and the App Store submission is 1.0 (1861).** The owner's words: "because 1.0/1861 hasn't been submitted to test flight yet, we can still change build number for a test flight release. bump build number down to 1776 for a test flight pass. we will restore build number to 1861 for the app store submission."
    - So decision 83 is refined. Once the P0 fixes and the retakes are in, the build number goes to 1776 for the TestFlight upload; after the device pass it is restored to 1861 for the submission. Each bump follows `CLAUDE.md`'s procedure, the README line and its mirror included.
    - App Store Connect accepts this order. Within version 1.0 each upload must be numbered above the last, and on the Mac above every earlier upload. Build 50 went up as 50, so 50, 1776 and 1861 all rise; the reverse order would be refused.
    - Should the device pass need a second TestFlight upload, its number lies between 1776 and 1861.
88. **A retake sitting follows the P0 fixes, before submission**, for every screen the fixes change, in the manuals and the store frames.
89. **The listing launches without App Previews.** They come in a later update (Visual Marketing Plan step 12).
90. **Build 52's order is decided after submission**, by the next plan. §3 lists its candidates.
91. **C-3 runs after submission and before build 52 starts.**
92. **#234's documents stay in place as deferred.** `CLAUDE.md`, kit code and `tools/semantic-harvest/` cite them.
93. **The cross-platform review's leftovers that were not already filed are declined.** Its folder is marked complete in place; two app files cite it.
94. **The manual review, and taking the *AI Generated* notice off, wait past build 52.** Decision 27 stands for 1.0.
95. **#1690 and #1691 are closed** (2026-10-21), each with a comment naming the lanes that built its lines. #1690's section vectors stay in §5 (decision 61).
96. **The person authority's deferred work is #1767, in P2.** It points at the two 2026-10-17 memos, which stay until it runs.
97. **`DEVELOPMENT-PLAN.md` is split at 2026-10-01.** Its entries before that date are in `Completed/DEVELOPMENT-PLAN-to-2026-09.md`, with the one that stood in its header (the N wave, 2026-08-06/07). The live file keeps the plan's header, a pointer and the entries from 2026-10-01. No test or tool reads the log; code and test comments cite its entries by date or by name.
98. **This plan lands as one docs change** with the old plan superseded, the review's document moves and in-place marks, the Visual Marketing Plan's §7, and decision 97's split.

**The owner's correction of 2026-10-22**, given while L5 was started and carried into the plan by L5's pull request:

99. **`build-51` tags the TestFlight build, 1.0 (1776), and `version-1.0` tags the submission, 1.0 (1861).** The owner's words of 2026-10-22: "include a plan of record correction: we will tag the 1.0/1776 test flight release as "build 51" in github, not 1.0/1861. 1.0/1861 will be tagged as "version 1.0""
    - The owner tags the commit uploaded to TestFlight as 1.0 (1776) `build-51` after the upload (R2), and the commit submitted as 1.0 (1861) `version-1.0` (R3).
    - A git tag name cannot contain a space, so "version 1.0" is spelled `version-1.0`, as "build 51" is `build-51`.
    - This refines decision 87, which set the two build numbers and named no tag. Until this correction R3 put `build-51` on the submission.

**Rules carried from the earlier plans and `CLAUDE.md`.** Each is the owner's.
- **The queue is serial.** The next pull request is pushed when the owner has merged the one before. Auto-merge is never enabled.
- **One fresh session per pull request**, started from this plan and the issue numbers, and ended at the merge.
- **Small defects are fixed inline**, several related issues to one pull request, with one review pass on the diff. `lane-dev.js` returns only for a lane with real design risk, one lane per run.
- **Tests are scoped with `-only-testing` while developing.** Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- **Every heavy job goes through `Scripts/heavy.sh`**, one at a time on this Mac.
- **One index bump a build.** None is planned for 1.0's remaining work, so a change to what indexing stores waits for build 52.
- **Lanes edit the manuals** where they change what a manual describes, and leave the *AI Generated* notice (decision 94).
- **A test that pins specific language is an advisory reminder** (decision 9): the edit goes ahead, the test is brought to the new text in the same change, and the reason is written where the test is.
- **The web edition.** Sessions follow `CLAUDE.md`'s four rules. Where an app goal complicates the web edition, the owner is shown the option that stays within the rules and the option that sets them aside.
- **The EditableContent range gate stays exact** (`EditableContentKeyTests.everyRangedBlockHoldsItsKey`).
- **A finding is filed as an issue on the owner's word.** The unfiled findings stay in §5 until then.

---

## 1. Track A — to App Store submission

| | Pull request | Issues |
|---|---|---|
| L1 | Small copy and drawing defects, and text that drifted from the data | #1761 (with decision 86's items), #1762 |
| L2 | Search: stale state, and a question typed in Keywords mode | #1758, #1760 |
| L3 | Analytics: numbers that contradict their own labels | #1756 |
| L4 | The indexing banner's totals, and the Research Guide's first-queue sheet | #1757 |
| L5 | First launch: the dock, the splash and onboarding's cloud | #1759 |
| L6 | A page link into a volume not on the device | #1766 |
| L7 | The launch kit, the composer and the check copy's README | #1763 |
| R1 | The retake sitting (decision 88) | — |
| R2 | The TestFlight pass, 1.0 (1776) (decision 87) | — |
| R3 | The submission, 1.0 (1861) (decision 87) | — |

- **L1 goes first**: it is cheap, and its fixes show on captured screens. L2 to L6 follow in any order the owner prefers. L7 is tools and copy; it can come any time before R1, since the composer's stamp shapes the store frames.
  - **L1 built on 2026-10-21** from `v2` at `1fdf4308`, on `claude/l1-copy-fixes-27e098`, and **opened as #1769** on the owner's word of 2026-10-22; not yet merged. A commit for each item or group of #1761, one for #1762, then a docs commit; not kit code, no index version, no CloudKit change. **#1761**: one unresolvable reference reads in the singular; an Administrations row says *1 vol*; a working corpus's coverage line groups its counts; frus1961-63v23's label loses its leading colon; the iPad rail toggle is tinted while the rail is open (a toolbar reads the button's `.tint`, never a `.foregroundStyle` inside its label; measured by pixel on iPad simulators under iOS 27.0 and 26.5), and iOS §4.2 says so again; the Mac date chip's ✕ measures 23×20 points with its own help, and a click off the glyph clears it (the check copy); the three quote-doubling siblings quote by `PinnedResultBase.quotable(_:)`, the appendix's plain-text line left as decision 86 says; and at the largest text size the Collections row and the two document rows wrap where they were cut. **#1762**: 88,059 (Mac §6.1), 37,899 and the shipped label (iOS §6.1h) and 3,977 (iOS §14.6, Mac §14.5), each read from its bundled file, and `ChronologyQueryTests`' two comments. #1762's lasting fix, manuals that stop hard-coding figures that move or a check that reads them from the bundled files, is put to the owner; nothing is built for it. The captures L1 changes, for R1: `ipad/research-rail`, `ipad/stage-manager`, `ipad/browse-administrations`, `ipad/browse-clusters-detail`, `macos/crossref-analytics-ranking` and `macos/crossref-analytics` (this session's log entry says what each shows).
  - **L2 built on 2026-10-22** from `v2` at `b385340c`, on `claude/l2-search-fixes-df74f5`, and **opened as #1770** on the owner's word of 2026-10-22; not yet merged. A commit for each item, then a docs commit; kit code (FRUSCoreKit, FTS5Store), no index version, no CloudKit change. **#1758**: on iPhone and iPad, emptying the Search field closes Facets and takes away the narrowings it made, a *Narrowed by* chip with nothing left to search runs nothing, and the binoculars menu's Facets is a toggle that closes the panel it opened (walked on an iPad Pro 13-inch (M5) simulator under iOS 27.0 holding S1's full index); the Mac's results list opens at its top for a new search and for another page (walked in the Mac check copy at `3dfe2741`); a working corpus records what narrowed its search, in the `sourceDescription` it already stores, and its save sheet shows **Narrowed by**. **#1760**: a keyword row's snippet starts at the rarest of the query's words that its prose holds, rarest across the index, with function words set aside while the query has another, so a question typed in Keywords mode marks *Marshall*, not *the* (over a full index, the first 100 rows of twelve questions marked a function word in 46 to 100% of rows and now in none; no single word's snippet moves); the snippet pass costs more where its scan runs on to that word, which this session's log entry measures in a release build; and the MATCH strip quotes each term as the tokenizer reads it, `"happen"` for `"happen?"` (parser 6.8, which also refuses `=cold. -=Cold OR -=Cold` as matching nothing). The captures L2 changes, for R1: every frame of *Berlin blockade*'s keyword rows, which now mark *blockade*: `ios/search-results`, `ios/search-facets`, `ios/search-tips`, `ipad/search-results`, `macos/search` and `macos/search-tips`, and the kit's frame 01 (this session's log entry says what each shows).
  - **L3 built on 2026-10-22** from `v2` at `3aa63d6a`, on `claude/l3-analytics-counts-3b801c`, and **opened as #1773** on the owner's word of 2026-10-22; not yet merged. A commit for each of #1756's three items, then a docs commit; not kit code, no index version, no CloudKit change. **#1756, 1**: Corpus Analytics' *View N documents ↗* prints Search's own count of the search it opens (`AnalyticsSearchHandoff`, through `SearchService.matchKeys`), which carries the years only when the reader narrowed them, and the dispersion line beside it decomposes that count. Over S1's full index, *Berlin* over Eisenhower's years read 2,803 on the link and 2,833 in Search, and reads 2,833 on both, its spread 99 of 553 volumes with the top three holding 34%, where it read 502 of 553 for every range; of nine terms and ranges, the link and Search disagreed in eight before and agree in all nine. **#1756, 2**: the Administrations drill lists its volumes by the documents each row prints, point and range together, and its caption says *most documents first*, its count in the singular at one; 168 of the bundled index's 854 adjacent pairs ran the wrong way, and none do. **#1756, 3**: Chart Colors reads *Colors per chart: 8*, and its footer and both charts' menus say the last color is a gray *Other volumes* once the volumes outnumber the colors; the fold is unchanged. Walked on an iPhone 17 simulator holding S1's full index (*Berlin* over 1953–1961: the link and Search both 2,833) and in the Mac check copy (Kennedy's 1961–1963: both 1,445). The captures L3 changes, for R1: `ipad/browse-administrations-truman`, `macos/analytics` and `macos/analytics-table` (this session's log entry says what each shows).
  - **L4 built on 2026-10-22** from `v2` at `d6272c28`, on `claude/l4-indexing-banner-a9f1e4`, and **opened as #1774** on the owner's word of 2026-10-22; not yet merged. A commit for each of #1757's two items, then a docs commit; not kit code, no index version, no CloudKit change. **#1757, 1**: the banner's *Volume N of M* counts every volume of the queue by id, once each — what waits to download or is under way, what has landed and waits for its pass, what waits on disk, and the volume that opened the queue — and a download cancelled or failed for good leaves the count; the Live Activity takes a new count at once, and the Mac's status bar reads the same total. Measured on an iPhone 17 simulator under iOS 27.0 holding S1's full library, by S3's method from Settings ▸ Volumes & Storage ▸ Download from GitHub ▸ Subseries: 1961-63's 27 volumes opened at *Volume 1 of 20* and read *20 of 20* with seven to come, and now read *of 27* in every frame from *Volume 1 of 27*; 1951's 11 opened at *Volume 1 of 12* and now at *1 of 11*. **#1757, 2**: the FRUS Research Guide that opens by itself for a session's first queue hangs on the tab shell rather than on the banner, so the queue's end no longer closes it (measured: it closed by itself as each first queue ended, and now stays until it is closed), and the session's introduction is spent only once the Guide is on screen; of several iPad windows one opens it. The captures L4 changes, for R1: none; `ios/indexing-banner` is an 11-volume queue, whose count was right before and after (this session's log entry says what a 27-volume retake would show).
  - **L5 built on 2026-10-22** from `v2` at `311e94c8`, on `claude/l5-first-launch-6d9a69`, and **opened as #1777** on the owner's word of 2026-10-22; not yet merged. A commit for each of #1759's three items, one for decision 99, then a docs commit; not kit code (nothing under `FRUSCoreKit/`, `WordCloudKit/` or a package target), no index version, no CloudKit change. **#1759, 1**: a fresh install's splash is drawn from the first frame (`CloudSurfaceArbiter.firstFrameSplash`), so the Welcome dock is never seen before it: on an erased iPad Pro 13-inch (M5) simulator under iOS 27.0 the dock was drawn in 14 frames under the fading launch screen with build 1861's code and in none with the fix, and in the Mac check copy in the window's first seven frames and in none. **#1759, 2**: onboarding's backdrop sees the vectors arrive (`WordCloudBackdropView.vectorsArrived`) and fades its cloud in under the splash, on the splash's seeded lens, so the splash fades into it: the empty backdrop measured 1.212, 1.048 and 0.437 s on the iPad (three of four launches) and 1.100 s on the Mac, and none of five launches with the fix shows one. **#1759, 3**: the drift field settles each word where its whole drift clears the edge, the zones and its neighbours (`WordCloudDriftField.settle`), so S2's frame has *objective* clear of *power* and *conflict* clear of *hostility*; over every bundled scope's two first-impression lenses, on the splash and onboarding canvases of three iPhones, four iPad shapes and the Mac, no two words meet and none reaches a zone, with 98–100% of the words kept and 72–100% of the drift. **Decision 99** corrects R2's, R3's and §2's tags. The captures L5 changes, for R1: `ipad/onboarding-volumes`, and the App Preview's pass A (this session's log entry says what each shows).
  - **L6 built on 2026-10-22** from `v2` at `88b3b7d1`, on `claude/l6-page-links-cf0af3`, and **opened as #1778** on the owner's word of 2026-10-22; not yet merged. A commit for the rule with its tests and both readers' calls, one for each platform's Browse page, then a docs commit; not kit code (the rule is the app's, beside `WholeVolumeLink`; two kit test files change inside their Xcode-only branches), no index version, no CloudKit change. **#1766**: both readers ask one rule, `PageLink`. A volume on the device answers from its page index as before, and from the bundled page map where that names nothing (a volume downloaded and not yet indexed). A volume not on the device answers from the map, and the document it names opens as a document link into such a volume opens: the *Volume Not Downloaded* alert, offering the download. A page the map does not list opens the volume's page in Browse, or the Mac's Corpus Browser, where a line under the not-downloaded heading names the page followed (`browser.volume.followedPage %lld`). Measured at corpus `6170e4b32` over the 48,577 live page references into other volumes: with the volume absent, the map names a document for 33,329 (68.6%) and 15,248 open the volume (8,499 "ff.", 6,522 ends of ranges across documents, 227 single pages naming nothing); the tap names the document the index stores for all 29,391 rows rule C resolves, and the one a device holding the volume opens for all 33,329. Walked on an iPhone 17 simulator under iOS 27.0 whose library held the citing volumes and not the cited ones, and in the Mac check copy's 65 volumes: on iPhone and iPad the not-downloaded section leads the volume's page on such a visit, since in its usual place, last, it sat below the fold. §5 takes two findings from the walk and the measurement. The captures L6 changes, for R1: none (no committed frame shows a page link's outcome).
  - **L7 built on 2026-10-22** from `v2` at `8cb9d92e`, on `claude/l7-launch-kit-591be1`; not yet opened, as the owner opens each pull request. A commit for items 1 to 3, one for item 4, one for item 5, then a docs commit; tools and copy only: no app or test code, no index version, no CloudKit change. **#1763, 1 and 2**: recording T's last three beats are the routes S1 recorded, checked in the code on `v2`: **Export…** ▸ the PDF card ▸ **Export PDF**, whose first page is the title page (the title, the collection note, the contents; the collection has no introduction); Research ▸ **FRUS Research Guide** ▸ **Next** to *Production & Timeliness*, the start year set in the year chip's popover (two year fields with steppers; nothing to drag); **% of documents**, then **Administration** ▸ *Dwight D. Eisenhower (1953–1961)* and **View N documents ↗** (a time chart has no bar to tap). A note under the table says why. **#1763, 3**: frame 10's sublines read *…then narrow the years to the spike and open its documents in Search. The chart exports as a figure or a CSV with its method stated.* on the iPad and the Mac (*Every chart* was the claim the kit's §5 had dropped), and both manuals' §18.6, the kit's source, no longer say *tap into* or *click into*. **#1763, 4**: the composer draws the review stamp over the frame's top margin, out of the layout's flow, so a stamped draft lays out as its store frame does (all 34 frames measure the same both ways) and the foot keeps its 78% on every preset: on the iPhone the disclaimer takes 2 lines on frame 01 (5 before) and the NARA sentence 2 on frame 04 (9 before). `STAMP=0` leaves the stamp out for App Store Connect and refuses a shot with no capture. The 38 committed drafts are rendered again, none changing size. **#1763, 5**: the check copy's README says how to put the copy's preferences back (key by key through CFPreferences, read back through `defaults export`) and how to record it while computer use drives it (ScreenCaptureKit, leaving the Claude app out), with S4's two helpers committed beside `axread.swift`; the kit's §4 no longer names QuickTime. What L7 changes for R1: no capture; every composed frame (the stamp's place, the foot's width, frame 10's sublines), and recording T's last three beats (this session's log entry says what each shows).
- **Each lane's issue body is its brief.** Each issue names its files, its measurements and what a fix could do.
  - #1757 changes what the banner counts during the first downloads, so its lane measures a 27-volume queue before and after, as S3 did.
  - #1759 is measured frame by frame, as S2 and S4 measured it: their scripts are kept with the sittings' notes.
  - #1766's fix could resolve the page through A18b's bundled page map (`cited-page-map.json`) where the map covers it, and open that document as a document link into an absent volume opens. Elsewhere it falls back to the volume's Browse page, with a word that the volume is not downloaded, on both platforms alike.
- **R1, the retakes.** After L1 to L7 merge, retake every screen the fixes changed, by the ledger's conventions (`Docs/screenshots/README.md`, S1 to S4's entries; an iPad frame matches the set only with the status bar's time and date erased as S1's were). That means:
  - the onboarding frames (#1759);
  - the analytics captures (#1756);
  - the search captures (#1758, #1760);
  - `research-rail` (#1761's tint);
  - any frame showing a coverage line or a fixed label.

  Then run the kit's `tools/marketing/compose.py` again at the store sizes with no stamp (`SCALE=1 STAMP=0`, which L7 added for #1763's item 4): the frames for App Store Connect carry no DRAFT stamp. As in S5's embed pass, each new frame is read against its sentence.
- **R2, the TestFlight pass.**
  - Run the release checklist again, as A19 ran it (`Completed/Plan-Of-Record-2026-10-14.md` §2, *Run 2026-10-21*):
    - the clean `build-for-testing`, read for warnings: the two known residues and nothing else;
    - the full unit target on iPhone 17 under iOS 27.0, and `swift test`;
    - the Mac build, and a walk of the Mac check copy;
    - the window-fronting audit;
    - the link check in report mode.

    A re-index census is owed only if a lane changes the index version, and none is planned.
  - Bump to 1.0 (1776) by `CLAUDE.md`'s procedure (`project.yml`, `project.pbxproj`, the README line and its mirror), and rewrite both TestFlight notes for 1776.
  - Before the archive: `./Scripts/fetch-llama-dsyms.sh` and `./Scripts/check_cloudkit_schema.py`.
  - The owner archives, uploads to TestFlight, tags the 1776 commit `build-51` after the upload (decision 99), and makes the device pass on an iPhone, an iPad and the Mac. A defect found goes to a lane, and the next TestFlight upload takes a number between 1776 and 1861 (decision 87).
- **R3, the submission.** Restore 1.0 (1861) by the same procedure. The owner archives, uploads, tags `version-1.0` on that commit (decision 99), and submits to App Review with §2's answers.

---

## 2. Submission — what only the owner does

The repository holds drafts for each.
- **The website.** Make frusexplorer.app public and paste the Privacy Policy and Support pages (decisions 36 and 58; `Docs/Privacy-Policy.md`, `Docs/Support.md`, `Docs/Website/`). App Store Connect requires both URLs. Every path answered 401 on 2026-10-21, as on 2026-10-19.
- **App Store Connect:**
  - the privacy label: Data Not Collected (decision 35);
  - the listing, from `Store-Listing-Draft.md` (decisions 28 to 31);
  - the screenshots, from R1's composed frames, with the 13-inch iPad slot checked for 2752 × 2064 landscape (decision 33);
  - no App Previews (decision 89);
  - the App Review notes: the query encoder is an optional 310 MB download of an Apache-licensed model from a public GitHub release, with no agreement step (decision 18), and the app is not an official product of the Office of the Historian;
  - the age rating, export compliance, and a Mac build signed for the App Store.
- **`check_repository_links.py --stamp`**, which writes the owner's confirmation date.
- **The archive, the uploads and the tags** (R2 and R3): `build-51` on 1.0 (1776) and `version-1.0` on 1.0 (1861) (decision 99).

---

## 3. After submission

- **C-3, the agentic analysis measurements** (decision 91): before build 52 starts, on the owner's Mac. Its design is `C-3-Reader-Test-Design.md`, with its budget rule; the harness facts are in `Agentic-Harness-Runbook.md`.
- **Build 52's candidates.** Their order is the next plan's (decision 90).
  - **#1723, A7: App Intents and Siri.** A7a covers the entities, the four intents and the copy. A7b covers the Spotlight association with `expirationDate` and a `CSSearchableIndexDelegate`, which closes two Spotlight findings: donated items expire after 31 days, and nothing answers Spotlight's requests to reindex. The plan is `App-Intents-Siri-Assessment-2026-10-18.md` §5, and the owner's device check (Spike Reader) decides A7b's place.
  - **Cross-references:**
    - #1764, the network at three hops;
    - the graph's untitled outbound page node;
    - six cross-volume references by id to a section's row, missing from the bundled edge index (A18b).
  - **#1765, summaries:** the Long Telegram refused, and the Mac's stale collection preview.
  - **Numbers and states that read wrong:**
    - after A18's respelling, the two Archival Neighbors readers disagree on a class key no note carries (A19's census);
    - a volume whose indexing is cut short is marked nowhere until the next launch (A14);
    - the Archives Visit labels lot targets by their first document (A15).
  - **Search's cost**, measured on 2026-10-15 in `Issue-1648-Stopping-A-Replaced-Search-2026-10-15.md` §6:
    - an exact-word search for a common word holds the pipeline for about two minutes;
    - on the Mac, most of a search's time is the snippet pass;
    - the default scope's user-content union costs a common word's count about 0.3 s.
  - **An owner device sitting:**
    - the Topics lens on an iOS 27 device;
    - one Audio Graph heard aloud;
    - the Mac's Sync Log after a sync;
    - the Mac Search window with a selection under VoiceOver, in dark appearance, with Full Keyboard Access;
    - Text Color's picker on an iPad under iOS 27;
    - the by-eye checks carried from builds 48 and 49 (`Completed/Plan-Of-Record-2026-10-14.md` §4 lists them).

---

## 4. Waiting on the owner

- §2's submission steps, and R2's TestFlight device pass.
- **For #1620** (decision 72): install iOS 27.1's simulator runtime. A session then re-runs the affected suites, starting from the Stage Manager switch (#1620's comment of 2026-10-21).
- **For A7** (#1723): the device check with Spike Reader. It is `App-Intents-Siri-Assessment-2026-10-18.md` §4, and `jolly-newton-d5828b`'s untracked `A6Spike/` holds the app.
- **The manual review**, past build 52 (decision 94). `Manual-Revisions-Pending.md` and `Manual-Update-Build-49-Owner-Review.md` are its inputs and close with it.
- **App Previews** for a later update (decision 89): recordings A, R and T are kept outside the repository.

---

## 5. Backlog, parked, deferred and closed

### P2 — later

- **#1767, the person authority's deferred work** (decision 96): the identifier rule (b4), the role text of overlay entries that carry several people, the nine held-apart members who rejoin by name, and #1658's undecided tie.
- **Generators:** provenance flows count no page reference (`RefDestination.citedDocument` is nil for a page).
- **Section vectors**, at the next vectors generation (decision 61).
- **Smaller app items:**
  - `ProjectLeadsService` ranks with no year;
  - `datesByDocumentKey(_:)` scans every `document_dates` row (17 ms against 0.03 ms by the key);
  - the archival chip is cut on the iPhone 17;
  - Sync Diagnostics' Clear Log draws its trash icon in the accent colour;
  - a phrase can match across a document's heading and its form marker, since `body_text` begins with both: 13 of *"long telegram"*'s 136 rows match only as *…to Minister Long* followed by *[Telegram]* (found in L2);
  - since #1760 a question's keyword snippets cost about three times A10b's in a release build, where the scan runs on to the rarest word; a faster scan (an ASCII fast path in the gates, or a UTF-8 scan) would win it back (found in L2). **The ASCII fast path is built** on 2026-10-22, on `claude/reverent-wiles-972304` from `v2` at `38dc3d7c`, and **merged as #1771** (`8843b88e`). On the merged tree the full unit run (7,571 tests), the Mac build and `swift test` (3,030 tests) pass. Over L2's 33 searches the snippet pass costs 4.05 s at 1,000 rows (A10b 4.64 s, `v2` 7.97 s) and 16.43 s at the Mac's ceiling (A10b 28.98 s, `v2` 36.80 s); 90% of what #1760 added to the questions is won back, and every snippet is byte-identical. The UTF-8 scan was not built (that session's log entry says why);
  - a number typed with a mark (`1945.`) searches nothing, and nothing says so; a hyphenated word (*long-range*) never anchors a snippet on its parts; an `=` word never anchors one (found in L2).
  - on the Mac, a volume hand-off that changes the Corpus Browser's subseries while a volume's page is pushed shows the new subseries' list and no page: a link to a whole volume (#1603), a page link #1766 sends to its volume, a provenance row or a subject pivot. Measured in `v2` at `88b3b7d1` as well as on L6's branch; with only a list showing, the hand-off opens the page (found in L6). **Fixed** on 2026-10-22, on `claude/relaxed-hypatia-b0a197` from `v2` at `88b3b7d1`, merged with `v2` at `700cb5a3`, and **opened as #1779**. Changing the sidebar's selection makes SwiftUI pop the detail stack itself, after the browser's own push, and the stack reads no path until AppKit shows the new list, so the push now waits until the new selection's list is in the window. In a copy of the split view the push then opened the page in all 74 hand-offs, where `v2`'s code lost it in all 14. In the check copy it opened the page from a pushed page and from a list, by a link to a whole volume and by a page link. On the merge the full unit run (7,606 tests) and the Mac build pass (that session's log entry has the rest).
  - a page link into a volume on the device whose page names no document still does nothing, as before #1766: 608 of the 48,577 page references into other volumes on a full library, and same-volume ones besides (found in L6).
- **The 2026-09-27 audit, unfiled:**
  - Facets is disabled in Meaning mode on iPhone and iPad, where the Mac offers it;
  - the reach scan and the leads count second-edition reprints;
  - Archives Visit derivations go stale when a volume updates.
- **Test infrastructure:**
  - `RichTextRestingCapTests` on an iPad host;
  - two UI suites need the Research rail open, which a simulator can hold closed (A12);
  - the iOS 26.5 runtime has no English lemmatiser, so every #1608 surface reads *Limited* in a 26.5 capture or test.
- **#1608:** how often an iOS 27 device launches without the lemmatiser.
- **Hygiene:**
  - `FilterChip` and `CrossProjectNoteIndicator`, the two views nothing constructs;
  - 14 Swift files outside every target with no license header;
  - nine Swift files citing #1210, #1211 or #1257 where the work merged as #1250, #1251 and #1256;
  - the HYG and READ leftovers, and the lanes' own leftovers (`Completed/Plan-Of-Record-2026-10-14.md` §6f, which points on to the 2026-09-28 plan's §0a, §4 and §4a);
  - `Docs/Agentic-Analysis-Guide.md` §14.11 still gives 3,985 archival collections, and the map's figures from before B4's layout (172 clusters, 92,268 unclustered, where the shipped map has 140 and 88,059) (found in L1).
- **Marketing**, from the Visual Marketing Plan: step 5 (the publication-lag plate), step 13 (Plate B) and step 16 (after launch).
- **Accessibility, worth a sweep of its own:**
  - `AXChartDescriptor` for four chart families;
  - Differentiate Without Color on the map;
  - about 37 text sites with a fixed size;
  - a reader that follows the system text size;
  - the iPad rail toggle's `.isSelected` trait, which XCUI does not read with the rail open or closed (found in L1);
  - at the largest text size on an iPhone, Collection settings' row breaks its title inside a word and cuts its caption, and the Local Only banner's button reads *De-tails* (found in L1).

### Parked — designed or proposed, not scheduled

- Dateline places, blocked on the owner's toponym curation.
- Links from the map to Search and Related.
- A heat-matrix cell drill-down.
- A Search command menu and shortcuts.
- Standalone token editors.
- A subseries pole picker.
- A region-share chart.
- An iPhone rail peek strip.
- An immersive Read mode.
- C-1 of the agentic loop, gated on C-2's measurement.
- The OS 27 design's C3, project-lead centroid retrieval.

### Deferred, or waiting on someone else

- **#234**, early-era people: deferred indefinitely (decision 92).
- **#1696**: waits for the Office's subject export to reach Document 946. Nothing is posted to HistoryAtState/frus#469 (decision 71).
- **For the corpus to fix:** `frus1945Malta/d273`'s year, 1945 by `@when` where its dateline says 1944.
- **For HistoryAtState/people to fix:** the registry's own merges (Stevenson, Wilson, Fish).
- **New volumes**, whenever the Office publishes, by `New-Volume-Release-Plan.md`.

### Closed or declined

- **Closed:** #1690 and #1691 (decision 95).
- **Answered "keep as decided":** A10b's two residuals.
- **Left as it is:** the method appendix's plain-text line, the record of what was typed. It stays the owner's call (decision 86).
- **Declined:**
  - W12's parallel editions, W14, the MCP server and `CSUserQuery`;
  - the cross-platform review's unfiled leftovers (decision 93).

---

## 6. The documents, as this change leaves them

The review's §1 has each disposition with its reason. This change applies them.
- **Moved to `Completed/`**, since no code, test or tool cites them. The live documents that cite them now point there.
  - `C0-Falsifier-2026-08-31.md` and `C2-Long-Session-2026-08-31.md`. Their data folders stay, because `CodingStandardsAuditTests` reads them.
  - `Issue-1577-Search-Within-Results-Assessment.md`.
  - `Map-Figure-Export-And-Visual-Outputs.md`.
  - `OS27-Semantic-Retrieval-Design.md`.
  - `W15-Geographic-Analytics-Assessment-2026-09-01.md`.
  - `Plan-Of-Record-2026-10-14.md`, marked SUPERSEDED.
- **`external-citation-sample.json` stays.** The review proposed moving it, but `Completed/README.md` names it the current baseline of the external-citation sample, whose superseded predecessor is archived there.
- **Marked complete in place**, because code, tests, tools or the Agentic Analysis Guide cite them:
  - `Cross-Volume-Page-Citations-Assessment-2026-10-20.md`;
  - `Issue-1648-Stopping-A-Replaced-Search-2026-10-15.md`;
  - `Keyword-Snippet-Assessment-2026-10-20.md`, once #1760 was fixed (L2);
  - `Vector-Embeddings-Semantic-Design.md`;
  - `Lexical-Axis-Addressable-Market-2026-08-27.md`;
  - `Agentic-Guide-Revisions-2026-09-04.md`, and the C-0b, C-0c and C-0d memos;
  - `OH-Report-2026-10-01.md`;
  - `semantic-spike/`'s three memos;
  - `Cross-Platform-UI-Adversarial-Review/STATUS.md` (decision 93).
- **Kept live:**
  - the runbooks;
  - the original specification;
  - the session log (split, decision 97);
  - `New-Volume-Release-Plan.md`;
  - the Visual Marketing Plan, the launch kit, the listing draft and `marketing-drafts/`, until submission;
  - the two manual-review documents, until the review;
  - the A7, C-3 and person-authority designs, until their work runs;
  - #234's documents (decision 92);
  - the generator output folders;
  - this plan's review, `Planning-Review-2026-10-21.md`.
