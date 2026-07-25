# What's New in Build 33 (iOS)

Build 33 **redesigns the document reading experience** and adds tools for finding the *next* document. No re-index this build — everything works on your existing library.

## The Research rail (redesigned)
Everything you do *with* a document — cite, summarize, note, tag, highlight, collect, and explore its sources, cross-references, and related documents — now lives in one place. The old row of a dozen toolbar buttons is gone; a single **Research-panel button** (top right) shows or hides a trailing **Research rail**.

- **iPhone:** the rail rises as a **bottom sheet** (drag it to size, swipe to dismiss).
- **iPad:** the rail is a **side panel** beside the document.
- **Inside the rail:** a tile grid — **Cite · Word Cloud · Sources · Graph · Related · Share** — over expandable **Summary · Notes · Tags · Collections** sections. On iPad the rail header also has an **Open in New Window** button for Stage Manager.

## The floating selection bar
**Select any text** in a document and a small bar appears at the selection: four **colour dots** (tap one to highlight the passage), **Excerpt** (save the selection into a collection), **Look Up** (NARA catalog), and **Note**. Highlighting no longer needs a separate mode or a colour-picker sheet.

## Read mode
Hide the rail for distraction-free reading. In Read mode, **tap near the left or right edge** to turn to the previous/next document in the volume, ebook-style. Choose how documents open — **Read / Research / Remember last** — in **Settings → Reading**.

## Finding the next document
- **Related Documents** — the rail's **Related** tile ranks what to read next by **archival provenance, cross-references, date, and shared people**, with tunable **weight sliders** and a **This volume / This subseries / All volumes** scope. "Why related" icon chips show which signals matched.
- **Custom Volume Scopes** — name a set of volumes once (**Settings → Research → Volume Scopes**) and reuse it in Search, Analytics, and Word Clouds. Every row shows **"N of M volumes indexed"** so undownloaded members are never a surprise; a scope with nothing indexed warns rather than silently searching the whole corpus.
- **Detected-topic filters (experimental)** — each volume's **Top subjects** become filters in Search and Analytics. These are **automatically detected, not editorial headings** — expect the occasional mistag and tell us.
- **Source Explorer** — resolved collections now show the **HMS/MLR Entry** number NARA staff ask for when you request original records.
- **People** — a person's detail sheet gains **Subjects** chips (the detected topics of the volumes where they're mentioned).
- **Zotero** — connect in **Settings → Integrations**, then the rail's **Share** menu can send a document (with your tags and notes) to your library.
- **Analytics exports** — charts now leave the app as **Chart data (CSV)**, **Figure (PNG)**, or **Figure (PDF)** through the **share sheet**: an **Export** menu in **Corpus Analytics** (iPad toolbar; on iPhone under **Export** in the **Options (…)** menu), a per-section **Export** button in **Person** and **Cross-Reference** Analytics, and **Options (…) → Export** on a word cloud. Try saving a figure *and* its CSV to Files, then check that the CSV's `#`-commented preamble describes the chart you were actually looking at — on **By Subseries** / **By Volume** the figure items are dimmed by design.

## Fixes
- **Research tab** — fixed a list that could briefly reorder/jump right after opening.
- **Search** — date sort and the facet warnings are corrected.
- **Collections** — a collection's context menu gains **Duplicate**.

## Feedback
The big one this build is the **reading redesign** — does the rail put things where you'd look for them, and is **Read mode** genuinely calmer? On iPhone, opening a rail tile (especially **Word Cloud**) should respond immediately. Then stress the **Related Documents** ranking and the **Volume Scopes**. Include your device + iOS version, the volume/document number, what you tapped, what you expected, and what happened. Screenshots help. Thanks for testing!
