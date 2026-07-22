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

- **macOS**: `Research ▸ Project Home` (**⌘P** — the owner is not implementing document
  printing, so plain ⌘P is free and is the natural "P for Project" mnemonic) opens/fronts
  the `frus.projectHome` window. Value-based on the active project id so it re-titles when
  you switch projects. *(Guard: since ⌘P conventionally means Print, add a `CommandGroup`
  that replaces `.printItem` so no stray system Print item competes for ⌘P.)*
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

### Phase 2 — Project-scoped search: two modes for two research phases  *(effort M–L)*

A Project has a **dual nature**, and search must honor both. Collapsing them into one
"search within this project" scope (the engaged set) — as the first draft did — only
serves the *retrospective* half and actively harms *discovery*. So Phase 2 ships **two
distinct, clearly-labeled search modes**:

#### Mode A — **Project Focus** (discovery / research-phase)  *— "What in the corpus fits this project that I haven't seen yet?"*
A corpus-wide search **actively scoped by the project's research focus**, to surface
**new, unengaged** material. It is NOT limited to what you've already touched. The focus
parameters map cleanly onto the existing `SearchParameters` filters:
- **Date range** → `SearchParameters.dateRange` (the project's `defaultDateRange`).
- **Subjects → volumes** → `SearchParameters.volumeIds`. This is the payoff of reviving
  `defaultSubjectTagIds` (owner decision #4): a project's subjects resolve, via the
  **volume-subject profiles** (`Browser/VolumeSubjectProfiles`, `volumeId → [ranked
  subjects]`), to the **set of volumes** whose profiles rank those subjects highly.
  Because subject data is volume-grain today, discovery-by-subject is *volume-scoped*,
  which is exactly what the `volumeIds` filter expresses. (When document-level tagging is
  re-integrated later, this tightens from volume-scope to document-scope with no UI change.)
- **"Only new to this project"** toggle → post-filters out the engaged doc-id set
  (collections + noted + visited), so discovery emphasizes what you *haven't* seen.
- The **research question** seeds suggested keywords (future: semantic ranking).

Net: a project's focus becomes a **discovery lens over the whole corpus** — the
research-phase filter the owner asked for, not a container of prior activity.

#### Mode B — **Project History** (recall / later-phase)  *— "Where did I see that, in my working set?"*
Restricts results to the project's **engaged documents** — its collections + noted +
visited + tagged docs. Retrospective recall over what you've already gathered. Needs a
document-id allow-list gate (a small `SearchParameters.documentIds: [String]?` addition,
or an FTS5 `IN (…)`), assembled from the project's tagged records. (`SearchParameters`
already has `projectId` + `userTagIds`, which cover the tag subset; collections/visits
need the doc-id set.)

#### Foundation (pulled forward from old Phase 4, because Mode A depends on it)
Revive `defaultSubjectTagIds` against the **volume-subject-profile vocabulary** and add a
resolver `project subjects → [volumeId]` (volumes whose profile ranks those subjects above
a threshold). This one piece powers Mode A's discovery scope, the Phase-4 editor surfacing,
and Phase 5's per-project volume scope. Country focus is **not** wired to discovery: there
is no country filter in `SearchParameters` today (`defaultCountryTagIds` is vestigial in
search) — leave it out of Mode A rather than fake it; revisit if a place filter ships.

Surfaces as a **two-way scope control** in Search when a project is active (Focus /
History / off), each clearly labeled so the researcher knows whether they're discovering
or recalling.

### Phase 3 — Project on export & citation  *(effort S–M)*
Carry the project (name + research question) into collection / research-data exports as
a provenance line/header (PDF/DOCX/HTML + the research-data JSON), so an exported working
set self-documents what project it belongs to. Touches `Collections/*Exporter*` +
`Export/ResearchDataExporter.swift`.

### Phase 4 — Surfacing & focus editing  *(effort S–M)*
- Show the active project's research question subtly in the Browse/Search chrome
  ("Working on: …") so the lens is visible while reading.
- A **focus editor** in Project Home / `ProjectEditorView`: date range + **subjects**
  (now live — picked from the volume-subject-profile vocabulary the Phase-2 foundation
  established, owner decision #4) — the controls that drive Mode-A discovery. (Subject
  focus stays *volume-grain* until document-level tagging is re-integrated, at which point
  the same control gains document-grain precision — a later expansion, per owner note.)
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

## 5. Owner decisions (2026-07-22)
1. **Project Home shortcut = ⌘P.** No document printing is planned, so ⌘P is free and is
   the "P for Project" mnemonic. (Add a `.printItem` `CommandGroup` guard so no system
   Print item claims ⌘P.)
2. **Phase order confirmed:** 1 → 2 → 3 → 4 → (5).
3. **Phase 2 = two modes** (see §3, Phase 2). The engaged-set scope is correct for
   **Project History** (recall) but wrong for research-phase **discovery**; discovery is a
   separate **Project Focus** mode — corpus-wide, scoped by the project's date range +
   subjects→volumes, with an "only new" toggle. Both ship.
4. **Revive `defaultSubjectTagIds`** against the **volume-subject profiles** (volume-grain
   for now; expands to document-grain when document-level tagging is re-integrated). This
   revival is the foundation Mode-A discovery depends on, so it's pulled into Phase 2.

### Still to confirm
- **Mode-A subject→volumes threshold**: how strongly must a volume's profile rank a
  project subject to be included in the discovery scope (top-N per volume? a min score?)
  — a tuning knob to settle during Phase 2 with real data.
- **Mode-B doc-id gate**: add `SearchParameters.documentIds: [String]?` (clean, explicit)
  vs. a post-filter over ranked results (no schema touch). Recommend the field.
