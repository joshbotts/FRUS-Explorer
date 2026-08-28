# Plan of Record — 2026-08-28, after build 44

**Status:** the single live plan, superseding `Completed/Plan-Of-Record-2026-08-23.md`
(discharged in bulk: tiers A and B shipped whole, Tier C's harvest lane closed except the
#234 scoring path, Tier D's W-9 completed FAR past its written scope — the encoder, the
licence surfaces, the zero-result fallback, and the full hybrid page all shipped — and
Tier E shipped W-11/W-16/W-17 leaving its four assessments/features). Written the day
**build 44 was tagged** (`build-44` at `c47a9d48`: search by meaning, archive visit plans,
Similar wording, overrides, freshness, Spotlight text, the quit fix) and the day the owner's
**Mac Studio began the Qwen3-14B NER harvest** — which is why Tier A is #234.

**How to keep this current:** when a session ships, strike its row. When this document's
sequencing is overtaken, replace it the way it replaced its predecessor.

---

## 1. The standing gates

1. **Build-44 tester feedback outranks the order below when it lands.** The two verdicts
   the What-to-Test notes put to testers directly: **do Meaning search's top matches
   deserve opening** (the shipped hybrid page's judgment, following the owner's own
   25-query sitting), and the carried-over **clusters/semantic-map leads-or-noise**
   question. Consequences remain pre-decided for the map (one clean removal commit,
   recorded in `Completed/Browse-Axes-Development-Plan.md`); a poor Meaning verdict
   demotes Tier B's V-5 residues, not the shipped surfaces.
2. **The Studio harvest is the owner's machine and stays untouched from here.** Nothing in
   this plan may assume its completion date; scoring rows activate when the owner says the
   stores exist.

## 2. Tier A — #234, the priority lane (next week)

The Mac Studio is running the **Qwen3-14B no-think NER sweep** over the weekend (launched
by the owner; `tools/semantic-harvest/harvest_ner.py` in the tree still lacks the W-7a
`ONLY_DOCUMENTS`/`WORKERS` additions, so this is the full-sweep route — whose store, being
per-volume and unsampled, is scoreable over any gold documents inside the volumes it
covers). The old plan's framing survives re-checking: the sweep was never the scoring
gate's input — but with it running anyway, the verdict now decides whether its OUTPUT is
used, not whether to spend the compute.

| # | Session | Scope | Gate |
|---|---|---|---|
| N-0 *(owner)* | **The M2a span sitting** | THE critical-path item, unchanged from the old plan's owner lane: key the 72 staged gold documents (`~/frus-m2a` on the Studio; `stage_m2a.py` is SEED-pinned, so a local re-stage is deterministic). The scorer refuses everything without it. The M1a identity CSV (0/300) rides the same sitting if convenient but does not gate scoring. | owner sitting |
| N-1 | **Score the weekend harvest** | When the stores exist: run `score_detections.py` over the Qwen3-14B store, the `EarlyEraNERControl` (NLTagger) store, and the editors'-markup baseline, against the keyed gold — same scorer, same documents, maximum-cardinality matching. Deliverable: the three-way table and the verdict against `People-Early-Era-Program.md` §5's gate — *does the model beat the free option by enough to justify its cost?* Record whatever the answer is; a control win is a finding, not a failure. Guard rails already in the tools: a store that sampled without `sampled_doc_ids` is refused; gold re-verified against the text layer before any detector is read. | N-0 + the harvest's stores |
| N-2 | **The verdict's consequences** | Branches on N-1, both pre-scoped: **detector wins** → design the ingestion (how detected early-era mentions reach the people browser #234 asks to extend — index shape, confidence display, the "detected, not editorial" disclosure the program mandates); **control/baseline wins** → the same browser extension built on the editors' markup + NLTagger at zero model cost, and the Studio's sweep output archived as a measured negative. Either branch ends with a build plan for the browser extension itself. | N-1 |
| N-3 | **W-7a, if a re-run is ever wanted** | The harness additions (`ONLY_DOCUMENTS` + `WORKERS`, both shapes settled by the Swift control and the #1083 probe) — folded here from the old plan, needed only if N-1's verdict demands scoped re-runs of other models. Do not build ahead of that need. | an N-1 outcome that wants more models |

## 3. Tier B — carried engineering (unblocked today)

| # | Session | Scope | Gate |
|---|---|---|---|
| B-1 | **W-13 coverage map / systematic-review mode** | Unchanged from the old plan: "opened 43 of 267 in this corpus — 12 annotated, 224 unread," from `ExportHistoryEntry` + `ProjectEngagedDocuments`, plus the exportable coverage statement completing the method appendix (searched → examined). No schema change. | none |
| B-2 | **W-14 read-aloud** | Unchanged: `AVSpeechSynthesizer` over the render tree — skip footnotes, track position, honor the read-vs-research split. Purely additive. | none |
| B-3 | **W-3 §7 remainders** | The visual-outputs backlog `Map-Figure-Export-And-Visual-Outputs.md` §7.1–7.4 still lists: the word-cloud drift harness, the splash lens, marketing plates, extra lenses. One session, or split when scoped. | none |
| B-4 | **V-5 residue: the supplementary sitting** | The shipped Meaning surfaces have never been judged the way the first 25 queries were: a second owner sitting over the SHIPPED pipeline (hybrid page + fallback), reusing the standing harness and rubric — sharpened by whatever build-44 testers report. Also the small unmeasured number: the encoder's Metal in-app footprint on a device/attended Mac run (the CPU shape measured 141→349→393→140 MB; the CLI ceiling 639–861 MB bounds Metal). | owner appetite; tester feedback helps |

## 4. Tier C — assessments (each ends with a build/no-build recommendation)

| # | Session | Scope | Gate |
|---|---|---|---|
| C-1 | **W-12 parallel-series concordance — ASSESSMENT** | Unchanged from the old plan: DBPO/DDF/AAPD/Dodis/Wilson Center volume-level concordance scoping; document-level alignment stays out. | none |
| C-2 | **W-15 geographic analytics — ASSESSMENT, historical toponymy first-class** | Unchanged: BigPicture priorities 8/10/11/12 together, with era-correct place names reconciling to stable places as the owner's stated requirement. | none |
| C-3 | **W-10 OS-27 adoption — assessment against the actual SDK** | Unchanged; first session is assessment-against-the-beta, not a build. | SDK availability |

## 5. The owner lane

| Item | Feeds |
|---|---|
| **Build 44**: the VoiceOver pass and the App Store Connect archive-and-upload (tag `build-44` is set; What-to-Test texts are paste-ready and under the 4,000-character limit) | release |
| **The M2a span sitting** (N-0) — the one thing on #234's critical path | Tier A |
| **The custom EULA paste** before any App Store (not TestFlight) submission of build 44+: fill four placeholders in `semantic-vectors/App-Store-Custom-EULA.md`, paste into App Information ▸ License Agreement | App Store review |
| Screenshot captures — #1081's 13 live placeholders, now further staled by build 44's Meaning/visit-plan surfaces | #1081 |
| Release habits: `check_repository_links.py --stamp` each release; eyeball the 3 owner-asserted URLs (JFK ×2, LBJ) | each release |
| Gemma recurring check (runbook §6): at each release carrying the encoder, re-read the PUP's last-modified date and re-run the Apache-relicensing escape-hatch check | compliance |

## 6. Standing records

Open issues: **#234** (Tier A), **#1081** (owner screenshots). Everything else the 2026-08-23
plan scheduled is shipped and struck in that document, which carries the per-row evidence.
The Gemma compliance state lives in `semantic-vectors/Gemma-Compliance-Runbook.md` (all
in-app/in-repo conditions DONE; §5 ASC EULA owner-only). The V-5 program's measurement
record lives in `semantic-vectors/` (the judged sitting, the four-route comparison, the
encoder acceptance fixture) and is the baseline any future retrieval work argues against.
