# Welcome to FRUS Explorer (iOS)

FRUS Explorer helps you research the *Foreign Relations of the United States* series. This guide assumes you've never used the app.

## Step 1 — Download some volumes (do this first)

The app starts empty. Open the Browse tab, pick a subseries (a date range, e.g. "1964–1968"), and download two or three volumes; each is then indexed for search. You can start a download from anywhere an undownloaded volume appears — tap **Download Volume** on the volume's page, use the Download action in the browser list, or follow a cross-reference into an undownloaded volume and accept the offer to download it. Let indexing finish before judging things — Settings → **Index Health** shows status. Results and definitions fill in as it completes (a few minutes the first time).

## Step 2 — Read a document; tap its links and its source

Open a volume, tap a document, and read (Previous/Next to move between them). Tap anything underlined or colored:

- A **person's name** → a card with context and mention count.
- A **term** ("UAR," "POL") → its definition.
- A **footnote number** → the footnote text.
- A **reference** ("Document 42," "pp. 311–313") → jumps there, even in another volume; if it isn't downloaded, you get a relationship graph.
- A **web link** → your browser.

For a corpus-wide index, open Browse → **People**. From the toolbar, **Source Explorer** resolves where a document came from (NARA record group, lot file, decimal/central file, presidential library, CIA) and links to the finding aid. To find other documents drawn from the same archival source (lot file, central file, series, or library), long-press a document — in the graph, a search result, or a volume's document list — and choose **Archival Neighbors**. Tap many of these; report any that misfire.

Also open a volume's **Sources** section (in its front matter): resolved collections show a **catalog link** (columns icon) to the National Archives record, and a collection cited by several volumes shows a **Cited in N volumes** control. Try both and report anything that misfires or looks wrong.

## Step 3 — The cross-reference graph

From a document's toolbar, tap **Cross-References**: each circle is a document on a date timeline, arrows point citing→cited, bigger = more connected. Switch Timeline/Network and Depth (1–3 hops); on iPhone a List/Graph control toggles the view. Tap a circle to open it; drag the strip below to zoom a date range.

## Step 4 — Chronology and Analytics (Browse toolbar)

On the Browse toolbar, the three analysis tools live together under one **Analysis Tools** menu (a chart icon):

- **Chronology** (calendar) — pick a date range and read every document in it, grouped by date, with a distribution chart.
- **Corpus Analytics** (chart) — chart how often a term appears over time or by subseries/volume; tap a bar for a scoped search.
- **Word Cloud** — a cloud of the corpus's most frequent terms (see Step 5).

In both the Chronology and Corpus Analytics distribution charts you can adjust how many source volumes get their own colour before the rest fold into "Other" — use **Chart colors** in the toolbar, or set the default in Settings → General → Display.

## Step 5 — Search, organize, summarize, export

Search (Search tab) takes a phrase or AND/OR, scoped to volumes; long lists load as you scroll. Add highlights, notes, and tags (the Research tab collects them). With Apple Intelligence, try **Summarize with AI** (on-device); for many at once, enable **background summarization** in Settings → Research → Summarization.

**Collections** were substantially reworked — please exercise them. The editor is now **its own screen** (tap a collection to open it; back to leave) and **saves as you edit** — there's no Save button, and backing out of an untouched new collection discards it. Document rows show the **title, volume, and date** once the volume is indexed. On iPhone, name/description live in a collapsible **Details** group and **Composition** in a group below the list; on iPad they're in a toolbar-toggled **details panel**. In the manager you compose: add documents, insert your own **section headings** and **rich-text prose** (bold/italic/underline/colour), tap **ⓘ** on a row to inspect a document's notes/highlights/tags/summary/source, and set the **composition** (default body depth, footnotes, table-of-contents style, highlights, notes, word cloud) once on the collection — with per-document and per-section body-depth overrides. **Export** then just picks a format: PDF, HTML, DOCX (all now show your headings and prose), **BibTeX**, or a native **`.fruscollection`** file — an editable copy you can share; open one back in with **Import Collection…** or by opening the file (it offers to download any volumes you're missing; your notes travel only if you opt in). A saved-search **smart collection** can be frozen into an editable one with **Create Static Snapshot**. **Send to Zotero** is one menu: a connected account (Settings → Zotero) sends over the web, otherwise it writes an RIS file. New this build: a **live preview** — the **Outline | Preview** toggle on iPhone, the **eye** toolbar button on iPad — shows the collection exactly as its HTML export while you edit; please exercise it, including **Render All** on a large collection and the **Download** bar when a volume is missing.

Open a **word cloud** to see the most frequent terms for a document, volume, subseries, collection, tag, saved search, the whole corpus, or a date range. Long-press a word to hide it; tune the cloud's font and density and manage hidden words in Settings → Research → **Word Cloud**. From a date-range cloud you can jump straight to Chronology for that range, and from Chronology you can build a cloud for the range you're viewing.

## Feedback

Report anything that crashes, freezes, or behaves unexpectedly — especially misfiring links/source notes, graph interactions, the charts, the **word cloud** (wrong-kind terms in a lens, words you'd expect filtered, or the font/density and date-range behaving oddly), **Collections** (do section headings and rich prose survive PDF/HTML/DOCX export? does a `.fruscollection` round-trip — export, share, import — reconstruct the collection, and do missing-volume prompts appear? does **Create Static Snapshot** work?), **Send to Zotero** (does the one menu do the right thing connected vs. not — and do tags and notes arrive?), the People index (names merged/split/misplaced), AI summaries (including very long documents), and searches returning too few/many results.

**Reporting an issue:** include your device and OS version, the volume/document number (top of screen), what you tapped, expected, and got. Screenshots help. Thank you for testing!
