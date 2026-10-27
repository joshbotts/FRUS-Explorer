# Website drafts

**Status: DRAFT, 2026-10-27.** None of these files is published, and none is a copy of record. The
work they wait for is the plan of record's decision 101 (`Plan-Of-Record-2026-10-21.md` §3): the
website's pages are generated, reviewed and revised after 1.0 (1861) is submitted. Until then, §2's
website step stands: at submission the Privacy Policy and Support pages go up as `Docs/` holds them.

## What is here

| File | What it is | What it becomes |
|---|---|---|
| `page-drafts.html` | The review sheet: the home page, and the Support and Privacy drafts as `Scripts/build_website_pages.py` renders them, each shown in a site frame, with the publishing steps, the reading levels and the app's terms. A switch at the top shows the coming-soon or the launch version. | The home page at `frusexplorer.app/`, built in Squarespace from its text |
| `Support-draft.md` | A plain-language draft of `Docs/Support.md` | The body of `Docs/Support.md`, after review |
| `Privacy-Policy-draft.md` | A plain-language draft of `Docs/Privacy-Policy.md` | The body of `Docs/Privacy-Policy.md`, after review |
| `tour/tour.html`, `tour/img/` | The tour: 20 steps in five parts, after a section on the editors' work, with production notes for each screen | An optional page at `frusexplorer.app/tour` |

Open the two HTML files in a browser from this folder. The sheet's Support and Privacy frames show the
two Markdown drafts as they stood on 2026-10-27; after editing a draft, run the repository's script
on it to see the new HTML.

## Coming soon and launch

Each page carries both versions. An element marked `data-show="soon"` appears only before release, and
one marked `data-show="launch"` only after; the switch sets `data-state` on the page. On release day:

- the home page drops its coming-soon banner, button and the *When will it be out?* answer, takes
  Apple's official App Store badge, linked to the listing, and switches its kicker, lead, price
  answer and contact section to their launch wording;
- Support loses its **Coming soon** line (delete it in `Docs/Support.md`, run the script, paste the
  HTML);
- the tour's closing section changes from the help address to *Get the app*;
- Privacy has no coming-soon text.

The banner on the home page and the tour reads "FRUS Explorer has been submitted to the App Store"
(the owner's comment of 2026-10-20, since Apple decides whether it is allowed). The kicker and button
("Coming soon to the App Store") and the tour's "will be free" still assume approval; whether to
soften them is the owner's call.

## What the drafts already follow

- **The disclaimer** of #1802, word for word: *independent, private-capacity*, and commentary that is
  personal views about historical research methodology, making no interpretive claim about the
  history of U.S. foreign policy. The NARA sentence and the listing's privacy sentence (decision 28)
  are also verbatim.
- **The series credited, and set against nothing.** The home page and the tour credit the editors and
  the Office's publication of the series as open TEI data. They make no comparison with a bulk
  release or with any other edition, and name history.state.gov only as the Office's own edition
  (the launch kit's §6).
- **The app's own terms, kept and explained** where each first appears: editorial annotation, your
  annotations, archival provenance, provenance of a value (the app's labels *FRUS text*,
  *FRUS + NARA catalog*, *This app's model*), semantic, corpus and working corpus, volume scope,
  corpus proximity, lasso, hops and TEI. Plain words replace jargon only where the app has no term of
  its own.
- **A reading level of grade 8 to 9.** Flesch–Kincaid grade over paragraphs, list items, table cells
  and captions of eight words or more, leaving out labels, navigation and production notes, with
  syllables from a standard English hyphenation dictionary:

  | Page | Before | Draft |
  |---|---|---|
  | Home | new | 6.6 coming soon, 6.9 at launch |
  | Support | 8.1 | 6.9 |
  | Privacy | 9.7 | 8.5 |
  | Tour | 8.3 | 7.2 |

  "Before" is the copy of record at `v2` `1c18b51` for Support and Privacy, and the tour as it stood on
  2026-10-17. Most blocks still above 9.5 hold a web address, a menu path or a long feature name.
- **Support and Privacy claim what the copies of record claim**, and no more. Support adds the
  coming-soon line and one sentence saying what TEI is; that sentence needs a row in
  `Docs/Website/README.md`.

## What the review owes (decision 101)

- **Figures.** Recount each against 1.0 (1861)'s shipped artifacts before publishing: 553 volumes;
  264,598 source notes matched to documents, in 502 volumes; 51 volumes with none; 8,637
  cross-references between volumes; 314,616 documents on the semantic map; the 13,174 documents of
  the People capture. Index versions 70 and 71 (A18, A18b) changed what the index stores, so the
  cross-reference figure in particular may have moved.
- **Screens.** The tour's captures come from builds 47 and 48, and its People sheet from before
  #1370 and #1441. Retake each from the submitted build; R1's retakes (decision 88) and
  `Docs/screenshots/` are the sources. Steps 18 to 20 have no capture, and the meaning-search, map and
  Chronology screens predate EmbeddingGemma 2, build 51's map layout and #1422. Each step's
  production note names what it needs.
- **The kit's rules.** Read each page against the launch kit's §6 checklist.
- **The copies of record.** Fold the Support and Privacy drafts in, run
  `python3 Scripts/build_website_pages.py`, check that `--check` passes, and add the TEI row.
- **The owner's call.** Whether the home page and the tour stay drafts here or become copies of record
  under `Docs/Website/`, with a trace for each factual sentence as decision 36 asks of the other two.

## How they were made

They were written in sessions of 2026-10-17 to 2026-10-27, following the owner's requests in this
order:
- the site's scope and style;
- a walkthrough on four themes, with agentic analysis left out;
- the editors' work as a theme;
- coming-soon versions and a plain-language pass;
- the app's own terms kept and explained;
- Part V and the People step.

The review sheet was assembled from page fragments by a session script that is not committed; its
frames for Support and Privacy are the repository script's output for the two drafts.
