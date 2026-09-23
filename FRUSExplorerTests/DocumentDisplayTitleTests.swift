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

    /// The case this type was written for: 8,467 of 8,474 headerless documents on a full index
    /// built before v55. From v55 the index stores every note's printed head (#1372), so this
    /// branch serves an index not yet rebuilt — and the generic heads below.
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

    /// #1372: 2,560 notes print only *Editorial Note*, up to 99 in one volume. Stored as their
    /// title, a list of them would read identically; the number tells them apart.
    @Test("A note whose printed head only says Editorial Note is numbered")
    func genericNoteHeadIsNumbered() {
        #expect(DocumentDisplayTitle.text(facts(header: "Editorial Note", number: "2", note: true),
                                          documentId: "d2") == "Editorial Note 2")
        #expect(DocumentDisplayTitle.text(facts(header: "Editor\u{2019}s Note", number: "710",
                                                note: true), documentId: "d710")
                == "Editorial Note 710")
        #expect(DocumentDisplayTitle.text(facts(header: "[Untitled]", number: "1137", note: true),
                                          documentId: "d1137") == "Editorial Note 1137")
    }

    /// The generic rule is about notes: a printed DOCUMENT titled *Note* is what its volume calls it.
    @Test("A document that is not a note keeps a generic-looking head")
    func genericHeadOnADocumentIsKept() {
        #expect(DocumentDisplayTitle.text(facts(header: "Note", number: "12"), documentId: "d12")
                == "Note")
    }

    /// Numbered heads and real titles are names — 5,114 and 825 of them — and must not be replaced.
    @Test("A note's numbered head or real title is kept")
    func namingNoteHeadsAreKept() {
        #expect(DocumentDisplayTitle.text(facts(header: "245. Editorial Note", number: "245",
                                                note: true), documentId: "d245")
                == "245. Editorial Note")
        #expect(DocumentDisplayTitle.text(
            facts(header: "Editorial Note on a Meeting at the White House, December 18, 1941",
                  number: "25", note: true), documentId: "d25")
                == "Editorial Note on a Meeting at the White House, December 18, 1941")
    }

    /// The exact list, measured over the corpus's note heads, in each spelling it occurs in.
    @Test("isGenericNoteHead matches the corpus's generic heads and nothing that names a note")
    func genericNoteHeadVocabulary() {
        for head in ["Editorial Note", "Editorial note", "editorial note.", "Editorial Notes",
                     "Editor\u{2019}s Note", "Editor's Note", "[Editorial Note]", "[Untitled]",
                     "Note", "  Editorial Note  "] {
            #expect(DocumentDisplayTitle.isGenericNoteHead(head), "\(head) should be generic")
        }
        for head in ["245. Editorial Note", "ETA\u{2013}16. Editorial Note",
                     "The World War: Editorial note", "Memorandum by Prime Minister Churchill",
                     "Introduction", ""] {
            #expect(!DocumentDisplayTitle.isGenericNoteHead(head), "\(head) names its note")
        }
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

// MARK: - CrossReferenceTargetLabelTests

/// What Cross-Reference Analytics calls a row's document (#1372).
///
/// The rule it replaced keyed on an empty header, so an indexed editorial note — stored with an
/// empty header before index v55 — was named "Document 245 — <volume title>", the form both
/// manuals reserve for a volume the reader has not downloaded. Membership decides now. Each branch
/// has a fixture of its own, so dropping one fails at least the test named for it.
///
/// Version history:
///   1.0 — #1372: initial implementation
@Suite("Cross-Reference Analytics target labels")
struct CrossReferenceTargetLabelTests {

    private let title = "Foreign Relations of the United States, 1964–1968, Volume II, Vietnam"

    @Test("An indexed document with a head is named by it")
    func indexedWithHead() {
        let facts = CrossReferenceStore.DocumentTitleFacts(
            header: "255. Telegram From the Embassy in Vietnam", documentNumber: "255",
            isEditorialNote: false)
        #expect(CrossReferenceTargetLabel.text(facts: facts, documentId: "d255", volumeTitle: title)
                == "255. Telegram From the Embassy in Vietnam")
    }

    /// The #1372 defect itself: indexed, but with no stored head (an index built before v55).
    /// It must NOT take the not-downloaded form.
    @Test("An indexed editorial note with no stored head is not named as undownloaded")
    func indexedNoteWithoutStoredHead() {
        let facts = CrossReferenceStore.DocumentTitleFacts(
            header: nil, documentNumber: "245", isEditorialNote: true)
        let label = CrossReferenceTargetLabel.text(facts: facts, documentId: "d245", volumeTitle: title)
        #expect(label == "Editorial Note 245")
        #expect(!label.contains(title))
    }

    /// One of the corpus's seven headerless documents that are not notes.
    @Test("An indexed headerless document falls through to its id, not the manifest form")
    func indexedHeaderlessNonNote() {
        let facts = CrossReferenceStore.DocumentTitleFacts(
            header: nil, documentNumber: nil, isEditorialNote: false)
        #expect(CrossReferenceTargetLabel.text(facts: facts, documentId: "d508d", volumeTitle: title)
                == "d508d")
    }

    @Test("A document in a volume not downloaded takes the manifest form")
    func notIndexed() {
        #expect(CrossReferenceTargetLabel.text(facts: nil, documentId: "d245", volumeTitle: title)
                == "Document 245 — \(title)")
    }

    @Test("A not-downloaded id without the d prefix is printed whole")
    func notIndexedUnprefixedId() {
        #expect(CrossReferenceTargetLabel.text(facts: nil, documentId: "ch3", volumeTitle: title)
                == "Document ch3 — \(title)")
    }
}
