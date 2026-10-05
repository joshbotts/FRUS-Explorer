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
#if canImport(UIKit)
import UIKit
#endif
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - IndexingSeamsTests

/// What the pipeline is given by its host (`IndexingSeams.swift`): the stamp store, the data files,
/// the donor and the passes after indexing.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 2: initial implementation
@Suite("FRUSCoreKit — the indexer's seams")
struct IndexingSeamsTests {

    /// A pipeline over a new database in `dir`, with no data files, its own in-memory stamps and
    /// `donor`, built through the kit's initialiser, which both compilers have.
    private func makePipeline(dir: URL, donor: (any IndexedDocumentDonor)? = nil) throws -> IndexingPipeline {
        let database = dir.appendingPathComponent("seams.sqlite")
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        return try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                                    volumesDirectory: volumes, resources: .none,
                                    defaults: InMemoryIndexingStampStore(), donor: donor)
    }

    /// A temporary directory for `body`, removed after it.
    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSeams-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// Writes a volume of `count` documents, `d1` to `d<count>`, to the pipeline's volumes folder.
    private func writeVolume(_ volumeId: String, documents count: Int, in dir: URL) throws {
        let documents = (1...count).map { n in
            "<div type=\"document\" xml:id=\"d\(n)\" n=\"\(n)\"><head>\(n). Telegram</head><p>Text \(n).</p></div>"
        }.joined(separator: "\n")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
              <publicationStmt><date>1970</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body><div type="compilation" xml:id="comp1">\(documents)</div></body></text>
            </TEI>
            """
        try Data(xml.utf8).write(to: dir.appendingPathComponent("volumes/\(volumeId).xml"))
    }

    @Test("The in-memory stamp store answers as UserDefaults does for the values the pipeline stores")
    func inMemoryStampsAnswerAsUserDefaults() {
        let store = InMemoryIndexingStampStore()
        #expect(store.integer(forKey: "absent") == 0)
        #expect(store.string(forKey: "absent") == nil)
        #expect(store.data(forKey: "absent") == nil)
        store.set(65, forKey: "version")
        #expect(store.integer(forKey: "version") == 65)
        #expect(store.string(forKey: "version") == "65")
        store.set("2026-09-09", forKey: "applied")
        #expect(store.string(forKey: "applied") == "2026-09-09")
        #expect(store.integer(forKey: "applied") == 0)
        store.set("12", forKey: "numeric")
        #expect(store.integer(forKey: "numeric") == 12)
        store.set(Data([1, 2]), forKey: "data")
        #expect(store.data(forKey: "data") == Data([1, 2]))
        store.set(nil, forKey: "version")
        #expect(store.integer(forKey: "version") == 0)
        store.removeObject(forKey: "applied")
        #expect(store.string(forKey: "applied") == nil)
    }

    @Test("A folder that lacks one of the four index files is refused, and each lacking file is named")
    func loadingRefusesAnIncompleteFolder() async throws {
        try await withTempDir { dir in
            try Data("{}".utf8).write(to: dir.appendingPathComponent("broken-refs-index.json"))
            #expect(throws: IndexingResources.LoadError.missing(
                directory: dir.path,
                names: ["person-authority-index", "document-subject-index", "decimal-class-labels"])) {
                try IndexingResources.loading(fromDirectory: dir)
            }
        }
    }

    @Test("A data file is decoded once, on first use, and one that will not decode answers nil")
    func aResourceIsDecodedOnceOnFirstUse() async throws {
        try await withTempDir { dir in
            let url = dir.appendingPathComponent("broken-refs-index.json")
            try Data("not json".utf8).write(to: url)
            let resource = LazyResource<BrokenRefsIndex>(dir, "broken-refs-index")
            #expect(resource.value() == nil)
            // Replacing the file with a valid one does not matter after the first use: the answer
            // is kept. A new resource over the same file decodes it.
            try Data(#"{"schemaVersion": 1, "generated": "2026-10-04", "totalBroken": 0, "fullDetail": false, "records": []}"#.utf8)
                .write(to: url)
            #expect(resource.value() == nil)
            #expect(LazyResource<BrokenRefsIndex>(dir, "broken-refs-index").value()?.generated == "2026-10-04")
        }
    }

    @Test("runPostIndexPasses reports a rebuilt rollup, and calls back only then")
    func postIndexPassesReportTheRollup() async throws {
        try await withTempDir { dir in
            let pipeline = try makePipeline(dir: dir)
            let calls = CallCount()
            // A new stamp store holds no rollup version, so the first run rebuilds.
            #expect(await pipeline.runPostIndexPasses { await calls.increment() } == true)
            #expect(await calls.value == 1)
            // Nothing changed since, so the second run rebuilds nothing and does not call back.
            #expect(await pipeline.runPostIndexPasses { await calls.increment() } == false)
            #expect(await calls.value == 1)
        }
    }

    @Test("The indexed documents are read for a donor page by page, in rowid order")
    func donatedDocumentsPageThroughTheCache() async throws {
        try await withTempDir { dir in
            let pipeline = try makePipeline(dir: dir)
            try writeVolume("frus1970v01", documents: 3, in: dir)
            try await pipeline.indexVolume("frus1970v01")
            let first = try await pipeline.donatedDocuments(afterRowId: 0, limit: 2)
            #expect(first.documents.map(\.documentId) == ["d1", "d2"])
            #expect(first.documents.allSatisfy { $0.volumeId == "frus1970v01" })
            let second = try await pipeline.donatedDocuments(afterRowId: first.lastRowId, limit: 2)
            #expect(second.documents.map(\.documentId) == ["d3"])
            let third = try await pipeline.donatedDocuments(afterRowId: second.lastRowId, limit: 2)
            #expect(third.documents.isEmpty)
            #expect(third.lastRowId == second.lastRowId)
        }
    }

    @Test("A donor is offered a volume's documents when it is indexed, and asked to withdraw them when it is removed")
    func aDonorHearsOfEachVolume() async throws {
        try await withTempDir { dir in
            let donor = RecordingDonor()
            let pipeline = try makePipeline(dir: dir, donor: donor)
            try writeVolume("frus1970v02", documents: 2, in: dir)
            try await pipeline.indexVolume("frus1970v02")
            #expect(donor.donated == ["frus1970v02": ["d1", "d2"]])
            try await pipeline.removeVolume("frus1970v02")
            #expect(await donor.withdrawn() == ["frus1970v02"])
        }
    }

    #if !SWIFT_PACKAGE // UIKit's notification name and the app's bundled stores are the app's
    #if canImport(UIKit)
    @Test("The memory-warning observer listens for UIKit's notification by its name")
    func memoryWarningNameIsUIKits() {
        #expect(UIApplication.didReceiveMemoryWarningNotification.rawValue
                == "UIApplicationDidReceiveMemoryWarningNotification")
    }
    #endif

    @Test("The app's data files reach the pipeline through its existing stores")
    func bundledResourcesAreTheAppsStores() {
        let resources = IndexingResources.bundled
        #expect(resources.personAuthority()?.generated == PersonAuthorityIndexStore.shared?.generated)
        #expect(resources.personAuthority() != nil)
        #expect(resources.documentSubjects()?.bucketVocabulary.digest
                == DocumentSubjectStore.shared?.bucketVocabulary.digest)
        #expect(resources.documentSubjects() != nil)
        #expect((resources.decimalClassLabels() != nil) == (DecimalClassLabelStore.shared != nil))
        #expect(resources.brokenRefs()?.generated == BrokenRefsIndexStore.shared?.generated)
        #expect(resources.brokenRefs() != nil)
    }
    #endif
}

/// Counts the calls of a callback across actors.
private actor CallCount {
    /// The calls so far.
    private(set) var value = 0
    /// Records a call.
    func increment() { value += 1 }
}

/// Records what the pipeline offers and withdraws.
private final class RecordingDonor: IndexedDocumentDonor, @unchecked Sendable {
    /// Guards the two records.
    private let lock = NSLock()
    /// The document ids offered, by volume.
    private var offered: [String: [String]] = [:]
    /// The volumes withdrawn, in order.
    private var removed: [String] = []

    /// The document ids offered so far, by volume.
    var donated: [String: [String]] {
        lock.lock()
        defer { lock.unlock() }
        return offered
    }

    /// The volumes withdrawn so far.
    func withdrawn() async -> [String] {
        lock.withLock { removed }
    }

    func donate(volumeId: String, documents: [DonatedDocument]) {
        lock.lock()
        defer { lock.unlock() }
        offered[volumeId, default: []] += documents.map(\.documentId)
    }

    func withdraw(volumeId: String) async {
        lock.withLock { removed.append(volumeId) }
    }
}
