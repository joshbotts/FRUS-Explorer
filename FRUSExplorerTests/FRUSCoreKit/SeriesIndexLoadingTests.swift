// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SeriesIndexLoadingTests

/// About the Series' two bundled aggregates, loaded by URL as a host loads them:
/// `SourceProvenanceIndex(contentsOf:)` and `AdministrationProfilesIndex(contentsOf:)` give what the
/// app's stores decode from the bundle (in Xcode, the stores themselves; in the package, a plain
/// decode of the same file), and throw where the stores answer `nil`.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): initial implementation, when the two aggregates'
///          types moved into the kit with their loaders
struct SeriesIndexLoadingTests {

    /// `value` encoded with sorted keys, so two decodes of one file compare byte for byte.
    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    /// A directory of its own for a test's files.
    private static func scratch() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSeriesIndexLoading-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("The source-provenance aggregate loads by URL as the app's store decodes it")
    @MainActor
    func sourceProvenanceLoadsAsTheStoreDoes() throws {
        let url = try #require(appBundledURL(forResource: "source-provenance-index", withExtension: "json"))
        let loaded = try SourceProvenanceIndex(contentsOf: url)
        #if SWIFT_PACKAGE
        let expected = try JSONDecoder().decode(SourceProvenanceIndex.self, from: Data(contentsOf: url))
        #else
        let expected = try #require(SourceProvenanceStore().index, "the app's store decodes the bundled copy")
        #endif
        #expect(try Self.encoded(loaded) == Self.encoded(expected))
        #expect(loaded.volumesCovered == expected.volumesCovered)
        #expect(loaded.byVolume?.count == loaded.volumesCovered)
    }

    @Test("The administration-profiles aggregate loads by URL as the app's store decodes it")
    @MainActor
    func administrationProfilesLoadAsTheStoreDoes() throws {
        let url = try #require(appBundledURL(forResource: "administration-profiles-index", withExtension: "json"))
        let loaded = try AdministrationProfilesIndex(contentsOf: url)
        #if SWIFT_PACKAGE
        let expected = try JSONDecoder().decode(AdministrationProfilesIndex.self, from: Data(contentsOf: url))
        #else
        let expected = try #require(AdministrationProfilesStore().index, "the app's store decodes the bundled copy")
        #endif
        #expect(try Self.encoded(loaded) == Self.encoded(expected))
        #expect(!loaded.administrations.isEmpty)
        #expect(loaded.volumeTotals.count >= loaded.volumesCovered)
    }

    @Test("A missing or malformed file throws, where the app's stores answer nil")
    func aMissingOrMalformedFileThrows() throws {
        let dir = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = dir.appendingPathComponent("absent.json")
        #expect(throws: (any Error).self) { try SourceProvenanceIndex(contentsOf: missing) }
        #expect(throws: (any Error).self) { try AdministrationProfilesIndex(contentsOf: missing) }
        let malformed = dir.appendingPathComponent("malformed.json")
        try Data("not json".utf8).write(to: malformed)
        #expect(throws: (any Error).self) { try SourceProvenanceIndex(contentsOf: malformed) }
        #expect(throws: (any Error).self) { try AdministrationProfilesIndex(contentsOf: malformed) }
    }

    @Test("An administration-profiles file missing its keys loads empty, as the store's tolerant decode does")
    func aKeylessAdministrationFileLoadsEmpty() throws {
        let dir = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("empty.json")
        try Data("{}".utf8).write(to: url)
        let index = try AdministrationProfilesIndex(contentsOf: url)
        #expect(index.administrations.isEmpty)
        #expect(index.volumeTotals.isEmpty)
        #expect(index.schemaVersion == 0)
    }
}
