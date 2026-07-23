// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSubjectProfiles

/// The app-side decode of the bundled `volume-subject-profiles-index.json` (Session 9):
/// per-volume "top subjects" derived from the Office of the Historian's public-domain
/// `frus-subjects` data by `VolumeSubjectProfilesGenerator`.
///
/// This is the successor to the retired document-level subject tags: the profiles are
/// **volume-level**, where the underlying string-match noise washes out. It powers the
/// "Top subjects" section in the volume browser (a subject chip lists the other volumes
/// that share the subject).
///
/// The generator factors the subject vocabulary into a shared `vocab` array and has each
/// profile row reference a subject by index; this decode resolves those references once,
/// up front, into `resolvedByVolume` (`volumeId → [ResolvedSubject]`) and a reverse
/// `volumesBySubjectRef` (`ref → [volumeId]`), so the views never touch the raw indices.
///
/// Decoding is optional-tolerant: a missing field degrades to an empty/neutral value
/// rather than trapping, matching the store's never-crash contract.
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — Session 9 review: surfaces `provenance` (source-drop MD5 pin) for the
///         bundled-artifact integrity test; `generated` doc corrected (it is the
///         artifact's own stamp, not the source drop's)
struct VolumeSubjectProfiles: Decodable, Sendable {

    /// One subject characteristic of a volume, fully resolved (name/category/score).
    struct ResolvedSubject: Sendable, Equatable, Identifiable {
        /// The stable subject ref (from the source dataset).
        let ref: String
        /// Display name (e.g. `"Vietnamization"`).
        let name: String
        /// Top-level category (e.g. `"Warfare"`).
        let category: String
        /// Second-level subcategory.
        let subcategory: String
        /// The TF-IDF-style distinctiveness weight; ranks within a volume only.
        let score: Double

        var id: String { ref }
    }

    /// One entry in the corpus-wide subject vocabulary — a subject a project can adopt as a
    /// discovery focus (#377 Phase 2b). Unlike ``ResolvedSubject`` it carries no per-volume
    /// score; `volumeCount` is how many volumes' profiles rank the subject (its reach).
    struct SubjectOption: Sendable, Equatable, Identifiable {
        /// The stable subject ref (matches `Project.defaultSubjectTagIds`).
        let ref: String
        /// Display name.
        let name: String
        /// Top-level category.
        let category: String
        /// Second-level subcategory.
        let subcategory: String
        /// How many volumes' profiles carry this subject.
        let volumeCount: Int

        var id: String { ref }
    }

    /// The artifact's own `yyyy-MM-dd` generation stamp (when the bundled index was
    /// built — the source drop's date and MD5 live in `provenance`).
    let generated: String

    /// The generator's provenance string: names the source dataset, its generated
    /// date, its MD5 (refs are stable only within a drop), and the derivation
    /// parameters. Empty when absent.
    let provenance: String

    /// `volumeId → [ResolvedSubject]`, each list ranked (highest score first).
    let resolvedByVolume: [String: [ResolvedSubject]]

    /// `subjectRef → [volumeId]` — the volumes whose profile carries the subject,
    /// sorted, for the cross-volume "other volumes covering this subject" pivot.
    let volumesBySubjectRef: [String: [String]]

    /// The corpus-wide subject vocabulary (subjects that carry at least one volume),
    /// de-duplicated by ref and ordered by category → subcategory → name (#377 Phase 2b).
    /// This is the picker vocabulary a project's discovery focus is chosen from.
    let allSubjects: [SubjectOption]

    // MARK: Decoding

    private enum CodingKeys: String, CodingKey {
        case generated, provenance, vocab, profiles
    }

    /// One vocabulary entry (short keys mirror the generator's compact encoding).
    private struct RawVocab: Decodable {
        let ref: String, name: String, category: String, subcategory: String
        private enum CodingKeys: String, CodingKey {
            case ref = "r", name = "n", category = "c", subcategory = "s"
        }
    }

    /// One profile row (`i` = vocab index, `w` = weight).
    private struct RawEntry: Decodable {
        let vocabIndex: Int, score: Double
        private enum CodingKeys: String, CodingKey { case vocabIndex = "i", score = "w" }
    }

    /// One volume's raw profile.
    private struct RawProfile: Decodable {
        let volumeId: String, entries: [RawEntry]
        private enum CodingKeys: String, CodingKey { case volumeId = "v", entries = "e" }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generated = (try? container.decode(String.self, forKey: .generated)) ?? ""
        provenance = (try? container.decode(String.self, forKey: .provenance)) ?? ""
        let vocab = (try? container.decode([RawVocab].self, forKey: .vocab)) ?? []
        let profiles = (try? container.decode([RawProfile].self, forKey: .profiles)) ?? []

        var byVolume: [String: [ResolvedSubject]] = [:]
        var bySubject: [String: [String]] = [:]
        byVolume.reserveCapacity(profiles.count)
        for profile in profiles {
            var resolved: [ResolvedSubject] = []
            resolved.reserveCapacity(profile.entries.count)
            for entry in profile.entries {
                guard entry.vocabIndex >= 0, entry.vocabIndex < vocab.count else { continue }
                let v = vocab[entry.vocabIndex]
                resolved.append(ResolvedSubject(
                    ref: v.ref, name: v.name, category: v.category,
                    subcategory: v.subcategory, score: entry.score))
                bySubject[v.ref, default: []].append(profile.volumeId)
            }
            if !resolved.isEmpty { byVolume[profile.volumeId] = resolved }
        }
        resolvedByVolume = byVolume
        volumesBySubjectRef = bySubject.mapValues { $0.sorted() }

        // Corpus-wide subject vocabulary for the discovery picker: keep the source vocab
        // order-independent by sorting, and only include subjects that carry ≥1 volume
        // (an unreferenced vocab entry would resolve to nothing).
        allSubjects = vocab.compactMap { entry -> SubjectOption? in
            guard let volumes = bySubject[entry.ref], !volumes.isEmpty else { return nil }
            return SubjectOption(ref: entry.ref, name: entry.name,
                                 category: entry.category, subcategory: entry.subcategory,
                                 volumeCount: Set(volumes).count)
        }.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            if lhs.subcategory != rhs.subcategory { return lhs.subcategory < rhs.subcategory }
            return lhs.name < rhs.name
        }
    }

    // MARK: Queries

    /// The ranked top subjects for a volume, or `nil` when the volume has no profile.
    ///
    /// - Parameter volumeId: The manifest volume id.
    /// - Returns: The ranked resolved subjects, or `nil` if absent.
    func topSubjects(forVolumeId volumeId: String) -> [ResolvedSubject]? {
        resolvedByVolume[volumeId]
    }

    /// A volume's top subjects grouped by category, the categories ordered by their
    /// most-characteristic (highest-scoring) subject so the leading group is the volume's
    /// dominant theme.
    ///
    /// - Parameter volumeId: The manifest volume id.
    /// - Returns: `(category, [ResolvedSubject])` groups, or `[]` when absent. Subjects
    ///   within a group keep the artifact's score-descending order.
    func groupedTopSubjects(forVolumeId volumeId: String) -> [(category: String, subjects: [ResolvedSubject])] {
        guard let subjects = resolvedByVolume[volumeId] else { return [] }
        var order: [String] = []
        var groups: [String: [ResolvedSubject]] = [:]
        for subject in subjects {
            if groups[subject.category] == nil { order.append(subject.category) }
            groups[subject.category, default: []].append(subject)
        }
        // `subjects` is already score-descending, so each group's first element is its
        // best; order categories by that best score (desc), ties by category name.
        return order
            .sorted { lhs, rhs in
                let l = groups[lhs]?.first?.score ?? 0
                let r = groups[rhs]?.first?.score ?? 0
                return l != r ? l > r : lhs < rhs
            }
            .map { (category: $0, subjects: groups[$0] ?? []) }
    }

    /// The volumes whose profile carries the subject, excluding `currentVolumeId`.
    ///
    /// - Parameters:
    ///   - ref: The subject ref.
    ///   - currentVolumeId: The volume to exclude (the one being viewed).
    /// - Returns: The other volume ids sharing the subject, sorted.
    func otherVolumes(forSubjectRef ref: String, excluding currentVolumeId: String) -> [String] {
        (volumesBySubjectRef[ref] ?? []).filter { $0 != currentVolumeId }
    }

    /// The union of volumes whose profiles carry **any** of the given subject refs — the
    /// discovery scope for a project's subject focus (#377 Phase 2b Mode A). A project's
    /// `defaultSubjectTagIds` resolve through this to `SearchParameters.volumeIds`.
    ///
    /// - Parameter refs: Subject refs (e.g. a project's `defaultSubjectTagIds`).
    /// - Returns: The de-duplicated set of volume ids covering at least one ref; empty when
    ///   no ref resolves.
    func volumeIds(forSubjectRefs refs: some Sequence<String>) -> Set<String> {
        var result = Set<String>()
        for ref in refs {
            if let volumes = volumesBySubjectRef[ref] { result.formUnion(volumes) }
        }
        return result
    }
}

// MARK: - VolumeSubjectProfilesStore

/// Loads and caches the bundled `volume-subject-profiles-index.json`.
///
/// Decoded once, **lazily**, on first access — deliberately NOT at `AppState` init, unlike
/// the removed synchronous `SubjectTagStore`. `shared` is `nil` only when the resource is
/// missing or malformed (logged in DEBUG); the volume-detail "Top subjects" section then
/// simply does not appear. Mirrors ``VolumeSourcesIndexStore``.
///
/// Version history:
///   1.0 — Session 9: initial implementation
enum VolumeSubjectProfilesStore {

    /// The bundled volume-subject profiles, or `nil` if unavailable. Loaded once.
    static let shared: VolumeSubjectProfiles? = load()

    private static func load() -> VolumeSubjectProfiles? {
        guard let url = Bundle.main.url(forResource: "volume-subject-profiles-index", withExtension: "json") else {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] volume-subject-profiles-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VolumeSubjectProfiles.self, from: data)
        } catch {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] failed to decode volume-subject-profiles-index.json — \(error)")
            #endif
            return nil
        }
    }
}
