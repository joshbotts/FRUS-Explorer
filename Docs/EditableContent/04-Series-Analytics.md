# EditableContent — Series Analytics (About the Series dashboards)

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §4, §18.4. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 33 blocks · 1 ✎ note (your central-files sentences in the “About these figures” footnote, replaced by #1543) · no ⚑ wording issues

---

## 4. Series Analytics — Dashboard Prose

*The four Series-analytics dashboards (reached from the Research Guide's live dashboard pages and from Corpus Analytics). Each has an intro paragraph, per-chart subtitles, and an "About these figures" methodology footnote. These are shared SwiftUI views — one edit point changes both iOS and macOS.*

---

### Source Provenance dashboard (Series Analytics SA-3b)

#### Page intro

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | intro (SourceProvenanceDashboard) | lines: 245–246 | key: series.provenance.intro -->

Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival provenance changed. The State Department’s central files predominated until bureau lot files and presidential libraries appeared after World War II. Modern volumes draw on a much wider range of sources.

<!-- END SOURCE: series.provenance.intro -->

#### Chart 1 subtitle — Archival provenance over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | mixOverTimeChart caption | lines: 396–397 | key: series.provenance.trend.caption -->

Each decade’s source notes divided among the archival collections they cite, so every decade totals 100%. A volume’s decade is set by the midpoint of its coverage. The trend begins in 1900 because earlier volumes carry no archival source notes.

<!-- END SOURCE: series.provenance.trend.caption -->

#### Chart 2 subtitle — Overall provenance composition

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | compositionChart caption | lines: 458–459 | key: series.provenance.composition.caption -->

How many source notes across the whole series, from 1900 on, cite each kind of archival collection. The Central Decimal File dwarfs the rest. Most published FRUS documents came from the State Department’s various central filing systems, but recent volumes draw from presidential records and other kinds of federal record collections.

<!-- END SOURCE: series.provenance.composition.caption -->

#### Chart 3 subtitle — The documentary base by decade

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | densityChart caption | lines: 513–514 | key: series.provenance.density.caption -->

How many source notes each decade contributes. These are the counts behind the shares above. The 1940s carry the deepest base. Volumes covering the 1970s, 1980s, and 1990s are still in production, so those decades will grow as new volumes are released.

<!-- END SOURCE: series.provenance.density.caption -->

#### Category-filter caveat — shown while categories are hidden

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats filtered line | lines: 628–629 | key: series.provenance.caveats.filtered.v2 -->

Some categories are hidden. Each share below is a share of the categories still shown, not of all source notes. A decade with no notes in any shown category reads as zero rather than being skipped. Use the Categories menu above to show them all.

<!-- END SOURCE: series.provenance.caveats.filtered.v2 -->

#### "About these figures" methodology footnote

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | caveats body | lines: 638–639 | key: series.provenance.caveats.body.v3 %lld %lld -->

These figures come from parsing each document’s source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. “Other / Unclassified” means a citation the parser could not classify, not a missing source note. Coverage spans %1$lld of the %2$lld cataloged volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. The categories follow State Department filing practice. The Central Decimal File category is the central filing system through January 1963: the decimal file from 1910 and, before it, the Numerical File of 1906–1910. The Subject-Numeric File replaced the decimal file in February 1963 and ran through 1973, and the Central Foreign Policy File followed from July 1973. A citation to the central files is placed by what it gives: a decimal file number, a Subject-Numeric file designation or its block of years, or the Central Foreign Policy File’s name or a film number. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors found the documents they selected for publication. That is an editorial and archival signal, not a full census of the underlying archives.

<!-- END SOURCE: series.provenance.caveats.body.v3 %lld %lld -->

> **✎ Your sentences of 2026-09-30, replaced by lane CFPF (#1543, 2026-10-02).** You wrote: “The Central Decimal File is the pre-1963 central filing system. For now, the Central Foreign Policy File category covers both its 1963–1973 Subject-Numeric successor and the post-1973 file.” The app now ships the three sentences above in their place, under a new key (`.v3`). Why: the category never held the 1963–1973 file. Measured over the 264,552 document source notes, 22 of the 9,443 Subject-Numeric citations sat in the Central Foreign Policy File category; 3,844 were counted under the Central Decimal File and 5,577 under Other NARA Collections, by how each note was worded. #1543 gives the Subject-Numeric File a category of its own, which is what your “For now” was waiting on, so the footnote says what the three central categories are and how a citation is placed among them. It also names the Numerical File of 1906–1910, whose 2,447 citations the Central Decimal File category has always held. Edit the block above to reword it; this box is never written back.

---

The `AdministrationProfilesDashboard` is a single shared SwiftUI view (used via `EducationDashboardView`), so its `String(localized:)` keys are single edit points shared across iOS and macOS.

### Administration Profiles Dashboard

#### Dashboard intro
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.intro | lines: 252–253 | key: series.admin.intro | shared: iOS+macOS (single edit point) -->

Whose foreign policy does Foreign Relations of the United States document? Every dated document is assigned to the presidential administration in office when the events it records took place. These charts show how many documents each administration draws, and how densely the series covers each term. Select any administration to see which volumes carry its record.

<!-- END SOURCE: series.admin.intro -->
Note: `AdministrationProfilesDashboard` is one shared SwiftUI view rendered on both iOS and macOS; editing this key changes both platforms.

#### Narrowed-empty state — shown when scope and year range match no administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.narrowedEmptyState | lines: 218–219 | key: series.admin.narrowedEmpty.message | shared: iOS+macOS (single edit point) -->

No administration matches your current scope and year range. The subseries you selected may carry no attributed documents, or your years may fall outside every presidential term. Reset the scope or year range above to see the whole series.

<!-- END SOURCE: series.admin.narrowedEmpty.message -->

#### Editorial-notes toggle explainer
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.editorialNotesToggle | lines: 269–270 | key: series.admin.toggle.subtitle | shared: iOS+macOS (single edit point) -->

Editorial-note documents carry a span of dates rather than a single date; including them adds them to every count and proportion.

<!-- END SOURCE: series.admin.toggle.subtitle -->

#### Chart 1 subtitle — Documents per administration
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.documentsChart | lines: 291–292 | key: series.admin.docs.caption | shared: iOS+macOS (single edit point) -->

How many published documents concern each administration’s foreign policy, in chronological order. Any date overlap counts, so a volume spanning two terms counts in both.

Volumes covering the 1970s, 1980s, and 1990s are still in production. Coverage of the Carter, Reagan, H.W. Bush, and Clinton administrations will expand as new volumes are released.

<!-- END SOURCE: series.admin.docs.caption -->

#### Chart 2 subtitle — Volumes per administration-year
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumesPerYearChart | lines: 352–353 | key: series.admin.perYear.caption | shared: iOS+macOS (single edit point) -->

How many volumes cover each administration, divided by the length of its term in years. This measures how densely the series covers each presidency.

Volumes covering the 1970s, 1980s, and 1990s are still in production. Coverage of the Carter, Reagan, H.W. Bush, and Clinton administrations will expand as new volumes are released.

<!-- END SOURCE: series.admin.perYear.caption -->

#### Volume-list subtitle — per-administration shares
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.volumeList | lines: 490–491 | key: series.admin.volumes.caption | shared: iOS+macOS (single edit point) -->

Each volume’s share is the fraction of that volume’s documents that fall in this administration — so shares can sum past 100% across administrations under any-overlap attribution.

<!-- END SOURCE: series.admin.volumes.caption -->

#### Subseries-scope caveat — shown while a subseries scope is active
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 566–567 | key: series.admin.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries. Counts and proportions come from that subseries’ volumes alone. The coverage span for each administration is hidden here, because the source data pre-aggregates it for the whole series. Reset the scope above to see the whole series.

<!-- END SOURCE: series.admin.caveats.scope %@ -->
Note: `%@` is filled with the active subseries label at runtime — keep the placeholder verbatim.

#### Any-overlap attribution footnote — "About these figures"
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/AdministrationProfilesDashboard.swift | AdministrationProfilesDashboard.caveats | lines: 574–575 | key: series.admin.caveats.body.v2 %lld | shared: iOS+macOS (single edit point) -->

A document counts toward an administration if its dates overlap that president’s term at all. A volume spanning two administrations therefore counts in both. That is why the volume counts add up to more than the series’ %lld volumes. It is also why one volume’s proportions can total over 100% across administrations. Editorial notes carry a range of dates rather than a single date. The toggle above decides whether they are counted, and it is off by default. Each president is counted separately: Nixon and Ford are distinct, as are Grover Cleveland’s two non-consecutive terms. Administrations the series has not yet published do not appear.

<!-- END SOURCE: series.admin.caveats.body.v2 %lld -->

---

### Geographic Emphasis dashboard

#### Intro paragraph
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.intro | lines: 161–162 | key: series.geography.intro -->

Where in the world does Foreign Relations of the United States look? Every volume carries editorial place tags, which map roughly to the State Department’s six regional bureaus. These charts show how the series’ geographic emphasis shifted over time. Early volumes concentrate on Europe and the Western Hemisphere. Postwar volumes widen into Asia, the Near East, and Africa. The charts also show which regions and countries the series covers most.

<!-- END SOURCE: series.geography.intro -->

#### Chart 1 caption — Regional emphasis over time
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTrendChart | lines: 198–199 | key: series.geography.trend.caption -->

Each decade’s volumes divided among the regions they cover. A volume spanning several regions splits evenly between them, so every decade totals 100%. A volume’s decade is set by the midpoint of its coverage.

<!-- END SOURCE: series.geography.trend.caption -->

#### Chart 2 caption — Overall regional emphasis
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.regionTotalsChart | lines: 260–261 | key: series.geography.totals.caption -->

How many volumes touch each region across the whole series. A volume that covers several regions counts once in each, so these totals overlap.

<!-- END SOURCE: series.geography.totals.caption -->

#### Chart 3 caption — Most-covered countries
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.topCountriesChart | lines: 312–313 | key: series.geography.countries.caption -->

The individual place tags carried by the most volumes — the concrete detail behind the regional picture.

<!-- END SOURCE: series.geography.countries.caption -->

#### Regional-bureau mapping footnote
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesGeographyDashboard.swift | SeriesGeographyDashboard.caveats | lines: 371–372 | key: series.geography.caveats.body.v2 %lld %lld -->

Place tags are editorial tags on the volume, not on the document. A volume touches a region if it carries a place tag that maps to that region. These are volume counts, not document counts, and a volume commonly spans several regions. The stacked chart splits each volume across its regions. A volume covering three regions contributes a third to each, so every decade totals 100%. The overall bars work differently: they count a multi-region volume once in every region it touches. Regions roughly follow the State Department’s six current regional bureaus, with dependencies and territories folded into “Other.” %1$lld of the %2$lld cataloged volumes carry a place tag that maps to a region. These figures cover the volumes the app currently catalogs, so the newest volumes may not appear yet.

<!-- END SOURCE: series.geography.caveats.body.v2 %lld %lld -->
Note: while a subseries scope is active, this dashboard's caveats block also shows the shared scope line `series.caveats.scope %@` (`SeriesGeographyDashboard.swift` lines 321–322). Its canonical block lives in the Production & Timeliness subsection below; the same key and defaultValue appear in both files, so edit both occurrences together.

---

### Production & Timeliness dashboard (`SeriesProductionDashboard.swift`)

Shared iOS+macOS surface — a single SwiftUI view rendered in both the onboarding sheet and the Research Guide. Every string below is keyed via `String(localized:)`, so editing the `defaultValue` is a single edit point for both platforms.

#### Intro paragraph

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var intro | lines: 141–142 | key: series.production.intro | shared: iOS+macOS (single edit point) -->

How long does the official record lag events? These charts trace the timeliness of Foreign Relations of the United States across its whole span. They show the lag between the events a volume documents and its publication. That lag is measured against the publication-timeliness target in force at the time. They also show the pace of publication over time and the steady growth of the digitized series.

<!-- END SOURCE: series.production.intro -->

#### Chart 1 caption — Publication lag over time

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var lagChart (caption) | lines: 183–184 | key: series.chart.lag.caption | shared: iOS+macOS (single edit point) -->

Each point is a volume. The horizontal axis is its publication year. The vertical axis is the lag: how many years earlier its latest document was written. The dashed step line is the timeliness target in force when the volume appeared. That target was 15 years from the 1961 directive, 20 years from 1972, and 30 years from 1985, codified by the 1991 statute.

<!-- END SOURCE: series.chart.lag.caption -->

#### Chart 2 caption — Volumes published per year

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var perYearChart (caption) | lines: 273–274 | key: series.chart.peryear.caption | shared: iOS+macOS (single edit point) -->

How many volumes reached print in each year, colored by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication.

<!-- END SOURCE: series.chart.peryear.caption -->

#### Chart 3 caption — Cumulative volumes published

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var cumulativeChart (caption) | lines: 331–332 | key: series.chart.cumulative.caption.v2 %lld | shared: iOS+macOS (single edit point) -->

The digitized corpus has grown to the %lld volumes this app catalogs — steeply in some decades, slowly in others.

<!-- END SOURCE: series.chart.cumulative.caption.v2 %lld -->

#### Subseries-scope caveat — shown while a subseries scope is active (shared with Geographic Emphasis)

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (scope line) | lines: 395–396 | key: series.caveats.scope %@ | shared: iOS+macOS (single edit point) -->

Scoped to the %@ subseries — reset the scope above for the whole series.

<!-- END SOURCE: series.caveats.scope %@ -->
Note: `SeriesGeographyDashboard.swift` repeats the same key and defaultValue in its own caveats block (lines 321–322) — edit both occurrences together so the two files stay consistent. `%@` is filled with the active subseries label at runtime; keep the placeholder verbatim.

#### Publication-timeliness footnote ("About these figures")

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | var caveats (body) | lines: 402–403 | key: series.caveats.body.v2 %lld | shared: iOS+macOS (single edit point) -->

These figures cover only published, digitized volumes. A volume’s publication year is the print year in its TEI header, and its coverage is the span of its document dates. Lag is print year minus coverage-end year. For the near-contemporaneous early volumes that lag can be close to zero. The timeliness target changed over time. There was no formal target before 1961. It was then 15 years under Kennedy’s 1961 directive, 20 under Nixon’s 1972 directive, and 30 under Reagan’s 1985 directive and as codified by the 1991 statute. The step line is drawn against each volume’s publication year, so it shows exactly the target in force when that volume was published. These charts cover the %lld volumes the app currently catalogs, so the newest volumes may not appear yet.

<!-- END SOURCE: series.caveats.body.v2 %lld -->

---

## 18. Prose this file had never carried (build-48 sweep) — the parts about this area

*The section’s introduction is in `README.md`; its other parts are in the other files.*

### 18.4 About the Series dashboards

*The Top Collections card and the other dashboard sentences §4 does not carry.*

#### This dashboard groups source notes into eleven broad…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift | SourceProvenanceDashboard.archivalAnalyticsLink | lines: 586–587 | key: series.provenance.archivalLink.detail.v2 -->

This dashboard groups source notes into eleven broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together.

<!-- END SOURCE: series.provenance.archivalLink.detail.v2 -->

#### The years selected above fall outside the eras this ranking…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.body | lines: 83–84 | key: series.provenance.topCollections.noBands -->

The years selected above fall outside the eras this ranking covers, which run from 1861 to 1992. Widen the range to see the collections.

<!-- END SOURCE: series.provenance.topCollections.noBands -->

#### The charts above group source notes into broad kinds of…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.header | lines: 171–172 | key: series.provenance.topCollections.caption -->

The charts above group source notes into broad kinds of record. These are the individual bodies of records inside them, ranked by how many documents each supplied.

<!-- END SOURCE: series.provenance.topCollections.caption -->

#### No named collection is recorded for the volumes in this…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.emptyState | lines: 191–192 | key: series.provenance.topCollections.empty -->

No named collection is recorded for the volumes in this scope. That is an answer about the scope, not a gap in the app — before 1948 the volumes cite filing-system classes far more often than named collections.

<!-- END SOURCE: series.provenance.topCollections.empty -->

#### The State Department’s central files are withheld from this…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.footnotes | lines: 290–291 | key: series.provenance.topCollections.umbrella.v2 %lld %lld -->

The State Department’s central files are withheld from this ranking — one undifferentiated in the NARA Catalog, carrying %1$lld here against %2$lld for the largest collection shown. Archival Analytics can show it.

<!-- END SOURCE: series.provenance.topCollections.umbrella.v2 %lld %lld -->

#### Counted in volumes, not documents: the document-level index…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.footnotes | lines: 298–299 | key: series.provenance.topCollections.volumesFallback -->

Counted in volumes, not documents: the document-level index is unavailable in this build, so these bars say how many volumes drew on each collection.

<!-- END SOURCE: series.provenance.topCollections.volumesFallback -->

#### Showing %1$lld of %2$lld collections reached across %3$@.…
<!-- SOURCE: FRUSExplorer/SeriesAnalytics/TopCollectionsCard.swift | TopCollectionsCard.coverageSentence | lines: 332–333 | key: series.provenance.topCollections.coverage %lld %lld %@ %@ -->

Showing %1$lld of %2$lld collections reached across %3$@. Together they account for %4$@ of the source notes those volumes carry.

<!-- END SOURCE: series.provenance.topCollections.coverage %lld %lld %@ %@ -->


#### VoiceOver label — Covers through \(…), published \(…), lag…

<!-- SOURCE: FRUSExplorer/SeriesAnalytics/SeriesProductionDashboard.swift | key: series.chart.lag.a11y.v2 -->

Covers through \(String(point.coverageEndYear)), published \(String(point.printYear)), lag \(SeriesProductionCounts.years(point.lagYears))

<!-- END SOURCE: series.chart.lag.a11y.v2 -->
