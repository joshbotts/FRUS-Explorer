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

// MARK: - DocumentDisplayTitleTests

/// What a document is called in a list when its printed head is not the answer.
///
/// The rule used to be spelled seven times as `headers[key] ?? documentId`, across three views,
/// and was wrong twice: first rendering blank (a headerless document came back as `""` rather than
/// absent), then rendering `d304`, which names the record without describing it. It lives in one
/// place now, and this suite is that place's contract.
///
/// Version history:
///   1.0 — initial implementation
@Suite("Document display titles")
struct DocumentDisplayTitleTests {

    private func facts(header: String? = nil, number: String? = nil,
                       note: Bool = false) -> CrossReferenceStore.DocumentTitleFacts {
        .init(header: header, documentNumber: number, isEditorialNote: note)
    }

    @Test("A printed head wins outright")
    func printedHeadWins() {
        #expect(DocumentDisplayTitle.text(facts(header: "Memorandum of Conversation"),
                                          documentId: "d12") == "Memorandum of Conversation")
        // Even for an editorial note that happens to carry one.
        #expect(DocumentDisplayTitle.text(facts(header: "A Head", number: "9", note: true),
                                          documentId: "d9") == "A Head")
    }

    /// The case this whole change exists for: 8,467 of 8,474 headerless documents on a full index.
    @Test("A headerless editorial note is named and numbered")
    func editorialNoteIsNamedAndNumbered() {
        #expect(DocumentDisplayTitle.text(facts(number: "304", note: true),
                                          documentId: "d304") == "Editorial Note 304")
    }

    /// The number is what tells two notes apart — without it a list of them reads identically.
    @Test("An unnumbered editorial note still says what it is")
    func unnumberedEditorialNote() {
        #expect(DocumentDisplayTitle.text(facts(note: true), documentId: "d7") == "Editorial Note")
    }

    /// Seven documents in the corpus are headerless and not notes; and an unindexed document has
    /// no facts at all. Both fall through to the id rather than to nothing.
    @Test("Anything else falls through to the document id")
    func fallsThroughToTheId() {
        #expect(DocumentDisplayTitle.text(facts(), documentId: "d508d") == "d508d")
        #expect(DocumentDisplayTitle.text(nil, documentId: "d1") == "d1")
    }

    /// The one guarantee every call site relies on: never blank. Rendering an empty string is the
    /// defect that started this.
    @Test("The title is never empty")
    func titleIsNeverEmpty() {
        for f in [facts(), facts(header: ""), facts(note: true), facts(number: "1", note: true), nil] {
            #expect(!DocumentDisplayTitle.text(f, documentId: "dX").isEmpty)
        }
    }
}
