// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LotFileCitation

/// A distinct State Department lot file referenced in the FRUS corpus.
///
/// The `normalizedLot` is the compact, upper-cased form (`63D135`) used as the index key
/// and produced by the app's runtime lot parsing, so both sides agree. The record group
/// follows the letter designator: `D` → RG 59 (central-files lot series), `F` → RG 84
/// (diplomatic post records).
public struct LotFileCitation: Sendable, Hashable {
    public let normalizedLot: String
    public let recordGroup: String

    public init(normalizedLot: String, recordGroup: String) {
        self.normalizedLot = normalizedLot
        self.recordGroup = recordGroup
    }
}

// MARK: - LotFileCitationExtractor

/// Extracts and normalizes State Department lot file numbers from citation text.
///
/// Matches the `Lot <number>` form across inline (`CU Files: Lot 63D135`), narrative
/// (`…RG 59, … Lot 64 D 199`), and dashed (`Lot 61–D 146`) variants, tolerating spaces and
/// hyphens between the parts. Normalization (strip spaces/dashes, upper-case) yields the
/// same key the app derives at runtime.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 3 — lot files
public enum LotFileCitationExtractor {

    // `Lot` then 2–3 digits, an optional dash, a single letter, optional spaces, digits.
    private static let lotRegex = try? NSRegularExpression(
        pattern: #"\bLot\s+(\d{2,3}\s*[-–]?\s*[A-Za-z]\s*\d+)"#,
        options: [.caseInsensitive])

    /// Returns every distinct lot citation found in `text` (a citation may name several).
    public static func citations(in text: String) -> [LotFileCitation] {
        guard let regex = lotRegex else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var result: [LotFileCitation] = []
        for m in matches {
            let raw = ns.substring(with: m.range(at: 1))
            let normalized = normalize(raw)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(LotFileCitation(normalizedLot: normalized,
                                          recordGroup: recordGroup(forNormalized: normalized)))
        }
        return result
    }

    /// Compact upper-cased form: drop spaces and dashes (`61–D 146` → `61D146`).
    public static func normalize(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "—", with: "")
    }

    /// `F`-designator lot files are RG 84 (diplomatic post records); all others RG 59.
    public static func recordGroup(forNormalized lot: String) -> String {
        // The designator is the single letter between the leading and trailing digits.
        if let r = lot.range(of: #"^\d{2,3}([A-Z])"#, options: .regularExpression) {
            let letter = lot[lot.index(before: r.upperBound)]
            return letter == "F" ? "84" : "59"
        }
        return "59"
    }
}
