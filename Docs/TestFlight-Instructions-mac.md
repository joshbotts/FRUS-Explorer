# What's New Since Build 43 (Mac)

The headlines: **search by meaning** and **archive visit plans**, in their own window. Also: Similar wording in Related, classification overrides, saved-search freshness, the quit-crash fix.

**Two one-time costs on first launch**: a full re-index of downloaded volumes (one index change), and a background Spotlight re-donation (~317k items). The app stays usable; Search and archival surfaces are incomplete until the re-index finishes.

## Search by meaning (experimental)

Two engines now: **Keywords**, and **Meaning** — a new control beside the query field that ranks the whole series by what your question means, so "Why did the Marshall Plan happen?" finds the 1947 policy papers despite sharing no words with them.

- A one-time, optional **229 MB model download** (Google's EmbeddingGemma, entirely on your Mac). Offered when keywords find nothing or you switch to Meaning; managed under Settings ▸ Volumes & Storage.
- **Results reach beyond your library**: matches in volumes you lack show the volume title, a score, and a Download Volume button.
- The strip above the results states the terms: filters intersected, what couldn't be scored yet — scoring **warms up over your first few searches**.
- Exact phrases stay keywords' job; concordance/collocates/facets and the "Search in" chips close in Meaning mode; Saved Searches always run as keywords.
- **The quit crash is fixed** — quitting soon after a Meaning search previously aborted.

## Archive visit plans — now fed from all over the app

Persistent, synced plans for consulting the records behind your documents — the **Archive Visits window** (Window menu, or the sidebar's Research section). Each plan holds **research targets** on two labeled channels — where documents *came from* (source notes) and what their footnotes *point at* (external references) — never summed, plus archival units added at their own grain. A packet generated from a plan draws its chapters from the targets; unresolvable citations route into the advance inquiry; deletion confirms (it cascades).

**Feeding a plan, from wherever you're working**: Collections (a collection's add menu sends its documents) and Source Explorer (an archival collection's page or the Archival Neighbors sheet sends the documents sharing a unit — or the unit itself). Every add uses one picker with a blue **basis banner** saying which claim the seeds contribute and where the add came from — you approve exactly what gets written.

## Also

**Similar wording** (Related, weight 0): raise it and matches share distinctive vocabulary, chips naming the terms; ~11k more documents gain archival neighbors. **Classification overrides**: fix a wrong chip from the rail's info popover; synced, survives re-indexing. **Saved searches** show an exact new-since-last-run count. Source Explorer joins the value-based windows; the sliced map survives Handoff; text scaling respects the system setting; previously-published sources signpost instead of dead-ending; long titles wrap.

## What to test

1. Meaning end-to-end: empty keyword search → model offer → accept → it searches by itself.
2. Ask real research questions in Meaning. Do the top matches deserve opening? **This is the verdict we most need.**
3. Download Volume from a beyond-library match; re-run — it gains its title.
4. **Quit within a couple of minutes of a Meaning search** — this exact sequence crashed before; it must not now.
5. Filters + Meaning: a volume scope or date range narrows results, the strip saying what it removed.
6. Archive Visits: build one plan from a collection, an Archival Neighbors sheet, and a hand-entered unit. Do the basis banners describe each add right? Channels labeled apart in the exported packet?
7. Similar wording on a distinctively-worded document — do matches read alike?
8. Saved searches: run one, add a matching volume, check the badge counts the new results.

Include macOS version, clicks, expected vs. actual. Thanks!
