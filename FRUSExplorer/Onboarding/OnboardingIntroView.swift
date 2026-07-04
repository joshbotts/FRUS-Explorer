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
///   2.1 — Dynamic Type pass 2026-07-04: hero glyph now actually scales
///         (`@ScaledMetric`); the existing accessibility3 cap was dead against
///         the former fixed `.system(size: 52)`.
@MainActor
struct OnboardingIntroView: View {

    @Bindable var viewModel: OnboardingViewModel

    /// Point size of the hero glyph, scaled with Dynamic Type relative to
    /// `.largeTitle`. Capped at accessibility3 at the glyph site.
    @ScaledMetric(relativeTo: .largeTitle) private var heroGlyphSize: CGFloat = 52

    /// The link tapped most recently within `viewModel.introText` —
    /// presented in `InAppBrowserView` instead of the system browser, so
    /// a curious tap on a history.state.gov citation doesn't pull a
    /// first-time user out of onboarding. `URL` conforms to `Identifiable`
    /// (see `CollectionEditorView`), so it can drive `.sheet(item:)` directly.
    @State private var inAppBrowserURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: heroGlyphSize))
                        // Cap the hero icon at accessibility3 so extreme Dynamic Type sizes
                        // don't push the icon into oversized territory (F-007).
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                        .padding(.bottom, 4)

                    Text(String(localized: "onboarding.intro.title",
                                defaultValue: "Welcome to FRUS Explorer"))
                        .font(.largeTitle.bold())

                    Text(String(localized: "onboarding.intro.subtitle",
                                defaultValue: "The Foreign Relations of the United States series, searchable on your device."))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(AttributedString(markdownBody: viewModel.introText))
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
        // Route inline Markdown link taps in `introText` into the in-app
        // browser instead of the system browser.
        .environment(\.openURL, OpenURLAction { url in
            inAppBrowserURL = url
            return .handled
        })
        .sheet(item: $inAppBrowserURL) { url in
            InAppBrowserView(url: url)
        }
    }
}
