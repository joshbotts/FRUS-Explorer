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
///   1.3 — Future (unnumbered): inline highlight annotation. When
///          `options.applyHighlights` is set and `doc.highlights` is non-empty, a
///          `HighlightPaintTracker` is threaded through the body render-node walk
///          (`renderModelToDocxParagraphs` → `blockNodeToDocxXML` →
///          `inlineRunsXML`/`inlineNodeRunXML`); highlighted leaf text
///          (`plainText`/`formulaText`/`lineBreak`) is split into separate `<w:r>`
///          runs at highlight boundaries with `<w:highlight w:val="...">` applied
///          via `runsXML(for:props:tracker:)`. Footnote rendering always passes
///          `tracker: nil` — footnote bodies are outside the flat-text coordinate
///          space (see `appendFlatText`), so highlight offsets never point into them.
///   1.4 — Collections rework Phase 3 (structure): renders the full composed
///          `[CollectionExportItem]` in authored order. Section headings use a new
///          `SectionHeading` style (outline level 0, so the Word field-code TOC lists
///          them); rich-text prose blocks render via `proseDocxXML`, mapping the shared
///          `CollectionProse` spans to bold/italic/underline/`<w:color>` runs. Per-document
///          rendering is factored into `documentSectionXML`.
///   1.5 — Session 2026-07-02 data-loss fix: `proseDocxXML` no longer silently drops a
///          prose block whose payload predates the RTF storage format — the shared
///          `CollectionProse.paragraphs(fromRTF:)` now decodes legacy Phase 3b JSON
///          `AttributedString` blobs (bold/italic preserved) instead of returning `[]`
///   1.6 — Authoring Phase 4 (publication frame): cover gains subtitle/author paragraphs
///          (`CollectionSubtitle`/`CollectionAuthor` styles) when set; authored headings
///          map level → `SectionHeading`/`SectionHeading2`/`SectionHeading3` with
///          `outlineLvl` 0/1/2 — NOT the built-in `Heading2`/`Heading3`, which document
///          citations and in-document TEI headings already use (mapping authored sections
///          onto them would make sections indistinguishable from citations in Word's ToC);
///          the ToC field's `\o` range is content-driven: it stays `"1-2"` (the exact
///          pre-Phase-4 field) unless an authored level-3 section exists, widening to
///          `"1-3"` only then — because `\o` bounds the `\u` outline-level sweep, an
///          unconditional widening would have pulled every in-document TEI heading and
///          "Summary" label (built-in Heading3, outlineLvl 2) into Word's regenerated
///          ToC even for collections using no Phase 4 feature. Residual tradeoff for
///          three-deep collections: authored level-3 sections and in-document TEI
///          headings share ToC level 3 and are indistinguishable there. Opt-in trailing
///          colophon paragraph (`Colophon` style). The introduction needs no code here —
///          it arrives as the resolver's leading `.prose` item
///   1.7 — Authoring Phase 5: opt-in headnote — a labeled paragraph plus italic-run
///          abstract above the body (`headnoteXML`); a requested headnote with no stored
///          summary renders a placeholder note. Footnote rendering here remained ungated
///          (pre-existing behavior — this exporter never consumed the legacy
///          `footnoteStyle`), so untouched collections export byte-identically
///          (gap since closed — see 1.10)
///   1.8 — Authoring Phase 5 (excerpts): `.excerpt` items render as quote-styled
///          paragraphs (`ExcerptQuote`: indented, italic, left accent border) plus an
///          `ExcerptSource` source-citation paragraph. The two styles join `stylesXML`
///          unconditionally — the same dormant-style precedent as the Phase 4 cover
///          styles; an excerpt-free document.xml is unchanged
///   1.9 — Authoring Phase 5 (overrides + related documents): the highlight and
///          research-note gates honor the document's resolved per-entry override
///          (`doc.x ?? options.x` — nil keeps collection behavior bit-for-bit); a
///          non-empty `relatedDocumentCitations` emits a "See also:" paragraph after
///          the source note (existing `DocURL` style — no new dormant style needed).
///          Footnote rendering remained ungated (the pre-existing gap, unchanged —
///          resolved: owner decision 2026-07-03, see 1.10)
///   1.10 — Footnote gate (owner decision 2026-07-03): the body honours
///          `doc.includeFootnotesOverride ?? options.includeFootnotes`, mirroring the
///          shared HTML renderer's semantics exactly — when the flag is `false` no
///          footnote body is registered in `word/footnotes.xml` and no
///          `<w:footnoteReference>` is emitted; inline markers fall back to plain
///          superscript label runs (HTML likewise keeps its `.fn-marker` buttons while
///          dropping the bodies). The default pair for an untouched collection is
///          `(true, false)`, so untouched collections keep exporting byte-identically;
///          legacy `footnoteStyle` values of `none`/`sourceNoteOnly` now suppress
///          footnotes BY DESIGN (they previously rendered them regardless)
///   1.11 — Authoring Phase 6 (generated apparatus): `.generated` items render as a
///          `SectionHeading` title (so Word's field-code ToC lists the block like a
///          section) plus one `GeneratedRow` paragraph per row (gray small-run secondary
///          text; per-row `<w:ind>` for indent levels). Rows with a URL emit a real
///          `<w:hyperlink r:id>` — `DocxRenderContext` allocates hyperlink relationship
///          ids (rId3+) and `documentRelsXML` emits the `TargetMode="External"`
///          relationships; the `xmlns:r` declaration and the extra relationships appear
///          ONLY when a hyperlink exists, so hyperlink-free exports are byte-identical.
///          The `GeneratedRow` + `Hyperlink` styles join `stylesXML` unconditionally —
///          the established dormant-style precedent (v1.8): document.xml is unchanged
///          for collections without blocks
///   1.12 — Authoring Phase 6 review fix: generated-block row text and secondary text
///          run through the `_…_`-to-italic conversion (`markdownItalicRunXML`, the
///          run-level core factored out of `markdownItalicRuns`) — bibliography and
///          chronology rows carry the citation formatter's `_Foreign Relations…_`
///          series title, which HTML/PDF already render as italics; DOCX printed the
///          literal underscores. Applies inside `<w:hyperlink>` too (each run keeps
///          the `Hyperlink` rStyle)
///   1.13 — Session 2026-07-03 (prose links): a prose span carrying a `.link` attribute
///          (the rich-text editor's Link control, RTF `HYPERLINK` field) emits a real
///          `<w:hyperlink r:id>` + `Hyperlink` rStyle through the same
///          `DocxRenderContext` relationship plumbing as v1.11 rows; link-free prose
///          output is byte-identical to 1.12
///   1.14 — Session 2026-07-03 (AI attribution): every rendered generated summary — a
///          `.summaryOnly` body or a filled headnote — is followed by the shared
///          `CollectionAIAttribution` caption paragraph (existing `DocURL` apparatus
///          style, so styles.xml is unchanged); collections rendering no generated
///          summary export byte-identically to 1.13
final class DocxCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        let data = buildDocx(collection: metadata, items: items, options: options)
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
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) -> Data {
        let ctx = DocxRenderContext()
        let decl = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"

        let bodyXML = documentBodyXML(collection: collection, items: items,
                                       ctx: ctx, options: options)
        let wNS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        // The relationships namespace is declared ONLY when a hyperlink run exists
        // (Phase 6 generated-block rows), so hyperlink-free document.xml bytes are
        // unchanged from prior builds.
        let rNSAttr = ctx.hyperlinkURLs.isEmpty
            ? ""
            : " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\""
        let docXML = "<w:document xmlns:w=\"\(wNS)\"\(rNSAttr)>\n  <w:body>\n\(bodyXML)  </w:body>\n</w:document>"

        let entries: [ZipEntry] = [
            ZipEntry(path: "[Content_Types].xml",
                     data: Data((decl + contentTypesXML()).utf8)),
            ZipEntry(path: "_rels/.rels",
                     data: Data((decl + rootRelsXML()).utf8)),
            ZipEntry(path: "word/_rels/document.xml.rels",
                     data: Data((decl + documentRelsXML(hyperlinkURLs: ctx.hyperlinkURLs)).utf8)),
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

    /// Builds `word/_rels/document.xml.rels`. Beyond the fixed styles/footnotes parts,
    /// one external-hyperlink relationship is emitted per URL collected by the render
    /// context (Phase 6 generated-block rows), ids `rId3`+ in first-use order — matching
    /// the ids `DocxRenderContext.hyperlinkRelId(for:)` handed out during body rendering.
    /// With no hyperlinks the output is byte-identical to the pre-Phase-6 part.
    private func documentRelsXML(hyperlinkURLs: [String] = []) -> String {
        let pfx  = "http://schemas.openxmlformats.org/package/2006/relationships"
        let oxml = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        var rels = """
        <Relationships xmlns="\(pfx)">
          <Relationship Id="rId1" Type="\(oxml)/styles"    Target="styles.xml"/>
          <Relationship Id="rId2" Type="\(oxml)/footnotes" Target="footnotes.xml"/>
        """
        for (index, url) in hyperlinkURLs.enumerated() {
            rels += "\n  <Relationship Id=\"rId\(3 + index)\" Type=\"\(oxml)/hyperlink\" "
                + "Target=\"\(xmlEscaped(url))\" TargetMode=\"External\"/>"
        }
        rels += "\n</Relationships>"
        return rels
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
          <w:style w:type="paragraph" w:styleId="SectionHeading">
            <w:name w:val="Section Heading"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:pBdr><w:bottom w:val="single" w:sz="6" w:space="4" w:color="999999"/></w:pBdr>
              <w:spacing w:before="480" w:after="160"/>
              <w:outlineLvl w:val="0"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="36"/><w:szCs w:val="36"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="SectionHeading2">
            <w:name w:val="Section Heading 2"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:spacing w:before="360" w:after="120"/>
              <w:outlineLvl w:val="1"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="SectionHeading3">
            <w:name w:val="Section Heading 3"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:spacing w:before="240" w:after="80"/>
              <w:outlineLvl w:val="2"/>
            </w:pPr>
            <w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="CollectionSubtitle">
            <w:name w:val="Collection Subtitle"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="80"/></w:pPr>
            <w:rPr><w:sz w:val="32"/><w:szCs w:val="32"/><w:color w:val="333333"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="CollectionAuthor">
            <w:name w:val="Collection Author"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="160"/></w:pPr>
            <w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/><w:color w:val="555555"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="Colophon">
            <w:name w:val="Colophon"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:pBdr><w:top w:val="single" w:sz="4" w:space="8" w:color="DDDDDD"/></w:pBdr>
              <w:spacing w:before="480"/>
            </w:pPr>
            <w:rPr><w:sz w:val="16"/><w:szCs w:val="16"/><w:color w:val="777777"/></w:rPr>
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
          <w:style w:type="paragraph" w:styleId="ExcerptQuote">
            <w:name w:val="Excerpt Quote"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:pBdr><w:left w:val="single" w:sz="12" w:space="8" w:color="8A8A86"/></w:pBdr>
              <w:ind w:left="360" w:right="360"/>
              <w:spacing w:before="160" w:after="80"/>
            </w:pPr>
            <w:rPr><w:i/><w:color w:val="333333"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="ExcerptSource">
            <w:name w:val="Excerpt Source"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr>
              <w:ind w:left="360" w:right="360"/>
              <w:spacing w:after="160"/>
            </w:pPr>
            <w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="555555"/></w:rPr>
          </w:style>
          <w:style w:type="paragraph" w:styleId="GeneratedRow">
            <w:name w:val="Generated Row"/>
            <w:basedOn w:val="Normal"/>
            <w:pPr><w:spacing w:after="60"/></w:pPr>
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
          <w:style w:type="character" w:styleId="Hyperlink">
            <w:name w:val="Hyperlink"/>
            <w:basedOn w:val="DefaultParagraphFont"/>
            <w:rPr><w:color w:val="1A4C8F"/><w:u w:val="single"/></w:rPr>
          </w:style>
        </w:styles>
        """
    }

    // MARK: - Document Body

    private func documentBodyXML(
        collection: CollectionExportMetadata,
        items: [CollectionExportItem],
        ctx: DocxRenderContext,
        options: CollectionExportOptions
    ) -> String {
        var body = ""
        let documents = items.documents

        // Cover: collection title
        body += styledPara(escaped(collection.name), styleId: "Heading1")

        // Cover: title-page subtitle and author paragraphs (Authoring Phase 4) — emitted
        // only when set, so an unset collection's cover is unchanged.
        if let subtitle = collection.subtitle, !subtitle.isEmpty {
            body += markdownItalicRuns(subtitle, styleId: "CollectionSubtitle")
        }
        if let author = collection.authorLine, !author.isEmpty {
            body += styledPara(escaped(author), styleId: "CollectionAuthor")
        }

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

        // Contents heading + Word TOC field code (updates on first open in Word). The
        // field's `\o` level range is content-driven: `"1-2"` (the exact pre-Phase-4
        // field) unless an authored level-3 section exists, so a collection using no
        // deep nesting keeps today's ToC — in particular, in-document TEI headings and
        // "Summary" labels (built-in Heading3, outline level 2) stay out of Word's
        // regenerated contents.
        let maxHeadingLevel = items.reduce(into: 1) { acc, item in
            if case .heading(_, let level) = item {
                acc = max(acc, min(max(level, 1), CollectionOutline.maxLevel))
            }
        }
        body += styledPara("Contents", styleId: "Heading2")
        body += tocFieldXML(maxHeadingLevel: maxHeadingLevel)

        // Page break before the composed body
        body += "    <w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>\n"

        // Composed items — documents, section headings, and prose blocks in authored order.
        for item in items {
            switch item {
            case .heading(let text, let level):
                // markdownItalicRuns handles _text_ spans; the SectionHeading styles are
                // bold. Levels map to SectionHeading/SectionHeading2/SectionHeading3
                // (outlineLvl 0/1/2 — see the v1.6 note for why not built-in Heading2/3),
                // so Word's regenerated ToC picks up the authored hierarchy.
                let styles = ["SectionHeading", "SectionHeading2", "SectionHeading3"]
                let l = min(max(level, 1), CollectionOutline.maxLevel)
                body += markdownItalicRuns(text, styleId: styles[l - 1], bold: true)
            case .prose(let rtf):
                body += proseDocxXML(rtf, ctx: ctx)
            case .excerpt(let excerpt):
                body += excerptDocxXML(excerpt)
            case .generated(let block):
                body += generatedDocxXML(block, ctx: ctx)
            case .document(let doc):
                body += documentSectionXML(doc: doc, ctx: ctx, options: options)
            }
        }

        // Trailing colophon paragraph (Authoring Phase 4) — opt-in only.
        if collection.includeColophon {
            body += styledPara(escaped(CollectionColophon.text(for: items)), styleId: "Colophon")
        }

        body += "    <w:sectPr/>\n"
        return body
    }

    /// Renders one document entry as Word paragraphs: citation heading, source URL, body
    /// (rich when a render model is present, flat-text fallback otherwise), source note, and
    /// research notes. Body depth and footnote/highlight/notes options are honoured per entry.
    private func documentSectionXML(
        doc: CollectionExportDocument,
        ctx: DocxRenderContext,
        options: CollectionExportOptions
    ) -> String {
        var body = ""

        // Section heading: the per-entry `titleOverride` when set, else the citation (M3,
        // centralized via `exportHeading`); markdownItalicRuns handles _text_.
        let heading = doc.exportHeading
        body += markdownItalicRuns(heading, styleId: "Heading2", bold: true)

        if !doc.historyStateGovURL.isEmpty {
            body += styledPara(escaped(doc.historyStateGovURL), styleId: "DocURL")
        }

        // Headnote (Authoring Phase 5) — a labeled italic abstract above the body; a
        // requested headnote with no stored summary renders the placeholder note
        // (headnote resolution never generates on demand).
        if doc.includeHeadnote {
            body += headnoteXML(doc.headnoteText)
        }

        // Body — controlled by doc.bodyDepth (per-entry effective depth).
        switch doc.bodyDepth {
        case .full:
            if let model = doc.renderModel {
                // Highlight offsets are flat-text positions over the render
                // model's body nodes (see `ExportHighlight`); the plain
                // `bodyText` paragraph-splitting fallback below uses a
                // different extraction path, so painting only applies here.
                // Phase 5: the per-entry/section override when resolved, else the
                // collection-level option.
                let applyHighlights = doc.applyHighlightsOverride ?? options.applyHighlights
                // Footnote gate (owner decision 2026-07-03): mirrors the shared HTML
                // renderer — `false` drops footnote bodies, markers stay as labels.
                let includeFootnotes = doc.includeFootnotesOverride ?? options.includeFootnotes
                let tracker: HighlightPaintTracker? =
                    (applyHighlights && !doc.highlights.isEmpty)
                        ? HighlightPaintTracker(doc.highlights)
                        : nil
                body += renderModelToDocxParagraphs(model, ctx: ctx, tracker: tracker,
                                                    includeFootnotes: includeFootnotes)
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
                // AI attribution (v1.14): generated text is always labeled in exports —
                // a caption paragraph in the existing DocURL apparatus style, so
                // styles.xml is unchanged.
                body += styledPara(escaped(CollectionAIAttribution.label()),
                                   styleId: "DocURL")
            }
        case .index:
            break
        }

        // Source note (options.includeSourceNote)
        if let sourceNote = doc.sourceNoteText, !sourceNote.isEmpty {
            body += styledPara("Source: \(escaped(sourceNote))", styleId: "DocURL")
        }

        // Related documents (A10, Authoring Phase 5): the pre-resolved in-collection
        // "See also:" citations; empty (every untouched entry) emits nothing. Reuses
        // the DocURL apparatus style, so styles.xml is unchanged.
        if !doc.relatedDocumentCitations.isEmpty {
            let label = String(localized: "collection.related.label", defaultValue: "See also:")
            let joined = doc.relatedDocumentCitations.joined(separator: "; ")
            body += markdownItalicRuns("\(label) \(joined)", styleId: "DocURL")
        }

        // Research notes — the per-entry override when resolved, else options.includeNotes.
        guard doc.includeNotesOverride ?? options.includeNotes else { return body }
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
        return body
    }

    /// Renders a rich-text prose block (RTF, or a legacy Phase 3b JSON blob the shared
    /// decoder recovers rather than dropping) to Word paragraph XML. Bold/italic/
    /// underline/colour spans (decoded once by `CollectionProse`) map to `<w:r>` run
    /// properties; a span carrying a link URL is wrapped in a real `<w:hyperlink r:id>`
    /// whose external relationship is allocated by `ctx` (Session 2026-07-03 — the same
    /// Phase 6 plumbing generated-block rows use); blank lines split paragraphs; single
    /// newlines within a paragraph become `<w:br/>`. Empty (whitespace-only) paragraphs
    /// are dropped.
    private func proseDocxXML(_ rtf: Data, ctx: DocxRenderContext) -> String {
        let paragraphs = CollectionProse.paragraphs(fromRTF: rtf)
        guard !paragraphs.isEmpty else { return "" }
        var xml = ""
        for paragraph in paragraphs {
            var runs = ""
            for span in paragraph {
                let runXML = proseRunXML(span)
                guard !runXML.isEmpty else { continue }
                if let url = span.linkURL, !url.isEmpty {
                    runs += "<w:hyperlink r:id=\"\(ctx.hyperlinkRelId(for: url))\">"
                        + runXML + "</w:hyperlink>"
                } else {
                    runs += runXML
                }
            }
            guard !runs.isEmpty else { continue }
            xml += wPara(runs: runs, styleId: "Normal")
        }
        return xml
    }

    /// Builds the `<w:r>` run(s) for one prose span, applying bold/italic/underline/colour
    /// (plus the `Hyperlink` character style for linked spans) and splitting on single
    /// newlines so each intra-paragraph break becomes a `<w:br/>`.
    private func proseRunXML(_ span: ProseFormattedSpan) -> String {
        // Emit run properties in CT_RPr schema order (rStyle first; color precedes
        // underline) so the output validates strictly, not just in lenient consumers
        // like Word/Pages.
        var props = ""
        if let url = span.linkURL, !url.isEmpty { props += "<w:rStyle w:val=\"Hyperlink\"/>" }
        if span.bold      { props += "<w:b/>" }
        if span.italic    { props += "<w:i/>" }
        if let hex = span.colorHex { props += "<w:color w:val=\"\(hex)\"/>" }
        if span.underline { props += "<w:u w:val=\"single\"/>" }
        let rPr = props.isEmpty ? "" : "<w:rPr>\(props)</w:rPr>"

        let parts = span.text.components(separatedBy: "\n")
        var runs = ""
        for (index, part) in parts.enumerated() {
            if index > 0 { runs += "<w:r>\(rPr)<w:br/></w:r>" }
            if !part.isEmpty {
                runs += "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(xmlEscaped(part))</w:t></w:r>"
            }
        }
        return runs
    }

    /// Renders an excerpt item (Authoring Phase 5): the frozen passage as `ExcerptQuote`
    /// paragraphs (blank lines split paragraphs, single newlines become `<w:br/>` —
    /// verbatim primary-source text, so no markdown transforms), followed by an
    /// `ExcerptSource` paragraph carrying "— citation" (the citation runs through
    /// `markdownItalicRuns` so `_…_` spans render as italics). An empty citation omits
    /// the source paragraph.
    private func excerptDocxXML(_ excerpt: CollectionExportExcerpt) -> String {
        var xml = ""
        let paragraphs = excerpt.text
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for para in paragraphs {
            let parts = para.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            var runs = ""
            for (index, part) in parts.enumerated() {
                if index > 0 { runs += "<w:r><w:br/></w:r>" }
                if !part.isEmpty {
                    runs += "<w:r><w:t xml:space=\"preserve\">\(xmlEscaped(part))</w:t></w:r>"
                }
            }
            guard !runs.isEmpty else { continue }
            xml += wPara(runs: runs, styleId: "ExcerptQuote")
        }
        if !excerpt.citation.isEmpty {
            xml += markdownItalicRuns("\u{2014} \(excerpt.citation)", styleId: "ExcerptSource")
        }
        return xml
    }

    /// Renders a generated apparatus block (Authoring Phase 6): the block title as a
    /// `SectionHeading` paragraph (outline level 0, so Word's field-code ToC lists it
    /// like an authored section), then one `GeneratedRow` paragraph per row — the row
    /// text (wrapped in a real `<w:hyperlink>` when the row carries a URL), an optional
    /// gray small-run secondary text, and a per-row `<w:ind>` for indent levels.
    private func generatedDocxXML(_ block: CollectionGeneratedBlock,
                                  ctx: DocxRenderContext) -> String {
        var xml = markdownItalicRuns(block.title, styleId: "SectionHeading", bold: true)
        for row in block.rows {
            // Row text and secondary text run through the run-level `_…_` conversion:
            // bibliography/chronology rows carry the citation formatter's italicized
            // series title, which every other format renders as italics — DOCX must
            // not print the literal underscores (Phase 6 review fix).
            var runs = ""
            if let url = row.url, !url.isEmpty {
                let relId = ctx.hyperlinkRelId(for: url)
                runs += "<w:hyperlink r:id=\"\(relId)\">"
                    + markdownItalicRunXML(row.text, baseRPr: "<w:rStyle w:val=\"Hyperlink\"/>")
                    + "</w:hyperlink>"
            } else {
                runs += markdownItalicRunXML(row.text)
            }
            if let secondary = row.secondaryText, !secondary.isEmpty {
                runs += markdownItalicRunXML(
                    "  \(secondary)",
                    baseRPr: "<w:color w:val=\"555555\"/><w:sz w:val=\"18\"/><w:szCs w:val=\"18\"/>")
            }
            let indent = min(max(row.indentLevel, 0), 4)
            let ind = indent > 0 ? "<w:ind w:left=\"\(indent * 360)\"/>" : ""
            xml += "    <w:p>\n"
                + "      <w:pPr><w:pStyle w:val=\"GeneratedRow\"/>\(ind)</w:pPr>\n"
                + "      \(runs)\n"
                + "    </w:p>\n"
        }
        return xml
    }

    // MARK: - Rich Rendering (Session 83)

    // Context object that tracks footnote IDs, collects footnote XML, and allocates
    // external-hyperlink relationship ids across all documents in one export run.
    // Created fresh per buildDocx call.
    private final class DocxRenderContext {
        private(set) var nextId = 1
        private(set) var footnoteXMLs: [String] = []
        /// External hyperlink targets in first-use order; index `i` is relationship
        /// `rId(3 + i)` (rId1/rId2 are the fixed styles/footnotes parts).
        private(set) var hyperlinkURLs: [String] = []

        func allocate() -> Int {
            defer { nextId += 1 }
            return nextId
        }

        func addFootnote(_ xml: String) {
            footnoteXMLs.append(xml)
        }

        /// Returns the relationship id for an external hyperlink target, allocating a
        /// new one (`rId3`+) on first use and reusing it for repeated URLs. The matching
        /// `<Relationship TargetMode="External">` entries are emitted by
        /// `documentRelsXML(hyperlinkURLs:)` after body rendering completes.
        func hyperlinkRelId(for url: String) -> String {
            if let index = hyperlinkURLs.firstIndex(of: url) {
                return "rId\(3 + index)"
            }
            hyperlinkURLs.append(url)
            return "rId\(3 + hyperlinkURLs.count - 1)"
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
    ///
    /// - Parameters:
    ///   - tracker: When non-`nil`, highlight ranges are painted onto
    ///     body text via `<w:highlight>` runs as flat-text leaf content is emitted.
    ///     Always passed as `nil` into footnote rendering — footnote bodies fall
    ///     outside the flat-text coordinate space (`appendFlatText` only walks
    ///     `model.bodyNodes`), so highlight offsets never point into them.
    ///   - includeFootnotes: When `false` (owner decision 2026-07-03), no footnote
    ///     body is registered with `ctx` and the label map stays empty, so inline
    ///     markers fall back to plain superscript label runs instead of
    ///     `<w:footnoteReference>` — matching the shared HTML renderer, which keeps
    ///     markers while dropping the footnote bodies.
    private func renderModelToDocxParagraphs(
        _ model: FRUSDocumentRenderModel,
        ctx: DocxRenderContext,
        tracker: HighlightPaintTracker? = nil,
        includeFootnotes: Bool = true
    ) -> String {
        // Pre-assign Word integer IDs to every footnote in this document. Skipped when
        // footnotes are gated off — an empty map routes every marker to the
        // superscript-label fallback and nothing references word/footnotes.xml.
        var labelMap: [String: Int] = [:]
        if includeFootnotes {
            for note in model.footnotes {
                if case .footnoteBody(_, _, _, _, let label, _) = note {
                    labelMap[label] = ctx.allocate()
                }
            }
        }

        // Render body paragraphs
        let bodyXML = model.bodyNodes
            .map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }
            .joined()

        // Render footnote bodies and register with context — tracker: nil (see above).
        // With footnotes gated off the map is empty, so nothing registers.
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
    ///
    /// - Parameter tracker: Threaded through to inline-run rendering so highlight
    ///   spans can be painted onto leaf text. `nil` for footnote-body rendering.
    private func blockNodeToDocxXML(_ node: FRUSRenderNode, labelMap: [String: Int],
                                     tracker: HighlightPaintTracker? = nil) -> String {
        switch node {
        case .heading(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap, tracker: tracker),
                         styleId: "Heading3")
        case .dateline(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(italic: true), labelMap: labelMap, tracker: tracker),
                         styleId: "Dateline")
        case .salutation(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap, tracker: tracker),
                         styleId: "Normal")
        case .paragraph(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap, tracker: tracker),
                         styleId: "Normal")
        case .letterOpener(let c), .letterCloser(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }.joined()
        case .editorialNoteBlock(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }.joined()
        case .attachmentBlock(_, let c):
            let sep = "    <w:p><w:pPr><w:pBdr><w:top w:val=\"single\" w:sz=\"6\" w:space=\"1\"/></w:pBdr></w:pPr></w:p>\n"
            return sep + c.map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }.joined()
        case .attachmentHeading(let c):
            return wPara(runs: inlineRunsXML(c, props: RunProps(), labelMap: labelMap, tracker: tracker),
                         styleId: "AttachmentHeading")
        case .titlePageBlock(let c):
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }.joined()
        case .tableBlock(let rows):
            return tableToDocxXML(rows, labelMap: labelMap, tracker: tracker)
        case .listBlock(let type, let items):
            return items.enumerated().map { (i, item) in
                let bullet = (type == "ordered") ? "\(i + 1). " : "• "
                let bulletRun = "<w:r><w:t xml:space=\"preserve\">\(bullet)</w:t></w:r>"
                let runs = inlineRunsXML(item, props: RunProps(), labelMap: labelMap, tracker: tracker)
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
            return c.map { blockNodeToDocxXML($0, labelMap: labelMap, tracker: tracker) }.joined()
        default:
            // Inline node at block level — wrap in Normal paragraph
            return wPara(runs: inlineNodeRunXML(node, props: RunProps(), labelMap: labelMap, tracker: tracker),
                         styleId: "Normal")
        }
    }

    private func inlineRunsXML(_ nodes: [FRUSRenderNode], props: RunProps,
                                labelMap: [String: Int], tracker: HighlightPaintTracker? = nil) -> String {
        nodes.map { inlineNodeRunXML($0, props: props, labelMap: labelMap, tracker: tracker) }.joined()
    }

    /// Converts an inline render node to `<w:r>` run XML.
    ///
    /// - Parameter tracker: When non-`nil`, leaf content that contributes to the
    ///   flat-text coordinate space (`.plainText`, `.formulaText`, `.lineBreak`)
    ///   is split into separate runs at highlight boundaries via `runsXML(for:props:tracker:)`,
    ///   each carrying a `<w:highlight w:val="...">` when it falls within a highlight.
    ///   All other leaf/container cases simply thread `tracker` through unchanged.
    private func inlineNodeRunXML(_ node: FRUSRenderNode, props: RunProps,
                                   labelMap: [String: Int], tracker: HighlightPaintTracker? = nil) -> String {
        switch node {
        case .plainText(let s):
            guard !s.isEmpty else { return "" }
            return runsXML(for: s, props: props, tracker: tracker)
        case .boldText(let c):
            return inlineRunsXML(c, props: props.adding(bold: true), labelMap: labelMap, tracker: tracker)
        case .italicText(let c):
            return inlineRunsXML(c, props: props.adding(italic: true), labelMap: labelMap, tracker: tracker)
        case .smallCapsText(let c):
            return inlineRunsXML(c, props: props.adding(smallCaps: true), labelMap: labelMap, tracker: tracker)
        case .underlineText(let c):
            return inlineRunsXML(c, props: props.adding(underline: true), labelMap: labelMap, tracker: tracker)
        case .sicText(let c):
            return inlineRunsXML(c, props: props.adding(strike: true), labelMap: labelMap, tracker: tracker)
        case .suppliedText(let c):
            let rpr = props.rPrXML()
            let open  = "<w:r>\(rpr)<w:t>[</w:t></w:r>"
            let inner = inlineRunsXML(c, props: props, labelMap: labelMap, tracker: tracker)
            let close = "<w:r>\(rpr)<w:t>]</w:t></w:r>"
            return open + inner + close
        case .formulaText(let s):
            let ip = props.adding(italic: true)
            return runsXML(for: s, props: ip, tracker: tracker)
        case .lineBreak:
            // Advance the flat-position counter (the HTML serializer counts "\n"
            // for line breaks) without emitting a highlight — a bare <w:br/>
            // cannot itself be shaded, so we just keep offsets aligned.
            _ = tracker?.partition("\n")
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
            return inlineRunsXML(c, props: props, labelMap: labelMap, tracker: tracker)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, let c):
            return inlineRunsXML(c, props: props, labelMap: labelMap, tracker: tracker)
        case .pageBreak:
            return ""
        case .unknown(_, let c):
            return inlineRunsXML(c, props: props, labelMap: labelMap, tracker: tracker)
        default:
            return "" // Block nodes in inline context: not expected in FRUS inline runs
        }
    }

    /// Splits `text` into one or more `<w:r>` runs at highlight boundaries, applying
    /// `<w:highlight w:val="...">` to spans that fall within an `ExportHighlight`.
    /// When `tracker` is `nil` or inactive, emits a single run with no highlight markup
    /// (preserving the exact prior output for non-highlighted exports).
    private func runsXML(for text: String, props: RunProps, tracker: HighlightPaintTracker?) -> String {
        guard !text.isEmpty else { return "" }
        guard let tracker, tracker.isActive else {
            return "<w:r>\(props.rPrXML())<w:t xml:space=\"preserve\">\(xmlEscaped(text))</w:t></w:r>"
        }
        var xml = ""
        for (range, color) in tracker.partition(text) {
            let chunk = String(text[range])
            guard !chunk.isEmpty else { continue }
            let rPr = highlightedRPrXML(props: props, color: color)
            xml += "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(xmlEscaped(chunk))</w:t></w:r>"
        }
        return xml
    }

    /// Builds `<w:rPr>` XML combining `props`' formatting flags with an optional
    /// `<w:highlight w:val="...">` element for the given highlight color.
    private func highlightedRPrXML(props: RunProps, color: DocumentHighlight.Color?) -> String {
        var inner = ""
        if props.bold      { inner += "<w:b/>" }
        if props.italic    { inner += "<w:i/>" }
        if props.smallCaps { inner += "<w:smallCaps/>" }
        if props.underline { inner += "<w:u w:val=\"single\"/>" }
        if props.strike    { inner += "<w:strike/>" }
        if let color { inner += "<w:highlight w:val=\"\(color.ooxmlHighlightName)\"/>" }
        return inner.isEmpty ? "" : "<w:rPr>\(inner)</w:rPr>"
    }

    private func tableToDocxXML(_ rows: [[TableCell]], labelMap: [String: Int],
                                 tracker: HighlightPaintTracker? = nil) -> String {
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
                let runs = inlineRunsXML(cell.children, props: RunProps(), labelMap: labelMap, tracker: tracker)
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

    /// Word field-code TOC. The `\o` level range bounds what the ToC collects (it caps
    /// the `\u` outline-level sweep the way Word's Show-levels control does): `"1-2"` —
    /// the exact pre-Phase-4 field — unless an authored level-3 section exists, in which
    /// case it widens to `"1-3"` so the three-deep outline is representable. Level-2
    /// sections need no widening: `SectionHeading2` carries `outlineLvl` 1, inside
    /// `"1-2"`. The `\u` switch collects the custom
    /// `SectionHeading`/`SectionHeading2`/`SectionHeading3` styles by their `outlineLvl`.
    /// `w:dirty="true"` causes Word to rebuild on first open.
    ///
    /// - Parameter maxHeadingLevel: The deepest clamped authored heading level in the
    ///   export (1 when the collection has no headings).
    private func tocFieldXML(maxHeadingLevel: Int) -> String {
        let range = maxHeadingLevel >= 3 ? "1-3" : "1-2"
        return "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\n"
        + "      <w:r><w:fldChar w:fldCharType=\"begin\" w:dirty=\"true\"/></w:r>\n"
        + "      <w:r><w:instrText xml:space=\"preserve\"> TOC \\o \"\(range)\" \\h \\z \\u </w:instrText></w:r>\n"
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
        let runs = markdownItalicRunXML(text, baseRPr: bold ? "<w:b/>" : "")
        return runs.isEmpty
            ? styledPara("", styleId: styleId)
            : wPara(runs: runs, styleId: styleId)
    }

    /// The run-level core of `markdownItalicRuns` (Authoring Phase 6 review fix): emits
    /// alternating normal / italic `<w:r>` runs for `_span_` markers, with **no**
    /// enclosing `<w:p>` — for renderers that assemble their own paragraphs from
    /// multiple run groups (the generated-block rows, whose citations carry the
    /// formatter's `_Foreign Relations…_` series-title markers).
    ///
    /// - Parameters:
    ///   - text: Raw (un-escaped) source text with optional `_span_` markers.
    ///   - baseRPr: Run-property XML applied to every run (e.g. `<w:b/>`, a
    ///     `<w:rStyle w:val="Hyperlink"/>`, or the secondary-text colour/size pair);
    ///     italic spans append `<w:i/>` after it.
    /// - Returns: The run XML; empty when `text` is empty.
    private func markdownItalicRunXML(_ text: String, baseRPr: String = "") -> String {
        guard let regex = try? NSRegularExpression(pattern: "_([^_\\n]+)_") else {
            return "<w:r><w:rPr>\(baseRPr)</w:rPr><w:t xml:space=\"preserve\">\(xmlEscaped(text))</w:t></w:r>"
        }
        let ns = text as NSString
        let length = ns.length
        var runs = ""
        var lastEnd = 0

        for match in regex.matches(in: text, range: NSRange(location: 0, length: length)) {
            // Normal run before the italic span
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            if beforeRange.length > 0 {
                let chunk = xmlEscaped(ns.substring(with: beforeRange))
                runs += "<w:r><w:rPr>\(baseRPr)</w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
            }
            // Italic run for the matched span content
            let g1 = match.range(at: 1)
            if g1.location != NSNotFound, g1.length > 0 {
                let chunk = xmlEscaped(ns.substring(with: g1))
                runs += "<w:r><w:rPr>\(baseRPr)<w:i/></w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
            }
            lastEnd = match.range.upperBound
        }
        // Trailing normal run
        if lastEnd < length {
            let chunk = xmlEscaped(ns.substring(from: lastEnd))
            runs += "<w:r><w:rPr>\(baseRPr)</w:rPr><w:t xml:space=\"preserve\">\(chunk)</w:t></w:r>"
        }
        return runs
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

    /// Emits the headnote block (Authoring Phase 5): a small bold "Headnote" label
    /// paragraph followed by the abstract in italic runs — or, when `text` is nil/empty
    /// (a requested headnote with no stored summary), the italic placeholder note.
    /// Paragraph breaks in the abstract split into separate paragraphs.
    private func headnoteXML(_ text: String?) -> String {
        let label = String(localized: "collection.headnote.label", defaultValue: "Headnote")
        var xml = wPara(
            runs: "<w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">\(escaped(label))</w:t></w:r>",
            styleId: "Normal")
        let content: String
        if let text, !text.isEmpty {
            content = text
        } else {
            content = String(localized: "collection.headnote.missing",
                             defaultValue: "No stored summary for this document — generate one in the document view to fill this headnote.")
        }
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for para in paragraphs {
            let flattened = para
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            xml += wPara(
                runs: "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">\(escaped(flattened))</w:t></w:r>",
                styleId: "Normal")
        }
        // AI attribution (v1.14) — a filled headnote is a stored GeneratedSummary, so
        // it carries the same caption as a summary body (DocURL apparatus style; no
        // styles.xml change). The placeholder renders no AI text and no attribution.
        if let text, !text.isEmpty {
            xml += styledPara(escaped(CollectionAIAttribution.label()), styleId: "DocURL")
        }
        return xml
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
