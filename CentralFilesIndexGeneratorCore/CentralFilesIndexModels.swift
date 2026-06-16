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

    /// The current schema version emitted by this generator.
    public static let currentSchemaVersion = 1

    public init(
        schemaVersion: Int = CentralFilesIndex.currentSchemaVersion,
        generated: String,
        numericalFile: NumericalFileIndex
    ) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.numericalFile = numericalFile
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

    /// Returns the roll whose case-number range contains `caseNumber`, or `nil`.
    ///
    /// Case ranges are expected to be contiguous and non-overlapping; if ranges do
    /// overlap, the roll with the lowest `caseStart` that contains the number wins
    /// (rolls are sorted ascending). `nil` means the number falls in a coverage gap.
    func roll(forCaseNumber caseNumber: Int) -> NumericalFileRoll? {
        rolls.first { $0.contains(caseNumber: caseNumber) }
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
