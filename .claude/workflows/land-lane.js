export const meta = {
  name: 'land-lane',
  description: 'Land the lane at the head of the serial merge queue: merge the current base branch into it, resolve, build, run the full unit target and, when the lane adds package code, swift test, check the merge read-only, and push only a green, checked merge; optionally open its PR.',
  whenToUse: 'A lane developed by lane-dev.js has reached the head of the queue and the owner has merged the one before it. Land ONE job per run unless the owner says otherwise.',
  phases: [
    { title: 'Merge', detail: 'merge the base, resolve, build, full unit run, swift test when owed' },
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
// What the package builds or reads. Xcode's schemes run none of the package's suites; only swift test does
// (CLAUDE.md, "Web edition (FRUS Explorer Light)", rule 4).
const PACKAGE_INPUT = 'a folder Package.swift names as a target path (every top-level folder except .claude/, Docs/, FRUSExplorer/, FRUSExplorer.xcodeproj/, FRUSExplorerTests/, FRUSExplorerUITests/, FRUSExplorerWidgets/, Planning/, Scripts/, Vendor/ and tools/; and FRUSExplorerTests/FRUSCoreKit/), Package.swift itself, or a data file under FRUSExplorer/Resources/, which package suites read from the repository'
// The shared kits FRUS Explorer Light compiles on Linux, and the rules that hold in them (the same section, rules 1 to 3).
const KIT_RULES = 'In shared code (FRUSCoreKit/, FTS5Store, SourceNoteKit, CrossRefKit, GeneratorKit, TEIHeaderKit, SemanticVectorsKit, ManifestGeneratorCore, and their test folders outside #if !SWIFT_PACKAGE): import no UI or app framework (SwiftUI, UIKit, AppKit, WebKit, SwiftData, CoreSpotlight, TipKit, NaturalLanguage); read no Bundle.main, UserDefaults or Keychain; name no type the app alone declares; leave every #if canImport guard in place; change kit behaviour in the kit, never in the forwarder the app keeps'
const JOBS = A.jobs || []
if (JOBS.length > 1) log(`land-lane: ${JOBS.length} jobs — the serial queue lands ONE lane at a time; a later job merges a base the earlier one has not yet joined`)

const MERGE = (j) => `
Merge ${BASE} (now ${BASE_SHA}, which added ${ADDED}) into the committed branch ${j.branch}, checked out in ${j.wt}.
House rules are in CLAUDE.md as merged: once the merge is committed, read ${j.wt}/CLAUDE.md, at least "Web edition (FRUS Explorer Light)" and the
FRUSCoreKit entry under "SPM package targets". The copy in your context is the session's and can be older than ${BASE}. Every git command as "git -C ${j.wt} ..."; absolute paths under ${j.wt}. NEVER touch ${ROOT} or any other worktree;
never stash, reset, rebase, push, open a PR, delete a branch, or git checkout -- files. If a hook blocks edits, EnterWorktree ${j.wt}. File no issues.
1. git -C ${j.wt} status must be clean. If it shows a merge in progress (a MERGE_HEAD left by an interrupted run), read what it holds: finish that
   resolution if it is ${BASE} at ${BASE_SHA}, otherwise git -C ${j.wt} merge --abort and start again. Never delete MERGE_HEAD by hand.
   git -C ${j.wt} fetch origin; confirm ${BASE} is ${BASE_SHA} (if it moved further, merge whatever it is and say so).
   Report the full sha of the ${BASE} you merged as baseMerged: the check reads it as the merge's second parent.
2. git -C ${j.wt} merge --no-commit ${BASE}. Resolve conflicts:
   - Planning/DEVELOPMENT-PLAN.md: both sides append entries at the end. Keep BOTH, the base's entries first, then this branch's, byte for byte.
   - Docs/EditableContent/Amendment-Log.md: many lanes append bullets at its end. Keep every bullet from both sides, the base's first. Any other Docs/EditableContent/ hunk:
     keep both sides' blocks, and recompute any count a section header states.
   - CLAUDE.md: lanes insert device-specific suite paragraphs, each with its own bash block. Keep BOTH paragraphs whole, the base's first, and check
     every code fence is balanced.
   - A number both sides took — an index-version bump (currentDateIndexVersion), a version-history entry: the side that landed first keeps it; this
     branch takes the next number, renumbers its own entries and notes, and raises any guard test that asserts it (e.g. >= 61 becomes >= 62).
   - A file this branch changed that ${BASE} has since MOVED (FRUSExplorer/… into FRUSCoreKit/…, or a suite into FRUSExplorerTests/FRUSCoreKit/):
     git follows the rename, and this branch's change belongs in the file at its NEW path. Never keep or re-create the old path: both app targets
     would compile it beside the moved file. On a rename/delete or modify/delete conflict, apply this branch's hunks to the moved file by hand.
     Then read what this branch added to the kit file. ${KIT_RULES}. A member that needs app state moves to an extension in an
     app file (FRUSExplorer/Search/IndexingPipeline+App.swift is the pattern); anything else is passed in.
   - Everything else: resolve by understanding both sides; never drop either side's change. Lane note: ${j.note || 'none'}
   - No conflict markers may remain. Commit the merge with git's default subject, a blank line, then your session's Co-Authored-By line
     (no "# Conflicts" lines).
3. For every Swift file either side changed since the merge base, check that each Docs/EditableContent/ block pointing at it still holds its key
   inside its lines: range; re-point any that moved in a follow-up commit "Docs: re-point EditableContent ranges after merging ${BASE_BRANCH} (${j.issue || (j.pr ? '#' + j.pr : 'lane ' + j.key)})".
   A block follows its file: if ${BASE} moved the file, the block's SOURCE path is the new one, and a block this branch added or re-pointed at the
   old path fails EditableContentKeyTests as "not found".
4. DEVELOPER_DIR=${DEV}, set -o pipefail, -derivedDataPath ${SCR}/${j.key}/dd, destination "platform=iOS Simulator,id=${j.udid}" — that UDID only; other
   lanes own the rest (xcrun simctl boot ${j.udid} || true). build-for-testing, then test-without-building -collect-test-diagnostics never
   -only-testing FRUSExplorerTests (the FULL unit target). It must be FULLY GREEN.${KNOWN} Read back the "Test run with N tests" line and every ✘ line.
   If a runner hangs before connecting, reboot that one UDID and re-run (never shutdown all). Background + poll (three minutes of silence kills a
   call). Build FRUSExplorerMac (platform=macOS) if the merge touched a Swift file both sides changed.
   Then the package run, which Xcode never makes. git -C ${j.wt} diff --name-only <the base you merged> HEAD is what this branch adds to the base,
   at the base's paths. If it names ${PACKAGE_INPUT}: DEVELOPER_DIR=${DEV} swift test --package-path ${j.wt} --scratch-path ${SCR}/${j.key}/spm
   in the background, polled (about two minutes; it counts as a build). It must exit 0 with no ✘ line. Report its "Test run with N tests" lines as
   swiftTest; otherwise report swiftTest as "not run: this branch adds no package input". green is true only when the unit run is green AND
   swift test, where owed, is.
5. If anything fails, find whether the MERGE caused it (compare with the pre-merge branch and with ${BASE}), fix it in a follow-up commit, re-run.
6. LAST STEP: xcrun simctl shutdown ${j.udid}. Do NOT push. Return data only.`
const OUT = { type: 'object', properties: { mergeCommit: { type: 'string' }, baseMerged: { type: 'string' }, conflicts: { type: 'string' },
  followUps: { type: 'string' }, fullRun: { type: 'string' }, swiftTest: { type: 'string' }, macBuild: { type: 'string' }, green: { type: 'boolean' }, notes: { type: 'string' } },
  required: ['mergeCommit', 'baseMerged', 'conflicts', 'fullRun', 'swiftTest', 'green'] }
const CHECK = (j, m) => `READ-ONLY check of a merge. Never edit, checkout, switch, stash, build or push. Branch ${j.branch} in ${j.wt}; use git -C ${j.wt}
only for log/show/diff/grep/merge-file (scratch output to your own scratch directory). The merge commit is ${m.mergeCommit}; its parents are the branch's
previous head and ${BASE} at ${m.baseMerged || BASE_SHA} (the run expected ${BASE_SHA}; the author merged what the base was when it fetched).
The author reports: ${JSON.stringify(m).slice(0, 2500)}
Verify: (a) no change from EITHER parent was dropped — first pair each path with the path the other parent renamed it to (git -C ${j.wt} diff -M
--name-status <merge base> <parent>, for each parent): ${BASE} may have moved a file this branch changed from FRUSExplorer/ into FRUSCoreKit/, and
this branch's hunks must then be in the moved file, with nothing left at the old path. Then for each file both parents changed relative to their
merge base, re-run git merge-file and compare with the merge result, and check one-sided files are blob-identical to their side; (b) no conflict markers anywhere in the tree, and no MERGE_HEAD;
(c) DEVELOPMENT-PLAN holds the base's entries then the branch's, none duplicated or truncated; (d) Docs/EditableContent/Amendment-Log.md keeps every
bullet from both sides, and CLAUDE.md keeps both sides' paragraphs with balanced fences; (e) a number both sides took is renumbered on this branch's
side, with its guard test; (f) any follow-up commit is limited to what it claims; (g) the merge commit carries the Co-Authored-By trailer; (h) if
git -C ${j.wt} diff --name-only ${m.baseMerged || BASE_SHA} HEAD names ${PACKAGE_INPUT}, the author reports a swift test run with its
result lines, not "not run"; (i) what this branch adds to a kit file keeps the rules: ${KIT_RULES}.
${j.checkNote || ''} allGood=false with specifics if anything is off.`
const CHK = { type: 'object', properties: { allGood: { type: 'boolean' }, details: { type: 'string' } }, required: ['allGood', 'details'] }
const PUSH = (j, m, c) => `Push one branch after a verified merge. The merge of ${BASE} into ${j.branch} (worktree ${j.wt}) is committed at or after
${m.mergeCommit}; its full unit run and, where owed, its swift test (${m.swiftTest || 'NOT REPORTED'}) were ${m.green ? 'green' : 'NOT green'}, and a read-only check returned allGood=${c.allGood}. Only if BOTH are true:
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
