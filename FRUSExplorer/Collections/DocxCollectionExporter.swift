// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocxCollectionExporter

/// Exports a collection's metadata and documents to a `.docx` (Office Open XML) file.
///
/// Produces a well-formed ZIP archive that opens in Word, Pages, and LibreOffice.
/// No external dependencies are required: a minimal stored-mode ZIP writer is
/// included inline (see `// MARK: - ZIP Writer`).
///
/// ## Document structure
///   - Cover page: collection title (Heading1), optional collection note, export
///     date + document/volume counts, Word field-code TOC
///   - One section per document (Heading2): history.state.gov URL, body content
///     (rich when `renderModel` is available, flat-text fallback otherwise),
///     optional research-note callout
///
/// ## ZIP contents
/// ```
/// [Content_Types].xml
/// _rels/.rels
/// word/document.xml
/// word/styles.xml
/// word/_rels/document.xml.rels
/// word/footnotes.xml
/// ```
///
/// Version history:
///   1.0 — Session 82: initial implementation; plain-text bodies, cover page, TOC,
///          research notes; stored-mode ZIP writer; five Open XML parts
///   1.1 — Session 83: rich rendering via FRUSDocumentRenderModel (bold, italic,
///          small caps, underline, strikethrough, datelines, footnotes, tables,
///          list items, attachments); word/footnotes.xml added; cover page gains
///          export date and document/volume count; TOC replaced with Word field-code
///          TOC; new styles: Heading3, Dateline, AttachmentHeading, FootnoteText,
///          DefaultParagraphFont, FootnoteReference
///   1.2 — Session 128: `markdownItalicRuns(_:styleId:)` converts `_text_` patterns
///          to inline italic Word runs; applied to citation headings, collection note,
///          and research note paragraphs; `options: CollectionExportOptions` controls ToC
///          label style; `noteTexts: [String]` and `includeDocumentBody` respected per entry
final class DocxCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions
    ) async throws -> URL {
        let data = buildDocx(collection: metadata, documents: documents, options: options)
        let filename = sanitized(metadata.name) + ".docx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - DOCX Assembly

    private func buildDocx(
        collection: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions
    ) -> Data {
        let ctx = DocxRenderContext()
        let decl = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"

        let bodyXML = documentBodyXML(collection: collection, documents: documents,
                                       ctx: ctx, options: options)
        let wNS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        let docXML = "<w:document xmlns:w=\"\(wNS)\">\n  <w:body>\n\(bodyXML)  </w:body>\n</w:document>"

        let entries: [ZipEntry] = [
            ZipEntry(path: "[Content_Types].xml",
                     data: Data((decl + contentTypesXML()).utf8)),
            ZipEntry(path: "_rels/.rels",
                     data: Data((decl + rootRelsXML()).utf8)),
            ZipEntry(path: "word/_rels/document.xml.rels",
                     data: Data((decl + documentRelsXML()).utf8)),
            ZipEntry(path: "word/styles.xml",
                     data: Data((decl + stylesXML()).utf8)),
            ZipEntry(path: "word/document.xml",
                     data: Data((decl + docXML).utf8)),
            ZipEntry(path: "word/footnotes.xml",
                     data: Data((decl + footnotesPartXML(ctx.footnoteXMLs)).utf8)),
        ]
        return buildZip(entries)
    }

    // MARK: - Open XML Parts

    private func contentTypesXML() -> String {
        let pfx = "http://schemas.openxmlformats.org/package/2006"
        let oxml = "application/vnd.openxmlformats-officedocument.wordprocessingml"
        return """
        <Types xmlns="\(pfx)/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml"
            ContentType="\(oxml).document.main+xml"/>
          <Override PartName="/word/styles.xml"
            ContentType="\(oxml).styles+xml"/>
          <Override PartName="/word/footnotes.xml"
            ContentType="\(oxml).footnotes+xml"/>
        </Types>
        """
    }

    private func rootRelsXML() -> String {
        let pfx = "http://schemas.openxmlformats.org/package/2006/relationships"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        return """
        <Relationships xmlns="\(pfx)">
          <Relationship Id="rId1" Type="\(rel)" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private func documentRelsXML() -> String {
        let pfx  = "http://schemas.openxmlformats.org/package/2006/relationships"
        let oxml = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        return """
        <Relationships xmlns="\(pfx)">
          <Relationship Id="rId1" Type="\(oxml)/styles"    Target="styles.xml"/>
          <Relationship Id="rId2" Type="\(oxml)/footnotes" Target="footnotes.xml"/>
        </Relationships>
        """
    }

    private func stylesXML() -> String {
        let w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        return """
        <w:styles xmlns:w="\(w)" w:docDefaults="true">
          <w:docDefaults>
            <w:rPrDefault>
              <w:rPr>
                <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                <w:sz w:val="24"/>
                <w:szCs w:val="24"/>
              </w:rPr>
            </w:rPrDefault>
          </w:docDefaults>
          <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
            <w:name w:val="Normal"/>
            <w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Heading1">
            <w:name w:val="heading 1"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:outlineLvl w:val="0"/>
              <w:spacing w:before="360" w:after="120"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="48"/><w:szCs w:val="48"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Heading2">
            <w:name w:val="heading 2"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:outlineLvl w:val="1"/>
              <w:spacing w:before="240" w:after="80"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Heading3">
            <w:name w:val="heading 3"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:outlineLvl w:val="2"/>
              <w:spacing w:before="160" w:after="60"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Dateline">
            <w:name w:val="Dateline"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:rPr><w:i/><w:color w:val="555555"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="AttachmentHeading">
            <w:name w:val="Attachment Heading"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:before="120" w:after="60"/></w:pPr>
            <w:rPr><w:b/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="CollectionNote">
            <w:name w:val="Collection Note"/>
            <w:basedOn w:val="Normal"/>
            <w:rPr><w:i/><w:color w:val="555555"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="DocURL">
            <w:name w:val="Document URL"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:rPr><w:color w:val="1A4C8F"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="ResearchNote">
            <w:name w:val="Research Note"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:ind w:left="360" w:right="360"/>
              <w:shd w:val="clear" w:color="auto" w:fill="FFFBEA"/>
            </w:pPr>
            <w:rPr><w:color w:val="444444"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="FootnoteText">
            <w:name w:val="footnote text"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
          </w:style>
          <w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont">
            <w:name w:val="Default Paragraph Font"/>
          </w:style>
          <w:style w:type="character" w:styleId="FootnoteReference">
            <w:name w:val="footnote reference"/>
            <w:basedOn w:val="DefaultParagraphFont"/>
            <w:rPr><w:vertAlign w:val="superscript"/></w:rPr>
          </w:style>
        </w:styles>
        """
    }

    // MARK: - Document Body

    private func documentBodyXML(
        collection: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        ctx: DocxRenderContext,
        options: CollectionExportOptions
    ) -> String {
        var body = ""

        // Cover: collection title
        body += styledPara(escaped(collection.name), styleId: "Heading1")

        // Cover: optional note — markdownItalicRuns converts _text_ to italic Word runs.
        if let note = collection.note, !note.isEmpty {
            body += markdownItalicRuns(note, styleId: "CollectionNote")
        }

        // Cover: export metadata
        let docCount = documents.count
        let volCount = Set(documents.map { $0.volumeId }).count
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .none
        let info = "\(docCount) document\(docCount == 1 ? "" : "s") from "
            + "\(volCount) volume\(volCount == 1 ? "" : "s") · Exported \(df.string(from: Date()))"
        body += styledPara(info, styleId: "Normal")

        // Contents heading + Word TOC field code (updates on first open in Word)
        body += styledPara("Contents", styleId: "Heading2")
        body += tocFieldXML()

        // Page break before document sections
        body += "    <w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>\n"

        // Document sections
        for doc in documents {
            // Section heading always shows the citation; markdownItalicRuns handles _text_.
            let heading = doc.citation.isEmpty ? doc.title : doc.citation
            body += markdownItalicRuns(heading, styleId: "Heading2", bold: true)

            if !doc.historyStateGovURL.isEmpty {
                body += styledPara(escaped(doc.historyStateGovURL), styleId: "DocURL")
            }

            // Body — controlled by options.bodyDepth.
            switch options.bodyDepth {
            case .full:
                if let model = doc.renderModel {
                    body += renderModelToDocxParagraphs(model, ctx: ctx)
                } else {
                    let paras = doc.bodyText
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in paras {
                        body += styledPara(
                            escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)
                                       .replacingOccurrences(of: "\n", with: " ")),
                            styleId: "Normal")
                    }
                }
            case .summaryOnly:
                if let summary = doc.summaryText, !summary.isEmpty {
                    body += styledPara("Summary", styleId: "Heading3")
                    let summaryParas = summary
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in summaryParas {
                        body += styledPara(
                            escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)),
                            styleId: "Normal")
                    }
                }
            case .index:
                break
            }

            // Source note (footnoteStyle == .sourceNoteOnly)
            if let sourceNote = doc.sourceNoteText, !sourceNote.isEmpty {
                body += styledPara("Source: \(escaped(sourceNote))", styleId: "DocURL")
            }

            // Research notes — respects options.includeNotes.
            guard options.includeNotes else { continue }
            for note in doc.noteTexts where !note.isEmpty {
                body += researchNoteHeadingPara()
                let noteParagraphs = note
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in noteParagraphs {
                    let text = para
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                    body += markdownItalicRuns(text, styleId: "ResearchNote")
                }
            }
        }

        body += "    <w:sectPr/>\n"
        return body
    }

    // MARK: - Rich Rendering (Session 83)

    // Context object that tracks footnote IDs and collects footnote XML
    // across all documents in one export run. Created fresh per buildDocx call.
    private final class DocxRenderContext {
        private(set) var nextId = 1
        private(set) var footnoteXMLs: [String] = []

        func allocate() -> Int {
            defer { nextId += 1 }
            return nextId
        }

        func addFootnote(_ xml: String) {
            footnoteXMLs.append(xml)
        }
    }

    // Accumulated run properties passed down during inline rendering
    private struct RunProps {
        var bold      = false
        var italic    = false
        var smallCaps = false
        var underline = false
        var strike    = false

        init(bold: Bool = false, italic: Bool = false, smallCaps: Bool = false,
             underline: Bool = false, strike: Bool = false) {
            self.bold = bold; self.italic = italic; self.smallCaps = smallCaps
            self.underline = underline; self.strike = strike
        }

        func rPrXML() -> String {
            var p = ""
            if bold      { p += "<w:b/>" }
            if italic    { p += "<w:i/>" }
            if smallCaps { p += "<w:smallCaps/>" }
            if underline { p += "<w:u w:val=\"single\"/>" }
            if strike    { p += "<w:strike/>" }
            return p.isEmpty ? "" : "<w:rPr>\(p)</w:rPr>"
        }

        func adding(bold: Bool = false, italic: Bool = false,
                    smallCaps: Bool = false, underline: Bool = false,
                    strike: Bool = false) -> RunProps {
            RunProps(bold: self.bold || bold, italic: self.italic || italic,
                     smallCaps: self.smallCaps || smallCaps,
                     underline: self.underline || underline, strike: self.strike || strike)
        }
    }

    /// Renders a `FRUSDocumentRenderModel` to Word paragraph XML.
    /// Pre-scans footnote labels to assign integer IDs, renders body nodes,
    /// then adds footnote bodies to `ctx`.
    private func renderModelToDocxParagraphs(
        _ model: FRUSDocumentRenderModel,
        ctx: DocxRenderContext
    ) -> String {
        // Pre-assign Word integer IDs to every footnote in this document
        var labelMap: [String: Int] = [:]
        for note in model.footnotes {
            if case .footnoteBody(_, _, _, _, let label, _) = note {
                labelMap[label] = ctx.allocate()
            }
        }

        // Render body paragraphs
        let bodyXML = model.bodyNodes
            .map { blockNodeToDocxXML($0, labelMap: labelMap) }
            .joined()

        // Render footnote bodies and register with context
        for note in model.footnotes {
            if case .footnoteBody(_, _, _, _, let label, let children) = note,
               let wordId = labelMap[label] {
                let footXML = singleParaFootnoteXML(id: wordId, children: children, labelMap: labelMap)
                ctx.addFootnote(footXML)
            }
        }

        return bodyXML
    }

    /// Converts a block render node to one or more `<w:p>` XML strings.
    private func blockNodeToDocxXML(_ node: FRUSRenderNode, labelMap: [String: Int]) -> String {
        switch node {
        case .heading(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap),
                         styleId: "Heading3")
        case .dateline(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(italic: true), labelMap: labelMap),
                         styleId: "Dateline")
        case .salutation(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap),
                         styleId: "Normal")
        case .paragraph(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap),
                         styleId: "Normal")
        case .letterOpener(let c), .letterCloser(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap) }.joined()
        case .editorialNoteBlock(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap) }.joined()
        case .attachmentBlock(_, let c):
            let sep = "    <w:p><w:pPr><w:pBdr><w:top w:val=\"single\" w:sz=\"6\" w:space=\"1\"/></w:pBdr></w:pPr></w:p>\n"
            return sep + c.map { blockNodeToDocxXML($0, labelMap: labelMap) }.joined()
        case .attachmentHeading(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap),
                         styleId: "AttachmentHeading")
        case .titlePageBlock(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap) }.joined()
        case .tableBlock(let rows):
            return tableToDocxXML(rows, labelMap: labelMap)
        case .listBlock(let type, let items):
            return items.enumerated().map { (i, item) in
                let bullet = (type == "ordered") ? "\(i + 1). " : "• "
                let bulletRun = "<w:r><w:t xml:space=\"preserve\">\(bullet)</w:t></w:r>"
                let runs = inlineRunsXML(item, props: RunProps(), labelMap: labelMap)
                return "    <w:p>\n"
                    + "      <w:pPr><w:pStyle w:val=\"Normal\"/><w:ind w:left=\"360\"/></w:pPr>\n"
                    + "      \(bulletRun)\(runs)\n"
                    + "    </w:p>\n"
            }.joined()
        case .figureBlock(let alt):
            guard let alt, !alt.isEmpty else { return "" }
            return wPara(runs: "<w:r><w:t xml:space=\"preserve\">[Figure: \(xmlEscaped(alt))]</w:t></w:r>",
                         styleId: "Normal")
        case .footnoteBody:
            return "" // serialised separately via model.footnotes
        case .pageBreak:
            return "    <w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>\n"
        case .unknown(_, let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap) }.joined()
        default:
            // Inline node at block level — wrap in Normal paragraph
            return wPara(runs: inlineNodeRunXML(node, props: RunProps(), labelMap: labelMap),
                         styleId: "Normal")
        }
    }

    private func inlineRunsXML(_ nodes: [FRUSRenderNode], props: RunProps,
                                labelMap: [String: Int]) -> String {
        nodes.map { inlineNodeRunXML($0, props: props, labelMap: labelMap) }.joined()
    }

    private func inlineNodeRunXML(_ node: FRUSRenderNode, props: RunProps,
                                   labelMap: [String: Int]) -> String {
        switch node {
        case .plainText(let s):
            guard !s.isEmpty else { return "" }
            return "<w:r>\(props.rPrXML())<w:t xml:space=\"preserve\">\(xmlEscaped(s))</w:t></w:r>"
        case .boldText(let c):
            return inlineRunsXML(c, props: props.adding(bold: true), labelMap: labelMap)
        case .italicText(let c):
            return inlineRunsXML(c, props: props.adding(italic: true), labelMap: labelMap)
        case .smallCapsText(let c):
            return inlineRunsXML(c, props: props.adding(smallCaps: true), labelMap: labelMap)
        case .underlineText(let c):
            return inlineRunsXML(c, props: props.adding(underline: true), labelMap: labelMap)
        case .sicText(let c):
            return inlineRunsXML(c, props: props.adding(strike: true), labelMap: labelMap)
        case .suppliedText(let c):
            let rpr = props.rPrXML()
            let open  = "<w:r>\(rpr)<w:t>[</w:t></w:r>"
            let inner = inlineRunsXML(c, props: props, labelMap: labelMap)
            let close = "<w:r>\(rpr)<w:t>]</w:t></w:r>"
            return open + inner + close
        case .formulaText(let s):
            let ip = props.adding(italic: true)
            return "<w:r>\(ip.rPrXML())<w:t xml:space=\"preserve\">\(xmlEscaped(s))</w:t></w:r>"
        case .lineBreak:
            return "<w:r><w:br/></w:r>"
        case .footnoteMarker(_, let label):
            guard let wordId = labelMap[label] else {
                // Fallback: render label as superscript text
                let sup = "<w:rPr><w:vertAlign w:val=\"superscript\"/></w:rPr>"
                return "<w:r>\(sup)<w:t>\(xmlEscaped(label))</w:t></w:r>"
            }
            return "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr>"
                + "<w:footnoteReference w:id=\"\(wordId)\"/></w:r>"
        case .termText(let c), .corrText(let c):
            return inlineRunsXML(c, props: props, labelMap: labelMap)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, let c):
            return inlineRunsXML(c, props: props, labelMap: labelMap)
        case .pageBreak:
            return ""
        case .unknown(_, let c):
            return inlineRunsXML(c, props: props, labelMap: labelMap)
        default:
            return "" // Block nodes in inline context: not expected in FRUS inline runs
        }
    }

    private func tableToDocxXML(_ rows: [[TableCell]], labelMap: [String: Int]) -> String {
        var xml = "    <w:tbl>\n"
        xml += "      <w:tblPr><w:tblBorders>"
        for side in ["top", "left", "bottom", "right", "insideH", "insideV"] {
            xml += "<w:\(side) w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        }
        xml += "</w:tblBorders></w:tblPr>\n"
        for row in rows {
            xml += "      <w:tr>"
            for cell in row {
                var tcPr = ""
                if cell.colSpan > 1 { tcPr += "<w:gridSpan w:val=\"\(cell.colSpan)\"/>" }
                let tcPrXML = tcPr.isEmpty ? "" : "<w:tcPr>\(tcPr)</w:tcPr>"
                let runs = inlineRunsXML(cell.children, props: RunProps(), labelMap: labelMap)
                xml += "<w:tc>\(tcPrXML)<w:p>\(runs)</w:p></w:tc>"
            }
            xml += "</w:tr>\n"
        }
        xml += "    </w:tbl>\n"
        return xml
    }

    /// Builds a single-paragraph footnote XML entry for `word/footnotes.xml`.
    /// Footnote body children are rendered as inline runs and collapsed into one
    /// `FootnoteText` paragraph (suitable for the one-paragraph FRUS footnote pattern).
    private func singleParaFootnoteXML(
        id: Int,
        children: [FRUSRenderNode],
        labelMap: [String: Int]
    ) -> String {
        let refRun = "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteRef/></w:r>"
        let spacer = "<w:r><w:t xml:space=\"preserve\"> </w:t></w:r>"
        let runs = children.map { inlineOrBlockRuns($0, labelMap: labelMap) }.joined()
        return "      <w:footnote w:id=\"\(id)\">\n"
            + "        <w:p><w:pPr><w:pStyle w:val=\"FootnoteText\"/></w:pPr>"
            + "\(refRun)\(spacer)\(runs)</w:p>\n"
            + "      </w:footnote>\n"
    }

    /// Extracts inline runs from a node regardless of whether it is a block or inline.
    private func inlineOrBlockRuns(_ node: FRUSRenderNode, labelMap: [String: Int]) -> String {
        switch node {
        case .paragraph(let c), .heading(let c), .dateline(let c),
             .salutation(let c), .attachmentHeading(let c):
            return inlineRunsXML(c, props: RunProps(), labelMap: labelMap)
        case .letterOpener(let c), .letterCloser(let c), .editorialNoteBlock(let c),
             .attachmentBlock(_, let c), .titlePageBlock(let c), .unknown(_, let c):
            return c.map { inlineOrBlockRuns($0, labelMap: labelMap) }.joined()
        default:
            return inlineNodeRunXML(node, props: RunProps(), labelMap: labelMap)
        }
    }

    /// Builds `word/footnotes.xml` from collected footnote XML fragments.
    private func footnotesPartXML(_ footnoteXMLs: [String]) -> String {
        let w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        let separators = """
              <w:footnote w:type="separator" w:id="-1">
                <w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:separator/></w:r></w:p>
              </w:footnote>
              <w:footnote w:type="continuationSeparator" w:id="0">
                <w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:continuationSeparator/></w:r></w:p>
              </w:footnote>
        """
        let body = footnoteXMLs.joined()
        return "<w:footnotes xmlns:w=\"\(w)\">\n\(separators)\n\(body)</w:footnotes>"
    }

    /// Word field-code TOC: `\o "1-2"` collects Heading1–Heading2.
    /// `w:dirty="true"` causes Word to rebuild on first open.
    private func tocFieldXML() -> String {
        "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\n"
        + "      <w:r><w:fldChar w:fldCharType=\"begin\" w:dirty=\"true\"/></w:r>\n"
        + "      <w:r><w:instrText xml:space=\"preserve\"> TOC \\o \"1-2\" \\h \\z \\u </w:instrText></w:r>\n"
        + "      <w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>\n"
        + "      <w:r><w:t>Right-click to update the table of contents.</w:t></w:r>\n"
        + "      <w:r><w:fldChar w:fldCharType=\"end\"/></w:r>\n"
        + "    </w:p>\n"
    }

    // MARK: - XML Element Helpers

    /// Emits a styled paragraph whose text may contain `_span_` Markdown italic markers.
    ///
    /// Splits `text` on `_..._` patterns and emits alternating normal / italic runs so that
    /// `_Foreign Relations of the United States_` appears as italic text in Word/Pages/LibreOffice
    /// rather than literal underscores.
    ///
    /// - Parameters:
    ///   - text: Raw (un-escaped) source text with optional `_span_` markers.
    ///   - styleId: The Word paragraph style to apply.
    ///   - bold: When `true`, the base run properties include `<w:b/>`.
    private func markdownItalicRuns(_ text: String, styleId: String, bold: Bool = false) -> String {
        guard let regex = try? NSRegularExpression(pattern: "_([^_\\n]+)_") else {
            return styledPara(escaped(text), styleId: styleId)
        }
        let ns = text as NSString
        let length = ns.length
        var runs = ""
        var lastEnd = 0
        var boldTag: String { bold ? "<w:b/>" : "" }

        for match in regex.matches(in: text, range: NSRange(location: 0, length: length)) {
            // Normal run before the italic span
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            if beforeRange.length > 0 {
                let chunk = xmlEscaped(ns.substring(with: beforeRange))
                runs += "<w:r><w:rPr>\(boldTag)</w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
            }
            // Italic run for the matched span content
            let g1 = match.range(at: 1)
            if g1.location != NSNotFound, g1.length > 0 {
                let chunk = xmlEscaped(ns.substring(with: g1))
                runs += "<w:r><w:rPr>\(boldTag)<w:i/></w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
            }
            lastEnd = match.range.upperBound
        }
        // Trailing normal run
        if lastEnd < length {
            let chunk = xmlEscaped(ns.substring(from: lastEnd))
            runs += "<w:r><w:rPr>\(boldTag)</w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
        }

        return runs.isEmpty
            ? styledPara("", styleId: styleId)
            : wPara(runs: runs, styleId: styleId)
    }

    /// Emits a styled paragraph with a single plain-text run.
    private func styledPara(_ text: String, styleId: String) -> String {
        "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"\(styleId)\"/></w:pPr>\n"
        + "      <w:r><w:t xml:space=\"preserve\">\(text)</w:t></w:r>\n"
        + "    </w:p>\n"
    }

    /// Emits a paragraph with arbitrary run XML and an optional style.
    private func wPara(runs: String, styleId: String) -> String {
        "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"\(styleId)\"/></w:pPr>\n"
        + "      \(runs)\n"
        + "    </w:p>\n"
    }

    private func researchNoteHeadingPara() -> String {
        "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"ResearchNote\"/></w:pPr>\n"
        + "      <w:r><w:rPr><w:b/></w:rPr>"
        + "<w:t xml:space=\"preserve\">Research Note</w:t></w:r>\n"
        + "    </w:p>\n"
    }

    private func escaped(_ text: String) -> String {
        xmlEscaped(text)
    }

    private func xmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }

    // MARK: - ZIP Writer

    private struct ZipEntry {
        let path: String
        let data: Data
    }

    private struct PreparedEntry {
        let pathBytes: Data
        let data: Data
        let crc: UInt32
        let size: UInt32
        var nameLen: UInt16 { UInt16(pathBytes.count) }
    }

    private func buildZip(_ entries: [ZipEntry]) -> Data {
        let prepared: [PreparedEntry] = entries.map { e in
            PreparedEntry(
                pathBytes: Data(e.path.utf8),
                data:      e.data,
                crc:       zipCRC32(e.data),
                size:      UInt32(e.data.count)
            )
        }

        var archive = Data()
        var offsets  = [UInt32]()

        for p in prepared {
            offsets.append(UInt32(archive.count))
            archive += pack32(0x04034b50)
            archive += pack16(20)
            archive += pack16(0)
            archive += pack16(0)    // stored
            archive += pack16(0)
            archive += pack16(0)
            archive += pack32(p.crc)
            archive += pack32(p.size)
            archive += pack32(p.size)
            archive += pack16(p.nameLen)
            archive += pack16(0)
            archive += p.pathBytes
            archive += p.data
        }

        let cdOffset = UInt32(archive.count)
        var centralDir = Data()
        for (i, p) in prepared.enumerated() {
            centralDir += pack32(0x02014b50)
            centralDir += pack16(20)
            centralDir += pack16(20)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack32(p.crc)
            centralDir += pack32(p.size)
            centralDir += pack32(p.size)
            centralDir += pack16(p.nameLen)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack16(0)
            centralDir += pack32(0)
            centralDir += pack32(offsets[i])
            centralDir += p.pathBytes
        }

        archive += centralDir

        archive += pack32(0x06054b50)
        archive += pack16(0)
        archive += pack16(0)
        archive += pack16(UInt16(prepared.count))
        archive += pack16(UInt16(prepared.count))
        archive += pack32(UInt32(centralDir.count))
        archive += pack32(cdOffset)
        archive += pack16(0)

        return archive
    }

    private func pack16(_ v: UInt16) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    private func pack32(_ v: UInt32) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    private func zipCRC32(_ data: Data) -> UInt32 {
        let poly: UInt32 = 0xEDB8_8320
        var table = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 { c = (c & 1) == 1 ? poly ^ (c >> 1) : c >> 1 }
            table[n] = c
        }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return ~crc
    }
}
