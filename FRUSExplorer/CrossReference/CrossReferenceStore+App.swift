// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CrossReferenceStore (the app's)

/// The app's half of ``CrossReferenceStore``, whose queries are FRUSCoreKit's
/// (`FRUSCoreKit/CrossReference/CrossReferenceStore.swift`): the initialiser every app call site
/// uses, which gives the store the two bundled files it reads.
///
/// Version history:
///   1.0 — 2026-11-10: FRUS Explorer Light's S23b — the store moved into FRUSCoreKit, which never
///          reads the bundle, and this is the initialiser it had, unchanged for its callers
///          (`AppState`, `FRUSExplorerApp` and the tests)
extension CrossReferenceStore {

    /// Opens a read-only connection to `databaseURL` with the bundled corpus-wide citation index
    /// (`ResolvedEdgeIndexStore.shared`) and the bundled page map (`CitedPageMapStore.shared`).
    ///
    /// Neither file is read here. The store reads each through its provider where it read the store
    /// before: the citation index each time a graph is built, the page map each time it dates a node
    /// the device holds no row for. So the citation index, which only the store reads, is still
    /// decoded on first use, on the store's actor, and the page map where the app first reads it.
    ///
    /// - Parameters:
    ///   - databaseURL: The search index's database.
    ///   - volumes: The bundled catalogue (`ManifestStore.bundledEntries`), from which a graph node
    ///     the device holds no row for takes its volume's span and a page node its title (#1799).
    /// - Throws: `CrossReferenceError.databaseOpenFailed` if SQLite cannot open the file.
    init(databaseURL: URL, volumes: [VolumeManifestEntry] = []) throws {
        try self.init(databaseURL: databaseURL, volumes: volumes,
                      resolvedEdgeIndexProvider: { ResolvedEdgeIndexStore.shared },
                      citedPageMapProvider: { CitedPageMapStore.shared })
    }
}
