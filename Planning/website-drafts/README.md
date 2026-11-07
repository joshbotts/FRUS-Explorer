# Website drafts

**Status: DRAFT, 2026-10-27.** None of these files is published, and none is a copy of record. The
work they wait for is the plan of record's decision 101 (`Plan-Of-Record-2026-10-21.md` §3): the
website's pages are generated, reviewed and revised after 1.0 (1861) is submitted. Until then, §2's
website step stands: at submission the Privacy Policy and Support pages go up as `Docs/` holds them.

**Revised 2026-11-06.** The owner revised the Home and Tour text through the Markdown editing
copies below. Both now describe 1.0 (1861) as the owner has scoped it: all of 2026-11-06's work,
Editors' Annotations among it, and all work in progress (`Revisions-proposed-2026-11-06.md`).

## What is here

| File | What it is | What it becomes |
|---|---|---|
| `page-drafts.html` | The review sheet: the home page, and the Support and Privacy drafts as `Scripts/build_website_pages.py` renders them, each shown in a site frame, with the publishing steps, the reading levels and the app's terms. A switch at the top shows the coming-soon or the launch version. | The home page at `frusexplorer.app/`, built in Squarespace from its text |
| `Support-draft.md` | A plain-language draft of `Docs/Support.md` | The body of `Docs/Support.md`, after review |
| `Privacy-Policy-draft.md` | A plain-language draft of `Docs/Privacy-Policy.md` | The body of `Docs/Privacy-Policy.md`, after review |
| `Home-draft.md`, `Tour-draft.md` | Editing copies of the home page's and the tour's words, with layout left out. No build reads them: a session folds the owner's edits back into `site-src/home.html` and `tour/tour.html`. The owner edits the copies in iCloud Drive, in the *2026-06-30 FRUS Explorer Build 26 screenshots* folder | Nothing; the HTML is the source |
| `Revisions-proposed-2026-11-06.md` | What 2026-11-06's work changed in the app, and the revisions it led to (applied; its screens are still owed) | Nothing |
| `tour/tour.html`, `tour/img/` | The tour: 20 steps in five parts, after a section on the editors' work, with production notes for each screen | An optional page at `frusexplorer.app/tour` |

Open the two HTML files in a browser from this folder. The sheet's Support and Privacy frames show the
two Markdown drafts as they stood on 2026-10-27; after editing a draft, run the repository's script
on it to see the new HTML.

## The site preview (2026-11-03)

`build_site.py` writes `site/`, a local preview of every page the site is to carry, in one shell
standing in for Squarespace's: Home (`site-src/home.html`), the tour, both quick starts (from
`Docs/`), and Support and Privacy (from the two drafts here), with `site/review.html`, a review
sheet that recounts the pages' figures from `FRUSExplorer/Resources` on every run and sets each tour
screen beside its current capture. A bar on every page switches between the coming-soon and launch
versions and hides the review notes; neither the bar nor the notes is pasted. Serve the repository
root over HTTP to view it (`python3 -m http.server 8765` there, then `/Planning/website-drafts/site/`),
since the quick starts' screenshots load from `Docs/screenshots/` by relative path. Then run
`python3 Planning/website-drafts/build_site.py --watch`: it rebuilds on every save of a source, and each
open page reloads itself within a second or two (`site-src/reload.js` reads `site/build-stamp.txt`). A
failed build is printed and the last good pages stay up. Without `--watch`, the script builds once.
Never edit `site/`, which every build overwrites.

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

- **The disclaimer** of #1802, word for word in the footers and the Support and Privacy pages (the home page's hero line was shortened by the owner on 2026-11-06 to *an independent research tool, not an official product…*; its FAQ answer keeps *private capacity*): *independent, private-capacity*, and commentary that is
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
  cross-references between volumes; 314,616 documents on the semantic map; the 13,177 documents of
  the People capture (retaken 2026-11-04). Index versions 70 and 71 (A18, A18b) changed what the index stores, so the
  cross-reference figure in particular may have moved.
- **Screens.** Done for seventeen on 2026-11-03: each was re-cropped from its build-1861 capture in
  `Docs/screenshots/` at the old crop's width and framing, and its caption, alt text and production
  note brought to the new screen; the build 47–48 crops are kept in `tour/img-builds-47-48/`, and
  `site/review.html` sets each pair side by side with what changed. On 2026-11-06, after #1865's retakes, six were
  re-cut again (steps 1, 2, 3, 5, 8 and 9: classification chips, the Editors' Annotations door, the
  288-volume line), and steps 14 and 18 gained screens (the Editors' Annotations matrix, Research ▸
  History). Step 13 gained the map film, re-rendered from build 51's layout (`tour/img/map-film.mp4`; rebuild it
  with `tools/map-film/`). Still owed: steps 19 and 20 have no capture, and step 15 is a text slip.
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
