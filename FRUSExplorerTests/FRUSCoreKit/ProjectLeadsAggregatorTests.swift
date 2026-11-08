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

// MARK: - ProjectLeadsAggregatorTests

/// Tests for the pure lead aggregation (#377 Phase 3).
struct ProjectLeadsAggregatorTests {

    @Test("aggregate sums relatedness across seeds, drops seeds, ranks + caps")
    func aggregatesLeads() {
        let perSeed: [(seed: String, related: [(key: String, score: Double)])] = [
            ("v/s1", [("v/a", 1.0), ("v/b", 0.5), ("v/s2", 9.0)]),  // s2 is a seed → excluded
            ("v/s2", [("v/a", 2.0), ("v/c", 0.3)]),
        ]
        let seeds: Set<String> = ["v/s1", "v/s2"]
        let leads = ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: seeds, limit: 10)

        // a: 1.0 + 2.0 = 3.0 (recurs across both seeds) leads; then b (0.5), c (0.3). s2 dropped.
        #expect(leads.map(\.key) == ["v/a", "v/b", "v/c"])
        #expect(leads[0].aggregateScore == 3.0)
        #expect(leads[0].contributingSeedKeys == ["v/s1", "v/s2"])
        #expect(!leads.contains { $0.key == "v/s2" })

        // limit caps the result.
        #expect(ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, limit: 1).count == 1)
    }

    @Test("aggregate: a dismissed lead frees its slot (backfill) yet stays retained + hidden")
    func aggregateBackfillsDismissed() {
        let perSeed: [(seed: String, related: [(key: String, score: Double)])] = [
            ("v/s", [("v/a", 4.0), ("v/b", 3.0), ("v/c", 2.0), ("v/d", 1.0)]),
        ]
        let seeds: Set<String> = ["v/s"]

        // No dismissals: the top-2 visible leads are a, b.
        #expect(ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, limit: 2).map(\.key) == ["v/a", "v/b"])

        // Dismiss 'a': its freed slot backfills with the next-best 'c' (b, c visible), and 'a' is
        // still returned (at the end) so `applyLeads` keeps it hidden — it must not resurface.
        let withDismiss = ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, dismissedKeys: ["v/a"], limit: 2)
        #expect(withDismiss.map(\.key) == ["v/b", "v/c", "v/a"])
    }
}
