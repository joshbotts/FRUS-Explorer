# What's New Since Build 46 (iOS)

The headline: **semantic matching is now on by default.** It shipped switched off, you had to find a slider to try it, and almost nobody did. It is now weighted 0.5 out of the box — still labelled experimental, because how well it reads nineteenth-century prose is genuinely not established.

**No re-index this time.** Build 46 rebuilt every downloaded volume; build 47 does not. Nothing is re-downloaded except the new volume's own vector file.

## Semantic matches, on by default

Every Related Documents list now includes matches found by the shape of the language rather than by citations or archival provenance. Two knock-on effects worth knowing:

- **Vector files now download as you read.** Opening a document's Related panel asks for the vector files of the volumes its matches sit in — **measured at a median of 104 volumes, about 31 MB, for a full library.** They are small files for volumes you already have, but there are a lot of them at once.
- **"Download With Volumes" now governs that too.** Previously the switch covered only the files riding along with a volume download; the read-as-you-go path ignored it. It no longer does. **There is still no separate cellular check** — if you are on a metered connection, turn the switch off (Settings ▸ Storage ▸ vectors) and use **Download Missing Vectors** on Wi-Fi instead. That row now says when the switch is the reason nothing is arriving.
- Turning the axis back down to 0 in **Related ▸ Adjust weights** switches all of it off, including the downloads.

## FRUS 1981–1988, Volume XVI, South America

New, and **partially published** — the Office of the Historian has cleared 4 of its 11 chapters, so the app carries **88 of its 485 documents** and shows an orange *Partial* badge. That is OH's state, not a download problem; the rest arrive when they clear. The corpus is now **553 volumes**.

## Beyond your library, now for a whole project

Project Home gains a section under Suggested Next: volumes you have **not** downloaded that your project's own documents point into, ranked by **how many of your documents reach each one** rather than by how many matches it holds. The Related panel has had the per-document version since build 46; this is the project-wide one.

## Also

"Archive Visits" is now **"Archives Visits"** throughout. Highlights in exported PDF, DOCX and HTML are placed by a corrected offset rule — you should see no difference, which is the point.

## What to test

1. **The default change is the whole build.** Read Related lists on documents you know well. Do the semantic matches earn their place, or do they push better rows down? Would you have chosen 0.5?
2. **Nineteenth-century material especially.** This is the declared unknown. If it is bad there, say so plainly — that is the finding.
3. **Watch your data.** Open a few Related panels and check Settings ▸ Storage. Did vector files arrive faster than you expected? Was 31 MB a surprise?
4. Turn **Download With Volumes** off, open a Related panel, and confirm the semantic section goes quiet — then that Settings tells you why, and that **Download Missing Vectors** still works.
5. **FRUS 1981–1988 vol. XVI** — download it. Does the *Partial* badge read as "OH hasn't finished" rather than "this failed"?
6. **Project Home ▸ Beyond your library** — are those volumes ones you would actually fetch? Is "reached from 7 of yours" the number you want, or would you rather see match counts?
7. Anything that got slower. The Related panel now does more work on every open.

Not bugs: a class row with a number and no reading; Facets off in Meaning mode; iCloud Schema "Up to date" beside "Reserved"; vol. XVI's missing chapters.

Include device + iOS version, taps, expected, actual — and for anything archival, the document id. Thanks!
