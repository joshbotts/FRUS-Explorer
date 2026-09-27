export const meta = {
  name: 'lane-dev',
  description: 'Develop fix lanes for the serial merge queue: implement each lane in its own worktree, review it through two lenses with every finding adversarially verified, run fix rounds until a read-only check is clean, and draft its PR. Never merges the base branch and never pushes.',
  whenToUse: 'Several issues are to be fixed as separate PRs and landed one at a time through land-lane.js. Run this first; it leaves each lane committed on its own branch with a PR draft.',
  phases: [
    { title: 'Implement', detail: 'one isolated-worktree agent per lane' },
    { title: 'Review', detail: 'two read-only lenses per lane' },
    { title: 'Verify', detail: 'one skeptic per non-nit finding' },
    { title: 'Fix', detail: 'resolve confirmed findings, full unit run' },
    { title: 'Check', detail: 'read-only check of the fix round' },
    { title: 'Draft', detail: 'PR description to the durable folder' },
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
// Generalized from the build-48 session's development-only lane runner (#1512). Arguments are
// documented in .claude/workflows/README.md; every path, simulator and issue comes from them.

const A = args || {}
const need = (k) => { if (!A[k]) throw new Error('lane-dev: args.' + k + ' is required (see .claude/workflows/README.md)'); return A[k] }
const REPO = A.repo || 'joshbotts/FRUS-Explorer'
const ROOT = need('root')                 // the main checkout: never touched by any agent
const READER = A.reader || ROOT           // a checkout reviewers read branches through, read-only
const BASE = A.base || 'origin/v2'
const MIN_BASE = need('minBase')          // a commit the lane's base must contain
const SCR = need('scratch')               // per-lane build output: <scratch>/<key>/
const DUR = need('durable')               // notes and drafts that must survive a reboot
const DEV = A.developerDir || '/Applications/Xcode.app/Contents/Developer'
const DATE = need('date')                 // the DEVELOPMENT-PLAN entry's date, e.g. 2026-09-26
const CONTEXT = A.context || 'a fix list of open issues'
const EXAMPLE = A.prExample ? `Model its structure and tone on ${A.prExample} (read it). ` : ''
const LANES = A.lanes || []
const IPAD_KNOWN = A.knownFailures ? ` Known failures that are not yours: ${A.knownFailures}.` : ''

const COMMON = `
You are implementing ONE PR of ${CONTEXT}. The house rules — build and test commands, which device
each UI suite needs, coding standards, Docs/EditableContent.md, the DEVELOPMENT-PLAN entry — are in
CLAUDE.md, which you already have; follow it. ${A.plan ? `Background on past lanes is in ${A.plan}. ` : ''}Your design is in the lane text
below and in the issues themselves: read each whole first, gh issue view <N> --repo ${REPO} --comments.

WORKSPACE — the serial merge queue's rules, non-negotiable:
- You run in an isolated git worktree. Run \`git rev-parse --show-toplevel\` and \`pwd\` first. If the top level is
  ${ROOT} or ${READER}, STOP and return an error. Use absolute paths under your own worktree for every file.
- git fetch origin, then create your branch FROM ${BASE}: git switch -c <branch> ${BASE}. Confirm git log -1 shows
  ${MIN_BASE} or a later commit.
- This lane lands later through the serial queue (land-lane.js), which merges the base once, right before its PR opens.
  So: never merge ${BASE} into your branch, never push, never open a PR. Never run git checkout/switch/stash/reset/worktree
  in any other checkout, never \`git stash\`, never delete a branch. Commit on your branch only: a one-sentence title stating
  the user-visible outcome with the issue number, a body giving cause and fix, ending with the Co-Authored-By line your
  session's attribution instructions give.
- Never edit a file to test a hypothesis outside a deliberate A/B that you restore by re-editing (never git checkout).

BUILD AND TEST: DEVELOPER_DIR=${DEV}, \`set -o pipefail\`, -derivedDataPath ${SCR}/<lane key>/dd, and only the simulator
UDIDs your lane names (xcrun simctl boot <UDID> || true; never \`simctl shutdown all\`; another lane owns every other
device). build-for-testing takes 10–25 minutes: run it in the background and poll, because a call silent for three minutes
is killed. test-without-building with -collect-test-diagnostics never and -only-testing FRUSExplorerTests/<TypeName> (the
type, never the @Suite string), and read back the "Test run with N tests" line: a filter that matches nothing runs zero tests
and still passes. Before returning, run the FULL unit target (-only-testing FRUSExplorerTests) and record its line.${IPAD_KNOWN}
- A/B: every new test must FAIL on the unfixed code first (record the ✘ lines), then pass with the fix. A scan test must
  assert it read more than zero files or sites.
- Test rules learned the hard way: drive the real code path, never a copy of it; a \`guard … else { return }\` in a test is
  vacuous; one fixture per guard conjunct; every fallback or else branch you add gets its own test; a source scan matches a
  call's balanced parentheses or braces, not a text window, and fails naming the sites.
- Claims: never write "the first" or "the only" without grepping for the counterexample; a comment saying "every X reads
  this" is checked against every X; every corpus figure counts exactly what its sentence names; a test or doc that says it
  guards a regression names the device or idiom it can fail on; when a fix makes state persist or reset, check every way the
  view is re-entered (Back, the iPad two-pane gate, a tab switch, a second window).
- If the lane's target turns out wrong once you read the code, choose the right one, pin the choice with a test, say why.
- A NEW source or test file needs \`xcodegen generate --spec project.yml\`, then CLAUDE.md's scheme restore, inside your worktree
  only, and the project.pbxproj change committed: prefer adding to an existing file.
- Every changed user-facing defaultValue: amend its block in Docs/EditableContent.md. Moving lines in a file it annotates
  with "lines:" ranges means updating EVERY range for that file. A block's text is always what the app ships; leave any
  ✎ or ⚑ note after a block in place. Record your change as one bullet at the end of its "Appendix — Amendment log",
  never in the header.
- Add one "## Session ${DATE} — <outcome>" entry at the END of Planning/DEVELOPMENT-PLAN.md, shaped like the last two:
  the question, what was measured, what changed, how verified, real numbers only.
- Store nothing a reviewer or later round needs ONLY under /private/tmp (a reboot wipes it): commit it, or write it to
  ${DUR}/work/<lane key>/.
- Out-of-scope defects: describe them fully in your return (sites, counts, a suggested fix). Do not file issues.
- When all builds and tests are done, shut down every simulator you booted. Then write your diff:
  git diff ${BASE}...HEAD > ${SCR}/<lane key>/<branch short name>.diff

Return data only: per PR the branch, commit sha, worktree path, files changed, the A/B evidence (failing line before,
passing line after, with test counts), the macOS build result, what you could not do or verify, and every decision the
lane text did not settle.
`
const RESULT = { type: 'object', properties: { prs: { type: 'array', items: { type: 'object', properties: {
  issue: { type: 'string' }, branch: { type: 'string' }, commit: { type: 'string' }, worktree: { type: 'string' }, diffPath: { type: 'string' },
  filesChanged: { type: 'array', items: { type: 'string' } }, abEvidence: { type: 'string' }, macBuild: { type: 'string' }, unverified: { type: 'string' },
  decisions: { type: 'string' }, summary: { type: 'string' } }, required: ['issue', 'branch', 'commit', 'diffPath', 'abEvidence', 'summary'] } },
  error: { type: 'string' } }, required: ['prs'] }
const REVIEW_SCHEMA = { type: 'object', properties: { summary: { type: 'string' }, findings: { type: 'array', items: { type: 'object', properties: {
  title: { type: 'string' }, file: { type: 'string' }, line: { type: 'integer' },
  severity: { type: 'string', enum: ['bug', 'regression', 'test-gap', 'doc-inaccuracy', 'plan-deviation', 'nit'] },
  detail: { type: 'string' }, evidence: { type: 'string' } }, required: ['title', 'file', 'severity', 'detail', 'evidence'] } } }, required: ['summary', 'findings'] }
const VERDICT = { type: 'object', properties: { real: { type: 'boolean' }, reasoning: { type: 'string' } }, required: ['real', 'reasoning'] }
const RRULES = (pr) => `READ-ONLY review of one PR diff: ${pr.diffPath} (branch ${pr.branch}, issue ${pr.issue}). Read files at the branch with
git -C ${READER} show ${pr.branch}:<path> and at the base with git -C ${READER} show ${BASE}:<path>. NEVER checkout, switch, stash or edit
anything anywhere, and never build. Read the issue (gh issue view --repo ${REPO}, with comments)${A.plan ? ` and the plan's section for it in ${A.plan}` : ''}. Cite path:line.`
const LENSES = [
  { key: 'correctness', text: 'LENS: correctness and completeness against the issue and the lane design. Does it fix every surface the issue names (both platforms, twin views), break any other caller, or deviate from a recorded owner decision? Grep for every other site of the pattern it fixes.' },
  { key: 'tests-claims', text: 'LENS: tests and claims. Would each new test fail on the base and on a plausible regression (name the mutation)? Any vacuous guard, wrong -only-testing type, scan that could pass reading zero files, fixture that does not match real data? Is every number and factual claim in comments, Docs/EditableContent.md and the DEVELOPMENT-PLAN entry true?' },
]
const reviewAndVerify = async (key, impl) => {
  if (!impl || !impl.prs || !impl.prs.length) return { lane: key, impl, reviews: [] }
  const reviews = await parallel(impl.prs.flatMap(pr => LENSES.map(l => async () => {
    const r = await agent(RRULES(pr) + '\n\n' + l.text, { label: `review:${key}:${l.key}`, phase: 'Review', schema: REVIEW_SCHEMA })
    if (!r) return null
    const serious = r.findings.filter(f => f.severity !== 'nit')
    const verified = await parallel(serious.map(f => () =>
      agent(RRULES(pr) + `\n\nA reviewer reported this. Independently try to REFUTE it; default real=false if it does not hold.\nTITLE: ${f.title}\nSEVERITY: ${f.severity}\nWHERE: ${f.file}:${f.line || ''}\nDETAIL: ${f.detail}\nEVIDENCE: ${f.evidence}`,
        { label: `verify:${key}`, phase: 'Verify', schema: VERDICT }).then(v => ({ ...f, verdict: v }))))
    return { pr: pr.branch, lens: l.key, summary: r.summary, findings: [...verified.filter(Boolean), ...r.findings.filter(f => f.severity === 'nit')] }
  })))
  return { lane: key, impl, reviews: reviews.filter(Boolean) }
}

const FIX = (j, round) => `
Round ${round} on the committed branch ${j.branch}, checked out in ${j.wt}. Every git command as "git -C ${j.wt} ..."; absolute paths under ${j.wt}.
NEVER touch ${ROOT}, ${READER} or any other worktree; never stash, reset, rebase, push, open a PR, delete a branch, or git checkout -- files. If a hook
blocks edits, EnterWorktree ${j.wt}. File no issues; put anything out of scope in openItems with sites, counts and a fix.
Work: ${j.notes}
Rules: every new or changed test is shown to fail on the code before its fix (A/B by re-editing, never git checkout; record the lines). Keep comments,
Docs/EditableContent.md (every lines: range in a file you move lines in; your bullet goes in its closing Amendment log appendix) and this branch's DEVELOPMENT-PLAN entry true to
the final code; correct earlier paragraphs in place and add a "Review fixes, round ${round} (${DATE})" section. New strings follow CLAUDE.md's localization rule.
No new source files. Commit ONE commit "Review fixes, round ${round}: <what> (${j.issue})" with your session's Co-Authored-By line.
Do NOT fetch or merge ${BASE} and do NOT push: this branch lands later through the serial merge queue.
If the worktree already holds UNCOMMITTED changes from an interrupted attempt at this round, read git status and git diff first, keep what is right, finish
the rest, and commit once. If git status shows a merge in progress (a MERGE_HEAD), stop and report it: this round never merges.
Build and test: DEVELOPER_DIR=${DEV}, set -o pipefail, -derivedDataPath ${SCR}/${j.key}/dd, destination "platform=iOS Simulator,id=${j.udid}"
(xcrun simctl boot ${j.udid} || true; never shutdown all). build-for-testing, then test-without-building -collect-test-diagnostics never -only-testing
FRUSExplorerTests (the FULL unit target): it must be FULLY GREEN.${IPAD_KNOWN} If a runner hangs before establishing a connection, reboot that one UDID
and re-run. Background + poll (three minutes of silence kills a call). Build FRUSExplorerMac (platform=macOS) if you touched Mac-compiled code.
Write git -C ${j.wt} diff ${BASE}...HEAD > ${SCR}/${j.key}/final.diff. LAST STEP: xcrun simctl shutdown every simulator you booted. Return data only.`
const OUT = { type: 'object', properties: { fixCommit: { type: 'string' }, resolutions: { type: 'string' },
  abEvidence: { type: 'string' }, fullRun: { type: 'string' }, green: { type: 'boolean' }, macBuild: { type: 'string' }, openItems: { type: 'string' } },
  required: ['fixCommit', 'resolutions', 'fullRun', 'green'] }
const CHECK = (j, work) => `READ-ONLY check. Never edit, checkout, switch, stash, build or push. Branch ${j.branch} in ${j.wt}: git -C ${j.wt} log/show/diff/grep only.
The review findings this round had to resolve: ${String(j.notes).slice(0, 6000)} The latest work: ${JSON.stringify(work).slice(0, 3000)}
Check: (1) every CONFIRMED finding and every listed item is resolved (evidence path:line); (2) each new test would fail on the mutant it names;
(3) no conflict markers and no MERGE_HEAD; (4) every figure in comments, Docs/EditableContent.md and the DEVELOPMENT-PLAN entry is supported by the code
or a recorded measurement. Classify each problem as BLOCKING (a code defect, a test that cannot fail, a wrong user-facing claim, a lost change) or NIT
(wording). allClean=true only if nothing is BLOCKING. Return data only.`
const CHK = { type: 'object', properties: { allClean: { type: 'boolean' }, blocking: { type: 'string' }, nits: { type: 'string' }, perItem: { type: 'string' } },
  required: ['allClean', 'blocking', 'nits', 'perItem'] }
const DRAFT = (j, history) => `Draft the GitHub PR description for branch ${j.branch} (worktree ${j.wt}, READ-ONLY: git -C ${j.wt} log/show/diff ${BASE}...HEAD;
never edit the worktree). Write it to ${DUR}/drafts/${j.key}.md and return the title. ${EXAMPLE}Open with a line naming the lane (${j.key} of ${CONTEXT})
and give the exact closing line "${j.closes}": one "Closes #N." per issue, because GitHub closes only the first number after a single Closes. Sections: "What
was wrong"; "The fix"; "Tests" (suites, counts, the mutants each kills, UI runs per device); the full unit run as the branch's records state it; review
rounds; "Filed rather than fixed here" (only issues that relate); "Owner items" (every owner step the DEVELOPMENT-PLAN entry names); a per-platform "Visual
check" list. Every figure must be one the branch's records state. Tight bullets. End with the PR attribution line your session's instructions give.
Title: one plain sentence in the repo's commit-subject style stating the fixed behaviour, then " (${j.issue})". Context: ${JSON.stringify(history).slice(0, 3000)}`

const finish = async (j) => {
  const history = []
  const r0 = j.startRound || 1
  let work = await agent(FIX(j, r0), { label: 'fix' + r0 + ':' + j.key, phase: 'Fix', schema: OUT })
  if (!work) return { job: j.key, error: 'no fix result' }
  history.push(work)
  let check = await agent(CHECK(j, work), { label: 'check:' + j.key, phase: 'Check', schema: CHK })
  history.push(check)
  const maxRounds = Math.max(1, A.maxRounds || 2)
  let round = r0
  while (check && !check.allClean && round < r0 + maxRounds - 1) {
    round += 1
    const extra = { ...j, notes: `Resolve these BLOCKING problems from the read-only check (take the nits too if cheap): ${check.blocking}\nNits: ${check.nits}` }
    work = await agent(FIX(extra, round), { label: 'fix' + round + ':' + j.key, phase: 'Fix', schema: OUT })
    history.push(work)
    check = work ? await agent(CHECK(j, work), { label: 'check' + round + ':' + j.key, phase: 'Check', schema: CHK }) : null
    history.push(check)
  }
  if (!check || !check.allClean || (work && work.green === false)) return { job: j.key, history, stopped: `not clean after ${round - r0 + 1} round(s)` }
  const draft = await agent(DRAFT(j, history), { label: 'draft:' + j.key, phase: 'Draft',
    schema: { type: 'object', properties: { title: { type: 'string' }, path: { type: 'string' } }, required: ['title', 'path'] } })
  return { job: j.key, history, draft, landed: false, note: 'not merged with the base and not pushed: land it through land-lane.js' }
}

const results = []
for (const lane of LANES) {
  phase('Implement')
  const extra = [A.triage ? `The triage of these issues is in ${A.triage}: read your issues' entries.` : '',
    `Branch: ${lane.branch}. Simulators: ${lane.udids || lane.udid}.`,
    `Your scratch directory: ${SCR}/${lane.key} (mkdir -p it); durable notes: ${DUR}/work/${lane.key}.`].filter(Boolean).join('\n')
  const impl = await agent(COMMON + '\n\n' + lane.prompt + '\n' + extra,
    { label: 'impl:' + lane.key, phase: 'Implement', isolation: 'worktree', schema: RESULT })
  const r = await reviewAndVerify(lane.key, impl)
  const pr = r && r.impl && r.impl.prs && r.impl.prs[0]
  if (!pr) { results.push({ key: lane.key, impl: r && r.impl, error: 'no implementation result' }); continue }
  const confirmed = [], nits = []
  let refuted = 0
  for (const rv of (r.reviews || [])) for (const f of rv.findings) {
    if (f.severity === 'nit') nits.push(`[${rv.lens}] ${f.title} — ${f.file}:${f.line || ''} — ${f.detail}`)
    else if (f.verdict && f.verdict.real) confirmed.push(`[${rv.lens}] ${f.severity}: ${f.title} — ${f.file}:${f.line || ''} — ${f.detail} EVIDENCE: ${f.evidence}`)
    else refuted++
  }
  log(`${lane.key} review: ${confirmed.length} confirmed, ${refuted} refuted, ${nits.length} nits`)
  const wt = pr.worktree || ''
  if (!wt) { results.push({ key: lane.key, impl: r.impl, reviews: r.reviews, error: 'implementation returned no worktree path' }); continue }
  const j = { key: lane.key, issue: lane.issues, closes: lane.closes, wt, branch: pr.branch || lane.branch, udid: lane.udid,
    notes: (confirmed.length ? 'Resolve every CONFIRMED review finding (each was independently verified):\n' + confirmed.join('\n') : 'The review confirmed no finding.')
      + (nits.length ? '\nNits (take the cheap, clearly right ones; say which you left and why):\n' + nits.join('\n') : '')
      + `\nSimulators: ${lane.udids || lane.udid}. Build FRUSExplorerMac if you touch Mac-compiled code.` }
  phase('Fix')
  const fin = await finish(j)
  results.push({ key: lane.key, impl: r.impl, reviews: r.reviews, confirmed, nits, finish: fin })
}
return results
