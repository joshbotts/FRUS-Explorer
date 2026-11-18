# Testing FRUS Explorer 1.0 (iOS)

**Release candidate.** Version 1.0 (1823) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1812) or (1787)?** First launch re-indexes your library once. From 1776 it also rebuilds People once, in the background.

## New in 1.0 (1823)

- **Subjects**, the Office of the Historian's experimental subject data, replace detected topics: Browse ▸ **Subjects**, Search's filters, the Research rail and **Related**, each with one caption saying where the data comes from.
- **Import from JSON…** (Settings ▸ System ▸ **Data & Recovery**) reads an export from this app or from FRUS Explorer Light, and shows what it would add, replace and keep before it writes anything.
- **Collections:** six templates under **Start from a template — optional** in Collection settings, each named for what it does, from **Full text as printed** to **Everything included**. On iPhone they are chips, and the settings row names the one in force.
- **Downloads:** Volumes & Storage's **Cancel All** asks first, and a download that fails says so, with **Retry**.
- **Search:** Filters' **Done** runs the search again with what you changed.
- Settings ▸ System ▸ About ▸ **Legal** links the privacy policy and the support page.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume, with the size it takes on the device. A banner and a Live Activity count the queue as volumes download and index.
- **Browse** goes from subseries to volume, chapter and document; each volume's page lists what its editors annotated. **Analysis Tools** charts terms, people, cross-references and archives.

## Reading and research

- Select text to highlight it or add a note. The **Research rail** holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.
- Search by **Keywords** or **Meaning** (EmbeddingGemma 2, an optional 310 MB download), narrow with **Facets**, and search within the results.
- Collections export as PDF, Word or HTML; citations copy as BibTeX or RIS, or go to Zotero.

**Fixed since 1.0 (1812):** many things, on every tab, among them a crash when deleting a note from All Notes on an iPad.

## What to test

1. **1812 and 1787 testers:** after the re-index, are your notes, highlights, tags and collections all there? Are your reports fixed?
2. **Import:** before you update, export from 1.0 (1812) (Settings ▸ System ▸ Data & Recovery ▸ **Export as JSON**); after, **Import from JSON…** that file, and one from FRUS Explorer Light if you use it. Does the report match what you had, and do the imported records reach your other devices through iCloud?
3. **Templates:** apply each of the six to a collection, then export it.
4. **Subjects:** Browse ▸ **Subjects**, then search the index. On an iPhone with iOS 27, is there a search field?
5. **Downloads:** queue several volumes, then **Cancel All**. Queue a few more and leave the app while they index: is the Live Activity right on the Lock Screen, and is the queue done when you come back?
6. **Charts:** on iOS 27.2, does each bar's name sit beside its own bar, in Person, Cross-Reference and Archival Analytics and About the Series' Geography?
7. **Voice Control:** on Browse's first screen, do "Tap Archives", "Tap Administrations", "Tap Editors" and "Tap Clusters" open them?

Report device, iOS version, taps, expected, actual and a document id. Thanks!
