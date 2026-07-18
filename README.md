# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

## Features

- Full-text search and filtering across the FRUS corpus (FTS5, English stemming, BM25 ranking), with a **volume/subseries scope** (platform-appropriate pickers; "Search this volume" handoff from the browser), grouped/Boolean query support, a front-matter inclusion toggle, and **user-tag filter chips** that refresh live as you create, rename, or delete tags anywhere in the app (on iOS/iPadOS **and the macOS Search window**). The results list also offers an **adjustable snippet length** (1–10 lines — a global default in Settings honored by both the main search list and the Collections add-documents sheet, each with its own per-surface override) and an optional **Checklist review mode** that hides each result as you open it or mark it reviewed, with a progress banner and an all-reviewed empty state — both available on iOS/iPadOS **and the macOS Search window**
- **WKWebView document renderer** (Sessions 140–147): documents rendered as HTML via `FRUSRenderNodeHTMLSerializer` inside `FRUSDocumentWebView`; native HTML Popover API for footnotes; CSS Custom Highlight API for passage highlights visible inline without entering a special mode
- TEI-rendered document view faithful to history.state.gov content and annotation
- **Research rail + floating selection bar** (the document reading redesign): a single trailing **Research rail** — toggled with `⌘⇧R`, presented as an iPad side panel, an iPhone bottom sheet, or a macOS trailing panel that overlays the reading column below ~900 pt — gathers each document's research into a tile grid (Cite · Word Cloud · Source Explorer · Cross-reference Graph · Related · Share) plus expandable Summary / Notes / Tags / Collections accordions. Selecting text raises a **floating selection bar** (four highlight-colour dots · Excerpt · Look Up in NARA · Note) on both platforms, so highlighting and annotation need no separate mode. Read mode (rail hidden) keeps the reading column distraction-free, with hover-revealed edge chevrons (macOS) or edge-tap zones (iOS) for previous/next document
- Structured date indexing from TEI `<date>` attributes; accurate date-range filtering
- Editorial note distinction: index and filter primary documents vs. editorial notes separately
- **Cross-corpus People browser**: a reconciled, corpus-wide index of everyone named across the FRUS series, reached from the top of the Browse screen. Per-volume TEI person entries are consolidated at index time into stable identities by a deterministic `PersonClusterer` (surname/initial blocking, variant folding, era/role guardrails, under-merge bias) and keyed to the Office of the Historian's CC0 people authority crosswalk where covered, so the same person spread across volumes under varying name forms collapses to one entry (e.g. "Kissinger, Henry A." → a single identity with its full mention count) while different people who share a name stay separate. Each row shows a `role · active years · N volumes` subtitle and an accurate mention count; the detail sheet drills into every `(volume, ref)` record, offers user **merge / separate** corrections — **"Merge with another person…"** from a person's detail sheet or row context menu, with a confirmation that names both people and warns when they look like genuinely different people, plus a **Corrections** toolbar button that lists every merge and separation you've made and can undo any of them, all CloudKit-synced — surfaces "possibly the same person" candidate suggestions, links reconciled identities to **VIAF** where an authority id is present, and hands off to a person-scoped search via **Find all mentions**
- Persons and terms glossaries persisted to SQLite; live autocomplete person picker
- Accurate footnote numbers from TEI `@n` attributes (matching printed volume numbering)
- Cross-reference graph (Session 161 redesign) with a left-to-right **chronological timeline layout**, direction arrows, node size encoding connectedness, edge weights/labels, a date axis, a **synchronized reference list panel** (regular widths) or List/Graph segmented picker (iPhone), sparse-graph auto-expansion to 2°, a legend and info popover, 1°/2°/3° neighbourhood expansion, and a node context menu (Recenter Graph / Open in Main Window / **Archival Neighbors**)
- **Corpus Chronology** browser: pick a date range and read every indexed document within it, grouped into auto-coarsening day/month/year sections, with per-document date precision and certainty (from TEI `<date>` attributes), a range-anchored stacked distribution chart whose colour-coded volume count is configurable (6–12, default 8) per-view and via a global Display default, a **"Word Cloud for this range"** action that builds a date-range word cloud from the documents displayed, a "spans this period" section for wide-span editorial notes, an "extends beyond this range" overflow section for uncertain dates, and a macOS hover magnifier for finer slices
- **Index Health** (Settings): merged index version, status, and an integrity check across the FTS5 store. **Page-number cross-references** (e.g. "see p. 427") now resolve to the correct document in the cross-reference graph and Cross-Reference Analytics; this required an **index-version bump to 21**, so updating the app triggers a **one-time re-index** of already-downloaded volumes
- **Unresolvable cross-references** rendered honestly: references that a corpus-wide validation dataset confirms cannot be followed (the printed volume cites a page, document, or volume that does not exist in the digital corpus) appear in muted grey with a dotted underline and a small dagger marker instead of posing as working links — tapping one opens an **Unresolved Reference** sheet explaining why it can't be followed and the apparent destination; Cross-Reference Analytics discloses "N unresolvable references are excluded from this analysis" whenever any fall in the current scope; and a **Broken Cross-References Report** (CSV or JSON — the corpus-wide list, for reporting to the Office of the Historian) exports from iOS Settings → Export Research Data or the macOS Settings → Data pane. The bundled validation index arrives with an **index-version bump to 22** — a one-time background re-index that also repairs a long-standing defect where some cross-volume page references resolved to the wrong document in graphs and analytics
- Document-level research notes, user tagging, and **inline text highlights** (CSS Custom Highlight API; four colors; stored offsets survive document re-renders via rendering-version hash; visible without a separate highlight mode); highlights are annotated inline across all three collection-export formats (HTML `<mark>`, PDF background shading, DOCX `<w:highlight>` runs)
- **Citation tools**: a citation control focused on the reference itself (formatted citation, copy citation / URL / BibTeX / RIS) plus a dedicated, peer-level **Share / Export control** (the Research rail's **Share** menu on both platforms) that gathers the "send this document somewhere" actions — **Send to Zotero Library** (Web API), export a Zotero-importable file (RIS/BibTeX), and **Share Citation** (the formatted citation and canonical history.state.gov URL combined into one shareable message)
- **Reading history**: every document visited and every search executed is recorded; macOS adds a **History** menu (last ten of each, with quick re-open/re-run) and a standalone **Complete History** window with an optional project filter
- **Embedded in-app browser** for Markdown links throughout onboarding, About, and education content, plus a standalone **FRUS Research Guide** (Settings entry on iOS; dedicated window + Help-menu command on macOS) with contextual deep-links from Source Explorer and NARA Catalog Lookup
- **iOS/iPadOS Read-mode page-turning**: invisible edge-tap zones in the document view open the previous/next document in the volume, ebook-reader style, without leaving Read mode or using the back button
- **Search ↔ Corpus Analytics handoff**: jump from an Analytics chart to Search pre-filled with the term and year-range as a date filter ("View in Search"), or from any Search that returns results to Analytics pre-seeded with the same keywords and date filter ("Visualize in Corpus Analytics") to chart the distribution; capped result sets still add guidance to narrow the range
- **Research window / tab**: browse all annotated documents organized by user tag (document count descending) with highlight excerpts shown inline as colored strips; macOS `⌘⌥R` shortcut; iOS Research tab (third tab); "By Highlight Color" sidebar section for color-coded research workflows
- AI summarization via Apple Intelligence (FoundationModels framework); long documents are handled by a **hierarchical map→reduce** pipeline (token-budgeted chunking with sentence-level hard-splitting, then a recursive synthesis that keeps every model call inside the on-device context window for a document of any length)
- **Background bulk summarization** (opt-in): queue an entire subseries, volume, user tag, saved search, date range, or one of your saved volume scopes (My Volume Scopes) to summarize unattended; runs conservatively in the background (iOS `BGProcessingTask`) and reports progress through the shared Live Activity / Settings contract
- User-configurable summarization prompts with structured output support
- Citation formatter (history.state.gov recommended style)
- Citation lookup: resolve citations encountered in publications to FRUS documents (⌘⇧F on macOS, Find by Citation button in the macOS search window); the macOS sheet is a grouped form (Return runs the lookup) and opens a result in its **own document window** — with working previous/next navigation — so the match list stays visible, and document-number citations now resolve reliably on indexed volumes
- **NARA Source Explorer** (Sessions 23, 130, 150, Central Files Phases 1–3, + the Source Explorer Provenance program Phases 1–5): source notes extracted for **every era of the series** — including the ~77,000 modern documents (1955–1991) whose head-nested notes earlier extraction missed entirely — parsed by the shared `SourceNoteKit` grammar (era-aware, eval-tested against a 267k-note corpus) with **classification markings** ("Secret; Nodis") split out and shown as **chips** in Source Explorer, the reading view's source footnote, and search rows; lot files resolved via `variantControlNumber_is` NARA Catalog API query (with a bundled key-less lot-file index covering RG-verified records); State Dept. decimal files routed to period-specific NARA finding-aid pages (1910–1963, 7 periods); **pre-1910 Central Files resolved from a bundled index** — 1906–1910 Numerical File citations to digitized rolls, and pre-1906 country-arranged diplomatic series — with no API key required; presidential library citations route to institution-specific finding-aid sites on zero API results; CIA records linked to CIA CREST database; the Word Cloud, Chronology, and Source Explorer each carry an info popover explaining the view, matching Corpus Analytics and the cross-reference graph
- **Archival Neighbors**: surfaces other indexed documents that share a document's original archival source — lot file, central decimal file, record-group series, or presidential-library collection — matched on **normalized keys written at index time** (compact lot forms, decimal classes) so matching is dumb-and-indexed at display time. The affordance is **three-state and honest**: no key (unrecognized entry), keyed with an explicit **0** ("no documents in your indexed volumes cite this" — never "we failed to parse it"), or a count badge. Reachable from the Source Explorer ("Documents from This Collection") **and** as an **Archival Neighbors** action on cross-reference graph nodes, search results, browser document lists, and the volume sources list (one shared `IndexingPipeline.archivalNeighbors` query + presentation); on macOS it opens as a **dedicated window per archival source**, restorable and side-by-side capable. A **scope selector** (This volume / This subseries / All indexed volumes, with per-trigger defaults) narrows or widens the list, and the two neighbor code paths are reconciled so the same source at the same scope returns the same set of *other* documents whichever surface opened it
- **Volume-level source provenance**: a volume's front-matter Sources section is resolved offline to NARA Catalog records via a bundled `volume-sources-index` (record-group headers and lot files harvested by the `VolumeSourcesIndexGenerator` SPM tool), with context (record group, repository, library) **inherited down the outline tree** and bibliography entries split into a separate Published Sources section. The `VolumeSourcesView` shows a **NARA Catalog link** and a batched per-entry **neighbor count** on each resolved collection, and a **"Cited in N volumes"** cross-volume provenance sheet on major collections cited by more than one volume (schema-v2 artifact: resolution maps + authority, ~1.3 MB, no per-volume trees). Resolved collections now also display the archival **file series name** and the **HMS/MLR entry number(s)** — the identifier NARA staff ask researchers to quote when requesting original records — in Source Explorer, the volume sources list, and cross-volume provenance rows; and a measured-bad class of lot resolutions (presidential-library staff files mis-matched by a removed fallback) is now treated as unresolved and routed to live NARA lookup instead of showing a wrong link
- **Cross-volume collection authority**: a bundled `collection-authority.json` (regenerated by the `CollectionAuthorityGenerator` SPM tool) clusters the **~4,400 archival collections** FRUS editors cite corpus-wide — canonical name, ~5,400 variant citation forms, sub-series, NARA NAIDs resolved 100% offline (939 records), and every citing volume (100% of lot-keyed front-matter items land in a record). The app surfaces it as **Browse Archival Collections** (searchable, repository-grouped) and a per-collection **Collection view** distinguishing series-wide citing volumes (bundled) from **In Your Library** counts (always computed from your own index)
- **Collections** — a two-part workflow: the **manager** is the editorial place (assemble content + composition) and **export** is purely sharing (format + destination). A collection is an ordered mix of **documents, section headings, and rich-text prose blocks** (bold/italic/underline/colour applied from a **visible formatting toolbar** on a native editor — an SF Symbols bar above each macOS editor, a keyboard accessory toolbar on iOS — persisted as RTF, plus a **Link** control that turns selected text into a hyperlink: a real `<a href>` in HTML and `<w:hyperlink>` in DOCX, underlined text with the visible URL in parentheses in PDF). Section headings **nest up to three levels** (indent/outdent from the heading's context menu; dragging a heading moves its **whole section as one block**; per-heading collapse chevrons are a display convenience only), and a collection carries optional **front matter** — a title-page **subtitle** and **author line**, a rich-text **introduction** opening the body, and an opt-in **colophon**. Composition is persisted on the collection — default body depth (full / summary-only / index), independent include-footnotes and include-source-note toggles, table-of-contents label style, apply-highlights, include-notes, include-word-cloud, summary prompt, and a collection-level **headnote** default — with **per-entry and per-section body-depth overrides** cascading entry → section → collection default. Four **one-tap presets** (Teaching reader / Briefing packet / Source dossier / Scholarly edition) set the whole composition at once — appending any apparatus blocks they call for, non-destructively. Document rows are **pure reports** — identity plus read-only status chips (body depth, note count, override flags); all per-document editing routes to the shared **entry inspector** — opened by tapping (iPad/iOS) or single-clicking (macOS, when already open) anywhere on a document row via its **⚙ Configure** control, now **document-only** (collection-wide settings live in the separate **⚙ Collection** surface, not repeated in the inspector) — which surfaces per-document data (research notes, highlights, tags, AI summary, archival source note, cross-reference count) *and* owns the export controls: the body-depth override, per-note include toggles (**empty = all notes**, mirroring per-highlight selection), an **editable Key-takeaway headnote** (Generate / Edit / Regenerate, with an AI-draft / AI-edited / yours provenance chip that governs whether the export carries the Apple Intelligence attribution), and the Default/On/Off overrides. On macOS the inspector is a trailing dismissible `.inspector` column; on iPad the per-document settings open as a **sheet**; on iPhone as a **pushed screen**. Collection-wide settings live in a **⚙ Collection popover** (macOS) / **sheet** (iPad) / **Collection settings drill-in** (iPhone). Document header (from indexed TEI `document_cache`) shown per row; per-entry delete and inline date sort stay on the row. **Generated apparatus blocks** — Bibliography, Chronology, Sources & Archives (NARA-linked), Persons Index (People-browser rollup identities), and Thematic Index (user tags) — are placeable entries computed from the collection's documents at every export and in the live preview (only the block *type* is stored or shared; rows re-resolve against each device's own index). A collection's name, note, front matter, and composition are edited in one place — the **⚙ Collection popover** (macOS) / **sheet** (iPad) / **Collection settings screen** (iPhone). On macOS the manager has **no sidebar**: a **toolbar collection picker** (switch / New / Import / Manage) heads a single **Contents** outline beside a default-on **live preview**, and the authoring verbs live in the toolbar — **＋ Add** (Documents / Section Heading / Note Block / Passages / an Apparatus submenu — the Documents picker's Search tab shows per-result **snippet previews** and the archival source note so you can judge a match before adding), **Sort**, **⚙ Collection**, **Export…**, and a **Document-inspector** toggle. **Sort by Date offers two modes** on the toolbar (all platforms) — **"Across the Whole Collection"** (a single global chronological sort) versus **"Within Each Section"** (documents sort by date inside each heading's section, never crossing a heading). The **export sheet** leads with a one-line, plain-language **composition summary** ("Exports an AI summary of each document, with headnotes, your notes, and a word-cloud overview"), then a **2×3 grid of format cards** (PDF · HTML · Word · BibTeX · RIS · .fruscollection) and a separate **Send to Zotero Library** row, so the render is confirmable before sharing
- **Collection export formats**: PDF, HTML, and DOCX (all render section headings and rich prose, with highlights annotated inline — HTML `<mark>`, PDF background shading, DOCX `<w:highlight>` runs — and every exported AI-generated summary or headnote labeled with an **"AI-generated summary · Apple Intelligence (on-device)"** attribution caption, in the live preview too), a **BibTeX** file, a **Zotero RIS** file, and a native **`.fruscollection`** format — a round-trippable JSON file that shares an *editable* copy of the collection (references + composition + structure + prose; documents travel as portable `volumeId`/`documentId`; opt-in "Include my research notes" toggle, default off). The file is versioned for compatibility: a collection using no newer features (nested sections, front matter) is still written as the original v1 format, so older app versions open it unchanged. Open a `.fruscollection` with the in-app **Import Collection** button or by double-click / share-to-app / AirDrop (missing volumes can be downloaded on the spot). A **smart collection** (driven by a saved search) can be materialised into a static, editable collection with **Create Static Snapshot**
- **Four analytics surfaces** — Corpus term-frequency, **Person**, **Cross-Reference**, and offline **Series** dashboards — cover the corpus from complementary angles (described in the four bullets that follow); Corpus, Person, and Cross-Reference share a **subseries/volume scope** and **year-range** bar so any of them can be narrowed to a project-specific slice (Corpus and Cross-Reference Analytics add an **Administration** preset menu that sets the document-year range to a president's term in one tap); **Person and Cross-Reference Analytics group their charts into collapsible sections** with each chart's controls in its own section, and on iPhone Corpus Analytics folds its secondary toolbar controls into an **Options** menu to fit the compact width
- Corpus Analytics: corpus-wide term frequency histograms (Swift Charts) with Decade / Year / Month / Day / Subseries / **By Volume** granularity, optional linear regression fit line, year-range filter, drill-in from a subseries/volume bar to a scoped search, and metric explanation popover; a **"% of documents" normalization toggle** on the By-Year and By-Decade charts reads a term as a share of the corpus in that period rather than a raw count; the **By-Year / By-Decade charts colour-code each period by its top source volumes** (the colour-coded volume count is configurable, 6–12 with a default of 8, per-view and via a global Display default, with the remainder folded into "Other" plus a textual legend, like the Chronology graph); **shares a volume/subseries scope with Search** so a query can be charted and read against the same corpus subset
- **Word Cloud**: a frequency visualisation over any of nine scopes (document, volume, subseries, corpus, collection, user tag, saved search, **custom volume scope**, and a **date range**) shown as a packed spiral cloud (density-aware rotation) or an accessible ranked/weighted list; a date-range cloud is reached from Chronology's **"Word Cloud for this range"** action and offers a **"View in Chronology"** item to hand back to the same range (macOS also exposes a "Date Range" scope entry with inline start/end date pickers); device-local **Appearance** controls in Settings set the cloud's font (Rounded/Default/Serif/Monospaced) and density (Compact/Balanced/Airy), applied across the cloud, comparison columns, and image exports; **semantic lenses** narrow the cloud to People / Places / Organizations (on-device NaturalLanguage named-entity recognition), Topics / Actions / Descriptors (part-of-speech), or **Concepts / Sentiment** (bundled lexicons; sentiment is colour-coded by polarity); **tap a word to chart its frequency across the whole corpus in Corpus Analytics** (volume-, subseries-, and custom-scope clouds add an optional "analyze within this volume/subseries/scope" menu action, and "Search for this term" stays on the word's context menu); compare two scopes side by side; export PNG / PDF / CSV; hide a word **in all clouds, just the current lens, or just the current cloud** (the per-cloud hide is temporary — the word returns next time the cloud is generated — and "Show N hidden words" restores all of them), and a **Word Cloud settings pane** with custom global + per-lens stop lists and tunable criteria (minimum length/occurrences, plural folding, classification-marking and diplomatic-boilerplate filters); corpus/subseries results are precomputed in the background on iOS and cached on disk
- **Custom Volume Scopes**: named, reusable volume sets synced via iCloud, managed in Settings (iOS "Volume Scopes" section; macOS Volume Scopes pane) — create, edit, and delete scopes; the editor adds volumes by name search or through an **"Add Volumes By…"** facet menu (Subject, Person, Manifest Tag, Coverage Years / Editor — facet matches union into the selection, never removing volumes already picked), and each scope row offers a one-tap word cloud. Apply a scope anywhere volumes are scoped: the Search filters' **"My Volume Scopes"** section (applying seeds the volume picker with the scope's *indexed* members, showing "N of M volumes indexed" and warning when none are indexed yet), the Corpus / Person / Cross-Reference Analytics scope menus (zero-indexed scopes disabled), the Word Cloud scope menu, and the About the Series dashboards at manifest grain
- **Related Documents**: from any document (iOS toolbar **Related Documents** button; macOS Research-strip **Related** button), a ranked list of documents related by five signals — shared archival provenance (same lot file, decimal file, or collection), cross-references (cites / cited-by), proximity in date, same volume/subseries, and shared people — each row carrying "why related" icon chips, with a scope picker (This volume / This subseries / All volumes) and an **"Adjust weights"** panel of per-signal sliders whose tuning persists (a sixth signal, shared topics, is visible but disabled until document-level topic data ships). Presented as a sheet on iOS; on macOS and on iPad under Stage Manager it opens as a separate window that stays open while you jump to results and restores across relaunch
- **Series Analytics** — a new **"About the Series"** category in the in-app FRUS Research Guide with four **offline** dashboards that render with no index (they work mid-onboarding): (1) **Production & Timeliness** — a publication-lag scatter (publication year × years-to-publish) with an **evolving timeliness-target step line** (no target pre-1961, 15 years from the 1961 directive, 20 from 1972, 30 from the 1985 directive / 1991 statute), volumes-per-print-year bars, and a cumulative-volumes growth curve; (2) **Geographic Emphasis** — regional coverage share over time across the 6 State Dept regional bureaus (stacked), region totals, and top-covered countries; (3) **Archival Sourcing** — provenance mix over coverage decades (central decimal file → lot files + presidential libraries + Central Foreign Policy File), overall composition, and note density by decade; (4) **Administration Profiles** — per-**president** (Nixon and Ford distinct; Cleveland twice) documents per administration, volumes per administration-year coloured by party, coverage span, and a per-administration volume list showing each volume's document **proportion**, with an include/exclude editorial-notes toggle and an any-overlap attribution caveat. All four carry an **editable start/end year range** (defaults ~1861–1993 coverage / 1861–2026 production), a **Scope** control (**Whole series / By Subseries**, subseries nested in decade submenus), and a per-chart **"View as table"** pop-up (native Table on macOS/iPad, list on iPhone) with **Copy CSV**; Archival Sourcing adds a **Categories** filter that re-bases the mix to the shown archival categories (the last visible category cannot be hidden), Administration Profiles gains a year-range bar showing the administrations whose terms overlap the years, and **Reset clears scope and year range together**
- **Person Analytics** — a new surface (iOS Browse → Analysis Tools → "Person Analytics"; macOS `frus.personAnalytics` window) with a **Trends / Network** toggle: (Trends) most-mentioned people by era, a multi-person **mention-trajectory comparison** (search and pick up to 5 people), and a two-person **relationship-dynamics** chart (co-mention over time); (Network) a person **co-mention ego-network graph** (a focus person plus their top co-mentioned partners) — every view honours a shared **subseries/volume scope** and **year-range** filter
- **Cross-Reference Analytics** — a new surface (iOS Analysis Tools → "Cross-Reference Analytics"; macOS `frus.crossRefAnalytics` window): most-referenced documents by **in-degree**, a citation **degree-distribution histogram**, a **volume-to-volume citation heat matrix** over the top connected volumes, and offline **PageRank** "influence" landmark documents; a **subseries/volume scope** and **year-range** bar narrow the network with **source-anchored** counting (a citation is attributed to — and filtered by — its citing document's volume and date, so scoping never collapses the graph), and the document-level figures now include **same-volume citations** that were previously dropped (the heat matrix stays cross-volume by definition)
- **Zotero** — a single unified **Send to Zotero…** action: with a connected account (Settings → Zotero, Web API key; the connection syncs across devices via iCloud Keychain) it pushes a single document — or a whole collection — into your Zotero library over the Web API, carrying tags and research notes; without an account it falls back to an RIS file for desktop import (File → Import). The former split between a "Zotero RIS" export format and a separate "Send to Zotero Library" button is collapsed into this one menu
- CloudKit-synced user data (notes, tags, collections, projects, highlights) with live sync monitoring and proactive health checks: account status and private zone verification at launch and on foreground; macOS status bar surfaces zone-missing and not-signed-in warnings alongside the existing "Syncing…/Synced/Sync Error" states; iOS Settings shows the same diagnostics in the iCloud Sync section; a **Sync Diagnostics** view (iOS Settings → Data; macOS Settings → General) keeps a local, on-device, **redacted** log of iCloud sync events — event types, timing, and error codes only, never record/account identifiers or any synced content — that you can read and export to help diagnose sync problems
- **Optional cross-device settings sync**: a per-device toggle (Settings → iCloud Sync) that mirrors your word-cloud filters and stop lists, citation style, default document mode, and research-logging preference across devices through a CloudKit-backed record — off by default, so each device can keep its own settings if you prefer (device-specific preferences like download limits and Live Activity stay local)
- Offline functionality with download queue; volumes indexed automatically after download
- Live indexing progress (stage, document count, throughput) in the volume browser; document list loads automatically on completion without navigating away; macOS status bar shows a tappable queue popover with per-volume progress, combined ETA, and pending-volume list for multi-volume batches
- macOS Settings → Storage: per-category usage breakdown (volume XML / search index / AI summaries / total); indexing controls (Index Remaining, Reindex All, Delete & Rebuild) positioned above the volume list; per-volume reindex and remove controls; storage limit with pre-download gate and Manage Storage sheet showing LRU removal candidates
- Breadcrumb navigation trail in the volume browser (iPhone and macOS; on iPad the tab sidebar and back button navigate instead — Browse uses push navigation on all devices)
- Front matter sections (preface, introduction, errata) browsable directly from the corpus
- **Volume subject profiles**: every volume's detail view (both platforms) shows a **Top subjects** section — the subjects most characteristic of that volume, derived from the Office of the Historian's public-domain subject data, grouped by category and visible even before the volume is downloaded; tapping a subject lists the other FRUS volumes covering the same subject across the whole corpus (including undownloaded ones) and can navigate there (bundled `volume-subject-profiles-index.json`, regenerated by the `VolumeSubjectProfilesGenerator` SPM tool). These detected topics also act as **experimental filters** — explicitly framed as automatically detected topics, not editorial subject headings, so mistags are possible: Search gains a **"By Subject · Detected Topics"** facet (**"Filter by detected topic…"**, a two-level category → sub-category picker seeding the volume picker through the same indexed guard), the analytics scope bars, Word Cloud, and About the Series dashboards gain a **"By Detected Topic"** scope menu with honest "N of M indexed" counts, and the document research panel adds a **"Subjects (this volume)"** disclosure — the volume's characteristic topics as chips, tapping one listing the other volumes covering it. An era-sanity pass removed 14 anachronistic subject↔volume profile entries
- Accurate subseries grouping in the volume browser and manifest diff
- **iOS/iPadOS**: five-tab navigation — Browse, Search, Research, Collections, Settings; iPad adopts an adaptive sidebar (`.sidebarAdaptable`) and, under Stage Manager, opens documents and tools (cross-reference graph, Source Explorer, Archival Neighbors, Related Documents) in their own windows alongside a search-results list; each iPad window keeps its **own tab selection** (a tap in one window no longer mirrors into another, and hand-offs bring the right tab forward in one window only), and tool windows are self-describing value-based scenes that restore correctly across relaunch
- **iPad/Mac parity**: native window tabbing on macOS; "open search result in a new window/tab"; multi-window tool windows; capability-gated "Open in New Window" that falls back to in-place navigation where multi-window is unavailable; macOS tool launches focus an already-open window instead of leaving it buried behind others
- **macOS**: up to 7,500 ranked search results with true-total count, TEI-derived context snippets, date-sort by structured ISO date, and scope-aware column filtering; native Settings scene (⌘,); `.help()` tooltips on all icon-only controls and toolbar buttons; save/load searches in the macOS search window; chronological **Timeline** view in the Search window (toggled from the sort bar); compact `volumeId/documentId` toolbar title and 980×600 minimum window size so toolbar controls no longer collapse into the overflow chevron
- **Save & load searches**: bookmark any query + filters in the macOS search window; saved searches also drive smart collections that auto-populate at export time

## Requirements

- **Xcode 26.0+** (macOS 26 SDK required)
- **macOS 26.0+** (development machine)
- **Swift 6.0+** with strict concurrency enabled
- Apple Developer account with the following capabilities:
  - iCloud (CloudKit + iCloud Documents)
  - iCloud Keychain Sharing
  - App Sandbox

## Project Structure

```
FRUSExplorer/
├── FRUSExplorer.xcodeproj        Xcode project (iOS/iPadOS + macOS app targets)
├── project.yml                   XcodeGen spec — edit this, not the .xcodeproj directly
├── FRUSExplorer/                 Main app source
│   ├── App/                      Entry point, AppState, root views
│   ├── Browser/                  Corpus / subseries / volume browser views
│   ├── CrossReference/           Cross-reference graph, volume connection graph
│   ├── Collections/              Collection editor, PDF/HTML/DOCX exporters
│   ├── Research/                 Research window / tab (annotated documents by tag)
│   ├── Search/                   SearchService, IndexingPipeline, SearchView
│   ├── DocumentView/             Document display, research notes, cross-reference links
│   ├── Summarization/            Apple Intelligence integration, prompt management
│   ├── Analytics/                Corpus Analytics with Swift Charts
│   ├── Citation/                 Citation formatter, lookup engine, BibTeX/RIS export
│   ├── SourceExplorer/           NARA catalog integration
│   ├── Downloads/                DownloadManager, download queue UI
│   ├── Models/                   SwiftData models, manifest structs, supporting types
│   ├── Settings/                 macOS FRUSSettingsView + iOS SettingsView
│   ├── TEI/                      XML parser, AST types, renderer
│   ├── Onboarding/               Onboarding flow, education pages, Research Guide
│   ├── Resources/                Bundled data (manifest, tag taxonomy, offline indexes:
│   │                             sources, authorities, subject profiles, broken refs)
│   └── Localizable.strings       English base localisation
├── FRUSExplorerTests/            Unit tests (600+ tests, all passing)
├── FRUSExplorerUITests/          UI tests
├── ManifestGenerator/            SPM tool: generates manifest.json from FRUS GitHub
├── TaxonomyGenerator/            SPM tool: generates volume-tag-taxonomy.json
├── *Generator/ + *GeneratorCore/ Further SPM index generators (CentralFiles, PersonAuthority,
│                                 VolumeSources, CollectionAuthority, SourceProvenance,
│                                 AdministrationProfiles, CrossRefValidation, VolumeSubjectProfiles,
│                                 SourceExplorerExport)
├── SourceNoteKit/                Shared SPM library: source-note grammar
├── CrossRefKit/                  Shared SPM library: cross-reference target grammar
│                                 (parity-tested mirror of the app's resolver)
├── GeneratorKit/                 Shared SPM library: corpus enumeration for generators
├── Package.swift                 SPM manifest for command-line tools
├── FRUS-API.openapi.yaml         Living OpenAPI spec (future FRUS API)
└── Planning/                     Specification and development plan documents
```

## Building

### iOS / iPadOS

Select the **FRUSExplorer** scheme in Xcode. Build for any iOS/iPadOS simulator or device.

### macOS — App Store

Select the **FRUSExplorerMac** scheme with the **AppStore** build configuration.

### macOS — Direct Distribution

Select the **FRUSExplorerMac** scheme with the **DirectDistribution** build configuration.
This configuration:
- Uses `CODE_SIGN_STYLE: Manual` with Developer ID signing
- Is notarized and packaged into a DMG via `Scripts/notarize.sh`

> **Note:** Sparkle-based automatic updates were removed (see commit `4119700`) —
> Apple rejected the App Store submission with error 90296 ("App sandbox not
> enabled") because Sparkle's helper executables don't carry the
> `com.apple.security.app-sandbox` entitlement, and the App Store does not permit
> third-party auto-update mechanisms in any case. Because Xcode links Swift
> Package dependencies per-target rather than per-build-configuration, Sparkle
> could not be confined to DirectDistribution builds without splitting
> `FRUSExplorerMac` into two targets — a larger restructuring deferred for now.
> Direct Distribution users currently check for updates manually (e.g. by
> revisiting the distribution page); reintroducing in-app update checking would
> require that two-target split.

#### Release workflow (Direct Distribution)

**Prerequisites:**

1. Export credentials to your environment:
   ```sh
   export TEAM_ID=XXXXXXXXXX
   ```

2. Create a notarytool credential profile (one-time setup):
   ```sh
   xcrun notarytool store-credentials "FRUS-Notary" \
     --apple-id "your@email.com" \
     --team-id "$TEAM_ID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

3. Set `CODE_SIGN_IDENTITY` and `PROVISIONING_PROFILE_SPECIFIER` in `project.yml`
   (or pass them on the command line) matching your Developer ID certificate.

**Build, notarize, and package:**

```sh
# Full workflow (archive → export → notarize → staple → DMG):
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh

# Dry run to preview commands without executing them:
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh --dry-run

# With an explicit app bundle and custom notarytool profile:
TEAM_ID=XXXXXXXXXX ./Scripts/notarize.sh \
  --app-path build/export/FRUS\ Explorer.app \
  --profile MyNotaryProfile
```

The script produces:
- `build/FRUSExplorer.xcarchive` — Xcode archive
- `build/export/FRUS Explorer.app` — notarized, stapled app bundle
- `build/FRUSExplorer.dmg` — distributable disk image

**Verifying notarization manually:**

```sh
xcrun stapler validate "build/export/FRUS Explorer.app"
spctl --assess --type execute --verbose "build/export/FRUS Explorer.app"
```

#### Release workflow (App Store)

1. Select the **AppStore** build configuration
2. In Xcode Product → Archive
3. Distribute via Xcode Organizer → "Distribute App" → App Store Connect

### Regenerating the Xcode Project

If `project.yml` is modified, regenerate the `.xcodeproj` using XcodeGen:

```sh
xcodegen generate --spec project.yml
```

> **Note:** XcodeGen regenerates all file references. New source files added to directories
> already tracked by the project (e.g. `FRUSExplorer/Research/`) will appear automatically
> after regeneration. When XcodeGen is unavailable, file references can be added manually
> to `project.pbxproj` following the existing `AA…` UUID pattern.

### Command-Line Tools

```sh
# Regenerate manifest.json before each app release:
swift run ManifestGenerator

# Regenerate volume-tag-taxonomy.json when the taxonomy changes:
swift run TaxonomyGenerator

# Validate every cross-reference in the local corpus and regenerate the
# broken-refs report (CSV + JSON) plus the bundled exclusion index:
swift run -c release CrossRefValidationGenerator

# Regenerate volume-subject-profiles-index.json from the Office of the
# Historian's document–subject data:
swift run -c release VolumeSubjectProfilesGenerator
```

See `CLAUDE.md` and `Package.swift` for the full generator catalogue (central files,
person authority, volume sources, collection authority, source provenance,
administration profiles, and the corpus-wide `SourceExplorerExportGenerator`
Source Explorer data export/audit) and each tool's environment variables.

## Running Tests

```sh
# All unit tests (iOS simulator)
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17"

# Quick filter to a single test suite
xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing FRUSExplorerTests/CitationParserTests
```

### Manual Integration Tests

The following integration tests require a live device, downloaded volumes, or
network access and must be verified manually before each release:

| Test | How to verify |
|---|---|
| **FullOnboardingTest** | Fresh install → onboarding → download ≥1 volume → confirm browser appears |
| **AutoIndexTest** | Download a volume; confirm it appears in search results without manual reindex |
| **LargeCorpusIndexTest** | Index 10+ volumes; confirm search returns correct results |
| **PersonMentionTest** | Search by person reference; confirm results filtered correctly |
| **DateRangeFilterTest** | Filter search by date range; confirm only documents with `<date @when>` in range returned |
| **EditorialNoteFilterTest** | Switch Document Type filter; confirm editorial notes included/excluded correctly |
| **FrontMatterTest** | Navigate to a volume preface; confirm "Read" button appears and opens document |
| **IndexingProgressInBrowserTest** | Trigger "Index Now" from a CompilationView; confirm live progress bar appears (stage label + doc count + throughput), then doc list populates automatically on completion without navigating away |
| **MacQueueProgressPanelTest** | Trigger download of ≥2 volumes simultaneously on macOS; confirm status-bar popover shows "Volume N of M", current-volume progress bar, combined ETA, and expandable pending-volume list; confirm popover closes when indexing finishes |
| **StorageReindexTest** | Open Settings → Storage; confirm indexing controls appear above the volume list; confirm per-volume indexed badge; tap Reindex on an indexed volume; confirm it re-indexes and badge updates; confirm per-category size breakdown (volumes / index / summaries / total) is displayed |
| **DeleteIndexRebuildTest** | Open Settings → Storage; tap "Delete Index & Rebuild"; confirm confirmation alert appears; confirm that after accepting, all volumes are re-indexed from scratch and search results are correct |
| **CrossRefNavigationTest** | Tap a cross-reference link in a document; confirm DocumentView loads the target document body (not just updates the nav title) |
| **CrossRefGraphTest** | Open the cross-reference graph for a document with ≥3 direct references; hover over an edge midpoint to see footnote context; right-click a node and verify "Recenter Graph" and "Open in Main Window" options appear; switch to 2° and confirm 2nd-degree nodes appear in grey with connections to their 1st-degree neighbours; tap the info button (ⓘ) and confirm the explanation popover opens |
| **SearchResultNavigationTest** | Select a search result; confirm the full document body loads in DocumentView, not just the header |
| **SearchResultDisplayTest** | Run a keyword search; confirm result rows show the original document header and dateline text (e.g. "Memorandum of Conversation", "Washington, January 20, 1969."), not Porter-stemmed tokens |
| **iOSSearchCapTest** | Run a broad search on iOS with a large corpus; confirm up to 500 results are returned with an over-cap guidance message when the cap is hit |
| **MacSearchCapTest** | Run a broad search on macOS with a large corpus; confirm result count label shows "N of M total" when results are capped at 7,500, with guidance text below the list |
| **SearchPerformanceTest** | Search a large corpus; results appear in <1 second |
| **GraphRenderPerformanceTest** | Open a document with 20+ cross-references; confirm smooth animation; hover an edge to see context |
| **AnalyticsGranularityTest** | Open Corpus Analytics; change the "Group by" picker through Decade / Year / Month / Day / Subseries; confirm chart updates at each granularity; toggle the fit-line switch and confirm the regression line appears/disappears; tap the info button and confirm the metric explanation popover opens |
| **CollectionEnhancementsTest** | Open a collection with ≥3 entries; confirm the document header (from indexed TEI) appears between the document number and volume title; tap the trash icon to remove an entry; attach multiple notes via the note picker and confirm the row shows "N notes"; tap Sort by Date and confirm entries reorder chronologically; resize the Collections window and confirm the document list expands to fill the new height |
| **FindByCitationMacTest** | On macOS, use both the ⌘⇧F shortcut and the "Find by Citation" button in the search window to open the Citation Lookup sheet; confirm a citation resolves to the correct document |
| **CloudKitSyncTest** | Create a research note on device A; confirm it appears on device B; verify the macOS status bar shows "Synced" after sync completes and "Sync Error" (with tooltip detail) if sync fails |
| **CloudKitSyncDiagnosticsTest** | On iOS, open Settings; confirm an "iCloud Sync" section appears at the top showing the live sync state (enabled / syncing / synced / error with message) |
| **ResearchWindowTest** | On macOS, open the Research window (⌘⌥R or Window menu); confirm the sidebar lists tags sorted by document count descending with a count badge; select a tag and confirm the document list shows only documents whose notes carry that tag; click a row and confirm the document opens in the main window; right-click and confirm "Show Cross-References" opens the graph window |
| **ResearchTabTest** | On iOS, tap the Research tab (third tab); confirm "All Annotated Documents" entry shows the correct count; confirm tag entries appear sorted by document count; tap a tag and verify the document list; tap a document row and confirm navigation to the Browse tab with the document loaded |
| **OfflineResilienceTest** | Disable network mid-session; confirm no crash or data loss |
| **CrossPlatformVerification** | Verify all major workflows on macOS, iPadOS, and iPhone |
| **iOSTabNavigationTest** | Verify all five tabs (Browse, Search, Research, Collections, Settings) on iPhone |
| **macOSSettingsSceneTest** | Open macOS Settings via ⌘,; verify all panes open correctly; in the Notes pane, confirm rows have consistent horizontal padding; in Storage, confirm per-category breakdown appears and indexing controls are above the volume list |
| **MacTooltipsTest** | On macOS, hover over icon-only toolbar buttons throughout the app (document view toolbar, search window, corpus viewer, Source Explorer, Collections, Analytics, Research window); confirm `.help()` tooltip appears for each |

## Coding Standards

All code must comply with the following standards (see `Planning/FRUS-Explorer-Specification.md` §22):

- **Swift 6 strict concurrency** — zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`
- **Localization** — all user-facing strings use `String(localized:)`; no hardcoded literals
- **Documentation** — every new type, function, and significant property carries a doc comment
- **Telemetry** — `#if DEBUG` print statements for all significant operations; log prefixes match `[TypeName]` convention
- **Testing** — each development session produces unit tests; all prior tests must continue passing
- **OpenAPI** — `FRUS-API.openapi.yaml` updated in any session touching the API surface; must remain valid OpenAPI 3.1.0

The `CodingStandardsAuditTests` suite in `FRUSExplorerTests/` enforces many of these requirements automatically.

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  SwiftUI Views                    │
│  iOS: MainTabView (Browse, Search, Research,      │
│        Collections, Settings)                     │
│  macOS: NavigationSplitView + Window scenes +     │
│          Settings scene (⌘,)                      │
├──────────────────────────────────────────────────┤
│              Service Layer                        │
│  (Summarization, Search, Export, Citation,        │
│   NARA Resolution, Download, Indexing)            │
├──────────────────┬───────────────────────────────┤
│   SwiftData      │   SQLite FTS5 + Auxiliary DB   │
│  (User Data +    │   (Search Index +              │
│   CloudKit Sync) │    Cross-References +          │
│   [live sync     │    Page Ranges +               │
│    monitoring])  │    Person Mentions +            │
│                  │    Persons/Terms Glossaries +  │
│                  │    Document Cache)             │
├──────────────────┴───────────────────────────────┤
│           TEI Rendering Pipeline                  │
│  XML → FRUSDocumentParser → FRUSASTNode            │
│  → ASTToRenderNodeConverter → FRUSRenderNode tree  │
│  → FRUSRenderNodeHTMLSerializer → HTML             │
│  → WKWebView (Sessions 140–147)                    │
│  Footnotes: HTML Popover API (no JS required)      │
│  Highlights: CSS Custom Highlight API              │
├──────────────────────────────────────────────────┤
│           Network & Storage Layer                 │
│  (GitHub API, NARA API, Volume Files,             │
│   Manifest, iCloud Keychain)                      │
└──────────────────────────────────────────────────┘
```

### macOS Window Scenes

| Scene ID | Title | Shortcut | Purpose |
|---|---|---|---|
| `frus.search` | Search | ⌘F | Full-text search with filters and pagination |
| `frus.corpusBrowser` | Corpus Browser | — | Subseries/volume browser with volume-level graph |
| `frus.crossReferenceGraph` | Cross-Reference Graph | — | Document ego graph with degree expansion |
| `frus.sourceExplorer` | Source Explorer | — | NARA catalog integration |
| `frus.analytics` | Corpus Analytics | — | Term frequency charts |
| `frus.personAnalytics` | Person Analytics | — | Most-mentioned-by-era, mention-trajectory comparison, relationship dynamics, and co-mention ego-network |
| `frus.crossRefAnalytics` | Cross-Reference Analytics | — | Most-referenced documents, degree histogram, volume-to-volume heat matrix, PageRank influence |
| `frus.wordcloud` | Word Cloud | — | Frequency cloud over any scope, with semantic lenses and an in-window scope picker |
| `frus.chronology` | Chronology | — | Date-range browser with range-anchored distribution chart |
| `frus.collections` | Collections | ⇧⌘K | Document collection editor and exporter |
| `frus.research` | Research | ⌘⌥R | Annotated documents organized by user tag |
| `frus.history` | History | — | Complete reading + search history with project filter (also reachable via the History menu's "Complete History…" item) |
| `frus.researchGuide` | FRUS Research Guide | — | Standalone research-methodology guide; reachable via the Help menu |
| `about` | About FRUS Explorer | — | Version and acknowledgements |

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| iOS/iPadOS app | `bottsywattsy.FRUS-Explorer` |
| macOS app | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |

The bundle identifier is registered in App Store Connect. Do not change it.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

## Contributing

1. Read `Planning/FRUS-Explorer-Specification.md` to understand the full application design
2. Read `Planning/DEVELOPMENT-PLAN.md` for the session sequence and dependency graph
3. Each session's task file (e.g. `Planning/36-42-Extended-Indexing.md`) describes
   prerequisites, key changes, and tests for that block of sessions
4. Ensure all existing tests pass before committing session output
5. Update `FRUS-API.openapi.yaml` if your session touches any stored or queryable data surface
6. After every commit, both `FRUSExplorer` (iOS) and `FRUSExplorerMac` (macOS) must build
   cleanly with zero warnings under Swift 6 strict concurrency
