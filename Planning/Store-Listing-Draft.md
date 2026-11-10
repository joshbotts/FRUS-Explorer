# App Store listing — draft copy

**Status:** DRAFT, 2026-08-31. Visual-marketing plan §7 step 3, *"draft store copy by lifting"*.
Nothing here is published; App Store Connect metadata is the owner's to paste and submit.

**Figures re-measured 2026-10-01** against the bundle at `v2` `dc17d945` (build 48's bundle plus
the build-49 wave's regenerations): the volume count and every map figure had moved since the
draft was written, when the manifest held 552 volumes. §5 gives each figure's source. The field
lengths did not move (552 → 553 is the same length), and §6's counter was re-run. **Three
sentences of the description that shipped features contradicted were reworded by the owner on
2026-10-15 — see "Settled before paste" under §2.** The price (free) and the territories (every
storefront, English only) were confirmed the same day. **Revised 2026-10-27 from the owner's
briefing deck:** the description's disclaimer reads *independent, private-capacity* and says
the commentary is personal views about historical research methodology that make no
interpretive claims about the history of U.S. foreign policy, and the BUILT ON THE EDITORS'
WORK section describes the Office's work by its statutory mandate (see the note under §2). The
app's own About disclaimer, `about.dos.disclaimer`, is unchanged by the owner's decision.

**Read against 1.0 (1812) on 2026-11-10**, TestFlight build 53, which the owner takes to be what
1.0 (1861) ships. Every figure recounts the same from `f179c1bd`'s bundle (§5), and that build
contradicts no sentence of the description. What changed here that day:

- the keywords are counted in bytes, as Apple's reference counts them, and an alternate is offered
  (§1);
- a sentence on Editors' Annotations is offered for the description, in the owner's own words from
  the home page (§2);
- What's New is marked as a field a first version does not have (§3);
- §5's index figure is a device's own count, at index version 74;
- §7 is new: the App Review notes;
- the fields leave this file through `Planning/app-store-connect/build_paste.py`, which counts each
  one and writes it ready to paste (§6). **The description's block here is wrapped for reading, and
  App Store Connect keeps a pasted line break: paste `paste/description.txt`, never the block.**

`Planning/app-store-connect/App-Store-Connect-Entry.md` walks through the submission page by page.

**Every field below is counted, not estimated.** The plan's headline correction for this step is a
length failure — a candidate subtitle 83 characters over a 30-character field — so the counts are
the first thing in each block. Re-count after any edit with the script in §6.

**Every number below was measured against a shipped artifact**, per §5's rule that no marketing
number may come from `CLAUDE.md` or a generator doc comment, several of which are measurably stale.
The app is safe because it recomputes at render time; **a store description has no recompute step.**
Provenance for each figure is in §5.

---

## 1. The short fields

### App name — 13 / 30

```
FRUS Explorer
```

### Subtitle — 26 / 30 ✅

```
The U.S. diplomatic record
```

**The candidate line must not go here.** *"The official documentary record of U.S. foreign policy
since 1861…"* — the plan measures the full line at **113 characters** — is proposed for a
30-character field, and it leads with *official* while the mandatory disclaimer sits in About, out
of view. It belongs in the description, in the same
field as the disclaimer — see §2.

Alternates, all counted:

| Option | Chars | Note |
|---|---|---|
| `The U.S. diplomatic record` | 26 | **Recommended.** Says what the corpus is without the acronym. |
| `Research the FRUS series` | 24 | Clearer to someone who already knows the acronym; opaque otherwise. |
| `US foreign relations research` | 29 | Keyword-dense, reads like a search query rather than a subtitle. |
| `Read and search 553 volumes` | 27 | Concrete, but dates the moment a volume is published. |

### Promotional text — 153 / 170 ✅

Editable without a review, so it is the field for anything time-sensitive.

```
553 volumes of the U.S. diplomatic record, indexed on your device and searchable offline — with the sourcing and analysis tools a corpus this size needs.
```

### Keywords — 92 / 100 ✅

Comma-separated, no spaces after a comma (a space is billed like any other character). **The limit
is 100 bytes, not 100 characters**, and each keyword must be longer than two characters (Apple's
reference, read 2026-11-10: "You can provide up to 100 bytes of content"). All ten are ASCII, so
the two counts agree.

```
FRUS,diplomacy,history,archives,primary source,NARA,research,foreign policy,declassified,TEI
```

**Offered 2026-11-10: `relations` in place of `FRUS`, 97 / 100.** The same reference says: "Your
app is searchable by app name and company name, so you shouldn't duplicate these values in the
keyword list." `FRUS` is a word of the name. Without it the field has room for `relations`, so that
both words of the series' own title, *foreign relations*, are in it (`foreign` is there already, in
`foreign policy`). The block above is the copy of record until the owner chooses:

```
diplomacy,history,archives,primary source,NARA,research,foreign policy,relations,declassified,TEI
```

---

## 2. Description

**4,000-character field. This draft is 3,423 / 4,000 ✅** (counted with Python's `len()` over the
block on 2026-10-27; 3,038 on 2026-10-17, after the BUILT ON THE EDITORS' WORK section and the READ line's credit to the
editors; 2,525 on 2026-10-15 after the owner's three sentences, 2,324 before them), leaving room for
the owner to add or cut.

The disclaimer is in **this** field, immediately after the "official documentary record" sentence,
which is the placement §4.1 requires — the two must not be separated.

```
FRUS Explorer is a research tool for the Foreign Relations of the United States series: the
official documentary record of U.S. foreign policy, published since 1861.

FRUS Explorer is an independent, private-capacity research tool. It is not an official product of
the Office of the Historian or the U.S. Department of State. Any commentary, advice, or guidance
about the FRUS series in this app reflects personal views about historical research methodology
and makes no interpretive claims about the history of U.S. foreign policy. Those views are not
necessarily those of the Department of State or the U.S. Government. The FRUS series itself is in
the public domain.

BUILT ON THE EDITORS' WORK
By statute, FRUS must be "a thorough, accurate, and reliable record" of major foreign policy
decisions, with every deletion marked where it occurs. The Office of the Historian fulfills
this mandate through research in the classified files of the Department of State and other
agencies: its historians select the most important documents, arrange them in date order, and
annotate them, from headings, source notes and cross-references to descriptions of material
that cannot be declassified. The Office publishes all of this as open TEI data. FRUS Explorer
reads that apparatus: source notes become archival leads, cross-references become a graph, and
the people the editors identified become an index you can search.

The app downloads the Office of the Historian's TEI editions, indexes them on your device, and
works offline from then on. What you read, search and write stays with you: notes and collections
sync only through your own iCloud account, and the app reaches the National Archives' catalog or
your Zotero library only when you ask it to.

READ
Documents rendered from the original TEI with the editors' headings, footnotes, page breaks and
live cross-references, plus highlights, notes, and a per-document research rail.

SEARCH
Full-text search with stemming, phrases, NEAR() proximity and exact-word matching, across 553
volumes. Save a scope, or capture a working corpus from a result set and search inside it.

SOURCE
Most documents carry the editors' own note saying where the original came from. FRUS Explorer
resolves those notes as far as the offline reference data reaches — a lot file to its record group and
series, a decimal file number to the subject it encodes, a collection to the archive that holds
it — so a citation becomes a shelf you could visit.

ANALYSE
Term frequency over time, cross-reference graphs, person and archival profiles, and a semantic map
of the whole published series. Nearly every chart exports its data as a CSV carrying its full
method statement, and most export as a figure too.

COLLECT
Group documents into collections and projects, annotate them, and export to PDF, DOCX, HTML,
BibTeX or RIS with citations formatted for you.

ON YOUR DEVICE
Volumes, notes and highlights live on your device; notes and collections sync privately through
your own iCloud account. Optional natural-language search runs entirely on-device using Google's
EmbeddingGemma model — an experimental feature, and nothing you type leaves the device.

FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives and
Records Administration (NARA). NARA Catalog data accessed through this app is provided by the
National Archives and is subject to their terms of use.
```

### What is deliberately not in it

- **"Every document."** A full library's index holds **321,749** rows (a device's own count at
  index version 74, on 2026-11-10: the printed documents, the editorial notes, the prose sections
  the parser promotes and the front matter — §5) while the semantic map places
  **314,616** — two different surfaces, two honest numbers, and neither is "every".
  The description says *553 volumes*, which is the one count that is fixed and checkable.
- **Any claim of endorsement by Google.** *"using Google's EmbeddingGemma model"* is the permitted
  form — describe, never brand. Nothing here implies endorsement.
- **Any figure lifted from a planning document.** See §5.
- **"AI-powered."** The on-device model does one thing — turning a typed question into a vector —
  and the feature ships flagged experimental in the app itself. The description says the same.

### Settled before paste (owner, 2026-10-15)

Three sentences of the block said more than the app does. Each was checked against the tree at
`dc17d945`, and the owner chose the wording that replaced each on 2026-10-15 (`Completed/Plan-Of-Record-2026-10-14.md`
§0, decisions 28 to 30). The block above carries the new sentences; what each replaced, and why:

- ***"Nothing you read, search, or write is sent anywhere."*** Now: *"What you read, search and
  write stays with you: notes and collections sync only through your own iCloud account, and the
  app reaches the National Archives' catalog or your Zotero library only when you ask it to."* The app queries the NARA Catalog
  when a reader asks it to (`FRUSExplorer/SourceExplorer/NARACatalogClient.swift`,
  `catalog.archives.gov/api/v2`) and sends a collection to the reader's own Zotero library on
  request (`FRUSExplorer/Zotero/ZoteroAPIClient.swift`, `api.zotero.org`), and the *ON YOUR DEVICE*
  paragraph of the same description says notes and collections sync through iCloud. Accurate
  wording already exists in `Completed/App-Store-Custom-EULA.md`, clause 9 (*Data*), the custom EULA build 51 does not need (it moved there on 2026-10-15, never entered).
- ***"Every chart exports as a figure or as a CSV."*** Now: *"Nearly every chart exports its data
  as a CSV carrying its full method statement, and most export as a figure too."* Both manuals say
  "Not every chart offers a figure", and two do not export at all, the Person Network graph and
  Chronology's distribution chart (`Docs/macOS-User-Manual.md` §15.8, `Docs/iOS-User-Manual.md` §15.8).
- ***"Every document carries the editors' own note saying where it came from."*** Now: *"Most
  documents carry the editors' own note saying where the original came from."*
  `collection-usage-index.json` counts 264,598 source notes paired with a document, in 502 of the
  553 volumes, against 314,616 printed documents: 51 volumes carry none.

### Added 2026-10-17: the editors' theme

`Launch-Marketing-Kit-2026-10-13.md` §1a adds a second theme, *built on the editors' work*, and this
field carries it in two places: a BUILT ON THE EDITORS' WORK section after the disclaimer, which must
stay below it so the "official documentary record" sentence and the disclaimer remain together, and
the READ line's "the editors' headings". The section names the Office of the Historian, which the
disclaimer above it already covers. It says what the editors do in the terms of the series' own
prefaces and claims no figure, so §5 owes it nothing. The owner may cut the section whole; nothing
else in the field depends on it.

*Rewritten 2026-10-27 from the owner's briefing deck (its slide on the series):* the section now
opens with the statute's standard, "a thorough, accurate, and reliable record", with every
deletion marked where it occurs, and says that the Office fulfills it through research in the
classified files of the Department and other agencies and publishes the result as open TEI data.
The statute line is the one the kit's §1a already quotes, and the section still claims no figure.
The disclaimer above it gained *private-capacity* and the scope of the commentary in the same
pass; the description was recounted (the figure in the heading of §2).

The promotional text has an alternate for the theme, 152 / 170, counted the same way:

```
The edited record of U.S. diplomacy, 553 volumes indexed on your device, with tools built on its editors' source notes, cross-references and annotation.
```

### Offered 2026-11-10: a sentence on Editors' Annotations

Since the description was last revised the app gained Editors' Annotations: each volume's page
lists what its editors annotated, and Browse files every volume by those layers (#1859 to #1862,
#1884). The description does not mention it, and nothing in the description is wrong for leaving it
out. If the owner wants it there, the home page's sentence of 2026-11-06 fits at the end of the
BUILT ON THE EDITORS' WORK paragraph, after *an index you can search.*, and brings the field to
**3,584 / 4,000** (160 characters and the space before them):

```
Every volume's page shows what kinds of annotation it carries, even before you download it, and Browse lays out each kind of annotation across the series' eras.
```

The description's block above is the copy of record until the owner chooses. To take the sentence,
add it to that block, change the count in the heading of §2, and run §6's script.

---

## 3. What's New (first release)

**Version 1.0 has no such field.** Apple's reference, read 2026-11-10: "This property isn't
available for the first version of the app but required for all subsequent versions." The text
below is kept for a page that shows the field after all, and as the form of the first update's:
169 / 4,000 characters as pasted.

```
First release.

FRUS Explorer reads, searches and sources the Foreign Relations of the United States series
offline, from the Office of the Historian's own TEI editions.
```

---

## 4. Screenshots and the App Preview

**As of 2026-11-10.** The listing launches without an App Preview (decision 89), so what follows
this paragraph is the preview's capture plan of 2026-08-31, kept for its later pass. The
screenshots are the launch kit's set (`Launch-Marketing-Kit-2026-10-13.md` §3), composed by
`tools/marketing/compose.py` from the captures `tools/marketing/shots.json` names. A store run
writes the 34 frames to `~/Desktop/store`, outside the repository, and the frames each App Store
Connect slot takes to `~/Desktop/store/upload/<preset>/`, numbered in the listing's order: ten for
the 13-inch iPad, ten for the Mac and five for the 6.9-inch iPhone. The three sizes were read on
Apple's Screenshot specifications page that day: 2752 × 2064 is one of the 13-inch iPad's two
landscape sizes, which settles decision 33's check. That page's list of required sizes names the
iPhone's *medium* display, and the page also says a larger set is scaled down, so the run writes
the iPhone's five a second time, scaled to 1206 × 2622, in `upload/iphone-6.3/`, for a slot that
asks for that size itself.

Per §4.1: two capture passes, **the same simulator and resolution in both**.

| Pass | Device state | Shots |
|---|---|---|
| A | Erased | splash → onboarding scope sweep |
| B | Full corpus (already indexed — see below) | search → document → map → Source Explorer |

**Gate B was satisfied when this was written** (2026-08-31: the author's Mac carried all 552
volumes and 316,839 documents), so pass B is unblocked; only pass A needs an erased device. The
library has since gained vol. XVI and been re-indexed twice; confirm 553 volumes in Volumes &
Storage before capturing.

**The `prepareVolumes` trap, which is the most valuable operational line in §4.1.** Switching to
Volume scope fires `BundledCloudVectors.prepareVolumes()`, and until it resolves a volume scope
falls back to the **subseries** list. An early frame therefore shows the *era's* vocabulary and
looks entirely plausible. **Hold for the LensChip before recording.**

**Hero: a live screenshot of the map, not the figure export.** The live view prints its own
disclosure beneath it; the figure export is a research plate with a methods band, which is right for
a journal and wrong for a store.

Any shot showing the map or naming a region carries §5's obligations in the pixels — the app draws
them itself, which is why a live screenshot is safer than a composed one.

---

## 5. Every number in this document, and where it was measured

Not one is quoted from prose.

| Figure | Value | Measured from |
|---|---|---|
| Volumes | 553 | `manifest.json`, entry count |
| Rows in a full index | 321,749 | `SELECT COUNT(*) FROM document_cache` on a copy of the owner's Mac index, 553 volumes at index version 74, taken 2026-11-10 with `quick_check` ok. By the table's two flags: 1,103 front-matter rows and 320,646 others, 8,477 of them editorial notes. This is the device count the row owed until then. Earlier: 321,702 on the iPad simulator at version 71 (A19, 2026-10-21); 316,814 by the parser's replica at version 63 (`tools/page-citations/replica.py`, corpus `99d851c79`, 2026-10-10); 316,839 on a device at 552 volumes (2026-07-30). **No field of the listing uses it.** The launch kit and the README still say *about 317,000* |
| Documents on the map | 314,616 | `semantic-vectors-index.json`, `documentCount` |
| Regions | 140 | `semantic-map-index.json`, `clusters`, re-read 2026-10-15 after B4 (EmbeddingGemma 2's layout; the 300m's held 172) |
| Documents in a region | 226,557 | `documentCount` − `layout.unclusteredCount`, re-read 2026-10-15 (222,348 under the 300m) |
| Documents between regions | 88,059 | `semantic-map-index.json`, `layout.unclusteredCount`, re-read 2026-10-15 (92,268 under the 300m) |
| Series published since | 1861 | `manifest.json`, earliest `publicationDate` |
| Subseries | 107 | `manifest.json`, distinct `subseries` |

Two figures a description must **not** use, recorded so nobody reaches for them:

- **Coverage "1861–1991"** is wrong at the low end. Three volumes carry documents earlier than 1800
  — `frus1872p2v5` reaches **1620** — because FRUS prints historical enclosures in arbitration
  papers. *Published since 1861* is the true and checkable claim; *covering 1861 onward* is not.
- **Any per-artifact count from `CLAUDE.md`.** When this was written its external-citation volume
  count read 284 against 440 in the shipped file (both have since been brought to 441). The app
  recomputes; a store listing cannot.

---

## 6. Re-counting after an edit

```bash
python3 Planning/app-store-connect/build_paste.py
```

The script reads each field's block from this file: the first fenced block under the field's
heading. It counts the text as it will be pasted, the way Apple's reference counts that field:
characters for the name, the subtitle, the promotional text, the description and What's New, and
**bytes** for the keywords and the App Review notes. It exits with an error when a field is over
its limit, when the count this file prints beside a field is not the count it measured, or when a
field holds one of the three characters App Store Connect refused in 1.0 (1776)'s Mac notes (the
gear, the multiplication X and the circled i). Then it writes each field to
`Planning/app-store-connect/paste/`, one line a paragraph, and the field table in
`App-Store-Connect-Entry.md`. With `--check` it writes nothing and exits 1 when a paste file or
the table is out of step with this file.

Until 2026-11-10 this section held a counter with its own copy of the four short fields, which an
edit to a block above could leave behind, and nothing counted the description.

**Count characters, never words, and count the em dash as one.** The failure this step exists to
avoid was a 113-character line proposed for a 30-character field. Where the limit is in bytes an
em dash is three, which is one reason the review notes are plain ASCII.

**And run it rather than trusting a draft, including this one.** Three of the counts first written
into this document were wrong — the promotional text by 4, the keywords by 5, the description by
523 — every one of them estimated rather than measured, in the document whose subject is not
estimating. All were inside their limits, so nothing would have been caught by the field rejecting
it; they were caught by running the counter. That is the whole argument for having it.

---

## 7. App Review notes

**4,000-byte field. This draft is 3,886 / 4,000 ✅**, counted as pasted. The field is on each
platform's version page, under App Review Information, and customers never see it. One text serves
both pages. It is plain ASCII, so that bytes and characters agree and no symbol can be refused.

It is lifted, not written: the first two paragraphs from §2, the downloads and the two optional
services from `Docs/Privacy-Policy.md`, the AI answers from the launch kit's §5.5, and the route
from the TestFlight notes. What the plan of record's §2 asks of it is the model's paragraph
(decision 18) and the not-an-official-product sentence.

```
FRUS Explorer is a research tool for the Foreign Relations of the United States (FRUS) series, the
official documentary record of U.S. foreign policy, which the Department of State's Office of the
Historian has published since 1861. The series is in the public domain, and the Office publishes
it as open TEI data, which the app downloads and reads.

The app is an independent, private-capacity project. It is not an official product of the Office
of the Historian or the U.S. Department of State. The description, the first screenshot of each
set, the Support page and the app's About screen say so.

NO ACCOUNT
There is no sign-in, no purchase, no advertising and no tracking. The app is free and collects no
data.

TO REVIEW
1. Launch the app. Onboarding offers the whole series, a subseries or a single volume. Choose A
   Single Volume and pick any volume: it is a few megabytes. The whole series is 553 volumes,
   about 3.3 GB, and is not needed for review.
2. On iPhone and iPad the tabs are Browse, Search, Research, Collections and Settings. On the Mac
   the same tools are in the main window, the Corpus Browser (Shift-Command-B), the Search window
   and the Analytics menu.
3. Open a document from Browse or Search. Select text to highlight it or add a note. The Research
   rail holds Cite, Sources, Graph, Related and Summary.
4. Editors' Annotations (Browse > Annotations on iPhone and iPad, the Corpus Browser's sidebar on
   the Mac), the series dashboards and each volume's page work before any download.

WHAT THE APP DOWNLOADS
- Volumes: public TEI XML files from the Office of the Historian's repository on GitHub
  (HistoryAtState/frus), and their figure images from static.history.state.gov.
- A small semantic match file for each volume, from the developer's public repository on GitHub
  (joshbotts/frus-semantic-vectors).
- Optional, and only when the user chooses Download Search Model: Google's EmbeddingGemma 2, an
  open model under the Apache 2.0 license, 310 MB, from a release of that same repository. There
  is no agreement to accept. The file is model weights (GGUF), not code; the app reads it with the
  llama.cpp library built into the app. It turns a typed question into numbers on the device for
  Search > Meaning, which the app labels experimental.

ON-DEVICE AI
Summarize this Document uses Apple Intelligence on the device and records on each summary that a
model wrote it. Search by meaning uses the optional model above. Neither sends a document or a
question anywhere. Without Apple Intelligence or the model, the rest of the app works.

OPTIONAL SERVICES, EACH WITH THE USER'S OWN KEY
- National Archives Catalog (catalog.archives.gov): Source Explorer can look up the records a
  document's source note cites, with the user's own free API key, entered in Settings > System >
  Connections. Without a key the app sends the Catalog nothing, and Source Explorer still resolves
  source notes from reference data inside the app.
- Zotero (api.zotero.org): sends citations to the user's own Zotero library, with the user's own
  key.
Neither is needed to use the app. FRUS Explorer is not affiliated with, endorsed by, or sponsored
by the National Archives and Records Administration.

ICLOUD AND BACKGROUND WORK
Notes, highlights, tags and collections sync through the user's own private iCloud database
(CloudKit). The developer runs no server. Background processing finishes indexing downloaded
volumes and, when the user asks for it, a batch of summaries. On iPhone and iPad a Live Activity
shows the indexing queue.

THE CONTENT
The documents are historical government records: diplomatic correspondence and memoranda about
war, weapons and political conflict as well as trade and treaties.

MAC
The app is sandboxed. Its entitlements are outgoing network connections (the downloads above),
user-selected files (exports and imports through the system's panels) and iCloud.
```

**Two things the notes leave to the owner.** They do not offer App Review a National Archives key:
if a reviewer asks to see a catalog lookup, the owner can answer with one. And the paragraph on
the content states the subject only; the age rating's answers are in the entry sheet, and are the
owner's to give.
