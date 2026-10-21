# What's New Since Build 50 (iOS)

**Release candidate.** Version 1.0 (1861) is the build meant for the App Store; unless your reports stop it, this is 1.0.

**First launch re-indexes your library once** (index version 71) and rebuilds People, in the background. The earlier search model and its match files are removed; Related Documents and Meaning fetch new ones.

## Search

- **Search within these results.** After a Meaning question, **•••** ▸ **Find Words in These Matches**; after a keyword search, **•••** ▸ **Rank These Results by a Question** or **Sort** ▸ **Closest to a Question…**. A row names the held list; **Swap** swaps the two orders, **✕** puts it back.
- **Meaning search runs EmbeddingGemma 2**, open source; if you had the earlier model, **Download Search Model** (310 MB) is offered again, nothing to accept.
- A common word in a working corpus searches much faster.
- A keyword snippet starts at your word, after the heading, source note and dateline.
- A chapter's row shows the days of its documents.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): **Update** shows each volume's row as *Queued*, *Downloading…*, *Indexing…*, *Updated*, retries a failed update twice, then says why and offers **Retry**; **Check for Corrections** says why when it cannot read the list; a side-loaded copy is marked.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**.
- **Browse** opens chapters whose only own text is a heading's footnote, the Notes on U.S. Covert Actions, the Presidents' annual messages and other prose the index left out; a List of Sources keys files with no subject number.
- **Cross-references:** a page of another volume (*Foreign Relations, 1942, vol. I, p. 841*) cites the document on that page, in the citing list, the graph and Cross-Reference Analytics, whether or not you hold that volume.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen and some eighty more once filed under namesakes have their own entries; a sheet links to VIAF only where the Office of the Historian does, never to Wikidata.

## Collections

- A **smart collection** (linked to a saved search) takes nothing by hand: **Add to Collection**, its editor and the Collections lists say *Smart collection*; earlier entries are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Accessibility:** VoiceOver offers a result's tags as **Filter by** actions; at the largest text sizes the Meaning strip is one line, **ⓘ** opens all of it.
- **Word cloud:** an export counted as printed says another device may count differently.
- **Live Activity:** one lasts a whole indexing queue, background included.
- **Archival Analytics:** Subject-Numeric files read in words, across both handbooks and past 1973.
- **Archives Visit:** a file with no subject number is one target, keeping your tier and note.
- **Email Feedback File** (Settings ▸ System ▸ Data & Recovery) writes a message of your Semantic Match verdicts to feedback@frusexplorer.app.

**Fixes:** many, on every tab and in accessibility.

## What to test

1. **First launch.** Does the re-index finish and People open whole? Kirkpatrick, Khomeini, Allen: one entry each?
2. **Search within these results**, both ways, then **Swap** and **✕**: do the row and header say so?
3. **Meaning.** Download the model: nothing to accept? Percentages as before?
4. **A common word** (*government*) in a working corpus: how long?
5. **Keeping Current.** **Check for Corrections**, then **Update**: each step shown? Offline, does it say why?
6. **Reading Width**, portrait and landscape.
7. **Smart collections.** Link one to a saved search: earlier entries apart? **Remove These Entries** asks first?
8. **Your build-50 reports**: fixed?

Not bugs: People counts, Meaning results and citing lists differing from build 50's.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
