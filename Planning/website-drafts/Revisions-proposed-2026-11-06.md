<!--
  Revisions proposed for the home page and the tour after 2026-11-06's work, all of which ships in
  1.0 (1861) on the owner's word. Each item names its place in Home-draft.md or Tour-draft.md,
  quotes the current text where it replaces something, and gives text ready to paste. Nothing here
  was applied yet when this was written.

  APPLIED 2026-11-06 on the owner's "Apply all": H1, H2 and T1–T6 are in site-src/home.html,
  tour/tour.html and both Markdown copies (T3's figure carries a fourth footnote, and the figures
  row is four columns wide). T7's screens are still owed.
-->

# Proposed revisions after 2026-11-06's work

## What changed in the app today

| Work | What a user sees | PRs |
|---|---|---|
| **Editors’ Annotations** | Every volume's page lists what its editors annotated, in three groups (*Who is named*, *Where it came from*, *How it connects*), with counts. The page ships with the app, so it shows before the volume is downloaded. **Not in this volume** lists the standard layers a volume lacks, and the era each became standard. A new **Editors’ Annotations** axis in Browse shows how many volumes carry each of fifteen layers, and an era strip for each. On iPad and Mac the strips form a matrix whose cells open that era's volumes. | #1859–#1862, #1863 |
| **Who tags people** | The People list and Person Analytics now say "People are tagged in 288 of 553 volumes, and only those volumes' people appear here. In the others, search for the names." Each links to the volumes that tag people. The Research Guide says which eras are tagged. | #1851, #1862 |
| **Classification markings** | Search's rows and Source Explorer now show the classification marking the 1932–1954 volumes print above the dateline. They also show markings a source note prints past its second sentence, which the app missed before (8,865 notes). | #1853, #1857 |
| Index version 74 | A false "prints a list nothing links to" mark is gone from two volumes. Nothing new to describe. | #1863 |
| A note to the Office of the Historian | Not an app change. | #1864 (open) |

Today's work is the clearest match yet for the site's theme, *built on the editors' work*. The app now shows each volume's editorial annotation as a thing in itself, and not only through the tools that read it.

## Home page (Home-draft.md)

**H1. *Built on the editors' work*: add a third paragraph** before the link to the tour:

> Not every volume carries every kind of annotation: the editors' practices changed over 165 years. Every volume's page shows what its editors annotated, even before you download it, and Browse lays out each kind of annotation across the series' eras.

*Why:* this tells a visitor what the app shows about the editors' work, and it sets up the answer to "why can't I find this person?" before they ask it.

**H2. Optional. *Find what you need*: add one sentence:**

> See before you download which volumes tag their people or record their sources.

## Tour (Tour-draft.md)

**T1. Part 0, note B (Classification marking and date line): extend *In the app*.**
Currently: "Chronology and Administrations put each document on the date the editors gave it. Search filters and analytics scope pickers use these dates…"
Add:

> Search results and Source Explorer show the classification marking, whether the volume prints it above the dateline, as here, or in the source note.

*Why:* d127 is one of the 1932–1954 documents whose marking the app showed only in the reader until today. So this specimen is now an example of the change.

**T2. Part 0, note C (People): make "half" a measured figure, and say this volume is unusual.**
Currently: "For half the volumes in the series, the editors tagged the key people named in the text…"
Replace the opening with:

> In 288 of the 553 volumes, standard in those covering 1955 on, the editors tagged the key people named in the text and included a list of persons in the front matter to describe the roles they held: …

Then, after "Here every one of the seven meeting participants is tagged.", add:

> This volume is one of the few covering the years before 1951 whose editors did so.

Extend *In the app*:

> … and the person filter in Search. Each volume's page says whether its editors tagged its people.

*Check:* #1851's count names "CFM / Germany and Austria" among the 1945–49 exceptions, and frus1947v02 is that volume. All seven people in d127's *Present* line are tagged.

**T3. Part 0, the *Figures* row: add a fourth figure.**

> **288** volumes whose editors tagged the people named in them, standard from the volumes covering 1955 on

*Note:* the app's own figure is 288. My earlier TEI scan counted 287, because the app counts a volume only when its documents link names to its list.

**T4. Step 3 (Choose how to browse among volumes): name the new axis.**
Currently: "Explore the series by subseries, presidency, editor or archive, or open the lists of people and topics."
Replace with:

> Explore the series by subseries, presidency, editor, archive or the editors' annotations, or open the lists of people and topics.

**T5. Step 5 (Follow a person across the series): match the app's own wording in *Limit*.**
Currently: "Roughly half the volumes do not have tagged people."
Replace with:

> People are tagged in 288 of the 553 volumes, and only those volumes' people appear in the People list. The list says so, and links to the volumes that tag people. In the others, search for the names.

**T6. Step 14 (Learn how the series itself has evolved): add the Editors’ Annotations axis.** This step is about how the series changed over time, and the axis shows how the editors' practices did. After the paragraph on publication lag, add:

> **Editors’ Annotations** shows how the editors' own practices changed. For fifteen kinds of annotation, from tagged people and source notes to cross-references and lists of abbreviations, it counts the volumes that carry each one and shades a strip of the eras by how many do, so you can see where a practice began and where it never took hold. Tap a layer to list the volumes with it and without it. On iPad and Mac, the strips form a table whose cells open one era's volumes.

Extend *From the editors*:

> … and the sources its editors cite. The Editors’ Annotations axis counts the annotation in each volume's own text.

**T7. Screens (production notes).**
- **New capture owed for step 14:** the Editors’ Annotations matrix on iPad (Browse ▸ Editors’ Annotations, regular width), or a volume's page with its Editors’ Annotations section. No capture exists in `Docs/screenshots/`. Until there is one, step 14 can keep the publication-lag screen.
- **Step 1's screen (`search.jpg`, *Berlin blockade*):** most of its rows date from 1948–49. Once the device re-indexes at version 74, they will carry classification chips. Retake on 1861 so the screen shows what the build does.
- **Step 3's (`truman.jpg`) and step 5's (`people.jpg`) screens:** check against 1861. The Browse root now has the Editors’ Annotations door below its grid, and the People list now has the 288-volume line, which the sheet in `people.jpg` covers.

## Checked against

- The PR bodies of #1851, #1853, #1857, #1859–#1863, and #1864's title.
- The iOS manual on `v2`, §6.1i, §6.2b and the People section.
- `FRUSExplorer/Resources/volume-annotations-index.json` on `v2`: 553 volumes, index version 74.
