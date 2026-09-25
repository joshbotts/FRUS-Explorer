// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Extracts each document's provenance source note from a volume's TEI XML, porting the
/// app's `IndexingPipeline.extractSourceNote(from:)` locator chain (itself the
/// frus-sources `import.xq` recipe) so the generator parses **exactly the notes the app
/// stores** to `document_cache.source_note` at index time. Priority order per document:
///
/// 1. `<head>`-nested note containing `<seg type="source">` — the source segment only.
/// 2. `<head>`-nested `<note type="source">` — the first `<p>` beginning
///    `Source:` / `[Source:` when the note has paragraphs, else the whole note; a
///    whole-note candidate *without* the prefix is **deferred** behind patterns 3/4.
/// 3. Top-level `<note type="source">` — the pre-1955 inline encoding, whole text.
/// 4. Top-level untyped note containing `<seg type="source">`.
/// 5. The deferred pattern-2 text, when nothing else matched.
///
/// Parity with the app is **structural, and pinned by a test**
/// (`RealTEINoteParityTests` compares this extractor against the pipeline's stored
/// notes over real volumes):
/// - "`<head>`-nested" means a **direct child** of the document's direct-child
///   `<head>` — the app scans only direct `.footnote` children of the head AST node,
///   so a note wrapped deeper inside the head is invisible to both sides;
/// - "untyped" mirrors the app's `FootnoteType.unclassified`: a `type` attribute that
///   is **absent or unrecognized** (anything but `footnote` / `editorial` / `source`);
/// - text is joined **the way the page prints it** (#1421), the app's
///   `FRUSASTNode.plainText` rule, replayed over the parser's events by
///   ``PrintedTextMirror``: no space invented inside brackets and quotes or before a
///   stop, one kept at a block's edge and wherever the XML had one
///   (`<gloss>MSP</gloss>/3–1952` still stores `"MSP /3–1952"`, because a slash is in
///   neither set), collapsed by the shared whitespace normalization. Until #1421 it put
///   a space at every element boundary, which is what the app did then;
/// - **editorial notes yield nothing**: the app wraps `<div type="editorialNote">`
///   and `subtype="editorial-note"` documents in a single `.editorialNote` AST node,
///   so their notes are never top-level and `extractSourceNote` stores none.
///
/// All returned text passes through the same `[Source: …]` wrapper normalization the
/// pipeline applies, so `SourceNoteParser` receives the stored shape.
///
/// Version history:
///   1.0 — Source Explorer Phase 4 (2026-07-03), with the parity rules of the 2026-07-04 review
///   1.1 — #1421: note text joined as printed, through ``PrintedTextMirror``
public final class DocumentNoteExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// One extracted document source note.
    public struct DocumentNote: Sendable, Equatable {
        /// The document's `xml:id` (empty when the div carries none).
        public let documentId: String
        /// The normalized note text the pipeline would store.
        public let note: String
    }

    /// Extracts every document's source note from a volume's TEI XML.
    public static func extract(fromXML data: Data) -> [DocumentNote] {
        let delegate = DocumentNoteExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.notes
    }

    /// The extracted notes in document order.
    public private(set) var notes: [DocumentNote] = []

    // MARK: Per-note accumulation

    /// One `<note>` observed inside the current document div.
    struct NoteCapture {
        /// Whether the note is a **direct child** of the document's direct-child
        /// `<head>` (the only nesting the app's AST scan sees).
        let headNested: Bool
        /// The note's `type` attribute (lowercased), or `nil` when absent.
        let type: String?
        /// The note's whole text, joined as printed.
        var whole = PrintedTextMirror.Accumulator()
        /// Text of each direct `<p>` child (full descendant text), in order.
        var paragraphs: [String] = []
        /// Text inside the first non-empty descendant `<seg type="source">`.
        var segSourceText = ""

        /// The note's whole text, joined as printed.
        var wholeText: String { whole.text }
    }

    private var elementDepth = 0

    /// Depth of the open `<div type="document">` / `editorialNote`, or -1.
    private var documentDepth = -1
    private var documentId = ""

    /// Whether the open document is one the app wraps in a single `.editorialNote`
    /// AST node (`type="editorialNote"` or `subtype="editorial-note"`) — its notes
    /// are never top-level on the app side, so it yields no source note.
    private var documentIsEditorialWrapped = false

    /// Depth of the document's direct-child `<head>`, or -1.
    private var headDepth = -1

    /// Captures for the current document, in document order.
    private var captures: [NoteCapture] = []

    /// Index into `captures` of the currently open note, or `nil`.
    private var openNoteIndex: Int?
    private var openNoteDepth = -1

    /// Depth of the open direct-child `<p>` of the current note, or -1.
    private var noteParagraphDepth = -1
    private var noteParagraph = PrintedTextMirror.Accumulator()

    /// Depth of the open `<seg type="source">` in the current note, or -1.
    private var segSourceDepth = -1
    private var segSource = PrintedTextMirror.Accumulator()

    /// The parser's text leaves and the printed join's block edges, replayed (#1421).
    private var mirror = PrintedTextMirror()

    private static let documentDivTypes: Set<String> = ["document", "editorialnote"]

    /// Opens document scopes, the head, notes, note paragraphs, and source segments.
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        // The run before this element ends, and the element's own edge — both belong to the
        // buffers already open, never to one this element opens below.
        apply(mirror.start(elementName, attributes: attributeDict))
        switch elementName {
        case "div":
            if documentDepth < 0,
               let type = attributeDict["type"]?.lowercased(),
               Self.documentDivTypes.contains(type) {
                documentDepth = elementDepth
                documentId = attributeDict["xml:id"] ?? ""
                captures = []
                headDepth = -1
                documentIsEditorialWrapped = type == "editorialnote"
                    || attributeDict["subtype"]?.lowercased() == "editorial-note"
            }
        case "head":
            if documentDepth >= 0, elementDepth == documentDepth + 1 {
                headDepth = elementDepth
            }
        case "note":
            guard documentDepth >= 0, !documentIsEditorialWrapped,
                  openNoteIndex == nil else { break }
            // Direct child of the head only — the app's `extractSourceNote` scans
            // direct `.footnote` children of the head AST node, never deeper.
            let headNested = headDepth >= 0 && elementDepth == headDepth + 1
            let topLevel = elementDepth == documentDepth + 1
            guard headNested || topLevel else { break }
            captures.append(NoteCapture(headNested: headNested,
                                        type: attributeDict["type"]?.lowercased()))
            openNoteIndex = captures.count - 1
            openNoteDepth = elementDepth
        case "p":
            if openNoteIndex != nil, elementDepth == openNoteDepth + 1, noteParagraphDepth < 0 {
                noteParagraphDepth = elementDepth
                noteParagraph = PrintedTextMirror.Accumulator()
            }
        case "seg":
            if let idx = openNoteIndex, segSourceDepth < 0,
               attributeDict["type"]?.lowercased() == "source",
               captures[idx].segSourceText.isEmpty {
                segSourceDepth = elementDepth
                segSource = PrintedTextMirror.Accumulator()
            }
        default:
            break
        }
    }

    /// Buffers character data; the mirror decides what reaches the note's buffers.
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        mirror.characters(string)
    }

    /// Applies the mirror's events to every buffer of the current note that is open.
    private func apply(_ events: [PrintedTextMirror.Event]) {
        guard let idx = openNoteIndex, !events.isEmpty else { return }
        for event in events {
            captures[idx].whole.apply(event)
            if noteParagraphDepth >= 0 { noteParagraph.apply(event) }
            if segSourceDepth >= 0 { segSource.apply(event) }
        }
    }

    /// Closes segments, paragraphs, notes, the head, and the document scope (applying
    /// the locator chain when the document div ends).
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        // The element's last run — inside it, so it reaches the buffer this element closes.
        apply(mirror.end(elementName))
        if segSourceDepth == elementDepth, elementName == "seg", let idx = openNoteIndex {
            captures[idx].segSourceText = segSource.text
            segSourceDepth = -1
        }
        if noteParagraphDepth == elementDepth, elementName == "p", let idx = openNoteIndex {
            captures[idx].paragraphs.append(noteParagraph.text)
            noteParagraphDepth = -1
        }
        if openNoteDepth == elementDepth, elementName == "note" {
            openNoteIndex = nil
            openNoteDepth = -1
            noteParagraphDepth = -1
            segSourceDepth = -1
        }
        if headDepth == elementDepth, elementName == "head" {
            headDepth = -1
        }
        if documentDepth == elementDepth, elementName == "div" {
            if let note = Self.selectNote(from: captures) {
                notes.append(DocumentNote(documentId: documentId, note: note))
            }
            documentDepth = -1
            documentId = ""
            captures = []
        }
    }

    // MARK: Locator chain

    /// Mirrors the app's `FootnoteType` mapping (`FRUSDocumentParser`:
    /// `FootnoteType(rawValue:) ?? .unclassified`): a `type` attribute that is absent
    /// or unrecognized is *unclassified* — only `footnote` / `editorial` / `source`
    /// are recognized values.
    static func isUnclassified(_ type: String?) -> Bool {
        guard let type else { return true }
        return type != "footnote" && type != "editorial" && type != "source"
    }

    /// Applies the pipeline's priority chain over the document's captured notes.
    static func selectNote(from captures: [NoteCapture]) -> String? {
        var deferredHeadNote: String?
        // Patterns 1 + 2: head-nested notes.
        for capture in captures where capture.headNested {
            let isSource = capture.type == "source"
            let isUntyped = isUnclassified(capture.type)
            guard isSource || isUntyped else { continue }
            let seg = normalizedWhitespace(capture.segSourceText)
            if !seg.isEmpty { return normalizeSourceNoteWrapper(seg) }
            if isSource, let body = sourceNoteBody(from: capture) {
                if body.hasPrefix("Source:") || body.hasPrefix("[Source:") {
                    return normalizeSourceNoteWrapper(body)
                }
                if deferredHeadNote == nil { deferredHeadNote = body }
            }
        }
        // Patterns 3 + 4: top-level notes.
        for capture in captures where !capture.headNested {
            if capture.type == "source" {
                let t = normalizedWhitespace(capture.wholeText)
                if !t.isEmpty { return normalizeSourceNoteWrapper(t) }
            } else if isUnclassified(capture.type) {
                let seg = normalizedWhitespace(capture.segSourceText)
                if !seg.isEmpty { return normalizeSourceNoteWrapper(seg) }
            }
        }
        // Deferred pattern-2 fallback.
        if let deferred = deferredHeadNote {
            return normalizeSourceNoteWrapper(deferred)
        }
        return nil
    }

    /// Mirrors `IndexingPipeline.sourceNoteBody(fromNoteChildren:)`: the first paragraph
    /// beginning `Source:` / `[Source:` when the note has paragraphs, else the whole text.
    static func sourceNoteBody(from capture: NoteCapture) -> String? {
        for paragraph in capture.paragraphs {
            let t = normalizedWhitespace(paragraph)
            if t.hasPrefix("Source:") || t.hasPrefix("[Source:") { return t }
        }
        let whole = normalizedWhitespace(capture.wholeText)
        return whole.isEmpty ? nil : whole
    }

    /// Mirrors `IndexingPipeline.normalizeSourceNoteWrapper(_:)`.
    static func normalizeSourceNoteWrapper(_ text: String) -> String {
        guard text.hasPrefix("[Source:"), text.hasSuffix("]") else { return text }
        let inner = text.dropFirst("[".count).dropLast("]".count)
        return normalizedWhitespace(String(inner))
    }

    /// Collapses all whitespace runs to single spaces and trims the ends.
    static func normalizedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

// MARK: - PrintedTextMirror (#1421)

/// The app's printed join, replayed over SAX events so the generator's two XML note extractors
/// store what the pipeline stores (#1421).
///
/// The app builds a note's text from its AST: `FRUSDocumentParser` turns each run of character
/// data between two tags into one text leaf (dropping a run that is only whitespace, keeping one
/// space where a run began or ended with some, and trimming a `persName`'s first and last runs),
/// and `IndexingPipeline`'s `PrintedText` joins the leaves by the printed rule, keeping a space at
/// every block edge except a footnote's closing one. This type reproduces both halves from the
/// events an `XMLParser` delivers, emitting ``Event``s an extractor applies to each buffer it has
/// open — the whole note, a direct `<p>`, a source `<seg>` — through ``Accumulator``.
///
/// **The two sides are separate code over one rule**, as the rest of these extractors are: the
/// app target cannot link this package. `PrintedJoinMirrorParityTests` (app target) pins them on
/// the #1421 fixtures, and the mirror-gated `RealTEINoteParityTests` / `RealTEIFootnoteParityTests`
/// over real volumes.
///
/// Two parser behaviours are deliberately NOT replayed, because the old boundary-space mirror did
/// not replay them either and neither occurs in the parity volumes: `<choice>` keeping only its
/// preferred child, and `<formula>` dropping its child elements.
///
/// Version history:
///   1.0 — #1421: initial implementation
public struct PrintedTextMirror: Sendable {

    /// What the text of an open buffer receives.
    public enum Event: Sendable, Equatable {
        /// One text leaf, as the app's parser would store it.
        case text(String)
        /// A block edge the printed join keeps a space at.
        case blockEdge
    }

    /// One buffer's printed text — the app's `PrintedText.append(_:)` for strings.
    public struct Accumulator: Sendable {
        /// The text so far. Callers normalise whitespace.
        public private(set) var text = ""
        private var pendingBlockEdge = false

        /// An empty buffer.
        public init() {}

        /// Applies one event.
        public mutating func apply(_ event: Event) {
            switch event {
            case .blockEdge:
                if !text.isEmpty { pendingBlockEdge = true }
            case .text(let piece):
                guard let first = piece.first else { return }
                guard let last = text.last else {
                    text = piece
                    return
                }
                if last.isWhitespace || first.isWhitespace {
                    text += piece
                } else if pendingBlockEdge
                            || !(PrintedTextMirror.openers.contains(last)
                                 || PrintedTextMirror.closers.contains(first)) {
                    text += " " + piece
                } else {
                    text += piece
                }
                pendingBlockEdge = false
            }
        }
    }

    /// The app's `PrintedText.openers`: the next run follows these with no space.
    static let openers: Set<Character> = ["(", "[", "{", "\u{201C}", "\u{2018}"]

    /// The app's `PrintedText.closers`: the previous run ends before these with no space.
    static let closers: Set<Character> = [
        ")", "]", "}", ".", ",", ";", ":", "!", "?", "\u{201D}", "\u{2019}",
    ]

    /// One open element.
    private struct Frame: Sendable {
        /// A `persName`, whose first and last text runs the parser trims.
        let isPersName: Bool
        /// Whether the element's closing edge is a block edge: a block that is not a footnote.
        let closesAsBlock: Bool
        /// Whether a child — an element, or a text run that survived — has been seen yet.
        var hasChild = false
    }

    private var run = ""
    private var frames: [Frame] = []

    /// A mirror with no element open.
    public init() {}

    /// Character data, buffered until the next tag.
    public mutating func characters(_ string: String) {
        run += string
    }

    /// An element opens: the run before it ends, then the element's own edge.
    public mutating func start(_ name: String, attributes: [String: String]) -> [Event] {
        var events = flushRun(atEndOfElement: false)
        if !frames.isEmpty { frames[frames.count - 1].hasChild = true }
        let block = Self.isBlock(name, attributes: attributes)
        if block { events.append(.blockEdge) }
        frames.append(Frame(isPersName: name == "persName",
                            closesAsBlock: block && !Self.isFootnote(name, attributes: attributes)))
        return events
    }

    /// An element closes: its last run ends, then its edge (none for a footnote).
    public mutating func end(_ name: String) -> [Event] {
        var events = flushRun(atEndOfElement: true)
        let frame = frames.popLast()
        // `<lb/>` is a one-space leaf (`.lineBreak`), placed where the element stood.
        if name == "lb" { events.append(.text(" ")) }
        if frame?.closesAsBlock == true { events.append(.blockEdge) }
        return events
    }

    /// The buffered run as the parser would store it, or nothing.
    private mutating func flushRun(atEndOfElement: Bool) -> [Event] {
        defer { run = "" }
        var leaf = Self.normalizedLeaf(run)
        guard !leaf.isEmpty else { return [] }
        if let top = frames.last, top.isPersName {
            // `trimInlineTextBoundaries`: the first child when it is text, and the last.
            if !top.hasChild { leaf = String(leaf.drop { $0 == " " || $0 == "\t" }) }
            if atEndOfElement {
                while let c = leaf.last, c == " " || c == "\t" { leaf.removeLast() }
            }
            guard !leaf.isEmpty else { return [] }
        }
        if !frames.isEmpty { frames[frames.count - 1].hasChild = true }
        return [.text(leaf)]
    }

    /// `FRUSDocumentParser.normalizedText`: a whitespace-only run is dropped; otherwise interior
    /// runs collapse to one space and each end keeps one space when it had any.
    static func normalizedLeaf(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lead = raw.first?.isWhitespace == true ? " " : ""
        let trail = raw.last?.isWhitespace == true ? " " : ""
        return lead + trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ") + trail
    }

    /// Element names whose AST node the page sets apart — the app's `FRUSASTNode.isPrintedBlock`.
    static let blockElements: Set<String> = [
        "head", "dateline", "opener", "closer", "salute", "p", "ab", "table", "row", "cell",
        "list", "item", "titlePage", "figure", "frus:attachment",
    ]

    /// Whether the parser keeps `name` as a block node.
    static func isBlock(_ name: String, attributes: [String: String]) -> Bool {
        if blockElements.contains(name) { return true }
        if name == "div" { return attributes["type"] == "editorialNote" }
        return isFootnote(name, attributes: attributes)
    }

    /// Whether `name` is a note the parser keeps as a `.footnote` — every `<note>` but an inline
    /// one (`rend="inline"`), which the parser splices into its parent, unless it is a source note.
    static func isFootnote(_ name: String, attributes: [String: String]) -> Bool {
        guard name == "note" else { return false }
        return attributes["type"] == "source" || attributes["rend"] != "inline"
    }
}
