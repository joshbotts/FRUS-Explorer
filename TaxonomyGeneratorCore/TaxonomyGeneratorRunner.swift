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
/// 3. Ask `TaxonomyGate` whether the result may replace the file at the output path
/// 4. Write `volume-tag-taxonomy.json` (`TaxonomyWriter`)
///
/// ## When to Run
/// Run manually whenever the tag taxonomy on history.state.gov changes. Review the
/// resulting JSON diff carefully before committing — unexpected changes may indicate
/// a page redesign that requires updating `TaxonomyParser`.
///
/// ## When it refuses to write (#1600)
/// When the page gave no tags, when a tag sits outside people, places and topics, or when more
/// than one in ten of the slugs in the file at the output path are gone from the new list
/// (`TaxonomyGate`). It then leaves the file as it was, says why, and exits 1.
///
/// ## Output Path
/// By default writes to `./FRUSExplorer/Resources/volume-tag-taxonomy.json` relative
/// to the current working directory (the project root when invoked via `swift run`).
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — #1600: `generate(fromHTML:outputPath:)`, which asks `TaxonomyGate` before it writes;
///         the run reports the tags the new list adds and drops
public struct TaxonomyGeneratorRunner {

    /// Default output path relative to the project root.
    public static let defaultOutputPath = "FRUSExplorer/Resources/volume-tag-taxonomy.json"

    private init() {}

    /// What a run that wrote the file did.
    public struct Outcome: Sendable, Equatable {
        /// The entries written, in the parser's order.
        public let entries: [TagTaxonomyFileEntry]
        /// Slugs the replaced file had and the new one lacks, sorted. Empty when no file was replaced.
        public let lostSlugs: [String]
        /// Slugs the new file has and the replaced one lacked, sorted. Every slug when no file was replaced.
        public let newSlugs: [String]
    }

    /// Parses the tags page and writes the taxonomy, unless `TaxonomyGate` refuses it.
    ///
    /// Everything a run does after the fetch, so a test can drive it with a page of its own.
    ///
    /// - Parameters:
    ///   - html: The page's HTML.
    ///   - outputPath: Where the taxonomy is written. A taxonomy already there is what the new one
    ///     is measured against.
    /// - Returns: What was written, and how it differs from the file it replaced.
    /// - Throws: `TaxonomyRefusal` when the file is left as it was; `TaxonomyWriterError` when
    ///   the write fails.
    @discardableResult
    public static func generate(fromHTML html: String, outputPath: String) throws -> Outcome {
        let entries = TaxonomyParser.parse(html: html).map { $0.asFileEntry() }
        let existing = existingTaxonomy(at: outputPath)
        if let refusal = TaxonomyGate.refusal(for: entries, replacing: existing) {
            throw refusal
        }
        try TaxonomyWriter.write(entries: entries, to: outputPath)
        return Outcome(
            entries: entries,
            lostSlugs: TaxonomyGate.slugs(of: existing ?? [], missingFrom: entries),
            newSlugs: TaxonomyGate.slugs(of: entries, missingFrom: existing ?? []))
    }

    /// The taxonomy in the file at `path`, or `nil` when there is no file or it does not decode.
    static func existingTaxonomy(at path: String) -> [TagTaxonomyFileEntry]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode([TagTaxonomyFileEntry].self, from: data)
    }

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

        do {
            let outcome = try generate(fromHTML: html, outputPath: outputPath)
            print("[TaxonomyGenerator] Parsed \(outcome.entries.count) tag entries.")

            // Summary by category.
            let byCategory = Dictionary(grouping: outcome.entries, by: \.category)
            for (cat, tags) in byCategory.sorted(by: { $0.key < $1.key }) {
                print("[TaxonomyGenerator]   \(cat): \(tags.count) tags")
            }
            if !outcome.lostSlugs.isEmpty {
                print("[TaxonomyGenerator]   no longer listed (\(outcome.lostSlugs.count)): "
                      + outcome.lostSlugs.joined(separator: ", "))
            }
            if !outcome.newSlugs.isEmpty, outcome.newSlugs.count < outcome.entries.count {
                print("[TaxonomyGenerator]   new (\(outcome.newSlugs.count)): "
                      + outcome.newSlugs.joined(separator: ", "))
            }
            print("[TaxonomyGenerator] ✓ volume-tag-taxonomy.json written to \(outputPath)")
        } catch let refusal as TaxonomyRefusal {
            print("[TaxonomyGenerator] ✗ Refusing to write \(outputPath): \(refusal)")
            exit(1)
        } catch {
            print("[TaxonomyGenerator] ✗ Failed to write taxonomy: \(error)")
            exit(1)
        }
    }
}
