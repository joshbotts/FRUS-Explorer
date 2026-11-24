// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit as a module of its own; Xcode compiles it into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

// MARK: - SemanticMapFixture

/// The bundled files the map's suites read, loaded through the kits by URL in both builds.
///
/// The repository's `FRUSExplorer/Resources` in the package, where `Bundle.main` is the test runner;
/// the app's bundle in Xcode. Loading through the kit's `SemanticBundledMap` rather than the app's
/// `BundledSemanticMap` keeps a suite off the app's shared static state, which one of its own tests
/// resets (S26a's lesson with `BundledSemanticVectors`), and is the load a host makes.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — the map's suites moved into the kit's
enum SemanticMapFixture {

    /// The bundled map with the vectors it is held to.
    struct Loaded {
        /// The bundled vectors' index, which keys every row.
        let index: SemanticVectorIndex
        /// The bundled corpus tier: the sign bits and the centroids.
        let corpus: SemanticCorpusVectors
        /// The map's index: its regions and its layout.
        let mapIndex: SemanticMapArtifacts.MapIndex
        /// The mapped placements.
        let map: SemanticMapVectors
    }

    /// A bundled file's address.
    ///
    /// - Parameters:
    ///   - name: The resource's name.
    ///   - ext: Its extension.
    /// - Returns: Its URL.
    static func resource(_ name: String, _ ext: String) throws -> URL {
        #if SWIFT_PACKAGE
        // `FRUSExplorer/Resources`, from this file's place in the repository.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/\(name).\(ext)")
        try #require(FileManager.default.fileExists(atPath: url.path), "\(name).\(ext) is not in Resources")
        return url
        #else
        return try #require(Bundle.main.url(forResource: name, withExtension: ext))
        #endif
    }

    /// The bundled map and its vectors, through the kit's loaders.
    static func load() throws -> Loaded {
        let tiers = try BundledTiersFixture.tiers()
        let bundled = try SemanticBundledMap(
            indexAt: resource("semantic-map-index", "json"),
            binaryAt: resource("semantic-map", "bin"),
            vectorIndex: tiers.index)
        return Loaded(index: tiers.index, corpus: tiers.corpus, mapIndex: bundled.index, map: bundled.vectors)
    }

    /// The bundled source-provenance aggregate's per-volume table, as the app's store decodes it.
    static func provenanceByVolume() throws -> [VolumeProvenance] {
        let index = try SourceProvenanceIndex(contentsOf: resource("source-provenance-index", "json"))
        return try #require(index.byVolume, "the bundled aggregate has no per-volume table")
    }
}
