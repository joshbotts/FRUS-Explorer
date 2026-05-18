// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Parses FRUS volume filenames into structured components.
///
/// FRUS XML filenames follow a `frus{subseries}[v{vol}][p{part}][sups][app].xml` pattern.
/// The subseries encodes the chronological coverage and is the primary grouping dimension
/// in the Browser view.
///
/// ## Observed Filename Patterns
///
/// | Pattern | Example | Subseries |
/// |---------|---------|-----------|
/// | Single year (early) | `frus1861.xml` | `1861` |
/// | Year range (2-digit end) | `frus1969-76v01.xml` | `1969-76` |
/// | Year range (4-digit end) | `frus1993-2000v01.xml` | `1993-2000` |
/// | Sub-series letter suffix | `frus1952-54Gv01.xml` | `1952-54` |
/// | Part only (no volume number) | `frus1863p2.xml` | `1863` |
/// | Vietnam extras | `frus1969-76ve01.xml` | `1969-76` |
/// | Vietnam extras + part | `frus1969-76ve05p1.xml` | `1969-76` |
/// | Conference topic suffix (single) | `frus1945Berlin.xml` | `1945` |
/// | Conference topic suffix (multi) | `frus1943CairoTehran.xml` | `1943` |
/// | Conference topic + edition suffix | `frus1951-54IranEd2.xml` | `1951-54` |
/// | Part number | `frus1952-54v06p2.xml` | `1952-54` |
/// | Supplement | `frus1969-76v01sups.xml` | `1969-76` |
/// | Appendix | `frus1861app.xml` | `1861` |
/// | Appendix part | `frus1894app1.xml` | `1894` |
/// | Microfiche | `frus1977-80v03mf.xml` | `1977-80` |
///
/// The `volumeId` is always the filename without the `.xml` extension.
///
/// The `subseries` is strictly the year or year-range prefix of the filename
/// (digits and hyphens only). All other suffixes — volume markers, part numbers,
/// known string suffixes, single-letter sub-series identifiers, conference/topic
/// names, and mixed alphanumeric edition markers — are discarded. This is enforced
/// by extracting only the leading `\d{4}(-\d{2,4})?` pattern from the after-`frus`
/// portion of the filename, so a subseries identifier never contains letters.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 54: handle Vietnam-extras (ve\d+), bare part numbers (p\d+),
///          and conference/topic name suffixes ([A-Z][a-z]+)
///   1.2 — Session 69: replace multi-pass stripping with a single anchored year-range
///          extraction (`^\d{4}(-\d{2,4})?`). Fixes three remaining error classes:
///          (a) Pass 1 returned early before Pass 4 stripped conference names, leaving
///          `1945Berlin`, `1919Paris`, etc.; (b) mixed alphanumeric suffixes like
///          `IranEd2` were not matched by the `[A-Z][a-z]+$` Pass 4 pattern;
///          (c) single-letter sub-series suffixes (e.g. `G` in `1952-54G`) were
///          intentionally preserved but the new rule requires digits-only subseries.
public struct VolumeIDParser {

    private init() {}

    /// Parses a FRUS volume filename and returns the volumeId and subseries.
    ///
    /// Returns `nil` if the filename does not match the expected `frus*.xml` pattern.
    ///
    /// - Parameter filename: The bare filename, e.g. `"frus1969-76v01.xml"`.
    /// - Returns: A tuple `(volumeId:, subseries:)` or `nil` on no match.
    public static func parse(filename: String) -> (volumeId: String, subseries: String)? {
        guard filename.hasSuffix(".xml") else { return nil }
        let base = String(filename.dropLast(4))
        guard base.hasPrefix("frus"), base.count > 4 else { return nil }

        let volumeId = base
        let afterFrus = String(base.dropFirst(4))

        // The subseries ends at the first occurrence of "v" followed by a digit
        // (the volume number marker). If no such marker exists, the whole suffix
        // is the subseries (e.g., "1861", "1894China").
        let subseries = subseries(from: afterFrus)
        return (volumeId: volumeId, subseries: subseries)
    }

    // MARK: - Private

    /// Extracts the subseries from the portion of the filename after "frus".
    ///
    /// A FRUS subseries is always a 4-digit start year optionally followed by a hyphen
    /// and a 2–4 digit end year. Everything else in the filename is discarded by
    /// extracting only the leading `^\d{4}(-\d{2,4})?` from `afterFrus`.
    ///
    /// This single-step extraction correctly handles all observed filename patterns
    /// without requiring multi-pass suffix stripping:
    ///
    /// | Input (`afterFrus`) | Result |
    /// |---------------------|--------|
    /// | `1969-76v01` | `1969-76` |
    /// | `1952-54Gv01` | `1952-54` |
    /// | `1945Berlin` | `1945` |
    /// | `1919Paris` | `1919` |
    /// | `1943CairoTehran` | `1943` |
    /// | `1951-54IranEd2` | `1951-54` |
    /// | `1969-76ve01` | `1969-76` |
    /// | `1863p2` | `1863` |
    /// | `1861app` | `1861` |
    /// | `1894app1` | `1894` |
    /// | `1993-2000v01` | `1993-2000` |
    private static func subseries(from afterFrus: String) -> String {
        // Extract the year or year-range prefix only. The regex anchors at the start
        // and matches exactly 4 digits followed by an optional hyphen+2-to-4 digits.
        // Anything after that (volume markers, letters, conference names, etc.) is
        // simply ignored — it is not part of the subseries.
        guard let range = afterFrus.range(of: #"^\d{4}(-\d{2,4})?"#,
                                          options: .regularExpression) else {
            return afterFrus    // no match is unexpected for a valid frus*.xml name
        }
        return String(afterFrus[range])
    }
}
