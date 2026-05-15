// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Orchestrates the full taxonomy generation pipeline.
///
/// Called from `TaxonomyGenerator/main.swift`. Steps:
/// 1. Fetch `history.state.gov/tags/all` HTML (`TaxonomyFetcher`)
/// 2. Parse the three-level hierarchy (`TaxonomyParser`)
/// 3. Write `volume-tag-taxonomy.json` (`TaxonomyWriter`)
///
/// ## When to Run
/// Run manually whenever the tag taxonomy on history.state.gov changes. Review the
/// resulting JSON diff carefully before committing — unexpected changes may indicate
/// a page redesign that requires updating `TaxonomyParser`.
///
/// ## Output Path
/// By default writes to `./FRUSExplorer/Resources/volume-tag-taxonomy.json` relative
/// to the current working directory (the project root when invoked via `swift run`).
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct TaxonomyGeneratorRunner {

    /// Default output path relative to the project root.
    public static let defaultOutputPath = "FRUSExplorer/Resources/volume-tag-taxonomy.json"

    private init() {}

    /// Runs the full taxonomy generation pipeline.
    ///
    /// - Parameter outputPath: Where to write the taxonomy JSON. Defaults to `defaultOutputPath`.
    public static func run(outputPath: String = defaultOutputPath) async {
        print("[TaxonomyGenerator] Starting taxonomy generation…")

        let html: String
        do {
            html = try await TaxonomyFetcher.fetch()
        } catch {
            print("[TaxonomyGenerator] ✗ Failed to fetch taxonomy page: \(error)")
            exit(1)
        }

        let rawEntries = TaxonomyParser.parse(html: html)
        print("[TaxonomyGenerator] Parsed \(rawEntries.count) tag entries.")

        // Summary by category.
        let byCategory = Dictionary(grouping: rawEntries, by: \.category)
        for (cat, tags) in byCategory.sorted(by: { $0.key < $1.key }) {
            print("[TaxonomyGenerator]   \(cat): \(tags.count) tags")
        }

        let fileEntries = rawEntries.map { $0.asFileEntry() }

        do {
            try TaxonomyWriter.write(entries: fileEntries, to: outputPath)
            print("[TaxonomyGenerator] ✓ volume-tag-taxonomy.json written to \(outputPath)")
        } catch {
            print("[TaxonomyGenerator] ✗ Failed to write taxonomy: \(error)")
            exit(1)
        }
    }
}
