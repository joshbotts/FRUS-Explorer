// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CentralFilesConfidence

/// How confident the classifier is that a document belongs to a given series.
enum CentralFilesConfidence: Sendable {
    /// The dateline unambiguously identifies the series (e.g. a U.S. legation abroad).
    case high
    /// The dateline narrows to a small set but cannot disambiguate (Dept. of State
    /// outbound is either an Instruction or a Note to a foreign mission).
    case medium

    var label: String {
        switch self {
        case .high:   return String(localized: "centralFiles.confidence.high", defaultValue: "Likely")
        case .medium: return String(localized: "centralFiles.confidence.medium", defaultValue: "Possible")
        }
    }
}

// MARK: - CentralFilesClassification

/// A candidate series + country for a pre-1906 document, derived from its dateline,
/// heading, and FRUS chapter. The Source Explorer turns each into roll links.
struct CentralFilesClassification: Sendable, Equatable {
    let category: CentralFilesSeriesCategory
    let geoKeys: [String]
    let confidence: CentralFilesConfidence
    /// One-line explanation of the cue used, for display.
    let rationale: String

    static func == (l: CentralFilesClassification, r: CentralFilesClassification) -> Bool {
        l.category == r.category && l.geoKeys == r.geoKeys && l.rationale == r.rationale
    }
}

// MARK: - CentralFilesClassifier

/// Classifies a pre-1906 FRUS document into the country-arranged Central Files series it
/// was filed in, using the cues that the reference-data trace (Finding 5) showed are
/// reliable: the **dateline** (originating office) decides the series; the **FRUS chapter**
/// gives the country. Pre-1906 documents carry no source note, so this is the only path.
///
/// The Instruction vs. Note-to distinction is genuinely ambiguous from a Washington-dated
/// document alone (both are Department of State outbound; the difference is whether the
/// addressee is a U.S. minister abroad or a foreign minister in Washington — which the
/// document text doesn't state). Both are returned as `medium`-confidence candidates.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2
enum CentralFilesClassifier {

    /// Returns candidate classifications, best-first, or `[]` when no cue applies (e.g. a
    /// consular despatch — Phase 3 — or a document with no resolvable country).
    static func classify(header: String, dateline: String, chapterCountry: String?) -> [CentralFilesClassification] {
        let dl = dateline.lowercased()

        // Consular despatch (Phase 3) — handled first, because its geography is the post
        // CITY taken from the dateline ("Consulate-General…, Havana") rather than the FRUS
        // chapter country. No city → can't resolve.
        if dl.contains("consulate") || dl.contains("consular") {
            guard let city = consularPostKey(fromDateline: dateline) else { return [] }
            return [CentralFilesClassification(
                category: .consularDespatches, geoKeys: [city], confidence: .high,
                rationale: String(localized: "centralFiles.rationale.consular",
                                  defaultValue: "Dateline is a U.S. consulate abroad — a consular despatch to the Department."))]
        }

        // Diplomatic series — geography is the FRUS chapter country.
        let geoKeys = chapterCountry.map { GeoKeyNormalizer.keys(from: $0) } ?? []
        guard !geoKeys.isEmpty else { return [] }

        // A U.S. diplomatic mission abroad → a despatch home.
        if containsAny(dl, ["legation of the united states", "embassy of the united states",
                            "american legation", "american embassy",
                            "united states legation", "u. s. legation", "u.s. legation"]) {
            return [CentralFilesClassification(
                category: .despatches, geoKeys: geoKeys, confidence: .high,
                rationale: String(localized: "centralFiles.rationale.despatch",
                                  defaultValue: "Dateline is a U.S. mission abroad — a despatch to the Department."))]
        }

        // Department of State outbound → an instruction or a note to a foreign mission.
        if dl.contains("department of state") {
            return [
                CentralFilesClassification(
                    category: .instructions, geoKeys: geoKeys, confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.instruction",
                                      defaultValue: "Department of State outbound; if the addressee is the U.S. minister abroad, it is an instruction.")),
                CentralFilesClassification(
                    category: .notesTo, geoKeys: geoKeys, confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.noteTo",
                                      defaultValue: "Department of State outbound; if the addressee is the foreign minister in Washington, it is a note to the legation.")),
            ]
        }

        // A foreign legation/embassy in Washington → a note from a foreign mission.
        if dl.contains("washington"), containsAny(dl, ["legation", "embassy"]) {
            return [CentralFilesClassification(
                category: .notesFrom, geoKeys: geoKeys, confidence: .high,
                rationale: String(localized: "centralFiles.rationale.noteFrom",
                                  defaultValue: "Dateline is a foreign legation in Washington — a note from the foreign mission."))]
        }

        // Fallback: datelined abroad — no Washington / Department of State marker. The
        // dateline frequently gives only the city (e.g. "Paris, December 11, 1863.") without
        // spelling out "Legation of the United States". In these country-arranged volumes such
        // documents are overwhelmingly despatches from the U.S. mission (or enclosures filmed
        // with them), so resolve to the country's despatch series.
        if !dl.trimmingCharacters(in: .whitespaces).isEmpty,
           !dl.contains("washington"), !dl.contains("department of state") {
            return [CentralFilesClassification(
                category: .despatches, geoKeys: geoKeys, confidence: .medium,
                rationale: String(localized: "centralFiles.rationale.despatchAbroad",
                                  defaultValue: "Datelined abroad — likely a despatch from the U.S. mission (or an enclosure filed with it)."))]
        }

        return []
    }

    /// Extracts the consular post city key from a dateline, normalized to match the index.
    ///
    /// Handles `Consulate[-General][, of the United States], {City}, {date}` (city is the
    /// comma-segment that isn't the consulate phrase / "United States" / "American") and the
    /// `Consulate … at {City}` form. Returns `nil` when no city can be isolated.
    static func consularPostKey(fromDateline dateline: String) -> String? {
        // Drop the trailing date so its month/place tokens don't masquerade as the city.
        let preDate: String
        if let r = dateline.range(of: #"[A-Za-z]+\.?\s+\d{1,2}\s*,?\s*\d{4}"#, options: .regularExpression) {
            preDate = String(dateline[..<r.lowerBound])
        } else {
            preDate = dateline
        }
        let segments = preDate.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 1. A standalone city segment (not the office phrase).
        for seg in segments {
            let low = seg.lowercased()
            if low.contains("consul") || low.contains("united states") || low.contains("american")
                || low.contains("legation") || low.contains("embassy") { continue }
            let key = GeoKeyNormalizer.canonicalize(seg)
            if !key.isEmpty { return key }
        }
        // 2. The "Consulate … at {City}" form.
        for seg in segments where seg.lowercased().contains("consul") {
            if let r = seg.range(of: #"\bat\s+"#, options: [.regularExpression, .caseInsensitive]) {
                let key = GeoKeyNormalizer.canonicalize(String(seg[r.upperBound...]))
                if !key.isEmpty { return key }
            }
        }
        return nil
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    // MARK: - Dateline date

    private static let monthDayYear = try? NSRegularExpression(
        pattern: #"([A-Za-z]+)\.?\s+(\d{1,2})\s*,?\s*(\d{4})"#)

    /// Parses the document date from a dateline (`…, February 3, 1900.`) to ISO. Uses the
    /// first `Month D, YYYY` — the sent date — ignoring a trailing `(Received …)` clause.
    static func datelineDateISO(from dateline: String) -> String? {
        let ns = dateline as NSString
        guard let m = monthDayYear?.firstMatch(in: dateline, range: NSRange(location: 0, length: ns.length)),
              let month = HistoricalMonth.number(ns.substring(with: m.range(at: 1))),
              let day = Int(ns.substring(with: m.range(at: 2))),
              let year = Int(ns.substring(with: m.range(at: 3))) else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, min(max(day, 1), 31))
    }

    // MARK: - Section path

    /// The chain of section titles from the volume root down to the section that
    /// **directly** contains `documentId` — e.g. `["Correspondence.", "Great Britain.",
    /// "Correspondence respecting the capture of the Saxon…"]`.
    ///
    /// Pre-1906 "Papers Relating to Foreign Affairs" volumes nest the country (e.g.
    /// "Great Britain.") as a chapter with subject subchapters beneath it — and the
    /// documents live in those subchapters — so the country is rarely the top-level
    /// section. Callers try each title in the returned chain to find the one that resolves
    /// to a country series, rather than assuming a single "chapter country".
    ///
    /// Returns `[]` when the document isn't found in the structure.
    static func documentSectionPath(in structure: VolumeStructure, documentId: String) -> [String] {
        func search(_ sections: [VolumeSection], _ ancestors: [String]) -> [String]? {
            for section in sections {
                let chain = ancestors + [section.title]
                if section.documentIds.contains(documentId) { return chain }
                if let hit = search(section.subsections, chain) { return hit }
            }
            return nil
        }
        return search(structure.sections, []) ?? []
    }
}

// MARK: - HistoricalMonth

/// Month-name → number, shared by the classifier's dateline parsing.
enum HistoricalMonth {
    static func number(_ name: String) -> Int? {
        switch name.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) {
        case "jan", "january":           return 1
        case "feb", "february":          return 2
        case "mar", "march":             return 3
        case "apr", "april":             return 4
        case "may":                      return 5
        case "jun", "june":              return 6
        case "jul", "july":              return 7
        case "aug", "august":            return 8
        case "sep", "sept", "september": return 9
        case "oct", "october":           return 10
        case "nov", "november":          return 11
        case "dec", "december":          return 12
        default:                         return nil
        }
    }
}
