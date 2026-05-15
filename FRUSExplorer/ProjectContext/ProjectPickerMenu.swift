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
