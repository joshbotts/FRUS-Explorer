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

/// Root container for the multi-step onboarding flow.
///
/// Creates and owns `OnboardingViewModel`, dispatches to each step view, and handles
/// the offline banner. The onboarding trigger (whether to show this vs. the main app)
/// is determined by `OnboardingViewModel.hasDownloadedVolumes(in:)` in `ContentView`.
///
/// Version history:
///   1.0 — Session 10: initial implementation
@MainActor
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    if !appState.isOnline {
                        offlineBanner
                    }
                    stepContent(vm: vm)
                }
                .animation(.easeInOut(duration: 0.2), value: appState.isOnline)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(
                    manifestStore: appState.manifestStore,
                    tagStore: appState.volumeLevelTagStore,
                    volumesDirectory: appState.downloadManager?.volumesDirectory
                )
            }
        }
    }

    // MARK: - Step Dispatch

    @ViewBuilder
    private func stepContent(vm: OnboardingViewModel) -> some View {
        switch vm.step {
        case .intro:
            OnboardingIntroView(viewModel: vm)
        case .volumePicker:
            OnboardingVolumePickerView(viewModel: vm)
        case .downloadConfirm:
            OnboardingDownloadView(viewModel: vm)
        case .projectSetup:
            OnboardingProjectSetupView(viewModel: vm)
        case .promptSetup:
            OnboardingPromptSetupView(viewModel: vm)
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(String(localized: "onboarding.offline.banner",
                        defaultValue: "You are offline. Showing bundled catalog only."))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.yellow.opacity(0.2))
        .foregroundStyle(.primary)
    }
}
