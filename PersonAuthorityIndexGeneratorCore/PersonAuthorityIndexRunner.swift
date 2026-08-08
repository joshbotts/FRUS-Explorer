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
/// - `PERSONS_COMPLETE` (optional, schema v2): `frus-name-authority/4_Outputs/persons-complete.xml`
///    — identifier enrichment plus the #260 crosswalk expansion.
/// - `MERGE_AUDIT_CSV` (optional, **required in practice** when `PERSONS_COMPLETE` is set):
///    `4_Outputs/merge_audit_report.csv`. Without it the audit guard cannot run and the build
///    refuses, rather than enriching from merges a human review rejected.
/// - `GENERATED_DATE` (optional): pins the `generated` stamp for a reproducible build.
/// - `ROLE_CHAR_LIMIT` (optional, default 120): the bundle-size lever for overlay role text.
public enum PersonAuthorityIndexRunner {

    /// Current schema version of the generated index.
    ///
    /// v2 (#736) adds the POCOM slug (`s`), Wikidata QID (`q`) and role text (`r`) to each
    /// authority entry, and expands the crosswalk from `persons-complete.xml`.
    public static let indexVersion = 2

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

        let generated = environment["GENERATED_DATE"] ?? Self.isoDate()
        var source = "HistoryAtState/people (CC0 / public domain)"

        // Schema v2 overlay. Both inputs or neither: the audit guard is what keeps 32
        // human-rejected merges out of the index, and a build that quietly skipped it would look
        // identical to one that applied it.
        var overlay: PersonAuthorityIndexBuilder.Overlay?
        if let personsPath = environment["PERSONS_COMPLETE"], !personsPath.isEmpty {
            guard let auditPath = environment["MERGE_AUDIT_CSV"], !auditPath.isEmpty else {
                FileHandle.standardError.write(Data("""
                    error: PERSONS_COMPLETE is set but MERGE_AUDIT_CSV is not.
                    The overlay must not run without the audit guard — 32 flagged pairs in that CSV
                    are auto-merges a human review rejected or doubted, and enriching from them
                    attaches one person's identifiers to another person's record.

                    """.utf8))
                exit(2)
            }
            do {
                let personsXML = try String(contentsOf: URL(fileURLWithPath: personsPath),
                                            encoding: .utf8)
                let auditCSV = try String(contentsOf: URL(fileURLWithPath: auditPath),
                                          encoding: .utf8)
                let entries = PersonsCompleteOverlay.parse(xml: personsXML)
                let flagged = PersonsCompleteOverlay.flaggedPeopleIds(
                    auditCSV: auditCSV, entries: entries)
                guard !flagged.isEmpty else {
                    FileHandle.standardError.write(Data("""
                        error: the audit guard resolved 0 people-ids from \(auditPath).
                        That CSV keys on FRUS-NNNNN xml:ids, which are re-minted between drops — if
                        it no longer matches persons-complete.xml, the guard is silently inert and
                        the build must not proceed.

                        """.utf8))
                    exit(1)
                }
                let limit = environment["ROLE_CHAR_LIMIT"].flatMap(Int.init) ?? 120
                overlay = PersonAuthorityIndexBuilder.Overlay(
                    entries: entries, flaggedPeopleIds: flagged, roleCharacterLimit: limit)
                // Pinned in provenance because it CANNOT be recomputed later: after the planned
                // upstream xml:id re-mint, the same CSV rows name different people.
                source += "; overlay frus-name-authority persons-complete.xml"
                    + " (\(entries.count) entries, audit-guarded ids: "
                    + flagged.sorted().joined(separator: ",") + ")"
                print("Overlay: \(entries.count) entries; audit guard resolved "
                    + "\(flagged.count) people-ids to skip.")
            } catch {
                FileHandle.standardError.write(Data("error reading overlay inputs: \(error)\n".utf8))
                exit(1)
            }
        }

        do {
            print("Building person-authority index from \(dataDir.path) …")
            let (index, stats) = try PersonAuthorityIndexBuilder.build(
                dataDirectory: dataDir, version: indexVersion, generated: generated,
                source: source, keepVolume: keepVolume, overlay: overlay)

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
                  with a POCOM slug:         \(stats.withPOCOMSlug)
                  with a Wikidata QID:       \(stats.withWikidata)
                  with role text:            \(stats.withRole)
                """)

            if overlay != nil {
                print("""
                      overlay entries read:      \(stats.overlayEntriesRead)
                      skipped by the audit guard:\(stats.overlayEntriesSkippedByAudit)
                      crosswalk pairs added:     \(stats.crosswalkPairsAdded)
                      crosswalk volumes added:   \(stats.crosswalkVolumesAdded)
                      anchors where the two sources DISAGREE (registry kept): \(stats.crosswalkConflicts.count)
                    """)
                if !stats.unknownOverlayIds.isEmpty {
                    print("      overlay anchors dropped — no registry entry for their people-id: "
                        + "\(stats.unknownOverlayIds.count) ids")
                }
                // Printed in full rather than counted: the issue's acceptance is that a human
                // reads these before the index ships.
                if !stats.crosswalkConflicts.isEmpty {
                    print("\n  --- conflicting anchors (registry id kept, overlay id shown) ---")
                    for c in stats.crosswalkConflicts.sorted(by: {
                        ($0.volumeId, $0.ref) < ($1.volumeId, $1.ref)
                    }) {
                        print("    \(c.volumeId)#\(c.ref)  registry=\(c.registry)  overlay=\(c.overlay)")
                    }
                }
            }

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
