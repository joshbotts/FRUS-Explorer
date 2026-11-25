# Brief for every reviewer (read this whole file first)

You are one of five independent reviewers in an ADVERSARIAL REVIEW of a design proposal for the FRUS Explorer app, a SwiftUI app for iPhone, iPad and Mac for researching the Foreign Relations of the United States series. The repository is at /home/user/FRUS-Explorer.

Strictly read-only: do not edit, create, delete, commit, push or publish anything, and do not start other agents. Nothing can be built or run here (no Swift toolchain, no Xcode, no simulator).

## What is under review

The design record `/home/user/FRUS-Explorer/Planning/Collections-Customization-Design-2026-11-25.md` proposes a redesign of the app's Collections feature. Read it whole before anything else.

The option under review is its RECOMMENDED HYBRID (§4.5), whose parts are in §3, §4.1, §4.3, §4.4, §4.6, §5 and §6:

- a template gallery first, in an inspector and in the export sheet;
- one "parts inspector" listing ten parts of a document at three scopes (this document, this section, whole collection), each control showing what is in force, with a dot for a change and Reset;
- the live preview as the way in: an "Adjust" switch outlines and names each part, and a tap on a part opens that part's settings. Review BOTH forms of that tap: (i) it opens the inspector on that part; (ii) it opens a popover on the page;
- the export sheet as a template, a format and a button, opened from the editor, the Collections list and the Mac's menu;
- the compiler's own heading or dateline printed in brackets, with a generated "Note on the Text";
- a citation style per collection with a short form; one layout plan that HTML, PDF and Word all draw; two stored JSON text values.

Mockups of it exist as HTML source you can read. They are design sketches, not app code:
`/tmp/claude-0/-home-user-FRUS-Explorer/7afd2999-14be-5996-b04c-68176ebd1f6c/scratchpad/canvas/project/` holding `OptionB.dc.html` (the inspector, Mac), `OptionC.dc.html` (the preview with Adjust, Mac), `PartsPhone.dc.html` (the inspector, iPhone), `Main.dc.html` (the export sheet, iPhone), `Marks.dc.html`, `Citations.dc.html`, `OptionA.dc.html`.

## The owner's ask, verbatim

"I am not satisfied with the Collections feature. I am not able to customize how each document is displayed, yet the interface is very complicated. I want to be able to export a collection very quickly using sensible default templates (the new ones we created last week are good starting points). I also want to be able to fine-tune any aspect of the collection, including overriding headings, datelines, and other labels derived from the source TEI with my own headings and labels, marked appropriately. I want to be able to choose what citation format to use if the contents are listed that way. Consider other authorial capabilities along these lines as well. Consider what kinds of user interface alternatives might help me preserve clean simplicity for default situations and also wield powerful customizability for other times."

## Your job

Attack the hybrid. Find where, built as written, it would:
- fail one of the owner's asks;
- be as complicated as what it replaces, or more;
- mislead or strand a person;
- lose or corrupt their work;
- say something false, ambiguous or unmarked to a reader of an export;
- be impossible, or far costlier than the record claims, to build on a platform the app ships on;
- rest on a claim in the record that the code contradicts.

You are not asked to redesign it or to be balanced. Agreement is of no use; an unsupported objection is of no use either. The record's §2 describes today's app: treat it as its author's reading, not as fact, and where a finding of yours depends on a §2 statement, re-read the line it cites.

## Evidence standard

Every finding rests on something you re-read yourself in this session:
- a `file:line` in the current tree (the app is under `FRUSExplorer/`, shared code under `FRUSCoreKit/`, tests under `FRUSExplorerTests/` and `FRUSExplorerUITests/`, the project's rules in `CLAUDE.md`, both manuals under `Docs/`);
- a section of the design record;
- or a line of a mockup file.

A claim about Apple's Human Interface Guidelines, WCAG or how a platform behaves that you could not fetch and read today is marked "from memory, not fetched". A claim only a running app could settle is marked NEEDS A RUN, with the check that would settle it.

## Severity

- **S1:** built as written, the design fails one of the owner's asks; loses or corrupts a person's work; states something false or unmarked to a reader of an export; or cannot be built as described on a platform the app ships on.
- **S2:** a first-time user is misled, stuck or led into an error on a common task; a claim in the record is false or materially overstated; a clear accessibility or HIG rule is broken on a primary surface; or a cost the record leaves out would materially change a lane's size.
- **S3:** real but secondary.

## Do not raise

- A weakness the record already states (its "Against it" lists, its §2, its "Not done"), unless you show it is worse than stated.
- What the earlier program ruled out and this design keeps ruled out (record §3.6).
- A preference of taste with no consequence for a person or for the build.

## Your report (your final message: plain text, no preamble, no closing remarks)

At most TEN findings, strongest first. For each:

```
ID: <PREFIX>-n
Severity: S1 | S2 | S3
Claim: one sentence, falsifiable.
What a person meets: the concrete scenario, and on which platform.
Evidence: file:line, record §, or mockup line, each re-read; quote the line where it matters.
Refutation: what would refute it, and whether you checked.
Direction: one sentence, not a redesign.
```

Then **Attacked and held**: up to five things you tried to break and could not, one line each with its evidence.
Then **Not read**: what you did not get to.
