# What's New in Build 36 (iOS)

Settings rebuilt, a new first run, a moving word cloud behind the waits, and search that is much faster on common words. Also fixes the Corpus Analytics rotation freeze. No re-index needed.

**Read first:** *Log Research Sessions* now governs **everything** the app remembers about your work, not just the session log. Turn it off and History and a project's Recents will thin out and empty. That is the switch finally doing what its description says — not a fault.

## Settings, rebuilt
Seventeen destinations became thirteen rows in four groups — Library, Research, Reading & Search, System — identical on iPhone and Mac. **Volumes & Storage** is one destination for downloads, storage, index health and sideload; **Free Up Space** is new on iOS. **Connections** holds your NARA key and Zotero. **Data & Recovery** offers a three-rung ladder that says what each rung costs. **Notes** and **Research Sessions** are new panes. Search at the top of Settings finds panes by what they do — "stop words" finds Word Cloud.

## A new first run
Delete and reinstall to see it: three steps docked in glass over a drifting word cloud, working before you have downloaded anything. No white flash at launch.

## The word cloud moves
Words drift as if suspended at different distances. You will see it while volumes index, and while a search runs — but only when there is nothing else to read there, and only if the wait is long enough to be worth filling. The words are the general vocabulary of whatever you scoped to. **They are not your search results**, which do not exist yet while you wait. Reduce Motion stops the drift; the cloud still changes lens.

## Indexing reports the queue, not each volume
The banner used to flash in and out once per volume. It now appears once and stays until everything is ready — "Volume 3 of 27", then "27 volumes ready to search". *Learn about FRUS while you wait* is reachable throughout.

## Search is much faster on common words
Searching *government*, *soviet* or *policy* left the app unresponsive for seconds **after** the results were already found, while it built previews. That is now a fraction of a second.

**Caveat:** the database query itself is unchanged — a genuinely common word still takes a few seconds to look up. What is gone is the second, avoidable wait that came after.

## Fixes
- Backgrounding mid-download stopped indexing; the queue now continues.
- The multi-volume indexing banner never appeared when downloads outpaced indexing — the normal case.
- Onboarding words sat underneath the panel at large accessibility text sizes.
- Corpus Analytics froze the app on iPhone rotation; Person Analytics had the same defect.
- The "Working on:" banner covered the navigation bar at every level of Browse.
- Browse rows only responded to taps on the text, not the whole row.
- "Index Required" on a fully indexed volume, with an Index Now button that did nothing.
- Two ways to lose work without being asked: Free Up Space (Mac) and Volume Scope swipe-delete (iOS) both ask now.
- The Research rail no longer auto-opens on every document.
- Source Explorer no longer shows "No Document Selected" for the first document opened.

## What to test
1. Delete and reinstall. Does the first run make sense before you have downloaded anything?
2. Download a subseries and watch the banner start to finish — it should appear once and stay.
3. Search a common word, then a rare one.
4. The cloud: too busy, too slow, too distracting while you read progress? It is tunable.
5. Reduce Motion, if you use it — the drift should stop completely.

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
