// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - EditorialOmissionMarkers

/// The editors' bracketed omission markers: the rule of the sixteenth layer, "Marked editorial
/// omissions" (`Planning/Editors-Annotations-Followups-2026-11-08.md`, Lane 1), measured over the
/// corpus by `Planning/editors-annotations/omission_markers.py` before it was written here.
///
/// A document carries the layer when a bracketed span of its own text, its notes left out,
/// matches one of three patterns and does not say "not declassified":
/// 1. "[Here follows discussion of …]", "[Here follow the names of …]";
/// 2. "[Omitted here is the Table of Contents.]", "[Omitted from this document are …]", or, after a
///    stage direction, "[Agnew left at 10:35 a.m. Omitted here is discussion unrelated to …]";
/// 3. "[The next three paragraphs, which have been omitted, are …]", "[…, which is omitted]",
///    "[The paragraph here omitted summarized …]", anywhere in the bracket.
///
/// Patterns 1 and 2 are case-sensitive, as the plan wrote them: a lower-case "[here follows …]"
/// sits mid-sentence, and a case-blind pattern 2 took "[omitted from?]", an editor's query on the
/// original, for an omission. The sweep's first run read 40 hits a pattern with no false positive
/// and found the two clauses added here in its residue, every sample an omission.
///
/// A bracket that says "not declassified" is a redaction, the Redactions layer's, whatever else it
/// says. The editors' remarks on a garbled original, "[apparent omission]", "[omission?]",
/// "[omission in the original]", "[sic]", match no pattern. The sweep found other phrasings the
/// rule leaves out, "[Chinese text not printed.]", "[Letter omitted.]", "[… was not transcribed.]",
/// and its output records each.
///
/// Version history:
///   1.0 — 2026-11-08: Lane 1 of the follow-ups plan
enum EditorialOmissionMarkers {

    // `NSRegularExpression`, as the kit's shared patterns are: a `Regex` literal in a `static let`
    // is not `Sendable`, and one compiled per bracket would be compiled some forty thousand times
    // over the corpus.

    /// "[Here follows …]", "[Here follow …]".
    private static let hereFollows = try? NSRegularExpression(pattern: #"^\s*Here\s+follows?\b"#)
    /// "[Omitted here is …]", "[Omitted from … are …]", and "Omitted here is …" after a sentence.
    private static let omittedHere = try? NSRegularExpression(
        pattern: #"^\s*Omitted\s+(?:here|from|are|is)\b|\bOmitted\s+here\s+(?:is|are)\b"#)
    /// "…, which has been omitted, …", "…, which are omitted …", "… here omitted …", anywhere.
    private static let hasBeenOmitted = try? NSRegularExpression(
        pattern: #"\b(?:has|have)\s+been\s+omitted\b|\bwhich\s+(?:is|are)\s+omitted\b|\bhere\s+omitted\b"#)
    /// The Redactions layer's mark, which takes a bracket out of this layer.
    private static let notDeclassified = try? NSRegularExpression(pattern: #"not\s+declassified"#,
                                                                   options: [.caseInsensitive])
    /// The longest bracket read: a `[` that does not close within this many characters is passed
    /// over, so a stray opener cannot swallow a document.
    static let longestBracket = 4000

    /// `true` when `text`, a document's own text, holds a bracket that marks an omission.
    static func marksAnOmission(in text: String) -> Bool {
        brackets(in: text).contains(where: isMarkedOmission)
    }

    /// `true` when the inside of one bracket marks an omission by the rule above.
    static func isMarkedOmission(_ inner: Substring) -> Bool {
        // Matched as a String of its own, so that `^` is the bracket's start wherever the span sits
        // in the document, as in the sweep.
        let span = String(inner)
        let whole = NSRange(span.startIndex..., in: span)
        func matches(_ regex: NSRegularExpression?) -> Bool {
            regex?.firstMatch(in: span, range: whole) != nil
        }
        guard !matches(notDeclassified) else { return false }
        return matches(hereFollows) || matches(omittedHere) || matches(hasBeenOmitted)
    }

    /// The inside of every bracketed span of `text`, nesting followed: "[Here follows … [sic] …]"
    /// is one span, read whole, and a `]` with no opener is passed over, as "No. 1315.]" in an
    /// opener is. A `[` that does not close within ``longestBracket`` characters is passed over too.
    static func brackets(in text: String) -> [Substring] {
        var spans: [Substring] = []
        var from = text.startIndex
        while from < text.endIndex, let open = text[from...].firstIndex(of: "[") {
            var depth = 0
            var cursor = open
            var length = 0
            var closed: String.Index?
            while cursor < text.endIndex, length <= longestBracket {
                let character = text[cursor]
                if character == "[" {
                    depth += 1
                } else if character == "]" {
                    depth -= 1
                    if depth == 0 {
                        closed = cursor
                        break
                    }
                }
                cursor = text.index(after: cursor)
                length += 1
            }
            if let closed {
                spans.append(text[text.index(after: open)..<closed])
                from = text.index(after: closed)
            } else {
                from = text.index(after: open)
            }
        }
        return spans
    }

    /// The first four-digit run of `text` as a year, or `nil`: the header's publication date is
    /// printed "1948", "2026-03-15" or, in a few volumes, on `@when` alone.
    static func year(in text: String) -> Int? {
        text.firstMatch(of: /\d{4}/).flatMap { Int($0.output) }
    }
}
