// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationLookupFields

/// The Parsed Fields a Citation Lookup form holds, and the two values it forwards without showing
/// them, kept as ONE value so a new paste replaces all of them together (#1474).
///
/// Before #1474 the view assigned each field `parsed.x ?? oldValue`, and did nothing when the paste
/// box was cleared. A field the new citation did not name therefore kept the previous citation's
/// value and took part in the next lookup — and a stale Document is not harmless: the engine tries
/// the document number before the page and stops at an exact hit, so a page-only citation pasted
/// after a document citation came back as the stale document, labelled an exact match. Every paste
/// now re-derives every field from scratch.
///
/// A value type with pure functions, so the rules the view follows are testable without the view:
/// `CitationLookupFieldsTests` drives these calls, and `CitationLookupViewWiringTests` reads the
/// view's source to pin that its paste and mode handlers, its Look Up gate and its lookup make
/// them — the defect this replaced was in exactly that wiring.
///
/// Version history:
///   1.0 — #1474: initial implementation, lifted out of `CitationLookupView`
///   1.1 — Session 2026-10-24 (FRUS Explorer Light, S15a): public, with its memberwise initialiser
///          spelled out with the same defaults, so `CitationLookupFields()` is the empty form as
///          before, for the web edition's Structured Entry
///   1.2 — #1977: the Document field holds the number as printed, and reaches the lookup as one
public struct CitationLookupFields: Equatable, Sendable {

    /// The Subseries field, e.g. `"1969-76"`.
    public var subseries = ""
    /// The Volume field, e.g. `"II"` or `"2"`.
    public var volume = ""
    /// The Part field, e.g. `"1"` or `"I"` (#1474).
    public var part = ""
    /// The Document no. field: the number as printed, `15`, `1190b`, `GT–6` or `C` (#1977), which
    /// `input(mode:pasteText:parser:)` reads through `CitationParser.normalizedDocumentNumber(_:)`.
    /// Until #1977 it was read as an `Int`, so a number with a letter typed in Structured Entry, or
    /// pasted and then left alone, named no document at all.
    public var document = ""
    /// The Page field.
    public var page = ""
    /// The paste's title fragment. Not shown, but forwarded in Paste mode so the matcher can
    /// correct a print-year subseries and tell part volumes apart (#216).
    public var titleFragment: String? = nil
    /// The paste's history.state.gov link, when it carried one (#1474). Not shown: its ids are
    /// exact, and an id such as `eta_d1` or `d710a-1` has no place in the Document field. A link
    /// to a numbered document fills that field with the id's number, `d373a`'s `373a` among them
    /// since #1977.
    public var exactReference: CitationExactReference? = nil
    /// The paste text these fields were last derived from. Entering Paste mode compares it with
    /// the current text, to tell a Batch edit (re-derive) from a return from Structured Entry
    /// (keep the reader's edits).
    public var derivedFrom = ""

    public init(subseries: String = "", volume: String = "", part: String = "", document: String = "",
                page: String = "", titleFragment: String? = nil,
                exactReference: CitationExactReference? = nil, derivedFrom: String = "") {
        self.subseries = subseries
        self.volume = volume
        self.part = part
        self.document = document
        self.page = page
        self.titleFragment = titleFragment
        self.exactReference = exactReference
        self.derivedFrom = derivedFrom
    }

    /// Every field derived from `text` alone — none carried over from an earlier paste, and all of
    /// them empty when `text` is blank.
    public static func derived(fromPaste text: String, parser: CitationParser) -> CitationLookupFields {
        derived(from: parser.parse(text), text: text)
    }

    /// The fields `parsed` yields, recorded as derived from `text`.
    private static func derived(from parsed: CitationInput, text: String) -> CitationLookupFields {
        CitationLookupFields(
            subseries: parsed.subseries ?? "",
            volume: parsed.volumeNumber ?? "",
            part: parsed.partNumber.map(String.init) ?? "",
            document: parsed.documentNumber ?? "",
            page: parsed.pageNumber.map(String.init) ?? "",
            titleFragment: parsed.titleFragment,
            exactReference: parsed.exactReference,
            derivedFrom: text
        )
    }

    /// The fields after the paste text or the mode changes: re-derived from `text` in Paste mode
    /// when `text` is not what they were last derived from, and unchanged otherwise.
    ///
    /// The view calls it on both events, because Batch edits the same text with no paste field
    /// mounted to notice: entering Paste afterwards must re-derive, while a return from Structured
    /// Entry (text unchanged) must keep what the reader typed there.
    public func refreshed(forPaste text: String, mode: CitationLookupMode,
                          parser: CitationParser) -> CitationLookupFields {
        guard mode == .paste, text != derivedFrom else { return self }
        return .derived(fromPaste: text, parser: parser)
    }

    /// The five values the form shows, for telling whether the reader has edited a paste's result.
    private var visibleValues: [String] { [subseries, volume, part, document, page] }

    /// Whether Look Up has anything to go on. In Batch mode that is the footnote block, which is
    /// that mode's whole input — these fields are never read there, so they must not gate it.
    /// Otherwise it is whatever `input` would hand the matcher.
    public func isActionable(mode: CitationLookupMode, pasteText: String, parser: CitationParser) -> Bool {
        if mode == .batch { return !CitationBlockSplitter.split(pasteText).isEmpty }
        return input(mode: mode, pasteText: pasteText, parser: parser).isActionable
    }

    /// The matcher input for a lookup in `mode`.
    ///
    /// Paste mode also forwards the title fragment, and the paste's link — but the link only while
    /// the five visible fields still hold what that paste produced. Once the reader edits one, the
    /// fields are the citation they mean to look up, and a link they can no longer see must not
    /// quietly outrank them.
    public func input(mode: CitationLookupMode, pasteText: String, parser: CitationParser) -> CitationInput {
        let parsed = mode == .paste ? parser.parse(pasteText) : nil
        let pasted = parsed.map { Self.derived(from: $0, text: pasteText) }
        let reference = pasted.flatMap { $0.visibleValues == visibleValues ? $0.exactReference : nil }

        /// A field's value, or `nil` when it holds only whitespace.
        func value(_ field: String) -> String? {
            let trimmed = field.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return CitationInput(
            rawText: parsed == nil ? nil : pasteText,
            subseries: value(subseries),
            volumeNumber: value(volume),
            partNumber: CitationParser.normalizedPartNumber(part),
            documentNumber: value(document).flatMap(CitationParser.normalizedDocumentNumber),
            pageNumber: value(page).flatMap { Int($0) },
            titleFragment: parsed == nil ? nil : titleFragment,
            exactReference: reference,
            parserConfidence: parsed?.parserConfidence ?? .structured
        )
    }
}
