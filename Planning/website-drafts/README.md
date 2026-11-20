# Website drafts

**Status: DRAFT, 2026-10-27.** None of these files is published, and none is a copy of record. The
work they wait for is the plan of record's decision 101 (`../Completed/Plan-Of-Record-2026-10-21.md`, carried in `../Plan-Of-Record-2026-11-15.md` §3): the
website's pages are generated, reviewed and revised after 1.0 (1861) is submitted. Until then, §2's
website step stands: at submission the Privacy Policy and Support pages go up as `Docs/` holds them.

**Revised 2026-11-06.** The owner revised the Home and Tour text through the Markdown editing
copies below. Both now describe 1.0 (1861) as the owner has scoped it: all of 2026-11-06's work,
Editors' Annotations among it, and all work in progress (`Revisions-proposed-2026-11-06.md`).

**Read against 1.0 (1812) on 2026-11-10**, TestFlight build 53, on the owner's word: "assume that
build-53 (1.0/1812) will end up being bumped to the App Store release that will ship (1861) with no
further feature updates. update website drafts and my instructions for entering them into
squarespace." So the pages describe what `build-53` does, and decision 101's review was made
against it ahead of the submission (*What the review owes*, below). The steps for entering the
pages into Squarespace, given in chat on 2026-11-07 and held by no file, are now
`Squarespace-Entry.md`.

**Read against 1.0 (1823) on 2026-11-18** (R5), the tree 1.0 (1861) ships with only its build
number raised (the plan of record from 2026-11-15, R7). 1861 took the rows L15 to L25 after all, so
the pages were read against it again, as #1888 asked. A diff of every localized string in the app
and the kit since `f179c1bd`, by key (47 values changed, 20 keys gone), finds no page quoting one
but the quick starts' alt text: three captures L15 retitled (*Topics* to *Subjects*: `browse-root`
and `research-rail` on iOS, `research-strip` on the Mac) and the iOS guide's onboarding size line
(L20). That text follows T2's retakes (`Docs/screenshots/README.md`), and the four tour screens
that showed *Topics* (`truman.jpg`, `browse.jpg`, `rail.jpg`, `related.jpg`) were re-cut from them.
The home page, the tour's text, Support and Privacy name nothing those rows changed: the tour
already names L25's templates, and every storage figure is L20's (*about 7 GB* once indexed). The
bundle's figures are 1812's, since its two regenerated files differ only in their index-version
stamp. **Owed by the owner after the merge:** paste `paste/quick-start-ios.txt` and
`quick-start-mac.txt` again; the tour's images load from GitHub and change with the merge.

**Read against 1.0 (1861) on 2026-11-20** (decision 101, the plan of record's §3), the build
submitted to App Review that day (`08e8bac8`, tagged `1.0-release`), after #1956 to #1960 had
changed it since R5's reading. Every figure recounts the same: the bundle and the two Swift files
the recount reads did not change after `75364cec`. Every page sentence holds against the five
changes but four, which changed on the owner's word that day:
- **Home and the tour say the app is in App Store review**, where they said final testing; Home's
  *When can I get it?* had said "in final testing before App Store review".
- **Support and Privacy are their plain-language texts.** The two drafts were folded into
  `Docs/Support.md` and `Docs/Privacy-Policy.md` and removed from this folder. Support left out
  its *In testing* line, so it does not change on release day. Privacy is dated November 20, 2026,
  and gains a paragraph on the app's own website: Squarespace, which hosts it, counts visits for
  the developer, and the site sets no analytics cookies. That last sentence holds only once the
  site's non-essential cookies are set to Restrict (`Squarespace-Entry.md`, *What changed*).
- **Step 14's Editors' Annotations crop** was re-cut from a retake: the axis's opening sentence is
  the owner's EditableContent review's (#1959).
- **Steps 19 and 20 have screens**, captured from 1.0 (1861) on the iPad simulator on the owner's
  word (`Docs/screenshots/README.md`, the sitting's entry).

Read and found to hold: the iPad's rail, a column of its own since R6a, which looks as the
inspector did (the owner's word of 2026-11-20); the Mac's exports, which still go only where they
are saved; the quick starts' links, already the site's. The reading level was measured again
(*What the drafts already follow*, below). **Owed by the owner after the merge:** restrict the
site's cookies, then paste six blocks again (`Squarespace-Entry.md`, *What changed*).

## What is here

| File | What it is | What it becomes |
|---|---|---|
| `page-drafts.html` | The review sheet: the home page, and Support and Privacy as `Scripts/build_website_pages.py` renders them from `Docs/`, each shown in a site frame, with the publishing steps, the reading levels and the app's terms. A switch at the top shows the coming-soon or the launch version. Until 2026-11-20 its Support and Privacy frames showed the plain-language drafts, `Support-draft.md` and `Privacy-Policy-draft.md`, which were folded into `Docs/` that day and removed | The home page at `frusexplorer.app/`, built in Squarespace from its text |
| `Home-draft.md`, `Tour-draft.md` | Editing copies of the home page's and the tour's words, with layout left out. No build reads them: a session folds the owner's edits back into `site-src/home.html` and `tour/tour.html`. The owner edits the copies in iCloud Drive, in the *2026-06-30 FRUS Explorer Build 26 screenshots* folder | Nothing; the HTML is the source |
| `Revisions-proposed-2026-11-06.md` | What 2026-11-06's work changed in the app, and the revisions it led to (applied; its screens are still owed) | Nothing |
| `tour/tour.html`, `tour/img/` | The tour: 20 steps in five parts, after a section on the editors' work, with production notes for each screen | The page at `frusexplorer.app/tour`, which the home page links to four times; pasted as `paste/tour-block-1.txt` and `-2.txt`, whose screens load from `tour/img/` on GitHub |
| `Squarespace-Entry.md` | The owner's steps for entering all six pages, the menu and the footer into Squarespace, on the Basic plan: what changed since the steps of 2026-11-07, the home page as one Code Block in its two versions, the footer as one, the tour's five sections (four Code Blocks and the film's Video block), what release day changes, and, as an appendix, the home page block by block for native blocks. Its parts between `generated` markers are written by `build_paste.py` | Nothing; it is followed, not published |
| `build_paste.py`, `paste/` | The paste kit: the script writes `paste/`'s twelve files, each the whole contents of one Code Block, and the guide's generated parts, and refreshes `page-drafts.html`'s Support and Privacy frames from the two drafts. `--check` exits 1 when anything is out of step. Each paste opens with a comment naming its page, its source and a fingerprint. The home page has a file for each version, since a paste cannot switch, and so has the tour's closing section; the home page's launch file waits for the app's App Store address (`APP_STORE_URL` in the script) and says *NOT READY* until it has one. The tour's coming-soon line and the site's footer are small blocks of their own | The Code Blocks of `/`, `/privacy`, `/support`, the two quick starts and `/tour`, and of the footer every page shares |

Open the two HTML files in a browser from this folder. The sheet's Support and Privacy frames, and
the Markdown under their buttons, are written from the two drafts by `build_paste.py` since
2026-11-10 (until then they showed the drafts of 2026-10-27, without the quick starts' links); its
Home frame is kept by hand, and the script's `--check` fails when it no longer reads as
`site-src/home.html` does. After editing a draft or a page's source, run
`python3 Planning/website-drafts/build_paste.py`.

## The site preview (2026-11-03)

`build_site.py` writes `site/`, a local preview of every page the site is to carry, in one shell
standing in for Squarespace's: Home (`site-src/home.html`), the tour, both quick starts (from
`Docs/`), and Support and Privacy (from the two drafts here), with `site/review.html`, a review
sheet that recounts the pages' figures from `FRUSExplorer/Resources` on every run and sets each tour
screen beside its current capture. Since 2026-11-10 it recounts two more, the 288 volumes that tag
people and the sixteen kinds of annotation (from the app's own table of layers), says whether the
paste kit is in step, and links to `site/tour-pasted.html`: the tour's two Code Blocks exactly as
`paste/` holds them, inside the preview's shell, with a dashed box standing in for each native
section; and to `site/home-pasted.html`, the home page's block in both versions, on a bare page
that has none of the preview's styles, so that a rule the paste left behind would show. A bar on every page switches between the coming-soon and launch
versions and hides the review notes; neither the bar nor the notes is pasted. Serve the repository
root over HTTP to view it (`python3 -m http.server 8765` there, then `/Planning/website-drafts/site/`),
since the quick starts' screenshots load from `Docs/screenshots/` by relative path. Then run
`python3 Planning/website-drafts/build_site.py --watch`: it rebuilds on every save of a source, and each
open page reloads itself within a second or two (`site-src/reload.js` reads `site/build-stamp.txt`). A
failed build is printed and the last good pages stay up. Without `--watch`, the script builds once.
Never edit `site/`, which every build overwrites.

## Coming soon and launch

Each page carries both versions. An element marked `data-show="soon"` appears only before release, and
one marked `data-show="launch"` only after; the switch sets `data-state` on the page. Squarespace
has no such switch, so the site holds one version at a time, and `Squarespace-Entry.md` lists each
change as an edit to a native block. On release day:

- the home page drops its coming-soon line, button and the *When will it be out?* answer, takes
  Apple's official App Store badge, linked to the listing, and switches its kicker, lead, price
  answer and contact section to their launch wording: pasted, that is `paste/home-launch.txt`
  over the block, once it holds the listing's address;
- Support does not change: its plain-language text was folded in on 2026-11-20 without the draft's
  coming-soon line;
- the tour drops its coming-soon line, a small block of its own that is deleted, and its closing
  section changes from the help address to *Get the app*: `paste/tour-closing-launch.txt` over that
  block. Its two large blocks hold neither, so they are not pasted again;
- Privacy has no coming-soon text.

The banner is a section, not Squarespace's Announcement Bar: the site is on the Basic plan, and
Squarespace includes the bar from the Core plan up (its help centre says a feature the plan lacks
can still show to the owner while logged in, and not to visitors).

The banner on the home page and the tour reads "FRUS Explorer is in App Store review for iPhone,
iPad and Mac. It is not yet on the App Store." The site went live on 2026-11-15, before the
submission, and the earlier "has been submitted" and "Coming soon to the App Store" were not true of
it; on the owner's word that day the pages said the app was in final testing. 1.0 (1861) was
submitted on 2026-11-20, and on the owner's word that day they say it is in App Store review, which
holds however long review takes. Only "will be free" still assumes approval. On 2026-11-15 the home
page's headline became "Research 165 years of U.S. diplomatic history.", and 553 moved into its
opening paragraph.

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

  **Measured again on 2026-11-20**, on the pages as this pass leaves them, by the same rule but with
  syllables from macOS's own English hyphenation dictionary (CoreFoundation's, the only one on this
  Mac), and each page's grade the mean of its blocks' grades. The 2026-10-27 dictionary is not known,
  so the two tables are compared within a column, not across: this one reads the 2026-10-27 texts at
  8.1 and 10.2 (Support and Privacy before) and 6.1 and 7.2 (their drafts). The script is not
  committed; it is kept with the session notes of the plan of record's session.

  | Page | 2026-11-20 |
  |---|---|
  | Home | 8.7, coming soon and at launch (8.5 on 2026-11-06's text) |
  | Tour | 8.0 coming soon, 8.1 at launch (8.3 on 2026-11-06's text) |
  | Support | 6.1, folded, where the text it replaced read 7.8 |
  | Privacy | 7.2, folded, where the text it replaced read 10.2 |
  | Quick starts | 6.9 iPad and iPhone, 7.3 Mac |

  Every page is now at grade 8 to 9 or under it. The blocks still above 9.5 are, as before, those
  holding an address, a menu path or a long feature name, and on Home the editors' paragraph and the
  hero's disclaimer, whose wording is the owner's.
- **Support and Privacy claim what the copies of record claim**, and no more. Support adds the
  coming-soon line and one sentence saying what TEI is; that sentence needs a row in
  `Docs/Website/README.md`.

## What the review owes (decision 101)

- **Figures.** Recount each against 1.0 (1861)'s shipped artifacts before publishing: 553 volumes;
  264,598 source notes matched to documents, in 502 volumes; 51 volumes with none; 8,637
  cross-references between volumes; 314,616 documents on the semantic map; the 13,177 documents of
  the People capture (retaken 2026-11-04). Index versions 70 and 71 (A18, A18b) changed what the index stores, so the
  cross-reference figure in particular may have moved. **Recounted on 2026-11-10 from 1.0 (1812)'s
  bundle** (`v2` at `f179c1bd`; the edge index of 2026-11-06 at index version 74, the annotations
  index of 2026-11-08): every one the same, with 3.34 GB of volumes, 288 volumes that tag people
  and sixteen layers of Editors' Annotations, where the tour said fifteen until #1874's layer was
  counted. The tour's three footnotes that date a count now say November 2026.
- **Screens.** Done for seventeen on 2026-11-03: each was re-cropped from its build-1861 capture in
  `Docs/screenshots/` at the old crop's width and framing, and its caption, alt text and production
  note brought to the new screen; the build 47–48 crops are kept in `tour/img-builds-47-48/`, and
  `site/review.html` sets each pair side by side with what changed. On 2026-11-06, after #1865's retakes, six were
  re-cut again (steps 1, 2, 3, 5, 8 and 9: classification chips, the Editors' Annotations door, the
  288-volume line), and steps 14 and 18 gained screens (the Editors' Annotations matrix, Research ▸
  History). Step 13 gained the map film, re-rendered from build 51's layout (`tour/img/map-film.mp4`; rebuild it
  with `tools/map-film/`). Still owed: steps 19 and 20 have no capture, and step 15 is a text slip. Steps 3 and 8 (`truman.jpg`, `browse.jpg`) were re-cut on 2026-11-10 from sitting T1's retakes for 1.0 (1812), at their old crops' box: the Editors' Annotations door is now the grid's *Annotations* tile, between Editors and Archives (#1884). Step 14's second screen (`annotations.jpg`) was read beside T1's retake the same day and not re-cut: its crop holds *Who is named* and the first two rows of *Where it came from*, where neither #1868's two new labels nor #1874's sixteenth row shows. No other change since 2026-11-06 reaches a screen the tour shows. *On 2026-11-20, read against 1.0 (1861): `annotations.jpg` was re-cut at its old box (1240, 236, 1511 × 1827) from a retake, since the owner's EditableContent review (#1959) reworded the axis's opening sentence, the only text in the crop that moved; steps 19 and 20 gained their screens (`batch.jpg`, `corrected.jpg`), on the owner's word that the session capture. Every other crop holds: R6a's rail column looks as the inspector did, and no other string #1956 to #1960 changed shows in a crop. Step 15 is still a text slip.*
- **The claims.** Read on 2026-11-10 against 1.0 (1812): every on-screen label the tour names is in
  the source as written; the user-facing strings that changed since the drafts' revision of
  2026-11-06 are Editors' Annotations', with the Research Guide's page on excisions (#1868, #1873,
  #1874), and the Browse tile's (#1884), by a diff of every string literal of four words or more;
  no network request and no stored record type was added since the Privacy draft's base. What
  that changed: the tour's count of layers and its path to them, and, in Support and Privacy, two
  things the copies of record had wrong before build 53 (the Library step of a Settings path, and
  the Quick Start row among the links the built-in browser opens, #1848), fixed in the drafts and
  the copies of record together.
- **The two quick starts** were not read in that first pass, which held them only to their
  Markdown; the owner asked the same day ("the quick start guides still refer to build 1787.
  were they reviewed or updated for 1812?"), and they were read then, at `f179c1bd`. Of the
  screens they describe, only Browse had changed since they were written at `f02b330` (#1861,
  #1884). Four passages moved: the notice names build 1861, the build the site describes, where
  it named 1787; the iPad guide's line on Browse and the Mac guide's list of the Corpus Browser's
  doors name Editors' Annotations; and so does both guides' note on what works before a
  download. What held: every on-screen label, the 70 links into the manuals and within the
  guides, the shortcuts (none changed), the figures (their 3.5 GB is the whole download, the
  app's own onboarding line; the home page's 3.3 GB is the volume files alone), and the twenty
  captures, each dated against what changed after it.
- **The kit's rules.** Read each page against the launch kit's §6 checklist.
- **The copies of record.** Fold the Support and Privacy drafts in, run
  `python3 Scripts/build_website_pages.py` and `python3 Planning/website-drafts/build_paste.py`,
  check that each one's `--check` passes, and add the TEI row. *Done on 2026-11-20, on the owner's
  word ("Fold both"), with the TEI row and the new website paragraph's row in
  `Docs/Website/README.md`.*
- **The owner's call.** Whether the home page and the tour stay drafts here or become copies of record
  under `Docs/Website/`, with a trace for each factual sentence as decision 36 asks of the other two.
  While the tour is published from here, its pasted blocks load their screens from `tour/img/` on
  GitHub at the default branch's head: moving this folder breaks them until the blocks are made and
  pasted again.
- **The reading level.** Not measured again after 2026-11-06's revisions or 2026-11-10's few words.
  *Measured on 2026-11-20 (What the drafts already follow, above).*
- **On the site itself.** Nothing in `Squarespace-Entry.md` was tried in Squarespace, whose site
  answers 401 to everyone but its owner: what it says of the editor is from Squarespace's help
  centre, read 2026-11-10. The pasted tour was checked in the preview's shell at 1280 and 375
  points, and against a page whose own stylesheet sets the text elements it uses
  (headings, paragraphs, links, lists and the like): all 821 elements computed the same with and
  without it. The home page's block and the small blocks were tested the same way. Not guarded
  in any of them: a rule on every bare `section` or `div`, which a harsher sheet showed moves a
  section's margins.

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
frames for Support and Privacy are the repository script's output for the two drafts, which
`build_paste.py` writes into it since 2026-11-10.

On 2026-11-10 a session read the drafts against 1.0 (1812), recovered the Squarespace steps of
2026-11-07 from that session's transcript, corrected them (the Announcement Bar, the footer and
the menu they left out, the tour they could not yet enter) and wrote them down with the kit.
