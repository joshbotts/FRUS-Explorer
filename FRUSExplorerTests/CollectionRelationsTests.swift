// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - CollectionRelationsTests

/// The three derivations behind #762's additions to `CollectionDetailView`.
///
/// These run against synthetic corpora *and* the shipped `collection-authority.json`, because
/// the two catch different things: a synthetic corpus is the only way to prove the ranking
/// prefers what it claims to prefer (the artifact has no clean two-record contrast), and the
/// artifact is the only way to prove the rule survives 4,423 real records — where 64% cite a
/// single volume and every naive similarity metric degenerates.
///
/// Version history:
///   1.0 — Session 2026-08-08: #762 (archival analytics Phase 1)
@Suite("Collection relations — #762")
struct CollectionRelationsTests {

    // MARK: - Fixtures

    private func record(_ id: String, _ name: String, volumes: [String],
                        repository: String? = nil, recordGroup: String? = nil,
                        lot: String? = nil) -> AuthorityCollectionRecord {
        AuthorityCollectionRecord(id: id, name: name, repository: repository,
                                  recordGroup: recordGroup, lotFileNorm: lot,
                                  volumeIds: volumes)
    }

    private func volumes(_ range: ClosedRange<Int>) -> [String] {
        range.map { "frusV\($0)" }
    }

    // MARK: - Ranking: the metric is the overlap coefficient, not the raw count

    @Test("A fully-contained small collection outranks a broader one that shares more volumes")
    func overlapCoefficientOutranksRawSharedCount() {
        // The whole point of dividing by the *smaller* list: `umbrella` shares more volumes
        // with the focus than `tight` does, but only because it is cited nearly everywhere.
        // Under raw-shared ranking `umbrella` wins and this test fails — which is what makes
        // it a test of the metric rather than of the sort call.
        let focus = record("focus", "Focus", volumes: volumes(1...20))
        let tight = record("tight", "Tight", volumes: volumes(1...4))            // 4/4  → 1.00
        let umbrella = record("umbrella", "Umbrella",
                              volumes: volumes(1...10) + volumes(50...100))      // 10/20 → 0.50

        let ranked = CollectionRelations.related(to: focus, in: [focus, tight, umbrella])

        #expect(ranked.map(\.id) == ["tight", "umbrella"], """
            Ranking is not the overlap coefficient: `umbrella` shares 10 volumes to `tight`'s \
            4, so a raw-count or Jaccard-free ordering puts it first. Measured on the shipped \
            artifact, that ordering makes the 157-volume Central Files record the top answer \
            on nearly every large collection — the umbrella problem the coefficient exists to \
            damp.
            """)
        #expect(ranked.first?.overlap == 1.0)
        #expect(ranked.first?.sharedVolumeCount == 4)
        #expect(ranked.last?.overlap == 0.5)
    }

    @Test("A partner sharing one volume is not related, however perfect its coefficient")
    func oneSharedVolumeIsBelowTheFloor() {
        // `singleton`'s entire volume list sits inside the focus, so it scores exactly 1.000 —
        // the highest score available — and without the floor it is the FIRST row. On the
        // shipped artifact 2,846 records are of exactly this shape; measured, they take 80.3%
        // of the top-5 slots for large collections when the floor is removed.
        let focus = record("focus", "Focus", volumes: volumes(1...20))
        let singleton = record("singleton", "Singleton", volumes: ["frusV1"])
        let real = record("real", "Real", volumes: volumes(1...3))

        let ranked = CollectionRelations.related(to: focus, in: [focus, singleton, real])

        #expect(!ranked.contains { $0.id == "singleton" }, """
            A one-volume record cleared the floor. It scores 1.000 by construction (its list \
            is a subset of every list containing it), so it does not merely appear — it \
            outranks every genuinely related collection.
            """)
        #expect(ranked.map(\.id) == ["real"])
    }

    @Test("A collection cited in one volume has no related collections at all")
    func singleVolumeFocusHasNoRelations() {
        let focus = record("focus", "Focus", volumes: ["frusV1"])
        let other = record("other", "Other", volumes: ["frusV1", "frusV2"])
        #expect(CollectionRelations.related(to: focus, in: [focus, other]).isEmpty, """
            With one citing volume there is no evidence of a shared neighbourhood — every \
            collection in that volume ties, and the ranking would be arbitrary.
            """)
    }

    @Test("Among equal coefficients, stronger evidence wins, then the more specific collection")
    func tieBreaksPreferEvidenceThenSpecificity() {
        let focus = record("focus", "Focus", volumes: volumes(1...10))
        // Two pairs, each tied on the coefficient, each isolating one tie-break.
        // 4/min(10,8) = 0.5 and 2/min(10,4) = 0.5 — same score, different evidence.
        let strongEvidence = record("strongEvidence", "StrongEvidence",
                                    volumes: volumes(1...4) + volumes(50...53))
        let weakEvidence = record("weakEvidence", "WeakEvidence",
                                  volumes: volumes(1...2) + volumes(60...61))
        // 3/min(10,13) = 0.3 and 3/min(10,33) = 0.3 — same score, same evidence, different breadth.
        let specific = record("specific", "Specific", volumes: volumes(1...3) + volumes(20...29))
        let sprawling = record("sprawling", "Sprawling", volumes: volumes(1...3) + volumes(30...59))

        let ranked = CollectionRelations.related(
            to: focus, in: [focus, sprawling, weakEvidence, specific, strongEvidence])

        #expect(ranked.map(\.overlap) == [0.5, 0.5, 0.3, 0.3],
                "fixture is wrong — the tie-breaks are only exercised when the scores tie")
        #expect(ranked.map(\.id) == ["strongEvidence", "weakEvidence", "specific", "sprawling"], """
            Tie-break order is wrong. Coefficients saturate across wide bands, so shared count \
            is what separates strong evidence from weak — note `strongEvidence` is the broader \
            of its pair and still wins, so breadth must not outrank evidence. Among equal \
            evidence the *smaller* partner is the more specifically related one, not another \
            umbrella.
            """)
    }

    @Test("The ranking does not depend on the order records arrive in")
    func rankingIsDeterministic() {
        let focus = record("focus", "Focus", volumes: volumes(1...12))
        var corpus = (1...30).map { i in
            record("r\(i)", "Record \(i)", volumes: volumes(1...(i % 9 + 2)))
        }
        corpus.append(focus)
        let forward = CollectionRelations.related(to: focus, in: corpus).map(\.id)
        let reversed = CollectionRelations.related(to: focus, in: corpus.reversed()).map(\.id)
        #expect(!forward.isEmpty, "fixture produced no rows — the comparison would be vacuous")
        #expect(forward == reversed, """
            Two orderings of the same corpus produced different rankings, so the sort is \
            resolving ties by input order. Swift's sort is not stable; the list would reshuffle \
            between launches.
            """)
    }

    @Test("A record is never related to itself, and empty records never appear")
    func selfAndEmptyRecordsAreExcluded() {
        let focus = record("focus", "Focus", volumes: volumes(1...5))
        let clone = record("clone", "Clone", volumes: volumes(1...5))
        let empty = record("empty", "Empty", volumes: [])
        let ranked = CollectionRelations.related(to: focus, in: [focus, clone, empty])
        #expect(ranked.map(\.id) == ["clone"])
    }

    // MARK: - Ranking against the shipped artifact

    @Test("The shipped authority ranks a real lot into a coherent, well-formed list")
    func shippedArtifactRanking() throws {
        let index = try #require(CollectionAuthorityStore.shared,
                                 "collection-authority.json must decode from the app bundle")
        let focus = try #require(index.record(forLotNorm: "63D351"),
                                 "S/S–NSC Files: Lot 63 D 351 is the worked example in the plan")
        #expect(focus.volumeIds.count > 50, "the focus record should be a broadly-cited lot")

        let ranked = CollectionRelations.related(to: focus, in: index.collections)
        #expect(ranked.count > 100, "guard is vacuous — only \(ranked.count) related records")

        for item in ranked {
            #expect(item.sharedVolumeCount >= CollectionRelations.minimumSharedVolumes,
                    "\(item.record.name) cleared the list with \(item.sharedVolumeCount) shared")
            #expect(item.record.id != focus.id)
            #expect(item.overlap > 0 && item.overlap <= 1.0,
                    "\(item.record.name) has an out-of-range coefficient \(item.overlap)")
        }

        // The documented total order, re-derived independently of the implementation's sort.
        for (a, b) in zip(ranked, ranked.dropFirst()) {
            let ordered = a.overlap > b.overlap
                || (a.overlap == b.overlap && a.sharedVolumeCount > b.sharedVolumeCount)
                || (a.overlap == b.overlap && a.sharedVolumeCount == b.sharedVolumeCount
                    && a.record.volumeIds.count <= b.record.volumeIds.count)
            #expect(ordered, "\(a.record.name) is ranked above \(b.record.name) out of order")
        }

        // The failure the floor exists to prevent, checked where it actually bit.
        let topFive = ranked.prefix(CollectionRelations.previewRowCap)
        #expect(topFive.allSatisfy { $0.record.volumeIds.count >= 2 }, """
            A single-volume record reached the top five of a 98-volume lot. That is the \
            measured pre-floor failure mode, not a hypothetical.
            """)
    }

    @Test("Every shipped record ranks without producing an out-of-contract row")
    func shippedArtifactIsWellBehavedCorpusWide() throws {
        let index = try #require(CollectionAuthorityStore.shared)
        // A sample rather than all 4,423 × 4,423: the contract is per-record, and the cost of
        // the full cross-product is minutes of test time for no extra coverage.
        let sampled = index.collections.enumerated()
            .filter { $0.offset % 60 == 0 }
            .map(\.element)
        var withRelations = 0
        var checked = 0
        for focus in sampled {
            let ranked = CollectionRelations.related(to: focus, in: index.collections)
            checked += 1
            if !ranked.isEmpty { withRelations += 1 }
            #expect(!ranked.contains { $0.record.id == focus.id })
            if focus.volumeIds.count < CollectionRelations.minimumSharedVolumes {
                #expect(ranked.isEmpty,
                        "\(focus.name) cites \(focus.volumeIds.count) volume(s) but ranked rows")
            }
        }
        #expect(checked > 50, "guard is vacuous — only \(checked) records sampled")
        #expect(withRelations > 5,
                "guard is vacuous — \(withRelations) of \(checked) sampled records had relations")
    }

    // MARK: - Coverage eras

    @Test("The era table partitions the series without gaps or overlaps")
    func erasArePartitioned() {
        let eras = CollectionRelations.coverageEras
        #expect(eras.count > 10, "the axis collapsed to a handful of buckets")
        #expect(eras.first?.startYear == 1861, "the table must start at the FRUS series' own floor")
        for (a, b) in zip(eras, eras.dropFirst()) {
            #expect(a.endYear >= a.startYear, "\(a.fullLabel) is inverted")
            #expect(b.startYear == a.endYear + 1,
                    "gap or overlap between \(a.fullLabel) and \(b.fullLabel)")
            #expect(b.index == a.index + 1)
        }
    }

    @Test("The postwar buckets are the published subseries, not decades")
    func postwarBucketsMatchSubseries() {
        // This axis exists because SA-3's decades are the wrong grain for one collection.
        // Both assertions below distinguish the two: a decade axis splits 1969–76 in half and
        // merges 1960 with 1961, and FRUS's own volumes do neither.
        #expect(CollectionRelations.eraIndex(forMidpointYear: 1969)
                == CollectionRelations.eraIndex(forMidpointYear: 1976), """
                The 1969–1976 subseries — 66 volumes, the largest in the corpus — was split \
                across two buckets at the 1970 decade line.
                """)
        #expect(CollectionRelations.eraIndex(forMidpointYear: 1960)
                != CollectionRelations.eraIndex(forMidpointYear: 1961),
                "the 1958–60 and 1961–63 subseries were merged into one 1960s bucket")

        let spans = Set(CollectionRelations.coverageEras.map { "\($0.startYear)-\($0.endYear)" })
        // Exactly the published subseries ids from 1955 on.
        for expected in ["1955-1957", "1958-1960", "1961-1963", "1964-1968",
                         "1969-1976", "1977-1980", "1981-1988", "1989-1992"] {
            #expect(spans.contains(expected), "\(expected) is not a bucket — the axis has drifted")
        }
        // The two earlier buckets the approved design names, which group the per-year
        // subseries of those years (the manifest carries 1948, 1949, 1950 separately).
        #expect(spans.contains("1948-1950"))
        #expect(spans.contains("1951-1954"))
    }

    @Test("Axis labels never let an 1860s bucket read as a 1960s one")
    func shortLabelsAreUnambiguous() throws {
        let nineteenth = try #require(CollectionRelations.coverageEras.first)
        #expect(nineteenth.shortLabel == "1861–1870",
                "a pre-1900 bucket must spell its years out; '61–70 would read as 1961–1970")
        let sixties = CollectionRelations.coverageEras.first { $0.startYear == 1961 }
        #expect(sixties?.shortLabel == "’61–63")
        #expect(sixties?.fullLabel == "1961–1963")
    }

    @Test("Midpoint attribution matches the rule SA-3a's generator uses")
    func midpointMatchesSA3a() {
        #expect(CollectionRelations.midpointYear(earliest: "1947-01-01T00:00:00Z",
                                                 latest: "1949-12-31T00:00:00Z") == 1948)
        #expect(CollectionRelations.midpointYear(earliest: "1969-01-01", latest: "1976-12-31") == 1972)
        // One endpoint missing falls back to the other, rather than dropping the volume.
        #expect(CollectionRelations.midpointYear(earliest: "1955-06-01", latest: nil) == 1955)
        #expect(CollectionRelations.midpointYear(earliest: nil, latest: "1955-06-01") == 1955)
        #expect(CollectionRelations.midpointYear(earliest: nil, latest: nil) == nil)
        #expect(CollectionRelations.midpointYear(earliest: "not a date", latest: nil) == nil)
    }

    @Test("Midpoints outside the table clamp instead of dropping the volume")
    func outOfRangeMidpointsClamp() {
        // frus1872p2v5 covers 1620–1872, giving a midpoint of 1740 — before the series' own
        // 1861 floor. Dropping it would shrink a count the reader takes as complete.
        #expect(CollectionRelations.eraIndex(forMidpointYear: 1740) == 0)
        #expect(CollectionRelations.eraIndex(forMidpointYear: 1861) == 0)
        let last = CollectionRelations.coverageEras.count - 1
        #expect(CollectionRelations.eraIndex(forMidpointYear: 2050) == last)
        #expect(CollectionRelations.eraIndex(forMidpointYear: 1962)
                == CollectionRelations.coverageEras.firstIndex { $0.startYear == 1961 })
    }

    @Test("The timeline runs first-to-last and keeps interior gaps")
    func timelineKeepsInteriorGaps() {
        // 1948–50, nothing in 1951–54, then 1955–57 twice.
        let buckets = CollectionRelations.citedOverTime(volumeMidpoints: [1949, 1956, 1956])
        #expect(buckets.map(\.era.fullLabel) == ["1948–1950", "1951–1954", "1955–1957"], """
            The empty middle bucket was dropped. A gap in a collection's use is the shape the \
            chart exists to show; closing it up would draw two adjacent bars and imply \
            continuous citation.
            """)
        #expect(buckets.map(\.volumeCount) == [1, 0, 2])
    }

    @Test("Volumes inside a single era produce no chart")
    func singleEraProducesNoChart() {
        #expect(CollectionRelations.citedOverTime(volumeMidpoints: [1962, 1962, 1963]).isEmpty,
                "one bar states nothing the section header does not already say")
        #expect(CollectionRelations.citedOverTime(volumeMidpoints: []).isEmpty)
    }

    @Test("Every shipped record's citing volumes bucket cleanly against the manifest")
    func shippedVolumesAllBucket() throws {
        let index = try #require(CollectionAuthorityStore.shared)
        let manifestURL = try #require(Bundle.main.url(forResource: "manifest",
                                                       withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: manifestURL))
        let byId = Dictionary(uniqueKeysWithValues: entries.map { ($0.volumeId, $0) })

        var resolved = 0
        var charted = 0
        for record in index.collections {
            var midpoints: [Int] = []
            for volumeId in record.volumeIds {
                let entry = try #require(byId[volumeId],
                                         "\(record.name) cites \(volumeId), absent from the manifest")
                let mid = try #require(CollectionRelations.midpointYear(
                    earliest: entry.dateRange.earliest, latest: entry.dateRange.latest),
                    "\(volumeId) has no parseable coverage year")
                midpoints.append(mid)
                resolved += 1
            }
            let buckets = CollectionRelations.citedOverTime(volumeMidpoints: midpoints)
            if !buckets.isEmpty {
                charted += 1
                #expect(buckets.reduce(0) { $0 + $1.volumeCount } == midpoints.count,
                        "\(record.name) lost volumes between the midpoints and the buckets")
            }
        }
        #expect(resolved > 10_000, "guard is vacuous — only \(resolved) memberships bucketed")
        #expect(charted > 100, "guard is vacuous — only \(charted) records reached two eras")
    }

    // MARK: - The generated caption

    @Test("A rise-and-fall shape names all three moments")
    func narrativeNamesEntersPeaksAndFades() {
        let buckets = timeline([(1948, 1), (1951, 3), (1955, 8), (1958, 2)])
        let text = CollectionRelations.timelineNarrative(for: buckets)
        #expect(text.contains("1948–1950"), "the first era is not named: \(text)")
        #expect(text.contains("1955–1957"), "the peak era is not named: \(text)")
        #expect(text.contains("1958–1960"), "the last era is not named: \(text)")
        #expect(text.contains("peaks"))
        #expect(text.contains("fades"))
    }

    @Test("A shape still rising at the end does not claim to fade")
    func narrativeDoesNotInventAFade() {
        let text = CollectionRelations.timelineNarrative(
            for: timeline([(1948, 1), (1951, 3), (1955, 9)]))
        #expect(text.contains("peaks"))
        #expect(!text.contains("fades"), """
            The collection's citations peak in the LAST era shown, so there is nothing after \
            the peak to fade from. Claiming a decline here would describe a chart the reader \
            can see does not decline: \(text)
            """)
        #expect(text.contains("1955–1957"))
    }

    @Test("One volume per era is not a peak")
    func narrativeDoesNotInventAPeak() {
        let text = CollectionRelations.timelineNarrative(
            for: timeline([(1948, 1), (1951, 1), (1955, 1)]))
        #expect(!text.contains("peaks"), "a flat 1-1-1 shape has no peak: \(text)")
        #expect(text.contains("1948–1950"))
        #expect(text.contains("1955–1957"))
    }

    @Test("A plateau is reported as one span, not one arbitrary bar")
    func narrativeSpansAPlateau() {
        // 1958–60 and 1961–63 tie at the maximum, then it falls away.
        let text = CollectionRelations.timelineNarrative(
            for: timeline([(1948, 1), (1958, 6), (1961, 6), (1964, 2)]))
        #expect(text.contains("1958–1963"), """
            Two adjacent eras tie at the peak, so the sentence should span them. Naming just \
            one would pick a winner the data does not have: \(text)
            """)
        #expect(text.contains("fades"))
    }

    @Test("Fewer than two buckets produces no sentence")
    func narrativeIsEmptyWithoutAShape() {
        #expect(CollectionRelations.timelineNarrative(for: []).isEmpty)
        #expect(CollectionRelations.timelineNarrative(for: timeline([(1961, 4)])).isEmpty)
    }

    /// Builds contiguous buckets from `(startYear, count)` pairs, filling the eras between.
    private func timeline(_ points: [(Int, Int)]) -> [CollectionEraCount] {
        var counts: [Int: Int] = [:]
        for (year, count) in points {
            counts[CollectionRelations.eraIndex(forMidpointYear: year), default: 0] += count
        }
        guard let first = counts.keys.min(), let last = counts.keys.max() else { return [] }
        return (first...last).map {
            CollectionEraCount(era: CollectionRelations.coverageEras[$0], volumeCount: counts[$0] ?? 0)
        }
    }
}

// MARK: - CollectionDetailWiringTests

/// That `CollectionDetailView` actually mounts and gates the three #762 sections.
///
/// A SwiftUI `View` cannot be evaluated in this test target, so the section builders above are
/// reachable only through the source. These assertions are deliberately scoped to `body` and
/// to code lines: a section that exists as a `private var` but is never mounted renders
/// nothing, and every earlier audit in this repo that matched anywhere in a file eventually
/// matched a doc comment instead of the control path.
///
/// Version history:
///   1.0 — Session 2026-08-08: #762
@Suite("Collection detail wiring — #762")
struct CollectionDetailWiringTests {

    private static func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "FRUSExplorer/SourceExplorer/CollectionDetailView.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.count > 5_000, "CollectionDetailView.swift is implausibly small")
        return text
    }

    private static func codeLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") && !$0.hasPrefix("*") }
    }

    /// `body`'s `List { … }` contents — the only place a section is actually mounted.
    private static func listBody(_ source: String) throws -> [String] {
        let start = try #require(source.range(of: "var body: some View {"))
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "// MARK: - Overview"))
        return codeLines(String(rest[..<end.lowerBound]))
    }

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // relatedCollectionsSection in a comment
            /// relatedCollectionsSection in prose
            relatedCollectionsSection
            """
        #expect(Self.codeLines(sample) == ["relatedCollectionsSection"])
    }

    @Test("All three new sections are mounted in body, not merely declared")
    func sectionsAreMounted() throws {
        let body = try Self.listBody(try Self.source())
        for section in ["relatedCollectionsSection", "citedOverTimeSection", "dividedAtNARASection"] {
            #expect(body.contains { $0.contains(section) }, """
                \(section) is not referenced inside `body`'s List. A section that exists only \
                as a private var compiles, passes a whole-file `contains` check, and renders \
                nothing (#762).
                """)
        }
    }

    @Test("Related Collections is gated on the record clearing the shared-volume floor")
    func relatedSectionIsGated() throws {
        let body = try Self.listBody(try Self.source())
        #expect(body.contains {
            $0.contains("record.volumeIds.count >= CollectionRelations.minimumSharedVolumes")
        }, """
            The Related Collections section is not gated on the focus record's own volume \
            count, so a one-volume collection shows an empty section rather than none — the \
            case that covers 2,846 of the 4,423 shipped records.
            """)
        #expect(body.contains { $0.contains("if !timeline.isEmpty") },
                "Cited Over Time must not mount with no buckets — the chart would be blank")
    }

    @Test("The related-collections scan runs off the main thread")
    func relatedScanIsOffMain() throws {
        let lines = Self.codeLines(try Self.source())
        guard let start = lines.firstIndex(where: { $0.contains("private func loadRelated()") }) else {
            Issue.record("loadRelated() is gone — the related list has no loader")
            return
        }
        let bodyLines = lines[start..<min(start + 8, lines.count)]
        #expect(bodyLines.contains { $0.contains("Task.detached") }, """
            loadRelated() intersects this record's volume list against all 4,423 shipped \
            records on whatever actor called it. It shares an appear with the SQLite \
            local-stats query; neither should be able to hold a frame.
            """)
    }

    @Test("The citing-volume list is capped with a disclosed expansion")
    func citingVolumesAreCapped() throws {
        let source = try Self.source()
        let start = try #require(source.range(of: "private var citingVolumesSection: some View {"))
        let rest = source[start.upperBound...]
        let end = rest.range(of: "// MARK: -")?.lowerBound ?? rest.endIndex
        let section = Self.codeLines(String(rest[..<end]))
        #expect(section.contains { $0.contains("CollectionRelations.previewRowCap") }, """
            The citing-volume list renders every row again. The widest shipped record cites \
            157 volumes, which buries the three new sections above it.
            """)
        #expect(section.contains { $0.contains("collection.detail.volumes.showAll") }, """
            A cap without a stated total is a silent truncation — the house rule the "Show all \
            N volumes" row exists to satisfy.
            """)
    }
}
