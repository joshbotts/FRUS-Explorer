// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
import SwiftData
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - PersonClustererTests

/// Unit tests for the pure `PersonClusterer` (Phase 2): blocking, variant folding, and the
/// era/role guardrails that drive merge / split / candidate decisions under the under-merge bias.
struct PersonClustererTests {

    private func input(_ vol: String, _ ref: String, _ name: String,
                       role: String? = nil,
                       listStart: Int? = nil, listEnd: Int? = nil,
                       authorityId: Int? = nil) -> PersonClusterInput {
        PersonClusterInput(volumeId: vol, ref: ref, name: name, role: role,
                           listStartYear: listStart, listEndYear: listEnd,
                           authorityId: authorityId)
    }

    // MARK: Exact-name behaviour

    @Test("Exact name with no era data merges (preserves Phase 0 behaviour)")
    func exactNameNoEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p_k", "Kissinger, Henry A."),
            input("v2", "p_z", "Kissinger, Henry A.")
        ])
        #expect(out.clusters.count == 1)
        #expect(out.clusters.first?.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Exact name but eras far apart splits into two clusters (de-conflation)")
    func exactNameDisjointEraSplits() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", listStart: 1850, listEnd: 1855),
            input("v2", "p2", "Smith, John", listStart: 1960, listEnd: 1965)
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty, "confident they are different people — not a suggestion")
    }

    @Test("Exact name with overlapping eras merges")
    func exactNameOverlappingEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", listStart: 1948, listEnd: 1952),
            input("v2", "p2", "Smith, John", listStart: 1950, listEnd: 1955)
        ])
        #expect(out.clusters.count == 1)
    }

    // MARK: Variant-name behaviour

    @Test("Name variant with unknown era stays split and is recorded as a candidate")
    func variantUnknownEraCandidate() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A."),
            input("v2", "p2", "Kissinger, Henry")
        ])
        #expect(out.clusters.count == 2, "under-merge bias: do not auto-merge an uncertain variant")
        #expect(out.candidates.count == 1)
        #expect(out.candidates.first?.reason.contains("variant") == true)
    }

    @Test("Name variant with overlapping era is auto-merged")
    func variantOverlappingEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A.", listStart: 1969, listEnd: 1977),
            input("v2", "p2", "Kissinger, Henry", listStart: 1973, listEnd: 1975)
        ])
        #expect(out.clusters.count == 1)
        #expect(out.candidates.isEmpty)
    }

    @Test("Name variant with overlapping era but conflicting roles is held as a candidate")
    func variantOverlappingEraRoleConflictCandidate() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Bohlen, Charles", role: "Ambassador to France", listStart: 1962, listEnd: 1968),
            input("v2", "p2", "Bohlen, C.", role: "Petroleum engineer", listStart: 1963, listEnd: 1965)
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.count == 1)
        #expect(out.candidates.first?.reason.contains("role differs") == true)
    }

    // MARK: Non-matches

    @Test("Different given names under the same surname do not merge and are not candidates")
    func incompatibleGivenNames() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, Henry"),
            input("v2", "p2", "Smith, Harold")
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Different surnames are never compared (separate blocks)")
    func differentSurnames() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry"),
            input("v2", "p2", "Nixon, Richard")
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Empty input yields empty output")
    func emptyInput() {
        let out = PersonClusterer.cluster([])
        #expect(out.clusters.isEmpty)
        #expect(out.candidates.isEmpty)
    }

    // MARK: Normalisation

    @Test("Diacritics, suffixes, and honorifics fold so variants share a block and merge")
    func normalisationFolding() {
        // "Kissinger, Henry A., Jr." vs "Kissinger, Gen. Henry Alfred" → same surname/initial block;
        // given tokens [henry, a(lfred)] are compatible → variant; overlapping era → merge.
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A., Jr.", listStart: 1970, listEnd: 1974),
            input("v2", "p2", "Kissinger, Gen. Henry Alfred", listStart: 1971, listEnd: 1975)
        ])
        #expect(out.clusters.count == 1, "suffix/title folding + initial-vs-name compatibility merge")
    }

    @Test("normalize splits surname/given and folds diacritics + case")
    func normalizeSplitsName() {
        let n = PersonClusterer.normalize("Müller, José A.")
        #expect(n.surname == "muller")
        #expect(n.given == ["jose", "a"])
        #expect(n.blockingKey == "muller|j")
    }

    @Test("nameRelation classifies exact, variant, and incompatible given names")
    func nameRelationClassification() {
        #expect(PersonClusterer.nameRelation(["henry", "a"], ["henry", "a"]) == .exact)
        #expect(PersonClusterer.nameRelation(["henry", "a"], ["henry"]) == .variant)
        #expect(PersonClusterer.nameRelation(["henry"], ["harold"]) == .incompatible)
    }

    // MARK: User corrections (Phase 3)

    private func key(_ vol: String, _ ref: String) -> PersonClusterer.MemberKey {
        PersonClusterer.MemberKey(volumeId: vol, ref: ref)
    }

    @Test("must-link merges two records the era guardrail would otherwise split")
    func mustLinkOverridesEraSplit() {
        let out = PersonClusterer.cluster(
            [input("v1", "p1", "Smith, John", listStart: 1850, listEnd: 1855),
             input("v2", "p2", "Smith, John", listStart: 1960, listEnd: 1965)],
            mustLink: [(key("v1", "p1"), key("v2", "p2"))])
        #expect(out.clusters.count == 1, "the user's merge overrides the era guardrail")
    }

    @Test("must-link merges across different surname blocks")
    func mustLinkAcrossBlocks() {
        let out = PersonClusterer.cluster(
            [input("v1", "p1", "Clay, Lucius"),
             input("v2", "p2", "Clayton, William")],   // different surname → different block
            mustLink: [(key("v1", "p1"), key("v2", "p2"))])
        #expect(out.clusters.count == 1)
    }

    @Test("detach pulls a member out of its algorithmic cluster into its own identity")
    func detachSplitsCluster() {
        let people = [input("v1", "p1", "Kissinger, Henry A."),
                      input("v2", "p2", "Kissinger, Henry A."),
                      input("v3", "p3", "Kissinger, Henry A.")]
        #expect(PersonClusterer.cluster(people).clusters.count == 1)
        let out = PersonClusterer.cluster(people, detach: [key("v3", "p3")])
        #expect(out.clusters.count == 2)
        #expect(out.clusters.contains { $0.count == 2 })
        #expect(out.clusters.contains { $0.count == 1 })
    }

    // MARK: Authority crosswalk (Phase 5)

    @Test("authority crosswalk merges members sharing a canonical id, across surname/era blocks")
    func authoritySameIdMerges() {
        // Different name strings and a disjoint listed era — the heuristic would never auto-merge —
        // but the shared canonical id unites them.
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Aaron, David L.", listStart: 1977, listEnd: 1981, authorityId: 100001),
            input("v2", "p2", "Aaron, David", authorityId: 100001),
            input("v3", "p3", "Aaron, David Laurence", listStart: 1969, listEnd: 1972, authorityId: 100001)
        ])
        #expect(out.clusters.count == 1)
        #expect(out.clusters.first?.count == 3)
    }

    @Test("authority crosswalk never merges different canonical ids, even with identical names")
    func authorityDifferentIdNeverMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", authorityId: 1),
            input("v2", "p2", "Smith, John", authorityId: 2)
        ])
        #expect(out.clusters.count == 2, "authority splits a same-name conflation the heuristic would merge")
        #expect(out.candidates.isEmpty)
    }

    @Test("a user detach overrides an authority grouping")
    func userDetachOverridesAuthority() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Aaron, David", authorityId: 100001),
            input("v2", "p2", "Aaron, David", authorityId: 100001)
        ], detach: [key("v2", "p2")])
        #expect(out.clusters.count == 2, "the user's split wins over the authority crosswalk")
    }

    @Test("detach then must-link can move a member to a different identity")
    func detachThenMustLink() {
        // a,b merge; c,d merge. Detach b from {a,b}, then must-link b with c → {a}, {b,c,d}.
        let people = [input("v1", "p1", "Adams, John"),
                      input("v2", "p2", "Adams, John"),
                      input("v3", "p3", "Baker, Howard"),
                      input("v4", "p4", "Baker, Howard")]
        let out = PersonClusterer.cluster(people,
                                          mustLink: [(key("v2", "p2"), key("v3", "p3"))],
                                          detach: [key("v2", "p2")])
        // {a} alone, and {b,c,d} merged.
        #expect(out.clusters.count == 2)
        #expect(out.clusters.contains { $0.count == 1 })
        #expect(out.clusters.contains { $0.count == 3 })
    }

    // MARK: Cannot-link guardrail (rollup v8, people-eval finding A)

    /// Given the input indices of a cluster output, returns the set of authority ids it contains.
    private func authorityIds(in cluster: [Int], of inputs: [PersonClusterInput]) -> Set<Int> {
        Set(cluster.compactMap { inputs[$0].authorityId })
    }

    @Test("an uncovered member cannot transitively bridge two different authority ids (Castro)")
    func uncoveredBridgeBetweenAuthorityIdsBlocked() {
        // The live-DB r10139 mechanism: Raúl Castro and Raul Hector Castro (AZ governor) are both
        // covered, contemporaries, and share a block; an uncovered "Castro, Raul" record decides
        // `.merge` against BOTH. Pre-v8 that union-found all three into one rollup; from v8 to v12
        // it joined whichever its block reached first, and since v13 it joins the one whose name it
        // fits exactly (the tie rule).
        let people = [
            input("v1", "p1", "Castro, Raul", listStart: 1959, listEnd: 1975, authorityId: 201),
            input("v2", "p2", "Castro, Raul Hector", listStart: 1959, listEnd: 1977, authorityId: 202),
            input("v3", "p3", "Castro, Raul", listStart: 1960, listEnd: 1970)   // uncovered
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 2, "the uncovered record joins one identity; it must not fuse both")
        for cluster in out.clusters {
            #expect(authorityIds(in: cluster, of: people).count <= 1,
                    "no cluster may carry two different authority ids")
        }
        #expect(out.clusters.contains { Set($0) == [0, 2] }, "\"Castro, Raul\" is Raúl Castro's exact name")
        #expect(out.candidates.contains { $0.reason.contains("reconciled") },
                "the blocked bridge is surfaced as a candidate (under-merge bias)")
    }

    @Test("authority pre-merge components spanning blocks cannot be bridged either (Fidel↔Raúl)")
    func crossBlockAuthorityComponentBridgeBlocked() {
        // Fidel's covered records span two blocking keys (castro|f and castro|r); an uncovered
        // "Castro, Raul" merges into Fidel's component via the castro|r record, and must then be
        // refused against covered Raúl — pre-v8 this chained Fidel into Raúl's rollup.
        let people = [
            input("v1", "p_f1", "Castro, Fidel", listStart: 1959, listEnd: 1975, authorityId: 300),
            input("v2", "p_f2", "Castro, R.", listStart: 1960, listEnd: 1970, authorityId: 300),
            input("v3", "p_r", "Castro, Raul", listStart: 1959, listEnd: 1975, authorityId: 301),
            input("v4", "p_u", "Castro, Raul", listStart: 1962, listEnd: 1968)   // uncovered
        ]
        let out = PersonClusterer.cluster(people)
        for cluster in out.clusters {
            #expect(authorityIds(in: cluster, of: people).count <= 1,
                    "Fidel's component (auth 300) and Raúl (auth 301) must stay separate")
        }
        // Fidel's two covered records stay one identity.
        #expect(out.clusters.contains { cluster in
            authorityIds(in: cluster, of: people) == [300] && cluster.count >= 2
        })
    }

    // MARK: Standing apart (rollup v13, #1767)

    /// An uncovered record the bundled index lists as belonging to no reconciled person.
    private func apart(_ vol: String, _ ref: String, _ name: String,
                       listStart: Int? = nil, listEnd: Int? = nil) -> PersonClusterInput {
        PersonClusterInput(volumeId: vol, ref: ref, name: name, listStartYear: listStart,
                           listEndYear: listEnd, standsApart: true)
    }

    /// The members of the cluster holding `vol/ref`, as `vol/ref` strings.
    private func cluster(of vol: String, _ ref: String, in out: PersonClusterOutput,
                         inputs: [PersonClusterInput]) -> Set<String> {
        let members = out.clusters.first { $0.contains { inputs[$0].volumeId == vol && inputs[$0].ref == ref } } ?? []
        return Set(members.map { "\(inputs[$0].volumeId)/\(inputs[$0].ref)" })
    }

    @Test("A member the bundle holds apart never joins a reconciled namesake (Hamilton Fish III)")
    func heldApartMemberStaysOutOfTheCoveredIdentity() {
        // v12's census: Hamilton Fish III's entries, held apart from the Secretary of State's record
        // by a correction and in no record of their own, rejoined him by name.
        let secretary = input("v1", "p_FH1", "Fish, Hamilton", listStart: 1925, listEnd: 1945, authorityId: 104298)
        let flagged = apart("v2", "p_FH_3", "Fish, Hamilton", listStart: 1933, listEnd: 1945)
        let out = PersonClusterer.cluster([secretary, flagged])
        #expect(out.clusters.count == 2)
        #expect(out.candidates == [PersonClusterCandidate(clusterA: 0, clusterB: 1,
                                                          reason: PersonClusterer.heldApartReason)])
        // The other half: without the flag the same two records merge by name and era, as in v12.
        let unflagged = input("v2", "p_FH_3", "Fish, Hamilton", listStart: 1933, listEnd: 1945)
        #expect(PersonClusterer.cluster([secretary, unflagged]).clusters.count == 1)
    }

    @Test("Entries of one unrecorded person still roll up together, apart from their namesake")
    func heldApartMembersUniteWithEachOther() {
        let people = [
            input("v1", "p_SA1", "Stevenson, Adlai E.", listStart: 1952, listEnd: 1965, authorityId: 113000),
            apart("v2", "p_SAE_3", "Stevenson, Adlai E.", listStart: 1971, listEnd: 1975),
            apart("v3", "p_SAE_2", "Stevenson, Adlai E.", listStart: 1975, listEnd: 1980),
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 2)
        #expect(cluster(of: "v2", "p_SAE_3", in: out, inputs: people) == ["v2/p_SAE_3", "v3/p_SAE_2"])
        #expect(cluster(of: "v1", "p_SA1", in: out, inputs: people) == ["v1/p_SA1"])
    }

    @Test("What has joined a member standing apart joins no reconciled person through it")
    func memberJoinedToAnApartOneStandsApartToo() {
        // The block reaches the pair with the held-apart member first, so the uncovered member is
        // joined to it, and the covered namesake's union is then refused for both.
        let people = [
            apart("v1", "p_WC_1", "Wilson, Charles", listStart: 1973, listEnd: 1988),
            input("v2", "p_WC_2", "Wilson, Charles", listStart: 1980, listEnd: 1985),
            input("v3", "p_WCE1", "Wilson, Charles", listStart: 1953, listEnd: 1957, authorityId: 114659),
        ]
        let out = PersonClusterer.cluster(people)
        #expect(cluster(of: "v1", "p_WC_1", in: out, inputs: people) == ["v1/p_WC_1", "v2/p_WC_2"])
        #expect(cluster(of: "v3", "p_WCE1", in: out, inputs: people) == ["v3/p_WCE1"])
        #expect(out.candidates.allSatisfy { $0.reason == PersonClusterer.heldApartReason })
    }

    @Test("A user's must-link over a member standing apart has the final say")
    func mustLinkOverridesStandingApart() {
        let people = [
            input("v1", "p_FH1", "Fish, Hamilton", listStart: 1925, listEnd: 1945, authorityId: 104298),
            apart("v2", "p_FH_3", "Fish, Hamilton", listStart: 1933, listEnd: 1945),
        ]
        let out = PersonClusterer.cluster(people, mustLink: [(.init(volumeId: "v1", ref: "p_FH1"),
                                                             .init(volumeId: "v2", ref: "p_FH_3"))])
        #expect(out.clusters.count == 1)
        #expect(out.candidates.isEmpty)
    }

    @Test("A covered member's apart flag is not read")
    func coveredMemberIgnoresTheFlag() {
        let flaggedButCovered = PersonClusterInput(volumeId: "v2", ref: "p_KJJ_1", name: "Kirkpatrick, Jeane J.",
                                                   listStartYear: 1981, authorityId: 107237, standsApart: true)
        let people = [input("v1", "p_KJJ_1", "Kirkpatrick, Jeane J.", listStart: 1983, authorityId: 107237),
                      flaggedButCovered,
                      input("v3", "p_KJJ_1", "Kirkpatrick, Jeane J.", listStart: 1984)]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 1, "one id unites the covered pair, and the uncovered entry joins it")
    }

    // MARK: The tie rule (rollup v13, #1658's undecided tie)

    /// Every ordering of `items`.
    private func orderings<T>(of items: [T]) -> [[T]] {
        guard items.count > 1 else { return [items] }
        return items.indices.flatMap { i -> [[T]] in
            var rest = items
            let head = rest.remove(at: i)
            return orderings(of: rest).map { [head] + $0 }
        }
    }

    /// The partition `out` makes of `inputs`, as sets of `vol/ref`, whatever order they came in.
    private func partition(_ out: PersonClusterOutput, of inputs: [PersonClusterInput]) -> Set<Set<String>> {
        Set(out.clusters.map { Set($0.map { "\(inputs[$0].volumeId)/\(inputs[$0].ref)" }) })
    }

    @Test("An uncovered member whose name fits two reconciled people joins neither, in any order")
    func tieMemberJoinsNeitherIdentity() {
        // #1658: 1981–1988 vol. XVI's "Kirkpatrick, Jeane J." merges by name with entries under two
        // ids, and until v13 the first pair its block reached decided which person it joined.
        let people = [
            input("volA", "p_KJJ_1", "Kirkpatrick, Jeane J.", listStart: 1981, authorityId: 107235),
            input("volB", "p_KJJ_1", "Kirkpatrick, Jeane J.", listStart: 1983, authorityId: 107237),
            input("volU", "p_KJJ_1", "Kirkpatrick, Jeane J.", listStart: 1985),
        ]
        let alone: Set<Set<String>> = [["volA/p_KJJ_1"], ["volB/p_KJJ_1"], ["volU/p_KJJ_1"]]
        for order in orderings(of: people) {
            let out = PersonClusterer.cluster(order)
            #expect(partition(out, of: order) == alone)
            #expect(out.candidates.count == 2 && out.candidates.allSatisfy { $0.reason == PersonClusterer.tieReason },
                    "both refused unions are candidates: \(out.candidates)")
        }
        // The other half: with the rule off, the first pair decides, and the orders disagree.
        let partitions = Set(orderings(of: people).map { partition(PersonClusterer.cluster($0, tieRule: .off), of: $0) })
        #expect(partitions.count == 2, "v12 put the uncovered entry with one person or the other by order")
    }

    @Test("A member that fits two reconciled people joins the one its exact name fits, in any order")
    func tieMemberJoinsItsExactName() {
        // The census of 2026-10-29: 1969–1976 vol. XIX Part 2's "Peterson, Peter G." fits 110613,
        // Peter G. Peterson, by its exact name, and 110612, a Peter Peterson of the same years, by a
        // variant.
        let people = [
            input("v1", "p_PP1", "Peterson, Peter", listStart: 1971, listEnd: 1974, authorityId: 110612),
            input("v2", "p_PPG1", "Peterson, Peter G.", listStart: 1971, listEnd: 1973, authorityId: 110613),
            input("v3", "p_PPG_1", "Peterson, Peter G.", listStart: 1972, listEnd: 1974),
        ]
        let joined: Set<Set<String>> = [["v1/p_PP1"], ["v2/p_PPG1", "v3/p_PPG_1"]]
        for order in orderings(of: people) {
            let out = PersonClusterer.cluster(order)
            #expect(partition(out, of: order) == joined)
            #expect(out.candidates.count == 1 && out.candidates.allSatisfy { $0.reason.contains("bridge") },
                    "the refused union with the other Peterson is a candidate: \(out.candidates)")
        }
        // With the rule off, an order that reaches the variant first gives the entry to the other man.
        let partitions = Set(orderings(of: people).map { partition(PersonClusterer.cluster($0, tieRule: .off), of: $0) })
        #expect(partitions.count == 2)
    }

    @Test("An uncovered member that fits one reconciled person still joins it")
    func singleReachStillMerges() {
        let people = [
            input("v1", "p_WSJO_1", "Wright, Sir J. Oliver", role: "British Ambassador to the United States",
                  listStart: 1982, listEnd: 1986, authorityId: 114825),
            input("v2", "p_WJ1", "Wright, Jerauld", role: "Commander in Chief, Atlantic",
                  listStart: 1954, listEnd: 1960, authorityId: 114817),
            input("v3", "p_WJO_1", "Wright, John Oliver", role: "British Ambassador to the United States",
                  listStart: 1982, listEnd: 1986),
        ]
        let out = PersonClusterer.cluster(people)
        #expect(cluster(of: "v3", "p_WJO_1", in: out, inputs: people) == ["v1/p_WSJO_1", "v3/p_WJO_1"],
                "\"John\" does not fit Jerauld, so the entry reaches Sir Oliver alone")
    }

    // MARK: "Mrs." is a distinguishing token (rollup v8, people-eval finding B)

    @Test("Mrs. <husband's name> no longer merges into the husband (Churchill/Clementine)")
    func mrsDoesNotFoldIntoHusband() {
        let people = [
            input("v1", "p_w", "Churchill, Winston S.", listStart: 1940, listEnd: 1965, authorityId: 400),
            input("v2", "p_c", "Churchill, Mrs. Winston S", listStart: 1943, listEnd: 1943, authorityId: 401),
            input("v3", "p_u", "Churchill, Winston", listStart: 1941, listEnd: 1955)   // uncovered
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 2)
        let clementine = out.clusters.first { authorityIds(in: $0, of: people).contains(401) }
        #expect(clementine?.count == 1, "Clementine stays her own identity")
        let winston = out.clusters.first { authorityIds(in: $0, of: people).contains(400) }
        #expect(winston?.count == 2, "the uncovered Winston record joins Winston, not Clementine")
    }

    @Test("normalize keeps mrs as a given token instead of dropping it")
    func normalizeKeepsMrs() {
        let n = PersonClusterer.normalize("Churchill, Mrs. Winston S")
        #expect(n.given.first == "mrs")
        #expect(PersonClusterer.nameRelation(
            n.given, PersonClusterer.normalize("Churchill, Winston S.").given) == .incompatible)
    }

    // MARK: Generational suffixes distinguish identities (rollup v8, people-eval finding B)

    @Test("differing generational suffixes never merge (Jimmy Carter Jr. vs. Chip Carter III)")
    func differingSuffixesNeverMerge() {
        let people = [
            input("v1", "p_j", "Carter, James Earl, Jr.", listStart: 1977, listEnd: 1981),
            input("v2", "p_c", "Carter, James Earl III", listStart: 1977, listEnd: 1981),
            input("v3", "p_h", "Carter, Hodding III", listStart: 1977, listEnd: 1981)
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 3, "contemporary Jr/III relatives are three distinct people")
    }

    @Test("suffixed vs. unsuffixed with a covered record is demoted to a candidate (Herter Sr/Jr)")
    func mixedSuffixCoveredPairCandidate() {
        let people = [
            input("v1", "p_sr", "Herter, Christian A.", listStart: 1957, listEnd: 1961, authorityId: 500),
            input("v2", "p_jr", "Herter, Christian A., Jr.", listStart: 1957, listEnd: 1975)
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 2, "the covered identity must not absorb its suffixed relative")
        #expect(out.candidates.count == 1)
        #expect(out.candidates.first?.reason.contains("suffix") == true)
    }

    @Test("suffixed vs. unsuffixed with unknown era is a candidate, not a merge (FDR/FDR Jr.)")
    func mixedSuffixUnknownEraCandidate() {
        let people = [
            input("v1", "p1", "Roosevelt, Franklin D."),
            input("v2", "p2", "Roosevelt, Franklin D., Jr.")
        ]
        let out = PersonClusterer.cluster(people)
        #expect(out.clusters.count == 2, "pre-v8 the suffix folded away and the exact names merged")
        #expect(out.candidates.count == 1)
    }

    @Test("normalize captures a trailing suffix but keeps a lone roman-numeral initial")
    func normalizeSuffixCapture() {
        #expect(PersonClusterer.normalize("Herter, Christian A., Jr.").suffix == "jr")
        #expect(PersonClusterer.normalize("Smith, Walter Bedell II").suffix == "ii")
        #expect(PersonClusterer.normalize("Carter, Hodding 3d").suffix == "iii", "2d/3d canonicalise to ii/iii")
        let molotov = PersonClusterer.normalize("Molotov, V.")
        #expect(molotov.suffix == nil, "a lone 'V.' is an initial, not 'the 5th'")
        #expect(molotov.given.isEmpty, "'v' stays fold-only (pre-v8 behaviour), never a distinguishing suffix")
        #expect(PersonClusterer.normalize("Franklin D. Roosevelt Jr").surname == "roosevelt",
                "a trailing suffix is never mistaken for the surname in no-comma names")
    }

    // MARK: A member's span (#1370)

    /// A member's two ends used to come from different sources — the start from the list, the end
    /// from the documents — so a list year later than every mention produced a span that ran
    /// backwards. All 235 reversed rollups #1370 measured had this shape.
    ///
    /// Abourezk: the parser stored "until January 3, 1979" as a START (the year he LEFT), and his
    /// only mention is from 1977. Abdullah: "from June 13, 1982" is a start, and his only mention is
    /// from 1981. Both are fed here in the shape they reach the clusterer in, list year as a start.
    @Test("A list start later than the mentions cannot invert a member's span (Abourezk, Abdullah)")
    func memberSpanCannotInvert() {
        let abourezk = PersonClusterInput(volumeId: "frus1977-80v02", ref: "p_AJG_1",
                                          name: "Abourezk, James G.", listStartYear: 1979,
                                          mentionStartYear: 1977, mentionEndYear: 1977)
        #expect(abourezk.effectiveStartYear == 1977)
        #expect(abourezk.effectiveEndYear == 1979)

        let abdullah = PersonClusterInput(volumeId: "frus1981-88v01", ref: "p_AASP_1",
                                          name: "Abdullah bin Abdulaziz Al Saud", listStartYear: 1982,
                                          mentionStartYear: 1981, mentionEndYear: 1981)
        #expect(abdullah.effectiveStartYear == 1981)
        #expect(abdullah.effectiveEndYear == 1982)

        // The corrected parser stores Abourezk's year as an END; the span must not care which.
        let abourezkAsEnd = PersonClusterInput(volumeId: "frus1977-80v02", ref: "p_AJG_1",
                                               name: "Abourezk, James G.", listEndYear: 1979,
                                               mentionStartYear: 1977, mentionEndYear: 1977)
        #expect(abourezkAsEnd.effectiveStartYear == 1977)
        #expect(abourezkAsEnd.effectiveEndYear == 1979)
    }

    /// The general form: whatever mix of years a member carries, its span is their minimum and
    /// maximum. Swept over every present/absent combination of four years drawn from both orders,
    /// so a rule that prefers one source for one end fails somewhere in the grid.
    @Test("A member's span is the minimum and maximum of every year it carries")
    func memberSpanIsMinMaxOfEveryYear() {
        let values: [Int?] = [nil, 1950, 1960]
        var checked = 0
        var dated = 0
        for ls in values { for le in values { for ms in values { for me in values {
            let member = PersonClusterInput(volumeId: "v", ref: "r", name: "Smith, John",
                                            listStartYear: ls, listEndYear: le,
                                            mentionStartYear: ms, mentionEndYear: me)
            let years = [ls, le, ms, me].compactMap { $0 }
            #expect(member.effectiveStartYear == years.min(), "start for \([ls, le, ms, me])")
            #expect(member.effectiveEndYear == years.max(), "end for \([ls, le, ms, me])")
            checked += 1
            if !years.isEmpty { dated += 1 }
        }}}}
        #expect(checked == 81 && dated == 80, "the sweep covered the whole grid")
    }

    // MARK: The era guardrail reads the list first (#1370 review)

    /// **Two men, and a document that remembered one of them.** frus1945Berlinv01 lists "Alexander
    /// II, Tsar of Russia, 1855–1881" and mentions him in a 1945 document; frus1917Supp02v01 lists
    /// "Alexander, King of the Hellenes from June 12" and mentions him in 1917. Both names
    /// normalise to the same key ("II" is folded away when it is the only given token), so only
    /// the era guardrail keeps them apart. The union of list and mention years put the Tsar at
    /// 1855–1945 and merged them; the list's own 1855–1881 is 36 years from 1917, beyond the gap.
    /// Rows as they stand in a full index, mention years from the dated body documents.
    @Test("A retrospective mention does not stretch the era the guardrail reads (Alexander II / Alexander)")
    func retrospectiveMentionDoesNotMerge() {
        let king = PersonClusterInput(volumeId: "frus1917Supp02v01", ref: "p_A1", name: "Alexander",
                                      role: "King of the Hellenes from June 12",
                                      mentionStartYear: 1917, mentionEndYear: 1917)
        let tsar = PersonClusterInput(volumeId: "frus1945Berlinv01", ref: "p_AII1", name: "Alexander II",
                                      role: "Tsar of Russia", listStartYear: 1855, listEndYear: 1881,
                                      mentionStartYear: 1945, mentionEndYear: 1945)
        #expect(PersonClusterer.eraRelation(king, tsar) == .disjoint)
        let out = PersonClusterer.cluster([king, tsar])
        #expect(out.clusters.count == 2, "the King of the Hellenes is not the Tsar of Russia")
        // The rollup's own span still holds every year the Tsar's record carries.
        #expect(tsar.effectiveStartYear == 1855 && tsar.effectiveEndYear == 1945)
        #expect(tsar.eraStartYear == 1855 && tsar.eraEndYear == 1881)
    }

    /// The general form: the guardrail's span is the list's years when the list names any — both
    /// ends over those years, so it cannot invert either — and the mention years only without them.
    @Test("The era span is the list's years when it names any, else the mentions'")
    func eraSpanIsListFirst() {
        let values: [Int?] = [nil, 1950, 1960]
        var checked = 0
        for ls in values { for le in values { for ms in values { for me in values {
            let member = PersonClusterInput(volumeId: "v", ref: "r", name: "Smith, John",
                                            listStartYear: ls, listEndYear: le,
                                            mentionStartYear: ms, mentionEndYear: me)
            let list = [ls, le].compactMap { $0 }
            let years = list.isEmpty ? [ms, me].compactMap { $0 } : list
            #expect(member.eraStartYear == years.min(), "era start for \([ls, le, ms, me])")
            #expect(member.eraEndYear == years.max(), "era end for \([ls, le, ms, me])")
            checked += 1
        }}}}
        #expect(checked == 81, "the sweep covered the whole grid")
    }
}

// MARK: - PersonClusterOverrideStoreTests

#if !SWIFT_PACKAGE // the override store and its records are SwiftData, the app's
/// Tests the SwiftData store for person-cluster corrections (Phase 3), backed by an in-memory
/// container so no CloudKit/disk is touched.
@MainActor
struct PersonClusterOverrideStoreTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: PersonClusterOverride.self, configurations: config)
        return ModelContext(container)
    }

    @Test("merge dedups unordered pairs and rejects a self-merge")
    func mergeDedup() throws {
        let ctx = try makeContext()
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx) != nil)
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx) == nil)
        #expect(PersonClusterOverrideStore.merge(("v2", "p2"), ("v1", "p1"), context: ctx) == nil,
                "reversed orientation is the same unordered pair")
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v1", "p1"), context: ctx) == nil,
                "a self-merge is rejected")
        #expect(PersonClusterOverrideStore.fetchAll(context: ctx).count == 1)
    }

    @Test("split dedups per member; snapshot maps both kinds")
    func splitAndSnapshot() throws {
        let ctx = try makeContext()
        #expect(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx) != nil)
        #expect(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx) == nil)
        PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx)

        let snap = PersonClusterOverrideStore.snapshot(context: ctx)
        #expect(snap.count == 2)
        #expect(snap.contains { $0.kind == .split && $0.volumeIdA == "v1" && $0.refA == "p1" })
        #expect(snap.contains { $0.kind == .merge && $0.volumeIdB == "v2" && $0.refB == "p2" })
    }

    @Test("remove deletes an override")
    func removeOverride() throws {
        let ctx = try makeContext()
        let override = try #require(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx))
        PersonClusterOverrideStore.remove(override, context: ctx)
        #expect(PersonClusterOverrideStore.fetchAll(context: ctx).isEmpty)
    }
}
#endif
