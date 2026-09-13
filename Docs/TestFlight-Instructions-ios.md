# What's New Since Build 46 (iOS)

**Semantic matching is on by default**, weighted 0.5 and still labelled experimental: how well it reads nineteenth-century prose is not established.

**First launch re-indexes every downloaded volume, once.** It runs in the background and joins person lists in four older volumes. Nothing is re-downloaded.

## Semantic matches, on by default

Related Documents now includes matches by the shape of the language, and re-scores what other signals found, so its order changes.

- **Vector files download as you read.** Opening Related fetches missing files for its candidates' volumes: a median of 104 volumes, about 31 MB, on a full library.
- **Download With Volumes** governs that. There is no cellular check: on a metered connection turn it off in **Settings ▸ Volumes & Storage ▸ Semantic Vectors** and use **Download Missing Vectors** on Wi-Fi.
- Weight 0 in **Related ▸ Adjust weights** stops Related's matches and the downloads it starts. Files for a new volume and Meaning searches still download unless the switch is off; Project Home has its own **Adjust weighting**.

## Notes

The note editor has a formatting switch by its **Note** header and a bar above the keyboard. Its **Tags** and **Projects** rows open searchable lists you can reorder. Settings' Notes pane is gone; the Research tab has **Contains Notes** and **All Notes**. Search now finds every note on a document, a deleted note's words drop out, and saving a note no longer erases a document's tags from tag search.

## Your order for tags and projects

Set it in **Settings ▸ Tags** or **Projects** (under Research): tap **Reorder**, or long-press a row for **Move to Top**, **Move Up** or **Move Down**. The note pickers, document tag picker, Active Project picker, Browse project menu and Search's **My Tags** follow it.

## Archives

**Browse ▸ Archives ▸ Collections** gains a grouping menu (**Repository**, **Record Group**, **Ungrouped**), a sort menu, and collapsible groups with **Collapse All**. Source Explorer's **Browse Archival Collections** gets the same controls.

## Documents stay in their tab

A document opened from Research, Collections, Settings ▸ Projects ▸ Project Home or an Archives Visits plan opens in that tab, and Back returns there. **Browse all topics…** opens Browse ▸ **Topics** (not in iPad analytics windows).

## Also

FRUS 1981–1988 vol. XVI is new and partial: 88 of 485 documents, an orange **Partial** badge. Project Home gains **Beyond your library**. "Archive Visits" is now "Archives Visits".

## What to test

1. **The default change.** Read Related lists on documents you know well. Do semantic matches earn their place, or push better rows down?
2. **Nineteenth-century material especially.** The declared unknown; if it is bad there, say so.
3. **Watch your data.** Open a few Related panels, then check Semantic Vectors in Settings. Was 31 MB a surprise?
4. **Notes.** Format a note, save, reopen. Search the Tags list; clear it, tap **Edit**, drag. Open Contains Notes and All Notes. Search a word only in a document's second note, delete that note, search again.
5. **Order.** Reorder in Settings, then check the pickers, the Browse project menu and My Tags.
6. **Archives.** Group, sort and collapse in Browse ▸ Archives ▸ Collections, then Source Explorer.
7. Open a document from Research, or long-press a collection row ▸ **Open Document**; press Back.
8. **Vol. XVI.** Does Partial read as "not finished" rather than "failed"? Are its tags there?
9. Anything slow, especially during the first-launch re-index.

Not bugs: a class row with a number and no reading; iCloud Schema "Up to date" beside "Reserved"; vol. XVI's missing chapters and Reagan/Shultz/Haig tags; Related order differing from build 46; **Reorder** only with two or more tags or projects.

Include device + iOS version, taps, expected, actual — and for anything archival, the document id. Thanks!
