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
/// Cases map directly to the provenance-switching table in Specification §13.
///
/// Version history:
///   1.0 — Session 23: initial implementation
public enum ParsedSourceNote: Sendable, Equatable {

    /// State Department central files, e.g. decimal file "862S.01/10-1646" or
    /// "File No. 17529" (pre-1912 era) or a full narrative citing "Central Foreign
    /// Policy File" / "Central Files". `fileIdentifier` is the raw numeric/decimal
    /// string or null when it cannot be extracted from a narrative note.
    case centralFiles(recordGroup: String, fileIdentifier: String?)

    /// State Department lot file. `lotNumber` is the lot number (e.g. "61-D 146").
    /// `fileIdentifier` carries the box number or other sub-identifier when present.
    case lotFile(lotNumber: String, fileIdentifier: String?)

    /// Presidential library collection.
    /// `library` is the institution name (e.g. "Kennedy Library").
    /// `collection` is the file group or series name.
    /// `fileIdentifier` is the box/file number if present.
    case presidentialLibrary(library: String, collection: String, fileIdentifier: String?)

    /// A foreign government archive. Raw description is preserved for display.
    case foreignGovernmentArchive(description: String)

    /// A previously published source (books, journals, other FRUS volumes).
    case previouslyPublished(citation: String)

    /// No known pattern matched. Raw text is preserved.
    case unrecognized(rawText: String)
}

// MARK: - SourceNoteParser

/// Parses plain-text FRUS source notes into structured `ParsedSourceNote` values.
///
/// ## Pattern Strategy
/// Patterns are tried from most-specific to most-general:
///
/// 1. **Era 2** (`rend="inline"`, starts with "File No.") — decimal/bare file number → `.centralFiles`
/// 2. **Era 3b** (inline, contains "Files: Lot") — lot file citation → `.lotFile`
/// 3. **Era 3a** (inline, decimal file pattern e.g. `862S.01/10-1646`) → `.centralFiles`
/// 4. **Full narrative** (starts with "Source:") — repository-based dispatch:
///    - Lot file phrase → `.lotFile`
///    - Presidential library name → `.presidentialLibrary`
///    - State Dept. central files → `.centralFiles`
///    - Foreign archive → `.foreignGovernmentArchive`
///    - Previously published → `.previouslyPublished`
/// 5. **Fallback** → `.unrecognized`
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
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

        // Era 2 — "File No. XXXX" (bare inline file number)
        if let result = tryFileNo(trimmed) { return result }

        // Era 3b — "XYZ Files: Lot XX-D XXX, Box YYYY" (lot file, inline)
        if let result = tryInlineLotFile(trimmed) { return result }

        // Era 3a — decimal file number (e.g. "862S.01/10-1646")
        if let result = tryDecimalFile(trimmed) { return result }

        // Era 3c / Era 4 — full narrative beginning with "Source:"
        if trimmed.hasPrefix("Source:") {
            return parseNarrative(trimmed)
        }

        return .unrecognized(rawText: trimmed)
    }

    // MARK: - Era 2: Bare File Number

    private func tryFileNo(_ text: String) -> ParsedSourceNote? {
        guard text.hasPrefix("File No.") else { return nil }
        // Strip trailing period; extract numeric portion
        let raw = text
            .dropFirst("File No.".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: raw.isEmpty ? nil : raw)
    }

    // MARK: - Era 3b: Inline Lot File

    private func tryInlineLotFile(_ text: String) -> ParsedSourceNote? {
        guard let lotRange = text.range(of: "Files: Lot", options: .caseInsensitive) else {
            return nil
        }
        // Everything after "Lot " is the lot number (optionally followed by ", Box N")
        let afterLot = String(text[lotRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        let (lotNumber, box) = splitLotAndBox(afterLot)
        return .lotFile(lotNumber: lotNumber, fileIdentifier: box)
    }

    // MARK: - Era 3a: Decimal File

    // Decimal file pattern: letters/digits, a period, digits, a slash, digits–digits
    // Examples: 862S.01/10-1646   033.4111/8-2554   711.94/3-251
    private static let decimalFileRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[A-Z0-9]+\.[A-Z0-9]+/[\d–\-]+"#,
        options: .caseInsensitive
    )

    private func tryDecimalFile(_ text: String) -> ParsedSourceNote? {
        guard let regex = Self.decimalFileRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard regex.firstMatch(in: text, range: range) != nil else { return nil }
        // Trim trailing period
        let identifier = text.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
    }

    // MARK: - Full Narrative (Era 3c / Era 4)

    private func parseNarrative(_ text: String) -> ParsedSourceNote {
        // Strip "Source:" prefix and leading whitespace
        let body = String(text.dropFirst("Source:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Previously published: starts with "Foreign Relations" or well-known serial titles
        if matchesPreviouslyPublished(body) {
            return .previouslyPublished(citation: body)
        }

        // Lot file in narrative
        if let lotResult = tryNarrativeLotFile(body) { return lotResult }

        // Presidential library
        if let libResult = tryPresidentialLibrary(body) { return libResult }

        // State Dept. central files keywords
        if matchesCentralFiles(body) {
            let identifier = extractFirstIdentifier(body)
            return .centralFiles(recordGroup: "RG-59", fileIdentifier: identifier)
        }

        // Foreign government archive heuristics
        if matchesForeignArchive(body) {
            return .foreignGovernmentArchive(description: body)
        }

        return .unrecognized(rawText: text)
    }

    // MARK: - Narrative Helpers

    private func tryNarrativeLotFile(_ body: String) -> ParsedSourceNote? {
        // Patterns: "Lot XX-D XXX" or "Files: Lot XX-D XXX"
        guard let lotKeyRange = body.range(of: #"\bLot\s+"#,
                                           options: .regularExpression) else { return nil }
        let afterLot = String(body[lotKeyRange.upperBound...])
        let (lotNumber, box) = splitLotAndBox(afterLot)
        guard !lotNumber.isEmpty else { return nil }
        return .lotFile(lotNumber: lotNumber, fileIdentifier: box)
    }

    private func tryPresidentialLibrary(_ body: String) -> ParsedSourceNote? {
        let libraryKeywords = [
            "Kennedy Library",
            "Johnson Library",
            "Nixon Presidential Library",
            "Nixon Library",
            "Ford Library",
            "Carter Library",
            "Reagan Library",
            "Bush Library",
            "Clinton Library",
            "Obama Library",
            "Eisenhower Library",
            "Truman Library",
            "Roosevelt Library",
            "Hoover Institution",
            "Presidential Library",
        ]
        for keyword in libraryKeywords {
            if let keyRange = body.range(of: keyword, options: .caseInsensitive) {
                let library = String(body[body.startIndex..<keyRange.upperBound])
                    .components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces) ?? keyword

                // Collection is the next comma-delimited segment
                let remainder = String(body[keyRange.upperBound...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",").union(.whitespaces))
                let collection = remainder
                    .components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""

                // Box/file identifier
                let fileId = extractBoxOrFile(from: remainder)

                return .presidentialLibrary(
                    library: library,
                    collection: collection,
                    fileIdentifier: fileId
                )
            }
        }
        return nil
    }

    private func matchesCentralFiles(_ body: String) -> Bool {
        let centralKeywords = [
            "Department of State",
            "Central Foreign Policy File",
            "Central Files",
            "National Archives",
            "Record Group 59",
            "RG 59",
            "RG-59",
        ]
        return centralKeywords.contains { body.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func matchesForeignArchive(_ body: String) -> Bool {
        let foreignKeywords = [
            "Archivo",
            "Archives",
            "Archiv",
            "Foreign Ministry",
            "Quai d'Orsay",
            "Public Record Office",
            "National Archives of",
            "Bundesarchiv",
            "Ministère",
            "Ministry of Foreign Affairs",
        ]
        return foreignKeywords.contains { body.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func matchesPreviouslyPublished(_ body: String) -> Bool {
        let publishedKeywords = [
            "Foreign Relations of the United States",
            "Department of State Bulletin",
            "Public Papers of the Presidents",
            "Ibid",
            "ibid",
        ]
        return publishedKeywords.contains { body.hasPrefix($0) }
    }

    // MARK: - Utility

    /// Splits "61-D 146, Box 4581" into ("61-D 146", "Box 4581").
    private func splitLotAndBox(_ text: String) -> (lot: String, box: String?) {
        // Take up to first comma or period
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ",."))
        let lot = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let remainder = parts.dropFirst().joined(separator: ",")
        let box = extractBoxOrFile(from: remainder)
        return (lot: lot, box: box)
    }

    private func extractBoxOrFile(from text: String) -> String? {
        let keywords = ["Box", "File", "Folder"]
        for keyword in keywords {
            if let r = text.range(of: keyword, options: .caseInsensitive) {
                let fragment = String(text[r.lowerBound...])
                    .components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces)
                return fragment?.isEmpty == false ? fragment : nil
            }
        }
        return nil
    }

    /// Extracts the first alphanumeric identifier token after the repository name.
    private func extractFirstIdentifier(_ body: String) -> String? {
        // Look for a comma-delimited segment that contains digits
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
