# UI and UX adversarial review, for the submission of 1.0 (1861) — 2026-11-15

**Status: LIVE — the review the plan of record's decision 126 asks for** (`Completed/Plan-Of-Record-2026-11-15.md`, whose rows L17 to L21 took its 1.0 findings; `Plan-Of-Record-2026-11-25.md` §5 carries the rest). The rows are filed as #1917 to #1921 on the owner's word of 2026-11-15 (the plan's decision 127): L17 #1917, L18 #1918, L19 #1919, L20 #1920, L21 #1921. The owner took its 2 S1s and 23 S2s for 1.0 the same evening (the plan's decision 133), and settled §7's naming question (decision 135). Read against `v2` at `4a269a35`. Nothing in the app, its tests or its manuals was changed by it. It stays at the Planning root until its 1.0 rows have merged and its backlog has been filed as issues or declined, on the owner's word.

---

## 0. What it found

Seven reviewers returned **68 findings**. Two skeptics then re-read every one against the code, and **none was refuted outright**. After four groups of duplicates were merged and six findings were re-rated down, the count stands at:

| | Findings | Of them, needing a run to settle |
|---|---|---|
| **S1**: blocks submission | **2** | 1 (ASR-1: the fix is safe without the check) |
| **S2**: fix before 1.0 if cheap | **23** | 3 (ASR-4, IPA-6, A11Y-5) |
| **S3**: after 1.0 | **37** | 7 |

The other six of the 68 are whole duplicates, each folded into the finding it repeats (§5); 2 + 23 + 37 + 6 = 68. Every S1 and S2 fix is app code: none changes `FRUSCoreKit/`, what indexing stores, or a `@Model`'s stored properties.

**The two S1s are both things App Review checks.**
- **No privacy policy link inside the app (ASR-2).** Guideline 5.1.1(i): "All apps must include a link to their privacy policy in the App Store Connect metadata field **and within the app** in an easily accessible manner."
- **No Photos usage string (ASR-1).** The app declares no usage-description key of any kind. Yet three paths on iPhone and iPad let a person save an image to Photos: an exported chart's Save Image, a reader figure's long press, and an image in the in-app browser. Apple's PhotoKit documentation: "Attempting to access the Photos library without a valid usage description causes your app to crash."

**The S2s fall into five groups**, which become the plan's rows:
1. **What App Review checks** (L17):
   - an in-app browser that can go anywhere, while the drafted age rating says it cannot;
   - a Mac App Store build that cannot print to a printer.
2. **A screen that says something happened when it did not** (L18):
   - Search's Filters sheet shows the narrowing at once, while the list on screen is still unfiltered;
   - Facets' Years and Volumes stage a choice that nothing applies;
   - a search's result is never spoken to VoiceOver.

   Added to L18 because it shares the surface:
   - Search's main touch targets are below Apple's minimum;
   - the Mac draws the words a document matched in yellow text at 1.5:1;
   - an empty library's search blames the search term.
3. **Work a researcher can lose without being asked** (L19):
   - a note being written is lost to a swipe;
   - a collection row that holds the researcher's own prose is deleted by one swipe or one click, with no undo;
   - Add to Collection confirms with a check that closes itself in 0.6 s.
4. **A wait or a failure that names the wrong cause, or none** (L20):
   - the first download's caption gives a quarter of its size on the device;
   - a Mac cannot stop a download, and Erase Everything leaves the queue running;
   - a failed download vanishes;
   - a device whose Apple Intelligence is merely switched off is told it cannot summarize.
5. **The Mac's window conventions** (L21):
   - the main window is titled with the app's name and shows a raw id;
   - two windows open narrower than their own toolbars;
   - the Research window's rows for same-headed telegrams are identical;
   - the empty first window's only instruction is in the grey reserved for unavailable things.

   In the same row:
   - a chart's comparison lines told apart by colour alone;
   - Browse's tiles, whose spoken names Voice Control cannot match.

**Found sound** (§8): the reader's page, whose contrast, underlines and target sizes are gated by tests; the per-window state and window restoration on iPad and Mac; the confirmations for deleting a highlight, a collection, a section and everything; Reduce Motion and Reduce Transparency; and the privacy manifest, the "Data Not Collected" claim, export compliance, background modes and the Mac sandbox.

---

## 1. Method

**Seven reviewers**, each with one scope and the same brief:
- the iPhone (IPH);
- the iPad's reading and organising half (IPA);
- the iPad's search and analysis half (IPS);
- the Mac (MAC);
- cross-platform flows and words (HCD);
- accessibility (A11Y);
- App Review readiness (ASR).

The brief set:
- the evidence standard: a `file:line` re-read in the current tree, or a capture named with its ledger date;
- the severity scale, below;
- what the owner had already declined (decision 93's list), which the reviewers were not to re-raise without new evidence;
- what the plan already carried (its §5), and the open issues.

Each finding had to name what would refute it and whether that was checked.

**The severity scale.**
- **S1:** a likely rejection under a named guideline, a crash or hang on a reachable path, data loss, or a common task a first-time user cannot complete.
- **S2:** a first-time user misled, stuck or led into an error on a common task, or a clear HIG instruction broken on a primary surface.
- **S3:** real but secondary.

**Two skeptics**, given the findings and not the reviewers' reasoning, tried to refute each one against the code, tests, manuals and plan decisions. They then gave each a verdict:
- CONFIRMED;
- PLAUSIBLE, where the effect depends on a run they could not make, with the check that would settle it;
- REFUTED;
- DUPLICATE.

Skeptic A took ASR, MAC and A11Y (28 findings). Skeptic B took IPH, IPS, IPA and HCD (40).

**The sources.**
- The current code under `FRUSExplorer/` and `FRUSCoreKit/`.
- The 89 committed captures (`Docs/screenshots/`). Each is evidence about the build its ledger entry names, the newest being sitting T1's, of 1.0 (1812).
- Both manuals and both quick starts.
- The Human Interface Guidelines and the App Review Guidelines as Apple published them on 2026-11-15, fetched that day: 57 HIG pages, several marked "Updated guidance for Liquid Glass", and the App Review Guidelines "Last Updated: October 16, 2026". The text is not committed; each quotation below names its page.
- For ASR-1 and ASR-4, Apple's documentation pages and WebKit's source, which Skeptic A read and cites.

**What no one could do.** The session's container has no Xcode and no simulator, so no app was run. Each finding that depends on runtime behaviour is marked PLAUSIBLE, with its check in §6. The plan puts every such check inside the row that would fix it, or in R6's device pass.

---

## 2. The two S1s (row L17)

### ASR-1 — Saving an image to Photos can terminate the app (iPhone, iPad)

*S1; PLAUSIBLE, strongly; XS.*

**What a person meets.** On iPhone or iPad, a person keeps a chart the obvious way: Export ▸ **Figure (PNG)…** ▸ Share ▸ **Save Image**. Or they long-press a figure in a document, or an image in the in-app browser, and choose **Save to Photos**. The app has no Photos usage string, and iOS terminates an app that writes to the photo library without one.

**Evidence.**
- `project.yml`'s iOS `info.properties` (lines 117–238) and `FRUSExplorer/Info.plist` hold no `*UsageDescription` key.
- The figure goes to `ShareLink` as a `.png` file URL (`FRUSExplorer/Analytics/Export/AnalyticsExportDelivery.swift:104-113`, `:234`). That sheet serves every analytics view, the Word Cloud, the semantic map and About the Series, which works before any download.
- The reader draws figures as plain `<img>` tags (`FRUSCoreKit/TEI/FRUSRenderNodeHTMLSerializer.swift:1250`), and nothing suppresses the long-press menu.
- The in-app browser is a plain `WKWebView` (`InAppBrowserView.swift:171-175`).
- WebKit offers **Save to Photos** unless the privacy check answers *denied*, and never reads the host's Info.plist (`WKActionSheetAssistant.mm`). It then writes with `UIImageDataWriteToSavedPhotosAlbum` in the app's own process (`PageClientImplIOS.mm:496-507`).
- Apple's developer forum thread 772243 (January 2025) reports this crash, fixed by adding the key.

**Apple.** `NSPhotoLibraryAddUsageDescription`: "This key is required if your app uses APIs that have write access to the user's photo library." App Review Guideline 2.1: "We will reject incomplete app bundles and binaries that crash or exhibit obvious technical problems."

**Fix (XS).**
- Add `NSPhotoLibraryAddUsageDescription`, with a purpose string that says what is saved, to `project.yml`'s iOS `info.properties` and to `FRUSExplorer/Info.plist`, by hand. Do not run `xcodegen generate`, whose scheme damage `CLAUDE.md` describes.
- Do not exclude the activity instead: it would leave the two web-view paths open.
- The key is safe to add whatever the check finds.

**Check.** On an iPhone 17 simulator under iOS 27.0 and 26.5, before and after the key, each of the three paths. Expect a termination naming the key before, and the system's prompt after. The Mac's image menu is unchecked.

### ASR-2 — The app never links to its privacy policy, or to a way to reach its developer (every platform)

*S1; CONFIRMED; S.*

**What a person meets.** A reviewer looking for the privacy policy inside the app finds none:
- About has Resources, Attribution and Legal sections;
- the Mac's Help menu holds the Quick Start and the Research Guide;
- no user-facing string says "privacy";
- the only contact is `feedback@frusexplorer.app`, inside the Semantic Match Feedback footer.

**Evidence.**
- `AboutLinks` (`FRUSExplorer/Settings/AboutView.swift:19-56`) holds twelve URLs, none of them the policy or the support page.
- The Mac's Help menu is `FRUSExplorerApp.swift:2289-2295`.
- Onboarding, the Research Guide, Settings and Full Notices hold neither. Read in this session as well: none of About's twelve links is either page.

**Apple.**
- 5.1.1(i), quoted in §0.
- 1.5: "Make sure your app and its Support URL include an easy way to contact you".

The rule has no exception for an app that collects nothing.

**Fix (S).**
- Two rows in About ▸ Legal, a view both platforms share: **Privacy Policy** (`https://frusexplorer.app/privacy`) and **Support** (`https://frusexplorer.app/support`), the addresses the App Store Connect entry sheet gives.
- Two Help-menu items on the Mac.
- `AboutLinks.allURLStrings` is tested.
- Inserting rows moves the ranged `Docs/EditableContent` blocks that cite `AboutView.swift`, and any below the Help menu in `FRUSExplorerApp.swift`. Each is re-pointed, with an Amendment-Log bullet.
- The pages must be public before submission. They answered 401 on 2026-11-10, and making them public is the owner's step on submission day (plan §2).

---

## 3. The S2s, by the row that takes them

Each entry gives the skeptic's verdict, the evidence that verdict rests on, and the fix. Line numbers are at `4a269a35`.

### Row L17, what App Review checks (with the two S1s)

- **ASR-3, the in-app browser and the age rating** (every platform; CONFIRMED; S).
  - **The browser:**
    - `InAppBrowserView.swift` is a plain `WKWebView()`, with a navigation delegate of five progress callbacks, no `decidePolicyFor`, no UI delegate and no address field.
    - It opens from About (`:190`, `:524`), the Research tab's Quick Start (`ResearchView.swift:400-403`) and the Research Guide (`IndexingEducationView.swift:216`).
    - Its start pages (github.com, huggingface.co, claude.ai) link onward anywhere.
  - **The rating:** the entry sheet answers *Unrestricted Web Access: no* (`Planning/app-store-connect/App-Store-Connect-Entry.md:148`), while admitting that a page's links lead on. Apple's definition: "Users can navigate to any webpage within the app or freely browse the web. May include: embedded browser functionality or browser app."
  - **Fix:** allow navigation only on the opening page's host and its subresources, and send any other link to the system browser, which makes *no* true. Or answer *yes*, and take 16+. The choice is the owner's (plan §4); the code fix is recommended.
  - **Why S2, not S1:** a rejection under 2.3.6 is fixed in the metadata without a new build.
- **ASR-4, Mac printing** (Mac; PLAUSIBLE; XS).
  - `File ▸ Print` (⌘P) runs `webView.printOperation(with:)` (`MacDocumentView.swift:790-799`), and the manual documents it (`macOS-User-Manual.md:142`).
  - Neither `FRUSExplorer-AppStore.entitlements` nor `-DirectDistribution.entitlements` declares `com.apple.security.print`.
  - Apple's App Sandbox guide: "Printing access is required if you want to provide a target with the ability to print."
  - The only measurement of the path printed to a PDF (the session log, 2026-10-08), never to a printer.
  - **Fix:** the key in both files. Neither entitlements test pins an allowlist.
  - **Check:** the owner prints to a real printer from an AppStore-configuration build, with Console open for a sandbox deny.
- **ASR-6, the App Review notes** (iPhone, iPad; S3, kept with L17 since it is free).
  - The notes say *A Single Volume*, but iOS's segment reads **Volume** (`OnboardingView.swift:658`); the Mac's matches (`:652`).
  - The screen opens on **Corpus**, and the notes say about 3.3 GB where the app says 3.5. The manifest sums to 3,339,186,418 bytes.
  - **Fix:** in `Store-Listing-Draft.md` §7, then `build_paste.py`.

### Row L18, Search says what it did (iPhone, iPad, Mac)

- **IPS-1 (with IPH-2), Filters' Done** (iPhone, iPad; CONFIRMED; S).
  - **What a person meets.** A date range or a volume is set and **Done** tapped. The list still reads "900 results". Yet four things now say the narrowing happened:
    - the *Narrowed by* chips (`SearchViewModel.swift:2549-2557`, built from the sheet's live fields);
    - the *Scoped to …* banner (`SearchView.swift:1748-1749`);
    - an *Inside "corpus"* banner (`:1709`);
    - the filled filter glyph (`:1184`).

    The Query Inspector refreshes to the new filters (`:694`), so its counts and the list describe different scopes.
  - **Why it happens.**
    - The sheet has no `onDismiss`, and its one `onChange` acts on opening (`:703-720`, read again in this session).
    - Done is a bare `dismiss()` (`SearchFilterView.swift:247-252`).
    - Only the Mac watches `advancedFilterSignature` (`SearchSheet.swift:1651`).
    - The manual gives the workaround: "tap **Done** and submit the search again" (`iOS-User-Manual.md:587`).
  - **Apple.** `sheets.md`: "The Done button dismisses a sheet after completing a task or explicitly saving changes."
  - **Fix.**
    - `onDismiss` reruns the search when the signature captured at opening has changed and results are on screen, the Mac's rule and `removeNarrowing`'s condition (`:955-962`).
    - §7.4 rewritten.
    - A UI test.
- **IPH-3, Facets' Years and Volumes** (iPhone, iPad; CONFIRMED, corrected; S).
  - **What a person meets.** A year row ticks and nothing narrows.
    - Years and Volumes only stage (`FRUSCoreKit/Search/FacetSelection.swift:177`).
    - **Apply** is drawn after every row and the page footer, at `.mini` caption2 (`FacetPanelView.swift:828-836`, `:1060-1073`). Years opens listing every year.
    - **Done** leaves the choice staged and unapplied until the next search clears it (`SearchView.swift:640-645`, `:161-166`, `:228-231`).
    - The tip promises the opposite: "Select any year, volume or person to narrow your search to it" (`DiscoveryTips.swift:172-173`).
    - VoiceOver's hint already says "Choose rows, then Apply" (`:1011`).
  - **Fix.**
    - Pin Apply and Clear to the sheet's foot (`safeAreaInset`) while a selection is staged.
    - Let Done apply it.
    - Correct the tip and its block (`Docs/EditableContent/09-Settings-and-App.md:837`).

    The kit's applier is unchanged.
- **IPH-5, Search's touch targets** (iPhone; CONFIRMED; S).
  - **The controls.**
    - The actions bar's five tools are default buttons in an `HStack(spacing: 20)`, with no frame or content shape (`SearchView.swift:1629-1653`). `controlHelp` adds a label, a hint and the Large Content Viewer, not a hit area (`ControlHelp.swift:84-90`).
    - The pager's two `.footnote` chevrons are the only way to page (`:2131`, `:2175-2205`), about 6×10 pt.
    - So are the queue banner's chevron (`IndexingQueueBannerView.swift:159-171`) and Facets' Apply and Clear.
  - **Measured** on `ios/search-results.png` (Q1): Filter about 19×19 pt.
  - **Apple.** `accessibility.md`: "44x44 pt" default and "28x28 pt" minimum on iOS. `buttons.md`: "a button needs a hit region of at least 44x44 pt."
  - **Fix.** An outset content shape to 44 pt, which leaves the layout and the captures unchanged. A 44-pt frame would instead empty `SearchTipsSheetTests`' accessibility-size check of its meaning. `SearchActionsBarFitTests` is run again on the iPhone 17 and the SE.
- **HCD-4, searching an empty library** (every platform; CONFIRMED; XS–S).
  - After Skip, *Berlin* returns "…matches no document in your current scope. The rest of your query is not the problem." (`QueryInspectorView.swift:398-418`, which the Mac shares at `SearchSheet.swift:445`).
  - The real cause is the last line, in tertiary grey: "0 volumes on this device".
  - The fallback underneath offers only the 310 MB search-model download (`SemanticSearchFallbackView.swift:70-73`).
  - **Fix.**
    - With no volume indexed, show "No volumes on this device yet" with **Download Volumes…**, and drop the per-term diagnosis.
    - Count with `CountCopy` ("1 volumes" today).
    - The downloaded-only filter's blank Subseries list (IPA-1, S3) takes the same empty state, at no extra cost.
- **A11Y-2, a search's result spoken** (every platform; CONFIRMED; XS).
  - A finished search is announced only inside a held list: `SearchView.swift:728-733` (`if vm.executedRoute.isLayer`), and `SearchSheet.swift:2122-2125` (`guard … isLayer`).
  - **Apple.** `voiceover.md`: "Inform VoiceOver when visible content or layout changes occur."
  - **Fix.** Drop both guards, and add a case to `SearchResultVoiceOverTests`. Searches run on submit, so it adds no noise.
- **A11Y-1, the Mac's matched words in yellow** (Mac; CONFIRMED; XS).
  - `SearchSheet.swift:3038-3039` colours each match `Color.yellow`.
  - The HIG's light Yellow (255, 204, 0) gives 1.51:1 on white, and the capture samples 1.53:1.
  - Increase Contrast's yellow passes (4.59:1); the default does not.
  - **Apple.** `accessibility.md`: "Up to 17 pts | All | 4.5:1."
  - **Fix.** The snippet's own text colour, bold, on a pale yellow background, as the reader draws a highlight. The accent's light blue is about 3.5:1, so not that.
  - **The cost** is the capture: `macos/search.png` is the README's hero image and the Mac's store frame 01 (plan R5, sitting T2).

### Row L19, nothing the researcher wrote is lost without asking (iPhone, iPad, Mac)

- **IPA-2 (with IPH-4), the note editor** (iPhone, iPad; CONFIRMED; S).
  - **What can be lost.**
    - The editor is an ordinary sheet over the passage (`DocumentView.swift:879-901`, `AllNotesScreen.swift:138-145`).
    - Nothing is saved before Save (`ResearchNoteEditorView.swift:366-382`), and no draft is kept.
    - The app's one `interactiveDismissDisabled` is elsewhere (`VolumesStorageHubView.swift:1733`).

    So a swipe, a tap beside the sheet, or **Discard** loses the typed note without a word.
  - **Delete** erases a saved note on every device in one tap (`:386-397`), where All Notes asks first (`AllNotesScreen.swift:148-165`).
  - **Apple.** `sheets.md`: "If people have unsaved changes in the sheet when they begin swiping to dismiss it, use an action sheet to let them confirm their action."
  - **Fix.**
    - Snapshot the text and tags on load (the view model holds only `bodyText`).
    - `.interactiveDismissDisabled(hasChanges)`, with a "Discard Changes?" dialog on swipe and on Discard.
    - All Notes' dialog on Delete.
- **MAC-2 (with IPA-3 and HCD-8), deleting the researcher's own writing in a collection** (every platform; CONFIRMED; S).
  - **How it happens.**
    - On the Mac, a row's red trash calls `deleteEntry` (`MacCollectionManagerView.swift:1537-1546`; `CollectionEntryRows.swift:271-284`), which deletes the entry and its headnote draft, "the reader's own text" (`GeneratedSummary.swift:257-258`), with no dialog.
    - On iPhone and iPad a full swipe does the same to any row (`CollectionEditorView.swift:1164-1166`, `:1667-1677`): a prose block, a heading with its defaults, or a document with its headnote.
  - **Why it cannot be recovered.** Nothing registers undo for model data: the scenes use `.modelContainer(_:)` (`FRUSExplorerApp.swift:962`), and `undoManager` appears only in the rich-text editor. The deletion syncs.
  - **The inconsistency.** Deleting a collection, or a section, asks first (`MacCollectionManagerView.swift:389-394`; `CollectionEntryRows.swift:196-210`).
  - **Apple.** `alerts.md`: "when people take an uncommon destructive action that they can't undo, it's important to display an alert."
  - **Fix.**
    - Reuse the Delete Section dialog for a row that holds text: a prose block, a heading with defaults, or a document row with a headnote draft or overrides.
    - Word the tooltip for each kind of row; it says "Remove this document…" on prose.
  - **Left to S3:** the whole-collection Sort (IPA-3's other half), whose warning text (`CollectionEntryData.swift:41-51`) is shown nowhere.
- **A11Y-3, Add to Collection's confirmation** (every platform; CONFIRMED; XS).
  - The picker draws a check and closes itself after 0.6 s, or 0.8 s when the document is already there (`CollectionPickerSheet.swift:201-206`, `:424-425`, `:437-439`, `:456-457`).
  - It announces nothing, and the reader passes no `onAdded`, so the toast and Undo that Search's results get never come (`ResearchRailView.swift:230-232`, `DocumentView.swift:956-959`).
  - "Already there" draws the same check as an add.
  - **Apple.** `accessibility.md`: "Minimize use of time-boxed interface elements… Prefer dismissing views with an explicit action."
  - **Fix.** Announce "Added to “X”" or "Already in “X”", with a different mark for the second.
- **IPA-4, reading a document from one's own collection** (iPad, iPhone; CONFIRMED; XS–S).
  - A row's tap, and its Configure pill, both open the inspector (`CollectionEntryRows.swift:785`, `:797-798`).
  - **Open Document** is only in the context menu (`:799-815`), and the inspector cannot open the reader. This is #755's deliberate choice, documented (`iOS-User-Manual.md:1048`).
  - **Apple.** `context-menus.md`: "Always make context menu items available in the main interface, too."
  - **Fix.** An **Open Document** button in the inspector, on the iPad pane and the iPhone drill-in. A row's tap stays as it is.
- **IPA-6, the rail at compact width on an iPad** (iPad; PLAUSIBLE; S if confirmed).
  - **What the code shows.**
    - The rail's `.inspector` is gated on `!isPhone && panelVisible` (`DocumentView.swift:1022-1032`). The code's own comment says that at compact width SwiftUI "would otherwise auto-present the inspector AS a sheet".
    - On an iPad the rail is open by default (`:368`, `:519-526`).
  - **Where an iPad user meets compact width:**
    - Split View, Slide Over or a narrow Stage Manager window;
    - on a full-screen iPad, a document opened from Project Home, which reads inside a form sheet (`ProjectPickerMenu.swift:412-428`). "An iPadOS form sheet reports a compact size class" (`CollectionEditorView.swift:1122-1123`).
  - **Check** on an iPad Pro 13-inch (M5) under iOS 27.0, rail on:
    1. Research ▸ Project Home ▸ open a document: does the rail arrive as a sheet?
    2. Does Cite open from it?
    3. After closing that sheet, is a document opened from Browse rail-closed?
    4. The same in the narrowest Windowed Apps window.
  - **Fix if confirmed:** require `horizontalSizeClass == .regular` too, and give a compact iPad the iPhone's tap-to-open rail sheet.

### Row L20, downloads, the first run and Apple Intelligence say what is happening (every platform)

- **HCD-1 (with IPH-1), the first download's size on the device** (CONFIRMED; XS copy).
  - **Today.**
    - Onboarding preselects **Corpus**, captioned "553+ volumes · ≈ 3.5 GB — the entire series, fully offline. Recommended for full functionality." (`OnboardingView.swift:103`, `:613-617`).
    - Continue queues the downloads before the Ready step (`:583-586`, `:745-757`), with cellular allowed by default (`DownloadManager.swift:754`).
    - Free space is checked only by the compaction rows.
    - The app's own storage hub puts the index at about 9 to 10 GB for 3.4 GB of XML (`VolumesStorageHubView.swift:1678`), and the Quick Start says "roughly 13 GB on the device" (`iOS-Quick-Start.md:31`).
  - **The owner's wording.** The default and its *Recommended* are the owner's, set in the close-out pass of 2026-09-30 (`Docs/EditableContent/Amendment-Log.md:136`, item C1), so only the missing size is a defect.
  - **Not a 4.2.3(ii) risk:** the app works after Skip, and the download's size is stated.
  - **Fix.**
    - Add "about 13 GB once indexed" under the same key (`onboarding.scope.caption.corpus.v2 %lld`, which `CorpusScaleLiteralsTests` reads by key).
    - Its block (`01-About-and-Onboarding.md:180`), and manual §2.3.
    - Retake `ipad/onboarding-volumes`.
- **HCD-2, a download that cannot be stopped** (CONFIRMED; XS–S).
  - **No way to stop it.**
    - The only call to `cancelDownload` from the UI is one Cancel per row in iOS's Active Downloads (`VolumesStorageHubView.swift:303`, in an `#if os(iOS)` file): about 553 taps for the default first run.
    - The Mac has none, and its status bar's "N downloads queued" does nothing when clicked (`SupportingViews.swift:569-575`).
  - **Nothing clears the queue.**
    - `ResetService.resetLocalData` (`:145-200`) leaves the saved queue, which resumes at every online launch (`FRUSExplorerApp.swift:3236-3237`). So Erase Everything's "as if newly installed" (`SettingsView.swift:1404`) is not kept.
    - Back on onboarding's Ready step only changes the step (`OnboardingView.swift:519`), so Skip after it still reads "Your volumes will download…".
  - **Apple.** `progress-indicators.md`: "If people can interrupt a process without causing negative side effects, include a Cancel button."
  - **Fix.**
    - `DownloadManager.cancelAll()`, called by Reset This Device, Erase Everything and Back on Ready (XS).
    - A **Cancel All** in iOS's Active Downloads and on the Mac storage hub's status line (S).
    - The Mac's full Active Downloads list waits for after 1.0 (M).
- **HCD-3 (with A11Y-4's download half), a failed download that vanishes** (CONFIRMED; S).
  - After two retries (`DownloadManager.swift:141`, `:1115-1151`), one `.failed` report goes to two places, and neither shows it:
    - Keeping Current drops it unless the volume is an update row (`KeepingCurrentModel.swift:290-291`);
    - the queue's count stops counting it (`AppState.swift:2280-2292`).
  - `VolumeView.swift:162-171` says so: "the Download button is re-offered".
  - A full disk is the likely cause, and nothing checks free space.
  - **Apple.** `feedback.md`: people "only need to know when it doesn't [succeed]".
  - **Fix.**
    - Remember each volume's last `DownloadFailure`, in memory or `UserDefaults`, never on a `@Model`.
    - Show "Download failed: <reason>" with **Retry** under Download Volume, in Keeping Current's existing words (`KeepingCurrentModel.swift:388-397`), and announce it.
    - The queue-wide wording can follow 1.0.
- **HCD-5, the reason Apple Intelligence is unavailable** (CONFIRMED; S).
  - `AppleIntelligenceProvider.swift:144-145` reads only `isAvailable`. So an eligible device with Apple Intelligence switched off, or its model still downloading, is told "Apple Intelligence is not available on this device".
  - The wording appears at seven sites: `ResearchRailView.swift:560`, `SupportingViews.swift:284`, `SettingsView.swift:1157`, `FRUSSettingsView.swift:779`, `BatchRunReadiness.swift:77`, `SummarizationModels.swift:131` and `CollectionEntryInspector.swift:1163`.
  - The Quick Start already names the condition: "Apple Intelligence turned on".
  - **Fix.** One helper over `SystemLanguageModel.default.availability`, used at all seven sites:
    - not enabled → turn it on in Settings ▸ Apple Intelligence & Siri;
    - model not ready → try again later;
    - not eligible → today's sentence.

### Row L21, the Mac's windows, a chart's lines and Browse's tiles

- **MAC-1, the main window's title** (Mac; CONFIRMED; XS title, S centre label).
  - The main window sets no title, so it reads "FRUS Explorer" whatever is open. Its centre shows the raw id, `frus1946v06/d475` (`MainWindowView.swift:251-261`).
  - Only the standalone document window titles itself (`MacDocumentView.swift:1428`, `:1439-1451`): the earlier fix (#903) reached that window alone.
  - **Apple.** `toolbars.md`: "Don't title windows with your app name."
  - **Fix.**
    - `.navigationTitle` from the document's head.
    - The standalone window's `MacDocumentTitle.principalLabel` in the centre.
    - The quick start's line that decodes the id (`macOS-Quick-Start.md:56`).
    - Retakes of `macos/toolbar` and `macos/research-strip`.
- **MAC-3, toolbars wider than their windows** (Mac; CONFIRMED; S).
  - Search opens at 820 pt (`FRUSExplorerApp.swift:1215`), and its toolbar needs about 1,250. Corpus Analytics opens at 760 (`:1436`), and its toolbar needs about 1,060.
  - So Facets and Export start behind ». The Quick Start says Facets is "in the title bar" (`macOS-Quick-Start.md:148`).
  - Both capture sittings widened these windows to 1,440 pt, which is why no frame shows it.
  - **Apple.** `toolbars.md`: "avoid layouts that cause toolbar items to overflow by default."
  - **Fix.** Measure each toolbar on a Mac, set the default size to fit, and pin it with a test, as #1378 pinned the Archives Visits window.
- **MAC-5, identical rows in the Research window** (Mac, and the shared view; CONFIRMED; XS).
  - Rows show the printed head and the volume (`ResearchView.swift:952-967`), so Documents 474, 475 and 476 all read "The Chargé in the Soviet Union (Kennan) to the Secretary of State". The number is loaded and never drawn.
  - **Fix.** Prefix `CitableDocumentNumber.rowLabel`, as Collections and Search do. Retake `macos/research`.
- **MAC-6, the empty first window** (Mac; CONFIRMED; XS).
  - The window says "Select a document to begin", with nothing to select.
  - Its one instruction, "Use Search (⌥⌘F) or open the Corpus Browser (⇧⌘B)", is `.tertiary` (`MainWindowView.swift:474-507`, `:494-497`): 1.88:1, sampled on `research.png`.
  - **Apple.** `labels.md` reserves tertiary for "an unavailable item or behavior".
  - **Fix.** Make the hint `.secondary`, and add **Search** and **Browse the Corpus** buttons.
- **IPS-3, comparison lines told apart by colour alone** (every platform; CONFIRMED; XS).
  - Corpus Analytics' comparison `LineMark`s take `.foregroundStyle(by:)` and nothing else (`AnalyticsView.swift:2097-2148`), for up to five terms (`:514`): blue, orange, green, purple, pink (`FRUSTheme.swift:62-65`).
  - The table is off while comparing (`:2954`).
  - Person Analytics already adds `.symbol(by:)` (`PersonAnalyticsView.swift:1262-1265`).
  - **Apple.** `charts.md`: "Avoid relying solely on color to differentiate between different pieces of data." WCAG 1.4.1, Level A.
  - **Fix.** `.lineStyle(by:)` or `.symbol(by:)`. Retake `ipad/analytics`, whose frame compares four terms.
- **A11Y-5, Browse's tile names under Voice Control** (iPhone, iPad; PLAUSIBLE; XS).
  - Four of the seven tiles' accessibility labels do not contain their visible word: Administrations, Editors, Archives and Clusters (`CorpusView.swift:427-512`).
  - Neither tile view sets input labels, and the app's own comment states the rule (`ArchivesArrangementControls.swift:194-198`).
  - **WCAG 2.5.3** (Label in Name, Level A).
  - **Fix.** `.accessibilityInputLabels([title, label])` in `BrowseAxisTile` and `BrowseAxisGridTile`.
  - **Check.** Voice Control on: "Tap Archives".

---

## 4. The S3s, after 1.0

Each is the plan's §5 backlog, to be filed on the owner's word. Each line gives the fix's size.

**iPhone (IPH)**
- **IPH-6:** at accessibility sizes on a small iPhone with no iCloud, the undismissable sync banner, with Search's fixed rows, leaves 10–22 pt for results in Search's heavy modes (the runbook's own measurements). Draw the banner on one line at accessibility sizes (S).
- **IPH-7:** the Lock Screen Live Activity shows one volume's progress, never "N of M" (S, widget).
- **IPH-8:** the end-of-queue card was never seen on iPhone. When it shows, **Search →** searches one volume and the card is gone in 6 s (S–M).
- **IPH-9:** onboarding's dock has no scroll view at accessibility sizes (S).
- **IPH-10:** the queue banner's word cloud stays under Increase Contrast and Reduce Transparency (XS).

**iPad, search and analysis (IPS)**
- **IPS-2 (with IPA-8):** caveats and partial-coverage lines in tertiary grey (1.72–1.84:1) and orange (2.17–2.31:1). They are captions, and the system colours darken under Increase Contrast. A warning-text token, and orange as an icon beside neutral text (S for the named sites, M tree-wide).
- **IPS-4:** the Meaning rows' "66%" and Related's bare percentages are explained only in the manuals (XS).
- **IPS-5:** Clusters and the map's Region name one group three ways (XS). Its topics half is HCD-6.
- **IPS-6:** Corpus Analytics' two counts, and its dimmed controls while comparing, are explained only in `.help` (XS).
- **IPS-7:** Archival Analytics' "or use the list below" names a list the Collections view does not draw (XS).

**iPad, reading and organising (IPA)**
- **IPA-1 (with MAC-12):** the downloaded-only filter wears the Download glyph, persists, and blanks the Subseries list with no message. Its empty state rides with HCD-4; a filter glyph would change T1's captures (XS).
- **IPA-3's Sort half:** the whole-collection Sort's warning is shown nowhere (XS).
- **IPA-5:** no next or previous control while the rail is open; Back and Document ▸ Previous/Next remain (S).
- **IPA-7:** the rail header's ⓘ and Open in New Window are about 13 pt, and the tag ✕ 8 pt with no name of its own (XS).
- **IPA-9:** two empty states point at things not on screen (XS).
- **IPA-10:** ⌥⌘F on iPad switches tab without focusing the field, and the tabs have no menu items (XS).
- **IPA-11:** Project Home ▸ visit ▸ packet stacks three sheets (S).
- **IPA-12:** a project row in the sidebar's footer switches the app-wide project; probably deliberate.
- **IPA-13:** "Adds all 0 generated summaries" (XS); "Administra…" cut at the default size.

**Mac (MAC)**
- **MAC-4:** the reader's largest size is 136% of the default, and ⌘+/⌘− do nothing. This is CARRIED with the reader's text size; the HIG's 200% is "Ideally" (S).
- **MAC-7:**
  - the reader's verbs and Back and Forward are not in the menu bar;
  - there are no sidebar, toolbar or inspector commands;
  - "Show …" items do not change their title;
  - there is no Help ▸ User Manual;
  - ⇧⌘P and ⇧⌘A are repurposed (S).
- **MAC-8:** the person and gloss sheets bind Return and not Escape (XS).
- **MAC-9:** the rail and Facets toggles expose no on/off state (XS).
- **MAC-10:** Settings reopens on Volumes & Storage (XS).
- **MAC-11:** an iOS-style Done in the Collections inspector column (XS).
- **MAC-13:** opening a result raises the main window over Search. Deliberate, from an earlier fix (S).
- **MAC-14:** two alerts on one error binding (XS).

**App Review (ASR)**
- **ASR-5:** `webView.setValue(false, forKey: "drawsBackground")` reaches WebKit's private key on the Mac (`FRUSDocumentWebView.swift:673`). The risk is low; use `underPageBackgroundColor`, or keep it as a known risk (XS).

**Accessibility (A11Y)**
- **A11Y-4's highlight half:** making a highlight is silent (XS).
- **A11Y-6:** the rail's accordions expose no open or closed state (XS). Their fixed 10 and 11 pt fonts are CARRIED.
- **A11Y-7:** the Research tab's rows open by a tap gesture alone, with no keyboard route on the Mac (S).
- **A11Y-8:** a highlight can be removed only by pointing at its words (S–M).

**Cross-platform flows and words (HCD)**
- **HCD-6:** one dataset under seven names and five accounts of where it comes from (§7, for #1905).
- **HCD-7:** the Mac says "Not Signed In" for every unavailable iCloud status, and both platforms say "Settings → Apple ID" (XS).
- **HCD-9:** the Research Guide reopens at every launch while a long queue runs. #757 chose the per-session flag on purpose (XS, the owner's call).
- **HCD-10:** summarizing one long document shows a spinner with no part count and no Stop (XS–S).

---

## 5. Merged and re-rated

**Duplicates**, each counted once, under the finding that states it best:
- IPS-1 ← IPH-2;
- HCD-1 ← IPH-1 and HCD-2's onboarding half;
- IPA-2 ← IPH-4;
- MAC-2 ← IPA-3's delete half and HCD-8;
- HCD-3 ← A11Y-4's download half;
- IPS-2 ← IPA-8, IPH-10's contrast half and MAC-6's;
- IPA-1 ← MAC-12;
- HCD-6 ← IPS-5's topics half.

**Re-rated down, with the skeptic's reason:**
- IPH-6, S2 to S3: a narrow combination (no iCloud, accessibility sizes, a small iPhone), and the worst figures come from Search's heavy modes.
- IPS-2, S2 to S3: captions, with Increase Contrast variants.
- IPA-1, S2 to S3: one tap undoes it, and the Quick Start names it.
- IPA-5, S2 to S3: Back and the Document menu remain.
- IPA-3's Sort half, S2 to S3: the manual says what Sort keeps, and suggests Duplicate first.
- MAC-4, S2 to S3: CARRIED, and the HIG says "Ideally".

**Corrected:**
- HCD-1's default and *Recommended* are the owner's (C1).
- IPH-3's Done leaves the choice staged, not discarded.
- A11Y-5 counts seven tiles, not six.
- ASR-1 reaches three paths, not one.
- ASR-4 and MAC's "⌘P prints" agree: the command is wired, and no one has printed to a printer.

**Refuted: none.**

---

## 6. What only a running app can settle

Each check is in the row that fixes it, or in R6's device pass.

| Finding | The check | Where |
|---|---|---|
| ASR-1 | Save Image from an exported figure; long-press a reader figure; long-press an image in the in-app browser. iPhone 17, iOS 27.0 and 26.5, before and after the key | L17 |
| ASR-4 | File ▸ Print to a real printer from an AppStore-configuration build, Console open | L17, by the owner |
| IPA-6 | The four steps in §3, row L19 | L19 |
| A11Y-5 | Voice Control: "Tap Archives" on the Browse root | L21 |
| MAC-3 | The two toolbars measured at their windows' default sizes | L21 |
| MAC-8 | Escape on a person sheet | after 1.0 |
| IPH-7, IPH-8, IPH-9 | The Lock Screen during a queue; a queue's end on an iPhone; onboarding at AX3 and AX5 on an SE | R6, if at hand |
| A11Y-4 | Whether WebKit speaks a CSS Custom Highlight | after 1.0 |

---

## 7. #1905's naming, for the owner

The owner's issue says *detected topics* implies the app does the detecting, and asks for *tagged topics*. The review agrees with the objection, and found more. The data is the Office of the Historian's subject export, matched to documents by name before the app reads it. The provenance chip already calls it "FRUS + OH subjects" (`ProvenanceSource.swift:118`).

**Seven names for one dataset.**
- *Topics*: the rail (`ResearchRailView.swift:412`) and Browse (`CorpusView.swift:339`).
- *Top subjects*: the volume page (`VolumeView.swift:130`).
- *Subjects*: Facets (`FacetPanelView.swift:499`) and the person sheet (`PersonIndexView.swift:717`).
- *Detected Topic(s)*: the scope menus and Search's filter.
- *Subject…*: volume scopes (`CustomScopesView.swift:343`).
- *Shared topics*: Related (`FRUSCoreKit/RelatedDocuments/SimilarityModel.swift:118`).
- *assigned topics*: the Topic index (`SubjectIndexView.swift:486`).

**Five accounts of where it comes from.**
- "Detected automatically from the text" (`ResearchRailView.swift:420`).
- "inferred from the text" (`SearchFilterView.swift:1487`).
- "experimental enrichment data" (`:959`).
- "assigned" (`SubjectIndexView.swift:486`).
- "Detected topics from the Office of the Historian, matched by name" (`FacetPanelView.swift:1116`).

**Where "tagged" would land.**
- On the rail, the section directly above the reader's own **Tags** section; `research-rail.png` shows TOPICS, then TAGS.
- Beside the volume page's editorial **Tags** (`VolumeView.swift:121`).
- Beside Search's **My Tags**.

*Topics* already means a word-cloud lens and a category of the volumes' tags.

**The name the evidence supports** is *Subjects*, already used by the chip, the generator, Facets, Top subjects and the person sheet, with one shared caption naming the source. For example: "Office of the Historian subjects, matched to the text by name — not chosen by the volume's editors, so some are wrong." *Subjects* can be read as the editors' own subject headings, and the caption is what prevents that.

**Decided 2026-11-15** (the plan's decision 135): *Subjects*, with one caption everywhere, on the owner's terms. The owner said the data "is from the office of the historian, but it is still experimental and not published on their website", and asked that the caption "credit the office but not imply that it has reviewed this data and approved its editorial accuracy". The caption, word for word:

> Experimental subject data from the Office of the Historian, not published on history.state.gov. Subjects are matched to documents by name in the text; they are not editorial headings from the FRUS publication process, so some are wrong.

The bundled file's own provenance agrees: "Derived from the Office of the Historian public-domain frus-subjects handoff … Detected topics from case-insensitive string matching of subject names and variants" (`document-subject-index.json`). L15 (#1905) makes the change.

---

## 8. Looked at and found sound

- **The reader.**
  - `lang`, headings, spoken footnote buttons, broken references as labelled buttons;
  - contrast, underlines and the 24-pt targets of lists of links, gated by `ReaderPageTests` and `LinksAloneTargetRenderTests`;
  - the edit menu's colour dots named;
  - the edge-tap zones labelled.
- **Windows and state.**
  - Per-window `@SceneStorage` tabs on iPad, and hand-offs addressed to a scene.
  - Windows restored by value.
  - The Mac's main window as the first scene, so a Dock click with no windows reopens it.
  - Every tool window fronts (the 2026-08-27 audit's CLEAN verdict, not redone).
- **Commands and keys.**
  - The iPadOS menu bar's Document and Find menus.
  - Mac commands that grey out rather than vanish.
  - Return and Escape bound on most sheets.
  - Search's results opened by ↓ and Return, with a right-click menu.
- **Confirmations and recovery.**
  - Deleting a highlight, a collection or a section asks first; Erase Everything asks twice.
  - Removing a volume says what is kept.
  - Person Separate and Merge are undoable from Corrections.
  - Search's bulk actions carry Undo.
  - Data & Recovery's options are ordered by what each removes.
- **Honest numbers and labels.**
  - "1,000 loaded · N total", "closest matches", and Facets' "Describing all N matches";
  - zero results that name the term;
  - "not a subject heading" on clusters, and "not a claim of historical importance" on PageRank;
  - provenance chips in shape and words as well as colour;
  - clamped date ranges.
- **Accessibility settings.**
  - Reduce Motion: the splash pauses, the backdrop fades, the graph's animation is gated.
  - Reduce Transparency: solid cards.
  - Dark Mode: no fixed fills.
  - Onboarding fits at accessibility sizes on iPad (tested).
  - The tab shell's banner keeps clear of lists and the keyboard (#1565, #1070).
- **What App Review reads beyond §2 and §3.**
  - The 11 test seams are entirely inside `#if DEBUG`, and DEBUG is defined only in Debug.
  - No placeholder text.
  - Every `fatalError`, `precondition` and `try!` guards validated data.
  - The privacy manifest's three reasons (CA92.1, C617.1, E174.1) match the code, and `llama.framework` imports no required-reason symbol.
  - "Data Not Collected" holds: no SDKs, no identifiers, nothing sent to the National Archives without a key.
  - Hashing only, for export compliance.
  - Background modes used as declared.
  - The Mac sandboxed, with the model shipped as weights rather than code.
  - The listing's claims hold against the code.
  - The first frame of each store set carries the disclaimer.
- **#1893** is not reached by any layout the code allows that the reviewers could find:
  - the Mac's graph is at least 640 pt wide;
  - at compact width the iOS canvas is the sheet or window, 320 pt or more;
  - at regular width it is the window less a 321-pt list panel (`CrossReferenceGraphView.swift:409-416`).

  The plan's L16 clamps it anyway.
