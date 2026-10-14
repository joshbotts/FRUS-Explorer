// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TEIPublicationYear

/// The year a volume was published, as its TEI header states it, which a citation prefers over the
/// manifest's `publicationDate` (e67bed9).
///
/// The manifest's date can be the volume's coverage range rather than its print date, so a citation
/// that read it printed a document's coverage-range start year, "1969", where the volume was printed
/// in 2010. The header's `<publicationStmt>` states the print year. Each host keeps its own fallback
/// for a volume whose header states none.
///
/// Version history:
///   1.0 — FRUS Explorer Light: the scan iOS's `DocumentViewModel` and the Mac's citation popover
///          (`DocumentExportSupport`) each kept a copy of, moved into the kit for the web edition's
///          citations
public enum TEIPublicationYear {

    /// How much of a volume's file is read: the first 8 KB, which always cover the `teiHeader`.
    static let headerPrefixBytes = 8_192

    /// The publication year the TEI file at `url` states, or `nil` when it states none, when the
    /// file cannot be read, or when its first 8 KB do not decode as UTF-8.
    ///
    /// - Parameter url: A volume's TEI file.
    /// - Returns: The year, four digits.
    public static func read(from url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: headerPrefixBytes)
        let n = stream.read(&buffer, maxLength: buffer.count)
        guard n > 0, let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }
        return year(inHeader: text)
    }

    /// The publication year `text`, the start of a TEI file, states in its `<publicationStmt>`: the
    /// year of `<date @when>`, the authoritative ISO publication date, or failing that a bare year as
    /// an element's text (`<date>2010</date>`), each only between 1751 and 2099.
    ///
    /// - Parameter text: The start of a TEI file, its header included.
    /// - Returns: The year, four digits, or `nil` when the statement names none.
    public static func year(inHeader text: String) -> String? {
        guard let blockStart = text.range(of: "<publicationStmt"),
              let blockEnd = text.range(of: "</publicationStmt>"),
              blockStart.lowerBound < blockEnd.lowerBound else { return nil }
        let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])
        // Prefer @when="YYYY" — most authoritative, always the actual publication year.
        if let yr = firstCapture(#"when="(\d{4})""#, in: block),
           let y = Int(yr), y > 1750, y < 2100 { return yr }
        // Fall back to bare year as text content, e.g. <date>2010</date>.
        if let yr = firstCapture(#">(\d{4})\s*<"#, in: block),
           let y = Int(yr), y > 1750, y < 2100 { return yr }
        return nil
    }

    /// The first capture group of `pattern`'s first match in `text`, or `nil`.
    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
