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
