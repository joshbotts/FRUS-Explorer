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

/// The design hand-off's 1a splash — but only on launches that have earned it.
///
/// ## It is an overlay, not a first frame
/// The (d) predicates are only knowable *after* container init and observer install, so this
/// cannot be present at frame zero and does not try to be. The pre-render window is covered
/// by the iOS launch screen (option (a)'s static half, shipped in #529); this picks up the
/// same composition once SwiftUI is running, so the two read as one moment rather than a
/// screen replaced by a different screen. **Keep them in step.**
///
/// ## Dismissal differs by reason, deliberately
/// - `.cloudKitImport` dismisses when the import settles — a real wait, of real duration.
/// - `.freshInstall` has nothing to wait for, so it holds briefly and flows into
///   onboarding's own cloud. That hold is **once per install**, not a per-launch floor: the
///   plan explicitly rules out a fixed display floor on every cold launch as "a permanent
///   tax on a tool people open repeatedly", and this is not that.
///
/// Version history:
///   1.0 — O-3: initial implementation
struct LaunchSplashView: View {

    /// Why this splash is showing. Governs how long it stays.
    let reason: CloudSurface.SplashReason

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.systemBackgroundCompat).ignoresSafeArea()

                // Full strength here — the splash is the one surface the cloud owns
                // outright, with no docked glass to stay legible over.
                WordCloudBackdropView(
                    scope: .corpus,
                    dim: FRUSTheme.cloudDimSplash,
                    exclusionZones: [identityZone(in: proxy.size)],
                    showsChip: true
                )
                .ignoresSafeArea()

                // Under Reduce Transparency the identity block gets an opaque card, so it
                // never has to be read against moving words.
                if reduceTransparency {
                    identityBlock
                        .padding(24)
                        .cloudSurfaceBackground(cornerRadius: 20, solid: true)
                } else {
                    identityBlock
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Self.accessibilityLabel))
        .transition(.opacity)
    }

    /// The centre block the cloud is kept out from under — matching the launch screen's
    /// composition so the hand-off between them is invisible.
    private var identityBlock: some View {
        VStack(spacing: 14) {
            // Compile-checked symbol, not a string — a typo here used to be a blank tile
            // at runtime. Enabled by ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS.
            Image(.launchAppTile)
                .resizable()
                .frame(width: tileSize, height: tileSize)
            Text(Self.wordmark)
                .font(.system(size: wordmarkSize, weight: .semibold))
            Text(Self.caption)
                .font(.system(size: captionSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            shimmerBar
                .padding(.top, 10)
        }
        .padding(.horizontal, 32)
    }

    /// A determinate-looking bar for an indeterminate wait. Honest enough: it says "working",
    /// not "this far along", and it stops moving under Reduce Motion.
    private var shimmerBar: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion
                ? 0.5
                : (sin(context.date.timeIntervalSinceReferenceDate * 2.0) + 1) / 2
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                Capsule().fill(Color.accentColor)
                    .frame(width: 46)
                    .offset(x: (140 - 46) * phase)
            }
            .frame(width: 140, height: 3)
        }
        .accessibilityHidden(true)
    }

    private func identityZone(in size: CGSize) -> CGRect {
        let width: CGFloat = min(340, size.width - 48)
        let height: CGFloat = 260
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                      width: width, height: height)
    }

    // MARK: - Copy

    static let wordmark = String(localized: "splash.wordmark", defaultValue: "FRUS Explorer")
    static let caption = String(localized: "splash.caption",
        defaultValue: "Foreign Relations of the United States · since 1861")
    static let accessibilityLabel = String(localized: "splash.accessibility",
        defaultValue: "FRUS Explorer is opening your library.",
        comment: "Spoken description of the launch splash")

    // MARK: - Metrics

    #if os(macOS)
    private var tileSize: CGFloat { 76 }
    private var wordmarkSize: CGFloat { 20 }
    private var captionSize: CGFloat { 12 }
    #else
    private var tileSize: CGFloat { 88 }
    private var wordmarkSize: CGFloat { 22 }
    private var captionSize: CGFloat { 13 }
    #endif
}

// MARK: - Cross-platform background

extension ShapeStyle where Self == Color {
    /// The window/system background, spelled once for both platforms.
    static var systemBackgroundCompat: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}
