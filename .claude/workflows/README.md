# Workflow scripts

Three Workflow scripts from build 48's fix wave (2026-09-25 to 2026-09-27). They are generalized
for any later wave: every session path, simulator UDID, base sha and issue list is an argument.
How they fit together, and what each rule in them is for, is
`Planning/Agentic-Harness-Runbook.md` §9, *The serial merge queue*. House rules are in
`CLAUDE.md`, which every workflow agent already has. The prompts point at it rather than restating
it, and carry only what `CLAUDE.md` does not say: the queue's worktree, branch and push rules,
and the durable lessons of build 48's review rounds.

Run one with the Workflow tool, `{scriptPath: ".claude/workflows/<name>.js", args: {…}}`, passing
`args` as a JSON object rather than a string.

## The order: the serial merge queue

1. **`open-issue-review.js`**: triage the open issues and verify every verdict. The owner picks
   the fix list from its report and settles any decision it raises.
2. **`lane-dev.js`**: develop the lanes. They may run in parallel, but no more than three may be
   building at once across every workflow on the machine. Each lane ends committed on its own
   branch, with a PR draft in `<durable>/drafts/<key>.md`. Nothing is merged or pushed.
3. **Fix the landing order** and tell the owner.
4. **`land-lane.js`** on the head of the queue ONLY. It merges the current base branch, runs the
   full unit target, checks the merge read-only, pushes, and opens the PR if the job gives a title
   and body file. Then wait for the owner to merge it, and land the next lane against the new
   base. Landing several lanes in one run re-creates the problem the queue exists to solve.
5. **`open-issue-review.js` again** once the queue is empty: close what landed, and rate what is
   left.

## `lane-dev.js`

Per lane, it runs these steps:

1. Implement, in an isolated worktree branched from the base.
2. Review through two read-only lenses: correctness, and tests and claims.
3. Give every non-nit finding to a skeptic who tries to refute it.
4. Run a fix round and a full unit run.
5. Run a read-only check.
6. Run a second fix round if the check found a blocking problem (`maxRounds`, default 2).
7. Draft the PR.

| arg | |
|---|---|
| `root` (required) | the main checkout. No agent touches it. |
| `reader` | a checkout that reviewers read branches through with `git -C … show` (default `root`) |
| `minBase` (required) | a commit each lane's base must contain |
| `base` | default `origin/v2` |
| `scratch` (required) | build output, `<scratch>/<key>/dd`. A reboot may wipe it. |
| `durable` (required) | notes (`work/<key>/`) and PR drafts (`drafts/<key>.md`) that must survive a reboot |
| `date` (required) | the DEVELOPMENT-PLAN entry's date |
| `context` | what the lanes belong to, e.g. "the build-48 fix list" |
| `plan`, `triage`, `prExample` | optional paths the agents read: the wave's plan, the triage report, a PR body to model |
| `knownFailures` | failures a green full run may still show, e.g. an iPad-only known issue |
| `developerDir` | default `/Applications/Xcode.app/Contents/Developer` |
| `maxRounds` | fix rounds before a lane stops unclean (default 2) |
| `lanes` | `[{key, issues, closes, branch, udid, udids, prompt}]`. `closes` is one `Closes #N.` per issue. `udid` is the lane's own simulator. `prompt` is the lane's design. |

```json
{"root": "/Users/me/FRUS-Explorer", "reader": "/Users/me/FRUS-Explorer/.claude/worktrees/orchestrator",
 "minBase": "ab27c834", "scratch": "/Users/me/Library/Caches/frus-lanes", "durable": "/Users/me/frus-lanes",
 "date": "2026-09-26", "context": "the build-48 fix list",
 "lanes": [{"key": "V", "issues": "#1512", "closes": "Closes #1512.", "branch": "claude/b48-tooling",
            "udid": "A36F4C02-37CC-4FEA-A589-13E6FB8B7D65", "udids": "iPhone 17 iOS 26.5 A36F4C02-…",
            "prompt": "YOUR PR: …"}]}
```

## `land-lane.js`

It merges the base into each job's committed branch. It resolves the conflicts every lane meets:
two lanes appending to the DEVELOPMENT-PLAN, the EditableContent header, CLAUDE.md's device
paragraphs, and an index version both lanes took. It also finishes or aborts a merge an
interrupted run left behind. It then builds, runs the full unit target, has a second agent check
the merge read-only, and pushes only when both are clean. It never force-pushes.

| arg | |
|---|---|
| `root` (required) | the main checkout. No agent touches it. |
| `baseSha` (required) | what the base branch is now |
| `base` | default `origin/v2` |
| `added` | what landed on the base since the lane branched, so conflicts can be read |
| `scratch` (required) | build output, `<scratch>/<key>/dd` |
| `knownFailures`, `developerDir` | as for `lane-dev.js` |
| `jobs` | `[{key, issue, wt, branch, udid, note, checkNote, pr \| title + bodyFile}]`. `wt` is the lane's worktree. `note` names overlaps with what landed. With `pr` it reports that PR's mergeability. With `title` and `bodyFile` it opens the PR. With neither, it only pushes. |

```json
{"root": "/Users/me/FRUS-Explorer", "baseSha": "d61b53f9", "added": "lane P (#1513): page_ranges start rows, index v61",
 "scratch": "/Users/me/Library/Caches/frus-lanes/land-d61b53f9",
 "jobs": [{"key": "V", "issue": "#1512", "wt": "/Users/me/FRUS-Explorer/.claude/worktrees/wf_1",
           "branch": "claude/b48-tooling", "udid": "A36F4C02-37CC-4FEA-A589-13E6FB8B7D65",
           "title": "Commit the build-48 tooling (#1512)", "bodyFile": "/Users/me/frus-lanes/drafts/V.md"}]}
```

## `open-issue-review.js`

It triages issues in batches of `batchSize` (default 7) against the base branch. Each batch then
goes to a skeptic. The skeptic tries to refute every proposed close, checks every incorrect-data
or feature-broken rating against the code as shipped, and upgrades anything rated too low. The
script logs every issue no agent triaged or verified, and every verdict the skeptic changed.

| arg | |
|---|---|
| `reader` (required) | a checkout the agents read through, read-only |
| `baseSha` (required) | what the base branch is now |
| `base` | default `origin/v2` |
| `newer` | issues filed recently from agents' read-only findings. Each is reproduced before it is rated. |
| `older` | issues with a prior verdict |
| `landed`, `openBranches`, `priorVerdicts`, `corpus`, `notes` | context: what has landed, open branches that will land first, the prior verdicts' path, the local corpus, anything else |
| `repo` | default `joshbotts/FRUS-Explorer` (all three scripts take it) |

```json
{"reader": "/Users/me/FRUS-Explorer/.claude/worktrees/orchestrator", "baseSha": "b192f8fc",
 "newer": [1489, 1491], "older": [234, 1309], "landed": "the build-48 PRs #1485–#1501",
 "priorVerdicts": "/Users/me/frus-lanes/triage/prior-verdicts-open.json", "corpus": "/Users/me/Development/frus/volumes"}
```

## Checking a script before you run it

This machine has no `node`. `tools/workflow-check/check_workflow.js` uses macOS's own
JavaScriptCore instead. It checks that the file begins with a pure-literal `meta`, uses no
`Date.now()` or `Math.random()`, and parses. It then runs the script against stub agents with
the args you give it, so a name the script never defined fails there, and so does a prompt that
would read "undefined":

```bash
osascript -l JavaScript tools/workflow-check/check_workflow.js .claude/workflows/lane-dev.js "$(cat args.json)"
```

The verdict line, `OK …` or `FAIL: …`, prints to stderr after `started …`.
