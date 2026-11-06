// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - TEIDocumentFeatures

/// What a document's raw TEI carries of the layers the kit's parser does not keep.
///
/// The parser drops `@type` from `persName`, `gloss` and `list`, so senders and recipients,
/// Subject lines and participant lists can only be read from the XML; the rest are read here too,
/// by the design's TEI definitions (`Planning/editors-annotations/README.md`).
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
struct TEIDocumentFeatures: Equatable, Sendable {
    /// `div[@subtype="editorial-note"]`.
    var isEditorialNote = false
    /// A `note[@type="source"][@rend="inline"]`: the file-number form, printed above the heading.
    var inlineSourceNote = false
    /// Every pointer of a `gloss`'s `@target` or `@ref`, without a leading `#`.
    var glossTargets: Set<String> = []
    /// An element typed `from` or `to`: the heading marks a sender or recipient.
    var correspondents = false
    /// A `list[@type="subject"]`.
    var subjects = false
    /// A `list[@type="participants"]`.
    var participants = false
    /// The text "not declassified", the words separated by any whitespace, anywhere in the document.
    var excisions = false
    /// A `seg[@type="margin"]`.
    var marginalNotes = false
    /// A `figure`.
    var figures = false
    /// A `note` that is neither the source note nor inside it.
    var footnotes = false
    /// A `ref` to a document of the volume.
    var xrefDocuments = false
    /// A `ref` to a footnote.
    var xrefFootnotes = false
    /// A `ref` to another volume.
    var xrefVolumes = false
    /// A `ref` to a printed page.
    var xrefPages = false
}

// MARK: - TEIVolumeScan

/// One volume's documents inside `<body>`, in source order, with what each carries.
struct TEIVolumeScan: Sendable {
    /// The `xml:id` of every `div[@type="document"]` inside `<body>`, in source order.
    var documentIds: [String] = []
    /// Each document's features, by id.
    var features: [String: TEIDocumentFeatures] = [:]
}

// MARK: - ReferenceKind

/// What a `ref`'s `@target` points at, by the design's TEI rule (`inventory.py`'s `xref_kind`).
enum ReferenceKind: Equatable, Sendable {
    /// A web address.
    case url
    /// A printed page: `#pg_…`, in this volume or another.
    case page
    /// A footnote: `#d12fn3`, or any `#…fn3`.
    case footnote
    /// A document of the volume: `#d12`.
    case document
    /// Another target inside the volume.
    case internalOther
    /// Another volume: `frus1964-68v01…`.
    case otherVolume
    /// Anything else.
    case other

    /// Classifies one `@target`.
    init(target: String) {
        let t = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http") || t.hasPrefix("mailto") {
            self = .url
        } else if t.contains("#pg_") {
            self = .page
        } else if t.contains(#/#d\d+fn\d+/#) || t.contains(#/#.*fn\d+$/#) {
            self = .footnote
        } else if t.hasPrefix("#") {
            self = t.prefixMatch(of: #/#d\d/#) != nil ? .document : .internalOther
        } else if t.hasPrefix("frus") {
            self = .otherVolume
        } else {
            self = .other
        }
    }
}

// MARK: - TEIAnnotationScanner

/// Reads one volume's TEI in a single SAX pass and records, for each document inside `<body>`,
/// the features in ``TEIDocumentFeatures``. An element is credited to its innermost document.
final class TEIAnnotationScanner: NSObject, XMLParserDelegate {

    /// One open element: what closing it ends.
    private struct Frame {
        var isDocument = false
        var isSourceNote = false
        var isBody = false
    }

    private var scan = TEIVolumeScan()
    private var frames: [Frame] = []
    private var documentStack: [String] = []
    private var textStack: [String] = []
    private var bodyDepth = 0
    private var sourceNoteDepth = 0

    /// Scans a volume's file.
    static func scan(file: URL) throws -> TEIVolumeScan {
        try scan(data: try Data(contentsOf: file))
    }

    /// Scans a volume's XML.
    static func scan(data: Data) throws -> TEIVolumeScan {
        let scanner = TEIAnnotationScanner()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = scanner
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return scanner.scan
    }

    /// Opens an element: a document, a source note, `<body>`, or a feature of the open document.
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        var frame = Frame()
        let type = attributeDict["type"] ?? ""
        if elementName == "body" {
            frame.isBody = true
            bodyDepth += 1
        }
        if elementName == "div", type == "document", bodyDepth > 0 {
            let id = attributeDict["xml:id"] ?? ""
            frame.isDocument = true
            documentStack.append(id)
            textStack.append("")
            if !id.isEmpty, scan.features[id] == nil {
                scan.documentIds.append(id)
                scan.features[id] = TEIDocumentFeatures(
                    isEditorialNote: attributeDict["subtype"] == "editorial-note")
            }
        } else if let id = documentStack.last, !id.isEmpty {
            record(elementName, type: type, attributes: attributeDict, in: id, frame: &frame)
        }
        frames.append(frame)
    }

    private func record(_ name: String, type: String, attributes: [String: String], in id: String,
                        frame: inout Frame) {
        var features = scan.features[id] ?? TEIDocumentFeatures()
        if type == "from" || type == "to" { features.correspondents = true }
        switch name {
        case "gloss":
            let pointers = (attributes["target"] ?? attributes["ref"] ?? "")
                .split(whereSeparator: \.isWhitespace)
            for pointer in pointers {
                features.glossTargets.insert(pointer.hasPrefix("#") ? String(pointer.dropFirst()) : String(pointer))
            }
        case "list":
            if type == "subject" { features.subjects = true }
            if type == "participants" { features.participants = true }
        case "seg":
            if type == "margin" { features.marginalNotes = true }
        case "figure":
            features.figures = true
        case "note":
            if type == "source" {
                frame.isSourceNote = true
                sourceNoteDepth += 1
                if attributes["rend"] == "inline" { features.inlineSourceNote = true }
            } else if sourceNoteDepth == 0 {
                features.footnotes = true
            }
        case "ref":
            if let target = attributes["target"], !target.isEmpty {
                switch ReferenceKind(target: target) {
                case .document: features.xrefDocuments = true
                case .footnote: features.xrefFootnotes = true
                case .page: features.xrefPages = true
                case .otherVolume: features.xrefVolumes = true
                case .url, .internalOther, .other: break
                }
            }
        default:
            break
        }
        scan.features[id] = features
    }

    /// Closes an element, ending the document, source note or `<body>` it opened.
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        guard let frame = frames.popLast() else { return }
        if frame.isSourceNote { sourceNoteDepth -= 1 }
        if frame.isBody { bodyDepth -= 1 }
        if frame.isDocument, let id = documentStack.popLast(), let text = textStack.popLast() {
            if !id.isEmpty,
               text.range(of: #"not\s+declassified"#, options: [.regularExpression, .caseInsensitive]) != nil {
                scan.features[id]?.excisions = true
            }
        }
    }

    /// Adds text to the open document's text, which the excision test reads when it closes.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !textStack.isEmpty else { return }
        textStack[textStack.count - 1] += string
    }

    /// Adds CDATA as text.
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard !textStack.isEmpty, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        textStack[textStack.count - 1] += string
    }
}
