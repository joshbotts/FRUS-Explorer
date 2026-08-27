// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CountrySeriesCategory

/// The four country-arranged diplomatic series (Phase 2), each with the structure its
/// real catalog records exhibit (harvested 2026-06-15).
///
/// | Category | Resolution record | Geo source | Dates |
/// |---|---|---|---|
/// | `.despatches` | item | parent file-unit title (`…Ministers to {Country}, …`) | item title |
/// | `.instructions` | fileUnit | own title (`Volume {n}: {Country}: {dates}`) | own title |
/// | `.notesFrom` | item | parent file-unit title (`…the {Demonym} Legation…`) | item title |
/// | `.notesTo` | fileUnit | own title (`{Country[ and …]}: {dates}`) | own title |
/// | `.consularDespatches` | item | parent file-unit title (`…U.S. Consuls in {City}, …`) | item title |
/// | `.consularInstructions` | fileUnit | — (chronological run) | own title, after the last label colon |
/// | `.notesToForeignConsuls` | fileUnit | — (chronological run) | own title (`6/17/1853 - 1/31/1865`) |
/// | `.notesFromForeignConsuls` | fileUnit | — (chronological run) | own title |
///
/// The three W-8 tail series (Phase 3's remainder) are SINGLE CHRONOLOGICAL RUNS: NARA
/// arranges them by date alone, their file units ARE the bound volumes, and no geography
/// exists to key on — `isChronologicalRun` is what tells a consumer to match by date only.
public enum CountrySeriesCategory: String, Sendable, CaseIterable {
    case despatches = "diplomaticDespatches"
    case instructions = "diplomaticInstructions"
    case notesFrom = "notesFromForeignMissions"
    case notesTo = "notesToForeignMissions"
    case consularDespatches = "consularDespatches"
    case consularInstructions = "consularInstructions"
    case notesToForeignConsuls = "notesToForeignConsuls"
    case notesFromForeignConsuls = "notesFromForeignConsuls"

    /// NARA series NAID.
    public var seriesNaId: String {
        switch self {
        case .despatches:              return "603720"
        case .instructions:            return "593313"
        case .notesFrom:               return "594363"
        case .notesTo:                 return "597272"
        case .consularDespatches:      return "302031"
        case .consularInstructions:    return "604019"
        case .notesToForeignConsuls:   return "1076611"
        case .notesFromForeignConsuls: return "1076629"
        }
    }

    /// Human-readable series name for display.
    public var displayName: String {
        switch self {
        case .despatches:              return "Diplomatic Despatches"
        case .instructions:            return "Diplomatic Instructions"
        case .notesFrom:               return "Notes from Foreign Missions"
        case .notesTo:                 return "Notes to Foreign Missions"
        case .consularDespatches:      return "Consular Despatches"
        case .consularInstructions:    return "Consular Instructions"
        case .notesToForeignConsuls:   return "Notes to Foreign Consuls"
        case .notesFromForeignConsuls: return "Notes from Foreign Consuls"
        }
    }

    /// The `levelOfDescription` of the records that are the page-by-page resolution
    /// targets for this series (the rest are skipped during the build).
    public var resolutionLevel: String {
        switch self {
        case .despatches, .notesFrom, .consularDespatches: return "item"
        case .instructions, .notesTo,
             .consularInstructions, .notesToForeignConsuls,
             .notesFromForeignConsuls:                     return "fileUnit"
        }
    }

    /// `true` for a series NARA arranges by date alone — no geography exists on its
    /// volumes, so a resolver must match by date only (`CountryRoll.matchesDate`), never
    /// through the geo-keyed path, whose `geoKeys.contains` guard would refuse every roll.
    public var isChronologicalRun: Bool {
        switch self {
        case .consularInstructions, .notesToForeignConsuls, .notesFromForeignConsuls:
            return true
        case .despatches, .instructions, .notesFrom, .notesTo, .consularDespatches:
            return false
        }
    }
}

// MARK: - ParsedCountryRoll

/// The geo + date extraction result for one resolution record.
public struct ParsedCountryRoll: Sendable, Equatable {
    public let geoKeys: [String]
    public let dateRange: DateRangeISO?
}

// MARK: - CountrySeriesParser

/// Extracts canonical geographic keys and a date range from a catalog record, per series.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 — Despatches, Instructions, Notes from/to
///   1.1 — W-8: the three chronological-run consular-tail series (Consular Instructions,
///         Notes to/from Foreign Consuls) — date-only, file-unit grain
public enum CountrySeriesParser {

    /// Parses a resolution record for `category`. Returns `nil` when the record is not a
    /// resolution target (wrong level) for the series.
    public static func parse(_ record: CatalogRecord, category: CountrySeriesCategory) -> ParsedCountryRoll? {
        guard record.levelOfDescription == category.resolutionLevel else { return nil }
        switch category {
        case .despatches:         return parseDespatches(record)
        case .instructions:       return parseInstructions(record)
        case .notesFrom:          return parseNotesFrom(record)
        case .notesTo:            return parseNotesTo(record)
        case .consularDespatches: return parseConsular(record)
        case .consularInstructions, .notesToForeignConsuls, .notesFromForeignConsuls:
            return parseChronologicalRun(record)
        }
    }

    // MARK: Chronological runs (fileUnit; date-only, no geography — W-8 tail)

    /// A chronological-run volume: the date range is the file unit's own title. Forms seen
    /// on the real records (all 22 file units of the three series):
    /// - `6/17/1853 - 1/31/1865`, `December 18, 1789 - December 31, 1826` — the bare range
    /// - `Instructions: October 12, 1801 - February 26, 1817` — a label before a colon
    /// - `Volume 1: "Despatches to Consuls," Pages 1-109: [through Sept. 1801]` — the date
    ///   lives in the LAST colon segment (an end-only "through" bound)
    ///
    /// The rule: parse the text after the LAST colon when that parses as a date; otherwise
    /// the whole title. Geography is `[]` by construction — see `isChronologicalRun`.
    private static func parseChronologicalRun(_ record: CatalogRecord) -> ParsedCountryRoll {
        var dateText = record.title
        if let colon = record.title.lastIndex(of: ":") {
            let tail = String(record.title[record.title.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            if HistoricalDateParser.parse(tail) != nil {
                dateText = tail
            }
        }
        dateText = dateText.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
        // "[through Sept. 1801]" is an END bound with an open start — parsed naively the
        // single date lands as a START, inverting the volume's coverage (a query before
        // Sept. 1801 would miss it; one after would wrongly hit it).
        if let r = dateText.range(of: #"^through\s+"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            let end = HistoricalDateParser.parse(String(dateText[r.upperBound...]))
            return ParsedCountryRoll(geoKeys: [], dateRange: end.map {
                DateRangeISO(startISO: nil, endISO: $0.startISO, plausible: $0.plausible)
            })
        }
        return ParsedCountryRoll(geoKeys: [], dateRange: HistoricalDateParser.parse(dateText))
    }

    // MARK: Despatches (item; geo from parent file-unit title)

    private static func parseDespatches(_ record: CatalogRecord) -> ParsedCountryRoll {
        let geo = record.parentFileUnitTitle.map(despatchesCountryKeys) ?? []
        return ParsedCountryRoll(geoKeys: geo, dateRange: HistoricalDateParser.parse(record.title))
    }

    // MARK: Consular Despatches (item; geo = post city from parent file-unit title)

    private static func parseConsular(_ record: CatalogRecord) -> ParsedCountryRoll {
        let geo = record.parentFileUnitTitle.map(consularPostKeys) ?? []
        return ParsedCountryRoll(geoKeys: geo, dateRange: HistoricalDateParser.parse(record.title))
    }

    /// Consular file-unit title → the post city key(s). The city is the first
    /// comma-delimited component after stripping the (highly variable) `Despatches from …
    /// {agency} {role} in/to` lead and the trailing date range. A parenthetical alternate
    /// spelling (`Brusa (Brousa)`) yields both as keys.
    ///
    /// Real lead forms (504 file units): `Despatches from U.S./U. S./US/United States
    /// Consuls in {City}`, `…the U.S. Consuls in`, `…Consular Officers, {City}`,
    /// `…Consular Offices - {City}`, `…Consular Representatives in`, `…Consuls to`,
    /// `…Ministers to`, `Despatches from {City}`, and a bare `{City}, {dates}`.
    static func consularPostKeys(fromParent title: String) -> [String] {
        var phrase = stripTrailingDateRange(title)
        // Strip the "Despatches from " lead.
        if let r = phrase.range(of: #"^Despatches\s+[Ff]rom\s+"#, options: [.regularExpression]) {
            phrase = String(phrase[r.upperBound...])
        }
        // Strip an optional agency + role + connector: "(the) (U.S./United States)
        // {Consular Officers|Consular Offices|Consular Representatives|Consuls|Ministers}
        // (in|to)? (- | ,)?". Cities that don't begin with a role word pass through.
        let lead = #"^(?:the\s+)?(?:U\.?\s*S\.?\s+|United States\s+)?(?:Consular Officers?|Consular Offices?|Consular Representatives?|Consuls?|Ministers?)\b\s*(?:in|to)?\s*[-–,]?\s*"#
        if let r = phrase.range(of: lead, options: [.regularExpression, .caseInsensitive]) {
            phrase = String(phrase[r.upperBound...])
        }
        phrase = phrase.trimmingCharacters(in: .whitespaces)
        guard let city = phrase.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces), !city.isEmpty else { return [] }
        // Split a `Main (Alternate)` spelling into both keys.
        if let m = firstGroups(in: city, pattern: #"^(.+?)\s*\((.+?)\)\s*$"#) {
            return [GeoKeyNormalizer.canonicalize(m.0), GeoKeyNormalizer.canonicalize(m.1)]
                .filter { !$0.isEmpty }
        }
        let key = GeoKeyNormalizer.canonicalize(city)
        return key.isEmpty ? [] : [key]
    }

    /// `Despatches from U.S. Ministers to {Country}, {dates}` /
    /// `Despatches from Diplomatic Officers, {Country}` → canonical keys.
    static func despatchesCountryKeys(fromParent title: String) -> [String] {
        var phrase = title
        if let r = phrase.range(of: #"^Despatches from (?:U\.?S\.? Ministers to (?:the )?|Diplomatic Officers,\s*)"#,
                                options: [.regularExpression]) {
            phrase = String(phrase[r.upperBound...])
        }
        return splitCountryKeys(stripTrailingDateRange(phrase))
    }

    // MARK: Instructions (fileUnit; geo + dates from own title)

    private static func parseInstructions(_ record: CatalogRecord) -> ParsedCountryRoll {
        // `Volume {n}: {Country}: {dates}` — country between the volume label and the date;
        // early volumes are `Volume {n}: {dates}` with no country (chronological run).
        let parts = record.title.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        var geo: [String] = []
        var dateText = record.title
        if parts.count >= 3 {
            geo = splitCountryKeys(parts[1])
            dateText = parts[(2...)].joined(separator: ": ")
        } else if parts.count == 2 {
            // Either "Volume N: dates" (no country) or "Volume N: Country" (no date).
            if HistoricalDateParser.parse(parts[1]) != nil {
                dateText = parts[1]
            } else {
                geo = splitCountryKeys(parts[1])
            }
        }
        return ParsedCountryRoll(geoKeys: geo, dateRange: HistoricalDateParser.parse(dateText))
    }

    // MARK: Notes from (item; geo from parent demonym, dates from item title)

    private static func parseNotesFrom(_ record: CatalogRecord) -> ParsedCountryRoll {
        let geo = record.parentFileUnitTitle.map(notesFromCountryKeys) ?? []
        return ParsedCountryRoll(geoKeys: geo, dateRange: HistoricalDateParser.parse(record.title))
    }

    /// Extracts the country from a Notes-from parent file-unit title, handling the demonym
    /// (`the {Demonym} Legation`), `Legation of {Country}`, `Foreign Missions, {Country}`,
    /// and `Central American Legations` forms; a leading `T## - ` microfilm prefix is
    /// stripped. `Miscellaneous Foreign States` rolls have no single country → `[]`.
    static func notesFromCountryKeys(fromParent title: String) -> [String] {
        var text = title
        // Strip a leading microfilm prefix, e.g. "T93 - ".
        if let r = text.range(of: #"^[A-Z]\d+\s*-\s*"#, options: [.regularExpression]) {
            text = String(text[r.upperBound...])
        }
        // Strip "Notes from " lead.
        if let r = text.range(of: #"^Notes from\s+"#, options: [.regularExpression, .caseInsensitive]) {
            text = String(text[r.upperBound...])
        }
        if text.range(of: "Miscellaneous", options: .caseInsensitive) != nil { return [] }

        // "the Legation(s) of {Country} in the United States…"
        if let m = firstGroup(in: text, pattern: #"^(?:the )?Legations? of (.+?) in the United States"#) {
            return splitCountryKeys(m)
        }
        // "Foreign Missions, {Country}"
        if let m = firstGroup(in: text, pattern: #"^Foreign Missions,\s*(.+?)\s*$"#) {
            return splitCountryKeys(stripTrailingDateRange(m))
        }
        // "{Demonym} Legation(s) in the United States…"  (also "Central American Legations …")
        if let m = firstGroup(in: text, pattern: #"^(?:the )?(.+?) Legations? in the United States"#) {
            return splitCountryKeys(m)
        }
        // Fallback: "{Demonym} Legation(s)…"
        if let m = firstGroup(in: text, pattern: #"^(?:the )?(.+?) Legations?\b"#) {
            return splitCountryKeys(m)
        }
        return []
    }

    // MARK: Notes to (fileUnit; geo + dates from own title)

    private static func parseNotesTo(_ record: CatalogRecord) -> ParsedCountryRoll {
        // `{Country[ and Country]}: {dates}`. Early volumes are date-only (no colon, or a
        // descriptive register title).
        guard let colon = record.title.firstIndex(of: ":") else {
            return ParsedCountryRoll(geoKeys: [], dateRange: HistoricalDateParser.parse(record.title))
        }
        let countryPart = String(record.title[..<colon])
        let datePart = String(record.title[record.title.index(after: colon)...])
        // A leading "Volume N" / register label is not a country.
        let geo = countryPart.range(of: #"\d"#, options: .regularExpression) != nil
            ? [] : splitCountryKeys(countryPart)
        return ParsedCountryRoll(geoKeys: geo, dateRange: HistoricalDateParser.parse(datePart))
    }

    // MARK: - Helpers

    /// Splits a country phrase on conjunctions and canonicalizes each part.
    private static func splitCountryKeys(_ phrase: String) -> [String] {
        phrase
            .replacingOccurrences(of: " & ", with: " and ")
            .replacingOccurrences(of: ", and ", with: " and ")
            .replacingOccurrences(of: ", ", with: " and ")
            .components(separatedBy: " and ")
            .map { GeoKeyNormalizer.canonicalize($0) }
            .filter { !$0.isEmpty }
    }

    /// Removes a trailing `, {dates}` clause (a comma followed by text containing a
    /// 4-digit year), so `Chile, 1823-1906` → `Chile` and
    /// `Serbia, July 5, 1900-July 31, 1906` → `Serbia`.
    static func stripTrailingDateRange(_ s: String) -> String {
        guard let r = s.range(of: #",\s*(?:[A-Za-z]+\.?\s+\d{1,2},?\s*)?\d{4}.*$"#,
                              options: [.regularExpression]) else {
            return s.trimmingCharacters(in: .whitespaces)
        }
        return String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    private static func firstGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }

    /// Returns the first two capture groups of `pattern` matched against `text`, or `nil`.
    private static func firstGroups(in text: String, pattern: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 2,
              m.range(at: 1).location != NSNotFound, m.range(at: 2).location != NSNotFound else { return nil }
        return (ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces),
                ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces))
    }
}
