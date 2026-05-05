// RootView.swift
// Top-level tab view: Explorer | Collections | Research (prompt profiles).

import SwiftUI
import FRUSKit

struct RootView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore
    @State private var selectedTab: AppTab = .explorer

    enum AppTab: String, Hashable {
        case explorer    = "Explorer"
        case collections = "Collections"
        case research    = "Research"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ExplorerView()
                .tabItem { Label("Explorer", systemImage: "books.vertical") }
                .tag(AppTab.explorer)

            CollectionsView()
                .tabItem { Label("Collections", systemImage: "rectangle.stack") }
                .tag(AppTab.collections)
                .badge(collectionStore.collections.isEmpty ? 0 : collectionStore.collections.count)

            PromptProfilesView()
                .tabItem { Label("Research", systemImage: "text.badge.checkmark") }
                .tag(AppTab.research)
        }
    }
}

// MARK: - ExplorerView (three-column layout)

struct ExplorerView: View {
    @Environment(AppStore.self) private var store: AppStore

    var body: some View {
        NavigationSplitView {
            CatalogueView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 340)
        } content: {
            OutlineView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            DetailView()
        }
        .navigationTitle("FRUS Explorer")
    }
}
