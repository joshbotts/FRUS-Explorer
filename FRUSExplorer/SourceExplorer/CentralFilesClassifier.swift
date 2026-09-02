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

// MARK: - CentralFilesDocumentPart

/// Which part of a printed FRUS document an archival home belongs to (B-5, Finding 4).
///
/// **A printed document and its enclosures do not share an archival home.** The June 2026 pre-1910
/// research traced one FRUS text to two places: the enclosure is filmed in its own originating
/// series, while the covering despatch or instruction is filmed in another, where the enclosure is
/// only referenced. A reader given one roll for the whole page is being told something false about
/// half of it.
///
/// The classifier itself is unchanged and still answers about one dateline at a time; this names
/// *whose* dateline was asked about, so a surface can say which roll holds which text.
///
/// Version history:
///   1.0 — B-5 (W-8 residue), Finding 4: initial implementation
enum CentralFilesDocumentPart: Sendable, Equatable, Hashable {

    /// The printed document itself — the despatch, instruction or note.
    case document

    /// An enclosure printed beneath it, with the TEI's own label when it carries one.
    case enclosure(label: String?)

    /// A stable key, so a resolution's identity survives two parts resolving to one series.
    ///
    /// Without it a document and its enclosure that both classify to, say, Consular Despatches
    /// collide in a `ForEach` keyed on the category alone — the shape the surfaces used before
    /// this existed, where SwiftUI would have shown one row and silently dropped the other.
    var key: String {
        switch self {
        case .document: return "document"
        case .enclosure(let label): return "enclosure:\(label ?? "")"
        }
    }

    /// What the row is called on screen.
    var displayName: String {
        switch self {
        case .document:
            return String(localized: "centralFiles.part.document", defaultValue: "This document")
        case .enclosure(let label):
            guard let label, !label.isEmpty else {
                return String(localized: "centralFiles.part.enclosure",
                              defaultValue: "Enclosure")
            }
            return String(format: String(localized: "centralFiles.part.enclosure.numbered %@",
                                         defaultValue: "Enclosure %@"), label)
        }
    }

    /// Whether this part is an enclosure.
    var isEnclosure: Bool {
        if case .enclosure = self { return true }
        return false
    }

    /// The sentence a surface prints once when a document's enclosures have homes of their own.
    ///
    /// Said once for the section rather than per row: it is a fact about how the record was
    /// filed, not about any single roll, and repeating it per enclosure would train the reader
    /// to skip it — the argument `QueryMethodAppendix.caveats` already makes about its own.
    static var enclosureNote: String {
        String(localized: "centralFiles.part.enclosureNote.v2",
               defaultValue: "An enclosure was often filmed in its own series rather than with the document that enclosed it. Each row below says which text its rolls hold; check both.")
    }
}

// MARK: - CentralFilesEnclosureHomes

/// One enclosure's archival home: which part it is, what it classified to, and its rolls (B-5).
struct CentralFilesEnclosureHome: Sendable, Equatable {
    /// Which enclosure of the printed page this is.
    let part: CentralFilesDocumentPart
    /// The series it placed in.
    let classification: CentralFilesClassification
}

extension CentralFilesClassifier {

    /// The archival homes of a document's enclosures, from their own openers (B-5, Finding 4).
    ///
    /// **Extracted from the two Source Explorer views rather than written into each.** They are
    /// hand-maintained twins, and the first attempt at this feature drifted between them inside a
    /// single commit; the rule that decides what an enclosure resolves to is the part that must
    /// not. It is also the part worth testing, and a private method inside a SwiftUI view is not
    /// reachable from a test — which is how a mutation that removed the narrowing survived a
    /// sweep that killed everything else.
    ///
    /// **`chapterCountry` is deliberately `nil`.** An enclosure prints no chapter of its own, so
    /// borrowing the parent's would let the 74.8% of dateline-bearing enclosures whose dateline
    /// names only a city resolve through the `.medium` "datelined abroad" fallback to the PARENT's
    /// country, and then be labelled "Enclosure" — a parent-derived guess wearing an enclosure's
    /// name, which is the conflation this feature exists to end. Passing `nil` makes the
    /// classifier refuse them: the geo-keyed branches guard on a non-empty `geoKeys` and the
    /// fallback returns an empty one the caller's roll lookup skips. What survives is the
    /// self-placing form — a dateline naming its own institution, or a chronological run matched
    /// by date — measured at 5,876 of 23,296 dateline-bearing enclosures.
    ///
    /// - Parameter openers: the enclosure openers, in printed order.
    /// - Returns: one home per enclosure that places, de-duplicated on part and series — two
    ///   enclosures of one document routinely share a series, and the reader needs the row once.
    static func enclosureHomes(
        openers: [IndexingPipeline.EnclosureOpener]
    ) -> [CentralFilesEnclosureHome] {
        var homes: [CentralFilesEnclosureHome] = []
        var seen = Set<String>()
        for opener in openers {
            let part = CentralFilesDocumentPart.enclosure(label: opener.label)
            for classification in classify(header: opener.header,
                                           dateline: opener.dateline,
                                           chapterCountry: nil) {
                let key = "\(part.key)|\(classification.category.rawValue)"
                guard seen.insert(key).inserted else { continue }
                homes.append(CentralFilesEnclosureHome(part: part, classification: classification))
            }
        }
        return homes
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
///   1.2 — W-8 remainder: the domestic and special-agent cues — another executive
///         department's dateline is a letter RECEIVED; Department outbound addressed to a
///         cabinet office is a Domestic Letter; a "special agent/commissioner/mission"
///         phrase routes to the Special Agents series by direction.
///   1.1 — W-8: the three chronological-run consular-tail series. A foreign consulate in
///         the U.S. now classifies as a Note FROM a foreign consul (it used to fall into
///         the U.S.-consulate branch and dead-end on a U.S. city no despatch post serves);
///         Department outbound whose HEADER names a consul adds the Consular
///         Instructions / Notes-to-Foreign-Consuls pair — the same shape of honest
///         ambiguity as the existing Instructions / Notes-to pair, and resolved by date
///         alone (the three tail series carry no geography).
enum CentralFilesClassifier {

    /// Returns candidate classifications, best-first, or `[]` when no cue applies (e.g. a
    /// document with no resolvable country and no consular cue).
    static func classify(header: String, dateline: String, chapterCountry: String?) -> [CentralFilesClassification] {
        let dl = dateline.lowercased()
        let headerL = header.lowercased()

        // A special agent's correspondence (W-8 remainder) — the most specific cue, checked
        // first: a document naming a special agent/commissioner/mission is filed in the
        // Special Agents series, not the diplomatic or consular ones its dateline would
        // otherwise suggest. Direction decides the series: Department outbound is an
        // instruction TO the agent; anything else is the agent's despatch home.
        if ["special agent", "special commissioner", "special mission"]
            .contains(where: { headerL.contains($0) || dl.contains($0) }) {
            if dl.contains("department of state") {
                return [CentralFilesClassification(
                    category: .specialAgentsInstructions, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.specialAgentInstruction",
                                      defaultValue: "Department of State outbound to a special agent — an instruction in the Special Missions volumes. Matched by the document's date."))]
            }
            return [CentralFilesClassification(
                category: .specialAgentsDespatches, geoKeys: [], confidence: .medium,
                rationale: String(localized: "centralFiles.rationale.specialAgentDespatch",
                                  defaultValue: "From a special agent of the Department — filed with the agent's mission in Despatches from Special Agents. Matched by the document's date."))]
        }

        // Another executive department or the President's office writing to State (W-8
        // remainder): filed in Letters Received (the "Miscellaneous Letters"). The dateline
        // is the SENDER's office, so direction is not in doubt.
        if containsAny(dl, ["war department", "navy department", "treasury department",
                            "post office department", "department of justice",
                            "department of the interior", "department of agriculture",
                            "department of commerce", "executive mansion", "white house"]) {
            return [CentralFilesClassification(
                category: .lettersReceived, geoKeys: [], confidence: .high,
                rationale: String(localized: "centralFiles.rationale.letterReceived",
                                  defaultValue: "Dateline is another executive department — a letter received by the Department of State, filed chronologically. Matched by the document's date."))]
        }

        // A FOREIGN consulate in the United States → a note from a foreign consul to the
        // Department (W-8). Checked before the U.S.-consulate branch: these datelines also
        // contain "consulate", and the old path extracted their U.S. city as a "post" no
        // despatch series serves — a dead-end candidate.
        if isForeignConsulateDateline(dl) {
            return [CentralFilesClassification(
                category: .notesFromForeignConsuls, geoKeys: [], confidence: .high,
                rationale: String(localized: "centralFiles.rationale.noteFromConsul",
                                  defaultValue: "Dateline is a foreign consulate in the United States — a note from the foreign consul to the Department. The series is a single chronological run, matched by the document's date."))]
        }

        // Consular despatch (Phase 3) — its geography is the post CITY taken from the
        // dateline ("Consulate-General…, Havana") rather than the FRUS chapter country.
        // No city → can't resolve.
        if dl.contains("consulate") || dl.contains("consular") {
            guard let city = consularPostKey(fromDateline: dateline) else { return [] }
            return [CentralFilesClassification(
                category: .consularDespatches, geoKeys: [city], confidence: .high,
                rationale: String(localized: "centralFiles.rationale.consular",
                                  defaultValue: "Dateline is a U.S. consulate abroad — a consular despatch to the Department."))]
        }

        // Diplomatic series — geography is the FRUS chapter country.
        let geoKeys = chapterCountry.map { GeoKeyNormalizer.keys(from: $0) } ?? []

        // A U.S. diplomatic mission abroad → a despatch home.
        if containsAny(dl, ["legation of the united states", "embassy of the united states",
                            "american legation", "american embassy",
                            "united states legation", "u. s. legation", "u.s. legation"]) {
            guard !geoKeys.isEmpty else { return [] }
            return [CentralFilesClassification(
                category: .despatches, geoKeys: geoKeys, confidence: .high,
                rationale: String(localized: "centralFiles.rationale.despatch",
                                  defaultValue: "Dateline is a U.S. mission abroad — a despatch to the Department."))]
        }

        // Department of State outbound → an instruction or a note to a foreign mission —
        // and, when the HEADER names a consul, the consular twin of that same ambiguity
        // (W-8): to the U.S. consul abroad it is a Consular Instruction; to the foreign
        // consul in the U.S. it is a note. Both consular series are chronological runs, so
        // their candidates carry no geography and resolve by date.
        if dl.contains("department of state") {
            var candidates: [CentralFilesClassification] = []
            if !geoKeys.isEmpty {
                candidates.append(CentralFilesClassification(
                    category: .instructions, geoKeys: geoKeys, confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.instruction",
                                      defaultValue: "Department of State outbound; if the addressee is the U.S. minister abroad, it is an instruction.")))
                candidates.append(CentralFilesClassification(
                    category: .notesTo, geoKeys: geoKeys, confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.noteTo",
                                      defaultValue: "Department of State outbound; if the addressee is the foreign minister in Washington, it is a note to the legation.")))
            }
            if headerL.contains("consul") {
                candidates.append(CentralFilesClassification(
                    category: .consularInstructions, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.consularInstruction",
                                      defaultValue: "Department of State outbound to a consul; if the addressee is a U.S. consul abroad, it is a consular instruction. Matched by the document's date.")))
                candidates.append(CentralFilesClassification(
                    category: .notesToForeignConsuls, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.noteToConsul",
                                      defaultValue: "Department of State outbound to a consul; if the addressee is a foreign consul in the United States, it is a note to the consul. Matched by the document's date.")))
            }
            // Department outbound ADDRESSED to a domestic cabinet office (W-8 remainder):
            // a Domestic Letter. The office must sit AFTER the header's " to " — the same
            // phrase BEFORE it is the sender, which is the Letters Received direction and
            // carries its own dateline cue above.
            if domesticAddressee(inHeader: headerL) {
                candidates.append(CentralFilesClassification(
                    category: .domesticLetters, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.domesticLetter",
                                      defaultValue: "Department of State outbound to a domestic official — filed chronologically in Domestic Letters. Matched by the document's date.")))
            }
            return candidates
        }

        guard !geoKeys.isEmpty else { return [] }

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

    /// Whether a lowercased dateline names a FOREIGN consulate in the United States (W-8).
    ///
    /// Two conservative cues, both measured against real dateline forms:
    /// - `consulate[-general] of {X}` where `{X}` is not the United States
    ///   ("Consulate-General of Spain, New York").
    /// - `{demonym} consulate` where the demonym is not American/U.S.
    ///   ("Spanish Consulate-General, Washington").
    /// A bare "Consulate-General, Havana" carries neither cue and stays on the
    /// U.S.-consulate-abroad path — exactly the pre-W-8 behavior.
    static func isForeignConsulateDateline(_ dl: String) -> Bool {
        guard dl.contains("consul") else { return false }
        // Any U.S. marker anywhere in the dateline means a U.S. consulate abroad — checked
        // FIRST, so no per-cue word list has to enumerate the ways "United States" tokenizes
        // ("United States Consulate" would otherwise read demonym "states").
        if dl.contains("united states") || dl.contains("american")
            || dl.contains("u.s.") || dl.contains("u. s.") {
            return false
        }
        // "Consulate[-General] of {X}" — with U.S. markers excluded above, any named X is
        // a foreign state ("Consulate-General of Spain, New York").
        if dl.range(of: #"consulate(?:[- ]general)?\s+of\s+\w"#,
                    options: .regularExpression) != nil {
            return true
        }
        // "{Demonym} Consulate" — a word directly before "consulate" that is not an
        // article ("Spanish Consulate-General, Washington"). A bare "Consulate-General,
        // Havana" has no preceding word and stays on the U.S.-consulate path.
        if let r = dl.range(of: #"(\w+)\s+consulate"#, options: .regularExpression) {
            let demonym = String(dl[r]).components(separatedBy: " ").first ?? ""
            return demonym != "the"
        }
        return false
    }

    /// Whether a lowercased header addresses a DOMESTIC cabinet office (W-8 remainder) —
    /// the office phrase must appear AFTER the header's " to " (the addressee half);
    /// before it, the office is the sender, which is the Letters Received direction.
    static func domesticAddressee(inHeader headerL: String) -> Bool {
        guard let toRange = headerL.range(of: " to ") else { return false }
        let addressee = String(headerL[toRange.upperBound...])
        return containsAny(addressee, ["secretary of war", "secretary of the navy",
                                       "secretary of the treasury",
                                       "secretary of the interior",
                                       "secretary of agriculture", "secretary of commerce",
                                       "attorney general", "attorney-general",
                                       "postmaster general", "postmaster-general"])
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
