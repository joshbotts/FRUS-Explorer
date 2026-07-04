// swift-tools-version: 6.0
// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import PackageDescription

/// SPM package for FRUS Explorer command-line tools and reusable library components.
///
/// This package is separate from `FRUSExplorer.xcodeproj` (the iOS/macOS app).
///
/// ## Command-Line Tools
///
/// - **ManifestGenerator**: parses `<teiHeader>` from each FRUS volume XML hosted on
///   the HistoryAtState GitHub repository and produces `manifest.json`, committed into
///   the app bundle. Run before each app release.
///
/// - **TaxonomyGenerator**: fetches and parses `history.state.gov/tags/all` to produce
///   `volume-tag-taxonomy.json`, which provides humanised display names and hierarchy for
///   volume-level subject tag slugs. Run manually when the taxonomy changes.
///
/// - **CentralFilesIndexGenerator**: harvests the digitized pre-1910 State Dept. Central
///   Files from the NARA Catalog v2 API and produces `central-files-index.json`, a bundled
///   map from archival citations to roll-level catalog records. Phase 1 covers the
///   1906–1910 Numerical File (microfilm M862). Requires `CATALOG_API_KEY`; caches raw
///   pages to disk. Run when refreshing the bundled index.
///
/// - **CollectionAuthorityGenerator**: builds the bundled `collection-authority.json`
///   (Source Explorer Phase 4) — a corpus-wide two-level authority of the archival
///   collections cited across all FRUS volumes (front matter + document source notes),
///   with alias forms, citing-volume lists, and offline-resolved NARA NAIDs. Entirely
///   offline; run against a local TEI mirror when refreshing the bundled artifact.
///
/// - **SourceNoteEvalGenerator**: runs `SourceNoteParser` over the offline
///   `citations.csv` eval corpus (267k source notes, 520 volumes) and writes a
///   deterministic, diffable classification-rate report bucketed by FRUS era.
///   Regression harness for parser grammar work; the committed BEFORE snapshot lives
///   at `SourceNoteKit/eval-baseline.txt`. Env: `CITATIONS_CSV`, `OUTPUT`.
///
/// ## Library Components
///
/// - **FTS5Store**: Swift actor wrapping SQLite FTS5 for full-text search. Used by the
///   app's search indexing pipeline. Designed for reuse outside FRUS Explorer.
///
/// - **SourceNoteKit**: the FRUS source-note parser shared between the app targets
///   (compiled directly via `project.yml`, like FTS5Store) and the eval harness.
///
/// Each tool is split into a library target (all logic, fully testable) and a thin
/// executable target (entry point only). Tests import the library targets directly.
///
/// To run a tool (from the project root):
/// ```
/// swift run ManifestGenerator
/// swift run TaxonomyGenerator
/// ```
let package = Package(
    name: "FRUSExplorerTools",
    platforms: [
        .macOS(.v15)
    ],
    targets: [

        // MARK: - ManifestGenerator

        /// All manifest-generation logic. Imported by both the executable and test target.
        .target(
            name: "ManifestGeneratorCore",
            path: "ManifestGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls ManifestGeneratorRunner.run() and exits.
        .executableTarget(
            name: "ManifestGenerator",
            dependencies: [.target(name: "ManifestGeneratorCore")],
            path: "ManifestGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for ManifestGeneratorCore logic.
        .testTarget(
            name: "ManifestGeneratorTests",
            dependencies: [.target(name: "ManifestGeneratorCore")],
            path: "ManifestGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - TaxonomyGenerator

        /// All taxonomy-generation logic. Imported by both the executable and test target.
        .target(
            name: "TaxonomyGeneratorCore",
            path: "TaxonomyGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls TaxonomyGeneratorRunner.run() and exits.
        .executableTarget(
            name: "TaxonomyGenerator",
            dependencies: [.target(name: "TaxonomyGeneratorCore")],
            path: "TaxonomyGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for TaxonomyGeneratorCore logic.
        .testTarget(
            name: "TaxonomyGeneratorTests",
            dependencies: [.target(name: "TaxonomyGeneratorCore")],
            path: "TaxonomyGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - CentralFilesIndexGenerator

        /// All Central Files index-harvest logic. Imported by the executable and tests.
        /// Phase 1 covers the 1906–1910 Numerical File (microfilm M862, series NAID 654171):
        /// it enumerates the digitized rolls in the NARA Catalog and builds a bundled
        /// case-number → roll index so the app can resolve a State Dept. "File No." to the
        /// exact roll for page-by-page review without any runtime API calls.
        .target(
            name: "CentralFilesIndexGeneratorCore",
            path: "CentralFilesIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls CentralFilesIndexGeneratorRunner.run() and exits.
        .executableTarget(
            name: "CentralFilesIndexGenerator",
            dependencies: [.target(name: "CentralFilesIndexGeneratorCore")],
            path: "CentralFilesIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for CentralFilesIndexGeneratorCore logic.
        .testTarget(
            name: "CentralFilesIndexGeneratorTests",
            dependencies: [.target(name: "CentralFilesIndexGeneratorCore")],
            path: "CentralFilesIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - PersonAuthorityIndexGenerator

        /// Builds `person-authority-index.json` from a checkout of the Office of the Historian's
        /// public-domain `HistoryAtState/people` registry: a `(volume, ref) → canonicalId` crosswalk
        /// plus canonical names/birth-death years/VIAF ids, so the app can key its person rollup on
        /// authoritative identities instead of (only) heuristic clustering.
        .target(
            name: "PersonAuthorityIndexGeneratorCore",
            path: "PersonAuthorityIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls PersonAuthorityIndexRunner.run() and exits.
        .executableTarget(
            name: "PersonAuthorityIndexGenerator",
            dependencies: [.target(name: "PersonAuthorityIndexGeneratorCore")],
            path: "PersonAuthorityIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for PersonAuthorityIndexGeneratorCore logic.
        .testTarget(
            name: "PersonAuthorityIndexGeneratorTests",
            dependencies: [.target(name: "PersonAuthorityIndexGeneratorCore")],
            path: "PersonAuthorityIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - VolumeSourcesIndexGenerator

        /// Harvests every volume's front-matter Sources section into `volume-sources-index.json`:
        /// per-volume prose + a resolved archival-collection outline, plus a deduplicated
        /// cross-volume authority. Lot files resolve offline against `central-files-index.json`;
        /// record-group / repository headers are reported for a later NARA Catalog API pass.
        .target(
            name: "VolumeSourcesIndexGeneratorCore",
            dependencies: [.target(name: "CentralFilesIndexGeneratorCore")],
            path: "VolumeSourcesIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls VolumeSourcesIndexRunner.run() and exits.
        .executableTarget(
            name: "VolumeSourcesIndexGenerator",
            dependencies: [.target(name: "VolumeSourcesIndexGeneratorCore")],
            path: "VolumeSourcesIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for VolumeSourcesIndexGeneratorCore logic.
        .testTarget(
            name: "VolumeSourcesIndexGeneratorTests",
            dependencies: [.target(name: "VolumeSourcesIndexGeneratorCore")],
            path: "VolumeSourcesIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - CollectionAuthorityGenerator

        /// Source Explorer Phase 4: builds the bundled `collection-authority.json` — a
        /// corpus-wide, two-level authority of the archival collections FRUS editors cite
        /// (front-matter Sources sections + document source notes across all 694 TEI
        /// volumes), clustered by normalized lot key / leading citation segment (the
        /// frus-sources `merge.xq` reconciliation model at two-level depth) with alias
        /// forms, citing-volume lists, and offline-resolved NARA NAIDs. Ships identity
        /// only — never document counts (S5: counts are recomputed from the user's index).
        .target(
            name: "CollectionAuthorityGeneratorCore",
            dependencies: [
                .target(name: "SourceNoteKit"),
                .target(name: "VolumeSourcesIndexGeneratorCore"),
            ],
            path: "CollectionAuthorityGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls CollectionAuthorityRunner.run() and exits.
        .executableTarget(
            name: "CollectionAuthorityGenerator",
            dependencies: [.target(name: "CollectionAuthorityGeneratorCore")],
            path: "CollectionAuthorityGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for CollectionAuthorityGeneratorCore (segment tokenization,
        /// two-level merge, conservative-merge guardrails, extraction parity,
        /// determinism).
        .testTarget(
            name: "CollectionAuthorityGeneratorTests",
            dependencies: [.target(name: "CollectionAuthorityGeneratorCore")],
            path: "CollectionAuthorityGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SourceProvenanceIndexGenerator

        /// Builds the bundled `source-provenance-index.json` (SA-3a): parses every
        /// FRUS volume's per-document source notes with the app's real `SourceNoteParser`
        /// grammar, maps each parse to a stable `ProvenanceCategory`, and aggregates the
        /// counts by coverage decade (from the enriched `manifest.json` date ranges) so
        /// the SA-3 "Archival Sourcing Over Time" dashboard can render the corpus-wide
        /// provenance evolution offline / zero-index. Entirely offline.
        .target(
            name: "SourceProvenanceIndexGeneratorCore",
            dependencies: [.target(name: "SourceNoteKit")],
            path: "SourceProvenanceIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls SourceProvenanceIndexRunner.run() and exits.
        .executableTarget(
            name: "SourceProvenanceIndexGenerator",
            dependencies: [.target(name: "SourceProvenanceIndexGeneratorCore")],
            path: "SourceProvenanceIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for SourceProvenanceIndexGeneratorCore (category mapping,
        /// full-parser pipeline, decade bucketing, aggregation, determinism).
        .testTarget(
            name: "SourceProvenanceIndexGeneratorTests",
            dependencies: [.target(name: "SourceProvenanceIndexGeneratorCore")],
            path: "SourceProvenanceIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SourceNoteKit

        /// The FRUS source-note parser (`SourceNoteParser`, `ParsedSourceNote`,
        /// `ParsedVolumeSources`, `ArchiveCitation`), shared between the app and the
        /// SPM eval harness. Like FTS5Store, these sources are ALSO compiled directly
        /// into both app targets via a `project.yml` path entry (no SPM product
        /// linkage), so the app and `SourceNoteEvalGenerator` always run the exact
        /// same grammar.
        .target(
            name: "SourceNoteKit",
            path: "SourceNoteKit",
            exclude: ["eval-baseline.txt", "eval-report.txt"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for the shared source-note parser grammar (era-realistic
        /// fixtures for every Phase 2 grammar upgrade).
        .testTarget(
            name: "SourceNoteKitTests",
            dependencies: [.target(name: "SourceNoteKit")],
            path: "SourceNoteKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SourceNoteEvalGenerator

        /// All eval-harness logic: streams `citations.csv` (RFC-4180, quoted TEI
        /// fields), replicates the IndexingPipeline's post-extraction note
        /// normalization, runs `SourceNoteParser` over every source-note row, and
        /// emits a deterministic, diffable classification-rate report bucketed by
        /// FRUS era. Imported by the executable and tests.
        .target(
            name: "SourceNoteEvalGeneratorCore",
            dependencies: [.target(name: "SourceNoteKit")],
            path: "SourceNoteEvalGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls SourceNoteEvalRunner.run() and exits.
        .executableTarget(
            name: "SourceNoteEvalGenerator",
            dependencies: [.target(name: "SourceNoteEvalGeneratorCore")],
            path: "SourceNoteEvalGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for SourceNoteEvalGeneratorCore logic (CSV parsing, era
        /// bucketing, note normalization).
        .testTarget(
            name: "SourceNoteEvalGeneratorTests",
            dependencies: [.target(name: "SourceNoteEvalGeneratorCore")],
            path: "SourceNoteEvalGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - FTS5Store

        /// SQLite FTS5 Swift wrapper. Actor-based, async/await, Swift 6 strict concurrency.
        /// Provides full-text search over FRUS documents with English stemming and BM25 ranking.
        /// Designed for reuse outside FRUS Explorer.
        .target(
            name: "FTS5Store",
            path: "FTS5Store",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),

        /// Unit tests for FTS5Store.
        .testTarget(
            name: "FTS5StoreTests",
            dependencies: [.target(name: "FTS5Store")],
            path: "FTS5StoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
