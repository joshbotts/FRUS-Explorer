# What's New Since Build 43 (Mac)

The headline: **search by meaning** — ask the corpus a question in your own words, answered by a language model that runs entirely on your Mac. Also new: tracked **archive visit plans** in their own window, a **Similar wording** axis in Related Documents, **classification overrides**, saved-search **freshness badges**, and a fix for the quit crash this cycle's testing caught.

**Two one-time costs on first launch.** A full re-index of every downloaded volume (one index change since build 43 — footnote citations now inherit through bare *Ibid.*s, enriching the archival channel by ~1,200 references); and a background re-donation of ~317,000 items to Spotlight. The app stays usable meanwhile, but Search and the archival surfaces are incomplete until the re-index finishes.

## Search by meaning (experimental)

The Search window has two engines now. **Keywords** is everything you know. **Meaning** — the new control beside the query field — embeds your question on-device and ranks the whole series by what it means, so *"Why did the Marshall Plan happen?"* finds the 1947 policy papers even though no document contains those words.

- **The model is a one-time, optional 229 MB download** (Google's EmbeddingGemma, running locally — nothing you search ever leaves the machine). Offered when a keyword search comes up empty or when you switch to Meaning; a consent sheet states the terms, and Settings ▸ Volumes & Storage ▸ Natural-Language Search manages or removes it.
- **Results reach beyond your library**: matches in volumes you haven't downloaded appear under their volume's title with a **Download Volume** button, each with a "Semantic match · N%" score.
- **The strip above the results states the terms**: ranked by meaning, filters intersected (and how many matches they removed), what couldn't be scored yet. Scoring **warms up over your first few searches** as small per-volume match files download in the background.
- **Where keywords stay better**: exact phrases and terms of art. Keyword-only readings (concordance, collocates, facets) and the "Search in" scope chips close in Meaning mode; Saved Searches always run as keyword searches.
- **The quit crash is fixed**: quitting within a few minutes of a Meaning search previously aborted; please quit freely and tell us if you ever see it again.

## Archive visit plans

The trip packet grows a memory. The **Archive Visits** window (Window menu) keeps persistent, synced visit plans in a Collections-style flat pane: each plan holds **research targets** drawn from your documents' source notes *and* from their footnotes' archival references (labeled apart, never summed), plus hand-entered targets at the archival-unit grain. Packet chapters draw on the plan; unresolvable citations route into the advance inquiry; deletion confirms before cascading.

## Related Documents: Similar wording (experimental)

A new axis beside Semantic similarity, starting at weight 0: raise it and Related also matches documents whose **wording** reads alike — the anchor's most distinctive terms run as a live query over your indexed volumes, with chips naming the shared terms. The archival axis also reaches further back: dotless file numbers, record-group series, consular film segments, and central-file citations now route ~11,000 more documents to archival neighbors.

## Classification overrides

A document whose classification chip is wrong can be corrected from the Research rail's info popover: an **Override** control. Overrides sync, survive re-indexing, and replay onto fresh indexes.

## Saved searches know when they're stale

Each saved search shows **how many new results** have appeared since you last ran it — an exact count, not a guess. Running the search clears the badge on every device.

## Also

Window discipline continued: Source Explorer joins the value-based windows, the sliced semantic map survives Handoff, and text scaling respects the system setting. The semantic map exports publication-quality figures. Source Explorer's previously-published sources signpost where the document was printed instead of dead-ending; pre-1910 consular and domestic-letters rolls resolve offline. Long titles wrap instead of clipping.

## What to test

1. Let the re-index finish, then: **Meaning search end-to-end** — an empty keyword search should offer the model; accept (229 MB), watch it search automatically after the download.
2. Ask real research questions in Meaning mode. Do the top matches deserve opening? This is the verdict we most need.
3. A match in a volume you don't have: **Download Volume** from the result, re-run, the row should gain its title.
4. **Quit within a couple of minutes of a Meaning search** — this exact sequence crashed before the fix; it must not now.
5. Filters + Meaning: a volume scope or date range should visibly narrow Meaning results, with the strip saying what was removed.
6. **Archive Visits** (Window menu): create a plan, add targets from documents and by hand, export the packet — the two evidence channels stay labeled apart.
7. **Similar wording**: raise the axis in Related on a distinctively-worded document; the chips should name shared terms.
8. Override a wrong classification chip from the rail popover; re-index and confirm it survives.
9. Saved searches: run one, add a volume that matches it, and check the badge counts the new results.

Include your macOS version, what you clicked, what you expected, what happened. Thanks for testing!
