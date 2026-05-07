// Collections/DivisionXMLRenderer.swift
// Serialises a parsed FRUSKit Division (and its inline content) back to
// well-formed TEI P5 XML, which is then used as input to the HTML/PDF renderer.

import Foundation

// MARK: - DivisionXMLRenderer

enum DivisionXMLRenderer {

    // MARK: Public entry point

    /// Render a single `Division` as a self-contained TEI XML fragment string.
    static func xml(for division: Division, volumeID: String) -> String {
        var out = ""
        renderDiv(division, into: &out, indent: 0)
        return out
    }

    // MARK: - Division

    private static func renderDiv(_ div: Division, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        var attrs = ""
        if let id = div.id          { attrs += " xml:id=\"\(escape(id))\"" }
        if let t = div.type         { attrs += " type=\"\(t.rawValue)\"" }
        if let n = div.number       { attrs += " n=\"\(escape(n))\"" }
        if let s = div.subtype      { attrs += " subtype=\"\(escape(s))\"" }
        out += "\(pad)<div\(attrs)>\n"

        for h in div.headings   { renderHeading(h, into: &out, indent: indent + 1) }
        if let dl = div.dateline { renderDateline(dl, into: &out, indent: indent + 1) }
        if let op = div.opener   { renderOpener(op, into: &out, indent: indent + 1) }
        for p in div.paragraphs  { renderParagraph(p, into: &out, indent: indent + 1) }
        for child in div.children { renderDiv(child, into: &out, indent: indent + 1) }
        if let cl = div.closer   { renderCloser(cl, into: &out, indent: indent + 1) }
        for n in div.notes       { renderNote(n, into: &out, indent: indent + 1) }

        out += "\(pad)</div>\n"
    }

    // MARK: - Structural elements

    private static func renderHeading(_ h: Heading, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        var attrs = ""
        if let t = h.type { attrs += " type=\"\(escape(t))\"" }
        out += "\(pad)<head\(attrs)>\(renderInline(h.content))</head>\n"
    }

    private static func renderDateline(_ dl: Dateline, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        out += "\(pad)<dateline>\(renderInline(dl.content))</dateline>\n"
    }

    private static func renderOpener(_ op: Opener, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        out += "\(pad)<opener>\(renderInline(op.content))</opener>\n"
    }

    private static func renderCloser(_ cl: Closer, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        out += "\(pad)<closer>\(renderInline(cl.content))</closer>\n"
    }

    private static func renderParagraph(_ p: Paragraph, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        var attrs = ""
        if let id = p.id     { attrs += " xml:id=\"\(escape(id))\"" }
        if let r = p.rend    { attrs += " rend=\"\(escape(r))\"" }
        out += "\(pad)<p\(attrs)>\(renderInline(p.content))</p>\n"
    }

    private static func renderNote(_ n: Note, into out: inout String, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        var attrs = ""
        if let id = n.id     { attrs += " xml:id=\"\(escape(id))\"" }
        if let t = n.type    { attrs += " type=\"\(escape(t))\"" }
        if let num = n.n     { attrs += " n=\"\(escape(num))\"" }
        if let pl = n.place  { attrs += " place=\"\(escape(pl))\"" }
        if n.paragraphs.isEmpty && n.content.isEmpty {
            out += "\(pad)<note\(attrs)/>\n"
        } else {
            out += "\(pad)<note\(attrs)>\n"
            for p in n.paragraphs { renderParagraph(p, into: &out, indent: indent + 1) }
            if !n.content.isEmpty {
                out += "\(pad)  \(renderInline(n.content))\n"
            }
            out += "\(pad)</note>\n"
        }
    }

    // MARK: - Inline content → XML string

    static func renderInline(_ content: [InlineContent]) -> String {
        content.map { inlineFragment($0) }.joined()
    }

    private static func inlineFragment(_ item: InlineContent) -> String {
        switch item {
        case .text(let s):
            return escape(s)

        case .persName(let p):
            var attrs = ""
            if let r = p.ref  { attrs += " ref=\"\(escape(r))\"" }
            if let ro = p.role { attrs += " role=\"\(escape(ro))\"" }
            return "<persName\(attrs)>\(escape(p.text))</persName>"

        case .placeName(let p):
            let ref = p.ref.map { " ref=\"\(escape($0))\"" } ?? ""
            return "<placeName\(ref)>\(escape(p.text))</placeName>"

        case .orgName(let o):
            let ref = o.ref.map { " ref=\"\(escape($0))\"" } ?? ""
            return "<orgName\(ref)>\(escape(o.text))</orgName>"

        case .date(let d):
            var attrs = ""
            if let w = d.when       { attrs += " when=\"\(w)\"" }
            if let f = d.from       { attrs += " from=\"\(f)\"" }
            if let t = d.to         { attrs += " to=\"\(t)\"" }
            if let nb = d.notBefore { attrs += " notBefore=\"\(nb)\"" }
            if let na = d.notAfter  { attrs += " notAfter=\"\(na)\"" }
            return "<date\(attrs)>\(escape(d.text))</date>"

        case .ref(let r):
            var attrs = ""
            if let tgt = r.target { attrs += " target=\"\(escape(tgt))\"" }
            if let t = r.type     { attrs += " type=\"\(escape(t))\"" }
            return "<ref\(attrs)>\(escape(r.text))</ref>"

        case .hi(let h):
            let rend = h.rend.map { " rend=\"\(escape($0))\"" } ?? ""
            return "<hi\(rend)>\(renderInline(h.content))</hi>"

        case .term(let t):
            let ref = t.ref.map { " ref=\"\(escape($0))\"" } ?? ""
            return "<term\(ref)>\(escape(t.text))</term>"

        case .note(let n):
            var attrs = ""
            if let id = n.id   { attrs += " xml:id=\"\(escape(id))\"" }
            if let t = n.type  { attrs += " type=\"\(escape(t))\"" }
            if let num = n.n   { attrs += " n=\"\(escape(num))\"" }
            if let pl = n.place { attrs += " place=\"\(escape(pl))\"" }
            let inner = n.paragraphs.map { "<p>\(renderInline($0.content))</p>" }.joined()
                + (n.content.isEmpty ? "" : renderInline(n.content))
            return "<note\(attrs)>\(inner)</note>"

        case .pageBreak(let pb):
            var attrs = ""
            if let id = pb.id  { attrs += " xml:id=\"\(escape(id))\"" }
            if let n = pb.n    { attrs += " n=\"\(escape(n))\"" }
            if let f = pb.facs { attrs += " facs=\"\(escape(f))\"" }
            return "<pb\(attrs)/>"

        case .lineBreak:
            return "<lb/>"

        case .list(let l):
            let type = l.type.map { " type=\"\(escape($0))\"" } ?? ""
            let items = l.items.map { "<item>\(renderInline($0.content))</item>" }.joined()
            return "<list\(type)>\(items)</list>"

        case .table(let t):
            let rows = t.rows.map { row -> String in
                let role = row.role.map { " role=\"\(escape($0))\"" } ?? ""
                let cells = row.cells.map { cell -> String in
                    var ca = ""
                    if let r = cell.role  { ca += " role=\"\(escape(r))\"" }
                    if let c = cell.cols  { ca += " cols=\"\(c)\"" }
                    if let r = cell.rows  { ca += " rows=\"\(r)\"" }
                    return "<cell\(ca)>\(renderInline(cell.content))</cell>"
                }.joined()
                return "<row\(role)>\(cells)</row>"
            }.joined()
            return "<table>\(rows)</table>"

        case .unknown:
            return ""
        }
    }

    // MARK: - XML character escaping

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}
