// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// The app's half of the collection exporters' shared types (FRUS Explorer Light, S18a). The
// payloads, options, presets and naming are FRUSCoreKit's (`FRUSCoreKit/Collections/
// CollectionExporter.swift`); what reads a SwiftData `Collection`, Apple Intelligence, the method
// appendix or AppKit and UIKit stays here, with the format list the export sheet offers.

// MARK: - CollectionPreset

extension CollectionPreset {

    /// Overwrites `collection`'s composition **fields** to the preset's recipe. Apparatus is added
    /// separately by the host (see `apparatusBlocks(notAlreadyIn:)`); this touches only scalar
    /// fields, which every host reads live via `@Bindable`, so the preview updates immediately.
    @MainActor
    func applyFields(to collection: Collection) {
        let r = recipe
        collection.defaultBodyDepth = r.bodyDepth.rawValue
        collection.effectiveIncludeFootnotes = r.footnotes
        collection.effectiveIncludeSourceNote = r.sourceNote
        collection.includeNotes = r.notes
        collection.defaultIncludeHeadnote = r.headnotes
        collection.applyHighlights = r.highlights
        collection.includeWordCloud = r.wordCloud
        collection.tocStyle = r.toc.rawValue
    }

    /// Whether `collection`'s current composition scalar fields all equal this preset's recipe —
    /// i.e. this preset is the collection's active starting composition, so the Composer preset
    /// grid highlights its card (Composer v2). Apparatus is intentionally NOT compared: preset
    /// apparatus is append-only/non-destructive, so a collection carrying extra blocks still matches.
    @MainActor
    func matches(_ collection: Collection) -> Bool {
        let r = recipe
        return collection.defaultBodyDepth == r.bodyDepth.rawValue
            && collection.effectiveIncludeFootnotes == r.footnotes
            && collection.effectiveIncludeSourceNote == r.sourceNote
            && collection.includeNotes == r.notes
            && collection.defaultIncludeHeadnote == r.headnotes
            && collection.applyHighlights == r.highlights
            && collection.includeWordCloud == r.wordCloud
            && collection.tocStyle == r.toc.rawValue
    }
}

// MARK: - CollectionBodyDepth

extension CollectionBodyDepth {

    /// The body depths a user can choose given the device / AI configuration.
    /// `.summaryOnly` is gated on Apple Intelligence being available.
    @MainActor
    static var available: [CollectionBodyDepth] {
        AppleIntelligenceProvider.shared.isAvailable
            ? allCases
            : allCases.filter { $0 != .summaryOnly }
    }
}

// MARK: - CollectionExportOptions

extension CollectionExportOptions {

    /// The options `collection`'s own composition settings give: what the Composition section
    /// stores, with nothing decided by the format.
    ///
    /// One builder for the two callers that used to write the same eight lines apart: the export
    /// sheet (through ``ExportFormat/exportOptions(for:)``) and the content resolver's
    /// `resolutionOptions(for:)`. The sheet's copy had grown a format test on the word cloud that
    /// the resolver's never had, which is how the Word export lost its cloud (#1585).
    ///
    /// - Parameter collection: The collection being exported.
    init(composing collection: Collection) {
        self.init(
            tocStyle:          CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            includeFootnotes:  collection.effectiveIncludeFootnotes,
            includeSourceNote: collection.effectiveIncludeSourceNote,
            applyHighlights:   collection.applyHighlights,
            includeNotes:      collection.includeNotes,
            summaryPromptId:   collection.summaryPromptId,
            includeWordCloud:  collection.includeWordCloud,
            includeHeadnoteDefault: collection.defaultIncludeHeadnote
        )
    }
}

// MARK: - ExportFormat

/// Supported output formats for collection export.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 82: added `.docx` backed by `DocxCollectionExporter`
///   1.2 — Session 155: added `.zoteroJSON` backed by `ZoteroCollectionExporter`
///          (Zotero JSON exchange format, one item per document)
///   1.3 — Session 164: `.zoteroJSON` now emits RIS (`.ris`)
///   1.4 — Zotero strategy: `.zoteroJSON` (RIS) is the **Zotero desktop**
///          fallback only — iOS Zotero has no RIS import. The annotation-
///          preserving path on both platforms is the Zotero Web API (separate).
///   1.5 — Collections rework Phase 4 (D7): added `.bibtex` (`.bib`) backed by
///          `BibTeXCollectionExporter`, for LaTeX / non-Zotero reference managers.
///   1.6 — Collections rework Phase 4 (D9): added `.fruscollection` — the native,
///          round-trippable collection file. It is not a `CollectionExporter` (it
///          serializes the collection's *source* via `NativeCollectionSerializer`), so
///          `makeExporter()` returns `nil` for it and the export flow special-cases it.
///   1.7 — 2026-10-09: #1585 — `drawsWordCloud` and `exportOptions(for:)`: the format says
///          whether it draws the word cloud, Word included, and builds the options its exporter
///          is handed
///   1.8 — 2026-10-25 (FRUS Explorer Light, S18a): in `CollectionExporter+App.swift`, since the payloads
///          and options it builds are FRUSCoreKit's and it makes the app's exporters; `makeExporter()`
///          hands the HTML exporter, now the kit's, the app's figure store and word-cloud drawing, which
///          it read for itself
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case html
    case docx
    case zoteroJSON
    case bibtex
    case fruscollection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf:        return "PDF"
        case .html:       return "HTML"
        case .docx:       return "DOCX"
        case .zoteroJSON: return String(localized: "export.format.zotero",
                                        defaultValue: "Zotero RIS (desktop)")
        case .bibtex:     return String(localized: "export.format.bibtex",
                                        defaultValue: "BibTeX")
        case .fruscollection: return String(localized: "export.format.native",
                                            defaultValue: "FRUS Collection (shareable)")
        }
    }

    /// The card title in the Composer v2 export format grid (§ Export): the short, canvas-exact
    /// label (`.zoteroJSON` reads as "RIS" there — the web-API send is a separate row).
    var gridLabel: String {
        switch self {
        case .pdf:            return "PDF"
        case .html:           return "HTML"
        case .docx:           return String(localized: "export.grid.docx.title", defaultValue: "Word")
        case .bibtex:         return "BibTeX"
        case .zoteroJSON:     return String(localized: "export.grid.ris.title", defaultValue: "RIS")
        case .fruscollection: return String(localized: "export.grid.native.title", defaultValue: ".fruscollection")
        }
    }

    /// The one-line descriptor under the format card's title (Composer v2 export grid).
    ///
    /// HTML's said "Web page + word cloud" until #1688, as though it alone carried the cloud: PDF and Word draw it
    /// too when Word-cloud overview is on (`options.includeWordCloud`, Word since #1621).
    var gridCaption: String {
        switch self {
        case .pdf:            return String(localized: "export.grid.pdf.caption", defaultValue: "Formatted reader")
        case .html:           return String(localized: "export.grid.html.caption.v2", defaultValue: "Web page")
        case .docx:           return String(localized: "export.grid.docx.caption", defaultValue: "Editable .docx")
        case .bibtex:         return String(localized: "export.grid.bibtex.caption", defaultValue: "Reference manager")
        case .zoteroJSON:     return String(localized: "export.grid.ris.caption", defaultValue: "Zotero / EndNote")
        case .fruscollection: return String(localized: "export.grid.native.caption", defaultValue: "Editable copy for a colleague")
        }
    }

    /// The formats offered in the export grid, in canvas order (PDF · HTML · Word · BibTeX · RIS ·
    /// .fruscollection). The native `.fruscollection` file is dropped for smart (saved-search)
    /// collections until they're snapshotted (D8/D9b); the web-API Zotero send is a separate row,
    /// not a grid card.
    static func gridFormats(smartCollection: Bool) -> [ExportFormat] {
        let ordered: [ExportFormat] = [.pdf, .html, .docx, .bibtex, .zoteroJSON, .fruscollection]
        return smartCollection ? ordered.filter { $0 != .fruscollection } : ordered
    }

    var fileExtension: String {
        switch self {
        case .zoteroJSON:     return "ris"
        case .bibtex:         return "bib"
        case .fruscollection: return NativeCollectionSerializer.fileExtension
        default:              return rawValue
        }
    }

    /// Whether an export in this format prints a figure's image (#1516): PDF, Word and HTML do.
    /// BibTeX and RIS print citations, and the native file carries the collection's source, so
    /// an export in one of those fetches no image.
    var printsFigureImages: Bool {
        switch self {
        case .pdf, .html, .docx: return true
        case .zoteroJSON, .bibtex, .fruscollection: return false
        }
    }

    /// Whether an export in this format draws the collection's word-cloud overview when the
    /// collection asks for one: PDF, HTML and Word do (#1585). BibTeX and RIS print citations, and
    /// the native file carries the setting itself, not a drawing.
    var drawsWordCloud: Bool {
        switch self {
        case .pdf, .html, .docx: return true
        case .zoteroJSON, .bibtex, .fruscollection: return false
        }
    }

    /// The options the export sheet hands this format's exporter for `collection`: the
    /// collection's composition, with the word cloud asked for only of a format that draws one.
    ///
    /// On the format, and not in the sheet, so that a test hands an exporter exactly what the
    /// sheet does. Until #1585 the sheet built these itself and asked for the cloud of PDF and
    /// HTML only, a condition older than the Word exporter's cloud (#960): the Word exporter drew
    /// the cloud whenever it was asked, the parity test asked it directly, and the app never did.
    ///
    /// - Parameter collection: The collection being exported.
    /// - Returns: The options for this format's exporter.
    func exportOptions(for collection: Collection) -> CollectionExportOptions {
        var options = CollectionExportOptions(composing: collection)
        options.includeWordCloud = options.includeWordCloud && drawsWordCloud
        return options
    }

    /// Returns a fresh exporter instance for this format, or `nil` for `.fruscollection`,
    /// which is produced by `NativeCollectionSerializer` (it serializes the collection's
    /// source rather than rendering resolved content) and handled directly by the export flow.
    func makeExporter() -> (any CollectionExporter)? {
        switch self {
        case .pdf:            return PDFCollectionExporter()
        case .html:           return HTMLCollectionExporter(figureImages: FigureImageStore.shared,
                                                            wordCloud: CollectionWordCloud.drawnByTheApp)
        case .docx:           return DocxCollectionExporter()
        case .zoteroJSON:     return ZoteroCollectionExporter()
        case .bibtex:         return BibTeXCollectionExporter()
        case .fruscollection: return nil
        }
    }
}

// MARK: - CollectionWordCloud

extension CollectionWordCloud {

    /// The collection's word cloud as the app draws it: `WordCloudExporter.collectionCloudImage`, the
    /// image the PDF export draws too, as its PNG and its size in pixels. The HTML and Word exporters,
    /// which are FRUSCoreKit's, are handed this by `ExportFormat.makeExporter()`.
    ///
    /// - Parameters:
    ///   - texts: The documents' body texts.
    ///   - title: The collection's name, the caption drawn under the cloud.
    /// - Returns: The image, or `nil` when the texts give no term to draw.
    @MainActor
    static func drawnByTheApp(texts: [String], title: String) async -> CollectionWordCloud? {
        guard let rendered = await WordCloudExporter.collectionCloudImage(texts: texts, title: title),
              let png = Data(base64Encoded: rendered.pngBase64) else { return nil }
        return CollectionWordCloud(png: png, pixelWidth: rendered.cgImage.width,
                                   pixelHeight: rendered.cgImage.height)
    }
}

// MARK: - CollectionExportMetadata

extension CollectionExportMetadata {

    /// Resolves the method-appendix lines from the toggle + the appendix — pure, so the gating is
    /// unit-testable without the SwiftData fetch at the call site.
    ///
    /// Returns `[]` when disabled or when the narrowed appendix has no rows. An appendix with a
    /// heading and caveats but no searches would be a methods section asserting a method that was
    /// never used, which is worse than omitting it.
    ///
    /// - Parameters:
    ///   - enabled: `Collection.includeMethodAppendix`.
    ///   - appendix: the appendix, **already narrowed** to the export's project.
    static func methodAppendix(enabled: Bool, appendix: QueryMethodAppendix?) -> [String] {
        guard enabled, let appendix, !appendix.rows.isEmpty else { return [] }
        return appendix.plainTextLines
    }
}

// MARK: - CollectionProse

/// The app's decoder for a rich-text prose block — supplied as **RTF** `Data`, as the editor
/// stores it — into the paragraphs of `ProseFormattedSpan` the exporters render. The span rules are
/// FRUSCoreKit's (`append(text:bold:italic:underline:colorHex:linkURL:to:)`, `hex(r:g:b:)`); reading
/// the stored bytes needs AppKit or UIKit, so it stays here. `CollectionContentResolver` decodes
/// each block when it builds the item, so every format renders the same spans.
///
/// **Data-loss guard.** A payload that fails the RTF decode is *not* dropped: a legacy
/// Phase 3b blob (the `AttributedString`'s own JSON `Codable` encoding, written before the
/// RTF switch and still reachable via CloudKit sync or `.fruscollection` files) is decoded
/// directly, with bold/italic recovered from `inlinePresentationIntent`. Only data that is
/// neither format yields `[]` — and `ProseRichText.exportRTF(from:)` never emits such a
/// payload, falling back to the entry's plain `text` instead.
///
/// **Colours are read as the light appearance draws them.** Text typed in the editor carries
/// the text view's dynamic colour, `NSColor.textColor` on the Mac and `UIColor.label` on iOS,
/// which RTF stores by name (`\cname textColor`, `\cname labelColor`). The Mac reads either
/// name back as that dynamic colour; iOS reads `labelColor` so, and `textColor`, a name UIKit
/// does not know, as the black its colour table holds. Resolved under the current appearance,
/// which outside drawing is whatever the thread was last left with, typed text was white
/// whenever that was dark: `color:#FFFFFF` in HTML, `w:color FFFFFF` in Word, white text in a
/// PDF, and white on the live preview's page, which is always light. Resolved for the light
/// appearance it is black, which `hex(r:g:b:)` reads as no colour. A system colour takes its
/// light shade at standard contrast, which iOS's Increase Contrast draws in a shade of its own;
/// a fixed colour is unchanged.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): the RTF and legacy JSON decoder, from
///          `CollectionExporter.swift`, which moved to FRUSCoreKit with the span rules
extension CollectionProse {
    /// Decodes `rtf` into paragraphs of formatted spans, resolving paragraph breaks *before*
    /// spans are emitted so callers never straddle a paragraph boundary with a single run.
    /// Falls back to the legacy Phase 3b JSON `AttributedString` encoding when the RTF
    /// decode fails (see the type doc), so pre-RTF prose still renders in every exporter.
    ///
    /// - Returns: One inner array per paragraph; empty (`[]`) when the data is empty or is
    ///   decodable as neither RTF nor the legacy JSON encoding.
    static func paragraphs(fromRTF rtf: Data) -> [[ProseFormattedSpan]] {
        if let ns = ProseRichText.decodedRTF(rtf) {
            return ns.length > 0 ? paragraphs(fromDecoded: ns) : []
        }
        if let legacy = ProseRichText.legacyJSONAttributedString(rtf) {
            return paragraphs(fromLegacy: legacy)
        }
        return []
    }

    /// Emits spans for a decoded RTF body: bold/italic from the run's concrete font traits,
    /// underline from the underline-style attribute, colour from the foreground colour,
    /// link URL from the `.link` attribute (`URL` or `String` valued — the RTF reader
    /// restores `HYPERLINK` fields as `NSURL`).
    private static func paragraphs(fromDecoded ns: NSAttributedString) -> [[ProseFormattedSpan]] {
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        let plain = ns.string as NSString
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length), options: []) { attrs, range, _ in
            var bold = false, italic = false, underline = false
            var colorHex: String?
            var linkURL: String?
            if let link = attrs[.link] {
                linkURL = (link as? URL)?.absoluteString ?? (link as? String)
            }
            #if canImport(AppKit)
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.bold); italic = traits.contains(.italic)
            }
            if let color = attrs[.foregroundColor] as? NSColor { colorHex = hexColor(color) }
            #elseif canImport(UIKit)
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.traitBold); italic = traits.contains(.traitItalic)
            }
            if let color = attrs[.foregroundColor] as? UIColor { colorHex = hexColor(color) }
            #endif
            if let style = attrs[.underlineStyle] as? Int, style != 0 { underline = true }

            append(text: plain.substring(with: range), bold: bold, italic: italic,
                   underline: underline, colorHex: colorHex, linkURL: linkURL, to: &paragraphs)
        }
        return paragraphs
    }

    /// Emits spans for a legacy Phase 3b body: bold/italic from each run's Foundation
    /// `inlinePresentationIntent` (the only formatting that encoding carried — Phase 3b had
    /// no underline or colour affordances).
    private static func paragraphs(fromLegacy attributed: AttributedString) -> [[ProseFormattedSpan]] {
        guard !attributed.characters.isEmpty else { return [] }
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        for run in attributed.runs {
            let intent = run.inlinePresentationIntent ?? []
            append(text: String(attributed.characters[run.range]),
                   bold: intent.contains(.stronglyEmphasized),
                   italic: intent.contains(.emphasized),
                   underline: false, colorHex: nil, linkURL: nil, to: &paragraphs)
        }
        return paragraphs
    }

    // MARK: - Colour helpers

    #if canImport(AppKit)
    /// `RRGGBB` for a colour as the light appearance draws it, or `nil` for (near-)black
    /// default text. `usingColorSpace(_:)` resolves a catalog colour under the current
    /// drawing appearance, so it is resolved under Aqua here, whatever appearance the export
    /// runs under (see the type doc). The call puts back the appearance it found, as a view's
    /// drawing does.
    private static func hexColor(_ color: NSColor) -> String? {
        var light: NSColor?
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            light = color.usingColorSpace(.sRGB)
        }
        guard let c = light ?? color.usingColorSpace(.sRGB) else { return nil }
        return hex(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)
    }
    #elseif canImport(UIKit)
    /// `RRGGBB` for a colour as the light appearance draws it, or `nil` for (near-)black
    /// default text. `getRed(_:green:blue:alpha:)` resolves a dynamic colour with the current
    /// trait collection, so it is resolved for the light style here, whatever appearance the
    /// export runs under (see the type doc).
    private static func hexColor(_ color: UIColor) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        return hex(r: r, g: g, b: b)
    }
    #endif
}
