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
/// The grammar mirrors the app's `SourceNoteParser.looseLotRegex` so the harvest queries every
/// lot the app can key, across: inline (`CU Files: Lot 63D135`), narrative (`…RG 59, … Lot 64 D
/// 199`), dashed (`Lot 61–D 146`), **letter-first** (`Lot M–88`, `Lot F 96`, `Lot W-130` — the
/// leading digits are optional), **trailing-letter suffix** (`Lot 61 D 282A`), plural lead
/// (`Lots 64 D 563 and …`), and `Lot File(s)` infix (`Lot File 57 D 577`). Normalization (strip
/// spaces/dashes, upper-case) yields the same key the app derives at runtime
/// (`SourceNoteParser.lotFileNorm`).
///
/// > Note: a plural citation's *second* lot (`Lots 64 D 563 and 65 D 101`) is not captured here,
/// > matching `looseLotRegex`/`firstLotReference`; such a lot is harvested from any other citation
/// > that names it directly.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 3 — lot files
///   1.1 — #352: widened to the app's `looseLotRegex` grammar (letter-first, trailing-letter
///          suffix, plural, `Lot File` infix) so letter-first lots — M-88 (CFM Files, 697
///          records) and the F-series RG-84 lots — are actually queried by the keyed pass.
public enum LotFileCitationExtractor {

    // Mirrors SourceNoteParser.looseLotRegex: optional 2–3 leading digits, a single letter
    // designator, dash/space separators, trailing digits, and an optional single-letter suffix.
    private static let lotRegex = try? NSRegularExpression(
        pattern: #"\bLots?\s+(?:Files?\s+)?((?:\d{2,3}\s*[–—\-]?\s*)?[A-Za-z]\s*[–—\-]?\s*\d+(?:\s?[A-Za-z](?![A-Za-z]))?)"#,
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

    /// Compact upper-cased form: drop all whitespace and dashes (`61–D 146` → `61D146`,
    /// `M–88` → `M88`, `61 D 282A` → `61D282A`). A trailing letter suffix is preserved.
    /// Mirrors `SourceNoteParser.lotFileNorm` on the captured lot token.
    public static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "–" && $0 != "—" })
    }

    /// `F`-designator lot files are RG 84 (diplomatic post records); all others RG 59.
    /// Mirrors `SourceNoteParser.lotFileRecordGroup`: the F may lead the key (`F96`) or follow a
    /// digit (`79F80`, `57F139`), so both positions map to RG 84 — a letter-first `F` lot was
    /// previously mis-classified as RG 59 by the digits-required pattern (#352).
    public static func recordGroup(forNormalized lot: String) -> String {
        if lot.range(of: #"(?:^|\d)F\d"#, options: .regularExpression) != nil {
            return "84"
        }
        return "59"
    }
}
