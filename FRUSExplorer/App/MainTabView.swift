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
/// drives selection and persists across launches. Only the Browse tab contains
/// live content in Session 43; the remaining four tabs show placeholder views
/// that will be replaced in Sessions 44–46.
///
/// `MainTabView` is instantiated by `ContentView` on iOS after the user has
/// completed onboarding. macOS continues to use `BrowserView` directly.
///
/// Version history:
///   1.0 — Session 43: initial iOS tab shell with Browse + 4 placeholder tabs
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
                PlaceholderTabView(
                    title: String(localized: "tab.search", defaultValue: "Search"),
                    systemImage: "magnifyingglass"
                )
            }
            Tab(
                String(localized: "tab.activity", defaultValue: "Activity"),
                systemImage: "clock.arrow.circlepath",
                value: AppTab.activity
            ) {
                PlaceholderTabView(
                    title: String(localized: "tab.activity", defaultValue: "Activity"),
                    systemImage: "clock.arrow.circlepath"
                )
            }
            Tab(
                String(localized: "tab.collections", defaultValue: "Collections"),
                systemImage: "folder",
                value: AppTab.collections
            ) {
                PlaceholderTabView(
                    title: String(localized: "tab.collections", defaultValue: "Collections"),
                    systemImage: "folder"
                )
            }
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gear",
                value: AppTab.settings
            ) {
                PlaceholderTabView(
                    title: String(localized: "tab.settings", defaultValue: "Settings"),
                    systemImage: "gear"
                )
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
struct BrowserTabView: View {
    var body: some View {
        BrowserView()
    }
}

// MARK: - PlaceholderTabView

/// Minimal placeholder shown for tabs not yet implemented (Sessions 44–46).
private struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(
                    String(localized: "tab.placeholder.description",
                           defaultValue: "Coming soon")
                )
            )
            .navigationTitle(title)
        }
    }
}
#endif
