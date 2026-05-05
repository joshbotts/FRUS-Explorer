// FRUSExplorerApp.swift
// Entry point for the FRUSExplorer macOS application.

import SwiftUI

@main
struct FRUSExplorerApp: App {
    @State private var store = AppStore()
    @State private var collectionStore = CollectionStore()
    @State private var profileStore = PromptProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(collectionStore)
                .environment(profileStore)
                .frame(minWidth: 1100, minHeight: 700)
                .task {
                    // Wire profileStore into AppStore after both are initialised.
                    // AppStore.profileStore is a plain var (not @Published) so this
                    // assignment does not trigger a view update loop.
                    store.profileStore = profileStore
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
