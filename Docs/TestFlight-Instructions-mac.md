# What's New in Build 33 (Mac)

Build 33 is about finding the *next* document: a new **Related Documents** window ranks what to read next by archival provenance, cross-references, dates, and shared people — with tunable weights; **Custom Volume Scopes** let you name a set of volumes once and reuse it across Search, Analytics, and Word Clouds; the volume subject profiles from build 32 become **detected-topic filters** (experimental); Source Explorer now shows the **HMS/MLR entry numbers** NARA staff actually ask for; the cross-reference graph gains scroll-wheel zoom and node context menus; and window management got a reliability pass. No re-index this build — everything works on your existing library.

## Related Documents
From any document, the Research strip's **Related** button opens a ranked list of documents related to the one you're reading — in its own window, so it works as a reading list.
- **Five signals** — **Archival provenance** (same lot file, decimal file, or collection), **Cross-references** (cites / cited by), **Close in date**, **Same volume or subseries**, and **Shared people**. Each row carries small **"why related" icon chips** showing which signals matched, strongest first.
- **A work list, not a dead end** — clicking a row opens the document in the main window while the Related Documents window stays open beside it, so you can step through the results. The window restores across relaunch, tuning and all.
- **Scope picker** — **This volume / This subseries / All volumes**; a scoped empty result invites widening rather than pretending there's nothing.
- **Adjust weights** — a disclosure of per-signal sliders; move one and the list re-ranks when you let go. Your tuning persists for the next document. A sixth slider, **Shared topics**, is visible but disabled — it activates when detected-topic document data ships.

## Custom Volume Scopes
Named, reusable volume sets — build "Cuban Missile Crisis volumes" or "Everything Kennedy" once, use it everywhere. They sync via iCloud, so scopes made on iPhone or iPad appear here too.
- **Manage** — **Settings → Research → Volume Scopes**: create with **New Scope**, edit or delete from a scope's row. A scope may include volumes you haven't downloaded — each row shows **"N of M volumes indexed"** so that's never a surprise.
- **The editor** — the whole series grouped by subseries with per-group **Add All / Remove All**, a title filter, and an **Add Volumes By…** menu with four facets: **Subject…** (detected topics), **Person…**, **Manifest Tag…**, and **Coverage Years / Editor…**. Facets always add volumes, never remove them.
- **Word cloud** — a scope row can launch a **Word Cloud** of everything in the scope (disabled until at least one member is indexed); the window opens directly and comes to the front even when relaunched.
- **Apply in Search** — the search filters gain a **My Volume Scopes** section: applying a scope fills the volume picker with its *indexed* members ("N of M volumes indexed"). If none are indexed yet, it warns and applies nothing — a scope never silently falls through to a whole-corpus search.
- **Apply in Analytics** — the Corpus, Person, and Cross-Reference Analytics scope menus add **My Volume Scopes** with honest "N of M indexed" counts (zero-indexed entries are disabled with "none indexed yet"), as does the Word Cloud scope menu. The **About the Series** dashboards can scope to one too — there at manifest grain, so undownloaded members count.

## Detected-Topic Filters (experimental)
The per-volume "Top subjects" profiles from build 32 become filters. These are **automatically detected topics, not editorial subject headings** — expect the occasional mistag, and tell us about the ones you find.
- **Search** — a **By Subject · Detected Topics** section with **Filter by detected topic…**: pick a category, optionally drill into a sub-category, and the volume picker fills with the indexed matches (same warn-and-refuse guard as scopes).
- **Analytics & Word Cloud** — the same scope menus gain a **By Detected Topic** submenu ("Detected topics — experimental"), including the About the Series dashboards.
- **Subjects (this volume)** — the document research panel gains a **Subjects (this volume)** disclosure: the volume's characteristic detected topics as chips; clicking one lists the other volumes covering that subject. Volume-level, and labeled as such.
- **Cleaner profiles** — an era-sanity pass removed 14 anachronistic subject-volume pairings (AIDS no longer appears on a 1964–68 volume).

## Source Explorer
- **The identifier NARA actually asks for** — resolved archival collections now show the **File Series** name and the **HMS/MLR Entry** number(s) — the identifier archives staff use to locate a series when you request original records. A note explains how to cite it alongside the lot number. Cross-volume provenance rows carry the same.
- **Honest unresolved** — a class of lot files that used to resolve to *wrong* NARA links (presidential-library staff files caught by an over-eager fallback) is now treated as unresolved and routed to live lookup instead.

## People & Cross-Reference Graph
- **Scroll-wheel zoom** — the graph zooms under the pointer with the scroll wheel or trackpad, alongside the existing pinch and drag.
- **Node context menus** — right-click a node for **Recenter Graph**, **Open in Main Window**, and **Archival Neighbors…** (find other documents drawn from the same archival source).
- **Subject affinity** — a person's detail sheet gains **Subjects** chips: the detected topics characteristic of the volumes where that person is mentioned (volume-level, weighted — not per-document tags). Clicking one pivots to all volumes covering that subject.

## Windows
- **Focus, don't bury** — launching a tool (Search, Source Explorer, graph, word cloud…) whose window is already open brings that window to the front instead of leaving it buried.
- **Reliable restore** — Source Explorer, cross-reference graph, Archival Neighbors, and Related Documents windows are self-describing and come back correctly across relaunch.

## Zotero
- **Connect** — **Settings → Integrations → Zotero**: click **Create a Zotero API key** (opens zotero.org with the right permissions pre-selected), paste the key, and **Connect**. The key is verified, your library resolved automatically, and stored in the Keychain.
- **Send documents** — once connected, the Research strip's Share popover gains **Send to Zotero Library**, sending the citation with your tags and research notes attached (Zotero-importable BibTeX/RIS file export remains alongside).
- **Send collections** — the Collections export screen has a **Send to Zotero Library** row that sends every document in the collection, with editorial notes flagged correctly.

## Fixes
- **Cross-reference toolbar** — the document toolbar's cross-reference controls now use distinct icons instead of near-identical glyphs.
- **Search** — facet warnings are always visible (they no longer vanished when you had no saved scopes).
- **Collections** — a collection's context menu gains **Duplicate**.
- **Browse** — hand-offs into the main browser (from graphs, lists, and windows) are no longer occasionally dropped.

## Feedback
This build's stress tests: open **Related Documents** on documents you know well — do the top results make archival sense? Play with **Adjust weights** and the scope picker and tell us where the ranking misleads, and whether the window's stay-open-and-step-through flow works for you. Build a **Volume Scope** and apply it in Search and Analytics — is the "N of M indexed" honesty right, and does the refusal-when-nothing-indexed behave? Try the **detected-topic filters** and report useful finds *and* mistags (they're expected — we want examples). And if you request records from NARA, check the **HMS/MLR Entry** numbers against what the archives expect. Include your macOS version, volume/document number, what you clicked, expected, and got. Screenshots and crash reports help. Thanks for testing!
