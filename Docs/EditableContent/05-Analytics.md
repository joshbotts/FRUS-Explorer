# EditableContent — Analytics — Corpus, Person, Cross-Reference, Chronology, Word Cloud, semantic map

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §5, §12, §13, §18.2, §18.6, parts of §14. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 221 blocks · no ✎ edits held or changed · no ⚑ wording issues

---

## 5. Analytics — Explanatory Captions & Info Popovers

*The "About …" info popovers and figure captions across the analytics features, plus the methods statement that travels inside an exported chart's CSV. Multi-sentence explanatory copy that teaches how to read each visualization.*

---

### About the Graph popover

#### What the graph shows

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.what.title | popover item title — the heading above is this string -->

What the graph shows

<!-- END SOURCE: graph.info.what.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1555–1556 | key: graph.info.what.body -->

Nodes are either FRUS documents or archival locations of documents referenced in FRUS documents. Light blue nodes represent incoming cross-references from other FRUS documents. Orange nodes represent outgoing cross-references to other FRUS documents. Teal nodes with the building icon represent outgoing archival references. Gray nodes are 2nd- or 3rd-degree neighbors. Larger nodes have more connections across the corpus. Each arrow points at the document being cited.

<!-- END SOURCE: graph.info.what.body -->

#### Edge context

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.edges.title | popover item title — the heading above is this string -->

Edge context

<!-- END SOURCE: graph.info.edges.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1561–1562 | key: graph.info.edges.body -->

Wherever feasible, lines between nodes carry the original footnote or editorial-note text that contain the reference that connects them. Hover over or tap the middle of a line to read it. A thicker line means the two documents are linked by several separate references.

<!-- END SOURCE: graph.info.edges.body -->

#### Timeline and Network layouts

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.timeline.title | popover item title — the heading above is this string -->

Timeline and Network layouts

<!-- END SOURCE: graph.info.timeline.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1567–1568 | key: graph.info.timeline.body -->

Timeline mode places each document at its date along a horizontal time axis. Outgoing references usually sit to the left, since they are earlier. Incoming references usually sit to the right, since they are later. Documents with no recorded date go in the Undated column. Network mode arranges nodes by their connections alone.

<!-- END SOURCE: graph.info.timeline.body -->

#### Neighborhood degree

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.degree.title | popover item title — the heading above is this string -->

Neighborhood degree

<!-- END SOURCE: graph.info.degree.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1573–1574 | key: graph.info.degree.body -->

1° shows only direct references to and from the central document. 2° adds neighbors of those neighbors. 3° extends one further hop. Resize the window to see denser graphs more clearly.

<!-- END SOURCE: graph.info.degree.body -->

#### Navigating the graph

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.interact.title | popover item title — the heading above is this string -->

Navigating the graph

<!-- END SOURCE: graph.info.interact.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.interactHelp | lines: 1538–1539 | key: graph.info.interact.body.v2 | shared: macOS (the iPhone and iPad text is the next block, #1481) -->

<!-- Repointed from graph.info.interact.body after the 2026-08-23 docs pass bumped the key to
     .v2 (the teal-node and three-citation-kinds paragraphs) but left this in-place block on the
     dead key. The §14 copy carries the change rationale; this is the section’s editing surface,
     the same in-place + §14 pairing the archival.info.weights.* keys use. -->

Click a node to see its details. Right-click to recenter the graph on that document or open it in the main window. Use drag to pan.

Teal nodes are archival material the editors pointed to in a footnote but did not print. There is no document behind one, so the walk ends there (unless you track the cited record down yourself in the archives).

This graph draws three kinds of archival citation: State Department lot files, collections in the presidential libraries, and the central files cited by decimal number, such as 681.8229/8–2950 — the usual practice in the earlier volumes, and still most archival footnotes in the volumes covering the 1950s. Opening a lot-file or library node shows the collection’s record. A central-file node is labeled by the number alone, with no subject beside it. A citation that was read but could not be matched is left off rather than drawn as a guess.

<!-- END SOURCE: graph.info.interact.body.v2 -->

> Same string also in §14 (Cross-Reference Graph) — edit one copy only.

#### Navigating the graph — iPhone and iPad

<!-- #1481 (2026-09-30): the touch text, split from the Mac’s under `#if os(macOS)`. Its first
     paragraph is the one you wrote in the 2026-09-21 box under the Mac block, with two changes you
     confirmed on 2026-09-30 — “Tap” for “Click”, and “or open it” for “or open it in the main window”,
     since on iOS that menu item opens the document over the graph; its other two are the ones you
     wrote in the #1481 slot. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.interactHelp | lines: 1541–1542 | key: graph.info.interact.body.ios | shared: iOS -->

Tap a node to see its details. Long-press to recenter the graph on that document or open it. Use pinch-to-zoom and drag to pan.

Teal nodes are archival material the editors pointed to in a footnote but did not print. There is no document behind one, so the walk ends there (unless you track the cited record down yourself in the archives).

This graph draws three kinds of archival citation: State Department lot files, collections in the presidential libraries, and the central files cited by decimal number, such as 681.8229/8–2950 — the usual practice in the earlier volumes, and still most archival footnotes in the volumes covering the 1950s. Opening a lot-file or library node shows the collection’s record. A central-file node is labeled by the number alone, with no subject beside it. A citation that was read but could not be matched is left off rather than drawn as a guess.

<!-- END SOURCE: graph.info.interact.body.ios -->

#### The node menu’s open item — Mac, and iPhone and iPad

<!-- #1481, your decision D9 (lane GRAPH, 2026-10-01): the long-press menu’s item is named for what
     it does on each platform. On the Mac it opens the document in the main window; on iPhone and
     iPad it opens the document inside the graph’s own sheet or window, as the node panel’s
     “View Document” button does, so it takes that button’s words. The help above (“or open it”)
     describes both. The same two labels name the open item in a reference-list row’s long-press
     or right-click menu (the graph’s List view on iPhone, the side panel on iPad and the Mac),
     which does the same thing; until review round 1 that row read “Open in Main Window” on iPhone
     and iPad too. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.openDocumentActionName | lines: 1519–1519 | key: graph.contextMenu.openDocument | shared: macOS -->

Open in Main Window

<!-- END SOURCE: graph.contextMenu.openDocument -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.openDocumentActionName | lines: 1521–1521 | key: graph.contextMenu.openDocument.ios | shared: iOS -->

View Document

<!-- END SOURCE: graph.contextMenu.openDocument.ios -->

#### Undownloaded volumes

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.undownloaded.title | popover item title — the heading above is this string -->

Undownloaded volumes

<!-- END SOURCE: graph.info.undownloaded.title -->

<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | CrossReferenceGraphView.graphInfoPopoverContent | lines: 1584–1585 | key: graph.info.undownloaded.body -->

A reference can point to a document in a volume you have not downloaded. The graph still shows it, because the connection was recorded when the citing volume was indexed. Those nodes have a dashed border and a struck-through cloud icon. Select one to download its volume from the info panel.

Using bundled series-wide cross-reference data, the app displays documents that cite this one even when their volumes are not on your device. They carry a dashed border and appear without titles or footnote text until you download their volumes; an orange banner at the top of the graph counts them. The 2nd- and 3rd-degree neighbors come only from volumes you have indexed, so download and index more volumes to fill in those links.

<!-- END SOURCE: graph.info.undownloaded.body -->

---

### Word Cloud — Info Popover ("About the Word Cloud")
<!-- Toolbar info popover; iOS+macOS use the same WordCloudView.swift toolbar (one file, shared across platforms). -->

#### Word Cloud info — What you're seeing

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.shows.title | popover item title — the heading above is this string -->

What you’re seeing

<!-- END SOURCE: wordcloud.info.shows.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1611–1612 | key: wordcloud.info.shows.detail.v2 -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail.v2 -->

> Same string also in §14 (Word cloud) — edit one copy only.

#### Word Cloud info — Lenses

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.lenses.title | popover item title — the heading above is this string -->

Lenses

<!-- END SOURCE: wordcloud.info.lenses.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1624–1625 | key: wordcloud.info.lenses.detail -->

The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.

<!-- END SOURCE: wordcloud.info.lenses.detail -->

#### Word Cloud info — What's filtered out

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.filters.title | popover item title — the heading above is this string -->

What’s filtered out

<!-- END SOURCE: wordcloud.info.filters.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1628–1629 | key: wordcloud.info.filters.detail -->

Common stopwords are always removed. A word’s own menu can hide it from this cloud only, which lasts until you next open it. The same menu can add it to a hidden-word list, either global or for one lens. You manage those lists in Settings → Word Cloud. You can also hide diplomatic boilerplate. Use “Show hidden words” in the Options menu to bring hidden words back.

<!-- END SOURCE: wordcloud.info.filters.detail -->

#### Word Cloud info — Selecting a word

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.tap.title | popover item title — the heading above is this string -->

Selecting a word

<!-- END SOURCE: wordcloud.info.tap.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | toolbarContent FeatureInfoItem | lines: 1632–1633 | key: wordcloud.info.tap.detail -->

Charts how often that term appears across the whole corpus in Corpus Analytics; the word’s menu also offers a scoped chart and a direct Search.

<!-- END SOURCE: wordcloud.info.tap.detail -->

### Word Cloud Settings — section footers

<!-- Shared surface note: WordCloudSettingsView is a single shared SwiftUI view used on both iOS and macOS (differs only by a #if os(macOS) .formStyle); each footer key below is a single edit point across both platforms. -->

#### Filtering footer — classification markings

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | filteringSection footer | lines: 163–164 | key: settings.wordcloud.markings.footer | shared: iOS+macOS (single edit point) -->

Classification markings include terms like “Top Secret” and “Confidential”, precedence words like “Priority” and “Immediate”, and month names. These words describe the handling of a document, not its content. Left in, they crowd the cloud, especially the named-entity lenses.

<!-- END SOURCE: settings.wordcloud.markings.footer -->

#### Thresholds footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | thresholdsSection footer | lines: 193–194 | key: settings.wordcloud.thresholds.footer | shared: iOS+macOS (single edit point) -->

Drops terms shorter than the minimum length, and terms appearing fewer than the minimum number of times. Raising either option results in a sparser cloud of stronger terms. Occurrences are counted across the whole scope before the top terms are picked, so raising the minimum count may thin a “long tail” you never see rather than the sample above.

<!-- END SOURCE: settings.wordcloud.thresholds.footer -->

#### Appearance footer

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | appearanceSection footer | lines: 219–220 | key: settings.wordcloud.appearance.footer | shared: iOS+macOS (single edit point) -->

Choose the typeface the cloud is drawn in and how tightly its words pack together. Compact fits more terms; airy spaces them out for legibility. These settings apply on this device only.

<!-- END SOURCE: settings.wordcloud.appearance.footer -->

#### Hidden-words footer — "Every cloud" scope

<!-- S-5b merged the two hidden-words sections into one editor with an "Applies to" scope picker; these two footers are now the two branches of `StopListScope.footer`, not two separate sections. -->

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.allLenses) | lines: 350–351 | key: settings.wordcloud.global.footer | shared: iOS+macOS (single edit point) -->

Words listed here are removed from every word cloud, on top of the built-in stop lists.

<!-- END SOURCE: settings.wordcloud.global.footer -->

#### Hidden-words footer — single-lens scope

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | StopListScope.footer (.lens) | lines: 353–354 | key: settings.wordcloud.lens.footer | shared: iOS+macOS (single edit point) -->

Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recognizer keeps mistaking) without affecting other lenses.

<!-- END SOURCE: settings.wordcloud.lens.footer -->


#### Sample footer — where the preview's terms come from

<!-- S-5b. Two branches of `WordCloudBench.provenance`, chosen by whether a cached cloud was found. -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudBench.swift | WordCloudBench.provenance | lines: 199–200 | key: settings.wordcloud.bench.source.cached | shared: iOS+macOS (single edit point) -->

Sampled from your most recent word cloud.

<!-- END SOURCE: settings.wordcloud.bench.source.cached -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudBench.swift | WordCloudBench.provenance | lines: 201–202 | key: settings.wordcloud.bench.source.canned | shared: iOS+macOS (single edit point) -->

A stand-in sample — open a corpus or subseries cloud and this becomes your own terms.

<!-- END SOURCE: settings.wordcloud.bench.source.canned -->

#### Sample empty state — the settings keep nothing

<!-- SOURCE: FRUSExplorer/Settings/WordCloudSettingsView.swift | sampleSection | lines: 123–124 | key: settings.wordcloud.sample.none | shared: iOS+macOS (single edit point) -->

These settings keep nothing from the sample. Lower a threshold or turn a filter off.

<!-- END SOURCE: settings.wordcloud.sample.none -->

---

### Chronology
<!-- Toolbar info popover; iOS+macOS use the same ChronologyView.swift toolbar (one file, shared across platforms). -->

#### What you're seeing

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | key: chronology.info.shows.title | popover item title — the heading above is this string -->

What you’re seeing

<!-- END SOURCE: chronology.info.shows.title -->

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1122–1123 | key: chronology.info.shows.detail -->

Every indexed document whose date falls within your selected range, grouped into date segments that become less precise (days → months → years) as the range widens.

<!-- END SOURCE: chronology.info.shows.detail -->

#### How dates work

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | key: chronology.info.dates.title | popover item title — the heading above is this string -->

How dates work

<!-- END SOURCE: chronology.info.dates.title -->

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1126–1127 | key: chronology.info.dates.detail -->

Each document sits at its TEI date, and is shown no more precisely than its source supports — with the editor’s annotated precision (day/month/year) and certainty (exact vs. approximate) preserved.

<!-- END SOURCE: chronology.info.dates.detail -->

#### The distribution chart

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | key: chronology.info.chart.title | popover item title — the heading above is this string -->

The distribution chart

<!-- END SOURCE: chronology.info.chart.title -->

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1130–1131 | key: chronology.info.chart.detail -->

The stacked chart color-codes documents by source volume (the top volumes, then a gray “Other”). Use the chart-colors menu to choose how many volumes get a distinct color.

<!-- END SOURCE: chronology.info.chart.detail -->

#### Wide ranges

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | key: chronology.info.cap.title | popover item title — the heading above is this string -->

Wide ranges

<!-- END SOURCE: chronology.info.cap.title -->

<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | ChronologyView toolbar FeatureInfoItem | lines: 1134–1135 | key: chronology.info.cap.detail -->

The document list is capped at 5,000, but the chart still reflects the whole range; the summary line reports the true total so you can narrow the range.

<!-- END SOURCE: chronology.info.cap.detail -->

### Source Explorer
<!-- Shared static FeatureInfoButton.sourceExplorer in FRUSTheme; consumed by both SourceExplorerView (iOS) and MacSourceExplorerView (macOS). Edit once in FRUSTheme.swift to change both. -->

#### What you're seeing

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: source.explorer.info.shows.title | popover item title — the heading above is this string -->

What you’re seeing

<!-- END SOURCE: source.explorer.info.shows.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 242–243 | key: source.explorer.info.shows.detail | shared: iOS+macOS (single edit point) -->

A structured breakdown of a document’s source note — the State Department editors’ record of where the document came from (archive, file, lot, telegram or despatch number) and how it was handled.

<!-- END SOURCE: source.explorer.info.shows.detail -->

#### Why it matters

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: source.explorer.info.why.title | popover item title — the heading above is this string -->

Why it matters

<!-- END SOURCE: source.explorer.info.why.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 246–247 | key: source.explorer.info.why.detail | shared: iOS+macOS (single edit point) -->

Source notes are your trail back to the original record. The parsed fields let you cite the document precisely and understand its provenance at a glance.

<!-- END SOURCE: source.explorer.info.why.detail -->

#### Links to the National Archives

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: source.explorer.info.catalog.title | popover item title — the heading above is this string -->

Links to the National Archives

<!-- END SOURCE: source.explorer.info.catalog.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.sourceExplorer FeatureInfoItem | lines: 250–251 | key: source.explorer.info.catalog.detail | shared: iOS+macOS (single edit point) -->

Whenever a source note or footnote resolves to a NARA series or file unit, the explorer links straight to the National Archives Catalog so you can locate the original record.

<!-- END SOURCE: source.explorer.info.catalog.detail -->

---

### Corpus Analytics — Info Popover ("About these results")
<!-- Shared static FeatureInfoButton.corpusAnalytics in FRUSTheme (moved out of AnalyticsView in Wave C, Win 7); the `analytics.info.*` keys and copy are unchanged, except Multiple words, re-keyed to `analytics.info.multiword.body.v2` for #1297, reworded in place, before shipping, for #1297 round 1, and re-keyed to `.v3` for #1299; and Phrases and How dates are determined, re-keyed to `.v2` for #1299. Edit once in FRUSTheme.swift to change both platforms. -->

#### What the numbers mean

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: analytics.info.metric.title | popover item title — the heading above is this string -->

What the numbers mean

<!-- END SOURCE: analytics.info.metric.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 281–282 | key: analytics.info.metric.body.v2 | shared: iOS+macOS (single edit point) -->

The Measure picker decides what a bar counts. Under Documents — the default — each bar is the number of indexed FRUS documents containing your term in that period, so a document that mentions your term ten times only counts once. Under Occurrences, each bar is every mention in those same documents, so that same document contributes ten instances of the term. Occurrences is offered for a single word only, and is always a raw count rather than a relative measure.

<!-- END SOURCE: analytics.info.metric.body.v2 -->

#### Multiple words

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: analytics.info.multiword.title | popover item title — the heading above is this string -->

Multiple words

<!-- END SOURCE: analytics.info.multiword.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 285–286 | key: analytics.info.multiword.body.v3 | shared: iOS+macOS (single edit point) -->

Words separated by spaces are combined with AND. So national security matches documents containing both words. OR finds either term. NOT, or a leading -, excludes a term from the words it is typed with, wherever it sits, except a NEAR(…): only NOT excludes that, and a - before it does not. An OR alternative made only of exclusions has nothing to find, so it is left out, and cold OR -korea is charted as cold; only Search’s Query Inspector marks what was left out. An = applies only where every match must contain the word you marked, as when every OR alternative marks it. Where a match need not contain it, as when only one OR alternative marks it, and always on a prefix or on a word the index splits into several terms, such as U.S.S.R., the = is ignored and the query is charted without it. Where an = applies, the query cannot be charted, because these counts are by stem. If you’re confused, try entering the same query in Search. Since a Corpus Analytics query is read exactly as the Search box reads it, you can use the Query Inspector to understand what was actually applied against your index.

<!-- END SOURCE: analytics.info.multiword.body.v3 -->

#### Phrases

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: analytics.info.phrase.title | popover item title — the heading above is this string -->

Phrases

<!-- END SOURCE: analytics.info.phrase.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 289–290 | key: analytics.info.phrase.body.v3 | shared: iOS+macOS (single edit point) -->

Wrap words in quotation marks, straight or curly, for an ordered phrase. “missile crisis” matches only documents where those two words appear together, in that order. A phrase cannot contain quotation marks of its own. Analytics and Search read a query the same way, so a query means the same thing in both. The counts can still differ, because Analytics counts document text only while Search also reads your own notes and summaries and applies whatever filters you have set. The View documents link opens Search with notes and summaries off for that reason.

<!-- END SOURCE: analytics.info.phrase.body.v3 -->

#### Stemming

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: analytics.info.stemming.title | popover item title — the heading above is this string -->

Stemming

<!-- END SOURCE: analytics.info.stemming.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 293–294 | key: analytics.info.stemming.body | shared: iOS+macOS (single edit point) -->

English stemming is applied: searching for “negotiate” also matches “negotiating”, “negotiated”, and “negotiations”.

<!-- END SOURCE: analytics.info.stemming.body -->

#### How dates are determined

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: analytics.info.dating.title | popover item title — the heading above is this string -->

How dates are determined

<!-- END SOURCE: analytics.info.dating.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics FeatureInfoItem | lines: 297–298 | key: analytics.info.dating.body.v3 | shared: iOS+macOS (single edit point) -->

Each document sits at its editor-annotated date. Where the editors date it to a range it sits at the range’s first day — about 3% of the corpus, and some of those ranges run for years. Volume content with no stored date, chiefly front matter, sits at the start year of its volume on By Year and By Decade and is left out of By Month and By Day.

<!-- END SOURCE: analytics.info.dating.body.v3 -->

Note: replaces `analytics.info.dating.body.v2` (#1306), whose last two sentences — a document with no month left out of By Month, one with no day left out of By Day — #1299 had carried over unmeasured. Measured over the 553 manifest volumes at corpus `550a8c5c5`: all 314,571 `<div type="document">` carry a full `frus:doc-dateTime-min`, so every stored date is exactly ten characters and the two charts' length guards can never fire. Nothing is left out for want of a month or a day. What IS left out of those two charts, and had never been mentioned, is a document with no stored date at all — about 2,152 promoted front-matter sections — which By Year and By Decade keep through the volume-start-year fallback. The row also now gives the range rule's scale: 11,030 documents, 3.5%, sit at a range's first day, and 7,126 of those ranges run for more than a year. #1306 deliberately changed no chart: the skew its own issue predicted does not exist — 1 January holds 793 documents and ranks 324th of the 366 month-days, behind 31 December's 1,226 — because #1326 had already taken each day from the editors' own date. `.v2` itself replaced `analytics.info.dating.body` (#1299), whose "its TEI <date> attribute" was stale.

### Corpus Analytics — Normalization Caption

#### Share-of-corpus caveat (% of documents mode)
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.normalizationCaption | lines: 1934–1935 | key: analytics.normalize.caption | shared: iOS+macOS (single edit point) -->

Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series.

<!-- END SOURCE: analytics.normalize.caption -->

### Corpus Analytics — Exact-word terms

*The refusal state shown when every entered term is an `=exact` term. It sits ahead of the
No-Results branch on purpose: this state HAS matches, and a bare "No Results" would read as "this
word never appears" — the opposite of the truth. The distinction it teaches (Analytics counts by
stem, Search filters to the exact word) must survive editing.*

#### Title
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 1651–1652 | key: analytics.exactUnsupported.title | shared: iOS+macOS (single edit point) -->

Exact-Word Charting Isn’t Available

<!-- END SOURCE: analytics.exactUnsupported.title -->

#### Detail
<!-- Placeholder note: the leading interpolation renders the refused terms as a list ("=containment
     and =détente"). Keep `\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and)))`
     intact exactly as written. -->
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | lines: 1655–1656 | key: analytics.exactUnsupported.detail | shared: iOS+macOS (single edit point) -->

\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and))) can’t be charted: Analytics counts by word stem in the search index, so it cannot tell "containment" from "container". Remove the = to chart the stem, or use Search, whose exact-word filter re-reads the stored document text to keep only the exact word.

<!-- END SOURCE: analytics.exactUnsupported.detail -->

### Corpus Analytics — Before a term is entered (#1380)

*The empty state names the Search button, so it says “tap” on iPhone and iPad and “click” on the
Mac, each under its own key: one key with two default values collides. Both are shorter than §18's
prose rule, and are carried because the Mac's is new and an editor should see the pair.*

#### Detail (iPhone and iPad)
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.promptDetail | lines: 2758–2759 | key: analytics.prompt.detail | shared: iOS only (the macOS wording is the next block) -->

Type a keyword and tap Search to chart its frequency across the FRUS corpus.

<!-- END SOURCE: analytics.prompt.detail -->

#### Detail (macOS)
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.promptDetail | lines: 2755–2756 | key: analytics.prompt.detail.mac | shared: macOS only -->

Type a keyword and click Search to chart its frequency across the FRUS corpus.

<!-- END SOURCE: analytics.prompt.detail.mac -->

### Person Analytics — Info Popover ("About Person Analytics")
<!-- Shared static FeatureInfoButton.personAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: personAnalytics.info.shows.title | popover item title — the heading above is this string -->

What you’re seeing

<!-- END SOURCE: personAnalytics.info.shows.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 311–312 | key: personAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

Trends ranks the people most mentioned in an era, as tagged by FRUS editors. It also charts how often one person is tagged across FRUS documents over time. Network maps who is tagged alongside whom in the same documents. Volumes covering the years before World War II carry no editorial tagging of people, so they fall outside both tools.

<!-- END SOURCE: personAnalytics.info.shows.detail -->

#### How people are counted

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: personAnalytics.info.counting.title | popover item title — the heading above is this string -->

How people are counted

<!-- END SOURCE: personAnalytics.info.counting.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 315–316 | key: personAnalytics.info.counting.detail | shared: iOS+macOS (single edit point) -->

Counts are mentions of a person across the documents you have indexed. The app’s person authority groups them, so spelling variants, honorifics, and different name forms for one individual merge into a single identity instead of splitting into several.

<!-- END SOURCE: personAnalytics.info.counting.detail -->

#### Comparing people

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: personAnalytics.info.compare.title | popover item title — the heading above is this string -->

Comparing people

<!-- END SOURCE: personAnalytics.info.compare.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.personAnalytics FeatureInfoItem | lines: 319–320 | key: personAnalytics.info.compare.detail | shared: iOS+macOS (single edit point) -->

Select a ranking bar, or use “Add a person to compare”, to plot several people’s mention trajectories on one chart — each colored line is one person. Remove a person with the ✕ on its chip.

<!-- END SOURCE: personAnalytics.info.compare.detail -->

### Cross-Reference Analytics — Info Popover ("About Cross-Reference Analytics")
<!-- Shared static FeatureInfoButton.crossReferenceAnalytics in FRUSTheme (added in Wave C, Win 7). Source doc comment notes this copy was drafted in Wave C and is pending owner review. Edit once in FRUSTheme.swift to change both platforms. -->

#### What you're seeing

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: crossRefAnalytics.info.shows.title | popover item title — the heading above is this string -->

What you’re seeing

<!-- END SOURCE: crossRefAnalytics.info.shows.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 409–410 | key: crossRefAnalytics.info.shows.detail | shared: iOS+macOS (single edit point) -->

How FRUS documents cite one another. The ranking lists the most-referenced documents. The heat matrix shows citation flow between whole volumes. Landmarks are the documents a reader following citations keeps returning to. Always remember that FRUS cross-referencing practice has changed over the life of the series. A subseries or a single administration therefore gives a more consistent signal than broader scopes that mix different editorial practices.

<!-- END SOURCE: crossRefAnalytics.info.shows.detail -->

#### Reading the heat matrix

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: crossRefAnalytics.info.matrix.title | popover item title — the heading above is this string -->

Reading the heat matrix

<!-- END SOURCE: crossRefAnalytics.info.matrix.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 413–414 | key: crossRefAnalytics.info.matrix.detail | shared: iOS+macOS (single edit point) -->

Rows cite columns. A darker cell means the row’s volume cites the column’s volume more often. Column labels are a short code of the volume’s years and number, such as ’55–57 II. Hover over a label, or use VoiceOver, for the full title on either axis.

<!-- END SOURCE: crossRefAnalytics.info.matrix.detail -->

#### About the influence score

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: crossRefAnalytics.info.influence.title | popover item title — the heading above is this string -->

About the influence score

<!-- END SOURCE: crossRefAnalytics.info.influence.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.crossReferenceAnalytics FeatureInfoItem | lines: 417–418 | key: crossRefAnalytics.info.influence.detail | shared: iOS+macOS (single edit point) -->

Landmark documents are ranked by PageRank, computed on this device over the citations the app resolved. It measures how often a document is cited by other much-cited documents. It is an editorial measurement, not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.info.influence.detail -->

### Cross-Reference Analytics — Captions

#### Scope-of-figures caveat
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 854–855 | key: crossRefAnalytics.resolvedCaption | shared: iOS+macOS (single edit point) -->

The most-referenced, degree, and PageRank charts count same-volume references, including resolved page references, toward the document’s own volume. Set a year range or scope and they count citations made by documents in that era or scope. The heat matrix counts only connections between different volumes, so it leaves same-volume citations out.

<!-- END SOURCE: crossRefAnalytics.resolvedCaption -->

#### Excluded unresolvable references (shown only when the count is non-zero)

<!-- Placeholder note: the leading count is a Swift string interpolation, not a %lld token — keep `\(excludedBrokenCount)` intact exactly as written. -->

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.resolvedCaption | lines: 859–860 | key: crossRefAnalytics.excludedBrokenCaption | shared: iOS+macOS (single edit point) -->

\(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus.

<!-- END SOURCE: crossRefAnalytics.excludedBrokenCaption -->

#### Landmark Documents (Influence) — PageRank hedge subtitle
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.landmarkSection | lines: 1255–1256 | key: crossRefAnalytics.landmarks.subtitle | shared: iOS+macOS (single edit point) -->

Ranked by a PageRank score computed on this device over the citations the app resolved. These are the documents a reader who follows citations would keep returning to. The score measures position in the citation network, not historical importance. Select one to open it.

<!-- END SOURCE: crossRefAnalytics.landmarks.subtitle -->

---

#### Heat matrix — subtitle

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | lines: 1011–1012 | key: crossRefAnalytics.matrix.subtitle -->

Citations between the \(Self.matrixVolumeLimit) volumes with the most references in and out. Rows cite columns. Darker cells mean more references. Select a volume label to open it.

<!-- END SOURCE: crossRefAnalytics.matrix.subtitle -->

---

### Analytics Export — Methods Statement (D3)

*The prose that leaves the app inside an exported chart. Every CSV carries a `#`-commented preamble — the figure, terms, grouping, scope, year range, values, app version and export date, then the method and caveats below, then the corpus attribution. An exported PNG or PDF carries only a two-line caption plus the pointer to the CSV, so these sentences are where a reader finds the method. Menu labels, the CSV preamble's field labels ("Figure", "Scope", "Method and caveats", …), CSV column headings, and export-failure messages are functional strings and are intentionally excluded.*

<!-- Placeholder note: `%lld` (a number) and `%@` (a word or phrase) are filled in at export time. Keep them intact and in order — removing one will break the string. -->

#### Corpus attribution — closes every export

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusAttribution | lines: 176–177 | key: analytics.export.attribution | shared: iOS+macOS (single edit point) -->

Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State (history.state.gov). The corpus is in the public domain.

<!-- END SOURCE: analytics.export.attribution -->

#### Dating rule

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.datingCaveat | lines: 209–210 | key: analytics.export.caveat.dating.v2 | shared: iOS+macOS (single edit point) -->

Dating: each document sits at the editor-annotated date; where that date is a range, at the range’s first day (about 3% of the corpus). Every stored date is a full day, so nothing is dropped for want of a month or a day. A document with no stored date at all falls back to the start year of its volume on the By Year and By Decade charts, in both the counts and the % denominator; the By Month and By Day charts have no such fallback and leave it out.

<!-- END SOURCE: analytics.export.caveat.dating.v2 -->

Note: replaces `analytics.export.caveat.dating` (#1306) — the first time this string has moved, and it had drifted twice. It still named the `TEI <date>` the in-app row dropped at #1299, and it carried the same no-month/no-day exclusion that #1306 measured and refuted. It is the worse of the two surfaces to leave wrong: it is printed into every exported CSV preamble and figure caption, so it travels to a reader who cannot check it against the chart. The two surfaces state the same rule again.

#### Corpus-coverage caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.corpusCaveat | lines: 218–219 | key: analytics.export.caveat.corpus %@ | shared: iOS+macOS (single edit point) -->

Corpus: counts cover only the %@ indexed on this device, not the entire FRUS series. *(Interpolated with the indexed volumes as a count and its noun — “12 volumes”, “1 volume” (#1374 review, round 1, where it read “1 volume(s)”).)*

<!-- END SOURCE: analytics.export.caveat.corpus -->

#### Value-mode caveat

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.valueModeCaveat | lines: 226–227 | key: analytics.export.caveat.values %@ | shared: iOS+macOS (single edit point) -->

Values: %@. A share is that period’s matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term.

<!-- END SOURCE: analytics.export.caveat.values -->

#### Year range — when the chart ignores it

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.yearRangeDescription | lines: 191–192 | key: analytics.export.range.notApplied | shared: iOS+macOS (single edit point) -->

Not applied — this breakdown covers the whole corpus span

<!-- END SOURCE: analytics.export.range.notApplied -->

#### Figure caption — pointer to the CSV

Printed on every exported figure. It used to read "Full method, caveats, and the underlying numbers
**accompany this figure** in its CSV export" — which a PNG published on its own made false: it did
not merely omit the caveats, it asserted they had travelled with the image. It now says where the
numbers can be got, which is true however the figure is published.

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.plateDataPointer | lines: 170–171 | key: analytics.export.figure.seeData | shared: iOS+macOS (single edit point) -->

The underlying numbers are available as a CSV export from FRUS Explorer, with the full method statement.

<!-- END SOURCE: analytics.export.figure.seeData -->

#### Figure plate — publisher credit

The credit an exported figure carries **on the image**. Before this existed a plate printed
`FRUS Explorer <version>` and nothing else, so a figure published in an article credited a reading
application for the U.S. government's documentary edition. This is the one-line form; the full
sentence in the CSV preamble is `analytics.export.attribution`, and the two should agree.

<!-- SOURCE: FRUSExplorer/Analytics/Export/AnalyticsProvenance.swift | AnalyticsProvenance.plateAttribution | lines: 159–160 | key: analytics.export.plateAttribution | shared: iOS+macOS (single edit point) -->

Foreign Relations of the United States, published by the Office of the Historian, U.S. Department of State. Public domain.

<!-- END SOURCE: analytics.export.plateAttribution -->

### Analytics Export — Person Analytics caveats

#### Dated-documents population

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 535–536 | key: personAnalytics.export.caveat.dated | shared: iOS+macOS (single edit point) -->

Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume’s start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable.

<!-- END SOURCE: personAnalytics.export.caveat.dated -->

#### Identity grouping

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.personProvenance | lines: 537–538 | key: personAnalytics.export.caveat.identity | shared: iOS+macOS (single edit point) -->

Identity: mentions are grouped by the app’s person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity.

<!-- END SOURCE: personAnalytics.export.caveat.identity -->

#### Decade shares (By Decade in % mode only)

<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.decadeShareCaveat | lines: 557–558 | key: personAnalytics.export.caveat.decadeShare | shared: iOS+macOS (single edit point) -->

Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was tagged. Years with no tags are dropped from that average rather than counted as zero. The “Dated documents in period” column, by contrast, sums every year of the decade. So dividing this file’s columns gives the decade’s own share, which can be far lower than the plotted value. Someone tagged in one year of a decade plots that single year’s share for the whole decade. Use the columns for the decade’s share and the plotted value for the average across the tagged years. They answer different questions.

<!-- END SOURCE: personAnalytics.export.caveat.decadeShare -->

### Analytics Export — Cross-Reference Analytics caveats

#### Unresolvable references — one

*The count is grouped and the sentence agrees with it (#1374 review, round 1, where one sentence said “%lld cross-reference(s) are” and printed a large count ungrouped).*

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 593–594 | key: crossRefAnalytics.export.caveat.excluded.one | shared: iOS+macOS (single edit point) -->

Unresolvable references: %@ cross-reference is excluded from this analysis — a reference in the printed volumes that points to a document, page, or volume not present in this corpus.

<!-- END SOURCE: crossRefAnalytics.export.caveat.excluded.one -->

#### Unresolvable references — several

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 595–596 | key: crossRefAnalytics.export.caveat.excluded.many | shared: iOS+macOS (single edit point) -->

Unresolvable references: %@ cross-references are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus.

<!-- END SOURCE: crossRefAnalytics.export.caveat.excluded.many -->

#### Same-volume attribution

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.crossRefProvenance | lines: 598–599 | key: crossRefAnalytics.export.caveat.sameVolume | shared: iOS+macOS (single edit point) -->

Attribution: the document-level figures count same-volume references, including resolved page references, toward the document’s own volume. The volume heat matrix counts only citations between different volumes, so it leaves same-volume references out.

<!-- END SOURCE: crossRefAnalytics.export.caveat.sameVolume -->

#### Heat matrix — which volumes it covers

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 768–769 | key: crossRefAnalytics.export.caveat.matrixLimit %lld | shared: iOS+macOS (single edit point) -->

Selection: the matrix covers the %lld volumes with the most references in and out. The CSV lists only pairs with at least one reference between them. The figure draws the whole grid and leaves the rest of the cells blank.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixLimit -->

#### Heat matrix — axes and labels

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixCaveats | lines: 771–772 | key: crossRefAnalytics.export.caveat.matrixAxes | shared: iOS+macOS (single edit point) -->

Axes: rows cite columns. In the figure the column headings are abbreviated volume codes and the row labels are shortened descriptive labels; both volumes’ full titles appear in this CSV.

<!-- END SOURCE: crossRefAnalytics.export.caveat.matrixAxes -->

#### Landmark Documents — what the score is

<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.exportLandmarkCSV | lines: 827–828 | key: crossRefAnalytics.export.caveat.pageRank | shared: iOS+macOS (single edit point) -->

Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is a measure of editorial handling, not a claim of historical importance.

<!-- END SOURCE: crossRefAnalytics.export.caveat.pageRank -->

### Analytics Export — Word Cloud caveats

<!-- A cloud never reads a document date, so its export deliberately carries no dating rule and no year-range line. The exported plate's figure title, axis line, and caption facts (wordcloud.export.figureTitle / .axis / .caption.*) are functional identifiers and are intentionally excluded here — all but one: the counted-as-printed caption segment (#1373), which states a method rather than identifying the plate, is kept below with the caveat it abbreviates. -->

#### Population

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.populationCaveat | lines: 264–265 | key: wordcloud.export.caveat.population %@ %@ %@ | shared: iOS+macOS (single edit point) -->

Population: these counts cover the %1$@ in this scope. The share column divides by %2$@, which is every word counted under the “%3$@” lens after the filters below. That is not the scope’s total word count. Shares from two different lenses cannot be compared. *(Interpolated with the scope's documents as a count and its noun — “4,591 documents”, “1 document” — then the denominator grouped, then the lens's name (#1374 review, round 1: it read “the 4591 document(s)”).)*

<!-- END SOURCE: wordcloud.export.caveat.population -->

#### Stopwords

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1122–1123 | key: wordcloud.export.caveat.stopwords %@ %@ | shared: iOS+macOS (single edit point) -->

Stopwords: common English words are always removed. FRUS boilerplate (telegram, department, embassy…) is %@; classification markings, months, and weekdays (secret, confidential, january…) are %@.

<!-- END SOURCE: wordcloud.export.caveat.stopwords -->

#### Stopwords caveat — the two fill-in phrases

*Each `%@` slot above (first the boilerplate filter, then the markings filter) is filled with one of these two fragments, depending on whether that filter is on.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1125–1129 | keys: wordcloud.export.caveat.stopwords.excluded, wordcloud.export.caveat.stopwords.kept | shared: iOS+macOS (single edit point) -->

**Filter on:** also removed

**Filter off:** kept

<!-- END SOURCE: wordcloud.export.caveat.stopwords.excluded/.kept -->

#### Tuning thresholds

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1131–1132 | key: wordcloud.export.caveat.tuning %@ %@ %@ | shared: iOS+macOS (single edit point) -->

Tuning: words shorter than %1$@ and words occurring fewer than %2$@ are excluded; plural folding is %3$@. *(Interpolated with each threshold as a count and its noun — “3 characters”, “1 time” — singular at one (#1374 review, round 1), where they read “character(s)” and “time(s)”; the two short forms each are not carried here, under §18's length rule.)*

<!-- END SOURCE: wordcloud.export.caveat.tuning -->

<!-- The tuning %@ slot is filled with the generic common.on / common.off strings ("on" / "off"), which are shared app-wide and not editable here. -->

#### Words hidden by hand — one word

*The count is grouped and the sentence agrees with it: one word “was … is … It … it”, several “were … are … They … they” (#1374 review, round 1, where one sentence said “%lld word(s) were”).*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1159–1160 | key: wordcloud.export.caveat.hidden.one | shared: iOS+macOS (single edit point) -->

Hidden words: %@ word was hidden by hand in this cloud and is absent from this export. It was counted before being hidden, so it remains in the denominator above.

<!-- END SOURCE: wordcloud.export.caveat.hidden.one -->

#### Words hidden by hand — several

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1161–1162 | key: wordcloud.export.caveat.hidden.many | shared: iOS+macOS (single edit point) -->

Hidden words: %@ words were hidden by hand in this cloud and are absent from this export. They were counted before being hidden, so they remain in the denominator above.

<!-- END SOURCE: wordcloud.export.caveat.hidden.many -->

#### Personal stop lists — only your global list removed words

*#1478, your close-out answer: the sentence names only the lists that removed something, so it never prints “0 words”, and each count is grouped (“1,204 words”) and agrees with its verb. Each count is the size of the list. With both lists empty the export carries no stop-lists sentence. `%@` is the count alone (“1”, “1,204”).*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 296–297 | key: wordcloud.export.caveat.stopLists.global.one | shared: iOS+macOS (single edit point) -->

Your stop lists: %@ word from your global hidden-word list was removed before counting. Stop-listed words are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists.global.one -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 298–299 | key: wordcloud.export.caveat.stopLists.global.many | shared: iOS+macOS (single edit point) -->

Your stop lists: %@ words from your global hidden-word list were removed before counting. Stop-listed words are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists.global.many -->

#### Personal stop lists — only this lens’s list removed words

*`%1$@` is the count alone (“1”, “3”); `%2$@` is the lens’s name (“Concepts”).*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 304–305 | key: wordcloud.export.caveat.stopLists.lens.one %@ %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %1$@ word from your list for the “%2$@” lens was removed before counting. Stop-listed words are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists.lens.one %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 306–307 | key: wordcloud.export.caveat.stopLists.lens.many %@ %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %1$@ words from your list for the “%2$@” lens were removed before counting. Stop-listed words are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists.lens.many %@ %@ -->

#### Personal stop lists — both lists removed words

*Two phrases joined by “and” take “were” at every count. `%1$@` and `%2$@` are each a count with its noun, from the two forms below (“1 word”, “3 words”); `%3$@` is the lens’s name.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 320–321 | key: wordcloud.export.caveat.stopLists.both %@ %@ %@ | shared: iOS+macOS (single edit point) -->

Your stop lists: %1$@ from your global hidden-word list and %2$@ from your list for the “%3$@” lens were removed before counting. Stop-listed words are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.export.caveat.stopLists.both %@ %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 313–314 | key: wordcloud.export.caveat.stopLists.words.one | shared: iOS+macOS (single edit point) -->

%@ word

<!-- END SOURCE: wordcloud.export.caveat.stopLists.words.one -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.stopListsCaveat | lines: 315–316 | key: wordcloud.export.caveat.stopLists.words.many | shared: iOS+macOS (single edit point) -->

%@ words

<!-- END SOURCE: wordcloud.export.caveat.stopLists.words.many -->

#### Active lens

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudView.cloudProvenance | lines: 1197–1198 | key: wordcloud.export.caveat.lens %@ | shared: iOS+macOS (single edit point) -->

Lens: the cloud is filtered to the “%@” word list, so this is a subset of the scope’s vocabulary, not its whole frequency ranking.

<!-- END SOURCE: wordcloud.export.caveat.lens -->

#### Counted as printed

*Added by #1373 review round 1. Carried only by a cloud whose words were counted without the device's lemmatiser — All terms, Concepts or Sentiment, which still draw then. The three blocks below say the same thing on three surfaces a reader meets after the device that made the cloud has moved on: the CSV's caveats, the exported image's caption line, and the cloud embedded in a collection export (that plate otherwise carries only its title). The on-screen line is §12.4's* Counted as printed.

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedCaveat | lines: 173–174 | key: wordcloud.export.caveat.countedAsPrinted | shared: iOS+macOS (single edit point) -->

Counting: these words were counted as printed. When this cloud was made, the device’s language analysis was not reducing words to their dictionary forms, so “negotiation” and “negotiations” are two words here where a device whose language analysis works counts one. These counts and shares cannot be compared with a cloud counted in dictionary forms.

<!-- END SOURCE: wordcloud.export.caveat.countedAsPrinted -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedCaptionSegment | lines: 181–182 | key: wordcloud.export.caption.countedAsPrinted | shared: iOS+macOS (single edit point) -->

counted as printed, not in dictionary forms

<!-- END SOURCE: wordcloud.export.caption.countedAsPrinted -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | WordCloudDisplayState.countedAsPrintedPlateLine | lines: 190–191 | key: wordcloud.export.collection.countedAsPrinted | shared: iOS+macOS (single edit point) -->

Counted as printed: the device that made this cloud was not reducing words to their dictionary forms.

<!-- END SOURCE: wordcloud.export.collection.countedAsPrinted -->

---

## 12. Word Cloud — Keyness and its Reference

*The keyness measure and the bundled corpus reference it is scored against, plus every state in which the app refuses to score rather than showing a number it cannot stand behind. §5 already carries the word cloud's info popover and settings footers; these are the keyness strings added since. This section is new in this regeneration.*

---

### 12.1 What the two measures are

#### Frequency and Distinctive

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.measure.title | popover item title — the heading above is this string -->

Frequency vs. Distinctive

<!-- END SOURCE: wordcloud.info.measure.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1615–1616 | key: wordcloud.info.measure.detail -->

Frequency sizes each word by how often it appears here. That tends to surface the vocabulary every FRUS volume shares. Distinctive compares this scope with bundled reference data for the whole corpus. It sizes each word by how much more it is used here than across the series, measured by log-likelihood keyness, the corpus-linguistics standard. Distinctive lists only words used more here than in the corpus.

<!-- END SOURCE: wordcloud.info.measure.detail -->

---

#### The two numbers on each row

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.info.keyness.numbers.title | popover item title — the heading above is this string -->

Reading the Distinctive list

<!-- END SOURCE: wordcloud.info.keyness.numbers.title -->

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1620–1621 | key: wordcloud.info.keyness.numbers.detail -->

Each row carries two numbers, and they answer different questions. The score on the right is log-likelihood (G²). It measures how strong the evidence is that the difference is real, and the list is ranked on it. “38× more often here” is the effect size: how much more often the word is used here than across the corpus, per word of text. G² grows with the amount of text, so a long volume scores higher than a short collection for the same effect. When you compare two scopes, compare the multiples. A word marked “unpriced” occurs too rarely across the corpus to be counted in the reference, so its multiple is an upper bound.

<!-- END SOURCE: wordcloud.info.keyness.numbers.detail -->

---

#### The reference, named on screen

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 866–867 | key: wordcloud.keyness.caveat.reference %lld -->

Words occurring fewer than %lld times corpus-wide are unpriced and score as if new.

<!-- END SOURCE: wordcloud.keyness.caveat.reference %lld -->

---

### 12.2 When keyness is unavailable, and why

#### No reference shipped

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1010–1011 | key: wordcloud.keyness.unavailable.noArtifact -->

The bundled corpus reference could not be loaded, so there is nothing to measure this scope against.

<!-- END SOURCE: wordcloud.keyness.unavailable.noArtifact -->

---

#### This lens has no reference

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1014–1015 | key: wordcloud.keyness.unavailable.lens %@ -->

The “%@” lens has no corpus reference. Names of people, places, and organizations are not counted across the whole corpus, so there is nothing to compare this scope against. Switch to another lens, or size words by frequency.

<!-- END SOURCE: wordcloud.keyness.unavailable.lens %@ -->

---

#### Your settings do not match the reference

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1019–1020 | key: wordcloud.keyness.unavailable.mismatch %@ -->

Your settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to compare this scope with the corpus.

<!-- END SOURCE: wordcloud.keyness.unavailable.mismatch %@ -->

---

#### Nothing in this scope clears the floor

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1027–1028 | key: wordcloud.keyness.unavailable.floor %lld -->

No word occurs at least %lld times in this scope. A word appearing once or twice can top a keyness ranking without saying anything about the documents, so nothing is ranked.

<!-- END SOURCE: wordcloud.keyness.unavailable.floor %lld -->

---

#### Nothing here is used more than corpus-wide

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1031–1032 | key: wordcloud.keyness.unavailable.nothingDistinctive -->

Nothing here is used more than it is across the corpus. This scope’s vocabulary is typical of the series.

<!-- END SOURCE: wordcloud.keyness.unavailable.nothingDistinctive -->

---

#### This device counted the words as printed

*Added by #1373. Shown under Distinctive when the scope's words were counted without the device's lemmatiser. Reworded by #1539: the app checks again each time it becomes active, and the cloud is counted again when a check finds the lemmatiser working.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1023–1024 | key: wordcloud.keyness.unavailable.languageAnalysis -->

These words were counted as printed, because this device’s language analysis wasn’t reducing them to their dictionary forms. The corpus reference was counted in dictionary forms, so the two can’t be compared. Size words by frequency instead. FRUS Explorer checks again each time you come back to it, and the cloud is counted again if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.keyness.unavailable.languageAnalysis -->

---

#### This lens found too little to draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 438–439 | key: wordcloud.lens.insufficient.detail %@ -->

There aren’t enough %@ in this scope to fill a cloud. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.insufficient.detail %@ -->

---

### 12.3 The keyness export

#### Axis label

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1210–1211 | key: wordcloud.export.axis.keyness -->

Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference

<!-- END SOURCE: wordcloud.export.axis.keyness -->

---

#### What the reference is

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1171–1172 | key: wordcloud.export.caveat.keyness %lld %lld %@ -->

Keyness: each word is scored against a built-in reference for the whole FRUS corpus. That reference covers %lld of the corpus’s %lld distinct words for this lens, and was generated %@. Only words used more here than in the corpus are listed. A word this scope conspicuously avoids is a real finding, and this table does not carry it.

<!-- END SOURCE: wordcloud.export.caveat.keyness %lld %lld %@ -->

---

#### When the reference covers everything

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1181–1182 | key: wordcloud.export.caveat.keyness.complete %lld -->

Keyness candidates: every word occurring at least %lld times in this scope was scored.

<!-- END SOURCE: wordcloud.export.caveat.keyness.complete %lld -->

---

#### When the reference is truncated

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1177–1178 | key: wordcloud.export.caveat.keyness.truncated %lld -->

Keyness candidates: only this scope’s %lld most frequent words were scored, so a word that is rare here but unique to it is outside this ranking.

<!-- END SOURCE: wordcloud.export.caveat.keyness.truncated %lld -->

---

#### What "unpriced" means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1186–1187 | key: wordcloud.export.caveat.keyness.cutoff %lld -->

Reference coverage: the reference counts only words occurring at least %lld times across the corpus. A rarer word is marked unpriced rather than absent. It is scored as though the corpus never used it. Treat a high score on a rare word with care.

<!-- END SOURCE: wordcloud.export.caveat.keyness.cutoff %lld -->

---

### 12.4 Empty states

#### Nothing to draw

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1554–1555 | key: wordcloud.empty.detail -->

There’s no indexed text in this scope yet. Download and index the relevant volumes, then try again.

<!-- END SOURCE: wordcloud.empty.detail -->

---

#### Title — a lens this device cannot draw

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.lens.unavailable.title | the two blocks below are its messages -->

Lens Unavailable on This Device

<!-- END SOURCE: wordcloud.lens.unavailable.title -->

#### A name lens this device cannot draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*Added by #1373; re-keyed in its review round 3. Shown for People, Places or Organizations when the device's name recognizer failed its check. Interpolated with the lens name (`%1$@`) and with the lenses that still work (`%2$@`), which the app reads from the same check and joins as a list: with only names failing, All terms, Topics (nouns), Actions (verbs), Descriptors (adjectives), Concepts, and Sentiment; with the word classes failing too, All terms, Concepts, and Sentiment. Reworded by #1539: the app checks again each time it becomes active, and the cloud reloads when a check finds names working.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 386–387 | key: wordcloud.lens.unavailable.names %@ %@ -->

This device’s language analysis isn’t recognizing names right now, so the “%1$@” lens can’t be drawn. %2$@ still work. FRUS Explorer checks again each time you come back to it, and the cloud updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.lens.unavailable.names %@ %@ -->

---

#### A part-of-speech lens this device cannot draw

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

*Added by #1373; re-keyed in its review round 3. Shown for Topics, Actions or Descriptors when the device's word classes failed their check. Interpolated with the lens name (`%1$@`) and with the lenses that still work (`%2$@`), which the app reads from the same check and joins as a list: with only the word classes failing, All terms, People, Places, Organizations, Concepts, and Sentiment; with names failing too, All terms, Concepts, and Sentiment. Reworded by #1539: the app checks again each time it becomes active, and the cloud reloads when a check finds the word classes working.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 390–391 | key: wordcloud.lens.unavailable.classes %@ %@ -->

This device’s language analysis isn’t telling nouns, verbs and adjectives apart right now, so the “%1$@” lens can’t be drawn. %2$@ still work. FRUS Explorer checks again each time you come back to it, and the cloud updates if it recovers; if it doesn’t, quitting and reopening FRUS Explorer may restore it.

<!-- END SOURCE: wordcloud.lens.unavailable.classes %@ %@ -->

---

#### Title — documents read, nothing kept

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | key: wordcloud.lens.noTerms.title | the nine blocks below are its messages -->

Nothing Found for This Lens

<!-- END SOURCE: wordcloud.lens.noTerms.title -->

#### Documents read, nothing kept — All terms

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 334–335 | key: wordcloud.lens.noTerms.allTerms -->

This scope’s documents were read, but none of their words passed the Word Cloud’s filters: the stopword lists, your hidden words, the minimum word length and the minimum count. You can change them in Settings → Word Cloud.

<!-- END SOURCE: wordcloud.lens.noTerms.allTerms -->

---

#### Documents read, nothing kept — People

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 337–338 | key: wordcloud.lens.noTerms.people -->

This scope’s documents were read, but no person’s name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.people -->

---

#### Documents read, nothing kept — Places

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 340–341 | key: wordcloud.lens.noTerms.places -->

This scope’s documents were read, but no place name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.places -->

---

#### Documents read, nothing kept — Organizations

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 343–344 | key: wordcloud.lens.noTerms.organizations -->

This scope’s documents were read, but no organization’s name in them passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.organizations -->

---

#### Documents read, nothing kept — Topics

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 346–347 | key: wordcloud.lens.noTerms.topics -->

This scope’s documents were read, but none of their nouns passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.topics -->

---

#### Documents read, nothing kept — Actions

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 349–350 | key: wordcloud.lens.noTerms.actions -->

This scope’s documents were read, but none of their verbs passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.actions -->

---

#### Documents read, nothing kept — Descriptors

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 352–353 | key: wordcloud.lens.noTerms.descriptors -->

This scope’s documents were read, but none of their adjectives passed the Word Cloud’s filters. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.descriptors -->

---

#### Documents read, nothing kept — Concepts

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 355–356 | key: wordcloud.lens.noTerms.concepts -->

This scope’s documents were read, but none of them uses a word from the Concepts list. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.concepts -->

---

#### Documents read, nothing kept — Sentiment

*Added by #1373. Shown when the scope has documents and this lens kept none of their words.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 358–359 | key: wordcloud.lens.noTerms.sentiment -->

This scope’s documents were read, but none of them uses a word from the Sentiment list. Try a broader scope or a different lens.

<!-- END SOURCE: wordcloud.lens.noTerms.sentiment -->

---

#### Counted as printed

*Added by #1373. A caption under the cloud's title when its words were counted without the device's lemmatiser — and, since review round 1, under a comparison column's count too. The exported forms of the same fact are §5's* Counted as printed *blocks.*

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 163–164 | key: wordcloud.countedAsPrinted -->

Counted as printed: this device isn’t reducing words to their dictionary forms right now.

<!-- END SOURCE: wordcloud.countedAsPrinted -->

---

#### The macOS window with no scope

<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 2261–2262 | key: wordcloud.window.empty.detail -->

Pick a scope above, or open a word cloud from a document, volume, collection, tag, saved search, volume scope, or the corpus.

<!-- END SOURCE: wordcloud.window.empty.detail -->

---

---

## 13. Semantic Analytics — the map, its regions, its slices, and its vectors

*The map surface and everything that explains it, plus the Settings section that governs the files
it needs. Gathered here rather than split across §5 and §6 because an editor working on this feature
is working on one idea, and the prose has to hold together: a **region** is a grouping the corpus
produced on its own, a **slice** is a contrast the reader proposed, and the difference between those
two sentences is the feature. Nearly all of it is new in build 42.*

**The standing rule for this section: plainer must not become more confident.** The semantic axis
ships at weight 0, its quality before 1900 is a declared unknown rather than a measured pass, and
the neighbor list is drawn only from volumes on the device even though the map draws all 552. Every
one of those limits is stated somewhere below. If an edit reads as having removed one rather than
unpacked it, that is a defect — say so and it goes back.

---

### 13.1 What the window says about itself


#### Panel heading
<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 154–155 | key: semanticAnalytics.about.title | shared: iOS+macOS (single edit point) -->

How the corpus’s language sits

<!-- END SOURCE: semanticAnalytics.about.title -->

#### What the map is
<!-- The four verbs a reader can act on — select, lasso, two poles, and (build 42) arriving from a document. “Select”, not “tap”, since #1380: the Mac shows this banner too. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 175–182 | key: semanticAnalytics.about.body.v2 | shared: iOS+macOS (single edit point) -->

Every document in the corpus placed by an AI model’s scoring of the meaning of its language, not by citations or archival provenance. Regions are named by the vocabulary that distinguishes them. Select a document to open it, draw a lasso to keep a set, or pick two poles to visualize the corpus along an axis you set.

<!-- END SOURCE: semanticAnalytics.about.body.v2 -->

#### Experimental standing
<!-- Not hedging. The blind panel that would have graded early-era quality was retired as a gate, so pre-1900 IS unmeasured, and this is the sentence that says so. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticAnalyticsView.swift | lines: 186–190 | key: semanticAnalytics.about.experimental | shared: iOS+macOS (single edit point) -->

Experimental. This is an AI model’s reading of the language, not an editorial fact, and its quality before 1900 has not been measured.

<!-- END SOURCE: semanticAnalytics.about.experimental -->

#### Layout caveat, under the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1634–1638 | key: semanticMap.caveat.map | shared: iOS+macOS (single edit point) -->

Layout preserves local similarity; distances between far regions are not meaningful.

<!-- END SOURCE: semanticMap.caveat.map -->


### 13.2 Regions — a grouping the corpus produced


#### What a region is
<!-- New in build 42. The second sentence is load-bearing: the names are the most distinctive words in a SAMPLE (c-TF-IDF over up to 300 documents), not subject headings, and a reader who takes them for topic labels over-reads every region. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2273–2274 | key: semanticMap.region.whatItIs | shared: iOS+macOS (single edit point) -->

A region is a group the corpus fell into on its own — documents whose meaning an AI model detected to be alike, found by mathematical clustering rather than chosen by a human editor. Its name reflects the most distinctive words in a sample of those documents. It is NOT a subject heading, so read it as a hint at what the group is about rather than a claim about every document in it.

<!-- END SOURCE: semanticMap.region.whatItIs -->

#### Save the region as a working corpus
<!-- New in build 42. The lasso could carry a set off the map and a region could not. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2304–2305 | key: semanticMap.region.save | shared: iOS+macOS (single edit point) -->

Save as Working Corpus

<!-- END SOURCE: semanticMap.region.save -->

#### Confirmation after saving
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2297–2298 | key: semanticMap.region.saved %@ | shared: iOS+macOS (single edit point) -->

Saved as “%@”. Find it under Working Corpora, where it can scope a search.

<!-- END SOURCE: semanticMap.region.saved %@ -->


### 13.3 Slices — a contrast the reader proposed


#### What a slice adds, on the selection card
<!-- New in build 42, and the complement of §13.2. The last sentence is the one that keeps it honest: ANY two differing volumes produce a spread, so a tidy picture is not evidence. Removing it would leave the text selling the feature. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2514–2515 | key: semanticMap.axis.whatItAdds | shared: iOS+macOS (single edit point) -->

On the map no direction has a meaning. A slice gives one that does: left to right becomes how far each document “leans” between two volumes you pick, with time running up the side. Any two volumes should produce a spread, so read it as a contrast you are interested in investigating — not one the corpus found.

<!-- END SOURCE: semanticMap.axis.whatItAdds -->

#### After one pole is set
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2187–2188 | key: semanticMap.axis.needsSecondPole.v2 | shared: iOS+macOS (single edit point) -->

Select a document in a different volume and choose “…to here”. The map will then display every document in the series by where it falls between your chosen documents’ enclosing volumes.

<!-- END SOURCE: semanticMap.axis.needsSecondPole.v2 -->

#### Refused: both documents in one volume
<!-- An axis runs between two volume summaries, not the two documents tapped. Before build 42 this refusal was silent and read as a dead control. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 738–739 | key: semanticMap.axis.sameVolume | shared: iOS+macOS (single edit point) -->

An axis runs between two volumes, and both of these documents are in the same one. Pick a document from a different volume as the second end.

<!-- END SOURCE: semanticMap.axis.sameVolume -->

#### Refused: the two volumes are too alike
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 774–775 | key: semanticMap.axis.tooAlike | shared: iOS+macOS (single edit point) -->

These two volumes were measured as so similar that there is no direction between them to lay the corpus along. Try two volumes you expect to differ.

<!-- END SOURCE: semanticMap.axis.tooAlike -->

#### Refused: no summary for a volume
<!-- Split from the message above in build 42. A missing summary is a property of the build, not of the volumes, and saying 'too alike' there sent the reader to change the wrong thing. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 765–766 | key: semanticMap.axis.noSummary | shared: iOS+macOS (single edit point) -->

This version of the app has no language summary for one of these volumes, so it cannot place an axis between them. Try a different volume as that end.

<!-- END SOURCE: semanticMap.axis.noSummary -->

#### Reading a slice's position
<!-- The bit width is READ FROM THE ARTIFACT, not typed — it said '256-bit' for a whole generation after the corpus moved to 512. Keep the placeholder. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1666–1671 | key: semanticMap.caveat.slice.position.v2 %@ %@ %lld | shared: iOS+macOS (single edit point) -->

Left to right is how far each document leans from %1$@ toward %2$@. The reading is approximate — it comes from a compact %3$lld-bit summary of each document — so treat a clear side as meaningful and a small gap as noise.

<!-- END SOURCE: semanticMap.caveat.slice.position.v2 -->

#### Reading a slice's vertical axis
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 1678–1679 | key: semanticMap.caveat.slice.vertical.v2 | shared: iOS+macOS (single edit point) -->

Up and down is the volume’s coverage midpoint, not each document’s own date.

<!-- END SOURCE: semanticMap.caveat.slice.vertical.v2 -->


### 13.4 Arriving from a document, and leaving by its neighbors


#### Research-rail tile
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1063–1063 | key: researchRail.tile.semanticMap | shared: iOS+macOS (single edit point) -->

On the Map

<!-- END SOURCE: researchRail.tile.semanticMap -->

#### Research-rail tile help
<!-- SOURCE: FRUSExplorer/DocumentView/ResearchRailView.swift | lines: 1064–1065 | key: researchRail.tile.semanticMap.help | shared: iOS+macOS (single edit point) -->

Show where this document sits on the semantic map, among the documents whose language is most like it

<!-- END SOURCE: researchRail.tile.semanticMap.help -->

#### Nearest-documents heading
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2390–2391 | key: semanticMap.nearest.header | shared: iOS+macOS (single edit point) -->

Nearest in language

<!-- END SOURCE: semanticMap.nearest.header -->

#### What the nearest list is drawn from
<!-- The map draws all 552 volumes; this list can only score documents whose vectors are on the device. Saying so is not optional — without it the ten rows read as the ten nearest in the corpus. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2414–2415 | key: semanticMap.nearest.fence | shared: iOS+macOS (single edit point) -->

Drawn only from volumes downloaded on this device — the map shows the whole series, so there may be nearer documents it cannot score yet.

<!-- END SOURCE: semanticMap.nearest.fence -->

#### When the anchor's own volume is absent
<!-- The anchor's own vectors ARE the query, so this is a harder limit than the one above: no vectors for this volume means no comparison at all. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2425–2426 | key: semanticMap.nearest.needsVolume | shared: iOS+macOS (single edit point) -->

Finding nearest documents needs this volume on the device. Download it to compare this document with others.

<!-- END SOURCE: semanticMap.nearest.needsVolume -->

#### A document with no place on the map
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2038–2039 | key: semanticMap.reveal.notOnMap | shared: iOS+macOS (single edit point) -->

This document has no place on the map

<!-- END SOURCE: semanticMap.reveal.notOnMap -->

#### …and why
<!-- About 2,356 display rows — chapter openers, front matter, appendix structure — were never embedded. Ordinary, not a fault, and the wording carries that. -->

<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2042–2043 | key: semanticMap.reveal.notOnMap.detail %@ | shared: iOS+macOS (single edit point) -->

Chapter openers, front matter and appendix material were not included when the map was built, so %@ has no point to show. The rest of the series is here.

<!-- END SOURCE: semanticMap.reveal.notOnMap.detail %@ -->


### 13.5 Related Documents — the semantic axis


#### Axis caption when the weight is 0
<!-- The axis ships OFF. Until build 42 the only prose describing it lived in a feedback screen in Settings ▸ Data & Recovery, so the app's most usable semantic feature was its least discoverable. -->

<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 554–555 | key: related.weights.semantic.off | shared: iOS+macOS (single edit point) -->

Off. Raise it to also match documents whose meaning an AI model measured as alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.

<!-- END SOURCE: related.weights.semantic.off -->

#### Axis caption when the weight is raised
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | lines: 556–557 | key: related.weights.semantic.on | shared: iOS+macOS (single edit point) -->

Matches carry a “Semantic match” score. Consider providing feedback to say whether it helped. Those verdicts are how this axis gets judged.

<!-- END SOURCE: related.weights.semantic.on -->

#### Similar-wording axis name (W-17)
<!-- SOURCE: FRUSExplorer/RelatedDocuments/SimilarityModel.swift | key: related.axis.lexical | shared: iOS+macOS (single edit point) -->

Similar wording (experimental)

<!-- END SOURCE: related.axis.lexical -->

#### Similar-wording axis caption while off
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.weights.lexical.off | shared: iOS+macOS (single edit point) -->

Off. Raise it to also match documents that reuse this one’s distinctive wording. Experimental; searches only the volumes indexed on this device, so results vary with your library.

<!-- END SOURCE: related.weights.lexical.off -->

#### Similar-wording axis caption when the weight is raised
<!-- SOURCE: FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift | key: related.weights.lexical.on | shared: iOS+macOS (single edit point) -->

Matches share this document’s distinctive wording. Searches only the volumes indexed on this device, so results vary with your library.

<!-- END SOURCE: related.weights.lexical.on -->


### 13.6 Settings ▸ Volumes & Storage ▸ Semantic Vectors

*One view mounted by both storage hubs, so every string here is a single edit point.*


#### Section header
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 71–71 | key: settings.vectors.header | shared: iOS+macOS (single edit point) -->

Semantic Vectors

<!-- END SOURCE: settings.vectors.header -->

#### Section footer
<!-- Rewritten in build 42: the previous version opened 'Vectors let the app…', which asks the reader to know what a vector is before the sentence will parse. -->

<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 87–88 | key: settings.vectors.footer.v4 | shared: iOS+macOS (single edit point) -->

The app can find documents on the same subject even when they use none of the same words. Matches appear in the Related Documents panel, in a section of their own. Each volume needs a small extra file for this, which downloads with the volume and is removed with it (unless you disabled this). The feature is experimental, and how well it works on nineteenth-century material is not yet established.

<!-- END SOURCE: settings.vectors.footer.v4 -->

#### Download-with-volumes toggle
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 139–140 | key: settings.vectors.auto.label | shared: iOS+macOS (single edit point) -->

Download With Volumes

<!-- END SOURCE: settings.vectors.auto.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 147–148 | key: settings.vectors.auto.detail.v3 %@ | shared: iOS+macOS (single edit point) -->

Helps Related Documents find documents on the same subject even when they use none of the same words. About %@ per volume.

<!-- END SOURCE: settings.vectors.auto.detail.v3 %@ -->

#### …its accessibility hint
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 162–163 | key: settings.vectors.auto.a11y.v3 | shared: iOS+macOS (single edit point) -->

When this is off, the app downloads none of these files on its own — not with a volume, and not when you open Related Documents or search by meaning. You can still download them all with Download Vectors for Every Volume, above.

<!-- END SOURCE: settings.vectors.auto.a11y.v3 -->

#### Manual download button
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 175–176 | key: settings.vectors.download.label | shared: iOS+macOS (single edit point) -->

Download Missing Vectors

<!-- END SOURCE: settings.vectors.download.label -->

#### …its detail
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 205–206 | key: settings.vectors.download.detail.v3 %lld %@ | shared: iOS+macOS (single edit point) -->

%lld volumes on this device are missing this file. About %@ to download, and Related Documents gets better for those volumes.

<!-- END SOURCE: settings.vectors.download.detail.v3 %lld %@ -->

#### Remove downloaded vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 339–340 | key: settings.vectors.remove.detail.v2 %@ | shared: iOS+macOS (single edit point) -->

Frees %@. Your volumes, notes and search stay exactly as they are. Related Documents keeps working, but semantic matches are unavailable until these files download again.

<!-- END SOURCE: settings.vectors.remove.detail.v2 %@ -->

#### Retry failed downloads
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 312–313 | key: settings.vectors.retry.detail.v2 | shared: iOS+macOS (single edit point) -->

Lets the app try the downloads that failed earlier. Worth using if you were offline before.

<!-- END SOURCE: settings.vectors.retry.detail.v2 -->

#### When the build carries no vectors
<!-- SOURCE: FRUSExplorer/Settings/SemanticStorageSection.swift | lines: 359–360 | key: settings.vectors.unavailable.detail.v2 | shared: iOS+macOS (single edit point) -->

This version of the app cannot match documents by subject, so that part of Related Documents is unavailable. Nothing is wrong with your library.

<!-- END SOURCE: settings.vectors.unavailable.detail.v2 -->

#### Problems — nothing noticed
<!-- This deliberately REFUSES to give a clean bill of health: the app only notices a problem when it downloads or searches a volume, so 'no problems' would claim more than it knows. -->

<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 118–119 | key: settings.vectors.problems.none.v2 | shared: iOS+macOS (single edit point) -->

Nothing has gone wrong since the app opened. The app only notices a problem when it downloads or searches a volume, so this does not mean every file is good.

<!-- END SOURCE: settings.vectors.problems.none.v2 -->

#### A file that did not arrive intact
<!-- SOURCE: FRUSExplorer/Semantic/SemanticStorageReport.swift | lines: 150–151 | key: settings.vectors.error.integrity.v2 | shared: iOS+macOS (single edit point) -->

The file did not arrive intact, so the app discarded it. Downloading again usually fixes this.

<!-- END SOURCE: settings.vectors.error.integrity.v2 -->

---

### 13.7 The map as an exported figure — frames and slices

*W-3 (#1100–#1101) and W-2a gave the map an offscreen figure-export path. These are the method
sentences stamped on what leaves the app; like §10, they must stand alone once the file has
traveled.*

#### The frame sequence's grain sentence
<!-- The publication animation's per-frame claim. The refusal in the second clause is the point:
     a frame lights the documents of the volumes published so far — a scope is a SET OF VOLUMES —
     and a reader will want it to mean "the documents about my subject", which it never does. -->
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapFrameSequence.swift | lines: 120–121 | key: semanticMap.frames.grain -->

Each frame lights every mapped document in the volumes published so far — whole volumes, whatever each document is about.

<!-- END SOURCE: semanticMap.frames.grain -->

#### The slice figure's caveat
<!-- Placeholder note: `%1$@` and `%2$@` are the slice's two pole labels. Keep them, positional
     numbers included. The capitalized SLICE is deliberate emphasis in a plain-text stamp. -->
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | lines: 2998–2999 | key: semanticMap.export.caveat.slice %@ %@ -->

This figure shows a SLICE (%1$@ → %2$@), not a map: the horizontal axis is the slice projection and the vertical axis is time. The map’s region labels are omitted because a slice offers a totally different illustration of the series’s semantic space.

<!-- END SOURCE: semanticMap.export.caveat.slice %@ %@ -->

---

### 13.8 Settings ▸ Data & Recovery ▸ Semantic Match Feedback

*The feedback screen for the "Semantically similar (experimental)" Related Documents axis. Shipped
before build 44 but never carried here. The `unknown` block is the honest center of the screen —
the axis is unmeasured exactly where it is meant to help most — and any edit that softens that
admission is a defect. Short chrome not carried: `settings.semanticFeedback.about.header`,
`.how.header`, `.recorded.header`, `.total`, `.helpful`, `.share`, `.export`, `.clear`,
`.clear.confirm`, `.clear.confirmAction`, `.era.unknown`.*

#### Window title
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 138–139 | key: settings.semanticFeedback.title -->

Semantic Match Feedback

<!-- END SOURCE: settings.semanticFeedback.title -->

#### What the axis is
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 41–49 | key: settings.semanticFeedback.what -->

The “Semantically similar (experimental)” axis in Related Documents finds documents by an AI model’s scoring of the meaning of their language rather than by citations or archival provenance. It contributes to every Related Documents list unless you lower its weight there. It is still experimental: how well it works on nineteenth-century material is not established, which is what the verdicts below are for.

<!-- END SOURCE: settings.semanticFeedback.what -->

#### What is not known
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 51–58 | key: settings.semanticFeedback.unknown -->

What we do not know is how good it is before 1900. The automatic check we can run relies on the editors’ cross-references, and that citation style only becomes common after 1945 — so it reaches barely 500 early documents out of the whole corpus. Nineteenth-century volumes are exactly where this axis is meant to help most, and exactly where nothing has measured it.

<!-- END SOURCE: settings.semanticFeedback.unknown -->

#### How to give feedback
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 67–72 | key: settings.semanticFeedback.how -->

Long-press (or right-click) any related document that shows the magnifier icon, then choose whether the match was helpful. Nineteenth-century verdicts are worth the most.

<!-- END SOURCE: settings.semanticFeedback.how -->

#### The privacy footer
<!-- SOURCE: FRUSExplorer/Settings/SemanticFeedbackView.swift | lines: 101–107 | key: settings.semanticFeedback.privacy -->

Stored on-device and not synced to iCloud. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you gave it. The app sends none of it: to share your verdicts, choose Prepare Feedback File, then Share Feedback File.

<!-- END SOURCE: settings.semanticFeedback.privacy -->

---

## 14. Short strings bumped since the build-42 pass — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### Word cloud

#### The meaningful terms in the chosen scope — a document, vo…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1611–1612 | key: wordcloud.info.shows.detail.v2 -->

The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.

<!-- END SOURCE: wordcloud.info.shows.detail.v2 -->

> Same string also in §5 (Word Cloud) — edit one copy only.

#### Reading every indexed document. On a full library this ta…
<!-- SOURCE: FRUSExplorer/Analytics/WordCloud/WordCloudView.swift | lines: 1509–1510 | key: wordcloud.loading.corpus.v2 -->

Reading every indexed document. On a full library this takes several minutes — you can leave this screen and come back.

<!-- END SOURCE: wordcloud.loading.corpus.v2 -->

### Semantic map lenses

#### Too few source notes
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 139–140 | key: semanticMap.legend.noProvenance.v2 -->

Too few source notes

<!-- END SOURCE: semanticMap.legend.noProvenance.v2 -->

#### Each volume takes the category its source notes name most…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapLens.swift | lines: 99–100 | key: semanticMap.lens.provenance.caption.v2 -->

Each volume takes the category its source notes name most often — a plurality, not a majority, for 73 of the 499 volumes it colors. Volumes with fewer than ten notes are left uncolored.

<!-- END SOURCE: semanticMap.lens.provenance.caption.v2 -->

### Chronology summary line

#### \(editorialNotes) editorial note\(editorialNotes == 1 ? "" : "s")
<!-- SOURCE: FRUSExplorer/Chronology/ChronologyView.swift | lines: 1362–1363 | key: chronology.agg.editorial.v2 -->

\(editorialNotes) editorial note\(editorialNotes == 1 ? "" : "s")

<!-- END SOURCE: chronology.agg.editorial.v2 -->

### Cross-Reference Graph — unprinted archival material (#837, #834)

#### Navigating the graph, and what a teal node is
<!-- The graph's ⓘ "Navigating the graph" item — the retired graph.help.body's successor, repointed
     2026-08-23. Keeps the shipped shape vocabulary: unit and class nodes are CIRCLES like every
     other node (owner's decision 2026-08-19) — the design handoff drew rounded squares, which
     would have inverted the archival Network view's circle=collection / square=class reading.
     #834's last commit put central-file class nodes on this canvas; the body names all three
     citation kinds and says a class node carries its number with NO subject gloss (the filing
     schedule was renumbered in 1950 and only the earlier schedule ships — #828's standard: where
     the table cannot place something, say nothing; the owner's 2026-09-30 wording keeps the
     refusal and drops that reason). The last sentence is a refusal and must
     survive editing: an unmatched citation is left off rather than guessed. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.info.interact.body.v2 | shared: macOS (the iPhone and iPad text is graph.info.interact.body.ios, in §5) -->

Click a node to see its details. Right-click to recenter the graph on that document or open it in the main window. Use drag to pan.

Teal nodes are archival material the editors pointed to in a footnote but did not print. There is no document behind one, so the walk ends there (unless you track the cited record down yourself in the archives).

This graph draws three kinds of archival citation: State Department lot files, collections in the presidential libraries, and the central files cited by decimal number, such as 681.8229/8–2950 — the usual practice in the earlier volumes, and still most archival footnotes in the volumes covering the 1950s. Opening a lot-file or library node shows the collection’s record. A central-file node is labeled by the number alone, with no subject beside it. A citation that was read but could not be matched is left off rather than drawn as a guess.

<!-- END SOURCE: graph.info.interact.body.v2 -->

> Same string also in §5 (About the Graph popover) — edit one copy only.

#### The legend key
<!-- Shown only when the canvas actually carries a unit node — a permanent key for something
     usually absent teaches a vocabulary the reader will not see. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.legend.unit -->

Not printed — opens the collection

<!-- END SOURCE: graph.legend.unit -->

#### A class node's context-menu heading
<!-- #834: the central-file counterpart of graph.context.unprinted. "Central file" and not the
     class number, because the menu heading names the KIND — the number is on the node. -->
<!-- SOURCE: FRUSExplorer/CrossReference/CrossReferenceGraphView.swift | key: graph.context.centralFile -->

Central file, not printed

<!-- END SOURCE: graph.context.centralFile -->


## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.2 Corpus, Person and Cross-Reference Analytics

*Help text, captions and empty states on the three analytics dashboards that §5 does not carry. Several are tooltips — read on hover, not on the page — so they are easy to miss in a review of the screen itself.*

#### Tooltip — Switch to Search pre-filled with this term — and this year…
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.searchHandoffBar | lines: 1312–1313 | key: analytics.handoff.help.v2 -->

Switch to Search pre-filled with this term — and this year range, if a date-based view is active — to see the matching documents. Search opens over document text only, the way the chart counts, with your own notes and summaries left out.

<!-- END SOURCE: analytics.handoff.help.v2 -->

#### Tooltip — Plot raw matching-document counts, or each period’s matches…
<!-- SOURCE: FRUSExplorer/Analytics/AnalyticsView.swift | AnalyticsView.toolbarContent | lines: 3007–3008 | key: analytics.normalize.help -->

Plot raw matching-document counts, or each period’s matches as a share of the indexed documents in that period so a rising corpus size doesn’t masquerade as a rising term.

<!-- END SOURCE: analytics.normalize.help -->

#### Tooltip — Overlay the out-degree distribution (how many citations…
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.distributionControls | lines: 842–843 | key: crossRefAnalytics.outDegree.help -->

Overlay the out-degree distribution (how many citations documents make) on the in-degree histogram.

<!-- END SOURCE: crossRefAnalytics.outDegree.help -->

#### No resolved cross-references are indexed yet. Index more…
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.rankingSection | lines: 879–880 | key: crossRefAnalytics.ranking.empty -->

No resolved cross-references are indexed yet. Index more volumes to build the citation network.

<!-- END SOURCE: crossRefAnalytics.ranking.empty -->

#### How many documents have each inbound-citation count — a few…
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.distributionSection | lines: 937–938 | key: crossRefAnalytics.distribution.subtitle -->

How many documents have each inbound-citation count — a few landmark documents and a long tail. Toggle the out-degree overlay to compare how many citations documents make.

<!-- END SOURCE: crossRefAnalytics.distribution.subtitle -->

#### Not enough cross-volume references are indexed to build a…
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.matrixSection | lines: 1017–1018 | key: crossRefAnalytics.matrix.empty -->

Not enough cross-volume references are indexed to build a heat matrix. Index more volumes.

<!-- END SOURCE: crossRefAnalytics.matrix.empty -->

#### Empty state — The search index is not available. Index at least one…
<!-- SOURCE: FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift | CrossReferenceAnalyticsView.unavailablePlaceholder | lines: 1356–1357 | key: crossRefAnalytics.unavailable.detail -->

The search index is not available. Index at least one volume to build the citation network.

<!-- END SOURCE: crossRefAnalytics.unavailable.detail -->

#### Tooltip — Plot raw mention counts, or each person’s share of all…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.comparisonControls | lines: 894–895 | key: personAnalytics.normalize.help -->

Plot raw tagged mention counts, or each person’s share of all dated documents in that period — so a growing corpus doesn’t masquerade as a rising person.

<!-- END SOURCE: personAnalytics.normalize.help -->

#### Top people by mentions in dated documents, \(…)–\(…). Select a…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsCopy.swift | PersonAnalyticsCopy.rankingSubtitle | lines: 35–36 | key: personAnalytics.ranking.subtitle -->

Top people by tagged mentions in dated documents, \(String(years.lowerBound))–\(String(years.upperBound)). Select a person to compare them below.

*Each year is wrapped in `String(_:)` so it prints 1940, not 1,940 (#1382). Keep the wraps.*

<!-- END SOURCE: personAnalytics.ranking.subtitle -->

#### Empty state — No dated documents in this year range mention indexed…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.rankingSection | lines: 953–954 | key: personAnalytics.ranking.empty.detail -->

No dated documents in this year range mention indexed people. Widen the range or index more volumes.

<!-- END SOURCE: personAnalytics.ranking.empty.detail -->

#### Add up to \(…) people — from the ranking above or the…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.comparisonSection | lines: 1117–1118 | key: personAnalytics.comparison.empty -->

Add up to \(Self.maxComparisonPeople) people — from the ranking above or the search field — to compare how often each is tagged over time.

<!-- END SOURCE: personAnalytics.comparison.empty -->

#### How often \(…) and \(…) are mentioned together over time.
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.relationshipSection | lines: 1156–1157 | key: personAnalytics.relationship.subtitle -->

How often \(selectedPeople[0].canonicalName) and \(selectedPeople[1].canonicalName) are tagged together over time.

<!-- END SOURCE: personAnalytics.relationship.subtitle -->

#### Co-occurrences in dated documents only; documents…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.relationshipSection | lines: 1176–1177 | key: personAnalytics.relationship.caption -->

Co-occurrences in dated documents only; documents tagging mentions of both people. Undated documents cannot be placed on the year axis.

<!-- END SOURCE: personAnalytics.relationship.caption -->

#### Empty state — Search for a person above to center the co-mention network…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.networkContent | lines: 1261–1262 | key: personAnalytics.network.noFocus.detail -->

Search for a person above to center the co-mention network on them. No people are indexed in this range yet.

<!-- END SOURCE: personAnalytics.network.noFocus.detail -->

#### Counts mentions in dated documents only; mentions in…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.trajectoryCaption | lines: 1486–1487 | key: personAnalytics.comparison.caption -->

Counts tagged mentions in dated documents only; tagged mentions in undated documents cannot be placed on the year axis.

<!-- END SOURCE: personAnalytics.comparison.caption -->

#### Tooltip — Switch between the trends dashboard (rankings…
<!-- SOURCE: FRUSExplorer/Analytics/PersonAnalyticsView.swift | PersonAnalyticsView.toolbarContent | lines: 1510–1511 | key: personAnalytics.mode.help -->

Switch between the trends dashboard (rankings, trajectories, relationship dynamics) and the co-mention network graph.

<!-- END SOURCE: personAnalytics.mode.help -->

#### Empty state — \(…) is not co-mentioned with any other indexed person.…
<!-- SOURCE: FRUSExplorer/Analytics/PersonCoMentionGraphView.swift | PersonCoMentionGraphView.body | lines: 1072–1073 | key: personCoMention.empty.detail -->

\(vm.focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently tagged focus person.

<!-- END SOURCE: personCoMention.empty.detail -->

#### VoiceOver hint — Selects or deselects this person. While they are selected,…
<!-- SOURCE: FRUSExplorer/Analytics/PersonCoMentionGraphView.swift | PersonCoMentionGraphView.nodeHitAreas | lines: 1304–1305 | key: personCoMention.node.hint -->

*Read by VoiceOver on a partner node in the co-mention network. It used to say “Tap to see the connection and re-center the network on this person”, but activating a node only selects it, or deselects it when it is already selected; Explore connections, in the dock or the node's menu, is what re-centers.*

Selects or deselects this person. While they are selected, the network shows how many documents they share with the focus person, and Explore connections re-centers it on them. Right-click or long-press for actions

<!-- END SOURCE: personCoMention.node.hint -->

#### Showing the top \(…) co-mentioned people (of \(…)+) by…
<!-- SOURCE: FRUSExplorer/Analytics/PersonCoMentionGraphView.swift | PersonCoMentionGraphViewModel.capDisclosure | lines: 443–444 | key: personCoMention.cap.disclosed -->

*Shown only when the cap bites, so it always reads "Showing the top 24 co-mentioned people (of 25+) …". The "25+" is all the app knows: it asks for one partner more than the 24 it draws, so it can say there are more but not how many.*

Showing the top \(partners.count) co-mentioned people (of \(totalPartnerCount)+) by shared-document count.

<!-- END SOURCE: personCoMention.cap.disclosed -->

#### Showing all \(…) co-mentioned people, sized by shared…
<!-- SOURCE: FRUSExplorer/Analytics/PersonCoMentionGraphView.swift | PersonCoMentionGraphView.legendBar | lines: 1442–1443 | key: personCoMention.cap.all -->

Showing all \(vm.partners.count) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both.

<!-- END SOURCE: personCoMention.cap.all -->

#### What do the numbers mean? Multi-word handling, phrases…
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | FeatureInfoButton.corpusAnalytics | lines: 276–277 | key: analytics.info.help -->

What do the numbers mean? Multi-word handling, phrases, stemming, and how dates are determined.

<!-- END SOURCE: analytics.info.help -->

### 18.6 The semantic map

*The map's own screen text that §13 does not carry: the frame-sequence film's specification line, the slice-position caveat, the empty lasso and nearest-neighbor states, and the VoiceOver summary of the whole map.*

#### \(…) frames: one volume added per frame in PUBLICATION…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapFrameSequence.swift | SemanticMapFrameSequence.provenanceText | lines: 262–263 | key: semanticMap.frames.spec -->

\(frameCount.formatted()) frames: one volume added per frame in PUBLICATION order — the record as it was released, not as it was lived — plus a closing unscoped frame. Out-of-scope documents are ghosted, never removed.

<!-- END SOURCE: semanticMap.frames.spec -->

#### Left to right is how far each document leans from %1$@…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | SemanticMapSpikeView.sliceCaveat | lines: 1673–1677 | key: semanticMap.caveat.slice.position.nobits.v2 %@ %@ -->

Left to right is how far each document leans from %1$@ toward %2$@. The reading is approximate, so treat a clear side as meaningful and a small gap as noise.

<!-- END SOURCE: semanticMap.caveat.slice.position.nobits.v2 %@ %@ -->

#### No nearest documents yet. The vectors for this volume may…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | SemanticMapSpikeView.nearestSection | lines: 2423–2424 | key: semanticMap.nearest.none -->

No nearest documents yet. The vectors for this volume may still be downloading — try again in a moment.

<!-- END SOURCE: semanticMap.nearest.none -->

#### Everything you enclosed is outside the current scope. Widen…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | SemanticMapSpikeView.lassoCard | lines: 2701–2705 | key: semanticMap.lasso.emptyInScope.detail -->

Everything you enclosed is outside the current scope. Widen the scope, or draw around the coloured documents.

<!-- END SOURCE: semanticMap.lasso.emptyInScope.detail -->

#### Semantic map: %1$lld regions covering %2$lld documents.…
<!-- SOURCE: FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift | SemanticMapSpikeView.accessibilitySummary | lines: 3076–3077 | key: semanticMap.a11y.summary %lld %lld %lld -->

Semantic map: %1$lld regions covering %2$lld documents. %3$lld more sit between regions and are not listed. Position shows similarity, not time — distances between far-apart regions are not meaningful.

<!-- END SOURCE: semanticMap.a11y.summary %lld %lld %lld -->
