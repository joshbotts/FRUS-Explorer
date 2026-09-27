export const meta = {
  name: 'land-lane',
  description: 'Land the lane at the head of the serial merge queue: merge the current base branch into it, resolve, build, run the full unit target, check the merge read-only, and push only a green, checked merge; optionally open its PR.',
  whenToUse: 'A lane developed by lane-dev.js has reached the head of the queue and the owner has merged the one before it. Land ONE job per run unless the owner says otherwise.',
  phases: [
    { title: 'Merge', detail: 'merge the base, resolve, build, full unit run' },
    { title: 'Check', detail: 'read-only check of the merge resolution' },
    { title: 'Push', detail: 'push only a checked, green merge; open the PR if asked' },
  ],
}
// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Generalized from the build-48 session's merge-v2-into-open runner (#1512). Arguments are
// documented in .claude/workflows/README.md.

const A = args || {}
const need = (k) => { if (!A[k]) throw new Error('land-lane: args.' + k + ' is required (see .claude/workflows/README.md)'); return A[k] }
const REPO = A.repo || 'joshbotts/FRUS-Explorer'
const ROOT = need('root')                 // the main checkout: never touched
const BASE = A.base || 'origin/v2'
const BASE_BRANCH = BASE.replace(/^origin\//, '')
const BASE_SHA = need('baseSha')          // what the base is expected to be now
const ADDED = A.added || 'the lanes that landed since this branch was developed'
const SCR = need('scratch')               // build output: <scratch>/<key>/dd
const DEV = A.developerDir || '/Applications/Xcode.app/Contents/Developer'
const KNOWN = A.knownFailures ? ` Known failures that are not yours: ${A.knownFailures}.` : ''
const JOBS = A.jobs || []
if (JOBS.length > 1) log(`land-lane: ${JOBS.length} jobs — the serial queue lands ONE lane at a time; a later job merges a base the earlier one has not yet joined`)

const MERGE = (j) => `
Merge ${BASE} (now ${BASE_SHA}, which added ${ADDED}) into the committed branch ${j.branch}, checked out in ${j.wt}.
House rules are in CLAUDE.md. Every git command as "git -C ${j.wt} ..."; absolute paths under ${j.wt}. NEVER touch ${ROOT} or any other worktree;
never stash, reset, rebase, push, open a PR, delete a branch, or git checkout -- files. If a hook blocks edits, EnterWorktree ${j.wt}. File no issues.
1. git -C ${j.wt} status must be clean. If it shows a merge in progress (a MERGE_HEAD left by an interrupted run), read what it holds: finish that
   resolution if it is ${BASE} at ${BASE_SHA}, otherwise git -C ${j.wt} merge --abort and start again. Never delete MERGE_HEAD by hand.
   git -C ${j.wt} fetch origin; confirm ${BASE} is ${BASE_SHA} (if it moved further, merge whatever it is and say so).
   Report the full sha of the ${BASE} you merged as baseMerged: the check reads it as the merge's second parent.
2. git -C ${j.wt} merge --no-commit ${BASE}. Resolve conflicts:
   - Planning/DEVELOPMENT-PLAN.md: both sides append entries at the end. Keep BOTH, the base's entries first, then this branch's, byte for byte.
   - Docs/EditableContent.md: many lanes append bullets to its closing "Appendix — Amendment log". Keep every bullet from both sides, the base's first. Any other hunk:
     keep both sides' blocks, and recompute any count a section header states.
   - CLAUDE.md: lanes insert device-specific suite paragraphs, each with its own bash block. Keep BOTH paragraphs whole, the base's first, and check
     every code fence is balanced.
   - A number both sides took — an index-version bump (currentDateIndexVersion), a version-history entry: the side that landed first keeps it; this
     branch takes the next number, renumbers its own entries and notes, and raises any guard test that asserts it (e.g. >= 61 becomes >= 62).
   - Everything else: resolve by understanding both sides; never drop either side's change. Lane note: ${j.note || 'none'}
   - No conflict markers may remain. Commit the merge with git's default subject, a blank line, then your session's Co-Authored-By line
     (no "# Conflicts" lines).
3. For every Swift file either side changed since the merge base, check that each Docs/EditableContent.md block pointing at it still holds its key
   inside its lines: range; re-point any that moved in a follow-up commit "Docs: re-point EditableContent ranges after merging ${BASE_BRANCH} (${j.issue || (j.pr ? '#' + j.pr : 'lane ' + j.key)})".
4. DEVELOPER_DIR=${DEV}, set -o pipefail, -derivedDataPath ${SCR}/${j.key}/dd, destination "platform=iOS Simulator,id=${j.udid}" — that UDID only; other
   lanes own the rest (xcrun simctl boot ${j.udid} || true). build-for-testing, then test-without-building -collect-test-diagnostics never
   -only-testing FRUSExplorerTests (the FULL unit target). It must be FULLY GREEN.${KNOWN} Read back the "Test run with N tests" line and every ✘ line.
   If a runner hangs before connecting, reboot that one UDID and re-run (never shutdown all). Background + poll (three minutes of silence kills a
   call). Build FRUSExplorerMac (platform=macOS) if the merge touched a Swift file both sides changed.
5. If anything fails, find whether the MERGE caused it (compare with the pre-merge branch and with ${BASE}), fix it in a follow-up commit, re-run.
6. LAST STEP: xcrun simctl shutdown ${j.udid}. Do NOT push. Return data only.`
const OUT = { type: 'object', properties: { mergeCommit: { type: 'string' }, baseMerged: { type: 'string' }, conflicts: { type: 'string' },
  followUps: { type: 'string' }, fullRun: { type: 'string' }, macBuild: { type: 'string' }, green: { type: 'boolean' }, notes: { type: 'string' } },
  required: ['mergeCommit', 'baseMerged', 'conflicts', 'fullRun', 'green'] }
const CHECK = (j, m) => `READ-ONLY check of a merge. Never edit, checkout, switch, stash, build or push. Branch ${j.branch} in ${j.wt}; use git -C ${j.wt}
only for log/show/diff/grep/merge-file (scratch output to your own scratch directory). The merge commit is ${m.mergeCommit}; its parents are the branch's
previous head and ${BASE} at ${m.baseMerged || BASE_SHA} (the run expected ${BASE_SHA}; the author merged what the base was when it fetched).
The author reports: ${JSON.stringify(m).slice(0, 2500)}
Verify: (a) no change from EITHER parent was dropped — for each file both parents changed relative to their merge base, re-run git merge-file and compare
with the merge result, and check one-sided files are blob-identical to their side; (b) no conflict markers anywhere in the tree, and no MERGE_HEAD;
(c) DEVELOPMENT-PLAN holds the base's entries then the branch's, none duplicated or truncated; (d) the EditableContent header keeps every clause from both
sides, and CLAUDE.md keeps both sides' paragraphs with balanced fences; (e) a number both sides took is renumbered on this branch's side, with its guard
test; (f) any follow-up commit is limited to what it claims; (g) the merge commit carries the Co-Authored-By trailer.
${j.checkNote || ''} allGood=false with specifics if anything is off.`
const CHK = { type: 'object', properties: { allGood: { type: 'boolean' }, details: { type: 'string' } }, required: ['allGood', 'details'] }
const PUSH = (j, m, c) => `Push one branch after a verified merge. The merge of ${BASE} into ${j.branch} (worktree ${j.wt}) is committed at or after
${m.mergeCommit}; its full unit run was ${m.green ? 'green' : 'NOT green'}, and a read-only check returned allGood=${c.allGood}. Only if BOTH are true:
git -C ${j.wt} status must be clean and HEAD must be the commit the check read (git -C ${j.wt} log --oneline -3); git -C ${j.wt} fetch origin, and
${BASE} must still be an ancestor of HEAD; then git -C ${j.wt} push -u origin ${j.branch} (fast-forward only; NEVER force).
${j.pr ? `Then gh pr view ${j.pr} --repo ${REPO} --json mergeable,mergeStateStatus (retry over ~30 s while UNKNOWN).`
  : j.title && j.bodyFile ? `Then open the PR: gh pr create --repo ${REPO} --base ${BASE_BRANCH} --head ${j.branch} --title ${JSON.stringify(j.title)} --body-file ${j.bodyFile}
(read the body first: it must close each issue with its own "Closes #N." line). Report its number and mergeStateStatus.`
  : 'Do not open a PR: none was asked for.'}
If a precondition is false, do NOT push; say why. Touch nothing else. Return data only.`
const PUSHOUT = { type: 'object', properties: { pushed: { type: 'boolean' }, head: { type: 'string' }, pr: { type: 'string' }, mergeable: { type: 'string' }, why: { type: 'string' } }, required: ['pushed', 'head'] }

const run = async (j) => {
  const m = await agent(MERGE(j), { label: 'merge:' + j.key, phase: 'Merge', schema: OUT })
  if (!m) return { job: j.key, merge: null }
  const c = await agent(CHECK(j, m), { label: 'check:' + j.key, phase: 'Check', schema: CHK })
  if (!c || !m.green || !c.allGood) return { job: j.key, merge: m, check: c, push: null, stopped: 'not pushed: the run was not green or the check was not clean' }
  const p = await agent(PUSH(j, m, c), { label: 'push:' + j.key, phase: 'Push', schema: PUSHOUT })
  return { job: j.key, merge: m, check: c, push: p }
}
phase('Merge')
const out = []
for (const j of JOBS) out.push(await run(j))
return out
