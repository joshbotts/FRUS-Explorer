# Visual marketing plan — animations in the app, and assets outside it

**Status:** proposed, 2026-08-30. Written against the tree at `30b105e` (build 44 on TestFlight).
Reconciles against `Planning/Map-Figure-Export-And-Visual-Outputs.md` §7–§9 and
`Planning/Plan-Of-Record-2026-08-28.md` rather than being invented beside them.

**Method.** Eight verified probes over the shipped code, three independent plan drafts scored by
adversarial judges, and a completeness critic. **The critic overturned the winning draft's flagship
claim** (§4.2) and corrected six of its motion items; those corrections are applied here, not
appended. Every figure below was read out of the shipped artifacts or opened in the tree. Nothing
rests on a doc comment — three corrections in this document exist *because* a doc comment or a
planning document in this repo was wrong, including one of mine.

---

## 1. Review verdict — the shipped semantic map export

**It works end to end, it is reachable from running UI on both platforms, and it needs zero volumes
downloaded.** `AnalyticsSectionExportControl` is mounted in the map toolbar with a non-nil figure
closure (`SemanticMapSpikeView.swift:1267-1271`), gated only on the bundled map index being present.
`exportMapFigure` (`:2769`) renders the point layer offscreen through the *same* `encode` path the
screen uses (`SemanticMapRenderer.swift:631-646`, callers `:596` on-screen and `:701` offscreen),
composites SwiftUI region labels over it inside `AnalyticsFigureCanvas`, and offers PNG and PDF.

W-3 implemented the design faithfully and improved on it in one respect worth recording: my plan
proposed saving and restoring `aspect`/`pointSize` around the offscreen call; the implementation
instead builds local uniforms and never writes stored view state, so the guarantee is **structural
rather than procedural**. That is the stronger design. All four documented traps are closed.

### Five residual gaps. Three block publication; they do not block rendering.

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 1 | **The caption band carries no caveats and no source attribution.** `AnalyticsProvenance.captionLines` returns exactly `[figureTitle, facts]` (`AnalyticsProvenance.swift:169-176`); `extraCaveats`, `corpusCaveat` and `corpusAttribution` are appended **only** in `csvPreambleLines` (`:180`, `:213`). Every plate credits "FRUS Explorer 0.2" and **not** the Office of the Historian. | Blocks publication |
| 2 | **The plate prints a sentence a standalone PNG makes false.** `AnalyticsFigureExport.swift:79-80` unconditionally renders *"Full method, caveats, and the underlying numbers accompany this figure in its CSV export."* Publish the image alone and it does not merely omit its caveats — it asserts they travelled with it. | Blocks publication |
| 3 | **The map's mandatory lens caveat reaches neither export half.** `SemanticMapLens.swift:100` carries *"a plurality, not a majority, for 73 of 522 volumes"*; its only consumer is the on-screen legend (`SemanticMapSpikeView.swift:2990`). `SemanticMapExport.caveats` takes a lens **label**, not a lens. | Blocks Provenance-lens publication |
| 4 | **The plate is washed toward white and its brightest dots clamp.** `sourceAlphaBlendFactor = .sourceAlpha` (`SemanticMapRenderer.swift:377`), not `.one`. Readback alpha lands ~0.79–0.84 while RGB holds a full over-composite against the dark clear colour — and the image is *declared* premultiplied, so compositing over `AnalyticsFigureCanvas`'s forced white clamps bright dots to pure white rather than lightening uniformly. | Print defect (S) |
| 5 | **The plate cannot state what was in frame.** The export builds uniforms from its own 1144:900 ratio, so the exported field of view differs from a wide Mac window's, and the label layer re-runs its spacing rule against the export rectangle — the figure can name regions the reader never saw named. The caveat list states no camera centre, no half-extent, no aspect. Readback is untagged `CGColorSpaceCreateDeviceRGB` (`:730`, `:744`). | Methods gap (S–M) |

**Gap 4 is my error to own.** `Map-Figure-Export-And-Visual-Outputs.md:143-144` asserts *"blending is
source-over on both RGB and alpha … so the texture is opaque."* Source-over on alpha requires `.one`.
The shipped code uses `.sourceAlpha`, which is what the pipeline always did — I mis-read it when
writing the design, and the implementation correctly followed the code rather than my sentence. No
test reads an alpha channel, and the fixture palette alpha is 1, so the defect is structurally
invisible. **Fixing it touches the single shared pipeline, so verify on screen as well as in the
plate** (no `isOpaque` is set on the MTKView, so the on-screen effect is probably nil — unverified).

**Verdict.** A finished *research* plate with three disclosure holes and one print defect. It is not
a marketing plate and cannot become one by cropping: `AnalyticsFigureCanvas` paints `Color.white`,
pins `.colorScheme(.light)`, and prints a mandatory methods band, with no width parameter reaching
any caller. That is right for a figure and wrong for a store screenshot — which is why §3 and §4 are
separated below and obey different rules.

---

## 2. Three facts that settle the plan's shape

**(a) The splash and a corpus-bearing device are mutually exclusive by construction.**
`CloudSurfaceArbiter.resolve` is one `switch`: UI-test mode returns `.none`, any pending corpus work
returns `.indexingBackdrop`, and only then is the fresh-install splash reachable. **One queued
download permanently replaces the splash.** Every capture plan here is therefore a two-device-state
plan and the App Preview is cut from two passes.

**(b) The XCUITest harness cannot see the splash.** The UI-test guard is unconditional, and that mode
also swaps in an in-memory store. Splash and onboarding frames are **manual, on an erased device, in
a window that occurs once per install.** Budget no automation for them.

**(c) The map's paused renderer is a motion engine, not an obstacle.** `camera` carries
`didSet { setNeedsRedraw() }`, and the view is configured `enableSetNeedsDisplay = true` /
`isPaused = true`. **One camera write is exactly one frame.** A 0.6 s tween is ~36 dirty marks
through the shipped encode path — no shader, artifact, `xcodegen` or CloudKit change — and **zero
idle cost**. This turns the repo's recorded performance refusal (a free-running loop cost 60
identical 314,483-point draws per second) into the argument *for* bounded motion.

---

## 3. In-app animation

Every item is classified on two axes, because conflating them is how this work gets mis-priced:
**data tier** (*pre-bundled*, works with zero downloads, vs *index-fed*) and **motion tier**
(*on-demand*, a bounded transit that ends, vs *continuous*).

**The house rule no item may break: the map stays on-demand.** A `TimelineView` sibling driving it
continuously would silently undo the `isPaused` decision and nothing in the build would complain.

### 3.1 Already shipping — film it, do not build it

| Item | Data | Motion | Path |
|---|---|---|---|
| Launch splash cloud + shimmer | pre-bundled | continuous | `LaunchSplashView.swift:50-51`, `:97` |
| **Onboarding scope-tracking cloud** — the best 8-second demo in the app | pre-bundled | continuous | `OnboardingView.swift:99-112`, `:123`; its doc calls this "the reason the vectors are bundled at all" |
| Indexing drift cloud — the app's **only** continuous particle animation | pre-bundled | continuous, closed-form | `drift: true` appears at exactly two sites: `IndexingCloudStrip.swift:61`, `PendingCloudBackdrop.swift:92` |
| Live Activity / Dynamic Island | index-fed | system | `FRUSExplorerWidgets/IndexingLiveActivity.swift` |

**Capture note.** The Live Activity is the one asset here **no simulator route can produce** — it
needs a physical iPhone with an active download (`Docs/screenshots/README.md:88-89`). Discover that
now, not in submission week.

### 3.2 New motion, corrected

**M-1 · Camera transit on region focus — M, and the best change in this plan.**
Today the camera **teleports**: `focusRegion` and `reveal` both end in an instantaneous
`renderer?.focus(...)`, a plain camera assignment.

*Correction the drafts got wrong:* the affordance labelled **"See on the semantic map"** is
`ClustersBrowseView.swift:522-524` → `focusRegion` — a **cluster** focus that is genuinely
pre-bundled and filmable on the erased device. The *document* reveal (`reveal(documentKey:)`) is
reached from `DocumentView.swift:1122` and `ResearchRailView.swift:941`, needs an indexed volume, and
opens a **new window or sheet** — so the reader has never seen the map and there is no "sense of
where it came from" to preserve. Sell M-1 as an **establishing zoom** on the region route; the
genuine visible jump on the document route is the deferred case, where the map draws whole via
`frameAll` and then snaps.

*Three constraints, in ascending difficulty:*
1. Two tests assert `halfExtent` **synchronously** right after `reveal()` returns.
2. Harder: `revealKeepsCamerasInStep` asserts `model.camera == renderer.camera` at **two** points.
   The obvious escape hatch — set the target synchronously and animate toward it — **fails that
   assertion by construction**, because the model's camera becomes the destination while the
   renderer's is mid-tween. The camera *mirror* is the binding constraint, not the half-extent.
3. A real race, not polish: a reveal must come *after* `applyScope`, because `applyScope` moves the
   camera to frame the scope. Today synchronous ordering guarantees it; an async tween can be
   overruled mid-flight.

Build the interpolator as a named type with its own test; interpolate `halfExtent` in log space.

**M-2 · The Reduce Motion / Reduce Transparency contract for the map — S, and a prerequisite.**
A grep across `FRUSExplorer/Semantic/` returns **zero** references to `reduceMotion` or
`reduceTransparency`, while nine other files read them. It is cheap precisely because **today's
shipped jump *is* the Reduce Motion path** — the cheapest accessibility story available anywhere in
this repo, and the reason M-1 is authorizable at all.

**M-3 · Lens dip — M.** The fade lever exists end to end and is unused: `Uniforms.alpha` is declared,
consumed by the shader, and **hardcoded to 1.0 at both call sites**. Drive 1.0 → ~0.25 → 1.0 across
the swap. A dip, not a cross-dissolve: `colourIndex` changes meaning per lens, so a palette lerp is
meaningless and a real dissolve needs two draws. *Favourable and non-obvious:* `setColourIndices`
leaves the flags byte untouched, so a lens dip composes correctly with a live scope.
*Do not forget:* if `alpha` becomes a stored property, the offscreen path must keep passing 1.0
explicitly, or a figure exported mid-dip is a faded plate.

**M-4 / M-5 · Splash drift and seeded lens — S each, but both are near-moot where proposed.**
The fresh-install splash lives exactly 1.6 s. The drift period is ~18.5 s, so a word traverses at
most half its 14 pt excursion; and the lens cadence is 4.2 s, so the splash **never advances past
lens 0 regardless of seeding**. Both effects are real on the **`.cloudKitImport` splash**, which the
code itself calls *"a real wait, of real duration"* — that is where to spend them. Ship the lens
**seeded, never randomised**, before 1.0: the splash is simultaneously the App Preview's opening
frame, a store screenshot and the README hero, and randomising it makes the one beat you most need
to reproduce non-reproducible.

**M-6 · In-app decade accumulation — DEFERRED pending measurement.** The ordering function is
app-side and GPU-free and each step is one dirty mark, but the only cost figure in the repo
(103.8 ms/frame) **includes readback and PNG encode the on-screen path does not pay**. Measure the
live per-step cost before scoping. Recording an assumption as a measurement is how a wrong number
gets into a plan.

---

## 4. External marketing assets

### 4.1 The store listing — the critical path

Screenshots via `xcrun simctl io … screenshot`, Mac via `screencapture -R`, App Preview via
`recordVideo` in **two passes** (per §2(a)): *Pass A* on an erased device for splash → onboarding
scope sweep; *Pass B* on the full-corpus device for search → document → map → Source Explorer. Same
simulator and resolution in both. Target ~25 s.

**The `prepareVolumes` capture trap — the most valuable operational line here.**
`OnboardingView.swift:311` is the app's only caller of `BundledCloudVectors.prepareVolumes()`, fired
when the user switches to Volume scope. Until it resolves, a volume scope falls back to the
**subseries** list. An early frame therefore shows the *era's* vocabulary and looks entirely
plausible. **Hold for the LensChip before recording.**

**Store copy: lift, do not write.** The repo contains **no** App Store Connect metadata of any kind.
It does contain owner-reviewed strings that already passed review — but with two corrections the
drafts missed:

- The candidate line *"The official documentary record of U.S. foreign policy since 1861…"* is
  **83 characters too long for the 30-character subtitle field** (it is 113), and it leads with "official"
  while the mandatory disclaimer (*not an official product of the Office of the Historian or the
  U.S. Department of State*) sits in About, out of view. Use it as **promotional text or
  description**, never as the subtitle, and put the disclaimer in the **same field**.
- Fix `README.md:14` while there: it says build 37; `project.yml:241` says 44. The README is about to
  become a public landing page.

**Hero image: use a live screenshot of the map, not the figure export.** The live view already prints
its own disclosure beneath it (*"Layout preserves local similarity; distances between far regions are
not meaningful."*). Promote `ipad/semantic-map` and `macos/semantic-map` from backlog to scheduled.

### 4.2 Research and press figures

**FLAGSHIP — publication lag against the statutory target.** `PublicationLagTarget.swift:13-50`
encodes the 1961/1972/1985 presidential directives and the 1991 statute as a step function on the
publication-year axis. *"How late is the official record against the law that governs it"* is a
stronger press story than the provenance plate, renders through the same free container, and needs
**zero downloads**. Three of the four zero-download Series dashboards were unscheduled by every
draft; this is the best of them.

**PLATE A — "Where the editors found the documents." Real, but its headline claim was wrong.**

The winning draft asserted that the Central Foreign Policy File being *"literally zero in every
decade before 1970"* shows *"the 1963 renumbering, visible as a discontinuity."* **Strike that
sentence.** `ProvenanceCategory.swift:33-36` defines `centralForeignPolicyFile` as *"CFPF,
**1973–1979** — the P/D/N-reel and AAD Electronic Telegrams format"*, reached only via `.cfpfFile`.
The 1963 renumbering produced **subject-numeric designators** (`POL 27 VIET S`), which the shared
grammar files under `centralDecimalFile`. **The 1963 renumbering is by construction invisible in this
artifact.** What the plate shows at 1970 is the arrival of a *citation format*, and the legend will
label the whole subject-numeric era "Central Decimal File".

The surviving finding is still publishable and still good: the central decimal file falls from ~99%
of source notes to under 1%, and presidential libraries rise from nothing to a majority. Four
conditions before it ships:

1. **Restore the 1920s row** (17 volumes, 13,412 notes, 98.5% central decimal file). The draft's
   table jumped 1910s → 1930s without saying so.
2. **Export with no category hidden.** The dashboard has a one-tap "Hide Other / Unclassified" that
   **re-bases every share** — the natural aesthetic choice, and it silently changes every number.
3. **Decide the pre-1900 axis, and caption it either way.** This is not "either is defensible": the
   1860s are 22 volumes and 1,890 of 1,891 notes `unrecognized`; under 1900, one note in 1,946
   parses. Included without a caption, the plate shows a solid "Other/Unclassified" wall that reads
   as *the editors did not say where these came from* when it means *the parser did not classify
   these*. The fixing sentence exists — and is CSV-only today.
4. Thread the artifact's `generated` stamp into the methods line.

**PLATE B — the map under the Provenance lens.** The same finding rendered spatially rather than
quantitatively, which is what gets two figures into one paper instead of one figure and a decoration.
Blocked on Gap 3.

**FILM — "The record assembles itself."** 553 chronological frames, no new app code. Five defects
must be fixed first; see §6 and §7.

### 4.3 What "ships today" actually means

| Asset | Renders today | Prerequisite | Citable today |
|---|---|---|---|
| Map figure | yes | **none** (bundled) | **no** — Gaps 1–3 |
| Series dashboard plates (×4) | yes | **none** (bundled) | **no** — Gaps 1–2 |
| Corpus term-frequency plate | yes | **all 552 volumes indexed** | no |
| Word-cloud / keyness plate | yes | **all 552 volumes indexed** | no |
| Frame sequence | yes | Metal + simulator + env var | **no** — sidecar defect, frame holes |

**There are twelve `AnalyticsFigureCanvas` plates, not eleven.** Corpus Analytics term frequency
(`AnalyticsView.swift:904`, `:907`) is wired to a hand-built PNG/PDF menu rather than through
`AnalyticsSectionExportControl`, which is why an `exportFigure:` grep misses it. *"Mentions of
Vietnam across the series, 1861–1989"* is the most legible chart the app draws and appeared in no
draft. It also means Gate C's blast radius is one plate larger than stated.

**The word-cloud trap.** `WordCloudView` and `WordCloudLoader` both gate on the index and reference
`BundledCloudVectors` **nowhere** — the bundled vectors feed only the *backdrop* surfaces. The map
figure needs zero downloads; the word-cloud plate needs the multi-hour index. Two assets that read as
equally free have wildly different setup costs. Separately, `WordCloudExporter` is a **different
container** that never pins `colorScheme` and draws its credit with `.secondary` — a plate exported
on a dark-appearance device is a different-looking plate with a possibly invisible credit.

*Corollary nobody scheduled:* the three entity lenses (people/places/organizations) **are** already
selectable and exportable in-app over an indexed corpus. Only the *bundled* artifact costs the
~50–60 minute generator run. A talk can have a people cloud today.

---

## 5. Disclosure — the sentences each asset must carry

Design §8 is binding and says the quiet part plainly: *"a promotional image that drops the caveat is
the one way this program does damage."* **The mechanism rule: caveats travel in the pixels, not in a
sidecar** — a sidecar is the first thing lost when a clip is reposted.

| Asset family | Must carry | Source |
|---|---|---|
| Any exported figure | OH/State attribution + public-domain line; and the "accompanies this figure in its CSV export" line reworded | `AnalyticsProvenance.swift:109-112`; `AnalyticsFigureExport.swift:79-80` |
| Anything showing the map | *"Layout preserves local similarity; distances between far regions are not meaningful."* | `SemanticMapSpikeView.swift:1444-1450` |
| Anything naming a region | ***"This surface is experimental."*** + the clustering sentence + coverage (179 regions, 226,276 documents; **88,207 sit between regions**) | `SemanticMapExport.swift:128-135` |
| Provenance lens | plurality-not-majority, 73 of 522 | `SemanticMapLens.swift:100` |
| Any scoped-map animation | the scope-is-a-set-of-volumes grain sentence | `SemanticMapFrameSequence.swift:84-85` |
| Anything on `provenance-flow-index.json` | 95.3% of edges are footnotes — annotation practice, not a relation between archives | design §8 |
| Anything showing NARA data | *"not affiliated with, endorsed by, or sponsored by the National Archives…"* | `AboutView.swift:710-719` |
| Store copy / launch post mentioning meaning search | **Gemma: "describe, never brand"** — no rights to Google marks or to suggest endorsement | `gemma-terms-of-use.txt:132-137`; `Gemma-Compliance-Runbook.md:163-164` |
| Everything | *not an official product of the Office of the Historian or the U.S. Department of State* — and note it continues *"Any commentary… reflects personal views,"* which is the **operative framing** for Plate A's claim, not boilerplate | `AboutView.swift:750-756` |

**Four amendments to the caveat text itself:**
1. **Do not elide "This surface is experimental."** Every other semantic surface carries that word on
   screen. Restore it verbatim.
2. `SemanticMapExport` returns **seven** caveats; the drafts carried two. The **artifact stamp +
   provenance digest** caveat is the one that makes a published figure reproducible — it must be in
   the subset.
3. *"Volumes with ten notes or fewer are left uncolored"* **contradicts the code**, which colours at
   exactly ten and has a test pinning that inclusive boundary. **Fix the caption, not the code.**
   Invisible today only because no volume sits at exactly ten.
4. "73 of 522" is measured over the **498 coloured** volumes. Literally true, imprecise.

**Two copy rules.** The map draws **314,483** documents; the app indexes **316,839** — a title card
reading "every document" would be wrong. And **no marketing number may come from `CLAUDE.md` or a
generator doc comment**: several are measurably stale against the shipped artifacts (external-citation
volume counts 284 vs 440 on disk). The app is safe because it recomputes at render time; **a store
description has no recompute step.**

**Everything here is English-only and nothing says so.** No `.xcstrings` ships; every
`String(localized:)` resolves to its inline default. Scope the launch to English territories or
state the limitation.

---

## 6. Operations — the plan's largest structural gap

No draft answered *where the output goes*, and the repo has no convention. Decide these before the
first sitting:

- **Destination.** There is no `Docs/figures/` and no marketing-asset directory. The only screenshot
  home is `Docs/screenshots/{ios,ipad,macos}/` under a lowercase-kebab naming rule. `.gitignore`
  already anticipates `fastlane/screenshots/**` though no fastlane exists.
- **Regeneration.** The artifacts move — `source-provenance-index.json` was regenerated 2026-08-19
  with a schema bump. Every published plate goes silently stale. **Rule: a published asset is
  re-exported when its artifact's `generated` stamp changes**, and there must be somewhere to look
  up which artifact a given asset came from.
- **Who runs it.** Only macOS produces a file at a chosen path (`NSSavePanel`); iOS returns a share
  sheet into a per-UUID temp directory. **Every plate must be exported on macOS** — while the four
  Series dashboards' capture convention is written for an iOS simulator.
- **Filename collisions.** `filenameStem` stamps **date only, no time**, and the map's title is the
  fixed "Semantic map" — so every map plate exported on one day collides, with the overwrite prompt
  as the only guard.
- **A batch route is precedented and should not be dismissed.** `SemanticMapOffscreenTests.swift:229-243`
  already drives the whole path — offscreen render → canvas → PNG bytes — and the env-gated
  generator-test pattern is established. A `RENDER_PLATES_DIR`-gated test emitting all twelve plates
  is the **only** option that answers the regeneration question. Record the choice either way.
- **A third device axis.** The two device states (corpus-empty, corpus-full) are incomplete: Session A
  also needs *a project active* plus hand-authored collections, notes, tags and saved searches, none
  of which is downloaded or bundled — and it must wait for person-rollup consolidation.
- **Device classes are asserted, not verified.** The documented capture program is iPhone 17 +
  iPad Pro 11″; store requirements (6.9″, 13″) are external facts. Verify against App Store Connect
  before rendering, and apply that rule to screenshots as well as previews.

---

## 7. Sequence

**Gates first.** A gate makes downstream output *unpublishable*, not merely unfinished.

- **GATE A — owner-only, start now.** Fill the four EULA placeholders (gates App Store submission of
  any encoder-carrying build; **TestFlight is explicitly not gated**). Decide the privacy nutrition
  label — **no `PrivacyInfo.xcprivacy` exists anywhere in the repo**. Neither is visual; both are
  hard blockers that surface the week you planned to submit.
- **GATE B — start the full 552-volume download and index now.** ~317,000 documents; the longest
  pole. Every store screenshot, Pass B, and every word-cloud or term-frequency plate depends on it.
- **GATE C — fix the caption band. Size L, not M.** It is the funnel for **twelve** plates; it needs
  a **per-provenance-builder** caveat designation across five builders (the map's caveats are not
  Plate A's — Plate A needs its dating rule and its Other/Unclassified sentence); it adds
  `String(localized:)` strings the audit suite gates; and the "~60 pt on a 900 pt plate" budget is
  the *map's* geometry — the Series plates default to `chartHeight: 300`, where 60 pt is a fifth of
  the chart. Reword the false CSV sentence in the same change. **Highest-leverage item in the plan.**

Then, in order:

1. **Route `lens.caption` into both export halves (S)**; fix the two wording imprecisions while there.
2. **Fix the two print defects (S each)** — blend factor and colour space. Add one assertion apiece;
   **verify on device and on screen**, since the pipeline is shared.
3. **Draft store copy by lifting (M).** Fix the README build number.
4. **Film what already exists — one afternoon, zero code.** Run the frame sequence; record the splash,
   the drifting indexing strip, the lens picker, and the camera **teleport**. This settles whether
   the material justifies engineering before a line is written, and the teleport recording is the
   "before" shot that justifies M-1.
5. **Ship the publication-lag plate**, then Plate A under §4.2's four conditions. Plate A rides the
   *fresh-install* device (State A), not Gate B — and it already has a scheduled capture sitting.
6. **Build the three device states** and confirm State A still shows the splash before shooting.
7. **Run the capture sessions.** The shot list stages ~41 rows ≈ **44–48 files**, not the 31 stale
   committed PNGs that circulated as a work estimate. Shoot store frames as a separate pass.
8. **Finish the film (M, mostly assembly).** **Pre-flight `ls | wc -l == records.count` before
   assembling**: a nil frame is skipped with `continue`, leaving a hole that stops `ffmpeg`, and the
   closing frame's index is `records.count`, which after one skip **overwrites a real frame**. Crop
   the ~44% dead width and put the grain sentence in the reclaimed margin; generate subtitles from
   `framesCSV`, whose fields are already exactly a subtitle track's; fix the `provenance.txt`
   `indexedVolumeCount: 0` and the hardcoded lens label. Not "zero Swift" — those two literals are in
   the test target.
9. **Record the App Preview in two passes and cut (L).**
10. **M-1 + M-2 as one change (M).** The accessibility contract ships with the motion.
11. **Plate B (S after step 1).**
12. **M-3, M-4, M-5** — all three already ride Plan-of-Record row B-3.
13. **Compose hero and captioned frames outside the repo.** No device-frame tooling, no fastlane, no
    metadata directory. Design-tool work, not engineering.
14. **Post-launch, follow the design's own §9 order.**

**One tension recorded rather than resolved.** §7.4 (word-cloud animation) is last on engineering
risk, but it is the **only** item producing posts indefinitely — 552 volumes × 4 lenses of bundled,
zero-download content. The hero clip is one post; this is hundreds. If marketing cadence outranks
engineering risk this cycle, promote it. That is an owner call.

---

## 8. Refusals

1. **Do not use the 553-frame sequence as the App Preview.** Wrong aspect (1920×1080 landscape),
   ~10 fps, the camera **never moves** (all 553 frames are one static shot), no chrome, a sidecar
   reading *"Only the 0 volume(s) indexed…"*, and a nil frame both holes the sequence and overwrites
   a real frame. A beautiful publication asset; keep it off the launch path.
2. **Do not parameterise `AnalyticsFigureCanvas` for a chrome-free marketing plate.** Stripping the
   methods band is precisely the §8 failure. **Screenshot for a clean image; export for a figure.**
3. **Do not ship title-only word-cloud plates.** A plate showing sized counts with no scope, date,
   credit or ranking basis violates §8. Make the caption band *beautiful* — a typography task, not a
   disclosure exemption.
4. **Do not automate splash or onboarding capture through XCUITest.** The harness cannot see it.
5. **Do not put a free-running clock on the map.** Every motion item here is a bounded transit.
6. **Do not build the slice morph.** `setSlice` calls `setPoints`, which reallocates and **clobbers
   the scope flags**; interpolating needs a new in-place mutator plus a per-frame projection over
   314,483 rows — L, for one transition on a rarely-visited surface, risking a composition three
   comments exist to protect.
7. **Do not schedule figure plates for the four Canvas graph surfaces.** Two carry explicit in-code
   export refusals; the other two have no export control. Independently disqualifying: the force
   layouts **re-randomise across process runs** (nodes appended from an unsorted Dictionary) and any
   resize re-runs the solver, so a poster render is a *different picture, not a scaled one*.
   **Export the CSV and typeset in the paper's toolchain; screenshot them for marketing.**
8. **Do not build a GIF path.** 256 colours, no alpha blending, against a near-black ground carrying
   179 hue-coded regions at 0.72 alpha. Use external ffmpeg. Adding a video encoder to this app to
   make a marketing clip is the tail wagging the dog.
9. **Do not bundle a pre-rendered video.** Resources already run to 47.37 MB. Every animation here is
   computed at runtime from artifacts that already ship — which is exactly why it is proposable. A
   baked clip would be paid for by every user who never watches it and would sever the frames from
   their provenance.
10. **Do not build bundled entity word clouds for launch** — the most marketable lenses and the most
    expensive. They are already available in-app over an indexed corpus.
11. **Do not put any image beyond the existing dim tile on the iOS launch storyboard.** It runs no
    code and its snapshot is cached before the process exists.
12. **Do not randomise the splash lens before 1.0.** Seed it.
13. **Do not animate the Series charts.** A reviewer cannot cite a frame, and a stacked area shows the
    whole sweep at once — which is the entire point.
14. **Do not add a second motion vocabulary.** The app has exactly one — closed-form functions of
    absolute time inside `TimelineView(.animation)`. `matchedGeometryEffect`, `phaseAnimator`,
    `keyframeAnimator` and `symbolEffect` appear nowhere. The motion-accessibility story is coherent
    *precisely because there is only one pattern to get right*.
15. **Do not try to film the macOS hover magnifier.** Documented uncapturable by every path tried;
    it needs ScreenCaptureKit, which nothing here uses.
16. **Do not cite `FrameTimeProbe` for a shipping build.** It is file-level `#if DEBUG` and returns
    `self` in release, while its own doc comment still argues it is *not* DEBUG-gated. That comment
    is stale.

---

## 9. Measured, assumed, and unverifiable

**Measured against the tree this session:** the CFPF category definition and the artifact's sixteen
decade rows (both P0 corrections); the arbiter's single-switch precedence; the map renderer's blend
factors, unused `Uniforms.alpha` and both hardcoded call sites, colour-space readback, paused-view
configuration and camera `didSet`; `captionLines`' two-element return and `corpusAttribution`'s
CSV-only placement; the `seeData` sentence; the plurality caption's single consumer; the frame
sequence's grain sentence and skip-and-overwrite mechanism; the two Canvas export refusals; the
reveal tests' assertions; the twelfth plate; the README/`project.yml` build drift.

**Assumed (inherited from the verified pack, not re-opened):** the 553-frame / 57.6 s timing; the
~44% dead-width geometry; the alpha-clamp arithmetic; the zero-`reduceMotion` result across
`FRUSExplorer/Semantic/`; the unsorted-Dictionary layout nondeterminism; the `provenance.txt`
defect; the macOS hover-magnifier capture failures.

**Unverifiable from a Linux checkout, and stated as such:** whether the sRGB/DeviceRGB mismatch
produces a visible hue shift in print; whether the blend-factor fix is visible on screen as well as
in the plate; whether the word-cloud plate's `.secondary` credit resolves dark under a dark-appearance
renderer. All three need a device. None blocks the plan; all three belong on the same on-device check
step 2 already schedules.
