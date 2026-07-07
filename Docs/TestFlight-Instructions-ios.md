# What's New in Build 30 (iOS)

Build 30 gathers the tester-feedback fixes and research tools added since build 28 (build 29 was internal only). **No re-index this time** — the update installs and is ready to use immediately.

## Search
- **Checklist Mode** — work a long result list like a shrinking to-do list. Turn it on from the search **••• (overflow) menu**; opening a result (or swiping a row → **Reviewed**, or long-press → **Mark Reviewed**) hides it, a "N reviewed hidden" banner tracks progress, and an **All Results Reviewed** state appears when you finish. It's per-session and resets on relaunch; starting a new search re-anchors it. Confirm reviewed rows disappear and the count/timeline stay correct.
- **Adjustable snippet length** — choose how many lines of matched context each result shows (1–10, was fixed at 3). Set the global default in **Settings → General → Search Defaults → Result Preview**; override just one surface from the main-search **filter (funnel) panel** or the **Add Documents** sheet's text-lines menu. Confirm changes apply live and stick across launches.
- **Add-document previews** — in a collection's **Add Documents → Search** tab, each result now shows a matched snippet + archival source note, so you can judge it without opening.
- **Live tag filter chips** — user-tag chips in the search filter now update the moment you create, rename, or delete a tag elsewhere (e.g. in a research note) — no relaunch. Changes arriving from another device via iCloud show up too.

## Analytics (Browse → Analysis Tools)
- **Scope + year range** — Corpus, Person, and Cross-Reference Analytics gained a **Scope** bar (Whole corpus / By Subseries / By Volume) and a year-range bar, so you can narrow any dashboard to a project-specific slice. Cross-Reference figures are **source-anchored** (counted from the citing document), so scoping never collapses the graph.
- **Same-volume references counted** — Cross-Reference figures (Most-Referenced, degree distribution, PageRank influence) now include within-volume citations that were previously dropped, so counts and rankings rise. The volume-to-volume heat matrix is unchanged by design.
- **iPhone Options menu** — Corpus and Person Analytics fold their secondary controls into a single **Options (•••)** button so pickers like Values no longer truncate in the narrow toolbar.

## Collections
- **Editor** — tap **anywhere on a document row** to open its inspector (not just the ⓘ button). The inspector is now titled with the collection's own name and pins a **Collection** section at the top (description, subtitle, author line, colophon, and all export-composition defaults), so collection-wide settings stay reachable while a document is focused.

## Settings
- **Sync Diagnostics** (Settings → Data) — a local, on-device, **redacted** log of iCloud sync events you can read and export to help diagnose sync problems. It records only event types, timing, and error codes — never identifiers, account identity, or anything about your documents. Try Copy, Export, and Clear.

## Feedback
Report crashes, freezes, or anything unexpected — especially wrong/missing analytics after scoping, snippet length not sticking, checklist rows that won't hide, tag chips out of sync, or Collections inspector glitches. Include your device + iOS version, the volume/document number (top of screen), what you tapped, expected, and got. Screenshots help. Thanks for testing!
