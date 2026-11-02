# Testing FRUS Explorer 1.0 (iOS)

**Release candidate.** Version 1.0 (1787) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1776)?** First launch rebuilds People once, in the background. From build 50 it also re-indexes your library once and removes the earlier search model.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume. As volumes download and index, a banner and a Live Activity count the whole queue, and for a first queue of several volumes the **FRUS Research Guide** opens while you wait.
- **Browse** goes from subseries to volume, chapter and document, prose sections and the Notes on U.S. Covert Actions included; **Analysis Tools** charts terms, people, cross-references and archives. Its **People** row lists everyone the volumes name, many with links to Wikidata and VIAF.

## Reading

- Select text to highlight it or add a note. The **Research rail** holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.
- **Summarize this Document** (Apple Intelligence) covers the whole document, however long; a structured prompt such as **Meeting Record** answers in its fields wherever the summary shows.
- **Cross-references:** a reference to a page of another volume cites the document on that page. A page link into a volume you have not downloaded offers that volume, or opens its page in Browse naming the page.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**.

## Search

- **Keywords** or **Meaning**: Meaning ranks documents by a question with EmbeddingGemma 2, an open-source model you add with **Download Search Model** (310 MB, nothing to accept).
- **Facets** narrow the results; **•••** ▸ **Save as Working Corpus…** keeps them, its sheet showing what narrowed them (**Narrowed by**).
- **Search within these results:** after a Meaning question, **•••** ▸ **Find Words in These Matches**; after keywords, **•••** ▸ **Rank These Results by a Question**. **Swap** swaps the two orders, and the close button on its row puts the list back.

## Collections and Settings

- Collections export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero. A **smart collection** follows a saved search and takes nothing by hand. Touch and hold a collection to **Rename**, **Duplicate** or **Delete** it; **Edit** deletes several, and every delete asks first.
- **Keeping Current** (Settings ▸ Library ▸ Volumes & Storage): **Check for Corrections**, then **Update**, each volume's row showing its step.
- **Email Feedback File** (Settings ▸ System ▸ Data & Recovery) writes a message of your Semantic Match verdicts to feedback@frusexplorer.app.

**Fixed since 1.0 (1776):** many things, on every tab.

## What to test

1. **First launch,** once in Airplane Mode: does the app open? Choose a subseries: does the banner's count match the queue?
2. **Read and annotate:** highlight, note, **Cite**, **Sources**, and **Summarize this Document** on a long one, such as 1946, vol. VI, Document 475.
3. **Search** both ways, with **Facets**, then within the results and **Swap**.
4. **Graph:** **Network** at **3 hops**, and that document's **Timeline**.
5. **Analytics:** **View N documents ↗** gives Search's count, and a bar of **Most-Referenced Documents** opens its document.
6. **Collections:** rename, duplicate and delete one.
7. **1776 testers:** does People rebuild, with Henry Kissinger linking to Wikidata and VIAF? Are your reports fixed?

Not bugs: People entries differing from 1776's.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
