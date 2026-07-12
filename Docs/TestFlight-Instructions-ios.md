# What's New in Build 32 (iOS)

Build 32 is a big feature wave: **Collections is rebuilt from the ground up** ("Composer"), broken cross-references are labeled instead of dead-ending, people can be merged by hand, every volume gets a Top subjects profile, and the series dashboards gain scoping. **One-time re-index** — first launch rebuilds the cross-reference index (v22) in the background; it may take a while on a large library, but the app stays usable. It also fixes some cross-volume page references that pointed at the wrong document in graphs and analytics.

## Collections, redesigned ("Composer")
Assembling and exporting document sets is rebuilt, cleanly split into a **manager** (what's in the collection and how it's composed) and **export** (just format + destination).
- **Presets + grouped composition** — the export settings sit in three labeled sections (Document content · Your annotations · Analysis & apparatus), and **four one-tap presets** — Teaching reader · Briefing packet · Source dossier · Scholarly edition — set the whole composition at once.
- **Editable "Key takeaway" headnote** — a document can print a short abstract above its body: **Generate** an on-device AI draft, **Edit** it in your own words, or **Regenerate**. A chip marks whether the text is AI or yours, and exports attribute it honestly.
- **Cleaner document rows** — a row shows **labeled override chips** only when it differs from the collection default, and a **⚙ Configure** control (replacing the old info glyph) opens that document's settings.
- **Per-platform layout** — on **iPad**, two roomy columns (Contents + a live preview) with settings summoned as sheets (a **⚙ Collection** sheet and per-row **⚙ Configure** sheets); on **iPhone**, the Outline leads with a **Collection settings** row, and each document row is a chevron disclosure that drills into its settings.
- **Export** — a **grid of format cards** (PDF · HTML · Word · BibTeX · RIS · .fruscollection) led by a one-line composition summary, plus a separate **Send to Zotero Library** row.

## Cross-References
- **Unresolvable links are labeled** — cross-references that corpus-wide validation confirms can't be followed (the print edition cites a page, document, or volume absent from the digital corpus) now render in muted grey with a dotted underline and a small dagger, instead of looking like working links. Tapping one opens an **Unresolved Reference** sheet explaining why and the apparent destination. Valid references and the printed text are unchanged.
- **Analytics disclosure** — when any fall in scope, Cross-Reference Analytics notes "N unresolvable references are excluded from this analysis".
- **Report export** — **Settings → Export Research Data** adds a **Broken Cross-References Report** (CSV or JSON) for reporting to the Office of the Historian.

## People
- **Manual merge** — **Merge with another person…** (in a person's detail sheet, or the row's context menu) merges two people into one identity, for cases the app's deliberately cautious automatic grouping kept apart. The confirmation names both and warns when they look like genuinely different people (distinct Office of the Historian identities). A **Corrections** toolbar button lists every merge and separation you've made, with undo; they sync via iCloud.

## Browse
- **Top subjects** — every volume shows the subjects most characteristic of it (from the Office of the Historian's subject data), grouped by category, visible before downloading. Tap one to see the *other* FRUS volumes covering it corpus-wide (even undownloaded) and jump there.
- **Two-line titles** — long volume titles on volume/chapter screens now wrap to two lines instead of truncating.
- **iPad navigation** — the breadcrumb bar is gone; the tab sidebar and back button navigate, and Browse uses push navigation on all devices.

## Analytics
- **Series dashboard scoping** — each **About the Series** dashboard (Research Guide) gains a **Scope** control: **Whole series** / **By Subseries** (nested by decade). Archival Sourcing Over Time adds a **Categories** filter that re-bases the mix to the shown categories (the last visible one can't be hidden); Administration Production Profiles adds a year-range bar showing administrations overlapping the years. **Reset** clears both scope and year range.
- **Administration presets** — Corpus and Cross-Reference Analytics add an Administration menu that sets the document-year range to a president's term in one tap.
- **Per-cloud word hiding** — a word's context menu can hide it from just the current cloud (it returns when the cloud regenerates), alongside the persistent global/per-lens lists; **Show N hidden words** restores all.

## Tags
- **New Tag field on top** — the tag picker's New Tag field moved to the top; tags created in the sheet pin to the top with a **New** badge until it closes, and the title shows the document ("Tags - Doc N").

## Citations
- **Document-number lookups** — document-number citations now reliably find their document on indexed volumes.

## Performance
- **Faster launch, smaller app** — a 9 MB synchronous parse was removed from launch; the app bundle is ~8.5 MB smaller.

## Feedback
Report anything unexpected — especially anything off in the redesigned **Collections** (building, previewing, or exporting a collection; the Key-takeaway headnote card; the presets), a working link shown as unresolvable (or vice versa), a merge/undo that misbehaves, wrong-looking Top subjects, or analytics that shift oddly after scoping. Include your device + iOS version, volume/document number, what you tapped, expected, and got. Screenshots help. Thanks for testing!
