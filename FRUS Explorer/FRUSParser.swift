// MARK: - FRUSParser
// Parses a FRUS TEI XML file into the typed model defined in Models.swift.

import Foundation

/// Errors that can be thrown during parsing.
public enum FRUSParserError: Error, LocalizedError {
    case fileNotFound(URL)
    case xmlParseError(Error)
    case missingRootElement
    case missingBody
    case malformedHeader(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at \(url.path)"
        case .xmlParseError(let err):
            return "XML parse error: \(err.localizedDescription)"
        case .missingRootElement:
            return "No <TEI> root element found"
        case .missingBody:
            return "<body> element is required but was missing"
        case .malformedHeader(let msg):
            return "Malformed teiHeader: \(msg)"
        }
    }
}

/// Entry point for parsing FRUS volumes.
///
/// ```swift
/// let parser = FRUSParser()
/// let volume = try parser.parse(url: fileURL)
/// print(volume.id)
/// for doc in volume.body.documents {
///     print(doc.headings.first?.plainText ?? "(untitled)")
/// }
/// ```
public final class FRUSParser: Sendable {
    public nonisolated init() {}

    /// Parse a FRUS volume from a file URL.
    public nonisolated func parse(url: URL) throws -> FRUSVolume {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FRUSParserError.fileNotFound(url)
        }
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse a FRUS volume from raw XML `Data`.
    public nonisolated func parse(data: Data) throws -> FRUSVolume {
        let delegate = ParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        xmlParser.shouldProcessNamespaces = true
        xmlParser.shouldReportNamespacePrefixes = false

        guard xmlParser.parse() else {
            if let err = xmlParser.parserError {
                throw FRUSParserError.xmlParseError(err)
            }
            throw FRUSParserError.xmlParseError(
                NSError(domain: "FRUSKit", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown XML parse failure"])
            )
        }

        guard let volume = delegate.result else {
            throw FRUSParserError.missingRootElement
        }
        return volume
    }
}

// MARK: - Internal SAX Delegate

/// SAX-style delegate that builds the model incrementally.
private final class ParserDelegate: NSObject, @preconcurrency XMLParserDelegate {

    // nonisolated(unsafe): ParserDelegate is created and used exclusively within
    // a single synchronous parse() call — no concurrent access occurs.
    nonisolated(unsafe) var result: FRUSVolume?

    nonisolated override init() { super.init() }

    // ── Parsing state ──────────────────────────────────────────────────────

    private var elementStack: [String] = []
    private var attrStack: [[String: String]] = []
    private var charBuf = ""

    // Top-level accumulators
    private var volumeID = ""

    // teiHeader accumulators
    private var inHeader = false
    private var titles: [Title] = []
    private var editors: [Editor] = []
    private var principals: [ResponsibilityStatement] = []
    private var respStmts: [ResponsibilityStatement] = []
    private var publisher: String?
    private var pubPlace: String?
    private var pubDate: String?
    private var idnos: [Identifier] = []
    private var availability: String?
    private var projectDesc: String?
    private var editorialDecls: [String] = []
    private var languages: [Language] = []
    private var keywords: [String] = []
    private var personRecords: [PersonRecord] = []
    private var changes: [Change] = []

    // Current sub-element state
    private var currentTitle: (level: String?, type: String?, lang: String?)?
    private var currentEditor: String?
    private var currentEditorRole: String?
    private var currentIdnoType: String?
    private var currentPersonID: String?
    private var currentPersonNames: [String] = []
    private var currentPersonNotes: [String] = []
    private var currentChangeWhen: String?
    private var currentChangeWho: String?
    private var inRespStmt = false
    private var respStmtResp: String?
    private var respStmtNames: [String] = []

    // text / front / back / body
    private var inText = false
    private var inFront = false
    private var inBack = false
    private var inBody = false

    // Division stack (body, front, back all produce Division trees)
    private var divStack: [DivAccumulator] = []

    // Inline content stack
    private var inlineStack: [InlineAccumulator] = []

    // Current note (footnote / editorial note)
    private var noteStack: [NoteAccumulator] = []

    // Staging buffers for list item and table row/cell content.
    // The SAX model closes child elements before parents, so when "list" closes
    // the item content arrays are already captured here, indexed by the sentinel
    // stored in the parent's inline accumulator.
    private var pendingListItemContents: [[InlineContent]] = []
    private var pendingRowContents: [[InlineContent]] = []
    private var pendingRowRoles: [String?] = []
    private var pendingCellContents: [[InlineContent]] = []

    // ── XML Delegate Methods ───────────────────────────────────────────────

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        attrStack.append(attributeDict)
        let attrs = attributeDict
        charBuf = ""

        switch elementName {

        // ── Root ────────────────────────────────────────────────────────
        case "TEI":
            volumeID = xmlID(attrs) ?? ""

        // ── teiHeader ───────────────────────────────────────────────────
        case "teiHeader":
            inHeader = true

        case "title":
            if inHeader {
                currentTitle = (level: attrs["level"], type: attrs["type"], lang: attrs["xml:lang"])
            }
        case "editor":
            if inHeader {
                currentEditor = nil
                currentEditorRole = attrs["role"]
            }
        case "principal":
            if inHeader { inRespStmt = true; respStmtResp = "principal"; respStmtNames = [] }
        case "respStmt":
            if inHeader { inRespStmt = true; respStmtResp = nil; respStmtNames = [] }
        case "resp":
            break // captured in charBuf
        case "name":
            break // captured in charBuf
        case "idno":
            currentIdnoType = attrs["type"]
        case "langUsage":
            break
        case "language":
            if inHeader {
                let ident = attrs["ident"] ?? attrs["xml:lang"] ?? ""
                languages.append(Language(ident: ident, description: nil))
            }
        case "person":
            currentPersonID = xmlID(attrs)
            currentPersonNames = []
            currentPersonNotes = []
        case "change":
            currentChangeWhen = attrs["when"]
            currentChangeWho = attrs["who"]

        // ── Structural ──────────────────────────────────────────────────
        case "text": inText = true
        case "front": inFront = true
        case "back": inBack = true
        case "body": inBody = true

        case "div":
            let acc = DivAccumulator(
                id: xmlID(attrs),
                typeString: attrs["type"],
                number: attrs["n"],
                subtype: attrs["subtype"]
            )
            divStack.append(acc)

        case "head":
            pushInline(attrs: attrs)

        case "dateline":
            pushInline(attrs: attrs)

        case "opener":
            pushInline(attrs: attrs)

        case "closer":
            pushInline(attrs: attrs)

        case "p":
            pushInline(attrs: attrs)

        case "note":
            let acc = NoteAccumulator(
                id: xmlID(attrs),
                type: attrs["type"],
                n: attrs["n"],
                place: attrs["place"]
            )
            noteStack.append(acc)
            pushInline(attrs: attrs)

        case "pb":
            let pb = PageBreak(id: xmlID(attrs), n: attrs["n"], facs: attrs["facs"])
            appendToCurrentInline(.pageBreak(pb))

        case "lb":
            appendToCurrentInline(.lineBreak)

        case "persName":
            pushInline(attrs: attrs)

        case "placeName":
            pushInline(attrs: attrs)

        case "orgName":
            pushInline(attrs: attrs)

        case "date":
            pushInline(attrs: attrs)

        case "ref", "xRef":
            pushInline(attrs: attrs)

        case "hi":
            pushInline(attrs: attrs)

        case "term":
            pushInline(attrs: attrs)

        case "list":
            pushInline(attrs: attrs)

        case "item":
            pushInline(attrs: attrs)

        case "table":
            pushInline(attrs: attrs)

        case "row":
            pendingRowRoles.append(attrs["role"])
            pushInline(attrs: attrs)

        case "cell":
            pushInline(attrs: attrs)

        case "gloss":
            // Gloss marks a definition or explanation; rendered as plain inline text.
            pushInline(attrs: attrs)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {

        defer {
            if !elementStack.isEmpty { elementStack.removeLast() }
            if !attrStack.isEmpty { attrStack.removeLast() }
        }

        let attrs = attrStack.last ?? [:]
        // Collapse internal XML whitespace (newlines, tabs, indentation from source
        // formatting) before trimming, so header leaf values like <title> are clean
        // single-line strings. inlineStack content uses normalizeXMLWhitespace instead.
        let text = charBuf.xmlWhitespaceCollapsed().trimmingCharacters(in: .whitespacesAndNewlines)
        charBuf = ""

        switch elementName {

        // ── teiHeader leaf captures ──────────────────────────────────────
        case "title":
            if inHeader, let ct = currentTitle {
                titles.append(Title(level: ct.level, type: ct.type, lang: ct.lang, text: text))
                currentTitle = nil
            }

        case "editor":
            if inHeader {
                editors.append(Editor(role: currentEditorRole, name: text))
                currentEditor = nil
                currentEditorRole = nil
            }

        case "resp":
            if inRespStmt { respStmtResp = text }

        case "name":
            if inRespStmt { respStmtNames.append(text) }
            if currentPersonID != nil || !currentPersonNames.isEmpty {
                currentPersonNames.append(text)
            }

        case "principal", "respStmt":
            if inHeader {
                let rs = ResponsibilityStatement(responsibility: respStmtResp, names: respStmtNames)
                if elementName == "principal" { principals.append(rs) } else { respStmts.append(rs) }
                inRespStmt = false
                respStmtResp = nil
                respStmtNames = []
            }

        case "publisher": publisher = text
        case "pubPlace": pubPlace = text
        case "date":
            if inHeader && !inText {
                _ = popInline()       // balance the pushInline from didStartElement
                pubDate = text
            } else if let inline = popInline() {
                let de = DateElement(
                    when: attrs["when"],
                    from: attrs["from"],
                    to: attrs["to"],
                    notBefore: attrs["notBefore"],
                    notAfter: attrs["notAfter"],
                    text: plainText(from: inline.content)
                )
                appendToCurrentInline(.date(de))
            }

        case "idno":
            idnos.append(Identifier(type: currentIdnoType, value: text))
            currentIdnoType = nil

        case "availability": availability = text
        case "projectDesc": projectDesc = text
        case "editorialDecl": editorialDecls.append(text)
        case "keywords": keywords.append(text)

        case "person":
            personRecords.append(PersonRecord(
                id: currentPersonID,
                names: currentPersonNames,
                notes: currentPersonNotes
            ))
            currentPersonID = nil
            currentPersonNames = []
            currentPersonNotes = []

        case "change":
            changes.append(Change(
                when: currentChangeWhen,
                who: currentChangeWho,
                description: text
            ))

        case "teiHeader":
            inHeader = false

        // ── Structural ──────────────────────────────────────────────────
        case "front": inFront = false
        case "back": inBack = false
        case "body": inBody = false

        case "div":
            guard let acc = divStack.popLast() else { return }
            let div = acc.build()
            if divStack.isEmpty {
                // Top-level div — store in appropriate container
                if inFront { frontDivs.append(div) }
                else if inBack { backDivs.append(div) }
                else { bodyDivs.append(div) }
            } else {
                divStack[divStack.count - 1].children.append(div)
            }

        case "head":
            guard let inline = popInline() else { return }
            let heading = Heading(
                type: attrs["type"],
                content: inline.content
            )
            if !divStack.isEmpty {
                divStack[divStack.count - 1].headings.append(heading)
            }

        case "dateline":
            guard let inline = popInline() else { return }
            let dates = extractDates(from: inline.content)
            let places = extractPlaceNames(from: inline.content)
            let dl = Dateline(content: inline.content, dates: dates, placeNames: places)
            if !divStack.isEmpty {
                divStack[divStack.count - 1].dateline = dl
            }

        case "opener":
            guard let inline = popInline() else { return }
            let opener = Opener(salute: nil, content: inline.content)
            if !divStack.isEmpty {
                divStack[divStack.count - 1].opener = opener
            }

        case "closer":
            guard let inline = popInline() else { return }
            let closer = Closer(salute: nil, signed: nil, content: inline.content)
            if !divStack.isEmpty {
                divStack[divStack.count - 1].closer = closer
            }

        case "p":
            guard let inline = popInline() else { return }
            let para = Paragraph(
                id: xmlID(attrs),
                rend: attrs["rend"],
                content: inline.content
            )
            // Paragraph can live inside a div, or inside a note
            if !noteStack.isEmpty {
                noteStack[noteStack.count - 1].paragraphs.append(para)
            } else if !divStack.isEmpty {
                divStack[divStack.count - 1].paragraphs.append(para)
            }

        case "note":
            guard let inline = popInline() else { return }
            let noteAcc = noteStack.popLast()
            let note = Note(
                id: noteAcc?.id ?? xmlID(attrs),
                type: noteAcc?.type ?? attrs["type"],
                n: noteAcc?.n ?? attrs["n"],
                place: noteAcc?.place ?? attrs["place"],
                paragraphs: noteAcc?.paragraphs ?? [],
                content: inline.content
            )
            // A note can be a child of a div or appear inside inline content
            if !noteStack.isEmpty {
                // nested note → treat as inline in parent note
                appendToCurrentInline(.note(note))
            } else if !inlineStack.isEmpty {
                appendToCurrentInline(.note(note))
            } else if !divStack.isEmpty {
                divStack[divStack.count - 1].notes.append(note)
            }

        case "persName":
            guard let inline = popInline() else { return }
            let personText = plainText(from: inline.content)
            // In particDesc/person context, capture the name for the person record.
            // Uses plainText(from:) so nested markup (hi, ref, etc.) is included.
            if currentPersonID != nil {
                currentPersonNames.append(personText)
            }
            let pn = PersonName(
                ref: attrs["ref"] ?? attrs["corresp"],
                role: attrs["role"],
                text: personText
            )
            appendToCurrentInline(.persName(pn))

        case "placeName":
            guard let inline = popInline() else { return }
            let pl = PlaceName(
                ref: attrs["ref"] ?? attrs["corresp"],
                text: plainText(from: inline.content)
            )
            appendToCurrentInline(.placeName(pl))

        case "orgName":
            guard let inline = popInline() else { return }
            let org = OrgName(
                ref: attrs["ref"] ?? attrs["corresp"],
                text: plainText(from: inline.content)
            )
            appendToCurrentInline(.orgName(org))

        case "ref", "xRef":
            guard let inline = popInline() else { return }
            let ref = Reference(
                target: attrs["target"],
                type: attrs["type"],
                text: plainText(from: inline.content)
            )
            appendToCurrentInline(.ref(ref))

        case "hi":
            guard let inline = popInline() else { return }
            let hi = HighlightedText(rend: attrs["rend"], content: inline.content)
            appendToCurrentInline(.hi(hi))

        case "term":
            guard let inline = popInline() else { return }
            let term = Term(
                ref: attrs["ref"] ?? attrs["corresp"],
                text: plainText(from: inline.content)
            )
            appendToCurrentInline(.term(term))

        case "list":
            guard let inline = popInline() else { return }
            let items = extractListItems(from: inline.content)
            let list = XMLList(type: attrs["type"], items: items)
            appendToCurrentInline(.list(list))

        case "item":
            guard let inline = popInline() else { return }
            // Encode the item's full inline content as a JSON-like sentinel so the
            // parent list handler can reconstruct ListItem(content:) properly.
            // We store the content array index into a thread-local staging buffer.
            let itemContent = inline.content
            pendingListItemContents.append(itemContent)
            let idx = pendingListItemContents.count - 1
            appendToCurrentInline(.unknown(elementName: "__item__", rawContent: "\(idx)"))

        case "table":
            guard let inline = popInline() else { return }
            let rows = extractTableRows(from: inline.content)
            let table = Table(rows: rows)
            appendToCurrentInline(.table(table))

        case "row":
            guard let inline = popInline() else { return }
            // Store this row's content array in the staging buffer
            let rowContent = inline.content
            pendingRowContents.append(rowContent)
            let rowIdx = pendingRowContents.count - 1
            appendToCurrentInline(.unknown(elementName: "__row__", rawContent: "\(rowIdx)"))

        case "cell":
            guard let inline = popInline() else { return }
            let cellContent = inline.content
            pendingCellContents.append(cellContent)
            let cellIdx = pendingCellContents.count - 1
            appendToCurrentInline(.unknown(elementName: "__cell__", rawContent: "\(cellIdx)"))

        case "gloss":
            guard let inline = popInline() else { return }
            // Drain gloss content (including any child markup) into the parent inline context.
            for item in inline.content {
                appendToCurrentInline(item)
            }

        case "TEI":
            // Build the final volume
            let titleStmt = TitleStatement(
                titles: titles,
                editors: editors,
                principals: principals,
                responsibilityStatements: respStmts
            )
            let pubStmt = PublicationStatement(
                publisher: publisher,
                pubPlace: pubPlace,
                date: pubDate,
                idnos: idnos,
                availability: availability
            )
            let fileDesc = FileDescription(
                titleStatement: titleStmt,
                publicationStatement: pubStmt,
                sourceDescription: nil
            )
            let encDesc = EncodingDescription(
                projectDescription: projectDesc,
                editorialDeclarations: editorialDecls
            )
            let profDesc = ProfileDescription(
                langUsage: languages,
                textClass: keywords.isEmpty ? nil : TextClass(keywords: keywords),
                particDesc: personRecords.isEmpty ? nil : ParticipantDescription(persons: personRecords)
            )
            let revDesc = changes.isEmpty ? nil : RevisionDescription(changes: changes)
            let header = TEIHeader(
                fileDescription: fileDesc,
                encodingDescription: encDesc,
                profileDescription: profDesc,
                revisionDescription: revDesc
            )
            let front = frontDivs.isEmpty ? nil : FrontMatter(divisions: frontDivs)
            let body = Body(divisions: bodyDivs)
            let back = backDivs.isEmpty ? nil : BackMatter(divisions: backDivs)
            let teiText = TEIText(front: front, body: body, back: back)
            result = FRUSVolume(id: volumeID, header: header, text: teiText)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        charBuf += string
        // Normalize XML whitespace: collapse internal runs, preserve single spaces.
        // Raw XML text nodes include newlines and indentation from formatting; these
        // must not appear as stray whitespace in rendered output.
        guard !inlineStack.isEmpty else { return }
        // Collapse any whitespace-only node to a single space (inter-element spacing),
        // or pass through non-whitespace content with internal runs collapsed.
        let normalized = normalizeXMLWhitespace(string)
        if !normalized.isEmpty {
            inlineStack[inlineStack.count - 1].content.append(.text(normalized))
        }
    }

    /// Normalises whitespace in a SAX text node for inline rendering.
    ///
    /// XML documents use newlines and indentation between elements as formatting;
    /// these must not appear verbatim in rendered output.  The rules applied here
    /// match the XML specification's whitespace handling for mixed-content models:
    ///
    /// 1. Any whitespace-only text node collapses to a single U+0020 SPACE —
    ///    preserving word boundaries between adjacent inline elements such as
    ///    `<persName>Kissinger</persName>, who…` where the `, ` lives in a text node.
    ///    An already-empty string returns empty (no phantom space inserted).
    ///
    /// 2. For text nodes that contain non-whitespace content, every tab, carriage
    ///    return, and newline character is replaced with a single space, then
    ///    consecutive spaces are collapsed to one.  Leading and trailing spaces are
    ///    preserved as a single space each when present in the original, so that
    ///    text adjacent to inline elements retains its inter-word spacing.
    private func normalizeXMLWhitespace(_ s: String) -> String {
        guard !s.isEmpty else { return "" }

        // Fast path: purely whitespace node → single space (word-boundary keeper).
        // Uses Swift's built-in allSatisfy which is O(n) single-pass.
        if s.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return " "
        }

        // General path: mixed text node.
        // Step 1 — single pass: replace every whitespace character with U+0020,
        //           building the result in a pre-allocated array for O(n) time.
        var chars = Array(s.unicodeScalars)
        let wsSet = CharacterSet.whitespacesAndNewlines
        for i in chars.indices {
            if wsSet.contains(chars[i]) {
                chars[i] = Unicode.Scalar(0x0020)! // U+0020 SPACE
            }
        }

        // Step 2 — single pass: collapse consecutive spaces, track leading/trailing.
        var result: [Unicode.Scalar] = []
        result.reserveCapacity(chars.count)
        var prevWasSpace = false
        for scalar in chars {
            if scalar.value == 0x0020 {
                if !prevWasSpace { result.append(scalar) }
                prevWasSpace = true
            } else {
                result.append(scalar)
                prevWasSpace = false
            }
        }

        // Step 3 — strip purely-structural leading/trailing spaces, then restore
        //           one space at each boundary if the original had whitespace there
        //           (preserves inter-element word spacing).
        // Array<Unicode.Scalar> uses Int indices.
        var lo = 0
        var hi = result.count
        while lo < hi && result[lo].value == 0x0020 { lo += 1 }
        while hi > lo && result[hi - 1].value == 0x0020 { hi -= 1 }

        let hadLeadingWS  = s.unicodeScalars.first.map { wsSet.contains($0) } ?? false
        let hadTrailingWS = s.unicodeScalars.last.map  { wsSet.contains($0) } ?? false
        let space = Unicode.Scalar(0x0020)!

        var finalScalars: [Unicode.Scalar] = []
        finalScalars.reserveCapacity(hi - lo + 2)
        if hadLeadingWS  { finalScalars.append(space) }
        finalScalars.append(contentsOf: result[lo..<hi])
        if hadTrailingWS { finalScalars.append(space) }
        return String(String.UnicodeScalarView(finalScalars))
    }
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        // ignore
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            charBuf += s
            if !inlineStack.isEmpty {
                inlineStack[inlineStack.count - 1].content.append(.text(s))
            }
        }
    }

    // ── Internal containers ────────────────────────────────────────────────

    private var frontDivs: [Division] = []
    private var bodyDivs: [Division] = []
    private var backDivs: [Division] = []

    // ── Helpers ────────────────────────────────────────────────────────────

    private func xmlID(_ attrs: [String: String]) -> String? {
        attrs["xml:id"] ?? attrs["{http://www.w3.org/XML/1998/namespace}id"]
    }

    private func pushInline(attrs: [String: String]) {
        inlineStack.append(InlineAccumulator(attrs: attrs))
    }

    private func popInline() -> InlineAccumulator? {
        inlineStack.popLast()
    }

    private func appendToCurrentInline(_ item: InlineContent) {
        guard !inlineStack.isEmpty else { return }
        inlineStack[inlineStack.count - 1].content.append(item)
    }

    private func plainText(from content: [InlineContent]) -> String {
        content.map { item -> String in
            switch item {
            case .text(let s): return s
            case .persName(let p): return p.text
            case .placeName(let p): return p.text
            case .orgName(let o): return o.text
            case .date(let d): return d.text
            case .ref(let r): return r.text
            case .hi(let h): return plainText(from: h.content)
            case .term(let t): return t.text
            case .note: return ""
            case .pageBreak, .lineBreak: return ""
            case .list: return ""
            case .table: return ""
            case .unknown: return ""
            }
        }.joined()
    }

    private func extractDates(from content: [InlineContent]) -> [DateElement] {
        content.compactMap {
            if case .date(let d) = $0 { return d }
            return nil
        }
    }

    private func extractPlaceNames(from content: [InlineContent]) -> [PlaceName] {
        content.compactMap {
            if case .placeName(let p) = $0 { return p }
            return nil
        }
    }

    private func extractListItems(from content: [InlineContent]) -> [ListItem] {
        content.compactMap { item -> ListItem? in
            if case .unknown(let name, let rawContent) = item, name == "__item__" {
                if let idx = Int(rawContent), idx < pendingListItemContents.count {
                    return ListItem(content: pendingListItemContents[idx])
                }
                return ListItem(content: [.text(rawContent)])
            }
            return nil
        }
    }

    private func extractTableRows(from content: [InlineContent]) -> [TableRow] {
        content.compactMap { item -> TableRow? in
            guard case .unknown(let name, let rawContent) = item, name == "__row__" else { return nil }
            guard let idx = Int(rawContent), idx < pendingRowContents.count else { return nil }
            let rowContent = pendingRowContents[idx]
            let cells = extractTableCells(from: rowContent)
            // Determine role from original attrs — we don't have them here so use nil
            let role = idx < pendingRowRoles.count ? pendingRowRoles[idx] : nil
            return TableRow(role: role, cells: cells)
        }
    }

    private func extractTableCells(from content: [InlineContent]) -> [TableCell] {
        content.compactMap { item -> TableCell? in
            guard case .unknown(let name, let rawContent) = item, name == "__cell__" else { return nil }
            guard let idx = Int(rawContent), idx < pendingCellContents.count else { return nil }
            return TableCell(role: nil, cols: nil, rows: nil, content: pendingCellContents[idx])
        }
    }
}

// MARK: - Accumulator Types

private struct InlineAccumulator {
    let attrs: [String: String]
    var content: [InlineContent] = []
}

private struct NoteAccumulator {
    let id: String?
    let type: String?
    let n: String?
    let place: String?
    var paragraphs: [Paragraph] = []
}

private struct DivAccumulator {
    let id: String?
    let typeString: String?
    let number: String?
    let subtype: String?
    var headings: [Heading] = []
    var dateline: Dateline? = nil
    var opener: Opener? = nil
    var closer: Closer? = nil
    var paragraphs: [Paragraph] = []
    var notes: [Note] = []
    var children: [Division] = []

    func build() -> Division {
        let divType: DivisionType?
        if let ts = typeString {
            divType = DivisionType(rawValue: ts) ?? .other
        } else {
            divType = nil
        }
        return Division(
            id: id,
            type: divType,
            number: number,
            subtype: subtype,
            headings: headings,
            dateline: dateline,
            opener: opener,
            closer: closer,
            paragraphs: paragraphs,
            notes: notes,
            children: children
        )
    }
}
