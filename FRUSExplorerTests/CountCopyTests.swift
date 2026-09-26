// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - CountCopyTests

/// Tests `CountCopy`, the one phrase every count goes through (#1374).
///
/// Two defects, one call: a count of one read as a plural ("1 volumes"), and a count built through
/// `String(format:)` and a `%lld` printed ungrouped ("12067 documents") two screens from a grouped
/// one. Each case below states the exact phrase, so a helper that singularised without grouping,
/// or grouped without singularising, fails on the case that shows it.
///
/// Version history:
///   1.0 — 2026-09-25: #1374, #1382 and #1422
struct CountCopyTests {

    /// A locale that groups with a comma, so the expected phrases can be written out.
    static let enUS = Locale(identifier: "en_US")

    /// The singular form the phrase cases use.
    static let one = "%@ document"
    /// The plural form beside `one`.
    static let many = "%@ documents"

    /// The four counts the issue names: none, one, two, and one past the grouping threshold.
    @Test("The phrase at 0, 1, 2 and 12,067: singular only at one, grouped past 999")
    func phraseAtTheFourCounts() {
        #expect(CountCopy.phrase(0, one: Self.one, many: Self.many, locale: Self.enUS) == "0 documents")
        #expect(CountCopy.phrase(1, one: Self.one, many: Self.many, locale: Self.enUS) == "1 document")
        #expect(CountCopy.phrase(2, one: Self.one, many: Self.many, locale: Self.enUS) == "2 documents")
        #expect(CountCopy.phrase(12_067, one: Self.one, many: Self.many, locale: Self.enUS)
                == "12,067 documents")
    }

    /// The guard: the shape `CountCopy` replaced really does print ungrouped here, and the
    /// formatter really does group. Without it the 12,067 case could pass because
    /// `String(format:)` had started grouping, which would leave the helper's grouping untested.
    @Test("The %lld shape it replaced prints 12067 on this platform, and the formatter groups")
    func theDefectShapeIsStillUngrouped() {
        #expect(String(format: "%lld documents", Int64(12_067)) == "12067 documents")
        #expect(12_067.formatted(.number.locale(Self.enUS)) == "12,067")
    }

    /// The locale is the one passed, not a fixed separator.
    @Test("The number is grouped for the locale passed")
    func groupsForTheLocalePassed() {
        #expect(CountCopy.phrase(12_067, one: Self.one, many: Self.many,
                                 locale: Locale(identifier: "de_DE")) == "12.067 documents")
    }

    /// With no locale the phrase follows the user's, which is what every screen passes.
    @Test("With no locale passed, the count is grouped for the user's locale")
    func defaultsToTheUsersLocale() {
        #expect(12_067.formatted() != "12067",
                "the host locale does not group; this case would pass for the wrong reason")
        #expect(CountCopy.documents(12_067) == "\(12_067.formatted()) documents")
    }

    /// The four shared nouns, each at one and past 999.
    @Test("documents, volumes, docs and vols each say one and group many")
    func theSharedNouns() {
        #expect(CountCopy.documents(1, locale: Self.enUS) == "1 document")
        #expect(CountCopy.documents(12_067, locale: Self.enUS) == "12,067 documents")
        #expect(CountCopy.volumes(1, locale: Self.enUS) == "1 volume")
        #expect(CountCopy.volumes(12_067, locale: Self.enUS) == "12,067 volumes")
        #expect(CountCopy.docs(1, locale: Self.enUS) == "1 doc")
        #expect(CountCopy.docs(17_606, locale: Self.enUS) == "17,606 docs")
        #expect(CountCopy.vols(1, locale: Self.enUS) == "1 vol")
        #expect(CountCopy.vols(12_067, locale: Self.enUS) == "12,067 vols")
    }
}

// MARK: - CountCopySiteTests

/// Drives the real emitters #1374, #1382 and #1422 name, at one and past 999.
///
/// Each emitter is reached through the function its screen calls, so a site that went back to a
/// `%lld` or lost its singular fails here as well as in the count scan. Every expectation is
/// written against `n.formatted()` in the host's locale, which `CountCopyTests` shows groups. The
/// views' own private strings (the section row, the Mac subseries row, the plan picker's banner)
/// have no callable emitter and are held by `CodingStandardsAuditTests.countsGoThroughCountCopy`.
///
/// **The sites the count scan cannot see are here above all** (#1374 review, round 1): a count
/// followed by a word that is not a noun — "+%lld more", "%lld total in full corpus", "%lld in
/// scope", the drawn-term figure — can only be wrong in its grouping, and the scan looks for a
/// noun. Each was lifted off its view onto a nonisolated type so it could be driven here, and
/// `CountCopyWiringTests` pins that the view still calls it.
///
/// Version history:
///   1.0 — 2026-09-25: #1374, #1382 and #1422
///   1.1 — 2026-09-25: #1374 review, round 1 — the Archival ranking caption, its VoiceOver value
///         and the umbrella caveat on screen; the gloss's "and N others"; the glossary's other
///         definitions; Corpus Analytics' full-corpus total; Chronology's "+N more"; the semantic
///         map's region headline; the Word Cloud export's drawn-term figure and Population caveat;
///         and the uncapped Archival export's denominator
struct CountCopySiteTests {

    /// 12,067 as this host groups it.
    static let big = 12_067.formatted()

    /// Corpus Analytics' totals footnote and its VoiceOver value: the `%lld` forms printed
    /// "1 documents matched" and an ungrouped number.
    @Test("Corpus Analytics' totals footnote and its VoiceOver value say one and group many")
    func analyticsValueUnitPhrases() {
        #expect(AnalyticsValueUnit.documents.matchedPhrase(count: 1) == "1 document matched")
        #expect(AnalyticsValueUnit.documents.matchedPhrase(count: 12_067) == "\(Self.big) documents matched")
        #expect(AnalyticsValueUnit.occurrences.matchedPhrase(count: 1) == "1 occurrence")
        #expect(AnalyticsValueUnit.occurrences.matchedPhrase(count: 12_067) == "\(Self.big) occurrences")
        #expect(AnalyticsValueUnit.documents.accessibilityPhrase(count: 1) == "1 document")
        #expect(AnalyticsValueUnit.documents.accessibilityPhrase(count: 12_067) == "\(Self.big) documents")
        #expect(AnalyticsValueUnit.occurrences.accessibilityPhrase(count: 1) == "1 occurrence")
    }

    /// The Word Cloud's provenance line, which the comparison columns share: it read "4591
    /// documents" for #1373's six-volume scope, and "1 terms" for a cloud of one.
    @Test("The Word Cloud's count line says one and groups many")
    func wordCloudCountLine() {
        #expect(WordCloudDisplayState.headerCountLine(for: .terms, shownTerms: 1, documentCount: 1)
                == "1 term from 1 document")
        #expect(WordCloudDisplayState.headerCountLine(for: .terms, shownTerms: 12, documentCount: 12_067)
                == "12 terms from \(Self.big) documents")
    }

    /// Chronology's aggregate line: its subseries count went through a `%lld` (#1422).
    @Test("Chronology's aggregate line groups its subseries count")
    func chronologyAggregateSubseries() {
        #expect(ChronologyAggregateText.line(volumes: 12_067, subseries: 12_067, editorialNotes: 1)
                == "\(Self.big) volumes · \(Self.big) subseries · 1 editorial note")
    }

    /// The storage hubs' counts, which carried the count through a `%lld` behind their two keys.
    @Test("The storage hubs' volume and subseries counts group many")
    func hubCounts() {
        #expect(HubCopy.volumes(1) == "1 volume")
        #expect(HubCopy.volumes(12_067) == "\(Self.big) volumes")
        #expect(HubCopy.subseries(1) == "1 subseries")
        #expect(HubCopy.subseries(12_067) == "\(Self.big) subseries")
    }

    /// The Projects and Tags rows and the Notes pane's header.
    @Test("Note, collection and document tallies say one and group many")
    func researchTallies() {
        #expect(NotesPaneSnapshot.noteCount(1) == "1 note")
        #expect(NotesPaneSnapshot.noteCount(12_067) == "\(Self.big) notes")
        #expect(ResearchItemCounts.TagTally(notes: 12_067, documents: 1).summary
                == "\(Self.big) notes · 1 document")
        #expect(ResearchItemCounts.TagTally(notes: 1, documents: 12_067).summary
                == "1 note · \(Self.big) documents")
        #expect(ResearchItemCounts.ProjectTally(notes: 1, collections: 12_067).summary
                == "1 note · \(Self.big) collections")
        #expect(ResearchItemCounts.ProjectTally(notes: 2, collections: 1).summary
                == "2 notes · 1 collection")
    }

    /// Archival Analytics' export: the umbrella's withheld count and the era's denominator, which
    /// #1374 measured printing "12067 documents" and "59973 source notes".
    @Test("The Archival Analytics export groups the umbrella count and the denominator")
    func archivalExportCaveats() {
        let provenance = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: 12_067, unitsReached: 700, bandVolumeCount: 120,
            indexedVolumeCount: 5, noteCount: 59_973, shownValue: 5_655)
        let text = provenance.extraCaveats.joined(separator: " ")
        #expect(text.contains("accounts for \(Self.big) documents in this era"), "\(text)")
        #expect(text.contains("carry \(59_973.formatted()) source notes in all"), "\(text)")
        #expect(text.contains("account for \(5_655.formatted()) of them"), "\(text)")

        let volumes = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .volumes,
            hiddenUmbrella: 1, unitsReached: 700, bandVolumeCount: 120, indexedVolumeCount: 5)
        let volumesText = volumes.extraCaveats.joined(separator: " ")
        #expect(volumesText.contains("accounts for 1 volume in this era"), "\(volumesText)")

        // The uncapped table's own sentence ("accounts for", singular: the table is its subject),
        // which the capped case above never reaches — its second figure had no test at all.
        let uncapped = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 700, bandVolumeCount: 120,
            indexedVolumeCount: 5, noteCount: 59_973, shownValue: 5_655, rowCapApplied: false)
        let uncappedText = uncapped.extraCaveats.joined(separator: " ")
        #expect(uncappedText.contains("carry \(59_973.formatted()) source notes in all"), "\(uncappedText)")
        #expect(uncappedText.contains("uncapped — accounts for \(5_655.formatted()) of them"), "\(uncappedText)")
    }

    /// The ranking card's caption: the classes lens read "draw on 5893 classes" in three bands of
    /// five, directly above the grouped denominator, and a lens reaching one unit read "1
    /// collections" (#1374 review, round 1).
    @Test("The Archival ranking caption groups both counts and names one unit in the singular")
    func archivalRankingCaption() {
        #expect(ArchivalCounts.rankingCaption(bandTitle: "1948–1960", bandVolumeCount: 1_204,
                                              unitsReached: 5_893, lens: .centralFileClasses,
                                              measuresPrintedMaterial: true)
                == "Volumes covering 1948–1960 — \(1_204.formatted()) of them — draw on \(5_893.formatted()) classes. Bars are colored by who holds the records.")
        #expect(ArchivalCounts.rankingCaption(bandTitle: "1948–1960", bandVolumeCount: 120,
                                              unitsReached: 1, lens: .namedCollections,
                                              measuresPrintedMaterial: true)
                == "Volumes covering 1948–1960 — 120 of them — draw on 1 collection. Bars are colored by who holds the records.")
        #expect(ArchivalCounts.rankingCaption(bandTitle: "1948–1960", bandVolumeCount: 120,
                                              unitsReached: 12_067, lens: .namedCollections,
                                              measuresPrintedMaterial: false)
                == "Footnotes in the volumes covering 1948–1960 — 120 of them — point at unprinted material in \(Self.big) collections. Bars are colored by who holds the records.")
        #expect(ArchivalCounts.rankingCaption(bandTitle: "1948–1960", bandVolumeCount: 120,
                                              unitsReached: 1, lens: .centralFileClasses,
                                              measuresPrintedMaterial: false)
                .hasSuffix("point at unprinted material in 1 class. Bars are colored by who holds the records."))
    }

    /// A ranking bar's VoiceOver value, which spoke "12067 documents" and "1 volumes".
    @Test("A ranking bar's VoiceOver value says its count in the weight's own words")
    func archivalRankingAccessibilityValue() {
        #expect(ArchivalCounts.rankingAccessibilityValue(12_067, weight: .documents,
                                                         custodian: "Presidential library")
                == "\(Self.big) documents, Presidential library")
        #expect(ArchivalCounts.rankingAccessibilityValue(1, weight: .volumes, custodian: "NARA")
                == "1 volume, NARA")
    }

    /// The umbrella caveat ON SCREEN — the export's twin is driven above; this one had no test,
    /// and #1374 names it ("accounts for 12067 documents in the 1948–1960 volumes").
    @Test("The umbrella caveat on screen says the withheld count in the weight's own words, grouped")
    func archivalUmbrellaOnScreen() {
        #expect(ArchivalCounts.umbrellaCaveat(weight: .documents, hidden: 12_067, bandTitle: "1948–1960")
                == "The Central Files umbrella record is hidden here. On its own it accounts for \(Self.big) documents in the 1948–1960 volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown.")
        let one = ArchivalCounts.umbrellaCaveat(weight: .volumes, hidden: 1, bandTitle: "1948–1960")
        #expect(one.contains("accounts for 1 volume in the 1948–1960 volumes"), "\(one)")
    }

    /// A class code with one other claimant read "and 1 others" on Archives ▸ Classes and in the
    /// Archival ranking, "also names 1 other places" to VoiceOver, and "(and 1 others)" in the CSV.
    @Test("A shared class code says \"and 1 other\" on screen, to VoiceOver and in the CSV")
    func glossAlternates() {
        #expect(ArchivalCounts.andOthers(1) == "and 1 other")
        #expect(ArchivalCounts.andOthers(21) == "and 21 others")
        #expect(ArchivalCounts.andOthersAccessibilityLabel(key: "811.6363", count: 1)
                == "811.6363 also names 1 other place")
        #expect(ArchivalCounts.andOthersAccessibilityLabel(key: "44e", count: 21)
                == "44e also names 21 other places")
        #expect(ArchivalCounts.exportReading(gloss: "Panama Canal Zone", alternates: 1)
                == "Panama Canal Zone (and 1 other)")
        #expect(ArchivalCounts.exportReading(gloss: "Bahamas", alternates: 21) == "Bahamas (and 21 others)")
        #expect(ArchivalCounts.exportReading(gloss: "Bahamas", alternates: 0) == "Bahamas")
    }

    /// The glossary's expand link under a term with two definitions read "1 other definitions".
    @Test("The glossary's expand link says one other definition")
    func glossaryOtherDefinitions() {
        #expect(GlossaryLookupCopy.otherDefinitions(1) == "1 other definition")
        #expect(GlossaryLookupCopy.otherDefinitions(29) == "29 other definitions")
    }

    /// Corpus Analytics' full-corpus total, named by #1374 ("16227 total in full corpus"). No
    /// noun follows the count, so no scan can see it; this is its guard.
    @Test("Corpus Analytics' full-corpus total is grouped")
    func analyticsFullCorpusTotal() {
        #expect(AnalyticsValueUnit.fullCorpusTotal(16_227) == "\(16_227.formatted()) total in full corpus")
    }

    /// Chronology's magnifier overflow, one of #1422's six counts. No noun follows it either.
    @Test("Chronology's magnifier overflow is grouped")
    func chronologyMagnifierMore() {
        #expect(ChronologyMagnifierText.more(12_067) == "+\(Self.big) more")
        #expect(ChronologyMagnifierText.more(1) == "+1 more")
    }

    /// The semantic map's region headline: "3803 documents in the series" for region 29, and an
    /// in-scope figure with no noun after it.
    @Test("The semantic map's region headline groups both counts and says one document")
    func semanticMapRegionHeadline() {
        #expect(SemanticMapRegionRows.countSummary(documentCount: 3_803, inScope: 1_204)
                == "\(3_803.formatted()) documents in the series · \(1_204.formatted()) in scope")
        #expect(SemanticMapRegionRows.countSummary(documentCount: 1, inScope: nil)
                == "1 document in the series")
    }

    /// The Word Cloud export: the image caption's drawn-term figure, which the scan saw only
    /// through its neighbour, and the Population caveat's document count and token total.
    @Test("The Word Cloud export groups its drawn terms, its documents and its denominator")
    func wordCloudExportCounts() {
        #expect(WordCloudDisplayState.figureCaptionTerms(drawn: 1_204, of: 12_067)
                == "\(1_204.formatted()) of \(Self.big) terms drawn")
        #expect(WordCloudDisplayState.figureCaptionTerms(drawn: 1, of: 1) == "1 of 1 term drawn")
        #expect(WordCloudDisplayState.populationCaveat(documentCount: 12_067, totalTokens: 1_234_567,
                                                       lensLabel: "All terms")
                == "Population: these counts cover the \(Self.big) documents in this scope. The share column divides by \(1_234_567.formatted()), which is every word counted under the “All terms” lens after the filters below. That is not the scope’s total word count. Shares from two different lenses cannot be compared.")
        let one = WordCloudDisplayState.populationCaveat(documentCount: 1, totalTokens: 40,
                                                         lensLabel: "Topics")
        #expect(one.contains("cover the 1 document in this scope"), "\(one)")
    }

    /// The weight's own words, which the umbrella caveat on screen and in the export share.
    @Test("Each Count-by weight says one of itself")
    func archivalWeightPhrases() {
        #expect(ArchivalWeight.documents.countPhrase(1) == "1 document")
        #expect(ArchivalWeight.volumes.countPhrase(12_067) == "\(Self.big) volumes")
        #expect(ArchivalWeight.unprintedPointers.countPhrase(1) == "1 unprinted pointer")
        #expect(ArchivalWeight.unprintedPointers.countPhrase(12_067) == "\(Self.big) unprinted pointers")
        #expect(ArchivalCounts.sourceNotes(1) == "1 source note")
        #expect(ArchivalCounts.sourceNotes(59_973) == "\(59_973.formatted()) source notes")
    }

    /// The Archives Visit list row and plan editor: "8 targets · 1 repositories".
    @Test("An Archives Visit plan's targets and repositories say one and group many")
    func archiveVisitCounts() {
        #expect(ArchiveVisitCounts.targets(1) == "1 target")
        #expect(ArchiveVisitCounts.targets(12_067) == "\(Self.big) targets")
        #expect(ArchiveVisitCounts.repositories(1) == "1 repository")
        #expect(ArchiveVisitCounts.repositories(2) == "2 repositories")
    }

    /// The publication-lag chart's durations — a count of years, unlike its calendar years.
    @Test("A publication lag of one year reads 1 year")
    func seriesLagYears() {
        #expect(SeriesProductionCounts.years(1) == "1 year")
        #expect(SeriesProductionCounts.years(25) == "25 years")
    }
}

// MARK: - CountCopyWiringTests

/// Pins that each view still calls the phrase `CountCopySiteTests` drives (#1374 review, round 1).
///
/// A tested function the view stopped calling would leave the test green and the screen wrong —
/// and for these sites no scan would notice, because the count's neighbour is not a noun. Each
/// needle is matched inside its own declaration's body with whitespace ignored, the
/// `WordCloudRuleWiringTests` way, so the call cannot drift elsewhere in the file and still count.
///
/// Version history:
///   1.0 — 2026-09-25: #1374 review, round 1
struct CountCopyWiringTests {

    private typealias Scan = NaturalLanguageReadinessScanTests

    /// One call a view must make: the file, the declaration whose body holds it, and the call.
    struct Site: CustomTestStringConvertible, Sendable {
        let path: String
        let declaration: String
        let needle: String
        var testDescription: String { "\(path.split(separator: "/").last ?? "") · \(needle)" }
    }

    static let sites: [Site] = [
        Site(path: "FRUSExplorer/Analytics/AnalyticsView.swift",
             declaration: "private func totalsFootnote(filtered: Int, total: Int) -> some View",
             needle: "Text(AnalyticsValueUnit.fullCorpusTotal(total))"),
        Site(path: "FRUSExplorer/Chronology/ChronologyView.swift",
             declaration: "private func magnifierCard(title: String, total: Int, bars: [ChronologyMagnifierBar]) -> some View",
             needle: "Text(ChronologyMagnifierText.more(bars.count - shown.count))"),
        Site(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift",
             declaration: "private func regionCountSummary(_ region: SemanticMapArtifacts.Cluster) -> String",
             needle: "SemanticMapRegionRows.countSummary(\n documentCount: region.documentCount,"),
        Site(path: "FRUSExplorer/Analytics/ArchivalAnalyticsView.swift",
             declaration: "private func collectionsConditionalCaveats(",
             needle: "Text(ArchivalCounts.umbrellaCaveat(weight: weight, hidden: hidden,\n bandTitle: band.title))"),
        Site(path: "FRUSExplorer/Analytics/ArchivalAnalyticsView.swift",
             declaration: "private func rankingCaption(_ ranking: ArchivalRanking) -> String",
             needle: "ArchivalCounts.rankingCaption(bandTitle: band.title,"),
        Site(path: "FRUSExplorer/Analytics/ArchivalAnalyticsView.swift",
             declaration: "private func accessibilityValue(for row: ArchivalRankingRow) -> String",
             needle: "ArchivalCounts.rankingAccessibilityValue(row.value, weight: weight,"),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private func cloudFigureCaption(drawnTerms: Int) -> String",
             needle: "WordCloudDisplayState.figureCaptionTerms(drawn: drawnTerms, of: layoutInputTerms.count),"),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private var cloudProvenance: AnalyticsProvenance",
             needle: "WordCloudDisplayState.populationCaveat(documentCount: result.documentCount,"),
    ]

    /// `text` with every whitespace character removed.
    private static func squeezed(_ text: some StringProtocol) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(Character.init))
    }

    @Test("Each count the scan cannot see is shown through the phrase its test drives",
          arguments: sites)
    func viewCallsThePhrase(site: Site) throws {
        let source = Scan.code(try String(contentsOf: Scan.repoRoot.appending(path: site.path),
                                          encoding: .utf8))
        let declaration = try #require(source.range(of: site.declaration),
                                       "\(site.declaration) is no longer in \(site.path)")
        let body = Self.squeezed(source[try #require(Scan.braceBody(in: source, after: declaration.upperBound))])
        #expect(body.contains(Self.squeezed(site.needle)),
                "\(site.path): \(site.declaration) no longer calls \(site.needle)")
    }
}

// MARK: - YearCopyTests

/// Tests that a year is never grouped where a count now is (#1382).
///
/// The Person Analytics caption read "Top people by mentions in dated documents, 1,940–1,992."
/// `String(localized:)` formats an interpolated `Int` for the locale, which groups it; the caption
/// now wraps each bound in `String(_:)`. The scan in `CodingStandardsAuditTests` refuses the bare
/// form by its spelling; this drives the caption itself, which a year held under another name
/// would reach without the scan seeing it.
///
/// Version history:
///   1.0 — 2026-09-25: #1382
struct YearCopyTests {

    /// The caption's two bounds, ungrouped, with the platform's grouping proven live beside them.
    @Test("The Most-Mentioned caption prints its years ungrouped")
    func rankingSubtitleHasNoGroupingSeparator() {
        let caption = PersonAnalyticsCopy.rankingSubtitle(1940...1992)
        #expect(caption == "Top people by mentions in dated documents, 1940–1992. Tap a person to compare them below.",
                "\(caption)")
        // The sentence has a comma of its own, so the check is for a separator inside a year.
        #expect(!caption.contains("1,9"), "\(caption)")

        // The guard `lifespanHasNoGroupingSeparator` carries: a bare Int interpolated into
        // `String(localized:)` really does group on this platform, so the case above cannot pass
        // because the platform stopped grouping.
        #expect(String(localized: "test.year.grouped", defaultValue: "\(1940)") != "1940",
                "if this ever equals 1940 the platform stopped grouping and the fix is moot")
    }
}

// MARK: - ResearchPlaceholderTests

/// Research's empty detail pane names the sidebar row it points at (#1374).
///
/// With nothing selected it said "Choose a tag or All Annotated Documents from the sidebar." — a
/// row renamed "All Research Documents" the day the placeholder was written. Both placeholders
/// (the iPad two-pane and the macOS split) are read from source through the audit's lexer, since a
/// view's `ContentUnavailableView` has no emitter to call, and each must name the row's own label.
///
/// Version history:
///   1.0 — 2026-09-25: #1374
struct ResearchPlaceholderTests {

    /// Every placeholder's `defaultValue:` contains the sidebar row's one label.
    @Test("Research's empty detail pane names the sidebar's All Research Documents row")
    func placeholderNamesTheSidebarRow() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Research/ResearchView.swift")
        let lexed = CodingStandardsAuditTests.LexedSource(try String(contentsOf: url, encoding: .utf8))
        func defaults(keyedWith prefix: String) -> [String] {
            lexed.literals.filter { $0.isDefaultValue && lexed.key(of: $0).hasPrefix(prefix) }
                .map(\.sourceText)
        }
        let rowLabels = Set(defaults(keyedWith: "research.sidebar.allNotes"))
        let placeholders = defaults(keyedWith: "research.empty.noSelection.detail")

        #expect(rowLabels == ["All Research Documents"], "the row's label is \(rowLabels)")
        #expect(placeholders.count == 2, "expected the two-pane and the Mac split: \(placeholders)")
        let label = try #require(rowLabels.first)
        for placeholder in placeholders {
            #expect(placeholder.contains(label), "the placeholder names another row: \(placeholder)")
        }
    }
}
