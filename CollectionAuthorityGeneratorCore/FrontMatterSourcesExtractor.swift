// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// One row of a volume's front-matter Sources section, with the Phase-3 match keys.
///
/// Mirrors the app's `VolumeSourceEntry` (`FRUSDocumentParser.swift`): the same
/// `kind` / `depth` / `isHeading` structure and the same key columns
/// (`lotFileNorm` via `SourceNoteParser.lotFileNorm`, `decimalClass` via
/// `SourceNoteParser.decimalClassKey`, repository / record-group **inheritance** down
/// the outline), so authority identity always agrees with the keys the app writes to
/// `volume_sources` at index time.
public struct FrontSourceRow: Sendable, Equatable {
    /// Row kind, mirroring the app's `VolumeSourceKind`.
    public enum Kind: String, Sendable { case prose, item, bibliography }
    /// Row kind.
    public let kind: Kind
    /// Outline nesting depth (0 = a top-level collection).
    public let depth: Int
    /// Whether the item wrapped a `<hi rend="strong">` heading.
    public let isHeading: Bool
    /// Repository keyword (own or inherited from ancestor headings).
    public let repository: String?
    /// Record-group number (own or inherited).
    public let recordGroup: String?
    /// Raw lot-file number (formatting preserved), from the shared lot grammar.
    public let lotFile: String?
    /// Canonical compact lot key (`SourceNoteParser.lotFileNorm`).
    public let lotFileNorm: String?
    /// Decimal / subject-numeric class key (`SourceNoteParser.decimalClassKey` form).
    public let decimalClass: String?
    /// The row's own whitespace-collapsed text (excluding nested child items).
    public let text: String
}

/// Parses a FRUS volume's front-matter Sources section into flat, document-order rows
/// with the Phase-3 match keys.
///
/// A faithful port of the app's post-Phase-3 `SourcesParserDelegate`
/// (`FRUSDocumentParser.swift`), kept as a standalone port because the app's delegate is
/// private to the app target (the established generator precedent —
/// `VolumeSourcesIndexGeneratorCore.VolumeSourcesExtractor` is the pre-Phase-3 port that
/// feeds the schema-v2 `volume-sources-index.json`; this one carries the Phase-3
/// grammar). **All key-producing rules live in `SourceNoteKit`** — the shared lot
/// grammar (`firstLotReference`), `lotFileNorm`, and `decimalClassKey` — so a key
/// derived here and the same row keyed by the app at index time are identical by
/// construction. Ported structure: outline inheritance (repository / record group walk
/// up the open-item stack), bibliography detection (whole-section `listofworks` /
/// published-sources heads and the pseudo-heading `Published Sources` subtree with its
/// narrative-exit rules), heading flags, and pre-order emission.
public final class FrontMatterSourcesExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Extracts the Sources rows from a volume's TEI XML. Returns an empty array when
    /// the volume has no recognizable sources section.
    public static func extract(fromXML data: Data) -> [FrontSourceRow] {
        let delegate = FrontMatterSourcesExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.entries
    }

    /// Flat, document-order rows accumulated across all matching sections.
    public private(set) var entries: [FrontSourceRow] = []

    private var inSourcesSection = false
    private var elementDepth = 0
    private var sectionDepth = -1

    private var sectionIsBibliography = false
    private var inPublishedSubtree = false
    private var publishedSubtreeSawRows = false

    private var inSectionHead = false
    private var sectionHeadBuffer = ""

    private var openCounter = 0
    private var collected: [(order: Int, row: FrontSourceRow)] = []

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

    private static let publishedHeadingPat = try? NSRegularExpression(
        pattern: #"^(?:part [a-z][.:]? )?(?:selected )?published (?:sources|references)$"#)

    private static let unpublishedHeadingPat = try? NSRegularExpression(
        pattern: #"^(?:part [a-z][.:]? )?unpublished sources$"#)

    /// Normalizes a candidate heading and tests it against `pattern` (≤60 chars, lowercased,
    /// trailing periods stripped) — the app delegate's `matchesHeading`.
    private static func matchesHeading(_ text: String, _ pattern: NSRegularExpression?) -> Bool {
        guard let pattern, text.count <= 60 else { return false }
        var s = text.lowercased()
        while s.hasSuffix(".") { s = String(s.dropLast()) }
        s = s.trimmingCharacters(in: .whitespaces)
        let ns = NSRange(s.startIndex..., in: s)
        return pattern.firstMatch(in: s, range: ns) != nil
    }

    // Matches the app delegate (excludes "listofabbreviations", a terms glossary).
    private static let sourceSectionTypes: Set<String> = [
        "sources", "listofworks", "sources-and-abbreviations"
    ]

    /// Opens the sources section, tracks lists/items/heads, and flags headings.
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
            let matchedKind: String? = elementName == "div"
                ? [type, subtype, xmlId].first { Self.sourceSectionTypes.contains($0) }
                : nil
            if matchedKind != nil || elementName == "listBibl" {
                inSourcesSection = true
                sectionDepth     = elementDepth
                sectionIsBibliography = (matchedKind == "listofworks")
            }
        }
        guard inSourcesSection else { return }
        switch elementName {
        case "list":
            listDepth += 1
        case "head":
            if itemStack.isEmpty {
                inSectionHead = true
                sectionHeadBuffer = ""
            }
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

    /// Routes character data to the innermost open item, the section head, or prose.
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inSourcesSection else { return }
        if !itemStack.isEmpty {
            itemStack[itemStack.count - 1].text += string
        } else if inSectionHead {
            sectionHeadBuffer += string
        } else if inProse {
            proseBuffer += string
        }
    }

    /// Emits rows on item/paragraph close and finishes the section in pre-order.
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        guard inSourcesSection else { return }

        switch elementName {
        case "list":
            listDepth = max(0, listDepth - 1)
        case "head":
            if inSectionHead {
                if Self.matchesHeading(Self.collapseWhitespace(sectionHeadBuffer),
                                       Self.publishedHeadingPat) {
                    sectionIsBibliography = true
                }
                inSectionHead = false
                sectionHeadBuffer = ""
            }
        case "item":
            if let frame = itemStack.popLast() {
                let text = Self.collapseWhitespace(frame.text)
                if !text.isEmpty {
                    let row: FrontSourceRow
                    if sectionIsBibliography || inPublishedSubtree {
                        publishedSubtreeSawRows = true
                        row = FrontSourceRow(kind: .bibliography, depth: frame.depth,
                                             isHeading: frame.isHeading, repository: nil,
                                             recordGroup: nil, lotFile: nil, lotFileNorm: nil,
                                             decimalClass: nil, text: text)
                    } else {
                        let ancestors = itemStack.map { Self.collapseWhitespace($0.text) }
                        row = Self.makeItemRow(text: text, depth: frame.depth,
                                               isHeading: frame.isHeading,
                                               ancestorTexts: ancestors)
                    }
                    collected.append((frame.order, row))
                }
            }
        case "p":
            if inProse && itemStack.isEmpty {
                let text = Self.collapseWhitespace(proseBuffer)
                if !text.isEmpty {
                    collected.append((proseOrder,
                                      FrontSourceRow(kind: proseKind(for: text), depth: 0,
                                                     isHeading: false, repository: nil,
                                                     recordGroup: nil, lotFile: nil,
                                                     lotFileNorm: nil, decimalClass: nil,
                                                     text: text)))
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
            sectionIsBibliography = false
            inPublishedSubtree = false
            publishedSubtreeSawRows = false
            inSectionHead = false
            sectionHeadBuffer = ""
            inProse = false
            proseBuffer = ""
            itemStack.removeAll()
            listDepth = 0
        }
    }

    /// Prose-vs-bibliography routing for top-level paragraphs — the app delegate's
    /// `proseKind(for:)` rules (published pseudo-heading opens the subtree, unpublished
    /// heading closes it, a long narrative paragraph after rows exits it).
    private func proseKind(for text: String) -> FrontSourceRow.Kind {
        if sectionIsBibliography { return .bibliography }
        if Self.matchesHeading(text, Self.publishedHeadingPat) {
            inPublishedSubtree = true
            publishedSubtreeSawRows = false
            return .prose
        }
        if Self.matchesHeading(text, Self.unpublishedHeadingPat) {
            inPublishedSubtree = false
            return .prose
        }
        guard inPublishedSubtree else { return .prose }
        let isNarrativeExit = text.count > 200
            && publishedSubtreeSawRows
            && !text.lowercased().hasPrefix("note:")
        if isNarrativeExit {
            inPublishedSubtree = false
            return .prose
        }
        publishedSubtreeSawRows = true
        return .bibliography
    }

    /// Collapses interior whitespace runs to single spaces.
    private static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Builds an `.item` row: keys from the node's own text, with record group and
    /// repository inherited from ancestor headings (innermost first) — the app
    /// delegate's `makeItemEntry` without the series-name heuristic (the authority
    /// clusters on leading segments, not the heuristic tail).
    static func makeItemRow(text: String, depth: Int, isHeading: Bool,
                            ancestorTexts: [String]) -> FrontSourceRow {
        var rg = extractRecordGroup(from: text)
        var repo = extractRepository(from: text)
        let lot = SourceNoteParser.firstLotReference(in: text)?.lotNumber

        if rg == nil || repo == nil {
            for ancestor in ancestorTexts.reversed() {
                if rg == nil { rg = extractRecordGroup(from: ancestor) }
                if repo == nil { repo = extractRepository(from: ancestor) }
                if rg != nil && repo != nil { break }
            }
        }

        let decimalClass = (lot == nil) ? classLeafKey(from: text) : nil

        return FrontSourceRow(kind: .item, depth: depth, isHeading: isHeading,
                              repository: repo, recordGroup: rg, lotFile: lot,
                              lotFileNorm: lot.map { SourceNoteParser.lotFileNorm($0) },
                              decimalClass: decimalClass, text: text)
    }

    /// Extracts a record-group number (`RG 59`, `Record Group 84`) from `text`, or `nil`.
    static func extractRecordGroup(from text: String) -> String? {
        guard let regex = rgPat else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: ns) else { return nil }
        if m.range(at: 1).location != NSNotFound, let r = Range(m.range(at: 1), in: text) {
            return String(text[r])
        }
        if m.range(at: 2).location != NSNotFound, let r = Range(m.range(at: 2), in: text) {
            return String(text[r])
        }
        return nil
    }

    /// Repository keywords in match-priority order — identical to the app delegate's
    /// `repoKeywords`, so inherited repository identity matches the runtime rows.
    public static let repoKeywords = [
        "National Archives", "Library of Congress", "Washington National Records Center",
        "Kennedy Library", "Johnson Library", "Nixon", "Ford Library", "Carter Library",
        "Reagan Library", "Bush Library", "Clinton Library", "Eisenhower Library",
        "Truman Library", "Roosevelt Library", "Hoover Institution",
        "Central Intelligence Agency", "Department of State",
        "Department of Defense", "Naval Historical", "Center of Military History",
    ]

    /// Extracts the first repository keyword found in `text`, or `nil`.
    static func extractRepository(from text: String) -> String? {
        for keyword in repoKeywords where text.range(of: keyword, options: .caseInsensitive) != nil {
            return keyword
        }
        return nil
    }

    /// The decimal / subject-numeric class key for a class-leaf entry — the app
    /// delegate's `classLeafKey` (after-final-colon candidate first, then
    /// before-first-colon; semicolon lists; comma-described leading segment), gated by
    /// the shared `SourceNoteParser.decimalClassKey`.
    static func classLeafKey(from text: String) -> String? {
        var candidates: [String] = []
        if text.contains(":") {
            let parts = text.components(separatedBy: ":")
            if let last = parts.last { candidates.append(last) }
            if let first = parts.first { candidates.append(first) }
        } else {
            candidates.append(text)
        }
        for candidate in candidates {
            for segment in candidate.components(separatedBy: ";") {
                if let key = SourceNoteParser.decimalClassKey(segment) { return key }
                if segment.contains(","),
                   let lead = segment.components(separatedBy: ",").first,
                   let key = SourceNoteParser.decimalClassKey(lead) {
                    return key
                }
            }
        }
        return nil
    }
}
