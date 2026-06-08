# FRUS Explorer for iOS and iPadOS — User Manual

> **Foreign Relations of the United States Explorer** — *Research the official record of U.S. foreign policy since 1861*

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation and First Launch](#2-installation-and-first-launch)
3. [The Main Interface](#3-the-main-interface)
4. [Browsing the Corpus](#4-browsing-the-corpus)
5. [Searching Documents](#5-searching-documents)
6. [Reading Documents](#6-reading-documents)
7. [Annotating and Tagging](#7-annotating-and-tagging)
8. [Cross-Reference Graph](#8-cross-reference-graph)
9. [Citation Lookup](#9-citation-lookup)
10. [Collections and Export](#10-collections-and-export)
11. [AI Summarization](#11-ai-summarization)
12. [Source Explorer](#12-source-explorer)
13. [Corpus Analytics](#13-corpus-analytics)
14. [Research Projects](#14-research-projects)
15. [Settings](#15-settings)
16. [iPad-Specific Features](#16-ipad-specific-features)
17. [Touch Gestures Reference](#17-touch-gestures-reference)
18. [The FRUS Research Guide](#18-the-frus-research-guide)

---

## 1. Introduction

FRUS Explorer brings the complete *Foreign Relations of the United States* documentary series to your iPhone and iPad as a fully offline, searchable research tool. The series — published since 1861 and now comprising more than 560 volumes — is the official declassified record of American foreign policy: diplomatic cables, policy memos, meeting transcripts, and intelligence reports from every era of U.S. history.

FRUS Explorer lets you:

- **Download and index** any subset of the corpus for instant full-text search, right on your device.
- **Read** documents in their original TEI-encoded form, with footnotes, editorial notes, and cross-references fully rendered for the iPhone and iPad screen.
- **Annotate** with research notes, inline highlights, and custom tags — all of which sync across your devices.
- **Summarize** long documents on-device using Apple Intelligence.
- **Export** curated collections of documents as formatted PDF, HTML, or Word (DOCX) documents, ready to share or print.
- **Cite** correctly using the State Department's recommended citation style, and share citations directly from the document view.
- **Visualize** how documents reference one another through an interactive, touch-friendly network graph.
- **Analyze** term frequency across the corpus with interactive charts, and jump fluidly between a chart and a search.

All of your research data — notes, tags, collections, highlights, and projects — syncs automatically across every device signed into the same iCloud account, so you can start reading on your iPhone and pick up exactly where you left off on your iPad.

This manual covers FRUS Explorer on iPhone and iPad from the ground up. No familiarity with any other version of the app is assumed.

---

## 2. Installation and First Launch

### System Requirements

FRUS Explorer requires iOS or iPadOS 26 or later. Full-text search and document rendering work on all supported devices; AI summarization (Section 11) additionally requires a device with Apple Intelligence enabled.

### Installation

Install FRUS Explorer from the App Store. Search for "FRUS Explorer" or follow a direct link from the publisher.

`[SCREENSHOT: App Store page showing FRUS Explorer with Get/Install button]`

### Onboarding

The first time you launch FRUS Explorer, a short onboarding flow walks you through initial setup.

**Step 1 — Welcome**

A brief overview of the FRUS series appears, including the scope of the corpus (number of volumes, date range, total document count). You can proceed immediately, or tap the embedded link to read more about the series at history.state.gov in FRUS Explorer's built-in browser (see "The Embedded Browser" below).

`[SCREENSHOT: Onboarding welcome screen with corpus overview statistics on iPhone]`

**Step 2 — Add Volumes**

Choose how much of the corpus to download to your device now. You can always add or remove volumes later from **Settings → Volumes**.

| Option | Description |
|--------|-------------|
| **Entire Corpus** | All 560+ published volumes (several GB; downloading may take a while depending on your connection and how much free storage your device has) |
| **A Subseries** | One publication era, e.g., *1969–1976* (Nixon/Ford) or *1977–1980* (Carter) |
| **A Single Volume** | One specific volume chosen from a grouped picker |

`[SCREENSHOT: Onboarding scope picker with three options and subseries list visible]`

Estimated storage requirements appear before you confirm — useful on space-constrained iPhones. If you start the download while offline, it queues automatically and resumes once you're back online.

**Step 3 — Ready**

Optionally create your first research project — give it a name and a research question. Projects help you organize notes, tags, and collections around a single research effort (see Section 14). You can skip this step and create projects later.

`[SCREENSHOT: Onboarding "Ready" screen with optional project creation form]`

Tap **Finish**. FRUS Explorer opens to the Browse tab and begins downloading and indexing your selected volumes in the background — you can keep using the app while this happens.

### The Embedded Browser

Wherever FRUS Explorer shows a link to an external resource — onboarding, the About screen, the Research Guide, education content, Source Explorer, or NARA Catalog Lookup — it opens in a built-in browser sheet rather than leaving the app. This keeps you in your research session: dismiss the sheet with the close button or a downward swipe to return exactly where you were.

`[SCREENSHOT: Embedded browser sheet showing a history.state.gov page with a Done button]`

---

## 3. The Main Interface

FRUS Explorer on iPhone and iPad is organized around a **tab bar** with five tabs. Each tab is a self-contained area of the app; switching tabs preserves your place in each one, so you can move freely between browsing, searching, and your research workspace without losing your spot.

`[SCREENSHOT: iPhone tab bar showing Browse, Search, Research, Collections, Settings]`

| Tab | Icon | Purpose |
|-----|------|---------|
| **Browse** | books.vertical | Navigate the corpus by subseries, volume, and document; switch your active research project; jump to Corpus Analytics |
| **Search** | magnifyingglass | Full-text search across your downloaded volumes; look up a document directly by citation |
| **Research** | note.text | Your personal research workspace — all notes, highlights, and tagged documents in one place, organized by collection, tag, or highlight color |
| **Collections** | tray.2 | Build, edit, and export curated sets of documents |
| **Settings** | gear | iCloud status, display preferences, downloads and storage, tags, summarization, integrations, the Research Guide, and About |

### 3.1 The Indexing Banner

When volumes are downloading or being indexed for search, a banner appears just above the tab bar. It shows progress for the current volume (and, when several are queued, your position in the queue and an estimated time to completion). Tapping a name mentioned in the banner — such as a person discovered while indexing — can jump you straight to a search for that name.

`[SCREENSHOT: Indexing banner above the tab bar showing progress for a volume]`

When indexing finishes, the banner becomes a brief summary card offering to search the newly indexed volume. A small dot badge also appears on the **Browse** tab whenever downloaded volumes are still waiting to be indexed.

`[SCREENSHOT: Indexing summary card with "Search this volume" action]`

### 3.2 Live Activity (iPhone 14 Pro and later)

On iPhones with a Dynamic Island, starting a download presents a **Live Activity** — a persistent, glanceable progress indicator that stays visible from the Lock Screen, the Dynamic Island, and other apps, so you can track indexing progress without returning to FRUS Explorer.

`[SCREENSHOT: Dynamic Island showing FRUS Explorer indexing progress]`

`[SCREENSHOT: Lock Screen Live Activity card showing volume download progress]`

### 3.3 The Document Toolbar

When you open a document for reading, its toolbar gathers every contextual action — annotation tools, citation tools, navigation, and AI features — into the system overflow ("**•••**") menu at the top of the screen. Tap it to reveal:

| Action | What it does |
|--------|--------------|
| **Add Research Note** | Attach a note to this document |
| **Tag Document** | Apply or remove custom tags |
| **Create Highlight** | Enter highlight mode to mark up passages (see Section 7.2) |
| **Read / Research** (segmented control) | Switch between distraction-free Read mode and the Research panel layout (see Section 6.2) |
| **View Citation** | Open the formatted-citation popover |
| **Copy Citation** | Copy the formatted citation text to the clipboard |
| **Share Citation** | Open the system share sheet with both the formatted citation and its canonical history.state.gov link, ready to send as one message |
| **Add to Collection** | File this document into one or more collections |
| **Cross-References** | View this document's outbound and inbound cross-references, and look any referenced person up in the NARA catalog |
| **Source Explorer** | Open this document's archival source note in Source Explorer |
| **Open in New Window** | (iPad, in a multi-window/Stage Manager session) open this document in its own window |
| **Summarize with AI** | Generate or view an on-device AI summary |
| **Show/Hide Notes Panel** | Toggle the notes panel alongside the document body |

`[SCREENSHOT: Document view with the "•••" overflow menu open, listing all toolbar actions]`

---

## 4. Browsing the Corpus

The **Browse** tab is where you navigate the FRUS corpus by its natural structure: subseries (publication eras), volumes, and individual documents.

`[SCREENSHOT: Browse tab showing a list of subseries]`

### 4.1 Navigating the Hierarchy

Tap a subseries — for example, *1969–1976* — to see the volumes published within it. Tap a volume to see its table of contents: the documents it contains, each labeled with its document number, heading, and date.

`[SCREENSHOT: Volume table of contents showing a list of documents with dates]`

A **breadcrumb trail** at the top of the screen shows your current position in the hierarchy and lets you jump back to any earlier level with a tap.

`[SCREENSHOT: Breadcrumb trail showing Subseries > Volume > Document]`

Volumes that haven't been downloaded yet show a download affordance; tap it to queue the volume (see Settings → Volumes for managing downloads in bulk).

### 4.2 Filtering to Downloaded Volumes

A toggle in the Browse toolbar limits the list to volumes you've already downloaded — handy when you want to browse only what's available offline, such as on a flight or in the field.

`[SCREENSHOT: Browse toolbar with the "Downloaded only" filter toggle highlighted]`

### 4.3 Switching Research Projects

A **project picker** in the Browse toolbar lets you set your active research context. Tap it to choose:

- **Global Context** — no active project; notes, tags, and highlights you create are not associated with any particular project
- Any of your existing projects, shown with a checkmark beside the active one
- **Manage Projects** — opens the full project management screen (see Section 14)

`[SCREENSHOT: Project picker menu open, showing Global Context and a list of projects with checkmarks]`

Whatever project is active follows you throughout the app — new notes, tags, and highlights you create are automatically associated with it, and your Research tab can be filtered to show only that project's material.

### 4.4 Jumping to Corpus Analytics

A chart-icon button in the Browse toolbar opens **Corpus Analytics** as a sheet (see Section 13), letting you explore term-frequency trends across the corpus without leaving your place in the browser.

---

## 5. Searching Documents

The **Search** tab provides full-text search across every volume you've downloaded and indexed, powered by the same search engine used for the State Department's own archive — ranked by relevance using the BM25 algorithm with English-language stemming (so searching for "negotiate" also matches "negotiation," "negotiated," and so on).

`[SCREENSHOT: Search tab with results list and a query in the search field]`

### 5.1 Basic Search

Type a word or phrase into the search field and results appear as you type, each showing a highlighted snippet of matching text, the document's citation, and its date. Tap a result to open the document, scrolled to the matching passage.

### 5.2 Search Syntax

The search field supports a small query syntax for more precise results:

| Syntax | Effect |
|--------|--------|
| `word1 word2` | Matches documents containing both words (in any order) |
| `"exact phrase"` | Matches the exact phrase |
| `word1 OR word2` | Matches documents containing either word |
| `-word` | Excludes documents containing that word |

`[SCREENSHOT: Search field showing a phrase query in quotes with matching results]`

### 5.3 Filters

Tap the filter control to narrow your search by:

- **Volume or subseries** — restrict to one or more specific volumes
- **Date range** — restrict to documents dated within a span of years
- **Person** — restrict to documents mentioning a specific indexed person

`[SCREENSHOT: Search filter sheet showing volume, date range, and person filters]`

### 5.4 Timeline View

Toggle **Timeline** from the sort control to see your search results arranged chronologically along a timeline rather than as a ranked list — useful for tracing how a topic developed over a span of years.

`[SCREENSHOT: Search results in Timeline view, documents arranged along a date axis]`

### 5.5 Visualizing a Search in Corpus Analytics

When a search returns more results than can be displayed in full, FRUS Explorer offers to **Visualize in Corpus Analytics** — tapping this hands your search terms and any active date-range filter to the Analytics tab, pre-seeded so you can immediately chart the term's distribution across the corpus and, if needed, narrow your date range before returning to search with a tighter result set (see Section 13.3).

`[SCREENSHOT: Search results banner offering "Visualize in Corpus Analytics"]`

### 5.6 Saving Searches

Tap the save icon to store your current query and filters for quick reuse later. Saved searches appear in a dedicated list accessible from the Search tab and sync across your devices via iCloud.

`[SCREENSHOT: Saved searches list]`

### 5.7 Finding a Document by Citation

Tap the citation-lookup button (a magnifying glass over quotation marks) in the Search toolbar to open **Citation Lookup** — paste or type a citation string (e.g., `FRUS 1969–1976, Volume I, Document 42`) and FRUS Explorer parses it and jumps directly to that document, even in a volume you haven't browsed to before. See Section 9 for more on citations.

`[SCREENSHOT: Citation Lookup sheet with a pasted citation string and a "Go" button]`

---

## 6. Reading Documents

Tapping any document — from Browse, Search, Research, or a Collection — opens it in the document view, where the original TEI-encoded text is rendered as readable, well-formatted prose: headings, datelines, paragraphs, footnotes, editorial notes, and cross-reference links all appear as the State Department originally published them, adapted for your screen.

`[SCREENSHOT: Document view showing a rendered FRUS document with heading, dateline, and body text]`

### 6.1 Navigating Within a Document

Footnote markers and cross-reference links are tappable. Tapping a footnote marker scrolls to (or pops up) its note text; tapping a cross-reference link jumps to the referenced document if it's in your downloaded corpus, or offers to look it up otherwise.

### 6.2 Read Mode and Research Mode

The **Read / Research** segmented control in the document toolbar switches between two layouts:

- **Read** — a clean, distraction-free view of the document body, ideal for close reading. Read mode also enables **edge-tap page-turning** (see 6.3).
- **Research** — shows the document alongside your notes panel, so you can read and annotate side by side.

`[SCREENSHOT: Read/Research segmented control in the document toolbar]`

### 6.3 Edge-Tap Page-Turning (Read Mode)

While in Read mode, invisible tap zones along the left and right edges of the screen let you move to the previous or next document in the volume — much like turning pages in an e-book reader. Tap near the left edge to go back one document, or near the right edge to advance to the next one. This lets you read straight through a volume without returning to the table of contents or using the back button. (These tap zones are intentionally hidden in Research mode, where the edges of the screen are needed for the notes panel and other controls.)

`[SCREENSHOT: Document view in Read mode with annotated edge-tap zones for previous/next navigation]`

### 6.4 Display Preferences

Adjust font size, line spacing, and other reading preferences from **Settings → General → Display** (see Section 15).

---

## 7. Annotating and Tagging

FRUS Explorer's research tools let you build a personal layer of analysis on top of the primary-source text — notes, highlights, and tags — all of which sync across your devices via iCloud.

### 7.1 Research Notes

From the document toolbar, choose **Add Research Note** to attach a free-form note to the current document. Notes appear in the notes panel (visible directly in Research mode, or toggled on in Read mode) and are collected across your whole library in the **Research** tab.

`[SCREENSHOT: Notes panel showing a research note attached to a document]`

If you have an active research project, new notes are automatically associated with it; from Global Context, notes aren't tied to any particular project.

### 7.2 Highlights

Choose **Create Highlight** from the document toolbar to enter highlight mode. Select a passage of text with your finger (or Apple Pencil on iPad) and choose one of four highlight colors — yellow, green, blue, or pink. Highlights appear as colored overlays directly in the text, are visible immediately without needing a separate "highlight mode" to view them, and survive document re-renders (such as display-preference changes) because their positions are tracked by stable text offsets rather than on-screen coordinates.

`[SCREENSHOT: Document body with yellow and blue highlights visible inline]`

`[SCREENSHOT: Highlight color picker showing the four available colors]`

Highlights you create are included automatically when you export a collection that contains the highlighted document — see Section 10.3.

### 7.3 Tags

Choose **Tag Document** from the document toolbar to apply one or more custom tags — short labels you define yourself (e.g., "Berlin Crisis," "needs follow-up," "key source"). Manage your full tag list, including colors and names, from **Settings → Research → Tags**. Tags let you build cross-cutting collections of documents that share a theme, regardless of which volume they come from.

`[SCREENSHOT: Tag picker sheet showing existing tags with a "Create new tag" option]`

### 7.4 The Research Tab

The **Research** tab is your single workspace for everything you've annotated. A sidebar lets you browse your material by:

- **All Notes** — every research note you've written, most recent first
- **By Collection** — documents grouped by the collections that contain them
- **By Tag** — documents grouped by the custom tags you've applied
- **By Highlight Color** — documents grouped by which highlight color appears in them

`[SCREENSHOT: Research tab sidebar showing All Notes, By Collection, By Tag, and By Highlight Color sections]`

Selecting any sidebar item shows the matching documents; tapping one opens it directly in the document view, scrolled to the relevant note or highlight.

---

## 8. Cross-Reference Graph

Many FRUS documents reference one another — a memo might respond to a cable, or a meeting record might cite an earlier policy paper. FRUS Explorer indexes these relationships and visualizes them as an interactive **network graph**.

Open the graph from a document's **Cross-References** menu, or from a dedicated entry point in your browsing flow. Each node represents a document; lines between nodes represent a reference from one to the other. Pinch to zoom, drag to pan, and tap a node to see a summary of that document and an option to open it.

`[SCREENSHOT: Cross-reference graph showing a network of connected document nodes with one selected]`

The graph can also highlight references to specific people — useful for tracing how often two officials' communications cross paths across the corpus.

`[SCREENSHOT: Cross-reference graph filtered to show references involving a specific person]`

---

## 9. Citation Lookup

FRUS Explorer formats citations to match the State Department's own recommended style for the series, and gives you several ways to use them.

### 9.1 Viewing a Citation

From any open document, choose **View Citation** in the toolbar to see the fully formatted citation string in a popover, ready to read or screenshot.

`[SCREENSHOT: Citation popover showing a formatted FRUS citation string]`

### 9.2 Looking Up a Document by Citation

From the Search tab, tap the citation-lookup button to open **Citation Lookup**: paste or type any citation string and FRUS Explorer parses it — recognizing volume, document number, subseries, and other common citation formats — and opens the matching document directly, even one you haven't browsed to before.

`[SCREENSHOT: Citation Lookup sheet parsing a pasted citation and showing a matched document]`

### 9.3 Copying and Sharing Citations

From the document toolbar:

- **Copy Citation** copies the formatted citation text to your clipboard, ready to paste into a paper, email, or notes app.
- **Share Citation** opens the system share sheet with a single message that combines the formatted citation *and* its canonical `history.state.gov` link — so whoever receives it can both read the citation and open the original source online with one tap. This works with any share destination your device supports: Messages, Mail, Notes, third-party apps, AirDrop, and more.

`[SCREENSHOT: System share sheet showing a combined citation-and-link message ready to send]`

---

## 10. Collections and Export

**Collections** let you assemble curated sets of documents — for a research paper, a teaching unit, a presentation, or simply your own organized reading list — and export them as polished, shareable documents.

### 10.1 Building a Collection

Open the **Collections** tab and tap **New Collection**, give it a name and an optional description, then add documents to it either from the collection editor's search, or by choosing **Add to Collection** from any open document's toolbar.

`[SCREENSHOT: Collection editor showing a list of added documents with reorder handles]`

Drag to reorder documents within a collection; the order you choose becomes the order they appear in any export.

### 10.2 Export Formats

Tap **Export** from a collection to choose a format:

| Format | Best for |
|--------|----------|
| **PDF** | Print-ready output with consistent pagination, suitable for sharing or archiving |
| **HTML** | Web-viewable output that preserves rich formatting and is easy to post or embed |
| **DOCX (Word)** | Editable output for further work in Word, Pages, Google Docs, or similar |

`[SCREENSHOT: Export format picker showing PDF, HTML, and DOCX options]`

### 10.3 Export Options

Before exporting, you can customize:

- **Table of contents style** — list each document by its formatted citation, or by its header and dateline
- **Body depth** — include the full document text, an AI-generated summary only (see Section 11), or a compact citation-and-notes index/outline
- **Footnotes** — include all footnotes, only the archival source note, or none
- **Inline highlights** — when enabled, any highlights you've created on the included documents are annotated directly in the exported text: as colored `<mark>` spans in HTML, as background shading in PDF, and as highlighted runs in DOCX (note that DOCX's limited highlight palette renders blue highlights as cyan and pink highlights as magenta — the closest available named colors)
- **Research notes** — optionally include your attached notes below each document's body

`[SCREENSHOT: Export options sheet showing table-of-contents style, body depth, footnote, and highlight toggles]`

Once exported, the system share sheet appears so you can save the file, print it, or send it anywhere your device supports.

---

## 11. AI Summarization

FRUS Explorer can generate concise summaries of long documents entirely **on-device**, using Apple's on-device AI (Apple Intelligence) — no document text ever leaves your device for this purpose.

### 11.1 Summarizing a Document

Choose **Summarize with AI** from a document's toolbar. A summary is generated (this can take a few moments on first use for a given document) and displayed alongside the original text. Summaries are saved automatically and indexed for full-text search, so a later search can match text that appears only in a summary.

`[SCREENSHOT: Document view showing a generated AI summary panel beneath the toolbar]`

### 11.2 Summarization Prompts

FRUS Explorer ships with a standard summarization prompt, and you can create your own from **Settings → Research → Summarization** — for example, a prompt tuned to extract names and dates, or one that produces a brief for a specific kind of research question. Choose which prompt to use when generating a summary, and manage your saved prompts from the same Settings screen.

`[SCREENSHOT: Summarization prompt picker and prompt management screen]`

### 11.3 Summaries in Exports

When building a collection export, choosing **Summary only** as the body depth (Section 10.3) generates summaries on demand for any included document that doesn't already have one for the selected prompt — producing a compact briefing-style export instead of a full-text one.

---

## 12. Source Explorer

Every FRUS document is drawn from original archival material, and each carries a **source note** describing exactly where it came from — which National Archives record group, collection, and box, for instance. **Source Explorer** turns those source notes into a navigable view of the underlying archival record.

Open Source Explorer from a document's toolbar. It displays the parsed source-note information and offers a direct link to look the corresponding record up in the **National Archives (NARA) online catalog**, opened in FRUS Explorer's embedded browser.

`[SCREENSHOT: Source Explorer view showing parsed archival source information with a NARA catalog link]`

If you have a NARA API key configured (see **Settings → Integrations**), Source Explorer can enrich its display with live catalog data such as digitized-item availability.

---

## 13. Corpus Analytics

**Corpus Analytics** charts how often terms appear across the FRUS corpus over time — a quick way to spot when a topic rose or fell in official attention, or to compare how two terms trend against each other.

Open Analytics from the chart-icon button in the Browse tab toolbar (Section 4.4), or via the handoff described below.

`[SCREENSHOT: Corpus Analytics view showing a term-frequency chart across a date range]`

### 13.1 Running an Analysis

Enter one or more terms and an optional date range, then tap to chart their frequency across the indexed corpus. Results display as an interactive line chart you can pinch to zoom and drag to scrub through specific years.

### 13.2 From a Chart to a Search

Tap a point or segment on the chart to **View in Search** — this opens the Search tab with that term and the corresponding year range pre-filled as a date filter, letting you read the actual documents driving that data point.

`[SCREENSHOT: Analytics chart with a "View in Search" action on a selected data point]`

### 13.3 From a Search to a Chart

The relationship runs both ways: when a search returns more matches than can be shown in full, Search offers **Visualize in Corpus Analytics** (Section 5.5) — tapping it opens Analytics pre-seeded with your search terms and date filter, so you can chart the term's distribution and narrow your date range before returning to a more focused search.

---

## 14. Research Projects

**Projects** let you organize your notes, tags, highlights, and collections around a specific research effort — a paper, a course, a long-term interest — keeping that material separate from your general reading.

### 14.1 Creating and Managing Projects

Open **Manage Projects** from the project picker in the Browse tab toolbar (Section 4.3), or create your first project during onboarding. Give each project a name and an optional research question or description; you can edit these at any time.

`[SCREENSHOT: Project management screen showing a list of projects with edit and delete actions]`

### 14.2 Switching Active Projects

The project picker in the Browse toolbar shows your current context — either **Global Context** (no project) or the name of your active project — and lets you switch instantly. Whatever is active when you create a note, apply a tag, or make a highlight determines which project (if any) that material is filed under.

`[SCREENSHOT: Project picker showing the active project with a checkmark]`

### 14.3 Filtering Your Research by Project

In the **Research** tab, you can filter your notes, tags, and highlights to show only material associated with a specific project — useful when you're deep in one research effort and don't want material from other projects cluttering the view.

> **Note:** Unlike on other platforms, iOS and iPadOS manage projects through the Browse tab's project picker rather than through a dedicated Settings pane — Settings focuses on app-wide preferences, while project context is treated as part of your active browsing and research session.

---

## 15. Settings

The **Settings** tab gathers every app-wide preference, organized into clearly labeled sections.

`[SCREENSHOT: Settings tab showing the full list of sections]`

| Section | Contains |
|---------|----------|
| **iCloud** | Sync status for your research data (notes, tags, collections, highlights, projects) |
| **General** | **Display** preferences (font size, line spacing, and related reading options) and **Search Defaults** (default filters and sort order for new searches) |
| **Volumes** | **Downloads** (queue and manage which volumes are on your device), **Storage** (see how much space the corpus occupies and free it up), and **Sideload** (import volume files manually, e.g., from a file you've obtained separately) |
| **Research** | **Tags** (create, rename, recolor, and delete your custom tags), **Summarization** (manage AI summarization prompts), and **Log Sessions** (diagnostic logging for troubleshooting) |
| **Integrations** | **NARA API Key** (configure your National Archives catalog key for Source Explorer) and **Reset** (clear cached or local app state) |

Two standalone rows complete the tab:

- **FRUS Research Guide** — opens the standalone research-methodology guide as a sheet (see Section 18)
- **About** — version information, acknowledgments, and links (opened in the embedded browser where applicable)

---

## 16. iPad-Specific Features

iPad's larger screen and multitasking model unlock several capabilities beyond the core iPhone experience.

### 16.1 Inspector Panels

On iPad, several views present supplementary information — such as a document's notes, tags, or cross-references — in a side **inspector panel** rather than a full-screen sheet, so you can see your primary content and its supporting material at the same time. Show or hide an inspector with the inspector toggle in the relevant toolbar.

`[SCREENSHOT: iPad split view showing a document with an inspector panel open alongside it]`

### 16.2 Multi-Window and Stage Manager

On iPads that support Stage Manager, FRUS Explorer can open documents in their own windows — choose **Open in New Window** from a document's toolbar to pop it out, then arrange it alongside other FRUS Explorer windows or other apps. This is especially useful for comparing two documents side by side, or keeping a reference document visible while you work in another.

`[SCREENSHOT: Stage Manager session showing two FRUS Explorer document windows side by side]`

### 16.3 Keyboard and Trackpad Support

When a hardware keyboard or trackpad is connected, FRUS Explorer supports standard navigation shortcuts (such as moving between search results or document sections) and trackpad gestures for scrolling, selecting text for highlights, and navigating back and forward — letting iPad function as a capable laptop replacement for extended research sessions.

### 16.4 Apple Pencil

When using Apple Pencil to select text for a highlight (Section 7.2), selection is precise enough for fine-grained passages — useful for marking a single clause or a specific name within a longer sentence.

---

## 17. Touch Gestures Reference

| Gesture | Where | Effect |
|---------|-------|--------|
| **Tap** | Search result, document list row, graph node | Open the item |
| **Tap and hold (long-press)** | Document text | Begin a text selection for highlighting or copying |
| **Tap near screen edge** | Document body, Read mode | Turn to the previous (left edge) or next (right edge) document in the volume |
| **Swipe down** | Sheets (citation popover, export options, embedded browser, etc.) | Dismiss |
| **Pinch** | Cross-reference graph, Analytics chart | Zoom in or out |
| **Drag** | Cross-reference graph, Analytics chart, collection document list | Pan the view, or reorder a list item |
| **Swipe left on a row** | Lists (saved searches, notes, collection items) | Reveal quick actions such as delete |

---

## 18. The FRUS Research Guide

The **FRUS Research Guide** is a standalone, in-app guide to historical research methodology — covering how to approach the FRUS series as a primary source, how to build a research question, how to use citations rigorously, and other practical guidance for working with declassified diplomatic records.

Open it from **Settings → FRUS Research Guide**. It opens as a sheet you can read at your own pace, with internal links that open in the embedded browser (Section 2) so you never lose your place.

`[SCREENSHOT: FRUS Research Guide opened as a sheet, showing a methodology section with embedded links]`

You'll also find contextual links into the Research Guide from **Source Explorer** and **NARA Catalog Lookup** — for example, a link explaining how to interpret an archival record group while you're looking at one — so guidance appears exactly when it's useful, not just as a separate reference document.

---

*FRUS Explorer is an independent research tool and is not affiliated with or endorsed by the U.S. Department of State. The underlying FRUS document series is in the public domain.*
