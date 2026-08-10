# What's New in Build 40 (iOS)

Source Explorer now tells you what the National Archives can tell you *before you travel* — who made the records, whether you can read them, whether you can publish what you find, and how much material there is. Search facets accept more than one year. Zotero stopped being a dead end on iPhone and iPad. There are two new lookups: a footnote triage table and a corpus-wide abbreviation search.

**This build re-indexes on first launch.** Front-matter parsing changed, so the app rebuilds its archival keys once. It is quick, and it is what puts the new Source Explorer rows in place.

## What NARA can tell you before you travel

Open a document whose citation resolves to a NARA series — a lot file like *Lot 64 D 199* is the common case — and the **NARA Catalog Record** panel now carries four things it never had:

- **Created by** — the office that actually made the records. FRUS names the container; it never names the bureau. *Department of State. Office of the Secretary. Executive Secretariat.* and 363 others.
- **Access** — whether you can read them at all, and why not. Two-thirds of the series the app can name are restricted in some degree, most citing FOIA (b)(1) National Security.
- **Use** — whether you can *publish* what you find. This is a different question from whether you can read it, and it is the one researchers discover too late. Some series are freely readable and copyright-restricted; some are the reverse.
- **Extent** and **Held At** — "1 linear foot, 3 linear inches", and which building.

Where NARA lists a folder or container list, **Finding Aids** says so.

These are absent on most decimal-file citations, and that absence is deliberate: those resolve to a whole record group, whose creator would read "Department of State" for three-quarters of the corpus. A blank row is more honest than one label repeated everywhere.

## Choosing more than one year

Search facets used to take one value. **Years** and **Volumes** now accept several — tap to include, tap again to exclude, then **Apply**. The chip reads what you actually chose.

While mapping this we found a shipped defect worth naming: the Years facet counted documents by their *start* year but filtered by date-range *overlap*, so the row that said 7,392 delivered 7,892. The two now agree.

## Where the editors pointed outside the printed record

A new **Flows** layer in Archival Analytics shows where FRUS's footnotes point to archives *outside* the documents it prints — a third body of evidence, distinct from where a printed document came from. Read the caveat on the surface: 95% of these are an editor's annotation, so a cell describes editorial practice, not a relation between archives.

## Zotero: no more dead ends

If you have no Zotero API key, the document Share menu now offers **Send to Zotero (web page)**, which Zotero's share extension actually ingests. The RIS and BibTeX files never could — Zotero on iOS has no File → Import and no citation-file parser, so those files appeared to work and did nothing. The collection sheet now says plainly that its RIS is for Zotero **on a Mac**. And a failed send offers to save the file rather than stopping at an error.

## Two new lookups

**Batch citation triage.** In Citation Lookup, choose **Batch** and paste a chapter's footnotes. Each becomes a row: resolved, ambiguous, or needing work — sorted worst-first. Numbered notes split on their numbers, and a note wrapped across lines is rejoined.

**Abbreviations.** Search's overflow menu now has **Look up an abbreviation**, searching every downloaded volume's glossary at once. FRUS editors did not standardise: `EUR` carries 30 different definitions across 231 volumes. Contested terms show all of them, most widely used first.

## Smaller things

- **Drag a chart to narrow the years.** In Corpus Analytics, drag across the plot. On By Decade a drag from 1950 to 1960 selects 1950–1969 — the whole decade you drew.
- **Related Documents admits when it cut you off.** Ranking works over a bounded pool; on a document in a very large archival container it now says how many neighbours were never scored. Two in five source-noted documents sit in such a container.
- **Side-loaded volumes** are browsable, and correctly refuse to cite as published.
- **Actions reach the window they belong to** on iPad with Stage Manager.

## What to test

1. Open a document citing a lot file and check the **NARA Catalog Record** panel. Do Access/Use read sensibly? A series can be *Unrestricted* to read and copyright-restricted to publish — that pairing is correct, not a bug.
2. Open a document citing a **decimal file**. The creator and access rows should be **absent**, not "Department of State".
3. In Search facets, include two years and exclude a third. Does the chip say what you chose?
4. Paste a chapter of footnotes into Citation Lookup ▸ Batch — especially one where a note **wraps across lines**. It should be one row, not three.
5. Look up `EUR` in the abbreviation search and expand its other definitions.
6. With no Zotero account, use **Send to Zotero (web page)** from a document. Does Zotero create a real item?
7. **VoiceOver users, especially:** the Series analytics charts now have Audio Graph descriptors for the first time. Entering a chart should announce its title and axes, and the graph's shape should match what is drawn. This is new and unvalidated on a real screen reader — please tell us what you hear.

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
