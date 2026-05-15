// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Parser Actor

/// Converts a FRUS volume XML file into an array of `FRUSDocumentAST` instances.
///
/// ## Architecture
/// `FRUSDocumentParser` is a Swift actor so that callers `await` the result without
/// blocking the main thread. Internally it delegates to `TEIParserDelegate`, a private
/// `NSObject` subclass that satisfies `XMLParserDelegate`.
///
/// ## Stack-Based Parsing
/// The delegate uses an explicit `[ParseFrame]` stack rather than recursion. Each start
/// element pushes a frame; each end element pops it, builds the corresponding `FRUSASTNode`,
/// and appends it to the parent frame's children list. Stack depth tracks the XML nesting,
/// not Swift call depth — this avoids stack-overflow risk in older FRUS volumes that
/// have very deep element hierarchies.
///
/// ## Whitespace Normalization
/// Rules applied during parsing (see `TEIParserDelegate.normalizedText`):
/// - Leading and trailing whitespace is trimmed from all text content.
/// - Multiple consecutive whitespace characters are collapsed to a single space.
/// - Text nodes containing only whitespace after normalization are discarded.
/// - These rules apply uniformly to both block and inline contexts in Session 06.
///   Session 07 may refine this for `<lb>` and `<formula>` elements.
///
/// ## Unknown Element Handling
/// Any TEI element not in the known-element table produces a `.unknown` AST node.
/// Unknown elements are never dropped and their text/child content is preserved.
/// This ensures forward compatibility when FRUS.odd gains new elements between app releases.
///
/// ## `xml:id` Attribute
/// FRUS TEI uses the `xml:id` attribute (W3C XML namespace). With Foundation's `XMLParser`
/// operating in non-namespace mode (the default), this attribute appears in the `attributes`
/// dictionary under the key `"xml:id"`. The parser also checks `"id"` as a fallback for
/// documents that omit the namespace prefix.
///
/// Version history:
///   1.0 — Session 06: initial implementation
public actor FRUSDocumentParser {

    public init() {}

    /// Parses all `<div type="document">` elements in the volume XML file.
    ///
    /// - Parameter volumeURL: The local file URL of the downloaded volume XML.
    /// - Returns: All documents in order of appearance, each as a `FRUSDocumentAST`.
    /// - Throws: `FRUSParserError` if the file cannot be read or parsed.
    public func parse(volumeURL: URL) async throws -> [FRUSDocumentAST] {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = TEIParserDelegate(targetDocumentId: nil)
        xmlParser.delegate = delegate
        xmlParser.parse()

        if let error = delegate.fatalError {
            throw FRUSParserError.xmlError(error)
        }

        #if DEBUG
        print("[TEIParser] Parsed \(delegate.documents.count) documents from \(volumeURL.lastPathComponent).")
        #endif

        return delegate.documents
    }

    /// Parses a single document by ID from the volume XML file.
    ///
    /// Parsing stops immediately after the target document's closing `</div>` tag,
    /// avoiding the cost of processing the remainder of potentially large volume files.
    ///
    /// - Parameters:
    ///   - documentId: The `xml:id` of the target `<div type="document">`.
    ///   - volumeURL: The local file URL of the downloaded volume XML.
    /// - Returns: The parsed document, or `nil` if no document with that ID exists.
    /// - Throws: `FRUSParserError` if the file cannot be read or parsed.
    public func parseDocument(documentId: String, volumeURL: URL) async throws -> FRUSDocumentAST? {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = TEIParserDelegate(targetDocumentId: documentId)
        delegate.parserRef = xmlParser
        xmlParser.delegate = delegate
        xmlParser.parse()

        if let error = delegate.fatalError {
            // Aborted parsing (document found) is not a real error.
            if delegate.foundTargetDocument { /* expected */ } else {
                throw FRUSParserError.xmlError(error)
            }
        }

        let result = delegate.documents.first { $0.documentId == documentId }
        #if DEBUG
        if result == nil {
            print("[TEIParser] Document '\(documentId)' not found in \(volumeURL.lastPathComponent).")
        }
        #endif
        return result
    }
}

// MARK: - Parser Error

/// Errors thrown by `FRUSDocumentParser`.
public enum FRUSParserError: Error, LocalizedError {
    case fileUnreadable(URL)
    case xmlError(Error)

    public var errorDescription: String? {
        switch self {
        case .fileUnreadable(let url): return "Cannot read TEI XML file: \(url.lastPathComponent)"
        case .xmlError(let e): return "XML parsing error: \(e.localizedDescription)"
        }
    }
}

// MARK: - Internal Delegate

/// SAX-style XMLParser delegate that builds `FRUSDocumentAST` instances using an explicit stack.
private final class TEIParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: Output

    var documents: [FRUSDocumentAST] = []
    var fatalError: Error?
    var foundTargetDocument = false

    // MARK: Configuration

    private let targetDocumentId: String?
    weak var parserRef: XMLParser?

    // MARK: Stack

    /// One frame per open XML element.
    private var stack: [ParseFrame] = []

    /// Depth of the current `<div type="document">` on the stack, or -1 if not inside one.
    private var documentDivDepth: Int = -1

    // MARK: Init

    init(targetDocumentId: String?) {
        self.targetDocumentId = targetDocumentId
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        // Flush any text that accumulated in the current top frame before pushing the new element.
        flushText()
        stack.append(ParseFrame(elementName: elementName, attributes: attributeDict))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].textBuffer += string
    }

    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        // Treat ignorable whitespace identically to character data; normalization will discard it.
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].textBuffer += whitespaceString
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        guard var frame = stack.popLast() else { return }

        // Flush remaining text buffer into children.
        let normalized = normalizedText(frame.textBuffer)
        if !normalized.isEmpty {
            frame.children.append(.text(normalized))
        }

        // Handle based on element type.
        if elementName == "div", frame.attributes["type"] == "document" {
            // Complete a FRUSDocumentAST from this document div.
            let docId = frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
            let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children)
            documents.append(doc)
            documentDivDepth = -1
            foundTargetDocument = (targetDocumentId == nil || docId == targetDocumentId)
            if foundTargetDocument, targetDocumentId != nil {
                // Found the target — abort parsing to avoid processing the rest of the file.
                parserRef?.abortParsing()
                return
            }
        } else if isTransparent(elementName: elementName, attributes: frame.attributes) {
            // Transparent element: pass children up to the parent frame.
            if !stack.isEmpty {
                stack[stack.count - 1].children.append(contentsOf: frame.children)
            }
        } else if let node = buildNode(elementName: elementName,
                                       attributes: frame.attributes,
                                       children: frame.children) {
            if !stack.isEmpty {
                stack[stack.count - 1].children.append(node)
            }
        }
        // If buildNode returns nil and the element is not transparent, the element is silently
        // dropped. This only happens for the root-level wrappers (TEI, text, body, front, back).
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Aborted parsing due to target document found — not a real error.
        if foundTargetDocument { return }
        fatalError = parseError
        #if DEBUG
        print("[TEIParser] Parse error: \(parseError)")
        #endif
    }

    // MARK: - Frame Helpers

    /// Flush the current top frame's text buffer by producing a normalized text node
    /// and appending it to the frame's children, then clearing the buffer.
    private func flushText() {
        guard !stack.isEmpty else { return }
        let text = normalizedText(stack[stack.count - 1].textBuffer)
        if !text.isEmpty {
            stack[stack.count - 1].children.append(.text(text))
        }
        stack[stack.count - 1].textBuffer = ""
    }

    /// Normalizes whitespace in character data:
    /// - Trims leading and trailing whitespace (spaces, tabs, newlines).
    /// - Collapses internal runs of whitespace to a single space.
    /// - Returns an empty string for whitespace-only input (caller discards these).
    ///
    /// This rule applies uniformly across block and inline contexts in Session 06.
    /// The effect is that inter-element newlines and indentation in the XML source
    /// do not produce spurious blank text nodes in the AST.
    private func normalizedText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Collapse internal whitespace runs.
        var result = ""
        var prevWasSpace = false
        for ch in trimmed {
            if ch.isWhitespace {
                if !prevWasSpace { result.append(" "); prevWasSpace = true }
            } else {
                result.append(ch); prevWasSpace = false
            }
        }
        return result
    }

    // MARK: - Transparent Elements

    /// Returns `true` for elements whose children should be passed directly to the
    /// parent frame without wrapping in an AST node.
    ///
    /// These are the structural wrappers in the FRUS TEI that carry no rendering meaning
    /// beyond grouping. Document-level `<div>` elements are handled separately above.
    private func isTransparent(elementName: String, attributes: [String: String]) -> Bool {
        switch elementName {
        case "TEI", "text", "body", "front", "back", "group":
            return true
        case "div":
            // Non-document div types are transparent in Session 06; Session 07 adds specific handling.
            let divType = attributes["type"] ?? ""
            return divType != "document"
        default:
            return false
        }
    }

    // MARK: - Node Builder

    /// Converts a closed XML element into an `FRUSASTNode`.
    ///
    /// Returns `nil` for elements that should be completely suppressed (the outermost
    /// volume wrappers handled by `isTransparent`). Returns `.unknown` for any element
    /// not in the known-element table, preserving its content for forward compatibility.
    private func buildNode(elementName: String,
                           attributes: [String: String],
                           children: [FRUSASTNode]) -> FRUSASTNode? {
        switch elementName {

        // MARK: Document structure
        case "head":
            return .head(children: children)

        case "dateline":
            return .dateline(children: children)

        case "opener":
            return .opener(children: children)

        case "closer":
            return .closer(children: children)

        case "salute":
            return .salute(children: children)

        // MARK: Content
        case "p":
            return .paragraph(children: children)

        case "note":
            let noteId = attributes["xml:id"] ?? attributes["id"]
            let type = FootnoteType(rawValue: attributes["type"] ?? "") ?? .unclassified
            return .footnote(id: noteId, type: type, children: children)

        // MARK: Inline links
        case "persName":
            let ref = attributes["ref"]
            return .persName(ref: ref, children: children)

        case "gloss":
            let ref = attributes["ref"]
            return .gloss(ref: ref, children: children)

        case "ref":
            let target = attributes["target"] ?? ""
            let (_, volumeId) = Self.parseRefTarget(target)
            return .crossReference(target: target, targetVolumeId: volumeId, children: children)

        // MARK: Inline formatting
        case "hi":
            let style = EmphasisStyle.from(rend: attributes["rend"])
            return .emphasis(style: style, children: children)

        case "term":
            return .term(children: children)

        // MARK: Root-level suppressed wrappers
        case "teiHeader", "fileDesc", "encodingDesc", "profileDesc", "revisionDesc",
             "titleStmt", "publicationStmt", "sourceDesc", "textClass":
            // Suppress — these are header elements, not document content.
            return nil

        // MARK: Unknown (forward compatibility)
        default:
            return .unknown(name: elementName, attributes: attributes, children: children)
        }
    }

    // MARK: - Reference Parsing

    /// Parses a `<ref target="...">` attribute value into its components.
    ///
    /// FRUS `target` attribute forms:
    ///   - `"#d42"` — reference to document `d42` in the same volume; `volumeId` is `nil`.
    ///   - `"frus1969-76v01#d42"` — cross-volume reference; `volumeId` is `"frus1969-76v01"`.
    ///   - `"https://..."` — external URL; `volumeId` is `nil`.
    ///
    /// Returns the original `target` string and the extracted `volumeId` (if present).
    static func parseRefTarget(_ target: String) -> (target: String, volumeId: String?) {
        guard !target.hasPrefix("#"), !target.hasPrefix("http") else {
            return (target, nil)
        }
        if let hashIndex = target.firstIndex(of: "#") {
            let volumeId = String(target[target.startIndex..<hashIndex])
            return (target, volumeId.isEmpty ? nil : volumeId)
        }
        return (target, nil)
    }
}

// MARK: - Parse Frame

private struct ParseFrame {
    let elementName: String
    let attributes: [String: String]
    var children: [FRUSASTNode] = []
    var textBuffer: String = ""
}

// MARK: - EmphasisStyle Extension

private extension EmphasisStyle {
    /// Maps the TEI `<hi rend="...">` attribute to an `EmphasisStyle`.
    /// FRUS uses `"italic"`, `"bold"`, `"smallcaps"`, `"underline"`.
    static func from(rend: String?) -> EmphasisStyle {
        switch rend?.lowercased() {
        case "italic", "i": return .italic
        case "bold", "b": return .bold
        case "smallcaps", "sc": return .smallCaps
        case "underline", "u": return .underline
        default: return .unspecified
        }
    }
}
