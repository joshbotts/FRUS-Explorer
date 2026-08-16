// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// `SemanticVectorsKit` is compiled INTO the app targets (the WordCloudKit/FTS5Store pattern), so
// its types are already in scope — importing it as a module fails to resolve. Its siblings in this
// directory import Foundation alone for the same reason.
import Foundation

// MARK: - SemanticStorageReport

/// What the storage screens can honestly say about this device's semantic vectors (#900).
///
/// ## Two numbers that are complete, and two lists that never can be
/// The distinction is the whole design of this type, because presenting the second pair as though
/// it were the first would be a screen that lies quietly.
///
/// **Complete.** How many shards are on disk and how many bytes they occupy comes from listing the
/// directory — `SemanticShardStore` keeps no registry precisely so the filesystem stays the single
/// source of truth. How many *could* be here comes from the bundled shards manifest, which lists
/// every published volume. Both are total.
///
/// **Partial, by construction.**
/// - `failures` holds fetches that were attempted **and failed this session**.
///   `SemanticShardFetcher.failed` is in-memory and starts empty at every launch, so a volume that
///   failed yesterday is simply absent today.
/// - `refusals` holds shards on disk that could not be mapped — and
///   `SemanticShardStore.refusal(for:)` is populated by `shard(for:)`, i.e. **only for volumes some
///   surface has already asked about**. A corrupt shard for a volume nobody has searched is
///   invisible here.
///
/// So the screen may say "2 problems found" but must never say "no problems". ``problemsCaption``
/// is the sentence that keeps that distinction, and it is part of this type rather than the view so
/// that both platforms' hubs cannot word it differently.
///
/// ## Why this is a value type and not a view model
/// The two storage hubs are hand-maintained twins (~1,850 and ~1,960 lines). A number computed in
/// one and re-derived in the other is a number that will eventually disagree; the app already has
/// that shape in `StorageHubModel`, and this follows it.
///
/// Version history:
///   1.0 — #900
struct SemanticStorageReport: Equatable, Sendable {

    /// Volumes with a shard file on disk. Authoritative.
    let volumesOnDisk: Int

    /// Bytes those shards occupy. Authoritative.
    let bytesOnDisk: Int

    /// Volumes the bundled manifest publishes a shard for. Authoritative.
    let volumesPublished: Int

    /// Bytes every published shard would occupy together. Authoritative.
    let bytesPublished: Int

    /// Fetches that failed **this session**, as user-facing sentences keyed by volume id. Partial.
    let failures: [String: String]

    /// Shards on disk that were refused when something asked for them, as user-facing sentences
    /// keyed by volume id. Partial.
    let refusals: [String: String]

    /// An empty report, for a device where the feature has not booted.
    static let unavailable = SemanticStorageReport(
        volumesOnDisk: 0, bytesOnDisk: 0, volumesPublished: 0, bytesPublished: 0,
        failures: [:], refusals: [:])

    /// Mean bytes a published shard occupies — what one more volume costs.
    ///
    /// Derived from the two authoritative totals rather than stored, so it cannot disagree with
    /// them. It is a **mean and says so** wherever it is shown ("about"): measured over the shipped
    /// manifest the shards run from 584 B to 497,964 B, so no single figure describes a particular
    /// volume and the screen must not imply one does.
    var perVolumeEstimate: Int {
        volumesPublished > 0 ? bytesPublished / volumesPublished : 0
    }

    /// Whether the section has anything to show.
    ///
    /// **`volumesOnDisk` is part of the test, not just the denominator.** Bytes the reader owns
    /// must always be reportable and removable, including on a build whose bundled manifests are
    /// missing or from another generation — that is exactly the state where vectors on disk are
    /// dead weight, and gating the section on a publishable denominator would hide the Remove
    /// button in the one case it matters most.
    var isAvailable: Bool { volumesPublished > 0 || volumesOnDisk > 0 }

    /// Every volume with something wrong, deduplicated across the two partial sources.
    ///
    /// A volume can appear in both: a fetch that succeeded and then produced a file the store
    /// refused shows up as a refusal, while a transport failure shows up as a failure. Listing it
    /// twice would report two problems where there is one volume.
    var problemVolumeIDs: [String] {
        Array(Set(failures.keys).union(refusals.keys)).sorted()
    }

    /// The sentence for one problem volume, preferring the refusal — the shard is on disk and
    /// unusable, which is the more actionable of the two.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    func problemDescription(for volumeID: String) -> String? {
        refusals[volumeID] ?? failures[volumeID]
    }

    /// How the screen describes the completeness of its own problem list.
    ///
    /// **Never claims there are none.** Both underlying sources are partial (see the type's note),
    /// so "no problems found" would be an assertion this app cannot support — the screen can only
    /// say what it has noticed.
    var problemsCaption: String {
        let count = problemVolumeIDs.count
        if count == 0 {
            return String(
                localized: "settings.vectors.problems.none",
                defaultValue: "No problems noticed this session. Faults are only recorded when a volume is fetched or searched, so this is not a clean bill of health.")
        }
        return String(
            format: String(localized: "settings.vectors.problems.some %lld",
                           defaultValue: "%lld noticed this session — others may exist in volumes nothing has searched yet."),
            Int64(count))
    }
}

// MARK: - User-facing diagnoses

extension SemanticStorageReport {

    /// One sentence a reader can act on, for a fetch that failed.
    ///
    /// These exist because `SemanticShardFetcher.failure(for:)` had **no readers anywhere in the
    /// app**: a fetch recorded its own diagnosis and `AppState.fetchSemanticShardIfNeeded` swallowed
    /// it into a `#if DEBUG print`. The information was already being computed; it was simply never
    /// shown to the person it concerned.
    ///
    /// - Parameter error: The recorded failure.
    static func describe(_ error: SemanticShardFetcher.FetchError) -> String {
        switch error {
        case .notInManifest:
            return String(localized: "settings.vectors.error.notPublished",
                          defaultValue: "No vectors are published for this volume.")
        case .httpStatus(let code):
            return String(format: String(localized: "settings.vectors.error.http %lld",
                                         defaultValue: "The download server answered %lld."),
                          Int64(code))
        case .integrityMismatch:
            return String(localized: "settings.vectors.error.integrity",
                          defaultValue: "The downloaded file did not match its published checksum, so it was discarded.")
        case .transport:
            return String(localized: "settings.vectors.error.transport",
                          defaultValue: "The download did not complete. It will be retried after a connection change.")
        case .rejectedByStore:
            return String(localized: "settings.vectors.error.rejected",
                          defaultValue: "The vectors downloaded correctly but were built for a different version of the app, so they were not kept. A future update will publish matching ones.")
        }
    }

    /// One sentence a reader can act on, for a shard on disk the store would not use.
    ///
    /// - Parameter reason: The recorded refusal.
    /// - Returns: The sentence, or `nil` for the two cases that are **not faults**: `noArtifact`
    ///   means no shard was ever fetched, and `documentNotVectorised` is a property of one document
    ///   rather than of this volume's storage. Reporting either as a problem would fill the list
    ///   with the ordinary state of an un-fetched library.
    static func describe(_ reason: SemanticUnavailable) -> String? {
        switch reason {
        case .noArtifact, .documentNotVectorised:
            return nil
        case .pending:
            return String(localized: "settings.vectors.refused.pending",
                          defaultValue: "Still preparing.")
        case .provenanceMismatch:
            return String(localized: "settings.vectors.refused.provenance",
                          defaultValue: "These vectors were built for a different version of the app and cannot be mixed with the bundled ones. Remove them and download again.")
        case .shardMissing:
            return String(localized: "settings.vectors.refused.missing",
                          defaultValue: "The file is gone from disk.")
        case .malformedArtifact:
            return String(localized: "settings.vectors.refused.malformed",
                          defaultValue: "The file on disk is damaged and was not used. Remove it and download again.")
        }
    }
}
