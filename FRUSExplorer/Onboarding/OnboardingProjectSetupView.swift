// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData

/// Fourth step of onboarding: project setup.
///
/// Collects a project name (required), research question (optional), date range
/// pickers (optional), and default tag selections (optional). On "Create Project",
/// inserts a `Project` into SwiftData and sets `appState.activeProjectId`.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   2.0 — Session 49: back now returns to .downloadScope; "Create Project" enqueues
///          downloads and completes onboarding in one step; pre-fill from corpus dates
///   2.1 — Session 57: "Skip for now" button creates a default-named project; name-required
///          error softened to a hint; proceed logic extracted to proceedWithProject() (F-009)
@MainActor
struct OnboardingProjectSetupView: View {

    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// Used to preserve the system color scheme on unselected tag chips so that
    /// forcing `.dark` on selected chips does not affect surrounding content (F-012).
    @Environment(\.colorScheme) private var colorScheme

    @State private var showDateRangePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "onboarding.project.title",
                                defaultValue: "Set Up Your Project"))
                        .font(.title.bold())
                    Text(String(localized: "onboarding.project.subtitle",
                                defaultValue: "Projects help you focus your research. You can create more later in Settings."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Name (required)
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        String(localized: "onboarding.project.name.label",
                               defaultValue: "Project Name"),
                        systemImage: "folder"
                    )
                    .font(.headline)
                    TextField(
                        String(localized: "onboarding.project.name.placeholder",
                               defaultValue: "e.g. Cold War Diplomacy"),
                        text: $viewModel.projectName
                    )
                    .textFieldStyle(.roundedBorder)

                    if viewModel.projectName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(String(localized: "onboarding.project.name.hint",
                                    defaultValue: "Enter a name, or tap Skip for now to use a default."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Research question (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        String(localized: "onboarding.project.question.label",
                               defaultValue: "Research Question"),
                        systemImage: "questionmark.circle"
                    )
                    .font(.headline)
                    Text(String(localized: "onboarding.project.question.hint",
                                defaultValue: "Optional — helps focus AI summarization."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        String(localized: "onboarding.project.question.placeholder",
                               defaultValue: "What were the key turning points in…"),
                        text: $viewModel.projectQuestion,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                }

                // Date range (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        String(localized: "onboarding.project.dateRange.label",
                               defaultValue: "Default Date Range"),
                        systemImage: "calendar"
                    )
                    .font(.headline)
                    Text(String(localized: "onboarding.project.dateRange.hint",
                                defaultValue: "Optional — narrows search results by default."))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "onboarding.project.dateRange.start",
                                        defaultValue: "Start"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker(
                                String(localized: "onboarding.project.dateRange.start",
                                       defaultValue: "Start"),
                                selection: Binding(
                                    get: { viewModel.projectDateStart ?? Date(timeIntervalSince1970: 0) },
                                    set: { viewModel.projectDateStart = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "onboarding.project.dateRange.end",
                                        defaultValue: "End"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker(
                                String(localized: "onboarding.project.dateRange.end",
                                       defaultValue: "End"),
                                selection: Binding(
                                    get: { viewModel.projectDateEnd ?? Date() },
                                    set: { viewModel.projectDateEnd = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }

                        Spacer()

                        if viewModel.projectDateStart != nil || viewModel.projectDateEnd != nil {
                            Button {
                                viewModel.projectDateStart = nil
                                viewModel.projectDateEnd = nil
                            } label: {
                                Text(String(localized: "onboarding.project.dateRange.clear",
                                            defaultValue: "Clear"))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // (The former "Default Subject Tags" control was removed in Session 09:
                // document-level subject-tag search filtering was retired for low
                // signal-to-noise, so pre-selecting subject tags no longer affects
                // searches. The successor volume-level subject feature lives in the
                // volume detail view, not onboarding.)

                Spacer(minLength: 32)
            }
            .padding(24)
        }

        Divider()

        footerButtons
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.step = .downloadScope
            } label: {
                Text(String(localized: "onboarding.project.back", defaultValue: "Back"))
            }
            .buttonStyle(.bordered)

            Spacer()

            // "Skip for now" creates a default-named project so the user is not blocked
            // by the name requirement during first launch. The project can be renamed in
            // Settings at any time.
            Button {
                if viewModel.projectName.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.projectName = String(localized: "onboarding.defaultProject",
                                                  defaultValue: "My Project")
                }
                proceedWithProject()
            } label: {
                Text(String(localized: "onboarding.project.skip", defaultValue: "Skip for now"))
            }
            .buttonStyle(.bordered)

            Button {
                proceedWithProject()
            } label: {
                Text(String(localized: "onboarding.project.create", defaultValue: "Get Started"))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceedFromProjectSetup)
        }
        .padding()
    }

    /// Creates the project and completes onboarding, enqueuing any chosen downloads.
    private func proceedWithProject() {
        let project = viewModel.createProject(context: modelContext)
        appState.activeProjectId = project.id
        // Enqueue the chosen downloads and complete onboarding in one step.
        // Downloads run in the background; the user lands immediately in the browser.
        let scope = viewModel.resolvedScope
        if let dm = appState.downloadManager {
            Task {
                await viewModel.enqueueScope(downloadManager: dm)
            }
        } else {
            // DownloadManager not yet booted — park scope for pickup after boot.
            appState.pendingDownloadScope = scope
        }
        appState.hasCompletedOnboarding = true
        #if DEBUG
        print("[Onboarding] Complete. Project id=\(project.id), scope=\(scope)")
        #endif
    }
}

// MARK: - Flow Layout (local copy for this file)

private struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                totalHeight += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
