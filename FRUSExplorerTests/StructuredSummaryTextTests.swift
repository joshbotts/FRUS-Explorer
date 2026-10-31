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

/// The Meeting Record template's fields, as `SummarizationPromptSeeder` seeds them.
private let meeting = StructuredSummarySchema(fields: [
    .init(name: "KeyParticipants", description: "Principal speakers, with the official capacity the document states for them"),
    .init(name: "Topics", description: "Main subjects discussed"),
    .init(name: "Agreements", description: "Points of consensus or decisions reached"),
    .init(name: "Disagreements", description: "Notable points of divergence or unresolved issues"),
])

// MARK: - StructuredSectionAnswerTests

/// How a structured prompt's answer is asked for and read back (2026-10-31). The answers are the shapes
/// the on-device model wrote in the measurement `StructuredSectionAnswer` records, and the ones a
/// reader's own field names can produce; the model is not run.
///
/// Version history:
///   1.0 — 2026-10-31: initial implementation
@Suite("Structured section answers")
struct StructuredSectionAnswerTests {

    @Test("A field's heading is its name as words, and a name with spaces keeps them")
    func headings() {
        #expect(StructuredSectionAnswer.heading(for: "KeyParticipants") == "Key Participants")
        #expect(StructuredSectionAnswer.heading(for: "PolicyImplications") == "Policy Implications")
        #expect(StructuredSectionAnswer.heading(for: "Subject") == "Subject")
        #expect(StructuredSectionAnswer.heading(for: "Dates and places") == "Dates and places")
        #expect(StructuredSectionAnswer.heading(for: "NARAFile") == "NARAFile")
    }

    /// The measured wording, in the schema's order, each description beneath its heading.
    @Test("The instructions ask for every field as a heading, in order, with its description")
    func instructions() throws {
        let text = StructuredSectionAnswer.instructions(for: meeting)
        #expect(text.hasPrefix("Write the answer in Markdown under exactly these headings, in this order, each heading on a line of its own as shown, followed by its content in plain prose. Do not add other headings or any text before the first heading."))
        let positions = try ["## Key Participants\n(Principal speakers, with the official capacity the document states for them)",
                             "## Topics\n(Main subjects discussed)",
                             "## Agreements\n(Points of consensus or decisions reached)",
                             "## Disagreements\n(Notable points of divergence or unresolved issues)"]
            .map { try #require(text.range(of: $0)).lowerBound }
        #expect(positions == positions.sorted())

        let bare = StructuredSectionAnswer.instructions(
            for: StructuredSummarySchema(fields: [.init(name: "Dates", description: "  ")]))
        #expect(bare.hasSuffix("## Dates"))
    }

    /// The shape of nearly every answer measured: the headings asked for, prose under each.
    @Test("Markdown headings are read into their fields")
    func markdownHeadings() throws {
        let values = try #require(StructuredSectionAnswer.values(in: """
            ## Key Participants
            The Chargé in the Soviet Union, writing to the Secretary of State.

            ## Topics
            The postwar Soviet outlook and its background.

            ## Agreements
            No formal agreements are recorded.

            ## Disagreements
            The Chargé disputes the premises of the party line.
            """, schema: meeting))
        #expect(values == [
            "KeyParticipants": "The Chargé in the Soviet Union, writing to the Secretary of State.",
            "Topics": "The postwar Soviet outlook and its background.",
            "Agreements": "No formal agreements are recorded.",
            "Disagreements": "The Chargé disputes the premises of the party line.",
        ])
    }

    @Test("Bold, colon and run-together labels are headings too, in any order")
    func otherLabels() throws {
        let values = try #require(StructuredSectionAnswer.values(in: """
            **Topics:** Tariffs.
            **KeyParticipants**: The Minister.
            - Disagreements: None.
            ### agreements
            A joint study.
            """, schema: meeting))
        #expect(values["KeyParticipants"] == "The Minister.")
        #expect(values["Topics"] == "Tariffs.")
        #expect(values["Agreements"] == "A joint study.")
        #expect(values["Disagreements"] == "None.")
    }

    /// The reader shows the stored JSON's text on some surfaces, where a line break would print as
    /// `\n`; the model wrote bullets and bold inside a section in some answers.
    @Test("A section is made one paragraph: lists, bold, rules and a repeated description go")
    func oneParagraph() throws {
        let values = try #require(StructuredSectionAnswer.values(in: """
            ## Key Participants
            (Principal speakers, with the official capacity the document states for them)
            The Minister in China (MacMurray).

            ## Topics
            - Japanese troops at Tsingtau
            - **The Lunghai Railroad**

            ## Agreements
            1. The British will help defend Peking.
            2. No legation will leave.

            ---

            ## Disagreements
            None
            recorded.
            """, schema: meeting))
        #expect(values["KeyParticipants"] == "The Minister in China (MacMurray).")
        #expect(values["Topics"] == "Japanese troops at Tsingtau; The Lunghai Railroad")
        #expect(values["Agreements"] == "The British will help defend Peking. No legation will leave.")
        #expect(values["Disagreements"] == "None recorded.")
    }

    /// The shape of a synthesis answer measured on 2026-10-31, which read *paths:; Adoption…;;* before
    /// the items' own semicolons were dropped.
    @Test("A lead-in line and items that end in semicolons make one sentence")
    func leadInAndSemicolons() throws {
        let values = try #require(StructuredSectionAnswer.values(in: """
            ## Key Participants
            The Ambassador.
            ## Topics
            The document presents several paths:
            - Restrictive measures by other nations;
            - American leadership, which opinion opposes,
            - Guidance from Washington
            ## Agreements
            None.
            ## Disagreements
            None.
            """, schema: meeting))
        #expect(values["Topics"] == "The document presents several paths: Restrictive measures by other nations; American leadership, which opinion opposes; Guidance from Washington")

        let mixed = try #require(StructuredSectionAnswer.values(in: """
            ## Key Participants
            - The Ambassador.
            - The Consul
            - The Minister
            ## Topics
            T.
            ## Agreements
            A.
            ## Disagreements
            D.
            """, schema: meeting))
        #expect(mixed["KeyParticipants"] == "The Ambassador. The Consul; The Minister")
    }

    /// 19 of the 713 answers measured on 2026-10-31 wrote their sections a second time, or added a
    /// heading of their own; until a section ended at every heading, the repeat landed in the last field.
    @Test("A section ends at any heading: a repeated set or an added heading stays out")
    func repeatedAndAddedHeadings() throws {
        let values = try #require(StructuredSectionAnswer.values(in: """
            ## Key Participants
            The Ambassadors.
            ## Topics
            Shipping.
            ## Agreements
            None.
            ## Disagreements
            The convention's reach.
            ## Key Participants
            The Ambassadors again.
            ## Topics
            Shipping again.
            ## Note
            An aside.
            """, schema: meeting))
        #expect(values["KeyParticipants"] == "The Ambassadors.")
        #expect(values["Topics"] == "Shipping.")
        #expect(values["Disagreements"] == "The convention's reach.")
    }

    @Test("A missing heading, or a refusal written as the answer, reads as no answer")
    func missingHeading() {
        #expect(StructuredSectionAnswer.values(
            in: "## Topics\nA.\n## Agreements\nB.\n## Disagreements\nC.", schema: meeting) == nil)
        #expect(StructuredSectionAnswer.values(
            in: "I’m sorry, but I can’t assist with that request.", schema: meeting) == nil)
        #expect(StructuredSectionAnswer.values(in: "", schema: meeting) == nil)
    }

    /// A reader's own prompt can name one field with the start of another's name, and an answer can
    /// open a sentence with a field's name.
    @Test("A heading is the whole name: a longer name or a sentence is not read as it")
    func wholeNames() throws {
        let schema = StructuredSummarySchema(fields: [
            .init(name: "Subject", description: ""), .init(name: "SubjectDetails", description: ""),
        ])
        let values = try #require(StructuredSectionAnswer.values(
            in: "## Subject Details\nD.\n## Subject\nS.", schema: schema))
        #expect(values == ["Subject": "S.", "SubjectDetails": "D."])
        #expect(StructuredSectionAnswer.values(
            in: "Subject to review.\n## Subject Details\nD.", schema: schema) == nil)
    }

    /// Characters a reader may type in a field's name are matched as themselves.
    @Test("A name with pattern characters is matched as written")
    func patternCharacters() throws {
        let schema = StructuredSummarySchema(fields: [.init(name: "Cost ($)", description: ""),
                                                      .init(name: "Who?", description: "")])
        let values = try #require(StructuredSectionAnswer.values(in: "## Cost ($)\nTen.\n## Who?\nThe Consul.", schema: schema))
        #expect(values == ["Cost ($)": "Ten.", "Who?": "The Consul."])
    }

    @Test("The JSON is the object a structured summary stores, its members in the schema's order")
    func json() throws {
        let values = ["Topics": "A \"quoted\" / slashed\ttab", "KeyParticipants": "B",
                      "Agreements": "", "Disagreements": "D"]
        let json = StructuredSectionAnswer.jsonString(values, schema: meeting)
        #expect(json == #"{"KeyParticipants": "B", "Topics": "A \"quoted\" / slashed\ttab", "Agreements": "", "Disagreements": "D"}"#)
        let decoded = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: String])
        #expect(decoded == values)
    }
}

// MARK: - StructuredSummaryDisplayTests

/// A stored summary as the reader shows it (2026-10-31).
///
/// Version history:
///   1.0 — 2026-10-31: initial implementation
@Suite("Structured summary display")
struct StructuredSummaryDisplayTests {

    /// Guided generation stored its members in no fixed order; the reader shows the schema's.
    @Test("A structured summary's fields come labelled, in the schema's order, then any others by name")
    func fieldsInSchemaOrder() throws {
        let stored = #"{"Disagreements": "D", "Extra": "E", "KeyParticipants": "K", "Topics": "T", "Agreements": "A", "Aside": "S"}"#
        let fields = try #require(StructuredSummaryDisplay.fields(responseText: stored, format: .structured(schema: meeting)))
        #expect(fields.map(\.label) == ["Key Participants", "Topics", "Agreements", "Disagreements", "Aside", "Extra"])
        #expect(fields.map(\.text) == ["K", "T", "A", "D", "S", "E"])
    }

    @Test("Plain text, and text that is not a JSON object of strings, is shown as stored")
    func storedTextAsIs() {
        let structured = ResponseFormat.structured(schema: meeting)
        #expect(StructuredSummaryDisplay.fields(responseText: #"{"Topics": "T"}"#, format: .general) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: "An edited headnote.", format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: #"{"Topics": 3}"#, format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: "{}", format: structured) == nil)
        #expect(StructuredSummaryDisplay.fields(responseText: #"["Topics"]"#, format: structured) == nil)

        let edited = StructuredSummaryDisplay.text(responseText: "An edited headnote.", format: structured)
        #expect(String(edited.characters) == "An edited headnote.")
    }

    @Test("The reader's text is one field a line, each label in bold")
    func readerText() throws {
        let stored = #"{"Topics": "Tariffs.", "KeyParticipants": "The Minister.", "Agreements": "", "Disagreements": "None."}"#
        let text = StructuredSummaryDisplay.text(responseText: stored, format: .structured(schema: meeting))
        #expect(String(text.characters) == "Key Participants: The Minister.\nTopics: Tariffs.\nAgreements: \nDisagreements: None.")
        let bold = text.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            .map { String(text[$0.range].characters) }
        #expect(bold == ["Key Participants:", "Topics:", "Agreements:", "Disagreements:"])
    }

    /// The answer the provider writes is the text the reader reads back.
    @Test("An answer read by StructuredSectionAnswer shows as its fields")
    func roundTrip() throws {
        let json = try AppleIntelligenceProvider.structuredJSON(
            fromAnswer: "## Key Participants\nK.\n## Topics\nT.\n## Agreements\nA.\n## Disagreements\nD.",
            schema: meeting)
        let fields = try #require(StructuredSummaryDisplay.fields(responseText: json, format: .structured(schema: meeting)))
        #expect(fields == [.init(label: "Key Participants", text: "K."), .init(label: "Topics", text: "T."),
                           .init(label: "Agreements", text: "A."), .init(label: "Disagreements", text: "D.")])
    }
}
