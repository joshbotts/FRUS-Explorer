// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation

// MARK: - Converter

/// Layer 2 of the TEI rendering pipeline.
///
/// Converts a `FRUSDocumentAST` (Layer 1 output) into a `FRUSDocumentRenderModel`
/// (Layer 2 output) according to the `TEIRenderingConfig`.
///
/// ## Footnote Numbering
/// Footnotes are numbered sequentially in document order during the single conversion
/// pass. Each `<note>` in the AST produces two render nodes:
///   - A `footnoteMarker` inline at the reference point (goes into the body).
///   - A `footnoteBody` collected in the `footnotes` array for bottom rendering.
///
/// ## persName / gloss Lookup
/// In Session 06, lookups always return `nil` (the volume's List of Persons and Terms
/// are not yet parsed). Session 07 passes non-nil lookup closures to enable the popover
/// content in the Document view.
///
/// ## Mutability
/// The converter tracks footnote state via a `var` counter. Instances are single-use
/// (one instance per `convert` call).
///
/// Version history:
///   1.0 — Session 06: initial implementation
///   1.x — Session 42: prefer `printedNumber` over sequential counter for display
///   1.1 — Session 78: `.attachment` case converts `.head` children to `.attachmentHeading`
///   1.2 — Session 79: `.titlePage` produces `.titlePageBlock` instead of `.unknown`
///   1.3 — Session 105: `renderingVersion(for:)` static API + `flatText(_:)` DFS helper
///   1.4 — Session 2026-06-08: `abbrLookup` added; `.unknown(name: "abbr", …)` elements
///          whose text matches a glossary term are emitted as `.glossLink` nodes so they
///          render with the accent-coloured dotted underline and open `GlossDetailSheet`
///          on tap, identical to explicit `<gloss ref="…">` elements.
///   1.5 — Session 7 / #240B: `brokenRefLookup` added; `crossRefLink` carries the
///          broken-ref payload so validated-dead references render as explained spans.
///   1.6 — Session 2026-08-09 / #659: upstream autolink noise (a bare-host `http(s)` target
///          under prose link text) renders as plain text instead of a link — see
///          `isSpuriousAutolink`. **`kVersion` is deliberately NOT bumped**: `flatText`
///          already recurses `.crossRefLink`'s children exactly as it would `.plainText`, so
///          the flat text is byte-identical and no stored highlight goes stale. A reflexive
///          bump here would mark every highlight in every indexed volume stale for a change
///          that moved no characters.
///   1.7 — #985: `displayLabel` is the number the volume PRINTED, or `nil`. The previous
///          `printedNumber ?? "\(sequentialNumber)"` invented a number for every note without
///          `@n` — 196,040 in-document notes, 193,500 of them unnumbered source notes — and
///          since the source note is almost always first it was handed the label "1", colliding
///          with the real footnote 1 in 51,368 documents. `sequentialNumber` still advances for
///          every note; it is now a DOM-key input rather than a display value, and rides on
///          `.footnoteMarker` too so a marker can derive the same key as its body.
///          **`kVersion` is deliberately NOT bumped**: `flatText` skips `.footnoteMarker`
///          entirely (the `default: break` arm), so no marker label has ever contributed a
///          character to the highlight coordinate space and no stored highlight goes stale.
///   1.8 — #1323: `<hi rend="strong">` now reaches this converter as `.emphasis(.bold, …)`
///          rather than `.emphasis(.unspecified, …)`, so it emits `.boldText(children)` where it
///          used to splice the children in unstyled. **`kVersion` is deliberately NOT bumped.**
///          `flatText` recurses `.boldText` exactly as it concatenates spliced children, so the
///          flat text is byte-identical — but that alone is not the whole argument, because
///          `FRUSRenderNode.appendFlatTextBlocks` treats `.boldText` as INLINE (no flush) while
///          a spliced block child would have flushed. The measurement is what closes it: over
///          158,059 `strong` elements in the 553 manifest volumes NOT ONE has a direct block
///          child — the only element children are `<note>` (350, which convert to an inline
///          `.footnoteMarker` plus a separately collected body), `<lb/>` (74) and 2 `<p>`s
///          nested inside one of those notes. So no excerpt loses a paragraph break and no
///          DOCX/PDF run changes block-vs-inline routing, and no stored highlight goes stale.
///   1.9 — #1369: `printedLabel(from:)` treats `n="0"` as unnumbered, so 9,985 head-nested source
///          notes draw the archival mark rather than a superscript 0. `kVersion` is not bumped: a
///          marker's label is outside `flatText`, which skips every `.footnoteMarker`, so no offset moves.
///   1.10 — #1371: `.list` converts every child in document order instead of keeping only its
///          items. `<head>` becomes the list's heading, each `<label>` rides with the item after
///          it, and every other child (`<pb/>`, `<lb/>`, `<note>`, `<salute>`, `<closer>`,
///          `<figure>`, `<gap/>`) is kept beside its neighbouring item as a ``ListLead``. Before
///          this, `SUBJECT`/`PARTICIPANTS` heads and printed numbering such as `(1)` were lost from
///          79,788 documents, and a footnote in a list head (16 documents), in a label (51) or loose
///          in a list (`frus1952-54v02p1/d93`) lost its marker AND its body, since a body is
///          collected only when its note is converted. **`kVersion` is deliberately NOT bumped:**
///          `flatText` still walks only the items, so every document's flat text is byte-identical
///          and no stored highlight goes stale. That covers the 94 documents that put an `<lb/>`,
///          `<closer>`, `<salute>` or `<gap/>` directly in a list: a line break or a closer walked as
///          flat text would have moved their `body_hash`. The price is that a highlight cannot begin
///          or end inside a label or heading; the selection bridge (`kSelectionJS`) moves such an
///          endpoint to the item's first letter, so a drag that starts on "(1)" still highlights
///          (`ListLabelSelectionTests`), and highlight and excerpt passages omit the numbering.
///   1.11 — #1495: `.table` keeps its `<head>` as the `.tableBlock`'s caption, converted where it
///          stands, instead of keeping only the rows. The caption — a table's title, and often its
///          units (`Millions of Dollars`) — reached no renderer from 216 tables in 96 documents, and
///          the 9 footnotes in captions (7 documents) lost their markers and bodies, since a body is
///          collected only when its note is converted. **`kVersion` is deliberately NOT bumped:**
///          `flatText` walks only the cells, so every document's flat text and `body_hash` are
///          byte-identical. A caption's note now takes a sequential number, so every later note in
///          its document takes one higher; that number keys nothing that outlives one rendering
///          (`footnoteDOMKey`'s `n-` branch, the DOCX id map), so nothing stored moves. The index is
///          untouched: `IndexingPipeline` reads bodies and footnotes from the AST, where the head
///          and its notes always were.
///   1.12 — #1509: a link to a printed page inside a footnote carries what the footnote names
///          (`.crossRefLink`'s `citing`, `PageCitationHint(noteChildren:)`), built from the same AST
///          the indexer builds the reference's edge from. **`kVersion` is not bumped:** the hint is
///          no text, and `flatText` reads only `.crossRefLink`'s children.
///   1.13 — #1516: `.figure` converts everything the figure prints — its `<head>`, its paragraphs
///          and its `<figDesc>` as captions, the image's name with the volume it is found in, a
///          video's link — where it kept the graphic's name alone and every renderer printed that
///          name as the caption (`figure_1162`, on 510 figures in documents); an empty figure
///          converts to nothing. The fold-in: `.elementSpace`, the space between two inline
///          elements. **`kVersion` is deliberately NOT bumped:** `flatText` skipped `.figureBlock`
///          whatever it carried and skips `.elementSpace`, so every document's flat text and
///          `body_hash` are byte-identical, no stored highlight goes stale and nothing re-indexes
///          (owner decision D3a: a figure's paragraphs are captions). The index is untouched:
///          `IndexingPipeline` reads a figure's text from the AST, where it always was.
public struct ASTToRenderNodeConverter {

    /// Converter algorithm version. Bump whenever the flat-text output changes
    /// (new text-bearing node type, traversal order change, character normalisation).
    /// Used as part of `DocumentHighlight.renderingVersion`.
    public static let kVersion = "1.2"

    /// The label a volume PRINTED for a footnote, or `nil` when it printed none (#985).
    ///
    /// `@n` is taken verbatim from the TEI, so present-but-blank must be treated as absent: one
    /// note corpus-wide carries `n=""` (`frus1969-76v25 d146`) and six carry a leading space
    /// (`n=" 1"`). A bare `printedNumber != nil` test admits both, and the empty one reintroduces
    /// exactly the defect #985 removed — an unlabelled marker keyed on an empty string.
    ///
    /// **One rule, two callers (#1322).** The reader draws this label, and
    /// `IndexingPipeline.collectBodyFootnoteTexts` stores it beside each harvested citation so a
    /// trip packet can cite the number the volume printed. They must normalise `@n` identically or
    /// the packet and the page disagree about the same note, so the rule lives here rather than
    /// being written twice.
    ///
    /// The label is NOT unique within a document: measured over the corpus, 6,912 documents
    /// (22,601 notes) repeat one, because numbering restarts inside attachments. It identifies
    /// what the volume printed, never which note.
    ///
    /// **`n="0"` is unnumbered too (#1369).** 34 volumes encode a document's unnumbered source
    /// note as `<note n="0" type="source">` rather than leaving `@n` out — 9,985 notes, one per
    /// document, in the head. No FRUS volume prints a footnote 0: 29 of those volumes' prefaces
    /// call the source note unnumbered, and in 8,807 of the 8,824 documents that also carry a body
    /// footnote the first one is `n="1"`. So `0` means "before footnote 1" in the encoding, not a
    /// number the volume printed, and treating it as a label drew a blue superscript 0 where the
    /// archival mark belongs. Four untyped body notes in `frus1961-63v24` carry `n="0"` as well;
    /// they read unnumbered for the same reason.
    public static func printedLabel(from printedNumber: String?) -> String? {
        guard let trimmed = printedNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != "0" else { return nil }
        return trimmed
    }

    // MARK: - Rendering Version

    /// Computes the 16-character hex `renderingVersion` for a render model.
    ///
    /// Hashes `SHA-256(flatText(bodyNodes).utf8 ++ kVersion.utf8)` and returns the
    /// first 16 hex characters (64 bits of collision resistance).
    ///
    /// The hash changes whenever the document's parsed text changes (e.g. after a
    /// volume re-download) or when `kVersion` is bumped after a converter algorithm change.
    /// Highlights whose stored `renderingVersion` no longer matches are shown as stale.
    public static func renderingVersion(for model: FRUSDocumentRenderModel) -> String {
        var data = Data()
        data.append(Data(flatText(model.bodyNodes).utf8))
        data.append(Data(kVersion.utf8))
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    // MARK: - Spurious autolinks (#659)

    /// Whether a `<ref>` is upstream autolink noise rather than a link an editor wrote.
    ///
    /// Two clauses, and **both are load-bearing**. Measured over the 552 shippable volumes of
    /// build 45 there are 619 `http(s)` refs inside documents; this predicate de-links exactly 22
    /// and keeps 597. The counts have not been re-measured since; OH's PR #460 moved one of the
    /// named examples out of the bare-host class, and `frus1981-88v16` arrived after it.
    ///
    /// 1. **The target is a bare host** — no path, no query, no fragment. Every one of the 22 is
    ///    (`http://must.be`); every deep link in the corpus is real. This clause alone is not
    ///    enough: thirty genuine bare-host links exist (`http://bookstore.gpo.gov`,
    ///    `http://www.un.org`). A third example stood here — `http://uwdc.library.wisc.edu/`, the
    ///    Wisconsin digitisation credit in `frus1914Supp` — until PR #460 repointed it at
    ///    `https://www.library.wisc.edu/uwdcc/`. That target has a path, so clause 1 now saves it
    ///    outright and it is no longer one of the thirty; the old spelling survives only as the
    ///    ref's link TEXT, and a scan of the corpus finds the target zero times.
    /// 2. **The link text does not announce itself as a URL.** All thirty genuine bare-host links
    ///    are written with the URL as their own link text; all twenty-two autolinks are written
    ///    over prose. This clause alone is not enough either: five real links — the
    ///    `frus1917-72PubDip` supplement PDFs — carry prose text ("a high resolution color PDF")
    ///    over a deep `static.history.state.gov` target, and clause 1 is what saves them.
    ///
    /// The deliberate cost: a future volume writing `<ref target="http://example.org">example.org
    /// </ref>` — a bare host whose text is the domain without a scheme — would be de-linked. That
    /// is the same shape as `<ref target="http://would.be">would.be</ref>`, which IS noise, and no
    /// predicate can separate them. Losing a tap on text that already reads as its own URL is the
    /// cheaper error; the alternative re-admits a link to a domain that does not exist.
    ///
    /// Scheme-gated to `http(s)` on purpose: `mailto:history@state.gov` refs are real, and their
    /// link text is never a URL.
    private static func isSpuriousAutolink(target: String, linkText: String) -> Bool {
        let lowered = target.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else { return false }
        guard let url = URL(string: target),
              url.path.isEmpty || url.path == "/",
              url.query == nil, url.fragment == nil else { return false }
        let text = linkText.lowercased()
        return !text.contains("http://") && !text.contains("https://")
    }

    /// DFS flat-text extraction per the Session 102 offset model spec.
    ///
    /// Rules:
    /// - `.plainText` / `.formulaText` → contribute their string value.
    /// - `.lineBreak` → contributes `"\n"`.
    /// - `.pageBreak`, `.footnoteMarker`, `.figureBlock`, `.footnoteBody`, `.elementSpace` → skip
    ///   (no chars). A figure's head and captions are skipped with it (#1516): the serializer
    ///   draws them under `data-skip`.
    /// - `.suppliedText` children → recurse without adding brackets.
    /// - `.tableBlock` → recurse each cell's children in row-major order. Its caption is skipped
    ///   (#1495): the serializer draws it under `data-skip`.
    /// - `.listBlock` → recurse each item's content in order. Its heading, labels and other
    ///   non-item children are skipped (#1371): the serializer draws them under `data-skip`.
    /// - All other container nodes → recurse their children.
    private static func flatText(_ nodes: [FRUSRenderNode]) -> String {
        var result = ""
        for node in nodes {
            switch node {
            case .plainText(let s):
                result += s
            case .formulaText(let s):
                result += s
            case .lineBreak:
                result += "\n"
            case .pageBreak, .footnoteMarker, .figureBlock, .footnoteBody, .elementSpace:
                break
            case .tableBlock(_, let rows):
                for row in rows {
                    for cell in row { result += flatText(cell.children) }
                }
            case .listBlock(_, _, let items, _):
                for item in items { result += flatText(item.children) }
            case .heading(let c), .dateline(let c), .letterOpener(let c),
                 .letterCloser(let c), .salutation(let c), .paragraph(let c),
                 .boldText(let c), .italicText(let c), .smallCapsText(let c),
                 .underlineText(let c), .termText(let c), .suppliedText(let c),
                 .sicText(let c), .corrText(let c), .editorialNoteBlock(let c),
                 .titlePageBlock(let c), .attachmentHeading(let c):
                result += flatText(c)
            case .persNameLink(_, let c, _), .glossLink(_, let c, _),
                 .crossRefLink(_, _, _, _, let c), .attachmentBlock(_, let c),
                 .unknown(_, let c):
                result += flatText(c)
            }
        }
        return result
    }

    // MARK: Dependencies

    /// Returns a `PersonEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's persons list.
    public var personLookup: ((String) -> PersonEntry?)?

    /// Returns a `GlossEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's terms list.
    public var glossLookup: ((String) -> GlossEntry?)?

    /// Returns a `GlossEntry` whose `term` text matches the given abbreviation string
    /// (case-insensitive). Used to resolve `<abbr>` elements that lack a `@ref` attribute.
    ///
    /// When non-nil, any `.unknown(name: "abbr", …)` AST node whose plain-text content
    /// matches a glossary term is emitted as a `.glossLink` render node — giving it the
    /// same dotted-underline styling and tap-to-sheet behaviour as explicit
    /// `<gloss ref="…">` links.
    ///
    /// `nil` (default) means `<abbr>` elements are rendered as plain text without linking.
    public var abbrLookup: ((String) -> GlossEntry?)?

    /// Returns broken-ref detail for a raw `<ref target>` value, or `nil` when the ref resolves
    /// (or is a non-degradable `malformedTarget` the store already filters). Closes over the source
    /// volume so the lookup is volume-scoped. When it returns non-nil the `<ref>` renders as a
    /// non-navigable explained span (issue #240B). `nil` (default) keeps every cross-reference live
    /// — so exporters, which inject no lookup, are unaffected.
    public var brokenRefLookup: ((String) -> BrokenRefInfo?)?

    /// The volume the documents being converted come from, or `nil` (#1516): what a figure's
    /// image and a video's link are found by.
    public var volumeId: String?

    // MARK: State

    /// The id of the document being converted (#1516): a video's link names it.
    private var documentId = ""

    private var footnoteCounter = 0
    private var collectedFootnotes: [FRUSRenderNode] = []
    /// The footnotes being converted, innermost last: each one's AST children, or `nil` for an
    /// editorial note's own text, which is in no footnote (#1509). A page link takes what the
    /// innermost names (`PageCitationHint(noteChildren:)`), as `IndexingPipeline.collectDocumentRefs`
    /// does for the edge it stores.
    private var citingNotes: [[FRUSASTNode]?] = []

    // MARK: Init

    /// Creates a converter.
    ///
    /// - Parameter volumeId: The volume the documents come from. A figure's image is found by
    ///   volume and name, and a video's link names the volume, so a converter built without one
    ///   prints the placeholder for every image and no video link (#1516).
    public init(volumeId: String? = nil,
                personLookup: ((String) -> PersonEntry?)? = nil,
                glossLookup: ((String) -> GlossEntry?)? = nil,
                abbrLookup: ((String) -> GlossEntry?)? = nil,
                brokenRefLookup: ((String) -> BrokenRefInfo?)? = nil) {
        self.volumeId = volumeId
        self.personLookup = personLookup
        self.glossLookup = glossLookup
        self.abbrLookup = abbrLookup
        self.brokenRefLookup = brokenRefLookup
    }

    // MARK: - Public API

    /// Converts a `FRUSDocumentAST` into a `FRUSDocumentRenderModel`.
    ///
    /// This method is called once per document. The converter instance should not be
    /// reused across multiple documents because the footnote counter is not reset.
    public mutating func convert(_ ast: FRUSDocumentAST) -> FRUSDocumentRenderModel {
        documentId = ast.documentId
        let bodyNodes = convertNodes(ast.nodes)
        return FRUSDocumentRenderModel(
            documentId: ast.documentId,
            bodyNodes: bodyNodes,
            footnotes: collectedFootnotes
        )
    }

    // MARK: - Node Conversion

    private mutating func convertNodes(_ nodes: [FRUSASTNode]) -> [FRUSRenderNode] {
        nodes.flatMap { convertNode($0) }
    }

    private mutating func convertNode(_ node: FRUSASTNode) -> [FRUSRenderNode] {
        switch node {

        case .document(_, _, let children):
            return convertNodes(children)

        case .head(let children):
            return [.heading(convertNodes(children))]

        case .dateline(let children):
            return [.dateline(convertNodes(children))]

        case .opener(let children):
            return [.letterOpener(convertNodes(children))]

        case .closer(let children):
            return [.letterCloser(convertNodes(children))]

        case .salute(let children):
            return [.salutation(convertNodes(children))]

        case .paragraph(let children):
            return [.paragraph(convertNodes(children))]

        case .footnote(let id, let type, let printedNumber, let children):
            footnoteCounter += 1
            let sequentialNumber = footnoteCounter
            // #985: the label is the number the VOLUME printed, or nothing. It is never
            // synthesised. The old `printedNumber ?? "\(sequentialNumber)"` gave the unnumbered
            // source note the label "1" — a number that belongs to a real footnote, duplicated in
            // 51,368 documents, and used downstream as a DOM id and as a DOCX dictionary key.
            //
            // `@n` is taken verbatim from the TEI, so present-but-blank must be treated as absent:
            // one note corpus-wide carries `n=""` (frus1969-76v25 d146) and six carry a leading
            // space (`n=" 1"`). A bare `printedNumber != nil` test admits both, and the empty one
            // reintroduces exactly the defect this change removes — an unlabelled marker keyed on
            // an empty string. The counter still advances for every note, so the DOM key below is
            // dense and stable regardless.
            let displayLabel = Self.printedLabel(from: printedNumber)
            citingNotes.append(children)
            let convertedChildren = convertNodes(children)
            citingNotes.removeLast()
            // When a footnote contains only inline nodes (no <p> wrapper in the source TEI),
            // wrap them in a single .paragraph so the renderer treats them as continuous prose
            // rather than rendering each node as a separate VStack row.
            let footnoteChildren: [FRUSRenderNode] = convertedChildren.contains(where: isBlockNode)
                ? convertedChildren
                : [.paragraph(convertedChildren)]
            let body = FRUSRenderNode.footnoteBody(
                id: id, type: type,
                printedNumber: printedNumber,
                sequentialNumber: sequentialNumber,
                displayLabel: displayLabel,
                children: footnoteChildren
            )
            collectedFootnotes.append(body)
            return [.footnoteMarker(id: id, type: type, sequentialNumber: sequentialNumber,
                                    displayLabel: displayLabel)]

        case .persName(let ref, let children):
            // Normalise the ref by stripping the leading '#' that FRUS TEI uses
            // (e.g. ref="#AlexanderHaig"). PersonEntry.ref stores the bare xml:id
            // value without '#', so the lookup only succeeds after normalisation.
            let normRef = ref.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            let person  = normRef.flatMap { personLookup?($0) }
            return [.persNameLink(ref: normRef, children: convertNodes(children), person: person)]

        case .gloss(let ref, let children):
            // Heading-metadata glosses (`<gloss type="from">Department of State</gloss>`
            // etc.) carry no target — they are not glossary terms and must not
            // render as tappable links (Session 162 link audit: they produced
            // dead `href="#"` anchors in document headings).
            guard let rawRef = ref else {
                return convertNodes(children)
            }
            let normRef = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
            let entry   = glossLookup?(normRef)
            return [.glossLink(ref: normRef, children: convertNodes(children), entry: entry)]

        case .crossReference(let target, let volumeId, let children):
            let inner = convertNodes(children)
            // #659: twenty-two `<ref>`s across twelve 1863–1868 volumes are upstream autolink
            // noise — an ordinary prose phrase whose final letters happen to form a country TLD,
            // turned into a link to a host that does not exist ("Shall" → `http://pha.ll`,
            // "must be" → `http://must.be`). They are indistinguishable from working links on
            // screen and take the reader out of the app to a dead domain. Rendered as plain text.
            if Self.isSpuriousAutolink(target: target, linkText: Self.flatText(inner)) {
                return inner
            }
            // `target` is the verbatim `@target` attribute — the exact key the broken-refs index
            // is keyed on. A non-nil result renders as a non-navigable explained span.
            let broken = brokenRefLookup?(target)
            // #1509: a link to a printed page carries what its footnote names, so the tap opens the
            // document the footnote means among several the page names.
            var citing: PageCitationHint?
            if let note = citingNotes.last ?? nil,
               case .page = FRUSURLScheme.resolveCrossRefTarget(target, volumeId: volumeId) {
                citing = PageCitationHint(noteChildren: note)
            }
            return [.crossRefLink(target: target, volumeId: volumeId, broken: broken,
                                  citing: citing, children: inner)]

        case .emphasis(let style, let children):
            let inner = convertNodes(children)
            switch style {
            case .italic:    return [.italicText(inner)]
            case .bold:      return [.boldText(inner)]
            case .smallCaps: return [.smallCapsText(inner)]
            case .underline: return [.underlineText(inner)]
            case .unspecified: return inner
            }

        case .term(let children):
            return [.termText(convertNodes(children))]

        case .text(let string):
            return string.isEmpty ? [] : [.plainText(string)]

        // MARK: Page breaks (Session 07)

        case .pageBreak(let number):
            return [.pageBreak(pageNumber: number)]

        // MARK: Tables (Session 07)

        case .table(let children):
            // #1495: the caption and the rows, in document order — which is also footnote order,
            // since a note is numbered and its body collected only when it is converted. The cells
            // alone are flat text; the caption reaches the renderers above them, offset-invisible.
            var caption: [FRUSRenderNode]?
            var rows: [[TableCell]] = []
            for child in children {
                switch child {
                case .head(let headChildren):
                    // Always the table's first child and never repeated in the corpus (216 heads). A
                    // second one is kept rather than dropped, on a line of its own.
                    let converted = convertNodes(headChildren)
                    caption = caption.map { $0 + [.lineBreak] + converted } ?? converted
                case .tableRow(let cells):
                    rows.append(cells.compactMap { cell -> TableCell? in
                        guard case .tableCell(let rs, let cs, let ch) = cell else { return nil }
                        return TableCell(rowSpan: rs, colSpan: cs, children: convertNodes(ch))
                    })
                default:
                    // The corpus's only other child of a table is a `<pb/>` between two rows (1,557
                    // of them, in 703 documents), dropped as it always was: the reader hides every
                    // page break, and in Word one would be a hard page break inside the table.
                    continue
                }
            }
            return [.tableBlock(caption: caption, rows: rows)]

        case .tableRow, .tableCell:
            // Handled as children of .table; should not appear standalone.
            return []

        // MARK: Lists (Session 07)

        case .list(let type, let children):
            // #1371: every child, in document order — which is also footnote order, since a note
            // is numbered and its body collected only when it is converted. The items alone are
            // flat text; everything else reaches the renderers beside them, offset-invisible.
            var heading: [FRUSRenderNode]?
            var items: [ListItemEntry] = []
            var lead: [ListLead] = []
            for child in children {
                switch child {
                case .head(let headChildren):
                    // Always the first child and never repeated in the corpus (52,185 heads). A
                    // second one is kept rather than dropped, on a line of its own.
                    let converted = convertNodes(headChildren)
                    heading = heading.map { $0 + [.lineBreak] + converted } ?? converted
                case .listItem(let itemChildren):
                    items.append(ListItemEntry(lead: lead, children: convertNodes(itemChildren)))
                    lead = []
                case .unknown(let name, _, let labelChildren) where name == "label":
                    lead.append(.label(convertNodes(labelChildren)))
                default:
                    let converted = convertNode(child)
                    if !converted.isEmpty { lead.append(.other(converted)) }
                }
            }
            // Whatever follows the last item — a closer, a salute, a gap, or a label with no item
            // after it (none in the corpus) — is drawn after the list rather than lost.
            return [.listBlock(type: type?.rawValue, heading: heading, items: items, trailing: lead)]

        case .listItem:
            // Handled as children of .list; should not appear standalone.
            return []

        // MARK: Structural divisions (Session 07)

        case .editorialNote(let children):
            citingNotes.append(nil)
            defer { citingNotes.removeLast() }
            return [.editorialNoteBlock(convertNodes(children))]

        case .titlePage(let children):
            return [.titlePageBlock(convertNodes(children))]

        // MARK: Figures and formulas (Session 07)

        case .figure(let graphic, let children):
            // #1516: everything the figure prints, converted where it stands — which is also
            // footnote order, should a figure ever hold a note (none of the corpus's 1,035 does).
            // None of it is flat text. An empty figure converts to nothing: history.state.gov
            // prints nothing for one, and neither does the app (owner decision D3c).
            return figureBlock(graphic: graphic, children: children).map { [.figureBlock($0)] } ?? []

        case .elementSpace:
            // #1516 fold-in: drawn as a space by every renderer, counted by no offset walker.
            return [.elementSpace]

        case .formula(let text):
            return [.formulaText(text)]

        // MARK: Inline editorial marks (Session 07)

        case .supplied(let children):
            return [.suppliedText(convertNodes(children))]

        case .sic(let children):
            return [.sicText(convertNodes(children))]

        case .corr(let children):
            return [.corrText(convertNodes(children))]

        // MARK: Line breaks (Session 07)

        case .lineBreak:
            return [.lineBreak]

        // MARK: Dates (Session 36)

        case .date(_, _, _, _, _, let children):
            // The structured date attributes (@when/@from/@to) are consumed by the
            // indexing pipeline only. Rendering passes through the display-text children
            // unchanged so the dateline reads identically to before this change.
            return convertNodes(children)

        // MARK: Attachments (Session 78)

        case .attachment(let n, let children):
            // Convert each child, but promote <head> children to .attachmentHeading
            // so the renderer can apply secondary heading style without extra context.
            let convertedChildren: [FRUSRenderNode] = children.flatMap { child -> [FRUSRenderNode] in
                if case .head(let headChildren) = child {
                    return [.attachmentHeading(convertNodes(headChildren))]
                }
                return convertNode(child)
            }
            return [.attachmentBlock(n: n, children: convertedChildren)]

        case .unknown(let name, _, let children) where name == "abbr":
            // Try to resolve the abbreviation text against the volume's glossary.
            // If a match is found, emit a `.glossLink` identical to an explicit
            // `<gloss ref="…">` element so the renderer styles it and the URL scheme
            // handler can open GlossDetailSheet on tap.
            let abbText = children.map(\.plainText).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !abbText.isEmpty, let entry = abbrLookup?(abbText) {
                return [.glossLink(
                    ref: "#\(entry.ref)",
                    children: convertNodes(children),
                    entry: entry
                )]
            }
            // No matching glossary entry — fall through as plain text.
            return convertNodes(children)

        case .unknown(let name, _, let children):
            return [.unknown(name: name, children: convertNodes(children))]
        }
    }

    // MARK: - Figures (#1516)

    /// The XHTML elements of the video players three public-diplomacy volumes embed in a
    /// `<figure>`: 12 `<object>` players with their `<script>`s and `<param>`s in
    /// `frus1917-72PubDip`, and 8 `<iframe>`s in volumes VI and VII. Their wrapping XHTML `<div>`s
    /// are transparent to the parser, so these reach the figure as its own children. The app
    /// cannot play them and prints none of their content — a `<script>`'s text least of all.
    private static let videoPlayerElements: Set<String> = ["iframe", "object", "script", "embed", "param"]

    /// Converts a `<figure>`'s content, or returns `nil` for a figure that prints nothing: one
    /// with no graphic, no head, no text and no video.
    ///
    /// - `<head>` → the figure's head, above the image; a second head joins it on a line of its own.
    /// - `<p>` → one caption line, its content converted like any inline content.
    /// - `<figDesc>` → one caption line, and the image's alternative text.
    /// - a video player's elements, and loose text beside them → no content; the figure links to
    ///   its page instead.
    /// - anything else the TEI may put there → a caption line of its own, so nothing is dropped.
    private mutating func figureBlock(graphic: String?, children: [FRUSASTNode]) -> FigureBlock? {
        var head: [FRUSRenderNode]?
        var captions: [[FRUSRenderNode]] = []
        var description: String?
        let isVideo = children.contains { child in
            if case .unknown(let name, _, _) = child { return Self.videoPlayerElements.contains(name) }
            return false
        }
        for child in children {
            switch child {
            case .head(let headChildren):
                let converted = convertNodes(headChildren)
                head = head.map { $0 + [.lineBreak] + converted } ?? converted
            case .paragraph(let paragraphChildren):
                let converted = convertNodes(paragraphChildren)
                if !converted.isEmpty { captions.append(converted) }
            case .unknown(let name, _, let descChildren) where name == "figDesc":
                let converted = convertNodes(descChildren)
                guard !converted.isEmpty else { continue }
                captions.append(converted)
                let text = Self.flatText(converted)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                if !text.isEmpty { description = text }
            case .unknown(let name, _, _) where Self.videoPlayerElements.contains(name):
                continue
            case .text where isVideo:
                // The player's own hidden text: `frus1917-72PubDip` opens each of its 12 players
                // with `<div style="display:none"> 298x530 </div>`, and the parser passes an XHTML
                // `<div>`'s content up to the figure.
                continue
            case .text(let string) where string.allSatisfy(\.isWhitespace):
                continue
            default:
                let converted = convertNode(child)
                if !converted.isEmpty { captions.append(converted) }
            }
        }
        let image = graphic.flatMap { name -> FigureImageName? in
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : FigureImageName(volumeId: volumeId, graphic: name)
        }
        guard image != nil || head != nil || !captions.isEmpty || isVideo else { return nil }
        let videoURL = isVideo
            ? volumeId.flatMap { FRUSCanonicalURL.url(volumeId: $0, documentId: documentId) }
            : nil
        return FigureBlock(image: image, imageDescription: description, head: head,
                           captions: captions, videoURL: videoURL, isVideo: isVideo)
    }

    private func isBlockNode(_ node: FRUSRenderNode) -> Bool {
        switch node {
        case .paragraph, .heading, .dateline, .letterOpener, .letterCloser,
             .salutation, .editorialNoteBlock, .tableBlock, .listBlock, .figureBlock,
             .attachmentBlock, .attachmentHeading, .titlePageBlock:
            return true
        default:
            return false
        }
    }
}
