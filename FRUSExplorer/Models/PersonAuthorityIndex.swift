// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndex

/// The bundled person-authority crosswalk, loaded from `person-authority-index.json`.
///
/// This is the app-side mirror of the model produced by the `PersonAuthorityIndexGenerator` SPM
/// tool (in a separate package target the app cannot import); the JSON is the contract between them.
/// It is derived from the Office of the Historian's public-domain (CC0) `HistoryAtState/people`
/// registry, which reconciles per-volume FRUS person entries to canonical identities.
///
/// `IndexingPipeline.consolidatePersonRollup` keys the rollup on these authoritative ids where a
/// `(volume, ref)` is covered (≈78% of indexed persons), falling back to heuristic clustering and
/// user corrections elsewhere.
///
/// Version history:
///   1.0 — Person rollup Phase 5: initial implementation
public struct PersonAuthorityIndex: Codable, Sendable {

    /// Index schema version.
    public let version: Int
    /// ISO date (`yyyy-MM-dd`) the index was generated.
    public let generated: String
    /// Provenance string (upstream repo + license).
    public let source: String
    /// `volumeId → (ref → canonicalId)` crosswalk over FRUS person anchors.
    public let crosswalk: [String: [String: Int]]
    /// `"canonicalId" → entry` for every canonical person referenced by the crosswalk.
    public let authority: [String: AuthorityEntry]

    /// A canonical person: preferred name, optional birth/death years, optional VIAF id.
    public struct AuthorityEntry: Codable, Sendable {
        public let n: String
        public let b: Int?
        public let d: Int?
        public let v: String?
    }

    public init(version: Int, generated: String, source: String,
                crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry]) {
        self.version = version
        self.generated = generated
        self.source = source
        self.crosswalk = crosswalk
        self.authority = authority
    }

    // Tolerate older/newer files: default missing fields rather than failing to decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        generated = try c.decodeIfPresent(String.self, forKey: .generated) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        crosswalk = try c.decodeIfPresent([String: [String: Int]].self, forKey: .crosswalk) ?? [:]
        authority = try c.decodeIfPresent([String: AuthorityEntry].self, forKey: .authority) ?? [:]
    }

    // MARK: - Lookups

    /// The canonical id reconciled for a per-volume person, or `nil` if not covered.
    public func canonicalId(volumeId: String, ref: String) -> Int? {
        crosswalk[volumeId]?[ref]
    }

    /// The canonical record for an id, or `nil`.
    public func entry(for canonicalId: Int) -> AuthorityEntry? {
        authority[String(canonicalId)]
    }

    /// Total `(volume, ref)` entries in the crosswalk.
    public var crosswalkCount: Int { crosswalk.values.reduce(0) { $0 + $1.count } }

    // MARK: - Bundled loading

    /// Loads the bundled `person-authority-index.json`, or `nil` if it is absent (e.g. the unit-test
    /// bundle) or fails to decode. Decoding ~1.3 MB is fast; callers cache the result.
    public static func loadBundled(bundle: Bundle = .main) -> PersonAuthorityIndex? {
        guard let url = bundle.url(forResource: "person-authority-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[PersonAuthorityIndex] person-authority-index.json not found in bundle")
            #endif
            return nil
        }
        do {
            let index = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data)
            #if DEBUG
            print("[PersonAuthorityIndex] loaded \(index.crosswalkCount) crosswalk entries, "
                + "\(index.authority.count) canonical people (generated \(index.generated))")
            #endif
            return index
        } catch {
            #if DEBUG
            print("[PersonAuthorityIndex] decode failed: \(error)")
            #endif
            return nil
        }
    }
}
