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
}
