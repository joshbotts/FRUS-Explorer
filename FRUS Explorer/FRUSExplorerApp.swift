// FRUSExplorerApp.swift
// Entry point for FRUSExplorer — macOS and iPadOS.

import SwiftUI

@main
struct FRUSExplorerApp: App {
    @State private var store = AppStore()
    @State private var collectionStore = CollectionStore()
    @State private var profileStore = PromptProfileStore()
    @State private var summaryStore = SummaryStore()
    @State private var taxonomyStore = TaxonomyStore()
    @State private var platformRef: PlatformViewReference? = nil

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(collectionStore)
                .environment(profileStore)
                .environment(summaryStore)
                .environment(taxonomyStore)
                .environment(\.platformViewReference, platformRef)
#if os(macOS)
                .frame(minWidth: 1100, minHeight: 700)
                // Invisible helper that reads the NSWindow once the view
                // is placed in the hierarchy and stores it in platformRef.
                .background(
                    WindowAccessor { window in
                        if self.platformRef == nil {
                            self.platformRef = PlatformViewReference(window: window)
                        }
                    }
                )
#else
                // On iPadOS, capture the hosting UIViewController
                .background(
                    ViewControllerAccessor { vc in
                        if self.platformRef == nil {
                            self.platformRef = PlatformViewReference(viewController: vc)
                        }
                    }
                )
#endif
                .task {
                    // Scan local files immediately so localVolumeIDs is accurate
                    // before RootView decides whether to present the onboarding sheet.
                    store.scanLocalVolumes()
                    store.profileStore = profileStore
                    store.summaryStore = summaryStore
                    store.taxonomyStore = taxonomyStore
                    await taxonomyStore.loadTaxonomy()
                }
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
#endif

        // macOS Settings window — accessible via Cmd+, and the application menu.
        // Kept in a separate #if block so it is a sibling scene in the builder,
        // not chained onto the WindowGroup modifiers above.
#if os(macOS)
        Settings {
            SettingsView()
                .environment(store)
                .environment(summaryStore)
                .environment(profileStore)
                .environment(taxonomyStore)
        }
#endif
    }
}

// MARK: - iPadOS UIViewController accessor

#if !os(macOS)
/// An invisible UIViewControllerRepresentable that provides access to the
/// hosting UIViewController for presenting share sheets.
struct ViewControllerAccessor: UIViewControllerRepresentable {
    let onViewController: @MainActor (UIViewController) -> Void

    func makeUIViewController(context: Context) -> Impl {
        Impl(callback: onViewController)
    }
    func updateUIViewController(_ vc: Impl, context: Context) {}

    final class Impl: UIViewController {
        let callback: @MainActor (UIViewController) -> Void
        init(callback: @escaping @MainActor (UIViewController) -> Void) {
            self.callback = callback
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // parent is the SwiftUI hosting controller
            if let parent {
                Task { @MainActor in self.callback(parent) }
            }
        }
    }
}
#endif
