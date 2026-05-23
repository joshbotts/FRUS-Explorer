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
///   - Cover page: collection title (Heading1), optional collection note
///   - Table of contents: plain list of citation labels
///   - One section per document (page-break-separated): citation heading (Heading2),
///     optional URL paragraph, body text paragraphs, optional research note
///
/// ## ZIP contents
/// ```
/// [Content_Types].xml
/// _rels/.rels
/// word/document.xml
/// word/styles.xml
/// word/_rels/document.xml.rels
/// ```
///
/// Rich inline formatting (bold, italic, footnotes, datelines) is deferred to
/// Session 83. For now `doc.bodyText` is used as the flat-text source; `renderModel`
/// is ignored until the rich pass.
///
/// Version history:
///   1.0 — Session 82: initial implementation; plain-text bodies, cover page, TOC,
///          research notes; stored-mode ZIP writer; five Open XML parts
final class DocxCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        let data = buildDocx(collection: metadata, documents: documents)
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
        documents: [CollectionExportDocument]
    ) -> Data {
        let decl = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
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
                     data: Data((decl + documentXML(collection: collection, documents: documents)).utf8)),
        ]
        return buildZip(entries)
    }

    // MARK: - Open XML Parts

    private func contentTypesXML() -> String {
        let pfx = "http://schemas.openxmlformats.org/package/2006"
        return """
        <Types xmlns="\(pfx)/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml"
            ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/styles.xml"
            ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
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
        let pfx = "http://schemas.openxmlformats.org/package/2006/relationships"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
        return """
        <Relationships xmlns="\(pfx)">
          <Relationship Id="rId1" Type="\(rel)" Target="styles.xml"/>
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
              <w:jc w:val="both"/>
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
        </w:styles>
        """
    }

    private func documentXML(
        collection: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) -> String {
        let w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        var body = ""

        // Cover: title
        body += styledPara(escaped(collection.name), styleId: "Heading1")

        // Cover: optional note
        if let note = collection.note, !note.isEmpty {
            body += styledPara(escaped(note), styleId: "CollectionNote")
        }

        // Table of contents heading + list
        body += styledPara("Contents", styleId: "Heading2")
        for doc in documents {
            let label = doc.citation.isEmpty ? doc.title : doc.citation
            body += styledPara(escaped(label), styleId: "Normal")
        }

        // Page break before document sections
        body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>\n"

        // Document sections
        for doc in documents {
            let heading = doc.citation.isEmpty ? doc.title : doc.citation
            body += styledPara(escaped(heading), styleId: "Heading2")

            if !doc.historyStateGovURL.isEmpty {
                body += styledPara(escaped(doc.historyStateGovURL), styleId: "DocURL")
            }

            // Body text — split on double newline into paragraphs
            let textParagraphs = doc.bodyText
                .components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for para in textParagraphs {
                let text = para
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                body += styledPara(escaped(text), styleId: "Normal")
            }

            // Research note
            if let note = doc.noteText, !note.isEmpty {
                body += researchNoteHeadingPara()
                let noteParagraphs = note
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in noteParagraphs {
                    let text = para
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                    body += styledPara(escaped(text), styleId: "ResearchNote")
                }
            }
        }

        // Required section properties at end of body
        body += "<w:sectPr/>\n"

        return "<w:document xmlns:w=\"\(w)\">\n  <w:body>\n\(body)  </w:body>\n</w:document>"
    }

    // MARK: - XML Element Helpers

    private func styledPara(_ text: String, styleId: String) -> String {
        "    <w:p>\n"
        + "      <w:pPr><w:pStyle w:val=\"\(styleId)\"/></w:pPr>\n"
        + "      <w:r><w:t xml:space=\"preserve\">\(text)</w:t></w:r>\n"
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

        // Local file entries
        for p in prepared {
            offsets.append(UInt32(archive.count))
            archive += pack32(0x04034b50)       // local file header signature
            archive += pack16(20)               // version needed
            archive += pack16(0)                // general purpose bit flag
            archive += pack16(0)                // compression: stored
            archive += pack16(0)                // last mod time
            archive += pack16(0)                // last mod date
            archive += pack32(p.crc)
            archive += pack32(p.size)           // compressed size
            archive += pack32(p.size)           // uncompressed size
            archive += pack16(p.nameLen)
            archive += pack16(0)                // extra field length
            archive += p.pathBytes
            archive += p.data
        }

        // Central directory
        let cdOffset = UInt32(archive.count)
        var centralDir = Data()
        for (i, p) in prepared.enumerated() {
            centralDir += pack32(0x02014b50)    // central directory signature
            centralDir += pack16(20)            // version made by
            centralDir += pack16(20)            // version needed
            centralDir += pack16(0)             // flags
            centralDir += pack16(0)             // stored
            centralDir += pack16(0)             // last mod time
            centralDir += pack16(0)             // last mod date
            centralDir += pack32(p.crc)
            centralDir += pack32(p.size)
            centralDir += pack32(p.size)
            centralDir += pack16(p.nameLen)
            centralDir += pack16(0)             // extra field length
            centralDir += pack16(0)             // file comment length
            centralDir += pack16(0)             // disk number start
            centralDir += pack16(0)             // internal file attributes
            centralDir += pack32(0)             // external file attributes
            centralDir += pack32(offsets[i])    // relative offset of local header
            centralDir += p.pathBytes
        }

        archive += centralDir

        // End of central directory record
        archive += pack32(0x06054b50)
        archive += pack16(0)                          // disk number
        archive += pack16(0)                          // disk where central dir starts
        archive += pack16(UInt16(prepared.count))     // entries on this disk
        archive += pack16(UInt16(prepared.count))     // total entries
        archive += pack32(UInt32(centralDir.count))   // size of central directory
        archive += pack32(cdOffset)                   // offset of central directory
        archive += pack16(0)                          // comment length

        return archive
    }

    private func pack16(_ v: UInt16) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    private func pack32(_ v: UInt32) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    /// CRC-32 using the ZIP polynomial (0xEDB88320), table-based.
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
