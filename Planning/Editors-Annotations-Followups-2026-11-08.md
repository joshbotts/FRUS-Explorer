# Editors' Annotations follow-ups: a local session plan (2026-11-08)

Status: BUILT, AWAITING MERGE — Lane 0b merged as #1873 (2026-11-08) with Lane 0's unit checks;
Lane 0's UI checks ran in the session that proposed the lanes' build; Lane 1 is #1874 and Lane 2
its own pull request, both opened 2026-11-08 from one development session on the Mac, each with
its *Built* passage below. Once both merge this file moves to `Planning/Completed/`. Lane 0b, the
pre-1925 correction, ships in 1.0 (the plan of record's decision 120 and L10); the other lanes are not
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
  1.6 — 2026-11-08: Lane 2 measured and built on the Mac (its section's *Measured* and *Built*
        passages): no document id has an index entry's shape, so the anchor alone decides; the
        landing is the footnote's script, shared; the "from elsewhere" landing has nothing to serve

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

**Measured on 2026-11-08** over the 553 catalogue volumes at `6170e4b32`
(`Planning/index-see-links/index_refs.py`, its tables in `index-refs.out`, per volume in
`index-refs.json`; one `ElementTree` parse a volume, through `Scripts/heavy.sh`, 43 seconds):
- **No document's `xml:id` begins `in` and a digit:** 0 of 314,616 `div[@type="document"]`, front
  and back matter's included. A whole-anchor rule, `in` and digits, is safe.
- **49,799 references name `#in<digits>`, in 397 volumes, every one inside an index division**
  (a `div` whose `@subtype` is `index` or whose `xml:id` begins `index`, or a `<list type="index">`),
  and none names another volume (`frus…#in…`: 0). So the reader's page holds the entry whenever
  such a reference is tapped, and the "from elsewhere" landing has nothing to serve.
- **49,551 of them resolve to an id in the volume, 49,542 inside the same division as the
  reference**; 9 point into another division of the same volume, and 248 are dangling, their id
  nowhere in the volume (`frus1945-50Intel`, `frus1952-54v08`, `frus1952-54v09p2`, `frus1961-63v10`
  and others, each a handful). The landing script returns `false` for those, and the reader stays
  where it is, which is what the Office's own site does with them.
- **18,809 `<item>`s and 2 `<persName>`s carry an `xml:id` of the form `in<digits>`,** all inside an
  index division; 34,537 items carry some `xml:id` in all (`in…` 18,844, `sub…` 10,672, `main…`
  5,021), so the serializer's `id="ix-…"` goes on every item with one, not on index items alone.
- **The volumes with the most:** `frus1919Parisv09` 792 references, `frus1952-54v03` 588,
  `frus1945Berlinv02` 523, `frus1923v02` 516, `frus1931v02` 509, `frus1932v04` 459 (102 entries with
  ids); `frus1955-57v03` 30; `frus1969-76v17` 66 (37).

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

### Built on 2026-11-08

Where the build departs from the text above, and what it found.

- **Confirmed first on the simulator, through the suite itself.** `IndexSeeLinkTests` was committed
  before the fix, with its fixture (`UITestVolumeSeeder.prepareIndexVolumeIfRequested(in:)`,
  `frus1932v04` as one document and an Index of eighty-odd entries, written on
  `FRUS_UI_TEST_SEED_INDEX_VOLUME=1` and removed by any launch that does not ask, so the four suites
  that count on one downloaded volume never see it), and run on the iPhone 17 (iOS 27.0) against
  that commit: the tap on "China" in "Aviation. *See under* China" opened a reader that said
  "Failed to Load: Document 'in2' was not found in the volume.", the plan's description. The real
  volume was not downloaded to a simulator: the fixture reproduces the markup, and the suite is the
  record.
- **The anchor's shape alone decides.** No document's `xml:id` in 314,616 begins `in` and a digit,
  so `resolveCrossRefTarget` returns `.indexEntry` for a whole anchor of `in` and digits, before the
  footnote branch, and no reading context is passed in. `#in14a` and `#intro` stay documents.
- **The "from elsewhere" landing is not built.** Every one of the 49,799 references sits inside the
  index that holds its entry and none names another volume, so the readers scroll the page on
  screen and push nothing; a reference into another volume's index is logged and left alone.
- **The AST's item keeps its id as the plan preferred,** `listItem(id:children:)`; `ListItemEntry.id`
  and the serializer's `id="ix-…"` follow, on every item with an `xml:id` (34,537 in the corpus, the
  18,809 index entries among them). An attribute adds no flat text, so no index version moved; the
  parity suites that read the serializer's text passed unchanged. `SettledCrossReferenceTarget`
  stores an index reference as collected, as before, so the index's rows did not move either.
- **The landing is the footnote's script, shared.** `IndexEntryLanding` and `FootnoteLanding` run
  one template, `ReaderLanding`, with the element id and the arrival class as its parameters; the
  footnote script's bytes did not move (its pin held), and the page's global records an index entry
  as it records a note, so the figure retry serves both. The stylesheet gains the entry's wash on
  the footnote's animation and its Reduce Motion rule; `ReaderPageTests`' eight heads and the three
  collection HTML pages that embed the stylesheet are re-pinned, each 707 bytes larger, all of them
  that block, with the reason above them.
- **A tap is a new value.** `IndexEntryReveal` carries a tap counter, so a second tap on the same
  entry after the reader has scrolled away lands again, where a footnote is revealed once per
  document and anchor.
- **`CrossRefKit`'s mirror took the branch,** not a drift note: `RefDestination.indexEntry`, citing
  no document, and the parity test reaches seven cases. The edge and flow generators dropped an
  `inN` target at their document check before, so neither output moves.
- **What the first runs taught the suite:** the compilation page's control is "Read Index" (the
  format "Read %@"), not "Read"; the Subseries tile needs `VolumeAnnotationsSectionTests`' three-try
  loop under the tab shell's banner; the launch after a run that ended in the reader restores that
  page, so the suite taps back to Browse's root before its walk and in `tearDown`; an iPad's
  reader page holds three web view elements, so "nothing was pushed" compares the count with
  itself; and WebKit reads a list item's text with its bullet, "• China (see also …", and exposes
  an entry below the fold, so the entry is found by containment and its frame read before and
  after. `IndexEntryLandingWebKitTests`, added when the first fixed runs could not find the entry,
  runs the landing in the offset engine's WebKit harness against the serializer's page and reads
  the scroll and the arrival class back.
- **Runs** (each heavy job through `Scripts/heavy.sh`, Xcode 27.2): `swift build --target
  FRUSCoreKit` clean; `swift test` exit 0, 39 runs all passed, `FRUSCoreKitTests` 1,779 tests in 229
  suites; the control above; a clean `build-for-testing` of the `FRUSExplorer` scheme (iPhone 17,
  iOS 27.0, after `xcodebuild clean`) with only the two known warning residues; the unit target,
  TEST EXECUTE SUCCEEDED, after eighteen EditableContent ranges that the reader and app insertions
  had moved were re-pointed to their keys; `FRUSExplorerMac` (AppStore) built with the same
  residues; `IndexSeeLinkTests`: iPhone 17 (`80CF0F18`, iOS 27.0): 1 test, 1 passed, 41.6 s; iPad Pro 13-inch (M5) (`9AB3A0C9`, iOS 27.0): 1 of 1, 36.8 s. On each the entry read "• China (see also Sino-Japanese dispute), " about 2,450 pt below the reader's frame before the tap and inside it after (y 563 of 116–722 on the iPhone, y 1,168 of 174–1,302 on the iPad), the link it came from 1,670 and 1,044 pt above. The Mac's half was built and not walked.

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
