# EditableContent — Archives — Archival Analytics, Source Explorer, Archives Visits

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §9, §11, §15, §18.3, §18.9, parts of §14. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 267 blocks · no ⚑ wording issues

---

## 9. Archival Analytics — Dashboard Prose

*The Archival Analytics family (`FRUSExplorer/Analytics/`): four modes — Collections, Network, Flows and Your Library — behind one mode picker, on iOS/iPadOS and in the macOS Archival Analytics window. Three of the four read bundled data and render with nothing downloaded; Your Library reads your own index. This section is new in this regeneration.*

---

### 9.1 The mode picker, and what it says when data is missing

#### Mode picker — help text

*Shown under the Mode control on both platforms.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 398–399 | key: archival.mode.help.v2 -->

Switch between the era rankings, the co-citation network, the reference hand-off diagram, and the archival profile of your own indexed volumes.

<!-- END SOURCE: archival.mode.help.v2 -->

---

#### Network mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 470–471 | key: archival.network.unavailable -->

The bundled collection authority is unavailable in this build, so the network cannot be drawn.

<!-- END SOURCE: archival.network.unavailable -->

---

#### Flows mode is unavailable

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 494–495 | key: archival.flows.unavailable -->

The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none.

<!-- END SOURCE: archival.flows.unavailable -->

---

#### Document counts are unavailable, so only the volume weight is offered

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1307–1308 | key: archival.caveats.noUsageIndex -->

Document counts are unavailable in this build — the bundled usage index did not load — so only the volume weight is offered.

<!-- END SOURCE: archival.caveats.noUsageIndex -->

---

#### Unprinted pointers on the classes lens — the self-citation disclosure
<!-- #834: the class lens gained its own pointer vocabulary, so Unprinted pointers is no longer
     withheld there — but most central-file citations name the citing document's own file, so
     without this footnote a reader comparing the two lenses compares two different things. The
     shares are measured (three in five overall, three in four before 1946); do not round them
     away. -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | key: archival.caveats.classPointersSelfCitation -->

Most central-file citations name the file the citing document itself came from — about three in five, and closer to three in four before 1946. They are counted here, because the file was still cited, but they are not movement between archives.

<!-- END SOURCE: archival.caveats.classPointersSelfCitation -->

---

### 9.2 Collections — the ranking

#### While the archival authority loads

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 528–529 | key: archival.collections.loading -->

Reading the archival authority…

<!-- END SOURCE: archival.collections.loading -->

---

#### Ranking caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalCounts.swift | ArchivalCounts.rankingCaption | lines: 92–93 | key: archival.ranking.caption %@ %@ %@ -->

Volumes covering %1$@ — %2$@ of them — draw on %3$@. Bars are colored by who holds the records. *(Interpolated with the era band's title, its volume count grouped, and the units the ranking reaches as a count and its noun — “5,893 classes”, “1 collection” — grouped and singular at one (#1374 review, round 1), where it read “draw on 5893 classes”.)*

<!-- END SOURCE: archival.ranking.caption %@ %@ %@ -->

---

#### Nothing to rank in this era

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1121–1122 | key: archival.ranking.empty -->

No archival units resolved in this era under the current unit and weight.

<!-- END SOURCE: archival.ranking.empty -->

---

#### The caveat block — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1626–1626 | key: archival.caveats.measured -->

Measured here

<!-- END SOURCE: archival.caveats.measured -->

---

#### The method statement, in the info popover

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.method.title | popover item title — the heading above is this string -->

Where the figures come from

<!-- END SOURCE: archival.info.method.title -->

*Moved off the page into **About These Figures** by #838, and unchanged in substance: it is what stops the two counts, the era asymmetry and the name-clustering from being read as defects. The disclosures that change with the controls — what the Central Files filter withheld, and a failed artifact load — stayed on the page and have their own blocks above.*

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 341–342 | key: archival.info.method.detail -->

Archival locations are parsed from the source note on each published document, not read from an archive’s catalog. So they say where the editors drew documents from — an editorial and archival signal, not a census of what the archives hold. Coverage is uneven by era, and switching what the chart shows is the way through it: named collections are scarce before 1948, when central-file numbers carry almost the whole record, and those numbers all but disappear after 1976, when the presidential libraries carry it. Collections are grouped across volumes by name, so when two spellings of one name fail to merge, the same body of records can appear twice under similar names.

<!-- END SOURCE: archival.info.method.detail -->

---

#### The caveat block — what the umbrella filter withheld

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalCounts.swift | ArchivalCounts.umbrellaCaveat | lines: 128–129 | key: archival.caveats.umbrella %@ %@ -->

The Central Files umbrella record is hidden here. On its own it accounts for %1$@ in the %2$@ volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown. *(Interpolated with the umbrella's count in the Count-by weight's own words — “12,067 documents”, “1 volume” — grouped and singular at one (#1374), then the era band's title.)*

<!-- END SOURCE: archival.caveats.umbrella %@ %@ -->

---

### 9.3 Network — one collection and everything cited beside it

#### Before a collection is chosen — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 936–937 | key: archival.network.empty.title -->

Choose a Collection

<!-- END SOURCE: archival.network.empty.title -->

---

#### Before a collection is chosen — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 939–940 | key: archival.network.empty.detail -->

Pick a collection to see which other bodies of records the same volumes drew on.

<!-- END SOURCE: archival.network.empty.detail -->

---

#### Nothing co-cited — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 944–945 | key: archival.network.none.title -->

No Co-Cited Collections

<!-- END SOURCE: archival.network.none.title -->

---

#### Nothing co-cited — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 948–949 | key: archival.network.none.detail.v2 %@ %@ -->

No other collection shares two or more volumes with %1$@ above the current threshold. %2$@

<!-- END SOURCE: archival.network.none.detail.v2 %@ %@ -->

---

#### Nothing co-cited — what to try

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 954–955 | key: archival.network.none.floor -->

The threshold is already at its lowest, so this collection simply shares no volumes with another — choose a more widely cited one.

<!-- END SOURCE: archival.network.none.floor -->

---

#### The info dock, before a node is selected

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 844–845 | key: archival.network.dock.title -->

Select a node to see the link

<!-- END SOURCE: archival.network.dock.title -->

---

#### The info dock — what the rings mean

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- #1478 (2026-09-30): your wording drops the verb, so it reads right at one; the counts now come
     grouped. %1$@ is the number drawn ("1,204"); %2$@ is the count with its noun, from the two forms
     below ("1 node", "3,665 nodes"); %3$@ is the strongest link. -->
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.dockSummarySentence | lines: 882–883 | key: archival.network.dock.summary.v3 %@ %@ %@ -->

%1$@ of the %2$@ above the current threshold drawn. Distance from the center shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (%3$@).

<!-- END SOURCE: archival.network.dock.summary.v3 %@ %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.dockSummarySentence | key: archival.network.dock.nodes.one -->

%@ node

<!-- END SOURCE: archival.network.dock.nodes.one -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.dockSummarySentence | key: archival.network.dock.nodes.many -->

%@ nodes

<!-- END SOURCE: archival.network.dock.nodes.many -->

---

#### The info dock — what a link means

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 911–912 | key: archival.network.dock.grain %lld -->

%lld collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity.

<!-- END SOURCE: archival.network.dock.grain %lld -->

---

#### The info dock — the six-per-custodian cap

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 916–917 | key: archival.network.dock.capped.v2 %lld -->

%lld more are held back so each custodian’s quadrant stays readable; every quadrant keeps its strongest members. Raising the threshold narrows the neighborhood rather than seeing more of it.

<!-- END SOURCE: archival.network.dock.capped.v2 %lld -->

---

#### The info dock — the class sub-arc

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 922–923 | key: archival.network.dock.classes %lld -->

The %lld squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown.

<!-- END SOURCE: archival.network.dock.classes %lld -->

---

#### A selected node's card

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.* `%1$@` is the shared-volume count with its noun ("13 volumes"), `%2$@` the focus collection's name and, in the first sentence, `%3$@` the jointly supplied document count with its noun ("7 documents"). One of the four is shown (#1467): the first when both collections' documents are counted, the other three when the count is unknown — because the partner, or the focus, has no document source note resolving to it, or because the usage index is missing. An unknown count is never printed as 0.

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkData.swift | lines: 393–394 | key: archival.network.card.detail.counted %@ %@ %@ -->

%1$@ cite both this and %2$@. In those volumes the two jointly supplied %3$@ — for each volume, the smaller of their two document counts, summed.

<!-- END SOURCE: archival.network.card.detail.counted %@ %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkData.swift | lines: 410–411 | key: archival.network.card.detail.partnerUncounted %@ %@ -->

%1$@ cite both this and %2$@. No document source note resolves to this collection, so the documents it supplied are not counted.

<!-- END SOURCE: archival.network.card.detail.partnerUncounted %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkData.swift | lines: 405–406 | key: archival.network.card.detail.focusUncounted %@ %@ -->

%1$@ cite both this and %2$@. No document source note resolves to %2$@, so the documents the two supplied are not counted.

<!-- END SOURCE: archival.network.card.detail.focusUncounted %@ %@ -->

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkData.swift | lines: 399–400 | key: archival.network.card.detail.noIndex %@ %@ -->

%1$@ cite both this and %2$@. The documents they supplied are not counted, because the document-usage index could not be loaded.

<!-- END SOURCE: archival.network.card.detail.noIndex %@ %@ -->

---

#### A selected class node's card

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 834–835 | key: archival.network.class.caption.v2 -->

Central-file class — a subject heading inside one of the State Department’s central filing systems, not a collection

<!-- END SOURCE: archival.network.class.caption.v2 -->

---

#### Node accessibility hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 687–688 | key: archival.network.node.hint -->

Select to see this link’s detail; right-click or long-press for actions

<!-- END SOURCE: archival.network.node.hint -->

---

#### Threshold slider — accessibility label

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | lines: 300–301 | key: archival.network.threshold.a11y -->

Minimum link strength, as a share of the strongest link

<!-- END SOURCE: archival.network.threshold.a11y -->

---

### 9.4 Flows — where an editor's cross-reference led

#### What this mode is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 163–164 | key: archival.flows.intro -->

When a FRUS editor annotated one published document by pointing to another, the two documents sometimes came from different archives. Added up across the series, those pointers map the research paths the editors walked between bodies of records.

<!-- END SOURCE: archival.flows.intro -->

---

#### The unfocused view — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 286–287 | key: archival.flows.top.title | shared: iOS+macOS (the same key in both views — edit both) -->

The heaviest hand-offs in the series

<!-- END SOURCE: archival.flows.top.title -->

---

#### The unfocused view — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 319–320 | key: archival.flows.top.caption -->

Choose a focus collection above to see everywhere its documents point.

<!-- END SOURCE: archival.flows.top.caption -->

---

#### Focused, outgoing — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 385–386 | key: archival.flows.title.outgoing -->

Where these documents point

<!-- END SOURCE: archival.flows.title.outgoing -->

---

#### Focused, incoming — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 387–388 | key: archival.flows.title.incoming -->

What points at these documents

<!-- END SOURCE: archival.flows.title.incoming -->

---

#### Focused, outgoing — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 401–402 | key: archival.flows.caption.outgoing %lld %lld -->

%1$lld references run from this collection to others. A further %2$lld stay inside the collection itself and are excluded.

<!-- END SOURCE: archival.flows.caption.outgoing %lld %lld -->

---

#### Focused, incoming — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 403–404 | key: archival.flows.caption.incoming %lld %lld -->

%1$lld references run from other collections to this one. A further %2$lld stay inside the collection itself and are excluded.

<!-- END SOURCE: archival.flows.caption.incoming %lld %lld -->

---

#### A selected hand-off — outgoing detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 571–572 | key: archival.flows.card.detail.outgoing %lld %lld -->

%1$lld references, %2$lld%% of everything this collection hands off.

<!-- END SOURCE: archival.flows.card.detail.outgoing %lld %lld -->

---

#### A selected hand-off — incoming detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 573–574 | key: archival.flows.card.detail.incoming %lld %lld -->

%1$lld references, %2$lld%% of everything handed off to this collection.

<!-- END SOURCE: archival.flows.card.detail.incoming %lld %lld -->

---

#### No hand-offs — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 611–611 | key: archival.flows.none.title -->

No Hand-Offs Recorded

<!-- END SOURCE: archival.flows.none.title -->

---

#### No hand-offs — detail

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 614–615 | key: archival.flows.none.detail %@ %lld %lld -->

No cross-reference runs between %1$@ and another collection in this direction. The cross-reference style these come from postdates 1945. Only %2$lld of the %3$lld volumes in the series carry any of these references.

<!-- END SOURCE: archival.flows.none.detail %@ %lld %lld -->

---

#### The caveat block — the footnote share, stated first

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 689–690 | key: archival.flows.caveats.footnotes %@ -->

%@ of these references are footnotes. While annotating material from one collection, they pointed the reader to material from another. It is not necessarily a relationship between the archives themselves.

<!-- END SOURCE: archival.flows.caveats.footnotes %@ -->

---

#### The caveat block — coverage, dates, and the excluded class axis

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 696–697 | key: archival.flows.caveats.body.v3 %lld %lld %lld %lld -->

Only %1$lld of the %2$lld volumes in the series contribute a single reference. The central-file classes left out of the diagrams carry %3$lld references over %4$lld pairs. These figures cover the whole series regardless of what you have downloaded, and carry no dates, so this mode cannot be narrowed to a period.

<!-- END SOURCE: archival.flows.caveats.body.v3 %lld %lld %lld %lld -->

---

#### The caveat block — why you cannot browse the citations

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.browse.title | popover item title — the heading above is this string -->

You cannot browse these citations

<!-- END SOURCE: archival.info.flows.browse.title -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.browse.detail -->

The app can only list the references for the volumes you have indexed and it has no way to tell which of those are the footnotes this bundled measure is built on. A generated list would disagree with the pre-bundled diagram above it, and nothing on screen would explain why.

<!-- END SOURCE: archival.info.flows.browse.detail -->

---

#### The References picker — first option

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsData.swift | lines: 59–60 | key: archival.flows.layer.printed -->

Between printed documents

<!-- END SOURCE: archival.flows.layer.printed -->

---

#### The References picker — second option

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsData.swift | lines: 62–63 | key: archival.flows.layer.unprinted -->

To unprinted material

<!-- END SOURCE: archival.flows.layer.unprinted -->

---

#### The References picker — its label

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 181–181 | key: archival.flows.layer -->

References

<!-- END SOURCE: archival.flows.layer -->

---

#### Unprinted material — what this layer is for

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 161–162 | key: archival.flows.intro.unprinted -->

FRUS editors often include references to documents they did not print, and say where they are filed. Added up across the series, those pointers show where in the archives the editors sent readers for records they left out.

<!-- END SOURCE: archival.flows.intro.unprinted -->

---

#### Unprinted material — unfocused title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 284–285 | key: archival.flows.top.title.unprinted -->

The heaviest pointers to unprinted material

<!-- END SOURCE: archival.flows.top.title.unprinted -->

---

#### Unprinted material — unfocused caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 317–318 | key: archival.flows.top.caption.unprinted -->

Choose a focus collection above to see everywhere its footnotes send you.

<!-- END SOURCE: archival.flows.top.caption.unprinted -->

---

#### Unprinted material — focused, outgoing title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 379–380 | key: archival.flows.title.unprinted.outgoing -->

Where the footnotes send you

<!-- END SOURCE: archival.flows.title.unprinted.outgoing -->

---

#### Unprinted material — focused, incoming title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 381–382 | key: archival.flows.title.unprinted.incoming -->

Which collections’ footnotes send you here

<!-- END SOURCE: archival.flows.title.unprinted.incoming -->

---

#### Unprinted material — focused, outgoing caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 394–395 | key: archival.flows.caption.unprinted.outgoing %lld %lld -->

%1$lld footnotes on documents from this collection name unprinted material in other collections. A further %2$lld name unprinted material in this collection itself, and these are left out because the diagram only shows where FRUS editors sent you *away* to.

<!-- END SOURCE: archival.flows.caption.unprinted.outgoing %lld %lld -->

---

#### Unprinted material — focused, incoming caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 396–397 | key: archival.flows.caption.unprinted.incoming %lld %lld -->

%1$lld footnotes on documents from other collections name unprinted material in this one. A further %2$lld come from documents already in this collection, and are left out.

<!-- END SOURCE: archival.flows.caption.unprinted.incoming %lld %lld -->

---

#### Unprinted material — the scope caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 650–651 | key: archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld -->

%1$lld citations were found and %2$lld of them matched a known collection, across %3$lld of the %4$lld volumes in the series. What this layer reads, and why the earlier volumes are nearly absent, is in the ⓘ.

<!-- END SOURCE: archival.flows.caveats.unprinted.scope.v2 %lld %lld %lld %lld -->

---

#### Unprinted material — the coverage-span caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 659–660 | key: archival.flows.caveats.unprinted.era %lld %lld -->

The volumes contributing here cover %1$lld to %2$lld.

<!-- END SOURCE: archival.flows.caveats.unprinted.era %lld %lld -->

---

#### Unprinted material — the “Ibid.” caveat

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 667–668 | key: archival.flows.caveats.unprinted.ibid.v2 %@ -->

%@ of these citations come from an “Ibid.”, which the app follows back — a reading rather than a quotation, explained in the ⓘ.

<!-- END SOURCE: archival.flows.caveats.unprinted.ibid.v2 %@ -->

---

#### Unprinted material — what Flows reads, and what it does not

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.scope.title | popover item title — the heading above is this string -->

What Flows reads, and what it does not

<!-- END SOURCE: archival.info.flows.scope.title -->

<!-- #834/#1012: this ⓘ item was rewritten when the central-file channel shipped. The old text
     ("what a ribbon claims") lives on in archival.info.flows.detail; this one now carries the
     scope — three citation kinds — and the self-file share, which is why a citation count reads
     roughly three times the number of pointers that lead somewhere new. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.scope.detail -->

This layer reads three kinds of citation: State Department lot files, collections in the presidential libraries, and central-file numbers such as 763.72/10417. The first two are ways of filing that came in after 1945; the third is how the earlier volumes cite.

Most central-file citations point at the citing document’s own file rather than somewhere else — about three in five, and closer to three in four before 1946. Those are counted where a class is ranked, because the class was still cited, but they are not drawn as movement between separate archival locations. A count of central-file citations is therefore roughly three times the number of pointers that actually lead somewhere different.

<!-- END SOURCE: archival.info.flows.scope.detail -->

---

#### Unprinted material — export axis, outgoing

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 263–264 | key: archival.export.axis.flows.unprinted.outgoing -->

Unprinted material this collection’s footnotes name

<!-- END SOURCE: archival.export.axis.flows.unprinted.outgoing -->

---

#### Unprinted material — export axis, incoming

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalFlowsView.swift | lines: 265–266 | key: archival.export.axis.flows.unprinted.incoming -->

Footnotes naming unprinted material in this collection

<!-- END SOURCE: archival.export.axis.flows.unprinted.incoming -->

---

### 9.5 Your Library — the same questions asked of your own index

#### What this mode is for

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1369–1370 | key: archival.library.intro %lld %lld -->

The archival profile of **your** library — computed from the %1$lld source notes across the %2$lld indexed volumes that carry them, not from the bundled corpus-wide aggregates.

<!-- END SOURCE: archival.library.intro %lld %lld -->

---

#### While your source notes are counted

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1362–1363 | key: archival.library.loading -->

Counting your indexed source notes…

<!-- END SOURCE: archival.library.loading -->

---

#### Composition card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1379–1380 | key: archival.library.composition.title | shared: iOS+macOS (the same key in both views — edit both) -->

Where your documents come from

<!-- END SOURCE: archival.library.composition.title -->

---

#### Composition card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1388–1389 | key: archival.library.composition.caption -->

Every source note in your index, divided among the kinds of archival collection they cite.

<!-- END SOURCE: archival.library.composition.caption -->

---

#### Citation-forms card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1452–1453 | key: archival.library.bands.title | shared: iOS+macOS (the same key in both views — edit both) -->

Citation forms across your volumes

<!-- END SOURCE: archival.library.bands.title -->

---

#### Citation-forms card — caption

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1461–1462 | key: archival.library.bands.caption -->

The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department’s decimal file, through the postwar bureau lot files, to the presidential libraries.

<!-- END SOURCE: archival.library.bands.caption -->

---

#### Your collections card — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1541–1542 | key: archival.library.collections.title | shared: iOS+macOS (the same key in both views — edit both) -->

Your most-cited collections

<!-- END SOURCE: archival.library.collections.title -->

---

#### Your collections card — caption

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1551–1552 | key: archival.library.collections.caption.v2 %lld %lld -->

Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are filing systems rather than collections. Another %2$lld name something the list does not recognize. Neither group is listed here.

<!-- END SOURCE: archival.library.collections.caption.v2 %lld %lld -->

---

#### Your collections card — nothing resolved

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1562–1563 | key: archival.library.collections.empty -->

None of your volumes’ source notes name a collection the bundled authority recognizes.

<!-- END SOURCE: archival.library.collections.empty -->

---

#### Your collections card — row hint

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1595–1596 | key: archival.library.collections.hint -->

Shows the documents in your index drawn from this collection

<!-- END SOURCE: archival.library.collections.hint -->

---

#### Footer — what these figures cover

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1630–1631 | key: archival.library.footer %lld %lld -->

Counted from the %1$lld volumes you have indexed. %2$lld more exist in the series.

<!-- END SOURCE: archival.library.footer %lld %lld -->

---

#### Footer — the two counts the collections list leaves out

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- #838(2) moved the "a source note is not a document" explanation off the page into the ⓘ
     (archival.info.library.detail); the footer keeps only the two measured counts. -->
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1637–1638 | key: archival.library.footer.detail %lld %lld -->

%1$lld notes cite the central files, counted in the composition above. Another %2$lld name something the app’s archival authority list does not recognize.

<!-- END SOURCE: archival.library.footer.detail %lld %lld -->

---

#### Nothing indexed yet — title

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1650–1650 | key: archival.library.empty.title -->

No Source Notes Yet

<!-- END SOURCE: archival.library.empty.title -->

---

#### Nothing indexed yet — detail

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | lines: 1652–1653 | key: archival.library.empty.detail -->

Download and index a volume and this page will show where its documents came from. The Collections mode works without any downloads.

<!-- END SOURCE: archival.library.empty.detail -->

---

### 9.6 The info popover ("About Archival Analytics")

*Shared: `FeatureInfoButton.archivalAnalytics` in `FRUSTheme.swift` feeds both platforms. Edit once.*

#### What you're seeing — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 335–335 | key: archival.info.shows.title -->

What you’re seeing

<!-- END SOURCE: archival.info.shows.title -->

---

#### What you're seeing — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 336–337 | key: archival.info.shows.detail.v2 -->

Where FRUS editors found the documents they published. Collections ranks the archival collections and central-file numbers each era’s volumes drew on. Network puts one collection at the center and groups everything cited alongside it by custodian. Flows maps where an editor’s cross-reference led when it pointed from one document to another. Your Library counts the same things in the volumes you have indexed.

<!-- END SOURCE: archival.info.shows.detail.v2 -->

---

#### The three counts — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 344–344 | key: archival.info.weights.title.v2 -->

The three counts measure different things

<!-- END SOURCE: archival.info.weights.title.v2 -->

> Same string also in §14 (Archival analytics — the three weights) — edit one copy only.

---

#### The three counts — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 345–346 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume’s front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

> Same string also in §14 (Archival analytics — the three weights) — edit one copy only.

---

#### Why Central Files is hidden — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 348–348 | key: archival.info.umbrella.title -->

Why Central Files is hidden

<!-- END SOURCE: archival.info.umbrella.title -->

---

#### Why Central Files is hidden — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 349–350 | key: archival.info.umbrella.detail.v2 -->

The State Department’s Central Files are cited by 157 volumes and supply more than seventeen thousand documents. That is over twice the next-largest collection, and its bar would flatten every other one. So it is hidden by default, and the chart states what it withheld. Turn the chip off to see it. The era-specific Central Files records are never hidden. Those records — Central Files 1964–66, 1967–69 and 1970–73 — are the Subject-Numeric File’s blocks of years, as the later volumes cite them through the National Archives. Your Library counts the same citations under the Subject-Numeric File instead of listing them as collections.

<!-- END SOURCE: archival.info.umbrella.detail.v2 -->

---

#### A flow is an editor's footnote — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 352–352 | key: archival.info.flows.title -->

A flow is an editor’s footnote, not an archive’s

<!-- END SOURCE: archival.info.flows.title -->

---

#### A flow is an editor's footnote — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 358–359 | key: archival.info.flows.detail.v2 -->

About 95% of the references behind Flows are footnotes. A linking ribbon means the editors annotated material from one collection with a reference directed toward material from another. It does not mean the two archives cite each other. Coverage is uneven because the cross-reference style this data comes from postdates 1945. Most volumes carry none, and the chart states how many do.

<!-- END SOURCE: archival.info.flows.detail.v2 -->

---

#### Your Library's rule — title
<!-- #838(2): Your Library's rule, moved off the page into this ⓘ item. The two counts it used to
     carry stay on the chart footer (archival.library.footer.detail) — they are measurements of
     the reader's own library; this is the rule they obey. -->

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.library.title -->

A source note is not a document

<!-- END SOURCE: archival.info.library.title -->

---

#### Your Library's rule — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.library.detail.v2 -->

Only documents whose editors recorded where the original was found appear in Your Library. So its total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records; notes citing the central files — the decimal file, the Subject-Numeric File and the Central Foreign Policy File — cite a filing system rather than a collection and are counted in the composition instead. Your Library counts only what you have indexed — Collections does not, and does not change with your downloads.

<!-- END SOURCE: archival.info.library.detail.v2 -->

---

#### Collections and classes — title

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 394–394 | key: archival.info.units.title -->

Collections and classes are different things

<!-- END SOURCE: archival.info.units.title -->

---

#### Collections and classes — detail

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 395–396 | key: archival.info.units.detail.v2 -->

A named collection is a body of records with a custodian. A central-file class is a subject heading inside one of the State Department’s central filing systems — 763.72 in the decimal file for the European War, POL 27 VIET S in the Subject-Numeric File for the war in South Vietnam. The two are never mixed in one ranking. Classes are ranked at one depth: a decimal file number stands for itself, while subject-numeric designators are grouped to their category and number, and a grouped row opens to the exact designators underneath it. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.

<!-- END SOURCE: archival.info.units.detail.v2 -->

---

---

## 11. Source Explorer — Panel Prose

*The explanatory notes inside Source Explorer: what a citation resolved to, what it did not, and what a researcher should do about it. §5 already carries the Source Explorer info popover; this section carries the panels themselves. Almost every key here exists twice — once in `SourceExplorerView.swift` (iOS) and once in `MacSourceExplorerView.swift` — so a revision has to be applied to both. This section is new in this regeneration.*

---

### 11.1 When there is no source note, or no key to look one up by

#### No source note on this document

*Shown while the pre-1906 check runs, when it found no roll, and when it resolved. When the check did not run, or does not apply, the left column shows one of the two blocks below instead.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1825–1826 | key: source.explorer.noNote.body -->

This document has no archival source note. Its likely filing is predicted from its dateline and FRUS chapter — see the resolution on the right.

<!-- END SOURCE: source.explorer.noNote.body -->

---

#### No source note — the pre-1906 check ran and found no roll

*Shown only in that one state. While the check runs, when it could not run, and for a document from 1906 on, the section shows the sentences in the blocks that follow instead — each of which would make this one false.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1794–1795 | key: source.explorer.noNote.detail | shared: iOS+macOS (the same key in both views — edit both) -->

This document carries no archival source note, and its exact filing couldn’t be predicted from its dateline and FRUS chapter.

<!-- END SOURCE: source.explorer.noNote.detail -->

---

#### No source note — the left column, when the check did not run (macOS)

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1819–1820 | key: source.explorer.noNote.body.notChecked -->

This document has no archival source note, and its likely filing has not been checked — the right column says why.

<!-- END SOURCE: source.explorer.noNote.body.notChecked -->

---

#### No source note — the left column, for a document from 1906 on (macOS)

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1822–1823 | key: source.explorer.noNote.body.notApplicable -->

This document has no archival source note. Roll suggestions cover only documents from before 1906.

<!-- END SOURCE: source.explorer.noNote.body.notApplicable -->

---

#### Pre-1906 check — while it runs

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1211–1212 | key: source.explorer.countrySeries.state.loading | shared: iOS+macOS (single edit point) -->

Checking the digitized pre-1906 records for this document…

<!-- END SOURCE: source.explorer.countrySeries.state.loading -->

---

#### Pre-1906 check — a document from 1906 on, where it does not apply

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1217–1218 | key: source.explorer.countrySeries.state.notApplicable | shared: iOS+macOS (single edit point) -->

This document carries no archival source note. Roll suggestions cover documents from before 1906, when the Department filed its correspondence by country, so none is offered for a later document.

<!-- END SOURCE: source.explorer.countrySeries.state.notApplicable -->

---

#### Pre-1906 check not run — the search index is still starting

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1162–1163 | key: source.explorer.countrySeries.state.notChecked.indexStarting | shared: iOS+macOS (single edit point) -->

Not checked yet — the search index is still starting. This section fills in when it is ready.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.indexStarting -->

---

#### Pre-1906 check not run — no document to look up

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1165–1166 | key: source.explorer.countrySeries.state.notChecked.noDocumentIdentity | shared: iOS+macOS (single edit point) -->

Not checked — Source Explorer was opened without a document to look up, so there is no dateline or FRUS chapter to read.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.noDocumentIdentity -->

---

#### Pre-1906 check not run — the search index could not be read

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1168–1169 | key: source.explorer.countrySeries.state.notChecked.indexReadFailed | shared: iOS+macOS (single edit point) -->

Not checked — the search index could not be read. Close Source Explorer and open it again.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.indexReadFailed -->

---

#### Pre-1906 check not run — the document is not indexed

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1171–1172 | key: source.explorer.countrySeries.state.notChecked.documentNotIndexed | shared: iOS+macOS (single edit point) -->

Not checked — this document is not in the search index on this device, so its dateline and FRUS chapter could not be read.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.documentNotIndexed -->

---

#### Pre-1906 check not run — no dateline

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1174–1175 | key: source.explorer.countrySeries.state.notChecked.noDateline | shared: iOS+macOS (single edit point) -->

Not checked — this document prints no dateline, and the dateline is what places a pre-1906 document in a series.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.noDateline -->

---

#### Pre-1906 check not run — no year

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1177–1178 | key: source.explorer.countrySeries.state.notChecked.noYear | shared: iOS+macOS (single edit point) -->

Not checked — this document’s dateline gives no year, so no roll’s dates can be compared.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.noYear -->

---

#### Pre-1906 check not run — the roll list did not load

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1180–1181 | key: source.explorer.countrySeries.state.notChecked.centralFilesIndexMissing | shared: iOS+macOS (single edit point) -->

Not checked — the app’s list of digitized rolls could not be loaded.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.centralFilesIndexMissing -->

---

#### Pre-1906 check not run — no chapter structure

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1183–1184 | key: source.explorer.countrySeries.state.notChecked.noVolumeStructure | shared: iOS+macOS (single edit point) -->

Not checked — this volume’s chapters are not in the search index on this device, and the chapter is what names the country.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.noVolumeStructure -->

---

#### Pre-1906 check not run — the document is not in its volume's chapters

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1186–1187 | key: source.explorer.countrySeries.state.notChecked.documentNotInStructure | shared: iOS+macOS (single edit point) -->

Not checked — this document was not found among its volume’s chapters, so no chapter names its country.

<!-- END SOURCE: source.explorer.countrySeries.state.notChecked.documentNotInStructure -->

---

#### No source note — the diplomatic series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1836–1837 | key: source.explorer.noNote.series.diplomatic | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are held in the country-arranged diplomatic series (Despatches and Instructions) at the National Archives, Record Group 59.

<!-- END SOURCE: source.explorer.noNote.series.diplomatic -->

---

#### No source note — the numerical file

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1839–1840 | key: source.explorer.noNote.series.numerical | shared: iOS+macOS (the same key in both views — edit both) -->

Documents of this era are filed in the 1906–1910 Numerical File at the National Archives, Record Group 59, arranged by case number rather than by country or date.

<!-- END SOURCE: source.explorer.noNote.series.numerical -->

---

#### The note parsed, but carries no lookup key

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1593–1594 | key: source.explorer.noKey.explanation.mac | shared: macOS (a key of its own since #1483; the iOS text is the next block) -->

A free NARA Catalog API key is needed to search for lot file and Presidential Library records. Add your key in Settings ▸ Connections.

<!-- END SOURCE: source.explorer.noKey.explanation.mac -->

#### The iPhone and iPad text (`SourceExplorerView.swift`, key `source.explorer.noKey.explanation`)

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | key: source.explorer.noKey.explanation | shared: iOS (the Mac text is in the block above) -->

A free NARA Catalog API key is required to search for lot file and Presidential Library records. Add your key in Settings → Connections.

<!-- END SOURCE: source.explorer.noKey.explanation (iOS) -->

---

#### The citation form was not recognized

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1189–1190 | key: source.explorer.unrecognized.explanation | shared: iOS+macOS (one text in both views since #1483; SourceExplorerView.swift declares it too — the raw note sits under the Source Note heading in each) -->

The source note format was not recognized. Its raw text is shown under Source Note. Automated NARA Catalog resolution is unavailable for this entry.

<!-- END SOURCE: source.explorer.unrecognized.explanation -->

---

#### The macOS window with no document selected

<!-- SOURCE: FRUSExplorer/App/SupportingViews.swift | lines: 2158–2159 | key: source.explorer.window.empty.detail -->

*#1380: it said “tap Sources in the toolbar”. On the Mac the reader clicks, and Sources is a tile in the document’s Research rail, not a toolbar item.*

Open a document with a source note, then click Sources in its Research rail. Or switch to Collections to browse the archival collections FRUS cites.

<!-- END SOURCE: source.explorer.window.empty.detail -->

---

### 11.2 Central files — decimal and subject-numeric

#### Requesting a decimal-file record from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 717–718 | key: source.explorer.centralFiles.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, give them the decimal file number above. Add any telegram serial number, the from/to information, and the document’s date from the source note. Archivists use these details to find the record within the file.

<!-- END SOURCE: source.explorer.centralFiles.cite.note -->

---

#### Which filing period a decimal number belongs to

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2199–2200 | key: source.explorer.decimalPeriod.hint | shared: iOS+macOS (the same key in both views — edit both) -->

Purport indexes and the filing manual for this period are available on the linked NARA page. Box lists are available on-site at the National Archives at College Park.

<!-- END SOURCE: source.explorer.decimalPeriod.hint -->

---

#### Requesting a Subject-Numeric File record from NARA

*#1543: a Subject-Numeric citation (February 1963–1973) has its own panel in every wording, through the Department or through the National Archives. Its rows are short labels with no block: “State Dept. Subject-Numeric File (February 1963–1973)”, “File Designation”, “File Years” and, for the Filing Period row, “February 1963–1973 (Subject-Numeric File)”.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 637–638 | key: source.explorer.subjectNumeric.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, give them the file designation above and the block of years it was filed in (1963, 1964–66, 1967–69 or 1970–73). Add any telegram or airgram number, the from/to information, and the document’s date from the source note. NARA asks that a central-file citation name the file designation, not a folder or a box.

<!-- END SOURCE: source.explorer.subjectNumeric.cite.note -->

---

#### Where the Subject-Numeric File's handbooks and box lists are

*The second sentence is yours, from the decimal-file hint above.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 688–689 | key: source.explorer.subjectNumeric.hint | shared: iOS+macOS (the same key in both views — edit both) -->

The filing handbooks are on the linked NARA page: the 1963 handbook for 1963 and the 1965 handbook for 1964–1973. Box lists are available on-site at the National Archives at College Park.

<!-- END SOURCE: source.explorer.subjectNumeric.hint -->

---

#### The Central Foreign Policy File

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1164–1165 | key: source.explorer.cfpf.note | shared: iOS+macOS (the same key in both views — edit both) -->

CFPF records are available on microfilm (P-Reels, D-Reels, N-Reels) printouts at NARA and as P-Reel index descriptions and electronic telegrams in the AAD database. No API key is required for either resource.

<!-- END SOURCE: source.explorer.cfpf.note -->

---

#### Requesting a CFPF record from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 879–880 | key: source.explorer.cfpf.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

To request the original record from NARA, give them the file identifier above. Add any telegram channel and serial numbers, the from/to information, and the document’s date from the source note.

<!-- END SOURCE: source.explorer.cfpf.cite.note -->

---

#### The 1906–1910 Numerical File — roll found

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2134–2135 | key: source.explorer.numericalFile.found | shared: iOS+macOS (the same key in both views — edit both) -->

These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case.

<!-- END SOURCE: source.explorer.numericalFile.found -->

---

#### The 1906–1910 Numerical File — no roll covers it

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2113–2114 | key: source.explorer.numericalFile.gap | shared: iOS+macOS (the same key in both views — edit both) -->

No digitized roll directly covers this file number. Use the Card Index to confirm the case number, then browse the Numerical File series.

<!-- END SOURCE: source.explorer.numericalFile.gap -->

---

### 11.3 Lot files

#### Requesting a lot file from NARA

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1399–1400 | key: source.explorer.lotFile.cite.note | shared: iOS+macOS (the same key in both views — edit both) -->

When requesting the original records from NARA, cite the HMS/MLR entry number together with the lot number — it is the identifier archives staff use to locate the series.

<!-- END SOURCE: source.explorer.lotFile.cite.note -->

---

#### Resolved from the bundled lot index

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1404–1405 | key: source.explorer.lotFile.bundled.note | shared: iOS+macOS (the same key in both views — edit both) -->

Resolved from the bundled index — no API key required. Records may be described at the series level rather than digitized page-by-page.

<!-- END SOURCE: source.explorer.lotFile.bundled.note -->

---

#### HMS / MLR entry numbers

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1385–1386 | key: source.explorer.lotFile.hmsMlr.series.note | shared: iOS+macOS (the same key in both views — edit both) -->

These entry numbers identify the enclosing file series, not this specific file unit.

<!-- END SOURCE: source.explorer.lotFile.hmsMlr.series.note -->

---

#### A possible match, not a confirmed one

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1474–1475 | key: source.explorer.curatedLot.possible.note | shared: iOS+macOS (the same key in both views — edit both) -->

This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it.

<!-- END SOURCE: source.explorer.curatedLot.possible.note -->

---

#### Several candidate lots

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1526–1527 | key: source.explorer.curatedLot.candidates.note | shared: iOS+macOS (the same key in both views — edit both) -->

NARA did not accession this lot as a single series, so no one record is the answer. Review the candidates against the document’s date and type and consult with NARA archivist staff.

<!-- END SOURCE: source.explorer.curatedLot.candidates.note -->

---

#### A lot file NARA divided across several series

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/LotClaimantsIndex.swift | lines: 143–144 | key: source.explorer.dividedLot.rationale %lld -->

NARA divided this lot file across %lld series. Each series lists the lot among its own control numbers, so each holds part of the records this citation names. The citation alone does not say which one. Consult with NARA archivist staff for further assistance.

<!-- END SOURCE: source.explorer.dividedLot.rationale %lld -->

---

#### A divided lot on a volume's Sources outline

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/Browser/VolumeSourcesView.swift | lines: 322–323 | key: browser.sources.lotFile.divided %lld -->

NARA divides this lot across %lld series — open Collection to see them.

<!-- END SOURCE: browser.sources.lotFile.divided %lld -->

This line replaces the catalogue link and the `HMS/MLR Entry` caption on a Sources row whose lot NARA divided. The app withholds those rather than naming one of several claiming series (#1205); the claimants themselves are listed in the Collection sheet the row's own button opens.

---

### 11.4 Presidential libraries and other repositories

#### Presidential library — provenance

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 213–217 | key: source.explorer.presLib.offline.provenance -->

Matched against the National Archives’ own description of this library, from the bundled catalog — no API key or network required.

<!-- END SOURCE: source.explorer.presLib.offline.provenance -->

---

#### Presidential library — collection only

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 183–188 | key: source.explorer.presLib.offline.collectionOnly -->

The collection is identified, but the citation does not name one of its \(c.series.count) series unambiguously. Open the collection record to find the series cited.

<!-- END SOURCE: source.explorer.presLib.offline.collectionOnly -->

---

#### Presidential library — several candidate series

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/PresidentialLibraryOutcome.swift | lines: 191–197 | key: source.explorer.presLib.offline.candidates -->

The collection is identified. The series named in the citation matches \(candidates.count) of its records, and \(shown) of those are listed below. No single record is the answer on its own, so check the titles and dates and consider consulting archivist staff at the library before citing.

<!-- END SOURCE: source.explorer.presLib.offline.candidates -->

---

#### A repository outside NARA's custody

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 823–830 | key: source.explorer.nara.outsideCustody | shared: macOS (SourceExplorerView.swift declares the same key and wording with its own placeholder — its iOS block follows) -->

\(library) is not a National Archives repository, so the NARA Catalog has no record of this collection. A search on the collection name alone can return results that look authoritative but are not. None are shown here.

<!-- END SOURCE: source.explorer.nara.outsideCustody -->

#### The same key on iPhone and iPad (`SourceExplorerView.swift`)

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | key: source.explorer.nara.outsideCustody | shared: iOS (the Mac text is in the block above) -->

\(repository) is not a National Archives repository, so the NARA Catalog has no record of this collection. A search on the collection name alone can return results that look authoritative but are not. None are shown here.

<!-- END SOURCE: source.explorer.nara.outsideCustody (iOS) -->

> The two views word this identically but name the repository differently in code — `\(library)` on the Mac, `\(repository)` on iPhone and iPad — so edit both blocks, keeping each one's own placeholder.

---

#### A foreign archive

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1131–1132 | key: source.explorer.foreignArchive.note | shared: iOS+macOS (the same key in both views — edit both) -->

Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access.

<!-- END SOURCE: source.explorer.foreignArchive.note -->

---

#### Previously published material

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.note | shared: one definition since W-11 — PublishedSourceGuidanceView renders this for BOTH platforms when the citation grammar declines the note -->

This document was previously published. Consult the cited publication for the original source.

<!-- END SOURCE: source.explorer.published.note -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.lookFor -->

*Interpolated with the extracted designation — a series number, an issue date and page, or a president–year–page. Keep the `\(designation)` placeholder.*

Look for \(designation) in this publication.

<!-- END SOURCE: source.explorer.published.lookFor -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.linkStale -->

*Shown under the link button only when the table’s verification stamp is older than the freshness window. Interpolated with the stamp date — keep the `\(…)` placeholder.*

Link last verified \(checked.formatted(date: .abbreviated, time: .omitted)).

<!-- END SOURCE: source.explorer.published.linkStale -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.treaties -->

Open the U.S. treaties research guide (Library of Congress)

<!-- END SOURCE: source.explorer.published.link.treaties -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.bulletin -->

Browse the Bulletin on the Internet Archive

<!-- END SOURCE: source.explorer.published.link.bulletin -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.link.publicPapers -->

Browse the Public Papers on GovInfo

<!-- END SOURCE: source.explorer.published.link.publicPapers -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.treatySeries -->

Treaty Series (Department of State)

<!-- END SOURCE: source.explorer.published.family.treatySeries -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.eas -->

Executive Agreement Series (Department of State)

<!-- END SOURCE: source.explorer.published.family.eas -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.bulletin -->

Department of State Bulletin

<!-- END SOURCE: source.explorer.published.family.bulletin -->

<!-- SOURCE: FRUSExplorer/SourceExplorer/PublishedSourceLinkTable.swift | key: source.explorer.published.family.publicPapers -->

Public Papers of the Presidents

<!-- END SOURCE: source.explorer.published.family.publicPapers -->

---

#### Intelligence records

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 996–997 | key: source.explorer.cia.note -->

CIA records are not in the NARA Catalog. The CREST database (cia.gov/readingroom) holds declassified CIA documents, including released operational files and historical collections.

<!-- END SOURCE: source.explorer.cia.note -->

---

#### A named file series

*Mac. Since build 49 this wording and the next block's both live in `NamedFileSeriesRouting.swift`, shared by the two Source Explorer views; the next block shows instead when the series' name opens with the agency holding it.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift | lines: 323–324 | key: source.explorer.namedSeries.note -->

A named file series cited without a lot number. The citation does not state the holding repository, so no automated NARA Catalog query is available.

<!-- END SOURCE: source.explorer.namedSeries.note -->

---

#### A named file series the citation places with an agency

*Mac. New in build 49 (#1514): a Department of State series that is not the central files (the INR/IL, INR–NIE, Bundy and USUN files) and another agency's own series (`National Security Council, Carter Intelligence Files`) name their holder, so "does not state the holding repository" was false for them. Interpolated with the agency — the Department of State, the National Security Council, the Department of Defense. Keep the `\(holder)` placeholder; the sentence supplies "the" before it. Beside this note the provenance column no longer offers the link "Department of State records at the National Archives" (review round 1): the citation places the Department's own series it names with the Department and does not say whether any was accessioned since, and another agency's are not State records.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift | lines: 320–321 | key: source.explorer.namedSeries.note.held -->

A file series the citation places with the \(holder), cited without a lot number, so no automated NARA Catalog query is available.

<!-- END SOURCE: source.explorer.namedSeries.note.held -->

---

#### What a named file series is

*iPhone and iPad.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift | lines: 313–314 | key: source.explorer.namedSeries.explainer -->

A named file series cited without a lot number. The repository is not stated in the citation.

<!-- END SOURCE: source.explorer.namedSeries.explainer -->

---

#### What a named file series is, when the citation names its agency

*iPhone and iPad. New in build 49 (#1514), the twin of the Mac block above. Keep the `\(holder)` placeholder. Under it the panel no longer offers the link "Department of State records at the National Archives" (review round 1), as on the Mac.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/NamedFileSeriesRouting.swift | lines: 310–311 | key: source.explorer.namedSeries.explainer.held -->

A file series the citation places with the \(holder), cited without a lot number.

<!-- END SOURCE: source.explorer.namedSeries.explainer.held -->

---

#### A country series

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1682–1683 | key: source.explorer.countrySeries.intro | shared: iOS+macOS (the same key in both views — edit both) -->

This document predates the 1906 Numerical File. Based on its dateline and FRUS chapter, it was likely filed in the digitized series below — open a roll and review the images for the document’s date.

<!-- END SOURCE: source.explorer.countrySeries.intro -->

---

#### A country series — the serial, on a despatch

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1104–1105 | key: source.explorer.countrySeries.serial %@ | shared: iOS+macOS (single edit point) -->

Despatch No. %@

*%@ is the serial FRUS prints above the document.*

<!-- END SOURCE: source.explorer.countrySeries.serial %@ -->

---

#### A country series — the serial's caption, on a despatch

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1119–1120 | key: source.explorer.countrySeries.serial.caption | shared: iOS+macOS (single edit point) -->

FRUS prints this number above the document — the post’s own serial for it. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.

<!-- END SOURCE: source.explorer.countrySeries.serial.caption -->

---

#### A country series — the serial, on an instruction

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1101–1102 | key: source.explorer.countrySeries.serial.instruction %@ | shared: iOS+macOS (single edit point) -->

Instruction No. %@

<!-- END SOURCE: source.explorer.countrySeries.serial.instruction %@ -->

---

#### A country series — the serial's caption, on an instruction

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1116–1117 | key: source.explorer.countrySeries.serial.instruction.caption | shared: iOS+macOS (single edit point) -->

FRUS prints this number above the document — the Department’s own number for its instruction to the post. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.

<!-- END SOURCE: source.explorer.countrySeries.serial.instruction.caption -->

---

#### A country series — the serial, on a note or letter

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1107–1108 | key: source.explorer.countrySeries.serial.neutral %@ | shared: iOS+macOS (single edit point) -->

No. %@

<!-- END SOURCE: source.explorer.countrySeries.serial.neutral %@ -->

---

#### A country series — the serial's caption, on a note or letter

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1122–1123 | key: source.explorer.countrySeries.serial.neutral.caption | shared: iOS+macOS (single edit point) -->

FRUS prints this number above the document — its sender’s own serial for it. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.

<!-- END SOURCE: source.explorer.countrySeries.serial.neutral.caption -->

---

#### A country series — why an instruction is Likely

<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | lines: 1382–1383 | key: centralFiles.rationale.instructionToChiefOfMission %@ %@ %@ %@ | shared: iOS+macOS (single edit point) -->

From the Department of State to %1$@, U.S. %2$@ to %3$@ (%4$@): an instruction.

*In order: the chief of mission's name as the Office of the Historian's register prints it, their role, the FRUS chapter's country, and the years of their tenure there.*

<!-- END SOURCE: centralFiles.rationale.instructionToChiefOfMission %@ %@ %@ %@ -->

---

### 11.5 The Paris Peace Conference records (RG 256)

#### Why these are not RG 59

<!-- SOURCE: FRUSExplorer/SourceExplorer/ParisPeaceRecords.swift | lines: 170–175 | key: source.explorer.parisPeace.provenance -->

The American Commission to Negotiate Peace kept its own decimal file, separate from the State Department’s. These records are Record Group 256, so the RG 59 central-file finding aids and filing manual do not describe them.

<!-- END SOURCE: source.explorer.parisPeace.provenance -->

---

#### Why the panel will not name a roll

<!-- SOURCE: FRUSExplorer/SourceExplorer/ParisPeaceRecords.swift | lines: 185–191 | key: source.explorer.parisPeace.rolls -->

Microfilm publication M820 reproduces the series. Most of its 538 file units are digitized, each covering a range of decimal numbers. This panel does not say which one holds this document. The ranges overlap and are not always continuous, so use the index below to find it.

<!-- END SOURCE: source.explorer.parisPeace.rolls -->

---

### 11.6 Digitized scans

#### Only the class is known — iOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 1166–1171 | key: source.explorer.scans.classOnly -->

NARA has scanned \(count) file ranges in decimal class \(cls), but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnly -->

---

#### Only the class is known — macOS

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2345–2350 | key: source.explorer.scans.classOnlyMac -->

NARA has scanned \(count) file ranges in this decimal class, but none of them covers \(fileIdentifier). The scans for this file are partial.

<!-- END SOURCE: source.explorer.scans.classOnlyMac -->

---

#### Several ranges contain this file

*Interpolated at runtime — keep every `\(…)` placeholder and every `%lld` / `%@` exactly as written, including the positional numbers.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2333–2339 | key: source.explorer.scans.multiple | shared: iOS+macOS (the same key in both views — edit both) -->

\(ranges.count) scanned file ranges contain \(fileIdentifier). They are listed narrowest first. NARA digitized this file in overlapping sets, so the widest range is not wrong. The narrowest is simply the most specific.

<!-- END SOURCE: source.explorer.scans.multiple -->

---

#### What a scan range does and does not tell you

<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | lines: 1184–1188 | key: source.explorer.scans.caveat -->

This is the scan of the file range the citation falls in, not of this document. The document is somewhere inside it.

<!-- END SOURCE: source.explorer.scans.caveat -->

---

### 11.7 Catalog evidence and manual searches

#### Matched on the record group alone

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 156–161 | key: source.explorer.nara.candidates.recordGroupOnly -->

Matched by keyword within record group \(recordGroup). The record group is the one cited; nothing here ties these records to the series cited. Check the series title and dates before citing.

<!-- END SOURCE: source.explorer.nara.candidates.recordGroupOnly -->

---

#### Matched on the collection name alone

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 163–168 | key: source.explorer.nara.candidates.collectionNameOnly -->

Searched on the repository and collection names only — no catalog identifier constrains these results to the collection cited. Treat them as leads, and prefer the finding aid above.

<!-- END SOURCE: source.explorer.nara.candidates.collectionNameOnly -->

---

#### An unverified manual search

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 1273–1274 | key: source.explorer.manualSearch.unverified.detail -->

From a manual search. Not checked against the cited lot number or record group.

<!-- END SOURCE: source.explorer.manualSearch.unverified.detail -->

---

#### What an export says about a manual search

<!-- SOURCE: FRUSExplorer/SourceExplorer/CatalogQueryEvidence.swift | lines: 129–133 | key: source.explorer.manualSearch.exportCaveat -->

NOTE: Result of a manual free-text search. It has not been checked against the cited lot number or record group.

<!-- END SOURCE: source.explorer.manualSearch.exportCaveat -->

---

### 11.8 Related collections

#### Why these collections are listed together

<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | lines: 703–704 | key: collection.detail.related.footer -->

These collections appear alongside this one in the same volumes’ source lists. Ranking uses the overlap coefficient, so a broad umbrella record does not dominate. The link is at volume level: both collections fed the same compilation. It does not mean the same documents cite both.

<!-- END SOURCE: collection.detail.related.footer -->

---

#### No related collections

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2588–2589 | key: source.explorer.related.empty.noNeighbors | shared: iOS+macOS (the same key in both views — edit both) -->

No other indexed documents cite this archival source. Index more volumes to surface related documents.

<!-- END SOURCE: source.explorer.related.empty.noNeighbors -->

---

#### This citation matched no collection

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2597–2598 | key: source.explorer.related.empty.unmatched | shared: iOS+macOS (the same key in both views — edit both) -->

This source note doesn’t cite a recognized lot file, central file, or presidential library, so related documents can’t be matched.

<!-- END SOURCE: source.explorer.related.empty.unmatched -->

---

#### A Subject-Numeric citation, and no other document matched to its file

*Shown under the Subject-Numeric File panel when the Archival Neighbors list is empty and the citation's class (`POL 27 VIET S`) was searched for: a note worded through the National Archives whose designation the app reads as a class.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2591–2592 | key: source.explorer.related.empty.subjectNumeric | shared: iOS+macOS (the same key in both views — edit both) -->

This source note cites the Subject-Numeric File. No other indexed document was matched to the same file. Index more volumes to surface related documents.

<!-- END SOURCE: source.explorer.related.empty.subjectNumeric -->

---

#### A Subject-Numeric citation the app cannot match on

*Shown under the same panel when there was nothing to search for: a designation the app does not read as a class (`POL FR-US`, `ORG 4–COMM`, `AID (US) S VIET`), a citation that gives only its block of years, or a note whose first sentence the app reads another way. Indexing more volumes does not change it.*

<!-- SOURCE: FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift | lines: 2594–2595 | key: source.explorer.related.empty.subjectNumeric.unkeyed | shared: iOS+macOS (the same key in both views — edit both) -->

This source note cites the Subject-Numeric File, but not in a form the app can match on, so documents from the same file can’t be matched.

<!-- END SOURCE: source.explorer.related.empty.subjectNumeric.unkeyed -->

---

---

## 14. Short strings bumped since the build-42 pass — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### Archival analytics — the three weights

#### The three weights count different things. A document coun…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsExport.swift | lines: 353–354 | key: archival.export.caveat.weight.v2 -->

The three weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Unprinted pointers counts neither: it counts footnotes naming material FRUS did not print, and is never added to the other two. Switching the weight changes which collections appear in the ranking, not just their order.

<!-- END SOURCE: archival.export.caveat.weight.v2 -->

> Same string also in §10.1 — edit one copy only.

#### Documents counts how many published documents came out of…
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 345–346 | key: archival.info.weights.detail.v2 -->

Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume’s front matter has volumes but no documents.

<!-- END SOURCE: archival.info.weights.detail.v2 -->

> Same string also in §9.6 — edit one copy only.

#### The three counts measure different things
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 344–344 | key: archival.info.weights.title.v2 -->

The three counts measure different things

<!-- END SOURCE: archival.info.weights.title.v2 -->

> Same string also in §9.6 — edit one copy only.

### Archival Flows — the crossing-citations caveat

#### Some footnotes cross between the two filing systems

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.mixed.title | popover item title — the heading above is this string -->

Citations that cross filing systems are counted in neither diagram

<!-- END SOURCE: archival.info.flows.mixed.title -->

<!-- Added by #831's measurement. The numbers are literal because the artifact does not carry this
     axis: the measurement found it too concentrated to draw. If it is ever regenerated with a
     mixed axis, these figures must be re-measured or removed — they are not read from data. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.mixed.detail -->

Some footnotes cross between the two filing systems — a document filed in a lot file or a presidential library pointing to a central-file number, or the reverse. There are about 1,900 of these across the series, and they are not spread evenly: a third of them come from two situations, the 1945 Potsdam volumes moving between Truman’s presidential file and the wartime file, and one 1952–54 conference volume moving between its lot file and its conference file. They are counted in neither diagram.

<!-- END SOURCE: archival.info.flows.mixed.detail -->

#### Some citations are read through an “Ibid.”

<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | key: archival.info.flows.ibid.title | popover item title — the heading above is this string -->

An “Ibid.” is followed, which is a reading

<!-- END SOURCE: archival.info.flows.ibid.title -->

<!-- The mixed-systems item's sibling in the same Flows ⓘ, never carried here before. The middle
     sentence is the honest claim — the app follows the editor's back-reference "the way a reader
     would, but it is a reading, not a quotation" — and the last sentence delegates the size of
     the effect to the chart rather than fixing a number in prose. Both must survive editing. -->
<!-- SOURCE: FRUSExplorer/Theme/FRUSTheme.swift | lines: 374–375 | key: archival.info.flows.ibid.detail -->

Some of these citations come from an “Ibid.” — the editor wrote the archive out once and then referred back to it. The app follows that back the way a reader would, but it is a reading, not a quotation. The share it accounts for is stated on the chart.

<!-- END SOURCE: archival.info.flows.ibid.detail -->


## 15. Archives Visits — the research-trip planner

*Build 44's flagship (#1086–#1097): an Archives Visit turns documents' source notes and their
footnotes' citations to unprinted material into a prioritized plan for a research trip. The prose
below is the feature's entire editorial voice — the two-claims vocabulary (**drawn from** = the
document's own source note; **pointed at** = a footnote citing something unprinted) and the rule
that the two counts are NEVER added are stated in the info popover and echoed by every footer.
Edits must keep that vocabulary consistent across all the blocks in this section, and must keep
the sparsity disclosure honest: pointed-at references exist on only ~4% of documents corpus-wide,
so a thin list is expected — sparse data, not a failed scan. The trip-packet sheet (15.6) predates
the feature but was rescoped by Phase 0 (#1088) and its empty states rewritten.*

### 15.1 The plan list, and the Mac manager window

#### Empty state — title
<!-- Shared: the same key is used by ArchiveVisitListView (iOS) and MacArchiveVisitManagerView. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 81–82 | key: archiveVisit.empty.title -->

No Archives Visits

<!-- END SOURCE: archiveVisit.empty.title -->

#### Empty state — detail
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 85–86 | key: archiveVisit.empty.detail -->

An Archives Visit uses information drawn from documents’ source notes to generate a draft research-trip plan. Seed one from Source Explorer, Archival Neighbors, a collection, or a project — or start empty below.

<!-- END SOURCE: archiveVisit.empty.detail -->

#### List footer — what a plan is
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 92–93 | key: archiveVisit.list.footer -->

An Archives Visit is an initial draft of a plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan syncs to your other devices.

<!-- END SOURCE: archiveVisit.list.footer -->

#### Per-plan coverage line
<!-- Placeholder note: keep `\(indexed.formatted())` and `\(CountCopy.documents(seeds.count))` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitListView.swift | lines: 179–180 | key: archiveVisit.coverage.v3 -->

\(indexed.formatted()) of \(CountCopy.documents(seeds.count)) indexed on this device

*The second interpolation is the plan's documents as a count and its noun — “1 document”, “1,204 documents” (#1374 review, round 1, where a one-document plan read “0 of 1 documents”).*

<!-- END SOURCE: archiveVisit.coverage.v3 -->

#### Mac manager — no selection
<!-- SOURCE: FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift | lines: 172–173 | key: archiveVisit.mac.noSelection.title -->

No Archives Visit Selected

<!-- END SOURCE: archiveVisit.mac.noSelection.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/MacArchiveVisitManagerView.swift | lines: 176–177 | key: archiveVisit.mac.noSelection.detail -->

Choose a plan from the picker in the toolbar, or create a new one. Plans can also be seeded from Source Explorer, Archival Neighbors, a collection, or a project.

<!-- END SOURCE: archiveVisit.mac.noSelection.detail -->

#### Deleting a plan
<!-- Shared: the same key is used from the editor, the list, and the Mac manager (three call
     sites, one string each — a change to the defaultValue must be made in all three). The message
     draws the sync boundary: the plan's own data goes, from every device; documents and volumes
     are untouched. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 331–332 | key: archiveVisit.delete.message -->

This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched.

<!-- END SOURCE: archiveVisit.delete.message -->

### 15.2 The editor — its toolbar tooltips, coverage and derivation states

#### The summary line
<!-- Placeholder note: keep `\(ArchiveVisitCounts.targets(targets))` and `\(ArchiveVisitCounts.repositories(repositories))` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitCounts.swift | lines: 103–104 | key: archiveVisit.editor.summary.v3 -->

\(ArchiveVisitCounts.targets(targets)) across \(ArchiveVisitCounts.repositories(repositories)).

*Each interpolation is a count and its noun — “8 targets”, “1 repository” — grouped and singular at one (#1374), where this line had read “8 targets across 1 repositories.”*

<!-- END SOURCE: archiveVisit.editor.summary.v3 -->

#### The coverage caveat
<!-- Phase 4's honesty line: targets derive from the search index, so unindexed seeding documents
     can silently contribute nothing. Placeholder note: keep `\(derived.indexedDocumentCount.formatted())`
     and `\(seeding)` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 760–761 | key: archiveVisit.editor.coverage.v3 -->

\(derived.indexedDocumentCount.formatted()) of \(seeding) indexed on this device — targets from unindexed documents may be missing below.

*`\(seeding)` is the seeding documents as a count and its noun — “1 seeding document”, “12 seeding documents” (#1374 review, round 1, where a one-document plan read “0 of 1 seeding documents”).*

<!-- END SOURCE: archiveVisit.editor.coverage.v3 -->

#### Deriving
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 388–389 | key: archiveVisit.editor.deriving -->

Deriving research targets from the plan’s documents…

<!-- END SOURCE: archiveVisit.editor.deriving -->

#### No documents seeded
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 722–723 | key: archiveVisit.editor.noSeeds.title -->

No documents seeded

<!-- END SOURCE: archiveVisit.editor.noSeeds.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 726–727 | key: archiveVisit.editor.noSeeds.detail -->

Seed this plan from Source Explorer, Archival Neighbors, a collection, or a project — each surface offers Add to Archives Visit.

<!-- END SOURCE: archiveVisit.editor.noSeeds.detail -->

#### Documents seeded, no targets derived
<!-- Two different empty states, and the difference is the diagnosis: `noTargets` means derivation
     ran and found nothing placeable; `allOff` means the reader switched every contribution off.
     Neither may be blurred into a generic "nothing here". -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1227–1228 | key: archiveVisit.editor.noTargets -->

No targets derive from these documents on this device — their volumes may not be indexed yet, or their source notes name nothing the app can place.

<!-- END SOURCE: archiveVisit.editor.noTargets -->

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1224–1225 | key: archiveVisit.editor.allOff -->

Every document’s contributions are switched off — turn a document’s archival source or unprinted references back on under Documents.

<!-- END SOURCE: archiveVisit.editor.allOff -->

#### Toolbar tooltip — Filter
<!-- On the Mac the plan editor's toolbar draws Filter, Export packet, About research targets and
     the ⋯ menu as icons alone, so each one's tooltip is where it says what it does (#1378 and its
     review). This one names what the Filter menu narrows; keep it in step with the menu's four
     controls (Repository, Tier, Claim, Included only). -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | ArchiveVisitEditorView.filterToolbarMenu | lines: 637–638 | key: archiveVisit.filter.menu.help | shared: macOS only -->

Narrow the Targets list by repository, tier or claim, or hide the targets excluded from the packet

<!-- END SOURCE: archiveVisit.filter.menu.help -->

#### Toolbar tooltip — Export packet
<!-- It names the three parts What to Include turns on by default and the sheet's two share
     buttons (Share, Share as PDF); keep it in step with both. The button's label, "Export packet",
     is shared with the iPhone menu's item and the Mac ⋯ menu's, and the macOS manual names it —
     keep all three one wording. SwiftUI draws a tooltip on the Mac alone: where iOS shows this
     button, it is VoiceOver's hint and nothing a sighted reader sees. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | ArchiveVisitEditorView.exportToolbarItem | lines: 462–463 | key: archiveVisit.editor.export.help | shared: iOS+macOS (single edit point — the Mac's tooltip; VoiceOver's hint alone at regular width, on iPad and on a large iPhone in landscape) -->

Open this plan’s packet — its research targets, repository visit-planning links and inquiry email drafts — to share as plain text or as a PDF

<!-- END SOURCE: archiveVisit.editor.export.help -->

#### Toolbar tooltip — About research targets
<!-- It names what the §15.3 popover explains; keep it in step with that popover. As with Export
     packet, iOS reads it as VoiceOver's hint and draws nothing. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | ArchiveVisitEditorView.infoToolbarItem | lines: 493–494 | key: archiveVisit.editor.about.help | shared: iOS+macOS (single edit point — the Mac's tooltip; VoiceOver's hint alone at regular width, on iPad and on a large iPhone in landscape) -->

What a research target is, what Drawn from and Pointed at mean, and why their counts are never added

<!-- END SOURCE: archiveVisit.editor.about.help -->

#### Toolbar tooltip — ⋯
<!-- It lists the Mac ⋯ menu's items, Export packet first, because the menu is where the packet is
     when the window is too narrow to show its button. Mac only: iPad's ⋯ menu holds neither Export
     packet nor Rename. Re-seed from Project appears only for a plan that belongs to a project. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | ArchiveVisitEditorView.moreToolbarItem | lines: 511–512 | key: archiveVisit.editor.more.help | shared: macOS only -->

Export packet, Rename, Priority Tiers, Duplicate and Delete, and Re-seed from Project for a plan that belongs to a project

<!-- END SOURCE: archiveVisit.editor.more.help -->

### 15.3 The info popover ("About research targets")

#### Title
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 652–653 | key: archiveVisit.info.title -->

About research targets

<!-- END SOURCE: archiveVisit.info.title -->

#### Body — the two claims, and the never-summed rule
<!-- The feature's defining paragraph. "The two counts are never added because they answer
     different questions" is owner decision 1b's rule stated to the reader; the last sentence
     explains why a plan stays correct as volumes index (stored rows are only the reader's own
     tiers/notes/exclusions — everything else re-derives). Both must survive editing. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 655–656 | key: archiveVisit.info.body -->

A target is one archival unit under one claim. Drawn from: the document was published from this file — its own source note. Pointed at: the document’s footnotes cite this, unprinted. One document can seed several targets, each prioritized on its own; the two counts are never added because they answer different questions. A row is stored only once you give it a tier, a note, or an exclusion — the rest derives from the document seeds each time, so it always reflects the current app index.

<!-- END SOURCE: archiveVisit.info.body -->

#### The corpus sparsity disclosure
<!-- The corpus-wide number is literal in the string (13,750 of 316,839, measured over the full
     index) — if the index is ever rebuilt over a different corpus it must be re-measured, not
     assumed. "Sparse data, not a failed scan" is the sentence doing the work. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 658–659 | key: archiveVisit.info.sparsity -->

Footnote references to unprinted material exist on only about 4% of documents corpus-wide (measured over the full index: 13,750 of 316,839), so a thin pointed-at list is expected — sparse data, not a failed scan.

<!-- END SOURCE: archiveVisit.info.sparsity -->

#### The measured local line
<!-- Phase 4's device-local companion: beside the corpus claim, never replacing it — the two
     describe different populations. Placeholder note: keep both `\(sparsity.…formatted())`
     interpolations intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1271–1272 | key: archiveVisit.info.sparsity.measured.v2 -->

On this device: \(sparsity.withReferences.formatted()) of \(sparsity.indexed.formatted()) indexed documents carry such references.

<!-- END SOURCE: archiveVisit.info.sparsity.measured.v2 -->

### 15.4 Targets — tiers, orphans, substitution

#### Tiers footer
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1661–1662 | key: archiveVisit.tiers.footer -->

Targets without a tier stay in Unprioritized, always listed last. An unlabeled tier reads “Priority 1”.

<!-- END SOURCE: archiveVisit.tiers.footer -->

#### An orphaned stored target
<!-- A stored row whose target no longer derives from the current seeds. "It never deletes itself"
     is the promise: the reader's tier and note survive reseeding until they remove them. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1196–1197 | key: archiveVisit.orphan.caption -->

Stored target — no longer derives from this plan’s current seeds. Kept with your tier and notes; it never deletes itself.

<!-- END SOURCE: archiveVisit.orphan.caption -->

#### Removing an orphan
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 267–268 | key: archiveVisit.orphan.remove.message -->

Its tier and note are deleted — from your other devices too, after sync. Nothing else in the plan changes.

<!-- END SOURCE: archiveVisit.orphan.remove.message -->

#### The digitized-substitute hint
<!-- Shown when part of the target's record group is digitized or microfilmed: read it that way
     instead of pulling boxes. Keep the leading ⇄ glyph — it is the row's badge. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 969–970 | key: archiveVisit.target.substitute -->

⇄ Part of this record is digitized or filmed — read it that way instead of pulling.

<!-- END SOURCE: archiveVisit.target.substitute -->

#### An inherited (Ibid.) seeding
<!-- The W-1b rule surfacing in the seeding detail: the citation was inherited from the preceding
     footnote's citation, and the row says so rather than presenting the reading as a quotation. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1049–1050 | key: archiveVisit.seeding.inherited -->

Cited as “Ibid.” — inherited from the preceding footnote’s citation.

<!-- END SOURCE: archiveVisit.seeding.inherited -->

### 15.5 The Documents tab

#### Footer — the two switches
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1249–1250 | key: archiveVisit.documents.footer -->

Each document contributes through two switches: its own source note (drawn from) and its footnotes’ citations to unprinted material (pointed at). References beyond FRUS exist on only about 4% of documents — where a half is absent, the control acts as a caption instead of a dead switch.

<!-- END SOURCE: archiveVisit.documents.footer -->

### 15.6 The trip-packet sheet

*Phase 0 (#1088) rescoped the packet to the documents the reader has actually engaged with, and
rewrote its empty states so each names its real cause. The two causes are distinct diagnoses —
no documents in the plan, no search index yet — and an edit must not collapse them into one
generic message. There was a third, "This collection’s search can’t run yet", for a packet built
straight from a smart collection; no screen could open one, so lane HYG (2026-10-01, #1423) deleted
that path and its two strings.*

#### Empty — no documents to plan over
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 295–296 | key: packet.empty.noDocuments.message -->

There are no documents here to plan over. Add documents to a collection, write a note on one, or apply a focus tag — the packet is built from the documents you have engaged with.

<!-- END SOURCE: packet.empty.noDocuments.message -->

#### Empty — the index is not ready
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 284–285 | key: packet.empty.noIndex.title -->

The search index isn’t ready

<!-- END SOURCE: packet.empty.noIndex.title -->

<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 288–289 | key: packet.empty.noIndex.message -->

The packet reads source notes from the search index, which isn’t available yet. Finish indexing and try again.

<!-- END SOURCE: packet.empty.noIndex.message -->

#### The research-topic field captions
<!-- Two states of one caption. The seeded form's second sentence is a privacy boundary — the
     drafts send what the reader writes HERE, never the stored project note — and must survive.
     Since #1366 the seeded form shows only while the field still reads the plan's project's
     research question (a plan copies it when it is created); before, the sheet was never told
     the question and this form could not appear. -->
<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 433–434 | key: packet.topic.caption.seeded -->

Seeded from your project’s research question — edit freely. The drafts include what you write here, never the stored note.

<!-- END SOURCE: packet.topic.caption.seeded -->

<!-- SOURCE: FRUSExplorer/TripPacket/TripPacketSheet.swift | lines: 435–436 | key: packet.topic.caption.unseeded -->

The inquiry drafts include what you write here.

<!-- END SOURCE: packet.topic.caption.unseeded -->

#### Re-seed from Project — offering the project's question to the topic
<!-- #1366. A plan copies its project's research question into the inquiry topic when it is
     created; Re-seed from Project (the plan editor's menu) is the only way the project's CURRENT
     question reaches it afterwards. It writes the question into an empty topic and says so with
     the toast below — the topic lives in the packet sheet, not on the editor's screen — and asks
     with the message below before replacing a topic that says something else. It asks even when
     that topic is only the project's old question: the plan keeps no record of what it was seeded
     with, so the question must not claim the reader wrote it — neither the message nor the cancel
     button below. It is an alert rather than a confirmation dialog, which iPad drew as a popover
     pointing at the whole editor; iPad centres the alert (checked on screen), and the Mac shows an
     alert as a sheet on the editor's window (not checked on screen). The menu offers Re-seed from
     Project only while the plan's project exists. Each quoted text ends a paragraph of its own:
     a research question ends in "?", and a sentence that went on after the quotation printed a
     full stop after it (#1366 review, round 2) — keep each closing ” at the end of its paragraph.
     Placeholder note: keep `\(pending.question)` and `\(pending.current)` intact. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 305–306 | key: archiveVisit.reseed.topic.message -->

The project’s research question now reads:

“\(pending.question)”

This plan’s inquiry drafts include:

“\(pending.current)”

Replace the topic with the question?

<!-- END SOURCE: archiveVisit.reseed.topic.message -->

<!-- The question's cancel button. It read "Keep My Topic" until the #1366 review: the topic it
     keeps may be the project's old question, which the reader never wrote. -->
<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 298–299 | key: archiveVisit.reseed.topic.keep -->

Keep Current Topic

<!-- END SOURCE: archiveVisit.reseed.topic.keep -->

<!-- SOURCE: FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift | lines: 1466–1467 | key: archiveVisit.reseed.topic.filled -->

The inquiry topic now reads the project’s research question.

<!-- END SOURCE: archiveVisit.reseed.topic.filled -->

---

## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.3 Archival Analytics

*Captions, pointers and the Network mode's grouping sentences, plus the gloss popover's explanation of why one filing code can name several places. §9 carries the rest of this dashboard.*

#### Footer — The Central Files umbrella record is withheld here too, so…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAllUnitsSheet.swift | ArchivalAllUnitsSheet.footer | lines: 217–218 | key: archival.allUnits.footer.umbrella -->

The Central Files umbrella record is withheld here too, so this list and the chart above count the same population.

<!-- END SOURCE: archival.allUnits.footer.umbrella -->

#### Most of this era’s sourcing names a central-file number…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.denominatorPointer | lines: 891–892 | key: archival.denominator.tryClasses -->

Most of this era’s sourcing names a central-file number rather than a named collection — switch the unit to File numbers to rank those.

<!-- END SOURCE: archival.denominator.tryClasses -->

#### Most of this era’s sourcing names a collection rather than…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.denominatorPointer | lines: 894–895 | key: archival.denominator.tryCollections -->

Most of this era’s sourcing names a collection rather than a central-file number — switch the unit to Collections to rank those.

<!-- END SOURCE: archival.denominator.tryCollections -->

#### Related file numbers are ranked together. Open one for the…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.familiesCaption | lines: 1005–1006 | key: archival.families.caption.documents -->

Related file numbers are ranked together. Open one for the exact designator a pull slip needs; its parts add up to the bar above.

<!-- END SOURCE: archival.families.caption.documents -->

#### Related file numbers are ranked together. Open one for the…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.familiesCaption | lines: 1007–1008 | key: archival.families.caption.volumes -->

Related file numbers are ranked together. Open one for the exact designator a pull slip needs. Each line counts the volumes citing that designator, so they overlap and do not add up to the bar: a volume citing two of them counts once for the group.

<!-- END SOURCE: archival.families.caption.volumes -->

#### Footnotes in the volumes covering %1$@ — %2$@ of them…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalCounts.swift | ArchivalCounts.rankingCaption | lines: 87–88 | key: archival.ranking.caption.pointers %@ %@ %@ -->

Footnotes in the volumes covering %1$@ — %2$@ of them — point at unprinted material in %3$@. Bars are colored by who holds the records. *(Interpolated as §9.2's ranking caption is.)*

<!-- END SOURCE: archival.ranking.caption.pointers %@ %@ %@ -->

#### When one collection entered the published record, and how…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.perCollectionTimingPointer | lines: 1276–1277 | key: archival.collections.timingPointer -->

When one collection entered the published record, and how long the editors kept returning to it, is on that collection’s own record, under Cited Over Time.

<!-- END SOURCE: archival.collections.timingPointer -->

#### Unprinted pointers are unavailable in this build — the…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.collectionsConditionalCaveats | lines: 1325–1326 | key: archival.caveats.noExternalIndex -->

Unprinted pointers are unavailable in this build — the bundled external-citation index did not load.

<!-- END SOURCE: archival.caveats.noExternalIndex -->

#### Where these figures come from, what each count measures…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsView.swift | ArchivalAnalyticsView.methodPointer | lines: 1337–1338 | key: archival.caveats.pointer -->

Where these figures come from, what each count measures, and how coverage changes by era — in About These Figures, above.

<!-- END SOURCE: archival.caveats.pointer -->

#### None of this focus’s partners above the link threshold are…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.groupCard | lines: 786–787 | key: archival.network.group.none %@ -->

None of this focus’s partners above the link threshold are held by %@. Lowering the threshold may bring some in.

<!-- END SOURCE: archival.network.group.none %@ -->

#### %1$lld of this focus’s %2$lld partners are held by %3$@.…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.groupCard | lines: 793–794 | key: archival.network.group.detail %lld %lld %@ %@ %lld -->

%1$lld of this focus’s %2$lld partners are held by %3$@. Strongest: %4$@, %5$lld shared volumes.

<!-- END SOURCE: archival.network.group.detail %lld %lld %@ %@ %lld -->

#### Only this group is drawn, and the rings have re-scaled to…
<!-- SOURCE: FRUSExplorer/Analytics/ArchivalNetworkView.swift | ArchivalNetworkView.groupCard | lines: 803–804 | key: archival.network.group.rescaled -->

Only this group is drawn, and the rings have re-scaled to its strongest link — distances are not comparable with the full graph.

<!-- END SOURCE: archival.network.group.rescaled -->

#### The Department filed a territory under the number of the…
<!-- SOURCE: FRUSExplorer/Analytics/GlossAlternatesLink.swift | GlossAlternatesLink.alternatesList | lines: 80–84 | key: archival.gloss.alsoNames.why -->

The Department filed a colonial territory under the number of the imperial power holding it, so one code can carry one or more geographical entities.

<!-- END SOURCE: archival.gloss.alsoNames.why -->


#### Measure detail — jointly supplied documents not counted (a fragment)

<!-- SOURCE: FRUSExplorer/Analytics/ArchivalAnalyticsAxes.swift | key: archival.measure.detail.documents.uncounted -->

jointly supplied documents not counted

<!-- END SOURCE: archival.measure.detail.documents.uncounted -->

### 18.9 Source Explorer and the NARA Catalog

*Central-file routing rationales (the sentence that says why a document went to the series it did), the NARA lookup's strategy hints and key warnings, and the collection record's timeline narratives and footers. §11 carries the panel prose already mirrored.*

#### No documents in your indexed volumes cite this archival…
<!-- SOURCE: FRUSExplorer/SourceExplorer/ArchivalNeighborsSheet.swift | ArchivalNeighborsContent.emptyDetail | lines: 421–422 | key: archivalNeighbors.empty.detail -->

No documents in your indexed volumes cite this archival source — indexing more volumes may surface some.

<!-- END SOURCE: archivalNeighbors.empty.detail -->

#### No documents in this scope cite this archival source…
<!-- SOURCE: FRUSExplorer/SourceExplorer/ArchivalNeighborsSheet.swift | ArchivalNeighborsContent.emptyDetail | lines: 424–425 | key: archivalNeighbors.empty.detail.scoped -->

No documents in this scope cite this archival source — switch to All volumes to search the whole index.

<!-- END SOURCE: archivalNeighbors.empty.detail.scoped -->

#### An enclosure was often filmed in its own series rather than…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesDocumentPart.enclosureNote | lines: 93–94 | key: centralFiles.part.enclosureNote.v2 -->

An enclosure was often filmed in its own series rather than with the document that enclosed it. Each row below says which text its rolls hold; check both.

<!-- END SOURCE: centralFiles.part.enclosureNote.v2 -->

#### Department of State outbound to a special agent — an…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 241–242 | key: centralFiles.rationale.specialAgentInstruction -->

Department of State outbound to a special agent — an instruction in the Special Missions volumes. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.specialAgentInstruction -->

#### From a special agent of the Department — filed with the…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 246–247 | key: centralFiles.rationale.specialAgentDespatch -->

From a special agent of the Department — filed with the agent’s mission in Despatches from Special Agents. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.specialAgentDespatch -->

#### Dateline is another executive department — a letter…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 259–260 | key: centralFiles.rationale.letterReceived -->

Dateline is another executive department — a letter received by the Department of State, filed chronologically. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.letterReceived -->

#### Dateline is a foreign consulate in the United States — a…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 270–271 | key: centralFiles.rationale.noteFromConsul -->

Dateline is a foreign consulate in the United States — a note from the foreign consul to the Department. The series is a single chronological run, matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.noteFromConsul -->

#### Department of State outbound, printed in FRUS’s…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 330–331 | key: centralFiles.rationale.legationNoteTo -->

Department of State outbound, printed in FRUS’s correspondence with the foreign legation in Washington — a note to the legation.

<!-- END SOURCE: centralFiles.rationale.legationNoteTo -->

#### Department of State outbound; if the addressee is the U.S.…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 335–336 | key: centralFiles.rationale.instruction -->

Department of State outbound; if the addressee is the U.S. minister abroad, it is an instruction.

<!-- END SOURCE: centralFiles.rationale.instruction -->

#### Department of State outbound; if the addressee is the…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 339–340 | key: centralFiles.rationale.noteTo -->

Department of State outbound; if the addressee is the foreign minister in Washington, it is a note to the legation.

<!-- END SOURCE: centralFiles.rationale.noteTo -->

#### Department of State outbound to a consul; if the addressee…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 345–346 | key: centralFiles.rationale.consularInstruction -->

Department of State outbound to a consul; if the addressee is a U.S. consul abroad, it is a consular instruction. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.consularInstruction -->

#### Department of State outbound to a consul; if the addressee…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 349–350 | key: centralFiles.rationale.noteToConsul -->

Department of State outbound to a consul; if the addressee is a foreign consul in the United States, it is a note to the consul. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.noteToConsul -->

#### Department of State outbound to a domestic official — filed…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 359–360 | key: centralFiles.rationale.domesticLetter -->

Department of State outbound to a domestic official — filed chronologically in Domestic Letters. Matched by the document’s date.

<!-- END SOURCE: centralFiles.rationale.domesticLetter -->

#### Printed in FRUS’s correspondence with the foreign legation…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 386–387 | key: centralFiles.rationale.legationNoteFrom -->

Printed in FRUS’s correspondence with the foreign legation in Washington, and not from the Department — a note from the legation.

<!-- END SOURCE: centralFiles.rationale.legationNoteFrom -->

#### Datelined abroad — likely a despatch from the U.S. mission…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CentralFilesClassifier.swift | CentralFilesClassifier.classify | lines: 399–400 | key: centralFiles.rationale.despatchAbroad -->

Datelined abroad — likely a despatch from the U.S. mission (or an enclosure filed with it).

<!-- END SOURCE: centralFiles.rationale.despatchAbroad -->

#### Nothing in your index cites this collection yet. Index more…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | CollectionDetailView.localSection | lines: 586–587 | key: collection.detail.local.empty -->

Nothing in your index cites this collection yet. Index more of its citing volumes to surface documents.

<!-- END SOURCE: collection.detail.local.empty -->

#### Footer — Counted from your own indexed volumes — the series-wide…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | CollectionDetailView.localSection | lines: 604–605 | key: collection.detail.local.footer -->

Counted from your own indexed volumes — the series-wide list below is independent of what you have downloaded.

<!-- END SOURCE: collection.detail.local.footer -->

#### The NARA Catalog link above points to one of them; the…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | CollectionDetailView.dividedAtNARASection | lines: 915–916 | key: collection.detail.divided.oneOfThem -->

The NARA Catalog link above points to one of them; the citation alone does not say which holds a given document.

<!-- END SOURCE: collection.detail.divided.oneOfThem -->

#### Footer — From the bundled lot-claimants index — %lld lots…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | CollectionDetailView.dividedAtNARASection | lines: 955–956 | key: collection.detail.divided.footer %lld -->

From the bundled lot-claimants index — %lld lots series-wide are claimed by more than one NARA series. Offline; no API key required.

<!-- END SOURCE: collection.detail.divided.footer %lld -->

#### Footer — Counted from editors’ footnotes naming material FRUS did…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionDetailView.swift | CollectionDetailView.unprintedPointersSection | lines: 1049–1050 | key: collection.detail.unprinted.footer -->

Counted from editors’ footnotes naming material FRUS did not print. A separate body of evidence from the counts above, which record where printed documents were drawn from — the two are never added together.

<!-- END SOURCE: collection.detail.unprinted.footer -->

#### This collection is cited in the %1$@ volumes and again as…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionRelations.swift | CollectionRelations.timelineNarrative | lines: 289–290 | key: collection.detail.timeline.narrative.gapped %@ %@ -->

This collection is cited in the %1$@ volumes and again as late as the %2$@ volumes, with eras in between where it does not appear.

<!-- END SOURCE: collection.detail.timeline.narrative.gapped %@ %@ -->

#### This collection enters the record with the %1$@ volumes and…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionRelations.swift | CollectionRelations.timelineNarrative | lines: 294–295 | key: collection.detail.timeline.narrative.flat %@ %@ -->

This collection enters the record with the %1$@ volumes and runs through the %2$@ volumes.

<!-- END SOURCE: collection.detail.timeline.narrative.flat %@ %@ -->

#### This collection enters the record with the %1$@ volumes and…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionRelations.swift | CollectionRelations.timelineNarrative | lines: 306–307 | key: collection.detail.timeline.narrative.peak %@ %@ -->

This collection enters the record with the %1$@ volumes and peaks across the %2$@ volumes.

<!-- END SOURCE: collection.detail.timeline.narrative.peak %@ %@ -->

#### This collection enters the record at its peak with the %1$@…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionRelations.swift | CollectionRelations.timelineNarrative | lines: 314–315 | key: collection.detail.timeline.narrative.entersAtPeak %@ %@ -->

This collection enters the record at its peak with the %1$@ volumes and fades after the %2$@ volumes.

<!-- END SOURCE: collection.detail.timeline.narrative.entersAtPeak %@ %@ -->

#### This collection enters the record with the %1$@ volumes…
<!-- SOURCE: FRUSExplorer/SourceExplorer/CollectionRelations.swift | CollectionRelations.timelineNarrative | lines: 319–320 | key: collection.detail.timeline.narrative.fade %@ %@ %@ -->

This collection enters the record with the %1$@ volumes, peaks across the %2$@ volumes, and fades after the %3$@ volumes.

<!-- END SOURCE: collection.detail.timeline.narrative.fade %@ %@ %@ -->

#### Archival units this document’s footnotes cite for material FRUS…
<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | SourceExplorerView.UnprintedPointer.sectionFooter | lines: 574–575 | key: source.explorer.unprinted.footer.v2 | shared: iOS+macOS (declared once; both Source Explorer twins draw it) -->

Archival units this document’s footnotes cite for material FRUS did not print. Each is a separate claim from the source note above, which records where this document itself was drawn from, even when the two name the same unit.

*The Unprinted Material section's footer, on iPhone, iPad and the Mac. Re-keyed for #1390: the old sentence ("Separate from the source note above…") said the section was separate from the source note while its rows could name the source note's own lot — in `frus1952-54v02p1` d41, three of five. What is separate is the claim, not the unit; keep that distinction if you reword it.*

<!-- END SOURCE: source.explorer.unprinted.footer.v2 -->

#### fn %1$@ · %2$@
<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | SourceExplorerView.UnprintedPointer.rowText | lines: 504–505 | key: source.explorer.unprinted.row.title %@ %@ | shared: iOS+macOS (declared once; both Source Explorer twins draw it) -->

fn %1$@ · %2$@

*The first line of each Unprinted Material row (#1390): the footnote number the volume printed, then the archival unit — “fn 2 · Lot 66 D 95”. When no printed number is recorded the row shows the unit alone and claims no number. Keep both placeholders.*

<!-- END SOURCE: source.explorer.unprinted.row.title %@ %@ -->

#### Footnote %1$@, %2$@
<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | SourceExplorerView.UnprintedPointer.rowText | lines: 507–508 | key: source.explorer.unprinted.row.spokenTitle %@ %@ | shared: iOS+macOS (declared once; both Source Explorer twins draw it) -->

Footnote %1$@, %2$@

*What VoiceOver says for the line above — “Footnote 2, Lot 66 D 95” — because “fn” is read as two letters. Keep both placeholders.*

<!-- END SOURCE: source.explorer.unprinted.row.spokenTitle %@ %@ -->

#### Same lot as the source note
<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | SourceExplorerView.UnprintedPointer.rowText | lines: 517–518 | key: source.explorer.unprinted.row.sameLot | shared: iOS+macOS (declared once; both Source Explorer twins draw it) -->

Same lot as the source note

*Marks an Unprinted Material row whose lot is the one the document's own source note names (#1390). The row stays listed: the footnote still points at material FRUS did not print.*

<!-- END SOURCE: source.explorer.unprinted.row.sameLot -->

#### %1$lld of %2$lld citations worded alike
<!-- SOURCE: FRUSExplorer/SourceExplorer/SourceExplorerView.swift | SourceExplorerView.UnprintedPointer.rowText | lines: 524–525 | key: source.explorer.unprinted.row.repeat %lld %lld | shared: iOS+macOS (declared once; both Source Explorer twins draw it) -->

%1$lld of %2$lld citations worded alike

*Shown under an Unprinted Material row only when another row of the same document prints exactly the same words (#1390): a footnote that repeats a citation word for word — `frus1952-54v04` d90's footnote 1 quotes two different memoranda and closes each with the same parenthetical, lot 62 D 430, “Rio Conference” — or two footnotes the volume printed with the same number and the same file. It reads “1 of 2 citations worded alike”, then “2 of 2”, in reading order; rows nothing repeats carry no number. Keep both placeholders, in that order.*

<!-- END SOURCE: source.explorer.unprinted.row.repeat %lld %lld -->

#### Error message — A NARA Catalog API key is required to search for lot files…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogClient.swift | NARACatalogError.errorDescription | lines: 78–79 | key: nara.error.missingKey -->

A NARA Catalog API key is required to search for lot files and Presidential Library records. Add your key in Settings → Connections.

<!-- END SOURCE: nara.error.missingKey -->

#### NARA Catalog API rate limit reached. Try again later, or…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogClient.swift | NARACatalogError.errorDescription | lines: 84–85 | key: nara.error.rateLimited -->

NARA Catalog API rate limit reached. Try again later, or use the manual search link below.

<!-- END SOURCE: nara.error.rateLimited -->

#### Archival citations found in the selected text and around it —…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | NARACatalogLookupView.candidateCitationsSection | lines: 274–275 | key: nara.lookup.detected.hint.v2 -->

*Added by #1380, which changed “tap one” to “select one” (the Mac shows this too) and so took the sentence from 89 characters to 92, past this section's prose rule.*

Archival citations found in the selected text and around it — select one to fill the search.

<!-- END SOURCE: nara.lookup.detected.hint.v2 -->

#### A NARA Catalog API key is required for this strategy. Add…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | NARACatalogLookupView.strategySection | lines: 374–375 | key: nara.lookup.noKey.warning -->

A NARA Catalog API key is required for this strategy. Add your key in Settings → Connections. The “Central files identifier” strategy does not require a key.

<!-- END SOURCE: nara.lookup.noKey.warning -->

#### Select the filing period that matches the document date.…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | NARACatalogLookupView.periodLinksSection | lines: 392–393 | key: nara.lookup.periodLinks.intro -->

Select the filing period that matches the document date. Each link goes directly to the NARA research page for that period — no API key required.

<!-- END SOURCE: nara.lookup.periodLinks.intro -->

#### Use for D-designator lot numbers (e.g. “63D135” or “68 D…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 570–571 | key: nara.lookup.strategy.lotFileRG59.hint -->

Use for D-designator lot numbers (e.g. “63D135” or “68 D 277”). Queries State Dept. lot file series in RG 59.

<!-- END SOURCE: nara.lookup.strategy.lotFileRG59.hint -->

#### Use for F-designator lot numbers (e.g. “55F44” or “56 F…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 573–574 | key: nara.lookup.strategy.lotFileRG84.hint -->

Use for F-designator lot numbers (e.g. “55F44” or “56 F 28”). Queries diplomatic post record lots in RG 84.

<!-- END SOURCE: nara.lookup.strategy.lotFileRG84.hint -->

#### Use for series names, collection descriptions, or partial…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 576–577 | key: nara.lookup.strategy.keywordRG59.hint -->

Use for series names, collection descriptions, or partial citation text. Restricts results to RG 59 (State Dept.).

<!-- END SOURCE: nara.lookup.strategy.keywordRG59.hint -->

#### Use for series names or collection descriptions. Restricts…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 579–580 | key: nara.lookup.strategy.keywordRG84.hint -->

Use for series names or collection descriptions. Restricts results to RG 84 (State Dept. post records).

<!-- END SOURCE: nara.lookup.strategy.keywordRG84.hint -->

#### Use for decimal file identifiers (e.g. “862S.01/10-1646”)…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 582–583 | key: nara.lookup.strategy.centralURL.hint -->

Use for decimal file identifiers (e.g. “862S.01/10-1646”) or central file keywords. Opens a pre-filtered NARA Catalog search — no API key required.

<!-- END SOURCE: nara.lookup.strategy.centralURL.hint -->

#### General free-text search across all record groups in the…
<!-- SOURCE: FRUSExplorer/SourceExplorer/NARACatalogLookupView.swift | LookupStrategy.hint | lines: 585–586 | key: nara.lookup.strategy.keyword.hint -->

General free-text search across all record groups in the NARA Catalog. Useful when the collection type is unclear.

<!-- END SOURCE: nara.lookup.strategy.keyword.hint -->
