// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Normalizes country / post names into canonical geographic keys so a FRUS chapter name
/// (`Argentine Republic`) and a NARA file-unit / roll name (`Argentina`) resolve to the
/// same key, and combined rolls (`Uruguay and Paraguay`) expand to multiple keys.
///
/// The same normalizer runs on both sides of the lookup — the harvested index keys and the
/// app's classifier input — so they must agree. A canonical key is lower-cased, with
/// surrounding noise (a `Volume N:` prefix, trailing punctuation) stripped and internal
/// whitespace collapsed; recognized aliases map to a single preferred key.
///
/// The alias table is a seed from the reference data and common historical names; it will
/// be extended once the diplomatic-series survey reveals the real file-unit vocabulary.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 — seed table
public enum GeoKeyNormalizer {

    /// Maps a normalized variant → preferred canonical key.
    static let aliases: [String: String] = [
        "argentine republic": "argentina",
        "argentine confederation": "argentina",
        "hawaiian islands": "hawaii",
        "sandwich islands": "hawaii",
        "the netherlands": "netherlands",
        "great britain and ireland": "great britain",
        "united kingdom": "great britain",
        "two sicilies": "two sicilies",
        "kingdom of the two sicilies": "two sicilies",
        "german empire": "germany",
        "german states": "germany",
        "ottoman empire": "turkey",
        "ottoman porte": "turkey",
        "persia": "iran",
        "siam": "thailand",
        "corea": "korea",
        "santo domingo": "dominican republic",
        "san domingo": "dominican republic",
    ]

    /// Returns the canonical geographic key(s) for a raw country/post string.
    ///
    /// Splits combined names (`Uruguay and Paraguay`, `Brazil & Argentina`) into multiple
    /// keys, strips a leading `Volume N:` segment, applies the alias table, and lower-cases.
    /// Returns `[]` when no usable name remains (e.g. an empty or purely numeric string).
    public static func keys(from raw: String) -> [String] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip a leading "Volume 18:" / "Vol. 3:" segment.
        if let r = text.range(of: #"^\s*Vol(?:ume|\.)?\s*\d+\s*:\s*"#,
                              options: [.regularExpression, .caseInsensitive]) {
            text = String(text[r.upperBound...])
        }

        // A trailing ": <dates>" segment, if any, is not part of the name.
        if let colon = text.firstIndex(of: ":") {
            text = String(text[..<colon])
        }

        return splitConjunctions(text)
            .map(canonicalize)
            .filter { !$0.isEmpty }
    }

    /// Normalizes a single already-isolated name to its canonical key (no splitting).
    public static func canonicalize(_ name: String) -> String {
        let collapsed = name
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;")))
            .lowercased()
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
        return aliases[collapsed] ?? collapsed
    }

    /// Splits `A and B`, `A & B`, `A, B` conjunction forms into component names.
    private static func splitConjunctions(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: " & ", with: " and ")
            .replacingOccurrences(of: ", ", with: " and ")
            .components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
