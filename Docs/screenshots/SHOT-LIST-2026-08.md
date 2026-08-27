# Capture checklist — the #1081 sweep, staged by session

**This is the CW-11 prep (W-2e): the owner's per-shot checklist for issue #1081's decision that
every committed capture is stale.** #1081 stays the shared tick-list; `README.md` stays the *how*
(simulators, status-bar override, window-capture methods, the Series-Analytics offline
convention). This file adds the one thing neither has: the shots grouped into **capture
sessions**, each with its device, its setup done once, and its route per shot — so the sweep is
four sittings, not thirty-one context switches.

Legend: 🆕 first capture · 🔄 re-capture under the **same filename** (manuals update with zero
edits) · ⚙️ special setup. iOS-manual shots are **iPad-first** (`ipad/`).

Before every iOS/iPadOS session:
`xcrun simctl status_bar <device> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`

---

## Session A — iPad, full corpus (iPad Pro 11″ simulator, Windowed Apps mode)

Setup once: full 552-volume corpus, index settled, a project active. Capture via
`xcrun simctl io <device> screenshot`.

| # | Shot | For | Route + what must show |
|---|------|-----|------------------------|
| A1 | 🆕 `ipad/research-rail.png` | iOS §4.2 placeholder | Open any document (landscape) → rail is the trailing inspector. Must show: RESEARCH header, the 3×2 tile grid (Cite · Word Cloud · Sources · Graph · Related · Share), and the Summary/Notes/Tags/Collections accordions beside the document text. |
| A2 | 🆕 `ipad/browse-root.png` | iOS §6 placeholder | Browse tab root: the volume search field, the People and Topics rows, and the "Browse by" tiles. |
| A3 | 🆕 `ipad/all-volumes.png` | iOS §6.1b placeholder | Browse ▸ All Volumes: the segmented Title/Published/Era/Length control, with decade headers visible in **Published** order. |
| A4 | 🆕 `ipad/administrations.png` | iOS §6.1c placeholder | Browse ▸ Administrations: the index with dimmed post-corpus presidencies, then the **Truman** drill with per-volume shares. (Two frames if one cannot show both.) |
| A5 | 🆕 `ipad/editors.png` | iOS §6.1d placeholder | Browse ▸ Editors: letter sections, with one row showing a "spellings merged" caption. |
| A6 | 🆕 `ipad/my-scopes.png` | iOS §6.1e placeholder | Browse ▸ My Scopes: the list; the scope editor with red minus rows and Add Volumes; the amber "Browsing within" banner over the subseries list. (Series of frames is fine — the banner frame is the load-bearing one.) |
| A7 | 🆕 `ipad/corpus-drill.png` | iOS §6.1f placeholder | A corpus drill: the amber coverage line, an indexed volume's titled rows, and an unindexed volume's gray rows with the Download button. |
| A8 | 🆕 `ipad/archives-axis.png` | iOS §6.1g placeholder | Browse ▸ Archives: the Provenance Types doors with counts; the Collections lens; a collection's detail (pushed) with its citing volumes. |
| A9 | 🆕 `ipad/clusters.png` | iOS §6.1h placeholder | Browse ▸ Clusters: labels, counts, era histograms; a cluster's drill with the coverage line and Save-as-Corpus; the map focused on the cluster after "See on the semantic map". |
| A10 | 🆕 `ipad/archive-visit.png` | iOS §14.8 placeholder | Collections ▸ a collection ▸ Archive Visit: a generated packet with a target's **two claim lists** visible, the **Options menu open** showing the repository scope, and the Share buttons. *(#1081 calls this slot `trip-packet.png` with an older caption — the manual's caption is newer; filename is the owner's choice, note it in the manual if it differs.)* |
| A11 | 🆕 `ipad/people-list.png` + 🆕 `ipad/people-detail.png` | iOS §6.5 (replace the two "(iPhone capture)" embeds) | Browse ▸ People: the alphabetical list; the reconciled "Kissinger, Henry A." detail. Capture only after the rollup consolidation settles (see README's People note). |
| A12 | 🆕 `ipad/analytics.png` | iOS §15.1 (replaces `ios/analytics.png`) | Corpus Analytics with **% of documents** on and the inline toolbar **Export** menu visible. |
| A13 | 🆕 `ipad/chronology.png` | iOS §15.7 (replaces `ios/chronology.png`) | Chronology on iPad. |
| A14 | 🔄 `ipad/sidebar-landscape.png` | iOS §4.1 | Landscape adaptive sidebar (now with the saved-searches/projects footer, #909). |
| A15 | 🔄 `ipad/search-results.png` | iOS §7 | Search results at regular width (facet inspector if open — the current chrome). |
| A16 | 🔄 `ipad/document.png` | iOS §4.3 | The reading view (70ch measure, current title bar — post-#888 two-line title if long). |
| A17 | 🆕 `ipad/stage-manager.png` ⚙️ | iOS §4.5 placeholder | Switch the sim to Stage Manager (Settings ▸ Multitasking & Gestures) → a document window beside a Related Documents window, main window behind. Switch back to Windowed Apps afterwards. |

New-slot backlog for Session A when time allows (all 🆕, wired in as they land — #1081 §5):
`ipad/collections-editor` (two-column manager with a section heading + prose row),
`ipad/source-explorer`, `ipad/cross-reference-graph`, `ipad/related-documents` (scope control +
Adjust weights + why-related chips), `ipad/crossref-analytics`, `ipad/archival-analytics`
(Collections mode, Central Files umbrella chip), `ipad/semantic-map` (Regions + caveat line),
`ipad/word-cloud` (Distinctive mode + eligibility line), `ipad/collection-sort-menu`,
`ipad/collection-note-collapsed`, `ipad/analytics-table-popup`, `ipad/analytics-export-menu`.

## Session B — fresh install (either simulator, no corpus) ⚙️

Erase a device (`xcrun simctl erase`) or reset content; do NOT pass `-hasCompletedOnboarding`.

| # | Shot | For | Route + what must show |
|---|------|-----|------------------------|
| B1 | 🆕 `ipad/onboarding-volumes.png` | iOS §2.3 | The Add Volumes step over the word-cloud backdrop. |
| B2 | 🆕 `ipad/series-production.png` | iOS §16.1 | Research Guide → About the Series → Production & Timeliness — offline by design (bundled aggregates; no index). Shows the editable year-range control and the wide layout. |
| B3 | 🆕 `ipad/series-geography` / `series-archival` / `series-administrations` | iOS §16 | The other three offline dashboards, same route. |

## Session C — macOS (one sitting, no simulator)

Main window full-screen as backdrop; `screencapture -R` per floating window; People sheets via
`screencapture -o -l <windowID>`. **18 re-captures keep their filenames** (macOS manual §-refs in
#1081 §3): `toolbar` (§4.1 — the consolidated trailing five: Search, Browse, Analytics ▾, My
Research ▾, rail toggle, centered id pill), `research-strip` (§4.2), `document` (§4.3),
`browser` (§6.1 — **also the macOS §6.1 placeholder's subject**: sidebar Browse section with All
Volumes selected, catalog in the detail column), `people-list` + `people-detail` (§4.4),
`search` (§7 — the current token row + titlebar picker, #922/#923), `saved-searches` (§7.5),
`cross-reference-graph` (§8.5), `research` (§9), `source-explorer` (§14), `analytics` (§15.1),
`analytics-table` (§15.1), `person-analytics-trends` + `person-analytics-network` (§15.3),
`chronology` (§15.7), `series-production` (§16), `collections` (§12.1 — the current window; the
old file shows retired chrome and is embedded nowhere until this lands).

Plus the second §14.8 placeholder: 🆕 `macos/archive-visit.png` — the Archive Visit sheet in the
Collections window, same content rule as A10.

New-slot backlog (all 🆕): `macos/crossref-analytics`, `macos/archival-analytics`,
`macos/semantic-map`, `macos/word-cloud`, and the four Series dashboards' remaining three.

Known-hard, unchanged (stay off this list until their capture problems are solved): the
Chronology hover magnifier (needs ScreenCaptureKit; route: date range 1869–1878, hover a year
bar), Live Activity / Dynamic Island (physical iPhone, active download).

## Session D — the repo README heroes (#1081 §6)

Three hero slots in the top table: `macos/search.png` and `macos/cross-reference-graph.png`
(both fall out of Session C) and the third — currently `ios/document-view.png` — where #1081
leaves the choice open: re-shoot it, or swap the slot for a current shot (the semantic map or
the Browse root) and delete the file. `Docs/EditableContent.md` and the dated copy embed the
same row and follow whatever the README does.

## After the sweep

- Delete the orphans (#1081 §7): `ios/browse-corpus.png`, `ios/search-results.png`,
  `ios/settings.png`, `ipad/browse.png`, `macos/collections-ribbon.png` — and
  `ios/document-view.png` only if Session D swapped it. (The old `macos/collections.png` is
  overwritten in place by Session C rather than deleted.)
- Swap the four iOS-manual embeds from `ios/` to the new `ipad/` files (A11–A13) and drop the
  "(iPhone capture)" captions.
- Remove the 13 `[SCREENSHOT: …]` placeholders as their images land; each caption above is the
  content contract for its slot.
- Add the build number of the capture run to `README.md` (the X-8 ledger rule: a screenshot is
  evidence about a build).
