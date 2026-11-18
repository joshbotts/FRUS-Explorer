# Testing FRUS Explorer 1.0 (Mac)

**Release candidate.** Version 1.0 (1823) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your Mac: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1812) or (1787)?** First launch re-indexes your library once. From 1776 it also rebuilds People once, in the background.

## New in 1.0 (1823)

- **Subjects**, the Office of the Historian's experimental subject data, replace detected topics: the Corpus Browser's **Subjects**, the Search window's filters, the Research rail and **Related**, each with one caption saying where the data comes from.
- **Import from JSON…** (Settings ▸ System ▸ **Data & Recovery**) reads an export from this app or from FRUS Explorer Light, and shows what it would add, replace and keep before it writes anything. Beside **Export Research Database…**, a line names the index version the copy will carry.
- **Collections:** six templates under **Start from a template — optional**, in the collection's settings popover (the gear button), each named for what it does, from **Full text as printed** to **Everything included**.
- **Downloads:** Volumes & Storage's **Cancel All** asks first, and a download that fails says so, with **Retry**.
- **Windows:** the main window is titled with the open document's heading, and its toolbar's centre names the volume and the document's number.
- The Help menu and About ▸ **Legal** link the privacy policy and the support page.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume, with the size it takes on the Mac. The status bar counts the queue as volumes download and index.
- **The Corpus Browser** (⇧⌘B) goes from subseries to volume, chapter and document; each volume's page lists what its editors annotated. The **Analytics** menu charts terms, people, cross-references and archives.

## Reading and research

- Select text to highlight it or add a note. The **Research rail** (⌘⇧R) holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.
- **The Search window** (⌥⌘F) searches by **Keywords** or **Meaning** (EmbeddingGemma 2, an optional 310 MB download), with **Facets** and **Search Within Results**.
- **Collections** (⇧⌘K) export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero.

**Fixed since 1.0 (1812):** many things, in every window.

## What to test

1. **1812 and 1787 testers:** after the re-index, are your notes, highlights, tags and collections all there? Are your reports fixed?
2. **Import:** before you update, export from 1.0 (1812) (Settings ▸ System ▸ Data & Recovery ▸ **Export as JSON**); after, **Import from JSON…** that file, and one from FRUS Explorer Light if you use it. Does the report match what you had, and do the imported records reach your other devices through iCloud?
3. **Templates:** apply each of the six to a collection, then export it.
4. **Downloads:** queue several volumes, then **Cancel All**.
5. **Windows:** open two documents with ⌘N; does the Window menu tell them apart?
6. **Charts:** on macOS 27.2, does each bar's name sit beside its own bar, in Person, Cross-Reference and Archival Analytics and About the Series' Geography?
7. **Print:** File ▸ **Print** a document to a printer.

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
