# Testing FRUS Explorer 1.0 (Mac)

**Release candidate.** Version 1.0 (1812) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your Mac: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1787)?** First launch re-indexes your library once. From 1776 it also rebuilds People once, in the background.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume. As volumes download and index, the status bar counts the whole queue, and its **Learn** button opens the **FRUS Research Guide** while you wait. Help ▸ **FRUS Explorer Quick Start** walks through the app's essentials.
- **The Corpus Browser** (⇧⌘B) goes from subseries to volume, chapter and document; the **Analytics** menu charts terms, people, cross-references and archives. Its **People** button lists everyone the volumes name, many with links to Wikidata and VIAF, and says how many volumes tag their people.

## Editors' Annotations

- Each volume's page lists what its editors annotated: tagged people, source notes, classification markings, redactions and more, each with its count, even for a volume you have not downloaded.
- In the Corpus Browser's sidebar, **Editors' Annotations** files every volume by those layers, era by era, as a matrix. Open a layer for what the editors did, when it became standard, and **Volumes with it** and **Volumes without it**.

## Reading

- Select text to highlight it or add a note. The **Research rail** (⌘⇧R) holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.
- **Summarize this Document** (Apple Intelligence) covers the whole document, however long; a structured prompt such as **Meeting Record** answers in its fields wherever the summary shows.

## Search

- **The Search window** (⌥⌘F), in **Keywords** or **Meaning**: Meaning ranks documents by a question with EmbeddingGemma 2, an open-source model you add with **Download Search Model** (310 MB, nothing to accept).
- Rows from the 1932-1954 volumes show the classification the document printed, as **Source Explorer** does.
- **Facets** narrow the results; **Save as Working Corpus…** keeps them.
- **Search Within Results**, in the titlebar: over a Meaning list it finds words in those matches, over a keyword list it ranks them by a question; **Swap** swaps the two orders.

## Collections and Settings

- **Collections** (⇧⌘K) export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero. A **smart collection** follows a saved search. The **Collection** menu and **Manage Collections…** rename, duplicate and delete a collection; every delete asks first.
- **Keeping Current** (Settings ▸ Library ▸ Volumes & Storage): **Check for Corrections**, then **Update**.

**Fixed since 1.0 (1787):** many things, in every window.

## What to test

1. **1787 testers:** after the re-index, do the Search window's rows from 1932-1954 volumes show their classification? Are your reports fixed?
2. **Editors' Annotations:** a volume's page, then the Corpus Browser's **Editors' Annotations**: open a layer, then **Volumes without it**.
3. **Read and annotate:** highlight, note, **Cite**, **Sources**, and **Summarize this Document** on a long one (1946, vol. VI, Document 475).
4. **Search** both ways, with **Facets**, then **Search Within Results** and **Swap**.
5. **Graph** at **3 hops**, and **Analytics**: **View N documents ↗** gives Search's count.
6. **Collections:** rename, duplicate and delete one.

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
