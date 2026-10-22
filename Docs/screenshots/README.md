# User-Manual Screenshots

Screenshots embedded in the user manuals (`../iOS-User-Manual.md`, `../macOS-User-Manual.md`).
A manual carries a `` `[SCREENSHOT: …]` `` placeholder wherever an image has not been captured yet;
since S5 of the build-51 sweep (2026-10-21, below) neither manual carries one.

> **Owner decision, 2026-08-23 (issue #1081): every committed capture is treated as stale.** The
> 31 files on disk date from the build 26–42 era and the UI has moved under all of them. Nothing
> on disk is presumed current: every slot a manual or the repo README references gets a fresh
> capture, every placeholder gets a first capture, and the unreferenced files get deleted rather
> than refreshed. **Issue #1081 is the shared tick-list; this file is the how.** The **Capture
> conventions** section below still applies in full. Everything between here and it — the tiered
> shot list and the historical "Captured" / "Remaining" / "New since build NN" sections — is kept
> for its staging notes only; its 🔄/keep triage is superseded, and its `§N.N` pointers refer to
> the pre-rewrite manual layout.
>
> The August 2026 rewrite (first-time graduate-student audience; the iOS manual is iPad-first and
> embeds the `ipad/` captures) also wired in `macos/person-analytics-trends` and `macos/research`,
> which were previously captured but unused.

## Capture ledger — the #1081 sweep, builds 47–48 (2026-09-13 → 2026-09-23)

A screenshot is evidence about a build, so every `ipad/` and `macos/` file is accounted for here.
**This sweep closes #1081 except for three frames**: the macOS Archives Visit packet with its
Options menu and Share buttons, which the branch these captures came from did not draw on the Mac
(#1377 — fixed before build 48 was tagged, so the shipped build does; see "Stale after build 48"
below); and the two
known-hard shots the issue always listed, the Chronology hover magnifier and the Live Activity.

- **Owner, physical iPad, build 47, 2026-09-13** (3180×2384; `cross-reference-graph` is a
  2852×2139 window capture): `research-rail`, `stage-manager`, `browse-root`,
  `browse-all-volumes`, `browse-administrations`, `browse-editors`, `browse-working-corpora`,
  `browse-archives` (the Classes lens), `browse-clusters`, `browse-clusters-detail`,
  `search-results`, `semantic-search`, `analytics`, `chronology`, `cross-reference-graph`,
  `related-documents`.
  - On disk but **not embedded**: `research-rail-portrait` (a portrait variant), and
    `semantic-search-loading`, `indexing-banner-portrait` and `ios/indexing-banner`, which show
    the build-47 waiting cloud. Build 48 changed that cloud (#1346 retired the Actions lens from
    it and added a "searching" label on iOS), so re-shoot those three before embedding them.
- **Simulator, build 48, 2026-09-22/23** — every other `ipad/` file. iPad Pro 13-inch (M5),
  iOS 27.0, landscape, 2752×2064, the `AppStore` configuration built for the simulator, the full
  553-volume corpus indexed on the device, demo status bar.
  - **One local-only patch, never committed**: `SyncStatusBanner.isWorthShowing` returned false
    under a launch argument. A simulator with no iCloud account otherwise shows "iCloud Sync
    Failed" at the foot of every screen, which no reader of the manual would see.
  - `onboarding-volumes` and `series-production` came from a second, **empty** simulator — the
    offline convention below.
  - Demo data, made through the app's own UI: the project "Early Cold War"; the scopes "Berlin
    Crises 1958-1963", "Cuba 1958-1963" and "Soviet Union 1945-1950"; working corpora from
    Keyword searches for "Berlin airlift" and `"long telegram"`; the collection "The Long
    Telegram and Its Readers"; and an Archives Visit seeded from that collection **plus**
    frus1952-54v02p1/d41 and frus1955-57v19/d81. Those two are printed from S/S–NSC Files,
    Lot 63 D 351 *and* cite it in their footnotes, which is what gives `trip-packet` both of its
    claim lists — no 1946 document does. `browse-corpus-drill` shows one gray row because
    frus1948v01p2 was removed from that device on purpose.
  - Paired frames where one screen cannot hold the contract: `browse-archives-collection-detail`
    + `-citing` (the detail runs about four screens), `people-detail` + `-records` (a ~660 pt
    form sheet), and `trip-packet` + `-options` (the open Options menu covers the Share buttons).
- **macOS, build 48, 2026-09-23** — every `macos/` file. An **isolated copy** of the Mac app built
  from the branch: bundle id `bottsywattsy.FRUS-Explorer.screenshots`, `AppStore` configuration,
  ad-hoc signed, no sandbox and no iCloud entitlements, launched with
  `open -n … --env CFFIXED_USER_HOME=<folder>` so that everything it stores lands in that folder and
  nothing touches the owner's library or iCloud. Its corpus index and demo data were copied from an
  iPad simulator's container (the store renamed `FRUSExplorerLocal.store`), so the Mac shots show
  the same project, scopes, corpora, collection and Archives Visit as the iPad ones, plus a note, a
  highlight, a "Containment" tag and three saved searches made on the Mac. `series-production` came
  from a second, empty folder. Windows captured one at a time with `screencapture -o -l <window id>`
  while the app was frontmost, so the chrome is active and no screen overlay can appear.
  - **Two local-only patches, never committed**, both under the same launch argument: the status
    bar shows the healthy "iCloud Sync" chip instead of "Local Only", and the store skips CloudKit
    altogether — without the iCloud entitlement, SwiftData's CloudKit setup halts the process at
    launch (SIGTRAP inside CloudKit).
  - Choices a reader might wonder about: `document` is frus1948v02/d399, because the first
    candidate drew its footnote classification chip misaligned (#1386); `cross-reference-graph` is
    frus1952-54v02p1/d16, where no date label collides with a node; `crossref-analytics` shows
    only the heat matrix, because both rankings carried fallback labels (#1372);
    `person-analytics-trends` is 1072 pt tall so the ranking and the start of the trajectories fit;
    `analytics-table` has no Copy CSV because Corpus Analytics has none (#1081 asked for one).
  - `trip-packet` shows both claim lists but not the Options menu or Share buttons — see #1377.
- **Replaced**: the committed `ipad/document.png`, `ipad/search-results.png` and
  `ipad/sidebar-landscape.png`; and the owner's build-47 `ipad/semantic-map.png`, which came
  from a DEBUG build with its frame-rate overlay showing.
- **Deleted** (#1081 §7): `ios/browse-corpus`, `ios/search-results`, `ios/settings`,
  `ipad/browse`, `macos/collections-ribbon`, the four `ios/` stand-ins (`people-list`,
  `people-detail`, `analytics`, `chronology`), and `ios/document-view`, whose README hero slot is
  now `ipad/document.png`.

### Stale after build 48 (Mac)

**Closed by S5 on 2026-10-21.** S4 retook every file below on build 1861, and S5 read each retake
against its caption (the sittings' ledger); what each now shows follows its line. The list as it
stood:

These embedded `macos/` captures now contradict `../macOS-User-Manual.md` and need a fresh
capture on the current build:

- ~~`crossref-analytics.png`: taken before #1445/#1480 (row labels cut at the front, the grid in an
  inner scroll box, a "Tap a volume label" caption).~~ The retake draws the 1961–1963 matrix whole,
  every row label in full, with *Select a volume label to open it*; S5 added
  `crossref-analytics-ranking.png` beside it (*Caption and sentence fixes*, item 5).
- ~~`chronology.png`: the old legend and chip counts (#1387, #1400).~~ The retake reads *24
  documents extend beyond this range (24 reach past both ends)* under the build-51 legend.
- ~~`trip-packet.png`: the Mac packet now has Options and Share (#1444); the capture shows
  neither.~~ The retake shows Options at the packet's head and Share and Share as PDF at its foot,
  and its caption now says so.
- ~~`collections.png`: the collection picker's count is out of date.~~ The picker reads *The Long
  Telegram and Its Readers 6*, the collection's six documents.
- ~~`people-list.png`, `people-detail.png` and `person-analytics-network.png`: taken before
  #1370/#1441 (roles, lifespans, and overlapping or unmarked network labels).~~ The retakes show
  build 51's roles and years, Kissinger's Career section with no VIAF or Wikidata link (its caption
  rewritten, item 2), and Kennan's network with its partners named beside their nodes.
- ~~Still a placeholder, not a capture: §7.11's `[SCREENSHOT: the Search window's zero-result state
  with the semantic matches section beneath the query decomposition.]`~~ Since S5 the slot embeds
  S4's `search-zero-result-meaning.png`.

### Not re-checked after the build-49 wave (2026-10-01)

**Closed by S5 on 2026-10-21.** Every embedded file this list names was retaken on build 1861 in
S1 or S4, which postdates every lane below, and S5 read each retake against its caption; what each
now shows follows its line. The list as it stood:

The wave's fifteen merged lanes (thirteen when this list was written; HYG and READ landed on
2026-10-02, and the last bullet is theirs) changed what several captured surfaces draw, and **no capture was retaken
or compared against the new build**. This list is drawn from what each lane changed, not from
looking at the app, so treat every line but the first as a candidate:

- ~~`ipad/crossref-analytics.png` — **stale, by measurement**: its longest Most-Referenced label
  runs about 525 pt on one line, and since #1473 a label is capped at 320 pt and wraps to a second
  line (`RankingChartAxis.labelWidth`). `macos/crossref-analytics.png` is already listed above.~~
  S1's retake draws each long title on two lines, as iOS §15.4 says.
- ~~`ipad/browse-archives-provenance.png` — lane NOTE recorded it in
  `../../Planning/Manual-Revisions-Pending.md` (#1514 moved notes between provenance categories).~~
  S1's retake shows eleven doors and *About 29%*; S5 brought the caption and §6.1g's sentence to
  both (items 1 and 9).
- ~~`ipad/archival-analytics.png`, `macos/archival-analytics.png`, and the
  `ipad/browse-archives*` set — their counts predate the collection authority's regenerations of
  2026-09-25 (#1466, #1469) and 2026-10-01 (#1514, #1468).~~ The retakes count over A18's
  regenerated files at index version 71: *60,019 source notes in 1948–1960*, 753 collections, on
  both platforms.
- ~~`ipad/trip-packet.png`, `ipad/trip-packet-options.png` — #1514 and #1515 changed the packet's
  crib and divided-lot lines.~~ Retaken in S1 on the visit of the demo recipe.
- ~~`ipad/cross-reference-graph.png`, `macos/cross-reference-graph.png`, `macos/person-analytics-network.png`
  — #1438 gave every graph's labels a second place above their node, so a re-capture names more
  nodes; #1481 renamed the iPad node menu's item to *View Document*.~~ Retaken in S1 and S4. The
  iPad graph at three hops now holds about seventy nodes and names only its focus (*Found by S1*,
  14); the Mac's Timeline at one hop names each document node by its number and date.
- ~~`macos/collections.png` (already listed) — #1446 also caps a long name in the collection
  picker.~~ Retaken in S4.
- ~~Any capture of Volumes & Storage, Data & Recovery, Citation Lookup's Batch mode, or a text
  selection in the iPad reader: lanes STOR, SYNC, LANG, CITE and SEL changed those screens. No
  capture named for one of them is embedded in either manual today; a future one should be taken
  on build 49 or later.~~ Still none is embedded. `ios/indexing-banner`, embedded in iOS §4.8 since
  S5, was taken over Volumes & Storage on build 1861, and its crop shows only the banner and the tab
  bar.
- ~~Added 2026-10-02, from what lanes READ and HYG changed: a document that prints a figure now
  draws its image where it printed the file's name, and the **Storage used** bar gains a
  **Figures** segment once an image is on the device (#1516); the Mac main window's empty state
  names ⌥⌘F under "Select a document to begin", and its Search tooltip does too. No capture was
  opened to see whether it shows one of these.~~ None of the build-1861 frames shows a figure, the
  Storage used bar or the Mac's empty state.

~~Three `[SCREENSHOT` placeholders remain: `../iOS-User-Manual.md` has two (the Search Tips sheet;
the zero-result "Search by meaning" offer) and `../macOS-User-Manual.md` one (above).~~ None
remains since S5: the slots embed `ios/search-tips`, `ipad/semantic-offer` with
`ipad/semantic-zero-result-matches`, and `macos/search-zero-result-meaning`.

## The build-51 sweep — the shot list (S0, 2026-10-21)

The 2026-10-14 plan of record's §6a (`../../Planning/Completed/Plan-Of-Record-2026-10-14.md`) retakes every embedded
capture on build 51 in five sittings after the tag, S1 to S5, with S6 optional on the owner's
devices. This section is S0, the sitting that takes no picture: the list the others shoot from.
It was made on 2026-10-21 at `v2` `b4dcd527` (A19 merged, index version 71, version 1.0 build
1861), after A19 and before the tag (decisions 81 and 83), by reading the two manuals line by line
against the code, the bundled files and the build-48 PNGs; nothing was run in the app. The
owner's rule from #1081 stands: **every committed capture is stale**, so every one of the 68
embedded files is retaken, and the question for each is only what it must now show. The
**Capture conventions** section below, the build-48 entries above and `Planning/Capture-Runbook.md`
§7 to §9 are the how; `Planning/Launch-Marketing-Kit-2026-10-13.md` §7 lists what the store
frames need beyond the manuals.

**What moved under the captures since build 48.** Builds 49, 50 and 51 change what most of the 68
show. Every capture with a document in it: the reader's contrast and underlined person and
cross-reference links (#1578) and its measure (#1665: Standard width holds about 100 characters a
line at Medium text on iPad, and fills the page beside the Research rail on a 13-inch iPad; the
Mac has its own default). Every search capture: a keyword snippet starts a few words before the
first match in the prose, past the heading, source note and dateline (A10b); the More menu and
Sort ▸ Closest to a Question… (A5); the dimmed bulk actions' reason (A13). Every People capture:
rollup v12 (A4, A4c), no Wikidata link and a VIAF link only from the register's own identifier
(A4d). Browse: a chapter's **Read** row (#1536) and the prose rows A18 promoted; the Archives door's
eleven provenance doors (#1543) and the classes read in words across both handbooks (A16, A18);
the regenerated authority (3,977 records, A18). The graph and Cross-Reference Analytics: labels
above nodes (#1438), *View Document* (#1481), two-line ranking labels (#1473), and A17's and
A18b's citations — 38,600 cross-volume citations into 20,273 documents from 513 volumes, 29,391 of
them pages of another volume counted as citations. The Archives Visit: Options and Share on the
Mac (#1444), the claimant line and the class-keyed notes (A15). Collections: the smart badge and
*Smart collection* label (#1619, A1), Link to Saved Search… in the Mac's ⚙ (A14). The semantic
layer: EmbeddingGemma 2's artifacts and relayout (B4: 140 regions, 314,616 documents, 88,059
unclustered). Live Activities and the indexing banner: one activity for a whole queue (A11). Each
row below says which of these touches it; a row that says *text unchanged* means the manual's
section is as it was at build 48 (measured by a section-by-section diff of both manuals between
the `build-48` tag and `b4dcd527`), not that the screen is.

### The captures whose subject changed in builds 49 to 51

By what the lanes changed on screen — §6a's *Why after the tag* list, then A1 to A18b — so a
sitting knows what to look for; the rows below carry the detail.

- **Every capture with a document in it** — #1578 (underlined links, contrast) and #1665 (the
  measure): `ipad/research-rail`, `document`, `stage-manager`; `macos/research-strip`, `document`.
- **Every search capture** — A10b (snippets), A5 (More, Sort, Search Within Results), A13, #1726:
  `ipad/search-results`, `semantic-search`; `macos/search`, `search-tips`, `saved-searches`; and
  the placeholders P2 and P3.
- **People** — A4, A4c, A4d (rollup v12; the links): `ipad/people-list`, `people-detail`,
  `people-detail-records`; `macos/people-list`, `people-detail` (its caption too),
  `person-analytics-trends`, `person-analytics-network`.
- **Browse** — #1536 and A18 (Read rows, the promoted prose), #1543 and A16/A18 (the Archives
  door), A9 (#1688's corpus line), the visit-title rule for Continue reading: `ipad/browse-root`,
  `browse-archives-provenance`, `browse-archives`, `browse-archives-collections`,
  `browse-working-corpora`; `macos/browser`, `browse-all-volumes`.
- **Clusters and the map** — B4's relayout (and A3c's #1700 on the Mac): `ipad/browse-clusters`,
  `browse-clusters-detail`, `browse-clusters-map`, `semantic-map`; `macos/semantic-map`.
- **Related Documents** — the semantic signal on at half weight, *shares:* chips, Beyond your
  library: `ipad/related-documents`.
- **The graph and Cross-Reference Analytics** — #1438, #1481, #1473, A17, A18b:
  `ipad/cross-reference-graph`, `crossref-analytics`; `macos/cross-reference-graph`,
  `crossref-analytics`.
- **Source Explorer and the Archives Visit** — §14.1's ⓘ and ⋯ menu, the Mac's Add to Archives
  Visit menu, #1444 (Options and Share on the Mac), A15: `ipad/source-explorer`, `trip-packet`,
  `trip-packet-options`; `macos/source-explorer`, `trip-packet`.
- **Collections** — #1619, A1, A3b, A4b, A14, #1446: `ipad/collections-editor`;
  `macos/collections`.
- **Corpus Analytics and the word cloud** — the Group by menu, Compare terms, the year chip, Save
  query, Dispersion; #1608's fallback lines: `ipad/analytics`, `word-cloud`; `macos/analytics`,
  `analytics-table`, `word-cloud`.
- **Archival Analytics** — A16, A18, the chip's Hidden/Shown: `ipad/archival-analytics`;
  `macos/archival-analytics`.
- **Chronology** — #1387, #1400, the Chart colors menu: `ipad/chronology`; `macos/chronology`.
- **Onboarding and About the Series** — the size line and two cloud views; the Subject-Numeric
  File in Archival Sourcing: `ipad/onboarding-volumes`, `series-production`;
  `macos/series-production`.
- **The sidebar** — #909's footer: `ipad/sidebar-landscape`.
- **The banner and Live Activities** — A11: the unembedded `ios/indexing-banner`, if re-shot.
- **Unchanged in subject, retaken under the owner's rule**: `ipad/browse-all-volumes`,
  `browse-administrations`, `browse-administrations-truman`, `browse-editors`, `browse-scopes`,
  `browse-scopes-editor`, `browse-scopes-banner`, `browse-corpus-drill`,
  `browse-archives-collection-detail`, `browse-archives-collection-citing`, `topic-index`;
  `macos/toolbar`, `topic-index`, `research`.

### The devices, and which captures go to iOS 26.5

- **S1's device is one iPad Pro 13-inch (M5) simulator under iOS 27.0**, landscape, 2752×2064,
  the demo status bar, the full 553-volume corpus indexed, created or erased for the sitting and
  **never one that has run an analytics UI suite**: under iOS 27.0 an iPad simulator's render
  server dies when a UI test that opened Corpus Analytics ends, and a simulator that has died once
  dies again at a plain launch of the app (#1620, measured 2026-10-09 and 2026-10-11 on the 11-inch
  `27A97343`, three of three). The existing 13-inch under 27.0 is `9AB3A0C9`, which A12 found
  holding the Research rail closed in its preferences (`frus.document.researchPanel.visible =
  false`, written by an earlier run): erase it or make a new one, and open a document to see the
  rail before shooting.
- **The seven Analysis Tools window captures go to the iPad Pro 13-inch (M5) under iOS 26.5**
  (`9F3D84A4-C35B-4280-9607-1B64240AD8D1`), as the plan's S1 row says: `analytics`,
  `crossref-analytics`, `archival-analytics`, `semantic-map`, `browse-clusters-map` (the same
  Semantic Analytics window, reached from a cluster), `chronology`, and `word-cloud` (a sheet, but
  the plan names it, and its tap on a word opens Corpus Analytics). The rule for the 27.0 device:
  **take every other capture first, and open no Analysis Tools window on it**; if one is opened
  there and the device survives, the ledger says so, since that is a measurement #1620 lacks. The
  26.5 device holds the same corpus and demo data (clone the container, install first, check
  `get_app_container` names the clone — the A6 lesson in the simulator notes). Its chrome differs
  from 27.0's only in the system's own drawing, which the manuals do not describe.
- **iOS 27.1's runtime is not installed** on 2026-10-21 (26.3, 26.4, 26.5 and 27.0 are), so
  decision 72's re-test of #1620 has not run and the split above stands. The owner's iPad under
  iOS 27 is the alternative for the seven (the plan's §5); the ledger says which.
- **S2** is a second 13-inch simulator, erased, no volumes: `onboarding-volumes`,
  `series-production`, and the kit's pass A (the splash and onboarding recording).
- **S3** is an iPhone 17 Pro under iOS 27.0, portrait, the full corpus; the kit's three iPhone
  frames want the iPhone 17 Pro Max (6.9-inch), so take them there and the manual's two on either.
- **S4** is the Mac. Use `tools/mac-check-copy/` (bundle id `bottsywattsy.FRUS-Explorer.maccheck`,
  the local-only store compiled in under `FRUS_MAC_CHECK`, a fake home under `CFFIXED_USER_HOME`,
  built from the tag with `setup.sh --ref build-51`), the committed form of the build-48 sitting's
  hand-patched copy; seed its fake home's library and store from the iPad simulator's container, as
  build 48's was, so the Mac shots show the same project, scopes, corpora, collection and visit.
  One thing to settle on the day: the copy has no iCloud entitlement, so its status chip reads
  **Local Only**; build 48 patched the chip to read **iCloud Sync** and never committed the patch.
  Either patch it again under a launch argument or crop the status bar, and say which here.
  **S4 patched it** (the owner's word of 2026-10-21, 19:01), in the copy's extracted source only,
  and built the copy from `v2`'s head, since the tag waits for submission: the sittings' ledger.
  Windows are captured one at a time with `screencapture -o -l <window id>` at 1440×900 points
  (2880×1800 pixels, the kit's Mac preset) wherever the capture is also a store frame.
- **The corpus.** Fastest is the simulator notes' recipe: `cp -c` the 553 manifest volumes into
  the app container and let the launch index them (about 30 minutes on this class; a fresh install
  runs the whole-library date pass). A19's census left a build-51 library at version 71 under
  `~/Library/Caches/FRUS-Explorer/a19/`; if it is whole, cloning it saves the index.
- **Every file's build number, device, OS and UDID go in this ledger** when its sitting runs (the
  X-8 rule); the skeleton is at the end of this section.

### The demo data, re-read against the manuals' sentences

The build-48 recipe above holds, with what the captions depend on made explicit and three things
it left out. Everything is made through the app's own UI.

1. **The project "Early Cold War"**, active, with the research question *How did Washington come
   to see the Soviet Union as its principal adversary, 1945-1950?* — it heads every Browse capture
   as the *Working on:* line (the build-48 PNGs show it; the recipe never recorded it) and seeds the
   Archives Visit's inquiry topic sentence. With the sidebar showing, it is the checked project in
   the Projects footer (`sidebar-landscape`).
2. **Three scopes**: *Berlin Crises 1958-1963*, *Cuba 1958-1963*, *Soviet Union 1945-1950*. Both
   `word-cloud` captions name the last; `browse-scopes` lists all three, most recently edited first.
3. **Two working corpora**, captured from keyword searches for *Berlin airlift* and `"long
   telegram"` with Save as Working Corpus — keyword captures, so the list's amber line (stopped
   short, or complete) is what §6.1f describes; a corpus saved from a Meaning search would read
   *The N closest matches of a Meaning search* in grey instead (A9), which no caption wants.
4. **The collection "The Long Telegram and Its Readers"** — the Long Telegram
   (`frus1946v06/d475`; S0 wrote d474, Kennan's telegram of February 12, *Found by S3*, 1) and the
   documents that answer it — with **at least two section headings
   and one note block**, since `collections-editor`'s caption shows "section headings, a prose
   block, documents with their Configure pills"; the build-48 recipe did not say so. A note under
   the title (Collection settings) gives the Mac's document inspector something to show.
5. **The Archives Visit**, seeded from that collection **plus `frus1952-54v02p1/d41` and
   `frus1955-57v19/d81`**. Read in the TEI on 2026-10-21: d41's source note is *S/S–NSC files, lot
   63 D 351, NSC 140* and d81's *S/S–NSC Files: Lot 63 D 351, NSC 5606 Series*; both are printed
   from the lot and cite it in their footnotes, which is what gives `trip-packet` both claim
   lists. A15's claimant line appears only for a divided lot cited through the National Archives,
   which 63 D 351 cited the Department's way is not; the packet's other new lines (the
   visit-planning links' dates, the coverage report's *Where this came from*) need nothing added.
6. **The reading history**: open the Long Telegram before the Browse captures, so **Continue
   reading** offers it. The build-48 `browse-root` names the volume's title in that row; the app
   now records a visit under the document's own title (Mac §16.2: a visit an earlier build recorded
   under its volume's title is listed by its ids instead), so the retake should read *The Chargé in
   the Soviet Union (Kennan) to the Secretary of State* — look.
7. **Remove `frus1948v01p2` on purpose**, after the corpora are captured, so `browse-corpus-drill`
   shows one gray identifier row with **Download** (check that the `"long telegram"` corpus holds a
   document from it; the build-48 take did). Before the Meaning zero-result frames (P2 below),
   remove two more volumes the question's closest matches sit in.
8. **On the Mac add** a note on the Long Telegram, a highlight, the tag *Containment*
   (`research-strip`'s caption names it; `research`'s strips need the highlight), and **three saved
   searches** (`saved-searches`), *Berlin blockade* among them. Optional, and cheap once the saved
   searches exist: link one new collection to a saved search, so the Collections picker shows
   A1's *Smart collection* label and bolt, which §12.1 now describes; no caption needs it.
9. **The documents by name.** Source Explorer on both platforms: `frus1952-54v02p1/d41` (the
   build-48 takes on both platforms show its note, *S/S – NSC files, lot 63 D 351, NSC 140*, with
   the bundled record A1 1586E and 623 archival neighbors). The cross-reference graph on both:
   `frus1952-54v02p1/d16` (the Mac's build-48 choice, where no date label collides). The Mac's
   `document`: `frus1948v02/d399` (the build-48 choice; see the ledger above). The iPad's
   `document` and `research-rail`: the Long Telegram, which has detected topics (the Topics
   accordion is hidden on a document with none). The collection's detail on the iPad:
   **Bohlen Files: Lot 74 D 379** (RG 59, NAID 840567), the build-48 take's.
10. **The Topic index**: the **Cold War** area on both platforms. Counted in
    `document-subject-index.json` on 2026-10-21 it still holds **6 topics** — Berlin crisis, Cold
    War, Detente, German reunification debate, Mutual and Balanced Force Reductions (1973–1989),
    Truman Doctrine — so the Mac's chip reads *Topic area: Cold War — 6 topics* as its caption
    says, with Berlin crisis open; the series holds 491 topics, as both manuals say.
11. **People**: *Kissinger, Henry A.*, after the rollup consolidation settles (the People note
    above). His record in `person-authority-index.json` carries no VIAF identifier of the
    register's own, so under A4d his sheet shows **neither a VIAF nor a Wikidata link**; the Mac's
    `people-detail` caption, which names both, is rewritten in S5 (below).
12. **The searches**: *Berlin blockade* for `search-results` (iPad) and `search` (Mac; the kit's
    frame 01 route names it on every device). The Meaning question for `semantic-search` is free;
    the zero-result question for P2 can be the manual's own, *Why did the Marshall Plan happen?*,
    if it returns no keyword result on the day.
13. **Analytics**: four terms by year in % of documents (iPad `analytics`); *Berlin* by year,
    1944–1975 (Mac `analytics`, `analytics-table`); Chronology over autumn 1962 (iPad
    `chronology`); the heat matrix for 1961–1963 (Mac `crossref-analytics`); George Kennan's ego
    network (Mac `person-analytics-network`); Archival Analytics in Collections mode, era
    1948–1960, by documents (both `archival-analytics`); the Soviet Union 1945-1950 scope in
    Distinctive mode, Concepts lens (both `word-cloud`).
14. **The offline convention** for `onboarding-volumes` and `series-production`: an erased
    simulator and, on the Mac, an empty fake home.
15. **The status bar**: `xcrun simctl status_bar <udid> override --time "9:41" --batteryState
    charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi` before each iPad
    and iPhone sitting. **The sync banner**: sign the simulator into iCloud, or keep the banner out
    of frame, or patch `SyncStatusBanner.isWorthShowing` under a launch argument as build 48 did
    (never committed); say which here.

**The mismatches, listed.** (1) iOS §6.1g's caption says ten doors where the text says eleven;
the doors are eleven (row 14). (2) The Mac `people-detail` caption names VIAF and Wikidata links
the sheet no longer shows (row 49). (3) The build-48 `browse-root` shows Continue reading under
the volume's title, which the app no longer records that way (point 6). (4) The build-48 recipe
never named the project's research question, which every Browse capture shows (point 1), nor the
collection's headings and note block, which `collections-editor`'s caption needs (point 4).
(5) iOS §7.12's placeholder asks for a Download Volume button that a full-corpus device cannot
show without volumes removed on purpose (point 7, P2b). (6) Sixteen of the embedded `ipad/` files
and the graph's window capture are the owner's build-47 device captures — the owner's status bar,
3180×2384 or 2852×2139 — not the demo bar at 2752×2064; every one is retaken. (7) The Mac
`crossref-analytics` caption describes the heat matrix alone because the build-48 rankings
carried fallback labels (#1372); row 64 says to look again. (8) The iOS `analytics` caption says
the Measure control is inline while four terms are compared, where §15.1 now says the picker is
disabled for a comparison (row 35).

### S1 — iPad, full corpus: the 40 captures, and the Meaning placeholder's two frames

Device as above; the seven marked **26.5** on the twin. *Slot* is the manual line at `b4dcd527`.
*Must bear out* is the caption, then the sentence near it that the frame has to agree with. (S1
took those seven on the 27.0 device and row 3 under iOS 26.5: the sittings' ledger below.)

| # | File | Slot | Must bear out | Moved since build 48 | Route and notes |
|---|---|---|---|---|---|
| 1 | `sidebar-landscape` | iOS §4.1, l. 138 | The adaptive tab sidebar with the active project in its Projects footer, beside the Browse root. §4.1: under the five tabs, up to five Saved Searches (newest first) and up to five Projects, a check mark on the active one; each list appears once there is something in it | §4.1 gained the shortcuts sentence (#909's footer); otherwise text unchanged | Browse root, sidebar expanded; one saved search and the project made first, so both lists show |
| 2 | `research-rail` | §4.2, l. 162 | RESEARCH header, the seven tiles (Cite · Word Cloud · Sources · Graph · Related · On the Map · Share), the Topics, Summary, Notes, Tags and Collections accordions beside the text. §4.2: the toolbar carries two controls now, Find in Document and the rail toggle; Topics only when the document has any | #1665 (Standard measure fills the page beside the rail on a 13-inch), #1578 (underlined links); §4.2's first paragraph changed | The Long Telegram; a note and the tag on it, as the Mac's `research-strip` has, are optional |
| 3 | `stage-manager` | §4.5, l. 196 | A document window beside a Related Documents window, the main window behind. §4.5: tool windows' Done; Related Documents has no Done | §4.5 rewritten (every multitasking mode; the Analysis Tools windows) | Settings ▸ Multitasking & Gestures ▸ Stage Manager; Open in New Window from the rail header, then Related; switch back to Windowed Apps afterwards (`AuxWindowCloseTests` runs there) |
| 4 | `browse-root` | §6, l. 313 | Continue reading, the volume search field, the People and Topics rows, the "Browse by" tiles, Your sets. §6.1: six doors, Subseries first | Text unchanged; the Continue reading row names the document (recipe 6); the *Working on:* line (recipe 1) | Two-pane root with nothing opened on the right, or a level open — the build-48 take had the right pane empty |
| 5 | `browse-all-volumes` | §6.1b, l. 347 | Published order, the Title / Published / Era / Length control above decade headers, newest first | Text unchanged; 1981–1988 vol. XVI heads the list | Browse ▸ All Volumes ▸ Published |
| 6 | `browse-administrations` | §6.1c, l. 355 | Each presidency with its volume and document reach, the post-corpus presidencies dimmed at the end | Text unchanged; the build-47 file is the owner's device (3180×2384) | Scroll so the dimmed tail is in frame |
| 7 | `browse-administrations-truman` | §6.1c, l. 357 | Truman's volumes, largest share first, each row's count and share, an *Also under …* note | Text unchanged | Find a row with the note |
| 8 | `browse-editors` | §6.1d, l. 363 | Letter sections, each editor with a volume count, a *2 spellings merged* caption under a name recorded two ways | Text unchanged | Scroll to a merged name |
| 9 | `browse-scopes` | §6.1e, l. 377 | Your scopes, most recently edited first. §6.1e now names the toolbar's **+** (New Scope) and the filter glyph on a scope being browsed within | Two sentences added (New Scope; where the long-press is offered) | Three scopes |
| 10 | `browse-scopes-editor` | §6.1e, l. 379 | A scope's volumes with red minus buttons, Add Volumes… | As 9 | The pencil on a scope |
| 11 | `browse-scopes-banner` | §6.1e, l. 381 | The amber *Browsing within: …* banner over the subseries list, its ✕. §6.1: while the filter is on, the root's Subseries tile names the scope and counts its volumes | As 9 | Browse Within This Scope on a scope's long-press menu; a second frame of the root tile is optional |
| 12 | `browse-working-corpora` | §6.1f, l. 393 | Each corpus with where it came from, when, and whether the capture was complete (amber) | §6.1f rewritten (moved from §7.9); A9's grey Meaning line applies only to a Meaning corpus | Two keyword corpora (recipe 3) |
| 13 | `browse-corpus-drill` | §6.1f, l. 395 | The amber coverage line, titled rows for indexed volumes, gray identifier rows with **Download** for a volume not on the device | As 12 | `frus1948v01p2` removed (recipe 7) |
| 14 | `browse-archives-provenance` | §6.1g, l. 409 | The caption says *the ten kinds of file*; §6.1g's text says **eleven doors**. **Settled by S0: eleven.** `ArchivesAxis.categoryDoors` draws one door per category in `collection-usage-index.json`, whose list holds 11 (the Subject-Numeric File joined in #1543); the build-48 PNG shows ten because it predates #1543. S5 rewrites the caption | The eleventh door; the banner's figures follow the regenerated usage index (264,598 notes across 502 of 553 volumes; 51 volumes print none) | Archives ▸ Provenance Types |
| 15 | `browse-archives-collections` | §6.1g, l. 411 | Collections lens grouped by record group, the Group and Sort menus, a collapsed group | A18 regenerated the authority (3,977 records); otherwise as the text | Group ▸ Record group; collapse one group |
| 16 | `browse-archives` | §6.1g, l. 413 | Classes lens: central-file classes under their filing schedule, sorted by document count, read in words where the manuals give a reading. §6.1g: three decimal schedules (1910–49, the 1950s, 1960–63) and the two subject-numeric arrangements | A16 (labels across the two handbooks, the 1964–1973 era at 1,615 classes), A18 (the class grammar; `POL 2 DOM REP`, names dropped) | Sort ▸ document count; a class read in words in frame |
| 17 | `browse-archives-collection-detail` | §6.1g, l. 415 | A collection's detail, reached by push: its identity, its other spellings, the NARA catalog record it resolves to, offline | Text unchanged; In Your Library's count follows the index | Bohlen Files: Lot 74 D 379 (recipe 9) |
| 18 | `browse-archives-collection-citing` | §6.1g, l. 417 | Further down: when the series cited it, the unprinted material editors pointed at, its citing volumes | Text unchanged | Same page, scrolled |
| 19 | `browse-clusters` | §6.1h, l. 429 | Each cluster's sampled label, document count and era histogram, under the three honesty rules. §6.1h: 140 groups; about 28% (88,059 documents) in no cluster; the example label *nanking · chinese · shanghai · chungking* | B4's relayout (171 → 140); the build-47 file is the owner's device | The list's head, with the rules in frame |
| 20 | `browse-clusters-detail` | §6.1h, l. 431 | A cluster's documents: the era breakdown and coverage line, See on the semantic map, Save as Working Corpus, documents grouped by volume | As 19; the largest cluster holds 37,899 documents in the shipped map, where §6.1h says 37,865 (S0 finding 2, below) | Any cluster; the build-47 file is the owner's |
| 21 | `browse-clusters-map` **26.5** | §6.1h, l. 433 | The semantic map focused on a cluster after *See on the semantic map*, its region card ready | B4's relayout | From 20's cluster |
| 22 | `topic-index` | §6.2a, l. 445 | The index narrowed to one topic area: the area chip with its ✕, each topic with its reach across the series. §6.2a: 491 topics; the chip's form *Topic area: Cold War — 6 topics* | One sentence changed (an area such as *Warfare · General* holds ten topics) | Browse ▸ Topics ▸ a Cold War topic ▸ All Cold War topics (recipe 10) |
| 23 | `people-list` | §6.5, l. 473 | One alphabetical list of reconciled identities, role · active-years subtitles, mention counts. §6.5: a question-mark badge marks a possible duplicate | A4, A4c, A4d (rollup v12: counts and roles move); the badge sentence changed | After the consolidation settles (the People note above) |
| 24 | `people-detail` | §6.5, l. 477 | Kissinger's sheet: the reconciled-identity seal, mention count and active years, subjects, Find all mentions | A4d: no Wikidata link, and no VIAF link for him (recipe 11); the caption does not name the links, so it stands | The sheet's top |
| 25 | `people-detail-records` | §6.5, l. 479 | Further down: the Career section and the underlying volume records, each with its Separate action | A4's rollups; the Career section is the register's (1,240 people) | Scrolled |
| 26 | `search-results` | §7, l. 504 | **Caption changed since build 48**: the query field, the actions bar, the ranked list with headings, datelines, volume identifiers and highlighted snippets. §7.1: a snippet begins a few words before the first match in the text, past the heading, source note and dateline | A10b (where the snippet starts), A5 (More's items, Sort ▸ Closest to a Question…), A13; the build-47 file is the owner's device | *Berlin blockade* in Keywords; the kit's frame 01 is this file |
| 27 | `semantic-search` | §7.12a, l. 730 | The Keywords \| Meaning control, the disclosure strip, ranked matches each with its semantic-match score. §7.12a: the header counts *N closest matches*; the strip's sentences (A9's decision-61 sentence among them); at the largest text sizes the strip is one line with an ⓘ (#1721) | §7.12a rewritten (61 diff lines); the model is EmbeddingGemma 2 (B4); the build-47 file is the owner's | **Needs the 310 MB encoder downloaded in the simulator.** Take after P2's offer frame (below), which needs it absent. The kit's frame 12 is this file |
| 28 | `document` | §8, l. 763 | A rendered document in landscape: heading, dateline, body with linked person names, footnote markers | #1578 (underlined links, contrast), #1665 (the measure), #1516 (a figure, if the document prints one; §8 now describes figures) | The Long Telegram with the rail hidden (Read mode), so the Standard measure and the faint edge chevrons (§4.4) show |
| 29 | `related-documents` | §8.5, l. 819 | The This volume / This subseries / All volumes scope, Adjust weights open with a slider per signal and Reset, ranked rows with their "why related" chips. §8.5: eight signals, **Reset to app defaults**, *shares: …* chips, the Beyond your library section | §8.5 changed (13 diff lines); the build-47 file is the owner's | The Long Telegram's Related window with the weights open |
| 30 | `cross-reference-graph` | §8.6, l. 829 | Network mode at three hops: document nodes, teal archival-citation nodes, the reference list panel beside the canvas. §8.6: the legend under the canvas; Timeline and Network layouts; the inbound-citation figures | #1438, #1481, A17, A18b (the figures); §8.6 changed (15 diff lines); the build-47 file is a 2852×2139 window capture | `frus1952-54v02p1/d16` (recipe 9); Depth 3, Network, the list panel open; a whole-screen `simctl io` capture is fine |
| 31 | `collections-editor` | §12.1, l. 1004 | The Contents outline (section headings, a prose block, documents with their Configure pills) beside the live preview. §12.1: the four toolbar buttons — gear, ＋, Sort, Export | §12.1 rewritten (the toolbar; swipe to remove; Edit for drag handles); A1's smart-collection rules do not touch this collection | *The Long Telegram and Its Readers* (recipe 4) |
| 32 | `source-explorer` | §14.1, l. 1173 | The parsed source note and the NARA catalog record it resolves to. §14.1: the ⓘ, and Learn About Source Notes in the ⋯ menu | §14.1 changed (the two buttons); A15/A16/A18 do not touch a lot-file note | `frus1952-54v02p1/d41` (recipe 9); the kit's frame 04 is this file |
| 33 | `trip-packet` | §14.8, l. 1254 | A research target with its two claim lists — documents published from the file and footnotes that cite it — with the Share buttons above | §14.8 changed (16 diff lines: the visit-planning links' dates, the coverage report's *Where this came from*, Stored targets, the Copy inquiry draft section); A15 | The visit of recipe 5; the Lot 63 D 351 target expanded; the kit's frame 05 is this file |
| 34 | `trip-packet-options` | §14.8, l. 1256 | The Options menu: the repository scope, a copy of each facility's inquiry draft, what to include | As 33 | The menu open over the packet |
| 35 | `analytics` **26.5** | §15.1, l. 1280 | Four terms charted by year as a share of documents, with the Measure, value and Export controls inline in the toolbar. §15.1: comparisons open in % of documents; the Measure picker and the table are unavailable while comparing — **so the picker is drawn dimmed in this frame**, and S5 reads the caption against it | §15.1 rewritten (the Group by chip's menu, the year chip's popover, Save query, Dispersion); the build-47 file is 2884×1540, the owner's | Analysis Tools ▸ Corpus Analytics; four terms; the kit's frame 10 is this file |
| 36 | `word-cloud` **26.5** | §15.2, l. 1310 | Distinctive mode, the Concepts lens, the Soviet Union 1945-1950 scope, the eligibility line beneath the mode control | §15.2 changed (the lemmatiser fallback's lines, #1608, show only on a Limited launch); A3b's caveat is on exports, not the screen | Analysis Tools ▸ Corpus Word Cloud, scope picker ▸ the scope |
| 37 | `crossref-analytics` **26.5** | §15.4, l. 1334 | The Scope, year-range and Administration controls above the Most-Referenced Documents ranking by inbound citations. §15.4: a long title takes two lines | **Stale by measurement** (the entry above: #1473's 320 pt labels); A17 and A18b move every count (a page of another volume counts) | Analysis Tools ▸ Cross-Reference Analytics, the ranking open |
| 38 | `archival-analytics` **26.5** | §15.5, l. 1350 | Collections mode, an era ranking of named collections, the Central Files umbrella chip. §15.5: the chip reads *Hidden* or *Shown*; Show all N units opens the Every Unit sheet | A16 (classes in words), A18 (the regenerated authority and usage index); §15.5 changed (18 diff lines) | Era 1948–1960, Named collections, by documents |
| 39 | `semantic-map` **26.5** | §15.6, l. 1376 | Colored by Regions: region labels, the explainer card above, the caveat line beneath the map. §15.6: 314,616 documents; the Provenance lens's 86 of 499 | B4's relayout (140 regions); the Point size control | Analysis Tools ▸ Semantic Analytics; the README's third hero slot and the kit's frame 03 are this file |
| 40 | `chronology` **26.5** | §15.7, l. 1382 | The From/To range (autumn 1962), the stacked distribution chart with its per-volume legend, the date-grouped list. §15.7: the Chart colors menu; the *Spans more than a year* and *Extends beyond this range* chips | #1387/#1400 (the legend and chip counts; the build-47 file predates them), the Chart colors menu | Analysis Tools ▸ Chronology, September–November 1962; the kit's frame 11 is this file |
| P2a | `semantic-offer` (new) | §7.12, l. 656, first half | A zero-result question with the *Search by meaning* offer card. §7.1: the zero-result screen names the term that matched nothing, with the denominator; §7.12: Download Search Model | The offer is `SemanticSearchFallbackView`; A9 (#1685) changed only what a replaced run writes | **Before the encoder is downloaded.** The manual's own question if it returns nothing |
| P2b | `semantic-zero-result-matches` (new) | §7.12, l. 656, second half | The same search after the model downloaded: ranked semantic matches beneath the zero-result explanation, with a **Download Volume** button on an undownloaded hit | §7.12's bullets (scores, the match-file caption) | **After the download.** On a full-corpus device no hit is undownloaded: remove the two volumes the question's closest matches sit in first (recipe 7), or S5 drops the clause |

### S2 — iPad, erased

| # | File | Slot | Must bear out | Moved since build 48 | Route and notes |
|---|---|---|---|---|---|
| 41 | `onboarding-volumes` | iOS §2.3, l. 86 | The Add Volumes step (Corpus, Subseries or Volume) over the word-cloud backdrop, its Concepts view. §2.3: the line under the control reads *553+ volumes · ≈ 3.5 GB*; Continue dimmed until a row is picked; two cloud views, Concepts and Topics | §2.3 rewritten (12 diff lines): the size line, the scrolling list, Skip and Back | An erased simulator, no `-hasCompletedOnboarding`; wait for the Concepts chip |
| 42 | `series-production` | §16.1, l. 1413 | About the Series ▸ Production & Timeliness on an empty install: the publication-lag scatter, colored by era, against the timeliness targets in force | §16.1 changed (the Guide's eleven pages; Open Archival Analytics hands its scope on) | Research tab ▸ FRUS Research Guide ▸ the last four pages; the kit's frame 09 is this file |

(S2 took both rows, and the kit's pass A, on a new 27.0 device on 2026-10-21: the sittings' ledger
below.)

### S3 — iPhone

| # | File | Slot | Must bear out | Notes |
|---|---|---|---|---|
| P1 | `ios/search-tips` (new) | iOS §7.2, l. 522 | The Search Tips sheet at half height over the Search screen, showing the first rows. §7.2: •••  ▸ Search Tips in Keywords mode | iPhone 17 Pro, portrait, the demo bar; Keywords mode (in Meaning mode the sheet shows no syntax) |
| — | `ios/indexing-banner` | none today; a §4.8 slot if the owner takes it | §4.8: the banner along the bottom, above the tab bar on iPhone, with the current volume's progress and *Volume 3 of 27* with an estimate; *Learn about FRUS while you wait →* | Re-shoot only if S5 embeds it (the verdict below); a queue of several volumes indexing, so the position in the queue shows; A11 changed what the banner says of a failed volume and the finishing merge |
| — | the kit's frames 01, 02, 03 (and 04, 11 if wanted) | the store listing | the kit's §3 routes | iPhone 17 Pro Max; frame 01 with the facet sheet closed and a second take with it open |

(S3 took P1, the banner and the kit's frames 01 to 04 and 11 on two new iPhones under iOS 27.0 on
2026-10-21: the sittings' ledger below.)

### S4 — the Mac: the 26 captures, the zero-result placeholder, the kit's two

| # | File | Slot | Must bear out | Moved since build 48 | Route and notes |
|---|---|---|---|---|---|
| 43 | `toolbar` | Mac §4.1, l. 132 | The centered volumeId/documentId title and the trailing Search, Browse, Analytics ▾, My Research ▾ and Research-panel controls | Text unchanged | A 2880×104 strip; retaken under the owner's rule |
| 44 | `research-strip` | §4.2, l. 169 | The Research panel beside the Long Telegram: the tile grid and the five accordions, holding a note and a *Containment* tag | #1665 (the Mac's default measure), #1578; §4.2's selection bar names Look Up in NARA | Recipe 8; the kit's frame 02 is this file |
| 45 | `document` | §4.3, l. 175 | A document filling the main window: heading, dateline, body with linked names and footnote markers, the footnotes section | #1665, #1578; the empty state's ⌥⌘F line is out of frame | `frus1948v02/d399`, the rail closed |
| 46 | `browser` | §6, l. 294 | The Corpus Browser: the sidebar's Browse, Your sets and Subseries sections, a volume's page with its Top subjects, front matter and contents | Text unchanged; A3c's *Working on:* bar now heads the detail column (#1701); A18's Read rows where a volume has prose sections | A volume page |
| 47 | `browse-all-volumes` | §6.1, l. 300 | Browse ▸ All Volumes in Published order, each volume with its print year, document count and download status | §6.1 changed (three sections; eleven doors; 140 clusters; the Read rows) | — |
| 48 | `people-list` | §6.3, l. 316 | An alphabetical list of reconciled identities with role · active-years subtitles and mention counts | **Stale** (the entry above: #1370/#1441); A4, A4c, A4d; the badge sentence changed | After the rollup settles; `screencapture -o -l` on the Corpus Browser window |
| 49 | `people-detail` | §6.3, l. 320 | **The caption names VIAF and Wikidata links that Kissinger's sheet no longer shows** (recipe 11): the Career section — Secretary of State, 1973–1977, from the register — is what the frame can bear out. S5 rewrites the caption | A4d; §6.3's link sentence rewritten; stale per the entry above | Scrolled to Career |
| 50 | `topic-index` | §6.4, l. 345 | The Topics window narrowed to the Cold War area (*Topic area: Cold War — 6 topics*), Berlin crisis open: its documents and volumes in the series and on this Mac, its covering volumes | Text unchanged; still 6 topics (recipe 10) | — |
| 51 | `search` | §7, l. 363 | *Berlin blockade* in Keywords mode, the ranked results with highlighted snippets, citations and dates, the Facets panel open on its Subjects section | A10b (snippets), A5 lane 5 (Search Within Results; the engine label), A13 (a facet's volumes; the Within picker), #1726 | Also the README's first hero slot and the kit's frame 01; capture at 1440×900 points |
| 52 | `search-tips` | §7.2, l. 381 | The Search window with the Tips panel open under the results | §7.2: the panel follows the engine the field runs (lane 7) | Keywords mode |
| 53 | `saved-searches` | §7.8, l. 487 | The saved-searches list opened from the filled bookmark button | §7.8 changed (the bookmark is off inside a held list; a saved search runs inside an applied corpus) | Three saved searches (recipe 8) |
| 54 | `cross-reference-graph` | §8.5, l. 637 | The focus document and its references along a date axis (Timeline), teal nodes for the archival material its footnotes cite, the reference list panel | #1438; A17 (Volume Connections' labels); A18b (the figures); §8.5 changed (12 diff lines) | `frus1952-54v02p1/d16`; the README's second hero slot today (swapped out in S5, decision 34) and the kit's frame 06 |
| 55 | `research` | §9.2, l. 678 | The Research window: every annotated document, highlight strips, the grouping sidebar | §9.2 changed (the Review sheet's quotations; Changed by an update) | The highlight and note of recipe 8 |
| 56 | `collections` | §12.1, l. 786 | The toolbar collection picker, the Contents outline, the live preview, the document inspector | **Stale** (the entry above: the picker's count, #1446's name cap); A1 (*Smart collection* in the picker), A14 (Link to Saved Search… in ⚙); §12.1 changed | *The Long Telegram and Its Readers* with the inspector open; the kit's frame 08 |
| 57 | `source-explorer` | §14, l. 947 | A lot-file source: the parsed note, provenance and collection on the left; the NARA query, the matched record with its HMS/MLR entry, Archival Neighbors on the right | §14's opening changed (Window ▸ Source Explorer's start; the ▤ popover); A15/A16/A18 do not touch this note | `frus1952-54v02p1/d41` (recipe 9); the kit's frame 04 |
| 58 | `trip-packet` | §14.8, l. 1058 | The Archives Visits window with a plan's packet open from Export packet: a target's two claim lists | **Stale** (the entry above: #1444 — the Mac packet has Options and Share, which the build-48 take lacks); A15; §14.8 changed (18 diff lines) | The visit of recipe 5; the kit's frame 05 |
| 59 | `analytics` | §15.1, l. 1082 | *Berlin* by year, 1944–1975, each bar color-coded by source volume with a legend | §15.1 rewritten (17 diff lines: Compare terms chips, the year chip's popover, Save query, Dispersion, View N documents ↗) | The kit's frame 10 |
| 60 | `analytics-table` | §15.1, l. 1097 | The same query in Table mode, a grid of year and count rows (no Copy CSV: Corpus Analytics has none) | As 59 | — |
| 61 | `word-cloud` | §15.2, l. 1113 | Distinctive mode, the Concepts lens, the Soviet Union 1945-1950 scope, the eligibility line beneath the controls | §15.2 changed (8 diff lines; the fallback lines show only on a Limited launch, which a Mac has not had) | The scope must be in the copy's store (recipe: copy the iPad container) |
| 62 | `person-analytics-trends` | §15.3, l. 1124 | Trends mode: the most-mentioned ranking and a multi-person trajectory comparison | A4's rollups; the build-48 take is 1072 pt tall so both sections fit | — |
| 63 | `person-analytics-network` | §15.3, l. 1128 | Network mode: George Kennan at the center of his co-mention ego network, partners sized by shared documents | **Stale** (the entry above: #1370/#1441, #1438's labels); §15.3's Network paragraph changed | The kit's frame 13 |
| 64 | `crossref-analytics` | §15.4, l. 1141 | The Volume Citation Heat Matrix for 1961–1963, each cell shaded by the cross-references from one volume to another | **Stale** (the entry above: #1445/#1480); A17, A18b (the counts); §15.4 changed | The build-48 take showed the matrix alone because both rankings carried fallback labels (#1372): look at the rankings again, and widen the caption if they are right |
| 65 | `archival-analytics` | §15.5, l. 1157 | **Caption changed since build 48**: the 1948–1960 ranking of named collections by documents, with the Central Files chip in the control bar | A16, A18 (the regenerated files); §15.5 changed (14 diff lines) | The kit's frame 14 |
| 66 | `semantic-map` | §15.6, l. 1182 | Colored by Regions: region labels, the explainer above, the caveat line beneath the map | B4's relayout; A3c's #1700 (a reopened window drew nothing: fixed, and a fresh window never did) | The kit's frame 03 |
| 67 | `chronology` | §15.7, l. 1188 | From/To pickers, the stacked distribution chart with per-volume legend, the date-grouped list | **Stale** (the entry above: #1387, #1400); the Chart colors menu | The kit's frame 11; the hover magnifier stays S6's |
| 68 | `series-production` | §16.4, l. 1236 | The Production & Timeliness dashboard: the publication-lag scatter above the volumes-per-year bars | §16.4 changed (the Subject-Numeric File in Archival Sourcing; the year range's defaults) | An empty fake home; the kit's frame 09 |
| P3 | `search-zero-result-meaning` (new) | §7.11, l. 509 | The Search window's zero-result state with the semantic matches section beneath the query decomposition | The copy has the encoder (A19's walk) | A question that returns no keyword result |
| — | `cite-popover` (new), `search-meaning` (new) | the kit's frames 07 and 12 | The Cite popover; the Search window in Meaning mode | — | The kit's §7, sitting 4 |

(S4 took all 26, P3 and the kit's frames 07 and 12 in the check copy on 2026-10-21, with recording A
and the Mac App Preview: the sittings' ledger below.)

### The three placeholders

P1 (iOS §7.2, line 522) is S3's; P2 (iOS §7.12, line 656) is two frames in S1, the offer before
the encoder is downloaded and the matches after; P3 (Mac §7.11, line 509) is S4's. Their file
names above are proposals: S5 wires them in and removes the three `[SCREENSHOT: …]` lines, which
are the last placeholders in either manual. **Done in S5, 2026-10-21**, under the names the sittings
used: iOS §7.2 embeds `ios/search-tips`, the whole 1206×2622 frame, as the iPhone captures the
manual embedded until build 48 were; iOS §7.12 embeds `ipad/semantic-offer` and then
`ipad/semantic-zero-result-matches`, whose Download Volume rows keep the placeholder's second
clause; Mac §7.11 embeds `macos/search-zero-result-meaning`. Neither manual holds a `[SCREENSHOT`
line now.

### A7's slot: none in build 51

The plan's S0 row names A7's slot (a *Siri, Shortcuts and Spotlight* section in each manual, with a
capture). The owner deferred A7 past build 51 on 2026-10-18 (decision 57; the plan's §6h, #1723):
neither manual has the section, and this sweep has no slot for it. When A7 ships, the slot returns
with it — on iPad, Spotlight's suggested document or the Shortcuts app running Open or Summarize;
on the Mac, Spotlight — and Siri surfacing a document is a device capture (S6's kind), since the
simulator's Siri never called the spike app.

### The four files embedded nowhere: the verdicts

All four are the owner's build-47 device captures (the owner's status bar and data: the
*Kennanology* collection, the *Cold War Origins* tag), not the demo set, and each shows retired UI.
The #1081 rule is that an unreferenced file is deleted, not refreshed.

- `ipad/research-rail-portrait` — **delete.** The rail in portrait beside the Long Telegram. No
  manual sentence describes the rail in portrait; §4.2's slot is `research-rail`, landscape.
- `ipad/semantic-search-loading` — **delete.** Meaning mode's waiting cloud (the Sentiment lens,
  green and red) under the build-47 strip's wording, which A9 and #1721 have since changed. §7.1
  describes the cloud in words and has no slot.
- `ipad/indexing-banner-portrait` — **delete.** A portrait Browse root with the build-47 banner
  over the Sentiment cloud; the iOS manual is landscape-first, and the banner's slot, if the owner
  takes one, is the iPhone's.
- `ios/indexing-banner` — **re-shoot in S3 if the owner gives §4.8 a figure, otherwise delete.**
  The file shows the build-47 banner: the Actions lens's cloud (retired in build 48, #1346), *~0s*
  left (A11 prints seconds from five up) and the old count line. §4.8 is the manual's longest
  section with no image, and the banner is the first thing a new reader sees, so S0 recommends the
  slot: one frame, a queue of several volumes indexing, so *Volume N of M* and the estimate show,
  with the caption written from §4.8's first paragraph. The decision is the owner's, in S5.
  **Answered on 2026-10-21 (17:14), in S3: §4.8 takes the figure.** S3 retook the file; S5 embeds it.

**Done in S5, 2026-10-21.** The three files marked delete are deleted. `ios/indexing-banner` is
iOS §4.8's figure, after the section's first paragraph, cropped by S5 to the bottom 552 rows of S3's
1206×2622 frame (rows 2070 to 2621): the banner opened by its chevron, *Volume 8 of 11*, and the tab
bar with the Settings tab's dot badge, a strip as the build-47 file was (1206×570). The whole frame
is in #1753's commit and S3's raw folder.

### The README's hero row and its mirror (S5)

`README.md` line 21 embeds `macos/search`, `macos/cross-reference-graph` and `ipad/semantic-map`;
`Docs/EditableContent/03-Repository-README.md` line 47 mirrors the row whole. Decision 34 swaps the
graph for `ipad/source-explorer` in S5, in both files in one change (the mirror is checked against
the README). The two files that stay are retaken in S4 and S1. **Done in S5, 2026-10-21**: the
middle column reads *Source Explorer (iPad)* over `ipad/source-explorer` in both files, the block
is character for character the README again (9,700 characters), and `Amendment-Log.md` has the
bullet. No test compares the two: the comparison was made by script.

### The store frames (the kit's §3 and §7)

Every iPad and Mac frame but four is one of the manuals' files, retaken above: 01 `search-results`
/ `search`, 02 `research-rail` / `research-strip`, 03 `semantic-map` (both), 04 `source-explorer`
(both), 05 `trip-packet` (both), 06 `cross-reference-graph` (both), 08 `collections-editor` /
`collections`, 09 `series-production` (both), 10 `analytics` (both), 11 `chronology` (both), 12
`semantic-search`, 13 `person-analytics-network` (Mac), 14 `archival-analytics` (both). The four
with no capture: **07** (the Cite sheet on iPad, the Cite popover on the Mac), **12** on the Mac
(the Search window in Meaning mode), **13** on iPad (Person Analytics' Network, which also goes to
the 26.5 device), and the **three iPhone frames**, which the listing cannot be submitted without.
The kit's §9 figures for the cross-volume citations (8,637 into 5,747 from 185) are build 50's;
A17 and A18b moved them to 38,600 into 20,273 from 513, which the composer's sublines do not quote.
After S4, `SCALE=1 OUT_DIR=~/Desktop/store python3 tools/marketing/compose.py` for the store
sizes, and the drafts re-run into `Planning/marketing-drafts/`. **Done in S5, 2026-10-21**:
`shots.json` names a capture for all 34 frames, every one stamped *build 1861*, and the composer
wrote them twice, the drafts into `Planning/marketing-drafts/` and the store sizes into
`~/Desktop/store` (the sittings' ledger, S5). **Composed again in R1, 2026-10-22**, with
`SCALE=1 STAMP=0` (#1763): the 34 frames for App Store Connect are in `~/Desktop/store`, none
stamped, and the drafts are rendered again (the sittings' ledger, R1).

### Caption and sentence fixes S5 already owes

1. iOS §6.1g, the `browse-archives-provenance` caption: *the ten kinds of file* → *the eleven
   kinds of file* (row 14).
2. Mac §6.3, the `people-detail` caption: drop *scrolled to its VIAF and Wikidata links and*; the
   frame bears out the Career section (row 49).
3. iOS §15.1, the `analytics` caption: read against the frame, where the Measure picker is dimmed
   while four terms are compared (row 35).
4. iOS §7.12's placeholder: if no undownloaded hit can be shown, drop *with a Download Volume
   button on an undownloaded hit* (P2b).
5. Mac §15.4, the `crossref-analytics` caption: widen beyond the heat matrix if the two rankings
   now carry their labels (row 64).
6. The two captions that changed since build 48 (`ipad/search-results`, `macos/archival-analytics`)
   are already the new wording; the retakes must match them.
7. The README hero row and its mirror (decision 34).
8. Close the *Stale after build 48 (Mac)* and *Not re-checked after the build-49 wave* sections
   above once every file they name is retaken.
9. The sentences *Found by S1* marks *S5* (below the sittings' ledger), read against S1's frames.
10. S3's files: `ios/search-tips` replaces iOS §7.2's placeholder; `ios/indexing-banner` goes into
    §4.8, with a caption written from its first paragraph. It is a whole frame, where the build-47 file
    was a 1206×570 strip of the bottom, so S5 chooses the crop. The kit's six iPhone files go into
    `tools/marketing/shots.json`. Its iPhone `reader` route names d474, which is not the Long Telegram
    (*Found by S3*, 1).
11. S4's files: `macos/search-zero-result-meaning` replaces Mac §7.11's placeholder, the last in
    either manual; `macos/cite-popover` and `macos/search-meaning` go into `tools/marketing/shots.json`
    as the Mac's frames 07 and 12, whose `route` placeholders they end. Read Mac §15.4's caption
    against *Found by S4*, 3: the rankings carry their titles now (item 5).

**Done in S5, 2026-10-21**, each read against its frame:

1. *The eleven kinds of file*; the frame's lens draws eleven doors.
2. The caption names the Career section alone.
3. The caption says which controls the frame draws dimmed while four terms are compared — the
   chart-or-table control, the Measure picker, the fit line and Chart colors — and that the value
   control and Export are not.
4. The clause stays: P2b shows a Download Volume button on three matches, in the two *Paris Peace
   Conference* volumes S1 removed with frus1948v01p2.
5. By a second figure. The frame is the heat matrix alone, so its caption stays; S4 kept the
   Most-Referenced Documents ranking over 1961–1963 with the sitting's notes (19:38, 960×900 points,
   every title whole), and S5 embedded it above the matrix as `macos/crossref-analytics-ranking.png`.
6. Both retakes match their captions.
7. Done: *The README's hero row*, above.
8. Both sections are closed above, each line struck with what its retake shows.
9. Findings 1, 2, 5, 6 and 7: iOS §6.1g's *about 29%*; §6.1h's volumes listed by identifier;
   §7.12's example question, *Why did the wartime alliance unravel?*; §7.12's row for a match in an
   undownloaded volume (*Document d32 in …*), with the Mac §7.11 sentence for the same row; §15.7's
   third direction, *reaches past both ends*. Finding 4 was read and left: the frame's 491 matches
   §6.2a, *detected* is the manuals' word for these topics throughout (the Topics accordion, *By
   Detected Topic*), and *assigned* is the owner's wording in the index's own header. Finding 8 is a
   test file's comments, not a manual.
10. `ios/search-tips` in §7.2; `ios/indexing-banner` in §4.8, cropped (*The four files*, above); the
    six iPhone files in `shots.json`, with `ios/document` (d475) in place of the d474 route; and the
    recipe's point 4 names d475.
11. `macos/search-zero-result-meaning` in §7.11; `macos/cite-popover` and `macos/search-meaning` in
    `shots.json`, with S1's `ipad/cite-sheet` and `ipad/person-analytics-network` as the iPad's
    frames 07 and 13.

S5's own reading of the frames changed eight sentences and captions more; its entry in the
sittings' ledger lists them.

### Found by S0 — for the new plan of record (decision 82)

Read in the manuals at `b4dcd527` against the bundled files; none is a capture, and none was seen
in the app.

Each says where it is and why it matters before submission; the owner decides what the new plan
takes. *After S5 (2026-10-21):* 4, 5 and 7 are answered and done (S3's figure, S1's frame, S4's
patch); 1, 2, 3, 6 and 8 wait for the new plan. *After L1 (2026-10-21):* 1, 2 and 3 are corrected
in both manuals from the bundled files (#1762).

1. **Mac §6.1 (line 298) says 89,449 documents belong to no cluster; the shipped map says
   88,059** (`semantic-map-index.json`, `layout.unclusteredCount`, generated 2026-10-15 after B4),
   which is the figure iOS §6.1h prints. The Mac sentence is the earlier layout's. *Why it
   matters:* the two manuals disagree by 1,390 on a figure the Clusters screen states on its own
   face ("about 28% of the corpus … belongs to no cluster"), and a reader who compares them finds
   one wrong.
2. **iOS §6.1h (line 425) says the largest cluster holds 37,865 documents; the shipped map's
   largest holds 37,899** (cluster 3, *nanking · shanghai · chinese · tientsin*). Mac §6.1 says
   *nearly 38,000*, which holds. The iOS example label in the same section (line 423), *nanking ·
   chinese · shanghai · chungking*, is not the shipped file's either. *Why it matters:* the
   Clusters list prints each cluster's count and label on its row, so the sentence is checkable
   against the screen beside it, and is off.
3. **Both manuals say the authority holds 3,985 archival collections (iOS §14.6, line 1219; Mac
   §14.5, line 1017); A18 regenerated it to 3,977** (`collection-usage-index.json`'s
   `coverage.authorityCollectionCount`; A18's entry records 3,985 → 3,977). *Why it matters:* the
   figure is the manuals' headline claim for the Collections view, and the app can show eight
   fewer than it promises.
4. **The owner's decision on `ios/indexing-banner`** (above): a §4.8 figure, or the file deleted.
   *Why it matters:* a file on disk that nothing embeds is the #1081 rule's own case for deletion,
   and the sweep cannot close with it undecided; nothing for App Review. *Answered on 2026-10-21 in
   S3: a figure. S3 retook the file.*
5. **The zero-result Meaning frame's Download Volume button** needs volumes removed on purpose
   (P2b), or the placeholder's second clause dropped. *Why it matters:* a `[SCREENSHOT: …]` line
   left in a shipped manual reads as unfinished; the clause decides the frame's recipe.
6. **#1620 is open and iOS 27.1's runtime is not installed**, so the seven analytics captures are
   taken under iOS 26.5 (or on the owner's iPad); decision 72's re-test is still owed. *Why it
   matters:* not a defect a user sees — the owner's iPad under iOS 27 runs these screens — but
   the simulator cannot be trusted for the seven until the re-test says so.
7. **The Mac check copy's status chip reads Local Only** without the never-committed patch: S4
   patches or crops, and the ledger says which. *Why it matters:* a Mac capture with *Local Only*
   in the status bar would contradict Mac §4.4's healthy chip; cosmetic to the sitting, nothing
   for App Review. *Answered on 2026-10-21 in S4: patched under a launch argument, never
   committed.*
8. **Both manuals carry an *AI Generated* notice under their titles**, kept until the owner's
   review of both as they stand (`Planning/Manual-Revisions-Pending.md`'s note of 2026-10-07;
   `Planning/Manual-Update-Build-49-Owner-Review.md` lists what the review needs). *Why it
   matters:* the notice is the first line a reader of either manual meets after the title, and
   the review it waits for is the owner's; S5 edits the manuals under it either way.

### The sittings' ledger (to fill as each runs — the X-8 rule)

- **S1 — run 2026-10-21, 12:40 to 16:03; the session captured, on the owner's word of 12:46.**
  Version 1.0, build **1861**, the `AppStore` configuration built for the simulator (`-target
  FRUSExplorer -sdk iphonesimulator ARCHS=arm64`) from `v2` at **`b24de205`** (its code is
  `b4dcd527`'s), with build 48's one local-only patch, never committed and reverted in the worktree
  once the build was made: `SyncStatusBanner.isWorthShowing` returns false under
  `-FRUSScreenshotHideSyncBanner YES` (signing the simulator into iCloud would have sent the demo
  data to the owner's container). **Every file predates the `build-51` tag (decision 83): a screen
  that a fix after `b24de205` changes is retaken.**
  - **The device:** a new iPad Pro 13-inch (M5) simulator, `3D2607D9-AAF8-431D-A69C-0596A25FE9AA`,
    iOS 27.0 (24A434), created for the sitting and never used by a UI suite; landscape, turned by a
    throwaway XCUIDevice test (`simctl` has no orientation command); 2752×2064; the demo status
    bar; and **Windowed Apps**, the multitasking mode a new device starts in, kept on the owner's
    word of 13:46: each window fills the screen, and the status bar ends *FRUS Explorer*, as the
    build-48 frames' does.
  - **The time and date erased after capture**, on the owner's word of 2026-10-21, once the pull
    request was open ("can you edit the screenshots to obscure the time and date?"). In all 44
    frames the status bar's *9:41 AM  Wed Oct 21* (ink at rows 21–46, columns 51–322 of the
    2752×2064 frame) was filled with its own background: rows 15–52 and columns 45–328, blended
    column by column from the four rows just above the box into the four just below it, with grain
    matched to the backdrop where it has any (`stage-manager`'s wallpaper). No pixel outside that
    box changed, checked against the frames as captured, and *FRUS Explorer* stays where iPadOS
    draws it, from column 349. The script is kept with the sitting's notes, outside the
    repository; an iPad frame a later sitting takes matches the set only if it gets the same edit.
  - **The corpus:** the 553 manifest volumes from the local corpus at `6170e4b32` (2026-10-14, the
    commit A18b's bundle was built from), indexed on the device from empty in 11 minutes under
    `Scripts/heavy.sh`: index version 71, People rollup 12, FTS schema 4; 553 volume structures,
    321,749 document rows, 18,009 rollups. **The encoder:** EmbeddingGemma 2,
    `embeddinggemma-2-Q8_0.gguf` (310 MB), downloaded in the simulator through the app after P2a,
    with vectors for all 553 volumes.
  - **The demo data:** S0's recipe, all through the UI. The scope *Soviet Union 1945-1950* holds
    frus1945v05, 1946v06, 1947v04, 1948v04, 1949v05 and 1950v04. A third working corpus, *Soviet
    intentions* (1,000 of 11,122), was added so `browse-working-corpora` shows the amber line: the
    recipe's two are complete captures and draw none. The collection's headings are *Moscow,
    February 1946* and *Washington Responds*; the visit holds 8 targets at one repository; the
    Long Telegram carries a note (its footnote 44's request, read in the TEI) and the tag
    *Containment*.
  - **On the 27.0 device, 43 files:** rows 1, 2 and 4 to 40, **the seven marked 26.5 among them**
    (the owner's word of 12:46: try 27.0 after every other capture, then 26.5; the device lived,
    below), and four new files: `semantic-offer` (P2a, before the encoder),
    `semantic-zero-result-matches` (P2b), `cite-sheet` (the kit's frame 07 on iPad: the Long
    Telegram ▸ Cite, the Copy as… menu open on Copy BibTeX and Copy RIS; nothing copied) and
    `person-analytics-network` (the kit's frame 13 on iPad: Network, focus *Kennan, George Frost*,
    *Acheson, Dean Gooderham* selected, 56 shared documents, as the Mac's frame reads). S5 wires the
    two kit frames into `tools/marketing/shots.json`. The paired frames' partners are
    `browse-archives-collection-citing`, `people-detail-records` and `trip-packet-options`.
  - **Under iOS 26.5, 1 file:** `stage-manager` (row 3), on a second new device,
    `5ED7E25B-3690-4F69-A412-73262634A265`, iOS 26.5 (23F77), holding a clone of the first's
    container, in Stage Manager for this frame and in Windowed Apps again afterwards: the main
    window behind (Browse ▸ Subseries), the Long Telegram's popped-out window at the left, its
    Related Documents window at the right. Row 3 moved because Stage Manager killed the 27.0
    device's render server (below). The brief's twin `9F3D84A4` took no capture.
  - **Route notes.** P2's question is *Why did the wartime alliance unravel?* (finding 5 below).
    `word-cloud` came from Settings ▸ Volume Scopes ▸ long-press ▸ Word Cloud, as build 48's did
    (Analysis Tools ▸ Corpus Word Cloud starts a whole-library read before a scope can be picked),
    on a launch whose log read `Lemma=available`: the launch before it was Limited and drew #1608's
    *Counted as printed* line. `browse-corpus-drill` and P2b were taken with three volumes removed
    through Settings ▸ Volumes & Storage (frus1948v01p2, frus1919Parisv01 and frus1919Parisv09,
    their vectors fetched again so the semantic list ranks them), and a snapshot of the container
    taken before the removals was restored afterwards. `browse-root` has Subseries open, so it
    differs from `sidebar-landscape`; `people-detail` is scrolled 45 pt so *Find all mentions* is in
    frame. A relaunch the system makes (after a crash or a reboot) carries no launch arguments, so
    it opens on the onboarding wizard with the banner showing: on the 26.5 device the two flags
    were written into the app's preferences with the simulator shut down.
  - **Recordings R and T** (the owner's word of 12:46): one clip a beat, `simctl io recordVideo
    --codec=h264` on the 27.0 device at 2752×2064, R1 to R7 and T1 to T7, 250 MB, kept outside the
    repository in `~/Library/Caches/FRUS-Explorer/s1/recordings/`, with an 89 s second take of R2
    narrowed to 1946, whose People facet reads *Nothing to break down here*. simctl writes a frame
    only when the screen changes, so a held still is shorter in the file than on the clock. T's last
    two beats follow the app, not the kit's script (findings 16 and 17). The App Preview's pass B
    (the kit's §4) was not recorded. The recordings came after every capture and changed the
    27.0 device's store (a fourth corpus, two documents and a headnote in the collection, the
    Teaching reader preset): **the clean demo state is the container snapshot
    `~/Library/Caches/FRUS-Explorer/s1/snapshot-A`** (6.4 GB, taken before the removals), which
    `stage-manager`'s device was cloned from and which S4 seeds the Mac from.
  - **#1620, measured on this Mac's iOS 27.0 runtime.** On the new 27.0 device the semantic map
    window (13:41) opened and closed, and after its 14:36 boot Corpus Analytics (twice),
    Cross-Reference, Archival, Semantic and Person Analytics and Chronology all opened, drew and
    closed while backboardd kept one process until the 15:31 shutdown. **Switching the device to
    Stage Manager at 14:09 killed backboardd** (SIGABRT in `-[MTLTextureDescriptorInternal
    validateWithDevice:]` under `CA::OGL::FlattenNode::retain_surface`, #1620's signature) with no
    Analysis Tools window ever opened on it; the device came back in portrait and launched the app
    normally afterwards. Under iOS 26.5, Stage Manager with three FRUS windows left backboardd
    alive. The crash report is kept with the sitting's notes, outside the repository.
- **S2 — run 2026-10-21, 16:26 to 16:54; the session captured, on the owner's word of 16:31.**
  Version 1.0, build **1861**, the `AppStore` configuration built for the simulator as S1's, from
  `v2` at **`8b6afa95`** (S1's #1751 merged; nothing outside `Docs/` and `Planning/` has changed
  since `b4dcd527`, so its code is S1's), built 16:29 to 16:32 under `Scripts/heavy.sh` with build
  48's local-only banner patch, never committed and reverted in the worktree once the build was
  made. **Both files predate the `build-51` tag (decision 83): a screen that a fix after
  `8b6afa95` changes is retaken.**
  - **The device:** a new iPad Pro 13-inch (M5) simulator, `A913C7F8-512F-4725-AF70-DAE4682B4E2C`,
    iOS 27.0 (24A434), created for the sitting: no volume and no index were ever on it (the offline
    convention), it was never signed in to iCloud, and it keeps the default wallpaper, which only
    the clips' first seconds show. Turned to landscape on its home screen by S1's throwaway
    XCUIDevice test, given a case that rotates without activating the app, so the app's first
    launch was the sitting's own; 2752×2064; the demo status bar; **Windowed Apps**, as S1's, each
    window filling the screen. Every launch carried `-FRUSScreenshotHideSyncBanner YES` and no
    `-hasCompletedOnboarding`.
  - **`onboarding-volumes`** (16:38:34, on the first launch): Get Started ▸ Add Volumes, Corpus
    selected, the Concepts view, the line *553+ volumes · ≈ 3.5 GB — the entire series, fully
    offline. Recommended for full functionality.* (build 48's read *≈ 3.3 GB*), Back, Skip and
    Continue. The cloud changes view about every four seconds with a crossfade of about one, so
    the frame is the third of a sixteen-frame burst whose first five are wholly Concepts. The
    seeded layout is build 48's.
  - **`series-production`** (16:51:39): Skip ▸ *You're all set — Nothing is downloading yet …* ▸
    Finish, so nothing was ever downloaded; then Research ▸ FRUS Research Guide ▸ Next seven times
    ▸ *Production & Timeliness*, page 8 of 11, scrolled so *Publication lag over time* heads the
    sheet, as in build 48's take: the scatter coloured by era, the dashed timeliness step line, the
    legend, and the head of *Volumes published per year*. The sheet sits over the Research tab, the
    manual's first route, where build 48's sat over Settings ▸ About; the sidebar's Projects list
    shows the starter project *My Research*.
  - **The time and date erased after capture**, by S1's script unchanged (byte for byte), as the
    owner asked of S1's frames. In each frame 2,382 pixels changed, all inside the box (rows 15–52,
    columns 45–328); alpha and *FRUS Explorer* are untouched. Both backdrops are flat there (white
    in `onboarding-volumes`, the dimmed sidebar's 182, 186, 192 in `series-production`), so the
    fill is exactly that colour and no grain was added.
  - **The kit's pass A** (the splash and onboarding): two clips, `simctl io recordVideo
    --codec=h264`, 2752×2064 after the display matrix, kept outside the repository in
    `~/Library/Caches/FRUS-Explorer/s2/recordings/` with the time and date as recorded. **A0**
    (33.7 s) is the app's first launch after install, which confirmed that the splash renders on
    this build before the take, as the kit asks. **A1** (94.3 s) is the take, from the home
    screen: the launch at 10.7 s, the splash 12.0–13.7 s, Welcome to 20.2 s, Add Volumes on Corpus
    to 32.5 s, Subseries ▸ *1969-76* picked at 50.0 s (*kissinger, nixon, president, soviet*),
    Volume ▸ frus1861 picked at 79.2 s (*seward, majesty, vessel*; *blockade, recognition,
    neutrality*). The Volume list runs oldest first with no search field, so the take picks its
    first row. The kit's *prepareVolumes* trap did not show: after Volume was tapped the cloud went
    back to the corpus's words within half a second, and the volume's own words came within a
    second of the pick. The hand-off from the splash to onboarding is findings 1 and 2 of *Found by
    S2*, below.
  - **Left:** the device holds the app and nothing else. It was shut down at 16:54, and the
    session's simulator pane in the Claude app booted it again: while the pane is open, it re-boots
    the device within a second of a shutdown. The build and both clips are under
    `~/Library/Caches/FRUS-Explorer/s2/` (957 MB) until the owner says.
- **S3 — run 2026-10-21, 17:09 to 18:41; the session captured, on the owner's word of 17:14.**
  Version 1.0, build **1861**, the `AppStore` configuration built for the simulator as S1's and S2's
  (`-target FRUSExplorer -sdk iphonesimulator ARCHS=arm64 -jobs 4`), from `v2` at **`16dc2160`** (S2's
  #1752 merged; nothing outside `Docs/` and `Planning/` has changed since `b4dcd527`, so its code is
  S1's and S2's). It was built 17:10:43 to 17:13:43 under `Scripts/heavy.sh` with build 48's local-only
  banner patch, never committed and reverted in the worktree once the build was made. **Every file
  predates the `build-51` tag (decision 83): a screen that a fix after `16dc2160` changes is
  retaken.** The owner's answers of 17:14: the session captures; iOS §4.8 takes the banner as a
  figure; the kit's frames 04 and 11 are taken too; the iPhone App Preview's pass B is not.
  - **The devices:** two new simulators under iOS 27.0 (24A434), portrait, the demo status bar, never
    signed in to iCloud, with the default wallpaper, which no frame shows. The **iPhone 17 Pro Max**,
    `7449CA80-3C9F-4121-A42A-EE586208D6F2`, 1320×2868, took the kit's frames; the **iPhone 17 Pro**,
    `3025E8FF-B213-4B10-8E7B-67E6D635B13B`, 1206×2622, took the manual's two. Every launch carried
    `-hasCompletedOnboarding 1 -FRUSScreenshotHideSyncBanner YES`.
  - **The corpus and the demo state:** each container holds a clone of S1's container snapshot
    `~/Library/Caches/FRUS-Explorer/s1/snapshot-A`, the clean demo state S4 also seeds from. It holds
    the 553 volumes of the local corpus at `6170e4b32`, index version 71 built by this code, rollup 12,
    S1's demo data, the encoder and 553 vector shards. Its `Library` was cloned with `cp -c` before
    the app's first launch, leaving out `SplashBoard` and `Saved Application State` (the iPad's launch
    snapshots and scene state). The device was then rebooted, and no re-index ran. The iPhone 17e
    `4E79C806`, which the brief offered, was not used: its library is index version 65, built from
    2026-10-08's files, so build 1861 would have re-indexed all of it, and the frames would come from
    other files than the iPad's. `snapshot-A` was only read.
  - **On the 17 Pro Max, the kit's six** (S5 wires them into `tools/marketing/shots.json`):
    - `ios/search-results` (frame 01, 17:22:24): Search ▸ Keywords ▸ *Berlin blockade*: *900 results*,
      *Page 1 of 36*, the MATCH strip `"berlin" AND "blockade"`, the *Working on:* line, the facet
      sheet closed.
    - `ios/search-facets` (frame 01's second take, 17:23:40): the binoculars menu ▸ Facets, the sheet
      at its medium height over the dimmed list: *This result set — Describing all 900 matches*, Years
      open and sorted by *Most documents* (1949 112, 1948 90, 1962 78 …).
    - `ios/document` (frame 02, 17:28:10): **`frus1946v06/d475`, the Long Telegram**, in Read mode with
      one yellow highlight on *so strange to our form of thought*, made in the app; no selection and no
      menu. The kit's route names d474 (*Found by S3*, 1).
    - `ios/semantic-map` (frame 03, 17:28:48): Browse ▸ Analysis Tools ▸ Semantic Analytics, a sheet
      at full height: the explainer card, the *Experimental* line, the map coloured by Regions over the
      whole corpus, the caveat line beneath it.
    - `ios/source-explorer` (frame 04, 17:29:20): `frus1952-54v02p1/d41` ▸ the rail, a bottom sheet ▸
      Sources: *S/S – NSC files, lot 63 D 351, NSC 140*, its provenance (a State Department lot file,
      RG 59, 63 D 351) and the NARA Catalog record it resolves to.
    - `ios/chronology` (frame 11, 17:32:17): Analysis Tools ▸ Chronology over September 1 to November
      30, 1962, set with the wheels: *1,154 documents*, the legend (Microfiche Supplement 284, Cuban
      Missile Crisis 202 … Other volumes 397), the chart, *714 documents span more than a year*, *25
      documents extend beyond this range (1 begins before · 24 reach past both ends)*, the counts of
      S1's iPad frame. The sheet opens on the corpus's last year, *Dec 31, 1991 – Dec 31, 1992*.
  - **On the 17 Pro, the manual's two:**
    - `ios/search-tips` (P1, iOS §7.2, 17:42:45): Search ▸ Keywords ▸ *Berlin blockade* ▸ ••• ▸ Search
      Tips. The sheet sits at half height over the dimmed results: *Search Tips* with Done, then
      *Typing a search* and its first three tips, each as typed with what it does. `berlin crisis`
      finds every word in any order; `negotiate` also matches its other forms; and `"cold war"` is a
      phrase in quotation marks, straight or curly.
    - `ios/indexing-banner` (iOS §4.8, 18:06:46): Settings ▸ Volumes & Storage, with the eleven
      volumes of 1951 removed through Free Up Space and queued again through Download from GitHub ▸
      Subseries. *Active Downloads* lists frus1951v07p2 with Cancel. The banner is opened by its
      chevron: *Volume 8 of 11*, the current volume's bar, *~1s*, one waiting title with its clock,
      and *Learn about FRUS while you wait →*. The Settings tab carries its dot badge. The frame is the
      20th of a burst of `simctl io` screenshots taken back to back through the queue. The build-47
      file was a 1206×570 strip of the bottom of a dark-mode frame showing the single-volume banner;
      the retake is the whole frame, and S5 chooses the crop.
  - **The banner's six queues** (findings 2 and 3), with the heavy lock held from 17:47:16 to
    18:36:07 while they downloaded and indexed:
    - Runs 1 and 2: the 27 files of 1961-63 moved out of the container by hand and queued again; each
      file was re-indexed on arrival.
    - Runs 3 and 5: the eleven of 1951 removed through Free Up Space and queued again. Run 4: the 27
      of 1961-63 the same way. Run 6: the ten of 1949.
    - Every re-downloaded file is byte-identical to the local corpus, and the device ended with 553
      files and 553 volume structures. Only run 3's frame is kept: a 27-volume queue's *of N* reads
      short (finding 2).
  - **The time erased after capture**, as in S1's and S2's frames (the owner's word of 2026-10-21).
    An iPhone's status bar prints the time alone, *9:41*, with no date, left of the Dynamic Island.
    The ink sits at rows 77–116, columns 167–267 on the 17 Pro, and rows 75–117, columns 192–299 on
    the Pro Max. S1's script, with the box moved to rows 71–122 × columns 161–273 and rows 69–123 ×
    columns 186–305, fills it column by column from the four rows above into the four below. It adds
    grain above 0.2 where S1's added it above 0.5, since an iPhone's glass bar dithers by one level;
    the three frames over one measure 0.24 to 0.44. In each frame 1,907 to 5,726 pixels changed, all
    inside the box, with alpha untouched. Under twelvefold contrast the box cannot be told from its
    surroundings. The script and the before-and-after sheets are kept with the sitting's notes,
    outside the repository.
  - **Every iPhone frame carries a 3×3 black square at its top-left corner pixels**, under
    `simctl io`'s `--mask` default and `ignored` alike; the iPad frames have none. It lies under the
    display's rounded corner, and the composer's corner radius clips it, so it is left as captured.
  - **Left:** both devices shut down at 18:39 and kept until the owner says, each holding the app and
    the cloned library. The 17 Pro shut down after the owner closed the session's simulator pane,
    which had re-booted it. Nothing is booted or running. The build, the raw frames and the bursts
    (1.0 GB) are under `~/Library/Caches/FRUS-Explorer/s3/`.
- **S4 — run 2026-10-21, 18:55 to 20:25; the session captured, on the owner's word of 19:01.**
  Version 1.0, build **1861**, the isolated check copy (`tools/mac-check-copy/`): `setup.sh --ref
  HEAD --prefix frus1961-63v09` at `v2` **`f7ce0188`** (S3's #1753 merged; nothing outside `Docs/` and
  `Planning/` has changed since `b4dcd527`, so its code is S1's to S3's), then `build.sh --no-launch`
  under `Scripts/heavy.sh`, 19:03:01 to 19:06:02, `** BUILD SUCCEEDED **` with the copy's nine expected
  warning lines. The tag S0 named waits for submission (decision 83), so the copy was built from
  `v2`'s head. It went into the shared scratch `~/Library/Caches/frus-mac-check`, reusing its `dd/`:
  bundle id `bottsywattsy.FRUS-Explorer.maccheck`, the `AppStore` configuration, ad-hoc signed, the
  local-only store under `FRUS_MAC_CHECK`, `com.apple.security.get-task-allow` its one entitlement.
  The product was copied to `~/Library/Caches/FRUS-Explorer/s4/app/` and launched from there with
  `open -n --env CFFIXED_USER_HOME=…`. The owner's answers of 19:01: the session captures with
  `screencapture`, as build 48's did; the chip is patched; recording A and the Mac App Preview are
  recorded too. **Every file predates the `build-51` tag (decision 83): a screen that a fix after
  `f7ce0188` changes is retaken.** macOS 27.0.1 (26A434), the M5 MacBook Air's display at 1710×1107
  points.
  - **The status chip: patched, never committed.** One local-only patch, made in the copy's extracted
    source after `setup.sh` and before the build, so the worktree and `v2` never held it: under
    `-FRUSScreenshotHealthySyncChip YES` the status bar draws the idle *iCloud Sync* chip of Mac §4.4
    (`SupportingViews.swift`, `cloudKitStatusChip`). Build 48's other patch, the local store, has been
    the copy's compile-time switch since #1512. After the sitting the patch was taken out of the
    shared scratch and the shared copy rebuilt without it (20:21:27 to 20:24:39, under the lock); the
    patched product stays with S4's files. The diff is kept with the sitting's notes.
  - **The fake home** is S4's own, `~/Library/Caches/FRUS-Explorer/s4/home`, not the shared copy's,
    which holds A19's 38-volume library and was not touched. It is an APFS clone (19:03:38) of S1's
    container snapshot `snapshot-A`: `Library/Application Support/FRUSExplorer/` whole and the store.
    That holds the 553 volumes of the local corpus at `6170e4b32` with their 96 figure folders,
    `frus.db` at index version 71 with rollup 12, 553 vector shards, and the encoder, EmbeddingGemma 2
    with its pin marker, which S1 downloaded through the app. The store is `default.store`, its
    write-ahead log folded in on the clone, renamed `FRUSExplorerLocal.store`. `snapshot-A` was only
    read. The copy opened the library without re-indexing: 553 volume structures, 321,749 document
    rows. **The preferences** escape a fake home, so the shared copy's 96 keys were exported first,
    the domain held the iPad's 15 for the sitting (the active project and the version-71 stamps), and
    the 96 were put back afterwards, identical key for key. `defaults import` reported success and
    changed nothing; CFPreferences, key by key, did it.
  - **Capture:** each window with `screencapture -o -x -l <window id>` while the copy was in front, so
    its chrome is active and no shadow is drawn. Window sizes were set with System Events: 1440×900
    points (2880×1800 pixels, the kit's Mac preset) for twelve of the kit's fourteen Mac frames, and
    build 48's sizes for the rest, `analytics` (frame 10, 1440×640) and `person-analytics-network`
    (frame 13, 1120×760) among them, since a taller window adds only empty canvas to either. The copy
    was driven with computer use, its bundle id alone, under full-screen control. Where a text field
    held the caret, a burst was taken and a caret-off frame kept: the frames differed only in the
    caret's column of four pixels. No frame holds the menu bar, so there is no clock to erase.
  - **The 29 files in `macos/`**, 26 retaken and 3 new, each read against its row before it was kept.
    The window's size is in points, and the demo data is S1's plus what is named:
    - `toolbar` (1440×52): the top 104 rows of `research-strip`, the size of build 48's strip.
    - `research-strip` (1440×900, 19:09): the Long Telegram (`frus1946v06/d475`) with the Research
      panel: S1's note, *Containment*, the collection, and a yellow highlight on *so strange to our
      form of thought*, made in the copy so that `research` has a strip.
    - `document` (1440×900, 19:18): `frus1948v02/d399`, the panel closed.
    - `browser` (1440×880, 19:13): frus1946v06's page under the *Working on:* bar.
      `browse-all-volumes` (1440×880, 19:13): Published order.
    - `people-list` (900×823, 19:14): at the *Adams, Alvin* pair, the rows of S1's iPad frame.
    - `people-detail` (620×532, 19:15): the People window with Kissinger's sheet scrolled to Career,
      *Secretary of State, 1973-09-22 – 1977-01-20*, from the register. Build 48's composition, with no
      VIAF or Wikidata link (A4d), so its caption is S5's to rewrite (item 2).
    - `topic-index` (900×820, 19:17): *Topic area: Cold War — 6 topics*, Berlin crisis's sheet open.
    - `search` (1440×900, 19:19): *Berlin blockade*, 900 results, Facets open on Subjects.
      `search-tips` (1440×900, 19:19): the Tips panel under the results, Facets closed, as build 48's.
    - `saved-searches` (1440×900, 19:20): S1's *Berlin blockade* and build 48's other two, saved in
      the copy under their names: *NSC 68 drafting* (`"NSC 68"`) and *Cuban missile crisis -
      quarantine* (*Cuba quarantine*).
    - `research` (1340×880, 19:23). `collections` (1440×900, 19:24): *The Long Telegram and Its
      Readers*, Document 475 in the inspector.
    - `source-explorer` (1440×900, 19:25): `frus1952-54v02p1/d41` ▸ Sources, its NARA record and 623
      archival neighbors.
    - `trip-packet` (1440×900, 19:26): Export packet with Lot 63 D 351 heading the sheet, both claim
      lists, Options at its head, and Share and Share as PDF at its foot (#1444).
    - `cross-reference-graph` (1440×900, 19:27): `frus1952-54v02p1/d16`, Timeline, the list open.
    - `analytics` and `analytics-table` (1440×640, 19:30): *Berlin*, 1944–1975, *View 9,192
      documents*.
    - `word-cloud` (1280×900, 19:32): *Soviet Union 1945-1950*, Distinctive, Concepts, *54 terms from
      4,666 documents*, the eligibility line, and no *Counted as printed* line.
    - `person-analytics-trends` (1280×1072, 19:33): 1940–1992, Kissinger, Rusk and Dulles picked and
      Acheson added, build 48's set. `person-analytics-network` (1120×760, 19:34): Kennan, with
      Acheson selected, *56 shared documents*.
    - `crossref-analytics` (960×900, 19:37): the heat matrix for 1961–1963, its heading, caption,
      fifteen rows and legend in frame, every row label whole (#1445, #1480).
    - `archival-analytics` (1440×900, 19:39): *60,019 source notes*, 753 collections, *Central Files
      Hidden*: S1's counts. `semantic-map` (1440×900, 19:39).
    - `chronology` (1440×900, 19:41): 10/14/1962 to 11/20/1962, build 48's range and recording A's: 668
      documents, *670 documents span more than a year*, *24 documents extend beyond this range (24
      reach past both ends)*.
    - `series-production` (1440×900, 20:19), on the empty fake home below: Help ▸ FRUS Research Guide
      ▸ Production & Timeliness, scrolled as build 48's take is, so the scope chip heads both charts.
    - **P3**, `search-zero-result-meaning` (1440×900, 19:22): S1's P2 question, *Why did the wartime
      alliance unravel?*, in Keywords. The MATCH strip, *No Results*, *553 volumes on this device*, and
      *Semantic matches (experimental)* beneath it, from 59% down.
    - **The kit's frame 07**, `cite-popover` (1440×900, 19:11): the Long Telegram ▸ Cite, with the
      Copy as… menu open on Copy BibTeX, Copy RIS and Save as .bib…, as S1's iPad `cite-sheet`.
      Nothing was copied. The popover without its menu is kept outside the repository.
    - **The kit's frame 12**, `search-meaning` (1440×900, 19:22): Meaning, the kit's question, *1–20
      of 100 closest matches*, 66% at the top. It is the question's second run, whose list read as
      the first's.
  - **The empty fake home** for `series-production` and pass A was
    `~/Library/Caches/FRUS-Explorer/s4/home-empty`, made empty, with the preference domain cut to the
    main window's saved frame, so each launch was the copy's first. Onboarding was skipped with nothing
    downloaded (*0 volumes indexed*).
  - **Recording A and the Mac App Preview**, on the owner's word of 19:01, are kept outside the
    repository in `~/Library/Caches/FRUS-Explorer/s4/recordings/` (314 MB), H.264 at 60 frames a
    second. A small ScreenCaptureKit recorder, kept with the sitting's notes, captured the display
    without the Claude app's windows; a `screencapture -v` test showed the app's panel over the copy.
    - **Recording A**, one clip a beat of the kit's §2.3 table, at 3420×1924 (1710×962 points,
      16:9): `A1-chronology` (25 s: 1961–1963 narrowed to 10/14 to 11/20/1962, Show, the day list),
      `A2-search-in-range` (23 s: Search in this range, *quarantine*, 174 results under the range's
      date chip), `A3-meaning` (28 s: Meaning, the chip removed, the kit's question, 100 closest
      matches), `A4-person-network` (27 s: Network, Kennan, Acheson, Explore connections),
      `A5-corpus-analytics` (19 s: *Cuba* added to *Berlin*, the chart turning to % of documents)
      and `A6-briefing-packet` (19 s: the collection under the Briefing packet preset, d474's
      headnote card with its *AI-generated summary · Apple Intelligence (on-device)* line).
    - **The preview's pass B**, the same size: `B1-search` (16 s), `B2-reader` (17 s: the first
      result opened, a yellow highlight made), `B3a-map-whole` (7 s), `B3b-map-transit` (13 s: a
      cluster's *See on the semantic map*, the camera's transit into *edc nato*), `B4-sources`
      (12 s: d41 ▸ Sources) and `B5-packet` (16 s).
    - **Pass A**, cut to the 1200×800-point onboarding window (2400×1600) so that the desktop around
      it is out, each from the window's first frame: `A0-first-launch` (30 s, the copy's first launch
      on the empty home) and `A1-take` (78 s: the splash, Welcome, Get Started, Add Volumes on Entire
      Corpus, A Subseries ▸ *1969-76*, A Single Volume ▸ frus1861, each cloud in turn).
    - A 3420×1924 frame scales to 1920×1080, the Mac App Preview's size, with no crop.
  - **Made in S4's home only, for the recordings:** d474's and d476's summaries (the on-device model,
    the Standard Summary prompt; d475's was refused, *Found by S4*, 5), the collection's Briefing
    packet template, the two saved searches, the two highlights (d475's, and B2's on
    `frus1961-63v10-12mSupp/d341`), and the recordings' searches.
  - **Left:** the copy quit at 20:20, and nothing is running. The shared check copy holds A19's home
    untouched, a clean build at `f7ce0188` and its own preferences. S4's app was unregistered from
    Launch Services and is kept with its homes, the raw frames and the recordings under
    `~/Library/Caches/FRUS-Explorer/s4/` (7.3 GB) until the owner says. The resume note, the patch's
    diff, the preference backup, the hand-off measurement and the 1961–1963 ranking frame are with
    the sitting's notes, outside the repository.
- **S5 — run 2026-10-21, from 20:41; no device, the embed pass.** From `v2` at **`913feb62`** (S4's
  #1754 merged); the branch was already there, so the app's sync merged nothing. Nothing was built,
  booted or launched for a frame: S5 read the files S1 to S4 committed and edited the manuals, this
  ledger, the README and its mirror, `tools/marketing/shots.json`, the composer's drafts, the kit's
  notes and the plan of record. Both manuals keep their *AI Generated* notice (decision 27).
  - **Every capture read against its sentence.** The 74 frames the manuals embed were read at full
    size, each beside its caption and the paragraphs around its slot: S1's 42 `ipad/` frames (its 40
    retakes and P2's two) and S2's two, S3's two `ios/`, and S4's 28 `macos/` (its 26 retakes, P3 and
    the 1961–1963 ranking frame). The kit's ten other files were read too, six at full size and four
    (`ios/document`, `search-facets`, `source-explorer` and `chronology`) in the composer's contact
    sheets. Where a frame and its text disagreed the manual changed, except where a *Found by* list
    sends the sentence to the new plan of record (*Left*, below).
  - **The eleven owed items:** *Done in S5*, under *Caption and sentence fixes S5 already owes*.
  - **Eight sentences and captions more, from the frames:**
    - iOS §3 (step 8) and §7.1 said a result's snippet has *your terms highlighted*. Every row of
      both Search frames bolds one word, the first place a term appears past the heading, source note
      and dateline, which is the one match `SearchService.makeContextSnippet` marks; both now say so.
    - iOS §4.2 said the rail toggle is *accent-tinted while the rail is open*. S1's `research-rail`
      draws it black with the rail open, as the build-47 device frame did, though `DocumentView`
      asks for the accent colour. The clause is gone, and the drawing is *Found by S5*, 1.
    - Both manuals' Chart colors sentences, in §15.1 and §15.7, counted the volumes that get a colour
      before the rest fold into *Other*. The count includes the gray *Other*: Chronology and Corpus
      Analytics keep one volume fewer than it when they fold (`ChronologyViewModel.makeChart`,
      `AnalyticsView`), so at the default 8 the legends of `ipad/chronology`, `macos/chronology` and
      `macos/analytics` name seven volumes and *Other volumes*. The four sentences say so.
    - Mac §14.8's packet caption names Options, and Share and Share as PDF, which the retake shows
      (#1444).
  - **Files.** Deleted, as the verdicts said: `ipad/research-rail-portrait`,
    `ipad/semantic-search-loading` and `ipad/indexing-banner-portrait`. Cropped: `ios/indexing-banner`,
    to its bottom 552 rows (*The four files embedded nowhere*, above). Added:
    `macos/crossref-analytics-ranking.png`, S4's frame from the sitting's notes, byte for byte
    (SHA-256 `05ddffc2…`): build 1861 in the check copy at `f7ce0188`, macOS 27.0.1, 960×900 points,
    taken 19:38. The iOS manual embeds 46 files and the Mac manual 28, where they embedded 42 and 26;
    84 PNGs are on disk. Every image reference in both manuals and the README resolves to a file, no
    `[SCREENSHOT` line is left, and the ten files nothing there names are the kit's —
    `ios/search-results`, `search-facets`, `document`, `semantic-map`, `source-explorer` and
    `chronology`, `ipad/cite-sheet` and `person-analytics-network`, `macos/cite-popover` and
    `search-meaning` — each named by `shots.json`.
  - **The README's hero row:** done, with its mirror and the amendment log's bullet.
  - **The store frames.** `shots.json` names a capture for all 34 frames. Where it had routes it now
    names the six iPhone frames (01 with its facet-sheet take, 02, 03, 04 and 11, the last two with
    the iPad's copy and 04 with its NARA foot), 07 on both platforms, 12 on the Mac and 13 on the
    iPad. Every frame's status reads *build 1861*, where eight read *stale* and the rest fell back to
    *stand-in*. The iPhone map takes `keepFoot`, so its caveat line stays in the pixels, as the kit's
    rule 2 asks. The composer ran under `Scripts/heavy.sh` with Google Chrome headless: the drafts at
    21:18 and again from 21:20:46, then the store sizes to 21:23:58, and the universal set once more
    after the facet take's status was shortened. The 34 frames, 14 at 2752×2064, 14 at 2880×1800 and
    6 at 1320×2868, are in `~/Desktop/store` with four contact sheets (22 MB, outside the
    repository); their half-size drafts are in `Planning/marketing-drafts/`, three of them new, and
    nothing there was edited by hand.
  - **Checks.** The three suites that read the manuals, the README or its mirror —
    `CodingStandardsAuditTests`, `EditableContentKeyTests` and `ResearchGuideCoverageTests` — ran
    named by type through `Scripts/heavy.sh` on iPhone 17 (`80CF0F18`, iOS 27.0), 21:31:47 to
    21:35:44: *Test run with 88 tests in 3 suites passed after 42.210 seconds*, and
    `** TEST SUCCEEDED **` (S0's two suites held 84; the third adds 4). No test reads this ledger,
    the kit, `shots.json` or the drafts. The simulator was booted for the run and shut down after
    it. The plan of record's S5 row changed one figure while the run was under way, so the plan
    audit's logic was re-run in Python over the final files: one live plan, the same struck list.
    The image references, the placeholders and the README's mirror were checked by script.
  - **Left for the new plan of record** (decision 82), each where its sitting listed it: S0's 1, 2,
    3, 6 and 8; S1's 3 and 8 to 19; S2's three; S3's 2 and 3; S4's 1, 2 and 4 to 10; and *Found by
    S5*, below. Three of them are now in a frame the manuals embed: `browse-clusters` shows the
    largest cluster at 37,899 beside iOS §6.1h's 37,865 (S0's 2), Mac §15.4's ranking frame prints *1
    unresolvable references* (S4's 1), and its matrix labels a row *: Southeast Asia* (S4's 2).
- **R1 — run 2026-10-22, 17:10 to 18:26; the retake sitting of the plan of record from 2026-10-21
  (decision 88), started by the coordinating session on the owner's "start r1"; the session
  captured, and drove the Mac on the owner's word of 17:58.** Version 1.0, build **1861**, the
  `AppStore` configuration built for the simulator as S1's to S3's (`-target FRUSExplorer -sdk
  iphonesimulator ARCHS=arm64 -jobs 4`), from `v2` at **`7bbf36cb`** (L1 to L7, #1771 and #1779
  merged), built 17:19:45 to 17:22:53 under `Scripts/heavy.sh` with build 48's local-only banner
  patch, never committed and reverted in the worktree once the build was made. No lane changed the
  index version, so nothing re-indexed. **Every file predates the `build-51` tag (decision 99): a
  screen that a fix after `7bbf36cb` changes is retaken.**
  - **21 files: the brief's 17, and four the lanes' lists missed**, each found by reading the
    committed frames against the lanes' diffs: `ipad/cite-sheet` (the kit's frame 07), whose rail
    is open behind the Cite sheet with its toggle, which L1 tints; and `ipad/semantic-offer`,
    `ipad/semantic-zero-result-matches` and `macos/search-zero-result-meaning`, whose MATCH strip
    printed S1's question as ending `"unravel?"`, which parser 6.8 (L2) prints `"unravel"`. Read and
    left: the chronology frames (no frus1961-63v23 row in either legend), the Meaning frames (no
    MATCH strip), `ios/document` (the rail closed), and the Mac's reader frames (L1's tint is the
    iPad `DocumentView`'s). Each retake was diffed by pixel against the frame it replaces: it
    differs where its lane said, in the status bar, and where its line below says.
  - **The iPad under iOS 27.0, S1's `3D2607D9`**: the build installed (the data container moved on
    install), S1's container snapshot `snapshot-A` restored into it, the device rebooted and turned to
    landscape on its home screen by S2's rotator (`testLandscapeHome`); the demo status bar; Windowed
    Apps; every launch with `-hasCompletedOnboarding 1 -FRUSScreenshotHideSyncBanner YES`.
    - `research-rail` (17:25): the rail toggle's ink is the accent blue, (0, 135, 254) over 676
      pixels, where S1's frame drew it black; the note's age reads *1 day, 3 hr*.
    - `cite-sheet` (17:25): the toggle behind the dimmed sheet reads grey 150 where S1's read 73, and
      the note's age as in `research-rail`; the Copy as… menu open on Copy BibTeX and Copy RIS, as
      S1's. Nothing was copied.
    - `browse-administrations` (17:26): George H. W. Bush's row reads *1 vol*.
    - `browse-administrations-truman` (17:27): *most documents first*, the rows 1,698, 1,463, 1,242,
      1,164, 1,135, 1,111 and 1,103 docs, frus1949v06 above frus1947v07.
    - `browse-clusters-detail` (17:28): *10,914 of 10,914 documents indexed on this device*.
    - `search-results` (17:28): *Berlin blockade*, every row marking *Blockaded* or *Blockade*.
    - `semantic-offer` (17:30): the model removed first through Settings ▸ Volumes & Storage ▸
      Remove Search Model; the strip ends `"unravel"`.
    - `semantic-zero-result-matches` (17:32): S1's `snapshot-B-removed` restored (the three volumes
      removed, the model present); Download Volume on S1's three rows, and only the `?` (138 pixels)
      differs from S1's frame. Then `snapshot-A` was put back, and the device shut down at 17:32.
  - **The iPad under iOS 26.5, `5ED7E25B`**: `stage-manager` (18:25), in Stage Manager, then Windowed
    Apps again; backboardd lived throughout, as it did for S1. The build was installed over S1's
    container, whose preferences carry the two flags. S1's composition, the Related window in front,
    was taken first (17:41) and set aside: the document window behind it draws its toolbar inactive,
    so its toggle is grey and L1's tint does not show. The retake puts the document window in front,
    its toggle's ink (42, 155, 255), the Related window beside it with its list scrolled as S1's, so
    iOS 26.5's *Shared words compared as printed* line (#1608, S1's finding 19) is out of view, and
    the main window behind on Browse ▸ Subseries. The document window sits at the screen's left
    edge, where S1's sat 29 points in.
  - **The iPad erased, S2's `A913C7F8`**: `onboarding-volumes` (17:44), the app uninstalled and
    installed so the launch was its first, with `-FRUSScreenshotHideSyncBanner YES` alone; Get
    Started ▸ Add Volumes, Corpus, the Concepts view; frame 5 of a 24-frame burst, the nearest to
    S2's composition. *objective* sits above *power*, and *conflict* and *hostility* are apart at the
    left edge, as L5's measurement placed them. The app was quit on that step; nothing downloaded.
  - **The iPhones, S3's two**, each with `snapshot-A`'s `Library` cloned in as S3 did (without
    `SplashBoard` and `Saved Application State`), the build installed and the device rebooted:
    `ios/search-results` (17:48) and `ios/search-facets` (17:49) on the 17 Pro Max `7449CA80`, and
    `ios/search-tips` (17:50) on the 17 Pro `3025E8FF`. Each differs from S3's frame only in its
    snippet lines, which now mark *blockade*.
  - **The time and date erased**, by S1's script and S3's iPhone script unchanged (SHA-256
    `58d052de…` and `1a8a3122…`): every changed pixel lies inside the box, alpha untouched. In
    `stage-manager` the box sits on the wallpaper, whose grain the script measured at 0.45, under the
    0.5 at which it adds grain, so the fill carries none: at eight times the contrast the box reads as
    a smoother patch, and at the frame's own contrast it does not show. In the Windowed Apps frames
    *FRUS Explorer* starts at column 345, where S1's started at 349, since the erased *Thu Oct 22*
    was narrower than *Wed Oct 21*.
  - **The Mac, in the check copy**: `setup.sh --ref HEAD --prefix frus1961-63v09` at `7bbf36cb` into
    the shared scratch, then `build.sh --no-launch` under the lock, 17:53:19 to 17:56:29, `** BUILD
    SUCCEEDED **` with the copy's nine expected warning lines. No chip patch: none of the eight frames
    shows the main window's status bar. The product was copied to R1's folder, launched from there
    with `open -n --env CFFIXED_USER_HOME=…`, and unregistered from Launch Services afterwards. **The
    fake home** is R1's own, an APFS clone of S4's (S4's demo data and its three saved searches); the
    copy opened it without re-indexing (553 volume structures, 321,749 rows). **The preferences**: the
    domain's 111 keys exported, the iPad's 15 set for the sitting, and the 111 put back afterwards
    with `prefs-restore.swift`, which read them back identical. Computer use drove the copy under
    full-screen control, its bundle id alone; each window was taken with `screencapture -o -x -l
    <window id>` at S4's size, and where a field held the caret, from a burst by S4's `caretfree.py`.
    - `search`, `search-tips` and `saved-searches` (18:00): *Berlin blockade*, every row marking the
      blockade word, in the list and behind the saved-searches sheet, whose list sits 4 points lower
      than S4's.
    - `search-zero-result-meaning` (18:01): only the `?` (123 pixels) differs from S4's frame.
    - `analytics` and `analytics-table` (18:02): *View 9,114 documents ↗ · Spread across 267 of 553
      indexed volumes* over the chart's *9,192 documents matched*, the difference Mac §15.1 explains;
      only that line differs from S4's frames.
    - `crossref-analytics-ranking` (18:03): *1 unresolvable reference is excluded from this analysis
      — a cross-reference in the printed volumes that points to a document, page, or volume not
      present in the corpus.*; only that line differs.
    - `crossref-analytics` (18:05): *Southeast Asia · 1961-63 v23*. A wheel step scrolled 20 pixels,
      so the scroll bar's value was set through accessibility to S4's offset: the frame differs from
      S4's in the colon's 19 pixels alone.
  - **The store frames**: `SCALE=1 STAMP=0 OUT_DIR=~/Desktop/store python3
    tools/marketing/compose.py` under the lock, 18:05:53 to 18:08:21. **The 34 frames for App Store
    Connect are in `~/Desktop/store`**, 14 at 2752×2064, 14 at 2880×1800 and 6 at 1320×2868, with
    four contact sheets, and none is stamped (checked by script over each frame's top margin). S5's
    set, which they replace, is kept at `~/Library/Caches/FRUS-Explorer/r1/store-S5-2026-10-21/`.
    The drafts, by the default run, to 18:09:24: ten files in `Planning/marketing-drafts/` changed,
    frame 01 on all four presets, 02 and 07 on the iPad, 10 on the Mac and three contact sheets, each
    the size it was; the other 28 rendered byte for byte as committed. Frames 01, 02, 07 and 10
    (Mac) recompose from new captures; frame 10 carries L7's sublines in the store set for the first
    time. Each was read against its headline and subline in `shots.json`, the changed frames at full
    size and the rest in the contact sheets.
  - **The manuals**: every retake read against its caption and the sentences around its slot. None
    changes a sentence or a caption, so neither manual changed; both keep the *AI Generated* notice
    (decision 94).
  - **Recordings A, R and T and the App Previews were not taken again** (decision 89). What the
    lanes changed for them: pass B's search beat, *Berlin blockade*, now marks *blockade* (L2), and R's
    first, `"long telegram"`, may open its snippets on another word, as 4,487 of the 7,962 phrase rows
    L2 measured did; T7's link reads 2,833 where its take read 2,803 (L3); pass A's first seconds now
    show the splash from the first frame and no empty backdrop at the hand-off, on the iPad and the
    Mac (L5).
  - **Left**: every simulator shut down, the rotator's runner uninstalled from each iPad. `3D2607D9`
    holds `snapshot-A` again, so the R and T recordings' edits S1 left in it are gone from the
    device; the iPhones hold `snapshot-A`'s library, so S3's highlight on d475 is gone from the Pro
    Max; both are in the containers R1 cloned before it changed anything. `5ED7E25B` keeps its Stage
    Manager windows in its scene state; `A913C7F8` holds the app on its Add Volumes step. The shared
    check copy is extracted and built at `7bbf36cb`, its home untouched, its preferences as they
    were. R1's builds, raw and erased frames, bursts, the Mac's app and home, the preference exports,
    the pre-R1 container clones and S5's store set are under `~/Library/Caches/FRUS-Explorer/r1/`
    (about 4 GB on the disk, most of it APFS clones) until the owner says.

### Found by R1 — for the owner

Seen in the sitting; not fixed and not filed. They go to the plan of record's §5 (decision 82's
rule).

1. **Under iOS 26.5 in Stage Manager, a document popped out with Open in New Window draws its rail's
   area black until the window is moved.** Both times the Long Telegram was popped out on
   `5ED7E25B`, the new window drew its text and left the Research rail's column black; moving the
   window by its top bar drew the rail. Seen twice, not measured; whether iOS 27 or a device does
   it is not established. *The app or the simulator.*

### Found by S1 — for the new plan of record

Seen or measured in the sitting, where S0's were read; decision 82 sends S0's to the new plan, and
these go with them, for the owner to place. *S5* marks a sentence or caption the embed pass reads
against S1's frames. *After S5 (2026-10-21):* 1, 2, 5, 6 and 7 are done and 4 was read and left
(*Caption and sentence fixes*, *Done in S5*, item 9); 3 and 8 to 19 wait for the new plan. *After L1
(2026-10-21):* 3, 8 and 10 are done (#1762, #1761); 10 changes `ipad/browse-clusters-detail`, for R1.
*After L3 (2026-10-22):* 9 and 13 are done (#1756), for R1. 9 changes
`ipad/browse-administrations-truman`. 13 changes `macos/analytics` and `macos/analytics-table`, whose
link and spread line read *View 9,192 documents ↗ · Spread across 502 of 553 indexed volumes* for
*Berlin* over 1944–1975 (on S1's index they would read 9,114 and 267 of 553), and the kit's recording
T7, whose link read 2,803 (17). *After L7 (2026-10-22):* 16 and 17 are done (#1763): the kit's recording T
gives the routes T5 to T7 took (**Export…** ▸ the PDF card ▸ **Export PDF** and the title page; Research ▸
**FRUS Research Guide** and the year chip's popover; the **Administration** preset and **View N
documents ↗**), with a note under its table. A retake of T7 reads 2,833 on the link (L3). *After R1
(2026-10-22):* the frames 9, 10 and 13 changed are retaken (`ipad/browse-administrations-truman`,
`ipad/browse-clusters-detail`, `macos/analytics` and `analytics-table`); recording T is not (decision 89).

**The manuals against the screen.**

1. iOS §6.1g: *only about 28%* of sourced documents name a collection; both Archives banners now
   say **about 29%** (`ArchivesAxis.collectionSharePercent`: 76,140 of 264,598 notes in
   `collection-usage-index.json`, 28.8%). The build-48 banner said 28%. *S5.*
2. iOS §6.1h: a cluster's documents are grouped by volume *in coverage order*; the drill orders
   volumes by identifier (`ClustersBrowseView`: *in volume order*), so `frus1917-72PubDipv06`
   (1960–1963) heads `edc · nato · nuclear · soviet` above its 36 documents from 1900–1944 volumes.
   *S5, or the order.*
3. iOS §6.1h's largest cluster reads **37,899** on screen: S0's finding 2, seen.
4. iOS §6.2a says the Topic index lists every detected topic; its header reads *491 assigned topics
   … drawn from experimental enrichment data*, the owner's EditableContent wording of 2026-10-01
   and deliberate. *S5 may align the sentence.*
5. iOS §7.12's example question, *Why did the Marshall Plan happen?*, returns **351** keyword
   results on a full library, so it cannot show the zero-result offer it illustrates. P2 used *Why
   did the wartime alliance unravel?*: no result, each term matching on its own (checked by FTS5
   MATCH on the device's index first). *S5.*
6. iOS §7.12: an undownloaded semantic match *shows the volume's title*; its row reads *Document
   d32 in Papers Relating to …*, the bare document id before the volume's title. *S5's read.*
7. iOS §15.7 names two directions for *Extends beyond this range* (begins before, ends after); the
   chip also counts documents that *reach past both ends*, 24 of autumn 1962's 25. *S5.*
8. `ChronologyQueryTests`' doc comments describe `ipad/chronology.png` as reading *26 documents
   extend beyond this range (26 before · 24 after)*, the build-47 take; the retake reads *25 … (1
   begins before · 24 reach past both ends)*. The fixtures still hold; the comments now describe a
   file that does not show them.

**The app.**

9. **The Administrations drill reads out of order by its own counts.** `AdministrationAxis.spec`
   keeps the bundled order (point documents, descending) and prints point plus range documents on
   each row: Truman's third and fourth rows read 1,164 then 1,242 (frus1947v07 1,159 + 5;
   frus1949v06 1,135 + 107), and an 85% row sits above a 100% one. Over the bundled
   `administration-profiles-index.json`, 168 of 854 adjacent pairs read out of order by the shown
   count, in 16 administrations; the caption says *largest share first*.
10. **A coverage line prints its counts ungrouped**: *10914 of 10914 documents indexed on this
    device* under a cluster whose row reads 10,914 (`WorkingCorpusCoverage.coverageDescription`
    formats with `%lld`), where §6.1f's example reads *1,873 of 2,340*. Build 47's frame had *3220
    of 3220*, so not new.
11. **A working corpus saved from a narrowed search records only the query.** Saved from `"long
    telegram"` narrowed by Facets to 1945 (5 documents), the sheet and the corpus read *From "long
    telegram"* (`SaveWorkingCorpusSheet` passes `sourceQuery: queryText` alone), so the corpus does
    not say how its documents were chosen; the kit's R caption calls it a denominator you can cite.
12. **Clearing the query leaves Facets on the old match.** After the field's ✕ the iPad panel reads
    *Describing this result set — total unavailable* over the old People list, with the *Narrowed
    by 1945* chip still up; removing the chip then shows *Search Error — Enter a keyword, phrase, or
    prefix to search.* Nothing in the binoculars menu closes the panel once it is open
    (`showFacetSheet = true`); a Keywords ⇄ Meaning switch does. Seen, not measured.
13. **Corpus Analytics' link and the search it opens disagree.** *Berlin*, Eisenhower's years
    (1953–1961): *View 2,803 documents ↗* opens a Search reading **2,833**, whose Years facet lists
    matches dated 1945, 1948, 1951 and 1952. Counted on the device's index: 16,273 documents match
    (the chart's line read 16,271); 2,775 start in 1953–1961; 2,833 have a date span overlapping it,
    Search's rule exactly; no rule tried gives 2,803. *Spread across 502 of 553 indexed volumes*
    did not change when the range narrowed.
14. **The graph at three hops** (`frus1952-54v02p1/d16`, Network): about 70 nodes since A17 and
    A18b; the four most-connected archival nodes sit pinned at the canvas's corners with every edge
    running to them, only the focus keeps its label, and the reference list's first *Cited By This
    Document* row is a page node, `frus1948v01p2/pg_507`. Seen, not measured.
15. **A question typed in Keywords mode highlights only *the*** in every snippet (A10b's window
    starts at the first match of any term), and the MATCH strip quotes trailing punctuation
    (`"happen?"`) that the tokenizer drops. Seen.

**The kit's recordings.**

16. T's 58–70 s beat: *Settings ▸ About ▸ Research Guide ▸ Production & Timeliness; drag the year
    range*. The Guide is reached from Research ▸ FRUS Research Guide (the manual's route), and the
    dashboard's range is a chip whose popover holds two year fields with steppers, so there is
    nothing to drag; T6 sets the start to 1945. And the 46–58 s beat's *title and introduction*: the
    collection has no introduction, so T5's first page shows the title, its note and the contents.
17. T's 70–80 s beat: *tap a bar ▸ the documents behind it*. A time chart has no bar tap (a drag
    across it narrows the range, #306; only By Subseries and By Volume bars drill, §15.1). T7 takes
    the app's route: the Administration preset, then *View N documents ↗*, with finding 13's counts.

**The simulators.**

18. **#1620's trigger on this Mac's iOS 27.0 runtime is Stage Manager** (measured above): every
    Analysis Tools window lived on a new 27.0 device, and the switch to Stage Manager killed it. S0's
    split was not needed for the seven; decision 72's re-test can start from the switch.
19. **The iOS 26.5 runtime here has no English lemmatiser, tagger or name tagger.** On the new 26.5
    device the app's verdict listed only Language, Script and TokenType, and its canary found no
    lemmas, classes or names. A scratch tool run inside the runtime asked
    `NLTagger.requestAssets(for: .english, tagScheme:)` for all three: none answered within 180 s,
    and every word tagged nil and `OtherWord`. The twin `9F3D84A4`, which holds the English
    LinguisticData asset (142 MB), gave the same result, and the asset cloned into the new device
    changed nothing. So **every #1608 surface reads Limited in a 26.5 capture**: S0's plan would
    have put the *Counted as printed* line in `word-cloud`, and in `stage-manager` the Related
    window's *Shared words compared as printed* line is scrolled just out of view (the frame with
    it showing is kept with the sitting's notes). A sitting under 26.5 reads the launch's verdict
    first.

### Found by S2 — for the new plan of record

Measured in pass A's two clips, frame by frame (every frame simctl wrote, scaled down and measured
for ink outside the identity block and the Welcome dock; the scripts are kept with the sitting's
notes), or seen in the frames. They go with S0's and S1's for the owner to place (decision 82).
*After L5 (2026-10-22):* 1 to 3 are fixed, in one branch for #1759. Measured again the same way
(S2's scripts unchanged, and one more that reads every frame on the same regions) on a new iPad Pro
13-inch (M5) under iOS 27.0, landscape, erased for each build. With build 1861's code the first
launch drew the dock in 14 frames under the fading launch screen (4.652 to 4.842 s), and the three
launches after it stood on an empty backdrop for 1.212, 1.048 and 0.437 s before the cloud appeared
in one frame (the first launch's lens change fell before the splash left, so it showed none). With
the fix no frame draws the dock before the splash, none of four launches shows an empty backdrop,
and the ink stays between 1.41 and 2.31% across the hand-off. The kit's 0–4 s beat now shows the
launch screen, the splash with its seeded Concepts cloud fading in, and that cloud carrying on under
the Welcome dock on the same lens, with no empty frame to cut before. In the Concepts layout of
`onboarding-volumes`, reproduced at S2's instant, *objective* and *power*, and *conflict* and
*hostility*, are apart, and no two words meet at any instant on any bundled layout of the splash
or onboarding. R1 retook `ipad/onboarding-volumes` on 2026-10-22 (the sittings' ledger).

1. **The splash empties before onboarding's cloud arrives.** The fresh-install splash shows its
   Concepts cloud and fades out, and the identity block and the Welcome dock then stand over an
   empty backdrop for **0.46 s on the first launch and 0.79 s on the second** (A0 7.18–7.64 s, A1
   13.75–14.53 s). Onboarding's own cloud then appears in one frame rather than fading in, in or
   crossing into the Topics view, and on the second launch it is back in the splash's own Concepts
   layout about a second later. `LaunchSplashView`'s doc says the fresh-install splash "holds
   briefly and flows into onboarding's own cloud", and `ContentViewWithSplash.resolveSplash()` says
   the same. The kit's 0–4 s beat, *the seeded splash cloud resolves to the wordmark*, is the first
   half of that sequence: the cut has to end before the empty half-second, or the hand-off is the
   app's to change. *The kit, or the app.*
2. **On the first launch after install, the Welcome dock shows before the splash.** In A0 the
   dock, with its title, its text and Get Started, is drawn under the fading launch screen from
   5.44 s to 5.69 s and is then covered by the splash, which `resolveSplash()` raises once from a
   `.task`, after the first frame. On the second launch only a trace shows, in a frame or two. So
   a new reader's first sight after the launch screen is the dock, then the splash, then the dock
   again. *The app.*
3. **Two pairs of words overlap in the Concepts layout that `onboarding-volumes` shows**:
   *objective* is drawn under *power*, and two vertical words collide at the screen's left edge.
   Build 48's take of the same seeded layout has both. Seen, not measured. *The app, cosmetic.*

### Found by S3 — for the new plan of record

Seen or measured in the sitting, or read in the files beside it. They go with S0's, S1's and S2's
for the owner to place (decision 82). *After S5 (2026-10-21):* 1 is done (`shots.json` names the
d475 frame, and the recipe says d475); 2 and 3 wait for the new plan. *After L4 (2026-10-22):* 2 and 3
are fixed, in one branch for #1757. Measured again on an iPhone 17 simulator under iOS 27.0 holding
S1's library, by S3's method (a subseries' files moved out, then Download from GitHub ▸ Subseries, in
bursts of `simctl io` frames): on build 1861's code 1961-63's 27 opened at *Volume 1 of 20*, *1 of
25* or *1 of 28* and read *20 of 20* with seven to come, and 1951's 11 at *1 of 12*; with the fix the
27 read *of 27* in every frame and the 11 *of 11*. On build 1861's code the Guide opened in both first
queues measured and closed by itself as each queue ended, since it hung on the banner the queue's end
removes; with the fix it stays open until it is closed. What removed it in S3's run 1 is not
established. No committed frame changes: `ios/indexing-banner` is an 11-volume queue, whose count
was right before and after.

1. **The kit's iPhone reader frame and the demo recipe name the Long Telegram `frus1946v06/d474`;
   the Long Telegram is `d475`.** d474 is Kennan's telegram of February 12, 1946, 3 p.m.; d475 is
   that of February 22, 9 p.m. Both `tools/marketing/shots.json`'s iPhone `reader` route and point 4
   of *The demo data* say d474. S1's note on the Long Telegram sits on d475 (read in `snapshot-A`'s
   store), and so do the code's references to it (`ReaderPage.swift`, `ReadingWidth.swift`,
   `ReadingWidthTests`). S3 took d475. *Why it matters:* the route is what a later sitting follows,
   and it leads to another document. *The kit and the recipe; nothing in the app.*
2. **The banner's *Volume N of M* counts only volumes already on the device, so a large download
   reads short.** Each of three 27-volume queues showed a short count at the first frame seen. Run 2
   opened at *Volume 1 of 15*. Run 4's first banner frame read *Volume 3 of 5*, and run 1's only
   screenshot read *Volume 4 of 6*. Each count grew as files landed: *4 of 6*, *7 of 7*, *9 of 10*
   … *27 of 27*. In run 2's 26th frame the chevron listed six waiting titles (volumes XVIII to
   XXIII) under *Volume 15 of 15*. Run 2's *N downloads queued* banner counted 2, 8 and 14 before
   the first volume began indexing, so the queue started while the download sheet was still
   enqueuing. Queues of 10 and 11 volumes read their full size from their first frame. Read in the
   code, not traced: `IndexingBatch`'s total is the app's download queue plus one when the first
   volume starts indexing (`AppState`, `IndexingBatch(total:`). Afterwards only
   `unindexedDownloadedVolumeIds()` raises it, and that counts volumes on disk. iOS §4.8 says *your
   position in the queue — Volume 3 of 27*. *Why it matters:* the denominator is how the banner
   tells a reader how long the wait is. A subseries download that reaches *N of N* several times
   reads as finished when it is not. *The app.*
3. **The FRUS Research Guide did not open by itself in the launch's first queue.** iOS §4.8 says
   *The first time in a session that a queue of two or more volumes starts indexing, the FRUS
   Research Guide opens by itself as a sheet*. `IndexingQueueBannerView` asks for it 0.6 s after the
   queue banner first appears. In this launch's first queue (run 1, 17:48), the screenshot with
   *Volume 4 of 6* on screen shows Volumes & Storage and no sheet. The flag that keeps it from opening
   twice is set at that first appearance, so no later queue could show it. Seen once, not measured.
   *The app, or the sentence.*

### Found by S4 — for the new plan of record

Seen or measured in the check copy, or read in the code beside it. They go with S0's to S3's for
the owner to place (decision 82). *After S5 (2026-10-21):* 3 is done (Mac §15.4's second figure);
1, 2 and 4 to 10 wait for the new plan. *After L1 (2026-10-21):* 1, 2, 7 and 10 are done (#1761,
#1762); 1 and 2 change `macos/crossref-analytics-ranking` and `macos/crossref-analytics`, for
R1. *After L5 (2026-10-22):* 8 is fixed (#1759). Measured again in two check copies, `v2` before
and the fix after, each on an empty fake home of its own, the window recorded at 60 frames a second
and read by S4's script: before, the dock alone in the window's first seven frames (0.117 s) and an
empty backdrop for 1.100 s at the hand-off; after, the window's first frame is the splash, and the
cloud runs unbroken through the hand-off. The splash's Concepts cloud no longer overprints words.
*After L7 (2026-10-22):* 9 is done (#1763): `tools/mac-check-copy/README.md` gives both notes, with
S4's two helpers beside `axread.swift` (`prefs-restore.swift`, `apprec.swift`), and the kit's §4 names
the ScreenCaptureKit recording where it named QuickTime. *After R1 (2026-10-22):* the two frames 1 and 2
changed are retaken (the sittings' ledger).

1. **One unresolvable reference reads as a plural.** Cross-Reference Analytics over 1961–1963 says
   *1 unresolvable references are excluded from this analysis*: `crossRefAnalytics.excludedBrokenCaption`
   in `CrossReferenceAnalyticsView.swift` has no singular. *The app, cosmetic.*
2. **frus1961-63v23's label begins with a colon**: *: Southeast Asia · 1961-63 v23*, a row of the
   heat matrix in `crossref-analytics`. Its title prints a colon after the volume number (*Volume
   XXIII: Southeast Asia*), and `ChronologyViewModel.volumeTopic(from:)` removes the number and then
   trims spaces, commas, full stops and semicolons, not a colon. A Python mirror of the rule, run over
   the bundled manifest, finds no other volume whose topic starts with punctuation. Every surface that
   distils a volume's title draws the same topic. *The app.*
3. **Mac §15.4's rankings carry their titles now** (S0's row 64). Over 1961–1963, Most-Referenced
   Documents opens on *281. Telegram From the Department of State to the Embassy in Vietnam* (21).
   Over the whole corpus it opens on No. 1383, *Protocol of the Proceedings of the Berlin Conference*
   (219), as on S1's iPad. #1372's fallback labels are gone, so the caption can widen beyond the heat
   matrix (S5's item 5). The ranking's frame is kept with the sitting's notes. *S5.*
4. **A new search keeps the old list's scroll position.** The pass-B take of *Berlin blockade* opened
   on its sixth row, *139. Memorandum From the Acting Chairman …*, because the results list had been
   scrolled before. Two searches had been run in between, without a scroll. Seen once, not measured.
   *The app.*
5. **The on-device model refused the Long Telegram.** Summarize this Document on d475, with the
   Standard Summary prompt, ended in *The model's safety guardrails were triggered*; d474 and d476
   summarized in under 20 seconds each. So the series' best-known document cannot carry an AI headnote,
   which recording A's last beat would have shown; the clip uses d474's. Seen once. *The model, or the
   prompt.*
6. **The collection's live preview missed a new summary.** After d474's summary was made in the
   reader, the Collections window's preview still read *No stored summary for this document — generate
   one in the document view to fill this headnote*, while the inspector beside it listed the summary.
   Closing and reopening the window drew the headnote. Seen once. *The app.*
7. **Search's date chip has a small ✕.** *Clear Date filter* measures 8×8 points by accessibility,
   and a click 2 points outside that frame did nothing. Its help text reads *Edit this filter in
   Advanced filters*, which is the chip's own. *The app, cosmetic.*
8. **The Mac's first launch shows S2's hand-off, shorter.** Every frame of the two pass-A clips was
   measured at 60 frames a second for ink outside the identity block and for the dock's Get Started
   button. The script is kept with the sitting's notes.
   - In `A0-first-launch` the Welcome dock is drawn in the window's first two frames (33 ms) before
     the splash covers it. The splash's cloud shows from 0.28 s to 1.75 s. The dock then stands over
     an empty backdrop for 0.18 s before onboarding's cloud arrives, at 1.95 s.
   - In `A1-take` no frame shows the dock before the splash, and the splash's cloud crosses into
     onboarding's at 1.70 s with no empty frame.
   - On the iPad, S2 measured 0.46 s and 0.79 s empty, and a quarter of a second of dock. *The app;
     the Mac's figures for S2's findings 1 and 2.*
9. **For `tools/mac-check-copy/README.md`, not the app.**
   - Putting back the copy's 96 preference keys with `defaults import` reported success and changed
     nothing, twice, though the 15-key import at the start of the sitting had taken. CFPreferences,
     key by key, put them back.
   - A screen recording made while computer use drives the copy picks up the Claude app's windows:
     a `screencapture -v` test showed its panel over the copy. A ScreenCaptureKit recording that
     leaves the Claude app out does not. The kit's §4 names QuickTime's screen recording, which
     records the whole screen in the same way.
10. **`ChronologyQueryTests`' `macCapture` comment quotes the build-48 frame.** It says
    `macos/chronology.png` reads *24 documents extend beyond this range (24 before · 24 after)*. The
    retake, over the same October 14 to November 20, 1962, reads *(24 reach past both ends)*, which is
    the fixture's own breakdown. The fixtures hold, and the comment now quotes a file that no longer
    shows those words. *The tests' comments, as with S1's finding 8.*

### Found by S5 — for the new plan of record

Seen in the frames S1 to S4 took, and read in the code beside them; nothing was run. They go with
S0's to S4's for the owner to place (decision 82). *After L1 (2026-10-21):* 1 and 3 are done (#1761);
they change `ipad/research-rail`, `ipad/stage-manager` and `ipad/browse-administrations`, for R1.
*After L3 (2026-10-22):* 2 is done (#1756): the setting and both charts' menus say *Colors per chart*,
and no frame shows them. *After L7 (2026-10-22):* 4 and 5 are done (#1763). The composer draws its stamp
over the frame's top margin, so the foot keeps its width (on the iPhone, frame 01's disclaimer and frame
04's NARA sentence take two lines each), and `STAMP=0` leaves the stamp out for App Store Connect. Frame
10's sublines say *narrow the years to the spike and open its documents in Search*, and both manuals'
§18.6 no longer say *tap into* or *click into* either. *After R1 (2026-10-22):* the three frames 1 and 3
changed are retaken, with `ipad/cite-sheet`, whose toggle 1 changes too, and the store frames are
composed again with `STAMP=0` (the sittings' ledger).

1. **The iPad's Research-rail toggle is not drawn in the accent colour while the rail is open.**
   `DocumentView` asks for it (`railToggleActive ? Color.accentColor : Color.primary`), and S1's
   `research-rail` (iOS 27.0, the rail open) and the build-47 device frame both draw the glyph
   black. iOS §4.2 said it was tinted; S5 removed the clause. *The app.*
2. **The Chart Colors setting counts the gray *Other* as one of its colours, and says it counts
   volumes.** The row reads *Distinctly-colored volumes: 8* (`settings.display.chartColors.value
   %lld`) and its footer *How many volumes appear as distinct colors in the Chronology and Corpus
   Analytics charts before the rest fold into a single "Other" series*, but both charts keep one
   volume fewer than the count when they fold, so the default names seven volumes beside *Other
   volumes*. The manuals now describe what the charts draw. *The app's wording.*
3. **The Administrations index prints *1 vols*** on George H. W. Bush's row (`AdministrationIndexView`,
   `"\(profile.volumeCount) vols"`, no singular). *The app, cosmetic.*
4. **On the iPhone preset the composer's stamp squeezes the disclaimer.** The stamp, *DRAFT · id ·
   status · the capture's path*, never wraps, so on a 1320-pixel frame that has a capture the foot
   beside it is a column a few words wide: the not-an-official-product sentence takes five lines on
   frame 01, and the NARA sentence nine on frame 04. The iPad and Mac frames are wide enough. *The
   kit's composer.*
5. **The kit's frame 10 sublines say *tap into* (iPad) and *click into the documents behind the
   spike* (Mac),** the gesture S1's finding 17 found a time chart does not have: the way to the
   documents is the *View N documents ↗* link, after narrowing the years by the chip, the
   Administration preset or a drag across the chart. *The kit's copy.*

## Staging notes (superseded triage — see #1081 for the tick-list)

Keyed to the **post-rewrite** section numbers. Legend as elsewhere: 🆕 new shot · 🔄 re-capture
(existing file shows retired UI). Two rules keep the wiring cheap:

- **🔄 items keep their existing filename** — the manuals reference the path, so a same-name
  re-capture updates them with zero edits.
- **🆕 items use the filenames below** (or note what you used instead, and the manual references
  get adjusted to match when the shots are wired in).

### Staging notes — holes in the shipped manuals (placeholders and stale-flagged embeds)

| Shot | For | What it must show |
|------|-----|-------------------|
| 🆕 `ipad/research-rail.png` | iOS §4.2 placeholder | Document open on iPad (landscape) with the Research rail as the trailing inspector: RESEARCH header, the three-column grid of seven tiles (Cite · Word Cloud · Sources · Graph · Related · On the Map · Share), and the Topics/Summary/Notes/Tags/Collections accordions beside the text. Pick a document with detected topics — the Topics accordion is hidden on documents that have none |
| 🆕 `ipad/stage-manager.png` | iOS §4.5 placeholder | Stage Manager: a document window beside a Related Documents (or Archival Neighbors) window, main window behind |
| 🔄 `macos/toolbar.png` | macOS §4.1 | The current trailing five: Search, Browse, **Analytics ▾**, **My Research ▾**, Research-rail toggle, with the centered `volumeId/documentId` title. (The older note below about separate Person/Cross-Reference Analytics *buttons* predates the menu consolidation — they now live inside Analytics ▾) |
| 🔄 `macos/research-strip.png` | macOS §4.2 | The Research rail beside a document — tile grid + accordions (filename kept for continuity) |
| 🔄 `macos/document.png` | macOS §4.3 | The reading view under the current toolbar (rail closed is fine) |

### Staging notes — iPad upgrades for the four iPhone stand-ins

The iOS manual is iPad-first; these four slots currently embed `ios/` captures with an
"(iPhone capture)" caption. Same content, iPad framing; the references get swapped once the
files land.

| Shot | For | Replaces |
|------|-----|----------|
| 🆕 `ipad/people-list.png` | iOS §6.5 | `ios/people-list.png` |
| 🆕 `ipad/people-detail.png` | iOS §6.5 | `ios/people-detail.png` |
| 🆕 `ipad/analytics.png` | iOS §15.1 | `ios/analytics.png` — ideally with **% of documents** on and the inline toolbar **Export** menu visible (the iPad placement is itself documented) |
| 🆕 `ipad/chronology.png` | iOS §15.7 | `ios/chronology.png` |

### Staging notes — new slots the manuals will embed as they land

No image exists on that platform today; each gets wired in on arrival.

- 🆕 `ipad/collections-editor.png` — iOS §12.1: the two-column manager (Contents outline + live
  preview), ideally with a section heading and a prose or excerpt row visible. The
  teaching-reader centerpiece — the highest-value Tier-3 shot.
- 🔄 `macos/collections.png` — macOS §12.1: the current Collections window (toolbar collection
  picker, outline + preview, ⚙ Collection / inspector controls). The committed file shows the
  retired UI, which is why the rewrite doesn't embed it; a fresh capture gets wired in.
- 🆕 `ipad/source-explorer.png` — iOS §14 (macOS already has one).
- 🆕 `ipad/cross-reference-graph.png` — iOS §8.6.
- 🆕 `ipad/related-documents.png` — iOS §8.5: scope control + Adjust weights + why-related chips.
- 🆕 `ipad/crossref-analytics.png` and `macos/crossref-analytics.png` — §15.4 on each (no capture
  of the analytics window exists on either platform).
- 🆕 `ipad/archival-analytics.png` and `macos/archival-analytics.png` — §15.5, Collections mode:
  an era ranking with the Central Files umbrella chip visible.
- 🆕 `ipad/semantic-map.png` and `macos/semantic-map.png` — §15.6, Regions coloring with labels
  and the caveat line beneath the map.
- 🆕 `ipad/word-cloud.png` and `macos/word-cloud.png` — §15.2, ideally in **Distinctive** mode
  with the eligibility line under the control visible.
- 🆕 `ipad/series-production.png` — iOS §16.1, offline per the Series-Analytics empty-corpus
  convention below (macOS already embedded).
- 🆕 `ipad/onboarding-volumes.png` — iOS §2.3, the Add Volumes step over the word-cloud backdrop
  (needs a fresh install, per the historical notes below).

### Housekeeping from the rewrite

- `ios/browse-corpus.png`, `ios/search-results.png`, `ios/settings.png` and `ipad/browse.png` are
  embedded by nothing and are **slated for deletion**, not refresh (#1081 §7).
  `ios/document-view.png` is no longer in either manual but is still the repo `README.md`'s third
  hero image — #1081 §6 leaves it as an open choice: re-shoot it for the README, or swap that slot
  for a current shot (the semantic map or the Browse root) and delete the file.
- The four `ios/` files still embedded are exactly the Tier-2 stand-ins above.
- Known-hard items are unchanged and stay out of the tiers: the macOS Chronology **hover
  magnifier** (capture problem documented below) and the **Live Activity / Dynamic Island**
  (needs a physical iPhone with an active download).

## Capture conventions

- **iOS / iPadOS** — captured from the iPhone 17 and iPad Pro simulators (13-inch since the build-48
  sweep) running the app against the full corpus, via `xcrun simctl io <device> screenshot` (clean
  device-screen PNGs). Three things changed with **Xcode 27**: Simulator.app is now **Device Hub**,
  whose toolbar has the rotate button (`simctl` has no orientation command); `simctl io … screenshot`
  of a landscape device is already upright, so do not rotate it; and a simulator with no iCloud
  account shows an iCloud banner along the bottom of every screen (build 48 worded it "iCloud Sync
  Failed"; #1393 later made it name the account) — sign the simulator in, or note in the ledger how
  the banner was kept out of frame.
  Set an Apple-style status bar first:
  `xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
  - **Series Analytics (offline) exception** — the four Series Analytics dashboards (Production &
    Timeliness, Geographic Emphasis, Archival Sourcing, Administration Profiles) render from bundled
    offline aggregates, with **no downloaded volumes and no index**. Capture them on a device with an
    empty corpus (or mid-onboarding), so the shots show the offline empty-index state these dashboards
    are designed for. Reachable via the FRUS Research Guide → **About the Series** category
    (`IndexingEducationView`).
- **macOS** — capture each window with the macOS screenshot tools (`⇧⌘4` then space). Most committed
  shots were taken with the main window in full-screen so its backdrop hid every other app, then
  `screencapture -R` cropped each floating window. The People sheets (`people-list`, `people-detail`)
  were instead captured with `screencapture -o -l <windowID>` on the Corpus Browser window, which
  grabs just that window (with its presented sheet) shadow-free regardless of what overlaps it — the
  window id comes from `CGWindowListCopyWindowInfo`.
- Keep filenames lowercase-kebab and grouped under `ios/`, `ipad/`, `macos/`.

## Captured

**iPhone (`ios/`)** — `browse-corpus`, `people-list`, `people-detail`, `search-results`,
`document-view`, `analytics`, `chronology`, `settings`.

**iPad (`ipad/`)** — `browse` (portrait split view), `sidebar-landscape` (landscape adaptive
sidebar), `document` (landscape reading view), `search-results`.

**macOS (`macos/`)** — `browser` (Corpus Browser with the People button), `people-list` (the People
sheet's alphabetical list) and `people-detail` (the "Kissinger, Henry A." reconciled-identity detail
sheet) — both wired into §4.4 — `search`, `document` (full-window reading view), `analytics`,
`chronology`, `collections` (**STALE — slated for re-capture**; see Remaining), and `research` (the
Research window; not yet wired into the manual — no placeholder). Also `toolbar` (§3.1, **STALE**; predates the toolbar consolidation), `research-strip` (§3.2, the annotation strip with a document
open), `saved-searches` (§5.5, the Search window's saved-search list), `source-explorer` (§12, an
RG-59 source resolved to a NARA Catalog entry), `cross-reference-graph` (a document's reference
graph; embedded at macOS manual §8.5 and as a repo-README hero), and `analytics-table` (§13.2,
Corpus Analytics in Table mode).

> **macOS People browser (behavior difference, investigated and resolved).** An earlier capture
> attempt showed the macOS People browser with "Kissinger" split four ways and some `*`-prefixed
> names, while iOS showed one unified identity. Root cause: a **stale rollup observed mid-rebuild** —
> the Mac's `person_rollup` was from an older (pre-authority) build, and the version-7 reconsolidation
> triggered on launch had not finished when the window was opened. Once it completed, the macOS
> browser showed the correct single "Kissinger, Henry A." (13,174 mentions, 100 volumes) and a clean
> list, **identical to iOS** — the state captured here. Both platforms use the same read path
> (`PersonIndexView → allPersonsSortedByName → SELECT … FROM person_rollup`); there is no
> macOS-specific bug. The `*`/`†*` strings live only in the raw `persons` table and are folded away by
> consolidation. Minor UX note: right after a rollup-version bump the browser keeps showing the
> previous (stale) rollup until the background reconsolidation finishes — including across sheet
> reopens, since the loaded list is cached — with no "rebuilding…" indicator; a fresh relaunch once
> consolidation has completed reads the clean rollup.

## Remaining

These placeholders still need images. They were out of scope for the first "core feature screens"
pass — most need a state that the running, already-indexed app can't show without extra setup. (The
four Series Analytics dashboards are the exception: they render **offline with no index**, so the
simplest capture is a fresh/empty install navigated to the Research Guide → About the Series
category — see the *Series Analytics* entry below and *New since build 26*.)

**macOS Chronology hover magnifier** (§14 placeholder) is still open. The magnifier is a transient
SwiftUI `onContinuousHover` overlay (year bucket → month-by-month breakdown) driven by live pointer
tracking: it is visible interactively, but every disk-capture path tried (`screencapture -l`/`-R` and
the MCP `zoom` re-capture) fires the hover's `.ended` and dismisses the card before the frame is
written, and `CGWindowListCreateImage` is unavailable on macOS 15+. Capturing it cleanly needs a
ScreenCaptureKit-based grab (or an in-process move-then-capture helper). To reach the year-bucketed
chart, set a date range longer than 8 years that stays under the 5,000-document load cap (e.g.
1869–1878) and hover a year bar.

**iOS / iPadOS states needing special setup:**

- **Series Analytics (About the Series) dashboards** — the four offline dashboards (Production &
  Timeliness, Geographic Emphasis, Archival Sourcing, Administration Profiles). Unlike everything
  else here, these render **with no index**, so the simplest capture is a fresh/empty install (or
  mid-onboarding) navigated to the Research Guide → About the Series category. Each dashboard carries
  an editable start/end year range and a per-chart "View as table" pop-up (see *New since build 26*).
- **Onboarding** — welcome / scope picker / "Ready" screens (needs a fresh install, no
  `-hasCompletedOnboarding` launch arg).
- **Indexing banners & Live Activity** — single- and multi-volume indexing banners, the
  indexing-complete card, the Dynamic Island and Lock Screen Live Activity (need an active download
  on a device; the simulator corpus is already indexed).
- **Stage Manager multi-window** (iPad) — two document windows side by side.
- **App Store listing** — the product page.
- **Feature flows not in the core pass** — embedded browser sheet, Research tab, Collections
  editor with documents, Citation Lookup, AI summary panel (Apple Intelligence, device-only),
  and, on **iOS/iPadOS only**, the cross-reference graph, Source Explorer, Person Analytics and
  Cross-Reference Analytics. On macOS all four of those are already committed
  (`cross-reference-graph`, `source-explorer`, `person-analytics-trends`,
  `person-analytics-network`), as is `collections-ribbon` — all stale per #1081, but present.

## New since build 35 — the Settings North Star

Build 36 rebuilt Settings end to end: seventeen destinations became thirteen rows in four groups
(Library · Research · Reading & Search · System), driven by one shared model on both platforms.
**Every existing settings shot is obsolete**, and most of these surfaces have never been captured.
Legend as above: 🆕 new shot · 🔄 re-capture (existing shot is stale).

The design handoff's reference framings — `design_handoff_settings_northstar/screenshots/`,
`00-ia-settled-1c.png` through `10-about-polish.png` — are one per pane and are what these should
look like.

**iPhone (`ios/`)**

- 🔄 `settings` — **STALE, three IA generations out of date.** The committed image shows Volumes
  (Downloads · Storage & Index · Sideload), Research (User Tags · Projects · Summarization ·
  a Log Research Sessions toggle), Integrations, Data, and a Reset row. Not one of those group
  names or rows still exists. Re-capture the root: the iCloud Sync section, the **Search Settings**
  field, and the four groups.
- 🆕 `settings-volumes-storage` — the merged Library destination: storage bar with the XML/index
  split, Downloaded Volumes, Keeping Current, Storage & Index.
- 🆕 `settings-free-up-space` — the Free Up Space sheet with candidates selected and the
  **confirmation dialog** showing. This is a fixed-safety surface; the dialog is the point.
- 🆕 `settings-connections` — the two service cards (NARA Catalog · Zotero) showing connected and
  not-connected state side by side.
- 🆕 `settings-data-recovery` — Contents counts, the export rows, and the three-rung recovery
  ladder with its consequence lines.
- 🆕 `settings-research-sessions` — the Log Research Sessions switch, the Session Log row with real
  counts, and Delete Recorded Sessions…
- 🆕 `settings-notes` — the pane iOS never had: recent notes plus the All Notes door.
- ⚙️ `settings-search-results` — the Search Settings field with a query typed ("privacy" or
  "stop words") showing the tree filtered. Optional, but it is the feature reviewers miss.

**Mac (`macos/`)**

- 🆕 `settings-sidebar` — the window with the grouped sidebar and a pane open beside it. There has
  never been a committed macOS settings shot.
- 🆕 `settings-word-cloud` — the pane carrying the new bench: the **Sample** row, the
  "Keeps N of M terms" line, and the single Hidden Words editor with its scope picker.
- 🆕 `settings-session-log` — the Session Log sheet with real sessions expanded to their events.

**Not to capture**

The macOS Settings window has no search field (iOS only), and macOS has no live sync status inside
Settings (it is in the main window's status bar). Both are real gaps, recorded in
`Planning/Completed/Settings-Parity-Audit-2026-07-25.md`, not things to shoot.

## New since build 26 (build-27 tier — partly captured)

The build-27 feature set adds the analytics surfaces and Collections polish below. **Several of
these have since been captured** — `macos/person-analytics-trends`, `macos/person-analytics-network`,
`macos/series-production`, `macos/collections-ribbon` are committed, and `macos/collections` has been
re-captured — so treat the tick-list in issue **#1081** as authoritative over this list
(#1081 supersedes #106). Legend: 🆕 new
shot · 🔄 re-capture (existing shot is stale) · ⚙️ optional re-capture to surface a new state.

**iPhone (`ios/`)**

- 🆕 `series-production` — Series Analytics: **Production & Timeliness** (publication-lag scatter with
  the evolving timeliness-target step line, volumes-per-print-year bars, cumulative-growth curve).
  Capture on an empty/offline install via Research Guide → About the Series.
- 🆕 `series-geography` — Series Analytics: **Geographic Emphasis** (regional-share-over-time stacked
  chart by the 6 State Dept regional bureaus, region totals, top countries). Offline.
- 🆕 `series-archival` — Series Analytics: **Archival Sourcing** (provenance-mix-over-decades chart,
  overall composition, note density by decade). Offline.
- 🆕 `series-administrations` — Series Analytics: **Administration Profiles** (docs-per-administration
  colored by party, per-administration volume list with document proportions, editorial-notes
  toggle). Offline.
- 🆕 `person-analytics-trends` — **Person Analytics**, Trends mode (most-mentioned people by era +
  multi-person mention-trajectory comparison). Browse → Analysis Tools → Person Analytics.
- 🆕 `person-analytics-network` — **Person Analytics**, Network mode (co-mention ego-network graph:
  focus person + top co-mentioned partners).
- 🆕 `crossref-analytics` — **Cross-Reference Analytics** (most-referenced documents / in-degree,
  degree-distribution histogram, volume-to-volume heat matrix, PageRank influence landmarks).
  Analysis Tools → Cross-Reference Analytics.
- 🆕 `analytics-table-popup` — the per-chart **"View as table"** pop-up in iPhone **list** mode with
  the Copy-CSV control (shown from any analytics chart).
- 🆕 `analytics-export-menu` (§13.7) — Corpus Analytics' **Options (•••)** menu open on the **Export**
  heading, showing Chart data (CSV)…, Figure (PNG)…, and Figure (PDF)…. Capture on a **time** axis
  (Decade / Year / Month / Day) so the two figure items are enabled — on **By Subseries** / **By
  Volume** they appear dimmed.
- 🆕 `analytics-figure-png` (§13.7) — **the exported file itself, not a device capture**: run
  Figure (PNG)… on a By-Year chart and commit the resulting 1,200-pt white plate, so the caption
  strip (scope · year range · value mode · app version · date, plus the pointer to the CSV) is
  legible. Downscale for the manual if needed; do not crop the strip away.
- ⚙️ `analytics` (re-capture optional) — existing By-Year term-frequency chart showing the new
  **"% of documents"** normalization toggle enabled.

**iPad (`ipad/`)**

- 🆕 `series-production` — Series Analytics Production & Timeliness on iPad (shows the editable
  start/end year-range control and the wider dashboard layout). Offline. Represents the four Series
  dashboards on iPad; ideally also capture `series-geography`, `series-archival`,
  `series-administrations`.
- 🆕 `person-analytics-trends` — Person Analytics Trends mode on iPad.
- 🆕 `person-analytics-network` — Person Analytics Network ego-graph on iPad.
- 🆕 `crossref-analytics` — Cross-Reference Analytics on iPad (heat matrix + PageRank landmarks).
- 🆕 `analytics-table-popup` — the per-chart "View as table" pop-up rendered as a native **Table** on
  iPad, with Copy-CSV.
- 🆕 `analytics-export-menu` — the Corpus Analytics **Export** menu open in the iPad **toolbar** (the
  iPhone shot shows it nested in the Options ••• menu instead, so both placements are on record). No
  manual placeholder — §13.7's iOS shots are iPhone-worded.
- 🆕 `collection-sort-menu` — the Sort-by-Date two-mode menu ("Across the Whole Collection" vs "Within
  Each Section") in the iPad Collections toolbar.
- 🆕 `collection-note-collapsed` — the collapsed "Add a note" affordance in the iPad collection editor
  (before a note is added).

**macOS (`macos/`)**

- 🆕 `series-production` — Series Analytics Production & Timeliness dashboard (offline; Research Guide
  → About the Series). Also capture `series-geography`, `series-archival`, `series-administrations`
  for the other three.
- 🆕 `person-analytics-trends` — Person Analytics window (`frus.personAnalytics`), Trends mode.
- 🆕 `person-analytics-network` — Person Analytics window, Network co-mention ego-graph.
- 🆕 `crossref-analytics` — Cross-Reference Analytics window (`frus.crossRefAnalytics`): volume-to-
  volume citation heat matrix + PageRank influence landmarks (and/or degree-distribution histogram).
- 🆕 `analytics-table-popup` — the per-chart "View as table" pop-up as a native macOS **Table** with
  Copy-CSV.
- 🆕 `analytics-export-menu` (§13.7) — the **Export** menu open in the Corpus Analytics window
  toolbar: Chart data (CSV)… · Figure (PNG)… · Figure (PDF)…. Capture on a **time** axis so both
  figure items are enabled (**By Subseries** / **By Volume** dim them).
- 🆕 `analytics-figure-heatmap` (§13.7) — **the exported file itself, not a window capture**: from
  Cross-Reference Analytics, export the volume-to-volume heat matrix via Figure (PNG)…. The plate
  renders the whole grid at once with **each cell's count printed**, the shading legend, and the
  caption strip — all three must stay visible. The matrix shades with the **system accent color**,
  so capture under the default accent for a reproducible figure.
- 🆕 `collections-ribbon` — the consolidated Collections manager ribbon: Add ▾ (Documents / Section
  Heading / Note Block / Passages / Apparatus) · Sort by Date ▾ · View ▾ (Composition / Front Matter
  / Preview) · Export….
- 🆕 `collection-sort-menu` — the Sort-by-Date ▾ menu opened, showing "Across the Whole Collection" vs
  "Within Each Section".
- 🔄 `collections` — **RE-CAPTURE**: the existing shot is stale (its subject — the always-visible
  collection note + old 10-button toolbar — has been replaced). The new shot must show the
  consolidated four-control ribbon and the collapsed "Add a note" affordance (collection note not yet
  added).
- 🔄 `toolbar` — **RE-CAPTURE**: the committed shot predates the toolbar consolidation. The
  current trailing set is Search, Browse, **Analytics ▾**, **My Research ▾**, and the
  Research-rail toggle, with the centered `volumeId/documentId` title (macOS manual §4.1).
  Person Analytics and Cross-Reference Analytics are items *inside* Analytics ▾, not buttons.
- ⚙️ `analytics` (re-capture optional) — existing term-frequency chart showing the new "% of
  documents" normalization toggle enabled.
