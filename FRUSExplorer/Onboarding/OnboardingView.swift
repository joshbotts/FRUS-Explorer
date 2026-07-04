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
/// 2. **Scope** — choose download scope (corpus / subseries / volume) with an
///    appropriate picker for each choice
/// 3. **Ready** — confirmation; tapping Finish completes onboarding and creates
///    a default project if none exists
///
/// ## Download Scope Choices
/// - **Entire Corpus** — enqueues all volumes on Continue; no further picker shown.
/// - **A Subseries** — shows a scrollable list of subseries sorted newest-first;
///   user must select one before Continue is enabled.
/// - **A Single Volume** — shows a grouped list with volumes nested under
///   collapsible subseries (sorted newest-first); user must select a volume.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   2.0 — Session 49: redesigned to three-step flow
///   3.0 — New UI: self-contained flow; project setup removed (created silently)
///   3.1 — Replaced flat volume list with scope picker (corpus/subseries/volume)
///   3.2 — Dynamic Type pass 2026-07-04: hero glyphs scale (`@ScaledMetric`,
///         capped at accessibility3); StepDot label uses `.caption2`.
@MainActor
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var step: OnboardingStep = .welcome

    /// Point size of the welcome / ready hero glyphs, scaled with Dynamic Type
    /// (relative to `.largeTitle`) so the icon grows with the body text it pairs
    /// with. Growth is capped at accessibility3 at the glyph sites so extreme
    /// sizes don't overwhelm the step layout.
    @ScaledMetric(relativeTo: .largeTitle) private var heroGlyphSize: CGFloat = 56

    // MARK: - Step 2 State

    private enum ScopeChoice { case corpus, subseries, volume }
    @State private var scopeChoice: ScopeChoice = .corpus
    @State private var selectedSubseries: String = ""
    @State private var selectedVolumeId: String = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isOnline {
                offlineBanner
            }

            stepIndicator
                .padding(.top, 24)
                .padding(.bottom, 20)

            Group {
                switch step {
                case .welcome:    welcomeView
                case .addVolumes: scopePickerView
                case .ready:      readyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .font(.system(size: heroGlyphSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
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

    // MARK: - Scope Picker Step

    private var scopePickerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("What Would You Like to Download?")
                    .font(.title3.weight(.semibold))
                Text("You can download more volumes later from Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Scope option cards
            VStack(spacing: 8) {
                ScopeCard(
                    isSelected: scopeChoice == .corpus,
                    systemImage: "square.stack.3d.up",
                    title: "Entire Corpus",
                    detail: "552+ volumes · ≈ 3.3 GB. Download everything for full offline search."
                ) { scopeChoice = .corpus }

                ScopeCard(
                    isSelected: scopeChoice == .subseries,
                    systemImage: "calendar",
                    title: "A Subseries",
                    detail: "Choose a decade or diplomatic era."
                ) { scopeChoice = .subseries; selectedSubseries = "" }

                ScopeCard(
                    isSelected: scopeChoice == .volume,
                    systemImage: "doc.text",
                    title: "A Single Volume",
                    detail: "Find and download one volume to explore."
                ) { scopeChoice = .volume; selectedVolumeId = "" }
            }
            .padding(.horizontal, 24)

            // Conditional picker
            switch scopeChoice {
            case .corpus:
                Spacer()
            case .subseries:
                Divider().padding(.top, 12)
                subseriesPickerView
            case .volume:
                Divider().padding(.top, 12)
                volumeGroupedPickerView
            }
        }
        .task {
            if appState.isOnline {
                await appState.manifestStore.refresh()
            }
        }
    }

    // MARK: - Subseries Picker

    private var subseriesPickerView: some View {
        List(allSubseries, id: \.self) { sub in
            Button {
                selectedSubseries = sub
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        let count = allVolumes.filter { $0.subseries == sub }.count
                        Text("\(count) volume\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedSubseries == sub {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    // MARK: - Volume Grouped Picker

    private var volumeGroupedPickerView: some View {
        List {
            ForEach(volumesBySubseries, id: \.subseries) { group in
                DisclosureGroup {
                    ForEach(group.volumes) { vol in
                        Button {
                            selectedVolumeId = vol.volumeId
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vol.title)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(vol.volumeId)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if selectedVolumeId == vol.volumeId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                        .padding(.top, 2)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                } label: {
                    HStack {
                        Text(group.subseries)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Text("\(group.volumes.count) vol\(group.volumes.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Ready Step

    private var readyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: heroGlyphSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
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
                #if os(macOS)
                Text("Download volumes whenever you like from the Corpus Browser (⇧⌘B) to search and read them offline.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                #else
                Text("Download volumes whenever you like from the Browse tab to search and read them offline.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                #endif
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
            if step != .welcome {
                Button("Back") {
                    if let prev = step.previous { step = prev }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if step == .addVolumes {
                Button("Skip") { step = .ready }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }

            Button(step.continueLabel) {
                if step == .addVolumes {
                    Task { await enqueueAndAdvance() }
                } else if let next = step.next {
                    step = next
                } else {
                    Task { await completeOnboarding() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(step == .addVolumes && !canProceedFromScope)
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

    // MARK: - Derived Data

    private var allVolumes: [VolumeManifestEntry] {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }
    }

    /// Subseries sorted newest-first by the leading four-digit year.
    private var allSubseries: [String] {
        let unique = Set(allVolumes.map(\.subseries))
        return unique.sorted { startYear(from: $0) > startYear(from: $1) }
    }

    /// Volumes grouped by subseries, subseries sorted newest-first.
    private var volumesBySubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        allSubseries.map { sub in
            (sub, allVolumes.filter { $0.subseries == sub })
        }
    }

    private func startYear(from subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    // MARK: - Validation

    private var canProceedFromScope: Bool {
        switch scopeChoice {
        case .corpus:    return true
        case .subseries: return !selectedSubseries.isEmpty
        case .volume:    return !selectedVolumeId.isEmpty
        }
    }

    // MARK: - Actions

    private func enqueueAndAdvance() async {
        if let dm = appState.downloadManager {
            let volumes: [VolumeManifestEntry]
            switch scopeChoice {
            case .corpus:
                volumes = allVolumes
            case .subseries:
                volumes = allVolumes.filter { $0.subseries == selectedSubseries }
            case .volume:
                volumes = allVolumes.filter { $0.volumeId == selectedVolumeId }.prefix(1).map { $0 }
            }
            for entry in volumes {
                await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: entry.downloadUrl)
            }
        }
        step = .ready
    }

    private func completeOnboarding() async {
        await ensureDefaultProjectExists()
        appState.hasCompletedOnboarding = true
    }

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
        case .addVolumes: return "Scope"
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
        case .addVolumes: return nil
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
                // The number / checkmark sits inside a fixed 28 pt circle, so its
                // glyph stays a fixed point size — scaling it with Dynamic Type
                // would clip inside the badge. The label below scales freely.
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
                .font(.caption2)
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
        }
    }
}

// MARK: - ScopeCard

private struct ScopeCard: View {
    let isSelected: Bool
    let systemImage: String
    let title: String
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 28, alignment: .top)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
