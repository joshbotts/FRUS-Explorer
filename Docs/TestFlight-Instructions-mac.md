# What's New Since Build 50 (Mac)

**Release candidate.** Version 1.0 (1861) is the build meant for the App Store; unless your reports stop it, this is 1.0.

**First launch re-indexes your library once** (index version 71) and rebuilds People, in the background. The earlier search model and its match files are removed; Related Documents and Meaning fetch new ones.

## Search

- **Search Within Results**, in the Search window's titlebar after **Save as Working Corpus…**: over a Meaning list it finds words in those matches; over a keyword list it ranks the results by a question. A row names the held list; **✕** puts it back, and after a search inside it **Swap** swaps the two orders.
- **Meaning search runs EmbeddingGemma 2**, open source; if you had the earlier model, **Download Search Model** (310 MB) is offered again, nothing to accept.
- A common word in a working corpus searches much faster.
- A keyword snippet starts at your word, after the heading, source note and dateline.
- A chapter's row shows the days of its documents.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): **Update** shows each volume's row as *Queued*, *Downloading…*, *Indexing…*, *Updated*, retries a failed update twice, then says why and offers **Retry**; **Check for Corrections** says why when it cannot read the list; a side-loaded copy is marked.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**; Standard is wider; a wide window adds margin, not line length.
- **The Corpus Browser** opens chapters whose only own text is a heading's footnote, the Notes on U.S. Covert Actions, the Presidents' annual messages and other prose the index left out; a List of Sources keys files with no subject number.
- **Cross-references:** a page of another volume (*Foreign Relations, 1942, vol. I, p. 841*) cites the document on that page, in the citing list, the graph and Cross-Reference Analytics, whether or not you hold that volume.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen and some eighty more once filed under namesakes have their own entries; a sheet links to VIAF only where the Office of the Historian does, never to Wikidata.

## Collections

- **⚙ Collection** ▸ **Link to Saved Search…** links any collection.
- A **smart collection** (linked to a saved search) takes nothing by hand: the Collections window dims **＋ Add**, and the picker and **Manage Collections…** say *Smart collection*; earlier entries are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Archival Analytics:** Subject-Numeric files read in words, across both handbooks and past 1973.
- **Archives Visit:** a file with no subject number is one target, keeping your tier and note.
- **Email Feedback File** (Settings ▸ System ▸ Data & Recovery) writes a message of your Semantic Match verdicts to feedback@frusexplorer.app.

**Fixes:** many, in every window and in accessibility.

## What to test

1. **First launch.** Does the re-index finish and People open whole? Kirkpatrick, Khomeini, Allen: one entry each?
2. **Search Within Results**, over a Meaning list and a keyword list, then **Swap** and **✕**: do the row and count line say so?
3. **Meaning.** Download the model: nothing to accept? Percentages as before?
4. **A common word** (*government*) in a working corpus (**Advanced…**): how long?
5. **Keeping Current.** **Check for Corrections**, then **Update**: each step shown, by the volume's title?
6. **Reading Width**, in a narrow and a wide window.
7. **Smart collections.** Link one to a saved search: earlier entries apart? **Remove These Entries** asks first?
8. **Your build-50 reports** (the semantic map reopened, the Corpus Browser under a research question): fixed?

Not bugs: People counts, Meaning results and citing lists differing from build 50's.

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
