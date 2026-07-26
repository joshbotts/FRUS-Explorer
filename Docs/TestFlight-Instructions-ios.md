# What's New in Build 36 (iOS)

Build 36 is a **Settings release**, and it also fixes the **Corpus Analytics freeze** some of you hit on iPhone. The whole of Settings has been rebuilt around one shared structure, and two ways to lose data without being asked are closed. Everything from build 35 — Research Projects, Corpus Analytics compare/export, and iPad multi-window — is unchanged and still worth your attention. No re-index needed.

> **One behaviour change to know about before you turn anything off:** the **Log Research Sessions** switch now governs *everything* the app remembers about your work, not just the session log. Turn it off and History and a project's Recents will thin out and eventually empty. That is the switch finally doing what its description says — not a fault. See *The recording switch* below.

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


## The recording switch now means what it says

**Log Research Sessions** used to stop only the session log — the one thing in the app nothing else read. Your reading history kept recording regardless, and it is what fills History, a project's Recents, the search History and Focus scopes, and the last-opened dates in Volumes & Storage. Turning the switch off did not stop the app remembering what you read.

It does now. One switch, every recorder.

- **If you rely on Recents or History, leave it on.** With it off, those surfaces will empty over time — by design.
- **Already-recorded activity stays** until you delete it — and now you can. The delete button in Settings → Research → Research Sessions clears the *whole* trail, and the new History screen lets you swipe away individual entries.
- **A correction for Mac users:** the old text in that pane said searches were recorded on iPhone and iPad "but not here". That was true of the session log and **wrong about the History window**, which has been recording your Mac search text all along. The pane now says so plainly.

## Fixes
- **Corpus Analytics froze the app when you rotated the iPhone.** Enter a term, tap the term field again, turn the phone sideways, and the app would hang and be killed. **Person Analytics had the same defect** and nobody had noticed — its two person-search fields did it too, just without the hang. Both fixed. If you were avoiding rotating that screen, please stop avoiding it.
- **The "Working on:" project banner covered the navigation bar.** On iPhone it sat on top of the back button, the title, and the toolbar buttons at every level of Browse. It now sits below the bar.
- **Browse rows only responded to taps on the text.** Tapping the empty space to the right of a subseries or volume name did nothing. The whole row is tappable now.
- **"Index Required" on a volume that was fully indexed** — with an "Index Now" button that did nothing at all when tapped. Fixed. And if the search index genuinely cannot be built, you now get a warning and an explanation instead of a dead blue button.
- **Two ways to lose work without being asked, closed.** On Mac, Free Up Space removed volumes with no confirmation at all. On iPhone and iPad, a full swipe deleted a Volume Scope outright. Both now ask first.
- iPhone: the Research rail no longer auto-opens on every document — it appears when you ask for it.
- Source Explorer no longer shows "No Document Selected" for the first document you open.
- Deleted user tags no longer leave orphaned rows.
- iPad: analytics term chips lay out correctly below the term field.

## Feedback

Three things to stress. **(1) Find your settings.** Go looking for something you changed before — a stop word, your NARA key, the reset options — and tell me if the new place surprised you or if you had to hunt. **(2) The two destructive paths.** Free Up Space and the Volume Scopes swipe both ask before deleting now; try to find a way to lose something without being asked. **(3) Anything that reads wrong.** Several settings sentences turned out to describe controls that no longer existed; if a footer promises something the screen does not do, that is exactly the bug I want. Include device + OS version, the pane, what you tapped, what you expected, what happened. Thanks for testing!
