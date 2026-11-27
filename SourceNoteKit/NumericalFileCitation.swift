// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NumericalFileCitation

/// The case number a FRUS "File No." citation of the 1906–1910 Numerical File names: the one rule that
/// Source Explorer (FRUSCoreKit's `CentralFilesIndex`) and the generators (`CentralFilesIndexGeneratorCore`'s
/// `NumericalFileIndex`, which the Source Explorer export reads) both forward to (#1974, decision 176).
///
/// ## Why it lives here
/// It was written twice, and #722 gave one copy the decimal-form guard: the kit's. The generators' copy
/// took the first run of digits, so the Source Explorer export read `723.2515/110` in a 1908 document as
/// case 723 and listed that unrelated case's rolls, about 335 records the app's views refuse. Two copies is
/// how #722 fixed one and missed the other; SourceNoteKit is a module both depend on.
///
/// Version history:
///   1.0 — 2026-11-26 (#1974, plan of record row L31, decision 176): moved, unchanged, from FRUSCoreKit's
///         `CentralFilesIndex.caseNumber(fromFileNumber:)` and `isDecimalFileForm(_:)`, which forward here, as
///         `CentralFilesIndexGeneratorCore`'s `NumericalFileIndex.caseNumber(fromFileNumber:)` now does
public enum NumericalFileCitation {

    /// Extracts the integer case number from a FRUS "File No." citation.
    ///
    /// Takes the first run of digits (the case number); a leading `File No.` label and a
    /// trailing `/NN` sub-document suffix are ignored. `"7187"` → 7187; `"697/43"` → 697;
    /// `"File No. 17529."` → 17529.
    ///
    /// Returns `nil` for a **decimal-file** citation, which carries no case number at all
    /// — see `isDecimalFileForm(_:)`.
    public static func caseNumber(fromFileNumber fileNumber: String) -> Int? {
        guard !isDecimalFileForm(fileNumber) else { return nil }
        var digits = ""
        var seenDigit = false
        for character in fileNumber {
            if character.isNumber {
                digits.append(character)
                seenDigit = true
            } else if seenDigit {
                break
            }
        }
        return Int(digits)
    }

    /// Whether a file identifier is written in the **decimal** file's form rather than the
    /// 1906–1910 Numerical File's (#354 item 5).
    ///
    /// ## Why the year cannot decide this
    /// Both surfaces that resolve Numerical File rolls gate on `documentYear` being
    /// 1906–1910, and the decimal file opened *in the middle of* 1910. Measured over the
    /// corpus, **334 documents** sit inside that year gate carrying a decimal citation —
    /// 327 of them dated 1910, plus a handful the editors cite from later filings.
    /// `835.415A/97`, `864.56/12`, `825.00/69`, `211.63 Or5/2`: the era boundary is a form,
    /// not a date, so the form is what this reads.
    ///
    /// ## Why it matters more than a missing link
    /// Without this, `caseNumber` takes the first run of digits and hands back `835`, `864`,
    /// `825` — real case numbers, belonging to real and entirely unrelated cases — and the
    /// roll lookup resolves them to real digitised rolls. The researcher is sent to a
    /// specific microfilm roll that does not hold the document and gives no sign of it. An
    /// honest "no match" is the better answer.
    ///
    /// ## The rule
    /// Starting **at the first digit** and stopping at the first `/`: a `.` followed, after
    /// any spaces, by an alphanumeric. Each clause carries a real case, and the rule was
    /// wrong without all three:
    ///
    /// - *From the first digit* — otherwise the abbreviation dot in a `"File No. 17529."`
    ///   label reads as a decimal point and gates a perfectly good numerical citation.
    ///   Anchoring on the digits skips the label without having to parse it. It cannot be
    ///   "the dot follows a digit" instead: `811B.5034` is decimal and its dot follows a
    ///   letter.
    /// - *Stopping at `/`* — the slash closes the case number, so `697/43`'s suffix cannot
    ///   make the citation decimal-era.
    /// - *After any spaces* — 14 documents cite `511. 4A1/914` and `812. 415A/7`, a space
    ///   transcribed into the decimal point. Without this clause they resolved cases 511
    ///   and 812. They are the reason this rule was measured against the corpus rather than
    ///   reasoned about: the first version looked right and missed all fourteen.
    public static func isDecimalFileForm(_ fileNumber: String) -> Bool {
        guard let start = fileNumber.firstIndex(where: \.isNumber) else { return false }
        var sawDot = false
        for character in fileNumber[start...] {
            if character == "/" { return false }
            if sawDot {
                if character.isLetter || character.isNumber { return true }
                if character != " " { sawDot = false }
            } else if character == "." {
                sawDot = true
            }
        }
        return false
    }
}
