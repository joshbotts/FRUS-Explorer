# Research Rail — Implementation Plan

**Source:** `design_handoff_research_rail/` (iCloud, 2026-06-30 Build 26 screenshots folder) — README.md,
`Document Cleanup.dc.html` interactive mock (+`support.js`), 7 annotated screenshots.
**Direction:** mock frame **1e** (grid action area). Frame 1a is the current-build baseline — do not implement.
**Plan date:** 2026-07-18. Code verification: 6-reader workflow over v2 (every file:line below re-checked against source).

## 1. What the design is

All research chrome on the document reading surface — the macOS research strip (14 controls, ~920 pt ideal),
the bottom research accordion (both platforms), and iPad's separate notes inspector — merges into **one
trailing 300 pt "Research rail"** behind a single icon-only toggle (`doc.text.magnifyingglass`, bound to the
existing `frus.document.researchPanel.visible` so `defaultDocumentMode` and ⌘⇧R keep working). Rail content,
top→bottom: `RESEARCH` header · **3×2 action grid** (Cite · Word Cloud · Share / Sources · Graph · Related) ·
accordions **SUMMARY / NOTES / TAGS / COLLECTIONS** (Collections is new; each accordion owns its own add-verb,
so no verb appears twice). Rail-off is pure reading: a **floating selection bar** at the text selection
(4 highlight dots · Excerpt · Look Up · Note — *shown in both modes*, per the handoff's Interactions section)
and prev/next as **hover edge chevrons** (Mac) / existing edge-taps (iOS). Titlebar collapses 10 launchers → 
Search · **Browse** · **Analytics** menu · **My Research** menu · rail toggle; main-window minWidth **700 → 640**;
below ~**900 pt content width the rail overlays** the document instead of squeezing it. iPad: toolbar ~13 → 2,
rail = `.inspector`. iPhone: toolbar → back + toggle, rail = sheet with `.medium/.large` detents; tab bar unchanged.

## 2. Verified state (what the handoff got right)

The core reuse contract all checks out:

- `@AppStorage "frus.document.researchPanel.visible"` shared by strip picker (SupportingViews.swift:154),
  MacDocumentView:107, DocumentView:268; `defaultDocumentMode` (`frus.reading.defaultMode`) writes it per
  document open (MacDocumentView:206-213, DocumentView:362); ⌘⇧R = Document menu Toggle
  (FRUSExplorerApp.swift:2166-2174) → `DocumentCommandActions.toggleResearchPanel` (MacDocumentView:631).
  Binding the rail toggle to the same key preserves all of it for free.
- Expansion keys `…researchPanel.summary/.notes/.tags` exist exactly as named (+ `.subjects`, see D1) —
  MacDocumentView:108-112 ≡ DocumentView:269-273. Proposed `…researchPanel.collections` is unused (grep-clean).
- Every grid-tile action exists: Cite→`CitationPopoverView` (SupportingViews:1869), Share→`DocumentSharePopover`
  (:2177), Sources→`frus.sourceExplorer`, Graph→`frus.crossReferenceGraph`, Related→`openWindow(value:
  RelatedDocumentsRequest)` (:375-379), Word Cloud→`pendingWordCloud = .document(…)` (:320).
- minWidth 700 at FRUSExplorerApp.swift:967 (comment :954-966 cites the strip's width as the historical floor —
  the constraint this design deletes). ⇧⌘B Browse = the existing `frus.corpusBrowser` scene shortcut (:642).
- iPad `.inspector` precedent exists (DocumentView:648, today hosting the notes panel);
  `presentationDetents([.medium,.large], selection:)` precedent = the graph sheet (DocumentView:574).
- iOS edge-taps: `documentEdgeNavigationOverlay` (DocumentView:1542-1568), gated `!panelVisible &&
  edgeTapNavigationEnabled` — exactly the rail-off behavior the design keeps.
- `CollectionEntry` carries volumeId+documentId (Collection.swift:434,453-459). The **Collections Composer
  program is fully merged** (PRs #281-#304) — no in-flight conflict.
- Selection bounding rect is **genuinely new** — the bridge posts `{start,end,text,blockText}` only; no
  `getBoundingClientRect`, no scroll bridge, anywhere (grep-clean).
- Test blast radius is small: **zero** existing tests reference ResearchStripView / researchPanel /
  showNotesPanel / strip button titles. UIObstructionTests scenarios never open a document. The test work is
  writing new coverage, not repairing old.

## 3. Corrections to the handoff (verified against code)

| # | Handoff says | Code says |
|---|---|---|
| C1 | Rail accordions = Summary/Notes/Tags/Collections | A **fifth accordion exists**: "Subjects (this volume)" (#308 F7), key `…researchPanel.subjects`, both platforms (MacDocumentView:586-604, DocumentView:1774-1793). **D1 resolved: retire it deliberately** (documented removal, not a silent drop); returns later as a separate view once document-level tagging is refined |
| C2 | "New Window retires to the File menu" | **No app File-menu item exists** (no `CommandGroup(.newItem)`; the system ⌘N opens a new *main* window). Native tabbing for document windows already works (WindowGroup(for: DocumentWindowID.self)). The File-menu "Open in New Window" command must be **added** |
| C3 | Titlebar spec applies to "the document window" | It exists only in **MainWindowView**. `MacDocumentWindowView` (MacDocumentView.swift:1081-1148) has **no toolbar at all** — the new titlebar + toggle must be added there, or standalone windows/tabs have no way to reopen the rail |
| C4 | "Selection verbs pop in and out" incl. Highlight | Highlight is always-rendered, merely disabled without a selection; only Add-Note-to-Highlight/Excerpt/NARA are conditionally rendered (SupportingViews:388-467). Excerpt/NARA key off `webKitSelectedText`, which deliberately **survives selection-clear** — load-bearing for the floating bar's snapshot semantics (§6 Phase B) |
| C5 | "Volume nav row shows in rail-ON only" | Behavior change: today `volumeNavigationView` renders unconditionally (MacDocumentView:421-426). Fine — but Read mode then has no visible position indicator ("Doc N", :859); the identity line covers it |

Minor: MacDocumentWindowView lives in MacDocumentView.swift (not the MainWindowView family); iPad toolbar
maximal count is 13 with Stage Manager + AI (11 unconditional); strip Word Cloud relies on a MainWindowView
`onChange` observer, already broken-by-design in standalone windows → rail tiles must `openWindow` directly.

## 4. Owner decisions — RESOLVED 2026-07-18

| # | Decision | Resolution (owner) |
|---|---|---|
| **D1** | **Subjects accordion fate.** The handoff defers "Subjects" as a *future grid tile* — but a volume-level SUBJECTS accordion already shipped (#308 F7) | **Drop it from the document view for now** (until document-level tagging is refined); when it returns, implement it as a **separate view, not an accordion**. The rail ships the handoff's four accordions. C1 therefore *deliberately retires* the document-view Subjects sections on both platforms + the now-orphaned `…researchPanel.subjects` key. `VolumeSubjectsChips` itself survives — its volume-browser and People-detail surfaces are untouched; only the document-panel embed dies |
| **D2** | **iPhone sheet persistence** (incl. the fresh-install trap: the key defaults `true`) | **As recommended:** keep the binding; auto-present under explicit `.research`; swipe-dismiss writes `false`; on iPhone the *unset* key reads `false`; sheet folds into `DocumentSheet` |
| **D3** | **iOS floating bar vs the system edit menu** | **As recommended:** bar below the selection on iOS, above on macOS; system menu kept |
| **D4** | **Scroll + zoom behavior of the bar (v1)** | **As recommended:** hide on scroll + hide while pinch-zoomed; live tracking later |
| **D5** | **"N documents" count fix.** The caption is the user-facing collection-size subtitle on the rail's membership rows (mock 02: "Cold War Origins · 14 documents") AND on both existing Add-to-Collection pickers; all derive from `documentEntries?.count`, which post-Composer also counts headings/prose/excerpts/apparatus | **As recommended:** count only `entryKind == .document`, in the rail and back-ported to both pickers |
| **D6** | **MacDocumentWindowView toolbar composition** (no toolbar exists today; designer never drew one) | **As proposed:** identity pill + rail toggle only |
| **D7** | **Panel state under Stage Manager** (process-global `panelVisible`) | **As recommended:** accept for v1; per-window seed is a follow-up |
| **D8** | **iPad "Open in New Window" home** | **As recommended:** trailing icon in the rail header |

Settled by the handoff, recorded as notes (not decisions): the rail-toggle glyph stays
`doc.text.magnifyingglass` (its ~12 existing uses are all decorative empty-state art, not actions); the
handoff Overview's "10 → 4 controls" undercounts its own §1 enumeration — **5** trailing controls
(Search · Browse · Analytics · My Research · toggle) is the correct reading and what this plan implements.

## 5. Cross-cutting rules (all phases)

- **JS parity discipline:** every `kSelectionJS` edit mirrors byte-identically into `Resources/frus-selection.js`;
  `SelectionScriptParityTests` enforces it. The tripwire test greps the literal `start: -1, end: -1, text, blockText`
  — append new fields **after** `blockText`.
- **Dual settings views:** any Read/Research copy change lands in BOTH SettingsView.swift (:3452-3484) and
  FRUSSettingsView.swift (:344-356).
- **Localization:** most current visible labels are raw literals (only `.help` tooltips are keyed). All *new*
  strings use `String(localized:)`; migrated grid labels get keys as they move.
- **Shortcuts:** ⌘⌥R / ⇧⌘K are declared twice today (scene + toolbar button) and coexist. Per the handoff,
  keep the shortcuts **visible on the menu items**: move each toolbar-button declaration onto its menu item
  1:1 (status-quo count of two declarations — do not add a third). ⌘⇧R keeps its Document-menu home (retitle
  to rail vocabulary); ⌘⇧H per-color highlight submenu stays as the keyboard parallel of the bar's dots.
- **Popover anchoring:** Cite/Share popovers get per-tile presentation state (SupportingViews:118-129 documents
  the shared-anchor SwiftUI bug).
- Rail tiles call `openWindow` **directly** (no pending-observer indirection) so standalone document windows work.
- **Design-token & micro-spec checklist** (each lands with the phase that builds the surface; system-first per
  the handoff's Fidelity note): rail bg `underPageBackgroundColor`-adjacent + hairline separators
  `black.opacity(0.06–0.09)` + badge pill `black.opacity(0.08)` (C1); tile bg `secondary.opacity(≈0.04)`
  radius 8, labels `.caption2` (C1); rail toggle active = accent on `accent.opacity(0.12)`, radius 6 Mac /
  circle iPad+iPhone, tooltip "Research panel (⌘⇧R)" (C1/C2/D); toggle + accordion animation
  `.easeInOut(0.2)` / 0.15 s (C1); thin toolbar dividers between titlebar groups (C2); rail-off **generous
  reading margins** (~110 pt at 1240 — widen the reading column's max-width padding when no rail is mounted, C2);
  edge chevrons 34 pt, `black.opacity(0.05)` fill, vertically centered (C2); selection-bar shadow
  `0 10 30 black 35%` (B); iPhone sheet drag indicator visible (D).

## 6. Phases

Each phase is one PR, builds green on both platforms, and leaves the app fully usable. **Order matters:**
the floating bar (B) lands *before* the strip is deleted (C1) — the strip's Excerpt and NARA verbs are the
only macOS surfaces for those actions (no Document-menu fallback exists: `DocumentCommandActions` carries
highlight/addNote but neither excerpt nor NARA), so building the bar first means the two coexist harmlessly
for one PR instead of leaving a regression window.

### Phase A — Selection-rect bridge (S)
Plumbing only; no visible change. Unblocks Phase B.
1. `kSelectionJS` + `frus-selection.js`: add `rect: {x,y,w,h}` (`range.getBoundingClientRect()`, viewport
   coords) to both `selectionChanged` payloads (ranged :246, footnote :257 — rect after `blockText`); add a
   passive capture-phase scroll listener posting a throttled `selectionScrolled` hide signal; include
   `visualViewport.scale`.
2. `FRUSSelectionEvent`/decode (FRUSDocumentWebView:14-42): carry `CGRect?` + scale — **replace the 4-tuple
   callback with a small payload struct** (5th positional param is past the readability line); register the new
   handler name alongside `selectionChanged` (FRUSWebViewConfiguration:68).
3. Store rect in `HighlightCoordinator` (macOS; clear in `reset()`) and iOS `@State`, beside the existing text
   preservation — do not disturb the survive-clear contract (C4).
4. Tests: decode cases (rect present/absent/malformed, scale), parity suite, tripwire intact.

### Phase B — Floating selection bar (L)
Both platforms, both modes. Coexists with the strip until C1 (harmless one-PR duplication of its selection verbs).
1. `FloatingSelectionBar` view: dark pill (`rgba(28,28,30,0.95)`, radius 10-12, shadow `0 10 30 black 35%`,
   fadeUp ~0.25 s) — 4 dots (`DocumentHighlight.Color.allCases`, calling `createWebKitHighlightAction` / iOS
   `createHighlight`) · divider · Excerpt (`text.quote` → `makeExcerptCaptureAction` + picker) · Look Up
   (`magnifyingglass.circle` → NARA hand-off incl. `blockContext`) · Note (`note.text.badge.plus`).
   iPhone: icons only.
2. Anchoring: macOS — wrap the web view in a ZStack/overlay (none exists today, :369-413) so the rect maps 1:1
   (magnification never enabled). iOS — anchor in the existing ZStack (:1426), rect × zoomScale + insets;
   **below** the selection (D3); clamp to bounds.
3. Visibility is **new state** (bar-visible ≠ selection state): show on settle, hide on true clear /
   scroll signal / zoom (D4) with a ~200 ms debounce against the false-clear blur race (DocumentView:257-264 —
   the documented overflow-menu blur). Actions consume the preserved snapshot
   (`webKitSelectedText` / `lastValidSelectionRange`), exactly like the strip's NARA/Excerpt buttons today.
4. Footnote selections (`FRUSSelectionEvent.footnote` — no offsets): dots + Excerpt disabled; Look Up + Note active.
5. After highlight creation: one-shot "Add Note to Highlight" swap (existing `pendingHighlightLink` flow).
6. iOS: remove the two custom edit-menu verbs (`_FRUSEditMenuWebView.buildMenu` :514-541 + wiring :1485-1498);
   system menu remains (Copy etc.), bar sits below the selection.
7. Tolerate nil action closures during `HighlightCoordinator.reset()`→re-register (.task :215) navigation gap.

### Phase C1 — Shared ResearchRailView + macOS adoption (L)
1. New `ResearchRailView` (new file, shared iOS/macOS): `RESEARCH` header (FRUSTheme sectionLabel tokens,
   :185-187) · 3×2 `LazyVGrid` tiles (labels → `.caption2` per the FRUSTheme table :189-239; glyphs per handoff,
   Word Cloud = `WordCloudGlyph.symbol` = `textformat.abc`) · accordion stack **(four accordions per D1:
   Summary · Notes · Tags · Collections)**. Accordion content donated from `macResearchPanel` (:477-606) /
   `iOSResearchPanel` (:1633-1795), parameterized for the platform deltas the readers mapped (note editing:
   window vs sheet; summary block: `SummaryBlockView` vs `SummaryStripView`). Extract `panelSectionHeader`
   (:651-690) as the shared accordion header. **D1 removal rider:** the document-view Subjects sections
   (MacDocumentView:586-604, DocumentView:1774-1793) and the orphaned `…researchPanel.subjects` key
   declarations (MacDocumentView:112, DocumentView:273) are deleted — a documented retirement, called out in
   the PR + release notes; `VolumeSubjectsChips`' other surfaces (volume browser, People detail) are untouched.
2. **NEW Collections accordion** (last): membership query `#Predicate<CollectionEntry> { $0.volumeId == v &&
   $0.documentId == d && $0.kind == "document" }` (raw `kind` — computed `entryKind` isn't predicate-usable;
   without the filter, excerpt provenance rows create false memberships), grouped by `collection?.id`,
   nil-orphans dropped (deleteRule .nullify), A4 duplicates deduped; row count = entries filtered
   `entryKind == .document` (**D5**, back-ported to both pickers). "＋ Add to Collection" reuses the picker —
   **unify the two private per-platform `CollectionPickerSheet` twins into one shared picker** while touching them.
   New key `frus.document.researchPanel.collections`, mirrored in both key blocks.
3. macOS adoption: mount the rail **once, inside `MacDocumentView.webKitDocumentView` (:352)** as the trailing
   member of a new HStack — both hosts (MainWindowView and MacDocumentWindowView) get it for free, and the
   <900 pt breakpoint GeometryReader (C2.4) lives in the same view, avoiding host↔document plumbing. Delete the
   strip row from both hosts (MainWindowView :85-98; MacDocumentWindowView :1111-1123) and the bottom
   `macResearchPanel` mount (:415-418). Gate `volumeNavigationView` on `panelVisible` (C5). The bar (Phase B)
   already carries the selection verbs, so nothing regresses. `ResearchStripView` dies (keep `.help` keys).
4. **Add the minimal MacDocumentWindowView toolbar now** (D6: identity pill + rail toggle) — deleting the strip
   removes that window's only visible research affordance, and ⌘⇧R alone is not discoverable (C3/F2).
   The full MainWindowView titlebar collapse still waits for C2.
5. Keep `DocumentCommandActions` equality field `isResearchPanelVisible` (:622-626) intact — ⌘⇧R checkmark.

### Phase C2 — macOS titlebar collapse + geometry (M/L)
1. `trailingTools` (:209-344) 10 → 5: Search · Browse (`books.vertical` + label, rename of "Corpus", opens
   `frus.corpusBrowser`) · **Analytics** `Menu` (Corpus / Person / Cross-Ref Analytics · Chronology · Word Cloud)
   · **My Research** `Menu` (Research · Collections) · rail toggle (accent-on-`accent.opacity(0.12)` active
   state, tooltip "Research panel (⌘⇧R)"). Shortcut declarations move onto the menu items 1:1 (§5).
   Identity pill yields first at narrow widths.
2. File menu: `CommandGroup(after: .newItem)` "Open Document in New Window" via `\.documentCommands`
   (C2; replaces the strip's New Window verb).
3. Geometry: minWidth 700 → **640** (:967, rewrite the rationale comment); give the standalone document window
   scene a matching min; **overlay-below-~900 pt content width** via a GeometryReader co-located with the rail
   mount in `webKitDocumentView` (:352) — rail becomes a trailing overlay panel (leading shadow, × control per
   mock 04), document does not reflow; reading column never below ~340 pt. (The rail is a manual HStack/overlay,
   not `.inspector`: macOS `.inspector` always presents as a trailing split and cannot overlay — the handoff
   pre-authorizes the manual fallback for exactly this reason.)
4. Hover **edge chevrons** (rail-off): net-new `onHover`-revealed 34 pt circles (`black.opacity(0.05)` fill,
   vertically centered at the document edges) reusing `prevEntry`/`nextEntry` + `navigationPath.append`
   (:833-884 mechanics, `document.nav.*.help` keys); hidden at volume boundaries.

### Phase D — iPad + iPhone adoption (L)
1. `documentToolbar` (:950-1275) collapses to the rail toggle (back is free; circular glass treatment,
   accent-tinted when on, per the mock); delete the Read/Research segmented picker (:1047-1073) — move its
   edge-tap a11y hint onto the toggle — and the iPad notes-inspector toggle (:1276-1295). Summarize's home
   becomes the SUMMARY accordion (error alert :463-473 already survives rail-off); Open-in-New-Window
   (Stage Manager) lands per **D8**.
2. iPad: rebind the single `.inspector` (:648) to `panelVisible` hosting `ResearchRailView`; delete
   `showNotesPanel` + `notesPanel` (:282, :1999-2072). iPad Stage Manager document windows (the
   `DocumentWindowID` WindowGroup) host this same `DocumentView`, so they inherit the rail for free —
   shared panel state per D7.
3. iPhone: rail as sheet (`DocumentSheet` case, `.medium/.large` detents + drag indicator), D2 semantics;
   edge-tap gate re-derived so a *presented sheet* (not the persisted bit) suppresses zones.
4. Verify no presentation collisions with the consolidated `activeSheet` chain + color-picker sheet (:530-620;
   the color-picker sheet itself retires — the bar's dots replace it (its three triggers die in B6/C1/D1 —
   grep-verified nothing else presents it); keep the Document-menu path on Mac).

### Phase E — Polish, tests, docs (M)
1. Settings copy both platforms (D2 footer, "in-document Read/Research control" sentences, edge-tap wording);
   `DefaultDocumentMode` labels keep Read/Research vocabulary (the concepts survive; only the control changed).
2. New UI tests: rail toggle round-trip (Mac + iPad), iPhone sheet detents, edge-chevron hover (Mac unit-level),
   obstruction suites re-run on iPhone + iPad destinations (#238 scenario unaffected but re-verify).
   Unit tests: collections membership query (kind filter, orphan, dedupe), bar visibility state machine.
3. Docs pass (house rule): both manuals' document-view + research-panel sections, README feature list,
   `EditableContent.md` + `IndexingEducationView` copy, TestFlight notes; `[SCREENSHOT]` placeholders for the
   owner's capture list. Fix the stale CLAUDE.md tab list ("Activity" → Research) while in there.
4. Localization sweep of every migrated label (§5).

## 7. Risks worth tracking

- **False-clear race** (C4/Phase B.3) — the single highest-risk interaction; mitigations specified, verify on
  device both platforms.
- **AppStorage global panel state** ×Stage Manager (D7) — accepted, documented.
- **`defaultDocumentMode` rewrite-on-open** can yank other windows' rails (MacDocumentView:206-213 fires per
  open) — make the write only-when-changed in Phase C1 (one-line guard).
- **Accordion expansion keys are cross-platform-shared** — an expanded-on-Mac SUMMARY pre-expands past the
  iPhone medium detent; accepted (matches today's shared keys), revisit per-platform if it annoys.
- **No selection-verb regression window**: the B-before-C1 ordering exists precisely because the strip's
  Excerpt + NARA buttons are the only macOS surfaces for those actions (no Document-menu fallback) — do not
  reorder these phases.
- Read-only-store staleness after in-session reindex (#275 class) applies to rail content — reuse the
  post-reindex recreate/reload pattern.

## 8. Out of scope / deferred

- Document Subjects surface (D1): returns as a **separate view** (not an accordion, not the handoff's grid
  tile) once document-level tagging is refined (#261 gate). The volume-level chips live on in the volume
  browser meanwhile.
  - **SUPERSEDED 2026-08-22, by owner decision.** Both halves of D1 have now been discharged, in order.
    The separate view shipped first as the Topic Index (#1023) once the owner ruled the #261 gate met;
    #261 itself was then closed on measurement (the 579 anachronistic pre-1970 `AIDS` refs it gated on
    are now **0**). The owner then **explicitly overruled the "not an accordion" clause** and asked for a
    document-level display in the Research rail as a collapsible accordion above Summary — shipped in
    #308. So the rail now carries what D1 retired, deliberately and with the gate discharged rather than
    bypassed. Do not re-derive the original constraint from this line: read the overrule.
- List-variant action area (mock's Tweaks alternative) — back pocket.
- Live rect tracking during scroll; per-window rail state; Cite-in-titlebar variant (mock trade-off note).
