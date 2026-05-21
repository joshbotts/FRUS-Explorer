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
/// - Whitespace-only text nodes are discarded (suppress XML indentation noise).
/// - Leading/trailing whitespace in a non-empty text node is collapsed to a single
///   space, preserving the word-boundary space around inline styled elements
///   (e.g. `"Secretary "` before `<hi rend="italic">Kissinger</hi>`).
/// - Internal whitespace runs are collapsed to a single space.
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
///   1.0 — Session 06: initial implementation (core elements)
///   1.1 — Session 07: full element coverage; parsePersons / parseTerms methods added
///   1.2 — Session 34: structural-section fallback in TEIParserDelegate so front matter
///          (preface, introduction, errata) can be opened by xml:id in DocumentView
///   1.3 — Session 36: `<date>` element mapped to `.date` AST node; captures `@when`,
///          `@from`, `@to`, `@notBefore`, `@notAfter` for structured date indexing
///   1.4 — Session 38: `<div type="editorialNote">` promoted to full `FRUSDocumentAST` entries;
///          `VolumeStructureParserDelegate` records editorial note IDs in parent section's `documentIds`
///   1.5 — Session 42: `@n` attribute captured in `.footnote` as `printedNumber`
///   1.6 — Session 64: `parseVolumeFull` added; `VolumeFullParseResult` and
///          `FullVolumeParserDelegate` introduced to consolidate three passes into one
///   1.7 — Session 76: `frus:doc-dateTime-min`/`max` attributes captured from
///          `<div type="document">` and stored in `FRUSDocumentAST`; prose-only
///          structural sections (preface, introduction, foreword, appendix, etc.)
///          promoted to quasi-documents during full-volume parse so their content
///          is indexed by `IndexingPipeline`; `"foreword"` added to structural
///          type recognition in `VolumeStructureParserDelegate`
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
    /// Parsing stops immediately after the target element's closing `</div>` tag,
    /// avoiding the cost of processing the remainder of potentially large volume files.
    ///
    /// Handles two cases:
    ///   - `<div type="document" xml:id="...">` — a normal numbered FRUS document.
    ///   - Structural sections (`<div type="preface">`, `<div type="introduction">`, etc.)
    ///     that contain prose directly (no document sub-divs). These are matched by
    ///     `xml:id` and captured as quasi-documents so front matter is accessible via
    ///     `DocumentView` without requiring FTS indexing.
    ///
    /// - Parameters:
    ///   - documentId: The `xml:id` of the target `<div>`.
    ///   - volumeURL: The local file URL of the downloaded volume XML.
    /// - Returns: The parsed document, or `nil` if no element with that ID exists.
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

    /// Parses all person entries from `<div type="persons">` or `<listPerson>` in the volume.
    ///
    /// Each entry maps to the `xml:id` that `<persName ref="...">` elements reference.
    /// Returns an empty array if the volume contains no persons div.
    public func parsePersons(volumeURL: URL) async throws -> [PersonEntry] {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = PersonsParserDelegate()
        xmlParser.delegate = delegate
        xmlParser.parse()
        #if DEBUG
        print("[TEIParser] Parsed \(delegate.entries.count) person entries from \(volumeURL.lastPathComponent).")
        #endif
        return delegate.entries
    }

    /// Parses all term entries from `<div type="terms">` in the volume.
    ///
    /// Each entry maps to the `xml:id` that `<gloss ref="...">` elements reference.
    /// Returns an empty array if the volume contains no terms div.
    public func parseTerms(volumeURL: URL) async throws -> [GlossEntry] {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = TermsParserDelegate()
        xmlParser.delegate = delegate
        xmlParser.parse()
        #if DEBUG
        print("[TEIParser] Parsed \(delegate.entries.count) term entries from \(volumeURL.lastPathComponent).")
        #endif
        return delegate.entries
    }

    // MARK: - Combined Full Parse

    /// Parses documents, persons, and terms in a single XML pass over the volume file.
    ///
    /// Replaces three sequential `XMLParser(contentsOf:)` calls with one, using a
    /// composite `FullVolumeParserDelegate` that routes SAX events to the three
    /// existing sub-delegates simultaneously.
    ///
    /// The three sub-delegates are section-guarded (`inPersonsSection`,
    /// `inTermsSection`) so events outside their target `<div>` are no-ops.
    /// `TEIParserDelegate` treats `<div type="persons">` and `<div type="terms">`
    /// as transparent (not structural document divs), so no spurious `FRUSDocumentAST`
    /// entries are produced from front-matter content.
    ///
    /// - Parameter volumeURL: The local file URL of the downloaded volume XML.
    /// - Returns: A `VolumeFullParseResult` containing documents, persons, and terms.
    /// - Throws: `FRUSParserError` if the file cannot be read or the XML is malformed.
    public func parseVolumeFull(volumeURL: URL) async throws -> VolumeFullParseResult {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let composite = FullVolumeParserDelegate()
        xmlParser.delegate = composite
        xmlParser.parse()

        if let error = composite.teiDelegate.fatalError {
            throw FRUSParserError.xmlError(error)
        }

        #if DEBUG
        let name = volumeURL.lastPathComponent
        print("[TEIParser] parseVolumeFull: \(composite.teiDelegate.documents.count) docs, " +
              "\(composite.personsDelegate.entries.count) persons, " +
              "\(composite.termsDelegate.entries.count) terms from \(name).")
        #endif

        return VolumeFullParseResult(
            documents: composite.teiDelegate.documents,
            persons:   composite.personsDelegate.entries,
            terms:     composite.termsDelegate.entries
        )
    }

    // MARK: - Volume Structure

    /// Parses the structural outline of a volume without extracting document content.
    ///
    /// Performs a lightweight pass over the TEI XML to build the `VolumeStructure` —
    /// the hierarchy of compilations, chapters, appendices, front matter, and back matter,
    /// together with the `xml:id` values of the `<div type="document">` elements in each
    /// section. Used by the Browser view's Volume and Compilation/Chapter levels.
    ///
    /// - Parameter volumeURL: Path to the downloaded volume XML file.
    /// - Returns: The `VolumeStructure` for the volume.
    /// - Throws: `FRUSParserError` if the file cannot be read or the XML is malformed.
    public func parseVolumeStructure(volumeURL: URL) async throws -> VolumeStructure {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = VolumeStructureParserDelegate()
        xmlParser.delegate = delegate
        xmlParser.parse()
        if let err = delegate.fatalError { throw FRUSParserError.xmlError(err) }
        let volumeId = volumeURL.deletingPathExtension().lastPathComponent
        #if DEBUG
        print("[TEIParser] Parsed volume structure for \(volumeId): \(delegate.topLevelSections.count) sections.")
        #endif
        return VolumeStructure(volumeId: volumeId, sections: delegate.topLevelSections)
    }
}

// MARK: - Volume Structure Parser Delegate

/// Stack-based `XMLParserDelegate` that extracts only the structural hierarchy of a
/// FRUS TEI volume: compilations, chapters, appendices, front/back matter, and the
/// `xml:id` values of the `<div type="document">` elements in each section.
///
/// Documents, their content, editorial notes, and teiHeader are intentionally skipped.
private final class VolumeStructureParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: Output

    var topLevelSections: [VolumeSection] = []
    var fatalError: Error? = nil

    // MARK: Private State

    /// Stack frames for currently open structural sections.
    private struct Frame {
        var sectionId: String
        var divType: String
        var headParts: [String] = []
        var documentIds: [String] = []
        var subsections: [VolumeSection] = []
    }

    private var stack: [Frame] = []

    /// Tracks how deep we are inside a `<div type="document">` or `<teiHeader>` so
    /// that nested `<div>` elements inside documents are ignored.
    private var skipDepth: Int = 0

    /// Whether we are capturing text for the innermost section's `<head>`.
    private var capturingHead: Bool = false
    private var headNestDepth: Int = 0
    private var autoIdCounter: Int = 0

    // Div types that form structural sections above the document level.
    private static let structuralTypes: Set<String> = [
        "compilation", "chapter", "subchapter", "appendix",
        "preface", "intro", "introduction", "errata", "index", "foreword",
    ]

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {

        // Inside a document or header — count depth and ignore structure.
        if skipDepth > 0 {
            skipDepth += 1
            return
        }

        switch elementName {
        case "teiHeader":
            skipDepth = 1

        case "front":
            autoIdCounter += 1
            stack.append(Frame(sectionId: "front-\(autoIdCounter)", divType: "front"))

        case "back":
            autoIdCounter += 1
            stack.append(Frame(sectionId: "back-\(autoIdCounter)", divType: "back"))

        case "div":
            let divType = attrs["type"] ?? ""
            let xmlId   = attrs["xml:id"] ?? attrs["id"] ?? ""

            if divType == "document" || divType == "editorialNote" {
                // Start skipping — we don't descend into document content.
                skipDepth = 1
                // Record the document id in the current structural frame, if any.
                if (divType == "document" || divType == "editorialNote"), !xmlId.isEmpty, var top = stack.last {
                    top.documentIds.append(xmlId)
                    stack[stack.count - 1] = top
                }
            } else if Self.structuralTypes.contains(divType) {
                autoIdCounter += 1
                let id = xmlId.isEmpty ? "\(divType)-\(autoIdCounter)" : xmlId
                stack.append(Frame(sectionId: id, divType: divType))
            }
            // Unrecognised div types (type="persons", "terms", "toc", etc.) are ignored.

        case "head":
            // Capture head text only when inside a structural section frame.
            if !stack.isEmpty && !capturingHead {
                capturingHead = true
                headNestDepth = 1
            } else if capturingHead {
                headNestDepth += 1
            }

        default:
            if capturingHead { headNestDepth += 1 }
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {

        if skipDepth > 0 {
            skipDepth -= 1
            return
        }

        switch elementName {
        case "head":
            if capturingHead {
                headNestDepth -= 1
                if headNestDepth == 0 { capturingHead = false }
            }

        case "front", "back":
            popFrame()

        case "div":
            if !stack.isEmpty {
                popFrame()
            }

        default:
            if capturingHead, headNestDepth > 0 { headNestDepth -= 1 }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard capturingHead, !stack.isEmpty else { return }
        stack[stack.count - 1].headParts.append(string)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalError = parseError
    }

    // MARK: - Helpers

    private func popFrame() {
        guard let frame = stack.popLast() else { return }
        let rawTitle = frame.headParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? humanTitle(for: frame.divType) : rawTitle
        let section = VolumeSection(
            sectionId: frame.sectionId,
            divType: frame.divType,
            title: title,
            documentIds: frame.documentIds,
            subsections: frame.subsections
        )
        if stack.isEmpty {
            topLevelSections.append(section)
        } else {
            stack[stack.count - 1].subsections.append(section)
        }
    }

    private func humanTitle(for divType: String) -> String {
        switch divType {
        case "front":        return "Front Matter"
        case "back":         return "Back Matter"
        case "compilation":  return "Compilation"
        case "chapter":      return "Chapter"
        case "appendix":     return "Appendix"
        case "preface":      return "Preface"
        case "intro", "introduction": return "Introduction"
        case "errata":       return "Errata"
        default:             return divType.capitalized
        }
    }
}

// MARK: - Combined Parse Result

/// Return value of `FRUSDocumentParser.parseVolumeFull`.
///
/// Bundles the three artefacts produced by a single XML pass so callers
/// (`IndexingPipeline.parseAndExtract`) can replace three separate awaits
/// with one and eliminate two redundant disk reads.
public struct VolumeFullParseResult: Sendable {
    /// All `<div type="document">` and `<div type="editorialNote">` entries.
    public let documents: [FRUSDocumentAST]
    /// Person entries from `<div type="persons">` or `<listPerson>`.
    public let persons:   [PersonEntry]
    /// Term/abbreviation entries from `<div type="terms">`.
    public let terms:     [GlossEntry]
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

    /// Structural `div/@type` values that can be promoted to quasi-documents when they
    /// contain prose but no child `<div type="document">` or `<div type="editorialNote">`.
    /// Used during full-volume parses to index front-matter and appendix content.
    private static let structuralDivTypes: Set<String> = [
        "compilation", "chapter", "subchapter", "appendix",
        "preface", "intro", "introduction", "errata", "index", "foreword",
    ]

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
            // Capture pipeline-computed date range attributes when present.
            // frus:doc-dateTime-min/max are set by update-frus-doc-dates.xsl and represent
            // the authoritative editorial date bounds, normalized to xs:dateTime. Foundation's
            // XMLParser in non-namespace mode exposes namespaced attributes under their
            // qualified name (e.g. "frus:doc-dateTime-min").
            let dateTimeMin = frame.attributes["frus:doc-dateTime-min"]
            let dateTimeMax = frame.attributes["frus:doc-dateTime-max"]
            let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children,
                                      dateTimeMin: dateTimeMin, dateTimeMax: dateTimeMax)
            documents.append(doc)
            documentDivDepth = -1
            // Mark the enclosing frame so structural parent sections are not promoted
            // to quasi-documents when they also contain numbered documents.
            if !stack.isEmpty {
                stack[stack.count - 1].hasChildDocuments = true
            }
            foundTargetDocument = (targetDocumentId == nil || docId == targetDocumentId)
            if foundTargetDocument, targetDocumentId != nil {
                // Found the target — abort parsing to avoid processing the rest of the file.
                parserRef?.abortParsing()
                return
            }
        } else if elementName == "div",
                  let targetId = targetDocumentId,
                  !targetId.isEmpty,
                  (frame.attributes["xml:id"] ?? frame.attributes["id"]) == targetId {
            // Structural section div (e.g. preface, introduction) whose xml:id matches the
            // search target. Captured as a quasi-document so that `CompilationView` can open
            // prose-only front matter sections in DocumentView without FTS indexing.
            // Only reached when targetDocumentId is set (i.e. called from parseDocument).
            let docId = frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
            let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children)
            documents.append(doc)
            foundTargetDocument = true
            parserRef?.abortParsing()
            return
        } else if elementName == "div", frame.attributes["type"] == "editorialNote" {
            // Promote editorial note divs to full FRUSDocumentAST entries (Session 38).
            // The .editorialNote([children]) wrapper ensures DocumentView renders them with
            // the editorial note visual treatment (left-border block).
            let docId = frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
            let wrappedChildren: [FRUSASTNode] = [.editorialNote(frame.children)]
            let doc = FRUSDocumentAST(documentId: docId, nodes: wrappedChildren)
            documents.append(doc)
            if !stack.isEmpty {
                stack[stack.count - 1].hasChildDocuments = true
            }
        } else if elementName == "div",
                  targetDocumentId == nil,
                  let divType = frame.attributes["type"],
                  Self.structuralDivTypes.contains(divType),
                  !frame.hasChildDocuments,
                  !(frame.attributes["xml:id"] ?? frame.attributes["id"] ?? "").isEmpty,
                  !frame.children.isEmpty {
            // Prose-only structural section (preface, introduction, foreword, appendix, etc.)
            // with no child document divs. Promote to a quasi-document so the full-volume
            // parse indexes its content and makes it searchable. This covers front-matter
            // and appendix content that was previously viewable via DocumentView but invisible
            // to the FTS5 index. The section becomes its own indexed entity; children are not
            // bubbled to the parent.
            let docId = frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
            let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children)
            documents.append(doc)
        } else if isTransparent(elementName: elementName, attributes: frame.attributes) {
            // Transparent element: pass children up to the parent frame.
            // Propagate hasChildDocuments so that ancestor structural sections know a
            // descendant section contains documents — preventing the ancestor from being
            // incorrectly promoted to a quasi-document.
            if !stack.isEmpty {
                if frame.hasChildDocuments {
                    stack[stack.count - 1].hasChildDocuments = true
                }
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
    /// - Whitespace-only nodes are discarded (returns `""`); this suppresses the
    ///   inter-element newlines and indentation that appear throughout FRUS XML.
    /// - Leading and trailing whitespace is collapsed to a single space when present;
    ///   this preserves the single space that separates inline styled runs from
    ///   adjacent text (e.g. the space around `<hi rend="italic">word</hi>`).
    /// - Internal runs of whitespace are collapsed to a single space.
    ///
    /// Version history:
    ///   1.0 — Session 06: trim-and-collapse (uniform block+inline rule)
    ///   1.1 — Session 54: preserve single boundary spaces for inline contexts
    private func normalizedText(_ raw: String) -> String {
        // Whitespace-only nodes are still discarded.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Restore a single space at each boundary where the original had whitespace.
        // This keeps the space between e.g. "Secretary " and "<hi>Kissinger</hi>".
        let lead  = raw.first?.isWhitespace == true ? " " : ""
        let trail = raw.last?.isWhitespace  == true ? " " : ""
        // Collapse internal whitespace runs in the trimmed interior.
        var collapsed = ""
        var prevWasSpace = false
        for ch in trimmed {
            if ch.isWhitespace {
                if !prevWasSpace { collapsed.append(" "); prevWasSpace = true }
            } else {
                collapsed.append(ch); prevWasSpace = false
            }
        }
        return lead + collapsed + trail
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
            let divType = attributes["type"] ?? ""
            // "document" and "editorialNote" produce their own AST nodes.
            // All other div types (compilation, chapter, subseries, volume, persons, terms, etc.)
            // pass their children through to the parent — they are structural wrappers.
            return divType != "document" && divType != "editorialNote"
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

        case "date":
            return .date(
                when:      attributes["when"],
                from:      attributes["from"],
                to:        attributes["to"],
                notBefore: attributes["notBefore"],
                notAfter:  attributes["notAfter"],
                children:  children
            )

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
            let noteId       = attributes["xml:id"] ?? attributes["id"]
            let printedNum   = attributes["n"]
            let type         = FootnoteType(rawValue: attributes["type"] ?? "") ?? .unclassified
            return .footnote(id: noteId, type: type, printedNumber: printedNum, children: children)

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

        // MARK: Page breaks (Session 07)
        case "pb":
            let n = attributes["n"] ?? ""
            return .pageBreak(pageNumber: PageNumber.parse(n))

        // MARK: Tables (Session 07)
        case "table":
            return .table(children)

        case "row":
            return .tableRow(children)

        case "cell":
            let rowSpan = Int(attributes["rows"] ?? "1") ?? 1
            let colSpan = Int(attributes["cols"] ?? "1") ?? 1
            return .tableCell(rowSpan: rowSpan, colSpan: colSpan, children: children)

        // MARK: Lists (Session 07)
        case "list":
            let listType = ListType(rawValue: attributes["type"] ?? "")
            return .list(type: listType, items: children)

        case "item":
            return .listItem(children)

        // MARK: Structural divisions (Session 07)
        case "div":
            // Only "editorialNote" reaches buildNode; "document" is handled in didEndElement.
            return .editorialNote(children)

        case "titlePage":
            return .titlePage(children)

        // MARK: Figures and formulas (Session 07)
        case "figure":
            // Extract the graphic URL from a nested <graphic url="..."/> child if present.
            let graphicUrl: String? = children.compactMap { node -> String? in
                guard case .unknown(let name, let attrs, _) = node, name == "graphic" else { return nil }
                return attrs["url"]
            }.first
            let contentChildren = children.filter {
                guard case .unknown(let name, _, _) = $0 else { return true }
                return name != "graphic"
            }
            return .figure(graphic: graphicUrl, children: contentChildren)

        case "graphic":
            // Preserved as .unknown so the parent <figure> can extract the url attribute.
            return .unknown(name: "graphic", attributes: attributes, children: children)

        case "formula":
            let text = children.compactMap { node -> String? in
                guard case .text(let s) = node else { return nil }
                return s
            }.joined()
            return .formula(text)

        // MARK: Inline editorial marks (Session 07)
        case "supplied":
            return .supplied(children)

        case "sic":
            return .sic(children)

        case "corr":
            return .corr(children)

        // MARK: Line breaks (Session 07)
        case "lb":
            return .lineBreak

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
    /// Set to `true` when any `<div type="document">` or `<div type="editorialNote">`
    /// closes while this frame is on the stack, or when a transparent child frame
    /// with `hasChildDocuments = true` bubbles its children up. Used to prevent
    /// prose-only structural sections from being mistakenly promoted to quasi-documents
    /// when they also contain (direct or indirect) child document divs.
    var hasChildDocuments: Bool = false
}

// MARK: - Persons Parser Delegate

/// Minimal SAX delegate that extracts `PersonEntry` records from a FRUS volume.
///
/// Handles two common structures found across the corpus:
///   - `<listPerson><person xml:id="p1"><persName>Name</persName><note>Desc</note></person></listPerson>`
///   - `<div type="persons"><list><item xml:id="p1">Name: description</item></list></div>`
private final class PersonsParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    var entries: [PersonEntry] = []

    private var inPersonsSection = false
    private var inPersonElement = false
    private var currentId: String?
    private var currentName: String?
    private var textBuffer = ""
    private var elementDepth = 0
    private var personsSectionDepth = -1

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        if (elementName == "div" && attributeDict["type"] == "persons") ||
            elementName == "listPerson" {
            inPersonsSection = true
            personsSectionDepth = elementDepth
        }
        guard inPersonsSection else { return }
        if elementName == "person" || (elementName == "item" && personsSectionDepth >= 0) {
            inPersonElement = true
            currentId = attributeDict["xml:id"] ?? attributeDict["id"]
            currentName = nil
            textBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inPersonElement else { return }
        textBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        guard inPersonsSection else { return }
        if elementName == "persName" && currentName == nil {
            currentName = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            textBuffer = ""
        }
        if elementName == "person" || (elementName == "item" && personsSectionDepth >= 0) {
            let raw = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = currentId ?? raw
            if !id.isEmpty {
                let parts = raw.components(separatedBy: ":")
                let name = currentName
                    ?? parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? raw
                let desc = parts.count > 1
                    ? parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil
                if !name.isEmpty {
                    entries.append(PersonEntry(ref: id, name: name, description: desc?.isEmpty == true ? nil : desc))
                }
            }
            inPersonElement = false
            currentId = nil
            currentName = nil
            textBuffer = ""
        }
        // Use <= because elementDepth still equals personsSectionDepth at the
        // start of didEndElement (before the defer runs). This clears the section
        // flag when the persons <div> itself closes, preventing sibling elements
        // (e.g. <div type="terms">) from being captured as person entries.
        if elementDepth <= personsSectionDepth {
            inPersonsSection = false
            personsSectionDepth = -1
        }
    }
}

// MARK: - Terms Parser Delegate

/// Minimal SAX delegate that extracts `GlossEntry` records from a FRUS volume.
///
/// Handles the `<div type="terms">` structure:
///   `<list><item xml:id="t1"><term>Abbr.</term>: definition text</item></list>`
private final class TermsParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    var entries: [GlossEntry] = []

    private var inTermsSection = false
    private var inItem = false
    private var currentId: String?
    private var currentTerm: String?
    private var textBuffer = ""
    private var elementDepth = 0
    private var termsSectionDepth = -1

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        if elementName == "div" && attributeDict["type"] == "terms" {
            inTermsSection = true
            termsSectionDepth = elementDepth
        }
        guard inTermsSection else { return }
        if elementName == "item" {
            inItem = true
            currentId = attributeDict["xml:id"] ?? attributeDict["id"]
            currentTerm = nil
            textBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        textBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        guard inTermsSection else { return }
        if elementName == "term" && currentTerm == nil {
            currentTerm = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            textBuffer = ""
        }
        if elementName == "item" {
            let raw = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = currentId ?? (currentTerm ?? raw)
            if !id.isEmpty {
                let parts = raw.components(separatedBy: ":")
                let term = currentTerm
                    ?? parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? raw
                let def = parts.count > 1
                    ? parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil
                if !term.isEmpty {
                    entries.append(GlossEntry(ref: id, term: term, definition: def?.isEmpty == true ? nil : def))
                }
            }
            inItem = false
            currentId = nil
            currentTerm = nil
            textBuffer = ""
        }
        if elementDepth <= termsSectionDepth {
            inTermsSection = false
            termsSectionDepth = -1
        }
    }
}

// MARK: - Composite Full-Volume Delegate

/// Composite `XMLParserDelegate` that forwards every SAX event to three
/// sub-delegates simultaneously, enabling a single `XMLParser` pass to
/// produce documents, persons, and terms.
///
/// ## Safety
/// - `PersonsParserDelegate` and `TermsParserDelegate` both guard all
///   mutations on `inPersonsSection` / `inTermsSection`; events outside
///   those sections are no-ops, so forwarding unconditionally is safe.
/// - `TEIParserDelegate(targetDocumentId: nil)` treats `<div type="persons">`
///   and `<div type="terms">` as unrecognised div types (not "document" or
///   "editorialNote") and skips their content — no spurious `FRUSDocumentAST`
///   entries are produced from front-matter material.
/// - `foundIgnorableWhitespace` is forwarded only to `teiDelegate` because
///   the other two delegates don't implement it.
private final class FullVolumeParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    let teiDelegate:     TEIParserDelegate     = TEIParserDelegate(targetDocumentId: nil)
    let personsDelegate: PersonsParserDelegate = PersonsParserDelegate()
    let termsDelegate:   TermsParserDelegate   = TermsParserDelegate()

    // MARK: - XMLParserDelegate Forwarding

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        teiDelegate    .parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        personsDelegate.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        termsDelegate  .parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        teiDelegate    .parser(parser, foundCharacters: string)
        personsDelegate.parser(parser, foundCharacters: string)
        termsDelegate  .parser(parser, foundCharacters: string)
    }

    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        // Only TEIParserDelegate implements foundIgnorableWhitespace.
        teiDelegate.parser(parser, foundIgnorableWhitespace: whitespaceString)
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        teiDelegate    .parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
        personsDelegate.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
        termsDelegate  .parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        teiDelegate.parser(parser, parseErrorOccurred: parseError)
    }
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
