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

## Deferred — other files (secondary macOS / mixed, next passes)

| File | Sites | Triage | Notes |
|------|------:|--------|-------|
| `App/MacDocumentView.swift` | 8 | SCALE (macOS) | Document-window strip captions (all `11`/`captionSize`) — same tokens apply; macOS reading chrome, next pass. |
| `Research/ResearchView.swift` | 6 | SCALE (macOS) | Research window rows (`12`/`10`/`8`). |
| `App/HistoryWindowView.swift` | 6 | SCALE (macOS) | History list rows (`13`/`11`). |
| `App/MainWindowView.swift` | 5 | mixed | 40pt empty glyph + `15`/`13`/`12` texts SCALE; the `12` monospaced count → **LEAVE** (grid-aligned tally). |
| `Collections/CollectionRichTextEditor.swift` | 1 | SCALE + **A2** | Toolbar label `11`. **A2 core** (`adjustsFontForContentSizeCategory` + `UIFontMetrics` display-time mapping) is its own dedicated item — NOT done this pass. |
| `Collections/CollectionExportSheet.swift` | 1 | SCALE | 48pt export glyph → `@ScaledMetric` when the Collections pass runs. |
| `Collections/MacCollectionManagerView.swift` | 1 | LEAVE | `9`pt provenance micro-label in a dense grid row. |

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

- **Converted this pass (Stage 1):** 34 sites across 9 files (28 SCALE, 6 ICON-track, 2 LEAVE) + 1 detent clip fix.
- **Deferred macOS-chrome bulk:** 262 (FRUSSettingsView 145, SupportingViews 72, SearchSheet 45).
- **Deferred other (next passes):** 28 (MacDocumentView 8, ResearchView 6, HistoryWindowView 6, MainWindowView 5, plus 3 Collections singles).
- **LEAVE-FIXED permanent (graph + word cloud):** 22 (CrossReferenceGraphView 11, VolumeConnectionGraphView 5, WordCloud files 6).
- Rounding note: a handful of the "deferred other" files also contain 1–2 LEAVE sites
  (e.g. MainWindowView's monospaced count, MacCollectionManagerView's grid micro-label)
  folded into their rows above; those are called out per-file.

The **A2 rich-text editor** work (`CollectionRichTextEditor` `adjustsFontForContentSizeCategory`
+ `UIFontMetrics`) is tracked as its own item and is not part of this font-site pass.
