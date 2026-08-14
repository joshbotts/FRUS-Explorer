# FRUS Explorer iPad UI — Adversarial Review Against the iPad-as-Research-Machine Bar

**Date:** 2026-08-13 · **Version:** 1.1 — §8 Semantic Analytics addendum added 2026-08-14 · **Status:** review for owner + fix worklist (Claude Code-consumable).
Companion figures: `Docs/screenshots/ipad/*.png` — annotated versions in `iPad-UI-Adversarial-Review.html` (self-contained, this folder). Fig 3 refers to `sidebar-landscape.png` rotated upright.

**The bar this review applies, as the repo itself set it:** MainTabView's version history 1.8 adopted
`.sidebarAdaptable` to give iPad "the macOS-like layout researchers expect on a keyboard/trackpad iPad."
So the bar is not "the iPhone app runs on iPad" — it is: a researcher with an 11–13″ iPad, a Magic
Keyboard, and Stage Manager should get a first-class research instrument. Portrait, landscape, Stage
Manager, and Apple HIG compliance are all in scope; every claim is cited to file:line at branch `v2`
(tree `29ad7485`, read 2026-08-13).

**Inputs:** full read of the iOS shell and per-tab roots (`MainTabView`, `ContentView`,
`FRUSExplorerApp` scene/commands regions, `BrowserView`, `SearchView`, `ResearchView`,
`SettingsView`, `CollectionListView`, `CollectionEditorView`, `DocumentView`, `ResearchRailView`,
`AnalyticsView` iPad branches, `OnboardingView`, `FacetPanelView`, `HTMLTemplate`, `FRUSTheme`);
the four committed iPad screenshots; `Docs/screenshots/README.md`; the prior audits this repo
already keeps (`Planning/Dynamic-Type-Worklist.md`, `Planning/Archival-Analytics-Adversarial-Review.md`);
bounded greps for `keyboardShortcut|hoverEffect|draggable|dropDestination`, `UIFindInteraction`,
`horizontalSizeClass`, `userInterfaceIdiom`.

---

## 1. Verdict up front

The iPad app is an iPhone app given the whole screen. After #238's retreat from nested
`NavigationSplitView`s — a retreat this review agrees with, given the iPadOS 26 occlusion defect it
fixed — every tab became a full-width, single-column `NavigationStack`, and no iPad-shaped layout
was built in its place. The plumbing underneath (per-window tab state, scene-addressed hand-offs,
restorable window scenes) is unusually good; the surface on top of it under-delivers in three
systemic ways:

1. **Width is spent, not used.** The reader renders body text with no maximum measure —
   ~190 characters per line on a 13″ landscape iPad against a 45–75-character readability norm —
   and every tab root (Browse, Search results, Research, Collections, Settings) is a phone list
   stretched across the full screen. The one two-pane surface (the reader's Research rail) proves
   the app knows how; nothing else does. (F-1…F-5)
2. **The keyboard/trackpad iPad the code names does not exist in the code.** The entire
   `.commands` block — Document, Find, Collection, Analytics, Research menus, every reading
   shortcut — is `#if os(macOS)`. An iPad with a Magic Keyboard gets no ⌘F, no find-in-document
   at all (the iOS web view never enables `UIFindInteraction`), no prev/next-document keys, no
   drag and drop anywhere in the app, and no pointer affordances. (F-6…F-10)
3. **Analysis is modal on the platform's biggest canvas.** All five analytics surfaces open as
   sheets over the Browse tab; search facets are a transient sheet over the results they filter;
   the Research Guide is five levels deep behind Settings ▸ About. macOS gives these windows and
   persistent panels; iPad — the device with the screen for them — gets interruptions. (F-11…F-16)

Alongside these: the iPad loses navigation context its own iPhone build keeps (breadcrumb
suppressed at regular width over a five-level hierarchy), search rows double-number themselves and
leak archival source notes into titles, the reader ignores the system Dynamic Type setting, and the
committed iPad screenshots + user manual advertise a split-view Browse that no longer ships.
None of this is data-layer work; with two exceptions (drag & drop, analytics windows) everything
below is view-layer and most of it is small.

## 2. What the review confirms is working

Credit first, because several hard things were done right and the recommendations lean on them:

- **The #238/#272 retreat was correct and is honestly documented.** A `NavigationSplitView` nested
  in the `.sidebarAdaptable` TabView genuinely mis-computes its top safe area on iPadOS 26; the
  guard rule ("tabs host a `NavigationStack`, not a split") is stated, enforced across all five
  tabs, and the old `splitLayout` is retained unreferenced for a one-line revert
  (`BrowserView.swift` `splitLayout` doc). The failure class chosen against — content occluded
  under the floating tab bar — is the right one to refuse.
- **Multi-window plumbing is genuinely good.** Per-window tab selection via `@SceneStorage`
  (#316) so Stage Manager windows stop mirroring; consume-once, scene-addressed hand-offs
  (#338/#752) with `.anyWindow` acceptance; value-based, restoration-safe `WindowGroup`s for
  Document / Source Explorer / Graph / Archival Neighbors / Related Documents; "Open in New
  Window" gated on `supportsMultipleWindows` instead of the wrong `sizeClass == .regular` proxy
  (`DocumentView` 3.5).
- **The idiom test is right where it matters.** iPhone-vs-iPad presentation splits use
  `userInterfaceIdiom` + size class, not size class alone, so Plus/Max iPhones in landscape and
  compact-width iPads (Split View/Slide Over) get the correct treatment — applied consistently in
  `DocumentView.isPhone`, `BrowserView.breadcrumbBarIfAppropriate`, `ProjectPickerMenu`.
- **The reader's Research rail is real iPad design.** Trailing `.inspector` on iPad, bottom sheet
  on iPhone, shared `panelVisible` mode bit, Stage Manager "open in new window" in the rail
  header (D8).
- **The Collections editor (Composer v2) is real iPad design.** Two roomy columns (outline +
  live preview) with settings summoned as sheets — the one tab whose iPad layout was actually
  redesigned rather than inherited (`CollectionEditorView.swift:729-767`).
- **Honest boot states** (#753 `BootPlaceholderView` instead of "Search Unavailable" lies),
  the #498 rotation-cycle fix with measurements, the iPadOS toolbar-overflow accessibility fix
  (Wave R / R-8) with a test seam, and the indexing banner's regular-width context card
  (`IndexingBannerView.swift:159`) are all quality iPad-specific work.
- **A Dynamic Type program exists** (`Planning/Dynamic-Type-Worklist.md`): 346 fixed-size sites
  surveyed, iOS-primary surfaces converted, discrimination rules written down. (The reader's own
  exemption from Dynamic Type is F-22 — the worklist never looked inside the web view.)

---

## 3. Findings

Ordered within themes; severity stated per finding. **24 findings: Critical ×2, High ×9, Medium ×9, Low ×4.**

### A. Width: the screen is spent, not used

#### F-1 · CRITICAL — The reader has no maximum measure: ~190-character lines on 13″ iPad

`HTMLTemplate.documentCSS` styles the document body with
`.frus-document { padding: 24px 48px 48px; }` under an explicit comment: *"No max-width: the
WKWebView fills the window and the user can resize freely"* (`FRUSExplorer/TEI/HTMLTemplate.swift`,
static CSS). That rationale is a macOS rationale — on iPad the "window" is the screen. On an
iPad Pro 13″ in landscape with the rail closed, body text runs ~1,270 pt wide at the default
~17 px size: **roughly 180–200 characters per line**, against the 45–75-character typographic
norm and the HIG's readability guidance. Fig 1 (the repo's own `ipad/document.png`) shows a
Kennan memorandum rendered as wall-to-wall text. Portrait is marginal (~110 CPL); landscape is
unreadable; Stage Manager half-width is accidentally the best reading size the app offers.
The fix is one CSS rule (`max-width` ~65–70ch + centered margins), optionally
width-responsive. This is the single highest-value/lowest-cost change in the review. (§6 R-1.)

#### F-2 · HIGH — Every tab root is a phone list stretched to full width

With `splitLayout` retired, all five tabs render their root list across the entire content width:

- Browse: subseries rows ("1969–76 · 66 volumes") spanning ~1,190 pt — `BrowserView.swift`
  `body` routes every size class through `stackLayout` (#238 Fix B).
- Search: result rows and their snippet paragraphs at full width, `.listStyle(.plain)` —
  `SearchView.swift:1665-1761`; Fig 2/3.
- Research: a root list of ~6 category rows, then a pushed full-width document list —
  `ResearchView.swift` `navigationContainer` (#272; macOS keeps its split).
- Collections: `.insetGrouped` list of collection names — `CollectionListView.swift:107,256`.
- Settings: the root `Form` — `SettingsView.swift:97`.

No content column is capped, and no tab offers a second pane at regular width. The #238 guard
rule forbids *nested `NavigationSplitView`s*, not two-pane content: a plain `HStack` of
list + detail (the shape `CollectionEditorView.iPadCollectionLayout` already ships) or capped
readable widths are both compatible with it. The iPad currently has *less* layout than the
Research rail proves the codebase can do. (§6 R-2.)

#### F-3 · HIGH — The tab sidebar is five rows and dead space

`.sidebarAdaptable`'s sidebar representation exists so a tab app can grow real navigation on
iPad: `TabSection`s of saved searches, projects, collections, recent volumes. `MainTabView`
declares five flat `Tab`s and nothing else, so the expanded sidebar is five rows above ~900 pt
of empty column (Fig 3, the repo's own `sidebar-landscape.png`). The researcher's own objects —
projects (`ProjectPickerMenu` exists), saved searches (`SavedSearchesView` exists), collections —
all live behind toolbars and tabs instead. The sidebar is the free, Apple-sanctioned place to
surface them on iPad. (§6 R-2c.)

#### F-4 · MEDIUM — Analytics charts are phone-sized bands inside a page sheet

Corpus Analytics' time charts are fixed at `.frame(height: 280)` (six sites:
`AnalyticsView.swift:2018,2044,2096,2159,2245,2329`) and secondary charts at 220 pt
(`:2474,2488`); only the by-subseries/by-volume bar lists grow with row count (`:2528,2584`).
Inside the `.presentationSizing(.page)` sheet on a 13″ iPad (`BrowserView.swift` analytics
sheet), the chart — the entire point of the surface — occupies a ~280 pt band in a ~1,000 pt
tall sheet, with controls and captions filling the rest. The Dynamic-Type worklist explicitly
LEAVEs canvas heights fixed, which is right for *text scaling* but was never re-examined for
*surface scaling*. (§6 R-7 rider.)

#### F-5 · LOW — Onboarding dock stretches edge to edge on iPad

The onboarding "docked glass" panel is `frame(maxWidth: .infinity)` on iOS
(`OnboardingView.swift:194`) while macOS pins the whole window at 560×540 (`:154`). On a 13″
iPad the welcome copy, scope picker, and buttons stretch across the full screen; a capped
(~560–640 pt) centered dock is the already-designed macOS shape. (§6 R-2 rider.)

### B. Input: the keyboard/trackpad iPad does not exist in the code

#### F-6 · CRITICAL — Zero keyboard commands on iPadOS

The entire `.commands` block — About, Open Document in New Window, the **Document** menu
(prev/next document ⌘⌥↑/⌘⌥↓, highlight ⌘⇧H, note ⌘⇧N, Read/Research toggle ⌘⇧R), the **Find**
menu (Find in Document ⌘F, Search ⌘S, Citation Lookup ⌘⇧F), the **Collection**, **Analytics**,
and **Research** menus, plus `TextFormattingCommands` for the rich-text editor — is inside
`#if os(macOS)` (`FRUSExplorerApp.swift:1265→1400`; shortcut sites `:2705-3063`). iPadOS
renders `Commands` in the menu bar and the ⌘-hold HUD; this app contributes nothing to either.
The only iOS `.keyboardShortcut`s are `.defaultAction`/`.cancelAction` on sheet buttons (grep).
A Magic Keyboard researcher — the user 1.8 names — cannot search, page, highlight, annotate,
or even find-in-page from the keyboard. The `FocusedValue` routing the macOS menus use
(`\.documentCommands` etc.) is platform-neutral machinery; the gate is the only thing in the
way. (§6 R-3.)

#### F-7 · HIGH — No find-in-document, by any input, anywhere on iPad

`isFindInteractionEnabled` appears once in the codebase, in `MacDocumentView.swift:1299`. The
iOS `FRUSDocumentWebView` never enables `UIFindInteraction`, no toolbar item invokes it, and
F-6 removes the ⌘F route. These are long diplomatic documents — the reading surface of a
*search app* cannot be searched within a document on iPad, while macOS has a Find menu and an
in-page find bar. One property + one toolbar/menu item. (§6 R-4.)

#### F-8 · HIGH — No drag and drop, on the platform that is defined by it

Bounded grep for `draggable(`/`dropDestination` across `FRUSExplorer/` returns zero UI sites.
Nothing in the app can be dragged: not a search result into a collection, not a document into
a project or a second window, not selected text into a note, not a collection entry out to
Files. Every one of those flows exists as a sheet/menu verb (`CollectionPickerSheet`,
`CollectionAddDocumentsSheet`, Move Up/Down context actions), so the models and mutations
already exist — only the `Transferable` surface is missing. On iPad, drag and drop is not a
power feature; it is the platform's grammar. (§6 R-5.)

#### F-9 · MEDIUM — Pointer users get nothing; `.help` tooltips are macOS-only explanations

No `hoverEffect` anywhere; more importantly, per-control explanations ride `.help(...)`
(e.g. every Research-rail tile: `ResearchRailView.railTile(help:)`), which iPadOS does not
render. The rail's six cryptic glyph tiles ("Cite / Word Cloud / Sources / Graph / Related /
Share") were given tooltips *because* the captions are small (C1b review F5) — and the platform
where they shipped never shows them. Long-press context or a first-run hint is the iPad
equivalent. (§6 R-3 rider.)

#### F-10 · MEDIUM — Edge-tap page-turns have no iPad-appropriate alternative

Read-mode page-turning is invisible 56 pt edge-tap zones (`FRUSTheme.swift:412`,
`DocumentView` 3.1) — an iPhone-reader gesture. On iPad: no visible prev/next affordance
(macOS has chevrons), no keyboard equivalent (F-6), and the zones sit where a trackpad user
drags to select text near margins. The Settings toggle (3.4) mitigates accidental triggers but
doesn't add an iPad-native affordance. (§6 R-3 rider.)

### C. Modality: analysis is trapped in sheets

#### F-11 · HIGH — All five analytics surfaces are modal sheets over the Browse tab

Corpus Analytics, Chronology, Person Analytics, Cross-Reference Analytics, Archival Analytics
open exclusively as `.sheet`s from Browse's Analysis Tools menu (`BrowserView.swift` sheet
declarations; `MainTabView.archivalSheet`). None can sit beside a document; opening one hides
the corpus you were reading; comparing a chart against a document is impossible on the one
Apple device sized for exactly that. macOS gives every one of these a window and a menu. The
iOS aux-scene table (`FRUSExplorerApp.swift:65-75`) has five value-based `WindowGroup`s — for
Document, Source Explorer, Graph, Archival Neighbors, Related Documents — and none for
analytics. The repo's own archival review called this "the island problem" for one surface
(its F-3); it is the pattern for the whole family. (§6 R-7.)

#### F-12 · HIGH — Search facets are a transient sheet over the results they filter

`SearchView` presents `FacetPanelView` via `showFacetSheet` (`SearchView.swift:247`) on iPad
exactly as on iPhone. Faceting is an iterative loop — tap a year, watch the list narrow, tap a
person, back out one — and the sheet forces open→tap→dismiss per step, hiding the results it
is narrowing. `FacetPanelView.swift:355` says it directly: the panel is *"shared so R-1c's iOS
sheet renders the identical content; only the container differs."* The container is the finding:
at regular width it belongs in a trailing `.inspector` (the reader already ships that pattern),
leaving the sheet to compact widths. (§6 R-6.)

#### F-13 · MEDIUM — The Search→Analytics hand-off teleports the user across tabs

"Visualize in Corpus Analytics" on a capped result set writes `pendingAnalytics` and calls
`openTab(.browse)`; `BrowserView` then presents the sheet (`consumePendingAnalytics`). From the
user's seat: they tapped a link in **Search** and landed in **Browse** with a sheet; dismissing
it strands them in Browse with their query one tab away. The hand-off exists because only
Browse owns the sheet — a symptom of F-11 (windows or a shell-owned presenter would fix the
teleport for free). (§6 R-7 rider.)

#### F-14 · MEDIUM — The Research Guide is five levels deep, in Settings

On iPad the app's educational core (the Research Guide / `IndexingEducationView`, host of the
four Series Analytics dashboards) is reached via Settings ▸ About ▸ FRUS Research Guide — a
sheet presented from a pushed pane (`AboutView.swift:175-184`), already indicted by the
archival review (§8.2: "five levels deep in a reference modal") when it blocked relocating
analytics there. The Research tab — the guide's obvious iPad home — never mentions it. (§6 R-8.)

#### F-15 · HIGH — The reader shows the same AI summary twice, before the document

On iPad with the rail open (the default: `panelVisible` defaults true and `summaryExpanded`
defaults true), a summarized document renders the summary **twice simultaneously**: the
full-width summary strip above the document body (`DocumentView` layout item 2) and the rail's
Summary accordion (`ResearchRailView.summaryAccordion` → `SummaryStripView`). Fig 1 shows both
copies of the identical Kennan summary occupying the first screenful, pushing the document —
the primary content — below the fold in landscape. One surface should own the summary per
idiom: the rail on iPad, the strip on iPhone. (§6 R-9.)

#### F-16 · LOW — Title stutter in the reader

The document title renders in the inline nav bar (`navigationTitle`, `DocumentView`) and again
as the `h2.doc-heading` at the top of the web view — on iPad's wide nav bar the two sit ~40 pt
apart saying the same 15-word heading (Fig 1). Cosmetic, but it is the first thing every
document open shows. (§6 R-9 rider.)

### D. Navigation context

#### F-17 · HIGH — iPad gets less location context than iPhone in a five-level hierarchy

Browse is corpus → subseries → volume → compilation → document. On iPhone a breadcrumb bar
shows the full path; on regular-width iPad it is deliberately suppressed
(`BrowserView.breadcrumbBarIfAppropriate` → `EmptyView()`) because a pinned top inset is
occluded under the floating tab bar (#238). The stated substitute — "the tab sidebar and the
navigation back button convey location" — conveys exactly one level (the Back button's title).
Mid-volume, three compilations deep, the iPad user has strictly less orientation than the
iPhone user. The occlusion constraint is real; the answer is a different *container* for the
same information (the navigation-title `Menu`/path affordance, or the subtitle machinery
`workingOnSubtitle` already ships), not deletion. (§6 R-10.)

#### F-18 · MEDIUM — "Open in New Window" can silently no-op (known, unprobed)

`supportsMultipleWindows` is plist-derived; the scene-table doc itself flags that an iPad in
Full Screen Apps mode "may still report true — unprobed; #241 review"
(`FRUSExplorerApp.swift:65-67`). If true, the rail-header window button and Search's
"Open in New Window" context item do nothing, silently — the exact defect class (silent no-op
affordance) that 3.5 fixed for iPhone. Probe and, if confirmed, fall back to in-place push
with a one-time explanation. (§6 R-12.)

#### F-19 · MEDIUM — A restored document window can dead-end in a permanent spinner

The iOS scene table records it plainly: `DocumentWindowID` windows' "CONTENT dead-ends in a
permanent spinner when the volume is gone or boot loses the race (#323)"
(`FRUSExplorerApp.swift:71`). Stage Manager restores windows across relaunch; a researcher who
removed a volume relaunches into a spinner with no message and no door out. The honest-empty
pattern (#241's Archival Neighbors guard) already exists to copy. (§6 R-12.)

#### F-20 · LOW — The second-project nudge fans out to every open window

`.secondProjectNudge()` is addressed app-wide; the code comment concedes a Stage Manager
setup shows the alert "in one window, not all of them" only *if* it is later re-routed
per-scene (`MainTabView` #377 Phase 5 note). Today two windows both interrupt. Small, and the
consume-once machinery to fix it already exists. (§6 R-12 rider.)

### E. Content defects the big screen magnifies

#### F-21 · HIGH — Search rows double-number themselves and leak source notes into titles

`SearchResultRow` prefixes `result.documentNumber` ("251.") before `result.header` — and for
modern volumes the indexed header *already begins with its own number*, so rows read
**"251. 251. Memorandum From Nathaniel Davis…"** (`SearchView.swift:1826-1837`; Fig 2, rows
1–6 of the repo's own screenshot). The same rows show headers that run on into the archival
source note — "…( Rostow ) **Source: Johnson Library, National Security File, Country File,
Ger…**" — truncated mid-word at `lineLimit(2)`. One is a row-render fix (suppress the prefix
when the header starts with `\(num).`); the other is an indexing/header-extraction fix and
worth its own issue since it also pollutes citations and document titles. (§6 R-11.)

#### F-22 · MEDIUM — The reading surface ignores Dynamic Type

Document text size comes exclusively from the app's own `TextSizePreference` picker
(Settings ▸ Display), compiled into CSS variables (`HTMLTemplate.build(model:colorScheme:textSize:)`),
with `-webkit-text-size-adjust: none` pinning the web view against system scaling. The system
text-size setting — including accessibility sizes — changes every piece of native chrome but
not the one surface a researcher reads for hours. The Dynamic-Type worklist audited 346 native
sites and never looked inside the web view. Map the preference's default to
`UIFontMetrics`-scaled sizes (keep the in-app override as an offset). (§6 R-9.)

#### F-23 · LOW — "1 volumes"

`SubseriesRowView` renders `"\(group.totalVolumes) volumes"` unconditionally
(`BrowserView.swift`); the committed browse screenshot shows "1989–92 · **1 volumes**" and
"1950–55 · **1 volumes**" (Fig 4). Inflect, or use `^[\(n) volume](inflect: true)`. (§6 R-11.)

#### F-24 · MEDIUM — The committed iPad screenshots and manual advertise a UI that no longer ships

`Docs/screenshots/README.md` lists `ipad/browse` as "(portrait split view)" and
`ipad/sidebar-landscape` as "(landscape adaptive sidebar)" under **Captured** — but #238 Fix B
removed the Browse split; the shipped Browse is a full-width stack at every size class. The
iPad screenshots predate the app they document, the user manual inherits the claim, and the
README's re-capture list (which tracks staleness meticulously for macOS shots) never flags
them. This is the repo's own honesty bar applied to its docs. (§6 R-11.)

---

## 4. Assessment against the review's contexts

**Portrait.** Usable but under-designed: single columns everywhere, ~110-char reading lines,
facets/analytics modal. The best-behaved context mostly because it is closest to an iPhone.

**Landscape.** The worst context: F-1 at full force (~190-char lines), the sidebar rail's dead
column (F-3), full-width search rows (Fig 3). Landscape is also the posture a Magic Keyboard
forces — the same user F-6 disarms.

**Stage Manager.** The plumbing shines (per-window tabs, scene-addressed hand-offs, restorable
document windows) and the review found real polish there. Remaining: analytics can't be windows
(F-11), `supportsMultipleWindows` honesty unprobed (F-18), restored-window spinner dead-end
(F-19), nudge fan-out (F-20). Narrow Split View/Slide Over widths correctly fall back to
compact behaviors throughout (credit: the idiom+width gates).

**Apple HIG.** The clear compliance gaps, by HIG section: *Layout* — no readable margins /
max measure in the reader (F-1), no use of regular-width for supplementary columns (F-2);
*Keyboards* — no keyboard shortcuts on a text-research app (F-6, F-7); *Drag and drop* —
absent app-wide (F-8); *Pointing devices* — no hover affordances, tooltip-only help (F-9);
*Accessibility/Typography* — core reading surface exempt from Dynamic Type (F-22);
*Feedback* — silent no-op window buttons and spinner dead-ends (F-18, F-19). Toolbars,
tab bars, badges, sheets-vs-popovers, and hit targets otherwise audit clean — several
(badge dot semantics, toolbar overflow naming, 44 pt row targets via the #312 pattern) are
better than typical.

---

## 5. Does the #238 architecture make sense? — yes, and it is not the constraint

Worth stating because every layout finding traces back to it: the retreat to
NavigationStack-per-tab was forced by a real iPadOS 26 defect, is Apple's documented shape for
`.sidebarAdaptable`, and should stand. But the guard rule forbids only *nested split views*.
It does not forbid: capped content widths (F-1, F-2), custom two-pane `HStack`s at regular
width (the Collections editor already ships one), trailing `.inspector`s (the reader already
ships one), `TabSection` sidebar content (F-3), or additional `WindowGroup` scenes (F-11).
The iPad app's problem is not the architecture it retreated to — it is that the retreat was
treated as the destination.

---

## 6. Recommendations, priced

Effort tags follow the repo convention (S/M/L). ⊘ = no tracker issue exists today.
Ordered by value-for-cost against the bar.

- **R-1 (S) ⊘ — Give the reader a measure.** `max-width: 70ch; margin-inline: auto` (plus a
  wider landscape gutter) on `.frus-document` / `.footnotes-section` in
  `HTMLTemplate.documentCSS`. Verify edge-tap zones still sit outside the column. Fixes F-1;
  the print/export CSS is untouched.
- **R-2 (M) ⊘ — A width-discipline pass over the five tab roots.** (a) Cap list/content
  widths at regular width (Search results, Settings, Collections, Research). (b) Browse and
  Research gain plain two-pane content layouts at regular width — list + detail in an
  `HStack`, honoring the #238 rule (no nested splits), following
  `CollectionEditorView.iPadCollectionLayout` as the house pattern. (c) Populate the tab
  sidebar with `TabSection`s: saved searches, projects, recent volumes (F-3). (d) Rider:
  cap the onboarding dock (F-5).
- **R-3 (M) ⊘ — iPad keyboard commands.** Lift the Document and Find menus (and the
  formatting commands the rich-text editor needs) out of `#if os(macOS)`; the
  `FocusedValue` routing is already platform-neutral. Minimum viable set: ⌘F find-in-document,
  ⌘S Search tab, ⌘⌥↑/⌘⌥↓ prev/next document, ⌘⇧N note, ⌘⇧H highlight, ⌘⇧R rail toggle.
  Rider: long-press/context equivalents for `.help`-only explanations (F-9) and a visible or
  keyboard page-turn affordance (F-10).
- **R-4 (S) ⊘ — Find in document on iPad.** Enable `UIFindInteraction` on
  `FRUSDocumentWebView`, add a Find toolbar/menu item, wire ⌘F to it (with R-3).
- **R-5 (M) ⊘ — First drag-and-drop pass.** `Transferable` on `DocumentBrowserEntry` /
  search results; drop targets on `CollectionListView` rows and the collection editor
  outline; drag selected text out of the reader as an excerpt. The mutations all exist
  behind sheet verbs already.
- **R-6 (S) ⊘ — Facets become a trailing inspector at regular width.** The panel is
  container-agnostic by its own doc comment; keep the sheet for compact. Also satisfies the
  facet loop's watch-it-narrow requirement.
- **R-7 (M–L) ⊘ — Analytics get windows on iPad.** Value-based `WindowGroup`s for the five
  analytics surfaces (the deep-link initializers #825/R-2e already call for), offered as
  "Open in New Window" beside the sheet path when `supportsMultipleWindows`; a shell-owned
  presenter kills the F-13 tab-teleport for the sheet path. Rider: charts adopt flexible
  heights inside the page sheet (F-4).
- **R-8 (S) ⊘ — Surface the Research Guide on the Research tab.** A row/door on the Research
  root (the guide window/sheet already exists); leaves the Settings ▸ About door in place.
  The archival review's contingency (§8.4) explicitly anticipated this move.
- **R-9 (S) ⊘ — Reader dedup + Dynamic Type.** (a) On iPad, the rail owns the summary; the
  top strip renders only when the rail is closed (F-15). (b) Suppress the in-body `h2` or the
  nav-bar title duplication (F-16). (c) Map `TextSizePreference` through `UIFontMetrics` so
  the default tracks the system size, keeping the picker as an offset (F-22).
- **R-10 (S) ⊘ — Restore location context on iPad.** Path menu on the navigation title (the
  Files-app pattern) or the existing subtitle machinery — same information as the suppressed
  breadcrumb, in a container the floating tab bar cannot occlude (F-17).
- **R-11 (S) ⊘ — The paper cuts, filed together.** Double numbering suppression + a header
  extraction issue for the "Source:" leak (F-21); "1 volumes" inflection (F-23); re-capture
  the four iPad screenshots post-#238 and correct the README/manual captions (F-24).
- **R-12 (probe, S) ⊘ — Honesty probes.** (a) Measure `supportsMultipleWindows` in Full
  Screen Apps mode on-device; add the fallback if it lies (F-18). (b) Honest empty state for
  the restored document window whose volume is gone (F-19, pattern exists). (c) Route the
  second-project nudge per-scene (F-20). (d) #657's device backtrace (plan item B-1) stays
  open — the badge fix is "a suspect removed, not a proven fix" (`MainTabView` 1.13).

**Sequencing.** Wave 1 (one polish session): R-1, R-4, R-6, R-9, R-11 — all S, all view-layer,
and R-1 alone transforms the app's core surface. Wave 2 (the input session): R-3 + R-5 — this
is what makes the "keyboard/trackpad iPad" sentence true. Wave 3 (the layout session): R-2,
R-10. Wave 4: R-7, R-8. R-12's probes ride any wave.

---

## 7. Worklist table (for tracker enrolment)

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-1 | Reader measure (CSS max-width) | F-1 | S | 1 |
| W-2 | UIFindInteraction + Find item | F-7 | S | 1 |
| W-3 | Facet inspector at regular width | F-12 | S | 1 |
| W-4 | Reader dedup + Dynamic Type mapping | F-15, F-16, F-22 | S | 1 |
| W-5 | Paper cuts: double numbers, "Source:" leak issue, "1 volumes", stale screenshots | F-21, F-23, F-24 | S | 1 |
| W-6 | iPad Commands (Document/Find menus cross-platform) + help/page-turn riders | F-6, F-9, F-10 | M | 2 |
| W-7 | Drag & drop pass 1 | F-8 | M | 2 |
| W-8 | Width discipline + two-pane Browse/Research + TabSections + onboarding cap | F-2, F-3, F-5, F-17 (via R-10) | M | 3 |
| W-9 | Analytics windows + sheet-presenter consolidation + chart heights | F-11, F-13, F-4 | M–L | 4 |
| W-10 | Research Guide door on Research tab | F-14 | S | 4 |
| W-11 | Probes: multi-window honesty, restored-window empty state, per-scene nudge, #657 backtrace | F-18, F-19, F-20 | S | any |

---

## 8. Addendum (2026-08-14) — Semantic Analytics

**What shipped.** Build 37 adds a sixth analytics surface: the whole corpus as one Metal-rendered map
of its own language — 314,483 documents at precomputed coordinates, four colour lenses, region
labels, tap-to-open, lasso → working-corpus capture, volume-pole axis slices, and the family's shared
scope bar. On iPad it opens from Browse's Analysis Tools menu as a sheet (`BrowserView.swift:201-213`,
`:349`); on macOS the same view is a window, for a measured Metal reason the code documents. Claims
cite branch `v2`, tree `46cde737`, read 2026-08-14. **6 new findings: High ×1, Medium ×3, Low ×2**;
recommendations R-13…R-16; worklist W-12…W-15. Shared-defect cross-references: slice scale (Mac
M-18, iPhone P-15), raw-ID selection card (Mac M-19, iPhone P-16), export absence (Mac M-20, iPhone
P-17).

**Inputs:** full read of `SemanticAnalyticsView`, `SemanticMapSpikeView` (+ `SemanticMapModel`,
`SemanticMapSurface`), `SemanticMapLens`/`SemanticMapColouring`, `SemanticMapPicking`,
`SemanticMapLabels`, `SemanticAxis`, `BundledSemanticMap`, the iOS launcher and scene table,
`SemanticVectorsKit`, the Related Documents semantic pipeline (`SemanticSimilarityGenerator`,
`SemanticSharedTerms`, `SemanticFeedbackLog`/`View`), manual §13.8, and the two design documents
(`Vector-Embeddings-Semantic-Design.md`, `OS27-Semantic-Retrieval-Design.md`).

### 8.1 What the addendum confirms is working

- **This is the first iOS analytics surface that genuinely uses the iPad's width.** A map fills
  whatever it is given; there is no stretched phone list here (the F-2 contrast), and the label
  layer, camera, and picking are resolution-independent by construction.
- **It avoided the `.help` trap this review filed as F-9.** Meaning lives in visible cards — the
  selection card, the axis card, the lasso card, the legend — not in tooltips iPadOS never renders.
  The one `.help`-shaped lesson (six controls that drew and did nothing) is documented in-file with
  its guards.
- **The lasso is Pencil-grade interaction from plain gestures** — drawn, thinned, even-odd resolved,
  honestly truncated ("Saving the first 7,500 of N"), and its capture coverage is stated by the same
  `WorkingCorpusResolver` that will later resolve the corpus in Search.
- **The sheet-vs-window Metal difference is verified, not assumed**: the UIKit sheet renders and the
  AppKit sheet does not, and the iOS entry point's comment records the simulator verification
  (`BrowserView.swift:202-207`).
- **Caveat posture is the family's best**: the experimental header collapses to its warning instead
  of disappearing (a fixed one-way door), the layout caveat is permanent, scope lines carry
  denominators, and the scope-grain sentence ("whole volumes, 12 of 552") pre-empts the obvious
  misreading.

### 8.2 Findings

#### F-25 · HIGH — The sixth analytics sheet: the new surface adopted the modality F-11 indicts, and buried a reader inside it

Semantic Analytics is a `.sheet` over Browse (`BrowserView.swift:201-213`) — the sixth member of the
F-11 family, on the platform whose screen the map wants most. The macOS manual sells the exact
workflow iPad cannot have: "it opens in its own window, so you can leave the map beside a document"
(`macOS-User-Manual.md §13.8`). The iOS aux-scene table still has no analytics `WindowGroup`, and
unlike its siblings this sheet does not even declare `.presentationSizing(.page)`. Worse, Open
Document pushes `DocumentView` **inside the sheet's own stack**
(`SemanticMapSpikeView.swift:769-776`, `:1233-1241`): the full reader, inside a modal, over Browse —
dismiss the sheet and both the map and the document are gone, with no "Open in New Window" offer on
the device that has Stage Manager. The MTKView-in-sheet constraint is macOS-only by the code's own
verification, so on iPad the modality is a choice, not a Metal limitation — and this surface is the
strongest argument yet for R-7's analytics windows. (R-13.)

#### F-26 · MEDIUM — The slice is an unlabelled chart, and undated volumes plot silently at mid-axis (shared)

A slice lays out x = projection onto the chosen axis, y = volume coverage-midpoint year
(`SemanticMapModel.setSlice`) with **no scale of any kind**: no year ticks, no pole names at the
plane's edges, no statement of which end is early. The semantics ride in a two-line `.caption2`
sentence. And `SemanticMapSpikeView.swift:519` plots any volume without a parseable coverage year at
the exact vertical centre — an unknown date drawn *as* a mid-century date, on the surface built to
say what is and is not a measurement. Full analysis at Mac M-18. (R-14.)

#### F-27 · MEDIUM — The selection card leads with raw IDs and passes them into the pushed reader (shared class)

The card headline is `frus1969v12 · d45` (`SemanticMapSpikeView.swift:1135`); Open mints
`header: "frus1969v12 — d45"` (`:1238`) for the pushed `DocumentView`. No volume title, no date —
yet the scope bar on the same screen already resolves titles from the manifest. F-21's raw-surface
family, on a brand-new surface. (R-15.)

#### F-28 · MEDIUM — No export, no share, no Handoff (shared)

The map offers no figure (PNG/PDF), no CSV, and publishes no `userActivity` — an analysis a
researcher builds on the iPad (a scoped map, a slice, a lasso) cannot leave the device or continue on
the Mac, in an app whose manual §13.9 promises every analytics chart an exit. The lasso → corpus is
the only door and it feeds Search. Mac M-20 carries the export analysis; the Handoff gap is iPad's
own — documents already publish activities, analytics never has. (R-16.)

#### F-29 · LOW — Region names are inert; the artifact's era data has no reader

Labels draw with `.allowsHitTesting(false)` — no tap-to-zoom, no region card — while the bundled
artifact carries per-region `eraCounts` "so a cluster tooltip can say *when* as well as *what*"
(`SemanticVectorsKit/SemanticMapArtifacts.swift:59-61`), shipped and read by nothing. On iPad the
missing affordance is also the missing zoom aid: tapping a label is the natural touch route into a
region. (R-16 rider; opportunity O-3.)

#### F-30 · LOW — VoiceOver gets a named rectangle

iOS wraps the surface in `.accessibilityElement(children: .contain)` with the window's name — and
nothing inside: no regions, no selection, no slice state. The ready-made `labelledClusters` list
(name, in-scope count, centre) would back a region list/rotor almost verbatim. (R-16 rider.)

### 8.3 Recommendations, priced

- **R-13 (S–M) ⊘ — Give Semantic Analytics the first analytics window on iPad.** A value-based or
  singleton scene + "Open in New Window" gated on `supportsMultipleWindows`, exactly the R-7 shape —
  this surface is its best pilot (Metal map beside a document is Stage-Manager-grade work). Interim
  rider: `.presentationSizing(.page)` for parity with the sibling sheets, and route Open Document
  to a document window instead of pushing the reader inside the sheet.
- **R-14 (S) ⊘ — Scale the slice** (shared fix with Mac MR-13): year ticks, pole names at the
  edges, undated volumes to a marked gutter or excluded with a count.
- **R-15 (S) ⊘ — Humane selection card** (shared with Mac MR-14): volume title + doc id headline,
  raw ids secondary, same header passed to the reader. Rider: double-tap-to-zoom — the missing
  iPad-native zoom affordance beside pinch.
- **R-16 (S–M) ⊘ — Exits and access:** figure/CSV export per §13.9 (shared with Mac MR-15);
  `userActivity` from the map (joins the analytics-Handoff idea in the iPhone review's PR-6);
  tappable region names (zoom + `eraCounts` breakdown); VoiceOver region list.

### 8.4 Foundations worth reusing — the semantic substrate × the visualization family

Six flags, each grounded in shipped code; the design doc's own ranking is
`Vector-Embeddings-Semantic-Design.md` §7.

- **O-1 · Result sets and corpora on the map.** `ScopeMask` is one byte per row but is only built
  from volume sets today; a document-key mask is the same array via `index.row(documentID:volumeID:)`.
  "Show on semantic map" from Search/corpora is the missing half of a loop the lasso already walks
  the other way — and it would give the F-13 hand-off a destination that isn't a tab teleport.
- **O-2 · A two-way bridge with Related Documents.** The similarity axis ships on this substrate
  (weight 0, experimental); the retrieval kernel's corpus scan is 1.43 ms. Selection card → "Similar
  documents" (works with zero downloads); Related rows → "Show on map." `SemanticSharedTerms` already
  computes the evidence chips.
- **O-3 · Region-share-over-time in Corpus Analytics.** Per-region `eraCounts` ship in the bundle
  (F-29) and nothing draws them; region × era stacked areas is the design doc's §7.3 and Swift Charts
  is already there. Highest value-per-effort flag: the data ships today.
- **O-4 · Pre-1900 rescue for Related Documents and the graph.** 46,234 documents have an empty
  Related list, 98.2% pre-1900 (`SemanticSimilarityGenerator` doc) — where citations and archival
  keys do not reach. Semantic neighbours as an explicitly-labelled experimental section lights the
  corpus's darkest region; the feedback loop already weights 19th-century verdicts highest.
- **O-5 · The renderer as a house substrate for large-N figures.** On-demand Metal point rendering
  with per-row flags, a pure-function camera, and measured picking is what the graph canvases (P-7's
  class) lack; on iPad it is also the LOD engine an analytics *window* family would want.
- **O-6 · Subseries poles.** 659 exact centroids ship (volumes *and* subseries); only volume poles
  are offered, via tapped documents. A subseries pole picker is data-ready; free-text poles stay
  correctly deferred.

### 8.5 Worklist additions

| # | Carries | Findings | Effort | Wave |
|---|---|---|---|---|
| W-12 | Semantic Analytics window on iPad + page sizing + reader un-burial | F-25 | S–M | rides W-9 |
| W-13 | Slice scale + undated gutter (shared: Mac W-14, iPhone W-12) | F-26 | S | 1 |
| W-14 | Humane selection card + double-tap zoom | F-27 | S | 1 |
| W-15 | Export + userActivity + region affordance + VoiceOver list | F-28, F-29, F-30 | S–M | 2 |
