// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - StructuredSummaryDisplayTests

/// A stored summary's fields, as every surface that shows a summary reads them (2026-10-31): the
/// readers, the collection inspector and exports, the note editor, the Research rail's preview and the
/// search index's summary text. The app's suite (`StructuredSummaryTextTests.swift`) has the reader's
/// bold drawing and the round trip from the model's answer.
///
/// Version history:
///   1.0 — 2026-10-31: the field tests of the app's suite, moved with `StructuredSummaryDisplay` into
///          the kit; ``label(for:)`` and the plain text added
@Suite("Structured summary display")
struct StructuredSummaryDisplayTests {

    /// The Meeting Record template's fields, as `SummarizationPromptSeeder` seeds them.
    static let meeting = StructuredSummarySchema(fields: [
        .init(name: "KeyParticipants", description: "Principal speakers, with the official capacity the document states for them"),
        .init(name: "Topics", description: "Main subjects discussed"),
        .init(name: "Agreements", description: "Points of consensus or decisions reached"),
        .init(name: "Disagreements", description: "Notable points of divergence or unresolved issues"),
    ])

    @Test("A field's label is its name as words, and a name with spaces keeps them")
    func labels() {
        #expect(StructuredSummaryDisplay.label(for: "KeyParticipants") == "Key Participants")
        #expect(StructuredSummaryDisplay.label(for: "PolicyImplications") == "Policy Implications")
        #expect(StructuredSummaryDisplay.label(for: "Subject") == "Subject")
        #expect(StructuredSummaryDisplay.label(for: "Dates and places") == "Dates and places")
        #expect(StructuredSummaryDisplay.label(for: "NARAFile") == "NARAFile")
    }

    /// Guided generation stored its members in no fixed order; every surface shows the schema's.
    @Test("A structured summary's fields come labelled, in the schema's order, then any others by name")
    func fieldsInSchemaOrder() throws {
        let stored = #"{"Disagreements": "D", "Extra": "E", "KeyParticipants": " K\n", "Topics": "T", "Agreements": "A", "Aside": "S"}"#
        let fields = try #require(StructuredSummaryDisplay.fields(responseText: stored,
                                                                 format: .structured(schema: Self.meeting)))
        #expect(fields.map(\.label) == ["Key Participants", "Topics", "Agreements", "Disagreements", "Aside", "Extra"])
        #expect(fields.map(\.text) == ["K", "T", "A", "D", "S", "E"])
    }

    @Test("Plain text, and text that is not a JSON object of strings, has no fields")
    func noFields() {
        let structured = ResponseFormat.structured(schema: Self.meeting)
        #expect(StructuredSummaryDisplay.fields(responseText: #"{"Topics": "T"}"#, format: .general) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: "An edited headnote.", format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: #"{"Topics": 3}"#, format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: "{}", format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: #"["Topics"]"#, format: structured) == nil)
    }

    /// What a note, the index and a one-line preview hold: no braces, no quotes, no keys.
    @Test("The plain text is a Label: text paragraph a field, or the stored text as it is")
    func plainText() {
        let structured = ResponseFormat.structured(schema: Self.meeting)
        let stored = #"{"Topics": "Tariffs.", "KeyParticipants": "The Minister.", "Agreements": "", "Disagreements": "None."}"#
        #expect(StructuredSummaryDisplay.plainText(responseText: stored, format: structured)
                    == "Key Participants: The Minister.\n\nTopics: Tariffs.\n\nAgreements:\n\nDisagreements: None.")
        #expect(StructuredSummaryDisplay.plainText(responseText: stored, format: structured, separator: " ")
                    == "Key Participants: The Minister. Topics: Tariffs. Agreements: Disagreements: None.")
        #expect(StructuredSummaryDisplay.plainText(responseText: stored, format: .general) == stored,
                "a summary written as prose is its text, whatever it looks like")
        #expect(StructuredSummaryDisplay.plainText(responseText: "An edited headnote.", format: structured)
                    == "An edited headnote.")
    }
}
