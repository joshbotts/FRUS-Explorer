# FRUS Explorer — Cross-Platform UI Adversarial Review (Consolidated Handover)

**Date:** 2026-08-14 · **Version:** 1.0 · **Status:** consolidated handover + master worklist (Claude Code-consumable).
Twin: `Cross-Platform-UI-Adversarial-Review.dc.html` (figures: `assets/*.png`, the repo's committed screenshots, annotated).

**What this package is.** One handover consolidating the three platform reviews of 2026-08-13 and
their Semantic Analytics addenda of 2026-08-14: shared defects filed once (§2), platform-defining
findings digested (§3), the new Semantic Analytics surface's consolidated verdict (§4), reuse
opportunities once (§5), and a master worklist sequencing everything (§6). The per-platform handoffs
remain the citation-grade source — every finding there cites file:line at branch `v2` — and stay
authoritative for detail:

- `Mac-UI/Mac-UI-Adversarial-Review.md` — 22 findings (M-1…M-22), MR-1…MR-16
- `iPad-UI/iPad-UI-Adversarial-Review.md` — 30 findings (F-1…F-30), R-1…R-16
- `iPhone-UI/iPhone-UI-Adversarial-Review.md` — 17 findings (P-1…P-17) + fit table, PR-1…PR-13

**Totals: 69 findings — Critical ×2, High ×19, Medium ×30, Low ×18 — into 12 consolidated work items.**

---

## 1. The three verdicts, side by side

- **macOS is the serious platform and mostly earns it** — exemplary menus, honest counting, native
  inspectors — but carries professional-app debts under sustained use: a 23-scene window model whose
  singletons cross-wire, hand-rolled fixed-point chrome in the most-used window, a reader with no
  measure, and deleted printing on reserved shortcuts.
- **The iPad app is an iPhone app given the whole screen.** Width is spent, not used; the
  keyboard/trackpad iPad named in the code does not exist in the code (zero commands, no
  find-in-document, no drag and drop); analysis is modal on the platform's biggest canvas.
- **The iPhone's core loop is genuinely good** — reading, triage, capture — and its honest identity
  is a companion with one good chart. Failures concentrate where desktop-grade analysis was ported
  to 390 pt without asking whether it survives.
- **Working everywhere:** multi-window plumbing, boot honesty, count honesty, the iOS Dynamic Type
  program, and — in Semantic Analytics — the app's most disciplined caveat posture yet.

## 2. Shared defects — file once, fix everywhere

| # | Severity | Defect | Platform IDs | Fix shape | Work item |
|---|---|---|---|---|---|
| X-1 | CRITICAL | Reader has no maximum measure: ~190-char lines on 13″ iPad, ~150–300 on Mac; iPhone correct by accident | M-7 · F-1 | One CSS line in `HTMLTemplate.documentCSS` (max-width ~70ch, centered) | CW-1 |
| X-2 | HIGH | Result headers double-number ("251. 251.") and leak "Source:" archival notes into titles; worst at 390 pt. Rider: "1 volumes" inflection | M-6 · F-21 · P-5 (+F-23, P-11) | One indexing fix + per-row prefix guards + `^[inflect]` pass | CW-2 |
| X-3 | HIGH (iOS) | Keyboard commands exist only behind `#if os(macOS)`; Magic Keyboard iPad gets nothing | F-6 (critical) · P-12 | Lift Document/Find menus to shared scope; FocusedValue routing is platform-neutral | CW-6 |
| X-4 | MEDIUM | Raw internal IDs on reader-facing surfaces: Mac principal item `frus1946v06/d475`; semantic selection card `frus1969v12 · d45` minted into opened-window headers | M-8/M-19 · F-27 · P-16 | Manifest title lookup ("volume title · Doc id"); raw id to secondary/help | CW-3 |
| X-5 | MEDIUM | Semantic slice is an unlabelled chart; undated volumes plot silently at mid-axis | M-18 · F-26 · P-15 | Year ticks, pole names at plane edges, undated gutter or stated exclusion | CW-3 |
| X-6 | MEDIUM | Semantic map has no exit: no figure/CSV anywhere (vs. manual §13.9's doctrine), no Handoff userActivity on iOS | M-20 · F-28 · P-17 | Viewport figure + lasso/slice CSV per §13.9 conventions; publish userActivity | CW-7 |
| X-7 | MEDIUM | Analysis is modal where it should be resident: six analytics sheets on iPad, the newest pushing the reader inside itself; macOS windows prove the alternative | F-11/F-12/F-25 | Analytics WindowGroups on iPad, Semantic Analytics first; facet inspector at regular width | CW-9 |
| X-8 | LOW–MED | Documentation shows retired or missing chrome: stale iPad shots, strip-era Mac manual figures, §13.8 [SCREENSHOT:] placeholders — no semantic capture exists on any platform | M-12/M-13 · F-24 | One re-capture sweep + ledger rule: chrome retired ⇒ shot stale | CW-11 |

## 3. Platform-defining findings (digest)

**macOS — professional-app debts under sustained use**
- Window model tax (M-1…M-3, M-22): 24 scenes; singleton per-document tools cross-wire with two
  documents open; one Search window blocks side-by-side result comparison.
- Least-native chrome in the most-used window (M-4, M-5, M-10): no toolbar, ten hover-explained
  9–13 pt icon toggles, a dead "Collections" chip, 262 deferred fixed-point text sites.
- Paper unreachable (M-14): Print deleted; ⌘P is Project Home, ⌘S is Search.
- The new map is gesture-only (M-17): pinch is the sole zoom input — a mouse cannot zoom
  314,483 points; the menu system contributes only the opening item.
- Quiet failures (M-9, M-11): invisible Read-mode paging; "Sync Error" detail lives in a tooltip.

**iPadOS — the research machine that is not in the code**
- Width spent, not used (F-2, F-3, F-5): phone lists at full width; a five-row sidebar over a dead
  column; the two-pane patterns the codebase already ships were never applied to the tab roots.
- Input grammar missing (F-7…F-10): no find-in-document by any input, zero drag and drop, no
  pointer affordances, tooltip-only explanations that iPadOS never renders.
- Modality (X-7; F-12…F-14): facets as a transient sheet; the Search→Analytics tab teleport; the
  Research Guide five levels deep in Settings.
- Context losses (F-17…F-19): breadcrumb suppressed over a five-level hierarchy; "Open in New
  Window" can silently no-op; a restored window can dead-end in a spinner.
- Reader dup (F-15, F-16, F-22): the same AI summary twice before the document; title stutter; the
  reading surface exempt from Dynamic Type.

**iOS — honest about what fits in a pocket**
- The flagship analytics sheet clips its own chrome at both edges, in the manual's own screenshot (P-1).
- Three surfaces fail 390 pt by their own code's admission (P-2 heat matrix, P-3 concordance,
  P-8 dashboards); the chronology chart is hairlines under an all-identical legend (P-4).
- Semantic compact debts (P-13, P-14): three action cards stack until they bury the canvas; header +
  controls squeeze the map to roughly half the sheet.
- The fit split stands (iPhone review §4, now including the semantic map as "carries"): own reading/
  triage/capture; carry facets, timelines, single charts, map overview + lasso; stop pretending to
  carry the matrix, concordance, graph canvases, and multi-chart dashboards — reduced forms + redirects.

## 4. Semantic Analytics — consolidated verdict on the new surface

**Credit:** the app's most disciplined honesty posture yet — collapse-not-dismiss experimental
header; permanent layout caveat; scope denominators ("whole volumes, 12 of 552"); lasso coverage
stated at capture via the same resolver Search uses, with honest truncation; provenance lens
evidence floor + plurality caption + deliberately dimmed weakest category; unsupported lenses
withheld; the six once-dead controls documented in-file with guards; the macOS Metal
window-not-sheet lesson measured and recorded; the compact lessons (wrapping legend, menu lens
picker, reachable toolbar toggle) applied on day one.

**Consolidated shortfalls:** unlabelled slice + undated-at-centre (X-5); raw-ID cards (X-4); no
exits (X-6); inert region names while the artifact's per-region `eraCounts` go unread (M-21/F-29);
Mac pinch-only zoom (M-17); iPad's sixth modal sheet burying the reader inside itself (X-7/F-25);
iPhone card stacking + chrome squeeze (P-13/P-14); VoiceOver gets a named rectangle everywhere
(M-22/F-30).

## 5. Foundations worth reusing — the semantic substrate × the visualization family

Ranked source: `Planning/Vector-Embeddings-Semantic-Design.md` §7. Filed once for all platforms.

- **O-1 · Result sets and corpora on the map.** The scope mask is per-row but only built from volume
  sets; a document-key mask is the same array. "Show on semantic map" from Search/corpora closes the
  loop the lasso already half-walks.
- **O-2 · Two-way bridge with Related Documents.** The similarity axis ships on this substrate
  (weight 0, experimental; 1.43 ms corpus scan). Selection card → "Similar documents" (zero
  downloads); Related rows → "Show on map"; `SemanticSharedTerms` already computes evidence chips.
- **O-3 · Region-share-over-time in Corpus Analytics.** Per-region `eraCounts` ship in the bundle,
  read by nothing; region × era stacked areas is the design doc's own §7.3. The data ships today.
- **O-4 · Pre-1900 rescue for Related Documents and the graph.** 46,234 documents have an empty
  Related list, 98.2% pre-1900; explicitly-labelled semantic neighbours light the corpus's darkest
  region; the feedback loop already weights 19th-century verdicts highest.
- **O-5 · The Metal point renderer as a house substrate.** On-demand drawing, per-row flags,
  pure-function camera, measured picking — what the graph canvases lack; the iPhone's hairline
  chronology is a density scatter it draws for free.
- **O-6 · Subseries poles.** 659 exact centroids ship (volumes *and* subseries); only tapped-document
  volume poles are offered. A picker is data-ready; free-text poles stay correctly deferred.

## 6. Master worklist and sequencing

Per-platform worklist rows (Mac W-*, iPad W-*, iPhone W-*) map into twelve consolidated items.

| # | Carries | Platforms | Maps to | Effort | Wave |
|---|---|---|---|---|---|
| CW-1 | Reader measure — one CSS line (X-1) | Mac · iPad | Mac W-1 · iPad W-1 | S | 1 |
| CW-2 | Header extraction + prefix guards + inflection (X-2) | all | Mac W-3 · iPad W-5 · iPhone W-2 | S | 1 |
| CW-3 | Slice scale + undated gutter; humane selection card + open header (X-5, X-4) | all | Mac W-14/W-15 · iPad W-13/W-14 · iPhone W-12 | S | 1 |
| CW-4 | Per-platform paper cuts: Print/shortcuts, Mac zoom inputs, Sync Error; facet inspector, find-in-doc, summary dedup; analytics clipping, tap-to-type years | all | Mac W-2/W-4/W-13 · iPad W-2/W-3/W-4 · iPhone W-1/W-3 | S each | 1 |
| CW-5 | Semantic compact pass: one card at a time + chrome fold (P-13/P-14) | iPhone | iPhone W-11 | S | 1 |
| CW-6 | iOS Commands lift (X-3) + drag-and-drop pass + pointer/help riders | iPad · iPhone | iPad W-6/W-7 · iPhone W-10 | M | 2 |
| CW-7 | Semantic exits: export, userActivity, region tap + eraCounts, VoiceOver list, §13.8 captures (X-6) | all | Mac W-16/W-17 · iPad W-15 · iPhone W-13 | S–M | 2 |
| CW-8 | Compact reduced forms + phone identity (P-2/P-3/P-4/P-7/P-8) | iPhone | iPhone W-4…W-8/W-14 | S–M | 2 |
| CW-9 | Window model: de-singleton Mac tools + multi-Search; iPad analytics windows, semantic first (X-7) | Mac · iPad | Mac W-6/W-7 · iPad W-9/W-12 | M–L | 3 |
| CW-10 | Chrome + width: Mac Search re-chrome; iPad width discipline + TabSections + breadcrumb; Read-mode paging | Mac · iPad | Mac W-8/W-9 · iPad W-8 | M | 3 |
| CW-11 | Documentation sweep: re-captures, captions, ledger rule, sidebar truncation, Settings search, guide doors (X-8) | all | Mac W-5/W-10 · iPad W-10 · iPhone W-9 | S | 3 |
| CW-12 | Programs and gates: macOS text scaling (262 sites); window-fronting audit per release; iPad probes | Mac · iPad | Mac W-11/W-12 · iPad W-11 | M–L | scheduled |

**Sequencing.** Wave 1 (CW-1…CW-5) is one all-S polish session per platform — CW-1 alone transforms
the core surface on two platforms. Wave 2 (CW-6…CW-8): the input session and the honest-compact
session. Wave 3 (CW-9…CW-11): windows, chrome, width, docs. CW-12 runs as scheduled programs and
recurring gates. Opportunities O-1…O-3 slot after wave 1: two are mask/chart work over data that
already ships.

---

**Figures** (in the HTML twin, annotated): `assets/ipad-document.png` (X-1, F-15) ·
`assets/mac-document.png` (X-1, X-4, M-11) · `assets/ipad-search-results.png` +
`assets/ios-search-results.png` (X-2 on two platforms) · `assets/mac-search.png` (M-4, M-10, X-2) ·
`assets/ios-analytics.png` (P-1) · `assets/ios-chronology.png` (P-4, X-2 rider). No committed
capture of Semantic Analytics exists on any platform (X-8 rider).
