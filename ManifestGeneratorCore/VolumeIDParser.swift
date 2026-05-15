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
/// | With sub-series letter | `frus1952-54Gv01.xml` | `1952-54G` |
/// | Special topic suffix | `frus1894China.xml` | `1894China` |
/// | Part number | `frus1952-54v06p2.xml` | `1952-54` |
/// | Supplement | `frus1969-76v01sups.xml` | `1969-76` |
/// | Appendix | `frus1861app.xml` | `1861` |
/// | Microfiche | `frus1977-80v03mf.xml` | `1977-80` |
///
/// The `volumeId` is always the filename without the `.xml` extension.
/// The `subseries` is the portion of the filename between `frus` and the first volume-
/// or suffix-indicator character.
///
/// Version history:
///   1.0 — Session 02: initial implementation
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
    /// Strips known suffix tokens (v{N}, p{N}, sups, mf, app) from the right, leaving
    /// the bare subseries identifier.
    private static func subseries(from afterFrus: String) -> String {
        // Find the volume marker: literal "v" followed by one or more digits.
        // This separates the subseries from the volume/part/suffix designators.
        if let range = afterFrus.range(of: #"v\d+"#, options: .regularExpression) {
            // Everything before the "v" is the subseries.
            return String(afterFrus[..<range.lowerBound])
        }

        // No volume marker: strip known non-subseries suffixes.
        // Order matters: strip longer suffixes before shorter ones.
        let suffixes = ["sups", "app", "mf"]
        for suffix in suffixes where afterFrus.hasSuffix(suffix) {
            return String(afterFrus.dropLast(suffix.count))
        }

        // Nothing to strip: the entire afterFrus string is the subseries.
        return afterFrus
    }
}
