// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CrossRefKit

// MARK: - ValidationOutcome

/// The outcome of validating one `<ref>` against the corpus xml:id inventories. Only `.broken`
/// records reach the report and bundled index; the rest are tallied as informational counts.
public enum ValidationOutcome: Equatable, Sendable {
    /// A resolvable ref (its target xml:id exists, and the target volume is shipped).
    case resolved
    /// An `http(s)`/`mailto` target — not existence-checked.
    case external
    /// A bare whole-volume link (`frus1865p1`) to a shipped volume.
    case wholeVolumeRef
    /// The target volume is in the series but not on disk — the anchor cannot be checked.
    case volumeNotInSnapshot
    /// The ref resolves in the corpus but the target volume is not shipped by the app; valid in the
    /// series, un-navigable in the app. `targetVolume` is that volume id.
    case nonShippable(targetVolume: String)
    /// A broken ref, with its full record.
    case broken(BrokenRef)
}

// MARK: - CrossRefValidator

/// Pass C: classify a `<ref>` with the shared `CrossRefKit` grammar, then resolve it against the
/// corpus inventories.
public struct CrossRefValidator {

    /// xml:id sets keyed by volume id, for every volume on disk.
    public let inventories: [String: Set<String>]
    /// All volume ids present on disk (the scanned corpus).
    public let corpusVolumeIds: Set<String>
    /// Volume ids in the app manifest (the shippable series).
    public let seriesVolumeIds: Set<String>

    /// Memberwise initializer (fields documented on the properties).
    public init(inventories: [String: Set<String>],
                corpusVolumeIds: Set<String>,
                seriesVolumeIds: Set<String>) {
        self.inventories = inventories
        self.corpusVolumeIds = corpusVolumeIds
        self.seriesVolumeIds = seriesVolumeIds
    }

    /// Whether a volume is real (either shipped by the app or present in the local corpus).
    private func isKnownVolume(_ id: String) -> Bool {
        corpusVolumeIds.contains(id) || seriesVolumeIds.contains(id)
    }

    /// Validates a single harvested ref from `sourceVolume` (`sourceFilename`).
    ///
    /// - Returns: The classified outcome; `.broken` carries the report record.
    public func validate(_ ref: HarvestedRef,
                         sourceVolume: String,
                         sourceFilename: String) -> ValidationOutcome {
        func broken(_ reason: BrokenRefReason, resolvedVolume: String?, resolvedAnchor: String?) -> ValidationOutcome {
            .broken(BrokenRef(sourceVolume: sourceVolume,
                              sourceDocument: ref.enclosingDocument,
                              sourceFilename: sourceFilename,
                              rawTarget: ref.rawTarget,
                              resolvedVolume: resolvedVolume,
                              resolvedAnchor: resolvedAnchor,
                              reason: reason,
                              line: ref.line,
                              byteOffset: ref.byteOffset))
        }

        switch CrossRefGrammar.classifyForValidation(ref.rawTarget, sourceVolumeId: sourceVolume) {

        case .external:
            return .external

        case .empty:
            return broken(.emptyTarget, resolvedVolume: nil, resolvedAnchor: nil)

        case .wholeVolumeOrMalformed(let token):
            guard isKnownVolume(token) else {
                // The apparent intent of a bare non-volume token is a same-volume anchor missing
                // its '#' (the app's grammar reads it that way) — record that hint for OH.
                return broken(.malformedTarget, resolvedVolume: sourceVolume, resolvedAnchor: token)
            }
            return seriesVolumeIds.contains(token) ? .wholeVolumeRef : .nonShippable(targetVolume: token)

        case .anchor(let volumeOverride, let anchor, let candidates, let shape):
            let targetVolume = volumeOverride ?? sourceVolume
            let isCrossVolume = volumeOverride != nil

            guard let ids = inventories[targetVolume] else {
                // Target volume not on disk.
                if seriesVolumeIds.contains(targetVolume) {
                    return .volumeNotInSnapshot            // real series volume, just not downloaded
                }
                return broken(.unknownVolume, resolvedVolume: targetVolume, resolvedAnchor: anchor)
            }

            let resolves = candidates.contains { ids.contains($0) }
            if resolves {
                if isCrossVolume && !seriesVolumeIds.contains(targetVolume) {
                    return .nonShippable(targetVolume: targetVolume)
                }
                return .resolved
            }
            let reason: BrokenRefReason = shape == .page ? .unknownPage : .unknownAnchor
            return broken(reason, resolvedVolume: targetVolume, resolvedAnchor: anchor)
        }
    }
}
