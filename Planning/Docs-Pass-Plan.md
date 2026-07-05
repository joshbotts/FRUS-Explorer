# Consolidated Docs Pass — Plan

**Date:** 2026-07-05
**Status:** Plan for review (recon complete; no doc edits made yet)
**Scope:** Bring every documentation surface current with everything shipped since **build 26** (PRs #169–#187), then bump the build. Testers are still on build 26, so this is the release that carries the entire analytics program + the Collections polish + the page-reference fix.

Built from a 7-surface reconnaissance sweep (iOS manual, macOS manual, README, both TestFlight files, the in-app Research Guide, and the screenshot checklist). ~70 itemized actions + ~24 new/regenerated screenshots. Line numbers are from the recon and must be re-verified at edit time.

---

## The feature set this pass must cover

| Ref | Feature | Where it lives |
|---|---|---|
| **A1** | Production & Timeliness dashboard (publication-year lag scatter + evolving 15/20/30-yr target line, volumes/print-year, cumulative) | Research Guide → About the Series |
| **A2** | Geographic Emphasis dashboard (regional share over time by State bureau) | " |
| **A3** | Archival Sourcing dashboard (provenance mix over decades) | " |
| **A4** | Administration Profiles dashboard (per-president; docs, volumes/admin-year, per-volume proportions, editorial-note toggle) | " |
| **A✻** | Cross-cutting: editable year range per dashboard + per-chart "View as table" pop-up (Copy-CSV) | " |
| **B5** | "% of documents" normalization toggle (By-Year/By-Decade) | Corpus Analytics |
| **B6** | Person Analytics (Trends: most-mentioned-by-era + trajectories; Network: co-mention ego-graph) | iOS Analysis Tools menu / macOS `frus.personAnalytics` |
| **B7** | Cross-Reference Analytics (in-degree, degree histogram, volume heat matrix, PageRank) | iOS Analysis Tools menu / macOS `frus.crossRefAnalytics` |
| **C8** | Collection note collapses to an "Add a note" affordance | iOS/iPad editor + macOS manager |
| **C9** | macOS Collections ribbon consolidated (Add ▾ / Sort by Date ▾ / View ▾ / Export…) | macOS manager (macOS-only) |
| **C10** | Sort by Date: "Across the Whole Collection" vs "Within Each Section" | macOS ribbon + iPad/iOS toolbar |
| **D** | Page-number cross-refs resolve correctly → **index bump to v21 → one-time re-index on update** | invisible except the re-index + Cross-Ref surfaces |

---

## Per-surface update plan

### 1. `Docs/iOS-User-Manual.md` (iPhone-first; ~765 lines) — 10 actions
- **§1 Introduction bullets** — broaden Analyze/Visualize bullets to name person analytics, cross-reference analytics, and the About-the-Series dashboards.
- **TOC + §3 tab table** — add Person Analytics, Cross-Reference Analytics, Series Analytics; revise Browse-tab row's Analysis-Tools list.
- **§4.4 Analysis Tools menu** — add "Person Analytics" + "Cross-Reference Analytics" entries; update the menu screenshot caption.
- **§8 Cross-Reference Graph** — (D) note page-number refs ("see p. 427") now resolve + the one-time re-index heads-up; **new §8.1 Cross-Reference Analytics** (in-degree / histogram / heat matrix / PageRank) + `[SCREENSHOT]`.
- **§10.1 Collection Manager** — (C8) note field now "Add a note" affordance; (C10) Sort by Date now two modes on the iOS/iPad toolbar.
- **§13.1 Corpus Analytics** — (B5) the "% of documents" toggle.
- **new §13.x Person Analytics** — Trends/Network modes + `[SCREENSHOT]`; cross-link from §4.5 People Browser.
- **new §19.1 About the Series** — the four offline dashboards + the cross-cutting year-range and View-as-table controls + `[SCREENSHOT]`s.
- **§16 / §3.1** — a re-index note (index v21) so users know why indexing runs after update.

### 2. `Docs/macOS-User-Manual.md` (~999 lines) — 14 actions (biggest Collections delta)
- **§3.5 Window Scenes table** — add rows for `frus.personAnalytics` + `frus.crossRefAnalytics` (verify exact open affordance in code).
- **§8** — (D) page-ref note + a re-index note near §16 storage.
- **§10 Collections — the largest rewrite:** the §10.2 "add menu" prose describes the **old 10-button/3-header ribbon** and must be rewritten to the **consolidated four-control ribbon** (C9); §10.3 "Composition group" → "View ▾ → Composition"; §10.5 eye button → "View ▾ → Preview"; §10.1 note → "Add a note" affordance (C8); **new §10.2a Sorting by date** (C10, both modes). Regenerate `collections.png`.
- **§13 Analytics** — (B5) normalization toggle; **new §13.5 Person Analytics** + **§13.6 Cross-Reference Analytics** (`frus.personAnalytics` / `frus.crossRefAnalytics` windows).
- **new §17.3a About the Series** — the four dashboards + cross-cutting controls.

### 3. `README.md` (top-level marketing summary) — 9 actions, no screenshots
- Add **Series Analytics**, **Person Analytics**, **Cross-Reference Analytics** feature bullets; extend the Corpus-Analytics bullet with **B5**; extend the Collections bullet with **C8/C9/C10**.
- Add `frus.personAnalytics` + `frus.crossRefAnalytics` to the macOS Window-Scenes table.
- Add a one-line "page-number refs now resolve → one-time re-index (v21)" note.
- Optional: a one-line "four analytics surfaces" framing sentence; optional manual-test-matrix rows.

### 4. `Docs/TestFlight-Instructions-ios.md` + `Docs/TestFlight-Instructions-mac.md` — the tester-facing "what's new"
- **Add a "What's new since the last build" teaser** (4–6 bullets) at the top of each.
- **The re-index (D) is the highest-priority tester note:** returning testers get a one-time automatic re-index (index v21) — expect indexing on first launch, watch Index Health, results incomplete until done; tie it to the page-ref fix.
- Add test steps for **Person Analytics**, **Cross-Reference Analytics**, the **About-the-Series dashboards** (note they work offline mid-onboarding — testable immediately), **B5**, **C8/C10** (iOS) and **C8/C9/C10** (mac); add feedback prompts for the new surfaces.
- **Cleanup:** the existing "New this build:" callouts describe **build 26** and now mislabel old features as new — demote them to plain prose so "new" means *this* build.

### 5. In-app FRUS Research Guide — `IndexingEducationView.swift` (localized `String(localized:)` prose) — code change
> **Recon correction (verified in code 2026-07-05):** the 4 dashboard pages have `sections: []`, but their **dashboard views already carry their own intro prose + per-chart captions + an "About these figures" caveats block** (`series.production.intro`, `series.geography.intro`, `series.provenance.intro`, `series.admin.intro`). They self-document. → **DO NOT add intro `EducationSection`s** to those pages — it would duplicate the in-view prose and force a dashboard-XOR-sections renderer change for no benefit. The dashboards need **no** guide-prose edit. This shrinks the in-app work to page 6/7 + doc-comments below.
- **Page 6 "Seeing the Bigger Picture":** add the (B5) normalization sentence to the Corpus Analytics section (its current color-coding sentence is about volume colors, not the % toggle); add a **Person Analytics** section (B6, cross-linked from page 5 "Person Index"); add a **Cross-Reference Analytics** section (B7) — the existing "Cross-Reference Graph" section covers the graph only, not in-degree/histogram/heat-matrix/PageRank. Optional: a one-line pointer to the "About the Series" dashboards (they render offline).
- **Page 7 "Working With Documents" → Collections section:** add a clause on the two Sort-by-Date modes (C10). (C9 ribbon is macOS toolbar layout — the cross-platform guide describes capabilities, not toolbars, so no C9 edit; C8 note-collapse is a minor optional clause.)
- **Doc-comment fix:** `IndexingEducationView`'s doc still says "Five pages" but `all` has **11** (7 prose + 4 dashboards); the `.aboutTheSeries` note and version history need entries. Required by the coding standard.

---

## New / regenerated screenshots for issue #106 (~24)

The doc edits insert `[SCREENSHOT: …]` placeholders; **you capture per #106** (I can't capture device shots). New rows to append, using #106's 🆕/🔄/⚙️ + `[iPhone]`/`[iPad]`/`[macOS]` conventions:

**iPhone (`ios/`):** 🆕 series-production · series-geography · series-archival · series-administrations · person-analytics-trends · person-analytics-network · crossref-analytics · analytics-table-popup · ⚙️ analytics (re-shoot with the % toggle on).
**iPad (`ipad/`):** 🆕 series-production (± the other three) · person-analytics-trends · person-analytics-network · crossref-analytics · analytics-table-popup · collection-sort-menu · collection-note-collapsed.
**macOS (`macos/`):** 🆕 series-production (± three) · person-analytics-trends · person-analytics-network · crossref-analytics · analytics-table-popup · collections-ribbon · collection-sort-menu · **🔄 collections (STALE — re-capture: consolidated ribbon + collapsed note)** · ⚙️ analytics (% toggle).

**Capture note:** the four Series dashboards render **offline** — capture on an empty/mid-onboarding install via Research Guide → About the Series (the recon adds this to `screenshots/README.md`).

---

## Decisions (resolved 2026-07-05)

1. **`iOS-Supplement.md`** → **DECIDED: fix issue #106, no new file.** Edit #106 so the iPad rows point at the existing iOS/macOS manuals + the `ipad/` screenshots. No supplement file is created.
2. **`Docs/EditableContent.md`** → **DECIDED: full re-sync now**, as part of this pass. Reconcile the entire file against the current `IndexingEducationView` 11-page structure (fix "five pages", SOURCE line ranges, add the page-6/7 + 4 dashboard blocks). Folds into **PR A** (it *is* the guide's reviewed source copy).
3. **Screenshots** → I add the `[SCREENSHOT: …]` placeholders + append the #106 rows; **you capture** on-device. (Default; say so if you want me to attempt simulator captures for any.)
4. **In-app guide prose depth** → a tight intro paragraph per dashboard (not a wall of text). (Default.)

## Recommended execution order (two PRs)

Collapsed to two PRs so the docs can land without cutting a build (testers stay on 26), and the build bump stays a deliberate, user-timed release trigger.

- **PR 1 — Consolidated docs pass** (branch `claude/consolidated-docs-pass`). No release impact; build stays 26. Sequential commits:
  1. this plan doc (`Planning/Docs-Pass-Plan.md`).
  2. **in-app guide** — page-6/7 prose additions + doc-comment/version-history fixes in `IndexingEducationView.swift` (localized) **+ full `Docs/EditableContent.md` re-sync**; builds + `CodingStandardsAuditTests`. (No dashboard-page prose — they self-document.)
  3. **written docs** — iOS manual, macOS manual, README, both TestFlight files, `screenshots/README.md` — with `[SCREENSHOT]` placeholders.
- **Issue #106 edit** (GitHub, not a commit) — append the new/regen rows; **fix the `iOS-Supplement.md` reference** to point at the main manuals.
- **You capture screenshots** per #106 (asynchronous; fills the placeholders over time).
- **PR 2 — build-number bump + release notes** (the non-xcodegen procedure). The ship trigger; merge when you're ready to cut the TestFlight build (after screenshots are in, if you like). Covers the whole feature set + the re-index note.
