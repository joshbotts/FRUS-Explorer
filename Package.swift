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
/// - **RecordGroupCatalogGenerator**: builds the offline NARA Catalog index for 22 foreign-affairs
///   record groups (43, 59, 63, 76, 84, 169, 182, 208, 229, 239, 256, 268, 278, 286, 306, 353, 383,
///   420, 466, 469, 486, 490) — a spin-off of `CentralFilesIndexGenerator` that keeps **all**
///   available description data rather than the few fields a citation lookup needs, with creator
///   authority information and the complete unfiltered `variantControlNumbers` as its two priority
///   payloads. Harvests NARA's **public S3 bulk export**, so it needs no `CATALOG_API_KEY` and is
///   subject to no quota; series-level by default, with per-record-group opt-in to file units. Also
///   emits a field/value/control-number/creator census. See
///   `Planning/nara-record-group-catalog-runbook.md`.
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
/// - **SourceExplorerExportGenerator**: the corpus-wide Source Explorer data export
///   (#335) — one record per document source note (canonical id, raw stored note, the
///   parsed value handed to Source Explorer logic, the strategy, and the offline
///   resolution results across the three bundled artifacts), streamed to
///   `Planning/source-explorer-export/` with a committed aggregate summary + sample.
///   Entirely offline; the basis for the Source Explorer accuracy audit.
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
        // The FRUS `<teiHeader>` grammar, shared by the manifest generator and the app.
        // Compiled into the app targets through project.yml as well (the SourceNoteKit pattern),
        // so a side-loaded volume's header is read exactly the way manifest.json was built (#777).
        .target(
            name: "TEIHeaderKit",
            path: "TEIHeaderKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "ManifestGeneratorCore",
            dependencies: [.target(name: "TEIHeaderKit")],
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
            dependencies: [.target(name: "ManifestGeneratorCore"), .target(name: "TEIHeaderKit")],
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
        /// The two edges below are #372 item 1b. `SourceNoteKit` supplies
        /// `LotResolutionAcceptance`, so the harvester stops carrying a private copy of the
        /// acceptance rule the app applies at render time; `LotClaimantsIndexGeneratorCore`
        /// supplies `HarvestShardReader`, for the reason its own header and
        /// `SeriesFactsIndexGeneratorCore` both give — a second decoder over the same shards is
        /// a second thing that can drift. Both are acyclic: `SourceNoteKit` declares no
        /// dependencies at all, and `LotClaimantsIndexGeneratorCore` depends only on
        /// `GeneratorKit` + `SourceNoteKit`, neither of which reaches back here.
        .target(
            name: "CentralFilesIndexGeneratorCore",
            dependencies: [
                .target(name: "GeneratorKit"),
                .target(name: "SourceNoteKit"),
                .target(name: "LotClaimantsIndexGeneratorCore"),
            ],
            path: "CentralFilesIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Builds `lot-claimants-index.json` — every NARA series claiming a FRUS lot, for the
        /// lots where more than one does (#675 / N-8b). Entirely offline: reads the
        /// record-group harvest, and matches with the app's own
        /// `LotResolutionAcceptance.foldControlNumber` so the artifact cannot diverge from the
        /// rule Source Explorer applies.
        .target(
            name: "LotClaimantsIndexGeneratorCore",
            dependencies: [
                .target(name: "GeneratorKit"),
                .target(name: "SourceNoteKit"),
            ],
            path: "LotClaimantsIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Builds `decimal-class-labels.json` (#828, design decision D-2): the era-scoped label
        /// table for State Department central-file decimal classes, parsed from NARA's published
        /// classification manuals. COMPOSITIONAL — class glosses, country numbers and subject
        /// suffixes are stored separately and composed at render time, which the #764 feasibility
        /// study measured at 87.7% of classed documents against 79.4% for a thousand flat rows.
        /// The manuals stay LOCAL (`SCHEDULE_DIR`); the artifact is the reproducible product.
        .target(
            name: "DecimalClassLabelGeneratorCore",
            path: "DecimalClassLabelGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "DecimalClassLabelGenerator",
            dependencies: [.target(name: "DecimalClassLabelGeneratorCore")],
            path: "DecimalClassLabelGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DecimalClassLabelGeneratorTests",
            dependencies: [.target(name: "DecimalClassLabelGeneratorCore")],
            path: "DecimalClassLabelGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Builds the digitised decimal-range index (#663): NARA file units whose titles
        /// state a decimal range and which carry scanned images, so Source Explorer can link
        /// the microfilm PDF for a citation's file range.
        .target(
            name: "DigitizedRangeIndexGeneratorCore",
            path: "DigitizedRangeIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "DigitizedRangeIndexGenerator",
            dependencies: [.target(name: "DigitizedRangeIndexGeneratorCore")],
            path: "DigitizedRangeIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DigitizedRangeIndexGeneratorTests",
            dependencies: [.target(name: "DigitizedRangeIndexGeneratorCore")],
            path: "DigitizedRangeIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Builds `series-facts-index.json` (#405 / F-6): for every NARA series the app can
        /// already name, the organisational body NARA credits with creating it. A DISPLAY
        /// projection — the similarity-axis half of #405 was measured and refused at 2.8%
        /// corpus reachability. Reuses LotClaimantsIndexGeneratorCore's HarvestShardReader
        /// rather than declaring a second decoder over the same shards.
        .target(
            name: "SeriesFactsIndexGeneratorCore",
            dependencies: [
                .target(name: "GeneratorKit"),
                .target(name: "LotClaimantsIndexGeneratorCore"),
            ],
            path: "SeriesFactsIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls SeriesFactsIndexRunner.run() and exits.
        .executableTarget(
            name: "SeriesFactsIndexGenerator",
            dependencies: [.target(name: "SeriesFactsIndexGeneratorCore")],
            path: "SeriesFactsIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for SeriesFactsIndexGeneratorCore.
        .testTarget(
            name: "SeriesFactsIndexGeneratorTests",
            dependencies: [
                .target(name: "SeriesFactsIndexGeneratorCore"),
                .target(name: "LotClaimantsIndexGeneratorCore"),
            ],
            path: "SeriesFactsIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for LotClaimantsIndexGeneratorCore — chiefly `HarvestShardReader`'s
        /// streaming walk (#372 item 1b), pinned against its own whole-array `read(_:)`.
        .testTarget(
            name: "LotClaimantsIndexGeneratorTests",
            dependencies: [.target(name: "LotClaimantsIndexGeneratorCore")],
            path: "LotClaimantsIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls LotClaimantsIndexRunner.run() and exits.
        .executableTarget(
            name: "LotClaimantsIndexGenerator",
            dependencies: [.target(name: "LotClaimantsIndexGeneratorCore")],
            path: "LotClaimantsIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Harvests the NARA Catalog's presidential-library collections and series into an
        /// offline index (#681). Library holdings sit outside every record group, so the
        /// record-group harvester structurally cannot reach them.
        .target(
            name: "PresidentialLibraryCatalogGeneratorCore",
            dependencies: [.target(name: "GeneratorKit")],
            path: "PresidentialLibraryCatalogGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls PresidentialLibraryCatalogRunner.run() and exits.
        .executableTarget(
            name: "PresidentialLibraryCatalogGenerator",
            dependencies: [.target(name: "PresidentialLibraryCatalogGeneratorCore")],
            path: "PresidentialLibraryCatalogGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for the projection, the query shape and the completeness check.
        .testTarget(
            name: "PresidentialLibraryCatalogGeneratorTests",
            dependencies: [.target(name: "PresidentialLibraryCatalogGeneratorCore")],
            path: "PresidentialLibraryCatalogGeneratorTests",
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
            dependencies: [
                .target(name: "CentralFilesIndexGeneratorCore"),
                .target(name: "SourceNoteKit"),
            ],
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

        // MARK: - POCOMIndexGenerator

        /// Builds `pocom-index.json` from a checkout of the Office of the Historian's
        /// public-domain `HistoryAtState/pocom` register — the Principal Officers and Chiefs of
        /// Mission data — so a person's posts and dates can be shown beside their FRUS mentions.
        /// Keyed by POCOM slug, which `person-authority-index.json` schema v2 supplies.
        .target(
            name: "POCOMIndexGeneratorCore",
            path: "POCOMIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls POCOMIndexRunner.run() and exits.
        .executableTarget(
            name: "POCOMIndexGenerator",
            dependencies: [.target(name: "POCOMIndexGeneratorCore")],
            path: "POCOMIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for POCOMIndexGeneratorCore parsing and label rules.
        .testTarget(
            name: "POCOMIndexGeneratorTests",
            dependencies: [.target(name: "POCOMIndexGeneratorCore")],
            path: "POCOMIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - VolumeSourcesIndexGenerator

        /// Harvests every volume's front-matter Sources section into `volume-sources-index.json`:
        /// per-volume prose + a resolved archival-collection outline, plus a deduplicated
        /// cross-volume authority. Lot files resolve offline against `central-files-index.json`;
        /// record-group / repository headers are reported for a later NARA Catalog API pass.
        .target(
            name: "VolumeSourcesIndexGeneratorCore",
            // SourceNoteKit since #733: the lot and CIA-Job grammars are shared with the app
            // rather than re-declared here. The private D-only lot regex this replaced could not
            // see 249 rows across 75 volumes that the app keys.
            dependencies: [
                .target(name: "CentralFilesIndexGeneratorCore"),
                .target(name: "SourceNoteKit"),
                .target(name: "GeneratorKit"),
            ],
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
            dependencies: [
                .target(name: "VolumeSourcesIndexGeneratorCore"),
                .target(name: "SourceNoteKit"),
            ],
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
            dependencies: [.target(name: "SourceNoteKit"), .target(name: "GeneratorKit")],
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

        // MARK: - AdministrationProfilesIndexGenerator

        /// Builds the bundled `administration-profiles-index.json` (SA-2a): reads the
        /// authoritative `frus:doc-dateTime-min`/`-max` bounds on each FRUS document `<div>`
        /// (the same editorial dates `IndexingPipeline.extractDateRange` prefers), classifies
        /// each document as point-dated (single day) / range-dated (multi-day editorial notes)
        /// / undated, and attributes it to the presidential administration(s) in office when it
        /// was written — half-open `[start, end)` for point dates, any-overlap for ranges. The
        /// per-administration and per-volume document/volume counts feed the SA-2 "Administration
        /// Production Profiles" dashboard. Entirely offline.
        .target(
            name: "AdministrationProfilesIndexGeneratorCore",
            path: "AdministrationProfilesIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls AdministrationProfilesIndexRunner.run() and exits.
        .executableTarget(
            name: "AdministrationProfilesIndexGenerator",
            dependencies: [.target(name: "AdministrationProfilesIndexGeneratorCore")],
            path: "AdministrationProfilesIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for AdministrationProfilesIndexGeneratorCore (half-open point
        /// attribution, any-overlap range attribution, aggregation, undated handling,
        /// determinism).
        .testTarget(
            name: "AdministrationProfilesIndexGeneratorTests",
            dependencies: [.target(name: "AdministrationProfilesIndexGeneratorCore")],
            path: "AdministrationProfilesIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - VolumeSubjectProfilesGenerator

        /// Builds the bundled `volume-subject-profiles-index.json` (Wave-6 Session 9):
        /// reads the Office of the Historian's public-domain `frus-subjects`
        /// document–subject mappings and aggregates a per-volume "top subjects" profile
        /// (TF-IDF-style ranking with a genericity floor) for the volume-level Subjects
        /// feature. Entirely offline & deterministic.
        /// #308 Phase 3: `document-subject-index.json` — every document's detected subjects.
        ///
        /// Ships the COMPLETE mapping (491 subjects, 877,817 pairs) with no breadth filter and no
        /// era gate, because three features read it and want different things: display wants
        /// completeness, facets want membership truth (they currently reach 11.7% of it through
        /// the top-15 volume profiles), and similarity wants distinctiveness amplified — which is
        /// a scoring decision, not a bundling one.
        .target(
            name: "DocumentSubjectIndexGeneratorCore",
            dependencies: [.target(name: "GeneratorKit")],
            path: "DocumentSubjectIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DocumentSubjectIndexGeneratorTests",
            dependencies: [.target(name: "DocumentSubjectIndexGeneratorCore")],
            path: "DocumentSubjectIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "DocumentSubjectIndexGenerator",
            dependencies: [.target(name: "DocumentSubjectIndexGeneratorCore")],
            path: "DocumentSubjectIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "VolumeSubjectProfilesGeneratorCore",
            path: "VolumeSubjectProfilesGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls VolumeSubjectProfilesRunner.run() and exits.
        .executableTarget(
            name: "VolumeSubjectProfilesGenerator",
            dependencies: [.target(name: "VolumeSubjectProfilesGeneratorCore")],
            path: "VolumeSubjectProfilesGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for VolumeSubjectProfilesGeneratorCore (genericity exclusion,
        /// min-count floor, ranking, top-N, vocab factoring, determinism).
        .testTarget(
            name: "VolumeSubjectProfilesGeneratorTests",
            dependencies: [.target(name: "VolumeSubjectProfilesGeneratorCore")],
            path: "VolumeSubjectProfilesGeneratorTests",
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

        // MARK: - CrossRefKit

        /// The FRUS cross-reference target grammar, mirrored from the app so the offline validator
        /// classifies `<ref target>` values exactly as the reading view navigates them
        /// (`CrossRefGrammar.resolveDestination` ≡ `FRUSURLSchemeHandler.resolveCrossRefTarget`),
        /// plus the existence-oriented `classifyForValidation`. Pure Foundation; parity-tested
        /// against the app's documented cases. SPM-only this session (a generator dependency);
        /// wiring it into the app targets is a later session's step.
        .target(
            name: "CrossRefKit",
            path: "CrossRefKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for the shared cross-reference grammar (navigation parity + validation
        /// classification + candidate generation).
        .testTarget(
            name: "CrossRefKitTests",
            dependencies: [.target(name: "CrossRefKit")],
            path: "CrossRefKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - WordCloudKit

        /// The word-cloud tokenizer stack, shared between the app targets (compiled
        /// directly via `project.yml`, like FTS5Store and SourceNoteKit) and the offline
        /// `CloudVectorsGenerator`.
        ///
        /// Lexicon and stopword payloads are **injected** rather than read from
        /// `Bundle.main`, which a command-line tool does not have — and which would
        /// otherwise let the app and the generator source different lists without anyone
        /// noticing. The JSON shapes live here so both callers decode identically.
        .target(
            name: "WordCloudKit",
            path: "WordCloudKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for WordCloudKit — chiefly the O-1-2 parity suite, which pins the
        /// one-pass multi-lens tokenizer against four separate single-lens runs.
        .testTarget(
            name: "WordCloudKitTests",
            dependencies: [.target(name: "WordCloudKit")],
            path: "WordCloudKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - CloudVectorsGenerator

        /// Core logic for the onboarding cloud-vector generator (Workstream O, O-1):
        /// byte-scans every shippable volume for `<div type="document">` body text,
        /// tokenises all four bundled lenses in ONE `NLTagger` pass via `WordCloudKit`,
        /// rolls raw counts up volume → subseries → corpus, and packs two int-indexed
        /// artifacts.
        .target(
            name: "CloudVectorsGeneratorCore",
            dependencies: [.target(name: "WordCloudKit"), .target(name: "GeneratorKit")],
            path: "CloudVectorsGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        .executableTarget(
            name: "CloudVectorsGenerator",
            dependencies: [.target(name: "CloudVectorsGeneratorCore")],
            path: "CloudVectorsGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests: TEI extraction, deterministic packing, int-index round-trip,
        /// sentiment polarity, and the below-signal flag.
        .testTarget(
            name: "CloudVectorsGeneratorTests",
            dependencies: [.target(name: "CloudVectorsGeneratorCore")],
            path: "CloudVectorsGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SemanticVectorsKit

        /// The semantic-vector artifact contract, shared between the offline packer and the app —
        /// the `WordCloudKit`/`SourceNoteKit` arrangement, and for the same reason: the two sides
        /// must not be able to disagree about what a byte in the artifact means.
        ///
        /// Holds the artifact shapes and binary layouts, the document-id run-length encoding that
        /// keys every row, mmap-backed readers for the bundled corpus tier and the per-volume
        /// shards, and the retrieval kernel. Compiled into the app targets through `project.yml`
        /// **and** as an SPM library target, so `SemanticVectorsGenerator` writes through exactly
        /// the declarations the device reads through.
        ///
        /// Deliberately excludes everything generator-side — pooling, quantization, the raw-store
        /// reader — because the app never produces vectors, only reads them.
        .target(
            name: "SemanticVectorsKit",
            path: "SemanticVectorsKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for the kit: row keying, binary readers over synthesised artifacts, and the
        /// retrieval kernel's tie-breaks.
        .testTarget(
            name: "SemanticVectorsKitTests",
            dependencies: [.target(name: "SemanticVectorsKit")],
            path: "SemanticVectorsKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SemanticVectorsGenerator

        /// Stage 2 of the semantic-vectors pipeline (V-1): the deterministic packer that turns the
        /// owner-run neural harvest into shippable tiers. Pools chunk vectors to documents under the
        /// pinned rule, applies the Matryoshka cut, quantizes to int8 and to sign bits, and emits
        /// the bundled index + corpus binary plus one downloadable int8 shard per volume.
        ///
        /// The arithmetic mirrors `tools/semantic-harvest/spike_gates.py` exactly, because every
        /// recall number the program has describes those steps; the document-id encoding stores
        /// identity rather than deriving it, because the design's implicit-keying rule was measured
        /// wrong for 4.8% of the corpus.
        .target(
            name: "SemanticVectorsGeneratorCore",
            dependencies: [
                .target(name: "GeneratorKit"),
                .target(name: "SemanticVectorsKit"),
                // The map's cluster labels are tokenised through the app's own stack, so a label
                // speaks the vocabulary every word-cloud surface speaks.
                .target(name: "WordCloudKit"),
            ],
            path: "SemanticVectorsGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls SemanticVectorsRunner.run() and exits.
        .executableTarget(
            name: "SemanticVectorsGenerator",
            dependencies: [.target(name: "SemanticVectorsGeneratorCore")],
            path: "SemanticVectorsGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests: the pinned quantization rules, the id run-length encoding and its round
        /// trip, binary layout round-trips, and the artifact tests that read the committed
        /// bundled artifacts.
        .testTarget(
            name: "SemanticVectorsGeneratorTests",
            dependencies: [
                .target(name: "SemanticVectorsGeneratorCore"),
                .target(name: "SemanticVectorsKit"),
            ],
            path: "SemanticVectorsGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - GeneratorKit

        /// Reusable utilities shared across the corpus-scanning generators: a deterministic
        /// `VolumeCorpusEnumerator`, a stderr logger, a reproducible `yyyy-MM-dd` date stamp, and an
        /// RFC-4180 `CSVWriter`. Factored out so every generator's output stays byte-stable.
        .target(
            name: "GeneratorKit",
            path: "GeneratorKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for GeneratorKit (CSV escaping, date stamp, enumerator sort/filter).
        .testTarget(
            name: "GeneratorKitTests",
            dependencies: [.target(name: "GeneratorKit")],
            path: "GeneratorKitTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - CrossRefValidationGenerator

        /// Validates every `<ref target>` across the local FRUS corpus (issue #240): a byte-scan
        /// xml:id inventory (Pass A), a byte-scan ref harvest capturing offset/line/enclosing
        /// document (Pass B), and classification against the shared `CrossRefKit` grammar (Pass C).
        /// Emits the OH-submittable `broken-refs-report.{csv,json}` plus the candidate bundled
        /// `broken-refs-index.json`. Entirely offline & deterministic; changes no app output.
        .target(
            name: "CrossRefValidationGeneratorCore",
            dependencies: [
                .target(name: "CrossRefKit"),
                .target(name: "GeneratorKit"),
            ],
            path: "CrossRefValidationGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls CrossRefValidationRunner.run() and exits.
        .executableTarget(
            name: "CrossRefValidationGenerator",
            dependencies: [.target(name: "CrossRefValidationGeneratorCore")],
            path: "CrossRefValidationGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for CrossRefValidationGeneratorCore (inventory extraction, ref
        /// harvest location, per-reason classification, end-to-end report/CSV/index).
        .testTarget(
            name: "CrossRefValidationGeneratorTests",
            dependencies: [.target(name: "CrossRefValidationGeneratorCore")],
            path: "CrossRefValidationGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - SourceExplorerExportGenerator

        /// The corpus-wide Source Explorer data export (#335): one record per document source
        /// note — canonical id, raw stored note (parity-pinned DocumentNoteExtractor), the
        /// parsed value handed to Source Explorer logic (shared SourceNoteParser), the strategy
        /// (ProvenanceCategory), and the dictionary of offline resolution results (bundled lot
        /// index with the #321 guard, 1906–1910 Numerical File rolls, volume-sources index,
        /// collection-authority 4-step lookup) plus the recorded — never executed — live
        /// catalog route. Entirely offline & deterministic.
        .target(
            name: "SourceExplorerExportGeneratorCore",
            dependencies: [
                .target(name: "SourceNoteKit"),
                .target(name: "GeneratorKit"),
                .target(name: "SourceProvenanceIndexGeneratorCore"),
                .target(name: "CollectionAuthorityGeneratorCore"),
                .target(name: "VolumeSourcesIndexGeneratorCore"),
                .target(name: "CentralFilesIndexGeneratorCore"),
            ],
            path: "SourceExplorerExportGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls SourceExplorerExportRunner.run() and exits.
        .executableTarget(
            name: "SourceExplorerExportGenerator",
            dependencies: [.target(name: "SourceExplorerExportGeneratorCore")],
            path: "SourceExplorerExportGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for SourceExplorerExportGeneratorCore (authority-lookup parity
        /// table, year extraction, record construction per strategy, end-to-end determinism).
        .testTarget(
            name: "SourceExplorerExportGeneratorTests",
            dependencies: [.target(name: "SourceExplorerExportGeneratorCore")],
            path: "SourceExplorerExportGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - ProvenanceFlowIndexGenerator

        /// Builds `provenance-flow-index.json` (#764) — the archival units FRUS's editors sent
        /// readers *between* when they cross-referenced one document from another, aggregated to
        /// collection-to-collection and class-to-class pairs.
        ///
        /// Reuses the validator's `RefHarvester` + `CrossRefGrammar` for the references and the
        /// export generator's parse/authority/class surfaces for each document's archival unit, so
        /// an edge here is an edge there and a unit here is a unit in collection-usage-index.json.
        /// Entirely offline & deterministic; throws rather than writing an empty index.
        .target(
            name: "ProvenanceFlowIndexGeneratorCore",
            dependencies: [
                .target(name: "SourceNoteKit"),
                .target(name: "GeneratorKit"),
                .target(name: "CrossRefKit"),
                .target(name: "CrossRefValidationGeneratorCore"),
                .target(name: "CollectionAuthorityGeneratorCore"),
                .target(name: "SourceExplorerExportGeneratorCore"),
            ],
            path: "ProvenanceFlowIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls ProvenanceFlowIndexRunner.run() and exits.
        .executableTarget(
            name: "ProvenanceFlowIndexGenerator",
            dependencies: [.target(name: "ProvenanceFlowIndexGeneratorCore")],
            path: "ProvenanceFlowIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - ResolvedEdgeIndexGenerator

        /// Builds `resolved-edge-index.json` (#262) — every CROSS-VOLUME document-to-document
        /// citation in the shippable corpus, grouped by the document cited, so inbound-citation
        /// views are complete even when the citing volume was never downloaded.
        ///
        /// Reuses the validator's RefHarvester + CrossRefGrammar and #764's DocumentIdInventory,
        /// so an edge here is an edge there. Same-volume edges are deliberately excluded: the
        /// local `cross_references` table already holds every one of them whenever the reader can
        /// see the document at all. Entirely offline & deterministic; throws rather than writing
        /// an empty index.
        .target(
            name: "ResolvedEdgeIndexGeneratorCore",
            dependencies: [
                .target(name: "GeneratorKit"),
                .target(name: "CrossRefKit"),
                .target(name: "CrossRefValidationGeneratorCore"),
                .target(name: "ProvenanceFlowIndexGeneratorCore"),
            ],
            path: "ResolvedEdgeIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls ResolvedEdgeIndexRunner.run() and exits.
        .executableTarget(
            name: "ResolvedEdgeIndexGenerator",
            dependencies: [.target(name: "ResolvedEdgeIndexGeneratorCore")],
            path: "ResolvedEdgeIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for ResolvedEdgeIndexGeneratorCore (the same-volume exclusion, the
        /// endpoint interning, determinism, and the empty-result refusal).
        .testTarget(
            name: "ResolvedEdgeIndexGeneratorTests",
            dependencies: [.target(name: "ResolvedEdgeIndexGeneratorCore")],
            path: "ResolvedEdgeIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for ProvenanceFlowIndexGeneratorCore (the document-id inventory,
        /// the edge join, the same-unit accounting, determinism, and the empty-result refusal).
        .testTarget(
            name: "ProvenanceFlowIndexGeneratorTests",
            dependencies: [.target(name: "ProvenanceFlowIndexGeneratorCore")],
            path: "ProvenanceFlowIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - CollectionUsageIndexGenerator

        /// Builds `collection-usage-index.json` (#763) — document-grain usage counts for the
        /// archival units FRUS cites: per-(authority collection, volume), per-(central-file
        /// class, volume), and per-(provenance category, volume) document counts, plus the
        /// per-volume note totals every share needs as a denominator.
        ///
        /// One pass over the shippable corpus reusing the surfaces the export generator already
        /// pins to the app (`DocumentNoteExtractor`, `SourceNoteParser`, `AuthorityLookup`,
        /// `ExportClassification.derivedKeys`, `ProvenanceCategory.from`), so the aggregate and
        /// the per-record export agree by construction. Carries no era rollups on purpose: every
        /// era view is a rollup of these per-volume counts against `manifest.json`, which the app
        /// already computes, and a second era axis here could silently disagree with the first.
        /// Entirely offline & deterministic; throws rather than writing an index of zeroes.
        .target(
            name: "CollectionUsageIndexGeneratorCore",
            dependencies: [
                .target(name: "SourceNoteKit"),
                .target(name: "GeneratorKit"),
                .target(name: "SourceProvenanceIndexGeneratorCore"),
                .target(name: "CollectionAuthorityGeneratorCore"),
                .target(name: "SourceExplorerExportGeneratorCore"),
            ],
            path: "CollectionUsageIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls CollectionUsageIndexRunner.run() and exits.
        .executableTarget(
            name: "CollectionUsageIndexGenerator",
            dependencies: [.target(name: "CollectionUsageIndexGeneratorCore")],
            path: "CollectionUsageIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for CollectionUsageIndexGeneratorCore (aggregation over a fixture
        /// corpus, the parallel-array invariant, determinism, and the broken-join refusal).
        .testTarget(
            name: "CollectionUsageIndexGeneratorTests",
            dependencies: [.target(name: "CollectionUsageIndexGeneratorCore")],
            path: "CollectionUsageIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - ExternalCitationIndexGenerator

        /// Builds `external-citation-index.json` (#784) — where FRUS's editorial *footnotes* point
        /// outside the printed record, aggregated to archival units.
        ///
        /// A third body of archival evidence, distinct from the two already indexed: a document's
        /// own source note (where the printed document came from) and a cross-reference between
        /// two printed documents. A footnote citation says *there is another document, we did not
        /// print it, and here is where it lives* — and it is the only archival signal that reaches
        /// 1910–1945, the decades #764 found structurally empty.
        ///
        /// One pass over the shippable corpus reusing the app's own surfaces
        /// (`DocumentFootnoteExtractor`, `SourceNoteKit.FootnoteCitationScanner`,
        /// `DocumentNoteExtractor`, `SourceNoteParser`, `AuthorityLookup`), so a reference here is
        /// a row in the app's `external_citations` table. Entirely offline & deterministic; throws
        /// rather than writing an index of zeroes.
        .target(
            name: "ExternalCitationIndexGeneratorCore",
            dependencies: [
                .target(name: "SourceNoteKit"),
                .target(name: "GeneratorKit"),
                .target(name: "CollectionAuthorityGeneratorCore"),
                .target(name: "SourceExplorerExportGeneratorCore"),
            ],
            path: "ExternalCitationIndexGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls ExternalCitationIndexRunner.run() and exits.
        .executableTarget(
            name: "ExternalCitationIndexGenerator",
            dependencies: [.target(name: "ExternalCitationIndexGeneratorCore")],
            path: "ExternalCitationIndexGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit + fixture tests for ExternalCitationIndexGeneratorCore (the body-footnote
        /// extraction and its exclusions, the anchor grammar, the `Ibid.` state machine, the
        /// absence guard, determinism, and the broken-join refusal).
        .testTarget(
            name: "ExternalCitationIndexGeneratorTests",
            dependencies: [.target(name: "ExternalCitationIndexGeneratorCore")],
            path: "ExternalCitationIndexGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - RecordGroupCatalogGenerator

        /// Builds the offline NARA Catalog index for the 22 foreign-affairs record groups
        /// (43, 59, 63, 76, 84, 169, 182, 208, 229, 239, 256, 268, 278, 286, 306, 353, 383,
        /// 420, 466, 469, 486, 490) — a spin-off of `CentralFilesIndexGenerator` that keeps
        /// **all** available description data rather than the handful of fields a citation
        /// lookup needs, with creator authority information and the complete unfiltered
        /// `variantControlNumbers` as its two priority payloads.
        ///
        /// Harvests NARA's **public, unauthenticated S3 bulk export** rather than the v2
        /// search API: no `CATALOG_API_KEY`, no 10,000/month quota, every level of description
        /// in one pass (so adding file units for a chosen group later is a filter change, not a
        /// second harvest), and each group's own `recordGroup` record carries NARA's
        /// `seriesCount` so a short harvest is self-detecting.
        .target(
            name: "RecordGroupCatalogGeneratorCore",
            dependencies: [.target(name: "GeneratorKit")],
            path: "RecordGroupCatalogGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls RecordGroupCatalogRunner.run() and exits.
        .executableTarget(
            name: "RecordGroupCatalogGenerator",
            dependencies: [.target(name: "RecordGroupCatalogGeneratorCore")],
            path: "RecordGroupCatalogGenerator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests for RecordGroupCatalogGeneratorCore — JSON tree coercions, NDJSON line
        /// splitting, S3 listing parse, plan/depth resolution, projection invariants, alias
        /// ledger states, the field/value/control-number censuses, checkpoint resume, and
        /// end-to-end determinism over a stubbed transport (no network).
        .testTarget(
            name: "RecordGroupCatalogGeneratorTests",
            dependencies: [.target(name: "RecordGroupCatalogGeneratorCore")],
            path: "RecordGroupCatalogGeneratorTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - EarlyEraNERControl

        /// The `NLTagger` control detector for the #234 R-1 early-era person harvest — the free
        /// baseline (measured ~8 min over the 267-volume scope) that a hosted LLM detector has to beat
        /// before it earns a sweep costing days. Reads the R-0 text layer and the `marked/` layer
        /// written by `tools/semantic-harvest/harvest_ner.py`, writes the same `detected/` shape,
        /// and is scored beside the LLM stores by `tools/semantic-harvest/score_detections.py`.
        /// Runbook: `tools/semantic-harvest/NER-RUNBOOK.md`.
        .target(
            name: "EarlyEraNERControlCore",
            dependencies: [.target(name: "GeneratorKit")],
            path: "EarlyEraNERControlCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Thin entry point — calls EarlyEraNERControlRunner.run() and exits.
        .executableTarget(
            name: "EarlyEraNERControl",
            dependencies: [.target(name: "EarlyEraNERControlCore")],
            path: "EarlyEraNERControl",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        /// Unit tests: the code-point offset arithmetic that joins this detector to a
        /// Python-produced store (tested on strings where code points, characters and UTF-16
        /// units disagree — they all agree on ASCII, which is what makes the bug invisible),
        /// the store row shapes, and a recogniser smoke test asserted only on properties that
        /// survive an OS update.
        .testTarget(
            name: "EarlyEraNERControlTests",
            dependencies: [.target(name: "EarlyEraNERControlCore")],
            path: "EarlyEraNERControlTests",
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
