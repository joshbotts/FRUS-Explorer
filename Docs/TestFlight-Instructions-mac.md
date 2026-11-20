# Testing FRUS Explorer 1.0 (Mac)

**Release candidate.** Version 1.0 (1842) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your Mac: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1823)?** Nothing re-indexes. **From 1.0 (1812) or (1787)**, first launch re-indexes your library once; from 1776 it also rebuilds People once, in the background.

## New since 1.0 (1812)

- **Subjects**, the Office of the Historian's experimental subject data, replace detected topics: the Corpus Browser's **Subjects**, the Search window's filters, the Research rail and **Related**, each with one caption saying where the data comes from.
- **Import from JSON…** (Settings ▸ System ▸ **Data & Recovery**) reads an export from this app or from FRUS Explorer Light, and shows what it would add, replace and keep before it writes anything. Beside **Export Research Database…**, a line names the index version the copy will carry.
- **Data & Recovery's exports ask where to save:** **Export as JSON…** saves the file where you choose, and **Export Notes as Markdown** and **Export Query Log as a Method Appendix…** each make a new folder in the one you choose. A line under each says where it went.
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

1. **Earlier testers:** are your notes, highlights, tags and collections all there? Are your reports fixed?
2. **Exports:** save each of Data & Recovery's three exports to a folder of your choice. Is each where the line under it says?
3. **Import:** **Import from JSON…** the file you saved, and one from an iPhone or iPad, or from FRUS Explorer Light. Does the report match what you had, and do imported records reach your other devices through iCloud?
4. **Two devices:** keep All Notes open on the Mac while you add and delete a note on another device. Does the list follow without a relaunch?
5. **Indexes and graphs:** in a volume's index, does a *See* reference bring its entry into view? Zoomed in, does each network graph stay inside its window?
6. **Templates:** apply each of the six to a collection, then export it.
7. **Print:** File ▸ **Print** a document to a printer.

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
