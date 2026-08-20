// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DespatchSerial

/// A pre-1906 document's own **despatch or instruction serial** — the sequence number the sending
/// post assigned its outgoing correspondence, printed by FRUS as `No. 74.]` above the document.
public struct DespatchSerial: Sendable, Equatable {

    /// The serial number itself. `74` in `No. 74.]`.
    public let number: Int
    /// A half-step, printed as a vulgar fraction: `No. 25½.]`. Stored separately because it is
    /// part of the identifier — `25½` is a different despatch from `25` — and because an `Int`
    /// cannot carry it.
    public let isHalf: Bool
    /// A letter suffix, as in `No. 12 B.]`.
    public let letterSuffix: String?
    /// The series or handling qualifier when the post kept more than one sequence:
    /// `Greek Series`, `Servian series`, `Dip. Ser.`, `confidential`, `official`.
    public let qualifier: String?
    /// The segment's text as printed, for display and for provenance.
    public let rawText: String

    /// The identifier a researcher would quote when requesting the document from the post's
    /// series — the number, its half-step and letter, but not the handling qualifier.
    public var displayNumber: String {
        "\(number)" + (isHalf ? "½" : "") + (letterSuffix.map { " \($0)" } ?? "")
    }
}

// MARK: - DespatchSerialGrammar

/// Reads a pre-1906 document's own serial out of a TEI `<seg>` (#965).
///
/// ## What this is, and what it is not
/// The issue this grammar serves was filed as *"file numbers embedded in document bodies"*. There
/// are no file numbers in pre-1906 bodies — the decimal file did not open until 1910. Measured
/// over three volumes spanning four decades: `frus1895p1` 508 serials / **0** file-number shapes,
/// `frus1876` 355 / **0**, `frus1863p1` 341 / **0**. What is there is the post's own outgoing
/// sequence number, which identifies a document *within a post's series* rather than a folder in a
/// central file. The issue was retitled before this file was written.
///
/// ## Why a whole-segment match, and not a scan
/// **This is the load-bearing rule.** `<seg>` is FRUS's general bracketed-editorial marker, not a
/// serial element. Measured over every pre-1906 volume, its commonest contents are:
///
/// | shape | occurrences |
/// |---|---|
/// | `No. N.]` | 25,582 |
/// | `[Inclosure N in No. N.]` | 3,508 |
/// | `[Translation.]` | 3,138 |
/// | `[Telegram.]` | 3,109 |
/// | `[Inclosure N.]` | 2,269 |
/// | `[Inclosure in No. N.]` | 1,480 |
///
/// An **enclosure** marker names the serial of the despatch it was enclosed *in* — someone else's
/// number. A grammar that scanned for `No. N` anywhere would attribute those to the documents that
/// merely carry them, and every one of those attributions would be confidently wrong. So a segment
/// qualifies only when its entire content is a serial.
///
/// **The anchoring is what refuses them, not the inclosure guard** — a distinction this comment
/// originally got wrong. Every one of the corpus's enclosure markers begins with `[Inclosure` or
/// `Inclosure`, never with `No`, so requiring the segment to start with `No` and carry an ASCII
/// digit already rejects all of them. Measured: segments starting with `No` that also name an
/// inclosure number, **0**. The explicit guard is a SECOND lock against one specific and likely
/// edit — relaxing the prefix rule to tolerate a leading `[` "for robustness" would admit every
/// marker at once. Because nothing in the corpus reaches it, it is exercised by a deliberately
/// synthetic fixture (`inclosureGuardHoldsEvenIfAnchoringIsRelaxed`), which says so in its own
/// documentation. Before that test existed a mutation deleting the guard SURVIVED.
///
/// Measured by running this grammar over every `<seg>` in all 69 pre-1906 volumes: **28,112
/// serials accepted, 17,078 enclosure markers refused.** The refusal is therefore not a corner
/// case — it is more than a third of everything that looks like a serial, and an earlier estimate
/// of "~7,700" from the top few shapes was less than half the truth, because the corpus wraps
/// these markers across lines in many variants.
///
/// ## Two classes are refused by decision, not by accident
/// The same corpus pass reports everything refused that still looks like a serial. It comes to
/// fifteen shapes, and all but two are correct refusals — `Notice.]`, `Note.]`, `Note verbale.]`
/// and prose like *"No evidence of the exercise of due diligence…"* all begin with "No" and are
/// rejected for carrying no digits, which is the digit requirement doing real work. The two that
/// are judgement calls:
///
/// - **`Nos. 4, 5.]` (8 occurrences)** — one segment naming TWO serials. Refused because
///   attributing the document to either one alone is a guess, and this type carries no rule for
///   choosing. Eight documents keep no serial rather than gain a possibly wrong one.
/// - **`No, 74.]` (2 occurrences)** — a comma where the corpus elsewhere prints a full stop,
///   almost certainly a typesetting slip. Refused for consistency with the above: two documents
///   are not worth a rule that admits a malformed shape.
///
/// Ten documents of 28,122. Both are listed here so the next reader knows they were seen and
/// decided, rather than missed.
///
/// ## The vocabulary is a tail, not a list
/// 119 distinct shapes over 28,139 occurrences in 69 volumes. Beyond the common forms it carries
/// series qualifiers (`Greek Series`, `Servian series`, `Roumanian series`, `Haitian series`,
/// `Santo Domingo Series`, `Dip. Ser.`, `Diplomatic`), handling words (`official`, `confidential`),
/// a half-step vulgar fraction (`No. 25½.]`), letter suffixes (`No. 12 B.]`), a missing space
/// (`No.12.]`), a trailing period outside the bracket (`No. 74.].`), and at least one segment with
/// no number at all (`No.—.]`). Coding to a six-item list — which is what a first pass at this
/// proposed — would have dropped the qualified series silently, and those are exactly the posts
/// that kept more than one sequence, where the serial alone is ambiguous.
///
/// Version history:
///   1.0 — Session 2026-08-20: #965
public enum DespatchSerialGrammar {

    /// Markers that name a serial belonging to some OTHER document. Refused before parsing.
    ///
    /// Spelled as FRUS spells it — `Inclosure`, not `Enclosure` — and matched case-insensitively
    /// because the corpus carries both cases in the qualifier tail.
    private static let foreignSerialMarkers = ["inclosure", "enclosure"]

    /// The serial a `<seg>` carries, or `nil` when it carries something else.
    ///
    /// - Parameter segment: The segment's text content, as parsed. Internal whitespace may be
    ///   wrapped across lines — the corpus wraps inside `<seg>` freely — so it is collapsed first.
    /// - Returns: The serial, or `nil` for any segment that is not wholly one.
    public static func serial(inSegment segment: String) -> DespatchSerial? {
        let raw = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }

        // An enclosure marker names another document's serial. Refused first, so no later rule can
        // accidentally admit one.
        let lowered = collapsed.lowercased()
        guard !foreignSerialMarkers.contains(where: { lowered.contains($0) }) else { return nil }

        // Strip the printed furniture: a leading bracket is not used by serials but costs nothing
        // to tolerate, and the trailing `]` / `.` / `].` forms all appear.
        var body = collapsed
        while let last = body.last, last == "]" || last == "." { body.removeLast() }
        body = body.trimmingCharacters(in: .whitespaces)
        guard body.lowercased().hasPrefix("no") else { return nil }
        body.removeFirst(2)
        if body.first == "." { body.removeFirst() }
        body = body.trimmingCharacters(in: .whitespaces)

        // The number. `No.—.]` has none and is not a serial.
        //
        // `isASCII && isNumber`, NOT `isNumber` alone: Swift counts a vulgar fraction as a number,
        // so `"25½".prefix(\.isNumber)` is the whole string and `Int("25½")` is nil — which
        // silently dropped every half-step serial. Same family as #966, where a vulgar fraction in
        // a decimal class hid behind a regex that looked right.
        let digits = body.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        var rest = body.dropFirst(digits.count)

        let isHalf = rest.first == "½"
        if isHalf { rest = rest.dropFirst() }
        // A serial's own full stop, before any qualifier: `No. 4.—Greek Series`. Left in place it
        // rides into the qualifier as ". Greek Series".
        if rest.first == "." { rest = rest.dropFirst() }

        // A qualifier follows a comma or an em/en dash: `No. 4, Greek Series` / `No. 4—Greek Series`.
        var qualifier: String?
        var letterSuffix: String?
        if let sep = rest.firstIndex(where: { $0 == "," || $0 == "—" || $0 == "–" }) {
            let tail = rest[rest.index(after: sep)...].trimmingCharacters(in: .whitespaces)
            qualifier = tail.isEmpty ? nil : tail
            rest = rest[..<sep]
        }
        let letters = rest.trimmingCharacters(in: .whitespaces)
        if !letters.isEmpty {
            // `No. 12 B` — a letter suffix. Anything longer than a short token is prose, and prose
            // after the number means this segment is not a bare serial (`No. 4. Diplomatic`).
            if letters.count <= 2, letters.allSatisfy({ $0.isLetter }) {
                letterSuffix = letters.uppercased()
            } else {
                qualifier = qualifier.map { "\(letters) \($0)" } ?? letters
            }
        }

        return DespatchSerial(number: number, isHalf: isHalf, letterSuffix: letterSuffix,
                              qualifier: qualifier, rawText: raw)
    }
}
