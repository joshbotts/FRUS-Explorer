# What's New Since Build 43 (iOS)

The headlines: **search by meaning** and **archive visit plans**. Also: a Similar-wording axis in Related, classification overrides, saved-search freshness badges, FRUS text in system Spotlight.

**Two one-time costs on first launch**: a full re-index of downloaded volumes (one index change), and a background Spotlight re-donation (~317k items). The app stays usable; Search and archival surfaces are incomplete until the re-index finishes.

## Search by meaning (experimental)

Two engines now: **Keywords**, and **Meaning** — a new segment under the search field that ranks the whole series by what your question means, so "Why did the Marshall Plan happen?" finds the 1947 policy papers despite sharing no words with them.

- A one-time, optional **229 MB model download** (Google's EmbeddingGemma, running entirely on-device). Offered when keywords find nothing, or when you switch to Meaning; managed under Settings ▸ Volumes & Storage.
- **Results reach beyond your library**: matches in volumes you lack show the volume title, a score, and a Download Volume button.
- The strip above the results states the terms: filters intersected, what couldn't be scored yet — scoring **warms up over your first few searches** as small match files download.
- Exact phrases stay keywords' job; concordance/collocates/facets close in Meaning mode; Saved Searches always run as keywords.

## Archive visit plans — now fed from all over the app

Persistent, synced plans for consulting the records behind your documents. The list lives in the **Research tab ▸ Archive Visits**; each plan holds **research targets** on two labeled channels — where documents *came from* (source notes) and what their footnotes *point at* (external references) — never summed, plus archival units added at their own grain. A packet generated from a plan draws its chapters from the targets; unresolvable citations route into the advance inquiry; deleting asks first (it cascades).

**Feeding a plan, from wherever you're working**: Collections (a collection's add menu sends its documents), Source Explorer (an archival collection's page, or the Archival Neighbors sheet, sends the documents sharing a unit — or the unit itself). Every add goes through the same picker with a blue **basis banner** saying which claim the seeds contribute and where the add came from — you approve exactly what gets written.

## Also

**Similar wording** (Related, weight 0): raise it and matches share distinctive vocabulary, chips naming the terms; the archival axis routes ~11k more documents to neighbors. **Classification overrides**: fix a wrong chip from the rail's info popover; synced, survives re-indexing. **Saved searches** show an exact new-since-last-run count. **Spotlight** finds document text from the home screen. Previously-published sources signpost instead of dead-ending; pre-1910 consular rolls resolve offline; two iPad layout fixes; long titles wrap.

## What to test

1. Meaning end-to-end: empty keyword search → model offer → accept on Wi-Fi → it searches by itself.
2. Ask real research questions in Meaning. Do the top matches deserve opening? **This is the verdict we most need.**
3. Download Volume from a beyond-library match; re-run — the row gains its title.
4. Search twice early: does "could not be scored yet" fall?
5. Filters + Meaning: a volume scope or date range should narrow results, the strip saying what it removed.
6. Archive Visits: build one plan from three places — a collection, an Archival Neighbors sheet, a hand-entered unit. Do the basis banners describe each add right? Are the two channels labeled apart in the packet?
7. Similar wording on a distinctively-worded document — do matches read alike?
8. Override a wrong classification chip; re-index; it should survive.
9. Spotlight a phrase you know is in a downloaded document.

Include device + iOS version, taps, expected, actual. Thanks!
