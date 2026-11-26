# Context streamlining of 2026-11-26: what is left for a session on the Mac

**Status: OPEN, for step 5 alone.** Steps 1 to 4 and the check in step 6 were made on the Mac on
2026-11-26, and *Results on the Mac*, at the end, gives each; step 5 waits on the owner's word.
Written by the cloud session that made the change, for one local session on the
Mac. That session had no Xcode, no `swift`, no simulator and no access to the Mac's own files, so
it changed documents only and ran no test. This note lists what only the Mac can do, in the order
to do it. When every step is done or declined, mark this file COMPLETE in its head and move it to
`Completed/` with an entry in that folder's `README.md`.

## What the change did

The session's entry in `DEVELOPMENT-PLAN.md` (2026-11-26) has the detail. In short:

| File | Before | After |
|---|---|---|
| `CLAUDE.md` | 131,937 characters, 510 lines | 57,022 characters, 322 lines |
| `Planning/DEVELOPMENT-PLAN.md` | 2,898,363 characters | 875,707 characters, before the session's own entry |

- **Six files under `.claude/rules/`** hold what left `CLAUDE.md` word for word: `ui-tests.md`,
  `generators.md`, `archive.md`, `semantic-vectors.md`, `word-cloud.md` and `reader-page.md`. Each
  opens with a `paths:` list, and Claude Code loads it when a session reads or edits a matching
  file. `CLAUDE.md` keeps a short paragraph for each, with the rules that bind a session that never
  opens a matching file.
- **`Planning/FRUSCoreKit-Runbook.md`** holds the `FRUSCoreKit` entry, which was one line of 48,003
  characters, as 43 headed paragraphs. `CLAUDE.md`'s entry keeps nine rules.
- **`Planning/Completed/`** holds October's 175 log entries (`DEVELOPMENT-PLAN-2026-10.md`) and
  the plan header of June (`DEVELOPMENT-PLAN-Plan-Header-2026-06.md`).
- **The three workflow scripts' prompts** name the new files.

## 1. Make the runs the change could not make

The change touches no source, test or bundled resource, so it owes no full unit run, no
`swift test` and no Mac build. One test reads `CLAUDE.md`, and two scan `Planning/`: run their
suites once, and read the test count back.

```bash
Scripts/heavy.sh xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerTests/SharedKitsBoundaryTests \
  -only-testing FRUSExplorerTests/CodingStandardsAuditTests
```

- `SharedKitsBoundaryTests.theKitsAreTheSharedCode` reads the line of `CLAUDE.md` that begins
  `Shared code: `. The move's script asserted that line is unchanged and still the only one.
- `CodingStandardsAuditTests.planOfRecordMatchesTheVisualMarketingPlan` lists `Plan-Of-Record-*.md`
  at the `Planning/` root. No such file was added, moved or edited.
- `CodingStandardsAuditTests.brokenSqliteInvocationsAreMarked` reads the `.js` and `.mjs` files
  under `Planning/`. None was added or edited.

## 2. Check that the rules files load, and for whom

The documentation says a path-scoped rule loads when Claude uses Read, Write or Edit on a matching
file, or views one with `cat` or `head`. It says nothing of when an ordinary subagent or a Workflow
agent loads one. The workflow prompts therefore tell an agent to read the files itself. Two checks
settle what is true on this Mac:

1. **The main session.** Start a fresh session in the repository and run `/context`: `CLAUDE.md`
   should be listed at about 16,000 tokens (by the ratio measured on 2026-10-09, when it was about
   37,000), and no file under `.claude/rules/`. Read
   `FRUSExplorerUITests/UIObstructionTests.swift`, and run `/context` again: `ui-tests.md` should
   now be listed. If a rules file is listed at launch, its front matter is malformed, and the
   documentation says such a file loads as if it had no `paths`.
2. **A subagent.** From that session, start one general-purpose subagent. Ask it to read
   `FRUSExplorerUITests/UIObstructionTests.swift` and then to quote the first of the "five rules
   that hold for every UI run" without opening any other file. If it can, a lane's agent loads the
   rules as the main session does, and the sentence added to `lane-dev.js` ("nothing is known to
   load them for a workflow agent") can say so. If it cannot, the sentence stands. Record the
   answer in `.claude/workflows/README.md` either way.

The glob `*Generator*/**` in `generators.md` is meant to match the generators' folders at the
repository's root (`ManifestGenerator/`, `ManifestGeneratorCore/`, `ManifestGeneratorTests/`). Check
it the same way: read `ManifestGeneratorCore/` for any one file, then `/context`.

## 3. Read the workflow prompts once before the next wave

`lane-dev.js`, `land-lane.js` and `.claude/workflows/README.md` were edited by hand. Each script
was parsed with Node before and after (all three parse), and none was run. Before the next
`lane-dev.js` run, read the three changed passages (`git log -p -1 -- .claude/workflows/`):

- `lane-dev.js`: the paragraph that tells an agent to read `CLAUDE.md` in its worktree now names
  the six rules files and the kit runbook.
- `land-lane.js`: the merge advice says where a row or a kit paragraph goes when a lane begun
  before 2026-11-26 added it to `CLAUDE.md`. A lane open on that day conflicts with this change in
  `CLAUDE.md` if it touched the UI table, the generator table or the `FRUSCoreKit` entry.

## 4. Review `MEMORY.md`, which the cloud session could not see

Auto memory is stored on the Mac only, at `~/.claude/projects/<project>/memory/`. Claude Code loads
the first 200 lines or 25 KB of `MEMORY.md` at the start of each local session, whichever comes
first, and reads the topic files beside it on demand. Cloud sessions and subagents receive none of
it. Read the file against these four questions:

- **Is it past 200 lines or 25 KB?** What lies beyond is never loaded. Move detail into topic files
  and leave `MEMORY.md` as an index of one line each.
- **Does an entry bind every session?** A rule that a cloud session or a lane's agent must follow
  belongs in the repository (`CLAUDE.md`, a rules file or a runbook), since neither sees memory.
- **Does an entry repeat `CLAUDE.md`, or contradict it?** Delete the copy. Where the two differ,
  find out which is right before deleting either.
- **Does an entry point at something that moved?** As of 2026-11-26 that includes `CLAUDE.md`'s
  UI suite table, its generator table, its "Before ANY archive" paragraph, its `FRUSCoreKit`,
  `SemanticVectorsKit` and `WordCloudKit` entries, the reader's-page paragraph, and every
  `DEVELOPMENT-PLAN.md` entry before 2026-11-01.

Do not delete an entry that records a caution about a destructive or irreversible action without
the owner's word.

## 5. Two proposals the owner has not approved

Each needs the owner's word before a session takes it. Neither is part of this change.

- **A size gate.** `CLAUDE.md` went from 226,886 characters to 54,241 on 2026-10-09 and was back at
  131,937 seven weeks later. A test in `CodingStandardsAuditTests` would hold it: `CLAUDE.md` under
  a budget (60,000 characters leaves about 3,000 of room), no line of it over 4,000 characters, and
  each file under `.claude/rules/` under the 40,000 characters Claude Code reads. It needs a unit
  run, so it is the Mac's. Today's longest line in `CLAUDE.md` is 2,539 characters.
- **Separating each rule from its history.** *Coding Standards* is about 17,000 characters, and many
  of its entries carry their full measurement record: the strict-concurrency entry is 2,452
  characters for about four sentences of rule. Keeping the rule and its issue number, and moving
  the record to a runbook beside it, would take `CLAUDE.md` to about 40,000 characters. The same
  holds for *Key Data Flows* (about 5,900) and the Directory Map's sixteen rows (about 10,400),
  which say file by file what the kit runbook now says by area.

## 6. Pointers left as written

These name a part of `CLAUDE.md` or of the log that moved. Each still leads to the text in one
step, through the paragraph `CLAUDE.md` keeps or the log's new head, so none was edited:

- `README.md` and its mirror `Docs/EditableContent/03-Repository-README.md` call `CLAUDE.md` "the
  canonical copy of every command" and send a reader to `DEVELOPMENT-PLAN.md` "for the session
  sequence". The owner's text, and gated: change both together if at all.
- `Planning/Editors-Annotations-Design-2026-11-06.md` (lines 515 and 517) and
  `Planning/Collections-Customization-Design-2026-11-25.md` (line 982) name `CLAUDE.md`'s generator
  table, its suite table and its *Command-line tools*.
- `Planning/nara-record-group-catalog-runbook.md` (line 507) and `Planning/OH-Report-2026-10-01.md`
  (line 347) name `CLAUDE.md`'s entry for a generator, which has been in
  `Planning/Generators-Runbook.md` since 2026-10-09.
- The plan of record was not edited. Where a row says to add a suite's row or a tool's row to
  `CLAUDE.md`, the row goes in `.claude/rules/ui-tests.md` or `.claude/rules/generators.md`.
- Code and test comments that cite `DEVELOPMENT-PLAN.md` for an entry of October 2026 (23 source
  and script files cite the log) find it in `Completed/DEVELOPMENT-PLAN-2026-10.md`, by its date.
- FRUS Explorer Light's sessions wrote the `FRUSCoreKit` entry's paragraphs. `CLAUDE.md` and the
  runbook's head now say a move is recorded in the runbook. The web edition's `COORDINATION.md` is
  in its own repository, which the cloud session could not reach: tell its sessions there if it
  describes where a kit move is recorded.

## Results on the Mac (2026-11-26)

Made by a session on the Mac at `8df01632`, #2014's merge, on the owner's word ("check pr
2014 and run the local-only steps").

1. **The runs.** 71 tests in 2 suites passed in 123 seconds on the iPhone 17 under iOS 27.0
   (Xcode 27.2): `CodingStandardsAuditTests` and the shared kits' suite, with
   `theKitsAreTheSharedCode`, `planOfRecordMatchesTheVisualMarketingPlan` and
   `brokenSqliteInvocationsAreMarked` among them. No warning but the known `GeneratedSummary` and
   `appintentsmetadataprocessor` lines.
2. **The rules files load, in the main session and in a subagent.**
   - The main session had begun before `.claude/rules/` existed in its worktree. Reading
     `FRUSExplorerUITests/UIObstructionTests.swift` brought `ui-tests.md` into its context, and
     reading `ManifestGeneratorCore/ManifestWriter.swift` brought `generators.md`, each from the
     worktree's `.claude/rules/`. So a rule is looked up when a file is read, and `*Generator*/**`
     matches the generators' folders.
   - A general-purpose subagent made the same two reads and received the same two files the same
     way. It reported that it began with the session's `CLAUDE.md`, the copy from before the move,
     and the `MEMORY.md` index. That differs from step 4 above and from #2014's log entry, which
     read in the documentation that auto memory reaches no subagent.
   - `/context` was not run, since a session cannot run a slash command: `CLAUDE.md`'s token count
     is the owner's to read. No workflow agent was measured, since a run needs the owner's opt-in.
     `.claude/workflows/README.md` records the measurement, and `lane-dev.js`'s sentence says what
     was measured.
3. **The workflow prompts.** The three passages read as described. Both scripts parse before and
   after, by JavaScriptCore's `checkModuleSyntax` with each body wrapped in an async function as the
   runtime runs it; a control with an unterminated template literal fails. One gap, left as
   written: `land-lane.js`'s advice for a lane begun before 2026-11-26 places a row it added to the
   UI table and a paragraph it added to the kit entry, but not a row it added to the generator
   table. No such lane exists: no pull request is open, and no branch ahead of `v2` touches
   `CLAUDE.md` but #2014's own.
4. **`MEMORY.md`**: 144 lines and 17,775 bytes, under both limits.
   - Three pointers into what moved were corrected in memory: the UI suite table, an October log
     entry, and a note that still described this log as a 31-session plan.
   - Five entries repeat `CLAUDE.md`: the build-number bump, the heavy lock's incident, the kit's
     two compilers, `build-for-testing` and the `/tmp` DerivedData sandbox. Each topic file holds a
     measurement `CLAUDE.md` does not, and three are cautions about destructive actions, so none was
     deleted.
   - One rule a lane's agent must follow was only in memory: steps that must follow one another go
     in one `heavy.sh` call. It is now the fourth habit under `CLAUDE.md`'s lock.
   - Left in memory: the `Regex` convention, which the compiler enforces, and the `devicectl`
     caution, a device step no lane takes. The 17 test-design rules and the 51 SwiftUI, SwiftData
     and XCUITest traps reach no cloud session; whether to give them a rules file by path is the
     owner's.
5. **The two proposals** were put to the owner on 2026-11-26.
6. **The pointers.** The web edition's `COORDINATION.md` does not say where a kit move is recorded,
   and its one pointer to the kit entry, the guarded modules, still holds: nothing to tell its
   sessions.
