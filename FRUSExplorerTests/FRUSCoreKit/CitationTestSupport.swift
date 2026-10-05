// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - What the app's test host gives a citation lookup, for the package

// In Xcode the suites run inside the app: the bundled manifest is in `Bundle.main`, and a test
// engine's catalogue is a `ManifestStore` over the entries the test names, as the app's is over the
// bundled ones. The package has neither, so it reads the same manifest from the repository and
// gives the engine a `FixedVolumeCatalogue`. The suites then build engines with the same calls
// under both compilers.

/// The app's bundled `manifest.json`: in the test host's bundle in Xcode, and in the repository's
/// `FRUSExplorer/Resources` in the package.
func testManifestURL() throws -> URL {
    #if SWIFT_PACKAGE
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources/manifest.json")
    #else
    try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
    #endif
}

/// Every entry of the app's bundled manifest, decoded as `ManifestStore` decodes it.
func testManifestEntries() throws -> [VolumeManifestEntry] {
    try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: testManifestURL()))
}

/// A catalogue of exactly `entries` for a test engine: a `ManifestStore` in Xcode, the app's own
/// catalogue type, and a `FixedVolumeCatalogue` in the package.
@MainActor
func makeTestCatalogue(_ entries: [VolumeManifestEntry]) -> any CitableVolumeCatalogue {
    #if SWIFT_PACKAGE
    FixedVolumeCatalogue(entries: entries)
    #else
    ManifestStore(bundledEntries: entries)
    #endif
}
