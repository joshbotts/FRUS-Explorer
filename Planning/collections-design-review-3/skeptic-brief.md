# Brief for every skeptic (read this whole file first)

You are a SKEPTIC in the third adversarial review of a design proposal for the FRUS Explorer app (SwiftUI; iPhone, iPad, Mac). The repository is checked out at `/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/l25-collection-templates-8f58f6` (REPO), on branch `claude/cr-collections-review-3`.

**Strictly read-only.** Do not edit, create, delete, commit, push or publish anything in REPO or anywhere else, and do not start other agents. **Run no build, test, archive, simulator or app** (`xcodebuild`, `swift build`, `swift test`, `swift run`, `Scripts/heavy.sh`): another session is running landing runs on this Mac. You may:

- read REPO, with `git show`, `git log` and `git grep`;
- read the public TEI at `/Users/jbotts/Development/frus/volumes/` (corpus `216cdb764`) with stdlib Python run with `python3 -I`;
- write scripts and notes under `SCRATCH/work-<YOUR LETTER>/`, and your report at `SCRATCH/skeptic-<YOUR LETTER>.md`, where SCRATCH is `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-l25-collection-templates-8f58f6/f6d777ba-c969-4f0e-bff4-c72a64a567ce/scratchpad/review3`.

## What happened before you

Six reviewers attacked the third form of the design record `REPO/Planning/Collections-Customization-Design-2026-11-25.md`, as brought to the owner's answers. Those answers are decisions 153 to 174 of `REPO/Planning/Plan-Of-Record-2026-11-25.md`, §0. They also attacked that plan's §1c, which takes the design's lanes as rows L34 to L55. Their brief is `REPO/Planning/collections-design-review-3/reviewer-brief.md`. Read its scopes, its severity scale and its "Do not raise" list. Their reports are in SCRATCH:

- `INT.md`: interaction;
- `ENG.md`: engineering;
- `DATA.md`: stored data and CloudKit;
- `FMT.md`: the collection file and the other carriers;
- `EDI.md`: editorial integrity;
- `A11Y.md`: accessibility.

The boards they cite are under `SCRATCH/canvas/project/`; the reviewer brief says which parts of them the owner's answers superseded. Index version 76, which is built and not merged, is read with `git -C REPO show claude/plan-of-record-pr2011-2cc493:<path>`. The review's first finding, on A2 and the index, is `REPO/Planning/collections-design-review-3/a2-what-the-index-owes.md`.

## Your job

Try to REFUTE each finding assigned to you. You owe the reviewers nothing. A finding that survives you is one the owner will act on, so a wrong one that survives costs real work. A right one you wave through unexamined is worth nothing either.

For each assigned finding:
1. **Re-read every line it cites,** in REPO, in version 76's branch, in the design, in the plan, in a board or in the TEI. Does the line say what the finding says it says? Quote what it actually says where they differ.
2. **Look for counter-evidence:** the evidence its own "Refutation" line names, and any other. Sources are the code, the tests, both manuals and the Agentic Analysis Guide (`Docs/`), `CLAUDE.md` and `.claude/rules/`, the plan of record, the earlier designs (`Planning/Completed/Collections-*.md`) and the two earlier reviews.
3. **Check whether it is already stated.** The design may state the weakness (its §5.6, §7.5, §12, or §13's "Not read" and "Not done"), or a row's brief may name it as that row's to settle. If so, the finding is NOT NEW unless it shows the thing is worse than stated.
4. **Check whether it re-argues an owner's decision as such.** If it does, it is REFUTED as out of bounds, unless it shows a consequence of the decision that neither the design nor the plan states.
5. **Check whether it repeats** a finding of the first or second review that the third form answers.
6. **Check the severity against the brief's scale.** A scenario that needs an unusual chain of steps, or harms nothing a person cannot recover, is not an S1.
7. **Where a finding rests on a count over the TEI,** re-count at least one figure yourself.
8. **Where a finding rests on platform behaviour** (a screen reader, Word, PDFKit, SwiftData or CloudKit) and the reviewer marked it "from memory" or NEEDS A RUN, say whether you could establish it from anything readable here. If you could not, it is PLAUSIBLE at best.
9. **Check its "Where it is answered" line.** Is that the right place: the design's text, a row's brief (is it the right row?), or a question for the owner?

Read all six reports once, so that you can name duplicates across them. Give verdicts only on your own.

## Verdicts

- **CONFIRMED**: the evidence says what the finding says, you found nothing against it, and the severity fits.
- **CONFIRMED, RE-RATED**: true, but the severity is wrong; give the right one and why.
- **PLAUSIBLE**: it depends on something only a run, or a source you could not read, would settle; name the check.
- **REFUTED**: say what refutes it, with the line.
- **NOT NEW**: the design or a row's brief already says it; cite where.
- **DUPLICATE**: of which finding (give the ID); still give the verdict the pair deserves once.

## Your report

Write it to `SCRATCH/skeptic-<YOUR LETTER>.md`: plain text, no preamble. End with a short final message that gives each finding's ID and verdict on one line. If you cannot write the file, put the whole report in your final message instead.

For each assigned finding, in the order of its file:

```
ID:
Verdict:
Severity: (as it should stand)
Why: two to five sentences, each resting on a line you re-read (file:line, design or plan §, board line, TEI count). Quote where the wording matters.
Where it is answered: (agree with the reviewer's line, or give the right one)
Check owed: (only for PLAUSIBLE)
Duplicates: (IDs in any of the six reports, or none)
```

Then:
- **The reviewers' starting-point lines in your files:** for each, say where you disagree, and why. Say nothing where you agree.
- **Errors in the design or the plan found on the way:** anything that is false, or that contradicts another part of either document or an owner's decision, whether or not a finding named it. Give each its section and the line that contradicts it, one line each.
- **Not checked:** what you could not get to.
