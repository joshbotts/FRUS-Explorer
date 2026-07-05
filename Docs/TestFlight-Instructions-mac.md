# What's New in Build 28 (Mac)

Build 28 carries everything added since build 26. New to the app? Open the **Corpus Browser (⇧⌘B)**, pick a subseries (e.g. "1964–1968"), download 2–3 volumes, and let **Settings (⌘,) → Index Health** finish before judging results.

## ⚠️ One-time re-index on first launch
If you already have volumes downloaded, this update re-indexes them **once** (the search index moved to v21 so page-number references like "see p. 427" now resolve to the correct document). Expect Index Health to show re-indexing on first launch — let it finish, then open a document with a "see p. NNN" reference and confirm it navigates correctly.

## New surfaces to exercise
- **Person Analytics** (its own window, from the Tools toolbar). *Trends:* most-mentioned people by era, compare up to 5 people's mention trajectories, and a two-person co-mention chart. *Network:* a co-mention ego-graph around a focus person. Pick people; confirm the charts populate and update.
- **Cross-Reference Analytics** (its own window): most-referenced documents (in-degree), a degree-distribution histogram, a volume-to-volume citation heat matrix, and offline PageRank "influence" landmarks. Sanity-check the rankings and heat matrix.
- **About the Series** (FRUS Research Guide): four dashboards that render with **no index** — try them mid-onboarding. Production & Timeliness, Geographic Emphasis, Archival Sourcing, and Administration Profiles (per president). On each, try the editable **year range** and the per-chart **View as table** (Copy CSV). Report any figure that looks wrong.
- **Corpus Analytics:** a new **"% of documents"** toggle on the By-Year/By-Decade charts reads a term as a share of the corpus rather than a raw count. Confirm the axis and values switch sensibly.
- **Collections (⇧⌘K):** the manager ribbon is consolidated into **four controls** — **Add ▾** (Documents / Section Heading / Note Block / Passages / Apparatus) · **Sort by Date ▾** · **View ▾** (Composition / Front Matter / Preview) · **Export…**; confirm every action you used before is still reachable. **Sort by Date** now offers **Across the Whole Collection** vs **Within Each Section** (confirm within-section never moves a document across a heading). The collection **note** collapses to an **"Add a note"** affordance (confirm it expands and persists). Also re-test the reworked editor: add documents (search / browse / paste citations & links / by tag), rich-text prose + Link, the ⓘ inspector, the live preview (eye button), and PDF/HTML/DOCX + `.fruscollection` export plus double-click import.

## Feedback
Report crashes, freezes, or anything unexpected — especially misfiring links/source notes, graph and chart interactions, the word cloud, Collections export/round-trip, Send to Zotero, the People index, multi-window behavior, AI summaries, and searches returning too few/many. For the new analytics, flag wrong/missing people or documents and broken graphs/histograms/heat matrices; for the dashboards, wrong figures or misbehaving year-range/table controls; and confirm the one-time re-index completed cleanly.

Include your macOS version, the volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
