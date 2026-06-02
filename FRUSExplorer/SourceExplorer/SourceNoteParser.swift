// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ParsedSourceNote

/// The result of parsing a FRUS source note string.
///
/// Cases map to the full range of archival citation patterns observed across the
/// FRUS corpus from 1905 to the present (~265,000 source notes analysed).
///
/// ## Era map
/// | Era | Volume range | Format | Example |
/// |-----|-------------|--------|---------|
/// | File No. | 1907–1920s | `File No. 3767/5.` | State Dept. bare file number |
/// | Decimal | 1910–1950s | `740.001121/10-1646` | Central decimal file |
/// | Narrative | 1950s–present | `Source: REPO, RG N, …` | Fully structured |
///
/// ## NARA queryability
/// - `.naraCollection` — queryable by `description.recordGroupNumber` + lot/series
/// - `.lotFile` — queryable by free-text lot number search
/// - `.presidentialLibrary` — queryable by library name + collection keywords
/// - `.centralFiles` / `.stateDepartmentFile` — use static URL path (no API key needed)
/// - `.ciaCollection` — not in NARA catalog
/// - `.previouslyPublished`, `.foreignGovernmentArchive`, `.unrecognized` — no query
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 118: `tryDecimalFile()` uses only regex-matched range
///   1.2 — Session 130: added `.naraCollection`, `.ciaCollection`; enriched `.lotFile`
///          with `recordGroup`; fixed era-1/2/3 pattern gaps; RG extraction from all
///          narrative notes; front-matter support via `ParsedVolumeSources`
public enum ParsedSourceNote: Sendable, Equatable {

    /// State Department central files identified by a decimal file number
    /// (e.g. `740.001121/10-1646`) or a bare "File No." number.
    /// Used in volumes from 1910–early 1950s.
    case centralFiles(recordGroup: String, fileIdentifier: String?)

    /// State Department lot file. Includes the RG number when it can be extracted
    /// (always RG 59 for State Dept. lot files).
    case lotFile(recordGroup: String?, lotNumber: String, fileIdentifier: String?)

    /// Presidential library collection (Kennedy, Johnson, Nixon, Ford, Carter,
    /// Reagan, Bush, Clinton, Hoover Institution, etc.).
    case presidentialLibrary(library: String, collection: String, fileIdentifier: String?)

    /// National Archives or Washington National Records Center record with an
    /// extractable record group number. The most queryable case via NARA API v2.
    case naraCollection(
        recordGroup: String,      // e.g. "59", "330", "306"
        series: String?,          // e.g. "Central Decimal File 1910–1929"
        lotFile: String?,         // e.g. "64 D 199"
        box: String?              // e.g. "736"
    )

    /// CIA accession-based citation using "Job" numbers (e.g. `Job 80-01795R`).
    /// CIA records are not in the public NARA catalog.
    case ciaCollection(jobNumber: String?, box: String?, description: String)

    /// A foreign government archive. Raw description is preserved for display.
    case foreignGovernmentArchive(description: String)

    /// A previously published source (books, journals, other FRUS volumes).
    case previouslyPublished(citation: String)

    /// No known pattern matched. Raw text is preserved.
    case unrecognized(rawText: String)
}

// MARK: - ParsedVolumeSources

/// Structured data extracted from a FRUS volume's front-matter sources list.
///
/// The front matter (`<div type="sources">` or similar) lists every archive and
/// collection cited in the volume. Parsing it at index time provides context that
/// enriches terse source notes (e.g. a bare "Lot 64 D 199" can be resolved to
/// its full repository and series name from the volume source list).
///
/// Version history:
///   1.0 — Session 130: initial implementation
public struct ParsedVolumeSources: Sendable {
    /// One entry from the front-matter sources list.
    public struct Entry: Sendable {
        public let repository: String?    // e.g. "National Archives and Records Administration"
        public let recordGroup: String?   // e.g. "59"
        public let lotFile: String?       // e.g. "64 D 199"
        public let seriesName: String?    // e.g. "Central Files"
        public let rawText: String
    }
    public let volumeId: String
    public let entries: [Entry]
}

// MARK: - ArchiveCitation (embedded in footnotes)

/// A structured archival citation extracted from editorial note prose.
///
/// Footnotes frequently embed citations like:
/// "…documentation is in National Archives, RG 59, Central Decimal File 1910–1929, Box 736…"
///
/// Version history:
///   1.0 — Session 130: initial implementation
public struct ArchiveCitation: Sendable {
    public let repository: String?
    public let recordGroup: String?
    public let seriesName: String?
    public let lotFile: String?
    public let box: String?
    public let rawText: String
}

// MARK: - SourceNoteParser

/// Parses plain-text FRUS source notes into structured `ParsedSourceNote` values.
///
/// ## Pattern strategy (most-specific to most-general)
///
/// 1. `File No.` variants (era 1) — bare inline file number → `.centralFiles`
/// 2. Inline lot file (`XYZ Files: Lot …`) → `.lotFile`
/// 3. Decimal file number (`862S.01/10-1646`) → `.centralFiles`
/// 4. Full narrative (`Source: …`) → repository-based dispatch:
///    - National Archives + RG number → `.naraCollection`
///    - CIA Job number → `.ciaCollection`
///    - Lot file phrase → `.lotFile`
///    - Presidential library name → `.presidentialLibrary`
///    - State Dept. central files → `.centralFiles`
///    - Foreign archive → `.foreignGovernmentArchive`
///    - Previously published → `.previouslyPublished`
/// 5. Fallback → `.unrecognized`
///
/// ## Footnote citation extraction
/// `extractCitations(from:)` finds embedded archival citations in editorial note prose.
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 118: `tryDecimalFile()` extracts only regex-matched range
///   1.2 — Session 130: added NARA/CIA cases; fixed era-1/2/3 patterns; RG extraction;
///          added `extractCitations(from:)` for footnote prose
public struct SourceNoteParser {

    public init() {}

    // MARK: - Public API

    /// Parses `sourceNote` and returns the best-matched `ParsedSourceNote`.
    public func parse(_ sourceNote: String) -> ParsedSourceNote {
        let trimmed = sourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized(rawText: sourceNote) }

        #if DEBUG
        print("[SourceExplorer] Parsing: \(trimmed.prefix(80))")
        #endif

        // Era 1 — "File No." variants (bare inline file number)
        if let result = tryFileNo(trimmed) { return result }

        // Era 3b — "XYZ Files: Lot XX D XXX, Box Y" (inline lot file)
        if let result = tryInlineLotFile(trimmed) { return result }

        // Era 2 — decimal file number (e.g. "862S.01/10-1646")
        if let result = tryDecimalFile(trimmed) { return result }

        // Era 1 variant — bare "File N/N" or bare decimal without letters
        if let result = tryBareFileNumber(trimmed) { return result }

        // Full narrative beginning with "Source:"
        if trimmed.hasPrefix("Source:") {
            return parseNarrative(trimmed)
        }

        return .unrecognized(rawText: trimmed)
    }

    /// Extracts embedded archival citations from editorial note body text.
    ///
    /// Returns an array because a single editorial note may reference multiple
    /// archival locations.  Returns an empty array when no recognizable patterns
    /// are found.
    public func extractCitations(from text: String) -> [ArchiveCitation] {
        var results: [ArchiveCitation] = []

        // Pattern 1: "National Archives[/WNRC], RG N, Series…"
        let naPattern = #"(?:National Archives(?:\s+and\s+Records\s+Administration)?|Washington\s+National\s+Records\s+Center),?\s*RG\s+(\d+\w*),?\s*([^.;,\(]{5,60}?)(?=[.,;\(]|$)"#
        if let regex = try? NSRegularExpression(pattern: naPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let rg = match.range(at: 1).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 1)) : nil
                let series = match.range(at: 2).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) : nil
                let rawRange = Range(match.range, in: text)
                let raw = rawRange.map { String(text[$0]) } ?? ""
                let lot = Self.lotFileRegex.flatMap { r in
                    let m = r.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw))
                    return m.flatMap { Range($0.range(at: 1), in: raw).map { String(raw[$0]) } }
                }
                let box = extractBoxNumber(from: raw)
                results.append(ArchiveCitation(
                    repository: "National Archives",
                    recordGroup: rg,
                    seriesName: series,
                    lotFile: lot,
                    box: box,
                    rawText: raw
                ))
            }
        }

        // Pattern 2: "Presidential Library, Collection name…"
        let libPattern = #"((?:[A-Z]\w+\s+)?(?:Kennedy|Johnson|Nixon|Ford|Carter|Reagan|Bush|Clinton|Obama|Eisenhower|Truman|Roosevelt|Hoover)\s+(?:Library|Presidential\s+Library|Institution))[,\s]+([^.;]{5,80}?)(?=[.,;]|$)"#
        if let regex = try? NSRegularExpression(pattern: libPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let library = match.range(at: 1).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 1)) : ""
                let collection = match.range(at: 2).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) : ""
                let rawRange = Range(match.range, in: text)
                let raw = rawRange.map { String(text[$0]) } ?? ""
                guard !library.isEmpty else { continue }
                results.append(ArchiveCitation(
                    repository: library,
                    recordGroup: nil,
                    seriesName: collection.isEmpty ? nil : collection,
                    lotFile: nil,
                    box: extractBoxNumber(from: raw),
                    rawText: raw
                ))
            }
        }

        return results
    }

    // MARK: - Era 1: Bare File Number Variants

    /// Handles: "File No. 3767/5.", "File No 1271", "Filed No. 774/245B",
    /// "File Not 7523" (typo), "File 4478/2–3."
    private func tryFileNo(_ text: String) -> ParsedSourceNote? {
        // Ordered from most-specific to least-specific
        let patterns: [(String, NSRegularExpression.Options)] = [
            (#"^File[d]?\s+No\.?\s*([\d\/–\-]+)"#, .caseInsensitive),   // File No. / Filed No. / File Not
            (#"^File\s+([\d\/–\-]+)"#, .caseInsensitive),                // File 774/42
        ]
        for (pat, opts) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pat, options: opts) else { continue }
            let ns = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: ns),
               let r = Range(match.range(at: 1), in: text) {
                let raw = String(text[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
                return .centralFiles(recordGroup: "RG-59", fileIdentifier: raw.isEmpty ? nil : raw)
            }
        }
        return nil
    }

    // MARK: - Era 3b: Inline Lot File

    private func tryInlineLotFile(_ text: String) -> ParsedSourceNote? {
        guard let lotRange = text.range(of: #"\bFiles?:\s*Lot\s+"#,
                                        options: .regularExpression) else { return nil }
        let afterLot = String(text[lotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        return .lotFile(recordGroup: "RG-59", lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Era 2: Decimal File

    private static let decimalFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[A-Z0-9]+\.[A-Z0-9]+/[\d–\-]+"#,
        options: .caseInsensitive
    )

    private func tryDecimalFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.decimalFileRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let matchRange = Range(match.range, in: text) else { return nil }
        let identifier = String(text[matchRange])
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
    }

    // MARK: - Era 1 Variant: Bare Decimal/File Numbers

    /// Handles bare decimal-like numbers: "5727/248.", "No. 8130/11."
    private static let bareNumberRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:No\.\s+)?(\d{3,6}/[\d–\-]+)\s*\.?\s*$"#,
        options: []
    )

    private func tryBareFileNumber(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.bareNumberRegex else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: String(text[r]))
    }

    // MARK: - Full Narrative (Era 3c / Era 4)

    private static let rgRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bRG\s+(\d+\w*)\b|\bRecord Group\s+(\d+)\b"#,
        options: .caseInsensitive
    )

    private static let lotFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bLot\s+([\w\s\-]+?D\s*\d+)\b"#,
        options: .caseInsensitive
    )

    private static let jobRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\bJob\s+([\w\-\/]+)"#,
        options: .caseInsensitive
    )

    /// Extracts the record group number from a text string.
    private func extractRG(from text: String) -> String? {
        guard let regex = Self.rgRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns) else { return nil }
        if match.range(at: 1).location != NSNotFound,
           let r = Range(match.range(at: 1), in: text) { return String(text[r]) }
        if match.range(at: 2).location != NSNotFound,
           let r = Range(match.range(at: 2), in: text) { return String(text[r]) }
        return nil
    }

    /// Extracts the lot file number from a text string.
    private func extractLotFile(from text: String) -> String? {
        guard let regex = Self.lotFileRegex else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespaces)
    }

    private func extractBoxNumber(from text: String) -> String? {
        let pat = #"\bBox\s+([\w\-\.]+\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: ns),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private func parseNarrative(_ text: String) -> ParsedSourceNote {
        let body = String(text.dropFirst("Source:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Previously published
        if matchesPreviouslyPublished(body) {
            return .previouslyPublished(citation: body)
        }

        // CIA Job number → .ciaCollection
        if let jobResult = tryCIACollection(body) { return jobResult }

        // National Archives or WNRC with an RG number → .naraCollection
        if let naraResult = tryNARACollection(body) { return naraResult }

        // Lot file in narrative (State Dept.) → .lotFile
        if let lotResult = tryNarrativeLotFile(body) { return lotResult }

        // Presidential library → .presidentialLibrary
        if let libResult = tryPresidentialLibrary(body) { return libResult }

        // State Dept. central files → .centralFiles
        if matchesCentralFiles(body) {
            let identifier = extractFirstIdentifier(body)
            return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
        }

        // Foreign government archive
        if matchesForeignArchive(body) {
            return .foreignGovernmentArchive(description: body)
        }

        return .unrecognized(rawText: text)
    }

    // MARK: - National Archives / WNRC

    private func tryNARACollection(_ body: String) -> ParsedSourceNote? {
        let naraKeywords = [
            "National Archives and Records Administration",
            "National Archives",
            "Washington National Records Center",
            "WNRC",
        ]
        guard naraKeywords.contains(where: { body.range(of: $0, options: .caseInsensitive) != nil }) else {
            return nil
        }
        // Extract record group — required to distinguish from other uses of "National Archives"
        guard let rg = extractRG(from: body) else {
            // No RG number — fall through to let lot file or central files handle it
            return nil
        }
        // Extract optional components
        let lot    = extractLotFile(from: body)
        let box    = extractBoxNumber(from: body)
        let series = extractSeriesName(from: body, afterRG: rg)
        return .naraCollection(recordGroup: rg, series: series, lotFile: lot, box: box)
    }

    /// Extracts a series name from the body after the RG number.
    private func extractSeriesName(from body: String, afterRG rg: String) -> String? {
        // Look for text immediately following "RG N," — up to the next comma or lot file reference
        let rgPattern = "RG\\s+\(NSRegularExpression.escapedPattern(for: rg))\\s*,\\s*(.{5,60}?)(?:,|\\bLot\\b|$)"
        guard let regex = try? NSRegularExpression(pattern: rgPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              match.range(at: 1).location != NSNotFound,
              let r = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - CIA

    private func tryCIACollection(_ body: String) -> ParsedSourceNote? {
        guard body.range(of: #"\bCentral Intelligence Agency\b|^CIA\b"#,
                         options: .regularExpression) != nil else { return nil }
        let jobNumber: String?
        if let regex = Self.jobRegex {
            let ns = NSRange(body.startIndex..., in: body)
            if let match = regex.firstMatch(in: body, range: ns),
               let r = Range(match.range(at: 1), in: body) {
                jobNumber = String(body[r])
            } else {
                jobNumber = nil
            }
        } else {
            jobNumber = nil
        }
        let box = extractBoxNumber(from: body)
        return .ciaCollection(jobNumber: jobNumber, box: box, description: body)
    }

    // MARK: - Lot File (narrative)

    private func tryNarrativeLotFile(_ body: String) -> ParsedSourceNote? {
        guard let lotKeyRange = body.range(of: #"\bLot\s+"#, options: .regularExpression) else { return nil }
        let afterLot = String(body[lotKeyRange.upperBound...])
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        // Always RG 59 for State Dept. lot files; other RG lot files would have been
        // caught by tryNARACollection() already (they include an explicit RG number).
        return .lotFile(recordGroup: "RG-59", lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Presidential Library

    private func tryPresidentialLibrary(_ body: String) -> ParsedSourceNote? {
        let libraryKeywords = [
            "Kennedy Library",
            "Johnson Library",
            "Nixon Presidential Library", "Nixon Library",
            "Ford Library",
            "Carter Library",
            "Reagan Library",
            "George H.W. Bush Library", "Bush Library",
            "Clinton Library",
            "Obama Library",
            "Eisenhower Library",
            "Truman Library",
            "Roosevelt Library",
            "Hoover Institution",
            "Presidential Library",
            "National Defense University",
        ]
        for keyword in libraryKeywords {
            guard let keyRange = body.range(of: keyword, options: .caseInsensitive) else { continue }
            // Library name = text from start to end of keyword, first segment
            let libraryRaw = String(body[body.startIndex..<keyRange.upperBound])
            let library = libraryRaw.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? keyword

            // Collection = next comma-delimited segment
            let remainder = String(body[keyRange.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: ",").union(.whitespaces))
            let collection = remainder.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? ""

            let fileId = extractBoxOrFileString(from: remainder)
            return .presidentialLibrary(library: library, collection: collection, fileIdentifier: fileId)
        }
        return nil
    }

    // MARK: - Central Files Keywords

    private func matchesCentralFiles(_ body: String) -> Bool {
        let keywords = [
            "Department of State", "Central Foreign Policy File",
            "Central Files", "Record Group 59", "RG 59", "RG-59",
        ]
        return keywords.contains { body.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func matchesForeignArchive(_ body: String) -> Bool {
        let keywords = [
            "Archivo", "Archiv", "Foreign Ministry", "Quai d'Orsay",
            "Public Record Office", "National Archives of", "Bundesarchiv",
            "Ministère", "Ministry of Foreign Affairs",
        ]
        return keywords.contains { body.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func matchesPreviouslyPublished(_ body: String) -> Bool {
        let keywords = [
            "Foreign Relations of the United States",
            "Department of State Bulletin",
            "Public Papers of the Presidents",
            "Ibid", "ibid",
        ]
        return keywords.contains { body.hasPrefix($0) }
    }

    // MARK: - Utility

    private func splitLotAndBox(_ text: String) -> (lot: String, box: String?) {
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ",."))
        let lot   = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let remainder = parts.dropFirst().joined(separator: ",")
        return (lot: lot, box: extractBoxOrFileString(from: remainder))
    }

    private func extractBoxOrFileString(from text: String) -> String? {
        for keyword in ["Box", "Folder", "File"] {
            if let r = text.range(of: keyword, options: .caseInsensitive) {
                let fragment = String(text[r.lowerBound...])
                    .components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces)
                if let f = fragment, !f.isEmpty { return f }
            }
        }
        return nil
    }

    private func extractFirstIdentifier(_ body: String) -> String? {
        let segments = body.components(separatedBy: ",")
        for segment in segments.dropFirst() {
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(where: { $0.isNumber }) && trimmed.count < 60 {
                return trimmed
            }
        }
        return nil
    }
}
