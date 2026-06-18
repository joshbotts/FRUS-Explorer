// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonClusterInput

/// One per-volume person record fed to the clusterer.
///
/// `listStartYear`/`listEndYear` come from the persons-list text (Phase 1); `mentionStartYear`/
/// `mentionEndYear` are derived from the dates of the documents that mention this record. The
/// clusterer prefers list years and falls back to mention years for its era guardrail.
public struct PersonClusterInput: Sendable {
    /// The volume the record belongs to.
    public let volumeId: String
    /// The per-volume TEI `ref` (xml:id) of the record.
    public let ref: String
    /// The display name as it appears in the volume's persons list ("Surname, Given M.").
    public let name: String
    /// Full biographical/description text (Phase 1). Carried for rollup aggregation; not used by
    /// the clustering decision.
    public let description: String?
    /// Optional role/title text (Phase 1).
    public let role: String?
    /// Active-range start year from the persons list, if any.
    public let listStartYear: Int?
    /// Active-range end year from the persons list, if any.
    public let listEndYear: Int?
    /// Earliest document year this record is mentioned in, if any.
    public let mentionStartYear: Int?
    /// Latest document year this record is mentioned in, if any.
    public let mentionEndYear: Int?
    /// Authoritative canonical id from the bundled crosswalk (Phase 5), if this `(volume, ref)` is
    /// covered. Records sharing an id are force-merged; records with *different* ids are never
    /// merged (the authority both heals fragmentation and prevents same-name conflation).
    public let authorityId: Int?

    public init(volumeId: String, ref: String, name: String, description: String? = nil,
                role: String? = nil, listStartYear: Int? = nil, listEndYear: Int? = nil,
                mentionStartYear: Int? = nil, mentionEndYear: Int? = nil, authorityId: Int? = nil) {
        self.volumeId = volumeId
        self.ref = ref
        self.name = name
        self.description = description
        self.role = role
        self.authorityId = authorityId
        self.listStartYear = listStartYear
        self.listEndYear = listEndYear
        self.mentionStartYear = mentionStartYear
        self.mentionEndYear = mentionEndYear
    }

    /// Effective start year for the era guardrail: list year when present, else mention year.
    var effectiveStartYear: Int? { listStartYear ?? mentionStartYear }
    /// Effective end year: list end, else mention end, else the effective start (single-year span).
    var effectiveEndYear: Int? { listEndYear ?? mentionEndYear ?? effectiveStartYear }
}

// MARK: - PersonClusterCandidate

/// A sub-threshold "possibly the same person" pair, referencing two distinct output clusters by
/// index. Surfaced (Phase 3/4) as a "possibly same — Merge?" suggestion; never auto-merged.
public struct PersonClusterCandidate: Sendable, Equatable {
    /// Index of the first cluster in `PersonClusterOutput.clusters`.
    public let clusterA: Int
    /// Index of the second cluster (always `> clusterA`).
    public let clusterB: Int
    /// Short human-readable reason ("name variant; era unknown").
    public let reason: String

    public init(clusterA: Int, clusterB: Int, reason: String) {
        self.clusterA = clusterA
        self.clusterB = clusterB
        self.reason = reason
    }
}

// MARK: - PersonClusterOutput

/// The result of clustering: disjoint clusters of input indices plus candidate pairs between them.
public struct PersonClusterOutput: Sendable {
    /// Each element is a cluster: the indices (into the original input array) of its members.
    /// Clusters are emitted in order of first member appearance for determinism.
    public let clusters: [[Int]]
    /// Candidate "possibly the same" pairs, referencing `clusters` by index.
    public let candidates: [PersonClusterCandidate]
}

// MARK: - PersonClusterer

/// Groups per-volume person records into cross-corpus identities (Phase 2).
///
/// Replaces the Phase-0 exact-normalised-name grouping with a blocked, guardrailed clusterer that
/// both **heals fragmentation** (the same person under slightly different name strings across
/// volumes) and **prevents conflation** (different people who share an exact name but are separated
/// in time). It honours the program's **under-merge bias**: only high-confidence pairs are merged
/// automatically; uncertain pairs stay split and are emitted as `candidates` for user confirmation.
///
/// Pipeline: surname + first-initial **blocking** → pairwise comparison within each block
/// (name relation × era relation × role relation) → union-find → connected components are clusters;
/// recorded-but-unmerged pairs become candidates. Pure and deterministic; the SQLite materialisation
/// lives in `IndexingPipeline.consolidatePersonRollup`.
public enum PersonClusterer {

    /// Years apart (between two records' effective active ranges) beyond which they are treated as
    /// different people. ~one generation; chosen to split same-name figures across distant eras.
    static let eraGapYears = 30

    /// A stable `(volumeId, ref)` member key, used to anchor user corrections to the TEI data.
    public struct MemberKey: Sendable, Hashable {
        public let volumeId: String
        public let ref: String
        public init(volumeId: String, ref: String) {
            self.volumeId = volumeId
            self.ref = ref
        }
    }

    /// Clusters `inputs` and returns the grouped member indices plus candidate pairs.
    ///
    /// `mustLink` (user "merge" corrections) forces the anchored member pairs into the same cluster,
    /// overriding blocking and the era/role guardrails. `detach` (user "split" corrections) pulls the
    /// anchored member out of whatever cluster it landed in, into its own identity. Detaches are
    /// applied before must-links, so a member can be detached and then re-merged elsewhere.
    public static func cluster(_ inputs: [PersonClusterInput],
                               mustLink: [(MemberKey, MemberKey)] = [],
                               detach: [MemberKey] = []) -> PersonClusterOutput {
        let n = inputs.count
        guard n > 0 else { return PersonClusterOutput(clusters: [], candidates: []) }

        let normalized = inputs.map { normalize($0.name) }
        var indexByKey: [MemberKey: Int] = [:]
        for i in 0..<n { indexByKey[MemberKey(volumeId: inputs[i].volumeId, ref: inputs[i].ref)] = i }

        // Blocking: only records sharing a surname + first-given-initial are ever compared.
        var blocks: [String: [Int]] = [:]
        for i in 0..<n {
            blocks[normalized[i].blockingKey, default: []].append(i)
        }

        var uf = UnionFind(count: n)
        // Raw candidate pairs by input index; resolved to cluster indices after union-find.
        var rawCandidates: [(Int, Int, String)] = []

        for indices in blocks.values where indices.count > 1 {
            for a in 0..<indices.count {
                for b in (a + 1)..<indices.count {
                    let i = indices[a], j = indices[b]
                    switch decide(inputs[i], normalized[i], inputs[j], normalized[j]) {
                    case .merge:
                        uf.union(i, j)
                    case .candidate(let reason):
                        rawCandidates.append((i, j, reason))
                    case .none:
                        break
                    }
                }
            }
        }

        // Connected components → clusters, ordered by first appearance for determinism.
        var clusterIndexOfRoot: [Int: Int] = [:]
        var clusters: [[Int]] = []
        var clusterOf = [Int](repeating: -1, count: n)
        for i in 0..<n {
            let root = uf.find(i)
            if let ci = clusterIndexOfRoot[root] {
                clusters[ci].append(i)
                clusterOf[i] = ci
            } else {
                let ci = clusters.count
                clusterIndexOfRoot[root] = ci
                clusters.append([i])
                clusterOf[i] = ci
            }
        }

        // Authority crosswalk groups (Phase 5): unite every member sharing a canonical id, across
        // blocks (the pairwise pass only compares within a block).
        var byAuthority: [Int: [Int]] = [:]
        for i in 0..<n where inputs[i].authorityId != nil {
            byAuthority[inputs[i].authorityId!, default: []].append(i)
        }
        var authorityLink: [(Int, Int)] = []
        for members in byAuthority.values where members.count > 1 {
            let first = members[0]
            for m in members.dropFirst() { authorityLink.append((first, m)) }
        }

        // Apply authority groups, then user corrections (Phase 3) on top.
        applyConstraints(authorityLink: authorityLink, mustLink: mustLink, detach: detach,
                         indexByKey: indexByKey, clusters: &clusters, clusterOf: &clusterOf)

        // Drop empty clusters left by must-link merges and reindex, keeping a member→cluster map.
        if clusters.contains(where: \.isEmpty) {
            var compact: [[Int]] = []
            for c in clusters where !c.isEmpty {
                let ci = compact.count
                for m in c { clusterOf[m] = ci }
                compact.append(c)
            }
            clusters = compact
        }

        // Map raw candidate pairs to cluster-index pairs, dropping any that ended up merged.
        var seen = Set<Int>()
        var candidates: [PersonClusterCandidate] = []
        for (i, j, reason) in rawCandidates {
            let ca = clusterOf[i], cb = clusterOf[j]
            guard ca != cb else { continue }
            let lo = min(ca, cb), hi = max(ca, cb)
            let key = lo * n + hi
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            candidates.append(PersonClusterCandidate(clusterA: lo, clusterB: hi, reason: reason))
        }

        return PersonClusterOutput(clusters: clusters, candidates: candidates)
    }

    // MARK: - User corrections (Phase 3)

    /// Applies authority groups (Phase 5) then user corrections (Phase 3), mutating `clusters`/
    /// `clusterOf`. Order matters: authority crosswalk groups first, then a user detach (which can
    /// pull a member out of an authority or heuristic cluster), then a user must-link — so a user
    /// correction always has the final say. Must-links leave an emptied slot the caller compacts away.
    private static func applyConstraints(authorityLink: [(Int, Int)],
                                         mustLink: [(MemberKey, MemberKey)],
                                         detach: [MemberKey],
                                         indexByKey: [MemberKey: Int],
                                         clusters: inout [[Int]],
                                         clusterOf: inout [Int]) {
        func merge(_ i: Int, _ j: Int) {
            let ci = clusterOf[i], cj = clusterOf[j]
            guard ci != cj else { return }
            for m in clusters[cj] { clusterOf[m] = ci }
            clusters[ci].append(contentsOf: clusters[cj])
            clusters[cj] = []
        }
        for (i, j) in authorityLink { merge(i, j) }
        for key in detach {
            guard let m = indexByKey[key] else { continue }
            let ci = clusterOf[m]
            guard clusters[ci].count > 1 else { continue }   // already its own identity
            clusters[ci].removeAll { $0 == m }
            clusterOf[m] = clusters.count
            clusters.append([m])
        }
        for (a, b) in mustLink {
            guard let i = indexByKey[a], let j = indexByKey[b] else { continue }
            merge(i, j)
        }
    }

    // MARK: - Pairwise decision

    private enum Decision {
        case merge
        case candidate(String)
        case none
    }

    private static func decide(_ a: PersonClusterInput, _ na: NormalizedName,
                               _ b: PersonClusterInput, _ nb: NormalizedName) -> Decision {
        // Authority crosswalk (Phase 5) is decisive when both records are covered: same canonical id
        // → merge; different ids → never merge (even if names match — this splits a conflation the
        // heuristic would miss). A mixed pair (one covered) falls through to the heuristic, which can
        // bridge an uncovered straggler into a covered cluster on a strong name+era match.
        if let idA = a.authorityId, let idB = b.authorityId {
            return idA == idB ? .merge : .none
        }
        switch nameRelation(na.given, nb.given) {
        case .incompatible:
            return .none
        case .exact:
            // Same name: merge unless their active ranges are clearly separated in time, in which
            // case they are different people who happen to share a name (the conflation we split).
            return eraRelation(a, b) == .disjoint ? .none : .merge
        case .variant:
            // Near-variant names: only auto-merge with positive era corroboration and no role
            // conflict; otherwise hold as a candidate (under-merge bias).
            switch eraRelation(a, b) {
            case .disjoint:
                return .none
            case .overlap:
                return roleRelation(a.role, b.role) == .incompatible
                    ? .candidate("name variant; era overlaps; role differs")
                    : .merge
            case .unknown:
                return .candidate("name variant; era unknown")
            }
        }
    }

    // MARK: - Name relation

    enum NameRelation { case exact, variant, incompatible }

    /// Compares two given-name token lists. `.exact` when identical; `.variant` when compatible but
    /// not identical (initial vs. full name, or an extra middle name/initial); `.incompatible` when
    /// a shared position has clearly different names ("Henry" vs. "Harold").
    static func nameRelation(_ g1: [String], _ g2: [String]) -> NameRelation {
        if g1 == g2 { return .exact }
        let shared = min(g1.count, g2.count)
        // Surname-only on one side: uncertain — treat as a variant (candidate, not a merge).
        if shared == 0 { return .variant }
        for k in 0..<shared where !tokensCompatible(g1[k], g2[k]) { return .incompatible }
        return .variant
    }

    /// Two name tokens are compatible if equal, or one is a single-letter initial of the other.
    static func tokensCompatible(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.count == 1 { return b.hasPrefix(a) }
        if b.count == 1 { return a.hasPrefix(b) }
        return false
    }

    // MARK: - Era relation

    enum EraRelation { case overlap, disjoint, unknown }

    /// `.overlap` when the records' effective active ranges intersect or sit within `eraGapYears`;
    /// `.disjoint` when farther apart; `.unknown` when either record has no year information.
    static func eraRelation(_ a: PersonClusterInput, _ b: PersonClusterInput) -> EraRelation {
        guard let s1 = a.effectiveStartYear, let s2 = b.effectiveStartYear else { return .unknown }
        let e1 = a.effectiveEndYear ?? s1
        let e2 = b.effectiveEndYear ?? s2
        // Gap between the two intervals; <= 0 means they overlap.
        let gap = max(s1, s2) - min(e1, e2)
        return gap <= eraGapYears ? .overlap : .disjoint
    }

    // MARK: - Role relation

    enum RoleRelation { case compatible, incompatible, unknown }

    /// Light role comparison used only to hold back variant merges. `.unknown` unless both roles
    /// carry a significant (4+ letter) word; `.incompatible` only when they share none.
    static func roleRelation(_ a: String?, _ b: String?) -> RoleRelation {
        guard let ra = a?.lowercased(), let rb = b?.lowercased(), !ra.isEmpty, !rb.isEmpty else {
            return .unknown
        }
        if ra == rb { return .compatible }
        let wa = significantWords(ra)
        let wb = significantWords(rb)
        if wa.isEmpty || wb.isEmpty { return .unknown }
        return wa.isDisjoint(with: wb) ? .incompatible : .compatible
    }

    private static func significantWords(_ s: String) -> Set<String> {
        Set(s.split { !$0.isLetter }.map(String.init).filter { $0.count >= 4 })
    }

    // MARK: - Name normalisation

    /// A name split into a folded surname and folded given-name tokens, with a blocking key.
    struct NormalizedName {
        let surname: String
        let given: [String]
        /// Surname plus the first given initial — the coarse bucket used for blocking.
        var blockingKey: String { surname + "|" + (given.first.map { String($0.prefix(1)) } ?? "") }
    }

    /// Generational suffixes dropped from name tokens before comparison.
    private static let suffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v", "2d", "3d"]
    /// Honorifics/ranks dropped from given-name tokens (they appear inconsistently across volumes).
    private static let titles: Set<String> = [
        "dr", "mr", "mrs", "ms", "sir", "gen", "general", "col", "colonel", "capt", "captain",
        "lt", "lieutenant", "maj", "major", "adm", "admiral", "sgt", "rev", "hon", "prof"
    ]

    /// Splits "Surname, Given M." (or a space-separated name) into folded surname + given tokens.
    static func normalize(_ name: String) -> NormalizedName {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let surnameRaw: String
        let givenRaw: String
        if let comma = folded.firstIndex(of: ",") {
            surnameRaw = String(folded[folded.startIndex..<comma])
            givenRaw = String(folded[folded.index(after: comma)...])
        } else {
            // No comma — assume "Given … Surname"; the last whitespace token is the surname.
            let toks = folded.split(whereSeparator: { $0 == " " }).map(String.init)
            if toks.count >= 2 {
                surnameRaw = toks.last!
                givenRaw = toks.dropLast().joined(separator: " ")
            } else {
                surnameRaw = folded
                givenRaw = ""
            }
        }
        let surname = cleanToken(surnameRaw)
        let given = givenRaw
            .split(whereSeparator: { $0 == " " || $0 == "." })
            .map { cleanToken(String($0)) }
            .filter { !$0.isEmpty && !suffixes.contains($0) && !titles.contains($0) }
        return NormalizedName(surname: surname, given: given)
    }

    /// Lowercases and strips everything but letters/digits from a single token.
    static func cleanToken(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}

// MARK: - UnionFind

/// Disjoint-set forest with path compression and union by size, over `0..<count`.
private struct UnionFind {
    private var parent: [Int]
    private var size: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root { root = parent[root] }
        var cur = x
        while parent[cur] != root { let next = parent[cur]; parent[cur] = root; cur = next }
        return root
    }

    mutating func union(_ a: Int, _ b: Int) {
        let ra = find(a), rb = find(b)
        guard ra != rb else { return }
        if size[ra] < size[rb] {
            parent[ra] = rb; size[rb] += size[ra]
        } else {
            parent[rb] = ra; size[ra] += size[rb]
        }
    }
}
