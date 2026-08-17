# What's New Since Build 40 (Mac)

The headline is **Semantic Analytics** — a map of the whole series arranged by how documents are written rather than by who cites whom. It is entirely new: none of it existed in build 40. The analytics surfaces also stop borrowing each other's windows, and Settings finally has a search field.

**First launch re-indexes every volume you have downloaded, and it is not quick.** The date index moved (36 → 40) and person rollups moved with it, and a date-version change forces a full clean re-parse of the XML. The app stays usable while it runs, but Search results, dates and person analytics are incomplete until it finishes.

The app downloads a small extra file per volume for the semantic features (about 287 KB each). That is on by default and can be turned off — Settings ▸ Volumes & Storage ▸ **Semantic Vectors**.

## Semantic Analytics (new)

Its own window: the **Analytics** menu, or the toolbar's analytics menu in the main window. Every document in the published series is placed on one map by the shape of its language, so documents that read alike land near each other whether or not they share a volume, a date or a citation.

- **Regions** are groups the corpus fell into on its own, named by their most distinctive words. Click one for its size and era mix, or **Save as Working Corpus** to keep it and scope a search to it.
- **Slices** are the opposite move: click two documents in *different* volumes as poles and the whole series lays out along the contrast you named, with time up the side.
- **Lasso** an area to keep everything inside it as a working corpus.
- **Colour by** region, era, what you have downloaded, or archival provenance. Scope the map to a subseries, a topic or a president's volumes. ⌘+ / ⌘− / ⌘0 zoom; the map exports its regions as data.

Two honest limits, both stated on screen. The layout preserves *local* similarity — near neighbours mean something, the distance between two far-apart regions does not. And a region's name comes from a sample of its documents, so read it as a hint rather than a claim about every document in it.

## From a document, and back out again (new)

Open any document ▸ Research rail ▸ **On the Map**. The map opens with that document selected and the view brought to it, and its card lists the **ten documents whose language is nearest**. Click one to travel there.

That list is drawn only from volumes you have downloaded, even though the map draws all 552 — it says so under the list. If the document's own volume is not on the device there is nothing to compare against at all, and it says that too.

## Semantic matches in Related Documents (new, and off)

Related Documents ▸ **Adjust weights** ▸ raise *Semantically similar*. It finds documents on the same subject even when they share no words, citations or archive. It ships at zero because **its accuracy on nineteenth-century material has not been established** — a real unknown, not modesty. Right-click a match to say whether it helped.

## Archives: two additions to what you already have

Source Explorer now shows **where the editors pointed outside the printed record** — the footnotes that send you to a file FRUS did not print — on both a document's sources and a collection's detail. And Archival Analytics ▸ Collections gains **Unprinted pointers** as a third way to rank, beside documents and volumes. It measures something different: where readers were *sent*, not where documents came *from*. The three are never added together, and the screen says so.

## Windows and menus

Six analytics surfaces now open in their own windows and are **raised** rather than re-created when already open. Two documents can hold **two cross-reference graphs** at once instead of one window teleporting between them. The **Search** window gets a proper titlebar, and its filters become a row of tokens you can remove individually. **Settings has a search field**. The Research Guide gains a door from Research. ⌘P prints the document you are reading.

## Things that drew correctly and did nothing

Several sheets could not be closed. The analytics mode picker read "Col… Net… Flo… You…". Onboarding's **Skip** was a dead end. A filter section that was open when its data reloaded sat empty instead of asking again. A chip on the archival dock did nothing, and a title bar said its name twice.

## Smaller things

About thirty explanatory passages were rewritten more plainly — no stated limit was softened. The heat matrix shows its numbers. A count that said "1 volumes" no longer does. The frame-rate readout that used to sit over the map is gone from release builds.

## What to test

1. Let the re-index finish. Roughly how long, and how many volumes?
2. Open **Semantic Analytics** and move around. Pan, zoom, and switch lenses — anything that stutters or draws wrong.
3. From a document, **On the Map** — then do it again from a *second* document without closing the map. Both should select their document and travel to it.
4. Read the **ten nearest documents** for a few anchors. Are they useful research leads, or plausible noise? This matters more than anything else here: we have no measurement that can answer it.
5. Click two documents in the **same volume** as poles. It should explain why it cannot make an axis rather than doing nothing.
6. **Colour by ▸ Era** — can you tell the four bands apart, and do they read as ordered early-to-late? Region names should sit on their clusters at every zoom.
7. Save a region as a **working corpus**, then scope a search to it.
8. Raise the **Semantically similar** weight and judge a few matches, especially pre-1900. Right-click to record a verdict.
9. Open two documents and a graph for each; then open several analytics windows and re-invoke them from the menu — each should raise, not duplicate.
10. In Archival Analytics ▸ Collections, switch to **Unprinted pointers**. Does the ranking change in a way that makes sense, and is it clear why it is not comparable to the other two?

Include macOS version, what you clicked, what you expected, what happened. Thanks for testing!
