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

// MARK: - CollocationWiringAuditTests

/// Source-text audit of how collocation is wired into the two search hosts.
///
/// `CollocationTests` exercises the engine directly, which is right — and means it cannot see the
/// call sites at all. S-1 established that this gap is real rather than theoretical: inverting
/// `includeDiplomatic` in a view was invisible to all fourteen of that session's unit cases. This
/// feature has **two** such call sites, on two hosts that share no code.
///
/// Reading source is a weak tool — it sees text, not behaviour — so each check carries an
/// anti-vacuity floor and the file paths are asserted to exist.
///
/// Version history:
///   1.0 — S-2: initial implementation
@Suite("Collocation wiring audit")
struct CollocationWiringAuditTests {

    private static let iOSHost = "FRUSExplorer/Search/SearchView.swift"
    private static let macHost = "FRUSExplorer/App/SearchSheet.swift"

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
        #expect(text.count > 1_000, "\(relativePath) is implausibly small — did it move?")
        return text
    }

    /// Both hosts, so a check can never pass by only being true on one platform.
    private func bothHosts() throws -> [(name: String, text: String)] {
        [(Self.iOSHost, try source(Self.iOSHost)), (Self.macHost, try source(Self.macHost))]
    }

    /// One function's text, bounded at its closing brace — not a character window.
    ///
    /// A `contains` over the whole file passes on any other call site that happens to use the same
    /// symbol, which is how the first version of the executed-query check went vacuous: the
    /// concordance uses `submittedSearchParameters` too.
    private func functionBody(named header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) not found")
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n    }"), "no closing brace for \(header)")
        return String(source[start.lowerBound..<end.upperBound])
    }

    @Test("Both hosts resolve the tokenisation ONCE and hand the same values to the guard")
    func configurationIsResolvedOnce() throws {
        for host in try bothHosts() {
            // The guard validates what a caller CLAIMS, not what its tokenizer was built with.
            // `CollocationConfiguration.live()` is the single resolution; reading the settings again
            // for the baseline call is how the two silently diverge.
            #expect(host.text.contains("CollocationConfiguration.live()"),
                    "\(host.name) must resolve the live tokenisation through the shared type")
            #expect(host.text.contains("tuning: configuration.tuning"),
                    "\(host.name) must give the guard the SAME tuning the tokenizer was built with")
            #expect(host.text.contains("includeDiplomatic: configuration.includeDiplomatic"),
                    "\(host.name) must give the guard the SAME boilerplate setting")
            #expect(!host.text.contains("includeDiplomatic: !configuration.includeDiplomatic"),
                    "includeDiplomatic is NOT the inverse of excludeBoilerplate in this codebase")
        }
    }

    @Test("Both hosts collocate the whole retained set, never the page")
    func scansTheRetainedSet() throws {
        let ios = try source(Self.iOSHost)
        let mac = try source(Self.macHost)
        // A page yields ~400 window tokens across ~290 lemmas against a floor of 3, so a
        // page-scoped collocation is empty for most queries — the panel would read as broken.
        #expect(ios.contains("let results = vm.displayedResults"))
        #expect(mac.contains("let results = searchVM.displayedResults"))
        for host in try bothHosts() {
            #expect(!host.text.contains("for: pagedResults"),
                    "\(host.name) is collocating a page")
            let rebuild = try functionBody(named: "func rebuildCollocation", in: host.text)
            #expect(rebuild.contains("submittedSearchParameters"),
                    "\(host.name) must anchor the collocation on the EXECUTED query, not the live search field")
            #expect(!rebuild.contains("parameters: vm.searchParameters"),
                    "\(host.name) is collocating whatever is typed in the field, not what ran")
        }
    }

    @Test("The rebuild key carries the window and NOT the page")
    func rebuildKeyIsCorrect() throws {
        for host in try bothHosts() {
            #expect(host.text.contains("CollocationRebuildKey(mode: showCollocates, window: collocationWindow"),
                    "\(host.name): the window changes the answer and must trigger a rebuild")
            // Paging changes nothing about a whole-set measure; keying on it would rescan thousands
            // of documents to produce the identical ranking.
            let key = try #require(host.text.range(of: "CollocationRebuildKey(mode:"))
            let call = String(host.text[key.lowerBound...].prefix(200))
            #expect(!call.contains("currentPage"),
                    "\(host.name): a collocation must not rebuild on page turn")
        }
    }

    @Test("The three view modes are mutually exclusive on both hosts")
    func modesAreMutuallyExclusive() throws {
        // Three booleans rather than one enum, matching what was already here. That only stays
        // correct if EVERY toggle clears the other two — the shape that produced the empty-menu
        // defect recorded in AnalyticsView.
        for host in try bothHosts() {
            #expect(host.text.contains("if showTimeline { showConcordance = false; showCollocates = false }"),
                    "\(host.name): the timeline toggle must clear both other modes")
            #expect(host.text.contains("if showConcordance { showTimeline = false; showCollocates = false }"),
                    "\(host.name): the concordance toggle must clear both other modes")
            #expect(host.text.contains("if showCollocates { showTimeline = false; showConcordance = false }"),
                    "\(host.name): the collocates toggle must clear both other modes")
        }
    }

    @Test("Both hosts await the reference before reading it")
    func referenceIsPrepared() throws {
        for host in try bothHosts() {
            // Without this a read taken before the launch decode lands verdicts `.noArtifact` — a
            // claim of a missing bundle resource, when the truth is "not yet".
            #expect(host.text.contains("await BundledKeynessBaseline.prepare()"),
                    "\(host.name) must await the reference")
        }
    }

    @Test("Neither host leaves a loading state unread")
    func loadingStatesAreRendered() throws {
        for host in try bothHosts() {
            // macOS had `rebuildConcordance` setting nothing at all, so a slow rebuild looked
            // frozen. A state that is set and never read is worse than none: it reads as handled.
            #expect(host.text.contains("if isLoadingConcordance { ProgressView() }"),
                    "\(host.name): isLoadingConcordance is set but never rendered")
            #expect(host.text.contains("isLoading: isLoadingCollocation"),
                    "\(host.name): isLoadingCollocation is set but never rendered")
        }
    }

    @Test("Cancellation is never rendered as a claim about the query")
    func cancellationIsNotAResult() throws {
        for host in try bothHosts() {
            #expect(host.text.contains("catch is CancellationError"),
                    "\(host.name): a cancelled scan must not write a verdict — switching modes or re-searching cancels one, and `.noMatches` is a specific false claim")
            #expect(!host.text.contains("?? .unavailable(.noMatches)"),
                    "\(host.name): `try?` folds cancellation into a result")
        }
    }

    @Test("iOS bumps its search version AFTER the results land")
    func versionBumpFollowsTheResults() throws {
        let vm = try source("FRUSExplorer/Search/SearchViewModel.swift")
        let body = try #require(vm.range(of: "results = try await searchService.search"))
        let after = String(vm[body.lowerBound...].prefix(1_400))
        // Bumped in the synchronous prefix, every `.task(id:)` keyed on it fires during the await —
        // against the PREVIOUS query's results, and never again.
        #expect(after.contains("executedSearchVersion &+= 1"),
                "the version must be bumped after `results` is replaced, matching MacSearchViewModel")
        let before = String(vm[..<body.lowerBound].suffix(600))
        #expect(!before.contains("executedSearchVersion &+= 1"),
                "a bump before the await makes the key fire against the previous result set")
    }

    @Test("The scan budget is on tokens and scales with the window")
    func matchBudgetIsPinned() {
        #expect(SearchService.collocationTokenBudget == 200_000)
        // A fixed MATCH budget calibrated at ±10 would let ±50 — offered by the picker — cost five
        // times its measurement.
        let atTen = SearchService.collocationMatchBudget(windowSize: 10)
        let atFifty = SearchService.collocationMatchBudget(windowSize: 50)
        #expect(atTen > atFifty)
        #expect(atTen / atFifty >= 4, "the budget must fall roughly in proportion to the window")
        #expect(SearchService.collocationChunkSize == 400,
                "400 pairs is 800 binds, under SQLite's 999-variable limit")
    }
}
