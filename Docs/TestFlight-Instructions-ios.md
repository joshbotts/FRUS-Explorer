# What's New Since Build 49 (iOS)

**Search results can be selected, tagged and collected. Browse opens text a chapter prints outside its documents. Collocates works where the device has no dictionary forms.**

**First launch re-indexes every downloaded volume, once**, in the background. Nothing is re-downloaded.

## Search

- **Select Results** (the **•••** menu, or touch and hold a result ▸ **Select**): pick results, then **Add to Collection…**, **Add Tags…** or, in Checklist Mode, **Mark Reviewed**. Each has **Undo**.
- One result's menu has the first two. Add Tags takes no tag off.
- **Checklist Mode** has **Mark Page Reviewed** and **Undo**. Its marks last as long as the search.
- A **Meaning** search inside a working corpus or a project's **History** scope ranks that set alone.

## Browse and the reader

- A chapter of text alone (a treaty, say) opens with **Read**, where it said "No documents in this section."
- Text a section prints above its documents (those present at a meeting, say) is a **Read** row heading the section, and Search finds it.
- 1981–1988 vol. XVI's documents end with **Persons** and **Abbreviations & Terms** lists, and its people have mentions.
- "See volume V" opens that volume's page, and a reference to a footnote counts for its document.
- Person names and cross-references are underlined, in darker colours, for WCAG 2.2 AA contrast.
- 1952–1954 vol. IX, Part 1 gains documents 900–946: Settings ▸ Volumes & Storage ▸ **Check for Corrections** brings them.

## Also

- **Language analysis:** where Settings ▸ Data & Recovery ▸ **Language Analysis** reads *Limited*, **Collocates**, a word cloud's **Distinctive** sizing and Related Documents' **shares:** chips compare words as printed and say so, where they refused or were withheld. **Copy Language Analysis Record** is for a report.
- **Archives:** a Subject-Numeric file with no subject number (POL US-USSR) has **Archival Neighbors** and is ranked under its category; a file is one list however it is cited. A lot cited through the National Archives gets its lot cards with no API key.
- **Live Activity:** two minutes after the app stops, it turns grey and reads *Indexing has stopped.* One left behind goes when the app is opened.
- **Accessibility:** all eleven About the Series charts have an Audio Graph.

**Fixes:** many, on every tab and in accessibility.

## What to test

1. **The re-index.** Anything slow while it runs? After it, search, browse and read: worse than build 49?
2. **Selecting results.** Add a selection to a collection, tag it, and **Undo** each. In Checklist Mode: **Mark Page Reviewed**, **Undo**. At a large text size, is anything covered?
3. **Meaning inside a set.** Apply a working corpus in Filters, switch to Meaning, ask a question: every row in the corpus?
4. **Read rows.** 1945 Potsdam vol. II ▸ VI. Minutes… ▸ Monday, July 16 ▸ Meeting of the Joint Chiefs of Staff, 10 a.m.: a **Read** row above Documents (1)? Does Search find Esposito there?
5. **Links.** 1981–88 vol. XVI doc. 368: tap Haig and OAS in the lists at its end. 1961–63 vol. VI doc. 16, footnote 1: tap "volume V". Underlines readable, light and dark?
6. **Collocates**, if Language Analysis reads *Limited*: does it rank, under a note? (*Working*: no change.)
7. **Sources.** 1961–63 vol. V doc. 323: a list under "Same Subject-Numeric file — POL US-USSR"? 1969–76 vol. XLI doc. 34: "NARA divided this lot file across 4 series"?
8. **Live Activity.** Index a large volume and lock the phone: grey and stopped after two minutes? Force-quit mid-index and reopen: gone?
9. **Your build-49 reports**, and the sync banner over a list's last row: fixed?

Not bugs: counts that differ from build 49's (search totals, mentions, cross-reference figures); new region labels on the semantic map; Collocates that differ between a *Limited* device and a *Working* one.

Include device + iOS version, taps, expected, actual — and for anything archival, the document id. Thanks!
