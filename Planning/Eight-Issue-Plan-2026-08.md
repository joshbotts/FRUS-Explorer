# Eight-Issue Plan — sequenced easiest-first

**Date**: 2026-08-01
**Issues**: #559, #597, #561, #553, #586, #562, #560, #626
**Status**: plan, awaiting owner decisions (§6)

Every effort estimate below was checked against code, and three claims were re-verified by hand
before this was written. Four issues turned out to be a different size than their titles suggest,
and two have a **false premise in the report itself** — those are called out, because a plan that
inherits a wrong premise builds the wrong thing.

---

## 1. The sequence

| # | Issue | Scope as planned (not as reported) | Effort | Schema | Platforms |
|---|---|---|---|---|---|
| 1 | **#559** keyboard never dismisses | `@FocusState` + resign-on-submit (iOS-gated) + `.scrollDismissesKeyboard` | **XS** | none | iOS behaviour, shared file |
| 2 | **#597** TipKit — *narrowed* | Re-anchor the dead tip + suppress tips under UI test. **Decline the suite.** Guide pass as PR 2 | **XS** → **S** | none | both, shared |
| 3 | **#561** duplicate prompts | Split seeder into seed / collapse; run the collapse from the existing post-import debounce | **S** | none | both, shared |
| 4 | **#553** Project Home leads | **Step 1 only**: snippets on lead rows. Peek sheet is a later, separate decision | **S** | none | both, one file |
| 5 | **#586** facet sort / truncation | Fetch all buckets, sort locally, display cap + "Show top N / All". **Cut paging** | **S** (large) | none | both, one file |
| 6 | **#562** corpus proximity axis | Depth-normalised in-volume gradient off the already-indexed `volume_structures` | **M** (small) | none | both, shared |
| 7 | **#560** bulk summarization | Truth + counting + retry classification + enumeration progress. **Cut generation controls** | **M** (mid) | none | both, shared engine |
| 8 | **#626** editable summaries | Edit + provenance chip on both document summary views + FTS5 push + export attribution | **M** (large) | none | both, **two platform-private views** |

**Tie-breaks.** #559 before #597 — both XS, but #559 is one file and a daily irritant. #561 before
#553 — both S, but #561 is deterministically testable and needs no owner decision. #553 before
#586 — #586 has more new UI states and a load-bearing ordering constraint. #562 before #560 —
#562 is contained; #560 has more files and retracts a shipped promise. #560 before #626 — #560
splits into a shippable subset; #626 has no cheap half.

**De-risking argument for slot 2.** The tip-suppression half of #597 (`Tips.hideAllTipsForTesting()`
under the existing `FRUS_UI_TEST_MODE` flag) protects every later item that touches the rail or
search. Do it early or it becomes a mystery `UIObstructionTests` failure during item 8.

---

## 2. Per issue

### 1 · #559 — Corpus Analytics keyboard (XS)

`AnalyticsView.swift` has no focus management at all: `grep FocusState` returns four files and this
is not one of them, `scrollDismissesKeyboard` returns zero hits app-wide, and `addTerm()` never
touches focus. Four small edits in one file: add `@FocusState`; **hoist `termField` out of
`ViewThatFits`** (it is instantiated in both candidates, and two live subtrees carrying `.focused()`
on one binding is not a supported shape); attach `.focused()` + `.submitLabel(.search)`; resign at
the end of `addTerm()`, **`#if os(iOS)`-gated** — ungated, Mac users lose focus after every Return.
Add `.scrollDismissesKeyboard(.interactively)` once on the body. Also fix the dangling
`testKeyboardPersistsAcrossTerms` reference at `AnalyticsRotationTests.swift:100`, which names a
function that does not exist.

**Acceptance.** Physical iPhone, portrait: type a term, Return → keyboard dismisses, chart renders
in the freed space. Swipe the chart with the field focused → dismisses interactively. macOS: Return
*keeps* focus so a second term needs no click. Re-run `AnalyticsRotationTests` on an iPhone
destination.

**Biggest risk — not #498.** Resigning focus means the "type then rotate" path arrives at rotation
with no first responder, which is the case that always passed. The real risk is a keyboard accessory
"Done" bar, which mounts a second hosting controller the shipped `.statusBarHidden(false)` would not
cover. **Do not ship an accessory bar in this PR.**

*Correction: sized S by the investigator on "it lands in #498 territory". Re-running an existing
suite is table stakes, not implementation cost. It is XS.*

### 2 · #597 — TipKit, narrowed (XS → S)

**The premise is false, and the finding is better than the request.** TipKit shipped in Session 162
and is live — but a census of `popoverTip(` / `TipView(` over the whole tree returns exactly **two**
display sites, both inside `CrossReferenceGraphView`. **`ExploreCrossReferencesTip` has no display
site anywhere** (verified: its only non-declaration reference is the `.invalidate` at
`DocumentView.swift:779`). It died when the Research Rail redesign deleted the toolbar button its
popover was attached to; the invalidate rode along on the surviving handler. So the two tips that
work are buried inside a window the user must already have found, and the tip that pointed *at* that
window can never fire. **Net first-contact discovery today is zero.**

**PR 1 (XS).** Anchor `ExploreCrossReferencesTip` to the `.graph` row in the shared
`ResearchRailView`; update its glyph to match the row; add `Tips.hideAllTipsForTesting()` to
`configureTipKit()` under `FRUS_UI_TEST_MODE`. Add a ~10-line test enumerating declared `Tip` types
and asserting each has a display site — that is what would have caught this.

**PR 2 (S), and the highest value-per-hour item in the set.** The Research Guide does not mention the
Q&CA wave at all: measured on `IndexingEducationView.swift`, `keyness` 0 hits, `collocation` 0,
`working corpus` 0, `Query Inspector` 0, `facet` 0. Add ~6 sections plus the `Docs/` mirror.

**Decline the tip suite.** ~40 candidate surfaces, ~55–65 anchor sites once platform-private views
are counted, ~120 new localized keys against no String Catalog — and the two tips that already ship
are invisible. A user who missed a popover can go to the guide; a user who missed the guide has
nowhere to go. Fix the guide first.

### 3 · #561 — duplicate default prompts (S)

`SummarizationPromptSeeder.seed(in:)` dedups by localized name and runs from one call site inside the
once-per-process boot, so its dedup pass sees the store *as it exists at boot* — and SwiftData's
CloudKit initial import lands after that. Second device: boot → empty → seed 8 → import delivers 8 →
the user sees 16 **for the rest of the session**, collapsing only at the next cold launch. On macOS
that is days. The reporter's "probable cloud sync cause" is right.

The hook already exists and was simply not used: the debounced post-import block at
`FRUSExplorerApp.swift:1852-1865` already runs three repair passes 8 s after imports go quiet, for
exactly this reason. Split `seed` into `seed` + `collapseDuplicates(in:)` and call the collapse from
that block. Make it lossless: **re-point `GeneratedSummary.promptId` to the keeper before deleting**
the duplicate. Keep the earliest-`createdAt` keeper rule, add the `id.uuidString` tiebreak
`DuplicateRecordCleanup.stableKeeper` already uses, and promote the removal log out of `#if DEBUG` —
these are synced deletions.

**Biggest risk.** Keeper divergence. If two devices pick different keepers they delete each other's
survivor and the prompt is gone everywhere. Never rank by anything that differs mid-sync.

### 4 · #553 — Project Home leads (S) — ship Step 1 alone

Both halves reproduce. `leadRow` renders only the header plus "Related to N of your documents",
because `ProjectLeadEntry` stores no body text and `ProjectLeadsService` deliberately passes
`includeSnippets: false` (it runs up to 40× per recompute). And `openDocument` calls `onNavigateAway`
— the sheet presenters pass `{ showProjectHome = false }` — then pushes onto the *Browse* stack, so
Back pops to the Browse root. One sub-claim in the report is already false: iOS **search** results
push into Search's own stack and do not dump into Browse.

**Step 1 (~20 lines).** Populate `leadSnippets` once for the ≤24 displayed leads via
`IndexingPipeline.documentSnippets(forKeys:maxLength:)` — the same point-lookup
`RelatedDocumentsEngine` already uses for shown rows — and render 2–3 lines. **Key the fetch on the
lead key set, not `projectId`**, or a recompute leaves snippets pointing at leads that are gone. Do
not flip `includeSnippets` in the service.

**Framing correction the owner should see.** The reporter's stated complaint is *navigation*. A peek
sheet does not fix that, it routes around it. The fix that matches the report is pushing the document
into the sheet's own `NavigationStack` — the pattern `SearchView` already uses successfully. See Q1.

### 5 · #586 — facet sort and truncation (large S)

**This is a defect, not an enhancement, and the report's premise is wrong.** Years are *not* sorted
by count — it is `ORDER BY k DESC` (year descending, verified at `IndexingPipeline.swift:2335`),
truncated to 50. On a broad query the visible head is metadata noise (2024|1, 2023|1…) and
**everything before roughly 1953 is unreachable.** That reframes it: not "let me re-sort", but
"three quarters of the match is hidden."

One product file. Raise the limit so every bucket returns (years and volumes are corpus-bounded; cap
people ~5,000), sort locally, and use the `controls:` slot that already exists on
`AnalyticsCollapsibleSection`. Add a display cap — "Show top 10 / 25 / 50 / All". Rewrite the
truncation string, which hardcodes "Showing the **top** N" — false the moment the sort is
alphabetical. Persist with `@AppStorage`, per the `SearchCollocationDefaults` precedent. Label the
people sort **"A–Z (name as filed)"**: 94.4% of rollups are already surname-first, and normalising to
a true surname would file Mao Zedong under "zedong".

**Biggest risk.** The facet list is `ScrollView { VStack { ForEach } }` — **not lazy**. 14k rows hangs
the panel on both platforms. The display cap must ship in the *same PR* as the raised limit; it is
the guard, not a nicety. And the sort control must not land before the limit rise, or you get a
correct-looking wrong list — alphabetising the top-50-by-count is not the alphabetical list.

**Cut the explicit paging.** It needs a page index that must reset on `invalidate(signature:)` or
page 7 of the previous match survives into a new one, and it buys nothing over scrolling a capped list.

### 6 · #562 — corpus proximity axis (small M)

`SubseriesScorer` is a two-branch step: same volume → 1.0, same subseries → 0.5. **The enabling
finding: the full per-volume hierarchy is already indexed and queryable** — `volume_structures` is
written on every index run and read by the existing public
`IndexingPipeline.cachedVolumeStructure(forVolumeId:)`, with `VolumeSection.documentIds` giving exact
within-section order. **No reindex, no index-version bump.**

Curve: adjacent in the same leaf section → 1.0; same leaf → 0.9; same volume otherwise →
0.6 + 0.4 × (common-ancestor depth ÷ **the anchor's own path depth**); different volume, same
subseries → 0.5 unchanged. Normalising by the anchor's own depth is the answer to "nesting practice
varies" — 160 volumes are flat, 449 one deep, 167 two deep, so an absolute chapter ladder cannot be
right. Same-volume stays in [0.6, 1.0], strictly above the subseries tier, so this only adds
discrimination *inside* a volume and cannot reorder anything across volumes.

**Do not rename `case subseries`.** Its rawValue is the persistence format in three places, and
`AxisWeights(rawValue:)` **silently skips unknown axes** while the `@AppStorage` readers do no
default-merge — every user who has ever dragged that slider would get the axis at weight 0. Change
`displayName` only.

**Biggest risk.** Silent degradation: if `cachedVolumeStructure` returns nil the axis quietly reverts
to today's flat 1.0 and nobody notices. Put a `#if DEBUG` print on the nil path and run acceptance on
a volume you *know* is chaptered.

**Never build the global-ordinal version.** True cross-section adjacency needs `VolumeSection`'s
shape to change, which is a parse-output change and therefore forces `currentDateIndexVersion` up and
a corpus reindex — the app's most-complained-about cost — to buy adjacency for 2.2% of documents.

### 7 · #560 — bulk summarization (mid M)

**The premise is dead, and that is the most valuable result here.** Measured: Apple's on-device model
serialises inference system-wide — 6 concurrent calls 11.50 s vs 6 serial 11.88 s (1.03×); reversing
the order to kill warm-up bias gave 1.39×. The four "concurrent" calls completed evenly staggered
~2.3 s apart: a queue, not parallelism. **The concurrency setting is not the lever**, and raising it
makes the run *look* more stalled. A ~1,400-document run is ~1,600 serialised calls and is honestly
1.5–4 hours. Nothing is stalled.

1. **Count successes, not attempts.** `counter.increment()` sits **outside** the `do/catch`
   (verified at `BackgroundSummarizationService.swift:487`), so a document that failed all five
   retries still advances the bar — a run where every document fails still reports "1400 documents
   summarized". `processBackgroundBatch` gets this right; the two paths disagree. **This is the single
   most important line in the issue.**
2. **Classify retryable vs terminal errors.** `withRetry` retries everything non-cancellation:
   2+4+8+16 = 30 s of sleep per permanently-failing document. If Apple Intelligence drops mid-run,
   1,400 documents each burn 30 s with permits held — ~2 h of pure sleeping — while the counter
   marches to "Completed".
3. **Enumeration progress.** `run()` parses every in-scope volume before it knows `total`, publishing
   `.running(0, 0)` — rendered as a bare spinner. A 1,400-result search spans ~157 volumes. Tick per
   volume; better, stream the group as volumes complete, which also stops `jobs` holding every
   document's full text at once.
4. **Stop promising parallelism.** The Stepper hint says "Higher values summarize faster but may
   exceed the model's rate limit." There is no rate limit and 6 is not faster.
5. **`@AppStorage` the concurrency setting** — it is `@State` and silently resets every sheet open.

**Cut the generation-controls work** (`instructions:`, `prewarm`, `maximumResponseTokens`). It is a
behaviour change dressed as a performance change: it alters how the model weights a user-authored
prompt, a token cap can truncate structured JSON mid-object, and it needs a 30-document quality A/B.

**Biggest risk — expectation.** None of this makes the run fast. The honest outcome is that it still
takes hours and the UI finally says so.

*Caveat: the benchmark ran as a command-line tool, not the entitled foreground app, so absolute
latencies may be optimistic. The serial-vs-concurrent ratio is measured under identical conditions on
both sides and is what the diagnosis rests on. Re-confirm in-app.*

### 8 · #626 — editable summaries on document surfaces (large M)

The affordance exists in exactly one shared place (`CollectionEntryInspector`) and every
document-facing surface is read-only and authorship-blind: `SummaryStripView` hardcodes
`Label("Summary", …)` and `SummaryBlockView` hardcodes `Label("AI summary", …)` regardless of
authorship. **`GeneratedSummary.authorship` already exists and is already deployed, so the schema cost
is zero** — that is what puts this in M rather than L.

Put the rule on `DocumentViewModel` — one `commitEditedSummary` mirroring `commitHeadnote` (trimmed
no-op guard; AI-derived seed → `.aiEdited`, else `.userWritten`) — so only *presentation* is
duplicated. It must additionally coerce `responseFormat` to `.general` when editing a `.structured`
row, and push to `IndexingPipeline.updateSummaryText` or FTS5 keeps matching the deleted AI text. Add
"Write your own summary" to **both** the no-summary branch and the Apple-Intelligence-unavailable
branch — the second is the whole point on non-AI hardware. Mint a reserved sentinel `promptId` as the
headnote path does, or the row inflates a real prompt's tallies.

**The export follow-through is not optional.** `CollectionAIAttribution.label()` is **unconditional**
and is called from the HTML, DOCX and PDF exporters. Ship the edit affordance without it and a
user-written summary exports under "AI-generated summary · Apple Intelligence (on-device)" in three
formats — exactly the defect #625 just fixed for JSON, re-created. `headnoteLabel(authorship:)` is
the template.

**Biggest risk.** `document_cache.summary_text` is one column per document while a document can own
up to 20 `GeneratedSummary` rows — last push wins. Worse, the pre-existing boot sync fetches every
`GeneratedSummary` with **no `!isHeadnoteDraft` filter**, so a collection headnote draft can already
overwrite a document's searchable summary on the next launch. Pre-existing and out of scope, but a
user-editable summary makes it visible and blameable — **file it separately**. Second: the classic
parity trap — the two views are in opposing `#if os` blocks, so the chip and commit rule get no
compiler help. Pin with a parity test, per `CollectionExportToggleParityTests`.

---

## 3. Groupings

**Ship together.** #559 + #597 PR 1 — disjoint files, both ~3-file diffs, both gated on the same
physical-device sitting. #560's five items as one PR: they are one story, "make the run tell the
truth", and splitting them makes each look arbitrary. **#626's two halves must ship together** — the
edit affordance without the export attribution change *is* a shipped mislabelling bug; if they must
split, ship the exporter change first.

**Must not ship together.** #560 and #626 — both say "summaries", and that is the trap: one touches
the provider and batch engine, the other two platform-private views plus three exporters. A combined
diff spans the whole summarization stack and is unreviewable. #562 with anything — a ranking change
needs an isolated before/after. #553 Step 1 and Step 2 — snippets are ~20 lines; bundling makes the
cheap fix wait on the expensive decision.

---

## 4. Schema gate

**None of the eight requires a CloudKit Production deploy as scoped.** Current state:
`deployedIdentifierCount = 233`, `deployedThroughBuild = "37"`, `identifiersAwaitingDeploy` empty.

That holds **only if four tempting shortcuts are refused**, each +1 identifier and an owner
round-trip that cost three PRs on the last one-boolean deploy:

| Issue | Shortcut | Instead |
|---|---|---|
| #553 | add `snippet` to `ProjectLeadEntry` | fetch live from SQLite for the ≤24 shown leads |
| #626 | add `originalAIText` to `GeneratedSummary` | mint a **second** summary; the carousel already holds 20 |
| #586 | a synced sort preference | `@AppStorage` |
| #597 | `Tips.ConfigurationOption.cloudKitContainer(_:)` | do not enable; whether TipKit's record types surface in the container is undetermined |

`CloudKitSchemaInventoryTests` is the tripwire: if it goes red on any of these, the implementation
reached for a shortcut and should be reverted, not accommodated. **Every item here can be started on
a day the owner cannot reach the CloudKit Dashboard.**

---

## 5. What I would cut

1. **#597's tip suite** — decline outright; substitute the dead-tip repair plus the guide pass.
2. **#560's generation controls** — defer to its own issue; it is the only part that can silently
   change summary quality.
3. **#553 Step 2 (the peek sheet)** — narrow to Step 1 and decide after living with richer rows.
4. **#586's explicit paging** — "Show top N / All" plus sort delivers the ask.
5. **#562's global-ordinal version** — forces a corpus reindex to buy adjacency for 2.2% of documents.

---

## 6. Open questions for the owner

**Q1 — #553: is the ask "richer rows" or "Back should return to the leads list"?** The peek answers
the first and sidesteps the second. The shape that answers the second is pushing the document into
the sheet's own `NavigationStack`, which `SearchView` already does. *Lean: ship snippets alone; if the
navigation complaint survives a week, do the in-sheet push — not a peek. Building both is building
the wrong one twice.*

**Q2 — #560: what happens to the concurrency Stepper?** Measurement says 6 is 1.0–1.4× faster than 1
and the hint promises otherwise. *Lean: narrow to 1–3 and rewrite the hint. Removing it outright is
the most honest and least code, but retracting a shipped setting is a bigger statement than the
finding warrants.*

**Q3 — #562: normalise by the anchor's own path depth, and leave subseries at 0.5?** *Lean: yes to
both. Keeping subseries at 0.5 makes the change monotone-safe — nothing that outranks something today
drops below it.*

**Q4 — #626: edit in place, or mint a second summary?** Both are zero-schema; storing the original
*on the row* is not. *Lean: mint a second. It costs one carousel entry and it is the only option that
lets you compare what the model wrote against what you corrected — which, for a provenance record, is
the point of the feature.*
