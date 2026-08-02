# What's New in Build 37 (iOS)

Search grew four ways to read a result set, a strip that shows the query you actually ran, and a facet panel that describes the whole match. Related Documents stopped printing percentages that meant nothing. Bulk summarization stopped claiming successes it did not have. No re-index needed.

## Read a result set four ways
The **binoculars** button in the search actions bar now offers **List**, **Timeline**, **Concordance** and **Collocates**, plus **Facets**. The concordance lines every occurrence of your term up on the term itself, so a screen of hits reads as usage rather than as a list. Collocates ranks the words that keep company with it.

**They do not all count the same thing, and the menu says which is which** — the concordance shows this page, timeline and collocates cover the results retained for this search, and Facets reads the whole match. When you are about to quote a number, that distinction *is* the number.

## The Query Inspector
Under the search field is the **FTS5 expression your query actually became** — the string that went to the database, not a paraphrase. Expand it for each term's index form (with a warning when it is broader than what you typed — `containment` is searched as `contain`), its corpus-wide count, and on request its exact count inside your filters.

## Facets
**Facets** breaks the whole result set down by year, volume, person, document type and archival provenance. Rows are also filters: tap one to narrow, and it becomes a clearable chip. The counts describe the whole match, not the page — the list is capped and the counts are not, and the panel says so. Archival provenance is descriptive only, and states how much of the match it can speak for.

## Two search operators
`NEAR("military guarantee" Europe, 30)` matches only where those ideas appear *together*. `=containment` switches stemming off for one word, so you stop getting *container*.

## Discovery tips
Small tips now point out the app's least visible controls the first few times you reach them — the Research-rail glyph, the invisible page-turn edges, the binoculars menu, and the fact that facet rows are filters. Each retires once you use the control. **Settings → Reading & Search → Display → Show Tips Again** brings them back.

## Related Documents tells the truth
Archival provenance emitted a constant, so its chip read "100%" on every row it ever rendered. An identical single citation read "100%" beside one neighbour and "21%" beside another. Chips now say **cited 3×** and **same provenance**; date, corpus proximity and shared people keep a percentage, which for them is real.

**Corpus proximity** — formerly "Same volume or subseries" — now reads the editors' arrangement: documents printed side by side or gathered into the same short chapter rank highest, easing off as the shared container widens.

## Bulk summarization
The progress count was attempts, not summaries: a run where every document failed reported "1400 of 1400 documents summarized" with nothing written. It now counts successes, reports failures, says when a scope was already done, and — during a very long document — shows **"d39 — part 12 of 131"** instead of a frozen number. It is still honestly hours; the app now says so before you start.

## What to test
1. Run a broad search, then step through all four readings. Do the counts say what they cover?
2. Open Facets and tap a year or volume row — does the chip appear and the count hold?
3. Open Related Documents on a document with a rich archival neighbourhood. Do the chips read sensibly?
4. Start a bulk run over a scope you have already summarized — it should say so rather than showing zero.

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
