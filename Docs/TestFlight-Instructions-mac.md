# What's New in Build 30 (Mac)

Build 30 gathers the tester-feedback fixes and research tools added since build 28 (build 29 was internal only). **No re-index this time** — the update is ready to use immediately.

## Analytics (dedicated windows)
- **Scope + year range** — Corpus, Person, and Cross-Reference Analytics gained a **Scope** control (Whole corpus / By Subseries / By Volume) and a year-range bar, so you can narrow any dashboard to a project-specific slice. Cross-Reference figures are **source-anchored** (counted from the citing document), so scoping to an era or volume never collapses the graph.
- **Same-volume references counted** — Cross-Reference figures (Most-Referenced Documents, the degree-distribution histogram, and PageRank influence landmarks) now include within-volume citations that were previously dropped, so counts and rankings rise. The volume-to-volume heat matrix is unchanged by design (it plots connections *between* volumes).

## Collections (⇧⌘K)
- **Editor** — with the inspector open, a single click on any document row now moves the inspector to that row (double-click / Return / ⓘ still open it). The inspector is titled with the collection's own name and pins a **Collection** section at the top — description, subtitle, author line, colophon, and all export-composition defaults — so collection-wide settings stay reachable while a document is focused.
- **Add Documents (⇧⌘A)** — the **Search** tab now shows a matched snippet + archival source note under each result, so you can judge relevance before adding. The preview length follows the global snippet-length setting, with a per-sheet override.

## Settings (⌘,)
- **Sync Diagnostics** (General → Sync Diagnostics) — a local, on-device, **redacted** log of iCloud sync events you can read and export (as JSON) to help diagnose sync problems. It records only event types, timing, and error codes — never identifiers, account identity, or anything about your documents. Try Copy, Export…, and Clear Log.

## Feedback
Report crashes, freezes, or anything unexpected — especially wrong/missing analytics after scoping, the Collections inspector re-targeting on the wrong row, add-document previews that look off, multi-window behavior, or sync errors (grab a Sync Diagnostics export if you hit one). Include your macOS version, the volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
