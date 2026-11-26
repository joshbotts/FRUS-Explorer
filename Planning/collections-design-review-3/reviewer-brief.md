# Brief for every reviewer (read this whole file first)

You are one of six independent reviewers in an ADVERSARIAL REVIEW of a design proposal for the FRUS Explorer app, a SwiftUI app for iPhone, iPad and Mac for researching the Foreign Relations of the United States series. It is the third review of this design (row CR of the plan of record), and the last before its lanes are built.

The repository is checked out at `/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/l25-collection-templates-8f58f6`, on branch `claude/cr-collections-review-3`: `v2` at `b3acd7ad` with two planning commits on top. Call it REPO below.

**Strictly read-only.** Do not edit, create, delete, commit, push or publish anything in REPO or anywhere else, and do not start other agents. **Run no build, test, archive, simulator or app**: no `xcodebuild`, `swift build`, `swift test`, `swift run`, `Scripts/heavy.sh`. Another session is running an index version's landing runs on this Mac (`CLAUDE.md`, *One heavy job at a time*). You may:

- read any file in REPO, and run `git show`, `git log` and `git grep` there;
- read the public TEI, all of it, at `/Users/jbotts/Development/frus/volumes/` (the corpus at `216cdb764`, the commit the app's bundled files and index version 76 were measured at), with small stdlib Python scripts run with `python3 -I`;
- write your scripts and notes under `SCRATCH/work-<YOUR PREFIX>/`, and your report at `SCRATCH/<YOUR PREFIX>.md`, where SCRATCH is `/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-l25-collection-templates-8f58f6/f6d777ba-c969-4f0e-bff4-c72a64a567ce/scratchpad/review3`.

## What is under review

**The design record** `REPO/Planning/Collections-Customization-Design-2026-11-25.md`, in its third form as twice amended and then brought to the owner's answers on 2026-11-26. Read it whole before anything else.

- §2 is its author's reading of the app as it ships (build 1861, which it calls "1.0"). Treat §2 as a reading, not as fact.
- The proposal is §3 to §9: §3 the document on the exported page; §4 settings and the two steps of a template; §5 the interface; §6 citation styles; §7 what is stored; §8 the candidates (§8.1 for a document and its page, §8.2 more apparatus); §9 lanes.
- §10's twelve questions are answered. The answers are the plan of record's decisions 153 to 174, and §10 marks each.
- §11 and §12 are what the earlier reviews left: where each finding was answered, and the runs still owed.

**The answers** are in `REPO/Planning/Plan-Of-Record-2026-11-25.md`, §0, decisions 147 to 187. Read 147 to 174 whole. **The plan's §1c takes the design's lanes as rows L34 to L55, each with a brief** ("The rows, in the order they land"). Those briefs are the plan's reading of an unreviewed design, and are in scope too. Where a row's brief and the design disagree, or a brief leaves out what its row must settle, that is a finding.

**What the owner's answers changed**, in brief (the design's head lists them):

- the mark is *As published:* (decision 154);
- the export sheet stays format and destination, and lane 5 and the design's §4.4 are withdrawn (decision 156);
- the volume's heading leads in four document templates and the citation in two (decision 158);
- nine of §8.1's thirteen candidates are taken (decision 164), and eight of §8.2's (decision 171), with A8, A10, A11 and A12 changing what 1.0's blocks print, with no switch;
- step 2 has three more ticks, 17 controls where the design counted 14.

The text was brought to the answers by the session that runs this review. **If the text misstates a decision in your scope, that is a finding.**

**A2 is settled as far as the index goes.** `REPO/Planning/collections-design-review-3/a2-what-the-index-owes.md` is this review's first finding. It measured where documents link their terms, and on the owner's word index version 76 records the part of the document each term is linked in. Do not re-raise that. The block itself, and what row L52 owes, are in scope.

**Index version 76** is built and not yet merged. Read it with `git -C REPO show claude/plan-of-record-pr2011-2cc493:<path>`; its newest commits are `71cc5749` (the tables `term_mentions` and `division_start_pages`) and `40f70883`.

**The two reviews before this one** are `REPO/Planning/Collections-Design-Adversarial-Review-2026-11-25.md` (of the first form) and `REPO/Planning/Collections-Design-Second-Review-2026-11-25.md` (of the second), with their reports in `REPO/Planning/collections-design-review/` and `REPO/Planning/collections-design-review-2/`. The design's §11 says where the third form answers the second review. Do not re-raise a finding either review made unless you show the third form leaves it standing. A defect that the third form, its amendments or the owner's answers introduced is worth more.

**The boards.** Mockups of the third form, as amended and before the owner's answers, are under `SCRATCH/canvas/project/`. They are design sketches, not app code, and three things in them are superseded:
- `Main.dc.html` (the export sheet, iPhone) draws the two steps that decision 156 withdrew;
- every board prints *In the volume:*, now *As published:*;
- `TwoSteps.dc.html` has the citation leading in *Full text with everything*, which decision 158 changed.

The boards are:
- `OptionA.dc.html`: the collection's settings behind the Mac's gear;
- `TwoSteps.dc.html`: the two steps, iPhone;
- `OptionB.dc.html`: a document's settings, Mac;
- `PartsPhone.dc.html`: a document's settings, iPhone;
- `SectionSheet.dc.html`: a section's sheet, iPhone;
- `OptionC.dc.html`: *Show Parts*, Mac;
- `Marks.dc.html`: three openings of document 475;
- `Citations.dc.html`: a contents list in three styles.

## The owner's words

The ask the design answers, verbatim:

"I am not satisfied with the Collections feature. I am not able to customize how each document is displayed, yet the interface is very complicated. I want to be able to export a collection very quickly using sensible default templates (the new ones we created last week are good starting points). I also want to be able to fine-tune any aspect of the collection, including overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately. I want to be able to choose what citation format to use if the contents are listed that way. Consider other authorial capabilities along these lines as well. Consider what kinds of user interface alternatives might help me preserve clean simplicity for default situations and also wield powerful customizability for other times."

Two amendments the owner directed (the design's head quotes both), and decision 149: "Review, then build". **Do not re-argue the owner's decisions.** Where a decision, built as the design and the plan's rows describe it, has a cost, a gap or a defect that neither states, that is a finding.

## Where the review starts

The plan of record's row CR names these. Each is in one or two scopes below:
- **A2**, beyond the index: the block, its rows, and decision 174's links.
- **The three things the withdrawn §4.4 said** and where each now goes: a template's needs, how many headnotes will print, and what a block cannot fill. The design's §4.4 and the plan's §1c read them as step 1's cards (L44) and as L50's line.
- **A section's headnote default:** a new field, or the `includeHeadnote` every entry already has (the plan's §1c, *The promotion*).
- **The nine candidates of §8.1 that were taken,** which the design gives a line or two each and nowhere designs. For each: what it stores, what 1.0 does with it, and whether it travels in the collection file.
- **A8, A10, A11 and A12,** which change what collections already print, with no switch.
- **Step 2 with three more ticks:** 17 controls, and 51 over the collection's four screens.

## The six scopes (yours is named in your prompt)

- **INT, interaction and comprehension.** §4.2, §4.3, §5 and the boards, with the plan's rows L35, L44, L45, L47 and L50.
  - A person setting up and exporting a collection on iPhone, iPad and Mac.
  - The two steps in the collection's settings, step 2's ticks and shortcuts, and *1 differs* on every collection that equals a template today.
  - Where a template's needs and the headnote count are now said, with the export sheet kept as 1.0's.
  - *Export…* from the lists as the quick export.
  - The controls each §8.1 candidate adds and where they go: *Save as Template*, *Same settings as…*, the page's choices, the short form, a fourth text depth, See also at the collection, a section's headnote default, the iPad's settings column and the drawn opening.
  - Recount §5.5 from §5.2's lists and from today's code, with those candidates' controls added.
- **ENG, engineering feasibility and regressions.** §3.2 to §3.5, §3.8, §6's kit changes, §8 and §9, with the plan's rows L34 to L55, its table *What each row touches* and its list of where two rows meet.
  - Whether what the design and each brief say of the render model, the content assembly, the three exporters, the blocks' data source, the preview and the tests is true at the lines they cite.
  - Whether each taken candidate and each taken block can be built as described on each platform the app ships on (a tagged PDF, a fourth text depth, See also by page, A3, A4, A8, A10, A11, A12).
  - What breaks: pins, parity, the UI suites, the web edition's kit.
  - What a row's brief leaves out.
- **DATA, stored data, sync and CloudKit.** §7, §4.1 and every taken candidate that stores something.
  - The four properties; See also at the collection, and what its absence means.
  - A section's headnote default: read the model's history of `includeHeadnote` and settle what an explicit `false` on a heading made before the Composer redesign would do.
  - A saved template as a record type: two devices, the duplicate cleanup, what it holds, the research export's version 8.
  - The page's choices and the short form's, if kept on the collection; what 1.0 (1861) does with each new property on a record it then changes; Duplicate and the snapshot.
  - The single promotion and the R-7 gate.
  - What the blocks read from the index and the bundled files (A1, A3, A4, A8, A10, A11), and what L52 needs from version 76's table beyond the part.
- **FMT, the `.fruscollection` file and whatever else carries a collection.** §7.4, §7.5 and every carrier, as the owner's answers leave them.
  - For each taken candidate and each new block: whether it travels in the collection file, under what key, and what a 1.0 app does with a file the new version writes. Among them: selected passages as text, a saved template (not carried), See also at the collection, a section's headnote default, the page's choices, A2, A3 and A4 as block types, a headnote as its text with its author (decision 166).
  - The BibTeX, RIS and Zotero titles (decision 165).
  - The web page as a file: decision 174's term links and their anchors, and a document entered twice (#2004).
  - A12's table in the web page and in Word; a tagged PDF as a file.
  - The Agentic Analysis Guide's §15, both manuals, and every test that pins or describes a format.
- **EDI, editorial and scholarly integrity.** §3, §3.6, §3.7, §6, and the taken apparatus and candidates as a reader of an export meets them.
  - Whether *As published:* is true wherever it prints, a contents row's second line and a heading read from the index included.
  - The four openings of decision 158.
  - A2: one term defined differently by two volumes, and what "the documents that use it" says.
  - A3's completeness, as against what its title promises; A4 and a page that holds several documents.
  - A8's classes in words, and a scan's link that is a file's and not a document's.
  - A10's volume entry and its pages, in three styles; A11's administrations, at a transition and for an undated document.
  - A12's counts and the caveats of *Distinctive*; the sign for an omission in selected passages; the short form's uniqueness.
  - Test the design's claims about the volumes against the TEI.
- **A11Y, accessibility.** §5, §3.8 and §9's table of accessibility checks.
  - Step 2's 17 controls at the largest text sizes.
  - The iPad's settings column and pointing; *Show Parts*; the opening drawn in a document's settings at AX3 and AX5.
  - A12's table as a table; a tagged PDF; decision 174's in-page links; A1's line spoken with its tick.
  - Whether each check names a suite the project has, on the right devices. Use `REPO/.claude/rules/ui-tests.md`, which loads when you read a file under `FRUSExplorerUITests/`, and `REPO/Planning/UI-Test-Destinations-Runbook.md`.

Stay in your scope. If you meet something serious in another, give it one line under "Outside my scope" at the end and do not develop it.

## Your job

Attack the design as the owner's answers leave it. Find where, built as written, it would:
- fail one of the owner's asks;
- be as complicated as what it replaces, or more;
- mislead or strand a person;
- lose or corrupt their work;
- say something false, ambiguous or unmarked to a reader of an export;
- be impossible, or far costlier than the design or a row's brief claims, to build on a platform the app ships on;
- rest on a claim that the code, the volumes or the project's own rules contradict;
- contradict itself between two of its sections, between its text and a row's brief, or between its text and an owner's decision.

You are not asked to redesign it or to be balanced. Agreement is of no use; an unsupported objection is of no use either.

## Evidence standard

Every finding rests on something you re-read yourself in this session:
- a `file:line` in REPO (the app is under `FRUSExplorer/`, shared code under `FRUSCoreKit/`, tests under `FRUSExplorerTests/` and `FRUSExplorerUITests/`, the project's rules in `CLAUDE.md` and `.claude/rules/`, both manuals and the Agentic Analysis Guide under `Docs/`);
- a line of version 76's code on `claude/plan-of-record-pr2011-2cc493`;
- a section of the design or of the plan, quoted;
- a line of a board;
- or a count you made over the TEI, with how you made it.

Where the design or a brief cites a `file:line`, re-read that line before you rely on it: the citations are to `efd73ec` and `94719de`, and the tree has moved since. A claim about Apple's Human Interface Guidelines, WCAG, CloudKit, SwiftData, PDFKit, Word or how a platform behaves that you could not read today is marked "from memory, not fetched". A claim only a running app or device could settle is marked NEEDS A RUN, with the check that would settle it.

## Severity

- **S1:** built as written, the design fails one of the owner's asks; loses or corrupts a person's work; states something false or unmarked to a reader of an export; or cannot be built as described on a platform the app ships on.
- **S2:** a first-time user is misled, stuck or led into an error on a common task; a claim in the design or a brief is false or materially overstated; a clear accessibility or HIG rule is broken on a primary surface; or a cost the design leaves out would materially change a row's size.
- **S3:** real but secondary.

## Do not raise

- A weakness the design already states (its §5.6, §7.5, §12, §13's "Not read" and "Not done"), or one a row's brief already names as that row's to settle, unless you show it is worse than stated.
- An owner's decision as such (decisions 147 to 187).
- A preference of taste with no consequence for a person or for the build.
- A finding of the first or second review that the third form answers.

## Your report

Write it to `SCRATCH/<YOUR PREFIX>.md`: plain text, no preamble. Then end with a short final message that lists each finding on one line (ID, severity, the claim). If you cannot write the file, put the whole report in your final message instead.

At most TEN findings, strongest first. For each:

```
ID: <PREFIX>-n
Severity: S1 | S2 | S3
Claim: one sentence, falsifiable.
What a person meets: the concrete scenario, and on which platform (or: which reader of which file).
Evidence: file:line, design or plan §, board line or TEI count, each re-read; quote the line where it matters.
Refutation: what would refute it, and whether you checked.
Where it is answered: the design's text (which §); a row's brief (which row); or the owner (the question, in one line).
Direction: one sentence, not a redesign.
```

Then:
- **The starting points in my scope.** For each of the list above that falls in your scope, one line: SETTLED BY THE TEXT, A ROW'S BRIEF MUST SAY IT (which row, and what), or NEEDS THE OWNER (the question).
- **Attacked and held:** up to five things you tried to break and could not, one line each with its evidence.
- **Not read:** what you did not get to.
- **Outside my scope:** at most three lines.
