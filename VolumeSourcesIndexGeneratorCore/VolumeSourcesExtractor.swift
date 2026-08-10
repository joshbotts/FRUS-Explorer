// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

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
    /// The raw CIA Job number (#733), formatting and dash variant preserved — a container
    /// identifier in its own right, kept out of `lotFile` because `lotFile` is looked up
    /// against `central-files-index.json`'s lot table and a job number is not a lot.
    public var jobNumber: String? = nil
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

    /// Whether this section emitted any `<item>` row (#668).
    private var sawItemRow = false
    /// Orders of the prose rows this section produced from a `<p rend="flushleft">`.
    private var flushLeftOrders: Set<Int> = []
    /// Whether the paragraph currently open carries `rend="flushleft"`.
    private var proseIsFlushLeft = false
    /// Whether the parse position is inside a published-works run — either the whole
    /// section (a `Published sources` `<head>`) or the subtree a `Published Sources`
    /// pseudo-heading paragraph opens.
    ///
    /// The app's delegate expresses this as a `.bibliography` row kind; `SourceRow` has no
    /// such case, so here it exists only to **withhold promotion**. Those rows stay `.prose`,
    /// exactly as they are today, which is why adding this costs nothing and omitting it
    /// would file `Dean Acheson, Present at the Creation` as an archival collection.
    private var inPublishedRun = false
    /// Whether a `<head>` is open at section level, and its accumulating text.
    private var inSectionHead = false
    private var sectionHeadBuffer = ""

    /// Anchored published-works heading shape, matched against a normalized candidate.
    /// The same pattern the app's `SourcesParserDelegate` uses — it reads the paragraph's
    /// **text**, not its `rend`, so it catches `smallcaps` spellings as well as `strong`.
    private static let publishedHeadingPat = try? NSRegularExpression(
        pattern: #"^(?:part [a-z][.:]? )?(?:selected )?published (?:sources|references)$"#)
    /// Anchored unpublished-sources heading shape; closes a published run.
    private static let unpublishedHeadingPat = try? NSRegularExpression(
        pattern: #"^(?:part [a-z][.:]? )?unpublished sources$"#)

    /// Normalizes a candidate heading and tests it. Candidates longer than 60 characters
    /// are never headings — they are narrative paragraphs containing the words.
    private static func matchesHeading(_ text: String, _ pattern: NSRegularExpression?) -> Bool {
        guard let pattern, text.count <= 60 else { return false }
        var s = text.lowercased()
        while s.hasSuffix(".") { s = String(s.dropLast()) }
        s = s.trimmingCharacters(in: .whitespaces)
        let ns = NSRange(s.startIndex..., in: s)
        return pattern.firstMatch(in: s, range: ns) != nil
    }

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
    // The lot grammar is NOT declared here any more (#733). It used to be
    // `#"\bLot\s+([\w\s\-]+?D\s*\d+)\b"#` — D-designator only — which is the regex the app
    // replaced at index version 18, and keeping the old one here meant this generator and the app
    // disagreed about what a lot is. Measured against the app's own table: **249 rows across 75
    // volumes** carry a lot this pattern cannot see, 225 of them F-designator posts
    // (`London Embassy Files, Lot 59 F 59`), plus A, M and B designators. Those collections were
    // simply absent from the bundled index. `SourceNoteParser.firstLotReference(in:)` is the one
    // grammar both sides now use.

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
        case "head":
            if itemStack.isEmpty {
                inSectionHead = true
                sectionHeadBuffer = ""
            }
        case "p":
            if itemStack.isEmpty {
                openCounter += 1
                proseOrder = openCounter
                inProse = true
                proseBuffer = ""
                proseIsFlushLeft = attributeDict["rend"]?.lowercased()
                    .contains("flushleft") ?? false
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
        } else if inSectionHead {
            sectionHeadBuffer += string
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
        case "head":
            if inSectionHead {
                // A whole published-works section (`<head>Published sources</head>` —
                // frus1969-76v34/v36, whose books are flushleft paragraphs with no `<item>`
                // in sight). Without this the promotion below would turn every one of them
                // into an archival collection.
                if Self.matchesHeading(Self.collapseWhitespace(sectionHeadBuffer),
                                       Self.publishedHeadingPat) {
                    inPublishedRun = true
                }
                inSectionHead = false
                sectionHeadBuffer = ""
            }
        case "item":
            if let frame = itemStack.popLast() {
                let text = Self.collapseWhitespace(frame.text)
                if !text.isEmpty {
                    collected.append((frame.order,
                                      Self.makeItemRow(text: text, depth: frame.depth,
                                                       isHeading: frame.isHeading)))
                    sawItemRow = true
                }
            }
        case "p":
            if inProse && itemStack.isEmpty {
                let text = Self.collapseWhitespace(proseBuffer)
                if !text.isEmpty {
                    // A `Published Sources` pseudo-heading opens the published run; an
                    // `Unpublished Sources` one closes it. The headings themselves stay prose.
                    if Self.matchesHeading(text, Self.publishedHeadingPat) {
                        inPublishedRun = true
                    } else if Self.matchesHeading(text, Self.unpublishedHeadingPat) {
                        inPublishedRun = false
                    } else if proseIsFlushLeft && !inPublishedRun {
                        flushLeftOrders.insert(proseOrder)
                    }
                    collected.append((proseOrder, SourceRow(kind: .prose, depth: 0, isHeading: false,
                                                            recordGroup: nil, lotFile: nil,
                                                            repository: nil, text: text)))
                }
                inProse = false
                proseBuffer = ""
                proseIsFlushLeft = false
            }
        default:
            break
        }

        if elementDepth <= sectionDepth {
            promoteFlushLeftHeadingsIfSectionHasNoItems()
            entries.append(contentsOf: collected.sorted { $0.order < $1.order }.map(\.row))
            collected.removeAll()
            inSourcesSection = false
            sectionDepth = -1
            inProse = false
            proseBuffer = ""
            proseIsFlushLeft = false
            sawItemRow = false
            flushLeftOrders.removeAll()
            inPublishedRun = false
            inSectionHead = false
            sectionHeadBuffer = ""
            itemStack.removeAll()
            listDepth = 0
        }
    }

    /// Promotes `<p rend="flushleft">` paragraphs to collection rows in a sources section
    /// that has no `<item>` outline at all (#668).
    ///
    /// The port of the app's `promoteFlushLeftHeadingsIfSectionHasNoItems()`, and it must
    /// stay one: the app parses this at index time while this builds
    /// `volume-sources-index.json`, and a volume that resolves in one and not the other is
    /// the exact split #668 reported. See the app's copy for the corpus measurement
    /// (15 volumes, 637 headings, 290 with a lot number) and the reasoning.
    ///
    /// Published-works rows are excluded at insertion time rather than here, because
    /// `SourceRow` has no `.bibliography` kind to test for.
    ///
    /// ## Two deliberate divergences from the app's copy
    /// Both were introduced by the #668 follow-up and are **intended**; do not "restore
    /// parity" without reading this.
    ///
    /// 1. The app absorbs each collection's following description paragraph into
    ///    `VolumeSourceEntry.note`, so the browser can render the two together. This
    ///    extractor leaves it a `.prose` row: `volume-sources-index.json` carries
    ///    collections and their resolved NAIDs, never descriptions, so absorbing it here
    ///    would change the row stream for no consumer.
    /// 2. The app's `proseKind` has a narrative-exit rule that ends a published run at a
    ///    paragraph over 200 characters; this extractor has none. That rule is what misfiled
    ///    16 of frus1950v07's books as archival collections — its 208-character
    ///    `S. L. A. Marshall …` citation tripped the threshold — and the app now refuses the
    ///    exit for flushleft paragraphs. Having no rule at all, this side was always correct
    ///    on that volume, and the fix brought the app back into agreement with it.
    private func promoteFlushLeftHeadingsIfSectionHasNoItems() {
        guard !sawItemRow, !flushLeftOrders.isEmpty else { return }
        for index in collected.indices where flushLeftOrders.contains(collected[index].order) {
            let row = collected[index].row
            guard row.kind == .prose, !Self.isSectionTitle(row.text) else { continue }
            collected[index].row = Self.makeItemRow(text: row.text, depth: 0, isHeading: false)
        }
    }

    /// Whether a flushleft paragraph is one of the series' boilerplate section titles
    /// (`Sources for the Foreign Relations Series`) rather than a collection name.
    ///
    /// Measured over the promoted corpus: **6 of 30,920 item rows begin `Sources for `, and
    /// all six are those titles**. The app's `SourcesParserDelegate.isSectionTitle` is the
    /// same test; keep them together.
    public static func isSectionTitle(_ text: String) -> Bool {
        text.lowercased().hasPrefix("sources for ")
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

        let lot = SourceNoteParser.firstLotReference(in: text)?.lotNumber

        // #733: the CIA Job number, from the same shared grammar the app and the document side
        // use. Read from the row's own text only — a job number identifies one container, so
        // inheriting it would key every sibling to the first child's collection.
        let job = SourceNoteParser.firstJobNumber(in: text)

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
                         recordGroup: rg, lotFile: lot, repository: repo,
                         jobNumber: job, text: text)
    }
}
