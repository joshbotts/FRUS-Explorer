# What's New in Build 31 (iOS)

Build 31 is a polish-and-fixes pass on the research tools from builds 28–30, plus a new way to scope Archival Neighbors. **No re-index** — it installs and is ready immediately.

## Archival Neighbors
- **Scope selector** — the Archival Neighbors sheet now has a **This volume / This subseries / All indexed volumes** control that re-runs the list in place. A document opens at *All indexed volumes*; a volume's Sources entry opens at *This volume*. The same archival source returns the same set of *other* documents no matter which surface you opened it from (a document view excludes the document you started from). Confirm switching scope re-runs the list and that a source reached from a document, a search result, a graph node, or a Sources entry stays consistent.

## Analytics (Browse → Analysis Tools)
- **Collapsible charts** — Person and Cross-Reference Analytics now group their charts into collapsible sections, each with its own controls (chart/table toggle, By-decade, Values, the out-degree overlay); only the mode picker stays in the toolbar. Confirm sections expand/collapse and the choice sticks.
- **Cleaner cross-reference figures** — Cross-Reference Analytics no longer counts non-document targets (page anchors, footnotes, back-of-book index items, chapters, appendices) as "landmark documents"; un-downloaded landmarks now read as "Document N — volume title" with a hint rather than an opaque key.
- **Consistent subseries** — Corpus Analytics → **Group by → Subseries** now buckets early annual, conference, and supplement volumes by publication year to match the Corpus Browser (they were previously dropped or split off under an area label).
- **More toolbar room** — Corpus, Person, Cross-Reference, and Chronology no longer squeeze a centered screen title into the toolbar on iPhone, so the controls render fully; VoiceOver still announces each screen's name.

## Search
- **Checklist Mode is easier to find** — the Checklist toggle is now a labeled button in the always-visible search actions bar (right of the timeline button), enabled once a search has results and tinted while active — no longer buried in the ••• menu.

## Source Explorer & Citations
- **Pre-1906 source links** — Source Explorer again resolves 19th-century / pre-1906 central-files citations (e.g. an 1863 despatch, frus1863p2/d1) to the right bundled reel-level / country-series link. Confirm an 1860s–1900s document's source note links correctly.
- **Citation Lookup round-trip** — pasting a citation the app produced (Search tab → Citation Lookup) now reopens the *exact* document, including pre-1906 *Papers Relating to Foreign Affairs* part volumes where the title fragment disambiguates a print-year collision.

## Collections
- **Manager shows all projects by default** — the Collection Manager now lists collections from every project by default, with a banner offering **Scope to '<project>'** to narrow and **Show All** to restore.

## Feedback
Report anything unexpected — especially wrong or empty Archival Neighbors after scoping, mismatched subseries buckets, cross-reference figures that look off, a Citation Lookup landing on the wrong document, or a pre-1906 source link that misses. Include your device + iOS version, the volume/document number (top of screen), what you tapped, expected, and got. Screenshots help. Thanks for testing!
