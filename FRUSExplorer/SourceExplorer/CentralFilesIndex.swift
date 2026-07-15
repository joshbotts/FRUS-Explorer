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

    /// The country-arranged diplomatic series (Phase 2). Empty for a Phase 1-only index.
    var countrySeries: [CountrySeriesIndex]

    /// Pre-resolved State Department lot files (Phase 3): normalized lot number → NARA
    /// Catalog series record. Empty for an index that predates Phase 3.
    var lotFiles: [LotFileEntry]

    // The generator defaults newer fields; tolerate their absence for forward safety.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        generated = try container.decodeIfPresent(String.self, forKey: .generated) ?? ""
        numericalFile = try container.decode(NumericalFileIndex.self, forKey: .numericalFile)
        countrySeries = try container.decodeIfPresent([CountrySeriesIndex].self, forKey: .countrySeries) ?? []
        lotFiles = try container.decodeIfPresent([LotFileEntry].self, forKey: .lotFiles) ?? []
    }

    /// Returns the country series for `category`, if present.
    func series(category: CentralFilesSeriesCategory) -> CountrySeriesIndex? {
        countrySeries.first { $0.category == category.rawValue }
    }

    /// Returns the pre-resolved lot file for a raw lot number from a source note, or `nil`.
    /// The raw form (`"63 D 135"`, `"61-D 146"`) is normalized to the bundle's compact key.
    func lotFile(forRawLot raw: String) -> LotFileEntry? {
        let key = CentralFilesIndex.normalizeLot(raw)
        return lotFiles.first { $0.lotNumber == key }
    }

    /// Compact upper-cased lot key (`61–D 146` → `61D146`), matching the generator's form.
    static func normalizeLot(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: "LOT ", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "—", with: "")
    }
}

// MARK: - LotFileEntry

/// A State Department lot file resolved to its NARA Catalog series record (bundled,
/// key-less). The bundle contains only exact control-number matches, so each is
/// high-confidence (`matchType` == `control`).
struct LotFileEntry: Codable, Sendable, Equatable {
    var lotNumber: String
    var recordGroup: String
    var naId: String
    var title: String
    var catalogURL: String
    var matchType: String
    /// The series' HMS/MLR Entry Number(s) — the identifier NARA staff ask researchers to
    /// quote when requesting the original records (#315). `nil` when the bundled index
    /// predates the enrichment pass **or** when the record genuinely carries none; both
    /// render the same way (nothing), so the UI need not distinguish them.
    var hmsMlrEntryNumbers: [String]?
    /// The resolved record's catalog level (`series`, `fileUnit`, …), when known (#315).
    ///
    /// Check this before presenting `title` as a *series* title: the resolver takes the first
    /// record-group match without requiring series level, so a minority of entries describe a
    /// file unit. `isSeriesLevel` is the intended read.
    var levelOfDescription: String?
    /// NAID of the enclosing file series, when this record is a file unit rather than a
    /// series (#315).
    var seriesNaId: String?
    /// Title of the enclosing file series, for records whose own `title` names a file unit.
    var seriesTitle: String?
    /// The **enclosing series'** HMS/MLR entry numbers — the parent's identifiers, not this
    /// record's.
    ///
    /// Deliberately separate from `hmsMlrEntryNumbers`: a series-level record's own entry
    /// number pinpoints the records being cited, whereas a parent series may carry many
    /// (the live "Central Decimal Files" series has 23), which narrows nothing for an
    /// archivist. Present these only with their imprecision made explicit — never merged
    /// into, or presented as, the record's own entry number.
    var seriesHmsMlrEntryNumbers: [String]?
    /// `true` when the resolved record's ancestry contains no record group — a candidate
    /// mis-resolution flagged by the enrichment pass for review (#315).
    var ancestryLacksRecordGroup: Bool?

    /// Whether the resolved record is described at the series level — i.e. whether `title`
    /// is itself the file series name (#315).
    ///
    /// `nil` level (an un-enriched bundle) reads as `false`: absent evidence, do not claim it.
    var isSeriesLevel: Bool { levelOfDescription == "series" }

    /// The **file series name** to display — the single accessor the UI should use, so the
    /// series/file-unit distinction cannot be got wrong at a call site (#315).
    ///
    /// A series-level record's own `title` is the series name. A file unit's is not — its
    /// series name is the enclosing series' title, resolved by the enrichment pass. `nil`
    /// when neither is known (an un-enriched bundle, or a record whose series never
    /// resolved), in which case no series should be named at all.
    var displaySeriesTitle: String? { isSeriesLevel ? title : seriesTitle }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lotNumber = try c.decode(String.self, forKey: .lotNumber)
        recordGroup = try c.decode(String.self, forKey: .recordGroup)
        naId = try c.decode(String.self, forKey: .naId)
        title = try c.decode(String.self, forKey: .title)
        catalogURL = try c.decode(String.self, forKey: .catalogURL)
        matchType = try c.decodeIfPresent(String.self, forKey: .matchType) ?? "control"
        // decodeIfPresent, so a bundle written before #315's enrichment still decodes.
        hmsMlrEntryNumbers = try c.decodeIfPresent([String].self, forKey: .hmsMlrEntryNumbers)
        levelOfDescription = try c.decodeIfPresent(String.self, forKey: .levelOfDescription)
        seriesNaId = try c.decodeIfPresent(String.self, forKey: .seriesNaId)
        seriesTitle = try c.decodeIfPresent(String.self, forKey: .seriesTitle)
        seriesHmsMlrEntryNumbers = try c.decodeIfPresent([String].self,
                                                         forKey: .seriesHmsMlrEntryNumbers)
        ancestryLacksRecordGroup = try c.decodeIfPresent(Bool.self,
                                                         forKey: .ancestryLacksRecordGroup)
    }
}

// MARK: - CentralFilesSeriesCategory

/// The country-arranged diplomatic series (Phase 2) plus the consular series (Phase 3),
/// mirroring the generator's categories.
enum CentralFilesSeriesCategory: String, Sendable, CaseIterable {
    case despatches = "diplomaticDespatches"
    case instructions = "diplomaticInstructions"
    case notesFrom = "notesFromForeignMissions"
    case notesTo = "notesToForeignMissions"
    case consularDespatches = "consularDespatches"

    /// Human-readable series name.
    var displayName: String {
        switch self {
        case .despatches:   return String(localized: "centralFiles.series.despatches",
                                          defaultValue: "Diplomatic Despatches")
        case .instructions: return String(localized: "centralFiles.series.instructions",
                                          defaultValue: "Diplomatic Instructions")
        case .notesFrom:    return String(localized: "centralFiles.series.notesFrom",
                                          defaultValue: "Notes from Foreign Missions")
        case .notesTo:      return String(localized: "centralFiles.series.notesTo",
                                          defaultValue: "Notes to Foreign Missions")
        case .consularDespatches: return String(localized: "centralFiles.series.consular",
                                          defaultValue: "Consular Despatches")
        }
    }
}

// MARK: - CountrySeriesIndex

/// One country-arranged diplomatic series, flattened to a single list of rolls.
struct CountrySeriesIndex: Codable, Sendable, Equatable {
    /// Category key (e.g. `diplomaticDespatches`).
    var category: String
    /// NARA series NAID.
    var seriesNaId: String
    /// Human-readable series name from the generator.
    var displayName: String
    /// All resolution rolls.
    var rolls: [CountryRoll]

    /// Returns rolls serving `geoKey` that contain `dateISO` (or all for the country when
    /// `dateISO` is nil), ascending by start date.
    func rolls(geoKey: String, dateISO: String?) -> [CountryRoll] {
        rolls.filter { $0.matches(geoKey: geoKey, dateISO: dateISO) }
    }
}

// MARK: - CountryRoll

/// One page-by-page resolution target in a country-arranged series.
struct CountryRoll: Codable, Sendable, Equatable, Identifiable {
    var naId: String
    var title: String
    var geoKeys: [String]
    var startISO: String?
    var endISO: String?
    var catalogURL: String
    var fileUnitNaId: String?
    var fileUnitTitle: String?

    var id: String { naId }

    /// Returns `true` when `geoKey` is served and `dateISO` falls within the roll's range.
    /// A dateless roll is excluded from date-filtered queries; a nil query date matches any.
    func matches(geoKey: String, dateISO: String?) -> Bool {
        guard geoKeys.contains(geoKey) else { return false }
        guard let dateISO else { return true }
        guard startISO != nil || endISO != nil else { return false }
        if let start = startISO, dateISO < start { return false }
        if let end = endISO, dateISO > end { return false }
        return true
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
