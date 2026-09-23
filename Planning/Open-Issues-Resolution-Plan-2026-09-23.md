# Open-issues resolution plan — 2026-09-23

Base: `v2` @ `b5175801` · index **v54** (`IndexingPipeline.swift:870`) · person rollup **v9**
(`:924`) · build **48** · **no open PRs** · corpus pinned at `550a8c5c5`.

**Scope.** 39 issues are open. The owner excluded **#1309** (the Yalta TEI sweep, an OH report) and
**#234** (the people-browser decision set), so this plan covers the other **37**. Thirty-six of them
were filed on 2026-09-22/23 from the #1081 screenshot sweep of build 48 (iPad Pro 13-inch (M5),
iOS 27.0, and macOS 27, AppStore configuration); #1352 came from verifying the Mac manual on
2026-09-21. None has a branch or a PR. Nothing on `v2` since filing touches any of them.

**What was re-checked and what was not.** Every issue body was read whole. The sites that decide
*sequencing* were then confirmed against this tree — the shared functions two issues claim, the
version constants, the test suites the issues name, the manual sentences they call false — and
§1's last column says which. The corpus-scale counts (9,985 notes, 79,788 documents, 214,223
titles, and so on) were **not** re-measured; they are quoted as the issues' own figures.

**This is a proposal, not a plan of record.** `Plan-Of-Record-2026-09-06.md` stays the single
live one; `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` filters on the
`Plan-Of-Record-` prefix, which this filename does not carry. The previous proposal,
`Open-Issues-Resolution-Plan-2026-09-19.md`, is discharged: every issue it planned has shipped
except the two excluded here.

**Sizes:** XS under an hour · S half a day · M one to two days · L three days or more, tests
included. "Bump" means the PR must move `currentDateIndexVersion` (parse output changed) and/or
`currentPersonRollupVersion` (rollup output changed) in the same commit.

---

## 1. Where the 37 issues stand

| # | Title (short) | Lane | Size | Bump | Owner gate | Checked here |
|---|---|---|---|---|---|---|
| 1352 | NARA Lookup guide deep-link names a dead page id | S | XS | no | — | issue only |
| 1356 | Removed volume stays on screen, still "indexed" | K | M | no | — | dialog site ✔ |
| 1357 | iPad remove-confirmation popover anchored to the list | K | S | no | — | dialog site ✔ |
| 1358 | Collections list counts headings/prose as documents | K | S | no | — | all 9 `documentEntries?.count` sites ✔ |
| 1359 | Collection editor never titled by name | K | S | no | **editable title?** | issue only |
| 1360 | Prose row is a fixed-height scrolling editor | K | M | no | **self-size or preview** | issue only |
| 1361 | History records the opener's label, never names the document | K | M | no | — | writer site ✔ |
| 1362 | Research two-pane: open category not marked | B | S | no | — | `isTwoPane` branch ✔ |
| 1363 | Browse two-pane: no level title; Back rebuilds the level | B | L | no | title story (measured) | `twoPaneLayout` ✔ |
| 1364 | Browse Within This Scope changes nothing on screen | B | S/M | no | — | menu site ✔; Mac manual claim ✔ |
| 1365 | Topic index door keeps the earlier search | B | S | no | — | `apply` cases ✔ |
| 1366 | Inquiry drafts print the topic placeholder (3 of 4 paths) | V | M | no | **rule: creation or render** | 3 bare inits ✔; D8 ✔ |
| 1367 | "Working on:" subtitle runs 224 pt into the detail pane | B | M | no | **question in pane or on bar** | `CorpusView` chrome ✔ |
| 1368 | iPad aux-window Done drops to the Home Screen | W | M/L | no | **reverse the no-activation pin** | marker needle ✔; 6 origin adopters ✔ |
| 1369 | `n="0"` source notes show a "0" marker (9,985 documents) | T | S | **index** | — | `printedLabel` ✔ |
| 1370 | People: lifespans as "Active", 235 reversed ranges, 5,217 debris roles | T | L | **index + rollup** | **birth/death home; row seal** | rollup v9 ✔; Kissinger pin ✔; manual claims ✔ |
| 1371 | Reader drops list heads and labels (79,788 documents) | R | M/L | **no under data-skip** | **data-skip or flatText** | `kVersion` 1.2 ✔ |
| 1372 | Editorial-note heads never indexed (8,467) | T | S | **index** | — | `extractHeader` ✔ |
| 1373 | Topics cloud reads 0 terms on iOS 27 (NLTagger first-scheme) | K | M | no | physical device | gate ✔; no warm-up call ✔ |
| 1374 | "1 volumes"; ungrouped `String(format:)` counts | C | M | no | scan baseline | `HubCopy` ✔ |
| 1375 | Stored titles/datelines gain a space at every markup boundary | T | M | **index** | — | `extractHeader` ✔ |
| 1377 | Mac packet sheet shows only Done | V | M | no | — | toolbar placements ✔ |
| 1378 | Archives Visits window 900×640 overflows; manual names ⋯ menu | V | S | no | **button or menu** | manual lines ✔ |
| 1379 | Heat matrix hides rows in a 480 pt box; head-cut labels | A | M | no | — | `volumeTag` ✔ |
| 1380 | Mac windows say "tap" | C | M | no | — | issue only |
| 1381 | Word Cloud segments read "Mostly Cloudy" to VoiceOver | A | XS+scan | no | — | issue only |
| 1382 | Person Analytics caption prints "1,940–1,992" | C | S | no | — | key in EditableContent ✔ |
| 1383 | Mac hover replaces the clicked partner | A | S/M | no | — | both `.onHover` sites ✔ |
| 1384 | Network labels cut at 14 chars, drawn over each other | A | M | no | — | issue only |
| 1385 | "(of 25+ )" | A | XS | no | — | key in EditableContent ✔ |
| 1386 | Classification chip inherits the −2.2em hanging indent | R | S | no | — | CSS ✔ |
| 1387 | Overflow chip counts an enclosing document twice | A | S | no | — | issue only |
| 1388 | Volume tags not unique: 11 tags shared by 29 volumes | A | S/M | no | — | `volumeTag` ✔ |
| 1389 | Section title built from every `<head>` (176 sections) | T | S | **index** | — | issue only |
| 1390 | Unprinted Material rows indistinguishable | S | M | no | — | issue only |
| 1391 | Archival Neighbors prints the number twice | S | S | no | — | issue only |
| 1392 | "Document 41., footnote 3" | V | S | no | **locator or strip** | keys in EditableContent ✔ |

Lanes: **T** TEI/index · **R** reader render · **B** Browse/Research two-pane · **W** iPad windows ·
**A** analytics and chronology · **C** copy and counts · **V** Archives Visit · **S** Source
Explorer · **K** Collections, storage, history, word cloud.

---

## 2. What the review found that the issues do not say

1. **Five issues change parse output, so five PRs carry an index bump, and testers must pay for
   them once.** #1369, #1372, #1375, #1389 and #1370 each move `currentDateIndexVersion`; #1370
   also moves `currentPersonRollupVersion`. The rule is a bump in the same commit as the parse
   change (each PR takes the next number, v55…v58, rollup v10), and the cost lands on the
   developer's own device between PRs. What matters for testers is that **build 49 is cut only
   after the whole T lane has merged**, so the TestFlight note owns exactly one full re-index —
   the lesson the 2026-09-19 plan recorded for v52/v53. The build bump edits `README.md` too
   (`readmeStatesCurrentBuild` pins `Current build: **48** (version 0.2)`).
2. **`IndexingPipeline.extractHeader` is claimed by two issues and read by two more.** #1372
   unwraps the editorial-note wrapper; #1375 replaces the space join. #1391's number-strip and
   #1361's stored title both read its output. One PR owns the function (T1 below), and #1391's
   strip must not depend on the join — the issue already says so, with the `61.<lb/>Mr. Trescot`
   case.
3. **#1371 need not join the bump cluster, and should not.** `ASTToRenderNodeConverter.kVersion`
   is `"1.2"` and its own history records three occasions (#659, #985, #1323) where it was
   deliberately *not* bumped by rendering the new text with `data-skip="1"` and leaving
   `flatText` byte-identical. The same route here keeps `body_hash` — the highlight coordinate
   space — unchanged for the 79,788 documents that gain headings and labels. The flatText route
   would stale every existing highlight in them. Recommend data-skip; it is the only thing that
   keeps #1371 out of lane T.
4. **#1363 and #1367 are one fault, and their proposed title fixes conflict.** Both come from
   `twoPaneLayout` putting both panes under one `NavigationStack` while the list pane's
   `CorpusView` sets the bar's title, display mode and subtitle. #1367 wants `CorpusView` to stop
   writing chrome in the two-pane so the detail level's `navigationTitle` lands on the bar (the
   F-2 design's stated intent, §7.3); #1363 wants a header drawn inside the detail pane (the F-2
   design's stated *fallback*). Neither issue measured which title wins once `CorpusView` stops.
   A one-hour device probe decides it before either PR is written (B0 below). The state half of
   #1363 — a per-level memory on `BrowserViewModel` — is independent of the title story and can
   proceed in parallel.
5. **Eight issues propose a source-scan test, and two of the scans have opposite rules for the
   same shape.** #1374 (counts must group and singularise), #1382 (years must never group),
   #1385 (no space inside parentheses), #1380 (no "tap" in Mac-compiled text), #1358 (no
   `documentEntries?.count` under Collections/ProjectContext), #1381 (segmented pickers need
   accessibility labels), #1383 (no `.onHover` assigning a `selected…` property), #1377 (no
   `.primaryAction`/`.secondaryAction` toolbar items in a macOS-presented sheet). #1382 asks
   that its scan and #1374's land together; C1 does that. Every scan must be run against `v2`
   first and must fail there naming the sites its issue lists; a scan that passes on `v2` has
   the wrong regex. Each must also assert it read more than zero files, or a moved directory
   turns it green.
6. **Three issues sit on hand-maintained twins.** #1356 (`DownloadedVolumesListView` /
   `MacAllVolumesSheet`), #1390 and #1391 (`SourceExplorerView` / `MacSourceExplorerView`). Each
   fix puts the row text or the row state in one function both twins call; a patch applied to one
   twin has no-opped on the other before (the Source Explorer render-block drift is on record).
7. **`Docs/EditableContent.md` catalogues strings these issues rewrite.** Verified for
   `personAnalytics.ranking.subtitle` (#1382), `personCoMention.cap.disclosed` (#1385) and both
   `archiveVisit.seeding.footnote.*` keys (#1392); #1374, #1380 and #1387 will hit more. The
   2026-09-20 amendment (PR #1349) brought the file current by a mechanical sweep, so every PR
   that changes a `defaultValue:` must amend its block in the same PR, or the next sweep reports
   the drift as a defect of this wave.
8. **The chronology screenshots #1387 and #1388 cite as "on the PR #1355 branch" are on `v2`
   now** (merged 2026-09-23, `b5175801`). Both manuals' chronology captures show the "24 before ·
   24 after" chip and the duplicate `v10` legend and need recapturing after A1 and A3 — one
   sitting, not two.
9. **#1368 changes what every UI-test `tearDown` observes.** `UITestPresentation
   .dismissAnyPresentation` taps the Done buttons that today close the app's only foreground
   scene. After the fix, Done fronts the launching window — which is what the next `launch()`
   wants — so the change is a net gain for the suites, but the marker test
   `WindowTargetingTests.noSceneActivationYet` must be inverted into a positive pin (activation
   exists at exactly one site) rather than deleted.
10. **Nothing here trips the CloudKit gate.** #1361 deliberately keeps the document number off
    the mirrored `@Model`; #1370's birth/death columns are SQLite; #1366's factory sets fields
    `ArchiveVisitPlan` already has. If `CloudKitSchemaInventoryTests` goes red in this wave,
    something unplanned changed.
11. **New files cost an `xcodegen generate` plus the scheme restore, per PR.** Likely new files:
    `CountCopy` (C1), the aux-window close action (W1), a shared row-text function for the Source
    Explorer twins (S3), any new UI-test suite (K4's popover test, A2's matrix test). Adding to an
    existing file where one fits avoids the step; the plan flags each.
12. **#1373 is wider than the word cloud.** Thirteen files tag with `NLTagger` in the app and
    `WordCloudKit`, including `SearchService`, `LexicalSimilarityGenerator`, `Keyness` and
    `AppState`. Under the measured failure, whichever scheme the process tags with *first* fails
    for the rest of the session, so the warm-up has to run before any of them — at launch, not
    inside the tokenizer — and the canary belongs in `WordCloudKit` so the generator inherits it.
    The Distinctive measure compares scope lemmas against `keyness-baseline.json`, which was
    counted with lemmas; a failed lemma scheme makes it silently wrong, so the canary must gate
    Distinctive too.
13. **#1370's generator half is owner-machine work.** Cutting the register role at a word
    boundary means re-running `PersonAuthorityIndexGenerator`, whose inputs (`PEOPLE_DATA_DIR`,
    `PERSONS_COMPLETE`, `MERGE_AUDIT_CSV`) are local repositories, and CLAUDE.md records that a
    regeneration moves rollup outcomes and needs a rollup bump. T5 already bumps the rollup, so
    the regeneration should ride T5 if the owner can run it that week; otherwise it waits for the
    next rollup bump rather than costing one of its own.

---

## 3. Lanes and sequence

```
T (index):   T1 #1375+#1372 (v55) → T2 #1389 (v56) → T3 #1369 (v57) → T4 #1370 (v58, rollup v10) → cut build 49
R (reader):  R1 #1386 harness → R2 #1371
B (browse):  B0 probe → B1 #1367+#1363-title → B2 #1363-state ; B3 #1362 ; B4 #1364 ; B5 #1365
W (windows): W1 #1368
A (charts):  A1 #1388 → A2 #1379 → A3 #1387 ; A4 #1383+#1385 → A5 #1384 ; A6 #1381
C (copy):    C1 #1374+#1382 (+#1385 scan) → C2 #1380            (C after A, same files)
V (visits):  V1 #1392 → V2 #1366 → V3 #1377 → V4 #1378
S (sources): S1 #1352 ; S2 #1391 → S3 #1390                     (S2 after T1)
K (misc):    K1 #1358 ; K2 #1359 ; K3 #1360 ; K4 #1356+#1357 ; K5 #1361 (after T1) ; K6 #1373
```

Lanes are independent of each other except where marked. Within a lane the order is by shared
files. Build 49 waits for lane T only; everything else ships in whichever build is next.

### Lane T — TEI and index (the critical path for build 49)

**T1 — #1375 and #1372 in one PR, v55.** One punctuation-aware join used by `extractHeader`,
`extractDateline` and `plainTextExcludingFootnotes` (concatenate when either piece carries a
boundary space, when the left ends in an opening bracket or quote, or when the right begins with
closing punctuation; otherwise one space), and `extractHeader` looking inside a single leading
`.editorialNote` wrapper. Replace the hand-built fixture at `IndexingPipelineTests.swift:1134–1152`
with parser-driven fixtures for frus1946v06 d2, frus1861 d69, frus1915Supp d1120 (must not glue)
and the frus1961-63v11 d1 dateline, plus a `subtype="editorial-note"` document whose stored header
is `245. Editorial Note`. Correct the population comments in `CrossReferenceStore.swift` and
`DocumentDisplayTitle.swift`. Carry #1372's view half here as well — `CrossReferenceAnalyticsView`
labels indexed rows through `documentTitleFacts` + `DocumentDisplayTitle`, keeps the manifest form
only when `isIndexed` is false, and routes both CSV `displayLabel`s through the same static — with
a test that the header `openDocument` receives for an indexed note is the printed head (the
2026-09-23 comment's point). Verify the measured residue the issue reports (728 titles, 4,903
datelines still differing) is not worse after the change by re-running its comparison on one
re-indexed device.

**T2 — #1389, v56.** `Frame.titleCaptured`; a capture starts only for the innermost frame's first
`<head>`. Fixtures beside `structureTitlesCollapseWhitespace`: a preface followed by a
`<frus:attachment><head>`, and a section whose `<head>` is followed by `<list><head>Present</head>`.
Assert through both `parseVolumeStructure` and `parseVolumeFull(...).structureSections`, since the
second is the persisted path.

**T3 — #1369, v57.** `printedLabel(from:)` returns nil for `"0"`. `FootnoteLabelTests` gains one
case per encoding the corpus uses for an unnumbered source note (absent, `""`, `" "`, `"0"`), each
on a `type="source"` note inside `<head>`, asserting a nil label, the archival glyph in the marker
HTML, "Source note" as the accessibility label, and no `[0]` on the collection header. The bump is
owed because the shared rule moves `external_citations.note_label` for four body notes in
`frus1961-63v24`.

**T4 — #1370, v58 and rollup v10.** The largest PR in the wave, and the one with two owner
decisions (§4 items 3 and 4). Six parts: (1) life years leave `start_year`/`end_year` — either
their own rollup columns or a display-time read of the authority/POCOM entry — and
`IndexingPipelineTests.swift:4455` is rewritten to assert an authority-covered start year is *not*
the birth year; (2) the mention-era query joins `document_cache` and excludes front matter; (3)
`extractRoleAndYears` reads the cue word ("until/to/through/till" end, "from/after/since" start),
parses `Month D, YYYY–Month D, YYYY`, and removes a year span from the role only when it is a
trailing `, YYYY(–YYYY)` or ` (YYYY–YYYY)` clause; (4) a member's span is min/max over every year
it carries, so it cannot invert; (5) both manuals' seal sentence and active-years sentence are
corrected or the seal is added to `PersonIndexRow`; (6) the register-role cut in the generator.
Tests: a `TEIParserTests` table of real persons-list shapes asserting no role ends on a month,
day or preposition, contains `, ;`, ` ;` or `, –`, or loses a parenthesis; and a rollup property
test over the pipeline test database (no `start_year > end_year`, no authority birth year as a
start unless a list or mention says so). Interaction with #234: this PR resets the `persons`
table's parse; whatever #234 decides builds on the corrected table, not the current one.

**Cut build 49** after T4 merges: bump `project.yml` and `project.pbxproj` by hand (never
`xcodegen`), edit `README.md`, and write the TestFlight note to say every device re-indexes once
and why (titles, datelines, section titles, source-note markers, people).

### Lane R — reader render (no bump)

**R1 — #1386.** One CSS rule, `.fn-list-item > * { text-indent: 0; }`, and the test that
would have caught it: lift `OffsetEngineTestHarness` (`FRUSOffsetEngineTests.swift:376`,
private today) into a shared helper, load `HTMLTemplate.build` for a model with the
`sourceWithMarking` fixture and a footnote holding a `.listBlock`, and assert every non-inline
descendant of `.fn-list-item` computes `text-indent: 0px` (visiting more than zero elements,
including the chip and a list item) and that the chip's text starts inside its border box. Run it
on `v2` first; it must fail there.

**R2 — #1371, data-skip route (§4 item 2).** `.listBlock` gains an optional heading and per-item
labels (or a dedicated heading node emitted before the block, on the `.attachmentHeading`
precedent — never `.heading`, which serialises as the document `<h2>`). The converter walks
`.list` children in document order: `.head` becomes the heading, a `.unknown("label")` is held
and attached to the next `.listItem` (exact for 449,657 of 449,659 labels by the issue's count),
and `.pageBreak`, `.lineBreak`, `.footnote` and the rest are kept beside the neighbouring item —
the two d93 footnotes come back with their bodies. The serializer prints the heading above the
list and the label where the bullet goes with `data-skip="1"`, so `flatText` and `kVersion` are
untouched; PDF and DOCX print the label instead of `"• "`. Update the four other `.listBlock`
switches the issue lists and the doc comment at `FRUSASTNode.swift:247`. Tests: d84's real shapes
(`<list type="subject"><head>SUBJECT</head>`, and the labelled list with a `<pb/>` between items)
reach the HTML in order and `renderingVersion` does not change; and the class test — one `<list>`
containing every direct-child element the corpus uses (item, label, head, pb, lb, closer, gap,
salute, note, figure) loses no text and no footnote. Uses R1's harness for a rendered assertion if
one is wanted, which is why R1 goes first.

### Lane B — Browse and Research two-pane (iPad)

**B0 — the probe, not a PR.** On an iPad Pro 13-inch at two-pane width, suppress `CorpusView`'s
`.navigationTitle`, `.navigationBarTitleDisplayMode(.large)` and `.workingOnSubtitle` when the
two-pane is active, and record (a) which title the bar shows at each depth — the level's, or the
outer container's inline "FRUS Explorer" — and (b) what the People/Topics/Collections
`.searchable` fields do to the bar's title and subtitle after activate-and-cancel (#1367's
"observed but not explained" paragraph). Half a day, written up as a comment on #1367.

**B1 — #1367 with #1363's title half.** If the probe shows the level's title landing on the bar,
ship that: `CorpusView` stops writing chrome in the two-pane (`showsNavigationChrome`, the flag
F-2 §7.3 names), and the research question is applied once as the full-width bar's subtitle (drop
the `!listPaneShown` gate) *or* drawn as a `List` header inside the 340 pt pane (§4 item 8). If
the probe shows the outer title winning, ship F-2's fallback instead: the detail pane's Back row
becomes a header carrying `breadcrumbLabel` with the header trait, shown at every depth. Either
way, correct the comments at `CorpusView.swift:72` and `BrowserView.swift:754–760`, and add an iPad
scenario to `UIObstructionTests` (skips below the 820 pt gate) asserting the `Working on:` element
lies inside the pane or bar the fix chose, and that the bar's title is the level's, not "FRUS
Corpus". A third assertion covers the search variant: after activating and cancelling the People
search, the title element still exists with an unchanged frame.

**B2 — #1363's state half.** A per-level memory on `BrowserViewModel`, keyed by the level's
position on the path, pruned when the path shrinks past it or `select(_:)` replaces it. Move the
Archives lens, its closed eras and groups, and the collection search first; then the catalogue and
editor searches. Not `.id(level)` (the #1301 reuse contract) and not hidden mounted levels (their
toolbars reach the one bar). Unit test on the view model (memory survives a push and pop above it,
gone after `select` or a shrink past it), plus a `BrowseNestedSectionTests` walk — Archives ▸
Collections ▸ type ▸ open ▸ Back asserts the segment and the text survive — on iPad, with the same
walk on iPhone as the control.

**B3 — #1362.** In the two-pane branch of `sidebarRow`, `.listRowBackground` from `selectedItem`
(the `ReferenceListPanel.swift:192` precedent) and `.accessibilityAddTraits(.isSelected)`, keeping
the button, greedy frame and `contentShape` that #312 put there. Rows get accessibility
identifiers; the iPad-only UI test taps History and asserts that row alone reports `isSelected`.
Check both the sidebar and floating-tab-bar representations by eye.

**B4 — #1364.** `ScopeIndexView` gains `onBrowseWithin`; the iOS mount sets the filter and calls
`vm.select(.subseriesIndex)`, so the reader lands under the banner the iOS manual already
promises. The root's Subseries tile caption comes from `ScopeAxis.filterState` while a filter is
active, and the active scope's row carries the filter glyph. Two UI tests (long-press → banner
on screen with no further navigation; launch with the filter set → the tile names the scope), on
both idioms. **Correct `Docs/macOS-User-Manual.md:276`** in the same PR: the Mac has no Browse
Within This Scope, and no Mac surface reads `browseScopeFilterId`.

**B5 — #1365.** The arrival rule moves into `SubjectIndexGrouping` as a pure function `apply(_:)`
calls: `.group` clears `query` and sets the chip, `.all` clears both. Pin both in
`SubjectIndexGroupingTests` (`SubjectFacetScopeTests.swift:560`). The chip says "1 of 6 topics"
when a search narrows the area further. Shared with the Mac Topics window.

### Lane W — iPad aux windows

**W1 — #1368.** One shared close action for iOS aux windows, injected as an environment value
from the scene declarations in `FRUSExplorerApp.swift` (where "this is a window" is known) and
read by every Done that today calls a bare `dismiss()`; absent, Done falls back to `dismiss()`, so
sheet presentations are unchanged. The action resolves the launching window (falling back to any
live main window), asks iPadOS to activate its scene session
(`UIApplication.shared.activateSceneSession(for:)`), then dismisses. Three enablers: `MainTabView`
registers its `UISceneSession` beside the `SceneID` it already registers (a small
`UIViewRepresentable` reading `window?.windowScene?.session`); the six analytics scenes apply
`.auxWindowOrigin` (six scenes carry it today — document, Source Explorer, graph, word cloud,
Related Documents, Archival Neighbors — and none of the analytics scenes does); and the nine Done buttons
plus the `CollectionDetailView` citing-volume path adopt the action. Invert
`noSceneActivationYet` into a pin that activation exists at exactly one site (widen its needle to
`activateSceneSession`). The UI test — for each Analysis Tools surface: open, tap Done, assert
`.runningForeground` and the main tab bar exist — is run against `v2` on one pinned iPad UDID first
and must fail there; record that simulator's windowing mode (the defect was seen in Full Screen
Apps mode; Stage Manager was not tested). Owner gate: §4 item 9.

### Lane A — analytics and chronology

**A1 — #1388.** `volumeTag` builds from the whole id suffix after `frus<subseries>`: keep a range
(`v10–12`), mark a supplement (`fiche`), keep the E prefix (`vE-5`; the current `(E-)?` branch
never matches the lower-case `ve05` spelling), keep a conference name and an edition. Change
`distilledLabelUniqueAcrossBundledCorpus` to assert the **tag half** is unique — it fails on today's
manifest naming the 11 groups — and add the `v10-12mSupp` / `v10` and `ve15p2` / `ve15p2Ed2` pairs
to `ChronologyVolumeLabelTests`. Correct the three comments that state the uniqueness claim
(`ChronologyViewModel.swift:641–642`, `CrossReferenceAnalyticsView.swift:1090–1094`,
`MacDocumentTitle.swift:37`). Consumers move together: legend, Mac magnifier, matrix rows, Corpus
Analytics series legend, iPad compilation parent line, the Mac document window's centre label.

**A2 — #1379, after A1.** Remove `.vertical` and `.frame(maxHeight: 480)` from `heatMatrix` so the
page scrolls; keep a horizontal scroll only for the cells, with the row-label column outside it.
Size the label column to the window (up to the figure's 320 pt and two lines), and split the label
into a topic `Text` truncated at the tail beside a tag `Text` that never truncates — which needs a
sibling of `distilledVolumeLabel` returning topic and tag apart and without the 40-character
pre-cut. Unit test the split for `frus1945Berlinv01`/`v02` (topic starts "The Conference of
Berlin", no leading or trailing "…", tags differ). iPad UI test with a fixture index that fills all
15 rows: a swipe starting on the matrix moves the *Landmark Documents* heading, and the 15th row's
label and the first column code are on screen together. Run it on `v2` first; it must fail. Check
on macOS that a wheel gesture over the matrix scrolls the page.

**A3 — #1387.** A `nonisolated static` beside `overflowDirection` returning three disjoint counts
(begins before only, ends after only, spans the whole range); the chip prints the non-zero ones
and the parts add up to the total. Test it on the three fixtures `overflowDirections` already
builds: 1 / 1 / 1, summing to 3 — today's two-counter shape returns 2 and 2. Chronology
screenshots in both manuals are recaptured after A1 and A3 together (owner).

**A4 — #1383, carrying #1385.** `PersonCoMentionGraphViewModel` gains `hoveredPartnerId`: hover
sets it on entry and clears it on exit only if it still names that node; only clicks write
`selectedPartnerId`; the dock and node emphasis read `hoveredPartnerId ?? selectedPartnerId`. Put
the logic in `hoverChanged(_:hovering:)` / `toggleSelection(_:)` so the tests drive the emitter,
one fixture per rule (select A, hover B on and off → A; hover A then click A → A, today nil;
select A, hover B → dock B, hover off → dock A). Same change in `VolumeConnectionGraphView`. #1385
rides here: `(of \(count)+)` without the space, and both doc comments say the count is a lower
bound from a probe capped at `partnerLimit + 1`. The `.onHover`-assigns-`selected…` scan goes in
this PR; the parenthesis-spacing scan goes to C1.

**A5 — #1384, after A4.** `shortLabel` ends a cut with "…" at a word boundary when one falls
within the limit; labels are measured (`context.resolve(_:).measure(in:)`) and placed in priority
order (focus, selected partner, then partners by `sharedWithFocus`), skipping any rect that would
overlap a placed label or another node's disc. The placement is a pure static over positions,
sizes and priorities: two same-height nodes closer than their labels are wide place exactly one
label (the higher-ranked), and no two placed rects intersect over a laid-out fixture. Offer the
same function to `VolumeConnectionGraphView`'s unmarked 10-character cut.

**A6 — #1381.** `.accessibilityLabel(mode.label)` on each Word Cloud segment (the
`AnalyticsChartChrome` shape), plus a scan beside `ToolbarAccessibilityAuditTests` covering every
`.pickerStyle(.segmented)` picker whose segments are `Label(…, systemImage:)` or
`Image(systemName:)`, scoped to the call's balanced braces and trailing modifier chain. It flags
two today (`WordCloudView.swift:1085`, `DocumentTimelineView.swift:104–111`); label both. Owner
reads the result on the Mac in Accessibility Inspector before merge.

### Lane C — copy and counts (after lane A, which edits the same analytics files)

**C1 — #1374 and #1382 together, with #1385's scan.** A `CountCopy.phrase(_:one:many:)` helper
that groups and singularises in one call (new file → xcodegen), routed through every site both
issue bodies list (the 2026-09-23 comment adds `SectionRowLabel`, the Mac subseries row, the Word
Cloud provenance and export caption, and three Corpus Analytics strings). The Research placeholder
names "All Research Documents". Years: wrap the bounds in `String(_:)` at
`PersonAnalyticsView.swift:923–924`, `SeriesProductionDashboard.swift:215` and `:242`, and the two
already-string `startYear` sites so the year scan needs no allowlist; move the caption off the
view into a `nonisolated static` with a test that keeps `lifespanHasNoGroupingSeparator`'s guard
(proves the platform still groups). Two scans designed together: a `defaultValue:` literal placing
`%lld`/`%N$lld`/`\(…)` — and a bare `Text("\(…) noun")` interpolation — directly before a countable
noun fails unless it is one half of a `.one`/`.many` pair, against a **baseline allowlist that may
only shrink** (the issue counts 131 candidate lines in 94 files); and a `defaultValue:`
interpolating a bare identifier ending `year`/`Year`, `lowerBound` or `upperBound` fails unless
wrapped or formatted. Unit-test the helper at 0, 1, 2 and 12,067. Amend every touched block in
`EditableContent.md`.

**C2 — #1380.** The two Mac-only strings say "click" (and `SupportingViews.swift:2126` is checked
against where Sources actually is on the Mac — a Research rail tile, not a toolbar item). Shared
strings get one wording that reads on both platforms where one exists; otherwise an
`#if os(macOS)` branch with **its own key** (the `settings.projects.list.footer.order.mac`
precedent — a shared key with two default values collides). The `hand.tap` glyph is replaced on
the Mac. The scan walks `FRUSExplorer/` tracking conditional compilation line by line (`os(iOS)`
and `canImport(UIKit)` are iOS-only; `os(macOS)`, `!os(iOS)`, `canImport(AppKit)` and ungated
code compile for the Mac; `#else` flips; a file-wide gate counts), reads single-line and `"""`
literals, fails on `\btap(s|ped|ping)?\b` in Mac-compiled text unless the literal also says
"click", and keeps a per-file exception list. On `v2` it must flag every site the issue lists.

### Lane V — Archives Visit

**V1 — #1392.** Recommend the packet-side rule (§4 item 6): strip one trailing period from
`seeding.citation` before appending anything, then end the line with the packet's own period —
one rule for the footnote line, the unnumbered branch, the no-plain-number branch and the
drawn-from " — file" line. The test builds a packet through `TripPacketDataSource` with a real
manifest entry for the fixture volume, so `citation` comes from `HistoryAtStateCitationFormatter`,
and asserts no line contains `"., "` or `". —"` and the footnote line ends in the house form.
Amend the two `archiveVisit.seeding.footnote.*` blocks in `EditableContent.md`.

**V2 — #1366, after the rule is chosen (§4 item 1).** Under the recommended render-time rule:
`projectResearchQuestionSeed` reads the research question of the plan's project and reaches the
builder as the *seed*, `inquiryText` stays the *edit*, and `TripPacketSheet` gets the same seed so
its "Seeded from your project's research question" caption can be true. All four creation sites
go through one factory, `ArchiveVisitPlan.make(name:activeProject:)`, which attaches `projectIds`
as collections and notes already do — picker-created plans carry none today, so the seed join
would find nothing without it. The factory should *not* copy the question into `inquiryText`
(Project Home does today), or that one path's draft stops following the project while the other
three follow it. Correct whichever comment states the losing rule. Tests: derive a factory-made
plan with an active project and assert `topicSentence.forExport` equals the question, not the
placeholder; a second fixture sets the question after creation and expects the export to follow;
remove the three bare `ArchiveVisitPlan(name:)` calls so no site can bypass the factory.

**V3 — #1377.** A `#if os(macOS)` body for `TripPacketSheet` in the house idiom
(`ArchiveVisitTierSheet` is the model): header row with the title and the existing `optionsMenu`,
a `Divider`, the existing content, then a bottom bar with the two `ShareLink`s leading and Done
with `.keyboardShortcut(.defaultAction)`. The scan: every `.sheet(` presenter that compiles on
macOS (198 `.sheet(` sites in the tree today, before platform gating), the presented type
resolved, failing when that type's Mac-compiled body has a `ToolbarItem` at any placement but
`.confirmationAction`/`.cancellationAction`; it evaluates `#if os(iOS)`/`#else`, matches the
`placement:` argument rather than a text window, and asserts it resolved more than zero types
including `TripPacketSheet`. It will also flag `ChartDataInspectorView` and
`ArchivalAllUnitsSheet`; the owner confirms each on a Mac before they are fixed here or split out.

**V4 — #1378.** Measure the width at which every toolbar item shows with a long plan name, set
`defaultSize` at or above it (the Collections window this one copies opens at 1180 × 760), cap the
plan-picker label with `.lineLimit(1)` and tail truncation, and record the measured width in the
PR. Manual: `Docs/macOS-User-Manual.md:926` and the screenshot slot at `:928` name Export packet
as its own toolbar button (§4 item 7). Owner captures the `:928` slot once V3 and V4 are in.

### Lane S — Source Explorer

**S1 — #1352.** Both literals in `NARACatalogLookupView.swift` point at `"finding-documents"`
after checking that page's sections carry the NARA Lookup guidance; a test asserts every
`pageId:` literal passed to the guide matches an `EducationPage.all` id, leaving the deliberate
fallback-to-0 for a plain "open the guide".

**S2 — #1391, after T1.** One shared function returning the number to show and the title to
show: when the header begins with the document's own number and a period, the prefix is removed
from the title and the number stays in the column; otherwise both unchanged. Routed through the
four rows (`MacSourceExplorerView.swift:2409`, `SourceExplorerView.swift:2438`,
`CrossReferenceGraphWindowView.swift:366`, `ReferenceListPanel.swift:224`). Unit tests on the
issue's four cases, including `"61.Mr. Trescot…"` with no space after the period so the strip does
not depend on T1's join.

**S3 — #1390.** `citation_index` selected into `ExternalCitation` (both readers) and made part of
`id` — read-side only, no bump. Rows start with the printed footnote ("fn 2 · Lot 66 D 95"), claim
no number when `noteLabel` is nil (a row written before v53), show `rawText` as the secondary line,
and carry "Same lot as the source note" when `lotFileNorm` equals the parsed source note's; the
footer says the *claims* are separate, not the units. Row text in one function both twins call
(new file → xcodegen, or a `SourceExplorer` model file that already exists). Fixture shaped like
d41: one note citing a lot twice, three notes citing the source note's lot in the same words —
every id unique, every row text distinct, the three same-lot rows marked. Note the iOS twin is a
`Form`, where a duplicate id shows as a *missing* row; the capture did not check it.

### Lane K — Collections, storage, history, word cloud

**K1 — #1358.** `Collection.documentCount` (entries with `entryKind == .document`), read by the
iOS list row, the picker (replacing its inline filter) and the three `MacCollectionManagerView`
sites; fix or delete the two `GlobalContextView` sites, which are never presented. The Research
sidebar's distinct-document rule stays separate. Unit test over a fixture with one entry of each
authorable kind plus a second `.document` (`documentCount == 2`); the scan fails on
`documentEntries?.count` under `Collections/` and `ProjectContext/` and asserts it read both
directories. The three non-display sites (`Collection.swift:881` debug print,
`DuplicateRecordCleanup.swift:158–159`) are outside the scan's directories and legitimately count
all entries.

**K2 — #1359.** `iOSContent` titles from the trimmed live `collectionName`, else the localized
"New Collection"/"Untitled Collection". Then either `navigationTitle(_: Binding<String>)` or a
corrected comment at `:806` (§4 item 5). UI test on iPad and iPhone: create, name via the
settings sheet or drill-in, return, assert `app.navigationBars[<name>]`; back out, reopen from
the list, assert again.

**K3 — #1360.** Under the recommended preview route (§4 item 4): the resting row shows a
line-limited `Text` of the block's plain text, which ends in an ellipsis; editing happens in the
focused row or the entry inspector; any scrolling editor that remains (the macOS `NSTextView`)
resets to the top in `textDidEndEditing`. UI test: add a prose block, type a paragraph longer than
the old cap, dismiss the keyboard, assert the row's static text begins with the paragraph's first
words — at the default size and at a large accessibility size.

**K4 — #1356 and #1357 in one PR.** `DownloadedVolumesListView` owns a `removingVolumeIds` set
(inserted when Remove fires, the row drawn with "Removing…" or dropped from `filtered`, cleared
when `onRemove` returns — the Free Up Space sheet's `isRemoving` shape); the hub drops the id from
`indexedVolumeIds` as soon as `pipeline.removeVolume` returns; and the confirmation dialog moves
into `row(_:)`, presented when `pendingRemoval == entry.volumeId`, so the iPad popover anchors to
the row. The Mac twin (`MacAllVolumesSheet`) gets the same in-progress state. The row model leaves
the `private struct` so a unit test can drive it with an `onRemove` suspended on a continuation
(row gone or marked, never "indexed", while suspended; gone after). An iPad UI test swipes a
seeded mid-list row, taps Remove, and asserts `app.popovers.firstMatch` sits directly above or
below that cell's frame (self-skips on iPhone, where the dialog is an action sheet). Also check
whether the pushed list re-renders when the hub's `storageReport` changes; if not, pass it
something observed rather than `let` copies. Check the Free Up Space dialog's anchor in the same
sitting.

**K5 — #1361, after T1.** `recordReadingHistory` stores `documentTitle` when the load produced
one and falls back to `entry.header` only when it did not (the navigation bar's own order); the
History row caption becomes `volumeId · documentId`; optionally, a display-time rule treats a
`displayTitle` equal to the volume's manifest title as absent, so rows already written fall
back without a migration. Tests: load a fixture through `load(volumeURL:)` from an entry whose
header is a volume title, call `recordReadingHistory`, assert the stored `displayTitle` equals
`documentTitle`; a pure test that `HistoryPaneSnapshot.DocumentRow`'s caption includes
`documentId`. Depends on T1 for editorial notes: until their heads are indexed, `documentTitle` is
empty for them and the fallback still stores the opener's label.

**K6 — #1373.** At launch, before any `NLTagger` use in the process, `NLTagger.requestAssets(for:
.english, tagScheme:)` for `.lexicalClass`, `.lemma` and `.nameType` (unmeasured) and at minimum
`NLTagger.availableTagSchemes(for: .word, language: .english)` (measured to restore tagging on the
iOS 27.0 simulator, only when first). Then a canary in `WordCloudKit`: tag one fixed sentence and
require a `.noun`; when it fails, the lens — and Distinctive — report themselves unavailable on
this device instead of computing a zero cloud. Every lens gets an empty state for `terms.isEmpty
&& documentCount > 0`, worded for the case. Tests: `topicsIsSubsetOfAllTerms` also asserts
`!topics.isEmpty` on a sentence with obvious nouns, with the same non-empty check for Actions,
Descriptors and the entity lenses; a view-state test over `WordCloudLens.allCases` that zero
terms from more than zero documents never renders a bare canvas. Owner: run the Topics lens once
on a physical iOS 27 device, which the issue could not measure.

---

## 4. Owner decisions

**Blocking a PR that is otherwise ready**

1. **#1366 — which documented rule.** *Recommend render-time* (option 2): it is what D8 in
   `Research-Trip-Packet-Scope.md` says ("seeded from the project's research question and
   editable, and the exporter reads the edited value"), what both manuals say, and what
   `TripPacketTopicSentence` already models; a reader's edit still wins, so the only draft a later
   project edit can change is one that never said anything of its own. Creation-time seeding
   (option 1) keeps the rule the Derivation comment states, but leaves a question written after
   the plan unreachable and the sheet caption permanently false.
2. **#1371 — data-skip or flatText.** *Recommend data-skip*: no bump, no stale highlights, the
   converter's own three precedents. Cost: a highlight cannot begin on "SUBJECT" or "(1)".
3. **#1370 — where birth and death years live.** Own rollup columns (one more rollup shape, shown
   as "1923–2023" on its own line) or a display-time read of the authority/POCOM entry (no
   schema, one more lookup per row). *Recommend the columns*: the rollup is rebuilt anyway at
   v10, and the People list draws thousands of rows.
4. **#1370 — the seal.** Add it to `PersonIndexRow` (`PersonIndexEntry` already carries
   `authorityId`) or remove the claim from both manuals. *Recommend the row*: the manuals have
   promised it since the seal shipped on the sheet, and the row is where a reader scans.
5. **#1359 — editable title or corrected comment.** *Recommend the corrected comment* and a
   live title only: the name already has one editing surface, and a second in the bar is a
   second place for the two to disagree.
6. **#1392 — locator in the formatter or strip in the packet.** *Recommend the packet-side
   strip*: one rule covers all four line shapes, and `CitationFormatterTests`' pinned terminal
   period stays true for standalone citations.
7. **#1378 — Export packet stays a toolbar button (fix the manual) or joins the ⋯ menu (make
   the manual true).** *Recommend the button and the manual fix*: V4's size and label cap end the
   overflow, and the button is the discoverable form.
8. **#1367 — the research question as a full-width bar subtitle, or a header inside the 340 pt
   list pane.** Decide after B0's probe; the bar form is only right if the bar carries the
   detail level's title, which is what the probe measures.
9. **#1368 — reverse the "no scene activation" pin.** `noSceneActivationYet` was written as a
   deliberate marker. #1368 argues, with the Home Screen drop, that the marker recorded a gap
   rather than a rule. Confirm before W1 starts.
10. **#1360 — self-sizing editor or preview at rest.** *Recommend preview*: the outline is a
    table of contents, and a self-sizing row makes a long block dominate it.
11. **Build 49 timing.** Cut after lane T alone, or hold for lanes A and V as well. The T lane is
    the only one whose cost (one full re-index) argues for shipping together; the rest can follow
    in build 50 without cost.

**Not blocking, but owner-only**

12. Screenshot recaptures: both manuals' chronology captures (after A1 + A3); the macOS packet
    sheet slot at `macOS-User-Manual.md:928` (after V3 + V4); the people-detail captures if the
    seal or the active-years line moves (after T4).
13. `PersonAuthorityIndexGenerator` re-run for #1370's role cut (local inputs), ideally in T4's
    week so it rides the v10 rollup bump.
14. Mac-by-eye checks no test target can make: #1377's sheet, #1378's toolbar at the measured
    width, #1381 in Accessibility Inspector, #1383's hover on a Mac, the two other sheets #1377's
    scan will flag.
15. #1373 on a physical iOS 27 device; #1368 on an iPad in Stage Manager as well as Full Screen
    Apps mode.
16. The C1 allowlist policy: whether the baseline of ~131 count sites may only shrink, or
    whether new count strings are refused outright.

---

## 5. Device verification matrix

| Work | Destinations | Why |
|---|---|---|
| Lane T | iPhone 17 unit runs per PR; one full re-index on a pinned iOS 27 UDID after T4; iPad + Mac by eye for titles, datelines, People rows | only a re-indexed device shows stored strings; the People list is where T4's six changes meet |
| R1, R2 | iPhone 17 (WKWebView harness) + Mac reader by eye | the CSS and the list markup are shared, but the Mac renders in its own `WKWebView` |
| B0–B2 | iPad Pro 13-inch (M5), landscape, ≥ 820 pt; iPhone 17 as the control | two-pane only; the control proves the stack path is untouched |
| B3 | iPad Pro 13-inch, both sidebar and floating-tab-bar representations | the representation persists per install and has no pin |
| B4 | iPhone 17 + iPad Pro 13-inch | the item is iOS-only and both idioms run the same path |
| W1 | one pinned iPad UDID, Full Screen Apps mode, then Stage Manager; A/B against `v2` first | the drop was seen in full-screen windows; the test must fail on `v2` |
| A2 | iPad Pro 13-inch with a fixture index filling 15 rows; Mac wheel-scroll by eye; A/B against `v2` | the page-scroll takeover was seen on both |
| A4, A5, A6 | Mac (hover, Accessibility Inspector); iPad for A5's labels | hover is `#if os(macOS)`; the canvas is shared |
| C1, C2 | Mac + iPhone 17 + iPad | shared strings on three platforms; C2's Mac variants must not leak to iOS |
| V1–V4 | Mac first (all four were seen there), then iPad for the shared sheet | V3's body is Mac-only; V2 and V1 are shared |
| S2, S3 | Mac + iPad (the `Form` twin) | a duplicate id shows as a missing row on iOS |
| K2, K3 | iPad + iPhone 17; K3 also at an AX size | the two layouts reach the name field through different screens |
| K4 | iPad Pro 13-inch (popover) + iPhone 17 (action sheet, self-skip) + Mac twin by eye | the anchor exists only in a regular-width size class |
| K6 | iOS 27.0 simulator (iPad Pro, iPhone 17e) + a physical device | the failure is per-runtime and was measured only on simulators |

All iOS 27 UI-test runs take `-test-timeouts-enabled YES -maximum-test-execution-time-allowance
300`; a suite that measures a screen at rest sets `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`; every
`-only-testing` names a **type**, not a file; every suite that opens a presentation closes it in
`tearDown`. A "green" claim needs a positive signal — a test count or `BUILD SUCCEEDED` — and a
scan that is meant to catch a class is run on `v2` first, where it must fail.

---

## 6. The docs pass

Each PR carries its own docs; the wave ends with one sweep. Specifically:

- **Manuals.** `macOS-User-Manual.md:276` (#1364, no Browse Within on the Mac), `:926` and `:928`
  (#1378, Export packet is a button), both manuals' People paragraphs (#1370, the seal and where
  active years come from). #1369's and #1372's manual sentences are already right once the fixes
  land and need no edit.
- **`Docs/EditableContent.md`.** Every `defaultValue:` this wave rewrites amends its block —
  C1, C2, A4 (#1385), V1, A3 (#1387) at least — in the amendment style PR #1349 set.
- **Screenshots.** Owner recaptures per §4 item 12; the plan changes no `[SCREENSHOT]` slot text
  except where the manual sentence beside it changes.
- **`Planning/DEVELOPMENT-PLAN.md`.** One `## Session 2026-09-DD — <title>` entry per PR, in the
  shape the September entries use.
- **Build 49.** `project.yml` and `project.pbxproj` by hand, `README.md`'s
  `Current build: **49** (version 0.2)`, and a TestFlight note that owns the single re-index and
  names what changes on screen because of it.

---

## 7. Where this plan departs from an issue's own fix

- **#1372:** the issue splits its fix between the index and the view; this plan ships both halves
  in T1 so the issue closes with one PR and the label test covers the `openDocument` header the
  2026-09-23 comment raised.
- **#1385:** the literal and doc-comment fix ride A4 (same file, same graph); only the scan goes
  to C1. The issue proposes a standalone `CodingStandardsAuditTests` change.
- **#1366:** the issue offers two rules and asks for a choice; this plan recommends one (render-
  time) and adds that the factory should stop copying the question into `inquiryText` on the
  Project Home path, which neither option in the issue states.
- **#1373:** the issue puts the warm-up "at launch"; this plan adds why (thirteen tagging files,
  first-scheme failure) and moves the canary into `WordCloudKit` so the generator and the
  Distinctive measure share it.
- **#1363 / #1367:** the issues propose two title mechanisms; this plan makes a device probe
  choose between them before either PR is written, and splits #1363's state memory into its own
  PR because it does not depend on the choice.
- **#1370:** the issue lists six fixes as one; this plan keeps them in one PR (they share the two
  bumps) but marks the generator half as owner-machine work that may lag without costing a bump.
