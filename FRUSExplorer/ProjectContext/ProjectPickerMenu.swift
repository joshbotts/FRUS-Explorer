// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectPickerMenu

/// Toolbar menu for switching the active project context.
///
/// Shows a `Menu` listing the global context ("Global") plus all user-created
/// projects. A checkmark indicates the current selection. The menu also provides
/// a "Manage Projects" action, whose destination is the host's to decide via
/// `onManageProjects` — `BrowserView` opens the Research tab on iOS, and the
/// macOS menu bar hands off to the Settings Projects pane.
///
/// Uses `@Query` so the list stays in sync without manual reloads.
///
/// ## Accessibility
/// The menu button is labeled "Switch project context" for VoiceOver.
///
/// Version history:
///   1.0 — Session 15: initial implementation
struct ProjectPickerMenu: View {

    @Environment(AppState.self) private var appState
    @Query private var projects: [Project]

    let onManageProjects: () -> Void

    var body: some View {
        Menu {
            // Global context (no active project)
            Button {
                appState.activeProjectId = nil
            } label: {
                if appState.activeProjectId == nil {
                    Label(
                        String(localized: "project.picker.global",
                               defaultValue: "Global Context"),
                        systemImage: "checkmark"
                    )
                } else {
                    Label(
                        String(localized: "project.picker.global",
                               defaultValue: "Global Context"),
                        systemImage: "globe"
                    )
                }
            }

            if !projects.isEmpty {
                Divider()
                ForEach(projects) { project in
                    Button {
                        appState.activeProjectId = project.id
                    } label: {
                        if appState.activeProjectId == project.id {
                            Label(project.name, systemImage: "checkmark")
                        } else {
                            Text(project.name)
                        }
                    }
                }
            }

            Divider()

            Button(action: onManageProjects) {
                Label(
                    String(localized: "project.picker.manage",
                           defaultValue: "Manage Projects"),
                    systemImage: "folder.badge.gearshape"
                )
            }
        } label: {
            Label(currentProjectLabel, systemImage: activeProjectSystemImage)
        }
        .accessibilityLabel(
            String(localized: "project.picker.a11y",
                   defaultValue: "Switch project context")
        )
    }

    // MARK: - Helpers

    private var currentProjectLabel: String {
        guard let pid = appState.activeProjectId else {
            return String(localized: "project.picker.global.short",
                          defaultValue: "Global")
        }
        return projects.first { $0.id == pid }?.name
            ?? String(localized: "project.picker.global.short",
                      defaultValue: "Global")
    }

    private var activeProjectSystemImage: String {
        appState.activeProjectId == nil ? "globe" : "folder"
    }
}

// MARK: - WorkingOnBanner

/// An ambient "Working on: <research question>" line for the Browse and Search chrome (#377 Phase 5).
///
/// Renders only when a project is active AND has a non-empty research question — so Global Context
/// and the silent default project (no question) show nothing, and single-project users are
/// unbothered. Self-contained (`@Query` + `@Environment`), so all four surfaces (Browse / Search ×
/// iOS / macOS) inject one view with a single source of truth for copy, gating, and style — rather
/// than threading the question through the two separate search view-models.
///
/// Reactive with no `.onChange`: `@Query` re-renders when the question is edited, and
/// `activeProjectId` is `@Observable`, so switching projects re-renders. Injected via
/// `.safeAreaInset`, which reserves zero height when the banner is empty.
///
/// Version history:
///   1.0 — #377 Phase 5: initial implementation
///   1.1 — #377 Phase 5 fix: suppressed on regular-width iPad, where a pinned top inset is
///          occluded by the iPadOS floating top tab bar (same as the browser breadcrumb, #238);
///          the research question is surfaced there as a navigation subtitle instead — see
///          `WorkingOnSubtitleModifier` / `View.workingOnSubtitle()`.
struct WorkingOnBanner: View {

    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Whether this pinned top `.safeAreaInset` can render without being hidden by the platform's top
    /// chrome. On **regular-width iPad** the `.sidebarAdaptable` TabView draws a floating top tab bar
    /// that overlays a pinned top inset (it can't be scrolled clear) — the same reason #238 suppresses
    /// the browser breadcrumb there — so the banner is dropped, matching that gate exactly (pad idiom
    /// AND regular width, since a Plus/Max iPhone in landscape or a compact-width iPad keeps the bottom
    /// tab bar). Compact iOS layouts and macOS (no floating tab bar) render it normally.
    private var canRenderInTopInset: Bool {
        #if os(iOS)
        return !(UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular)
        #else
        return true
        #endif
    }

    var body: some View {
        if canRenderInTopInset,
           let question = Self.resolvedQuestion(activeProjectId: appState.activeProjectId, projects: projects) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Text(String(localized: "project.workingOn.prefix", defaultValue: "Working on:")).bold()) \(question)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
            }
        }
    }

    /// The active project's research question to surface, or `nil` when nothing should render: no
    /// active project (Global Context), the active project is absent/deleted, or its research
    /// question is unset/blank. Pure, so the gating is unit-testable without SwiftUI.
    static func resolvedQuestion(activeProjectId: UUID?, projects: [Project]) -> String? {
        guard let pid = activeProjectId,
              let project = projects.first(where: { $0.id == pid }),
              let question = project.researchQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !question.isEmpty
        else { return nil }
        return question
    }
}

// MARK: - WorkingOnSubtitle (regular-width iPad)

/// Surfaces the active project's research question as a **navigation subtitle** on regular-width iPad
/// — where the pinned top-inset `WorkingOnBanner` is suppressed because the `.sidebarAdaptable`
/// floating top tab bar overlays it (#238). A subtitle rides in the title area, which renders cleanly
/// under the floating tab bar, so the "Working on:" context is preserved on iPad without the overlay.
/// No-op on compact iOS and macOS (the banner renders there) and when no project/question is active.
/// Apply it next to the `.navigationTitle` of each surface that hosts the banner (Browse, Search).
private struct WorkingOnSubtitleModifier: ViewModifier {

    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad,
           sizeClass == .regular,
           let question = WorkingOnBanner.resolvedQuestion(activeProjectId: appState.activeProjectId,
                                                           projects: projects) {
            // "Working on: <question>" — reuse the banner's prefix so iPad matches the other surfaces.
            let prefix = String(localized: "project.workingOn.prefix", defaultValue: "Working on:")
            content.navigationSubtitle("\(prefix) \(question)")
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// On regular-width iPad, show the active project's research question as a navigation subtitle in
    /// place of the (suppressed) top-inset "Working on:" banner. See `WorkingOnSubtitleModifier`.
    func workingOnSubtitle() -> some View { modifier(WorkingOnSubtitleModifier()) }
}

// MARK: - SecondProjectNudge (pure decisions)

/// Pure decision helpers for the one-time second-project nudge (#377 Phase 5) — testable without UI.
enum SecondProjectNudge {
    /// The nudge fires when the researcher has reached ≥ 2 projects and hasn't been shown it yet.
    static func shouldNudge(projectCount: Int, alreadyShown: Bool) -> Bool {
        projectCount >= 2 && !alreadyShown
    }

    /// The migration seed: a researcher who ALREADY has ≥ 2 projects when the feature first ships is
    /// marked already-shown, so only a genuine 1 → 2 transition ever nudges (no retro-nudge on the
    /// next project they create).
    static func seedAlreadyShown(projectCount: Int, currentlyShown: Bool) -> Bool {
        currentlyShown || projectCount >= 2
    }
}

// MARK: - SecondProjectNudgeModifier

/// Presents the one-time "you now have a second project — open Project Home?" nudge (#377 Phase 5).
///
/// Applied to the two surfaces that are on screen when a project is created — the iOS tab shell and
/// the macOS Settings window. Driven by the transient `AppState.pendingSecondProjectNudge` signal
/// (set by `ProjectEditorView.saveProject` on reaching the 2nd project) and gated to once-ever by
/// `@AppStorage`. On appear it seeds the flag for pre-existing multi-project users so they are never
/// retro-nudged (only a genuine 1 → 2 transition prompts).
struct SecondProjectNudgeModifier: ViewModifier {

    @Environment(AppState.self) private var appState
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    /// This window's scene id, re-injected into the nudge's Project Home sheet so its hand-offs
    /// target this window on iPad multi-window (#377 follow-up / #338).
    @Environment(\.sceneID) private var sceneID
    #endif
    @Query private var allProjects: [Project]
    @AppStorage("frus.hasShownSecondProjectNudge") private var hasShown = false
    #if os(iOS)
    @State private var homeSheetProjectId: UUID?
    #endif

    func body(content: Content) -> some View {
        content
            .task {
                // Migration seed — don't retro-nudge a user who already has multiple projects.
                if SecondProjectNudge.seedAlreadyShown(projectCount: allProjects.count, currentlyShown: hasShown) {
                    hasShown = true
                }
            }
            .alert(
                String(localized: "project.nudge.secondProject.title", defaultValue: "You have a second project"),
                isPresented: nudgePresented
            ) {
                Button(String(localized: "project.nudge.secondProject.open", defaultValue: "Open Project Home")) {
                    let id = appState.pendingSecondProjectNudge
                    hasShown = true
                    if let id { openProjectHome(id) }
                }
                Button(String(localized: "project.nudge.secondProject.dismiss", defaultValue: "Not now"),
                       role: .cancel) {
                    hasShown = true
                }
            } message: {
                Text(String(localized: "project.nudge.secondProject.message",
                            defaultValue: "Projects keep separate research threads — each with its own collections, notes, and suggestions. Project Home is where you steer one; switch between them from the project menu."))
            }
            #if os(iOS)
            .sheet(isPresented: Binding(
                get: { homeSheetProjectId != nil },
                set: { if !$0 { homeSheetProjectId = nil } }
            )) {
                if let id = homeSheetProjectId {
                    NavigationStack {
                        ProjectHomeView(projectId: id, onNavigateAway: { homeSheetProjectId = nil })
                    }
                    // A sheet doesn't reliably inherit `\.sceneID`; re-inject so Project Home's
                    // hand-offs target this window on iPad multi-window (#338).
                    .environment(\.sceneID, sceneID)
                }
            }
            #endif
    }

    /// True while the transient signal is set and the nudge hasn't been shown; clearing it (alert
    /// dismissed by either button) consumes the signal.
    private var nudgePresented: Binding<Bool> {
        Binding(
            get: { appState.pendingSecondProjectNudge != nil && !hasShown },
            set: { presented in if !presented { appState.pendingSecondProjectNudge = nil } }
        )
    }

    /// Makes the new project active and opens its Project Home — a fresh window on macOS, a sheet on iOS.
    private func openProjectHome(_ id: UUID) {
        appState.activeProjectId = id
        #if os(macOS)
        openWindow(value: ProjectHomeRequest(projectId: id))
        #else
        homeSheetProjectId = id
        #endif
    }
}

extension View {
    /// Attaches the one-time second-project nudge (#377 Phase 5).
    func secondProjectNudge() -> some View { modifier(SecondProjectNudgeModifier()) }
}
