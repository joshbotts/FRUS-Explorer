// OutlineNode.swift
// Converts the parsed FRUSVolume into a tree of OutlineNodes for SwiftUI List disclosure groups.

import Foundation
import FRUSKit

// MARK: - Node

/// A node in the volume outline tree.
final class OutlineNode: Identifiable {
    let id: String

    /// Primary label line shown in bold/medium weight.
    let title: String
    /// Secondary label line: dateline for documents, number for editorial notes.
    let subtitle: String?
    /// Tertiary label line: first sentence of the source note (documents only).
    let sourceNote: String?

    let kind: NodeKind
    let division: Division?
    let children: [OutlineNode]

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        sourceNote: String? = nil,
        kind: NodeKind,
        division: Division? = nil,
        children: [OutlineNode] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sourceNote = sourceNote
        self.kind = kind
        self.division = division
        self.children = children
    }

    enum NodeKind {
        case volume
        case frontMatter
        case body
        case backMatter
        case compilation
        case chapter
        case section
        case document
        case editorialNote
        case other
    }

    var icon: String {
        switch kind {
        case .volume:        return "books.vertical.fill"
        case .frontMatter:   return "text.alignleft"
        case .body:          return "doc.text.fill"
        case .backMatter:    return "text.alignright"
        case .compilation:   return "folder.fill"
        case .chapter:       return "list.bullet.indent"
        case .section:       return "doc.plaintext"
        case .document:      return "doc.fill"
        case .editorialNote: return "quote.bubble.fill"
        case .other:         return "doc"
        }
    }

    var isLeaf: Bool { children.isEmpty }

    var isSelectable: Bool {
        switch kind {
        case .document, .editorialNote, .section: return true
        default: return !isLeaf
        }
    }
}

// MARK: - Builder

enum OutlineBuilder {
    static func build(from volume: FRUSVolume) -> [OutlineNode] {
        var nodes: [OutlineNode] = []

        if let front = volume.text.front, !front.divisions.isEmpty {
            nodes.append(OutlineNode(
                id: "\(volume.id)__front",
                title: "Front Matter",
                kind: .frontMatter,
                children: front.divisions.map { divNode($0, volumeID: volume.id, prefix: "front") }
            ))
        }

        nodes.append(OutlineNode(
            id: "\(volume.id)__body",
            title: "Body",
            kind: .body,
            children: volume.text.body.divisions.map {
                divNode($0, volumeID: volume.id, prefix: "body")
            }
        ))

        if let back = volume.text.back, !back.divisions.isEmpty {
            nodes.append(OutlineNode(
                id: "\(volume.id)__back",
                title: "Back Matter",
                kind: .backMatter,
                children: back.divisions.map { divNode($0, volumeID: volume.id, prefix: "back") }
            ))
        }

        return nodes
    }

    // MARK: - Private node builder

    private static func divNode(_ div: Division, volumeID: String, prefix: String) -> OutlineNode {
        let rawID = div.id ?? "\(prefix)_\(UUID().uuidString)"
        let nodeID = "\(volumeID)__\(rawID)"
        let kind = nodeKind(for: div)

        let title: String
        let subtitle: String?
        let sourceNote: String?

        switch kind {

        case .document:
            // Title: "N. <subject heading>" — subject heading preferred over type heading
            let subjectHeading = div.headings.first(where: { $0.type == "subject" })
                ?? (div.headings.count > 1 ? div.headings[1] : nil)
            let subjectText = subjectHeading.map { plainText(from: $0.content) }
                ?? div.headings.first.map { plainText(from: $0.content) }
                ?? "Document"
            title = div.number.map { "\($0). \(subjectText)" } ?? subjectText

            // Subtitle: formatted dateline (prefer ISO when/date text fallback)
            subtitle = dateline(from: div)

            // Source note: first sentence of the first footnote with place="bottom" or type="footnote"
            sourceNote = firstSentenceOfSourceNote(from: div)

        case .editorialNote:
            // Title: "Editorial Note" preceded by number if available
            let typeHead = div.headings.first.map { plainText(from: $0.content) }
                ?? "Editorial Note"
            title = div.number.map { "\($0). \(typeHead)" } ?? typeHead

            // Subtitle: second heading if present, otherwise nil
            subtitle = div.headings.count > 1
                ? plainText(from: div.headings[1].content)
                : nil

            sourceNote = nil

        default:
            title = div.title
                ?? div.type.map { "\($0.rawValue.capitalized)" }
                ?? "Section"
            subtitle = div.number.map { "No. \($0)" }
            sourceNote = nil
        }

        // Recurse into children
        var childNodes = div.children.map { divNode($0, volumeID: volumeID, prefix: rawID) }

        // Promote editorial notes attached directly to this div
        let editorialNotes = div.notes.filter { $0.type == "editorial" || $0.place == "inline" }
        for note in editorialNotes {
            let noteID = note.id ?? UUID().uuidString
            let noteNodeID = "\(volumeID)__note_\(noteID)"
            let noteHead = note.paragraphs.first
                .map { plainText(from: $0.content) }
                .map { firstSentence(of: $0) }
                ?? "Editorial Note"
            childNodes.append(OutlineNode(
                id: noteNodeID,
                title: noteHead,
                subtitle: note.n.map { "n. \($0)" },
                kind: .editorialNote,
                division: nil,
                children: []
            ))
        }

        return OutlineNode(
            id: nodeID,
            title: title,
            subtitle: subtitle,
            sourceNote: sourceNote,
            kind: kind,
            division: (kind == .document || kind == .editorialNote || kind == .section) ? div : nil,
            children: childNodes
        )
    }

    // MARK: - Label helpers

    /// Formatted dateline string for a document division.
    private static func dateline(from div: Division) -> String? {
        guard let dl = div.dateline else { return nil }
        // Prefer human-readable date text over raw ISO when
        let dateText = dl.dates.first?.text.trimmingCharacters(in: .whitespaces)
        let fullText = plainText(from: dl.content).trimmingCharacters(in: .whitespacesAndNewlines)
        // Return whichever is shorter and non-empty, preferring the full dateline text
        if !fullText.isEmpty { return fullText }
        return dateText
    }

    /// Extracts the first sentence from the first source/footnote note in the division.
    /// In FRUS, the first footnote on a document typically identifies the source archive.
    private static func firstSentenceOfSourceNote(from div: Division) -> String? {
        // Look for bottom-placed footnotes (source notes) first
        let candidate = div.notes.first(where: { $0.place == "bottom" || $0.type == "footnote" })
        guard let note = candidate else { return nil }

        let text: String
        if let firstPara = note.paragraphs.first {
            text = plainText(from: firstPara.content)
        } else if !note.content.isEmpty {
            text = plainText(from: note.content)
        } else {
            return nil
        }

        let sentence = firstSentence(of: text)
        return sentence.isEmpty ? nil : sentence
    }

    /// Extracts the first sentence from a plain-text string.
    private static func firstSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Split on sentence-ending punctuation followed by whitespace or end
        for terminator in [". ", "! ", "? "] {
            if let range = trimmed.range(of: terminator) {
                return String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        // No terminator found — return up to 120 chars
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "…"
        }
        return trimmed
    }

    private static func nodeKind(for div: Division) -> OutlineNode.NodeKind {
        switch div.type {
        case .compilation:   return .compilation
        case .chapter:       return .chapter
        case .document:      return .document
        case .preface, .sources, .persons, .terms, .appendix, .index: return .section
        case .section:       return .section
        case .other, nil:    return .other
        }
    }
}
