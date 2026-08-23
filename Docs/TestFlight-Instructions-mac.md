# What's New Since Build 40 (Mac)

The headline is **Semantic Analytics** — a map of the whole series arranged by how documents are written rather than by who cites whom. None of it existed in build 40. The analytics surfaces also stop borrowing each other's windows.

**First launch re-indexes every downloaded volume, and it is not quick** — the date index moved, which forces a full clean re-parse. The app stays usable while it runs, but Search, dates and person analytics are incomplete until it finishes.

The app also downloads a small extra file per volume (~287 KB) for the semantic features. On by default; Settings ▸ Volumes & Storage ▸ Semantic Vectors turns it off.

## Semantic Analytics (new)

Its own window, from the Analytics menu. Every document in the series is placed on one map by the shape of its language, so documents that read alike land near each other whether or not they share a volume, a date or a citation.

- **Regions** — groups the corpus fell into on its own, named by their most distinctive words. Click one for its size and era mix, or save it as a working corpus.
- **Slices** — click two documents in *different* volumes as poles and the series lays out along that contrast, with time up the side.
- **Lasso** an area to keep it as a working corpus. **Colour by** region, era, downloads or provenance; scope to a subseries, topic or president. ⌘+/⌘−/⌘0 zoom.

Two limits, stated on screen: only local similarity means anything — the distance between far-apart regions does not — and a region's name is a hint drawn from a sample, not a claim about every document in it.

## From a document, and back out

Any document ▸ Research rail ▸ **On the Map** opens the map with that document selected and lists the **ten documents whose language is nearest**. Click one to travel there. The list draws only on downloaded volumes (the map draws all 552), and says so.

## Semantic matches in Related Documents (off by default)

Adjust weights ▸ raise *Semantically similar*. It finds documents on the same subject that share no words, citations or archive. It ships at zero because its accuracy before 1900 is not established. Right-click a match to say whether it helped.

## Archives

Source Explorer and collection details now show where the editors pointed **outside the printed record**, and Archival Analytics ▸ Collections adds **Unprinted pointers** — where readers were *sent*, not where documents came *from*. Never added together, and the screen says so.

## Windows and menus

Six analytics surfaces open in their own windows and are raised, not re-created; two documents can hold two cross-reference graphs. The Search window gains a titlebar and removable filter tokens, Settings a search field, and ⌘P prints the open document.

## Also

Corpus word clouds are built on demand now — allow several minutes. Several sheets that could not be closed now can, a filter section that reloads asks for its data again, and about thirty passages read more plainly — no stated limit softened.

## What to test

1. Let the re-index finish — roughly how long, and how many volumes?
2. Semantic Analytics: pan, zoom, switch lenses — anything that stutters or draws wrong?
3. **On the Map** from a document, then from a second without closing it.
4. Read the ten nearest for a few anchors: useful leads, or plausible noise? This matters most.
5. Two poles in the *same* volume should explain the refusal, not do nothing.
6. Colour by Era: four distinguishable bands, and names on their clusters at every zoom?
7. Save a region as a working corpus and scope a search to it.
8. Raise the semantic weight; judge matches, especially pre-1900 (right-click to record a verdict).
9. Re-invoke open analytics windows from the menu — each should raise, not duplicate.
10. Unprinted pointers: does the ranking read sensibly?
11. Corpus Browser ▸ Clusters: skim several clusters and open a few. Do the groupings read as coherent research leads, or as arbitrary piles? This feeds the same leads-or-noise verdict as item 4 — the list exists so you can judge membership directly, not just the map's picture.
12. In a cluster: **See on the semantic map** should raise the map window zoomed on that region with its card open; **Save as Working Corpus** on a big cluster should say it kept the first 7,500.
13. Project Home ▸ **Plan a Visit** (or Collections ▸ ＋ Add ▸ **Plan an Archive Visit…**): read the generated packet against documents you know. Is anything it asserts about your records wrong? The inquiry draft should paste cleanly into Mail; **Share as PDF** should print the same text.
14. In the packet: with no visit date, deadlines should read relative; a citation the app can't place should appear verbatim under "help me locate", never dropped.

Include macOS version, what you clicked, what you expected, what happened. Thanks for testing!
