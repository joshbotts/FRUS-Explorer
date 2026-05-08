// Collections/CollectionHTMLRenderer.swift
//
// Transforms a DocumentCollection into a print-ready HTML document whose
// document rendering matches the presentation used by history.state.gov —
// the official Office of the Historian website.
//
// history.state.gov uses a TEI Publisher / hsg-shell pipeline (HistoryAtState/hsg-shell)
// to transform FRUS TEI XML to HTML. Key presentation decisions from the live site:
//
//  • Document header block:
//      – "Foreign Relations of the United States · {volumeID}" source line (italic, muted)
//      – "Document N" number label
//      – All <head> children in sequence (type heading, then subject line)
//      – Dateline on its own line, italic
//      – Opener / salute if present
//  • Body: block-level <p>, text-align:justify, no first-line indent
//  • Footnote markers: superscript anchor <sup><a href="#fn-D-N">N</a></sup>
//    linked to numbered entries at the bottom with back-arrows
//  • <persName>, <placeName>, <orgName> → plain text (no colour — matching HSG)
//  • <hi rend="italic"> → <em>; <hi rend="bold"> → <strong>
//  • <hi rend="smallcaps"> → <span class="sc">
//  • <ref target="http…"> → <a>; otherwise plain text
//  • Sub-sections (nested <div>) rendered with a rule and smaller heading
//  • No collapsible XML source blocks
//
// Citation format follows https://history.state.gov/historicaldocuments/citing-frus:
//   _Foreign Relations of the United States_, [volume title],
//   eds. [Editor1 and Editor2] (Washington: Government Printing Office, year),
//   Document N.

import Foundation
import FRUSKit

// MARK: - CollectionHTMLRenderer

enum CollectionHTMLRenderer {

    // MARK: - Public API

    static func html(
        for collection: DocumentCollection,
        resolvedItems: [UUID: Division],
        loadedVolumes: [String: LoadedVolume]
    ) -> String {
        var bodyHTML = ""
        bodyHTML += coverHTML(for: collection)
        bodyHTML += tocHTML(for: collection)
        for (i, item) in collection.items.enumerated() {
            bodyHTML += documentHTML(
                item: item,
                division: resolvedItems[item.id],
                loadedVolume: loadedVolumes[item.volumeID],
                docIndex: i + 1,
                totalDocs: collection.items.count
            )
        }
        return fullPage(title: collection.name, body: bodyHTML)
    }

    // MARK: - Page skeleton

    private static func fullPage(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8"/>
        <title>\(esc(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - CSS
    // Typography and layout matching history.state.gov, adapted for US Letter print/PDF.

    private static let css: String = """
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
        html{font-size:10.5pt}
        body{
            font-family:Georgia,'Times New Roman',serif;
            color:#111;background:#fff;
            line-height:1.72;
            -webkit-print-color-adjust:exact;
            print-color-adjust:exact;
        }
        @page{
            size:8.5in 11in portrait;
            margin:1in 1.15in 1.1in 1.15in;
        }
        @media print{
            .page-break{page-break-before:always;break-before:page}
            .avoid-break{page-break-inside:avoid;break-inside:avoid}
            a{color:inherit;text-decoration:none}
            .doc-ref-url a{color:#0060a0;text-decoration:none}
        }
        p{orphans:3;widows:3}

        /* Cover */
        .cover{
            min-height:74vh;display:flex;flex-direction:column;
            justify-content:flex-end;padding-bottom:2.8rem;
            border-bottom:2px solid #444;
        }
        .cover-eyebrow{
            font-size:8pt;letter-spacing:.14em;text-transform:uppercase;
            color:#666;margin-bottom:.55rem;
        }
        .cover-title{font-size:21pt;font-weight:bold;line-height:1.22;margin-bottom:1.3rem}
        .cover-byline{font-size:9.5pt;color:#444;line-height:1.85}
        .cover-notes{
            margin-top:1.3rem;padding:.65rem .95rem;
            border-left:3px solid #bbb;font-size:10pt;
            font-style:italic;color:#444;
        }

        /* Table of contents */
        .toc{padding:2rem 0}
        .toc-heading{
            font-size:8.5pt;font-weight:bold;letter-spacing:.12em;
            text-transform:uppercase;color:#555;
            border-bottom:1px solid #999;padding-bottom:.3rem;
            margin-bottom:.9rem;
        }
        .toc-entry{
            display:grid;grid-template-columns:2.5em 1fr auto;
            gap:0 .5rem;padding:.17rem 0;font-size:9.5pt;
            align-items:baseline;
        }
        .toc-n{font-variant-numeric:tabular-nums;color:#777;text-align:right}
        .toc-date{font-style:italic;color:#666;white-space:nowrap;font-size:8.5pt}

        /* Document wrapper */
        .document{padding:2.4rem 0 2rem;border-top:1px solid #ccc}
        .document:first-of-type{border-top:none}

        /* Document reference block (volume label + URL) */
        .doc-ref{
            margin-bottom:.7rem;padding-bottom:.5rem;
            border-bottom:1px solid #e8e8e8;
        }
        .doc-ref-label{
            font-size:8pt;font-family:'Courier New',monospace;
            color:#555;margin-bottom:.15rem;
        }
        .doc-ref-url{
            font-size:8pt;color:#0060a0;
        }
        .doc-ref-url a{color:#0060a0;text-decoration:none}

        /* Header block — matching history.state.gov */
        .doc-header{margin-top:.55rem}
        .doc-source{font-size:8.5pt;font-style:italic;color:#666;margin-bottom:.45rem}
        .doc-number{
            font-size:8pt;font-weight:bold;letter-spacing:.07em;
            text-transform:uppercase;color:#555;margin-bottom:.28rem;
        }
        .doc-head-type{font-size:13pt;font-weight:bold;line-height:1.23;margin-bottom:.13rem}
        .doc-head-subject{font-size:11pt;font-weight:bold;color:#222;margin-bottom:.13rem}
        .doc-dateline{font-size:10pt;font-style:italic;color:#444;margin:.45rem 0 .55rem}
        .doc-opener{font-size:10pt;margin-bottom:.45rem}

        /* Body */
        .doc-body{margin-top:.65rem}
        .doc-body>p{text-align:justify;hyphens:auto;margin-bottom:.52rem}
        .doc-body>p:last-child{margin-bottom:0}

        /* Paragraph alignment/style variants */
        p.text-center{text-align:center;hyphens:none}
        p.text-right{text-align:right;hyphens:none}
        p.text-italic{font-style:italic}
        p.indent{text-indent:1.5em}

        /* Subsections */
        .subsection{margin-top:1.35rem;padding-top:.85rem;border-top:1px solid #ddd}
        .subsection-head{font-size:10.5pt;font-weight:bold;margin-bottom:.32rem}
        .subsection-dateline{font-size:9.5pt;font-style:italic;color:#555;margin-bottom:.38rem}
        .subsection-body>p{text-align:justify;hyphens:auto;margin-bottom:.5rem}
        .subsection-body>p:last-child{margin-bottom:0}

        /* Closer */
        .doc-closer{font-style:italic;color:#333;margin-top:.55rem;font-size:10pt}

        /* Inline — plain text for named entities, matching live site */
        em{font-style:italic}
        strong{font-weight:bold}
        .sc{font-variant:small-caps}
        u{text-decoration:underline}
        em.term{}

        /* Page breaks */
        .pb{font-size:7pt;color:#bbb;font-family:'Courier New',monospace;margin:0 1px}

        /* Lists */
        ul.tei-list,ol.tei-list{margin:.38rem 0 .45rem 1.8rem}
        ul.tei-list li,ol.tei-list li{margin-bottom:.2rem}

        /* Tables */
        table.tei-table{border-collapse:collapse;width:100%;margin:.65rem 0;font-size:9pt}
        table.tei-table th,table.tei-table td{border:1px solid #bbb;padding:3px 6px;vertical-align:top}
        table.tei-table th{font-weight:bold;background:#f3f3ef}

        /* Footnote inline superscripts */
        sup.fn-ref{font-size:7.5pt;line-height:0;vertical-align:super}
        sup.fn-ref a{color:#333;text-decoration:none}

        /* Footnotes block */
        .footnotes{margin-top:1.5rem;padding-top:.5rem;border-top:1px solid #bbb;font-size:9pt;color:#333}
        .footnotes-label{font-size:8pt;font-variant:small-caps;letter-spacing:.06em;color:#777;margin-bottom:.45rem}
        .fn-entry{display:flex;gap:.5rem;margin-bottom:.32rem;align-items:baseline}
        .fn-back{font-size:8pt;color:#999;text-decoration:none;flex-shrink:0}
        .fn-n{min-width:1.8em;text-align:right;font-variant-numeric:tabular-nums;flex-shrink:0}
        .fn-text{flex:1;line-height:1.5}

        /* Citation block */
        .doc-citation{
            margin-top:1.2rem;padding:.4rem .7rem;
            border-left:2px solid #ccc;
            font-size:8.5pt;color:#555;line-height:1.5;
        }
        .doc-citation-label{font-style:normal;font-weight:600;margin-right:.3em}

        /* User annotation */
        .annotation{
            margin-top:.9rem;padding:.5rem .85rem;
            background:#fffde7;border-left:3px solid #c8b400;
            font-size:9.5pt;font-style:italic;color:#444;line-height:1.5;
        }
        .annotation-label{font-weight:bold;font-style:normal;margin-right:.3em}

        /* Not-loaded notice */
        .not-loaded{font-style:italic;color:#888;font-size:9.5pt;margin-top:.5rem}
    """

    // MARK: - Cover

    private static func coverHTML(for c: DocumentCollection) -> String {
        let df = DateFormatter(); df.dateStyle = .long
        let n = c.items.count
        var h  = "<div class=\"cover\">\n"
        h += "<p class=\"cover-eyebrow\">Foreign Relations of the United States — Custom Collection</p>\n"
        h += "<h1 class=\"cover-title\">\(esc(c.name))</h1>\n"
        h += "<div class=\"cover-byline\">"
        let plural = n == 1 ? "" : "s"
        h += "<p>\(n) document\(plural)</p>"
        h += "<p>Created \(df.string(from: c.createdAt))</p>"
        h += "<p>Last modified \(df.string(from: c.modifiedAt))</p>"
        h += "</div>\n"
        if !c.notes.isEmpty {
            h += "<div class=\"cover-notes\">\(esc(c.notes))</div>\n"
        }
        h += "</div>\n"
        return h
    }

    // MARK: - Table of Contents

    private static func tocHTML(for c: DocumentCollection) -> String {
        guard !c.items.isEmpty else { return "" }
        var h = "<div class=\"toc page-break\">\n<p class=\"toc-heading\">Contents</p>\n"
        for (i, item) in c.items.enumerated() {
            h += "<div class=\"toc-entry\">"
            h += "<span class=\"toc-n\">\(i+1).</span>"
            h += "<span class=\"toc-title\">\(esc(item.cachedTitle))</span>"
            h += "<span class=\"toc-date\">\(esc(item.cachedDateline ?? ""))</span>"
            h += "</div>\n"
        }
        h += "</div>\n"
        return h
    }

    // MARK: - Document

    private static func documentHTML(
        item: CollectionItem,
        division: Division?,
        loadedVolume: LoadedVolume?,
        docIndex: Int,
        totalDocs: Int
    ) -> String {
        var h = "<div class=\"document page-break\" id=\"doc-\(docIndex)\">\n"

        // Reference block: volume + document identifier and history.state.gov URL
        let hsgURL = "https://history.state.gov/historicaldocuments/\(item.volumeID)/\(item.divisionID)"
        let docLabel: String
        if let n = division?.number {
            docLabel = "Volume \(item.volumeID) \u{00B7} Document \(n)"
        } else {
            docLabel = "Volume \(item.volumeID) \u{00B7} \(item.divisionID)"
        }
        h += "<div class=\"doc-ref avoid-break\">\n"
        h += "<p class=\"doc-ref-label\">\(esc(docLabel))</p>\n"
        h += "<p class=\"doc-ref-url\"><a href=\"\(esc(hsgURL))\">\(esc(hsgURL))</a></p>\n"
        h += "</div>\n"

        if let div = division {
            let fns = buildFootnoteRegistry(from: div, docIndex: docIndex)
            h += "<div class=\"doc-header avoid-break\">\n"
            h += headerHTML(div: div, item: item)
            h += "</div>\n"
            h += bodyHTML(div: div, fns: fns, docIndex: docIndex, depth: 0)
            if !fns.isEmpty { h += footnotesHTML(fns: fns) }
        } else {
            h += "<div class=\"doc-header avoid-break\">\n"
            h += "<p class=\"doc-source\">Foreign Relations of the United States &middot; \(esc(item.volumeID))</p>\n"
            h += "<p class=\"doc-head-type\">\(esc(item.cachedTitle))</p>\n"
            if let dl = item.cachedDateline {
                h += "<p class=\"doc-dateline\">\(esc(dl))</p>\n"
            }
            h += "</div>\n"
            h += "<p class=\"not-loaded\">Full text unavailable — volume not currently loaded. Load the volume in FRUS Explorer and re-export this collection to include the complete text.</p>\n"
        }

        // Citation
        h += citationHTML(item: item, division: division, volume: loadedVolume?.volume)

        // User annotation
        if !item.annotation.isEmpty {
            h += "<div class=\"annotation\"><span class=\"annotation-label\">Research Note:</span> \(esc(item.annotation))</div>\n"
        }

        h += "</div>\n"
        return h
    }

    // MARK: - Citation block

    // Citation format per https://history.state.gov/historicaldocuments/citing-frus:
    // _Foreign Relations of the United States_, [volume title],
    // eds. [Name and Name] (Place: Publisher, Year), Document N.
    private static func citationHTML(
        item: CollectionItem,
        division: Division?,
        volume: FRUSVolume?
    ) -> String {
        let series = volume?.seriesTitle ?? "Foreign Relations of the United States"
        let volTitle = volume?.volumeTitle

        let stmt = volume?.header.fileDescription.titleStatement
        let primaryEditors = (stmt?.editors ?? []).filter { $0.role == "primary" }
        let allEditors     = stmt?.editors ?? []
        let editorNames    = (primaryEditors.isEmpty ? allEditors : primaryEditors).map(\.name)
        let editorStr      = formatEditorNames(editorNames)

        let pub       = volume?.header.fileDescription.publicationStatement
        let pubPlace  = pub?.pubPlace  ?? "Washington"
        let publisher = pub?.publisher ?? "Government Printing Office"
        let year      = pub?.date      ?? ""

        let docNum = division?.number

        var cite = "<em>\(esc(series))</em>"
        if let vt = volTitle, !vt.isEmpty { cite += ", \(esc(vt))" }
        if !editorStr.isEmpty { cite += ", eds. \(esc(editorStr))" }
        var pubPart = "(\(esc(pubPlace)): \(esc(publisher))"
        if !year.isEmpty { pubPart += ", \(esc(year))" }
        pubPart += ")"
        cite += ", \(pubPart)"
        if let n = docNum { cite += ", Document \(esc(n))." } else { cite += "." }

        return "<div class=\"doc-citation\"><span class=\"doc-citation-label\">Cite as:</span> \(cite)</div>\n"
    }

    private static func formatEditorNames(_ names: [String]) -> String {
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        case 2:  return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + ", and " + names.last!
        }
    }

    // MARK: - Header block

    private static func headerHTML(div: Division, item: CollectionItem) -> String {
        var h = "<p class=\"doc-source\">Foreign Relations of the United States &middot; \(esc(item.volumeID))</p>\n"
        if let n = div.number {
            h += "<p class=\"doc-number\">Document \(esc(n))</p>\n"
        }
        for (i, heading) in div.headings.enumerated() {
            let cls = i == 0 ? "doc-head-type" : "doc-head-subject"
            h += "<p class=\"\(cls)\">\(inline(heading.content, fns: nil, di: 0))</p>\n"
        }
        if let dl = div.dateline {
            h += "<p class=\"doc-dateline\">\(inline(dl.content, fns: nil, di: 0))</p>\n"
        }
        if let op = div.opener, !op.content.isEmpty {
            h += "<p class=\"doc-opener\">\(inline(op.content, fns: nil, di: 0))</p>\n"
        }
        return h
    }

    // MARK: - Body (recursive)

    private static func bodyHTML(
        div: Division,
        fns: [FootnoteRecord],
        docIndex: Int,
        depth: Int
    ) -> String {
        var h = ""
        if !div.paragraphs.isEmpty {
            let cls = depth == 0 ? "doc-body" : "subsection-body"
            h += "<div class=\"\(cls)\">\n"
            for p in div.paragraphs {
                var pClasses: [String] = []
                if let rend = p.rend {
                    if rend.contains("center") { pClasses.append("text-center") }
                    if rend.contains("right")  { pClasses.append("text-right") }
                    if rend.contains("italic") { pClasses.append("text-italic") }
                    if rend.contains("indent") { pClasses.append("indent") }
                }
                let pAttr = pClasses.isEmpty ? "" : " class=\"\(pClasses.joined(separator: " "))\""
                h += "<p\(pAttr)>\(inline(p.content, fns: fns, di: docIndex))</p>\n"
            }
            h += "</div>\n"
        }
        if let cl = div.closer, !cl.content.isEmpty {
            h += "<p class=\"doc-closer\">\(inline(cl.content, fns: nil, di: 0))</p>\n"
        }
        for child in div.children {
            h += "<div class=\"subsection avoid-break\">\n"
            for (i, hd) in child.headings.enumerated() {
                h += "<p class=\"\(i == 0 ? "subsection-head" : "doc-head-subject")\">\(inline(hd.content, fns: nil, di: 0))</p>\n"
            }
            if let dl = child.dateline {
                h += "<p class=\"subsection-dateline\">\(inline(dl.content, fns: nil, di: 0))</p>\n"
            }
            if let op = child.opener, !op.content.isEmpty {
                h += "<p class=\"doc-opener\">\(inline(op.content, fns: nil, di: 0))</p>\n"
            }
            h += bodyHTML(div: child, fns: fns, docIndex: docIndex, depth: depth + 1)
            h += "</div>\n"
        }
        return h
    }

    // MARK: - Footnote registry

    struct FootnoteRecord {
        let noteID: String
        let marker: String
        let contentHTML: String
        let anchorID: String   // href target in body
        let refID: String      // id on the superscript in body
    }

    static func buildFootnoteRegistry(from div: Division, docIndex: Int) -> [FootnoteRecord] {
        var records: [FootnoteRecord] = []
        gatherNotes(div: div, into: &records, docIndex: docIndex)
        return records
    }

    private static func gatherNotes(div: Division, into out: inout [FootnoteRecord], docIndex: Int) {
        // Direct child notes (source citations) are registered first — before inline notes.
        // In printed FRUS, the source note always leads the footnote block.
        for n in div.notes where isCollectableNote(n) {
            appendFn(n, into: &out, docIndex: docIndex)
        }
        for p in div.paragraphs { gatherInlineNotes(p.content, into: &out, docIndex: docIndex) }
        if let op = div.opener  { gatherInlineNotes(op.content, into: &out, docIndex: docIndex) }
        if let cl = div.closer  { gatherInlineNotes(cl.content, into: &out, docIndex: docIndex) }
        for child in div.children { gatherNotes(div: child, into: &out, docIndex: docIndex) }
    }

    private static func isCollectableNote(_ note: Note) -> Bool {
        note.place == "bottom" || note.place == "end"
            || note.type == "footnote" || note.type == "source"
    }

    private static func gatherInlineNotes(_ content: [InlineContent], into out: inout [FootnoteRecord], docIndex: Int) {
        for item in content {
            switch item {
            case .note(let n) where n.type == "footnote" || n.type == nil || n.place == "bottom":
                appendFn(n, into: &out, docIndex: docIndex)
            case .hi(let h):
                gatherInlineNotes(h.content, into: &out, docIndex: docIndex)
            case .list(let l):
                for listItem in l.items {
                    gatherInlineNotes(listItem.content, into: &out, docIndex: docIndex)
                }
            default:
                break
            }
        }
    }

    private static func appendFn(_ note: Note, into out: inout [FootnoteRecord], docIndex: Int) {
        let seq  = out.count + 1
        let mark = note.n ?? "\(seq)"
        let nid  = note.id ?? "auto-\(docIndex)-\(seq)"
        let anch = "fn-\(docIndex)-\(seq)"
        let ref  = "\(anch)-ref"
        var content = note.paragraphs.map { inline($0.content, fns: nil, di: 0) }.joined(separator: " ")
        if content.isEmpty { content = inline(note.content, fns: nil, di: 0) }
        out.append(FootnoteRecord(noteID: nid, marker: mark, contentHTML: content, anchorID: anch, refID: ref))
    }

    private static func footnotesHTML(fns: [FootnoteRecord]) -> String {
        var h = "<div class=\"footnotes\">\n<p class=\"footnotes-label\">Notes</p>\n"
        for fn in fns {
            h += "<div class=\"fn-entry\" id=\"\(fn.anchorID)\">"
            h += "<a class=\"fn-back\" href=\"#\(fn.refID)\">&#x21a9;</a>"
            h += "<span class=\"fn-n\">\(esc(fn.marker)).</span>"
            h += "<span class=\"fn-text\">\(fn.contentHTML)</span>"
            h += "</div>\n"
        }
        h += "</div>\n"
        return h
    }

    // MARK: - Inline → HTML

    static func inline(_ content: [InlineContent], fns: [FootnoteRecord]?, di: Int) -> String {
        content.map { frag($0, fns: fns, di: di) }.joined()
    }

    private static func frag(_ item: InlineContent, fns: [FootnoteRecord]?, di: Int) -> String {
        switch item {
        case .text(let s):      return esc(s.xmlWhitespaceCollapsed())
        // Named entities — plain text, no colour (matching history.state.gov)
        case .persName(let p):  return esc(p.text)
        case .placeName(let p): return esc(p.text)
        case .orgName(let o):   return esc(o.text)
        case .date(let d):      return esc(d.text)
        case .term(let t):      return "<em class=\"term\">\(esc(t.text))</em>"

        case .hi(let h):
            let inner = inline(h.content, fns: fns, di: di)
            let rend  = h.rend ?? ""
            if rend.contains("italic")    { return "<em>\(inner)</em>" }
            if rend.contains("bold")      { return "<strong>\(inner)</strong>" }
            if rend.contains("smallcaps") { return "<span class=\"sc\">\(inner)</span>" }
            if rend.contains("underline") { return "<u>\(inner)</u>" }
            return inner

        case .ref(let r):
            let text = esc(r.text)
            if let t = r.target, t.hasPrefix("http") {
                return "<a href=\"\(esc(t))\">\(text)</a>"
            }
            return text

        case .note(let n):
            // Resolve against registry; fall back to plain superscript
            let mark = n.n ?? "†"
            guard let fns else { return "<sup>\(esc(mark))</sup>" }
            if let rec = fns.first(where: { $0.noteID == (n.id ?? "") || $0.marker == mark }) {
                return "<sup class=\"fn-ref\" id=\"\(rec.refID)\"><a href=\"#\(rec.anchorID)\">\(esc(rec.marker))</a></sup>"
            }
            return "<sup>\(esc(mark))</sup>"

        case .pageBreak(let pb):
            return pb.n.map { "<span class=\"pb\">[p.\(esc($0))]</span>" } ?? ""

        case .lineBreak:
            return "<br/>"

        case .list(let l):
            let tag   = l.type == "ordered" ? "ol" : "ul"
            let items = l.items.map { "<li>\(inline($0.content, fns: fns, di: di))</li>" }.joined()
            return "<\(tag) class=\"tei-list\">\(items)</\(tag)>"

        case .table(let t):
            let rows = t.rows.map { row -> String in
                let cells = row.cells.map { cell -> String in
                    let tag  = (row.role == "label") ? "th" : "td"
                    var attr = ""
                    if let c = cell.cols { attr += " colspan=\"\(c)\"" }
                    if let r = cell.rows { attr += " rowspan=\"\(r)\"" }
                    return "<\(tag)\(attr)>\(inline(cell.content, fns: fns, di: di))</\(tag)>"
                }.joined()
                return "<tr>\(cells)</tr>"
            }.joined()
            return "<table class=\"tei-table\">\(rows)</table>"

        case .unknown: return ""
        }
    }

    // MARK: - XML escaping

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
