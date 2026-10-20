# What's New Since Build 50 (Mac)

**Version 1.0 (1861) is the release candidate. The Search window searches inside its own results. Meaning search runs EmbeddingGemma 2. Keeping Current shows each update.**

**First launch rebuilds People once**, in the background. It also removes the earlier search model and its match files; Related Documents and Meaning fetch the new ones as you use them. No volume is re-indexed or re-downloaded.

## Search

- **Search Within Results**, in the Search window's titlebar after **Save as Working Corpus…**: over a Meaning list it finds words in those matches; over a keyword list it ranks the results by a question, and a list cut at 7,500 is ranked whole. A row under the query field names the held list, and its **✕** puts the list back.
- Once you have searched inside the list, the row's **Swap** turns one order into the other without retyping.
- **Meaning search runs EmbeddingGemma 2**, open source. If you had the earlier model, **Download Search Model** (310 MB) is offered again, once, with no agreement to accept. Its percentages read as the earlier model's did.
- A common word searched inside a working corpus is much faster (it took seven seconds or more).
- The Corpus Browser lists a Meaning search's corpus as its closest matches.

## Library and reading

- **Keeping Current** (Settings ▸ Volumes & Storage): a volume keeps its row through **Update** or **Update All** and reads *Queued*, *Downloading…*, *Indexing…*, *Updated*. A failed update is tried twice more, then says why and offers **Retry**. When **Check for Corrections** cannot read the published list, it says why. A copy you side-load from now on says so in its row, since **Update** replaces it.
- **Reading Width** (Settings ▸ Reading & Search ▸ Display): **Narrow**, **Standard** or **Wide**. Standard is wider than the old column; a wide window adds margin, not line length.
- **People:** Jeane Kirkpatrick, Ahmad Khomeini, Richard V. Allen, Romulo Betancourt and some eighty more people once filed under namesakes have their own entries. A person's sheet shows no Wikidata link, and **View on VIAF** only where the Office of the Historian's own register names one.

## Collections

- A **smart collection** (one linked to a saved search) takes nothing by hand: the Collections window dims its **＋ Add** items, and the collection picker, **Manage Collections…** and Project Home say *Smart collection*.
- Entries it held before the link are listed apart, dimmed, with **Remove These Entries**.

## Also

- **Semantic Match Feedback** (Settings ▸ System ▸ Data & Recovery): **Email Feedback File** opens a message in your mail app to feedback@frusexplorer.app with your verdicts attached.

**Fixes:** many, in every window and in accessibility.

## What to test

1. **First launch.** Does People open whole? Search it for Kirkpatrick, Khomeini and Allen: one entry for each person?
2. **Search Within Results**, over a Meaning list and over a keyword list, then **Swap** and **✕**. Do the row and the count line say what you see?
3. **Meaning.** Download the model: no agreement to accept? Ask a question: do the percentages read as before?
4. **A common word** (*government*) in a working corpus (**Advanced…**): how long does it take?
5. **Keeping Current.** **Check for Corrections**, then **Update**: does the row show each step, beside the volume's title?
6. **Reading Width.** Each width, in a narrow window and a wide one.
7. **Smart collections.** Link a collection to a saved search: are earlier entries listed apart? Does **Remove These Entries** ask first?
8. **Your build-50 reports**, the semantic map after its window is closed and reopened, and the Corpus Browser under a project's research question: fixed?

Not bugs: People counts that differ from build 50's; Meaning results that differ from build 50's; no Wikidata link on a person's sheet.

Include macOS version, window, clicks, expected, actual — and for anything archival, the document id. Thanks!
