// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivesClassAxis

/// The Archives axis's third lens: the central-file classes, divided by FILING ERA (#1255).
///
/// ## Why an era division rather than one flat list
/// A class key does not mean one thing. The Department renumbered the decimal file in 1950 —
/// class 7 is *Political Relations of States* before and *Internal Political and National Defense
/// Affairs* after, and Iran moves from 91 to 88 — and replaced it outright with the
/// subject-numeric system in 1963, whose own 1965 edition renumbers again: `POL 24` is
/// *SUBVERSION. ESPIONAGE.* under the 1963 arrangement and *SANCTIONS* under the one effective
/// January 1964.
///
/// A single list of class keys would therefore have to pick one reading per key and be wrong for
/// the other era, or print none and be a list of numbers. Dividing by era is not a convenience:
/// it is the only arrangement in which every row can carry a true reading, and it puts the same
/// designator in two sections saying two different things, which is the fact a reader most needs.
///
/// ## The eras are the schedules', not a second opinion
/// They are read from the two bundled label tables' own coverage blocks, so a schedule added or
/// respanned there moves this lens with it and cannot disagree with the glosses beneath.
///
/// Version history:
///   1.0 — #1255: initial implementation
///   1.1 — 2026-09-10: `rows(inEra:)` uncapped, so the lens's sort controls order the whole era
enum ArchivesClassAxis {

    // MARK: Types

    /// Which filing system an era belongs to.
    enum FilingSystem: String, Sendable {
        case decimal, subjectNumeric
    }

    /// One filing era: a schedule's span, and the system it belongs to.
    struct FilingEra: Identifiable, Sendable, Equatable {
        /// Stable identity, e.g. `"decimal:1910-1949"`.
        let id: String
        /// The schedule's own id.
        let scheduleId: String
        /// Which filing system.
        let system: FilingSystem
        /// First and last year the schedule governs.
        let span: ClosedRange<Int>

        /// Section heading — `Decimal file · 1910–1949`.
        var title: String {
            let years = "\(span.lowerBound)–\(span.upperBound)"
            switch system {
            case .decimal:
                return String(format: String(localized: "browser.archives.era.decimal %@",
                                             defaultValue: "Decimal file · %@"), years)
            case .subjectNumeric:
                return String(format: String(localized: "browser.archives.era.subjectNumeric %@",
                                             defaultValue: "Subject-numeric file · %@"), years)
            }
        }
    }

    /// One class within an era.
    struct ClassRow: Identifiable, Sendable, Equatable {
        /// The class key as source notes write it.
        let key: String
        /// Its reading under THIS era's schedule, or `nil` when that schedule cannot say.
        let gloss: String?
        /// The other places this key's country code also names under THIS era's schedule (#1257).
        let glossAlternates: [String]
        /// Documents this class supplies from volumes in the era.
        let documents: Int
        /// The citing volumes, heaviest first — the drill's members.
        let volumeIds: [String]

        var id: String { key }
    }

    // MARK: Eras

    /// The filing eras, earliest first, from the bundled schedules' own spans.
    ///
    /// - Returns: The eras, or an empty list when neither label table is bundled — in which case
    ///   the lens has nothing true to say and the caller withholds it.
    static func eras() -> [FilingEra] {
        var out: [FilingEra] = []
        for schedule in DecimalClassLabelStore.shared?.schedules ?? [] {
            out.append(FilingEra(id: "decimal:\(schedule.id)", scheduleId: schedule.id,
                                 system: .decimal,
                                 span: schedule.startYear...schedule.endYear))
        }
        for schedule in SubjectNumericLabelStore.shared?.schedules ?? [] {
            out.append(FilingEra(id: "subject:\(schedule.id)", scheduleId: schedule.id,
                                 system: .subjectNumeric,
                                 span: schedule.startYear...schedule.endYear))
        }
        return out.sorted {
            $0.span.lowerBound == $1.span.lowerBound
                ? $0.span.upperBound < $1.span.upperBound
                : $0.span.lowerBound < $1.span.lowerBound
        }
    }

    /// The volumes an era speaks for.
    ///
    /// A volume belongs to the era whose schedule governs its coverage span — the SAME test the
    /// glosses are chosen by, so a row can never appear under an era whose schedule would refuse
    /// to read it. A volume straddling two schedules belongs to neither and is counted as
    /// unplaced rather than assigned to the nearer one; the caption says how many.
    ///
    /// - Parameters:
    ///   - era: The era.
    ///   - coverage: Volume coverage spans.
    /// - Returns: The member volume ids.
    static func volumes(inEra era: FilingEra,
                        coverage: [String: ArchivalVolumeCoverage]) -> Set<String> {
        var out: Set<String> = []
        for (volumeId, span) in coverage where governs(era, span.firstYear...span.lastYear) {
            out.insert(volumeId)
        }
        return out
    }

    /// Whether an era's schedule governs a coverage span.
    ///
    /// Mirrors the label stores' own `governs`, clamp included: a volume opening before its
    /// filing system existed is still governed by the first schedule, because it holds no keys
    /// from before then to mislabel.
    ///
    /// - Parameters:
    ///   - era: The era.
    ///   - span: A volume's coverage years.
    /// - Returns: Whether the era speaks for the span.
    static func governs(_ era: FilingEra, _ span: ClosedRange<Int>) -> Bool {
        let floor = era.system == .decimal ? decimalFloor : subjectNumericFloor
        guard span.upperBound >= floor else { return false }
        return max(span.lowerBound, floor) >= era.span.lowerBound
            && span.upperBound <= era.span.upperBound
    }

    /// The year the decimal file opens, from its own coverage block.
    static var decimalFloor: Int {
        DecimalClassLabelStore.shared?.schedules.map(\.startYear).min() ?? 1910
    }

    /// The year the subject-numeric file opens, from its own coverage block.
    static var subjectNumericFloor: Int {
        SubjectNumericLabelStore.shared?.coverage.systemOpensIn ?? 1963
    }

    // MARK: Rows

    /// Every class an era carries, heaviest first.
    ///
    /// **Uncapped since the sort controls.** This took a `limit` of 200, which bound in EVERY era
    /// — measured over the shipped corpus the eras carry 6,118 / 1,922 / 548 / 249 / 1,071 classes,
    /// so the lens showed 1,000 of 9,908 rows — and the screen never said so. That was a silent
    /// truncation while the list was heaviest-first; once a reader can reorder it, it becomes a
    /// wrong answer: "fewest documents first" would have shown the 200 heaviest classes reversed,
    /// and class-number order would have filed those same 200 — a list that reads as the 1910–49
    /// file and omits 5,918 of its classes. Lifting it costs nothing to
    /// BUILD — the sweep below always constructed every row and the cap only discarded 8,908 of
    /// them afterwards (0.10 s for all five eras on the simulator) — only more rows to render, and
    /// `List` renders lazily.
    ///
    /// Only keys of the era's OWN filing system are admitted. The two vocabularies live in one
    /// column of the usage index and are told apart by `CollectionKeying.isSubjectNumericClass` —
    /// without the test a decimal number would list under a subject-numeric era, where no schedule
    /// can read it, and the section would fill with unglossed rows that look like a failure of the
    /// labels rather than a category error.
    ///
    /// - Parameters:
    ///   - era: The era.
    ///   - usage: The bundled usage index.
    ///   - coverage: Volume coverage spans.
    /// - Returns: The rows.
    static func rows(inEra era: FilingEra, usage: CollectionUsageIndex,
                     coverage: [String: ArchivalVolumeCoverage]) -> [ClassRow] {
        let members = volumes(inEra: era, coverage: coverage)
        guard !members.isEmpty else { return [] }
        var out: [ClassRow] = []
        for key in usage.classKeys {
            guard CollectionKeying.isSubjectNumericClass(key)
                == (era.system == .subjectNumeric) else { continue }
            let byVolume = usage.documentsByVolume(forClassKey: key)
                .filter { members.contains($0.key) }
            guard !byVolume.isEmpty else { continue }
            let documents = byVolume.values.reduce(0, +)
            guard documents > 0 else { continue }
            let ordered = byVolume.sorted {
                $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
            }
            out.append(ClassRow(key: key, gloss: gloss(for: key, era: era),
                                glossAlternates: alternates(for: key, era: era),
                                documents: documents, volumeIds: ordered.map(\.key)))
        }
        // Heaviest first, then by key: a total order, so the list is the same on every launch.
        out.sort { $0.documents == $1.documents ? $0.key < $1.key : $0.documents > $1.documents }
        return out
    }

    /// A key's reading under one era's schedule.
    ///
    /// Asked with the ERA'S OWN SPAN rather than the citing volumes' — the point of the division
    /// is that the reader is looking at this era, so the answer must be this era's schedule's,
    /// and asking with its span is what guarantees that schedule is the one that governs.
    ///
    /// - Parameters:
    ///   - key: A class key.
    ///   - era: The era.
    /// - Returns: The reading, or `nil`.
    static func gloss(for key: String, era: FilingEra) -> String? {
        switch era.system {
        case .decimal:
            return DecimalClassLabelStore.shared?.gloss(for: key, coveringYears: era.span)
        case .subjectNumeric:
            return SubjectNumericLabelStore.shared?.leafGloss(for: key, coveringYears: era.span)
        }
    }

    /// The other places a key's country code names, under this era's schedule.
    ///
    /// Asked with the ERA'S OWN SPAN for the same reason the gloss is: the reader is looking at
    /// this era, so the list must be this era's schedule's. Decimal only — the subject-numeric
    /// table refuses an ambiguous country reading outright, so a key that glosses there has one
    /// answer by construction.
    ///
    /// - Parameters:
    ///   - key: A class key.
    ///   - era: The era.
    /// - Returns: The other names, or empty.
    static func alternates(for key: String, era: FilingEra) -> [String] {
        guard era.system == .decimal else { return [] }
        return DecimalClassLabelStore.shared?.alternates(for: key, coveringYears: era.span) ?? []
    }

    // MARK: Drill

    /// The volume list behind one class row.
    ///
    /// - Parameters:
    ///   - row: The row.
    ///   - era: The era it was listed under.
    ///   - usage: The bundled usage index, for the per-volume share denominator.
    /// - Returns: The drill spec.
    static func spec(for row: ClassRow, era: FilingEra,
                     usage: CollectionUsageIndex) -> VolumeListSpec {
        let byVolume = usage.documentsByVolume(forClassKey: row.key)
        var accessories: [String: String] = [:]
        for volumeId in row.volumeIds {
            let documents = byVolume[volumeId] ?? 0
            if let notes = usage.noteCount(forVolumeId: volumeId), notes > 0 {
                let share = Int((Double(documents) / Double(notes) * 100).rounded())
                accessories[volumeId] = String(localized: "browser.archives.accessory",
                                               defaultValue: "\(documents) docs · \(share)%")
            } else {
                accessories[volumeId] = String(localized: "browser.archives.accessory.plain",
                                               defaultValue: "\(documents) docs")
            }
        }
        let title = row.gloss.map { "\(row.key) — \($0)" } ?? row.key
        return VolumeListSpec(
            axisKey: "class:\(era.id):\(row.key)",
            title: title,
            volumeIds: row.volumeIds,
            caption: String(format: String(localized: "browser.archives.class.caption %@ %@",
                                           defaultValue: """
                                               Volumes citing %1$@ whose coverage falls inside \
                                               %2$@. Counted from document source notes.
                                               """),
                            row.key, era.title),
            accessories: accessories)
    }
}
