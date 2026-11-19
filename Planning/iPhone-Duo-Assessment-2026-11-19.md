# R6b — FRUS Explorer on the iPhone Duo simulator

*Written 2026-11-19 by R6b's session, for row R6b of the plan of record (`Plan-Of-Record-2026-11-15.md`, §1), from `v2` at `1f6b51c1` (R6's records, #1954), which is 1.0 (1823). The aim, from the owner's word of 2026-11-18: find what misbehaves on the Duo and mitigate it, not design for the inner screen.*

## In short

- **No crash, no loss of work and no store check was found.** Every task interrupted by a fold or an unfold came through with its state: a sheet stayed open, typed text stayed typed, the reader kept its place, Search kept its results, and Filters and Facets kept their unapplied changes.
- **F8 does not reach the Duo.** On an iPhone idiom the Research rail is always a sheet (`DocumentView.railIsSheet` is `isPhone || …`), so the inspector that F8 re-hosts as an iPad window narrows is never built. Two folds and two unfolds with the rail open did not crash.
- **One finding, D1:** the Duo is the one iPhone that supports multiple windows. So the analysis tools and the other surfaces the iPad opens in windows open as windows here too, and a window closed with **Done** comes back as a "view" at the app's next launch. It is not a crash, a loss of work or a store check. It is the owner's to place.

## The device and the library

- **The iPhone Duo simulator** `69E4A90C`, device type `iPhone-Duo`, on its own runtime, iOS 27.2 (24B91016s, `iOS-27-2-iPhone19-4`); Xcode 27.2 (27B52).
- **Postures**, from the simulator control's `posture`:
  - **closed** (0°): the outer screen, 466 × 678 pt;
  - **open** (180°): the inner screen, 951 × 669 pt;
  - **half open at 130°**: iOS lights the inner screen.
- **The app** declares no `UIRequiresFullScreen`, all four orientations and multiple scenes. iOS gave it each screen whole: no black bars on either.
- **The build** was a Debug build of `v2` at `1f6b51c1` for the Duo (174 s, under `Scripts/heavy.sh`).
- **The library** was S1's version-75 library: 553 volumes, from the iPad Pro 13-inch (M5) S1 simulator after R5's census, cloned into the Duo's container before the app's first launch, with the SwiftData store renamed to the Debug build's `FRUSExplorerDebug.store`. No re-index ran. The first run was checked first, on an empty install.
- **How the Duo was driven:**
  - the simulator control's taps and `set_posture`;
  - `simctl io … screenshot --display=1` (outer) and `--display=3` (inner) for each screen;
  - SpringBoard's log for scene events;
  - for the accessibility tree, a copy of T2's remote-control XCUITest (`~/Library/Caches/FRUS-Explorer/r6b/remote`, never committed).

## What was checked

Each check below was made on the outer screen, then through an unfold, and back through a fold. The strips show the three postures.

| Path | Posture changes, with the task in the middle | Result |
|---|---|---|
| **First run** (onboarding's dock) | On the outer screen, step 2 with *Subseries ▸ 1989-92* chosen: unfold, then fold | **Pass.** The dock, its step and its choice held through both ([strip](iPhone-Duo-Assessment-2026-11-19-onboarding.webp)) |
| **Search** with results | *Berlin wall*, 380 results: unfold, then fold | **Pass.** The results and the query held |
| **Search ▸ Filters** | A date limit staged, not applied: unfold, then fold | **Pass.** The sheet and its staged chip held ([strip](iPhone-Duo-Assessment-2026-11-19-search.webp)) |
| **Search ▸ Facets** | *Years: 2 included* staged, not applied: unfold, then fold | **Pass.** The sheet and the foot bar's count held |
| **The reader**, its place | The Long Telegram scrolled to items (d)–(g): unfold, then fold | **Pass.** Each screen opened on the same passage ([strip](iPhone-Duo-Assessment-2026-11-19-reader.webp)). The inner screen keeps the phone's measure (70ch), centred |
| **The reader's Research rail** | The rail's medium sheet open: unfold, then fold, twice | **Pass**, and no crash ([strip](iPhone-Duo-Assessment-2026-11-19-rail.webp)). F8 cannot arise here (above) |
| **A new note** (IPA-2) | A line typed on the outer screen: unfold, then fold; then *Discard Changes?* open: unfold, then fold | **Pass.** The words held; the question held as a popover on both screens ([strip](iPhone-Duo-Assessment-2026-11-19-note.webp)) |
| **A collection's editor** | Settings drill-in with a subtitle typed (the iPhone layout): unfold; the ⚙ settings sheet with a subtitle typed (the iPad layout, which the editor takes at regular width): fold; an entry's drill-in and its Configure sheet: each through a fold | **Pass.** Each field kept its text and focus as the editor swapped between its two layouts ([strip](iPhone-Duo-Assessment-2026-11-19-collection.webp)). The introduction's editor reports every keystroke to the model, so no fold can lose it |
| **Delete a collection** (*Delete "…"?*) | The confirmation open: unfold, then fold | **Pass.** It re-anchored to its row on each screen ([strip](iPhone-Duo-Assessment-2026-11-19-dialog.webp)). Dismissed; nothing was deleted |
| **Browse** root ▸ Subseries ▸ volume list | Unfold and fold mid-path | **Pass.** One pane on both screens (the two-pane gate needs the pad idiom); the breadcrumb is on screen |
| **Analytics** | Cross-Reference Analytics, and Semantic Analytics (Metal): each through an unfold and a fold | **Pass.** Both re-laid out; each name beside its bar; the map kept drawing ([strip](iPhone-Duo-Assessment-2026-11-19-analytics.webp)). Each opened as a window, which is D1 |
| **Settings ▸ Volumes & Storage, a queue** | 3 volumes, then the 13 of 1981–88, re-downloaded from GitHub | **Pass.** The queue ran and indexed (the 13 in about 30 s). The FRUS Research Guide it raises held its page through an unfold. The indexing banner was gone before a fold could be made under it |
| **The queue's Live Activity** (IPH-7) | Seen on the outer screen's Cover Sheet during the queue | **Pass.** One volume's progress (*Volume XXIV, North Africa — 463/463 docs*), with the system's *Allow Live Activities?*, left unanswered ([strip](iPhone-Duo-Assessment-2026-11-19-views.webp)) |
| **The tab shell and its banner** | The iCloud banner (always up on a simulator without an account) through every fold | **Pass.** On both screens iOS 27.2 draws the tabs as a vertical bar on the trailing edge, and the content and the banner keep clear of it. Lists end above the banner after each fold. Nothing occludes Browse's breadcrumb, which #238 guards against on an iPad |

**The idiom branches** (`userInterfaceIdiom`: 14 lines in 10 files, read and then seen). The Duo is the phone idiom in both postures, so each branch takes its iPhone side on the inner screen too:

- one pane in Browse (`BrowserView`) and Research (`ResearchView`);
- the rail and Facets as sheets (`DocumentView`, `SearchView`);
- the phone reading measure (`ReadingWidth`);
- no "Open Documents In" picker (`SettingsView`);
- the "Working on:" line kept and the breadcrumb drawn (`ProjectPickerMenu`, `BrowserView`, `CompilationView`);
- no tab-sidebar footer (`MainTabView`);
- the phone's splash metrics (`LaunchSplashView`).

None misbehaves. The inner screen reads as a wide iPhone, which the brief leaves out of scope ("where an iPad's layout already serves, the only question is whether the app takes it up without breaking"). The size-class branches that are not idiom-gated do switch on a fold: the collection editor's two layouts, the indexing banner's volume card and the analytics' compact layouts. Each was seen to switch cleanly.

**The skill's other APIs** (app-resizability). The app reads `UIScreen.main` nowhere; the frame-time probe's one `connectedScenes` read is the Debug build's. Its `safeAreaInsets` reads are SwiftUI `GeometryProxy` reads in the splash and onboarding, which the onboarding strip shows laying out on both screens. Whether a fold posts the app's lifecycle notifications was not instrumented: the app logs none of them, and neither queue was still running at a fold. None of these APIs showed a fault, so none was changed, as the plan's freeze asks.

## Findings

| Finding | Seen | What happens | Weight | Mitigation proposed |
|---|---|---|---|---|
| **D1** | Analytics, both postures | **On the Duo, every "open in a window where one is available" surface opens a separate window, and a window closed with Done comes back as a view at the next launch.** `@Environment(\.supportsMultipleWindows)` is true on the Duo in both postures, so the 25 gates that choose between a window and a sheet (10 files: `BrowserView`, `DocumentView`, `SearchView` and seven more) take the iPad's side, and the 23 `openAuxWindow` sites open scenes. On every other iPhone they are sheets: the code's comments say so ("iPhone (single window)", `ResearchRailView`), and R6's F9 reads the iPhone's PH18 through its sheet. What was seen: Cross-Reference Analytics and Semantic Analytics each opened as a full-screen window with **Done** (SpringBoard: a `SceneCreationRequest` for a new scene). Done brought the main window back (#1368's close works). In three of four closes SpringBoard received a *destroy scenes request*. Once (02:21:40) it did not, and the window stayed open behind the main window, so the next launch read **2 Views Open**. **In the other three the window's session survived too.** The app's `KnownSceneSessions` still listed both windows closed that way, and the next launch read **3 Views Open**: Cross-Reference Analytics and Semantic Analytics, each closed with Done, beside the main window ([strip](iPhone-Duo-Assessment-2026-11-19-views.webp)). The system's views switcher showed each with its content, and a swipe there removed it. | Not a crash, a loss of work or a store check | Either: (a) treat a phone-idiom device as single-window for these surfaces, so the Duo shows sheets as every other iPhone does; one helper beside `supportsMultipleWindows` read at the 25 gates. Or (b) keep the windows, and have `AuxWindowCloseAction` end its own scene session (`requestSceneSessionDestruction`) after it fronts the launcher, so a closed window does not return. (a) is the smaller change in behaviour. Whether (b)'s survival also happens on an iPad was not measured |

**Not findings, recorded for whoever drives the Duo next:**
- **XCUITest reaches only the outer screen.** On the inner screen its taps landed on nothing: a tap on the Browse tab left Search selected, by the tree. Folded, its taps worked. So a UI suite can run on the folded Duo, but it cannot fold it or drive the inner screen; only the simulator control can. The control's own taps reach both screens, but after a posture change its first taps sometimes failed with *could not finish sending input* until it was attached again.
- **Half open from closed froze the simulator's frame.** Going from closed to 130° left a blurred, frozen frame for every app (the system's Settings too), until the hinge moved again; open to 130° was fine. That is the simulator, not the app.
- **Screens by `simctl`:** display 1 is the outer screen and display 3 the inner; display 1 can come back landscape.

## Not checked

- **A fold while a queue downloads or indexes**, and with it the indexing banner changing height under a fold (F1's ground, R6a's): both queues indexed too fast to fold during one. R6a's own reproduction uses a full re-index, which would give the time.
- **The inner screen in landscape, and rotation:** not asked of this row.
- **A physical Duo:** none at hand.
- **Whether a plain iPhone 17 under iOS 27.2 is single-window:** not measured here; R6's device pass on an iPhone 17 Pro under 27.2 reported no windows.

## Placed

- **D1: the first update after 1.0**, on the owner's word of 2026-11-19 ("First update"). It is among the plan's §3 candidates, with both proposed fixes.
- **No finding goes before R7,** so R6b lands no mitigation. No UI suite runs on the Duo, so `CLAUDE.md`'s UI table and the runbook are unchanged.
- **The records** were opened as #1955 on the owner's word ("Open the PR").

## The Duo afterwards

The hinge was put back where it was found: closed, at 0°. Of the 19 volumes moved out of the container to make the two queues, 16 were downloaded again from GitHub, each byte for byte the file it replaced, and 3 were copied back. So the library again holds 552 of 553 volumes, as S1's did. The app is left with S1's library and one main window. S1's own simulator was only read from.
