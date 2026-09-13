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
enum CentralFilesConfidence: Sendable, CaseIterable {
    /// The dateline unambiguously identifies the series (e.g. a U.S. legation abroad), or — for a
    /// Department letter — the addressee rule matched the header's addressee to the one U.S. chief of
    /// mission the register places at that post on that date (1.4).
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
/// The Instruction vs. Note-to distinction cannot be read from a Washington dateline alone (both are
/// Department of State outbound; the difference is whether the addressee is a U.S. minister abroad
/// or a foreign minister in Washington). `classify` returns both, at `medium` confidence. The HEADER
/// names the addressee in all but 55 of 9,851 such documents, and `documentHomes` settles the pair
/// after the roll lookup through `applyAddresseeRule`: when the register places exactly one U.S.
/// chief of mission of that name at the chapter's post on the dateline's date, the Instructions home
/// becomes `high` and the Notes-to home is dropped. `classify` itself is unchanged by that rule.
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
///   1.3 — 2026-09-13: a chapter of correspondence with a FOREIGN legation in Washington
///         (`British legation.`, `Correspondence with the legation of Mexico at Washington.`) now
///         reads as that country, so it is also read for what it says about direction. The
///         Department's letter there is a note TO the legation, never an instruction; a letter from
///         Washington is a note FROM it; and nothing else in the chapter falls back to a U.S.
///         mission's despatch, because the chapter names the legation's country, not a mission's.
///         Measured before the change: the documents in these chapters are Lord Lyons's notes and
///         the Department's replies, and a title-only fix would have offered every reply as an
///         instruction to Great Britain. A letter the Secretary of State signs is the Department's
///         whatever its dateline says. Measured, 15 of these chapters' letters had read as notes FROM
///         the legation: 6 under a bare `Washington` or the Secretary's own address, and 9 under a
///         damaged or variant Department dateline (`Dapartment of State`, `State Department`). A
///         letter from the President is refused, being neither note.
///   1.4 — 2026-09-13: the addressee rule (`applyAddresseeRule`, `ChiefsOfMissionRoster`,
///         `addressee(inHeader:)`). A Department letter whose header names the one U.S. chief of
///         mission the Office of the Historian's register places at the chapter's post on the
///         dateline's date is an instruction: its Instructions home becomes "Likely" and the Notes-to
///         home is dropped, but a document's only reel is never removed. Also the evaluation both
///         Source Explorer views now share (`gate`, `documentHomes`, `enclosureRolls`, `evaluate`), its
///         outcome states, the direction-aware serial label, and `documentYear(fromDateline:)`.
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
                                      defaultValue: "Department of State outbound to a special agent — an instruction in the Special Missions volumes. Matched by the document’s date."))]
            }
            return [CentralFilesClassification(
                category: .specialAgentsDespatches, geoKeys: [], confidence: .medium,
                rationale: String(localized: "centralFiles.rationale.specialAgentDespatch",
                                  defaultValue: "From a special agent of the Department — filed with the agent’s mission in Despatches from Special Agents. Matched by the document’s date."))]
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
                                  defaultValue: "Dateline is another executive department — a letter received by the Department of State, filed chronologically. Matched by the document’s date."))]
        }

        // A FOREIGN consulate in the United States → a note from a foreign consul to the
        // Department (W-8). Checked before the U.S.-consulate branch: these datelines also
        // contain "consulate", and the old path extracted their U.S. city as a "post" no
        // despatch series serves — a dead-end candidate.
        if isForeignConsulateDateline(dl) {
            return [CentralFilesClassification(
                category: .notesFromForeignConsuls, geoKeys: [], confidence: .high,
                rationale: String(localized: "centralFiles.rationale.noteFromConsul",
                                  defaultValue: "Dateline is a foreign consulate in the United States — a note from the foreign consul to the Department. The series is a single chronological run, matched by the document’s date."))]
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
        // A chapter of correspondence WITH a foreign legation in Washington (1.3). Its country is
        // the legation's, so every branch below that would place a document with a U.S. mission
        // abroad refuses instead.
        let legationChapter = chapterCountry.map {
            GeoKeyNormalizer.foreignLegationName(inChapterTitle: $0) != nil
        } ?? false
        // In those chapters the header's sender also settles direction (1.3): a letter the Secretary of
        // State signs is the Department's, whatever its dateline says — a bare "Washington", Blaine's
        // "17 Madison Place", an OCR-damaged "Dapartment of State". Scoped to foreign-legation chapters,
        // because elsewhere the same surnames sign despatches home: Foster from Mexico, Adee from
        // Madrid, Root from Santiago.
        let departmentOutbound = dl.contains("department of state")
            || (legationChapter && secretaryOfStateSender(inHeader: headerL))

        // A U.S. diplomatic mission abroad → a despatch home.
        if containsAny(dl, ["legation of the united states", "embassy of the united states",
                            "american legation", "american embassy",
                            "united states legation", "u. s. legation", "u.s. legation"]) {
            guard !geoKeys.isEmpty, !legationChapter else { return [] }
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
        if departmentOutbound {
            var candidates: [CentralFilesClassification] = []
            if !geoKeys.isEmpty, legationChapter {
                // The chapter settles what the dateline cannot: the addressee is the legation.
                candidates.append(CentralFilesClassification(
                    category: .notesTo, geoKeys: geoKeys, confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.legationNoteTo",
                                      defaultValue: "Department of State outbound, printed in FRUS’s correspondence with the foreign legation in Washington — a note to the legation.")))
            } else if !geoKeys.isEmpty {
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
                                      defaultValue: "Department of State outbound to a consul; if the addressee is a U.S. consul abroad, it is a consular instruction. Matched by the document’s date.")))
                candidates.append(CentralFilesClassification(
                    category: .notesToForeignConsuls, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.noteToConsul",
                                      defaultValue: "Department of State outbound to a consul; if the addressee is a foreign consul in the United States, it is a note to the consul. Matched by the document’s date.")))
            }
            // Department outbound ADDRESSED to a domestic cabinet office (W-8 remainder):
            // a Domestic Letter. The office must sit AFTER the header's " to " — the same
            // phrase BEFORE it is the sender, which is the Letters Received direction and
            // carries its own dateline cue above.
            if domesticAddressee(inHeader: headerL) {
                candidates.append(CentralFilesClassification(
                    category: .domesticLetters, geoKeys: [], confidence: .medium,
                    rationale: String(localized: "centralFiles.rationale.domesticLetter",
                                      defaultValue: "Department of State outbound to a domestic official — filed chronologically in Domestic Letters. Matched by the document’s date.")))
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

        // In a foreign-legation chapter (1.3), a letter from Washington or from the legation
        // wherever it wrote is a note FROM it — most of Lord Lyons's notes are datelined
        // "Washington, <date>" and nothing more. Anything else refuses: the despatch fallback below
        // would name a U.S. mission in the legation's country, which the chapter does not say.
        if legationChapter {
            // A letter from the President to a sovereign passes through the legation but is neither
            // note; it is filed with the ceremonial letters, which the index does not carry.
            guard !presidentialSender(inHeader: headerL),
                  dl.contains("washington") || containsAny(dl, ["legation", "embassy"]) else { return [] }
            return [CentralFilesClassification(
                category: .notesFrom, geoKeys: geoKeys, confidence: .medium,
                rationale: String(localized: "centralFiles.rationale.legationNoteFrom",
                                  defaultValue: "Printed in FRUS’s correspondence with the foreign legation in Washington, and not from the Department — a note from the legation."))]
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

    /// Whether a lower-cased header's SENDER — the part before ` to ` — is the Secretary of State, by
    /// office or by the surname of a Secretary or acting Secretary of 1861–1905 (1.3). Read only in a
    /// foreign-legation chapter: elsewhere the same surnames sign despatches home (`Mr. Foster to
    /// Mr. Fish`, from Mexico). `Secretary of State for …` is a foreign minister's style and is refused.
    static func secretaryOfStateSender(inHeader headerL: String) -> Bool {
        guard let toRange = headerL.range(of: " to ") else { return false }
        let sender = String(headerL[..<toRange.lowerBound])
        return sender.range(
            of: #"\b(?:secretary of state(?! for)|mr\.? (?:[a-z]\. ?)*(?:seward|fish|evarts|blaine|frelinghuysen|bayard|foster|gresham|olney|sherman|day|hay|root|hunter|adee|wharton|uhl))\b"#,
            options: .regularExpression) != nil
    }

    /// Whether a lower-cased header's SENDER is the President (`The President to King Humbert .`,
    /// `No. 495. The President of the United States to the President of Mexico .`) (1.3).
    static func presidentialSender(inHeader headerL: String) -> Bool {
        guard let toRange = headerL.range(of: " to ") else { return false }
        return headerL[..<toRange.lowerBound].range(
            of: #"^\s*(?:no\. ?\d+\. )?the president\b"#, options: .regularExpression) != nil
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

// MARK: - Document year

extension CentralFilesClassifier {

    /// The year of a dateline: the strict `Month D, YYYY` parse first, then a loose 18xx–2029 scan.
    ///
    /// The body of `DocumentView.extractYear(from:)`, moved here because that one is a static on a
    /// SwiftUI view and therefore main-actor isolated, while Source Explorer derives a year from an
    /// index-hydrated dateline inside `evaluate`, which is not. The strict parse wins so a stray
    /// 4-digit token (a telegram number) cannot hijack the year; the loose scan catches bare-year
    /// datelines. `CentralFilesClassifierTests.documentYearParity` pins the two copies together.
    static func documentYear(fromDateline dateline: String?) -> Int? {
        guard let dl = dateline else { return nil }
        if let iso = datelineDateISO(from: dl), let year = Int(iso.prefix(4)) {
            return year
        }
        let pattern = #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dl, range: NSRange(dl.startIndex..., in: dl)),
              let range = Range(match.range(at: 1), in: dl)
        else { return nil }
        return Int(dl[range])
    }
}

// MARK: - CentralFilesAddressee (1.4)

/// Who a Department letter's printed header says it went to, as the addressee rule reads it.
///
/// **The style is not a nationality.** `Mr.` is how FRUS styles the U.S. minister and, just as often,
/// a foreign minister in Washington (`Mr. Romero`, Mexico's, heads 137 documents). The grammar only
/// sorts headers into the ones a register match may decide and the ones it may not; the decision is
/// `ChiefsOfMissionRoster.decide`'s, and a foreign title refuses outright.
struct CentralFilesAddressee: Sendable, Equatable {

    /// How the addressee is styled.
    enum Style: Sendable, Equatable {
        /// A style the Department uses for its own officers (`Mr.`, `General`, `Minister`).
        case usStyle
        /// A foreign title (`Lord`, `Baron`, `Señor`, `M.`), or a `Bey`/`Pasha`/`Effendi`/`Khan` name.
        case foreign
        /// No honorific at all (`Mavroyeni Bey` aside, a bare name).
        case none
        /// A description rather than a name (`the Japanese Minister`). `foreignEnvoy` is `true` when it
        /// names a foreign minister, legation or government, and never for a United States or
        /// American one (`the United States ambassadors at London`).
        case descriptive(foreignEnvoy: Bool)
        /// More than one addressee (`Messrs. …`, `Mr. A and Mr. B`).
        case multiple
    }

    /// How the addressee is styled.
    let style: Style
    /// The addressee's name, folded to lower-case letters, with initials and `Jr.`/`Sr.` removed
    /// (`Mr. De Long` → `["de", "long"]`). Empty for a descriptive or multiple addressee.
    let names: [String]
    /// Whether the SENDER — the part before " to " — carries a foreign title (`Señor Benitez`).
    /// `M.` is excepted, being the scans' OCR of `Mr.` (`M. Seward`).
    let senderIsForeign: Bool
}

extension CentralFilesClassifier {

    /// Honorifics the Department uses for its own officers. Measured over the two-reel set; the
    /// undotted forms are how OCR and FRUS's own typesetting print them.
    static let usStyleHonorifics: Set<String> = [
        "mr", "mr.", "mrs", "mrs.", "hon", "hon.", "honorable", "general", "gen", "gen.",
        "colonel", "col", "col.", "judge", "governor", "ex-governor", "dr", "dr.", "doctor",
        "admiral", "commodore", "captain", "capt", "capt.", "major", "lieutenant", "lieut",
        "lieut.", "commander", "professor", "senator", "minister", "ambassador", "chargé", "charge",
    ]

    /// Foreign titles. A missing entry turns straight into a false "Likely", so each is tested.
    static let foreignHonorifics: Set<String> = [
        "sir", "lord", "lady", "baron", "baroness", "count", "count.", "countess", "viscount", "vicomte",
        "marquis", "marquis.", "marquess", "duke", "prince", "princess", "chevalier", "señor", "senor",
        "señores", "senhor", "señhor", "signor", "signore", "señora", "m.", "mm.", "mons.", "monsieur",
        "herr", "don", "dom", "doña", "cardinal", "jonkheer", "ritter", "comte", "monseigneur",
        "excellency", "his",
    ]

    /// Name suffixes that mark a foreign envoy wherever they appear (`Mavroyeni Bey`, `Tevfik Pasha`).
    static let foreignNameSuffixes: Set<String> = ["bey", "pasha", "effendi", "khan"]

    /// OCR forms of `Mr.` measured in the two-reel set (`Mr` 9, `Air.` 1). The third, `Mr,` (1), never
    /// reaches this table: the addressee is cut at its first comma, so `addressee(inHeader:)` reads a
    /// leading `Mr, ` as `Mr. ` before it cuts.
    static let ocrMisterForms: Set<String> = ["air.", "mr"]

    /// Reads the addressee (and whether the sender is foreign) from a document header, or `nil` when
    /// the header names no addressee (no ` to `: `[Untitled]`, memoranda, circulars).
    ///
    /// The grammar, in order: strip a leading `No. N.` serial; split at the first ` to `; read a leading
    /// OCR `Mr,` as `Mr.`, because the next step would cut at its comma; cut the addressee at `;`, `(`,
    /// `,`, ` through ` or ` [` (`Mr. Seward to Mr. Adams; (same to Mr. Dayton …)` is Adams); `and`, `&`
    /// or a leading `Messrs.` is several people; an OCR `Air.`/`Mr` is `Mr.`; a `the …` addressee is a
    /// description; then the honorific tables. Names are folded and
    /// lose their initials and `Jr.`.
    static func addressee(inHeader header: String) -> CentralFilesAddressee? {
        var h = header.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let r = h.range(of: #"^\[?No\.?\s*[\dIVXL]+[½a-z]?\s*\.?\]?\s*"#, options: .regularExpression) {
            h = String(h[r.upperBound...])
        }
        guard let toRange = h.range(of: " to ") else { return nil }
        let sender = String(h[..<toRange.lowerBound])
        var addressee = String(h[toRange.upperBound...])
        if let ocr = addressee.range(of: #"^Mr,\s+"#, options: .regularExpression) {
            addressee.replaceSubrange(ocr, with: "Mr. ")
        }
        if let cut = addressee.range(of: #"\s*[;(,]|\s+through\s+|\s+\["#, options: .regularExpression) {
            addressee = String(addressee[..<cut.lowerBound])
        }
        addressee = addressee.trimmingCharacters(in: CharacterSet(charactersIn: " .:"))
        let senderIsForeign = sender.split(separator: " ").first
            .map { isForeignHonorific(String($0), exceptingOCRMister: true) } ?? false

        var tokens = addressee.split(separator: " ").map(String.init)
        guard let first = tokens.first else {
            return CentralFilesAddressee(style: .none, names: [], senderIsForeign: senderIsForeign)
        }
        let lowered = addressee.lowercased()
        let bareTokens = tokens.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        if bareTokens.contains("and") || addressee.contains("&")
            || lowered.hasPrefix("messrs") || lowered.hasPrefix("señores") || lowered.hasPrefix("senores") {
            return CentralFilesAddressee(style: .multiple, names: [], senderIsForeign: senderIsForeign)
        }
        if ocrMisterForms.contains(first.lowercased()) { tokens[0] = "Mr." }
        let head = normalizedToken(tokens[0])

        if head == "the" {
            let excludesUnitedStates = lowered.range(
                of: #"^the (?:united states|american|u\. ?s\.)\b"#, options: .regularExpression) != nil
            let namesEnvoy = lowered.range(
                of: #"^the (?:[\p{L}’'-]+ )+(?:minister|ambassador|chargé|charge|legation|embassy|envoy|consul|government|secretary)"#,
                options: .regularExpression) != nil
            let titled = tokens.count > 1 && isForeignHonorific(tokens[1], exceptingOCRMister: false)
            return CentralFilesAddressee(style: .descriptive(foreignEnvoy: !excludesUnitedStates && (namesEnvoy || titled)),
                                         names: [], senderIsForeign: senderIsForeign)
        }

        var style: CentralFilesAddressee.Style
        var rest: [String]
        if isForeignHonorific(tokens[0], exceptingOCRMister: false) {
            style = .foreign
            rest = Array(tokens.dropFirst())
        } else if usStyleHonorifics.contains(head) {
            style = .usStyle
            rest = Array(tokens.dropFirst())
        } else {
            style = .none
            rest = tokens
        }
        if rest.contains(where: { foreignNameSuffixes.contains(foldName($0)) }) { style = .foreign }
        let names = rest
            .filter { $0.range(of: #"^[A-Z]\.?$"#, options: .regularExpression) == nil }
            .filter { !["jr", "sr", "jun", "junior"].contains(foldName($0)) }
            .flatMap { foldName($0).split(separator: " ").map(String.init) }
        return CentralFilesAddressee(style: style, names: names, senderIsForeign: senderIsForeign)
    }

    /// Whether a token is a foreign title, with or without its trailing dot. `M.` and `MM.` count only
    /// in their dotted form, and `exceptingOCRMister` drops `M.` altogether — the sender check's
    /// exception, because `M. Seward` is an OCR'd `Mr. Seward`.
    static func isForeignHonorific(_ token: String, exceptingOCRMister: Bool) -> Bool {
        let t = normalizedToken(token)
        if exceptingOCRMister, t == "m." { return false }
        if foreignHonorifics.contains(t) { return true }
        let undotted = t.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return foreignHonorifics.contains { $0 != "m." && $0 != "mm." && $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == undotted }
    }

    /// A token lower-cased and composed, so a decomposed `é` from the text layer matches the table.
    private static func normalizedToken(_ token: String) -> String {
        token.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// A name folded for matching: diacritics and case removed, apostrophes dropped, a hyphen and any
    /// other non-letter read as a space (`D’Avezac` → `davezac`, `Pérez-Gómez` → `perez gomez`).
    static func foldName(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
        let letters: ClosedRange<Character> = "a"..."z"
        let spaced = String(folded.map { letters.contains($0) ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }
}

// MARK: - ChiefsOfMissionRoster (1.4)

/// The U.S. chiefs of mission the Office of the Historian's register records for 1861–1906, keyed by
/// the chapter geo keys the classifier emits — the one fact that tells a Department letter to the U.S.
/// minister (an instruction) from one to a foreign minister in Washington (a note).
///
/// Built from `POCOMIndex.chiefs(territoryId:)` and nothing else. A territory id's keys are
/// `GeoKeyNormalizer.keys(from:)` of its words, plus `territoryKeyOverrides` for the places FRUS
/// names by a historical title the normalizer does not reach from POCOM's modern id.
struct ChiefsOfMissionRoster: Sendable {

    /// Chapter geo key → the chiefs whose territory reaches it, in territory then register order.
    let chiefsByGeoKey: [String: [POCOMChiefOfMission]]

    /// Days after the register's last day that a letter still reaches a chief (owner decision D6).
    ///
    /// Measured: 0 → 90 days adds 26 decisions, every one the same chief shortly after the recorded end
    /// (Seward to Dayton three days after Dayton died at post). None is granted BEFORE the first day:
    /// the 19 that would add are mostly letters to Bigelow while he headed the Paris legation before
    /// his appointment, and the register does not make him its chief then.
    ///
    /// **The bundled table is cut to this.** The generator admits rows whose last day falls up to 90 days
    /// before 1861 (`POCOMIndexBuilder.chiefsWindowEarliestLastDay`, `1860-10-03`), so a letter of early
    /// 1861 still sees every chief it could reach and the rule's one-person count is complete. Raising
    /// this past 90 needs a regeneration with a wider window; `POCOMIndexTests` pins the pair.
    static let graceDaysAfterLastDay = 90

    /// Territory ids FRUS names by a different chapter title (the plan's measured list). Without
    /// these, 202 decisions are lost. There is deliberately no `germany` → `prussia` entry.
    static let territoryKeyOverrides: [String: [String]] = [
        "holy-see": ["papal states"],
        "iran": ["persia"],
        "thailand": ["siam"],
        "guatemala": ["central america"],
        "costa-rica": ["central america"],
        "honduras": ["central america"],
        "nicaragua": ["central america"],
        "el-salvador": ["central america"],
    ]

    /// The roster read from the bundled `pocom-index.json`. Empty when the file is absent, or is a
    /// version-1 file with no `chiefs` table — in which case the rule decides nothing.
    static let bundled = ChiefsOfMissionRoster(index: POCOMIndexStore.shared)

    /// A roster with nobody in it: the rule decides nothing.
    static let empty = ChiefsOfMissionRoster(chiefsByTerritory: [:])

    /// Keys a set of chiefs, grouped by POCOM territory id, under the chapter geo keys.
    init(chiefsByTerritory: [String: [POCOMChiefOfMission]]) {
        var byKey: [String: [POCOMChiefOfMission]] = [:]
        for territoryId in chiefsByTerritory.keys.sorted() {
            let chiefs = chiefsByTerritory[territoryId] ?? []
            for key in Self.geoKeys(forTerritoryId: territoryId) {
                byKey[key, default: []].append(contentsOf: chiefs)
            }
        }
        chiefsByGeoKey = byKey
    }

    /// The roster a POCOM index's `chiefs` table describes.
    init(index: POCOMIndex?) {
        var byTerritory: [String: [POCOMChiefOfMission]] = [:]
        for territoryId in index?.chiefTerritoryIds ?? [] {
            byTerritory[territoryId] = index?.chiefs(territoryId: territoryId) ?? []
        }
        self.init(chiefsByTerritory: byTerritory)
    }

    /// The chapter geo keys a POCOM territory id reaches: its words through `GeoKeyNormalizer`, then
    /// any override (`iran` → `iran`, `persia`; `united-kingdom` → `great britain`).
    static func geoKeys(forTerritoryId territoryId: String) -> [String] {
        var keys = GeoKeyNormalizer.keys(from: territoryId.replacingOccurrences(of: "-", with: " "))
        for extra in territoryKeyOverrides[territoryId] ?? [] where !keys.contains(extra) {
            keys.append(extra)
        }
        return keys
    }

    /// The chief of mission a Department letter was written to, or `nil` when the rule cannot say.
    ///
    /// Returns a chief only when ALL of these hold:
    /// 1. the addressee is U.S.-styled and has a name;
    /// 2. the sender carries no foreign title (`M.` excepted);
    /// 3. the dateline is not a foreign ministry's `Department of State for/and Foreign …`;
    /// 4. the dateline gives a date (the dateline date only — never the index date, D7);
    /// 5. exactly ONE register person across the chapter's geo keys both matches the name and covers
    ///    the date, from their first day to `graceDaysAfterLastDay` after their last. A chief with no
    ///    last day never matches. Persons are counted, not chiefs at post: two chiefs of different
    ///    surnames during a turnover still decide, and two people sharing a surname (Thomas and
    ///    William H. Corwin, Mexico, April 1864) refuse.
    ///
    /// A missing match is not evidence of a note: the caller leaves both readings as they were.
    func decide(header: String, dateline: String, geoKeys: [String]) -> POCOMChiefOfMission? {
        guard let addressee = CentralFilesClassifier.addressee(inHeader: header),
              addressee.style == .usStyle, !addressee.names.isEmpty else { return nil }
        guard !addressee.senderIsForeign else { return nil }
        guard dateline.range(of: #"department of state\s+(?:for|and)\s+foreign"#,
                             options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        guard let dateISO = CentralFilesClassifier.datelineDateISO(from: dateline),
              let day = Self.dayNumber(iso: dateISO) else { return nil }

        var bySlug: [String: [POCOMChiefOfMission]] = [:]
        var slugOrder: [String] = []
        for key in geoKeys {
            for chief in chiefsByGeoKey[key] ?? [] where Self.covers(chief, day: day)
                && Self.nameMatches(addressee.names, chief: chief) {
                if bySlug[chief.slug] == nil { slugOrder.append(chief.slug) }
                bySlug[chief.slug, default: []].append(chief)
            }
        }
        guard slugOrder.count == 1, let rows = bySlug[slugOrder[0]] else { return nil }
        // One person, possibly several rows (Washburn was commissioner, then minister resident): name
        // the row the date falls inside rather than a grace period, and of those the latest appointed.
        return rows.max { a, b in
            let aInside = Self.dayNumber(iso: a.lastDayISO ?? "").map { day <= $0 } ?? false
            let bInside = Self.dayNumber(iso: b.lastDayISO ?? "").map { day <= $0 } ?? false
            if aInside != bInside { return !aInside }
            return a.firstDayISO < b.firstDayISO
        }
    }

    /// Whether `day` falls from the chief's first day through `graceDaysAfterLastDay` past the last.
    static func covers(_ chief: POCOMChiefOfMission, day: Int) -> Bool {
        guard let first = dayNumber(iso: chief.firstDayISO),
              let lastISO = chief.lastDayISO, let last = dayNumber(iso: lastISO) else { return false }
        return first <= day && day <= last + graceDaysAfterLastDay
    }

    /// Whether folded addressee names are the chief: the chief's surname equals the trailing tokens,
    /// and every leading token is one of the forenames (`Mr. Dayton`, `Mr. W. L. Dayton`, `Mr.
    /// William Dayton`). A surname with a parenthesised variant (`Davezac (D’Avezac)`) matches either.
    static func nameMatches(_ names: [String], chief: POCOMChiefOfMission) -> Bool {
        let forenames = Set(CentralFilesClassifier.foldName(chief.forename).split(separator: " ").map(String.init))
        var surnames = [chief.surname]
        if let open = chief.surname.firstIndex(of: "("), let close = chief.surname.lastIndex(of: ")"), open < close {
            surnames = [String(chief.surname[..<open]),
                        String(chief.surname[chief.surname.index(after: open)..<close])]
        }
        for surname in surnames {
            let tokens = CentralFilesClassifier.foldName(surname).split(separator: " ").map(String.init)
            guard !tokens.isEmpty, names.count >= tokens.count,
                  Array(names.suffix(tokens.count)) == tokens else { continue }
            if names.dropLast(tokens.count).allSatisfy(forenames.contains) { return true }
        }
        return false
    }

    /// Days since 1970-01-01 for a `yyyy-MM-dd` string, or `nil` when it does not read as one.
    ///
    /// Arithmetic rather than `Calendar`, so the rule has no locale or time zone to disagree about.
    static func dayNumber(iso: String) -> Int? {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let y0 = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}

// MARK: - CentralFilesResolution

/// One archival home Source Explorer shows for a pre-1906 document: a classification, the rolls it
/// resolves to, whose dateline produced it, and — when the addressee rule promoted it — the chief of
/// mission who decided it.
///
/// Shared by both Source Explorer views (each keeps a `CountrySeriesResolution` typealias), because
/// the two are hand-maintained twins and a type written twice is two places to drift.
struct CentralFilesResolution: Identifiable, Sendable, Equatable {
    /// The series and country the document placed in.
    let classification: CentralFilesClassification
    /// The digitized rolls that series resolves to for this document's date.
    let rolls: [CountryRoll]
    /// Whose dateline produced this home — the document's, or one enclosure's (B-5).
    var part: CentralFilesDocumentPart = .document
    /// The chief of mission the addressee rule matched when it promoted this home to "Likely", or
    /// `nil`. A surface badges the promoted row with the register it came from.
    var chiefOfMission: POCOMChiefOfMission? = nil
    /// Keyed on the part as well as the category: a document and its enclosure can resolve to the
    /// SAME series, and an id of the category alone silently drops one of the two rows.
    var id: String { "\(part.key)|\(classification.category.rawValue)" }
}

// MARK: - CentralFilesSerialLabel (fix 4)

/// What to call the serial FRUS prints above a pre-1906 document, from the direction of the home
/// Source Explorer leads with.
///
/// A Department instruction carries the Department's number for it, a despatch the post's, and a note
/// its sender's. Labelling every serial "Despatch No." — as the views did — named the wrong side for
/// 7,392 Department-outbound documents.
///
/// **It claims no more than the section does.** A Department letter the addressee rule did not decide lists
/// Notes to Foreign Missions beside its Instructions reel, both at "Possible", and it may well be a note:
/// `Mr. Olney to Baron Thielmann.` (frus1895p1/d458, No. 42) went to the German ambassador. The number is the
/// Department's either way, so such a pair reads plain "No.", and "Instruction No." only once the rule names
/// the U.S. chief of mission and drops the notes reel.
enum CentralFilesSerialLabel: Sendable, Equatable {
    /// An instruction from the Department (Diplomatic, Consular or Special Agents Instructions).
    case instruction
    /// A despatch to the Department (Diplomatic, Consular or Special Agents Despatches).
    case despatch
    /// A note or a letter, where "Instruction" and "Despatch" would both be wrong.
    case neutral

    /// The label for a set of homes: the first DOCUMENT home's series, after the addressee rule, and
    /// never an enclosure's, which can run the other way. Only enclosure homes → `.neutral`. An instruction
    /// series listed beside its own notes twin (Notes to Foreign Missions; Notes to Foreign Consuls for
    /// Consular Instructions) is a pair the rule did not decide → `.neutral`.
    init(homes: [CentralFilesResolution]) {
        guard let lead = homes.first(where: { !$0.part.isEnclosure }) else {
            self = .neutral
            return
        }
        switch lead.classification.category {
        case .instructions, .consularInstructions, .specialAgentsInstructions:
            let twin: CentralFilesSeriesCategory? = switch lead.classification.category {
            case .instructions: .notesTo
            case .consularInstructions: .notesToForeignConsuls
            default: nil
            }
            let undecidedPair = homes.contains { !$0.part.isEnclosure && $0.classification.category == twin }
            self = undecidedPair ? .neutral : .instruction
        case .despatches, .consularDespatches, .specialAgentsDespatches:
            self = .despatch
        case .notesFrom, .notesTo, .notesToForeignConsuls, .notesFromForeignConsuls,
             .domesticLetters, .lettersReceived:
            self = .neutral
        }
    }

    /// The row's title: `Instruction No. 428`, `Despatch No. 74`, or `No. 12`.
    func title(serial: String) -> String {
        switch self {
        case .instruction:
            return String(format: String(localized: "source.explorer.countrySeries.serial.instruction %@",
                                         defaultValue: "Instruction No. %@"), serial)
        case .despatch:
            return String(format: String(localized: "source.explorer.countrySeries.serial %@",
                                         defaultValue: "Despatch No. %@"), serial)
        case .neutral:
            return String(format: String(localized: "source.explorer.countrySeries.serial.neutral %@",
                                         defaultValue: "No. %@"), serial)
        }
    }

    /// The caption under the title, saying whose number it is and that it is not a NARA identifier.
    var caption: String {
        switch self {
        case .instruction:
            return String(localized: "source.explorer.countrySeries.serial.instruction.caption",
                          defaultValue: "FRUS prints this number above the document — the Department’s own number for its instruction to the post. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.")
        case .despatch:
            return String(localized: "source.explorer.countrySeries.serial.caption",
                          defaultValue: "FRUS prints this number above the document — the post’s own serial for it. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.")
        case .neutral:
            return String(localized: "source.explorer.countrySeries.serial.neutral.caption",
                          defaultValue: "FRUS prints this number above the document — its sender’s own serial for it. The rolls below are browsed by eye, so look for it on the images alongside the date. It is not a NARA identifier and does not resolve to a catalog record.")
        }
    }
}

// MARK: - CountrySeriesOutcome (fix 5)

/// What Source Explorer's pre-1906 section knows about a document, as distinct states.
///
/// Before this, an empty list of homes meant loading, not checked (for any of nine reasons), nothing
/// found, and "this is not a pre-1906 document" all at once, and every one of them printed "couldn't be
/// predicted from its dateline and FRUS chapter" — false in all but one.
enum CountrySeriesOutcome: Sendable, Equatable {

    /// Why the check did not run.
    enum NotCheckedReason: Sendable, Equatable, CaseIterable {
        /// The search index has not been created yet.
        case indexStarting
        /// The host passed no volume or document id.
        case noDocumentIdentity
        /// Reading the document's row from the index threw.
        case indexReadFailed
        /// The route supplied no dateline and the document has no index row.
        case documentNotIndexed
        /// The document has an index row, and neither it nor the route has a dateline.
        case noDateline
        /// The dateline gives no year.
        case noYear
        /// The bundled central-files index did not load.
        case centralFilesIndexMissing
        /// The volume's chapter structure is not in the index.
        case noVolumeStructure
        /// The document is not among its volume's chapters.
        case documentNotInStructure

        /// The sentence the section shows for this reason.
        var message: String {
            switch self {
            case .indexStarting:
                return String(localized: "source.explorer.countrySeries.state.notChecked.indexStarting",
                              defaultValue: "Not checked yet — the search index is still starting. This section fills in when it is ready.")
            case .noDocumentIdentity:
                return String(localized: "source.explorer.countrySeries.state.notChecked.noDocumentIdentity",
                              defaultValue: "Not checked — Source Explorer was opened without a document to look up, so there is no dateline or FRUS chapter to read.")
            case .indexReadFailed:
                return String(localized: "source.explorer.countrySeries.state.notChecked.indexReadFailed",
                              defaultValue: "Not checked — the search index could not be read. Close Source Explorer and open it again.")
            case .documentNotIndexed:
                return String(localized: "source.explorer.countrySeries.state.notChecked.documentNotIndexed",
                              defaultValue: "Not checked — this document is not in the search index on this device, so its dateline and FRUS chapter could not be read.")
            case .noDateline:
                return String(localized: "source.explorer.countrySeries.state.notChecked.noDateline",
                              defaultValue: "Not checked — this document prints no dateline, and the dateline is what places a pre-1906 document in a series.")
            case .noYear:
                return String(localized: "source.explorer.countrySeries.state.notChecked.noYear",
                              defaultValue: "Not checked — this document’s dateline gives no year, so no roll’s dates can be compared.")
            case .centralFilesIndexMissing:
                return String(localized: "source.explorer.countrySeries.state.notChecked.centralFilesIndexMissing",
                              defaultValue: "Not checked — the app’s list of digitized rolls could not be loaded.")
            case .noVolumeStructure:
                return String(localized: "source.explorer.countrySeries.state.notChecked.noVolumeStructure",
                              defaultValue: "Not checked — this volume’s chapters are not in the search index on this device, and the chapter is what names the country.")
            case .documentNotInStructure:
                return String(localized: "source.explorer.countrySeries.state.notChecked.documentNotInStructure",
                              defaultValue: "Not checked — this document was not found among its volume’s chapters, so no chapter names its country.")
            }
        }
    }

    /// The check has not finished.
    case loading
    /// The check could not run, and why.
    case notChecked(NotCheckedReason)
    /// The check ran and no roll matched.
    case noMatch
    /// The document is from 1906 or later, where this section's rule does not apply.
    case notApplicable
    /// The homes found, with the serial label their lead home implies.
    case resolved([CentralFilesResolution], serialLabel: CentralFilesSerialLabel)

    /// The homes when resolved, otherwise none.
    var homes: [CentralFilesResolution] {
        if case .resolved(let homes, _) = self { return homes }
        return []
    }

    /// The sentence shown while the check runs.
    static var loadingMessage: String {
        String(localized: "source.explorer.countrySeries.state.loading",
               defaultValue: "Checking the digitized pre-1906 records for this document…")
    }

    /// The sentence shown for a note-less document from 1906 or later, where nothing ran.
    static var notApplicableMessage: String {
        String(localized: "source.explorer.countrySeries.state.notApplicable",
               defaultValue: "This document carries no archival source note. Roll suggestions cover documents from before 1906, when the Department filed its correspondence by country, so none is offered for a later document.")
    }
}

// MARK: - The gate, the homes, and evaluate (fixes 1–5)

/// What the opening route handed Source Explorer about the document.
struct CountrySeriesRoute: Sendable, Equatable {
    /// The header the host passed; on several routes it is the xml:id, not the printed header.
    let header: String?
    /// The dateline the host passed, or `nil` (History, related-document taps, restored windows).
    let dateline: String?
    /// The year the host derived, or `nil`.
    let year: Int?
    /// The document's volume id.
    let volumeId: String?
    /// The document's xml:id.
    let documentId: String?
}

/// What reading the document's row from the index produced.
enum SourceExplorerFactsLookup: Sendable, Equatable {
    /// Nothing was read: no pipeline, or no ids to read by.
    case notAttempted
    /// The read threw.
    case failed
    /// The document has no row.
    case missing
    /// The row.
    case found(IndexingPipeline.SourceExplorerFacts)

    /// The row, when there is one.
    var facts: IndexingPipeline.SourceExplorerFacts? {
        if case .found(let facts) = self { return facts }
        return nil
    }
}

/// Whether the volume structure has been read, and what it gave.
enum CountrySeriesSectionPathRead: Sendable, Equatable {
    /// Not read yet: the gate's structure checks pass.
    case unread
    /// The volume has no cached structure.
    case noStructure
    /// Reading the structure threw: an I/O or corruption fault, which is not the same as no row.
    case readFailed
    /// The chain of section titles to the document; empty when the document is not in it.
    case path([String])
}

/// Everything the gate decides on, so each refusal can be tested one condition at a time.
struct CountrySeriesGateInput: Sendable, Equatable {
    /// The year the host passed.
    var routeYear: Int?
    /// The document's volume id.
    var volumeId: String?
    /// The document's xml:id.
    var documentId: String?
    /// Whether the indexing pipeline exists.
    var pipelineAvailable: Bool
    /// What reading the document's row produced.
    var facts: SourceExplorerFactsLookup
    /// The document after hydration.
    var context: SourceExplorerDocumentContext
    /// Whether the bundled central-files index loaded.
    var centralFilesIndexAvailable: Bool
    /// The section path, once read.
    var sectionPath: CountrySeriesSectionPathRead
}

extension CentralFilesClassifier {

    /// The outcome when the check cannot or need not run, or `nil` to proceed.
    ///
    /// In order: a host year of 1906 or later is not applicable; no ids; no pipeline; no dateline
    /// (split by what the index read gave: it threw, there is no row, or the row has none); no year;
    /// a hydrated year of 1906 or later; no central-files index; no volume structure (or reading it
    /// threw); the document is not in it. `sectionPath == .unread` passes the last two, so `evaluate` can refuse cheaply
    /// before it reads the structure and then ask again.
    static func gate(_ input: CountrySeriesGateInput) -> CountrySeriesOutcome? {
        if let year = input.routeYear, year >= 1906 { return .notApplicable }
        guard input.volumeId != nil, input.documentId != nil else { return .notChecked(.noDocumentIdentity) }
        guard input.pipelineAvailable else { return .notChecked(.indexStarting) }
        if input.context.dateline == nil {
            switch input.facts {
            case .failed: return .notChecked(.indexReadFailed)
            case .missing, .notAttempted: return .notChecked(.documentNotIndexed)
            case .found: return .notChecked(.noDateline)
            }
        }
        guard let year = input.context.year else { return .notChecked(.noYear) }
        guard year < 1906 else { return .notApplicable }
        guard input.centralFilesIndexAvailable else { return .notChecked(.centralFilesIndexMissing) }
        switch input.sectionPath {
        case .unread:
            return nil
        case .noStructure:
            return .notChecked(.noVolumeStructure)
        case .readFailed:
            return .notChecked(.indexReadFailed)
        case .path(let path):
            return path.isEmpty ? .notChecked(.documentNotInStructure) : nil
        }
    }

    /// The rolls a classification resolves to: by date alone for a chronological run (and only with a
    /// date — an undated query would list the whole series), otherwise by its first geo key and date.
    static func rolls(for classification: CentralFilesClassification, index: CentralFilesIndex,
                      dateISO: String?) -> [CountryRoll] {
        guard let series = index.series(category: classification.category) else { return [] }
        if classification.category.isChronologicalRun {
            guard let dateISO else { return [] }
            return series.rolls(containingDate: dateISO)
        }
        guard let geoKey = classification.geoKeys.first else { return [] }
        return series.rolls(geoKey: geoKey, dateISO: dateISO)
    }

    /// The document's own homes: each title in the section path from the root, until one yields rolls.
    ///
    /// Per title it classifies, looks up the rolls, then applies the addressee rule — AFTER the roll
    /// lookup, so the rule sees which reels exist. The country is usually a parent chapter (`France.`
    /// under `Supplement.`), which is why every title is tried.
    static func documentHomes(header: String, dateline: String, sectionPath: [String],
                              index: CentralFilesIndex, roster: ChiefsOfMissionRoster) -> [CentralFilesResolution] {
        let dateISO = datelineDateISO(from: dateline)
        for title in sectionPath {
            let classifications = classify(header: header, dateline: dateline, chapterCountry: title)
            var homes: [CentralFilesResolution] = []
            for classification in classifications {
                let found = rolls(for: classification, index: index, dateISO: dateISO)
                if !found.isEmpty {
                    homes.append(CentralFilesResolution(classification: classification, rolls: found))
                }
            }
            homes = applyAddresseeRule(homes: homes, classifications: classifications, header: header,
                                       dateline: dateline, chapterTitle: title, roster: roster)
            if !homes.isEmpty { return homes }
        }
        return []
    }

    /// Promotes the Instructions home when the roster names the addressee as the U.S. chief of mission.
    ///
    /// Applies only when the title classified to BOTH Instructions and Notes to Foreign Missions and
    /// `ChiefsOfMissionRoster.decide` returns a chief. Then an Instructions home is rebuilt at `.high`
    /// with a rationale naming the chief, and the Notes-to home is dropped — but only when an
    /// Instructions home exists: a title whose only reel is Notes-to keeps it, at "Possible" (D2),
    /// because removing a document's only reel would turn a decided letter into "no match". Consular
    /// and domestic candidates are never touched.
    static func applyAddresseeRule(homes: [CentralFilesResolution], classifications: [CentralFilesClassification],
                                   header: String, dateline: String, chapterTitle: String,
                                   roster: ChiefsOfMissionRoster) -> [CentralFilesResolution] {
        guard let instruction = classifications.first(where: { $0.category == .instructions }),
              classifications.contains(where: { $0.category == .notesTo }),
              let at = homes.firstIndex(where: { $0.classification.category == .instructions }),
              let chief = roster.decide(header: header, dateline: dateline, geoKeys: instruction.geoKeys)
        else { return homes }
        let lastYear = String((chief.lastDayISO ?? chief.firstDayISO).prefix(4))
        let firstYear = String(chief.firstDayISO.prefix(4))
        let years = firstYear == lastYear ? firstYear : String(
            format: String(localized: "centralFiles.rationale.tenureYears %@ %@", defaultValue: "%1$@–%2$@"),
            firstYear, lastYear)
        let rationale = String(
            format: String(localized: "centralFiles.rationale.instructionToChiefOfMission %@ %@ %@ %@",
                           defaultValue: "From the Department of State to %1$@, U.S. %2$@ to %3$@ (%4$@): an instruction."),
            chief.displayName, chief.roleLabel, printedCountry(fromChapterTitle: chapterTitle), years)
        var promoted = homes
        promoted[at] = CentralFilesResolution(
            classification: CentralFilesClassification(category: .instructions, geoKeys: instruction.geoKeys,
                                                       confidence: .high, rationale: rationale),
            rolls: homes[at].rolls, part: homes[at].part, chiefOfMission: chief)
        promoted.removeAll { $0.classification.category == .notesTo }
        return promoted
    }

    /// A chapter title as printed, for a sentence: its chapter number and `(Continued.)` removed and
    /// its trailing period, colon, semicolon or comma dropped (`XXIX.—Spain.` → `Spain`, `Denmark:` →
    /// `Denmark`). Measured, 20 decided documents sit under `Denmark:`.
    static func printedCountry(fromChapterTitle title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = text.range(of: #"^(?:\[\d+\]\s*)?\*?\s*(?:[IVXLCDM]+|\d{1,3})\.\s*[—–-]\s*"#, options: .regularExpression) {
            text = String(text[r.upperBound...])
        }
        if let r = text.range(of: #"\s*\(\s*continued\.?\s*\)\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            text = String(text[..<r.lowerBound])
        }
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".:;,")))
    }

    /// The enclosures' homes with their rolls, each matched by the enclosure's OWN date (B-5).
    ///
    /// The rule of what an enclosure resolves to is `enclosureHomes`; this adds the roll lookup both
    /// views used to repeat. A chronological run is matched by the enclosure's date alone, and using
    /// the parent's would file the enclosure under the covering document's date.
    static func enclosureRolls(openers: [IndexingPipeline.EnclosureOpener],
                               index: CentralFilesIndex) -> [CentralFilesResolution] {
        var dates: [String: String] = [:]
        for opener in openers {
            dates[CentralFilesDocumentPart.enclosure(label: opener.label).key] = datelineDateISO(from: opener.dateline)
        }
        var found: [CentralFilesResolution] = []
        for home in enclosureHomes(openers: openers) {
            let homeRolls = rolls(for: home.classification, index: index, dateISO: dates[home.part.key])
            guard !homeRolls.isEmpty else { continue }
            found.append(CentralFilesResolution(classification: home.classification, rolls: homeRolls, part: home.part))
        }
        return found
    }

    /// The document's enclosure openers, from the shared AST cache, else from parsing the volume.
    ///
    /// Cache hit, else parse — the `CollectionContentResolver.cachedAST` shape. The cache is a 24-slot
    /// LRU that empties on an iOS memory warning, so an open document's AST is probably, not certainly,
    /// cached; without the parse an eviction or a restored scene would give two readers of the same
    /// document different answers. Takes the actor and a URL rather than `AppState`, which is
    /// main-actor isolated and cannot be read from here.
    static func enclosureOpeners(volumeId: String, documentId: String, astCache: DocumentASTCache,
                                 volumeURL: URL?) async -> [IndexingPipeline.EnclosureOpener] {
        var cached = await astCache.ast(volumeId: volumeId, documentId: documentId)
        if cached == nil, let volumeURL, FileManager.default.fileExists(atPath: volumeURL.path),
           let parsed = try? await FRUSDocumentParser().parseDocument(documentId: documentId, volumeURL: volumeURL) {
            await astCache.store([parsed], volumeId: volumeId)
            cached = parsed
        }
        guard let ast = cached else { return [] }
        return IndexingPipeline.extractEnclosureOpeners(from: ast.nodes)
    }

    /// Everything the pre-1906 section shows for a document, for both Source Explorer views.
    ///
    /// A host year of 1906 or later is answered at once, reading nothing. Otherwise: reads the
    /// document's row, hydrates what the route left out, gates, reads the volume structure, gates
    /// again, then finds the document's homes (with the addressee rule) and its enclosures'.
    /// Nonisolated: each view reads `DocumentASTCache` and the volume URL on the main actor, passes
    /// them in, and writes the result only if its task was not cancelled.
    ///
    /// - Parameter roster: The chiefs of mission the addressee rule reads, or `nil` for the bundled
    ///   register. Resolved here, after both gates, rather than by the caller: `.bundled` decodes
    ///   `pocom-index.json` on first use, and a view passing it would do that on the main actor — for
    ///   a document the rule never reads, too.
    static func evaluate(route: CountrySeriesRoute, pipeline: IndexingPipeline?, index: CentralFilesIndex?,
                         roster: ChiefsOfMissionRoster? = nil, astCache: DocumentASTCache,
                         volumeURL: URL?) async -> (context: SourceExplorerDocumentContext, outcome: CountrySeriesOutcome) {
        if let year = route.year, year >= 1906 {
            // The gate's first refusal, before the index read: awaiting the pipeline actor, which may be
            // busy indexing, would show "Checking…" for a check that cannot run.
            let context = SourceExplorerDocumentContext.hydrate(
                routeHeader: route.header, routeDateline: route.dateline, routeYear: year,
                documentId: route.documentId, indexed: nil)
            return (context, .notApplicable)
        }
        var lookup = SourceExplorerFactsLookup.notAttempted
        if let pipeline, let volumeId = route.volumeId, let documentId = route.documentId {
            do {
                if let facts = try await pipeline.sourceExplorerFacts(volumeId: volumeId, documentId: documentId) {
                    lookup = .found(facts)
                } else {
                    lookup = .missing
                }
            } catch {
                lookup = .failed
            }
        }
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: route.header, routeDateline: route.dateline, routeYear: route.year,
            documentId: route.documentId, indexed: lookup.facts)
        var input = CountrySeriesGateInput(
            routeYear: route.year, volumeId: route.volumeId, documentId: route.documentId,
            pipelineAvailable: pipeline != nil, facts: lookup, context: context,
            centralFilesIndexAvailable: index != nil, sectionPath: .unread)
        if let refused = gate(input) { return (context, refused) }
        // The gate has refused each of these already; the fallback is unreachable.
        guard let pipeline, let volumeId = route.volumeId, let documentId = route.documentId,
              let dateline = context.dateline, let index else {
            return (context, .notChecked(.noDocumentIdentity))
        }
        var path: [String] = []
        do {
            if let structure = try await pipeline.cachedVolumeStructure(forVolumeId: volumeId) {
                path = documentSectionPath(in: structure, documentId: documentId)
                input.sectionPath = .path(path)
            } else {
                input.sectionPath = .noStructure
            }
        } catch {
            input.sectionPath = .readFailed
        }
        if let refused = gate(input) { return (context, refused) }

        let homes = documentHomes(header: context.header, dateline: dateline, sectionPath: path,
                                  index: index, roster: roster ?? .bundled)
        let openers = await enclosureOpeners(volumeId: volumeId, documentId: documentId,
                                             astCache: astCache, volumeURL: volumeURL)
        let all = homes + enclosureRolls(openers: openers, index: index)
        guard !all.isEmpty else { return (context, .noMatch) }
        return (context, .resolved(all, serialLabel: CentralFilesSerialLabel(homes: all)))
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
