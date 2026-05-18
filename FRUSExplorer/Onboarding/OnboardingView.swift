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

/// Three-step onboarding flow for FRUS Explorer.
///
/// ## Steps
/// 1. **Welcome** — brief introduction to the app and its corpus
/// 2. **Add Volumes** — select and download FRUS volumes from the manifest
/// 3. **Ready** — confirmation screen; tapping Finish completes onboarding
///
/// ## Invisible Project Creation
/// When onboarding completes, `ensureDefaultProjectExists()` silently creates a
/// "My Research" project if none exists. The user never sees a project-setup step.
/// `AppState.activeProjectId` is set to the new project's `id` before the main UI
/// appears, so all activity from the first session is attributed to that project.
///
/// ## Offline Handling
/// An inline banner appears at the top when the device is offline. The volume list
/// falls back to the bundled manifest entries so the flow remains navigable.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   2.0 — Session 49: redesigned to three-step flow
///   3.0 — New UI: self-contained flow; project setup removed (created silently)
@MainActor
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var step: OnboardingStep = .welcome

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isOnline {
                offlineBanner
            }

            // Step dot indicator
            stepIndicator
                .padding(.top, 24)
                .padding(.bottom, 20)

            // Step content
            Group {
                switch step {
                case .welcome:  welcomeView
                case .addVolumes: addVolumesView
                case .ready:    readyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            navigationRow
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 16)
        }
        #if os(macOS)
        .frame(width: 560, height: 540)
        #endif
        .animation(.easeInOut(duration: 0.2), value: appState.isOnline)
        .animation(.easeInOut(duration: 0.22), value: step)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases) { s in
                StepDot(index: s.index, label: s.label, isCurrent: s == step, isPast: s.index < step.index)
            }
        }
    }

    // MARK: - Welcome Step

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)

            Text("Welcome to FRUS Explorer")
                .font(.title2.weight(.semibold))

            Text("""
                FRUS Explorer gives you full-text search, cross-reference navigation, \
                and AI-assisted research over the Foreign Relations of the United States \
                documentary series — the official record of U.S. foreign policy since 1861.
                """)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("You can add volumes now or skip ahead and add them later from the Corpus Browser.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Add Volumes Step

    private var addVolumesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Volumes")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 24)

            Text("Choose the volumes you want to download. You can add more later from the Corpus Browser.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
            if entries.isEmpty {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries.prefix(200)) { entry in
                            VolumeDownloadRow(entry: entry)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .task {
            if appState.isOnline {
                await appState.manifestStore.refresh()
            }
        }
    }

    // MARK: - Ready Step

    private var readyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .padding(.bottom, 4)

            Text("You're all set")
                .font(.title2.weight(.semibold))

            if hasIndexedVolume {
                Text("Your volumes are being indexed. Search and cross-reference navigation will be available shortly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("No volumes are downloading yet — you can add them any time from the Corpus Browser (⇧⌘B).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Text("A default research project has been created for you. You can rename it or create additional projects from the project picker.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Navigation Row

    private var navigationRow: some View {
        HStack {
            // Back button (hidden on first step)
            if step != .welcome {
                Button("Back") {
                    if let prev = step.previous {
                        step = prev
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Skip volumes button (only on addVolumes step)
            if step == .addVolumes {
                Button("Skip") {
                    step = .ready
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
            }

            // Continue / Finish button
            Button(step.continueLabel) {
                if let next = step.next {
                    step = next
                } else {
                    Task { await completeOnboarding() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("You are offline. Showing bundled catalog only.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.yellow.opacity(0.2))
        .foregroundStyle(.primary)
    }

    // MARK: - Completion

    private func completeOnboarding() async {
        await ensureDefaultProjectExists()
        appState.hasCompletedOnboarding = true
    }

    /// Creates a "My Research" project if no projects exist yet.
    /// Sets `appState.activeProjectId` so the first session is attributed to it.
    private func ensureDefaultProjectExists() async {
        do {
            let descriptor = FetchDescriptor<Project>()
            let count = try modelContext.fetchCount(descriptor)
            guard count == 0 else { return }

            let defaultProject = Project(name: "My Research")
            modelContext.insert(defaultProject)
            try modelContext.save()
            appState.activeProjectId = defaultProject.id

            #if DEBUG
            print("[OnboardingView] Default project created: \(defaultProject.id)")
            #endif
        } catch {
            #if DEBUG
            print("[OnboardingView] Failed to create default project: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// True if at least one volume is currently queued or downloading.
    private var hasIndexedVolume: Bool {
        !appState.downloadQueue.isEmpty
    }
}

// MARK: - OnboardingStep

private enum OnboardingStep: CaseIterable, Identifiable {
    case welcome, addVolumes, ready

    var id: Self { self }

    var index: Int {
        switch self {
        case .welcome:    return 0
        case .addVolumes: return 1
        case .ready:      return 2
        }
    }

    var label: String {
        switch self {
        case .welcome:    return "Welcome"
        case .addVolumes: return "Volumes"
        case .ready:      return "Ready"
        }
    }

    var continueLabel: String {
        switch self {
        case .welcome:    return "Get Started"
        case .addVolumes: return "Continue"
        case .ready:      return "Finish"
        }
    }

    var next: OnboardingStep? {
        switch self {
        case .welcome:    return .addVolumes
        case .addVolumes: return .ready
        case .ready:      return nil
        }
    }

    var previous: OnboardingStep? {
        switch self {
        case .welcome:    return nil
        case .addVolumes: return .welcome
        case .ready:      return .addVolumes
        }
    }
}

// MARK: - StepDot

private struct StepDot: View {
    let index: Int
    let label: String
    let isCurrent: Bool
    let isPast: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.accentColor : (isPast ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15)))
                    .frame(width: 28, height: 28)
                if isPast {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
        }
    }
}

// MARK: - VolumeDownloadRow

private struct VolumeDownloadRow: View {
    let entry: VolumeManifestEntry

    @Environment(AppState.self) private var appState

    private var isQueued: Bool {
        appState.downloadQueue.contains(entry.volumeId)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.volumeId)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isQueued {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 36, height: 36)
            } else {
                Button {
                    Task { await enqueue() }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func enqueue() async {
        guard let dm = appState.downloadManager else { return }
        await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: entry.downloadUrl)
    }
}
