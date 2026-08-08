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

**This makes the core problem reconciliation, not detection.** And 93.3% of the names sit in
`from`/`to` correspondence headers, which is a far better-constrained matching problem than open
prose: a despatch's sender and recipient, plus the document's date, plus POCOM's record of who held
which post when, is a three-way constraint. POCOM is genuinely load-bearing here in a way it is not
for the M0 work that shipped in #736.

> **Do not over-read this.** 253,919 is the count of names the editors *chose to mark up*. What
> fraction of all person mentions in those volumes that represents is **unmeasured**. Detection may
> still be needed for people named only in running prose. Measuring that coverage is the first task
> below, precisely because the program's size depends on the answer.

---

## 4. The program

Phase names kept from the archived plan so the issue history still reads.

### M0 — shipped
POCOM career data + authority schema v2 + the #260 crosswalk expansion — [#736](https://github.com/joshbotts/FRUS-Explorer/issues/736) / PR #737. Enriches the covered corpus. Adds nobody to the 268.

### M1a — measure before building *(new, and the gate on everything else)*
1. **Marked-up coverage.** In a sample of no-list volumes, what share of person mentions in the
   document text carry `<persName>`? This decides whether M2 needs detection at all.
2. **Ground-truth eval set.** The archived plan's non-negotiable, and still right: it does not
   exist, and nothing downstream is measurable without it. Hand-key a stratified sample of
   volumes across the 1860s–1940s.
3. **POCOM constraint strength.** For `from`/`to` names in a dated despatch, how often does POCOM
   name exactly one plausible officeholder? Measured on the eval set, this is the precision ceiling
   for the cheap path.

### M1b — reconcile the marked-up names
Cluster the 253,919 `persName` strings into identities, anchored on POCOM where the from/to +
date constraint resolves, and on the existing `person_rollup` where a name already exists there.
Emit derived entries in a **synthetic-ref namespace** distinct from editor `xml:id`s (rules
documented in the archived plan), force-merge only, never auto-splitting a reconciled identity.

### M2 — detection, only for what M1a shows is missing
NER over running prose in the early-era volumes, with adversarial review. Scope depends entirely
on M1a's first measurement; it may be much smaller than the archived plan assumed, or unnecessary.

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
