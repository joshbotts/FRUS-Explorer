// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentIdInventory

/// Every `<div type="document">` xml:id in a volume.
///
/// `AnchorInventory` (the validator's Pass A) collects *all* xml:ids, which is the right question
/// for "does this anchor exist" and the wrong one here: a reference whose target is a page, an
/// index entry, or a section resolves against that inventory and has no archival provenance at
/// all. Measured on the corpus, 49,799 references target index-entry anchors (`inN`) that the
/// grammar reports as documents; without this narrower inventory each would mint a phantom node.
///
/// The scan mirrors `RefHarvester`'s: a left-to-right byte walk that steps over comments, CDATA,
/// processing instructions, and DOCTYPE, so a `<div type="document">` inside a comment is neither
/// inventoried here nor harvested there.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
public enum DocumentIdInventory {

    /// The xml:ids of every document div in a volume's TEI.
    public static func documentIds(in data: Data) -> Set<String> {
        var ids: Set<String> = []
        let bytes = [UInt8](data)
        var i = 0
        let count = bytes.count

        while i < count {
            guard bytes[i] == 0x3C else { i += 1; continue }   // '<'
            // Skip comments, CDATA, processing instructions, DOCTYPE.
            if matches(bytes, at: i, "<!--") {
                i = skip(bytes, from: i + 4, until: "-->") ; continue
            }
            if matches(bytes, at: i, "<![CDATA[") {
                i = skip(bytes, from: i + 9, until: "]]>") ; continue
            }
            if matches(bytes, at: i, "<?") || matches(bytes, at: i, "<!") {
                i = skip(bytes, from: i + 2, until: ">") ; continue
            }
            guard matches(bytes, at: i, "<div") else { i += 1; continue }
            guard let close = index(of: 0x3E, in: bytes, from: i) else { break }   // '>'
            let tag = String(decoding: bytes[i..<close], as: UTF8.self)
            if let id = attribute("xml:id", in: tag), attribute("type", in: tag) == "document" {
                ids.insert(id)
            }
            i = close + 1
        }
        return ids
    }

    // MARK: - Byte helpers

    private static func matches(_ bytes: [UInt8], at index: Int, _ token: String) -> Bool {
        let needle = [UInt8](token.utf8)
        guard index + needle.count <= bytes.count else { return false }
        for offset in needle.indices where bytes[index + offset] != needle[offset] { return false }
        return true
    }

    private static func skip(_ bytes: [UInt8], from start: Int, until token: String) -> Int {
        let needle = [UInt8](token.utf8)
        var i = start
        while i + needle.count <= bytes.count {
            if matches(bytes, at: i, token) { return i + needle.count }
            i += 1
        }
        return bytes.count
    }

    private static func index(of byte: UInt8, in bytes: [UInt8], from start: Int) -> Int? {
        var i = start
        while i < bytes.count {
            if bytes[i] == byte { return i }
            i += 1
        }
        return nil
    }

    /// The value of `name="…"` in a tag string, matched on a whitespace-anchored name so
    /// `type=` cannot be found inside `subtype=`.
    private static func attribute(_ name: String, in tag: String) -> String? {
        for separator in ["\"", "'"] {
            let needle = " \(name)=\(separator)"
            guard let range = tag.range(of: needle) else { continue }
            let rest = tag[range.upperBound...]
            guard let end = rest.range(of: separator) else { continue }
            return String(rest[..<end.lowerBound])
        }
        return nil
    }
}
