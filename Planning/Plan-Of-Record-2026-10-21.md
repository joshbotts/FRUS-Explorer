# Plan of record — from 2026-10-21

**Base:** `v2` @ `e47ca307` (2026-11-01). The tree reads version 1.0, build 1776, the TestFlight build tagged `build-51` at `f0479037`; 40 pull requests have merged since the tag. Index **v71**, person rollup **v15**, and EmbeddingGemma 2 vectors under digest `89481b18`. Four issues are open (#1835, #1723, #1696, #234), and no pull request. *(The line read `f962077e`, 1861 and v12 until 2026-11-01, and named five open issues, #1823 and #1620 among them, until both closed that day; #1835 was filed the same day, from #1620's re-test.)*

**Status: LIVE — the plan of record from 2026-10-21.** It supersedes `Completed/Plan-Of-Record-2026-10-14.md`, whose work is done: Track A (A1 to A19, all but A7, which its decision 57 deferred), Track B and the build-51 screenshot sweep S0 to S5 (#1670 to #1755).

It is written from two sources:
- `Planning/Planning-Review-2026-10-21.md`: the documents' dispositions, the backlog in tiers, and fifteen questions;
- the owner's answers to those questions, numbered here 84 to 98.

Its aim is **App Store submission of FRUS Explorer 1.0**: first the nine issues that gate it, then the retakes, a TestFlight pass, and the submission. Since 2026-11-01 a second TestFlight build, 1.0 (1787), comes before the submission, then a retake sitting of what changed since `build-51`, and then the Agentic Analysis Guide's revision (decisions 110 to 112).

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
- 72: #1620 is re-tested on iOS 27.1. Settled on 2026-11-01 without it (decision 114).
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
91. **C-3 runs after submission and before build 52 starts.** *Overtaken 2026-10-25: the owner started it before the submission ("start C-3 now with build 1776"), on the Mac, with the TestFlight build's index; it ran to completion the same night, with three replicates under a stop line the owner raised from 69% to 75% while it ran. Results: `C-3-Results-2026-10-26.md`; the guide's §3a (v1.34) carries the table.*
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

**The owner's instruction of 2026-10-26**, four days after the TestFlight upload:

100. **The four issues filed on 2026-10-26 are one lane, L8, taken next**: #1796 to #1799. The owner's words: "read issues 1796, 1797, 1798, and 1798 and include a lane in the plan of record to address them next." They name 1798 twice; the fourth is taken to be #1799, the fourth issue filed that day.
    - L8 comes before R3. None of the four carries the *before App Store submission* label that decision 84's nine carry; "next" is what puts them ahead of the submission.
    - When L8 has merged, the owner decides whether its fixes go to TestFlight before R3. If they do, that upload is numbered between 1776 and 1861 (decision 87), and the bump follows `CLAUDE.md`'s procedure, as R2's did.

**The owner's instruction of 2026-10-27**, with the pull request that commits the website drafts:

101. **The website's pages are generated, reviewed and revised after the submission of 1.0 (1861).** The owner's words: "Open a PR with drafts in planning. As part of PR, include generation, review, and revision of the website pages as part of the post-build 1861 submission work."
    - The drafts are in `Planning/website-drafts/`: the home page and the tour, each in a coming-soon version for the weeks of App Review and a launch version, and plain-language drafts of the Support and Privacy pages. Its `README.md` says what each owes.
    - §2's website step is unchanged: at submission the Privacy Policy and Support pages go up as `Docs/` holds them, since App Store Connect requires both addresses. This work follows it (§3).

**The owner's instructions of 2026-10-29**, in the session that built #1767's lane A:

102. **#1767's lane A is started now**: "start the person authority lane". It is built from `Completed/Person-Authority-Lane-Design-2026-10-28.md` §7, items 3 and 4 with §4.6. Its rollup version (v13) rebuilds every library's people at launch, so when it merges, before or after R3, is the owner's call at the merge.
103. **#1658's tie: a member that fits two reconciled people joins the one its exact name fits, when only one does, and neither otherwise** (`exactFirst`). The owner chose it over the memo's T1 and T2 after the census of one full library. T1 moved three entries away from the one person their exact name fits; T2 moved seven of Jimmy Carter's own entries.
104. **Speaker Jim Wright's four entries are fixed in lane A**: "Address the Jim Wright finding in this PR." The census found them in Sir Oliver Wright's rollup, joined by name ("James" fits "J.", and the role check counts "from"); four assignments give them to his own record, 114818. The role check itself is unchanged: leaving its function words out would also break three right career rollups.

**The owner's answers of 2026-10-29**, in the session that built #1767's lane B:

105. **The identifier assessment's 300 reads are rebuilt from the 2026-10-17 session's transcript and committed beside the Wikidata snapshot**: "Rebuild it". The original file had gone from the Mac with that session's notes folder; the transcript holds each sample's verdict string and the reading sheet that orders it. The rule's tests re-score the shipped file against them.
106. **Lane B bumps the person rollup to v14**: "Bump to v14", over v13 carrying both lanes. Lane A's v13 had not shipped, so a library still at v12 rebuilds once either way; v14 also reaches a library a development build already rebuilt at v13.

**The owner's answers of 2026-11-01**, in the session that took up what #1767's two lanes found and left:

107. **Truman's nephew does not carry the President's item**: "Withhold from nephew". One overlay entry carries both men with Q11613, and a correction withholds from every id of an entry, so the corrections file gains `withheld`: an identifier kept off one record of an entry carrying several people. Its one entry keeps Q11613 off 116214; the President keeps it.
108. **A country stays a role word, and the two wrong ids it let in are corrected by data**: "Correct the two by data". Left out of the role words with the nationalities, as the session's brief proposed, countries took 19 ids off the bundle, measured against the control and read one by one: Gustav Dahrendorf's son's item and Major General Inam-ul-Haq's namesake's, and 17 right ones whose only word in common with their item is the country (Kiichi Aichi, Liu Chieh, Pham Dang Lam among them). Two identifier-only corrections withhold the two.

**The owner's word of 2026-11-01**, in the session that assessed #1764, #1765 and #1767:

109. **#1767 is closed**: "Yes, close it out". Its five items, and what its two lanes found and left, are merged: #1815, #1816 and #1826, rollup v15. The device check of a library rebuilt at v15 and the filing of the three reports for `HistoryAtState/people` are the owner's (§4), and neither holds the issue open. The design memos leave the live set. The identifier assessment is marked complete in place, since the generator, its tests and the snapshot tool cite it by path; the overlay review and the lane design move to `Completed/`; the report drafts stay until they are filed.

**The owner's instruction of 2026-11-01**, given to a cloud session with #1823 and further summarization work under way in local sessions on the MacBook Air:

110. **A second pre-release TestFlight build, 1.0 (1787), goes up on 2026-11-02, and folds in the work already under way.** The owner's words: "Include another pre-release test flight build (1.0/1787) tomorrow that folds in work that is already underway today (issue 1823 and additional summarization work are in progress in local sessions on the MacBook Air)."
    - This is the upload decision 87 allowed for, numbered between 1776 and 1861; 1787 lies between them, and App Store Connect accepts it after 1776 on both platforms.
    - It is R2b (§1). What has merged into `v2` when R2b's checklist runs goes into 1787, the 40 pull requests since `build-51` among them; a lane still open on the Mac then waits for the next upload, which takes a number between 1787 and 1861.
    - The tags are decision 113's: `build-52` on 1787, `1.0-release` on 1861.
111. **After 1787 is on TestFlight, a retake sitting recaptures every screen a pull request since `build-51` changed.** The owner's words: "After 1787 is added to test flight, the plan should include recapturing screenshots that have been changed by PRs since 1.0/1776 were tagged as build 51." It is R4 (§1), by decision 88's rule and R1's conventions, from 1787's own code, in the manuals and the store frames.
112. **After the retakes, the plan picks up the Agentic Analysis Guide's revision.** The owner's words: "After that, the plan should pick up agentic analysis revision work." It is G1 (§1): the reviews' recommendations not yet taken, the owner's open choices from the four C-3 tiers, and whether a measurement follows, with its scope set by the owner at its start.
    - R3 keeps its place: the submission follows 1787's device pass, when the owner calls it. G1 is documents and measurements on the Mac and changes no app code, so it runs on whichever side of R3 the owner's calendar puts it.
113. **`build-52` tags 1.0 (1787), and `1.0-release` tags the submission, 1.0 (1861).** The owner's words of 2026-11-01: "build 1787 will take the \"build 52\" tag and 1861 should be tagged \"1.0 release\"".
    - This refines decision 99, which named `version-1.0` for 1861; no tag of that name has been pushed. "1.0 release" is spelled `1.0-release`, since a git tag name cannot contain a space, as "build 51" is `build-51`.
    - The owner tags the commit uploaded as 1.0 (1787) `build-52` after the upload (R2b), and the commit submitted as 1.0 (1861) `1.0-release` (R3). Should the device pass need another upload before 1861, its tag is the owner's call then.
    - So build 52 is 1787, and **"build 52" written in this plan before 2026-11-01 means the release after 1.0**: decisions 90, 91 and 94, §0's index-bump rule, §3's candidates list and §4's manual-review line, and the issues that say "past build 51" or "build 52". They are left as written, with §3's heading renamed; the next plan numbers that release.

**The owner's word of 2026-11-01**, in the session that re-tested #1620:

114. **#1620 is closed**: "Post and close". No iOS 27.1 runtime was installed (decision 72's re-test); the host moved instead, to Xcode 27.2 and macOS 27.2, with the same iOS 27.0 runtime (24A434). On it, none of the issue's three triggers reproduced: a plain launch on the iPad Pro 11-inch that had ended `backboardd` 3 of 3, the analytics and keyboard suites on the iPad mini, and the Stage Manager switch on a newly created iPad Pro 13-inch. The aborting frame is `MTLSimDevice`, the simulator's bridge to the host's Metal; whether the update or the Mac's restart cleared it was not separated. `CLAUDE.md`'s index and `UI-Test-Destinations-Runbook.md` read the analytics and toolbar suites on an iPad under iOS 27.0 again. The same run found something else: under 27.0 `KeyboardDismissBarReachTests`' Browse-root test fails, 2 runs of 2, because the tab shell's banner stays up with the keyboard; under 26.5 it passes. So that suite's row stays on 26.5. The failure is #1835.

**Rules carried from the earlier plans and `CLAUDE.md`.** Each is the owner's.
- **The queue is serial.** The next pull request is pushed when the owner has merged the one before. Auto-merge is never enabled.
- **One fresh session per pull request**, started from this plan and the issue numbers, and ended at the merge.
- **Small defects are fixed inline**, several related issues to one pull request, with one review pass on the diff. `lane-dev.js` returns only for a lane with real design risk, one lane per run.
- **Tests are scoped with `-only-testing` while developing.** Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- **Every heavy job goes through `Scripts/heavy.sh`**, one at a time on this Mac.
- **One index bump a build.** None is planned for 1.0's remaining work, so a change to what indexing stores waits for the release after 1.0 ("build 52" until decision 113).
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
| L8 | Four issues filed after the upload: the Mac's launch offline, the ranking chart's taps, the corpus word cloud on an iPad, and the timeline's earlier citations (decision 100) | #1796, #1797, #1798, #1799 |
| L9 | Under way on the Mac on 2026-11-01: the Collections Manager's CRUD on both platforms, and the summarization follow-ups (decision 110) | #1823, and what #1820 to #1827 left |
| R2b | The second TestFlight pass, 1.0 (1787), on 2026-11-02 (decision 110) | — |
| R4 | The retake sitting after 1787: every capture a pull request since `build-51` changed (decision 111) | — |
| G1 | The Agentic Analysis Guide's revision (decision 112) | — |
| R3 | The submission, 1.0 (1861) (decision 87) | — |

- **L1 goes first**: it is cheap, and its fixes show on captured screens. L2 to L6 follow in any order the owner prefers. L7 is tools and copy; it can come any time before R1, since the composer's stamp shapes the store frames.
  - **L1 built on 2026-10-21** from `v2` at `1fdf4308`, on `claude/l1-copy-fixes-27e098`, and **opened as #1769** on the owner's word of 2026-10-22; **merged as `b385340c`**. A commit for each item or group of #1761, one for #1762, then a docs commit; not kit code, no index version, no CloudKit change. **#1761**: one unresolvable reference reads in the singular; an Administrations row says *1 vol*; a working corpus's coverage line groups its counts; frus1961-63v23's label loses its leading colon; the iPad rail toggle is tinted while the rail is open (a toolbar reads the button's `.tint`, never a `.foregroundStyle` inside its label; measured by pixel on iPad simulators under iOS 27.0 and 26.5), and iOS §4.2 says so again; the Mac date chip's ✕ measures 23×20 points with its own help, and a click off the glyph clears it (the check copy); the three quote-doubling siblings quote by `PinnedResultBase.quotable(_:)`, the appendix's plain-text line left as decision 86 says; and at the largest text size the Collections row and the two document rows wrap where they were cut. **#1762**: 88,059 (Mac §6.1), 37,899 and the shipped label (iOS §6.1h) and 3,977 (iOS §14.6, Mac §14.5), each read from its bundled file, and `ChronologyQueryTests`' two comments. #1762's lasting fix, manuals that stop hard-coding figures that move or a check that reads them from the bundled files, is put to the owner; nothing is built for it. The captures L1 changes, for R1: `ipad/research-rail`, `ipad/stage-manager`, `ipad/browse-administrations`, `ipad/browse-clusters-detail`, `macos/crossref-analytics-ranking` and `macos/crossref-analytics` (this session's log entry says what each shows).
  - **L2 built on 2026-10-22** from `v2` at `b385340c`, on `claude/l2-search-fixes-df74f5`, and **opened as #1770** on the owner's word of 2026-10-22; **merged as `38dc3d7c`**. A commit for each item, then a docs commit; kit code (FRUSCoreKit, FTS5Store), no index version, no CloudKit change. **#1758**: on iPhone and iPad, emptying the Search field closes Facets and takes away the narrowings it made, a *Narrowed by* chip with nothing left to search runs nothing, and the binoculars menu's Facets is a toggle that closes the panel it opened (walked on an iPad Pro 13-inch (M5) simulator under iOS 27.0 holding S1's full index); the Mac's results list opens at its top for a new search and for another page (walked in the Mac check copy at `3dfe2741`); a working corpus records what narrowed its search, in the `sourceDescription` it already stores, and its save sheet shows **Narrowed by**. **#1760**: a keyword row's snippet starts at the rarest of the query's words that its prose holds, rarest across the index, with function words set aside while the query has another, so a question typed in Keywords mode marks *Marshall*, not *the* (over a full index, the first 100 rows of twelve questions marked a function word in 46 to 100% of rows and now in none; no single word's snippet moves); the snippet pass costs more where its scan runs on to that word, which this session's log entry measures in a release build; and the MATCH strip quotes each term as the tokenizer reads it, `"happen"` for `"happen?"` (parser 6.8, which also refuses `=cold. -=Cold OR -=Cold` as matching nothing). The captures L2 changes, for R1: every frame of *Berlin blockade*'s keyword rows, which now mark *blockade*: `ios/search-results`, `ios/search-facets`, `ios/search-tips`, `ipad/search-results`, `macos/search` and `macos/search-tips`, and the kit's frame 01 (this session's log entry says what each shows).
  - **L3 built on 2026-10-22** from `v2` at `3aa63d6a`, on `claude/l3-analytics-counts-3b801c`, and **opened as #1773** on the owner's word of 2026-10-22; **merged as `d6272c28`**. A commit for each of #1756's three items, then a docs commit; not kit code, no index version, no CloudKit change. **#1756, 1**: Corpus Analytics' *View N documents ↗* prints Search's own count of the search it opens (`AnalyticsSearchHandoff`, through `SearchService.matchKeys`), which carries the years only when the reader narrowed them, and the dispersion line beside it decomposes that count. Over S1's full index, *Berlin* over Eisenhower's years read 2,803 on the link and 2,833 in Search, and reads 2,833 on both, its spread 99 of 553 volumes with the top three holding 34%, where it read 502 of 553 for every range; of nine terms and ranges, the link and Search disagreed in eight before and agree in all nine. **#1756, 2**: the Administrations drill lists its volumes by the documents each row prints, point and range together, and its caption says *most documents first*, its count in the singular at one; 168 of the bundled index's 854 adjacent pairs ran the wrong way, and none do. **#1756, 3**: Chart Colors reads *Colors per chart: 8*, and its footer and both charts' menus say the last color is a gray *Other volumes* once the volumes outnumber the colors; the fold is unchanged. Walked on an iPhone 17 simulator holding S1's full index (*Berlin* over 1953–1961: the link and Search both 2,833) and in the Mac check copy (Kennedy's 1961–1963: both 1,445). The captures L3 changes, for R1: `ipad/browse-administrations-truman`, `macos/analytics` and `macos/analytics-table` (this session's log entry says what each shows).
  - **L4 built on 2026-10-22** from `v2` at `d6272c28`, on `claude/l4-indexing-banner-a9f1e4`, and **opened as #1774** on the owner's word of 2026-10-22; **merged as `311e94c8`**. A commit for each of #1757's two items, then a docs commit; not kit code, no index version, no CloudKit change. **#1757, 1**: the banner's *Volume N of M* counts every volume of the queue by id, once each — what waits to download or is under way, what has landed and waits for its pass, what waits on disk, and the volume that opened the queue — and a download cancelled or failed for good leaves the count; the Live Activity takes a new count at once, and the Mac's status bar reads the same total. Measured on an iPhone 17 simulator under iOS 27.0 holding S1's full library, by S3's method from Settings ▸ Volumes & Storage ▸ Download from GitHub ▸ Subseries: 1961-63's 27 volumes opened at *Volume 1 of 20* and read *20 of 20* with seven to come, and now read *of 27* in every frame from *Volume 1 of 27*; 1951's 11 opened at *Volume 1 of 12* and now at *1 of 11*. **#1757, 2**: the FRUS Research Guide that opens by itself for a session's first queue hangs on the tab shell rather than on the banner, so the queue's end no longer closes it (measured: it closed by itself as each first queue ended, and now stays until it is closed), and the session's introduction is spent only once the Guide is on screen; of several iPad windows one opens it. The captures L4 changes, for R1: none; `ios/indexing-banner` is an 11-volume queue, whose count was right before and after (this session's log entry says what a 27-volume retake would show).
  - **L5 built on 2026-10-22** from `v2` at `311e94c8`, on `claude/l5-first-launch-6d9a69`, and **opened as #1777** on the owner's word of 2026-10-22; **merged as `88b3b7d1`**. A commit for each of #1759's three items, one for decision 99, then a docs commit; not kit code (nothing under `FRUSCoreKit/`, `WordCloudKit/` or a package target), no index version, no CloudKit change. **#1759, 1**: a fresh install's splash is drawn from the first frame (`CloudSurfaceArbiter.firstFrameSplash`), so the Welcome dock is never seen before it: on an erased iPad Pro 13-inch (M5) simulator under iOS 27.0 the dock was drawn in 14 frames under the fading launch screen with build 1861's code and in none with the fix, and in the Mac check copy in the window's first seven frames and in none. **#1759, 2**: onboarding's backdrop sees the vectors arrive (`WordCloudBackdropView.vectorsArrived`) and fades its cloud in under the splash, on the splash's seeded lens, so the splash fades into it: the empty backdrop measured 1.212, 1.048 and 0.437 s on the iPad (three of four launches) and 1.100 s on the Mac, and none of five launches with the fix shows one. **#1759, 3**: the drift field settles each word where its whole drift clears the edge, the zones and its neighbours (`WordCloudDriftField.settle`), so S2's frame has *objective* clear of *power* and *conflict* clear of *hostility*; over every bundled scope's two first-impression lenses, on the splash and onboarding canvases of three iPhones, four iPad shapes and the Mac, no two words meet and none reaches a zone, with 98–100% of the words kept and 72–100% of the drift. **Decision 99** corrects R2's, R3's and §2's tags. The captures L5 changes, for R1: `ipad/onboarding-volumes`, and the App Preview's pass A (this session's log entry says what each shows).
  - **L6 built on 2026-10-22** from `v2` at `88b3b7d1`, on `claude/l6-page-links-cf0af3`, and **opened as #1778** on the owner's word of 2026-10-22; **merged as `700cb5a3`**. A commit for the rule with its tests and both readers' calls, one for each platform's Browse page, then a docs commit; not kit code (the rule is the app's, beside `WholeVolumeLink`; two kit test files change inside their Xcode-only branches), no index version, no CloudKit change. **#1766**: both readers ask one rule, `PageLink`. A volume on the device answers from its page index as before, and from the bundled page map where that names nothing (a volume downloaded and not yet indexed). A volume not on the device answers from the map, and the document it names opens as a document link into such a volume opens: the *Volume Not Downloaded* alert, offering the download. A page the map does not list opens the volume's page in Browse, or the Mac's Corpus Browser, where a line under the not-downloaded heading names the page followed (`browser.volume.followedPage %lld`). Measured at corpus `6170e4b32` over the 48,577 live page references into other volumes: with the volume absent, the map names a document for 33,329 (68.6%) and 15,248 open the volume (8,499 "ff.", 6,522 ends of ranges across documents, 227 single pages naming nothing); the tap names the document the index stores for all 29,391 rows rule C resolves, and the one a device holding the volume opens for all 33,329. Walked on an iPhone 17 simulator under iOS 27.0 whose library held the citing volumes and not the cited ones, and in the Mac check copy's 65 volumes: on iPhone and iPad the not-downloaded section leads the volume's page on such a visit, since in its usual place, last, it sat below the fold. §5 takes two findings from the walk and the measurement. The captures L6 changes, for R1: none (no committed frame shows a page link's outcome).
  - **L7 built on 2026-10-22** from `v2` at `8cb9d92e`, on `claude/l7-launch-kit-591be1`, and **opened as #1780** on the owner's word of 2026-10-22; **merged as `7bbf36cb`**. A commit for items 1 to 3, one for item 4, one for item 5, then a docs commit; tools and copy only: no app or test code, no index version, no CloudKit change. **#1763, 1 and 2**: recording T's last three beats are the routes S1 recorded, checked in the code on `v2`: **Export…** ▸ the PDF card ▸ **Export PDF**, whose first page is the title page (the title, the collection note, the contents; the collection has no introduction); Research ▸ **FRUS Research Guide** ▸ **Next** to *Production & Timeliness*, the start year set in the year chip's popover (two year fields with steppers; nothing to drag); **% of documents**, then **Administration** ▸ *Dwight D. Eisenhower (1953–1961)* and **View N documents ↗** (a time chart has no bar to tap). A note under the table says why. **#1763, 3**: frame 10's sublines read *…then narrow the years to the spike and open its documents in Search. The chart exports as a figure or a CSV with its method stated.* on the iPad and the Mac (*Every chart* was the claim the kit's §5 had dropped), and both manuals' §18.6, the kit's source, no longer say *tap into* or *click into*. **#1763, 4**: the composer draws the review stamp over the frame's top margin, out of the layout's flow, so a stamped draft lays out as its store frame does (all 34 frames measure the same both ways) and the foot keeps its 78% on every preset: on the iPhone the disclaimer takes 2 lines on frame 01 (5 before) and the NARA sentence 2 on frame 04 (9 before). `STAMP=0` leaves the stamp out for App Store Connect and refuses a shot with no capture. The 38 committed drafts are rendered again, none changing size. **#1763, 5**: the check copy's README says how to put the copy's preferences back (key by key through CFPreferences, read back through `defaults export`) and how to record it while computer use drives it (ScreenCaptureKit, leaving the Claude app out), with S4's two helpers committed beside `axread.swift`; the kit's §4 no longer names QuickTime. What L7 changes for R1: no capture; every composed frame (the stamp's place, the foot's width, frame 10's sublines), and recording T's last three beats (this session's log entry says what each shows).
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
  - **R1 run on 2026-10-22** from `v2` at `7bbf36cb` (every lane merged), on `claude/r1-retakes-42d073`, and **opened as #1781** on the owner's word of 2026-10-22; **merged as `0f5c8ef5`**. Build 1861 on S1's to S3's simulators and in the Mac check copy, by each sitting's conventions, the iPad and iPhone frames with their time and date erased by S1's and S3's scripts unchanged. **21 captures retaken**: the 17 the lanes listed, and four their lists missed, `ipad/cite-sheet` (the rail toggle L1 tints, behind the Cite sheet) and the three zero-result frames, whose MATCH strip parser 6.8 (L2) prints `"unravel"` where it printed `"unravel?"`. Each was diffed against the frame it replaces and differs only where its lane said, and in the status bar; `stage-manager` now has the document window in front, since L1's tint shows only on the active window. **The 34 store frames are composed with no stamp in `~/Desktop/store`** (14 iPad, 14 Mac, 6 iPhone, and four contact sheets), and the drafts are rendered again (ten files changed). No manual sentence changes. The ledger's R1 entry has the devices, the times and the one finding (§5). Recordings A, R and T and the App Previews were not taken again (decision 89); the entry says what the lanes changed for them.
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
  - **R2 run on 2026-10-22** from `v2` at `0f5c8ef5` (R1 merged), on `claude/r2-testflight-1776-5d0908`, and **opened as #1782** on the owner's word of 2026-10-22; **merged as `8cb1c868`**. **The tree reads 1.0 (1776)** from `c96cad13`, the final code: `CURRENT_PROJECT_VERSION` in `project.yml`'s three targets and `project.pbxproj`'s nine occurrences, the README's line and its mirror, and an amendment-log bullet. **Both TestFlight notes are rewritten for first-time testers**, describing the app as it is, with the release-candidate flag at the head and the build-50 re-index named; every fix is in the one line (iOS 3,893 and Mac 3,882 characters). **The checklist at the final code, each figure A19's or explained:**
    - the clean `build-for-testing` from an empty folder: 177 s, the two known residues and nothing else;
    - the full unit target on iPhone 17 under iOS 27.0: 7,606 tests in 900 suites with #1606's six known issues (A19's 7,540 in 891, with the lanes' tests since);
    - `swift test`: 3,030 tests in 361 suites, 38 runs, none failed (#1771's figure);
    - the Mac build: 605 compile lines, the two residues;
    - the window-fronting audit: 80 / 2 / 34 / 0, 20 scenes, 23 `openAuxWindow` sites, with no opener line changed since A19;
    - the link check in report mode: 20 OK, 3 owner-asserted, 0 dead; 3 OK;
    - the dSYM fetch: all five UUIDs verified, A19's;
    - `check_cloudkit_schema.py`: PASS, 268 of 272 identifiers required, Production 310, with `CloudKitSchemaInventory.swift` and every `@Model` file unchanged since A19;
    - index v71 and rollup v12 unchanged, so no re-index census;
    - the Mac check copy at 1.0 (1776): About reads *Version 1.0 (1776)*; a page link the map names opens the *Volume Not Downloaded* alert, and one it does not list opens the volume's page in the Corpus Browser naming the page, from a page pushed in another subseries too (L6, #1779); **View 1,445 documents ↗** over Kennedy's years opens Search on 1,445 (L3); the working corpus's sheet shows **Narrowed by**, and a new search opens at its first row (L2).

    The session entry has every figure.
  - **The owner's steps for R2**, in the checkout the archive is cut from, since the dSYM cache and the schema stamp belong to the checkout they ran in:
    1. bring `v2` to R2's merge commit;
    2. run `./Scripts/fetch-llama-dsyms.sh` and `./Scripts/check_cloudkit_schema.py` there;
    3. archive and upload the iOS app (`FRUSExplorer`) and `FRUSExplorerMac`, both schemes archiving in the AppStore configuration, with `Docs/TestFlight-Instructions-ios.md` and `-mac.md` as each build's What to Test;
    4. tag that commit `build-51` and push the tag (decision 99);
    5. make the device pass on an iPhone, an iPad and the Mac.

    A defect the pass finds goes to a lane, and the next upload takes a number between 1776 and 1861 (decision 87). Otherwise R3 follows.
  - **The upload, 2026-10-22.** App Store Connect refused 1.0 (1776)'s Mac notes for an invalid character, and #1783 (`f0479037`) put into words the three controls the notes had named by symbols no accepted upload carried: ⚙, ✕ and ⓘ. The owner tagged `f0479037` `build-51`, "TestFlight 1.0 (1776), both platforms" (decision 99). The four issues the owner filed on 2026-10-26 are L8 (decision 100).
- **L8, four issues filed after the upload** (decision 100). One fresh session and one pull request: a commit for each issue, then a docs commit, under §0's rules. None of the four changes what indexing stores, so no index version; none adds a `@Model` or a stored property, so no CloudKit change. If #1799's lookup is made the kit's (beside `PageLink`, in `FRUSCoreKit/TEI/FRUSURLScheme.swift`), `swift build --target FRUSCoreKit` and `swift test` are owed. Each issue's body is a line or two, so this bullet is the brief, read from the code at `v2` `907febd2`:
  - **#1796, a Mac launch with no network stalls.** Every platform's main window is `ContentViewWithSplash`. Its one resolve after the first frame raises the `.cloudKitImport` splash when a CloudKit event of any phase is in flight and no import has yet ended this launch (`CloudSurfaceArbiter.resolve`); `cloudKitSyncState` turns `.syncing` at the start of a setup, an import or an export. The splash lifts only when `hasInitialProjectSyncSettled` turns true, which only an ended `import` event sets, and deliberately "not on a timer" (`ContentView.swift`). So a launch that resolves while an event runs, and then sees no import end, keeps the splash over the window for as long as the app runs, and a launch with no network can be that launch. This is the first suspect, not a finding.
    - Measure first. Read the unified log of the launch the issue reports (the app's `Logger` lines and `NSCloudKitMirroringDelegate`'s), read-only. Then take the owner's launches with the network off (a session changes no system setting), on the Mac and on an iPhone or iPad, whose window is the same.
    - The fix lets the launch through whatever sync does: the splash lifts when the event it waited on ends with no import begun, or after a bound. `CloudSurfaceArbiterTests` takes the sequence: setup starts, the resolve, setup fails, no import.
    - The issue also asks that an iCloud time-out or failure not hold the launch. Walk one launch signed out of iCloud and one whose sync fails, and read `bootSearchInfrastructureOnce()` and `checkCloudKitHealth()` for any other wait on the network.
  - **#1797, the Most-Referenced Documents chart opens nothing.** The subtitle over both displays says "Select a document to open it" (`crossRefAnalytics.ranking.subtitle`), but only the list's rows are buttons (`rankingTable`, which calls `openDocument(volumeId:documentId:header:)`). `CrossReferenceRankingChart` has no tap, selection or overlay, on iOS or the Mac. Make a bar and its axis label open the document as its row does, on both platforms, and let VoiceOver open it too. The exported figure draws the same view (#1473), so the action stays out of the figure. A test in `CrossReferenceRankingChartTests` (`AnalyticsRotationTests.swift`) taps a bar and finds the document open, and `CLAUDE.md`'s row for the suite takes the new count.
  - **#1798, the corpus word cloud crashed an M1 iPad Pro.** Browse ▸ Analysis Tools ▸ Corpus Word Cloud (`BrowserView.swift`) and the cloud's own Scope ▸ Entire Corpus count every document in the library on the device. `WordFrequencyService.topTerms` reads their text 400 at a time and tags it with WordCloudKit's `NLTagger` tokenizer, with no autorelease pool. The generator that counts the corpus with that kit recorded what no pool costs (`CloudVectorsRunner`'s "Memory" note, and `CloudVectorsGenerator`'s entry in `Generators-Runbook.md`): a 24.9 GB footprint over the corpus without one, and 893 MB with one for each document. Whether Swift's executor drains the app's objects at each chunk's `await` is for the measurement to settle.
    - Measure first, as the issue asks: a corpus count's peak footprint and its time for each lens, on a simulator holding a full library and read from the host, and the owner's report from the iPad, where a `JetsamEvent` report means memory.
    - Then fix in this order. First a pool for each document, as the runner has. Only if the count still does not fit an iPad, take the corpus scope off iOS as the issue proposes, with Browse's entry, the scope menu and both manuals brought to match; the Mac keeps it. The subseries and subject clouds count the same way and take the same fix.
  - **#1799, the timeline leaves out what the Long Telegram cites.** The screenshot is `frus1946v06` d475, of 22 February 1946. Its note 45 cites 1943 vol. III, pp. 531–532 and 542–543: two ranges across documents of 19 May to 11 June 1943, which rule C leaves on the volume as `pg_531`, `pg_532`, `pg_542` and `pg_543`. The graph draws each as an outbound node with no title and Open disabled (`Cross-Volume-Page-Citations-Assessment-2026-10-20.md` §10, side finding 2). `CrossReferenceStore.graph` gives the node a placeholder with no date, and `timelineLayout` parks every undated node in the Undated column, so the four never reach the axis, which runs from the focus to 1 April 1946.
    - The layout already starts the axis at the earliest dated node, so the fix is in the node, not the axis. Date an outbound page node by the documents on its page: from the device's page index when the volume is on the device, else from `cited-page-map.json`'s facts where it lists the page, else from the volume's own range in `manifest.json`, drawn at the precision it has (1943 vol. III's runs from 30 May 1942 to 24 March 1944). Title it by its volume and pages, as "1943, vol. III, pp. 531–532". This is §3's untitled outbound page node, which L8 takes.
    - An outbound document in a volume not on the device, and an inbound one from such a volume (`resolved-edge-index.json` carries no dates), park the same way and take the same fallback.
    - A18b's run left 19,213 of the 48,604 page references into other volumes on the volume: 10,633 "ff.", 8,326 ends of ranges across documents, 227 single pages naming nothing and 27 broken or outside the catalogue. Measure, over a full library and over one holding only the citing volume, how many nodes park as Undated before the fix and after it, and how many each source dates. Walk d475 on an iPhone and on the Mac, with 1943 vol. III present and absent.
  - The lane's log entry lists the captures it changes, and decision 88 has them retaken before R3.
  - **L8 built on 2026-10-26** from `v2` at `5cba0dc9`, on `claude/l8-four-issues-7877ef`, and **opened as #1801** on the owner's word of 2026-10-26; **merged as `36e7add7`**. A commit for each issue, then a docs commit; app code only (nothing under `FRUSCoreKit/` or a package target), no index version, no CloudKit change. **#1796**: the installed 1.0 (1776)'s sync log and unified log for the reported launch (read-only) show every zone check meeting CloudKit's *network unavailable* and no import ending before the launch was quit; no other wait on the network holds a launch. No CloudKit splash is raised offline, and one already up lifts at the first of an ended import, no network, 3 s of idle sync with no import begun, or 15 s, and is logged with its reason (category `LaunchSplash`); `CloudSurfaceArbiterTests` takes the brief's sequence. The owner's network-off launches of 1776 on two iPhones did not stall; each held *Preparing your index…* longer than usual, and Settings read *Synced* while every zone check failed (reported, not changed). The owner's launch of 1776 on the Mac with the network off held on the iCloud splash until it was quit three minutes later; its log shows setup succeeding from the cached account, every zone check failing, and the import's fetch beginning 3.1 s in and never finishing, the case the fix takes. **#1797**: a bar of the Most-Referenced chart, or its title, opens its document as its row does, and VoiceOver opens it through a button over each bar's row; the figure takes no action; `CrossReferenceRankingChartTests` 3 of 3 on the iPhone 17 (iOS 27.0) and an iPad Pro 13-inch (M5) (iOS 26.5), both new tests failing on the iPhone on the chart without its action; in the Mac check copy a bar and a title each opened their document in the main window. **#1798**: measured in the test host on an iPhone 17 simulator over a full index (553 volumes, 321,749 documents): without a pool the count kept 70 to 100 KB a document in every lens, released none of it, and held 4.5 GB after 60,000 documents (a corpus count about 25 GB); with a pool for each document each lens held at 88 MB over 5,000 documents, and the corpus count in the default lens, from 139 MB at its start, peaked at 158 MB in 1,036 s. The iPad's report (Xcode's Organizer, build 1776 on iPad13,11) confirms the cause: the count's autorelease pool failed to get a new page 6½ minutes in, so the corpus scope stays on iOS. The corpus cloud's note says what it costs and that closing it stops the count. **#1799**: a node the device holds no row for is dated by the documents on its page (page index, then page map), its own day (page map), or its volume's span, at whose middle it sits, and a page node is titled *1943, vol. III, p. 531*; over build 1776's full index Undated document and page nodes fall from 21,694 to 2,230, and with only the citing volume on the device from 92,298 to 1,282; walked on a clone of S3's iPhone 17 Pro (iOS 27.0, full library) with 1943 vol. III and without it, the date group at May 1943 and, from the middle of the volume's span, at April 1943, and in the Mac check copy the same. Checks: the full unit target on the iPhone 17 (iOS 27.0), 7,673 tests, none failed; the Mac build. The captures L8 changes, for decision 88's retakes before R3: `ipad/cross-reference-graph` and `macos/cross-reference-graph`, whose `frus1948v01p2/pg_507` now reads *1948, vol. I, pt. 2, p. 507* and, on the Mac's timeline, sits on the axis rather than in the Undated column.
- **L9, the work under way on the Mac** (decision 110). Two kinds of local session were running on 2026-11-01, and their pull requests arrive from the Mac under §0's rules; this plan does not describe their builds beyond their briefs.
  - **#1823, the Collections Manager lacks CRUD.** The owner's issue of 2026-11-01: the Mac's Collections Manager "lacks CRUD capabilities that are the bare minimum for this UI surface", iOS has partial CRUD, and both are to have at least CRUD. Not kit code unless the lane makes it so; no index version; a stored property added to a `@Model` is a CloudKit change, which the R-7 gate catches and 1787 cannot ship without the Production deploy. The captures it changes, for R4: `macos/collections` and `ipad/collections-editor`, and any manual frame of the editor's toolbar.
  - **The summarization follow-ups**, after the six that merged on 2026-10-31 and 2026-11-01 (#1820 for #1765; #1821, #1822, #1824, #1825 and #1827). What those entries left, each in its *Found, not fixed* or *Not done* list in the session log: a chunked summary's synthesis keeps too little of the document, so the Long Telegram's headnote is not yet a good one (#1820); a model that declines may write its refusal as the answer (#1820); no device and no iOS 26 system was measured, where a 4,096-token window leaves an answer 1,000 to 2,100 tokens (#1825, #1827); and the app was not run with #1827's retry. No index version: a summary is not keyed by the budget, and `summaries` is indexed as before. The captures they change, for R4: none committed shows a summary (d474's and d476's were made in S4's home for the recordings only), so the R4 session checks `ipad/research-rail` and `macos/collections` for a summary surface and retakes nothing for these unless one shows.
  - What merges before R2b's checklist runs goes into 1787. A lane that merges after it waits for the upload after 1787 (decision 110).
- **R2b, the second TestFlight pass, 1.0 (1787)** (decision 110), on 2026-11-02, one fresh session from `v2` at its head that day.
  - Run the release checklist as R2 ran it, each figure against R2's:
    - the clean `build-for-testing`, read for warnings: the two known residues and nothing else;
    - the full unit target on iPhone 17 under iOS 27.0 (R2 had 7,606 tests; #1828's merged tree had 7,848 in 940 suites, 37 skipped);
    - `swift test`, which is owed: kit and package code changed since `build-51` (#1784 to #1789, #1805 to #1809, #1813 to #1816, #1826 among them);
    - the Mac build, and a walk of the Mac check copy that opens what changed since 1776: a launch with the network off (#1796), a bar of the Most-Referenced chart (#1797), d16's network at three hops and d475's timeline (#1764, #1799), the Long Telegram's summary and a structured summary's fields in the collection inspector (#1820, #1822, #1824), and the Collections Manager if #1823 is in;
    - the window-fronting audit (R2: 80 / 2 / 34 / 0, 20 scenes, 23 `openAuxWindow` sites);
    - the link check in report mode;
    - `check_cloudkit_schema.py`, which should read PASS: `CloudKitSchemaInventory.swift` is unchanged between `build-51` and `e47ca307` (measured 2026-11-01 by `git diff --stat`), and the model files that changed did so for the kit moves of #1786, S17b and S18a (nested value types and rules over values, no `@Model`'s stored properties) and the duplicate-copy fix (#1792), each merged with `CloudKitSchemaInventoryTests` green; so a stored property can only come from a lane merged on 2026-11-02, and the R-7 gate catches it;
    - index v71 is unchanged, so no re-index census. Rollup **v15** is not: a library at v12 (build 1776's) rebuilds its People once at launch (#1815, #1816, #1826), and the TestFlight notes say so.
  - Bump to 1.0 (1787) by `CLAUDE.md`'s procedure: `CURRENT_PROJECT_VERSION` in `project.yml` and every occurrence in `project.pbxproj`, the README line and its mirror in `Docs/EditableContent/03-Repository-README.md`, and an amendment-log bullet.
  - Rewrite both TestFlight notes for 1787, each 4,000 characters at most counted by Python's `len()`, for a tester who has 1776 and for a first-time tester, with ⚙, ✕ and ⓘ written as words (#1783). What they name, from the 40 pull requests since `build-51`: People rebuilt once at launch (rollup v15, with Kissinger's two links and the record moves to look for); a launch with no network no longer held by the iCloud splash; the Most-Referenced chart's bars open their document; the corpus word cloud's scope off iOS; the timeline dating a cited page; the network at three hops laid out and labelled; the Long Telegram summarized, a refusal read as a sentence, a long document's summary covering the whole document, a structured summary shown as its fields on every surface, and the budget on an 8K model; the collection preview following the reader's summary; an exact-word search under a second; a highlight the reader could not draw no longer hiding the others; typed prose in a dark-appearance export; notes and saved searches stored as several copies listed once; a research database exported without the notes keeping no word of them; and #1823's Collections Manager if it is in.
  - Before the archive: `./Scripts/fetch-llama-dsyms.sh` and `./Scripts/check_cloudkit_schema.py`, in the checkout the archive is cut from.
  - **The owner's steps for R2b**, as for R2: bring `v2` to R2b's merge commit; run the two scripts there; archive and upload `FRUSExplorer` and `FRUSExplorerMac` in the AppStore configuration, with the two notes as What to Test; tag that commit `build-52` and push the tag (decision 113); make the device pass on an iPhone, an iPad and the Mac, reading the People rebuild and #1826's list (§4) on a library that had 1776. A defect the pass finds goes to a lane, and the next upload takes a number between 1787 and 1861.
- **R4, the retake sitting after 1787** (decision 111). After the upload, from 1787's own code, on S1's to S3's simulators and in the Mac check copy, by the ledger's conventions (`Docs/screenshots/README.md`, S1 to S4's and R1's entries; an iPad frame matches the set only with the status bar's time and date erased). The session first reads every merged pull request since `build-51` for the captures its log entry lists, since this list was made on 2026-11-01 and L9's lanes add to it:
  - `ipad/cross-reference-graph`: L8's page-node title (*1948, vol. I, pt. 2, p. 507*) and #1764's layout at three hops, with its labels and the list's order; the throwaway iPad Pro 13-inch (M5) simulator #1764's session kept for it, "1764 iPad Pro 13 (throwaway)", `34F01AA6-CE00-49BF-83BF-2063C114FC7B`, holding a clone of S1's library;
  - `macos/cross-reference-graph`: the page node on the timeline's axis rather than the Undated column (L8), and the date cluster's label above its cluster (#1764);
  - the store's tenth frame, `researchers-06`, cropped from the iPad graph (#1764's session, decision 1: "Fix now, retake frame");
  - `macos/collections` and `ipad/collections-editor`, if #1823 is in 1787, and any other frame its lane lists;
  - any frame a summarization lane lists; none is expected (L9);
  - every frame whose text a merged lane changed is read against its manual sentence, and the ledger's R4 entry records each retake with its device, its time and what differs from the frame it replaces.

  Then run `tools/marketing/compose.py` again at the store sizes with no stamp (`SCALE=1 STAMP=0`) for any store frame a retake feeds, `researchers-06` at least, write the result to `~/Desktop/store` beside R1's, and render the drafts again. No manual sentence is expected to change; a lane that changed one has already done so. The recordings and the App Previews are not taken again (decision 89).
- **G1, the Agentic Analysis Guide's revision** (decision 112). Documents and measurements only, on the Mac; no app code. The guide stands at v1.40 (2026-10-31): R1 and R2 adopted after the rewrite test, the rest of the two reviews' list not. The session starts by putting the scope to the owner from this list, and takes what the owner chooses:
  - **The text.** The steering review's recommendations that presupposed the READER-FACING OUTPUT section's adoption and waited on it: R9 (the URL carries the pair, every number has a line), R11 (the collection's prose and notes are reader-facing too, and the vector vocabulary is named), R12 (one model sentence for the vector work) and R13 (the bottom line's citations are complete), read again against v1.40, since R1 took some of what they asked. The style review's third open question, whether the collection's notes are rewritten as the overview was. Whether §15.1's and §15.1a's examples, byte-identical since v1.38, are rewritten under the adopted section and §14.16's template; `CollectionTests.publishedExampleMatchesTheGuide` pins the §15.1 block and moves with it (decision 9). The trace table, O2, which failed in all twelve of the reader-facing tier's runs and was the first C-3 run's weak rule: a revision of the rule, or of what the harness counts as a trace row.
  - **Not adopted, by the tiers' rule, and not to be re-proposed without a new measurement:** R6's vocabulary bullet and the SEMANTIC VECTORS section inside the block (R16, 2026-10-30), R7, R8 and R10 (K, 2026-10-31), and R15's card, whose spot check is designed in `C-3-Reader-Facing-Tier-Design.md` §5.2. The W and K candidates stay on the Mac's local branches (`b40d2da6`, `5e8bd1bd`, unpushed).
  - **The owner's open choices:** whether the guard's per-run clause stays, given that the control breached it (`C-3-Reader-Facing-Tier-Results-2026-10-31.md` §7); a second question for §3a's model table, which it calls "the first thing a later run adds", from the three of the owner's candidates still unused; and whether a measurement tier follows the text at all, under a budget line set as before. The meters reset on 2026-11-04, so a tier that starts after that date has the week's whole allowance.
  - **The documents.** The inputs are `Agentic-Guide-Steering-Review-2026-10-27.md`, `Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md`, the four results files and the rewrite test, with the harness facts in `Agentic-Harness-Runbook.md` (its §7 cost table runs through the reader-facing tier). A review or design whose work is done moves to `Completed/` by §6's rule; one the guide, a test or a tool cites is marked complete in place. The guide's version history and §3a take each change, and `CLAUDE.md`'s rule on language pins (decision 9) applies to the §15.1 block.
- **R3, the submission.** Restore 1.0 (1861) by the same procedure. The owner archives, uploads, tags `1.0-release` on that commit (decision 113, which refined decision 99's `version-1.0`), and submits to App Review with §2's answers.

---

## 2. Submission — what only the owner does

The repository holds drafts for each.
- **The website.** Make frusexplorer.app public and paste the Privacy Policy and Support pages (decisions 36 and 58; `Docs/Privacy-Policy.md`, `Docs/Support.md`, `Docs/Website/`). App Store Connect requires both URLs. Every path answered 401 on 2026-10-21, as on 2026-10-19.
- **App Store Connect:**
  - the privacy label: Data Not Collected (decision 35);
  - the listing, from `Store-Listing-Draft.md` (decisions 28 to 31);
  - the screenshots, from R1's composed frames, with the 13-inch iPad slot checked for 2752 × 2064 landscape (decision 33). R1 wrote the 34 to `~/Desktop/store` on 2026-10-22: 14 iPad at 2752 × 2064, 14 Mac at 2880 × 1800 and 6 iPhone at 1320 × 2868, none stamped, with a contact sheet for each audience;
  - no App Previews (decision 89);
  - the App Review notes: the query encoder is an optional 310 MB download of an Apache-licensed model from a public GitHub release, with no agreement step (decision 18), and the app is not an official product of the Office of the Historian;
  - the age rating, export compliance, and a Mac build signed for the App Store.
- **`check_repository_links.py --stamp`**, which writes the owner's confirmation date.
- **The archive, the uploads and the tags** (R2, R2b and R3): `build-51` on 1.0 (1776) (decision 99), `build-52` on 1.0 (1787) and `1.0-release` on 1.0 (1861) (decision 113).

---

## 3. After submission

- **The website's pages** (decision 101), while App Review runs and before release.
  - **Generate.** Build each page from `Planning/website-drafts/`: the home page and the tour in their coming-soon versions, and the Support and Privacy drafts folded into `Docs/Support.md` and `Docs/Privacy-Policy.md`, the copies of record, with `Scripts/build_website_pages.py` and a row in `Docs/Website/README.md` for each new sentence (decision 36).
  - **Review.** Recount every figure from 1.0 (1861)'s shipped artifacts, retake every screen from the submitted build, read each page against the launch kit's §6, and keep the reading level by the drafts' method.
  - **Revise and publish.** The owner pastes the pages into frusexplorer.app. On release day the home page and the tour switch to their launch versions, the home page takes Apple's App Store badge, and Support's coming-soon line comes out. Whether the home page and the tour become copies of record under `Docs/Website/` is the owner's call at this step.
- **C-3, the agentic analysis measurements** (decision 91): before build 52 starts, on the owner's Mac. Its design is `C-3-Reader-Test-Design.md`, with its budget rule; the harness facts are in `Agentic-Harness-Runbook.md`. **Done 2026-10-25/26**, ahead of the submission on the owner's word: `C-3-Results-2026-10-26.md`, record in `c3-reader-test/`, the guide's §3a. Opus 5.5 at `medium` is the fastest and the best value, Sonnet 5.5 at `high` the highest quality; the reader-facing block section held in 31 of 36 reader items, the trace table (O2) its weak rule. The next plan decides whether the section is called adopted and what a second question looks like. The run used no vector artifact; the tier adding Appendix A and the vectors for the two recommended cells (`C-3-Vectors-Tier-Design.md`) **ran 2026-10-26/27** on the owner's four decisions and the owner's Cuba question: `C-3-Vectors-Tier-Results-2026-10-27.md`, record in `c3-vectors-tier/`, the guide's §3a paragraph (v1.36). Every run used all five of Appendix A's operations; two of four reached and quoted a document full-text search could not; one compliance item lost a run; Appendix A's worked figures were found to be the previous generation's and re-taken (v1.35). `Agentic-Guide-Steering-Review-2026-10-27.md` read both tiers' records and made sixteen recommendations; those outside the §12 block and the deliverable are in the guide at v1.37 (2026-10-29: §14.17 and the rest). The block's revisions wait for its R16, a two-arm tier. The owner answered the review's five questions on 2026-10-30: the vectors section goes inside the block; centroid similarity is dropped; the third question is chosen from five the owner proposes; READER-FACING OUTPUT is adopted in substance and scope, with its style and language a pass of their own; and the budget is as proposed, with the tier starting that day rather than after build 52. R16's design is `C-3-Steering-Tier-Design.md`. **It ran 2026-10-30** (`C-3-Steering-Tier-Results-2026-10-30.md`, record in `c3-steering-tier/`), nine runs on the owner's corruption question, inside the owner's lines (19 points weekly, 34 Fable). By its rule the revised block and card are not adopted: the cost reading failed by one item. R6's vocabulary bullet and R8's stem trap each showed an effect of their own. The owner followed the rule (2026-10-30): nothing is adopted, the guide records the measurement at v1.38, and R7, R8 and R10 are owed a measurement alone. The reader-facing pass's style review is written (`Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md`), and its four-pair pilot ran the same day: the judge preferred the revised wording in 4 of 4, and the traced-numbers reading failed, so the wording's numbers rule was revised the same day. The owner skipped the full rewrite pass: the revised wording goes to the next full tier, with R7, R8 and R10. **That tier ran 2026-10-31** (`C-3-Reader-Facing-Tier-Results-2026-10-31.md`): twelve runs on the owner's soft-power question; by its rule nothing is adopted, and the owner followed it (guide v1.39). After a rewrite test that held the research fixed (`C-3-Reader-Facing-Rewrite-Test-2026-10-31.md`, the revised overviews preferred in 7 of 8 pairs), the owner adopted R1 and R2 (guide v1.40).
- **The release after 1.0: its candidates.** *(The heading read "Build 52's candidates" until 2026-11-01; build 52 is 1787 since decision 113.)* Their order is the next plan's (decision 90).
  - **#1723, A7: App Intents and Siri.** A7a covers the entities, the four intents and the copy. A7b covers the Spotlight association with `expirationDate` and a `CSSearchableIndexDelegate`, which closes two Spotlight findings: donated items expire after 31 days, and nothing answers Spotlight's requests to reindex. The plan is `App-Intents-Siri-Assessment-2026-10-18.md` §5, and the owner's device check (Spike Reader) decides A7b's place.
  - **Cross-references:**
    - #1764, the network at three hops. *Fixed before the submission, 2026-11-01, by #1828 (`3fd3b4ee`), on the owner's word in its session ("Fix now, retake frame"), since the store's tenth frame shows that view; its retakes are R4's. Its session's findings are in §5.*
    - the graph's untitled outbound page node, which L8 takes with #1799 (decision 100). *Done in L8 (#1801).*
    - six cross-volume references by id to a section's row, missing from the bundled edge index (A18b).
  - **#1765, summaries:** the Long Telegram refused, and the Mac's stale collection preview. *Fixed 2026-10-31 by #1820 (`233dc344`), with five follow-ups the same two days (#1821, #1822, #1824, #1825, #1827); what they left is L9's, and all of it goes into 1787 (decision 110).*
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
- **R2b, 2026-11-02** (decision 110): the archive and upload of 1.0 (1787) in the checkout the two scripts ran in, the `build-52` tag (decision 113), and the device pass on an iPhone, an iPad and the Mac, on a library that had 1776, so the People rebuild at v15 is seen.
- **G1's scope** (decision 112): which of §1's G1 items are taken, and whether a measurement tier follows the text, with its budget line.
- **The website's pages** (decision 101): the pastes into frusexplorer.app, and whether the home page and the tour become copies of record.
- **For A7** (#1723): the device check with Spike Reader. It is `App-Intents-Siri-Assessment-2026-10-18.md` §4, and `jolly-newton-d5828b`'s untracked `A6Spike/` holds the app.
- **The manual review**, past build 52 (decision 94). `Manual-Revisions-Pending.md` and `Manual-Update-Build-49-Owner-Review.md` are its inputs and close with it.
- **App Previews** for a later update (decision 89): recordings A, R and T are kept outside the repository.
- **For #1767** (decision 109), closed with these left:
  - the device check of a library rebuilt at rollup v15, from #1815's, #1816's and #1826's lists (among them Kissinger's Wikidata and VIAF links, Kirkpatrick across eleven volumes, E. Romney Wheeler apart from the General, and Truman keeping Q11613);
  - whether to file the three reports drafted in `Person-Authority-Upstream-Reports-2026-11-01.md` with `HistoryAtState/people`.

---

## 5. Backlog, parked, deferred and closed

### P2 — later

- **Generators:** provenance flows count no page reference (`RefDestination.citedDocument` is nil for a page).
- **Section vectors**, at the next vectors generation (decision 61).
- **Found by #1764's session (2026-11-01), unfiled:** a graph of 1,259 nodes cannot be read on an iPad canvas under any layout tried (NSC 68 at three hops places 11 labels, with about 3,200 pairs of discs overlapping), so clustering or a cap on what three hops draws is a design question; one-line labels, the number without the date, placed about twice as many on d16 in the harness (62 against 26), and what a label carries is the owner's call; the walk's reference-list toggle opened nothing on two taps on the iPad, and whether the tip's popover takes the first tap was not checked.
- **Found by the summarization sessions (2026-10-31 and 2026-11-01), unfiled:** L9's list in §1.
- **Smaller app items:**
  - `ProjectLeadsService` ranks with no year;
  - `datesByDocumentKey(_:)` scans every `document_dates` row (17 ms against 0.03 ms by the key);
  - the archival chip is cut on the iPhone 17;
  - Sync Diagnostics' Clear Log draws its trash icon in the accent colour;
  - a phrase can match across a document's heading and its form marker, since `body_text` begins with both: 13 of *"long telegram"*'s 136 rows match only as *…to Minister Long* followed by *[Telegram]* (found in L2);
  - since #1760 a question's keyword snippets cost about three times A10b's in a release build, where the scan runs on to the rarest word; a faster scan (an ASCII fast path in the gates, or a UTF-8 scan) would win it back (found in L2). **The ASCII fast path is built** on 2026-10-22, on `claude/reverent-wiles-972304` from `v2` at `38dc3d7c`, and **merged as #1771** (`8843b88e`). On the merged tree the full unit run (7,571 tests), the Mac build and `swift test` (3,030 tests) pass. Over L2's 33 searches the snippet pass costs 4.05 s at 1,000 rows (A10b 4.64 s, `v2` 7.97 s) and 16.43 s at the Mac's ceiling (A10b 28.98 s, `v2` 36.80 s); 90% of what #1760 added to the questions is won back, and every snippet is byte-identical. The UTF-8 scan was not built (that session's log entry says why);
  - a number typed with a mark (`1945.`) searches nothing, and nothing says so; a hyphenated word (*long-range*) never anchors a snippet on its parts; an `=` word never anchors one (found in L2).
  - on the Mac, a volume hand-off that changes the Corpus Browser's subseries while a volume's page is pushed shows the new subseries' list and no page: a link to a whole volume (#1603), a page link #1766 sends to its volume, a provenance row or a subject pivot. Measured in `v2` at `88b3b7d1` as well as on L6's branch; with only a list showing, the hand-off opens the page (found in L6). **Fixed** on 2026-10-22, on `claude/relaxed-hypatia-b0a197` from `v2` at `88b3b7d1`, merged with `v2` at `700cb5a3`, and **opened as #1779**, **merged as `8cb9d92e`**. Changing the sidebar's selection makes SwiftUI pop the detail stack itself, after the browser's own push, and the stack reads no path until AppKit shows the new list, so the push now waits until the new selection's list is in the window. In a copy of the split view the push then opened the page in all 74 hand-offs, where `v2`'s code lost it in all 14. In the check copy it opened the page from a pushed page and from a list, by a link to a whole volume and by a page link. On the merge the full unit run (7,606 tests) and the Mac build pass (that session's log entry has the rest).
  - a page link into a volume on the device whose page names no document still does nothing, as before #1766: 608 of the 48,577 page references into other volumes on a full library, and same-volume ones besides (found in L6).
  - under iOS 26.5 in Stage Manager, a document popped out with Open in New Window draws its Research rail's column black until the window is moved: seen twice on the 26.5 iPad simulator, not measured, and not established on iOS 27 or a device (found in R1).
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
  - `Docs/Agentic-Analysis-Guide.md` §14.11 still gives 3,985 archival collections, and the map's figures from before B4's layout (172 clusters, 92,268 unclustered, where the shipped map has 140 and 88,059) (found in L1). **Fixed** in the guide's v1.37 (2026-10-29): 3,977 collections and 11,041 class keys, 140 clusters with the shipped layout's label readings; the unclustered count had been re-taken at v1.35.
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
- **For HistoryAtState/people to fix:** the registry's own merges (Stevenson, Wilson, Fish), its duplicate records (Rowan, Regan, Tran Buu Kiem) and Sir Oliver Wright's two missing anchors. The three reports are drafted in `Person-Authority-Upstream-Reports-2026-11-01.md` and are not filed (§4).
- **New volumes**, whenever the Office publishes, by `New-Volume-Release-Plan.md`.

### Closed or declined

- **Closed:** #1690 and #1691 (decision 95).
- **#1620, the iPad simulator's render server under iOS 27.0, closed on 2026-11-01** (decisions 72 and 114), once the host's update had ended it.
- **#1767, the person authority's deferred work, closed on 2026-11-01** (decisions 96 and 109): the identifier rule (b4), the role text of overlay entries that carry several people, the nine held-apart members who rejoin by name, and #1658's undecided tie.
  - **Lane A built on 2026-10-29** (decisions 102 to 104) from `v2` at `fb542514`, on `claude/person-authority-lane-c64504`, and **opened as #1815** on the owner's word of 2026-10-29: the nine and #1658's tie, with the design's §4.6. Kit and generator code, rollup v13, no index version, no CloudKit change; `person-authority-index.json` and `pocom-index.json` regenerated. Over S1's full library, 22 of 63,667 people entries change person. The nine stand apart (John Hughes and William G. Miller join their own records instead), five ties stand apart, Speaker Jim Wright's four entries leave Sir Oliver Wright for his own record, and Sir Oliver's vol. XLIV Part 1 entry leaves Jerauld Wright. The design memo's header has what the build corrected in it. Lane A merged as #1815 (`5c185a71`).
  - **Lane B built on 2026-10-29** from `v2` at `5c185a71`, on `claude/strange-cohen-3a0b0b`: items 1 and 2, the identifier rule (b4) over a Wikidata snapshot committed beside the generator, with its refresh tool, and a multi-person entry's role text only for the records whose remarks hold it. Generator code, the snapshot, its tool and the assessment's reads (decision 105), and the bundle; rollup v14 (decision 106), no index version, no CloudKit change; `pocom-index.json` not owed (no slug moves). The file gains 1,859 Wikidata ids and 1,468 of the overlay's VIAF ids (142 → 1,610) and loses 33 role texts that were another record's, and nothing else changes. No member of a rollup moves; v14's rebuild writes the VIAF ids into a library. **Opened as #1816** on the owner's word of 2026-10-29 ("Push and open pr"), against `v2` at `5c185a71`, which had not moved since the branch was cut; it merged as `cb463e33`.
  - **The follow-up, built on 2026-11-01** from `v2` at `3cc517fa`, on `claude/priceless-hopper-b53acf`: what the two lanes found and left (decisions 107 and 108). E. Romney Wheeler of USIA stands apart from General Earle G. Wheeler (a third list in the corrections file, `standsApart`, since his overlay entry carries no people-id); Luigi R. Einaudi takes his own item (an entry carrying several people's VIAF id, once the rule gives it to one of them, is not held against the item it offers another); five identifier-only corrections (Sir William Luce, Warren E. Thompson, General MacArthur's nephew's VIAF id, Gustav Dahrendorf, Inam-ul-Haq); and `withheld` for Truman's nephew. The bundle moves 10 identifiers (Wikidata 1,859 → 1,856, VIAF 1,610 → 1,607, the General taking his own item) and one anchor into `apart`; rollup v15. Drafts of three reports for `HistoryAtState/people` are in `Planning/Person-Authority-Upstream-Reports-2026-11-01.md`, unfiled. **Opened as #1826** on the owner's word of 2026-11-01 ("Push and open PR"), against `v2` at `3cc517fa`; it merged as `4e6142c0`.
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
  - `website-drafts/`, until the website's pages are published (decision 101);
  - the two manual-review documents, until the review;
  - the A7 and C-3 designs, until their work runs;
  - the person-authority designs, until #1767 closed on 2026-11-01 (decision 109). Since then the identifier assessment stays at the root marked complete, because code, tests and a tool cite it. The overlay review and the lane design are in `Completed/`. The upstream-report drafts stay until they are filed;
  - #234's documents (decision 92);
  - the generator output folders;
  - this plan's review, `Planning-Review-2026-10-21.md`.
