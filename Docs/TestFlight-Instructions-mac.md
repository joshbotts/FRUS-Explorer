# What's New Since Build 50 (Mac)

**Version 1.0 (1861) is the release candidate. The Search window searches inside its results. Meaning search runs EmbeddingGemma 2. Keeping Current shows each update.**

**First launch rebuilds People once**, in the background. It also removes the earlier search model and its match files; Related Documents and Meaning fetch new ones. No volume is re-indexed or re-downloaded.

## Search

- **Search Within Results**, in the Search window's titlebar after **Save as Working Corpus…**: over a Meaning list it finds words in those matches; over a keyword list it ranks the results by a question, and a list cut at 7,500 is ranked whole. A row under the query field names the held list; **✕** puts it back, and after a search inside it **Swap** swaps the two orders.
- **Meaning search runs EmbeddingGemma 2**, open source. If you had the earlier model, **Download Search Model** (310 MB) is offered once more, with nothing to accept.
- A common word in a working corpus searches much faster.
- A keyword snippet starts at your word, after the heading, source note and dateline.
- The Corpus Browser lists a Meaning search's corpus as its closest matches.
- **Add to Collection…** and **Add Tags…**, dimmed over 1,000, say why.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): with **Update** or **Update All** a volume's row reads *Queued*, *Downloading…*, *Indexing…*, *Updated*. A failed update is tried twice more, then says why and offers **Retry**. **Check for Corrections** says why when it cannot read the list. A side-loaded copy is now marked, since **Update** replaces it.
- **Index Remaining** finishes partly indexed volumes.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**; Standard is wider than before, and a wide window adds margin, not line length.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen and some eighty more once filed under namesakes have their own entries; a sheet links to VIAF only where the Office of the Historian names one, not to Wikidata.

## Collections

- **⚙ Collection** ▸ **Link to Saved Search…** links any collection.
- A **smart collection** (linked to a saved search) takes nothing by hand: the Collections window dims its **＋ Add** items, and the collection picker, **Manage Collections…** and Project Home say *Smart collection*.
- Entries held before the link are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Archives Visit:** a file cited with no subject number is one target, keeping your tier and note.
- **Archival Analytics:** Subject-Numeric files read in words across the 1963 and 1965 handbooks and past 1973.
- **Semantic Match Feedback** (Settings ▸ System ▸ Data & Recovery): **Email Feedback File** opens a message of your verdicts to feedback@frusexplorer.app.

**Fixes:** many, in every window and in accessibility.

## What to test

1. **First launch.** Does People open whole? Search for Kirkpatrick, Khomeini and Allen: one entry each?
2. **Search Within Results**, over a Meaning list and a keyword list, then **Swap** and **✕**. Do the row and count line say what you see?
3. **Meaning.** Download the model: no agreement to accept? Ask a question: do percentages read as before?
4. **A common word** (*government*) in a working corpus (**Advanced…**): how long?
5. **Keeping Current.** **Check for Corrections**, then **Update**: does the row show each step by the volume's title?
6. **Reading Width.** Each width, in a narrow and a wide window.
7. **Smart collections.** Link one to a saved search: are earlier entries listed apart? Does **Remove These Entries** ask first?
8. **Your build-50 reports**, the semantic map after its window is reopened, and the Corpus Browser under a project's research question: fixed?

**Your library re-indexes once** at this build's first launch (index version 70): a chapter whose only text of its own is a footnote on its heading has a row, as do the Notes on U.S. Covert Actions, the Presidents' annual messages and the other prose the index left out; a chapter's row shows the days of its documents in Search; and a volume's List of Sources keys files with no subject number.

Not bugs: People counts and Meaning results differing from build 50's.

Include macOS version, window, clicks, expected, actual, and a document's id. Thanks!
