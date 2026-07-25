# What's New in Build 35 (Mac)

Build 35 is about **organizing your research and analyzing the corpus**: Research Projects grow a real workflow, Corpus Analytics learns to compare and export through the save panel, and the app gains find-in-document. No re-index needed.

## Research Projects, grown up
- **Project Home** — a dashboard of the active project's activity: recent documents, notes, collections, and **Project Leads**.
- **Project Leads** — ranked suggestions for what to read next, aggregated from everything the project has touched, with **tunable weights** and per-lead "why" evidence. Dismissing a lead backfills the next candidate.
- **Search inside your project** — the Search window's filters gain a project scope: **History** (only documents this project has collected, annotated, or visited) or **Focus** (volumes your project's subjects point to, with "only new").
- The **Research menu** gains **Switch Project** and **New Project…**; exports carry the project's **name and research question** on the title page.

## Find, finally
- **⌘F — Find in Document** opens a find bar over the reading view (next/previous, match count). A **Find menu** joins the menu bar; window-level **Search moved to ⌘S**.

## Corpus Analytics: compare, save, export
- **Compare up to 5 terms** as chips on one chart; **% of documents** normalization keeps eras comparable.
- **Save a query** (bookmark button) and rerun it later; recent queries are kept automatically.
- **Export** any chart as **CSV, PNG, or PDF** through a standard **save panel** — the CSV opens with a `#`-commented method block (scope, year range, caveats); the PDF is vector, sharp at any size. Figures are offered on time axes; Landmark Documents and By Subseries / By Volume are CSV-only by design. The **heat-matrix figure** prints every cell's count so an exported matrix is checkable. Word clouds export the same way, with a ranked CSV that records your filters and hidden words.
- The on-screen **heat matrix** is rebuilt (bigger cells, readable codes); **ⓘ buttons** on every analytics view explain what you're seeing; the Person co-mention graph gains a docked detail card.

## Windows
- The **Window menu** now lists tool windows correctly, and NARA lookups land on the NARA Lookup tab, not the source note. (Window routing itself shipped last build — documents still open where you're working; keep reporting misroutes.)

## Also
- **Zotero** — connect in Settings → Integrations, then Share a document (with tags and notes) to your library.
- **Source Explorer** — resolved collections show the **HMS/MLR Entry** number NARA staff ask for.

## Fixes
- Source Explorer no longer shows "No Document Selected" for the first document opened from a tool window.
- Deleted user tags no longer leave orphaned rows.
- The macOS Corpus Analytics window no longer truncates the term field on open.

## Feedback
Three things to stress: (1) the **project loop** — create a project, set focus subjects, work a while, then judge whether Project Leads earn their place; (2) **analytics compare + export** — save a figure and its CSV together and check the method block describes what you charted; (3) **⌘F** on long documents. Include your macOS version, the volume/document, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
