<!--
  The owner's steps for entering the website's pages into Squarespace. It replaces the steps given
  in chat on 2026-11-07, which no file held. Written 2026-11-10 on the owner's word: "assume that
  build-53 (1.0/1812) will end up being bumped to the App Store release that will ship (1861) with
  no further feature updates. update website drafts and my instructions for entering them into
  squarespace."

  The parts between "generated" markers are written by build_paste.py from the pages' own sources:
  edit the source and run the script, never the text between the markers. Everything else here is
  edited by hand. `python3 Planning/website-drafts/build_paste.py --check` says when the two part.

  What it says of Squarespace was read in Squarespace's help centre on 2026-11-10; the pages are
  listed at the end. Nothing here was tried on the site itself, which answers 401 to everyone but
  its owner.
-->

# Entering the website into Squarespace

Six pages go on frusexplorer.app. They describe **version 1.0 (1861)**, which is taken to be what
1.0 (1812), TestFlight build 53, already does: the pages were read against that build on
2026-11-10, and every figure on them was recounted from its bundle.

| Page | Address | How it goes in | From |
|---|---|---|---|
| Privacy | `/privacy` | one Code Block | [paste/privacy.txt](paste/privacy.txt) |
| Support | `/support` | one Code Block | [paste/support.txt](paste/support.txt) |
| Quick start, iPad and iPhone | `/quick-start-ios` | one Code Block | [paste/quick-start-ios.txt](paste/quick-start-ios.txt) |
| Quick start, Mac | `/quick-start-mac` | one Code Block | [paste/quick-start-mac.txt](paste/quick-start-mac.txt) |
| Home | `/` | one Code Block | [paste/home-coming-soon.txt](paste/home-coming-soon.txt) |
| Tour | `/tour` | four Code Blocks, and a Video block for the film | [the Tour chapter](#tour), below |

Work in that order. App Store Connect needs the first two addresses, Support links to the two
quick starts, and Home links to all of the others.

## What changed since the steps of 7 November

If you have already entered a page, this is all you need to redo.

| Page | What changed | What to do |
|---|---|---|
| **Home** | No words changed. It can now go in as one Code Block, like the other pages, with its coming-soon line inside it. That line cannot be an Announcement Bar: Squarespace includes one from the Core plan up, and says a feature the plan lacks can show to you while you are logged in and not to visitors. | Turn the bar off, if you set one up. Then either [paste the block](#home) in place of the sections you built, or keep them and add [section 0](#appendix-home-from-native-blocks) above them. |
| **The site's footer and menu** | New: the earlier steps left them out, and the footer carries the disclaimer on every page. | [Do them once](#the-menu-and-the-footer). The footer is one paste. |
| **Privacy** | One sentence gained the Quick Start on the Research tab, two Settings paths gained *Library*, and the date is now November 10, 2026. | Paste [paste/privacy.txt](paste/privacy.txt) over the block's contents. |
| **Support** | One Settings path gained *Library*. | Paste [paste/support.txt](paste/support.txt) over the block's contents. |
| **Quick start, iPad and iPhone** | Its notice names build 1861, where it named 1787. Its line on Browse and its note on what works before a download name Editors’ Annotations. One screenshot's description, for screen readers, names the new Annotations tile; the picture updated by itself. | Paste [paste/quick-start-ios.txt](paste/quick-start-ios.txt) over the block's contents. |
| **Quick start, Mac** | Its notice names build 1861, where it named 1787. Its list of the Corpus Browser's doors and its note on what works before a download name Editors’ Annotations. | Paste [paste/quick-start-mac.txt](paste/quick-start-mac.txt) over the block's contents. |
| **Tour** | It can now be entered. Its text says sixteen kinds of annotation, where it said fifteen, and names the Annotations tile. | [Enter it](#tour). |

The four files sent on 7 November (`privacy.txt`, `support.txt` and the two quick starts) are
superseded by the ones in `paste/`, which carry today's text and a first line that says so.

## Three things the Basic plan changes

1. **No Announcement Bar.** It comes with the Core plan and above. Squarespace says a feature
   the plan lacks disappears from the live site and can still show to you while you are logged
   in, so a bar that looks right in the editor proves nothing. The coming-soon line is part of
   Home's block, and a small Code Block of its own at the top of the Tour.
2. **No scripts in a Code Block.** A Code Block renders HTML and a `<style>` on every plan, up to
   400 KB. A `<script>` or an `<iframe>` pasted into one is kept and does nothing. None of the eight
   pastes holds either.
3. **The film goes in a Video block.** Any site may hold 30 minutes of uploaded video, and the
   film is 46 seconds.

## The editor, in six lines

- The site is a set of **pages**, listed in the **Pages** panel. A page is a stack of **sections**,
  and a section holds **blocks**: Text, Button, Image, Video, Accordion, Code.
- A new page is empty and offers only **Add Section**. Choose a blank one. **Add Block** then
  appears at the section's top left when you point at it.
- **A page's address** is its URL slug: the gear beside the page in the Pages panel.
- **A Code Block:** Add Block ▸ **Code**. Click the block, then its pencil. Leave the mode at
  **HTML** and **Display Source** off. Select everything in the box, paste, and click away. Then
  drag the block's edges out to the full width of the section.
- **A Text block's style** (Heading 1 to 4, Paragraph 1 to 3) is in its toolbar, after you select
  the words. A paste into one may keep the words alone, so each native block in the appendix
  lists the italics, bold and links to check and put back. A Code Block keeps everything. For a link, select the words and press ⌘K; an address such as
  `/tour` names a page of your own site.
- Nothing shows to visitors until you **Save**, and while the site is behind its password,
  nothing shows to anyone else at all.

## The four pasted pages

For each of Privacy, Support and the two quick starts:

1. **Pages ▸ ＋ ▸ Blank Page.** Name it, and set its URL slug from the table at the top.
2. **Edit ▸ Add Section** (blank) **▸ Add Block ▸ Code.**
3. Open the paste file from the table, select all of it (⌘A), copy, and paste it over whatever the
   Code Block holds. Its first line is a comment naming the page and a fingerprint: leave it in.
   The files are plain text: any editor opens one, and once they are merged GitHub shows each
   with a **Raw** button, from any device.
4. Drag the block to the section's full width, then **Save**.
5. Look at the page, and at its phone view (the phone icon at the top of the editor).

What to expect:

- **Privacy** opens with *FRUS Explorer Privacy Policy* and its date, *November 10, 2026*, and
  ends with a line that links to Support.
- **Support** opens with the disclaimer in a quotation block, and lists the two quick starts
  first under *Manuals and guides*. Those two links fail until the quick starts are up.
- **A quick start** opens with its *AI Generated* notice, which names build 1861, and shows its
  screenshots, which load from this repository on GitHub. A capture retaken later shows on the
  site with no new paste. The repository has to stay public.
- Type and colour are your site's. If a page's text is cut off at the bottom, drag the block's
  lower edge down; if the phone view cuts it off, do the same there, since the two views are sized
  apart.

**Which Support and Privacy text this is.** It is the published text, `Docs/Support.md` and
`Docs/Privacy-Policy.md`, as the plan of record has it for the submission. The plain-language
drafts in this folder replace it only when you say so: a session folds them into `Docs/`, runs
both scripts, and these two paste files change. The Support draft then carries a *Coming soon*
line, which comes out on release day.

## The menu and the footer

**The menu.** In the Pages panel, **Main Navigation** holds what the header lists, and **Not
Linked** holds pages that exist without a place in it. The preview's header reads *Tour · Quick
Start · Support · Privacy*: put Tour, the iPad and iPhone quick start, Support and Privacy in Main
Navigation, in that order, and Home and the Mac quick start in Not Linked. Each quick start links
to the other in its first lines. Set Home as the homepage from its gear.

**The footer** is one section shared by every page: scroll to the bottom of any page in the
editor and choose **Edit Footer**. Remove what the template put there, add a Code Block, and paste
all of [paste/footer.txt](paste/footer.txt) into it.

<!-- generated:footer -->

It holds, word for word, the store listing's disclaimer and the National Archives sentence, and under them five links: *Support* (`/support`), *Privacy* (`/privacy`), *Tour* (`/tour`), *Quick start* (`/quick-start-ios`), *Source code* (`https://github.com/joshbotts/FRUS-Explorer`).

<!-- /generated:footer -->

Its type and colour are your footer's own, so it reads on a dark footer as on a light one. It is
pasted, not typed, so that the disclaimer stays word for word: do not shorten it in the block.

**To look like the preview** (optional): in **Site Styles**, Source Serif 4 for headings and
paragraphs and IBM Plex Sans for buttons and the menu, if the font list offers them; a white
background, text `#1B1B1F`, buttons and accents `#A61C2A`, links `#22705F`. The Tour's blocks ask
for the same typefaces by name and fall back to Georgia where the site does not load them.

## Home

One Code Block, as the four pages above are: a blank page, a blank section, a Code Block dragged to
the section's full width. Set the page as the homepage from its gear. Its draft is
`site-src/home.html`, which the preview shows.

Squarespace has no switch between a page's two versions, so each is a file, and release day is one
paste over the other.

<!-- generated:home-paste -->

| When | What the Code Block holds |
|---|---|
| Now | all of [paste/home-coming-soon.txt](paste/home-coming-soon.txt) |
| Release day | all of [paste/home-launch.txt](paste/home-launch.txt), pasted over it |

The launch version differs from the first in six places, and in nothing else:

1. the coming-soon line at the top is gone;
2. the label over the headline reads *Free on the App Store*, where it read *Coming soon to the App Store*;
3. the opening paragraph no longer says the app is coming soon;
4. Apple's “Download on the App Store” badge, linked to the app's page there, stands where the outlined “Coming soon to the App Store” did;
5. under *Questions*, *When will it be out?* is gone and *What does it cost?* answers *It's free.*;
6. the last section is *Tell me what it can't answer yet*, where it was *Questions before it's out?*.

**The launch file is not ready yet.** Its badge has to link to the app's page on the App Store, an address the app has only once it is approved: `https://apps.apple.com/app/id` followed by the app's Apple ID, which App Store Connect shows under **App Information**. Until then the file holds `APP-STORE-ADDRESS` in its place, says *NOT READY* on its first line, and shows a notice in a dashed box at the top of the page, so a paste of it cannot pass for the finished page.

On release day, give the address to a session, or set `APP_STORE_URL` near the top of `build_paste.py` yourself and run `python3 Planning/website-drafts/build_paste.py`. The file it then writes has the address, no notice and a new fingerprint: paste that one.

The badge itself is Apple's own artwork, loaded from Apple's marketing toolbox, so there is nothing to upload.

<!-- /generated:home-paste -->

What to expect:

- **The coming-soon version** opens with the coming-soon line in a tinted box, then *Coming soon to
  the App Store* over the headline, *Search 553 volumes of the U.S. diplomatic record.*
- Four columns under *What it does*, which become two and then one as the page narrows.
- Nine questions under *Questions*, each with its answer showing.
- Its links go to `/tour`, the two quick starts, `/privacy` and `/support`, so they work as those
  pages go up.
- Type and colour are the draft's own, as in the preview: Source Serif 4 where your site loads it,
  and Georgia where it does not.
- To change a word later, tell a session: it changes the draft, the script writes the file again,
  and you paste it. If you would sooner edit the page in Squarespace itself, build it from native
  blocks instead, as the [appendix](#appendix-home-from-native-blocks) lists them.

## Tour

Five sections, top to bottom, with one block in each. The two large Code Blocks hold everything
that does not change at launch, the two small ones hold what does, and the film is a Video block.

<!-- generated:tour -->

| Section | Block | What goes in it |
|---|---|---|
| 1, coming soon only | Code | all of [paste/tour-coming-soon-line.txt](paste/tour-coming-soon-line.txt) |
| 2 | Code | all of [paste/tour-block-1.txt](paste/tour-block-1.txt) |
| 3, optional | Video | the film: upload [tour/img/map-film.mp4](tour/img/map-film.mp4) (3.2 MB) |
| 4 | Code | all of [paste/tour-block-2.txt](paste/tour-block-2.txt) |
| 5 | Code | all of [paste/tour-closing-coming-soon.txt](paste/tour-closing-coming-soon.txt) |

**Section 3, the film.** Add Block ▸ **Video**, the block's pencil, then **Upload file**. Leave **Autoplay** off and the player's controls on. For the frame shown before it plays, turn on **Custom featured image** and upload [tour/img/map-film-poster.jpg](tour/img/map-film-poster.jpg). In the editor's **Description** field, which shows under the film as its caption:

> The record as it was released: each frame lights every mapped document in the volumes published so far, whole volumes, whatever each document is about. 553 volumes in 46 seconds, drawn by the app from the map it ships with.

**On release day, change two things.**

1. **Section 1:** delete it.
2. **Section 5:** paste all of [paste/tour-closing-launch.txt](paste/tour-closing-launch.txt) over what its block holds. Its heading becomes *Bring your own question*, where it was *Coming soon to the App Store*; it says the app is free, where it said it will be; and a **Get the app** button stands where the outlined “Coming soon to the App Store” did. The button goes to the home page, whose badge goes on to the App Store; once `APP_STORE_URL` is set in `build_paste.py` it goes there itself.

<!-- /generated:tour -->

What to expect:

- **The coming-soon line** is a tinted box, as on Home.
- **The first large block** opens with *Take one question through 553 volumes* and a table of
  contents whose entries jump down the page, and ends with the dark band that holds the map.
- **The second** opens at step 14 and ends with step 20.
- **The closing** reads *Coming soon to the App Store*, with the two quick starts and the help
  address beside it.
- Each screenshot is a link: a click opens it at full size in a new tab.
- Home's links to `/tour#part-0` and `/tour#part-5` land on *What FRUS historians built* and
  *Standing behind your work*. They work once the two large blocks are in.
- The screenshots load from this folder on GitHub. If the folder is ever moved, the blocks have to
  be made again and pasted again.
- Skip section 3 and the page reads on from the map to step 14 with nothing missing.

## Going public, and release day

| When | What |
|---|---|
| **Now**, behind the password | Enter all six pages, the menu and the footer: twelve pastes and one video. Nobody else can see them. |
| **The day 1.0 (1861) is submitted** | **Settings ▸ Site Availability ▸ Public ▸ Save.** App Review opens `/privacy` and `/support`, and both answer with an error while the password is on. The coming-soon lines say the app *has been submitted*, so this is the day they become true. |
| **Release day** | Home: paste [paste/home-launch.txt](paste/home-launch.txt) over its block, once that file holds the app's App Store address ([Home](#home) says how). The Tour: its two changes, listed at the end of its chapter. Privacy and the quick starts do not change. Support does not change either, unless the plain-language draft was folded in: then its *Coming soon* line comes out, and you paste it once more. |

Making the site public is yours to do: it is the step that publishes it. So is the wording that
assumes approval, *Coming soon to the App Store* and *It will be free*, which App Review decides.

## When a page changes later

A change to a page's source reaches the site only when you paste it again.

1. The source changes: `Docs/Support.md`, `Docs/Privacy-Policy.md`, a quick start, `tour/tour.html`
   or `site-src/home.html`.
2. `python3 Scripts/build_website_pages.py` writes the four pages' HTML, and
   `python3 Planning/website-drafts/build_paste.py` writes the paste files and this guide's
   generated parts. Each has a `--check`.
3. You paste the changed file over its block. If you built Home from native blocks, you retype
   the block that changed.

To tell which version a block holds, open it and read the fingerprint on its first line against
this table:

<!-- generated:kit -->

| File | Goes in | Size | Fingerprint |
|---|---|---|---|
| [paste/privacy.txt](paste/privacy.txt) | `/privacy` | 12,045 bytes | `70729172` |
| [paste/support.txt](paste/support.txt) | `/support` | 6,321 bytes | `afe50dd6` |
| [paste/quick-start-ios.txt](paste/quick-start-ios.txt) | `/quick-start-ios` | 26,375 bytes | `95bade41` |
| [paste/quick-start-mac.txt](paste/quick-start-mac.txt) | `/quick-start-mac` | 26,864 bytes | `503e955d` |
| [paste/footer.txt](paste/footer.txt) | the footer of every page | 1,208 bytes | `08c9aa33` |
| [paste/home-coming-soon.txt](paste/home-coming-soon.txt) | `/`, until release day | 11,892 bytes | `814c41f7` |
| [paste/home-launch.txt](paste/home-launch.txt) | `/`, from release day | 12,036 bytes | `ccf6ec51`, not ready: it waits for the App Store address |
| [paste/tour-coming-soon-line.txt](paste/tour-coming-soon-line.txt) | `/tour`, section 1, until release day | 1,036 bytes | `73a41228` |
| [paste/tour-block-1.txt](paste/tour-block-1.txt) | `/tour`, section 2 | 66,699 bytes | `7919c798` |
| [paste/tour-block-2.txt](paste/tour-block-2.txt) | `/tour`, section 4 | 35,826 bytes | `4671c5d0` |
| [paste/tour-closing-coming-soon.txt](paste/tour-closing-coming-soon.txt) | `/tour`, section 5, until release day | 4,139 bytes | `a65b3389` |
| [paste/tour-closing-launch.txt](paste/tour-closing-launch.txt) | `/tour`, section 5, from release day | 4,025 bytes | `f23bd2df` |

<!-- /generated:kit -->

## Appendix: Home from native blocks

The other way to enter Home: typed into Squarespace's own blocks, section by section. It takes
longer, and the words then live in Squarespace, where you can edit them in place. Use it or the
Code Block, not both. If you built Home this way on 7 November, its words have not changed since:
only section 0 is new.

**Every section starts the same way:** Add Section ▸ blank, then Add Block inside it.

<!-- generated:home -->

#### 0. The coming-soon line: a thin section of its own

| Block | Style | Content |
|---|---|---|
| Text | **Paragraph 2**, centred | **Coming soon** — FRUS Explorer has been submitted to the App Store for iPhone, iPad and Mac. |

- Bold the first two words. Under **Edit Section**, give the section the smallest height and a background that sets it off, so it reads as a notice.
- This takes the place of the Announcement Bar, which the Basic plan does not include (see *Three things the Basic plan changes*, above).
- On release day, delete the whole section.

#### 1. Hero

| Block | Style | Content |
|---|---|---|
| Text | **Heading 4** (a small label) | Coming soon to the App Store |
| Text | **Heading 1** | Search 553 volumes of the U.S. diplomatic record. |
| Text | **Paragraph 1** | FRUS Explorer is a free research app for iPhone, iPad and Mac, coming soon to the App Store. It puts the *Foreign Relations of the United States* series and powerful new research tools on your device, so you can reach and share insights from 165 years of U.S. diplomatic history. |
| Button | Primary | **Take the tour** → `/tour` |
| Text | **Paragraph 2** | Quick start: iPad and iPhone · Mac |
| Text | **Paragraph 3** (small) | FRUS Explorer is an independent research tool, not an official product of the Office of the Historian or the U.S. Department of State. |

*After pasting* — italic: *Foreign Relations of the United States*; link: “iPad and iPhone” → `/quick-start-ios`; link: “Mac” → `/quick-start-mac`.

- The draft's outlined “Coming soon to the App Store” pill is left out on purpose: a Button block with no link looks clickable and does nothing, and the label above already says it.

#### 2. What it does: a heading, four columns, a link

| Block | Style | Content |
|---|---|---|
| Text, full width | **Heading 2** | What it does |
| Text × 4, side by side | **Heading 3**, then **Paragraph 2** | the four below |
| Text | **Paragraph 2** | See all of it in the tour → |

1. **Find what you need** — Search every volume you've downloaded, offline. Narrow the results by year, volume, person or subject. Or search by meaning: ask a question in your own words.
2. **Manage your research** — Highlight, take notes and tag documents as you read. Save searches, gather documents into collections, and plan a trip to the archives.
3. **See the patterns** — Chart a word across the years, lay out a crisis day by day, and follow how documents point to each other.
4. **Share what you find** — Export analytics, word clouds, and document collections with your own annotations.

*After pasting* — link: “See all of it in the tour →” → `/tour`.

- Each of the four is one Text block: its title on the first line as Heading 3, its sentence under it.
- For four columns, make the first block and drag its right edge in to a quarter of the width, then add the others and drag each beside the last. Check the phone view (the phone icon at the top of the editor): they should stack.

#### 3. Built on the editors' work: one Text block

The first line is **Heading 2**, the rest **Paragraph 2**.

> **Built on the editors' work**
>
> FRUS is an edited documentary history series produced by the State Department's Office of the Historian. The historians who compile the volumes select documents for publication after extensive research in classified records from across the foreign affairs interagency and then add editorial annotation to help readers place each document in its contemporary and archival context. They give each document a heading, a source note describing its original provenance and current archival location, and add other footnotes as needed to help readers understand the text and locate other directly related records. The digital editions published by the State Department include all of that work as open TEI data.
>
> FRUS Explorer builds on that foundation to transform editorial annotation into active tools that help researchers reach and share insights about the history of U.S. foreign policy. It turns informative text into direct links to archives, graphs of incoming and outgoing cross-references, cross-volume people networks, and visualized analytics. Because FRUS editors' practices changed over 165 years, not every volume carries every kind of annotation. Every volume's page shows what kinds of annotation it carries, even before you download it, and Browse lays out each kind of annotation across the series' eras.
>
> The app clearly labels where the information on screen came from, so users can distinguish at a glance what came directly from the published volumes, what came from other Office of the Historian data sources or the National Archives catalog, and what was built specifically for the app.
>
> See one document, with its editorial annotation labeled →

*After pasting* — link: “See one document, with its editorial annotation labeled →” → `/tour#part-0`.

#### 4. Work that holds up: one Text block

**Heading 2**, then a bulleted list (select the three lines and use the toolbar's list button), then the link.

> **Work that holds up**
>
> - **Show how you got your results.** The app keeps a record of your searches, saved sets and charts, down to the searches that found nothing.
> - **Check a citation.** Paste a footnote, or a whole chapter's notes, and review the documents they identify.
> - **Keep up with corrections.** When the Office corrects a volume, the app shows what changed in the documents you've marked with research annotations.
>
> See how in the tour →

*After pasting* — bold: **Show how you got your results.**; bold: **Check a citation.**; bold: **Keep up with corrections.**; link: “See how in the tour →” → `/tour#part-5`.

#### 5. Your research stays yours: one Text block

> **Your research stays yours**
>
> FRUS Explorer collects no data. What you read, search and write stays with you: notes and collections sync only through your own iCloud account, and the app connects with the National Archives' catalog or your Zotero library only when you tell it to.
>
> Read the privacy policy →

*After pasting* — link: “Read the privacy policy →” → `/privacy`.

- Give this section a different background from its neighbours (**Edit Section ▸ Colors**), so it reads as a promise and not one more feature.

#### 6. Questions: a heading and an Accordion block

| Block | Content |
|---|---|
| Text, **Heading 2** | Questions |
| **Accordion** | one item for each row below |

| Title | Description |
|---|---|
| Is this an official government app? | No. FRUS Explorer is an independent research tool released in the developer's private capacity. It is not an official product of the Office of the Historian or the U.S. Department of State. The FRUS series itself is in the public domain. |
| When will it be out? | Soon. This page will link to the App Store as soon as the app is there. |
| What does it cost? | It will be free. |
| What do I need? | An iPhone or iPad with iOS or iPadOS 26 or later, or a Mac with macOS 26 or later. Document summaries also need Apple Intelligence. |
| Does it need the internet? | Only to download volumes and a few optional extras. After that, reading and searching work offline. If you add NARA Catalog and/or Zotero API keys, those connections also require internet connectivity. |
| How much space does it take? | The whole series is about 3.3 GB. The search index the app builds takes about 2.8 times as much again. You can download only the volumes you need, and remove them later. |
| Does it use AI? | Two optional features use a model on your device. Apple Intelligence writes document summaries, and each one is labeled as generated. Search by meaning relies on a downloaded embedding model to encode your queries. Nothing you type leaves your device for either of these features. |
| Where do I start? | The quick start for iPad and iPhone or for the Mac takes you through a first session, from the first download to a cited document. |
| Which languages does it support? | English only, just like the FRUS series itself. |

*After pasting* — link: “iPad and iPhone” → `/quick-start-ios`; link: “the Mac” → `/quick-start-mac`.

- **Add Block ▸ Accordion**, then the block's pencil: each item takes a **Title** (the question) and a **Description** (the answer).

#### 7. Contact: one Text block

> **Questions before it's out?**
>
> Email help@frusexplorer.app. If you're testing the app, the Support page has the quick starts and manuals, and tells you what to put in a bug report.

*After pasting* — link: “help@frusexplorer.app” → `mailto:help@frusexplorer.app`; link: “Support page” → `/support`.

#### On release day, change six things

1. **Section 0:** delete it.
2. **Hero label:** Free on the App Store
3. **Hero paragraph:** FRUS Explorer is a free research app for iPhone, iPad and Mac. It puts the *Foreign Relations of the United States* series and powerful new research tools on your device, so you can reach and share insights from 165 years of U.S. diplomatic history.
4. **Hero, above the button:** add an **Image** block with Apple's “Download on the App Store” badge, from Apple's marketing resources, linked to the app's App Store page. Use Apple's artwork as supplied.
5. **Questions:** delete “When will it be out?”. Under “What does it cost?”, the answer becomes: It's free.
6. **Section 7:** the heading becomes **Tell me what it can't answer yet**, and the text: Bug reports, ideas and questions are all welcome. Email help@frusexplorer.app, or see the Support page for what to include.

*After pasting* — italic: *Foreign Relations of the United States*; link: “help@frusexplorer.app” → `mailto:help@frusexplorer.app`; link: “Support page” → `/support`.

<!-- /generated:home -->

## Squarespace's own pages on these steps

- [Code blocks](https://support.squarespace.com/hc/en-us/articles/206543167): the 400 KB limit, and
  the mode and Display Source settings.
- [Premium features](https://support.squarespace.com/hc/en-us/articles/115015517328): what the
  Basic plan leaves out, the Announcement Bar and scripts among them.
- [Announcement bar](https://support.squarespace.com/hc/en-us/articles/205815318): the plans that
  have it.
- [Publish or hide your site](https://support.squarespace.com/hc/en-us/articles/360002088548): Site
  Availability.
- [Video blocks](https://support.squarespace.com/hc/en-us/articles/206544187) and
  [Upload videos to your site](https://support.squarespace.com/hc/en-us/articles/206542397): the
  Description field, the 30 minutes, and the file types.
- [Anchor links](https://support.squarespace.com/hc/en-us/articles/207135178): links to a place on
  a page.
- [Resizing blocks](https://support.squarespace.com/hc/en-us/articles/206543647): the computer and
  phone views are sized apart.
