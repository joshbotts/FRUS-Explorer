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

// MARK: - DocumentChangeBannerTests

/// The in-document change banner's truth table (Volume-Update-Annotation-Integrity design §6, P2).
///
/// `DocumentChangeBanner.line` is the one sentence both document-view twins show above a changed
/// document, so every cell of the table is pinned here — including the two that must say
/// NOTHING: an unstamped row (the first index of a volume) and a reviewed one. The pre-P2 hedge is
/// pinned word for word, because a highlight made before the table existed still reaches it.
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
@Suite("Document change banner — every cell of the truth table")
struct DocumentChangeBannerTests {

    private func row(kind: String?, stamped: Bool = true, reviewed: Bool = false)
    -> IndexingPipeline.DocumentRevision {
        IndexingPipeline.DocumentRevision(
            volumeId: "frus1950v01", documentId: "d7",
            contentHash: "c", bodyHash: "b",
            changedAt: stamped ? "2026-09-03T12:00:00Z" : nil,
            changeKind: kind,
            reviewedAt: reviewed ? "2026-09-03T13:00:00Z" : nil)
    }

    private static let hedge = "Some highlights may be misaligned — the document has been updated since they were created."

    @Test("No row and no stale highlight: nothing")
    func nothingToSay() {
        #expect(DocumentChangeBanner.line(revision: nil, highlightsStale: false) == nil)
    }

    @Test("No row but a stale highlight: the pre-P2 hedge, word for word")
    func staleWithoutRow() {
        #expect(DocumentChangeBanner.line(revision: nil, highlightsStale: true) == Self.hedge)
    }

    /// Two unstamped rows: the first index's (no kind) and one CARRYING a kind — a shape the
    /// upsert never writes today, pinned because a future review path that clears `changed_at`
    /// and leaves `change_kind` must not re-raise the banner. The mutation sweep found the
    /// second necessary: without it, dropping the stamp check from the guard survived.
    @Test("An unstamped row says nothing, stale or not — even when it still carries a kind")
    func unstampedRowIsSilent() {
        for first in [row(kind: nil, stamped: false), row(kind: "body", stamped: false)] {
            #expect(DocumentChangeBanner.line(revision: first, highlightsStale: false) == nil)
            #expect(DocumentChangeBanner.line(revision: first, highlightsStale: true) == Self.hedge)
        }
    }

    @Test("A reviewed row is silent again — a review must not need a delete")
    func reviewedRowIsSilent() {
        let reviewed = row(kind: "body", reviewed: true)
        #expect(DocumentChangeBanner.line(revision: reviewed, highlightsStale: false) == nil)
        #expect(DocumentChangeBanner.line(revision: reviewed, highlightsStale: true) == Self.hedge)
    }

    @Test("A body change names the text, and hedges the highlights only when they are stale")
    func bodyChange() throws {
        let fresh = try #require(DocumentChangeBanner.line(revision: row(kind: "body"), highlightsStale: false))
        let stale = try #require(DocumentChangeBanner.line(revision: row(kind: "body"), highlightsStale: true))
        #expect(fresh.hasPrefix("The text of this document changed"))
        #expect(fresh.contains("positions may have moved"))
        #expect(!fresh.contains("misaligned"))
        #expect(stale.hasPrefix("The text of this document changed"))
        #expect(stale.contains("misaligned"))
        #expect(fresh != stale)
    }

    @Test("An apparatus change says the text did NOT change — unless highlights are stale, when it says both")
    func apparatusChange() throws {
        let fresh = try #require(DocumentChangeBanner.line(revision: row(kind: "apparatus"), highlightsStale: false))
        let stale = try #require(DocumentChangeBanner.line(revision: row(kind: "apparatus"), highlightsStale: true))
        #expect(fresh.hasPrefix("Footnotes, the source note, or the heading changed"))
        #expect(fresh.contains("The text did not"))
        #expect(!fresh.contains("misaligned"))
        #expect(stale.hasPrefix("Footnotes, the source note, or the heading changed"))
        #expect(stale.contains("misaligned"))
        #expect(!stale.contains("The text did not"))
    }

    @Test("A vanished row says so regardless of highlights")
    func vanished() throws {
        let a = try #require(DocumentChangeBanner.line(revision: row(kind: "vanished"), highlightsStale: false))
        let b = try #require(DocumentChangeBanner.line(revision: row(kind: "vanished"), highlightsStale: true))
        #expect(a == b)
        #expect(a.contains("no longer in the volume"))
    }

    @Test("A change kind this build does not know falls back: hedge if stale, silence if not")
    func unknownKind() {
        #expect(DocumentChangeBanner.line(revision: row(kind: "renumbered"), highlightsStale: false) == nil)
        #expect(DocumentChangeBanner.line(revision: row(kind: "renumbered"), highlightsStale: true) == Self.hedge)
    }
}
