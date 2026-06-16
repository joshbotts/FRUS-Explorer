// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Streams the `plain_text` column from a large FRUS citations CSV.
///
/// The export is ~200 MB with an RFC-4180-quoted `tei_xml` column containing embedded
/// commas, newlines, and `""` escapes, so it is parsed with a byte-level state machine
/// over fixed-size chunks (never loaded whole). Only the target column's bytes are
/// buffered; all other fields are scanned and discarded, so memory stays flat.
///
/// Expected columns: `volume_id, citation_type, ancestor_id, xpath, plain_text, tei_xml`.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 3 — lot files
public enum CitationCSVReader {

    public enum CSVError: Error { case cannotOpen(String) }

    /// Index of the `plain_text` column.
    private static let plainTextColumn = 4

    private static let comma: UInt8 = 0x2C
    private static let quote: UInt8 = 0x22
    private static let newline: UInt8 = 0x0A
    private static let carriage: UInt8 = 0x0D

    /// Calls `body` with each row's `plain_text` value (the header row is skipped).
    public static func forEachPlainText(path: String, _ body: (String) -> Void) throws {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw CSVError.cannotOpen(path)
        }
        defer { try? handle.close() }

        var fieldIndex = 0
        var inQuotes = false
        var pendingQuote = false       // saw a quote while inQuotes; decide on next byte
        var fieldStart = true          // at the first byte of a field (for opening quote)
        var rowIsHeader = true
        var buffer: [UInt8] = []       // bytes of the target field only
        var rowHasContent = false

        func endField() {
            fieldIndex += 1
            fieldStart = true
        }
        func endRow() {
            if !rowIsHeader, rowHasContent, !buffer.isEmpty {
                body(String(decoding: buffer, as: UTF8.self))
            }
            rowIsHeader = false
            fieldIndex = 0
            fieldStart = true
            inQuotes = false
            pendingQuote = false
            buffer.removeAll(keepingCapacity: true)
            rowHasContent = false
        }

        while case let chunk = handle.readData(ofLength: 1 << 20), !chunk.isEmpty {
            for b in chunk {
                rowHasContent = true
                if inQuotes {
                    if pendingQuote {
                        pendingQuote = false
                        if b == quote {                       // "" → literal quote
                            if fieldIndex == plainTextColumn { buffer.append(quote) }
                            continue
                        }
                        inQuotes = false                      // closing quote; fall through
                    } else if b == quote {
                        pendingQuote = true
                        continue
                    } else {
                        if fieldIndex == plainTextColumn { buffer.append(b) }
                        continue
                    }
                }

                // Not in quotes (or just left quotes via the closing quote above).
                switch b {
                case quote where fieldStart:
                    inQuotes = true
                    fieldStart = false
                case comma:
                    endField()
                case newline:
                    endRow()
                case carriage:
                    break                                     // ignore CR; LF ends the row
                default:
                    fieldStart = false
                    if fieldIndex == plainTextColumn { buffer.append(b) }
                }
            }
        }
        // Final row if the file doesn't end with a newline.
        if rowHasContent { endRow() }
    }
}
