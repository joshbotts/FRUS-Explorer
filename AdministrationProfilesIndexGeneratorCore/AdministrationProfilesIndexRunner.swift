// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Builds the bundled `administration-profiles-index.json` (SA-2a): attributes every
/// FRUS document's date to the presidential administration(s) in office when it was
/// written and aggregates the per-administration / per-volume document and volume counts.
///
/// Entirely offline and deterministic. Configuration (environment variables):
/// - `VOLUMES_DIR` — directory of volume `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `ADMINISTRATIONS` — administrations table path (default `FRUSExplorer/Resources/administrations.json`)
/// - `OUTPUT` — output path (default `FRUSExplorer/Resources/administration-profiles-index.json`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
public enum AdministrationProfilesIndexRunner {

    /// The artifact schema version this runner emits.
    public static let schemaVersion = 1

    /// Runs the generator.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let adminsPath = env["ADMINISTRATIONS"] ?? "FRUSExplorer/Resources/administrations.json"
        let outputPath = env["OUTPUT"] ?? "FRUSExplorer/Resources/administration-profiles-index.json"
        let generated = env["GENERATED_DATE"] ?? today()

        // MARK: Load the administrations table.
        let table = try AdministrationsTable.load(from: URL(fileURLWithPath: adminsPath))
        log("Loaded \(table.administrations.count) administrations from \(adminsPath)")

        // MARK: Iterate every volume XML, extracting one DocumentDate per document.
        let xmls = try FileManager.default
            .contentsOfDirectory(at: volumesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !xmls.isEmpty else { throw RunError.noVolumes(volumesDir.path) }

        var volumes: [ProfileAggregator.VolumeDates] = []
        var volumesWithDocs = 0
        for url in xmls {
            let volumeId = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url) else { continue }
            let dates = DocumentDateExtractor.extract(fromXML: data)
            guard !dates.isEmpty else { continue }
            volumes.append(.init(volumeId: volumeId, dates: dates))
            volumesWithDocs += 1
        }

        // MARK: Aggregate.
        let index = ProfileAggregator.aggregate(
            administrations: table.administrations,
            volumes: volumes,
            schemaVersion: schemaVersion,
            generated: generated)

        // MARK: Write.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(index).write(to: URL(fileURLWithPath: outputPath))

        // MARK: Reconciliation check (fail loudly if totals drift).
        let sumPoint = index.volumeTotals.values.reduce(0) { $0 + $1.pointDocs }
        let sumRange = index.volumeTotals.values.reduce(0) { $0 + $1.rangeDocs }
        let sumUndated = index.volumeTotals.values.reduce(0) { $0 + $1.undatedDocs }
        precondition(sumPoint == index.totalDocumentsPointDated
            && sumRange == index.totalDocumentsRangeDated
            && sumUndated == index.totalDocumentsUndated,
            "volumeTotals do not reconcile with the global totals")

        log("""
        administration-profiles-index.json written to \(outputPath)
          volumes with documents:  \(volumesWithDocs) / \(xmls.count)
          point-dated documents:   \(index.totalDocumentsPointDated)
          range-dated documents:   \(index.totalDocumentsRangeDated)
          undated documents:       \(index.totalDocumentsUndated)
          reconciles (Σ volumeTotals == totals): true
        """)
    }

    // MARK: - Helpers

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    /// Errors thrown by the runner.
    public enum RunError: Error, CustomStringConvertible {
        /// No `.xml` volumes were found in `VOLUMES_DIR`.
        case noVolumes(String)
        public var description: String {
            switch self {
            case .noVolumes(let dir): return "No .xml volumes found in \(dir)"
            }
        }
    }
}
