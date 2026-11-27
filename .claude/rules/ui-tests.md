---
paths:
  - "FRUSExplorerUITests/**"
  - "Planning/UI-Test-Destinations-Runbook.md"
---

# UI suites: the index, and the five rules for every UI run

Claude Code loads this file when a session reads or edits a file its `paths` name. A session that
only runs a suite, and a lane's agent, read it first (`CLAUDE.md`, *UI suites*). Everything below
this paragraph was moved here from `CLAUDE.md`'s *Build & Test Commands* word for word on 2026-11-26.

Add a new suite's row here and its entry to `Planning/UI-Test-Destinations-Runbook.md`. Claude Code
reads only the first 40,000 characters of a file like this one: a row gives devices, counts and
skips, and what a suite measured goes in its runbook entry.

**UI suites: which devices, and where the detail is.** One destination gives one idiom's tests, and
a suite that self-skips on the wrong device reports green. Each suite's full entry is in
`Planning/UI-Test-Destinations-Runbook.md`: why it needs those devices, the counts and skips to
expect, what it measured on the unfixed code, and the exact commands. **Read a suite's entry before
you run it, change it or read its result as a guard** (`grep -n '<SuiteName>'` finds it). The table
is the index, not the entry.

| Suite (name the TYPE in `-only-testing`) | Run it on | Expect |
|---|---|---|
| `UIObstructionTests` | an iPhone and any iPad | scenario 4 (#238) self-skips on an iPhone |
| `BrowseNestedSectionTests` | iPad Pro 13-inch (M5) and iPhone 17; `testLevelStateSurvivesTheTwoPaneGate` on iPad mini (A17 Pro) | 11 tests: 3 skipped on the iPad, 4 on the iPhone; allow 600 s a test on the iPhone and 1,500 on the iPad, which takes both allowance flags |
| `TopicIndexArrivalTests` | iPad Pro 13-inch (M5), two-pane, and iPhone 17 | 3 passed on each; it never skips, so one device alone is not the guard |
| `CollectionEditorTitleTests` | iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`; iPad Air 11-inch (M4), `OS=26.5` | 9 tests: 0, 3 and 3 skipped; allow 600 s a test; only the Air folds ＋ Add into the overflow; only the iPads guard Link to Saved Search… (#1704) |
| `CollectionProseRowRestTests` (in `CollectionEditorTitleTests.swift`) | iPad Air 11-inch (M4) and iPhone Air, both `OS=26.5` | 5 tests, 0 skipped on each; allow 600 s a test |
| `CollectionListManagementTests` (in `CollectionEditorTitleTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0` | 4 tests, 0 skipped on each; never skips; the dialog is an action sheet on the iPhone and a popover on the iPad (#1823); allow 600 s a test |
| `CollectionRowDeleteTests` (in `CollectionEditorTitleTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0` | 2 tests, 2 passed on each; never skips; a note block with text asks on its swipe and a document at its defaults goes at once; under iOS 27 the dialog is a popover pointing at the row on both; fails on the code before L19 at the note block's dialog (#1919), where the untouched document's test fails too but guards nothing; allow 600 s a test |
| `CollectionListSwipeDeleteTests` (in `CollectionEditorTitleTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.2` and `OS=27.0` | 1 test, 1 passed on each; never skips; launches with animations on, swipes a collection and requires its question up two seconds later with the collection listed; fails on the code before R6a at the swipe's question, which closes as it opens (F10, iPhone 17 under 27.2); allow 600 s a test |
| `VolumeScopeSwipeDeleteTests` (in `CustomScopeSaveTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.2` | 1 test, 1 passed on each; never skips; passes on the code before R6a too: it is the measurement behind F10's sweep leaving the swipes whose question hangs on the list, not the row; allow 600 s |
| `CollectionInspectorOpenDocumentTests` (in `CollectionEditorTitleTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0` | 1 test, 1 passed on each; never skips; the iPhone's drill-in and the iPad's Configure sheet are different code; fails on the code before L19 at Open Document (#1919) |
| `SelectionEditMenuTests` (in `ResearchReadingStaysInTabTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0` | 4 tests, 4 passed on each; never skips; green on iPhone 17 under 26.5 too; under iOS 27.0 a press raises the menu only when WebKit's selection lands before the lift, so it holds its press 3 s and taps the selected word when no menu comes, and the menu's › is `Next Page` there |
| `NoteEditorUnsavedChangesTests` (in `ResearchReadingStaysInTabTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 3 tests, 3 passed on each; never skips; under iOS 27 its dialogs are popovers on the iPhone too; only the iPad taps beside the sheet, which asks nothing and must lose nothing; fails on the code before L19 at the swipe's dialog and at Delete's, and on the iPad there Delete crashes the app (#1919); on a simulator just booted, run one test first |
| `AllNotesFollowsOtherDevicesTests` (in `ResearchReadingStaysInTabTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; the app adds a note and deletes the seeded one through a second context on Darwin signals (`FRUS_UI_TEST_NOTES_ON_SIGNAL`), as an iCloud import writes, with All Notes open; fails on the code before R6a at the added note, which the open list never shows (F4); allow 600 s a test |
| `AddToCollectionAnnouncementTests` (in `ResearchReadingStaysInTabTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; skips below iOS 27; listens through iOS 27's VoiceOver service and double-taps the picker's row as VoiceOver does; run it alone on a simulator shut down before it, as `SearchResultVoiceOverTests`' cases; fails on the code before L19, which says only the row's name (#1919) |
| `RailAtCompactWidthTests` (in `ResearchReadingStaysInTabTests.swift`) | iPad Pro 13-inch (M5), `OS=27.0`; its narrowing test under `OS=27.2`, in Windowed Apps | 2 tests, 2 passed; iPad only (an iPhone skips); reads the stored rail setting, never a launch argument's, and leaves it on; fails on the code before L19 at the toggle's tap in Project Home's sheet, which opens no rail (#1919); the narrowing test resizes the window by its corner grip, skips where it cannot, and fails on the code before R6a at narrowing 1, where an empty sheet is left over the reader (F8); allow 900 s |
| `FacetsAtCompactWidthTests` (in `ResearchReadingStaysInTabTests.swift`) | iPad Pro 13-inch (M5), `OS=27.2`, in Windowed Apps | 2 tests, 2 passed; iPad only (an iPhone skips); a Year staged in Facets stays staged and unapplied through three narrowings, and a swipe closing Facets' compact sheet applies it (IPH-3); fails on the code before R6a at narrowing 1, which applied the staged Year; allow 900 s |
| `ResearchReadingDepthTests` | iPad mini (A17 Pro) | skips on an iPad whose portrait is already two-pane |
| `AnalyticsKeyboardTests`, `KeyboardDismissBarReachTests`, `ToolbarOverflowAccessibilityTests` | iPad mini (A17 Pro), `OS=27.0` (since L27); `KeyboardDismissBarReachTests`' year-range test on `OS=26.5` as well | 9 tests, 0 skipped; green on iPhone 17 and iPad Pro 13-inch too, but only the mini catches a restored analytics window (#1279); under 27.0, 8 passed: #1835's Browse-root test passes, and the year-range test fails because the popover's own keyboard goes down after the test's 5-s wait (#2024); it passes under 26.5 |
| `SearchActionsBarFitTests` | iPhone 17 and iPhone SE (3rd generation), iOS 27 | iPhone-only; self-skips at iPad width |
| `SearchHitAreaTests` (in `SearchTipsSheetTests.swift`) | iPhone 17, iPhone SE (3rd generation) and iPad Pro 13-inch (M5), `OS=27.0` | 7 tests, 7 passed on each; never skips; taps beside or below each small control, inside its 44 pt and outside its glyph; on the code before #1918's IPH-5 its four menu taps fail and its Filter and pager taps pass, since the system already takes a tap that close to a button, so the menus' four are the guard; allow 600 s a test |
| `AuxWindowCloseTests` | iPad Pro 13-inch (M5), `OS=27.0`, in Windowed Apps | iPad-only; which cases guard depends on the multitasking mode |
| `VolumeRemovalTests` | an iPad on iOS 27 and one on iOS 26, full screen | 5 tests, 0 skipped; an iPhone skips the 2 popover-anchor tests |
| `DownloadCancelAllTests` (in `VolumeRemovalTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 2 tests, 2 passed on each; never skips; six volumes queued and held by the download seam (`FRUS_UI_TEST_DOWNLOADS=hold`), with no network; under iOS 27 the question is a popover on both, closed by a tap at its dismiss region's corner; fails on the code before L20 at Cancel All (#1920); allow 600 s a test |
| `OnboardingBackCancelsDownloadsTests` (in `VolumeRemovalTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; launches into onboarding with the seam holding Corpus's downloads, then reads Volumes & Storage after Back, Skip and Finish; fails on the code before L20 at Active Downloads (#1920); allow 600 s a test |
| `ResearchSidebarSelectionTests` | iPad Pro 13-inch or iPad Air 13-inch | 2 tests, 0 skipped; an iPhone run is a skip |
| `BrowseRootSelectionTests` (in `TwoPaneDocumentTests.swift`) | the same 13-inch iPads | 4 tests, 0 skipped; an iPhone run is a skip |
| `CrossReferenceMatrixScrollTests` (in `AnalyticsRotationTests.swift`) | iPad Pro 11-inch (M5) and iPhone 17 | 5 tests: 1 skipped on the iPad, 2 on the iPhone |
| `CrossReferenceRankingChartTests` (same file) | any iPhone or iPad | 3 tests, 3 passed; never skips; two tap a bar and its title and find the document open (#1797) |
| `BrowseWithinScopeTests` | iPad Pro 11-inch (M5) and iPhone 17 Pro, both `OS=26.4` | 3 passed on each; neither is a control |
| `SummarizationPromptCopyTests` | iPhone 17 or iPad Pro 11-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; its test must stay the pane's first action |
| `AnalyticsCompareFromTableTests` | iPhone 17 or iPad mini (A17 Pro), `OS=27.0` | 1 test, 1 passed on each; never skips; needs no index; an iPad under iOS 27.0 has run it clean since #1620 closed (2026-11-01) |
| `TabShellBannerClearanceTests` | iPhone 17 and iPad Pro 11-inch (M5) | 6 tests: 1 skipped on the iPhone, 0 on the iPad, which the suite turns to landscape |
| `SearchResultAddToCollectionTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 2 tests, 2 passed on each; never skips; only the iPad's wide sheet guards the picker row's tap |
| `SearchResultVoiceOverTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 4 tests; nothing skips under iOS 27 (three skip below it); listens through iOS 27's VoiceOver service, which returns 64 characters of speech and cannot make VoiceOver do an action; fails on the code before #1684, and its announcement test on the code before #1918; **under Xcode 27.2** VoiceOver stays on once a test has read its speech, and no call of the service turns it off (R5 measured four), so run each test alone, on a simulator shut down before it: 1 passed each; a run of the whole suite passes its first test and skips the other three, naming the cause; allow 600 s a test |
| `MeaningResultsSeamTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 3 tests, 3 passed on each; never skips; needs no search model (`FRUS_UI_TEST_SEED_MEANING` stands in for it); allow 600 s a test when the Mac is busy; on a simulator just booted, run one test first |
| `FilterVolumeListTests` (in `MeaningResultsSeamTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; the guard for Filters' volume list, which fails on the code before its fix on both |
| `FilterSheetDoneTests` (in `MeaningResultsSeamTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 3 tests, 3 passed on each; never skips; closing Filters by Done or a swipe runs the search again under the changed filter; fails on the code before #1918's IPS-1, at its first count after the sheet closes; allow 600 s a test |
| `FilterDateRangeHandOffTests` (in `MeaningResultsSeamTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 2 tests, 2 passed on each; never skips; the app runs in New York's zone (`TZ`) and the hand-off comes by the search seam's signal with two days (`FRUS_UI_TEST_SEARCH_ON_SIGNAL_DATES`); fails on the code before L57 at both tests (#2013); on the iPad run each test alone on a fresh boot (`backboardd` aborted in #1620's frames at a second launch on one boot); on the iPhone leave the app installed, since a fresh install's first launch opens the while-indexing guide over Search; allow 600 s a test |
| `SearchBulkActionsTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 5 tests, 5 passed on each; never skips; allow 600 s a test when the Mac is busy; on a simulator just booted, run one test first |
| `ResultSelectionBarFitTests` (in `SearchBulkActionsTests.swift`) | iPhone 17 and iPhone SE (3rd generation), `OS=27.0` | 6 tests, 6 passed on each; iPhone-only, self-skips at iPad width; fails when the tab shell's banner is not showing; on a simulator just booted, run one test first |
| `SearchWithinResultsTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 6 tests, 6 passed on each; never skips; needs no search model (`FRUS_UI_TEST_SEED_MEANING`); fails on the code before #1577 lane 4, and its Swap test on the code before lane 7; allow 600 s a test; on a simulator just booted, run one test first |
| `SearchLayerBaseRowFitTests` (in `SearchWithinResultsTests.swift`) | iPhone 17 and iPhone SE (3rd generation), `OS=27.0` | 5 tests, 5 passed on each; each size measures the row again with Swap on it (#1577 lane 7; AX3 and AX5 since #1721); iPhone-only, self-skips at iPad width; fails when the tab shell's banner is not showing; allow 600 s a test |
| `SaveSearchSheetTests` (in `SearchWithinResultsTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; fails on the code before the Save Search sheet's fix; its test must stay the launch's first Save this search; allow 600 s a test |
| `SearchWithinTheWholeMatchTests` (in `SearchWithinResultsTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; cuts the fixture at four rows (`FRUS_UI_TEST_SEARCH_CEILING`); fails on the code before #1577 lane 6; allow 600 s a test |
| `MeaningStripFitTests` (in `MeaningResultsSeamTests.swift`) | iPhone 17 and iPhone SE (3rd generation), `OS=27.0` | 6 tests, 6 passed on each; iPhone-only, self-skips at iPad width; needs no search model (`FRUS_UI_TEST_SEED_MEANING`); fails when the tab shell's banner is not showing; on the code before #1721 it fails at every accessibility size (no ⓘ), with the bars off the screen at AX3 and AX5 on the iPhone 17 and from AX1 on the SE |
| `VolumeAnnotationsSectionTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 2 tests, 2 passed on each; never skips; each test keeps a screenshot of the section; the Mac's half is walked in the check copy |
| `VolumeDownloadFailureTests` (in `VolumeAnnotationsSectionTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; downloads *Soviet Union* (`frus1961-63v05`), which must not be on the simulator, under the seam's `fail`; fails on the code before L20 at the failure's line (#1920); allow 600 s a test |
| `VolumeDownloadFailureAnnouncementTests` (in `VolumeAnnotationsSectionTests.swift`) | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; skips below iOS 27; listens through iOS 27's VoiceOver service, the download started by a Darwin signal; run it alone, on a simulator shut down before it, as `SearchResultVoiceOverTests`' cases; fails on the code before L20, which says nothing (#1920); allow 600 s a test |
| `AnnotationsAxisBrowseTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 5 tests: 1 skipped on the iPhone (the matrix), 0 on the iPad; Person Analytics' link is a sheet's on the iPhone and absent in the iPad's window; counts are the shipped file's; keeps screenshots of the axis, the matrix, a layer's page and its lists; run it with `VolumeAnnotationsSectionTests` |
| `IndexSeeLinkTests` | iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0` | 1 test, 1 passed on each; never skips; seeds `frus1932v04` as one document and a back-matter Index (`FRUS_UI_TEST_SEED_INDEX_VOLUME`), removed by any launch that does not ask for it; fails on the code before Lane 2 of the editors' annotations follow-ups, where a "Failed to Load" reader opens for a document named `in2`; allow 600 s a test |
| `WordCloudLensTests`, `NaturalLanguageReadinessWarmUpTests` (unit target) | iPad Pro 13-inch (M5), `OS=27.0` | a guard only on iOS 27.0; a control elsewhere |

Five rules hold for every UI run, and the runbook gives the measurement behind each:

- **Name the test type, not its file.** An `-only-testing` name that matches nothing runs zero tests
  and reports green, so read the test count back.
- **A device name does not name an OS.** This Mac has one of each device per installed runtime
  (iOS 26.3, 26.4, 26.5, 27.0): pin `OS=` or a UDID. A simulator also carries state between runs
  (the tab-sidebar representation, the scene's saved state), so when a failure follows one
  simulator, suspect that before the OS.
- **On iOS 27 pass `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 300`**, so a
  stall ends the run. A suite that measures a screen at rest sets `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`.
- **A suite that opens a presentation closes it in `tearDown`** with
  `UITestPresentation.dismissAnyPresentation(in:)`. Terminating the app is not enough: the next
  launch restores what the last one had open.
- **A test that opens on the onboarding wizard was handed another process.** A Live Activity
  dismissed while the app is not running makes the system open the app in the background, and a
  launch that arrives then gets that process, without the suite's arguments. A test's process starts
  none (`LiveActivityPolicy`); the tests of a build older than 2026-10-11 can leave one, and so can
  the app killed while it indexes, until the app is next launched, which ends it (#1642). Tapping
  Allow on the Lock Screen's Live Activities prompt opens the app in the background too.
  `TabBarNavigator` names it in the failure: run again.
