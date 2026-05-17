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

/// First step of onboarding: introductory text about the FRUS series.
///
/// Displays intro text loaded from history.state.gov (or bundled fallback) and
/// a "Get Started" button to advance to the volume picker step.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   2.0 — Session 49: CTA advances to .downloadScope (was .volumePicker)
@MainActor
struct OnboardingIntroView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .padding(.bottom, 4)

                    Text(String(localized: "onboarding.intro.title",
                                defaultValue: "Welcome to FRUS Explorer"))
                        .font(.largeTitle.bold())

                    Text(String(localized: "onboarding.intro.subtitle",
                                defaultValue: "The complete Foreign Relations of the United States series, searchable on your device."))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(viewModel.introText)
                    .font(.body)
                    .lineSpacing(4)

                Spacer(minLength: 32)

                Button {
                    viewModel.step = .downloadScope
                    #if DEBUG
                    print("[Onboarding] Step: welcome → downloadScope")
                    #endif
                } label: {
                    Text(String(localized: "onboarding.intro.cta",
                                defaultValue: "Get Started"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
        }
        #if os(macOS)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        #endif
    }
}
