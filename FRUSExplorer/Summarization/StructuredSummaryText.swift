// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - StructuredSectionAnswer

/// How a structured prompt's answer is asked for, and read back into its fields (2026-10-31).
///
/// ## Why not guided generation
/// Until 2026-10-31 a structured prompt was answered by guided generation: a `GenerationSchema` built
/// from its fields. The on-device model declines a schema-shaped answer about most FRUS documents.
/// Measured on a Mac under macOS 27.2 with a throwaway harness that ran `SummarizationService`'s
/// chunking and reduce over 54 documents of 13 volumes, 1870 to 1988, under the five structured
/// templates without a placeholder: 38 of 270 documents summarized, 4 of the 140 that were chunked.
/// 413 of the 425 failed calls were the model's own refusal (`LanguageModelError.refusal`, *May
/// contain sensitive content*), returned in a median 0.3 s, and the outcome repeated in 4 of 4 runs
/// for 54 of the 54 document and template pairs run four times. Two invented memos passed 20 of 20,
/// and removing a refused document's source note and classification did not help: the model was
/// declining the documents' substance. Apple's `permissiveContentTransformations` guardrails behave
/// as the default for a non-`String` answer, as Apple documents, and were identical on all 108 pairs
/// tried; session instructions describing the series made it worse.
///
/// ## What it does instead
/// The fields are asked for as Markdown headings in the session's instructions (``instructions(for:)``),
/// the prompt's own text is the request as before, the answer is generated as a `String` on the
/// permissive guardrails, and ``values(in:schema:)`` reads the headings back. Over the same documents
/// that was 108 of 108 documents across the five templates, 56 of them chunked, and 297 of 297
/// answers carried every heading; none was a refusal written as the answer. The owner chose it on
/// 2026-10-31 over a fallback to plain text after a refused guided call, which fell back on 113 of
/// 145 calls and was no faster.
///
/// ``jsonString(_:schema:)`` writes the object a structured summary has always stored in
/// `GeneratedSummary.responseText`: a string per field, keyed by the field's name.
///
/// Model-facing and never shown, so the instructions are not localized. The wording is the measured
/// wording: a change to it is a change the measurement no longer covers.
///
/// Version history:
///   1.0 — 2026-10-31: initial implementation
enum StructuredSectionAnswer {

    /// The heading a field is asked for under, and the label the reader shows it with: its name with a
    /// space before each capital that follows a lowercase letter, so `KeyParticipants` reads *Key
    /// Participants*. A name the reader wrote with spaces keeps them.
    ///
    /// Asked for under its run-together name, as `KeyParticipants: description`, the model wrote the
    /// colon and dropped the name in all 8 answers of the first try.
    static func heading(for name: String) -> String {
        var heading = ""
        for character in name {
            if character.isUppercase, let last = heading.last, last.isLowercase { heading.append(" ") }
            heading.append(character)
        }
        return heading
    }

    /// The session instructions that ask for `schema`'s fields as Markdown headings, in its order, each
    /// with its description in parentheses beneath it.
    static func instructions(for schema: StructuredSummarySchema) -> String {
        let sections = schema.fields.map { field -> String in
            let description = field.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty
                ? "## \(heading(for: field.name))"
                : "## \(heading(for: field.name))\n(\(description))"
        }
        return """
            Write the answer in Markdown under exactly these headings, in this order, each heading on a \
            line of its own as shown, followed by its content in plain prose. Do not add other headings \
            or any text before the first heading.

            \(sections.joined(separator: "\n\n"))
            """
    }

    /// Each field's text in `answer`, keyed by the field's name, or `nil` when a field's heading is
    /// missing. A refusal written as the answer has none.
    ///
    /// A field's text runs from its first heading to the next heading of any kind (a field's, again or
    /// not, or any other Markdown heading), whatever order the model wrote them in, and is made one
    /// paragraph (``paragraph(_:description:)``). So a heading the model added, or its sections
    /// written a second time (19 of 713 answers measured), stays out of the field before it.
    static func values(in answer: String, schema: StructuredSummarySchema) -> [String: String]? {
        let text = answer as NSString
        let whole = NSRange(location: 0, length: text.length)
        var firsts: [(field: StructuredSummarySchema.Field, textStart: Int)] = []
        var boundaries: [Int] = []
        if let markdown = try? NSRegularExpression(pattern: #"^[ \t]*#{1,6}[ \t]+\S"#, options: [.anchorsMatchLines]) {
            boundaries += markdown.matches(in: answer, range: whole).map(\.range.location)
        }
        for field in schema.fields {
            guard let pattern = try? NSRegularExpression(pattern: headingPattern(for: field.name),
                                                         options: [.caseInsensitive, .anchorsMatchLines])
            else { return nil }
            let matches = pattern.matches(in: answer, range: whole)
            guard let first = matches.first else { return nil }
            firsts.append((field, NSMaxRange(first.range)))
            boundaries += matches.map(\.range.location)
        }
        boundaries.sort()
        var values: [String: String] = [:]
        for heading in firsts {
            let end = boundaries.first { $0 >= heading.textStart } ?? text.length
            let section = text.substring(with: NSRange(location: heading.textStart,
                                                       length: max(0, end - heading.textStart)))
            values[heading.field.name] = paragraph(section, description: heading.field.description)
        }
        return values
    }

    /// `values` as the JSON object a structured summary stores, its members in the schema's order.
    static func jsonString(_ values: [String: String], schema: StructuredSummarySchema) -> String {
        let members = schema.fields.map { "\(quoted($0.name)): \(quoted(values[$0.name] ?? ""))" }
        return "{" + members.joined(separator: ", ") + "}"
    }

    // MARK: - Private

    /// A heading line for `name`: Markdown's heading, quote or list markers if any, the name with or
    /// without the spaces between its words, emphasis around it if any, then a colon or the end of the
    /// line. So *Subject* is not read from a *Subject Details* heading, nor from a line that opens
    /// *Subject to*.
    private static func headingPattern(for name: String) -> String {
        let words = heading(for: name)
            .split(whereSeparator: { $0 == " " || $0 == "_" })
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
        return #"^[ \t]*(?:#{1,6}[ \t]*|[>*\-•][ \t]*|\d+[.)][ \t]*)*(?:\*\*|__|\*|_)?[ \t]*"#
            + words.joined(separator: "[ _]*")
            + #"[ \t]*(?:\*\*|__|\*|_)?[ \t]*(?::[ \t]*(?:\*\*|__)?|$)"#
    }

    /// A section made one paragraph: the field's description dropped where the model repeated it under
    /// the heading, rules, list markers and bold removed, a list item's own closing semicolon or comma
    /// dropped, and the lines joined by a semicolon after a list item that ends without a stop, and
    /// by a space otherwise (after a sentence, or a lead-in line ending in a colon).
    ///
    /// One paragraph because a structured summary is stored as JSON, and a line break inside a value
    /// would reach every surface that shows the stored text as it is (a collection's headnote, the
    /// research data export).
    private static func paragraph(_ section: String, description: String) -> String {
        var lines = section.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.allSatisfy { "-*_=".contains($0) } }
        let echo = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = lines.first, !echo.isEmpty,
           first.trimmingCharacters(in: CharacterSet(charactersIn: "()")).caseInsensitiveCompare(echo) == .orderedSame {
            lines.removeFirst()
        }
        let entries = lines.map { line -> (text: String, isItem: Bool) in
            var text = line
            let marker = text.range(of: #"^(?:[-*•]|\d+[.)])[ \t]+"#, options: .regularExpression)
            if let marker { text.removeSubrange(marker) }
            text = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            return (text, marker != nil)
        }
        var paragraph = ""
        var previousWasOpenItem = false
        for entry in entries {
            var text = entry.text
            if entry.isItem {
                while let last = text.last, ";,".contains(last) { text.removeLast() }
            }
            if !paragraph.isEmpty { paragraph += previousWasOpenItem && entry.isItem ? "; " : " " }
            paragraph += text
            previousWasOpenItem = entry.isItem && !(text.last.map { ".!?:".contains($0) } ?? false)
        }
        return paragraph
    }

    /// `string` as a JSON string literal.
    private static func quoted(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string], options: [.withoutEscapingSlashes]),
              let array = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }
}

// MARK: - StructuredSummaryDisplay

/// A stored summary as the reader shows it: a structured summary's fields as labelled lines, and any
/// other summary's text as it is stored (2026-10-31).
///
/// Until 2026-10-31 both readers showed a structured summary's stored JSON as it stands, braces and
/// quotes included. Few readers met it while the model declined most structured prompts; once those
/// prompts were answered (``StructuredSectionAnswer``), the owner chose to show the fields.
///
/// The fields come in the order of the schema the summary was made with, then any member the schema
/// does not name, by name. Text that is not a JSON object of strings (a headnote the reader edited,
/// say) is shown as it is stored.
///
/// Version history:
///   1.0 — 2026-10-31: initial implementation
enum StructuredSummaryDisplay {

    /// A labelled field of a structured summary.
    struct Field: Equatable {
        /// The field's name as words (``StructuredSectionAnswer/heading(for:)``).
        let label: String
        /// The field's text.
        let text: String
    }

    /// The fields of a structured summary's stored text, or `nil` for a plain-text summary and for text
    /// that is not a JSON object of strings.
    static func fields(responseText: String, format: ResponseFormat) -> [Field]? {
        guard case .structured(let schema) = format,
              let object = try? JSONSerialization.jsonObject(with: Data(responseText.utf8)) as? [String: Any],
              !object.isEmpty
        else { return nil }
        var strings: [String: String] = [:]
        for (key, value) in object {
            guard let string = value as? String else { return nil }
            strings[key] = string
        }
        let named = schema.fields.map(\.name).filter { strings[$0] != nil }
        let others = strings.keys.filter { !named.contains($0) }.sorted()
        return (named + others).map {
            Field(label: StructuredSectionAnswer.heading(for: $0),
                  text: strings[$0]!.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// The text the reader draws for a summary: a structured summary's fields one to a line, each
    /// opening with its label in bold, or the stored text as it is.
    static func text(responseText: String, format: ResponseFormat) -> AttributedString {
        guard let fields = fields(responseText: responseText, format: format) else {
            return AttributedString(responseText)
        }
        var text = AttributedString()
        for (index, field) in fields.enumerated() {
            if index > 0 { text += AttributedString("\n") }
            var label = AttributedString(field.label + ":")
            label.inlinePresentationIntent = .stronglyEmphasized
            text += label
            text += AttributedString(" " + field.text)
        }
        return text
    }
}

extension GeneratedSummary {
    /// This summary as the reader shows it (``StructuredSummaryDisplay``).
    var readerText: AttributedString {
        StructuredSummaryDisplay.text(responseText: responseText, format: responseFormat)
    }
}
