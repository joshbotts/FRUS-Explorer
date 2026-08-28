# What's New Since Build 43 (iOS)

The headline: **search by meaning** — ask the corpus a question in your own words, answered by a language model that runs entirely on your device. Also new: tracked **archive visit plans**, a **Similar wording** axis in Related Documents, **classification overrides**, saved-search **freshness badges**, and FRUS document text in the system's own Spotlight search.

**Two one-time costs on first launch.** A full re-index of every downloaded volume (one index change since build 43 — footnote citations now inherit through bare *Ibid.*s, enriching the archival channel by ~1,200 references); and a background re-donation of ~317,000 items to Spotlight. The app stays usable meanwhile, but Search and the archival surfaces are incomplete until the re-index finishes.

## Search by meaning (experimental)

Search has two engines now. **Keywords** is everything you know. **Meaning** — the new segment under the search field — embeds your question on-device and ranks the whole series by what it means, so *"Why did the Marshall Plan happen?"* finds the 1947 policy papers even though no document contains those words.

- **The model is a one-time, optional 229 MB download** (Google's EmbeddingGemma, running locally — nothing you search ever leaves the device). You'll be offered it the first time a keyword search comes up empty, or when you switch to Meaning; a consent sheet states the terms, and Settings ▸ Volumes & Storage ▸ Natural-Language Search manages or removes it.
- **Results reach beyond your library.** Matches in volumes you haven't downloaded appear under their volume's title with a **Download Volume** button — that's the point: discovery across all 552 volumes. Each match carries a "Semantic match · N%" score.
- **The strip above the results tells you the terms**: ranked by meaning, filters intersected (and how many matches they removed), what couldn't be scored yet. Scoring **warms up over your first few searches** as small per-volume match files download in the background — search again a moment later and the caption's number falls.
- **Where keywords stay better**: exact phrases and terms of art (*"persona non grata"*). Meaning search dissolves the phrase; that's why keyword search stays the default and the fallback only offers Meaning when keywords found nothing.
- Keyword-only readings (concordance, collocates, facets) close in Meaning mode rather than describing a different query; Saved Searches always run as keyword searches.

## Archive visit plans

The trip packet grows a memory. **Research ▸ Archive Visits** keeps persistent, synced visit plans: each plan holds **research targets** drawn from your documents' source notes *and* from their footnotes' archival references (the two channels are labeled apart and never summed), plus targets you add by hand at the archival-unit grain. The packet chapters draw on the plan, unresolvable citations route into the advance inquiry, and deleting a plan asks first — it cascades.

## Related Documents: Similar wording (experimental)

A new axis beside Semantic similarity, starting at weight 0: raise it and Related also matches documents whose **wording** reads alike — the anchor's most distinctive terms run as a live query over your indexed volumes. Chips name the shared terms. Separately, the archival axis reaches further back: dotless file numbers, record-group series, consular film segments, and central-file citations now route ~11,000 more documents to archival neighbors.

## Classification overrides

A document whose classification chip is wrong (OCR damage, a marking the parser misread) can be corrected: the Research rail's info popover gains an **Override** control. Overrides sync, survive re-indexing, and replay onto fresh indexes.

## Saved searches know when they're stale

Each saved search shows **how many new results** have appeared since you last ran it — an exact count against the live index, not a guess. Running the search clears the badge everywhere via sync.

## Spotlight

FRUS document text is donated to the system Spotlight index — search from the home screen and documents open in the app.

## Also

The Mac quit crash after a Meaning search is fixed (caught in this cycle's testing). Source Explorer's previously-published sources now signpost where the document was printed instead of dead-ending; pre-1910 consular and domestic-letters rolls resolve offline. The semantic map exports publication-quality figures. Two iPad layout fixes from the probe pass; long titles wrap instead of clipping.

## What to test

1. Let the re-index finish, then: **Meaning search end-to-end** — a keyword search that finds nothing should offer the model; accept on Wi-Fi (229 MB), watch it search automatically after the download.
2. Ask real research questions in Meaning mode — the kind you'd ask a colleague, not keywords. Do the top matches deserve to be opened? This is the verdict we most need.
3. A match in a volume you don't have: **Download Volume** from the result, then re-run — the row should gain its title.
4. Search twice in a row early on: does the "could not be scored yet" number fall as match files land?
5. Try an exact phrase in Meaning mode (*"trust but verify"*) — keywords should beat it; tell us if the ranking surprises you either way.
6. Filters + Meaning: set a volume scope or date range, search by meaning — the strip should say what the filters removed.
7. **Archive Visits** (Research tab): create a plan from documents you know, add a hand-entered target, check the two evidence channels stay labeled apart in the packet.
8. **Similar wording**: raise the axis in Related's Adjust weights on a document with distinctive vocabulary — do the matches read alike? The chips should name shared terms.
9. Override a wrong classification chip from the rail's info popover; re-index a volume (Settings) and confirm the override survives.
10. Spotlight from the home screen: search a phrase you know is in a downloaded document.

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
