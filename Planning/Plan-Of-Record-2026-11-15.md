# Plan of record — from 2026-11-15

**Base:** `v2` @ `4a269a35` (2026-11-14, #1916's merge). The tree reads version 1.0, build 1812, the third TestFlight upload (decision 125), uploaded for both platforms on 2026-11-10 and tagged `build-53` at `0c800887`. Eighteen pull requests have merged since that tag, #1887 to #1916: four records and assets (#1887 to #1890); eleven that move app code into `FRUSCoreKit`, or add kit API and tests, for FRUS Explorer Light (#1891, #1894 to #1897, #1899 to #1901, #1903, #1904, #1906), about 20,000 lines across 290 files, each meant to change nothing the app does; two that change the reader's lists (#1898, #1902); and the Zotero client's back-off clamp (#1916). Index **v74**, person rollup **v15**, EmbeddingGemma 2 vectors under digest `89481b18`. Seventeen issues are open, twelve of them filed from 2026-11-09 to 2026-11-14 (§1a places those twelve, and §3 and §5 the other five), and no pull request.

**Status: LIVE — the plan of record from 2026-11-15.** It supersedes `Completed/Plan-Of-Record-2026-10-21.md`, whose Track A ran from L1 to R2c: three TestFlight uploads (1.0 (1776), (1787) and (1812)), L1 to L14, the retake sittings R1, R4 and T1, G1, and index versions 72 to 74. Its last row, R3, the submission, is this plan's aim.

It is written from four sources:
- the owner's instruction of 2026-11-15 (decision 126);
- the twelve issues filed from 2026-11-09 to 2026-11-14, each read whole with its comments, and checked against the code at `4a269a35`;
- `Planning/UI-UX-Adversarial-Review-2026-11-15.md`, the review decision 126 asks for, every finding of which was put to an independent skeptic before it reached this plan;
- the session log's entries since `build-53`, which record two things a release checklist would stop on: one failing test in the full unit target under iOS 27.2, and a third warning line in a clean `build-for-testing` (R5).

§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 14, 15. (These are the Visual Marketing Plan's §7 steps that are done, unchanged since 2026-10-21; `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` checks the list. The line names that plan's §7; this file has no §7 of its own.)

---

## 0. Decisions, and the rules that still bind

**Decisions carried.** Their full text stays in `Completed/Plan-Of-Record-2026-10-21.md` (84 to 125) and `Completed/Plan-Of-Record-2026-10-14.md` (1 to 83). This plan relies on these:
- 17 and 18: EmbeddingGemma 2 under Apache 2.0, reaching a device as an opt-in 310 MB download with no agreement step.
- 25 and 87: the version is 1.0 and the submission's build number is 1861. Within 1.0 each upload is numbered above the last, on the Mac above every earlier upload: 50, 1776, 1787 and 1812 have gone up, so a fourth TestFlight build takes a number between 1812 and 1861, and 1861 comes last.
- 27 and 94: 1.0 ships with the manuals' *AI Generated* notice; the manual review waits until after 1.0.
- 28 to 36 and 58: the listing's three sentences, free in every storefront, English only, the store frames, the privacy label (Data Not Collected), and the Privacy Policy and Support pages with their two addresses.
- 88: a retake sitting follows the fixes, before submission, for every screen they change.
- 89: the listing launches without App Previews.
- 101: the website's pages are generated, reviewed and revised after the submission of 1.0 (1861).
- 113: `1.0-release` tags the submitted commit; a TestFlight build's tag is the owner's call (`build-51`, `build-52`, `build-53` so far).
- 117 to 119: index versions 72 to 74 ship in the next release, so 1.0 (1861) re-indexes once at launch a library last indexed by 1.0 (1787) or earlier. A library from 1.0 (1812) is already at 74.
- 120 to 124: in 1.0 and merged (L10 to L14).

**The owner's instruction of 2026-11-15**, which this plan is written from:

126. **This week's sessions work to submit 1.0 (1861) for App Review, and address the issues filed in the six days before, with an adversarial review of the UI and UX against human-centred design practice and Apple's Human Interface Guidelines.** The owner's words: "My goal for this week's development sessions is to submit build 1861 for App Store review. Please create a new plan of record that works toward that goal while also addressing issues opened over the last 6 days and performing an adversarial review over the UI/UX against both general human centered design best practices and Apple's HIG."
    - *This week* is read as Monday 2026-11-16 to Friday 2026-11-20, with Saturday 2026-11-21 as slack (§1's calendar).
    - *Issues opened over the last 6 days* is read as the twelve filed from 2026-11-09 to 2026-11-14: #1892, #1893, #1905, and #1907 to #1915. §1 places each, in 1.0 or after it, with its reason. The five issues open from before (#1854, #1835, #1723, #1696, #234) are placed too, in §3 and §5.
    - *The review* was performed in the session that wrote this plan, and its record is `UI-UX-Adversarial-Review-2026-11-15.md` (§6): seven independent reviewers, each over one platform or one cross-cutting concern, reading the current code, the 89 committed captures and both manuals against the HIG and the App Review Guidelines as Apple published them on 2026-11-15; then a skeptic for every finding. No app was run: the session's container has no Xcode. What only a running app can show is R6's device pass and §3's sitting.

**Proposed by this plan, for the owner's word.** Seven questions, Q1 to Q7, each with its recommendation (§4). The track below follows each recommendation, and says where. Each becomes a numbered decision, as written or as changed, when the owner answers.

**Rules carried from the earlier plans and `CLAUDE.md`.** Each is the owner's.
- **The queue is serial.** The next pull request is pushed when the owner has merged the one before. Auto-merge is never enabled.
- **One fresh session per pull request**, started from this plan and the row's issue numbers, and ended at the merge.
- **Small defects are fixed inline**, several related issues to one pull request, with one review pass on the diff.
- **Tests are scoped with `-only-testing` while developing.** Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- **Every heavy job goes through `Scripts/heavy.sh`**, one at a time on this Mac.
- **One index bump a build.** 1.0 (1861) carries versions 72 to 74 (decisions 117 to 119), and no row in this plan changes what indexing stores. A fix that would is a candidate for the release after 1.0 (§3): #1854 and #1909 are two.
- **No CloudKit schema change in 1.0.** A row that would add a `@Model`, or a stored property to one, goes after 1.0; the R-7 gate (`CloudKitSchemaInventoryTests`) catches one, and Production would need a deploy before the build ships.
- **Lanes edit the manuals** where they change what a manual describes, and leave the *AI Generated* notice (decision 94).
- **A test that pins specific language is an advisory reminder** (decision 9): the edit goes ahead, the test is brought to the new text in the same change, and the reason is written where the test is.
- **The web edition.** Sessions follow `CLAUDE.md`'s four rules. A row that changes shared code says so, runs `swift build --target FRUSCoreKit` and `swift test`, and, where its issue carries a hand-over note for FRUS Explorer Light, fills it in after the merge.
- **The EditableContent range gate stays exact** (`EditableContentKeyTests.everyRangedBlockHoldsItsKey`).
- **A finding is filed as an issue on the owner's word.** The review's findings that no row takes stay in §5 and in the review's record until then.
- **The freeze (Q2):** from R5's start until 1.0 (1861) is uploaded, `v2` takes only this plan's rows. Any other pull request waits for the upload, or becomes a row on the owner's word.

---

## 1. Track A — to App Store submission

| | Pull request | Issues |
|---|---|---|
| L15 | *Detected topics* renamed (Q6): the label the scope menus, Search's filters, the facet panel, Browse and the manuals give the Office's subject tags, and one caption in place of the five that explain them | #1905 |
| L16 | The cross-reference graph: the banner's count at two and three hops, the timeline's tick range below 116 pt, and the timeline kept through a relayout | #1892, #1893, #1914 |
| L17 | What App Review checks: a privacy-policy and support link inside the app, the Photos usage string, the in-app browser's reach, the Mac's print entitlement, and the review notes | review ASR-1, ASR-2, ASR-3, ASR-4, ASR-6 |
| L18 | Search says what it did: Filters' Done reruns the search, Facets' Apply where it can be seen, a result spoken to VoiceOver, an empty library named as the cause, 44-pt targets, and the Mac's matched words readable | review IPS-1, IPH-3, HCD-4, A11Y-2, IPH-5, A11Y-1 |
| L19 | Nothing the researcher wrote is lost without asking: the note editor, a collection row that holds the researcher's text, Add to Collection's confirmation, Open Document from the inspector, and the iPad's rail at compact width | review IPA-2, MAC-2, A11Y-3, IPA-4, IPA-6 |
| L20 | Downloads, the first run and Apple Intelligence say what is happening: the size on the device, Cancel All, a failed download shown with Retry, and why a summary is unavailable | review HCD-1, HCD-2, HCD-3, HCD-5 |
| L21 | The Mac's windows, a chart's lines and Browse's tile names: the main window's title, toolbars that fit their windows, numbered Research rows, the empty window's way in, comparison lines that differ by more than colour, and tile names Voice Control can say | review MAC-1, MAC-3, MAC-5, MAC-6, IPS-3, A11Y-5 |
| N1 | Where NARA's live answers put a record's record group, read from one lookup with the owner's key; a fix in the kit only if the lookup shows one is owed | #1908 |
| R5 | The release checklist on the frozen tree, the bump to the fourth TestFlight build, both TestFlight notes, and the retake sitting T2 for what the rows changed | — |
| R6 | The fourth TestFlight build uploaded, and the device pass: what changed since 1.0 (1812), the re-index a 1.0 (1787) library makes, and the 1812 pass still owed | — |
| R7 | The bump to 1.0 (1861) | — |
| R3 | The submission, 1.0 (1861) (decision 87) | — |

**The calendar** (Q1's, Q2's and Q4's recommendations). Each day's rows are serial, and a row starts when the one before has merged. The 2026-10-21 plan's L1 to L7, seven rows of this size, were built and merged in two days.

| Day | Rows | Who |
|---|---|---|
| Sun 2026-11-15 | This plan | the owner merges it, and answers Q1 to Q7 |
| Mon 2026-11-16 | L15, L16, L17; N1's lookup | sessions; the owner merges each and makes the lookup |
| Tue 2026-11-17 | L18, L19 | sessions; the owner merges each |
| Wed 2026-11-18 | L20, L21 | sessions; the owner merges each |
| Thu 2026-11-19 | R5: the freeze starts, the checklist runs, the tree goes to the fourth TestFlight number, sitting T2 retakes what the rows changed | a session; the owner archives and uploads that evening |
| Fri 2026-11-20 | R6, the device pass, in the morning; R7, the bump to 1861; R3: the website made public, the App Store Connect entry, the submission, the tag | the owner; a session for R7 |
| Sat 2026-11-21 | Slack: R3, if Friday's pass or entry runs long | — |

**If a day slips**, the rows give way in this order, each to the first update after 1.0: L21 first, then L20's S parts (Cancel All on the Mac, the failed download's line), then L19's IPA-6. L15 to L17, L18 and the rest of L19 and L20 stay: they are the owner's own issues, the store's checks, and the defects that mislead a researcher or lose their work. A defect R6 finds goes to a row on the owner's word; one that is not a crash, a loss of work or a store check may go to the first update instead, so that 1.0 (1861) keeps its week.

### 1a. Where each issue filed from 2026-11-09 to 2026-11-14 goes

| Issue | Goes | Why |
|---|---|---|
| #1905, *detected topics* → *tagged topics* | **L15, in 1.0** | The owner's own copy change: *detected* says the app does the detecting, and the topics are the Office of the Historian's tags, matched upstream by name. Copy only. The review found the same data under seven names; which one replaces *detected* is Q6. |
| #1892, the banner's count at two and three hops | **L16, in 1.0** | A graph opened at two hops, which the view model does by itself for a sparse graph (`CrossReferenceGraphViewModel.loadGraph`), shows the sentence #262 retired. One line in the kit (`CrossReferenceStore.expandedGraph`'s return, `FRUSCoreKit/CrossReference/CrossReferenceStore.swift:387`), read at `4a269a35`. |
| #1893, the timeline traps below 116 pt | **L16, in 1.0** | A trap is a crash in a release build. Nothing seen reaches it, and the iOS view sets no minimum width (§1's L16 asks the session to look for a layout that does). One clamp in the kit (`CrossReferenceGraphDisplay.swift:917`). |
| #1914, the timeline lost on a relayout | **L16, in 1.0** | A resize, an expanded cluster or a brushed range sends a graph whose dated nodes share one date back to the network layout. `timelineEligible` reads `displayNodes` (`CrossReferenceGraphViewModel.swift:163`), which `rerunLayout` replaces with the date-clustered set. App code. |
| #1908, NARA's record group on the ancestor | **N1, before R5** | Only a live answer settles it, and only the owner holds a key. If lots resolve, nothing in the app changes: the generator's note is corrected and the issue closes. If not, the fallback to the `recordGroup` ancestor is a small kit change, a row before R5 if it can merge by Tuesday, else the first update's. A reader without a key never meets it, and the App Review notes offer none. |
| #1910, the Mac export's index version | **After 1.0** | A line of text the web edition needs, and no reader of 1.0 is misled without it (FRUS Explorer Light refuses a mismatched export with a sentence that names both versions). Taken before R5 only on the owner's word. |
| #1907, #1912, #1913 | **After 1.0, web-authored, after the upload** | Kit parameters and cache keys only the web edition needs, each changing nothing the app does: #1913 only for a term spelt `occ:` and a word. Under the freeze they merge once 1.0 (1861) is uploaded. |
| #1911, boundary tests for the other kits | **After the upload, web-authored** | Tests only, so no binary moves; the freeze holds it to keep R5's runs and R6's tree the same. |
| #1909, the blob SHA of each indexed volume | **After 1.0, the owner's call** | An index-schema change, and 1.0 carries 72 to 74 (one bump a build). Whether it needs a version is that row's question. |
| #1915, Import from JSON on every platform | **After 1.0, the first candidate for the release after it** (§3) | A new feature that writes research into the synced store, on both platforms, with merge rules over seven format versions. It cannot be built, reviewed and device-passed inside the week without putting the submission at risk. Its kit half, the rules over values, changes nothing the app does, and can be built during App Review and merged after the upload. |

**The rows.**

- **L15, *detected topics* renamed** (#1905). One fresh session, one pull request. Copy only: no index version, no CloudKit change, and no kit code unless Related's *Shared topics* is renamed too (below); the kit's other mentions are comments.
  - **What the reader meets.** Every user-facing *Detected Topic* or *detected topics*, counted at `4a269a35`: the scope menus (`analytics.scope.bySubject` in `AnalyticsChartChrome.swift:543` and `SeriesScopeBar.swift:213`, `wordcloud.scope.bySubject` in `WordCloudView.swift:2446`, each with its *Detected topics — experimental* header), the word cloud's `Detected Topic` (`WordCloudView.swift:2182`), Browse's *Browse detected topics across the whole series* (`CorpusView.swift:353`), Search's *By Subject · Detected Topics*, *Filter by detected topic…*, *Filter by Detected Topic* and the explanation under it (`SearchFilterView.swift:955`, `:966`, `:1419`, `:1487`), and the facet panel's row (`FacetPanelView.swift:1116`). The keys stay; their `defaultValue`s change.
  - **The name is Q6's answer.** The issue asks for *tagged topics*. The review (§7) found the same data under seven names, and *tagged* would sit directly above the reader's own **Tags** in the rail and beside the volume page's editorial Tags. So the evidence there supports *Subjects*, the word the provenance chip, Facets, Top subjects and the person sheet already use. Until the owner answers, the session builds nothing that depends on the name.
  - **The sentences that explain them** say the topics are *detected*, *inferred from the text*, *automatically detected*, *experimental enrichment data* or *assigned*: five accounts. The data's own provenance (`Planning/Generators-Runbook.md`, `DocumentSubjectIndexGenerator`) is the Office of the Historian's subject export, which matches subject names and variants against the text, case-insensitively, before the app reads it. So one caption replaces the five, under either name, and the session puts its wording to the owner before writing it everywhere. For example: *Office of the Historian subjects, matched to the text by name, not chosen by the volume's editors, so some are wrong.*
  - **The other names** go with the choice. *Topics* (the rail, Browse), *Top subjects* (the volume page), *Shared topics* (Related, whose axis title is in `FRUSCoreKit/RelatedDocuments/SimilarityModel.swift`, so a change there owes `swift build --target FRUSCoreKit` and `swift test`) and *assigned topics* (the Topic index) take the chosen name or are left, as the owner says; the review's §7 lists each with its line.
  - **The mirrors:** both manuals (about 12 lines in the iOS manual and 14 in the Mac's, found with `grep -n -i "detected"`), the two `07-Search-and-Browse.md` blocks that hold the changed strings, one Amendment-Log bullet, the quick starts' web copies (`Docs/Website/quick-start-ios.html`, `quick-start-mac.html`, regenerated by `Scripts/build_website_pages.py`, whose `--check` must pass) and the website paste kit (`Planning/website-drafts/build_paste.py`). The owner re-pastes the quick-start pages in Squarespace (§2).
  - **Checks:** `EditableContentKeyTests`, `CodingStandardsAuditTests`, the unit target, the Mac build. **Captures:** the ledger shows no frame with a scope menu open or Search's filters on the Subjects row; the session reads the T1, R4 and S1 entries and the frames themselves to confirm, and lists any it finds for T2.
- **L16, the cross-reference graph** (#1892, #1893, #1914). One fresh session, one pull request: a commit for each issue, then a docs commit. Kit code (`FRUSCoreKit/CrossReference/`) and app code (`FRUSExplorer/CrossReference/`), so `swift build --target FRUSCoreKit` and `swift test` are owed; no index version, no CloudKit change.
  - **#1892:** pass `undownloadedCitingVolumeIds: base.undownloadedCitingVolumeIds` in `expandedGraph`'s return, drop the doc comment's paragraph on the gap, and pin it in `CrossReferenceHostTests` (the two-hop answer names the undownloaded volume, as the one-hop answer does).
  - **#1893:** keep the tick range's upper end at or above its lower one, as the issue's fix has it; on a canvas of 116 pt or more every tick is unchanged. A test lays the timeline out at widths 1, 50, 115 and 116 and at the sizes the app uses. Before choosing between that and drawing no timeline below the width, the session looks for an iOS layout that gives the canvas less than 116 pt (Slide Over, Split View, the smallest Stage Manager window, a phone in landscape with a sheet), and says what it found; the choice is the owner's if one does.
  - **#1914:** `timelineEligible` reads `baseDisplayNodes`, or `displayNodes` when the base is empty, as `rerunLayout`'s `sourceNodes` falls back; the toolbar's `.disabled(!vm.timelineEligible)` and the canvas's timeline branch are read again. A view-model test: a graph whose dated neighbours share one date lays out as a timeline, and still does after a resize and after its cluster is expanded.
  - **After the merge:** the hand-over notes in #1892's and #1893's comments, and the one in #1914's body, are filled in and filed for FRUS Explorer Light as each says.
  - **Captures:** `ipad/cross-reference-graph` is Network at three hops on d16, exactly where #1892's banner reads the retired sentence when a citing volume is not downloaded; the session reads the frame, and if its banner shows, the frame goes to T2. `macos/cross-reference-graph` (Timeline at 1 hop) is not expected to change.
- **The review's rows, L17 to L21.** Each row is one fresh session and one pull request, a commit for each finding, then a docs commit. Its brief is the review's section for it (`UI-UX-Adversarial-Review-2026-11-15.md` §2 and §3), with the evidence at `4a269a35`, the fix and its checks; the bullets below are what each row owes besides. Every fix is app code: none changes `FRUSCoreKit/`, so `swift test` is owed only if a row's diff names package input, and none needs an index version or a CloudKit change. A row that finds otherwise stops and asks. Each row's log entry lists the captures it changes, for T2 (R5), and the manual and `Docs/EditableContent` lines it moves, with one Amendment-Log bullet.
  - **L17, what App Review checks** (§2, and §3's row L17).
    - **ASR-2:** Privacy Policy and Support rows in About ▸ Legal, which both platforms share, and two items in the Mac's Help menu. They point at `https://frusexplorer.app/privacy` and `/support`, the entry sheet's addresses. `AboutLinks.allURLStrings`'s test takes them, and the EditableContent blocks that cite `AboutView.swift` and the Help menu are re-pointed.
    - **ASR-1:** `NSPhotoLibraryAddUsageDescription` in `project.yml`'s iOS `info.properties` and in `FRUSExplorer/Info.plist`, both by hand, with no `xcodegen generate`. Then the three paths checked on an iPhone 17 simulator under iOS 27.0 and 26.5, before the key and after, and the result recorded: Save Image from an exported figure, a reader figure's long press, an image in the in-app browser.
    - **ASR-3, on Q7's answer:** the in-app browser follows a link only on its opening page's host, and sends any other to the system browser. Under the other answer, the entry sheet's age rating says *yes*, and the code is unchanged.
    - **ASR-4:** `com.apple.security.print` in both Mac entitlements files; the owner then prints to a real printer from an AppStore-configuration build.
    - **ASR-6:** the review notes' onboarding step (`Store-Listing-Draft.md` §7, then `app-store-connect/build_paste.py`).
  - **L18, Search says what it did** (§3, row L18).
    - **IPS-1:** the Filters sheet's dismissal reruns the search when its signature changed, with §7.4 rewritten and a UI test; it is the one most worth a second reviewer's eyes.
    - **IPH-3:** Facets' staged Apply pinned to the sheet's foot, Done applying it, and the tip's block corrected.
    - **HCD-4:** an empty library's search names the library, with **Download Volumes…**; the downloaded-only filter's blank list takes the same state.
    - **A11Y-2:** the announcement after every search, with a case in `SearchResultVoiceOverTests` (`CLAUDE.md`'s row: iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`).
    - **IPH-5:** 44-pt hit areas by an outset content shape, with `SearchActionsBarFitTests` run on the iPhone 17 and the SE under `OS=27.0`.
    - **A11Y-1:** the Mac's matched words drawn as the reader draws a highlight. Its capture, `macos/search`, is the README's hero and the Mac's store frame 01, so T2 retakes it.
    - The row may split in two, iOS's sheets (IPS-1, IPH-3, IPH-5) and the rest, if one pull request runs long.
  - **L19, nothing lost without asking** (§3, row L19).
    - **IPA-2:** the note editor's change snapshot, its dismissal guard and its two dialogs.
    - **MAC-2:** the Delete Section dialog before a row that holds the researcher's text is deleted, on the Mac's trash and iOS's swipe alike, with each kind of row's tooltip.
    - **A11Y-3:** Add to Collection's announcement, and a different mark for *already there*.
    - **IPA-4:** **Open Document** in the inspector, on the iPad pane and the iPhone drill-in.
    - **IPA-6:** first the four-step simulator check; then the size-class gate, only if the check shows the sheet. If it does not, the row says so and the finding closes.
  - **L20, downloads, the first run and Apple Intelligence** (§3, row L20).
    - **HCD-1:** the corpus caption gains "about 13 GB once indexed" under its key, and T2 retakes `ipad/onboarding-volumes`. The owner's default and *Recommended* stay (C1, 2026-09-30) unless the owner says otherwise.
    - **HCD-2:** `DownloadManager.cancelAll()` from Reset This Device, Erase Everything and Back on the Ready step, and **Cancel All** in iOS's Active Downloads and on the Mac hub's status line. The Mac's full Active Downloads list is after 1.0.
    - **HCD-3:** a volume's last failure shown with **Retry** and announced, kept in memory or `UserDefaults`, never on a `@Model`.
    - **HCD-5:** one helper over `SystemLanguageModel.default.availability`, used at all seven sites.
  - **L21, the Mac's windows, a chart's lines and Browse's tiles** (§3, row L21).
    - **MAC-1:** the main window's title, its centre label as the standalone window's, and the quick start's line.
    - **MAC-3:** the Search and Corpus Analytics windows' default widths, measured on a Mac to fit their toolbars and pinned by a test as #1378 pinned the Archives Visits window.
    - **MAC-5:** the Research rows' document numbers.
    - **MAC-6:** the empty window's buttons and hint.
    - **IPS-3:** `.lineStyle(by:)` or `.symbol(by:)` on the comparison lines.
    - **A11Y-5:** the tiles' input labels, checked once with Voice Control.
    - Captures for T2: `macos/toolbar`, `macos/research-strip`, `macos/research` and `ipad/analytics`.
- **N1, NARA's record group** (#1908). The owner's lookup and, if owed, a session.
  - **The owner's step, on the Mac with the key (Settings ▸ Connections):** a lot lookup the bundled indexes resolve, a D-designator lot in RG 59, in Source Explorer. Then one of two:
    - it resolves: say so on the issue. A session corrects the note in `RecordGroupCatalogGeneratorCore/CatalogRecordModels.swift` (`CatalogAncestor`) with the live answer's shape and closes the issue (generator code only; `swift test`).
    - it finds nothing: a session captures the raw `/records/search` answer with the owner (the key and every header removed), keeps it as a fixture, and has `NARACatalogClient.buildResult(from:)` fall back to the `recordGroup` ancestor after the record's own fields, as the issue's steps say (kit code: `swift build --target FRUSCoreKit`, `swift test`). It is a row before R5 if it merges by Tuesday evening; else it goes to the first update, and the App Review notes, which offer no key, need no change.
- **R5, the release checklist and the fourth TestFlight build.** One fresh session from `v2` when every row above has merged; the freeze starts when it does (Q2).
  - **Two things the checklist would stop on, fixed first, test code only:**
    - **The third warning line.** A clean `build-for-testing` has printed three warning lines since Lane 2 (#1875): the two known residues and `FRUSOffsetEngineTests.swift:2736`'s ambiguous `#require(… as? Bool)` (L11's session found it; every session since counts "`v2`'s 3 warning lines"). The checklist allows the two residues and nothing else, so the value is read first and the cast required after (`:2736`, and `:2753`'s twin if it warns).
    - **The one failing test under iOS 27.2.** Every full unit run on an iOS 27.2 simulator since 2026-11-10 fails `CrossReferenceRankingLabelsTests`' *At 720 pt every row's title is drawn* (`FRUSExplorerTests/CrossReferenceRankingLabelsTests.swift:846`), which reads the rendered chart back with Vision; under iOS 27.0 it passes (R2c's run, 7,934 tests, none failed). The test prints what Vision reads. The session runs it on both runtimes, reads the two outputs and the rendered image, and settles which is at fault: if the chart draws a title cut or blank under 27.2, that is an app defect on the system readers have, and it is fixed in the chart; if Vision reads a whole chart differently, the test's reading is widened, as it was for iOS 27.0 (its comment on the count Vision read as *m-*), with the reason beside it.
  - **The checklist**, as R2 and R2b ran it, each figure against R2b's (`Completed/Plan-Of-Record-2026-10-21.md` §1):
    - a clean `build-for-testing`, read for warnings: the two known residues and nothing else;
    - the full unit target on iPhone 17 under **iOS 27.0 and iOS 27.2** (Q5): none failed. R2b had 7,864 tests in 942 suites; the sessions since `build-53` count 8,012 in 963 on 27.2;
    - `swift test`, owed since `build-52` for the kit moves (#1891 onward): R2b had 3,267 tests in 394 suites; #1916's session had 4,512 in 532;
    - the Mac build, and a walk of the Mac check copy that opens what changed since 1.0 (1812): Source Explorer on `frus1952-54v02p1` d41 (#1894's resolution); a Most-Referenced chart's bar and the graph at two hops and on its timeline (#1891, L16); Corpus Analytics' **View N documents ↗** over Kennedy's years (#1896); Person Analytics' co-mention network, Chronology and About the Series (#1899); a word cloud in two lenses with Distinctive sizing (#1900); Archival Analytics' rankings and network (#1901); the person sheet's lifespan, Career and Subjects, and a scope bar's renamed topics (#1906, L15); `frus1961-63v06`'s index and contents in the reader at Small and Medium, the contents line *Kennedy-Khrushchev Exchanges*, `frus1873p1v1`'s *See* reference *De Long* and `frus1964-68v12` d238's *Bill Martin* (#1898, #1902, the taps of Mac check 27); and every row's own surface;
    - the window-fronting audit (R2b: 80 / 2 / 34 / 0, 20 scenes, 23 `openAuxWindow` sites);
    - the link check in report mode (R2b: 19 OK and 3 owner-asserted, NARA's page answering 502 that night and 200 the next morning);
    - the dSYM fetch and `./Scripts/check_cloudkit_schema.py` (R2b: PASS, 268 of 272 identifiers required, Production 310). No `@Model` file's stored properties changed since `build-52`, read by `git diff build-53..v2 -- FRUSExplorer/Models/`: the changes moved nested value types into the kit;
    - **the re-index census at version 74**, owed since R2b counted 71: decisions 117 to 119 ask the release that carries 72 to 74 to count its re-index, as A19 counted 71's.
  - **The bump** to the fourth TestFlight build: a number between 1812 and 1861, the owner's to name as 1776, 1787 and 1812 were (Q1). `CURRENT_PROJECT_VERSION` in `project.yml`'s three targets and every occurrence in `project.pbxproj` (`replace_all`), the README's line and its mirror in `Docs/EditableContent/03-Repository-README.md`, and an Amendment-Log bullet, by `CLAUDE.md`'s procedure, with no `xcodegen generate`.
  - **Both TestFlight notes** rewritten for that build, each 4,000 characters at most by Python's `len()`, with ⚙, ✕ and ⓘ written as words (#1783): for a tester who has 1.0 (1812), and for one who has 1.0 (1787), whose library re-indexes once at launch. What changed since 1812, from the rows above; every fix in the one line, as the owner's rule for these notes has it; what to test, from R6's list. The new behaviour a tester should look for:
    - the Privacy Policy and Support rows in About;
    - Search's Filters applying on Done;
    - Cancel All;
    - a failed download's Retry;
    - the Mac's window titles.
  - **Sitting T2, the retakes** (decision 88): every committed capture a row since `build-53` changed, read from each row's log entry and from #1898's and #1902's (whose entries list none), retaken by the ledger's conventions (`Docs/screenshots/README.md`), each diffed by pixel against the frame it replaces.
    - **Expected from the rows' briefs, about seven frames:**
      - `macos/search` (A11Y-1), which is the README's hero and the Mac's store frame 01;
      - `ipad/onboarding-volumes` (HCD-1);
      - `ipad/analytics` (IPS-3);
      - `macos/toolbar` and `macos/research-strip` (MAC-1);
      - `macos/research` (MAC-5).

      Each row's entry confirms or adds to the list.
    - **Then** `tools/marketing/compose.py` with `SCALE=1 STAMP=0` for every store frame a retake feeds (the Mac's 01 at least), into `~/Desktop/store/upload/` in the listing's order, and the drafts rendered again. The quick starts' web copies load the captures from the default branch, so a merged retake shows there unaided.
  - **The records 1861 reads:** `Planning/app-store-connect/App-Store-Connect-Entry.md` says 1.0 (1861) is "taken to be what 1.0 (1812) … already does"; it now says what 1861 adds. `Store-Listing-Draft.md` and the paste kit are read against the frozen tree, as the 2026-11-10 session read them against 1812; the website drafts too, since L15 changes a sentence of the quick starts (#1888's condition: "Should 1861 take a change after all, the pages are read against it again").
  - **The owner's steps**, in the checkout the archive is cut from: bring `v2` to R5's merge; run `./Scripts/fetch-llama-dsyms.sh` and `./Scripts/check_cloudkit_schema.py` there; archive and upload `FRUSExplorer` and `FRUSExplorerMac` in the AppStore configuration, each with its note as What to Test; tag the commit (`build-54` would follow the others; decision 113 leaves it to the owner).
- **R6, the device pass** of the fourth TestFlight build, on an iPhone, an iPad and the Mac. The owner's.
  - **A library that had 1.0 (1787) or earlier**, so the one re-index to 74 is seen (decisions 117 to 119), and **one that had 1.0 (1812)**, which re-indexes nothing: this folds in R2c's device pass, still owed (`Completed/Plan-Of-Record-2026-10-21.md` §4).
  - **What changed since 1812:** R5's Mac walk, on the iPad and the iPhone too; and, on iOS, a queue left to index while the app is away (L11 to L14, which 1812 was the first to carry).
  - **Each row's own surface**, from its log entry, and the review's checks that only a device can make (its §6), where the device is at hand:
    - the Lock Screen during a queue (IPH-7);
    - a queue's end on an iPhone (IPH-8);
    - onboarding at AX3 and AX5 on a small iPhone (IPH-9).
  - **On the Mac:** File ▸ Print to a printer (ASR-4), if L17's own check did not reach one.
  - **If the iPad is an iPad mini on iOS 27:** a search field with the keyboard up on the Browse root, for #1835, which fails only in the iPad mini simulator under 27.0.
  - **A defect the pass finds** goes to a row on the owner's word, and the next upload takes a number above the fourth build's and below 1861, with the calendar's Saturday as its slack. One that is not a crash, a loss of work or a store check may go to the first update instead (§1's calendar).
- **R7, the bump to 1.0 (1861).** One session, one pull request, when R6 has passed: `CURRENT_PROJECT_VERSION` 1861 by the same procedure, the README line and its mirror, an Amendment-Log bullet, and both TestFlight notes' release-candidate line. No other change: the tree that goes to App Review is R6's but for its build number.
- **R3, the submission.** The owner archives and uploads 1.0 (1861) for both platforms, opens it once from TestFlight (About reads *Version 1.0 (1861)*), and submits it with §2's answers; then tags that commit `1.0-release` (decision 113).

---

## 2. Submission — what only the owner does

The repository holds a draft for each.
- **The website.** Make frusexplorer.app public, with `/privacy` and `/support`, on the day of the submission: App Review opens both addresses, and every path answered 401 on 2026-11-10. The six pages and the footer are entered and hold their current files (`website-drafts/Squarespace-Entry.md`); L15 changes the two quick-start pages, which the owner pastes again from `website-drafts/paste/` after L15 merges.
- **App Store Connect**, page by page in `app-store-connect/App-Store-Connect-Entry.md`, each text field ready to paste in `app-store-connect/paste/` and each screenshot slot in `~/Desktop/store/upload/<preset>/` (ten iPad, ten Mac, five iPhone, and the iPhone's five again at 1206 × 2622). R5 brings the sheet's description of 1861 up to date. The sheet's four decisions are the owner's (§4): the age rating (13+ as drafted, which Q7's recommended answer keeps true by limiting the in-app browser, or 16+), the trader status under the Digital Services Act, whether China mainland stays among the storefronts if a filing number or permit is asked for, and a manual release (recommended). And its two offers: `relations` for `FRUS` among the keywords, and the home page's Editors' Annotations sentence in the description.
- **`check_repository_links.py --stamp`**, which writes the owner's confirmation date.
- **The archives, the uploads and the tags:** the fourth TestFlight build (R5, R6) and 1.0 (1861) (R7, R3), `1.0-release` on the second.

---

## 3. After submission

- **The website's pages** (decision 101), while App Review runs and before release: generate the home page and the tour in their coming-soon versions, review every figure against 1.0 (1861)'s bundle and every screen against the submitted build, revise, and publish; on release day the home page and the tour switch to their launch versions with the App Store badge. Still owed from 2026-11-10: the fold of the two plain-language drafts into `Docs/Support.md` and `Docs/Privacy-Policy.md`, on the owner's word; the reading level; captures for the tour's steps 19 and 20.
- **The release after 1.0: its candidates.** Its order is the next plan's.
  - **#1915, Import from JSON on every platform** (§1a): first, since the owner asked for it on 2026-11-14 after setting it aside on 2026-10-23. Its issue's two pull requests: the kit's rules, then the screen.
  - **#1723, A7: App Intents and Siri**, with A7b's Spotlight association; the owner's device check with Spike Reader decides A7b's place (`App-Intents-Siri-Assessment-2026-10-18.md` §4 and §5).
  - **#1854**, 138 editorial-note documents with no source note, dateline or provenance stored: an index version.
  - **#1909**, the blob SHA of each indexed volume: the owner's call on the proposal, then its index-version question.
  - **#1910**, the Mac export's index version, unless taken before R5.
  - **The web edition's kit rows**, #1907, #1911, #1912 and #1913, web-authored, merging once 1.0 (1861) is uploaded.
  - **The review's findings no 1.0 row takes** (§5, *Found by the review*), each filed on the owner's word.
  - **Carried from the 2026-10-21 plan's §3:** six cross-volume references by id to a section's row, missing from the bundled edge index (A18b); the two Archival Neighbors readers disagreeing on a class key no note carries (A19); a volume whose indexing is cut short marked nowhere until the next launch (A14); the Archives Visit labelling lot targets by their first document (A15); Search's cost (`Issue-1648-Stopping-A-Replaced-Search-2026-10-15.md` §6: an exact-word search for a common word holds the pipeline for about two minutes, most of a Mac search's time is the snippet pass, the default scope's user-content union costs a common word's count about 0.3 s).
  - **An owner device sitting:** the Topics lens on an iOS 27 device; one Audio Graph heard aloud; the Mac's Sync Log after a sync; the Mac Search window with a selection under VoiceOver, in dark appearance and with Full Keyboard Access; Text Color's picker on an iPad under iOS 27; the by-eye checks carried from builds 48 and 49 (`Completed/Plan-Of-Record-2026-10-14.md` §4). The review's record lists the checks only a running app can settle; they join this sitting.
- **Accessibility Nutrition Labels.** Voluntary at 1.0, and to be required for new submissions later (`App-Store-Connect-Entry.md`, *Not required now*). Answering one means walking every common task with that feature on; the review's accessibility findings are the starting list.

---

## 4. Waiting on the owner

**The seven questions** this plan proposes answers to (§0). Each recommendation is what §1 follows until the owner answers.
- **Q1. How 1.0 (1861) is reached.** *Recommended: a fourth TestFlight build, its number the owner's between 1812 and 1861, carries the frozen tree for R6's device pass, and R7 bumps that same tree to 1861 for the submission.* The alternative, uploading 1861 to TestFlight first and submitting it after the pass, tests the exact binary but spends 1861 on the first defect the pass finds, and decision 25 makes 1861 the submission's number. Either way 1861 is cut from `v2`, with what has merged since `build-53`; a release branch from `build-53` would leave the web edition's moves and #1916's fix out, and this repository has never cut one.
- **Q2. The freeze.** *Recommended: from R5's start until 1.0 (1861) is uploaded, `v2` takes only this plan's rows.* Web-authored pull requests (#1907, #1911 to #1913, and the hand-overs' follow-ups) merge after the upload. The alternative lets test-only pull requests through, at the cost of a tree that moves between R5's runs and R6's archive.
- **Q3. The twelve issues** (§1a). *Recommended: #1905, #1892, #1893 and #1914 in 1.0 (L15, L16); #1908 settled by N1's lookup; the other seven after 1.0.*
- **Q4. The review's findings** (`UI-UX-Adversarial-Review-2026-11-15.md`). *Recommended: its 2 S1s and 23 S2s go in 1.0 as rows L17 to L21, in that order, with §1's rule for a day that slips (L21 gives way first). Its 37 S3s go to §5.* Each row's findings may also be filed as one issue labelled *before App Store submission*, as #1756 to #1763 were, so that each row's issue body is its brief; the plan works from the review's sections either way.
  - **Why the S2s, and not only the S1s:** each is XS or S and app code only. Together they are what a first-time researcher, or a reviewer trying the app for ten minutes, would meet first: a filter that says it narrowed and did not, a note lost to a swipe, a download that cannot be stopped or fails without a word, a first Mac window with nothing to click.
  - **The cost:** five more pull requests before the checklist, and a T2 sitting of about seven frames (§1, R5).
- **Q5. iOS 27.2 in the checklist.** *Recommended: yes.* App Review uses current systems, the sessions since 2026-11-10 ran their unit targets on iOS 27.2 simulators, and one test fails only there (R5). The checklist ran on iOS 27.0 alone until now.
- **Q6. The name that replaces *detected topics*** (L15, #1905). *The owner's word decides; the review recommends* Subjects. The issue asks for *tagged topics*. On the rail, *Tagged* would sit directly above the reader's own **Tags**, and beside the volume page's editorial Tags. *Subjects* is the word five surfaces already use. Either way, one caption replaces the five accounts of where the data comes from (the review's §7).
- **Q7. The in-app browser and the age rating** (L17, the review's ASR-3). *Recommended: the browser follows links only on its opening page's host and sends the rest to the system browser, so the rating's* Unrestricted Web Access: no *is true and the rating stays 13+ as drafted.* The alternative is to answer *yes*, which rates the app 16+ and changes no code. The other age-rating items stay as the entry sheet drafts them, the owner's declaration.

**Carried:**
- **The submission's entry** (§2): the four decisions and two offers in `App-Store-Connect-Entry.md`.
- **The website**: made public on the day of the submission; the word on the two plain-language drafts; whether the home page and the tour become copies of record.
- **R2c's device pass** of 1.0 (1812), which R6 takes (§1).
- **For #1767**, closed: whether to file the three reports drafted in `Person-Authority-Upstream-Reports-2026-11-01.md` with `HistoryAtState/people`.
- **The asterisk rows** (`Editors-Annotations-Followups-2026-11-08.md`, Lane 0b): whether a row of asterisks, the editors' mark of an omission before the 1925 order, counts as a third form of marked omission. `FRUS-History-Feature-Assessment-2026-11-09.md` §2.4 proposes a census for the plan after 1.0.
- **For A7** (#1723): the device check with Spike Reader (`App-Intents-Siri-Assessment-2026-10-18.md` §4).
- **App Previews** for a later update (decision 89): recordings A, R and T are kept outside the repository.
- **The manual review**, after 1.0 (decision 94): `Manual-Revisions-Pending.md` and `Manual-Update-Build-49-Owner-Review.md` are its inputs.

---

## 5. Backlog, parked, deferred and closed

The 2026-10-21 plan's §5, with what has been fixed since left out (the ASCII fast path, #1771; the Mac's volume hand-off, #1779; the guide's figures, v1.37), and the review's findings that no 1.0 row takes.

### Found by the review, 2026-11-15 — after 1.0 unless a row takes one

The review's 37 S3 findings, less ASR-6, the review notes' wording, which L17 takes since it costs nothing. Each of the other 36 has its evidence and size in the review's §4, and the 7 that need a running app to settle have their checks in its §6. Each is filed as an issue on the owner's word, or declined. In brief:
- **iPhone:**
  - IPH-6, the sync banner at accessibility sizes on a small iPhone;
  - IPH-7, the Lock Screen Live Activity's count;
  - IPH-8, the end-of-queue card;
  - IPH-9, onboarding's dock at accessibility sizes;
  - IPH-10, the banner's word cloud under Increase Contrast.
- **Search and analysis:**
  - IPS-2, captions in tertiary grey and orange (with IPA-8);
  - IPS-4, the match percentages, unexplained in the app;
  - IPS-5, Clusters' and the map's three names for one group;
  - IPS-6, Corpus Analytics' explanations in `.help` only;
  - IPS-7, Archival Analytics' "list below".
- **Reading and organising:**
  - IPA-1, the downloaded-only filter's glyph (its empty state goes with L18);
  - IPA-3's whole-collection Sort;
  - IPA-5, next and previous with the rail open;
  - IPA-7, the rail header's and tag chips' small targets;
  - IPA-9, two empty states;
  - IPA-10, ⌥⌘F on iPad;
  - IPA-11, three stacked sheets;
  - IPA-12, the sidebar's project rows;
  - IPA-13, "Adds all 0 generated summaries".
- **Mac:**
  - MAC-4, the reader's 136% ceiling and no ⌘+/⌘− (with the accessibility sweep's reader item);
  - MAC-7, the reader's verbs, Back and Forward, and Help ▸ User Manual in the menu bar, and ⇧⌘P and ⇧⌘A;
  - MAC-8, Escape on the person and gloss sheets;
  - MAC-9, the toggles' state for VoiceOver;
  - MAC-10, Settings' last pane;
  - MAC-11, the inspector's Done;
  - MAC-13, the main window over Search;
  - MAC-14, two alerts on one error.
- **Cross-platform:**
  - ASR-5, `drawsBackground`;
  - A11Y-4's silent highlight;
  - A11Y-6, the rail's accordion state;
  - A11Y-7, the Research tab's rows by keyboard;
  - A11Y-8, removing a highlight without pointing;
  - HCD-6, the seven names (L15 takes its labels; its captions follow Q6);
  - HCD-7, the iCloud wording;
  - HCD-9, the Research Guide at every launch during a queue (#757's choice);
  - HCD-10, a long summary's spinner.

### P2 — later

- **Generators:** provenance flows count no page reference (`RefDestination.citedDocument` is nil for a page).
- **Section vectors**, at the next vectors generation (decision 61).
- **A second question for the Agentic Analysis Guide's model table** (§3a; decision 115), under a budget line the owner sets and decision 115's guard.
- **Found by #1764's session, unfiled:** a graph of 1,259 nodes cannot be read on an iPad canvas under any layout tried, so clustering or a cap on what three hops draws is a design question; what a label carries is the owner's call; the reference-list toggle opened nothing on two taps on the iPad.
- **Found by the summarization sessions, unfiled:** a chunked summary's synthesis keeps too little of the document (#1820); a model that declines may write its refusal as the answer (#1820); no device and no iOS 26 system measured for the 4,096-token window (#1825, #1827); the app not run with #1827's retry.
- **Found in R2b's walk, unfiled:** where a collection names no summary prompt, an entry's AI summary row in the inspector, and the headnote it would draft, show the first summary the store returns, while the reader's rail shows the newest (`CollectionEntryInspector` and the content resolver's fallback).
- **Found in T1, unfiled:** two subseries that begin in the same year sort differently from launch to launch (`BrowserViewModel.allSubseriesGroups` sorts by start year alone over a `Dictionary`'s order).
- **Found in R4, unfiled:** on the iPad, a Collections row opens only where its text is (`CollectionRow` has no full-width content shape).
- **Smaller app items:** `ProjectLeadsService` ranks with no year; `datesByDocumentKey(_:)` scans every `document_dates` row; the archival chip is cut on the iPhone 17; Sync Diagnostics' Clear Log draws its trash icon in the accent colour; a phrase can match across a document's heading and its form marker; a question's keyword snippets cost more since #1760 (the UTF-8 scan unbuilt); a number typed with a mark (`1945.`) searches nothing and nothing says so; a hyphenated word or an `=` word never anchors a snippet; a page link into a volume on the device whose page names no document does nothing (608 of 48,577); under iOS 26.5 in Stage Manager a popped-out document's rail draws black until the window moves.
- **The 2026-09-27 audit, unfiled:** Facets is disabled in Meaning mode on iPhone and iPad, where the Mac offers it; the reach scan and the leads count second-edition reprints; Archives Visit derivations go stale when a volume updates.
- **Test infrastructure:** `RichTextRestingCapTests` on an iPad host; two UI suites need the Research rail open, which a simulator can hold closed (A12); the iOS 26.5 runtime has no English lemmatiser; **#1835**, the tab shell's banner staying up with the keyboard in the iPad mini simulator under iOS 27.0, whose suite's row stays on 26.5 (R6 checks a device if one is at hand).
- **#1608:** how often an iOS 27 device launches without the lemmatiser.
- **Hygiene:** `FilterChip` and `CrossProjectNoteIndicator`, the two views nothing constructs; 14 Swift files outside every target with no license header; nine Swift files citing #1210, #1211 or #1257 where the work merged as #1250, #1251 and #1256; the HYG and READ leftovers (`Completed/Plan-Of-Record-2026-10-14.md` §6f).
- **Marketing**, from the Visual Marketing Plan: step 5 (the publication-lag plate), step 13 (Plate B) and step 16 (after launch).
- **Accessibility, a sweep of its own:** `AXChartDescriptor` for four chart families; Differentiate Without Color on the map; about 37 text sites with a fixed size; a reader that follows the system text size; the iPad rail toggle's `.isSelected` trait; at the largest text size on an iPhone, Collection settings' row and the Local Only banner's button. The review's accessibility findings (above) join it.

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
- **#1696**: waits for the Office's subject export to reach Document 946 (decision 71).
- **For the corpus to fix:** `frus1945Malta/d273`'s year, 1945 by `@when` where its dateline says 1944.
- **For HistoryAtState/people to fix:** the registry's own merges (Stevenson, Wilson, Fish), its duplicate records (Rowan, Regan, Tran Buu Kiem) and Sir Oliver Wright's two missing anchors; the three reports are drafted and not filed (§4).
- **New volumes**, whenever the Office publishes, by `New-Volume-Release-Plan.md`.

### Closed or declined

- **Closed under the 2026-10-21 plan:** #1690, #1691, #1620, #1767, and every issue its rows fixed (#1756 to #1766, #1796 to #1799, #1823 and #1856). L10 to L14 fixed findings that were not filed (#1873 and #1879 to #1883 are their pull requests).
- **Left as it is:** the method appendix's plain-text line, the record of what was typed (decision 86).
- **Declined:** W12's parallel editions, W14, the MCP server and `CSUserQuery`; the cross-platform review's unfiled leftovers (decision 93), which the 2026-11-15 review did not re-raise.

---

## 6. The documents, as this change leaves them

- **New:** `UI-UX-Adversarial-Review-2026-11-15.md`, the review's record: its method, every finding with its evidence and the skeptic's verdict, and what it found sound. It stays live until its 1.0 rows merge and its backlog is filed or declined.
- **Moved to `Completed/`:**
  - `Plan-Of-Record-2026-10-21.md`, marked SUPERSEDED in its head: the record of decisions 84 to 125, L1 to L14, R1 to R4 with R2b and R2c, G1 and V72 to V74;
  - `Planning-Review-2026-10-21.md`, the review that plan was written from, decided the same day and cited by no code, test or tool.
  - The live documents that pointed at either now point there, or at this plan where they meant the live one: `Completed/README.md`, `Visual-Marketing-Plan.md`, `website-drafts/README.md`, `Cross-Platform-UI-Adversarial-Review/STATUS.md` and `Docs/Agentic-Analysis-Guide.md`'s two citations. Dated records were left as written: `DEVELOPMENT-PLAN.md`'s entries, the archived plans' bodies, and the dated memos and results at the Planning root.
- **Kept live**, as the 2026-10-21 plan's §6 left them: the runbooks; the original specification; the session log; `New-Volume-Release-Plan.md`; the Visual Marketing Plan, the launch kit, the listing draft, `marketing-drafts/` and `app-store-connect/`, until submission; `website-drafts/`, until the pages are published (decision 101); the two manual-review documents, until the review; the A7 design, until its work runs; the person-authority identifier assessment (marked complete, cited by code) and the upstream-report drafts, until filed; #234's documents (decision 92); `Editors-Annotations-Followups-2026-11-08.md` (marked complete, cited by code); the generator output folders.
