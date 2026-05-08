# FRUS Explorer

A native macOS and iPadOS reader for the *Foreign Relations of the United States* (FRUS) series — the official documentary record of U.S. foreign policy published by the [Office of the Historian](https://history.state.gov/). Volumes are sourced from the open-data repository at [HistoryAtState/frus](https://github.com/HistoryAtState/frus).

## Features

### Volume catalogue
- Fetches the full FRUS catalogue from GitHub at launch and displays file sizes.
- Download individual volumes or all volumes in bulk, with per-volume and aggregate progress indicators.
- Downloaded volumes are stored locally and available offline; the catalogue shows a "Downloaded" section immediately at launch before any network request completes.
- Sort volumes by ID or file size.
- Volume list displays human-readable series and volume titles once a volume has been parsed; titles are cached to disk so they appear immediately on subsequent launches without re-parsing.

### Three-column explorer
- **Catalogue** — searchable, filterable volume list with download state indicators and cached titles.
- **Outline** — hierarchical chapter/document outline for the selected volume, matching the structure of history.state.gov.
- **Detail** — full document rendering with typeset body text, footnotes, tables, and editorial apparatus.

### Document rendering
- TEI XML is parsed to a native Swift model and rendered entirely in SwiftUI.
- Typography matches the history.state.gov presentation: serif body text, monospaced datelines, inline footnotes, paragraph and list formatting.

### Subject taxonomy
- Every document in the 552-volume corpus is tagged against a controlled vocabulary of 663 subjects, 110 subcategories, and 13 top-level categories aligned to Library of Congress Subject Headings.
- Subject tags are loaded at parse time from a bundled index (~1.5 million annotations) and displayed as colour-coded pill chips in the document outline and the detail view.
- Subjects are integrated into the full-text search engine as a first-class filter dimension (see below).

### Full-text search
- Cross-volume search across all downloaded volumes simultaneously.
- Field-scoped query syntax: `person:Kissinger`, `place:Geneva`, `org:NATO`, `term:détente`.
- Date-range filter with a visual date picker.
- **Subject filter** — tap the tag button to open a subject picker organised by category and subcategory. Selected subjects narrow results to documents that carry at least one matching tag; subject-only filtering (no query text required) is supported.
- Search scope includes document text, AI-generated summaries, and collection annotations.
- Results show volume ID, document title, dateline, and match-field chips (Title, Text, Person, Place, Org, Term, Summary, Note, Date, Subject).

### AI-powered summaries
- Generates per-document summaries using Apple Intelligence (on-device; no data leaves the device).
- Multiple named *prompt profiles* let you configure tone, length, focus, and output format independently.
- Summaries are persisted across sessions keyed to the document and the profile that produced them, so re-opening a document does not trigger re-generation.
- Summaries are included in full-text search.
- Manage profiles and purge stored summaries per-profile from the Prompt Profiles panel.

### Research collections
- Create named collections and add any document from any loaded volume.
- Drag to reorder items within a collection.
- Write per-item research annotations and collection-level research notes.
- Annotations appear in search results and in PDF exports.

### Citation-aware PDF export
- Exports a collection to a US Letter (8.5 × 11 in) paginated PDF via WebKit.
- Each document is labeled with its volume ID, document number, and its canonical URL on history.state.gov.
- A "Cite as:" block is generated for each document following the [FRUS citation guidelines](https://history.state.gov/historicaldocuments/citing-frus):
  > *Foreign Relations of the United States*, [Series Title], eds. [Editors] (Place: Publisher, Year), Document N.
- Research annotations appear beneath each document in the export.

### Settings
- **macOS** — accessible via Cmd+, or the application menu; **iPadOS** — dedicated Settings tab.
- Check for new volumes and configure the number of simultaneous downloads (1–8).
- View local disk usage and re-index all downloaded volumes in bulk with a progress indicator.
- Delete all downloaded volumes with a single confirmation.
- Purge all AI-generated summaries across every profile.
- Clear in-memory volume data or the volume title cache independently.
- Displays app version, build number, and links to the FRUS source repository.

### Volume management
- Re-index any downloaded volume to force a full re-parse and rebuild of the search index — useful after app updates or if the index becomes stale.
- Delete downloaded volumes individually to free disk space.

## Platform requirements

| Platform | Minimum |
|----------|---------|
| macOS    | 14 Sonoma |
| iPadOS   | 17 |

Apple Intelligence features require a device that supports on-device model inference (M-series Mac or A17 Pro / M-series iPad).

## Architecture

| Layer | Description |
|-------|-------------|
| `FRUSKit` | Embedded module: TEI XML parser (`FRUSParser`) and model types (`FRUSVolume`, `Division`, `InlineContent`, `Note`, …) |
| `AppStore` | Central `@Observable` store — catalogue, downloads, parsing, summarisation, search, taxonomy wiring |
| `CollectionStore` | Persistent store for research collections and annotations |
| `SummaryStore` | Persistent store for AI-generated summaries, keyed by `(volumeID, divisionID, profileID)` |
| `PromptProfileStore` | Persistent store for named summarisation prompt profiles |
| `TaxonomyStore` | `@Observable` store — loads the bundled subject taxonomy at launch; holds the per-volume docID→subjectID maps populated as volumes are parsed |
| `SearchEngine` | Swift actor — builds and queries an inverted full-text index across all loaded volumes; supports subject pre-filtering |
| `PDFExporter` | WKWebView-based PDF renderer; `CollectionHTMLRenderer` produces the print-ready HTML |

## Data storage

| Data | Location |
|------|----------|
| Downloaded volumes (macOS) | `~/Library/Application Support/FRUSExplorer/volumes/` |
| Downloaded volumes (iPadOS) | Files app → FRUS Explorer → FRUSVolumes/ |
| Collections, summaries, profiles | `~/Library/Application Support/FRUSExplorer/` (macOS) / app Documents (iPadOS) |
| Volume title cache | UserDefaults (`frus.volumeTitleCache.v2`) |
| Subject taxonomy index | Bundled at `SubjectData/taxonomy.json` + `SubjectData/subjects-{volumeID}.json` (552 per-volume files, ~33 MB total) |

## License

Source is provided for personal and research use. FRUS volumes are U.S. Government works in the public domain.
