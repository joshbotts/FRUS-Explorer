// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BrokenRefInfo

/// The reason a `<ref target>` fails to resolve, plus the destination it apparently meant —
/// everything the reading view's explanation sheet and the report export need for one broken
/// cross-reference. Carried on the `crossRefLink` render node so a tap presents the sheet with no
/// re-lookup.
///
/// `Identifiable`/`Hashable` so it can drive `.sheet(item:)` on both platforms; `Sendable` so the
/// render node stays `Sendable`.
public struct BrokenRefInfo: Sendable, Hashable, Identifiable, Codable {
    /// The verbatim `target` attribute value (e.g. `#pg_700`, `frus1877#pg_1077`).
    public let target: String
    /// The failure reason raw value: `unknownPage` / `unknownAnchor` / `unknownVolume` /
    /// `malformedTarget` / `emptyTarget`.
    public let reason: String
    /// The volume the target apparently pointed at (the `vol#` prefix, or the source volume).
    public let resolvedVolume: String?
    /// The anchor the target apparently meant (the literal string after `#`).
    public let resolvedAnchor: String?

    /// Stable identity for `.sheet(item:)`: a broken ref is fully described by its target + reason.
    public var id: String { "\(target)\u{1}\(reason)" }

    /// Memberwise initializer (fields documented on the properties).
    public init(target: String, reason: String, resolvedVolume: String?, resolvedAnchor: String?) {
        self.target = target
        self.reason = reason
        self.resolvedVolume = resolvedVolume
        self.resolvedAnchor = resolvedAnchor
    }
}

// MARK: - BrokenRefsIndex

/// The app-side decode of the bundled `broken-refs-index.json` — the corpus-wide catalogue of TEI
/// cross-references that resolve nowhere (issue #240B, produced offline by
/// `CrossRefValidationGenerator`). Loaded lazily once; drives (1) reading-view degradation of dead
/// `<ref>`s into explained non-navigable spans, (2) the `is_broken` marking + query exclusion in the
/// cross-reference graph/analytics, and (3) the in-app report export.
///
/// ## Keying — `(sourceVolume, rawTarget)`, deliberately not the bundle's `(sv, sd, t)`
/// A cross-reference is broken iff its target xml:id exists nowhere in the target volume — a pure
/// function of `(sourceVolume, rawTarget)`, independent of the source *document*. So this store keys
/// degradation and marking on `(sv, t)` and ignores `sd`. This is both simpler and strictly more
/// correct than the bundle's `(sv, sd, t)`:
///   - The reading view opens a single document and knows only `entry.documentId`; the bundle marks
///     624/652 broken occurrences as front/back-matter (`sd == ""`), a sentinel that never equals a
///     real document id — so an exact-`sd` lookup would silently fail to degrade every front-matter
///     dead ref. Volume-scoping catches them.
///   - It is safe: verified against the shipped index, no `(sv, t)` maps to conflicting
///     reasons, and no valid ref can share a broken `(sv, t)` (resolution is volume-scoped).
///
/// ## `malformedTarget` policy
/// The malformed records (bare `pg_1602` / `pg_1743` written without a `#`) are OH-report material
/// but the app *can* still navigate them as same-volume page refs, so they are excluded from
/// `degradableTargets` (the reading view keeps them live) while remaining in `records` (the export
/// includes them).
///
/// Version history:
///   1.0 — Session 7 / #240B: initial implementation
public struct BrokenRefsIndex: Sendable, Decodable {

    // MARK: Record

    /// One distinct broken cross-reference `(sv, sd, t)` key from the bundle, with its reason and
    /// apparent destination. Retained in full for the report export.
    public struct Record: Sendable, Equatable, Codable {
        /// Source volume id.
        public let sv: String
        /// Source document id, or `""` for front/back-matter refs.
        public let sd: String
        /// Verbatim `target` attribute value.
        public let t: String
        /// Failure reason raw value.
        public let r: String
        /// Resolved (apparent) volume, if known.
        public let rv: String?
        /// Resolved (apparent) anchor, if known.
        public let ra: String?
    }

    /// The reason value the reading view keeps live rather than degrading (see policy above).
    static let nonDegradableReason = "malformedTarget"

    /// Bundle schema version.
    public let schemaVersion: Int
    /// The generator run's date stamp (also the marker the pipeline gates its UPDATE pass on).
    public let generated: String
    /// Broken *occurrences* corpus-wide (the report's per-occurrence count).
    public let totalBroken: Int
    /// Whether records carry full `rv`/`ra` detail.
    public let fullDetail: Bool
    /// Every distinct broken record, in bundle order (kept for the export).
    public let records: [Record]

    /// `(sourceVolume \u{1} rawTarget)` → info, excluding the non-degradable `malformedTarget`
    /// records. Drives reading-view degradation and pipeline marking.
    private let degradableByKey: [String: BrokenRefInfo]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, totalBroken, fullDetail, records
    }

    /// Composite volume-scoped key.
    private static func key(_ sourceVolume: String, _ rawTarget: String) -> String {
        "\(sourceVolume)\u{1}\(rawTarget)"
    }

    /// Tolerant decode (mirrors `VolumeSubjectProfiles`): every field defaults so a partial/stale
    /// bundle degrades to an empty-but-valid index rather than throwing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 1
        generated = (try? c.decode(String.self, forKey: .generated)) ?? ""
        totalBroken = (try? c.decode(Int.self, forKey: .totalBroken)) ?? 0
        fullDetail = (try? c.decode(Bool.self, forKey: .fullDetail)) ?? true
        let decoded = (try? c.decode([Record].self, forKey: .records)) ?? []
        records = decoded

        var byKey: [String: BrokenRefInfo] = [:]
        byKey.reserveCapacity(decoded.count)
        for rec in decoded where rec.r != Self.nonDegradableReason {
            // Volume-scoped key; the rare (sv, t) that appears under two sd values is identical in
            // reason/rv/ra, so first-wins is lossless.
            let k = Self.key(rec.sv, rec.t)
            if byKey[k] == nil {
                byKey[k] = BrokenRefInfo(target: rec.t, reason: rec.r,
                                         resolvedVolume: rec.rv, resolvedAnchor: rec.ra)
            }
        }
        degradableByKey = byKey
    }

    // MARK: Lookups

    /// The broken-ref detail for a `<ref target>` in `sourceVolume`, or `nil` when the ref resolves
    /// or is a non-degradable `malformedTarget`. Volume-scoped: the source document is irrelevant to
    /// brokenness, so front/back-matter refs resolve here too.
    public func degradableInfo(sourceVolume: String, rawTarget: String) -> BrokenRefInfo? {
        degradableByKey[Self.key(sourceVolume, rawTarget)]
    }

    /// Every `(sourceVolume, rawTarget)` the reading view / pipeline should treat as broken — the
    /// pipeline marks `cross_references.is_broken` from this set.
    public var degradableTargets: some Sequence<(sourceVolume: String, rawTarget: String, info: BrokenRefInfo)> {
        degradableByKey.map { key, info in
            let parts = key.split(separator: "\u{1}", maxSplits: 1, omittingEmptySubsequences: false)
            return (sourceVolume: String(parts.first ?? ""), rawTarget: info.target, info: info)
        }
    }

    /// The number of distinct degradable broken targets (diagnostics / tests).
    public var degradableCount: Int { degradableByKey.count }
}

// MARK: - BrokenRefsIndexStore

/// Lazily loads the bundled `broken-refs-index.json` once. Nil-tolerant: a missing or corrupt
/// resource yields `nil`, and every consumer treats a `nil` store as "nothing is known-broken"
/// (links stay live, no exclusion, the export section hides) — never a crash.
///
/// Mirrors `VolumeSubjectProfilesStore`. Never touched at app launch; consumers warm it with a
/// detached utility task on view appear.
enum BrokenRefsIndexStore {

    /// The bundled broken-refs index, or `nil` if unavailable. Loaded once.
    static let shared: BrokenRefsIndex? = load()

    private static func load() -> BrokenRefsIndex? {
        guard let url = Bundle.main.url(forResource: "broken-refs-index", withExtension: "json") else {
            #if DEBUG
            print("[BrokenRefsIndexStore] broken-refs-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BrokenRefsIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[BrokenRefsIndexStore] failed to decode broken-refs-index.json — \(error)")
            #endif
            return nil
        }
    }
}
