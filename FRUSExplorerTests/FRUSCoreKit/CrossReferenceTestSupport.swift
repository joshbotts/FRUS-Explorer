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

// MARK: - What the app's test host gives a cross-reference store, for the package

// In Xcode the suites run inside the app: a store opened with the app's initialiser
// (`CrossReferenceStore+App.swift`) reads the bundled citation index and page map through their stores,
// and the catalogue is `ManifestStore`'s. The package has neither the app nor its bundle, so it declares
// the two stores the suites read, each decoding the repository's copy of its file, as the app's decodes
// the bundle's, and the app's initialiser over them. The suites then open stores with the same calls
// under both compilers, over the same bytes.
//
// Version history:
//   1.0 — 2026-11-10 (FRUS Explorer Light, S23b): initial implementation, for the suites that moved into
//         FRUSCoreKit with the cross-reference store

/// The bundled catalogue's entries, as the app gives them to a store: `ManifestStore`'s in Xcode, the
/// repository's `manifest.json` in the package (`testManifestEntries()`).
@MainActor
func crossReferenceTestCatalogue() throws -> [VolumeManifestEntry] {
    #if SWIFT_PACKAGE
    try testManifestEntries()
    #else
    ManifestStore().bundledEntries
    #endif
}

#if SWIFT_PACKAGE
/// The repository's copy of a JSON file bundled with the app.
private func crossReferenceResource(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources/\(name).json")
}

/// The app's `ResolvedEdgeIndexStore`: `resolved-edge-index.json`, through the kit's loader.
enum ResolvedEdgeIndexStore {
    static let shared = try? ResolvedEdgeIndex(contentsOf: crossReferenceResource("resolved-edge-index"))
}

/// The app's `CitedPageMapStore`: `cited-page-map.json`, decoded as the app's store decodes it.
enum CitedPageMapStore {
    static let shared = try? JSONDecoder().decode(CitedPageMap.self,
                                                  from: Data(contentsOf: crossReferenceResource("cited-page-map")))
}

extension CrossReferenceStore {

    /// The app's initialiser, as the package's suites need it: the two bundled files from the
    /// repository, read where the store reads them.
    init(databaseURL: URL, volumes: [VolumeManifestEntry] = []) throws {
        try self.init(databaseURL: databaseURL, volumes: volumes,
                      resolvedEdgeIndexProvider: { ResolvedEdgeIndexStore.shared },
                      citedPageMapProvider: { CitedPageMapStore.shared })
    }
}
#endif
