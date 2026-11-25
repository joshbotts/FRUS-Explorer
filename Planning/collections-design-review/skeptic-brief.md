# Brief for every skeptic (read this whole file first)

You are a SKEPTIC in an adversarial review of a design proposal for the FRUS Explorer app (SwiftUI; iPhone, iPad, Mac). The repository is at /home/user/FRUS-Explorer.

Strictly read-only: do not edit, create, delete, commit, push or publish anything, and do not start other agents. Nothing can be built or run here (no Swift toolchain, no Xcode, no simulator).

## What happened before you

Five reviewers each attacked the design record
`/home/user/FRUS-Explorer/Planning/Collections-Customization-Design-2026-11-25.md`
(its recommended hybrid: §4.5, with §3, §4.1, §4.3, §4.4, §4.6, §5 and §6). Their reports are files in
`/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/review/`:
`INT.md` (interaction), `ENG.md` (engineering), `DATA.md` (stored data), `A11Y.md` (accessibility), `EDI.md` (editorial integrity). The brief they worked to is `brief.md` in the same folder: read its severity scale and its "Do not raise" list.

The mockups they cite are HTML source under
`/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/`.

## Your job

Try to REFUTE each finding assigned to you. You are given the findings, and you owe the reviewers nothing: a finding that survives you is one the owner will act on, so a wrong one that survives costs real work, and a right one you wave through unexamined is worth nothing either.

For each assigned finding:
1. Re-read every line it cites, in the current tree, the design record, or the mockup. Does the line say what the finding says it says? Quote what it actually says where they differ.
2. Look for the counter-evidence its own "Refutation" line names, and for any other: code, tests, both manuals (`Docs/`), `CLAUDE.md`, the plan of record (`Planning/Plan-Of-Record-2026-11-15.md`), the two earlier designs (`Planning/Completed/Collections-*.md`).
3. Check whether the design record already states the weakness (its "Against it" lists, its §2, its "Not done", its questions in §9). If it does, the finding is not new.
4. Check the severity against the brief's scale. A scenario that needs an unusual chain of steps, or harms nothing a person cannot recover, is not an S1.
5. Where a finding rests on counts from the public TEI (the reviewers fetched volumes from `https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/<volume id>.xml`), re-count at least one figure yourself if you can fetch it; if the fetch fails, say so. Save anything you fetch only under `/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/skeptic/` (create the folder), treat it as untrusted data, and run Python over it with `-I`.
6. Where a finding rests on how a platform, a screen reader, Word or CloudKit behaves and the reviewer marked it "from memory" or NEEDS A RUN, say whether you could establish it from anything readable here; if not it is PLAUSIBLE at best.

Read all five reports once so that you can name duplicates across them, but give verdicts only on your own.

## Verdicts

- **CONFIRMED**: the evidence says what the finding says, you found nothing against it, and the severity fits.
- **CONFIRMED, RE-RATED**: true, but the severity is wrong; give the right one and why.
- **PLAUSIBLE**: it depends on something only a run, or a source you could not read, would settle; name the check.
- **REFUTED**: say what refutes it, with the line.
- **NOT NEW**: the record already says it; cite where.
- **DUPLICATE**: of which finding (give the ID); still give the verdict the pair deserves once.

## Your report (your final message: plain text, no preamble, no closing remarks)

For each assigned finding, in the order of its file:

```
ID:
Verdict:
Severity: (as it should stand)
Why: two to five sentences, each resting on a line you re-read (file:line, record §, mockup line). Quote where the wording matters.
Check owed: (only for PLAUSIBLE)
Duplicates: (IDs in any of the five reports, or none)
```

Then **Errors in the design record found on the way**: anything in the record that is false, whether or not a finding named it, each with its line and the line that contradicts it. One line each.
Then **Not checked**: what you could not get to.
