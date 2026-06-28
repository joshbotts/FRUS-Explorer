# Welcome to FRUS Explorer (iOS)

FRUS Explorer helps you research the *Foreign Relations of the United States* series. This guide assumes you've never used the app.

## Step 1 — Download some volumes (do this first)

The app starts empty. Open the Browse tab, pick a subseries (a date range, e.g. "1964–1968"), and download two or three volumes; the app then indexes each for search.

Let indexing finish before judging things. Settings → **Index Health** shows the status and a quick integrity check. Search results and glossary definitions fill in as indexing completes (a few minutes the first time).

## Step 2 — Read a document; tap its links and its source

In Browse, open a volume, tap a document, and read; use Previous/Next to move between them. In the text, tap anything underlined or colored:

- A person's name → a card with front-matter context and how many documents mention them.
- An abbreviation or term ("UAR," "POL") → its front-matter definition.
- A small raised footnote number → the footnote text.
- A reference to a document or page ("Document 42," "pp. 311–313") → jumps there, even in another volume; if it isn't downloaded, you'll see a relationship graph instead.
- A web link → opens in your browser.

To look someone up across the whole corpus, open Browse → **People** (the row above the subseries list): an alphabetical, searchable index of everyone mentioned in your indexed volumes. Tap a name for their description, a mention count, and **Find all mentions**.

From the toolbar, **Source Explorer** resolves where the document came from (NARA record group, lot file, decimal/central file, presidential library, or CIA collection), links to the right finding aid, and lists other documents from the same source.

Tap many of these (and a few source notes); report any that do nothing, error, or land wrong.

## Step 3 — Explore the cross-reference graph

From a document's toolbar, tap Cross-References to see what cites what:

- Each circle is a document, placed on a timeline by date; arrows point from citing to cited; bigger circles are more connected.
- Switch Timeline/Network layouts and Depth (1–3 hops). On iPhone, a List/Graph control switches between the canvas and a scrollable list.
- Tap a circle for details and to open it. Same-period documents bundle into "N docs" clusters — tap to expand. Drag the strip beneath the graph to zoom a date range.

## Step 4 — The bigger picture: Chronology and Analytics (Browse tab)

Two Browse-tab toolbar buttons open corpus-wide tools as sheets:

- **Chronology** (calendar icon) — pick a date range and read every document in it, grouped by date, with a distribution chart anchored to your range. Wide-span notes and out-of-range dates get their own sections.
- **Corpus Analytics** (chart icon) — chart how often a term appears over time, or by subseries/volume; tap a bar to jump into a scoped search.

## Step 5 — Search, organize, summarize, export

Use the Search tab for full-text queries (a phrase, or AND/OR; scope to specific volumes); long result sets load more as you scroll. Add highlights, notes, and tags as you read — the Research tab collects them. With Apple Intelligence, try **Summarize with AI** (on-device); to summarize many documents at once, turn on **background summarization** in Settings → Research → Summarization. Gather documents into Collections you can **export** (PDF, HTML, DOCX, Zotero/RIS), and use a document's **Share** menu (or a collection's export) to copy a **citation** or **Send to Zotero**.

## Step 6 — What's new to try in this build

- **Word Cloud** — Open one for a document (Share/More), a volume or subseries (browser context menu), a collection, a tag, a saved search, or the whole corpus. Try the **lens chips** (People, Places, Concepts, Sentiment, …), tap a word to search it, and export it. Tune the filters and add hidden words in Settings → Research → **Word Cloud**.
- **Zotero (Web API)** — In Settings → Integrations → **Zotero**, paste a Zotero Web API key, then use a document's **Share → Send to Zotero Library** (or a collection) to push it — with your tags and notes — straight into your Zotero library.
- **Sync settings across devices** — Settings → iCloud Sync has a new toggle. Turn it on to mirror your word-cloud filters, citation style, and a few other preferences to your other devices (off by default).

## What feedback to provide

Anything that crashes, freezes, looks broken, or behaves unexpectedly — especially links and source notes that misfire, graph interactions, the Chronology and Analytics charts, the **word cloud** (a lens showing the wrong kind of term, or words you'd expect filtered out), **Send to Zotero** (does the document arrive with its tags and notes?), the People index (names that look merged, split, or out of place), AI summaries (including very long documents), and searches returning too few or too many results. Tips appear to help you find features; tell me if anything's confusing.

## How to report an issue

Include: your device and OS version, the volume and document number (top of the screen), what you tapped, expected, and got. Screenshots help a lot.

Thank you for testing — clear, reproducible reports make the app better!
