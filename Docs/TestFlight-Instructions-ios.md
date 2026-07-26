# What's New in Build 36 (iOS)

Build 36 is a **Settings release**. The whole of Settings has been rebuilt around one shared structure, and two ways to lose data without being asked are closed. Everything from build 35 — Research Projects, Corpus Analytics compare/export, and iPad multi-window — is unchanged and still worth your attention. No re-index needed.

## Settings, rebuilt

Settings has been rebuilt end to end. **Seventeen destinations became thirteen rows in four groups** — Library, Research, Reading & Search, System — and both platforms now render the same tree from the same source, so a setting is in the same place on your iPhone as on your Mac.

- **Volumes & Storage** — Downloads, Storage, Index Health and Sideload are one destination. Everything about the corpus on your device is behind one row: what you have, what to add, what it costs, and the index. **Free Up Space** is new on iOS.
- **Connections** — the NARA Catalog key and Zotero, each a card showing whether it is connected before you open it.
- **Data & Recovery** — export, the Broken Cross-References report, the sync log, and a recovery ladder whose three rungs say what each one costs: **Fix iCloud Sync** (nothing is deleted) · **Reset This Device** (volumes and index only) · **Erase Everything…** (its own screen, two confirmations).
- **Notes** is now on iPhone and iPad — a flat list of your notes with per-note delete, which iOS never had.
- **Research Sessions** is new: what the app records about your reading, a switch to stop it, and a way to delete it.
- **Search Settings** at the top of the list finds panes by what they do — "stop words" finds Word Cloud, "api key" finds Connections.
- The **FRUS Research Guide** moved out of the settings list into **About → Resources**.

## Research Projects, grown up
- **Project Home** — open your project from the Research tab for a dashboard of its activity: recent documents, notes, collections, and **Project Leads**.
- **Project Leads** — ranked suggestions for what to read next, aggregated from everything the project has touched, with **tunable weights** and per-lead "why" evidence. Dismiss a lead and the next candidate backfills.
- **Search inside your project** — the Search filter panel gains a project scope: **History** (only documents you've collected, annotated, or visited in this project) or **Focus** (volumes your project's subjects point to, with an "only new" toggle).
- Exports now carry your **project name and research question** on the title page.
- Create projects in **Settings → Projects** (a New Project button now lives there); the Browse toolbar's project menu switches between them and shows what you're **working on**.

## Corpus Analytics: compare, save, export
- **Compare up to 5 terms** as chips on one chart; **% of documents** normalization keeps eras comparable.
- **Save a query** (bookmark button) and rerun it later; recent queries are kept automatically.
- **Export** any chart as **CSV, PNG, or PDF** via the share sheet — the CSV opens with a `#`-commented method block (scope, year range, caveats). Figures are offered on time axes; By Subseries / By Volume are CSV-only by design. Word clouds export too, now with a ranked CSV that records your filters and hidden words.
- The volume **heat matrix** is rebuilt: bigger cells, readable column codes. **ⓘ buttons** on every analytics view explain what you're seeing.

## iPad: multiple windows, for real
Multi-window was broken at the OS-registration level; it's fixed. **Drag a document out** into its own window, and tools (Search, Analytics, Word Cloud, Chronology, the graph) now open their results **in the window you're working in**, not a random one. Stage Manager users: please stress this hard.

## Also
- **Zotero** — connect in Settings → Connections; the rail's Share menu sends a document with your tags and notes.
- **Source Explorer** — resolved collections show the **HMS/MLR Entry** number NARA staff ask for.


## Fixes
- **Two ways to lose work without being asked, closed.** On Mac, Free Up Space removed volumes with no confirmation at all. On iPhone and iPad, a full swipe deleted a Volume Scope outright. Both now ask first.
- iPhone: the Research rail no longer auto-opens on every document — it appears when you ask for it.
- Source Explorer no longer shows "No Document Selected" for the first document you open.
- Deleted user tags no longer leave orphaned rows.
- iPad: analytics term chips lay out correctly below the term field.

## Feedback

Three things to stress. **(1) Find your settings.** Go looking for something you changed before — a stop word, your NARA key, the reset options — and tell me if the new place surprised you or if you had to hunt. **(2) The two destructive paths.** Free Up Space and the Volume Scopes swipe both ask before deleting now; try to find a way to lose something without being asked. **(3) Anything that reads wrong.** Several settings sentences turned out to describe controls that no longer existed; if a footer promises something the screen does not do, that is exactly the bug I want. Include device + OS version, the pane, what you tapped, what you expected, what happened. Thanks for testing!
