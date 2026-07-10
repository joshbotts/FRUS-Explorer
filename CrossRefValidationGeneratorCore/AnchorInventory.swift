// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnchorInventory

/// Pass A of validation: every `xml:id` value declared in a volume's TEI.
///
/// Everything a `<ref>` can target carries an `xml:id` — documents (`<div xml:id="d5">`), printed
/// pages (`<pb n="427" xml:id="pg_427"/>`), footnotes (`<note xml:id="d2fn1">`), terms, index items,
/// persons, and named divisions. So anchor validation collapses to a single set-membership test per
/// volume, and page anchors need no separate page-number index: `#pg_427` is just membership of the
/// literal id `pg_427`.
///
/// Extraction is a raw byte scan (the app's `XMLParser` gives no way to enumerate ids cheaply and
/// we do not need element structure here) matching the literal attribute `xml:id="…"` /
/// `xml:id='…'`, whitespace-anchored so it never matches a substring of some other attribute name.
public enum AnchorInventory {

    private static let xmlIdPattern: [UInt8] = Array("xml:id=".utf8)   // 7 bytes
    private static let doubleQuote: UInt8 = 0x22   // "
    private static let singleQuote: UInt8 = 0x27   // '

    /// Every distinct `xml:id` value in a volume's raw TEI bytes.
    ///
    /// - Parameter data: The volume file contents.
    /// - Returns: The set of xml:id values.
    public static func xmlIds(in data: Data) -> Set<String> {
        let b = [UInt8](data)
        let n = b.count
        let pat = xmlIdPattern
        let patLen = pat.count
        var ids = Set<String>()
        var i = 0
        while i + patLen < n {
            // Match "xml:id=" only when whitespace-preceded (or at the very start), so a hypothetical
            // attribute ending in "xml:id" cannot false-match.
            guard b[i] == pat[0] else { i += 1; continue }
            var matched = true
            var k = 1
            while k < patLen {
                if b[i + k] != pat[k] { matched = false; break }
                k += 1
            }
            if matched {
                let before: UInt8? = i > 0 ? b[i - 1] : nil
                let boundaryOK = before == nil || before == 0x20 || before == 0x0A
                    || before == 0x09 || before == 0x0D
                if boundaryOK {
                    let q = b[i + patLen]
                    if q == doubleQuote || q == singleQuote {
                        var j = i + patLen + 1
                        let valueStart = j
                        while j < n && b[j] != q { j += 1 }
                        if j <= n {
                            ids.insert(String(decoding: b[valueStart..<j], as: UTF8.self))
                        }
                        i = j + 1
                        continue
                    }
                }
            }
            i += 1
        }
        return ids
    }
}
