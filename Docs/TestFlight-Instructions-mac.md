# What's New in Build 32 (Mac)

Build 32 is a big feature wave: **Collections is rebuilt from the ground up** ("Composer"), broken cross-references are labeled instead of dead-ending, people can be merged by hand, volumes get Top subjects profiles, Citation Lookup results open in their own window, and the series dashboards gain scoping. **One-time re-index** — first launch rebuilds the cross-reference index (v22) in the background; it may take a while on a large library, but the app stays usable. It also fixes some cross-volume page references that pointed at the wrong document in graphs and analytics.

## Collections, redesigned ("Composer")
Assembling and exporting document sets is rebuilt, and the Collections window (**⇧⌘K**) is now a true Mac layout that fits a 13″ screen.
- **No sidebar** — switch collections from a **toolbar collection picker** (each with its document count, plus **New**, **Import**, and **Manage Collections…**); the single middle column is the **Contents** outline, with a **live preview** beside it.
- **⚙ Collection popover** — the collection's name, note, title-page front matter, the **presets**, and the three grouped composition sections all live in one popover; a single document's settings open in a **dismissible inspector** column from a **⚙ Configure** pill on the row (replacing the old ⓘ glyph).
- **Presets + grouped composition** — three labeled sections (Document content · Your annotations · Analysis & apparatus) and **four one-tap presets** — Teaching reader · Briefing packet · Source dossier · Scholarly edition — that set the whole composition at once.
- **Editable "Key takeaway" headnote** — **Generate** an on-device AI draft, **Edit** it in your own words, or **Regenerate**; a chip marks whether the text is AI or yours, and exports attribute it honestly.
- **Cleaner rows** — a document row shows **labeled override chips** only when it differs from the collection default.
- **Export** — a **grid of format cards** (PDF · HTML · Word · BibTeX · RIS · .fruscollection) led by a one-line composition summary, plus a separate **Send to Zotero Library** row.

## Cross-References
- **Unresolvable links are labeled** — cross-references that corpus-wide validation confirms can't be followed (the print edition cites a page, document, or volume absent from the digital corpus) now render in muted grey with a dotted underline and a small dagger, instead of looking like working links. Clicking one opens an **Unresolved Reference** sheet explaining why and the apparent destination. Valid references and the printed text are unchanged.
- **Analytics disclosure** — when any fall in scope, Cross-Reference Analytics notes "N unresolvable references are excluded from this analysis".
- **Report export** — the **Settings → Data** pane adds a **Broken Cross-References Report** (CSV or JSON) for reporting to the Office of the Historian.

## People
- **Manual merge** — **Merge with another person…** (in a person's detail sheet, or the row's context menu) merges two people into one identity, for cases the app's deliberately cautious automatic grouping kept apart. The confirmation names both and warns when they look like genuinely different people (distinct Office of the Historian identities). A **Corrections** toolbar button lists every merge and separation you've made, with undo; they sync via iCloud.

## Corpus Browser
- **Top subjects** — every volume shows the subjects most characteristic of it (from the Office of the Historian's subject data), grouped by category, visible before downloading. Click one to see the *other* FRUS volumes covering it corpus-wide (even undownloaded) and jump there.

## Citation Lookup (⇧⌘F)
- **Own-window results, Return to run** — the lookup form is now grouped and Return runs it; a result opens the document in its own window (with previous/next navigation), so the match list stays visible.
- **Document-number lookups** — document-number citations now reliably find their document on indexed volumes.

## Analytics (windows)
- **Series dashboard scoping** — each **About the Series** dashboard (Research Guide) gains a **Scope** control: **Whole series** / **By Subseries** (nested by decade). Archival Sourcing Over Time adds a **Categories** filter that re-bases the mix to the shown categories (the last visible one can't be hidden); Administration Production Profiles adds a year-range bar showing administrations overlapping the years. **Reset** clears both scope and year range.
- **Administration presets** — Corpus and Cross-Reference Analytics add an Administration menu that sets the document-year range to a president's term in one click.
- **Per-cloud word hiding** — a word's context menu can hide it from just the current cloud (it returns when the cloud regenerates), alongside the persistent global/per-lens lists; **Show N hidden words** restores all.

## Tags
- **New Tag field on top** — the tag picker's New Tag field moved to the top; tags created in the sheet pin to the top with a **New** badge until it closes, and the title shows the document ("Tags - Doc N").

## Performance
- **Faster launch, smaller app** — a 9 MB synchronous parse was removed from launch; the app bundle is ~8.5 MB smaller.

## Feedback
Report anything unexpected — especially anything off in the redesigned **Collections** (the toolbar picker and ⚙ Collection popover; building, previewing, or exporting a collection; the Key-takeaway headnote card), a working link shown as unresolvable (or vice versa), a merge/undo that misbehaves, wrong-looking Top subjects, or analytics that shift oddly after scoping. Include your macOS version, volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
