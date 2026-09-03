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

// MARK: - HighlightReviewTests

/// The per-highlight review verbs (design §5.4, R-5 P3) and the repaint signature.
///
/// `confirm` is the first post-creation write to `renderingVersion` the app has ever made, and
/// `HighlightSignature` is what makes it visible: the web view used to compare id lists, so a
/// confirmed highlight stayed amber until reload. The signature test is the repaint claim.
///
/// Version history:
///   1.0 — R-5 P3: initial implementation
@Suite("Highlight review — confirm, delete, and the repaint signature")
struct HighlightReviewTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: DocumentHighlight.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private func highlight(version: String, passage: String = "the Ambassador") -> DocumentHighlight {
        let h = DocumentHighlight(volumeId: "v1", documentId: "d1", startOffset: 4, endOffset: 18,
                                  noteId: nil, renderingVersion: version)
        h.selectedText = passage
        return h
    }

    @Test("Status: aligned when versions match, stale otherwise, unverifiable with nothing to compare")
    func status() {
        let h = highlight(version: "abc")
        #expect(HighlightReview.status(of: h, currentVersion: "abc") == .aligned)
        #expect(HighlightReview.status(of: h, currentVersion: "def") == .stale(hasPassage: true))
        #expect(HighlightReview.status(of: highlight(version: "abc", passage: ""), currentVersion: "def")
                == .stale(hasPassage: false))
        #expect(HighlightReview.status(of: h, currentVersion: nil) == .unverifiable)
        #expect(HighlightReview.status(of: h, currentVersion: "") == .unverifiable)
    }

    @Test("Confirm rewrites renderingVersion and nothing else; an empty version is refused")
    @MainActor
    func confirm() throws {
        let container = try makeContainer()
        let h = highlight(version: "old")
        container.mainContext.insert(h)
        HighlightReview.confirm(h, currentVersion: "new")
        #expect(h.renderingVersion == "new")
        #expect(h.startOffset == 4 && h.endOffset == 18 && h.selectedText == "the Ambassador")
        HighlightReview.confirm(h, currentVersion: "")
        #expect(h.renderingVersion == "new")
        #expect(HighlightReview.status(of: h, currentVersion: "new") == .aligned)
    }

    @Test("Delete removes the row")
    @MainActor
    func delete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let h = highlight(version: "v")
        context.insert(h)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<DocumentHighlight>()) == 1)
        HighlightReview.delete(h, in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<DocumentHighlight>()) == 0)
    }

    @Test("The repaint signature changes on a confirm and on a moved offset, not on an unrelated field")
    func signature() {
        let h = highlight(version: "old")
        let before = HighlightSignature.signature(of: [h])
        h.colorTag = "green"
        #expect(HighlightSignature.signature(of: [h]) == before, "colour is not painted from the signature")
        HighlightReview.confirm(h, currentVersion: "new")
        #expect(HighlightSignature.signature(of: [h]) != before, "a confirm must repaint")
        let confirmed = HighlightSignature.signature(of: [h])
        h.startOffset = 5
        #expect(HighlightSignature.signature(of: [h]) != confirmed, "a moved offset must repaint")
        #expect(HighlightSignature.signature(of: []).isEmpty)
    }

    @Test("The sheet's standing line: vanished wins, then one sentence per status")
    @MainActor
    func statusLines() {
        let vanished = DocumentChangeReviewSheet.statusLine(.aligned, vanished: true)
        #expect(vanished.contains("no longer in the volume"))
        #expect(DocumentChangeReviewSheet.statusLine(.stale(hasPassage: true), vanished: true) == vanished)
        #expect(DocumentChangeReviewSheet.statusLine(.aligned, vanished: false) == "Matches the current text.")
        let stale = DocumentChangeReviewSheet.statusLine(.stale(hasPassage: true), vanished: false)
        let noPassage = DocumentChangeReviewSheet.statusLine(.stale(hasPassage: false), vanished: false)
        #expect(stale.contains("position may have moved") && !stale.contains("by eye"))
        #expect(noPassage.contains("by eye") && noPassage.contains("not stored"))
        #expect(DocumentChangeReviewSheet.statusLine(.unverifiable, vanished: false).contains("no record"))
    }
}
