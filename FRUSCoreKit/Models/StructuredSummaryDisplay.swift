// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - StructuredSummaryDisplay

/// A stored summary as it is shown: a structured summary's fields as labelled text, and any other
/// summary's text as it is stored (2026-10-31).
///
/// A structured summary stores a JSON object in `GeneratedSummary.responseText`, a string per field,
/// keyed by the field's name. Until 2026-10-31 every surface showed that object as it stands, braces
/// and quotes included. Few readers met it while the on-device model declined most structured
/// prompts; once those prompts were answered (the app's `StructuredSectionAnswer`), the owner chose to
/// show the fields: in both readers first, then in the collection inspector, the collection exports,
/// the research note editor, the Research rail's preview and the search index's summary text.
///
/// The fields come in the order of the schema the summary was made with, then any member the schema
/// does not name, by name. Text that is not a JSON object of strings (a headnote the reader edited,
/// say) is shown as it is stored, and so is a summary whose format is `.general`.
///
/// The app's readers draw ``fields(responseText:format:)`` with each label in bold (the app's
/// `StructuredSummaryDisplay.text(responseText:format:)`), and so do the collection exporters;
/// ``plainText(responseText:format:separator:)`` is the same fields as plain text, for a surface that
/// holds a `String`: a note the summary is inserted into, the search index, a one-line preview.
///
/// Version history:
///   1.0 — 2026-10-31: the app's reader display, `FRUSExplorer/Summarization/StructuredSummaryText.swift`
///   1.1 — 2026-10-31: moved into FRUSCoreKit, public, so the collection exporters read the fields;
///          ``label(for:)`` (the app's `StructuredSectionAnswer.heading(for:)`) and
///          ``plainText(responseText:format:separator:)`` added
public enum StructuredSummaryDisplay {

    /// A labelled field of a structured summary.
    public struct Field: Equatable, Sendable {
        /// The field's name as words (``StructuredSummaryDisplay/label(for:)``).
        public let label: String
        /// The field's text.
        public let text: String

        /// A field with `label` and `text`.
        public init(label: String, text: String) {
            self.label = label
            self.text = text
        }
    }

    /// The label a field is shown with, and the heading the model is asked to write it under: its name
    /// with a space before each capital that follows a lowercase letter, so `KeyParticipants` reads
    /// *Key Participants*. A name the reader wrote with spaces keeps them.
    public static func label(for name: String) -> String {
        var label = ""
        for character in name {
            if character.isUppercase, let last = label.last, last.isLowercase { label.append(" ") }
            label.append(character)
        }
        return label
    }

    /// The fields of a structured summary's stored text, or `nil` for a plain-text summary and for text
    /// that is not a JSON object of strings.
    public static func fields(responseText: String, format: ResponseFormat) -> [Field]? {
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
            Field(label: label(for: $0), text: strings[$0]!.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// A summary as plain text: a structured summary's fields each as *Label: text* (*Label:* alone for
    /// an empty field), joined by `separator` (a blank line by default, so each field is a paragraph), or
    /// the stored text as it is.
    public static func plainText(responseText: String, format: ResponseFormat,
                                 separator: String = "\n\n") -> String {
        guard let fields = fields(responseText: responseText, format: format) else { return responseText }
        return fields.map { $0.text.isEmpty ? "\($0.label):" : "\($0.label): \($0.text)" }
            .joined(separator: separator)
    }
}
