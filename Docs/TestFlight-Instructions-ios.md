# Testing FRUS Explorer 1.1 (iOS)

**Early build.** Version 1.1 (1862) is the first build of the update to 1.0 (1861), which is on the App Store. It brings the first part of the Collections overhaul; the rest comes in a later build.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**First launch re-indexes your library once,** whichever build you had: about 15 minutes for the whole series, less for a smaller library. You can keep reading while it runs.

## New since 1.0 (1861)

- **Collections:** a web page, a PDF and a Word file now print each document's parts in the same order. **Export…** opens from a collection's menu in the Collections list, and the export sheet starts on the format that collection last used and says what the export will print.
- **Save a working corpus from more places:** the cross-reference graph's **Save As** ▸ **Working Corpus…** (or **Archives Visit…**), and Chronology's **This Range** ▸ **Save as Working Corpus…**. Each says what it holds before it saves.
- **Central files after 1963:** footnotes that cite the Subject-Numeric File (1963–1973) or the Central Foreign Policy File are now read. Source Explorer lists them under **Unprinted Material**, and the cross-reference graph draws the Subject-Numeric File's classes.
- **Zotero:** a send that Zotero asks to wait now says so, and for how long.

**Fixed since 1.0 (1861):** many things, on every tab.

## What to test

1. **The re-index:** once it ends, are your notes, highlights, tags and collections all there? Does Search find what it found before?
2. **Shared code:** Related Documents, Meaning search, the semantic map, the word cloud and Archives Visits now run on code shared with FRUS Explorer Light, the web edition. Try Related's **Beyond your library**, **Search Within Results**, a slice of the **Semantic Map**, the word cloud's **Distinctive** and **Collocates**, and **Duplicate** an Archives Visit, then export its packet. Does each behave as in 1.0?
3. **Collections:** export one with a section and a document at summary depth as a web page, a PDF and Word. Do the three agree, with one copy of each source note? Does **Preview** keep your place when you change a setting?
4. **Saving:** in a document's **Graph** at **3 hops**, try **Save As** ▸ **Working Corpus…**, and in Chronology **This Range** ▸ **Save as Working Corpus…**. Does Browse ▸ **Working Corpora** hold what each question said?
5. **Links and order:** in *1961–1963, Volume VI*, do the Contents lines for the Preface and the lists open them? In *1969–1976, Volume E–9, Part 1*, does the *Note on U.S. Covert Actions* come before Document 1?
6. **Sources and citations:** does the 1909 volume's Document 429 read 1909 in Source Explorer and list the Numerical File's rolls? Does **Citation Lookup** find the 1898 volume's Document 1190b from its own citation?
7. **Search's dates:** in Chronology, pick a month and tap **Search in this range**. Do the date filter's pickers show its first and last days?
8. **Research notes:** turn off a document's **Research notes** in a collection, then export it as BibTeX or RIS, or send it to Zotero. Are the notes left out? Does **Duplicate** keep every setting?
9. **iPad:** with **Read** chosen in Settings ▸ Reading & Search ▸ Display, open a document's Research rail in Browse, narrow the window to one pane and widen it again. Is the rail still open? While the re-index runs, does the indexing banner stay at the bottom with no blank band above it? If not, take a screenshot and note the time.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
