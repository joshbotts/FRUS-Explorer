// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Extracts every document's **body** footnotes from a volume's TEI XML, in reading order — the
/// input the #784 footnote-citation harvest runs over.
///
/// ## Body footnotes, and why the exclusions are the whole design
/// A FRUS document div carries three kinds of `<note>`, and only one of them names archival
/// material the volume did *not* print:
///
/// | note | what it says | here? |
/// |---|---|---|
/// | `<note type="source">` | where the printed document came from | **no** — `document_sources` |
/// | a note nested in the document's `<head>` | also the printed document's provenance | **no** |
/// | anything else inside the div | the editor's annotation | **yes** |
///
/// The head-nested exclusion is not a formality. In the pre-1950 volumes the encoding puts the
/// decimal file number in `<note type="source">` and a *second* provenance statement in a
/// head-nested footnote — `frus1937v01/d29` fn 1 is, in full, `Photostatic copy obtained from the
/// Franklin D. Roosevelt Library, Hyde Park, N. Y.` Harvesting that would report the editors
/// pointing outside the printed record when they were describing the printed record itself.
/// Measured over the shippable corpus: **258 head-nested notes carry a lot or library anchor**.
///
/// A note containing a `<seg type="source">` is skipped for the same reason: that is pattern 4 of
/// `IndexingPipeline.extractSourceNote`'s locator chain — an untyped note whose *segment* is the
/// document's source note.
///
/// ## Two deliberate differences from ``DocumentNoteExtractor``
/// 1. **Editorial notes are included.** `DocumentNoteExtractor` yields nothing for a document the
///    app wraps in a single `.editorialNote` AST node, because `extractSourceNote` only scans
///    top-level nodes and therefore stores no source note for one. A footnote walk recurses, so
///    the app sees those notes and so must this. Editorial notes are also the documents most
///    likely to cite unprinted material — they are the code #783 removed from `document_sources`.
/// 2. **Depth is unbounded.** A source note is a direct child of the div or of its head; a
///    footnote sits wherever its reference mark falls, inside `<p>`, `<list>`, `<quote>`.
///
/// ## Parity with the app
/// Structural, and pinned by `RealTEIFootnoteParityTests`, which compares this extractor's
/// citations against the `external_citations` rows `IndexingPipeline` actually writes over real
/// volumes. Text accumulates with a space at every element boundary — the app's
/// `FRUSASTNode.plainText` child-join rule — collapsed by the same whitespace normalization.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
public final class DocumentFootnoteExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// One document's body footnotes, in reading order.
    public struct DocumentFootnotes: Sendable, Equatable {
        /// The document's `xml:id` (empty when the div carries none).
        public let documentId: String
        /// Body footnote texts, in the order their reference marks appear.
        public let footnotes: [String]
        /// Notes the exclusions above removed, each with the reason. Returned rather than dropped
        /// so the generator can *measure* what each guard cost instead of asserting it: a silent
        /// exclusion reads as "there was nothing there" when it may have been the difference
        /// between a right answer and a wrong one.
        ///
        /// The reason has to travel with the note, not just the count. The first corpus run
        /// reported "299,643 excluded, 44,356 of those carried an anchor" and the second number
        /// looked alarming until it was split: 268,752 of the exclusions are `type="source"`
        /// notes, which *should* carry archival anchors — that is what a source note is. The
        /// figure worth watching is the head-nested one.
        public let excluded: [ExcludedNote]

        /// Creates a record.
        public init(documentId: String, footnotes: [String], excluded: [ExcludedNote] = []) {
            self.documentId = documentId
            self.footnotes = footnotes
            self.excluded = excluded
        }
    }

    /// A note the extractor refused, and why.
    public struct ExcludedNote: Sendable, Equatable {
        /// Why the note is not a body footnote.
        public enum Reason: String, Sendable, Equatable {
            /// `<note type="source">` — the document's own provenance.
            case sourceNote
            /// A direct child of the document's `<head>` — also the document's own provenance.
            case headNested
            /// Carries a `<seg type="source">` — pattern 4 of the source-note locator chain.
            case sourceSegment
        }

        /// Why it was refused.
        public let reason: Reason
        /// The note's normalized text.
        public let text: String

        /// Creates an excluded note.
        public init(reason: Reason, text: String) {
            self.reason = reason
            self.text = text
        }
    }

    /// Extracts every document's body footnotes from a volume's TEI XML.
    public static func extract(fromXML data: Data) -> [DocumentFootnotes] {
        let delegate = DocumentFootnoteExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.documents
    }

    /// The extracted documents, in document order.
    public private(set) var documents: [DocumentFootnotes] = []

    // MARK: State

    private var elementDepth = 0

    /// Depth of the open document div, or -1.
    private var documentDepth = -1
    private var documentId = ""
    private var footnotes: [String] = []
    private var excluded: [ExcludedNote] = []

    /// Depth of the document's direct-child `<head>`, or -1.
    private var headDepth = -1

    /// Text of the open note, or `nil` when no note is open.
    private var openNoteText: String?
    private var openNoteDepth = -1
    /// Why the open note is excluded, or `nil` when it is a body footnote.
    private var openNoteExclusion: ExcludedNote.Reason?

    private static let documentDivTypes: Set<String> = ["document", "editorialnote"]

    /// Opens document scopes, the head, and notes.
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        elementDepth += 1
        appendBoundarySpace()
        switch elementName {
        case "div":
            if documentDepth < 0,
               let type = attributeDict["type"]?.lowercased(),
               Self.documentDivTypes.contains(type) {
                documentDepth = elementDepth
                documentId = attributeDict["xml:id"] ?? ""
                footnotes = []
                excluded = []
                headDepth = -1
            }
        case "head":
            if documentDepth >= 0, elementDepth == documentDepth + 1 {
                headDepth = elementDepth
            }
        case "note":
            // Only the outermost note of a nest is captured, matching the app's AST walk, which
            // takes a `.footnote` node's whole `plainText` including any note inside it.
            guard documentDepth >= 0, openNoteText == nil else { break }
            openNoteText = ""
            openNoteDepth = elementDepth
            let headNested = headDepth >= 0 && elementDepth == headDepth + 1
            openNoteExclusion = attributeDict["type"]?.lowercased() == "source" ? .sourceNote
                : (headNested ? .headNested : nil)
        case "seg":
            // Pattern 4 of the source-note locator chain: an untyped note whose source segment is
            // the document's provenance. Not an editorial annotation.
            if openNoteText != nil, attributeDict["type"]?.lowercased() == "source",
               openNoteExclusion == nil {
                openNoteExclusion = .sourceSegment
            }
        default:
            break
        }
    }

    /// Accumulates note text.
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard openNoteText != nil else { return }
        openNoteText? += string
    }

    /// The app's `plainText` child-join separator (one space) at every element boundary.
    private func appendBoundarySpace() {
        guard openNoteText != nil else { return }
        openNoteText? += " "
    }

    /// Closes notes, the head, and the document scope.
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer { elementDepth -= 1 }
        appendBoundarySpace()
        if openNoteDepth == elementDepth, elementName == "note" {
            let text = Self.normalizedWhitespace(openNoteText ?? "")
            if !text.isEmpty {
                if let reason = openNoteExclusion {
                    excluded.append(ExcludedNote(reason: reason, text: text))
                } else {
                    footnotes.append(text)
                }
            }
            openNoteText = nil
            openNoteDepth = -1
            openNoteExclusion = nil
        }
        if headDepth == elementDepth, elementName == "head" {
            headDepth = -1
        }
        if documentDepth == elementDepth, elementName == "div" {
            documents.append(DocumentFootnotes(documentId: documentId, footnotes: footnotes,
                                               excluded: excluded))
            documentDepth = -1
            documentId = ""
            footnotes = []
            excluded = []
        }
    }

    /// Collapses all whitespace runs to single spaces and trims the ends.
    static func normalizedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
