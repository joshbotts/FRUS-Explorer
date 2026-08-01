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

// MARK: - WorkingCorpusVisibilityTests

/// A working corpus gates every row of a search. These pin that it says so.
///
/// The defects here share a cause: a corpus is applied through its own field rather than through
/// the volume-checkbox field a custom volume scope writes, so it inherited none of the filter
/// vocabulary that field carries for free — not the active-filter glyph, not Clear Filters, not
/// the macOS chip label, and no banner at all.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Working corpus visibility")
struct WorkingCorpusVisibilityTests {

    /// A view model over a throwaway empty index. These tests exercise filter *state*, which
    /// needs no documents — but `SearchViewModel` requires a service, so one is stood up.
    @MainActor
    private func viewModel() throws -> (SearchViewModel, cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCorpusVis-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("vis.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        let vm = SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline))
        return (vm, { try? FileManager.default.removeItem(at: dir) })
    }

    // MARK: - The filter vocabulary

    @Test("An applied corpus counts as an active filter")
    @MainActor
    func corpusIsAnActiveFilter() throws {
        let (vm, cleanup) = try viewModel()
        defer { cleanup() }
        #expect(!vm.hasActiveFilters, "a fresh view model must report no filters")
        vm.appliedWorkingCorpusKeys = ["v1/d1"]
        vm.appliedWorkingCorpusName = "minerals"
        #expect(vm.hasActiveFilters,
                "the filter glyph read 'no filters' while a corpus gated every row")
    }

    @Test("Clear Filters clears the corpus")
    @MainActor
    func clearFiltersClearsTheCorpus() throws {
        let (vm, cleanup) = try viewModel()
        defer { cleanup() }
        vm.appliedWorkingCorpusKeys = ["v1/d1"]
        vm.appliedWorkingCorpusName = "minerals"
        vm.clearFilters()
        #expect(vm.appliedWorkingCorpusKeys == nil)
        #expect(vm.appliedWorkingCorpusName == nil)
        #expect(!vm.hasActiveFilters)
    }

    /// The empty array is not the empty set. `IndexingPipeline` reads an empty `documentIds` as
    /// "match nothing" and `nil` as "no constraint", so clearing must produce `nil` — an empty
    /// array left behind would silently return no results forever.
    @Test("Clearing produces nil, never an empty array")
    @MainActor
    func clearingProducesNil() throws {
        let (vm, cleanup) = try viewModel()
        defer { cleanup() }
        vm.appliedWorkingCorpusKeys = []
        vm.clearWorkingCorpus()
        #expect(vm.appliedWorkingCorpusKeys == nil)
    }

    // MARK: - The provenance that was written and never read

    /// `captureProvenanceDescription` is stored on every capture. Until now nothing rendered it,
    /// so the truncation was recorded correctly and shown to nobody.
    @Test("A truncated capture's description is rendered where a corpus is chosen")
    func provenanceIsRenderable() {
        let truncated = ResultSetScope(loaded: 1_000, shown: 1_000, fetchLimit: 1_000,
                                       totalMatchCount: 195_519, documentsOnPage: 25, pageCount: 40)
        let description = truncated.captureProvenanceDescription
        #expect(description.contains("highest-scoring"))
        // Two surfaces read `sourceDescription` now — the Settings row and the filter-sheet apply
        // row. This pins the value they read is worth rendering, not that they render it; the
        // source audit below pins the call sites.
        #expect(description != "Search results")
    }

    // MARK: - Grouped digits

    /// `%lld` never groups, so a truncated capture read "the highest-scoring 7500 of 195519
    /// matches". The tell was this file's sibling test hedging `"1000" || "1,000"`.
    @Test("Large counts in user-facing sentences carry thousands separators")
    func countsAreGrouped() {
        let scope = ResultSetScope(loaded: 7_500, shown: 7_500, fetchLimit: 7_500,
                                   totalMatchCount: 195_519, documentsOnPage: 25, pageCount: 300)
        let expectedLoaded = 7_500.formatted()
        let expectedTotal = 195_519.formatted()
        #expect(scope.captureProvenanceDescription.contains(expectedLoaded))
        #expect(scope.captureProvenanceDescription.contains(expectedTotal))
        #expect(scope.headerDescription.contains(expectedLoaded))
        #expect(scope.headerDescription.contains(expectedTotal))

        // Anti-vacuity: in a locale that groups, the grouped form must actually differ from the
        // bare digits — otherwise every assertion above passes without the fix.
        if expectedTotal != "195519" {
            #expect(!scope.headerDescription.contains("195519"))
        }
    }
}

// MARK: - WorkingCorpusSurfaceAuditTests

/// Source audits for the render sites, which no runtime test can reach.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Working corpus surfaces")
struct WorkingCorpusSurfaceAuditTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    @Test("Both places a corpus is chosen render its provenance")
    func provenanceIsRendered() throws {
        let settings = try Self.source("FRUSExplorer/Settings/WorkingCorporaView.swift")
        #expect(settings.contains("corpus.sourceDescription"),
                "the Settings row omitted the one field that says what the set IS")
        let filter = try Self.source("FRUSExplorer/Search/SearchFilterView.swift")
        #expect(filter.contains("corpus.sourceDescription"),
                "the apply row is the moment the truncation has to be legible")
    }

    /// Both platforms, because #606 shipped this on one and the omission was invisible until the
    /// owner went looking for a banner the Mac never had.
    @Test("macOS names the corpus too, from the same shared string")
    func macOSBannerExists() throws {
        let sheet = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        #expect(sheet.contains("private var workingCorpusBanner"))
        // Mounted, not merely declared.
        #expect(sheet.contains("WorkingOnBanner()\n            workingCorpusBanner"),
                "the banner must be mounted above the results, beside its sibling")
        // The same localized key iOS uses — two spellings of one fact would drift.
        #expect(sheet.contains("search.corpusScope.label %@"))
    }

    @Test("The results screen names the corpus it is searching inside")
    func bannerExists() throws {
        let view = try Self.source("FRUSExplorer/Search/SearchView.swift")
        #expect(view.contains("private var workingCorpusBanner"))
        // Mounted, not merely declared — the defect being fixed is a property that existed and
        // was rendered nowhere, which is exactly what an unmounted banner would reproduce.
        #expect(view.contains("workingCorpusBanner\n                        volumeScopeBanner"),
                "the banner must be mounted beside its sibling in the safe-area stack")
    }

    /// `documentIds` has two producers — a corpus and a project History gate, intersected by
    /// `DocumentScopeGate` — so a fixed label named the wrong scope whenever a corpus was the source.
    @Test("The macOS chip distinguishes a corpus from a project gate")
    func macChipNamesTheScope() throws {
        let mac = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")
        #expect(mac.contains("case (true, false): parts.append(\"corpus\")"))
        #expect(mac.contains("case (true, true):  parts.append(\"corpus + project\")"))
    }
}
