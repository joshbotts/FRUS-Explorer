// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestedRef

/// One `<ref target>` located in a volume, with the precise source location the report needs.
public struct HarvestedRef: Equatable, Sendable {
    /// The verbatim `target` attribute value.
    public let rawTarget: String
    /// UTF-8 **byte** offset of the `<ref>`'s `<` in the file.
    public let byteOffset: Int
    /// 1-based line of the `<ref>` in the file.
    public let line: Int
    /// The nearest enclosing `<div type="document">` xml:id, or `nil` for front/back-matter refs.
    public let enclosingDocument: String?

    /// Memberwise initializer (fields documented on the properties).
    public init(rawTarget: String, byteOffset: Int, line: Int, enclosingDocument: String?) {
        self.rawTarget = rawTarget
        self.byteOffset = byteOffset
        self.line = line
        self.enclosingDocument = enclosingDocument
    }
}

// MARK: - RefHarvester

/// Pass B of validation: a single left-to-right byte scan that yields every `<ref>` with its exact
/// byte offset, 1-based line, and nearest enclosing `<div type="document">`.
///
/// The scan tracks only `<div>` nesting on a stack (documents nest inside sections/compilations),
/// which is all that is needed to attribute a ref to its document; other elements are skipped. It
/// steps over comments, CDATA, processing instructions, and DOCTYPE so a stray `<ref` inside a
/// comment can never be harvested. TEI is well-formed XML — `>` is escaped in text and cannot appear
/// inside an attribute value — so a first-`>`-after-`<` tag scan and simple div stack are reliable.
public enum RefHarvester {

    private static let lt: UInt8 = 0x3C          // <
    private static let gt: UInt8 = 0x3E          // >
    private static let slash: UInt8 = 0x2F       // /
    private static let bang: UInt8 = 0x21        // !
    private static let question: UInt8 = 0x3F    // ?
    private static let nl: UInt8 = 0x0A          // \n
    private static let dash: UInt8 = 0x2D        // -
    private static let rbrack: UInt8 = 0x5D      // ]

    /// Harvests every `<ref>` from a volume's raw TEI bytes.
    ///
    /// - Parameter data: The volume file contents.
    /// - Returns: The harvested refs, in document order.
    public static func harvest(from data: Data) -> [HarvestedRef] {
        let b = [UInt8](data)
        let n = b.count
        var i = 0
        var line = 1
        var divStack: [(isDocument: Bool, id: String?)] = []
        var refs: [HarvestedRef] = []

        while i < n {
            let c = b[i]
            if c == nl { line += 1; i += 1; continue }
            if c != lt { i += 1; continue }

            let start = i
            let startLine = line
            guard i + 1 < n else { break }
            let next = b[i + 1]

            // Comment / CDATA / DOCTYPE.
            if next == bang {
                if hasPrefix(b, at: i + 1, "!--") {
                    i = skip(b, from: i + 4, until: "-->", line: &line, n: n)
                } else if hasPrefix(b, at: i + 1, "![CDATA[") {
                    i = skip(b, from: i + 9, until: "]]>", line: &line, n: n)
                } else {
                    i = skipToGt(b, from: i + 2, line: &line, n: n)
                }
                continue
            }
            // Processing instruction.
            if next == question {
                i = skip(b, from: i + 2, until: "?>", line: &line, n: n)
                continue
            }

            // A normal tag: find the closing '>' (attributes never contain '>').
            var j = i + 1
            while j < n && b[j] != gt {
                if b[j] == nl { line += 1 }
                j += 1
            }
            let tagEnd = j                        // index of '>' (or n if truncated)
            let isClose = next == slash
            let selfClose = tagEnd > start && b[tagEnd - 1] == slash
            let nameStart = isClose ? i + 2 : i + 1
            var k = nameStart
            while k < tagEnd && isNameByte(b[k]) { k += 1 }
            let name = String(decoding: b[min(nameStart, tagEnd)..<min(k, tagEnd)], as: UTF8.self)

            if isClose {
                if name == "div", !divStack.isEmpty { divStack.removeLast() }
            } else if name == "div" {
                if !selfClose {
                    let tag = String(decoding: b[start..<min(tagEnd + 1, n)], as: UTF8.self)
                    let type = attribute("type", in: tag)
                    let id = attribute("xml:id", in: tag)
                    divStack.append((isDocument: type == "document", id: id))
                }
            } else if name == "ref" {
                let tag = String(decoding: b[start..<min(tagEnd + 1, n)], as: UTF8.self)
                if let target = attribute("target", in: tag) {
                    let enclosing = lastEnclosingDocument(divStack)
                    refs.append(HarvestedRef(rawTarget: target,
                                             byteOffset: start,
                                             line: startLine,
                                             enclosingDocument: enclosing))
                }
            }

            i = tagEnd < n ? tagEnd + 1 : n
        }

        return refs
    }

    // MARK: - Helpers

    /// The innermost enclosing document div's xml:id, if any.
    private static func lastEnclosingDocument(_ stack: [(isDocument: Bool, id: String?)]) -> String? {
        for entry in stack.reversed() where entry.isDocument {
            if let id = entry.id { return id }
        }
        return nil
    }

    /// Whether `pattern` (ASCII) occurs at byte index `at`.
    private static func hasPrefix(_ b: [UInt8], at: Int, _ pattern: String) -> Bool {
        let pat = Array(pattern.utf8)
        guard at + pat.count <= b.count else { return false }
        for x in 0..<pat.count where b[at + x] != pat[x] { return false }
        return true
    }

    /// Advances past `terminator` (ASCII), counting newlines; returns the index just after it.
    private static func skip(_ b: [UInt8], from: Int, until terminator: String, line: inout Int, n: Int) -> Int {
        let term = Array(terminator.utf8)
        let tLen = term.count
        var j = from
        while j < n {
            if b[j] == nl { line += 1 }
            if b[j] == term[0], j + tLen <= n {
                var m = 1
                while m < tLen && b[j + m] == term[m] { m += 1 }
                if m == tLen { return j + tLen }
            }
            j += 1
        }
        return n
    }

    /// Advances to just past the next `>`, counting newlines.
    private static func skipToGt(_ b: [UInt8], from: Int, line: inout Int, n: Int) -> Int {
        var j = from
        while j < n && b[j] != gt {
            if b[j] == nl { line += 1 }
            j += 1
        }
        return j < n ? j + 1 : n
    }

    /// Whether a byte can appear in an XML element/attribute name.
    private static func isNameByte(_ c: UInt8) -> Bool {
        (c >= 0x41 && c <= 0x5A) ||   // A–Z
        (c >= 0x61 && c <= 0x7A) ||   // a–z
        (c >= 0x30 && c <= 0x39) ||   // 0–9
        c == 0x3A || c == 0x2D || c == 0x5F || c == 0x2E   // : - _ .
    }

    /// Reads a whitespace-anchored attribute value from a tag string, honouring `"` or `'` quoting.
    /// Whitespace-anchoring keeps `attribute("type", …)` from matching `subtype=`.
    private static func attribute(_ name: String, in tag: String) -> String? {
        let needle = name + "="
        var searchStart = tag.startIndex
        while let r = tag.range(of: needle, range: searchStart..<tag.endIndex) {
            let boundaryOK: Bool = {
                guard r.lowerBound > tag.startIndex else { return false }
                let before = tag[tag.index(before: r.lowerBound)]
                return before == " " || before == "\n" || before == "\t" || before == "\r"
            }()
            if boundaryOK, r.upperBound < tag.endIndex {
                let q = tag[r.upperBound]
                if q == "\"" || q == "'" {
                    let valueStart = tag.index(after: r.upperBound)
                    if let end = tag[valueStart...].firstIndex(of: q) {
                        return String(tag[valueStart..<end])
                    }
                    return nil
                }
            }
            searchStart = r.upperBound
        }
        return nil
    }
}
