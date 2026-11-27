# Testing FRUS Explorer 1.1 (iOS)

**Early build.** Version 1.1 (1862) is the first build of the update to 1.0 (1861), which is on the App Store. The Collections overhaul is not in it yet: it comes in a later build.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your iPhone and iPad: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**First launch re-indexes your library once,** whichever build you had: about 15 minutes for the whole series, less for a smaller library. You can keep reading while it runs.

## New since 1.0 (1861)

- **Central files after 1963:** footnotes that cite the Subject-Numeric File (1963–1973) or the Central Foreign Policy File are now read. Source Explorer lists them under **Unprinted Material**, and the cross-reference graph draws the Subject-Numeric File's classes.
- **Zotero:** a send that Zotero asks to wait now says so, and for how long.
- **Shared code:** Related Documents, search by **Meaning**, the semantic map, the word cloud and Archives Visits now run on code shared with FRUS Explorer Light, the web edition. Each should work as it did in 1.0.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume, with the size it takes on the device. A banner and a Live Activity count the queue as volumes download and index.
- **Browse** goes from subseries to volume, chapter and document. Select text to highlight it or add a note; the **Research rail** holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections.

**Fixed since 1.0 (1861):** many things, on every tab.

## What to test

1. **The re-index:** once it ends, are your notes, highlights, tags and collections all there? Does Search find what it found before?
2. **Shared code:** Related's **Beyond your library**, Project Home, a **Meaning** search and **Search Within Results**, the **Semantic Map** and a slice of it, the word cloud's **Distinctive** and **Collocates**, and an Archives Visit (**Duplicate** it, then export its packet). Does each behave as in 1.0?
3. **Order:** in Browse, open *1969–1976, Volume E–9, Part 1*. Does its *Note on U.S. Covert Actions* come before Document 1, as printed?
4. **Source Explorer:** in the 1909 volume, does Document 429 read 1909 and list the Numerical File's rolls?
5. **Citation Lookup:** copy the citation of Document 1190b in the 1898 volume and paste it in. Does it find that document?
6. **Search's dates:** in Chronology, pick a month and tap **Search in this range**. Do the date filter's pickers show its first and last days?
7. **Collections:** turn off a document's **Research notes**, then export its collection as BibTeX or RIS, or send it to Zotero. Are the notes left out? Does **Duplicate** keep every setting?
8. **iPad:** with **Read** chosen in Settings ▸ Reading & Search ▸ Display, open a document's Research rail in Browse, then narrow the window to one pane and widen it again. Is the rail still open?
9. **iPad, while the re-index runs:** with Browse in two panes and a document open, does the indexing banner stay at the bottom, with no blank band above it? If not, take a screenshot and note the time.

Report device, iOS version, taps, expected, actual and a document id. Thanks!
