export const meta = {
  name: 'open-issue-review',
  description: 'Triage a list of open issues against the current base branch, then give every verdict to an independent skeptic: refute every proposed close, check every incorrect-data or feature-broken rating against the code as shipped, and upgrade anything rated too low. Read-only.',
  whenToUse: 'Before planning a fix wave, and again after one lands: which issues are fixed, which show users wrong data or break a feature, and what each fix would touch.',
  phases: [
    { title: 'Triage', detail: 'one agent per batch of issues' },
    { title: 'Verify', detail: 'one skeptic per batch' },
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
// Generalized from the build-48 session's open-issue re-review (#1512). Arguments are documented
// in .claude/workflows/README.md.

const A = args || {}
const need = (k) => { if (!A[k]) throw new Error('open-issue-review: args.' + k + ' is required (see .claude/workflows/README.md)'); return A[k] }
const REPO = A.repo || 'joshbotts/FRUS-Explorer'
const READER = need('reader')             // a checkout agents read through, read-only (git -C … show/grep/log)
const BASE = A.base || 'origin/v2'
const BASE_SHA = need('baseSha')
const NEWER = A.newer || []               // issues filed recently from agents' read-only findings: reproduce before rating
const OLDER = A.older || []               // issues with a prior verdict to re-check
const ISSUES = [...NEWER, ...OLDER]
if (!ISSUES.length) throw new Error('open-issue-review: args.newer and/or args.older must list issue numbers')
const SIZE = Math.max(1, A.batchSize || 7)
const BATCHES = []
for (let i = 0; i < ISSUES.length; i += SIZE) BATCHES.push(ISSUES.slice(i, i + SIZE))

const CONTEXT = [
  A.landed ? `What has landed since the last review: ${A.landed}` : '',
  A.openBranches ? `Open work that will land first, read at its branch with git -C ${READER} show <branch>:<path>: ${A.openBranches}` : '',
  A.priorVerdicts ? `Prior verdicts for the older issues: ${A.priorVerdicts}. For an older issue, say whether its verdict still holds and why it changed if it did.` : '',
  A.notes ? A.notes : '',
  A.corpus ? `Local corpus (read-only): ${A.corpus}.` : '',
].filter(Boolean).join('\n')

const RULES = `READ-ONLY. Never edit, checkout, switch, stash, build, push, comment, close, label or create anything on GitHub.
Tools: gh issue view <N> --repo ${REPO} --comments; gh pr view <N> --repo ${REPO}; git -C ${READER} fetch -q origin;
git -C ${READER} log --oneline ${BASE} --grep '#<N>'; git -C ${READER} show ${BASE}:<path>; git -C ${READER} grep -n <pattern> ${BASE} -- <paths>.
${BASE} is now ${BASE_SHA}. A PR body closes only the FIRST issue after a single "Closes", so read PR bodies for every mention, not only closing refs.
The ${NEWER.length} newer issues (${NEWER.map(n => '#' + n).join(', ') || 'none'}) were filed from agents' read-only findings, often from code that
was read and not run: verify each defect is REALLY present at ${BASE} before rating it.
${CONTEXT}`
const TRIAGE_SCHEMA = { type: 'object', properties: { issues: { type: 'array', items: { type: 'object', properties: {
  number: { type: 'integer' }, title: { type: 'string' },
  status: { type: 'string', enum: ['fixed', 'fixed-by-open-pr', 'partly-fixed', 'still-open', 'obsolete', 'upstream-only', 'owner-decision'] },
  closeEvidence: { type: 'string' },
  severity: { type: 'string', enum: ['incorrect-data', 'feature-broken', 'degraded-ui', 'dev-or-docs-only', 'enhancement', 'n/a-closed'] },
  userImpact: { type: 'string' }, whoSees: { type: 'string' }, platforms: { type: 'string' },
  reindexNeeded: { type: 'string', enum: ['yes', 'no', 'unknown'] }, dataRegenNeeded: { type: 'string' },
  effort: { type: 'string', enum: ['S', 'M', 'L'] }, evidence: { type: 'string' },
  subsystem: { type: 'string' }, filesLikely: { type: 'string' }, relatedIssues: { type: 'string' },
  priorVerdictChange: { type: 'string' }, notes: { type: 'string' } },
  required: ['number', 'title', 'status', 'severity', 'userImpact', 'reindexNeeded', 'effort', 'evidence', 'subsystem', 'filesLikely'] } } }, required: ['issues'] }
const TRIAGE = (b) => `${RULES}

Triage these open issues: ${b.map(n => '#' + n).join(', ')}. For EACH:
1. Read the issue whole (with comments). Check whether a landed PR fixed it, and CHECK THE CODE OR DATA AT ${BASE} that the defect is actually gone before
   calling it fixed — cite path:line. A PR that fixed a sibling does not fix it. status: fixed, fixed-by-open-pr (open work named above fixes it),
   partly-fixed (say what remains), still-open, obsolete (premise false or code gone), upstream-only (the defect is in data another party publishes),
   owner-decision (blocked on a copy or design choice).
2. If not closed, classify what it does to users of the current build. incorrect-data = the app shows, exports or cites a wrong fact, count, label, date,
   citation, attribution or document; feature-broken = a user cannot complete something the app offers (a control missing or inert, a sheet unusable, an
   export unusable, data lost); degraded-ui = cosmetic, layout, wording, or a workaround exists; dev-or-docs-only = tests, generators, docs, warnings,
   dead code; enhancement = a new capability. Be strict: incorrect-data only when a user would see or export something false; say exactly what, where and
   how often (whoSees). Measure reach where cheap, and say when a count is an estimate. For each NEWER issue, reproduce the claim from the code (read the
   named sites); if it does not hold, say so and rate it accordingly.
3. reindexNeeded (would a correct fix change what IndexingPipeline stores?), dataRegenNeeded (which generator, or "no"), effort S/M/L, subsystem,
   filesLikely (the files a fix would touch), relatedIssues (open issues a fix should share a PR with, and why). For older issues, priorVerdictChange:
   "unchanged" or what changed.
Return data only.`
const VERIFY_SCHEMA = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: {
  number: { type: 'integer' }, agreesStatus: { type: 'boolean' }, correctedStatus: { type: 'string' },
  agreesSeverity: { type: 'boolean' }, correctedSeverity: { type: 'string' }, reasoning: { type: 'string' } },
  required: ['number', 'agreesStatus', 'agreesSeverity', 'reasoning'] } } }, required: ['verdicts'] }
const VERIFY = (items) => `${RULES}

A triage agent made the claims below. You are an independent SKEPTIC. For each item:
- If it says fixed / fixed-by-open-pr / obsolete / upstream-only (that is, "close it"): try to REFUTE that — find any part of the issue still reproducible
  from the code or data at ${BASE}. Default agreesStatus=false if you cannot confirm the defect is gone.
- If it rates severity incorrect-data or feature-broken: check that the user really sees or exports something false, or really cannot complete the action,
  in the build as shipped (not a test-only or hypothetical path) — read the code path yourself. Downgrade if cosmetic, unreachable, or with an obvious
  workaround.
- If it rates degraded-ui / dev-or-docs-only / enhancement but the user actually sees wrong data or a broken feature, upgrade it.
Give correctedStatus / correctedSeverity only when you disagree.
ITEMS:
${JSON.stringify(items, null, 1).slice(0, 60000)}
Return data only.`

const out = await pipeline(BATCHES,
  (b, _, i) => agent(TRIAGE(b), { label: `triage:${i + 1}`, phase: 'Triage', schema: TRIAGE_SCHEMA }),
  (t, b, i) => {
    if (!t) return { batch: b, triage: null, verify: null }
    return agent(VERIFY(t.issues), { label: `verify:${i + 1}`, phase: 'Verify', schema: VERIFY_SCHEMA }).then(v => ({ batch: b, triage: t, verify: v }))
  })
const missing = ISSUES.filter(n => !out.some(o => o && o.triage && o.triage.issues.some(x => x.number === n)))
if (missing.length) log('NOT TRIAGED: ' + missing.join(', '))
const unverified = ISSUES.filter(n => !out.some(o => o && o.verify && o.verify.verdicts.some(x => x.number === n)))
if (unverified.length) log('NOT VERIFIED: ' + unverified.join(', '))
const overturned = out.filter(o => o && o.verify).flatMap(o => o.verify.verdicts.filter(v => !v.agreesStatus || !v.agreesSeverity).map(v => v.number))
log(`${ISSUES.length} issues; the skeptics disagreed on ${overturned.length}: ${overturned.map(n => '#' + n).join(', ') || 'none'}`)
return { out, missing, unverified, overturned }
