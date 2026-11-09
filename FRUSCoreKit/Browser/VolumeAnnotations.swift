// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnnotationCategory

/// One layer of editorial annotation a FRUS volume may carry: people tagged, abbreviations
/// explained, source notes, classification markings, document numbers and the rest.
///
/// The categories, their thresholds and their eras are
/// `Planning/Editors-Annotations-Design-2026-11-06.md`'s (§2, §4). Each is a count of documents in
/// `volume-annotations-index.json`, which `VolumeAnnotationsIndexGenerator` writes through
/// ``VolumeAnnotationsIndex``. The kit decides what a count means, so a threshold can change
/// without regenerating the file.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
///   1.1 — 2026-11-08: ``editorialOmissions``, the sixteenth layer (Lane 1 of
///          `Planning/Editors-Annotations-Followups-2026-11-08.md`); each volume's
///          ``VolumeAnnotations/publicationYear`` and the 1925 gate; schema version 2
public enum AnnotationCategory: String, CaseIterable, Sendable {
    /// Documents that link a name to the volume's List of Persons: the People browser's rule.
    case people
    /// Documents that link a term to the volume's List of Abbreviations.
    case abbreviations
    /// Documents whose heading marks its sender or recipient (`@type="from"` or `"to"`).
    case correspondents
    /// Documents with a Subject line (`list[@type="subject"]`).
    case subjects
    /// Documents with a list of participants (`list[@type="participants"]`).
    case participants
    /// Documents whose source note is a footnote-style citation ("Source: …"), the form of the
    /// volumes from 1955 on and the retrospectives.
    case sourceCitation
    /// Documents whose source note is the file number printed above the heading
    /// (`note[@rend="inline"]`), the form of the volumes covering 1907–1954.
    case sourceFileNumber
    /// Documents for which the index stores a classification marking, the note's or the opener's.
    case classification
    /// Documents that mark an excision ("not declassified").
    case excisions
    /// Documents whose own text says, in brackets, what the editors left out: "[Here follows …]",
    /// "[Omitted here is …]", "[…, which has been omitted, …]". A bracket inside a footnote or a
    /// source note is not read, and one that says "not declassified" is a redaction
    /// (``excisions``), never an omission. The file counts every volume's; a volume carries the
    /// layer only from ``VolumeAnnotations/editorialOmissionsFromYear`` (``VolumeAnnotations/carries(_:)``).
    case editorialOmissions
    /// Documents with a pre-1906 despatch or instruction serial (#965).
    case despatch
    /// Documents whose stored heading opens with its printed number ("12. Telegram From …").
    case numbered
    /// Documents that cite another document of the volume (`ref target="#d…"`).
    case xrefDocuments
    /// Documents that cite a footnote (`ref target="#d…fn…"`).
    case xrefFootnotes
    /// Documents that cite another volume (`ref target="frus…"`).
    case xrefVolumes
    /// Documents that cite a printed page (`ref target="#pg_…"`).
    case xrefPages
    /// Editorial notes (`div[@type="document"][@subtype="editorial-note"]`).
    case editorialNotes
    /// Documents with a footnote that is not their source note.
    case footnotes
    /// Documents with a marginal note (`seg[@type="margin"]`).
    case marginalNotes
    /// Documents with a figure.
    case figures

    /// The three groups a volume's page shows the categories in.
    public enum Family: String, CaseIterable, Sendable {
        /// Who is named: people, abbreviations, correspondents, subjects, participants.
        case named
        /// Where it came from: source notes, classification, excisions, despatch numbers.
        case provenance
        /// How it connects: numbering, references, editorial notes, footnotes, marginal notes, figures.
        case connects
    }

    /// When a volume carries a category: by the share of its documents that do, or by any one.
    public enum Threshold: Sendable, Equatable {
        /// A pervasive layer: at least half the volume's documents carry it.
        case halfOfDocuments
        /// At least a tenth of the volume's documents carry it (despatch numbers).
        case tenthOfDocuments
        /// A counted layer: one document carrying it is enough.
        case anyDocument
    }

    /// The group the category is shown in.
    public var family: Family {
        switch self {
        case .people, .abbreviations, .correspondents, .subjects, .participants:
            return .named
        case .sourceCitation, .sourceFileNumber, .classification, .excisions, .editorialOmissions, .despatch:
            return .provenance
        case .numbered, .xrefDocuments, .xrefFootnotes, .xrefVolumes, .xrefPages,
             .editorialNotes, .footnotes, .marginalNotes, .figures:
            return .connects
        }
    }

    /// When a volume carries the category (the design's §2 bases).
    public var threshold: Threshold {
        switch self {
        case .people, .abbreviations, .correspondents, .sourceCitation, .sourceFileNumber,
             .classification, .numbered, .footnotes:
            return .halfOfDocuments
        case .despatch:
            return .tenthOfDocuments
        case .subjects, .participants, .excisions, .editorialOmissions, .xrefDocuments, .xrefFootnotes,
             .xrefVolumes, .xrefPages, .editorialNotes, .marginalNotes, .figures:
            return .anyDocument
        }
    }

    /// `true` for a category the series made standard, which a volume's page lists as absent when
    /// the volume lacks it (§5.2). An era-bound practice (senders and recipients, despatch numbers,
    /// marginal notes, page references) appears only when present. The two source-note forms are
    /// era-bound each; source notes as a whole are series-wide (``VolumeAnnotations/carriesSourceNotes``).
    public var isSeriesWide: Bool {
        switch self {
        case .people, .abbreviations, .classification, .numbered, .xrefDocuments, .editorialNotes:
            return true
        case .correspondents, .subjects, .participants, .sourceCitation, .sourceFileNumber,
             .excisions, .editorialOmissions, .despatch, .xrefFootnotes, .xrefVolumes, .xrefPages,
             .footnotes, .marginalNotes, .figures:
            return false
        }
    }
}

// MARK: - AnnotationEra

/// The era bands the design reads the corpus in (§2.2), keyed by the year a volume's subseries
/// begins, with the late retrospective volumes as a band of their own.
///
/// The manifest's earliest date is no use for this: it reaches back to enclosures centuries older
/// than the volume. The retrospectives sit at no single point in the series' chronology, so the
/// onset rule leaves them out (``VolumeAnnotationsIndex/onset(where:)``).
public enum AnnotationEra: String, CaseIterable, Sendable, Comparable {
    /// Subseries beginning 1861–1898.
    case from1861 = "1861-1898"
    /// Subseries beginning 1899–1913.
    case from1899 = "1899-1913"
    /// Subseries beginning 1914–1919.
    case from1914 = "1914-1919"
    /// Subseries beginning 1920–1931.
    case from1920 = "1920-1931"
    /// Subseries beginning 1932–1944.
    case from1932 = "1932-1944"
    /// Subseries beginning 1945–1950.
    case from1945 = "1945-1950"
    /// Subseries beginning 1951–1954.
    case from1951 = "1951-1954"
    /// Subseries beginning 1955–1968.
    case from1955 = "1955-1968"
    /// Subseries beginning 1969–1980.
    case from1969 = "1969-1980"
    /// Subseries beginning 1981 or later.
    case from1981 = "1981-"
    /// The late retrospective volumes, whose editors worked in the modern format whatever era
    /// they cover: Public Diplomacy, the two Intelligence volumes, Iran and its second edition,
    /// and Guatemala.
    case retrospective = "retrospective"

    /// The chronological bands, without ``retrospective``, in order.
    public static var chronological: [AnnotationEra] {
        allCases.filter { $0 != .retrospective }
    }

    /// The first year of the band, or `nil` for ``retrospective``.
    public var firstYear: Int? {
        switch self {
        case .from1861: return 1861
        case .from1899: return 1899
        case .from1914: return 1914
        case .from1920: return 1920
        case .from1932: return 1932
        case .from1945: return 1945
        case .from1951: return 1951
        case .from1955: return 1955
        case .from1969: return 1969
        case .from1981: return 1981
        case .retrospective: return nil
        }
    }

    /// The band a volume belongs to.
    ///
    /// - Parameters:
    ///   - subseriesStartYear: The first year of the volume's subseries (`manifest.json`'s
    ///     `subseries`, "1969-76" → 1969).
    ///   - volumeId: The volume's id, which decides whether it is a retrospective.
    /// - Returns: The band, or `nil` for a subseries beginning before 1861.
    public static func era(subseriesStartYear: Int, volumeId: String) -> AnnotationEra? {
        if isRetrospective(volumeId: volumeId) { return .retrospective }
        return chronological.last { ($0.firstYear ?? .max) <= subseriesStartYear }
    }

    /// `true` for one of the late retrospective volumes: Public Diplomacy (`frus1917-72PubDip…`),
    /// the Intelligence volumes (`…Intel`), Iran (`…Iran`, `…IranEd2`) and Guatemala (`…Guat`).
    public static func isRetrospective(volumeId: String) -> Bool {
        volumeId.contains("PubDip") || volumeId.hasSuffix("Intel") || volumeId.contains("Iran")
            || volumeId.hasSuffix("Guat")
    }

    /// Bands order chronologically, with ``retrospective`` last.
    public static func < (lhs: AnnotationEra, rhs: AnnotationEra) -> Bool {
        guard let left = allCases.firstIndex(of: lhs), let right = allCases.firstIndex(of: rhs) else {
            return false
        }
        return left < right
    }
}

// MARK: - VolumeAnnotations

/// What one volume carries: how many of its documents carry each category, the sizes of its two
/// lists, its era and the sections it prints.
///
/// "Documents" are the TEI's `<div type="document">` elements inside `<body>`, editorial notes
/// included; a section's own printed text is not one.
public struct VolumeAnnotations: Sendable, Equatable {
    /// The volume's documents, editorial notes included.
    public let documents: Int
    /// Its documents less its editorial notes.
    public let historicalDocuments: Int
    /// The entries of its List of Persons, as the index stores them.
    public let personsListed: Int
    /// The entries of its List of Abbreviations, as the index stores them.
    public let termsListed: Int
    /// The band of the series it belongs to.
    public let era: AnnotationEra
    /// How many documents carry each category; a category not here is carried by none.
    public let counts: [AnnotationCategory: Int]
    /// The kinds of the sections it prints, as the parser names them (`preface`, `sources`,
    /// `persons`, `terms`, `index`, …) plus `list-of-papers` for an analytical List of Papers.
    public let sections: [String]
    /// The year the volume was published, from its header's `date[@type="publication-date"]`;
    /// `nil` in a file of schema version 1, or for a header that prints none. A practice that
    /// changed with a volume's publication, not the years it covers, is gated on it.
    public let publicationYear: Int?

    /// The year from which a volume's bracketed omissions count, that of Secretary Kellogg's order
    /// on the series. Before it an omission was marked with a row of asterisks, which the bracket
    /// scan does not read; the brackets it finds in earlier volumes stand in for duplicate text,
    /// formalities and gaps in a telegram as received (`Planning/Editors-Annotations-Followups-2026-11-08.md`,
    /// Lane 1). The count is stored for every volume; the gate is the kit's, as every threshold is.
    public static let editorialOmissionsFromYear = 1925

    /// Creates a volume's annotations.
    public init(documents: Int, historicalDocuments: Int, personsListed: Int, termsListed: Int,
                era: AnnotationEra, counts: [AnnotationCategory: Int], sections: [String],
                publicationYear: Int? = nil) {
        self.documents = documents
        self.historicalDocuments = historicalDocuments
        self.personsListed = personsListed
        self.termsListed = termsListed
        self.era = era
        self.counts = counts.filter { $0.value != 0 }
        self.sections = Array(Set(sections)).sorted()
        self.publicationYear = publicationYear
    }

    /// `true` when the volume was published before ``editorialOmissionsFromYear``, so that its
    /// bracketed omissions, if any, are counted and not carried. `false` where the year is unknown.
    public var publishedBeforeEditorialOmissionsOrder: Bool {
        guard let publicationYear else { return false }
        return publicationYear < Self.editorialOmissionsFromYear
    }

    /// How many documents carry `category`.
    public func count(_ category: AnnotationCategory) -> Int {
        counts[category] ?? 0
    }

    /// `true` when the volume carries `category`, by the category's threshold; never
    /// ``AnnotationCategory/editorialOmissions`` for a volume published before
    /// ``editorialOmissionsFromYear``, whatever its count.
    public func carries(_ category: AnnotationCategory) -> Bool {
        if category == .editorialOmissions, publishedBeforeEditorialOmissionsOrder { return false }
        return Self.meets(category.threshold, count: count(category), of: documents)
    }

    /// Documents with a source note of either form.
    public var sourceNotes: Int {
        count(.sourceCitation) + count(.sourceFileNumber)
    }

    /// `true` when at least half the volume's documents have a source note of either form.
    public var carriesSourceNotes: Bool {
        Self.meets(.halfOfDocuments, count: sourceNotes, of: documents)
    }

    /// `true` when the volume prints a section of `kind`.
    public func prints(section kind: String) -> Bool {
        sections.contains(kind)
    }

    private static func meets(_ threshold: AnnotationCategory.Threshold, count: Int, of documents: Int) -> Bool {
        guard count > 0 else { return false }
        switch threshold {
        case .halfOfDocuments: return 2 * count >= documents
        case .tenthOfDocuments: return 10 * count >= documents
        case .anyDocument: return true
        }
    }
}

// MARK: - VolumeAnnotationsIndex

/// The bundled `volume-annotations-index.json`: every catalogue volume's ``VolumeAnnotations``.
///
/// Written by `VolumeAnnotationsIndexGenerator` through ``shippingData()`` and read by the app
/// through `Decodable`, so both go through this one declaration. The file is columnar: the count
/// names once (`fields`), each volume's counts as one array in that order, and its sections as
/// indices into one list of section kinds (`sections`). A reader maps counts by name, so a field
/// it does not know is ignored.
///
/// Schema version 2 (2026-11-08) adds each volume's publication year as the fourth element of its
/// row, after its sections; a row of three elements is schema version 1's, and reads with no year.
///
/// `indexVersion` is the index version whose rules counted the file: people, source notes,
/// classification, despatch numbers, numbering and sections are read from a full index the
/// generator builds through the kit's own pipeline, so the labels and the app agree.
public struct VolumeAnnotationsIndex: Sendable, Equatable {
    /// The file format this declaration writes: 2 since 2026-11-08, when each row gained the
    /// volume's publication year. The decoder reads 1 as well.
    public static let currentSchemaVersion = 2

    /// The share of an era's volumes that must carry a category for the era to count toward its
    /// onset (§4).
    public static let onsetShare = 0.75

    /// The file's format.
    public let schemaVersion: Int
    /// The day the file was generated (`yyyy-MM-dd`).
    public let generated: String
    /// The corpus commit the volumes were read at.
    public let corpusCommit: String
    /// The index version whose rules counted the file.
    public let indexVersion: Int
    /// Each volume's annotations, by volume id.
    public let volumes: [String: VolumeAnnotations]

    /// Creates an index.
    public init(schemaVersion: Int = VolumeAnnotationsIndex.currentSchemaVersion, generated: String,
                corpusCommit: String, indexVersion: Int, volumes: [String: VolumeAnnotations]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.corpusCommit = corpusCommit
        self.indexVersion = indexVersion
        self.volumes = volumes
    }

    /// The annotations of one volume, or `nil` for a volume the file does not hold.
    public subscript(volumeId: String) -> VolumeAnnotations? {
        volumes[volumeId]
    }

    /// The ids of the volumes `predicate` accepts, sorted.
    public func volumeIds(where predicate: (VolumeAnnotations) -> Bool) -> [String] {
        volumes.filter { predicate($0.value) }.keys.sorted()
    }

    /// The era from which the series made a practice standard: the first chronological band from
    /// which every later band has at least ``onsetShare`` of its volumes accepted by `carries`.
    /// The retrospectives are left out, and a band that holds no volume is passed over.
    ///
    /// - Returns: The band, or `nil` when the practice never became standard.
    public func onset(where carries: (VolumeAnnotations) -> Bool) -> AnnotationEra? {
        var share: [AnnotationEra: Double] = [:]
        for era in AnnotationEra.chronological {
            let members = volumes.values.filter { $0.era == era }
            guard !members.isEmpty else { continue }
            share[era] = Double(members.filter(carries).count) / Double(members.count)
        }
        let bands = AnnotationEra.chronological.filter { share[$0] != nil }
        for (position, band) in bands.enumerated()
        where bands[position...].allSatisfy({ (share[$0] ?? 0) >= Self.onsetShare }) {
            return band
        }
        return nil
    }

    /// The onset of `category` (``onset(where:)`` over ``VolumeAnnotations/carries(_:)``).
    public func onset(of category: AnnotationCategory) -> AnnotationEra? {
        onset { $0.carries(category) }
    }

    /// The file as it ships: compact JSON with sorted keys, so the same input writes the same bytes.
    public func shippingData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - Columnar coding

extension VolumeAnnotationsIndex: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, corpusCommit, indexVersion, fields, sections, volumes
    }

    /// The counts each volume's array holds, in order: the four sizes, then every category.
    static let fieldNames: [String] =
        ["documents", "historicalDocuments", "personsListed", "termsListed"]
        + AnnotationCategory.allCases.map(\.rawValue)

    /// A volume as the file holds it: its era, its counts in ``fieldNames`` order, its sections
    /// as indices into the file's `sections` and, since schema version 2, its publication year
    /// (`null` where the header prints none). A row of three elements is version 1's.
    private struct Row: Codable {
        let era: String
        let counts: [Int]
        let sections: [Int]
        let publicationYear: Int?

        init(era: String, counts: [Int], sections: [Int], publicationYear: Int?) {
            self.era = era
            self.counts = counts
            self.sections = sections
            self.publicationYear = publicationYear
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            era = try container.decode(String.self)
            counts = try container.decode([Int].self)
            sections = try container.decode([Int].self)
            publicationYear = container.isAtEnd ? nil : try container.decodeIfPresent(Int.self)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(era)
            try container.encode(counts)
            try container.encode(sections)
            if let publicationYear {
                try container.encode(publicationYear)
            } else {
                try container.encodeNil()
            }
        }
    }

    /// Reads the columnar file, mapping each count by its field name.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generated = try container.decode(String.self, forKey: .generated)
        corpusCommit = try container.decode(String.self, forKey: .corpusCommit)
        indexVersion = try container.decode(Int.self, forKey: .indexVersion)
        let fields = try container.decode([String].self, forKey: .fields)
        let sectionKinds = try container.decode([String].self, forKey: .sections)
        let rows = try container.decode([String: Row].self, forKey: .volumes)
        var volumes: [String: VolumeAnnotations] = [:]
        for (volumeId, row) in rows {
            guard let era = AnnotationEra(rawValue: row.era) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .volumes, in: container,
                    debugDescription: "\(volumeId): unknown era \(row.era)")
            }
            var value: [String: Int] = [:]
            for (field, count) in zip(fields, row.counts) { value[field] = count }
            var counts: [AnnotationCategory: Int] = [:]
            for category in AnnotationCategory.allCases {
                counts[category] = value[category.rawValue]
            }
            let sections = row.sections.compactMap { sectionKinds.indices.contains($0) ? sectionKinds[$0] : nil }
            volumes[volumeId] = VolumeAnnotations(
                documents: value["documents"] ?? 0,
                historicalDocuments: value["historicalDocuments"] ?? 0,
                personsListed: value["personsListed"] ?? 0,
                termsListed: value["termsListed"] ?? 0,
                era: era, counts: counts, sections: sections, publicationYear: row.publicationYear)
        }
        self.volumes = volumes
    }

    /// Writes the columnar file.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(generated, forKey: .generated)
        try container.encode(corpusCommit, forKey: .corpusCommit)
        try container.encode(indexVersion, forKey: .indexVersion)
        try container.encode(Self.fieldNames, forKey: .fields)
        let sectionKinds = Array(Set(volumes.values.flatMap(\.sections))).sorted()
        let position = Dictionary(uniqueKeysWithValues: sectionKinds.enumerated().map { ($1, $0) })
        try container.encode(sectionKinds, forKey: .sections)
        var rows: [String: Row] = [:]
        for (volumeId, annotations) in volumes {
            let counts = [annotations.documents, annotations.historicalDocuments,
                          annotations.personsListed, annotations.termsListed]
                + AnnotationCategory.allCases.map { annotations.count($0) }
            rows[volumeId] = Row(era: annotations.era.rawValue, counts: counts,
                                 sections: annotations.sections.compactMap { position[$0] },
                                 publicationYear: annotations.publicationYear)
        }
        try container.encode(rows, forKey: .volumes)
    }
}
