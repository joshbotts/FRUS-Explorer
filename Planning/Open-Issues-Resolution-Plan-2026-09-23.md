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

**§4's decisions were resolved on 2026-09-23 (amendment below).** Before they were put to the owner,
every premise the recommendations rest on was re-checked against this tree and the issue threads
(no thread records an owner preference). Seven recommendations changed and the rest were refined;
§3's lane designs are amended to match, and the places the check found this plan wrong are
corrected in place and listed in §8. Two changes reach beyond a single lane: **build 48 has not
shipped, so nothing goes to TestFlight until every lane has merged** (one release, one re-index),
and #1370's life years move to the person sheet instead of the rollup.

**Sizes:** XS under an hour · S half a day · M one to two days · L three days or more, tests
included. "Bump" means the PR must move `currentDateIndexVersion` (parse output changed) and/or
`currentPersonRollupVersion` (rollup output changed) in the same commit.

---

## 1. Where the 37 issues stand

| # | Title (short) | Lane | Size | Bump | Decision | Checked here |
|---|---|---|---|---|---|---|
| 1352 | NARA Lookup guide deep-link names a dead page id | S | XS | no | — | issue only |
| 1356 | Removed volume stays on screen, still "indexed" | K | M | no | — | dialog site ✔ |
| 1357 | iPad remove-confirmation popover anchored to the list | K | S | no | — | dialog site ✔ |
| 1358 | Collections list counts headings/prose as documents | K | S | no | — | all 9 `documentEntries?.count` sites ✔ |
| 1359 | Collection editor never titled by name | K | S | no | live title + follow renames (§4.5) | issue only |
| 1360 | Prose row is a fixed-height scrolling editor | K | M | no | capped editor (§4.10) | issue only |
| 1361 | History records the opener's label, never names the document | K | M | no | — | writer site ✔ |
| 1362 | Research two-pane: open category not marked | B | S | no | — | `isTwoPane` branch ✔ |
| 1363 | Browse two-pane: no level title; Back rebuilds the level | B | L | no | title story (measured) | `twoPaneLayout` ✔ |
| 1364 | Browse Within This Scope changes nothing on screen | B | S/M | no | — | menu site ✔; Mac manual claim ✔ |
| 1365 | Topic index door keeps the earlier search | B | S | no | — | `apply` cases ✔ |
| 1366 | Inquiry drafts print the topic placeholder (3 of 4 paths) | V | M | no | creation + refresh (§4.1) | 3 bare inits ✔; D8 ✔ |
| 1367 | "Working on:" subtitle runs 224 pt into the detail pane | B | M | no | bar subtitle (§4.8) | `CorpusView` chrome ✔ |
| 1368 | iPad aux-window Done drops to the Home Screen | W | M/L | no | reverse, W1 widened (§4.9) | marker needle ✔; 6 origin adopters ✔ |
| 1369 | `n="0"` source notes show a "0" marker (9,985 documents) | T | S | **index** | — | `printedLabel` ✔ |
| 1370 | People: lifespans as "Active", 235 reversed ranges, 5,217 debris roles | T | L | **index + rollup** | sheet read; manuals fixed (§4.3–4) | rollup v9 ✔; Kissinger pin ✔; manual claims ✔ |
| 1371 | Reader drops list heads and labels (79,788 documents) | R | M/L | **no under data-skip** | data-skip, hardened (§4.2) | `kVersion` 1.2 ✔ |
| 1372 | Editorial-note heads never indexed (8,467) | T | S | **index** | — | `extractHeader` ✔ |
| 1373 | Topics cloud reads 0 terms on iOS 27 (NLTagger first-scheme) | K | M | no | physical device | gate ✔; no warm-up call ✔ |
| 1374 | "1 volumes"; ungrouped `String(format:)` counts | C | M | no | shrink-only baseline (§4.16) | `HubCopy` ✔ |
| 1375 | Stored titles/datelines gain a space at every markup boundary | T | M | **index** | — | `extractHeader` ✔ |
| 1377 | Mac packet sheet shows only Done | V | M | no | — | toolbar placements ✔ |
| 1378 | Archives Visits window 900×640 overflows; manual names ⋯ menu | V | S | no | button + Mac ⋯ item (§4.7) | manual lines ✔ |
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
| 1392 | "Document 41., footnote 3" | V | S | no | shared strip helper (§4.6) | keys in EditableContent ✔ |

Lanes: **T** TEI/index · **R** reader render · **B** Browse/Research two-pane · **W** iPad windows ·
**A** analytics and chronology · **C** copy and counts · **V** Archives Visit · **S** Source
Explorer · **K** Collections, storage, history, word cloud.

---

## 2. What the review found that the issues do not say

1. **Five issues change parse output, so five PRs carry an index bump, and testers must pay for
   them once.** #1369, #1372, #1375, #1389 and #1370 each move `currentDateIndexVersion`; #1370
   also moves `currentPersonRollupVersion`. The rule is a bump in the same commit as the parse
   change (each PR takes the next number, v55…v58, rollup v10), and the cost lands on the
   developer's own device between PRs. What matters for testers is that **the release is cut only
   after the whole T lane has merged**, so the TestFlight note owns exactly one full re-index —
   the lesson the 2026-09-19 plan recorded for v52/v53. *(Resolved, §4 item 11: build 48 never
   shipped, so the release waits for every lane, not lane T alone.)* The build bump edits
   `README.md` too (`readmeStatesCurrentBuild` pins `Current build: **48** (version 0.2)`).
2. **`IndexingPipeline.extractHeader` is claimed by two issues and read by two more.** #1372
   unwraps the editorial-note wrapper; #1375 replaces the space join. #1391's number-strip and
   #1361's stored title both read its output. One PR owns the function (T1 below), and #1391's
   strip must not depend on the join — the issue already says so, with the `61.<lb/>Mr. Trescot`
   case.
3. **#1371 need not join the bump cluster, and should not.** `ASTToRenderNodeConverter.kVersion`
   is `"1.2"` and its own history records three occasions (#659, #985, #1323) where it was
   deliberately *not* bumped because `flatText` stayed byte-identical. *(Corrected: none of the
   three rendered new visible text under `data-skip`; they justify "no bump when flatText is
   unchanged". The precedents for visible `data-skip` text are the serializer's footnote-marker
   label, broken-ref dagger and classification chip. And `flatText` stays unchanged because the
   Swift walkers ignore the new fields — `data-skip` is read only by the JS offset engine and the
   export highlighter.)* The same route here keeps `body_hash` — the highlight coordinate space —
   unchanged for the 79,788 documents that gain headings and labels. The flatText route would
   stale every existing highlight in them. Data-skip, hardened, was chosen (§4 item 2); it is the
   only thing that keeps #1371 out of lane T.
4. **#1363 and #1367 are one fault, and their proposed title fixes conflict.** Both come from
   `twoPaneLayout` putting both panes under one `NavigationStack` while the list pane's
   `CorpusView` sets the bar's title, display mode and subtitle. #1367 wants `CorpusView` to stop
   writing chrome in the two-pane so the detail level's `navigationTitle` lands on the bar (the
   F-2 design's stated intent, §7.3); #1363 wants a header drawn inside the detail pane (the F-2
   design's stated *fallback*). Neither issue measured which title wins once `CorpusView` stops.
   A one-hour device probe decides it before either PR is written (B0 below). *(Resolved, §4 item
   8: the research question is a bar subtitle whichever title wins, so B0 now decides only the
   title mechanism and where the subtitle attaches.)* The state half of
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
    regeneration moves rollup outcomes and needs a rollup bump. T4 already bumps the rollup, so
    the regeneration should ride T4 if the owner can run it that week; otherwise it waits for the
    next rollup bump rather than costing one of its own.

---

## 3. Lanes and sequence

```
T (index):   T1 #1375+#1372 (v55) → T2 #1389 (v56) → T3 #1369 (v57) → T4 #1370 (v58, rollup v10)
R (reader):  R1 #1386 ; R2 #1371                                (independent)
B (browse):  B0 probe → B1 #1367+#1363-title → B2 #1363-state ; B3 #1362 ; B4 #1364 ; B5 #1365
W (windows): W1 #1368
A (charts):  A1 #1388 → A2 #1379 → A3 #1387 ; A4 #1383+#1385 → A5 #1384 ; A6 #1381
C (copy):    C1 #1374+#1382 (+#1385 scan) → C2 #1380            (C after A, same files)
V (visits):  V1 #1392 → V2 #1366 → V3 #1377 → V4 #1378
S (sources): S1 #1352 ; S2 #1391 → S3 #1390                     (S2 after T1)
K (misc):    K1 #1358 ; K2 #1359 ; K3 #1360 ; K4 #1356+#1357 ; K5 #1361 (after T1) ; K6 #1373
```

Lanes are independent of each other except where marked. Within a lane the order is by shared
files. **The release waits for every lane** (§4 item 11: build 48 never shipped), so lane T is the
critical path only because its four PRs are serial — each takes the next index version.

### Lane T — TEI and index (the serial critical path)

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
decisions (§4 items 3 and 4, both resolved). Six parts: (1) life years leave
`start_year`/`end_year` — `IndexingPipeline.swift:1059–1060` stops taking `auth?.b`/`auth?.d` —
and move to the **person sheet, read at display time**: one testable function takes the
authority's year first and fills a gap from the POCOM career (Kissinger's death year, 2023, is
only in POCOM; the two sources disagree on exactly two people, Byrnes and Deming, and the
authority wins), and its line replaces or promotes the Career footer's `lifespanText`
(`PersonIndexView.swift:600`) so the sheet shows one lifespan, not two. The 18 people with
authority years and no POCOM career — 13 of them presidents — gain a lifespan they have no line
for today. No rollup column, no row change; `ProvenanceMountTests.swift:255–268`'s rule that
`roleEraSubtitle` reads no authority or POCOM data becomes true again rather than being broken
on purpose. `IndexingPipelineTests.swift:4455` is rewritten to assert an authority-covered start
year is *not* the birth year; (2) the mention-era query joins `document_cache` and excludes front matter; (3)
`extractRoleAndYears` reads the cue word ("until/to/through/till" end, "from/after/since" start),
parses `Month D, YYYY–Month D, YYYY`, and removes a year span from the role only when it is a
trailing `, YYYY(–YYYY)` or ` (YYYY–YYYY)` clause; (4) a member's span is min/max over every year
it carries, so it cannot invert; (5) **the manuals are corrected, not the row**: the
reconciled-identity seal moves from the People-list paragraph (`iOS-User-Manual.md:427`,
`macOS-User-Manual.md:292`) into the sheet paragraph, where the iOS caption at `:433` already
puts it, and the active-years sentence says where active years come from; the row stays
unbadged, as `ProvenanceMountTests.swift:241–268` records was deliberate, and any row marker is
left to #234's planned "Derived" marker; (6) the register-role cut in the generator.
Tests: a `TEIParserTests` table of real persons-list shapes asserting no role ends on a month,
day or preposition, contains `, ;`, ` ;` or `, –`, or loses a parenthesis; and a rollup property
test over the pipeline test database (no `start_year > end_year`, no authority birth year as a
start unless a list or mention says so). Interaction with #234: this PR resets the `persons`
table's parse; whatever #234 decides builds on the corrected table, not the current one.

**The release** is cut after every lane has merged (§4 item 11), not after T4. Build 48 was never
shipped; whether the release goes out as 48 or bumps to 49 depends on whether 48 was ever uploaded
to App Store Connect. If it bumps: `project.yml` and `project.pbxproj` by hand (never `xcodegen`)
and `README.md`. Either way: run `./Scripts/fetch-llama-dsyms.sh` before archiving (the #1350
gate fails an archive without the cache), and rewrite **both** TestFlight files —
`Docs/TestFlight-Instructions-ios.md` and `-mac.md` still say "What's New Since Build 46" — to
say every device re-indexes once and why (titles, datelines, section titles, source-note markers,
people), and to carry the three fixes already on `v2` since build 48 (#1354, #1376, #1393).

### Lane R — reader render (no bump)

**R1 — #1386.** One CSS rule, `.fn-list-item > * { text-indent: 0; }`, and the test that
would have caught it: lift `OffsetEngineTestHarness` (`FRUSOffsetEngineTests.swift:376`,
private today) into a shared helper, load `HTMLTemplate.build` for a model with the
`sourceWithMarking` fixture and a footnote holding a `.listBlock`, and assert every non-inline
descendant of `.fn-list-item` computes `text-indent: 0px` (visiting more than zero elements,
including the chip and a list item) and that the chip's text starts inside its border box. Run it
on `v2` first; it must fail there.

**R2 — #1371, data-skip route, hardened (§4 item 2).** `.listBlock` gains an optional heading and
per-item labels (or a dedicated heading node emitted before the block — never `.heading`, which
serialises as the document `<h2>`, and never `.attachmentHeading`, whose text the converter's
`flatText` includes at `:196`). The converter walks
`.list` children in document order: `.head` becomes the heading, a `.unknown("label")` is held
and attached to the next `.listItem` (exact for 449,657 of 449,659 labels by the issue's count),
and `.pageBreak`, `.lineBreak`, `.footnote` and the rest are kept beside the neighbouring item —
the two d93 footnotes come back with their bodies. The serializer prints the heading above the
list and the label where the bullet goes with `data-skip="1"`, so `flatText` and `kVersion` are
untouched; PDF and DOCX print the label instead of `"• "`. **Hardening, the decision's point:** a
selection that starts *or ends* inside a skipped node maps to −1 (`frus-selection.js:50–56`), so
both twins fall to `atFootnote: true` and disable Highlight and Excerpt — and a drag from the left
edge of a numbered item commonly starts on its label. Give the heading and label
`user-select: none` (CSS only, scoped to the new classes) or snap such an endpoint to the nearest
mapped character in `frus-selection.js` and its `kSelectionJS` twin (parity test at
`FRUSOffsetEngineTests.swift:491`); measure which one yields a highlightable selection for a drag
that starts on "(1)" and ship that one. Snapping is global to every skipped node, including the
footnote marker, so prefer the CSS if it measures clean. Highlight and excerpt passages still omit
the numbering (`CollectionExcerpts.swift:22–25`); the label stays findable, copyable and spoken,
since nothing hides `data-skip` text from WebKit find, the pasteboard or VoiceOver. Walk all
**eight** `.listBlock` sites — converter `:189`, `FRUSRenderNode` `:331` and `:486`,
`FRUSURLSchemeHandler` `:324`, `CollectionContentResolver` `:1635`, serializer `:647`, PDF
`:1001`, DOCX `:953` — and note that the `default: break` arms (`FRUSRenderNode` `:350`, `:521`;
URL scheme handler `:329`) will silently swallow a new node the compiler does not force. Update the
doc comment at `FRUSASTNode.swift:247`. **94 documents** put `lb`/`closer`/`salute`/`gap`
directly inside a list (measured at corpus `550a8c5c5`: 77 `lb`, 8 closers and 4 salutes with
text); restoring those as ordinary text moves their `body_hash`, so they are emitted under
`data-skip` too or the 94 are named in the PR as the stale set. Tests: d84's real shapes
(`<list type="subject"><head>SUBJECT</head>`, and the labelled list with a `<pb/>` between items)
reach the HTML in order and `renderingVersion` does not change; **a Swift/JS parity case in
`FRUSOffsetEngineTests` on those shapes** — `renderingVersion` hashes only the converter's
`flatText`, so stray DOM text outside the skip span would misalign highlights while it stays
unchanged, and only the parity harness sees that (it lives in the same file, so this needs no R1
lift); a drag starting on a label yields offsets; and the class test — one `<list>` containing
every direct-child element the corpus uses (item, label, head, pb, lb, closer, gap, salute, note,
figure) loses no text and no footnote.

### Lane B — Browse and Research two-pane (iPad)

**B0 — the probe, not a PR.** On an iPad Pro 13-inch at two-pane width, suppress `CorpusView`'s
`.navigationTitle`, `.navigationBarTitleDisplayMode(.large)` and `.workingOnSubtitle` when the
two-pane is active, and record (a) which title the bar shows at each depth — the level's, or the
outer container's inline "FRUS Explorer" — and (b) what the People/Topics/Collections
`.searchable` fields do to the bar's title and subtitle after activate-and-cancel (#1367's
"observed but not explained" paragraph), (c) whether the bar subtitle attaches best on the level
or on the two-pane's `HStack`/empty-path placeholder, and (d) whether a long (~98-character)
research question truncates acceptably in an inline bar carrying the three persistent toolbar
items plus the level's own. The repository already predicts (a) — an inner `navigationTitle`
beats the outer one (the Browse root reads "FRUS Corpus" under an outer "FRUS Explorer",
`TabBarNavigator.swift:77`), and in the Research two-pane the list sibling's title beats the
detail's (`ResearchReadingStaysInTabTests.swift:260–261`) — but nothing measures a silent
`CorpusView`, so the probe still runs. People sets `.large` (`PersonIndexView.swift:132`), so its
title may again start at the list pane's leading edge. Half a day, written up as a comment on #1367.

**B1 — #1367 with #1363's title half.** The research question is **the full-width bar's
subtitle** (§4 item 8, resolved): applied once, the `!listPaneShown` gate dropped, attached where
B0(c) says. That is the house idiom on regular-width iPad already (Search, the in-place reader,
the stack path — `ProjectPickerMenu.swift:145–148`), it needs no second path when a document under
1100 pt drops the list pane, and it does not move when the width crosses 820 pt. For the title: if
the probe shows the level's title landing on the bar, `CorpusView` stops writing chrome in the
two-pane (a new `showsNavigationChrome` flag; F-2 §7.3 names that flag, but as a toolbar-overflow
fallback passed to the levels, so this reuses the name for another purpose). If the probe shows
the outer title winning, ship F-2's fallback instead: the detail pane's Back row
becomes a header carrying `breadcrumbLabel` with the header trait, shown at every depth. Either
way, correct the comments at `CorpusView.swift:72` and `BrowserView.swift:754–760`, and add an iPad
scenario to `UIObstructionTests` (skips below the 820 pt gate) asserting the `Working on:` element
lies inside the navigation bar, and that the bar's title is the level's, not "FRUS
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
sheet presentations are unchanged. The action resolves the launching window against
`UIApplication.shared.openSessions` (not `liveSceneIDs`, which `onDisappear` may clear while the
session survives), falling back to any live main window and, **when none is left** (closed in
Stage Manager), requesting a new main scene rather than dropping to the Home Screen; it asks
iPadOS to activate that session (`UIApplication.shared.activateSceneSession(for:)`), then
dismisses. Enablers: `MainTabView` registers its `UISceneSession` beside the `SceneID` it already
registers (a small `UIViewRepresentable` reading `window?.windowScene?.session`); the six
analytics scenes record their launcher in a **close-only environment key**, *not* by applying
`.auxWindowOrigin` — that modifier republishes the launcher's borrowed `\.sceneID`, and
`ArchivalAnalyticsView.swift:530` (`handoff.target == (sceneID ?? .anyWindow)`) would then claim
scope hand-offs addressed to the launcher, racing `MainTabView.consumePendingArchivalScope`; it
would also retarget a dozen analytics producers from `nil` to the launcher, a routing change this
PR does not own. Adopters (§4 item 9, widened): the nine Done buttons, the `CollectionDetailView`
citing-volume path, **and the six hand-off-then-dismiss exits** that close the window and hand
content to a backgrounded launcher — `SourceExplorerView.swift:2381`, `ChronologyView.swift:204`
and `:1206`, `AnalyticsView.swift:1200`, `WordCloudView.swift:1463`/`:1592`/`:1625` — which front
the hand-off's target before dismissing. Invert `noSceneActivationYet` into a pin that activation
exists at exactly one site (widen its needle to `activateSceneSession`; the current needle does not
match it and would keep passing). Correct the stale comments at `AppState.swift:2617` and
`:3126–3127` and `FRUSExplorerApp.swift:4285`/`:4340–4341`. The UI test — for each Analysis Tools
surface: open, tap Done, assert `.runningForeground` and the main tab bar exist, plus one hand-off
exit (Chronology ▸ Search in this range) — is run against `v2` on one pinned iPad UDID first and
must fail there; record that simulator's windowing mode (the defect was seen in Full Screen Apps
mode; Stage Manager was not tested). Unverified at runtime and owed to the device run: activation
being asynchronous against an immediate dismiss (a possible Home Screen flash), and whether a
session the system disconnected can be activated.

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
`%lld`/`%N$lld`/`\(…)` — and a bare `Text("\(…) noun")` interpolation, including a ternary inside
`Text` (the Mac subseries row, `MacCorpusBrowserWindow.swift:419–421`) — directly before a
countable noun fails unless it goes through `CountCopy` (the `.one`/`.many` exemption is
restricted to the `%@` + `.formatted()` form, since a paired `%lld` still prints "1000 volumes"
ungrouped), against a **shrink-only baseline** (§4 item 16, resolved). Size it honestly: the
issue's "131" counts `%lld` lines only (the "94 files" belongs to its 332 `%lld` lines, not to the
131), and this scan also matches `\(…)` and bare `Text`, so the baseline is **about 190–270 lines
in about 85–95 files** depending on the noun list — fix the sites the issues name, list the rest.
Entries are keyed by **file plus string key** (never line number), a stale entry (listed but no
longer flagged) fails, and a pinned entry-count ceiling stops a PR adding one; a new count string
is refused outright. The second scan: a `defaultValue:` interpolating a bare identifier ending
`year`/`Year`, `lowerBound` or `upperBound` fails unless wrapped or formatted (measured to find
exactly the five sites above, so it needs no allowlist). Unit-test the helper at 0, 1, 2 and
12,067. Amend every touched block in `EditableContent.md`.

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

**V1 — #1392, a shared strip helper (§4 item 6, resolved).** One helper beside the citation
formatter returns a citation without its terminal period, so each caller adds its own
punctuation. The packet uses it for the footnote line, the unnumbered branch, the
no-plain-number branch and the drawn-from " — file" line (`TripPacketExporter.swift:264–265`,
`:858–864`), each line ending in the packet's own period. **Collections "See also:" uses it
too**: it joins formatter citations with `"; "` and prints "…Document 3.; …Document 7." today
(`PDFCollectionExporter.swift:737`, `DocxCollectionExporter.swift:651`,
`CollectionItemHTMLRenderer.swift:333–335`), and its contract fixture passes one hand-written
citation (`CollectionTests.swift:1786`), so nothing sees it. Stripping is safe: History at State
output always ends in "Document N." or ")." and the `volumeId/documentId` fallback has no period.
The reason this beats a formatter locator is the " — file" line (a file designation is not a
locator, so it would still need the strip) and the snapshot rule at `TripPacketModel.swift:102–103`
— not `CitationFormatterTests`' pinned period, which an optional locator would leave intact. The
test builds a packet through `TripPacketDataSource` with a real manifest entry for the fixture
volume, so `citation` comes from `HistoryAtStateCitationFormatter` (it spells "Washington, D.C.",
not the issue's "Washington"; the fixture id `frus1952-54v01` is not a manifest id — use `p1`),
and asserts on the **join**: no `"., footnote"`, no `". — file"`, no `".; "`, and the footnote
line ends in the house form. A bare `!contains("., ")` fails on real data: five manifest volumes
print "Sanford, Jr., and" in their editor list. A See-also case drives two real formatter
citations through each exporter. Amend the two `archiveVisit.seeding.footnote.*` blocks in
`EditableContent.md`. Out of scope, filed separately: document ids that are not `d`+integer (949
of 314,570, e.g. `d373a`) lose their number from the citation entirely, in both
`TripPacketBuilder.swift:424–426` and `CollectionContentResolver.swift:977–979`/`:1220–1222`.

**V2 — #1366, seeded at creation with an explicit refresh (§4 item 1, resolved).** The rule is
the editor's own — "an explicit re-seed, never a live mirror" (`ArchiveVisitEditorView.swift:422`,
`:1305`). All four creation sites go through one factory, `ArchiveVisitPlan.make(name:activeProject:)`,
which attaches `projectIds` as collections and notes already do **and copies the project's
research question into `inquiryText`**, as Project Home does today — so the field shows exactly
what exports, and the draft survives the project's deletion or merge. Remove the three bare
`ArchiveVisitPlan(name:)` calls (`ArchiveVisitListView.swift:82`,
`MacArchiveVisitManagerView.swift:136`, `PlanPickerSheet.swift:275`) so no site can bypass it;
`duplicate()` keeps its own init because it copies both fields. **Re-seed from Project**
(`ArchiveVisitEditorView.swift:421`, `plan.projectIds.first`) also offers the project's *current*
question, so a question written after the plan is one explicit tap away; it asks before replacing
a draft the reader has edited. The sheet's "Seeded from your project's research question" caption
(`TripPacketSheet.swift:353–355`) is unreachable today — the only construction passes
`researchQuestion: nil` (`ArchiveVisitEditorView.swift:209`) — so pass the plan's project question
and show the caption only while `inquiryText` still equals it. Rewrite **both** comments that state
a rule: the model's (`ArchiveVisitPlan.swift:74–75`, "falls back to the active project's research
question at render time", which no code does) and the derivation's
(`ArchiveVisitDerivation.swift:169–173`), and retire the always-nil `projectResearchQuestionSeed`
or document it as the creation-time copy. **Side effect to state in the PR:** Project Home's Plan a
Visit is create-or-open on the most recently modified plan whose `projectIds` contain the project
(`ProjectHomeView.swift:137`, `:398–400`); once picker-created plans carry the active project, it
may open one of them instead of creating a plan seeded from the project's engaged documents, and
Re-seed from Project appears on those plans. Tests: a factory-made plan with an active project
exports the question, not the placeholder; with no active project it exports the placeholder and
carries no `projectIds`; Re-seed after the question changes offers the new question and does not
overwrite an edited draft without confirmation.

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
PR. The window's `minWidth` stays 640 (`MacArchiveVisitManagerView.swift:76`) and a saved frame
may not take a new `defaultSize`, so the toolbar can still overflow; hence §4 item 7, resolved:
**keep the Export packet button and add a macOS-only Export packet item to the ⋯ menu**
(`moreMenuItems`, `ArchiveVisitEditorView.swift:396–439`, behind `#if os(macOS)` on the Rename
precedent at `:397–407` — ungated it would appear twice on iPhone, whose consolidated menu already
lists Export first). The button is icon-only and has no tooltip; give it `.help`, as Collections'
Export… has (`MacCollectionManagerView.swift:1381`). The manual sentence at
`Docs/macOS-User-Manual.md:930` then becomes true as written and needs no edit; the screenshot at
`:932` was filled by #1355 and its caption is already correct. The owner recaptures
`screenshots/macos/trip-packet.png` once V3 and V4 are in.

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

**K2 — #1359, a live title that follows renames (§4 item 5, resolved).** `iOSContent` titles
from the saved `collection.name` (trimmed), else the localized "New Collection"/"Untitled
Collection" — the precedent is `CollectionEntryInspector.swift:207–214`. The editor also
**follows a rename made elsewhere**: add `collection.name` to `FrontMatterModelSync`
(`CollectionEditorView.swift:2021–2038`, three flags today) the way the Mac does
(`MacCollectionManagerView.swift:719–726`); without it, a rename arriving by CloudKit or from a
second iPad scene is overwritten by the next `saveLive()`, which any edit to the name, note,
subtitle, author or flags triggers. Delete the `:806` parenthetical ("The canvas also edits the
name via the toolbar title"): it records a Composer v2 prototype intent that was never built, and
the PR says so. On the Mac, localize and trim the `:710` title. UI test on iPad and iPhone:
create, name via the settings sheet or drill-in, return, assert `app.navigationBars[<name>]`;
back out, reopen from the list, assert again. Unit test: a model-side rename reaches the editor's
field state.

**K3 — #1360, a height-capped editor (§4 item 10, resolved).** Keep the same text view. At rest it
turns scrolling off, sizes to its content and caps at *N* lines with a trailing ellipsis
(`isScrollEnabled = false` + `sizeThatFits`, `textContainer.maximumNumberOfLines` +
`.byTruncatingTail`; `NSTextContainer` has the same two properties on the Mac); the cap lifts when
editing begins and returns when it ends. A tap goes straight to the caret, formatting stays
visible, and no new edit surface or focus plumbing is needed — the plan's earlier "edit in the
entry inspector" did not exist (`CollectionEntryInspector` has document and heading variants only,
and the Mac excludes prose on purpose, `MacCollectionManagerView.swift:1391–1397`). Make it an
opt-in flag on the shared `RichTextEditor`, which also backs both Introductions and research notes
(`CollectionEditorView.swift:1090–1094`, `MacCollectionManagerView.swift:934–938`,
`ResearchNoteEditorView.swift:219–225`); decide in the PR whether the Introductions adopt it,
since they have the same clipping. **Spike first (under an hour):** tail truncation in an
*editable* TextKit 2 view is unmeasured, and touching `layoutManager` falls back to TextKit 1; if
the spike fails, fall back to a line-limited preview on the `CollectionExcerptRow` precedent
(`CollectionEntryRows.swift:485–486`, with a full-text `accessibilityLabel`) plus tap-to-edit.
Either way the scrolling editor resets to the top when editing ends. UI test: add a prose block,
type a paragraph longer than the old cap, dismiss the keyboard, assert the row's text begins with
the paragraph's first words — at the default size and at a large accessibility size.

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

## 4. Owner decisions — resolved 2026-09-23

Every blocking decision was put to the owner after its premises were re-checked against this tree
and the issue threads (none of the threads records a preference). The owner took the recommended
option on eleven of the twelve; on release timing the owner set the rule instead (item 11). Seven
positions changed from the ones this section first carried; the change and its reason are noted
beside each. §3's lane designs are amended to match.

**Decided**

1. **#1366 — seeded at creation, with an explicit refresh.** *Changed from render-time.* D8 and
   both manuals are timing-neutral, and the manuals' one timed sentence (iOS `:786`, Mac `:603`)
   describes creation; the editor's own rule is "an explicit re-seed, never a live mirror"
   (`ArchiveVisitEditorView.swift:422`). Render-time would have left the field blank while the
   export printed the question, left existing Project Home plans frozen, and printed the
   placeholder once a project was merged or deleted. V2 carries the design.
2. **#1371 — data-skip, hardened.** *Refined.* The stated cost was understated: a selection that
   starts *or ends* on a label maps to −1 and loses Highlight and Excerpt, and quoted passages
   omit the numbering. R2 adds `user-select: none` or endpoint snapping (measured), and a Swift/JS
   parity test, because "`renderingVersion` unchanged" cannot see DOM drift.
3. **#1370 — life years on the person sheet, read at display time.** *Changed from rollup
   columns.* The list is lazy, the authority lookup is a hash the sheet already makes, the code
   chose a display-time read over rollup columns once before (`PersonIndexView.swift:461–465`),
   and authority-only columns would miss POCOM's 76 gap-fills (Kissinger would read "born 1923").
   T4 carries the design.
4. **#1370 — the seal: fix the manuals, not the row.** *Changed from the row.* A row seal would
   mark ~71% of rows, and `ProvenanceMountTests` records the row as deliberately unbadged. The
   claim moves to the sheet paragraph; a row marker is left to #234.
5. **#1359 — a live title that follows renames.** *Refined.* The stated reason ("a second place
   for the two to disagree") was wrong — a Binding to the same `@State` cannot diverge. The real
   divergence is an existing bug: the iOS editor overwrites a rename made elsewhere. K2 fixes it.
6. **#1392 — a shared strip helper.** *Refined from a packet-only strip.* Collections "See also:"
   has the same bug ("Document 3.; …"). V1 carries the design.
7. **#1378 — keep the button and add a macOS-only ⋯ item.** *Changed from button + manual fix.*
   `minWidth` 640 is below the fit width, so the button can still overflow; the ⋯ item keeps it
   reachable and makes the manual at `:930` true as written. V4 carries the design.
8. **#1367 — the research question is the full-width bar's subtitle, decided now.** *Changed from
   "after B0".* It works whichever title wins, it is the house idiom on regular-width iPad, and a
   list-pane header would move across the 820 pt gate and need a second path when a document
   drops the list pane. B0 still decides the title mechanism and the attach point.
9. **#1368 — reverse the pin, and widen W1.** *Refined.* The pin calls itself "a marker, not an
   endorsement". W1 as first designed missed six hand-off-then-dismiss exits, and its
   `.auxWindowOrigin` enabler would have raced Archival Analytics against the main window; it now
   uses a close-only key and requests a new main scene when none is left.
10. **#1360 — a height-capped editor at rest.** *Changed from a preview.* The preview's edit path
    did not exist: no inspector edits prose (the Mac excludes it on purpose) and the app has no
    focus plumbing. A one-hour spike proves the cap first; the preview is the fallback.
11. **Release timing — after every lane.** *Changed.* Build 48 has not shipped; the owner will
    finish this plan before releasing on TestFlight. One release, one re-index. (The check had
    proposed cutting a build now for the three fixes already on `v2`; moot.)
16. **C1 allowlist — shrink-only.** *Clarified.* The baseline is about 190–270 lines, not 131;
    entries keyed by file plus string key, stale entries fail, a count ceiling stops additions,
    and new count strings are refused. C1 carries the design.

**Owner-only, not decisions**

12. Screenshot recaptures: both manuals' chronology captures (after A1 + A3); the macOS packet
    sheet, `screenshots/macos/trip-packet.png` at `macOS-User-Manual.md:932` (after V3 + V4); the
    people-detail captures **and both `people-list.png` captures** (iPad and Mac) after T4 — the
    list captures show text T4 removes ("President of Ghana until July 5", "until August 29, ;
    thereafter", "Acheson … 1893–1971"), so they need redoing whatever the seal decision.
13. `PersonAuthorityIndexGenerator` re-run for #1370's role cut (local inputs), ideally in T4's
    week so it rides the v10 rollup bump.
14. Mac-by-eye checks no test target can make: #1377's sheet, #1378's toolbar at the measured
    width, #1381 in Accessibility Inspector, #1383's hover on a Mac, the two other sheets #1377's
    scan will flag.
15. #1373 on a physical iOS 27 device; #1368 on an iPad in Stage Manager as well as Full Screen
    Apps mode.

---

## 5. Device verification matrix

| Work | Destinations | Why |
|---|---|---|
| Lane T | iPhone 17 unit runs per PR; one full re-index on a pinned iOS 27 UDID after T4 (and again before the release); iPad + Mac by eye for titles, datelines, People rows | only a re-indexed device shows stored strings; the People list is where T4's six changes meet |
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

- **Manuals.** `macOS-User-Manual.md:276` (#1364, no Browse Within on the Mac); both manuals'
  People paragraphs (#1370: the seal moves from the list paragraph, `iOS :427` / `macOS :292`, to
  the sheet paragraph, and the active-years sentence says where active years come from); the
  prose-row sentences if K3 falls back to the preview (`iOS :860`, `macOS :692`). #1378 needs **no**
  manual edit: the ⋯ item makes `macOS-User-Manual.md:930` true as written. #1369's and #1372's
  manual sentences are already right once the fixes land and need no edit.
- **`Docs/EditableContent.md`.** Every `defaultValue:` this wave rewrites amends its block —
  C1, C2, A4 (#1385), V1, A3 (#1387) at least — in the amendment style PR #1349 set.
- **Screenshots.** Owner recaptures per §4 item 12; the plan changes no `[SCREENSHOT]` slot text
  except where the manual sentence beside it changes.
- **`Planning/DEVELOPMENT-PLAN.md`.** One `## Session 2026-09-DD — <title>` entry per PR, in the
  shape the September entries use.
- **The release** (after every lane, §4 item 11). If the build number moves, `project.yml` and
  `project.pbxproj` by hand and `README.md`'s `Current build:` line; `./Scripts/fetch-llama-dsyms.sh`
  before any archive; and **both** TestFlight files rewritten (they still say "What's New Since
  Build 46") to own the single re-index, name what changes on screen because of it, and carry
  #1354, #1376 and #1393, which are already on `v2`.

---

## 7. Where this plan departs from an issue's own fix

- **#1372:** the issue splits its fix between the index and the view; this plan ships both halves
  in T1 so the issue closes with one PR and the label test covers the `openDocument` header the
  2026-09-23 comment raised.
- **#1385:** the literal and doc-comment fix ride A4 (same file, same graph); only the scan goes
  to C1. The issue proposes a standalone `CodingStandardsAuditTests` change.
- **#1366:** the issue offers two rules and asks for a choice; the owner chose a third —
  creation-time seeding on every path (the issue's option 1) plus an explicit refresh through Re-seed
  from Project, which the issue does not offer.
- **#1392:** the issue offers a packet strip or a formatter locator; this plan ships the strip as a
  shared helper so Collections "See also:" is fixed by the same rule.
- **#1368:** the issue names the Done buttons and one Collections path; this plan adds six
  hand-off-then-dismiss exits and replaces the `.auxWindowOrigin` enabler with a close-only key.
- **#1360:** the issue offers a self-sizing editor or a preview; this plan ships a height-capped
  editor, with the preview as the fallback if the spike fails.
- **#1378:** the issue says "pick one" of button-plus-manual or ⋯ menu; this plan ships both the
  button and a macOS-only ⋯ item.
- **#1373:** the issue puts the warm-up "at launch"; this plan adds why (thirteen tagging files,
  first-scheme failure) and moves the canary into `WordCloudKit` so the generator and the
  Distinctive measure share it.
- **#1363 / #1367:** the issues propose two title mechanisms; this plan makes a device probe
  choose between them before either PR is written, fixes the research question as the bar
  subtitle regardless, and splits #1363's state memory into its own PR because it does not depend
  on the choice.
- **#1370:** the issue lists six fixes as one; this plan keeps them in one PR (they share the two
  bumps) but marks the generator half as owner-machine work that may lag without costing a bump,
  reads life years on the sheet rather than from the rollup, and fixes the manuals rather than the
  row.

---

## 8. What the 2026-09-23 check found wrong in this plan

Corrected in place above; listed here so a reader of the first version knows what moved.

- **Stale line numbers.** The Mac manual's Export sentence is at `:930`, not `:926`; the `:928`
  screenshot slot was filled by #1355 (now an image at `:932` whose caption is already correct).
  §1's "manual lines ✔" was checked against the tree before `b5175801`.
- **Cross-references.** K3 cited "§4 item 4" (the seal) for #1360, which is item 10; §2 item 13
  said "T5", which does not exist (the rollup bump is T4).
- **Screenshots.** §4 item 12 missed both `people-list.png` captures.
- **Counts.** C1's "131 candidate lines in 94 files" joined two of the issue's figures; the scan's
  real baseline is ~190–270 lines.
- **R2.** The three converter precedents never rendered visible text under `data-skip`; the "four
  other `.listBlock` switches" are seven; the proposed "`renderingVersion` unchanged" guard cannot
  see DOM drift; the R1 harness lift is not needed for R2's guard; 94 documents put `lb`, closers
  and salutes directly in a list and would change hash if restored as ordinary text.
- **W1.** Missed six window-closing exits; the `.auxWindowOrigin` enabler would have created an
  Archival scope race; the existing needle would not have caught `activateSceneSession`.
- **K3.** "Edit in the entry inspector" named a surface that does not exist for prose.
- **V1.** The proposed `!contains("., ")` guard fails on real manifest text; the stated reason for
  the strip (the pinned period) did not distinguish the options.
- **V2.** Both options silently change Project Home's Plan a Visit create-or-open; the sheet
  caption was unreachable rather than false; both rule-stating comments need rewriting, not one.
- **T4 / #1370.** The pipeline never reads POCOM, so the "1923–2023" line the first version
  promised could not have come from rollup columns filled the way the rollup is filled today.
- **The release steps** named one TestFlight note (there are two, both stale since build 46) and
  omitted the `fetch-llama-dsyms.sh` gate #1350 added.
