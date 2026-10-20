// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Where a document's own prose starts in its `body_text`, and the snippet a Meaning row shows from
/// there: one strip, which keyword rows, Meaning rows and the retrieval evaluation harness share.
///
/// The prose-first snippet (owner request, 2026-08-27) was built for the evaluation report's judging
/// rows, then shared with the app's Meaning rows, which face the same problem for the same reason (no
/// keywords, so nothing to bold): the row already shows the header, dateline, and key, and FRUS
/// `body_text` OPENS with exactly that boilerplate — the head, the source-note footnote, the dateline,
/// a despatch serial — so a naive prefix spends most of its budget re-showing what the row states one
/// line up. Since A10b (plan of record decision 74) a keyword row's window is cut from the same start
/// (`SearchService.keywordSnippet`), so the bold word a keyword row draws is its prose's, not its
/// heading's.
///
/// ## Why stripping is by the DOCUMENT'S OWN fields, not by pattern
/// The order of the boilerplate varies by era — a 1943 telegram opens `151.10/2003a: Telegram
/// <header> <dateline> 1819. <prose>` (citation first), a 1961 memorandum opens `<header>
/// Source: … <prose>` (header first) — so the strip repeatedly takes, from the front, whichever of
/// the row's own header / stored source note / dateline matches next, in any order. A run of white
/// space in the body matches a field's one space, so the body need not be collapsed first (the index
/// stores it collapsed). What survives is what none of the known fields claim. Two small pattern
/// strips remain for the pieces no stored field carries: a leading `[Received …]` bracket group and
/// a leading despatch/telegram serial (`1819.`, `No. 804.]`).
///
/// ## The two corrections (A10b, decision 74)
/// Measured over a full index at version 69 (`Planning/Keyword-Snippet-Assessment-2026-10-20.md`
/// §3), the strip as it stood stopped short in 17.9% of documents, in two ways:
/// 1. **The fields are tried before the bracket and serial rules, on every pass.** The serial rule
///    used to run first, so a heading that opens "No. 567" lost its number to it, and the rest of the
///    heading no longer matched and stayed: 6,923 documents in 26 volumes, `frus1952-54v07p2` d567
///    among them.
/// 2. **Then on through the document's own dateline, where it starts within ``datelineReach``
///    characters** of where the field strip stopped, and through a short bracket group and a serial
///    after it. No stored field carries a 1946–60 telegram's classification marking or distribution
///    line, which sits before its dateline: `frus1951v06p2` d94 opens "confidential Bangkok,
///    November 30, 1951—3 p. m. 1233." A dateline further on (3.5% of documents, after a long
///    distribution note) is left where it is, with the text before it. A dateline the field strip
///    already took is not looked for again, since prose that repeats it is the document's own.
///
/// ## Why the serial rule is not a regular expression
/// It was `^(?:No\.\s*\S{1,8}\]?|\d{1,7}\s*\.)\s+`, tried at every pass. A keyword search strips
/// every row it lists, 7,500 on the Mac, and a Foundation regular expression is compiled each time it
/// is asked for, so the rule is written out (``endOfSerial(in:at:)``), counting in characters as the
/// rest of the strip does. `ProseSnippetTests` holds it to the expression.
///
/// ## The honest fallback
/// A document whose entire early text IS its boilerplate (a stub, a very short note) falls back to
/// the plain collapsed prefix rather than showing nothing — an empty snippet reads as "no text",
/// which is a different claim than "nothing but boilerplate".
///
/// Version history:
///   1.0 — 2026-08-27: the evaluation report's judging rows, in SemanticVectorsKit
///   1.1 — V-5 hybrid page: shared with the app's Meaning rows
///   2.0 — A10b (decision 74): moved into FRUSCoreKit, for keyword rows too (``proseStart(in:header:dateline:sourceNote:)``),
///         with the two corrections; the serial rule written out; the evaluation harness takes it from here
public enum ProseSnippet {

    /// How far past the end of the field strip the document's own dateline may start and still be
    /// stripped through, in characters: the reach of the second correction (decision 74).
    public static let datelineReach = 200

    /// Builds the snippet a Meaning row shows: the document's prose from where
    /// ``proseStart(in:header:dateline:sourceNote:)`` puts it, collapsed and cut at a word.
    ///
    /// - Parameters:
    ///   - header: The document's header, as the row shows it.
    ///   - dateline: The row's dateline, when present.
    ///   - sourceNote: The document's stored source note, when present.
    ///   - body: A leading window of `body_text` (the caller fetches ~10× the target length).
    ///   - limit: Target snippet length; truncation lands on a word boundary.
    /// - Returns: The prose snippet.
    public static func prose(
        header: String,
        dateline: String?,
        sourceNote: String?,
        body: String,
        limit: Int = 300
    ) -> String {
        let collapsed = collapse(body)
        guard !collapsed.isEmpty else { return "" }
        let characters = Array(collapsed)
        // The fallback: boilerplate was everything. Show the plain prefix rather than nothing.
        let start = proseStart(in: characters, header: header, dateline: dateline, sourceNote: sourceNote) ?? 0
        return truncateAtWord(String(characters[start...]), limit: limit)
    }

    /// Where the document's prose starts in `body`: after its own heading, stored source note and
    /// dateline, a short bracket group and a despatch serial, taken from the front in any order, and
    /// then on through its dateline where that starts within ``datelineReach`` characters.
    ///
    /// - Parameters:
    ///   - body: The document's body text, or a leading window of it, as characters.
    ///   - header: The document's header, as the row shows it.
    ///   - dateline: The row's dateline, when present.
    ///   - sourceNote: The document's stored source note, when present.
    /// - Returns: The index in `body` of the prose's first character, or `nil` when the strip takes
    ///   everything: a document whose body is only its boilerplate.
    public static func proseStart(
        in body: [Character],
        header: String,
        dateline: String?,
        sourceNote: String?
    ) -> Int? {
        let datelineField = dateline.map { Array(collapse($0)) } ?? []
        // In the order they are tried at each pass. A field that is empty once collapsed is no field.
        let fields: [(text: [Character], isDateline: Bool)] = [
            (Array(collapse(header)), false),
            (sourceNote.map { Array(collapse($0)) } ?? [], false),
            (datelineField, true),
        ].filter { !$0.text.isEmpty }

        var position = endOfWhitespace(in: body, from: 0)
        var tookDateline = false
        // The fields first, at every pass (the first correction), then the two patterns.
        passes: while position < body.count {
            for field in fields {
                if let end = endOfField(field.text, in: body, at: position) {
                    position = endOfWhitespace(in: body, from: end)
                    tookDateline = tookDateline || field.isDateline
                    continue passes
                }
            }
            if let end = endOfBracketGroup(in: body, at: position) {
                position = endOfWhitespace(in: body, from: end)
                continue
            }
            if let end = endOfSerial(in: body, at: position) {
                position = end
                continue
            }
            break
        }
        guard position < body.count else { return nil }
        guard !tookDateline, !datelineField.isEmpty else { return position }

        // The second correction: on through the dateline where it starts within reach, and through a
        // bracket group and a serial after it, unless that would leave nothing.
        let lastStart = min(position + datelineReach, body.count - datelineField.count)
        guard lastStart >= position else { return position }
        for start in position...lastStart where body[start] == datelineField[0] {
            guard let end = endOfField(datelineField, in: body, at: start) else { continue }
            var after = endOfWhitespace(in: body, from: end)
            while after < body.count {
                if let close = endOfBracketGroup(in: body, at: after) {
                    after = endOfWhitespace(in: body, from: close)
                } else if let serial = endOfSerial(in: body, at: after) {
                    after = serial
                } else {
                    break
                }
            }
            return after < body.count ? after : position
        }
        return position
    }

    /// Whitespace-collapsed form: every run of whitespace (newlines included) becomes one space.
    public static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Truncates at the last word boundary inside `limit`, appending an ellipsis when cut.
    public static func truncateAtWord(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let hardEnd = text.index(text.startIndex, offsetBy: limit)
        let cut = text[..<hardEnd]
        let end = cut.lastIndex(of: " ") ?? hardEnd
        return String(text[..<end]) + "…"
    }

    // MARK: - The rules

    /// Where `field`, a collapsed field, ends when `body` holds it at `start`: a run of white space in
    /// the body matches the field's one space.
    ///
    /// - Returns: The index after the field's last character, or `nil` when `body` does not hold it there.
    static func endOfField(_ field: [Character], in body: [Character], at start: Int) -> Int? {
        var index = start
        for character in field {
            guard index < body.count else { return nil }
            if character == " " {
                guard body[index].isWhitespace else { return nil }
                index = endOfWhitespace(in: body, from: index)
            } else {
                guard body[index] == character else { return nil }
                index += 1
            }
        }
        return index
    }

    /// Where a `[Received December 14—1:57 p.m.]` group ends when one opens at `start`. Only a SHORT
    /// group, 60 characters with its brackets, is chrome; a long one is bracketed prose.
    ///
    /// - Returns: The index after the closing bracket, or `nil` when no short group opens at `start`.
    static func endOfBracketGroup(in body: [Character], at start: Int) -> Int? {
        guard start < body.count, body[start] == "[" else { return nil }
        let limit = min(body.count, start + 60)
        var index = start + 1
        while index < limit {
            if body[index] == "]" { return index + 1 }
            index += 1
        }
        return nil
    }

    /// Where a despatch or telegram serial ends when one opens at `start`, with the white space after
    /// it: `1819.`, `271048.`, `No. 804.]`. Modern telegram numbers run six digits, so the cap is
    /// seven, and a `No.` token runs to eight characters, or nine when its ninth is the bracket.
    ///
    /// `^(?:No\.\s*\S{1,8}\]?|\d{1,7}\s*\.)\s+` written out, as the type's documentation says why:
    /// a digit is a decimal digit (`\d`), and white space is what `Character.isWhitespace` says.
    ///
    /// - Returns: The index after the serial and its white space, or `nil` when no serial opens at `start`.
    static func endOfSerial(in body: [Character], at start: Int) -> Int? {
        let count = body.count
        guard start < count else { return nil }
        var index: Int
        if body[start] == "N" {
            guard start + 2 < count, body[start + 1] == "o", body[start + 2] == "." else { return nil }
            let token = endOfWhitespace(in: body, from: start + 3)
            // The token's length, counted no further than ten: only one to nine can match.
            var length = 0
            while length < 10, token + length < count, !body[token + length].isWhitespace { length += 1 }
            if (1...8).contains(length) {
                index = token + length
            } else if length == 9, body[token + 8] == "]" {
                index = token + 9
            } else {
                return nil
            }
        } else if isDecimalDigit(body[start]) {
            var digits = 0
            while digits < 8, start + digits < count, isDecimalDigit(body[start + digits]) { digits += 1 }
            guard digits <= 7 else { return nil }
            index = endOfWhitespace(in: body, from: start + digits)
            guard index < count, body[index] == "." else { return nil }
            index += 1
        } else {
            return nil
        }
        // At least one white space character must follow, and all of it is taken.
        guard index < count, body[index].isWhitespace else { return nil }
        return endOfWhitespace(in: body, from: index)
    }

    /// The first index at or after `start` that is not white space.
    private static func endOfWhitespace(in body: [Character], from start: Int) -> Int {
        var index = start
        while index < body.count, body[index].isWhitespace { index += 1 }
        return index
    }

    /// Whether `character` is one decimal digit, as a regular expression's `\d` reads one.
    private static func isDecimalDigit(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        return scalars.count == 1 && scalars.first?.properties.generalCategory == .decimalNumber
    }
}
