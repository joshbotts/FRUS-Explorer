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

// MARK: - SummaryIndexSelectionTests

/// Which summary's text goes into the one-per-document FTS5 column (R-5 P3b-1, design Q-8 g).
///
/// Both push loops used to write every row in fetch order, so whichever the store returned last
/// won — a superseded summary or a headnote draft could outrank the newest AI summary in search.
///
/// Version history:
///   1.0 — R-5 P3b-1: initial implementation
@Suite("Summary index selection — the newest non-draft per document")
struct SummaryIndexSelectionTests {

    private func summary(_ doc: String, created: Date?, draft: Bool = false, text: String = "t") -> GeneratedSummary {
        let s = GeneratedSummary(documentId: doc, volumeId: "v1", promptId: UUID(), responseText: text,
                                 isHeadnoteDraft: draft)
        s.createdAt = created
        return s
    }

    @Test("One per document, the newest by createdAt")
    func newestWins() {
        let older = summary("d1", created: Date(timeIntervalSince1970: 1_000), text: "old")
        let newer = summary("d1", created: Date(timeIntervalSince1970: 2_000), text: "new")
        let other = summary("d2", created: Date(timeIntervalSince1970: 500), text: "d2")
        let picked = GeneratedSummary.newestNonDraftPerDocument([older, other, newer])
        #expect(picked.map(\.responseText) == ["new", "d2"])
    }

    @Test("Drafts never win, even when newest; a nil createdAt sorts last")
    func draftsAndNilDates() {
        let live = summary("d1", created: Date(timeIntervalSince1970: 1_000), text: "live")
        let draft = summary("d1", created: Date(timeIntervalSince1970: 9_000), draft: true, text: "draft")
        let undated = summary("d1", created: nil, text: "undated")
        #expect(GeneratedSummary.newestNonDraftPerDocument([draft, undated, live]).map(\.responseText) == ["live"])
        #expect(GeneratedSummary.newestNonDraftPerDocument([draft]).isEmpty)
        #expect(GeneratedSummary.newestNonDraftPerDocument([undated]).map(\.responseText) == ["undated"])
    }

    @Test("Blank ids are skipped and the result is ordered by document key")
    func blanksAndOrder() {
        let blank = summary("", created: Date(timeIntervalSince1970: 1), text: "blank")
        let b = summary("d2", created: Date(timeIntervalSince1970: 1), text: "b")
        let a = summary("d1", created: Date(timeIntervalSince1970: 1), text: "a")
        #expect(GeneratedSummary.newestNonDraftPerDocument([blank, b, a]).map(\.responseText) == ["a", "b"])
    }

    /// The two tie-breaks the doc comment names — rows synced from before `createdAt` existed
    /// fold to the same date, so `lastModified` and then the id must decide, and decide the same
    /// way twice. `lastModified` is set directly: the `@Model` macro rewrites stored properties,
    /// so the `didSet` observers never fire (see `ModelModificationStamper`).
    @Test("Ties: equal createdAt falls to the later lastModified, then to the lower id")
    func tieBreaks() {
        let x = summary("d1", created: nil, text: "x"); x.lastModified = Date(timeIntervalSince1970: 100)
        let y = summary("d1", created: nil, text: "y"); y.lastModified = Date(timeIntervalSince1970: 200)
        #expect(GeneratedSummary.newestNonDraftPerDocument([x, y]).map(\.responseText) == ["y"])
        #expect(GeneratedSummary.newestNonDraftPerDocument([y, x]).map(\.responseText) == ["y"])
        let same = Date(timeIntervalSince1970: 300)
        let p = summary("d2", created: same, text: "p"); p.lastModified = same
        let q = summary("d2", created: same, text: "q"); q.lastModified = same
        let winner = p.id.uuidString < q.id.uuidString ? "p" : "q"
        #expect(GeneratedSummary.newestNonDraftPerDocument([p, q]).map(\.responseText) == [winner])
        #expect(GeneratedSummary.newestNonDraftPerDocument([q, p]).map(\.responseText) == [winner])
    }

    @Test("Draft-only documents are reported for clearing; documents with any live summary are not")
    func draftOnlyDocuments() {
        let onlyDraft = summary("d1", created: nil, draft: true)
        let draftAndLive = [summary("d2", created: nil, draft: true), summary("d2", created: nil)]
        let blank = summary("", created: nil, draft: true)
        let docs = GeneratedSummary.draftOnlyDocuments([onlyDraft, blank] + draftAndLive)
        #expect(docs.map { "\($0.volumeId)/\($0.documentId)" } == ["v1/d1"])
        #expect(GeneratedSummary.draftOnlyDocuments([]).isEmpty)
    }
}
