// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - BibtexExporter

/// Formats FRUS citation metadata as a BibTeX `@incollection` record.
///
/// `@incollection` is the correct BibTeX type for a primary-source document
/// inside an edited volume. The citation key is `{volumeId}_{documentId}`.
///
/// ## Example output
/// ```bibtex
/// @incollection{frus1969-76v01_d1,
///   title     = {Memorandum of Conversation},
///   booktitle = {Foreign Relations of the United States, 1969--1976, Volume I,
///                Foundations of Foreign Policy, 1969--1972},
///   editor    = {Louis J. Smith and David H. Herschler},
///   publisher = {Government Printing Office},
///   address   = {Washington, D.C.},
///   year      = {1972},
///   note      = {Document 1},
///   url       = {https://history.state.gov/historicaldocuments/frus1969-76v01/d1}
/// }
/// ```
///
/// Version history:
///   1.0 — Session 86
public struct BibtexExporter: Sendable {

    public init() {}

    /// Returns a BibTeX string for the given FRUS document.
    ///
    /// - Parameters:
    ///   - volumeId: The volume identifier (e.g. `frus1969-76v01`), used in the citation key.
    ///   - document: Metadata for the specific document being cited.
    ///   - volume: Metadata for the containing volume.
    ///   - year: Effective publication year string (e.g. `"1972"` or `"n.d."`).
    ///   - url: Canonical URL, or `nil` if unavailable.
    public func export(
        volumeId: String,
        document: FRUSDocumentMetadata,
        volume: FRUSVolumeMetadata,
        year: String,
        url: String?
    ) -> String {
        let key = bibtexKey(volumeId: volumeId, documentId: document.documentId)
        let title = bibtexEscape(document.header.isEmpty ? document.documentId : document.header)
        let booktitle = bibtexEscape(volume.title)
        let editorField = editorString(volume.editors)
        let note = document.documentNumber.map { "Document \($0)" } ?? document.documentId

        var lines: [String] = [
            "@incollection{\(key),",
            "  title     = {\(title)},",
            "  booktitle = {\(booktitle)},",
        ]
        if !editorField.isEmpty {
            lines.append("  editor    = {\(editorField)},")
        }
        lines += [
            "  publisher = {\(volume.publisher)},",
            "  address   = {\(volume.publicationPlace)},",
            "  year      = {\(year)},",
            "  note      = {\(note)},",
        ]
        if let url {
            lines.append("  url       = {\(url)}")
        } else {
            // Remove trailing comma from note line if no url follows
            if var last = lines.last, last.hasSuffix(",") {
                last.removeLast()
                lines[lines.count - 1] = last
            }
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func bibtexKey(volumeId: String, documentId: String) -> String {
        let safe = { (s: String) in
            s.components(separatedBy: .init(charactersIn: ":{}\\\"# ")).joined()
        }
        return "\(safe(volumeId))_\(safe(documentId))"
    }

    /// Escapes characters that have special meaning inside BibTeX braces.
    private func bibtexEscape(_ text: String) -> String {
        // Replace em-dash and en-dash with BibTeX double-hyphen convention,
        // and escape bare % which BibTeX treats as a comment character.
        text
            .replacingOccurrences(of: "\u{2013}", with: "--")
            .replacingOccurrences(of: "\u{2014}", with: "---")
            .replacingOccurrences(of: "%", with: "\\%")
    }

    private func editorString(_ editors: [String]) -> String {
        editors.joined(separator: " and ")
    }
}
