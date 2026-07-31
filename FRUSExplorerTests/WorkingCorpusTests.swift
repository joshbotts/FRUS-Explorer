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
import SwiftData
import Testing

@testable import FRUSExplorer

// MARK: - WorkingCorpusTests

/// The document-grain scope: a fixed set that means the same thing on every device.
@Suite("Working corpus")
struct WorkingCorpusTests {

    private func keys(_ pairs: [(String, String)]) -> [String] {
        pairs.map { "\($0.0)/\($0.1)" }
    }

    @Test("Membership is de-duplicated and sorted, so two captures of one set are equal")
    func membershipIsCanonical() {
        let a = WorkingCorpus(name: "OSP", documentKeys: ["v2/d9", "v1/d1", "v2/d9", "v1/d2"])
        let b = WorkingCorpus(name: "OSP", documentKeys: ["v1/d2", "v2/d9", "v1/d1"])
        #expect(a.documentKeys == b.documentKeys,
                "the same set captured twice must store identically, or two devices holding one corpus disagree byte-for-byte")
        #expect(a.documentCount == 3, "a duplicated key is one document, not two")
    }

    @Test("The volume span is derived, not stored")
    func volumeSpanIsDerived() {
        let corpus = WorkingCorpus(name: "x", documentKeys: keys([("v1", "d1"), ("v1", "d2"), ("v2", "d1")]))
        #expect(corpus.volumeIds == ["v1", "v2"])
    }

    @Test("Provenance is captured, because a corpus is a claim about a moment in the index")
    func provenanceIsCaptured() {
        let corpus = WorkingCorpus(name: "OSP", documentKeys: ["v1/d1"],
                                   sourceQuery: "procurement OR mobilization",
                                   sourceDescription: "Search results",
                                   indexedVolumeCountAtCapture: 40)
        #expect(corpus.sourceQuery == "procurement OR mobilization")
        #expect(corpus.indexedVolumeCountAtCapture == 40,
                "a corpus captured against 40 volumes and one captured against 552 are different evidence")
        #expect(corpus.capturedAt != nil)
    }

    @Test("Membership edits stamp lastModified, which CloudKit's last-writer-wins resolves on")
    @MainActor
    func membershipEditsStampModification() throws {
        let container = try ModelContainer(
            for: WorkingCorpus.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let corpus = WorkingCorpus(name: "x", documentKeys: ["v1/d1"])
        container.mainContext.insert(corpus)
        let backdated = Date(timeIntervalSince1970: 0)

        corpus.lastModified = backdated
        corpus.replaceMembership(["v1/d1", "v1/d2"])
        let afterEdit = try #require(corpus.lastModified)
        #expect(afterEdit.timeIntervalSinceNow > -5)
        #expect(corpus.documentKeys == ["v1/d1", "v1/d2"])

        corpus.lastModified = backdated
        corpus.rename(to: "renamed")
        #expect(try #require(corpus.lastModified).timeIntervalSinceNow > -5)

        // Why the methods exist rather than a `didSet`: measured, an observer on a `@Model` array
        // property fires on NEITHER an in-place append nor a whole reassignment. Assigning the
        // property directly leaves the stamp exactly where it was — which is precisely the silent
        // stale-merge this guards against.
        corpus.lastModified = backdated
        corpus.documentKeys = ["v1/d1", "v1/d2", "v1/d3"]
        #expect(corpus.lastModified == backdated,
                "if a direct assignment ever starts stamping, SwiftData's observer behaviour has changed and this model can be simplified")
        _ = container
    }

    @Test("A membership edit re-canonicalises, so an edited corpus matches a fresh capture")
    func editsAreCanonical() {
        let corpus = WorkingCorpus(name: "x", documentKeys: ["v1/d1"])
        corpus.replaceMembership(["v2/d1", "v1/d1", "v2/d1"])
        #expect(corpus.documentKeys == ["v1/d1", "v2/d1"])
    }

    // MARK: - Resolution

    @Test("Coverage names BOTH numbers — the corpus and what this device can reach")
    func coverageReportsBothNumbers() {
        let corpus = WorkingCorpus(name: "OSP",
                                   documentKeys: keys([("v1", "d1"), ("v1", "d2"), ("v9", "d1")]))
        let resolution = WorkingCorpusResolver(indexedVolumeIds: ["v1"]).resolve(corpus)
        #expect(resolution.indexedCount == 2)
        #expect(resolution.totalCount == 3,
                "the denominator is the CORPUS; a device that reported only what it could reach would make every claim unreproducible")
        #expect(!resolution.isComplete)
        #expect(resolution.missingVolumeIds == ["v9"])
        #expect(resolution.coverageDescription.contains("2"))
        #expect(resolution.coverageDescription.contains("3"))
    }

    @Test("A fully indexed corpus still states both numbers")
    func completeCoverageStillStatesBoth() {
        let corpus = WorkingCorpus(name: "x", documentKeys: keys([("v1", "d1"), ("v1", "d2")]))
        let resolution = WorkingCorpusResolver(indexedVolumeIds: ["v1", "v7"]).resolve(corpus)
        #expect(resolution.isComplete)
        #expect(resolution.missingVolumeIds.isEmpty)
        // "267 of 267" tells a reader the corpus is whole; a bare "267 documents" leaves them
        // wondering whether it was clipped.
        #expect(resolution.coverageDescription.contains("2 of 2"))
    }

    @Test("Nothing indexed resolves to nothing, without losing the corpus size")
    func nothingIndexed() {
        let corpus = WorkingCorpus(name: "x", documentKeys: keys([("v1", "d1"), ("v2", "d1")]))
        let resolution = WorkingCorpusResolver(indexedVolumeIds: []).resolve(corpus)
        #expect(resolution.indexedKeys.isEmpty)
        #expect(resolution.totalCount == 2)
        #expect(resolution.missingVolumeIds == ["v1", "v2"])
    }

    @Test("A malformed key is skipped rather than trapping")
    func malformedKeys() {
        let corpus = WorkingCorpus(name: "x", documentKeys: ["", "v1/d1"])
        let resolution = WorkingCorpusResolver(indexedVolumeIds: ["v1"]).resolve(corpus)
        #expect(resolution.indexedCount == 1)
        #expect(resolution.totalCount == 2, "the stored set is reported as stored, even where a key is unusable")
    }

    // MARK: - Scope composition

    @Test("A working corpus INTERSECTS the project gate rather than replacing it")
    func gateComposesByIntersection() {
        // Both are document-grain constraints the user asked for. Replacing one with the other would
        // silently widen or narrow the search under two scope labels.
        let combined = DocumentScopeGate.combine(corpus: ["v1/d1", "v1/d2", "v2/d1"],
                                                 projectGate: ["v1/d2", "v2/d1", "v3/d9"])
        #expect(combined == ["v1/d2", "v2/d1"])
        #expect(combined?.contains("v1/d1") == false,
                "`v1/d1` is in the corpus but NOT in the project gate — a composition that returns the corpus would keep it, and the user would be searching outside a scope they applied")
        #expect(combined?.contains("v3/d9") == false,
                "`v3/d9` is in the gate but not the corpus — returning the gate would be the same failure the other way round")
    }

    @Test("With no project gate the corpus stands alone; with no corpus the gate is untouched")
    func gatePassesThroughWhenOnlyOneIsPresent() {
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: ["v1/d1"]) == ["v1/d1"])
        #expect(DocumentScopeGate.combine(corpus: ["v9/d9"], projectGate: nil) == ["v9/d9"])
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: nil) == nil,
                "no constraint at all must stay nil, or every unscoped search would match nothing")
    }

    @Test("A disjoint corpus and gate match NOTHING, never the whole corpus")
    func disjointGatesMatchNothing() {
        // The empty array is the "match nothing" contract IndexingPipeline honours. Degrading to
        // `nil` here would search the entire corpus while two scope labels are on screen — the
        // worst possible answer, because it looks like a result.
        let gate = DocumentScopeGate.combine(corpus: ["v1/d1"], projectGate: ["v2/d2"])
        #expect(gate == [])
        #expect(gate != nil)
    }

    @Test("The composition is order-independent and canonical")
    func compositionIsCanonical() {
        let a = DocumentScopeGate.combine(corpus: ["v2/d1", "v1/d1"], projectGate: ["v1/d1", "v2/d1"])
        let b = DocumentScopeGate.combine(corpus: ["v1/d1", "v2/d1"], projectGate: ["v2/d1", "v1/d1"])
        #expect(a == b)
        #expect(a == ["v1/d1", "v2/d1"], "sorted, so a gate cannot reorder between renders")
    }

    // MARK: - Persistence

    @Test("It round-trips through SwiftData with its provenance intact")
    @MainActor
    func persists() throws {
        let container = try ModelContainer(
            for: WorkingCorpus.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        context.insert(WorkingCorpus(name: "OSP", documentKeys: ["v1/d2", "v1/d1"],
                                     sourceQuery: "procurement", sourceDescription: "Search results",
                                     indexedVolumeCountAtCapture: 40))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WorkingCorpus>())
        #expect(fetched.count == 1)
        let corpus = try #require(fetched.first)
        #expect(corpus.documentKeys == ["v1/d1", "v1/d2"])
        #expect(corpus.sourceQuery == "procurement")
        #expect(corpus.indexedVolumeCountAtCapture == 40)
        // The container must outlive this scope: ModelContext holds it weakly, and dropping it
        // here would SIGTRAP the test host.
        _ = container
    }

}

// MARK: - WorkingCorpusPlatformParityTests

/// That an applied corpus reaches the **search**, on both platforms.
///
/// The seeding run found it did not on macOS. Two independent breaks, either alone enough:
/// `MacSearchViewModel.scopeDerivedParams` never consulted the corpus, and
/// `advancedFilterSignature` — which is what tells the Mac its filter view model changed — did not
/// mention it, so nothing re-applied even once the composition existed.
///
/// `WorkingCorpusTests` covered the composition rule in isolation and passed throughout, because the
/// rule was right and simply was not called. The two search surfaces share no code, and this repo
/// already records that as a standing hazard; a rule tested only in isolation cannot see it.
///
/// Source-text checks, because `MacSearchViewModel` needs a live `SearchService` and a container to
/// instantiate. They are weak on their own, so each carries a floor.
///
/// Version history:
///   1.0 — M-1 seeding follow-up: initial implementation
@Suite("Working corpus platform parity")
struct WorkingCorpusPlatformParityTests {

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
        #expect(text.count > 1_000, "\(relativePath) is implausibly small — did it move?")
        return text
    }

    @Test("Both search paths compose the corpus into the document gate")
    func bothPathsCompose() throws {
        let ios = try source("FRUSExplorer/Search/SearchViewModel.swift")
        let mac = try source("FRUSExplorer/App/MacSearchViewModel.swift")
        for (name, text) in [("iOS", ios), ("macOS", mac)] {
            #expect(text.contains("DocumentScopeGate.combine"),
                    "\(name) builds its own SearchParameters and must compose the corpus itself — the two surfaces share no code")
            #expect(text.contains("appliedWorkingCorpusKeys"),
                    "\(name) never reads the applied corpus")
        }
    }

    @Test("The macOS filter signature carries the corpus, or nothing re-applies")
    func macSignatureCarriesTheCorpus() throws {
        let vm = try source("FRUSExplorer/Search/SearchViewModel.swift")
        let start = try #require(vm.range(of: "var advancedFilterSignature"))
        let rest = vm[start.upperBound...]
        let end = try #require(rest.range(of: "\n    }"), "no closing brace for advancedFilterSignature")
        let body = String(vm[start.lowerBound..<end.upperBound])
        #expect(body.count < 2_500, "the extracted window is too large to be one computed property")
        #expect(body.contains("parts.append"), "sanity: this really is the signature body")
        // The Mac copies filter state into `parameters` only when this string changes. Applying or
        // clearing a corpus without touching it left the corpus set, shown as applied, and ignored.
        #expect(body.contains("appliedWorkingCorpusName") || body.contains("appliedWorkingCorpusKeys"),
                "applying a working corpus must change the signature that triggers applyAdvancedFilters")

    }

    @Test("The corpus is applied through the shared rule, never re-implemented")
    func compositionIsNotDuplicated() throws {
        let mac = try source("FRUSExplorer/App/MacSearchViewModel.swift")
        // Two hand-rolled intersections would drift, and the empty-vs-nil contract is exactly the
        // detail that would drift first.
        #expect(!mac.contains(".intersection("),
                "macOS should call DocumentScopeGate.combine rather than intersect by hand")
    }
}
