# Dynamic Type Worklist — UI-Audit §3 A1/A2

Tracking the migration of fixed-point `.font(.system(size:))` off frozen sizes onto
scalable text styles / `@ScaledMetric`, so text tracks the user's Dynamic Type setting.

- **Baseline survey:** 346 `.font(.system(size:))` sites app-wide (67 on `Image(systemName:)`).
- **Convention:** see `FRUSTheme` "Dynamic Type — scalable text tokens" (size→text-style
  table + `@ScaledMetric(relativeTo:)` pattern + `FRUSTheme.captionFont` / `captionSmallFont`).
- **Discrimination rules (this is a careful pass, NOT find-replace):**
  - **SCALE** — body/caption/headline/title text on reading, onboarding, banner,
    search, research, collection, history, document surfaces; empty-state / hero
    glyphs that pair with text; fixed `.frame(height:)` / `.presentationDetents`
    that clip large type.
  - **ICON** — a standalone control/toolbar glyph at a fixed size is fine; an icon
    paired with adjacent text should track it (feed a text-style `Font`).
  - **LEAVE-FIXED** — graph-canvas node/edge labels (scale with graph *zoom*, not
    Dynamic Type); word-cloud bespoke `word.fontSize`; monospaced count/tally badges
    aligned in a grid; a glyph constrained inside a fixed-size shape (would clip).

Status key: **[x]** converted this pass · **[ ]** deferred · **LEAVE** decided-fixed.

---

## Stage 1 — converted this pass (iOS-primary reading / onboarding / banner surfaces)

| File | Sites | SCALE | ICON | LEAVE-FIXED | Notes |
|------|------:|------:|-----:|------------:|-------|
| `Theme/FRUSTheme.swift` | 3 | 3 | — | — | `EditorialNoteBadge` + `FRUSTagChip` text → `captionFont`/`captionSmallFont`. Added the scalable tokens + convention comment. The 3 CGFloat constants (`captionSize`/`captionSmallSize`/`sectionLabelSize`) are **retained as layout metrics** for macOS chrome not yet migrated — they are not text sizes at their remaining call sites. |
| `Onboarding/OnboardingView.swift` | 5 | 3 | — | 2 | Two 56pt hero glyphs → `@ScaledMetric heroGlyphSize` (cap AX3). StepDot `label` → `.caption2`. **LEAVE:** StepDot number (`12`) + checkmark (`11`) sit inside a fixed 28pt circle — scaling clips inside the badge; documented at the site. |
| `Onboarding/OnboardingIntroView.swift` | 1 | 1 | — | — | 52pt hero glyph → `@ScaledMetric` (the pre-existing AX3 cap was **dead** against the former fixed size — now it actually scales). |
| `App/IndexingBannerView.swift` | 6 | 4 | 2 | — | iOS-only. 4 caption texts + 2 paired status icons → `captionFont`/`captionSmallFont`. |
| `App/IndexingQueueBannerView.swift` | 8 | 6 | 2 | — | iOS-only. All caption texts + paired icons (status, clock, chevron, learn-label) → scalable tokens. |
| `App/IndexingContextCard.swift` | 1 | 1 | — | — | Series-context caption → `captionFont` (shared by the iOS banner + macOS detail). |
| `App/IndexingSummaryCard.swift` | 5 | 5 | — | — | 4 iOS banner captions → tokens; the macOS sheet's 48pt success glyph → `@ScaledMetric successGlyphSize` (cap AX3). |
| `DocumentView/DocumentView.swift` | 4 | 4 | — | — | Two 44pt not-found empty-state glyphs → `@ScaledMetric notFoundGlyphSize` (cap AX3); "Add Tag" button caption → `captionFont`; panel disclosure chevron (`10`) → `.caption2`. Also fixed the **A2 clip**: highlight color-picker sheet detent `[.height(180)]` → `[.height(180), .medium]` so the swatch row can grow. |
| `Search/SearchView.swift` | 1 | 1 | — | — | 48pt empty-prompt hero glyph → `@ScaledMetric promptGlyphSize` (cap AX3). |
| **Stage-1 total** | **34** | **28** | **6** | **2** | Every text/paired-icon site in these files now scales. |

### `.frame(height:)` / detent clip sites in the Stage-1 files
Audited the fixed-container sites in these files against AX5:
- `DocumentView.swift` highlight picker `presentationDetents([.height(180)])` — **fixed (converted):** added `.medium` (above).
- Remaining `.frame(width:)` in the indexing banners are on `ProgressView` (bar width, no text) — no clip. Their other `presentationDetents` are `[.medium, .large]` (already growable). No fixed text-container heights remained to clip.

---

## Deferred — macOS-chrome bulk (explicitly NOT this pass)

The three heaviest files are macOS window/settings/search chrome. macOS 14+ has text
scaling, so they are **not exempt**, but they are lower-priority than the iOS-visible
reading surfaces and are a large, self-contained follow-up. Deferred with the same
convention already in place to reuse.

| File | Sites | Rationale for deferral |
|------|------:|------------------------|
| `Settings/FRUSSettingsView.swift` | 145 | macOS-only settings chrome (dual of the iOS `SettingsView`). Largest single file; its own pass. |
| `App/SupportingViews.swift` | 72 | macOS window scaffolding (status bar, launchers, section chrome). |
| `App/SearchSheet.swift` | 45 | macOS search-window chrome + result rows. |
| **Deferred macOS-chrome total** | **262** | Convert with the `FRUSTheme` convention when their pass is scheduled. |

## Stage 3 — converted this pass (iOS-reachable SECONDARY text surfaces)

Stage 3 targets the iOS-reachable secondary text surfaces not covered by stage 1's
iOS-primary reading/onboarding/banner batch. The audit of the "deferred other" table
below (re-checked platform reachability at each file's `#if os(...)` guard and every
call site) found **exactly one** genuinely iOS-reachable file: `ResearchView`, which is
hosted at BOTH `MainTabView.swift:79` (the iOS **Research tab**) and `FRUSExplorerApp.swift:705`
(the macOS `frus.research` window). It had been mis-labelled "macOS" in the stage-1
deferred table. Every other "deferred other" file is `#if os(macOS)`-gated (verified) —
they stay deferred as macOS chrome.

| File | Sites | SCALE | ICON | LEAVE-FIXED | Notes |
|------|------:|------:|-----:|------------:|-------|
| `Research/ResearchView.swift` | 6 | 4 | 2 | — | Shared iOS-tab / macOS-window. All **four** sidebar count badges (`12`, at source lines 150/171/195/221 — All-Documents, By-Collection, By-Tag, **By-Highlight**) → `captionFont`; the "By Tag" `◆` glyph (`10`, in the Label `icon:` slot beside scaling text) → `captionSmallFont`; the document-row collection `tray.2` glyph (`8`) → dropped its override so it inherits the HStack's `.caption2` and tracks its adjacent label. Version history 1.3 → 1.4. (Review 2026-07-04: the By-Highlight badge had been missed on the first pass — now 4-of-4.) |
| **Stage-3 total** | **6** | **4** | **2** | — | The only iOS-reachable residual text surface; now scales. |

### `.frame(height:)` audit (iOS-reachable)
The audit's "22 fixed `.frame(height:)`" was a rough at-audit grep. Re-swept every numeric
`.frame(height:)` and split by platform + purpose:
- **Named A2 clip (DocumentView highlight-picker detent):** fixed in stage 1 (`[.height(180), .medium]`).
- **iOS-reachable numeric `.frame(height:)` remaining:** all are **fixed chart/graph CANVAS**
  heights, not text containers — `Analytics/AnalyticsView.swift` (6× `280`/`220` Swift-Charts
  canvases), `Chronology/ChronologyView.swift` (`150` chart) — a chart canvas is sized in
  points by design and does not clip text (its axis labels are separate, scalable). **LEAVE.**
- **macOS-only:** `SearchSheet` (6), `MainWindowView` (4), `FRUSSettingsView` (2),
  `CrossReferenceGraphView` (2 graph canvas), `SupportingViews:1111` (24pt status bar) —
  deferred macOS chrome / graph canvas. No iOS-reachable fixed-height *text* container remains.

## Deferred — other files (secondary macOS / mixed, next passes) — all `#if os(macOS)`-verified

| File | Sites | Triage | Notes |
|------|------:|--------|-------|
| `App/MacDocumentView.swift` | 8 | SCALE (macOS) | Document-window strip captions (all `11`/`captionSize`) — same tokens apply; macOS reading chrome, next pass. `#if os(macOS)`. |
| `App/HistoryWindowView.swift` | 6 | SCALE (macOS) | History list rows (`13`/`11`). Whole file `#if os(macOS)`; `frus.history` window only. |
| `App/MainWindowView.swift` | 5 | mixed (macOS) | 40pt empty glyph + `15`/`13`/`12` texts SCALE; the `12` monospaced count → **LEAVE** (grid-aligned tally). Whole file `#if os(macOS)`. |
| `Collections/CollectionRichTextEditor.swift` | 1 | SCALE + **A2** | Toolbar label `11` (macOS toolbar). **A2 core** shipped in commit `ebe4011` (iOS `adjustsFontForContentSizeCategory` + `UIFontMetrics` remap). The residual `11` is macOS toolbar chrome. |
| `Collections/CollectionExportSheet.swift` | 1 | SCALE (macOS) | 48pt success glyph in `MacExportCompleteView` (macOS Save-panel flow) → `@ScaledMetric` when the Collections macOS pass runs. |
| `Collections/MacCollectionManagerView.swift` | 1 | LEAVE (macOS) | `9`pt provenance micro-label in a dense grid row; macOS-only manager window. |

## LEAVE-FIXED (permanent) — graph canvas + word cloud

Per the discrimination rules these are correct as fixed points and must **not** be scaled:

| File | Sites | Reason |
|------|------:|--------|
| `CrossReference/CrossReferenceGraphView.swift` | 11 | Node/edge labels scale with graph **zoom**, not Dynamic Type — a fixed pt is the contract (Session 161 visual-encoding). The legend/inset control text (`14`/`11`) could scale later, but the canvas labels (`8`, `fontSize`, `fontSize-1`) are LEAVE. |
| `CrossReference/VolumeConnectionGraphView.swift` | 5 | Same: volume-node canvas labels (`8`/`9`/`10`) are zoom-scaled. Legend `13`s could scale in a graph-chrome pass. |
| `Analytics/WordCloud/WordCloudView.swift` | 1 | Bespoke `word.fontSize` layout system — the word cloud sizes words by frequency, not text style. |
| `Analytics/WordCloud/WordCloudComparisonView.swift` | 1 | Same bespoke `word.fontSize`. |
| `Analytics/WordCloud/WordCloudExport.swift` | 4 | Export canvas: `word.fontSize` + fixed export-image chrome (`20`/`14`/`44`) that must render at a fixed pixel size in the exported image. |

---

## Summary counts (346 total)

Reconciled after Stage 3 — **every one of the 346 sites is now classified as
DONE, DEFERRED (macOS chrome), or LEAVE-FIXED (permanent)**:

- **Converted — Stage 1** (iOS-primary reading / onboarding / banner): **34** sites / 9 files (28 SCALE, 6 ICON, 2 LEAVE) + 1 detent clip fix.
- **Converted — Stage 3** (iOS-reachable secondary — `ResearchView`): **6** sites (4 SCALE, 2 ICON).
- **Converted total: 40 sites.**
- **Deferred — macOS-chrome bulk:** **262** (FRUSSettingsView 145, SupportingViews 72, SearchSheet 45).
- **Deferred — other macOS-only files** (all `#if os(macOS)`-verified, next macOS passes): **22**
  (MacDocumentView 8, HistoryWindowView 6, MainWindowView 5, CollectionRichTextEditor 1 macOS-toolbar,
  CollectionExportSheet 1, MacCollectionManagerView 1). ResearchView's 6 moved to *converted*.
- **LEAVE-FIXED permanent (graph + word cloud):** **22** (CrossReferenceGraphView 11, VolumeConnectionGraphView 5, WordCloud files 6).
- **Reconciliation: 40 done + 262 + 22 deferred + 22 leave-fixed = 346.** ✓
- Rounding note: a handful of the deferred macOS files also contain 1–2 in-file LEAVE sites
  (e.g. MainWindowView's monospaced count, MacCollectionManagerView's grid micro-label) — those are
  folded into their file rows and will be marked LEAVE when that file's macOS pass runs.

The **A2 rich-text editor** work (`CollectionRichTextEditor` `adjustsFontForContentSizeCategory`
+ `UIFontMetrics`) shipped in commit `ebe4011` (its own item). The one residual `11`pt site in that
file is the macOS toolbar label, folded into the deferred macOS-chrome count above.

---

## Adversarial-review fixes (2026-07-04)

Three low-severity findings from the review of the pass:

1. **ResearchView "By Highlight" badge missed** — the fourth of four identical sidebar
   count badges (source line 221) was left at `.system(size: 12)` while its three siblings
   moved to `captionFont`. Fixed → `captionFont`; the file is now genuinely 4-of-4 (the
   Stage-3 row above is corrected to name all four line numbers).

2. **`@ScaledMetric` hero-glyph caps were inert** — every hero/empty-state glyph used
   `.font(.system(size: <scaledMetric>)).dynamicTypeSize(...accessibility3)`. That modifier
   is a no-op for the glyph size: `@ScaledMetric` resolves its `CGFloat` from the *parent's*
   uncapped environment, and a `.system(size:)` font ignores the downstream environment the
   modifier changes — so glyphs grew past AX3 to their full AX5 size. Replaced the modifier
   at all seven sites (OnboardingIntroView, OnboardingView ×2, SearchView, IndexingSummaryCard,
   DocumentView ×2) with a code clamp: `FRUSTheme.cappedGlyphSize(scaled, base: N)` =
   `min(scaled, base * 1.6)`, added to `FRUSTheme`. Glyphs still scale with Dynamic Type but
   now actually hold near the accessibility-large tier.

3. **Highlight-picker sheet still opened clipped at the smallest detent** — a multi-detent
   sheet opens at its *smallest* detent, so `[.height(180), .medium]` still presents at 180 pt,
   where the grown title/nav chrome can clip the swatch row. Wrapped the sheet content in a
   `ScrollView` so the overflow scrolls (every control stays reachable) without removing the
   `.medium` drag-to-grow affordance.

All three are UI-only; no parse-output change, no index-version bump.
