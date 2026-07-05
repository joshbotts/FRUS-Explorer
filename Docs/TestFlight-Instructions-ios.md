# Welcome to FRUS Explorer (iOS)

FRUS Explorer helps you research the *Foreign Relations of the United States* series. This guide assumes you've never used the app.

## What's new in build 27

Since your last build (26), the headline additions to exercise are:

- **A one-time re-index on update** — see the warning just below if you already have volumes downloaded.
- **Person Analytics** — a new surface under Browse → Analysis Tools (mention trends by era, multi-person comparisons, and a co-mention network graph).
- **Cross-Reference Analytics** — a new surface under Browse → Analysis Tools (most-referenced documents, degree-distribution histogram, volume-to-volume heat matrix, PageRank influence).
- **"About the Series" dashboards** — four offline dashboards in the in-app Research Guide that work with **no index downloaded**, so you can try them immediately after installing.
- **A "% of documents" toggle** on the Corpus Analytics By-Year / By-Decade term-frequency charts.
- **Collections polish** — the collection note now collapses to an "Add a note" affordance, and Sort by Date offers two modes.

Detailed test steps for each are in the sections below.

> **Returning testers — read this first (one-time re-index):** If you already have volumes downloaded, this update performs a **ONE-TIME automatic re-index** of them. The search index moved to **version 21** so that page-number references like "see p. 427" now resolve to the correct document in the Cross-Reference graph and in Cross-Reference Analytics. Expect indexing activity on your first launch after updating — watch **Settings → Index Health** for status. Search, cross-references, and the analytics surfaces below may be incomplete until it finishes.

## Step 1 — Download some volumes (do this first)

The app starts empty. Open the Browse tab, pick a subseries (a date range, e.g. "1964–1968"), and download two or three volumes; each is then indexed for search. You can start a download from anywhere an undownloaded volume appears — tap **Download Volume** on the volume's page, use the Download action in the browser list, or follow a cross-reference into an undownloaded volume and accept the offer to download it. Let indexing finish before judging things — Settings → **Index Health** shows status. Results and definitions fill in as it completes (a few minutes the first time). Browser rows and page headers show complete volume and chapter titles, so an older subseries (e.g. the 1860s–1900s annual volumes, whose titles run to whole paragraphs) reads in full on iPhone rather than being cut off.

## Step 2 — Read a document; tap its links and its source

Open a volume, tap a document, and read (Previous/Next to move between them). Tap anything underlined or colored:

- A **person's name** → a card with context and mention count.
- A **term** ("UAR," "POL") → its definition.
- A **footnote number** → the footnote text.
- A **reference** ("Document 42," "pp. 311–313") → jumps there, even in another volume; if it isn't downloaded, you get a relationship graph.
- A **web link** → your browser.

For a corpus-wide index, open Browse → **People**. From the toolbar, **Source Explorer** resolves where a document came from (NARA record group, lot file, decimal/central file, presidential library, CIA) and links to the finding aid — source notes now exist for **every era, including modern volumes (1955 onward)**, so try documents from a recent volume too. Where a note carries classification markings ("Secret; Nodis"), a small **chip** shows them — in Source Explorer, next to the source footnote in the reading view, and on search results. **Archival Neighbors** (long-press a document in the graph, a search result, or a volume's document list) lists other indexed documents from the same archival source; an **empty list means nothing in your indexed volumes cites that source**, not a failure — please report any that still look wrong. From Source Explorer, also try **Browse Archival Collections** — a searchable, repository-grouped list of every collection FRUS cites — and open a few **Collection** views (aliases, catalog link, series-wide citing volumes, "in your library" counts from your own index).

Also open a volume's **Sources** section (in its front matter): resolved collections show a **catalog link** (columns icon) to the National Archives record, and each recognized entry shows an Archival Neighbors count — a badge with a number, a subdued **0** (honest: your index has none), or nothing when the entry couldn't be keyed. Entries the bundled collection authority tracks show a **Collection · cited in N volumes** control. Tap many of these; report any counts, links, or collections that misfire or look wrong.

## Step 3 — The cross-reference graph

From a document's toolbar, tap **Cross-References**: each circle is a document on a date timeline, arrows point citing→cited, bigger = more connected. Switch Timeline/Network and Depth (1–3 hops); on iPhone a List/Graph control toggles the view. Tap a circle to open it; drag the strip below to zoom a date range.

For a corpus-wide view, open Browse → **Analysis Tools** → **Cross-Reference Analytics**. Exercise the **most-referenced documents** (by in-degree — how many other documents cite them), the **citation degree-distribution histogram**, the **volume-to-volume citation heat matrix** (the top connected volumes), and the offline **PageRank "influence"** landmark documents. This is also where to confirm the build-27 fix: page-number references like "see p. 427" now land on the correct document — please report any that still resolve to the wrong place.

## Step 4 — Chronology and Analytics (Browse toolbar)

On the Browse toolbar, the analysis tools live together under one **Analysis Tools** menu (a chart icon):

- **Chronology** (calendar) — pick a date range and read every document in it, grouped by date, with a distribution chart.
- **Corpus Analytics** (chart) — chart how often a term appears over time or by subseries/volume; tap a bar for a scoped search. New in build 27: a **"% of documents"** normalization toggle on the By-Year and By-Decade charts reads a term as a share of the corpus for each period rather than a raw count — toggle it and confirm the axis and values switch between count and percentage.
- **Person Analytics** (new in build 27) — a **Trends / Network** surface. *Trends* shows the most-mentioned people by era, a multi-person **mention-trajectory comparison** (search and pick up to **5** people), and a two-person **relationship-dynamics** co-mention-over-time chart. *Network* draws a person **co-mention ego-network graph** (a focus person plus their top co-mentioned partners). Try picking real people and report anyone whose mentions look wrong or missing.
- **Cross-Reference Analytics** (new in build 27) — corpus-wide citation analysis (see Step 3): most-referenced documents, degree-distribution histogram, volume-to-volume heat matrix, and PageRank influence.
- **Word Cloud** — a cloud of the corpus's most frequent terms (see Step 5).

In both the Chronology and Corpus Analytics distribution charts you can adjust how many source volumes get their own colour before the rest fold into "Other" — use **Chart colors** in the toolbar, or set the default in Settings → General → Display.

## "About the Series" dashboards (new in build 27 — work offline)

Open Settings → **FRUS Research Guide** and go to the **About the Series** category. Its four dashboards render **with no index downloaded** — even mid-onboarding — so you can try them immediately after installing, before your volumes finish (or before you download any):

- **Production & Timeliness** — a publication-lag scatter (publication year × years-to-publish) with an evolving timeliness-target step line (no target before 1961, then 15 years, 20, and 30 as the directives and 1991 statute changed it), a volumes-per-print-year bar chart, and a cumulative-volumes curve.
- **Geographic Emphasis** — regional share over time across the six State Department regional bureaus (stacked), region totals, and the top-covered countries.
- **Archival Sourcing** — the provenance mix over coverage decades (central decimal file → lot files, presidential libraries, Central Foreign Policy File), overall composition, and note density by decade.
- **Administration Profiles** — per **president** (Nixon and Ford are distinct; Cleveland appears twice): documents per administration, volumes per administration-year coloured by party, coverage span, and a per-administration volume list showing each volume's document **proportion**, with an include/exclude **editorial-notes** toggle and an any-overlap attribution caveat.

Cross-cutting controls to exercise on every dashboard: an editable **start/end year range**, and a per-chart **"View as table"** pop-up (with **Copy** as CSV). Please report any figure that looks wrong (lag, region, provenance, or administration counts) and whether the year-range and table/CSV controls behave.

## Step 5 — Search, organize, summarize, export

Search (Search tab) takes a phrase or AND/OR, scoped to volumes; long lists load as you scroll. Add highlights, notes, and tags (the Research tab collects them). With Apple Intelligence, try **Summarize with AI** (on-device); for many at once, enable **background summarization** in Settings → Research → Summarization.

**Collections** were substantially reworked — please exercise them. The editor is now **its own screen** (tap a collection to open it; back to leave) and **saves as you edit** — there's no Save button, and backing out of an untouched new collection discards it. Document rows show the **title, volume, and date** once the volume is indexed. On iPhone, name/description live in a collapsible **Details** group and **Composition** in a group below the list; on iPad they're in a toolbar-toggled **details panel**. In the manager you compose: add documents, insert your own **section headings** and **rich-text prose** (bold/italic/underline/colour, now applied from a **formatting toolbar above the keyboard** — plus a **Link** button that turns selected text into a real hyperlink in HTML/DOCX exports), tap **ⓘ** on a row to inspect a document's notes/highlights/tags/summary/source, and set the **composition** (default body depth, footnotes, table-of-contents style, highlights, notes, word cloud) once on the collection — with per-document and per-section body-depth overrides. **Export** then just picks a format: PDF, HTML, DOCX (all now show your headings and prose), **BibTeX**, or a native **`.fruscollection`** file — an editable copy you can share; open one back in with **Import Collection…** or by opening the file (it offers to download any volumes you're missing; your notes travel only if you opt in). A saved-search **smart collection** can be frozen into an editable one with **Create Static Snapshot**. **Send to Zotero** is one menu: a connected account (Settings → Zotero) sends over the web, otherwise it writes an RIS file. A **live preview** — the **Outline | Preview** toggle on iPhone, the **eye** toolbar button on iPad — shows the collection exactly as its HTML export while you edit; exercise it, including **Render All** on a large collection and the **Download** bar when a volume is missing. **Add Documents…** in the editor gathers documents four ways — search, browse a volume, **paste citations or history.state.gov links** (each line should resolve to a document or say clearly why not — try pasting real footnotes), or a tag — so exercise all four and confirm additions land at the end of the list, with an **Also in collection** badge on repeats. **Nested sections and front matter**: long-press a heading to Indent/Outdent (up to 3 levels), Rename, or delete it with or without its contents; drag a heading and verify its **whole section moves as one block**; collapse sections with the chevron; and set a subtitle, author line, rich-text introduction, and colophon in Details, then confirm all of it (stepped headings, nested table of contents, title page) survives PDF/HTML/DOCX export and a `.fruscollection` round-trip. **Excerpts and the read-write inspector**: insert **excerpt quotations** all three ways (the add menu's **Add Highlighted Passages…**, **Add Selection as Excerpt** from a document's selected text, and **Insert as Excerpt** on a highlight row in the ⓘ inspector), then exercise the inspector's controls (headnote pick, per-document Highlights/Notes/Source note/Footnotes/Summary prompt/Related documents overrides, per-highlight checkboxes, and a heading's **Section Defaults…**) and confirm each choice shows up in the live preview and all three rich exports. The add menu's **Apparatus** submenu inserts **five generated blocks** (Bibliography, Chronology, Sources & Archives, Persons Index, Thematic Index) — add every one into a collection, export all three rich formats, and confirm each block's content matches the collection's documents (and that an empty block prints an explanatory line, not a bare heading). Exported AI text is **labeled** — export a collection containing a summary-only document or a headnote and confirm the "AI-generated summary · Apple Intelligence (on-device)" caption appears under it in PDF, HTML, and DOCX and in the live preview (and does **not** appear anywhere in a collection with no AI summaries). Document rows are **pure reports** — each shows status **chips** (body depth, note count, "Highlights off", "Headnote", "See also"), and **all editing** (body depth and note selection included) lives in the **ⓘ inspector** (on iPad it opens as a trailing panel beside the list). One behaviour to keep in mind: **research notes export by default when notes are enabled — deselect individual notes in the entry inspector to leave them out.**

New in build 27: the **collection note** field now stays collapsed as an **"Add a note"** affordance until you tap it (iOS/iPad editor) — confirm it appears collapsed on a fresh collection and expands on tap. Also new: **Sort by Date** offers two modes on the iPad/iOS toolbar — **"Across the Whole Collection"** (one global date sort) and **"Within Each Section"** (documents sort by date inside each heading's section, never crossing a heading). With a sectioned collection, try both and confirm the within-section mode keeps documents inside their headings.

Open a **word cloud** to see the most frequent terms for a document, volume, subseries, collection, tag, saved search, the whole corpus, or a date range. Long-press a word to hide it; tune the cloud's font and density and manage hidden words in Settings → Research → **Word Cloud**. From a date-range cloud you can jump straight to Chronology for that range, and from Chronology you can build a cloud for the range you're viewing.

## Feedback

Report anything that crashes, freezes, or behaves unexpectedly — especially misfiring links/source notes, graph interactions, the charts, the **word cloud** (wrong-kind terms in a lens, words you'd expect filtered, or the font/density and date-range behaving oddly), **Collections** (do section headings and rich prose survive PDF/HTML/DOCX export? does a `.fruscollection` round-trip — export, share, import — reconstruct the collection, and do missing-volume prompts appear? does **Create Static Snapshot** work?), **Send to Zotero** (does the one menu do the right thing connected vs. not — and do tags and notes arrive?), the People index (names merged/split/misplaced), AI summaries (including very long documents), and searches returning too few/many results.

For the build-27 additions, please also report: **Person Analytics** and **Cross-Reference Analytics** (wrong or missing people or documents, broken graphs/histograms/heat matrix); the **About the Series** dashboards (wrong lag/region/provenance/administration figures, and whether the year-range and **View as table** / Copy-CSV controls behave); the Corpus Analytics **"% of documents"** toggle (does the axis and value switch cleanly between count and percentage?); whether the one-time **re-index on update** completed cleanly (watch Settings → **Index Health**); and — the reason for that re-index — whether **page-number references** ("see p. 427") now resolve to the correct document in the Cross-Reference graph and Cross-Reference Analytics.

**Reporting an issue:** include your device and OS version, the volume/document number (top of screen), what you tapped, expected, and got. Screenshots help. Thank you for testing!
