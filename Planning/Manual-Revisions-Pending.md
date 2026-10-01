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

## NOTE — #1514, #1515, #1404

*Lane NOTE re-routed the Department of State's own series, the FOIA reading room and the Nixon materials out of the central files, read Subject-Numeric designators the identifier rule refused, fixed the packet's crib and divided-lot lines, and corrected the pre-1906 classifier's Department cue (#1514, decision D2 "wide", and its §2 fold-ins). These are the manual sentences that change makes wrong or incomplete. Each quotes the manual as it stands at `origin/v2` 95bfc706. #1404 is test-only and changes no manual.*

- **Manual / section:** Mac §14.1 What Resolves, and How — the table's **Named file series** row (`Docs/macOS-User-Manual.md:858`)
- **Current:** | **Named file series** (`Roosevelt Papers`, `J.C.S. Files`, `Moscow Embassy Files`) | Where the volume's own Sources section says where the series is held, that destination is shown **with the editors' sentence quoted beneath it**, so the claim is checkable rather than asserted. Joint Chiefs files resolve to RG 218, SWNCC to RG 353, and Foreign Service post files (a city's Embassy, Legation, Consulate, or Post Files) to RG 84 | No |
- **Proposed:** | **Named file series** (`Roosevelt Papers`, `J.C.S. Files`, `Moscow Embassy Files`, and the Department of State's own series — the INR/IL Historical Files, the INR–NIE, Bundy, Har-Van, IO, USUN and Executive Secretariat files) | Where the volume's own Sources section says where the series is held, that destination is shown **with the editors' sentence quoted beneath it**, so the claim is checkable rather than asserted. Joint Chiefs files resolve to RG 218, SWNCC to RG 353, and Foreign Service post files (a city's Embassy, Legation, Consulate, or Post Files) to RG 84. A series whose citation names the agency holding it — the Department of State's, or the National Security Council's — says so, is not treated as the central files, and is not offered the Department of State's records page at the National Archives | No |
- **Why:** #1514: a citation led by the Department that names neither the central files nor a file number is now a named series `Department of State, <series>` (`SourceNoteKit/SourceNoteParser.swift:2721`, `tryDepartmentSeries`), where it was filed as RG 59 and drew the Central Files panel; 567 notes in the corpus move. The panel's note names the holder (`FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift:318`, `source.explorer.namedSeries.note.held`). Review round 1: NARA's State records page is withheld for such a series (`NamedFileSeriesRouting.offersStateRecordsLink`, `FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift:338`), because frus1964-68v07's Sources describes the INR/IL Historical Files as "still under Department of State custody" and another agency's series are not State records.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.1 — the table's **Previously published** row (`Docs/macOS-User-Manual.md:862`)
- **Current:** "… Publications outside the four families show the citation as before | No |"
- **Proposed:** "… Publications outside the four families show the citation as before. An agency's online FOIA reading room — the State Department's Electronic Reading Room of Kissinger telephone transcripts, its Virtual Reading Room — counts as published, since the text FRUS printed is the agency's own release; so do the Department's press releases and its *Dispatch* | No |"
- **Why:** #1514: `SourceNoteParser.leadsWithReadingRoom` (`SourceNoteKit/SourceNoteParser.swift:2817`) and the new publication leads; 35 notes move, 31 of them from the central files.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.1 — the table's **Pre-1910 Central Files** row (`Docs/macOS-User-Manual.md:853`), after "(… never to an instruction or despatch)"
- **Current:** "… resolves to that legation's Notes to or from Foreign Missions, never to an instruction or despatch) — plus the chronological runs …"
- **Proposed:** "… resolves to that legation's Notes to or from Foreign Missions, never to an instruction or despatch; a letter the Secretary of State signed is the Department's from wherever he wrote it, Seward at Auburn or Blaine at Bar Harbor; and a department of state that is not the U.S. one — the Confederate department at Richmond, or a foreign ministry so styled — is not read as the Department) — plus the chronological runs …"
- **Why:** the 2026-09-28 audit's fold-in into #1514: `CentralFilesClassifier.isUSDepartmentDateline` and `sittingSecretarySender` (`FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift:541`, `:609`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 The Archives Visit Packet, the **research targets** paragraph (`Docs/macOS-User-Manual.md:935`)
- **Current:** "… (with the file or folder designation their source note cites — none when the note names only the series or says only how many pages are withheld, and none for some notes that do name a file, such as one without a number (`POL ARAB–ISR`) or one given only as a volume number or a web address), …"
- **Proposed:** "… (with the file or folder designation their source note cites — none when the note names only the series or says only how many pages are withheld, and none for some notes that do name a file, such as one cited under the National Archives' own name and record group (`RG 59, Central Files 1967–69, POL 27–14 VIET`) or a Subject-Numeric file without a number whose country is not printed in capitals (`POL Laos`)), …"
- **Why:** #1514 and #1515 removed the three examples the sentence gives: a Subject-Numeric file with no number is stored (`POL ARAB–ISR`, `ParsedSourceNote.isDigitlessSubjectNumeric`, `SourceNoteKit/SourceNoteParser.swift:273`); the eight notes given only as a volume number are INR/IL series whose folder is now named with its volume (`Carlson –Department Messages, Vol. 4, 1965–69`); and the notes given only as a web address are the FOIA reading room, now a publication, which seeds no file. The caveat itself stays (review round 1), with two examples that are still true: `TripPacketBuilder.fileDesignation` gives no designation for any note the parser reads as a National Archives collection (`FRUSExplorer/TripPacket/TripPacketBuilder.swift:399`) — 5,951 notes in the corpus cite `RG 59, Central Files` that way, frus1964-68v06/d131 among them — and the number-less designator rule reads only a category in capitals, an optional agency, a space and a country element in capitals, so 126 central-file notes in 11 volumes still store none (review round 2, which corrects round 1's "31 … in 7 volumes"): 30 whose country is not printed in capitals (`POL Laos`, `POL Pol–US`, 24 of them in frus1961-63v16), 54 commodity files joined to their category by a dash (`INCO–GRAINS GATT` ×15), 21 with an agency and no country (`DEF(MLF)` ×16) and 21 with a title-case category (`Pol Port-US` ×4, all frus1961-63v13). 55 more cite an `AID` file with no number (`AID (US) S VIET`), a category the rule does not know. The lane's DEVELOPMENT-PLAN entry lists them under *Still open*.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 — the **coverage report** paragraph (`Docs/macOS-User-Manual.md:943`)
- **Current:** "… the digitized-substitute denominators, and how much of the restriction picture is actually measured."
- **Proposed:** "… the digitized-substitute denominators, and how much of the restriction picture is actually measured — a divided lot's claimant series included, so a plan is never called unrestricted while one of them is restricted or has no recorded status."
- **Why:** the audit's divided-lot fold-in: the access block now opens on divided lots as well as on the triage, and its all-clear sentence waits for them (`FRUSExplorer/TripPacket/TripPacketExporter.swift:689`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.2 What Resolves, and How — the **Named file series** bullet (`Docs/iOS-User-Manual.md:1018`)
- **Current:** "- **Named file series** (`Roosevelt Papers`, `J.C.S. Files`, `Moscow Embassy Files`): where the volume's own front-matter Sources section states where the series is held, …"
- **Proposed:** "- **Named file series** (`Roosevelt Papers`, `J.C.S. Files`, `Moscow Embassy Files`, and the Department of State's own series such as the INR/IL Historical Files, which are not the central files): where the volume's own front-matter Sources section states where the series is held, … A series whose citation names the agency holding it says so, and is not offered the Department of State's records page at the National Archives."
- **Why:** as for the Mac row above (#1514; `NamedFileSeriesRouting.explainer`, `FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift:308`, `source.explorer.namedSeries.explainer.held`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.2 — the **CIA records** bullet (`Docs/iOS-User-Manual.md:1020`)
- **Current:** "- **CIA records** link to the CREST page; foreign-archive and previously-published notes display their parsed citation."
- **Proposed:** "- **CIA records** link to the CREST page; foreign-archive and previously-published notes display their parsed citation. An agency's online FOIA reading room — the State Department's Electronic Reading Room of Kissinger telephone transcripts — counts as published, as do the Department's press releases."
- **Why:** as for the Mac row above (#1514).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.2 — the **Pre-1910 Central Files** bullet (`Docs/iOS-User-Manual.md:1014`)
- **Current:** "… (a chapter of correspondence with a foreign legation in Washington, such as *British legation.*, resolves to that legation's Notes to or from Foreign Missions, never to an instruction or despatch), …"
- **Proposed:** "… (a chapter of correspondence with a foreign legation in Washington, such as *British legation.*, resolves to that legation's Notes to or from Foreign Missions, never to an instruction or despatch; a letter the Secretary of State signed is the Department's from wherever he wrote it; and a Confederate or foreign department of state is not read as the Department), …"
- **Why:** as for the Mac row above.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 The Archives Visit Packet — **The advance inquiry**, the list of what the app cannot place (`Docs/macOS-User-Manual.md:941`), and iOS §14.8, the same sentence (`Docs/iOS-User-Manual.md:1068`)
- **Current:** "What the app cannot place at any repository — a records center whose holdings may since have moved, a foreign archive, a citation it could not read, or a repository the app has no curated entry for, such as the Library of Congress, the National Defense University or a university library — gets a **Confirm before you travel** list instead, …"
- **Proposed:** "What the app cannot place at any repository — a records center whose holdings may since have moved, a file series its citation places with an agency rather than the National Archives, such as the Department of State's INR/IL Historical Files or a National Security Council series, a foreign archive, a citation it could not read, or a repository the app has no curated entry for, such as the Library of Congress, the National Defense University or a university library — gets a **Confirm before you travel** list instead, …"
- **Why:** #1514, review round 1: such a series used to be placed at College Park, as if the citation had named the National Archives (`ResearchFacilityResolver.facility`, step 5, `FRUSExplorer/TripPacket/ResearchFacility.swift:199`). 1,171 notes in 144 volumes are cited this way, 567 of them the Department's own series and 514 the National Security Council's; frus1964-68v07's Sources describes the INR/IL Historical Files as "still under Department of State custody".
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.8 The Archives Visit Packet — the **research targets** paragraph (`Docs/iOS-User-Manual.md:1062`) and the **coverage report** paragraph (`Docs/iOS-User-Manual.md:1070`)
- **Current:** the same two sentences as the Mac §14.8 entries above.
- **Proposed:** the same two changes.
- **Why:** as above; the packet is shared by both platforms.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** screenshots — iOS §6 Browse, Archives (`screenshots/ipad/browse-archives-provenance.png`, `Docs/iOS-User-Manual.md:369`)
- **Current:** the Provenance Types lens captured with build 48's counts.
- **Proposed:** recapture once build 49 ships the regenerated artifact (owner step).
- **Why:** the lens counts document source notes from the bundled `collection-usage-index.json` (`FRUSExplorer/Browser/ArchivesBrowseView.swift`), whose category counts move (measured on the regenerated artifact): Central Decimal File 601 notes fewer and 50 fewer volumes (410 → 360 — every central-file note those volumes had was a Department series or the reading room), Named File Series 567 more (221 → 265 volumes), Previously Published 35 more (132 → 142), Presidential Library 8 more, Unrecognized 6 fewer, Central Foreign Policy File 3 fewer, Intelligence 1 fewer, Lot File 1 more (#1514).
- **Owner:** ☐ approve ☐ edit ☐ reject
