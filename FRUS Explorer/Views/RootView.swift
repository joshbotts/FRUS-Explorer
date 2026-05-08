// RootView.swift
// Top-level navigation: Explorer | Collections | Research.
//
// macOS   — TabView with tab bar (sits at top via .windowToolbarStyle)
// iPadOS  — TabView with sidebar-style tab bar (iPadOS 18+), collapsible
//           to a compact tab bar in smaller split views.

import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore
    @State private var selectedTab: AppTab = .explorer

    enum AppTab: String, Hashable {
        case explorer    = "Explorer"
        case collections = "Collections"
        case research    = "Research"
#if os(iOS)
        case settings    = "Settings"
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Explorer", systemImage: "books.vertical", value: AppTab.explorer) {
                ExplorerView()
            }
            Tab("Collections", systemImage: "rectangle.stack", value: AppTab.collections) {
                CollectionsView()
            }
            .badge(collectionStore.collections.isEmpty ? 0 : collectionStore.collections.count)

            Tab("Research", systemImage: "text.badge.checkmark", value: AppTab.research) {
                PromptProfilesView()
            }

#if os(iOS)
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
#endif
        }
#if os(iOS)
        // On iPadOS 18+, the sidebar-style tab bar shows labels alongside icons
        // and collapses gracefully in Split View / Slide Over.
        .tabViewStyle(.sidebarAdaptable)
#endif
    }
}

// MARK: - ExplorerView (three-column NavigationSplitView)

struct ExplorerView: View {
    @Environment(AppStore.self) private var store: AppStore

    var body: some View {
        NavigationSplitView {
            CatalogueView()
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 340)
#endif
        } content: {
            OutlineView()
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
#endif
        } detail: {
            DetailView()
        }
        .navigationTitle("FRUS Explorer")
    }
}
