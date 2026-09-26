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
/// carries that prose's own subseries (with whether it followed the series' name), volume and
/// part beside the reference, for the matcher to check the document it finds against:
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
///   1.4 — #1474 review round 3: the subseries is the year the series names (`FRUS, 1961–1963`),
///          not the first year in the text, which in a footnote opening with the document's date
///          is that date's year
///   1.5 — #1474 review round 4: the series' name ends at a word boundary, so "Frustrated" and
///          "Foreign Relationship" are not read as the series
///   1.6 — #1474 review round 5: the prose beside a link says how its subseries was read — after
///          the series' name, or as the text's first year (`CitationVolumeFields.subseriesReading`)
///   1.7 — #1507: a year follows the series' name only with no other number between them, every
///          place the series is named is tried, and otherwise a range is read before a bare year;
///          #1505: the title fragment keeps the series' name and drops the editors and a
///          Turabian publication statement, so the app's own citations reach their own volumes
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
    ///
    /// The year is the one the series names (#1474 review round 3): the first year or range AFTER
    /// the series' name — "FRUS" or "Foreign Relations of the United States", or, when the text
    /// has neither, "Foreign Relations" — so that a subtitle standing between them is passed over
    /// (`…, Diplomatic Papers, 1943`, `…, The Conferences at Washington, 1941–1942`). Only a text
    /// naming the series nowhere, or with no year following its name, falls back to the text's
    /// first range, or with none its first year (#1507, `readSubseries(from:)`). The commonest
    /// footnote opens with the document's own date — `Memorandum of
    /// Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84` — and the first-year
    /// rule read that as the subseries 1962, which no volume carries: a plain paste came back as
    /// a best guess naming "subseries 1962", and the same note beside a history.state.gov link was
    /// told its text named a different volume. The full name outranks the bare "Foreign Relations"
    /// so that a committee named before the date (`Senate Committee on Foreign Relations, May 5,
    /// 1962, FRUS, 1961–1963`) is not read as the series. A text that opens with the series title
    /// — as each of the app's own three formats does — has no year before the name, so both rules
    /// read the same year in it. The name is a whole word on both sides (#1474 review round 4):
    /// "Frustrated" and "Foreign Relationship" name no series.
    ///
    /// The prose beside a history.state.gov link often names the series nowhere — the link is its
    /// only "frus" — so a dated note there still reads its date's year. The parser records which
    /// of the two rules read the year (`readSubseries(from:)`, #1474 review round 5), and the
    /// matcher checks the text beside a link against the link's volume for its year when the year
    /// followed the series' name, or when it is a range (#1507).
    public func extractSubseries(from text: String) -> String? {
        readSubseries(from: text)?.subseries
    }

    /// The year `extractSubseries(from:)` reads, and which rule read it (#1474 review round 5):
    /// `.afterSeriesName` when it is the first year or range after the series' name with no other
    /// number between them, `.firstYear` when the text names the series nowhere, or names it with
    /// no such year after it, and the text's first range — or with none its first year — was taken
    /// instead.
    ///
    /// The difference decides what the year is. After the name it names a volume of the series
    /// (`FRUS, 1961–1963`); otherwise a single year is often the date a note opens with
    /// (`Memorandum of Conversation, Moscow, May 5, 1962, vol. V, doc. 84, …/frus1961-63v05`), which
    /// is the document's date and names no volume — Volume V of 1961–63 opens with a National
    /// Intelligence Estimate dated December 1, 1960. The matcher checks a link's volume against
    /// the first kind, and against a range of the second (`CitationVolumeFields.subseriesReading`).
    ///
    /// Two rules, both #1507's, keep a date from being read as the subseries:
    /// - **The year must follow the name with no other number between.** Words may stand there —
    ///   166 of the 553 bundled titles put words there (`, Diplomatic Papers,`, `, The Paris Peace
    ///   Conference,`), and a note citing a volume of its own subseries gives the volume and its
    ///   title first (`Foreign Relations, volume XV, Soviet Union, June 1972–August 1974`) — but a
    ///   number marks what follows as a date or a locator's: `FRUS, vol. V, doc. 84, Memorandum,
    ///   May 5, 1962` and `Senate Committee on Foreign Relations, May 5, 1962` name no year. Every
    ///   place the series is named is tried, the full names first, so `…the Senate Foreign
    ///   Relations Committee on June 10, 1949, … see Foreign Relations, 1950, vol. ii` reads 1950.
    ///   (The 59 pre-1918 titles that print their transmittal date there — `…, December 3, 1877` —
    ///   read the same year through the fallback.)
    /// - **Otherwise a range comes before a bare year.** A range names a subseries (`1961–1963`);
    ///   a bare year is as often the date a note opens with (`Memorandum, May 5, 1962`), so it is
    ///   read only when the text holds no range. `Memorandum, May 5, 1962, 1961–1963, vol. V`
    ///   reads 1961–63, where it read 1962 and came back a best guess under a note saying the
    ///   citation did not name its volume.
    ///
    /// Measured over the 30,204 clauses of the corpus's own footnotes that name the series and a
    /// year (corpus `550a8c5c5`), against the 27,016 that print the name directly before a year:
    /// the rule this replaces read that year for 26,960 and these rules for 26,976, and the 25
    /// volume-first citations above read their title's year under both. A narrower gap — no
    /// volume or document locator and no month either — lost 4 of those 25. The app's own three
    /// citation formats of all 553 volumes, marked and plain, read the same year as before.
    private func readSubseries(
        from text: String
    ) -> (subseries: String, reading: CitationVolumeFields.SubseriesReading)? {
        // Pattern: 4-digit year followed by optional (en dash or hyphen) + (2 or 4 digit year)
        let pattern = #"(1[89]\d{2})(?:[–\-](\d{4}|\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let whole = NSRange(text.startIndex..., in: text)

        // Where the series is named: its full name first, then the bare "Foreign Relations".
        var named: NSTextCheckingResult?
        let series = #"(?<![A-Za-z])(?:FRUS|Foreign\s+Relations(\s+of\s+the\s+United\s+States)?)(?![A-Za-z])"#
        if let seriesRegex = try? NSRegularExpression(pattern: series, options: .caseInsensitive) {
            let names = seriesRegex.matches(in: text, range: whole)
            let isFull = { (name: NSTextCheckingResult) -> Bool in
                name.range(at: 1).location != NSNotFound
                    || (Range(name.range, in: text).map { text[$0].uppercased() == "FRUS" } ?? false)
            }
            for name in names.filter(isFull) + names.filter({ !isFull($0) }) {
                let end = NSMaxRange(name.range)
                if let year = regex.firstMatch(in: text, range: NSRange(location: end, length: whole.length - end)),
                   let gap = Range(NSRange(location: end, length: year.range.location - end), in: text),
                   !text[gap].contains(where: \.isNumber) {
                    named = year
                    break
                }
            }
        }
        let years = named == nil ? regex.matches(in: text, range: whole) : []
        guard let match = named
                ?? years.first(where: { $0.range(at: 2).location != NSNotFound })
                ?? years.first else {
            return nil
        }
        let reading: CitationVolumeFields.SubseriesReading = named != nil ? .afterSeriesName : .firstYear

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
            return ("\(startYear)-\(endNormalized)", reading)
        }
        return (startYear, reading)
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
    /// The subseries goes with how it was read (#1474 review round 5), because only a year read
    /// after the series' name is checked: the prose is read without the link, which is often the
    /// note's only "frus", and its first year is then the date the note opens with.
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
            let year = readSubseries(from: prose)
            let named = CitationVolumeFields(subseries: year?.subseries,
                                             subseriesReading: year?.reading ?? .afterSeriesName,
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
        print("[CitationParser] link volume=\(volumeId) segment=\(link.segment ?? "-") page=\(pageNumber.map(String.init) ?? "-") document=\(documentNumber.map(String.init) ?? "-") proseSubseries=\(reference.prose?.subseries ?? "-") read=\(reference.prose?.subseriesReading.map { "\($0)" } ?? "-")")
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
    /// Strategy: after removing the editors, the publication statement, the subseries, the volume
    /// identifier, and doc/page references, whatever remains is the title fragment.
    ///
    /// The series' name stays in it (#1505), and "FRUS" is spelled out. The name used to be removed
    /// when the text began with it, which a plain-text copy of the app's own citation does and its
    /// italic-marked form (`_Foreign Relations of the United States_, …`) does not — so the two
    /// forms of one citation reached different volumes, and the plain form, the one Copy Citation
    /// puts on the clipboard, could not print any title whole
    /// (`CitationMatchingEngine.wholeTitlesFirst`): `frus1919v01`'s came back as the Paris Peace
    /// Conference's Volume I.
    public func extractTitleFragment(from text: String, subseries: String?, volumeNumber: String?) -> String? {
        // "FRUS" is no title's word, but it names the series as the full name does (#1505): spelled
        // out, `FRUS, 1952–1954, Iran, 1951–1954` matches the Iran retrospective's title whole.
        var working = text.replacingOccurrences(of: #"(?<![A-Za-z])FRUS(?![A-Za-z])"#,
                                                with: "Foreign Relations of the United States",
                                                options: [.regularExpression, .caseInsensitive])

        // Strip the editors and the publication statement (#1505) — before the subseries, whose
        // removal would take the year the publication statement ends with.
        for pattern in [Self.editorStatement, Self.publicationStatement] {
            working = working.replacingOccurrences(of: pattern, with: "",
                                                   options: [.regularExpression, .caseInsensitive])
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

    /// A citation's editors, from `ed.`, `eds.` or `edited by` to the publication parenthetical
    /// or the end of the text (#1505) — in all three of the app's formats the title comes before
    /// them. The names are no title's words, and before #1505 they stayed in the title fragment
    /// in Chicago and Turabian form (`edited by`) and after the first comma in the history.state.gov
    /// form's `eds. A, B, and C`, so the fragment matched no title whole and the lookup counted
    /// shared words instead: in `frus1943China`'s Chicago citation the "and" of "Noble and
    /// Perkins" tied the Cairo–Tehran volume's title ("Cairo and Tehran") with China's, and the
    /// manifest order put Cairo–Tehran first.
    static let editorStatement = #"\b(?:eds?\.|edited\s+by)\s[^()]*?(?=\s*\(|$)"#

    /// The publication statement a Turabian citation prints outside parentheses, `Washington,
    /// D.C.: Government Printing Office, 1864` (#1505). Its words are no title's, so before #1505
    /// the fragment of a pre-1906 part volume matched no title whole, and the print year alone
    /// chose the volume: 13 of the parts between `frus1863p1` and `frus1867p2` came back as the
    /// next print year's volumes. Anchored on Washington, where every FRUS volume was published,
    /// so a title that names Washington (`The Conferences at Washington, 1941–1942`) keeps it.
    static let publicationStatement = #"\bWashington(?:,?\s*D\.?\s*C\.?)?\s*:.*?,\s*(?:1[89]|20)\d{2}\b"#

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
