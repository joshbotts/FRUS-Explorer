// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Extracts every per-document source note from a FRUS volume's TEI XML.
///
/// A FRUS document's source note is a TEI element carrying `type="source"` — primarily
/// `<note type="source">`, but also head-nested notes and `<p>`/`<seg type="source">`
/// (the app's `IndexingPipeline` locator chain is head/note/p/seg[@type="source"] then
/// head/note[@type="source"] then a top-level inline note). This delegate collects the
/// text content of *every* element whose `type` attribute equals `"source"`, which
/// captures the vast majority of the corpus's document source notes (a prior scan found
/// 268,750 across 522 volumes). Each note's text is whitespace-collapsed.
///
/// Nested source elements are handled by tracking the depth at which a source element
/// opened: characters accumulate into the outermost open source element, and a note is
/// emitted when that outermost element closes, so a `<note type="source">` wrapping an
/// inner typed element yields one note (its full text), not two overlapping ones.
///
/// Version history:
///   1.0 — SA-3a (Session 2026-07-04): initial implementation
public final class SourceNoteExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Extracts the whitespace-collapsed text of every `type="source"` element from a
    /// volume's TEI XML. Returns an empty array when the volume has no source notes.
    ///
    /// - Parameter data: The raw TEI XML bytes.
    /// - Returns: One string per source note, in document order.
    public static func extract(fromXML data: Data) -> [String] {
        let delegate = SourceNoteExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.notes
    }

    private var notes: [String] = []

    /// Current nesting depth of every open element.
    private var elementDepth = 0
    /// The depth at which the outermost currently-open source element started, or `nil`
    /// when not inside a source element.
    private var sourceDepth: Int?
    /// Accumulated characters for the currently-open source element.
    private var buffer = ""

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        // Only latch the outermost source element; inner typed elements just contribute
        // their characters to the already-open buffer.
        if sourceDepth == nil, attributeDict["type"]?.lowercased() == "source" {
            sourceDepth = elementDepth
            buffer = ""
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard sourceDepth != nil else { return }
        buffer += string
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        if let depth = sourceDepth, elementDepth == depth {
            let text = Self.collapseWhitespace(buffer)
            if !text.isEmpty { notes.append(text) }
            sourceDepth = nil
            buffer = ""
        }
    }

    /// Collapses all runs of whitespace to single spaces and trims the ends.
    static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
