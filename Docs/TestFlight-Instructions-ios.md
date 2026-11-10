# Testing FRUS Explorer 1.0 (iOS)

**Release candidate.** Version 1.0 (1812) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1787)?** First launch re-indexes your library once. From 1776 it also rebuilds People once, in the background.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume. As volumes download and index, a banner and a Live Activity count the whole queue, and for a first queue of several volumes the **FRUS Research Guide** opens while you wait. **Quick Start**, on the Research tab, walks through the app's essentials.
- **Browse** goes from subseries to volume, chapter and document; **Analysis Tools** charts terms, people, cross-references and archives. **People** lists everyone the volumes name, many with links to Wikidata and VIAF, and says how many volumes tag their people.

## Editors' Annotations

- Each volume's page lists what its editors annotated: tagged people, source notes, classification markings, redactions and more, each with its count, even for a volume you have not downloaded.
- In Browse, **Annotations** files every volume by those layers, era by era, as a matrix on iPad. Open a layer for what the editors did, when it became standard, and **Volumes with it** and **Volumes without it**.

## Reading

- Select text to highlight it or add a note. The **Research rail** holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.
- **Summarize this Document** (Apple Intelligence) covers the whole document, however long; a structured prompt such as **Meeting Record** answers in its fields wherever the summary shows.

## Search

- **Keywords** or **Meaning**: Meaning ranks documents by a question with EmbeddingGemma 2, an open-source model you add with **Download Search Model** (310 MB, nothing to accept).
- Rows from the 1932-1954 volumes show the classification the document printed, as **Sources** does.
- **Facets** narrow the results; **•••** ▸ **Save as Working Corpus…** keeps them.
- **Search within these results:** after a Meaning question, **•••** ▸ **Find Words in These Matches**; after keywords, **•••** ▸ **Rank These Results by a Question**. **Swap** swaps the two orders.

## Collections and Settings

- Collections export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero. A **smart collection** follows a saved search. Touch and hold a collection to **Rename**, **Duplicate** or **Delete** it; every delete asks first.
- **Keeping Current** (Settings ▸ Library ▸ Volumes & Storage): **Check for Corrections**, then **Update**.

**Fixed since 1.0 (1787):** many things, on every tab.

## What to test

1. **1787 testers:** after the re-index, do Search's rows from 1932-1954 volumes show their classification? Are your reports fixed?
2. **Editors' Annotations:** a volume's page, then Browse ▸ **Annotations**: open a layer, then **Volumes without it**.
3. **Indexing:** queue several volumes and leave the app. Has the queue moved on when you come back?
4. **Read and annotate:** highlight, note, **Cite**, **Sources**, and **Summarize this Document** on a long one, such as 1946, vol. VI, Document 475.
5. **Search** both ways, with **Facets**, then within the results and **Swap**.
6. **Graph** at **3 hops**, and **Analytics**: **View N documents ↗** gives Search's count.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
