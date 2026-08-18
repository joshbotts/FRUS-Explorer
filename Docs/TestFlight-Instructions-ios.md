# What's New Since Build 40 (iOS)

The headline is **Semantic Analytics** — a map of the whole series arranged by how documents are written rather than by who cites whom. None of it existed in build 40. iPad also gains a two-pane Browse and Research.

**First launch re-indexes every downloaded volume, and it is not quick** — the date index moved, which forces a full clean re-parse. The app stays usable while it runs, but Search, dates and person analytics are incomplete until it finishes.

The app also downloads a small extra file per volume (~287 KB) for the semantic features. On by default; Settings ▸ Volumes & Storage ▸ Semantic Vectors turns it off.

## Semantic Analytics (new)

Browse ▸ Analysis Tools ▸ Semantic Analytics. Every document in the series is placed on one map by the shape of its language, so documents that read alike land near each other whether or not they share a volume, a date or a citation.

- **Regions** — groups the corpus fell into on its own, named by their most distinctive words. Tap one for its size and era mix, or save it as a working corpus and scope a search to it.
- **Slices** — tap two documents in *different* volumes as poles and the series lays out along that contrast, with time up the side.
- **Lasso** an area to keep it as a working corpus. **Colour by** region, era, downloads or provenance; scope the map to a subseries, topic or president.

Two limits, stated on screen: only local similarity means anything — the distance between far-apart regions does not — and a region's name is a hint drawn from a sample, not a claim about every document in it.

## From a document, and back out

Any document ▸ Research rail ▸ **On the Map** opens the map with that document selected and lists the **ten documents whose language is nearest**. Tap one to travel there. The list draws only on downloaded volumes (the map draws all 552) — it says so, and says when the anchor's own volume is missing.

## Semantic matches in Related Documents (off by default)

Adjust weights ▸ raise *Semantically similar*. It finds documents on the same subject that share no words, citations or archive. It ships at zero because its accuracy before 1900 is not established. Press and hold a match to say whether it helped.

## Archives

Source Explorer and collection details now show where the editors pointed **outside the printed record**, and Archival Analytics ▸ Collections adds **Unprinted pointers** as a third ranking — where readers were *sent*, not where documents came *from*. The three are never added together, and the screen says so.

## Also

Resizing an iPad window no longer crashes. A new volume scope now saves — it could be lost silently. Every stuck text field gains a Done above the keyboard. iPad at full width keeps Browse and Research beside what you opened; a filter section that reloads asks for its data again. Corpus word clouds are built on demand now — allow several minutes — rather than in a background pass that never paid for itself. About thirty passages read more plainly; no stated limit was softened.

## What to test

1. Let the re-index finish — roughly how long, and how many volumes?
2. Semantic Analytics: does the map feel responsive? Note your device.
3. **On the Map** from a document, then from a second without closing it.
4. Read the ten nearest for a few anchors: useful leads, or plausible noise? This matters most — we have no measurement that can answer it.
5. Two poles in the *same* volume should explain the refusal, not do nothing.
6. Colour by Era: four distinguishable bands, ordered early to late?
7. Save a region as a working corpus and scope a search to it.
8. Raise the semantic weight; judge matches, especially pre-1900 (long-press to record a verdict).
9. iPad two-pane, both orientations.
10. Unprinted pointers: does the ranking read sensibly?

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
