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
///   1.8 — Session 77: `<choice>` handled in `buildNode` — only the preferred form
///          (`<corr>` > `<reg>` > first non-sic child) is returned; `<sic>` suppressed
///   1.9 — Session 78: `<note rend="inline">` made transparent in `isTransparent` so
///          its children flow inline; `<frus:attachment>` handled in `buildNode` as
///          `.attachment(n:children:)` AST node
///   2.0 — Session 79: `<ab>` mapped to `.paragraph` in `buildNode`
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

    /// Parses the target document **and a surrounding window** in a single pass.
    ///
    /// SAX parsing must start from the beginning of the file, so by the time the
    /// target document is reached every preceding document has already been parsed —
    /// this method returns them instead of discarding them, plus `trailingDocuments`
    /// additional documents past the target, so callers can warm an AST cache and
    /// make adjacent-document navigation (Read-mode page-turns) instant.
    ///
    /// - Parameters:
    ///   - documentId: The `xml:id` of the target `<div>`.
    ///   - volumeURL: The local file URL of the downloaded volume XML.
    ///   - trailingDocuments: How many documents past the target to include. Default 1.
    /// - Returns: All documents parsed before the abort, in volume order. Empty if
    ///   no element with the target ID exists.
    /// - Throws: `FRUSParserError` if the file cannot be read or parsed.
    public func parseDocumentWindow(
        documentId: String,
        volumeURL: URL,
        trailingDocuments: Int = 1
    ) async throws -> [FRUSDocumentAST] {
        guard let xmlParser = XMLParser(contentsOf: volumeURL) else {
            throw FRUSParserError.fileUnreadable(volumeURL)
        }
        let delegate = TEIParserDelegate(
            targetDocumentId: documentId,
            trailingDocumentsAfterTarget: trailingDocuments
        )
        delegate.parserRef = xmlParser
        xmlParser.delegate = delegate
        _ = autoreleasepool { xmlParser.parse() }

        if let error = delegate.fatalError {
            // Aborted parsing (target found) is not a real error. Reaching EOF with
            // fewer trailing documents than requested (target near the end of the
            // volume) is also fine — XMLParser reports no error for clean EOF.
            if delegate.foundTargetDocument { /* expected */ } else {
                throw FRUSParserError.xmlError(error)
            }
        }
        guard delegate.foundTargetDocument else { return [] }
        return delegate.documents
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
        // `autoreleasepool` ensures the XMLParser's internal Objective-C allocations
        // (NSXMLParser event buffers, NSString attribute dictionaries) are drained as
        // soon as parsing finishes rather than accumulating until the enclosing async
        // task's autorelease pool drains. This is particularly important on iOS where
        // large FRUS volumes (3–15 MB XML) can create tens of thousands of temporary
        // ObjC objects; without a pool, peak RSS can exceed the system's jetsam limit
        // mid-batch and cause the indexer to be killed.
        // `xmlParser.parse()` returns Bool but we rely on `teiDelegate.fatalError`
        // for error detection; discarding the Bool is intentional.
        _ = autoreleasepool { xmlParser.parse() }

        if let error = composite.teiDelegate.fatalError {
            throw FRUSParserError.xmlError(error)
        }

        #if DEBUG
        let name = volumeURL.lastPathComponent
        print("[TEIParser] parseVolumeFull: \(composite.teiDelegate.documents.count) docs, " +
              "\(composite.personsDelegate.entries.count) persons, " +
              "\(composite.termsDelegate.entries.count) terms, " +
              "\(composite.sourcesDelegate.entries.count) sources from \(name).")
        #endif

        return VolumeFullParseResult(
            documents:     composite.teiDelegate.documents,
            persons:       composite.personsDelegate.entries,
            terms:         composite.termsDelegate.entries,
            volumeSources: composite.sourcesDelegate.entries,
            structureSections: composite.structureDelegate.topLevelSections
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
        /// `true` for unrecognised wrapper divs: the frame exists only to keep
        /// open/close events balanced; on pop, its documents and subsections bubble
        /// up to the parent instead of emitting a `VolumeSection`.
        var isTransparent: Bool = false
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

    // Div types that form structural sections above the document level when they
    // appear as literal `type` values. The real corpus encodes front/back matter as
    // `type="section"` + `subtype` (resolved by `structuralKind`); these literal
    // values cover body structure plus the legacy fixture vocabulary.
    private static let structuralTypes: Set<String> = [
        "compilation", "chapter", "subchapter", "appendix",
        "preface", "intro", "introduction", "errata", "index", "foreword",
        "prefatoryNote", "sources", "persons", "terms",
    ]

    /// Resolves a `<div>`'s effective structural kind from its attributes, or `nil`
    /// when the div is not structural (an unknown wrapper — tracked as a transparent
    /// frame so its children bubble up to the correct parent).
    ///
    /// ## Real corpus encoding (verified against HistoryAtState/frus, 2026-06-10)
    /// Front/back matter is `<div type="section" subtype="…" xml:id="…">`:
    /// `subtype` ∈ {preface, sources, table-of-contents, press-release,
    /// volume-summary, about-frus-series, errata, index, historical-document}.
    /// The Persons and Terms glossaries are `subtype="index"` distinguished by
    /// `xml:id` (`"persons"` / `"terms"` / `"abbreviations"`), matching the pattern
    /// `PersonsParserDelegate` and `TermsParserDelegate` already key on. The 1861-era
    /// volume uses a bare `type="toc"`, normalised to `"table-of-contents"`.
    static func structuralKind(type: String, subtype: String, xmlId: String) -> String? {
        if type == "section" {
            if subtype == "index" {
                switch xmlId.lowercased() {
                case "persons", "persname", "listofpersons":
                    return "persons"
                case "terms", "abbreviations", "listofabbreviations":
                    return "terms"
                default:
                    return "index"
                }
            }
            if !subtype.isEmpty { return subtype }
            if !xmlId.isEmpty { return xmlId.lowercased() }
            return "section"
        }
        if type == "toc" { return "table-of-contents" }
        return structuralTypes.contains(type) ? type : nil
    }

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
            let subtype = attrs["subtype"] ?? ""
            let xmlId   = attrs["xml:id"] ?? attrs["id"] ?? ""

            if divType == "document" || divType == "editorialNote" {
                // Start skipping — we don't descend into document content.
                skipDepth = 1
                // Record the document id in the current structural frame, if any.
                if (divType == "document" || divType == "editorialNote"), !xmlId.isEmpty, var top = stack.last {
                    top.documentIds.append(xmlId)
                    stack[stack.count - 1] = top
                }
            } else if let kind = Self.structuralKind(type: divType, subtype: subtype, xmlId: xmlId) {
                autoIdCounter += 1
                let id = xmlId.isEmpty ? "\(kind)-\(autoIdCounter)" : xmlId
                stack.append(Frame(sectionId: id, divType: kind))
            } else {
                // Unrecognised div type — push a transparent frame so this div's
                // closing tag pops *itself* rather than a real structural frame.
                // (Previously, every unmatched </div> popped the current frame,
                // which detached the <front> wrapper from its sections in every
                // real volume.)
                autoIdCounter += 1
                stack.append(Frame(sectionId: "transparent-\(autoIdCounter)",
                                   divType: divType,
                                   isTransparent: true))
            }

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

    /// Collapses interior whitespace runs to single spaces and trims the ends. TEI `<head>`
    /// elements are hard-wrapped in the source XML, and `foundCharacters` delivers the text
    /// in fragments around nested markup, so a joined title otherwise carries embedded
    /// newlines and ragged indentation into the stored section title.
    private static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func popFrame() {
        guard let frame = stack.popLast() else { return }

        if frame.isTransparent {
            // Bubble the unrecognised wrapper's children up to its parent so
            // structure nested inside unknown div types is never lost. Documents
            // attach to the parent (matching the pre-frame behaviour, where they
            // were recorded against the enclosing structural section directly).
            if stack.isEmpty {
                topLevelSections.append(contentsOf: frame.subsections)
                if !frame.documentIds.isEmpty {
                    // Top-level documents inside an unknown wrapper still need a
                    // navigable home; emit the wrapper as a generic section.
                    let rawTitle = Self.collapseWhitespace(frame.headParts.joined())
                    topLevelSections.append(VolumeSection(
                        sectionId: frame.sectionId,
                        divType: "section",
                        title: rawTitle.isEmpty ? humanTitle(for: "section") : rawTitle,
                        documentIds: frame.documentIds,
                        subsections: []
                    ))
                }
            } else {
                stack[stack.count - 1].subsections.append(contentsOf: frame.subsections)
                stack[stack.count - 1].documentIds.append(contentsOf: frame.documentIds)
            }
            return
        }

        let rawTitle = Self.collapseWhitespace(frame.headParts.joined())
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
        case "front":          return "Front Matter"
        case "back":           return "Back Matter"
        case "compilation":    return "Compilation"
        case "chapter":        return "Chapter"
        case "appendix":       return "Appendix"
        case "preface":        return "Preface"
        case "intro", "introduction": return "Introduction"
        case "errata":         return "Errata"
        case "prefatoryNote":  return "Prefatory Note"
        case "sources":        return "Sources"
        case "persons":        return "Persons"
        case "terms":          return "Terms and Abbreviations"
        case "table-of-contents": return "Contents"
        case "press-release":  return "Press Release"
        case "volume-summary": return "Summary"
        case "about-frus-series": return "About the Series"
        case "historical-document": return "Document"
        case "index":          return "Index"
        case "section":        return "Section"
        default:               return divType.capitalized
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
    public let documents:      [FRUSDocumentAST]
    /// Person entries from `<div type="persons">` or `<listPerson>`.
    public let persons:        [PersonEntry]
    /// Term/abbreviation entries from `<div type="terms">`.
    public let terms:          [GlossEntry]
    /// Archival source entries from the volume front-matter sources list.
    public let volumeSources:  [VolumeSourceEntry]
    /// Top-level structural sections (compilations, chapters, front/back matter)
    /// for the Browser hierarchy. Persisted to `volume_structures` at index time
    /// so browsing an indexed volume never re-parses its XML.
    public let structureSections: [VolumeSection]
}

/// Whether a `VolumeSourceEntry` is a narrative "Note on Sources" paragraph or a node in
/// the archival-collection outline.
public enum VolumeSourceKind: String, Sendable {
    /// A narrative paragraph from the section's prose introduction.
    case prose
    /// An archival-collection outline node (a repository, record group, series, or lot file).
    case item
}

/// One row of a FRUS volume's front-matter Sources section.
///
/// The section has two parts: narrative `.prose` paragraphs (the "Note on Sources"
/// introduction) followed by a nested `.item` outline of the archival collections the
/// volume drew on. Rows are produced flat in document (pre-order) order; `depth`
/// (0 = a top-level collection) and `isHeading` (the item wrapped a `<hi rend="strong">` —
/// i.e. a major named collection) let the browser rebuild and render the outline.
///
/// Produced by `SourcesParserDelegate` when it encounters a `<div type="sources">`,
/// `<div type="listofworks">`, or `<listBibl>` section.
public struct VolumeSourceEntry: Sendable {
    public let kind: VolumeSourceKind
    public let depth: Int
    public let isHeading: Bool
    public let repository: String?
    public let recordGroup: String?
    public let lotFile: String?
    public let seriesName: String?
    /// The entry's own text (whitespace-collapsed), excluding any nested child items.
    public let rawText: String

    public init(kind: VolumeSourceKind, depth: Int = 0, isHeading: Bool = false,
                repository: String? = nil, recordGroup: String? = nil, lotFile: String? = nil,
                seriesName: String? = nil, rawText: String) {
        self.kind = kind
        self.depth = depth
        self.isHeading = isHeading
        self.repository = repository
        self.recordGroup = recordGroup
        self.lotFile = lotFile
        self.seriesName = seriesName
        self.rawText = rawText
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

    /// Number of additional documents to parse *after* the target before aborting.
    ///
    /// `0` (default) preserves the original `parseDocument` behaviour: abort the
    /// moment the target's closing `</div>` is seen. `parseDocumentWindow` passes
    /// `1` so the next document is captured too, pre-warming the AST cache for the
    /// Read-mode forward page-turn.
    let trailingDocumentsAfterTarget: Int

    /// Trailing documents still to parse once the target has completed.
    private var trailingRemaining: Int = 0

    weak var parserRef: XMLParser?

    // MARK: Stack

    /// One frame per open XML element.
    private var stack: [ParseFrame] = []

    /// Depth of the current `<div type="document">` on the stack, or -1 if not inside one.
    private var documentDivDepth: Int = -1

    /// Section kinds eligible for quasi-document promotion into the FTS5 index.
    ///
    /// The body-structure types (compilation, chapter, …) are included because a
    /// prose-only chapter or appendix is still worth indexing; the section kinds
    /// cover the real corpus front/back matter. Excluded by design:
    /// `"persons"`/`"sources"` (structured data with dedicated views and tables),
    /// `"table-of-contents"`/`"index"` (navigation aids — page numbers and chapter
    /// titles would pollute search results), and `"section"` (unidentifiable).
    private static let promotableQuasiDocumentKinds: Set<String> = [
        "compilation", "chapter", "subchapter", "appendix",
        "preface", "intro", "introduction", "errata", "foreword",
        "prefatoryNote", "terms",
        "press-release", "volume-summary", "about-frus-series",
        "historical-document",
    ]

    // MARK: Init

    init(targetDocumentId: String?, trailingDocumentsAfterTarget: Int = 0) {
        self.targetDocumentId = targetDocumentId
        self.trailingDocumentsAfterTarget = trailingDocumentsAfterTarget
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
            // The canonical history.state.gov document number is the `@n` on the document
            // div (e.g. n="17"). Present for every document — including early-volume
            // documents that were unnumbered in print. Trimmed and emptied-to-nil so a stray
            // `n=""` falls back to the head-text heuristic downstream.
            let trimmedN = frame.attributes["n"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let printedNumber = (trimmedN?.isEmpty == false) ? trimmedN : nil
            // The real corpus marks editorial notes as `type="document"
            // subtype="editorial-note"` (the standalone `type="editorialNote"`
            // encoding below exists only in legacy fixtures). Wrap their content in
            // the .editorialNote node so rendering, badges, the document-type search
            // filter, and `document_cache.is_editorial_note` all recognise them.
            let nodes: [FRUSASTNode]
            if frame.attributes["subtype"] == "editorial-note" {
                nodes = [.editorialNote(frame.children)]
            } else {
                nodes = frame.children
            }
            let doc = FRUSDocumentAST(documentId: docId, nodes: nodes,
                                      dateTimeMin: dateTimeMin, dateTimeMax: dateTimeMax,
                                      printedNumber: printedNumber)
            documents.append(doc)
            documentDivDepth = -1
            // Mark the enclosing frame so structural parent sections are not promoted
            // to quasi-documents when they also contain numbered documents.
            if !stack.isEmpty {
                stack[stack.count - 1].hasChildDocuments = true
            }
            if targetDocumentId != nil {
                if foundTargetDocument {
                    // A document completed *after* the target — part of the trailing
                    // window requested via `trailingDocumentsAfterTarget` (used to
                    // pre-warm the AST cache for forward page-turns).
                    trailingRemaining -= 1
                    if trailingRemaining <= 0 {
                        parserRef?.abortParsing()
                        return
                    }
                } else if docId == targetDocumentId {
                    foundTargetDocument = true
                    trailingRemaining = trailingDocumentsAfterTarget
                    if trailingRemaining <= 0 {
                        // No trailing window requested — abort immediately to avoid
                        // processing the rest of the file (original behaviour).
                        parserRef?.abortParsing()
                        return
                    }
                }
            } else {
                foundTargetDocument = true
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
                  let kind = VolumeStructureParserDelegate.structuralKind(
                      type: frame.attributes["type"] ?? "",
                      subtype: frame.attributes["subtype"] ?? "",
                      xmlId: frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
                  ),
                  Self.promotableQuasiDocumentKinds.contains(kind),
                  !frame.hasChildDocuments,
                  !(frame.attributes["xml:id"] ?? frame.attributes["id"] ?? "").isEmpty,
                  !frame.children.isEmpty {
            // Prose-only structural section (preface, press release, summary, etc.)
            // with no child document divs. Promote to a quasi-document so the
            // full-volume parse indexes its content and makes it searchable. The
            // section's *kind* is resolved from the real corpus encoding
            // (`type="section"` + `subtype` + `xml:id`); persons, sources, tables of
            // contents, and name indexes are excluded — they are structured data
            // with dedicated views, or navigation aids whose text would only add
            // noise to full-text search. The section becomes its own indexed
            // entity; children are not bubbled to the parent.
            let docId = frame.attributes["xml:id"] ?? frame.attributes["id"] ?? ""
            // Mark as front matter so IndexingPipeline can set is_front_matter in document_cache.
            let isFrontMatter = VolumeSection.frontMatterKinds.contains(kind) && kind != "front"
            let doc = FRUSDocumentAST(documentId: docId, nodes: frame.children,
                                      isFrontMatter: isFrontMatter)
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

    /// Strips leading whitespace from the first text child and trailing whitespace
    /// from the last text child of an inline element's children array.
    ///
    /// `normalizedText` intentionally preserves a single " " at the boundary of a text
    /// run when the raw XML had whitespace there (so "Secretary " + link text + " said"
    /// renders with correct inter-word spacing). For inline links like `<persName>` the
    /// element's OWN content should not carry boundary spaces — those come from the
    /// surrounding text nodes. Stripping here prevents a `<persName>` that wraps its
    /// content onto a separate XML line from contributing an extra space to the flat text
    /// and shifting highlight character offsets.
    private func trimInlineTextBoundaries(_ nodes: [FRUSASTNode]) -> [FRUSASTNode] {
        guard !nodes.isEmpty else { return nodes }
        var result = nodes

        // Trim leading whitespace from first text node
        if case .text(let s) = result[0] {
            let trimmed = s.drop(while: { $0 == " " || $0 == "\t" })
            if trimmed.isEmpty {
                result.removeFirst()
            } else if trimmed.count != s.count {
                result[0] = .text(String(trimmed))
            }
        }

        // Trim trailing whitespace from last text node (after possible removeFirst above)
        if !result.isEmpty, case .text(let s) = result[result.count - 1] {
            var end = s.endIndex
            while end > s.startIndex {
                let prev = s.index(before: end)
                if s[prev] == " " || s[prev] == "\t" { end = prev } else { break }
            }
            let trimmed = String(s[s.startIndex..<end])
            if trimmed.isEmpty {
                result.removeLast()
            } else if trimmed.count != s.count {
                result[result.count - 1] = .text(trimmed)
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
            let divType = attributes["type"] ?? ""
            // "document" and "editorialNote" produce their own AST nodes.
            // All other div types (compilation, chapter, subseries, volume, persons, terms, etc.)
            // pass their children through to the parent — they are structural wrappers.
            return divType != "document" && divType != "editorialNote"
        case "note":
            // <note rend="inline"> renders its children inline in the text flow rather
            // than as a superscript footnote reference. Used for attachment label phrases
            // such as <note rend="inline">Attachment</note> before a frus:attachment heading.
            //
            // Exception: <note type="source" rend="inline"> must NOT be transparent.
            // These are withheld-document provenance notes (e.g. "[Source: Johnson Library,
            // National Security File... Not declassified.]"). Making them transparent
            // hoists their text into the surrounding paragraph as plain characters,
            // which prevents extractSourceNote from finding a .footnote(type: .source)
            // node. The FRUS schema's type="source" attribute is the canonical marker
            // for provenance notes; it takes precedence over the inline rendering hint.
            if attributes["type"] == "source" { return false }
            return attributes["rend"] == "inline"
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
            // FRUS TEI uses "corresp" in document body (e.g. corresp="#p_AH1").
            // Fall back to "ref" for volumes that use the alternative attribute.
            let ref = attributes["corresp"] ?? attributes["ref"]
            // Strip boundary whitespace from the first and last text children.
            // normalizedText preserves a leading/trailing " " when the raw XML has
            // whitespace at the element boundary (e.g. when persName content is on its
            // own line). For inline links this spurious space shifts flat-text offsets
            // and can produce a visible extra space in the rendered link.
            return .persName(ref: ref, children: trimInlineTextBoundaries(children))

        case "gloss":
            // FRUS TEI uses "target" for gloss links (e.g. target="#t_NSC1").
            // Fall back to "ref" for volumes that use the alternative attribute.
            let ref = attributes["target"] ?? attributes["ref"]
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

        // MARK: Anonymous blocks and attachments (Session 79 / 78)
        case "ab":
            // <ab> (anonymous block) is a paragraph-equivalent used for short prose
            // blocks that don't fit <p>, <head>, or <label> — e.g. captions, rubrics,
            // inscriptions. Map directly to .paragraph so it renders as body text.
            return .paragraph(children: children)

        case "frus:attachment":
            // Foundation's XMLParser in non-namespace mode delivers the qualified
            // name ("frus:attachment") as the element name. No div/@type equivalent
            // exists in the FRUS schema; this namespaced element is the sole mechanism.
            return .attachment(n: attributes["n"], children: children)

        // MARK: Choice (Session 77)
        case "choice":
            // Render only the preferred form; suppress <sic> entirely.
            // Priority: <corr> > <reg> > first child.
            // Both <sic> and <corr> are already built as children by the time
            // this case runs, so filtering here is sufficient — no AST or
            // render-node changes required.
            let preferred: FRUSASTNode? =
                children.first { if case .corr = $0 { return true }; return false }
                ?? children.first {
                    if case .unknown(let n, _, _) = $0 { return n == "reg" }; return false
                }
                ?? children.first(where: { if case .sic = $0 { return false }; return true })
            guard let preferred else { return nil }
            if case .corr(let c) = preferred {
                return c.count == 1 ? c[0] : .unknown(name: "choice", attributes: [:], children: c)
            }
            return preferred

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

// MARK: - Person List Heuristics

/// Classifies a List-of-Persons entry as a real person vs. an artifact of the surrounding list prose.
///
/// Centralised so the index-time parser (`PersonsParserDelegate`) and the rollup consolidation read
/// path (`IndexingPipeline.consolidatePersonRollup`) apply identical rules. The cross-corpus People
/// browser surfaced parenthetical fragments — e.g. `(together with political, military and technical
/// advisers).` — that a parser-only filter could not retroactively remove from already-indexed
/// `persons` rows; consolidation now reuses this same predicate to purge them without a full reindex.
enum PersonListHeuristics {
    /// Whether `name` looks like a biographical record rather than list-prose noise.
    ///
    /// Rejects, conservatively (it must never discard a real person):
    /// - empty or letterless strings;
    /// - back-of-book `See …` / `See also …` cross-reference redirects;
    /// - entries whose first meaningful character is an opening bracket (`(`, `[`, `{`) — a
    ///   parenthetical fragment lifted out of the prose.
    ///
    /// A name that merely *contains* a parenthetical mid-string ("McKeown (MacEoin), Major General
    /// Sean") starts with a letter and is kept; transliterated names that legitimately open with an
    /// apostrophe or ʿayn are not bracket-led and are likewise kept.
    static func isLikelyPersonName(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard n.contains(where: { $0.isLetter }) else { return false }
        if let first = n.first, first == "(" || first == "[" || first == "{" { return false }
        let lower = n.lowercased()
        return !(lower.hasPrefix("see ") || lower.hasPrefix("see also "))
    }
}

// MARK: - Persons Parser Delegate

/// Minimal SAX delegate that extracts `PersonEntry` records from a FRUS volume.
///
/// Handles the common structures found across the corpus:
///
/// **`<listPerson>` structure** (modern FRUS, teiHeader or body):
/// ```xml
/// <listPerson>
///   <person xml:id="AlexanderHaig">
///     <persName>Haig, Alexander M.</persName>
///     <note>National Security Advisor</note>
///   </person>
/// </listPerson>
/// ```
///
/// **`<div>` list structure** (older FRUS, front or back matter):
/// ```xml
/// <div type="persons">
///   <list>
///     <item xml:id="AlexanderHaig">Haig, Alexander M.: National Security Advisor</item>
///   </list>
/// </div>
/// ```
///
/// The `<div>` type can be `"persons"`, `"persname"`, or `"listofpersons"` depending
/// on the volume era. All are treated identically.
private final class PersonsParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    var entries: [PersonEntry] = []

    private var inPersonsSection = false
    private var inPersonElement = false
    private var currentId: String?
    private var currentName: String?
    private var textBuffer = ""
    private var elementDepth = 0
    private var personsSectionDepth = -1

    /// Returns `true` when the given element starts a persons section.
    ///
    /// FRUS TEI marks the persons section with `xml:id="persons"` on a
    /// `<div type="section">` element — NOT with `type="persons"`. Both
    /// patterns are accepted for forward compatibility.
    private static func isPersonsSection(elementName: String, attributes: [String: String]) -> Bool {
        if elementName == "listPerson" { return true }
        if elementName == "div" {
            // Primary pattern (all modern FRUS volumes): xml:id identifies the section.
            let xmlId = attributes["xml:id"]?.lowercased() ?? ""
            if xmlId == "persons" || xmlId == "persname" || xmlId == "listofpersons" { return true }
            // Secondary pattern (some older or non-standard volumes): type attribute.
            let type = attributes["type"]?.lowercased() ?? ""
            return type == "persons" || type == "persname" || type == "listofpersons"
        }
        return false
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        if Self.isPersonsSection(elementName: elementName, attributes: attributeDict) {
            inPersonsSection = true
            personsSectionDepth = elementDepth
        }
        guard inPersonsSection else { return }

        if elementName == "person" || (elementName == "item" && personsSectionDepth >= 0) {
            inPersonElement = true
            // In FRUS TEI the item's xml:id is on the nested <persName>, not the <item>
            // itself. We initialise currentId to nil here and capture it in the
            // persName handler below; the <item>-level xml:id is also accepted as a
            // fallback for <listPerson> structures.
            currentId = attributeDict["xml:id"] ?? attributeDict["id"]
            currentName = nil
            textBuffer = ""
        }

        // FRUS TEI places the person xml:id on <persName> inside <item>:
        // <item><persName xml:id="p_AH1">Alphand, Herve</persName>,</hi> ...</item>
        if inPersonElement && elementName == "persName" {
            if let id = attributeDict["xml:id"] ?? attributeDict["id"] {
                currentId = id          // takes priority over any item-level id
            }
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
            // Collapse interior whitespace (e.g. "Kissinger,\n  Henry A." → "Kissinger, Henry A.")
            // in addition to trimming edges. XML formatting wraps name content across lines in
            // some FRUS volumes; trimmingCharacters alone leaves embedded newlines/spaces in the
            // stored person name.
            currentName = textBuffer
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            textBuffer = ""
        }
        if elementName == "person" || (elementName == "item" && personsSectionDepth >= 0) {
            let raw = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = currentId ?? raw
            if !id.isEmpty {
                // Two persons-list shapes appear across FRUS eras:
                //   Format A (modern, persName-wrapped): the name came from <persName>; `raw` is the
                //     trailing role text after </persName> (e.g. ", Assistant to the President…")
                //     that earlier versions discarded.
                //   Format B (older, colon-delimited): a single text run "Name: role".
                let name: String
                let descRaw: String?
                if let cn = currentName {
                    name = cn
                    descRaw = Self.cleanTrailingText(raw)
                } else {
                    let parts = raw.components(separatedBy: ":")
                    name = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
                    descRaw = parts.count > 1
                        ? Self.cleanTrailingText(parts[1...].joined(separator: ":"))
                        : nil
                }
                if !name.isEmpty, PersonListHeuristics.isLikelyPersonName(name) {
                    let (role, startYear, endYear) = Self.extractRoleAndYears(from: descRaw)
                    entries.append(PersonEntry(
                        ref: id, name: name, description: descRaw,
                        role: role, startYear: startYear, endYear: endYear
                    ))
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

    // MARK: - Role / year extraction (person rollup Phase 1)

    /// Cleans a descriptive fragment: trims whitespace, strips leading/trailing separators and
    /// brackets left over from "</persName>, role" or year removal, and a trailing period. Returns
    /// `nil` when nothing with a letter remains (e.g. "()" left after extracting "(1923–1990)").
    static func cleanTrailingText(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let seps = CharacterSet(charactersIn: ",:;–—-()[]. ")
        while let f = t.unicodeScalars.first, seps.contains(f) { t.removeFirst() }
        while let l = t.unicodeScalars.last, seps.contains(l) { t.removeLast() }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.contains(where: { $0.isLetter }) else { return nil }
        return t
    }

    /// Splits descriptive text into a role title and an active-year range. Years come from `YYYY` or
    /// `YYYY[–-]YY(YY)` / `YYYY–present` patterns bounded to plausible FRUS years (1700–2099); the
    /// role is the text with that span removed. A "present"/open range leaves `endYear` nil.
    static func extractRoleAndYears(from text: String?) -> (role: String?, startYear: Int?, endYear: Int?) {
        guard let text, !text.isEmpty else { return (nil, nil, nil) }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func boundedYear(_ s: String) -> Int? {
            guard let y = Int(s), y >= 1700, y <= 2099 else { return nil }
            return y
        }

        // Year range first: "1973–1977", "1973-77", "1969–present".
        if let re = try? NSRegularExpression(pattern: #"(\d{4})\s*[–—-]\s*(\d{2,4}|present|pres\.?)"#,
                                             options: [.caseInsensitive]),
           let m = re.firstMatch(in: text, range: full),
           let start = boundedYear(ns.substring(with: m.range(at: 1))) {
            let endStr = ns.substring(with: m.range(at: 2))
            var end: Int?
            if endStr.count == 4 {
                end = boundedYear(endStr)
            } else if endStr.count == 2, let two = Int(endStr) {
                // "1973–77" → 1977: graft the century/decade of the start year.
                end = boundedYear(String(format: "%02d%02d", start / 100, two))
            }
            let role = Self.cleanTrailingText(ns.replacingCharacters(in: m.range, with: ""))
            return (role, start, end)
        }
        // Single year: "Ambassador to France, 1975".
        if let re = try? NSRegularExpression(pattern: #"\b(\d{4})\b"#),
           let m = re.firstMatch(in: text, range: full),
           let y = boundedYear(ns.substring(with: m.range(at: 1))) {
            let role = Self.cleanTrailingText(ns.replacingCharacters(in: m.range, with: ""))
            return (role, y, nil)
        }
        return (Self.cleanTrailingText(text), nil, nil)
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
        // FRUS TEI marks the terms/abbreviations section with xml:id="terms" on a
        // <div type="section"> — NOT with type="terms". Both patterns accepted.
        if elementName == "div" {
            // Primary pattern (all modern FRUS volumes): xml:id identifies the section.
            let xmlId = attributeDict["xml:id"]?.lowercased() ?? ""
            if xmlId == "terms" || xmlId == "abbreviations" || xmlId == "listofabbreviations" {
                inTermsSection = true
                termsSectionDepth = elementDepth
            } else {
                // Secondary pattern: type attribute (older/non-standard volumes).
                let type = attributeDict["type"]?.lowercased() ?? ""
                if type == "terms" || type == "abbreviations" || type == "listofabbreviations" {
                    inTermsSection = true
                    termsSectionDepth = elementDepth
                }
            }
        } else if elementName == "listBibl" && !inTermsSection {
            inTermsSection = true
            termsSectionDepth = elementDepth
        }
        guard inTermsSection else { return }
        if elementName == "item" {
            inItem = true
            // In FRUS TEI the term xml:id is on the nested <term> element, not <item>.
            // Initialise to nil here; it is captured below in the <term> handler.
            currentId = attributeDict["xml:id"] ?? attributeDict["id"]
            currentTerm = nil
            textBuffer = ""
        }
        // FRUS TEI: <item><term xml:id="t_A1">A</term>, airgram</item>
        // Capture the xml:id from <term> inside an item — this is the canonical id.
        if inItem && elementName == "term" {
            if let id = attributeDict["xml:id"] ?? attributeDict["id"] {
                currentId = id
            }
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
                let term: String
                let def: String?
                if let captured = currentTerm {
                    // Canonical FRUS shape: <item><term xml:id="t_POL1">POL</term>,
                    // petroleum, oil, lubricants</item> — after </term> resets the
                    // buffer, everything left in `raw` IS the definition, prefixed
                    // by separator punctuation. The previous code split `raw` on
                    // ":" (a separator FRUS never uses here), so every definition
                    // in the corpus was discarded (Session 162 link audit: all 214
                    // terms of frus1964-68v19 carried NULL definitions).
                    term = captured
                    let separators = CharacterSet(charactersIn: ",;:—–-")
                        .union(.whitespacesAndNewlines)
                    let trimmedDef = raw.trimmingCharacters(in: separators)
                    def = trimmedDef.isEmpty ? nil : trimmedDef
                } else {
                    // Fallback shape without a nested <term>: "TERM: definition".
                    let parts = raw.components(separatedBy: ":")
                    term = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
                    let joined = parts.count > 1
                        ? parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        : ""
                    def = joined.isEmpty ? nil : joined
                }
                if !term.isEmpty {
                    entries.append(GlossEntry(ref: id, term: term, definition: def))
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
    let sourcesDelegate: SourcesParserDelegate = SourcesParserDelegate()
    let structureDelegate: VolumeStructureParserDelegate = VolumeStructureParserDelegate()

    // MARK: - XMLParserDelegate Forwarding

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        teiDelegate    .parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        personsDelegate.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        termsDelegate  .parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        sourcesDelegate.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        structureDelegate.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        teiDelegate    .parser(parser, foundCharacters: string)
        personsDelegate.parser(parser, foundCharacters: string)
        termsDelegate  .parser(parser, foundCharacters: string)
        sourcesDelegate.parser(parser, foundCharacters: string)
        structureDelegate.parser(parser, foundCharacters: string)
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
        sourcesDelegate.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
        structureDelegate.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        teiDelegate.parser(parser, parseErrorOccurred: parseError)
    }
}

// MARK: - Sources Parser Delegate

/// Minimal SAX delegate that extracts source-list entries from a FRUS volume's
/// front-matter `<div type="sources">`, `<div type="listofworks">`, or similar section.
///
/// FRUS front-matter source lists have a hierarchical structure:
/// ```xml
/// <div type="sources">
///   <list>
///     <item>National Archives and Records Administration, College Park, Maryland</item>
///     <item>  Record Group 59, General Records of the Department of State</item>
///     <item>    Central Files</item>
///     <item>    Lot Files</item>
///     <item>      Lot 64 D 199, Records of the Policy Planning Staff</item>
///   </list>
/// </div>
/// ```
///
/// Each `<item>` becomes a `VolumeSourceEntry`. Repository context is carried forward
/// from the current indentation level.
private final class SourcesParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Flat, document-order (pre-order) rows: the narrative `.prose` paragraphs first, then
    /// the archival-collection `.item` outline (parents before their children).
    var entries: [VolumeSourceEntry] = []

    private var inSourcesSection = false
    private var elementDepth = 0
    private var sectionDepth = -1

    /// Monotonic open-order counter. Assigned when a paragraph or item *opens*, so the
    /// final list can be sorted into document (pre-order) order — necessary because
    /// `<item>` elements close inner-first, which would otherwise emit children before
    /// their parents.
    private var openCounter = 0
    private var collected: [(order: Int, entry: VolumeSourceEntry)] = []

    /// A top-level narrative `<p>` being accumulated (outside any collection `<item>`).
    private var inProse = false
    private var proseBuffer = ""
    private var proseOrder = 0

    /// Stack of in-progress collection `<item>`s. Each frame captures the item's *own* text
    /// (characters directly inside it, before/outside its child `<list>`), whether it wrapped
    /// a `<hi rend="strong">` heading, its list-nesting `depth`, and its open order.
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

    // Deliberately excludes "listofabbreviations": that glossary is a `terms` section owned
    // by `TermsParserDelegate`; matching it here double-consumed it as bogus source items.
    private static let sourceSectionTypes: Set<String> = [
        "sources", "listofworks", "sources-and-abbreviations"
    ]

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        if !inSourcesSection {
            // Real corpus encoding: `<div type="section" subtype="sources"
            // xml:id="sources">`. The bare type values and `<listBibl>` cover
            // legacy fixtures and non-standard volumes.
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
            // A narrative paragraph, but only at the top level — `<p>` never appears inside
            // a collection `<item>` in this encoding, and treating it as one is exactly the
            // bug that turned the "Note on Sources" prose into bogus source rows.
            if itemStack.isEmpty {
                openCounter += 1
                proseOrder = openCounter
                inProse = true
                proseBuffer = ""
            }
        case "hi":
            // Bold `<hi rend="strong">` marks a major named collection (Department of State,
            // Record Group 59, Nixon Presidential Materials, …) — the headings a flat parse
            // used to lose. Flag the innermost open item.
            if attributeDict["rend"]?.lowercased() == "strong", !itemStack.isEmpty {
                itemStack[itemStack.count - 1].isHeading = true
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inSourcesSection else { return }
        // Characters belong to the innermost open item, else the current prose paragraph.
        if !itemStack.isEmpty {
            itemStack[itemStack.count - 1].text += string
        } else if inProse {
            proseBuffer += string
        }
    }

    func parser(_ parser: XMLParser,
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
                                      Self.makeItemEntry(text: text, depth: frame.depth,
                                                         isHeading: frame.isHeading)))
                }
            }
        case "p":
            if inProse && itemStack.isEmpty {
                let text = Self.collapseWhitespace(proseBuffer)
                if !text.isEmpty {
                    collected.append((proseOrder, VolumeSourceEntry(kind: .prose, rawText: text)))
                }
                inProse = false
                proseBuffer = ""
            }
        default:
            break
        }

        if elementDepth <= sectionDepth {
            // Section closed — append this section's rows in document (pre-order) order.
            // Append (don't assign): a volume can legitimately have more than one matching
            // section (e.g. a bibliography plus a combined sources-and-abbreviations list),
            // and each should accumulate rather than the last overwriting the rest.
            entries.append(contentsOf: collected.sorted { $0.order < $1.order }.map(\.entry))
            collected.removeAll()
            inSourcesSection = false
            sectionDepth = -1
            inProse = false
            proseBuffer = ""
            itemStack.removeAll()
            listDepth = 0
        }
    }

    /// Collapses interior whitespace runs (hard line breaks, ragged TEI indentation) to
    /// single spaces so a citation flows as one line instead of wrapping at its source column.
    private static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Builds an `.item` entry, extracting record group / lot file / repository / series from
    /// the node's own text (heuristics unchanged from the previous flat parser).
    private static func makeItemEntry(text: String, depth: Int, isHeading: Bool) -> VolumeSourceEntry {
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
        for keyword in repoKeywords {
            if text.range(of: keyword, options: .caseInsensitive) != nil {
                repo = keyword
                break
            }
        }

        let seriesName: String?
        if rg != nil || lot != nil {
            var s = text
            if let r = rg { s = s.replacingOccurrences(of: "RG \(r)", with: "", options: .caseInsensitive) }
            s = s.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? s
            seriesName = s.count > 3 ? s : nil
        } else {
            seriesName = nil
        }

        return VolumeSourceEntry(
            kind: .item, depth: depth, isHeading: isHeading,
            repository: repo, recordGroup: rg, lotFile: lot,
            seriesName: seriesName, rawText: text
        )
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
