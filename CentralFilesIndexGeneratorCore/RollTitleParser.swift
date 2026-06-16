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
///   1.0 — Session 2026-06-15: Numerical File grammar (clean `N-N` form)
///   1.1 — Session 2026-06-15: rewritten against the live M862 harvest, which revealed
///         many richer real-world title forms (sub-document boundaries `21701-21740/125`,
///         roll-split markers `23600 (S)-23640` / `(R)`, single-case rolls `22346`,
///         `…/126-End of case`, stray-leading-dash and space-separated ranges). The case
///         number is now extracted from the first integer on each side of the range.
public enum RollTitleParser {

    /// Characters NARA uses (or mis-renders) as the range separator.
    private static let dashCharacters = CharacterSet(charactersIn: "-–—‐")

    /// Matches and strips the `Numerical File:` roll-title label (colon required).
    ///
    /// Real case rolls always use the colon form (`Numerical File: 7179-7187`). Requiring
    /// it is the primary filter: it rejects the publication / file-unit descriptions whose
    /// digits are years not cases (`Numerical File, 1906-1910 (M862)`), the series label
    /// (`Numerical and Minor Files`), and any other stray-digit record (`M862 pamphlet`).
    private static let colonLabelPrefix = #"^\s*Numerical\s+File\s*:\s*"#

    /// Matches a Numerical File roll title and returns its inclusive *case-number* range.
    ///
    /// Handles every form observed in the M862 harvest:
    /// - clean ranges — `Numerical File: 7179-7187`, `682–699`, bare `5275-5300`
    /// - single-case rolls — `Numerical File: 22346` → `(22346, 22346)`
    /// - sub-document boundaries — `21701-21740/125` → `(21701, 21740)`,
    ///   `19274/46-19297` → `(19274, 19297)`, `21740/126-End of case` → `(21740, 21740)`
    /// - roll-split markers — `23600 (S)-23640` → `(23600, 23640)`, `23600-23600 (R)`
    /// - stray leading dash / space separator — `-25101 25240` → `(25101, 25240)`
    ///
    /// Returns `nil` for titles that are not case rolls — the series/file-unit
    /// descriptions, finding aids, and the name/place-filed portion of the Numerical File
    /// (`Numerical File: Miscellaneous`, `North Dakota-Wisconsin`, `New York City`), which
    /// carry no digits and are never the target of a numeric "File No." citation. This is
    /// how non-case records are filtered out of the harvest.
    ///
    /// The case number is the *first* integer on each side, so a `/NN` sub-document
    /// suffix or a `(R)`/`(S)` split marker never displaces it. A non-numeric end token
    /// (e.g. `End of case`) falls back to the start case (the roll covers one case).
    ///
    /// - Returns: `(start, end)` with `start <= end`, or `nil`.
    public static func numericalFileCaseRange(from title: String) -> (start: Int, end: Int)? {
        // 1. Require and strip the "Numerical File:" roll label (colon required).
        //    Anything else (publication descriptions, the series label, stray-digit
        //    records) is not a case roll.
        guard let r = title.range(of: colonLabelPrefix,
                                  options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        var body = String(title[r.upperBound...]).trimmingCharacters(in: .whitespaces)

        // 2. Strip a stray leading dash/whitespace (catalog titles like "-25101 25240").
        while let first = body.unicodeScalars.first,
              dashCharacters.contains(first) || first == " " {
            body.removeFirst()
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }

        // 3. Pure name/place/subject labels (no digits) are not case rolls.
        guard body.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }

        // 4. Split into start/end tokens.
        let (startToken, endToken) = splitRange(body)

        // 5. Extract the leading case integer from each side.
        guard let startCase = firstInteger(in: startToken) else { return nil }
        let endCase = firstInteger(in: endToken) ?? startCase
        return startCase <= endCase ? (startCase, endCase) : (endCase, startCase)
    }

    // MARK: - Helpers

    /// Splits a label-stripped title into start and end tokens.
    ///
    /// Prefers the first dash as the range separator; failing that, a space between two
    /// numeric groups; failing that, the whole string is a single-case roll.
    private static func splitRange(_ body: String) -> (start: String, end: String) {
        if let dash = body.rangeOfCharacter(from: dashCharacters) {
            return (String(body[body.startIndex..<dash.lowerBound]),
                    String(body[dash.upperBound...]))
        }
        let numericParts = body
            .split(whereSeparator: { $0 == " " })
            .map(String.init)
            .filter { $0.rangeOfCharacter(from: .decimalDigits) != nil }
        if numericParts.count >= 2 {
            return (numericParts.first!, numericParts.last!)
        }
        return (body, body)
    }

    /// Returns the first maximal run of digits in `token` as an `Int`, or `nil`.
    /// Skips leading non-digits and stops at the first non-digit after the run, so
    /// `21740/126` → 21740, `23600 (S)` → 23600, `End of case` → nil.
    private static func firstInteger(in token: String) -> Int? {
        var digits = ""
        for character in token {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }
}
