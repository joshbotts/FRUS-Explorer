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

/// Step 2 of onboarding: choose a download scope.
///
/// Presents three mutually-exclusive options for what the user wants to download:
///
/// - **Entire Corpus** — all 552+ volumes (≈ 3.3 GB). Best for researchers who want
///   everything available offline.
/// - **A Subseries** — pick a decade or diplomatic era from a scrollable list. Downloads
///   only the volumes covering that period.
/// - **A Single Volume** — search by title or volume ID and download just one volume.
///
/// The user's selection populates `viewModel.selectedScope`. "Next" advances to the
/// project-setup step. "Back" returns to the welcome screen.
///
/// The subseries and subject-tag pickers that previously lived in onboarding are now
/// available in Settings → Download Manager for power users who want them post-setup.
///
/// Version history:
///   1.0 — Session 49: initial implementation
@MainActor
struct DownloadScopePickerView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    scopeOptions
                        .padding()
                    if case .subseries = viewModel.selectedScope {
                        subseriesPicker
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    if case .volume = viewModel.selectedScope {
                        singleVolumePicker
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }

            Divider()
            footerButtons
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "onboarding.scope.title",
                        defaultValue: "What Would You Like to Download?"))
                .font(.title2.bold())
            Text(String(localized: "onboarding.scope.subtitle",
                        defaultValue: "You can download more volumes later from Settings."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Scope Options

    private var scopeOptions: some View {
        VStack(spacing: 12) {
            ScopeOptionRow(
                isSelected: {
                    if case .corpus = viewModel.selectedScope { return true }
                    return false
                }(),
                systemImage: "square.stack.3d.up",
                title: String(localized: "onboarding.scope.corpus.title",
                              defaultValue: "Entire Corpus"),
                detail: String(localized: "onboarding.scope.corpus.detail",
                               defaultValue: "552 volumes · ≈ 3.3 GB. Download everything and search the full series.")
            ) {
                viewModel.selectedScope = .corpus
            }

            ScopeOptionRow(
                isSelected: {
                    if case .subseries = viewModel.selectedScope { return true }
                    return false
                }(),
                systemImage: "calendar",
                title: String(localized: "onboarding.scope.subseries.title",
                              defaultValue: "A Subseries"),
                detail: String(localized: "onboarding.scope.subseries.detail",
                               defaultValue: "Choose a decade or diplomatic era.")
            ) {
                viewModel.selectedScope = .subseries(viewModel.selectedSubseries)
            }

            ScopeOptionRow(
                isSelected: {
                    if case .volume = viewModel.selectedScope { return true }
                    return false
                }(),
                systemImage: "doc.text",
                title: String(localized: "onboarding.scope.volume.title",
                              defaultValue: "A Single Volume"),
                detail: String(localized: "onboarding.scope.volume.detail",
                               defaultValue: "Find and download one volume to explore.")
            ) {
                viewModel.selectedScope = .volume(viewModel.singleVolumeSearchText)
            }
        }
    }

    // MARK: - Subseries Picker

    private var subseriesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "onboarding.scope.subseries.picker.label",
                        defaultValue: "Choose a Subseries"))
                .font(.headline)

            if viewModel.allSubseries.isEmpty {
                Text(String(localized: "onboarding.scope.subseries.picker.empty",
                            defaultValue: "No subseries available."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    String(localized: "onboarding.scope.subseries.picker.label",
                           defaultValue: "Choose a Subseries"),
                    selection: $viewModel.selectedSubseries
                ) {
                    Text(String(localized: "onboarding.scope.subseries.picker.placeholder",
                                defaultValue: "Select…"))
                        .tag("")
                    ForEach(viewModel.allSubseries, id: \.self) { subseries in
                        Text(subseries).tag(subseries)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: viewModel.selectedSubseries) { _, newValue in
                    viewModel.selectedScope = .subseries(newValue)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Single Volume Picker

    private var singleVolumePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "onboarding.scope.volume.picker.label",
                        defaultValue: "Search for a Volume"))
                .font(.headline)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    String(localized: "onboarding.scope.volume.picker.placeholder",
                           defaultValue: "Title or volume ID…"),
                    text: $viewModel.singleVolumeSearchText
                )
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onChange(of: viewModel.singleVolumeSearchText) { _, newValue in
                    viewModel.selectedScope = .volume(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                if !viewModel.singleVolumeSearchText.isEmpty {
                    Button {
                        viewModel.singleVolumeSearchText = ""
                        viewModel.selectedScope = .volume("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(
                String(localized: "onboarding.scope.volume.search.a11y",
                       defaultValue: "Search volumes by title or ID")
            )

            if !viewModel.singleVolumeResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.singleVolumeResults) { entry in
                        Button {
                            viewModel.singleVolumeSearchText = entry.volumeId
                            viewModel.selectedScope = .volume(entry.volumeId)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(entry.volumeId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if case .volume(let id) = viewModel.selectedScope, id == entry.volumeId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Footer Buttons

    private var footerButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.step = .welcome
                #if DEBUG
                print("[Onboarding] Step: downloadScope → welcome")
                #endif
            } label: {
                Text(String(localized: "onboarding.scope.back", defaultValue: "Back"))
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                viewModel.step = .projectSetup
                #if DEBUG
                print("[Onboarding] Step: downloadScope → projectSetup. Scope: \(viewModel.resolvedScope)")
                #endif
            } label: {
                Text(String(localized: "onboarding.scope.next", defaultValue: "Next"))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceedFromDownloadScope)
        }
        .padding()
    }
}

// MARK: - ScopeOptionRow

/// A single selectable option card used by `DownloadScopePickerView`.
@MainActor
private struct ScopeOptionRow: View {

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
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
