# Onboarding Overhaul — "Glass over Word Clouds" Session Plan

**Date:** 2026-07-26
**Source of truth:** `design_handoff_onboarding_glass_flow/` — `README.md`, `Onboarding
Revamp.dc.html` (canonical option ids **1a, 4a, 4b, 4c** only; turns 2–3 are rejected
design history), `Current Onboarding.dc.html` (baseline recreation), `screenshots/01`–`08`.
**The bundle is deliberately untracked** (`.gitignore`: `design_handoff_*/`, as with every
Claude Design hand-off) — unpack `Onboarding flow with animated word clouds.zip` from
iCloud Drive at the repo root before any O session, or the file:line citations below and in
the sessions resolve to nothing.
**Execution context:** local Mac + Xcode. Two sessions have owner-executed steps (the
corpus generator run in O-1, the fresh-install captures in O-5).

**What this is.** A full-bleed animated word cloud behind every onboarding screen and a
new every-launch splash, with all UI floating above as liquid-glass surfaces. Cloud data
is pre-generated at build time and bundled, so the animation works before a single volume
is downloaded — which is what makes it usable as a *content preview* at the moment the
user is deciding what to download.

**Scope of this plan:** 6 sessions, ~8–10 PRs (O-0 is two). No CloudKit schema change, so the #488
schema-deploy gate never fires. Independent of **R-2b** — the one Wave-R item still open,
the rest having shipped as PRs #510–#521 — and of Workstream Q; it can interleave with
either.

---

## Recon findings — where the handoff and the code disagree

Measured against the tree at `409219d`, 2026-07-26. **Read this section before O-0.** Five
of these change what the sessions contain; two change what the feature can honestly claim.

### 1. The splash's stated premise does not hold (blocks 1a)

The handoff shows the splash "while stores/manifest open". They do not open then.
`ModelContainer` is created **synchronously** (`FRUSExplorerApp.swift:253`,
`makeFRUSContainer()`), and `AppState` initialises synchronously before it
(`FRUSExplorerApp.swift:39–48`, boot sequence steps 1–2). The only post-render work is the
first `.task {}` fire at `FRUSExplorerApp.swift:1054` — `IndexingPipeline`, `SearchService`,
`DownloadManager` construction and `resumeQueuedDownloads()`.

So a splash bound to "stores ready" has nothing to wait for and may flash for a single
frame — worse than no splash.

**But there is a real wait; it is simply earlier than a SwiftUI overlay can reach.**
`AppState`'s stored properties decode roughly **1.8 MB of bundled JSON synchronously on
the main thread before the first frame**, and `manifest.json` is decoded **twice**:

| Load | Size | Where |
|---|---|---|
| `volume-tag-taxonomy.json` | 99 KB | `VolumeLevelTagStore.init()` — `VolumeLevelTagStore.swift:58` |
| `manifest.json` (1st) | 782 KB | `VolumeLevelTagStore.init()` — `:59`, for `volumesByTag` |
| `manifest.json` (2nd) | 782 KB | `ManifestStore.init()` — `ManifestStore.swift:177` |
| `administration-profiles-index.json` | 171 KB | `AdministrationProfilesStore.init()` — `:39–41` |

…plus `ModelContainer.makeFRUSContainer()`, which on a large synced store is likely the
dominant term. On iOS that entire window is covered by `UILaunchScreen: {}`
(`project.yml:97`) — a **blank** screen. On macOS it is covered by nothing.

That reframes 1a: the honest gap is pre-render, where only a launch screen can draw, and
part of it is self-inflicted (the double decode). **Settled 2026-07-26 — O-0-1 answered
(c) + (d), and the double decode is in scope as O-0-2.** See O-0.

### 2. The onboarding tests do not test the onboarding flow

`OnboardingFlowTests` (212 lines) and `OnboardingTests` (145 lines) exercise
`OnboardingViewModel` — which **does not drive the shipped flow**. The live
`OnboardingView` carries its own `@State step` (`:50`), `scopeChoice` (`:61`),
`selectedSubseries`/`selectedVolumeId` (`:62–63`), `enqueueAndAdvance()` (`:407`),
`completeOnboarding()` (`:425`) and `ensureDefaultProjectExists()` (`:430`).
`OnboardingViewModel` survives in the app only through one nonisolated static helper,
`hasDownloadedVolumes(in:)`, called from `ContentView.swift:51`.

The handoff's reassurance that these tests "should need only cosmetic updates" is true,
and for the wrong reason: **the code being rewritten has no behavioural coverage at all.**
O-0 adds it before O-4 touches anything.

### 3. ~727 lines of the `Onboarding/` directory are dead

Never instantiated anywhere in the app or tests:

| File | Lines | Status |
|---|---|---|
| `DownloadScopePickerView.swift` | 325 | Referenced only by a comment in a tombstone |
| `OnboardingProjectSetupView.swift` | 245 | Dead |
| `OnboardingIntroView.swift` | 107 | Dead (mentioned in an `InAppBrowserView.swift:17` doc comment) |
| `OnboardingVolumePickerView.swift` | 16 | Tombstone — "retained so the Xcode project continues to compile without a pbxproj edit" |
| `OnboardingDownloadView.swift` | 17 | Tombstone |
| `OnboardingPromptSetupView.swift` | 17 | Tombstone |

> **Corrected during O-0.** This table listed a seventh file,
> `IndexingSetupWizardView.swift` (43 lines). **It is live.** The file declares
> `WhileIndexingSheet`, not `IndexingSetupWizardView` — the wizard was deleted in Session
> 163 and the filename never followed — and `IndexingQueueBannerView.swift:101` presents it
> on iOS. Deleting it broke the build immediately, which is the only reason the error was
> cheap. Both this recon and its verification pass had checked each file for references to
> *the type its filename names*; neither looked at the types the files actually declare.
> O-0 renamed it `WhileIndexingSheet.swift` so the next audit cannot repeat the mistake.
> The lesson generalises: **a filename is not an inventory of a file's contents.**

The tombstones' stated reason expired when the project moved to XcodeGen directory globs.
Two audit backlogs point at this dead code as if it were live — UI-Audit §A5 cites
`DownloadScopePickerView.swift:295`, and `Dynamic-Type-Worklist.md` lists
`OnboardingIntroView.swift`. Deleting it in O-0 shrinks the surface the overhaul appears
to touch by more than half and retires those rows.

### 4. The live onboarding flow is entirely unlocalized

`OnboardingView.swift` contains **zero** `String(localized:)` calls and 14 raw `Text("…")`
literals (e.g. `:160`, `:297`, `:303`, `:361`) — a standing violation of the house
localization standard, which has no mechanical gate. Worse, `Docs/EditableContent.md:105`
documents onboarding copy by pointing at `OnboardingIntroView.swift` — the *dead* file.
O-4 replaces this copy wholesale, so it is the cheap moment to fix both.

### 5. The artifact is ~1.5–2.0 MB, not 6–8 MB (owner-agreed two-file split)

The README's estimate assumes repeated term strings. Int-indexing the shared vocabulary —
the pattern `VolumeSubjectProfilesGenerator` already uses — cuts it by roughly two-thirds:

| | Entries | Raw | Int-indexed |
|---|---|---|---|
| Core: corpus + 107 subseries | 21,600 | ~400 KB | **~250–350 KB** |
| Volumes: 552 | 110,400 | ~2.2 MB | **~1.2–1.7 MB** |

Ship **two files split by access pattern**, each with its own self-contained vocabulary:
`cloud-vectors-core.json` (splash, Welcome, Ready, Corpus and Subseries scopes — loaded
eagerly, off-main) and `cloud-vectors-volumes.json` (the 552-volume tail — loaded lazily
when the Volume segment is first selected, behind a screen the user is already reading).
Not one monolith: the splash is the one screen that cannot afford a 2 MB decode on the
path to its first frame, and the cloud *is* the splash. Not 552 slices: they'd forfeit
the shared vocabulary that makes int-indexing pay, add 552 bundle entries to sign and
enumerate, and solve a random-access problem the app doesn't have.

No mmap/offset-table format. Every bundled store in the app is `Data(contentsOf:)` +
`JSONDecoder` (`CentralFilesIndexStore` at 3.5 MB, `VolumeSubjectProfilesStore`,
`VolumeSourcesIndexStore`, `PersonAuthorityIndex`); 1.5 MB does not justify diverging.
Revisit only if O-2's measurement shows the volume decode stuttering.

**Note the manifest has 107 subseries, not the ~20 eras the prototype's sheet implies**
(`manifest.json`: `1969-76` = 66 volumes, then a long tail of single years — `1919`, `1945`,
`1946`…). The 4b sheet's max height (196 pt mac / 240 pt iOS) is a scroll view over 107
rows, and the chip label must cope with `Concepts · 1919`.

### 6. The tokenizer is portable; its data sources are not

`WordCloudTokenizer` is pure `Foundation` + `NaturalLanguage`, `Sendable`, no SwiftUI —
it lifts into an SPM target cleanly. But `WordCloudLexicons.swift:49` and
`WordCloudStopwords.swift:36` are hard-wired to `Bundle.main`, which an SPM tool does not
have. The shared target must take the payloads by injection; the app keeps a bundle-backed
loader that feeds the same types.

**And the lens set is not all lexicon-driven.** `WordCloudLexicons.filter(for:)` only
answers for `.concepts` and `.sentiment`; **`.topics` and `.actions` are POS lenses**,
resolved by `NLTagger` with `[.lemma, .lexicalClass]` (`WordCloudTokenizer.swift:117–133`).
`WordCloudTokenizer` is built to serve one lens per pass, so the naive port runs NLTagger
over 3.34 GB of TEI **four times**. Design the generator as one tagger pass with four
accumulators (decision **O-1-2**).

### 7. The layout engine already exists

`WordCloudLayout.place` (`WordCloudLayout.swift:65`) is already the deterministic
Archimedean-spiral packer with axis-aligned collision boxes the handoff describes,
`Sendable` and testable without a graphics context. The backdrop needs three added
parameters — exclusion zones, y-compression (0.62), and a size exponent (1.45 in place of
today's sqrt curve) — not a new engine. All three must default to today's behaviour so the
existing Word Cloud feature is unchanged; pin that with a regression test.

### 8. This is the codebase's first Liquid Glass adoption

`grep` for `glassEffect` across `FRUSExplorer/` returns **0**. Deployment target is already
`26.0` on every target (`project.yml:57, 194, 271, 317`), so the OS API is available — use
it rather than hand-rolling the handoff's blur/saturate values, which are CSS
approximations of it.

### 9. Two honesty items

- **The silent fallback.** The handoff's `minimumSignalTerms` rule (< 4 terms → show the
  subseries list) is specified as invisible. A user reading a volume's cloud to decide
  whether to download it would then be reading its *era's* vocabulary and attributing it
  to the volume. The chip must distinguish the two (e.g. `Topics · 1969–76 (era)` vs
  `Topics · SALT I`). Decision **O-4-2**.
- **`ContentView` scans the filesystem inside `body`.** `hasDownloadedVolumes(in:)` runs a
  directory enumeration on every render pass (`ContentView.swift:51`). Pre-existing, and
  O-3 edits this file — flag it, do not silently fold a fix into a UI PR.

---

## Cross-cutting guardrails (every session)

- **Completion side-effects are untouchable.** `enqueueAndAdvance()`, `completeOnboarding()`,
  `ensureDefaultProjectExists()`, and the `hasCompletedOnboarding` flag keep their current
  semantics. The acceptance checklist's last line is the contract; O-0's characterization
  tests are how it is enforced.
- **The existing Word Cloud feature must not change.** Every extension to
  `WordCloudLayout` / `WordCloudTokenizer` is additive with behaviour-preserving defaults,
  and the app path and the generator path must agree term-for-term (O-1's parity test).
- **Cloud words are decorative.** Exempt from Dynamic Type — this is already the documented
  convention (`FRUSTheme.swift:317` explicitly excludes "the word cloud's bespoke
  `word.fontSize` system") — and hidden from VoiceOver. The lens chip is the accessible
  surface.
- **Never block launch.** No cloud work, no decode, and no layout pass may sit between
  process start and the first frame the user can act on.
- **Localization from here on.** Every string O-4 introduces uses `String(localized:)` and
  lands in `Docs/EditableContent.md` in the same commit.
- **Standing gates:** Apache headers on sources *and* tests; doc comments on every
  `public`/`internal` symbol; `Version history` rows on files that already carry them;
  `CodingStandardsAuditTests` green; iOS **and** macOS in every session; `build-for-testing`
  before claiming green; implementer ≠ reviewer; visual-review checklist in every UI PR.
- **XcodeGen:** sessions that add or delete files run `xcodegen generate --spec project.yml`
  followed by `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`. Flagged per
  session below.

---

# Sessions

## O-0 — Clear the ground *(Effort S, two PRs)*

**Goal.** Delete what is dead, cover what is about to be rewritten, and take the
main-thread work out of launch before anything is layered on top of it.

**PR 1 — dead code, tests, measurement.**
- Delete the six dead files in finding 3 (~727 lines), and rename the seventh —
  `IndexingSetupWizardView.swift` → `WhileIndexingSheet.swift` — which is live, not dead.
  Drop the `InAppBrowserView.swift:17` reference to `OnboardingIntroView`; retire the
  UI-Audit §A5 and Dynamic-Type-Worklist rows that point at them (a line in each doc, not a
  code change). `Docs/EditableContent.md` §2 needs correcting in the same PR rather than in
  O-4: it documents the deleted `OnboardingIntroView`'s copy, which never rendered, and
  §2.2's intro body loses its last reader with that file.
- **Characterization tests for the live path.** Extract the pure logic currently inlined in
  `OnboardingView` — scope → volume set (`:373–395`), `canProceedFromScope` (`:397`),
  `startYear(from:)` (`:391`) — into a testable `OnboardingScopeResolver`, and pin:
  corpus/subseries/volume enqueue sets, the default-project creation path
  (`ensureDefaultProjectExists`), and that `completeOnboarding()` sets
  `hasCompletedOnboarding`. These tests must pass unchanged after O-4.
- Rename `OnboardingFlowTests` to name what it actually covers
  (`OnboardingViewModelTests`), so the next reader is not misled the way this plan's recon
  was.
- **Measure the launch gap, in two parts** — they have different remedies: (i) process
  start → first frame (the pre-render window: `AppState` init, the ~1.8 MB of JSON,
  `ModelContainer`), and (ii) first frame → first `.task` complete. iPhone and Mac, fresh
  install and warm install, with Instruments. Record both in the PR body; PR 2 is measured
  against (i).

**PR 2 — O-0-2, one manifest decode.**
- `manifest.json` is decoded twice on the synchronous pre-render path — by
  `VolumeLevelTagStore.init()` (`VolumeLevelTagStore.swift:59`, to build `volumesByTag`)
  and again by `ManifestStore.init()` (`ManifestStore.swift:177`). Decode once and share:
  `AppState` constructs `manifestStore` first and hands `bundledEntries` to
  `VolumeLevelTagStore`, whose parameterless `init()` stays for tests and previews.
- ~763 KB of main-thread JSON leaves every cold launch — on the exact path the splash was
  meant to cover, which is why it lands before O-3 rather than after.
- **Measured in O-0, and smaller than this plan first implied: 7.8 ms** (best of 9,
  `JSONDecoder().decode([VolumeManifestEntry].self, …)` over the shipped 763 KB / 552-entry
  `manifest.json`, release-optimised, M-series Mac). A first pass measured 6.3 ms against a
  proxy struct with a *synthesized* decoder and was 25% low: `VolumeManifestEntry` has a
  custom `init(from:)` (`ManifestModels.swift:87–108`) that re-joins whitespace in every
  title and de-duplicates `tags` with a linear `contains` per tag — quadratic on an entry
  carrying up to 154 tags. Measure the type the app actually decodes, not one shaped like
  it. So the redundant decode costs ~8 ms on a Mac and, measured since, **~10 ms on an
  iPhone** — real, and free to remove, but **not** the reason cold launch feels slow.

- **✅ SETTLED by the owner's Time Profiler traces, 2026-07-26 (`AppStore` config).** The
  suspicion was right, and by a wider margin than expected. Two traces:

  | Symbol | **Mac**, loaded store | **iPhone**, fresh install (empty store) |
  |---|---:|---:|
  | `FRUSExplorerApp.init()` | **158 ms** | **119.9 ms** |
  | ↳ `ModelContainer.makeFRUSContainer()` | 137 ms — 87% | **86.3 ms — 72%** |
  | ↳ `AppState.init()` | 21 ms — 13% | 33.3 ms — 28% |
  | ↳↳ `VolumeLevelTagStore.init` (taxonomy + manifest #1) | 10 ms | 15.6 ms |
  | ↳↳ `ManifestStore.init` (manifest #2) | 8 ms | 10.0 ms |
  | ↳↳ `AppState.startNetworkMonitor()` | (1 ms, as `NWPathMonitor.init`) | **5.0 ms**, all self |
  | ↳↳ `DocumentASTCache.init(capacity:)` | — | 2.0 ms |
  | ↳↳ `AdministrationProfilesStore.init` / `SourceProvenanceStore.init` | 1 ms | 0.7 ms |
  | ↳ `FRUSExplorerApp.configureTipKit()` | — | 0.2 ms |

  On the Mac, `ManifestStore.init` at 8 ms corroborates the 7.8 ms standalone benchmark to
  within measurement noise, so the redundant decode is exactly the 8 ms claimed — **5% of
  app init** there, and **~8% (10 ms of 120 ms)** on the phone.

  **The iPhone trace is the more interesting one, for a reason that was not the plan.** It
  was taken on a *fresh install with no downloaded or indexed volumes* — the owner deleted
  the TestFlight build first, following an instruction meant for the launch-screen visual
  check rather than for this trace. That accident produced the control case: **86 ms of
  container open with an empty store.** So the container's cost is mostly **fixed** —
  `Schema(frusModelTypes)` building a managed object model over 19 `@Model` types by
  reflection, plus store setup and CloudKit mirroring — and not something that grows into
  existence as a user accumulates data.

  That matters more than the absolute number: **every user pays most of this on their very
  first launch, before any data exists.** It is not "the owner's store got big." It is the
  strongest argument for the launch screen, which is the only thing that can draw there.

  **Still unmeasured:** an iPhone cold launch against a *loaded* store. Mac-loaded (137 ms)
  versus iPhone-empty (86 ms) cannot be subtracted — different hardware and different store
  size at once. That number sets O-3's gate and is worth having before O-3, not before O-1.

  **New, and not previously visible: `startNetworkMonitor()` costs 5 ms of main-thread self
  time at init** — 4% of app init, spent starting an `NWPathMonitor` whose only product is
  `isOnline`, which nothing needs at frame zero (onboarding's offline banner could start
  optimistic and correct itself on the first path update). Deferring it past first frame
  looks like a one-line change for 5 ms. **Flagged, deliberately not folded into O-0-2** —
  it is a behaviour change to network-state timing, not a decode dedup, and it belongs in
  its own PR with its own reasoning. Same rule as the `ContentView` in-`body` filesystem
  scan in finding 9.

  **Consequences, all three of them:**
  1. **PR 2 lands as hygiene, not performance.** One decode, one source of truth, no second
     store deriving from a re-parse. Say so in the PR; do not claim a launch win.
  2. **O-3's "must not extend time-to-interactive" gate is measured against the 137 ms**,
     which is where the budget actually lives.
  3. **The reason given below for not building option (a)'s launch-screen half no longer
     holds** — see the note under *Explicitly not built* in O-3.

  `makeFRUSContainer()` is two statements: `Schema(frusModelTypes)` over the 19 `@Model`
  types, and one `ModelContainer(for:configurations:)` with CloudKit private-database
  mirroring. There is nothing in it to delete — the cost is SwiftData building the
  managed object model by reflection and opening the store, which the empty-store trace
  confirms is largely fixed work rather than data-proportional. Reducing it means changing
  *when* the container is built, not what it does, and that is a restructure no session in
  this plan is scoped for. **Still outstanding: the same trace on an iPhone**, where a
  large synced store should make the figure worse, not better.
- **Own PR, not a rider on a UI session:** this is a change to app startup ordering, and
  `AppState` init is the most load-bearing initialiser in the app.
- Verify: re-run the (i) measurement and report the delta; `VolumeLevelTagStore`'s
  `volumesByTag` mapping is unchanged (pin with a test if none covers it).

**Data & migration:** none. **Prereq:** none. **Needs xcodegen:** yes (deletions, PR 1).

### ✅ O-0-1 — ANSWERED, owner decision 2026-07-26: **(c) + (d)**

The cloud gets **two homes outside onboarding**, and they are mutually exclusive at
runtime:

- **(c) The indexing wait** — the backdrop renders behind `IndexingBannerView` /
  `IndexingQueueBannerView`, scoped to the volumes currently downloading and
  re-aggregating as each lands. This is the wait that is genuinely minutes long and
  genuinely bare today.
- **(d) A splash on occasions that have something to say** — never on an ordinary warm
  start.

**Precedence rule (they must never both fire).** If there is download or indexing work
pending at launch, **(c) owns the screen** and no splash appears. Otherwise (d) may fire.
Write this as a single resolved enum with one owner, not two independent `if`s in two
views — two conditions racing for the same surface is how the research-trail double-write
in Wave R began.

**The (d) predicates, and what already exists to answer them:**

| Occasion | Predicate | Note |
|---|---|---|
| First launch of a fresh install | `hasCompletedOnboarding == false` | Splash flows straight into 4a — both full-bleed cloud, so design the handoff between them as one continuous surface, not two |
| A CloudKit import is actually running | `hasInitialProjectSyncSettled == false` while `cloudKitSyncState == .syncing` | **Already exists** (`AppState.swift:288`, #377 Phase 5) and already drives the macOS "Switch Project" placeholder — reuse it, do not invent a second signal |
| Pending reindex | index work queued at launch | Overlaps (c); the precedence rule resolves it to (c) |

**Ordering hazard in (d).** Both live predicates are only knowable *after* container init
and observer install — i.e. after first render. So the splash is an overlay that fades in
when the condition is met, not something present at frame zero. It therefore cannot cover
the pre-render gap; **O-0-2 is what improves that window**, and it does so by removing work
rather than by covering it.

The options as originally posed, for the record:

- **(a) Move it earlier — launch screen + continuation.** Put the 1a identity block
  (icon tile, wordmark, caption) in the iOS launch screen so it covers the *real*
  pre-render gap that is blank today, then have `LaunchSplashView` continue from the same
  composition with the cloud while the first `.task` runs, dismissing when ready. The two
  halves read as one moment. **Constraints:** a launch screen cannot animate and cannot
  draw a cloud — the static half is identity only; macOS has no launch screen at all, so
  it gets the SwiftUI half only. Best fidelity to the design's intent; most honest about
  what is being waited on.
- **(b) Threshold-triggered.** Render nothing for the first ~250 ms; if readiness has not
  arrived, fade the splash in and hold a short floor so it cannot strobe. Fast launches
  never see it. Honours "never block" literally, at the cost that the better the app's
  launch gets, the less anyone sees the work.
- **(c) Re-target to the wait that actually exists — first download and index.** That wait
  is *minutes*, not milliseconds, and today it is an `IndexingBannerView` /
  `IndexingQueueBannerView` over an app with nothing in it. Putting the backdrop behind
  that banner, scoped to the volumes currently landing and re-aggregating as they do,
  spends the asset on a genuine emptiness and previews exactly what is arriving. Reuses
  O-2 wholesale; needs no splash at all. **Strongest product use of the cloud**, and it
  composes with (a) or (d) rather than competing.
- **(d) Conditional occasions.** Show it only on launches that have something to say —
  first launch after install, a CloudKit initial import, a pending reindex — and never on
  an ordinary warm start. Keeps the moment rare enough to stay a moment.
- **(e) Drop 1a.** Keep the cloud on 4a–4c only. Cheapest, removes O-3 entirely, and loses
  nothing the Add Volumes preview does not already deliver.

*(Claude's recommendation was (c) + (e). The owner took (c) + (d) — the splash survives,
restricted to occasions that earn it. A fixed display floor on every cold launch was never
on the list: it is a permanent tax on a tool people open repeatedly, and the handoff
forbids it.)*

**Verify.** Full `FRUSExplorerTests` green with the new tests; iOS and macOS build clean;
UI tests still reach `MainTabView` under `FRUS_UI_TEST_MODE`. PR 2 additionally reports the
before/after (i) measurement on both platforms.

---

## O-1 — `WordCloudKit` + `CloudVectorsGenerator` *(Effort L — the anchor)*

**Goal.** One tokenizer, two callers, two bundled artifacts.

**Deliverables.**
- New SPM target **`WordCloudKit`**: `WordCloudTokenizer`, `WordCloudTuning`,
  `WordCloudLens`, `WordCloudLexicons`, `WordCloudStopwords`, `TermCount`, with lexicon and
  stopword payloads **injected** rather than read from `Bundle.main` (finding 6). The app
  keeps a thin bundle-backed loader that constructs the same values; the generator passes
  file URLs. Follows the `SourceNoteKit`/`CrossRefKit` precedent, and starts on
  `GeneratorKit` (the migration #270 wants for the older generators).
- **`CloudVectorsGeneratorCore` / `CloudVectorsGenerator` / `CloudVectorsGeneratorTests`**,
  mirroring the `AdministrationProfilesIndexGenerator*` target trio in `Package.swift:289–311`.
- TEI → body-text extraction over `VOLUMES_DIR`. **No existing generator core does this** —
  `DocumentNoteExtractor` extracts source notes only, and the app's path reads `body_text`
  out of FTS5, which a command-line tool cannot reach. Write it here, per-volume and
  concurrent.
- Aggregation: per volume → per subseries (`manifest.json` `subseries`) → corpus. Top 50
  terms per lens, weights normalised 0–100, sentiment carrying polarity ±1. Entity lenses
  (People/Places/Organizations) excluded per the handoff.
- Two artifacts per finding 5, int-indexed vocabulary, `sortedKeys`, compact (not
  pretty-printed), provenance stamp (`generated`, corpus volume count, tuning digest).
- Env: `VOLUMES_DIR`, `MANIFEST`, `LEXICONS`, `STOPWORDS`, `OUTPUT_DIR`, `GENERATED_DATE`.
  Document the invocation in `CLAUDE.md`'s SPM tools block.

**Data & migration:** two new bundled resources. **Prereq:** none.
**Needs xcodegen:** yes (new resources + `Package.swift` targets).

### ✅ O-1-1 / O-1-2 — ANSWERED, owner decision 2026-07-27

**O-1-1 — parity at the tokenizer, not end to end.** The original framing ("must the
generator's counts match the app's cloud exactly") turned out to be unachievable, for three
independent reasons rather than one: the app tokenises FTS5 `body_text` from the parsed AST
while the generator byte-scans TEI; user tuning, custom stop lists and per-scope hidden
words are all live inputs a build-time artifact cannot follow; and the app counts only
*indexed* documents, so someone with 3 of a subseries' 44 volumes sees a 3-volume cloud.

So the pinned property is narrower and actually true: **same text and same sets in → same
counts out**, enforced by `WordCloudKitTests`. The generator additionally *mimics the app's
input* — document bodies only, footnotes included, matching `FRUSASTNode.plainText` — rather
than tokenising whole TEI files, so the two converge as far as the architecture allows. The
residue is documented on `CloudVectorsAggregator`, not papered over. End-to-end parity was
rejected: it would mean lifting `FRUSDocumentParser` (2,243 lines) into SPM and would still
be false for any user who touched a setting.

**O-1-2 — one pass, and it is verified rather than assumed.** All four lenses share the
same `enumerateTags(scheme: .lemma)` walk and differ only in the final filter, so the merge
is a refactor. The one real risk was whether requesting `.lexicalClass` alongside `.lemma`
perturbs the lemma — an assumption about a closed-source framework. The parity suite runs
the merged tokenizer against four single-lens runs and requires exact agreement, including
a **lexicon-only** request where the merged path asks for `[.lemma]` alone. 8/8 pass. If it
ever breaks, the fallback is two passes, not four.

**Schema consequence found while settling these.** The hand-off specifies `[term, weight]`
normalised 0–100 (`README.md:37`) *and* "future multi-volume scopes sum raw counts then
re-rank" (`:39`). **Those are incompatible** — a term at 100 in a 40-document volume and 100
in a 4,000-document volume are not the same quantity, and 4b's Subseries segment is already
a multi-volume scope. The artifact therefore stores **raw counts**, and the loader
normalises against the first (largest) entry. Summation stays exact; the renderer still
gets its 0–100.

**Session split into two PRs**, because perfect input parity is gated on a parser lift that
is its own session: PR 1 = `WordCloudKit` + both decisions; PR 2 = `CloudVectorsGenerator`,
the TEI extraction, and the artifacts.

**Verify.** `swift test --filter CloudVectorsGeneratorTests` (determinism: two runs are
byte-identical; int-index round-trips; sentiment polarity survives; the
`minimumSignalTerms` fallback marks rather than hides). Owner runs the full corpus pass and
reports wall-clock plus both artifact sizes; a core file over ~500 KB or a volumes file
over ~2.5 MB means the vocabulary factoring is not working and is a finding, not a
tolerance to widen.

---

## O-2 — The backdrop *(Effort M)*

**Goal.** The animated cloud, on both platforms, from bundled vectors, offline.

**Deliverables.**
- `BundledCloudVectors` — core loaded eagerly and **off the main actor** during startup;
  volumes loaded lazily on first Volume-segment selection. House `enum Store { static let
  shared }` shape, with the one deviation that it must not be first-touched on the render
  path (see guardrail).
- `WordCloudLayout.place` gains `exclusionZones:`, `yCompression:`, `sizeExponent:`, all
  defaulted to current behaviour. Regression test: the existing Word Cloud's placements are
  unchanged.
- `WordCloudBackdropView` — one `TimelineView`/driver, per-word `.opacity`/`.scaleEffect`
  with the handoff's stagger (14 ms out / 38 ms in) and curves; layouts cached per
  (canvas size × lens × vector set); deterministic seed per screen.
- Lens chip: capsule, accent dot, `{Lens}` or `{Lens} · {Scope}`, accent colours per the
  handoff.
- **Reduce Motion**: crossfade only, no scale or stagger.

**Data & migration:** none. **Prereq:** O-1. **Needs xcodegen:** yes.

### ✅ O-2-1 — ANSWERED, owner decision 2026-07-27: **a constant, no toggle**

`FRUSTheme.cloudLensCadence`. The hand-off calls the cadence "design-tweakable", meaning
tweakable by whoever is designing it, not by the reader — and the Word Cloud settings pane
already carries controls a user could confuse it with.

**Two defects the visual check caught that no build or test would have.** Both are the kind
only looking finds, which is why O-2 mounted the backdrop temporarily to screenshot it
rather than shipping a view nothing hosts:

1. **The chip named a lens that was not on screen.** It switched the instant the lens index
   changed, while the outgoing words were still fading (0.95 s) and the incoming ones still
   staggering in (~1 s) — so for most of every transition it lied. The chip now carries the
   lens through the same resolved value as the words and crossfades at the transition's
   midpoint.
2. **The chip read "Topics (nouns)"** — `WordCloudLens.label` is the *Analytics menu* label,
   and its disambiguating parenthetical reads as documentation in a menu and as noise on a
   decorative chip. Added `shortLabel`.

**One finding for O-4:** the backdrop has no host until O-4 places it, so O-2's own visual
verification required temporarily mounting it. Expect the same for any later session that
builds a view before its host exists — budget it rather than skipping the look.

**Verify.** Layout regression test green. On device, both platforms: the cloud renders with
**zero downloaded volumes** and airplane mode on — that is the whole point of bundling.
Measure a lens crossfade with the animation instrument on the oldest supported iPhone;
~25 concurrently animating words is the budget.

---

## O-3 — The cloud outside onboarding: indexing backdrop + occasional splash *(Effort M — per O-0-1 (c) + (d))*

**Goal.** Spend 1a's composition on waits that exist, without ever delaying readiness.
Two surfaces, one arbiter.

**Deliverables — (c), the indexing backdrop (the primary half).**
- The backdrop behind `IndexingBannerView` / `IndexingQueueBannerView`, scoped to the
  volumes currently downloading and re-aggregating as each lands — the same
  scope-reactive machinery 4b already needs, pointed at the queue instead of a picker.
- Must not compete with the education content that already fills this wait
  (`IndexingEducationView`, 1,189 lines, reached from the banner): the cloud is **backdrop
  to it**, never a rival surface. If the education content is on screen, it wins the
  foreground and the cloud dims behind it — settle the dim factor with the 0.62/0.68
  values in the handoff rather than inventing a third.
- Scope honesty carries over from O-4-2: a queued volume too thin for its own vectors
  shows its subseries list, and the chip says so.

**Deliverables — (d), the occasional splash.**
- `LaunchSplashView` per 1a: full-strength cloud, centre exclusion zone, icon tile,
  wordmark, caption, cycling chip, shimmer bar.
- Overlay wired at `FRUSExplorerApp.swift:1042` (over `ContentView`), fading in only when
  a (d) predicate holds and out on ~0.25 s when it clears. Never present at frame zero
  (the predicates are not knowable that early — see the ordering hazard in O-0-1).
- **One arbiter, not two `if`s.** A single resolved value — pending index work → (c);
  else a (d) occasion → splash; else nothing — owned in one place and read by both views.
- First-launch handoff: splash → 4a is cloud-to-cloud. Carry the lens phase and seed
  across so it reads as one surface rather than two that happen to look alike.

**~~Explicitly not built:~~ BUILT — owner decision 2026-07-26, after the measurement below.**
The iOS launch-screen half of option (a) ships as `FRUSExplorer/Resources/LaunchScreen.storyboard`:
the 1a identity block (gradient app tile, wordmark, caption) on an asset-catalog ground
with light and dark variants, wired through `UILaunchStoryboardName` in `project.yml`.
`UILaunchScreen: {}` is **removed**, not left alongside — iOS 14+ prefers the dictionary
when both are present, which would silently ignore the storyboard.

Constraints that shaped it, all inherent to launch screens: no code runs, so the gradient
is a pre-rendered vector PDF rather than a drawn layer and the glyph is baked into it
rather than tinted at runtime; no Dynamic Type; no localization. It is identity only — the
animated cloud belongs to `LaunchSplashView` in O-3, which takes over once SwiftUI is up.
**Keep the two compositions in step**: they are meant to read as one moment, which is the
whole argument for option (a) having two halves. macOS has no launch-screen equivalent and
is unchanged.

One trap worth recording: the macOS target globs the same `FRUSExplorer/` directory, and
`ibtool --target-device mac` **hard-errors** on an iOS storyboard rather than skipping it,
so the file is excluded in the macOS target's `sources` — omitting that exclusion breaks
the macOS build outright.

<details><summary>The decision as it stood before it was made</summary>

> ⚠️ **This rationale did not survive measurement — owner decision needed before O-3.**
> O-0's trace puts `makeFRUSContainer()` at 137 ms of a 158 ms `FRUSExplorerApp.init()`,
> against 8 ms for the decode O-0-2 removes. "Removing work" addresses **5%** of the
> window; the other 95% is a synchronous store open with nothing in it to delete. So the
> pre-render gap is not going away, it is ~150 ms+ on a Mac and probably worse on a phone
> with a large synced store, and on iOS every millisecond of it is a **blank white screen**
> — `UILaunchScreen: {}` draws nothing at all.
>
> The choice is now between two honest positions, and it is a product call:
> - **Accept the blank screen.** Defensible: it is brief, and a launch screen that apes the
>   first frame can make an app feel slower when the transition is visible.
> - **Build option (a)'s static half** — the 1a identity block (icon tile, wordmark,
>   caption) as a real iOS launch screen. It cannot animate and cannot draw the cloud, so
>   it is identity only, and it is *not* code: a launch-screen storyboard plus an
>   `UILaunchScreen` dictionary in `project.yml`'s `info.properties`. It is the only thing
>   that can appear during the 137 ms, and it composes with (d): the launch screen's
>   composition hands off to `LaunchSplashView`'s identical one, which is exactly the
>   "two halves read as one moment" the option described.
>
> Claude's recommendation is the second, on the narrow ground that it is nearly free and
> the gap is now known to be real and irreducible — but it reopens a question the owner
> already answered once, so it is flagged rather than folded in. macOS has no launch-screen
> equivalent and is unaffected either way.

</details>
- **UI-test bypass**: the splash must not appear under `FRUS_UI_TEST_MODE`, or every
  existing UI test's first element lookup races it. Same env check as
  `ContentView.swift:53`.
- Note, do not silently fix, the in-`body` filesystem scan (finding 9).

**Data & migration:** none. **Prereq:** O-2 (the cloud), O-0 PR 2 (so the launch baseline
is the improved one). **Needs xcodegen:** yes (new files).

### ✅ O-3-1 — decided during O-3: **before onboarding, never over it**

The splash holds briefly on a fresh install and dismisses into onboarding's own cloud.
Stacking two full-bleed cloud surfaces was the shape most likely to read as a stutter on
the one launch that forms a first impression.

**The fresh-install hold, and why it is not the thing the plan forbids.** A `.freshInstall`
splash has nothing to wait for, so it holds ~1.6 s. That is **once per install**, not the
"fixed display floor on every cold launch" O-0-1 rules out as a permanent tax on a tool
people open repeatedly. The other reason, `.cloudKitImport`, has a real wait and dismisses
when `hasInitialProjectSyncSettled` flips — never on a timer.

**Both (d) predicates are required together, not either/or.**
`hasInitialProjectSyncSettled` alone is false forever on a device with no iCloud account,
which would have shown a splash waiting for something that is never going to arrive. The
arbiter therefore requires `cloudKitSyncState == .syncing` as well.

**The arbiter is a `switch`, and that is the point.** `CloudSurfaceArbiter.resolve` returns
one `CloudSurface`, so "both surfaces at once" is unrepresentable rather than merely
untested — the failure the plan warned about cannot be expressed. `CloudSurfaceArbiterTests`
sweeps all 32 input combinations, pins that pending corpus work always wins, and asserts
every branch is reachable so the suite cannot pass vacuously.

**Verify.** `UIObstructionTests` and `FRUSExplorerUITests` green unchanged — the splash
must not appear under `FRUS_UI_TEST_MODE` or it races every first element lookup. Cold
launch on device must not extend time-to-interactive beyond the O-0 PR 2 baseline; if it
does, it is wrong regardless of how it looks. Verify (c) against a **real** first download
on both platforms, not a simulated queue — and verify the arbiter by starting a download
and relaunching, which is exactly the state where both surfaces would otherwise claim the
screen.

---

## O-4 — The three steps, docked in glass *(Effort L; split by platform if the diff outruns review appetite)*

**Goal.** 4a/4b/4c as designed, with the flow's behaviour bit-for-bit unchanged.

**Deliverables.**
- `FRUSTheme`: glass tokens and lens accents. Prefer the OS Liquid Glass material over the
  handoff's CSS-derived blur values (finding 8).
- `OnboardingView.swift`: replace `welcomeView` (`:110`), `scopePickerView` (`:141`),
  `readyView` (`:279`), `stepIndicator` (`:100`) and `navigationRow` (`:322`) with the
  docked-glass layout. `StepDot` (`:508`) → page dots; `ScopeCard` (`:542`) → segmented
  control. Keep `OnboardingStep`, `ScopeChoice`, `enqueueAndAdvance()`,
  `completeOnboarding()`, and the offline banner (`:358`).
- 4b: segmented control (full labels on macOS, short on iOS), selection-reactive caption,
  transient sheet for Subseries (107 rows — finding 5) and Volume, **no sheet** for Corpus,
  and the backdrop re-aggregating on selection.
- Copy verbatim from the handoff, all of it via `String(localized:)`, all of it into
  `Docs/EditableContent.md` in the same commit — and re-point that file's onboarding
  section away from the deleted `OnboardingIntroView` (finding 4).

**Data & migration:** none. **Prereq:** O-2. **Needs xcodegen:** only if split into new files.

### ✅ O-4-1 — decided during O-4: **not built**

The 4c "what happens next" list stays cut. The Ready dock's one line already says what
happens ("Volumes download and index automatically — search unlocks in minutes"), and a
disclosure on a terminal step users tap through in about two seconds is a control nobody
opens. **Cheap to reverse** — it is one `DisclosureGroup` in `readyDock` — so this is
recorded as a call made, not a door closed.

### ✅ O-4-2 — built in O-2, and it turns out to have no work to do

The chip carries an explicit `"{Lens} · {era} (era)"` qualifier, and
`BundledCloudVectorsTests` pins that a thin volume — **or one whose vectors have not loaded
yet**, which is the ordinary state on first selection — is marked rather than silently
substituted.

But O-1's corpus pass found **zero below-signal (scope, lens) pairs across all 2,208**. At
volume grain, for these four lenses, the hand-off's `minimumSignalTerms` fallback never
fires. The machinery is correct, tested, and unexercised; the only path that actually
reaches it today is the pre-load one. **Do not spend further design on it.**

**Verify.** O-0's characterization tests pass **unchanged** — that is the session's real
oracle. Then on device, both platforms: each scope enqueues what it enqueued before, Skip
still reaches Ready, and the default project is still created.

---

## O-5 — Accessibility, docs, closeout *(Effort S–M)*

**Deliverables.**
- **Reduce Transparency**: glass replaced by solid `windowBackgroundColor` cards.
- VoiceOver: cloud hidden; chip a live region announcing the lens; page dots carry position.
- Dynamic Type: the dock's text scales; cloud words are exempt, and that exemption is
  documented at the site per the `FRUSTheme.swift:317` convention.
- Both manuals' onboarding sections; TestFlight notes; screenshot-checklist rows in #106
  (the onboarding captures are ⚙️ fresh-install, owner-executed).
- Walk the handoff's acceptance checklist line by line in the PR body, each mapped to where
  it was verified — **with one line knowingly not met.** The checklist opens with "Splash
  shows on every cold launch, cycles lenses, never blocks readiness"
  (`README.md:105`, and `:23`/`:67` say the same). O-0-1 answered (d): the splash fires
  only on launches with a live reason, never on an ordinary warm start. That item is
  therefore **superseded, not failed** — record it as such rather than quietly ticking it,
  and pair it with the (c) indexing backdrop, which is where the composition actually went.

**Prereq:** O-3, O-4. **Needs xcodegen:** no.

---

## ✅ Workstream O — complete (O-0 … O-5, PRs #525–#535)

| Session | PRs | What shipped |
|---|---|---|
| O-0 | #525, #527 | 727 dead lines gone, 20 characterization tests, one manifest decode |
| — | #526, #529 | the launch traces, and option (a)'s static launch screen |
| O-1 | #530, #531 | `WordCloudKit` + parity + one-pass; the generator and both artifacts |
| O-2 | #532 | the animated backdrop, layout extensions, regression guard |
| O-4 | #533 | the three steps in docked glass, fully localised |
| O-3 | #534 | indexing backdrop + occasional splash, under one arbiter |
| O-5 | #535 | Dynamic Type, Reduce Transparency, manuals, closeout |

**Four decisions were reversed or narrowed by evidence**, which is the part worth carrying
forward:

1. **The splash's premise was false** (recon) — and the launch traces then showed the
   pre-render gap is ~86 ms of *fixed* SwiftData container cost even on an empty store, so
   "remove the work instead" addressed 5% of it. Option (a)'s launch screen got built after
   all.
2. **End-to-end tokenizer parity is impossible** (O-1-1) — three independent reasons. The
   achievable claim, tokenizer parity, is narrower and actually true.
3. **The hand-off's artifact schema contradicted itself** — normalised weights cannot be
   summed, and 4b's Subseries segment is already a multi-volume scope. Raw counts instead.
4. **The `minimumSignalTerms` fallback has no work to do** — zero below-signal pairs across
   all 2,208. Built, tested, unexercised.

**Owner-side items still open** (none block the release):
- macOS visual review of the O-4 dock, and the splash at window size
- Reduce Motion and Reduce Transparency *feel* on device — the code paths are verified, the
  experience is not
- An animation-instrument measurement on the oldest supported iPhone (~25 animating words)
- (c) against a **real** first download, and the arbiter verified by starting a download and
  relaunching
- The ⚙️ fresh-install screenshot captures for #106

---

## Order and stop points

```
O-0 ──► O-1 ──► O-2 ──┬──► O-3 (indexing backdrop + occasional splash)
                      └──► O-4 ──► O-5
```

**O-0 stands alone** and is worth landing regardless — it deletes dead code, covers
untested behaviour, and answers a question that would otherwise be answered by building
the wrong thing.

**There is no earlier shippable slice than O-2.** Every screen sits on the backdrop, the
backdrop sits on the artifacts, and the artifacts sit on the generator. This is the plan's
main structural difference from Workstream Q, whose Q-1 ships alone in one small session:
here the first user-visible increment costs O-1 + O-2 + O-4.

**Natural pause:** after O-2 (the cloud exists and is proven offline) and after O-4 (the
flow is the designed flow). O-3 is mostly a second home for O-2's backdrop rather than a
new surface, which is why it sits after O-2 and can trail O-4 without holding it up.

---

## Risks

| Risk | Where | Mitigation |
|---|---|---|
| Splash appears when nothing is happening | O-3 | O-0-1 (d): it fires only on occasions with a live predicate, never on a warm start |
| (c) and (d) both claim the screen | O-3 | One resolved arbiter, pending-index-work wins; verified by relaunching mid-download |
| A splash makes launch *slower* to justify itself | O-3 | Time-to-interactive against the O-0 baseline is the gate; O-0-2 removes 782 KB from that path first |
| Rewriting a 583-line view with no behavioural coverage | O-4 | O-0's characterization tests land first and must pass unchanged |
| Generator and app disagree on a volume's terms | O-1 | Parity test (O-1-1); one shared `WordCloudKit`, never a reimplementation |
| Four NLTagger passes over 3.34 GB | O-1 | One pass, four accumulators (O-1-2); measure on ten volumes first |
| Artifact bigger than budgeted | O-1 | Int-indexed vocabulary; size assertions in the test; >500 KB core / >2.5 MB volumes is a finding |
| 2 MB decode lands on the launch path | O-2 | Two files split by access pattern; core loaded off-main; volumes lazy |
| Existing Word Cloud regresses via the shared layout | O-2 | Additive parameters with current defaults + a placement regression test |
| Thin volume shows its era's vocabulary as its own | O-4 | O-4-2 chip qualifier |
| Motion budget on older iPhones | O-2 | ~25 animated words; measure before O-4 builds on it |
| Splash races existing UI tests | O-3 | `FRUS_UI_TEST_MODE` bypass, same check as `ContentView.swift:53` |

---

## Explicitly not in this plan

- **Entity lenses (People/Places/Organizations).** Excluded by the handoff pending curation.
- **Document-grain clouds.** The grain is corpus / subseries / volume; nothing smaller.
- **Re-theming the rest of the app in glass.** This is the first adoption, deliberately
  confined to onboarding and the splash.
- **`IndexingEducationView` / the Research Guide** (1,189 lines, live, reached from
  `FRUSExplorerApp` and Settings). Untouched — it is not part of the first-run flow the
  handoff redesigns.
- **The `OnboardingViewModel` retirement.** It keeps one live caller
  (`ContentView.swift:51`); moving that helper is a tidy-up with no user-visible effect and
  no reason to ride this wave.

---

## Owner-executed steps

1. **O-0:** the two-part cold-launch measurement, before and after PR 2's decode fix.
2. **O-1:** the full-corpus generator run against `VOLUMES_DIR` (one-off, minutes).
3. **O-4:** visual review of both platforms against `screenshots/01`–`08`.
4. **O-5:** fresh-install screenshot captures (⚙️ rows in #106).

Everything else is ordinary PR work.

---

## Relationship to the other workstreams

Independent of **R-2b** (the only Wave-R item left; R-1 and R-3…R-9 shipped as PRs
#510–#521) and of Workstream Q. It adds **no `@Model` type**, so
`CloudKitSchemaInventoryTests` never fires and no Production schema deploy gates the
release — the release-blocking dependency that Q's M-1, Q's M-2, and R-2b all carry. The
only shared file with any other lane is `FRUSTheme.swift`, and only additively.

If both lanes run, O-0 is the natural companion to a Q session: it is small, it is
independent, and it stops the next reader of `Onboarding/` from being misled the way this
plan's recon was.
