// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The prose-first snippet (owner request, 2026-08-27) — built for the evaluation report's
/// judging rows and now shared with the app's semantic search results, which face the same
/// problem for the same reason (no keywords, so nothing to bold): the row already shows
/// the header, dateline, and key, and FRUS `body_text` OPENS with exactly that boilerplate —
/// the head, the source-note footnote, the dateline, a despatch serial — so a naive prefix
/// spends most of its budget re-showing what the row states one line up. This strips the
/// known front matter and hands the judge actual prose.
///
/// ## Why stripping is by the DOCUMENT'S OWN fields, not by pattern
/// The order of the boilerplate varies by era — a 1943 telegram opens `151.10/2003a: Telegram
/// <header> <dateline> 1819. <prose>` (citation first), a 1961 memorandum opens `<header>
/// Source: … <prose>` (header first) — so the cleaner repeatedly strips, from the front,
/// whichever of the row's own header / stored source note / dateline matches next, in any
/// order, on whitespace-collapsed text. What survives is what none of the known fields claim.
/// Two small pattern strips remain for the pieces no stored field carries: a leading
/// `[Received …]` bracket group and a leading despatch/telegram serial (`1819.`, `No. 804.]`).
///
/// ## The honest fallback
/// A document whose entire early text IS its boilerplate (a stub, a very short note) falls
/// back to the plain collapsed prefix rather than showing nothing — an empty snippet reads as
/// "no text", which is a different claim than "nothing but boilerplate".
public enum ProseSnippet {

    /// Builds the snippet.
    ///
    /// - Parameters:
    ///   - header: The document's header, as the report row shows it.
    ///   - dateline: The row's dateline, when present.
    ///   - sourceNote: The document's stored source note (`document_sources.raw_text`), when present.
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

        var remainder = Substring(collapsed)
        let fronts = [collapse(header), sourceNote.map(collapse) ?? "", dateline.map(collapse) ?? ""]
            .filter { !$0.isEmpty }

        // Strip the document's own front-matter fields, whichever comes next, until none match.
        var stripped = true
        while stripped {
            stripped = false
            for front in fronts where remainder.hasPrefix(front) {
                remainder = remainder.dropFirst(front.count)
                while remainder.first == " " { remainder = remainder.dropFirst() }
                stripped = true
            }
            // `[Received December 14—1:57 p.m.]` and kin — no stored field carries these.
            if remainder.first == "[" , let close = remainder.firstIndex(of: "]") {
                let group = remainder[remainder.startIndex...close]
                // Only a SHORT bracket group is chrome; a long one is bracketed prose.
                if group.count <= 60 {
                    remainder = remainder[remainder.index(after: close)...]
                    while remainder.first == " " { remainder = remainder.dropFirst() }
                    stripped = true
                }
            }
            // A leading despatch/telegram serial: `1819.`, `271048.`, `No. 804.]` — modern
            // telegram numbers run six digits, so the cap is seven.
            if let match = remainder.range(
                of: #"^(?:No\.\s*\S{1,8}\]?|\d{1,7}\s*\.)\s+"#, options: .regularExpression) {
                remainder = remainder[match.upperBound...]
                stripped = true
            }
        }

        // The fallback: boilerplate was everything. Show the plain prefix rather than nothing.
        let source = remainder.trimmingCharacters(in: .whitespaces).isEmpty
            ? Substring(collapsed)
            : remainder

        return truncateAtWord(String(source), limit: limit)
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
}
