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
- **Proposed:** Scoring needs a small per-volume file; a match whose volume has none is left out and counted in the caption. While every such volume's file is downloading it reads "*N possible matches in M volumes could not be scored yet; their match files are downloading*"; otherwise — **Download With Volumes** off, no connection, or volumes ranked below the top hundred, which a search never asks for — it reads "*…could not be scored. Try Download Missing Vectors in Settings to enable scoring*", and a search that scores nothing says the match files "are required" instead of "still downloading".
- **Why:** #1527, the owner's option (a): `SemanticUnscoredCopy.unscored` and `.warming` (`FRUSExplorer/Search/SemanticMeaningModeViews.swift:100`, `:127`) claim a download only when `AppState.semanticShardFetchesRun` (`FRUSExplorer/App/AppState.swift:878`) holds and the searcher asked for every unscored volume (`SemanticQuerySearcher.Results.queuedVolumes`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §7.11 Search by Meaning (Experimental)
- **Current:** Scoring needs a small per-volume match file, and a candidate whose volume has none is left out; the caption counts what could not be scored.
- **Proposed:** Scoring needs a small per-volume match file, and a candidate whose volume has none is left out; the caption counts what could not be scored, says the files are downloading only while every one of them is, and otherwise points to **Download Missing Vectors**.
- **Why:** #1527, as above (`SemanticMeaningModeViews.swift:100`, `:127`; the Mac search sheet reads the same `SemanticModeStrip.caption`).
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
