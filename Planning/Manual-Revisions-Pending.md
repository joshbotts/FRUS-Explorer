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
- **Why:** #1531: the owner's confirmation now says "Nothing in iCloud is deleted, but unsynced local data could be lost" (`FRUSExplorer/Settings/DataRecoveryView.swift:286`, `settings.dataRecovery.fixSync.message`), and the reset clears exports that never uploaded; the table's "Nothing" contradicts the dialog the reader is about to confirm. Lane SYNC may add a warning while an export is unrecovered; this row should follow whatever it ships.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery (the recovery-ladder table, **Fix iCloud Sync** row)
- **Current:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Nothing — iCloud is untouched |
- **Proposed:** | **Fix iCloud Sync** | Clears the local copy so the app re-downloads from iCloud | Changes made on this device that have not reached iCloud yet; iCloud itself is untouched |
- **Why:** as for the Mac row above (#1531, `DataRecoveryView.swift:286`, shared by both platforms).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §7.12 Search by Meaning (Experimental), "Match files warm up over a few searches"
- **Current:** Scoring needs a small per-volume file; a match whose volume has none is left out and counted in the caption ("*N possible matches in M volumes could not be scored yet*").
- **Proposed:** Scoring needs a small per-volume file; a match whose volume has none is left out and counted in the caption. While every such volume's file is downloading it reads "*N possible matches in M volumes could not be scored yet; their match files are downloading*"; otherwise — **Download With Volumes** off, no connection, a file that failed to download this session, or volumes ranked below the top hundred, which a search never asks for — it reads "*…could not be scored. Try Download Vectors for Every Volume in Settings to enable scoring*", and a search that scores nothing says the match files "are required" instead of "still downloading".
- **Why:** #1527, the owner's option (a) with the button's name changed in review round 1: `SemanticUnscoredCopy.unscored` and `.warming` (`FRUSExplorer/Search/SemanticMeaningModeViews.swift:105`, `:126`) claim a download only when every unscored volume's fetch request was answered with a download under way (`AppState.requestSemanticShardForSearch`, `FRUSExplorer/App/AppState.swift:919`; `SemanticQuerySearcher.Results.downloadingVolumes`), and otherwise name **Download Vectors for Every Volume**, because **Download Missing Vectors** fetches only for downloaded volumes — as this section's next sentence already says — while the unscored volumes are usually ones the reader has not downloaded. Nothing in the manual's following sentence changes.
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

- **Superseded** (lane GRAPH review round 1, 2026-10-01): by lane GRAPH's entry for the same bullet, at the end of this file, which relabels the item as this entry anticipated and is measured on iPhone and iPad. Review that one instead; this one is kept only as WB wrote it. (The bullet is in iOS §8.6, not §14, and the line numbers cited below have since moved.)
- **Manual / section:** iOS §14 the cross-reference graph, the **Gestures** bullet (`Docs/iOS-User-Manual.md:695`)
- **Current:** **Gestures**: tap a node to select it, pinch to zoom, two-finger drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…* (Section 14.4).
- **Proposed:** **Gestures**: tap a node to select it, pinch to zoom, drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window* (on iPhone and iPad it opens the document over the graph), and *Archival Neighbors…* (Section 14.4).
- **Why:** the owner confirmed `graph.info.interact.body.ios` ("Tap a node… Long-press to recenter the graph on that document or open it. Use pinch-to-zoom and drag to pan.") in the close-out pass. The canvas pans with a one-finger `DragGesture` (`CrossReferenceGraphView.swift:1615–1616`), and the iOS branch of *Open in Main Window* pushes onto the graph's own navigation stack (`:892–896`). If lane GRAPH relabels the item (D9), use its new name instead of the parenthesis.
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

## STOR — #1526, #1432, #1476

*Lane STOR (2026-10-01). #1526, #1538 and the two fold-ins (the side-loaded Remove message's asterisks, boot reconciliation of side-loaded volumes) change no sentence either manual prints: neither manual describes the indexed count reading wrong after Rebuild Index, the 0-byte file a failed export left, the asterisks, or a raw id in place of a side-loaded volume's title. These are the hero's states (#1476) and the Free Up Space rows (#1432). Each quotes the manual as it stands at `origin/v2` 95bfc706.*

- **Manual / section:** Mac §17.2 Volumes & Storage
- **Current:** It opens with a **Storage used** bar split into **XML**, **Index**, **Summaries**, and **Vectors**, a status line, and the two ways in — **Download from GitHub…** and **Sideload XML File…**.
- **Proposed:** It opens with a **Storage used** bar split into **XML**, **Index**, **Summaries**, and **Vectors**, a status line, and the two ways in — **Download from GitHub…** and **Sideload XML File…**. Until the pane has measured the library the size reads "—" and the status line *Measuring…*; if measuring fails, *Could not measure storage*, with the reason in a row beneath (a re-measure that fails keeps the last figures). While volumes are being removed the status line counts them separately — *1 being removed* — rather than as downloaded.
- **Why:** #1476, the owner's 2026-09-30 wording. Both hubs draw `DownloadedVolumesListModel.heroContent(catalogCount:interruptedCount:)` (`FRUSExplorer/Settings/StorageHubModel.swift`, the hero at `FRUSExplorer/Settings/MacVolumesStorageHub.swift:270`), and the Mac now measures through `DownloadedVolumesListModel.measure(_:)`, which keeps the error instead of `try?` and the last report on a failure; the failure row is new on the Mac (`MacVolumesStorageHub.swift:289`). The clause is `settings.hub.summary.removing.one` / `settings.hub.summary.removing %lld` (`FRUSExplorer/Settings/SettingsComponents.swift:139`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.2 Volumes & Storage
- **Current:** Opens with a **Storage used** bar split into XML and index, and a status line.
- **Proposed:** Opens with a **Storage used** bar split into XML and index, and a status line. Until the pane has measured the library the size reads "—" and the status line *Measuring…*; if measuring fails, *Could not measure storage*, with the reason in a row beneath. While volumes are being removed the status line counts them separately — *1 being removed* — rather than as downloaded.
- **Why:** #1476, as for the Mac (`DownloadedVolumesListModel.heroContent`, `FRUSExplorer/Settings/StorageHubModel.swift`; the iOS hero at `FRUSExplorer/Settings/VolumesStorageHubView.swift:251`). The sentence "split into XML and index" is also short of the four segments the bar draws, which is not this lane's change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.2 Volumes & Storage (the **Storage & Index** item)
- **Current:** **Free Up Space…**, which lists only volumes with nothing of yours attached, ordered by what you'd recover, and asks first;
- **Proposed:** **Free Up Space…**, which lists only volumes with nothing of yours attached, ordered by what you'd recover, and asks first — while it removes, its rows are dimmed and cannot be ticked or unticked;
- **Why:** #1432: the rows used to stay tappable mid-removal, toggling a checkmark and the recovery estimate that changed nothing being removed. `FreeUpSpaceSheet.candidateRow` now carries `.disabled(isRemoving)` (`FRUSExplorer/Settings/VolumesStorageHubView.swift:1875`); the Mac's sheet already blocked its rows, by covering them with an overlay while it removes (`MacVolumesStorageHub.swift:1935`). Optional: the manual says nothing about the removal's progress at all.
- **Owner:** ☐ approve ☐ edit ☐ reject

## PAGE — #1509, #1510, #1511

*Lane PAGE (index v63). Each entry quotes the manual as it stands at `origin/v2` 95bfc706. Review round 1 corrected the scope of the first two (the footnote decides whenever the page names several documents, not only when several begin on it) and added the three after them (iOS §15.4, Mac §11.4, iOS §11.4); review round 2 widened the two §11.4 proposals to the breaks a chapter with text of its own gives up.*

- **Manual / section:** Mac §8.5 The Cross-Reference Graph (the last bullet, and the `OPEN #1509` comment under it)
- **Current:** Page-number references ("see p. 427") resolve to the document that begins on the cited page — when several begin on it, the first of them, and when none does, the document printed on it — and references confirmed unresolvable (8.2) are excluded — every edge you see leads to a real document.
- **Proposed:** Page-number references ("see p. 427") resolve to the document that begins on the cited page, or, when none does, the document printed on it — and when the page names several, to the one the footnote names by its document number (*Doc. No. 497*) or its date (*telegram of July 7*), or the first of them when it names neither — and references confirmed unresolvable (8.2) are excluded — every edge you see leads to a real document. Clicking the page link in the document opens the same document the graph draws. *(Delete the `OPEN #1509` comment.)*
- **Why:** #1509: the stored edge and the reader's page link now both go through `PageSpanResolver.citedDocument(among:facts:citing:)` (`FRUSExplorer/Citation/PageSpanResolver.swift:310`), called by `IndexingPipeline.resolvePageBasedCrossReferences` (`FRUSExplorer/Search/IndexingPipeline.swift:8661`) and by the Mac reader's `resolvePageReference` through `PageRangeStore.document(forPage:inVolume:citing:)` (`FRUSExplorer/App/MacDocumentView.swift:1217`). The footnote's numbers and dates come from `PageCitationHint(citingText:)` (`PageSpanResolver.swift:429`). It runs whenever the page names several, whatever the claim: of the 2,218 edges it moves, 2,216 cite a page several documents begin on and 2 a page none begins on and several are printed on (`tools/page-citations/v63.py`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8.6 The Cross-Reference Graph (the bullet beginning "Nodes in undownloaded volumes")
- **Current:** References confirmed unresolvable (Section 8.2) are excluded rather than drawn as dead ends, and page-number references ("see p. 427") resolve to their true target documents.
- **Proposed:** References confirmed unresolvable (Section 8.2) are excluded rather than drawn as dead ends, and page-number references ("see p. 427") resolve to the document that begins on the cited page, or, when none does, the one printed on it — of several, the one the footnote names by its document number or its date, otherwise the first — which is also the document tapping the link opens.
- **Why:** #1509, as above; the iPhone and iPad reader's page link is `DocumentView.resolvePageReference` (`FRUSExplorer/DocumentView/DocumentView.swift:1372`). "Their true target documents" claimed more than either the old rule (the first) or the new one (the footnote's choice, else the first) can know.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.4 Cross-Reference Analytics (the paragraph beginning "A **Scope** bar")
- **Current:** The document-level figures include same-volume citations; page-number references resolve to their true targets; references confirmed unresolvable are excluded, and a caption discloses how many.
- **Proposed:** The document-level figures include same-volume citations; a page-number reference counts toward the document that begins on the cited page, or, when none does, the one printed on it — of several, the one its footnote names by document number or date, otherwise the first; references confirmed unresolvable are excluded, and a caption discloses how many.
- **Why:** #1509 review round 1: the same overclaim as iOS §8.6 above. Cross-Reference Analytics reads the stored `cross_references` edges through `CrossReferenceStore` (`FRUSExplorer/CrossReference/CrossReferenceStore.swift:604`), which `IndexingPipeline.resolvePageBasedCrossReferences` writes by `PageSpanResolver.citedDocument` (`FRUSExplorer/Search/IndexingPipeline.swift:8661`). The Mac's §15.4 says only that "page-number references count alongside document-number ones", which stays true, so it needs no change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.4 Citation Lookup (the labels table, the last sentence of the **Possible match — one of *N* documents that begin on page *P*** row)
- **Current:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — is never the answer to a page it begins on
- **Proposed:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — never answers a page just by beginning on it: a page finds it only where the section is printed, by a page break inside it or by the break printed just before it, when the chapter or compilation around it has nothing of its own on that page but a heading. That is how page 57 of the *Paris Peace Conference* Volume XIII finds the Preamble, which begins there, and page 135 Section I of Part III, which begins there after Part III's own notes end on page 134
- **Why:** #1510 (owner decision D1, review rounds 1 and 2): a section still records no start, but `TEIParserDelegate.finishParse` (`FRUSExplorer/TEI/FRUSDocumentParser.swift:1167`) gives the section that begins after them the breaks a container leaves — every break of a compilation, chapter or subchapter holding nothing but its heading, which is not indexed, and the breaks one with text of its own prints after that text, before or between the sections it holds (`FRUSDocumentAST.carriedPages`) — and the index stores them as that section's `page_ranges` rows (`FRUSExplorer/Search/IndexingPipeline.swift:4976`), which `PageSpanResolver.documents(onPage:in:)` reads as pages the section is printed on. 41 such breaks reach 37 sections, 19 of them given up by the 15 chapters with text of their own, all in `frus1919Parisv13` (`tools/page-citations/v63.py`), so those sections can answer pages they begin on: in `frus1919Parisv13`, p. 57 is ch9, the Preamble, from the heading-only comp3, and p. 135 is ch12subch1, Section I of Part III, from ch12, whose own notes end on p. 134 (`RealTEIPageCitationsV63Tests.parisv13Containers`; `ContainerTests.proseContainerIsNarrowedToItsOwnText` on a fixture). Citation Lookup reports either as a page match through `matchByPageRange` (`FRUSExplorer/Citation/CitationMatchingEngine.swift:1023`). Before #1510 p. 57 answered comp3 alone, and p. 135 ch12 and comp3 together (measured with the container rule off). A container's heading may share the page, which is why the clause allows one: ch10, Part I, left out too, prints only its heading on p. 69, and p. 69 is its first section, ch10subch1. Review round 2 widened the clause, which as first proposed named only the container holding nothing but its heading and so was false for the 19 breaks the chapters with text give up.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §11.4 Citation Lookup, in Both Directions (the paragraph beginning "A citation that names a page but no document")
- **Current:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — is never the answer to a page it begins on.
- **Proposed:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — never answers a page just by beginning on it: a page finds it only where the section is printed, by a page break inside it or by the break printed just before it, when the chapter or compilation around it has nothing of its own on that page but a heading. That is how page 57 of the *Paris Peace Conference* Volume XIII finds the Preamble, which begins there, and page 135 Section I of Part III, which begins there after Part III's own notes end on page 134.
- **Why:** as for the Mac entry above.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §6.3 The People Browser (the paragraph on **active years**)
- **Current:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Proposed:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* — or *until his resignation on April 22, 1959* — is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Why:** the persons-list fold-in of lane PAGE (#1370's left-open item): a year after "until" or "till" and another event before its date ("until his resignation on", "until country renamed in", "until overthrown on") is now an end, not a start — `endEventCueRegex` and its use in `PersonsParserDelegate.yearSpan(in:)` (`FRUSExplorer/TEI/FRUSDocumentParser.swift:2003`, `:2191`). Until v63 Dulles's List of Persons entry in `frus1958-60v03` read **1959** as the year he began.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §6.5 The People Browser (the paragraph on **active years**)
- **Current:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Proposed:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* — or *until his resignation on April 22, 1959* — is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Why:** as for the Mac entry above (`FRUSDocumentParser.swift:2003`, `:2191`).
- **Owner:** ☐ approve ☐ edit ☐ reject

## SYNC — #1531

*Lane SYNC remembers an upload that failed with none succeeding since, across launches, and says so; warns before Fix iCloud Sync would discard what never uploaded; reads this device's own system log after a failure; and gives Debug builds a store of their own. These are the manual sentences that makes wrong or incomplete. Each quotes the manual as it stands at `origin/v2` 95bfc706. The Fix iCloud Sync table rows are already proposed under WB above; the entries here are the ones WB's note left to this lane ("this row should follow whatever it ships").*

- **Manual / section:** iOS §1 Welcome: What FRUS Explorer Is (the paragraph on sync, under the principles list)
- **Current:** When it cannot, a bar along the bottom of the screen says why — **Local Only** (iCloud could not start, so new work stays on this device), **iCloud Account Issue** (not signed in, or the account is restricted), **iCloud Sync Zone Missing**, or **iCloud Sync Failed** — and its **Details** button opens Settings, where the iCloud Sync row explains it.
- **Proposed:** When it cannot, a bar along the bottom of the screen says why — **Local Only** (iCloud could not start, so new work stays on this device), **iCloud Account Issue** (not signed in, or the account is restricted), **iCloud Sync Zone Missing**, **iCloud Sync Stopped** (an upload from this device failed in an earlier session and none has succeeded since; your changes are kept on the device), or **iCloud Sync Failed** — and its **Details** button opens Settings, where the iCloud Sync row explains it, and for a stopped sync says since when. A failed or stopped upload keeps the bar up until an upload succeeds, even if a download succeeds first.
- **Why:** #1531: `ICloudStatusSummary.resolve` now resolves a remembered failure (`FRUSExplorer/App/ICloudStatusSummary.swift:103`) to `.stopped` when it began in an earlier launch and to `.failed` when it began in this one, over any later event; the banner's words are `FRUSExplorer/App/SyncStatusBanner.swift:121` and the Settings row's `FRUSExplorer/Settings/SettingsView.swift:279`. Before this, the build-48 outage showed no bar at all on most launches.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §4.4 The Status Bar (the **iCloud sync** bullet)
- **Current:** Otherwise it names the most fundamental problem, and only that one: **Local Only** (orange — iCloud could not start; hover for the diagnostic), then **Not Signed In** (orange — sign in via System Settings → Apple ID to sync), then **Zone Missing** (red — the private sync zone is absent; relaunch, or use **Settings → Data & Recovery → Fix iCloud Sync**), then **Sync Error** — click that one for detail and an **Open Sync Diagnostics** button.
- **Proposed:** Otherwise it names the most fundamental problem, and only that one: **Local Only** (orange — iCloud could not start; hover for the diagnostic), then **Not Signed In** (orange — sign in via System Settings → Apple ID to sync), then **Zone Missing** (red — the private sync zone is absent; relaunch, or use **Settings → Data & Recovery → Fix iCloud Sync**), then **Sync Stopped** (red — an upload from this Mac failed in an earlier session and none has succeeded since; your changes are kept on this Mac), then **Sync Error** — click either of the last two for detail and an **Open Sync Diagnostics** button; Sync Stopped's detail says since when uploads have stopped and, when the app could tell, which record type and field iCloud refused. Both stay until an upload succeeds; a successful download does not clear them.
- **Why:** #1531: the chip's new arm is `FRUSExplorer/App/SupportingViews.swift:688`, its popover shared with Sync Error's (`syncDetailPopover`); the precedence and the "until an upload succeeds" rule are `FRUSExplorer/App/ICloudStatusSummary.swift:103`.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery (the sentence before the recovery-ladder table), and iOS §17.6 Data & Recovery (the same sentence)
- **Current:** **Recovery** is a ladder ordered by cost, each rung stating what it deletes:
- **Proposed:** **Recovery** is a ladder ordered by cost, each rung stating what it deletes. While an upload from this device has failed with none succeeding since, **Fix iCloud Sync** would discard those changes, and the screen says so: the row reads *Would discard changes not yet in iCloud*, the confirmation opens with a warning naming when uploads stopped, and the footer no longer calls it the rung that deletes nothing. **Reset This Device** does not touch them.
- **Why:** #1531: `DataRecoveryView.fixSyncMessage`, `fixSyncRowDetail` and `recoveryFooter` (`FRUSExplorer/Settings/DataRecoveryView.swift:285`, `:298`, `:309`) read `AppState.unrecoveredExport`; `ResetService.resetLocalData` removes volumes and the index only, never the SwiftData store. WB's two proposed Fix iCloud Sync rows stand as written.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery (the **Sync Log** in Diagnostics)
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content; it stays on this Mac), …
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, error codes, and — after a failure — the names of the record types and fields iCloud refused, read from this Mac's own system log; never your content, and it stays on this Mac), …
- **Why:** #1531: after a failed event the app reads its own process's log through the existing `CD_…` allow-list (`SystemLogSchemaScan`, `FRUSExplorer/Diagnostics/CloudKitErrorInspector.swift`) and the row shows it as "└ system log: …" (`FRUSExplorer/Diagnostics/SyncDiagnosticsLog.swift:325`). In the outage the row's own error named nothing; the log named the field.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery (the **Sync Log** in Diagnostics)
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content) and the **iCloud Schema** status.
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, error codes, and — after a failure — the names of the record types and fields iCloud refused, read from this device's own system log; never your content) and the **iCloud Schema** status.
- **Why:** as for the Mac entry above (#1531, `SyncDiagnosticsLog.swift:325`); the code is shared by both platforms.
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

## LANG — #1539

*Lane LANG makes the app check its language analysis again each time it returns to the foreground (and when an answer it had stopped waiting for arrives), starts the iPhone and iPad warm-up on the first foreground rather than at launch, and adds a read-only **Language Analysis** row to Data & Recovery. These are the manual sentences that change makes wrong or incomplete. Each quotes the manual as it stands at `origin/v2` 95bfc706.*

- **Manual / section:** Mac §15.2 Word Cloud, the **Lenses** bullet
- **Current:** …the lens says it is unavailable instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed), and quitting and reopening the app may restore it.
- **Proposed:** …the lens says it is unavailable instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed). The app checks the analysis again each time you switch back to it, and the cloud redraws by itself if it has recovered; if it has not, quitting and reopening the app may restore it.
- **Why:** #1539 step B. `NaturalLanguageReadinessEngine.applicationDidBecomeActive()` (`WordCloudKit/NaturalLanguageReadiness.swift:1058`) re-checks a verdict that lacks a capability on every activation (`LanguageAnalysisLifecycle`, `FRUSExplorer/App/FRUSExplorerApp.swift:4497`), and the Word Cloud's load is keyed on the adopted verdict's revision (`FRUSExplorer/Analytics/WordCloud/WordCloudView.swift:659`). The two refusals now say so (`wordcloud.lens.unavailable.names %@ %@` and `.classes %@ %@`, `WordCloudView.swift:386`, `:390`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.2 Word Cloud, the **Lenses** bullet (its last sentence)
- **Current:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out.
- **Proposed:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out. When a later check finds the analysis working, the cloud — and a comparison column — is counted again in dictionary forms and an open Collocates panel rebuilds without your doing anything.
- **Why:** #1539. A count made as printed is no longer reused from memory once the verdict changes (`WordFrequencyService.isReusableInMemory`, `FRUSExplorer/Analytics/WordCloud/WordFrequencyService.swift:247`), the Word Cloud's load and each comparison column's load are keyed on the revision (`WordCloudView.swift:659`; `FRUSExplorer/Analytics/WordCloud/WordCloudComparisonView.swift:113`, since review round 1), and the Collocates panel's rebuild key carries it too (`CollocationRebuildKey.language`, `FRUSExplorer/Search/CollocationView.swift:377`; the Mac window's task at `FRUSExplorer/App/SearchSheet.swift:603`). The Distinctive refusal says so (`wordcloud.keyness.unavailable.languageAnalysis`, `WordCloudView.swift:1023`) and so does the Collocates one (`search.collocation.unavailable.languageAnalysis`, `CollocationView.swift:251`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.2 Word Cloud, the **Lenses** bullet
- **Current:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed), and quitting and reopening the app may restore it.
- **Proposed:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed). The app checks the analysis again each time you come back to it — from the Home Screen or another app — and the cloud redraws by itself if it has recovered; if it has not, quitting and reopening the app may restore it.
- **Why:** as for the Mac (#1539; `NaturalLanguageReadiness.swift:1058`, `FRUSExplorerApp.swift:4497`, `WordCloudView.swift:659`, `:386`, `:390`). On iPhone and iPad the app also no longer starts this check in a background launch (a CloudKit push, a background task, a finished download), which is the cause the owner's force-quit result points to (`FRUSExplorerApp.swift:510`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.2 Word Cloud, the **Lenses** bullet (its last sentence)
- **Current:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading (Section 7.6) steps aside for the same reason, and a related document's shared-word chips are left out.
- **Proposed:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading (Section 7.6) steps aside for the same reason, and a related document's shared-word chips are left out. When a later check finds the analysis working, the cloud — and a comparison column — is counted again in dictionary forms and an open Collocates panel rebuilds without your doing anything.
- **Why:** as for the Mac (#1539; `WordFrequencyService.swift:247`, `WordCloudComparisonView.swift:113`, `CollocationView.swift:377`, the iOS Search tab's task at `FRUSExplorer/Search/SearchView.swift:621`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery, the **Diagnostics** sentence
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (…), **Semantic Match Feedback** — (…) — and the **iCloud Schema** status (…).
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (…), **Semantic Match Feedback** — (…) — the **iCloud Schema** status (…), and **Language Analysis**: whether this Mac's language analysis is reducing words to their dictionary forms, telling parts of speech apart and recognizing names — *Working*, *Limited* (naming what is not working; the app checks again each time you switch back to it), or *Checking* while it finds out.
- **Why:** #1539 step A: `LanguageAnalysisRow` in the Diagnostics section (`FRUSExplorer/Settings/DataRecoveryView.swift:97`, its wording at `:725`), one view on both platforms.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery, the **Diagnostics** sentence
- **Current:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content) and the **iCloud Schema** status.
- **Proposed:** **Diagnostics** holds the redacted iCloud **Sync Log** (event types, timing, and error codes only — never your content), the **iCloud Schema** status, and **Language Analysis**: whether this device's language analysis is reducing words to their dictionary forms, telling parts of speech apart and recognizing names — *Working*, *Limited* (naming what is not working; the app checks again each time you come back to it), or *Checking* while it finds out.
- **Why:** as for the Mac (#1539; `DataRecoveryView.swift:97`, `:725`). The iOS sentence also omits **Semantic Match Feedback**, which the same section shows on iPhone and iPad; that is older than this lane and is left to lane MANUALS.
- **Owner:** ☐ approve ☐ edit ☐ reject

## GRAPH — #1434, #1517, #1518, #1481

*Lane GRAPH's proposals. Each quotes the manual as it stands at `origin/v2` 284f52c8. The iPad measurements are an iPad Pro 13-inch (M5) simulator on iOS 27.0, the iPhone ones an iPhone 17 simulator on iOS 26.5. Nothing here was checked on the Mac app by eye: review round 1 replayed the shipped constructions on the Mac in process instead (the `tools/hover-region-probe` method), so the Mac half rests on that replay. Review round 1 also measured the iPhone sheets and corrected the iOS entry below, which had told iPhone readers to start a drag on a node.*

- **Manual / section:** Mac §8.5 The Cross-Reference Graph (the **Node actions** bullet)
- **Current:** … right-click for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…*; scroll to zoom, drag the background to pan. <!-- OPEN #1517: whether a drag or double-click can start on EMPTY canvas in the document graph (and Person Analytics ▸ Network) is unverified; the canvas takes no hits there. Check by eye before keeping "drag the background to pan". -->
- **Proposed:** … right-click for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…*; scroll to zoom, drag the background to pan, and double-click it to reset the view. A click on the background closes nothing. *(The OPEN comment is deleted.)*
- **Why:** #1517: the canvas behind the nodes now takes hits on both platforms (`GraphEmptyCanvas`, `FRUSExplorer/CrossReference/CrossReferenceGraphView.swift:438`), laid between the pan offset and the drag and double-click gestures, so both can start on empty canvas; it carries no gesture of its own, so a click there clears nothing (your decision D8). Measured on the iPad, where the same view runs: a drag across empty canvas panned the graph and a double-tap reset it, where on `v2` the same drag did nothing. On the Mac, replayed in process on copies of the graph's construction (review round 1): on `v2` a drag and a double-click on empty canvas reached nothing, and with the canvas the drag pans, the double-click resets and a click reaches nothing; a right-click on a node still offers its menu. **The Mac app is not measured by eye**: please drag and double-click the empty canvas once before approving.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §8.5 The Cross-Reference Graph (the **Volume Connections** bullet)
- **Current:** Labels never overlap: the volume at the center is always named, on a plate over whatever lies beneath it, and a partner is named only where its label keeps clear of every other label and node — the panel's volume first, then the rest by references — so a crowded graph names only some partners.
- **Proposed:** Labels never overlap: the volume at the center is always named, on a plate over whatever lies beneath it, and a partner is named only where its label keeps clear of every other label and node — the panel's volume first, then the rest by references — so a crowded graph names only some partners. While the graph settles into place, after it opens, re-centers or is resized, only the volume at the center is named; the partners' names appear once it comes to rest.
- **Why:** #1434: the partner labels used to be chosen afresh on each of the layout's fifteen animation frames, so they flickered for about a quarter of a second; now `GraphNodeLabels.place(_:settling:)` places only the centre's label until the layout's last pass (`FRUSExplorer/CrossReference/VolumeConnectionGraphView.swift:735`, the flag set at `:402` and cleared at `:417`). With Reduce Motion on, or three volumes or fewer, the layout does not animate and every label appears at once.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.3 Person Analytics (the **Network** paragraph), and iOS §15.3 Person Analytics (the same paragraph)
- **Current:** … A name that would run into another name, the focus person's patch or another node goes unlabeled; hover over a partner or click it to see its name in the panel. *(iOS: … tap a partner to see its name in the panel beside or below the graph.)*
- **Proposed:** *(append, on both platforms)* While the network settles into place, after it opens, re-centers or is resized, only the focus person is named; the other names appear once it comes to rest. Drag the background to pan, and double-click (on iPhone and iPad, double-tap) it to reset the view.
- **Why:** #1434, as for Volume Connections above (`FRUSExplorer/Analytics/PersonCoMentionGraphView.swift:1170`, the flag set at `:707` and cleared at `:722`); and #1517: the network's empty canvas now takes a drag, a pinch and a double-tap (`GraphEmptyCanvas`, `PersonCoMentionGraphView.swift:1083`). Measured on the iPad: a drag across empty canvas panned the network and its **Reset View** button appeared. Measured on the iPhone, where Person Analytics is a sheet (review round 1): on `v2` a sideways or downward drag across empty canvas moved nothing; with the canvas both pan the network and a double-tap resets it. Replayed on the Mac in process, as for the document graph above. Neither manual said how to pan this graph; the Mac app is unmeasured by eye.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8.6 The Cross-Reference Graph (the **Gestures** bullet)
- **Current:** **Gestures**: tap a node to select it, pinch to zoom, two-finger drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…* (Section 14.4).
- **Proposed:** **Gestures**: tap a node to select it, pinch to zoom, drag to pan, double-tap to reset the view; long-press a node for *Recenter Graph*, *View Document*, and *Archival Neighbors…* (Section 14.4). *View Document* opens the document right there in the graph, and **Back** returns to it; a row of the reference list offers the same item when you long-press it. Where the graph is a sheet, as on iPhone, a drag on the graph pans it, so resize the sheet by its top edge.
- **Why:** #1481 (your decision D9): the long-press item read *Open in Main Window* but pushes the document inside the graph's own navigation stack, so on iOS it now reads *View Document*, the words of the node panel's own button (`CrossReferenceGraphView.openDocumentActionName`, `FRUSExplorer/CrossReference/CrossReferenceGraphView.swift:1517`); the Mac keeps *Open in Main Window*. Review round 1 gave the reference list's row menu the same name (`FRUSExplorer/CrossReference/ReferenceListPanel.swift:219`), which had still read *Open in Main Window* on iPhone and iPad. #1517: measured on the iPad, where the graph opened in its own window, a one-finger drag across empty canvas now pans and a double-tap resets. Measured on the iPhone in review round 1, the graph in its sheet at both sizes: a one-finger drag across empty canvas pans and a double-tap there resets, where on `v2` the drag panned nothing and a downward one moved the sheet from its large size to its medium one; the sheet's top edge still resizes it. Round 0's note that on the iPhone a drag had to start on a node did not reproduce. "Two-finger drag" was not measured either way, so the proposal drops it.
- **Owner:** ☐ approve ☐ edit ☐ reject
