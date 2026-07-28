# What's New in Build 36 (Mac)

Settings rebuilt, a new first run, and search that is dramatically faster on common words — the Mac window had the worst of that problem by a wide margin. No re-index needed.

**Read first:** *Log Research Sessions* now governs **everything** the app remembers about your work, not just the session log. Turn it off and the History window will thin out and empty — by design. And the old text in that pane said your Mac searches were not recorded. **That was wrong**; the History window has been recording them all along. The pane now says so.

## Search is much faster on common words
This is the headline, and the numbers were not close. Searching *government*, *soviet* or *policy* left the app unresponsive for a long time **after** the results were already found, while it built a preview for every row. The Search window fetches 7,500 rows to the phone's 1,000, so it carried 7.5× the work: measured against a real 316,000-document library, the worst case was **41 seconds**. It is now a small fraction of that.

That worst case was not exotic: it fired whenever your search matched in a heading, dateline, source note, note or summary rather than the document body.

**Caveat:** the database query itself is unchanged. A genuinely common word still takes several seconds to look up. What is gone is the second, much larger wait that came after.

## Settings, rebuilt
Seventeen destinations became thirteen rows in four groups — Library, Research, Reading & Search, System — identical on Mac and iPhone. Every pane is a native grouped form. **Volumes & Storage** is one destination for downloads, storage, index health and sideload; **Free Up Space** replaces Manage Storage. **Connections** holds your NARA key and Zotero. **Data & Recovery** offers a three-rung ladder that says what each rung costs. **Research Sessions** is a new pane.

## A new first run
Delete and reinstall to see it: three steps docked in glass over a drifting word cloud, working before you have downloaded anything.

## A word cloud while you wait
Run the **first** search in a window — when the results list would otherwise be empty — and a drifting field of words fills the space after a moment, with the spinner fading out behind it. Search again with results already on screen and nothing changes: your previous results stay put.

The words are the general vocabulary of whatever you scoped to. **They are not your search results**, which do not exist yet while you wait. Reduce Motion stops the drift; the cloud still changes lens.

## Also, if you skipped build 35
Find in Document (⌘F; Search moved to ⌘S). Project Home and Project Leads, with History / Focus project scopes in the Search filters. Corpus Analytics: compare five terms, save queries, export CSV / PNG / PDF.

## Fixes
- Onboarding words sat underneath the panel at large accessibility text sizes.
- Free Up Space removed volumes with no confirmation at all; it asks now.
- Source Explorer no longer shows "No Document Selected" for the first document opened from a tool window.
- The Corpus Analytics window no longer truncates the term field on open.
- Deleted user tags no longer leave orphaned rows.

## What to test
1. **Search a common word from a fresh window** — this is the change most likely to be obvious, and the one I most want confirmed on a real library rather than a benchmark. Then search something rare.
2. Delete and reinstall. Does the first run make sense before any download?
3. The waiting cloud must **never** paint over results you are already reading. If you see it behind a populated list, that is a bug.
4. Go looking for a setting you changed before — did the new place surprise you?

Include macOS version, the window, what you clicked, what you expected, what happened. Thanks for testing!
