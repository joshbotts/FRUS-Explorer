// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - SummaryCarouselOrderTests

/// Which twenty summaries the document carousel loads, and in what order (R-5 P3b-6).
///
/// These call `DocumentViewModel.loadSummaries` — the REAL emitter. The suite they replace
/// re-implemented that function under a comment reading "Simulate what
/// `DocumentViewModel.loadSummaries` does", so it stayed green whatever the function did, and it
/// had already drifted: it dropped the `!isHeadnoteDraft` predicate the production fetch carries.
///
/// Version history:
///   1.0 — R-5 P3b-6: initial implementation
@Suite("Summary carousel order — which twenty, and in what order")
struct SummaryCarouselOrderTests {

    /// Returns the CONTAINER. `try makeContainer().mainContext` releases it on the same line and
    /// the context then traps — a runner crash, not a test failure.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: GeneratedSummary.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @MainActor
    private func makeViewModel() -> DocumentViewModel {
        DocumentViewModel(
            entry: DocumentBrowserEntry(documentId: "d1", volumeId: "vol1", header: "A document"),
            volumeEntry: nil,
            parser: FRUSDocumentParser())
    }

    @discardableResult
    private func summary(_ context: ModelContext, _ text: String,
                         created: TimeInterval, draft: Bool = false,
                         documentId: String = "d1") -> GeneratedSummary {
        let s = GeneratedSummary(documentId: documentId, volumeId: "vol1", promptId: UUID(),
                                 responseText: text, isHeadnoteDraft: draft)
        s.createdAt = Date(timeIntervalSinceReferenceDate: created)
        s.lastModified = Date(timeIntervalSinceReferenceDate: created)
        context.insert(s)
        return s
    }

    /// The defect the Regenerate controls would otherwise have exposed: an unordered fetch
    /// truncated to twenty returns an undefined twenty, so a freshly generated summary can simply
    /// be absent from the carousel. Twenty-five rows, and the newest is inserted LAST so that a
    /// fetch honouring insertion order would leave it outside the window.
    @Test("Past twenty summaries the carousel still shows the newest")
    @MainActor
    func newestSurvivesTheLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for i in 0..<24 { summary(context, "Summary \(i)", created: Double(i) * 100) }
        summary(context, "The newest one", created: 100_000)
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)

        #expect(vm.summaries.count == 20)
        #expect(vm.summaries.first?.responseText == "The newest one")
        #expect(vm.activeSummaryIndex == 0, "the reader is shown the summary just made")
    }

    /// Newest first, by `createdAt`. `lastModified` is a SAVE stamp — two bulk paths rewrite
    /// summaries for reasons unrelated to recency — so ordering on it let a prompt de-duplication
    /// silently reorder a reader's carousel.
    @Test("Order is newest-first by createdAt, not by the save stamp")
    @MainActor
    func orderIsByCreation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = summary(context, "Oldest", created: 100)
        summary(context, "Middle", created: 200)
        summary(context, "Newest", created: 300)
        try context.save()
        // A later save of the OLDEST row — what `ModelModificationStamper` does on any change.
        old.lastModified = Date(timeIntervalSinceReferenceDate: 9_000)
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)

        #expect(vm.summaries.map(\.responseText) == ["Newest", "Middle", "Oldest"],
                "a touched old row must not become the newest summary")
    }

    /// The predicate the mirrored test had dropped. A headnote draft belongs to a collection
    /// entry's headnote, not to this document's carousel.
    @Test("A headnote draft never appears in the carousel")
    @MainActor
    func draftsAreExcluded() throws {
        let container = try makeContainer()
        let context = container.mainContext
        summary(context, "A real summary", created: 100)
        summary(context, "A draft", created: 900, draft: true)
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)

        #expect(vm.summaries.map(\.responseText) == ["A real summary"])
    }

    /// The carousel is per document; another document's summaries must not leak into it.
    @Test("Only this document's summaries load")
    @MainActor
    func scopedToTheDocument() throws {
        let container = try makeContainer()
        let context = container.mainContext
        summary(context, "Mine", created: 100)
        summary(context, "Someone else's", created: 900, documentId: "d2")
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)

        #expect(vm.summaries.map(\.responseText) == ["Mine"])
    }

    /// The predicate's OTHER conjunct. Without a differing-volume fixture, deleting `volumeId` from
    /// the predicate passes every other test in this suite — two volumes can carry the same
    /// document id, which is precisely why the index keys on the pair.
    @Test("A document id that repeats in another volume does not leak in")
    @MainActor
    func scopedToTheVolume() throws {
        let container = try makeContainer()
        let context = container.mainContext
        summary(context, "Mine", created: 100)
        let other = GeneratedSummary(documentId: "d1", volumeId: "vol2", promptId: UUID(),
                                     responseText: "Same document id, other volume")
        other.createdAt = Date(timeIntervalSinceReferenceDate: 900)
        other.lastModified = other.createdAt
        context.insert(other)
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)

        #expect(vm.summaries.map(\.responseText) == ["Mine"])
    }

    /// The carousel and the FTS summary column must agree about which summary is newest — they are
    /// two answers to one question, and before P3b-6 they used different rules.
    @Test("The carousel's newest is the summary search indexes")
    @MainActor
    func agreesWithTheSearchIndex() throws {
        let container = try makeContainer()
        let context = container.mainContext
        summary(context, "Older", created: 100)
        summary(context, "Newer", created: 800)
        try context.save()

        let vm = makeViewModel()
        vm.loadSummaries(context: context)
        let all = try context.fetch(FetchDescriptor<GeneratedSummary>())
        let indexed = GeneratedSummary.newestNonDraftPerDocument(all).first

        #expect(vm.summaries.first?.responseText == "Newer")
        #expect(indexed?.responseText == vm.summaries.first?.responseText)
    }
}
