# The Early-Era People Program (#234 M1/M2/M3)

**Status:** deferred, unstarted, and *live*. This is not an archived plan.

## Why this document exists

The program was defined inside `Planning/Completed/Issues-233-243-Plan.md` and went into
`Completed/` in the 2026-08-05 Planning cleanup, indexed under **"Closed issue-wave plans."** The
wave closed; the program it deferred did not. The only live pointer left was one sentence in
`Feature-Priorities-Review-2026-08.md`, which bundled it with #259 and #260 — both since resolved.
It became effectively invisible. This file carries it forward, with the measurements that were
missing and one premise corrected.

Everything below is measured against the owner's 552-volume index and the local TEI corpus
(2026-08-07). Where a figure differs from the archived plan, this file is the current one.

---

## 1. The gap, measured

| | |
|---|---|
| indexed volumes | 552 |
| volumes with an editor-published person list | 284 |
| **volumes with none** | **268 (48.6%)** |
| documents in those volumes | **199,246 — 62.9% of the corpus** |
| of those, in pre-1930 volumes | 82,862 |

The document share (62.9%) is much larger than the volume share (48.6%) because the unserved
volumes are the big early annual *Foreign Relations* volumes. **Nearly two-thirds of the corpus is
invisible to the People browser, person search, person analytics, and the co-mention graph.**

By era, the no-list volumes are: every volume from the 1860s (38) and 1880s (25), 42 of 58 from the
1900s, 67 of 72 from the 1920s, and 96 of 191 from the 1940s. Only 21 of the 173 pre-1940 volumes
carry a list.

*(The archived plan says "409 volumes" and "62 pre-1910 volumes". Those were the figures at the
time; 268 and 129-pre-1930 are the current ones.)*

---

## 2. Correction: `persons-new.xml` does **not** reframe M1

The archived plan's 2026-07-09 revision states that
`frus-name-authority/4_Outputs/persons-new.xml` "reframes M1 from *NER from scratch* to *adopt +
human-review the colleague's extraction* — much smaller program, same ground-truth-first
discipline."

**That does not hold for the early-era gap.** Measured:

| | |
|---|---|
| volumes `persons-new.xml` carries anchors for | 111 |
| of the 268 no-list volumes, reached | **2** |
| of the 129 pre-1930 no-list volumes, reached | **2** |

The reason is structural, not a data-quality problem. Its anchors are
`<idno type="frus-ref">volume/persons#ref</idno>` — they point *into a volume's persons page*, so
by construction they can only land in volumes that already have one. `persons-new.xml` enriches the
**covered** corpus; it cannot extend into the uncovered one.

The two apparent exceptions confirm it: `frus1873p1v1` and `frus1873p1v2` have no persons list at
all, so those anchors are synthetic refs the upstream pipeline minted for a page that does not
exist.

**`persons-new.xml` remains a real asset** — 4,542 records, 5,363 anchors, 3,466 model-vetted
`new_person` verdicts (plus 325 `attach_likely`, 291 `review_low`, 231 `review`, 203
`attach_review`) — but it is an *enrichment of volumes that already have lists*, and belongs to a
different piece of work than this one. M1 is not smaller than originally scoped.

---

## 3. The finding that does reshape the program

The early-era volumes are not unmarked text. **The editors already delimit person names in them.**

Across all 268 no-list volumes:

| | |
|---|---|
| `<persName>` elements | **253,919** |
| typed `from` (correspondence sender) | 141,064 |
| typed `to` (recipient) | 95,837 |
| untyped | 17,018 |
| **carrying a link to any identity** | **0** |
| distinct name strings | 13,914 |
| name strings appearing 5+ times | 3,253 |

Compare a covered volume: `frus1915Supp` has 5,392 `persName`, of which **4,033 carry
`corresp="#p_W1"`** pointing back at an editor list entry written as
`<persName xml:id="p_W1">Wilhelmina</persName> Queen of the Netherlands.`

So the difference between a covered and an uncovered volume is **not whether the names are marked
up — it is whether there is a list for them to point at.** The uncovered volumes have the names and
no identities.

93.3% of the names sit in `from`/`to` correspondence headers, which is a far better-constrained
matching problem than open prose: a despatch's sender and recipient, plus the document's date, plus
POCOM's record of who held which post when, is a three-way constraint. POCOM is genuinely
load-bearing here in a way it is not for the M0 work that shipped in #736 — **M1a measured it at
83.2% surname-known and 63.9% resolving to exactly one officeholder serving that year.**

> **⚠️ Corrected by M1a, 2026-08-07.** This section originally concluded "the core problem is
> reconciliation, not detection", flagging that markup coverage was unmeasured. It is now measured
> and it goes the other way: **only ~34% of person mentions in these volumes carry `<persName>`**,
> falling to 12–31% in the 1946– volumes. The editors mark up the correspondence apparatus and
> leave the body prose alone, so **M2 (detection) is not optional**. M1b remains a real, cheap
> deliverable — it buys the correspondence layer — but it does not buy person coverage.
> Full findings: `Planning/early-era-people/M1a-Findings.md`.

---

## 4. The program

Phase names kept from the archived plan so the issue history still reads.

### M0 — shipped
POCOM career data + authority schema v2 + the #260 crosswalk expansion — [#736](https://github.com/joshbotts/FRUS-Explorer/issues/736) / PR #737. Enriches the covered corpus. Adds nobody to the 268.

### M1a — measure before building — **run 2026-08-07**, `early-era-people/M1a-Findings.md`
1. **Marked-up coverage — done.** ~34% pooled; 12–31% in the 1946– volumes. **M2 is required.**
2. **Ground-truth eval set — staged, not done.** 300 stratified candidates in
   `early-era-people/m1a-eval-candidates.csv` with an empty identity column. **Owner work**;
   nothing downstream is measurable until it is keyed.
3. **POCOM constraint strength — done.** 12,384 `from`/`to` names in the sample: 83.2%
   surname-known, 63.9% resolving to exactly one officeholder serving that year. An upper bound on
   precision, since the match is surname-only.

The survey also found two defects: `frus1873p1v1`/`p1v2` carry 57-entry editor lists the parser
never reads (`xml:id="correspondents"`, no `subtype`), and `frus1941-43` contributes 77
back-of-book subject-index headings to the People browser as if they were people.

### M1b — reconcile the marked-up names
Cluster the marked layer's **245,747** `persName` mentions into identities (§3's 253,919 is the 268-volume
app-view census; the harvest runs the 267-volume TEI rule — NER-RUNBOOK §3 reconciles the two), anchored on POCOM where the from/to +
date constraint resolves, and on the existing `person_rollup` where a name already exists there.
Emit derived entries in a **synthetic-ref namespace** distinct from editor `xml:id`s (rules
documented in the archived plan), force-merge only, never auto-splitting a reconciled identity.

### M2 — detection (required — M1a measured ~34% markup coverage)
NER over running prose in the early-era volumes, with adversarial review. M1a settled the scope
question: roughly two-thirds of person mentions carry no markup, so detection is not optional.

**The R-1 harvest has a runbook and a harness: `tools/semantic-harvest/NER-RUNBOOK.md`**
(2026-08-11), driven by `harvest_ner.py`. Its scope pass and its **marked layer** — **245,747** located `<persName>` mentions over the 267-volume
TEI-rule scope (§3's 253,919 is the 268-volume app view) — need no model and are M1b's input. Its detector
layer is deliberately sampled, and the estimates that argued for sampling have since been measured: the
shortlisted Qwen3 14 B runs at 4.68 s/chunk on the Studio, pricing a full sweep at **~18.4 days** (~4.7 with
the probed 4-worker pool), while Qwen3 1.7 B is disqualified on verbatim-copy discipline. The free `NLTagger`
control is **built** (`EarlyEraNERControl`) and measured at **~8 min** over the same scope. The sweep is not a
scoring input: M2a is staged but un-keyed, and scoring needs a targeted pass over the gold documents only
(NER-RUNBOOK §4.7–4.8.2, §7). Nothing it produces may
ship until M2a is keyed.

**Execution plan: ride the semantic-vectors pipeline** — same corpus pass, same pinned-tooling
discipline, same hardware window, and the embedding model doubles as a mention-context
reconciliation signal for identity clustering. The seam (what rides, what must not — gates and
verdicts stay separate), the combined stage list, and the measured generation costs on both of
the owner's machines are in **`Planning/M2-Semantic-Pipeline-Ride-Along.md`** (2026-08-07).
Prerequisite unchanged: the M2a prose ground-truth sample must be keyed before anything ships.

### M3 — provenance UI
Derived people must be visibly derived. The app already has the vocabulary for this — the
"Reconciled identity" seal, and Source Explorer's habit of saying what it does not know. A derived
early-era person must never present with the same confidence as an editor-listed one.

---

## 5. Constraints carried forward (all still binding)

- **Eval set first.** No accept/reject artifact is meaningful without ground truth.
- **Out of interactive scope.** Multi-week offline program; run the LLM-assisted review as scripted
  batch jobs, not interactive sessions.
- **Pilot before corpus.** Measure precision on the pre-1910 volumes before touching the rest.
- **Synthetic-ref namespace, index-version bump batching, force-merge-only rollup rules** — defined
  in `Planning/Completed/Issues-233-243-Plan.md`; that file remains the reference for them.
- **A confidently-wrong person is this app's most serious defect class.** Under-merge bias, as in
  rollup v8. [#259](https://github.com/joshbotts/FRUS-Explorer/issues/259) was closed not-planned
  for proposing merges that would have undone exactly those guardrails — the same standard applies
  to anything this program emits.

## 6. Related, resolved

- [#259](https://github.com/joshbotts/FRUS-Explorer/issues/259) merge suggestions from the dedup
  clusters — **closed not planned** 2026-08-07; of 5,756 clusters only 619 reached two app rollups,
  none of the 207 identifier-backed ones reached the app at all, and 79% attacked a guardrail an
  audit had installed.
- [#260](https://github.com/joshbotts/FRUS-Explorer/issues/260) crosswalk expansion — **shipped** in
  PR #737; coverage 78.5% → 89.3% of person rows.
