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
///   1.1 — Collections rework Phase 4 (D7): added `export(zoteroItem:volumeId:documentId:)`,
///          a pre-built-`Item` overload used by `BibTeXCollectionExporter` for whole-collection
///          `.bib` files (mirrors `RISExporter.export(zoteroItem:)`). Tags → `keywords`,
///          research notes → `annote`, `extra` lines → `note`.
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

    /// Renders a BibTeX record from a pre-built Zotero `Item`, using `volumeId`/`documentId`
    /// for the citation key. Used by the collection BibTeX export, whose pipeline produces
    /// `Item`s rather than raw `FRUSDocumentMetadata` (the `Item` carries no IDs, so the key
    /// components are passed explicitly).
    ///
    /// Field mapping: `bookTitle` → `booktitle`; editor/author creators → `editor`/`author`;
    /// `place` → `address`; `date` → `year`; `extra` lines → `note`; tags → `keywords`;
    /// research notes → `annote`. Free-text fields (note/keywords/annote) have braces and
    /// backslashes neutralized so user text cannot break the record structure.
    ///
    /// - Parameters:
    ///   - item: The pre-built Zotero item.
    ///   - volumeId: The volume identifier, used in the citation key.
    ///   - documentId: The document identifier, used in the citation key.
    public func export(
        zoteroItem item: ZoteroJSONExporter.Item,
        volumeId: String,
        documentId: String
    ) -> String {
        let key = bibtexKey(volumeId: volumeId, documentId: documentId)
        var lines: [String] = ["@\(Self.bibtexType(for: item.itemType)){\(key),"]
        lines.append("  title     = {\(bibtexEscape(item.title))},")
        if let bookTitle = item.bookTitle, !bookTitle.isEmpty {
            lines.append("  booktitle = {\(bibtexEscape(bookTitle))},")
        }
        let authors = (item.creators ?? []).filter { $0.creatorType == "author" }.map(\.name)
        let editors = (item.creators ?? []).filter { $0.creatorType == "editor" }.map(\.name)
        if !authors.isEmpty { lines.append("  author    = {\(editorString(authors))},") }
        if !editors.isEmpty { lines.append("  editor    = {\(editorString(editors))},") }
        if let publisher = item.publisher, !publisher.isEmpty {
            lines.append("  publisher = {\(bibtexEscape(publisher))},")
        }
        if let place = item.place, !place.isEmpty {
            lines.append("  address   = {\(bibtexEscape(place))},")
        }
        if let date = item.date, !date.isEmpty {
            lines.append("  year      = {\(bibtexEscape(date))},")
        }
        if let extra = item.extra, !extra.isEmpty {
            let note = extra.split(separator: "\n", omittingEmptySubsequences: true)
                .map { bibtexFreeText(String($0)) }
                .joined(separator: "; ")
            if !note.isEmpty { lines.append("  note      = {\(note)},") }
        }
        let tags = (item.tags ?? []).map(\.tag)
        if !tags.isEmpty {
            lines.append("  keywords  = {\(tags.map(bibtexFreeText).joined(separator: ", "))},")
        }
        let notes = (item.notes ?? []).map(\.note)
        if !notes.isEmpty {
            lines.append("  annote    = {\(notes.map(bibtexFreeText).joined(separator: "\n\n"))},")
        }
        if let url = item.url, !url.isEmpty {
            lines.append("  url       = {\(url)}")
        } else if var last = lines.last, last.hasSuffix(",") {
            // Remove the trailing comma from the last field when no url follows.
            last.removeLast()
            lines[lines.count - 1] = last
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// The BibTeX entry type for a Zotero item type (`book` → `@book`, else `@incollection`).
    private static func bibtexType(for itemType: String) -> String {
        itemType == "book" ? "book" : "incollection"
    }

    /// Escapes a free-text field (user notes/tags) for BibTeX. Neutralizes braces and
    /// backslashes in the *raw* text first — so arbitrary user text cannot unbalance the
    /// `{…}` field or introduce a stray control sequence — and only then applies the standard
    /// `bibtexEscape`. Order matters: `bibtexEscape` turns `%` into `\%`, which must survive,
    /// so the backslash-neutralizing step has to run *before* the escape, not after.
    private func bibtexFreeText(_ text: String) -> String {
        let neutralized = text
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "{", with: "(")
            .replacingOccurrences(of: "}", with: ")")
        return bibtexEscape(neutralized)
    }

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
