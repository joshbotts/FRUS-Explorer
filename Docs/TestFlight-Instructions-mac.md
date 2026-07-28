# What's New in Build 36 (Mac)

Build 36 rebuilds **Settings**, gives the app a **new first run**, and makes **search dramatically faster** on common words — the Mac window had the worst of that problem by a wide margin. Everything from build 35 — Research Projects, Corpus Analytics compare/export, and find-in-document — is unchanged and still worth your attention. No re-index needed.

> **Two things to read before you change any setting:** the **Log Research Sessions** switch now governs *everything* the app remembers about your work — turn it off and the History window will thin out and eventually empty, by design. And the old description in that pane told you your Mac searches were not being recorded. **That was wrong.** Both are covered in *The recording switch* below.

## Settings, rebuilt

Settings has been rebuilt end to end. **Seventeen destinations became thirteen rows in four groups** — Library, Research, Reading & Search, System — and both platforms now render the same tree from the same source, so a setting is in the same place on your Mac as on your iPhone. Every pane is a native grouped form; sub-screens open as sheets with a Done button.

- **Volumes & Storage** — Downloads, Storage, Index Health and Sideload are one destination. Everything about the corpus on your device is behind one row: what you have, what to add, what it costs, and the index. **Free Up Space** replaces the old Manage Storage sheet.
- **Connections** — the NARA Catalog key and Zotero, each a card showing whether it is connected before you open it.
- **Data & Recovery** — export, the Broken Cross-References report, the sync log, and a recovery ladder whose three rungs say what each one costs: **Fix iCloud Sync** (nothing is deleted) · **Reset This Device** (volumes and index only) · **Erase Everything…** (its own screen, two confirmations).
- **Research Sessions** is new: what the app records about your reading, a switch to stop it, and a way to delete it.
- The **FRUS Research Guide** moved out of the settings list into **About → Resources**.

## A new first run

Install fresh (or delete and reinstall) and you get a different app: **three steps docked in glass** — welcome, choose what to download, ready — over a drifting field of the corpus's own vocabulary. The cloud is there from the very first launch, before you have downloaded anything; the words are built into the app. On a fresh install, or while iCloud is restoring your library onto a new Mac, you get a **brief splash** rather than an empty window with no explanation.

## Search is much faster on common words

This is the headline for Mac, and the numbers were not close.

Searching a word that appears in most documents — *government*, *soviet*, *policy* — left the app unresponsive for a long time **after** the results had already been found, while it built the preview snippets for every row. The Search window fetches 7,500 rows to the phone's 1,000, so it got 7.5× the work. Measured against a real 316,000-document library, the worst case was **41 seconds** of pure snippet-building. It is now a small fraction of that.

That worst case was not exotic, either: it fires whenever your search matched in a heading, dateline, source note, note or summary rather than in the document body.

**Honest caveat:** the database query itself is untouched, and a genuinely common word still takes several seconds to look up before any of this happens. What is gone is the second, much larger wait that came after.

## A word cloud while you wait

When you run the **first** search in a Search window — when the results list would otherwise be empty — a drifting field of words fills the space after a moment, and the spinner fades out behind it. Search again with results already on screen and nothing changes: your previous results stay put, exactly as before.

The words are the *general* vocabulary of whatever you scoped to — the corpus, or the volumes you filtered to. **They are not your search results**, which do not exist yet while you are waiting.

**Reduce Motion** (System Settings → Accessibility → Display) stops the drift completely; the cloud still changes lens every few seconds, it just stops moving.

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
- **Onboarding words sat underneath the panel at large text sizes.** Only visible if you use a large accessibility text size, which is exactly why it survived this long.
- **Two ways to lose work without being asked, closed.** On Mac, Free Up Space removed volumes with no confirmation at all. On iPhone and iPad, a full swipe deleted a Volume Scope outright. Both now ask first.
- Source Explorer no longer shows "No Document Selected" for the first document opened from a tool window.
- Deleted user tags no longer leave orphaned rows.
- The macOS Corpus Analytics window no longer truncates the term field on open.

## Feedback

Four things to stress this time.

**(1) Search a common word from a fresh window.** *government*, *policy*, *soviet*. This is the change most likely to be obvious, and the one I most want confirmed on a real library rather than a benchmark. Then search something rare and confirm it is still instant.

**(2) The first run.** Delete the app and reinstall it. Does the opening sequence make sense before you have downloaded anything? Anything that flashes, jumps, or sits blank?

**(3) The waiting cloud, and what it must not do.** It should fill an empty results area on a first search — and it must **never** paint over results you are already reading. If you ever see it behind a populated list, that is a bug and I want it.

**(4) Find your settings.** Go looking for something you changed before — a stop word, your NARA key, the reset options — and tell me if the new place surprised you or if you had to hunt.

Include macOS version, the window, what you clicked, what you expected, what happened. Thanks for testing!
