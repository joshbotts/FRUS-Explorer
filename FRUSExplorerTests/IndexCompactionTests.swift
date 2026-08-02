// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - IndexPageStatisticsTests

/// The live-versus-reclaimable split of the index file.
///
/// SQLite never returns deleted pages to the filesystem — they go on a freelist and wait to be
/// reused — so the file size the storage hub reports is not the size of the data. Measured on the
/// author's 552-volume store: **6.29 GiB on disk, 2.75 GiB live, 3.53 GiB (56.2%) reclaimable**,
/// almost all of it left by reindexing, which deletes and reinserts every row and never compacts.
///
/// Version history:
///   1.0 — build 37: initial implementation
@Suite("Index page statistics")
struct IndexPageStatisticsTests {

    private let gib = 1024 * 1024 * 1024

    /// The real store, to scale.
    @Test("The split adds up")
    func splitAddsUp() {
        let stats = IndexPageStatistics(fileBytes: 6_752_000_000, reclaimableBytes: 3_795_000_000)
        #expect(stats.liveBytes == 6_752_000_000 - 3_795_000_000)
        #expect(stats.liveBytes + stats.reclaimableBytes == stats.fileBytes)
        #expect(abs(stats.reclaimableFraction - 0.562) < 0.005)
    }

    /// A freelist larger than the file, or a negative one, is nonsense a pragma read should never
    /// produce — but it would render as a negative "live" size, which is worse than clamping.
    @Test("Impossible inputs clamp instead of producing a negative live size")
    func clamping() {
        let over = IndexPageStatistics(fileBytes: 100, reclaimableBytes: 500)
        #expect(over.reclaimableBytes == 100)
        #expect(over.liveBytes == 0)

        let negative = IndexPageStatistics(fileBytes: 100, reclaimableBytes: -20)
        #expect(negative.reclaimableBytes == 0)
        #expect(negative.liveBytes == 100)
    }

    @Test("An empty file reports no reclaimable fraction rather than dividing by zero")
    func emptyFile() {
        let empty = IndexPageStatistics(fileBytes: 0, reclaimableBytes: 0)
        #expect(empty.reclaimableFraction == 0)
        #expect(empty.liveBytes == 0)
    }
}

// MARK: - IndexCompactionTests

/// Whether to offer compaction — the decision, in the one place both platforms read it from.
@Suite("Index compaction")
struct IndexCompactionTests {

    private let gib = 1024 * 1024 * 1024
    private let mib = 1024 * 1024

    /// The author's store: 2.75 GiB live, 3.53 GiB reclaimable, plenty of disk.
    private var realStore: IndexPageStatistics {
        IndexPageStatistics(fileBytes: 6_752_000_000, reclaimableBytes: 3_795_000_000)
    }

    // MARK: - The three outcomes

    @Test("A store with room to spare is offered compaction")
    func offered() {
        let result = IndexCompaction.availability(statistics: realStore, availableBytes: 20 * gib)
        guard case .available(let reclaimable, let fraction) = result else {
            Issue.record("expected .available, got \(result)"); return
        }
        #expect(reclaimable == 3_795_000_000)
        #expect(abs(fraction - 0.562) < 0.005)
    }

    /// The interesting decline. A user whose index is half wasted space should be *told* that, and
    /// told what would let them fix it — showing nothing would hide the most useful number.
    @Test("Too little free disk declines, but still states the figure")
    func insufficientSpace() {
        let result = IndexCompaction.availability(statistics: realStore, availableBytes: 1 * gib)
        guard case .insufficientSpace(let reclaimable, let required, let available) = result else {
            Issue.record("expected .insufficientSpace, got \(result)"); return
        }
        #expect(reclaimable == 3_795_000_000)
        #expect(available == 1 * gib)
        // VACUUM writes a full copy before swapping, so it needs the LIVE size plus headroom.
        #expect(required > realStore.liveBytes)
        #expect(required < realStore.fileBytes, "it needs the live size, not the file size")

        let text = IndexCompaction.subtitle(for: result)
        #expect(text != nil, "a decline for want of space must still say what could be reclaimed")
    }

    /// An ordinary freelist is normal SQLite behaviour, not a problem. An offer that is always
    /// present teaches the reader to ignore it.
    @Test("A small freelist is not worth offering")
    func notWorthwhile() {
        let tidy = IndexPageStatistics(fileBytes: 6 * gib, reclaimableBytes: 50 * mib)
        #expect(IndexCompaction.availability(statistics: tidy, availableBytes: 100 * gib)
                == .notWorthwhile)
        #expect(IndexCompaction.subtitle(for: .notWorthwhile) == nil,
                "nothing to say means render nothing")
    }

    // MARK: - Declining rather than guessing

    /// Both inputs can genuinely be unavailable — the pragmas can fail, and the capacity key is
    /// documented as optional. An offer that fails part-way through a multi-gigabyte rewrite is a
    /// much worse outcome than an offer that never appeared.
    @Test("Unknown inputs decline rather than assume")
    func unknownInputs() {
        #expect(IndexCompaction.availability(statistics: nil, availableBytes: 100 * gib)
                == .notWorthwhile)

        let result = IndexCompaction.availability(statistics: realStore, availableBytes: nil)
        guard case .insufficientSpace(_, _, let available) = result else {
            Issue.record("unknown free space must decline, got \(result)"); return
        }
        #expect(available == 0)
    }

    /// The boundary, from both sides — a threshold tested only from the far side is a threshold
    /// that could be anywhere.
    @Test("The worthwhile threshold is a real boundary")
    func threshold() {
        let justUnder = IndexPageStatistics(
            fileBytes: 10 * gib, reclaimableBytes: IndexCompaction.minimumWorthwhileBytes - 1)
        let justOver = IndexPageStatistics(
            fileBytes: 10 * gib, reclaimableBytes: IndexCompaction.minimumWorthwhileBytes)
        #expect(IndexCompaction.availability(statistics: justUnder, availableBytes: 100 * gib)
                == .notWorthwhile)
        if case .notWorthwhile = IndexCompaction.availability(statistics: justOver,
                                                             availableBytes: 100 * gib) {
            Issue.record("exactly the threshold must be offered")
        }
    }

    /// The free-space rule is about the LIVE size, not the file size — the copy VACUUM writes is
    /// the packed one. Requiring the file size would decline in exactly the case the feature
    /// exists for: a mostly-empty file.
    @Test("The space requirement scales with live data, not file size")
    func requirementUsesLiveSize() {
        // Same live data, wildly different files.
        let bloated = IndexPageStatistics(fileBytes: 10 * gib, reclaimableBytes: 8 * gib)
        let tight = IndexPageStatistics(fileBytes: 2 * gib + 300 * mib, reclaimableBytes: 300 * mib)
        #expect(bloated.liveBytes == tight.liveBytes)

        // 3 GiB free is more than the 2 GiB live size plus margin: both must be offered.
        for stats in [bloated, tight] {
            if case .insufficientSpace = IndexCompaction.availability(statistics: stats,
                                                                      availableBytes: 3 * gib) {
                Issue.record("declined with room for the live data: \(stats)")
            }
        }
    }
}

// MARK: - CompactionParityTests

/// Both storage hubs must offer this, and must clean up after it identically.
///
/// This app has shipped a control to one platform and not the other before — #617 hid a collection
/// toggle from every Mac user, and it took the owner going looking for it to find out. The two
/// hubs are separate files with no shared view, so nothing but an audit can see the divergence.
@Suite("Compaction parity")
struct CompactionParityTests {

    private static let hubs = [
        "FRUSExplorer/Settings/VolumesStorageHubView.swift",
        "FRUSExplorer/Settings/MacVolumesStorageHub.swift",
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    @Test("Both hubs offer compaction, from the shared decision")
    func bothHubsOffer() throws {
        for path in Self.hubs {
            let hub = try Self.source(path)
            #expect(hub.contains("IndexCompaction.availability"),
                    "\(path) must decide through the shared rule, not its own inline test")
            #expect(hub.contains("compactionRow"), "\(path) never renders the control")
            #expect(hub.contains("vacuumIndex()"), "\(path) offers no action")
        }
    }

    /// The one that would be silent. VACUUM replaces the database file underneath the boot-once
    /// read-only stores; without recreating them the cross-reference graph, person mentions and
    /// page ranges read **empty for the rest of the session**, and a relaunch hides it (#275).
    /// Nothing about the compaction itself would look wrong.
    @Test("Both hubs rebuild the read-only stores after compacting")
    func bothHubsRefreshReadOnlyStores() throws {
        for path in Self.hubs {
            let hub = try Self.source(path)
            let compact = try #require(hub.range(of: "private func compactIndex()"))
            let body = hub[compact.lowerBound...].prefix(2_000)
            #expect(body.contains("refreshReadOnlyStores()"),
                    """
                    \(path): compactIndex must call appState.refreshReadOnlyStores(). VACUUM \
                    swaps the file under the boot-once read-only connections and they go empty \
                    for the session (#275) — nothing visible would flag it.
                    """)
        }
    }

    /// Reading the split has to happen where the report is refreshed, or the offer describes a
    /// file that may since have changed — including immediately after a compaction.
    @Test("Both hubs refresh the page split with the storage report")
    func bothHubsRefreshWithReport() throws {
        for path in Self.hubs {
            let hub = try Self.source(path)
            let load = try #require(hub.range(of: "private func loadReport()"))
            let body = hub[load.lowerBound...].prefix(800)
            #expect(body.contains("refreshIndexPages()"), "\(path): stale offer")
        }
    }
}
