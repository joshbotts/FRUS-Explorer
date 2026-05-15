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

/// Fifth (final) step of onboarding: prompt setup stub.
///
/// Informs the user that custom summarization prompts can be configured in Settings.
/// The app ships with a standard summary prompt. Tapping "Get Started" completes
/// onboarding; the re-entry trigger (`hasDownloadedVolumes`) will take over on next launch.
///
/// Version history:
///   1.0 — Session 10: initial implementation
@MainActor
struct OnboardingPromptSetupView: View {

    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "text.bubble.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text(String(localized: "onboarding.prompt.title",
                            defaultValue: "AI Summarization"))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(String(localized: "onboarding.prompt.body",
                            defaultValue: "You can create custom summarization prompts in Settings. For now, the app includes a standard summary prompt."))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            Button {
                #if DEBUG
                print("[Onboarding] Step: promptSetup → complete (Get Started tapped)")
                #endif
                // Onboarding is done. ContentView will switch to the main app view
                // once hasDownloadedVolumes returns true (after downloads complete).
                // For now, nothing further to navigate — this view will remain until
                // the first XML file lands in the volumes directory.
            } label: {
                Text(String(localized: "onboarding.prompt.cta", defaultValue: "Get Started"))
                    .frame(minWidth: 200)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        #if os(macOS)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        #endif
    }
}
