import Foundation
extension FRUSASTNode {
    /// All plain text content of this node and its descendants.
    var plainText: String {
        switch self {
        case .text(let s):   return s
        case .formula(let s): return s
        case .lineBreak:     return " "
        case .pageBreak, .document: return ""
        case .head(let c), .dateline(let c), .paragraph(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .term(let c), .editorialNote(let c), .titlePage(let c),
             .supplied(let c), .sic(let c), .corr(let c):
            return c.map(\.plainText).joined(separator: " ")
        case .attachment(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .date(_, _, _, _, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .emphasis(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .persName(_, let c): return c.map(\.plainText).joined(separator: " ")
        case .gloss(_, let c):    return c.map(\.plainText).joined(separator: " ")
        case .crossReference(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .figure(_, let c):   return c.map(\.plainText).joined(separator: " ")
        case .footnote(_, _, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .table(let rows):    return rows.map(\.plainText).joined(separator: " ")
        case .tableRow(let cells): return cells.map(\.plainText).joined(separator: " ")
        case .tableCell(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        case .list(_, let items): return items.map(\.plainText).joined(separator: " ")
        case .listItem(let c):    return c.map(\.plainText).joined(separator: " ")
        case .unknown(_, _, let c): return c.map(\.plainText).joined(separator: " ")
        }
    }

    /// Like `plainText`, but with every `.footnote` subtree excluded — at any depth,
    /// not just among direct children. Used by `IndexingPipeline.extractHeader` so
    /// footnotes nested inside `<hi>`/`<persName>`/`<p>` markup within `<head>` cannot
    /// leak into the stored document title.
    var plainTextExcludingFootnotes: String {
        switch self {
        case .footnote:
            return ""
        case .text, .formula, .lineBreak, .pageBreak, .document:
            return plainText
        default:
            return children.map(\.plainTextExcludingFootnotes).joined(separator: " ")
        }
    }

    /// Direct and indirect child nodes (used for recursive cross-reference and page-range extraction).
    var children: [FRUSASTNode] {
        switch self {
        case .text, .formula, .lineBreak, .pageBreak: return []
        case .document(_, _, let c): return c
        case .head(let c), .dateline(let c), .paragraph(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .term(let c), .editorialNote(let c), .titlePage(let c),
             .supplied(let c), .sic(let c), .corr(let c):
            return c
        case .attachment(_, let c): return c
        case .date(_, _, _, _, _, let c): return c
        case .emphasis(_, let c): return c
        case .persName(_, let c): return c
        case .gloss(_, let c):    return c
        case .crossReference(_, _, let c): return c
        case .figure(_, let c):   return c
        case .footnote(_, _, _, let c): return c
        case .table(let rows):    return rows
        case .tableRow(let cells): return cells
        case .tableCell(_, _, let c): return c
        case .list(_, let items): return items
        case .listItem(let c):    return c
        case .unknown(_, _, let c): return c
        }
    }
}
