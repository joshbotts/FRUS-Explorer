# Testing FRUS Explorer 1.0 (iOS)

**Release candidate.** Version 1.0 (1842) is the app meant for the App Store; unless your reports stop it, this is 1.0.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**Tested 1.0 (1823)?** Nothing re-indexes. **From 1.0 (1812) or (1787)**, first launch re-indexes your library once; from 1776 it also rebuilds People once, in the background.

## New since 1.0 (1812)

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

**Fixed since 1.0 (1812):** many things, on every tab, among them two crashes on an iPad: deleting a note from All Notes, and narrowing the window with a document's Research rail open.

## What to test

1. **Earlier testers:** are your notes, highlights, tags and collections all there? Are your reports fixed?
2. **iPad:** open a document with its Research rail, then narrow the window and widen it again, several times (Stage Manager or Windowed Apps). Does the app stay up, with the rail back at full width?
3. **Two devices:** keep All Notes open on one while you add and delete a note on the other. Does the list follow without a relaunch?
4. **Collections:** on an iPhone, swipe a collection and tap **Delete**. Does the question wait for your answer, and does closing it keep the collection?
5. **Import:** export as JSON on one device (Settings ▸ System ▸ Data & Recovery ▸ **Export as JSON**) and **Import from JSON…** it on another, or one from FRUS Explorer Light. Does the report match what you had?
6. **Indexes and graphs:** in a volume's index, does a *See* reference bring its entry into view? Zoomed in, does each network graph stay inside its frame?
7. **Templates:** apply each of the six to a collection, then export it.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
