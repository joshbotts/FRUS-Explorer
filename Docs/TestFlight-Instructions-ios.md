# What's New Since Build 40 (iOS)

The headline is **Semantic Analytics** — a map of the whole series arranged by how documents are written rather than by who cites whom. It is entirely new: none of it existed in build 40. iPad also gains a two-pane Browse and Research at full width.

**First launch re-indexes every volume you have downloaded, and it is not quick.** The date index moved (36 → 40) and person rollups moved with it, and a date-version change forces a full clean re-parse of the XML. The app stays usable while it runs, but Search results, dates and person analytics are incomplete until it finishes.

The app downloads a small extra file per volume for the semantic features (about 287 KB each). That is on by default and can be turned off — Settings ▸ Volumes & Storage ▸ **Semantic Vectors**.

## Semantic Analytics (new)

Browse ▸ **Analysis Tools** ▸ *Semantic Analytics*. Every document in the published series is placed on one map by the shape of its language, so documents that read alike land near each other whether or not they share a volume, a date or a citation.

- **Regions** are groups the corpus fell into on its own, named by their most distinctive words. Tap one to see its size and era mix, or **Save as Working Corpus** to keep it and scope a search to it.
- **Slices** are the opposite move: tap two documents in *different* volumes as poles and the whole series lays out along the contrast you named, with time up the side.
- **Lasso** an area to keep everything inside it as a working corpus.
- **Colour by** region, era, what you have downloaded, or archival provenance.

Two honest limits, both stated on screen. The layout preserves *local* similarity — near neighbours mean something, the distance between two far-apart regions does not. And a region's name comes from a sample of its documents, so read it as a hint rather than a claim about every document in it.

## From a document, and back out again (new)

Open any document ▸ Research rail ▸ **On the Map**. The map opens with that document selected and the view brought to it, and its card lists the **ten documents whose language is nearest**. Tap one to travel there.

That list is drawn only from volumes you have downloaded, even though the map draws all 552 — it says so under the list. If the document's own volume is not on the device there is nothing to compare against at all, and it says that too.

## Semantic matches in Related Documents (new, and off)

Related Documents ▸ **Adjust weights** ▸ raise *Semantically similar*. It finds documents on the same subject even when they share no words, citations or archive. It ships at zero because **its accuracy on nineteenth-century material has not been established** — a real unknown, not modesty. Press and hold a match to say whether it helped.

## iPad: two panes

At full width, **Browse** and **Research** keep the list beside what you opened instead of replacing it. A document takes the width back when it needs it. The sidebar is no longer five rows and a void.

## Smaller things

The concordance keeps its columns on a phone. Text fields you could get stuck in now offer a way to dismiss the keyboard. A filter section that was open when its data reloaded asks for it again instead of sitting empty. About thirty explanatory passages were rewritten more plainly — no stated limit was softened.

## What to test

1. Let the re-index finish. Roughly how long, and how many volumes?
2. Open **Semantic Analytics** and move around. Does the map feel responsive on your device? Note the model.
3. From a document, **On the Map** — then do it again from a *second* document without closing the map.
4. Read the **ten nearest documents** for a few anchors. Are they useful research leads, or plausible noise? This matters more than anything else here: we have no measurement that can answer it.
5. Tap two documents in the **same volume** as poles. It should explain why it cannot make an axis rather than doing nothing.
6. **Colour by ▸ Era** — can you tell the four bands apart, and do they read as ordered early-to-late?
7. Save a region as a **working corpus**, then scope a search to it.
8. Raise the **Semantically similar** weight and judge a few matches, especially pre-1900. Long-press to record a verdict.
9. On iPad at full width, check **Browse** and **Research** in both orientations.

Include device + iOS version, what you tapped, what you expected, what happened. Thanks for testing!
