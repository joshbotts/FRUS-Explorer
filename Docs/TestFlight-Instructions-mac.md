# What's New in Build 40 (Mac)

Source Explorer now tells you what the National Archives can tell you *before you travel* — who made the records, whether you can read them, whether you can publish what you find, and how much material there is. Search facets accept more than one year. There are two new lookups: a footnote triage table and a corpus-wide abbreviation search.

**This build re-indexes on first launch.** Front-matter parsing changed, so the app rebuilds its archival keys once. It is quick, and it is what puts the new Source Explorer rows in place.

## What NARA can tell you before you travel

Open a document whose citation resolves to a NARA series — a lot file like *Lot 64 D 199* is the common case — and the **NARA Catalog Record** box now carries four things it never had:

- **Created by** — the office that actually made the records. FRUS names the container; it never names the bureau. *Department of State. Office of the Secretary. Executive Secretariat.* and 363 others.
- **Access** — whether you can read them at all, and why not. Two-thirds of the series the app can name are restricted in some degree, most citing FOIA (b)(1) National Security.
- **Use** — whether you can *publish* what you find. This is a different question from whether you can read it, and it is the one researchers discover too late. Some series are freely readable and copyright-restricted; some are the reverse.
- **Extent** and **Held At** — "1 linear foot, 3 linear inches", and which building.

Where NARA lists a folder or container list, **Finding Aids** says so.

These are absent on most decimal-file citations, and that absence is deliberate: those resolve to a whole record group, whose creator would read "Department of State" for three-quarters of the corpus. A blank row is more honest than one label repeated everywhere.

For a lot NARA split across several series, the creator appears **only when every claimant agrees** — a divided lot can have several creating offices, and naming one would be false for the rest.

## Choosing more than one year

Search facets used to take one value. **Years** and **Volumes** now accept several — click to include, click again to exclude, then **Apply**. The chip reads what you actually chose.

While mapping this we found a shipped defect worth naming: the Years facet counted documents by their *start* year but filtered by date-range *overlap*, so the row that said 7,392 delivered 7,892. The two now agree.

## Where the editors pointed outside the printed record

A new **Flows** layer in Archival Analytics shows where FRUS's footnotes point to archives *outside* the documents it prints — a third body of evidence, distinct from where a printed document came from. Read the caveat on the surface: 95% of these are an editor's annotation, so a cell describes editorial practice, not a relation between archives.

## Two new lookups

**Batch citation triage.** The Citation Lookup window has a **Batch** mode: paste a chapter's footnotes and each becomes a row — resolved, ambiguous, or needing work — sorted worst-first. Numbered notes split on their numbers, and a note wrapped across lines is rejoined. A resolved row opens its document in a real window.

**Abbreviations.** Search's overflow menu now has **Look up an abbreviation**, searching every downloaded volume's glossary at once. FRUS editors did not standardise: `EUR` carries 30 different definitions across 231 volumes. Contested terms show all of them, most widely used first.

## Smaller things

- **Drag a chart to narrow the years.** In Corpus Analytics, drag across the plot. On By Decade a drag from 1950 to 1960 selects 1950–1969 — the whole decade you drew.
- **Related Documents admits when it cut you off.** Ranking works over a bounded pool; on a document in a very large archival container it now says how many neighbours were never scored. Two in five source-noted documents sit in such a container.
- **Side-loaded volumes** are browsable, and correctly refuse to cite as published.
- Zotero's collection export now states plainly that its RIS file is for **File → Import** on the desktop, and a failed API send offers to save that file rather than stopping at an error.

## What to test

1. Open a document citing a lot file and check the **NARA Catalog Record** box. Do Access/Use read sensibly? A series can be *Unrestricted* to read and copyright-restricted to publish — that pairing is correct, not a bug. Watch the layout: a long FOIA list can run wide.
2. Open a document citing a **decimal file**. The creator and access rows should be **absent**, not "Department of State".
3. Open a **divided lot** (the candidates panel, e.g. `61D146` with 13 claimants). A creator should appear only if the claimants agree.
4. In Search facets, include two years and exclude a third. Does the chip say what you chose?
5. Paste a chapter of footnotes into Citation Lookup ▸ Batch — especially one where a note **wraps across lines**. It should be one row, not three.
6. Look up `EUR` in the abbreviation search and expand its other definitions.
7. Drag across a Corpus Analytics chart. Confirm the drag does not fight window or text selection, and that **By Decade** gives you the whole decade.
8. **VoiceOver users, especially:** the Series analytics charts now have Audio Graph descriptors for the first time. Entering a chart should announce its title and axes, and the graph's shape should match what is drawn. This is new and unvalidated on a real screen reader — please tell us what you hear.

Include macOS version, what you clicked, what you expected, what happened. Thanks!
