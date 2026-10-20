# What's New Since Build 50 (iOS)

**Version 1.0 (1861) is the release candidate. Search runs inside a list of results. Meaning search runs EmbeddingGemma 2. Keeping Current shows each update.**

**First launch rebuilds People once**, in the background. It also removes the earlier search model and its match files; Related Documents and Meaning fetch new ones. No volume is re-indexed or re-downloaded.

## Search

- **Search within these results.** After a Meaning question, **•••** ▸ **Find Words in These Matches**. After a keyword search, **•••** ▸ **Rank These Results by a Question**, or **Sort** ▸ **Closest to a Question…**; a list cut at 1,000 is ranked whole. A row names the held list; **Swap** swaps the two orders, **✕** puts it back.
- **Meaning search runs EmbeddingGemma 2**, open source. If you had the earlier model, **Download Search Model** (310 MB) is offered once more, with nothing to accept.
- A common word in a working corpus searches much faster.
- A keyword snippet starts at your word, after the heading, source note and dateline.
- Browse lists a Meaning search's corpus as its closest matches.
- **Add to Collection** and **Add Tags**, dimmed over 1,000, say why.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): with **Update** or **Update All** a volume's row reads *Queued*, *Downloading…*, *Indexing…*, *Updated*. A failed update is tried twice more, then says why and offers **Retry**. **Check for Corrections** says why when it cannot read the list. A side-loaded copy is now marked, since **Update** replaces it.
- **Index Remaining** finishes partly indexed volumes.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**; on iPad, Standard is wider than before.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen and some eighty more once filed under namesakes have their own entries; a sheet links to VIAF only where the Office of the Historian names one, not to Wikidata.

## Collections

- A **smart collection** (linked to a saved search) takes nothing by hand: **Add to Collection**, its editor, both Collections lists and Project Home say *Smart collection*.
- Entries held before the link are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Accessibility:** with VoiceOver, a search result's tags are **Filter by** actions. At the largest text sizes the Meaning strip is one line; **ⓘ** opens all of it.
- **Word cloud:** an export counted as printed says another device may count differently.
- **Live Activity:** one lasts a whole indexing queue, background included.
- **Archival Analytics:** Subject-Numeric files read in words across the 1963 and 1965 handbooks and past 1973.
- **Archives Visit:** a file cited with no subject number is one target, keeping your tier and note.
- **Semantic Match Feedback** (Settings ▸ System ▸ Data & Recovery): **Email Feedback File** opens a message of your verdicts to feedback@frusexplorer.app.

**Fixes:** many, on every tab and in accessibility.

## What to test

1. **First launch.** Does People open whole? Search for Kirkpatrick, Khomeini and Allen: one entry each?
2. **Search within these results**, both ways, then **Swap** and **✕**. Do the row and header say what you see? At a large text size?
3. **Meaning.** Download the model: no agreement to accept? Ask a question: do percentages read as before?
4. **A common word** (*government*) in a working corpus (Filters): how long?
5. **Keeping Current.** **Check for Corrections**, then **Update**: does the row show each step? In Airplane Mode, does it say why?
6. **Reading Width.** Each width, portrait and landscape.
7. **Smart collections.** Link one to a saved search: are earlier entries listed apart? Does **Remove These Entries** ask first?
8. **Your build-50 reports**: fixed?

Not bugs: People counts and Meaning results differing from build 50's.

Include device + iOS version, taps, expected, actual, and a document's id. Thanks!
