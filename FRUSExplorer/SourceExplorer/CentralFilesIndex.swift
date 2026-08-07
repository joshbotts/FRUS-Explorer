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

    /// `lotFiles` keyed by its already-normalized `lotNumber`, built once at decode.
    ///
    /// `lotFile(forRawLot:)` used to scan all 971 entries. That was fine while Source Explorer
    /// was the only caller — once per opened document — but the #372/N-5 repoint put it on the
    /// corpus browser's Sources outline, which calls it **once per row**, and a volume like
    /// `frus1964-68v06` has 755. Not part of the encoded shape: `CodingKeys` omits it, so a
    /// re-encode round-trips unchanged.
    private let lotFilesByNumber: [String: LotFileEntry]

    // The generator defaults newer fields; tolerate their absence for forward safety.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        generated = try container.decodeIfPresent(String.self, forKey: .generated) ?? ""
        numericalFile = try container.decode(NumericalFileIndex.self, forKey: .numericalFile)
        countrySeries = try container.decodeIfPresent([CountrySeriesIndex].self, forKey: .countrySeries) ?? []
        lotFiles = try container.decodeIfPresent([LotFileEntry].self, forKey: .lotFiles) ?? []
        // First wins, matching the `first(where:)` this replaced. The shipped bundle has no
        // duplicate lot numbers, so the tie-break is a formality rather than a policy.
        lotFilesByNumber = Dictionary(lotFiles.map { ($0.lotNumber, $0) },
                                      uniquingKeysWith: { first, _ in first })
    }

    /// Returns the country series for `category`, if present.
    func series(category: CentralFilesSeriesCategory) -> CountrySeriesIndex? {
        countrySeries.first { $0.category == category.rawValue }
    }

    /// Returns the pre-resolved lot file for a raw lot number from a source note, or `nil`.
    /// The raw form (`"63 D 135"`, `"61-D 146"`) is normalized to the bundle's compact key.
    ///
    /// **Entries flagged `ancestryLacksRecordGroup` are treated as unresolved** (#321): the
    /// 2026-07-15 harvest measured the resolver's null-record-group fallback at **0/16
    /// precision** — every flagged record was a presidential-library staff file (Ford,
    /// Reagan, Clinton, Bush, FDR), not a State Department lot, so surfacing them would hand
    /// researchers confidently wrong NARA links. Returning `nil` here routes both platforms'
    /// Source Explorers to their live-lookup fallback, which is exactly the honest behavior
    /// for a lot the bundle cannot vouch for. The durable resolver fix (drop the fallback,
    /// re-harvest) is #321; this guard makes the shipped data safe in the meantime.
    ///
    /// **`fileUnit`-level matches are also treated as unresolved** (#351): the corpus-wide
    /// Source Explorer audit (#335) found the 16 `fileUnit`-level lot resolutions are almost
    /// entirely wrong-collection — the query matched a *file unit* whose own control-number list
    /// is empty (e.g. Conference Files Lot 60 D 627, the corpus's 2nd-most-cited lot, resolving
    /// to an "Operation Mongoose / Cuba – 1963" file unit; others to Nazi-War-Crimes disclosure
    /// folders and the Polish Foreign Ministry). All 947 `series`-level entries sampled sane, so
    /// this guard rejects exactly the fileUnit class. Durable across re-harvests, like the #321
    /// guard; the generator also rejects fileUnit hits at harvest time going forward.
    func lotFile(forRawLot raw: String) -> LotFileEntry? {
        let key = CentralFilesIndex.normalizeLot(raw)
        guard let entry = lotFilesByNumber[key],
              entry.ancestryLacksRecordGroup != true,
              !entry.isFileUnitLevel else { return nil }
        return entry
    }

    /// NARA NAIDs the bundle resolved through a **candidate mis-resolution** — a `fileUnit`-level
    /// or `ancestryLacksRecordGroup` lot match (#351). These are the wrong-collection NAIDs the
    /// `lotFile(forRawLot:)` guard hides in Source Explorer's own card, but the *same* NAIDs were
    /// baked into the sibling bundles built from an earlier central-files index — the
    /// `collection-authority` lot clusters and the `volume-sources` archival outline — which read
    /// their NAID directly rather than re-resolving. Those surfaces consult this set at render
    /// time (`isUntrustworthyNAID`) so a lot like Conference Files 60 D 627 stops linking to the
    /// "Operation Mongoose" file unit everywhere, without regenerating the downstream artifacts
    /// (that keyed re-resolution is #352). Empty once those bundles are re-harvested.
    var untrustworthyNAIDs: Set<String> {
        Set(lotFiles.compactMap {
            ($0.isFileUnitLevel || $0.ancestryLacksRecordGroup == true) ? $0.naId : nil })
    }

    /// Whether `naId` was produced by a candidate mis-resolution and must not be surfaced as a
    /// NARA link from a lot-keyed record in any bundle (#351). `nil`/empty is trustworthy.
    /// The scan is over the ~16 flagged/fileUnit entries' NAIDs; callers at render frequency can
    /// hoist `untrustworthyNAIDs` if they test many records.
    func isUntrustworthyNAID(_ naId: String?) -> Bool {
        guard let naId, !naId.isEmpty else { return false }
        return untrustworthyNAIDs.contains(naId)
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

    /// Whether this entry resolved to a **file unit** rather than a series (#351). A real lot
    /// file is catalogued as a series; a `fileUnit` match is a control-number query that landed
    /// on a folder inside another collection (the #335-audited 60 D 627 → "Operation Mongoose"
    /// class), so `lotFile(forRawLot:)` treats it as unresolved. `nil` level reads as `false`.
    var isFileUnitLevel: Bool { levelOfDescription == "fileUnit" }

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
    ///
    /// An OCR-mangled title date — a stray case number parsed as an implausible year (e.g.
    /// "…- August 31, 139" → 1596, or "Nov. 1, 11186 -" → 1318) — is **ignored**, not used to
    /// filter. Otherwise such a roll (its other bound valid) silently vanishes from every
    /// date-filtered query. The country series are all pre-1906, so a bound outside 1780–1911 is
    /// untrustworthy. The generator applies the same guard at build time (`CountrySeriesIndexBuilder`).
    func matches(geoKey: String, dateISO: String?) -> Bool {
        guard geoKeys.contains(geoKey) else { return false }
        guard let dateISO else { return true }
        let start = CountryRoll.plausibleDate(startISO)
        let end = CountryRoll.plausibleDate(endISO)
        guard start != nil || end != nil else { return false }
        // An **inverted** range (start > end) that survived the plausibility filter — both bounds
        // in-window but reversed, e.g. "January 10, 1870 - March 31, 1861" — is still a corrupt
        // title date and, unguarded, is unsatisfiable (no date is ≥1870 AND ≤1861), so the roll
        // vanishes from every date query. We can't tell which bound is wrong, so fall back to a
        // geography-only match rather than hide the roll.
        if let start, let end, start > end { return true }
        if let start, dateISO < start { return false }
        if let end, dateISO > end { return false }
        return true
    }

    /// An ISO date whose year falls in the plausible pre-1906 country-series window (1780–1911),
    /// else `nil` — filters out OCR-mangled bounds.
    static func plausibleDate(_ iso: String?) -> String? {
        guard let iso, let year = Int(iso.prefix(4)), (1780...1911).contains(year) else { return nil }
        return iso
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
    ///
    /// Returns `nil` for a **decimal-file** citation, which carries no case number at all
    /// — see `isDecimalFileForm(_:)`.
    static func caseNumber(fromFileNumber fileNumber: String) -> Int? {
        guard !isDecimalFileForm(fileNumber) else { return nil }
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

    /// Whether a file identifier is written in the **decimal** file's form rather than the
    /// 1906–1910 Numerical File's (#354 item 5).
    ///
    /// ## Why the year cannot decide this
    /// Both surfaces that resolve Numerical File rolls gate on `documentYear` being
    /// 1906–1910, and the decimal file opened *in the middle of* 1910. Measured over the
    /// corpus, **334 documents** sit inside that year gate carrying a decimal citation —
    /// 327 of them dated 1910, plus a handful the editors cite from later filings.
    /// `835.415A/97`, `864.56/12`, `825.00/69`, `211.63 Or5/2`: the era boundary is a form,
    /// not a date, so the form is what this reads.
    ///
    /// ## Why it matters more than a missing link
    /// Without this, `caseNumber` takes the first run of digits and hands back `835`, `864`,
    /// `825` — real case numbers, belonging to real and entirely unrelated cases — and the
    /// roll lookup resolves them to real digitised rolls. The researcher is sent to a
    /// specific microfilm roll that does not hold the document and gives no sign of it. An
    /// honest "no match" is the better answer.
    ///
    /// ## The rule
    /// Starting **at the first digit** and stopping at the first `/`: a `.` followed, after
    /// any spaces, by an alphanumeric. Each clause carries a real case, and the rule was
    /// wrong without all three:
    ///
    /// - *From the first digit* — otherwise the abbreviation dot in a `"File No. 17529."`
    ///   label reads as a decimal point and gates a perfectly good numerical citation.
    ///   Anchoring on the digits skips the label without having to parse it. It cannot be
    ///   "the dot follows a digit" instead: `811B.5034` is decimal and its dot follows a
    ///   letter.
    /// - *Stopping at `/`* — the slash closes the case number, so `697/43`'s suffix cannot
    ///   make the citation decimal-era.
    /// - *After any spaces* — 14 documents cite `511. 4A1/914` and `812. 415A/7`, a space
    ///   transcribed into the decimal point. Without this clause they resolved cases 511
    ///   and 812. They are the reason this rule was measured against the corpus rather than
    ///   reasoned about: the first version looked right and missed all fourteen.
    static func isDecimalFileForm(_ fileNumber: String) -> Bool {
        guard let start = fileNumber.firstIndex(where: \.isNumber) else { return false }
        var sawDot = false
        for character in fileNumber[start...] {
            if character == "/" { return false }
            if sawDot {
                if character.isLetter || character.isNumber { return true }
                if character != " " { sawDot = false }
            } else if character == "." {
                sawDot = true
            }
        }
        return false
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
