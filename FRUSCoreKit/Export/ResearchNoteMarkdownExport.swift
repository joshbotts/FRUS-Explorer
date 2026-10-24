// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResearchNoteMarkdownExport

/// A single rendered Markdown file for a `ResearchNote`, with YAML front matter
/// linking back to the source document.
///
/// Produced by `ResearchDataExporter.markdownExports(notes:tags:appState:)` for
/// the per-note, Obsidian-style export, which renders each file with ``render(noteId:documentId:volumeId:bodyText:userTagIds:createdAt:lastModified:citation:tagNamesById:)``.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — FRUS Explorer Light: moved into FRUSCoreKit from `Export/ResearchDataExporter.swift`,
///          `public`, with the rendering of one note's file, which took the app's `ResearchNote`,
///          taking the note's values instead, unchanged
public struct ResearchNoteMarkdownExport: Identifiable, Sendable {

    /// The source `ResearchNote.id`.
    public let id: UUID

    /// Suggested filename, unique per note.
    public let filename: String

    /// Full file contents: YAML front matter followed by the note body.
    public let content: String

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, filename: String, content: String) {
        self.id = id
        self.filename = filename
        self.content = content
    }

    /// Builds a single Markdown export for a note.
    ///
    /// The front matter names the document, its canonical `history.state.gov` URL, the citation
    /// when there is one, the note's tags by name, and its dates; the body follows it.
    ///
    /// - Parameters:
    ///   - noteId: The note's id, which names the file with its document.
    ///   - documentId: The note's document.
    ///   - volumeId: The document's volume.
    ///   - bodyText: The note's text, which is the file's body.
    ///   - userTagIds: The note's tags, in its order; an id `tagNamesById` does not name is left out.
    ///   - createdAt: When the note was created, if known.
    ///   - lastModified: When it last changed, if known.
    ///   - citation: The document's citation, or `nil` when its volume is not indexed, which leaves
    ///     `citation` out of the front matter.
    ///   - tagNamesById: Every tag's name, by id.
    /// - Returns: The note's file.
    public static func render(
        noteId: UUID,
        documentId: String,
        volumeId: String,
        bodyText: String,
        userTagIds: [UUID],
        createdAt: Date?,
        lastModified: Date?,
        citation: String?,
        tagNamesById: [UUID: String]
    ) -> ResearchNoteMarkdownExport {
        let canonicalURL = "https://history.state.gov/historicaldocuments/\(volumeId)/\(documentId)"
        let tagNames = userTagIds.compactMap { tagNamesById[$0] }

        var frontMatter: [String] = ["---"]
        frontMatter.append("documentId: \(documentId)")
        frontMatter.append("volumeId: \(volumeId)")
        frontMatter.append("url: \(canonicalURL)")
        if let citation {
            frontMatter.append("citation: \(yamlQuoted(citation))")
        }
        if !tagNames.isEmpty {
            frontMatter.append("tags: [\(tagNames.map(yamlQuoted).joined(separator: ", "))]")
        }
        if let createdAt {
            frontMatter.append("created: \(ISO8601DateFormatter().string(from: createdAt))")
        }
        if let lastModified {
            frontMatter.append("modified: \(ISO8601DateFormatter().string(from: lastModified))")
        }
        frontMatter.append("---")

        let content = frontMatter.joined(separator: "\n") + "\n\n" + bodyText + "\n"
        let shortId = noteId.uuidString.prefix(8)
        let filename = "\(volumeId)-\(documentId)-\(shortId).md"

        return ResearchNoteMarkdownExport(id: noteId, filename: filename, content: content)
    }

    /// Wraps `value` in a double-quoted YAML scalar, escaping backslashes and
    /// quotes — user-authored tag names and citation text can contain `:`/`"`/`]`,
    /// which break unquoted YAML.
    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
