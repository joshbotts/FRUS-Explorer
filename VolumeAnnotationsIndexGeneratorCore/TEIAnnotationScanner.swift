// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FRUSCoreKit
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
///   1.1 — 2026-11-06: ``annotatedIds``, the ids the document div's own `@ana` names
///   1.2 — 2026-11-08: ``editorialOmissions``, read from the document's own text (Lane 1 of
///          `Planning/Editors-Annotations-Followups-2026-11-08.md`)
struct TEIDocumentFeatures: Equatable, Sendable {
    /// `div[@subtype="editorial-note"]`.
    var isEditorialNote = false
    /// A `note[@type="source"][@rend="inline"]`: the file-number form, printed above the heading.
    var inlineSourceNote = false
    /// Every pointer of a `gloss`'s `@target` or `@ref`, without a leading `#`.
    var glossTargets: Set<String> = []
    /// The ids the document div's own `@ana` names in its volume (`FRUSDocumentAST.annotatedId`):
    /// the people and terms `frus1981-88v16` names on each document, where other volumes link them
    /// in the text. The reader lists them below the document (#1599). A pointer into another file
    /// names nothing here.
    var annotatedIds: Set<String> = []
    /// An element typed `from` or `to`: the heading marks a sender or recipient.
    var correspondents = false
    /// A `list[@type="subject"]`.
    var subjects = false
    /// A `list[@type="participants"]`.
    var participants = false
    /// The text "not declassified", the words separated by any whitespace, anywhere in the document.
    var excisions = false
    /// A bracket in the document's own text, every `note` left out, that says what the editors left
    /// out (`EditorialOmissionMarkers`): "[Here follows …]", "[Omitted here is …]".
    var editorialOmissions = false
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

/// One volume's documents inside `<body>`, in source order, with what each carries, and the year
/// its header says it was published.
struct TEIVolumeScan: Sendable {
    /// The `xml:id` of every `div[@type="document"]` inside `<body>`, in source order.
    var documentIds: [String] = []
    /// Each document's features, by id.
    var features: [String: TEIDocumentFeatures] = [:]
    /// The year of the header's first `date[@type="publication-date"]`, from its text or its
    /// `@when`, or `nil` where the header prints none.
    var publicationYear: Int?
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
/// the features in ``TEIDocumentFeatures``, and the header's publication year. An element is
/// credited to its innermost document.
///
/// Two texts are kept for each open document: every character, which the redaction test reads
/// (a withheld document's mark sits in its source note), and the document's own text, every
/// `note` left out, which the omission test reads. In the second a `<lb/>` or `<pb/>` is a space,
/// so that a bracket broken across a printed line is one span.
final class TEIAnnotationScanner: NSObject, XMLParserDelegate {

    /// One open element: what closing it ends.
    private struct Frame {
        var isDocument = false
        var isSourceNote = false
        var isNote = false
        var isBody = false
        var isHeader = false
        var isPublicationDate = false
    }

    private var scan = TEIVolumeScan()
    private var frames: [Frame] = []
    private var documentStack: [String] = []
    private var textStack: [String] = []
    private var ownTextStack: [String] = []
    private var bodyDepth = 0
    private var sourceNoteDepth = 0
    private var noteDepth = 0
    private var headerDepth = 0
    private var publicationDate: (text: String, when: String?)?

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
        if elementName == "teiHeader" {
            frame.isHeader = true
            headerDepth += 1
        }
        if elementName == "date", headerDepth > 0, type == "publication-date", scan.publicationYear == nil {
            frame.isPublicationDate = true
            publicationDate = (text: "", when: attributeDict["when"])
        }
        if elementName == "div", type == "document", bodyDepth > 0 {
            let id = attributeDict["xml:id"] ?? ""
            frame.isDocument = true
            documentStack.append(id)
            textStack.append("")
            ownTextStack.append("")
            if !id.isEmpty, scan.features[id] == nil {
                scan.documentIds.append(id)
                // `@ana`'s pointers as the parser splits them, each to the id it names.
                let annotated = (attributeDict["ana"] ?? "").split(whereSeparator: \.isWhitespace)
                    .compactMap { FRUSDocumentAST.annotatedId(String($0)) }
                scan.features[id] = TEIDocumentFeatures(
                    isEditorialNote: attributeDict["subtype"] == "editorial-note",
                    annotatedIds: Set(annotated))
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
        case "lb", "pb":
            if noteDepth == 0, !ownTextStack.isEmpty { ownTextStack[ownTextStack.count - 1] += " " }
        case "note":
            frame.isNote = true
            noteDepth += 1
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

    /// Closes an element, ending the document, note, `<body>`, header or publication date it opened.
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        guard let frame = frames.popLast() else { return }
        if frame.isSourceNote { sourceNoteDepth -= 1 }
        if frame.isNote { noteDepth -= 1 }
        if frame.isBody { bodyDepth -= 1 }
        if frame.isHeader { headerDepth -= 1 }
        if frame.isPublicationDate, let date = publicationDate {
            scan.publicationYear = EditorialOmissionMarkers.year(in: date.text)
                ?? date.when.flatMap(EditorialOmissionMarkers.year(in:))
            publicationDate = nil
        }
        if frame.isDocument, let id = documentStack.popLast(), let text = textStack.popLast() {
            let own = ownTextStack.popLast() ?? ""
            guard !id.isEmpty else { return }
            if text.range(of: #"not\s+declassified"#, options: [.regularExpression, .caseInsensitive]) != nil {
                scan.features[id]?.excisions = true
            }
            if EditorialOmissionMarkers.marksAnOmission(in: own) {
                scan.features[id]?.editorialOmissions = true
            }
        }
    }

    /// Adds text to the open document's two texts, and to the publication date while it is open.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        append(string)
    }

    /// Adds CDATA as text.
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { return }
        append(string)
    }

    private func append(_ string: String) {
        if publicationDate != nil { publicationDate?.text += string }
        guard !textStack.isEmpty else { return }
        textStack[textStack.count - 1] += string
        if noteDepth == 0 { ownTextStack[ownTextStack.count - 1] += string }
    }
}
