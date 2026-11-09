// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AxisWeights @AppStorage support

/// Persists the weight vector as a compact `axis:weight,…` string so it can back an `@AppStorage`
/// default — the user's preferred tuning, remembered across find-related invocations.
///
/// ## The encoding stores DEPARTURES from the default, not the vector (#1021)
/// An axis whose weight equals its current `defaultWeight` is omitted; `init?(rawValue:)` fills
/// every absent axis back in from `defaultWeight`. That is one change on paper and the whole point
/// of the conformance in practice.
///
/// The old encoding wrote every axis unconditionally. So the moment a reader released any slider,
/// their stored string pinned `sharedSubjects:0.0` — and when #308 Phase 3 raised that axis's
/// default to 0.5, the new default reached nobody who had ever touched the tuning. Worse than a
/// stale number: `RelatedDocumentsEngine` skips a zero-weighted axis outright at three sites, so
/// the stale string did not merely mis-weight the feature, it *disabled* it. The `??
/// axis.defaultWeight` fallback in `ProjectLeadsService.effectiveWeights` exists for exactly this
/// and could never fire, because the serializer guaranteed the key was present.
///
/// The consequence to hold on to: **a tuning now tracks defaults for every axis the reader has not
/// moved.** That is the fix working. Its accepted cost is that a reader who deliberately set an
/// axis to exactly today's default is indistinguishable from one who never touched it, and will
/// follow a future change to that default. There is no encoding that both tracks defaults and
/// preserves a deliberate value identical to one.
///
/// ## Why the backfill is in `init`, not in the subscript
/// Three surfaces read this preference straight out of `@AppStorage`
/// (`RelatedDocumentsContent`, `DocumentView`, `ResearchRailView`) and the macOS window payload
/// decodes it, all feeding `AxisWeights` to the engine through `subscript`, which reads a missing
/// axis as **0**. Only `ProjectLeadsService` overlays defaults. Sparse output with the old
/// subscript would therefore have zeroed every unmentioned axis on those four paths — turning a
/// compaction into a far worse version of the bug it fixes. Backfilling at the persistence
/// boundary fixes all four at once and leaves `AxisWeights(weights:)`'s sparse-dictionary
/// semantics — and everything built on them — untouched.
///
/// ## Two things about the conformance itself
///
/// 1. **The encoding is manual, not `JSONEncoder().encode(self)`, on purpose.** Adding
///    `RawRepresentable` (with `RawValue: Codable`) to a type that already synthesises `Codable`
///    makes the standard library **re-route `Equatable`, `Hashable`, and `Codable` through
///    `rawValue`** (verified empirically — `AxisWeights([.a:0.9]) == AxisWeights([.a:0.9, …:0])` is
///    now `true`, and `JSONEncoder` emits the string, not an object). A `rawValue` that called
///    `JSONEncoder().encode(self)` would therefore recurse into itself and stack-overflow at runtime.
///    Encoding each `axis.rawValue:weight` pair directly breaks that cycle.
///
/// 2. **The re-routing is intentional and safe here.** The encoding is faithful, full-precision,
///    deterministic and locale-independent — Swift's `"\(Double)"` always uses `.` and never emits
///    `:`/`,`, and axis raw values are camelCase, so no separator collision. Two vectors with the
///    same *effective* weights compare equal, which is a normalisation and arguably more correct
///    than a raw-dictionary compare. Note the sparse encoding keeps that property exactly: both
///    sides omit the same axes for the same reason.
///
/// ## The empty string is the default tuning, and that is load-bearing
/// Under this encoding `AxisWeights.default.rawValue` is `""`. `RelatedDocumentsRequest` is
/// `Codable` **through** `rawValue`, and `RawRepresentable`'s synthesised `Codable` throws
/// `.dataCorrupted` when `init?` returns nil — so a `nil` for `""` would mean a restored macOS
/// Related window saved at default weights **fails to decode and never reappears**. `""` therefore
/// decodes as `.default`. A non-empty string that yields no pairs is still malformed and still
/// returns nil, so the documented "a bad stored value falls back at the read site" contract holds
/// for genuine garbage.
///
/// ## Why it is in FRUSCoreKit
/// It was in `RelatedDocumentsView.swift` until FRUS Explorer Light's S23a (2026-11-08). The
/// conformance decides how `AxisWeights` compares, hashes and encodes (above), so it sits with the
/// type: a package build of the kit without it would compare and encode the weights as a
/// dictionary, where every Apple build compares and encodes them as this string.
extension AxisWeights: RawRepresentable {

    /// The default vectors earlier versions wrote for an **untouched** tuning.
    ///
    /// A stored string equal to one of these is treated as unconfigured, so its axes are refilled
    /// from today's defaults. Without this, #1021's fix would reach only readers who had never
    /// opened "Adjust weights" — the old serializer spelled the whole vector out, so the readers
    /// who most need the repair are precisely the ones a forward-only fix cannot see.
    ///
    /// **There are two rows, not one, and the second is easy to miss.** The semantic axis shipped
    /// in #868, so a tuning last written before it exists with only six axes; #308 Phase 3 then
    /// raised `sharedSubjects` from 0 to 0.5. An amnesty written against the seven-axis vector
    /// alone would strand everyone whose last slider release predates the semantic axis.
    ///
    /// This is safe rather than merely convenient: through both of those eras the shared-subject
    /// axis had **no bundled index behind it** (#308 Phase 3 gated on #261), so a reader could move
    /// its slider but not observe an effect. A vector identical to the era's defaults is therefore
    /// not evidence of a preference about it. A reader who set it to anything else — 0.3, say — has
    /// a vector that matches no row here and is preserved untouched.
    private static let legacyDefaultVectors: [[SimilarityAxis: Double]] = [
        // Before the semantic axis (#868): six axes.
        [.archivalProvenance: 1.0, .crossReference: 1.0, .dateProximity: 0.5,
         .subseries: 0.3, .sharedPersons: 0.7, .sharedSubjects: 0.0],
        // #868 through #308 Phase 3: seven axes, both new ones off.
        [.archivalProvenance: 1.0, .crossReference: 1.0, .dateProximity: 0.5,
         .subseries: 0.3, .sharedPersons: 0.7, .sharedSubjects: 0.0, .semanticSimilarity: 0.0],
    ]

    public init?(rawValue: String) {
        var parsed: [SimilarityAxis: Double] = [:]
        for pair in rawValue.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let axis = SimilarityAxis(rawValue: String(parts[0])),
                  let weight = Double(parts[1]) else { continue }
            parsed[axis] = weight
        }
        // `""` is the default tuning under this encoding; anything else that parses to nothing is
        // malformed and falls back at the read site.
        guard !parsed.isEmpty || rawValue.isEmpty else { return nil }

        // Amnesty before backfill: it compares against the vector AS STORED.
        if Self.legacyDefaultVectors.contains(parsed) { parsed = [:] }

        var complete: [SimilarityAxis: Double] = [:]
        for axis in SimilarityAxis.allCases {
            complete[axis] = parsed[axis] ?? axis.defaultWeight
        }
        self.init(weights: complete)
    }

    public var rawValue: String {
        // Sorted by axis rawValue for a stable, deterministic string; axes at their default are
        // omitted so the reader inherits future changes to them (#1021).
        SimilarityAxis.allCases
            .sorted { $0.rawValue < $1.rawValue }
            .filter { self[$0] != $0.defaultWeight }
            .map { "\($0.rawValue):\(self[$0])" }
            .joined(separator: ",")
    }
}
