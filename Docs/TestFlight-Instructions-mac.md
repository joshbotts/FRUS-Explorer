# What's New in Build 36 (Mac)

Build 36 is a **Settings release**. The whole of Settings has been rebuilt around one shared structure, and two ways to lose data without being asked are closed. Everything from build 35 — Research Projects, Corpus Analytics compare/export, and find-in-document — is unchanged and still worth your attention. No re-index needed.

> **Two things to read before you change any setting:** the **Log Research Sessions** switch now governs *everything* the app remembers about your work — turn it off and the History window will thin out and eventually empty, by design. And the old description in that pane told you your Mac searches were not being recorded. **That was wrong.** Both are covered in *The recording switch* below.

## Settings, rebuilt

Settings has been rebuilt end to end. **Seventeen destinations became thirteen rows in four groups** — Library, Research, Reading & Search, System — and both platforms now render the same tree from the same source, so a setting is in the same place on your Mac as on your iPhone. Every pane is a native grouped form; sub-screens open as sheets with a Done button.

- **Volumes & Storage** — Downloads, Storage, Index Health and Sideload are one destination. Everything about the corpus on your device is behind one row: what you have, what to add, what it costs, and the index. **Free Up Space** replaces the old Manage Storage sheet.
- **Connections** — the NARA Catalog key and Zotero, each a card showing whether it is connected before you open it.
- **Data & Recovery** — export, the Broken Cross-References report, the sync log, and a recovery ladder whose three rungs say what each one costs: **Fix iCloud Sync** (nothing is deleted) · **Reset This Device** (volumes and index only) · **Erase Everything…** (its own screen, two confirmations).
- **Research Sessions** is new: what the app records about your reading, a switch to stop it, and a way to delete it.
- The **FRUS Research Guide** moved out of the settings list into **About → Resources**.

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
- **Zotero** — connect in Settings → Connections, then Share a document (with tags and notes) to your library.
- **Source Explorer** — resolved collections show the **HMS/MLR Entry** number NARA staff ask for.


## The recording switch now means what it says

**Log Research Sessions** used to stop only the session log — the one thing in the app nothing else read. Your reading and search history kept recording regardless, and they are what fill the **History window**, a project's Recents, the search History and Focus scopes, and the last-opened dates in Volumes & Storage. Turning the switch off did not stop the app remembering what you read.

It does now. One switch, every recorder.

- **The old description was wrong, and this is the important part.** It said searches were recorded on iPhone and iPad "but not here". That was true of the *session log* and false of the History window, which has been recording your Mac search text — the actual query strings — all along, and syncing them to your private iCloud database. The pane now says so plainly. If that is not what you want, turn the switch off.
- **If you rely on the History window, leave it on.** With it off, History will empty over time — by design.
- **Already-recorded activity stays** until you delete it — and now you can. The delete button in Settings → Research → Research Sessions clears the *whole* trail, and the new History screen lets you swipe away individual entries.

## Fixes
- **Two ways to lose work without being asked, closed.** On Mac, Free Up Space removed volumes with no confirmation at all. On iPhone and iPad, a full swipe deleted a Volume Scope outright. Both now ask first.
- Source Explorer no longer shows "No Document Selected" for the first document opened from a tool window.
- Deleted user tags no longer leave orphaned rows.
- The macOS Corpus Analytics window no longer truncates the term field on open.

## Feedback

Three things to stress. **(1) Find your settings.** Go looking for something you changed before — a stop word, your NARA key, the reset options — and tell me if the new place surprised you or if you had to hunt. **(2) The two destructive paths.** Free Up Space asks before deleting now; try to find a way to lose something without being asked. **(3) Anything that reads wrong.** Several settings sentences turned out to describe controls that no longer existed; if a footer promises something the screen does not do, that is exactly the bug I want. Include device + OS version, the pane, what you tapped, what you expected, what happened. Thanks for testing!
