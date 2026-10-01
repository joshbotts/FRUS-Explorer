# Manual revisions pending the owner's review

Plan-of-record decision P2 (2026-09-28): while the owner reviews `Docs/macOS-User-Manual.md` (handed back after Tier 2), **no lane edits either user manual.** Each lane appends its proposed changes here under its own heading instead. That keeps the owner's diff clean and lets the owner review Claude's proposals separately. After the hand-back, lane MANUALS applies the approved ones to the owner's version, and the iOS items feed DOCS-2.

Format, one entry per change:

- **Manual / section:** Mac §x.y (or iOS §x.y)
- **Current:** the sentence as it stands
- **Proposed:** the new sentence
- **Why:** the behaviour change and its code path (path:line), with the issue number
- **Owner:** ☐ approve ☐ edit ☐ reject

<!-- Lanes append below this line, one "## <LANE KEY> — <issues>" heading each. -->

## WB — #1422, #1464, #1476, #1478, #1481, #1483, #1527, #1531 (copy)

*Lane WB wrote the owner's 2026-09-30 EditableContent review into the app. These are the manual sentences that review, or the code it needed, makes wrong or out of step. Each quotes the manual as it stands at `origin/v2` b340c61b.*

- **Manual / section:** Mac §16.3 The FRUS Research Guide
- **Current:** Its pages fall into three groups: **About FRUS** (*The Official Record of American Foreign Policy*, *163 Years in Progress*, *Understanding What You're Reading*, *Using FRUS for Research*), …
- **Proposed:** Its pages fall into three groups: **About FRUS** (*The Official Record of American Foreign Policy*, *165 Years of Documenting U.S. Foreign Policy*, *Understanding What You're Reading*, *Using FRUS for Research*), …
- **Why:** the owner retitled the guide's second page; `FRUSExplorer/Onboarding/IndexingEducationView.swift:742` now ships `title: "165 Years of Documenting U.S. Foreign Policy"`.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery (the recovery-ladder table, **Fix iCloud Sync** row)
- **Current:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Nothing — iCloud is untouched |
- **Proposed:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Changes made on this Mac that have not reached iCloud yet; iCloud itself is untouched |
- **Why:** #1531: the owner's confirmation now says "Nothing in iCloud is deleted, but unsynced local data could be lost" (`FRUSExplorer/Settings/DataRecoveryView.swift:142`, `settings.dataRecovery.fixSync.message`), and the reset clears exports that never uploaded; the table's "Nothing" contradicts the dialog the reader is about to confirm. Lane SYNC may add a warning while an export is unrecovered; this row should follow whatever it ships.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery (the recovery-ladder table, **Fix iCloud Sync** row)
- **Current:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Nothing — iCloud is untouched |
- **Proposed:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Changes made on this device that have not reached iCloud yet; iCloud itself is untouched |
- **Why:** as for the Mac row above (#1531, `DataRecoveryView.swift:142`, shared by both platforms).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §7.12 Search by Meaning (Experimental), "Match files warm up over a few searches"
- **Current:** Scoring needs a small per-volume file; a match whose volume has none is left out and counted in the caption ("*N possible matches in M volumes could not be scored yet*").
- **Proposed:** Scoring needs a small per-volume file; a match whose volume has none is left out and counted in the caption. While every such volume's file is downloading it reads "*N possible matches in M volumes could not be scored yet; their match files are downloading*"; otherwise — **Download With Volumes** off, no connection, a file that failed to download this session, or volumes ranked below the top hundred, which a search never asks for — it reads "*…could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring*", and a search that scores nothing says the match files "are required" instead of "still downloading".
- **Why:** #1527, the owner's option (a) with the button's name changed in review round 1: `SemanticUnscoredCopy.unscored` and `.warming` (`FRUSExplorer/Search/SemanticMeaningModeViews.swift:105`, `:126`) claim a download only when every unscored volume's fetch request was answered with a download under way (`AppState.requestSemanticShardForSearch`, `FRUSExplorer/App/AppState.swift:897`; `SemanticQuerySearcher.Results.downloadingVolumes`), and otherwise name **Download Vectors for Every Volume**, because **Download Missing Vectors** fetches only for downloaded volumes — as this section's next sentence already says — while the unscored volumes are usually ones the reader has not downloaded. Nothing in the manual's following sentence changes.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §7.11 Search by Meaning (Experimental)
- **Current:** Scoring needs a small per-volume match file, and a candidate whose volume has none is left out; the caption counts what could not be scored.
- **Proposed:** Scoring needs a small per-volume match file, and a candidate whose volume has none is left out; the caption counts what could not be scored, says the files are downloading only while every one of them is, and otherwise points to **Download Vectors for Every Volume**.
- **Why:** #1527, as above (`SemanticMeaningModeViews.swift:105`, `:126`; the Mac search sheet reads the same `SemanticModeStrip.caption`). It agrees with the section's own later sentence that **Download Missing Vectors** fetches only for volumes you have downloaded.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.3a Semantic Vectors and the Search Model
- **Current:** **Remove Downloaded Vectors** frees the space without touching volumes, notes, or search — Related Documents keeps working, less precisely, until the files return.
- **Proposed:** **Remove Downloaded Vectors** frees the space without touching volumes, notes, or search — Related Documents keeps working, but without semantic matches until the files return.
- **Why:** the owner reworded the confirmation to "Related Documents keeps working, but semantic matches are unavailable until these files download again" (`FRUSExplorer/Settings/SemanticStorageSection.swift:339`, `settings.vectors.remove.detail.v2 %@`); the manual's "less precisely" is the wording it replaced.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §2.3 Onboarding, Step 3 — Ready
- **Current:** A confirmation that your volumes are downloading, plus a note that a starter research project named **"My Research"** has been created for you.
- **Proposed:** A confirmation that your volumes will download and index automatically, plus a note that if you have no project yet, a starter research project named **"My Research"** is ready.
- **Why:** the owner's Ready text is "Your volumes will download and index automatically — search unlocks in minutes. If you have no project yet, one named “My Research” is ready." (`FRUSExplorer/Onboarding/OnboardingView.swift:619`, `onboarding.ready.body`); onboarding creates the project only when none exists (`OnboardingCompletion.ensureDefaultProjectExists`, `FRUSExplorer/Onboarding/OnboardingScopeResolver.swift:200`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery
- **Current:** *(no mention of Semantic Match Feedback)*
- **Proposed:** Add the Mac §17.5 sentence's iOS twin: **Semantic Match Feedback** — the verdicts you recorded on Related Documents' semantic rows, with counts of verdicts recorded and marked helpful, **Prepare Feedback File** / **Share Feedback File** to hand them to the share sheet (the app sends nothing on its own), and **Clear Recorded Feedback**.
- **Why:** the owner's close-out pass (2026-09-30) made the screen's footer name that route (`FRUSExplorer/Settings/SemanticFeedbackView.swift:101`, `settings.semanticFeedback.privacy`), and the iOS manual is the only place a tester on an iPhone or iPad could look it up. Where to send the file is #1545; both manuals should name it once that lands.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14 the cross-reference graph, the **Gestures** bullet (`Docs/iOS-User-Manual.md:695`)
- **Current:** **Gestures**: tap a node to select it, pinch to zoom, two-finger drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…* (Section 14.4).
- **Proposed:** **Gestures**: tap a node to select it, pinch to zoom, drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window* (on iPhone and iPad it opens the document over the graph), and *Archival Neighbors…* (Section 14.4).
- **Why:** the owner confirmed `graph.info.interact.body.ios` ("Tap a node… Long-press to recenter the graph on that document or open it. Use pinch-to-zoom and drag to pan.") in the close-out pass. The canvas pans with a one-finger `DragGesture` (`CrossReferenceGraphView.swift:1612–1613`), and the iOS branch of *Open in Main Window* pushes onto the graph's own navigation stack (`:889–893`). If lane GRAPH relabels the item (D9), use its new name instead of the parenthesis.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §2.2 Onboarding, Step 2 — Scope (the scope table, **Corpus** row, `Docs/iOS-User-Manual.md:78`)
- **Current:** | **Corpus** | All 553 volumes in the bundled catalog (about 3.3 GB; downloading takes a while depending on your connection and free storage) |
- **Proposed:** | **Corpus** | All 553 volumes in the bundled catalog (about 3.5 GB with their match files; downloading takes a while depending on your connection and free storage) |
- **Why:** the owner's close-out pass (C1) changed the onboarding caption to "≈ 3.5 GB" (`FRUSExplorer/Onboarding/OnboardingView.swift:609`): 3,338,778,538 bytes of volume XML plus 162,354,028 bytes of match files, which Download With Volumes (on by default) fetches with each volume. The Mac manual's "about **3.3 GB** of XML" (`Docs/macOS-User-Manual.md:74`) is accurate as written, since it names the XML; it could add "plus about 160 MB of match files". The subseries caption now reads "recommended if you want to start smaller" if either manual quotes it.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.7 Chronology (`Docs/iOS-User-Manual.md:1201`) and Mac §15.7 Chronology (`Docs/macOS-User-Manual.md:1083`), the **distribution chart** bullet in each
- **Current:** iOS: "…Two companion sections keep it honest: **Spans this period** collects wide-span documents (mostly editorial notes) rather than smearing them across the chart, and **Extends beyond this range**…". Mac: the same sentence with "(chiefly editorial notes)".
- **Proposed:** In both, replace "**Spans this period** collects wide-span documents" with "**Spans more than a year** collects documents whose dates span more than a year", keeping each manual's parenthesis: iOS "…**Spans more than a year** collects documents whose dates span more than a year (mostly editorial notes) rather than smearing them across the chart, and **Extends beyond this range**…"; Mac the same with "(chiefly editorial notes)".
- **Why:** #1422, the owner's option (a) plus the header. The section header is now "Spans more than a year" (`ChronologyViewModel.spanningSectionHeader`, `FRUSExplorer/Chronology/ChronologyViewModel.swift:613`, key `chronology.spanning.header`) and its chip reads "N documents span more than a year" (`spanningChipTitle`, `:590`). A row is listed because its dates overlap the range (`IndexingPipeline.documentsInDateRange`), so it need not span the whole period, and it is sorted there when its dates lie more than 366 days apart (`ChronologyViewModel.partition`, `maxSpanDaysForPlacement`). Both manuals' parentheses stay true: 36 of 7,137 such rows in a 553-volume index are not editorial notes.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 The Archives Visit Packet, the **Archives Visits window** paragraph (`Docs/macOS-User-Manual.md:931`)
- **Current:** "…a **plan picker in the toolbar** switches between plans (its menu also holds **New Archives Visit…** and **Manage Archives Visits…** — rename inline, duplicate, or delete from the Manage sheet)…"
- **Proposed:** "…a **plan picker in the toolbar** switches between plans (its menu also holds **New Archives Visit** and **Manage Archives Visits…** — rename inline, duplicate, or delete from the Manage sheet)…"
- **Why:** #1483, the owner's choice "all A": `archiveVisit.picker.new` reads "New Archives Visit" on both platforms (`FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift:235`, `FRUSExplorer/TripPacket/PlanPickerSheet.swift:179`). The Mac item creates the plan at once (`createPlan()`) and opens no dialog, so it has no ellipsis. **Manage Archives Visits…** keeps its ellipsis because it opens a sheet. No other passage of either manual quotes any of #1483's ten texts.
- **Owner:** ☐ approve ☐ edit ☐ reject

## LANG — #1539

*Lane LANG makes the app check its language analysis again each time it returns to the foreground, starts the iPhone and iPad warm-up on the first foreground rather than at launch, and adds a read-only **Language Analysis** row to Data & Recovery. These are the manual sentences that change makes wrong or incomplete. Each quotes the manual as it stands at `origin/v2` 95bfc706.*

- **Manual / section:** Mac §15.2 Word Cloud, the **Lenses** bullet
- **Current:** …the lens says it is unavailable instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed), and quitting and reopening the app may restore it.
- **Proposed:** …the lens says it is unavailable instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed). The app checks the analysis again each time you switch back to it, and the cloud redraws by itself if it has recovered; if it has not, quitting and reopening the app may restore it.
- **Why:** #1539 step B. `NaturalLanguageReadinessEngine.applicationDidBecomeActive()` (`WordCloudKit/NaturalLanguageReadiness.swift:856`) re-checks a verdict that lacks a capability on every activation (`LanguageAnalysisLifecycle`, `FRUSExplorer/App/FRUSExplorerApp.swift:4506`), and the Word Cloud's load is keyed on the adopted verdict's revision (`FRUSExplorer/Analytics/WordCloud/WordCloudView.swift:656`). The two refusals now say so (`wordcloud.lens.unavailable.names %@ %@` and `.classes %@ %@`, `WordCloudView.swift:386`, `:390`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.2 Word Cloud, the **Lenses** bullet (its last sentence)
- **Current:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out.
- **Proposed:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out. When a later check finds the analysis working, the cloud is counted again in dictionary forms and an open Collocates panel rebuilds without your doing anything.
- **Why:** #1539. A count made as printed is no longer reused from memory once the verdict changes (`WordFrequencyService.isReusableInMemory`, `FRUSExplorer/Analytics/WordCloud/WordFrequencyService.swift:247`), and the Collocates panel's rebuild key carries the revision (`CollocationRebuildKey.language`, `FRUSExplorer/Search/CollocationView.swift:377`; the Mac window's task at `FRUSExplorer/App/SearchSheet.swift:603`). The Distinctive refusal says so (`wordcloud.keyness.unavailable.languageAnalysis`, `WordCloudView.swift:1020`) and so does the Collocates one (`search.collocation.unavailable.languageAnalysis`, `CollocationView.swift:251`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.2 Word Cloud, the **Lenses** bullet
- **Current:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed), and quitting and reopening the app may restore it.
- **Proposed:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed). The app checks the analysis again each time you come back to it — from the Home Screen or another app — and the cloud redraws by itself if it has recovered; if it has not, quitting and reopening the app may restore it.
- **Why:** as for the Mac (#1539; `NaturalLanguageReadiness.swift:856`, `FRUSExplorerApp.swift:4506`, `WordCloudView.swift:656`, `:386`, `:390`). On iPhone and iPad the app also no longer starts this check in a background launch (a CloudKit push, a background task, a finished download), which is the cause the owner's force-quit result points to (`FRUSExplorerApp.swift:504`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.2 Word Cloud, the **Lenses** bullet (its last sentence)
- **Current:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading (Section 7.6) steps aside for the same reason, and a related document's shared-word chips are left out.
- **Proposed:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading (Section 7.6) steps aside for the same reason, and a related document's shared-word chips are left out. When a later check finds the analysis working, the cloud is counted again in dictionary forms and an open Collocates panel rebuilds without your doing anything.
- **Why:** as for the Mac (#1539; `WordFrequencyService.swift:247`, `CollocationView.swift:377`, the iOS Search tab's task at `FRUSExplorer/Search/SearchView.swift:621`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery, the **Diagnostics** sentence
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (…), **Semantic Match Feedback** — (…) — and the **iCloud Schema** status (…).
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (…), **Semantic Match Feedback** — (…) — the **iCloud Schema** status (…), and **Language Analysis**: whether this Mac's language analysis is reducing words to their dictionary forms, telling parts of speech apart and recognizing names — *Working*, *Limited* (naming what is not working; the app checks again each time you switch back to it), or *Checking* while it finds out.
- **Why:** #1539 step A: `LanguageAnalysisRow` in the Diagnostics section (`FRUSExplorer/Settings/DataRecoveryView.swift:95`, its wording at `:679`), one view on both platforms.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery, the **Diagnostics** sentence
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content) and the **iCloud Schema** status.
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content), the **iCloud Schema** status, and **Language Analysis**: whether this device's language analysis is reducing words to their dictionary forms, telling parts of speech apart and recognizing names — *Working*, *Limited* (naming what is not working; the app checks again each time you come back to it), or *Checking* while it finds out.
- **Why:** as for the Mac (#1539; `DataRecoveryView.swift:95`, `:679`). The iOS sentence also omits **Semantic Match Feedback**, which the same section shows on iPhone and iPad; that is older than this lane and is left to lane MANUALS.
- **Owner:** ☐ approve ☐ edit ☐ reject
