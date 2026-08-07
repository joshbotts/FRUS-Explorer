// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DigitizedRange

/// One digitised NARA file unit, keyed by the decimal file range its title states (#663).
///
/// The app-side mirror of `DigitizedRangeIndexGeneratorCore.DigitizedRange`; the JSON is the
/// contract between them.
struct DigitizedRange: Codable, Sendable, Equatable, Identifiable {
    /// The decimal class, lower-cased and dot-normalised (`763.72119`).
    let decimalClass: String
    /// First and last document serial the file unit's title claims, inclusive.
    let low: Int
    let high: Int
    /// The file unit's NARA Archival Identifier.
    let naId: String
    /// How many scanned images the unit holds.
    let objectCount: Int
    /// The scan's own URL on `catalog.archives.gov`, when the unit publishes one.
    let objectUrl: String?
    /// The scan's filename, which names the microfilm publication and roll
    /// (`M367_Roll20.pdf`) — often the most legible thing about the record.
    let objectFilename: String?
    /// NARA's own title for the range, shown verbatim rather than reconstructed.
    let title: String

    var id: String { naId }

    /// The file unit's catalog record — always offered, because it is the page with the image
    /// viewer on it.
    var catalogURL: URL? { URL(string: "https://catalog.archives.gov/id/\(naId)") }

    /// The direct scan link, **only when it is a whole microfilm roll**.
    ///
    /// 440 of the 624 ranges publish a `.pdf` — a complete roll, which is worth opening
    /// directly. The other 184 publish a `.tif` or `.jpg`: that is the *first image* of the
    /// unit, and sending a researcher to one frame of 802 is worse than sending them to the
    /// viewer that holds all of them. So the direct link is withheld there rather than made
    /// to look equivalent.
    var rollPDFURL: URL? {
        guard let objectUrl, let objectFilename,
              objectFilename.lowercased().hasSuffix(".pdf") else { return nil }
        return URL(string: objectUrl)
    }

    /// Whether `serial` falls inside this range.
    func contains(serial: Int) -> Bool { serial >= low && serial <= high }
}

// MARK: - DigitizedRangeMatch

/// What the index can say about one decimal citation (#663).
///
/// Three outcomes, and the distinction between the first two is the whole point: **4.6% of
/// adjacent ranges within a class overlap** in NARA's own titles, and a wrong roll sends a
/// researcher into the wrong several-hundred-page scan. An ambiguous answer is presented as
/// ambiguous.
enum DigitizedRangeMatch: Sendable, Equatable {
    /// Exactly one digitised range claims this serial.
    case resolved(DigitizedRange)
    /// More than one claims it. NARA's ranges overlap here and the catalogue cannot say which
    /// is right, so both are offered and neither is asserted.
    case ambiguous([DigitizedRange])
    /// The class has digitised ranges but none contains this serial — worth saying, because
    /// "scans exist for this file, just not this part of it" is useful and is not "no scans".
    case classDigitizedButSerialNotCovered(rangeCount: Int)
    /// Nothing digitised for this class.
    case none
}

// MARK: - DigitizedRangeIndex

/// The bundled index of digitised decimal-file ranges (#663).
///
/// ## What this reaches, and what it does not
/// The NARA harvest carries `digitalObjects` on 17,985 records — 10.1M individual scans. The
/// slice a FRUS decimal citation can actually land in is much narrower than that number
/// suggests, and the honest figure matters more than the impressive one.
///
/// Measured over the shipped artifact and the owner's index (185,694 decimal citations carrying
/// a parsed class):
///
/// | | documents | share |
/// |---|---|---|
/// | class has any digitised numeric range | 5,791 | 3.1% |
/// | citation's serial lands **inside** a range | **5,326** | 2.9% |
///
/// And it is concentrated almost entirely in one file: `763.72` — the European War 1914–1918
/// decimal file — plus its sub-classes account for over 5,000 of those. In practice this is
/// *the WWI supplements get their microfilm*, which is worth having and is not a corpus-wide
/// capability. The UI says "file range", never "this document".
///
/// The classes FRUS cites most have **zero** digitised units — 893 (China, internal) at 10,876
/// documents, 611 at 6,767, 793 at 5,780 — because NARA's RG 59 digitisation followed the
/// microfilm publications, which concentrate on 1910–1929 and on the visa classes FRUS barely
/// touches.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663
struct DigitizedRangeIndex: Codable, Sendable {
    let schemaVersion: Int
    let generated: String
    let seriesNaIds: [String]
    let note: String
    let ranges: [DigitizedRange]

    /// `ranges` grouped by class, built once at decode. Source Explorer asks once per opened
    /// document; the corpus browser could ask per row.
    private let byClass: [String: [DigitizedRange]]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, seriesNaIds, note, ranges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        generated = try c.decodeIfPresent(String.self, forKey: .generated) ?? ""
        seriesNaIds = try c.decodeIfPresent([String].self, forKey: .seriesNaIds) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        ranges = try c.decodeIfPresent([DigitizedRange].self, forKey: .ranges) ?? []
        byClass = Dictionary(grouping: ranges, by: \.decimalClass)
    }

    /// What the index can say about a decimal citation.
    ///
    /// - Parameters:
    ///   - decimalClass: The citation's class as `document_sources.decimal_class` stores it.
    ///   - serial: The document serial after the `/`.
    func match(decimalClass: String, serial: Int) -> DigitizedRangeMatch {
        let key = Self.canonicalClass(decimalClass)
        guard let candidates = byClass[key], !candidates.isEmpty else { return .none }
        let hits = candidates.filter { $0.contains(serial: serial) }
        switch hits.count {
        case 0:  return .classDigitizedButSerialNotCovered(rangeCount: candidates.count)
        case 1:  return .resolved(hits[0])
        default: return .ambiguous(hits.sorted { ($0.low, $0.high) < ($1.low, $1.high) })
        }
    }

    /// The class key both sides join on. The harvest titles write `131.` and `131`
    /// interchangeably, so the trailing dot cannot be part of the key or half a class's ranges
    /// become unreachable.
    static func canonicalClass(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            .lowercased()
    }

    /// The class and serial a decimal file identifier states, or `nil`.
    ///
    /// `763.72/1476` → `("763.72", 1476)`. A citation with no serial after the slash cannot be
    /// placed in a range, and gets `nil` rather than being matched on class alone — the class
    /// is not the document.
    static func classAndSerial(fromFileIdentifier identifier: String) -> (String, Int)? {
        guard let match = citationRegex?.firstMatch(
            in: identifier, range: NSRange(identifier.startIndex..., in: identifier)),
              let classRange = Range(match.range(at: 1), in: identifier),
              let serialRange = Range(match.range(at: 2), in: identifier),
              let serial = Int(identifier[serialRange])
        else { return nil }
        return (canonicalClass(String(identifier[classRange])), serial)
    }

    private static let citationRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"([0-9][0-9A-Za-z.\-]*?)\s*/\s*(\d+)"#)
}

// MARK: - DigitizedRangeIndexStore

/// Loads the bundled `digitized-ranges-index.json` once, mirroring the other Source Explorer
/// stores. `nil` when the resource is absent or malformed — in which case the surfaces simply
/// show nothing extra, as before.
enum DigitizedRangeIndexStore {
    static let shared: DigitizedRangeIndex? = load()

    private static func load() -> DigitizedRangeIndex? {
        guard let url = Bundle.main.url(forResource: "digitized-ranges-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] DigitizedRangeIndexStore: resource not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(DigitizedRangeIndex.self,
                                            from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] DigitizedRangeIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
