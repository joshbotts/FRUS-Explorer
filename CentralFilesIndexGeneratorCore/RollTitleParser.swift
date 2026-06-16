// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Parses NARA Catalog roll (item) titles into structured ranges.
///
/// Roll-title formats are heterogeneous *per series* (see Finding 2 in
/// `Planning/BigPicture-Pre1910-CentralFiles.md`), so each series gets its own parser.
/// Phase 1 implements only the Numerical File grammar; country-arranged grammars
/// (`Volume {n}: {country}: {dates}`, `{dates}`, etc.) arrive with later phases.
///
/// Version history:
///   1.0 — Session 2026-06-15: Numerical File grammar
public enum RollTitleParser {

    /// Matches a Numerical File roll title and returns its inclusive case range.
    ///
    /// Grammar: an optional `Numerical File:` prefix, then two integers separated by a
    /// hyphen or en-dash, e.g. `Numerical File: 7179-7187` or `682–699`. Surrounding
    /// whitespace and a trailing period are tolerated. Returns `nil` for any title that
    /// is not a case range (the series and file-unit records, finding aids, etc.), which
    /// is how non-roll records are filtered out of the harvest.
    ///
    /// - Returns: `(start, end)` with `start <= end`, or `nil`.
    public static func numericalFileCaseRange(from title: String) -> (start: Int, end: Int)? {
        guard let regex = Self.numericalRangeRegex else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let r1 = Range(match.range(at: 1), in: title),
              let r2 = Range(match.range(at: 2), in: title),
              let a = Int(title[r1]),
              let b = Int(title[r2])
        else { return nil }
        return a <= b ? (a, b) : (b, a)
    }

    /// `Numerical File: 7179-7187`, `Numerical File: 682–699`, or a bare `7179-7187`.
    /// The optional label is matched case-insensitively; the separator may be a hyphen
    /// or en-dash with optional surrounding spaces.
    private static let numericalRangeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:\s*Numerical\s+File\s*:?\s*)?(\d+)\s*[-–]\s*(\d+)\s*\.?\s*$"#,
        options: [.caseInsensitive]
    )
}
