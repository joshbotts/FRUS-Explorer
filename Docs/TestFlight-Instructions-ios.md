# Testing FRUS Explorer 1.0 (iOS)

**Release candidate.** Version 1.0 (1776) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested build 50?** First launch re-indexes your library once (index version 71) and rebuilds People, in the background. The earlier search model and its match files are removed; Related Documents and Meaning fetch new ones.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume. As volumes download and index, a banner and a Live Activity count the whole queue, and for a first queue of several volumes the **FRUS Research Guide** opens while you wait.
- **Browse** goes from subseries to volume, chapter and document, prose sections and the Notes on U.S. Covert Actions included; **Analysis Tools** charts terms, people, cross-references and archives.

## Reading

- Select text to highlight it or add a note. The **Research rail** holds **Cite**, **Sources**, **Graph**, **Related** and your notes, tags and collections.
- **Cross-references:** a page of another volume (*Foreign Relations, 1942, vol. I, p. 841*) cites the document on that page. A page link into a volume you have not downloaded offers that volume, or opens its page in Browse naming the page.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**.

## Search

- **Keywords** or **Meaning**: Meaning ranks documents by a question with EmbeddingGemma 2, an open-source model you add with **Download Search Model** (310 MB, nothing to accept).
- A keyword snippet starts at the rarest of your words, past the heading, source note and dateline.
- **Facets** narrow the results; **•••** ▸ **Save as Working Corpus…** keeps them, its sheet showing what narrowed them (**Narrowed by**).
- **Search within these results:** after a Meaning question, **•••** ▸ **Find Words in These Matches**; after keywords, **•••** ▸ **Rank These Results by a Question**. **Swap** swaps the two orders, and the close button on its row puts the list back.
- **Accessibility:** VoiceOver offers a result's tags as **Filter by** actions; at the largest text sizes the Meaning strip is one line, and its info button opens all of it.

## Collections and Settings

- Collections export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero. A **smart collection** follows a saved search and takes nothing by hand.
- **Keeping Current** (Settings ▸ Library ▸ Volumes & Storage): **Check for Corrections**, then **Update**, each volume's row showing its step.
- **Email Feedback File** (Settings ▸ System ▸ Data & Recovery) writes a message of your Semantic Match verdicts to feedback@frusexplorer.app.

**Fixed since build 50:** many things, on every tab and in accessibility.

## What to test

1. **First launch.** Choose a subseries: does the banner's count match the queue, and does the Guide stay open?
2. **Read and annotate:** highlight, note, **Cite**, **Sources**.
3. **Search** both ways, with **Facets**, then within the results, **Swap** and the row's close button: do the row and header say so?
4. **Meaning.** Download the model: nothing to accept?
5. **A page link** into a volume you have not downloaded.
6. **Analytics:** chart a term, narrow the years, **View N documents ↗**: the same count in Search?
7. **Keeping Current** and **Reading Width**, portrait and landscape.
8. **Build-50 testers:** does the re-index finish, with People whole (Kirkpatrick, Khomeini, Allen one entry each)? Are your reports fixed?

Not bugs: People counts, Meaning results and citing lists differing from build 50's.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
