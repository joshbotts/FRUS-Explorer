// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSubjectProfilesIndex

/// The bundled `volume-subject-profiles-index.json` aggregate (Wave-6 Session 9):
/// per-volume "top subjects" profiles derived from the Office of the Historian's
/// public-domain `frus-subjects` handoff (taxonomy + document–subject mappings).
///
/// Each volume gets a ranked shortlist of the subjects most distinctive to it, scored
/// by a TF-IDF-style weight (see `ProfileAggregator`) that suppresses corpus-wide
/// generic subjects. The shared subject vocabulary is factored into `vocab`; each
/// profile row references a subject by its integer index into `vocab`, keeping the
/// bundled artifact compact (the alternative — repeating the full name/category strings
/// on every row — roughly triples the size).
///
/// The document-level subject taxonomy this data derives from is NOT re-introduced as
/// per-document tags: at the volume grain the string-match noise washes out (a volume
/// with many "Neutrality" hits genuinely concerns neutrality), which is why this feature
/// is volume-level only.
///
/// Version history:
///   1.0 — Session 9: initial implementation
public struct VolumeSubjectProfilesIndex: Codable, Sendable, Equatable {

    /// Artifact schema version.
    public let schemaVersion: Int

    /// The `yyyy-MM-dd` date the artifact was generated (provenance stamp).
    public let generated: String

    /// Human-readable provenance: the source dataset, its own generated date, and the
    /// derivation parameters, so a future maintainer can trace the numbers.
    public let provenance: String

    /// The shared subject vocabulary. A profile row's `vocabIndex` is a position in
    /// this array. Sorted by `ref` for deterministic, stable indices.
    public let vocab: [VocabSubject]

    /// The per-volume profiles, sorted by `volumeId`.
    public let profiles: [VolumeProfile]

    /// Memberwise initializer.
    ///
    /// - Parameters mirror the stored properties.
    public init(
        schemaVersion: Int,
        generated: String,
        provenance: String,
        vocab: [VocabSubject],
        profiles: [VolumeProfile]
    ) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.provenance = provenance
        self.vocab = vocab
        self.profiles = profiles
    }
}

// MARK: - VocabSubject

/// One subject in the shared vocabulary: its stable ref plus display metadata.
///
/// Uses terse coding keys (`r`/`n`/`c`/`s`) because the vocabulary ships in the app
/// bundle; the field names are documented here rather than in the JSON.
public struct VocabSubject: Codable, Sendable, Equatable {

    /// The stable subject ref (an Airtable-style `rec…` id from the source dataset).
    public let ref: String
    /// The subject's display name (e.g. `"Neutrality"`).
    public let name: String
    /// The top-level category (one of the source taxonomy's 13), e.g. `"Warfare"`.
    public let category: String
    /// The second-level subcategory.
    public let subcategory: String

    /// Memberwise initializer.
    ///
    /// - Parameters mirror the stored properties.
    public init(ref: String, name: String, category: String, subcategory: String) {
        self.ref = ref
        self.name = name
        self.category = category
        self.subcategory = subcategory
    }

    private enum CodingKeys: String, CodingKey {
        case ref = "r", name = "n", category = "c", subcategory = "s"
    }
}

// MARK: - VolumeProfile

/// One volume's ranked "top subjects" profile.
public struct VolumeProfile: Codable, Sendable, Equatable {

    /// The manifest volume id (e.g. `"frus1969-76v06"`).
    public let volumeId: String
    /// The ranked subject rows, highest score first (ties broken by vocab ref).
    public let entries: [ScoredSubject]

    /// Memberwise initializer.
    ///
    /// - Parameters mirror the stored properties.
    public init(volumeId: String, entries: [ScoredSubject]) {
        self.volumeId = volumeId
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey {
        case volumeId = "v", entries = "e"
    }
}

// MARK: - ScoredSubject

/// A subject's weight within one volume: an index into the shared `vocab` plus the
/// TF-IDF-style score (rounded to 4 decimals for compact, deterministic output).
public struct ScoredSubject: Codable, Sendable, Equatable {

    /// Index into `VolumeSubjectProfilesIndex.vocab`.
    public let vocabIndex: Int
    /// The TF-IDF-style distinctiveness weight (higher = more characteristic of the
    /// volume). Not normalized; meaningful only as a ranking within a volume.
    public let score: Double

    /// Memberwise initializer.
    ///
    /// - Parameters mirror the stored properties.
    public init(vocabIndex: Int, score: Double) {
        self.vocabIndex = vocabIndex
        self.score = score
    }

    private enum CodingKeys: String, CodingKey {
        case vocabIndex = "i", score = "w"
    }
}
