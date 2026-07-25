// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SettingsPaneModelTests

/// Tests the shared Settings pane model (S-1).
///
/// Before this model the macOS sidebar and the iOS root each hard-coded their own labels, icons,
/// and section membership, and drifted apart — different titles for the same pane, different
/// grouping. These tests pin the invariants that make the two renderers agree, and the ones the
/// old macOS-only `assertSidebarCoverage()` could never check (that assertion was a DEBUG
/// `assert` in a macOS-only file, and the Mac scheme has no test action, so it never ran in CI).
struct SettingsPaneModelTests {

    /// Every pane renders somewhere. A pane with an empty platform set would compile, appear in
    /// `allCases`, and be reachable by nothing — the failure mode the macOS sidebar hit with
    /// `.scopes` when its section arrays were hand-maintained.
    @Test("Every pane declares at least one platform")
    func noOrphanedPanes() {
        let orphans = SettingsPane.allCases.filter { $0.platforms.isEmpty }
        #expect(orphans.isEmpty, "panes render nowhere: \(orphans.map(\.rawValue))")
    }

    /// The grouped query is the only thing either renderer calls, so anything it drops is
    /// invisible in the app regardless of what the enum says.
    @Test("Grouping renders exactly the panes each platform claims", arguments: [SettingsPlatform.iOS, .macOS])
    func groupingIsLossless(platform: SettingsPlatform) {
        let rendered = Set(SettingsPane.groupedPanes(on: platform).flatMap(\.panes))
        let claimed = Set(SettingsPane.allCases.filter { $0.platforms.contains(platform) })
        #expect(rendered == claimed,
                "dropped on \(platform): \(claimed.subtracting(rendered).map(\.rawValue))")
    }

    /// A pane must not appear twice — duplicate rows in a settings list are a visible bug.
    @Test("No pane appears in more than one group", arguments: [SettingsPlatform.iOS, .macOS])
    func noDuplicateRows(platform: SettingsPlatform) {
        let all = SettingsPane.groupedPanes(on: platform).flatMap(\.panes)
        #expect(all.count == Set(all).count, "duplicate rows on \(platform)")
    }

    /// Empty groups must not render as empty section headers.
    @Test("Grouped output never contains an empty group", arguments: [SettingsPlatform.iOS, .macOS])
    func noEmptyGroups(platform: SettingsPlatform) {
        #expect(SettingsPane.groupedPanes(on: platform).allSatisfy { !$0.panes.isEmpty })
    }

    /// Group order is the researcher-job order the IA settles on, and it is the render order on
    /// both platforms — so pinning it here pins what the user sees.
    @Test("Groups render in the settled task-first order")
    func groupOrder() {
        #expect(SettingsGroup.allCases == [.library, .research, .readingAndSearch, .system])
    }

    /// The point of the model: one label per pane, whichever renderer asks. A regression here is
    /// exactly the drift S-1 exists to end.
    @Test("Labels and icons are platform-independent")
    func sharedPresentation() {
        for pane in SettingsPane.allCases {
            #expect(!pane.label.isEmpty)
            #expect(!pane.icon.isEmpty)
        }
        // Spot-check the ones S-0 renamed, so a later edit cannot quietly revert them.
        #expect(SettingsPane.tags.label == "Tags")
        #expect(SettingsPane.search.label == "Search")
        #expect(SettingsPane.naraAPI.label == "NARA API")
    }

    /// Both renderers show these, so their placement is the shared tree.
    @Test("Cross-platform panes land in the expected groups")
    func groupAssignments() {
        #expect(SettingsPane.storage.group == .library)
        #expect(SettingsPane.downloads.group == .library)
        #expect(SettingsPane.projects.group == .research)
        #expect(SettingsPane.wordCloud.group == .research)
        #expect(SettingsPane.display.group == .readingAndSearch)
        #expect(SettingsPane.search.group == .readingAndSearch)
        #expect(SettingsPane.about.group == .system)
        #expect(SettingsPane.reset.group == .system)
    }

    /// The asymmetries are deliberate and documented; pinning them means a future change to one
    /// renderer has to change the model — which is the whole point.
    @Test("Platform-specific panes stay platform-specific")
    func platformAsymmetry() {
        #expect(SettingsPane.notes.platforms == [.macOS])
        #expect(SettingsPane.sync.platforms == [.macOS])
        #expect(SettingsPane.sideload.platforms == [.iOS])
        #expect(SettingsPane.researchGuide.platforms == [.iOS])
        #expect(SettingsPane.display.platforms == [.iOS, .macOS])
    }

    // MARK: - Search

    /// An empty query shows the whole tree — a cleared search field must not blank the screen.
    @Test("An empty or whitespace query matches every pane")
    func emptyQueryMatchesAll() {
        for pane in SettingsPane.allCases {
            #expect(pane.matches(""))
            #expect(pane.matches("   "))
        }
    }

    /// Label matching is the baseline expectation.
    @Test("A pane matches its own label, case-insensitively")
    func labelMatch() {
        #expect(SettingsPane.wordCloud.matches("word cloud"))
        #expect(SettingsPane.wordCloud.matches("WORD CLOUD"))
        #expect(SettingsPane.naraAPI.matches("nara"))
    }

    /// Keywords are what make the field worth having: they match what a researcher types, not
    /// what the row happens to be called.
    @Test("Keywords find panes whose labels do not contain the query")
    func keywordMatch() {
        #expect(SettingsPane.wordCloud.matches("stop words"))
        #expect(!SettingsPane.wordCloud.label.lowercased().contains("stop words"))
        #expect(SettingsPane.naraAPI.matches("api key"))
        #expect(SettingsPane.display.matches("font"))
        #expect(SettingsPane.data.matches("export"))
        #expect(SettingsPane.reset.matches("erase"))
        #expect(SettingsPane.storage.matches("reindex"))
    }

    /// The group name is searchable too, so "research" surfaces the whole research group.
    @Test("A group name matches its panes")
    func groupNameMatch() {
        #expect(SettingsPane.projects.matches("Research"))
        #expect(SettingsPane.display.matches("Reading"))
    }

    /// A query that matches nothing must match nothing — an over-eager filter would make the
    /// field useless.
    @Test("An unrelated query matches no pane")
    func noFalsePositives() {
        let matches = SettingsPane.allCases.filter { $0.matches("zzzznotathing") }
        #expect(matches.isEmpty)
    }

    /// Diacritic-insensitivity, so a query typed with an accent still finds its pane.
    @Test("Matching ignores diacritics")
    func diacriticInsensitive() {
        #expect(SettingsPane.search.matches("séarch"))
    }
}
