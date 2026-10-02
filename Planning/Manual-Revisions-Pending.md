# Manual revisions pending the owner's review

Plan-of-record decision P2 (2026-09-28): while the owner reviews `Docs/macOS-User-Manual.md` (handed back after Tier 2), **no lane edits either user manual.** Each lane appends its proposed changes here under its own heading instead. That keeps the owner's diff clean and lets the owner review Claude's proposals separately. After the hand-back, lane MANUALS applies the approved ones to the owner's version, and the iOS items feed DOCS-2.

Format, one entry per change:

- **Manual / section:** Mac §x.y (or iOS §x.y)
- **Current:** the sentence as it stands
- **Proposed:** the new sentence
- **Why:** the behaviour change and its code path (path:line), with the issue number
- **Owner:** ☐ approve ☐ edit ☐ reject

<!-- Lanes append below this line, one "## <LANE KEY> — <issues>" heading each. -->

**Index, 2026-10-02** *(added by lane PLAN on 2026-10-01 and brought to the merged file when the
lane landed; no entry below was edited).* Sixteen sections, in the order the lanes landed:
**WB**, **STOR**, **PAGE**, **SYNC**, **NOTE**, **LANG**, **GRAPH**, **ARCH**, **EXPORT**,
**MACCOL**, **SEL**, **CITE**, **XREF**, **HYG**, **READ**, and **PLAN** at the end, which
holds manual sentences the 2026-09-27 planning audit found wrong rather than ones a lane's code
changed. **HYG**'s three entries propose no change; one offers an optional sentence. Each entry
is self-contained; three things are worth knowing before applying them.

- **Five pairs of lanes propose changes to the same sentences.** Lanes GRAPH and ARCH both
  rewrite Mac §8.5's **Volume Connections** bullet and the **Network** paragraph of Mac §15.3
  Person Analytics (GRAPH's entry covers iOS §15.3 too, and ARCH has an iOS §15.3 entry of its
  own). They do not conflict: GRAPH appends sentences (only the centre is named while the graph
  settles; drag and double-click on empty canvas), and ARCH changes the clause about where a label
  goes (under its node, or above it). Apply both to the same text. Lanes NOTE and EXPORT likewise
  both extend the last clause of the **coverage report** paragraph in Mac §14.8 and iOS §14.8
  (NOTE: divided lots; EXPORT: where the packet came from); they compose the same way.
  Lane READ's entries meet three earlier lanes' on the same text, and each says so itself:
  - **Mac §5.1a and iOS §5.1a, the list's lead-in** (READ, CITE). Each changes "Four things" to
    "Five things" and adds a fifth bullet of its own (CITE: citation lookup leaves a side-loaded
    volume out; READ: its figures read **[Figure]**). Applied together the list has six items,
    and the lead-in's count follows.
  - **Mac §17.2 and iOS §17.2, the first sentence** (READ, STOR). READ adds the figure images to
    the bar's segments, inside the sentence; STOR adds sentences after it.
  - **Mac §12.9 and iOS §12.10, the paragraph after the bullets** (READ, EXPORT). EXPORT adds a
    sentence about a name too long for a file name; READ adds the sentences about figures.
- **One entry is superseded.** WB's entry for the iOS graph's **Gestures** bullet is marked so in
  place; lane GRAPH's entry for that bullet (iOS §8.6) replaces it, with the item's shipped name,
  *View Document*.
- **Several sections collect entries from more than one lane, on different sentences**: Mac §17.5
  and iOS §17.6 Data & Recovery (WB, SYNC, LANG, EXPORT), Mac §11.4 and iOS §11.4 Citation Lookup
  (PAGE, CITE), Mac §8.5 (PAGE, GRAPH, ARCH), Mac §12.3 (EXPORT, MACCOL), Mac §14.8 (WB, NOTE,
  EXPORT; HYG's entry there and for iOS §14.8 proposes no change), iOS §14.2 (NOTE, SEL), iOS
  §15.4 (PAGE, XREF), iOS §5.3 Managing Storage (READ, PLAN), and Mac §15.6 and iOS §15.6 (PLAN
  only, but waiting on a code fix — see its entry). Reading a section's entries together is quicker
  than taking the lanes in order.

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
- **Why:** the owner confirmed `graph.info.interact.body.ios` ("Tap a node… Long-press to recenter the graph on that document or open it. Use pinch-to-zoom and drag to pan.") in the close-out pass. The canvas pans with a one-finger `DragGesture` (`CrossReferenceGraphView.swift:1643–1644`), and the iOS branch of *Open in Main Window* pushes onto the graph's own navigation stack (`:906–910`). If lane GRAPH relabels the item (D9), use its new name instead of the parenthesis.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §2.2 Onboarding, Step 2 — Scope (the scope table, **Corpus** row, `Docs/iOS-User-Manual.md:78`)
- **Current:** | **Corpus** | All 553 volumes in the bundled catalog (about 3.3 GB; downloading takes a while depending on your connection and free storage) |
- **Proposed:** | **Corpus** | All 553 volumes in the bundled catalog (about 3.5 GB with their match files; downloading takes a while depending on your connection and free storage) |
- **Why:** the owner's close-out pass (C1) changed the onboarding caption to "≈ 3.5 GB" (`FRUSExplorer/Onboarding/OnboardingView.swift:609`): 3,338,778,538 bytes of volume XML plus 162,354,028 bytes of match files, which Download With Volumes (on by default) fetches with each volume. The Mac manual's "about **3.3 GB** of XML" (`Docs/macOS-User-Manual.md:74`) is accurate as written, since it names the XML; it could add "plus about 160 MB of match files". The subseries caption now reads "recommended if you want to start smaller" if either manual quotes it.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.7 Chronology (`Docs/iOS-User-Manual.md:1201`) and Mac §15.7 Chronology (`Docs/macOS-User-Manual.md:1083`), the **distribution chart** bullet in each
- **Current:** iOS: "…Two companion sections keep it honest: **Spans this period** collects wide-span documents (mostly editorial notes) rather than smearing them across the chart, and **Extends beyond this range**…". Mac: the same sentence with "(chiefly editorial notes)".
- **Proposed:** In both, replace "**Spans this period** collects wide-span documents" with "**Spans more than a year** collects documents whose dates span more than a year", keeping each manual's parenthesis: iOS "…**Spans more than a year** collects documents whose dates span more than a year (mostly editorial notes) rather than smearing them across the chart, and **Extends beyond this range**…"; Mac the same with "(chiefly editorial notes)".
- **Why:** #1422, the owner's option (a) plus the header. The section header is now "Spans more than a year" (`ChronologyViewModel.spanningSectionHeader`, `FRUSExplorer/Chronology/ChronologyViewModel.swift:615`, key `chronology.spanning.header`) and its chip reads "N documents span more than a year" (`spanningChipTitle`, `:592`). A row is listed because its dates overlap the range (`IndexingPipeline.documentsInDateRange`), so it need not span the whole period, and it is sorted there when its dates lie more than 366 days apart (`ChronologyViewModel.partition`, `maxSpanDaysForPlacement`). Both manuals' parentheses stay true: 36 of 7,137 such rows in a 553-volume index are not editorial notes.
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
- **Why:** #1476, the owner's 2026-09-30 wording. Both hubs draw `DownloadedVolumesListModel.heroContent(catalogCount:interruptedCount:)` (`FRUSExplorer/Settings/StorageHubModel.swift`, the hero at `FRUSExplorer/Settings/MacVolumesStorageHub.swift:273`), and the Mac now measures through `DownloadedVolumesListModel.measure(_:)`, which keeps the error instead of `try?` and the last report on a failure; the failure row is new on the Mac (`MacVolumesStorageHub.swift:292`). The clause is `settings.hub.summary.removing.one` / `settings.hub.summary.removing %lld` (`FRUSExplorer/Settings/SettingsComponents.swift:143`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.2 Volumes & Storage
- **Current:** Opens with a **Storage used** bar split into XML and index, and a status line.
- **Proposed:** Opens with a **Storage used** bar split into XML and index, and a status line. Until the pane has measured the library the size reads "—" and the status line *Measuring…*; if measuring fails, *Could not measure storage*, with the reason in a row beneath. While volumes are being removed the status line counts them separately — *1 being removed* — rather than as downloaded.
- **Why:** #1476, as for the Mac (`DownloadedVolumesListModel.heroContent`, `FRUSExplorer/Settings/StorageHubModel.swift`; the iOS hero at `FRUSExplorer/Settings/VolumesStorageHubView.swift:254`). The sentence "split into XML and index" is also short of the four segments the bar draws, which is not this lane's change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.2 Volumes & Storage (the **Storage & Index** item)
- **Current:** **Free Up Space…**, which lists only volumes with nothing of yours attached, ordered by what you'd recover, and asks first;
- **Proposed:** **Free Up Space…**, which lists only volumes with nothing of yours attached, ordered by what you'd recover, and asks first — while it removes, its rows are dimmed and cannot be ticked or unticked;
- **Why:** #1432: the rows used to stay tappable mid-removal, toggling a checkmark and the recovery estimate that changed nothing being removed. `FreeUpSpaceSheet.candidateRow` now carries `.disabled(isRemoving)` (`FRUSExplorer/Settings/VolumesStorageHubView.swift:1889`); the Mac's sheet already blocked its rows, by covering them with an overlay while it removes (`MacVolumesStorageHub.swift:1949`). Optional: the manual says nothing about the removal's progress at all.
- **Owner:** ☐ approve ☐ edit ☐ reject

## PAGE — #1509, #1510, #1511

*Lane PAGE (index v63). Each entry quotes the manual as it stands at `origin/v2` 95bfc706. Review round 1 corrected the scope of the first two (the footnote decides whenever the page names several documents, not only when several begin on it) and added the three after them (iOS §15.4, Mac §11.4, iOS §11.4); review round 2 widened the two §11.4 proposals to the breaks a chapter with text of its own gives up.*

- **Manual / section:** Mac §8.5 The Cross-Reference Graph (the last bullet, and the `OPEN #1509` comment under it)
- **Current:** Page-number references ("see p. 427") resolve to the document that begins on the cited page — when several begin on it, the first of them, and when none does, the document printed on it — and references confirmed unresolvable (8.2) are excluded — every edge you see leads to a real document.
- **Proposed:** Page-number references ("see p. 427") resolve to the document that begins on the cited page, or, when none does, the document printed on it — and when the page names several, to the one the footnote names by its document number (*Doc. No. 497*) or its date (*telegram of July 7*), or the first of them when it names neither — and references confirmed unresolvable (8.2) are excluded — every edge you see leads to a real document. Clicking the page link in the document opens the same document the graph draws. *(Delete the `OPEN #1509` comment.)*
- **Why:** #1509: the stored edge and the reader's page link now both go through `PageSpanResolver.citedDocument(among:facts:citing:)` (`FRUSExplorer/Citation/PageSpanResolver.swift:310`), called by `IndexingPipeline.resolvePageBasedCrossReferences` (`FRUSExplorer/Search/IndexingPipeline.swift:8643`) and by the Mac reader's `resolvePageReference` through `PageRangeStore.document(forPage:inVolume:citing:)` (`FRUSExplorer/App/MacDocumentView.swift:1228`). The footnote's numbers and dates come from `PageCitationHint(citingText:)` (`PageSpanResolver.swift:429`). It runs whenever the page names several, whatever the claim: of the 2,218 edges it moves, 2,216 cite a page several documents begin on and 2 a page none begins on and several are printed on (`tools/page-citations/v63.py`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8.6 The Cross-Reference Graph (the bullet beginning "Nodes in undownloaded volumes")
- **Current:** References confirmed unresolvable (Section 8.2) are excluded rather than drawn as dead ends, and page-number references ("see p. 427") resolve to their true target documents.
- **Proposed:** References confirmed unresolvable (Section 8.2) are excluded rather than drawn as dead ends, and page-number references ("see p. 427") resolve to the document that begins on the cited page, or, when none does, the one printed on it — of several, the one the footnote names by its document number or its date, otherwise the first — which is also the document tapping the link opens.
- **Why:** #1509, as above; the iPhone and iPad reader's page link is `DocumentView.resolvePageReference` (`FRUSExplorer/DocumentView/DocumentView.swift:1369`). "Their true target documents" claimed more than either the old rule (the first) or the new one (the footnote's choice, else the first) can know.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.4 Cross-Reference Analytics (the paragraph beginning "A **Scope** bar")
- **Current:** The document-level figures include same-volume citations; page-number references resolve to their true targets; references confirmed unresolvable are excluded, and a caption discloses how many.
- **Proposed:** The document-level figures include same-volume citations; a page-number reference counts toward the document that begins on the cited page, or, when none does, the one printed on it — of several, the one its footnote names by document number or date, otherwise the first; references confirmed unresolvable are excluded, and a caption discloses how many.
- **Why:** #1509 review round 1: the same overclaim as iOS §8.6 above. Cross-Reference Analytics reads the stored `cross_references` edges through `CrossReferenceStore` (`FRUSExplorer/CrossReference/CrossReferenceStore.swift:604`), which `IndexingPipeline.resolvePageBasedCrossReferences` writes by `PageSpanResolver.citedDocument` (`FRUSExplorer/Search/IndexingPipeline.swift:8643`). The Mac's §15.4 says only that "page-number references count alongside document-number ones", which stays true, so it needs no change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.4 Citation Lookup (the labels table, the last sentence of the **Possible match — one of *N* documents that begin on page *P*** row)
- **Current:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — is never the answer to a page it begins on
- **Proposed:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — never answers a page just by beginning on it: a page finds it only where the section is printed, by a page break inside it or by the break printed just before it, when the chapter or compilation around it has nothing of its own on that page but a heading. That is how page 57 of the *Paris Peace Conference* Volume XIII finds the Preamble, which begins there, and page 135 Section I of Part III, which begins there after Part III's own notes end on page 134
- **Why:** #1510 (owner decision D1, review rounds 1 and 2): a section still records no start, but `TEIParserDelegate.finishParse` (`FRUSExplorer/TEI/FRUSDocumentParser.swift:1171`) gives the section that begins after them the breaks a container leaves — every break of a compilation, chapter or subchapter holding nothing but its heading, which is not indexed, and the breaks one with text of its own prints after that text, before or between the sections it holds (`FRUSDocumentAST.carriedPages`) — and the index stores them as that section's `page_ranges` rows (`FRUSExplorer/Search/IndexingPipeline.swift:4958`), which `PageSpanResolver.documents(onPage:in:)` reads as pages the section is printed on. 41 such breaks reach 37 sections, 19 of them given up by the 15 chapters with text of their own, all in `frus1919Parisv13` (`tools/page-citations/v63.py`), so those sections can answer pages they begin on: in `frus1919Parisv13`, p. 57 is ch9, the Preamble, from the heading-only comp3, and p. 135 is ch12subch1, Section I of Part III, from ch12, whose own notes end on p. 134 (`RealTEIPageCitationsV63Tests.parisv13Containers`; `ContainerTests.proseContainerIsNarrowedToItsOwnText` on a fixture). Citation Lookup reports either as a page match through `matchByPageRange` (`FRUSExplorer/Citation/CitationMatchingEngine.swift:1010`). Before #1510 p. 57 answered comp3 alone, and p. 135 ch12 and comp3 together (measured with the container rule off). A container's heading may share the page, which is why the clause allows one: ch10, Part I, left out too, prints only its heading on p. 69, and p. 69 is its first section, ch10subch1. Review round 2 widened the clause, which as first proposed named only the container holding nothing but its heading and so was false for the 19 breaks the chapters with text give up.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §11.4 Citation Lookup, in Both Directions (the paragraph beginning "A citation that names a page but no document")
- **Current:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — is never the answer to a page it begins on.
- **Proposed:** A section that is not a document — a chapter reading only *[Printed under Russia, p. 807.]*, a list of errata — never answers a page just by beginning on it: a page finds it only where the section is printed, by a page break inside it or by the break printed just before it, when the chapter or compilation around it has nothing of its own on that page but a heading. That is how page 57 of the *Paris Peace Conference* Volume XIII finds the Preamble, which begins there, and page 135 Section I of Part III, which begins there after Part III's own notes end on page 134.
- **Why:** as for the Mac entry above.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §6.3 The People Browser (the paragraph on **active years**)
- **Current:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Proposed:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* — or *until his resignation on April 22, 1959* — is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Why:** the persons-list fold-in of lane PAGE (#1370's left-open item): a year after "until" or "till" and another event before its date ("until his resignation on", "until country renamed in", "until overthrown on") is now an end, not a start — `endEventCueRegex` and its use in `PersonsParserDelegate.yearSpan(in:)` (`FRUSExplorer/TEI/FRUSDocumentParser.swift:2078`, `:2266`). Until v63 Dulles's List of Persons entry in `frus1958-60v03` read **1959** as the year he began.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §6.5 The People Browser (the paragraph on **active years**)
- **Current:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Proposed:** … the years in their Lists of Persons, read by the words around them (*until January 3, 1979* — or *until his resignation on April 22, 1959* — is when someone left, *from June 13, 1982* when they began, and a post held *until his death on November 22, 1963* ends that year), …
- **Why:** as for the Mac entry above (`FRUSDocumentParser.swift:2078`, `:2266`).
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
- **Why:** #1514 and #1515 removed the three examples the sentence gives: a Subject-Numeric file with no number is stored (`POL ARAB–ISR`, `ParsedSourceNote.isDigitlessSubjectNumeric`, `SourceNoteKit/SourceNoteParser.swift:273`); the eight notes given only as a volume number are INR/IL series whose folder is now named with its volume (`Carlson –Department Messages, Vol. 4, 1965–69`); and the notes given only as a web address are the FOIA reading room, now a publication, which seeds no file. The caveat itself stays (review round 1), with two examples that are still true: `TripPacketBuilder.fileDesignation` gives no designation for any note the parser reads as a National Archives collection (`FRUSExplorer/TripPacket/TripPacketBuilder.swift:405`) — 5,951 notes in the corpus cite `RG 59, Central Files` that way, frus1964-68v06/d131 among them — and the number-less designator rule reads only a category in capitals, an optional agency, a space and a country element in capitals, so 126 central-file notes in 11 volumes still store none (review round 2, which corrects round 1's "31 … in 7 volumes"): 30 whose country is not printed in capitals (`POL Laos`, `POL Pol–US`, 24 of them in frus1961-63v16), 54 commodity files joined to their category by a dash (`INCO–GRAINS GATT` ×15), 21 with an agency and no country (`DEF(MLF)` ×16) and 21 with a title-case category (`Pol Port-US` ×4, all frus1961-63v13). 55 more cite an `AID` file with no number (`AID (US) S VIET`), a category the rule does not know. The lane's DEVELOPMENT-PLAN entry lists them under *Still open*.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 — the **coverage report** paragraph (`Docs/macOS-User-Manual.md:943`)
- **Current:** "… the digitized-substitute denominators, and how much of the restriction picture is actually measured."
- **Proposed:** "… the digitized-substitute denominators, and how much of the restriction picture is actually measured — a divided lot's claimant series included, so a plan is never called unrestricted while one of them is restricted or has no recorded status."
- **Why:** the audit's divided-lot fold-in: the access block now opens on divided lots as well as on the triage, and its all-clear sentence waits for them (`FRUSExplorer/TripPacket/TripPacketExporter.swift:692`).
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
- **Why:** #1539 step B. `NaturalLanguageReadinessEngine.applicationDidBecomeActive()` (`WordCloudKit/NaturalLanguageReadiness.swift:1058`) re-checks a verdict that lacks a capability on every activation (`LanguageAnalysisLifecycle`, `FRUSExplorer/App/FRUSExplorerApp.swift:4549`), and the Word Cloud's load is keyed on the adopted verdict's revision (`FRUSExplorer/Analytics/WordCloud/WordCloudView.swift:659`). The two refusals now say so (`wordcloud.lens.unavailable.names %@ %@` and `.classes %@ %@`, `WordCloudView.swift:386`, `:390`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.2 Word Cloud, the **Lenses** bullet (its last sentence)
- **Current:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out.
- **Proposed:** …so Distinctive is withheld for the whole cloud rather than word by word; the Collocates reading steps aside for the same reason, and a related document's shared-word chips are left out. When a later check finds the analysis working, the cloud — and a comparison column — is counted again in dictionary forms and an open Collocates panel rebuilds without your doing anything.
- **Why:** #1539. A count made as printed is no longer reused from memory once the verdict changes (`WordFrequencyService.isReusableInMemory`, `FRUSExplorer/Analytics/WordCloud/WordFrequencyService.swift:247`), the Word Cloud's load and each comparison column's load are keyed on the revision (`WordCloudView.swift:659`; `FRUSExplorer/Analytics/WordCloud/WordCloudComparisonView.swift:113`, since review round 1), and the Collocates panel's rebuild key carries it too (`CollocationRebuildKey.language`, `FRUSExplorer/Search/CollocationView.swift:377`; the Mac window's task at `FRUSExplorer/App/SearchSheet.swift:603`). The Distinctive refusal says so (`wordcloud.keyness.unavailable.languageAnalysis`, `WordCloudView.swift:1023`) and so does the Collocates one (`search.collocation.unavailable.languageAnalysis`, `CollocationView.swift:251`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.2 Word Cloud, the **Lenses** bullet
- **Current:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed), and quitting and reopening the app may restore it.
- **Proposed:** …the lens says it is unavailable on this device instead of drawing an empty cloud and names the lenses that still work (which depends on which part of the analysis failed). The app checks the analysis again each time you come back to it — from the Home Screen or another app — and the cloud redraws by itself if it has recovered; if it has not, quitting and reopening the app may restore it.
- **Why:** as for the Mac (#1539; `NaturalLanguageReadiness.swift:1058`, `FRUSExplorerApp.swift:4549`, `WordCloudView.swift:659`, `:386`, `:390`). On iPhone and iPad the app also no longer starts this check in a background launch (a CloudKit push, a background task, a finished download), which is the cause the owner's force-quit result points to (`FRUSExplorerApp.swift:516`).
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
- **Why:** #1434: the partner labels used to be chosen afresh on each of the layout's fifteen animation frames, so they flickered for about a quarter of a second; now `GraphNodeLabels.place(_:avoiding:settling:)` places only the centre's label until the layout's last pass (`FRUSExplorer/CrossReference/VolumeConnectionGraphView.swift:736`, the flag set at `:403` and cleared at `:418`). With Reduce Motion on, or three volumes or fewer, the layout does not animate and every label appears at once.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.3 Person Analytics (the **Network** paragraph), and iOS §15.3 Person Analytics (the same paragraph)
- **Current:** … A name that would run into another name, the focus person's patch or another node goes unlabeled; hover over a partner or click it to see its name in the panel. *(iOS: … tap a partner to see its name in the panel beside or below the graph.)*
- **Proposed:** *(append, on both platforms)* While the network settles into place, after it opens, re-centers or is resized, only the focus person is named; the other names appear once it comes to rest. Drag the background to pan, and double-click (on iPhone and iPad, double-tap) it to reset the view.
- **Why:** #1434, as for Volume Connections above (`FRUSExplorer/Analytics/PersonCoMentionGraphView.swift:1216`, the flag set at `:753` and cleared at `:768`); and #1517: the network's empty canvas now takes a drag, a pinch and a double-tap (`GraphEmptyCanvas`, `PersonCoMentionGraphView.swift:1129`). Measured on the iPad: a drag across empty canvas panned the network and its **Reset View** button appeared. Measured on the iPhone, where Person Analytics is a sheet (review round 1): on `v2` a sideways or downward drag across empty canvas moved nothing; with the canvas both pan the network and a double-tap resets it. Replayed on the Mac in process, as for the document graph above. Neither manual said how to pan this graph; the Mac app is unmeasured by eye.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8.6 The Cross-Reference Graph (the **Gestures** bullet)
- **Current:** **Gestures**: tap a node to select it, pinch to zoom, two-finger drag to pan; long-press a node for *Recenter Graph*, *Open in Main Window*, and *Archival Neighbors…* (Section 14.4).
- **Proposed:** **Gestures**: tap a node to select it, pinch to zoom, drag to pan, double-tap to reset the view; long-press a node for *Recenter Graph*, *View Document*, and *Archival Neighbors…* (Section 14.4). *View Document* opens the document right there in the graph, and **Back** returns to it; a row of the reference list offers the same item when you long-press it. Where the graph is a sheet, as on iPhone, a drag on the graph pans it, so resize the sheet by its top edge.
- **Why:** #1481 (your decision D9): the long-press item read *Open in Main Window* but pushes the document inside the graph's own navigation stack, so on iOS it now reads *View Document*, the words of the node panel's own button (`CrossReferenceGraphView.openDocumentActionName`, `FRUSExplorer/CrossReference/CrossReferenceGraphView.swift:1517`); the Mac keeps *Open in Main Window*. Review round 1 gave the reference list's row menu the same name (`FRUSExplorer/CrossReference/ReferenceListPanel.swift:219`), which had still read *Open in Main Window* on iPhone and iPad. #1517: measured on the iPad, where the graph opened in its own window, a one-finger drag across empty canvas now pans and a double-tap resets. Measured on the iPhone in review round 1, the graph in its sheet at both sizes: a one-finger drag across empty canvas pans and a double-tap there resets, where on `v2` the drag panned nothing and a downward one moved the sheet from its large size to its medium one; the sheet's top edge still resizes it. Round 0's note that on the iPhone a drag had to start on a node did not reproduce. "Two-finger drag" was not measured either way, so the proposal drops it.
- **Owner:** ☐ approve ☐ edit ☐ reject

## ARCH — #1437, #1438, #1468, #1470

*Lane ARCH keeps a node from reading like the focus or like another node, keeps a trailing lot or file number in a cut label, moves each custodian caption to the corner of its quadrant clear of every node, keeps every label off the captions and the Central Files outline, gives every graph's labels a second place above their node, names a long front-matter collection by its printed title, and keeps the selected node's panel buttons in view. These are the manual sentences the change makes wrong or incomplete. Each quotes the manual as it stands at `origin/v2` f5625ca2.*

- **Manual / section:** Mac §15.5 Archival Analytics, the **Network** paragraph (labels)
- **Current:** The other names are drawn under their nodes where they fit clear of every other name and node — the node you clicked first, then the strongest — so a crowded quadrant shows only some of them. A long name is cut at 26 characters, and an ellipsis marks the cut. Where two partner collections share a name, the repository is added to tell them apart, and the name and the repository are each cut on their own, so the ellipsis can come before the repository ("White House Ce… · Ford Library"). A partner is never compared with the focus, so one that shares the focus's name gets no repository, and two long names that differ only after the cut (often in a lot number) read alike: a node can look like the focus or like another node. Click it to read its full name. <!-- OPEN #1437 … -->
- **Proposed:** The other names are drawn under their nodes, or above them when the place under is taken, where they fit clear of every other name and node, the custodian names and the Central Files outline — the node you clicked first, then the strongest — so a crowded quadrant shows only some of them. A long name is cut at 26 characters, and an ellipsis marks the cut; a lot or file number at the end of a name is kept whole ("Conference F… Lot 64 D 559"). Where two collections share a name — two partners, or a partner and the focus — the repository is added to tell them apart ("Whitman File · Eisenhower Library" at the center beside a "Whitman File" that names none), and the name and the repository are each cut on their own, so the ellipsis can come before the repository ("White House Ce… · Ford Library"). Where a cut would still make a partner read like the focus or another partner, it shows the end of its name instead ("National Securi… (H-Files)"). Click a node to read its full name. *(Delete the `OPEN #1437` comment.)*
- **Why:** #1437: the focus's name is compared and qualified (`ArchivalNetworkBuilder.disambiguate(_:in:focus:)` and `focusLabel(_:nodes:)`, `FRUSExplorer/Analytics/ArchivalNetworkData.swift:522`, `:560`), a cut keeps a trailing identifier (`identifierKeepingCut(_:limit:)`, `:979`), and a node still drawn alike is re-cut to its end (`drawnLabels(in:)`, `:1039`). #1438: the place above and the obstacles (`GraphNodeLabels.place(_:avoiding:settling:)`, `FRUSExplorer/Analytics/PersonCoMentionGraphView.swift:235`; `labelObstacles(_:)`, `ArchivalNetworkData.swift:735`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.5 Archival Analytics, the **Network** paragraph (last sentence)
- **Current:** Click a wedge to isolate a custodian; click a node for what the link is made of, its full name included; scroll to zoom, drag to pan, double-click to reset.
- **Proposed:** Each custodian's name sits in the corner of its quadrant, clear of the nodes. Click a wedge, or its name, to isolate a custodian; click a node for what the link is made of — the panel shows its name in up to three lines, with **Explore This Collection**, **Show Archival Neighbors** and **Open Collection** right under it, and the whole name in the name's tooltip; scroll to zoom, drag to pan, double-click to reset.
- **Why:** #1470: the captions are reserved outside the node band (`ArchivalNetworkBuilder.reserveCaptions(in:graph:size:captionSize:)`, `ArchivalNetworkData.swift:764`), drawn there (`drawSectorLabel`, `FRUSExplorer/Analytics/ArchivalNetworkView.swift:429`), and part of the wedge's tap target (`sectorZones`, `:615`). #1468: `ArchivalNetworkNodeCard` (`ArchivalNetworkView.swift:1202`) holds the heading to three lines, wraps the actions under it — the heading giving up lines where they need more rows (`ArchivalNetworkCardLead`, `:1256`) — and puts the whole name in `.help`.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.3 Person Analytics, the **Network** paragraph
- **Current:** A name that would run into another name, the focus person's patch or another node goes unlabeled; hover over a partner or click it to see its name in the panel.
- **Proposed:** A name that would run into another name, the focus person's patch or another node under its node is drawn above the node instead, and goes unlabeled only when it does not fit there either; hover over a partner or click it to see its name in the panel.
- **Why:** #1438, owner decision D10: the place above is the shared rule of all three graphs (`GraphNodeLabels.place(_:avoiding:settling:)` and `labelRectAbove(for:)`, `PersonCoMentionGraphView.swift:235`, `:166`). On the person graph's test layouts it keeps 21 labels where one place kept 18 (700 × 520) and 19 where it kept 17 (360 × 420).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §8.5 The Cross-Reference Graph, the **Volume Connections** bullet
- **Current:** …and a partner is named only where its label keeps clear of every other label and node — the panel's volume first, then the rest by references — so a crowded graph names only some partners.
- **Proposed:** …and a partner is named under its volume, or above it when the place under is taken, only where its label keeps clear of every other label and node — the panel's volume first, then the rest by references — so a crowded graph names only some partners.
- **Why:** #1438, as for Person Analytics (`PersonCoMentionGraphView.swift:235`). On the volume graph's test layouts it keeps 31 labels where one place kept 18 (700 × 520) and 19 where it kept 11 (360 × 420).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.5 Archival Collections Across the Series, first paragraph
- **Current:** …each with its canonical name, the variant forms volumes actually print, its NARA catalog record where one resolved offline, its sub-series, and every citing volume.
- **Proposed:** …each with its canonical name, the variant forms volumes actually print, its NARA catalog record where one resolved offline, its sub-series, and every citing volume. Where a volume prints a collection's title and a paragraph about it as one entry, the title is the name and the paragraph one of its variant forms (*Indexed Central Files*).
- **Why:** #1468, owner decision D11: a front-matter item over 100 characters that opens with a printed `<hi>` title is named by the title (`ReferenceBuilder.printedTitle(of:)`, `CollectionAuthorityGeneratorCore/ReferenceBuilder.swift:268`), and the name it replaces is kept as an alias the 12-alias cap never drops (`AuthorityBuilder.cappedAliases(_:excludingName:exempt:)`, `CollectionAuthorityGeneratorCore/AuthorityBuilder.swift:252`). Ten names change in `collection-authority.json`; Indexed Central Files was 2,150 characters.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.5 Archival Analytics, the **Network** paragraph
- **Current:** The other names are drawn under their nodes where they fit clear of every other name and node — the node you tapped first, then the strongest — so a crowded quadrant shows only some of them. A long name is cut, and an ellipsis marks the cut. Where two collections share a name, the repository is added to tell them apart, and the name and the repository are each cut on their own, so the ellipsis can come before the repository ("White House Ce… · Ford Library"). Tap a wedge to isolate a custodian; tap a node for what the link is made of, its full name included; pinch to zoom, drag to pan, double-tap to reset.
- **Proposed:** The other names are drawn under their nodes, or above them when the place under is taken, where they fit clear of every other name and node, the custodian names and the Central Files outline — the node you tapped first, then the strongest — so a crowded quadrant shows only some of them. A long name is cut, and an ellipsis marks the cut; a lot or file number at the end of a name is kept whole ("Conference F… Lot 64 D 559"). Where two collections share a name — two partners, or a partner and the focus — the repository is added to tell them apart, and the name and the repository are each cut on their own, so the ellipsis can come before the repository ("White House Ce… · Ford Library"); where a cut would still make a partner read like the focus or another partner, it shows the end of its name instead. Each custodian's name sits in the corner of its quadrant, clear of the nodes. Tap a wedge, or its name, to isolate a custodian; tap a node for what the link is made of — the panel shows as much of its name as leaves its actions in view (one line on most iPhones, where the actions take a row each, two on the largest, and up to three on an iPad; one with the iPhone turned sideways), with the actions right under it; pinch to zoom, drag to pan, double-tap to reset.
- **Why:** as for the Mac (#1437, #1438, #1470, #1468; `ArchivalNetworkData.swift:522`, `:560`, `:764`, `:979`, `:1039`; `ArchivalNetworkView.swift:429`, `:615`, `:1202`; `PersonCoMentionGraphView.swift:235`). The heading's one line at compact height is `ArchivalNetworkNodeCard`'s `isCompact`, which the view sets from a compact vertical size class; in portrait the three actions are 204, 217 and 156 pt wide, a row each in a 402 or 375 pt dock and two rows in a 440 pt one, and the heading takes the lines they leave (`ArchivalNetworkCardLead`, `ArchivalNetworkView.swift:1256`; measured by `ArchivalNetworkNodeCardTests`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.3 Person Analytics, the **Network** paragraph
- **Current:** A name that would run into another name, the focus person's patch or another node goes unlabeled; tap a partner to see its name in the panel beside or below the graph.
- **Proposed:** A name that would run into another name, the focus person's patch or another node under its node is drawn above the node instead, and goes unlabeled only when it does not fit there either; tap a partner to see its name in the panel beside or below the graph.
- **Why:** as for the Mac (#1438, D10; `PersonCoMentionGraphView.swift:235`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.6 Archival Collections Across the Series, first paragraph
- **Current:** …each with its canonical name, the variant forms volumes actually print, its NARA catalog record where one resolved offline, and every citing volume.
- **Proposed:** …each with its canonical name, the variant forms volumes actually print, its NARA catalog record where one resolved offline, and every citing volume. Where a volume prints a collection's title and a paragraph about it as one entry, the title is the name and the paragraph one of its variant forms (*Indexed Central Files*).
- **Why:** as for the Mac (#1468; `ReferenceBuilder.swift:268`, `AuthorityBuilder.swift:252`). The same paragraph's "~4,400 archival collections" predates #1469 and #1514 (the artifact holds 4,051; the Mac manual says ~4,100), which lane MANUALS or DOCS-2 can take with it.
- **Owner:** ☐ approve ☐ edit ☐ reject

## EXPORT — #1465, #1496, #1497, #1498, #1464

*Lane EXPORT (2026-10-01) changes what an untitled Section heading does, how a collection is named in Zotero and in a file name, when an imported collection's notes become searchable, and what every analytics export, the method appendix and the Archives Visit packet say they were drawn from. Each entry quotes the manual as it stands at `origin/v2` f5625ca2. #1496 (a note inside a note in a Word export) and #1464 (list rows trimming the name) change nothing either manual says.*

- **Manual / section:** Mac §12.3 Composing: Headings, Prose, Excerpts, and Apparatus (the **Section headings** bullet)
- **Current:** … dragging a heading moves its **entire section as one block**. Exports mirror the nesting with stepped heading sizes and an indented table of contents.
- **Proposed:** … dragging a heading moves its **entire section as one block**. Exports mirror the nesting with stepped heading sizes and an indented table of contents. A heading you leave without text shows in the live preview as *Untitled section*, in grey italics, and is left out of every PDF, HTML and Word export, whether or not documents sit under it; a heading nested under it moves up a level, and its documents keep the section defaults it sets.
- **Why:** #1465, decision D4: an export resolves with `dropsUntitledHeadings` (`FRUSExplorer/Collections/CollectionContentResolver.swift:514`), whose levels come from `CollectionOutline.exportLevels` (`FRUSExplorer/Collections/CollectionOutline.swift:155`) while the section cascades still run over the whole outline; the preview prints the heading through `headingText` (`FRUSExplorer/Collections/CollectionItemHTMLRenderer.swift:262`). Before, every format printed an empty heading, and the preview's Contents a row of "1." and nothing.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.3 Section Headings and Prose (the **Section headings** bullet)
- **Current:** … dragging a heading moves its **entire section as one block**. Exports mirror the nesting with stepped heading sizes and an indented table of contents.
- **Proposed:** … dragging a heading moves its **entire section as one block**. Exports mirror the nesting with stepped heading sizes and an indented table of contents. A heading you leave without text shows in the live preview as *Untitled section*, in grey italics, and is left out of every PDF, HTML and Word export, whether or not documents sit under it; a heading nested under it moves up a level, and its documents keep the section defaults it sets.
- **Why:** as for the Mac (#1465; the same resolver and renderer serve both platforms).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.9 Export (the **Send to Zotero Library** bullet)
- **Current:** **Send to Zotero Library**, below the grid, pushes the whole collection into your connected library over the Web API, with tags and research notes; with no account it falls back to an RIS file for desktop import.
- **Proposed:** **Send to Zotero Library**, below the grid, pushes the whole collection into your connected library over the Web API — into a new Zotero collection named after it, or, for a collection with no name, *FRUS Explorer Collection -* and the day you send it (*FRUS Explorer Collection - 2026-10-01*) — with tags and research notes; with no account it falls back to an RIS file for desktop import.
- **Why:** #1497, decision D16: the send names its Zotero collection through `CollectionExportNaming.zoteroCollectionName` (`FRUSExplorer/Collections/CollectionExportSheet.swift:752`, `FRUSExplorer/Collections/CollectionExporter.swift:1549`), trimmed; an unnamed collection's items used to land loose in the library, in no Zotero collection.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.10 Export (the **Send to Zotero Library** bullet)
- **Current:** **Send to Zotero Library**, below the grid, pushes the whole collection into your connected Zotero library over the Web API, with tags and research notes; with no account connected it falls back to an RIS file for desktop import.
- **Proposed:** **Send to Zotero Library**, below the grid, pushes the whole collection into your connected Zotero library over the Web API — into a new Zotero collection named after it, or, for a collection with no name, *FRUS Explorer Collection -* and the day you send it — with tags and research notes; with no account connected it falls back to an RIS file for desktop import.
- **Why:** as for the Mac (#1497; one export sheet serves both).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.9 Export (the paragraph after the bullets)
- **Current:** Exports always include the collection title and a linked table of contents, and each file is named after the collection. A collection with no name exports as **Untitled Collection** — the file's name, and the title of a PDF, HTML or Word export.
- **Proposed:** Exports always include the collection title and a linked table of contents, and each file is named after the collection. A collection with no name exports as **Untitled Collection** — the file's name, and the title of a PDF, HTML or Word export. A name too long for a file name is shortened, at a whole character, in the file's name only; the export's title keeps it whole.
- **Why:** #1498: `CollectionExportNaming.fileName` cuts the stem through `ExportFileName.fitting` (`FRUSExplorer/Collections/CollectionExporter.swift:1525`, `:1621`) so name and suffix fit within 240 UTF-8 bytes of the name's decomposed form, which bounds the UTF-16 units of that form the file system counts; uncut, a name past the file system's 255 units failed every format's write with "Could not write export file".
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.10 Export (the paragraph after the bullets)
- **Current:** Each file is named after the collection; a collection with no name exports as **Untitled Collection** — the file's name, and the title of a PDF, HTML or Word export.
- **Proposed:** Each file is named after the collection; a collection with no name exports as **Untitled Collection** — the file's name, and the title of a PDF, HTML or Word export. A name too long for a file name is shortened, at a whole character, in the file's name only.
- **Why:** as for the Mac (#1498).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.9 Export (the **Importing** bullet)
- **Current:** **Importing.** **Import Collection…** in the window, or just **double-click a `.fruscollection` file** (or receive one by AirDrop) — the window opens with the import selected. Double-clicking a byte-identical file again during the same app session re-opens the collection it created; after a relaunch, opening the file imports a fresh copy.
- **Proposed:** **Importing.** **Import Collection…** in the window, or just **double-click a `.fruscollection` file** (or receive one by AirDrop) — the window opens with the import selected. Research notes the file carries become notes of yours on those documents, searchable straight away. Double-clicking a byte-identical file again during the same app session re-opens the collection it created; after a relaunch, opening the file imports a fresh copy.
- **Why:** the 2026-09-28 audit (from #1280's log): all three import paths now index the notes an import brings (`NativeCollectionSerializer.indexImportedNotes`, `FRUSExplorer/Collections/NativeCollectionFormat.swift:776`, called by Import Collection… at `FRUSExplorer/Collections/MacCollectionManagerView.swift:409` and `FRUSExplorer/Collections/CollectionListView.swift:254`, and for a double-clicked or AirDropped file at `FRUSExplorer/App/FRUSExplorerApp.swift:2086`); before, they became searchable only at the next launch.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.10 Export (the **Importing** bullet)
- **Current:** **Importing.** **Import Collection…** on the Collections screen, or simply open a `.fruscollection` from Files, Mail, or AirDrop. Opening the same file again re-surfaces the collection it created rather than importing a duplicate.
- **Proposed:** **Importing.** **Import Collection…** on the Collections screen, or simply open a `.fruscollection` from Files, Mail, or AirDrop. Research notes the file carries become notes of yours on those documents, searchable straight away. Opening the same file again re-surfaces the collection it created rather than importing a duplicate.
- **Why:** as for the Mac — Import Collection… at `CollectionListView.swift:254`, and a file opened from Files, Mail or AirDrop at `FRUSExplorerApp.swift:2086`.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.8 Exporting a Chart for Publication (the **What.** bullet)
- **Current:** The **CSV is the complete artifact**: a `#`-commented preamble naming the figure, your terms, the grouping, the scope, the year range, the value mode, the app version, and the export date — followed by the full method and caveats, then the table.
- **Proposed:** The **CSV is the complete artifact**: a `#`-commented preamble naming the figure, your terms, the grouping, the scope, the year range, the value mode, the app version, and the export date — followed by the full method and caveats, closing on what the numbers were drawn from, then the table. That last statement names the volumes alone for most charts, and says so where a chart joined them to other data or computed from them: a word cloud's word lists, the semantic map's model, Person Analytics' people register, the regional chart's subject taxonomy, and the State Department's filing schedule behind a class ranking's unprinted pointers or a class's gloss.
- **Why:** PV-1 (the 2026-09-28 audit): every analytics export claimed "the FRUS volumes, and from no other source"; the builders now pass their sources (`FRUSExplorer/Analytics/WordCloud/WordCloudView.swift:1227`, `FRUSExplorer/Semantic/Map/SemanticMapExport.swift:142`, `FRUSExplorer/Analytics/PersonAnalyticsView.swift:542`, `FRUSExplorer/SeriesAnalytics/SeriesAnalyticsExport.swift:101`, `FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift:175`), and the plate prints the same statement.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.8 Exporting a Chart for Publication (the **What.** bullet)
- **Current:** The **CSV is the complete artifact**: a `#`-commented preamble naming the figure, your terms, the grouping, the scope, the year range, the value mode, the app version, and the export date — followed by the full method and caveats, then the table.
- **Proposed:** The **CSV is the complete artifact**: a `#`-commented preamble naming the figure, your terms, the grouping, the scope, the year range, the value mode, the app version, and the export date — followed by the full method and caveats, closing on what the numbers were drawn from (the volumes alone for most charts; the volumes joined to other data, or computed by the app, where a chart did that), then the table.
- **Why:** as for the Mac (PV-1). The section's next bullet, **Before you publish a figure alone**, is already stale on iOS — the plate has printed every caveat since visual-marketing GATE C — and is left to lane MANUALS, which the planning audit records.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.8 Exporting a Chart for Publication (the last bullet)
- **Current:** Files are named for the chart and dated (`FRUS-Analytics-Berlin-By-Year-2026-07-24.csv`), so repeat exports stay distinguishable in a downloads folder. If an export fails, the app says so rather than doing nothing.
- **Proposed:** Files are named for the chart and dated (`FRUS-Analytics-Berlin-By-Year-2026-07-24.csv`), so repeat exports stay distinguishable in a downloads folder; a very long title — a word cloud of a volume with a long title — is shortened in the file name, never in the figure or the CSV. If an export fails, the app says so rather than doing nothing.
- **Why:** the 2026-09-28 audit: `AnalyticsExportDelivery.filenameStem` (`FRUSExplorer/Analytics/Export/AnalyticsExportDelivery.swift:133`) cuts the title's part so prefix, date and extension fit; the longest volume title made a 515-byte name.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.8 Exporting a Chart for Publication (the last bullet)
- **Current:** Files are named for the chart and dated (`FRUS-Analytics-Berlin-By-Year-2026-07-24.csv`), and the share sheet lets you save, AirDrop, or send them anywhere.
- **Proposed:** Files are named for the chart and dated (`FRUS-Analytics-Berlin-By-Year-2026-07-24.csv`) — a very long title is shortened in the file name, never in the figure or the CSV — and the share sheet lets you save, AirDrop, or send them anywhere.
- **Why:** as for the Mac; on iOS the uncut name failed the share sheet's write in the temporary directory.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.5 Data & Recovery (the **Export Query Log as a Method Appendix** paragraph)
- **Current:** **Export Query Log as a Method Appendix** writes the same trail as a methods statement rather than as data: a Markdown table you can paste into a paper, and a CSV to re-derive from. Each row is one search with the scope it ran under, how many volumes were indexed at the time, and what it returned.
- **Proposed:** **Export Query Log as a Method Appendix** writes the same trail as a methods statement rather than as data: a Markdown table you can paste into a paper, and a CSV to re-derive from. Each row is one search with the scope it ran under, how many volumes were indexed at the time, and what it returned. Both, and the query log a collection appends, say what the counts were drawn from: the volumes' text, and the app's search model where a Meaning search is listed.
- **Why:** PV-1's appendix half (the 2026-09-28 audit): only the CSV carried the sources block; `QueryMethodAppendix.sourceLines` (`FRUSExplorer/Export/QueryMethodAppendix.swift:484`) now feeds the Markdown and the plain-text lines a collection export embeds too.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.6 Data & Recovery (the **Export Query Log as a Method Appendix** paragraph)
- **Current:** **Export Query Log as a Method Appendix** writes the same trail as a methods statement rather than as data: a Markdown table you can paste into a paper, and a CSV to re-derive from. Each row is one search with the scope it ran under, how many volumes were indexed at the time, and what it returned.
- **Proposed:** As for the Mac, append: Both, and the query log a collection appends, say what the counts were drawn from: the volumes' text, and the app's search model where a Meaning search is listed.
- **Why:** as for the Mac (`QueryMethodAppendix.swift:484`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 The Archives Visit Packet (the **coverage report** paragraph)
- **Current:** A **coverage report** travels with every export, scoped or not — it is not optional, because an empty channel with no caveat reads as a clearance: how many targets resolved, how far the footnote scan reached (…), the digitized-substitute denominators, and how much of the restriction picture is actually measured.
- **Proposed:** A **coverage report** travels with every export, scoped or not — it is not optional, because an empty channel with no caveat reads as a clearance: how many targets resolved, how far the footnote scan reached (…), the digitized-substitute denominators, how much of the restriction picture is actually measured, and — as every export ends — where the packet came from: the volumes' source notes and footnotes as the app read them, with the parser's measured miss rate, and the app's snapshot of NARA's catalog.
- **Why:** PV-1 (the 2026-09-28 audit): the coverage report now ends on `TripPacketExporter.sourceLines` (`FRUSExplorer/TripPacket/TripPacketExporter.swift:776`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.8 The Archives Visit Packet (the **coverage report** paragraph)
- **Current:** A **coverage report** closes every export: how many targets resolved, how far the footnote scan reached (…), the digitized-substitute denominators, and how much of the restriction picture is actually measured.
- **Proposed:** A **coverage report** closes every export: how many targets resolved, how far the footnote scan reached (…), the digitized-substitute denominators, how much of the restriction picture is actually measured, and where the packet came from — the volumes' source notes and footnotes as the app read them, with the parser's measured miss rate, and the app's snapshot of NARA's catalog.
- **Why:** as for the Mac (`TripPacketExporter.swift:776`).
- **Owner:** ☐ approve ☐ edit ☐ reject

## MACCOL — #1446, #1448, #1449, #1477, #1493, #1475

*Lane MACCOL polishes the Mac Collections window and folds in two save fixes: the Mac detail pane writes only the field the reader edits and follows the others, and a heading's Section defaults saves each edit. These are the manual sentences that work makes incomplete or too cautious. Each quotes the manual as it stands at `origin/v2` f5625ca2. #1448 (the resting cap after a formatting change, and the edited height beside a legacy scroller), #1475 (List footers that wrap) and #1477 (no stale caret; legible chips on a selected row) change drawing the manuals do not describe, and need no change.*

- **Manual / section:** Mac §12.1 The Collections Window (the collection picker sentence)
- **Current:** The window has no permanent sidebar; you switch collections from the **collection picker** at the left of the toolbar — a pop-up menu listing every collection with its document count, plus **New Collection…** (⌥⌘N), …
- **Proposed:** The window has no permanent sidebar; you switch collections from the **collection picker** at the left of the toolbar — a pop-up menu listing every collection with its document count (a long name is cut short on the toolbar, and listed whole in the menu), plus **New Collection…** (⌥⌘N), …
- **Why:** #1446: the picker's label keeps the name to one line within `MacCollectionManagerView.collectionNameMaxWidth`, 260 pt (`FRUSExplorer/Collections/MacCollectionManagerView.swift:203`), so a long name no longer pushes the toolbar's items behind its overflow chevron; the menu's rows still list the name whole. Every count the picker prints — its label's and its rows' — and Manage Collections' rows' now prints grouped (*1,234*), where all three printed *1234*; the manual quotes no count, so this needs no sentence.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.3 Composing, the **Prose blocks** bullet
- **Current:** …click it to edit the whole block, and it goes back to its opening lines when you click another row or field. The introduction in the ⚙ Collection popover works the same way.
- **Proposed:** …click it to edit the whole block, and it goes back to its opening lines when you click another row or field. The introduction in the ⚙ Collection popover works the same way, and so does the popover's **Note** above it, which is plain text and has no formatting bar.
- **Why:** #1449: the Note is the shared capped editor in its plain-text mode (`RichTextEditor(…, restingCap: .noteInPopover, plainText: true)`, `MacCollectionManagerView.swift:995`), where it was a fixed-height field that scrolled a long note and cut it through a line. It stays plain because the collection's note is a plain `String?`; a rich note would be a stored property, a CloudKit schema change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.3 Composing, the **Apparatus blocks** bullet (a sentence added after the list of the five blocks)
- **Current:** (no sentence)
- **Proposed:** Where these blocks list documents, each reads by its printed number — *Document 373a* — and one the volume prints without a number, such as the unnumbered documents of the Potsdam volume, reads *Unnumbered (d710a-1)*, by its history.state.gov identifier.
- **Why:** #1493, the owner's decision D5: `CitableDocumentNumber.unnumberedLabel` (`FRUSExplorer/Citation/CitationFormatter.swift:294`) through the blocks' list tokens (`CollectionGeneratedBlocks.referenceToken` and `referenceListText`, `FRUSExplorer/Collections/CollectionGeneratedBlocks.swift:727`, `:759`). They used to print the id as though it were the number — "Document d710a-1".
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.5 Document Rows and the Inspector (first sentence)
- **Current:** Each document row is a scannable report — title, volume, date, and small labeled chips — …
- **Proposed:** Each document row is a scannable report — the document's printed number (*Document 373a*, or *Unnumbered (d710a-1)* for a document the volume prints without one), title, volume, date, and small labeled chips — …
- **Why:** #1493: the row's label is `CitableDocumentNumber.rowLabel` (`CitationFormatter.swift:271`, called at `MacCollectionManagerView.swift:1798`), which showed such a document's bare id. A document whose volume is not indexed on this Mac still shows its id, and an apparatus block that lists it reads *Document d710a-1*: with no number stored, nothing the app has read says the volume prints none, and it does not guess from the identifier's shape.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.5 Apparatus Blocks (a sentence added after the list of the five blocks)
- **Current:** (no sentence)
- **Proposed:** Where these blocks list documents, each reads by its printed number — *Document 373a* — and one the volume prints without a number, such as the unnumbered documents of the Potsdam volume, reads *Unnumbered (d710a-1)*, by its history.state.gov identifier.
- **Why:** as for the Mac (#1493; `CitationFormatter.swift:294`, `CollectionGeneratedBlocks.swift:727`, `:759`); the blocks are the same on every platform, in the preview and in every export.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.1 The Manager on iPad (its first paragraph, the save sentences)
- **Current:** Collection settings saves each edit as you make it, so leaving by Back, by another tab, or by closing the app loses nothing. Section defaults puts each edit on the collection at once, so leaving the sheet or the editor loses nothing, and the app saves it with its regular saves.
- **Proposed:** Collection settings saves each edit as you make it, and Section defaults saves each change to the collection's description, subtitle, author line and three export switches the same way, so leaving by Back, by another tab, or by closing the app loses none of them. Section defaults puts its other changes on the collection at once too, and the app saves them with its regular saves.
- **Why:** the plan of record's fold-in "Section defaults save each write": `CollectionAttributesRows` — the sheet's description, subtitle, author line and three toggles — now saves in every field's and toggle's binding (`optional(_:)` and `saving(_:)`, `FRUSExplorer/Collections/CollectionCompositionRows.swift:353`, `:359`), where it left the save to the app's autosave. Pinned by `SectionDefaultsSaveTests`, which types into each field and switches each toggle with autosave off. The sheet's other controls — the composition rows (`CollectionCompositionRows`) and the section's own export defaults (`CollectionEntryInspector.overrideControls`) — still leave the save to autosave, so the proposal promises nothing for them.
- **Owner:** ☐ approve ☐ edit ☐ reject

## SEL — #1540

*Lane SEL retires the iPhone and iPad floating selection bar: its four color dots, Excerpt, Look Up and Note now open the system edit menu, before Copy, as the owner chose on 2026-09-29 (option a). The Mac keeps its bar. On both platforms "Look Up" is now **Look Up in NARA**, because the iPhone and iPad menu has a Look Up of its own (the dictionary). Measured on the simulators (iOS 26.5): an iPhone 17's menu shows the four dots and **Excerpt**, then **›**, which opens the whole menu as a list (Look Up in NARA, Note, then Copy, Find Selection, Look Up, Translate…); an iPad Pro 13-inch's shows the dots, Excerpt and Look Up in NARA before its **›**. Only those two devices were measured, at the default text size; how many items fit before **›** changes with the width and the text size, so no proposal below names a device. A selection inside a footnote offers only Look Up in NARA and Note, where the bar showed the dots and Excerpt dimmed. Each entry quotes the manual as it stands at `origin/v2` f5625ca2. The code: `SelectionEditMenu` and `_FRUSEditMenuWebView.buildMenu(with:)` in `FRUSExplorer/TEI/FRUSDocumentWebView.swift:764`, `:854`; the verbs and their names in `SelectionVerb`, `FRUSExplorer/DocumentView/FloatingSelectionBar.swift:24`; the reader's handling in `DocumentView.performSelectionVerb`, `FRUSExplorer/DocumentView/DocumentView.swift:1808`.*

- **Manual / section:** iOS §3 A First Session, step 3
- **Current:** **Highlight a passage.** Select a sentence with your finger or Apple Pencil. A dark pill — the **floating selection bar** — appears just below the selection. Tap one of its four **color dots** and the passage is highlighted in that color, permanently and across your devices. There is no separate highlight mode to enter or leave.
- **Proposed:** **Highlight a passage.** Select a sentence with your finger or Apple Pencil. The edit menu that appears beside the selection begins with four **color dots**. Tap one and the passage is highlighted in that color, permanently and across your devices. There is no separate highlight mode to enter or leave.
- **Why:** #1540: the bar is gone and the dots lead the system edit menu (`_FRUSEditMenuWebView.buildMenu(with:)`, `FRUSDocumentWebView.swift:854`, inserting `SelectionEditMenu`'s group at the start of the menu). UIKit places the menu above or below the selection, so "beside" rather than "below".
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §3 A First Session, step 4
- **Current:** **Attach a note.** With text selected, tap **Note** on the same bar and type a thought. The note is saved to this document, filed under your active project, and searchable later.
- **Proposed:** **Attach a note.** With text selected, choose **Note** from the same menu — if it is not on the menu's first page, tap **›** to reach it — and type a thought. The note is saved to this document, filed under your active project, and searchable later.
- **Why:** #1540 (as above). On an iPhone 17 and an iPad Pro 13-inch (iOS 26.5, default text size) Note is in the list **›** opens; on a wider window or at a smaller text size it may fit on the first page, so the step does not name a device (review round 1).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §4.3 The Floating Selection Bar (heading and the paragraph and list under it)
- **Current:** ### 4.3 The Floating Selection Bar / Select any passage in the document body and a dark pill appears just below it with the actions that operate on a selection: / - Four **color dots** — tap one to highlight the selection in that color (Section 9.1). / - **Excerpt** — capture the selection as a verbatim quotation into a collection (Section 12.4). / - **Look Up** — run a NARA Catalog lookup on the selected text (Section 14.2). / - **Note** — attach a research note (Section 9.2).
- **Proposed:** ### 4.3 Actions on a Selection / Select any passage in the document body and the edit menu that appears beside it begins with FRUS Explorer's own actions, ahead of the system's (Copy, Look Up, Translate and the rest): / - Four **color dots** — tap one to highlight the selection in that color (Section 9.1). / - **Excerpt** — capture the selection as a verbatim quotation into a collection (Section 12.4). / - **Look Up in NARA** — run a NARA Catalog lookup on the selected text (Section 14.2). The system's own **Look Up**, later in the menu, is the dictionary. / - **Note** — attach a research note (Section 9.2). / The menu shows as many of its items as fit and puts the rest behind **›**; how many fit depends on the device and the text size. Choosing one of these actions clears the selection. VoiceOver reads each dot by its name, such as "Highlight Yellow".
- **Why:** #1540. The section describes a control that no longer exists on iPhone or iPad. The order is `SelectionVerb.allInOrder` (`FloatingSelectionBar.swift:36`); the selection is cleared by `_FRUSEditMenuWebView.clearSelection()` (`FRUSDocumentWebView.swift:880`); the dots' spoken names are their images' accessibility labels (`SelectionEditMenu.action(for:perform:)`, `FRUSDocumentWebView.swift:793`), read by `SelectionEditMenuTests` from the menu's accessibility tree on iPhone 17 and iPad Pro 13-inch (M5). The row's contents were measured only on those two devices at iOS 26.5 and the default text size, so the paragraph names no device (review round 1). A selection that ends at the end of a paragraph, or just before a footnote marker, keeps the colors and Excerpt since review round 1 (`rangeEndpointToOffset`, `FRUSExplorer/Resources/frus-selection.js:72`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §4.3, the paragraph after the list (its first sentence)
- **Current:** For a selection inside a footnote, the color dots and Excerpt are disabled; Look Up and Note remain available.
- **Proposed:** For a selection inside a footnote, the menu offers only Look Up in NARA and Note.
- **Why:** #1540: `SelectionEditMenu.verbs(hasDocumentOffsets:)` (`FRUSDocumentWebView.swift:773`) leaves out the colours and Excerpt for a selection with no document offsets, where the bar showed them dimmed. The rest of the paragraph (list labels, table captions) is unchanged.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §9.1 Highlights, first paragraph
- **Current:** Select a passage (finger or Apple Pencil) and tap one of the four **color dots** on the floating selection bar — yellow, green, blue, or pink.
- **Proposed:** Select a passage (finger or Apple Pencil) and tap one of the four **color dots** at the start of the edit menu — yellow, green, blue, or pink.
- **Why:** #1540 (as for §4.3).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §9.2 Research Notes, first sentence
- **Current:** Attach a free-form note from the floating selection bar's **Note** (with a passage selected) or from the **Notes** accordion in the Research rail.
- **Proposed:** Attach a free-form note from **Note** in the edit menu (with a passage selected) or from the **Notes** accordion in the Research rail.
- **Why:** #1540 (as for §4.3).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.4 Excerpts
- **Current:** …select a passage while reading and tap **Excerpt** on the floating selection bar; or tap **Insert as Excerpt** on any highlight row in a document's inspector.
- **Proposed:** …select a passage while reading and choose **Excerpt** from the edit menu; or tap **Insert as Excerpt** on any highlight row in a document's inspector.
- **Why:** #1540 (as for §4.3).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §14.2 What Resolves, and How, the **Free-text lookup** paragraph
- **Current:** …and tap **Look Up** on the floating selection bar for a NARA Catalog query pre-populated with your selection, with a choice of search strategies.
- **Proposed:** …and choose **Look Up in NARA** from the edit menu for a NARA Catalog query pre-populated with your selection, with a choice of search strategies. (The menu's plain **Look Up** is the system dictionary.)
- **Why:** #1540: the verb is renamed on both platforms (`selectionBar.lookUpInNARA`, `FloatingSelectionBar.swift:60`) and moved into the edit menu on iPhone and iPad.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §19.1 Where Do I…?, four rows
- **Current:** | Highlight a passage | Select text → a color dot on the floating selection bar | / | Attach a note to a passage | Select text → **Note** on the floating selection bar | / | Capture a quotation for a collection | Select text → **Excerpt** | / | Look up selected text in the NARA catalog | Select text → **Look Up** |
- **Proposed:** | Highlight a passage | Select text → a color dot in the edit menu | / | Attach a note to a passage | Select text → **Note** in the edit menu | / | Capture a quotation for a collection | Select text → **Excerpt** in the edit menu | / | Look up selected text in the NARA catalog | Select text → **Look Up in NARA** in the edit menu |
- **Why:** #1540 (as for §4.3 and §14.2).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §4.2 The Research Rail, the **Highlighting is not a rail button** paragraph
- **Current:** …plus **Excerpt** (freeze the passage into a collection, Section 12.3), **Look Up** (hand the text to Source Explorer, Section 14.2), and **Note** actions. For a selection inside a footnote, the color dots and Excerpt are disabled; Look Up and Note remain available. … The same bar, with the same behavior, appears on iPad and iPhone.
- **Proposed:** …plus **Excerpt** (freeze the passage into a collection, Section 12.3), **Look Up in NARA** (hand the text to Source Explorer, Section 14.2), and **Note** actions. For a selection inside a footnote, the color dots and Excerpt are disabled; Look Up in NARA and Note remain available. … On iPad and iPhone the same actions open the system edit menu instead of a bar.
- **Why:** #1540: the Mac bar's verb is now "Look Up in NARA" (`FloatingSelectionBar` reads `SelectionVerb.lookUpInNARA.title`, `FloatingSelectionBar.swift:198`), and iPhone and iPad no longer draw the bar (`DocumentView.swift` mounts none; `SelectionBarRetirementTests` pins that).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §4.5 Separate Windows, and How They Behave, the **Source Explorer** row of the table
- **Current:** | Source Explorer | Research rail **Sources** tile (one window per document); **Look Up** on the selection bar, or **Window ▸ Source Explorer** (Section 14) |
- **Proposed:** | Source Explorer | Research rail **Sources** tile (one window per document); **Look Up in NARA** on the selection bar, or **Window ▸ Source Explorer** (Section 14) |
- **Why:** #1540, the rename (`FloatingSelectionBar.swift:60`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14 Source Explorer: From Source Note to Archive, the opening paragraph
- **Current:** …**Look Up** on the selection bar opens the same window's **NARA Lookup** view (Section 14.2).
- **Proposed:** …**Look Up in NARA** on the selection bar opens the same window's **NARA Lookup** view (Section 14.2).
- **Why:** #1540, the rename (as above).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.2 Free-Text Lookup, first sentence
- **Current:** Select any text in a document body — a lot number, a decimal identifier, an archival keyword — and choose **Look Up** on the floating selection bar: …
- **Proposed:** Select any text in a document body — a lot number, a decimal identifier, an archival keyword — and choose **Look Up in NARA** on the floating selection bar: …
- **Why:** #1540, the rename (as above).
- **Owner:** ☐ approve ☐ edit ☐ reject

## CITE — #1504, #1506, #1523, #1524, #1491

*Lane CITE deletes Citation Lookup's nearest-document strategy and the manifest's `documentCount` (#1504, D6); hides the Parsed Fields in Batch and counts a best guess in a bucket of its own (#1506, D17); keeps refusing side-loaded volumes in Citation Lookup and Add Documents and says so at side-load time (#1523, D7); takes the cited volume numeral out of the title fragment as a whole word (#1524, no reader-visible change); and cites the Potsdam volume's unnumbered documents in the app with no number, as the exports do (#1491). These are the manual sentences that change makes wrong, incomplete or stale. Each quotes the manual as it stands at `origin/v2` f5625ca2.*

- **Manual / section:** Mac §5.1a Side-Loaded Volumes, the list's lead-in and the paragraph after it
- **Current:** Four things are deliberately different, and each is the honest consequence of the file not being the catalog's: … One more difference is not a design rule but where the app stands today: **Citation Lookup** and **Add Documents ▸ Citations** find volumes in the bundled catalog only, so they do not resolve a citation or history.state.gov link to a side-loaded volume (11.4, 12.2). `<!-- OPEN #1523: side-loaded volumes are refused by citation and link resolution; revisit this paragraph when the owner decides. -->`
- **Proposed:** Five things are deliberately different, and each is the honest consequence of the file not being the catalog's: … (a fifth bullet:) **Citation Lookup** and **Add Documents ▸ Citations** resolve citations against the bundled catalog only, so they do not resolve a citation or history.state.gov link to a side-loaded volume, even one on this Mac and indexed (11.4, 12.2); open it from Browse or find it with Search. When you side-load a volume the catalog does not list, Volumes & Storage says so under the import's result: **Not in the bundled catalogue**. (Delete the "One more difference…" paragraph and its OPEN comment.)
- **Why:** #1523, owner decision D7 — refuse, and tell the reader at side-load time. The engine reads `ManifestStore.citableEntries`, the bundled catalogue (`FRUSExplorer/Models/Manifest/ManifestStore.swift:156`; `FRUSExplorer/Citation/CitationMatchingEngine.swift:413`, `:743`), and both storage hubs show `SideloadCatalogueNoticeRow` when an import adds a volume outside it (`FRUSExplorer/Settings/SettingsView.swift:494`; `MacVolumesStorageHub.swift:332`). A file named after a catalogue volume is that volume and draws no notice.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §5.1a Side-Loaded Volumes, the list of differences
- **Current:** Four things are deliberately different, and each is the honest consequence of the file not being the catalog's: (four bullets; the iOS section never mentions Citation Lookup)
- **Proposed:** Five things are deliberately different, and each is the honest consequence of the file not being the catalog's: … (a fifth bullet:) **Find by citation** and **Add Documents ▸ Citations** resolve citations against the bundled catalog only, so they do not resolve a citation or history.state.gov link to a side-loaded volume, even one on this device and indexed; open it from Browse or find it with Search. When you side-load a volume the catalog does not list, Volumes & Storage says so under the import's result: **Not in the bundled catalogue**.
- **Why:** as for the Mac (#1523; `VolumesStorageHubView.swift:358`). The iOS manual has never documented the refusal, which the Mac manual does; this brings DOCS-2 parity.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.4 Citation Lookup, the **Batch** bullet
- **Current:** The result is a table — **Resolved**, **N possible documents**, or **No match** per note — with a running count of resolved, ambiguous, and unresolved citations. A note is **Resolved** only when its one answer is a document the lookup vouches for; a note whose one answer is a best guess, a volume still to download, or a volume still to be indexed, shows that answer's own label instead and counts as ambiguous.
- **Proposed:** The result is a table — **Resolved**, **N possible documents**, a best guess's own label, or **No match** per note — with a running count of resolved, ambiguous, best-guess and unresolved citations (*12 citations · 7 resolved · 2 ambiguous · 2 best guesses · 1 unresolved*). A note is **Resolved** only when its one answer is a document the lookup vouches for. A note whose one answer the lookup labels a best guess — a document from a volume the citation does not name, or not on the cited page, or a volume still to download or to be indexed that does not match a part, volume or year the citation names — shows that label and counts as a best guess; **Needs work first** sorts best guesses after the notes that found nothing and before the ambiguous ones, because a best guess reads like an answer. A note whose one answer is a volume still to download or still to be indexed that matches everything the citation names shows that label and counts as ambiguous. Batch hides the Parsed Fields, which it never reads — each note is parsed on its own.
- **Why:** #1506, owner decision D17. `BatchCitationOutcome.classify` gives a lone row the engine labels a best guess its own outcome (`FRUSExplorer/Citation/CitationBlockSplitter.swift:205`, reading `CitationMatch.isBestGuess` at `CitationModels.swift:392`; a volume row is marked by the engine at `CitationMatchingEngine.swift:714`), `triageOrder` puts it third (`:238`), and `summary(of:locale:)` counts it apart (`:262`); the form mounts the Parsed Fields only where the mode reads them (`CitationLookupView.swift:258`, `CitationLookupMode.showsParsedFields` at `CitationModels.swift:480`), and Batch focuses its footnote editor (`CitationLookupFocus.initial(for:)`, `CitationLookupView.swift:673`). The common volume case is #1474's own example, *FRUS, 1961–1963, vol. V, pt. 2, doc. 84*, with Volume V not downloaded: its row reads "Best guess — this volume does not match the cited part 2", and the count says so.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §11.4 Citation Lookup, in Both Directions — the end of the paragraph on volumes not yet indexed
- **Current:** …and in **Batch** that note counts as ambiguous. A document the volume already holds is found as usual, and a citation naming only the volume is answered as it will be once the volume is indexed.
- **Proposed:** …and in **Batch** that note counts as ambiguous. A document the volume already holds is found as usual, and a citation naming only the volume is answered as it will be once the volume is indexed. **Batch** counts a note whose one answer the lookup labels a best guess — a document, or a volume still to download or to be indexed, that does not match something the citation names — as a best guess, apart from the ambiguous notes (*… · 2 ambiguous · 2 best guesses · …*), and hides the Parsed Fields, which it never reads; entering it puts the cursor in the footnote box.
- **Why:** #1506, as for the Mac (`CitationBlockSplitter.swift:205`, `:262`; `CitationLookupView.swift:258`, `:673`). On iPhone, entering Batch used to focus the Subseries field and raise the keyboard over a field Batch ignores. The not-yet-indexed note the sentence before describes stays ambiguous, because its label is **Volume identified — …**; one whose volume does not match the citation is labelled a best guess, and is counted as one.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.4 Citation Lookup, the comment under the label table
- **Current:** `<!-- OPEN #1504: a nearest-document label ("Possible match — document N not found; nearest is document M") exists in code but never appears, because every manifest row carries documentCount 0. Restore a row here only if #1504 supplies the counts. -->`
- **Proposed:** (delete the comment; the label table needs no row)
- **Why:** #1504, owner decision D6: the strategy, its two labels and the manifest's `documentCount` are deleted (`CitationMatchingEngine.swift` header, version 2.1; `FRUSExplorer/Resources/manifest.json`, 553 rows). A document number a volume does not hold now finds nothing in it, as it always did on the shipped manifest.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.4 Citation Lookup, the paragraph after the table
- **Current:** Lookup finds volumes in the app's bundled catalog only, so a citation or history.state.gov link naming a **side-loaded** volume (5.1a) is not resolved to it, even when the volume is on this Mac and indexed. `<!-- OPEN #1523: owner decision — widen volume resolution to side-loaded volumes, or keep this refusal documented in both manuals. -->`
- **Proposed:** Lookup resolves citations against the app's bundled catalog only, by design, so a citation or history.state.gov link naming a **side-loaded** volume (5.1a) is not resolved to it, even when the volume is on this Mac and indexed. (Delete the OPEN comment.)
- **Why:** #1523: the owner decided to keep the refusal (D7), so the paragraph is now the documented behaviour (`CitationMatchingEngine.swift:413`, `:743`; `ManifestStore.swift:156`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §11.1 (the **Cite** tile paragraph) and iOS §11.1 (the **Cite** paragraph)
- **Current:** Mac: From any open document, the rail's **Cite** tile opens the citation popover: the formatted citation in your chosen style (switchable per view), with **Copy citation**, **Copy URL**, and a **Copy as…** menu (BibTeX / RIS, or **Save as .bib**). Paste into a footnote and move on. iOS: From any open document, tap **Cite** in the Research rail: the fully formatted citation, with **Copy Citation** and **Copy as…** BibTeX or RIS. Paste into a footnote and move on.
- **Proposed:** (append to each:) A document the volume prints without a number — the Potsdam volume's 217 unnumbered documents, which the Office of the Historian's data numbers with an editorial description such as *[Unnumbered document following Document 710 (#1)]* — is cited without one, ending at the publication details, exactly as a collection export or a trip packet cites it. (Mac only, after it:) Above the citation, and in the document's header, its previous and next buttons and the window's toolbar, such a document is named *Unnumbered (d710a-1)* — its history.state.gov identifier.
- **Why:** #1491: every in-app citation route — Copy Citation, its share message, BibTeX, RIS and Zotero on iOS (`FRUSExplorer/DocumentView/DocumentViewModel.swift:215`), the Mac citation and share popovers (`FRUSExplorer/App/SupportingViews.swift:1084`, and the popover's **Document no.** row at `:1310`) and the Research-notes Markdown export (`FRUSExplorer/Export/ResearchDataExporter.swift:941`) — now resolves the number through `CitableDocumentNumber.resolve` (`FRUSDocumentMetadata.init(citing:printedNumber:)`, `FRUSExplorer/Citation/CitationFormatter.swift:157`). Before, the app printed "…, Document [Unnumbered document following Document 710 (#1)]." and Citation Lookup read that paste as document 710. Review round 1 named the captions too: the popover's identity line (`SupportingViews.swift:1253`), the Mac reader's header, previous and next buttons and position (`MacDocumentView.swift`, `CitableDocumentNumber.headerLabel` / `.captionLabel`, `CitationFormatter.swift:318`, `:332`), its standalone window's toolbar (`MacDocumentTitle.swift`), the Mac Search row and the breadcrumb, each of which printed "Doc [Unnumbered document following Document 710 (#1)]". Optional: the manuals never described the old form, so this is a clarification, not a correction.
- **Owner:** ☐ approve ☐ edit ☐ reject

## XREF — #1472, #1473

*Lane XREF fixed Cross-Reference Analytics' Most-Referenced Documents chart at narrow widths (#1473), the 1969–76 E-volumes' matrix column codes and their doubled number in every short volume label (#1472), and the matrix row labels whose first word broke across two lines on a phone (the plan's fold-in). The manuals describe none of the matrix's column codes or on-screen row labels, and quote no E-volume label, so only the ranking needs anything. Each entry quotes the manual as it stands at `origin/v2` 0591a2df.*

- **Manual / section:** Mac §15.4 Cross-Reference Analytics, the **Most-Referenced Documents** bullet
- **Current:** - **Most-Referenced Documents** — ranked by inbound citations (in-degree); chart or table. A fast way to surface the memos and decisions a whole era kept coming back to. <!-- OPEN #1473: at the window's 720 pt minimum and its ~820 pt default, this chart draws document titles with no bars (a bug, not behaviour). -->
- **Proposed:** - **Most-Referenced Documents** — ranked by inbound citations (in-degree); chart or table. A fast way to surface the memos and decisions a whole era kept coming back to. In the chart a long title takes up to two lines and is cut at its end, so the bars keep their room at any window width; the table, and VoiceOver on each bar, give the title whole.
- **Why:** #1473 is fixed, so the `OPEN` comment goes. A chart label takes 40% of the chart's width, raised to at least 120 pt and capped at 320 pt, and then narrowed if it must be so the plot keeps 160 pt (`RankingChartAxis.labelWidth`, `FRUSExplorer/Analytics/RankingChartLabels.swift:432`), wrapping to two lines (`RankingAxisLabelLayout`, `FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift:1587`); before, a title took its whole one-line width and at 720–820 pt left the bars none. The added sentence is optional: the manual never said a title was shown whole, but a reader who sees one cut may want to know where to read it.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.4 Cross-Reference Analytics, the **Most-Referenced Documents** bullet
- **Current:** - **Most-Referenced Documents** — ranked by inbound citations (in-degree); chart or table. A fast way to surface the memos and decisions a whole era kept coming back to.
- **Proposed:** - **Most-Referenced Documents** — ranked by inbound citations (in-degree); chart or table. A fast way to surface the memos and decisions a whole era kept coming back to. In the chart a long title takes up to two lines and is cut at its end; the table, and VoiceOver on each bar, give the title whole.
- **Why:** as for the Mac (#1473; the same `CrossReferenceRankingChart` on every platform, `CrossReferenceAnalyticsView.swift:1525`). On an iPhone the bug was worse than on the Mac: on `v2`, iPhone 17, the plot was squeezed to 1 pt at x 977 of a 402 pt window, and 5 of the 12 rows on screen showed no title at all. Optional, like the Mac sentence.
- **Owner:** ☐ approve ☐ edit ☐ reject

## HYG — #1412, #1439, #1423, #1450, #1484

*Lane HYG is developer hygiene: test fixtures (#1412, #1450), a generator's write order (#1439), dead code (#1423, #1484, and the plan's fold-ins), two generator defaults, a license scan and comments. It changes two strings a reader sees, both on the Mac's main window, and deletes one screen state no reader could reach. **It makes no manual change necessary.** The three things checked, against both manuals as they stand at `origin/v2` dc17d945, are listed so the owner can see why, with one optional sentence offered.*

- **Manual / section:** Mac §4.3 The Document View
- **Current:** The central area displays the open document ("Select a document to begin" when none is).
- **Proposed:** no change needed. Optional, if the hint is worth quoting whole: The central area displays the open document; when none is open it reads "Select a document to begin" over a hint, "Use Search (⌥⌘F) or open the Corpus Browser (⇧⌘B)".
- **Why:** the hint under that sentence read "Use Search (⌘S)…" in the app, a key the app binds to nothing since UI review M-14 moved Search to ⌥⌘F, and the toolbar's Search tooltip read "Open the full-text search window (⌘F)", which is Find in Document. Both now name ⌥⌘F (`FRUSExplorer/App/MainWindowView.swift:289`, `:494`–`495`; the shortcut is registered at `FRUSExplorer/App/FRUSExplorerApp.swift:3807`). The manual already gives ⌥⌘F everywhere it names the Search shortcut (lines 104, 124, 140, 196, 344, 1278) and quotes neither string, so the manual was right and the app was wrong. Nothing to correct; the optional sentence only quotes the hint now that it agrees with the manual.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §14.8 The Archives Visit Packet, the packet sheet's empty states (iOS §14.8 likewise)
- **Current:** neither manual describes them.
- **Proposed:** no change.
- **Why:** #1423 deleted the packet sheet's third empty state, "This collection’s search can’t run yet", with the path that showed it. That path was a packet built straight from a smart collection, and no screen could open one: the Archives Visit editor's **Export packet** is the sheet's one presenter (`FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift:276`), and it hands the sheet a plan. So no reader has seen the state, and neither manual mentions it. Recorded here because the lane found, and did not fix, what the state would have explained: **Add to Archives Visit…** on a smart collection whose saved search cannot run yet does nothing and says nothing (`FRUSExplorer/Collections/CollectionEditorView.swift:1378`, `:1459`; `FRUSExplorer/Collections/MacCollectionManagerView.swift:1391` — each returns when `TripPacketSeed.resolve` gives `nil`). If that is fixed, its message is new copy and may want a manual sentence then.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §13.2 Prompts and iOS §13.2 Prompts
- **Current:** each says where your own prompts are created (the Mac's: "**Your own prompts** are created in **Settings → Research → Summarization**").
- **Proposed:** no change.
- **Why:** #1484 deleted `PromptsListView`, an older prompts screen nothing constructed; prompts are managed where the manuals say, in `SummarizationPromptsSettingsView` (iOS) and the Mac's Summarization pane (`FRUSExplorer/Settings/SettingsView.swift`, `FRUSExplorer/Settings/FRUSSettingsView.swift`). The lane's other deletions (`GlobalContextView`, `BrowserView.splitLayout`, `SubseriesListView`) were also screens nothing presented, and neither manual describes them.
- **Owner:** ☐ approve ☐ edit ☐ reject

## READ — #1516

*Lane READ made a document's figures show their images (owner decision D3, option (f)4). These are the manual sentences that makes incomplete or out of step. Each quotes the manual as it stands at `origin/v2` dc17d945. Measured 2026-10-01 by HEAD request at corpus `8e5da08c1`: history.state.gov serves 553 figure images, 140,994,857 bytes (141 MB), for 96 of the 553 catalog volumes; 13 more names it refuses.*

- **Manual / section:** Mac §8.1 Document Structure (`Docs/macOS-User-Manual.md:493`)
- **Current:** … **body** (paragraphs, numbered footnotes, editorial notes, tables, and lists, faithfully rendered from the TEI source), and — when one exists — a **summary strip** above the body (Section 13).
- **Proposed:** … **body** (paragraphs, numbered footnotes, editorial notes, tables, lists, and figures, faithfully rendered from the TEI source), and — when one exists — a **summary strip** above the body (Section 13). A **figure** — a map, a chart, a facsimile — is drawn where the volume prints it, with its title above and its caption beneath. **[Figure]** stands in its place only when the image is not on this Mac: the app fetches it then if you are online, and draws it without a reload. Thirteen of the names the series' figures give have no image on history.state.gov, and those figures read **[Figure]** wherever the app shows them. The twenty films in the three *Public Diplomacy* volumes cannot play in the app: each shows its title, where it has one, and a **Watch on history.state.gov ↗** link, which opens the document's page in your browser.
- **Why:** #1516. A figure used to print only its file's name — "figure_1162" in the reader, "[figure_1162]" in a PDF, "[Figure: figure_1162]" in Word — and neither its head nor its captions. The converter now makes a figure of its head, image and captions (`figureBlock`, `FRUSExplorer/TEI/ASTToRenderNodeConverter.swift:643`); the reader draws the image from the device through `frusexplorer://figure/…` (`respondWithFigure`, `FRUSExplorer/TEI/FRUSURLSchemeHandler.swift:340`), shows `document.figure.missing` ("[Figure]", `FRUSExplorer/TEI/FRUSRenderNode.swift:478`) only while the image is absent, and for a video player prints `document.figure.video.watch` (`FRUSRenderNode.swift:483`). The 13 are the names the host answers with HTTP 403; the 20 films are 12 in `frus1917-72PubDip`, 5 in volume VI and 3 in volume VII, and all eight pages they link to answered 200. Seen on an iPhone 17 (iOS 26.4) with real volumes and, in review round 1, on an iPad Pro 13-inch (M5), iOS 26.5, with the images the app fetched from history.state.gov (`frus1946v01` d587, `frus1951v03p1` d289); the Mac was not run.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8 Reading Documents, the opening paragraph (`Docs/iOS-User-Manual.md:624`)
- **Current:** … the original TEI-encoded text rendered as readable prose, with headings, datelines, paragraphs, footnotes, editorial notes, and cross-references as the State Department published them.
- **Proposed:** … the original TEI-encoded text rendered as readable prose, with headings, datelines, paragraphs, footnotes, editorial notes, figures, and cross-references as the State Department published them. A **figure** — a map, a chart, a facsimile — is drawn where the volume prints it, with its title above and its caption beneath. **[Figure]** stands in its place only when the image is not on your device: the app fetches it then if you are online, and draws it without a reload. Thirteen of the names the series' figures give have no image on history.state.gov, and those figures read **[Figure]** wherever the app shows them. The twenty films in the three *Public Diplomacy* volumes cannot play in the app: each shows its title, where it has one, and a **Watch on history.state.gov ↗** link, which opens the document's page in your browser.
- **Why:** as for Mac §8.1 (#1516; the reader's page is the same on every platform, `FRUSExplorer/TEI/HTMLTemplate.swift:111`). Seen on an iPhone 17, iOS 26.4: `frus1951v03p1` d249's chart drawn at the column's width inside its editorial note, and `frus1917-72PubDipv06` appendix-1 with "[Figure]", "Reel 1" and the link.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.1 Downloading Volumes (`Docs/macOS-User-Manual.md:229`)
- **Current:** Downloaded volumes index automatically on completion.
- **Proposed:** Downloaded volumes index automatically on completion, and a volume's figure images — its maps, charts and facsimiles — are fetched with it from history.state.gov and kept beside it. The size a volume's page states is its text alone; the images are 141 MB across the whole series and nothing at all for most volumes. A volume you downloaded before this version gets its images the next time you open the app while you are online; until then, a document or an export fetches the image it needs.
- **Why:** #1516. `DownloadManager.figureTextDidChange` starts the fetch when a download finishes (`FRUSExplorer/Downloads/DownloadManager.swift:740`, `fetchFigureImages` at `:767`). A volume already on the device is brought up to its images by a pass over the library at launch and each time the device comes back online (`fetchMissingFigureImages`, `:851`, started from `FRUSExplorer/App/FRUSExplorerApp.swift:2148`), which also tries again whatever an earlier run could not fetch; until the pass reaches a volume, one image is fetched on demand (`fetchFigureImage`, `:898`, through `FigureImageStore`, configured at `FRUSExplorerApp.swift:2753`). The stated size is the manifest's `sizeBytes`, which is the XML. 96 of the 553 catalog volumes have an image the host serves; the median for those is 328 KB and the largest, `frus1943CairoTehran`, 25.4 MB. (Review round 1 added the pass and corrected the median, first given as 337 KB, the upper of the two middle values.)
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §5.1 Downloading Volumes, the last paragraph (`Docs/iOS-User-Manual.md:235`)
- **Current:** Downloads queue; progress appears in the indexing banner (Section 4.8) and in Settings. **Options** in Volumes & Storage sets concurrent downloads and whether cellular downloads are allowed.
- **Proposed:** Downloads queue; progress appears in the indexing banner (Section 4.8) and in Settings. **Options** in Volumes & Storage sets concurrent downloads and whether cellular downloads are allowed. A volume's figure images — its maps, charts and facsimiles — are fetched with it from history.state.gov, under the same cellular setting, and kept beside it; they are 141 MB across the whole series and nothing at all for most volumes. A volume you downloaded before this version gets its images the next time you open the app while you are online, under that same setting; until then, a document or an export fetches the image it needs.
- **Why:** as for Mac §5.1 (#1516). An image's request carries the Allow Cellular Downloads setting, as the volume's own does (`FRUSExplorer/Downloads/DownloadManager.swift:929`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.1a Side-Loaded Volumes, the list of differences (`Docs/macOS-User-Manual.md:239`)
- **Current:** Four things are deliberately different, and each is the honest consequence of the file not being the catalog's:
- **Proposed:** Five things are deliberately different, and each is the honest consequence of the file not being the catalog's: — and, as a fifth bullet: "Its figures read **[Figure]**. The app fetches figure images from history.state.gov by a catalog volume's ID, and a file of your own has no such address. (A side-loaded file whose ID *is* a catalog volume's — a corrected copy, say — is the exception: its images are fetched as that volume's are.)"
- **Why:** #1516. Side-loading starts no figure fetch; the pass over the library at launch reads catalog volumes only (`FRUSExplorer/Downloads/DownloadManager.swift:869`); and the on-demand fetch is refused for a volume the catalog does not list (`FigureImageStore.mayFetch`, `DownloadManager.swift:1475`) — all for #777's reason: the app has no address for it. The in-app notice shown after a side-load (`settings.hub.sideload.notCatalogued.detail`) does not say this; whether it should is the owner's wording to decide. Lane CITE's entry above changes the same lead-in for #1523; the two combine.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §5.1a Side-Loaded Volumes, the list of differences (`Docs/iOS-User-Manual.md:245`)
- **Current:** Four things are deliberately different, and each is the honest consequence of the file not being the catalog's:
- **Proposed:** Five things are deliberately different, and each is the honest consequence of the file not being the catalog's: — and the same fifth bullet as the Mac's.
- **Why:** as for Mac §5.1a (#1516, `DownloadManager.swift:1475`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.3 Managing Storage, the storage bar (`Docs/macOS-User-Manual.md:263`)
- **Current:** The essentials: a **Storage used** bar split into **XML**, **Index**, **Summaries**, and **Vectors** (the semantic-vector files, Section 5.3a);
- **Proposed:** The essentials: a **Storage used** bar split into **XML**, **Figures** (the volumes' figure images), **Index**, **Summaries**, and **Vectors** (the semantic-vector files, Section 5.3a);
- **Why:** #1516. The bar draws a **Figures** segment after XML whenever any image is on the device (`settings.storage.segment.figures`, `FRUSExplorer/Settings/SettingsComponents.swift:69`), from `StorageReport.totalFigureBytes` (`FRUSExplorer/Downloads/DownloadModels.swift:113`). A volume's row shows its text and images together (`VolumeStorageEntry.totalBytes`, `DownloadModels.swift:70`), and Free Up Space's estimate counts the images once (`FRUSExplorer/Settings/StorageHubModel.swift:92`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.3 Managing Storage, the last sentence (`Docs/macOS-User-Manual.md:263`)
- **Current:** Your annotations are never touched by any storage or index operation — removing a volume removes the text, not your work.
- **Proposed:** Your annotations are never touched by any storage or index operation — removing a volume removes the text and its figure images, not your work.
- **Why:** #1516. `DownloadManager.deleteVolume` removes the volume's images with its XML (`discardFigureImages`, `FRUSExplorer/Downloads/DownloadManager.swift:959`), and Reset Local Data sweeps every volume's (`FRUSExplorer/Settings/ResetService.swift:160`).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §17.2 Volumes & Storage, the first sentence (`Docs/macOS-User-Manual.md:1168`)
- **Current:** It opens with a **Storage used** bar split into **XML**, **Index**, **Summaries**, and **Vectors**, a status line, and the two ways in — **Download from GitHub…** and **Sideload XML File…**.
- **Proposed:** It opens with a **Storage used** bar split into **XML**, **Figures**, **Index**, **Summaries**, and **Vectors**, a status line, and the two ways in — **Download from GitHub…** and **Sideload XML File…**.
- **Why:** as for Mac §5.3 (#1516, `SettingsComponents.swift:69`; `FRUSExplorer/Settings/MacVolumesStorageHub.swift:849` passes the figure). Lane STOR's entry above adds to the end of the same sentence; the two combine.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §5.3 Managing Storage, the first bullet (`Docs/iOS-User-Manual.md:265`)
- **Current:** - A **Storage used** bar splits usage into XML and index, with a line saying how many volumes you hold and whether anything needs attention.
- **Proposed:** - A **Storage used** bar splits usage into XML, figure images and index, with a line saying how many volumes you hold and whether anything needs attention.
- **Why:** as for Mac §5.3 (#1516, `SettingsComponents.swift:69`; `FRUSExplorer/Settings/VolumesStorageHubView.swift:892` passes the figure). The bar has drawn Summaries and Vectors segments on iOS since before this lane, which this sentence does not name; that is not this lane's to change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §17.2 Volumes & Storage, the first sentence (`Docs/iOS-User-Manual.md:1263`)
- **Current:** Opens with a **Storage used** bar split into XML and index, and a status line.
- **Proposed:** Opens with a **Storage used** bar split into XML, figure images and index, and a status line.
- **Why:** as for iOS §5.3 (#1516). Lane STOR's entry above adds to the end of the same sentence; the two combine.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §12.9 Export, the paragraph after the bullets (`Docs/macOS-User-Manual.md:785`)
- **Current:** Exports always include the collection title and a linked table of contents, and each file is named after the collection.
- **Proposed:** Exports always include the collection title and a linked table of contents, and each file is named after the collection. A document's figures go with it: the PDF, Word and HTML exports carry each image inside the file, under its title and over its caption, scaled to the page. Such an export first fetches any image that is not on this Mac, for the documents it prints in full, if you are online; one it cannot get prints **[Figure]**. A film prints its title, where it has one, and the address of its page on history.state.gov.
- **Why:** #1516. A PDF, Word or HTML export asks for the absent images of its full-body documents before it prints (`fetchAbsentFigureImages`, `FRUSExplorer/Collections/CollectionContentResolver.swift:461`); the live preview does not, nor does a BibTeX, RIS or Zotero export, which prints none. PDF sets an image at two pixels to the point, never wider than the text column or taller than 560 pt (`figureDisplaySize`, `FRUSExplorer/Collections/PDFCollectionExporter.swift:1141`, drawn at `:1469`); Word stores it as `word/media/figureN.png` (`FRUSExplorer/Collections/DocxCollectionExporter.swift:1138`, `:1188`), and prints **[Figure]** for an image inside a footnote; HTML embeds it as a `data:` URL (`FRUSExplorer/Collections/CollectionItemHTMLRenderer.swift:326`). In Word and HTML the film's line is a link; in the PDF it is the address in print. Lane EXPORT's entry above rewrites this paragraph's later sentences; this adds one after its first.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §12.10 Export, the paragraph after the bullets (`Docs/iOS-User-Manual.md:952`)
- **Current:** After export, the system share sheet appears — save to Files, print, AirDrop, or send anywhere your device supports.
- **Proposed:** A document's figures go with it: the PDF, Word and HTML exports carry each image inside the file, under its title and over its caption, scaled to the page. Such an export first fetches any image that is not on your device, for the documents it prints in full, if you are online; one it cannot get prints **[Figure]**. A film prints its title, where it has one, and the address of its page on history.state.gov. After export, the system share sheet appears — save to Files, print, AirDrop, or send anywhere your device supports.
- **Why:** as for Mac §12.9 (#1516; the exporters are shared). Lane EXPORT's entry above changes the same paragraph; the two combine.
- **Owner:** ☐ approve ☐ edit ☐ reject

## PLAN — planning housekeeping (P3)

*Lane PLAN changed no code. These are manual sentences the 2026-09-27 planning audit found wrong or missing and that no lane's code change covers; each was re-read against the manuals and the tree at `origin/v2` dc17d945. The iOS ones overlap DOCS-2's whole re-read and are listed so that nothing depends on that lane rediscovering them.*

- **Manual / section:** iOS §6.1h Clusters, last paragraph (`Docs/iOS-User-Manual.md:387`)
- **Current:** Clusters are an **experimental, computed** view — the same "leads or noise?" question the semantic map asks. If a cluster's members read like a genuine research lead, that is worth knowing; if they read like an arbitrary pile, that is worth knowing too.
- **Proposed:** Clusters are an **experimental, computed** view: the groups come from how documents read, not from an editor's heading, and a cluster's label is a sample of its distinctive terms. Treat a cluster as a lead to check against its documents. About 28% of the corpus (89,449 documents) belongs to no cluster and cannot be reached here.
- **Why:** owner decision D-A (2026-09-10, `Planning/Completed/Plan-Of-Record-2026-09-06.md` §0): "No surface should any longer invite its own removal. The leads-or-noise framing is retired." This paragraph is the one place it survives; no app string carries it. The proposed limits are the ones Mac §6.1 already states, and 89,449 is `semantic-map-index.json`'s `layout.unclusteredCount` of 314,571 (28.4%).
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §8.5 Related Documents, the signal table's **Semantic similarity** row and the sentence under **Adjust weights** (`Docs/iOS-User-Manual.md:668`, `:676`)
- **Current:** | **Semantic similarity** | *Experimental, and off until you move its slider.* Documents whose language reads alike, whether or not they share words | … **Semantic similarity** is experimental and starts at zero; drag it above zero to include it.
- **Proposed:** | **Semantically similar (experimental)** | Language that reads alike, whether or not the words match. On by default at half weight — below the archival and citation signals, so it shapes the list without dominating it — and its slider moves it either way | … **Semantically similar** is experimental and on at half weight; its slider moves it either way.
- **Why:** owner decision D-D (2026-09-10) raised the default from 0 to 0.5: `SimilarityAxis.defaultWeight` returns `0.5` for `.semanticSimilarity` (`FRUSExplorer/RelatedDocuments/SimilarityModel.swift:218`), and the axis's label is "Semantically similar (experimental)" (`:121`). The proposed row is Mac §8.4's, word for word. *Similar wording* does start at zero (`.lexicalSimilarity`, `:219`), so its row is right as it stands.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §15.8 Exporting a Chart for Publication, the **Before you publish a figure alone** bullet (`Docs/iOS-User-Manual.md:1210`)
- **Current:** **Before you publish a figure alone**: the figure's caption strip is deliberately short, and the caveats that qualify the numbers — the dating rule, the fact that counts cover only the volumes indexed on *your* device, what a percentage is a percentage *of* — live in the CSV. The figure says so in small type at its foot. Submit the pair together; the CSV is where a referee finds your method.
- **Proposed:** **Before you publish a figure alone**: beneath the chart the figure prints its title, a line naming the scope, the year range and value mode where they apply, the app, and the date, and then, in small type, the same caveats the CSV's method block states — the dating rule, the fact that counts cover only the volumes indexed on *your* device, what a percentage is a percentage *of*, and the sources the numbers were drawn from — followed by the corpus credit and a line saying the underlying numbers are available as a CSV export with the full method statement. The numbers themselves are only in the CSV. Submit the pair together; the CSV is where a referee checks your figures.
- **Why:** false since GATE C (PR #1154, 2026-08-31): a plate prints every caveat the CSV prints, the Office of the Historian credit and a data pointer (`AnalyticsProvenance.plateLines`, `FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift:301`), the sources statement among them. The proposed text is Mac §15.8's bullet with "this Mac" changed to "your device". Lane EXPORT's entries for §15.8 are on the **What.** bullet and the last bullet, not this one.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.1 Corpus Analytics, the **Documents or Occurrences** bullet (`Docs/macOS-User-Manual.md:982`), and iOS §15.1, the same bullet (`Docs/iOS-User-Manual.md:1109`); and the pointer to it in §18.2 of each (`:1227`, `:1332`)
- **Current:** … The two can move in opposite directions, and the difference is a finding: searching `"Article 43"`, documents fall from 34 in 1948 to 11 in 1949 while occurrences *rise* from 77 to 92 — a single 1949 document discusses it 54 times. … The picker is disabled **with a stated reason** wherever no honest count exists — exact-word (`=`) searches, phrases, wildcards, proximity queries, multi-term comparisons …
- **Proposed:** *(no figures offered)* … The two can move in opposite directions, and the difference is a finding: a term can appear in fewer documents in one year than the last while its occurrences rise, because one long document discusses it many times. … — and in §18.2, "(15.1 explains the difference)" in place of "(the `"Article 43"` example in 15.1 is the cautionary tale)".
- **Why:** the example contradicts its own paragraph: `"Article 43"` is a phrase search, and the next sentence says the Measure picker is disabled for phrases. The figures also predate #1340, which changed what the bars count under Occurrences. **A measured one-word example would be better than none, and this lane could not measure one**: it needs a full index. PR #1340 listed it as an owner step.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §10.2 Creating a Project (`Docs/macOS-User-Manual.md:599`)
- **Current:** A project created by an earlier version's onboarding may still carry one: it is shown on Project Home as *From … Through …* and pre-fills the Search date filter, and it cannot be edited.
- **Proposed:** A project created by an earlier version's onboarding may still carry one: it is shown on Project Home as *From … Through …* and cannot be edited. On the Mac it changes no search; on iPhone and iPad it pre-fills the Search tab's date filter.
- **Why:** only the iOS Search tab applies a project's date range (`SearchViewModel.applyProjectDefaults`, called from `FRUSExplorer/Search/SearchView.swift:865`); the Mac Search window's model never reads it (no `defaultDateRange` or `applyProjectDefaults` in `FRUSExplorer/App/MacSearchViewModel.swift` or `FRUSExplorer/App/SearchSheet.swift`). Read from the code, not checked in the running Mac app.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §7.11 Search by Meaning (Experimental), after its second paragraph (`Docs/macOS-User-Manual.md:465`)
- **Current:** *(no such sentence)*
- **Proposed:** *(add)* Like every semantic surface it is **experimental**: its quality on nineteenth-century material is not yet established, and a phrase whose exact wording is the point ("persona non grata") is better served by a keyword search.
- **Why:** parity. iOS §7.12 carries this caveat (`Docs/iOS-User-Manual.md:584`) and the Mac section does not; the evaluation behind it is `Planning/semantic-vectors/eval-2026-08-27/VERDICT.md`, and the early-era question is still open (no pre-1900 quality measurement exists). The in-app strip (`search.meaning.strip.base`) says neither thing; that is copy for the owner's EditableContent pass, not a manual change.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §5.3a Semantic Vectors and the Search Model (`Docs/macOS-User-Manual.md:265`), and iOS §5.3 Managing Storage, where the iOS manual has no vectors section yet (`Docs/iOS-User-Manual.md:261`)
- **Current:** *(no such sentence)*
- **Proposed:** *(add)* The vectors, the semantic map and its regions are made when the app is built. If the Office of the Historian corrects a volume and you update your copy, your text is the corrected one at once, but Related Documents' semantic matches, search by meaning and the map go on describing the earlier text of that volume until the next app update.
- **Why:** `Planning/New-Volume-Release-Plan.md` §13 names this window and says it "cannot be fixed, only disclosed"; nothing discloses it. The bundled index, binary and map are app resources, while a volume's text is downloaded live (`VolumeUpdateChecker`). A shard whose document count changed is refused and re-fetched (`settings.vectors.error.rejected.v2`), but a correction that keeps the count is scored from the old vectors until a release re-publishes the shard. The wording is new and is the owner's to set.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** iOS §5.3 Managing Storage, the **Free Up Space…** bullet (`Docs/iOS-User-Manual.md:266`)
- **Current:** **Free Up Space…** lists only volumes with nothing of yours attached — no notes, highlights, or tags — ordered by what you would recover, and asks before removing anything.
- **Proposed:** **Free Up Space…** lists only volumes with no research notes, collection entries, or summaries attached and that the app can download again (a side-loaded volume is never offered; highlights and tags do not keep a volume off the list, and they survive its removal like the rest of your work), ordered by what you would recover, and asks before removing anything.
- **Why:** the list is wrong: the sheet's own empty state says "Every volume has notes, collections, or summaries attached." (`FRUSExplorer/Settings/VolumesStorageHubView.swift:665`), and Mac §5.3 already states the rule this way. The ordering clause is left as iOS has it; lane STOR's entry on the same item (iOS §17.2) adds that the rows are dimmed while it removes.
- **Owner:** ☐ approve ☐ edit ☐ reject

- **Manual / section:** Mac §15.6 Semantic Analytics, the **Color by** bullet (`Docs/macOS-User-Manual.md:1065`), and iOS §15.6, the same bullet (`Docs/iOS-User-Manual.md:1184`) — **wait for the caption fix**
- **Current (Mac):** … with its caveat stated under the lens: a plurality, not a majority, for 73 of the 499 volumes it colors; volumes with fewer than ten notes, and the 30 the aggregate does not cover, take the gray **Too few source notes** color rather than a guess.
- **Current (iOS):** … with carefully stated caveats: it is a volume-level plurality (for 73 of 522 covered volumes the winner holds under half the notes), 55 volumes are "won" by *Other/Unclassified* (meaning the parser could not classify their notes), and volumes resting on ten notes or fewer take their own gray *Too few source notes* color rather than being folded in.
- **Proposed:** Mac: the same sentence with the count the corrected caption gives (75 today). iOS: the Mac's sentence, which also corrects "ten notes or fewer" (the floor is fewer than ten) and drops the two figures the caption does not state.
- **Why:** the Mac sentence quotes the lens caption, `semanticMap.lens.provenance.caption.v2` (`FRUSExplorer/Semantic/Map/SemanticMapLens.swift:100`), and that caption is itself out of date: recomputed from `source-provenance-index.json` as lane NOTE regenerated it on 2026-10-01, the winner holds under half the notes in **75** of the 499 colored volumes, not 73 (`frus1961-63v03` and `frus1961-63v21` joined). The caption is a code string and was not changed by this lane; it is listed in the plan of record's "Not placed" note. Change the manuals when it is fixed, to whatever it then says.
- **Owner:** ☐ approve ☐ edit ☐ reject

## OH — #1309 report (P4)

*Lane OH compiled the report to the Office of the Historian (`Planning/OH-Report-2026-10-01.md`). It changes no app behaviour and no app copy, so it makes no manual change necessary. Both manuals were searched for statements the report bears on; the two that touch it stay true as written:*

- *Mac §8.2 and iOS §8.2, cross-references that cannot be followed (`Docs/macOS-User-Manual.md:508`, `Docs/iOS-User-Manual.md:640`): "occasionally … cites a page, document, or volume that does not exist in the digital corpus." The report finds that 352 of the 652 such references point at pages missing from one file, `frus1952-54v09p1`, and 8 at volumes not yet digitized. The sentence covers both.*
- *Mac §17.5 and iOS §17.6, **Reports → Broken Cross-References** (`Docs/macOS-User-Manual.md:1196`, `Docs/iOS-User-Manual.md:1301`): the export is unchanged. The bundled index was not regenerated (the regenerated CSV is byte-identical to the committed one).*

**No entry for the owner to approve.** If the Office of the Historian restores `frus1952-54v09p1`'s Documents 900–946, the count the app shows falls by 352 at the next corpus refresh; neither manual states a count.
