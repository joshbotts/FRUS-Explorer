# What's New Since Build 46 (Mac)

**Semantic matching is on by default**, weighted 0.5 and still labelled experimental: how well it reads nineteenth-century prose is not established. **Your notes get formatting, and your tags and projects your own order.**

**First launch re-indexes every downloaded volume, once**, to join person lists in four older volumes; three show people only while their set's first part is downloaded. The app may be slower until it finishes. Nothing is re-downloaded.

## Semantic matches, on by default

- Related Documents now includes matches found by the shape of the language, and the semantic axis also re-scores rows other signals found, so Related order changes.
- **Vector files download as you read**: opening Related asks for the files of the volumes its matches sit in, measured on a full library at a median of 104 volumes, about 31 MB.
- **Download With Volumes** governs that. There is no metered-connection check: turn it off in **Settings ▸ Volumes & Storage ▸ Semantic Vectors** and use **Download Missing Vectors** later.
- Setting the axis to 0 in **Related ▸ Adjust weights** stops semantic matches and Related's vector requests, not the files fetched by volume downloads or Meaning searches. Only the switch stops those.

## Notes

An unlabelled switch by the **Note** header, on by default, shows a formatting bar. **Tags** and **Projects** are one row each, opening a searchable list you drag to reorder. The Research window adds **Contains Notes** and **All Notes**; the Settings Notes pane is gone. Search now finds every note on a document, a deleted note's words drop out, and saving a note no longer erases a document's tags from tag search.

## Your order for tags and projects

Set it in **Settings ▸ Research ▸ Tags** or **Projects**: right-click a row for **Move to Top**, **Move Up**, **Move Down**. The note editor's pickers, the document tag picker, the Active Project picker, **Research ▸ Switch Project** and Search's **My Tags** follow it.

## Archives

In **Corpus Browser ▸ Archives**, **Collections** gets a group menu (**Repository**, **Record Group**, **Ungrouped**); it and **Classes** get a sort menu, collapsing headers and **Collapse All**. Source Explorer's **Collections** gets the same row.

## Also

FRUS 1981–1988 vol. XVI is new and partial: 88 of 485 documents, an orange *Partial* badge; 553 volumes. Project Home adds **Beyond your library**. Pre-1906 Source Explorer suggests a series for more documents. "Archive Visits" is now **"Archives Visits"**.

## What to test

1. **The semantic default.** Do semantic matches earn their place in Related, or push better rows down? Nineteenth-century material especially: if it is bad there, say so.
2. **Data use.** Open a few Related panels, then check **Volumes & Storage ▸ Semantic Vectors**. Was 31 MB a surprise? With the switch off, does **Download Missing Vectors** say why?
3. **Notes.** Format a note, save, reopen. Search a picker, clear the search, drag to reorder. Open Contains Notes and All Notes. Search a word only in a second note, delete that note, search again.
4. **Order.** Move tags and projects in Settings; check the pickers, Switch Project and My Tags.
5. **Archives.** Group, sort and collapse in Corpus Browser ▸ Archives ▸ Collections, then Source Explorer.
6. **Related** from the document's Research panel (⇧⌘R): is the new order better?
7. **Pre-1906 Source Explorer**, from Research: does a letter to a U.S. minister list Instructions first?
8. **Vol. XVI**: does *Partial* read as "OH hasn't finished" rather than "this failed"?
9. Anything slow, especially during the first-launch re-index.

Not bugs: a class row with a number and no reading; iCloud Schema "Up to date" beside "Reserved"; vol. XVI's missing chapters; Related order differing from build 46; no drag reordering in the Settings tag and project lists.

Include macOS version, window, clicks, expected, actual — and for anything archival, the document id. Thanks!
