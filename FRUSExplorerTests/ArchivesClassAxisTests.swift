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

// MARK: - ArchivesClassAxisTests

/// The Archives axis's class lens, divided by filing era (#1255).
///
/// Version history:
///   1.0 — #1255: initial implementation
@Suite("Archives — central-file classes by filing era")
struct ArchivesClassAxisTests {

    @Test("The eras are the shipped schedules' own spans, earliest first")
    func erasComeFromTheSchedules() throws {
        let eras = ArchivesClassAxis.eras()
        #expect(eras.count == 5, """
            Three decimal schedules and two subject-numeric ones. A count that moved without a \
            schedule being added means this lens has stopped reading their coverage blocks.
            """)
        #expect(eras.map(\.span.lowerBound) == eras.map(\.span.lowerBound).sorted())
        // The systems interleave in time rather than following one another cleanly: the decimal
        // file runs to 1963 and the subject-numeric one opens in 1963.
        #expect(eras.first?.system == .decimal)
        #expect(eras.last?.system == .subjectNumeric)
        #expect(eras.contains { $0.system == .subjectNumeric && $0.span.contains(1970) })
    }

    @Test("A volume straddling two schedules is counted in neither")
    func straddlingVolumesAreUnplaced() throws {
        let eras = ArchivesClassAxis.eras()
        let decimal = try #require(eras.first { $0.system == .decimal && $0.span.upperBound == 1949 })
        let fifties = try #require(eras.first { $0.system == .decimal && $0.span.lowerBound == 1950 })
        // 1948–1955 crosses the renumbering, where the same digits mean different things. Placing
        // it in either era would put its keys under a schedule that misreads half of them.
        #expect(ArchivesClassAxis.governs(decimal, 1948...1955) == false)
        #expect(ArchivesClassAxis.governs(fifties, 1948...1955) == false)
        // A volume wholly inside one schedule is placed.
        #expect(ArchivesClassAxis.governs(fifties, 1952...1958))
        // AND THE CLAMP: a volume opening before the decimal file existed is still placed in the
        // first schedule, because it holds no earlier keys to mislabel.
        #expect(ArchivesClassAxis.governs(decimal, 1861...1947))
    }

    @Test("Each era admits only its own filing system's keys")
    func systemsDoNotMix() throws {
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let coverage = ArchivalVolumeCoverage.map(from: entries)
        for era in ArchivesClassAxis.eras() {
            let rows = ArchivesClassAxis.rows(inEra: era, usage: usage, coverage: coverage)
            for row in rows {
                #expect(CollectionKeying.isSubjectNumericClass(row.key)
                        == (era.system == .subjectNumeric), """
                    \(row.key) listed under \(era.title), whose schedule cannot read it. Without \
                    the system test the section fills with unglossed rows that look like a \
                    failure of the labels rather than a category error.
                    """)
            }
        }
    }

    @Test("The same designator reads differently in two eras, which is the point")
    func oneKeyTwoReadings() throws {
        let eras = ArchivesClassAxis.eras()
        let early = try #require(eras.first {
            $0.system == .subjectNumeric && $0.span.upperBound == 1963
        })
        let later = try #require(eras.first {
            $0.system == .subjectNumeric && $0.span.contains(1970)
        })
        // The 1965 arrangement reused this designator and moved subversion to POL 23-7. A single
        // flat list would have to pick one of these and be wrong for the other era's documents.
        #expect(ArchivesClassAxis.gloss(for: "POL 24", era: early)
                    == "SUBVERSION. ESPIONAGE. SABOTAGE.")
        #expect(ArchivesClassAxis.gloss(for: "POL 24", era: later) == "SANCTIONS")

        // The same holds across the 1950 decimal renumbering, on the class the reader is most
        // likely to meet.
        let preWar = try #require(eras.first { $0.system == .decimal && $0.span.upperBound == 1949 })
        let sixties = try #require(eras.first {
            $0.system == .decimal && $0.span.lowerBound == 1960
        })
        let before = ArchivesClassAxis.gloss(for: "748.00", era: preWar)
        let after = ArchivesClassAxis.gloss(for: "748.00", era: sixties)
        #expect(before != nil && after != nil)
        #expect(before != after, """
            Country 48 is British Africa before 1950 and Poland after it; if these agree the \
            gloss is being asked with the wrong schedule. Got \(before ?? "nil") / \(after ?? "nil").
            """)
    }

    @Test("Over the real corpus every era carries rows, and they are ordered and drillable")
    func realCorpusRows() throws {
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let coverage = ArchivalVolumeCoverage.map(from: entries)
        var seen = 0
        for era in ArchivesClassAxis.eras() {
            let rows = ArchivesClassAxis.rows(inEra: era, usage: usage, coverage: coverage)
            guard !rows.isEmpty else { continue }
            seen += 1
            // Heaviest first, then by key — a total order, so the list is stable across launches.
            let ordered = rows.sorted {
                $0.documents == $1.documents ? $0.key < $1.key : $0.documents > $1.documents
            }
            #expect(rows.map(\.key) == ordered.map(\.key), "\(era.title) is not in a total order")
            #expect(rows.allSatisfy { $0.documents > 0 && !$0.volumeIds.isEmpty })

            let spec = ArchivesClassAxis.spec(for: rows[0], era: era, usage: usage)
            #expect(spec.volumeIds == rows[0].volumeIds)
            #expect(spec.caption?.isEmpty == false, "every counting axis owes a caption")
            #expect(spec.axisKey.hasPrefix("class:\(era.id):"))
        }
        #expect(seen >= 3, "only \(seen) eras carried any rows")
    }
}
