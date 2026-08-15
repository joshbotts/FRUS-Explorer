// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

/// The values that key the iOS analytics windows (UI review F-11 / F-25, CW-9a and CW-9b).
///
/// ## Why these properties and not the views
/// A `WindowGroup(for:)` is not a view you can instantiate in a test — but its *behaviour* is
/// almost entirely a property of the value, and that part is testable. Two things matter and both
/// fail silently:
///
/// 1. **Equality decides window count.** `openWindow(value:)` focuses the existing window for an
///    equal request and opens a new one otherwise. So a value whose equality is too *loose* merges
///    two charts the reader wanted side by side, and one too *strict* — say, one carrying a
///    timestamp — opens a new window on every invocation until the screen is full. Neither throws.
/// 2. **Codable decides restoration.** SwiftUI persists the value and rebuilds the scene from it
///    after relaunch. A field that does not survive the round trip comes back as a different chart
///    than the one the reader left open, which looks like data loss rather than a coding bug.
///
/// Version history:
///   1.0 — CW-9b
@Suite("Analytics window values")
struct AnalyticsWindowValueTests {

    /// Round-trips a value through the same coder SwiftUI uses for scene storage.
    private func roundTrip<V: Codable & Hashable>(_ value: V) throws -> V {
        try JSONDecoder().decode(V.self, from: JSONEncoder().encode(value))
    }

    // MARK: - Corpus Analytics

    @Test("a corpus-analytics request survives scene restoration intact")
    func analyticsRoundTrips() throws {
        let params = AnalyticsParameters(term: "Berlin crisis",
                                         yearRangeStart: 1958,
                                         yearRangeEnd: 1963,
                                         scopeVolumeIds: ["frus1958-60v08", "frus1961-63v14"],
                                         scopeLabel: "Berlin 1958–63")
        #expect(try roundTrip(params) == params)
    }

    @Test("two different queries are two windows, not one")
    func analyticsDistinctQueriesDiffer() {
        // The comparative workflow the review asks for: two Berlin ranges side by side. If these
        // compared equal, the second open would focus the first window and silently replace the
        // chart the reader was looking at.
        let a = AnalyticsParameters(term: "Berlin", yearRangeStart: 1958, yearRangeEnd: 1960)
        let b = AnalyticsParameters(term: "Berlin", yearRangeStart: 1961, yearRangeEnd: 1963)
        #expect(a != b)
        // Deliberately NOT asserting the hashes differ. Unequal values are permitted to collide,
        // so such an assertion would be testing the hasher's luck rather than this type's
        // contract — and `openWindow(value:)` keys on equality. (A first draft wrote
        // `hashValue != hashValue || a != b`, which cannot fail and only looked like coverage.)
    }

    @Test("the same query re-opened focuses one window rather than stacking duplicates")
    func analyticsSameQueryIsOneWindow() {
        let a = AnalyticsParameters(term: "Berlin", yearRangeStart: 1958, yearRangeEnd: 1960)
        let b = AnalyticsParameters(term: "Berlin", yearRangeStart: 1958, yearRangeEnd: 1960)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("scope is part of the identity")
    func analyticsScopeDistinguishes() {
        // Same term, different corpus scope, is a different chart — and must therefore be a
        // different window, or scoping one would retarget the other.
        let unscoped = AnalyticsParameters(term: "Berlin")
        let scoped = AnalyticsParameters(term: "Berlin",
                                         scopeVolumeIds: ["frus1958-60v08"],
                                         scopeLabel: "One volume")
        #expect(unscoped != scoped)
    }

    // MARK: - Chronology

    @Test("a chronology range survives scene restoration intact")
    func chronologyRoundTrips() throws {
        let cal = Calendar(identifier: .gregorian)
        let params = ChronologyParameters(
            rangeStart: cal.date(from: DateComponents(year: 1961, month: 8, day: 13)),
            rangeEnd: cal.date(from: DateComponents(year: 1961, month: 10, day: 27)))
        let restored = try roundTrip(params)
        #expect(restored == params)
    }

    @Test("two different ranges are two windows")
    func chronologyDistinctRangesDiffer() {
        let cal = Calendar(identifier: .gregorian)
        let a = ChronologyParameters(rangeStart: cal.date(from: DateComponents(year: 1961, month: 1, day: 1)))
        let b = ChronologyParameters(rangeStart: cal.date(from: DateComponents(year: 1962, month: 1, day: 1)))
        #expect(a != b)
    }

    @Test("the empty request is stable, so the menu always reaches one window")
    func emptyRequestsAreStable() {
        // The Browse menu opens the unscoped surface, and `BrowserView.presentAnalytics(nil)`
        // synthesises the value. Two invocations must produce the SAME value or the menu opens a
        // second identical window every time it is used — the failure `SemanticMapRequest`
        // .wholeCorpus exists to prevent, restated for these two.
        #expect(AnalyticsParameters(term: "") == AnalyticsParameters(term: ""))
        #expect(ChronologyParameters() == ChronologyParameters())
        #expect(SemanticMapRequest.wholeCorpus == SemanticMapRequest.wholeCorpus)
    }

    // MARK: - The semantic map's value (CW-9a)

    @Test("a map request survives scene restoration and keys by scope")
    func semanticMapValue() throws {
        let scoped = SemanticMapRequest(volumeIDs: ["frus1969-76v20"],
                                        scopeLabel: "Soviet Union",
                                        lensRawValue: SemanticMapLens.cluster.rawValue)
        #expect(try roundTrip(scoped) == scoped)
        #expect(scoped != SemanticMapRequest.wholeCorpus)
    }
}
