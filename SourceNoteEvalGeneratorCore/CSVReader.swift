// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Streaming RFC-4180 CSV reader, dependency-free.
///
/// Built for the ~200 MB `citations.csv` eval corpus, whose `tei_xml` column is a
/// quoted field containing embedded commas, newlines, and `""`-escaped quotes — a
/// naive line-splitting parser mangles it. The reader processes the file in fixed-size
/// chunks through a byte-level state machine, so memory stays bounded regardless of
/// file size.
///
/// Dialect handled (RFC 4180 plus common relaxations):
/// - fields separated by `,`; records terminated by `\n`, `\r\n`, or bare `\r`;
/// - quoted fields (`"…"`) may contain commas, newlines, and quotes escaped as `""`;
/// - an unquoted field is taken verbatim (no escapes);
/// - a final record without a trailing newline is still emitted;
/// - a quote appearing after data in an unquoted field is kept literally (relaxation).
///
/// Version history:
///   1.0 — Source Explorer Phase 2 (Session 2026-07-03): initial implementation for
///          the SourceNoteEvalGenerator harness
public struct CSVReader {

    /// Parser state for the byte-level RFC-4180 state machine.
    private enum State {
        /// At the start of a field — a `"` here opens a quoted field.
        case fieldStart
        /// Inside an unquoted field.
        case unquoted
        /// Inside a quoted field.
        case quoted
        /// Just consumed a `"` inside a quoted field — the next byte disambiguates
        /// an escaped quote (`""`) from the closing quote.
        case quoteInQuoted
    }

    /// Errors thrown by `CSVReader`.
    public enum CSVError: Error, CustomStringConvertible {
        /// The input file could not be opened for reading.
        case cannotOpen(path: String)

        /// Human-readable error description.
        public var description: String {
            switch self {
            case .cannotOpen(let path): return "CSVReader: cannot open \(path)"
            }
        }
    }

    private init() {}

    /// Streams every record of the CSV file at `url` to `handler`, in file order.
    ///
    /// - Parameters:
    ///   - url: File to read. Must be UTF-8 encoded.
    ///   - chunkSize: Bytes read per I/O call (default 4 MiB); exposed for tests.
    ///   - handler: Called once per record with its fields. Return `false` to stop
    ///     early (remaining records are skipped), `true` to continue.
    /// - Throws: `CSVError.cannotOpen` when the file cannot be read.
    public static func forEachRecord(
        in url: URL,
        chunkSize: Int = 4 << 20,
        handler: ([String]) -> Bool
    ) throws {
        guard let file = FileHandle(forReadingAtPath: url.path) else {
            throw CSVError.cannotOpen(path: url.path)
        }
        defer { try? file.close() }

        var state = State.fieldStart
        var field: [UInt8] = []
        var record: [String] = []
        var sawCR = false          // pending \r that may pair with a following \n
        var recordHasData = false  // suppresses empty records from blank lines

        /// Closes the current field into the record.
        func endField() {
            record.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }

        /// Closes the current record and forwards it. Returns the handler's verdict.
        func endRecord() -> Bool {
            endField()
            let row = record
            record.removeAll(keepingCapacity: true)
            recordHasData = false
            return handler(row)
        }

        while true {
            let data = (try? file.read(upToCount: chunkSize)) ?? nil
            guard let chunk = data, !chunk.isEmpty else { break }

            for byte in chunk {
                // A bare \r (not followed by \n) terminates a record too.
                if sawCR {
                    sawCR = false
                    if byte == UInt8(ascii: "\n") { continue }  // \r\n already handled
                }
                switch state {
                case .fieldStart:
                    switch byte {
                    case UInt8(ascii: "\""):
                        state = .quoted
                        recordHasData = true
                    case UInt8(ascii: ","):
                        endField()
                        recordHasData = true
                    case UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                        sawCR = byte == UInt8(ascii: "\r")
                        if recordHasData || !field.isEmpty || !record.isEmpty {
                            if !endRecord() { return }
                        }
                    default:
                        field.append(byte)
                        state = .unquoted
                        recordHasData = true
                    }
                case .unquoted:
                    switch byte {
                    case UInt8(ascii: ","):
                        endField()
                        state = .fieldStart
                    case UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                        sawCR = byte == UInt8(ascii: "\r")
                        state = .fieldStart
                        if !endRecord() { return }
                    default:
                        field.append(byte)
                    }
                case .quoted:
                    if byte == UInt8(ascii: "\"") {
                        state = .quoteInQuoted
                    } else {
                        field.append(byte)
                    }
                case .quoteInQuoted:
                    switch byte {
                    case UInt8(ascii: "\""):
                        // Escaped quote ("") — emit one literal quote.
                        field.append(UInt8(ascii: "\""))
                        state = .quoted
                    case UInt8(ascii: ","):
                        endField()
                        state = .fieldStart
                    case UInt8(ascii: "\n"), UInt8(ascii: "\r"):
                        sawCR = byte == UInt8(ascii: "\r")
                        state = .fieldStart
                        if !endRecord() { return }
                    default:
                        // Data after a closing quote — keep it (relaxed dialect).
                        field.append(byte)
                        state = .unquoted
                    }
                }
            }
        }

        // Final record without a trailing newline.
        if recordHasData || !field.isEmpty || !record.isEmpty {
            _ = endRecord()
        }
    }

    /// Parses an in-memory CSV string into records. Convenience for tests; the
    /// production path streams from disk via `forEachRecord(in:chunkSize:handler:)`.
    ///
    /// - Parameter text: CSV content.
    /// - Returns: All records, in order.
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("csvreader-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: tmp) }
        do {
            try Data(text.utf8).write(to: tmp)
            try forEachRecord(in: tmp) { row in
                rows.append(row)
                return true
            }
        } catch {
            return []
        }
        return rows
    }
}
