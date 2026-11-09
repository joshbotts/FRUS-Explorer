// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - VolumeAnnotationsPresentationTests

/// Tests for what a volume page's "Editors’ Annotations" section says
/// (`Planning/Editors-Annotations-Design-2026-11-06.md`, §5): the rows' copy and spoken labels, the
/// rule that a layer is in the volume or not, the standard layers a volume lacks with their onsets,
/// and the shipped file read through `VolumeAnnotationsStore`.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane B
///   1.1 — 2026-11-06: the shipped file's `frus1981-88v16` explains its abbreviations, which its
///          documents name on `@ana`, and `frus1941-43`'s printed aids name its Index of Persons as the
///          index it is (index version 74)
///   1.2 — 2026-11-08: Marked editorial omissions, the sixteenth row, and the 1925 gate (Lane 1 of
///          `Planning/Editors-Annotations-Followups-2026-11-08.md`)
@Suite("Editors’ Annotations — what a volume page says about its editors' annotation")
struct VolumeAnnotationsPresentationTests {

    private let locale = Locale(identifier: "en_US")

    /// A volume of `documents` documents carrying `counts`.
    private func volume(_ era: AnnotationEra, documents: Int, persons: Int = 0, terms: Int = 0,
                        _ counts: [AnnotationCategory: Int], sections: [String] = [],
                        publicationYear: Int? = nil) -> VolumeAnnotations {
        VolumeAnnotations(documents: documents, historicalDocuments: documents - (counts[.editorialNotes] ?? 0),
                          personsListed: persons, termsListed: terms, era: era, counts: counts,
                          sections: sections, publicationYear: publicationYear)
    }

    private func index(_ volumes: [String: VolumeAnnotations]) -> VolumeAnnotationsIndex {
        VolumeAnnotationsIndex(generated: "2026-11-06", corpusCommit: "fixture", indexVersion: 73, volumes: volumes)
    }

    /// The China volume's own counts (`frus1969-76v17`), with a despatch number and a marginal note
    /// added so every row shows; its 32 bracketed omissions are the sweep's figure for it
    /// (`Planning/editors-annotations/omission-markers.json`).
    private var full: VolumeAnnotations {
        volume(.from1969, documents: 280, persons: 325, terms: 470, [
            .people: 279, .abbreviations: 278, .correspondents: 161, .subjects: 137, .participants: 67,
            .sourceCitation: 263, .sourceFileNumber: 5, .classification: 260, .excisions: 37,
            .editorialOmissions: 32, .despatch: 30,
            .numbered: 280, .xrefDocuments: 131, .xrefFootnotes: 65, .xrefVolumes: 89,
            .editorialNotes: 12, .footnotes: 243, .marginalNotes: 1,
        ], sections: ["back", "errata", "front", "index", "note-on-covert-actions", "persons", "preface",
                      "sources", "table-of-contents", "terms"], publicationYear: 2006)
    }

    @Test("Each row says its counts, in three groups, in the page's order")
    func rowsSayTheirCounts() throws {
        let section = VolumeAnnotationsPresentation(annotations: full, index: index(["v": full]), locale: locale)
        #expect(section.groups.map(\.id) == [.named, .provenance, .connects])
        #expect(section.groups.map(\.title) == ["Who is named", "Where it came from", "How it connects"])
        var detail: [String: String] = [:]
        for group in section.groups { for row in group.rows { detail[row.id] = row.detail } }
        #expect(section.groups.flatMap { $0.rows.map(\.id) } == [
            "people", "abbreviations", "correspondents", "subjects", "participants",
            "sourceNotes", "classification", "excisions", "editorialOmissions", "despatch",
            "numbered", "crossReferences", "editorialNotes", "footnotes", "marginalNotes", "printedAids",
        ])
        #expect(detail["people"] == "279 of 280 documents · 325 people listed")
        #expect(detail["abbreviations"] == "278 of 280 documents · 470 terms listed")
        #expect(detail["correspondents"] == "161 documents")
        #expect(detail["sourceNotes"] == "268 of 280 documents · archival citations and file numbers")
        #expect(detail["classification"] == "260 of 280 documents")
        #expect(detail["excisions"] == "37 documents with redactions marked")
        #expect(detail["editorialOmissions"] == "32 documents with editorial omissions marked")
        #expect(detail["numbered"] == "280 of 280 documents")
        #expect(detail["crossReferences"]
                == "131 documents cite others in this volume · 89 documents cite other volumes")
        #expect(detail["editorialNotes"] == "12 editorial notes")
        #expect(detail["marginalNotes"] == "1 document")
        #expect(detail["printedAids"]
                == "Preface · Sources · Abbreviations · Persons · Note on U.S. Covert Actions · Index · Errata")
        #expect(section.absent.isEmpty)
    }

    @Test("VoiceOver reads a row as one sentence, its parts joined by semicolons")
    func spokenRows() throws {
        let section = VolumeAnnotationsPresentation(annotations: full, index: index(["v": full]), locale: locale)
        let people = try #require(section.groups.first?.rows.first)
        #expect(people.accessibilityLabel == "People tagged: 279 of 280 documents; 325 people listed.")
    }

    @Test("A layer is in the volume or not: under half its documents, a pervasive layer is absent")
    func noPartialState() {
        let partial = volume(.from1955, documents: 10, [.people: 4, .sourceCitation: 6, .editorialNotes: 1])
        let section = VolumeAnnotationsPresentation(annotations: partial, index: index(["v": partial]),
                                                    locale: locale)
        let ids = section.groups.flatMap { $0.rows.map(\.id) }
        #expect(!ids.contains("people") && ids.contains("sourceNotes") && ids.contains("editorialNotes"))
        #expect(section.absent.map(\.id).contains("people"))
        // One editorial note is a counted layer, and singular.
        #expect(section.groups.flatMap(\.rows).first { $0.id == "editorialNotes" }?.detail == "1 editorial note")
        // The one form present names itself.
        #expect(section.groups.flatMap(\.rows).first { $0.id == "sourceNotes" }?.detail
                == "6 of 10 documents · archival citations (“Source: …”)")
    }

    @Test("A standard layer the volume lacks names the era from which the series made it standard")
    func absentLayersGiveTheirOnset() throws {
        var volumes: [String: VolumeAnnotations] = [:]
        let tagged = volume(.from1955, documents: 2, [.people: 2])
        for n in 0..<2 {
            volumes["a\(n)"] = volume(.from1861, documents: 2, [:])
            volumes["b\(n)"] = volume(.from1945, documents: 2, [:])
            volumes["d\(n)"] = tagged
            volumes["e\(n)"] = volume(.from1969, documents: 2, [.people: 2])
        }
        volumes["c0"] = tagged
        volumes["c1"] = volume(.from1951, documents: 2, [:])
        let early = try #require(volumes["a0"])
        let section = VolumeAnnotationsPresentation(annotations: early, index: index(volumes), locale: locale)
        #expect(section.groups.isEmpty)
        #expect(section.absent.map(\.id) == ["people", "abbreviations", "sourceNotes", "classification", "numbered",
                                             "referencesToDocuments", "editorialNotes", "noteOnSources"])
        #expect(section.absentTitle == "Not in this volume (8)")
        let people = try #require(section.absent.first)
        #expect(people.note == "Standard in the volumes covering 1955 on. Search the names instead.")
        #expect(people.accessibilityLabel
                == "Not in this volume: People tagged. Standard in the volumes covering 1955 on. Search the names instead.")
        // A practice no era made standard here gives no onset.
        #expect(section.absent.first { $0.id == "classification" }?.note == "")
    }

    @Test("Bracketed omissions show from 1925; a volume published before the order lists none, and is not told it lacks them")
    func editorialOmissionsFollowTheGate() {
        let before = volume(.from1914, documents: 1_200, [.correspondents: 1_200, .editorialOmissions: 16],
                            publicationYear: 1922)
        let gated = VolumeAnnotationsPresentation(annotations: before, index: index(["v": before]), locale: locale)
        #expect(!gated.groups.flatMap(\.rows).contains { $0.id == "editorialOmissions" })
        #expect(!gated.absent.contains { $0.id == "editorialOmissions" }, "an era-bound layer is never listed as missing")
        let from = volume(.from1920, documents: 800, [.correspondents: 800, .editorialOmissions: 1], publicationYear: 1940)
        let carried = VolumeAnnotationsPresentation(annotations: from, index: index(["v": from]), locale: locale)
        let row = carried.groups.flatMap(\.rows).first { $0.id == "editorialOmissions" }
        #expect(row?.detail == "1 document with an editorial omission marked")
        #expect(row?.symbol == "text.badge.minus" && row?.layer.family == .provenance)
        #expect(row?.accessibilityLabel == "Marked editorial omissions: 1 document with an editorial omission marked.")
    }

    @Test("A count is grouped for the locale, and a year is not")
    func countsAreGroupedYearsAreNot() {
        let big = volume(.from1955, documents: 2_000, [.people: 1_234])
        let section = VolumeAnnotationsPresentation(annotations: big, index: index(["v": big]), locale: locale)
        #expect(section.groups.first?.rows.first?.detail == "1,234 of 2,000 documents")
        #expect(VolumeAnnotationsPresentation.standardFrom(.from1955) == "Standard in the volumes covering 1955 on.")
    }

    // MARK: The shipped file

    @Test("The shipped file gives China, 1969–1972, the design's rows, and 1890 the eight it lacks")
    func theShippedFile() throws {
        let china = try #require(VolumeAnnotationsPresentation(volumeId: "frus1969-76v17", locale: locale),
                                 "volume-annotations-index.json must decode from the app bundle")
        let people = try #require(china.groups.first?.rows.first)
        #expect(people.detail == "279 of 280 documents · 325 people listed")
        #expect(china.groups.flatMap(\.rows).first { $0.id == "classification" }?.detail == "260 of 280 documents")
        #expect(china.groups.flatMap(\.rows).first { $0.id == "editorialOmissions" }?.detail
                == "32 documents with editorial omissions marked")
        #expect(china.absent.isEmpty)

        let papers1890 = try #require(VolumeAnnotationsPresentation(volumeId: "frus1890", locale: locale))
        #expect(papers1890.absent.count == 8)
        #expect(papers1890.absent.first?.note == "Standard in the volumes covering 1955 on. Search the names instead.")
        #expect(papers1890.groups.flatMap(\.rows).first { $0.id == "despatch" }?.detail == "347 documents")
        #expect(papers1890.groups.flatMap(\.rows).first { $0.id == "printedAids" }?.detail == "List of Papers · Index")
        // 1914 (published 1922) holds 16 bracketed omissions and is kept out by the 1925 gate: no
        // row, and no absent row either, since the layer is era-bound.
        let papers1914 = try #require(VolumeAnnotationsPresentation(volumeId: "frus1914", locale: locale))
        #expect(!papers1914.groups.flatMap(\.rows).contains { $0.id == "editorialOmissions" })
        #expect(!papers1914.absent.contains { $0.id == "editorialOmissions" })

        // The volume `VolumeAnnotationsSectionTests` opens carries every standard layer.
        let kennedy = try #require(VolumeAnnotationsPresentation(volumeId: "frus1961-63v06", locale: locale))
        #expect(kennedy.absent.isEmpty)
        #expect(kennedy.groups.first?.rows.first?.accessibilityLabel
                == "People tagged: 120 of 120 documents; 58 people listed.")
        #expect(VolumeAnnotationsPresentation(volumeId: "frus-no-such-volume") == nil)

        // 1981–88 vol. XVI names its terms on each document's `@ana`, which the reader lists below
        // the document, so its page explains them rather than listing them as absent.
        let southAmerica = try #require(VolumeAnnotationsPresentation(volumeId: "frus1981-88v16", locale: locale))
        #expect(southAmerica.groups.flatMap(\.rows).first { $0.id == "abbreviations" }?.detail
                == "88 of 88 documents · 108 terms listed")
        #expect(!southAmerica.absent.contains { $0.id == "abbreviations" })

        // The Washington and Casablanca conferences print an Index of Persons, which is an index:
        // no people are listed, and the printed aids do not name a List of Persons.
        let conferences = try #require(VolumeAnnotationsPresentation(volumeId: "frus1941-43", locale: locale))
        #expect(conferences.groups.flatMap(\.rows).first { $0.id == "printedAids" }?.detail
                == "Preface · Abbreviations · List of Papers · Index")
        #expect(!conferences.groups.flatMap(\.rows).contains { $0.id == "people" })
    }
}
