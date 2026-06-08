# FRUS Explorer for macOS — User Manual

> **Foreign Relations of the United States Explorer** — *Research the official record of U.S. foreign policy since 1861*

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation and First Launch](#2-installation-and-first-launch)
3. [The Main Window](#3-the-main-window)
4. [Browsing the Corpus](#4-browsing-the-corpus)
5. [Searching Documents](#5-searching-documents)
6. [Reading Documents](#6-reading-documents)
7. [Annotating and Tagging](#7-annotating-and-tagging)
8. [Cross-Reference Graph](#8-cross-reference-graph)
9. [Citation Lookup](#9-citation-lookup)
10. [Collections and Export](#10-collections-and-export)
11. [AI Summarization](#11-ai-summarization)
12. [Source Explorer](#12-source-explorer)
13. [Analytics](#13-analytics)
14. [Projects and Tags](#14-projects-and-tags)
15. [Settings](#15-settings)
16. [Reading History and the Research Guide](#16-reading-history-and-the-research-guide)
17. [Keyboard Shortcuts](#17-keyboard-shortcuts)

---

## 1. Introduction

FRUS Explorer brings the complete *Foreign Relations of the United States* documentary series to your Mac as a fully offline, searchable research tool. The series — published since 1861 and now comprising more than 560 volumes — is the official declassified record of American foreign policy: diplomatic cables, policy memos, meeting transcripts, and intelligence reports from every era of U.S. history.

FRUS Explorer lets you:

- **Download and index** any subset of the corpus for instant full-text search.
- **Read** documents in their original TEI-encoded form, with footnotes, editorial notes, and cross-references fully rendered.
- **Annotate** with research notes, highlights, and custom tags.
- **Summarize** long documents using on-device Apple Intelligence.
- **Export** curated collections of documents as formatted PDF or HTML.
- **Cite** correctly using the State Department's recommended citation style.
- **Visualize** how documents reference one another through an interactive network graph.
- **Analyze** term frequency across the corpus with interactive charts.

All research data (notes, tags, collections, highlights) syncs automatically across your devices via iCloud.

---

## 2. Installation and First Launch

### System Requirements

FRUS Explorer requires macOS 26 or later. Full-text search and document rendering work on all supported Macs; AI summarization (Section 11) additionally requires an Apple Silicon Mac with Apple Intelligence enabled.

### Installation

Install FRUS Explorer from the Mac App Store or from the `.dmg` distributed directly from the project website.

`[SCREENSHOT: Mac App Store page showing FRUS Explorer with Install button]`

### Onboarding

When you launch FRUS Explorer for the first time, an onboarding flow walks you through initial setup.

**Step 1 — Welcome**

A brief overview of the FRUS series appears, including the scope of the corpus (number of volumes, date range, total document count). You can proceed immediately or follow the link to learn more about the series at history.state.gov.

`[SCREENSHOT: Onboarding welcome screen with corpus overview statistics]`

**Step 2 — Add Volumes**

Choose how much of the corpus to download now. You can always add or remove volumes later from Settings.

| Option | Description |
|--------|-------------|
| **Entire Corpus** | All 560+ published volumes (~several GB; downloading may take time depending on connection speed) |
| **A Subseries** | One publication era, e.g., *1969–1976* (Nixon/Ford) or *1977–1980* (Carter) |
| **A Single Volume** | One specific volume chosen from a grouped picker |

`[SCREENSHOT: Onboarding scope picker showing three options with subseries list visible]`

Estimated storage requirements are shown before you confirm. If you are offline at first launch, the download queue will start automatically once connectivity is restored.

**Step 3 — Ready**

Optionally create your first research project — give it a name and a research question. Projects let you organize notes, tags, and collections around a single research initiative (see Section 14). You can skip this step and create projects later.

`[SCREENSHOT: Onboarding "Ready" screen with optional project creation form]`

Click **Finish**. FRUS Explorer opens its main window and begins downloading and indexing in the background.

---

## 3. The Main Window

`[SCREENSHOT: Annotated full-width view of the macOS main window with all four layers labeled]`

The main window has four distinct areas.

### 3.1 Toolbar

The toolbar runs across the top of the window.

**Center — Document Title**

When a document is open, a compact `volumeId/documentId` title (e.g., `frus1969-76v01/d42`) appears here, updating automatically as you navigate. This condensed format keeps the title short enough that the toolbar's other controls don't collapse into the overflow chevron — the main window also enforces a 980×600 minimum size for the same reason.

**Right-side toolbar buttons**

| Button | Shortcut | Opens |
|--------|----------|-------|
| **Search** | ⌘F | Full-text search window |
| **Graph** | — | Cross-reference graph for the current document |
| **Info** | — | Citation and metadata popover for the current document |
| **Research** | ⌘⌥R | Research window (all annotated documents) |
| **Collections** | ⇧⌘K | Collections management window |
| **Corpus** | ⇧⌘B | Corpus browser (volume hierarchy) |
| **Analytics** | — | Term-frequency analytics window |

`[SCREENSHOT: Toolbar close-up with each button labeled]`

### 3.2 Research Strip

Directly below the toolbar, the research strip is always visible when a document is open. It provides quick access to the annotation tools most researchers use on every document:

- **Add / Edit Note** — Open the note editor for this document.
- **Highlight** — Enabled when you have selected text in the document body. Click to save the selected passage as a colored highlight. The button is grayed out when no text is selected.
- **Citation** — Open the citation popover.
- **Tags** — Apply or remove user tags.

`[SCREENSHOT: Research strip shown beneath toolbar with a document open]`

### 3.3 Document View

The large central area displays the currently open document. If no document is open, a placeholder ("Select a document to begin") is shown.

Documents are rendered from TEI XML into native SwiftUI, matching the typography and structure of the history.state.gov website. As you navigate — through search results, cross-references, or the corpus browser — FRUS Explorer maintains a full navigation history. Use the standard macOS Back (⌘[) and Forward (⌘]) gestures or the toolbar arrows to move through your reading history.

`[SCREENSHOT: Document view showing a rendered FRUS document with footnotes and source note]`

### 3.4 Status Bar

The status bar at the bottom of the main window provides at-a-glance information about background tasks:

- **Indexing progress** — Volume name and percentage complete during initial indexing.
- **iCloud sync** — Current CloudKit sync state: idle (checkmark), syncing (spinner), succeeded, or sync error with full error detail in a tooltip. Two additional warnings may appear:
  - **Zone Missing** (red) — the iCloud private sync zone is absent; records cannot upload or download. Force-quit and relaunch to trigger zone recreation, or use Reset iCloud Sync in Settings.
  - **Not Signed In** (orange) — iCloud account is unavailable; data will not sync until you sign in via System Settings → Apple ID.
- **iCloud Keychain** — Availability of NARA API key sync across devices.

`[SCREENSHOT: Status bar detail showing indexing progress indicator]`

### 3.5 Separate Window Scenes

FRUS Explorer opens specialized tools in their own windows so you can keep a document open in the main window while working elsewhere. Windows are persistent — closing and reopening them restores their previous size and position.

| Window | Shortcut |
|--------|----------|
| Search | ⌘F |
| Corpus Browser | ⇧⌘B |
| Cross-Reference Graph | (toolbar button) |
| Source Explorer | (tap source note link) |
| Collections | ⇧⌘K |
| Research | ⌘⌥R |
| Analytics | (toolbar button) |
| History | (History menu → "Complete History…") |
| FRUS Research Guide | (Help menu) |
| Settings | ⌘, |

---

## 4. Browsing the Corpus

Open the **Corpus Browser** (⇧⌘B) to navigate the FRUS series as a hierarchy.

`[SCREENSHOT: Corpus browser window open alongside the main window, showing the subseries list]`

### 4.1 Navigation Levels

**Corpus view** — The top level lists every publication subseries, together with totals for volumes, documents, and the date range covered.

`[SCREENSHOT: Corpus-level view showing subseries list with document counts]`

**Subseries view** — Click a subseries to see the volumes it contains. Each volume entry shows its title, editors, publication date, and whether it has been downloaded and indexed.

`[SCREENSHOT: Subseries view for "1969-1976" showing volumes with download status badges]`

**Volume view** — Click a volume to see its front matter, chapters, and appendices. Each chapter entry shows the number of documents it contains.

`[SCREENSHOT: Volume detail view showing chapter list with document counts]`

**Chapter / Compilation view** — Click a chapter to see individual document listings with their dateline, source note, and document number.

`[SCREENSHOT: Chapter view listing documents with datelines]`

### 4.2 Downloading Volumes

Any volume that has not been downloaded shows a download button. Click it to add the volume to the download queue. Progress appears in the status bar and in **Settings → Corpus → Storage**. Downloaded volumes are indexed automatically on completion.

`[SCREENSHOT: Volume entry in browser with the download button highlighted]`

### 4.3 Filtering the Browser

A filter bar at the top of the Corpus Browser lets you narrow the display by:

- **Date range** — Slide to restrict volumes to a particular period.
- **Subject tags** — Pick from the bundled subject-tag taxonomy to show only volumes tagged with relevant topics.

---

## 5. Searching Documents

Press **⌘F** to open the Search window, or click the Search toolbar button.

`[SCREENSHOT: Search window showing keyword field, filter controls, and results list]`

### 5.1 Basic Search

Type your query into the search field and press Return. Results update in real time as you refine the query.

FRUS Explorer searches across:
- Document full text
- Headings and source notes
- Your research notes
- Generated summaries
- User tag names

### 5.2 Query Syntax

| Syntax | Example | Effect |
|--------|---------|--------|
| Plain keywords | `berlin crisis` | Matches documents containing both words (AND implied) |
| Quoted phrase | `"cold war"` | Exact phrase match |
| Boolean AND | `kissinger AND détente` | Both terms required |
| Boolean OR | `kissinger OR rodgers` | Either term |
| Boolean NOT | `vietnam NOT laos` | Excludes term |
| Prefix wildcard | `negoti*` | Matches negotiate, negotiated, negotiating, etc. |

English stemming is applied automatically, so searching for *negotiate* also matches *negotiated* and *negotiating*.

> **Note:** Suffix wildcards (e.g., `*tion`) are not supported. Use prefix wildcards only.

### 5.3 Advanced Filters

Click **Filters** in the Search window to expand additional filter controls.

`[SCREENSHOT: Search window with the Filters panel expanded, showing all filter options]`

| Filter | Description |
|--------|-------------|
| **Date Range** | Restrict results to documents dated within a range |
| **User Tags** | Restrict to documents you have tagged yourself |
| **Summaries** | *All*, *Specific prompt*, or *None* (documents with no generated summary) |
| **Research Notes** | *All documents* or *Documents with notes only* |
| **Document Type** | Include or exclude editorial notes |

All active filters are shown as chips at the top of the results list; click any chip to remove that filter.

### 5.4 Timeline View

Toggle **Timeline** in the Search window to display results on a chronological axis rather than a ranked list. This view is useful for understanding the temporal distribution of documents matching a query.

`[SCREENSHOT: Timeline view showing documents plotted chronologically with zoom controls]`

Pinch or use the scroll wheel to zoom the timeline; drag to pan.

### 5.5 Saving Searches

Click **Save Search** to bookmark the current query and all active filters. Saved searches appear in a sidebar in the Search window for instant re-running.

`[SCREENSHOT: Search window sidebar showing a list of saved searches]`

Saved searches can also be linked to Collections to create *smart collections* that auto-populate at export time (see Section 10.3).

### 5.6 Visualizing a Search in Corpus Analytics

When a query returns more results than the Search window can display in full, a banner offers to **Visualize in Corpus Analytics**. Clicking it opens the Analytics window (Section 13) pre-seeded with your search terms and any active date-range filter, so you can chart the term's distribution across the corpus and narrow the date range before returning to a more focused search.

`[SCREENSHOT: Search results banner offering "Visualize in Corpus Analytics" above a capped result list]`

---

## 6. Reading Documents

Click any document — in search results, the corpus browser, or a cross-reference — to open it in the main window's document view.

`[SCREENSHOT: Full document view showing rendered TEI content with labeled regions]`

### 6.1 Document Structure

Each rendered document shows:

- **Header** — Document number, classification header, participants, and date.
- **Dateline** — Location and date at the top of the document body.
- **Source Note** — Archival provenance, shown below the dateline.
- **Body** — Paragraphs, numbered footnotes, editorial notes, tables, and lists, all faithfully rendered from the TEI source.
- **Summary Strip** — If a generated summary exists for this document, it appears in a strip above the body (see Section 11).
- **Tags Section** — Subject tag chips and your user tag chips appear at the bottom. Click any tag to run a search filtered to that tag.

### 6.2 Interactive Elements Within Documents

| Element | Appearance | Action |
|---------|-----------|--------|
| Person reference | Underlined person name | Click to open Person Index entry |
| Glossary term | Styled term | Click to open Terms & Abbreviations entry |
| Cross-reference | Numbered or inline link | Click to jump to the referenced document |
| Source note | Text at top of document | Click to open Source Explorer (Section 12) |

`[SCREENSHOT: Document close-up showing a person reference, glossary term, and cross-reference link all visible]`

### 6.3 Navigation History

FRUS Explorer tracks every document you open in the current session. Use **⌘[** (Back) and **⌘]** (Forward) to move through your reading history, just as in a web browser.

---

## 7. Annotating and Tagging

### 7.1 Research Notes

Research notes are freeform text attached to a specific document. They sync across all your devices via iCloud.

**To add a note:**
1. Open the document.
2. Click **Add Note** in the research strip (or press ⌘⌥N), or click the **Add Note** button that appears inline at the bottom of the Notes section in the research panel.
3. Type your note in the editor that appears.
4. Click **Save**.

`[SCREENSHOT: Research note editor open beneath the research strip with note text being entered]`

**To edit an existing note:** Click any note row directly in the Notes section of the research panel — the note editor opens with the selected note pre-loaded. You can also click the note text in the research strip or open the Research window (⌘⌥R) and double-click the document entry.

Notes are associated with the active project (see Section 14). If another project has notes for the same document, a disclosure indicator appears at the bottom of the note area — click it to reveal those notes and optionally promote them to the current project.

### 7.2 Highlights

Select any text in the document body. When a selection is active, the **Highlight** button in the research strip becomes enabled. Click it to open the color picker.

`[SCREENSHOT: Text selected in a document with the Highlight button enabled in the research strip and a color picker popover showing four color options]`

**To create a highlight:**
1. Select the passage you want to highlight (click and drag or double-click a word).
2. Click **Highlight** in the research strip (the paintbrush icon becomes active when text is selected).
3. Choose a color: Yellow, Green, Blue, or Pink.
4. The highlight appears immediately as a colored background over the selected text.

Highlights appear as colored background fills directly in the document body — no special mode is required to see them. The **Add Note** button in the research strip becomes active immediately after creating a highlight, allowing you to attach a note to the passage.

**Managing highlights:** All highlights for a document are visible in the document view itself. A **stale highlight** warning banner appears at the top of the document if any highlights were created from an older version of the document's content — this can happen if the underlying TEI source has been updated. Stale highlights are shown in amber; you can delete them from the Research window.

**Research window integration:** Highlights appear in the Research window (⌘⌥R) as colored strip excerpts beneath the document header, showing the verbatim highlighted text. The sidebar includes a "By Highlight Color" section grouping documents by which colors you have used — useful when you use different colors to mark different thematic categories.

### 7.3 User Tags

User tags are global labels you define. They are not the same as the official subject tags from the FRUS taxonomy.

**To tag a document:**
1. Click **Tags** in the research strip, or click the **+ Add Tag** button that appears next to the existing tag chips in the Tags section of the research panel.
2. Start typing to search existing tags or create a new one.
3. Press Return to apply.

`[SCREENSHOT: Tag picker popover showing existing tags and a text field for creating a new one]`

Tags appear as **removable chips** in the Tags section of the research panel. Each chip has an **×** button — click it to remove that tag directly without opening the tag picker. A **+** button next to the chips adds more tags. Click any tag chip (without the × button) to run a search filtered to documents with that tag. Manage all your tags — rename, merge, delete — in **Settings → Research → Tags**.

---

## 8. Cross-Reference Graph

FRUS documents frequently reference one another. The **Cross-Reference Graph** visualizes these connections as an interactive network.

Open the graph for any document by clicking **Graph** in the toolbar. The graph opens in its own window.

`[SCREENSHOT: Cross-reference graph window showing a three-column network with inbound references on the left, the current document in the center, and outbound references on the right]`

### 8.1 Layout

The graph uses a three-column layout:

- **Left column** — Documents that reference the current document (inbound).
- **Center** — The current document.
- **Right column** — Documents that the current document references (outbound).

When a document has more than 30 references, nodes from the same volume are grouped into a collapsible cluster. Click a cluster to expand it.

For documents with very large reference networks (more than 21 nodes), the layout switches to a force-directed spring simulation that animates into a stable arrangement.

### 8.2 Interacting with Nodes

| Action | Effect |
|--------|--------|
| Hover | Shows the full document title and metadata in a tooltip |
| Click | Selects the node |
| Right-click | Context menu: *Re-centre on this document*, *Open in Main Window* |
| Pinch / scroll | Zoom |
| Drag (background) | Pan |

### 8.3 Degree Filter

Use the **Degree** picker to control how many hops from the central document are displayed: 1st degree (direct references only), 2nd degree, or 3rd degree.

`[SCREENSHOT: Graph with the degree picker control visible and second-degree nodes shown in a different color]`

### 8.4 Undownloaded Volumes

Nodes in volumes that have not been downloaded are shown with a **?** indicator. Clicking such a node prompts you to download the volume; the graph updates when indexing completes.

---

## 9. Citation Lookup

If you have a citation from a footnote, bibliography, or note and want to find the actual document, use **Citation Lookup**.

Access it via **Document → Citation Lookup** in the menu bar, or press **⌘⇧F**.

`[SCREENSHOT: Citation Lookup sheet showing the two-mode interface — Paste Citation tab active with a sample citation entered]`

### 9.1 Input Modes

**Paste Citation** — Paste any citation text. FRUS Explorer parses it in real time, extracting subseries year range, volume number, document number, and page number. Supported formats include:

- history.state.gov recommended style
- Chicago footnote and bibliography
- Informal abbreviated forms (*FRUS 1955–57, vol. XIV, doc. 23*)
- Page-only citations

**Structured Entry** — Fill in fields manually: subseries/year, volume number, document number or page number, and an optional title fragment.

### 9.2 Results

`[SCREENSHOT: Citation Lookup results list showing three candidates with confidence labels]`

Results are ranked by confidence:

| Label | Meaning |
|-------|---------|
| Exact match | Document number matched directly |
| Matched by page number | Page range overlaps |
| Match — document number assigned digitally | Pre-1955 volumes where document numbers were added digitally |
| Possible match — nearest is *N* | Fuzzy document-number match |
| Volume identified — download to find document | Volume not yet downloaded |
| Best guess | Explanation provided |

Click any result to open that document. If the volume is not downloaded, a **Download** button appears in place of the open link.

### 9.3 Copying and Sharing Citations

With a document open, click **Info** in the research strip (or use the document toolbar's **View Citation** / **Copy Citation** / **Share Citation** commands) to work with its formatted citation:

- **Copy Citation** copies the formatted citation text to the clipboard, ready to paste into a paper, email, or notes app.
- **Share Citation** opens the macOS share sheet with a single message that combines the formatted citation *and* its canonical `history.state.gov` link, so the recipient can both read the citation and open the original source online with one click. This works with any share destination macOS supports — Mail, Messages, Notes, AirDrop, third-party apps, and more.

`[SCREENSHOT: Citation popover showing formatted citation with Copy and Share Citation buttons]`

`[SCREENSHOT: macOS share sheet showing a combined citation-and-link message ready to send]`

---

## 10. Collections and Export

Collections are ordered groups of documents that you can export as formatted PDF or HTML. Use them to assemble source packets, share a curated reading list, or build an annotated bibliography.

Open the Collections window with **⇧⌘K**.

`[SCREENSHOT: Collections window showing a list of collections on the left and a selected collection's contents on the right]`

### 10.1 Creating a Collection

1. Click **+** in the Collections window.
2. Enter a name and an optional collection note.
3. Click **Create**.

### 10.2 Adding Documents

With a collection selected, add documents in two ways:

- **Individually**: Open any document and click **Collections** in the research strip. Choose an existing collection or create a new one.
- **By Tag**: In the Collections window, click **Add by Tag**, choose a user tag, and all documents with that tag are appended.

Reorder documents by dragging rows within the collection list.

`[SCREENSHOT: Collection detail view with documents listed and drag handles visible]`

For each document in a collection you can choose which research note (if any) to include in the export. Click the document row's **Note** column to pick from existing notes or write one inline.

### 10.3 Smart Collections

Link any saved search to a collection by clicking **Link Search** in the collection detail view. The collection becomes *smart*: at export time, FRUS Explorer resolves the saved search and includes all matching documents automatically. This keeps the collection current as you add new notes and tags.

`[SCREENSHOT: Collection detail showing the "Link Search" button and a linked saved search name displayed as a badge]`

### 10.4 Exporting

Click **Export** in the Collections window to generate a formatted document.

| Format | Best for |
|--------|---------|
| **PDF** | Printing, archiving, sharing with colleagues who do not have FRUS Explorer |
| **HTML** | Web-based viewing, browser printing with custom CSS, embedding links |
| **DOCX** | Microsoft Word format with styles, footnotes, and internal links |

The export sheet offers additional controls:

| Control | Options |
|---------|---------|
| **Body depth** | *Full* (complete document body), *Summary only* (requires Apple Intelligence; generates summaries on demand), or *Index only* (citation, date, and notes — no body text) |
| **Footnotes** | *All* (full footnotes), *Source note only*, or *None* |
| **Inline highlights** | Toggle to include highlighted passages as `<mark>` annotations (HTML export) |
| **Research notes** | Toggle to include or exclude attached research notes |

The export always includes the collection title, a linked table of contents, and any research notes you have attached — unless the notes toggle is turned off.

After exporting, a Finder reveal button opens the enclosing folder.

`[SCREENSHOT: Export format picker sheet with PDF, HTML, and DOCX options]`

---

## 11. AI Summarization

FRUS Explorer integrates with Apple Intelligence to generate on-device summaries of documents. Summaries are stored in the local database and indexed for search. No document content is sent to any server.

> **Requirement:** AI summarization requires an Apple Silicon Mac with Apple Intelligence enabled in System Settings → Apple Intelligence & Siri.

### 11.1 Summarizing a Document

1. Open a document.
2. Click **Summarize** (the summary strip above the document body, or the Research strip button).
3. A prompt picker sheet appears. Choose a prompt (see below) and click **Run**.

`[SCREENSHOT: Prompt picker sheet showing standard prompts and a "Create Prompt" button]`

The summary appears in the strip above the document. If a previously generated summary exists, clicking **View Others** shows all summaries for this document grouped by prompt.

### 11.2 Prompt Types

**Standard prompts** — Shipped with FRUS Explorer:

- *General Summary* — A one-paragraph overview of the document's content.
- *Structured Summary* — Key participants, subject, decisions, and significance as structured fields.

**User prompts** — Create your own in **Settings → Advanced → Summarization**:

1. Click **+** to create a new prompt.
2. Give it a name.
3. Choose **General** (free text output) or **Structured** (define fields by name and type).
4. Write your prompt instructions.
5. Save.

**Templates** — Eight built-in templates are available as starting points: General Summary, Diplomatic Exchange, Policy Decision, Analytical Report, Meeting Record, Crisis Event, Individual Role Trace, and Relevance Assessment.

`[SCREENSHOT: User prompt creation form showing the schema builder for a Structured output type]`

### 11.3 Long Documents

Documents that are too long for a single model call are automatically chunked at TEI structural boundaries, each chunk summarized independently, and then combined into a final summary. A **"Summarized in sections"** indicator appears in the summary strip when this has occurred.

### 11.4 Background Summarization

To summarize many documents at once, use the **Background Summarizer** in **Settings → Advanced → Summarization → Background Summarizer**.

1. Choose a scope: an entire subseries, a single volume, a user tag, a saved search, or a date range.
2. Set the concurrency limit (how many documents are summarized in parallel).
3. Click **Run**.

Progress is shown non-intrusively in the Settings window. The main window and all other tools remain fully responsive while summarization runs.

`[SCREENSHOT: Background Summarizer settings pane showing scope picker, concurrency slider, and progress indicator]`

### 11.5 Promoting Summaries to Notes

Any summary can be promoted into a research note. Click **Use as Draft** in the summary strip. The summary text becomes the initial content of a new note, which you can then edit and save normally.

---

## 12. Source Explorer

Every FRUS document carries a source note that identifies the archival record behind the published text — a State Department lot file, a presidential library folder, or a NARA record group. The **Source Explorer** resolves that note into links to the relevant archival description.

Click the source note at the top of any open document to open the Source Explorer sheet.

`[SCREENSHOT: Source Explorer sheet showing a resolved RG-59 lot file with NARA Catalog link]`

### 12.1 Resolution by Provenance Type

Source Explorer classifies each source note and applies the most precise resolution strategy available for that type. The guiding principle is honest navigation: if a type cannot be resolved to a specific catalog record, Source Explorer links directly to the correct finding-aid page rather than showing a generic error or a blank state.

| Provenance | Resolution | API key needed? |
|-----------|-----------|:---:|
| **State Dept. decimal files (1910–1963)** | NARA finding-aid page for the 1910–1963 decimal file series. The Source Explorer also links to the relevant **filing manual** PDF for the document's period (where applicable), so you can understand how records were classified and organized | No |
| **State Dept. central files (post-1963)** | NARA Catalog search pre-scoped to the RG-59 parent description; subject-numeric code (e.g. `POL 27 VIET S`) used as the query | No |
| **Lot files** | NARA Catalog API `variantControlNumber_is` query with three normalised forms of the lot number (e.g. `63D135`, `63 D 135`, `63 D135`), constrained to Record Group 59 | Yes |
| **Other NARA record groups** (RG 218, 306, 330, 84) | NARA Catalog API search with record group number constraint | Yes |
| **Presidential library** | NARA Catalog keyword search combining library name and collection keywords; up to 3 candidates shown; zero-result path links to the institution's own finding-aid portal (e.g. jfklibrary.org, lbjlibrary.org, nixonlibrary.gov) | Yes |
| **CIA records** | CIA CREST database link with job number pre-populated when available | No |
| **Foreign archive** | Displays parsed text | — |
| **Previously published** | Displays parsed citation | — |
| **Unrecognized** | Shows raw text with a general NARA Catalog search link | No |

When the API returns multiple candidates (up to 5 for lot files and 3 for presidential libraries), they are displayed as a ranked list. Click any candidate to open its NARA Catalog record in your browser. When zero results are returned, a manual-search button appears pre-scoped to the correct record group or institution.

`[SCREENSHOT: Source Explorer showing a resolved State Dept. lot file with multiple NARA Catalog candidates listed]`

`[SCREENSHOT: Source Explorer showing a decimal file citation with the matched 1945–1949 period finding-aid link and a brief explanation of the filing system]`

### 12.1.1 Free-Text NARA Catalog Lookup

You can also run a free-text NARA Catalog query using any text you select in a document body — useful when the automatic parser cannot identify the source type, or when you want to search with different keywords.

Select the relevant text (a lot number, decimal file identifier, archival keyword, etc.) and choose **NARA Lookup** from the research strip (macOS) or **Look Up in NARA Catalog** from the **More (…)** overflow menu (iOS). A lookup sheet appears pre-populated with your selection. Choose a search strategy (lot file by record group, keyword search within RG 59 or RG 84, or general catalog search), edit the query if needed, and tap **Search**.

`[SCREENSHOT: NARA Catalog Lookup sheet showing the pre-populated query field and strategy picker]`

### 12.2 NARA API Key

Lot file and presidential library lookups require a free NARA Catalog API key. Enter your key once in **Settings → Advanced → NARA API**; it is stored in iCloud Keychain and syncs automatically to all your devices. Central file, decimal file, and CIA resolution work without a key.

`[SCREENSHOT: Settings pane for NARA API key entry with a "Need a Key?" link]`

---

## 13. Analytics

The **Analytics** window charts how often a search term appears across the corpus over time.

Open it from the **Analytics** toolbar button in the main window.

`[SCREENSHOT: Analytics window showing a bar chart of term frequency by year with a trend line overlay]`

### 13.1 Configuring a Chart

1. Type a search term in the field at the top of the window. The same query syntax as the Search window is supported (see Section 5.2).
2. Choose a **dimension**: Decade, Year, Month, or Day.
3. Choose a **grouping**: All subseries combined, or broken out by subseries.
4. Drag the **Year Range** slider to zoom in on a particular period.

### 13.2 Chart vs. Table

Toggle between **Chart** (bar chart with optional trend line) and **Table** (scrollable data grid) using the segmented control at the top right.

`[SCREENSHOT: Analytics window in Table mode showing year, count, and subseries columns]`

### 13.3 From a Chart to a Search

Click a bar, point, or table row to **View in Search** — this opens the Search window with that term and the corresponding year range pre-filled as a date filter, so you can read the actual documents behind that data point. The relationship runs both ways: a capped Search result set can hand its terms and date filter back to Analytics via "Visualize in Corpus Analytics" (Section 5.6), making it easy to move fluidly between charting a trend and reading the documents that drive it.

`[SCREENSHOT: Analytics chart with a "View in Search" action on a selected bar]`

---

## 14. Projects and Tags

### 14.1 Projects

A *project* is a named research initiative with optional default filters. Every note, highlight, summary, and collection you create is tagged with the active project, making it easy to keep separate research threads distinct.

**Creating a project:**

Open **Settings → Research → Projects** and click **+**. Give it a name, an optional research question, and optional defaults:

- **Default date range** — Pre-fills the date filter whenever you open Search or the corpus browser under this project.
- **Default subject tags** — Pre-filters the browser to show only volumes tagged with these subjects.
- **Default country tags** — Similar pre-filter for country.

`[SCREENSHOT: Project editor in Settings showing name, research question, and default fields]`

**Switching projects:**

The active project is shown in the toolbar of the Corpus Browser. Click it to switch. The change is instant — all new annotations from that point forward belong to the newly selected project.

**Merging projects:**

In **Settings → Research → Projects**, click the ellipsis (…) button next to a project and choose **Merge into…**. Select the destination project from the list. All notes, highlights, summaries, and collections from the source project are unified under the destination project, and the source project is deleted. The active project switches to the destination automatically if the source was active.

**Cross-project notes:**

When you read a document that has notes from a different project, a disclosure indicator appears at the bottom of the note area. Expand it to read those notes. Click **Add to This Project** on any note to make it visible under both projects.

### 14.2 User Tags

User tags are global (not project-scoped). They complement projects by letting you mark documents with thematic labels that cut across multiple research initiatives.

Manage all user tags in **Settings → Research → Tags**:

- **Rename** — Update the tag name everywhere it is applied.
- **Merge** — Combine two tags into one.
- **Delete** — Remove the tag from all documents.

---

## 15. Settings

Open Settings with **⌘,** or via the **FRUS Explorer → Settings** menu.

`[SCREENSHOT: macOS Settings window with the sidebar showing all panes]`

### General

| Pane | Contents |
|------|----------|
| **About** | FRUS series overview, links to history.state.gov and the GitHub source repository, app version and attribution |
| **Display** | Theme preferences (light, dark, or system) |
| **Search** | FTS5 configuration — stemming language, ranking parameters |

### Research

| Pane | Contents |
|------|----------|
| **Projects** | Create, rename, set defaults, delete projects |
| **Tags** | Rename, merge, delete user tags |
| **Notes** | View notes filtered by project or tag; logging preferences |

### Corpus

| Pane | Contents |
|------|----------|
| **Storage** | Breakdown of disk usage by volumes (XML), search index (FTS5), and generated summaries; per-volume delete with size shown; **Reindex** button |
| **Add Volumes** | Download queue with progress; **Check for Updates** to fetch the latest manifest; **Sideload XML** to import a single volume file |

### Advanced

| Pane | Contents |
|------|----------|
| **NARA API** | API key entry (stored in iCloud Keychain); *Need a Key?* link |
| **Summarization** | Prompt management, summary browser, background summarizer |

### Reset

| Option | Effect |
|--------|--------|
| **Reset Local Data** | Deletes all local app data; iCloud-synced records (notes, tags, collections, highlights) are preserved and re-download on next launch |
| **Reset iCloud Sync** | Clears the CloudKit change token so the container performs a full re-sync from the server on next launch. Use when the sync indicator shows a persistent error that does not resolve on its own |
| **Reset Everything** | Deletes all local data and initiates deletion of all iCloud records |

All reset options require confirmation.

---

## 16. Reading History and the Research Guide

### 16.1 The History Menu

FRUS Explorer keeps a running record of every document you've opened and every search you've run. The **History** menu in the menu bar surfaces the last ten of each for quick access:

- Recently viewed documents — choose one to reopen it directly
- Recently run searches — choose one to re-run it with its original query and filters intact

`[SCREENSHOT: History menu open, showing recent documents and recent searches]`

### 16.2 The Complete History Window

Choose **Complete History…** from the History menu (or open the `frus.history` window directly) to see your full reading and search history in a dedicated window — not just the last ten of each. An optional **project filter** lets you narrow the list to activity associated with a specific research project (see Section 14.1), which is useful for reconstructing the research trail behind a particular paper or question.

`[SCREENSHOT: Complete History window showing a scrollable list of visited documents and searches with a project filter control]`

From either list, you can reopen a document or re-run a search with a single click — the same way you would from the History menu's short lists.

### 16.3 The FRUS Research Guide

The **FRUS Research Guide** is a standalone, in-app guide to historical research methodology — covering how to approach the FRUS series as a primary source, how to frame a research question, how to cite material rigorously, and other practical guidance for working with declassified diplomatic records.

Open it from **Help → FRUS Research Guide** (or the `frus.researchGuide` window scene). It opens in its own window that you can keep open for reference alongside your main research window. Internal links open in FRUS Explorer's embedded in-app browser (Section 16.4) so you never lose your place.

`[SCREENSHOT: FRUS Research Guide window showing a methodology section with embedded links]`

You'll also find contextual links into the Research Guide from **Source Explorer** and **NARA Catalog Lookup** — for example, a link explaining how to interpret an archival record group while you're looking at one — so guidance appears exactly when it's useful, not just as a separate reference document.

### 16.4 The Embedded Browser

Wherever FRUS Explorer shows a link to an external resource — onboarding, About, the Research Guide, education content, Source Explorer, or NARA Catalog Lookup — it opens in a built-in browser sheet rather than launching Safari. This keeps you in your research session: dismiss the sheet to return exactly where you were, with your document, search, or guide content untouched in the background.

`[SCREENSHOT: Embedded browser sheet showing a history.state.gov page with a Done button]`

---

## 17. Keyboard Shortcuts

### Global

| Action | Shortcut |
|--------|----------|
| Open Search window | ⌘F |
| Open Citation Lookup | ⌘⇧F |
| Open Corpus Browser | ⇧⌘B |
| Open Research window | ⌘⌥R |
| Open Collections window | ⇧⌘K |
| Open Complete History window | (History menu → "Complete History…") |
| Open FRUS Research Guide | (Help menu) |
| Open Settings | ⌘, |
| Back in document history | ⌘[ |
| Forward in document history | ⌘] |

### In the Search Window

| Action | Shortcut |
|--------|----------|
| Run search | Return |
| Clear search | Escape |
| Open document from result | Return (with result selected) |

### In a Document

| Action | Shortcut |
|--------|----------|
| Add / edit research note | ⌘⌥N |
| Copy citation | ⌘⌥C |
| Open cross-reference graph | ⌘⌥G |

---

*FRUS Explorer is an independent research tool and is not affiliated with the U.S. Department of State or the Office of the Historian. The FRUS series itself is published under a public domain license.*
