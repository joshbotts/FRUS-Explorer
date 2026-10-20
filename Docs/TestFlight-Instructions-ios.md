# What's New Since Build 50 (iOS)

**Version 1.0 (1861) is the release candidate. Search runs inside a list of results. Meaning search runs EmbeddingGemma 2. Keeping Current shows each update.**

**First launch rebuilds People once**, in the background. It also removes the earlier search model and its match files; Related Documents and Meaning fetch the new ones as you use them. No volume is re-indexed or re-downloaded.

## Search

- **Search within these results.** After a Meaning question, **•••** ▸ **Find Words in These Matches**. After a keyword search, **•••** ▸ **Rank These Results by a Question**, or **Sort** ▸ **Closest to a Question…**; a list cut at 1,000 is ranked whole. A row names the held list, and its **✕** puts the list back.
- After a search inside the list, the row's **Swap** turns one order into the other without retyping.
- **Meaning search runs EmbeddingGemma 2**, open source. If you had the earlier model, **Download Search Model** (310 MB) is offered again, once, with no agreement to accept. Its percentages read as the earlier model's did.
- A common word searched inside a working corpus is much faster (it took seven seconds or more).
- Browse lists a Meaning search's corpus as its closest matches.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): a volume keeps its row through **Update** or **Update All** and reads *Queued*, *Downloading…*, *Indexing…*, *Updated*. A failed update is tried twice more, then says why and offers **Retry**. When **Check for Corrections** cannot read the published list, it says why. A copy you side-load from now on says so in its row, since **Update** replaces it.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**. On iPad, Standard is wider than the old column.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen, Romulo Betancourt and some eighty more people once filed under namesakes have their own entries. A person's sheet shows no Wikidata link, and **View on VIAF** only where the Office of the Historian's own register names one.

## Collections

- A **smart collection** (one linked to a saved search) takes nothing by hand: **Add to Collection**, its editor, both Collections lists and Project Home say *Smart collection*.
- Entries it held before the link are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Accessibility:** with VoiceOver, a search result's tags are **Filter by** actions. At the five largest text sizes, Meaning mode's strip is one line; its **ⓘ** opens all of it.
- **Word cloud:** an exported cloud counted as printed says another device may count differently.
- **Semantic Match Feedback** (Settings ▸ System ▸ Data & Recovery): **Email Feedback File** opens a message to feedback@frusexplorer.app with your verdicts attached.

**Fixes:** many, on every tab and in accessibility.

## What to test

1. **First launch.** Does People open whole? Search it for Kirkpatrick, Khomeini and Allen: one entry for each person?
2. **Search within these results**, both ways, then **Swap** and **✕**. Do the row and the header say what you see? At a large text size?
3. **Meaning.** Download the model: no agreement to accept? Ask a question: do the percentages read as before?
4. **A common word** (*government*) in a working corpus (Filters): how long does it take?
5. **Keeping Current.** **Check for Corrections**, then **Update**: does the row show each step? Open the app in Airplane Mode and check: does it say why it cannot?
6. **Reading Width.** Each width, portrait and landscape.
7. **Smart collections.** Link a collection to a saved search: are earlier entries listed apart? Does **Remove These Entries** ask first?
8. **Your build-50 reports**: fixed?

Not bugs: People counts and Meaning results that differ from build 50's; no Wikidata link on a person's sheet.

Include device + iOS version, taps, expected, actual — and for anything archival, the document id. Thanks!
