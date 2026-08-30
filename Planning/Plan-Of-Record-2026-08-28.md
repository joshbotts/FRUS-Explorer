# Plan of Record — 2026-08-28, after build 44

**Status:** the single live plan — **reviewed and revised 2026-08-29, §7** (every checkable
claim verified against the tree, the tags, the tester notes, and the issue tracker; two
corrections, two recovered residues) — superseding `Completed/Plan-Of-Record-2026-08-23.md`
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

1. **Build-44 tester feedback outranks the order below when it lands.** Two verdicts are
   outstanding — but *(corrected 2026-08-29, §7)* they are solicited by **different
   builds' notes**, not both by build 44's. Build 44's What-to-Test asks only **do Meaning
   search's top matches deserve opening** ("this is the verdict we most need", following
   the owner's own 25-query sitting). The **clusters/semantic-map leads-or-noise**
   question was build 43's ask ("coherent research leads, or arbitrary piles?") and the
   build-44 rewrite dropped it, so that verdict rides the 43 cohort; if it stays silent,
   restore the ask in the next build's notes rather than assuming it is still being put.
   Consequences remain pre-decided for the map (one clean removal commit, recorded in
   `Completed/Browse-Axes-Development-Plan.md`); a poor Meaning verdict demotes Tier B's
   V-5 residues, not the shipped surfaces.
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
| N-1 | **Score the weekend harvest** | When the stores exist: run `score_detections.py` over the Qwen3-14B store, the `EarlyEraNERControl` (NLTagger) store, and the editors'-markup baseline, against the keyed gold — same scorer, same documents, maximum-cardinality matching. Deliverable: the three-way table and the verdict on the question the scorer was designed for (`NER-RUNBOOK.md` §6–7) — *does the model beat the free option by enough to justify its cost?* — under `People-Early-Era-Program.md` §5's own binding constraint, which is prior: eval set first, nothing ships until M2a is keyed *(citation repointed 2026-08-29, §7 — §5 states the keying gate, not the comparison question)*. Record whatever the answer is; a control win is a finding, not a failure. Guard rails already in the tools: a store that sampled without `sampled_doc_ids` is refused; gold re-verified against the text layer before any detector is read. | N-0 + the harvest's stores |
| N-2 | **The verdict's consequences** | Branches on N-1, both pre-scoped: **detector wins** → design the ingestion (how detected early-era mentions reach the people browser #234 asks to extend — index shape, confidence display, the "detected, not editorial" disclosure the program mandates); **control/baseline wins** → the same browser extension built on the editors' markup + NLTagger at zero model cost, and the Studio's sweep output archived as a measured negative. Either branch ends with a build plan for the browser extension itself. | N-1 |
| N-3 | **W-7a, if a re-run is ever wanted** | The harness additions (`ONLY_DOCUMENTS` + `WORKERS`, both shapes settled by the Swift control and the #1083 probe) — folded here from the old plan, needed only if N-1's verdict demands scoped re-runs of other models. Do not build ahead of that need. | an N-1 outcome that wants more models |

## 3. Tier B — carried engineering (unblocked today)

| # | Session | Scope | Gate |
|---|---|---|---|
| B-1 | **W-13 coverage map / systematic-review mode** | Unchanged from the old plan: "opened 43 of 267 in this corpus — 12 annotated, 224 unread," from `ExportHistoryEntry` + `ProjectEngagedDocuments`, plus the exportable coverage statement completing the method appendix (searched → examined). No schema change. | none |
| B-2 | **W-14 read-aloud** | Unchanged: `AVSpeechSynthesizer` over the render tree — skip footnotes, track position, honor the read-vs-research split. Purely additive. | none |
| B-3 | **W-3 §7 remainders** | The visual-outputs backlog `Map-Figure-Export-And-Visual-Outputs.md` §7.1–7.4 still lists: the word-cloud drift harness, the splash lens, marketing plates, extra lenses. One session, or split when scoped. | none |
| B-4 | **V-5 residue: the supplementary sitting** | The shipped Meaning surfaces have never been judged the way the first 25 queries were: a second owner sitting over the SHIPPED pipeline (hybrid page + fallback), reusing the standing harness and rubric — sharpened by whatever build-44 testers report. Also the small unmeasured number: the encoder's Metal in-app footprint on a device/attended Mac run (the CPU shape measured 141→349→393→140 MB; the CLI ceiling 639–861 MB bounds Metal). | owner appetite; tester feedback helps |
| B-5 | **W-8 residue: the two June leftovers** *(recovered 2026-08-29, §7)* | Recorded in the old plan's struck W-8 row ("Left of this row") and carried nowhere until now: **enclosure dual-home rendering** (the printed text lives in its originating despatch; the classifier surfaces should say so — Finding 4 of the June pass), and the **live UI walkthrough of the pre-1910 classifier surfaces** on both platforms. Small; one sitting; no open issue tracks them, so this row is the only record. | none |

## 4. Tier C — assessments (each ends with a build/no-build recommendation)

| # | Session | Scope | Gate |
|---|---|---|---|
| C-1 | **W-12 parallel-series concordance — ASSESSMENT** | Unchanged from the old plan: DBPO/DDF/AAPD/Dodis/Wilson Center volume-level concordance scoping; document-level alignment stays out. | none |
| C-2 | **W-15 geographic analytics — ASSESSMENT, historical toponymy first-class** | Unchanged: BigPicture priorities 8/10/11/12 together, with era-correct place names reconciling to stable places as the owner's stated requirement. | none |
| C-3 | **W-10 OS-27 adoption — assessment against the actual SDK** | Unchanged; first session is assessment-against-the-beta, not a build. | SDK availability |

## 4a. Tier D — the agentic-loop wave, W-19 *(added 2026-08-30)*

One wave, one plan document: `Agentic-Loop-Development-Plan.md` collects the app-side work that
turns the agentic loop `Docs/Agentic-Analysis-Guide.md` documents — curate in the app, compute
over the curation, adjudicate in the app — from folklore into affordances. Nine rows, L-0..L-8,
each anchored to the code it extends; no CloudKit schema change anywhere in the wave; the plan
argues its own sequencing so this table stays a pointer, not a copy.

| # | Session | Size | Gate |
|---|---|---|---|
| L-0 | Guide correction — Appendix A.7 stale since build 44 (the app now embeds queries) | XS | none |
| L-1 | `.fruscollection` write-minimum: spec + conformance fixture (the inbound keystone) | S | none |
| L-2 | Export Research Database… (backup + integrity + default-off include-my-notes) | S | none |
| L-3 | Mirror tag names into `user_tags` beside the existing id sync | S | none |
| L-4 | Surface the shipped embedder (reveal model path; publish `queryPrefix`, undigested) | S | none |
| L-5 | `frusexplorer://` document deep links (touches `project.yml` — xcodegen ritual) | M | none |
| L-6 | Corpus-wide shard fetch as an explicit named-cost button (#926's refusal upheld) | S | none |
| L-7 | Copy research-state record (build, index versions, volume list, digests) | XS | none |
| L-8 | Local read-only MCP server — ASSESSMENT, build/no-build | M | L-1..L-4 |

Tier D sits below Tier A and its standing gates, and its rows interleave with Tier B the way
B-rows interleave with each other; L-0 may ship any time as a published-document correctness fix.

## 5. The owner lane

| Item | Feeds |
|---|---|
| **Build 44**: the VoiceOver pass and the App Store Connect archive-and-upload (tag `build-44` is set; What-to-Test texts are paste-ready and under the 4,000-character limit) | release |
| **The M2a span sitting** (N-0) — the one thing on #234's critical path | Tier A |
| **The custom EULA paste** before any App Store (not TestFlight) submission of build 44+: fill four placeholders in `semantic-vectors/App-Store-Custom-EULA.md`, paste into App Information ▸ License Agreement | App Store review |
| Screenshot captures — #1081's 13 live placeholders, via the staged four-sitting shot list (`Docs/screenshots/SHOT-LIST-2026-08.md`, W-2e). *Refined 2026-08-29, §7:* the list already covers the visit-plan packet (shot A10, the two claim lists); what build 44 staled is **Meaning search, which has no shot at all** — add its shots to the sweep (the mode strip, the beyond-library row, the model offer) or log the gap on #1081 before capturing | #1081 |
| Release habits: `check_repository_links.py --stamp` each release; eyeball the 3 owner-asserted URLs (JFK ×2, LBJ) | each release |
| Gemma recurring check (runbook §6): at each release carrying the encoder, re-read the PUP's last-modified date and re-run the Apache-relicensing escape-hatch check | compliance |
| **Optional CSUserQuery re-run with Apple Intelligence verified ON** *(recovered 2026-08-29, §7)* — the caveat the W-9 step-1 verdict itself records: the eval machine's setting was unconfirmed, and one re-run with it ON would harden the eight-zero-queries finding. Only if the owner wants the record hardened; the verdict stands either way | closes the step-1 record |

## 6. Standing records

Open issues: **#234** (Tier A), **#1081** (owner screenshots) — verified 2026-08-29 as the
only two open. Everything else the 2026-08-23 plan scheduled is shipped and struck in that
document, which carries the per-row evidence — except two residues its struck rows still
name, now carried here rather than lost (B-5; the owner-lane CSUserQuery re-run).
The Gemma compliance state lives in `semantic-vectors/Gemma-Compliance-Runbook.md` (all
in-app/in-repo conditions DONE; §5 ASC EULA owner-only). The V-5 program's measurement
record lives in `semantic-vectors/` (the judged sitting, the four-route comparison, the
encoder acceptance fixture) and is the baseline any future retrieval work argues against.

## 7. Review — 2026-08-29, the day after

A claim-by-claim verification of this document against the tree, the tags, the tester
notes, and the issue tracker, run one day after it was written. The method was the one
this repo's measurement records use: no claim taken from memory or from a neighboring
document when a primary source could answer — the string in the source file, the tag on
the remote, the character count of the file itself. **The plan held up: of some twenty
distinct checks, two claims needed correction, two residues had leaked, and one row needed
sharpening; everything else verified true.** The corrections, the recoveries, and the
sharpening are all edited in place above, each marked *(…2026-08-29, §7)*.

### What was verified and held

- **The supersession accounting.** `Completed/Plan-Of-Record-2026-08-23.md` exists; its
  Tier A and Tier B rows are all struck (W-1, W-1b, W-18, W-2, W-3, W-6; W-4+W-5 one PR);
  Tier C is closed except W-7/W-7a, which are this plan's N-0…N-3; W-8 is struck with the
  residue B-5 now carries; Tier D's W-9 row records steps 1–4 all decided/shipped plus the
  hybrid page — "FAR past its written scope" is fair; Tier E shipped W-11 (struck, one
  session), W-16 (delete arm), W-17 (three sessions + the judged sitting), leaving exactly
  the four this plan carries: W-13→B-1, W-14→B-2, W-12→C-1, W-15→C-2. W-18 is rightly
  absent here — delivered 2026-08-26 as the Archive Visits Phase 1 pointed-at channel, per
  the old plan's own struck row.
- **The tag.** `build-44` exists on the remote at `c47a9d48` (the #1130 merge), annotated.
- **The Meaning verdict ask.** Verbatim in both build-44 notes: "Do the top matches
  deserve opening? **This is the verdict we most need.**"
- **The map's pre-decided consequence.** `Completed/Browse-Axes-Development-Plan.md` line
  167: "If the eventual verdict demotes the map, removing the tile remains one clean
  commit."
- **Tier A's tooling facts.** `harvest_ner.py` contains neither `ONLY_DOCUMENTS` nor
  `WORKERS` (the W-7a additions remain unbuilt); its `FULL_SWEEP=1` route writes
  `"sampled": false` with `sampled_doc_ids: null` — "for a full volume the answer is 'all
  of them'" — so the weekend store is indeed scoreable over any gold documents inside the
  volumes it covers. `stage_m2a.py` is SEED-pinned (default 234) with DOCS default 72.
  The M1a identity CSV is 300 rows, 0 keyed (`early-era-people/m1a-eval-candidates.csv`).
- **Tier B's premises.** `ExportHistoryEntry` is in the CloudKit inventory and
  `ProjectEngagedDocuments` exists (B-1's "no schema change" is plausible on those two);
  B-3's four items are exactly `Map-Figure-Export-And-Visual-Outputs.md` §7.1–7.4 (the
  "drift harness" is §7.4's `WordCloudDriftField`/`WordCloudDriftCanvas` animation);
  B-4's memory figures are verbatim from the record — 141→349→393→140 MB is the s2
  CPU-shape acceptance, 639–861 MB is the step-4 spike's Metal CLI run, and the 25-query
  file has exactly 25 queries.
- **Tier C's rows** match the old plan's W-12/W-15/W-10 scope statements word for word
  where they claim to be unchanged.
- **The owner lane.** #1131's own record: "the owner's VoiceOver pass and the App Store
  Connect archive-and-upload remain owner-only." The What-to-Test files measure 3,940
  (iOS) and 3,986 (Mac) characters — both under 4,000, the Mac one by fourteen.
  `App-Store-Custom-EULA.md` carries exactly four bracketed placeholders (mailing
  address, telephone, support email, state/country). The shot list's own §"After the
  sweep" names the 13 `[SCREENSHOT: …]` placeholders. `Scripts/check_repository_links.py`
  supports `--stamp`, and the three owner-asserted URLs are `jfklibrary.org` ×2 +
  `discoverlbj.org` — JFK ×2, LBJ, as written. Gemma runbook §6 is the recurring
  obligation exactly as the row states (PUP last-modified re-read, §0 escape hatch folded
  into the same ritual).
- **Standing records.** The tracker holds exactly two open issues, #234 and #1081.

### What was corrected (edited in place above)

1. **Gate 1 misattributed the second verdict.** It said the What-to-Test notes put both
   verdicts to testers; build 44's notes ask only the Meaning question. The
   clusters/leads-or-noise ask ("Coherent research leads, or arbitrary piles? This is the
   leads-or-noise verdict we most need") was build **43**'s notes — the build-44 rewrite,
   which baselines against 43, dropped it. The verdict is still outstanding but nobody is
   currently being asked; the gate now says so and names the follow-up (restore the ask in
   the next build's notes if the 43 cohort stays silent).
2. **N-1 cited the wrong document for the comparison question.**
   `People-Early-Era-Program.md` §5 is "Constraints carried forward" — its binding gate is
   *eval set first / nothing ships until M2a is keyed*. The "does the model beat the free
   option" question is the scorer's design brief (`NER-RUNBOOK.md` §6–7, and the
   `stage_m2a.py` header). The row now cites both, each for what it actually says.

### What had leaked (recovered above)

3. **The two June W-8 leftovers** — enclosure dual-home rendering and the live UI
   walkthrough of the pre-1910 classifier surfaces — were recorded inside the old plan's
   *struck* W-8 row ("Left of this row: only…") and appeared nowhere in this plan. No open
   issue tracks them. Now Tier B row B-5.
4. **The optional CSUserQuery re-run** with Apple Intelligence verified ON — a caveat the
   W-9 step-1 verdict itself records as the one thing that would harden it — was in the
   old plan's "what remains is owner-lane" clause and was not carried. Now an owner-lane
   row, marked optional.

One row was sharpened rather than corrected: the screenshots line said build 44's
"Meaning/visit-plan surfaces" further staled #1081, but the staged shot list already
covers the visit-plan packet (shot A10, the two claim lists); the genuinely uncovered
surface is Meaning search — zero mentions in the shot list. The row now says which.

### What the review deliberately did not change

The tier order and every gate. In particular it did not second-guess the two standing
gates: the Studio harvest stays untouched and undated (nothing here assumes its
completion), and no row was promoted on the strength of this review — a verification is
not a verdict. The Tier C assessments stay assessments. The owner-lane items stay
owner-only. And the review adds no new work beyond the two recovered residues, which were
already commitments — recorded once, in rows that were struck around them.
