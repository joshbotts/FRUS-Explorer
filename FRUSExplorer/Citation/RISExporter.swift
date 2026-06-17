// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - RISExporter

/// Formats FRUS citation metadata as an RIS record.
///
/// Uses `TY  - CHAP` (book chapter) which maps cleanly to an edited-volume
/// primary-source document in Zotero, Mendeley, and EndNoteX.
///
/// ## Example output
/// ```
/// TY  - CHAP
/// TI  - Memorandum of Conversation
/// T2  - Foreign Relations of the United States, 1969-1976, Volume I
/// A3  - Smith, Louis J.
/// A3  - Herschler, David H.
/// PB  - Government Printing Office
/// CY  - Washington, D.C.
/// PY  - 1972
/// UR  - https://history.state.gov/historicaldocuments/frus1969-76v01/d1
/// N1  - Document 1
/// ER  -
/// ```
///
/// Version history:
///   1.0 — Session 86
public struct RISExporter: Sendable {

    public init() {}

    /// Returns an RIS string for the given FRUS document.
    ///
    /// - Parameters:
    ///   - document: Metadata for the specific document being cited.
    ///   - volume: Metadata for the containing volume.
    ///   - year: Effective publication year string (e.g. `"1972"` or `"n.d."`).
    ///   - url: Canonical URL, or `nil` if unavailable.
    public func export(
        document: FRUSDocumentMetadata,
        volume: FRUSVolumeMetadata,
        year: String,
        url: String?
    ) -> String {
        var lines: [String] = ["TY  - CHAP"]

        let title = document.header.isEmpty ? document.documentId : document.header
        lines.append("TI  - \(title)")
        lines.append("T2  - \(volume.title)")

        for editor in volume.editors {
            lines.append("A3  - \(editor)")
        }

        lines.append("PB  - \(volume.publisher)")
        lines.append("CY  - \(volume.publicationPlace)")
        lines.append("PY  - \(year)")

        if let url {
            lines.append("UR  - \(url)")
        }

        let note = document.documentNumber.map { "Document \($0)" } ?? document.documentId
        lines.append("N1  - \(note)")
        lines.append("ER  - ")

        return lines.joined(separator: "\n")
    }

    /// Renders an RIS record from a pre-built Zotero `Item`.
    ///
    /// Used by the collection Zotero export, whose pipeline produces `Item`s rather than
    /// raw `FRUSDocumentMetadata`. RIS imports into standard Zotero (no Better BibTeX
    /// plugin required, and works on iOS), unlike the Zotero-API JSON envelope.
    public func export(zoteroItem item: ZoteroJSONExporter.Item) -> String {
        var lines: [String] = ["TY  - \(Self.risType(for: item.itemType))"]
        lines.append("TI  - \(item.title)")
        if let bookTitle = item.bookTitle { lines.append("T2  - \(bookTitle)") }
        for creator in item.creators ?? [] {
            lines.append("\(Self.risCreatorTag(for: creator.creatorType))  - \(creator.name)")
        }
        if let publisher = item.publisher { lines.append("PB  - \(publisher)") }
        if let place = item.place { lines.append("CY  - \(place)") }
        if let date = item.date { lines.append("PY  - \(date)") }
        if let url = item.url { lines.append("UR  - \(url)") }
        for tag in item.tags ?? [] { lines.append("KW  - \(tag.tag)") }
        if let extra = item.extra, !extra.isEmpty { lines.append("N1  - \(extra)") }
        for note in item.notes ?? [] { lines.append("N1  - \(note.note)") }
        lines.append("ER  - ")
        return lines.joined(separator: "\n")
    }

    private static func risType(for itemType: String) -> String {
        switch itemType {
        case "bookSection": return "CHAP"
        case "book":        return "BOOK"
        default:            return "GEN"
        }
    }

    private static func risCreatorTag(for creatorType: String) -> String {
        switch creatorType {
        case "author": return "AU"
        case "editor": return "A3"
        default:       return "A2"
        }
    }
}
