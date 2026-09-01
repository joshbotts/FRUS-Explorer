// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
import SwiftData
@testable import FRUSExplorer

// MARK: - QueryMethodAppendixCoverageTests

/// The exported coverage statement (W-13 session 2).
///
/// **The suite's reason for existing is the parity test.** `QueryMethodAppendix` has three
/// renderers and they do not share a header: `preambleLines` is private and used only by `csv`,
/// while `markdown` and `plainTextLines` each hand-build their own. A fact added to one of them
/// therefore ships in the exported Markdown and is silently absent from the collection PDF that the
/// same research is published from — and nothing before this suite would have failed.
///
/// The second reason is disclosure. A scoped appendix is handed to a *collection export*, which is
/// a shareable artifact; a coverage table naming corpora from another line of work would turn a
/// methods section into a leak.
///
/// Version history:
///   1.0 — W-13 session 2: initial implementation
@Suite("Query method appendix — coverage")
struct QueryMethodAppendixCoverageTests {

    private let projectA = UUID()
    private let projectB = UUID()
    private let corpusA = UUID()
    private let corpusB = UUID()

    /// A search run inside `corpus`, under `project`.
    private func search(_ query: String, corpus: UUID?, project: UUID?,
                        at seconds: TimeInterval = 100) -> SearchHistoryEntry {
        SearchHistoryEntry(queryText: query, resultCount: 12, projectId: project,
                           executedAt: Date(timeIntervalSince1970: seconds),
                           loadedCount: 12, matchCount: 12, fetchLimit: 7_500,
                           indexedVolumeCount: 552, appliedCorpusId: corpus)
    }

    /// A coverage row: `total` documents, of which `opened`/`annotated`/`collected` are engaged.
    private func coverage(_ id: UUID, _ name: String,
                          engaged: Int, total: Int,
                          opened: Int = 0, annotated: Int = 0, collected: Int = 0,
                          loggingOn: Bool = true,
                          truncation: WorkingCorpus.CaptureTruncation = .complete)
    -> QueryMethodAppendix.CorpusCoverage {
        var engagements: [String: DocumentEngagement] = [:]
        for i in 0..<engaged { engagements["v1/d\(i)"] = [] }
        for i in 0..<opened { engagements["v1/d\(i)", default: []].insert(.opened) }
        for i in 0..<annotated { engagements["v1/d\(i)", default: []].insert(.annotated) }
        for i in 0..<collected { engagements["v1/d\(i)", default: []].insert(.collected) }
        return QueryMethodAppendix.CorpusCoverage(
            corpusId: id, corpusName: name,
            coverage: EngagementCoverage(engagements: engagements, totalCount: total,
                                         openedCount: opened, annotatedCount: annotated,
                                         collectedCount: collected,
                                         isOpenedComplete: loggingOn),
            truncation: truncation)
    }

    private func appendix(_ searches: [SearchHistoryEntry],
                          coverage rows: [QueryMethodAppendix.CorpusCoverage],
                          projectName: String? = "Oil diplomacy") -> QueryMethodAppendix {
        QueryMethodAppendix.make(searches: searches,
                                 corpusNames: [corpusA: "Suez captures", corpusB: "Iran captures"],
                                 projectName: projectName, researchQuestion: nil,
                                 generatedAt: Date(timeIntervalSince1970: 1_000),
                                 corpusCoverage: rows)
    }

    // MARK: - Parity

    /// **The test this suite exists for.** The same corpus, the same two numbers, in all three
    /// renderers. Wiring the block into `preambleLines` alone — the obvious move, because that is
    /// the one property named "shared" — puts it in the CSV and nowhere else, and every other
    /// assertion here would still pass.
    @Test("The coverage block reaches Markdown, plain text and CSV alike")
    func everyRendererCarriesIt() throws {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA)],
                               coverage: [coverage(corpusA, "Suez captures",
                                                   engaged: 43, total: 267, opened: 40,
                                                   annotated: 12, collected: 5)])
        let renderings: [(name: String, text: String)] = [
            ("markdown", subject.markdown),
            ("plainText", subject.plainTextLines.joined(separator: "\n")),
            ("csv", subject.csv),
        ]
        for rendering in renderings {
            #expect(rendering.text.contains("Suez captures"), "\(rendering.name) lost the corpus name")
            #expect(rendering.text.contains("43 of 267"), "\(rendering.name) lost the fraction")
            #expect(rendering.text.contains("224 untouched"), "\(rendering.name) lost the remainder")
            #expect(rendering.text.contains("40 opened"), "\(rendering.name) lost the breakdown")
            #expect(rendering.text.contains(QueryMethodAppendix.coverageHeading),
                    "\(rendering.name) lost the heading")
        }
    }

    /// The HTML collection renderer turns line 0 into the document's `<h2>` and every other line
    /// into a paragraph. Putting coverage at the top would demote the title; putting it at the
    /// bottom breaks `lineShape`'s "last line is a search" contract. It goes in the middle, and
    /// this pins both ends.
    @Test("Plain text keeps its title first and a search line last")
    func plainTextKeepsItsEnds() throws {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA)],
                               coverage: [coverage(corpusA, "Suez captures", engaged: 1, total: 9)])
        let lines = subject.plainTextLines
        #expect(lines.first == String(localized: "appendix.title",
                                      defaultValue: "Query log — method appendix"))
        #expect(lines.last?.contains("suez") == true, "last line was: \(lines.last ?? "nil")")
        let heading = try #require(lines.firstIndex(of: QueryMethodAppendix.coverageHeading))
        #expect(heading > 0 && heading < lines.count - 1)
    }

    // MARK: - Disclosure

    /// Coverage of a corpus no shown search ran inside is not the log's to report. This is the
    /// narrowing that keeps a shareable collection PDF from naming another project's corpora.
    @Test("A corpus the shown rows never searched is not reported")
    func unsearchedCorpusIsNotReported() {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA)],
                               coverage: [coverage(corpusA, "Suez captures", engaged: 1, total: 9),
                                          coverage(corpusB, "Iran captures", engaged: 7, total: 80)])
        #expect(subject.applicableCoverage.map(\.corpusName) == ["Suez captures"])
        #expect(!subject.markdown.contains("Iran captures"))
        #expect(!subject.csv.contains("Iran captures"))
        #expect(!subject.plainTextLines.joined().contains("Iran captures"))
    }

    /// Narrowing to a project drops the other project's corpus from the stored table too, not only
    /// from the rendering — so a caller reading `corpusCoverage` directly cannot leak it either.
    @Test("Scoping to a project narrows the coverage table itself")
    func scopingNarrowsTheStoredTable() {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA),
                                search("abadan", corpus: corpusB, project: projectB, at: 200)],
                               coverage: [coverage(corpusA, "Suez captures", engaged: 1, total: 9),
                                          coverage(corpusB, "Iran captures", engaged: 7, total: 80)])
        #expect(subject.corpusCoverage.count == 2, "unscoped, both are measured")
        let scoped = subject.scoped(toProject: projectA)
        #expect(scoped.corpusCoverage.map(\.corpusName) == ["Suez captures"])
        #expect(scoped.applicableCoverage.map(\.corpusName) == ["Suez captures"])
        #expect(!scoped.markdown.contains("Iran captures"))
    }

    /// No corpus, no denominator, no block — in every renderer. An appendix that printed a
    /// coverage heading over nothing would assert a method that was never used, which is the same
    /// argument `CollectionExportMetadata.methodAppendix` makes about an empty row set.
    @Test("A log with no corpus-scoped search renders no coverage at all")
    func noCorpusNoBlock() {
        let subject = appendix([search("suez", corpus: nil, project: projectA)], coverage: [])
        #expect(subject.coverageLines.isEmpty)
        #expect(!subject.markdown.contains(QueryMethodAppendix.coverageHeading))
        #expect(!subject.csv.contains(QueryMethodAppendix.coverageHeading))
        #expect(!subject.plainTextLines.contains(QueryMethodAppendix.coverageHeading))
    }

    // MARK: - Honesty

    /// The logging gate is one device setting, so it is stated once however many corpora there are.
    /// It must also survive the alphabetically-first corpus being the complete one — reading the
    /// caveat off `first` rather than off the first that *has* one is the silent way to lose it.
    @Test("The logging caveat appears exactly once, whichever corpus carries it")
    func loggingCaveatAppearsOnce() {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA),
                                search("abadan", corpus: corpusB, project: projectA, at: 200)],
                               // "Iran captures" sorts FIRST, and is the complete one. That is
                               // the whole fixture: reading the caveat off `first?.loggingCaveat`
                               // rather than off the first that HAS one yields nil here, and the
                               // block silently ships without its caveat.
                               coverage: [coverage(corpusA, "Suez captures", engaged: 1, total: 9,
                                                   opened: 1, loggingOn: false),
                                          coverage(corpusB, "Iran captures", engaged: 7, total: 80,
                                                   opened: 7, loggingOn: true)])
        let caveat = try? #require(subject.coverageLines.last)
        #expect(caveat?.contains("floor") == true, "expected the logging caveat, got: \(caveat ?? "nil")")
        let markdown = subject.markdown
        let occurrences = markdown.components(separatedBy: "research logging is off").count - 1
        #expect(occurrences == 1, "the device-wide caveat was printed \(occurrences) times")
    }

    /// **The denominator can itself be a floor.** A corpus saved at the row ceiling holds a slice
    /// of its query's matches, so "43 of 267 worked on" describes a set that is not the one the
    /// search described. The appendix's whole premise is that a floor never renders as a total.
    @Test("A truncated corpus discloses that its denominator is not every match")
    func truncatedDenominatorIsDisclosed() {
        let truncated = appendix([search("suez", corpus: corpusA, project: projectA)],
                                 coverage: [coverage(corpusA, "Suez captures", engaged: 43,
                                                     total: 267,
                                                     truncation: .truncated(total: 7_500))])
        #expect(truncated.coverageLines.contains { $0.contains("267") && $0.contains("7,500") },
                "lines were: \(truncated.coverageLines)")
        // …and a complete capture says nothing, so the disclosure keeps its force.
        let complete = appendix([search("suez", corpus: corpusA, project: projectA)],
                                coverage: [coverage(corpusA, "Suez captures", engaged: 43,
                                                    total: 267, truncation: .complete)])
        #expect(!complete.coverageLines.contains { $0.contains("7,500") })
        #expect(complete.coverageLines.count == 2, "preamble + one corpus line")
    }

    /// Whose engagement the numbers describe, said in the block itself. A project-scoped count
    /// attributes annotations through the project that owns them; a device-wide one does not, and
    /// a reader recomputing by hand needs to know which before the difference looks like an error.
    @Test("The block names the population it counted")
    func blockNamesItsScope() {
        let rows = [coverage(corpusA, "Suez captures", engaged: 1, total: 9)]
        let searches = [search("suez", corpus: corpusA, project: projectA)]
        let scoped = appendix(searches, coverage: rows, projectName: "Oil diplomacy")
        let device = appendix(searches, coverage: rows, projectName: nil)
        #expect(scoped.coverageLines.first?.contains("this project") == true)
        #expect(device.coverageLines.first?.contains("this device") == true)
        #expect(scoped.coverageLines.first != device.coverageLines.first)
    }

    /// Grouped digits, matching every other number the appendix prints. A table reading "1,234"
    /// beside a coverage line reading "1234" invites the reader to doubt they share a source.
    @Test("Coverage numbers are grouped like the rest of the appendix")
    func numbersAreGrouped() {
        let subject = appendix([search("suez", corpus: corpusA, project: projectA)],
                               coverage: [coverage(corpusA, "Suez captures",
                                                   engaged: 1, total: 12_345)])
        #expect(subject.coverageLines.contains { $0.contains("12,345") },
                "lines were: \(subject.coverageLines)")
    }
}

// MARK: - QueryMethodAppendixCoverageProducerTests

/// The producer: which corpora a coverage block is entitled to measure, against a real store
/// (W-13 session 2).
///
/// Version history:
///   1.0 — W-13 session 2: initial implementation
@Suite("Query method appendix — coverage producer")
struct QueryMethodAppendixCoverageProducerTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SearchHistoryEntry.self, WorkingCorpus.self, Project.self,
                 ReadingHistoryEntry.self, ResearchNote.self,
                 DocumentHighlight.self, Collection.self, CollectionEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// **The universe is the corpora *this project* searched inside**, resolved through
    /// `SearchHistoryEntry.appliedCorpusId` — the only record carrying a corpus id and a project id
    /// together, since a `WorkingCorpus` has no project of its own.
    ///
    /// The fixture is built so a wrong rule gives a visibly wrong answer rather than a plausible
    /// one: the device holds three corpora, one searched by this project, one searched only by
    /// another project, and one never searched at all. Measuring "every corpus" or "every searched
    /// corpus" both yield sets this asserts against.
    @Test("Only the corpora this project searched inside are measured")
    @MainActor
    func onlyThisProjectsSearchedCorporaAreMeasured() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mine = Project(name: "Oil diplomacy")
        let theirs = Project(name: "Berlin airlift")
        context.insert(mine)
        context.insert(theirs)

        let searched = WorkingCorpus(name: "Suez captures", documentKeys: ["v1/d1", "v1/d2", "v1/d3"])
        let othersOnly = WorkingCorpus(name: "Berlin captures", documentKeys: ["v2/d1"])
        let neverSearched = WorkingCorpus(name: "Idle captures", documentKeys: ["v3/d1"])
        for corpus in [searched, othersOnly, neverSearched] { context.insert(corpus) }

        context.insert(SearchHistoryEntry(queryText: "suez", projectId: mine.id,
                                          appliedCorpusId: searched.id))
        context.insert(SearchHistoryEntry(queryText: "airlift", projectId: theirs.id,
                                          appliedCorpusId: othersOnly.id))
        // Engagement inside the measured corpus: one opened, one annotated, one untouched.
        context.insert(ReadingHistoryEntry(documentId: "d1", volumeId: "v1",
                                           displayTitle: nil, projectId: mine.id))
        context.insert(ResearchNote(documentId: "d2", volumeId: "v1",
                                    bodyText: "n", projectIds: [mine.id]))
        try context.save()

        let appendix = ResearchDataExporter.methodAppendix(modelContext: context,
                                                           activeProjectId: mine.id)
        #expect(appendix.corpusCoverage.map(\.corpusName) == ["Suez captures"],
                "got \(appendix.corpusCoverage.map(\.corpusName))")
        let row = try #require(appendix.corpusCoverage.first)
        #expect(row.coverage.totalCount == 3)
        #expect(row.coverage.openedCount == 1)
        #expect(row.coverage.annotatedCount == 1)
        #expect(row.coverage.untouchedCount == 1)
    }

    /// The engagement counted is the project's, not the device's — so another project's note on a
    /// document of this corpus does not inflate the numerator.
    @Test("Another project's annotation does not count toward this project's coverage")
    @MainActor
    func engagementIsScopedToTheProject() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mine = Project(name: "Oil diplomacy")
        let theirs = Project(name: "Berlin airlift")
        context.insert(mine)
        context.insert(theirs)
        let corpus = WorkingCorpus(name: "Suez captures", documentKeys: ["v1/d1", "v1/d2"])
        context.insert(corpus)
        context.insert(SearchHistoryEntry(queryText: "suez", projectId: mine.id,
                                          appliedCorpusId: corpus.id))
        context.insert(ResearchNote(documentId: "d1", volumeId: "v1",
                                    bodyText: "theirs", projectIds: [theirs.id]))
        try context.save()

        let appendix = ResearchDataExporter.methodAppendix(modelContext: context,
                                                           activeProjectId: mine.id)
        let row = try #require(appendix.corpusCoverage.first)
        #expect(row.coverage.annotatedCount == 0, "another project's note was counted")
        #expect(row.coverage.untouchedCount == 2)
    }

    /// A corpus captured at the row ceiling carries its own floor into the export, so the
    /// denominator is never presented as every match.
    @Test("The corpus's capture truncation reaches the appendix")
    @MainActor
    func truncationReachesTheAppendix() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let project = Project(name: "Oil diplomacy")
        context.insert(project)
        let corpus = WorkingCorpus(name: "Suez captures", documentKeys: ["v1/d1"],
                                   wasTruncatedAtCapture: true, totalMatchCountAtCapture: 7_500)
        context.insert(corpus)
        context.insert(SearchHistoryEntry(queryText: "suez", projectId: project.id,
                                          appliedCorpusId: corpus.id))
        try context.save()

        let appendix = ResearchDataExporter.methodAppendix(modelContext: context,
                                                           activeProjectId: project.id)
        let row = try #require(appendix.corpusCoverage.first)
        #expect(row.truncation == .truncated(total: 7_500))
        #expect(appendix.coverageLines.contains { $0.contains("7,500") },
                "lines were: \(appendix.coverageLines)")
    }
}
