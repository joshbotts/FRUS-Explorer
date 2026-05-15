// swift-tools-version: 6.0
// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import PackageDescription

/// SPM package for FRUS Explorer command-line tools.
///
/// This package is separate from `FRUSExplorer.xcodeproj` (the iOS/macOS app).
/// It defines two executable tools used in the release preparation workflow:
///
/// - **ManifestGenerator**: parses `<teiHeader>` from each FRUS volume XML file
///   hosted on the HistoryAtState GitHub repository and produces `manifest.json`,
///   which is committed into the app bundle. Implemented in Session 02.
///
/// - **TaxonomyGenerator**: fetches and parses `history.state.gov/tags/all` to
///   produce `volume-tag-taxonomy.json`, which provides humanised display names
///   and hierarchy for volume-level subject tag slugs. Implemented in Session 02.
///
/// To run a tool:
/// ```
/// swift run ManifestGenerator
/// swift run TaxonomyGenerator
/// ```
let package = Package(
    name: "FRUSExplorerTools",
    platforms: [
        .macOS(.v15)   // Updated to .v26 when Swift SDK for macOS 26 stabilises
    ],
    targets: [
        .executableTarget(
            name: "ManifestGenerator",
            path: "ManifestGenerator",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "TaxonomyGenerator",
            path: "TaxonomyGenerator",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
