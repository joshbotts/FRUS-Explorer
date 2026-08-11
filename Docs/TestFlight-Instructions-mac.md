# What's New Since Build 37 (Mac)

Three builds at once. The headline is **Archival Analytics**, a new way to see which archives FRUS drew on. Source Explorer now answers trip-planning questions. Plus two new lookups, multi-select search facets, and window and menu repair.

**First launch re-indexes every volume you have downloaded, and it is not quick** — the index format moved a long way since build 37. The app stays usable and offers the Research Guide while it runs, but Search results and analytics are incomplete until it finishes.

## Archival Analytics (new)

Its own window: sidebar ▸ **Archival Analytics**, the Analytics menu, or the door on the Research Guide's Archival Sourcing page. Four views:

- **Collections** — which archival units the editors leaned on, ranked inside one era band. Central-file class keys now read in words: `812.6363` is *Mexico — Petroleum*.
- **Network** — which collections the same volumes drew on together, in custodian sectors.
- **Flows** — where footnotes point *outside* the printed record.
- **Your Library** — the archival profile of the volumes you have indexed.

Two things that look like bugs and are not. Class readings appear only in **Through 1947**; the classification was renumbered in 1950 and later eras are left bare rather than guessed. And the *Central Files* umbrella is withheld from the ranking by default — one undifferentiated record that would flatten every other bar. Both say so on screen.

## What NARA can tell you before you travel

On a citation that resolves to a NARA series, the **NARA Catalog Record** box now carries **Created by**, **Access** (whether you can read it), **Use** (whether you can publish it — a different question), **Extent**, and **Held At**. Presidential-library citations route to the right finding aid. Unverified lookups are labelled *candidates*, not answers. For a lot NARA split across several series, the creator appears only when every claimant agrees.

These rows are **absent** on most decimal-file citations by design: those resolve to a whole record group whose creator would read "Department of State" for three-quarters of the corpus.

## Two new lookups

**Batch citation triage** — Citation Lookup ▸ Batch. Paste a chapter's footnotes; each becomes a row, worst-first, and a resolved row opens its document. **Abbreviations** — Search's overflow menu. `EUR` carries 30 definitions across 231 volumes.

## Smaller things

Search facets take several years at once (click to include, again to exclude). Corpus Browser moved to the **Find** menu beside Search and Citation Lookup, and ⌘⇧B now fronts an open-but-buried window instead of doing nothing. Drag across a Corpus Analytics chart to narrow the years. Related Documents says when the pool cut you off. Side-loaded volumes are browsable.

## What to test

1. Let the re-index finish. Tell us roughly how long, and how many volumes.
2. Open **Archival Analytics** and step through all four views and all five era bands. Anything that reads as empty, wrong, or unexplained. Watch the layout — long collection names and class readings can run wide.
3. In **Collections**, check the class readings in Through 1947 — do they match the number? Then confirm later bands show bare numbers.
4. Open a document citing a lot file: does **Access**/**Use** read sensibly? A long FOIA list can run wide.
5. Open a document citing a **decimal file**. Creator and access rows should be absent, not "Department of State".
6. Open a **divided lot** (`61D146` has 13 claimants). A creator should appear only if they agree.
7. Paste a chapter of footnotes into Citation Lookup ▸ Batch, especially one where a note **wraps across lines**.
8. Drag across a Corpus Analytics chart. Confirm the drag does not fight window or text selection.

Include macOS version, what you clicked, what you expected, what happened. Thanks!
