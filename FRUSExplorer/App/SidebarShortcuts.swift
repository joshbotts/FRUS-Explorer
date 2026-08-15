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

// MARK: - SidebarShortcuts

/// The researcher's own objects, in the iPad tab sidebar's empty column (UI review F-3).
///
/// ## What F-3 asked for, and what it actually gets
/// `.sidebarAdaptable` exists so a tab app can grow real navigation on iPad, and `MainTabView`
/// declared five flat `Tab`s and nothing else — five rows above an empty column. (The review says
/// "~900 pt of empty column"; measured, it is nearer **510 pt**, which is still most of the
/// sidebar.) The owner's decision was **saved searches and projects**: Collections is already the
/// fourth row, so listing it here would duplicate a tab, and recent volumes were excluded.
///
/// ## Why this is a sidebar FOOTER and not `TabSection`
/// The review names `TabSection`, and that is the Apple-sanctioned shape — but it is not free
/// here, and the cost is structural rather than effortful. `TabSection`'s children must be `Tab`s,
/// every `Tab` must carry a `value` of the **selection binding's type**, and this TabView's
/// selection is `@SceneStorage("frus.selectedTab") var selectedTab: AppTab` — a `String`-raw enum
/// that is *persisted across launches* and threaded through `AppState.openTab`,
/// `consumePendingTab`, `seedActiveTab`, and roughly twenty hand-off sites. Adding saved searches
/// as tabs therefore means widening that type to a composite, re-keying its `SceneStorage`, and
/// touching every hand-off — a change to how the app remembers where you were, in exchange for a
/// list of shortcuts.
///
/// There is also a semantic objection, and it is the one that decided it: a saved search is not a
/// peer of Browse and Search. It is a *shortcut that runs somewhere* — in the Search tab, on the
/// query it stores. Making it a tab would give it a persistent root of its own and a place in the
/// selection the app restores into, which is not what a saved search is.
///
/// So the shortcuts live in `.tabViewSidebarFooter`, which fills the same empty column, takes
/// ordinary `View` content, and leaves tab identity alone. If the owner later wants true
/// `TabSection`s, the identity widening is the prerequisite and this file is what it replaces.
///
/// ## iPad only, by construction
/// The footer renders in the sidebar representation, which iPhone never shows — but the `@Query`
/// pair would still run there, so the whole view is gated on the pad idiom. iPhone's bottom tab
/// bar is untouched, which is the promise `.sidebarAdaptable` was adopted under (#238).
///
/// Version history:
///   1.0 — CW-11 (UI review F-3): saved searches + projects in the sidebar footer
struct SidebarShortcuts: View {

    /// Routes a chosen saved search into the Search tab, and reads the active project.
    @Environment(AppState.self) private var appState
    /// Addresses the hand-off to this window, so a second iPad window does not also react.
    @Environment(\.sceneID) private var sceneID

    /// Most recently used first — the same order the Saved Searches surface presents.
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]

    /// The user's projects, newest first.
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    /// How many of each list the footer shows before it stops.
    ///
    /// A cap rather than a scroll view: the footer sits under five tabs in a column the sidebar
    /// also has to fit, and an unbounded list of forty saved searches would push the tabs out of
    /// reach. Five is what fits the measured void without crowding it.
    private static let displayLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !savedSearches.isEmpty {
                section(
                    title: String(localized: "sidebar.savedSearches",
                                  defaultValue: "Saved Searches"),
                    systemImage: "bookmark") {
                        ForEach(savedSearches.prefix(Self.displayLimit)) { saved in
                            shortcutRow(saved.name.isEmpty
                                        ? String(localized: "sidebar.savedSearch.untitled",
                                                 defaultValue: "Untitled search")
                                        : saved.name) {
                                run(saved)
                            }
                        }
                    }
            }
            if !projects.isEmpty {
                section(
                    title: String(localized: "sidebar.projects", defaultValue: "Projects"),
                    systemImage: "folder") {
                        ForEach(projects.prefix(Self.displayLimit)) { project in
                            shortcutRow(project.name.isEmpty
                                        ? String(localized: "sidebar.project.untitled",
                                                 defaultValue: "Untitled project")
                                        : project.name,
                                        isActive: project.id == appState.activeProjectId) {
                                appState.activeProjectId = project.id
                            }
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    /// One titled group of shortcuts.
    @ViewBuilder
    private func section(title: String,
                         systemImage: String,
                         @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                // A test hook, and it is load-bearing rather than decorative: "Projects" also
                // names a row in Settings, so a UI test matching that word alone passes with this
                // whole footer deleted — which is exactly what the first version of scenario 12
                // did. The identifier is unique to the sidebar.
                .accessibilityIdentifier("SidebarShortcuts.\(systemImage)")
            rows()
        }
    }

    /// One shortcut. `isActive` marks the project the app is currently working in.
    private func shortcutRow(_ title: String,
                             isActive: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            // Without a greedy frame the row is only as wide as its text, so the tap target is
            // the glyphs rather than the row — the defect #312 fixed for the browser lists.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }

    /// Runs a saved search in the Search tab of THIS window.
    ///
    /// Uses the same two-part hand-off every other producer uses — the payload plus
    /// `openTab` — rather than reaching into the Search tab directly, so a saved search behaves
    /// exactly like the existing Saved Searches surface and addresses only this scene.
    private func run(_ saved: SavedSearch) {
        appState.openSearch(saved.searchParameters, from: sceneID)
        appState.openTab(.search, from: sceneID)
    }
}
#endif
