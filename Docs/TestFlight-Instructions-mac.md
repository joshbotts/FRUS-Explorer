# What's New in Build 37 (Mac)

Search grew four ways to read a result set, a strip showing the query you actually ran, and a facet panel describing the whole match. Related Documents stopped printing percentages that meant nothing. Bulk summarization stopped claiming successes it did not have. Facet and tag counts got much faster on a cold start. No re-index needed.

## Read a result set four ways
The **binoculars** button in the search actions bar now offers **List**, **Timeline**, **Concordance** and **Collocates**, plus **Facets**. The concordance lines every occurrence of your term up on the term itself, so a screen of hits reads as usage rather than as a list. Collocates ranks the words that keep company with it.

**They do not all count the same thing, and each panel names the set it used** — the concordance shows this page, timeline and collocates cover the results retained for this search, and Facets reads the whole match. When you are about to quote a number, that distinction *is* the number.

## The Query Inspector
Under the search field is the **FTS5 expression your query actually became** — the string that went to the database, not a paraphrase. Expand it for each term's index form (with a warning when it is broader than what you typed — `containment` is searched as `contain`), its corpus-wide count, and on request its exact count inside your filters. If you publish method appendices, this is the line to quote.

## Facets
**Facets** breaks the whole result set down by year, volume, person, document type and archival provenance. Rows are also filters: click one to narrow, and it becomes a clearable chip. The counts describe the whole match, not the page — the list is capped and the counts are not, and the panel says so. Archival provenance is descriptive only, and states how much of the match it can speak for.

Opening it is also much faster on a cold launch: it was reading a gigabyte of text it never looked at.

## Discovery tips
Small tips now point out easy-to-miss controls the first few times you reach them — the binoculars menu, the fact that facet rows are filters, and the cross-reference graph's reference list and layout picker. Each retires once you use the control. **Settings → Reading & Search → Display → Show Tips Again** brings them back.

## Related Documents tells the truth
Archival provenance emitted a constant, so its chip read "100%" on every row it ever rendered. An identical single citation read "100%" beside one neighbour and "21%" beside another. Chips now say **cited 3×** and **same provenance**; date, corpus proximity and shared people keep a percentage, which for them is real. Chip order is also stable across launches now.

**Corpus proximity** — formerly "Same volume or subseries" — now reads the editors' arrangement: documents printed side by side or gathered into the same short chapter rank highest, easing off as the shared container widens.

## Bulk summarization
The progress count was attempts, not summaries: a run where every document failed reported "1400 of 1400 documents summarized" with nothing written. It now counts successes, reports failures, says when a scope was already done, and — during a very long document — shows **"d39 — part 12 of 131"** instead of a frozen number. The concurrency setting is finally remembered between runs. It is still honestly hours; the app now says so before you start, and that quitting stops a run.

## What to test
1. Run a broad search, then step through all four readings. Do the counts say what they cover?
2. Open Facets on a cold launch — expand every section and click a row to narrow.
3. Open Related Documents on a document with a rich archival neighbourhood; relaunch and confirm the chips appear in the same order.
4. Set the summarization concurrency, close the sheet, reopen it — it should have kept your choice.

Include macOS version, what you clicked, what you expected, what happened. Thanks!

## Source Explorer now answers where the National Archives cannot

Four kinds of citation that used to end in a shrug now resolve, all without a NARA API key.

**Repositories outside the National Archives.** Library of Congress, National Defense University,
the Army's Center of Military History, the Hoover Institution, university and historical-society
collections. Source Explorer no longer runs a catalogue query that cannot succeed; it names the
institution, says what it holds, and links to its finding aids. **Two have been renamed since FRUS
printed them** — the Naval Historical Center is now the Naval History and Heritage Command (2008),
and the U.S. Army Military History Institute's holdings are now the Army Heritage and Education
Center — so searching under the printed name finds nothing. The panel says so.

**Series cited by name alone.** `Roosevelt Papers`, `Leahy Papers`, `J.C.S. Files`,
`Moscow Embassy Files` — the whole source note, with no repository in it. Where a volume's own
front matter says where the series is held, that destination is shown **with the editors'
sentence quoted beneath it**, so you can judge it rather than take it on trust.

**Paris Peace Conference citations.** `Paris Peace Conf. 180.03401/101` looks like a State
Department decimal file and is not — it is Record Group 256. These now resolve to the right record
group, the series holding the Conference's decimal file, and NARA's index and classification manual
for it. The panel deliberately does *not* guess which microfilm roll holds your document.

**Front-matter Sources lists in the early-1950s volumes.** Fourteen volumes wrote their collection
list as paragraphs rather than a list, and read as a wall of prose. They now show their collections
properly — 526 of them — each with the editors' description attached, and each resolving to the
National Archives.

### What to test

- Open a 1919 Paris volume document and check the Paris Peace Conference panel.
- Open any document citing the Library of Congress or the Naval Historical Center and read the
  repository block — is what it tells you what you'd want to know before travelling?
- Browse to **frus1951v05 ▸ Sources** and confirm the collections read as a list, with each
  description under its collection.
- Browse to **frus1950v07 ▸ Sources** and confirm its published-works list still reads as books,
  not as archival collections.
- Anywhere a catalogue link appears, check where it actually lands. **A confident link to the
  wrong records is the bug we most want to hear about.**
