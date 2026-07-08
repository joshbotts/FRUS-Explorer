# What's New in Build 31 (Mac)

Build 31 is a polish-and-fixes pass on the research tools from builds 28–30, plus a new way to scope Archival Neighbors and macOS parity for two iOS features. **No re-index** — ready immediately.

## Archival Neighbors (windows)
- **Scope selector** — the Archival Neighbors window (and the inline Source Explorer "Documents from This Collection" section) now has a **This volume / This subseries / All indexed volumes** control that re-runs the list in place. A document opens at *All indexed volumes*; a volume's Sources entry opens at *This volume*. The chosen scope is part of the window's identity, so it restores on relaunch, and the same source returns the same set of *other* documents whichever action opened it (a document window excludes the document you started from).

## Analytics (windows)
- **Collapsible charts** — Person and Cross-Reference Analytics group their charts into collapsible sections, each with its own controls (chart/table toggle, the out-degree overlay); the shared toolbar is gone. Confirm expand/collapse persists.
- **Cleaner cross-reference figures** — Cross-Reference Analytics no longer ranks non-document targets (page anchors, footnotes, index items, chapters, appendices) as "landmark documents"; un-downloaded landmarks read as "Document N — volume title" with a hint.
- **Consistent subseries** — Corpus Analytics → **Subseries** now buckets early annual, conference, and supplement volumes by publication year to match the Corpus Browser.

## Corpus Browser
- **Early volumes browse without indexing** — a downloaded-but-unindexed early annual volume (e.g. an 1860s *Papers Relating to Foreign Affairs*) now opens its full front matter and chapters immediately, with a non-blocking **Index / Re-index** banner instead of a blocking "Index Required" wall. Full-text search, chapter document lists, and the connections graph still wait for indexing.

## Search (⇧⌘F)
- **Live tag filter chips** — the Search window's **Advanced…** filter now has a **My Tags** section listing your tags that updates live when you create, rename, or delete a tag elsewhere (matching iOS); picking one narrows results immediately and lights the **Tagged** chip above the list.
- **Checklist Mode button** — the checklist control in the sort bar is now an icon-plus-text **Checklist** button that reads without hovering and highlights while it's on.

## Source Explorer & Citations
- **Pre-1906 source links** — Source Explorer again resolves 19th-century / pre-1906 central-files citations to the right bundled reel-level / country-series link.
- **Citation Lookup round-trip** — pasting a citation the app produced (⌘⇧F) reopens the *exact* document, including pre-1906 *Papers Relating to Foreign Affairs* part volumes where the title fragment disambiguates a print-year collision.

## Collections (⇧⌘K)
- **Window shows all projects by default** — the Collections window now lists collections from every project by default, with a banner offering **Scope to '<project>'** and **Show All** (previously it hard-filtered to the active project with no override).

## Feedback
Report anything unexpected — especially wrong or empty Archival Neighbors after scoping, tag chips out of sync, an unindexed early volume that won't open, a Citation Lookup on the wrong document, or a pre-1906 source link that misses. Include your macOS version, the volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
