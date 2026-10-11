# Plan of record — from 2026-09-28

**Base:** `v2` @ `07b9b65c` · build 48 shipped 2026-09-27 (tag `build-48` = `d61b53f9`) · index **v62** · rollup **v10**. One PR is open: **#1533**, the docs-only prep for the owner's review.

**Scope.** 49 issues are open. #234 is deferred indefinitely, and #1309 is used only to hold the report to the Office of the Historian. This plan covers the other **47**.

**Status: LIVE — the plan of record from 2026-09-28** (owner decision P5). It supersedes `Plan-Of-Record-2026-09-06.md` (in `Completed/` since 2026-10-01). The owner answered every decision in §3 and §3a on 2026-09-28, and §0 gives the result. **WB, Tier 1 and Tier 2 landed on 2026-10-01, and HYG, READ and PLAN of Tier 3 on 2026-10-02; OH's report landed after them and was filed with the Office of the Historian on 2026-10-02; lane CFPF (#1543) was added after Tier 3 on the owner's word; §0a says where the wave stands and what remains.** **§0b and §0c carry it on from build 49, and §0c's *Where the queue stands* is the present state.**

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
    - **D moves to the tail of the plan as an optional item** (owner, 2026-09-29, after the device result below). LANG builds steps A–C only. D, a reference counted as printed from `CloudVectorsGenerator`'s same NLTagger pass and the comparison against it, flagged per surface, runs last and only if step A's log shows the verdict still failing on foreground launches once B and C have landed.
    - The flag and the explanation are new copy, with EditableContent blocks. The manual text for them goes to `Planning/Manual-Revisions-Pending.md` (P2).
    - D is a regeneration (`cloud-vectors-core.json` and `keyness-baseline.json` come out of one `pack()`), about an hour of generator time. That is why it is optional.
- **#1539 device result (owner, 2026-09-29):** after a force-quit and relaunch, Collocates worked on both the iPhone and the iPad. So the lemmatiser is available on hardware, and the refusal came from a verdict fixed earlier in a long-lived process, as the triage's background-launch hypothesis predicts. Steps B (re-check on foreground) and C (no warm-up in a background launch) address that cause directly. Step A's log will show how often the verdict fails at all.
- **Owner diagnostics for #1539** (optional, but they would decide whether step D is needed). On each iOS device:
  - force-quit FRUS Explorer, reopen it on Wi-Fi with the screen on, wait 60 s, then run Search "missile" ▸ Collocates, three times;
  - note Wi-Fi or cellular, and whether the Word Cloud header says "Counted as printed";
  - if possible, stream Console.app from the cabled device during one launch.

**Lane order**
1. **WB** — needs the owner's EditableContent hand-back.
2. **Tier 1:** STOR (with #1538), PAGE (index v63), NOTE (v64), SYNC, LANG (#1539, after SYNC).
3. **Tier 2:** EXPORT, MACCOL, SEL (#1540), GRAPH, ARCH (after GRAPH), CITE, XREF.
4. **Tier 3:** READ, HYG, PLAN, OH, then MANUALS (apply the approved pending manual revisions after the owner's Mac hand-back) and DOCS-2 (the iOS manual).
5. **Optional tail — LANG-D (#1539's printed-form fallback):**
   - **When it runs:** only if LANG's warm-up log shows the lemma verdict still failing on foreground launches after steps B and C.
   - **What it builds:** a reference counted as printed, and the fallback comparison on Collocates, Word Cloud Distinctive, Related's shared-word chips and the clouds' counts.
   - **What each fallback surface must say:** that it fell back, why, and that results can differ from a device that reduces words to their dictionary forms.
   - **What it costs:** regenerating the word-cloud artifacts, about an hour.

The release (build 49, one re-index) follows the tiers the owner chooses to land. The staged launch files are listed in the plan's session entry in `Planning/DEVELOPMENT-PLAN.md`.

## 0a. Where the wave stands — 2026-10-02

Recorded by lane PLAN against `v2` @ `dc17d945` on 2026-10-01, and brought to `v2` @ `1d6fc032` when the lane landed on 2026-10-02, after HYG and READ had merged. Lane OH's landing, on `v2` @ `6f6d2430` (PLAN's merge, PR #1560), added the two paragraphs on PLAN and OH below the table and rewrote "What remains" to match. Lane CFPF (2026-10-02, #1543) added the paragraph on itself below, recorded OH's filing, and changed the release's re-index to v62 → v65. None of this changes anything in §0. The build number is still 48: build 49 has not been cut. The index is at **v64** on `v2` and goes to **v65** when lane CFPF lands; the rollup is at **v10**.

**Landed: WB, all of Tier 1, all of Tier 2, and HYG and READ of Tier 3** (fifteen lanes, in this order: the first thirteen merged on 2026-10-01, HYG and READ on 2026-10-02).

| Lane | PR | Issues closed | Notes |
|---|---|---|---|
| WB | #1544 | #1422, #1478, #1483, #1527 | The owner's 2026-09-30 EditableContent review, written into the app. It also carried the copy for #1464, #1476, #1481 and #1531. |
| STOR | #1546 | #1526, #1432, #1476, #1538 | Both ◦ fold-ins. |
| PAGE | #1547 | #1509, #1510, #1511 | Index **v63**. The persons-list ◦ fold-in. |
| SYNC | #1548 | #1531 | All seven items of §2, and the ◦ fold-in. Adds the archive gate (below). |
| NOTE | #1549 | #1514, #1515, #1404 | Index **v64**, D2 "wide". All five ◦ fold-ins, and one fix taken from §4: the live NARA decoder's series dates. Five artifacts regenerated. |
| LANG | #1550 | #1539 | Steps A–C. Step D stays the optional tail. |
| GRAPH | #1551 | #1434, #1517, #1518, #1481 | |
| ARCH | #1552 | #1437, #1438, #1468, #1470 | `collection-authority.json` and its successors regenerated (D11). |
| EXPORT | #1553 | #1465, #1496, #1497, #1498, #1464 | The three ◦ fold-ins, and two fixes taken from the audit beyond §2: PV-1's sources statement (§4), in the analytics exports, the visit packet and the method appendix; and the word-cloud plate, which now pins the light appearance and draws its credit in a fixed colour. |
| MACCOL | #1554 | #1446, #1448, #1449, #1477, #1493, #1475 | Both ◦ fold-ins. |
| SEL | #1555 | #1540 | Option (a). |
| CITE | #1556 | #1504, #1506, #1523, #1524, #1491 | |
| XREF | #1557 | #1472, #1473 | The ◦ fold-in. |
| HYG | #1558 | #1412, #1439, #1423, #1450, #1484 | All five ◦ fold-ins. Adds a gate for a view nothing constructs (`UnconstructedViewAuditTests`), and #1412's known-failure exemption is dropped: the unit target runs with none. |
| READ | #1559 | #1516 | D3 option (f)4, and the ◦ fold-in. The index stays at **v64**: no stored text moved. D3's sub-choices (a)–(d) shipped as §0 recommends and wait on the owner's confirmation (below). |

**PLAN landed too, as PR #1560 on 2026-10-02.** It is the planning housekeeping of P3 (b) and closes no issue, so it has no row in the table. Its session entry in `Planning/DEVELOPMENT-PLAN.md` lists what it archived and corrected.

**OH's report is compiled, and it lands in lane OH's PR, the one that carries this paragraph.** It is `Planning/OH-Report-2026-10-01.md`, with its CSVs in `Planning/OH-Report-2026-10-01/` and the script that re-checks every item in `tools/oh-report/`. **It was filed on 2026-10-02**: upstream as [HistoryAtState/frus#469](https://github.com/HistoryAtState/frus/issues/469), and on #1309 as [one comment](https://github.com/joshbotts/FRUS-Explorer/issues/1309#issuecomment-5953382879). #1309 stays open.
- **What it holds** (§5 was the plan's list; each item was re-checked at corpus `550a8c5c5`, and several figures moved). `frus1952-54v09p1`'s missing Documents 900–946 lead it: 47 documents, which 352 of the 652 broken references point into. Then six classes: structure (19 edits in 15 volumes, 17 confirmed and 2 questions, and 21 Sources lists as questions), pagination (73 rows in 51 volumes), cross-references (645 defects), dates (205 rows in 89 volumes), transcription (169 rows, and 77 files with glued tags) and headers (13 rows).
- **What it corrects in the repository's own record.** Of the 2026-09-20 structure sweep's 23 rows, three are withdrawn and one of its five confirmed rows is wrong (`frus1873p1v2`); the report's Part B.2 says not to send that sweep's `REPORT.md`. The generator is not fixed.
- **The items lanes PAGE and NOTE added for it** are in the report where they are defects: two of PAGE's page ids (`pg-seq-1004` in `frus1949v05`, `pg-seq-938` in `frus1950v01`), NOTE's source-note and dateline patterns, and its nested Sources headings, which a scan of every Sources list took from three volumes to 32 headings in 21 lists. OH's session entry in `Planning/DEVELOPMENT-PLAN.md` says which were left out as ordinary TEI and which are left to the owner.
- **What followed (P4), done on 2026-10-02:** Part A was posted to #1309 as one comment and filed upstream on `HistoryAtState/frus` as issue #469 (the two links above). No printed volume and no page image was read for it.

**Count.** The plan covers 50 issues: the 47 of §1 and #1538, #1539 and #1540. **All 50 are closed**: the 49 in the table and #1430 (D14), each read with `gh issue view` on 2026-10-02. **Six issues are open in the repository**, and none is one of the 50: #234 (deferred), #1309 (it holds the OH report), #1543 (lane CFPF holds it, in the next paragraph; it closes when the lane's PR merges) and the three under "Not placed" below, #1535, #1536 and #1545.

**Lane CFPF (#1543), added after Tier 3 on the owner's word (2026-10-02).** Its PR is opened when the lane lands, and #1543 was listed under "Not placed" until the lane took it. The Subject-Numeric File of February 1963–1973 becomes an eleventh provenance category, a stored citation form (`citation_era = 'subject_numeric'`, index **v65**) and a Source Explorer panel, placed by what the citation gives. The owner answered four questions for it — the full split; build 49; the 356 decimal numbers cited through the National Archives move to Central Decimal File; the collection records stay and the help text explains them — and its other decisions are listed for review in its PR. Its session entry in `Planning/DEVELOPMENT-PLAN.md` has the measurements.

**What remains, in order.**
1. ~~**OH's posting.**~~ **Done on 2026-10-02**: filed upstream as [HistoryAtState/frus#469](https://github.com/HistoryAtState/frus/issues/469) and posted on #1309 as [one comment](https://github.com/joshbotts/FRUS-Explorer/issues/1309#issuecomment-5953382879). #1309 stays open.
2. **MANUALS**, after the owner hands back the Mac manual: apply the approved entries of `Planning/Manual-Revisions-Pending.md`, which holds eighteen sections — one for each of the fifteen lanes in the table, one for PLAN, one for OH and one for CFPF — with an index at its head. OH's section proposes no manual change.
3. **DOCS-2**, after the same hand-back — the iOS manual: the whole re-read, parity with the Mac manual, and the owner's Mac edits.
4. **Optional tail, LANG-D** — only if LANG's release log shows the lemma verdict still failing on foreground launches (§0, Lane order 5).
5. **The release steps** — the next paragraph.

**The release (build 49, one re-index, v62 → v65).** §2's list stands. The wave added to it (v65 is lane CFPF's, owner decision of 2026-10-02 that #1543 ships in build 49, so the build still carries one re-index):
- **The CloudKit schema gate (SYNC).** Every archive now runs a "Check CloudKit schema" phase, and it fails until `Scripts/check_cloudkit_schema.py` has read Production's schema on this Mac. That needs a CloudKit management token (`xcrun cktool save-token --type management`), and none was saved when SYNC landed. Nothing awaits deploy: `identifiersAwaitingDeploy` is empty.
- **SYNC's device check.** The Development-device A/B with an unpublished field, and the Mac and iPhone system logs, were not run.
- **LANG's release log**, on the owner's devices. It decides whether LANG-D is needed.
- **The owner's by-eye checks**, listed under "Still open" in each lane's entry in `Planning/DEVELOPMENT-PLAN.md`: the Mac's research-database export from a sandboxed build (STOR); the Archival network on the Mac and an iPhone (ARCH); Cross-Reference Analytics at 720 and 820 pt on the Mac (XREF); Batch and the side-load notice (CITE); one Word export holding `frus1951v01` d2 (EXPORT); the Mac Collections window's list in MACCOL's entry ("Owner's Mac checks"); VoiceOver on the iOS edit menu (SEL); the Settings row for language analysis (LANG); the Mac's Search tooltip and the hint under "Select a document to begin" (HYG); figures in the Mac's reader and storage bar, with one Word export opened in Word itself (READ); and lane CFPF's fourteen, of which an iPhone was looked at at the lane's landing and no iPad or Mac was: the Subject-Numeric panel in Source Explorer on iPhone, iPad and Mac with the sentence under it when Archival Neighbors is empty (two new sentences, added at the lane's landing), the no-year table there and in the NARA Lookup sheet, the Archival Sourcing charts and Categories menu, Browse ▸ Archives ▸ Provenance Types with Your Library beside it, the map's provenance legend on iPad and Mac (the new hue, 0.64, sits 0.04 from Previously Published's 0.68, and the lane's specification asked for a by-eye check of it), one Archives Visit packet holding a Subject-Numeric document cited through the National Archives, VoiceOver on the Categories menu, and, on iPhone or iPad, no basis line above the Archival Neighbors of a Department-led designation with a stop in it (`frus1964-68v22/d111`, `DEF 19–8 U.S.-IRAN`; 34 documents read "Same decimal file" there until the lane's review round 1); and four from the landing's second round, each seen on an iPhone only: the four provenance charts' colours in light and dark (the ten older categories as build 48 draws them, the Subject-Numeric File brown — the charts state their colours now, where the lane's first build moved every later category one colour along), the "Where your documents come from" bar under its legend on an iPhone and the card unmoved on an iPad and a Mac, Archival Neighbors and Related Documents for a central-file document alone in its file (`frus1964-68v01/d359`, `frus1961-63v03/d10`: nothing listed, and the empty sentence — the Subject-Numeric one for `d359` since the landing's third round), and the last row of a list resting under the status banner (Provenance Types' eleventh door, Settings' last row), which the lane left and its entry describes; and two from the landing's third round: "Archival provenance over time" with no white wedge where a category's band begins or ends (seen on an iPhone with every category shown; also owed with one hidden, under a subseries scope and in an exported figure), and VoiceOver over that chart reading no "0%" for a category with no notes in a decade (CFPF). No entry records the Mac app being run by eye: GRAPH's Mac half rests on an in-process replay and MACCOL's on a harness, and HYG, READ and CFPF built the Mac app without running it.
- **READ's owner decisions** (PR #1559, "Owner items"). Four bear on the release: D3's sub-choices, which §0 left to that PR's review; whether the pass that fetches figure images for volumes already on a device stays automatic (a full library downloaded before build 49 fetches up to 141 MB at its first launch); whether the App Store Connect privacy label changes, now that the app asks `static.history.state.gov` unasked; and onboarding's "≈ 3.5 GB", which is 141 MB short of a full download with images.
- **The earlier Mac check's five steps**, still owed since 2026-09-25 (`Planning/Completed/Mac-Check-2026-09-25.md`): hover, a trackpad swipe, dark appearance, and one judgement.

**Not placed.** Open issues and defects that no lane holds. None is designed here.
- **#1535** — Browse cannot open a prose-only chapter, subchapter or compilation. **#1536** — text printed at a container's own level is discarded. Both are D1's side gaps. §0 puts them in scope "only if P1 allows", and the owner has not added them.
- **#1545** — Semantic Match Feedback has a way to share its file and no destination. An owner decision; filed from WB's close-out.
- **Found by the Tier 3 lanes and not filed.** Each is described under "Filed rather than fixed here" in the PR named:
  - **PR #1558 (HYG):** `RichTextRestingCapTests` crashes the test host on an iPad Pro 13-inch (M5) on iOS 27.0, so an iPad host there cannot finish the unit target.
  - **PR #1558:** two views nothing constructs, `FilterChip` and `CrossProjectNoteIndicator`.
  - **PR #1558:** **Add to Archives Visit…** on a smart collection whose search cannot run yet does nothing and says nothing.
  - **PR #1558:** code only tests call (`TripPacketBuilder.build(documents:researchQuestion:dataSource:)`, `ProjectContextViewModel`, `CollectionFootnoteStyle`).
  - **PR #1558:** 14 Swift files with no license header, outside every target.
  - **PR #1558:** ⚙ Collection on an iPad narrower than the Air, where the test helper has no overflow branch. Not measured.
  - **PR #1558:** `PROJECT_ONLY` with a store for some of the planned groups still rewrites the run-wide artifacts.
  - **PR #1558:** a vector pack with no layout writes a volume's shard before it finds a later volume missing.
  - **PR #1558:** the map preflight counts by the store's heads, so a store whose heads misstate its documents can still refuse after the vectors are written.
  - **PR #1559 (READ):** two images are fetched that no document draws.
  - **PR #1559:** `body_text` of the 12 `frus1917-72PubDip` film sections holds the player's hidden text and script. Read from the code, not from an index.
  - **PR #1559:** the export header takes no dateline from an `<opener>`.
  - **PR #1559:** an image that arrives late still moves the page under a reader who is not at a footnote.
  - **PR #1559:** an image in flight when an update drops its name is stored after the prune.
  - **PR #1559:** two things read in passing and not verified, in `cancelDownload` and `PDFCollectionExporter.drawFrameWithHighlights`.
  - **PR #1559:** the figure fetch's run-level de-duplication has no test.
- **Left for HYG by lane PLAN, and not taken** (the two lanes were developed on the same base, so HYG never saw the note): the comment-only fixes in four Swift files (`Project.swift`, `SimilarityModel.swift`, `ProvenanceSource.swift`'s `curatedDisclosure`, `TripPacketSheet.swift`), and the citations of #1210, #1211 and #1257 in `CLAUDE.md` and in 22 Swift files' doc comments, where the work merged as PRs #1250, #1251 and #1256. PLAN's session entry has both.
- **Found by lane PLAN while re-measuring, not filed:**
  - **The provenance lens's caption is two volumes out.** *Fixed by lane CFPF (#1543): the caption is `.v3`, its two figures are measured from the regenerated index (86 of 499), and `SemanticMapSurfaceTests.provenanceCaptionFiguresAreMeasured` recomputes them. The manuals' §15.6 sentences are proposed in `Planning/Manual-Revisions-Pending.md`.* As found: `semanticMap.lens.provenance.caption.v2` says the winning category is a plurality "for 73 of the 499 volumes it colors". Recomputed from `source-provenance-index.json` as NOTE regenerated it, it is **75 of 499**: `frus1961-63v03` and `frus1961-63v21` joined. The string, its EditableContent block, three doc comments and both manuals' §15.6 state 73, and no test compares the caption with the artifact.
  - **`subject-numeric-labels.json` describes itself out of date.** Its `coverage.measured` block counts 1,362 subject-numeric keys; `collection-usage-index.json` has held 1,370 since its 2026-09-25 regeneration. Its `coverage.note` says the country element is not read, though the file has carried `areas` since #1254. Regenerating it needs the owner's local handbooks.
- **Left open by the lanes themselves**, each with its fix described in the lane's entry: the Spotlight item of a left-out container, the persons list's "until January, 1953", and the export check's wording for a left-out container (PAGE); the Subject-Numeric files still stored without a designation — 126 central-file notes, 55 `AID` notes and about 778 NARA-led notes (NOTE); the bracketed `@n` on six more labels (MACCOL, CITE); and Person Analytics' ranking chart, which sets the labels XREF fixed elsewhere.

---

## 0b. Since build 49 — 2026-10-07

Build 49 is archived and tagged (`build-49`, `34a51205`). Three things have happened since, and none changes §0.

- **A second set of sessions writes to this repository.** They build FRUS Explorer Light, a self-hosted web edition in `joshbotts/FRUS-Explorer-Web-App`, which compiles this repository's shared kits on Linux from a pinned commit. Between 4 and 7 October they merged nine pull requests here that move the TEI pipeline, the reader's page, the citation code, the indexing pipeline and the search service into `FRUSCoreKit/`. `CLAUDE.md`'s *Web edition* section states the four rules sessions here follow; the arrangement is the web repository's `docs/COORDINATION.md`. The owner's stance (2026-10-07): follow the rules, and where an app goal complicates the web edition, be shown the option that stays within them and the option that sets them aside. An index-version bump is the change that costs the web side most (its server refuses exports from the new build until its pin moves), so bumps are batched into one per build where the work allows.
- **Both manuals are brought up to date and marked AI Generated** until the owner reviews them, which will not be before 2026-10-21. From here on a lane that changes behaviour a manual describes edits the manual and leaves the notice: the owner's decision of 2026-10-07, which replaces P2 in §0 and §3. `Planning/Manual-Update-Build-49-Owner-Review.md` is the review's worklist.
- **Two feature requests are assessed, and the owner took every recommended default on 2026-10-08. Neither is started; each issue carries its implementation plan:** #1576 (bulk actions on search results; `Planning/Issue-1576-Bulk-Actions-Assessment.md`) and #1577 (combined full-text and semantic search; `Planning/Issue-1577-Search-Within-Results-Assessment.md`). Neither needs a CloudKit deploy, an index-version bump or a re-index on its recommended path. Their interface lanes edit the same search menus: #1576's selection lanes land first, after #1565 is fixed, and #1577's lanes 4 and 5 after them. #1577's lanes 1 to 3 can go at any time.

Owed before build 50: a TestFlight line for #1578, for the print change below and for the documents restored to 1952–1954, vol. IX, Part 1 (§0c; a reader updates the volume to get them); and the twenty-three defects the manual review, the catch-up and the assessments turned up, each checked against the code and filed on 2026-10-07 as #1582–#1604.

**Decided by the owner on 2026-10-07:**
- **Lanes edit the manuals** (above).
- **1981–88 vol. XVI's person and term links (#1599)** are built with the next change that bumps the index version (#1535, #1536 or the next volume ingest), not on their own: one re-index for readers and one pin move for the web edition.
- **#1578 and #1579's open questions (2026-10-08).** The colours stand. Person names and cross-references print without their underline (done: one `@media print` rule in the kit's stylesheet). An empty person or term reference still reads as "not found", the page's link scheme check stays exact, and the test hook on the two read-only stores stays.

## 0c. The week of 2026-10-12 — usage, and the queue

The owner asked on 2026-10-07 and again on 2026-10-09 for sessions that spend less usage. On 2026-10-09 the session transcripts of 2026-09-25 to 2026-10-08 were totalled: each request's `usage`, counted once per message id and request id, over every transcript under `~/.claude/projects/-Users-jbotts-Development-FRUS-Explorer*/`.

| | Main sessions | Subagents |
|---|---|---|
| Model calls | 2,081 | 70,028, from 1,390 agents |
| Cache-write tokens | 32.0M | 380.9M |
| Cache-read tokens | 1,136M | 19,293M |
| Output tokens | 2.1M | 3.4M |

- **Usage is calls × context.** At API price weights (cache read 0.1, cache write 1.25, output 5; the subscription's own weights are not known) subagents were about 94% of the fortnight and output about 1%.
- **A subagent's first call carried a median 127,733 tokens**, about half of it `CLAUDE.md`, which was 226,886 characters.
- **The eight largest workflow runs each read 0.7 to 1.25 billion tokens from cache.** Every main session of the fortnight together read 1.1 billion.
- **Main sessions averaged 546K tokens of context per call**, because one session ran from 27 September to 8 October.

**Changed on 2026-10-09.** `CLAUDE.md` is 54,241 characters. Its per-suite device entries are now `Planning/UI-Test-Destinations-Runbook.md` and its generator entries `Planning/Generators-Runbook.md`, each moved word for word; `CLAUDE.md` keeps one index row per suite and per tool, the rules that span entries, and the instruction to read an entry before using it. On the fortnight's call count that is about 3.5 billion fewer cache-read tokens.

**Rules for the week.**
- Small defects are fixed inline, several related issues to one pull request, with one review pass on the diff. No two-lens review, no skeptic per finding, no by-eye sweep agents.
- `lane-dev.js` is not used this week. It returns only for a lane with real design risk (an index bump, a feature lane), one lane per run.
- One fresh session per pull request, started from this section and the issue numbers, and ended at the merge.
- Tests are scoped with `-only-testing` while developing. Landing owes one full unit run, `swift test` where the diff names package input, and the Mac build. Build output goes to a file, and the session reads the summary.
- The queue is serial, as in §0: the next pull request starts when the owner has merged the one before.

**The queue.** 26 of the 35 open issues, with no index bump. A fix in pull request 4 that turns out to need one moves to the bump below.

| | Pull request | Issues |
|---|---|---|
| 0 | `CLAUDE.md`'s entries move into two runbooks (this change) | — |
| 1 | Upstream catch-up at corpus `deb6a04f8` | #1309 |
| 2 | Interrupted indexing is detected and repaired | #1566 |
| 3 | The sync and indexing banner no longer covers a list's last rows | #1565 |
| 4 | Wrong data in lookups | #1582, #1589, #1591, #1603 |
| 5 | Meaning-mode and browse honesty in Search | #1584, #1595, #1596, #1597, #1598, #1592; #1608 is diagnosed here |
| 6 | Small interface, accessibility and export fixes | #1583, #1585, #1586, #1587, #1588, #1590, #1593, #1594, #1602 |
| 7 | Tooling and test reliability | #1568, #1600, #1601, #1604, #1606 |

**Decided by the owner on 2026-10-09: #1592, yes.** Checklist Mode depends on Log Research Sessions. Pull request 5 takes the issue's option 2, a line in the app saying that opened results are not hidden while the switch is off, unless the owner prefers option 3, the manuals alone.

**Upstream (pull request 1).** HistoryAtState/frus is at `0e9f9e0ec` (2026-10-09), nine commits past `8e5da08c1`; `volumes/` last changed at `deb6a04f8`, and the local clone is there. 26 volumes changed, 51 lines:
- **Div boundaries** in about fifteen volumes, `frus1945Malta` among them. This is upstream pull request #470, which cites the report filed as HistoryAtState/frus#469 and says more is to come; #469 stays open.
- **Section types.** Two `frus1902app1` divisions are sections and no longer documents (`s05sub04`, `s12`), and `frus1868p1`'s `comp1` is a compilation.
- **Document numbers.** A trailing space is gone from three `@n` values, and seven of `frus1981-88v11`'s documents (its appendix, `appA` to `appG`) are numbered A to G where they were 331 to 337.
- **Text.** Mis-encoded characters are repaired (`frus1958-60v05mSupp` and others) and no-break spaces replaced (`frus1981-88v16` and three others). *(Corrected 2026-10-09: this list first gave the two 1981–88 volumes the other way round.)*

Readers need no new build: `VolumeUpdateChecker` offers a corrected volume by its blob hash, and the download re-indexes it. The work is the records': the manifest's sizes; the structure sweep, the report's re-check and cross-reference validation at the new commit; the two re-typed divisions and the lettered numbers checked against citations and the bundled document ids; an aggregate regenerated only where its diff is not empty; and #1309 closed if Malta's row clears. Do this first, because every generator run and every unit run with the TEI mirror already reads the new corpus.

**Pull request 1, done (2026-10-09).** Measured at `deb6a04f8` against `8e5da08c1`; the session entry in `DEVELOPMENT-PLAN.md` has the method.
- **The report filed as HistoryAtState/frus#469.** 17 of its 19 structure edits are corrected exactly as suggested, in 13 volumes, Malta's among them, so #1309 closes with this pull request. The two Sources-list edits (`frus1955-57v13`, `frus1964-68v06`) stand as reported, and no row of any other class is gone or new. Upstream also moved `frus1945v01`'s list of persons out of the Introductory Note, a sweep row the report had withdrawn as matching the book. The structure sweep at the new commit finds 7 sites in 6 volumes where it found 23 in 18, none of them confirmed. `tools/oh-report/status_at_commit.py` (new) answers this question at any later commit; the filed report and its CSVs are left as filed.
- **What a reader gets when a corrected volume is re-indexed**, by the kit's own parser over the 26 volumes at both commits: Browse's structure changes in 14 volumes; `frus1981-88v11`'s seven appendix documents cite as Document A to G; eight documents change by a few characters; `frus1945v01`'s Introductory Note no longer carries the list of persons in its text; and `frus1902app1` goes from 202 indexed documents to 201.
- **`frus1902app1` loses text until #1536 is fixed.** Its two re-typed divisions (`s05sub04`, `s12`) each hold a statement of the case above the documents inside them, 12,783 characters together. As documents the app indexed and showed that text; as sections that hold documents, the app discards it, which is #1536's class. `s05` (6,060 characters) goes the other way: it no longer holds documents, so it is now indexed. #1536 carries the detail, and this raises its weight in the index bump below.
- **Two rows of the bundled semantic index name documents that no longer exist** (`frus1902app1` rows 150 and 174). On a device holding the corrected volume a neighbour list that would have named either is one short. The vectors are not re-harvested for two rows of 314,571; the volume is re-harvested at the next re-pack (`New-Volume-Release-Plan.md`, "Phase D for a CORRECTED volume").
- **Bundled files.** The manifest (14 sizes), the administration profiles, collection usage and external-citation indexes, and the three word-cloud files are regenerated. Volume sources, the collection authority, provenance flow, resolved edges and source provenance came out byte-identical and are untouched. The broken cross-references are the same 652 rows, so the bundled exclusion index is untouched and only its planning copy is refreshed.

**Pull request 2, done (2026-10-09): #1566.** A volume's `volume_structures` row is now the record that its last store pass finished: the pass removes it before it writes anything and writes it last. A volume that holds documents and no such row was cut short, and a launch finishes it unless the interrupted-indexing sentinel names it, in which case it stays on the reader's amber badge as before. No new table, no index bump and no re-index. In the app on a simulator, a volume killed at 600 of its 759 documents stayed at 600 through a relaunch with the sentinel in place, and was whole 8 seconds into a relaunch with the sentinel gone. Not changed: a sentinel left naming a volume that is in fact whole (the report's `frus1936v03`) still shows the badge, which a Re-index clears.

**Pull request 3, done (2026-10-09): #1565, merged as #1612.** The banner no longer covers a tab's content. Each tab's own view controller now sets the banner's height aside at the bottom of its safe area, and the banner is drawn in that room (`TabShellBannerModifier` in `MainTabView.swift`); a navigation stack passes its controller's safe area on where it did not pass on the SwiftUI inset the shell used before. Measured on iPhone 17 with the Local Only banner up, its top edge at y 721.7:
- **Lists.** The Browse root, Browse ▸ Archives and the Settings root rested with their last row's text at y 732–755 and now rest with it ending at y 685–686.
- **More than the issue reported.** Settings ▸ Volumes & Storage ▸ Download from GitHub drew its Download button at y 741–775, wholly under the banner, so a reader with a banner showing could not start a download from that screen; it is now at y 671–706. The reader's web view ran 69 points under the banner and now ends at its top edge.
- **Why not the issue's first suggestion.** `contentMargins` applied at the shell was measured too: it cleared the three lists and left the Download button where it was, because it reaches scroll content only.
- **Search.** The pre-search screen no longer reserves the banner's height itself, and `\.tabShellBottomOverlay` is gone.
- **Tests.** `TabShellBannerClearanceTests` (UI, six scenarios, one of them iPad-only; on the old drawing four fail on iPhone 17 and five on an iPad Pro 11-inch in landscape) and `TabShellBannerReserveTests` (unit, four tests). `BrowseWithinScopeTests` now scrolls its row clear of the banner before tapping it, which is what failed it on iPhone 17 under iOS 27.0.
- **For #1576.** A bar pinned to the bottom of the Search stack's safe area now sits above the banner without being told its height; the assessment says so.

**Pull request 4, done (2026-10-09): #1582, #1589, #1591, #1603.** No index bump, no CloudKit deploy and no re-index. The session entry in `DEVELOPMENT-PLAN.md` has the measurements and what was seen in the app.
- **#1582.** The count beside a term in Look up an abbreviation is the number of volumes that define it: `EUR` reads 231 where it read 82, and is fifth in the opening list where it was nineteenth. A term or a definition the TEI source wraps across lines is read with the break folded to a space, so `EUR` has 16 wordings where it had 30. Nothing stored changes.
- **#1589.** A lot cited through the National Archives with its record group gets the keyless lot cards on both platforms, under the record group the note names: 719 of the 807 such documents in a full index (621 one series, 98 a divided lot). Ten are refused because the note opens with another record group, and 78 cite a lot the bundle does not hold.
- **#1591.** The search index's copy of a document's tags is cleared when its last tag is gone. It is reconciled at launch and each time an iCloud import settles, deleting a tag in Settings rewrites its documents at once, and a result row no longer prints a tag id it cannot name. One new partial index on `document_cache`, built once at the first launch after the build ships, by one scan of the table.
- **#1603.** A cross-reference to a whole volume opens the volume's page in Browse, or history.state.gov's page for a volume outside the catalogue: 8,266 links in the 553 volumes at corpus `deb6a04f8`, 6,997 of them to catalogue volumes.

**Pull request 5, done (2026-10-09): #1584, #1592, #1595, #1596, #1597, #1598; #1608 diagnosed.** No index bump, no CloudKit deploy and no re-index. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was seen in the app.
- **One cause under four of the six.** Each search view built its own account of the rows on screen, from the keyword ceiling as a constant and from the Keywords | Meaning picker. Both view models now compose it (`resultSetScope`) from what the run recorded with the rows: the ceiling that fetch ran under, and the engine it ran through.
- **#1584.** On iPhone and iPad a complete browse of 1,000 to 7,499 documents reads as a plain count, and a working corpus saved from it is a whole capture. Seen in the app on a full index: a topic of 1,976 documents reads "1,976 results" where it read "1,976 loaded · 1,976 total", and its save sheet carries no warning.
- **#1595.** On the Mac a full Meaning list no longer draws the orange advisory or its triangle: the window's truncation flag asks the shared rule, and the rule answers that a ranking has no larger match to load.
- **#1596.** On the Mac, Visualize in Corpus Analytics is offered in Keywords mode only, as on iPhone and iPad.
- **#1597.** On iPhone and iPad, switching to Meaning over a browse clears its rows and shows the Meaning prompt, as the Mac does, and switching back runs the browse again. Seen in the app.
- **#1598.** A working corpus saved from a Meaning list is recorded as "Meaning search — the N closest matches", its save sheet says the documents are the closest matches and not every document on the subject, and its stored flag is the partial one, so the corpus lists and the method appendix mark it. A corpus already saved from a Meaning list keeps "Search results": nothing on the record tells it from a keyword capture.
- **#1592.** While Checklist Mode is on and Log Research Sessions is off, a line under the count says that opening a result does not hide it and that Mark Reviewed still does. Seen in the app.
- **Three more, found on the way and fixed.** A hand-off that names a search (Find all mentions, a topic, a chart's documents link) runs as a keyword search whatever the picker showed, on both platforms: with Search on Meaning, a browse hand-off had landed on "Type a question or phrase to search by meaning." On iPhone and iPad a topic card's Find documents on this topic now brings Search forward: it had run the search and left the reader on Topics. And the model offer in Meaning mode no longer opens "Keyword search found nothing".
- **#1608, diagnosed and left open.** The panel in the report is the designed refusal for a session whose language check found no working lemmatiser; nothing in the Collocates code is at fault. Which of the engine's three paths the owner's iPhone takes can be read only from that phone's log, and the issue now says how to capture it and what each answer means. If it is the path the simulators take (the first request never answers, and a relaunch works), no change to the check can fix it, and the remedy is a second reference counted as printed, which is a lane of its own.

**Pull request 6, done (2026-10-09): #1583, #1585, #1586, #1587, #1588, #1590, #1593, #1594, #1602.** No index bump, no CloudKit deploy and no re-index. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was run.
- **#1583.** A Corpus Analytics comparison begun from the table is a chart in % of documents, with the chart segment selected and both Values choices live. Every gate reads the display on screen where it read the chart/table control's stored value. Run in the app as a UI test: on the old code Table stayed selected and both choices were disabled.
- **#1585.** A collection's Word export carries the word-cloud overview when the collection asks for one. The format builds the options its exporter is handed, and a test exports through them. Seen in Quick Look's drawing of the exported file; not opened in Word or Pages.
- **#1586.** Related Documents groups its container's size: "… · 1 of 1,063" on the chip and "the first 120 of 1,063 documents" under a cut pool. One entry leaves the count scan's baseline, which is 290.
- **#1587.** All eleven About the Series charts give VoiceOver an Audio Graph of the numbers they plot. Publication lag plays each volume's lag against its publication year where it played the publication year; the five charts that had none have one; the two stacked charts play one series per region or kind of collection. Not heard on a device.
- **#1588.** About These Figures says "about a hundred and ninety collections appear only under pointers", and a test recomputes both of the sentence's rounded figures from the bundled indexes (1,017 and 189).
- **#1590.** The first Use as Template or Duplicate of a visit to Settings ▸ Summarization opens the copy. Run in the app as a UI test on iPhone: on the old code Choose a Template came up over a blank editor. The Mac pane is fixed the same way and was built, not run.
- **#1593.** Add to Collection lists a smart collection under "Smart collection. Its documents come from its saved search." and does not take the tap.
- **#1594.** The confirmation toast posts its words to VoiceOver, half a second after it appears and at high priority. Not heard on a device. A toast replaced by another inside 2.6 seconds was cleared at once by the first one's task; it now stays.
- **#1602.** Text inside a reader highlight is drawn in black (light) or white (dark), at least 5.08:1 over every tint. The wash behind a footnote a cross-reference arrived at keeps every text colour at 4.63:1 or better, and is fainter for it: 1.15:1 from the page where it was 1.32 in the light palette, and 1.30:1 where it was 2.02 in the dark. Five rules of the collection HTML export's own layer reach 4.5:1 (the issue listed three), and a link inside an export's highlight takes the highlight's text colour. Both were looked at in the iOS web view. The export's contents links stay without an underline. The reader's stylesheet is the kit's, so the web edition serves the two new variables when its pin moves.
- **Filed from it, none of them fixed here:** #1616 (on a device whose region writes decimals with a comma, the Corpus and Person Analytics Audio Graphs play some shares ten times too large), #1617 (a categorical Audio Graph's points are given a number for their x value; whether VoiceOver minds was not heard), #1618 (Related Documents' Beyond your library counts are ungrouped and have no singular form), #1619 (the collection editors still take hand-added documents into a smart collection, and neither Collections list says a collection is smart: #1593's two open questions) and #1620 (on an iPad simulator under iOS 27.0, a UI test that opens Corpus Analytics is killed with the simulator: `v2`'s own `AnalyticsKeyboardTests` fails 3 of 3 on a newly booted iPad mini, so that row of `CLAUDE.md`'s index cannot be read on this Mac; it belongs with pull request 7's subject).

**Pull request 7, done (2026-10-09): #1568, #1600, #1601, #1604, #1606.** Tests, one test seam in the app, one access level in the kit, one generator, and one line of the download manager that the full run found. No index bump, no CloudKit deploy, no re-index, no manual edit. The session entry in `DEVELOPMENT-PLAN.md` has the traces and the mutations.
- **#1568 was the test's, not the reader's.** Traced in the page from a shut-down simulator, two runs in six failed, and in both the script that brings a revealed note back never ran after the image arrived. What failed was the test's own `scrollTo(0, 0)`: a few milliseconds after the reveal the page reported position 0 again, so the scroll did nothing and the simulated reader never left the note. The test now scrolls where a finger does, in the web view's own scroll view, and waits for the page and the scroll view to agree before and after. 10 runs of 10 from a shut-down simulator pass where 1 in 3 failed, and it still fails when the page stops listening for the wheel.
- **#1606.** The simulators on this Mac refuse a process its own log store; a Mac process on the same machine reads its own. The sync monitor takes its system-log read as a parameter, so what it does with one is tested without the store, and the one test that needs the real store records a known issue where the store cannot be opened. The suite is 14 tests, green with 6 known issues, in a second where it took 22. **A full unit run on this Mac is green again.** Not known: whether the shipped app is refused on a device or in the Mac's sandbox. The owner's check from the issue stands (the Mac's Sync Log after any sync event).
- **#1601.** The metadata-order test reads the order where the pipeline is held at its first batch, for both of its entry points, in place of two tasks' clocks. Three full `swift test` runs passed.
- **#1604.** All 34 test files that walk a source folder without `AppSourceTree` were read. Four had a rule a kit file could break and read the kit now (the precompute removal scan, the unit-noun scan, the citation-engine scan and the SF Symbol scan): with one violation planted per rule, `v2`'s scans passed and these fail. The reading is kept as two tests: the list of directories the app compiles is held to `project.yml`, and a test file that walks the app's folder alone must be on a list, with its reason. A new test builds the app's pipeline and requires its Spotlight donor.
- **#1600.** `TaxonomyGenerator` leaves the bundled file as it was, and exits 1, when the page gives no tags, a tag outside the three categories, or a list missing more than one in ten of the file's slugs. Against the live page it still writes the bundled file byte for byte: 508 tags. The issue's second step, a source that outlives the page, is #1622.
- **#1620, looked at and left open.** It follows the iOS 27.0 simulator: one build, a newly booted iPad mini, `AnalyticsKeyboardTests` killed 3 of 3 under iOS 27.0 and passed 3 of 3 under iOS 26.5, where the index row's three suites and `AnalyticsCompareFromTableTests` then ran 10 tests with no failure. The row is read on `OS=26.5`; `CLAUDE.md` and the runbook say so. Its cause is not found.
- **Found by the full run, and fixed.** A volume update that landed while one of its images was in flight could lose that image: the image is written through a temporary file in the volume's figure folder, and the update's own run, pruning the images its text no longer names, removed it. The prune now removes images only. One test had been failing 2 runs in 12 for it; sixty iterations lost the image 15 times on the old prune and never on the new. On a device the loss repaired itself at the next launch.
- **The week's queue is done.** Fifteen issues stay open when this merges: the index bump's four (#1535, #1536, #1599, #1613), the two features (#1576, #1577), the owner's two (#1545, #234), #1608 (diagnosed, and waiting on a log from the owner's iPhone), #1620, and five filed during the week and not started (#1616, #1617, #1618, #1619, #1622).

**After the queue, done (2026-10-10): the documents upstream restored to 1952–1954, vol. IX, Part 1.** HistoryAtState/frus pull request #471 (2026-10-09, corpus `99d851c79`) put Documents 900–946 and pages 1661–1741 back into `frus1952-54v09p1`, citing the report filed as HistoryAtState/frus#469, whose first item they were. No app code, no index bump, no CloudKit deploy and no re-index; one tool fix. The session entry in `DEVELOPMENT-PLAN.md` has the method and every measurement.
- **What a reader gets, in any build.** Updating the volume in Volumes & Storage brings the 47 documents. The kit's own pipeline, run over the volume at both commits, stores the 899 older documents column for column as it did and the 47 with their numbers, headings, datelines, dates and source notes. Three were opened in the reader on a simulator: a telegram, a letter with its postscript and enclosure, and an editorial note.
- **The bundle is at the new corpus.** Seventeen files in `Resources/`: the manifest (one size), the broken-reference index, the collection authority (two lots gain the volume), collection usage, external citations, provenance flow, resolved edges, source provenance, the administration profiles, the three word-cloud files, and the five semantic files. Each regenerated file differs from its predecessor only where the 47 documents are, and the unchanged generators over the corpus as it was reproduced the shipped files byte for byte first. Volume sources came out byte-identical and are untouched.
- **Broken references: 652 → 300.** The 352 that left are the second part's back-of-book index entries for the restored pages, 71 distinct targets. They were never rows of `cross_references` and the app draws no index, so no link and no graph changes with them; the report export in Settings is where they were.
- **The vectors and the shards.** Two volumes were embedded again on this Mac under the unchanged contract: `frus1952-54v09p1` (899 → 946 rows) and `frus1902app1` (198 → 196, the two phantom rows §0c's pull request 1 left for the next re-pack). The vectors, the map and the per-volume counts agree on **314,616** documents. The provenance digest is unchanged and 551 of the 553 shards are byte-identical. On the owner's word the two re-packed shards were pushed to `joshbotts/frus-semantic-vectors` the same day and read back byte-exact at the address the app fetches. That repository's own README, manifest copy and description, which had said 552 shards since 2026-09-09, were brought up to date the same day (`38793f0`), and the release plan's step 13a keeps them so. **Until build 50 is out, builds through 49 refuse a fresh download of those two shards** and score those two volumes from the bundled tier; a copy already on a device is kept. The web edition's pinned manifest disagrees the same way until its pin moves.
- **The map is a new partition** (owner decision D-2 of the release plan: relayout every release). 172 regions where there were 171, and 92,268 documents between regions where there were 89,449. Of the documents on both maps 79,067 changed between a region and none, and 349 of the 570 label terms carried over. The picture kept its orientation and a document moved a median 4.7% of the map's width. The 47 landed in one region, `israel, israeli, arab, uar`, with their neighbours in the book. No label is made of general words. **The labels are owed the owner's reading before build 50.**
- **The report.** At the new commit its missing-documents item is corrected, 352 of its 653 cross-reference rows are gone and none is new, and every other class stands as filed. `tools/oh-report` found one row by a line number and so reported it gone while it stood; it finds the heading from the chapter's own tag now, and its output at the report's revision is unchanged.
- **Not done.** The 47 documents have no subject tags: the Office of the Historian's subject export of 2026-08-20 stops at Document 899. Nothing is posted to HistoryAtState/frus#469. On a simulator the new build discarded the old shard at launch and kept the untouched one; the download of the new one was not driven there. The Mac app was built, not run.

**The two features, begun on the owner's word (2026-10-10).** The order: #1577's lane 1, then #1576's lanes, then the rest of #1577. Each lane is one pull request based on `v2`, through the serial queue.
- **#1577 lane 1, done (2026-10-10): a Meaning search ranks inside a document set.** With a working corpus applied or a project's History scope on, a Meaning search scores every document in the set and lists the closest, where it had taken the series' closest hundred and discarded what fell outside. On `v2` the same search of a synthetic corpus listed 0 rows and reported 100 removed by filters; it now lists the set's members in brute-force cosine order. The strip, the empty state and the iPhone pre-search prompt say where the ranking ran, a trail row signs the set, and two timing lines are written to the system log. No interface is added, no shared kit file is edited, and there is no index bump, CloudKit deploy or re-index. The session entry in `DEVELOPMENT-PLAN.md` has the rest.
- **#1576 lane 1, done (2026-10-10): Mark Page Reviewed, with Undo.** Checklist Mode shows a strip whenever it is on, on all three platforms: a line that counts what is hidden, Mark Page Reviewed, and Undo, which is always drawn and dimmed until there is a page to bring back, so that neither button moves when a page is marked (a departure from the plan's "after a bulk mark, Undo", stated in the pull request for the owner to accept or reverse). Both buttons are dimmed under a reading with no page. On iPhone and iPad the marks survive a re-run of the same search, as on the Mac, and on every platform two browses with no words are the same search only when they are of the same person and subject (the owner's decision 4). No index bump, CloudKit deploy, re-index or shared kit file.
- **#1576 lane 2, done (2026-10-10): Add to Collection from a result row.** A result row's menu adds its document to a collection through the existing picker, on all three platforms, and on iPhone and iPad the row has the command as a VoiceOver action; a document the collection already holds is skipped (the owner's decision 3). `CollectionDocumentDiscovery.appendDocuments` is the write lane 3's selection will use, with the 1,000-document limit (decision 5) held in it, and `BulkResultRequest` freezes the documents when the command is chosen. Three changes reach the picker's older modes too: a row takes a tap anywhere on it, the list keeps the order it opened in, and a presentation adds once. Two departures from the plan, both stated in the pull request: the Mac row has no VoiceOver action of its own (its menu is the route), and the UI test adds to a seeded collection, not one made through the editor. No index bump, CloudKit deploy, re-index or shared kit file.
- **#1576 lane 3, done (2026-10-10): select results on iPhone and iPad.** A reader selects search results from More ▸ Select Results or a row's Select, in a selection bar that takes the actions bar's place (Done, the count, a Select menu and an Actions menu), and adds the selection to a collection or, in Checklist Mode, marks it reviewed. What a command did stays as a line above the results, with Undo. **The commands are the Actions menu and not a bar at the foot: the plan's rule, applied.** The bar was built and the fit suite measured it; on an iPhone SE at the largest accessibility size, with the tab shell's banner showing, Mark Reviewed drew under the banner, and at the third size no result showed above the bar. The figures are in the pull request and the runbook, and the assessment's head says what to read for "bottom bar". **It also repairs lane 1 at large text.** With Checklist Mode on at the accessibility sizes and the banner showing, the count header and the strip were taller than the results' room: the mode picker drew behind the search field and no result showed. Those rows now scroll where they would take more than their share (`SearchView.resultsColumn`), and a layout at the navigation root keeps a reading that cannot give way, Collocates, from moving the bars (`TopAnchoredOverflow`). Two review passes, on two diffs, since the redesign came after the first. No index bump, CloudKit deploy, re-index or shared kit file. Lane 4 is the Mac; lane 5 puts Add Tags in the Actions menu.
- **#1576 lane 4, done (2026-10-10): select results on the Mac.** A titled Select button in the Search window's titlebar, beside Checklist, gives every result a checkbox and brings up a strip above the list: the count, a Select menu, Add to Collection… and (in Checklist Mode) Mark Reviewed as buttons, what the last command did with Undo, and Done. A click on a checkbox checks it and a click elsewhere on the row still opens the document; Space checks the highlighted row; a checked row's menu, with others checked, adds the selection. The window loads up to 7,500 results, so All N Shown is often over the 1,000 one add takes, and the strip says so. **The selection's rules are one value both view models hold** (`ResultSelectionSession`): the Mac's half has no test that runs, so its view model is the iPhone's line for line, and a scan reads the two against each other. **The Mac was run, in the isolated check copy** (`tools/mac-check-copy/`, 27 volumes), and the lane's list walked there; that and the review found a line offering to undo marks that Checklist Mode had already forgotten, a Select button dimmed while on, and a Mark Reviewed that could mark the last search's rows under the next search, all three fixed in the lane. The titlebar folds its buttons into its » menu from the right, measured on this lane and on `v2`: Select shows as a button from 1,140 pt of width, Facets from 1,170 where it showed from 1,090, and at the 820 pt the window opens to all the trailing buttons are in the menu, as the three were before. Left for the owner: VoiceOver heard aloud, dark mode, Full Keyboard Access, and a search that fails. No index bump, CloudKit deploy, re-index or shared kit file.
- **#1576 lane 5, done (2026-10-11): Add Tags, to one result and to a selection.** Add Tags… is on a result row's menu on both platforms, in the iPhone's Actions menu and in the Mac's strip. It opens the tag picker in a new adding mode, titled "Tag 37 Documents", with every tag off and beside each how many of the documents carry it; Done adds the tags switched on and takes none off. `UserTagAdmin.assign` makes one fetch of every assignment, inserts only the missing pairs and saves once; a fetch that fails stops it, and the 1,000 limit is the collection's. The tagged rows show the tag at once, a line says what was added, with Undo, and each store write is followed by a rewrite of the index's tag column, the rewrites in the order asked. **The launch-sync clear the plan gave this lane was already on `v2`**, from #1591's own fix (#1614, `DocumentTagAssignment.reconcileTagColumn`), so the lane adds none and closes no issue. No index bump, CloudKit deploy, re-index or shared kit file.
- **#1576 lane 6, done (2026-10-11): the notes.** Both user manuals now say the two side effects of a bulk command. Documents added to a collection that is filed under a project become part of that project's History from the next time the filter panel is opened, and a Focus search with Only new to this project on then leaves them out. A bulk tag reaches another device's My Tags filter once iCloud has delivered it: **a few seconds after the sync when the app is open there, and not at its next launch as the plan had it**, since #1614 reconciles the index's tag column when an import settles. The bulk-actions part was read as a whole, and two gaps closed: Select joined the iPhone manual's list of a row's menu, and Space the Mac manual's table of the Search window's keys. **Still owed, at the next build bump: the TestFlight notes for #1576**, which the plan leaves to that bump (Mark Page Reviewed with Undo; Add to Collection and Add Tags from a result's menu; selecting results on iPhone, iPad and Mac).
- **#1577 lane 2, done (2026-10-11): one recorded route for the list on screen.** Most of this lane landed with #1615, which fixed the five defects the plan gave it. What was left is in: `ExecutedSearchRoute` (keywords, meaning, words in matches, ranked by meaning) takes the place of `ResultSetScope`'s Meaning flag, both view models write it beside every assignment of the rows, and the two places a window still asked the Keywords | Meaning picker about the rows now ask it: the facet panel's count, wording and keys, and the readings' control, which needs the field's engine to be Keywords and the rows to be a keyword match's. A reader can see that only between a switch of the picker and the new rows. One thing shows at rest: one result reads "1 result" on iPhone and iPad, where it read "1 results". **The two layered routes have their header and capture sentences now and no search produces them yet**; lanes 4 and 5 are to adopt them. No index bump, CloudKit deploy, re-index or shared kit file.
- **#1577 lane 3, done (2026-10-11): a UI test can reach a Meaning result.** `FRUS_UI_TEST_SEED_MEANING` (DEBUG only) has `UITestMeaningSeeder` stand in for the query encoder and build the searcher over a match-file store of the seam's own, which holds one file made for the seeded fixture volume; the searcher's code, the backend and the bundled index and sign bits are the app's own, and the app's match-file store is not read or written. Both stand-ins are made of bundled sign bits: every question is answered as the fixture's second document, so a plain Meaning search lists its three documents that have vectors (100, 65 and 61 percent), and a question that holds "afield" is answered as a document of another volume, which reaches none of them outside a set and all three inside a working corpus. `MeaningResultsSeamTests` reads those on an iPhone 17 and an iPad Pro 13-inch, and **on the tree before lane 1 its working-corpus test lists none**, which is the plan's control. The figures are held against the bundled artifacts by a unit suite, so a regenerated bundle fails there first. One thing a reader gets: on iPhone and iPad VoiceOver reads a ranked result's score after its heading, where the chip was silent. **For lane 4:** a plain Meaning search under the seam lists exactly three fixture documents, the titles ending One, Two and Three, so a keyword such as Two is in one of them and not the others. The search has 78 hits, of which those three are in the index: the strip counts the other 75 as not listed, and 722 candidates in 179 volumes as unscored.
- **Owed by the owner before #1577's lane 4 starts:** three timings on an iPhone with the search model downloaded, read in Console from `subsystem:bottsywattsy.FRUS-Explorer category:SearchTiming`: a Meaning search inside a working corpus of about 1,000 documents; the same inside a 7,500-row browse saved as a corpus; and a common word in Keywords mode inside a 100-document corpus.

**Two of the five issues filed during the week, done (2026-10-11): #1616 and #1618.** One pull request under this section's rules, and the first since the review of this plan the same day. No index bump, CloudKit deploy, re-index, shared kit file or manual edit. The session entry in `DEVELOPMENT-PLAN.md` has the measurements and the mutations.
- **#1616.** The Corpus Analytics series table and the mention-trajectory table state the numbers their charts plot, as the About the Series tables have since #1587, so VoiceOver's Audio Graph reads no cell of theirs. Measured first: where decimals take a comma (`de_DE`, `fr_FR`) a share of 12.4 is printed `12,4`, and the descriptor's reader made that 124, as the issue said. A share is played to the one decimal its cell prints; a year the chart does not plot is not played, where its empty cell used to refuse the whole graph; and one person charted is still spoken under that person's name. The issue's third question is answered by reading: the eight other tables an Audio Graph still reads by column hold plain integers. **Not heard on a device.**
- **#1618.** Related Documents' Beyond your library section groups its four counts and has a form for one: "At least 4,096 documents in 12 volumes …", "1 document in 1 volume … reads as close", "1 matching document", "and 1 more volume". The four lines are `RelatedDocumentsCounts`' and leave the count scan's baseline, which is 286. Seen in the app on an iPhone 17 simulator holding the one seeded volume: "At least 4,096 documents in 404 volumes …", five rows of "N matching documents" and "and 399 more volumes". The three forms for one were not met there and are held by tests.

**A third of the five, done (2026-10-11): #1622.** Tooling alone. No file the app compiles is changed, the bundled taxonomy is byte for byte what it was, and there is no index bump, CloudKit deploy or re-index. The session entry in `DEVELOPMENT-PLAN.md` has the measurements and the mutations.
- **Two sources.** `TaxonomyGenerator` reads `taxonomy/taxonomy.xml` from the public HistoryAtState/tags repository, the file the site's page is drawn from, and then the page when the file gives nothing to write. `TAXONOMY_SOURCE` names one source and stops there. Each goes through #1600's gate, and a run in which neither gives a taxonomy leaves the file as it was and exits 1.
- **Measured with the tool itself:** from the file, from the live page, and from the file over no file at all, the bundled taxonomy byte for byte, 508 tags. A copy of the file (HistoryAtState/tags at `0e701226`, public domain) is committed as a test fixture, and a test fails when the copy no longer writes the bundled file: the two are committed together from now on, as the runbook's entry says.
- **The file first is this session's choice.** The issue allowed either order. The other is one constant (`TaxonomySource.automaticOrder`), and the pull request says what each means.
- **For the owner: `lgbtq-rights`.** The file holds it inside a comment, so neither source gives it. Four volumes of `manifest.json` carry it, and the bundled taxonomy has no name for it. Whether it joins is the owner's to decide.

**The index bump's brief, and #1535, done (2026-10-11).** The owner asked for the index-bumping sessions to begin, five days before the brief's date. The brief is `Planning/Index-Bump-Brief-2026-10-11.md`; the session entry in `DEVELOPMENT-PLAN.md` has what was run.
- **#1535 needs no index change, so it left the bump and is fixed here.** The parser already promoted a prose-only chapter, subchapter or compilation, and each was an indexed row that Search found: 1,136 sections in 144 volumes, counted in a full index. Browse refused them because `VolumeSection.proseReadableKinds` left the three kinds out. They are in, so such a section shows the Read button a preface shows on iPhone and iPad and opens in the reader on the Mac. Kit code; no version, no re-index, no CloudKit deploy. Both manuals gain a sentence.
- **The bump is three pull requests in series**, as build 49's versions 63 to 65 were: A (version 66) takes #1613 with the small stored-value corrections, B (67) takes #1599, and C (68) takes #1536. A reader re-indexes once, at the build that carries all three, and a build is cut before the first merges or after the last. *(Since the owner's answers, below: four pull requests, D at version 69, and build 50 carries them.)*
- **Measured for the brief:** #1536 is 1,332 sections in 137 volumes at corpus `99d851c79`, 485 of them the list of those present at a meeting in five wartime conference volumes; #1599's 1,041 pointers all resolve, and history.state.gov lists a document's people and terms in its sidebar from them; #1613's 6,944 rows are drawn as placeholder nodes in a document's graph and counted by nothing between volumes.
- **Found while measuring, and in the brief:** 17,087 rows store a reference to a footnote as an edge to a document named after the note, so a document cited through a note does not list the citing document; 80 web addresses and 46 mail addresses are stored as cross-references; and the film sections' leaked player text is 2 rows, not 12.
- ~~**Six decisions wait on the owner**~~ *(answered 2026-10-11, below)* (the brief's §4), each with a recommendation a session takes if none is given: how a section's own text is kept, where vol. XVI's people and terms show, what a whole-volume reference becomes, whether references to a footnote are corrected, which leftovers are taken, and whether build 50 goes out before the bump.

**The owner's answers, and the bump's pull request A, done (2026-10-11): #1613, index version 66.** #1637 merged, and the owner answered the brief's six decisions the same day: the first five as recommended, **build 50 carries the bump**, and the Subject-Numeric files the brief had declined are **pull request D**. The brief's §4 records each. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was run.
- **What a re-index now stores.** A cross-reference to a footnote is an edge to the document that holds the note, and one to a whole volume is a volume-to-volume row with no document. A web or mail address is not stored. A glossary term and its definition are stored without the source's line breaks, the two film sections of `frus1917-72PubDip` without the video player's text, and a persons-list year after "until January," as the end it is.
- **Measured through the kit's own extraction** over the 553 catalogue volumes at corpus `99d851c79`: 185,529 rows where version 65 collected 185,655, the 126 between them being the addresses; 17,088 rows settle as a note's document, in 232 volumes; 6,944 as a volume, in 406, of which 5,688 name a catalogue volume, 1,256 one of 57 volumes outside it, and 249 the citing volume itself. No term or definition of 66,203 holds a line break. Ten persons-list entries in six volumes change their years, every one an "until Month, year".
- **The 6,944 are below the corpus's 8,266** because the index collects a reference only inside a document or a section it holds. The other 1,322 are in text it does not hold, a section's own text (#1536) among them; they were not broken down.
- **Seen on iPhone:** a document that cites one document and one whole volume lists the one document, and a document two others cite through its footnote 4 lists both. **On the Mac the check copy re-indexed itself from version 65 to 66 on launch** and its index holds the rows above for one volume, read by SQL; the Mac's screen locked before its graph could be clicked.
- **No bundled file changes.** `CrossRefKit` and the generators that read the corpus themselves are as they were, so the bundled resolved-edge index still leaves out the 273 references to a footnote in another volume.
- **Left open:** the volume graph now holds 1,256 references to volumes outside the catalogue where it held 12, and how it draws such a volume was not looked at. *(The Mac walk was made with pull request B's, below.)*

**The bump's pull request B, done (2026-10-11): #1599, index version 67.** #1638 merged, and the owner asked for B. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was run.
- **What a re-index now stores.** A document's `@ana` pointers into its volume's persons list are person mentions. 1981–88 vol. XVI is the one volume that names its people that way: 622 mentions, of 117 of its 120 people, in all 88 of its documents, where the index held none. Measured through the kit's own parser over the 553 catalogue volumes, no other volume carries the attribute and no other volume's mentions change.
- **What the reader shows.** Such a document ends with two lists below its footnotes, **Persons** and **Abbreviations & Terms**, as history.state.gov shows them beside it. Each entry is the link an inline name or term would be and opens the same card. The lists are outside the document's text: no stored highlight, `body_text` or rendering version moves, and an export writes none.
- **Found on the screen and fixed here:** the first build listed the names and answered a tap with "Person Information Unavailable", because the app answers a link from the links of the page it registered and these are in no node of the page. The listed entries now carry the volume's own entries, and the handler registers them.
- **Seen on iPhone and on the Mac.** Document 368 lists its 7 persons and 5 terms; a person opens the card with the role the volume's list gives and the count of documents that mention them (20 in the volume), and Find all mentions lists those 20. The Mac's screen was unlocked, so **pull request A's Mac walk was made too**: a volume's connections graph draws the six volumes it cites only as wholes, a document's graph has no placeholder for one, and a document cited through its footnote shows the two that cite it.
- **For the owner: the session opened the installed app by mistake.** A deep link meant for the Mac check copy went to `/Applications/FRUS Explorer.app`, which launched and was asked to open 1981–88 vol. XVI, Document 368. It was quit about fifty seconds later. If research logging was on, that document is in the active project's History. The check copy's README now says never to open a `frusexplorer://` link from the shell.

**The bump's pull request C, done (2026-10-11): #1536, index version 68.** #1639 merged, and the owner asked for C and for the two Mac walks that were owed. The session entry in `DEVELOPMENT-PLAN.md` has the method and what was run.
- **What a re-index now stores.** A section that holds documents and prints text of its own has a row for that text under its own id: its heading and what is written directly inside it, and none of what its documents hold. By two full indexes of the 553 volumes, built through the kit's pipeline from `v2` and from the branch and compared: 1,337 rows in 139 volumes, 1,421,459 characters, and no other row changed. Most are the lists of those present at the wartime conferences' meetings.
- **What a reader meets.** Browse lists the text first in the section, as a **Read** row above its sections and documents, on both platforms. Search finds it, and the reader's Previous and Next reach it before the section's documents. A person named in a list of those present is mentioned there: 4,461 mentions in 358 sections. Brigadier General Esposito attended seven of the Joint Chiefs' meetings at Potsdam and is named in none of their minutes: no mention in that volume at version 67, seven at 68.
- **Pages.** A page break is the section's only when its own text follows it. 208 pages in 20 volumes that named nothing now name a section, no page moves from a document to a section, and two page references that led nowhere now open the section that prints the diagram they cite.
- **The reader's page for a section is the row the index holds.** A parse for one section now decides it as the index does. For the 33 sections #1510 gave a row, the reader had opened the section with everything inside it. A section the index leaves out still opens whole.
- **Seen on iPhone and on the Mac.** A Potsdam meeting shows the **Read** row over its one new sentence and above its documents; the row opens the list of those present with each name a link, and turning forward reaches the minutes. A search for "Esposito" returns seven meetings' lists.
- **No bundled file changes.** The resolved-edge index takes only references inside a document, so it lacks the 383 that sections' own text makes to documents of other volumes.
- **The two Mac walks that were owed were made**, in the check copy at pull request B's commit: #1576's lane 5 (Add Tags) passed every check, and #1577's lane 2 passed the five that need no search model. The one check left needs a Meaning list, and the copy has no search model.
- **Left open:** "No documents in this section." still shows under a section that holds only sections on iPhone and iPad, because `BrowseNestedSectionTests` reads that sentence as its proof that a load finished; a meeting's row does not say its day; and text the index still does not hold was measured and is listed below.

**Between C and D (2026-10-11): the suite's two failures, and the Mac check that was owed.** #1640 merged, and the owner asked for the two `BrowseNestedSectionTests` failures of C's run to be found and resolved, and for the search model in the Mac check copy, before D. The session entry in `DEVELOPMENT-PLAN.md` has the measurements. No index version, and nothing a reader meets.
- **The two failures were two things.** Each test held a seam back for a number of seconds counted from launch, 25 and 30, and the walk to the compilation took 46 to 50 that day; the seams now wait for a signal the test sends once it has seen the screen its premise names. And a run's first test could open on the onboarding wizard, in a process that had none of its launch arguments: the system opens the app in the background when a Live Activity is dismissed while the app is not running, and a test's launch that arrives then is given that process. Four installs stopped an activity an earlier run had left, and the launch after each was the one.
- **A test's process now starts no Live Activity** (`LiveActivityPolicy`), which is the only change outside the DEBUG seams, and holds in a unit test's host and a UI test's app alone. `TabBarNavigator` names the cause for the cases the rule cannot reach, and `CLAUDE.md` has it as the fifth rule for every UI run.
- **The suite's walk opens the fixture's own subseries, by name.** It took the first row labelled "Subseries", and the iPad Pro 13-inch under iOS 27.0 holds two real 1964–68 volumes from other work, so the suite's first test failed there until the walk asked for "Subseries 1961-63". Four other UI suites still take the first row.
- **A typed search is waited for in its field.** On that iPad the suite read "Bator Pape" where it had just typed "Bator Papers", and stopped on its own precondition.
- **#1577 lane 2's last Mac check is made**, in the check copy, with the owner's leave for the 229 MB search model and for the Gemma terms the app's own sheet asks a reader to accept. During a switch from a keyword search to Meaning the facet panel went on describing the keyword rows ("Describing all 364 matches") while the header read "Searching…", and described the Meaning list when it arrived ("Describing the 14 closest matches"). The switch closes the panel and the search took under a second, so the panel was read as it closed and not opened again by hand.
- **Left open:** a reader's Live Activity that nothing ends, when the app is killed while it indexes. Read, not filed.

**Where the queue stands — 2026-10-11.** Read against `v2` @ `8be12f5d` and the tracker, after #1536 merged as #1640. Seven issues are open, and one pull request, the one for the paragraph above. Upstream was at `99d851c79`, the corpus the bundle is at, when last read that day.
- **In hand:** #1577, lanes 4 to 7 (above), behind the owner's three timings.
- **Next, and the session that wrote the paragraph above begins it:** the index bump's pull request D (Subject-Numeric designations, to be filed), from the brief's §3.7. It starts with a measurement. No Mac walk is owed: pull request A's was made with B's, #1576's lane 5 and five checks of #1577's lane 2 with C's, and lane 2's last with the paragraph above.
- **Waiting on the owner:** #1608, for the iPhone's log, which decides whether the printed-form reference of §0 (LANG-D) becomes a lane; #1619's two questions about smart collections; #1617, which needs an Audio Graph heard on a device; #1545; and #234.
- **Left open on purpose:** #1620. It follows the iOS 27.0 simulator, and its suites are read on `OS=26.5`.
- **Build 50** is not started. Owed before it: the TestFlight lines §0b lists, with #1576's (lane 6, above), a line for #1535 (a chapter of prose alone opens in Browse) and one line of fixes that takes in #1616 and #1618 (#1622 changes nothing a reader meets); and the owner's reading of the map's 172 labels. **Decided by the owner on 2026-10-11: build 50 carries the index bump**, so it waits for pull requests A to D. Until it is out, builds through 49 refuse a fresh download of the two re-packed shards (above).

**Found since 2026-10-09 and not filed.** Each is in the "Not done" list of the session entry named, in `DEVELOPMENT-PLAN.md`; none is designed here. §0a's "Not placed" is the same list for the build-49 wave, and of that one four items were read again on 2026-10-11: `FilterChip` and `CrossProjectNoteIndicator` are still the two views nothing constructs, the 14 Swift files outside every target still have no license header, 9 Swift files still cite #1210, #1211 or #1257 where 22 did (`CLAUDE.md` cites none), and `subject-numeric-labels.json` still states 1,362 keys.
- **On the Mac, a hand-off or a saved-search recall searches the whole series under the "Inside …" banner.** `MacSearchViewModel.applyParameters` clears the document gate from the parameters a search runs with and leaves the applied working corpus in the filter view model, which is what the banner reads; the corpus comes back only when the filter panel derives the gate again. Read on `v2` @ `9d247985`, not run. #1577's assessment calls it a defect that deserves its own issue, and the file is one its lane 5 edits. (#1577 lane 1)
- **On iPhone and iPad, after a launch straight onto Search, Filters shows no My Working Corpora, no volume scopes and no subject section** for that launch: `SearchView` asks for the indexed volumes once, as it first appears. Seen once. (#1577 lane 1)
- **A search that a later one has superseded is not dropped**, in `SearchService` or `FTS5Store`, so a slow Meaning run can land after the keyword search that followed it. Lane 2 made the screen right for that state and did not prevent it. (#1576 lane 4, #1577 lane 2)
- **Counts with no form for one, or not grouped, outside the results header:** the facet panel's "Describing all 1 matches" and "Describing the 1 closest matches", the capture's caution for a Meaning list of one document, three sentences that say "1 reviewed documents", and the checklist strip's "1852 reviewed hidden". They are in files #1577's lanes 4 and 5 edit. (#1576 lane 4, #1577 lane 2)
- **VoiceOver on iPhone and iPad reads neither a result row's tag chips nor its classification chip.** (#1576 lane 5, #1577 lane 3)
- **Checklist Mode:** Mark Page Reviewed and a row's own Mark Reviewed have the gap lane 4 closed for a selection, a mark made while another search is under way. (#1576 lane 4)
- **Selecting results:** a selection begun while a Keywords or Meaning switch's search is under way lasts into the other engine's list when the words are the same (read, not run); a browse with no words can show All N Shown over the 1,000 one add takes (read, not run); from the picker's empty state, Done on an untouched new collection returns to a picker that still says No Collections (seen once); and on the Mac the volume id and the chips of a highlighted row keep their colours and are hard to read. (#1576 lanes 3 and 4)
- **Wording that pull requests 5 and 6 and #1577's lane 1 left:** the corpus lists say "The capture stopped short of every match" of a Meaning capture; a full Meaning list is recorded in search history as a floor, so the method appendix prints "at least 100"; the appendix's CSV prints `top=100` for a Meaning search inside a set and does not name the set; the Keywords prompt reads "Enter keywords to search the FRUS corpus." with a corpus applied; and the HTML format card reads "Web page + word cloud" though PDF and Word carry the cloud too.
- **From pull requests 2 and 4:** the storage hubs' Index Remaining counts only volumes with no documents in the index; `UserTagAdmin.merge` leaves the index's tag column to the next reconcile; the Archives Visit packet's line for a divided lot cited through the National Archives is unchanged (#1589's optional fourth step); and `CrossRefKit`'s mirror grammar has no whole-volume case.
- **The cost of a relayout** of the semantic map (79,067 documents changed between a region and none when 47 were added) is the owner's to call an issue or not.
- **From the index bump's pull request C (#1536), measured and not built:**
  - A prose section of a kind the index does not promote is not indexed, and Browse says "No documents in this section." of it; the reader's Previous and Next do reach one. `note-on-covert-actions` is 866,558 characters in 45 volumes, `message` 644,638 in 9 (the President's messages of the 1860s among them), and `frus1945-50Intel`'s eight chapter introductions 170,416.
  - 3,516 sections that hold documents have nothing of their own but a footnote on the heading: 471,486 characters and 5,173 cross-references that reach nothing.
  - A section's row carries no date unless its own text prints one (1,227 of the 1,337 have none), so in Search a meeting's row is its heading over the volume's id, and its day is the heading of the chapter around it. Section divisions carry `frus:doc-dateTime-min` in the corpus, which the parser reads on documents alone.
  - Add Documents' list of a volume and the Mac graph window's document picker read the stored order, where a section's own text follows its documents. Read, not seen.
  - No section row has a vector, so a Meaning search returns none.
- **From the two Mac walks made with pull request C:** under Meaning the Reading picker is not drawn dimmed; Collocates' "Within" picker has its label off-screen and its left cap clipped on the Mac, and its caveat prints counts ungrouped ("6387 matches, in 1512 documents"); and #1633's body says its Mac half was run where its session entry and this plan said it was not.
- **A reader's Live Activity that nothing ends.** If the app is killed while it indexes, the activity stays on the Lock Screen until the system removes it, and the app is opened in the background when it does. An activity is taken up again only when an index is running, and nothing at launch ends one that no index is driving. Read in `AppState`, and seen in the simulator's log for a test's app; not seen on a device. (The pull request between C and D)

**Not this week.**
- **One index bump** carrying #1535, #1536, #1599 and #1613, with what pull request 4 hands it. ~~Its brief is written on 2026-10-16.~~ *The brief was written on 2026-10-11 (`Planning/Index-Bump-Brief-2026-10-11.md`, and the paragraph above): #1535 turned out to need no bump and is fixed, and the rest is three pull requests. What follows is as the plan first gave it.* Pull request 4 hands it two things, each a change to what indexing stores:
  - **Whole-volume references are stored as edges to a document named after the volume** (#1613, filed 2026-10-09; #1603's cause, in `IndexingPipeline.collectDocumentRefs`): 6,944 rows of `cross_references` in a full index, in 406 volumes, carry a volume id as `target_document_id` and no target volume. The tap is fixed; the rows are not. What the cross-reference graph and the analytics show for them was not checked.
  - **The terms parser keeps the source's line breaks inside a term and a definition** (#1582's contributing cause): 49,517 of the 66,203 stored definitions and 198 terms. The lookup folds them as it reads; the stored values still carry them, and folding them in the parser changes what indexing writes.
  - **For the brief to take or decline** (added 2026-10-11): §0a records other leftovers that change what indexing stores, and the rule is one bump a build (§0b). They are `body_text` of the 12 `frus1917-72PubDip` film sections, which holds the player's hidden text and script (pull request #1559; read from the code, not from an index), and what lanes PAGE and NOTE left open: the persons list's "until January, 1953", and the Subject-Numeric files stored without a designation, which lane CFPF's v65 may since have changed. None was measured again for this note.
- ~~**#1576 and #1577**, after pull requests 3 and 5, which edit the same search menus.~~ Begun on 2026-10-10 (above): #1576 is closed, and #1577's lanes 4 to 7 remain.
- **The owner's to decide:** #1545 and #234.

## 1. Where the 47 issues stand

*(As of 2026-09-28. §0a has the count at 2026-10-02.)*

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
| **LANG** | #1539 (iOS 27 devices: no lemmas, so Collocates, keyness, shared-word chips and dictionary-form clouds are withheld) | Steps A–C (release warm-up log plus a Settings row; re-check on foreground; no warm-up in background launches, no tagging while a request is in flight). **D is an optional tail item (see Lane order 5)** | S–M | — | the owner's devices (force-quit and reopen ×3, optional Console stream); the simulator's 1-in-4 loss as the control |
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

**Release.** Build 49 ships once Tier 1 and Tier 2 have merged, with **one re-index** (v62 → v65; v64 until lane CFPF, #1543, was added on 2026-10-02 — §0a). Before it:
- the full unit target on iOS 27;
- the build-48 UI suites that were measured only on iOS 26 (`CollectionEditorTitleTests`, `BrowseWithinScopeTests`);
- one full re-index census on a pinned device;
- the window-fronting audit;
- `check_repository_links.py --stamp`;
- the Gemma policy re-check;
- TestFlight notes, with fixes on one line.

**Release preparation, 2026-10-02** (build 49 for TestFlight, on the owner's word; the session entry in `Planning/DEVELOPMENT-PLAN.md` has the figures):
- **Done:** the build is 49; both TestFlight notes are rewritten; the full unit target is green on iOS 27.0 (one test fixed, which Vision on iOS 27.0 misread); `CollectionEditorTitleTests` passes on an iOS 27.0 iPhone and iPad; the re-index census gives 316,768 documents in 553 volumes, equal to the parser replica volume for volume; the window-fronting audit is clean; the link check reports no dead link; the Gemma Terms are unchanged since 2026-04-01.
- **One suite fails on iOS 27.0, and the cause is older than build 49:** `BrowseWithinScopeTests.testBrowseWithinLandsUnderTheBanner` on an iPhone, twice, because the corpus root rests with My Scopes under the "Local Only" banner. That is the app-wide banner over the last row of every tab's list (`MainTabView.swift:175`–`:215`, unchanged since the `build-48` tag). Not filed.
- **Found by the census, not filed:** a volume whose indexing is cut off by an unclean shutdown can keep part of its rows with no interrupted mark, and is then treated as indexed.
- **The CloudKit gate, run 2026-10-02, failed and then passed.** Its first read of Production found fifteen identifiers the inventory attested as deployed and neither Production nor Development held (Development had evidently been reset to Production). They were imported into Development with `cktool import-schema`, the owner deployed them to Production (the twelfth promotion), and the gate passed: Production holds every identifier build 49 can write. `CloudKitSchemaInventory` records it (2.0).
- **Owed by the owner before the upload:** a CloudKit management token and `./Scripts/check_cloudkit_schema.py` (both done 2026-10-02, above); `./Scripts/fetch-llama-dsyms.sh`; the archive and upload; `check_repository_links.py --stamp`; the `build-49` tag; and the by-eye checks above.

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
  - ~~the live NARA catalog decoder misreads series dates;~~ fixed in lane NOTE (#1549), from fixtures: no API key was available to check a live response;
  - Archives Visit derivations go stale when an indexed volume is updated, and an older derivation can finish last;
  - ~~PV-1's sources statement is missing from analytics exports, the trip packet and the method appendix.~~ fixed in lane EXPORT (#1553).
- **Owner-only, outstanding:**
  - three screenshot placeholders, and the Mac and iPad captures build 48 made stale;
  - by-eye checks listed in the build-48 PRs (#1486, #1490, #1501, #1519; Mac hover; iPad Stage Manager);
  - the Topics lens on a physical iOS 27 device;
  - confirming the dSYM warning is gone;
  - App Store Connect: the EULA, the privacy label, the listing (~~its figures predate vol. XVI~~ `Store-Listing-Draft.md` was re-measured at 553 volumes by lane PLAN on 2026-10-01; three sentences of its description still wait on your wording, under its "Open before paste");
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

## 4a. Residue carried from the documents archived on 2026-10-01

Lane PLAN moved twelve finished documents and one folder to `Planning/Completed/` (its README lists them). Each had a little left. This is where that goes; nothing here is scheduled.

- **`Release-frus1981-88v16.md`** (the vol. XVI ingest, build 47):
  - Phase E, deferred by the owner: subject tags and the person crosswalk for the volume, when the upstream drops include it.
  - Lot `95D407` is unresolved. NARA's catalogue does not answer it; retry at the next keyed run.
  - Re-harvest the volume's semantic shard at its next document-count change, deleting its store entry first. `New-Volume-Release-Plan.md` §10 now has the steps.
  - The doubled `)` in d395 goes in the OH report (§5).
- **`Volume-Update-Annotation-Integrity-Design.md`** (R-5, shipped): Q-2 is among §3's older decisions. Unbuilt and undecided: its §9 cases (a side-loaded volume later published, cross-document annotations, exports made before a correction). `CD_AnnotationReview.CD_annotationId` still has no writer.
- **`Archive-Visit-Plan-Design.md`** (built): the "Seeded from …" caption on the plan list waits on a stored field, which is a CloudKit change. The repository link check is on the release list.
- **`Provenance-Tiers-Development-Plan.md`** (wave PV, complete): the archival exports and the provenance dashboard rest on the source-note parse and do not print its residual. `ProvenanceSource.curatedDisclosure`'s doc comment states a premise its own Q-3 refuted.
- **`Open-Issues-Resolution-Plan-2026-09-19.md`** and **`-2026-09-23.md`** (discharged): what they left is this plan.
- **`Plan-Of-Record-2026-08-28.md`** and **`-2026-09-06.md`** (superseded): §4 above summarises what the audit found open in them.
- **`Tier-E-Assessment-2026-08-27.md`**, **`MCP-Server-Assessment-2026-08-31.md`**, **`W12-Parallel-Series-Concordance-Assessment-2026-09-07.md`**, **`Phase-D-on-the-Air.md`**: nothing.
- **Not archived, and why:** the cross-platform review package waits on an owner yes or no to the residue its `STATUS.md` §0 lists. `Vector-Embeddings-Semantic-Design.md` stays at the Planning root because four source files cite it by that path.

## 5. The #1309 report to the Office of the Historian

*Compiled on 2026-10-01 as `Planning/OH-Report-2026-10-01.md` (§0a). This section is the plan's list as written on 2026-09-28; the report re-checked each item, and several of the figures below moved.*

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

*(The 50 issues as planned on 2026-09-28 and 2026-09-29. All fifty have closed since; §0a lists them by lane.)*

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
