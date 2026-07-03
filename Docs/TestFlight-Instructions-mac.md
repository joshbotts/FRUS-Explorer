# Welcome to FRUS Explorer (Mac)

FRUS Explorer makes research in the *Foreign Relations of the United States* series easier. This guide assumes you're new to the app.

## Step 1 — Download some volumes (do this first)

The app starts empty. Open the Corpus Browser (⇧⌘B), choose a subseries (a date range, e.g. "1964–1968"), and download two or three volumes; each is then indexed. Let indexing finish before judging things — Settings (⌘,) → **Index Health** shows status. Results and definitions fill in as it completes (a few minutes the first time). You can also download from anywhere: an undownloaded volume shows a **Download Volume** button, and a cross-reference into a volume you don't have offers to download it rather than dead-ending.

## Step 2 — Read a document; follow its links and its source

Open a volume, select a document, and read (Previous/Next to move; hover toolbar icons for tooltips). Click anything underlined or colored:

- A **person's name** → a panel with context and mention count.
- A **term** ("UAR," "POL") → its definition.
- A **footnote number** → the footnote text.
- A **reference** ("Document 42," "pp. 311–313") → navigates there, even across volumes (or opens a relationship graph if that volume isn't downloaded).
- A **web link** → your browser.

For a corpus-wide index, the Corpus Browser lists **People** at the top. Also click a document's **source note**: **Source Explorer** resolves where it came from (archives, lot files, presidential libraries, CIA) with finding-aid links. To find other documents from that same archival source (lot file, central file, record-group series, or library), right-click a document → **Archival Neighbors** (also available per-entry in a volume's Sources list and in Source Explorer).

Then browse to a volume's **Sources** section (in its front matter): resolved collections show a **catalog link** (columns icon) to the National Archives record, and a collection cited by several volumes shows a **Cited in N volumes** control that lists them. Try both and report anything that misfires or looks wrong.

## Step 3 — The cross-reference graph (its own window)

From a document's toolbar, click **Cross-References**: each circle is a document on a date timeline, arrows point citing→cited, bigger = more connected. Hover to preview, click to pin, double-click to re-center; scroll to zoom, drag to pan. Switch Timeline/Network and Depth (1–3).

## Step 4 — Chronology and Analytics (toolbar)

- **Chronology** (calendar) — pick a date range and read every document in it, grouped by date, with a distribution chart.
- **Corpus Analytics** (chart) — chart how often a term appears over time or by subseries/volume; click a bar for a scoped search.

Both distribution charts colour-code by top source volume; a **Chart colors** menu in each toolbar sets how many distinct colours show before the rest fold into "Other" (the global default lives in Display settings).

## Step 5 — Search, organize, summarize, export

Search (⌘F) opens its own window that stays open while you read — a phrase or AND/OR, scoped to volumes. Open documents in new windows and revisit via History. Add highlights, notes, and tags (the Research window, ⌘⌥R, gathers them). On an Apple Silicon Mac, **Summarize** a document on-device — or queue a subseries with the **Background Summarizer** (Settings → Advanced → Summarization).

**Collections** (⇧⌘K) were substantially reworked — please exercise them. The **manager** is where you compose: add documents, insert your own **section headings** and **rich-text prose** (bold/italic/underline/colour), open a row's **inspector (ⓘ)** to see a document's notes/highlights/tags/summary/source, and set the **Composition** (default body depth, footnotes, table-of-contents style, highlights, notes, word cloud) once on the collection — it's now an expandable group at the **top of the document list** (no longer a popover) — with per-document and per-section body-depth overrides. **Export** then just picks a format: PDF, HTML, DOCX (all now show your headings and prose), **BibTeX**, or a native **`.fruscollection`** file — an editable copy you can share; open one back in with **Import Collection…** or by **double-clicking the file** (it offers to download any volumes you're missing; your notes travel only if you opt in). A saved-search **smart collection** can be frozen into an editable one with **Create Static Snapshot**. **Send to Zotero** is one menu: a connected account (Settings → Zotero) sends over the web, otherwise it writes an RIS file. New this build: a **live preview** (the **eye** toolbar button) renders the collection beside the editor exactly as its HTML export while you edit — please exercise it, including **Render All** on a large collection and the **Download** bar when a volume is missing. Also new: **Add Documents…** in the toolbar (⇧⌘A) gathers documents four ways — search, browse a volume, **paste citations or history.state.gov links** (each line should resolve to a document or say clearly why not — please try pasting real footnotes), or a tag — so exercise all four and confirm additions land at the end of the list, with an **Also in collection** badge on repeats. Newest this build: **nested sections and front matter** — right-click a heading to Indent/Outdent (up to 3 levels), Rename, or delete it with or without its contents; drag a heading and verify its **whole section moves as one block**; collapse sections with the chevron; and set the subtitle/author fields under the name plus the rich-text introduction and colophon in the **Front Matter** group, then confirm all of it (stepped headings, nested table of contents, title page) survives PDF/HTML/DOCX export and a `.fruscollection` round-trip.

Open a **word cloud** from the toolbar: the Word Cloud window has an in-window scope picker — pick any scope (document, volume, subseries, corpus, collection, tag, saved search) or choose **Date Range**, which reveals inline start/end date pickers in the scope bar. Tune the cloud's font and density, and manage hidden words, in Settings → **Word Cloud**; to hide a single word on the spot, right-click it. A date-range cloud and Chronology hand off to each other — **Word Cloud for this range** builds a cloud from the dates you're viewing in Chronology, and **View in Chronology** (in the cloud's options menu) opens that same range in Chronology.

## Feedback

Report anything that crashes, freezes, or behaves unexpectedly — especially misfiring links/source notes, graph and chart interactions, the **word cloud** (wrong-kind or unfiltered terms, font/density that looks off, a date-range cloud that doesn't match Chronology), **Collections** (do section headings and rich prose survive PDF/HTML/DOCX export? does a `.fruscollection` round-trip — export, share, double-click to open — reconstruct the collection, bring the Collections window forward with it selected, and avoid duplicating on a second double-click, with missing-volume prompts? does **Create Static Snapshot** work?), **Send to Zotero** (does the one menu behave connected vs. not — and do tags and notes arrive?), the People index, multi-window behavior, AI summaries, and searches returning too few/many.

**Reporting an issue:** include your macOS version, the volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thank you for testing!
