# Agentic harness runbook

The operational facts that decide whether a multi-agent run finishes. They were learned the
expensive way across the 2026-09 commercial-diplomacy run (~207 sessions) and the C-0/C-0b
falsifier runs, and until #1207 they lived only in throw-away workflow scripts and an assistant
memory note outside the tree.

`Docs/Agentic-Analysis-Guide.md` deliberately keeps only the method-level rules (§3, §14.12 items
5–7) and points at "your harness". This is the harness.

**How to read the confidence of each fact.** Two kinds appear here and they are marked:

- **[VERIFIED]** — re-run on this machine while writing this file, or measured directly by a run
  recorded in `Planning/`. The command is printed and its output is quoted.
- **[FROM THE RUN]** — measured once during the 2026-09 run and not reproducible now, because the
  sessions are gone. Cited to where the figure lives. Treat as an order of magnitude, not a
  constant.

---

## 1. Prove the environment with one cheap agent, before any fleet

Guide §14.12 item 7 states the rule. This is the invocation.

Spend one agent on the **exact command your prompts print**, against a known answer, and read its
output yourself. A fleet that all fails identically at its first tool call costs the same as the
fleet that works.

**Run every invocation you are about to print into a prompt, yourself, first.** The `-uri` history
in §5 is what happens when nobody does.

**[VERIFIED]** The read-only proof, non-destructive, on Apple's sqlite3 3.51.0:

```
sqlite3 "file:/path/to.db?mode=ro" "BEGIN; CREATE TABLE zz(x); ROLLBACK;"
  -> Error: stepping, attempt to write a readonly database (8)
```

A failure there is the proof. **`BEGIN IMMEDIATE; ROLLBACK;` alone proves nothing** — on a
read-only handle it exits 0 and prints nothing, because it never attempts a write.

## 1a. Four things that are not on this machine, or not what you think

**[VERIFIED, 53 agents over two rounds, 2026-09-06.]** Each of these cost real work, and the first
cost it *silently*.

- **`timeout` DOES NOT EXIST on macOS.** Three round-1 agents wrote `timeout 170 python3 …`; one
  **lost four batches with no error at all** — the loop failed, the file count did not advance,
  nothing printed. There is no `gtimeout` either unless coreutils is installed and you have checked.
  Chunk and flush instead; do not reach for a timeout.
- **There is a ~120-second FOREGROUND tool limit, separate from the 180-second silence watchdog.**
  A call can be killed for taking too long *while printing*. It fired twice in round 2, both times
  on the 3.45 GB database. Put anything longer in the background and poll a file.
- **zsh does not word-split an unquoted `$VAR`** — only `$(cmd)`. An agent passed 550 volume ids as
  ONE argument, scanned zero volumes and printed `TOTAL 0`, twice. **It was caught only because a
  three-volume control contradicted the 550-volume absence.** Pass a file of ids, or an array.
- **`tee` buffers, and `tee | head` SIGPIPEs the writer.** A background job's harness output file
  read empty for ~60 s while the tee'd target already held rows — polling the wrong file reads as a
  failed job. Poll the redirect target. And `| head` truncates the file mid-write.

Python here is **3.9**: no backslash inside an f-string expression, and `csv` needs
`csv.field_size_limit(10**9)` for this corpus's longest table-of-contents heads.

## 1b. Do not ask an agent for a guarantee it cannot give

**[VERIFIED, C-0c, 2026-09-06.]** The runner prompt in that experiment asked, in both arms, for
`queries.log` holding *"EVERY command you ran that touched a surface, one per line, verbatim, in
order."* **All four block-arm agents restated that sentence as their log header — and all four then
elided command bodies**, because a hundred-character `python3 -c` body does not fit one line. The
rubric item scoring the guide's don't-overclaim rule came back **0 of 4**, in both arms.

The instruction created the false claim it was then scored against. Two consequences:

- **Ask for the exception, not the guarantee.** Require an `ELIDED:` line naming what was
  shortened, not an assurance that nothing was. The first is checkable and survives a long command;
  the second is a sentence anyone can type.
- **A measurement that scores an agent for a claim the harness demanded is scoring the harness.**
  When an item fails in *every* cell of *both* arms, suspect the prompt before the guidance.

## 2. The per-call watchdog: 180 seconds of silence and the call is killed


**[FROM THE RUN]** A tool call that produces no output for 180 s is killed, and everything not yet
on disk is lost. A single call that scans all 552 TEI volumes, or reads all of `body_text`, dies
every time.

Three things make a long scan survive:

- **Chunk it.** One call per volume, or per shard, not one call per corpus.
- **Checkpoint to the agent's own scratch directory as you go**, so a kill costs one chunk.
- **Flush.** `python3 -u`, or an explicit `flush()`. A buffered writer that has produced no output
  for three minutes is indistinguishable from a hang, and is killed as one.

`run_in_background` plus polling is the alternative when the work genuinely cannot be chunked.

## 3. Resume rather than relaunch

**[VERIFIED, this session]** `Workflow({scriptPath, resumeFromRunId})` replays every completed
agent from cache, keyed on **`(prompt, opts)` — byte-identical**.

The trap follows from the key: **a correction appended to every prompt re-runs every finished
agent.** Append it only to the agents still to run — a per-key conditional that returns `''` for
the ones that already finished. Done right, 25+ agents of deep work survive an edit to the script.

`scriptPath` must be a path the tool returned, or one the session can read; copy an edited script
into the session scratchpad if the tool refuses it.

**Give single-point agents a retry wrapper.** A synthesis step that returns `null` throws, and the
throw discards the whole run.

## 4. The model-pin hang, and how to diagnose it

**[FROM THE RUN]** When one model's quota ran out mid-run, adding `model: 'opus'` to the remaining
`agent()` calls made **every one of them hang on its first request** until the watchdog killed it:
six attempts, four hours, zero output. The session was *already* on Opus 5. **Removing the pin and
letting agents inherit the session model fixed it in seconds** — bare prompt to 20+ records.

**Diagnose from the transcripts, not the prompts.** Read
`subagents/workflows/<run>/agent-*.jsonl`: an agent with ~5 records and **no `tool_use`** never got
a model response at all. That is a transport problem, and no amount of prompt rewriting fixes it.

The general form of the error is worth more than the instance: each of these failure modes presents
as *"the agents failed"*, which invites rewriting prompts that were fine.

## 5. The `-uri` history, attributed correctly

This one is in the runbook partly as a correction, because a wrong account of it survived into an
assistant memory note and had to be caught by review.

**[VERIFIED]** There is no `-uri` option: `sqlite3: Error: unknown option: -uri`. Both of these open
read-only on Apple's sqlite3 3.51.0 — the URI form takes the URI **as the database name, with no
flag**:

```
sqlite3 "file:/path/to.db?mode=ro" "SELECT ..."
sqlite3 -readonly /path/to.db      "SELECT ..."
```

**[VERIFIED] The guide never printed the flag.** `Docs/Agentic-Analysis-Guide.md` contains `-uri`
three times and all three are warnings against it (§2 and the v1.11 version history). The flag came
from the **C-0 falsifier's runner prompt** — `Planning/c0-falsifier/workflow.mjs`, 8 occurrences —
and was copied from there into the 2026-09 run's round-1 RESOURCES text.

The first record of this in an assistant memory said "the guide's §2 recipe fails as written". That
was wrong; the 2026-09-04 review's checkers caught it. The guide's real gap was that it printed **no
shell form at all**, which is what invited the invention — and that gap is now closed.

**It was still live on 2026-09-06.** `Planning/c0-falsifier/workflow.mjs` and
`Planning/c2-long-session/workflow.mjs` both still carry the flag, so every C-0 and C-2 run spent
its first query on a broken command. Both arms carried it equally, so those comparisons stand — but
`Planning/c0b-falsifier/workflow.mjs` is the corrected template to copy from.

## 6. Quota and burst limits

**[FROM THE RUN]** 45 of round 1's 141 sessions died without output — session quota twice, HTTP 429
bursts once. Two things made the loss recoverable rather than fatal:

- a **retry wrapper** around single-point agents (see §3 — one `null` throws the run);
- **per-agent logs written as the agent goes**, so a killed agent leaves evidence rather than
  nothing.

Guide §14.12 item 5 states the method-level version: *expect agents to die, and make the loss
cheap*. Item 6 adds the discipline for what a dead agent left behind — its draft is a claim, not a
result.

## 7. Cost expectations

Recorded so the next run can cite a figure rather than guess. No file inside the 2026-09 run
carries one; neither does C-0's or C-2's.

| Run | Agents / sessions | Tokens | Wall clock | Notes |
|---|---|---|---|---|
| Commercial diplomacy, 3 rounds **[FROM THE RUN]** | ~207 sessions | 2.94 B | — | 95.9% cache reads; ≈$2,800 at first-party rates. **Half of all output tokens were adversarial refuters.** |
| C-0b falsifier **[VERIFIED]** | 16 agents (8 passes + 8 blind scorers) | 3.17 M | 35.2 min | 701 tool calls, 0 errors. `Planning/C0b-Falsifier-2026-09-06.md` |
| Chief-of-mission field run **[VERIFIED]** | 53 agents over 2 rounds (17 readers, 34 refuters, 2 synthesis) | 12.81 M | 4 h 02 m | 3,549 tool calls, **0 errored** (round 2 also 0 empty). 630 documents read whole (14 in round 1, 616 in round 2). `~/frus-analysis/chief-of-mission/logs/measurement*.md` |

The refuter share is the number to plan around: an adversarial pass is not a rounding error on the
budget, it is half of it.

## 8. Authoring the script

**[VERIFIED, C-0b]** Two practices that paid for themselves:

- **Generate the script; do not hand-transcribe a payload into it.** C-0b's runner prompts embed a
  143-line block extracted from the guide. Transcribing it four times by hand is four chances to
  introduce a difference between arms that the experiment would then measure. A small generator
  script that reads the source and emits the workflow removes that class of error entirely.
- **Verify the arms before launching, not after.** C-0b's assignment was checked by parsing the
  generated script back: which cells carry the block, prompt lengths, which question each got, that
  no prompt still printed the broken invocation, and that the new logging requirement appeared in
  **both** arms — a requirement present in only one arm is a treatment, not an instrument. That
  check cost one command; a mis-assigned arm costs the whole run.

## 9. Sources

- `Planning/C0b-Falsifier-2026-09-06.md` — the run whose figures are marked [VERIFIED] here.
- `Planning/c0b-falsifier/workflow.mjs` — the corrected harness template.
- `Planning/Agentic-Guide-Revisions-2026-09-04.md` — M1-operations, check-M1, Part 2 R-6; the
  opening correction is where the `-uri` misattribution was caught.
- `Docs/Agentic-Analysis-Guide.md` §3 and §14.12 items 5–7 — the method-level rules this file is
  the harness half of.
- `Planning/Agentic-Loop-Development-Plan.md` — the programme this sits under.
