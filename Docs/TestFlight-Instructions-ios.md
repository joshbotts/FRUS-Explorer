# What's New in Build 33 (iOS)

Build 33 is about finding the *next* document: a new **Related Documents** list ranks what to read next by archival provenance, cross-references, dates, and shared people — with tunable weights; **Custom Volume Scopes** let you name a set of volumes once and reuse it across Search, Analytics, and Word Clouds; the volume subject profiles from build 32 become **detected-topic filters** (experimental); Source Explorer now shows the **HMS/MLR entry numbers** NARA staff actually ask for; and iPad windows got a reliability pass. No re-index this build — everything works on your existing library.

## Related Documents
From any document, the toolbar's **Related Documents** button opens a ranked list of documents related to the one you're reading.
- **Five signals** — **Archival provenance** (same lot file, decimal file, or collection), **Cross-references** (cites / cited by), **Close in date**, **Same volume or subseries**, and **Shared people**. Each row carries small **"why related" icon chips** showing which signals matched, strongest first.
- **Scope picker** — **This volume / This subseries / All volumes**; a scoped empty result invites widening rather than pretending there's nothing.
- **Adjust weights** — a disclosure of per-signal sliders; move one and the list re-ranks when you let go. Your tuning persists for the next document. A sixth slider, **Shared topics**, is visible but disabled — it activates when detected-topic document data ships.
- **Presentation** — a sheet on iPhone (and iPads without Stage Manager); on **iPad with Stage Manager** it opens as a real window that stays open beside the document as you jump to results, and restores across relaunch.

## Custom Volume Scopes
Named, reusable volume sets — build "Cuban Missile Crisis volumes" or "Everything Kennedy" once, use it everywhere. They sync via iCloud.
- **Manage** — **Settings → Research → Volume Scopes**: create with **New Scope**, tap a scope to edit, swipe to delete. A scope may include volumes you haven't downloaded — each row shows **"N of M volumes indexed"** so that's never a surprise.
- **The editor** — the whole series grouped by subseries with per-group **Add All / Remove All**, a title filter, and an **Add Volumes By…** menu with four facets: **Subject…** (detected topics), **Person…**, **Manifest Tag…**, and **Coverage Years / Editor…**. Facets always add volumes, never remove them.
- **Word cloud** — long-press a scope row for a **Word Cloud** of everything in the scope (disabled until at least one member is indexed).
- **Apply in Search** — the search filters gain a **My Volume Scopes** section: tapping a scope fills the volume picker with its *indexed* members ("N of M volumes indexed"). If none are indexed yet, it warns and applies nothing — a scope never silently falls through to a whole-corpus search.
- **Apply in Analytics** — the Corpus, Person, and Cross-Reference Analytics scope menus add **My Volume Scopes** with honest "N of M indexed" counts (zero-indexed entries are disabled with "none indexed yet"), as does the Word Cloud scope menu. The **About the Series** dashboards can scope to one too — there at manifest grain, so undownloaded members count.

## Detected-Topic Filters (experimental)
The per-volume "Top subjects" profiles from build 32 become filters. These are **automatically detected topics, not editorial subject headings** — expect the occasional mistag, and tell us about the ones you find.
- **Search** — a **By Subject · Detected Topics** section with **Filter by detected topic…**: pick a category, optionally drill into a sub-category, and the volume picker fills with the indexed matches (same warn-and-refuse guard as scopes).
- **Analytics & Word Cloud** — the same scope menus gain a **By Detected Topic** submenu ("Detected topics — experimental"), including the About the Series dashboards.
- **Subjects (this volume)** — the research panel below a document gains a **Subjects (this volume)** disclosure: the volume's characteristic detected topics as chips; tapping one lists the other volumes covering that subject. Volume-level, and labeled as such.
- **Cleaner profiles** — an era-sanity pass removed 14 anachronistic subject-volume pairings (AIDS no longer appears on a 1964–68 volume).

## Source Explorer
- **The identifier NARA actually asks for** — resolved archival collections now show the **File Series** name and the **HMS/MLR Entry** number(s) — the identifier archives staff use to locate a series when you request original records. A note explains how to cite it alongside the lot number. Cross-volume provenance rows carry the same.
- **Honest unresolved** — a class of lot files that used to resolve to *wrong* NARA links (presidential-library staff files caught by an over-eager fallback) is now treated as unresolved and routed to live lookup instead.

## People
- **Subject affinity** — a person's detail sheet gains **Subjects** chips: the detected topics characteristic of the volumes where that person is mentioned (volume-level, weighted — not per-document tags). Tapping one pivots to all volumes covering that subject.

## iPad Windows
- **Archival Neighbors is a real window** — under Stage Manager it opens beside the document and stays open as you navigate, like the graph and Source Explorer.
- **Windows keep their own tab** — each window remembers its own tab selection; switching tabs in one window no longer mirrors into another, and hand-offs bring the right tab forward in one window only.
- **Reliable restore** — Source Explorer, cross-reference graph, Archival Neighbors, and Related Documents windows are self-describing and come back correctly across relaunch.

## Zotero
- **Connect** — **Settings → Integrations → Zotero**: tap **Create a Zotero API key** (opens zotero.org with the right permissions pre-selected), paste the key, and **Connect**. The key is verified, your library resolved automatically, and stored in the Keychain.
- **Send documents** — once connected, the Research rail's **Share** menu gains **Send to Zotero Library…**, sending the citation with your tags and research notes attached. This is the only way to get FRUS annotations into Zotero on iPhone and iPad.
- **Send collections** — the Collections export screen has a **Send to Zotero Library** row that sends every document in the collection, with editorial notes flagged correctly.

## Fixes
- **Search** — sorting results by date now orders correctly, and facet warnings are always visible (they no longer vanished when you had no saved scopes).
- **Collections** — a collection's context menu gains **Duplicate**.
- **Research tab** — simpler push navigation throughout; no more split-view dead ends.
- **Browse** — hand-offs into Browse (from graphs, lists, and windows) are no longer occasionally dropped.

## Feedback
This build's stress tests: open **Related Documents** on documents you know well — do the top results make archival sense? Play with **Adjust weights** and the scope picker and tell us where the ranking misleads. Build a **Volume Scope** and apply it in Search and Analytics — is the "N of M indexed" honesty right, and does the refusal-when-nothing-indexed behave? Try the **detected-topic filters** and report useful finds *and* mistags (they're expected — we want examples). And if you request records from NARA, check the **HMS/MLR Entry** numbers against what the archives expect. Include your device + iOS version, volume/document number, what you tapped, expected, and got. Screenshots help. Thanks for testing!
