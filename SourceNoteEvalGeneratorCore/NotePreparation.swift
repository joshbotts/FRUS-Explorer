// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Replicates the IndexingPipeline's post-extraction source-note normalization, so the
/// eval harness feeds `SourceNoteParser` the same text the app's pipeline stores.
///
/// After Source Explorer Phase 1, `IndexingPipeline.extractSourceNote(from:)` stores:
/// - **head-nested numbered notes** (the 1955+ `<head><note n="1" type="source">`
///   encoding; in `citations.csv` these rows' xpath addresses the note by its own
///   `xml:id`, e.g. `id('d184fn1')`): the *first `<p>` whose text begins
///   `Source:`/`[Source:`* when the note has paragraph children, otherwise the whole
///   note's whitespace-normalized plain text (`sourceNoteBody(fromNoteChildren:)`);
/// - **top-level inline notes** (the pre-1955 `<div><note rend="inline" type="source">`
///   encoding; csv xpath ends `…/note` or `…/note[N]`): the whole note's
///   whitespace-normalized plain text;
/// - both shapes then pass through `normalizeSourceNoteWrapper`, collapsing a
///   `[Source: …]` bracket wrapper to `Source: …`.
///
/// ## Known gaps vs the live pipeline (documented, all measured-small)
/// 1. **Deferred-head-note gate**: the pipeline defers a non-`Source:`-prefixed head
///    note and prefers a top-level note from the same document when one exists (29
///    corpus documents carry both encodings). The csv is one row per note, so the
///    harness evaluates both notes independently — a ≤29-row overcount.
/// 2. **`seg[@type='source']` selection** (pattern 1/4): zero source-note rows in
///    `citations.csv` contain a source `<seg>` (verified against the corpus), so the
///    branch is not replicated.
/// 3. **Attachment notes** (`…/attachment/note`, ~2,100 rows): `extractSourceNote`
///    scans only document-level nodes, so the live pipeline never stores these; the
///    harness keeps them because they exercise the same citation grammar. They are
///    whole-text rows like other inline notes.
/// 4. Malformed `tei_xml` falls back to the whitespace-normalized `plain_text` column
///    (flattened paragraphs — no `Source:`-paragraph selection).
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation
public enum NotePreparation {

    /// Produces the parser input for one csv source-note row.
    ///
    /// - Parameters:
    ///   - plainText: The csv `plain_text` column (flattened note text).
    ///   - teiXML: The csv `tei_xml` column (the `<note>` element).
    ///   - xpath: The csv `xpath` column, used to route between the head-nested
    ///     (`id('…')`) and top-level (`…/note`) normalization paths.
    /// - Returns: The text `SourceNoteParser.parse(_:)` would receive from the
    ///   pipeline for this note.
    public static func parserInput(plainText: String, teiXML: String, xpath: String) -> String {
        let body: String
        if isHeadNestedXPath(xpath), let selected = sourceNoteBody(fromNoteXML: teiXML) {
            body = selected
        } else {
            body = normalizedWhitespace(plainText)
        }
        return normalizeSourceNoteWrapper(body)
    }

    /// Whether the row's xpath addresses the note by its own `xml:id` — the shape the
    /// citations.csv harvest emits for head-nested numbered source notes (`id('d184fn1')`),
    /// as opposed to the `id('d5')/note` path shape of top-level inline notes.
    ///
    /// - Parameter xpath: The csv `xpath` column.
    public static func isHeadNestedXPath(_ xpath: String) -> Bool {
        guard let close = xpath.range(of: "')") else { return false }
        return xpath[close.upperBound...].isEmpty
    }

    /// Mirrors `IndexingPipeline.sourceNoteBody(fromNoteChildren:)` over the note's
    /// TEI XML: when the note holds `<p>` children, the first paragraph whose text
    /// begins `Source:` / `[Source:` wins; otherwise the whole note's plain text.
    /// Returns `nil` when the XML cannot be parsed or yields no text (callers fall
    /// back to the csv's `plain_text`).
    ///
    /// - Parameter xml: The `<note>` element markup from the csv `tei_xml` column.
    public static func sourceNoteBody(fromNoteXML xml: String) -> String? {
        let delegate = NoteXMLDelegate()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        for paragraph in delegate.paragraphTexts {
            let text = normalizedWhitespace(paragraph)
            if text.hasPrefix("Source:") || text.hasPrefix("[Source:") { return text }
        }
        let whole = normalizedWhitespace(delegate.wholeText)
        return whole.isEmpty ? nil : whole
    }

    /// Mirrors `IndexingPipeline.normalizeSourceNoteWrapper(_:)`: collapses the
    /// `[Source: …]` bracket wrapper to the unbracketed `Source: …` shape; all other
    /// text is returned unchanged.
    ///
    /// - Parameter text: A whitespace-normalized note body.
    public static func normalizeSourceNoteWrapper(_ text: String) -> String {
        guard text.hasPrefix("[Source:"), text.hasSuffix("]") else { return text }
        let inner = text.dropFirst("[".count).dropLast("]".count)
        return normalizedWhitespace(String(inner))
    }

    /// Mirrors the pipeline's `String.normalizedWhitespace` helper: collapses all
    /// whitespace runs (including newlines) to single spaces and trims the ends.
    ///
    /// - Parameter text: Raw text.
    public static func normalizedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// XMLParser delegate that captures the direct `<p>` children of the root `<note>`
/// element (each paragraph's full descendant text) plus the whole note's text.
private final class NoteXMLDelegate: NSObject, XMLParserDelegate {
    /// Text of each direct `<p>` child of the root element, in document order.
    private(set) var paragraphTexts: [String] = []
    /// All character data in the note, in document order.
    private(set) var wholeText = ""

    /// Element nesting depth; the root `<note>` is depth 1.
    private var depth = 0
    /// Depth of the currently open direct-child `<p>`, or `nil` outside one.
    private var openParagraphDepth: Int?
    /// Accumulator for the currently open paragraph.
    private var currentParagraph = ""

    /// Tracks depth and opens a paragraph accumulator for root-level `<p>` elements.
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        depth += 1
        if elementName == "p", depth == 2, openParagraphDepth == nil {
            openParagraphDepth = depth
            currentParagraph = ""
        }
    }

    /// Closes the paragraph accumulator when its element ends.
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if let open = openParagraphDepth, depth == open, elementName == "p" {
            paragraphTexts.append(currentParagraph)
            openParagraphDepth = nil
        }
        depth -= 1
    }

    /// Accumulates character data into the whole-note and paragraph buffers.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        wholeText += string
        if openParagraphDepth != nil { currentParagraph += string }
    }
}
