// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// One row extracted from a volume's front-matter Sources section: a narrative prose
/// paragraph or a node in the archival-collection outline.
///
/// Mirrors the app's `VolumeSourceEntry` (`FRUSDocumentParser.swift`) so the harvested
/// authority matches what the app parses at index time. Kept as a standalone port because
/// the app's parser lives in the app target, and the generators reimplement TEI parsing
/// (as `ManifestGeneratorCore` does for volume headers).
public struct SourceRow: Sendable, Equatable {
    public enum Kind: String, Sendable { case prose, item }
    public let kind: Kind
    public let depth: Int
    public let isHeading: Bool
    public let recordGroup: String?
    public let lotFile: String?
    public let repository: String?
    /// The row's own text (whitespace-collapsed), excluding any nested child items.
    public let text: String
}

/// Parses a FRUS volume's front-matter Sources section into flat, document-order rows.
///
/// A faithful port of the app's corrected `SourcesParserDelegate`: it separates narrative
/// `<p>` prose from the nested `<list>`/`<item>` archival-collection tree, captures each
/// item's own text (excluding child items), flags `<hi rend="strong">` headings, and emits
/// rows in document (pre-order) order (items close inner-first, so it sorts by an
/// open-order index). Whitespace is collapsed.
public final class VolumeSourcesExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Extracts the Sources rows from a volume's TEI XML. Returns an empty array when the
    /// volume has no recognizable sources section.
    public static func extract(fromXML data: Data) -> [SourceRow] {
        let delegate = VolumeSourcesExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.entries
    }

    private var entries: [SourceRow] = []

    private var inSourcesSection = false
    private var elementDepth = 0
    private var sectionDepth = -1

    private var openCounter = 0
    private var collected: [(order: Int, row: SourceRow)] = []

    private var inProse = false
    private var proseBuffer = ""
    private var proseOrder = 0

    private struct ItemFrame {
        var text = ""
        var isHeading = false
        let depth: Int
        let order: Int
    }
    private var itemStack: [ItemFrame] = []
    private var listDepth = 0

    private static let rgPat = try? NSRegularExpression(
        pattern: #"\bRG\s+(\d+\w*)\b|\bRecord Group\s+(\d+)\b"#, options: .caseInsensitive)
    private static let lotPat = try? NSRegularExpression(
        pattern: #"\bLot\s+([\w\s\-]+?D\s*\d+)\b"#, options: .caseInsensitive)

    // Matches the app's post-review set (excludes "listofabbreviations", a terms glossary).
    private static let sourceSectionTypes: Set<String> = [
        "sources", "listofworks", "sources-and-abbreviations"
    ]

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        if !inSourcesSection {
            let type    = attributeDict["type"]?.lowercased() ?? ""
            let subtype = attributeDict["subtype"]?.lowercased() ?? ""
            let xmlId   = attributeDict["xml:id"]?.lowercased() ?? ""
            if (elementName == "div" && (Self.sourceSectionTypes.contains(type)
                                         || Self.sourceSectionTypes.contains(subtype)
                                         || Self.sourceSectionTypes.contains(xmlId)))
               || elementName == "listBibl" {
                inSourcesSection = true
                sectionDepth     = elementDepth
            }
        }
        guard inSourcesSection else { return }
        switch elementName {
        case "list":
            listDepth += 1
        case "item":
            openCounter += 1
            itemStack.append(ItemFrame(depth: max(0, listDepth - 1), order: openCounter))
        case "p":
            if itemStack.isEmpty {
                openCounter += 1
                proseOrder = openCounter
                inProse = true
                proseBuffer = ""
            }
        case "hi":
            if attributeDict["rend"]?.lowercased() == "strong", !itemStack.isEmpty {
                itemStack[itemStack.count - 1].isHeading = true
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inSourcesSection else { return }
        if !itemStack.isEmpty {
            itemStack[itemStack.count - 1].text += string
        } else if inProse {
            proseBuffer += string
        }
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        guard inSourcesSection else { return }

        switch elementName {
        case "list":
            listDepth = max(0, listDepth - 1)
        case "item":
            if let frame = itemStack.popLast() {
                let text = Self.collapseWhitespace(frame.text)
                if !text.isEmpty {
                    collected.append((frame.order,
                                      Self.makeItemRow(text: text, depth: frame.depth,
                                                       isHeading: frame.isHeading)))
                }
            }
        case "p":
            if inProse && itemStack.isEmpty {
                let text = Self.collapseWhitespace(proseBuffer)
                if !text.isEmpty {
                    collected.append((proseOrder, SourceRow(kind: .prose, depth: 0, isHeading: false,
                                                            recordGroup: nil, lotFile: nil,
                                                            repository: nil, text: text)))
                }
                inProse = false
                proseBuffer = ""
            }
        default:
            break
        }

        if elementDepth <= sectionDepth {
            entries.append(contentsOf: collected.sorted { $0.order < $1.order }.map(\.row))
            collected.removeAll()
            inSourcesSection = false
            sectionDepth = -1
            inProse = false
            proseBuffer = ""
            itemStack.removeAll()
            listDepth = 0
        }
    }

    private static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func makeItemRow(text: String, depth: Int, isHeading: Bool) -> SourceRow {
        var rg: String?
        if let regex = rgPat {
            let ns = NSRange(text.startIndex..., in: text)
            if let m = regex.firstMatch(in: text, range: ns) {
                if m.range(at: 1).location != NSNotFound, let r = Range(m.range(at: 1), in: text) {
                    rg = String(text[r])
                } else if m.range(at: 2).location != NSNotFound, let r = Range(m.range(at: 2), in: text) {
                    rg = String(text[r])
                }
            }
        }

        var lot: String?
        if let regex = lotPat {
            let ns = NSRange(text.startIndex..., in: text)
            if let m = regex.firstMatch(in: text, range: ns),
               let r = Range(m.range(at: 1), in: text) {
                lot = String(text[r]).trimmingCharacters(in: .whitespaces)
            }
        }

        let repoKeywords = [
            "National Archives", "Library of Congress", "Washington National Records Center",
            "Kennedy Library", "Johnson Library", "Nixon", "Ford Library", "Carter Library",
            "Reagan Library", "Bush Library", "Clinton Library", "Eisenhower Library",
            "Truman Library", "Roosevelt Library", "Hoover Institution",
            "Central Intelligence Agency", "Department of State",
            "Department of Defense", "Naval Historical", "Center of Military History",
        ]
        var repo: String?
        for keyword in repoKeywords where text.range(of: keyword, options: .caseInsensitive) != nil {
            repo = keyword
            break
        }

        return SourceRow(kind: .item, depth: depth, isHeading: isHeading,
                         recordGroup: rg, lotFile: lot, repository: repo, text: text)
    }
}
