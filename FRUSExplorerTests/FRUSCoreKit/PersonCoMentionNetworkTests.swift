// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
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

// MARK: - PersonCoMentionNetworkTests

/// The co-mention ego network's choice of nodes and edges, as a host makes it: `PersonCoMentionNetwork`
/// over a real `PersonMentionStore`, in both builds, so Linux runs it. The view model's own suites
/// (`PersonCoMentionHoverSelectionTests`, `PersonNetworkFocusTests`) drive the same choice through
/// `load(from:volumeIds:)` in Xcode; the last test here holds the view model's load to the kit's.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): initial implementation, when the choice moved out of
///          `PersonCoMentionGraphViewModel` into the kit
struct PersonCoMentionNetworkTests {

    /// A fixture that could not be built.
    private struct FixtureError: Error {
        let message: String
    }

    /// A store whose `person_mentions` are `mentions`, each `(document, rollup)` in volume `v1`, with
    /// one rollup per id named `Person NN` (or as `names` gives), as the app's index stores them.
    private static func makeStore(
        mentions: [(document: String, rollup: Int)],
        names: [Int: String] = [:]
    ) throws -> (dir: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCoMentionNetwork-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw FixtureError(message: "cannot open the fixture database")
        }
        defer { sqlite3_close_v2(db) }
        var statements: [String] = []
        for rollup in Set(mentions.map(\.rollup)).sorted() {
            let name = names[rollup] ?? String(format: "Person %02d", rollup)
            statements.append("INSERT INTO person_rollup (rollup_id, namekey, canonical_name, mention_count) VALUES (\(rollup), '\(name.lowercased())', '\(name)', 1)")
            statements.append("INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES ('v1', 'p_\(rollup)', \(rollup))")
        }
        for mention in mentions {
            statements.append("INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES ('v1', '\(mention.document)', 'p_\(mention.rollup)')")
        }
        for sql in statements {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw FixtureError(message: String(cString: sqlite3_errmsg(db)))
            }
        }
        return (dir, try PersonMentionStore(databaseURL: dbURL))
    }

    /// One document mentioning the focus (rollup 1) and `partners` others (2…).
    private static func oneDocument(partners: Int) -> [(document: String, rollup: Int)] {
        (1...(partners + 1)).map { (document: "d1", rollup: $0) }
    }

    @Test("The nodes are the focus, sharing nothing, then its partners in the store's order, with the probe's count")
    func nodesAreTheFocusThenItsPartners() async throws {
        // Rollup 3 shares two documents with the focus, 2 and 4 one each.
        let (dir, store) = try Self.makeStore(mentions: [
            ("d1", 1), ("d1", 2), ("d1", 3), ("d1", 4), ("d2", 1), ("d2", 3),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let ego = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                         store: store, volumeIds: nil)
        #expect(ego.nodes.first == PersonCoMentionNode(rollupId: 1, name: "Focus", sharedWithFocus: 0))
        #expect(ego.nodes.dropFirst().map(\.rollupId) == [3, 2, 4])
        #expect(ego.nodes.dropFirst().map(\.sharedWithFocus) == [2, 1, 1])
        #expect(ego.nodes.dropFirst().map(\.name) == ["Person 03", "Person 02", "Person 04"])
        #expect(ego.totalPartnerCount == 3)
        let partners = PersonCoMentionNetwork.partners(of: ego.nodes, focusRollupId: 1)
        #expect(partners.map(\.rollupId) == [3, 2, 4], "most-shared first, then by name")
        #expect(!PersonCoMentionNetwork.capApplied(partnerCount: partners.count,
                                                   totalPartnerCount: ego.totalPartnerCount))
    }

    @Test("Past the cap the nodes stop at partnerLimit, and the probe says only that there are more")
    func theCapIsDisclosedAsALowerBound() async throws {
        let (dir, store) = try Self.makeStore(mentions: Self.oneDocument(partners: 30))
        defer { try? FileManager.default.removeItem(at: dir) }
        let ego = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                         store: store, volumeIds: nil)
        #expect(PersonCoMentionNetwork.partnerLimit == 24)
        #expect(ego.nodes.count == PersonCoMentionNetwork.partnerLimit + 1)
        #expect(ego.totalPartnerCount == PersonCoMentionNetwork.partnerLimit + 1)
        let partners = PersonCoMentionNetwork.partners(of: ego.nodes, focusRollupId: 1)
        #expect(PersonCoMentionNetwork.capApplied(partnerCount: partners.count, totalPartnerCount: ego.totalPartnerCount))
        #expect(PersonCoMentionNetwork.capDisclosure(partnerCount: partners.count, totalPartnerCount: ego.totalPartnerCount)
                == "Showing the top 24 co-mentioned people (of 25+) by shared-document count.")
    }

    @Test("The edges join the ego's people alone, weighted by the documents each pair shares")
    func edgesJoinTheEgoAlone() async throws {
        // Rollup 5 is never in a document with the focus, so it is no partner, and its document with
        // rollup 2 gives no edge.
        let (dir, store) = try Self.makeStore(mentions: [
            ("d1", 1), ("d1", 2), ("d1", 3), ("d2", 1), ("d2", 2), ("d3", 2), ("d3", 5),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let ego = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                         store: store, volumeIds: nil)
        #expect(Set(ego.nodes.map(\.rollupId)) == [1, 2, 3])
        let edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: nil)
        let weights = Dictionary(edges.map { ([min($0.a, $0.b), max($0.a, $0.b)], $0.sharedDocuments) },
                                 uniquingKeysWith: +)
        #expect(edges.count == 3, "each pair once")
        #expect(weights == [[1, 2]: 2, [1, 3]: 1, [2, 3]: 1])
    }

    @Test("A volume scope narrows the partners and the edges to the scope's documents")
    func aScopeNarrowsBoth() async throws {
        let (dir, store) = try Self.makeStore(mentions: Self.oneDocument(partners: 2))
        defer { try? FileManager.default.removeItem(at: dir) }
        let none = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                          store: store, volumeIds: ["v2"])
        #expect(none.nodes.map(\.rollupId) == [1])
        #expect(none.totalPartnerCount == 0)
        #expect(try await PersonCoMentionNetwork.edges(among: none.nodes, store: store, volumeIds: ["v2"]).isEmpty)
        let all = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                         store: store, volumeIds: ["v1"])
        #expect(all.nodes.map(\.rollupId) == [1, 2, 3])
    }

    #if !SWIFT_PACKAGE // the view model is the app's
    @Test("The view model's load holds the kit's nodes and edges")
    @MainActor
    func theViewModelLoadsTheKitsChoice() async throws {
        let (dir, store) = try Self.makeStore(mentions: [
            ("d1", 1), ("d1", 2), ("d1", 3), ("d1", 4), ("d2", 1), ("d2", 3), ("d2", 4),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        await vm.load(from: store)
        let ego = try await PersonCoMentionNetwork.nodes(focusRollupId: 1, focusName: "Focus",
                                                         store: store, volumeIds: nil)
        let edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: nil)
        #expect(vm.error == nil)
        #expect(vm.nodes == ego.nodes)
        #expect(vm.edges == edges)
        #expect(vm.totalPartnerCount == ego.totalPartnerCount)
        #expect(vm.partners == PersonCoMentionNetwork.partners(of: ego.nodes, focusRollupId: 1))
        #expect(PersonCoMentionGraphViewModel.partnerLimit == PersonCoMentionNetwork.partnerLimit)
    }
    #endif
}
