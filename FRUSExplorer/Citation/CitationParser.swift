// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationParser

/// Extracts structured `CitationInput` from free-form FRUS citation text.
///
/// ## Supported citation formats
///
/// **history.state.gov recommended style:**
/// ```
/// Foreign Relations of the United States, 1969–1976, Volume I, ...,
/// eds. Name, ... (Washington: GPO, 2003), Document 15.
/// ```
///
/// **Chicago footnote (full):**
/// ```
/// Foreign Relations of the United States, 1969–1976, vol. I, doc. 15, p. 47
/// ```
///
/// **Chicago footnote (short):**
/// ```
/// FRUS, 1969–76, I, doc. 15
/// ```
///
/// **Informal/abbreviated:**
/// ```
/// FRUS 1969-76, vol. 1, no. 15
/// ```
///
/// **Page-only (common in pre-1955–57 references):**
/// ```
/// FRUS, 1952–1954, vol. XIV, p. 847
/// ```
///
/// **A volume's part (#1474):**
/// ```
/// FRUS, 1952–1954, vol. II, pt. 1, doc. 41
/// ```
///
/// **A history.state.gov address (#1474)** — the form the app's own share menu and exports hand
/// out. Its volume id is exact, so the volume fields are always read from it. An address naming a
/// numbered document (`d41`, `d373a`) or a page (`pg_50`) decides every field and none is read from
/// the prose around it; an address naming only the volume, a section (`ch3`), or a document whose
/// id carries no plain number (`d710a-1`, `eta_d1`, `appA`) leaves the document and page to that
/// prose — `FRUS, 1961–1963, vol. V, doc. 84, https://…/frus1961-63v05` is document 84 — and
/// carries that prose's own subseries, volume and part beside the reference, for the matcher to
/// check the document it finds against:
/// ```
/// https://history.state.gov/historicaldocuments/frus1952-54v02p1/d41
/// ```
///
/// **Potentially malformed:** OCR artifacts and spacing variations are tolerated
/// through a lenient multi-stage pipeline.
///
/// ## Pipeline stages
/// Each extraction method is independent; unrecognized text is preserved as
/// a `titleFragment` candidate.
///
/// ## Log prefix
/// `[CitationParser]`
///
/// Version history:
///   1.0 — Session 30: initial implementation
///   1.1 — #1474: parses a volume's part (`pt. 2`, `Part II`) and a history.state.gov address,
///          neither of which it read before — a pasted link filled only the Subseries field
///   1.2 — #1474 review round 1: an address naming only a volume or a section no longer discards
///          the document number printed beside it; a segment is kept as written whatever its shape
///          (`d550A`, `d710a-1`, `eta_d1`); and an E-volume address fills the Volume field (`E-5`)
///   1.3 — #1474 review round 2: beside such an address, the prose's own subseries, volume and
///          part are carried on the reference (`CitationExactReference.prose`)
public struct CitationParser: Sendable {

    public init() {}

    // MARK: - Main Entry Point

    /// Parses a raw citation string and returns the best `CitationInput` the pipeline can produce.
    public func parse(_ rawText: String) -> CitationInput {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return CitationInput(rawText: rawText, parserConfidence: .low)
        }

        // A history.state.gov address names the volume exactly, and often the document (#1474).
        if let link = Self.link(in: text) {
            return input(fromLink: link, text: text, rawText: rawText)
        }
        return parseProse(text, rawText: rawText)
    }

    /// The fields a citation with no history.state.gov address yields.
    private func parseProse(_ text: String, rawText: String) -> CitationInput {
        let subseries      = extractSubseries(from: text)
        let volumeNumber   = extractVolumeNumber(from: text)
        let partNumber     = extractPartNumber(from: text)
        let documentNumber = extractDocumentNumber(from: text)
        let pageNumber     = extractPageNumber(from: text)
        let titleFragment  = extractTitleFragment(from: text,
                                                  subseries: subseries,
                                                  volumeNumber: volumeNumber)

        let fieldCount = [subseries, volumeNumber].compactMap { $0 }.count
            + [documentNumber, pageNumber].compactMap { $0 }.count

        let confidence: ParserConfidence
        switch fieldCount {
        case 3...: confidence = .high
        case 2:    confidence = .medium
        default:   confidence = .low
        }

        #if DEBUG
        print("[CitationParser] parsed subseries=\(subseries ?? "-") vol=\(volumeNumber ?? "-") part=\(partNumber.map(String.init) ?? "-") doc=\(documentNumber.map(String.init) ?? "-") page=\(pageNumber.map(String.init) ?? "-") confidence=\(confidence)")
        #endif

        return CitationInput(
            rawText: rawText,
            subseries: subseries,
            volumeNumber: volumeNumber,
            partNumber: partNumber,
            documentNumber: documentNumber,
            pageNumber: pageNumber,
            titleFragment: titleFragment,
            parserConfidence: confidence
        )
    }

    // MARK: - Subseries Extraction

    /// Extracts a normalized subseries year-range string such as `"1969-76"`.
    ///
    /// Handles:
    /// - En dash vs hyphen: `"1969–76"` → `"1969-76"`
    /// - Full end year: `"1969–1976"` → `"1969-76"`
    /// - Single year: `"1861"` → `"1861"`
    public func extractSubseries(from text: String) -> String? {
        // Pattern: 4-digit year followed by optional (en dash or hyphen) + (2 or 4 digit year)
        let pattern = #"(1[89]\d{2})(?:[–\-](\d{4}|\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard let startRange = Range(match.range(at: 1), in: text) else { return nil }
        let startYear = String(text[startRange])

        if let endCaptureRange = Range(match.range(at: 2), in: text) {
            let endRaw = String(text[endCaptureRange])
            let endNormalized: String
            if endRaw.count == 2 {
                // Collapse: "1969-76" → keep the two-digit form
                endNormalized = endRaw
            } else {
                // Full end year: "1969-1976" → take last two digits
                endNormalized = String(endRaw.suffix(2))
            }
            return "\(startYear)-\(endNormalized)"
        }
        return startYear
    }

    // MARK: - Volume Number Extraction

    /// Extracts a volume number, normalizing Roman numeral variants.
    ///
    /// Recognized prefixes: `vol.`, `v.`, `Volume`, `volume`, `Vol.`, bare Roman after comma.
    /// Normalizes Arabic → Roman via `arabicToRoman(_:)`; returns the string as-is when
    /// the numeral cannot be parsed.
    public func extractVolumeNumber(from text: String) -> String? {
        // Explicit prefix patterns first (most reliable)
        let prefixPatterns = [
            #"(?:vol(?:ume)?\.?\s+)([IVXLCDMivxlcdm]+|\d+)"#,
            #"(?:v\.\s*)([IVXLCDMivxlcdm]+|\d+)"#,
        ]
        for pattern in prefixPatterns {
            if let raw = firstCapture(pattern: pattern, in: text) {
                return normalizeVolumeNumber(raw)
            }
        }

        // "FRUS, 1969–76, I" — Roman numeral after subseries with no prefix
        let romanAfterSubseries = #"(?:1[89]\d{2}(?:[–\-]\d{2,4})?)\s*,\s*([IVXivx]+)\b"#
        if let raw = firstCapture(pattern: romanAfterSubseries, in: text) {
            return normalizeVolumeNumber(raw)
        }

        return nil
    }

    // MARK: - Part Extraction

    /// Extracts the part of a multi-part volume — `pt. 2`, `pt 2`, `part 2`, `Part II` — as an
    /// integer (#1474).
    ///
    /// Before #1474 nothing read a part: `vol. II, pt. 1` parsed as Volume II and the part survived
    /// only as the token `1` in the hidden title fragment, where it happened to overlap the manifest
    /// title's "Part 1". The word must stand alone on the left, so `department`, `counterpart` and
    /// `Sept.` name no part, and the numeral must end at a word boundary, so `Part Iran` does not
    /// either.
    public func extractPartNumber(from text: String) -> Int? {
        let pattern = #"\b(?:pt|part)\.?\s*([IVX]+|\d{1,2})\b"#
        guard let raw = firstCapture(pattern: pattern, in: text) else { return nil }
        return Self.normalizedPartNumber(raw)
    }

    /// A part numeral as typed in Structured Entry's Part field or printed in a citation — `2`,
    /// `II`, `ii` — or `nil` for anything else, including zero (#1474).
    public static func normalizedPartNumber(_ raw: String) -> Int? {
        CitationNumerals.value(of: raw)
    }

    // MARK: - history.state.gov Links

    /// The volume, and the document, a history.state.gov address in `text` names (#1474), e.g.
    /// `https://history.state.gov/historicaldocuments/frus1961-63v05/d84` → `frus1961-63v05`, `d84`.
    ///
    /// The address's path components ARE the TEI identifiers, so nothing is resolved here: the
    /// volume id, and the segment after it, are kept exactly as written — the manifest has
    /// mixed-case volume ids (`frus1919Parisv01`), and the corpus has document ids of many shapes
    /// (`d373a`, `d550A`, `d710a-1`, `eta_d1`, `appA`), none of which the address tells from a
    /// section such as `ch3`. A page address (`…/pg_50`) names the volume alone. `nil` when `text`
    /// holds no such address.
    public static func exactReference(in text: String) -> CitationExactReference? {
        link(in: text)?.reference
    }

    /// A history.state.gov address as `link(in:)` reads it.
    private struct Link {
        /// The volume id, as written.
        let volumeId: String
        /// The segment after the volume, as written; `nil` when there is none or it names a page.
        let segment: String?
        /// The page a `pg_N` segment names.
        let page: Int?
        /// The whitespace-delimited token the address occupies, so the prose around it can be read
        /// without it.
        let token: Range<String.Index>

        /// The reference the matcher resolves.
        var reference: CitationExactReference {
            CitationExactReference(volumeId: volumeId, documentId: segment)
        }

        /// Whether the address decides every field itself: it names a page, or a document by a
        /// `d` id that carries its number (`d84`, `d373a`, `d550A`). Any other segment may be a
        /// section, so the prose beside it keeps its say over the document and page.
        var namesDocumentOrPage: Bool {
            page != nil
                || segment?.range(of: #"^[dD]\d+[A-Za-z]*$"#, options: .regularExpression) != nil
        }
    }

    /// The address `exactReference(in:)` reads, with the page a `pg_N` path names.
    private static func link(in text: String) -> Link? {
        let pattern = #"(?:^|/)historicaldocuments/(frus[0-9][A-Za-z0-9\-]*)(?:/([A-Za-z0-9_\-]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let matched = Range(match.range, in: text),
              let volumeRange = Range(match.range(at: 1), in: text) else { return nil }
        let volumeId = String(text[volumeRange])
        let segment = Range(match.range(at: 2), in: text).map { String(text[$0]) }

        // The token runs from the whitespace before the address to the whitespace after it, so
        // `https://history.state.gov`, a trailing `.` and any wrapping parentheses go with it.
        let start = text[..<matched.lowerBound].lastIndex(where: \.isWhitespace)
            .map { text.index(after: $0) } ?? text.startIndex
        let end = text[matched.upperBound...].firstIndex(where: \.isWhitespace) ?? text.endIndex

        if let segment, segment.range(of: #"^pg_\d+$"#, options: .regularExpression) != nil {
            return Link(volumeId: volumeId, segment: nil, page: Int(segment.dropFirst(3)),
                        token: start..<end)
        }
        return Link(volumeId: volumeId, segment: segment, page: nil, token: start..<end)
    }

    /// The input a history.state.gov address yields.
    ///
    /// The volume fields always come from its volume id, which is exact. An address that names a
    /// numbered document or a page decides the document and page as well, and nothing is read from
    /// the prose around it, which may not agree. Any other address — the volume alone, a section,
    /// or a document whose id carries no plain number — names no document the parser can vouch
    /// for, so the document and page come from the prose beside it, read without the address. The
    /// matcher looks the address's segment up first and falls back to them within the linked volume.
    ///
    /// In that second case the prose's own subseries, volume and part travel with the reference
    /// (`CitationExactReference.prose`, #1474 review round 2). They never choose the volume, but a
    /// document the prose chooses is checked against them: `vol. XIV, doc. 84, …/frus1961-63v05`
    /// finds Volume V's document 84 and reports it as a best guess naming the cited volume XIV.
    private func input(fromLink link: Link, text: String, rawText: String) -> CitationInput {
        let volumeId = link.volumeId
        let documentNumber: Int?
        let pageNumber: Int?
        var reference = link.reference
        if link.namesDocumentOrPage {
            documentNumber = link.segment.flatMap { Int($0.dropFirst()) }
            pageNumber = link.page
        } else {
            var prose = text
            prose.removeSubrange(link.token)
            documentNumber = extractDocumentNumber(from: prose)
            pageNumber = extractPageNumber(from: prose)
            let named = CitationVolumeFields(subseries: extractSubseries(from: prose),
                                             volumeNumber: extractVolumeNumber(from: prose),
                                             partNumber: extractPartNumber(from: prose))
            if !named.isEmpty {
                reference = CitationExactReference(volumeId: volumeId, documentId: link.segment,
                                                   prose: named)
            }
        }
        let input = CitationInput(
            rawText: rawText,
            subseries: extractSubseries(from: volumeId),
            volumeNumber: CitationNumerals.volumeDesignation(inVolumeId: volumeId),
            partNumber: CitationNumerals.partNumber(inVolumeId: volumeId),
            documentNumber: documentNumber,
            pageNumber: pageNumber,
            titleFragment: nil,
            exactReference: reference,
            parserConfidence: .high
        )
        #if DEBUG
        print("[CitationParser] link volume=\(volumeId) segment=\(link.segment ?? "-") page=\(pageNumber.map(String.init) ?? "-") document=\(documentNumber.map(String.init) ?? "-")")
        #endif
        return input
    }

    // MARK: - Document Number Extraction

    /// Extracts a document number.
    ///
    /// Recognized forms: `Document 15`, `doc. 15`, `doc 15`, `no. 15`, `no 15`, `#15`.
    public func extractDocumentNumber(from text: String) -> Int? {
        let patterns = [
            #"[Dd]oc(?:ument)?\.?\s+(\d+)"#,
            #"\bno\.?\s+(\d+)"#,
            #"#\s*(\d+)"#,
        ]
        for pattern in patterns {
            if let raw = firstCapture(pattern: pattern, in: text), let n = Int(raw) {
                return n
            }
        }
        return nil
    }

    // MARK: - Page Number Extraction

    /// Extracts a page number.
    ///
    /// Recognized forms: `p. 47`, `pp. 47`, `page 47`, `page no. 47`, `, 47.` (trailing).
    public func extractPageNumber(from text: String) -> Int? {
        let patterns = [
            #"\bpp?\.?\s+(\d+)"#,
            #"\bpages?\s+(\d+)"#,
        ]
        for pattern in patterns {
            if let raw = firstCapture(pattern: pattern, in: text), let n = Int(raw) {
                return n
            }
        }
        return nil
    }

    // MARK: - Title Fragment Extraction

    /// Extracts a title fragment for volume disambiguation.
    ///
    /// Strategy: after removing the series title prefix, subseries, volume identifier,
    /// and doc/page references, whatever remains is the title fragment.
    public func extractTitleFragment(from text: String, subseries: String?, volumeNumber: String?) -> String? {
        var working = text

        // Strip series prefix
        let prefixes = [
            "Foreign Relations of the United States",
            "Papers Relating to the Foreign Relations of the United States",
            "FRUS",
        ]
        for prefix in prefixes {
            if working.lowercased().hasPrefix(prefix.lowercased()) {
                working = String(working.dropFirst(prefix.count))
                break
            }
        }

        // Strip subseries
        if let sub = subseries {
            // Also strip the en-dash variant
            let enDashVariant = sub.replacingOccurrences(of: "-", with: "–")
            working = working.replacingOccurrences(of: sub, with: "")
            working = working.replacingOccurrences(of: enDashVariant, with: "")
        }

        // Strip volume number references
        if let vol = volumeNumber {
            working = working.replacingOccurrences(of: vol, with: "")
        }

        // Strip doc/page references and publication info
        let noisePatterns = [
            #"(?:Document|doc)\.?\s+\d+"#,
            #"pp?\.?\s+\d+"#,
            #"no\.?\s+\d+"#,
            #"\([^)]*\)"#,   // parenthetical publisher info
            #"eds?\.[^,]+"#, // editor list
            #"\bvol(?:ume)?\.?\s+[IVXivx\d]+"#,
        ]
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(working.startIndex..., in: working)
                working = regex.stringByReplacingMatches(in: working, range: range, withTemplate: "")
            }
        }

        // Collapse whitespace and strip punctuation at boundaries
        working = working
            .components(separatedBy: .init(charactersIn: ",.:;"))
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return working.count >= 4 ? working : nil
    }

    // MARK: - Private Helpers

    private func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// Normalizes a volume number string.
    ///
    /// - Arabic numerals → Roman numeral string (e.g. `"1"` → `"I"`)
    /// - Roman numerals → uppercased
    /// - Unrecognized forms → uppercased as-is
    private func normalizeVolumeNumber(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces).uppercased()
        // If it looks like an Arabic numeral, convert to Roman
        if let n = Int(trimmed), n > 0, n <= 39 {
            return arabicToRoman(n)
        }
        return trimmed
    }

    /// Converts an integer (1–39) to uppercase Roman numeral.
    private func arabicToRoman(_ n: Int) -> String {
        let values = [(10,"X"),(9,"IX"),(5,"V"),(4,"IV"),(1,"I")]
        var result = ""
        var remaining = n
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}
