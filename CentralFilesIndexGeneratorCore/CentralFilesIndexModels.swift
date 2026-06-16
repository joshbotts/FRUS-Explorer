// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CentralFilesIndex

/// The bundled index that maps FRUS archival citations to digitized NARA Catalog
/// rolls, shipped in the app bundle as `central-files-index.json`.
///
/// Because the index is bundled and every resolved link is a static
/// `catalog.archives.gov/id/<naId>` URL, the runtime feature requires no NARA API key.
///
/// Phase 1 (this version) populates only `numericalFile` (the 1906–1910 Numerical
/// File, microfilm M862). Later phases add the country-arranged diplomatic and consular
/// series; their container will be added alongside `numericalFile` without breaking the
/// Phase 1 shape, hence the explicit `schemaVersion`.
///
/// See `Planning/BigPicture-Pre1910-CentralFiles.md` for the full design.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 1 — Numerical File only
public struct CentralFilesIndex: Codable, Sendable, Equatable {

    /// Index schema version. Bumped when the JSON shape changes so the app can refuse
    /// to load an index it does not understand.
    public var schemaVersion: Int

    /// ISO-8601 date (`yyyy-MM-dd`) the index was generated. Informational.
    public var generated: String

    /// The 1906–1910 Numerical File component (Phase 1).
    public var numericalFile: NumericalFileIndex

    /// The country-arranged diplomatic series (Phase 2). Optional so a Phase 1-only index
    /// still decodes.
    public var countrySeries: [CountrySeriesIndex]

    /// Pre-resolved State Department lot files (Phase 3): normalized lot number → NARA
    /// Catalog series record, so the app links a later-volume lot citation with no API call.
    public var lotFiles: [LotFileEntry]

    /// The current schema version emitted by this generator. Bumped to 3 with Phase 3.
    public static let currentSchemaVersion = 3

    public init(
        schemaVersion: Int = CentralFilesIndex.currentSchemaVersion,
        generated: String,
        numericalFile: NumericalFileIndex,
        countrySeries: [CountrySeriesIndex] = [],
        lotFiles: [LotFileEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.numericalFile = numericalFile
        self.countrySeries = countrySeries
        self.lotFiles = lotFiles
    }

    /// Returns the resolved lot-file entry for a normalized lot number (`63D135`), if any.
    public func lotFile(normalized: String) -> LotFileEntry? {
        lotFiles.first { $0.lotNumber == normalized }
    }
}

// MARK: - LotFileEntry

/// A State Department lot file resolved to its NARA Catalog series record.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 3
public struct LotFileEntry: Codable, Sendable, Equatable {
    /// Normalized (compact, upper-cased) lot number, e.g. `63D135`.
    public var lotNumber: String
    /// Record group: `59` (D-designator) or `84` (F-designator).
    public var recordGroup: String
    /// NARA NAID of the resolved series record.
    public var naId: String
    /// Series title from the catalog.
    public var title: String
    /// Deep link to the NARA Catalog record.
    public var catalogURL: String

    public init(lotNumber: String, recordGroup: String, naId: String, title: String, catalogURL: String) {
        self.lotNumber = lotNumber
        self.recordGroup = recordGroup
        self.naId = naId
        self.title = title
        self.catalogURL = catalogURL
    }
}

// MARK: - CountrySeriesIndex

/// One country-arranged diplomatic series, flattened to a single list of rolls regardless
/// of whether the source hierarchy resolved country at the file-unit or roll-title level.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2
public struct CountrySeriesIndex: Codable, Sendable, Equatable {
    /// Category key (e.g. `diplomaticDespatches`).
    public var category: String
    /// NARA series NAID.
    public var seriesNaId: String
    /// Human-readable series name.
    public var displayName: String
    /// All resolution rolls, ascending by `startISO` (nils last).
    public var rolls: [CountryRoll]

    public init(category: String, seriesNaId: String, displayName: String, rolls: [CountryRoll]) {
        self.category = category
        self.seriesNaId = seriesNaId
        self.displayName = displayName
        self.rolls = rolls.sorted { ($0.startISO ?? "9999") < ($1.startISO ?? "9999") }
    }
}

// MARK: - CountryRoll

/// One page-by-page resolution target in a country-arranged series, with the canonical
/// country key(s) it serves and its inclusive date range.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2
public struct CountryRoll: Codable, Sendable, Equatable {
    /// NARA NAID of the resolution record (item or file unit, per series).
    public var naId: String
    /// Title exactly as shown in the catalog.
    public var title: String
    /// Canonical country/place keys this roll serves (≥1; combined rolls have several).
    public var geoKeys: [String]
    /// Inclusive start date, `yyyy-MM-dd`, when parseable.
    public var startISO: String?
    /// Inclusive end date, `yyyy-MM-dd`, when parseable.
    public var endISO: String?
    /// Deep link to the NARA Catalog record (page-by-page viewer).
    public var catalogURL: String
    /// Parent file-unit NAID, when the roll resolved from an item under a file unit.
    public var fileUnitNaId: String?
    /// Parent file-unit title (the country grouping), when present.
    public var fileUnitTitle: String?

    public init(
        naId: String, title: String, geoKeys: [String],
        startISO: String?, endISO: String?, catalogURL: String,
        fileUnitNaId: String? = nil, fileUnitTitle: String? = nil
    ) {
        self.naId = naId
        self.title = title
        self.geoKeys = geoKeys
        self.startISO = startISO
        self.endISO = endISO
        self.catalogURL = catalogURL
        self.fileUnitNaId = fileUnitNaId
        self.fileUnitTitle = fileUnitTitle
    }

    /// Returns `true` when `geoKey` is served and `dateISO` falls within the roll's range.
    ///
    /// A `nil` query date matches any roll for the country. With a query date, a roll must
    /// carry at least one date bound — a roll whose title yielded no date at all (garbled
    /// OCR) is excluded from date-filtered results rather than matching everything.
    public func matches(geoKey: String, dateISO: String?) -> Bool {
        guard geoKeys.contains(geoKey) else { return false }
        guard let dateISO else { return true }
        guard startISO != nil || endISO != nil else { return false }
        if let start = startISO, dateISO < start { return false }
        if let end = endISO, dateISO > end { return false }
        return true
    }
}

public extension CountrySeriesIndex {
    /// Returns rolls serving `geoKey` that contain `dateISO` (or all for the country when
    /// `dateISO` is nil), ascending by start date.
    func rolls(geoKey: String, dateISO: String?) -> [CountryRoll] {
        rolls.filter { $0.matches(geoKey: geoKey, dateISO: dateISO) }
    }
}

public extension CentralFilesIndex {
    /// Returns the country series for `category`, if present.
    func series(category: String) -> CountrySeriesIndex? {
        countrySeries.first { $0.category == category }
    }
}

// MARK: - NumericalFileIndex

/// The digitized 1906–1910 Numerical File (State Dept. central files), microfilm M862.
///
/// The Numerical File is a flat, two-level hierarchy in the NARA Catalog: the series
/// (NAID 654171) holds rolls described as items, each titled `Numerical File: <start>-<end>`
/// where the range is the inclusive span of *case numbers* on that roll. A FRUS "File No."
/// citation (e.g. `7187` or `697/43`) is resolved by the integer case number alone —
/// the `/NN` suffix is a within-case document number and does not affect roll selection.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
public struct NumericalFileIndex: Codable, Sendable, Equatable {

    /// NARA series NAID for the Numerical File (`654171`).
    public var seriesNaId: String

    /// Microfilm publication number (`M862`). Display metadata only.
    public var microfilm: String

    /// All digitized rolls, sorted ascending by `caseStart` for deterministic output
    /// and binary-search-friendly lookup.
    public var rolls: [NumericalFileRoll]

    public init(seriesNaId: String, microfilm: String, rolls: [NumericalFileRoll]) {
        self.seriesNaId = seriesNaId
        self.microfilm = microfilm
        self.rolls = rolls.sorted { $0.caseStart < $1.caseStart }
    }
}

// MARK: - NumericalFileRoll

/// One digitized roll of the Numerical File, covering an inclusive case-number range.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
public struct NumericalFileRoll: Codable, Sendable, Equatable {

    /// NARA item NAID for this roll (e.g. `19779414`).
    public var naId: String

    /// Roll title exactly as shown in the catalog (e.g. `Numerical File: 7179-7187`).
    public var title: String

    /// First (lowest) case number on the roll, inclusive.
    public var caseStart: Int

    /// Last (highest) case number on the roll, inclusive.
    public var caseEnd: Int

    /// Deep link to the roll's NARA Catalog record (page-by-page image/PDF viewer).
    public var catalogURL: String

    public init(naId: String, title: String, caseStart: Int, caseEnd: Int, catalogURL: String) {
        self.naId = naId
        self.title = title
        self.caseStart = caseStart
        self.caseEnd = caseEnd
        self.catalogURL = catalogURL
    }

    /// Returns `true` when `caseNumber` falls within `[caseStart, caseEnd]` inclusive.
    public func contains(caseNumber: Int) -> Bool {
        caseNumber >= caseStart && caseNumber <= caseEnd
    }
}

// MARK: - Lookup

public extension NumericalFileIndex {

    /// Returns the first roll whose case-number range contains `caseNumber`, or `nil`.
    ///
    /// A single case is frequently split across two or three consecutive rolls (when its
    /// sub-documents overflow a roll), so ranges legitimately share boundary cases. This
    /// returns the lowest-`caseStart` roll containing the number; use
    /// `rolls(containingCaseNumber:)` to get every roll holding the case. `nil` means the
    /// number falls in a coverage gap.
    func roll(forCaseNumber caseNumber: Int) -> NumericalFileRoll? {
        rolls.first { $0.contains(caseNumber: caseNumber) }
    }

    /// Returns every roll whose case-number range contains `caseNumber`, ascending.
    ///
    /// Because a case's documents can span multiple rolls, the app should surface all of
    /// these as page-by-page targets rather than only the first.
    func rolls(containingCaseNumber caseNumber: Int) -> [NumericalFileRoll] {
        rolls.filter { $0.contains(caseNumber: caseNumber) }
    }

    /// Returns the roll for a FRUS-style "File No." string, parsing the leading integer
    /// case number and ignoring any `/NN` sub-document suffix and trailing punctuation.
    ///
    /// Examples: `"7187"` → 7187; `"697/43"` → 697; `"File No. 17529."` → 17529.
    /// Returns `nil` when no case number can be parsed or it falls in a coverage gap.
    func roll(forFileNumber fileNumber: String) -> NumericalFileRoll? {
        guard let caseNumber = NumericalFileIndex.caseNumber(fromFileNumber: fileNumber) else {
            return nil
        }
        return roll(forCaseNumber: caseNumber)
    }

    /// Extracts the integer case number from a FRUS "File No." citation.
    ///
    /// Strips a leading `File No.`/`File`/`No.` label, then takes the first run of
    /// digits (the case number); the `/NN` sub-document suffix is intentionally dropped.
    static func caseNumber(fromFileNumber fileNumber: String) -> Int? {
        let scalars = fileNumber.unicodeScalars
        var digits = ""
        var seenDigit = false
        for scalar in scalars {
            if scalar.properties.numericType == .decimal || ("0"..."9").contains(scalar) {
                digits.unicodeScalars.append(scalar)
                seenDigit = true
            } else if seenDigit {
                // Stop at the first non-digit after the leading integer (e.g. the "/" in 697/43).
                break
            }
            // Skip leading non-digits (the "File No." label).
        }
        return Int(digits)
    }
}
