// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProjectFocusSuggestions

/// Suggests discovery-focus subjects for a project from the volumes it already engages
/// (#377 Phase 2b, owner decision: picker **pre-seeded** from engaged volumes).
///
/// A researcher's collected / annotated / visited documents live in a handful of volumes;
/// those volumes' most-characteristic subjects (from `VolumeSubjectProfiles`) are a strong
/// zero-config starting point for "what is this project about?" — which then resolves back
/// to a *wider* set of volumes for discovery. Pure and deterministic.
enum ProjectFocusSuggestions {

    /// Ranks subjects to suggest, drawn from the top subjects of the project's engaged
    /// volumes.
    ///
    /// Ranking: primarily by **recurrence** — how many engaged volumes carry the subject
    /// (a theme spanning several of your volumes is a better focus than a one-off) — then by
    /// summed distinctiveness score, then name for stability. Already-chosen refs are
    /// excluded.
    ///
    /// - Parameters:
    ///   - engagedVolumeIds: The volumes the project engages.
    ///   - profiles: The bundled volume-subject profiles.
    ///   - chosen: Refs already in the project's focus (excluded from suggestions).
    ///   - limit: Maximum suggestions to return.
    /// - Returns: Up to `limit` suggested subjects, best first.
    static func suggestions(engagedVolumeIds: Set<String>,
                            profiles: VolumeSubjectProfiles,
                            excluding chosen: Set<String>,
                            limit: Int = 8) -> [VolumeSubjectProfiles.SubjectOption] {
        var count: [String: Int] = [:]
        var scoreSum: [String: Double] = [:]
        for volumeId in engagedVolumeIds {
            for subject in profiles.topSubjects(forVolumeId: volumeId) ?? []
            where !chosen.contains(subject.ref) {
                count[subject.ref, default: 0] += 1
                scoreSum[subject.ref, default: 0] += subject.score
            }
        }
        let byRef = Dictionary(uniqueKeysWithValues: profiles.allSubjects.map { ($0.ref, $0) })
        return count.keys
            .compactMap { byRef[$0] }
            .sorted { lhs, rhs in
                let cl = count[lhs.ref] ?? 0, cr = count[rhs.ref] ?? 0
                if cl != cr { return cl > cr }
                let sl = scoreSum[lhs.ref] ?? 0, sr = scoreSum[rhs.ref] ?? 0
                if sl != sr { return sl > sr }
                return lhs.name < rhs.name
            }
            .prefix(limit)
            .map { $0 }
    }
}
