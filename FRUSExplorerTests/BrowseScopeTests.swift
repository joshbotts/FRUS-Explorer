// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - BrowseScopeTests

/// Pure-logic tests for the custom-scopes browse axis (#1051 B-3, A-5): the Q-3
/// live-reference filter states (never a silent whole-corpus fallback — the #258 rule),
/// the hierarchy restriction, the R-1 drill spec, and the membership mutations whose
/// no-op and reassignment contracts the 3b menu relies on.
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
///   1.1 — #1364: the corpus root's Subseries tile caption under each filter state, Browse Within
///          This Scope's action (narrow, then open the list it narrows), and three tests that only
///          the iOS mount offers it — a scan of every mount's call, its closures included; the
///          property's default, run; and a sweep of the view for any path to the filter the action
///          does not guard
@MainActor
struct BrowseScopeTests {

    // MARK: Fixtures

    private func scope(name: String = "Cold War Berlin",
                       volumeIds: [String] = []) -> CustomVolumeScope {
        CustomVolumeScope(name: name, volumeIds: volumeIds)
    }

    private func entry(id: String, subseries: String = "1969-76") -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: subseries,
            title: "Fixture \(id)",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2000", status: .published,
            editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: []
        )
    }

    // MARK: Filter states

    @Test func nilFilterIdIsInactive() {
        #expect(ScopeAxis.filterState(filterId: nil, scopes: [scope()], manifestIds: ["a"])
                == .inactive)
    }

    @Test func danglingIdIsUnavailable_neverWholeCorpus() {
        // A scope deleted on another device: the state is EXPLICIT, and the hierarchy
        // helpers below turn it into nothing — not into an unfiltered corpus under the
        // scope's name.
        let state = ScopeAxis.filterState(filterId: UUID(), scopes: [scope()], manifestIds: ["a"])
        #expect(state == .unavailable)
        #expect(ScopeAxis.scopedGroups([SubseriesGroup(subseries: "1969-76",
                                                       volumes: [entry(id: "a")])],
                                       state: state).isEmpty)
    }

    @Test func activeStateIntersectsMembershipWithTheManifest() {
        let s = scope(volumeIds: ["frus-a", "frus-ghost"])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s],
                                          manifestIds: ["frus-a", "frus-b"])
        #expect(state == .active(name: "Cold War Berlin", allowed: ["frus-a"]))
    }

    @Test func emptyMembershipIsItsOwnExplicitState() {
        let s = scope(volumeIds: [])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s], manifestIds: ["frus-a"])
        #expect(state == .empty(name: "Cold War Berlin"))
    }

    @Test func membershipOfOnlyUnresolvableIdsIsEmptyToo() {
        let s = scope(volumeIds: ["frus-ghost"])
        let state = ScopeAxis.filterState(filterId: s.id, scopes: [s], manifestIds: ["frus-a"])
        #expect(state == .empty(name: "Cold War Berlin"))
    }

    // MARK: Hierarchy restriction

    @Test func scopedGroupsRestrictAndDropEmptied() {
        let groups = [
            SubseriesGroup(subseries: "1969-76", volumes: [entry(id: "frus-a"), entry(id: "frus-b")]),
            SubseriesGroup(subseries: "1861", volumes: [entry(id: "frus-c")]),
        ]
        let scoped = ScopeAxis.scopedGroups(groups,
                                            state: .active(name: "x", allowed: ["frus-b"]))
        #expect(scoped.count == 1)
        #expect(scoped[0].subseries == "1969-76")
        #expect(scoped[0].volumes.map(\.volumeId) == ["frus-b"])
    }

    @Test func inactiveStatePassesGroupsThrough() {
        let groups = [SubseriesGroup(subseries: "1861", volumes: [entry(id: "frus-c")])]
        #expect(ScopeAxis.scopedGroups(groups, state: .inactive).count == 1)
        #expect(ScopeAxis.scopedVolumes([entry(id: "frus-c")], state: .inactive).count == 1)
    }

    @Test func emptyAndUnavailableFilterToNothing() {
        let volumes = [entry(id: "frus-a")]
        #expect(ScopeAxis.scopedVolumes(volumes, state: .empty(name: "x")).isEmpty)
        #expect(ScopeAxis.scopedVolumes(volumes, state: .unavailable).isEmpty)
    }

    // MARK: The drill spec

    @Test func specResolvesInScopeOrderAndDisclosesTheUnresolvable() throws {
        let s = scope(volumeIds: ["frus-b", "frus-a", "frus-ghost"])
        // CustomVolumeScope sorts membership on init, so the scope's own order is sorted;
        // the spec must keep IT (frus-a, frus-b, frus-ghost minus the ghost).
        let spec = ScopeAxis.spec(for: s, manifestIds: ["frus-a", "frus-b"])
        #expect(spec.volumeIds == ["frus-a", "frus-b"])
        #expect(spec.axisKey == "scope:\(s.id.uuidString)")
        let caption = try #require(spec.caption)
        #expect(caption.contains("2 volumes"))
        #expect(caption.contains("catalogue: 1"))
    }

    @Test func untitledScopesGetThePlaceholderName() {
        let s = scope(name: "", volumeIds: ["frus-a"])
        let name = ScopeAxis.displayName(s)
        #expect(!name.isEmpty)
        #expect(ScopeAxis.spec(for: s, manifestIds: ["frus-a"]).title == name)
    }

    // MARK: Membership mutation (the 3b contracts)

    @Test func addIsSortedReassignmentAndTouchesLastModified() {
        let s = scope(volumeIds: ["frus-b"])
        #expect(ScopeAxis.add("frus-a", to: s))
        #expect(s.volumeIds == ["frus-a", "frus-b"])
        #expect(s.lastModified != nil)
    }

    @Test func addingAnExistingMemberIsANoOp_lastModifiedUntouched() {
        let s = scope(volumeIds: ["frus-a"])
        let before = s.lastModified
        #expect(!ScopeAxis.add("frus-a", to: s))
        #expect(s.volumeIds == ["frus-a"])
        #expect(s.lastModified == before)
    }

    @Test func removeFiltersAndNoOpsForNonMembers() {
        let s = scope(volumeIds: ["frus-a", "frus-b"])
        #expect(ScopeAxis.remove("frus-a", from: s))
        #expect(s.volumeIds == ["frus-b"])
        #expect(!ScopeAxis.remove("frus-ghost", from: s))
        #expect(s.volumeIds == ["frus-b"])
    }

    // MARK: Persistence (the #862 class, at unit grain)

    @Test func createInsertsIntoTheContextAndSurvivesAFetch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CustomVolumeScope.self, configurations: config)
        let context = ModelContext(container)
        let created = ScopeAxis.create(named: "Captured", volumeIds: ["frus-a"], in: context)
        // The #862 lesson at this grain: the model must BELONG to a context after create —
        // a save that had nothing to write is how work vanishes silently.
        #expect(created.modelContext != nil)
        let fetched = try context.fetch(FetchDescriptor<CustomVolumeScope>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Captured")
        #expect(fetched.first?.volumeIds == ["frus-a"])
    }

    // MARK: The corpus root's Subseries tile (#1364)

    /// Four volumes over three eras, 1861–1969; `frus-b` and `frus-c` alone span 1917–1969, so a
    /// caption that counted or spanned the whole list under a filter cannot pass for the scope's.
    private var tileVolumes: [VolumeManifestEntry] {
        [entry(id: "frus-a", subseries: "1861"),
         entry(id: "frus-b", subseries: "1917"),
         entry(id: "frus-c", subseries: "1969-76"),
         entry(id: "frus-d", subseries: "1969-76")]
    }

    @Test func tileCaptionCountsTheWholeSeriesWhenNothingNarrowsIt() {
        #expect(ScopeAxis.subseriesTileCaption(volumes: tileVolumes, state: .inactive)
                == "4 volumes by era, 1861–1969")
    }

    @Test func tileCaptionForOneEraHasNoSpan() {
        let oneEra = [entry(id: "frus-c"), entry(id: "frus-d")]
        #expect(ScopeAxis.subseriesTileCaption(volumes: oneEra, state: .inactive)
                == "2 volumes by era")
    }

    @Test func tileCaptionNamesTheScopeAndCountsAndSpansOnlyItsVolumes() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-b", "frus-c"]))
        #expect(caption == "Browsing within: Cold War Berlin · 2 volumes by era, 1917–1969")
    }

    @Test func tileCaptionForAOneEraScopeHasNoSpan() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-c", "frus-d"]))
        #expect(caption == "Browsing within: Cold War Berlin · 2 volumes by era")
    }

    @Test func tileCaptionForAOneVolumeScopeIsSingular() {
        let caption = ScopeAxis.subseriesTileCaption(
            volumes: tileVolumes,
            state: .active(name: "Cold War Berlin", allowed: ["frus-c"]))
        #expect(caption == "Browsing within: Cold War Berlin · 1 volume")
    }

    @Test func tileCaptionForAnEmptyScopeSaysItHasNothingToShow() {
        // The list below shows nothing; the tile must not count the series over it (#258).
        let caption = ScopeAxis.subseriesTileCaption(volumes: tileVolumes,
                                                     state: .empty(name: "Cold War Berlin"))
        #expect(caption == "Browsing within: Cold War Berlin · no volumes this device’s catalogue can show")
        #expect(!caption.contains("4 volumes"))
    }

    @Test func tileCaptionForAVanishedScopeNeverCountsTheSeries() {
        // A scope deleted on another device: the list is explicitly empty, so a whole-series
        // count here would be the #258 inversion moved to the root.
        let caption = ScopeAxis.subseriesTileCaption(volumes: tileVolumes, state: .unavailable)
        #expect(caption == "Browsing within a scope that is no longer available")
        #expect(!caption.contains("4 volumes"))
    }

    // MARK: Browse Within This Scope (#1364)
    //
    // `ScopeIndexView` offers the filter only where its mount passes `onBrowseWithin`. That is a
    // runtime check where `v2` had a compile-time `#if os(iOS)`, so the three tests below stand
    // where the gate stood, one per way the Mac could get the item back: a default on the property
    // (`aMountThatPassesNoActionOffersNoFilter`), the Mac mount passing the action in any spelling
    // (`onlyTheIOSMountOffersBrowseWithin`), and the view reaching the filter by some path the
    // action does not guard (`everyFilterAffordanceWaitsForTheAction`). Each was A/B'd against
    // a mutant of its own (see DEVELOPMENT-PLAN, #1364 review round 1).

    /// A Swift source file under the repository root, with every comment line emptied.
    ///
    /// A line whose code begins with `//` — a doc comment or a line comment — becomes empty rather
    /// than going, so line numbers stay the file's own. The scans below are NEGATIVE, failing when
    /// a spelling appears, and the files they read explain themselves in comments that name
    /// `onBrowseWithin`, `browseScopeFilterId` and `ScopeIndexView(` in prose.
    ///
    /// - Parameter url: The file.
    /// - Returns: Its code, as characters.
    private static func code(of url: URL) throws -> [Character] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: "\n").map { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : line
        }
        return Array(lines.joined(separator: "\n"))
    }

    /// The app's source directory, `FRUSExplorer/`.
    private static var appSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    /// The index of the bracket closing the one opened at `open`, or `nil` if it never closes.
    private static func closing(_ text: [Character], from open: Int,
                                opener: Character, closer: Character) -> Int? {
        var depth = 0
        for index in open..<text.count {
            if text[index] == opener { depth += 1 }
            if text[index] == closer {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    /// The 1-based line holding `offset`.
    private static func line(of offset: Int, in text: [Character]) -> Int {
        text[..<offset].filter { $0 == "\n" }.count + 1
    }

    /// One `ScopeIndexView(…)` call: the file it is in, its parenthesised arguments, and every
    /// trailing closure after them — the unlabelled one and each `label: { … }` that follows it
    /// (SE-0279). A call reaches its closures either way, so a scan that stopped at the `)` would
    /// read half of one.
    private struct ScopeIndexViewCall {
        /// The file's name.
        let file: String
        /// `ScopeIndexView(` through its balanced `)`.
        let arguments: String
        /// Each trailing closure, with its label when it has one.
        let trailingClosures: [String]
    }

    /// Every `ScopeIndexView(` call in the app's code (comment lines emptied).
    private static func scopeIndexViewCalls() throws -> [ScopeIndexViewCall] {
        let files = try #require(FileManager.default.enumerator(at: appSources,
                                                                includingPropertiesForKeys: nil))
        let needle = Array("ScopeIndexView(")
        var calls: [ScopeIndexViewCall] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try code(of: url)
            var i = 0
            while i + needle.count <= text.count {
                guard Array(text[i..<(i + needle.count)]) == needle else { i += 1; continue }
                let close = closing(text, from: i + needle.count - 1, opener: "(", closer: ")")
                    ?? text.count - 1
                var trailing: [String] = []
                var j = close + 1
                while true {
                    while j < text.count, text[j].isWhitespace { j += 1 }
                    // A label is read only after an unlabelled closure, as the grammar has it —
                    // which also keeps a following `default:` or `case …:` from reading as one.
                    var labelEnd = j
                    if !trailing.isEmpty {
                        while labelEnd < text.count,
                              text[labelEnd].isLetter || text[labelEnd].isNumber || text[labelEnd] == "_" {
                            labelEnd += 1
                        }
                    }
                    var brace = labelEnd
                    if labelEnd > j {
                        guard labelEnd < text.count, text[labelEnd] == ":" else { break }
                        brace = labelEnd + 1
                        while brace < text.count, text[brace].isWhitespace { brace += 1 }
                    }
                    guard brace < text.count, text[brace] == "{",
                          let end = closing(text, from: brace, opener: "{", closer: "}") else { break }
                    trailing.append(String(text[j...end]))
                    j = end + 1
                }
                calls.append(ScopeIndexViewCall(file: url.lastPathComponent,
                                                arguments: String(text[i...close]),
                                                trailingClosures: trailing))
                i = close + 1
            }
        }
        return calls
    }

    /// Only the iOS Browse mount offers Browse Within This Scope. The Mac corpus browser has no
    /// filter surface and no view there reads the filter, so the Mac manual says the item is iOS
    /// only; an action on the Mac mount would put an item there that narrows nothing.
    ///
    /// A call can hand over the action three ways: `onBrowseWithin:` inside the parentheses, the
    /// same label on a trailing closure (SE-0279), or an UNLABELLED trailing closure, which after
    /// `onEdit:` binds to `onBrowseWithin` by forward-scan matching (SE-0286), since that is the
    /// last parameter. So any mount but the iOS one must name `onBrowseWithin` nowhere and pass no
    /// trailing closure at all: every closure labelled inside the parentheses, where this scan can
    /// read which parameter it fills.
    @Test func onlyTheIOSMountOffersBrowseWithin() throws {
        let calls = try Self.scopeIndexViewCalls()
        // Both mounts must be read, or "the Mac passes none" holds over nothing.
        #expect(calls.map(\.file).sorted() == ["MacCorpusBrowserWindow.swift", "ScopeBrowseView.swift"],
                "the scan found \(calls.map(\.file))")
        let offering = calls.filter {
            $0.arguments.contains("onBrowseWithin") || !$0.trailingClosures.isEmpty
        }
        #expect(offering.map(\.file) == ["ScopeBrowseView.swift"], """
            Browse Within This Scope may be offered by \(offering.map(\.file)) — it belongs to the \
            iOS Browse mount alone (#1364). Any other mount passes its closures labelled inside the \
            parentheses and names no `onBrowseWithin`. Read: \(offering.map { $0.arguments + " " + $0.trailingClosures.joined(separator: " ") })
            """)
        // …and the iOS mount does hand it over, by label.
        #expect(calls.filter { $0.file == "ScopeBrowseView.swift" }
                    .allSatisfy { $0.arguments.contains("onBrowseWithin:") },
                "the iOS mount no longer passes `onBrowseWithin:`")
    }

    /// The Mac mount's shape — the ids and the two closures, nothing else — gets no action, and so
    /// no menu item and no row glyph. The call-site scan cannot see this: a non-nil DEFAULT on the
    /// property would hand the item to every mount that passes nothing.
    @Test func aMountThatPassesNoActionOffersNoFilter() {
        let view = ScopeIndexView(manifestIds: [], onOpen: { _ in }, onEdit: { _ in })
        #expect(view.onBrowseWithin == nil,
                "a ScopeIndexView given no onBrowseWithin still has one, so the Mac offers the filter")
    }

    /// Nothing in `ScopeIndexView` reaches the filter except behind the action: every mention of
    /// `browseScopeFilterId` and of the two menu items' keys sits inside `if let onBrowseWithin`,
    /// but the row mark's one read, which is conjoined with `onBrowseWithin != nil`. That is what
    /// keeps a mount that passes nothing — the Mac — free of both items and the glyph, and what a
    /// `#if os(macOS)` branch re-adding an item, or a glyph keyed on the filter alone, would break.
    @Test func everyFilterAffordanceWaitsForTheAction() throws {
        let text = try Self.code(of: Self.appSources.appendingPathComponent("Browser/ScopeBrowseView.swift"))
        let source = String(text)
        let declaration = "struct ScopeIndexView: View {"
        // `source` is `text` as a string, so a distance in characters is an index into `text`.
        let viewStart = source.distance(from: source.startIndex,
                                        to: try #require(source.range(of: declaration)).lowerBound)
        let viewEnd = try #require(Self.closing(text, from: viewStart + declaration.count - 1,
                                                opener: "{", closer: "}"),
                                   "ScopeIndexView's body never closes")
        let blockOpener = Array("if let onBrowseWithin {")
        let blockStarts = (viewStart...(viewEnd - blockOpener.count)).filter {
            Array(text[$0..<($0 + blockOpener.count)]) == blockOpener
        }
        #expect(blockStarts.count == 1, "ScopeIndexView has \(blockStarts.count) `if let onBrowseWithin` blocks, not one")
        let blockStart = try #require(blockStarts.first)
        let blockEnd = try #require(Self.closing(text, from: blockStart + blockOpener.count - 1,
                                                 opener: "{", closer: "}"))

        var inside: [String: Int] = [:]
        var rowMarkReads = 0
        for token in ["browseScopeFilterId", "\"browser.scopes.menu.browseWithin\"",
                      "\"browser.scopes.menu.stopBrowsing\""] {
            let needle = Array(token)
            for offset in viewStart...(viewEnd - needle.count)
            where Array(text[offset..<(offset + needle.count)]) == needle {
                let line = Self.line(of: offset, in: text)
                if (blockStart...blockEnd).contains(offset) {
                    inside[token, default: 0] += 1
                } else if token == "browseScopeFilterId",
                          source.components(separatedBy: "\n")[line - 1]
                              .contains("onBrowseWithin != nil && appState.browseScopeFilterId") {
                    rowMarkReads += 1
                } else {
                    Issue.record("""
                        ScopeBrowseView.swift:\(line): ScopeIndexView reaches \(token) outside \
                        `if let onBrowseWithin`, so a mount that passes no action — the Mac — gets it too
                        """)
                }
            }
        }
        // The sweep must have read what it guards: both items, the Stop branch's test and write,
        // and the row mark.
        #expect(inside["\"browser.scopes.menu.browseWithin\""] == 1)
        #expect(inside["\"browser.scopes.menu.stopBrowsing\""] == 1)
        #expect(inside["browseScopeFilterId", default: 0] == 2, "read \(inside)")
        #expect(rowMarkReads == 1, "the row mark's guarded read was found \(rowMarkReads) times")
    }

    #if os(iOS)
    /// The action the iOS My Scopes level hands its menu: narrow the subseries hierarchy, then open
    /// the subseries list — the level the banner is on — replacing the path, as the root's own tile
    /// does. This calls the function; the closure the mount wraps it in is reached only by the UI
    /// suite `BrowseWithinScopeTests`.
    @Test func browseWithinNarrowsAndOpensTheSubseriesList() {
        let appState = AppState()
        // `browseScopeFilterId` writes UserDefaults, and this runs inside the app host.
        let before = appState.browseScopeFilterId
        defer { appState.browseScopeFilterId = before }
        let vm = BrowserViewModel(manifestStore: ManifestStore(bundledEntries: []),
                                  tagStore: VolumeLevelTagStore(),
                                  downloadManager: nil, indexingPipeline: nil)
        vm.navigationPath = [.scopes]
        let scopeId = UUID()

        BrowseScopesLevel.browseWithin(scopeId, vm: vm, appState: appState)

        #expect(appState.browseScopeFilterId == scopeId)
        #expect(vm.navigationPath == [.subseriesIndex],
                "the reader must land on the list the banner is on; path \(vm.navigationPath)")
    }
    #endif
}
