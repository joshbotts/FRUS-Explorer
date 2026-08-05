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
- **Leads slot (filled by Phase 3):** reserve a "Suggested next / related to your
  collection" section — a placeholder in Phase 1, wired up in Phase 3.
- **Quick actions:** New collection in project · Open Research (this project) · Search
  (this project, Phase 2).
- **macOS:** new `frus.projectHome` window scene + `Research ▸ Project Home` (⌘P).
  **iOS:** Research-tab landing screen.
- Reuses `ProjectContextViewModel` / `GlobalContextViewModel` + `ResearchDocumentEntry`
  aggregation; no new persistence.

> **Shipped state (2026-07-23):** Phase 1 landed as #430; macOS is complete (window +
> `Research ▸ Project Home` ⌘P). iOS shipped a prominent **Research-tab row → sheet**
> (#431) plus a **Settings → Active Project** switcher (#433), not the originally-planned
> full Research-tab *landing* — the sheet was chosen to stay clear of the fragile
> one-deep `[ResearchSidebarItem]` nav path (#272/#238). The iOS surface's remaining
> rough edges are collected in Phase 1P below.

### Phase 1P — iOS/iPadOS Project Home polish  *(deferrable; effort S–M; slot in after on-device feedback)*

Refinements to the **iOS Project Home surface** after the Phase-1 ship (#430) + the
prominent entry (#431) + the switcher / rename / nav-fix follow-ups (#432/#433). Kept as
its own phase so Phase 1's dashboard logic stays done; this is presentation/routing polish
driven by real iPad use.

1. **Scene-aware routing** (already tracked): `ProjectHomeView`'s document/tab hand-offs
   pass `from: nil` (→ `.anyWindow` first-wins) instead of the presenting surface's
   `\.environment(\.sceneID)`. Under iPad multi-window / Stage Manager a document opened
   from Project Home can land in the wrong window. Read `@Environment(\.sceneID)` and pass
   it through. **Needs on-device multi-window/Stage-Manager verification** (inherited from
   the already-shipped Settings entry too).
2. **iPad sheet form-factor:** the dashboard is a wide-window layout (`maxWidth 760`,
   multi-column stat grid) presented as a **sheet** from the Research tab. Tune the sheet
   size/detents and the header / stat-grid / recent-feed typography for the sheet and
   compact widths; decide sized-sheet vs. full-screen on iPad.
3. **Recent searches → re-run:** display-only in Phase 1; wire tap-to-re-run once Phase 2's
   project-scoped search lands (the two connect — a recent search re-runs *in its mode*).
4. **Landing vs. sheet (revisit):** if on-device use shows the sheet reads as a detour,
   reconsider a true Research-tab landing / push once the `[ResearchSidebarItem]` path is
   safe to extend (e.g. add a `.projectHome` case) — deferred from Phase 1 for exactly that
   fragility.
5. **General visual polish** from on-device feedback: spacing, empty states, the Project
   Leads placeholder copy, Dynamic Type, and VoiceOver on the dashboard.

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

### Phase 3 — Project Leads: a related-document discovery pipeline  *(effort L; the marquee idea)*

The most powerful discovery signal isn't the project's *declared* focus (Mode A) — it's
what emerges from what the researcher has *actually gathered*. As documents are added to
a project's collections, this phase tracks their **top related documents** and turns the
incremental changes into a **living research pipeline**.

**Concept.** The project's collections are a growing **seed set**. The **Leads** are the
ranked set of **related-but-uncollected** documents, aggregated across the seed. Add a
document to a collection → it joins the seed → *its* related documents enter the Leads
→ the research snowballs outward. The Leads' *changes over time* are the pipeline.

**Mechanics** (reuses `RelatedDocuments/RelatedDocumentsEngine` — a pure multi-axis
similarity ranker fed by the existing generators/scorers; no engine changes):
1. **Seed** = documents in the project's collections (config: collections only, or +
   noted/visited).
2. For each seed doc, run the related engine → scored candidates (subjects, citations,
   persons, … axes).
3. **Aggregate** across the seed: a candidate's Leads score accumulates across the seed
   docs it's related to, so a document related to *many* seed docs rises (consensus).
   Exclude anything already in the seed / engaged.
4. **Static Leads** (surfaced in Project Home's reserved slot): top-N "documents related
   to your collection you haven't gathered," each showing *which* seed docs pulled it in and
   *why* (axes) — provenance for trust.
5. **Incremental pipeline** — the novel part: persist the Leads so newly-surfaced
   documents (ones that newly cleared the threshold as the collection grew) get a
   `firstSurfacedAt` stamp → a chronological "**new since you last looked**" feed. That feed
   *is* the research pipeline.
6. **Actions** per leads doc: open · **add to a collection** (feeds it back into the seed
   — the compounding loop) · **dismiss** (stops it resurfacing).

**Persistence (the one new @Model in the whole program):** `ProjectLeadEntry`
(`projectId`, `documentKey`, `aggregateScore`, `firstSurfacedAt`, `contributingSeedKeys`,
`dismissed`). Additive and CloudKit-safe — a *new record type*, not a change to any existing
record, so it stays within the "no migration" guardrail.

**Cost control:** recompute on collection change, debounced + off the main actor; cache the
Leads; cap the seed and per-seed candidate counts so a large collection stays cheap. The
engine itself is I/O-free once fed.

Depends on Phase 1 (Home surfaces it). Complements Phase 2: Mode A is top-down *declared*
discovery; the Leads is bottom-up *emergent* discovery.

### Phase 4 — Project on export & citation  *(effort S–M)*
Carry the project (name + research question) into collection / research-data exports as
a provenance line/header (PDF/DOCX/HTML + the research-data JSON), so an exported working
set self-documents what project it belongs to. Touches `Collections/*Exporter*` +
`Export/ResearchDataExporter.swift`.

### Phase 5 — Surfacing & focus editing  *(effort S–M)*
- Show the active project's research question subtly in the Browse/Search chrome
  ("Working on: …") so the lens is visible while reading.
- A **focus editor** in Project Home / `ProjectEditorView`: date range + **subjects**
  (now live — picked from the volume-subject-profile vocabulary the Phase-2 foundation
  established, owner decision #4) — the controls that drive Mode-A discovery. (Subject
  focus stays *volume-grain* until document-level tagging is re-integrated, at which point
  the same control gains document-grain precision — a later expansion, per owner note.)
- Add the "second project created → open Project Home?" first-run nudge (D2.3).

### Phase 6 — Per-project default volume scope  *(optional; effort M)*
`CustomVolumeScope` already carries `projectIds`. Let a project pin a **default volume
scope** so Browse / Search / Analytics default to the volumes that matter for it, tying
the #258 custom-scope work to the project lens. (Natural companion to Phase 2's
subjects→volumes resolver — the project's subject focus can *propose* the volume scope.)

## 4. Non-goals / guardrails
- **No CloudKit removal or migration.** This plan is additive. The only new persistence is
  Phase 3's `ProjectLeadEntry` — a *new* @Model record type (CloudKit-safe: adding a
  type never migrates existing records). `Project`, `projectIds`, and `projectId` are
  untouched on the shipped schema.
- **Single-project users stay unbothered.** Every new surface is either behind the
  project picker or a no-op when only the default project exists.
- **Docs pass** (Docs/ manuals + in-app ResearchGuide/IndexingEducation + README) closes
  the program once the shipped phases land.

## 5. Owner decisions (2026-07-22)
1. **Project Home shortcut = ⌘P.** No document printing is planned, so ⌘P is free and is
   the "P for Project" mnemonic. (Add a `.printItem` `CommandGroup` guard so no system
   Print item claims ⌘P.)
2. **Phase order:** 1 → 2 → **3 (Project Leads — new marquee discovery phase)** → 4 →
   5 → (6). The Leads (owner idea, 2026-07-22) is bottom-up emergent discovery that
   complements Phase 2's top-down declared discovery; slotted right after search.
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
- **Leads seed** (Phase 3): collections only, or collections + noted/visited? (Recommend
  **collections only** to start — the most intentional signal — with noted/visited as a
  later toggle.)
- **Leads aggregation** (Phase 3): sum vs. max vs. count-weighted across seed docs, and
  how to weight the similarity axes for the *aggregate* (inherit the user's find-related
  weights, or a Leads-specific default). Settle with real data during Phase 3.
- **Leads surfacing**: is the "new since you last looked" pipeline a section of Project
  Home, or does it also warrant a light notification/badge when fresh documents surface?
