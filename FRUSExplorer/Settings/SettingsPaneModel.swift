// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SettingsGroup

/// The four task-first groups the Settings root is organised into (North Star IA option `1c`).
///
/// Ordered by researcher job: get material onto the device, work with it, tune how it reads, then
/// the plumbing you touch once. `allCases` order **is** the render order on both platforms.
///
/// Version history:
///   1.0 — S-1: initial implementation
enum SettingsGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// Getting the corpus onto this device and keeping it indexed.
    case library
    /// The research apparatus: projects, tags, scopes, and the tools that read them.
    case research
    /// How documents and results are presented.
    case readingAndSearch
    /// Sync, connected services, data export, and the app's own identity.
    case system

    var id: String { rawValue }

    /// The section header shown on both platforms.
    var label: String {
        switch self {
        case .library:          return String(localized: "settings.group.library", defaultValue: "Library")
        case .research:         return String(localized: "settings.group.research", defaultValue: "Research")
        case .readingAndSearch: return String(localized: "settings.group.readingAndSearch", defaultValue: "Reading & Search")
        case .system:           return String(localized: "settings.group.system", defaultValue: "System")
        }
    }
}

// MARK: - SettingsPlatform

/// Which renderer a pane appears in.
///
/// The two Settings surfaces are not yet symmetric — macOS has a Notes pane iOS lacks, iOS has a
/// Sideload row and an in-app Research Guide entry macOS reaches from a menu instead. Declaring
/// that here keeps the asymmetry *stated* rather than implied by two divergent view bodies, which
/// is what let the trees drift apart in the first place.
///
/// Version history:
///   1.0 — S-1: initial implementation
enum SettingsPlatform: Hashable, Sendable {
    case iOS
    case macOS

    /// The platform this build renders for.
    static var current: SettingsPlatform {
        #if os(macOS)
        .macOS
        #else
        .iOS
        #endif
    }
}

// MARK: - SettingsPane

/// One Settings destination, declared once and rendered by both platforms.
///
/// Before S-1 the macOS sidebar owned this enum (labels, icons, and five hand-maintained section
/// arrays) while iOS hard-coded its own rows and section headers in `SettingsView`. The two drifted
/// — different titles for the same pane, different grouping, different order — and every settings
/// change had to be made twice by hand. This type is the single source of truth for **identity,
/// label, icon, group, search keywords, and platform availability**; each renderer supplies only
/// the destination view.
///
/// Adding a pane: add the case, its `label`/`icon`/`group`/`keywords`/`platforms`, and a
/// destination in each renderer that lists it. `assertCoverage()` catches a case that never
/// reaches a group.
///
/// Version history:
///   1.0 — S-1: promoted from the macOS-only sidebar enum to the shared cross-platform model;
///          gained `group`, `keywords`, and `platforms`
enum SettingsPane: String, Identifiable, Hashable, CaseIterable, Sendable {

    // Library
    case storage, downloads, sideload
    // Research
    case projects, tags, scopes, summarization, wordCloud, notes
    // Reading & Search
    case display, search
    // System
    case sync, syncDiagnostics, naraAPI, zotero, data, reset, about, researchGuide

    var id: String { rawValue }

    // MARK: Presentation

    /// The row title. One wording on both platforms — divergence here is the drift S-1 exists to end.
    var label: String {
        switch self {
        case .storage:         return String(localized: "settings.pane.storage", defaultValue: "Storage & Index")
        case .downloads:       return String(localized: "settings.pane.downloads", defaultValue: "Add Volumes")
        case .sideload:        return String(localized: "settings.pane.sideload", defaultValue: "Sideload Volume")
        case .projects:        return String(localized: "settings.pane.projects", defaultValue: "Projects")
        case .tags:            return String(localized: "settings.pane.tags", defaultValue: "Tags")
        case .scopes:          return String(localized: "settings.pane.scopes", defaultValue: "Volume Scopes")
        case .summarization:   return String(localized: "settings.pane.summarization", defaultValue: "Summarization")
        case .wordCloud:       return String(localized: "settings.pane.wordCloud", defaultValue: "Word Cloud")
        case .notes:           return String(localized: "settings.pane.notes", defaultValue: "Notes")
        case .display:         return String(localized: "settings.pane.display", defaultValue: "Display")
        case .search:          return String(localized: "settings.pane.search", defaultValue: "Search")
        case .sync:            return String(localized: "settings.pane.sync", defaultValue: "iCloud Sync")
        case .syncDiagnostics: return String(localized: "settings.pane.syncDiagnostics", defaultValue: "Sync Diagnostics")
        case .naraAPI:         return String(localized: "settings.pane.naraAPI", defaultValue: "NARA API")
        case .zotero:          return String(localized: "settings.pane.zotero", defaultValue: "Zotero")
        case .data:            return String(localized: "settings.pane.data", defaultValue: "Research Data")
        case .reset:           return String(localized: "settings.pane.reset", defaultValue: "Reset App")
        case .about:           return String(localized: "settings.pane.about", defaultValue: "About")
        case .researchGuide:   return String(localized: "settings.pane.researchGuide", defaultValue: "FRUS Research Guide")
        }
    }

    /// SF Symbol for the row.
    var icon: String {
        switch self {
        case .storage:         return "internaldrive"
        case .downloads:       return "plus.circle"
        case .sideload:        return "square.and.arrow.down"
        case .projects:        return "folder"
        case .tags:            return "tag"
        case .scopes:          return "square.stack.3d.up"
        case .summarization:   return "sparkles"
        case .wordCloud:       return "text.word.spacing"
        case .notes:           return "note.text"
        case .display:         return "textformat.size"
        case .search:          return "magnifyingglass"
        case .sync:            return "icloud"
        case .syncDiagnostics: return "stethoscope"
        case .naraAPI:         return "key"
        case .zotero:          return "books.vertical"
        case .data:            return "square.and.arrow.up"
        case .reset:           return "arrow.counterclockwise"
        case .about:           return "info.circle"
        case .researchGuide:   return "book"
        }
    }

    // MARK: Placement

    /// Which of the four `1c` groups this pane belongs to.
    var group: SettingsGroup {
        switch self {
        case .storage, .downloads, .sideload:
            return .library
        case .projects, .tags, .scopes, .summarization, .wordCloud, .notes:
            return .research
        case .display, .search:
            return .readingAndSearch
        case .sync, .syncDiagnostics, .naraAPI, .zotero, .data, .reset, .about, .researchGuide:
            return .system
        }
    }

    /// Which renderers show this pane. See `SettingsPlatform` for why the two differ today.
    var platforms: Set<SettingsPlatform> {
        switch self {
        // macOS reaches sideloading from inside Add Volumes; iOS has a dedicated row.
        case .sideload:      return [.iOS]
        // The in-app guide is a Window scene on macOS, opened from a menu rather than Settings.
        case .researchGuide: return [.iOS]
        // iOS has no standalone Notes pane; its note settings live with the research surfaces.
        case .notes:         return [.macOS]
        // iOS presents iCloud sync as an inline toggle section, not a pushed destination.
        case .sync:          return [.macOS]
        default:             return [.iOS, .macOS]
        }
    }

    // MARK: Search

    /// Extra terms that should match this pane in the iOS Settings search field, beyond its label.
    ///
    /// These are the words a researcher actually types when hunting a setting — the feature name
    /// ("stop words"), the thing being changed ("font"), or the old label they remember.
    var keywords: [String] {
        switch self {
        case .storage:         return ["index", "reindex", "disk", "space", "free up", "rebuild", "spotlight"]
        case .downloads:       return ["download", "github", "volumes", "corpus", "fetch", "updates", "corrections"]
        case .sideload:        return ["xml", "import", "tei", "local file"]
        case .projects:        return ["project", "research question", "active project"]
        case .tags:            return ["user tags", "labels", "merge", "rename"]
        case .scopes:          return ["volume scope", "custom scope", "my volume scopes", "subset"]
        case .summarization:   return ["ai", "apple intelligence", "prompts", "summaries", "batch", "background"]
        case .wordCloud:       return ["stop words", "stopwords", "hidden words", "lens", "density", "typeface", "font"]
        case .notes:           return ["research notes", "annotations"]
        case .display:         return ["text size", "font", "citations", "reading mode", "chart colors", "appearance"]
        case .search:          return ["scope", "snippet", "editorial notes", "defaults", "filters"]
        case .sync:            return ["icloud", "cloudkit", "devices"]
        case .syncDiagnostics: return ["icloud", "log", "troubleshoot", "errors"]
        case .naraAPI:         return ["national archives", "catalog", "api key", "source explorer", "nara"]
        case .zotero:          return ["citations", "library", "integration", "bibliography"]
        case .data:            return ["export", "json", "markdown", "backup", "broken cross-references", "report"]
        case .reset:           return ["erase", "delete", "start over", "clear"]
        case .about:           return ["version", "build", "license", "credits", "acknowledgements"]
        case .researchGuide:   return ["help", "guide", "education", "how to", "learn"]
        }
    }

    /// Whether this pane matches `query` in the iOS Settings search field.
    ///
    /// Case- and diacritic-insensitive over the label, the group name, and `keywords`, so "stop
    /// words" finds Word Cloud and "icloud" finds both sync panes. An empty query matches
    /// everything, which is what a cleared search field should show.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystack = ([label, group.label] + keywords).joined(separator: "\n")
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    // MARK: Queries

    /// The panes in `group` that this platform renders, in declaration order.
    ///
    /// Declaration order is the render order: `allCases` follows the source order of the cases,
    /// which is grouped and sequenced deliberately above. That removes the five hand-maintained
    /// section arrays the macOS sidebar used to carry — and with them the failure mode where a
    /// new case compiled cleanly but shipped unreachable because nobody added it to an array.
    static func panes(in group: SettingsGroup,
                      on platform: SettingsPlatform = .current) -> [SettingsPane] {
        allCases.filter { $0.group == group && $0.platforms.contains(platform) }
    }

    /// Every pane this platform renders, grouped, skipping groups with no panes.
    static func groupedPanes(on platform: SettingsPlatform = .current) -> [(group: SettingsGroup, panes: [SettingsPane])] {
        SettingsGroup.allCases.compactMap { group in
            let panes = panes(in: group, on: platform)
            return panes.isEmpty ? nil : (group, panes)
        }
    }

    /// Fails a debug build if any pane would never render on a platform that claims it.
    ///
    /// The old macOS sidebar needed this because its sections were hand-listed; the grouped query
    /// above makes an orphan impossible by construction. It stays as a guard on the weaker
    /// remaining invariant — that no pane declares an empty platform set and silently disappears
    /// from both renderers.
    static func assertCoverage() {
        #if DEBUG
        let orphaned = allCases.filter { $0.platforms.isEmpty }
        assert(orphaned.isEmpty,
               "SettingsPane case(s) render on no platform: \(orphaned.map(\.rawValue))")
        for platform in [SettingsPlatform.iOS, .macOS] {
            let rendered = Set(groupedPanes(on: platform).flatMap(\.panes))
            let claimed = Set(allCases.filter { $0.platforms.contains(platform) })
            assert(rendered == claimed,
                   "SettingsPane grouping drops \(claimed.subtracting(rendered).map(\.rawValue)) on \(platform)")
        }
        #endif
    }
}
