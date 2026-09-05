// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - BundledArtifactProvenanceTests

/// The tier is DERIVED from the generators, and this suite is what makes that true.
///
/// A table of tiers maintained by hand would rot within two waves: a generator gains an input,
/// nobody updates the table, and the app goes on telling readers a value came from FRUS alone when
/// it no longer does. That failure is silent and it reaches footnotes, which is the one place this
/// wave exists to protect. So the suite reads the generator sources and fails when they disagree
/// with the table.
///
/// Version history:
///   1.0 — PV-0: initial implementation
@Suite("Bundled artifact provenance")
struct BundledArtifactProvenanceTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// The data inputs a generator's sources actually read, found by scanning for the env names.
    private static func inputsRead(byGenerator prefix: String) throws -> Set<String> {
        let dir = repoRoot.appendingPathComponent("\(prefix)GeneratorCore")
        var found: Set<String> = []
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return found
        }
        for case let url as URL in e where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for name in BundledArtifactProvenance.dataInputs where text.contains("\"\(name)\"") {
                found.insert(name)
            }
        }
        return found
    }

    /// **The guard.** If a generator starts reading a data input the table does not list, the tier
    /// it implies may be wrong — so the build fails until someone decides what the new input means.
    @Test("Every generator's declared inputs match what its source reads")
    func declaredInputsMatchTheSources() throws {
        var mismatches: [String] = []
        for (artifact, entry) in BundledArtifactProvenance.table.sorted(by: { $0.key < $1.key }) {
            let dir = Self.repoRoot.appendingPathComponent("\(entry.generator)GeneratorCore")
            guard FileManager.default.fileExists(atPath: dir.path) else {
                // Manifest and Taxonomy read no data input and keep their logic elsewhere; a
                // missing Core directory is only acceptable when the row declares no inputs.
                if !entry.declaredInputs.isEmpty {
                    mismatches.append("\(artifact): no \(entry.generator)GeneratorCore, but the row declares \(entry.declaredInputs.sorted())")
                }
                continue
            }
            let actual = try Self.inputsRead(byGenerator: entry.generator)
            if actual != entry.declaredInputs {
                let gained = actual.subtracting(entry.declaredInputs).sorted()
                let lost = entry.declaredInputs.subtracting(actual).sorted()
                mismatches.append("""
                    \(artifact) (\(entry.generator)): \
                    \(gained.isEmpty ? "" : "GAINED \(gained) — decide what it means for the tier; ")\
                    \(lost.isEmpty ? "" : "no longer reads \(lost)")
                    """)
            }
        }
        #expect(mismatches.isEmpty, Comment(rawValue: """
            The provenance table disagrees with the generators:
            \(mismatches.joined(separator: "\n"))
            """))
    }

    /// A Tier-1 claim is the strongest thing this app says about a value, so it may rest only on
    /// the volumes — or on the administrations calendar, which is a public-record constant by
    /// owner decision rather than a dataset that could disagree with FRUS.
    @Test("Nothing claims Tier 1 on a non-FRUS input unless the fields say why")
    func tierOneRestsOnFRUSAlone() throws {
        for (artifact, entry) in BundledArtifactProvenance.table where entry.source.tier == .frusOnly {
            let outside = entry.declaredInputs.subtracting(BundledArtifactProvenance.frusOnlyInputs)
            if outside.isEmpty { continue }
            // The §1a case is permitted, but only when the row explains which fields it reads.
            #expect(entry.readsOnlyFRUSFields != nil, Comment(rawValue: """
                \(artifact) claims Tier 1 while reading \(outside.sorted()); a row that does that \
                must say which fields it reads and why they are FRUS-derived
                """))
        }
    }

    /// Every bundled artifact the app ships must be tiered, or a value could reach a footnote with
    /// no provenance at all. Config payloads that carry no corpus data are exempt by name.
    @Test("Every bundled data artifact has a provenance row")
    func everyArtifactIsTiered() throws {
        let exempt: Set<String> = [
            "tei-rendering-config.json", "word-cloud-lexicons.json", "word-cloud-stopwords.json",
            "administrations.json", "curated-lot-resolutions.json", "curated-library-resolutions.json",
            "semantic-shards-manifest.json", "source-explorer-export-summary.json",
        ]
        let resources = Self.repoRoot.appendingPathComponent("FRUSExplorer/Resources")
        let shipped = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".json") }
        let untiered = shipped
            .filter { BundledArtifactProvenance.table[$0] == nil && !exempt.contains($0) }
            .sorted()
        #expect(untiered.isEmpty, Comment(rawValue: """
            \(untiered.count) bundled artifact(s) have no provenance row, so a value from them \
            could be reported with no source stated: \(untiered.joined(separator: ", "))
            """))
    }

    /// The eight labels are a closed vocabulary the reader learns; each must say something, and
    /// each joined source must name a partner a reader can go and read.
    @Test("Every source has a label, a method sentence, and a partner where one is owed")
    func everySourceSpeaks() {
        for source in ProvenanceSource.allCases {
            #expect(!source.label.isEmpty)
            #expect(!source.methodSentence.isEmpty)
            if source.tier == .joined {
                #expect(source.methodSentence.contains(source.partnerName),
                        Comment(rawValue: "\(source) is a join and must name what it joined to"))
            }
        }
        #expect(ProvenanceSource.allCases.count == 8, "the vocabulary is eight labels by decision")
    }
}
