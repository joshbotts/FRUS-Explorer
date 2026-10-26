// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The two `Codable` values an Archives Visit plan stores, which the research data export names
// (`ResearchDataEnvelope`'s plan records), moved here unchanged but `public` from the app's
// `Models/ArchiveVisitPlan.swift`, so the envelope can be FRUSCoreKit's. The plan and its two
// child models stay there: they are SwiftData's.

// MARK: - ArchiveVisitTier

/// One user-defined priority tier of a plan (§2): an id targets assign to, an optional label,
/// and a position. Any number per plan; the implicit Unprioritized group is not a tier and
/// always sorts last.
///
/// A `Codable` value in ``ArchiveVisitPlan/tiersData``, not a `@Model`: a tier is read and
/// written as part of the plan's whole ordered list, and its only cross-record reference is
/// `ArchiveVisitTarget.tierId` — which survives a tier's deletion as a dangling id that reads
/// as Unprioritized.
///
/// `Hashable` so ``ArchiveVisitDerivation/InputSignature`` can carry a plan's tiers whole (#1456):
/// the derivation copies them into the overlay as they are, so any field added here is one the
/// signature must also see, and hashing the value itself is what makes that automatic.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
///   1.1 — FRUS Explorer Light: moved into FRUSCoreKit, `public`, with its memberwise initialiser
///          spelled out as it was synthesized
public struct ArchiveVisitTier: Codable, Hashable, Sendable, Identifiable {
    /// Stable identity — what `ArchiveVisitTarget.tierId` references. Survives relabeling.
    public var id: UUID = UUID()
    /// Optional display label ("If time allows"). `nil` renders as a positional name.
    public var label: String?
    /// Sort position among the plan's tiers, ascending.
    public var order: Int = 0

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID = UUID(), label: String? = nil, order: Int = 0) {
        self.id = id
        self.label = label
        self.order = order
    }
}

// MARK: - ArchiveVisitDeliverables

/// The per-plan deliverable toggles (§3b): the three core deliverables, on by default, and the
/// citation-guidance appendix, off by default (owner decision — an opt-in appendix).
///
/// ## The decoder is hand-written, and that is load-bearing
/// Swift's synthesized `Decodable` ignores a property's default value, so a future toggle added
/// to this struct would make every already-stored blob undecodable — silently resetting every
/// plan's toggles to the defaults through the accessor's `try?`. `decodeIfPresent ?? default`
/// per field is what makes the blob actually evolvable, which is the reason it is a blob.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
///   1.1 — FRUS Explorer Light: moved into FRUSCoreKit, unchanged but `public`
public struct ArchiveVisitDeliverables: Codable, Equatable, Sendable {
    /// Deliverable (a): the repository visit-planning links.
    public var includeLinks = true
    /// Deliverable (b): the target list.
    public var includeTargets = true
    /// Deliverable (c): the per-repository inquiry drafts.
    public var includeInquiry = true
    /// The NARA citation-guidance appendix (§3a: opt-in, default off).
    public var includeCitationCrib = false

    public init(includeLinks: Bool = true, includeTargets: Bool = true,
                includeInquiry: Bool = true, includeCitationCrib: Bool = false) {
        self.includeLinks = includeLinks
        self.includeTargets = includeTargets
        self.includeInquiry = includeInquiry
        self.includeCitationCrib = includeCitationCrib
    }

    enum CodingKeys: String, CodingKey {
        case includeLinks, includeTargets, includeInquiry, includeCitationCrib
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeLinks = try container.decodeIfPresent(Bool.self, forKey: .includeLinks) ?? true
        includeTargets = try container.decodeIfPresent(Bool.self, forKey: .includeTargets) ?? true
        includeInquiry = try container.decodeIfPresent(Bool.self, forKey: .includeInquiry) ?? true
        includeCitationCrib =
            try container.decodeIfPresent(Bool.self, forKey: .includeCitationCrib) ?? false
    }
}
