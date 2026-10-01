// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ProvenanceStatementTests

/// The sentences that reach a footnote (PV-1).
///
/// This is the only part of wave PV a reader can cite from: a chip cannot travel into a PDF
/// somebody else opens. So the suite pins what the block says, that it says only what the export
/// used, and that it reaches every renderer rather than one.
///
/// Version history:
///   1.0 — PV-1: initial implementation
@Suite("Provenance statements in exports")
struct ProvenanceStatementTests {

    // MARK: - The statement

    @Test("Nothing in, nothing out")
    func emptySourcesProduceNoBlock() {
        #expect(ProvenanceStatement.lines(for: []).isEmpty)
        #expect(ProvenanceStatement.block(for: []).isEmpty)
    }

    /// Ordered from the volumes outward, so two exports listing the same sources read alike.
    @Test("Sources are ordered by tier, then by label")
    func orderedFromTheVolumesOutward() {
        let lines = ProvenanceStatement.lines(for: [.appModel, .naraCatalog, .frusText])
        #expect(lines.count == 3)
        #expect(lines[0] == ProvenanceSource.frusText.methodSentence)
        #expect(lines[1] == ProvenanceSource.naraCatalog.methodSentence)
        #expect(lines[2] == ProvenanceSource.appModel.methodSentence)
    }

    /// A joined sentence must name what it joined to — otherwise it tells a reader they may not
    /// say "FRUS shows" without telling them what they may say instead.
    @Test("A joined source names its partner in the sentence")
    func joinedSourceNamesThePartner() {
        let line = ProvenanceStatement.lines(for: [.naraCatalog])[0]
        #expect(line.contains(ProvenanceSource.naraCatalog.partnerName))
        #expect(line.contains("National Archives"))
    }

    /// Q-3: the owner's own archival judgement is disclosed where it applies.
    @Test("Curated resolutions are disclosed, and only when present")
    func curatedDisclosureIsConditional() {
        let without = ProvenanceStatement.lines(for: [.naraCatalog])
        let with = ProvenanceStatement.lines(for: [.naraCatalog], includesCuratedResolutions: true)
        #expect(!without.contains(ProvenanceSource.curatedDisclosure))
        #expect(with.contains(ProvenanceSource.curatedDisclosure))
        #expect(with.count == without.count + 1)
    }

    // MARK: - The derivation

    private func doc(_ id: String, depth: CollectionBodyDepth = .full) -> CollectionExportItem {
        .document(CollectionExportDocument(
            documentId: id, volumeId: "v1", sortOrder: 0, bodyDepth: depth,
            title: "T", titleOverride: nil, date: nil, bodyText: "b", noteTexts: []))
    }


    /// The parse residual is disclosed, and **only** where the export actually parses source notes.
    ///
    /// The conditionality is the whole design (PV §5 / Q-1): `.frusText` is inserted for every
    /// document, excerpt, bibliography and chronology item, so an unconditional residual would
    /// caveat plain document collections that parse nothing — the error PV-3 had to undo for Q-3.
    @Test("The parse residual is disclosed, and only when the export parses source notes")
    func parseResidualIsConditional() {
        let without = ProvenanceStatement.lines(for: [.frusText, .naraCatalog])
        let with = ProvenanceStatement.lines(for: [.frusText, .naraCatalog],
                                             restsOnSourceNoteParse: true)
        #expect(!without.contains(ProvenanceSource.parseResidualDisclosure))
        #expect(with.contains(ProvenanceSource.parseResidualDisclosure))
        #expect(with.count == without.count + 1)
    }

    /// The two disclosures are independent, so one cannot be read as implying the other.
    @Test("The curated and parse-residual disclosures are independent")
    func disclosuresAreIndependent() {
        let both = ProvenanceStatement.lines(for: [.naraCatalog],
                                             includesCuratedResolutions: true,
                                             restsOnSourceNoteParse: true)
        #expect(both.contains(ProvenanceSource.curatedDisclosure))
        #expect(both.contains(ProvenanceSource.parseResidualDisclosure))
        let curatedOnly = ProvenanceStatement.lines(for: [.naraCatalog],
                                                    includesCuratedResolutions: true)
        #expect(!curatedOnly.contains(ProvenanceSource.parseResidualDisclosure))
    }

    /// Derived from the items, never declared — an export cannot claim a source it did not use.
    @Test("A plain document collection claims the volumes and nothing else")
    func plainCollectionIsFRUSOnly() {
        #expect([doc("d1"), doc("d2")].provenanceSources == [.frusText])
    }

    /// The one case where the exported prose is not the record's.
    @Test("A summary-only body adds the model")
    func summaryOnlyAddsTheModel() {
        #expect([doc("d1", depth: .summaryOnly)].provenanceSources == [.frusText, .appModel])
    }

    /// Headings carry no content and must not manufacture a claim.
    @Test("Headings alone produce no sources, and so no block")
    func headingsClaimNothing() {
        let items: [CollectionExportItem] = [.heading("A", level: 1)]
        #expect(items.provenanceSources.isEmpty)
        #expect(CollectionColophon.sourceLines(for: items, embedsWordCloud: false).isEmpty)
    }

    /// **An archival-sources block does NOT disclose hand-curated identifiers, because it cannot
    /// contain one.** PV-1 shipped this the other way round, on the stated ground that such a
    /// block "may carry an identifier the owner matched by hand" — so every collection export
    /// containing one told its reader that some identifier in it might be the owner's judgement
    /// rather than the catalogue's.
    ///
    /// It cannot be. The block's identifiers come from `ArchivalResolver.documentResolution`,
    /// which reads only `CentralFilesIndexStore` and `VolumeSourcesIndexStore`, and
    /// `CuratedLotResolutionsTests` proves in two non-vacuous assertions that curated rows are in
    /// neither artifact behind them. The trip packet's `archivalResolution` returns `nil`
    /// outright, and every reader of the curated tables is a Source Explorer view.
    ///
    /// The wave exists to let a reader say what they may claim. Manufacturing doubt the app has
    /// guaranteed away fails that in the same way overstating certainty would.
    @Test("An archival-sources export does not claim hand-matched identifiers")
    func archivalSourcesDoesNotClaimCuration() {
        let block = CollectionGeneratedBlock(
            type: .archivalSources, title: "Archival Sources",
            rows: [CollectionGeneratedRow(text: "RG 59, Central Files")])
        let items: [CollectionExportItem] = [doc("d1"), .generated(block)]

        let lines = CollectionColophon.sourceLines(for: items, embedsWordCloud: false)
        #expect(!lines.isEmpty, "the guard is vacuous if the block produced no sources at all")
        #expect(lines.contains(ProvenanceSource.naraCatalog.methodSentence),
                "an archival-sources block does draw on the catalog, and must still say so")
        #expect(!lines.contains(ProvenanceSource.curatedDisclosure),
                "the export claims a hand-matched identifier it cannot contain")
    }

    // MARK: - Reach

    /// **The W-13 failure this must not repeat**: a fact added to one renderer ships in one format
    /// and vanishes from the other two. The sources block is built once, in the shared colophon,
    /// and all three rich renderers call it — each telling it whether the word cloud it drew is there,
    /// from the image it holds rather than from the option (review round 1).
    @Test("All three rich renderers emit the shared sources block, saying whether they drew the cloud")
    func everyRendererEmitsTheBlock() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for (file, cloud) in [("FRUSExplorer/Collections/PDFCollectionExporter.swift", "wordCloud"),
                              ("FRUSExplorer/Collections/DocxCollectionExporter.swift", "wordCloudXML"),
                              ("FRUSExplorer/Collections/CollectionItemHTMLRenderer.swift", "wordCloudPNGBase64")] {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            #expect(source.contains("CollectionColophon.sourceLines(for: items, embedsWordCloud: \(cloud) != nil)"),
                    Comment(rawValue: "\(file) must emit the shared sources block, not its own, and say whether it drew a cloud"))
        }
    }

    /// PV-1, review round 1: a PDF, HTML or Word export can embed the collection's word cloud, which the app counts
    /// through its own lexicons and stopwords — the reason the standalone word-cloud export names
    /// ``ProvenanceSource/appWordLists``. The cloud is an export option, not an item, so a colophon derived from the
    /// items alone stated only the volumes' text above a figure the app computed. Driven through the real HTML
    /// renderer, which draws the figure from the image it is handed.
    @Test("A collection export that embeds the word cloud names the app's word lists, and one without it does not")
    func embeddedWordCloudNamesTheWordLists() {
        let items = [doc("d1"), doc("d2")]
        let listsSentence = ProvenanceSource.appWordLists.methodSentence
        #expect(CollectionColophon.sourceLines(for: items, embedsWordCloud: true).contains(listsSentence))
        #expect(!CollectionColophon.sourceLines(for: items, embedsWordCloud: false).contains(listsSentence))
        let metadata = CollectionExportMetadata(name: "Berlin", note: nil, includeColophon: true)
        let renderer = CollectionItemHTMLRenderer()
        let withCloud = renderer.pageHTML(metadata: metadata, items: items, wordCloudPNGBase64: "iVBORw0KGgo=")
        let without = renderer.pageHTML(metadata: metadata, items: items, wordCloudPNGBase64: nil)
        #expect(withCloud.contains("<figure class=\"word-cloud\">"), "the fixture drew no cloud, so this tests nothing")
        #expect(withCloud.contains(Self.htmlEscaped(listsSentence)),
                "an export with the cloud does not name the app's word lists")
        #expect(!without.contains(Self.htmlEscaped(listsSentence)), "an export without the cloud names the word lists")
        #expect(without.contains(Self.htmlEscaped(ProvenanceSource.frusText.methodSentence)),
                "the colophon's sources block is missing altogether, so the absence above proves nothing")
    }

    /// `text` as the HTML renderer escapes it.
    private static func htmlEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A trimmed plate is the artifact most likely to be shared detached from its CSV, so the
    /// designation may drop caveats but never the sources.
    @Test("A plate designation cannot drop the sources block")
    func plateTrimKeepsTheSources() {
        var p = AnalyticsProvenance(figureTitle: "F", axisLabel: "A", indexedVolumeCount: 552)
        p.sources = [.frusText, .naraCatalog]
        let sourceLines = ProvenanceStatement.lines(for: p.sources)
        #expect(sourceLines.allSatisfy { p.allCaveats.contains($0) })
        // Designate only the corpus caveat — the tightest possible trim.
        p.plateCaveats = [p.corpusCaveat]
        #expect(sourceLines.allSatisfy { p.plateCaveatLines.contains($0) },
                "a figure whose sources are unstated is what this wave exists to prevent")
        #expect(p.plateCaveatLines.contains(p.corpusCaveat))
    }
}

// MARK: - AnalyticsExportSourcesTests (PV-1)

/// Every analytics export states the sources its figures drew on (PV-1's analytics half).
///
/// `AnalyticsProvenance.sources` defaults to the volumes alone, and until the 2026-09-28 audit not one of the
/// fourteen analytics builders passed anything else — so a word cloud, a semantic map, a regional-emphasis chart, a
/// person ranking and a glossed class table each printed "Read from … the FRUS volumes, and from no other source"
/// above figures this app computed, or joined to the Office of the Historian's or the State Department's data. The
/// builders a test can call are driven here; the two whose statement is built inside a view (the word cloud's and
/// Person Analytics') are pinned by `everyBuilderStatesItsSources`, which reads every call in the app. Runs on any
/// destination.
@Suite("Analytics exports state the sources their figures drew on (PV-1)")
struct AnalyticsExportSourcesTests {

    /// The method sentence a source's presence prints.
    private func sentence(_ source: ProvenanceSource) -> String { source.methodSentence }

    @Test("Regional emphasis states the subject taxonomy its regions come from")
    func geographyStatesTheSubjectTaxonomy() {
        let geography = SeriesAnalyticsExport.geography(
            figureTitle: "Overall regional emphasis", axisLabel: "A", scopeLabel: nil, yearRange: nil,
            volumeCount: 552)
        #expect(geography.sources == [.frusText, .ohSubjects], "\(geography.sources)")
        let csv = geography.csvPreambleLines.joined(separator: "\n")
        #expect(csv.contains(sentence(.ohSubjects)), "the CSV does not name the subject taxonomy")
        #expect(geography.plateCaveatLines.contains(sentence(.ohSubjects)), "the plate does not name it")
    }

    /// Controls: the other three About-the-Series builders read FRUS-derived aggregates only.
    @Test("The other About-the-Series exports state the volumes alone")
    func otherSeriesBuildersStateTheVolumes() {
        let statements = [
            SeriesAnalyticsExport.production(figureTitle: "P", axisLabel: "A", scopeLabel: nil,
                                             yearRange: 1861...2026, volumeCount: 552),
            SeriesAnalyticsExport.provenance(figureTitle: "S", axisLabel: "A", scopeLabel: nil,
                                             yearRange: 1900...1993, volumeCount: 522, noteCount: 268_757,
                                             hiddenCategories: []),
            SeriesAnalyticsExport.administration(figureTitle: "D", axisLabel: "A", scopeLabel: nil,
                                                 yearRange: 1861...2026, volumeCount: 552,
                                                 includesEditorialNotes: false),
        ]
        for statement in statements {
            #expect(statement.sources == [.frusText], "\(statement.figureTitle): \(statement.sources)")
        }
    }

    /// The pointed-at class axis admits a decimal key only when it composes under the State Department's schedule
    /// (`external-citation-index.json` is `.stateDeptSchedule` in `BundledArtifactProvenance`), so a ranking of
    /// central-file classes by unprinted pointers is a join with that schedule.
    @Test("A class ranking by unprinted pointers states the State Department's schedule")
    func pointerClassRankingStatesTheSchedule() {
        let ranking = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .centralFileClasses, weight: .unprintedPointers,
            hiddenUmbrella: nil, unitsReached: 10, bandVolumeCount: 120, indexedVolumeCount: 5)
        #expect(ranking.sources == [.frusText, .stateDeptSchedule], "\(ranking.sources)")
        #expect(ranking.csvPreambleLines.joined(separator: "\n").contains(sentence(.stateDeptSchedule)))
    }

    /// Controls: the usage counts behind Documents and Volumes read authority clusters by identity, all FRUS-derived
    /// (`BundledArtifactProvenance`'s §1a case), and the named-collections axis of the pointers index likewise.
    @Test("A ranking that reads FRUS-derived counts states the volumes alone",
          arguments: zip([ArchivalUnitLens.namedCollections, .namedCollections, .namedCollections,
                          .centralFileClasses, .centralFileClasses],
                         [ArchivalWeight.documents, .volumes, .unprintedPointers, .documents, .volumes]))
    func frusOnlyRankingsStateTheVolumes(_ lens: ArchivalUnitLens, _ weight: ArchivalWeight) {
        let ranking = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: lens, weight: weight,
            hiddenUmbrella: nil, unitsReached: 10, bandVolumeCount: 120, indexedVolumeCount: 5)
        #expect(ranking.sources == [.frusText], "\(lens) by \(weight): \(ranking.sources)")
    }

    /// The every-unit sheet writes each class's gloss into its CSV — words read from the State Department's
    /// schedules (`decimal-class-labels.json`, `subject-numeric-labels.json`) — so that table states the schedule;
    /// the ranking card's own table writes no gloss and does not.
    @Test("The every-unit table states the State Department's schedule when it writes a class's gloss")
    func glossedTableStatesTheSchedule() throws {
        func ranking(glossesWritten: Bool) -> AnalyticsProvenance {
            ArchivalAnalyticsExport.ranking(
                band: ArchivalEraBand.all[1], lens: .centralFileClasses, weight: .documents,
                hiddenUmbrella: nil, unitsReached: 10, bandVolumeCount: 120, indexedVolumeCount: 5,
                rowCapApplied: false, glossesWritten: glossesWritten)
        }
        #expect(ranking(glossesWritten: true).sources == [.frusText, .stateDeptSchedule])
        #expect(ranking(glossesWritten: false).sources == [.frusText])
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Analytics/ArchivalAllUnitsSheet.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        let call = try #require(text.range(of: "ArchivalAnalyticsExport.ranking("))
        let arguments = try #require(WindowTargetingTests.balancedBlock(
            in: text, from: text.index(before: call.upperBound), open: "(", close: ")"))
        #expect(arguments.contains("glossesWritten: ranking.rows.contains { $0.gloss != nil }"),
                "the every-unit sheet does not say when its CSV carries a gloss:\n\(arguments)")
    }

    /// What each `AnalyticsProvenance(` call in the app passes as `sources:`, in file order: `nil` where it passes
    /// nothing and so states the volumes alone.
    ///
    /// A new analytics surface fails this until it is classified here, which is the point: the default is right for
    /// a figure counted from the index and wrong for one that joined or computed anything.
    static let expectedSources: [String: [String?]] = [
        "Analytics/AnalyticsView.swift": [nil],
        "Analytics/CrossReferenceAnalyticsView.swift": [nil],
        "Analytics/PersonAnalyticsView.swift": ["[.frusText, .ohPeopleRegister]"],
        "Analytics/WordCloud/WordCloudView.swift": ["[.frusText, .appWordLists]"],
        "Semantic/Map/SemanticMapExport.swift": ["[.frusText, .appModel]"],
        "SeriesAnalytics/SeriesAnalyticsExport.swift": [nil, "[.frusText, .ohSubjects]", nil, nil],
        "Analytics/ArchivalAnalyticsExport.swift": [
            "rankingSources(lens: lens, weight: weight, glossesWritten: glossesWritten)", nil, nil, nil, nil],
    ]

    @Test("Every analytics provenance builder in the app states the sources it drew on")
    func everyBuilderStatesItsSources() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = root.appendingPathComponent("FRUSExplorer")
        let files = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        var found: [String: [String?]] = [:]
        var calls = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let relative = url.path.components(separatedBy: "/FRUSExplorer/").last ?? url.path
            var searchStart = source.startIndex
            while let hit = source.range(of: "AnalyticsProvenance(", range: searchStart..<source.endIndex) {
                searchStart = hit.upperBound
                // A mention in a comment is not a call.
                let lineStart = source[..<hit.lowerBound].lastIndex(of: "\n").map { source.index(after: $0) }
                    ?? source.startIndex
                if source[lineStart..<hit.lowerBound].contains("//") { continue }
                let parenStart = source.index(before: hit.upperBound)
                let arguments = try #require(WindowTargetingTests.balancedBlock(
                    in: source, from: parenStart, open: "(", close: ")"),
                    "an unbalanced AnalyticsProvenance( call in \(relative)")
                calls += 1
                var passed: String?
                if let label = arguments.range(of: "sources: ") {
                    let rest = String(arguments[label.upperBound...])
                    passed = rest.hasPrefix("[")
                        ? WindowTargetingTests.balancedBlock(in: rest, from: rest.startIndex,
                                                             open: "[", close: "]").map(String.init)
                        : WindowTargetingTests.balancedBlock(in: rest, from: rest.startIndex,
                                                             open: "(", close: ")")
                            .map { String(rest.prefix(while: { $0 != "(" })) + $0 }
                }
                found[relative, default: []].append(passed)
            }
        }
        #expect(calls > 0, "read no AnalyticsProvenance( call at all: the scan is broken, not the tree clean")
        #expect(calls == 14, "the app has \(calls) analytics provenance builders, not 14: classify the new one here")
        for file in Set(found.keys).union(Self.expectedSources.keys).sorted() {
            #expect(found[file] == Self.expectedSources[file],
                    "\(file) passes sources \(found[file] ?? []), expected \(Self.expectedSources[file] ?? [])")
        }
    }
}

// MARK: - QueryMethodAppendixSourcesTests (PV-1)

/// The query log's method appendix states its sources in every format, not only the CSV (PV-1's appendix half).
///
/// `preambleLines`, which builds the sources block, fed only the CSV, though its comment said both formats: the
/// Markdown query log (`frus-query-log.md`) and the plain-text lines that collection PDF, HTML and Word exports embed
/// stated no sources at all — the W-13 trap the provenance plan named. Runs on any destination.
@Suite("The method appendix states its sources in Markdown and plain text too (PV-1)")
struct QueryMethodAppendixSourcesTests {

    /// A keyword search, and a Meaning search, whose scope signature names the semantic route.
    private func appendix(semantic: Bool) -> QueryMethodAppendix {
        var searches = [SearchHistoryEntry(queryText: "petroleum", resultCount: 41,
                                           executedAt: Date(timeIntervalSince1970: 100), loadedCount: 41,
                                           matchCount: 41, fetchLimit: 7_500, indexedVolumeCount: 552)]
        if semantic {
            searches.append(SearchHistoryEntry(queryText: "oil diplomacy", resultCount: 20,
                                               executedAt: Date(timeIntervalSince1970: 200),
                                               scopeSignature: "route=semantic"))
        }
        return QueryMethodAppendix.make(searches: searches, corpusNames: [:], projectName: nil,
                                        researchQuestion: nil, generatedAt: Date(timeIntervalSince1970: 1_000))
    }

    @Test("Markdown and plain text carry the sources block the CSV carries", arguments: [false, true])
    func everyFormatStatesTheSources(_ semantic: Bool) {
        let appendix = appendix(semantic: semantic)
        #expect(semantic == (appendix.semanticRowCount > 0), "the fixture's Meaning row was not read as one")
        // Read as sentences, not as sources: the model and the word lists share one (computed) sentence.
        let expected = ProvenanceStatement.block(for: semantic ? [.frusText, .appModel] : [.frusText])
        let unexpected = Set(ProvenanceSource.allCases.map(\.methodSentence)).subtracting(expected)
        #expect(expected.count == (semantic ? 3 : 2), "the heading and one sentence per source: \(expected)")
        for (format, text) in [("CSV", appendix.csv), ("Markdown", appendix.markdown),
                               ("plain text", appendix.plainTextLines.joined(separator: "\n"))] {
            for line in expected {
                #expect(text.contains(line), "the \(format) appendix omits: \(line)")
            }
            for sentence in unexpected {
                #expect(!text.contains(sentence), "the \(format) appendix claims: \(sentence)")
            }
        }
    }
}
