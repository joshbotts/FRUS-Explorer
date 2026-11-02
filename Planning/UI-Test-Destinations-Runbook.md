# UI test destinations runbook

Which simulators each UI suite needs, what it measured, and the commands. `CLAUDE.md`'s *Build &
Test Commands* section holds the index (suite, devices, expected counts) and the five rules that
hold for every UI run; this file holds each suite's full entry. The entries were moved here from
`CLAUDE.md` word for word on 2026-10-09, so that a session loads them when it needs one and not
with every request. Add a new suite's entry here, and its row to the index.

**Run the UI obstruction suite on an iPad destination** (scenario 4 covers the iPadOS
`.sidebarAdaptable` floating-top-tab-bar overlay, #238; it self-skips on an iPhone
destination — any installed iPad simulator works; check `xcrun simctl list devices available`):
```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -only-testing FRUSExplorerUITests/UIObstructionTests
```

**`BrowseNestedSectionTests` (#1301) must run on BOTH an iPad and an iPhone, and one destination
gives you only one idiom's layout tests.** The suite self-skips on the wrong idiom in both
directions: `testNestedSectionsLoadInTwoPane` needs a pad idiom *and* 820 pt of content width (it
skips on any iPad below the two-pane gate, naming the width it measured), and
`testNestedSectionsLoadOnPushPath` — the non-regression control for the `.navigationDestination`
path — needs a phone. Each reports the other as a **skip**, not a pass. **Round 3 adds a THIRD
iPad-only test**, `testASecondVolumeFromRootSearchLoadsItsOwnStructure`, which walks
`.volume → .volume` from the corpus root's search; it skips on a phone with the other two-pane one.
The **four** round-2 tests (the failure row and its Retry, the in-flight spinner, the cold-index
kick, the late-pipeline kick) and round 4's **fifth** (the progress kick, driven by finishing the
cold fixture's download while its compilation is open — the only loader on the download → open →
browse path) are idiom-agnostic and run on whichever destination you give it — the in-flight one is
the test that kills the pre-load-drawn-as-rows mutant, so a run that reports it missing has lost
the guard, not a spare. **#1363 adds three**: `testLevelStateSurvivesBackInTwoPane` is the guard —
the root's own search left for a document, then Archives (a closed era, a lens switch that must
EMPTY the collection search, the collection search, a collection's Show-all list left for its sixth
volume), All Volumes and Editors, each left and returned to with Back. It needs the iPad two-pane
IN PORTRAIT, which it sets (a document takes the list pane down only under 1100 pt), so on an iPad
Pro 13-inch it needs the tabs as a floating bar: with the tab sidebar showing — it persists per
install — portrait is under the 820 pt gate and the test skips like the reproduction, naming the
width. `testLevelStateSurvivesBackOnPushPath` walks the same levels on a phone as the control,
which passes with or without the per-level memory; only its lens-switch step can fail, that rule
being the same in both layouts. `testLevelStateSurvivesTheTwoPaneGate` carries the root's search
and a narrowed Archives across the 820 pt gate and back, so it needs an iPad whose portrait is below
the gate: **iPad mini**. On the iPad Pro 13-inch portrait is already two panes and it skips, naming
the width. Both iPad tests put the device back in the orientation they found. Expect **11 tests
with 3 skipped on iPad Pro 13-inch** and **11 with 4 skipped on iPhone**, so the honest pair is the
first two commands; the third is the gate. Measured on iOS 26.5 and on iOS 27.0 (the iPad Pro
13-inch suite, the phone's control and the gate on iPad mini, each with the flags below):

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 1500 -maximum-test-execution-time-allowance 1500 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad mini (A17 Pro)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests/testLevelStateSurvivesTheTwoPaneGate
```

**The late-pipeline test and the progress test release their seams themselves** (2026-10-11). Each
used to hold its seam back for a number of seconds counted from launch, 25 for the pipeline and 30
for the seeded download, and then check the screen it expected to find in the meantime. On iPhone 17
(iOS 27.0) the walk to the compilation took 46 to 50 seconds that day, each query 2 to 3.5, so the
pipeline had attached and the volume was indexed before either test looked, and both failed on their
own premise, on `v2` @ `af64ceae` as on a branch. Now `FRUS_UI_TEST_HOLD_PIPELINE=1` and
`FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL=1` hold each seam until the test posts a Darwin
notification (`notify_post`, which crosses from the runner to the app in one simulator), and each
test posts it once it has seen "Search Index Unavailable" or "Index Required". `BrowseSeamSignalTests`
(unit target) holds the names the two sides share. **Give the suite 600 seconds a test on the
iPhone, not 300, and 1,500 on the iPad:**
`testLevelStateSurvivesBackOnPushPath`, the phone's control, took 368 and 358 seconds in two runs
that day, the second with the load average under 8, so the 300 the commands above used to pass
ends it as a failure with no assertion failed.

**The suite's walk opens the fixture's own subseries, by name** (2026-10-11). It launches with
downloaded volumes only and used to tap the first row labelled "Subseries". The UI-test app shares a
simulator's volumes with every other run on it, so a simulator that holds a real volume lists more
than one subseries: on an iPad Pro 13-inch (iOS 27.0) holding `frus1964-68v01` and `v02`, the first
match was "Subseries 1964-68, 35 volumes" and the test failed one step on, with "The seeded volume's
row did not appear in the subseries list". An iPhone 17 under iOS 26.5 that held another session's
volumes had failed with the same message that afternoon. The walk now asks for "Subseries 1961-63".

**Since A12 (#1694, 2026-10-20) every walk to the fixture volume names its subseries the same way**:
`CompilationDocumentsTests`, `TwoPaneDocumentTests`, `BrowseRootSelectionTests`' Continue reading
test and `AuxWindowCloseTests`' Research rail cases. Three queries still take the first subseries
row, and need no more: `UIObstructionTests`' row, `AuxWindowCloseTests`' launcher mark and
`BrowseRootSelectionTests`' first test. None depends on which subseries its row belongs to, and their
launches do not narrow Browse to downloaded volumes, so the simulator's volumes do not change which
row comes first. The iPad Pro 13-inch (M5) under iOS 27.0 (`9AB3A0C9`) still held `frus1964-68v01`
and `v02` beside the fixture on 2026-10-20, so the code before A12 misfires there in all four walks:
each opened "Subseries 1964-68, 35 volumes" and failed one step on, at the fixture volume's row.

**A typed search is waited for in its field** (2026-10-11). `typeSearch` read the field in the
statement after `typeText` and, on the iPad Pro 13-inch (iOS 27.0) with another job running on the
Mac, got "Bator Pape" where "Bator Papers" had been typed: `testLevelStateSurvivesBackInTwoPane`
stopped on that precondition. The read now waits up to 30 seconds for the field to hold the text.
**On the iPad that test needs more than ten minutes now, and one flag does not give it them.** Run by
itself on that iPad the same evening, with the load average under 7, it passed in 677 seconds. A test
gets the DEFAULT allowance, 600 seconds, whatever `-maximum-test-execution-time-allowance` says above
that: it was ended at ten minutes twice, still walking, once with the maximum at 600 and once with
the maximum alone at 1,500 ("exceeded execution time allowance of 10 minutes"). Pass
`-default-test-execution-time-allowance` with it, as the iPad's command above does. (A maximum under
600, like the 300 other entries pass, does cap.)

**`TopicIndexArrivalTests` (#1365) must run on an iPad two-pane AND an iPhone. It never skips, so
either destination alone reports green.** Its guard for the iPad's Back,
`testBackFromAVolumeKeepsTheAreaAndTheSearch`, works only in Browse's two-pane. There a covering
volume opened from a topic's sheet replaces the Topic index, and Back mounts a new one. A phone's
navigation stack keeps the index alive under the volume, so on an iPhone the test is a control that
passes with or without the fix. Measured: round 1's view-held state failed it on the iPad Pro
13-inch and passed it on an iPhone 17e. `testTopicsRowAfterAHandOffOpensTheWholeIndex` also has a
two-pane-only step (the Topics row tapped beside the narrowed index). The suite chooses its path from
the screen (no Back in the bar at the index means two panes). It does not skip and does not say which
path it took, so an iPad under Browse's 820 pt gate (an iPad mini, in the portrait the suite forces)
silently runs the phone path. Use the iPad Pro 13-inch, and confirm the two-pane in the activity log:
Back from the volume taps the detail pane's own "Back", not the bar's. No unit test stands in for it.
`SubjectIndexGroupingTests.aDeliveryLandsOnceAndAReMountRestores` drives `HostState` alone and cannot
see an index view that keeps its own state instead of the host's. Expect **3 tests, 3 passed, on
each** (measured on the iPad Pro 13-inch (M5) on iOS 27.0 and an iPhone 17e on iOS 26.3):

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/TopicIndexArrivalTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/TopicIndexArrivalTests
```

**`CollectionEditorTitleTests` (#1359, #1415, #1413) must run on an iPhone AND an iPad, and only the iPhone guards the
push-over and the Collections-tab exit.** On a compact width Collection settings is PUSHED over the editor; on a regular
width it is a sheet, which covers nothing and fires no `onDisappear`. So the push-over test
(`testContentAloneDoesNotNameANewCollection`) can fail on an iPhone and cannot fail on an iPad, and the three tab-tap
tests — `testAnUntouchedCollectionLeftFromItsSettingsIsDiscarded`, and #1415's
`testANameTypedInSettingsSurvivesTheCollectionsTab` and `testFieldsSetInSettingsSurviveTheCollectionsTab` — need the
pushed screen and skip on the sheet route. #1413's three Section defaults tests run, and can fail, on both idioms: all
three failed on the pre-fix editor on iPhone 17 and on iPad Pro 13-inch (M5). Expect **9 tests with 0 skipped on iPhone
17** and **9 with 3 skipped on iPad Pro 13-inch (M5)** (8 and 8 until #1704). The suite passed on an iOS 27.0 iPhone 17 when it had its first
3 tests (pass the iOS 27 timeout flags below), and all 8 ran on an iOS 27.0 iPad Pro 13-inch (M5) on 2026-10-01 with
those flags, 5 passing and 3 skipping; all 9 ran on both on 2026-10-17 (below).
**A third destination guards #1450: iPad Air 11-inch in portrait, which the suite sets.** There the toolbar folds
＋ Add into its ⋯ overflow (⚙ Collection stays in the bar, and Collection settings is still the sheet), and the suite,
which looked for the menu in the bar alone, failed in `addSectionHeading()` before testing anything. Lane K3 measured
that on the one test that then added a heading; the other three came with #1413. Both suites in the file now open the
menu through `CollectionEditorAddMenu.open`, which looks in the overflow too (the lookup `CollectionProseRowRestTests`
already had), and each call prints `[CollectionEditorAddMenu] opened from …`. Measured on iPad Air 11-inch (M4), iOS
26.5, 2026-10-01: **8 tests with 3 skipped and none failed**, the four heading tests each opening the menu "from the
toolbar's overflow menu"; with the bar-only lookup put back, **those four failed** ("The editor has no Add menu"), 3
skipped and 1 passed. Neither of the other two devices folds the menu, so on them that line never names the overflow
and a change to the helper is unexercised: run the Air too.
**#1704 added a ninth test, `testLinkToSavedSearchOpensOverCollectionSettings`, and only the iPads guard it.** It opens
Collection settings, taps Link to Saved Search… (the launch seeds the search it needs, `FRUS_UI_TEST_SEED_SAVED_SEARCH`),
and requires the picker to open over the settings and the pick to show in them. On a regular width the settings are a
sheet, and before the fix the picker's sheet hung on the editor beneath it, so the tap opened nothing. Measured on the
code before the fix, 2026-10-17: it failed on iPad Air 11-inch (M4), iOS 26.5, and on iPad Pro 13-inch (M5), iOS 27.0,
each with "opened no picker. Bars: Collection settings | New Collection" while the app logged SwiftUI's "Currently, only
presenting a single sheet is supported."; on iPhone 17, iOS 27.0, which pushes its settings screen, it passed: there it
is the control. With the fix it passed on all three, alone, inside the 300 s allowance: 218 s on the iPad Pro, 222 s on
the Air, 196 s on the iPhone. It skips on no device. **The seeded search matches nothing, on purpose** (`UITestSavedSearchSeeder.keywords`): with
"missile" the iPad Pro 13-inch simulator's own volumes gave the linked collection 22 documents, the editor's live preview
drew them, single queries took up to 67 s, and the test ran out its allowance in its last step, Done, though the run's
screen recording shows the sheet gone 2 s after the tap. **On iPad Pro 13-inch (M5) under iOS 27.0 the
runner twice failed before the test began**, "Timed out waiting for AX loaded notification", and the simulator's
SpringBoard was being killed (`launchctl list` showed it at -9) when the app was launched by hand with a volume seed;
`simctl shutdown` and `boot` cleared the runner's failure, as the next run showed. Read a run that executes no test as the
simulator's, not the suite's.
**Every wait in the suite is 30 s, and it needs 600 s a test** (2026-10-17, plan of record §6g). Since Xcode 27.1
(installed 2026-10-16) one XCUI query on these screens takes seconds: in #1704's runs a query for a control by its
identifier took 4 to 13 s at a run's median, and up to 28 s, against about a second for one by label, on all three
devices and on a quiet Mac too. XCTest first checks a wait's condition about a second after the wait begins, so a 5 s wait
ran out while that first check was still running, whatever the screen showed. #1413's three Section defaults tests
(`testTheEditorShowsASubtitleSetInSectionDefaults`, `testASubtitleSetInSectionDefaultsSurvivesTheEditorsNextEdit` and
`testADescriptionSetInSectionDefaultsSurvivesAToggleInTheSameSheet`) wait for the sheet to go in an `XCTWaiter` of their
own, which checks nothing more once it runs out, so all three failed "The Section defaults sheet did not close" on iPhone
17 (iOS 27.0), iPad Air 11-inch (M4) (iOS 26.5) and iPad Pro 13-inch (M5) (iOS 27.0), on `v2` itself (`b3272d86`, built in
a control worktree) as on #1704's branch. `waitForExistence(timeout:)` does check once more after it runs out, and that
second check is all that kept the suite's other 5 s waits passing: all 61 waits for a control by identifier in #1704's
runs ran past their 5 s. Every wait is now the suite's `patience`, 30 s; a wait that is met returns at once.
**Measured on 2026-10-17 with the commands below:** iPhone 17 (iOS 27.0) **9 tests, 0 skipped, 0 failed**, in 1,514 s;
iPad Air 11-inch (M4) (iOS 26.5) **9, 3 skipped, 0 failed**, in 1,081 s; iPad Pro 13-inch (M5) (iOS 27.0) **9, 3 skipped,
0 failed**, in 1,222 s. In each run all five waits for the Section defaults sheet to go took longer than 5 s (up to 11.6 s
on the iPhone, 7.6 s on the Air, 8.1 s on the iPad Pro), and 22 to 29 of a run's 102 to 124 waits did. The Section
defaults tests took 139 to 348 s on the iPhone, 166 to 266 s on the Air and 191 to 342 s on the iPad Pro; in #1704's
control with a 30 s wait they took 326 to 430 s on the Air, and in #1704's run of the whole suite the 300 s allowance
ended `testContentAloneDoesNotNameANewCollection` on the iPad Pro (it passed alone in 191 s, given 600). Hence 600 s.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`SelectionEditMenuTests` (#1540) must run on an iPhone AND an iPad, and it lives in
`ResearchReadingStaysInTabTests.swift` — so `-only-testing FRUSExplorerUITests/ResearchReadingStaysInTabTests` runs a
different suite and none of these, while reporting green. Name the type.** It long-presses a word in the reader and reads
the system edit menu, which leads with the app's four colours, Excerpt, Look Up in NARA and Note. The menu shows what
fits and puts the rest behind ›, and the two idioms split it differently: at the default text size an iPhone 17's row
holds the dots and Excerpt, an iPad Pro 13-inch's the dots, Excerpt and Look Up in NARA, so Look Up in NARA is reached
through › on one and from the row on the other. The suite skips on neither. Expect **4 tests, 0 skipped, on each**
(measured on iPhone 17 and iPad Pro 13-inch (M5), iOS 26.5, with the iOS 27 timeout flags; iOS 27 itself is unmeasured).
Its unit half is `FRUSExplorerTests/SelectionEditMenuItemTests`, which also pins the clear that follows a chosen item.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/SelectionEditMenuTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/SelectionEditMenuTests
```

**`ResearchReadingDepthTests` needs its own, NARROWER iPad.** The iPad command for
`UIObstructionTests` further up is scoped to that suite, so it never runs this one. #1273's test turns a page and rotates across Research's
820 pt two-pane gate, which needs an iPad whose PORTRAIT canvas is under the gate: iPad mini (744 pt). On
iPad Pro 13-inch portrait is already two-pane, so the suite takes its `XCTSkipUnless` — reported as a skip
naming the required device, not as a pass.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad mini (A17 Pro)" \
  -only-testing FRUSExplorerUITests/ResearchReadingDepthTests
```

**The three keyboard/toolbar suites need iPad mini too, and #1279 is why.** Measured on `v2` at
`69dfac7d`, `AnalyticsKeyboardTests` + `KeyboardDismissBarReachTests` +
`ToolbarOverflowAccessibilityTests` ran **8 tests with 4 skipped and 3 failures** on iPad mini while
passing on iPhone 17 and iPad Pro 13-inch — a suite ending with an analytics window open, another
launch restoring it, and four bare tab guards that reported the wrong cause. They are green on all
three devices now; run them on the mini, because that is the one that catches this class.

**Run them on `OS=26.5`. #1620 no longer holds them there; `KeyboardDismissBarReachTests` does.**
Measured on 2026-11-01 on this Mac, now Xcode 27.2 (27B52) and macOS 27.2 with the same iOS 27.0
runtime (24A434), one build of `v2` at `c5e0608a`, the iPad mini (A17 Pro) under 27.0 (`22BCEC47`)
booted for each run: the three suites with `AnalyticsCompareFromTableTests` ran **10 tests, 9
passed**, with no `backboardd` report, so #1620's crash is gone and the issue is closed. The one
failure is `KeyboardDismissBarReachTests.testDismissBarRendersOnTheBrowseRootSearchField`, at its
#1070 assertion: the tab shell's banner, up before the field was focused, was still on screen
after the keyboard rose, through 19 polls. A second run of that suite under 27.0 failed the same
way, 1 of 2. The same build on the iPad mini under **iOS 26.5** (`0093684B`) passed it 2 of 2, and
there the assertion did run: the banner was up before focus and gone at the first poll. So under
iOS 27.0 the keyboard does not hide the banner on that iPad (#1835). Not looked into: why, and whether a
device does it. Until then this row is read on 26.5, and its analytics and toolbar suites can be
read under 27.0 as well.

**History: #1620 (closed 2026-11-01).** Measured on 2026-10-09 on this Mac, one build, an iPad mini (A17 Pro) shut down
and booted for each run. Under **iOS 27.0**, `AnalyticsKeyboardTests` ended 3 tests of 3 with
"Restarting after unexpected exit, crash, or test timeout", "Executed 0 tests" and three new
`backboardd` crash reports, as the issue filed it. Under **iOS 26.5** the same suite passed 3 of 3
with no report, and then the three suites with `AnalyticsCompareFromTableTests` ran **10 tests, 0
failures, 0 skipped** (3, 2, 4 and 1), again with none. So the crash follows the 27.0 simulator
and not the app or the Mac, and this row is read on 26.5 until a later 27 runtime is shown to run
it. One 26.5 iPad was used; no device was.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad mini (A17 Pro),OS=26.5" \
  -only-testing FRUSExplorerUITests/AnalyticsKeyboardTests \
  -only-testing FRUSExplorerUITests/KeyboardDismissBarReachTests \
  -only-testing FRUSExplorerUITests/ToolbarOverflowAccessibilityTests
```

**`SearchActionsBarFitTests` (#1307) is iPhone-only and wants two widths.** It measures the Search
actions bar's frames at five text sizes; at iPad width the row fits either way, so it self-skips
there. Run it on an iPhone 17 (402 pt) and on an **iPhone SE 3rd generation (375 pt, iOS 27)**,
which is the narrowest device type iOS 27 supports — create one if the machine has none. The
suite's own guard is worth knowing: an unrecognised `UICTContentSizeCategory…` name renders at the
DEFAULT size while every fit assertion passes, so each accessibility case proves its category took
effect. The tiers are spelled `M`, `L`, `XL`, `XXL`, `XXXL` — `…AccessibilityMedium` is not a name,
and a launch carrying it measured pixel-identical to L.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing FRUSExplorerUITests/SearchActionsBarFitTests
```

**`AuxWindowCloseTests` (#1368) is iPad-only, and which of its cases guard against the Home Screen
depends on the runtime and the multitasking mode.** It opens each Analysis Tools window, and — from a
seeded document's Research rail, which the suite seeds itself — Source Explorer, the graph and the
word cloud; taps Done; and requires the app to still be in the foreground with the window it was
opened from in front. Before opening anything it marks that window (Browse's Subseries directory, or
the open document) and counts the Browse tab items, so a close that opened a new main window fails
too. One case closes Archival Analytics through a citing-volume hand-off and requires the handed
volume on screen, and one opens Source Explorer from the standalone document window and requires
that window back. It self-skips on an iPhone, where these surfaces are sheets, and its Analysis
Tools cases skip on an iPad too narrow for Browse's two-pane. On `v2`, on an iPad Pro 13-inch (M5),
the Home Screen drop reproduced deterministically in one configuration: **iOS 27.0 in Windowed
Apps** — a fresh iOS 27.0 simulator's default, set in Settings ▸ Multitasking & Gestures — where
Archival Analytics' Done, Semantic Analytics' Done and the hand-off dropped in all three round-0 runs
and again in review round 1's; the rail cases and the document-window case came back even on `v2`
there. On iPadOS 26.5 in the same mode (a long-lived simulator, so its mode says nothing about a
fresh 26.x default) the hand-off dropped in one run of two; on iOS 27.0 in Full Screen Apps nothing
dropped, but Cross-Reference Analytics' window was still on screen after its Done in the one run, so
that case failed there; in Stage Manager nothing failed. The other cases are controls against the
Home Screen. Against a close that opens a new main window every case is a guard (measured in
Windowed Apps: all eleven fail under that mutant), and the document-window case also fails on round
0's code, which fronted the main window instead. The mode is a simulator setting that persists per
install and no launch argument sets it, so check it before reading a green run as a guard against
the drop.

**Its four rail cases need the Research rail open, and so does `TwoPaneDocumentTests`** (found in
A12, 2026-10-20). The rail's state is a persisted preference: on a simulator whose app holds
`frus.document.researchPanel.visible = false`, as the iPad Pro 13-inch (M5) under iOS 27.0
(`9AB3A0C9`) did that day, every document opens without it, and those tests fail once their walk
reaches the document ("The document opened without its Research rail…", "The Research rail is not
present…"). The key is in the app container's `Library/Preferences/bottsywattsy.FRUS-Explorer.plist`,
which `simctl spawn … defaults` does not reach; the finding was the 2026-10-14 plan of record's §6g, and the plan of record from 2026-10-21 carries it in §5 (P2, test infrastructure).

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/AuxWindowCloseTests
```

**`VolumeRemovalTests` (#1356/#1357) needs an iPad for two of its five tests, and iOS 27 is where
both issues were found.** The two confirmation-anchor tests exist only where a confirmation dialog
is a popover — a regular-width size class — so a phone skips them, since there it is an action
sheet with no source. The skip reads the idiom, not the size class, so run the iPad full-screen:
a compact Split View or Slide Over window would present an action sheet too, and the tests would
fail on `app.popovers` instead of skipping (reasoned, not measured). The row
test asks from two rows and reads each popover against its own row's frame, so it does not depend
on where one device happens to put a misanchored popover. The other three tests run on both idioms:
a removed row leaving *Volumes on This Device* with nothing touched while the list itself stays —
it PASSED against unfixed `v2` (1.1 s), so it guards wiring, not #1356's symptom;
`testRemovalMarkSurvivesLeavingTheHub`, which holds the removal open for 40 s through
`FRUS_UI_TEST_HOLD_STORAGE_REMOVAL` and requires the row to read *removing…* both before and after
the reader leaves Volumes & Storage and comes back; and
`testFreeUpSpaceKeepsItsVolumeWhileRemovingIt`, which holds a Free Up Space removal for 20 s and
requires the sheet to go on listing the volume it is removing — never "No Removable Volumes" — and
then to close on its own. That test removes the browse fixture's catalogue volume; the next launch
that seeds the fixture writes it and indexes it again. The suite seeds five side-loaded rows through
`FRUS_UI_TEST_SEED_STORAGE_ROWS`, which every launch WITHOUT it removes again, and runs with
`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`. Expect **5 tests, 0 skipped on iPad** and **5 with 2 skipped
on iPhone**, and run it on an iOS 27 iPad as well as an iOS 26 one:

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/VolumeRemovalTests
```

**`ResearchSidebarSelectionTests` (#1362) needs an iPad whose Research tab is two-pane in BOTH
tab-bar representations: iPad Pro 13-inch or iPad Air 13-inch, which the suite turns to landscape
itself.** It asserts that the category open in the two-pane's detail is the only row in the list
beside it whose `.isSelected` trait is set. **It reads the trait, not the row's fill**: a fill
changes no trait, so a row whose fill were deleted would pass it (measured: both tests green with
the fill removed). `ResearchSidebarOpenMarkSourceTests`, in the unit target, pins the two together
in the source, and whether the fill is visible is checked by eye from the screenshots the suite
keeps. On an iPhone both tests skip as iPad-only, measuring no width, because the stack pushes the
category and no list stays on screen to mark, so an iPhone run is a skip, not a guard. On an iPad
whose Research content area — the window less the tab sidebar, the width the 820 pt gate measures —
is under the gate, they skip naming that width. Over the gate they never skip: a missing two-pane
fails, and so does a selection the representation toggle loses. The first test runs in whichever
representation the install has, and the second toggles to the other, so one run covers both; the
log's `[#1362]` lines name the representation and the content width. Expect **2 tests, 0 skipped**.
Measured green on iPad Pro 13-inch (M5), iOS 26.3, launching in the floating bar, and on iPad Air
13-inch (M4), iOS 27.0, launching in the sidebar; the flags below are for iOS 27.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/ResearchSidebarSelectionTests
```

**`BrowseRootSelectionTests` (#1431) is Browse's sibling and needs the same iPads: iPad Pro 13-inch
or iPad Air 13-inch, turned to landscape by the suite.** It lives in `TwoPaneDocumentTests.swift`
and asserts that the door the Browse two-pane's detail was opened from — a row or tile on the
corpus root, a root-search result, or the Continue reading row — is the only element under the
`browse.root.` identifier prefix whose `.isSelected` trait is set. Like the Research suite it reads
the trait and not the fill (measured: with the row fill removed, its first test passed);
`BrowseRootOpenMarkSourceTests`, in the unit target, pins the fill on every door in the source.
Both suites read the content width through `TabBarNavigator.settledContentAreaWidth`. On an iPhone
all four tests skip as iPad-only before launching, so an iPhone run is a skip, not a guard. Under
the 820 pt gate the first three skip naming the width; over it a missing two-pane or a door lost on
the representation toggle fails. The fourth, the Continue reading row, needs the 1,100 pt DOCUMENT
gate (the list pane survives a document only with room for the Research rail), so it switches to
the floating bar itself — in landscape a 13-inch iPad's sidebar leaves 1,086–1,096 pt — and skips
below 1,100 pt naming the width; it seeds `frus1961-63v06` and a research note on its `d2`, taps
Index Now when the fixture's compilation offers it, and after Continue reading reads `d2` in
Research, so a newer reading-history entry must leave the row marked and naming its own document.
Expect **4 tests, 0 skipped**. Measured green on iPad Pro 13-inch (M5), iOS 26.3, launching in the
floating bar, and on iPad Air 13-inch (M4), iOS 27.0, launching in the sidebar. Those are the only
devices measured, not the only ones it runs on: an iPad mini or 11-inch in landscape clears the
gates too, so there the suite runs, and can fail.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseRootSelectionTests
```

**`WordCloudLensTests` (#1373) is a guard only on an iOS 27.0 simulator.** On iOS 27.0 an
`NLTagger` scheme whose first use in a process fails stays failed for that process; the app's
`NaturalLanguageReadiness` warm-up (WordCloudKit) prevents it, and these tests assert that a
part-of-speech or entity lens keeps something whenever the warm-up's request for the scheme it
reads (lexical classes, names) answered `available`. On the pre-fix tree they failed on the iPad Pro
13-inch (M5) and the iPhone 17e, both iOS 27.0, and those two requests answered `available` in every
iOS 27.0 launch whose warm-up line was recorded (103, all on the iPhone 17e). On the Mac the warm-up
starts **at launch**, as the first statement of its `FRUSExplorerApp` init; on iPhone and iPad it
starts on the app's **first foreground** (#1539), because a background launch runs the init too — the
iOS init's first statement installs `LanguageAnalysisLifecycle`, which makes any earlier first use
wait for that foreground (`NaturalLanguageReadinessScanTests.initsInstallTheLifecycleBeforeAnythingCanTag`
and `onlyTheMacInitStartsTheWarmUp`). Either way it has usually finished before a test first tags,
and no runtime test reliably sees the gate that makes a tagger wait for it —
`taggerReadsTheVerdictBeforeItBuilds` pins that wait in the source instead. Since #1539 a lemma
request that does not answer within its 30 s in the foreground withholds the lemma scheme from every
tagger built until a request for it answers (one left unanswered by a trip to the background keeps
the whole verdict pending instead), so in such a launch the word lenses count printed forms, and the
printed line contains `withheld=[Lemma]`. An earlier attempt moved
it to first use after counting 7 of 14 iPhone 17e launches losing the lemmatiser at launch against 1
of the 14 recorded on first use (six more went unrecorded, one of which spent the full 30 s budget);
those were blocks of one arrangement at a time, and rotated launch by launch on the same simulator
the launch start, the search-boot start and first use lost it in 7, 5 and 6 of 25 launches — the
simulator's state, not the arrangement. So on that one iPhone 17e, over the 2 to 28 minutes after
it booted, about one launch in four (18 of 75) lost its lemmatiser wherever the warm-up started —
where a command-line probe on a warm iPad Pro lost it in 1 of 41 processes, so do not read the rate
as a property of iOS 27.0. Such a launch is the canary's to report, and a passing run does not mean
every launch lemmatised: read the printed line. Counted again on 2026-10-12 (#1608): the iPhone 17
under iOS 27.0 kept its lemmatiser in 15 launches of 15, and the iPad Pro 13-inch (M5) lost it in 1 of
3, the first after its boot, which was this pair of suites' own run (8 tests passed in it, its line
reading `Lemma=timedOut@30.002s withheld=[Lemma]`). Since #1608 such a launch also ranks: Collocates,
Distinctive sizing and Related Documents' shared words compare printed forms with a reference counted
as printed. To have one on demand, launch a Debug build with `FRUS_DEBUG_NO_LEMMA_ANSWER=1`
(`CLAUDE.md`, "To see a launch with no lemmatiser"). Each run's `NaturalLanguageReadinessWarmUpTests`
prints the warm-up it saw (`[#1373] …` — the release log's own line since #1539: what started it,
how far into the process, what each request answered and what was withheld), which is how those
launches were counted. On the **iOS 26 simulators** (26.3,
26.4 and 26.5 measured, iPhone 17) no request answers and nothing tags at all, so below 27 the
warm-up does not ask (`NaturalLanguageReadiness.asksForAssets(onMajorVersion:)` — it used to wait
out the 30 s budget in every process there) and the same tests fall back to checking that the
canary agrees with the tokenizer: a control there, not a guard. Under `swift test` on the macOS host
(`WordCloudKitTests`) tagging works with or without the warm-up, so those runtime cases are controls
too.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerTests/WordCloudLensTests \
  -only-testing FRUSExplorerTests/NaturalLanguageReadinessWarmUpTests
```

**`CrossReferenceMatrixScrollTests` (#1379) must run on BOTH an iPad and an iPhone, and one
destination gives you only one idiom's cases.** It lives in `AnalyticsRotationTests.swift` and
launches with `FRUS_UI_TEST_SEED_CROSSREF_MATRIX=1`, which writes 420 citations among fifteen real
volumes into the index so the matrix is full with nothing downloaded (`UITestVolumeSeeder`); every
later debug launch without the key deletes them again. It turns the device to portrait itself. The
two page-scroll tests need an iPad whose portrait window shows the whole 565 pt grid — iPad Pro
11-inch (M5) and iPad mini (A17 Pro) are the ones measured — and skip on an iPhone, where a window
shorter than the grid and the chrome above it would fail the second however the matrix scrolled.
`testTheCellsScrollSidewaysBesideLabelsThatStayPut` needs a window under 707 pt, where the cells
really scroll sideways, and skips on every full-screen iPad naming the width it measured: an iPhone
in portrait runs it. The label-width and row-alignment tests run on both. Expect **5 tests, 1
skipped** on an iPad and **5 tests, 2 skipped** on an iPhone. On `v2`'s layout, iPad Pro 11-inch
(M5), iOS 26.5: a 260 pt drag from a matrix cell moved the *Landmark Documents* heading 0 pt, the
last row never came on screen in six drags of the page, and the row labels ended at x 229.5 instead
of 293. On an iPhone 17, iOS 26.5, a sideways drag carried a row label from x 16 to −124 with the
cells, and an upward drag from the cells moved the page 0 pt. On iPad Pro 11-inch (M5), iOS 27.0,
with the timeout flags below, it ran 5 tests with 1 skipped and none failed, its analytics window
full screen at 834 pt. **A drag must not start at the foot of an iPhone's
screen**: there it is the system's home gesture, and the sideways test's first run measured the app
shrinking toward the Home Screen, which is why it raises its row into the upper two-thirds of the
window first. The Mac's scrolling over the matrix is checked by eye, with the steps in
`Planning/DEVELOPMENT-PLAN.md` (2026-09-25). The **wheel** half passed on 2026-09-25 on an isolated
Mac copy (`Planning/Completed/Mac-Check-2026-09-25.md`, A2: the page scrolls and nothing inside the
matrix scrolls on its own); a two-finger **trackpad** swipe and the row label's tooltip could not
be driven there and are still owed.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 11-inch (M5)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/CrossReferenceMatrixScrollTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/CrossReferenceMatrixScrollTests
```

**`CrossReferenceRankingChartTests` (#1473) runs on any iPhone or iPad and never skips, and on an iPad it is a
guard only because its floor is 150 pt**; it lives in `AnalyticsRotationTests.swift` beside the matrix suite and
launches with the same `FRUS_UI_TEST_SEED_CROSSREF_MATRIX=1`. It reads the Most-Referenced Documents chart's bars
by their VoiceOver value ("N inbound citations"). Swift Charts gives each bar's element the bar's ROW ACROSS THE
PLOT, not the bar's length (every one 218 pt on an iPhone 17), so it is the plot's width it requires: at least
`RankingChartAxis.minimumPlotWidth` less 10 pt, 150 pt, inside the window (`RankingChartAxisTests` reads the UI
suite's spelling of the figure). `v2`'s label column is its widest title's one line, about 961 pt whatever the
device: on an iPhone 17, iOS 26.5, every bar was 1 pt wide at x 977 of a 402 pt window, and a 13-inch iPad in the
portrait the suite sets keeps a plot of only about 31–39 pt. The suite's first floor, 20 pt, passes that: a mutant
leaving the iPhone 17 a plot that size drew every bar's row 36 pt wide, which the 150 pt floor fails. The first iPad
run was #1797's, on the fixed code, so that the floor fails the code before #1473 on an iPad is still reasoned. The Mac, where #1473 was found at 720–820 pt,
has no UI target: `RankingChartAxisTests` draws the chart at 720, 820 and 402 pt and counts the bars in the
pixels, and the by-eye check is the owner's. **Since #1797 two more tests tap the ranking's first bar and its
title** and find the document open: the fixture's documents are in volumes the simulator lacks, so each opens
on its *Volume Not Downloaded* page, which names the volume, as the list's row opens it. Each bar is now a
button over its row across the plot (identifier `crossRefAnalytics.ranking.bar.<volume>/<document>`, which
`RankingChartAxisTests` holds the suite's spelling to), so the first test still measures the row Swift Charts
gave the mark: 218 pt on the iPhone 17, as before. Measured on the iPhone 17, iOS 27.0, and an iPad Pro 13-inch (M5), iOS 26.5: **3 tests, 3 passed** on each;
on the iPhone, with the screen's chart given no action, as on `v2`, both tap tests fail (no bar button). Expect **3 tests,
3 passed**.

**`CollectionProseRowRestTests` (#1360) must run on an iPad AND an iPhone; it lives in
`CollectionEditorTitleTests.swift`.** It types a long paragraph into a collection note block (and into the
introduction in Collection settings), puts the keyboard away and asks Vision what the text view DRAWS — a text view's
`value` is its whole text whether or not any of it is on screen, so no XCUI query can see the defect. Two more tests
read the block while it is edited: at AX3 a tap must not SHRINK it (six resting lines, 292 pt, outgrow the 220 pt
editing height), and typing into the Text Color picker's own Red field — which takes focus, where merely opening the
picker does not — must not collapse it. The two idioms reach different screens. On iPhone the Add menu is one nav-bar
menu and Collection settings is a pushed screen. On iPad settings is a sheet and the Add menu is the toolbar's ＋ Add,
inside its ⋯ overflow only where the toolbar is too narrow for it: measured, iPad Air 11-inch in portrait at the
default text size, but not at AX3 on the same device and not on iPad Pro 13-inch (iOS 26.4), where every note-block test
took the plain Add. Every test fails on the code it guards on both idioms — the three resting tests on v2's row, the two
editing tests on #1360's first build — measured on iPad Air 11-inch (M4) and iPhone Air, iOS 26.5. Expect **5 tests, 0
skipped** on each. The AX3 tests prove their size took effect from the recognized line height, and the default-size
test checks the other side of the same threshold. The unit half is `FRUSExplorerTests/RichTextRestingCapTests`. A
`name=` alone picks one of several runtimes on this machine, so pin the OS the figures came from.
**Every wait in it is 30 s, and give it 600 s a test** (2026-10-17, plan of record §6g). In #1704's runs on iPad Air
11-inch (M4) 3 passed and 2 failed: `testALongIntroductionRestsOnItsOpeningWords` ("Done did not put the keyboard away",
its first check of the settings sheet's Done taking 4.3 s) and `testTextColorKeepsALongNoteBlockOpenWhileItsPickerIsUp`
("The colour picker did not close", and once "Text Color opened no colour picker with a Sliders tab"), each the same way
on `v2` at `a9361e7e`, built in a control worktree; iPhone Air passed all 5. The cause is the one
`CollectionEditorTitleTests`' entry above gives: a 5 s wait ran out while XCTest's first check, a second in, was still
running. With every wait at the suite's `patience`, 30 s, it passed whole on both on 2026-10-17 with the commands below:
**5 tests, 0 skipped, 0 failed** on each, in 583 s on the Air and 590 s on the iPhone Air. The wait for the keyboard to
go took about 5.3 s on the Air and 5.5 s on the iPhone Air in that run, past the old 5 s. The slowest test took 137 s,
but #1704's runs of the Text Color test on the Air reached 214 and 228 s before failing in its last steps, so the
commands pass 600 s.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionProseRowRestTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone Air,OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionProseRowRestTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`CollectionListManagementTests` (#1823) must run on an iPhone AND an iPad; it lives in
`CollectionEditorTitleTests.swift`.** It drives the Collections list's three delete routes — a row's menu, its swipe,
and Edit's Delete over two chosen rows — and its Rename, and requires the delete dialog before anything goes and the
collection gone only after the dialog's Delete. The idioms present that dialog differently, which is why it needs both:
on the iPhone an action sheet with a Cancel, on the iPad a popover hanging from the row (or from Edit's Delete) with no
Cancel, which the menu test closes by tapping outside it. Its two collections are the launch's own seeds,
`FRUS_UI_TEST_SEED_PROJECT=1`'s unattached collection and `FRUS_UI_TEST_SEED_SAVED_SEARCH=linked`'s smart one, in the
in-memory store, so each launch has both and nothing is left behind. Nothing skips: expect **4 tests, 0 skipped** on
each. On the code before #1823 every test fails, by reading rather than by a run: the row's menu had no Rename and no
Delete, the list had no Edit, and the swipe's Delete deleted at once, so no dialog appeared. Measured 2026-11-01, Xcode
27.2: **iPhone 17, iOS 27.0, 4 tests, 0 failed, in 64 s** (13–20 s a test), and **iPad Pro 13-inch (M5), iOS 27.0, 4 tests,
0 failed, in 65 s**, each beside `CollectionEditorTitleTests`' 9, which passed with their expected skips (0 and 3). Give it 600 s a test, as for the suite it shares a file with.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/CollectionListManagementTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/CollectionListManagementTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`BrowseWithinScopeTests` (#1364) must run on an iPhone AND an iPad, and neither is a control.**
Its first two tests failed on the unfixed code on each idiom (measured on `v2` with the suite's
seams, as first written), and the first and third, `testAnotherScopeOffersBrowseWithinWhileNarrowed`,
fail on each when the menu's action only writes the scope's id, which is #1364's own defect
(measured after review round 1 extended the suite). The iPhone reaches My Scopes through
the navigation stack and the iPad through the two-pane's detail pane, so a fix can land on one and
miss the other. `testBrowseWithinLandsUnderTheBanner` also checks the list pane's Subseries tile,
and `testRootTileNamesTheScopeWhenLaunchedNarrowed` checks it again after Stop Browsing Within, but
only in the two-pane; on a stack layout (an iPhone, or an iPad below Browse's 820 pt gate) each
leaves out that one check without skipping, and prints `[#1364] layout: …` so the log says which it
measured. An iPad Pro 11-inch (M5) is two-pane even in portrait. The suite seeds TWO scopes with
`FRUS_UI_TEST_SEED_SCOPE=1` — one to narrow to and one that must read as not narrowed — and
`UITestLaunch` now pins `-frus.browseScopeFilterId ""` for every suite launched through it (all but
`UIObstructionTests`' onboarding launch): a test here that fails or is stopped between choosing the
filter and clearing it leaves the id in the persistent domain, and a later suite would otherwise
launch narrowed to a scope its in-memory store does not hold — the `.unavailable` state, whose
subseries list is empty. Expect **3 tests, 3 passed, on each**, measured on the iOS 26.4 runtime
the destinations below pin. **On iOS 27.0 (measured 2026-10-09, with #1565): 3 passed on iPhone 17
and on iPad Pro 11-inch (M5).** Before #1565 `testBrowseWithinLandsUnderTheBanner` failed on
iPhone 17 under iOS 27.0: the swipes stopped with My Scopes still under the Local Only banner,
where `isHittable` is true, and the tap landed on the banner. The helper now swipes until the row
is above the banner, which the app's fix made possible. Seen once that day, and not looked into:
the first test of a run on a simulator this build had not been installed on before met the
onboarding screen in spite of the launch pin and failed on a missing Browse tab; the same test
passed on the next run. The commands:

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.4" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseWithinScopeTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseWithinScopeTests
```

**`TabShellBannerClearanceTests` (#1565) runs on an iPhone and an iPad, and turns the iPad to
landscape, because in portrait two of an iPad's lists are too short to reach the banner.** Every
UI-test launch runs without CloudKit, so the Local Only banner is always up. Three scenarios drag a
list to its end (the Browse root, Browse ▸ Archives, the Settings root) and require its lowest text
or control to end at or above the banner's top edge; each SKIPS, saying so, when nothing in the list
ran below that edge before it was scrolled. `testPushedScreenBottomBarSitsAboveTheBanner` requires
the Download button on Settings ▸ Volumes & Storage ▸ Download from GitHub to sit above the banner.
`testEveryTabDrawsTheBannerAboveTheTabBar` visits all five tabs and taps the banner's Details.
`testBannerKeepsItsPlaceWhenTheTabsBecomeASidebar` is iPad-only: it switches the tabs to their other
arrangement, checks the banner and the Settings list again, and `tearDown` switches them back, since
the arrangement persists per install. `setUp` turns an iPad to landscape and an iPhone to portrait,
and `tearDown` returns either to portrait. Measured on 2026-10-09:

- **iPhone 17, iOS 27.0: 6 tests, 5 passed, 1 skipped** (the sidebar scenario, which is iPad-only).
  Banner top at y 721.7; the three lists rest with their last text ending at y 684.7 to 686.0, and
  Download sits at y 671.3–705.7. On iOS 26.5 the same five passed with the same figures, before
  the sidebar scenario was written.
- **On the old drawing (the banner as a bottom `safeAreaInset` outside the stack), iPhone 17,
  iOS 26.5: the three list scenarios and the Download scenario FAIL** (last text at y 732–755,
  Download at y 740.7–775.0) and the five-tab scenario passes. That one guards the new drawing
  alone: it fails when the banner hangs with no room set aside for it, and a list scenario fails
  when the room is set aside and the banner is not hung in it.
- **iPad Pro 11-inch (M5), iOS 27.0, landscape: 6 tests, 6 passed, 0 skipped.** Banner top at
  y 760.5; lists end at y 723.5 to 725.0; Download at y 710.0–744.5. **On the old drawing there,
  five FAIL** (lists at y 762.5 to 778.2, Download at y 763.5–798.0) and the five-tab scenario
  passes. That simulator had its tabs as a sidebar, so the sidebar scenario measured the bar.
- **The same iPad in portrait, before the suite pinned landscape: 5 tests, 3 passed, 2 skipped.**
  The Browse root and Browse ▸ Archives fit above the banner (top at y 1136.5).

On the iPad each scenario takes one to two and a half minutes, about ten minutes for the suite. The
list reading leaves out images and anything wider than its list: while a list has rows under the
tab bar, iOS keeps an image named `AdditionalDimmingOverlay` inside it (measured on 26.5), which
reaches below the screen and once ended a scenario halfway down the Settings list. With the tabs as
a sidebar the reading also includes the sidebar's own list, whose last row is far above the banner.
The same rule lives in the unit target as `TabShellBannerReserveTests` (4 tests, any iPhone or iPad
simulator), which hosts the modifier in a window and reads the host's inset, the banner's frame and
a `List`'s bottom inset inside a `NavigationStack`.

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/TabShellBannerClearanceTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/TabShellBannerClearanceTests
```

**A device NAME does not name an OS, and a simulator carries state between runs.** This machine
has one "iPad mini (A17 Pro)" per installed runtime (iOS 26.3, 26.4, 26.5 and 27.0), so a
`name=` destination picks one for you. To compare runs, pin a UDID and write down its runtime
(`xcrun simctl list devices`). On 2026-09-18, four iPad mini failures were first read as an iOS
27 change, but the "pinned" mini was on 26.3. The real variable was per-install state: a UI test
had left `activeProjectId` in UserDefaults. `UITestLaunch` now pins it, the same way it pins the
tab. The sidebar representation also persists per install and has no pin; a helper that assumes
the floating bar will fail on a device that has shown the sidebar. When a failure follows one
simulator and not another, diff the app's preferences plist before suspecting the OS — **but a
plist diff will not show the representation.** Measured on 2026-09-24 (#1362, iPad Pro 13-inch,
iOS 26.3): the scene's saved state, `Library/Saved Application State/bottsywattsy.FRUS-Explorer.savedState`
in the app's data container, decides it when one exists. That state was written when the app went
to the BACKGROUND with the sidebar showing: after a probe toggled it and pressed Home, both launches
of the next run opened in the sidebar, and moving the folder away brought the floating bar back.
`com.apple.UIKit.UITabSidebar`'s `preferredVisibility` stayed at the same value across two toggles,
so toggling does not write it. Whether that key decides a launch with NO saved state was not
measured: the one run launched after writing it (2) still had a saved state on disk, so its floating
bar says only that the saved state wins. To make the sidebar the launch representation, toggle it,
press Home, and relaunch. To go back to the floating bar, move that `.savedState` folder out of the
container while the app is not running — measured on a simulator whose `preferredVisibility` read 1.

**Pass `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 300` when running UI tests
on iOS 27**, so a stall ends the run instead of hanging it. Before every action XCTest waits for
"animations idle", and in a stall that wait is never answered again for the rest of the launch: each
action waits the full 60 s ("App animations complete notification not received"). **The cause is
known (2026-09-19) and it is not the app.** XCTest decides "idle" from one process-wide counter, +1
in its swizzle of `-[UIViewAnimationState animationDidStart:]` and −1 in
`animationDidStop:finished:`, and iOS 27's system animations unbalance it two ways: the new
in-process engine (AnimationKit's `UIViewInProcessAnimationState`, absent on iOS 26.3) leaves
exactly 11 starts unstopped when the Analysis Tools menu opens on an iPhone, and Core Animation
delivers one interrupted spring's start twice when a keyboard comes up or goes down or a sheet's
Done dismisses it. UIKit finishes every animation; only XCTest's count is wrong, and nothing the app
starts is involved. Measured over `YearRangeFieldWidthTests` on iOS 27 simulators: with animations
on, 13 of 221 cases stalled (5.9%, mostly iPhones) and a stalled case often ran out its allowance;
with them off, 0 of 171. **A suite that measures a screen at rest should set
`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`** (see `FRUSExplorerApp.configureUITestAnimations`):
`YearRangeFieldWidthTests` does, which took the events XCTest counts from ~840 to 16–19 per case,
all balanced. It is opt-in because a suite testing an animated transition — `AnalyticsRotationTests`
(#498) — needs its animations. `tools/ui-test-stall/` catches and explains a stall: `watch_stall.py`
loops a test and captures each stall, `animdump.py` reads XCTest's counter from a live app (read its
first line; the layer tree alone showed nothing), and `track_counter.py` logs every move of it. To
reproduce, run the watcher's default test with `INJECT='(void)[UIView setAnimationsEnabled:YES]'`.

**A UI-test suite that opens a presentation must CLOSE it in `tearDown`, not merely terminate.**
`XCUIApplication.launch()` already terminates a running app; what the next launch restores is what
the last one had *open*. On iPad that includes a whole window scene — `BrowserView.presentAnalytics`
branches on `\.supportsMultipleWindows`, so Corpus Analytics is an auxiliary WINDOW there and only a
`.sheet` on iPhone — and a test that inherits it finds no tab bar in the element tree at all.
Nothing in the app restores it (`showAnalytics` is plain `@State`), so do not go looking there.
`UITestPresentation.dismissAnyPresentation(in:)` is the helper, and it is scoped to
`app.navigationBars.buttons` for two measured reasons: a bare `app.buttons["Done"]` closes the #861
keyboard accessory bar instead, and `isHittable` on a dying popover button fails the test outright.

**A test that opens on the onboarding wizard was handed another process, and a Live Activity is
why.** The system opens the app in the background when one of its Live Activities is dismissed while
the app is not running. A launch a test asks for while that background launch is starting is given
its process, which has none of the test's launch arguments and none of its environment: the wizard
(no `-hasCompletedOnboarding 1`), over the simulator's real store and with CloudKit set up (no
`FRUS_UI_TEST_MODE`). The test fails in 12 to 15 seconds on its first tab selection. Measured on
2026-10-11 on iPhone 17 (iOS 27.0), from the simulator's own log, two ways an activity is dismissed
with the app gone:
- **Nothing ended it.** A UI test that taps Index Now passes once the rows are drawn and its app is
  killed while it indexes; a unit run that takes a second ends while its host indexes a volume it
  found at launch. The next `xcodebuild` run's install stops the activity (`liveactivitiesd`:
  "Stopping uninstalled activity") and the request to open follows. Four installs stopped an
  activity left over, two by chance and two made on purpose, and the launch after each came up in
  the background (SpringBoard: "Bootstrapping … with intent background", "Initial launch state:
  BG-Active") and showed the wizard, the test's request 9 to 23 ms behind `liveactivitiesd`'s. No
  other launch did: of the 20 the log holds up to the third, after 11 installs, the other 17 came
  up in front.
- **The app ended it**, and its dismissal came due three seconds later, the host having exited: the
  request followed 3.013 seconds after the end, twice out of two. Neither met a test's launch.

**A test's process now starts no Live Activity** (`LiveActivityPolicy`, in `AppState.swift`: a unit
test's host and a UI test's app), so the suites no longer do this to each other. Measured after: the
test that left an activity behind leaves none, and the test run first after it passed, in front.
What still can: **the tests of a build older than the rule** (a control build of a commit before
2026-10-11) and **the app killed by hand while it indexes**. The next run's first test then fails
once, and `TabBarNavigator` says why when it meets the wizard. Run again. Since #1642 (2026-10-12)
an activity the app left is ended at the app's next launch, a test's launch included, so what the
killed app leaves lasts only until then; an `xcodebuild` install that comes first still stops it and
opens the app. **A second way the system opens the app in the background**, measured the same day
on an iPhone 17 simulator (iOS 27.0), twice of two: tapping **Allow** (and later **Always Allow**)
on the Lock Screen's "Allow Live Activities from FRUS Explorer?" prompt. `liveactivitiesd` logs
"Launching process to deliver push token", and the launch asked for 11 seconds later was handed
that process and showed the wizard. To see it in the log:
```bash
xcrun simctl spawn <UDID> log show --last 10m --style compact --predicate \
  '(process == "liveactivitiesd" AND eventMessage BEGINSWITH "Stopping uninstalled activity") OR (process == "SpringBoard" AND (eventMessage CONTAINS "Received request to open \"bottsywattsy.FRUS-Explorer\"" OR eventMessage CONTAINS "Initial launch state"))'
```
A launch the test got reads `from CoreSimulatorBr` and then `FV-Focal`; one it did not get has a
line `from liveactivitiesd` just above it and reads `BG-Active`.

**`SummarizationPromptCopyTests` (#1590) runs on an iPhone or an iPad, and its test must stay the
Summarization pane's FIRST action.** It opens Settings ▸ Summarization, presses **Use as Template**
on the first standard prompt, and requires the New Prompt editor's name field to read "Copy of
<that prompt>" with no **Choose a Template** sheet over it. The defect it guards showed only on the
first Use as Template or Duplicate of a visit to the pane: the pane kept the copy in a `@State`
beside the sheet's Bool and read it only inside the sheet's content closure, so the sheet was built
from the closure made before the tap. Anything that reads that state first hides it (pressing **New
Prompt…** is enough), so the test touches nothing in the pane before the button, and each test
method is a fresh launch. One pane serves both idioms, so one device is the guard, and it never
skips. Measured on 2026-10-09 on **iPhone 17, iOS 27.0: 1 test, 1 passed**, and on **iPad Pro
11-inch (M5), iOS 27.0: 1 test, 1 passed**; and on the code before the fix (the three app files at
`9c774265`), on iPhone 17, **1 failed**, on Choose a Template being up.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/SummarizationPromptCopyTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
```

**`AnalyticsCompareFromTableTests` (#1583) needs no index, and runs on an iPhone or an iPad under
iOS 27.0.** Until 2026-11-01 an iPad run under 27.0 was killed at teardown (#1620, below); on
Xcode and macOS 27.2 it passed on the iPad mini (A17 Pro) under 27.0, twice, and the issue is
closed. It
opens Corpus Analytics, commits one term, switches the Display control to **Table**, commits a
second term, and reads two things before asserting either: the Display control's **Chart** segment
is the selected one, and the two **Values** choices (Raw count, % of documents) are enabled. On an
iPhone the choices are listed in the **Options** menu, under Measure's two; on a regular width they
are a segmented control in the toolbar, and the test looks there first. The controls answer for a
comparison whether or not either term matches a document, so an empty index is enough. It never
skips: a control it cannot find fails and prints the buttons on screen. `tearDown` closes Corpus
Analytics, which on an iPad is a window scene the next launch would restore (#1279). Measured on
2026-10-09 on **iPhone 17, iOS 27.0: 1 test, 1 passed**; and with `AnalyticsView.swift` as it was
at `9c774265`, **1 failed, on both observations** (Table selected, both Values choices disabled).
**On iPad Pro 11-inch (M5) and iPad mini (A17 Pro), iOS 27.0, every step ran and no assertion
failed, and then the simulator's `backboardd` aborted about two seconds after `tearDown`
terminated the app and took the test runner with it** ("Test crashed with signal kill"). That is
not this suite's: `v2`'s own `AnalyticsKeyboardTests` does the same on a newly booted iPad mini, 3
tests of 3 (#1620). **On an iPad mini (A17 Pro) under iOS 26.5 it passed, 1 test, later the same
day**, in the run of ten the keyboard suites' entry above records. *(That paragraph is the record
of #1620; since 2026-11-01 an iPad run under iOS 27.0 is read like any other.)*
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/AnalyticsCompareFromTableTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
```

**`SearchResultAddToCollectionTests` (#1576 lane 2) runs on an iPhone and an iPad, and only the
iPad guards the picker row's tap.** Each of its two tests seeds the six-document volume
(`FRUS_UI_TEST_SEED_VOLUME`) and `UITestProjectSeeder`'s collection, "UI Test Unattached
Collection", which holds `d1` (`FRUS_UI_TEST_SEED_PROJECT`; the seeded project is not made active),
and runs a keyword search for "Synthetic", which every fixture paragraph holds. The search is
submitted until its rows are there, five times at most, because the seeded volume is indexed
during launch and a search that runs first lists nothing. Each then long-presses a result row,
chooses **Add to Collection…**, taps the seeded collection's row, and reads that row's count from
a picker presented again:
- `testAResultAddedFromItsMenuRaisesTheCollectionsCount` adds "UI Test Document Two" and reads
  "1 document" then "2 documents", and adds "UI Test Document Three" and reads "3 documents". Two
  different documents, so a request that carried the wrong row, or always the same document, comes
  out at the wrong count.
- `testADocumentTheCollectionHoldsIsNotAddedAgain` adds "UI Test Document One", which the
  collection holds, and reads "1 document" before and after.

Neither skips. The count is read in the app's one context, and the UI-test store is in memory, so
this proves the entry was linked and does not prove the save; `CollectionAttachmentTests` reads a
second context for that. `tearDown` taps the picker's Cancel by name before the shared helper
runs, since that helper does not choose Cancel.

The row is tapped at its centre. On an iPhone that is over the collection's name. On an iPad's
wider sheet it is the blank part of the row, and a plain button takes a tap only where its label
draws, so until this lane gave the row a content shape the tap did nothing there. Measured on
2026-10-10 on **iPhone 17, iOS 27.0: 2 tests, 2 passed**, and on **iPad Pro 13-inch (M5),
iOS 27.0: 2 tests, 2 passed**. Before the split into two tests, the one test that held all five
sheets was run on that iPad with the content shape taken out, twice, and **failed** each time on
"The picker did not close after adding UI Test Document Two"; and with `appendDocuments` changed to
add a document the collection holds, it failed on the iPhone on the row reading "3 documents".
**It was split because of time:** as one test it took 130 s on a quiet Mac and 292 s on the iPhone
while other sessions' builds had the load average over 300, against the 300 s a test is allowed
under iOS 27. As two, run as that load was coming down, they took 144 s and 173 s on the iPhone
and 140 s and 114 s on the iPad.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchResultAddToCollectionTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
```

**`SearchResultVoiceOverTests` (#1684) runs on an iPhone and an iPad under iOS 27, and nothing skips there.** It is
the first suite to listen to VoiceOver: iOS 27's VoiceOver service for UI tests (`XCUIDevice.shared.voiceOverService`,
Xcode 27.1) turns VoiceOver on in the simulator, moves its cursor (`moveForward()`) and returns what it spoke
(`utterance`), and a flick up (`swipeUp()`) with VoiceOver on moves through the focused element's actions, which
VoiceOver speaks. Its fixture is `FRUS_UI_TEST_SEED_SPOKEN_VOLUME`, a side-loaded volume of three sections that hold
the word "xylograph", which no other fixture holds: a document numbered 7 in `@n` and not in its head, dated and with
a source note classified "Secret; Nodis"; an editorial note numbered 8; and a preface, which is front matter. A
launch without the flag removes the file and its index rows. The search is submitted until the three rows are there.
- `testEachRowSaysWhatItDraws` reads each row's label, "7. UI Test Spoken Document, Washington, May 4, 1962,
  uitest-spoken-01, Classification markings: Secret; Nodis", "8. UI Test Spoken Editorial Note, uitest-spoken-01,
  Editorial Note" and "UI Test Spoken Preface, uitest-spoken-01, Front Matter", then turns VoiceOver on and requires
  it to speak each label and then "Button".
- `testATagIsSaidAndOfferedAsAnActionThatFilters` tags the document from its row's menu (Add Tags…, a tag made in
  the picker titled "Tag 1 Document", Done) and requires the label to end ", Tags: UI Test Spoken Tag"; with
  VoiceOver on the row it flicks up through the actions and requires Add to Collection…, Add Tags…, Filter by UI
  Test Spoken Tag; then, VoiceOver off, it taps the tag's chip and requires "1 result", the document's row, and
  neither of the other two.
- `testSelectionOffersNoActionForATag` tags the document, enters selection from More ▸ Select Results, and requires
  the row's actions, flicked through with VoiceOver, to hold Add Tags… and not Filter by.

**Three things measured about the service** (iPhone 17, iOS 27.0, 2026-10-19), which the suite is written around.
**It returns the first 64 characters of what VoiceOver speaks** ("Toggle filters Button Filter results by volume,
date range, docu"), so speech is compared up to that length and the whole label is read from the element. **The
cursor stops on the last element** and says it again at each step, so a row not met in forty steps is not on the
screen. **A tap goes to the element under it, not to VoiceOver**: a double tap, which a reader uses to do the action
VoiceOver last spoke, opened the editorial note's row when it fell on the screen's centre and the document's own row
when it fell on that row, did nothing on the 23 points of empty list under the rows, and Ctrl-Option-Space did
nothing either. So no test can make VoiceOver do a custom action: the suite reads the action's words from VoiceOver,
drives what it does through the chip's tap, and `SearchResultAccessibilityTests` holds the action to the chip's
function, read from source.

**On the code before #1684** (`v2` at `c9e26509`, with this suite and its fixture): **iPhone 17: 3 tests, 3 failed**, each at the label, which read "UI Test Spoken Document" where the row as drawn was required. The actions VoiceOver
read there were Add to Collection…, Add Tags… and its own Activate Default. **Mutations** (each built and run alone,
the file restored from the commit after each): **two of two caught**. The tags' actions taken out failed `testATagIsSaidAndOfferedAsAnActionThatFilters`, the actions reading Add to Collection… and Add Tags…; the actions offered in selection too failed `testSelectionOffersNoActionForATag`, with Filter by UI Test Spoken Tag among them.

Measured at the final code under iOS 27.0, 2026-10-19, each device alone under the heavy-job lock: **iPhone 17 (`80CF0F18`): 3 tests, 3 passed** (61, 28 and 60 s), and **iPad Pro 13-inch (M5) (`9AB3A0C9`), built into its own build folder and warmed with one test first: 3 tests, 3 passed** (62, 27 and 59 s). A test spends most of its minute on VoiceOver: each flick waits about five seconds for the app to idle.

**Warm the iPhone with one test too** (A10b, 2026-10-20). Twice on iPhone 17 (`80CF0F18`), each time the first test after the unit target had run on the same simulator and the simulator had restarted, `testATagIsSaidAndOfferedAsAnActionThatFilters` failed at its first step, "The row's menu has no Add Tags…": the long press opened no menu. Its recording shows the app indexing volumes under the rows (*Indexing frus1900…*, then *frus1902…*). Alone, or after one test, it passed. At A10b's final code, warmed with `testEachRowSaysWhatItDraws`: iPhone 17, 3 tests, 3 passed (60, 28 and 60 s); iPad Pro 13-inch (M5) (`9AB3A0C9`), 3 tests, 3 passed (60, 26 and 58 s).
```bash
Scripts/heavy.sh xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchResultVoiceOverTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`SearchBulkActionsTests` (#1576 lane 3) runs on an iPhone and an iPad, and nothing skips on either.** It is the only suite that drives a selection of search results. Each of its five tests is its own launch with two fixtures: `FRUS_UI_TEST_SEED_BULK_VOLUME`, a side-loaded volume of thirty documents that all hold the word "quillwort", so a search for it lists a first page of twenty-five and a second of five; and `FRUS_UI_TEST_SEED_PROJECT`, whose collection, "UI Test Unattached Collection", holds one document of another volume. A launch without the first flag removes the volume and its index rows, so no other suite lists it. The search is submitted until its rows are there, five times at most, because the volume is indexed during launch.
- `testPickedRowsAreCountedAndOutliveAPageTurn` enters from More ▸ Select Results, taps two rows and reads "2 selected" and the two rows' selected trait, turns to page 2 and waits for its five rows, then reads the count after This Page (7), All 30 Shown (30) and None (0), and after Done finds the actions bar back.
- `testASelectionIsAddedToACollectionAndUndoTakesItBack` enters from a row's long-press ▸ Select, picks a second row, chooses Actions ▸ Add to Collection…, taps the seeded collection, reads "Added 2 documents to “UI Test Unattached Collection”." and then, after Undo, "Removed 2 documents…", and reads the collection's row back at "1 document" from the picker presented again.
- `testAddingASelectionTwiceSaysTheDocumentsWereAlreadyThere` adds the same two twice and reads "Nothing added: 2 were already in…" with no Undo beside it.
- `testASelectedPageIsMarkedReviewedAndUndoBringsItBack` turns Checklist Mode on, picks the page, chooses Actions ▸ Mark Reviewed, reads "25 reviewed hidden", "0 selected" and five rows, and after Undo "Nothing hidden".
- `testASelectionIsTaggedAndUndoTakesTheTagBack` (#1576 lane 5) picks two rows, chooses Actions ▸ Add Tags…, makes a tag in the picker titled "Tag 2 Documents" and taps Done, and reads "Added “UI Test Tag” to 2 documents." It opens the picker again and reads "All 2 have it" beside the tag, with its switch off; after Undo it reads "Removed “UI Test Tag” from 2 documents." and, from the picker once more, no count beside the tag. **The tag is read back from the picker and not from the rows**: the picker says how many of the two carry it. A row's tag chips are not elements a test can find, though since #1684 the row's label names its tags (`SearchResultVoiceOverTests` reads one). `SearchSelectionModelTests` holds the rows' refresh. Since #1684 the suite finds a row by `label CONTAINS` the title, since a bulk document's row draws its number first and its label begins "1. UI Test Bulk Document 01, uitest-bulk-01". Measured on 2026-10-11 under iOS 27.0: passed on an iPhone 17 (172 s) and on an iPad Pro 13-inch (M5) (226 s).

**On a simulator that has just booted, the first test of a run can fail before it starts.** On 2026-10-10 the suite's first test on a freshly booted iPad Pro 13-inch (M5) failed in two runs running, once when the runner restarted while the app launched and once when the search field never took the keyboard ("Neither element nor any descendant has keyboard focus"), and the three tests after it passed both times. Run by itself after one other test, it passed. It is not the iPad's alone: on 2026-10-11 the first test of `ResultSelectionBarFitTests` on an iPhone SE (3rd generation) booted for that run failed on the same line about keyboard focus, the five after it passed, and it passed when run by itself afterwards; the same night an iPad Pro 13-inch (M5) that had run one test first passed all five of this suite. So on a just-booted simulator run one test first, and read which test failed and at what step: `Executed 3 tests, with 0 failures` beside `TEST EXECUTE FAILED` is this, and the missing test has no verdict line.

The commands are chosen from the selection bar's Actions menu (`search.selection.actions`), by their titles. The counts are read in the app's one context and the UI-test store is in memory, so the suite proves what the screen says and does not prove the save; `CollectionEntryRemovalTests` and `CollectionAttachmentTests` read a store for that. Measured on 2026-10-10 under iOS 27.0, the two devices run at once: **iPhone 17: 4 tests, 4 passed; iPad Pro 13-inch (M5): 4 tests, 4 passed**, in each of three runs. A test took 147 to 259 s with the load average under 50, and 183 to 280 s while other sessions' builds held it between 65 and 165. **The waits are 30 s (`BulkActionsScreen.patience`) because of a third run**: with the waits at 8 s and the load average over 200, all four tests failed on the iPhone and one on the iPad, each on a wait whose text was right by the time the failure was written. Allow 600 s a test when the Mac is busy.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchBulkActionsTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600
```

**`ResultSelectionBarFitTests` (#1576 lane 3, in `SearchBulkActionsTests.swift`) is iPhone-only and wants two widths**, as `SearchActionsBarFitTests` does: an iPhone 17 (402 pt) and an **iPhone SE 3rd generation (375 pt, iOS 27)**. It self-skips at iPad width. With the same two fixtures, Checklist Mode on (it waits for the strip) and the tab shell's banner showing (it fails if the banner is not there), it enters selection at five text sizes and requires: the bar's four controls (`search.selection.done`, `.count`, `.menu`, `.actions`) inside the window's width, in order and apart, and their feet above the banner's head; the mode picker's top under the search field's foot; room between Done and Select for "8,888 selected" at the smallest scale the count draws at; and the first result's top between the bar and the banner. Each accessibility size proves it took effect by the search field's height. A sixth test turns the Collocates reading on at AX5 and requires the mode picker under the search field. Every run prints `[#1576]` lines with the frames and the count's room, pass or fail.

What its assertions beyond the frames guard:
- *A result between the bar and the banner.* The rows above the list (the count header, a command's line, and in Checklist Mode the strip) scroll where they would take more than their share of the column (`SearchView.resultsColumn`). With the rows not scrolling, the suite failed at AX5 on the iPhone 17, the first result's top at y 745 under a banner whose head was at 551; at AX3 there, where the plain rows fit, it passed.
- *The mode picker under the search field, in the Collocates reading.* A view taller than its room is centred by SwiftUI and takes what is attached to it along. The list gives way before that happens, and so, as measured, do the Timeline reading and All Results Reviewed; the Collocates reading has two controls of its own above its list and cannot. `TopAnchoredOverflow`, at the navigation root, keeps the results from reporting more height than they are offered. With the layout taken out, this test failed on the iPhone 17: the picker's top at y 155, the field's foot at 186. The same mutation left a test of the Timeline reading passing, which is why the test is of Collocates.
- *The count's room.* A line of text never draws wider than it is offered, so a count cut short does not show in its frame. The room is worked out from Done's and Select's frames and the row's spacing, and the widest count's width from the system font; the suite carries copies of `ResultSelectionBar.spacing` and `.countMinimumScale`, which `ResultSelectionWiringTests` holds to the same figures. Measured: 123 to 124 pt on the iPhone SE at the accessibility sizes against 111 needed, and 150 to 151 on the iPhone 17. With the Actions glyph drawn at three times its size, the suite failed on the iPhone SE at AX1: 71 pt of room.
- *An identifier on a `Label` names two elements*, its glyph and its words, and a first match can answer with either: at XXXL on the iPhone 17 the checklist strip's count answered "Checklist With Checkmarks". `BulkActionsScreen.waitFor` matches any element with the identifier that holds the text.

**It also decided the lane's design.** The plan put the commands in a bar at the foot of the results, with the rule that if the bar could not clear the banner at 375 pt and the accessibility sizes they would go in one Actions menu in the selection bar. Measured on 2026-10-10 with that bar built: on the iPhone SE at AX5 Mark Reviewed drew at y 334 to 382 under a banner whose top was at y 344, and at AX3 the first result's top (y 283) was under the bar's top edge (y 280); on the iPhone 17 it cleared at all five sizes, with 7 pt left for the list at AX5. So the commands are a menu, and this suite measures one bar.

Measured on 2026-10-10 under iOS 27.0, with the commands in the menu: **iPhone 17: 6 tests, 6 passed; iPhone SE (3rd generation): 6 tests, 6 passed.** From the first result's top to the banner's head there were 381, 303, 251, 162 and 67 pt on the iPhone 17 at L, XXXL, AX1, AX3 and AX5, and 215, 138, 118, 58 and 10 pt on the iPhone SE. A test took 99 to 210 s with the load average under 10, and up to 304 s while other sessions' builds held it between 34 and 143, so allow 600 s a test when the Mac is busy.

**It also guards the More menu's order on a small screen (2026-10-17, #1577 lane 4).** At AX5 an iPhone SE's More menu shows three items and draws the rest only once scrolled to. With lane 4's Search Within These Results command placed after the two save items, the menu showed Save this search, Save as Working Corpus… and that command, and `testBarsFitAtLargestAccessibilitySize` failed "The More menu has no Select Results". The command now follows Select Results, and the suite then passed 6 of 6 on the iPhone SE (`0D979960…`, iOS 27.0). The iPhone 17 (`2CD5886D…`), whose menu shows more items, had passed 6 of 6 with the command before Select Results.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=27.0" \
  -only-testing FRUSExplorerUITests/ResultSelectionBarFitTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600
```

**`MeaningResultsSeamTests` (#1577 lane 3) runs on an iPhone and an iPad, and nothing skips on either.** It is the first suite to reach a Meaning result. A Meaning search needs the 310 MB query encoder, which no simulator has and no test may download, so until this suite every surface a Meaning list reaches was tested below the view. `FRUS_UI_TEST_SEED_MEANING=1`, with `FRUS_UI_TEST_SEED_VOLUME` naming the fixture volume, has `UITestMeaningSeeder` stand in for the encoder and build the searcher over a match-file store of the seam's own: a folder of the temporary directory, made afresh at each such launch, holding one file made for that volume. The searcher's code, the backend, the bundled index and the bundled sign bits are the app's own. **The app's match-file store is not read or written**, so a match file the simulator's app holds for another volume cannot put a row into these lists (a far question's 800 candidates lie in 124 volumes), and a launch without the flag does nothing. The suite also launches with `-frus.semantic.autoDownloadShards <false/>`, the reader's own switch, so the app asks the network for no match file.

What it expects is a fact about the bundled artifacts, held by `UITestMeaningSeederTests` (unit target), which fails first if a regenerated bundle moves it:
- *Every question is answered as the fixture's second document* (`frus1961-63v06` d2), whose three documents with bundled vectors are the 1st, 2nd and 50th of 314,616 by Hamming distance. `testAMeaningSearchListsTheFixtureDocumentsWithTheirScores` reads UI Test Document Two, One and Three, at "Semantic match 100 percent", 32 and 3. They are three of 80 hits: the real volume has 120 documents, 80 of whose rows are among the question's 800 candidates, and the fixture holds three. So the strip above the list reads "77 close matches are not listed: this device's index does not hold those documents." and "720 possible matches in 248 volumes could not be scored." **Since B4 (2026-10-15)** these are EmbeddingGemma 2's bits through its score calibration; through build 50 the three read 100, 65 and 61, of 78 hits, with 722 unscored in 179 volumes.
- *A question that holds the word "afield" is answered as a document of another volume* (`frus1861` d1), none of whose 800 candidates is in the fixture volume. `testAFarQuestionOutsideAnySetListsNoFixtureDocument` asks the near question first and reads its three rows, then asks the far one and reads "No semantic matches yet", no fixture row, and "800 possible matches" in the strip. The near question comes first because an empty list alone shows nothing: a Meaning search that runs before the launch has indexed the fixture lists nothing either.
- *The same far question inside a working corpus of the fixture's documents ranks every member that has a vector.* `testAFarQuestionInsideAWorkingCorpusRanksEveryMemberWithAVector` searches the fixture's phrase in Keywords, saves the six results from More ▸ Save as Working Corpus…, applies the corpus in Filters ▸ My Working Corpora, switches to Meaning and reads Three, Two and One, each at 0 percent: the seam's sign-vector cosines, about 0.27, sit below the calibration's 0.47 offset (`UITestMeaningSeeder`'s header). Through build 50 it read Two, Three and One at 24, 24 and 16. It is the first UI test to save and to apply a working corpus.

**The control, on the tree before #1577 lane 1** (`477ee9b6` with the seeder, the launch's hook, the row's accessibility value and this suite added; iPhone 17, iOS 27.0, 2026-10-11, run twice, the second time with the seam as it landed): the first two tests passed, and the third failed with `"a question from far afield" should list 3 fixture documents`, 0 listed, with the corpus applied ("Leave this working corpus" on screen). That is lane 1's change seen on a screen: before it a Meaning search inside a set took the whole series' closest hundred and kept the members among them.

A row's score is read from its accessibility value ("Semantic match 65 percent"), which lane 3 gave it: on iPhone and iPad a result row is one accessibility element whose label was its heading, and since #1684 is the row as drawn, heading first ("UI Test Document Two, Washington, January 2, 1962, frus1961-63v06"), so the suite reads the heading as the label up to its first comma. The order is read from the rows' frames.

Measured on 2026-10-11 under iOS 27.0, each after one test run first: **iPhone 17: 3 tests, 3 passed (214 s); iPad Pro 13-inch (M5): 3 tests, 3 passed (211 s).** **On 2026-10-15 (B4's second pull request, the Mac loaded by builds):** iPad Pro 13-inch (M5), 3 of 3 passed with the new figures; iPhone 17 (`80CF0F18…`), the first two passed, and `testAFarQuestionInsideAWorkingCorpusRanksEveryMemberWithAVector` failed twice before its Meaning search, "Filters has no My Working Corpora group after 8 swipes", **and the same at `v2` `28dd78a0` without that change**, on the same simulator with the same `-only-testing`. **The cause was Search's, found the same day:** Search read Filters' volume list once, when the tab appeared, and Filters draws My Working Corpora, My Volume Scopes, By Subject and Limit to Volumes only while that list has a volume in it. Boot publishes the search service and reads which volumes the index holds afterwards, in a task of its own, so a Search tab the app opens on can read the set before boot has. Which tab a run opens on is the simulator's: the window's saved scene (`frus.selectedTab` in the app's `Library/Saved Application State`) opens on the tab the last saved state held, and `-frus.activeTab` seeds only a window with none. That iPhone's opens on Search: the app's log put the tab's `.task` on an empty set a second before boot's read began, and Filters saw the saved corpus and no volume. The iPad Pro 13-inch's opens on Collections, so Search appeared when the test tapped it, six seconds after the read had landed. The tree at #1634 (`9d247985`) failed the same way on the same iPhone that day, so the runs of 2026-10-11 passed on that day's saved scene, not on that day's code. `SearchView.reloadAvailableVolumes` now reads the list when the tab appears, when the panel opens and whenever the indexed set changes; `FilterVolumeListTests`, below, is the guard. An iPhone 17 under iOS 26.5, whose window opens on Browse, got past Filters with build 50's model and failed later: `ask` read the rows while the Meaning search that choosing Meaning runs on the field's text was being replaced (Three, Two, One, which is neither list), and the delete keys had left `content"` after the question. `submit` now empties the field with its Clear text button and waits for the list to empty. **With both, after B4's merge: iPhone 17 (`80CF0F18…`), 3 tests, 3 passed; iPad Pro 13-inch (M5) (`9AB3A0C9…`), 3 tests, 3 passed (each beside `FilterVolumeListTests`, 2026-10-15).** In an earlier run that day on the iPad, the one test run first, on the simulator just booted and with a build loading this Mac (load average 172), failed waiting thirty seconds for the Keywords | Meaning picker, which the launch draws only once it has loaded the bundled vectors; that wait is ninety seconds now. Run one test first on a simulator just booted, as for the suites above.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/MeaningResultsSeamTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600
```

**`FilterVolumeListTests` (2026-10-15, in `MeaningResultsSeamTests.swift`) runs on any iPhone or iPad, and nothing skips.** It guards Search's Filters volume list (`SearchViewModel.availableVolumes`), which gates My Working Corpora, My Volume Scopes, By Subject and Limit to Volumes, and which Search read only when the tab appeared until 2026-10-15 (the `MeaningResultsSeamTests` entry above has the finding). The defect needs a volume indexed after the Search tab first appears. `MeaningResultsSeamTests` meets that only where the window opens on Search and boot's read of the index loses the race; this suite makes it certain with two of `UITestBrowseSeams`' seams. `FRUS_UI_TEST_COLD_SEEDED_VOLUME` un-indexes the fixture at launch, and `FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL` finishes its download when the test, on Search, posts the signal; the app's own post-download closure then indexes it, as after any download. The test reads Filters ▸ Limit to Volumes ▸ Volumes before the signal, for the premise (the fixture's row, "Kennedy-Khrushchev", is not there), and again once a keyword search for the fixture's phrase lists its documents (the row is there). A simulator that holds other indexed volumes draws Volumes from the start, so the test looks for the fixture's own row; where none is indexed, the Person header with no Volumes row above it is the answer.

Measured on 2026-10-15 under iOS 27.0. **On the code before the fix it failed at its last assertion on both devices**, with the volume indexed and its documents listed: iPhone 17 (`80CF0F18…`, 84 s), whose app logged the list at 0 volumes after the index had marked the fixture, and iPad Pro 13-inch (M5) (`9AB3A0C9…`, 114 s), whose list stayed at the two other volumes it holds. **With the fix: iPhone 17, 1 test, 1 passed (103 s); iPad Pro 13-inch (M5), 1 test, 1 passed (107 s).**
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/FilterVolumeListTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600
```

**`SearchWithinResultsTests` (#1577 lane 4) runs on an iPhone and an iPad, and nothing skips on either.** It drives Search Within These Results end to end through lane 3's Meaning seam (`FRUS_UI_TEST_SEED_MEANING`; the `MeaningResultsSeamTests` entry above says what the seam answers and why): the near question's Meaning list of the fixture's three documents with vectors, Two, One and Three at 100, 32 and 3 percent, and the fixture's phrase, `"Synthetic UI-test content"`, which lists all six of its documents, the three with no vectors among them. Six tests, each reading the screen and not the model:
- *Words in a Meaning list.* More ▸ Find Words in These Matches holds the three. The row that names the base reads "Searching within 3 closest matches to “…”" to VoiceOver (it shows "Within …"), the Keywords | Meaning control has gone, the field's prompt is "Words to find in these matches…", and the three stay listed until words are typed. "Two OR Three" then lists Two and Three, in the list's order, at 100 and 3 percent, under "2 of your 3 closest matches contain these words".
- *A keyword list ranked by a question.* Sort ▸ Closest to a Question… holds the six, and the near question lists Two, One and Three first at 100, 32 and 3 percent, under "6 results · 3 ranked · 3 not ranked", with the line "3 results not ranked by meaning" below the last of them and a row with no vector under the line (on a phone the list is dragged up a third to draw it).
- *Closing the row* puts back "3 closest matches", the control on Meaning, the question in the field and the three rows, with no search.
- *Words found nowhere* read "None of your 3 closest matches contains these words" and offer Back to the 3 Matches and Search the Whole Library for These Words, with no "No semantic matches yet"; Back puts the list back, and the whole library leaves the base and searches the words as keywords.
- *A recalled saved search*, a hand-off, leaves the base, and Save this search is dimmed while one is held.
- *Swap* (#1577 lane 7). The words `"Synthetic UI-test content" Two`, which only Two and Nested Document Two hold and no published document does, are found in one of the near question's three closest matches ("1 of your 3 closest matches contains these words"); no Swap shows before that search. Swap, read as "Swap the two searches", then lists both documents that hold the words: the row reads "Searching within 2 results for “…”", the header "2 results · 1 ranked · 1 not ranked", Two at 100 percent, and Nested Document Two, which has no vector and which the Meaning list never held, under "1 result not ranked by meaning"; the field holds the question. Swapped back, the row names the three closest matches again, the words are found in one of them, and the field holds the words.

Two things the suite does because a run without them failed. **It waits for the Meaning engine before any More menu** (`LayerScreen.chooseFromTheMoreMenu`): the ranking command in that menu is dimmed until the launch has built the engine, and a menu whose contents change while it is open is rebuilt under the tap (measured: "Save this search opened no sheet", and at AX3 the ranking command found and then gone). **On a small screen it scrolls the More menu**, which draws only the items in view. Until the Save Search sheet's fix (2026-10-18, `SaveSearchSheetTests` below) the recalled-search test also typed a space after the sheet's name before Save, which the sheet left off until the name was edited (iPhone 17 and iPad Pro 13-inch (M5), iOS 27.0); it saves the name as offered now.

**The control** (`v2` at `632dc509` with this suite added, iPhone 17 `2CD5886D…`, iOS 27.0, 2026-10-17): 5 tests, 5 failed, each at its way in after its fixture search had listed the documents: "The More menu has no "Find Words in These Matches"" (three), "The Sort menu has no Closest to a Question…" and "The More menu has no "Rank These Results by a Question"".

Measured on 2026-10-17 under iOS 27.0 at the final code: **iPhone 17 (`2CD5886D…`): 5 tests, 5 passed (627 s); iPad Pro 13-inch (M5) (`B2FF6BBE…`): 5 tests, 5 passed (696 s)**, none skipped. A test took 90 to 227 s, the ranking the longest. On the way there the recalled-search test failed on its own, each time fixed in the test: the More menu opened before the engine booted ("Save this search opened no sheet"); a name typed over the sheet's own, which on the iPhone came out unlike the name the test then looked for ("The saved search is not listed") and on the iPad left the sheet open ("The sheet did not close", cause not seen); and Save left off because nothing edited the name ("The sheet's Save … is off", seen in the run's recording on both devices). **At the Save Search sheet's fix** (2026-10-18, the recalled-search test saving the offered name with nothing typed, each run with `SaveSearchSheetTests`): iPad Pro 13-inch (M5) (`B2FF6BBE…`), 5 tests, 5 passed, the recalled-search test in 163 s; iPhone 17 (`2CD5886D…`), 5 tests, 4 passed and 1 failed: the ranking test, at "No row names the held base", with the hierarchy taken at the failure showing the Sort menu still open and Closest to a Question… in it, so the tap on the item did not take. Run alone on the same build and simulator it passed (209 s). The recalled-search test passed in 136 s.

**With Swap** (#1577 lane 7, 2026-10-18, iOS 27.0, nothing building beside it): iPhone 17 (`EBCC150E…`), 6 tests, 6 passed (1,234 s; the Swap test 250 s), with `SearchWithinTheWholeMatchTests` 1 of 1 (152 s); its first attempt started no test ("Timed out waiting for AX loaded notification") and ran once the simulator was rebooted. iPad Pro 13-inch (M5) (`E35529EB…`), alone under the heavy-job lock after a restart: 6 tests, 6 passed (199 s; the Swap test 30 s), with `SearchWithinTheWholeMatchTests` 1 of 1 (20 s). **The control** (`v2` at `ee3b4431` with only this file's lane 7 version added, iPhone 17, iOS 27.0, 2026-10-18): the Swap test failed (51 s) at "The row offers no Swap once a search has run inside the list", after the words were found in the list, and the fit suite's L test (112 s) at "The row offers no Swap at L", after its first measurement had passed.

**With the phrase quoted once** (plan of record §6g, 2026-10-19, iOS 27.0, nothing building beside it): the two labels for the list held from the fixture's phrase read "Searching within 6 results for “Synthetic UI-test content”", the phrase's own marks no longer inside the row's, and the Swap test's label for `"Synthetic UI-test content" Two`, a phrase beside a word, keeps them. iPhone 17 (`80CF0F18…`): 6 tests, 6 passed (159 s), with `SearchWithinTheWholeMatchTests` 1 of 1 (20 s). iPad Pro 13-inch (M5) (`9AB3A0C9…`, built for it): 6 of 6 (164 s), and the whole-match test 1 of 1 (19 s). The suite had passed with the doubled form at lane 7, so the new labels fail on the code before the fix. Typed by hand into the same fixture, the phrase came out curly in the field (Smart Punctuation, which the suite's typing does not trigger), and the row quoted it once all the same.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchWithinResultsTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`SearchLayerBaseRowFitTests` (#1577 lane 4, in `SearchWithinResultsTests.swift`) is iPhone-only and wants two widths**, as `SearchActionsBarFitTests` does: an iPhone 17 (402 pt) and an iPhone SE (3rd generation) (375 pt, iOS 27). It self-skips at iPad width. The row that names a held base takes the Keywords | Meaning control's place, which ran off both edges once (#1307). At five text sizes the suite holds the six-document keyword list (More ▸ Rank These Results by a Question, the longest sentence the fixture can give the row), puts away the keyboard the hold raised (the tab shell's banner gives way to a keyboard, #1070), and requires: the row, its ✕ and the actions bar's five controls inside the window's width; the sentence ending before the ✕; the ✕ at least 44 points each way; the row under the search field's foot and above the actions bar; and the first result between the bar's foot and the banner, whose head the bar stays above. It requires the banner, which a simulator with no iCloud account always shows, as `ResultSelectionBarFitTests` does. **Since #1577 lane 7 each size measures the row a second time with Swap on it**, which the row offers once a search has run inside the held list: the near question's Meaning list, whose sentence is the longest the fixture gives the row, held, with "Two" found in it; Swap must end after the sentence and before the ✕, inside the width, 44 points tall, with a result still above the banner (`[#1577 lane 7]` lines). Lane 7 took the second measurement at L, XXXL and AX1 only: the way there passes through a plain Meaning list, whose strip at AX3 and AX5 made the top inset taller than an iPhone 17's screen (More at y −394, the list below the screen, so the near question listed nothing on screen). Since the Meaning strip's fix (#1721, 2026-10-18, the `MeaningStripFitTests` entry below) AX3 and AX5 take it too. Each accessibility size proves it took effect by the search field's height, every run prints `[#1577]` lines with the frames, and each frame is read once: a read is a query, 4 to 13 s apiece under Xcode 27.1, and reading them as needed took the first test past 10 minutes on a loaded Mac.

**What it found** (2026-10-17). At AX3 and AX5 on the iPhone 17 the top inset was taller than the screen once a list was held: the row's sentence took three lines (156 pt at AX5) where the control takes one, and over a held keyword list the Meaning strip's opening sat under the actions bar. SwiftUI centred the inset, which put the row above the screen (y −143 to 13 at AX5) and the first result below it (y 952 of 874). Capped at AX1, as the selection bar is, the row still took three lines on the iPhone SE, and at AX5 the first result started 9 pt under the banner's head. The row now draws its text at XXXL in two lines at most at the accessibility sizes, and the strip waits until a question has ranked the list.

**The control** (`v2` at `632dc509` with this suite added, iPhone 17, iOS 27.0, 2026-10-17): 5 tests, 5 failed, "The More menu has no "Rank These Results by a Question"".

Measured on 2026-10-17 under iOS 27.0 at the final code, each frame read once: **iPhone 17 (`2CD5886D…`): 5 tests, 5 passed (1,011 s); iPhone SE (3rd generation) (`0D979960…`): 5 tests, 5 passed (820 s).** From the first result's top to the banner's head there were 436, 384, 350, 272 and 133 pt on the iPhone 17 at L, XXXL, AX1, AX3 and AX5, and 271, 220, 185, 65 and 15 pt on the iPhone SE. The row was 15 pt tall at L and 47 at XXXL and above on the iPhone 17 (34 and 47 on the SE), and its ✕ 44 by 44 points (a fraction under 44 tall at AX3 and AX5 on the iPhone 17, inside the suite's half-point tolerance). A test took 139 to 228 s. Reading each frame as needed, the same tests took 355 to 512 s, and the SE's first, which launches twice, went past 600 s at a load average over 100: allow 600 s.

**With Swap** (#1577 lane 7, 2026-10-18, iOS 27.0): **iPhone 17 (`EBCC150E…`): 5 tests, 5 passed**: L, XXXL and AX1 in one run (362, 276 and 348 s), and AX3 and AX5 again once the Swap measurement was kept to the first three (168 and 204 s), since the first run's AX3 and AX5 failed on the way there, at the plain Meaning list; **iPhone SE (3rd generation) (`082FF7C0…`): 5 tests, 5 passed (213 s)**, alone under the heavy-job lock. The first measurement read lane 4's figures exactly on both. With Swap on the row there were 443, 329 and 306 pt from the first result to the banner at L, XXXL and AX1 on the iPhone 17, and 278, 165 and 141 on the iPhone SE; Swap was 57 by 44 points at L and 77 or 78 by 44 from XXXL up, and at XXXL the sentence took three lines (71 pt, where it takes two without Swap).

**At all five sizes with Swap** (the Meaning strip's fix, #1721, 2026-10-18, iOS 27.0, each run alone under the heavy-job lock, beside the three other fit suites): **iPhone 17 (`DEAE891C…`): 5 tests, 5 passed; iPhone SE (3rd generation) (`1B365EFB…`): 5 tests, 5 passed**, 44 to 53 s a test. The first measurement and the second at L, XXXL and AX1 read the figures above exactly. With Swap on the row there were 160 and 90 pt from the first result to the banner at AX3 and AX5 on the iPhone 17, and 56 and 8 on the iPhone SE, where at AX5 the result's top is a sliver above the banner, as the selection bar's is (`ResultSelectionBarFitTests`, 10 pt).
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchLayerBaseRowFitTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`SaveSearchSheetTests` (in `SearchWithinResultsTests.swift`) runs on an iPhone and an iPad, and its test must stay the launch's first Save this search.** It lists the fixture's six documents by their phrase (the `SearchWithinResultsTests` entry above says what the fixture holds), opens More ▸ Save this search, and requires the sheet's name field to hold the phrase and its Save to be on within 30 s, with nothing typed; then Save must close the sheet, and Saved searches must list a search under that name (the store is in memory under `FRUS_UI_TEST_MODE`, so the row is that launch's). One test, which never skips; the sheet is one view on both devices.

**The defect it guards** (found 2026-10-17 by `SearchWithinResultsTests`): the sheet opened with the search's words in its name field and its Save off, and Save came on only once the name was edited. More ▸ Save this search set the name and the sheet's Bool, two `@State`s of `SearchView` that its body never read, so the body did not run again, and the sheet was built from the closure made before the tap. **Measured** with a temporary probe, `Logger` lines in the command's action, `SearchView.body`, the sheet's content, its Save item and its `onAppear` (iPhone 17 `2CD5886D…`, iOS 27.0, 2026-10-18): the action set the name to the phrase and the Bool to true; no body ran after it; the sheet's content read the name as empty and its own Bool as false, and built Save disabled; `onAppear`, outside the update, read both as set; and no body ran again for 44 s, while the test's wait found Save off at each of its six checks, until its teardown tapped Cancel. The field showed the words because a binding reads the stored value; Save's `.disabled` was worked out once, from the old name. #1590's `SummarizationPromptCopyTests` guards the same shape, and like it this needs the first presentation of a launch: anything that reads the name first hides it. The fix is #1590's: the command makes a `SaveSearchRequest` (the words, and the search it saves), the screen presents `.sheet(item:)`, and `SaveSearchSheet` keeps the name as its own state. The Mac's Search window built its own sheet the same way, with the same defect (the Mac check copy at `f83acb37`, on a fresh launch: Save drawn dimmed at 1 s and 6 s, and a click on it did nothing); it presents `SaveSearchSheet` too now, with the Mac body it had.

**The control** (`v2` at `f83acb37` with this suite added, iOS 27.0, 2026-10-18): iPhone 17 (`2CD5886D…`) 1 test, 1 failed (92 s), and iPad Pro 13-inch (M5) (`B2FF6BBE…`, booted for the run) 1 test, 1 failed (221 s), both at "Save is off though the sheet offers the name". At the fix, run with `SearchWithinResultsTests`: iPhone 17, the guard passed (84 s), Save on at the wait's first check; iPad Pro 13-inch (M5), the guard passed (194 s), Save on at the wait's first check, and passed again after a reboot (189 s). The iPad's first run at the fix stalled before its first step: the app it launched stayed at about 100% of a core and never went idle ("App event loop idle notification not received") while another session's build drove the load average to about 900 and the Mac paged; that run was stopped, its app terminated, and the run above made once the load fell.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/SaveSearchSheetTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`SearchWithinTheWholeMatchTests` (#1577 lane 6, in `SearchWithinResultsTests.swift`) runs on an iPhone and an iPad, and nothing skips on either.** It is the one suite that reaches a list cut at its ceiling, which a question ranks whole. No fixture holds more than thirty documents one search matches, so the launch lowers the ceiling: `FRUS_UI_TEST_SEARCH_CEILING=4` (`UITestSearchCeiling`, DEBUG-only and inert without `FRUS_UI_TEST_MODE`) fetches a search with text in it at four rows, and the fixture's phrase, which all six of its documents hold (the `SearchWithinResultsTests` entry above), lists four of them, "4 loaded · 6 total". The suite waits for that header rather than for titled rows, since which four the keyword engine loads is its own. Sort ▸ Closest to a Question… holds the list, and the row must read "Searching within all 6 results for “Synthetic UI-test content”" to VoiceOver, the phrase quoted once (plan of record §6g; until 2026-10-19 it read “"Synthetic UI-test content"”, the phrase's own marks inside the row's). The near question must then rank all six, not the four loaded: "Closest 3 of 6 results · 3 not ranked", Two, One and Three at 100, 32 and 3 percent, and "1 result not ranked by meaning" over one of the list's own unranked rows, the room the ceiling of four leaves. One test.

**The control** (`v2` at `b222fcb7` with the seam and this suite added, iPhone 17, iOS 27.0, 2026-10-18): **1 test, 1 failed (141 s)**, at the row that names the base, which there reads "Searching within the first 4 of 6 results for “"Synthetic UI-test content"”": lane 4 ranked the four rows loaded.

Measured on 2026-10-18 under iOS 27.0 at the lane's last code commit (`799f9813`), run with `SearchWithinResultsTests` and nothing building beside them: **iPhone 17 (`E32250EF…`): 1 test, 1 passed (162 s); iPad Pro 13-inch (M5) (`4A953DF9…`): 1 test, 1 passed (90 s)**, and `SearchWithinResultsTests` 5 of 5 on each. At the lane's first app commit the same test had passed in 237 s and 202 s; that iPhone's first run never started its test, its runner "Timed out waiting for AX loaded notification", and after the simulator was rebooted it ran. At plan of record §6g's fix (2026-10-19), run with `SearchWithinResultsTests`: iPhone 17 (`80CF0F18…`) 1 of 1 (20 s), iPad Pro 13-inch (M5) (`9AB3A0C9…`) 1 of 1 (19 s).
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0" \
  -only-testing FRUSExplorerUITests/SearchWithinTheWholeMatchTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```

**`MeaningStripFitTests` (in `MeaningResultsSeamTests.swift`) is iPhone-only and wants two widths**, as `SearchActionsBarFitTests` does: an iPhone 17 (402 pt) and an iPhone SE (3rd generation) (375 pt, iOS 27). It self-skips at iPad width. It is the suite of plain Meaning mode at five text sizes, which no suite measured at the accessibility sizes before it. Each test chooses Meaning and asks lane 3's near question (`FRUS_UI_TEST_SEED_MEANING`; the `MeaningResultsSeamTests` entry above says what the seam answers) until the Meaning strip says "77 close matches are not listed", which only the run that listed the fixture's three says, puts the keyboard away, and requires: the Keywords | Meaning control and the actions bar's five controls inside the window and under the search field's foot, the bar under the control and above the banner; the strip starting under the bar and above the banner, with "77 close matches are not listed" and "720 possible matches in 248 volumes could not be scored" in what VoiceOver reads of it; at the accessibility sizes the strip one row with its ⓘ inside it, 44 points each way, no less (a target) and no more (the row is drawn at XXXL at most), and the row no taller than its ⓘ, and at the standard sizes no ⓘ; and the first result between the strip and the banner. A sixth test opens the ⓘ at AX5 and requires the sheet to hold the opening and the two disclosures as three paragraphs, one under another, the first under the sheet's navigation bar, and Done to close it. It requires the banner, which a simulator with no iCloud account always shows, as `ResultSelectionBarFitTests` does. Each accessibility size proves it took effect by the search field's height. Every frame is read from one accessibility snapshot (`XCUIElement.snapshot()`), as `TabShellBannerClearanceTests` reads its lists, and every run prints `[Meaning strip]` lines with the frames and attaches a screenshot of each screen it measured, pass or fail.

**What it found** (2026-10-18; lane 7's `SearchLayerBaseRowFitTests` had met it on the way to the row with Swap). On `v2` (`ee3b4431`), after the near question, the strip's caption is about 400 characters: the opening, "77 close matches are not listed: this device's index does not hold those documents." and "720 possible matches in 248 volumes could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring." Grown with the text it made Search's top inset taller than the screen, and SwiftUI centred the inset. The strip was 126, 251, 377, 857 and 1,530 pt tall at L, XXXL, AX1, AX3 and AX5 on the iPhone 17, and 126, 274, 404, 896 and 1,785 on the iPhone SE. The control and the bar were on screen at L, XXXL and AX1 on the iPhone 17 (27 pt left above the banner at AX1) and at L and XXXL on the iPhone SE (11 pt at XXXL); at AX1 on the SE the control sat behind the search field (y 39 under a foot at 88) and the first result under the banner; at AX3 More was at y −22 on the iPhone 17 and −188 on the SE, and at AX5 at −394 and −646, with no result row in the tree.

**Three ways were measured**, each with a throwaway switch in the app at AX3 and AX5 on both iPhones, and all three passed the suite there. The room from the first result to the banner at AX5 was 15 / 135 pt (SE / iPhone 17) with the strip capped at XXXL in two lines and the whole caption in the Large Content Viewer, as `SearchLayerBaseRow` is; 22 / 147 with one 44-pt row and an ⓘ that opens the caption in a sheet; and 44 / 126 with the strip moved among the rows that scroll above the results, where it was read through a window about 37 pt tall on the SE and 120 on the iPhone 17, with the results' count scrolled out of view under it. **The Large Content Viewer could not hold the caption**: touched and held at AX5 on the iPhone 17 (the system's text size at AX5 as well), it drew the caption in a column about 170 pt wide that ran off the top and the bottom of the screen, its opening and its last sentence unreadable, and it does not scroll. The owner chose the row and the sheet (2026-10-18): `SemanticModeStrip` at the accessibility sizes, `SemanticModeStripCaptionSheet`.

**The control** (`v2` at `67a3a0b7`, the strip as it was, with this suite as it now is, iOS 27.0, 2026-10-18): **iPhone 17: 6 tests, 4 failed; iPhone SE: 6 tests, 4 failed**, L and XXXL passing on both. At AX1 the iPhone 17's layout fits (27 pt above the banner) and the test fails on "The strip offers no ⓘ at AX1"; the SE's control is behind the search field (y 39.5 under a foot at 88) and its bar's top is too. At AX3 and AX5 the control and the bar's five controls are above the screen on both, and no result row is in the tree. The sixth test fails on both at "The strip offers no ⓘ at AX5".

Measured on 2026-10-18 under iOS 27.0 at the final code, each device alone under the heavy-job lock, with `SearchActionsBarFitTests`, `SearchLayerBaseRowFitTests` and `ResultSelectionBarFitTests` in the same run: **iPhone 17 (`DEAE891C…`): 6 tests, 6 passed; iPhone SE (3rd generation) (`1B365EFB…`): 6 tests, 6 passed**, 12 to 51 s a test, and the run's 23 tests 23 passed on each (592 and 580 s). From the first result's top to the banner's head there were 353, 178, 364, 286 and 147 pt on the iPhone 17 at L, XXXL, AX1, AX3 and AX5, and 188, 11, 199, 79 and 22 pt on the iPhone SE. The row was 43 or 44 pt tall at every accessibility size on both, its ⓘ 44 by 44 (a fraction under 44 tall at AX1 on the iPhone 17, inside the half-point tolerance); L and XXXL drew the strip as `v2` did, 126 and 251 pt on the iPhone 17 and 126 and 274 on the SE. In the sheet at AX5 the three paragraphs ran from y 148 to 2,043 on the iPhone 17 and from 106 to 2,188 on the SE, the opening alone 869 and 993 pt tall.

**A/B by mutation** (2026-10-18, iPhone SE, each mutation built and run alone, the file restored after each): **five of five caught**, each by the assertion written for it. The ⓘ's 44-point frame removed: "The ⓘ is under 44 points wide at AX1" (27 by 27). The caption taken out of what VoiceOver reads of the row: "the strip never said "77 close matches are not listed"", then "VoiceOver does not read…". The sheet's paragraphs joined into one: "1 is not equal to 3". The row drawn at the standard sizes too: "The strip offers its ⓘ at L, a standard size". The row's XXXL cap removed: it passed at first, since the row still left room for a result, but at AX5 its words were cut to "Meaning…", which no frame shows, and the ⓘ grew to 62 points; the suite now holds the ⓘ to 44 points and the row to its ⓘ's height, and the same mutation failed at AX3 and AX5 ("The ⓘ grew past 44 points"). A sixth, the sheet hung inside the row's cap, changed nothing: a presentation does not take the cap, and the sheet's paragraphs measured the same.
```bash
Scripts/heavy.sh xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=27.0" \
  -only-testing FRUSExplorerUITests/MeaningStripFitTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600
```
