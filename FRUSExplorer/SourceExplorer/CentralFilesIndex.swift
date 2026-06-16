// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CentralFilesIndex

/// The bundled index mapping pre-1910 archival citations to digitized NARA Catalog
/// rolls, loaded from `central-files-index.json` in the app bundle.
///
/// This is the app-side mirror of the model produced by the `CentralFilesIndexGenerator`
/// SPM tool (which lives in a separate package target the app cannot import). The JSON is
/// the contract between the two; the field names here must match the generated file.
///
/// Phase 1 carries only the 1906–1910 Numerical File (microfilm M862). Because the index
/// ships in the bundle and every roll link is a static `catalog.archives.gov/id/<naId>`
/// URL, resolving a citation to its roll requires **no NARA API key and no network**.
///
/// See `Planning/BigPicture-Pre1910-CentralFiles.md`.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 1 — Numerical File
struct CentralFilesIndex: Codable, Sendable, Equatable {

    /// Index schema version. Phase 1 emits `1`.
    var schemaVersion: Int

    /// ISO-8601 date (`yyyy-MM-dd`) the index was generated.
    var generated: String

    /// The 1906–1910 Numerical File component.
    var numericalFile: NumericalFileIndex

    // The generator defaults `schemaVersion`; tolerate its absence for forward safety.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        generated = try container.decodeIfPresent(String.self, forKey: .generated) ?? ""
        numericalFile = try container.decode(NumericalFileIndex.self, forKey: .numericalFile)
    }
}

// MARK: - NumericalFileIndex

/// The digitized 1906–1910 Numerical File (State Dept. central files), microfilm M862.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
struct NumericalFileIndex: Codable, Sendable, Equatable {

    /// NARA series NAID for the Numerical File (`654171`).
    var seriesNaId: String

    /// Microfilm publication number (`M862`).
    var microfilm: String

    /// All digitized rolls, ascending by `caseStart`.
    var rolls: [NumericalFileRoll]
}

// MARK: - NumericalFileRoll

/// One digitized roll of the Numerical File, covering an inclusive case-number range.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
struct NumericalFileRoll: Codable, Sendable, Equatable, Identifiable {

    /// NARA item NAID for this roll (e.g. `19779414`).
    var naId: String

    /// Roll title exactly as shown in the catalog (e.g. `Numerical File: 7179-7187`).
    var title: String

    /// First (lowest) case number on the roll, inclusive.
    var caseStart: Int

    /// Last (highest) case number on the roll, inclusive.
    var caseEnd: Int

    /// Deep link to the roll's NARA Catalog record (page-by-page image/PDF viewer).
    var catalogURL: String

    /// Stable identity for SwiftUI lists.
    var id: String { naId }

    /// Returns `true` when `caseNumber` falls within `[caseStart, caseEnd]` inclusive.
    func contains(caseNumber: Int) -> Bool {
        caseNumber >= caseStart && caseNumber <= caseEnd
    }
}

// MARK: - Lookup

extension NumericalFileIndex {

    /// Returns every roll whose case-number range contains `caseNumber`, ascending.
    ///
    /// A single case is frequently split across two or three consecutive rolls (when its
    /// sub-documents overflow a roll), so the UI should surface all matching rolls as
    /// page-by-page targets. Empty means the case falls in a coverage gap.
    func rolls(containingCaseNumber caseNumber: Int) -> [NumericalFileRoll] {
        rolls.filter { $0.contains(caseNumber: caseNumber) }
    }

    /// Returns every roll holding the case named by a FRUS-style "File No." string.
    ///
    /// Parses the leading integer case number and ignores any `/NN` sub-document suffix
    /// and trailing punctuation (`"697/43"` → case 697). Empty means no digit could be
    /// parsed or the case falls in a coverage gap.
    func rolls(forFileNumber fileNumber: String) -> [NumericalFileRoll] {
        guard let caseNumber = CentralFilesIndex.caseNumber(fromFileNumber: fileNumber) else {
            return []
        }
        return rolls(containingCaseNumber: caseNumber)
    }
}

extension CentralFilesIndex {

    /// Extracts the integer case number from a FRUS "File No." citation.
    ///
    /// Takes the first run of digits (the case number); a leading `File No.` label and a
    /// trailing `/NN` sub-document suffix are ignored. `"7187"` → 7187; `"697/43"` → 697;
    /// `"File No. 17529."` → 17529.
    static func caseNumber(fromFileNumber fileNumber: String) -> Int? {
        var digits = ""
        var seenDigit = false
        for character in fileNumber {
            if character.isNumber {
                digits.append(character)
                seenDigit = true
            } else if seenDigit {
                break
            }
        }
        return Int(digits)
    }
}

// MARK: - CentralFilesIndexStore

/// Loads and caches the bundled `central-files-index.json`.
///
/// The index is decoded once, lazily, on first access. `shared` is `nil` only when the
/// resource is missing or cannot be decoded (logged in DEBUG).
///
/// ## Static catalog links (no API key)
/// `numericalFileSeriesURL` and `cardIndexURL` are the fallbacks shown when a case falls
/// in a coverage gap or on the name/place-filed rolls that carry no case number.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
enum CentralFilesIndexStore {

    /// The bundled Central Files index, or `nil` if unavailable. Loaded once.
    static let shared: CentralFilesIndex? = load()

    /// NARA Catalog record for the Numerical File series (M862, NAID 654171).
    static let numericalFileSeriesURL = URL(string: "https://catalog.archives.gov/id/654171")!

    /// NARA Catalog record for the Card Index to the Numerical File (M1889, NAID 656824),
    /// the finding aid that resolves names/subjects to case numbers.
    static let cardIndexURL = URL(string: "https://catalog.archives.gov/id/656824")!

    private static func load() -> CentralFilesIndex? {
        guard let url = Bundle.main.url(forResource: "central-files-index", withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CentralFilesIndexStore: central-files-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CentralFilesIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CentralFilesIndexStore: failed to decode central-files-index.json — \(error)")
            #endif
            return nil
        }
    }
}
