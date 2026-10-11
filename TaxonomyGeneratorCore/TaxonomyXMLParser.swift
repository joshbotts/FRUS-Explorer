// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TaxonomyXMLError

/// Why the repository's taxonomy file could not be read as a taxonomy (#1622).
///
/// Each is a file this parser will not guess at. A file that is well formed and holds no
/// category at all is not one of these: it parses to no entries, and `TaxonomyGate` refuses that.
///
/// Version history:
///   1.0 — #1622: initial implementation
public enum TaxonomyXMLError: Error, Equatable, Sendable, CustomStringConvertible {

    /// The data is not well-formed XML. `line` is where the parser stopped.
    case malformed(line: Int, reason: String)

    /// A `<category>` or `<tag>` that opens at `line` has no `<id>`, or an empty one.
    case missingID(line: Int)

    /// The `<category>` or `<tag>` with this id has no `<label>`, or an empty one.
    case missingLabel(id: String)

    /// Two elements carry this id. A volume's tag is joined to the taxonomy by it.
    case duplicateID(String)

    /// What the run prints for the error.
    public var description: String {
        switch self {
        case .malformed(let line, let reason):
            return "it is not well-formed XML (line \(line): \(reason))."
        case .missingID(let line):
            return "the category or tag that opens at line \(line) has no id."
        case .missingLabel(let id):
            return "\"\(id)\" has no label."
        case .duplicateID(let id):
            return "the id \"\(id)\" is given to two entries."
        }
    }
}

// MARK: - TaxonomyXMLParser

/// Parses `taxonomy/taxonomy.xml`, the file `history.state.gov/tags/all` is drawn from, into the
/// entries `TaxonomyParser` reads off that page (#1622).
///
/// ## The file
///
/// ```xml
/// <taxonomy>
///   <category>                       ← a root: people, places or topics. Not an entry.
///     <id>places</id><label>Places</label>
///     <category>                     ← an entry
///       <id>sovereign-territories</id><label>Sovereign Territories</label>
///       <tag>                        ← an entry, and so is each tag inside it
///         <id>near-east</id><label>Near East</label>
///         <tag><id>iran</id><label>Iran</label></tag>
///       </tag>
///     </category>
///   </category>
/// </taxonomy>
/// ```
///
/// A `<category>` and a `<tag>` are read alike: each has an `<id>`, a `<label>`, perhaps a
/// `<definition>` and a `<usage-hint>`, and its children. The id is the slug and the label the
/// display name. A usage hint is the Office's note to its own taggers and is not read. A tag
/// inside a comment is not read either, which is how the file withholds one today.
///
/// ## The same entries as the page gives
/// Measured against the file at HistoryAtState/tags `0e701226` (2026-10-11): 511 ids, the three
/// roots among them, and the 508 entries are the bundled taxonomy's field for field, so
/// `TaxonomyWriter` writes the bundled file byte for byte. `TaxonomyRepositoryFileTests` holds
/// that against a copy of the file. Three rules make it so:
///
/// - **Where an entry sits** is `TaxonomyParser`'s rule, stated on depth where that parser states
///   it on the slug: under a root an entry is its own subcategory and has no parent; under one of
///   `TaxonomyParser.structuralSlugs` it is its own subcategory and keeps the parent; anywhere
///   else its subcategory and its parent are the entry it sits in.
/// - **A definition is kept as written**, its line breaks and indentation included, with only
///   its ends trimmed. The page prints the file's text unchanged and `TaxonomyParser` trims no
///   more than that.
/// - **A `<ptr target="asylum"/>` in a definition is written as the page draws it**, a link to
///   the tag under the tag's label: `<a href="/tags/asylum">Asylum</a>`. Two shipped entries hold
///   such markup. No screen shows a tag's description, so it has not been seen.
///
/// One thing differs by construction and has no case today: an XML parser decodes `&amp;`, and
/// the page's text would keep it.
///
/// Version history:
///   1.0 — #1622: initial implementation
public struct TaxonomyXMLParser {

    private init() {}

    /// Parses the taxonomy file into a flat list of entries, in the file's order.
    ///
    /// - Parameter data: The file's bytes.
    /// - Returns: Every category and tag below the roots.
    /// - Throws: `TaxonomyXMLError` when the file is not XML, or an entry has no id or no label,
    ///   or two share an id.
    public static func parse(xml data: Data) throws -> [RawTaxonomyEntry] {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else {
            throw TaxonomyXMLError.malformed(
                line: parser.lineNumber,
                reason: parser.parserError?.localizedDescription ?? "the parser gave no reason")
        }

        // Every label by id, roots included: a definition may point at any of them.
        var labels: [String: String] = [:]
        func collect(_ node: Reader.Node) throws {
            for child in node.children {
                guard !child.id.isEmpty else { throw TaxonomyXMLError.missingID(line: child.line) }
                guard !child.label.isEmpty else { throw TaxonomyXMLError.missingLabel(id: child.id) }
                guard labels.updateValue(child.label, forKey: child.id) == nil else {
                    throw TaxonomyXMLError.duplicateID(child.id)
                }
                try collect(child)
            }
        }
        try collect(reader.top)

        var entries: [RawTaxonomyEntry] = []
        func emit(_ node: Reader.Node, category: String, parent: String, parentIsRoot: Bool) {
            let ownsItsSubcategory = parentIsRoot || TaxonomyParser.structuralSlugs.contains(parent)
            entries.append(RawTaxonomyEntry(
                slug: node.id,
                displayName: node.label,
                category: category,
                subcategory: ownsItsSubcategory ? node.id : parent,
                // A root is not a tag, so it is no entry's parent.
                parentSlug: parentIsRoot ? nil : parent,
                description: node.definition.flatMap { Self.text(of: $0, labels: labels) }))
            for child in node.children {
                emit(child, category: category, parent: node.id, parentIsRoot: false)
            }
        }
        for root in reader.top.children {
            for child in root.children {
                emit(child, category: root.id, parent: root.id, parentIsRoot: true)
            }
        }
        return entries
    }

    /// A definition as the page prints it: its text as written, a pointer as a link to the tag
    /// under the tag's label, and its ends trimmed. `nil` when nothing is left.
    private static func text(of definition: [Reader.Segment], labels: [String: String]) -> String? {
        let written = definition.map { segment -> String in
            switch segment {
            case .text(let text):
                return text
            case .pointer(let target):
                // A pointer at an id the file does not hold is drawn under the id.
                return "<a href=\"/tags/\(target)\">\(labels[target] ?? target)</a>"
            case .link(let href, let text):
                return "<a href=\"\(href)\">\(text)</a>"
            }
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return written.isEmpty ? nil : written
    }
}

// MARK: - Reader

/// The `XMLParser` delegate: the file's categories and tags as a tree.
private final class Reader: NSObject, XMLParserDelegate {

    /// One `<category>` or `<tag>`.
    final class Node {
        /// The line its element opens at, for an error that has no id to name.
        let line: Int
        var id = ""
        var label = ""
        /// `nil` when the element has no `<definition>`.
        var definition: [Segment]?
        var children: [Node] = []
        init(line: Int) { self.line = line }
    }

    /// One run of a definition's content.
    enum Segment {
        case text(String)
        /// `<ptr target="…"/>`.
        case pointer(String)
        /// `<a href="…">…</a>`.
        case link(href: String, text: String)
    }

    private enum Field { case id, label, definition }

    /// Stands for `<taxonomy>`: its children are the roots.
    let top = Node(line: 0)

    /// The open categories and tags, innermost last, under ``top``.
    private lazy var open: [Node] = [top]
    /// Every open element's name, innermost last.
    private var elements: [String] = []
    /// The field being read, and how deep its element is, so that an element of the same name
    /// inside it does not close it.
    private var field: (kind: Field, depth: Int)?
    private var text = ""
    private var segments: [Segment] = []
    /// The `href` of the `<a>` being read inside a definition.
    private var linkHref: String?
    private var linkText = ""

    private static let entryElements: Set<String> = ["category", "tag"]

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        defer { elements.append(elementName) }

        if let field {
            // Inside a definition, the two inline elements the file uses. Any other element's
            // text is kept and its tags are not.
            guard field.kind == .definition else { return }
            if elementName == "ptr" {
                flushText()
                segments.append(.pointer(attributeDict["target"] ?? ""))
            } else if elementName == "a", linkHref == nil {
                flushText()
                linkHref = attributeDict["href"] ?? ""
                linkText = ""
            }
            return
        }

        if Self.entryElements.contains(elementName) {
            let node = Node(line: parser.lineNumber)
            open.last?.children.append(node)
            open.append(node)
            return
        }

        // An id, a label or a definition counts only as the child of a category or a tag:
        // `<taxonomy>` has a title and a description of its own.
        guard let parent = elements.last, Self.entryElements.contains(parent) else { return }
        let kind: Field
        switch elementName {
        case "id": kind = .id
        case "label": kind = .label
        case "definition": kind = .definition
        default: return
        }
        field = (kind, elements.count)
        text = ""
        segments = []
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard field != nil else { return }
        if linkHref != nil {
            linkText += string
        } else {
            text += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        elements.removeLast()

        guard let field else {
            if Self.entryElements.contains(elementName), open.count > 1 { open.removeLast() }
            return
        }

        if elements.count > field.depth {
            // An element inside the field has closed.
            if elementName == "a", let href = linkHref {
                segments.append(.link(href: href, text: linkText))
                linkHref = nil
            }
            return
        }

        let node = open.last
        switch field.kind {
        case .id:
            node?.id = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .label:
            node?.label = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .definition:
            flushText()
            node?.definition = segments
        }
        self.field = nil
    }

    /// Moves the text read so far into the definition's segments.
    private func flushText() {
        guard !text.isEmpty else { return }
        segments.append(.text(text))
        text = ""
    }
}
