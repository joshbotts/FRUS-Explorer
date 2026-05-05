// MARK: - Convenience Extensions

import Foundation

// MARK: FRUSVolume

public extension FRUSVolume {
    /// The main series title from the `<titleStmt>`.
    var seriesTitle: String? {
        header.fileDescription.titleStatement.titles
            .first(where: { $0.level == "s" })?.text
    }

    /// The main volume title (monograph-level).
    var volumeTitle: String? {
        header.fileDescription.titleStatement.titles
            .first(where: { $0.level == "m" || $0.level == nil })?.text
    }

    /// All flat list of `<div type="document">` elements anywhere in the body.
    var documents: [Division] {
        text.body.divisions.flatMap(\.allDocuments)
    }

    /// All flat list of `<div type="chapter">` elements.
    var chapters: [Division] {
        text.body.divisions.flatMap(\.allChapters)
    }

    /// All flat list of `<div type="compilation">` elements.
    var compilations: [Division] {
        text.body.divisions.filter { $0.type == .compilation }
    }

    /// Front matter divisions, keyed by type.
    var frontMatterSection: [DivisionType: Division] {
        var dict: [DivisionType: Division] = [:]
        for div in text.front?.divisions ?? [] {
            if let t = div.type { dict[t] = div }
        }
        return dict
    }
}

// MARK: Division

public extension Division {
    /// Recursively collect all descendant `<div type="document">` nodes.
    var allDocuments: [Division] {
        var result: [Division] = []
        if type == .document { result.append(self) }
        for child in children { result += child.allDocuments }
        return result
    }

    /// Recursively collect all descendant `<div type="chapter">` nodes.
    var allChapters: [Division] {
        var result: [Division] = []
        if type == .chapter { result.append(self) }
        for child in children { result += child.allChapters }
        return result
    }

    /// The plain-text content of the first heading.
    var title: String? { headings.first.map { plainText(from: $0.content) } }

    /// The document number as an `Int` (if `@n` is numeric).
    var documentNumber: Int? { number.flatMap(Int.init) }

    /// The date of this division, taken from the dateline if available.
    var date: DateElement? { dateline?.dates.first }

    /// All footnotes in this division (not searching children).
    var footnotes: [Note] {
        notes.filter { $0.type == "footnote" || $0.place == "bottom" }
    }

    /// Flat array of all inline text in all paragraphs, including nested child divisions.
    var bodyText: String {
        var parts = paragraphs.map { plainText(from: $0.content) }
        for child in children {
            parts.append(contentsOf: child.bodyText
                .components(separatedBy: "\n\n")
                .filter { !$0.isEmpty })
        }
        return parts.joined(separator: "\n\n")
    }
}

// MARK: Heading

public extension Heading {
    var plainTextValue: String { plainText(from: content) }
}

// MARK: InlineContent

public extension InlineContent {
    /// Plain-text representation, collapsing all markup.
    var plainTextValue: String { plainText(from: [self]) }
}

// MARK: - Private Helpers (file-scope)

func plainText(from content: [InlineContent]) -> String {
    content.map { item -> String in
        switch item {
        case .text(let s):
            // Normalize XML whitespace: collapse runs to single spaces
            var r = s
            for c in ["\n","\r","\t"] { r = r.replacingOccurrences(of: c, with: " ") }
            while r.contains("  ") { r = r.replacingOccurrences(of: "  ", with: " ") }
            return r
        case .persName(let p):        return p.text
        case .placeName(let p):       return p.text
        case .orgName(let o):         return o.text
        case .date(let d):            return d.text
        case .ref(let r):             return r.text
        case .hi(let h):              return plainText(from: h.content)
        case .term(let t):            return t.text
        case .note:                   return ""
        case .pageBreak, .lineBreak:  return ""
        case .list(let l):
            return l.items.map { plainText(from: $0.content) }.joined(separator: "; ")
        case .table:                  return ""
        case .unknown:                return ""
        }
    }.joined()
}
