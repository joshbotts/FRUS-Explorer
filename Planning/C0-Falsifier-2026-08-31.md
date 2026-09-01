# C-0: the falsifier the L-8 assessment put in front of the CLI

**Status:** RUN AND JUDGED, 2026-08-31. Row C-0 of `Agentic-Loop-Development-Plan.md`, which gates
row C-1 (the read-only CLI).

**The verdict: the falsifier substantially FIRES. Do not build the CLI now.** Downgrade C-1 from a
build to a row gated on one further measurement, named in §6. Evidence is committed beside this
document at `Planning/c0-falsifier/` — the frozen rubric, the eight memos, the scored verdicts, the
exact house-rules block used, and the workflow that ran it.

---

## 1. What was measured, and why it needed a control

L-8's assessment set this test: *"Re-run §14's scoping protocol on a fresh question with the §12
block pasted, and count which rules are violated anyway, by block… The rules that survive a paste
need no tool; the rules that do not are the specification for the subcommands."*

That instruction, taken literally, produces an uninterpretable number. `§14.11` recorded the archival
half at **zero** — but against a different guide, on different questions, with no concurrent
baseline. "N of 24 rules obeyed" means nothing without knowing what an agent does *unprompted*.

So the design added the arm the instruction did not ask for:

| | |
|---|---|
| **Questions** | Two, both fresh — neither is one of §14's three written-up runs, whose answers and controls are printed in the guide and could be copied. **Q1** (expected FRUS-rich, variant-heavy): *US disputes over fishing rights and territorial waters.* **Q2** (expected FRUS-thin, archives-rich): *State and international narcotics control before 1970.* |
| **Arm BLOCK** | The §12 house-rules block, 110 lines, guide **v1.10** — i.e. including the SURFACES preamble and `[TEI]`/`[JSON]` tags added the same day. |
| **Arm CONTROL** | Identical question, identical resources, identical deliverable. **No rules.** |
| **Runs** | 2 per cell = 8 scoping passes, each 30–60 tool calls against the live 552-volume index (316,839 documents), the TEI corpus, and the bundled JSON. |
| **Scoring** | One agent per memo, blind to the arm, against a **24-item rubric frozen before launch** and told to ignore any mention a memo makes of rules it was given. |

**Both arms were handed the same resource inventory, including all eighteen archival JSON files by
name and path.** This was deliberate and it is the single most consequential design choice in the
experiment — see §4.

---

## 2. The result

Adjudicated (see §3): **BLOCK 96 of 97 = 99%. CONTROL 81 of 96 = 84%.**

The aggregate is the least interesting number here. The interesting one is *where* the arms differ,
because 17 of the 25 items are at 4/4 in **both**:

| Item | | BLOCK | CONTROL |
|---|---|---|---|
| **E1** | excluded front matter and editorial notes | **4/4** | **1/4** |
| **A2** | established what the footnotes POINT AT | **4/4** | **1/4** |
| **S1** | ran a positive *and* a negative control | **4/4** | **2/4** |
| **S5** | handled the Ed2 second-edition fold | **4/4** | **2/4** |
| S2 | stated the counting surface | 4/4 | 3/4 |
| S4 | periodised on document dates | 4/4 | 3/4 |
| I2 | no rowid as an identifier | 4/4 | 3/4 |
| R1 | showed the SQL | 3/4 | 2/4 |
| *the other 17 items* | | 4/4 | 4/4 |

**And one post-hoc measurement that matters more than any rubric row.** Counting distinct NARA
catalogue identifiers named in each memo:

| | NAIDs resolved |
|---|---|
| BLOCK | a3 **7**, a7 **4**, a2 **2**, a8 **1** — every run, 14 distinct |
| CONTROL | a1 **0**, a5 **0**, a4 **0**, a6 **0** — **not one, in any run** |

This is labelled post-hoc and is not a rubric change: item A5 asked only for "a concrete archival
target", and a lot number copied out of a source note satisfies it. All four control memos named lot
numbers and record groups. **None of them resolved one to a shelf.** That is §14.11's original
finding, reproduced exactly, in a same-day control arm.

---

## 3. Adjudication, stated because the scorers were not reliable

Two `obeyed` verdicts were overturned to `violated` after checking the scorers' own quoted evidence.
Both are corrections of a **misapplied frozen item**, not changes to the item:

- **a1 / S1.** The scorer credited a per-year table comparing `fishing` against `fisheries` as a
  positive-and-negative control pair. Those are two topic terms. §12's rule is a control that
  *proves the scan works* — a term expected everywhere and a term expected nowhere.
- **a1 / S2.** The scorer credited "the FTS index uses a Porter stemmer" plus a reproduction command
  as stating a counting surface. Naming a tokenizer is not naming raw-TEI / tag-stripped /
  word-bounded.

A mechanical grep confirms the pattern the scorers missed. Negative-control language: **4/4 in the
BLOCK arm, 0/4 in the CONTROL arm.** The guide's own counting-surface vocabulary: **4/4 vs 0/4.**
Channel language (`came from` / `points at`): **4/4 vs 0/4.** The scorers had marked S2 and A3 as
obeyed across the control arm largely because a memo that used *one* channel had, trivially, not
summed two.

Two further items are recorded as passing on a weak reading, and are not overturned because the item
as written permits it: a4 and a6 satisfy **S2** by naming the FTS index as the surface they used
rather than by distinguishing the three surfaces; and **A3** is nearly free wherever **A2** failed,
since a memo with one channel cannot mislabel two.

**Contamination check: clean.** No memo or script referenced the forbidden repository tree. The two
files that matched the filter are BLOCK-arm memos citing their own pasted rules — one of which
independently re-derived the **701**-document Ed2 overlap on the index surface, matching the figure
measured for §14.9 the same day from the other direction.

---

## 4. What the result actually says, including against the design

**(a) The block works, and works better than expected.** 99% compliance, in the guide's own
vocabulary, on two questions it was not written for. On the literal terms L-8 set — *the rules that
do not survive a paste are the subcommand specification* — the specification is nearly empty. One
violated item (a memo that did not show its SQL) is not a program.

**(b) Most of §14.11's archival collapse was a DISCOVERY failure, and that half is already fixed.**
Items A1 (came-from) and A4 (opened a bundled artifact) score **4/4 in the arm with no rules at
all**. Simply listing the eighteen artifacts by name and path — which is what both arms got, and
which §14.11 previously did not do for anyone — is what moved that from zero. That paragraph shipped
today in PR #1151. It cost one paragraph and it is worth more than any subcommand.

**(c) But it was not ONLY discovery, and this is what keeps a narrowed C-1 alive.** With the
artifacts named and open in front of them, four capable agents with no rules resolved **zero NAIDs**
and established the pointed-at channel **once in four runs**. Finding the shelf list is a discovery
behaviour. *Naming the shelf* is a rules behaviour, and without the rules it did not happen.

**(d) Two of the four items the block earns are already structural as of PR #1151.** E1 (apparatus)
and S5 (the Ed2 fold) are enforced by `research_documents` and `research_suppressed_volumes` in the
app's export. That leaves **A2 and S1** as the only measured rules a binary would newly carry — and
A2 is precisely the `archival_units` subcommand the L-8 assessment promoted to first.

**(e) The design's own biggest limitation is the one that decides the question it was aimed at.**
Every run was 30–60 tool calls **in fresh context**. The single point the assessment kept on MCP's
side was that a tool catalogue is re-presented every turn where a 110-line pasted block can be
forgotten or truncated. **This experiment cannot see that.** It measures whether the rules work; it
does not measure whether they *survive*. A 99% figure from a short session is not evidence about
turn 80, and it would be dishonest to read it as such.

Other limits, recorded: n = 2 per cell, so this separates "mostly obeyed" from "mostly not" and
supports no claim about a small difference; blinding is partial, since a memo may mention its rules;
one scorer per memo, with the error rate demonstrated above rather than assumed.

---

## 5. Consequences for C-1

**C-1 is downgraded from a build to a gated row.** The case that survives is not the six-subcommand
tool layer the assessment scoped; it is at most two subcommands, one of which has a cheaper
substitute that already shipped.

What C-0 removed from the case:

| L-8's argument | After C-0 |
|---|---|
| The resolution layer is committed but never joined | **Weakened.** An inventory alone gets the artifacts opened, 4/4, with no rules. |
| The archival half is measured at zero | **Split.** The *discovery* half is fixed by a paragraph (shipped). The *resolution* half stands: 0/4 NAIDs without rules. |
| Only 1 of ~40 rules is enforced by a mechanism | **Weakened.** A pasted block reaches 99% unenforced. And 2 of the 4 rules it earns are now enforced by the export's views anyway. |

What is left is one honest sentence: **a tool would make the archival resolution the default for a
reader who does not paste 110 lines of prose.** That is worth something. It is not worth four
sessions on the strength of this measurement.

---

## 6. The gate on C-1, and it is narrow

Build C-1 only if a **long-session** re-run shows the block decaying. That is the only setting in
which the delivery-channel argument can be true, and it is the one setting C-0 did not test.

Concretely: paste the block at turn 1, then run a session long enough that the archival work happens
after substantial unrelated work — a multi-question sitting, or a scoping pass followed by a drafting
pass. Score the same 24 items. If archival compliance holds where it held here, the block is
sufficient and C-1 should be closed as NOT NEEDED. If it decays, the decay is the specification, and
`archival_units` is the first and possibly only subcommand.

Two things to do regardless of that outcome, both cheap:

1. **Sharpen rubric item A5.** "A concrete archival target" let a copied lot number pass. The
   question that discriminates is whether a catalogue identifier was resolved. Any re-run should ask
   for that directly rather than recover it post-hoc as this one did.
2. **Keep the negative control in §12 as a literal.** The block already names
   `ZZZ_IMPOSSIBLE_ZZZ`, and 4/4 BLOCK runs used a control while 0/4 CONTROL runs invented one. It is
   the cheapest high-yield line in the block and worth keeping verbatim.

---

## 7. Reproducing this

Everything is in `Planning/c0-falsifier/`:

| File | |
|---|---|
| `RUBRIC.md` | the 24 items and the pre-registered reading, frozen before launch |
| `house-rules-block-v1.10.txt` | the exact 110 lines pasted into the BLOCK arm |
| `keymap.json` | opaque memo id → (question, arm); the scorers never saw this |
| `memos/a1.md` … `a8.md` | the eight scoping memos, verbatim |
| `verdicts.json` | per-item verdicts with the scorer's evidence; the two adjudicated rows are prefixed `[ADJUDICATED]` |
| `workflow.mjs` | the runner and scorer prompts, both arms, exactly as sent |

The corpus side is not reproducible from a clone — it needs a local library and a copy of the index
— which is why the memos themselves are committed rather than only the numbers.
