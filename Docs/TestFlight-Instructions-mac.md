# Testing FRUS Explorer 1.0 (Mac)

**Release candidate.** Version 1.0 (1776) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your Mac: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested build 50?** First launch re-indexes your library once (index version 71) and rebuilds People, in the background. The earlier search model and its match files are removed; Related Documents and Meaning fetch new ones.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume. As volumes download and index, the status bar counts the whole queue, and its **Learn** button opens the **FRUS Research Guide** while you wait.
- **The Corpus Browser** (⇧⌘B) goes from subseries to volume, chapter and document, prose sections and the Notes on U.S. Covert Actions included; the **Analytics** menu charts terms, people, cross-references and archives.

## Reading

- Select text to highlight it or add a note. The **Research rail** (⌘⇧R) holds **Cite**, **Sources**, **Graph**, **Related** and your notes, tags and collections.
- **Cross-references:** a page of another volume (*Foreign Relations, 1942, vol. I, p. 841*) cites the document on that page. A page link into a volume you have not downloaded offers that volume, or opens its page in the Corpus Browser naming the page.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**; a wide window adds margin, not line length.

## Search

- **The Search window** (⌥⌘F), in **Keywords** or **Meaning**: Meaning ranks documents by a question with EmbeddingGemma 2, an open-source model you add with **Download Search Model** (310 MB, nothing to accept).
- A keyword snippet starts at the rarest of your words, past the heading, source note and dateline.
- **Facets** narrow the results; **Save as Working Corpus…** keeps them, its sheet showing what narrowed them (**Narrowed by**).
- **Search Within Results**, in the window's titlebar: over a Meaning list it finds words in those matches; over a keyword list it ranks the results by a question. **✕** puts the list back, and after a search inside it **Swap** swaps the two orders.

## Collections and Settings

- **Collections** (⇧⌘K) export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero. **⚙ Collection** ▸ **Link to Saved Search…** makes a **smart collection**, which follows the search and takes nothing by hand.
- **Keeping Current** (Settings ▸ Library ▸ Volumes & Storage): **Check for Corrections**, then **Update**, each volume's row showing its step.
- **Email Feedback File** (Settings ▸ System ▸ Data & Recovery) writes a message of your Semantic Match verdicts to feedback@frusexplorer.app.

**Fixed since build 50:** many things, in every window and in accessibility.

## What to test

1. **First launch.** Choose a subseries: does the status bar's count match the queue?
2. **Read and annotate:** highlight, note, **Cite**, **Sources**.
3. **Search** both ways, with **Facets**, then **Search Within Results**, **Swap** and **✕**: do the row and count line say so?
4. **Meaning.** Download the model: nothing to accept?
5. **A page link** into a volume you have not downloaded.
6. **Analytics:** chart a term, narrow the years, **View N documents ↗**: the same count in Search?
7. **Keeping Current**, and **Reading Width** in a narrow and a wide window.
8. **Build-50 testers:** does the re-index finish, with People whole (Kirkpatrick, Khomeini, Allen one entry each)? Are your reports fixed?

Not bugs: People counts, Meaning results and citing lists differing from build 50's.

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
