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
/// a "Manage Projects" action that opens `ProjectContextView`.
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
struct WorkingOnBanner: View {

    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        if let question = Self.resolvedQuestion(activeProjectId: appState.activeProjectId, projects: projects) {
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
