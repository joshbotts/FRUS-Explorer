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
///   1.1 — Session 2026-08-07: schema v2 fields — POCOM slug, Wikidata QID, role text (#736)
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

    /// A canonical person: preferred name, life years, and reconciled external identifiers.
    ///
    /// The three schema-v2 fields are optional in both senses — absent from a v1 file, and absent
    /// from most v2 entries. Decoding stays tolerant so a build carrying either file works.
    public struct AuthorityEntry: Codable, Sendable {
        /// Preferred display name ("Surname, Given").
        public let n: String
        /// Birth year, if known.
        public let b: Int?
        /// Death year, if known.
        public let d: Int?
        /// VIAF authority id, if reconciled.
        public let v: String?
        /// POCOM slug (v2) — the key into `pocom-index.json`.
        public let s: String?
        /// Wikidata QID (v2), e.g. `Q193236`.
        public let q: String?
        /// Short role text (v2), for a subtitle line.
        public let r: String?

        /// `https://www.wikidata.org/wiki/{QID}`, when the entry carries one.
        public var wikidataURL: URL? { q.flatMap { URL(string: "https://www.wikidata.org/wiki/\($0)") } }
        /// `https://viaf.org/viaf/{id}`, when the entry carries one.
        public var viafURL: URL? { v.flatMap { URL(string: "https://viaf.org/viaf/\($0)") } }

        /// The v2 fields default to absent so callers that predate them — and any test building a
        /// fixture entry — keep compiling. The synthesized memberwise init would have required
        /// all three at every construction site.
        public init(n: String, b: Int? = nil, d: Int? = nil, v: String? = nil,
                    s: String? = nil, q: String? = nil, r: String? = nil) {
            self.n = n
            self.b = b
            self.d = d
            self.v = v
            self.s = s
            self.q = q
            self.r = r
        }
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

    /// The POCOM slug for an id, when schema v2 supplied one (#736).
    public func pocomSlug(for canonicalId: Int) -> String? {
        entry(for: canonicalId)?.s?.isEmpty == false ? entry(for: canonicalId)?.s : nil
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

// MARK: - PersonAuthorityIndexStore

/// The one decoded copy of the bundled authority index (#736).
///
/// `IndexingPipeline` has loaded this since Phase 5 for clustering; the person detail sheet now
/// needs it too, for the schema-v2 fields (POCOM slug, Wikidata, role text) that the rollup table
/// does not carry. Two independent `loadBundled()` calls would hold two decoded copies of a 2.4 MB
/// file resident, so both go through here instead.
///
/// The pipeline keeps its own injectable slot for tests — this store is deliberately *not*
/// settable, because a shared mutable singleton is how one test leaks a fixture into another.
enum PersonAuthorityIndexStore {
    static let shared: PersonAuthorityIndex? = PersonAuthorityIndex.loadBundled()
}
