# FRUS Explorer iPhone UI — Adversarial Review Against the Fits-in-a-Pocket Bar

**Date:** 2026-08-13 · **Version:** 1.1 — §7 Semantic Analytics addendum added 2026-08-14 · **Status:** review for owner + fix worklist (Claude Code-consumable).
Companion to `../iPad-UI/iPad-UI-Adversarial-Review.md` and `../Mac-UI/Mac-UI-Adversarial-Review.md` (both 2026-08-13); shared defects are cross-referenced.
Figures: `Docs/screenshots/ios/*.png` — annotated versions in `iPhone-UI-Adversarial-Review.html` (self-contained, this folder).

**The bar this review applies, per the owner's brief:** judge the iPhone app as an iPhone app — and be
honest about which of this corpus-analysis suite's features **cannot be satisfactorily handled on a
phone-sized screen**, rather than pretending a compact re-layout settles it. The review therefore has
two products: the defect catalogue (§3) and a feature-by-feature fit verdict (§4) that says plainly
what the phone should own, what it carries with compromises, and what it should stop pretending to
carry. Every claim cites file:line at branch `v2` (tree `29ad7485`, read 2026-08-13).

**Inputs:** the iOS shell and per-tab roots (read for the iPad review: `MainTabView`, `BrowserView`,
`SearchView`, `ResearchView`, `SettingsView`, `CollectionListView`/`CollectionEditorView`,
`DocumentView` + `ResearchRailView`, `OnboardingView`, `FacetPanelView`, `HTMLTemplate`, `FRUSTheme`);
compact-width reads of the analysis surfaces (`ConcordanceView`, `CollocationView`,
`CrossReferenceAnalyticsView`, `CrossReferenceGraphView`, `ChronologyView`,
`PersonCoMentionGraphView`, `AnalyticsView` compact branches); the eight committed iPhone
screenshots; `Planning/Dynamic-Type-Worklist.md`.

---

## 1. Verdict up front

The iPhone app's core loop is genuinely good — better, in one respect, than either sibling: on a
390-pt screen the reader's unbounded CSS accidentally produces the app's only correctly-measured
typography, and reading, searching, and capturing notes on the phone feel right. The failures are
concentrated where desktop-grade analysis was ported to compact width without asking whether it
survives:

1. **The committed screenshots show broken compact layout on the app's own flagship analytics
   sheet.** The iPhone Corpus Analytics capture clips its own search field, title, "View in
   Search" link, y-axis labels, and matched-count footer at both edges — a fixed-width control row
   in a compact sheet, shipped in the manual. (P-1)
2. **Three analysis surfaces do not survive the phone, by their own code's admission.** The
   volume heat matrix encodes cell values "only as opacity plus a tooltip" — and tooltips do not
   exist on iOS; the export comment concedes the counts are "otherwise unreadable." The
   concordance's doc comment says "alignment is the feature" — at compact width its context
   columns hold roughly two words. Cross-Reference Analytics omits its own navigation title on
   iOS because it is "the worst-crowding view." The phone ships these anyway. (P-2, P-3, P-8)
3. **The app already knows the screen is too small and says so obliquely.** iPhone-portrait
   analytics shows a rotate-to-landscape hint (`showsLandscapeHint`); Session 161 records the
   graph sheet's half-height first impression as "the weakest"; the chronology chart draws a
   year of documents as hairline strokes with a color-only legend of six identically-truncated
   volume titles. These are honest patches on a dishonest premise — that every desktop analysis
   belongs on a 390-pt canvas. §4 proposes the honest split instead.

Shared defects from the sibling reviews reproduce here at their worst: double-numbered result rows
whose two-line titles waste half their cap on a repeated number, and archival source notes fused
into titles (iPad F-21 / Mac M-6). Credits are real and listed — the phone-specific engineering
(bottom-sheet rail, toolbar consolidation, boot honesty, Dynamic Type on iOS-primary surfaces) is
careful work.

## 2. What the review confirms is working

- **Reading is the phone's best surface.** The compact width caps the measure naturally
  (~45–55 characters), footnote popovers and person/gloss links work well at touch sizes, and the
  committed `document-view.png` is the strongest screenshot in the set. Edge-tap page-turns are a
  right-sized phone gesture, with a Settings opt-out (Session 154).
- **The rail-as-bottom-sheet was decided, not defaulted.** Owner decision D2 + #404: the iPhone
  rail is user-triggered only, never auto-presented, with medium/large detents and a visible drag
  indicator; `panelVisible` semantics stay truthful across dismiss paths
  (`DocumentView.sheetIdentityChanged`).
- **Toolbar discipline is HIG-literate.** Session 56 collapsed 6–7 document toolbar icons to
  ≤4 + overflow; Session 2026-06-07 removed the nested "··· → More" double-overflow; #219
  deliberately trades the nav title for controls where they cannot fit.
- **Boot honesty** (#753): the Search tab says "Search will be ready in a moment" over a building
  index instead of claiming breakage; `BootPlaceholderView` replaced the false re-onboarding flash
  (M-20).
- **The Dynamic Type program converted the iOS-primary surfaces first** (34 sites + detent-clip
  fixes; `@ScaledMetric` hero glyphs with real code clamps) — the phone is the platform where
  text scaling actually works today.
- **Indexing UX is phone-shaped:** banner → queue banner → completion card priority is reasoned
  (`MainTabView.indexingBanner`), and compact width correctly drops the wide context card
  (`IndexingBannerView:159`).
- **Plus/Max landscape is handled correctly everywhere it matters** — the `userInterfaceIdiom` +
  size-class gates (reader sheet vs. inspector, breadcrumb) were built for exactly that edge.

---

## 3. Findings

**12 findings: High ×3, Medium ×5, Low ×4.**

### A. Compact layout defects

#### P-1 · HIGH — The Corpus Analytics sheet clips its own chrome at both edges

The committed `ios/analytics.png` — the manual's illustration — shows the query field clipped to
"Berlin" flush against the sheet edge, the chart title clipped to `Berlin" — by Year`, "View in
Searc[h]" cut mid-word on the right, the y-axis "Document[s]" and value labels ("1,50", "1,00")
cut, and the matched-count footer clipped at the left margin (Fig 1 ①–④). A fixed-width
control/chart row is overflowing the compact sheet on both sides. The chart itself sits in a
~280 pt band (`AnalyticsView.swift:2018` family) under a stepper-driven year-range row. This is
the app's marquee analysis surface, on its most-used platform, shipping edge-clipped. (§5 PR-1.)

#### P-2 · HIGH — The volume heat matrix is unreadable on touch, by its own code's admission

The 15×15 volume citation matrix encodes each cell's count "only as opacity plus a tooltip"
(`CrossReferenceAnalyticsView.swift:544-545` — the CSV export exists precisely because "these
counts are otherwise unreadable"). Tooltips are `.help(...)` — which iOS never renders — so on
iPhone (and iPad) the matrix is opacity-only: a texture, not a figure. At compact width it is
also a horizontally-scrolled grid wider than the screen. The right compact representation already
exists in the code as the CSV's shape: a ranked source→target pair list. (§5 PR-2; fit table §4.)

#### P-3 · HIGH — The concordance's columns collapse to ~2 words; "alignment is the feature" does not survive

`ConcordanceView`'s own header: "Alignment is the feature. The three columns are fixed-width so
the eye can run down the margins" (`ConcordanceView.swift:23-27`). The layout is one
`lineLimit(1)` monospaced caption line split into thirds (`:94-111`); on a 390-pt screen each
context column gets ~120 pt ≈ 15–18 monospaced characters — two or three words — before
truncation. The repeated-formula scan the view exists for is physically absent at compact width,
and the same header's warning that a concordance "whose columns differ between platforms … cannot
be compared" lands backwards: the phone renders the *same* layout at a width where it stops being
a concordance. (§5 PR-3; fit table §4.)

### B. Compact analysis surfaces that strain

#### P-4 · MEDIUM — The chronology chart is hairline strokes with a color-only, all-identical legend

`ios/chronology.png` (Fig 3): a year of documents renders as 1–2 px vertical strokes on a
0–2 count axis — untappable, unreadable density — under a legend whose six entries all read
"Foreign Relations of the…" with only their color squares distinguishing them (volume titles
share a 40-character prefix by construction; tail truncation guarantees identical labels). Day
headers repeat the shared pluralization bug: "**1 volumes** · 1 subseries." The list below the
chart is good; the chart above it says nothing a phone reader can use. (§5 PR-4.)

#### P-5 · MEDIUM — Result rows double-number and leak source notes — worst on the smallest screen (shared defect)

iPad F-21 / Mac M-6 reproduce on iPhone at higher cost: "134. **134.** Memorandum From the
President's Assistant…" spends the two-line title cap's first line on a repeated number, and
"…Source: Carter Library, National S…" (Fig 2 ①②) fuses archival provenance into the title's
truncation budget. On a 390-pt row every wasted character is visible. One indexing fix + a row
prefix guard serves all three platforms. (§5 PR-5.)

#### P-6 · MEDIUM — Research mode covers the document it researches

On iPhone the Research rail is a `.medium`/`.large` bottom sheet over the reader
(`DocumentSheet.researchRail`) — by design (D2, #404), and the design is right that
auto-presenting would be worse. But the consequence should be named: on the phone a reader cannot
see the document and their notes/summary at once, in the app whose core loop is
read-then-annotate. A collapsed peek strip (one-line summary + note count above the tab bar, tap
to expand) would restore simultaneity without the sheet's cover. (§5 PR-7.)

#### P-7 · MEDIUM — Force-directed graph canvases in phone sheets

The cross-reference graph and the person co-mention ego network are pan/zoom canvases presented
in sheets. Session 161's own note — the graph "never opens half-height" anymore because that "was
the weakest first impression of the feature" — fixed the detent, not the fit: node labels at
canvas scale on a 390-pt screen, drag-vs-scroll gesture contention inside a sheet, and no hover
for edge inspection. The 1-hop `ReferenceListPanel` list is the phone-right representation and
already exists; the canvas should be the secondary door on compact, not the primary. (§5 PR-6.)

#### P-8 · MEDIUM — The dashboards crowd the phone's chrome until the title leaves

Cross-Reference Analytics on iOS "omits the nav title so the full nav-bar width goes to the
trailing controls — this is the worst-crowding view (longest title, no compact fold)"
(`CrossReferenceAnalyticsView.swift:193-196`). Corpus Analytics folds its secondary controls into
an Options menu at compact width (`AnalyticsView.swift:2780`) and shows a rotate-to-landscape
hint in portrait (`showsLandscapeHint`, `:938-942`) — the app literally advising that the
orientation is too small. Each patch is competent; together they are the system saying these
surfaces exceed the phone. §4 draws the conclusion. (§5 PR-6.)

### C. Small defects the phone magnifies

#### P-9 · LOW — Year ranges are stepper-driven at compact width

The analytics year-range bar at compact width is `1861 [−][+] – 2026 [−][+]` (Fig 1 ④;
`AnalyticsChartChrome` compact variant, threaded as `isCompactWidth` from
`AnalyticsView.swift:1374`). Narrowing a century is a hundred taps unless the number itself is
editable; a tap-to-type field (or drag slider) is the compact-right control. (§5 PR-8.)

#### P-10 · LOW — The tab bar never yields during reading

The reader keeps the five-tab bar on screen (Fig 4) — correct as a default, but there is no
immersive reading affordance (tab-bar-hides-on-scroll or full-screen read mode) in an app whose
Read mode otherwise strips chrome deliberately. Minor; worth a toggle at most.

#### P-11 · LOW — "1 volumes," now in two surfaces (shared defect)

The chronology's day headers ("1 volumes · 1 subseries", Fig 3 ③) join Browse's subseries rows
(iPad F-23) in the uninflected count. One `^[inflect: true]` pass over count strings. (§5 PR-5
rider.)

#### P-12 · LOW — Hardware-keyboard support is absent here too (shared defect)

The `.commands` block is `#if os(macOS)` (iPad F-6). On iPhone the population with Smart
Keyboards is small, so this is Low here — but the fix (lifting Document/Find menus to shared
scope) is one change for both iOS platforms.

---

## 4. Fit for a phone — the honest split

The owner asked directly: which features cannot be satisfactorily handled on a phone-sized
screen? Verdicts below, with the recommended posture. "Redirect" means: keep a door on the phone,
render the phone-right reduced form, and offer the full instrument via the app's existing Handoff
plumbing (documents already publish `userActivity`; analytics surfaces could) or an explicit
"best on iPad or Mac" note — the honesty pattern this repo already prefers.

**Fits, and the phone should own it:**
- **Reading** — the app's best typography lives here by accident of width. Own it.
- **Search-and-triage** — query, skim snippets, open, mark reviewed (checklist mode). Strong.
- **Capture** — notes, highlights, tags, add-to-collection, citation copy. Strong.
- **Downloads & indexing** — banners, Live Activity, background tasks: built phone-first.
- **Onboarding, Settings, People browser, Citation Lookup, Saved Searches** — all list-shaped;
  all fine.

**Carries with compromises that are working:**
- **Facets** — the sheet round-trip costs iteration speed but reads well; acceptable on 390 pt
  (the iPad, not the phone, is where the inspector is owed).
- **Timeline reading & collocates** — list/bar shapes survive compact width.
- **Collections composing** — the iPhone outline/preview segmented layout (Composer redesign) is
  a real phone design; long-form assembly is still nicer elsewhere, but nothing is broken.
- **Word cloud, Source Explorer, Related Documents** — single-column forms and clouds fit.
- **Single-chart analytics (By-Year frequency)** — viable *once P-1's clipping is fixed*; the
  landscape hint is a fair patch for a chart that is legitimately better wide.

**Cannot be satisfactorily handled on a phone-sized screen — stop pretending:**
- **Volume heat matrix (P-2)** — opacity-encoded N×N with hover-only values on a hoverless,
  too-narrow device. *Compact form:* ranked pair list (the CSV already defines it). *Full form:*
  redirect.
- **Concordance (P-3)** — two-word context columns are not a concordance. *Compact form:*
  stacked per-hit lines (match centered, context wrapped), losing the vertical scan honestly.
  *Full form:* redirect.
- **Force-directed graph canvases (P-7)** — cross-reference graph, co-mention network. *Compact
  form:* the 1-hop reference/partner lists as the primary representation. *Canvas:* secondary,
  and better on iPad/Mac.
- **Multi-chart dashboards (P-8)** — Series Analytics' four dashboards, Archival Analytics'
  modes, Cross-Reference Analytics' four sections stacked in one scrolling compact sheet. The
  nav-title deletion and landscape hints are the tell. *Compact form:* one section per screen
  with a section switcher, or headline-numbers-first with charts behind taps. *Full form:*
  redirect.
- **Chronology's density chart (P-4)** — hairline strokes; the *list* is the phone form.

The honest phone identity this produces: **a reading, triage, and capture companion with one
good chart** — which is most of a researcher's phone minutes anyway — plus visible, unashamed
doors to the bigger screens for the instrument work. That framing costs three reduced compact
representations and some copy; it does not cost features.

---

## 5. Recommendations, priced

- **PR-1 (S) ⊘ — Fix the analytics sheet's compact clipping.** Audit the chart-header/title/
  year-range rows for fixed widths; everything visible in `ios/analytics.png` (field, title,
  link, axis labels, footer) fits after a `.frame(maxWidth:)`/padding pass. Re-capture the
  screenshot after.
- **PR-2 (S) ⊘ — Compact heat matrix → ranked pair list.** At compact width render the top
  source→target pairs with counts (the CSV edge list's shape); keep the grid ≥ regular. Also
  print counts in cells ≥ regular (the export already does, owner decision G).
- **PR-3 (S) ⊘ — Compact concordance → stacked lines.** Match term centered on its own line,
  wrapped context above/below, per hit; keep the three-column alignment ≥ regular width. Copy
  states the change of shape ("aligned view available on wider screens").
- **PR-4 (S) ⊘ — Chronology compact pass.** Replace the year-of-hairlines chart with month
  buckets at compact width; disambiguate the legend with volume short-codes; inflect the day
  headers (P-11).
- **PR-5 (S) ⊘ — The shared header fix, filed once.** Leading-number and "Source:" extraction at
  index time + per-row prefix guards (joins iPad W-5 / Mac W-3).
- **PR-6 (M) ⊘ — Adopt the phone identity: reduced forms + redirects.** One session establishing
  the pattern: compact-form primary representations (PR-2/PR-3/PR-4), a "Full view works best on
  iPad or Mac" line on the four §4-red surfaces, and `userActivity` publication from analytics/
  graph surfaces so Handoff carries an analysis, not just a document.
- **PR-7 (S) ⊘ — Rail peek strip.** A collapsed one-line rail (summary preview · note/tag
  counts) above the tab bar in Research mode, expanding to today's sheet — restores
  read-and-annotate simultaneity (P-6).
- **PR-8 (S) ⊘ — Tap-to-type year fields at compact width** (P-9).
- **PR-9 (S) ⊘ — Reading immersion toggle** — tab bar hides on scroll in Read mode (P-10);
  Settings-gated like the edge-tap zones.

**Sequencing.** Wave 1: PR-1, PR-5, PR-8 (paper cuts + the flagship embarrassment). Wave 2:
PR-2, PR-3, PR-4 (the three reduced compact forms — this is the §4 honesty made real). Wave 3:
PR-6 (identity + redirects), PR-7, PR-9.

---

## 6. Worklist table (for tracker enrolment)

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-1 | Analytics compact clipping fix + re-capture | P-1 | S | 1 |
| W-2 | Shared header-extraction fix + prefix guards + inflection | P-5, P-11 | S | 1 |
| W-3 | Tap-to-type year fields at compact | P-9 | S | 1 |
| W-4 | Heat matrix compact pair list (+ counts-in-cells ≥ regular) | P-2 | S | 2 |
| W-5 | Concordance compact stacked form | P-3 | S | 2 |
| W-6 | Chronology compact chart + legend + counts | P-4 | S | 2 |
| W-7 | Phone identity: redirects + analytics Handoff + copy | P-7, P-8 | M | 3 |
| W-8 | Rail peek strip | P-6 | S | 3 |
| W-9 | Read-mode tab-bar hiding (Settings-gated) | P-10 | S | 3 |
| W-10 | Shared iOS Commands lift (rides iPad W-6) | P-12 | — | with iPad |

---

## 7. Addendum (2026-08-14) — Semantic Analytics

**What shipped.** Build 37 adds a sixth analytics surface: the whole corpus as one Metal-rendered map
of its own language — 314,483 documents, four colour lenses, region labels, tap-to-open, lasso →
working-corpus capture, volume-pole axis slices, the family's scope bar. On iPhone it opens from
Browse's Analysis Tools menu as a sheet (`BrowserView.swift:201-213`, `:349`). Claims cite branch
`v2`, tree `46cde737`, read 2026-08-14. **5 new findings: Medium ×3, Low ×2**; recommendations
PR-10…PR-13; worklist W-11…W-14; one new row for the §4 fit table. Shared-defect cross-references:
slice scale (Mac M-18, iPad F-26), raw-ID selection card (Mac M-19, iPad F-27), export absence (Mac
M-20, iPad F-28).

**Inputs:** compact-width read of `SemanticAnalyticsView` and `SemanticMapSpikeView` (+
`SemanticMapModel`, `SemanticMapSurface`), `SemanticMapLens`, `SemanticMapPicking`,
`SemanticMapLabels`, `SemanticAxis`, the iOS launcher, manual §13.8, and the Related Documents
semantic pipeline (`SemanticSimilarityGenerator`, `SemanticSharedTerms`, `SemanticFeedbackView`).

### 7.1 What the addendum confirms is working

The compact lessons this review catalogued were visibly applied here — the first analytics surface
built after them:

- **The legend wraps instead of hiding.** The code names the failure it replaced: eleven entries in a
  horizontal scroll "showed three of them on an iPhone with nothing on screen to say the other eight
  existed — a key that hides most of the key." An adaptive grid wraps them, capped at two full rows
  (a cut row "reads as a rendering fault").
- **The lens picker is a menu, not a segmented control, from the fourth lens onward** — "four
  segments fit an iPhone only by truncating their own names." The P-8 crowding class, avoided by
  design.
- **The Lasso toggle lives in the navigation bar because the bottom row was unreachable** — the
  iCloud banner overlaid it and "the toggle was drawn but could not be tapped." The controls stack is
  a plain stack because a grouped `Form` rendered "an empty card with both controls below the fold."
  Both are verified-on-device fixes, recorded in-file.
- **Honest capture at phone scale**: a thumb-drawn lasso at fit-all zoom easily encloses more than a
  corpus may hold, and the card says "Saving the first 7,500 of N" before the save, with device
  coverage from the same resolver Search will use.
- The experimental header collapses to its warning rather than disappearing; the layout caveat is
  permanent; the stats overlay is DEBUG-gated.

### 7.2 Findings

#### P-13 · MEDIUM — The action cards stack until they bury the canvas

The axis, selection, and lasso cards render as one bottom-leading `VStack`
(`SemanticMapSpikeView.swift:725-728`) at `maxWidth` 320–340 — ~85% of a 390-pt screen. With an axis
set, a document selected, and a lasso result showing — the exact state of active use — the three
stack to cover effectively the whole canvas, including the lassoed area itself and the region the
selection sits in. Each card dismisses only individually; nothing condenses them. The stacking exists
for a good reason (cards used to hide each other's buttons); compact needs the next step — one card
at a time, or a condensed strip in the P-6/PR-7 peek-strip shape. (PR-10.)

#### P-14 · MEDIUM — The chrome squeezes the map to roughly half the sheet

Top: the about header (headline + three-sentence body + experimental caption) until dismissed, then a
one-line warning. Bottom: scope chip row + scope summary line + "Colour by" row + legend (≤48 pt +
caption — the provenance caption alone is two lines) + the always-visible point-size slider
(`SemanticMapSpikeView.swift:1718-1726`) + the caveat line. On a 390×844 phone the canvas — the
surface's entire point — gets roughly half the sheet until the header is collapsed. The slider is a
rarely-used control permanently resident at the platform's scarcest edge; the P-8 family's own
answer (fold secondary controls into an Options row at compact) applies. (PR-11.)

#### P-15 · MEDIUM — The slice is an unlabelled chart, and undated volumes plot at mid-axis (shared)

No year ticks, no pole names at the plane's edges, no statement of which end is early — the
semantics ride in a two-line `.caption2` caveat, smallest exactly where the screen is smallest. And
any volume without a parseable coverage year plots at the exact vertical centre
(`SemanticMapSpikeView.swift:519`), an unknown date drawn as a mid-century date. Full analysis at
Mac M-18. (PR-12.)

#### P-16 · LOW — The selection card headline is a raw ID (shared class)

`frus1969v12 · d45` (`SemanticMapSpikeView.swift:1135`) — on a 390-pt card the id *is* the content,
with no volume title or date, and the pushed reader inherits `header: "frus1969v12 — d45"` (`:1238`).
P-5's raw-surface family; the manifest title lookup the scope bar already does would fix the
headline. (PR-13 rider.)

#### P-17 · LOW — No exit: no figure, no CSV, no Handoff

Nothing an iPhone reader finds on the map can leave it except as a working corpus. No figure/CSV
(manual §13.9 covers every sibling), and no `userActivity` — the surface most likely to be *started*
on a phone ("where does this sit?") and *finished* on a Mac publishes nothing for Handoff, the exact
gap PR-6 files for the other analytics. (PR-13.)

### 7.3 Fit for a phone — the §4 table gains a row

**Carries with compromises that are working:** the **semantic map** — overview reading (regions,
lenses, scope-against-corpus) and lasso capture genuinely work at 390 pt; pinch-zoom makes tap-to-open
usable after a zoom-in. What wants width: pole-picking and slice reading (P-15's caveat-only
semantics at caption size), and any two-card state (P-13). Phone form: overview + capture; full
instrument: redirect per PR-6, once the map publishes a `userActivity` (P-17). It is a better phone
citizen than the dashboards in §4's red list — a map degrades by zooming, a dashboard by stacking.

### 7.4 Recommendations, priced

- **PR-10 (S) ⊘ — One card at a time at compact.** Selection, axis, and lasso cards become mutually
  exclusive below regular width (newest wins, others condense to chips), or adopt the PR-7 peek-strip
  shape.
- **PR-11 (S) ⊘ — Compact chrome fold.** Point-size slider (and the legend caption) behind an
  Options row at compact; scope + lens stay visible. Keep the collapsed about header as the default
  after first dismissal (it already is — verify the expanded header does not re-assert per launch).
- **PR-12 (S) ⊘ — Scale the slice** (shared: Mac MR-13, iPad R-14): ticks, pole names, undated
  gutter.
- **PR-13 (S) ⊘ — Exits:** `userActivity` from the map (joins PR-6's analytics-Handoff work) and
  the shared figure/CSV export; rider: humane card headline via the manifest title (P-16).

### 7.5 Foundations worth reusing — the semantic substrate × the visualization family

Six flags, grounded in shipped code (design ranking: `Vector-Embeddings-Semantic-Design.md` §7). On
the phone, O-2 and O-5 pay first.

- **O-1 · Result sets and corpora on the map.** `ScopeMask` is per-row; a document-key mask is the
  same array. "Show on semantic map" from Search gives the phone's triage identity a one-tap
  *where-does-this-sit* door; the lasso already walks the reverse direction.
- **O-2 · A two-way bridge with Related Documents.** The similarity axis ships on this substrate
  (weight 0, experimental; 1.43 ms corpus scan). "Similar documents" from the selection card works
  with zero volumes downloaded — on the phone, where libraries are smallest, that is the
  highest-value semantic feature of all. `SemanticSharedTerms` already computes evidence chips.
- **O-3 · Region-share-over-time in Corpus Analytics.** Per-region `eraCounts` ship in the bundle and
  nothing draws them; region × era stacked areas is the design doc's own §7.3. The data ships today.
- **O-4 · Pre-1900 rescue for Related Documents.** 46,234 documents have an empty Related list, 98.2%
  pre-1900; semantic neighbours as a labelled experimental section lights them, and the feedback loop
  already weights 19th-century verdicts highest.
- **O-5 · The renderer fixes this review's own charts.** P-4's hairline chronology is a density
  scatter this on-demand Metal renderer draws for free, and P-7's graph canvases want exactly its
  LOD/point-sprite posture. The machinery is now in-tree, tested, and phone-proven at 314,483 points.
- **O-6 · Subseries poles.** 659 exact centroids ship (volumes *and* subseries); only tapped-document
  volume poles are offered. A picker is data-ready — and on the phone a picker beats tap-precision.

### 7.6 Worklist additions

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-11 | Compact card discipline + chrome fold | P-13, P-14 | S | 1 |
| W-12 | Slice scale + undated gutter (shared: Mac W-14, iPad W-13) | P-15 | S | 1 |
| W-13 | Map userActivity + shared export + humane card headline | P-17, P-16 | S | 2 |
| W-14 | §4 fit-table adoption + redirect copy for the map (rides W-7) | — | — | with W-7 |
