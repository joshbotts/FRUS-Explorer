// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LotResolutionAcceptance

/// Whether a NARA Catalog record may be surfaced as the resolution of a State Department
/// lot file (#674 / N-8).
///
/// ## Why this exists
/// The bundle-building generator has applied a three-conjunct acceptance test since #352
/// (`CatalogRecord.isAcceptableLotResolution`). **The app never had one.** Its live path
/// tried three exact `variantControlNumber_is` forms and, when all three correctly returned
/// nothing, fell back to a free-text phrase query taking the single top hit — which is how
/// lot `90 D 234` (the Bureau of Oceans' Antarctic files) came to resolve to a **Census
/// Bureau** series.
///
/// The generator's own client had already written down why that happens
/// (`NARACatalogHarvestClient.swift:413-416`): NARA's record-group filter does not constrain
/// free-text results, and *"the top hit for a lot string is often a giant wrong-RG series
/// (census/military/court)"*. It was hardened; the app was not. This type is the rule, in a
/// module both sides can compile, so there is one definition rather than two that drift.
///
/// ## The three conjuncts
/// Each closes a mis-resolution class the #335 audit found:
/// 1. the record's own record group matches the one being asked about — never a coincidental
///    free-text hit in another RG;
/// 2. it is not a **file unit** — a State Department lot file is catalogued as a *series*;
/// 3. it actually carries the queried lot in its `variantControlNumbers`.
///
/// Conjunct 3 is what makes the free-text fallback safe to keep rather than delete. The
/// exact `variantControlNumber_is` query matches only the literal spellings the caller
/// generated (`74D476`, `74 D 476`, `74 D476`), so a record NARA indexed as
/// `"Lot File 74D476"` is invisible to it — but `foldControlNumber` strips that prefix, so
/// the free-text hit can still be *verified*. The fallback stops being a guess and becomes a
/// second lookup with the same standard of proof.
///
/// ## What it deliberately does not do
/// It cannot tell one bureau's `66 D 50` from another's. State assigned lot numbers per
/// accession, so two offices could each hold that number and NARA catalogued both; all three
/// conjuncts pass for either. That is #675, and it needs the citation's own office name —
/// which this type is not given. Do not read a `true` here as "this is the right collection",
/// only as "this record is not obviously the wrong one".
///
/// Version history:
///   1.0 — Session 2026-08-04: #674 / N-8, extracted so the app and the generator share one rule
public enum LotResolutionAcceptance {

    /// NARA's `levelOfDescription` value for a file unit — the level a lot file is never
    /// catalogued at, and the one #351 found behind the worst mis-resolutions.
    public static let fileUnitLevel = "fileUnit"

    /// Folds a raw control-number string to the compact lot key form.
    ///
    /// Uppercase; drop spaces and every dash variant (hyphen, en dash, em dash — a citation
    /// reading `61–D 146` and a catalogue entry reading `61-D-146` are the same lot); strip a
    /// single leading `LOT` or `LOTFILE` token and a trailing period.
    ///
    /// ## The two expansions NARA itself documents (#679)
    /// NARA indexes the same lot in more than one spelling, and says so in its own data: nine
    /// `State Department Lot File Number` values literally read **`"82D309 or 1982D0309"`** and
    /// **`"1978D0412 or 78D412"`**. So:
    ///
    /// - **four-digit year** — `1984D241` ≡ `84D241`. 1,016 harvested values use the long form.
    /// - **zero-padded sequence** — `75D076` ≡ `75D76`, `1982D0129` ≡ `82D129`.
    ///
    /// Without these, a record NARA indexed *only* in the expanded form is refused. Measured on
    /// the shipped bundle: 8 rows gain claimants, the largest being `84D241` (164 documents),
    /// where two further Vance series are indexed `1984D241`.
    ///
    /// ## Why the century strip is `19` only
    /// State lot files run from the 1940s to the 1990s, so a four-digit year is always `19xx`.
    /// Folding `20xx` would rewrite modern accession numbers into implausible lots —
    /// `2015D0755` would become `15D755`, a 1915 lot file that cannot exist. Measured over
    /// every control number in the harvest, restricting to `19` changes 53 keys, touches no
    /// `20xx` value, and merges exactly two pairs: `1982D0129`/`82D129` and `1981D0113`/`81D113`
    /// — both the same lot spelled both ways, which is the point.
    public static func foldControlNumber(_ raw: String) -> String {
        var s = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "—", with: "")
        for prefix in ["LOTFILE", "LOT"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
            break
        }
        if s.hasSuffix(".") { s.removeLast() }
        return canonicalLotKey(s)
    }

    /// Applies the two spelling expansions to an already-stripped key. Returns `s` unchanged
    /// when it is not lot-shaped, so entry numbers (`A1 3051B`), declassification project
    /// numbers and accession numbers pass through untouched.
    private static func canonicalLotKey(_ s: String) -> String {
        var body = s
        // 1984D241 -> 84D241. Only 19xx; see the doc comment.
        if body.count > 3, body.hasPrefix("19") {
            let rest = body.dropFirst(2)
            if isLotShaped(String(rest)) { body = String(rest) }
        }
        // 75D076 -> 75D76.
        guard let letter = body.firstIndex(where: { $0.isLetter }) else { return body }
        let year = body[body.startIndex..<letter]
        let sequence = body[body.index(after: letter)...]
        guard year.count == 2, year.allSatisfy(\.isNumber),
              !sequence.isEmpty, sequence.allSatisfy(\.isNumber) else { return body }
        let trimmed = String(sequence.drop { $0 == "0" })
        return trimmed.isEmpty ? body : year + String(body[letter]) + trimmed
    }

    /// `NNxNNN…` — two digits, one letter, at least one digit.
    private static func isLotShaped(_ s: String) -> Bool {
        guard s.count >= 4 else { return false }
        let chars = Array(s)
        guard chars[0].isNumber, chars[1].isNumber, chars[2].isLetter else { return false }
        return chars[3...].allSatisfy(\.isNumber) && chars.count > 3
    }

    /// Whether `variantControlNumbers` contains `normalizedLot` as a **whole** control number.
    ///
    /// Equality, never `contains` — `"160D6270"` must not spuriously satisfy `"60D627"`.
    /// Both sides are folded so a raw or spaced key still matches.
    public static func carriesLotControlNumber(
        _ normalizedLot: String,
        variantControlNumbers: [String]
    ) -> Bool {
        let target = foldControlNumber(normalizedLot)
        guard !target.isEmpty else { return false }
        return variantControlNumbers.contains { foldControlNumber($0) == target }
    }

    /// How a record was established as holding the queried lot.
    ///
    /// Two channels, kept distinct so the UI can say which one applied rather than asserting
    /// a flat "resolved".
    public enum Evidence: Sendable, Equatable {
        /// The record carries the lot as one of its own control numbers. NARA's direct assertion.
        case controlNumber
        /// The lot is named in the prose `note` attached to another of the record's control
        /// numbers — NARA describing a consolidation it performed.
        case consolidationNote
    }

    /// Lot numbers named inside a control number's prose `note`.
    ///
    /// ## Why this is worth ~40 lines and not a paragraph of warnings
    /// NARA sometimes records a consolidation only in prose. naId 596518 (INR *Subject Files*)
    /// carries the note *"This lot file is a consolidation of material found in lots 53D500,
    /// 58D159, 58D776, 60D644, 61D67, and 62D42 after screening."* — six lot files merged into
    /// one series, stated nowhere else. Reading only `number` refuses that record for five of
    /// the six lots, which is a false refusal against NARA's own words.
    ///
    /// ## The context requirement, and why it is not optional
    /// A note is only read when it **says** it is describing a consolidation — it must contain
    /// one of `consolidat`, `found in lots`, `merged`, or `combined`. Without that gate the
    /// scan is unsafe, and not hypothetically: RG 286's *"Transfer W286-68S3602, Boxes 89-93"*
    /// yields the lot-shaped token `68S3602`, which is a transfer number. That case was found
    /// by a test written against the real 8,897-note corpus after a first measurement — taken
    /// with a regex that tokenised differently from this function — reported zero false
    /// positives. Measure with the code that ships, not with its description.
    ///
    /// With the gate: of all 8,897 control-number notes in the 22-record-group harvest,
    /// **one** is read. The rest are boilerplate (*"This is the Department of State Lot File
    /// Number."*, 1,706 occurrences plus four more spellings) or entry-provenance prose
    /// (*"…formerly described under National Archives Identifier 6862111"*).
    static func lotsNamedInNote(_ note: String) -> [String] {
        let lowered = note.lowercased()
        let describesConsolidation = ["consolidat", "found in lots", "merged", "combined"]
            .contains { lowered.contains($0) }
        guard describesConsolidation else { return [] }
        var found: [String] = []
        var current = ""
        func flush() {
            defer { current = "" }
            let key = foldControlNumber(current)
            guard isLotShaped(key) else { return }
            found.append(key)
        }
        for ch in note {
            if ch.isNumber || ch.isLetter { current.append(ch) } else { flush() }
        }
        flush()
        return found
    }

    /// Whether a candidate record may be surfaced as the resolution of `normalizedLot` in
    /// `recordGroup`.
    ///
    /// A `nil` `candidateRecordGroup` or a `nil` `levelOfDescription` **fails** the test:
    /// #321 removed a last-resort branch that accepted records with no exposed record group,
    /// and absence of evidence is not evidence here.
    public static func isAcceptable(
        recordGroup: String,
        normalizedLot: String,
        candidateRecordGroup: String?,
        levelOfDescription: String?,
        variantControlNumbers: [String],
        controlNumberNotes: [String] = []
    ) -> Bool {
        evidence(recordGroup: recordGroup, normalizedLot: normalizedLot,
                 candidateRecordGroup: candidateRecordGroup,
                 levelOfDescription: levelOfDescription,
                 variantControlNumbers: variantControlNumbers,
                 controlNumberNotes: controlNumberNotes) != nil
    }

    /// The evidence establishing this record as the resolution of `normalizedLot`, or `nil`
    /// when there is none. `controlNumber` wins over `consolidationNote` when both apply.
    public static func evidence(
        recordGroup: String,
        normalizedLot: String,
        candidateRecordGroup: String?,
        levelOfDescription: String?,
        variantControlNumbers: [String],
        controlNumberNotes: [String] = []
    ) -> Evidence? {
        guard let candidateRecordGroup, candidateRecordGroup == recordGroup else { return nil }
        guard let levelOfDescription, levelOfDescription != fileUnitLevel else { return nil }
        if carriesLotControlNumber(normalizedLot, variantControlNumbers: variantControlNumbers) {
            return .controlNumber
        }
        let target = foldControlNumber(normalizedLot)
        guard !target.isEmpty else { return nil }
        for note in controlNumberNotes where lotsNamedInNote(note).contains(target) {
            return .consolidationNote
        }
        return nil
    }
}
