// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - MainTabView

/// Root tab bar view for FRUS Explorer on iOS.
///
/// Uses the iOS 18+ `Tab` API with `value:` parameter so `appState.activeTab`
/// drives selection and persists across launches. All five tabs are fully wired
/// as of Session 44.
///
/// ## Badges
/// - **Activity** tab: count of `ResearchNote`s with `createdAt` newer than
///   `appState.lastActivityTabVisit`. Cleared automatically when the user selects
///   the Activity tab (the timestamp is stamped in the `.onChange` handler).
/// - **Settings** tab: count of downloaded-but-unindexed volumes, via
///   `appState.unindexedVolumeCount`. Prompts the user to run Reindex.
///
/// `MainTabView` is instantiated by `ContentView` on iOS after the user has
/// completed onboarding. macOS continues to use `BrowserView` directly.
///
/// Version history:
///   1.0 — Session 43: initial iOS tab shell with Browse + 4 placeholder tabs
///   1.1 — Session 44: all four placeholder tabs wired with real content
///   1.2 — Session 45: activity + settings badges; lastActivityTabVisit stamping
///   1.3 — Session 56: Settings badge changed from raw count to boolean "·" indicator
///          (HIG: badges must represent actionable user-driven information, not status
///          counts; a simple dot communicates "attention needed" without implying
///          the number is an actionable queue)
///   1.4 — Session 93: IndexingBannerView wired via .safeAreaInset(edge: .bottom) on
///          each tab's root view; ActivityKit / Live Activity deferred (see
///          IndexingBannerView.swift); banner visible across all tabs during indexing
struct MainTabView: View {

    @Environment(AppState.self) private var appState

    /// All research notes; filtered in `newNoteCount` to those newer than last visit.
    @Query private var allNotes: [ResearchNote]

    /// Count of notes created after the last visit to the Activity tab.
    ///
    /// Uses `createdAt`; notes with a nil `createdAt` (legacy) are not counted.
    private var newNoteCount: Int {
        allNotes.filter { note in
            guard let created = note.createdAt else { return false }
            return created > appState.lastActivityTabVisit
        }.count
    }

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.activeTab) {
            Tab(
                String(localized: "tab.browse", defaultValue: "Browse"),
                systemImage: "books.vertical",
                value: AppTab.browse
            ) {
                BrowserTabView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.search", defaultValue: "Search"),
                systemImage: "magnifyingglass",
                value: AppTab.search
            ) {
                SearchTabView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.activity", defaultValue: "Activity"),
                systemImage: "person.crop.rectangle.stack",
                value: AppTab.activity
            ) {
                ActivityTabView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            .badge(newNoteCount)
            Tab(
                String(localized: "tab.collections", defaultValue: "Collections"),
                systemImage: "tray.2",
                value: AppTab.collections
            ) {
                CollectionListView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gear",
                value: AppTab.settings
            ) {
                SettingsView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            // Boolean dot badge: shows when any downloaded volumes are awaiting indexing.
            // A raw count badge (the previous behaviour) is misleading — the number is a
            // background status metric, not an actionable queue the user must clear item
            // by item. A dot communicates "something needs attention" without implying
            // a specific count.
            .badge(appState.unindexedVolumeCount > 0 ? "·" : "")
        }
    }

    /// Returns `IndexingBannerView` when indexing is active, or `EmptyView` otherwise.
    ///
    /// Passed to `.safeAreaInset(edge: .bottom, spacing: 0)` on each tab's root view.
    /// An `EmptyView` result adds 0 height inset, so there is no visual or layout effect
    /// when no indexing is in progress.
    @ViewBuilder
    private var indexingBanner: some View {
        if let update = appState.currentIndexingProgress {
            IndexingBannerView(update: update)
        }
    }
}

// MARK: - BrowserTabView

/// Wraps `BrowserView` for the Browse tab.
///
/// Exists as a named struct so that SwiftUI maintains stable `@State` identity for
/// `BrowserView`'s `viewModel` across tab switches. Without the wrapper, switching
/// away from and back to the Browse tab could recreate `BrowserView` and reset
/// navigation state.
///
/// Version history:
///   1.0 — Session 43: initial implementation
struct BrowserTabView: View {
    var body: some View {
        BrowserView()
    }
}

// MARK: - SearchTabView

/// Search tab root on iOS.
///
/// Embeds `SearchView` directly (no sheet wrapper). A Citation Lookup toolbar
/// button opens `CitationLookupView` as a local sheet — the sheet is tied to
/// the Search tab rather than the Browse tab so it stays in context.
///
/// When `appState.searchService` is unavailable (database not yet opened),
/// a `ContentUnavailableView` placeholder is shown instead.
///
/// Version history:
///   1.0 — Session 44: initial implementation
private struct SearchTabView: View {

    @Environment(AppState.self) private var appState
    @State private var showCitationLookup = false

    var body: some View {
        if let service = appState.searchService {
            SearchView(
                searchService: service,
                subjectTagStore: appState.subjectTagStore
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCitationLookup = true
                    } label: {
                        Image(systemName: "text.magnifyingglass")
                    }
                    .accessibilityLabel(
                        String(localized: "search.citationLookup.a11y",
                               defaultValue: "Find by citation")
                    )
                }
            }
            .sheet(isPresented: $showCitationLookup) {
                CitationLookupView()
            }
        } else {
            ContentUnavailableView(
                String(localized: "search.unavailable.title",
                       defaultValue: "Search Unavailable"),
                systemImage: "magnifyingglass",
                description: Text(
                    String(localized: "search.unavailable.detail",
                           defaultValue: "The search index is not available.")
                )
            )
        }
    }
}

// MARK: - ActivityTabView

/// Activity tab root on iOS.
///
/// `ProjectContextView` renders as a persistent tab root — the user sees their
/// projects and activity feeds without tapping a toolbar button or dismissing a sheet.
///
/// Version history:
///   1.0 — Session 44: initial implementation
private struct ActivityTabView: View {
    var body: some View {
        ProjectContextView()
    }
}
#endif
