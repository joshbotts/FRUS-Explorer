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

// MARK: - TrailRecordedCountTests

/// What a trail entry's count actually asserts.
///
/// M-2's purpose is an appendix "of every query with its real hit count, including the zeros —
/// that is what makes a claim of absence checkable". A single `Int` cannot carry that: it cannot
/// distinguish a measured total from a fetch ceiling, nor either from a row written before the
/// app recorded the difference. `RecordedCount` is the four states, and these pin them.
///
/// Version history:
///   1.0 — M-2 commit 2: initial implementation
@Suite("Trail recorded count")
struct TrailRecordedCountTests {

    private func entry(reported: Int, loaded: Int? = nil, match: Int? = nil,
                       limit: Int? = nil) -> SearchHistoryEntry {
        SearchHistoryEntry(queryText: "détente", resultCount: reported,
                           loadedCount: loaded, matchCount: match, fetchLimit: limit)
    }

    // MARK: - The four states

    @Test("A row written before M-2 is unrecorded, not complete")
    func legacyRowIsUnrecorded() {
        // The whole population that existed before this build. Collapsing it into any other state
        // would assert something about those rows that was never measured.
        #expect(entry(reported: 1_000).recordedCount == .unrecorded(reported: 1_000))
    }

    @Test("A real total is exact")
    func realTotalIsExact() {
        let e = entry(reported: 195_519, loaded: 1_000, match: 195_519, limit: 1_000)
        #expect(e.recordedCount == .exact(match: 195_519, loaded: 1_000))
    }

    @Test("A failed count on a capped fetch is a floor, not a total")
    func cappedWithoutTotalIsFloor() {
        // The case that motivated the whole design: 1,000 here means "at least 1,000".
        let e = entry(reported: 1_000, loaded: 1_000, match: nil, limit: 1_000)
        #expect(e.recordedCount == .floor(loaded: 1_000, fetchLimit: 1_000))
    }

    @Test("A failed count on an uncapped fetch is still complete")
    func uncappedWithoutTotalIsComplete() {
        // 412 of a 1,000 ceiling: the fetch saw everything, so the absence of a COUNT costs
        // nothing. Reporting this as a floor would understate a complete answer.
        let e = entry(reported: 412, loaded: 412, match: nil, limit: 1_000)
        #expect(e.recordedCount == .completeWithoutTotal(loaded: 412))
    }

    /// A zero is the deliverable, not an edge case.
    @Test("A recorded zero survives as a complete answer")
    func zeroIsEvidence() {
        let e = entry(reported: 0, loaded: 0, match: 0, limit: 1_000)
        #expect(e.recordedCount == .exact(match: 0, loaded: 0))
        #expect(!e.isPartialEvidence(), "a zero under a stated scope is a finding, not a gap")
    }

    // MARK: - Partial evidence

    @Test("A floor is partial evidence; an exact count is not")
    func partialEvidence() {
        #expect(entry(reported: 1_000, loaded: 1_000, limit: 1_000).isPartialEvidence())
        #expect(!entry(reported: 412, loaded: 412, match: 412, limit: 1_000).isPartialEvidence())
    }

    /// The entry alone cannot know this — the corpus it ran inside may itself have been a capped
    /// capture, which is why the truncation arrives as a parameter.
    @Test("A search inside a truncated corpus is partial however exact its own count")
    func truncatedCorpusMakesItPartial() {
        let exact = entry(reported: 267, loaded: 267, match: 267, limit: 1_000)
        #expect(!exact.isPartialEvidence())
        #expect(exact.isPartialEvidence(corpusTruncation: .truncated(total: 195_519)))
        // `unrecorded` must stay silent, as everywhere else in the wave.
        #expect(!exact.isPartialEvidence(corpusTruncation: .unrecorded))
        #expect(!exact.isPartialEvidence(corpusTruncation: .complete))
    }

    // MARK: - Anti-vacuity

    /// `fetchLimit` is the legacy discriminator, so it must be the thing that decides — not a
    /// coincidence of the other fields.
    @Test("fetchLimit alone separates a legacy row from a recorded one")
    func fetchLimitIsTheDiscriminator() {
        // Same numbers, differing only in whether the ceiling was recorded.
        let legacy = entry(reported: 412, loaded: 412, match: 412, limit: nil)
        let recorded = entry(reported: 412, loaded: 412, match: 412, limit: 1_000)
        #expect(legacy.recordedCount == .unrecorded(reported: 412))
        #expect(recorded.recordedCount == .exact(match: 412, loaded: 412))
    }
}

// MARK: - ScopeSignatureTests

/// The key that makes two searches comparable across devices.
///
/// Version history:
///   1.0 — M-2 commit 2: initial implementation
@Suite("Search scope signature")
struct ScopeSignatureTests {

    private func params(_ mutate: (inout SearchParameters) -> Void = { _ in }) -> SearchParameters {
        var p = SearchParameters(keywords: "détente")
        mutate(&p)
        return p
    }

    @Test("The same scope always produces the same key")
    func deterministic() {
        let a = SearchScopeSignature.signature(for: params { $0.volumeIds = ["v3", "v1", "v2"] })
        let b = SearchScopeSignature.signature(for: params { $0.volumeIds = ["v1", "v2", "v3"] })
        #expect(a == b, "member ORDER carries no scope meaning and must not change the key")
    }

    /// The property the de-duplication depends on. A count alone would collapse these, and the
    /// trail would treat a re-run under a different scope as a duplicate — the hole M-2 closes.
    @Test("Two different scopes of the same size produce different keys")
    func injectiveOnMembers() {
        let a = SearchScopeSignature.signature(for: params { $0.volumeIds = ["v1", "v2"] })
        let b = SearchScopeSignature.signature(for: params { $0.volumeIds = ["v3", "v4"] })
        #expect(a != b)
    }

    /// `IndexingPipeline` reads an empty `documentIds` as "match nothing" and `nil` as "no
    /// constraint". Those are opposite scopes and must never share a token.
    @Test("An empty id list is not the same scope as no id list")
    func emptyIsNotAbsent() {
        let none = SearchScopeSignature.signature(for: params { $0.documentIds = nil })
        let empty = SearchScopeSignature.signature(for: params { $0.documentIds = [] })
        #expect(none != empty)
    }

    @Test("Changing any one dimension changes the key")
    func everyDimensionCounts() {
        let base = SearchScopeSignature.signature(for: params())
        #expect(SearchScopeSignature.signature(for: params { $0.includeNotes = false }) != base)
        #expect(SearchScopeSignature.signature(for: params { $0.includeFrontMatter = false }) != base)
        #expect(SearchScopeSignature.signature(for: params { $0.documentTypeFilter = .documentsOnly }) != base)
        #expect(SearchScopeSignature.signature(for: params { $0.userTagIds = ["t1"] }) != base)
        #expect(SearchScopeSignature.signature(for: params { $0.personRollupId = 8_812 }) != base)
        #expect(SearchScopeSignature.signature(for: params { $0.booleanMode = .or }) != base)
    }

    /// The keyword is NOT part of the scope — the trail pairs the signature with `queryText`, and
    /// folding the query in would make every new query look like a new scope.
    @Test("The query text is not part of the scope")
    func queryIsNotScope() {
        let a = SearchScopeSignature.signature(for: params())
        var other = params(); other.keywords = "wheat"
        #expect(SearchScopeSignature.signature(for: other) == a)
    }

    @Test("The key carries no localized text")
    func localeFree() {
        let key = SearchScopeSignature.signature(for: params {
            $0.documentTypeFilter = .editorialNotesOnly
            $0.dateRange = DateRange(earliest: "1949-01-01", latest: "1952-12-31")
        })
        #expect(key.contains("type=editorial"))
        #expect(key.contains("1949-01-01..1952-12-31"))
        // A localized rendering would put a space or a word separator in; the key is machine-shaped.
        #expect(!key.contains(" "))
    }
}
