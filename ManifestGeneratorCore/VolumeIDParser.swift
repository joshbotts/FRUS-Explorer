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
/// | Part only (no volume number) | `frus1863p2.xml` | `1863` |
/// | Vietnam extras | `frus1969-76ve01.xml` | `1969-76` |
/// | Vietnam extras + part | `frus1969-76ve05p1.xml` | `1969-76` |
/// | Conference topic suffix | `frus1943CairoTehran.xml` | `1943` |
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
///   1.1 — Session 54: handle Vietnam-extras (ve\d+), bare part numbers (p\d+),
///          and conference/topic name suffixes ([A-Z][a-z]+)
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
    /// Strips volume markers and non-subseries suffixes from the right in four passes:
    ///
    /// 1. **`v[a-z]?\d+` volume marker** — covers standard volumes (`v01`) and
    ///    Vietnam-extras (`ve01`, `ve05p1`). Everything from this marker onward is
    ///    discarded, so `1969-76ve01` → `1969-76` and `1952-54Gv01` → `1952-54G`.
    ///
    /// 2. **Trailing `p\d+`** — bare part numbers with no preceding volume marker,
    ///    e.g. `1863p2` → `1863`.
    ///
    /// 3. **Known string suffixes** (`sups`, `app`, `mf`) — e.g. `1861app` → `1861`.
    ///
    /// 4. **Trailing `[A-Z][a-z]+` conference/topic names** — applied iteratively so
    ///    `1943CairoTehran` → `1943Cairo` → `1943`. A trailing single uppercase letter
    ///    (e.g. the `G` in `1952-54G`) is NOT stripped because it matches `[A-Z]` but
    ///    not `[A-Z][a-z]+`.
    private static func subseries(from afterFrus: String) -> String {
        var s = afterFrus

        // 1. v[a-z]?\d+ covers standard (v01) and Vietnam-extras (ve01, ve05p2, …).
        //    Match the marker and everything that follows, discard it all.
        if let range = s.range(of: #"v[a-z]?\d+.*$"#, options: [.regularExpression]) {
            return String(s[..<range.lowerBound])
        }

        // 2. Trailing bare part number (no volume marker), e.g. "1863p2".
        if let range = s.range(of: #"p\d+$"#, options: [.regularExpression]) {
            s = String(s[..<range.lowerBound])
        }

        // 3. Known non-subseries string suffixes (longest first to avoid partial matches).
        for suffix in ["sups", "app", "mf"] where s.hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count)); break
        }

        // 4. Trailing conference / topic names of the form [A-Z][a-z]+, applied
        //    iteratively so "CairoTehran" is fully stripped in two passes.
        //    Single trailing uppercase letters (e.g. "G" in "1952-54G") are untouched.
        var changed = true
        while changed {
            changed = false
            // Anchor to end ($) so the regex matches the trailing word, not the first.
            if let r = s.range(of: #"[A-Z][a-z]+$"#, options: .regularExpression) {
                s = String(s[..<r.lowerBound])
                changed = true
            }
        }

        return s
    }
}
