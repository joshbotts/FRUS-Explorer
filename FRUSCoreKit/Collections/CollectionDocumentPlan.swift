// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionExportPlan

/// What a collection's export prints, decided once for the web page, the PDF and Word (L34; the
/// Collections design §3.8): the contents list's rows, and each document's lines in order.
///
/// Until L34 each exporter decided for itself what a document's parts were, in what order and under
/// what words, and the three drifted: the PDF's contents list stopped at its first page (#1984), the
/// source note printed twice (#1991), the web page numbered its contents rows with its sections and
/// blocks among them (#1993), a title of the author's stood with nothing of the volume's beside it
/// (#1998), and a call whose note did not print was a button that did nothing (#2007). The exporters
/// now draw this plan in order. **None decides a part's presence, place or wording**; each keeps its
/// own typography and pagination.
///
/// **The highlight walk is untouched.** Every node of a document's text is drawn, and the plan's words
/// that are not the volume's (*As published:*, a call drawn as text) are drawn outside the walk that
/// counts highlight offsets, as *Source:* always was.
///
/// Version history:
///   1.0 — L34: initial implementation
public struct CollectionExportPlan: Sendable {

    /// The contents list's rows, in the items' order: a section's heading, an apparatus block's title,
    /// and each document, the documents alone numbered (#1993).
    public let contents: [CollectionContentsRow]
    /// One entry per item, in the items' order: the item, and the document's plan where it is one.
    public let items: [Item]

    /// One item and what the plan decided for it.
    public struct Item: Sendable {
        /// The item, as the assembly resolved it.
        public let item: CollectionExportItem
        /// The level the item's heading takes in the export's outline: a section's own (its level + 1,
        /// the collection's title being 1), a document's leading line, an apparatus block's title.
        /// `nil` for prose and an excerpt, which have none.
        public let headingLevel: Int?
        /// The document's plan, where the item is a document.
        public let document: CollectionDocumentPlan?
    }

    /// Plans an export.
    ///
    /// - Parameters:
    ///   - items: The resolved items, in order.
    ///   - options: The export's options.
    ///   - forPreview: Whether the plan is the live preview's, which marks a requested headnote with
    ///     nothing stored (``CollectionDocumentPlan/isHeadnoteMissing``) for its author.
    public init(items: [CollectionExportItem], options: CollectionExportOptions, forPreview: Bool = false) {
        var planned: [Item] = []
        var sectionLevel = 0
        for item in items {
            switch item {
            case .heading(_, let level):
                sectionLevel = CollectionContentsRow.clamped(level)
                planned.append(Item(item: item, headingLevel: sectionLevel + 1, document: nil))
            case .generated:
                // A block is titled at a section's first level: it is listed in the contents as one.
                planned.append(Item(item: item, headingLevel: 2, document: nil))
            case .document(let doc):
                let plan = CollectionDocumentPlan(document: doc, options: options, sectionLevel: sectionLevel,
                                                  forPreview: forPreview)
                planned.append(Item(item: item, headingLevel: plan.documentLevel, document: plan))
            case .prose, .excerpt:
                planned.append(Item(item: item, headingLevel: nil, document: nil))
            }
        }
        self.items = planned
        self.contents = CollectionContentsRow.rows(for: items, style: options.tocStyle)
    }
}

// MARK: - CollectionContentsRow

/// One row of a collection's contents list, as all three formats print it (L34).
///
/// - **The documents alone are numbered, in collection order** (#1993). A section's heading and an
///   apparatus block's title are rows without a number. The web page's ordered list counted every row,
///   so its fourth document was row 6 where the PDF and Word called it 4.
/// - **A row quotes the volume's heading through the one reading** (`DocumentHeadingReading`): its words
///   without the volume's own number, which the row's number would stand beside (#2002), and without
///   its calls (#1992), with the dateline wherever the document prints one (#1994).
/// - **A title of the author's never stands alone** (#1998; decisions 154 and 197): under it, in small
///   type, *As published:* and the volume's heading as the volume prints it, its own number kept, and in
///   *Citation* style the citation after that (J46).
///
/// Version history:
///   1.0 — L34 (#1993, #1994, #1998, #2002): initial implementation
public struct CollectionContentsRow: Sendable, Equatable {

    /// What a row lists.
    public enum Kind: Sendable, Equatable {
        /// A document, with its number among the collection's documents.
        case document(number: Int)
        /// A section's heading.
        case section
        /// An apparatus block's title.
        case block
    }

    /// What the row lists.
    public let kind: Kind
    /// The row's nesting: a section's own level, 1 to 3, and for a document or a block the level of the
    /// section it is in (1 outside any).
    public let level: Int
    /// The row's first line, without its number: the words a format prints after "4. ".
    public let text: String
    /// The lines under it, in small type, each a line of its own.
    public let lines: [String]
    /// The document the row links to, where it lists one.
    public let document: CollectionExportDocument?

    /// Creates a row.
    public init(kind: Kind, level: Int, text: String, lines: [String] = [], document: CollectionExportDocument? = nil) {
        self.kind = kind
        self.level = level
        self.text = text
        self.lines = lines
        self.document = document
    }

    /// The document's number among the collection's documents, or `nil` for a section or a block.
    public var number: Int? {
        if case .document(let number) = kind { return number }
        return nil
    }

    /// The first line as printed: "4. The Long Telegram" for a document, the text alone otherwise.
    public var numberedText: String {
        number.map { "\($0). \(text)" } ?? text
    }

    /// Two rows are the same row: the same kind, level and words. The document is the row's link, not its
    /// words.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.kind == rhs.kind && lhs.level == rhs.level && lhs.text == rhs.text && lhs.lines == rhs.lines
    }

    /// A heading level clamped to the outline's (`CollectionOutline.maxLevel`).
    static func clamped(_ level: Int) -> Int { min(max(level, 1), CollectionOutline.maxLevel) }

    /// The rows of `items`' contents list in `style`. Prose and an excerpt are no row.
    ///
    /// - Parameters:
    ///   - items: The resolved items, in order.
    ///   - style: The collection's contents style.
    /// - Returns: The rows, in the items' order.
    public static func rows(for items: [CollectionExportItem], style: CollectionToCStyle) -> [CollectionContentsRow] {
        var rows: [CollectionContentsRow] = []
        var level = 1
        var number = 0
        for item in items {
            switch item {
            case .heading(let text, let raw):
                level = clamped(raw)
                rows.append(CollectionContentsRow(kind: .section, level: level, text: text))
            case .generated(let block):
                rows.append(CollectionContentsRow(kind: .block, level: level, text: block.title))
            case .document(let doc):
                number += 1
                let (text, lines) = documentLines(doc, style: style)
                rows.append(CollectionContentsRow(kind: .document(number: number), level: level, text: text,
                                                  lines: lines, document: doc))
            case .prose, .excerpt:
                break
            }
        }
        return rows
    }

    /// A document row's first line and the lines under it.
    static func documentLines(_ doc: CollectionExportDocument, style: CollectionToCStyle) -> (String, [String]) {
        let reading = DocumentHeadingReading(indexedHeader: doc.header, indexedDateline: doc.dateline)
        let citation = doc.citation.isEmpty ? doc.title : doc.citation
        if let title = doc.trimmedTitleOverride {
            var lines: [String] = []
            let published = [reading.printedHeading, style == .headerAndDateline ? reading.dateline : nil]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
            if !reading.printedHeading.isEmpty {
                lines.append("\(CollectionDocumentPlan.asPublishedLabel) \(published)")
            }
            if style == .citation || reading.printedHeading.isEmpty { lines.append(citation) }
            return (title, lines)
        }
        switch style {
        case .citation:
            return (citation, [])
        case .headerAndDateline:
            guard !reading.words.isEmpty else { return (citation, []) }
            if let dateline = reading.dateline { return ("\(reading.words) — \(dateline)", []) }
            return (reading.words, [])
        }
    }
}

// MARK: - CollectionDocumentPlan

/// The lines one document prints, in order, each with its text, its role, its heading level and its
/// label (L34; the Collections design §3.8 and its three openings, §3.3).
///
/// - **A title of the author's leads wherever one is given**, at the heading's size, and the citation
///   follows as a small line. The volume's heading then stands one level down with *As published:*
///   inside it (decision 154): inside the text, where the text prints; where it does not, as a line of
///   its own read from the one reading, with its dateline under it (#1998, J16).
/// - **Otherwise the citation leads**, at the heading's size, as 1.0 opened every document.
/// - **The volume's heading leads** where ``CollectionExportOptions/volumeHeadingLeads`` asks: the citation
///   is a small line before it, and the document's region carries the citation's number (J16). Nothing
///   sets it before L43, which makes it the collection's *Opening*.
/// - **The source note prints once** (#1991; §3.5): where the volume puts it on the heading (from 1955),
///   among the footnotes; where it leads the document unnumbered (before 1955), as *Source:* after the
///   text, its unlabelled copy and the app's glyph for it left out.
/// - **A requested headnote with nothing stored prints nothing** in an export (J10): 1.0 printed an
///   instruction to the author in a file made for a reader.
///
/// **One heading rule for every level** (J32). The collection's title is level 1 and a section of level
/// *L* is *L* + 1, so a document's leading line is one level below the section it is in. The volume's
/// heading under a title is one level below that, an attachment's heading one level below the volume's,
/// and the document's notes are headed one level below the document's leading line. The web page draws
/// a level past six as a paragraph with the heading role and the level; Word draws each as its outline
/// level.
///
/// Version history:
///   1.0 — L34 (#1991, #1998, #2007; J10, J16, J19, J32): initial implementation
public struct CollectionDocumentPlan: Sendable, Equatable {

    /// The words that mark where the volume's begin, under a title of the author's (decision 154). They
    /// are fixed: an author cannot change or empty them.
    public static var asPublishedLabel: String {
        String(localized: "collection.document.asPublished", defaultValue: "As published:")
    }

    /// How a document opens (§3.3).
    public enum Opening: String, Sendable, Equatable {
        /// The citation leads, at the heading's size, and the volume's heading follows: 1.0's opening.
        case citation
        /// The volume's heading leads, and the citation is a small line above it.
        case volumeHeading
        /// A title of the author's leads.
        case title
    }

    /// What a line is: the role each format draws it by, and the role L60's tagged PDF marks it with.
    public enum Role: String, Sendable, Equatable {
        /// A title of the author's.
        case title
        /// The citation: the document's heading where it leads, a small line otherwise.
        case citation
        /// The document's address on history.state.gov.
        case address
        /// The headnote, with its attribution.
        case headnote
        /// The volume's heading as a line of its own, where the text does not print.
        case volumeHeading
        /// The volume's dateline, under its heading's words, where the text does not print.
        case dateline
        /// The document's text, as the volume prints it: its heading, dateline and body, and its notes.
        case text
        /// A summary, in the text's place.
        case summary
        /// The *Source:* line.
        case sourceNote
        /// The *See also:* line.
        case seeAlso
        /// One research note.
        case researchNote
    }

    /// How a document's text is drawn, where it prints with its render model.
    public struct TextDrawing: Sendable, Equatable {
        /// The words drawn inside the volume's heading before its own (*As published:*), or `nil`.
        public let headingLabel: String?
        /// The level of the volume's heading.
        public let headingLevel: Int
        /// The level of an attachment's heading.
        public let attachmentHeadingLevel: Int
        /// The level of the heading over the document's notes.
        public let notesHeadingLevel: Int
        /// Which notes print, and how each call is drawn.
        public let footnotes: FootnotePrinting
        /// Whether the document's highlights are drawn.
        public let appliesHighlights: Bool
    }

    /// One line the document prints.
    public struct Line: Sendable, Equatable {
        /// What the line is.
        public let role: Role
        /// The line's words, with `_…_` marking italics as each format reads them. Empty for the text.
        public let text: String
        /// The words before the text, set apart: *As published:*, *Source:*, *See also:*, *Headnote*,
        /// *Summary* or *Research Note*. `nil` for a line with none.
        public let label: String?
        /// The level the line is a heading at, or `nil` for a line that is not one.
        public let headingLevel: Int?
        /// The address the line links to, or `nil`.
        public let link: String?
        /// The format a headnote's or a summary's text was written in.
        public let format: ResponseFormat
        /// The caption under a headnote or a summary saying who wrote it, or `nil`.
        public let attribution: String?
        /// How the text is drawn, for the text's line.
        public let drawing: TextDrawing?

        /// Creates a line.
        public init(role: Role, text: String, label: String? = nil, headingLevel: Int? = nil, link: String? = nil,
                    format: ResponseFormat = .general, attribution: String? = nil, drawing: TextDrawing? = nil) {
            self.role = role
            self.text = text
            self.label = label
            self.headingLevel = headingLevel
            self.link = link
            self.format = format
            self.attribution = attribution
            self.drawing = drawing
        }
    }

    /// How the document opens.
    public let opening: Opening
    /// The level of the document's leading line: one below the section it is in.
    public let documentLevel: Int
    /// The lines, in the order they print.
    public let lines: [Line]
    /// Whether the entry asked for a headnote that has nothing stored: an export prints nothing for it
    /// (J10), and only the live preview tells its author.
    public let isHeadnoteMissing: Bool

    /// The line that is the document's heading: the first at the document's level. A line in the text,
    /// the volume's heading where it leads, is not one of the plan's own lines, so it is `nil` there.
    public var headingLine: Line? {
        lines.first { $0.headingLevel == documentLevel }
    }

    /// The citation's number, which names the document's region where the volume's heading leads (J16):
    /// "Document 475" from "…, Document 475.". `nil` for a citation that names no number.
    public let regionName: String?

    // MARK: Planning one document

    /// Plans one document.
    ///
    /// - Parameters:
    ///   - doc: The resolved document.
    ///   - options: The export's options.
    ///   - sectionLevel: The level of the section the document is in, 1 to 3, or 0 outside any.
    ///   - forPreview: Whether the plan is the live preview's.
    public init(document doc: CollectionExportDocument, options: CollectionExportOptions, sectionLevel: Int = 0,
                forPreview: Bool = false) {
        let level = min(max(sectionLevel, 0), CollectionOutline.maxLevel) + 2
        let reading = DocumentHeadingReading(indexedHeader: doc.header, indexedDateline: doc.dateline)
        let citation = doc.citation.isEmpty ? doc.title : doc.citation
        let link = doc.historyStateGovURL.isEmpty ? nil : doc.historyStateGovURL
        let opening: Opening = doc.trimmedTitleOverride != nil ? .title
            : (options.volumeHeadingLeads ? .volumeHeading : .citation)
        // The volume's heading: one level down under a title, the document's heading where it leads.
        let volumeLevel = opening == .title ? level + 1 : level + (opening == .citation ? 1 : 0)
        let label = opening == .title ? Self.asPublishedLabel : nil
        var lines: [Line] = []

        // The opening: a title, or the citation at the heading's size, or the citation as a small line.
        switch opening {
        case .title:
            lines.append(Line(role: .title, text: doc.trimmedTitleOverride ?? "", headingLevel: level))
            lines.append(Line(role: .citation, text: citation, link: link))
        case .citation:
            lines.append(Line(role: .citation, text: citation, headingLevel: level, link: link))
        case .volumeHeading:
            lines.append(Line(role: .citation, text: citation, link: link))
        }
        if let link { lines.append(Line(role: .address, text: link, link: link)) }

        // The headnote, above the volume's words: it is the author's, or the app's for them.
        let headnote = doc.headnoteText.flatMap { $0.isEmpty ? nil : $0 }
        if doc.includeHeadnote, let headnote {
            lines.append(Line(role: .headnote, text: headnote, label: Self.headnoteLabel, format: doc.headnoteFormat,
                              attribution: CollectionAIAttribution.headnoteLabel(authorship: doc.headnoteAuthorship)))
        }

        // The text, a summary or nothing, by the document's depth.
        let includeFootnotes = doc.includeFootnotesOverride ?? options.includeFootnotes
        let sourceNote = doc.sourceNoteText.flatMap { $0.isEmpty ? nil : $0 }
        var printsSourceLine = sourceNote != nil
        let textPrints = doc.bodyDepth == .full && (doc.renderModel != nil || !doc.bodyText.isEmpty)
        if doc.bodyDepth == .full, let model = doc.renderModel {
            let printing = Self.footnotePrinting(model: model, includeFootnotes: includeFootnotes,
                                                 sourceLinePrints: printsSourceLine)
            printsSourceLine = printing.sourceLinePrints
            lines.append(Line(role: .text, text: "", drawing: TextDrawing(
                headingLabel: label, headingLevel: volumeLevel, attachmentHeadingLevel: volumeLevel + 1,
                notesHeadingLevel: level + 1, footnotes: printing.footnotes,
                appliesHighlights: doc.applyHighlightsOverride ?? options.applyHighlights)))
        } else if textPrints {
            // A body with no render model prints as its flat text, the heading's words among them.
            lines.append(Line(role: .text, text: doc.bodyText))
        } else {
            // Where the text does not print, the volume's heading is a line of its own under a title or
            // where it leads, with its dateline under it (#1998, J16).
            if opening != .citation, !reading.printedHeading.isEmpty {
                lines.append(Line(role: .volumeHeading, text: reading.printedHeading, label: label,
                                  headingLevel: volumeLevel))
                if let dateline = reading.dateline { lines.append(Line(role: .dateline, text: dateline)) }
            }
            if doc.bodyDepth == .summaryOnly, let summary = doc.summaryText, !summary.isEmpty {
                lines.append(Line(role: .summary, text: summary, label: Self.summaryLabel, format: doc.summaryFormat,
                                  attribution: CollectionAIAttribution.label()))
            }
        }

        // After the text: the source note, the documents it names in the collection, the research notes.
        if printsSourceLine, let sourceNote {
            lines.append(Line(role: .sourceNote, text: SourceNoteDisplay.withoutLeadingLabel(sourceNote),
                              label: Self.sourceLabel))
        }
        if !doc.relatedDocumentCitations.isEmpty {
            // Each citation's own period comes off before the "; " join, and the line ends in one (#1392).
            let joined = doc.relatedDocumentCitations.map(CitationPunctuation.withoutTerminalPeriod)
                .joined(separator: "; ") + "."
            lines.append(Line(role: .seeAlso, text: joined, label: Self.seeAlsoLabel))
        }
        if doc.includesNotes(options: options) {
            for note in doc.noteTexts where !note.isEmpty {
                lines.append(Line(role: .researchNote, text: note, label: Self.researchNoteLabel))
            }
        }

        self.opening = opening
        self.documentLevel = level
        self.lines = lines
        self.isHeadnoteMissing = forPreview && doc.includeHeadnote && headnote == nil
        self.regionName = opening == .volumeHeading ? Self.citationNumber(citation) : nil
    }

    // MARK: The source note, once

    /// Which notes a document's text prints, and whether the *Source:* line prints beside them (#1991; the
    /// design's §3.5).
    ///
    /// | Where the volume has the source note | Both on | Footnotes on, Source note off | Footnotes off, Source note on |
    /// |---|---|---|---|
    /// | A footnote on the heading (from 1955) | among the footnotes, once | among the footnotes | *Source:* after the text |
    /// | A line above the heading, unnumbered (before 1955) | *Source:* after the text, once | among the footnotes | *Source:* after the text |
    ///
    /// The era is read from where the note's call is, never from whether it is numbered: 29 volumes of
    /// 1955 on number the note on the heading `n="0"`, which the app reads as unnumbered
    /// (`ASTToRenderNodeConverter.printedLabel(from:)`). A note the source note calls goes with it.
    ///
    /// - Parameters:
    ///   - model: The document's render model.
    ///   - includeFootnotes: Whether the document's footnotes print.
    ///   - sourceLinePrints: Whether the *Source:* line has a note to print.
    /// - Returns: The notes that print, and whether the *Source:* line does.
    public static func footnotePrinting(model: FRUSDocumentRenderModel, includeFootnotes: Bool,
                                        sourceLinePrints: Bool) -> (footnotes: FootnotePrinting, sourceLinePrints: Bool) {
        guard includeFootnotes else { return (.none, sourceLinePrints) }
        let sourceKeys = model.sourceNoteKeys
        guard sourceLinePrints, !sourceKeys.isEmpty else { return (.all, sourceLinePrints) }
        // From 1955: the heading calls its source note, and that call must keep its note.
        if !model.headingCallKeys.isDisjoint(with: sourceKeys) { return (.all, false) }
        // Before 1955: the labelled line is the copy kept, and the unlabelled one goes with what it calls.
        let leftOut = sourceKeys.union(model.keysCited(inNotes: sourceKeys))
        return (FootnotePrinting(printedKeys: Set(model.footnoteKeys).subtracting(leftOut)), true)
    }

    // MARK: Words

    /// The label over a headnote.
    static var headnoteLabel: String {
        String(localized: "collection.headnote.label", defaultValue: "Headnote")
    }

    /// The label over a summary.
    static var summaryLabel: String {
        String(localized: "collection.summary.label", defaultValue: "Summary")
    }

    /// The label before a source note.
    static var sourceLabel: String {
        String(localized: "collection.source.label", defaultValue: "Source:")
    }

    /// The label before the documents a document names in the collection.
    static var seeAlsoLabel: String {
        String(localized: "collection.related.label", defaultValue: "See also:")
    }

    /// The label over a research note.
    static var researchNoteLabel: String {
        String(localized: "collection.researchNote.label", defaultValue: "Research Note")
    }

    /// "Document 475" from a citation that ends "…, Document 475.", or `nil`.
    static func citationNumber(_ citation: String) -> String? {
        guard let range = citation.range(of: ", Document ", options: .backwards) else { return nil }
        let number = citation[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return number.isEmpty ? nil : "Document \(number)"
    }
}

// MARK: - CollectionExportDocument's title

extension CollectionExportDocument {
    /// The title of the author's, trimmed, or `nil` where none is given.
    public var trimmedTitleOverride: String? {
        let title = titleOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? nil : title
    }
}
