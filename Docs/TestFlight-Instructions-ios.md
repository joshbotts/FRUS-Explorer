# What's New Since Build 45 (iOS)

The headline: **a central-file number now says what it means**, and there is a new place to browse the archives by it.

**One cost, on first launch.** Build 46 re-indexes every downloaded volume in the background — minutes on a large library. Search and browsing keep working, but People, cross-reference analytics and archival attributions are in flux until it settles. Nothing is re-downloaded and none of your own work is touched.

## Classes, read from the Department's own filing manuals

`874.00` and `POL 27 VIET S` used to render as bare numbers. The app now reads the Department's own schedules — the decimal file in its 1910–1949, 1950–1959 and 1960–1963 arrangements, and the subject-numeric file that replaced it in 1963 — and composes a reading in NARA's filing order: *Bulgaria — Political affairs*; *Vietnam, South — MILITARY OPERATIONS*. Four of those five tables are new here, and so are Bulgaria and Canada, which the country table could not name.

- **Browse ▸ Archives ▸ Classes** is new: five sections, one per schedule, each row carrying a document count and drilling to the volumes citing it. It reads a bundled index, so it works with nothing downloaded.
- Same readings in **Browse ▸ Analysis Tools ▸ Archival Analytics**, at *Show: Central-file classes*.
- The Department filed a territory under the number of the power holding it, so one number often names several places. Where it does, the reading carries **"and N others"**, and a tap opens the list rather than the app asserting one name.
- A volume whose coverage straddles two schedules is counted in **neither** section. The same number means different things either side of each boundary.

## Where each fact on screen came from

Capsules now label provenance — **FRUS text**, **FRUS + NARA catalog**, **FRUS + OH people register**, **This app's model** — in Source Explorer, on archival collection and person pages, in the Add to Collection sheet, and on the semantic map. Exports gain a **Where this came from** block naming the sources they drew on, and how often the source-note parser recognised nothing.

## Also

A lot cited only as where *another* copy sits is no longer stored as the document's own source — visible in **Archival Neighbors…** after the re-index. A lot NARA divided across several series says so in a volume's **Sources** list. Research stops beachballing on a large annotated library, and titles fill in faster. A headerless editorial note reads **Editorial Note 304**, not a blank. Meaning results name the closest matches found, not a total that never existed. A newly indexed volume's people appear without a relaunch.

## What to test

1. **Read down Browse ▸ Archives ▸ Classes against codes you know cold. Are the readings right?** Then: is counting a straddling volume in *neither* era the right call, or does it hide volumes you wanted listed?
2. **"and N others"** — honest compression, or does naming one place mislead? Would you rather see every claimant inline?
3. Time the first-launch re-index, and say how big your library is. Did People and the analytics recover **without** a relaunch?
4. After it finishes: **Archival Neighbors…** on documents whose note names a lot. Does every lot still listed really belong to that document?
5. Do the provenance capsules change what you would claim in print, or are they clutter?
6. **Related ▸ Adjust weights ▸ Semantically similar** above 0, then scroll to **Beyond your library**, new here — are those volumes ones you would have wanted?
7. Meaning search, if you took the model: do the top matches deserve opening? Still unanswered.

Not bugs: a class row with a number and no reading; Facets off in Meaning mode; iCloud Schema "Up to date" beside "Reserved".

Include device + iOS version, taps, expected, actual — and for anything archival, the document id. Thanks!
