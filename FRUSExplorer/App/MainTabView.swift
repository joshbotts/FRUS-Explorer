// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)
import SwiftUI

// MARK: - MainTabView

/// Root tab bar view for FRUS Explorer on iOS.
///
/// Uses the iOS 18+ `Tab` API with `value:` parameter so `appState.activeTab`
/// drives selection and persists across launches. All five tabs are fully wired
/// as of Session 44.
///
/// `MainTabView` is instantiated by `ContentView` on iOS after the user has
/// completed onboarding. macOS continues to use `BrowserView` directly.
///
/// Version history:
///   1.0 — Session 43: initial iOS tab shell with Browse + 4 placeholder tabs
///   1.1 — Session 44: all four placeholder tabs wired with real content
struct MainTabView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.activeTab) {
            Tab(
                String(localized: "tab.browse", defaultValue: "Browse"),
                systemImage: "books.vertical",
                value: AppTab.browse
            ) {
                BrowserTabView()
            }
            Tab(
                String(localized: "tab.search", defaultValue: "Search"),
                systemImage: "magnifyingglass",
                value: AppTab.search
            ) {
                SearchTabView()
            }
            Tab(
                String(localized: "tab.activity", defaultValue: "Activity"),
                systemImage: "person.crop.rectangle.stack",
                value: AppTab.activity
            ) {
                ActivityTabView()
            }
            Tab(
                String(localized: "tab.collections", defaultValue: "Collections"),
                systemImage: "tray.2",
                value: AppTab.collections
            ) {
                CollectionListView()
            }
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gear",
                value: AppTab.settings
            ) {
                SettingsView()
            }
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
