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
///   1.1 — the backdrop fades in when the vectors arrive instead of popping. This surface is now
///         reachable BEFORE they have (see `CloudSurfaceArbiter.resolve`, which used to gate every
///         branch on them and so made this view unreachable entirely), which is the composition the
///         launch screen hands over: identity only, then the cloud.
///   1.5 — `LaunchIdentityMetrics`: the block's sizes are per idiom, and the iPad tile is 176 pt.
///   1.4 — `identityZones`: the tile's square and the text strip are protected separately, so
///         the cloud reaches the glass instead of stopping at a 340 x 260 rect around the block.
///   1.3 — the icon sits on a layout-neutral Liquid Glass backplate (`LaunchIdentityBlock` 1.1).
///   1.2 — the identity block is `LaunchIdentityBlock`, shared with onboarding's welcome step, and
///         the tile it draws is the app icon. Launch screen → splash → onboarding now keep one
///         icon in one place; before, the launch screen and splash drew a generic blue tile that
///         appeared nowhere else, and onboarding drew no identity at all.
struct LaunchSplashView: View {

    /// Why this splash is showing. Governs how long it stays.
    let reason: CloudSurface.SplashReason

    /// Read for `areCloudVectorsReady` only — the observable mirror of the vector store, which is
    /// static state Observation cannot see. Safe to declare here because this view has exactly one
    /// host, `ContentViewWithSplash`, which puts `AppState` in the environment.
    @Environment(AppState.self) private var appState
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
                    exclusionZones: Self.identityZones(in: proxy.size,
                                                       safeAreaInsets: proxy.safeAreaInsets),
                    showsChip: true,
                    // The particle field, on the one surface composed for it (visual-marketing
                    // plan §3.2, M-4). The static renderer gets no expansion and no bleed, so
                    // today's splash is the "clump stranded in an empty expanse" the field's v1.2
                    // spread exists to fix; full-bleed and full-screen, this is the only surface
                    // that holds the composition the code was written for long enough to read it.
                    //
                    // It is also the first shipping surface to drift WITH an exclusion zone, which
                    // is why `WordCloudDriftField.push`'s bleed re-clamp had to be fixed in the
                    // same change: until now nothing exercised that path.
                    //
                    // Reduce Motion is already handled downstream — `WordCloudBackdropView` hands
                    // the flag to the canvas, which pins the MOTION clock so the field is drawn at
                    // its packed layout. The lens rotation deliberately continues (at 6 Hz), on the
                    // canvas's own stated rule that Reduce Motion simplifies a transition rather
                    // than removing it; so the splash still crossfades, it just does not drift.
                    drift: true,
                    // SEEDED, never randomised (visual-marketing §3.2, M-5). This surface is the
                    // App Preview's opening frame, a store screenshot and the README hero at once;
                    // a lens decided by the wall clock makes the beat that most needs reproducing
                    // the one that cannot be.
                    lensSeed: 0,
                    // Never the verb list, and never the polarity display: this is the App
                    // Preview's opening frame and the README hero. See `lensSet`.
                    lensSet: WordCloudBackdropView.firstImpressionLenses
                )
                .ignoresSafeArea()
                // OPACITY, not a conditional, and animated on arrival.
                //
                // The splash can now be raised before the vectors are resident, so the first frames
                // of it are the identity block alone — which is exactly the launch screen's
                // composition, and the handover this view's own doc says it exists to make
                // invisible. What must not happen is the field appearing between one frame and the
                // next. The backdrop already draws nothing without vectors, so holding it at zero
                // costs a view that renders nothing anyway, and `areCloudVectorsReady` is what
                // makes the arrival observable at all.
                .opacity(appState.areCloudVectorsReady ? 1 : 0)
                .animation(.easeIn(duration: FRUSTheme.cloudArrivalDuration),
                           value: appState.areCloudVectorsReady)

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
        LaunchIdentityBlock(showsShimmer: true)
    }

    /// The rects the cloud is kept out from under, **in the backdrop's coordinate space**: the
    /// glass plate's square, and the wordmark-and-caption strip below it.
    ///
    /// ## Two rects, not one, so the cloud reaches the glass
    /// One centred 340 x 260 rect used to protect the whole block. The block is a narrow tile over
    /// a wide caption, so that rect left the sides of the tile and the band above it empty — on a
    /// phone, roughly a third of the screen's middle with no words in it, on a surface whose point
    /// is the words. The tile's square is now protected on its own and the text on its own, and
    /// the packer and the drift field take the array, so words flow beside the glass and stop at
    /// its rim. ``identityZone`` is the union, for callers that need one edge (the onboarding dock
    /// rule needs the bottom) and for the tests that pin the coverage.
    ///
    /// ## Two spaces, and the zones have to be in the second one
    /// This view is an `.overlay` on `ContentView`, so its `GeometryReader` reports the
    /// SAFE-AREA-inset box, and the identity block is centred in that. The backdrop beneath it
    /// carries `.ignoresSafeArea()`, so it packs and drifts in the FULL-BLEED box. Handing the
    /// zone across unchanged puts it off by exactly the leading/top inset — measured at 62 pt
    /// vertically on an iPhone 17 in portrait, which leaves the shimmer bar and the gap above it
    /// outside the protected rect, and in landscape leaves the caption's right-hand end outside.
    ///
    /// ## Modelled from the layout constants, with the slack stated
    /// The block is centred as a whole, so its top is derived from ``identityBlockMinimumHeight``,
    /// which is a FLOOR: the two `Text`s lay out at roughly 1.2x their point size, so the real
    /// block is about 7 pt taller and its top about 4 pt higher. ``zoneLineHeightAllowance``
    /// carries that, and ``zoneMargin`` is the clearance between a word and the block on top of
    /// it. A word that touched the caption would fail on a store screenshot, not in a test, so the
    /// numbers err toward the block.
    ///
    /// - Parameters:
    ///   - size: the safe-area box the identity block is laid out in.
    ///   - safeAreaInsets: that box's insets, which locate it inside the full-bleed canvas.
    ///   - metrics: the block's sizes — this device's by default; the plate generator passes the
    ///     idiom it is packing for, since it runs on whichever simulator hosts the tests.
    /// - Returns: `[tileZone, textZone]`, in full-bleed coordinates.
    static func identityZones(in size: CGSize,
                              safeAreaInsets: EdgeInsets = EdgeInsets(),
                              metrics: LaunchIdentityMetrics = .current) -> [CGRect] {
        let centerX = safeAreaInsets.leading + size.width / 2
        let blockHeight = metrics.identityBlockMinimumHeight
        // The block's top, from its centring — see the doc for why the allowance is here.
        let blockTop = safeAreaInsets.top + (size.height - blockHeight) / 2
            - zoneLineHeightAllowance / 2
        let plateEdge = metrics.tileSize + 2 * LaunchIdentityBlock.backplateInset
        let tileEdge = plateEdge + 2 * zoneMargin
        let tile = CGRect(x: centerX - tileEdge / 2,
                          y: blockTop + metrics.tileSize / 2 - tileEdge / 2,
                          width: tileEdge, height: tileEdge)
        let textTop = blockTop + metrics.tileSize + metrics.blockSpacing - zoneMargin
        let textBottom = blockTop + blockHeight + zoneLineHeightAllowance + zoneMargin
        let textWidth: CGFloat = min(340, size.width - 48)
        let text = CGRect(x: centerX - textWidth / 2, y: textTop,
                          width: textWidth, height: textBottom - textTop)
        return [tile, text]
    }

    /// The union of ``identityZones(in:safeAreaInsets:)`` — one rect covering the whole block.
    static func identityZone(in size: CGSize,
                             safeAreaInsets: EdgeInsets = EdgeInsets(),
                             metrics: LaunchIdentityMetrics = .current) -> CGRect {
        identityZones(in: size, safeAreaInsets: safeAreaInsets, metrics: metrics)
            .reduce(CGRect.null) { $0.union($1) }
    }

    /// Clearance between a word and the block, on every side of both zones.
    static let zoneMargin: CGFloat = 8

    /// How much taller the laid-out block is than ``identityBlockMinimumHeight``'s floor — the
    /// two `Text`s' line heights over their point sizes. Split across the block's centring.
    static let zoneLineHeightAllowance: CGFloat = 8

    // MARK: - Copy

    static let wordmark = String(localized: "splash.wordmark", defaultValue: "FRUS Explorer")
    static let caption = String(localized: "splash.caption",
        defaultValue: "Foreign Relations of the United States · since 1861")
    static let accessibilityLabel = String(localized: "splash.accessibility",
        defaultValue: "FRUS Explorer is opening your library.",
        comment: "Spoken description of the launch splash")

    // MARK: - Metrics

    /// The gap between the identity block's stacked elements. See ``LaunchIdentityMetrics``.
    static var blockSpacing: CGFloat { LaunchIdentityMetrics.current.blockSpacing }
    /// The app icon's edge length on this device. See ``LaunchIdentityMetrics``.
    static var tileSize: CGFloat { LaunchIdentityMetrics.current.tileSize }
    /// The wordmark's point size on this device. See ``LaunchIdentityMetrics``.
    static var wordmarkSize: CGFloat { LaunchIdentityMetrics.current.wordmarkSize }
    /// The caption's point size on this device. See ``LaunchIdentityMetrics``.
    static var captionSize: CGFloat { LaunchIdentityMetrics.current.captionSize }

    /// The shimmer bar's height. See ``LaunchIdentityMetrics/shimmerHeight``.
    static var shimmerHeight: CGFloat { LaunchIdentityMetrics.shimmerHeight }
    /// The gap above the shimmer bar. See ``LaunchIdentityMetrics/shimmerTopPadding``.
    static var shimmerTopPadding: CGFloat { LaunchIdentityMetrics.shimmerTopPadding }

    /// The least vertical space the identity block can occupy: its three type elements, the
    /// shimmer bar, and every gap between them. ``identityZone`` must cover it.
    ///
    /// A floor, not the laid-out height — the two `Text` elements render at roughly 1.2x their
    /// point size, so the real block is a little taller. Under-stating is the safe direction for
    /// a guard; over-stating would fail on a zone that is in fact adequate.
    static var identityBlockMinimumHeight: CGFloat {
        LaunchIdentityMetrics.current.identityBlockMinimumHeight
    }
}

// MARK: - LaunchIdentityMetrics

/// The identity block's sizes, per idiom — because 88 pt is a quarter of a phone and a tenth of
/// an iPad.
///
/// The block shipped at one size on every iOS device: an 88 pt tile is 22% of an iPhone 17's
/// width and 10.5% of an iPad Pro 11-inch's, and on an iPad's canvas it read as a thumbnail lost
/// among words larger than itself. The iPad tile is doubled to 176 pt (21% of the same iPad, 24%
/// of an iPad mini — proportionately what the phone has), with the wordmark and caption scaled
/// more gently so the block stays one composition rather than a poster over a footnote. The
/// launch storyboard carries the same three numbers as regular-width, regular-height size-class
/// variations, which is iPad and nothing else, so the handover still lands on the same pixels.
///
/// A value type rather than statics on the view, so the plate generator can ask for the iPad's
/// geometry while running on an iPhone simulator; ``current`` is what every live surface reads.
///
/// Version history:
///   1.0 — the iPad tile at 176 pt
struct LaunchIdentityMetrics: Equatable, Sendable {
    /// The app icon's edge length.
    let tileSize: CGFloat
    /// The wordmark's point size.
    let wordmarkSize: CGFloat
    /// The caption's point size.
    let captionSize: CGFloat
    /// The gap between the block's stacked elements.
    let blockSpacing: CGFloat

    /// iPhone: the hand-off's numbers, unchanged since #529.
    static let phone = LaunchIdentityMetrics(tileSize: 88, wordmarkSize: 22, captionSize: 13, blockSpacing: 14)
    /// iPad: the tile doubled, the type scaled by roughly a quarter.
    static let pad = LaunchIdentityMetrics(tileSize: 176, wordmarkSize: 28, captionSize: 15, blockSpacing: 14)
    /// macOS: the Dock-shaped icon at 76 pt in a 560 x 540 window.
    static let mac = LaunchIdentityMetrics(tileSize: 76, wordmarkSize: 20, captionSize: 12, blockSpacing: 14)

    /// The shimmer bar's height, the same on every idiom.
    ///
    /// Included in the floor below rather than left out as "chrome": it is the LOWEST element of
    /// the block, so it is the first thing an under-sized or mis-placed zone stops protecting —
    /// which is exactly what the safe-area offset did before `identityZone` took the insets.
    /// Lives here rather than on the view because a `View`'s statics are main-actor-isolated and
    /// ``identityBlockMinimumHeight`` is not.
    static let shimmerHeight: CGFloat = 3
    /// The gap above the shimmer bar, beyond the stack's own spacing.
    static let shimmerTopPadding: CGFloat = 10

    /// This device's metrics.
    @MainActor static var current: LaunchIdentityMetrics {
        #if os(macOS)
        .mac
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }

    /// The least vertical space the identity block can occupy at these metrics: its three type
    /// elements, the shimmer bar, and every gap between them. ``LaunchSplashView/identityZones``
    /// must cover it.
    ///
    /// A floor, not the laid-out height — the two `Text` elements render at roughly 1.2x their
    /// point size, so the real block is a little taller. Under-stating is the safe direction for
    /// a guard; over-stating would fail on a zone that is in fact adequate.
    var identityBlockMinimumHeight: CGFloat {
        tileSize + wordmarkSize + captionSize + Self.shimmerHeight
            + blockSpacing * 3 + Self.shimmerTopPadding
    }
}

// MARK: - LaunchIdentityBlock

/// The app icon, wordmark and caption, in the one composition three surfaces share.
///
/// ## One block, three surfaces
/// The launch storyboard draws it with no code (an `88 x 88` image view over two labels,
/// centred in the safe area); `LaunchSplashView` draws it here once SwiftUI is running; and
/// `OnboardingView` draws it on the welcome step, so the fresh-install sequence
/// **launch screen → splash → onboarding** keeps the icon at one point on screen while the cloud
/// arrives under it, the shimmer goes, and the dock rises. Any of the three moving the block is
/// the "screen replaced by a different screen" the storyboard's own header rules out — which is
/// why the layout is one type rather than three copies.
///
/// ## The tile IS the icon
/// `LaunchAppTile` is the app icon: the 1024 pt artwork the home screen shows, clipped to the
/// home screen's continuous corner and rasterised at 1x/2x/3x, with a `mac` idiom carrying the
/// macOS icon's own shape. It replaced a generic blue document-and-magnifier tile that appeared
/// nowhere else in the product, so the first frame a reader saw after tapping the icon was not
/// the icon they had tapped.
///
/// ## `showsShimmer: false` keeps the geometry, not just the look
/// Onboarding has nothing to wait for, so it draws no shimmer — but the shimmer's height and the
/// gap above it are still laid out, as a clear placeholder. The block is centred as a whole, so
/// dropping the shimmer would move the icon up by half its height at exactly the moment the
/// splash fades into onboarding. A shift of seven points is small and it is also the entire
/// difference between a handover and a cut.
///
/// ## The glass backplate is LAYOUT-NEUTRAL, and the iPhone SE is why
/// The icon sits on a Liquid Glass plate that reaches ``backplateInset`` past its edge, drawn as a
/// background so the block's laid-out height does not change. It could not: the launch plate's
/// identity hole is sized to `LaunchSplashView.identityBlockMinimumHeight` at the worst case
/// (`LaunchArtworkTests.identityHoleSurvivesEveryCrop`, a 375 pt iPhone SE at 374 of 400 plate
/// points), so sixteen more points of block would mean re-packing and re-shipping the plate. The
/// glass instead borrows from the empty space above the icon and from the gap below it, which is
/// what glass over a cloud is for — the onboarding dock already floats over the words the same
/// way. The launch screen shows NO backplate: glass is a live effect over whatever is behind it,
/// and the storyboard is a static snapshot, so the plate appears as the splash does, with the
/// cloud. Under Reduce Transparency there is no glass to draw and the icon sits bare, as before.
///
/// Version history:
///   1.0 — extracted from `LaunchSplashView.identityBlock` for onboarding's welcome step
///   1.1 — the glass backplate
struct LaunchIdentityBlock: View {

    /// Whether the indeterminate bar under the caption is drawn (the splash) or merely laid out
    /// (onboarding).
    let showsShimmer: Bool

    /// How far the glass plate reaches past the icon's edge, on each side.
    ///
    /// Eight leaves 6 pt of the 14 pt gap between plate and wordmark, and is well inside the
    /// identity zone's own slack (`SplashDriftTests.zoneCoversTheIdentityBlock` pins that).
    static let backplateInset: CGFloat = 8

    /// The icon's home-screen corner, as a share of its edge — the continuous-corner ratio iOS
    /// masks app icons with, which is also what `LaunchAppTile` was clipped to. The plate takes
    /// the same ratio at its own larger edge, so the two corners run concentric.
    static let cornerRatio: CGFloat = 0.2237

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let metrics = LaunchIdentityMetrics.current
        VStack(spacing: metrics.blockSpacing) {
            // Compile-checked symbol, not a string — a typo here used to be a blank tile
            // at runtime. Enabled by ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS.
            // The catalog carries `ipad` renditions at 176 pt, so the iPad draws its double-size
            // tile from 352 px rather than upscaling the phone's 264.
            Image(.launchAppTile)
                .resizable()
                .frame(width: metrics.tileSize, height: metrics.tileSize)
                .background {
                    if !reduceTransparency {
                        let edge = metrics.tileSize + 2 * Self.backplateInset
                        Color.clear
                            .frame(width: edge, height: edge)
                            .glassEffect(.regular, in: .rect(cornerRadius: edge * Self.cornerRatio,
                                                             style: .continuous))
                    }
                }
                .accessibilityHidden(true)
            Text(LaunchSplashView.wordmark)
                .font(.system(size: metrics.wordmarkSize, weight: .semibold))
            Text(LaunchSplashView.caption)
                .font(.system(size: metrics.captionSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Group {
                if showsShimmer {
                    shimmerBar
                } else {
                    Color.clear.frame(width: 140, height: LaunchSplashView.shimmerHeight)
                }
            }
            .padding(.top, LaunchSplashView.shimmerTopPadding)
        }
        .padding(.horizontal, 32)
    }

    /// A determinate-looking bar for an indeterminate wait. Honest enough: it says "working",
    /// not "this far along", and it stops moving under Reduce Motion.
    ///
    /// ## Why this pauses where `WordCloudDriftCanvas` slows, which looks inconsistent and is not
    ///
    /// The contract is *pin the value, not the schedule; simplify the transition, never remove it*
    /// — and the drift canvas follows it by slowing to 6 Hz rather than pausing, because **it still
    /// has something to say**: it keeps cycling lenses under Reduce Motion, and a paused schedule
    /// would pin one lens forever and take three quarters of the vocabulary away.
    ///
    /// This bar has nothing left to say. Under Reduce Motion its phase is substituted with a
    /// constant (`0.5`, below), so every frame after the first is byte-identical. Slowing the
    /// schedule instead of pausing it would buy a body re-evaluation and a re-composite per tick to
    /// produce a frame nobody can distinguish — on a `.cloudKitImport` splash that is, by
    /// definition, a main-thread-contended wait. The value is pinned; there is no transition left
    /// to simplify; so the schedule stops. That is the rule applied, not evaded.
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
            .frame(width: 140, height: LaunchSplashView.shimmerHeight)
        }
        .accessibilityHidden(true)
    }
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
