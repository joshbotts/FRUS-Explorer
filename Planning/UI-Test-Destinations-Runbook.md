# UI test destinations runbook

Which simulators each UI suite needs, what it measured, and the commands. `CLAUDE.md`'s *Build &
Test Commands* section holds the index (suite, devices, expected counts) and the four rules that
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
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad mini (A17 Pro)" \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 \
  -only-testing FRUSExplorerUITests/BrowseNestedSectionTests/testLevelStateSurvivesTheTwoPaneGate
```

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
three failed on the pre-fix editor on iPhone 17 and on iPad Pro 13-inch (M5). Expect **8 tests with 0 skipped on iPhone
17** and **8 with 3 skipped on iPad Pro 13-inch (M5)**. The suite passed on an iOS 27.0 iPhone 17 when it had its first
3 tests (pass the iOS 27 timeout flags below), and all 8 ran on an iOS 27.0 iPad Pro 13-inch (M5) on 2026-10-01 with
those flags, 5 passing and 3 skipping; the 5 added by #1415 and #1413 have not been run on an iOS 27 iPhone.
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

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionEditorTitleTests
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

**Run them on `OS=26.5`: under iOS 27.0 an iPad simulator kills each test that opens Corpus
Analytics (#1620).** Measured on 2026-10-09 on this Mac, one build, an iPad mini (A17 Pro) shut down
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
every launch lemmatised: read the printed line. Each run's `NaturalLanguageReadinessWarmUpTests`
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
leaving the iPhone 17 a plot that size drew every bar's row 36 pt wide, which the 150 pt floor fails. No iPad has
been run, so the iPad half is reasoned. Expect **1 test, 1 passed**. The Mac, where #1473 was found at 720–820 pt,
has no UI target: `RankingChartAxisTests` draws the chart at 720, 820 and 402 pt and counts the bars in the
pixels, and the by-eye check is the owner's.

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
`name=` alone picks one of several runtimes on this machine, so pin the OS the figures came from:

```bash
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionProseRowRestTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300

xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone Air,OS=26.5" \
  -only-testing FRUSExplorerUITests/CollectionProseRowRestTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
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

**`AnalyticsCompareFromTableTests` (#1583) needs no index; on an iPad simulator under iOS 27.0 its
run is killed at teardown, as every suite that opens Corpus Analytics is (#1620), so an iPad run
is made on `OS=26.5`.** It
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
day**, in the run of ten the keyboard suites' entry above records. An iPad run under iOS 27.0 still
says nothing either way.
```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerUITests/AnalyticsCompareFromTableTests \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300
```
