// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalAnalyticsMode

/// The modes of ``ArchivalAnalyticsView``, in picker order.
///
/// Two of the design's four modes ship here (#765 stage 1). Network and Flows are the two
/// custom-drawn `Canvas` surfaces and land next; they are absent from this enum rather than
/// present-and-empty, so the picker never offers a segment that does nothing.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1 (Collections + Your Library)
enum ArchivalAnalyticsMode: String, CaseIterable, Identifiable, Sendable {
    /// Corpus-wide era × archival-unit rankings and lifecycles.
    case collections
    /// The archival profile of the volumes this user has indexed.
    case yourLibrary

    var id: String { rawValue }

    /// Segment label.
    var title: String {
        switch self {
        case .collections:
            return String(localized: "archival.mode.collections", defaultValue: "Collections")
        case .yourLibrary:
            return String(localized: "archival.mode.yourLibrary", defaultValue: "Your Library")
        }
    }
}

// MARK: - ArchivalRepositoryCategory

/// The four-way custodial bucket the archival-analytics surfaces colour by — who holds the
/// records an authority collection names.
///
/// ## Why this is not ``SourceProvenanceCategory``
/// SA-3's ten-way category classifies a **parsed source note**: it can tell a pre-1963 decimal
/// citation from its post-1963 successor because it read the citation. This classifies an
/// **authority record**, which has only a repository keyword, a lot key, and a name. The two
/// answer different questions from different inputs, and folding them into one enum would mean
/// one of the two surfaces silently reporting a class it cannot actually distinguish.
///
/// ## What each case really tests
/// The rule is deliberately narrow, and the labels say only what the rule proves. In
/// particular ``stateDepartment`` is *not* "central files": measured over the shipped
/// authority, 392 records reach it, and while the four `Central Files` records carry the bulk
/// of the documents, the tail includes post files (`Accra Consulate Files`) and Department
/// series that are not central filing at all. Calling the bucket "Central Files" would be a
/// claim the data does not support, so it is called what it is.
///
/// Measured on the 2026-08-06 authority (4,423 records): 1,727 lot files, 1,853 other
/// institutions, 451 presidential libraries, 392 Department of State. No record is both
/// lot-keyed and presidential, so the order of the tests below is not load-bearing today —
/// it is fixed anyway, because a future re-clustering could produce one.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
enum ArchivalRepositoryCategory: String, CaseIterable, Identifiable, Sendable, Hashable {
    /// A numbered State Department bureau, office, or post lot file.
    case lotFile
    /// Material the corpus attributes to the Department of State that is not a numbered lot —
    /// the central files above all, plus the Department's own named series.
    case stateDepartment
    /// A presidential library or the Nixon presidential materials.
    case presidentialLibrary
    /// Every other custodian: NARA record groups, the Washington National Records Center, CIA,
    /// Defense, the Library of Congress, universities, and records the corpus leaves
    /// unattributed.
    case otherInstitution

    var id: String { rawValue }

    /// Display order — heaviest and most specific first, "other" last, matching the legend.
    static let ordered: [ArchivalRepositoryCategory] = [
        .stateDepartment, .lotFile, .presidentialLibrary, .otherInstitution,
    ]

    /// Repository keywords that name a presidential library but do not end in `" Library"`.
    ///
    /// One entry, and it is not an edge case: `Nixon` is how the corpus cites the Nixon
    /// presidential materials, and it carries `NSC Files` — 7,056 documents, the second-largest
    /// collection in the series. Dropping it would put the single biggest bar of the 1969–1976
    /// era in the wrong colour.
    private static let presidentialRepositories: Set<String> = ["Nixon"]

    /// The bucket for one authority record.
    ///
    /// Presidential custody is tested first because it is a statement about *who holds the
    /// paper*, which outranks the filing system it was once part of.
    static func from(_ record: AuthorityCollectionRecord) -> ArchivalRepositoryCategory {
        if let repository = record.repository,
           repository.hasSuffix(" Library") || presidentialRepositories.contains(repository) {
            return .presidentialLibrary
        }
        if record.lotFileNorm != nil { return .lotFile }
        if record.repository == "Department of State" { return .stateDepartment }
        return .otherInstitution
    }

    /// Legend and axis label.
    var displayName: String {
        switch self {
        case .stateDepartment:
            return String(localized: "archival.category.stateDepartment",
                          defaultValue: "Department of State")
        case .lotFile:
            return String(localized: "archival.category.lotFile", defaultValue: "State lot files")
        case .presidentialLibrary:
            return String(localized: "archival.category.presidentialLibrary",
                          defaultValue: "Presidential libraries")
        case .otherInstitution:
            return String(localized: "archival.category.otherInstitution",
                          defaultValue: "Other institutions")
        }
    }

    /// The design's four sector tints.
    var color: Color {
        switch self {
        case .stateDepartment: return .blue
        case .lotFile: return .teal
        case .presidentialLibrary: return .purple
        case .otherInstitution: return .orange
        }
    }
}

// MARK: - ArchivalEraBand

/// A span of coverage years the Collections mode ranks within — a **rollup of contiguous
/// ``CollectionRelations/coverageEras`` buckets**, never a second set of boundaries.
///
/// The app has one era axis on purpose. #762's collection timeline draws the 19 `coverageEras`
/// buckets; ranking within all 19 would give bands of a dozen volumes, so these five group
/// them. Because each band is stored as a *range of era indices* rather than a pair of years,
/// its own start and end years are read back off the eras it contains and the two surfaces
/// cannot drift apart. ``ArchivalEraBandTests`` pins that the five ranges tile the axis exactly
/// once, with no gap and no overlap.
///
/// ## Why five, and why not the mock's four
/// The approved mock's Card-1 segmented control names 1946–60 / 1961–68 / 1969–76 / 1977–88.
/// Three of those four are exact unions of existing eras; `1946` is not — the axis runs
/// `1941–1947` as one war-years bucket, so a band starting in 1946 would have to split it.
/// More importantly, the four bands leave out everything before 1946, which is **261 of the
/// 552 volumes**. Those volumes are nearly absent from the named-collection lens (131
/// collections reached, the largest supplying 1,063 documents) and dominant in the class lens
/// (`793.94` alone supplies 4,956). That asymmetry is the thing the mock's own "unit-switch
/// pointer" footnote is about, so the band exists and the footnote points at it.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
struct ArchivalEraBand: Identifiable, Sendable, Equatable, Hashable {

    /// Position in ``all``; also `id`.
    let index: Int
    /// Indices into ``CollectionRelations/coverageEras``, contiguous and ascending.
    let eraIndices: ClosedRange<Int>

    var id: Int { index }

    /// The band's first coverage year, read off its first era.
    var startYear: Int { CollectionRelations.coverageEras[eraIndices.lowerBound].startYear }
    /// The band's last coverage year, read off its last era.
    var endYear: Int { CollectionRelations.coverageEras[eraIndices.upperBound].endYear }

    /// Segment label — `1961–1968`, or `Through 1947` for the open-ended first band.
    ///
    /// The first band opens at 1861 only because that is where the *series* opens; writing
    /// `1861–1947` on a segment would imply an evenly covered span, when in fact it holds four
    /// nineteenth-century decades of retrospective compilations alongside the war years.
    var title: String {
        if index == 0 {
            return String(format: String(localized: "archival.band.through %lld",
                                         defaultValue: "Through %lld"), Int64(endYear))
        }
        return "\(startYear)–\(endYear)"
    }

    /// Whether a coverage midpoint falls inside this band.
    func contains(midpointYear: Int) -> Bool {
        eraIndices.contains(CollectionRelations.eraIndex(forMidpointYear: midpointYear))
    }

    /// The five bands, earliest first.
    ///
    /// Volume counts over the shipped manifest: 261 / 120 / 64 / 66 / 41.
    static let all: [ArchivalEraBand] = [
        ArchivalEraBand(index: 0, eraIndices: 0...8),    // 1861–1947
        ArchivalEraBand(index: 1, eraIndices: 9...12),   // 1948–1960
        ArchivalEraBand(index: 2, eraIndices: 13...14),  // 1961–1968
        ArchivalEraBand(index: 3, eraIndices: 15...15),  // 1969–1976
        ArchivalEraBand(index: 4, eraIndices: 16...18),  // 1977–1992
    ]

    /// The band a coverage midpoint belongs to.
    ///
    /// Never `nil`: ``CollectionRelations/eraIndex(forMidpointYear:)`` is clamped at both ends
    /// and ``all`` tiles the whole era axis, so every year resolves. The band that ends up
    /// holding an out-of-range year is the clamped one, which is what the timeline does too.
    static func band(forMidpointYear year: Int) -> ArchivalEraBand {
        let era = CollectionRelations.eraIndex(forMidpointYear: year)
        return all.first { $0.eraIndices.contains(era) } ?? all[all.count - 1]
    }
}

// MARK: - ArchivalUnitLens

/// Which kind of archival unit the Collections mode ranks — the design's "Units" chip.
///
/// The two are different kinds of thing and are never mixed in one ranking (feasibility §4-I
/// rider b): a named collection is a body of records with a custodian, a central-file class is
/// a subject heading inside one filing system. Switching the lens replaces the chart.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
enum ArchivalUnitLens: String, CaseIterable, Identifiable, Sendable {
    /// Authority collections — the 4,423-record cross-volume clustering.
    case namedCollections
    /// Central-file class keys: decimal classes (`763.72`) and the 1963–1973 subject-numeric
    /// designators (`POL 27 VIET S`) the same grammar produces.
    case centralFileClasses

    var id: String { rawValue }

    /// Menu label.
    var title: String {
        switch self {
        case .namedCollections:
            return String(localized: "archival.lens.namedCollections",
                          defaultValue: "Named collections")
        case .centralFileClasses:
            return String(localized: "archival.lens.centralFileClasses",
                          defaultValue: "Central-file classes")
        }
    }
}

// MARK: - ArchivalWeight

/// How a ranking counts — the design's Documents | Volumes segmented control.
///
/// The two produce genuinely different lists and both are correct: `lot:54D270` supplies 1,063
/// documents from 5 volumes, `lot:63D351` supplies 624 from 98. Volumes measures how widely
/// the editors drew on a collection; documents measures how deeply.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
enum ArchivalWeight: String, CaseIterable, Identifiable, Sendable {
    /// Documents drawn from the unit — needs `collection-usage-index.json`.
    case documents
    /// Distinct volumes citing the unit.
    case volumes

    var id: String { rawValue }

    /// Segment label.
    var title: String {
        switch self {
        case .documents:
            return String(localized: "archival.weight.documents", defaultValue: "Documents")
        case .volumes:
            return String(localized: "archival.weight.volumes", defaultValue: "Volumes")
        }
    }
}
