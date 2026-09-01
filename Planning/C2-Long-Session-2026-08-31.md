# C-2: does the pasted house-rules block survive a long session?

**Status:** RUN AND JUDGED, 2026-08-31. Row C-2 of `Agentic-Loop-Development-Plan.md`, the gate C-0
placed in front of row C-1 (the read-only CLI).

**The verdict: the block does not decay. CLOSE C-1 as NOT NEEDED.** That is the pre-registered
reading of this result, written before the run and honoured now. Evidence is committed beside this
document at `Planning/c2-long-session/`.

---

## 1. The one thing C-0 could not see

C-0 measured whether the §12 house-rules block *works*. Every one of its eight runs was a short
session in fresh context — 41–85 tool calls — so it could say nothing about whether the rules
*survive*. That mattered, because surviving is the only advantage a re-presented tool catalogue is
claimed to have over a pasted block: *"a 110-line pasted block can be forgotten or truncated."*

C-2 runs the same terminal task at the end of a much longer session.

| | |
|---|---|
| **Terminal task** | **Byte-identical to C-0's** — same two questions, same deliverable wording, same 30–60 tool-call budget. The only difference between a C-2 memo and a C-0 memo is how much work sits between the rules and the task. |
| **What sits in front of it** | Three substantial, deliberately **non-archival** tasks: a chronological coverage profile, a person-coverage profile, and a description of the publication's structure. |
| **Withholding** | The terminal task is **not in the opening prompt**. It sits in `task4.md`, which runners are told not to open until tasks 1–3 are done, so it enters context as a tool result deep in the session rather than adjacent to the rules. Without this an agent could plan its archival work at turn 1 with the rules fresh — the condition C-0 already measured. |
| **Arms** | Both again: block pasted, and no rules. A drop in the block arm would otherwise be unattributable between "the rules decayed" and "everything gets worse in a long session". |
| **Runs** | 2 questions × 2 arms × 2 = 8, scored blind by 8 scorers against **C-0's 24 items verbatim plus one addition, A6**. |

**The manipulation worked, and this was checked before any verdict was read.** Long runs used a mean
of **123 tool calls against C-0's 59** (2.1×), with transcripts averaging 767 KB against 454 KB.
Every long run exceeded every short run: the ranges do not overlap (101–146 against 41–85).

---

## 2. The result

| | obeyed / applicable | |
|---|---|---|
| SHORT + block | 96/97 | **99%** |
| **LONG + block** | **99/100** | **99%** |
| SHORT + control | 81/96 | 84% |
| **LONG + control** | **75/100** | **75%** |

**Not one item decayed in the block arm.** Item by item across all 25, the long-session block arm
matches or equals the short-session block arm everywhere. Its single violation is `R1` — a memo that
did not show its SQL — which is the same item, on the same question, as C-0's single violation.

**The control arm did decay: 84% → 75%.** So long sessions do degrade unruled work, and that is
precisely what makes the block-arm result meaningful rather than a null: the degradation was
available to happen and the block prevented it entirely. The control's losses are concentrated in
`C2` (4/4 → 1/4, stating the library conditionality), `I3` (4/4 → 2/4, joining on the document pair)
and `S5` (2/4 → 0/4, the Ed2 fold).

### The sharpest measurement in the program

Counting distinct 7–8 digit catalogue identifiers in each memo, across **both** experiments and
**both** session lengths — an instrument with a positive control (it recovers the NAIDs a scorer
independently verified against `central-files-index.json`) and a negative control:

| | run 1 | run 2 | run 3 | run 4 |
|---|---|---|---|---|
| BLOCK, short | 4 | 3 | 8 | 9 |
| BLOCK, long | 6 | 3 | 5 | 5 |
| CONTROL, short | 0 | 0 | 0 | 0 |
| CONTROL, long | 0 | 0 | 0 | 0 |

**8 of 8 versus 0 of 8.** Every run that had the rules resolved an archival unit to a catalogue
identifier; no run without them ever did, at either length. This is pre-registered item **A6** — the
strict form C-0 had to recover post-hoc — and it is 4/4 against 0/4 in C-2 as an item, matching the
grep exactly.

---

## 3. Verification, and two false alarms that were mine

The same mechanical pass that caught scorer leniency in C-0 was run again. This time it produced
**two false alarms, both defects in my own instrument rather than in the scoring**:

- **b2 / A6** looked like a scorer error — my pattern found zero NAIDs. The memo resolves five, in a
  table whose column heading is `NAID`, which a pattern anchored on the word `NAID` immediately
  before digits cannot see. The scorer had additionally verified all five against
  `central-files-index.json` and their image counts against `roll-scans-index.json`.
- **b7 / S2** looked like another — my pattern searched for `counting surface`; the memo writes
  `counting-surface`, hyphenated, in a sentence that states the surface *and* its limit ("I did not
  open the TEI, so nothing here is a counting-surface or spelling-variant measurement over raw
  text").

Recorded because the lesson generalises and cuts against the previous document: **a grep is a screen,
not an oracle, and it needs its own controls before it is used to overturn a judgement.** In C-0 the
mechanical pass corrected the scorers; here the scorers corrected the mechanical pass. Neither
direction is the reliable one. The corrected pattern above therefore carries both a positive and a
negative control, which is §14.2's rule applied to the instrument rather than to the corpus.

**No verdict was overturned in C-2.** **Contamination check clean** — no run reached the forbidden
repository tree.

**Compliance did not come at the cost of the work.** Block-arm memos average 24.8 KB in the long
session against 29.9 KB in the short; control-arm memos 20.5 KB against 21.9 KB. Both arms wrote
somewhat less after 123 tool calls, and the block arm still wrote more than the control arm did at
either length.

---

## 4. The limit, stated plainly, and why it does not reopen C-1

**No session compacted. Zero of eight.** At 767 KB of transcript the block stayed in context
throughout, so C-2 tested the *forgotten* half of the mechanism and never exercised the *truncated*
half. A session long enough to force a context reset could still lose the block where a tool
catalogue would survive, and this experiment does not speak to that.

Three reasons that does not keep C-1 alive:

1. **The pre-registration said what to do.** "Compliance holds → close C-1 as NOT NEEDED." Inventing a
   new gate after seeing a result one could keep chasing is exactly the move this program's own
   method forbids. The limit is recorded; it is not converted into a fresh condition.
2. **The untested branch has a cheaper answer than a binary.** If a block is lost to compaction, the
   fix is to paste it again — or to let the artifact carry it, which the export already does: the
   views enforce four rules structurally regardless of what the model remembers, and
   `research_provenance.documentation` names the guide from inside the file.
3. **The measured direction is the wrong one for the tool.** Compliance did not sag at 2.1× length by
   *any* amount — not one item, in either question, in either run. A mechanism that shows zero effect
   across a doubling is not a mechanism one should expect to appear suddenly at 3×.

Other limits, recorded: n = 2 per cell; partial blinding, since a memo may mention its rules; one
scorer per memo; and `E3` is `not_applicable` in all eight C-2 runs (none used cross-references), so
the denominators are 100 and 97 rather than a common number.

---

## 5. What this closes

**C-1 is CLOSED, NOT NEEDED.** With C-0 and C-2 together the full factorial is complete:

| | block | no rules |
|---|---|---|
| **short session** | 99% | 84% |
| **long session** | 99% | 75% |

The §12 block is sufficient, it is protective, and it does not decay. The residue shipped in PR
#1151 covers the rest: the artifact paths that fixed the *discovery* half of §14.11's archival zero,
and the export views that make four rules structural for anyone who never pastes anything.

The W-19 agentic-loop wave is complete, and it ends with a build refused twice on measurement rather
than on preference — once for MCP at L-8, once for the CLI here.

---

## 6. Reproducing this

`Planning/c2-long-session/` holds the frozen rubric, all eight memos, the three preamble
deliverables per run, the per-item verdicts with scorer evidence, the withheld `task4.md` files, the
exact 110-line block, the arm keymap the scorers never saw, and the workflow with both arms' prompts
as sent. C-0's comparator is at `Planning/c0-falsifier/`.
