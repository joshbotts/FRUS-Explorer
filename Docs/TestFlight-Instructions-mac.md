# Testing FRUS Explorer 1.1 (Mac)

**Early build.** Version 1.1 (1862) is the first build of the update to 1.0 (1861), which is on the App Store. The Collections overhaul is not in it yet: it comes in a later build.

FRUS Explorer puts the State Department's *Foreign Relations of the United States* on your Mac: download volumes, then read, search, annotate, cite and chart their documents offline. Notes, highlights, tags and collections sync through iCloud.

**First launch re-indexes your library once,** whichever build you had: about 15 minutes for the whole series, less for a smaller library. You can keep reading while it runs.

## New since 1.0 (1861)

- **Central files after 1963:** footnotes that cite the Subject-Numeric File (1963–1973) or the Central Foreign Policy File are now read. Source Explorer lists them under **Unprinted Material**, and the cross-reference graph draws the Subject-Numeric File's classes.
- **Zotero:** a send that Zotero asks to wait now says so, and for how long, in the Share popover and in a collection's export sheet.
- **Shared code:** Related Documents, search by **Meaning**, the semantic map, the word cloud and Archives Visits now run on code shared with FRUS Explorer Light, the web edition. Each should work as it did in 1.0.

## Getting started

- **Onboarding** offers the whole series, a subseries or one volume, with the size it takes on the Mac. The status bar counts the queue as volumes download and index.
- **The Corpus Browser** (⇧⌘B) goes from subseries to volume, chapter and document. Select text to highlight it or add a note; the **Research rail** (⌘⇧R) holds **Cite**, **Sources**, **Graph**, **Related**, the **Summary** and your notes, tags and collections. **The Search window** (⌥⌘F) searches by **Keywords** or **Meaning**.

**Fixed since 1.0 (1861):** many things, in every window.

## What to test

1. **The re-index:** once it ends, are your notes, highlights, tags and collections all there? Does Search find what it found before?
2. **Shared code:** Related's **Beyond your library**, Project Home, a **Meaning** search and **Search Within Results**, the **Semantic Map** and a slice of it, the word cloud's **Distinctive** and **Collocates**, and an Archives Visit (**Duplicate** it, then export its packet). Does each behave as in 1.0?
3. **Order:** in the Corpus Browser, open *1969–1976, Volume E–9, Part 1*. Does its *Note on U.S. Covert Actions* come before Document 1, as printed?
4. **Source Explorer:** in the 1909 volume, does Document 429 read 1909 and list the Numerical File's rolls?
5. **Citation Lookup:** copy the citation of Document 1190b in the 1898 volume and paste it in. Does it find that document?
6. **Chronology:** choose a range of several years, then hold the pointer over a year in the chart. Does the magnifier name its months?
7. **Collections:** turn off a document's **Research notes**, then export its collection as BibTeX or RIS, or send it to Zotero. Are the notes left out? Does **Duplicate** keep every setting?

Report macOS version, window, clicks, expected, actual and a document id. Thanks!
