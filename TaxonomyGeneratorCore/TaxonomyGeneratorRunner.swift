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
/// Called from `TaxonomyGenerator/main.swift`. For each source in turn (`TaxonomySource`) until
/// one is written:
/// 1. Fetch it (`TaxonomyFetcher`)
/// 2. Parse the hierarchy (`TaxonomyXMLParser` for the repository's file, `TaxonomyParser` for
///    the page)
/// 3. Ask `TaxonomyGate` whether the result may replace the file at the output path
/// 4. Write `volume-tag-taxonomy.json` (`TaxonomyWriter`)
///
/// ## When to Run
/// Run manually whenever the Office of the Historian's tag taxonomy changes. Review the
/// resulting JSON diff carefully before committing.
///
/// ## Two sources (#1622)
/// The repository's file is read first and the page second (`TaxonomySource.automaticOrder`). A
/// source that cannot be fetched, cannot be parsed or is refused by the gate is passed over,
/// with its reason printed, and the next is read. `TAXONOMY_SOURCE` names one source and stops
/// the run there. Until #1622 the page was the only source, and a page whose markup had changed
/// left the tool with nothing to read.
///
/// ## When it refuses to write (#1600)
/// When a source gave no tags, when a tag sits outside people, places and topics, or when more
/// than one in ten of the slugs in the file at the output path are gone from the new list
/// (`TaxonomyGate`). When that is so of every source read, the run leaves the file as it was,
/// says why, and exits 1.
///
/// ## Output Path
/// By default writes to `./FRUSExplorer/Resources/volume-tag-taxonomy.json` relative
/// to the current working directory (the project root when invoked via `swift run`).
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — #1600: `generate(fromHTML:outputPath:)`, which asks `TaxonomyGate` before it writes;
///         the run reports the tags the new list adds and drops
///   1.2 — #1622: `generate(fromTaxonomyXML:outputPath:)` for the repository's file, and
///         `generate(from:outputPath:read:)`, which reads the sources in order and writes the
///         first the gate accepts
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

    /// A source that gave nothing to write, and why.
    public struct PassedOver: Sendable, Equatable {
        /// The source read.
        public let source: TaxonomySource
        /// Why nothing was written from it, as the run prints it.
        public let reason: String
    }

    /// What a run over one or more sources did.
    public struct SourcedOutcome: Sendable, Equatable {
        /// The source the file was written from.
        public let source: TaxonomySource
        /// What was written.
        public let outcome: Outcome
        /// The sources read before it, in order.
        public let passedOver: [PassedOver]
    }

    /// No source gave a taxonomy the gate accepts. The file at the output path is as it was.
    public struct NothingToWrite: Error, Sendable, Equatable {
        /// Every source read, in order, with its reason.
        public let passedOver: [PassedOver]
    }

    /// Parses the tags page and writes the taxonomy, unless `TaxonomyGate` refuses it.
    ///
    /// Everything a run does with the page after the fetch, so a test can drive it with a page
    /// of its own.
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
        try write(TaxonomyParser.parse(html: html).map { $0.asFileEntry() }, to: outputPath)
    }

    /// Parses the repository's taxonomy file and writes the taxonomy, unless `TaxonomyGate`
    /// refuses it (#1622).
    ///
    /// - Parameters:
    ///   - xml: The file's bytes.
    ///   - outputPath: Where the taxonomy is written, as in ``generate(fromHTML:outputPath:)``.
    /// - Returns: What was written, and how it differs from the file it replaced.
    /// - Throws: `TaxonomyXMLError` when the file cannot be read as a taxonomy and
    ///   `TaxonomyRefusal` when the gate refuses it, the file left as it was in both cases;
    ///   `TaxonomyWriterError` when the write fails.
    @discardableResult
    public static func generate(fromTaxonomyXML xml: Data, outputPath: String) throws -> Outcome {
        try write(TaxonomyXMLParser.parse(xml: xml).map { $0.asFileEntry() }, to: outputPath)
    }

    /// The gate and the write, which are the same whichever source the entries came from.
    private static func write(_ entries: [TagTaxonomyFileEntry], to outputPath: String) throws -> Outcome {
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

    /// Reads `sources` in order and writes the first taxonomy `TaxonomyGate` accepts (#1622).
    ///
    /// A source is passed over when it cannot be read, cannot be parsed or is refused. A write
    /// that fails is not a reason to read another source, and is thrown as it is.
    ///
    /// - Parameters:
    ///   - sources: The sources to read, in order.
    ///   - outputPath: Where the taxonomy is written.
    ///   - read: Returns a source's text. The run fetches it; a test hands its own.
    /// - Returns: The source written from, what was written, and the sources passed over.
    /// - Throws: ``NothingToWrite`` when no source is written, the file left as it was;
    ///   `TaxonomyWriterError` when the write fails.
    public static func generate(
        from sources: [TaxonomySource], outputPath: String,
        read: (TaxonomySource) async throws -> String
    ) async throws -> SourcedOutcome {
        var passedOver: [PassedOver] = []
        for source in sources {
            let text: String
            do {
                text = try await read(source)
            } catch {
                passedOver.append(PassedOver(source: source, reason: "it could not be read (\(error))."))
                continue
            }
            do {
                let outcome: Outcome
                switch source {
                case .repository:
                    outcome = try generate(fromTaxonomyXML: Data(text.utf8), outputPath: outputPath)
                case .page:
                    outcome = try generate(fromHTML: text, outputPath: outputPath)
                }
                return SourcedOutcome(source: source, outcome: outcome, passedOver: passedOver)
            } catch let refusal as TaxonomyRefusal {
                passedOver.append(PassedOver(source: source, reason: refusal.explanation(for: source)))
            } catch let error as TaxonomyXMLError {
                passedOver.append(PassedOver(source: source, reason: error.description))
            }
        }
        throw NothingToWrite(passedOver: passedOver)
    }

    /// The taxonomy in the file at `path`, or `nil` when there is no file or it does not decode.
    static func existingTaxonomy(at path: String) -> [TagTaxonomyFileEntry]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode([TagTaxonomyFileEntry].self, from: data)
    }

    /// Runs the full taxonomy generation pipeline.
    ///
    /// - Parameters:
    ///   - outputPath: Where to write the taxonomy JSON. Defaults to `defaultOutputPath`.
    ///   - sources: The sources to read, in order. Defaults to `TaxonomySource.automaticOrder`.
    public static func run(outputPath: String = defaultOutputPath,
                           sources: [TaxonomySource] = TaxonomySource.automaticOrder) async {
        print("[TaxonomyGenerator] Starting taxonomy generation…")

        do {
            let result = try await generate(from: sources, outputPath: outputPath) { source in
                try await TaxonomyFetcher.fetch(urlString: source.url)
            }
            report(result.passedOver)
            let outcome = result.outcome
            print("[TaxonomyGenerator] Read \(result.source.name): \(result.source.url)")
            // Printed after the write, which `generate` has made by now: the count is of what the
            // file holds.
            print("[TaxonomyGenerator] \(outcome.entries.count) tag entries:")

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
        } catch let nothing as NothingToWrite {
            report(nothing.passedOver)
            print("[TaxonomyGenerator] ✗ Refusing to write \(outputPath): no source gave a taxonomy to write.")
            exit(1)
        } catch {
            print("[TaxonomyGenerator] ✗ Failed to write taxonomy: \(error)")
            exit(1)
        }
    }

    /// Prints each source that was passed over, with its address and its reason.
    private static func report(_ passedOver: [PassedOver]) {
        for passed in passedOver {
            print("[TaxonomyGenerator] ✗ Nothing written from \(passed.source.name) "
                  + "(\(passed.source.url)): \(passed.reason)")
        }
    }
}
