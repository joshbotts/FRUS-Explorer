# Editors' Annotations follow-ups: a local session plan (2026-11-08)

Status: IN PROGRESS — Lane 0b is built and Lane 0's unit checks are run (2026-11-08, on
`claude/editor-annotation-axis-revisions-54aede`, opened as #1873); Lane 0's UI checks and
Lanes 1 and 2 remain, for one development session run locally on the Mac. Lane 0b, the pre-1925
correction, ships in 1.0 (the plan of record's decision 120 and L10); the other lanes are not
scheduled against 1.0.

The design this amends is `Editors-Annotations-Design-2026-11-06.md`. Its measurements are in
`editors-annotations/`. This plan takes four decisions the owner made on 2026-11-08, and one of 2026-11-09, and turns them
into lanes:

1. **Printed aids** becomes **Front and back matter**. *Copy only.* Done on
   `claude/jolly-pascal-dhlwjj` (`ba3ef70`); still to verify on the Mac.
2. **Excisions marked** becomes **Redactions marked as not declassified**, and its user-facing
   language changes with it. *Copy only.* Done in the same commit; still to verify.
3. A new layer, **Marked editorial omissions**. *A kit category, a generator rule and a regenerated
   index.*
4. A back-of-volume index's **"See" links** scroll within the index. *A kit change in the parser, the
   reader's link parse and the reader's scripts.*
5. **The pre-1925 correction** (2026-11-09). *Copy only; ships in 1.0.* Two shipped texts say the
   editors marked nothing before the 1925 order; the Office's history and the TEI say they marked an
   omission with a row of asterisks. Lane 0b.

Every heavy job goes through `Scripts/heavy.sh`, one at a time (CLAUDE.md, *Build & Test Commands*).
Run long jobs in the background and reuse one worktree's DerivedData.

Version history:
  1.0 — 2026-11-08: written from the cloud session that made the copy changes and measured the
        omission markers
  1.1 — 2026-11-08: the owner's three decisions recorded: infra/supra notes count as omissions, the
        Redactions page names the 1991 statute in place of an era, and the onboarding page says
        "redactions"
  1.2 — 2026-11-08: the owner's rule that editors marked nothing before the 1925 order. The new
        layer counts only volumes published from 1925 (the generator stores each volume's
        publication year), and its copy says so; the onboarding text and the Redactions practice
        paragraph now name the order
  1.3 — 2026-11-09: the owner's correction, reversing 1.2's rule: before the 1925 order the editors
        marked an omission with a row of asterisks (the Office's history, chs. 2 and 4; the TEI). Lane
        0b corrects the two shipped texts and ships in 1.0 (plan of record, decision 120); Lane 1's
        gate keeps 1925 for the sweep's own reason, and its two strings are re-worded
  1.4 — 2026-11-08: Lane 0b built, with Lane 0's unit checks, on the Mac; the clean build found one
        strict-concurrency warning in `AnnotationsAxisTests` (lane D's), fixed by making
        `PeopleTaggingCaption.text(index:locale:)` nonisolated; Lane 0's UI checks are still owed
  1.5 — 2026-11-08: Lane 1 measured and built on the Mac (its section's *Measured* and *Built*
        passages): the rule took two clauses from the sweep's residue, the 1925 gate is the kit's,
        and the file is schema version 2; Lane 2's corpus measurement, for its *Measure first*

---

## Lane 0. Verify the copy commit (decisions 1 and 2)

**Already on the branch** (`ba3ef70`, 7 files):
- **Front and back matter:** the label; the practice text ("…prints front and back matter to help
  readers use it…"); both rules, which now say "section" where they said "aid".
- **Redactions marked as not declassified:** the label; the rule ("…marks a redaction as not
  declassified: text in it, or the whole document."); the practice paragraph, which dates the
  bracketed marking to the 1991 statute and says why earlier volumes' ellipses are not counted; and a
  volume row's "N documents with redactions marked".
- **Docs and tests:** both user manuals, the matching blocks in
  `Docs/EditableContent/07-Search-and-Browse.md`, one Amendment-Log bullet, and two unit-test
  expectations (`VolumeAnnotationsPresentationTests` line 71, `AnnotationsAxisTests` line 197).
- **Unchanged:** the identifiers (`printedAids`, `excisions`, the `annotation:…` axis keys), so
  saved scopes still open. The count is unchanged too: the scanner's `not\s+declassified` already
  matched both a gap in the text and a withheld document's source note.

**Not built in the cloud session**, which had no Swift toolchain. On the Mac:

```bash
Scripts/heavy.sh xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerTests/AnnotationsAxisTests \
  -only-testing FRUSExplorerTests/VolumeAnnotationsPresentationTests \
  -only-testing FRUSExplorerTests/EditableContentKeyTests
```

Read the test count back. Then run `VolumeAnnotationsSectionTests` and `AnnotationsAxisBrowseTests`
on the runbook's devices (iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`) and look at the kept
screenshots:
- Is the longer label, "Redactions marked as not declassified", still on one line in the volume
  page's row?
- Does it fit as the layer page's title on the iPhone?
- Does the new practice paragraph read well at AX3?

If the label wraps badly in either place, raise it with the owner. Do not shorten it unasked.

**Run on the Mac on 2026-11-08, with Lane 0b, on `claude/editor-annotation-axis-revisions-54aede`.**
- The three unit suites, run without rebuilding after a clean `build-for-testing` of the
  `FRUSExplorer` scheme on an iPhone 17 under iOS 27.0 (`80CF0F18`): 38 tests in 3 suites, all
  passed. The whole unit target after them: 7,909 tests, 7,872 passed, none failed, 37 skipped (the
  environment gates). So #1868's copy and its two test expectations hold, and the page-3 range holds.
- The clean build printed one source warning, in the test target and not from #1868: lane D's
  `AnnotationsAxisTests.shippedCellAndCaption` (lines 238–239) calls
  `PeopleTaggingCaption.text(index:locale:)` from a synchronous nonisolated test, and the static
  method was main-actor-isolated with its `View`. The method is now `nonisolated`, a value over the
  file, and the rebuild of the edited files printed no warning. Lane D's entry says no build warned
  in its files; the warning is in one of them, so that build was not a clean one.
- **Not run, and still owed:** `VolumeAnnotationsSectionTests` and `AnnotationsAxisBrowseTests` on
  the runbook's devices, and the three looks at the kept screenshots above (the label on one line in
  the row, the title on the iPhone, the practice paragraph at AX3).

**Decided by the owner on 2026-11-08, and done on the branch in the second copy commit:**
- *The era sentence on Redactions.* "Standard in the volumes covering 1964 on" went by the years a
  volume covers, but the practice changed with the year of publication. Measured over the 553
  volumes, by publication year: 3/49 published in the 1970s, 3/21 in 1980–84, 4/33 in 1985–89, 67/73
  in the 1990s and 133/147 from 2000. The layer's page now says instead (`AnnotationsAxis.redactionsStandardLine`,
  key `browser.annotations.standard.redactions`): "Volumes produced after the passage of the 1991
  statute include explicit editorial annotation of redactions made during the declassification
  process." The spoken row reads the same sentence. The practice paragraph no longer opens with the
  date, so the two do not repeat each other. The strip still shades by coverage era. Check on the
  device that the sentence and the strip read well together.
- *Nothing marked before 1925* (the owner's rule, a later decision the same day). The onboarding
  text now opens "Before Secretary of State Frank Kellogg's 1925 order, FRUS editors did not mark
  excisions or redactions. Beginning with that order, …". It said "Before the 1920s" until then. The
  Redactions practice paragraph says "From Secretary Kellogg's 1925 order until the 1991 statute,
  volumes marked an omission with an ellipsis, … Volumes published before the 1925 order did not mark
  omissions at all." It said "Before the 1991 statute, volumes marked every omission" until then,
  which implied every earlier volume. **Reversed on 2026-11-09:** both sentences were wrong the other
  way, and Lane 0b corrects them.
- *The onboarding page's section* (`IndexingEducationView.swift`, mirrored in
  `Docs/EditableContent/02-Research-Guide.md`) is now titled **Excisions and Redactions**. It says
  "redaction" where an omission came from declassification and keeps "excision" for the editors' own.
  Each paragraph stays on its one line, so the page's `lines: 802–851` range still holds; confirm
  with `EditableContentKeyTests`.

---

## Lane 0b. The pre-1925 correction (the owner's decision of 2026-11-09; ships in 1.0)

**What is wrong.** Two shipped texts say that before Secretary Kellogg's 1925 order the editors did
not mark omissions:
- the Redactions layer's practice paragraph, `browser.annotations.practice.excisions`
  (`FRUSExplorer/Browser/AnnotationsAxis.swift`, line 269; mirrored in
  `Docs/EditableContent/07-Search-and-Browse.md` §20): "… Volumes published before the 1925 order did
  not mark omissions at all.";
- the Research Guide's *Excisions and Redactions* paragraph
  (`FRUSExplorer/Onboarding/IndexingEducationView.swift`, line 840; mirrored in
  `Docs/EditableContent/02-Research-Guide.md`, page 3, the ranged block `lines: 802–851`): "Before
  Secretary of State Frank Kellogg's 1925 order, FRUS editors did not mark excisions or redactions.
  Beginning with that order, FRUS historians added ellipses (...) …".

Both entered the copy as the owner's rule of 2026-11-08 (version 1.2 above). The Office's history of
the series says otherwise: the Civil War volumes "feature lines of asterisks to indicate excised
material" (McAllister, Botts, Cozzens and Marrs, *Toward "Thorough, Accurate, and Reliable"*, 2015,
ch. 2, *Excisions, Excisions*), and the Contemporaneous compilers "took great care to identify the
lacunae with ellipses, asterisks, dashes, or similar markings" (ch. 4, *FRUS at War: The 1898
Volume*). What the 1925 order added was a written policy and one uniform mark, the ellipsis. The TEI
agrees (HistoryAtState/frus, read 2026-11-09): `frus1861.xml` carries 212 asterisk runs, most as
`<p rend="center">* * * * * * * * * *</p>` and some inline at the end of a sentence, and
`frus1887.xml` 254; neither has an ellipsis or a `<gap>`. `frus1932v01.xml` (published 1948) has no
asterisk run, 112 spaced ellipses, 15 ellipsis characters and 3 `<gap>` elements.
`Planning/FRUS-History-Feature-Assessment-2026-11-09.md` §1 has the finding, and its §2.4 the census
that would follow.

**The change** (copy only: no identifier, count, index version or model moves). The replacements are
proposed; the owner may word them otherwise.
- `browser.annotations.practice.excisions`: replace the last sentence with "Volumes published before
  the 1925 order marked an omission with a row of asterisks, under no written rule and without saying
  whose cut it was; those are not counted here either."
- The Research Guide paragraph: replace its first two sentences with "Before Secretary of State Frank
  Kellogg's 1925 order, FRUS editors marked an excision with a row of asterisks, under no written
  policy and without saying whether the cut was theirs or a reviewer's. Beginning with that order,
  FRUS historians marked omissions uniformly with ellipses (...), but still did not describe how much
  information was withheld or explain whether an omission was an editorial excision or a redaction
  made after an unfavorable declassification decision." The third sentence stays.
- Mirrors: the two EditableContent blocks take the same text, and one Amendment-Log bullet ("changed
  at the owner's request (2026-11-09): …") says that it reverses the 2026-11-08 third change.
- The manuals carry neither sentence (checked 2026-11-09: no "1925" in either), so they do not change.

**Checks.** `EditableContentKeyTests` (the page-3 block's `lines:` range holds while each paragraph
stays on one line), `AnnotationsAxisTests` and `VolumeAnnotationsPresentationTests` (neither pins the
sentences; they pin labels and details), then the unit target and the Mac build as for any copy
change. No capture to retake: `browse-annotations` and `volume-annotations` show the axis and a
volume's page, not the layer's practice paragraph, and no capture shows the Research Guide's page 3.

**Built on 2026-11-08**, on `claude/editor-annotation-axis-revisions-54aede`, from `v2` at `39c5019f`,
on the owner's "Yes, do Lane 0b", and opened as #1873. The two strings and their two mirrors take the proposed wording
word for word, each paragraph on its one line; the Amendment-Log's bullet says the change reverses
the third change of 2026-11-08. Checked: `EditableContentKeyTests`, `AnnotationsAxisTests` and
`VolumeAnnotationsPresentationTests`, 38 tests passed; the unit target, 7,909 tests, 7,872 passed,
none failed, 37 skipped; `FRUSExplorerMac` (the AppStore configuration) built with only the two known
warning residues. The clean `build-for-testing` before them is Lane 0's, above. The owner may still
word either sentence otherwise: a change is two Swift lines and their two mirrors.

**What it changes in Lane 1.** Lane 1's gate, counting the bracketed layer only from 1925, stays, but
for a different reason, written into its section below: the bracketed description of what was left
out is the post-1925 form, and the pre-1925 brackets the sweep found stand in for duplicate text,
formalities and gaps in a telegram as received; before 1925 an omission was marked with a row of
asterisks, which the bracket scanner does not read. Lane 1's two strings that repeated the rule are
re-worded below. **Open for the owner:** whether to count the asterisk rows themselves, as a third
form of marked omission beside the bracketed note and the redaction mark. The assessment's §2.4
proposes it as a census for the plan after 1.0; nothing in this lane depends on the answer.

---

## Lane 1. A new layer: Marked editorial omissions (decision 3)

### What the corpus shows

Swept over all 553 catalogue volumes at corpus `6170e4b32`, a document at a time
(`div[@type="document"]`). The sweep agrees with the shipped index on redactions: 210 volumes each.

| Published | to 1899 | 1900–19 | 1920–39 | 1940–49 | 1950–59 | 1960–69 | 1970–79 | 1980–84 | 1985–89 | 1990–99 | 2000 on |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Volumes | 51 | 20 | 33 | 42 | 46 | 38 | 49 | 21 | 33 | 73 | 147 |
| `[Here follows …]` | 17 | 8 | 31 | 34 | 44 | 38 | 49 | 21 | 32 | 72 | 26 |
| `[… omitted …]`, raw | 10 | 4 | 32 | 36 | 44 | 37 | 38 | 10 | 14 | 25 | 128 |
| Redactions marked | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 3 | 4 | 67 | 133 |

- **Documents:** `[Here follows …]` appears in 7,437 documents in 372 volumes. The raw `omitted`
  pattern appears in at most 5,601 documents in 378 volumes. That figure is inflated by the noise
  described under *The rule*.
- **The editors marked their own omissions in brackets from the 1920s on.** Around 2000 the wording
  moved from "[Here follows …]" to "[Omitted here is …]".
- **The pre-statute bare ellipsis is out of reach.** It can be either an omission or a redaction, and
  the text does not say which. This layer does not count it, and its copy says so.

### The rule (the generator's scanner)

A document carries the layer when its text holds a bracketed span `[…]` that matches one of these:

1. `^\[\s*Here\s+follows?\b` — "[Here follows discussion of …]", "[Here follow the names of …]".
2. `^\[\s*Omitted\s+(here|from|are|is)\b` — "[Omitted here is the Table of Contents.]".
3. `\b(has|have)\s+been\s+omitted\b` or `\bwhich\s+(is|are)\s+omitted\b` anywhere in the bracket —
   "[The next three paragraphs, which have been omitted, are …]".

A bracket that matches none of these does not count. The cases to exclude:

- **A bracket that says `not declassified`.** That is the Redactions layer, never this one.
- **The editors' remarks on a garbled original:** "[apparent omission]", "[omission?]", "[omission in
  the original]", "[sic]". They sit in the 1920s–40s telegrams and say that the source as received
  had a gap, not that the editors left something out. Patterns 1–3 never match them. Pin them as
  negative fixtures.
- **A bracket inside a footnote, a source note or an editorial note.** Read only the document's own
  text, not its `<note>` children. Check this against the scanner's existing text walk
  (`TEIAnnotationScanner.swift`, which keeps a document's text for the redaction test), and decide
  whether the redaction test should keep reading notes. It must, for a withheld document's source
  note.

**"Printed infra / supra / elsewhere" counts (the owner's decision of 2026-11-08).** Some brackets
stand in for text the volume prints in another place: "[Here follows text of the aide-mémoire of
May 9, 1938, … printed infra.]". They are omissions in place and count. The rule needs no
exception for them, and a fixture pins one as a positive.

**Only volumes published from 1925 count.** The reason was the owner's rule of 2026-11-08 that the
editors marked nothing before Secretary Kellogg's 1925 order; Lane 0b reverses that rule
(2026-11-09), and the gate stays for the reason the sweep itself gives: the bracketed description is
the post-1925 form, and before it an omission was marked with a row of asterisks, which this scanner
does not read. The patterns do match volumes published earlier: the sweep found `[Here follows …]` in 28 of the 74 volumes published
before 1925, and the raw `omitted` pattern in 17. Sampled at `6170e4b32`:
- frus1868p2 (published 1869): "[Here follow the signatures.]"
- frus1878: "[The telegram here is defective, … being manifestly omitted.]"
- frus1914 (published 1922): "[Here follows the text of the memorandum, printed hereafter as
  inclosure with …]"
- frus1915 (published 1924): "[The paragraphs here omitted are identical with those in the letter to
  the Governor of Massachusetts.]" and "[Here follows a long digression intended to show …]"

They stand in for duplicate text, formalities and gaps in a telegram as received, not for the marked
excisions the order required. So:
- **Generator:** read each volume's `teiHeader` publication date (`date[@type="publication-date"]`;
  all 553 volumes have one) and count the layer only from 1925. Store the year in the file
  (`publicationYear`, a per-volume field), so that the app can say why an earlier volume is not
  counted. That changes the file's shape, so bump `schemaVersion` and give the decoder a fixture of
  each shape.
- **App:** for a volume published before 1925, the layer's drills put it under "Volumes without it"
  with a note: "Published before the 1925 order, when the editors marked an omission with a row of
  asterisks, not a bracketed note."
- **Fixtures:** a pre-1925 volume with `[Here follows …]` that is not counted, and the same text in
  a 1925 volume that is.
- **Check the same gate for Redactions.** The sweep found no "not declassified" in any volume
  published before the 1970s, so the gate changes no count there. Its copy says what those volumes
  marked instead (Lane 0b).

**Measure first.** Before writing the scanner, run the patterns over the Mac's corpus clone
(`~/Development/frus/volumes`, at `6170e4b32`). A stdlib Python script in the scratchpad is enough;
`Planning/editors-annotations/inventory.py` is the model. Write a per-era table like the one above,
plus 40 random hits per pattern, read by eye. Confirm the share of false positives before the rule
is fixed. Commit the script and its output under `Planning/editors-annotations/` beside the
existing extracts, and add a dated amendment to that folder's README.

**Measured on 2026-11-08** (`Planning/editors-annotations/omission_markers.py`, its tables and
samples in `omission-markers.out`, per volume in `omission-markers.json`; the README's amendment of
the same day has the detail). Each document's own text, its notes left out and a line break read
as a space; the brackets read whole, nesting followed.

| Published | to 1899 | 1900–19 | 1920–39 | 1940–49 | 1950–59 | 1960–69 | 1970–79 | 1980–84 | 1985–89 | 1990–99 | 2000 on | all |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Volumes | 51 | 20 | 33 | 42 | 46 | 38 | 49 | 21 | 33 | 73 | 147 | 553 |
| … with `[Here follows …]` | 16 | 7 | 31 | 34 | 44 | 38 | 49 | 21 | 32 | 72 | 26 | 370 |
| … with `[Omitted here …]` | 0 | 1 | 0 | 0 | 0 | 0 | 4 | 0 | 0 | 1 | 121 | 127 |
| … with `… has been omitted …` | 0 | 0 | 2 | 5 | 16 | 12 | 5 | 0 | 0 | 0 | 1 | 41 |
| … with the layer | 16 | 7 | 31 | 34 | 44 | 38 | 49 | 21 | 32 | 73 | 137 | 482 |
| Documents with the layer | 24 | 17 | 235 | 330 | 444 | 914 | 1,463 | 552 | 745 | 2,365 | 4,353 | 11,442 |
| Redactions marked | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 3 | 4 | 67 | 133 | 210 |

- **The first run used the three patterns above, case-blind.** Its 40 samples a pattern, read by eye,
  held no false positive: every `[Here follows …]` and `[Omitted here …]` describes text the editors
  left out, and so do the 18 brackets the third pattern found. Its residue held two unambiguous
  phrasings the patterns missed, every sample an omission: "… here omitted …" ("[The paragraph here
  omitted summarized telegram 2385 …]", 41 documents, 1920s–1970s) and "Omitted here is …" after a
  stage direction in a tape transcript ("[Agnew left at 10:35 a.m. Omitted here is discussion
  unrelated to …]", 6 documents). **The rule as fixed takes both:** pattern 2 also matches
  `\bOmitted\s+here\s+(is|are)\b` anywhere in the bracket, and pattern 3 also `\bhere\s+omitted\b`.
  Patterns 1 and 2 are case-sensitive, as written above: 27 documents open a bracket in lower case,
  mid-sentence ("as follows: [here follows the text of the treaty in full]"), and a case-blind
  pattern 2 took "[omitted from?]", an editor's query on the original. The table is the rule as fixed.
- **Excluded, as the rule says:** 12 documents whose bracket joins an omission phrase to "not
  declassified" ("[Here follow 6-1/2 pages of source text scheduled for inclusion in the Supplement but
  not declassified.]"), which the Redactions layer counts; 8 whose only such bracket sits in a
  footnote ("[Here follows a footnote in the source text with the dissenting view …]"); 3,624 with
  the editors' remark on a garbled original. The 426 brackets that say "printed infra", "supra" or
  "elsewhere" count, as decided.
- **Left out by the rule, for the owner to see:** 125 documents with a bracket that says "not
  printed" and matches no pattern ("[Chinese text not printed.]", "[This annex is not printed. It is
  the same as annex I-a, supra …]"), 1900s–1970s; the short forms "[Letter omitted.]", "[Article
  omitted.]" and "[The first three paragraphs are omitted since …]" among the 1,641 brackets that hold
  an omission word and match nothing; 3 "[… was not transcribed.]" in tape transcripts; and the 27
  lower-case openers. None of them changes a volume's verdict that this sweep could find: every
  volume with one also carries a pattern.
- **The gate:** 74 volumes were published before 1925, and 26 of them carry a bracket (77
  documents, 16 in `frus1914` and 11 in `frus1915`), so 456 volumes carry the layer. 23 volumes
  published from 1925 carry none.
- **Redactions reproduce the shipped index:** 210 volumes, 8,166 documents, and reading a line break
  as a space changes no volume's count, so the scanner's own-text walk could take it safely.
- **The cloud sweep's `[Here follows …]` figures** (372 volumes, 7,437 documents) differ from this
  run's 370 and 7,383 by the brackets inside notes, those joined to "not declassified", and the 27
  lower-case openers, which this rule reads differently.

### Code

**FRUSCoreKit** (Foundation only; shared code, so rules 1–4 of *Web edition* apply):
- `FRUSCoreKit/Browser/VolumeAnnotations.swift`: add `AnnotationCategory.editorialOmissions`, in
  family `.provenance` next to `.excisions`, counted "when one document does" (the same group as
  `.excisions` in that file's two threshold switches).
- The decoder reads the file's `fields` array by name. Confirm that a file without the new field
  decodes with a zero for it, and add a `FRUSCoreKitTests` fixture of the old shape that pins this.
- Bump the file's `schemaVersion` if the decoder needs it to tell the shapes apart.

**Generator** (`VolumeAnnotationsIndexGeneratorCore`):
- `TEIAnnotationScanner.swift`: an `editorialOmissions` feature, set by the rule above.
- `VolumeAnnotationsAssembly.swift`: `add(.editorialOmissions, …)`, beside line 75's
  `add(.excisions, …)`.
- `VolumeAnnotationsIndexGeneratorTests`:
  - a fixture document for each positive pattern;
  - one each for "[apparent omission]", "[omission?]", a `not declassified` bracket and a bracket
    inside a footnote;
  - an infra/supra case, as a positive.

**App** (`FRUSExplorer/Browser/`):
- `AnnotationLayer`: a new case `editorialOmissions`, placed after `.excisions` in the "Where it
  came from" group. That makes 16 layers. Update the doc comment that says fifteen, and any test that
  counts them (`VolumeAnnotationsPresentationTests` line 63's id list).
- The case's properties:

  | Property | Value |
  |---|---|
  | `symbol` | `text.badge.minus` (or `ellipsis.rectangle`; check both render at the row's size) |
  | `category` | `.editorialOmissions` |
  | `appUse` | the shared "none" line |
  | `accessory` | the `"37 docs"` branch |
  | `appLink` | none |

- Copy. New keys only, so no existing EditableContent block moves.

  | Key | Text |
  |---|---|
  | `browser.volume.annotations.editorialOmissions` | Marked editorial omissions |
  | `browser.annotations.rule.editorialOmissions` | A volume published from 1925 counts when one of its documents says, in brackets, what the editors left out: "[Here follows …]" or "[Omitted here is …]". |
  | `browser.annotations.note.editorialOmissions.before1925` | Published before the 1925 order, when the editors marked an omission with a row of asterisks, not a bracketed note. |
  | `browser.annotations.practice.editorialOmissions` | Since Secretary Kellogg's 1925 order, where the editors left out part of a document as not relevant to the volume, they could say so in brackets and describe what was omitted. Until the 1991 statute an ellipsis could also mark an omission, the editors' or a redaction, and those are not counted here. Volumes published before the order marked an omission with a row of asterisks, not a bracketed note, and are not counted here. |
  | `browser.volume.annotations.editorialOmissions.one` | %@ document with an editorial omission marked |
  | `browser.volume.annotations.editorialOmissions.many` | %@ documents with editorial omissions marked |

- `VolumeAnnotationsPresentation.Labels` and the row detail switch: the new label and detail. The
  layer is not "standard" in any era by the one-document rule, so it never appears under *Not in
  this volume*. Confirm that against `standardLayers`, or whatever decides that list.

### Regenerate

Read `VolumeAnnotationsIndexGenerator`'s entry in `Planning/Generators-Runbook.md` first. Then run
it with the same `CORPUS_COMMIT=6170e4b32` as the shipped file, so that only the new field moves:

```bash
CORPUS_COMMIT=6170e4b32 VOLUMES_DIR=~/Development/frus/volumes \
  Scripts/heavy.sh swift run -c release VolumeAnnotationsIndexGenerator
```

(Add `INDEX_DB=` if a full index at the current version is at hand. Otherwise it builds one.)

Then:
- **Diff the regenerated file against the shipped one.** Every field but the new one must be byte-for-byte
  the same. If anything else moved, stop and find out why before going on.
- **Check the new field's totals** against the lane's own measurement (above, refined).
- **Update the runbook entry** (inputs, figures, date) and the file's row in
  `BundledArtifactProvenance.table` (figures and date). It is a same-name refresh, so no
  `xcodegen generate` is needed.

### Tests and runs

1. `Scripts/heavy.sh swift build --target FRUSCoreKit`
2. `Scripts/heavy.sh swift test`. Read the per-target counts back. `VolumeAnnotationsIndexGeneratorTests`
   and `FRUSCoreKitTests` must both have run.
3. The unit target, with `AnnotationsAxisTests`, `VolumeAnnotationsPresentationTests`,
   `BundledArtifactProvenanceTests` and `EditableContentKeyTests` among the suites run.
4. A Mac build (`FRUSExplorerMac`).
5. `VolumeAnnotationsSectionTests` and `AnnotationsAxisBrowseTests` on their runbook devices. Their
   counts come from the shipped file, so expect no change. `AnnotationsAxisBrowseTests` may count
   rows; if so, add one.

### Docs

- **Both user manuals:** add the layer to the "Where it came from" lists (iOS manual lines 483 and
  448; macOS manual line 307).
- **`Docs/EditableContent/07-Search-and-Browse.md`:** §19 and §20 gain the five new keys' blocks, plus
  one Amendment-Log bullet.
- **The design doc:** a dated amendment noting the 16th layer, and a pointer from §5's table.

### Built on 2026-11-08

Where the build departs from the text above, and what it measured.

- **The 1925 gate is the kit's, not the generator's.** The generator counts every volume's bracketed
  omissions and stores the volume's `publicationYear`; `VolumeAnnotations.carries(_:)` returns
  `false` for the layer in a volume published before `VolumeAnnotations.editorialOmissionsFromYear`
  (1925), whatever its count. The design's §4 rule, counts and never verdicts, is the reason: the
  gate can move without a regeneration, and a drill's row can say both that a volume is kept out
  and how many brackets it holds ("16 docs" beside the note, for `frus1914`). A volume with no year
  is not gated; every catalogue volume has one.
- **The rule took two clauses from the measurement** (above): pattern 2 also matches "Omitted here
  is …" after a stage direction, and pattern 3 also "… here omitted …". Patterns 1 and 2 are
  case-sensitive, as written. The rule lives in the generator core, `EditorialOmissionMarkers`, as
  `NSRegularExpression` statics: a `Regex` literal in a `static let` is not `Sendable` under Swift 6,
  and the kit's shared patterns are `NSRegularExpression`s for the same reason.
- **The scanner keeps two texts for each document:** every character, for the redaction test (a
  withheld document's mark sits in its source note), and the document's own text, every `note`
  left out and a line break read as a space, for the omission test. The redaction test was left as
  it was; the sweep showed a space at `<lb/>` changes no volume's redaction count.
- **Schema version 2.** Each volume's row gains a fourth element, the publication year (`null`
  where a header prints none); a three-element row still decodes, with no year and no gate, and the
  kit's suite holds a fixture of each shape. `fields` gains `editorialOmissions` after `excisions`.
- **The symbol is `text.badge.minus`,** 21 pt wide at the 17 pt body against `person.3`'s 36, so
  the symbols' column does not move.
- **Regenerated** at `CORPUS_COMMIT=6170e4b32`, index version 74, with `INDEX_DB` on the index the
  version-74 run kept (3 min 2 s with the release build). Against the shipped file every other
  field is equal volume for volume, and the new count equals the sweep's in all 553 volumes
  (`diff_annotations.py`, in the pull request): 456 volumes carry the layer (11,365 documents), 26
  published before 1925 are counted and not carried (77 documents), 11,442 documents in all; onset
  1920–31 by the eras the volumes cover; 71,939 bytes. `frus1969-76v17` has 32, `frus1961-63v06` 2,
  `frus1914` 16.
- **Copy and docs:** the six keys above, word for word, with their EditableContent blocks and one
  Amendment-Log bullet; both manuals' *Where it came from* lists; the design's header, §5.2 table
  and §11; the measurements README; the runbook entry; the provenance table's comment.
- **Runs** (each heavy job through `Scripts/heavy.sh`, Xcode 27.2): `swift build --target
  FRUSCoreKit` clean; `swift test` exit 0, 39 runs all passed, `FRUSCoreKitTests` 1,779 tests in
  229 suites (three new) and `VolumeAnnotationsIndexGeneratorTests` 18; a clean `build-for-testing`
  of the `FRUSExplorer` scheme (iPhone 17, iOS 27.0, from empty DerivedData) with only the two known
  warning residues; the unit target, 7,914 tests, 7,877 passed, none failed, 37 skipped (the
  environment gates); `FRUSExplorerMac` (AppStore) built with
  the same residues; `VolumeAnnotationsSectionTests` and `AnnotationsAxisBrowseTests` together on
  the iPhone 17 (`80CF0F18`, 7 tests, 6 passed, 1 skipped, the matrix) and the iPad Pro 13-inch (M5)
  (`9AB3A0C9`, 7 of 7), 145 and 116 s. The Mac's half was built and not walked.

---

## Lane 2. "See" links in a back-of-volume index scroll within the index (decision 4)

### What happens now

Read from the code, not yet seen on a device. Confirm it first on the simulator: open 1932 IV's
Index and tap "China" in "Aviation. *See under* China".

- An entry's cross-reference is `<ref target="#in2">`, and its target is an `<item xml:id="in2">` in
  the same index division.
- `FRUSURLScheme.resolveCrossRefTarget` (`FRUSCoreKit/TEI/FRUSURLScheme.swift`) has no rule for
  `in…`. It returns `.document(documentId: "in2")`.
- `DocumentView.navigateToCrossRef` (and `MacDocumentView`'s equivalent at line ~1170) pushes a
  reader for document `in2`. That fails with "Document 'in2' was not found in the volume."
- The AST cannot carry the id even if the reader wanted it: `FRUSASTNode.listItem([FRUSASTNode])`
  holds no `xml:id`, so the serializer writes no `id=` for an index item.
- In the five volumes checked: 1932 IV has 459 such refs and 102 item ids; 1955–57 III has 30;
  1969–76 XVII has 66 refs and 37 ids. The cross-reference rankings already exclude `in[0-9]*`
  (`CrossReferenceStore.documentTargetPredicate`), so the indexer stores these refs.

### Measure first

Over the Mac's corpus clone, record:
- every `<ref>` whose target is `#in\d+`, and whether each sits inside an index division;
- whether its target id exists in the same volume, and in the same division;
- the volumes that have them;
- every non-item element whose `xml:id` matches `in\d+`, if there are any;
- **whether any `div[@type="document"]` has an `xml:id` beginning `in` followed by a digit.** This
  decides whether a prefix rule is safe. The figure to beat is #988's "captures 0 of 314,571".

Add the counts to this plan before coding.

### Code

1. **AST (kit).** Give an index item its id.
   - *Preferred:* `case listItem(id: String?, children: [FRUSASTNode])`, set from the item's
     `xml:id`.
   - *Alternative:* if changing the case's shape touches too many switches, add the id only where the
     list's `type` or its division is an index.

   The parser is `FRUSDocumentParser.swift`. Check whether its existing list-depth state
   (`indexListDepth`) helps.

   *Index version:* none should be needed, because the index is not in FTS. Confirm that
   `renderingVersion`, `body_hash` and stored highlights do not move: an `id=` attribute adds no flat
   text, but prove it with the existing parity suites, not by argument.
2. **Serializer (kit).** `FRUSRenderNodeHTMLSerializer` writes `id="ix-<escaped id>"` on an index
   item's `<li>`. The prefix keeps it from colliding with `fn-`/`fnote-` and with document anchors.
3. **Link parse (kit).** Add `CrossRefDestination.indexEntry(volumeId: String?, anchor: String)`,
   returned for an anchor that matches `in\d+` once the measurement shows no document id of that
   form. If it shows any, make the rule conditional on the reading context instead: pass whether the
   page is an index into the resolver.
   - It is a public enum, so the web edition's exhaustive switches must follow (CLAUDE.md: do not
     hold back; the web side follows).
   - `ReaderLinkTests`' table needs rows for `#in2`, and for `frus1932v04#in2` from outside the
     volume.
   - `CrossRefKit` is a mirror, not shared source. Add the branch there too, or record the drift in
     its doc comment as the other three are.
4. **Reader (app, both platforms).**
   - On `.indexEntry` in the same volume, with the page on screen showing that volume's index, do not
     push. Scroll the web view to `#ix-<anchor>` and briefly highlight the entry. Copy the pattern of
     #988's same-document footnote reveal (`revealedFootnoteAnchor` and `FootnoteLanding`).
   - On `.indexEntry` from elsewhere (a later volume's index citing an earlier index, if the
     measurement finds any), open that volume's Index section and land on the entry.
   - A small kit script can do the landing (`FootnoteLanding` is the model). Adding it to
     `ReaderAnnotationScripts` or to the page template changes pinned bytes, so re-take the pins in
     `ReaderAnnotationScriptTests` and, if CSS is added for the highlight, in `ReaderPageTests`, with
     the reason written above them.
   - The highlight's colour must pass the page's contrast gate. Reuse the footnote landing's wash if
     possible.
5. **Tests.**
   - `FRUSCoreKitTests`: the parser keeps an item's id; the serializer writes it; the resolver
     classifies `#in2`.
   - App unit tests: the reader's call for an `in…` ref does not push.
   - A UI test (a new suite, or a case in `TwoPaneDocumentTests`): open 1932 IV's Index, tap a "See"
     link, assert the target entry is on screen and the navigation depth did not change. Run it on
     iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`, and give it a row in
     `Planning/UI-Test-Destinations-Runbook.md` and CLAUDE.md's table. It needs the volume
     downloaded; follow how the existing reader UI suites seed a volume.
6. **Runs.** `swift build --target FRUSCoreKit`, then `swift test`, then the unit target, then the Mac
   build, then the UI suite. All through `Scripts/heavy.sh`.

---

## Order and landing

- **Order:** Lane 0 first. It is cheap, and it confirms the branch builds. Lane 0b next, and before
  R3: it ships in 1.0 (decision 120), on a pull request of its own. Then Lanes 1 and 2, in either
  order; neither is scheduled against 1.0. They touch different kit files, except that both add to
  the kit's suites.
- **Pull requests:** land each lane as its own PR. Lane 1's PR carries the regenerated JSON, its
  runbook and provenance updates, and the corpus measurement.
- **Before each PR:** do a clean `build-for-testing` of the `FRUSExplorer` scheme and check it prints
  zero source warnings.
- **After the session:** add an entry to `Planning/DEVELOPMENT-PLAN.md`. When every lane has landed,
  move this file to `Planning/Completed/`.
