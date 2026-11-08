# Editors' Annotations follow-ups: a local session plan (2026-11-08)

Status: PLANNED — for one development session run locally on the Mac.

The design this amends is `Editors-Annotations-Design-2026-11-06.md`. Its measurements are in
`editors-annotations/`. This plan takes four decisions the owner made on 2026-11-08 and turns them
into lanes:

1. **Printed aids** becomes **Front and back matter**. *Copy only.* Done on
   `claude/jolly-pascal-dhlwjj` (`ba3ef70`); still to verify on the Mac.
2. **Excisions marked** becomes **Redactions marked as not declassified**, and its user-facing
   language changes with it. *Copy only.* Done in the same commit; still to verify.
3. A new layer, **Marked editorial omissions**. *A kit category, a generator rule and a regenerated
   index.*
4. A back-of-volume index's **"See" links** scroll within the index. *A kit change in the parser, the
   reader's link parse and the reader's scripts.*

Every heavy job goes through `Scripts/heavy.sh`, one at a time (CLAUDE.md, *Build & Test Commands*).
Run long jobs in the background and reuse one worktree's DerivedData.

Version history:
  1.0 — 2026-11-08: written from the cloud session that made the copy changes and measured the
        omission markers
  1.1 — 2026-11-08: the owner's three decisions recorded: infra/supra notes count as omissions, the
        Redactions page names the 1991 statute in place of an era, and the onboarding page says
        "redactions"

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
- *The onboarding page's section* (`IndexingEducationView.swift`, mirrored in
  `Docs/EditableContent/02-Research-Guide.md`) is now titled **Excisions and Redactions**. It says
  "redaction" where an omission came from declassification and keeps "excision" for the editors' own.
  Each paragraph stays on its one line, so the page's `lines: 802–851` range still holds; confirm
  with `EditableContentKeyTests`.

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
  | `browser.annotations.rule.editorialOmissions` | A volume counts when one of its documents says, in brackets, what the editors left out: "[Here follows …]" or "[Omitted here is …]". |
  | `browser.annotations.practice.editorialOmissions` | Where the editors left out part of a document as not relevant to the volume, they said so in brackets and described what was omitted. Before the 1991 statute an ellipsis could also mark an omission, the editors' or a redaction, and those are not counted here. |
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

- **Order:** Lane 0 first. It is cheap, and it confirms the branch builds. Then Lanes 1 and 2, in
  either order. They touch different kit files, except that both add to the kit's suites.
- **Pull requests:** land each lane as its own PR. Lane 1's PR carries the regenerated JSON, its
  runbook and provenance updates, and the corpus measurement.
- **Before each PR:** do a clean `build-for-testing` of the `FRUSExplorer` scheme and check it prints
  zero source warnings.
- **After the session:** add an entry to `Planning/DEVELOPMENT-PLAN.md`. When every lane has landed,
  move this file to `Planning/Completed/`.
