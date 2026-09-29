# Plan of record — from 2026-09-28

**Base:** `v2` @ `07b9b65c` · build 48 shipped 2026-09-27 (tag `build-48` = `d61b53f9`) · index **v62** · rollup **v10**. One PR is open: **#1533**, the docs-only prep for the owner's review.

**Scope.** 49 issues are open. #234 is deferred indefinitely, and #1309 is used only to hold the report to the Office of the Historian. This plan covers the other **47**.

**Status: LIVE — the plan of record from 2026-09-28** (owner decision P5). It supersedes `Plan-Of-Record-2026-09-06.md`. The owner answered every decision in §3 and §3a on 2026-09-28, and §0 gives the result. No lane has started: the plan starts once the owner hands back the revised `Docs/EditableContent/` and has usage for it (P1, P2).

§7 struck: 0, 1, 2, 3, 4, 6, 7, 8, 9, 11, 14. (This is the Visual-Marketing-Plan §7 steps that are done, carried unchanged from the 2026-09-06 plan and checked by `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan`.)

**How the plan was made.** Two read-only workflows ran on 2026-09-27:
- **Open-issue triage (12 agents).** Every verdict went to an independent skeptic, and all 47 were upheld.
- **Planning and docs audit (39 agents).** It swept 12 groups of planning documents, 6 docs-readiness areas and the OH report, each checked by a skeptic, plus a completeness critic.

The raw results are in the session's durable folder, `…/8b45e6f9-…/durable/plan/`:
- `triage-merged.json` — the issue verdicts;
- `plan-items.json` — 714 planning items;
- `docs-digest.txt` — the docs-readiness findings;
- `w2-result.json` — the whole audit.

**Sizes.** S is half a day, M one to two days, L three days or more, tests included.

---

## 0. Decisions resolved 2026-09-28 — read this first

The owner's answers, as they bind the lanes. §3 and §3a keep the original options and the owner's inline notes. Where the two differ, this section wins.

**Process**
- **P1 — scope is flexible.** Lanes run tier by tier. After each tier lands, the owner decides whether to continue, based on usage.
- **P2 — order and manuals.**
  - **Lane WB goes first.** The owner finishes the `Docs/EditableContent/` review before the plan starts. WB writes those revisions into the app, so every later lane works from the revised text.
  - **The owner's Mac manual review lands after Tier 2.** Until the owner hands it back, **no lane edits `Docs/macOS-User-Manual.md` or `Docs/iOS-User-Manual.md`.** Each lane writes its proposed manual changes into `Planning/Manual-Revisions-Pending.md`, under its own lane heading, giving:
    - the manual and section;
    - the current sentence;
    - the proposed sentence;
    - why, with the code path.
  - That keeps the owner's diff clean, and lets the owner review Claude's proposals separately. After the hand-back, one docs lane applies the approved proposals to the owner's version. The iOS items feed DOCS-2.
- **P3 — every fold-in.**
  - every ◦ item in §2's table;
  - planning housekeeping (lane PLAN);
  - the release-gating measurements;
  - the #1309 report (lane OH).
- **P4 — one post for the OH report.** A single post is fine if each defect class is clearly documented within it.
- **P5 — this file is the plan of record.** `Plan-Of-Record-2026-09-06.md` is marked SUPERSEDED.
- **P6 — the EditableContent range gate stays exact.** `EditableContentKeyTests.everyRangedBlockHoldsItsKey` is kept.

**Behaviour, by lane**
- **PAGE — D1 / #1510:**
  - Stop indexing heading-only containers, limited to compilation, chapter and subchapter. The 7 appendix and historical-document containers stay.
  - Keep the 32 Parisv13 containers that carry their own text indexed for that text, with their page span narrowed to their own page breaks.
  - A dropped container's page breaks go to the section that begins after them.
  - The two side gaps are filed as #1535 (Browse cannot open prose-only sections) and #1536 (container-level text is discarded). They are in scope for this wave only if P1 allows; they are not required for #1510.
- **NOTE — D2 / #1514:** **wide.** Re-route the Electronic Reading Room notes and the non-central Department series (INR/IL, INR-NIE and the like), about 450 notes. This moves `source-provenance-index.json`, so regenerate it and any artifact that reads the changed categories, following CLAUDE.md's generator run order.
- **READ — D3 / #1516: option (f)4, download figure images with their volume.**
  - Images are fetched with the volume from `https://static.history.state.gov/frus/<volume>/<file>.png`.
  - They are kept beside the XML, shown in the reader, and embedded in PDF and Word. Volume removal deletes them, and Volumes & Storage counts them.
  - Only figure images are fetched, never page scans.
  - This settles the other sub-choices as follows. The owner asked whether (f) supersedes them; these are Claude's recommendations, to be confirmed in the lane's PR review:
    - (a) a figure's paragraphs render as **captions under the image** (no re-index);
    - (b) **"[Figure]"** remains only as the fallback when the image is not on the device (before its download finishes, or after a failure);
    - (c) an empty `<figure/>` prints **nothing**, as on history.state.gov;
    - (d) no "Figure:" marker, because the image makes one unnecessary;
    - (e) superseded.
  - The 20 embedded videos in the three PubDip volumes cannot be downloaded (Brightcove), so they get a **"Watch on history.state.gov ↗"** link and their head ("Reel 1") as the caption.
- **EXPORT — D4 / #1465:**
  - The preview shows an untitled heading as **"Untitled section"**, and exports drop it.
  - It is dropped whether or not documents sit under it.
  - A named sub-heading under a dropped heading moves up one level.
  - The editor row keeps its "Section heading" prompt.
- **MACCOL — D5 / #1493:** an unnumbered document reads **"Unnumbered (d710a-1)"**.
- **CITE:**
  - **D6 / #1504:** delete the nearest-document strategy, the manifest's `documentCount` field, and the OpenAPI text about it (:2429).
  - **D7 / #1523:** refuse side-loaded volumes in Citation Lookup and Add Documents. When a volume is side-loaded, tell the reader that side-loaded volumes are not included in features that rely on bundled publication data. That is new copy, with its EditableContent block.
  - **D17 / #1506:** hide Parsed Fields in Batch mode, and give best guesses their own bucket in the Batch summary.
- **GRAPH:**
  - **D8 / #1517:** the owner confirmed on Mac and iPhone that a click or tap on empty canvas clears nothing, and that is acceptable. The lane still checks, and fixes if broken, whether drag-to-pan and double-click-to-reset can start on empty canvas. It does not change what a click clears.
  - **D9 / #1481:** in-app text must describe the controls that exist. The wording comes from the owner's EditableContent pass (WB); GRAPH makes the per-platform key and any relabel.
- **ARCH:**
  - **D10 / #1438:** a fallback label slot above the node.
  - **D11 / #1468:** do both. Apply the display-name rule only to names over 100 characters that have a printed `<hi>` title (11 names change). Exempt the full-text alias from the 12-alias cap, so "Indexed Central Files" keeps its paragraph. Regenerate `collection-authority.json` and its successors in CLAUDE.md's run order. The 271 remaining long names are left to the layout fix, which caps the card heading, puts the full name in `.help` and accessibility, and moves the buttons above the detail.
  - **D12 / #1470:** reserve the captions' space in the layout, paired with #1438's obstacle seeding.
- **SYNC — D13 / #1531:** the lane exactly as §2 describes it. There is **no retry control**. Debug builds get their own store file, and Fix iCloud Sync gets a warning. The outage itself ended with the owner's Production schema deploy on 2026-09-28.
- **Closed or settled:**
  - **D14:** #1430 is closed.
  - **D15 / #1484:** delete `PromptsListView` (HYG).
  - **D16 / #1497:** an unnamed collection sent to Zotero is named **"FRUS Explorer Collection - yyyy-mm-dd"**. This applies to the Zotero send only; exports keep "Untitled Collection".

**Issues filed after the plan (2026-09-29), placed here** (triage and skeptic: `…/durable/plan/newissues/triage-1538-1540.json`)
- **#1538 → lane STOR, Tier 1** (Mac: the research-database export fails on every attempt). This Mac's system log settles the cause. The save panel's sandbox grant covers only the chosen file, but `IndexDatabaseExporter.export` opens SQLite directly on that URL, and `sqlite3_backup` must then create `<file>-journal` beside it. The sandbox refuses that: "Operation not permitted", reported as "unable to open database file". It has been broken since build 45, and each failure also leaves a 0-byte file at the destination.
  - **Fix (S):** build, strip, verify and stamp the copy in a staging directory (`itemReplacementDirectory` or the container's temporary directory), then move it to the chosen URL. Nothing is created at the destination until the copy verifies. The unit tests missed it because they write into the temporary directory, so the new test must pin that no connection opens in the destination's folder.
  - **Check:** by eye on the Mac. Export to `~/Downloads` with the toggle on and again with it off, then open each copy with `sqlite3`.
- **#1539 → new lane LANG, Tier 1** (iPhone and iPad on iOS 27: Collocates refuses for want of lemmas).
  - **What it disables:** that process's language-analysis verdict also withholds Word Cloud Distinctive (keyness) on every lens, Related's shared-word chips, dictionary-form counting in the clouds (they read "Counted as printed"), and the word cloud in collection exports. Mac is unaffected.
  - **Cause:** the verdict is computed once per process at launch (`NaturalLanguageReadiness`), under one shared 30 s asset-request budget, and never re-checked. On a physical device a background launch (CloudKit push, background processing), or a request still in flight when the canary runs, can fix a failed verdict for the life of the process. Not yet measured on hardware.
  - **Lane, steps A–C:**
    - (A) log the warm-up record in release builds, and show the verdict in a Settings row;
    - (B) re-request assets and re-run the canary on the next foreground when a capability is missing, adopting a better verdict;
    - (C) do not start the warm-up in a background launch, and keep the verdict pending rather than tag while a request is in flight.
  - **A fallback (D) only by owner decision (below):** a reference counted as printed. It is exact, but splits "missile" and "missiles" into separate collocates.
  - Runs after SYNC, since both touch `FRUSExplorerApp.swift`.
- **#1540 → lane SEL, new and split from READ, Tier 2** (iOS reader: the system edit menu covers the app's floating selection bar).
  - **Cause:** the bar always anchors below the selection (`DocumentView.swift`), on the Research-rail decision D3 (2026-07-18) that UIKit puts the edit menu above it. UIKit also puts it below, as your screenshot shows, and the bar flips above near the bottom edge, onto the menu's usual spot. The app has no `buildMenu` hook, so it neither knows nor controls where the menu goes.
  - iPad runs the same code path (inferred, not measured). The Mac is unaffected.
  - **The design is an owner decision (below).** In every option the app's "Look Up" becomes "Look Up in NARA", since the system menu has its own Look Up.
- **Decisions these add:**
  - **#1540:**
    - (a) **put the app's actions (the colours, Excerpt, Look Up in NARA, Note) at the start of the system edit menu, and retire the iOS bar** (recommended: native for VoiceOver, Voice Control and keyboard; the pre-July reader did this);
    - (b) dock the bar at the reader's bottom edge;
    - (c) suppress the system menu (worst for accessibility: it drops Speak, Translate, Share and Writing Tools).
  - **#1539:** whether the printed-form fallback (D) is acceptable if steps A–C do not recover the lemmatiser on hardware. The refusal's wording ("Quitting and reopening … may restore it") is settled once the device cause is known.
- **Resolved 2026-09-29 (owner):**
  - **#1540: option (a).** The app's actions go at the start of the iOS system edit menu: the four highlight colours, Excerpt, Look Up in NARA and Note. The iOS floating selection bar is retired, and the Mac keeps its bar. The app's "Look Up" becomes "Look Up in NARA" on every platform.
  - **#1539: the printed-form fallback (D) is approved,** provided users are told. Wherever a surface falls back to comparing printed forms (Collocates, Word Cloud Distinctive, Related's shared-word chips, the clouds' counts), it must say so on screen and explain why. It must also say that results can differ from a device whose language analysis reduces words to their dictionary forms: a Mac, or another iPhone or iPad.
    - LANG builds steps A–C first. Then it adds D: a reference counted as printed, from `CloudVectorsGenerator`'s same NLTagger pass, and the comparison against it, flagged per surface.
    - The flag and the explanation are new copy, with EditableContent blocks. The manual text for them goes to `Planning/Manual-Revisions-Pending.md` (P2).
    - D is a regeneration (`cloud-vectors-core.json` and `keyness-baseline.json` come out of one `pack()`), about an hour of generator time.
- **Owner diagnostics for #1539** (optional, but they would decide whether step D is needed). On each iOS device:
  - force-quit FRUS Explorer, reopen it on Wi-Fi with the screen on, wait 60 s, then run Search "missile" ▸ Collocates, three times;
  - note Wi-Fi or cellular, and whether the Word Cloud header says "Counted as printed";
  - if possible, stream Console.app from the cabled device during one launch.

**Lane order**
1. **WB** — needs the owner's EditableContent hand-back.
2. **Tier 1:** STOR (with #1538), PAGE (index v63), NOTE (v64), SYNC, LANG (#1539, after SYNC).
3. **Tier 2:** EXPORT, MACCOL, SEL (#1540), GRAPH, ARCH (after GRAPH), CITE, XREF.
4. **Tier 3:** READ, HYG, PLAN, OH, then MANUALS (apply the approved pending manual revisions after the owner's Mac hand-back) and DOCS-2 (the iOS manual).

The release (build 49, one re-index) follows the tiers the owner chooses to land. The staged launch files are listed in the plan's session entry in `Planning/DEVELOPMENT-PLAN.md`.

---

## 1. Where the 47 issues stand

- **Four show users wrong data.**
  - #1509: a "p. N" reference goes to the first of several documents beginning on that page. At least 1,825 of these are wrong.
  - #1514: about 30 source notes are filed as RG 59 central files when they are not.
  - #1526: after Rebuild Index the app treats nothing as indexed until relaunch. Related Documents goes empty, every Meaning hit reads "not downloaded", and on the Mac a wrong count is synced into saved searches. After build 48's boot re-index the count also reads one too high until relaunch.
  - #1526's counting half is the fourth.
- **None is fixed**, and none is a full feature break.
- **The rest:** 30 are layout or wording problems (degraded UI), and 12 are dev-only (tests, generators, dead code).
- **#1531 (iCloud sync after the update).**
  - The code rules out the re-index: the index is a separate SQLite file and writes nothing to the synced store.
  - It also rules out the CloudKit schema: nothing changed and nothing awaits deploy.
  - The likeliest cause is new in build 48: each device rewrites the four standard summary prompts at first launch, before it has imported the others' rewrites.
  - Sync logs from all three devices would settle it.
  - One real hazard: **Fix iCloud Sync** promises "nothing is lost", but it discards changes that have not been uploaded yet.
- **Eight issues are wording-only.** They are now ⚑ items in `Docs/EditableContent.md` (PR #1533): #1422, #1464, #1476, #1478, #1481, #1483, #1527, and #1531's copy. The owner's revisions settle them, and one write-back PR (lane **WB**) closes them.

## 2. Lanes

Each lane is one PR. Lanes land through the serial merge queue (`.claude/workflows/`): at most **three** building at once, and only the head of the queue gets its final merge of `v2`.

| Lane | Issues | Fold-ins from the planning audit (optional, marked ◦) | Size | Re-index | Checks |
|---|---|---|---|---|---|
| **STOR** | #1526, #1432, #1476, **#1538** (Mac research-database export; stage the copy, then move it) | ◦ The side-loaded volume's Remove confirmation prints `**` literally. ◦ Side-loaded volumes are not reconciled at boot. | M | — | VolumeRemovalTests on iPhone + iPad; Mac by eye |
| **PAGE** | #1509, #1510, #1511 | ◦ 29 persons-list "until <event>" entries misread as start years | L | **v63** | page-citation replica (`tools/page-citations`) |
| **NOTE** | #1514, #1515, #1404 | ◦ Subject-Numeric title-case designators (`Def 12 NATO`). ◦ Library-heading rows with no repository. ◦ The pre-1906 "department of state" cue. ◦ The packet crib's example choice. ◦ The divided-lot denominator. | M–L | **v64** | mirror-gated parity test |
| **SYNC** | #1531 (**sync-broken**; the outage itself was ended 2026-09-28 by the owner's Production schema deploy of `CD_GeneratedSummary.CD_sourceContentHash`, verified on the Mac in the system log and on the iPhone by its Sync Log) | Lane scope (§3a D13): (1) install the sync-event observer before the container starts, so a launch's first failure is always recorded; (2) remember a failed export with no success since across launches, with the banner "Sync stopped on this device; your changes are kept here", never quiet and never promising a retry; (3) after a failed event, read the process's own system log (`OSLogStore`) through the existing `CD_…` allow-list, so the Sync Log names the record type and field; (4) honest Fix iCloud Sync copy ("changes not yet in iCloud are discarded"), with a warning while an export is unrecovered; (5) no retry that forces a sync, at most a read-only **Check Again**; (6) a release gate: diff `xcrun cktool export-schema --environment production` against `CloudKitSchemaInventory.installedIdentifiers` before archiving (needs a management token on this Mac), and correct the inventory's 09-03 attestation note; (7) Debug builds get their own store file, so a Development session can never again expire the shipped app's Production change token, and each Sync Log row records the build configuration. ◦ A project deleted on another device leaves `activeProjectId` dangling. | M | — | Mac + iPhone with the system log; a Development-device A/B with an unpublished field |
| **LANG** | #1539 (iOS 27 devices: no lemmas, so Collocates, keyness, shared-word chips and dictionary-form clouds are withheld) | Steps A–C (release warm-up log plus a Settings row; re-check on foreground; no warm-up in background launches, no tagging while a request is in flight), then **D (approved 2026-09-29)**: a printed-form reference and fallback, flagged on every surface that uses it, with the cross-platform difference explained | M–L (D regenerates the cloud artifacts) | — | the owner's devices (force-quit and reopen ×3, optional Console stream); the simulator's 1-in-4 loss as the control |
| **SEL** | #1540 (the iOS edit menu covers the floating selection bar) | **(a), owner decision 2026-09-29:** the app's actions go at the start of the iOS system edit menu, and the iOS bar is retired. "Look Up" becomes "Look Up in NARA" | M | — | iPhone and iPad by eye: drag the lower handle, and select near the bottom edge; VoiceOver on the menu |
| **EXPORT** | #1465, #1496, #1497, #1498, #1464 (code) | ◦ A `.fruscollection` import leaves its notes unindexed until relaunch. ◦ Add to Collection's search and the rail's sort read the raw name. ◦ The analytics export file name has no 255-byte cap. | M | — | Word/PDF/HTML by eye |
| **MACCOL** | #1446, #1448, #1449, #1477, #1493, #1475 | ◦ **Mac Collections detail pane: seven handlers each save all seven fields from stale copies, so a rename made elsewhere can be overwritten** (#1413's shape on the Mac). ◦ Section defaults save each write. | M–L | — | Mac by eye (`tools/mac-check-copy`) |
| **GRAPH** | #1434, #1517, #1518, #1481 (behaviour) | — | M | — | Mac + iPad by eye |
| **ARCH** | #1437, #1438, #1468, #1470 | — | M–L | — | after GRAPH (shared `GraphNodeLabels.place`) |
| **CITE** | #1504, #1506, #1523, #1524, #1491 | — | M | — | round-trip measurement |
| **XREF** | #1472, #1473 | ◦ The phone matrix label breaks mid-word. | S | — | Mac window at its 720 pt minimum |
| **WB** | the eight wording issues plus the ✎ edits the owner adopts | — | M | — | when the owner hands EditableContent back |
| **READ** | #1516 | ◦ The reader drops the space between two inline elements (`Washington,February 28, 1861`). | M | only if D3 = text | — |
| **HYG** | #1412, #1439, #1423, #1450, #1484 | ◦ `SemanticVectorsGenerator` still defaults `DIMS` to 256 (the bundle ships 512). ◦ `PROJECT_ONLY=1` with no raw store rewrites the committed artifacts. ◦ Dead code: `GlobalContextView`, `splitLayout`, `SubseriesListView`, the four-argument `updateNoteText`. ◦ The UI-test license-header scan. ◦ The Mac toolbar tooltip says ⌘F (it is ⌥⌘F). | S–M | — | — |
| **DOCS-2** | iOS manual: a whole re-read, parity with the Mac manual, and the owner's Mac edits ported in | — | L | — | after the owner hands back the Mac manual |

**#1430** is recommended to close (see D14).

**Suggested run groups** (three concurrent dev runs; each runs its lanes one after another):
- **A (index path):** PAGE → NOTE → READ.
- **B (state and Collections):** STOR → SYNC → EXPORT → MACCOL.
- **C (canvases and citations):** GRAPH → ARCH → CITE → XREF → HYG.

**Landing order** follows readiness, with wrong-data lanes first: STOR, PAGE, NOTE, SYNC, then the rest. Each index lane takes the next version at its landing.

**Release.** Build 49 ships once Tier 1 and Tier 2 have merged, with **one re-index** (v62 → v64). Before it:
- the full unit target on iOS 27;
- the build-48 UI suites that were measured only on iOS 26 (`CollectionEditorTitleTests`, `BrowseWithinScopeTests`);
- one full re-index census on a pinned device;
- the window-fronting audit;
- `check_repository_links.py --stamp`;
- the Gemma policy re-check;
- TestFlight notes, with fixes on one line.

**Tiers.**
- **Tier 1 (this week):** STOR, PAGE, NOTE, SYNC.
- **Tier 2:** EXPORT, MACCOL, GRAPH, ARCH, CITE, XREF, WB.
- **Tier 3:** READ, HYG, DOCS-2.

## 3. Owner decisions

Recommendations are in **bold**.

**Behaviour, needed before a lane starts:**
- **D1. #1510 heading-only containers** (lane PAGE): **drop them from the index**, or keep them and exclude them only from page answers. Dropping takes about 170 heading-only pseudo-documents out of search results and document counts, across about 80 volumes (an estimate).
- d1 decision - compare with history.state.gov handling. if container-level URLs are resolvable to document lists there, they should be treated like compilation or chapter segments in other volumes. if they are handled differently, come back to me with a description so i can decide whether the app should pursue parity with the Office of the Historian or resolve differently
- **D2. #1514 scope** (lane NOTE): **narrow — about 30 notes (Reading Room telcons, Nixon materials, OAS/USUN lots)**, or wide — about 450 notes, re-routing the INR series too. Wide moves the provenance counts and the generator chain, so it would be its own issue.
- d2 decision wide
- **D3. #1516 figures** (lane READ):
  - A figure's paragraphs render as **captions (no re-index)** or as document text (re-index).
  - A figure that is only a graphic prints **nothing** or "[Figure]".
  - d3 decisions require more context. show me a range of examples based on representative examples from FRUS figures
- **D4. #1465 an empty Section heading:** **left out of the preview and every export**, or printed as "Untitled section".
- d4 decision - would it be feasible to display as "untitled section" in preview (to provide a visual cue to users that they created it but haven't completed it) but omit from exports (to avoid value-less clutter)?
- **D5. #1493 an unnumbered document (d710a-1) in a list token or Mac row:**
  - **"the unnumbered document following Document 710"**;
  - its heading;
  - "Unnumbered (d710a-1)";
  - leave it and close.
- d5 decision use the "Unnumbered (id)" pattern
- **D6. #1504 the nearest-document strategy:** **delete it** (the manual row is already gone in #1533), or wire it from `document_cache`.
- d6 decision - if there is no other current or planned consumer for the manifest's per-volume document count, then delete it. if there is, or will be, another consumer, wire it.
- **D7. #1523 side-loaded volumes in Citation Lookup and Add Documents:** **resolve them**, or keep refusing them (the Mac manual now documents the refusal).
- d7 decision - refuse them. when a user adds a sideloaded volume, the app should inform them that volumes added with this method are not included in features that rely on bundled publication data
- **D8. #1517 document graph:**
  - A click on empty canvas clears **both the pinned node and the pinned edge**, or only one of them.
  - **No canvas change** on the iOS volume sheet.
- d8 decision on-device testing on Mac and iPhone confirm that tapping or clicking on empty space in the cross-reference graph does not clear node or edge. this is fine.
- **D9. #1481 the iOS graph node action:** **relabel it to what it does**, or hand the document to the main window and close the sheet.
- d9 decision - ensure in-app text describes existing UI and controls
- **D10. #1438 small-canvas labels:**
  - **a fallback label slot above the node** (this also answers the older decision "allow a second label place above a node");
  - shorter labels;
  - a larger minimum canvas;
  - accept the sparseness.
- d10 decision - use fallback label slot above the node
- **D11. #1468 an overlong collection name** (the 2,150-character "Indexed Central Files"): **fix the layout only**, or also change the authority's display-name rule, which means regenerating the data.
- d11 decision - test both data and layout fix. measure how many collections would lose long form name under cappedAliases limit
- **D12. #1470 custodian captions:** **reserve their space in the layout** (pairs with #1438), or draw them last on a plate.
- d12 decision - pair with 1438 decision
- **D13. #1531 retry control:**
  - **No button now.** The banner says iCloud retries on its own, Fix iCloud Sync warns honestly, and the first-launch prompt refresh waits until after import.
  - Or add a Try Again, or both.
  - **Please also export the sync log from all three devices.**
- d13 decision - remind me to provide logs (staged separately). add a retry control unless this would create risks of undesired behavior
- **D14. #1430:** **close it** (you accepted the loss on 09-24), or keep it open.
- d14 decision - close it
- **D15. #1484 `PromptsListView`:** **delete it**, or wire it in.
- d15 decision - delete it
- **D16. #1497 an unnamed collection sent to Zotero:** **create "Untitled Collection"**, or send the items loose.
- d16 decision - if a collection is unnamed, use "FRUS Explorer Collection - yyyy-mm-dd" placeholder default
- **D17. #1506 Batch summary:** **keep counting best guesses under "ambiguous"** (just hide Parsed Fields), or give best guesses their own bucket.
- d17 decision - hide parsed fields and give best guesses their own bucket

**Process:**
- **P1. Scope of this wave:** **Tiers 1 and 2 before build 49; Tier 3 after**, or all 47 now.
p1 decision - keep scope flexible so i can decide based on usage availability as each tier lands.
- **P2. Coordination while you revise:** **lanes do not edit the manuals or EditableContent block text**. They re-point `lines:` ranges only, and record their manual changes in the PR body. I merge your hand-back by key.
p2 decision - assume that editable content review will be complete before plan starts. make merging those revisions into the app the first task so subsequent tasks work from the revised baseline. assume that mac user manual review will be complete after tier 2. track your mac manual revisions between plan start and my handoff of owner revisions to the now-current version separately so a) the owner revision diff is clean and b) i can review your proposed revisions separately.
- **P3. Fold-ins from the planning audit:**
  - (a) **the ◦ items in §2's table**;
  - (b) **planning housekeeping**: supersede the plan of record, archive about 10 completed plans to `Planning/Completed/`, fix the stale document headers, and refresh the Agentic guide's artifact table and its duplicate 1.21 entry;
  - (c) **the release-gating measurements** in §2;
  - (d) **the #1309 report compile** (§5).
  - Park §4's bigger features.
p3 decision - yes to all
- **P4. The OH report channel:** **one consolidated comment in #1309, then one issue on HistoryAtState/frus with the CSVs attached, which you post**. Or post per defect class.
-p4 decision - as long as the reports are clearly documented, they can share a single post
- **P5. Plan of record:** **make this plan the plan of record** (supersede 09-06), or keep it a proposal.
p5 decision - make this plan the plan of record
- **P6. #1424's EditableContent range gate:** **keep it exact**, or make the ranges advisory.
p6 - keep exact

## 3a. Follow-up research on your decisions (2026-09-28)

Six decisions needed facts first. One read-only workflow researched them; a skeptic re-checked D1 and D13, and both conclusions held. Full results: `…/durable/plan/decision-research.json`.

**D13 / #1531 — iCloud sync is stopped, and the cause is a Production schema field, not build 48.** Confirmed in this Mac's system log (09-27 and again 09-28 13:38 local):
- CloudKit Production rejects `CD_GeneratedSummary.CD_sourceContentHash` with "Cannot create or modify field … in production schema".
- `SummarizationService` has written that field on every summary of an indexed document since build 45. `CloudKitSchemaInventory` says it was deployed on 09-03; the server says otherwise.
- Core Data treats the rejection as fatal. It resets, refuses every sync request for the rest of the session, and fails the same way about 1.3 s into each later launch. It stops **both directions**, not only the upload.
- The app misses the later failures because its event observer is installed after the container starts. That is why your logs show only "zone ok" since 09-27: on the iPhone, 0 of 17 launches had a sync event, against 31 of 39 before.
- A Debug build (it talks to CloudKit Development but shares the shipped app's store) ran on the Mac at 02:20 on 09-27. It expired the Production change token, which forced the full re-upload that hit the bad field.
- **Owner step, now; it fixes every user without an app update:**
  - In CloudKit Console, confirm Development's `CD_GeneratedSummary` has `CD_sourceContentHash`. Add it by hand there if not. Do NOT use a Debug Mac build to create it, since that is what set this off.
  - Read the whole Development → Production diff.
  - Deploy Schema Changes to Production.
  - Do **not** press Fix iCloud Sync on any device first: it would discard changes that never uploaded.
  - Afterwards, verify on the Mac with `/usr/bin/log show` ("Finished export", no "Export failed"). The Sync Log can miss the first export for the same observer reason.
- **Your retry control: not recommended.** No variant can sync through this failure. The ones that act at all risk duplicates, conflicts, a crash, or hiding the outage. The only safe control is a read-only **Check Again** that re-reads the status.
- **Lane SYNC is re-scoped (M):**
  - install the event observer before the container starts;
  - remember a failed export across launches, with the banner "Sync stopped on this device; your changes are kept here";
  - read the process's own system log after a failure, so the Sync Log names the record type and field;
  - honest Fix iCloud Sync copy, with a warning while an export is unrecovered;
  - put the field back into `identifiersAwaitingDeploy` until the deploy is confirmed;
  - a release gate that diffs `cktool export-schema --environment production` against the inventory (needs a CloudKit management token saved on this Mac);
  - give Debug builds their own store file.
  - Deferring the prompt refresh is optional: nothing implicates it.
- **#1531 is sync-broken, not degraded UI.** Any tester on builds 45–48 who summarises an indexed document stops syncing.
- **Choices left:**
  - no control, or a read-only Check Again;
  - Debug builds get a separate store file or a separate bundle ID;
  - Fix iCloud Sync: warn only, or disabled while an export is unrecovered;
  - whether to confirm the iPhone's cause (Console stream, or CloudKit Console logs). The iPhone's own log suggests its exposure may start on 09-14.
d13 decisions - implement plan SYNC lane only

**D1 / #1510 — history.state.gov resolves every container URL to a list of what it holds** (15 pages fetched, all HTTP 200). This includes Parisv13's compilations, heading-only chapters, and ordinary compilations elsewhere. So your rule applies.
- The fix stops indexing **169 heading-only containers**: 17 in Parisv13, 152 in 80 other volumes. They leave search, document totals and page answers. Browse already matches HSG.
- **Choices left:**
  - (1) The 32 Parisv13 containers with their own text (1,531 paragraphs of treaty text): **keep them indexed for their own text, narrowed to their own pages** (recommended), or drop the text.
  - (2) 37 printed pages whose only answer today is a container would answer nothing: 19 in Parisv13 (e.g. p. 57, where the Preamble begins), 18 in 6 other volumes. Choose: give those page breaks to the section that begins after them (recommended), let such a section take a start page, or accept pages with no answer.
  - (3) The 7 heading-only appendix and historical-document containers: drop them too, or limit the rule to compilation, chapter and subchapter.
  - (4) File two side gaps as issues: Browse cannot open prose-only chapters (1,137 sections in 145 volumes); container text that HSG shows is discarded (1,237 containers in 141 volumes).
d1 decisions - accept recommendations for 1 and 2; limit the rule for 3, file the side issues

**D3 / #1516 — figures.** 532 figures sit inside documents (204 documents, 89 volumes):
- 426 are image only;
- 20 are empty `<figure/>`s, 15 of them standing for Chinese characters in frus1881;
- 86 have printed text, all in volumes from 1943 on: 51 heads, 36 paragraphs, 2 descriptions.
- The paragraphs are short captions: photo subjects ("W. Averell Harriman"), chart titles, a chart NOTE, and even the print-shop code "568851 2-76".
- HSG shows the image, the head as a caption, and the paragraph as ordinary text.
- The app shows no images, and prints the file name ("figure_1162") on 510 figures.
- 23 documents contain nothing but page images, such as the frus1981-88v11 appendices.
- Ten worked examples, with what each option would show, are in the research file.
- **Choices left:**
  - (a) paragraphs as **captions (no re-index)** or as text (re-index, parity with HSG);
  - (b) an image-only figure prints **"[Figure]"** (recommended: otherwise 23 documents look empty and "…thus:" points at nothing) or nothing;
  - (c) empty `<figure/>`s get the same treatment, or nothing;
  - (d) a captioned figure gets a "Figure:" marker, or none;
  - (e) file an issue to show or link HSG's images (served at `static.history.state.gov/frus/<volume>/<file>.png`).
- **How the app handles the other images and media the TEI links** (page scans excluded, as you asked; measured 2026-09-28 over all 553 volumes):
  - **Figure images (~990 `<graphic url>` in `<figure>`)** are bare file names. The parser keeps only the name, and the reader, PDF and Word print it as the caption (`FRUSDocumentParser.swift:1318`, `ASTToRenderNodeConverter.swift:505`, `FRUSRenderNodeHTMLSerializer.swift:737`). The app loads no image anywhere.
  - **history.state.gov serves them all at one predictable address:** `https://static.history.state.gov/frus/<volume>/<file>.png`. All nine files sampled across 1864–1988 returned 200. Sizes ran 3–679 KB, about 175 KB on average, which puts the whole set near 170 MB (a rough estimate from nine files).
  - **Volume covers (554) and some page images (29 PNG + 29 TIF)** are listed in each volume's TEI header as `<relatedItem>` asset entries, with URL, byte size and date. The page-image entries point at figure ids (e.g. `corresp="#d385p1"` in frus1981-88v04). The app skips the header, so none of these is used.
  - **Video supplements (20 players in 3 volumes):** frus1917-72PubDip has 12 `<object>` players, v06 has 5 `<iframe>`s and v07 has 3. Each is embedded as XHTML inside a `<figure>` with a head such as "Reel 1". The app renders an empty figure and drops the head, so these supplements are invisible. history.state.gov plays them.
  - **What this opens up for D3, a new choice (f):**
    - (1) keep today's text-only handling, with "[Figure]";
    - (2) a **"View image on history.state.gov ↗" link** on each figure and video: small, online only, no download cost;
    - (3) **load the image in the reader when online**: moderate, makes a request to history.state.gov per view, and PDF/Word still print a placeholder;
    - (4) **download figure images with their volume**: offline, and they can be embedded in PDF/Word exports; larger, about 170 MB across the corpus. It fits `DownloadManager` beside the XML.
  - Covers could separately illustrate Browse. That is a feature, not part of #1516.
- Heads and descriptions become the caption either way.
d3 decision - f option 4. not sure if this supersedes a-e above?

**D4 / #1465 — feasible, S–M.** The preview and the HTML export already share one renderer with preview-only switches. The export can drop an untitled heading while the preview shows a placeholder. PDF and Word follow the export path unchanged.
- **Choices left:**
  - a named sub-heading under a dropped heading moves up one level (recommended), or files under the section before it;
  - the preview label reads "Untitled section" or "Untitled section — left out of exports";
  - drop an untitled heading that has documents under it, or only one with nothing under it;
  - the editor row's typing prompt stays "Section heading" or becomes "Untitled section".
- d4 decisions - accept recommendation; "untitled section"; drop untitled heading in either case; keep "Section heading" prompt

**D6 / #1504 — delete.** Only the dead nearest-document strategy reads the manifest's `documentCount`. It is 0 in all 553 rows, and no plan or issue proposes filling it.
- The count is also the wrong number: the strategy needs each volume's highest printed document number, which differs from the count in 40 volumes.
- **Choice left:** delete the strategy only, or the manifest field too (about 40 more mechanical edits, same lane).
- The OpenAPI sentence at :2429 is false either way.
- d6 decision - delete in strategy, manifest field, and OpenAI reference

**D11 / #1468 — both fixes were tested.** The real generator was run with the proposed display-name rule, which cuts a name over 100 characters to its printed title.
- Only **11** names change, and the usage index is byte-identical afterwards.
- **271** names stay over 100 characters (up to 818), because most long items have no printed title to cut at. So the layout fix is needed regardless.
- Under the 12-alias cap exactly **1** collection loses its long form: "Indexed Central Files", the issue's headline case. Its paragraph is still printed in each volume's own Sources list.
- **Choices left:**
  - that paragraph: accept the loss, exempt the full-text alias from the cap (recommended), or raise the cap for all;
  - rule scope: names over 100 characters (11) or every name that opens with a printed title (46, of which 19 collide with another record's name);
  - the 271 plain long names: leave them to the layout fix, or also cut them at a boundary (not yet measured).
- d11 decision - exempt from cap; over 100 characters; layout fix

**Older decisions still open in the planning documents** (none blocks a lane; answer when convenient):
- the Archives Visit packet's repository order (College Park falls between two libraries);
- the packet's narrower "Published from this file" rule (#1488);
- whether name search keeps matching summary-only hits (R14);
- the publisher cited for a volume with no year;
- keeping the superseded text of a changed annotated document (Q-2);
- whether Section defaults save each write;
- "Browse all topics…" from iPad analytics windows;
- confirming calls made on your behalf in #1528, #1480 and #1425;
- whether to salvage or drop the Research Guide edits in `stash@{0}` (2026-08-20);
- App Store: the EULA placeholders, the privacy nutrition label, and English-only territories.

## 4. Planning documents: what has not been done

The audit found **714 items**. After the skeptics' corrections: 157 done, **362 not done**, 59 partly done, 43 unverified, 20 blocked, 27 deferred by the owner, 30 declined, 15 superseded. 285 are candidates to fold in, and 129 of those need the owner. `plans-digest.txt` lists every one. In summary:

- **Unfiled correctness fixes found in session logs.** The ◦ items in §2's table.
- **Also unfiled:**
  - on iOS, Facets is disabled in Meaning mode (the Mac offers it);
  - the S-2 project reach scan and S-3's off-index leads count Ed2 reprints of documents the reader already holds;
  - the live NARA catalog decoder misreads series dates;
  - Archives Visit derivations go stale when an indexed volume is updated, and an older derivation can finish last;
  - PV-1's sources statement is missing from analytics exports, the trip packet and the method appendix.
- **Owner-only, outstanding:**
  - three screenshot placeholders, and the Mac and iPad captures build 48 made stale;
  - by-eye checks listed in the build-48 PRs (#1486, #1490, #1501, #1519; Mac hover; iPad Stage Manager);
  - the Topics lens on a physical iOS 27 device;
  - confirming the dSYM warning is gone;
  - App Store Connect: the EULA, the privacy label, the listing (its figures predate vol. XVI);
  - filming and marketing plates (Visual-Marketing-Plan steps 5, 10, 12, 13, 15 and 16).
- **Designed but unbuilt (recommend parking):**
  - the OS-27 App Intents / IndexedEntity assessment (now unblocked by Xcode 27);
  - W15 P10 dateline places (blocked on your toponym curation);
  - links from the map to Search and Related;
  - a heat-matrix cell drill-down;
  - a Search command menu and shortcuts;
  - standalone token editors;
  - a subseries pole picker;
  - a region-share chart;
  - an iPhone rail peek strip;
  - an immersive Read mode;
  - a reader that follows the system text size;
  - `AXChartDescriptor` for four chart families;
  - Differentiate Without Color on the map;
  - about 37 fixed-size text sites.
- **Deferred or declined; no action:** #234 and its programs, W12 parallel editions, W14, the MCP server (no-build), CSUserQuery.

## 5. The #1309 report to the Office of the Historian

**Nothing has been filed upstream yet.** #1309 holds the Malta body (now diagnosed as a single displaced `</div>`) and three comments on pagination.

**The lead finding is new, and it was checked in the corpus:** `frus1952-54v09p1` ends at d899 on p. 1660, and Part 2 starts at d947 on p. 1743. **Documents 900–946 (printed pp. 1661–1742) are missing**, and that gap explains 352 of the 652 broken cross-references.

**The other classes** (all present at corpus `550a8c5c5` = upstream `8e5da08c1` for `volumes/`):
- **Structure:** 23 fix sites in 18 volumes (5 confirmed, 18 questions).
- **Pagination:**
  - 20 out-of-order breaks in 11 volumes;
  - misnumbered or malformed page ids: `frus1884` pg_13, `frus1977-80v13` `pgg_655`, `frus1949v01` `pg-814`, `frus1977-80v20`'s zero-padding;
  - missing page breaks in 5 volumes;
  - 9 wrong `@facs`.
- **Cross-references:**
  - 248 index "See" links to `#inN` ids that were never assigned;
  - 40 references to pages that do not exist, 8 of them into the wrong part;
  - 3 targets missing `#`;
  - bad volume ids;
  - `#pg101`.
- **Transcription:**
  - the doubled `)` in v16 d395;
  - `IRAN-U.S..`;
  - missing spaces, including 1,213 `,<gloss` sites in 40 volumes;
  - the #1514/#1515 note punctuation.
- **Dates:** #1407's misencoded dates, and one inverted date range.
- **Headers:** 11 `revisionDesc` published entries without `@when`; the appendix `titleStmt` gaps.

**Not OH items**, because they are legitimate encodings the app must handle: #1491's bracketed `@n`, and #1422's inferred ranges.

**Work.** Claude's part is S: regenerate the broken-ref report at `550a8c5c5` into scratch, then write one comment plus CSVs. Your part: pick the channel (P4), spot-check 2–3 of the question rows against the printed volumes, and post.

## Appendix — every open issue

**WB** = the owner's EditableContent wording, applied by the write-back lane.

| # | Issue | Lane | Kind | Size | Re-index |
|---|---|---|---|---|---|
| #1437 | Archival network: 42 of 376 graphs draw a node whose label reads exactly like the focus's | ARCH | UI | M |  |
| #1438 | Archival network: few labels fit on small canvases, and placement ignores the custodian and … | ARCH | UI | M |  |
| #1468 | Archival network: selecting "Indexed Central Files" draws a 2,150-character paragraph as its… | ARCH | UI | M |  |
| #1470 | In a small Archival Analytics window, the network's custodian captions are drawn underneath … | ARCH | UI | S |  |
| #1491 | In-app citations print frus1945Berlinv02's bracketed editorial description as the document n… | CITE | UI | S |  |
| #1504 | Citation Lookup's nearest-document strategy never runs, because every bundled manifest row h… | CITE | dev | S |  |
| #1506 | Citation Lookup's Batch mode shows the Parsed Fields section, which Batch never reads | CITE | UI | S |  |
| #1523 | Citation Lookup and Add Documents refuse a link or citation to a side-loaded volume, because… | CITE | UI | S |  |
| #1524 | Citation Lookup's title fragment strips the cited volume numeral inside words ('Vietnam' → '… | CITE | dev | M |  |
| #1465 | A Section heading left without text exports as an empty heading, <h2 class="section-heading"… | EXPORT | UI | S |  |
| #1496 | Word export writes a nested note's marker as a footnoteReference inside footnotes.xml (405 n… | EXPORT | UI | M |  |
| #1497 | Send to Zotero passes the collection name untrimmed: a whitespace-only name makes a Zotero c… | EXPORT | UI | S |  |
| #1498 | A collection name longer than the file system allows (255 UTF-8 bytes) would fail every expo… | EXPORT | UI | S |  |
| #1464 | Project Home and its Manage collections sheet call an unnamed collection "Untitled collectio… | EXPORT + WB | UI | S |  |
| #1434 | Network graphs re-place every label on each frame of the animated layout, so labels pop for … | GRAPH | UI | S |  |
| #1517 | Mac document and co-mention graphs: drag-to-pan and double-click-to-reset probably cannot st… | GRAPH | UI | S |  |
| #1518 | iOS: four graph and word-cloud context menus are attached after .position, so a long-press m… | GRAPH | UI | S |  |
| #1481 | The Cross-Reference Graph tells iPhone and iPad readers to click, right-click and pinch-to-z… | GRAPH + WB | UI | S |  |
| #1412 | Three splash and onboarding geometry unit tests fail on any iPad test host: iPhone fixtures,… | HYG | dev | S |  |
| #1423 | TripPacketSheet's .documents and .collection seed cases are never constructed; on those path… | HYG | dev | S |  |
| #1439 | SemanticVectorsGenerator: a map pass that refuses (no lemmatiser) can leave new vector artif… | HYG | dev | S |  |
| #1450 | CollectionEditorTitleTests.testContentAloneDoesNotNameANewCollection cannot find the Add men… | HYG | dev | S |  |
| #1484 | PromptsListView is constructed nowhere, so it is dead code or an unwired screen | HYG | dev | S |  |
| #1446 | Mac Collections window: the toolbar's collection picker shows the whole name, so a long name… | MACCOL | UI | S |  |
| #1448 | Mac note-block resting cap: a formatting change while resting can land the cap on a blank li… | MACCOL | UI | S |  |
| #1449 | Mac Collection popover: the Note field is still a fixed-height plain TextEditor that scrolls… | MACCOL | UI | S |  |
| #1475 | On the Mac, a List section footer is cut to one line with an ellipsis: the Topic sheet's Cov… | MACCOL | UI | S |  |
| #1477 | Mac Collections editor: a note block that has lost focus can keep drawing a caret, and a sel… | MACCOL | UI | M |  |
| #1493 | A collection's generated-block list token and the Mac collection row show an unnumbered docu… | MACCOL | UI | S |  |
| #1404 | The app stores "Department of State" library citations the external-citation generator does … | NOTE | dev | S |  |
| #1514 | SourceNoteParser files about 30 notes as RG 59 central files that are not (FOIA Reading Room… | NOTE | **wrong data** | M | yes |
| #1515 | Central-file designations: 'Vol. N' notes store no file (8 notes), and the packet drops the … | NOTE | UI | S | yes |
| #1509 | A page cross-reference (pg_N) goes to the first of several documents beginning on that page;… | PAGE | **wrong data** | M | yes |
| #1510 | frus1919Parisv13's compilations are indexed as documents beside the chapters they hold, beca… | PAGE | UI | M | yes |
| #1511 | A second pagination's page breaks (frus1871 pg-seq1_, the 1862/1865 President's messages) ar… | PAGE | UI | S | yes |
| #1516 | A <figure>'s head, paragraphs and figDesc are dropped everywhere, and its graphic's URL (fig… | READ | UI | M | ? |
| #1432 | iOS Free Up Space: the rows stay tappable while the sheet is removing, so a tap toggles a ch… | STOR | UI | S |  |
| #1476 | Volumes & Storage says "Zero KB" and "0 of 553 downloaded · nothing indexed yet" while it is… | STOR | UI | S |  |
| #1526 | After Settings ▸ Rebuild Index, AppState.indexedVolumeIds reads [""] until relaunch (wrong i… | STOR | **wrong data** | S |  |
| #1531 | Initial iCloud sync after app update fails; succeeds after relaunch | SYNC | UI | M |  |
| #1422 | Chronology's spanning chip says "N editorial notes span this whole period", but 36 of the 7,… | WB | UI | S |  |
| #1478 | Count copy left after #1374: four baselined strings need one/many wording, the semantic map'… | WB | UI | M |  |
| #1483 | Nine localization keys carry two different default values across the app, so a future string… | WB | dev | M |  |
| #1527 | Meaning-search and Semantic Vectors captions say match files 'are downloading' even when Dow… | WB | UI | M |  |
| #1472 | Cross-Reference Analytics' heat matrix labels an E-volume's column "’69–76 Volume", the firs… | XREF | UI | S |  |
| #1473 | On the Mac, at the Cross-Reference Analytics window's 720 pt minimum and at its default ~820… | XREF | UI | S |  |
| #1430 | iPad floating tab bar: no inline navigation title or subtitle is drawn in any tab, so "Worki… | close? | UI | M |  |
| #1538 | Export research database failures (Mac: the sandbox refuses SQLite's journal beside the chosen file) | STOR | broken | S |  |
| #1539 | Collocates search mode fails on iOS (no lemmas on iOS 27 devices) | LANG | broken | M |  |
| #1540 | Floating selection bar and the system edit menu overlap on iOS | SEL | UI | M |  |
