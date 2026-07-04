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
/// - text accumulates with a **space at every element boundary**, the app's
///   `FRUSASTNode.plainText` child-join rule (`<gloss>MSP</gloss>/3–1952` stores
///   `"MSP /3–1952"`), collapsed by the shared whitespace normalization;
/// - **editorial notes yield nothing**: the app wraps `<div type="editorialNote">`
///   and `subtype="editorial-note"` documents in a single `.editorialNote` AST node,
///   so their notes are never top-level and `extractSourceNote` stores none.
///
/// All returned text passes through the same `[Source: …]` wrapper normalization the
/// pipeline applies, so `SourceNoteParser` receives the stored shape.
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
        /// All character data inside the note.
        var wholeText = ""
        /// Text of each direct `<p>` child (full descendant text), in order.
        var paragraphs: [String] = []
        /// Text inside the first non-empty descendant `<seg type="source">`.
        var segSourceText = ""
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
    private var noteParagraphBuffer = ""

    /// Depth of the open `<seg type="source">` in the current note, or -1.
    private var segSourceDepth = -1

    private static let documentDivTypes: Set<String> = ["document", "editorialnote"]

    /// Opens document scopes, the head, notes, note paragraphs, and source segments.
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        // The app's `plainText` joins every AST child with a single space, so an
        // element boundary inside a note always contributes one — mirror it before
        // any capture state changes (the whitespace normalization collapses runs).
        appendBoundarySpace()
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
                noteParagraphBuffer = ""
            }
        case "seg":
            if let idx = openNoteIndex, segSourceDepth < 0,
               attributeDict["type"]?.lowercased() == "source",
               captures[idx].segSourceText.isEmpty {
                segSourceDepth = elementDepth
            }
        default:
            break
        }
    }

    /// Accumulates note text into the whole-note, paragraph, and seg buffers.
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let idx = openNoteIndex else { return }
        captures[idx].wholeText += string
        if noteParagraphDepth >= 0 { noteParagraphBuffer += string }
        if segSourceDepth >= 0 { captures[idx].segSourceText += string }
    }

    /// Appends the app's `plainText` child-join separator (one space) to every open
    /// buffer of the current note. Called on each element start **and** end while a
    /// note is open, so `<gloss>MSP</gloss>/3–1952` accumulates as `"MSP /3–1952"` —
    /// exactly the `c.map(\.plainText).joined(separator: " ")` shape the pipeline
    /// stores (leading/trailing runs are trimmed by `normalizedWhitespace`).
    private func appendBoundarySpace() {
        guard let idx = openNoteIndex else { return }
        captures[idx].wholeText += " "
        if noteParagraphDepth >= 0 { noteParagraphBuffer += " " }
        if segSourceDepth >= 0 { captures[idx].segSourceText += " " }
    }

    /// Closes segments, paragraphs, notes, the head, and the document scope (applying
    /// the locator chain when the document div ends).
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        // Closing edge of the child-join boundary — see `appendBoundarySpace()`.
        appendBoundarySpace()
        if segSourceDepth == elementDepth, elementName == "seg" {
            segSourceDepth = -1
        }
        if noteParagraphDepth == elementDepth, elementName == "p", let idx = openNoteIndex {
            captures[idx].paragraphs.append(noteParagraphBuffer)
            noteParagraphDepth = -1
            noteParagraphBuffer = ""
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
