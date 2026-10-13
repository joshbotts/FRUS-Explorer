# What's New Since Build 49 (Mac)

**Search results can be selected, tagged and added to a collection. The Corpus Browser opens text a chapter prints outside its documents.**

**First launch re-indexes every downloaded volume, once**; the app may be slower until it finishes. Nothing is re-downloaded.

## Search

- **Select**, in the Search window's titlebar (its **»** menu when the window is narrow), gives every result a checkbox and puts a strip above the list: **Add to Collection…**, **Add Tags…** and, in Checklist Mode, **Mark Reviewed**, each with **Undo**. **Space** checks the highlighted row.
- Right-click one result for **Add to Collection…** and **Add Tags…**. Add Tags takes no tag off.
- **Checklist Mode** has **Mark Page Reviewed** and **Undo**. Its marks last as long as the search.
- A **Meaning** search inside a working corpus or a project's **History** scope ranks that set alone.

## The Corpus Browser and the reader

- A chapter of text alone (a treaty, say) opens with **Read**, where it said "No documents in this section."
- Text a section prints above its documents, such as those present at a meeting, is a **Read** row heading the section, and Search finds it.
- 1981–1988 vol. XVI's documents end with **Persons** and **Abbreviations & Terms** lists, and its people have mentions.
- "See volume V" opens that volume's page in the Corpus Browser, and a reference to a footnote counts for its document.
- Person names and cross-references are underlined, in darker colours, for WCAG 2.2 AA contrast. **File ▸ Print** prints them in colour with no underline.
- 1952–1954 vol. IX, Part 1 has 47 more documents (900–946): Settings ▸ Volumes & Storage ▸ **Check for Corrections** brings them.

## Also

- **Archives:** a Subject-Numeric file with no subject number (POL US-USSR) has **Archival Neighbors**, and a file is one list however it is cited. Archival Analytics groups such files under their category (**Files with no subject number**). A lot cited through the National Archives gets its lot cards with no API key.
- **Language analysis:** Settings ▸ Data & Recovery ▸ **Language Analysis** has **Copy Language Analysis Record**, for a report.
- **Accessibility:** all eleven About the Series charts have an Audio Graph.

**Fixes:** many, in every window and in accessibility.

## What to test

1. **The re-index.** Anything slow while it runs? After it, search, browse and read: worse than build 49?
2. **Selecting results.** Check several, add them to a collection, tag them, and **Undo** each. Right-click a checked result: "Add 3 Selected to Collection…"? In Checklist Mode: **Mark Page Reviewed**, **Undo**.
3. **Meaning inside a set.** Apply a working corpus (**Advanced…**), switch to Meaning, ask a question: every row in the corpus?
4. **Read rows.** 1945 Potsdam vol. II ▸ VI. Minutes… ▸ Monday, July 16 ▸ Meeting of the Joint Chiefs of Staff, 10 a.m.: a **Read** row above Documents (1)? Does Search find Esposito there?
5. **Links.** 1981–88 vol. XVI doc. 368: click Haig and OAS in the lists at its end. 1961–63 vol. VI doc. 16, footnote 1: click "volume V". Does the Corpus Browser come forward on that volume?
6. **The page.** Underlines readable, light and dark, at Extra Large? Print a document (⌘P): names and cross-references in colour, not underlined?
7. **Source Explorer.** 1961–63 vol. V doc. 323: do Archival Neighbors end "Matching archival source: POL US-USSR"? 1969–76 vol. XLI doc. 34: a Candidate NARA Series box above the NARA Catalog box?
8. **Archival Analytics** ▸ Collections ▸ **Central-file classes**: does **Inside these families** open POL to its files?
9. **Your build-49 reports**: fixed?

Not bugs: counts that differ from build 49's (search totals, mentions, cross-reference figures); new region labels on the semantic map; files inside a family in Archival Analytics that carry no country name.

Include macOS version, window, clicks, expected, actual — and for anything archival, the document id. Thanks!
