// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ArchivalPoolStratificationTests

/// The archival candidate pool is now a representative slice of its container rather than the
/// container's alphabetical head (#645).
///
/// ## What was wrong
/// The archival queries `ORDER BY (volume_id, document_id)` and then `LIMIT`. For a container
/// larger than the 120-slot pool, that keeps whichever documents sort first. Measured on the
/// owner's index: Nixon's NSC Files hold **7,056 documents across 67 volumes and the first 120
/// reach five of them**; lot 54 D 270 holds 1,063 across 5 volumes, distributed 1 / 24 / 95 / 0 / 0,
/// so the 434 documents in `frus1946v10` were unreachable by any scorer for any anchor.
///
/// That contradicts the engine's own rationale for a pool deeper than the display limit — it exists
/// so a scorer can promote a candidate the generator ranked low, and a scorer can only promote a
/// candidate that is *in* the pool.
///
/// Version history:
///   1.0 — #645: initial implementation
@Suite("Archival pool stratification")
struct ArchivalPoolStratificationTests {

    private func documents(_ spec: [(volume: String, count: Int)]) -> [IndexingPipeline.RelatedDocument] {
        spec.flatMap { volume, count in
            (1...count).map { index in
                IndexingPipeline.RelatedDocument(
                    volumeId: volume, documentId: "d\(index)",
                    header: "\(volume)/d\(index)", dateline: nil,
                    documentNumber: nil, isEditorialNote: false)
            }
        }
    }

    /// The measured shape of lot 54 D 270: five volumes, wildly uneven, and the alphabetical head
    /// reaches three of them.
    @Test("A skewed container yields every volume, not the alphabetical head")
    func skewedContainer() {
        let pool = documents([("frus1945v01", 30), ("frus1945v02", 500),
                              ("frus1946v10", 434), ("frus1947v03", 60), ("frus1948v05", 39)])
        let cut = IndexingPipeline.stratifyByVolume(pool, limit: 120)

        #expect(cut.count == 120)
        let volumes = Set(cut.map(\.volumeId))
        #expect(volumes.count == 5, "every volume must be represented, got \(volumes.sorted())")

        // The old behaviour, for contrast: the first 120 alphabetically reach only two volumes.
        let alphabetical = Array(pool.prefix(120))
        #expect(Set(alphabetical.map(\.volumeId)).count == 2)
    }

    /// Round-robin means the counts are as even as the container allows — a volume with only 3
    /// documents contributes 3, and the slack goes to volumes that have more.
    @Test("Small volumes contribute everything they have; large ones absorb the slack")
    func evenAsPossible() {
        let pool = documents([("a", 3), ("b", 200), ("c", 200)])
        let cut = IndexingPipeline.stratifyByVolume(pool, limit: 60)
        var counts: [String: Int] = [:]
        for document in cut { counts[document.volumeId, default: 0] += 1 }

        #expect(cut.count == 60)
        #expect(counts["a"] == 3, "a volume with 3 documents contributes all 3")
        #expect(abs((counts["b"] ?? 0) - (counts["c"] ?? 0)) <= 1, "the rest split evenly")
    }

    /// The queries already sort, so this only interleaves — the same input must give the same
    /// output every time, or a lead score computed from it would drift between runs.
    @Test("The cut is deterministic and preserves within-volume order")
    func deterministic() {
        let pool = documents([("v1", 50), ("v2", 50), ("v3", 50)])
        let first = IndexingPipeline.stratifyByVolume(pool, limit: 30)
        for _ in 0..<20 {
            #expect(IndexingPipeline.stratifyByVolume(pool, limit: 30).map(\.header)
                    == first.map(\.header))
        }
        // Within a volume, the query's order survives.
        let v1 = first.filter { $0.volumeId == "v1" }.map(\.documentId)
        #expect(v1 == ["d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10"])
    }

    /// A container that fits, or spans one volume, must come back untouched — stratifying is only
    /// meaningful when something has to be dropped.
    @Test("A pool that fits is returned unchanged")
    func noOpCases() {
        let small = documents([("v1", 10), ("v2", 10)])
        #expect(IndexingPipeline.stratifyByVolume(small, limit: 120).map(\.header)
                == small.map(\.header))

        let single = documents([("v1", 500)])
        let cut = IndexingPipeline.stratifyByVolume(single, limit: 120)
        #expect(cut.map(\.header) == Array(single.prefix(120)).map(\.header),
                "one volume has nothing to interleave with")
    }

    @Test("Degenerate limits do not trap or over-return")
    func degenerateLimits() {
        let pool = documents([("v1", 10), ("v2", 10)])
        #expect(IndexingPipeline.stratifyByVolume(pool, limit: 0).isEmpty)
        #expect(IndexingPipeline.stratifyByVolume(pool, limit: -5).isEmpty)
        #expect(IndexingPipeline.stratifyByVolume([], limit: 120).isEmpty)
        // A limit larger than the pool returns the pool, not a padded list.
        #expect(IndexingPipeline.stratifyByVolume(pool, limit: 9_999).count == 20)
    }
}

// MARK: - ArchivalPoolWiringTests

/// Which callers get the stratified pool, and which must not.
///
/// Four of the seven `ORDER BY (volume_id, document_id)` sites feed the similarity axis; three feed
/// anchorless finding-aid surfaces, where alphabetical is the *honest* presentation — the list is
/// the collection, and there is nothing for it to be relevant to. The per-container helpers serve
/// **both** kinds of caller with no parameter distinguishing them, so the opt-in has to be threaded
/// rather than switched on inside the query.
@Suite("Archival pool wiring")
struct ArchivalPoolWiringTests {

    private static func pipelineSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appending(path: "FRUSExplorer/Search/IndexingPipeline.swift"),
            encoding: .utf8)
        #expect(text.count > 10_000, "IndexingPipeline moved?")
        return text
    }

    /// One function's whole declaration — signature **and** body — brace-matched from `func`.
    ///
    /// The wiring assertions below are about **where** something appears, not how many times it
    /// appears in the file, so they need a declaration rather than a whole-file `contains`. The
    /// signature is included deliberately: whether a parameter is defaulted is half of what these
    /// tests check, and it lives above the opening brace.
    ///
    /// Balancing braces is enough on the functions this is used for, because none of them embeds
    /// a brace inside a string literal (the SQL-building helpers, which do, are checked by prefix
    /// elsewhere). If that ever stops being true the scan runs off the end of the file and records
    /// an issue, rather than silently returning a truncated declaration that assertions would pass
    /// against.
    private static func functionSource(named name: String, in source: String) throws -> Substring {
        let signature = try #require(source.range(of: "func \(name)("),
                                     "\(name) is gone from IndexingPipeline")
        let declaration = source[signature.lowerBound...]
        let open = try #require(declaration.firstIndex(of: "{"), "\(name) has no body")
        var depth = 0
        var index = open
        while index < declaration.endIndex {
            if declaration[index] == "{" { depth += 1 }
            if declaration[index] == "}" {
                depth -= 1
                if depth == 0 { return declaration[declaration.startIndex...index] }
            }
            index = declaration.index(after: index)
        }
        Issue.record("\(name)'s body never closes — brace matching ran off the end of the file")
        return declaration
    }

    @Test("The scoped re-cut stratifies too, or the fix stops at the volume grain")
    func scopedRecutStratifies() throws {
        // The second alphabetical cut #645 reported, one grain down, and the one that actually
        // binds when a scope is active: the fetch ceiling is 100,000, so `stratifyByVolume`'s
        // `documents.count > limit` guard is false for every real container — the largest is
        // 7,056 — and the query-side stratification never fires. `applyScope` is where the list
        // is really cut.
        let source = try Self.pipelineSource()
        let applyScope = try Self.functionSource(named: "applyScope", in: source)
        #expect(applyScope.contains("stratifyByVolume(filtered, limit: limit)"), """
            applyScope must be able to stratify its re-cut. For "This subseries" — which the \
            picker offers and which expands to every member volume — a plain prefix returns the \
            alphabetically-first volumes' heads and nothing from the rest, under a scope chosen \
            precisely because it spans volumes.
            """)
        #expect(applyScope.contains("ordering == .stratified"),
                "…and only when asked, so the finding-aid callers keep their alphabetical cut")
    }

    /// The routes into the anchored axis that are meant to stratify, each with its reason.
    ///
    /// The direct-key fetch is deliberately absent: it spells its argument across a line break, so
    /// matching it textually would pin the call's formatting rather than its behaviour. The count
    /// assertion below covers it.
    private static let intendedStratifiedRequests: [(call: String, why: String)] = [
        ("limit: fetchLimit, ordering: .stratified, excluding: exclude",
         "the collection-authority alias fallback — the ONLY pool an anchor whose direct keys all missed ever sees"),
        ("ordering: .stratified)",
         "the scoped re-cut in applyScope — the cut that actually binds under a scope, because the 100,000-row fetch ceiling means the query-side stratification never fires"),
        ("ordering: .stratified\n",
         "the direct-key fetch, the anchored axis's main route"),
    ]

    /// Stratification is requested only from inside the anchored entry point — an **allowlist by
    /// location**, not a count.
    ///
    /// This assertion used to read `requests == 1`, which was wrong in a way worth recording,
    /// because it was wrong in the direction that looks right. The anchored entry point reaches
    /// the axis by two routes: the direct keys, and — when every direct key misses — the
    /// collection-authority alias fallback. Only the first was stratified, so the anchors that
    /// depend *entirely* on the fallback still got the alphabetical head of their container. And
    /// a bare count of one meant that **fixing it would fail this test**: the assertion written to
    /// stop a finding aid silently changing order was also holding the remaining half of the bug
    /// in place. A test that pins a gap shut is worse than no test, because it reads as coverage.
    ///
    /// Scoping to `archivalNeighborsWithCohort`'s body keeps the real guarantee — no anchorless
    /// finding aid quietly stops being alphabetical — without also freezing the number of routes
    /// the anchored path is allowed to have.
    ///
    /// **And then it froze them anyway.** The paragraph above says "allowlist by location, not a
    /// count", but the assertion below still read `inside == 2` — so when the *third* route was
    /// fixed (the scoped re-cut in `applyScope`, which is the cut that actually binds when a scope
    /// is active), this test went red on a change that repaired a defect. Twice now, this
    /// assertion has been the thing standing between #645 and its fix. It is a real allowlist
    /// now: ``intendedStratifiedRequests`` names each route and why it is on the list, and
    /// whoever adds a fourth has to say what it is for rather than edit a number.
    @Test("Stratification is requested at the intended sites, and only there")
    func onlyTheAnchoredPathOptsIn() throws {
        let source = try Self.pipelineSource()
        let anchored = try Self.functionSource(named: "archivalNeighborsWithCohort", in: source)

        for request in Self.intendedStratifiedRequests {
            #expect(anchored.contains(request.call), """
                Missing an intended `.stratified` request: \(request.why). Each is a route into \
                the anchored axis, and an anchor that reaches its neighbours through the missing \
                one gets #645 in full.
                """)
        }

        let inside = anchored.components(separatedBy: "ordering: .stratified").count - 1
        #expect(inside == Self.intendedStratifiedRequests.count, """
            \(inside) stratified requests inside archivalNeighborsWithCohort against \
            \(Self.intendedStratifiedRequests.count) on the allowlist. If you added one, add it to \
            `intendedStratifiedRequests` with the reason it belongs — a bare number here has now \
            blocked this issue's fix twice.
            """)

        let total = source.components(separatedBy: "ordering: .stratified").count - 1
        #expect(total == inside,
                """
                A `.stratified` request exists outside archivalNeighborsWithCohort \
                (\(total) total, \(inside) inside). Every other caller is a finding aid keyed on a \
                container: the list IS the collection, there is nothing for it to be relevant to, \
                and an alphabetical cut is the honest presentation rather than a bug.
                """)
    }

    /// `aliasNeighbors` serves both kinds of caller and takes no parameter that tells them apart,
    /// so a defaulted `ordering` is how the anchored caller silently inherited `.alphabetical`.
    /// Requiring it makes the omission a compile error instead of a wrong answer, and forwarding
    /// it is what makes stating it mean anything.
    @Test("aliasNeighbors requires an ordering and forwards it to every helper it calls")
    func aliasFallbackForwardsOrdering() throws {
        let source = try Self.pipelineSource()
        let declaration = try Self.functionSource(named: "aliasNeighbors", in: source)

        #expect(!declaration.contains("ordering: RelatedPoolOrdering = "),
                """
                aliasNeighbors' `ordering` has a default again. It is reachable from the anchored \
                axis AND from the anchorless key lookup, so a default silently gives one of them \
                the other's behaviour — which is how the second half of #645 survived the fix.
                """)
        #expect(declaration.contains("ordering: RelatedPoolOrdering,"),
                "aliasNeighbors must take an undefaulted `ordering`")

        // Every neighbour query it can dispatch to, not just the one an alias usually takes.
        for helper in ["relatedByLotFile", "relatedByPresidentialLibrary",
                       "relatedByCollection", "relatedBySeriesName"] {
            let call = try #require(declaration.range(of: "\(helper)("),
                                    "aliasNeighbors no longer calls \(helper)")
            let arguments = declaration[call.lowerBound...].prefix(260)
            #expect(arguments.contains("ordering: ordering"),
                    """
                    aliasNeighbors calls \(helper) without forwarding `ordering`, so that route \
                    falls back to the `.alphabetical` default and the anchor gets the container's \
                    alphabetical head.
                    """)
        }
    }

    /// The default must stay alphabetical, or every anchorless caller silently changes behaviour
    /// without appearing in the diff.
    @Test("The default ordering is alphabetical everywhere else")
    func defaultIsAlphabetical() throws {
        let source = try Self.pipelineSource()
        let defaults = source.components(
            separatedBy: "ordering: RelatedPoolOrdering = .alphabetical").count - 1
        #expect(defaults >= 6,
                """
                Every helper on the axis path, plus the dispatcher and the executor, must default \
                to alphabetical; found \(defaults).
                """)
    }

    /// The two anchorless sites the axis never reaches must keep their plain `LIMIT`.
    @Test("The finding-aid queries are untouched")
    func findingAidsUntouched() throws {
        let source = try Self.pipelineSource()
        for function in ["relatedByDecimalClass", "collectionNeighbors"] {
            let start = try #require(source.range(of: "func \(function)")).lowerBound
            let body = source[start...].prefix(3_000)
            #expect(!body.contains("ordering:"),
                    "\(function) is anchorless — alphabetical is its honest presentation")
        }
    }

    /// The correctness bug, which neither #644 nor #645 named.
    ///
    /// `relatedByDecimal` bound `max(1000, limit)` and then ran its segment filter **in Swift over
    /// that already-truncated set** — while ordering by `volume_id`, which sorts chronologically,
    /// against a decimal segment that *is* chronological. So the cut kept the earliest volumes and
    /// the filter then rejected them all for any later-era anchor. Measured: `893.00` spans 55
    /// volumes and the first 1,000 rows reach 18; `861.00` spans 31 and reaches 5; `812.00` spans
    /// 24 and reaches 4. Roughly 4,300 anchors got an empty list while the index held their mates.
    @Test("The decimal path no longer truncates before its own filter")
    func decimalHasNoPreCut() throws {
        let source = try Self.pipelineSource()
        // Non-comment lines only: the doc comment beside the fix names `max(1000, limit)` to
        // explain why it is gone, and a bare `contains` would fail on the explanation.
        let bindsPreCut = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { !$0.hasPrefix("//") && !$0.hasPrefix("///") && $0.contains("max(1000, limit)") }
        #expect(!bindsPreCut,
                """
                The decimal pre-cut is back. It truncates by volume_id — which sorts \
                chronologically — before a chronological segment filter runs, so a later-era \
                anchor sees only earlier-era candidates and ends with none.
                """)
        let start = try #require(source.range(of: "func relatedByDecimal(")).lowerBound
        let body = source[start...].prefix(4_000)
        #expect(body.contains("Int64(Int32.max)"),
                "the decimal select must fetch its whole match set before filtering")
    }
}
