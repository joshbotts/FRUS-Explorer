// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Reads a volume's `<div>` tree by scanning bytes, keeping every offset and line.
///
/// **A byte scan rather than an XML parse, because the offsets ARE the product.** An OH editor
/// opens the file in oXygen at a line; a correction that could not name one would not be
/// actionable. `XMLParser` reports a line but no byte offset, and no offset at all for a closing
/// tag.
///
/// Comments, CDATA and processing instructions are stepped over, so a `<div>` written inside a
/// comment is neither opened nor counted.
///
/// **A foreign-namespace `<div>` is not a TEI div.** The four `frus1917-72PubDip*` volumes embed an
/// XHTML video player whose markup includes `<div>`; counting those desynchronises the whole tree
/// for the rest of the file. They are skipped by their `xmlns` attribute — measured, that is the
/// only thing that distinguishes them, and a scanner that ignored it disagreed with an element
/// tree on exactly those files.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum DivScanner {

    private static let lt: UInt8 = 0x3C          // <
    private static let gt: UInt8 = 0x3E          // >
    private static let slash: UInt8 = 0x2F       // /
    private static let bang: UInt8 = 0x21        // !
    private static let question: UInt8 = 0x3F    // ?
    private static let newline: UInt8 = 0x0A

    /// Scans `data` and returns its divs in document order.
    public static func scan(_ data: Data) -> [DivNode] {
        let bytes = [UInt8](data)
        var nodes: [DivNode] = []
        var stack: [Int] = []
        var line = 1
        var index = 0
        // The open tag of the div whose <head> we are inside, plus the head's text so far.
        var headOwner: Int?
        var headDepth = 0
        var noteDepth = 0
        var headBytes: [UInt8] = []

        while index < bytes.count {
            let byte = bytes[index]
            if byte == newline { line += 1; index += 1; continue }
            guard byte == lt else {
                if headOwner != nil, noteDepth == 0 { headBytes.append(byte) }
                index += 1
                continue
            }

            // Comment, CDATA, DOCTYPE, processing instruction: step over without reading.
            if index + 1 < bytes.count, bytes[index + 1] == bang || bytes[index + 1] == question {
                let (next, lines) = skipNonElement(bytes, from: index)
                line += lines
                index = next
                continue
            }

            guard let tagEnd = findTagEnd(bytes, from: index) else { break }
            let tag = String(decoding: bytes[index...tagEnd], as: UTF8.self)
            let name = elementName(of: tag)

            switch name {
            case "div":
                if tag.hasPrefix("</") {
                    if let top = stack.popLast() {
                        nodes[top].closeByte = index
                        nodes[top].closeLine = line
                    }
                } else if !tag.hasSuffix("/>"), !isForeignNamespace(tag) {
                    let node = DivNode(
                        index: nodes.count, parent: stack.last, type: attribute("type", in: tag) ?? "",
                        subtype: attribute("subtype", in: tag), id: attribute("xml:id", in: tag),
                        n: attribute("n", in: tag), openByte: index, openLine: line,
                        closeByte: index, closeLine: line, depth: stack.count)
                    if let parent = stack.last { nodes[parent].children.append(node.index) }
                    nodes.append(node)
                    stack.append(node.index)
                }
            case "head":
                if tag.hasPrefix("</") {
                    headDepth -= 1
                    if headDepth == 0, let owner = headOwner {
                        nodes[owner].headText = collapse(String(decoding: headBytes, as: UTF8.self))
                        headOwner = nil
                        headBytes = []
                    }
                } else if !tag.hasSuffix("/>") {
                    // Only a div's OWN head, and only the first one.
                    if headOwner == nil, let top = stack.last, nodes[top].headText.isEmpty {
                        headOwner = top
                        headBytes = []
                        noteDepth = 0
                    }
                    headDepth += 1
                }
            case "note":
                // A note inside a head is the editors' annotation ON the heading, not part of it.
                if headOwner != nil {
                    if tag.hasPrefix("</") {
                        noteDepth = max(0, noteDepth - 1)
                    } else if !tag.hasSuffix("/>") {
                        noteDepth += 1
                    }
                }
            default:
                break
            }

            line += tag.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
            index = tagEnd + 1
        }
        return nodes
    }

    // MARK: - Tag reading

    /// The index of the `>` closing the tag that starts at `start`, or `nil` at end of data.
    private static func findTagEnd(_ bytes: [UInt8], from start: Int) -> Int? {
        var index = start + 1
        while index < bytes.count {
            if bytes[index] == gt { return index }
            index += 1
        }
        return nil
    }

    /// Steps over a comment, CDATA section, DOCTYPE or processing instruction.
    private static func skipNonElement(_ bytes: [UInt8], from start: Int) -> (next: Int, lines: Int) {
        let terminator: [UInt8]
        if matches(bytes, at: start, "<!--") {
            terminator = Array("-->".utf8)
        } else if matches(bytes, at: start, "<![CDATA[") {
            terminator = Array("]]>".utf8)
        } else {
            terminator = Array(">".utf8)
        }
        var index = start
        var lines = 0
        while index < bytes.count {
            if bytes[index] == newline { lines += 1 }
            if matchesBytes(bytes, at: index, terminator) {
                return (index + terminator.count, lines)
            }
            index += 1
        }
        return (bytes.count, lines)
    }

    private static func matches(_ bytes: [UInt8], at index: Int, _ text: String) -> Bool {
        matchesBytes(bytes, at: index, Array(text.utf8))
    }

    private static func matchesBytes(_ bytes: [UInt8], at index: Int, _ needle: [UInt8]) -> Bool {
        guard index + needle.count <= bytes.count else { return false }
        for offset in 0..<needle.count where bytes[index + offset] != needle[offset] { return false }
        return true
    }

    /// The element name of a tag, lower-cased and without any namespace prefix.
    static func elementName(of tag: String) -> String {
        var name = tag.dropFirst()                       // "<"
        if name.hasPrefix("/") { name = name.dropFirst() }
        let end = name.firstIndex { $0 == " " || $0 == ">" || $0 == "/" || $0 == "\n" || $0 == "\t" }
            ?? name.endIndex
        let raw = String(name[name.startIndex..<end])
        if let colon = raw.lastIndex(of: ":") { return String(raw[raw.index(after: colon)...]) }
        return raw.lowercased()
    }

    /// The value of `name` in `tag`, or `nil`.
    ///
    /// **The name must be preceded by whitespace**, or a substring match reads the wrong
    /// attribute: `type=` matches inside `subtype=`, and `n=` matches inside
    /// `frus:doc-dateTime-min=`. Caught by `ElementTreeParity` on 554 of 744 files the first time
    /// this ran, which is the entire reason that check is not optional.
    static func attribute(_ name: String, in tag: String) -> String? {
        var searchStart = tag.startIndex
        while let range = tag.range(of: "\(name)=\"", range: searchStart..<tag.endIndex) {
            let precedingIsBoundary = range.lowerBound == tag.startIndex
                || tag[tag.index(before: range.lowerBound)].isWhitespace
            if precedingIsBoundary {
                let rest = tag[range.upperBound...]
                guard let close = rest.firstIndex(of: "\"") else { return nil }
                return String(rest[rest.startIndex..<close])
            }
            searchStart = range.upperBound
        }
        return nil
    }

    /// Whether a `<div>` declares its own default namespace — the XHTML player markup the four
    /// PubDip volumes embed.
    static func isForeignNamespace(_ tag: String) -> Bool {
        guard let declared = attribute("xmlns", in: tag) else { return false }
        return declared != "http://www.tei-c.org/ns/1.0"
    }

    /// Collapses runs of whitespace and trims, so a hard-wrapped heading compares as one line.
    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
