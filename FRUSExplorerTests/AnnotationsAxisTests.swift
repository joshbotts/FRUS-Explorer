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

// MARK: - AnnotationsAxisTests

/// Tests for the Editors’ Annotations browse axis (`Planning/Editors-Annotations-Design-2026-11-06.md`,
/// §6): that a volume's page and the axis read one table of layers, each layer's reach across the
/// volumes and their eras, the sentence that says when it became standard, the drills' specs, and the
/// shipped file read through `VolumeAnnotationsStore`.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
///   1.1 — 2026-11-06: lane D — a matrix cell's drill, and the People captions' line
@Suite("Editors’ Annotations axis — each layer's reach, its page and its drills")
struct AnnotationsAxisTests {

    private let locale = Locale(identifier: "en_US")

    /// A volume of `documents` documents carrying `counts`.
    private func volume(_ era: AnnotationEra, documents: Int, persons: Int = 0, terms: Int = 0,
                        _ counts: [AnnotationCategory: Int] = [:], sections: [String] = []) -> VolumeAnnotations {
        VolumeAnnotations(documents: documents, historicalDocuments: documents, personsListed: persons,
                          termsListed: terms, era: era, counts: counts, sections: sections)
    }

    private func index(_ volumes: [String: VolumeAnnotations]) -> VolumeAnnotationsIndex {
        VolumeAnnotationsIndex(generated: "2026-11-06", corpusCommit: "fixture", indexVersion: 73, volumes: volumes)
    }

    // MARK: One table

    @Test("A volume page's rows are the axis's layers, in the same order and groups")
    func pageRowsAreTheAxisLayers() {
        let full = volume(.from1969, documents: 280, persons: 325, terms: 470, [
            .people: 279, .abbreviations: 278, .correspondents: 161, .subjects: 137, .participants: 67,
            .sourceCitation: 263, .classification: 260, .excisions: 37, .despatch: 30,
            .numbered: 280, .xrefDocuments: 131, .editorialNotes: 12, .footnotes: 243, .marginalNotes: 1,
        ], sections: ["preface", "index"])
        let section = VolumeAnnotationsPresentation(annotations: full, index: index(["v": full]), locale: locale)
        #expect(section.groups.flatMap { $0.rows.map(\.layer) } == AnnotationLayer.allCases)
        for group in section.groups {
            for row in group.rows { #expect(row.layer.family == group.id) }
        }
    }

    @Test("A volume page's absent row opens the layer that holds it")
    func absentRowsOpenTheirLayer() {
        let bare = volume(.from1861, documents: 2)
        let section = VolumeAnnotationsPresentation(annotations: bare, index: index(["a": bare]), locale: locale)
        let opened = Dictionary(uniqueKeysWithValues: section.absent.map { ($0.id, $0.layer) })
        #expect(opened == [
            "people": .people, "abbreviations": .abbreviations, "sourceNotes": .sourceNotes,
            "classification": .classification, "numbered": .numbered,
            "referencesToDocuments": .crossReferences, "editorialNotes": .editorialNotes,
            "noteOnSources": .printedAids,
        ])
    }

    // MARK: Reach

    @Test("A layer's reach: its volumes in id order, and each era's share, the retrospectives last")
    func reachCountsVolumesAndEras() {
        let tagged = volume(.from1955, documents: 2, [.people: 2])
        let untagged = volume(.from1955, documents: 2)
        let early = volume(.from1861, documents: 4, [.people: 1])
        let retro = volume(.retrospective, documents: 2, [.people: 2])
        let reach = AnnotationsAxis.reach(of: .people, in: index([
            "frus1955-57v10": tagged, "frus1955-57v2": tagged, "frus1958-60v01": untagged,
            "frus1861": early, "frus1917-72PubDipv06": retro,
        ]))
        // Numbers compare as numbers: v2 before v10.
        #expect(reach.carrying == ["frus1917-72PubDipv06", "frus1955-57v2", "frus1955-57v10"])
        #expect(reach.total == 5)
        #expect(reach.bands.map(\.era) == AnnotationEra.chronological + [.retrospective])
        let band1955 = reach.bands.first { $0.era == .from1955 }
        #expect(band1955?.carrying == 2 && band1955?.total == 3)
        // One document in four is under half: not carried.
        #expect(reach.bands.first { $0.era == .from1861 }?.carrying == 0)
        #expect(reach.bands.last?.share == 1)
    }

    @Test("When a layer became standard, or where a practice no era made standard is most common")
    func standardLines() {
        let volumes = index([
            "a": volume(.from1861, documents: 2, [.despatch: 2]),
            "b": volume(.from1861, documents: 2, [.despatch: 2]),
            "c": volume(.from1955, documents: 2, [.people: 2]),
            "d": volume(.from1969, documents: 2, [.people: 2]),
            "e": volume(.retrospective, documents: 2, [.marginalNotes: 1]),
        ])
        let people = AnnotationsAxis.reach(of: .people, in: volumes)
        #expect(people.onset == .from1955)
        #expect(AnnotationsAxis.standardLine(for: people) == "Standard in the volumes covering 1955 on.")
        #expect(AnnotationsAxis.spokenRow(for: people, locale: locale)
                == "People tagged: 2 of 5 volumes. Standard in the volumes covering 1955 on.")
        #expect(AnnotationsAxis.standardLine(for: AnnotationsAxis.reach(of: .despatch, in: volumes))
                == "No era made it standard. It is most common in the volumes covering 1861–1898.")
        #expect(AnnotationsAxis.standardLine(for: AnnotationsAxis.reach(of: .marginalNotes, in: volumes))
                == "No era made it standard. It is most common in the late retrospective volumes.")
        // A layer no volume carries says nothing of when.
        #expect(AnnotationsAxis.standardLine(for: AnnotationsAxis.reach(of: .subjects, in: volumes)).isEmpty)
    }

    @Test("Era names: a span, an open end, the retrospectives; a cell's label and what it reads")
    func eraNames() {
        #expect(AnnotationsAxis.eraName(.from1861) == "1861–1898")
        #expect(AnnotationsAxis.eraName(.from1981) == "1981 on")
        #expect(AnnotationsAxis.eraName(.retrospective) == "the late retrospectives")
        #expect(AnnotationsAxis.shortEraName(.from1955) == "1955")
        #expect(AnnotationsAxis.shortEraName(.retrospective) == "Retro.")
        let band = AnnotationsAxis.Band(era: .from1955, carrying: 58, total: 60)
        #expect(AnnotationsAxis.spokenBand(band, locale: locale) == "1955–1968: 58 of 60 volumes")
        #expect(AnnotationsAxis.spokenBand(AnnotationsAxis.Band(era: .retrospective, carrying: 1, total: 1),
                                           locale: locale) == "Late retrospectives: 1 of 1 volume")
    }

    // MARK: Drills

    @Test("A drill says how many volumes and by what rule, with each volume's count and its notes")
    func drillSpecs() throws {
        let china = volume(.from1969, documents: 280, persons: 325, [.people: 279])
        let unlinked = volume(.from1969, documents: 100, persons: 153)
        let partial = volume(.from1969, documents: 10, [.people: 3])
        let volumes = index(["frus1969-76v17": china, "frus1977-80v27": unlinked, "frus1969-76v05": partial])
        let drills = AnnotationsAxis.drills(for: .people, in: volumes, locale: locale)
        #expect(drills.map(\.id) == ["with", "without"])
        #expect(drills.map(\.count) == [1, 2])
        let with = try #require(drills.first).spec
        let without = try #require(drills.last).spec
        #expect(with.axisKey == "annotation:people:with" && without.axisKey == "annotation:people:without")
        #expect(with.title == "With: People tagged" && without.title == "Without: People tagged")
        #expect(with.volumeIds == ["frus1969-76v17"])
        #expect(without.volumeIds == ["frus1969-76v05", "frus1977-80v27"])
        #expect(with.caption
                == "1 of 3 volumes. A volume counts when at least half its documents link a name to its List of Persons.")
        #expect(with.accessories["frus1969-76v17"] == "279/280")
        // Under half shows its count; none shows nothing.
        #expect(without.accessories["frus1969-76v05"] == "3/10")
        #expect(without.accessories["frus1977-80v27"] == nil)
        #expect(without.notes == ["frus1977-80v27":
                                    "Prints a List of Persons, but none of its documents links a name to it."])
        #expect(with.notes.isEmpty)

        // Opened from a volume's page, the volume comes first, and says so after any other note.
        let fromPage = AnnotationsAxis.drills(for: .people, in: volumes, from: "frus1977-80v27", locale: locale)
        let marked = try #require(fromPage.last).spec
        #expect(marked.volumeIds == ["frus1977-80v27", "frus1969-76v05"])
        #expect(marked.notes["frus1977-80v27"]
                == "Prints a List of Persons, but none of its documents links a name to it. You came here from this volume.")
        // The same list, by its key: the mark does not make it another level.
        #expect(marked == without)
    }

    @Test("A layer found here and there counts documents; editorial notes count notes; references none")
    func countedAccessories() {
        let annotated = volume(.from1969, documents: 280, [.editorialNotes: 12, .excisions: 37, .xrefDocuments: 9])
        #expect(AnnotationsAxis.accessory(for: .editorialNotes, annotated, locale: locale) == "12 notes")
        #expect(AnnotationsAxis.accessory(for: .excisions, annotated, locale: locale) == "37 docs")
        #expect(AnnotationsAxis.accessory(for: .crossReferences, annotated, locale: locale) == nil)
        let one = volume(.from1969, documents: 2, [.editorialNotes: 1])
        #expect(AnnotationsAxis.accessory(for: .editorialNotes, one, locale: locale) == "1 note")
    }

    @Test("Source notes add one drill per form; the printed aids have one per aid")
    func formAndAidDrills() throws {
        let volumes = index([
            "c": volume(.from1969, documents: 2, [.sourceCitation: 2], sections: ["persons", "index"]),
            "f": volume(.from1914, documents: 2, [.sourceFileNumber: 2], sections: ["index", "intro"]),
            "b": volume(.from1951, documents: 4, [.sourceCitation: 2, .sourceFileNumber: 2],
                        sections: ["introduction"]),
        ])
        let source = AnnotationsAxis.drills(for: .sourceNotes, in: volumes, locale: locale)
        #expect(source.map(\.id) == ["with", "without", "citation", "fileNumber"])
        #expect(source[2].spec.axisKey == "annotation:sourceNotes:citation")
        #expect(source[2].spec.volumeIds == ["b", "c"])
        #expect(source[3].spec.volumeIds == ["b", "f"])
        #expect(source[2].spec.accessories["b"] == "2/4")

        let aids = AnnotationsAxis.drills(for: .printedAids, in: volumes, locale: locale)
        #expect(aids.map(\.title) == ["Introduction", "Persons", "Index"])
        // "intro" and "introduction" are one aid.
        let introduction = try #require(aids.first)
        #expect(introduction.spec.axisKey == "annotation:printedAids:intro")
        #expect(introduction.spec.volumeIds == ["b", "f"])
        #expect(introduction.spec.caption == "2 of 3 volumes. A volume counts when it prints this aid.")
    }

    @Test("A matrix cell opens its era's volumes that carry the layer, the era in its title and caption")
    func eraDrills() throws {
        let volumes = index([
            "frus1955-57v02": volume(.from1955, documents: 2, [.people: 2]),
            "frus1955-57v10": volume(.from1955, documents: 2, [.people: 2]),
            "frus1958-60v01": volume(.from1955, documents: 2),
            "frus1969-76v17": volume(.from1969, documents: 2, [.people: 2]),
            "frus1917-72PubDipv06": volume(.retrospective, documents: 2, [.people: 2]),
        ])
        let drill = AnnotationsAxis.eraDrill(for: .people, era: .from1955, in: volumes, locale: locale)
        #expect(drill.count == 2)
        #expect(drill.spec.axisKey == "annotation:people:era:1955-1968")
        #expect(drill.spec.title == "People tagged, 1955–1968")
        #expect(drill.spec.volumeIds == ["frus1955-57v02", "frus1955-57v10"])
        #expect(drill.spec.caption
                == "1955–1968: 2 of 3 volumes. A volume counts when at least half its documents link a name to its List of Persons.")
        let retro = AnnotationsAxis.eraDrill(for: .people, era: .retrospective, in: volumes, locale: locale)
        #expect(retro.spec.title == "People tagged, the late retrospectives")
        #expect(retro.spec.caption?.hasPrefix("Late retrospectives: 1 of 1 volume. ") == true)
        // An era none of whose volumes carries it opens nothing to list.
        #expect(AnnotationsAxis.eraDrill(for: .people, era: .from1861, in: volumes, locale: locale).count == 0)
    }

    // MARK: The shipped file

    @Test("The shipped file's matrix cell and the People captions' line")
    func shippedCellAndCaption() throws {
        let index = try #require(VolumeAnnotationsStore.shared)
        let people = AnnotationsAxis.reach(of: .people, in: index)
        let band = try #require(people.bands.first { $0.era == .from1955 })
        #expect(AnnotationsAxis.spokenCell(.people, band, locale: locale)
                == "People tagged, 1955–1968: 114 of 114 volumes")
        #expect(AnnotationsAxis.eraDrill(for: .people, era: .from1955, in: index, locale: locale).count == 114)
        #expect(PeopleTaggingCaption.text(index: index, locale: locale)
                == "People are tagged in 288 of 553 volumes, and only those volumes' people appear here. In the others, search for the names.")
        #expect(PeopleTaggingCaption.text(index: nil, locale: locale) == nil)
    }

    @Test("The shipped file: people tagged in 288 of 553 volumes from 1955 on, two Lists of Persons unlinked")
    func theShippedFile() throws {
        let index = try #require(VolumeAnnotationsStore.shared,
                                 "volume-annotations-index.json must decode from the app bundle")
        let people = AnnotationsAxis.reach(of: .people, in: index)
        #expect(people.carrying.count == 288 && people.total == 553)
        #expect(people.onset == .from1955)
        #expect(AnnotationsAxis.spokenRow(for: people, locale: locale)
                == "People tagged: 288 of 553 volumes. Standard in the volumes covering 1955 on.")
        let band1955 = try #require(people.bands.first { $0.era == .from1955 })
        #expect(band1955.carrying == 114 && band1955.total == 114)
        // In id order, the volume the UI suite opens is the 126th: why a drill puts its own first.
        #expect(people.carrying.firstIndex(of: "frus1961-63v06") == 125)

        let without = try #require(AnnotationsAxis.drills(for: .people, in: index, locale: locale)
            .first { $0.id == "without" })
        #expect(without.count == 265)
        #expect(without.spec.notes["frus1977-80v27"]
                == "Prints a List of Persons, but none of its documents links a name to it.")
        #expect(Set(without.spec.notes.keys) == ["frus1941-43", "frus1977-80v27"])

        // Every layer has volumes to show.
        for layer in AnnotationLayer.allCases {
            #expect(!AnnotationsAxis.reach(of: layer, in: index).carrying.isEmpty, "\(layer) has no volume")
        }
    }
}
