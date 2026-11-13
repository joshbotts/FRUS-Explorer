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
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - What the app's test host gives a pipeline, for the package

// In Xcode the suites run inside the app, so a test pipeline built with the app's initialiser
// (`IndexingPipeline+App.swift`) reads the app's bundled data files and keeps its stamps in
// `UserDefaults.standard`. The package has neither, so it gets the same data files from the
// repository and one stamp store that every pipeline in the run shares, as they share `.standard`.
// The suites then build pipelines with the same calls under both compilers.

#if SWIFT_PACKAGE
/// The app's bundled data files, read from the repository's `FRUSExplorer/Resources` and decoded
/// once per run, as the test host's bundle supplies them in Xcode.
let testIndexingResources: IndexingResources = {
    let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources")
    do {
        return try IndexingResources.loading(fromDirectory: resources)
    } catch {
        fatalError("the suites read the app's data files from the repository: \(error)")
    }
}()

/// The stamps of every pipeline the package's suites build without a store of their own, shared
/// as `UserDefaults.standard` is in Xcode. Parallel tests write it (`consolidatePersonRollup` stamps
/// the rollup), so a test whose result depends on a stamp builds its pipeline over a store of its own
/// (`makeIsolatedStamps(_:)`) instead.
let testIndexingStamps = InMemoryIndexingStampStore()

extension IndexingPipeline {

    /// The app's initialiser, as the package's suites need it: the repository's data files, and
    /// the run's shared stamps unless the test passes a store.
    init(
        fts5Store: FTS5Store,
        databaseURL: URL,
        volumesDirectory: URL,
        stateTracker: IndexingStateTracker? = nil,
        concurrencyLimit: Int = 4,
        defaults: (any IndexingStampStore)? = nil
    ) throws {
        try self.init(fts5Store: fts5Store, databaseURL: databaseURL, volumesDirectory: volumesDirectory,
                      resources: testIndexingResources, stateTracker: stateTracker,
                      concurrencyLimit: concurrencyLimit, defaults: defaults ?? testIndexingStamps)
    }
}
#endif

/// A stamp store of a test's own, so a test's stamps meet no other test's: a fresh `UserDefaults`
/// suite in Xcode, removed by `removeIsolatedStamps(_:)`, and a fresh in-memory store in the package.
/// `makeTestPipeline(dir:volumesDir:isolatedStamps:)` builds a pipeline over one. A test pipeline
/// built without one shares the run's store (`testIndexingStamps` in the package, and in Xcode
/// `UserDefaults.standard`, the default of the app's initialiser), which parallel tests write.
func makeIsolatedStamps(_ suite: String) -> any IndexingStampStore {
    #if SWIFT_PACKAGE
    InMemoryIndexingStampStore()
    #else
    UserDefaults(suiteName: suite)!
    #endif
}

/// Removes what `makeIsolatedStamps(_:)` made for `suite`: the `UserDefaults` suite in Xcode;
/// nothing in the package, whose store goes with the test.
func removeIsolatedStamps(_ suite: String) {
    #if !SWIFT_PACKAGE
    UserDefaults.standard.removePersistentDomain(forName: suite)
    #endif
}
