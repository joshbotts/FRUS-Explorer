# The sitting's verdict — lexical vs. semantic, one measure, 2026-08-28

**Instrument:** `RetrievalEvalHarness` first run (2026-08-27), 25 owner-written queries,
top 10 per route. **Judge:** the owner, by eye, per the report's rubric (the would-open
test; near-misses score 1; blank = the row's evidence underdetermines it, excluded from
denominators). **Sheet:** `verdicts.csv` beside this file — 435 rows: 173 relevant, 144
not, 118 blank, zero malformed. One cross-route pair had a judged 1 on one side and a
blank on the other (Q16, `frus1969-76v38p2/d139`); the judged value carries over,
disclosed here.

## The headline

| | lexical | semantic |
|---|---|---|
| precision over judged rows (all queries) | **0.40** | **0.65** |
| MRR@10 (rank of first relevant; 0 when none) | 0.418 | **0.771** |
| rows returned (of 250 possible) | 185 | 250 |
| blank rate | 29% | 26% |

But the aggregate is the least informative number here — **the register split is the
finding**, and it is exactly what the query set was stratified to expose:

| register | lexical P | semantic P | verdict |
|---|---|---|---|
| research questions (9) | **0.07** | **0.65** | semantic, by a wipeout |
| search-box keywords (11) | **0.79** | **0.77** | tie — with two decisive exceptions below |
| known-items (3) | 0.10 | 0.39 | semantic (2 of 3 found; 1 missed by both) |
| wrong-premise probe (1) | 0.00 | 0.60 | semantic corrected past the wrong word |
| null control (1) | 0.10 | 0.22 | see below |

## What each route is for

**Natural-language questions destroy the lexical route.** Implicit AND over question
words returned **zero rows for four queries** (Q4, Q11, Q18, Q19) and precision 0.00 on
five more; its only research-question success was Q16, whose phrasing happens to be
keyword-shaped ("Kissinger manage State Department"). The semantic route scored ≥ 0.60
on seven of nine, with first-relevant at rank 1 on five.

**Terms of art destroy the semantic route.** Q23 `"trust but verify"` and Q24
`persona non grata`: lexical **1.00** on both; semantic **0.10** on both — it drifted to
verification-adjacent arms-control paper and to Italian diplomatic correspondence,
because the *phrase itself* is the discriminator and embeddings dissolve it. Every other
keyword query tied at or near 1.00 for both routes.

**Known-items:** the Olney note (Q4) — semantic ranks Cleveland's message 1 and the note
itself 2, with the whole surrounding correspondence filling ranks 3–6; lexical returned
nothing. The Mao memcon (Q17) — semantic rank 2 is the February 1973 memcon itself;
lexical's single row was the April 1972 memcon, judged relevant under the would-open
test. **The blood telegram (Q25) beat both routes**: lexical AND'ed into medical
telegrams, semantic returned Chargé *Trueblood*'s telegrams — a surname collision that
is the sitting's cleanest exhibit of embedding-tokenization hazard. The closest either
route came was lexical's rank 10: a Farland telegram from the Dacca consulate general
(`frus1969-76ve07/d74`) — right post, August 1970, wrong subject, judged blank. A
researcher would still be one browse away rather than arrived.

**The wrong-premise probe worked as designed** (Q15, "U.S.S. Liberty sinking"): semantic
0.60 — it reached the attack documents past the wrong word; lexical 0.00 — it found
sinkings that are not the Liberty.

**The null control half-worked.** The design assumed no honest 1 exists for "Space
aliens"; the judge found three — the Space Council memoranda both routes surfaced are
documents a curious historian would genuinely open for that phrase. The control's real
finding survives anyway: the semantic route's junk arrived wearing confident scores
(0.59 on drift), while the lexical route's junk (aliens-as-foreigners) was transparently
wrong at a glance. The next query set should carry a *harder* null — a phrase with no
topical neighbors at all.

## What this decides

1. **W-9 proceeds, strengthened.** Typed queries through the pinned Gemma space — no
   encoder yet, LM Studio standing in — deliver P 0.65 / MRR 0.77 against the shipped
   funnel. That is the quality bar `CSUserQuery` (step 1) must now beat, the instrument
   PRF (step 3) gets priced against, and direct evidence that a shipped on-device query
   encoder (step 4) would be embedding into a space where typed queries genuinely work.
   The prompt question is settled for that work: the query template, measured here at
   63%/54% divergence from its alternatives.
2. **A shipped search surface should route by register, not pick a winner.** The clean
   split — questions → semantic, terms of art → lexical, topics → either — plus the
   four zero-result lexical queries suggest the cheapest first integration: **fall back
   to (or offer) the semantic route when the lexical expression returns nothing**, which
   in this sitting rescued four of twenty-five queries outright.
3. **The W-17 axis stays experimental at weight 0.** This sitting judged typed-query
   retrieval, not the document-anchored more-like-this axis; the axis's own judgment
   remains with tester feedback / a future anchored instrument. Nothing here demotes it,
   and the terms-of-art result is consistent with its chip design (the terms are the
   evidence).
4. **Recorded gaps:** nickname known-items ("blood telegram") defeat both routes — the
   one query class with a zero across the board; a curated alias layer is the only
   plausible fix and is deliberately not scoped here. Surname collision (Trueblood)
   belongs in any semantic-surface disclosure alongside the existing early-era unknown.

---

# Addendum, 2026-08-28: the third route — CSUserQuery, measured and decided

W-9 step 1 asked the smallest question that decides something: with `textContent`
donated, is Apple's local ranked search good enough here? **Measured: no.** The owner ran
the seam twice on the Mac (07:33 and 09:28 local, 5.5 and 7.5 hours after the 316,895-item
re-donation fully processed — the corespotlightd heartbeat confirmed
request = journaled = processed), macOS 26.6.2, donated schema v2. Both runs are archived
beside this file; run 2 is merged into `report.md` as the third route.

**The decisive facts, stable across both runs:**

- **Eight queries returned zero rows in both runs — six of the nine research questions,
  the Mao question, and the quoted phrase.** This is the lexical failure signature on
  exactly the register where the Gemma route scored 0.65 with rank-1 hits. Zero rows is a
  retrieval failure no generous judging can rescue.
- **All three known-items missed by identity in both runs** ("blood telegram" returned an
  1890s Adee–Pauncefote letter: keyword matching on "blood" + "telegram").
- The route surfaces almost entirely different documents from both prior routes: of 142
  rows, only 13 overlap the judged sitting (run 2: 9 relevant / 4 not — the 4 zeros are
  the null control, where it returned an 1845 constitution for "space aliens"). Where it
  behaved, it behaved as competent keyword search: all 9 judged-relevant rows are
  search-box queries. MRR floor 0.119 (unjudged rows counted as misses — a floor, and
  the zero-row questions bound it regardless).
- **The keyword rankings churned between runs** (two top-10s replaced wholesale, several
  reshuffled) while the zero-row questions stayed identically empty — consistent with
  background index churn that does not touch the structural failure.

**What this decides:** Apple's local semantic search, as reachable through `CSUserQuery`
over donated `textContent` on this OS build, does **not** clear the P 0.65 / MRR 0.77
bar — it does not reach it on any register, and on the research-question register it
fails the same way BM25 does. **V-5's remaining claim therefore does not narrow**: the
Gemma route stays the only demonstrated answer for natural-language queries over this
corpus, and the on-device encoder case (V-5 step 4) strengthens — it now has a measured
three-way comparison behind it. Steps 2–3 of the §6 sequence proceed as planned; the
donation itself stays shipped (system Spotlight findability improved for every user
regardless of this verdict).

**Caveats, stated:** ranking quality here is a property of the OS's models and may change
with OS updates — the JSON stamps the build for exactly that reason. Whether the semantic
ranking layer was fully engaged for third-party `textContent` on this build is not
observable from outside, and **the eval machine's Apple Intelligence setting was not
confirmed** — if the owner finds it was disabled, one further run with it enabled would
be worth the ten minutes before treating this verdict as final. And 129 of the route's
rows are documents the sitting never judged — a supplementary sitting could refine its
precision on the keyword register, but cannot change the zero-row facts that decide the
verdict.
