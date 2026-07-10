// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CSVWriter

/// A minimal RFC-4180 CSV serializer for generator reports (e.g. the OH-submittable
/// broken-cross-references spreadsheet). Emits UTF-8, CRLF-terminated rows, quoting any field that
/// contains a comma, double quote, carriage return, or line feed and doubling interior quotes.
public enum CSVWriter {

    /// The RFC-4180 line terminator.
    public static let lineTerminator = "\r\n"

    /// Escapes a single field: quotes it when it contains a comma, double quote, CR, or LF, and
    /// doubles any interior double quotes.
    ///
    /// - Parameter value: The raw field value.
    /// - Returns: The RFC-4180-safe field.
    public static func field(_ value: String) -> String {
        let needsQuoting = value.contains(",")
            || value.contains("\"")
            || value.contains("\r")
            || value.contains("\n")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Serializes one row from its raw field values (each is escaped), CRLF-terminated.
    ///
    /// - Parameter fields: The raw field values in column order.
    /// - Returns: The escaped, CRLF-terminated row.
    public static func row(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",") + lineTerminator
    }

    /// Serializes a full document: a header row followed by data rows.
    ///
    /// - Parameters:
    ///   - header: The column names.
    ///   - rows: The data rows, each an array of raw field values matching `header`'s order.
    /// - Returns: The complete CSV text.
    public static func document(header: [String], rows: [[String]]) -> String {
        var out = row(header)
        for r in rows { out += row(r) }
        return out
    }
}
