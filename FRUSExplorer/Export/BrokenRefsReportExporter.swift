// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BrokenRefsReportExporter

/// Re-serializes the bundled broken cross-reference index (issue #240B) to CSV or JSON for the
/// in-app "Broken Cross-References Report" export.
///
/// The bundled index is the compact, de-duplicated form (one row per distinct `(sv, sd, t)` key,
/// no per-occurrence line/offset/filename), so the exported CSV is the reduced 6-column shape. The
/// full 9-column, per-occurrence OH-submittable spreadsheet is produced offline by
/// `CrossRefValidationGenerator`; the export footer says so.
enum BrokenRefsReportExporter {

    /// The reduced CSV columns the bundled index can produce.
    static let csvHeader = [
        "source_volume", "source_document", "raw_target", "reason", "resolved_volume", "resolved_anchor",
    ]

    /// RFC-4180 CSV of the index's distinct broken records, sorted `(sv, sd, t)` for determinism,
    /// CRLF-terminated to match the OH report byte-for-byte. (GeneratorKit's `CSVWriter` isn't
    /// linkable into the app, so its escaper is mirrored here.)
    static func csv(from index: BrokenRefsIndex) -> String {
        let rows = index.records
            .sorted {
                if $0.sv != $1.sv { return $0.sv < $1.sv }
                if $0.sd != $1.sd { return $0.sd < $1.sd }
                return $0.t < $1.t
            }
            .map { [$0.sv, $0.sd, $0.t, $0.r, $0.rv ?? "", $0.ra ?? ""] }
        var out = row(csvHeader)
        for r in rows { out += row(r) }
        return out
    }

    /// The bundled index JSON, verbatim, so `schemaVersion`/`generated`/counts/records round-trip
    /// exactly with zero re-encode drift. Throws if the bundled resource is missing.
    static func jsonData() throws -> Data {
        guard let url = Bundle.main.url(forResource: "broken-refs-index", withExtension: "json") else {
            throw ExportError.resourceMissing
        }
        return try Data(contentsOf: url)
    }

    /// A failure exporting the report.
    enum ExportError: Error, LocalizedError {
        /// The bundled `broken-refs-index.json` resource could not be found.
        case resourceMissing
        var errorDescription: String? {
            switch self {
            case .resourceMissing:
                return String(localized: "The broken cross-references dataset isn't available in this build.")
            }
        }
    }

    // MARK: - RFC-4180 helpers

    private static let lineTerminator = "\r\n"

    private static func field(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"")
            || value.contains("\r") || value.contains("\n")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",") + lineTerminator
    }
}
