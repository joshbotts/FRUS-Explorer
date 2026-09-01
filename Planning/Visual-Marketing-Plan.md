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
| ~~1~~ | **FIXED 2026-08-31 (GATE C).** ~~The caption band carries no caveats and no source attribution.~~ `AnalyticsProvenance.captionLines` returns exactly `[figureTitle, facts]` (`AnalyticsProvenance.swift:169-176`); `extraCaveats`, `corpusCaveat` and `corpusAttribution` are appended **only** in `csvPreambleLines` (`:180`, `:213`). Every plate credits "FRUS Explorer 0.2" and **not** the Office of the Historian. | Blocks publication |
| ~~2~~ | **FIXED 2026-08-31 (GATE C).** ~~The plate prints a sentence a standalone PNG makes false.~~ `AnalyticsFigureExport.swift:79-80` unconditionally renders *"Full method, caveats, and the underlying numbers accompany this figure in its CSV export."* Publish the image alone and it does not merely omit its caveats — it asserts they travelled with it. | Blocks publication |
| ~~3~~ | **FIXED 2026-08-31 (step 1).** ~~The map's mandatory lens caveat reaches neither export half.~~ `SemanticMapLens.swift:100` carries *"a plurality, not a majority, for 73 of 522 volumes"*; its only consumer is the on-screen legend (`SemanticMapSpikeView.swift:2990`). `SemanticMapExport.caveats` takes a lens **label**, not a lens. | Blocks Provenance-lens publication |
| ~~4~~ | **FIXED 2026-08-31 (step 2).** ~~The plate is washed toward white and its brightest dots clamp.~~ `sourceAlphaBlendFactor = .sourceAlpha` (`SemanticMapRenderer.swift:377`), not `.one`. Readback alpha lands ~0.79–0.84 while RGB holds a full over-composite against the dark clear colour — and the image is *declared* premultiplied, so compositing over `AnalyticsFigureCanvas`'s forced white clamps bright dots to pure white rather than lightening uniformly. | Print defect (S) |
| ~~5~~ | **FIXED 2026-08-31.** Colour space in step 2; the methods half now. ~~The plate cannot state what was in frame.~~ The export builds uniforms from its own 1144:900 ratio, so the exported field of view differs from a wide Mac window's, and the label layer re-runs its spacing rule against the export rectangle — the figure can name regions the reader never saw named. The caveat list states no camera centre, no half-extent, no aspect. Readback is untagged `CGColorSpaceCreateDeviceRGB` (`:730`, `:744`). | Methods gap (S–M) |

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

| Item | Data | Motion | Renderer | Path |
|---|---|---|---|---|
| Launch splash cloud + shimmer | pre-bundled | continuous | **Text (static words); the shimmer is the only motion** | `LaunchSplashView.swift:50-51`, `:97` |
| **Onboarding scope-tracking cloud** — the best 8-second demo in the app | pre-bundled | continuous | **Text (static)** | `OnboardingView.swift:99-112`, `:123`; its doc calls this "the reason the vectors are bundled at all" |
| Indexing drift cloud — the app's **only** continuous particle animation | pre-bundled | continuous, closed-form | **Drift (Canvas)** | `drift: true` appears at exactly two sites: `IndexingCloudStrip.swift:61`, `PendingCloudBackdrop.swift:92` |
| Live Activity / Dynamic Island | index-fed | system | out of process (ActivityKit) | `FRUSExplorerWidgets/IndexingLiveActivity.swift` |

**The Renderer column is load-bearing** *(added 2026-08-31, §10)*. `WordCloudBackdropView.drift`
defaults to `false` (`WordCloudBackdropView.swift:71`) and is opt-in per surface; only the two sites
two rows below pass it. **The splash and the onboarding cloud have never run the particle canvas.**
A row that proposes changing "the splash's drift" is proposing to *enable a renderer*, not to tune a
constant — see M-4. Note also that the splash's `continuous` Motion cell describes its shimmer
(`LaunchSplashView.swift:98`), not its words: the static resolver never touches `fillFactor` or
`WordCloudDriftField.expansion`, so today's splash is 50 spiral-packed words, not a full-bleed field.

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
`reduceTransparency` (re-measured 2026-08-31 across all 20 files: still zero), while eight other
files read them. It is cheap precisely because **today's shipped jump *is* the Reduce Motion path** —
the cheapest accessibility story available anywhere in this repo, and the reason M-1 is authorizable
at all.

*Widened 2026-08-31, §10.* **Write the contract once, in words, and apply it: pin the value, not the
schedule; simplify the transition, never remove it.** (Near-verbatim from
`WordCloudDriftCanvas.swift:127`; the first half paraphrases `:210`/`:217`.) Three things ride with
it, and the first is not the fix the review proposed:

- **`LaunchSplashView.swift:98` uses `paused: reduceMotion`** where the drift canvas *slows the
  interval and pins the clock inside the renderer* (`TimelineView(.animation(minimumInterval:
  reduceMotion ? 1.0 / 6.0 : nil))`, `:133-135`). It is harmless today because the phase is also
  substituted (`:99-101`, a deterministic date-independent pose), and **the remedy is the interval
  substitution, not dropping `paused:`** — dropping it while keeping a 30 Hz schedule buys a
  body re-evaluation and Canvas re-composite producing a byte-identical frame, on a
  `.cloudKitImport` splash that is by definition a main-thread-contended wait. Match the drift
  canvas's shape or leave it; do not half-apply the rule.
  **RESOLVED 2026-08-31 as LEAVE IT, with the reason written at the code.** The two diverge for a
  cause: the drift canvas slows rather than pauses because it still has something to say — it keeps
  cycling lenses — while the shimmer's phase is substituted with a constant, so every frame after
  the first is byte-identical. Slowing its schedule would buy a re-composite per tick to produce an
  indistinguishable frame. The value is pinned and no transition remains to simplify.
- ~~**`WordCloudView.swift:97` declares `@Environment(\.accessibilityReduceMotion)` and never uses
  it**~~ **DELETED 2026-08-31.** The deletion arm, because there was nothing to implement: that view
  has no motion of its own — the drift lives in the backdrop, which reads the setting itself — and
  adding an animation to its lens picker purely to justify an environment read would be inventing
  scope to keep a variable.
- **State the Reduce Transparency behaviour rather than implying one**, given a dark full-bleed
  field with dots at alpha 0.72 — including "no change, and why," if that is the answer. And note
  what is missing beside it: **`accessibilityDifferentiateWithoutColor` appears nowhere under
  `Semantic/`**, though it is honoured with a documented rationale at `WordCloudView.swift:101`
  (consumed `:609`/`:612`/`:640`) on a surface far *less* colour-dependent than a map whose cluster
  lens is an even hue sweep and whose provenance lens is a ten-hue legend.

**M-3 · Lens dip — M.** The fade lever exists end to end and is unused: `Uniforms.alpha` is declared,
consumed by the shader, and **hardcoded to 1.0 at both call sites**. Drive 1.0 → ~0.25 → 1.0 across
the swap. A dip, not a cross-dissolve: `colourIndex` changes meaning per lens, so a palette lerp is
meaningless and a real dissolve needs two draws. *Favourable and non-obvious:* `setColourIndices`
leaves the flags byte untouched, so a lens dip composes correctly with a live scope.
*Do not forget:* if `alpha` becomes a stored property, the offscreen path must keep passing 1.0
explicitly, or a figure exported mid-dip is a faded plate.

*Duration named 2026-08-31, §10.* Use **`FRUSTheme.cloudTransformDuration` (1.15 s,
`FRUSTheme.swift:621`)** — the app's one constant for "this surface is changing what it is showing
you," already shared across both cloud renderers by explicit design (`WordCloudBackdropView.swift:397`,
`:404`; `WordCloudDriftCanvas.swift:278`, whose comment says the crossfade is matched to it "so the
two surfaces feel like one animation"). **Do not introduce a second figure.**

The review that proposed this argued it as "two lens pickers running at different speeds"; that
comparison does not exist and should not be repeated. `WordCloudView`, the app's only *user-facing*
lens picker, consumes no timing constant at all — `lens = option` (`WordCloudView.swift:328`), with
no `withAnimation` and no `.animation(` in 2,024 lines. The real argument is the simpler one above.
That absence is also the missing half of M-2's case: the flagship picker has neither a motion
contract nor a timing constant.

*While in the file:* `FRUSTheme.swift:574` still reads `// MARK: - Onboarding cloud backdrop (O-2)`
for constants now serving five surfaces across four host features in three directories. Rename it —
and fold in the dangling `// MARK: Chrome` two lines above at `:572`, which has no body, rather than
leaving a second wrong header behind the renamed one. Alias or rename the constant so a `Semantic/`
file can reference it without reading as a borrow.

*Pair with §1 Gap 4 — with one scheduling conflict to resolve first.* Both are "one shared pipeline,
two consumers, one of which is a published figure" (the blend factor at `SemanticMapRenderer.swift:377`
and the `Uniforms.alpha` field at `:94`). But **§7 schedules Gap 4 at step 2** while M-3 is step 8.
Either pull M-3's shared assertion forward to step 2 or accept that Gap 4 ships first and M-3 adds
its assertion later; do not leave the plan asserting both a pairing and a six-step gap.

**M-4 / M-5 · Splash drift and seeded lens — re-priced 2026-08-31 to `S in code, M in risk`.**
The fresh-install splash lives exactly 1.6 s (verified, `ContentView.swift:171-176`). The drift
period is ~18.5 s, so a word traverses at most **53.7%** of its 14 pt excursion in the worst case.
Both effects are real on the **`.cloudKitImport` splash**, which the code itself calls *"a real wait,
of real duration"* — that is where to spend them. Ship the lens **seeded, never randomised**, before
1.0: the splash is simultaneously the App Preview's opening frame, a store screenshot and the README
hero, and randomising it makes the one beat you most need to reproduce non-reproducible.

*Corrected 2026-08-31, §10 — three sentences in the original row were wrong, and the conclusion is
unchanged.*

1. **"The splash never advances past lens 0 regardless of seeding" is REFUTED.** The phase is
   wall-clock-derived (`WordCloudBackdropView.swift:149-151`) and `lensIndex` takes the absolute
   phase integer, so roughly 38% of 1.6 s splashes cross a 4.2 s boundary and land on an arbitrary
   lens. This *strengthens* M-5 — the beat is non-reproducible today — but the sentence is false and
   must not be quoted forward.
2. **The row is priced as if it adjusts an existing effect. It does not.** The splash is on the
   static `Text` renderer (§3.1); M-4 **enables the particle Canvas on a first-run composition**,
   which is the blast radius `WordCloudBackdropView.drift`'s own doc comment (`:63-70`) exists to
   contain. Hence `S in code, M in risk`. It requires a `WordCloudDriftField` test covering
   `identityZone` at phone width — the `push` path has never run in production, because no drifting
   surface passes a zone — and an on-device composition review at phone and Mac widths before it
   reaches `.freshInstall`. **It is not gated on anything else**; an earlier draft of this
   correction made it a prerequisite of a defect that does not exist (§10).
3. **A real bug sits directly on this path and must be fixed with M-4, not after it.**
   `WordCloudDriftField.state(of:)` clamps with the surface's bleed (`:264`) while `push`'s
   acceptance test re-clamps with the default `bleed: 0` (`:302` against the signature at `:319-320`).
   On any surface with fill > 1 — every host taller than 160 pt, i.e. **exactly the full-bleed
   splash M-4 proposes** — a valid nudge is rejected and the word is left inside the identity zone.

*The affirmative argument, which the row lacked and which is stronger than the review stated.*
`WordCloudDriftField` v1.2 spreads the composition to fill 1.12 with bleed above `bandHeight` 160,
at up to 50 words per lens (100 particles mid-crossfade, ~2.6 ms, `WordCloudBackdropView.swift:321-324`).
The static path gets **no expansion and no bleed at all**, so today's splash is the "clump stranded
in an empty expanse" v1.2 was written to fix (`WordCloudDriftField.swift:111-117`). A full-bleed
splash is the only surface that would hold the field the code was written for, long enough to see.
*(One review claim about this is REFUTED: "the indexing strip cannot reach that state — its
`minimumHeight` is 96." 96 is a `minHeight` FLOOR, not a cap (`IndexingCloudStrip.swift:48`, `:52`),
and the queue banner expands to six Dynamic-Type-scalable rows. The strip can reach it; the argument
for the splash rests on duration and composition, not on the strip's ceiling.)*

**M-6 · In-app decade accumulation — DEFERRED pending measurement.** The ordering function is
app-side and GPU-free and each step is one dirty mark, but the only cost figure in the repo
(103.8 ms/frame) **includes readback and PNG encode the on-screen path does not pay**. Measure the
live per-step cost before scoping. Recording an assumption as a measurement is how a wrong number
gets into a plan.

*The rig named 2026-08-31, §10 — the deferral stands, and it is now cheap to lift.* Use
**`SemanticMapRenderer.Stats`** (`SemanticMapRenderer.swift:117-136`): DEBUG-gated, carrying
`frameMilliseconds` / `worstMilliseconds` / `presentedFrames`, fed by a GPU completion handler
through `onStats` (`:138-142`) into `SemanticMapModel.stats` (`SemanticMapSpikeView.swift:77-80`).
It measures the on-screen map directly and needs no `TimelineView`. **Do not use `FrameTimeProbe`**:
a review proposed it, but it measures frame intervals from `TimelineView(.animation)` and
`DrawCostMeter`, whose only recorder is `WordCloudDriftCanvas.swift:170` and whose only mount is
`WordCloudBackdropView.swift:126`. M-6 is a semantic-map item and the map is `isPaused = true`;
following that pointer literally would hang a free-running SwiftUI clock beside a view whose whole
design is that it has none — refusal 5.

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
3. ~~*"Volumes with ten notes or fewer are left uncolored"* **contradicts the code**~~ **FIXED
   2026-08-31**, PR #1160 — the caption now reads *"fewer than ten"*. The plan's diagnosis was exact,
   including why it was invisible: measured against the shipped artifact, **zero of 522 volumes sit
   at exactly ten**.
4. ~~"73 of 522" is measured over the **498 coloured** volumes. Literally true, imprecise.~~
   **FIXED 2026-08-31**, PR #1160 — the caption now gives 73 against the 498 volumes the lens
   colours. Both denominators verified from `source-provenance-index.json`.

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
- ~~**GATE B — start the full 552-volume download and index now.**~~ **ALREADY SATISFIED, verified
  2026-08-31.** The author's own Mac carries **552 volumes / 316,839 documents** — the whole manifest,
  every volume. The longest pole in the plan was already finished when the plan was written; nobody
  had looked. Steps 5 and 10 and every corpus-bearing store screenshot are unblocked **now**.
- ~~**GATE C — fix the caption band.**~~ **SHIPPED 2026-08-31**, PR #1154. See the note below for
  what the sizing argument got wrong. Original text: **Size L, not M.** It is the funnel for **twelve** plates; it needs
  a **per-provenance-builder** caveat designation across five builders (the map's caveats are not
  Plate A's — Plate A needs its dating rule and its Other/Unclassified sentence); it adds
  `String(localized:)` strings the audit suite gates; and the "~60 pt on a 900 pt plate" budget is
  the *map's* geometry — the Series plates default to `chartHeight: 300`, where 60 pt is a fifth of
  the chart. Reword the false CSV sentence in the same change. **Highest-leverage item in the plan.**

  **What GATE C found, and two of this plan's premises did not survive it.**

  1. **The band does not squeeze the chart; the plate grows.** `AnalyticsFigureExporter.render`
     proposes `ProposedViewSize(width:height: nil)`, so the canvas sizes to fit and the chart keeps
     its `chartHeight` exactly. **Measured**: full disclosure costs **+152 px at 2× = +76 pt**, and
     the same +76 pt whether the chart is 240 pt or 900 pt. A 240 pt Series plate goes 842 → 994 px;
     the map plate 2162 → 2314 px. So the real question was never "does the caveat block eat a fifth
     of the chart" — it is "what share of the image is method text", which is 18% on the smallest
     plate and 7% on the map. For a *research* figure that is correct rather than excessive.
  2. **"Five builders" undercounts by a factor of three.** There are **14 `AnalyticsProvenance(`
     construction sites across 7 files**. The fix therefore did not designate caveats per builder at
     all: `plateCaveats` defaults to `nil`, which prints **everything the CSV prints**, so no builder
     can silently under-disclose and none had to be edited. Trimming is available, deliberate, and
     structurally safe — a designation FILTERS `allCaveats`, so a trim can never invent a
     qualification the method block does not make, and `corpusCaveat` survives every trim.

  Also confirmed exactly as written: **twelve plates** funnel through the canvas, and the Series
  dashboards' `figureHeight` default is `300` — though every real call site passes 240–280, so the
  proportion is worse than the plan's own figure, not better.

Then, in order. *(Re-sequenced 2026-08-31, §10: a step 0 added, and the three motion items moved
ahead of the capture sessions. Old numbers in brackets.)*

0. ~~**Withdraw the pending cloud when indexing begins (XS).**~~ **SHIPPED 2026-08-31**, PR #1156 —
   by making the whole predicate live rather than by the `onChange` alternative, which fixes only
   the indexing half. **The staleness cuts both ways and this plan named only one**: a wait that
   began before the vectors were resident could never acquire a cloud when they arrived, because
   `isCoreReady` turning true also re-ran nothing. The task is now keyed on
   `PendingCloudRule.Liveness` — pending, indexing, core-ready. `isUITestMode` is deliberately
   excluded: it cannot change within a process, and reading it per body pass would build a
   `ProcessInfo.environment` dictionary on a view that is on screen during every search.

   The key is a named type beside the rule rather than a private struct in the view, for the reason
   `PendingCloudRule`'s own comment gives — *rules that can be evaluated are rules that can be wrong
   out loud*. **The rule was never wrong here; consulting it once and keeping the answer was**, so
   the liveness needed a test as much as the rule did. `keyIsCompleteOverTheDecision` is exhaustive
   over the eight reachable states and asserts the invariant directly: no two states with different
   verdicts may share a key. Dropping either field from the key fails it by name. Original text: `PendingCloudBackdrop.canShow` is
   sampled **once**, inside `.task(id: isPending)` (`PendingCloudBackdrop.swift:99-104`), and
   `isShowing` is `@State` that is never re-tested. So a search cloud already up when a batch starts
   keeps drifting *above* the newly-mounted banner strip — genuinely two drifting Canvases, the state
   `PendingCloudRule`'s own comment forbids. Make the predicate live: carry the surface in the task
   id, or add `.onChange(of: appState.indexingBatch != nil) { if $1 { isShowing = false } }`.
   **Not** the predicate swap a review proposed — see §10 for why that fixes nothing and costs the
   search backdrop the whole pre-indexing download phase.

1. ~~**Route `lens.caption` into both export halves (S)**; fix the two wording imprecisions while
   there.~~ **SHIPPED 2026-08-31**, PR #1155. Done by replacing the `lensLabel: String` parameter
   with `lens: SemanticMapLens`, so the caption reaches both halves through the one call they share
   and cannot be omitted by a caller. **"Two wording imprecisions" was four**, and all four were the
   same defect: caveats written for the regions CSV and inherited by the figure at W-3 assert a
   table the figure does not have — "every row below", "appear in no row below", "when this table
   was taken", "this table names regions and counts". All reworded to be true of both halves.
2. ~~**Fix the two print defects (S each)** — blend factor and colour space.~~ **SHIPPED
   2026-08-31**, PR #1155. `sourceAlphaBlendFactor` `.sourceAlpha` -> `.one`; the readback is tagged
   sRGB rather than left as untagged device RGB, in both the direct and the downsampled path.

   **On the shared-pipeline warning: the blend change is a no-op on screen and provably so.** The
   `MTKView` layer is opaque, so nothing reads the alpha channel there; and with an opaque ground
   (`backgroundClearColor` alpha 1) the fixed factor yields `srcA + 1·(1−srcA) = 1` for every source
   alpha, so the visible RGB composite is unchanged. The colour-space change is readback-only and
   never touches the on-screen path at all.

   **Both assertions had to be built rather than added, and the first one written was vacuous.** No
   existing fixture could see the alpha defect: every one uses a palette with alpha 1, where
   `.sourceAlpha` and `.one` are arithmetically identical — the defect was invisible to the suite
   *by construction*, which is why the design doc could assert the opposite for months. The new test
   uses a half-transparent palette entry and asserts the invariant rather than a pixel value: an
   opaque ground stays opaque whatever is drawn over it. Under the old factor the least-opaque pixel
   measures **191**, exactly `1 − a + a²` at `a = 0.5`.
3. ~~**Draft store copy by lifting (M).**~~ **DRAFTED 2026-08-31**, PR #1160 —
   `Planning/Store-Listing-Draft.md`. Every field counted rather than estimated, every number
   measured from a shipped artifact, and the "official documentary record" line placed in the
   description with the disclaimer in the SAME field, never in the subtitle. ~~Fix the README build
   number.~~ **Done 2026-08-31 in PR #1151** — 37 → 44, with a `CodingStandardsAuditTests` gate so
   it cannot go stale again.

   **A fourth amendment to §5 is now applied in code, not just recorded.** Amendment 3 said the
   provenance-lens caption contradicts the colouring rule and to *"fix the caption, not the code"* —
   it now reads *"Volumes with fewer than ten notes are left uncolored"*, matching
   `totalNotes >= minimumProvenanceNotes`. Measured against `source-provenance-index.json`: 522
   volumes, **498 coloured**, 24 below the floor, and **zero at exactly ten**, which is why the
   defect was invisible. Amendment 4 is applied in the same string — 73 is now given against the
   **498 volumes the lens colours**, not against all 522. Both were shipping in the CSV and the
   figure as well as the legend, because step 1 routed that caption into both export halves.

   **One measured caution the plan does not carry: coverage does NOT start in 1861.** Three volumes
   print documents earlier than 1800 — `frus1872p2v5` reaches **1620** — because FRUS includes
   historical enclosures in arbitration papers. *Published since 1861* is true and checkable;
   *covering 1861 onward* is not, and a store listing has no recompute step.
4. ~~**Film what already exists — one afternoon, zero code.**~~ **THE CODE-DRIVEN HALF IS RUN**,
   2026-08-31, PR #1161 — `Planning/Capture-Runbook.md`. The filming itself stays the owner's, per
   §2(b). 553 frames, mean **100.8 ms**, worst 122.8 ms, 392 MB, no gaps — reproducing the
   2026-08-27 figures (103.8 / 123.9).

   **Running it found what reading it did not: the sequence opens in 1620 and its first six frames
   misrepresent chronology.** Ordering is by `dateRange.earliest`, and FRUS prints historical
   enclosures in arbitration papers, so three volumes published in the 1870s–1900s carry pre-1800
   documents. A clip captioned "the record accumulating chronologically" would be false for its
   opening. NOT a harness defect — ordering by earliest coverage is the honest thing for it to do —
   but a captioning obligation, with three options in the runbook (caption it, start at frame 6, or
   the one that is not available).

   **Both `provenance.txt` defects confirmed in the produced file**: it says *"Only the 0 volume(s)
   indexed on this device"*, and hard-codes the lens. Step 11 already schedules them.

   **"THE TELEPORT RECORDING IS THE BEFORE SHOT" NO LONGER WORKS AS WRITTEN**, because this step ran
   after steps 7–9 rather than before them, and the teleport is gone. It is still recordable
   exactly: **turn on Reduce Motion**, which M-2 made the behaviour that shipped for the map's whole
   life. One setting toggle on one device is a better before/after than two builds.

   **One departure from "zero code", argued in the runbook §4**: the harness skipped a failed frame
   with `continue`, which does not thin the sequence but CORRUPTS it — a hole that stops `ffmpeg`
   plus a closing frame that overwrites a real one. It throws now, which makes step 11's manual
   pre-flight unnecessary. All 553 frames rendered in this run, so the pre-flight would have passed;
   that is precisely why it was the wrong guard.
5. **Ship the publication-lag plate**, then Plate A under §4.2's four conditions. Plate A rides the
   *fresh-install* device (State A), not Gate B — and it already has a scheduled capture sitting.
6. **Build the three device states** and confirm State A still shows the splash before shooting.
7. ~~*(was 10)* **Plan §3.2's M-1 + M-2 as one change (M).**~~ **SHIPPED 2026-08-31**, PR #1158.
   **Constraint 3's premise is FALSE and must not be quoted forward**: `setScope` rebuilds the scope
   mask and drops the selection, and never touches the camera — there is no reveal-versus-`applyScope`
   race. The real race is with the writes that DO move it (`frameAll`, pan, zoom), and each now
   cancels a transit in flight. Constraints 1 and 2 were exact, and one shape satisfies both: the
   tween drives BOTH cameras through a single `applyCamera`, so `model.camera == renderer.camera`
   holds mid-flight — stronger than what shipped — while `cameraTransitDuration` defaults to `nil`,
   which keeps the synchronous contract every existing test asserts, IS the Reduce Motion path, and
   needed no test edited.
8. ~~*(was part of 12)* **Plan §3.2's M-3, the lens dip (M).**~~ **SHIPPED 2026-08-31**, PR #1158.
   The Gap 4 scheduling conflict is moot — Gap 4 shipped at step 2 and this adds its own assertion
   now, the second of the two options the note offered. `FRUSTheme.semanticLensDipDuration` is an
   ALIAS for `cloudTransformDuration`, not a second figure; the stale
   `// MARK: - Onboarding cloud backdrop (O-2)` and the bodyless `// MARK: Chrome` above it are
   folded into one correct header.
9. ~~*(was part of 12)* **Plan §3.2's M-5 alone — seed the splash lens, never randomise.**~~
   **SHIPPED 2026-08-31**, PR #1158 — **not one line, because the mechanism is not what the row
   assumed.** `lensIndex` is seeded 0, but the cadence driver assigns the ABSOLUTE phase integer at
   the first boundary it crosses, so a seed alone would be overwritten within 4.2 s. A seeded surface
   now advances RELATIVE to the first phase it saw: the start is pinned and the cycle survives.
   Unseeded surfaces keep the absolute phase byte for byte. Original text:
   It moves ahead of capture because the splash is the App Preview's opening frame *and* a store
   screenshot: capturing before seeding is capturing a beat that cannot be reproduced. **M-4 does
   not move with it** — it is `M in risk`, enables a renderer, and needs an on-device composition
   review, none of which should gate a capture program.
10. *(was 7)* **Run the capture sessions.** The shot list stages ~41 rows ≈ **44–48 files**, not the
    31 stale committed PNGs that circulated as a work estimate. Shoot store frames as a separate pass.
11. *(was 8)* **Finish the film (M, mostly assembly).** ~~**Pre-flight `ls | wc -l == records.count`
    before assembling**: a nil frame is skipped with `continue`, leaving a hole that stops `ffmpeg`,
    and the closing frame's index is `records.count`, which after one skip **overwrites a real
    frame**.~~ **NO LONGER NEEDED, 2026-08-31** — the harness throws on a failed frame (PR #1161),
    so the corruption this pre-flight guarded against cannot occur. The two `provenance.txt`
    literals below still stand. Crop the ~44% dead width and put the grain sentence in the reclaimed margin; generate
    subtitles from `framesCSV`, whose fields are already exactly a subtitle track's; fix the
    `provenance.txt` `indexedVolumeCount: 0` and the hardcoded lens label. Not "zero Swift" — those
    two literals are in the test target.
12. *(was 9)* **Record the App Preview in two passes and cut (L).**
13. *(was 11)* **Plate B (S after step 1).**
14. **Plan §3.2's M-4 — splash drift, with the `push` re-clamp fix.** After capture, deliberately.
15. *(was 13)* **Compose hero and captioned frames outside the repo.** No device-frame tooling, no
    fastlane, no metadata directory. Design-tool work, not engineering.
16. *(was 14)* **Post-launch, follow the design's own §9 order.**

**Why the motion moved ahead of the capture** *(2026-08-31)*. Old steps 7 and 9 capture the very
surfaces old steps 10 and 12 change, so the original order shipped every store screenshot and both
App Preview passes against the behaviour M-1 replaces — straight into §6's regeneration problem, for
the assets hardest to re-shoot. Step 4's teleport recording still happens; it is the before-shot.
**The moved work is index-independent, so it does not wait on Gate B** — which is the honest form of
the claim. *(A review asserted "net effect on the critical path: nothing"; that is a scheduling claim
neither this document nor the Plan of Record licenses, since neither bounds Gate B's duration nor the
moved work's. Index-independence is true, checkable, and sufficient.)*

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
    is stale. *(Sharpened 2026-08-31: the stale block is `FrameTimeProbe.swift:180-187`, with the
    purpose statement at `:172-173` — **not** `:27`, which a review cited. And the gating is
    test-enforced: `DeveloperInstrumentationGateTests.wordCloudProbeIsGated` pins three properties of
    that file by region and strips comments before matching. So this is a **documentation** defect,
    not a code one — and anyone who reads the stale comment and "fixes" it by un-gating the probe
    fails the suite. Fix the comment; leave the gate.)*
17. **Do not introduce a second duration for "this surface is changing what it is showing you."**
    *(Added 2026-08-31, §10 — refusal 14's rule applied to timing rather than to API.)* The app has
    one such constant, `FRUSTheme.cloudTransformDuration` (1.15 s), already shared across both cloud
    renderers by explicit design so the two "feel like one animation". Refusal 14 is about API
    surface and names no duration, so this is new by analogy rather than a restatement — recorded
    here rather than inside a work row, because a rule that lives only in an M-row is a rule that
    ships once and is then forgotten.

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

---

## 10. External review — 2026-08-31, `Animation-Surfaces-Review`

An outside design handoff (`Animation-Surfaces-Review` + `PLAN-REVISIONS.md`, findings A-1..A-8,
six proposed revisions R-1..R-6) reviewed §3's motion items against the shipped animation code. It
was verified claim by claim against the tree before anything was applied. **Its reading of the code
is good and several §3 rows were genuinely wrong. Its reading of the plan documents is where it
drifts — which is the reverse of what one would expect.** What survived is edited in place above,
each marked *(…2026-08-31, §10)*.

### The headline finding is REFUTED, and no document should acquire its sentence

The handoff's only claimed defect — "two drifting Canvases run at once in the download-queued
window" — does not exist. Its two quoted predicates are accurate, but the inference is not: the
drifting strip is **not raised by the arbiter**. It is raised by its host,
`MainTabView.indexingBanner` at `MainTabView.swift:452` — `} else if let batch = appState.indexingBatch {` —
and the arbiter's `.indexingBackdrop` only decides whether the *already-mounted* strip draws its
cloud. In the queue-only window the host is absent, so exactly one canvas is on screen. The two
predicates disagree only in the direction that produces **one** cloud.

The supporting quotation is an elision. The comment reads *"Never two drifting clouds at once.
**During an indexing run** the banner strip already carries one…"* (`PendingCloudBackdrop.swift:136-139`);
the handoff's `…` removes the qualifier that scopes it to `indexingBatch != nil` — the very predicate
the finding calls wrong. Code and comment agree.

**The proposed fix is wrong twice over.** It does not fix what it is sold as fixing; and because
`resolve` returns `.indexingBackdrop` on `!downloadQueue.isEmpty` alone, routing `shouldShow`
through it would **suppress the search backdrop for the entire pre-indexing download phase** — on a
fresh library, the whole first volume download — justified by a comment about a strip that is not on
screen. It also breaks five test call sites (`PendingCloudBackdropTests.swift:37,:44,:45,:52,:61`).

### Two real defects it missed, in the file it opened

- **The genuine double-cloud, by staleness rather than predicate.** Now §7 step 0.
- **The opposite defect — CONFIRMED 2026-08-31 and deliberately NOT fixed; still owed a row.**
  Verified at all three sites while shipping step 0. It is not a drive-by: closing it needs a product
  decision (should that window show a queued-download banner, or let the splash through?) *and* a
  banner state that does not exist — `IndexingQueueBannerView` needs a `batch.latest`, and in that
  window there is no batch. What step 0 did do is stop the misleading test from misleading: the doc
  comment on `relaunchMidDownloadPrefersIndexing` now states that it asserts the arbiter's value
  rather than what renders, and that the screen is blank while it passes. Original text:
  `.indexingBackdrop` is a suppression verdict that **nothing renders**. `ContentView.swift:178-181`
  reads it as "(c) owns the screen" and refuses the splash, while `MainTabView.swift:452` declines to
  mount the only thing that draws (c); `resolveSplash()` runs once (`:166-168`). So a relaunch
  mid-download-before-first-index shows **no cloud at all**. `CloudSurfaceArbiterTests.relaunchMidDownloadPrefersIndexing`
  exists for exactly this state and **passes while the screen is blank**, because it asserts the
  arbiter's value rather than what renders. Unclaimed by the handoff, and the same bug class
  `PendingCloudRule`'s doc comment catalogues. **Worth its own row when someone next opens these files.**

### Also corrected, applied above

`minimumHeight` 96 is a floor, not a cap. "50 particles" is 100 mid-crossfade. "The splash never
advances past lens 0" is false — the phase is wall-clock-derived, so ~38% of splashes land on an
arbitrary lens. "Drop `paused:`" is not the house rule's remedy. "The word cloud's lens swap runs on
`cloudTransformDuration`" describes a comparison that does not exist. `FrameTimeProbe` is not M-6's
rig. And the handoff's own claim of "no new file except one test case" is wrong for its largest
item: M-1's interpolator is mandated as "a named type with its own test" — two new files against
`project.yml`'s generate-time glob, so **`xcodegen generate` plus the scheme restore**.

### Not applied

- **R-2's condition (a)**, which gated splash drift on the refuted defect. Refused outright: it
  converts a nonexistent problem into a gate on other people's work.
- **R-6 as written.** It misquotes what the Plan of Record's cell says, and applied literally would
  delete that cell's one operational warning. Its content is applied to the Plan of Record as an
  *append*, in that document's §9.
- **"Net effect on the critical path: nothing."** Restated above as index-independence, which is
  what is actually checkable.

### The M-number collision — for anyone editing either document

**`Plan-Of-Record-2026-08-28.md` §2a and this document's §3.2 both use M-numbers, for different
rows.** §2a's M-1/M-2/M-3 are *the store listing / the five export gaps / in-app motion*; §3.2's
M-1..M-6 are *camera transit / reduce-motion contract / lens dip / splash drift / seeded lens /
decade accumulation*. Always write "plan §3.2's M-1" when crossing between them. The handoff did not
notice, and wrote §3.2's vocabulary into a §2a cell.

### Whether to commit the review document

The precedent is real — `Planning/Cross-Platform-UI-Adversarial-Review/` and
`Planning/Archive-Visit-Design-Handoff/` both track their `.dc.html` with a byte-identical
`support.js`. **Recommendation: do not commit this one.** Its citation-grade claim does not survive
verification (a refuted headline, a wrong line cite, an elided quotation), and its one piece of
content that reaches neither plan — A-8's rig pointer — was wrong and has been replaced above with
the right one. Everything worth keeping is now in this document and the Plan of Record. Committing
a third 69 KB `support.js` to preserve a superseded argument is the wrong trade.
