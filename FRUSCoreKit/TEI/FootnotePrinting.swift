// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FootnotePrinting

/// Which of a document's notes a page prints, and how each call to a note is drawn (L34; the
/// Collections design §3.5).
///
/// The reader prints every note (``all``). A collection's export prints the notes its plan gives it
/// (`CollectionDocumentPlan`): none where Footnotes is off, and every note but a source note's
/// second copy where the *Source:* line prints it (#1991).
///
/// **A call stays where its note does not print, as text** (#2007): the volume's number is in the
/// volume's text, and tells a reader that a note exists. Until L34 the web page drew each call as a
/// button whose popover it had not written, so a click did nothing and a screen reader announced a
/// control. **A mark of the app's own goes with its note**: a note the volume printed unnumbered has
/// no number to keep, and the glyph the app draws for it, the archival mark on a source note or a
/// bullet, prints only where the note does.
///
/// Version history:
///   1.0 — L34 (#1991, #2007): initial implementation
public struct FootnotePrinting: Sendable, Equatable {

    /// The DOM keys (``FRUSRenderNode/footnoteDOMKey(id:sequentialNumber:)``) of the notes printed, or
    /// `nil` for every note.
    public let printedKeys: Set<String>?

    /// Creates a printing of the notes `printedKeys` names, or of every note when it is `nil`.
    public init(printedKeys: Set<String>?) {
        self.printedKeys = printedKeys
    }

    /// Every note prints: the reader's page.
    public static let all = FootnotePrinting(printedKeys: nil)

    /// No note prints, and each call the volume numbered stays as its number.
    public static let none = FootnotePrinting(printedKeys: [])

    /// Whether the note keyed `key` prints.
    public func prints(_ key: String) -> Bool {
        printedKeys?.contains(key) ?? true
    }

    /// How a call is drawn.
    public enum Call: Sendable, Equatable {
        /// A call to a note that prints: the reader's button, Word's note reference, the PDF's mark.
        case note
        /// The number the volume printed, as text: its note does not print.
        case text
        /// Nothing: a note the volume printed unnumbered, which does not print.
        case omitted
    }

    /// How the call to the note keyed `key`, printed with `label`, is drawn.
    ///
    /// - Parameters:
    ///   - key: The note's DOM key.
    ///   - label: The number the volume printed, or `nil` for a note it printed unnumbered.
    /// - Returns: The call's drawing.
    public func call(key: String, label: String?) -> Call {
        if prints(key) { return .note }
        return label == nil ? .omitted : .text
    }
}

// MARK: - What a render model's notes are

extension FRUSDocumentRenderModel {

    /// Each note's DOM key, in the order the notes print.
    public var footnoteKeys: [String] {
        footnotes.compactMap { note in
            guard case .footnoteBody(let id, _, _, let seq, _, _) = note else { return nil }
            return FRUSRenderNode.footnoteDOMKey(id: id, sequentialNumber: seq)
        }
    }

    /// The DOM keys of the document's source notes (`type="source"`).
    public var sourceNoteKeys: Set<String> {
        Set(footnotes.compactMap { note in
            guard case .footnoteBody(let id, .source, _, let seq, _, _) = note else { return nil }
            return FRUSRenderNode.footnoteDOMKey(id: id, sequentialNumber: seq)
        })
    }

    /// The DOM keys of the notes the document's heading calls: its first heading, read through an
    /// editorial note's wrapper. From the volumes for 1955 on, the source note is one of them, a
    /// footnote on the heading; before, it leads the document unnumbered, above the heading.
    public var headingCallKeys: Set<String> {
        func firstHeading(_ nodes: [FRUSRenderNode]) -> [FRUSRenderNode]? {
            for node in nodes {
                if case .heading(let children) = node { return children }
                if case .editorialNoteBlock(let children) = node, let found = firstHeading(children) { return found }
            }
            return nil
        }
        return Self.callKeys(in: firstHeading(bodyNodes) ?? [])
    }

    /// The DOM keys of the notes the notes keyed `keys` call, at any depth: the notes printed inside them
    /// (#1496), which go where they go.
    ///
    /// - Parameter keys: The DOM keys of the outer notes.
    /// - Returns: The keys their bodies call, outside `keys`, followed through each body called.
    public func keysCited(inNotes keys: Set<String>) -> Set<String> {
        var bodies: [String: [FRUSRenderNode]] = [:]
        for note in footnotes {
            if case .footnoteBody(let id, _, _, let seq, _, let children) = note {
                bodies[FRUSRenderNode.footnoteDOMKey(id: id, sequentialNumber: seq)] = children
            }
        }
        var found: Set<String> = []
        var queue = Array(keys)
        while let key = queue.popLast() {
            for cited in Self.callKeys(in: bodies[key] ?? []) where !keys.contains(cited) && found.insert(cited).inserted {
                queue.append(cited)
            }
        }
        return found
    }

    /// The DOM keys of the calls among `nodes`, at any depth.
    static func callKeys(in nodes: [FRUSRenderNode]) -> Set<String> {
        var keys: Set<String> = []
        func walk(_ node: FRUSRenderNode) {
            switch node {
            case .footnoteMarker(let id, _, let seq, _):
                keys.insert(FRUSRenderNode.footnoteDOMKey(id: id, sequentialNumber: seq))
            case .heading(let c), .dateline(let c), .letterOpener(let c), .letterCloser(let c),
                 .salutation(let c), .paragraph(let c), .boldText(let c), .italicText(let c),
                 .smallCapsText(let c), .underlineText(let c), .termText(let c), .suppliedText(let c),
                 .sicText(let c), .corrText(let c), .editorialNoteBlock(let c), .titlePageBlock(let c),
                 .attachmentHeading(let c), .attachmentBlock(_, let c), .unknown(_, let c),
                 .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, _, _, let c):
                c.forEach(walk)
            case .footnoteBody(_, _, _, _, _, let c):
                c.forEach(walk)
            case .tableBlock(let caption, let rows):
                caption?.forEach(walk)
                rows.forEach { $0.forEach { $0.children.forEach(walk) } }
            case .listBlock(_, let heading, let items, let trailing):
                heading?.forEach(walk)
                for item in items {
                    for lead in item.lead {
                        switch lead { case .label(let c), .other(let c): c.forEach(walk) }
                    }
                    item.children.forEach(walk)
                }
                for lead in trailing {
                    switch lead { case .label(let c), .other(let c): c.forEach(walk) }
                }
            case .figureBlock(let figure):
                figure.head?.forEach(walk)
                figure.captions.forEach { $0.forEach(walk) }
            case .plainText, .formulaText, .lineBreak, .elementSpace, .pageBreak:
                break
            }
        }
        nodes.forEach(walk)
        return keys
    }
}
