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
        #expect(SettingsPane.connections.label == "Connections")
    }

    /// Both renderers show these, so their placement is the shared tree.
    @Test("Cross-platform panes land in the expected groups")
    func groupAssignments() {
        #expect(SettingsPane.volumesStorage.group == .library)
        #expect(SettingsPane.projects.group == .research)
        #expect(SettingsPane.wordCloud.group == .research)
        #expect(SettingsPane.display.group == .readingAndSearch)
        #expect(SettingsPane.search.group == .readingAndSearch)
        #expect(SettingsPane.about.group == .system)
        #expect(SettingsPane.dataRecovery.group == .system)
    }

    /// The asymmetries are deliberate and documented; pinning them means a future change to one
    /// renderer has to change the model — which is the whole point.
    ///
    /// Notes used to be pinned here as macOS-only and no longer is. That assertion did its job:
    /// it was the speed bump that made promoting the pane a decision rather than an accident.
    /// The decision was taken because the pane owns the Log Research Sessions switch, which iOS
    /// had no control for at all.
    @Test("Platform-specific panes stay platform-specific")
    func platformAsymmetry() {
        #expect(SettingsPane.sync.platforms == [.macOS])
        #expect(SettingsPane.notes.platforms == [.iOS, .macOS])
        #expect(SettingsPane.display.platforms == [.iOS, .macOS])
    }

    /// The research-session switch has its own pane now. It was a section of Notes only because
    /// Notes was the one Research destination with room — the giveaway being that `.notes` had to
    /// carry "logging", "privacy" and "trail" so a reader could find a recording switch inside a
    /// pane called *Notes*. Those keywords belong to the pane that owns the switch.
    @Test("Research Sessions answers for the words a reader actually types")
    func researchSessionsKeywords() {
        // "reading history" and "search history" were added in Wave R-1: the switch in this pane
        // now gates those stores too, so a reader hunting for where they are governed must land
        // here rather than concluding the app offers no control over them.
        for query in ["log research sessions", "logging", "session log", "history",
                      "privacy", "recording", "trail", "delete history",
                      "reading history", "search history", "recents"] {
            #expect(SettingsPane.researchSessions.matches(query), "no match for \(query)")
        }
        #expect(SettingsPane.researchSessions.group == .research)
        #expect(SettingsPane.researchSessions.platforms == [.iOS, .macOS])
    }

    /// And Notes goes back to being about notes: it must not still claim the recording vocabulary,
    /// or both panes surface for "privacy" and the split has bought nothing.
    @Test("Notes no longer answers for the recording switch")
    func notesReleasedTheLoggingKeywords() {
        for query in ["logging", "privacy", "recording", "trail", "session log"] {
            #expect(!SettingsPane.notes.matches(query), "Notes still matches \(query)")
        }
        #expect(SettingsPane.notes.matches("research notes"))
        #expect(SettingsPane.notes.platforms.contains(.iOS))
    }

    /// S-2 merged Storage + Add Volumes + Sideload into one destination on each platform. The
    /// Library group is now a single row everywhere; a second one would mean the merge had come
    /// undone on one side.
    @Test("Library is one destination on both platforms", arguments: [SettingsPlatform.iOS, .macOS])
    func libraryIsOneDestination(platform: SettingsPlatform) {
        #expect(SettingsPane.panes(in: .library, on: platform) == [.volumesStorage])
    }

    /// The merged pane has to answer every query that used to find one of the three it replaced —
    /// a reader who searched "sideload" or "github" must still land somewhere.
    @Test("The merged destination inherits the search terms of the panes it absorbed")
    func mergedDestinationKeywords() {
        for query in ["download", "github", "sideload", "xml", "tei", "reindex", "free up",
                      "corrections", "storage", "spotlight", "disk"] {
            #expect(SettingsPane.volumesStorage.matches(query), "no match for \(query)")
        }
    }

    /// S-4b merged Research Data, Sync Diagnostics and Reset App. The recovery ladder is only
    /// findable if the door answers for all three of the rows it replaced.
    @Test("Data & Recovery answers for the three rows it absorbed")
    func dataRecoveryKeywords() {
        for query in ["export", "json", "markdown", "obsidian", "backup", "broken cross-references",
                      "sync diagnostics", "log", "troubleshoot", "erase", "reset", "start over"] {
            #expect(SettingsPane.dataRecovery.matches(query), "no match for \(query)")
        }
    }

    /// The whole point of S-4 and S-5: System shrinks from nine rows to three or four.
    @Test("System is down to its merged rows", arguments: [SettingsPlatform.iOS, .macOS])
    func systemGroupSize(platform: SettingsPlatform) {
        let system = SettingsPane.panes(in: .system, on: platform)
        #expect(system.contains(.connections))
        #expect(system.contains(.dataRecovery))
        #expect(system.contains(.about))
        #expect(system.count <= 4, "System grew back: \(system.map(\.rawValue))")
    }

    /// S-5 retired the Research Guide row — it is content, not a setting, and lives in About's
    /// Resources now. A reader who searches for it must still land on the pane that has it.
    @Test("About answers for the Research Guide it absorbed")
    func aboutCarriesTheGuide() {
        for query in ["guide", "help", "how to", "learn", "legal", "notices", "version"] {
            #expect(SettingsPane.about.matches(query), "no match for \(query)")
        }
    }

    /// S-4a merged the two outside-service rows. Same rule as the Library merge: the survivor has
    /// to answer for both, and neither of the retired rows may still be reachable.
    @Test("Connections answers for both services it absorbed")
    func connectionsKeywords() {
        for query in ["nara", "national archives", "catalog", "api key", "source explorer",
                      "zotero", "bibliography", "citations", "library", "connect"] {
            #expect(SettingsPane.connections.matches(query), "no match for \(query)")
        }
        // One row, both platforms — a second would mean the merge came undone on one side.
        for platform in [SettingsPlatform.iOS, .macOS] {
            let system = SettingsPane.panes(in: .system, on: platform)
            #expect(system.contains(.connections))
            #expect(system.filter { $0 == .connections }.count == 1)
        }
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
        #expect(SettingsPane.connections.matches("nara"))
    }

    /// Keywords are what make the field worth having: they match what a researcher types, not
    /// what the row happens to be called.
    @Test("Keywords find panes whose labels do not contain the query")
    func keywordMatch() {
        #expect(SettingsPane.wordCloud.matches("stop words"))
        #expect(!SettingsPane.wordCloud.label.lowercased().contains("stop words"))
        #expect(SettingsPane.connections.matches("api key"))
        #expect(SettingsPane.display.matches("font"))
        #expect(SettingsPane.dataRecovery.matches("export"))
        #expect(SettingsPane.dataRecovery.matches("erase"))
        #expect(SettingsPane.volumesStorage.matches("reindex"))
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
