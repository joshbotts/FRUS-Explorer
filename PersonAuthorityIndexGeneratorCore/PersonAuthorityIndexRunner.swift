// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndexRunner

/// Orchestrates a build: reads the `HistoryAtState/people` checkout, optionally restricts the
/// crosswalk to volumes present in the app manifest, writes `person-authority-index.json`, and
/// prints a coverage report.
///
/// Environment variables:
/// - `PEOPLE_DATA_DIR` (required): path to the `data` directory of a `HistoryAtState/people` checkout.
/// - `OUTPUT_PATH` (optional): output JSON path. Default `FRUSExplorer/Resources/person-authority-index.json`.
/// - `MANIFEST_PATH` (optional): path to the app's `manifest.json`; when set, only volumes present
///    in the manifest are kept and unmatched volumes are reported.
public enum PersonAuthorityIndexRunner {

    /// Current schema version of the generated index.
    public static let indexVersion = 1

    public static func run(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let dataDirPath = environment["PEOPLE_DATA_DIR"], !dataDirPath.isEmpty else {
            FileHandle.standardError.write(Data("""
                error: set PEOPLE_DATA_DIR to the `data` directory of a HistoryAtState/people checkout.
                e.g. PEOPLE_DATA_DIR=/path/to/people/data swift run PersonAuthorityIndexGenerator

                """.utf8))
            exit(2)
        }
        let dataDir = URL(fileURLWithPath: dataDirPath, isDirectory: true)
        let outputPath = environment["OUTPUT_PATH"]
            ?? "FRUSExplorer/Resources/person-authority-index.json"
        let outputURL = URL(fileURLWithPath: outputPath)

        // Optional: restrict to volumes the app actually ships, from manifest.json.
        var keepVolume: ((String) -> Bool)?
        var manifestVolumes: Set<String> = []
        if let manifestPath = environment["MANIFEST_PATH"], !manifestPath.isEmpty {
            manifestVolumes = (try? Self.loadManifestVolumeIds(URL(fileURLWithPath: manifestPath))) ?? []
            if !manifestVolumes.isEmpty {
                keepVolume = { manifestVolumes.contains($0) }
                print("Loaded \(manifestVolumes.count) volume ids from manifest; restricting crosswalk to them.")
            }
        }

        let generated = Self.isoDate()
        let source = "HistoryAtState/people (CC0 / public domain)"

        do {
            print("Building person-authority index from \(dataDir.path) …")
            let (index, stats) = try PersonAuthorityIndexBuilder.build(
                dataDirectory: dataDir, version: indexVersion, generated: generated,
                source: source, keepVolume: keepVolume)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(index)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: outputURL)

            print("""

                Wrote \(outputURL.path)  (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))
                  records parsed:            \(stats.recordsParsed)
                  with FRUS anchors (kept):  \(stats.recordsWithFRUSAnchors)
                  crosswalk (volume,ref)→id: \(stats.crosswalkEntries)
                  distinct volumes:          \(stats.distinctVolumes)
                  canonical ids with VIAF:   \(stats.withViaf)
                """)

            if !manifestVolumes.isEmpty {
                let covered = Set(index.crosswalk.keys)
                let manifestWithPersons = manifestVolumes.intersection(covered)
                print("  manifest volumes covered:  \(manifestWithPersons.count) / \(manifestVolumes.count)")
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    // MARK: - Helpers

    /// Extracts the set of volume ids from the app's `manifest.json` (tolerant of its shape:
    /// any `"id"` / `"volumeId"` string values that look like FRUS volume ids are collected).
    static func loadManifestVolumeIds(_ url: URL) throws -> Set<String> {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        var ids = Set<String>()
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                for key in ["id", "volumeId", "volume_id"] {
                    if let v = dict[key] as? String, v.hasPrefix("frus") { ids.insert(v) }
                }
                dict.values.forEach(walk)
            } else if let arr = node as? [Any] {
                arr.forEach(walk)
            }
        }
        walk(json)
        return ids
    }

    static func isoDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }
}
