# Projects Enhancement Plan (#377)

Filed from GitHub #377 ("Is there any value in the Projects 'soft filter' at this
point?"). Investigation outcome: **enhance** — multi-project work is core to the
owner's workflow, and the feature today is a coherent but *invisible* activity lens
that under-delivers on its own premise. This plan turns a Project from a silent tag
into a **visible, first-class research workspace**.

## 1. Where it stands today

A `Project` is *"an activity lens, not a content container"* (`Models/Project.swift`).
The active project silently tags the researcher's actions and soft-filters what they
see; all content stays global and switching is an instant `AppState.activeProjectId`
change, never a data migration.

**What's tagged** (the data the dashboard already has to work with):
- `ResearchNote.projectIds`, `Collection.projectIds`, `CustomVolumeScope.projectIds`
- `ReadingHistoryEntry.projectId`, `SearchHistoryEntry.projectId`
- generated summaries (via the active project at creation time)

**Where it surfaces today:**
- **Collections list** — soft-filters to the active project's collections, with an
  explaining banner + "Show All" override (`Collections/CollectionListView.swift`).
- **History** — a three-way project filter (`App/HistoryWindowView.swift`).
- **Search** — `SearchViewModel.applyProjectDefaults` pre-populates the date range +
  country tags when a project is active.
- **Management** — `ProjectContext/ProjectContextView.swift` (a sheet: switch / edit /
  merge / delete + an "Activity" section that only *links out* to the filtered lists);
  `GlobalContextView` (the no-project aggregate); `ProjectPickerMenu` (globe = global /
  folder = project) lives in the **Browse toolbar** on iOS and routes taps to the
  Research tab.

**Erosion signals ("at this point"):**
- `Project.defaultSubjectTagIds` is **inert** — dead since the document-level subject
  taxonomy was retired (Session 09). The project editor still shows the control.
- Onboarding **stopped promoting** Projects (v3.0: "project setup removed (created
  silently)"). Every user gets one silent "My Research" project, so for a
  single-project user the soft filter is a **no-op**. The multi-project value only
  appears once a user deliberately creates a second project — which nothing invites.

The feature isn't broken; it's under-surfaced and partly eroded. The enhancement makes
it pull its weight.

## 2. Design decisions (incl. the two open questions)

### D1 — Where does "Project Home" live? → **Research menu (macOS) / Research tab (iOS)**, as its own window/screen.

Yes: Project Home belongs in the **Research menu** on macOS. That menu (added in #363)
already groups the researcher's own-work surfaces — Research (⌘⌥R), Collections (⌘⇧K),
History. Project Home joins them as a new item that opens the active project's
dashboard **window** (`frus.projectHome`), consistent with the app's window-per-tool
model (Analytics, Collections, Search are all their own windows). Being its own window
is what lets it sit **alongside** the main window (answering D2).

- **macOS**: `Research ▸ Project Home` (proposed shortcut **⌘⌥J** — ⌘⌥P is taken by the
  Collection menu's "Show Preview"; "J" is free and mnemonic-neutral) opens/fronts the
  `frus.projectHome` window. Value-based on the active project id so it re-titles when
  you switch projects.
- **iOS/iPadOS**: Project Home is the **landing screen of the Research tab** (the tab
  the Browse-toolbar project picker already routes to) — the dashboard on top, drilling
  into the existing notes/tags/collections/highlights browser below. No separate
  "window" concept applies on iPhone; on iPad it can also be torn off via Stage Manager
  like the other surfaces.

Rejected alternative: folding the dashboard into the existing `frus.research` window as
its landing view. Cleaner in theory, but it conflates "browse my tagged documents"
(what Research is) with "my project workspace" (what Home is), and it can't be opened
*alongside* the main window the way D2 wants. Keep them as sibling windows that
cross-link.

### D2 — Does Project Home auto-open at launch, alongside the main window? → **No by default; opt-in via a setting; natural window-restoration otherwise.**

Recommendation: **do not force** a second window open on every launch. That would fight
the app's on-demand window model and the #363 Window-menu de-clutter direction, and it's
pure noise for the (currently majority) single-project users.

Instead, three complementary behaviors:
1. **Window restoration (free):** if you quit with Project Home open, macOS restores it
   on relaunch — so a power user who keeps it open gets it back automatically.
2. **Opt-in setting:** a Settings toggle **"Open Project Home at launch"** (default
   **off**). Turning it on opens `frus.projectHome` alongside the main window at launch.
   This is the switch the owner (a heavy multi-project user) flips; it stays out of
   everyone else's way.
3. **First-run nudge (Phase 4):** once a user creates a *second* project, offer a
   one-time "Projects help you keep separate research threads — open Project Home?"
   prompt, so the feature becomes discoverable exactly when it starts to matter.

Net: the owner can have Project Home present at every launch (setting on), without
imposing a two-window launch on single-project users.

### D3 — Platform parity
macOS gets the window + menu; iOS/iPadOS gets the Research-tab landing screen. Both read
the same tagged data and the same `activeProjectId`. No CloudKit schema change is needed
for Phases 1–4 (all data is already tagged); Phase 5 reuses `CustomVolumeScope.projectIds`.

## 3. Phased delivery

Each phase is an independent PR, base `v2`, with an adversarial review + on-device
verification. Ordered by value; 2–5 can be reprioritized freely after Phase 1.

### Phase 1 — Project Home dashboard  *(anchor; effort M–L)*
Turn `ProjectContextView`'s link-only "Activity" section into a real per-project home:
- **Header:** project name + **research question** (inline-editable — today it's buried
  in the editor), plus the project's date-range / country focus as chips.
- **Activity summary:** live counts — collections, notes, tagged documents, documents
  visited, searches run — from the already-tagged records.
- **Recent-in-this-project feed:** most-recent notes / visited documents / searches,
  each a jump.
- **Quick actions:** New collection in project · Open Research (this project) · Search
  (this project, Phase 2).
- **macOS:** new `frus.projectHome` window scene + `Research ▸ Project Home` (⌘⌥J).
  **iOS:** Research-tab landing screen.
- Reuses `ProjectContextViewModel` / `GlobalContextViewModel` + `ResearchDocumentEntry`
  aggregation; no new persistence.

### Phase 2 — Project-scoped search  *(effort M)*
Beyond today's default pre-population, add a real **"Search within this project"** scope:
restrict results to documents in the project's collections + documents the user has
noted/visited in it. Reuses FTS5 + the tagged activity as a document-id allow-list
(a post-filter over ranked results, or an FTS5 `IN (…)` gate). Surfaces as a scope
chip in Search when a project is active.

### Phase 3 — Project on export & citation  *(effort S–M)*
Carry the project (name + research question) into collection / research-data exports as
a provenance line/header (PDF/DOCX/HTML + the research-data JSON), so an exported working
set self-documents what project it belongs to. Touches `Collections/*Exporter*` +
`Export/ResearchDataExporter.swift`.

### Phase 4 — Surfacing & defaults cleanup  *(effort S–M)*
- Show the active project's research question subtly in the Browse/Search chrome
  ("Working on: …") so the lens is visible while reading.
- Make project defaults easier to set from Project Home.
- **Retire the dead `defaultSubjectTagIds` control** from `ProjectEditorView` +
  `applyProjectDefaults` (keep the stored field for CloudKit stability; just stop
  surfacing dead UI). Optionally re-point it at the live **volume-subject profiles**.
- Add the "second project created → open Project Home?" first-run nudge (D2.3).

### Phase 5 — Per-project default volume scope  *(optional; effort M)*
`CustomVolumeScope` already carries `projectIds`. Let a project pin a **default volume
scope** so Browse / Search / Analytics default to the volumes that matter for it, tying
the #258 custom-scope work to the project lens.

## 4. Non-goals / guardrails
- **No CloudKit removal or migration.** This plan is additive; `Project`, `projectIds`,
  and `projectId` stay exactly as they are on the shipped schema.
- **Single-project users stay unbothered.** Every new surface is either behind the
  project picker or a no-op when only the default project exists.
- **Docs pass** (Docs/ manuals + in-app ResearchGuide/IndexingEducation + README) closes
  the program once the shipped phases land.

## 5. Open questions for the owner
1. **Shortcut** for `Research ▸ Project Home` — proposed ⌘⌥J; confirm or pick another
   (⌘⌥P is taken).
2. **Phase order** after Phase 1 — default is 2 → 3 → 4 → (5). Reprioritize?
3. **Phase 2 scope semantics** — "within this project" = the project's collections +
   noted/visited documents. Include tagged-but-unvisited? (Recommend: collections +
   any tagged/noted/visited doc.)
4. **`defaultSubjectTagIds`** — retire the dead control (recommended), or revive it
   against the live volume-subject profiles?
