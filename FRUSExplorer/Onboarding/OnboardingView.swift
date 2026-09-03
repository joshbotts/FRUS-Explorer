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
///   3.3 — Dynamic Type review 2026-07-04: hero-glyph caps now enforced in code
///         via `FRUSTheme.cappedGlyphSize` (the `.dynamicTypeSize` cap was inert
///         on a `.system(size:)` font).
///   3.4 — O-0: the pure step-2 logic (volume floor, subseries order, grouping,
///         validity, enqueue set) moved to `OnboardingScopeResolver`, and the
///         Finish side-effect to `OnboardingCompletion`, so both are testable
///         before O-4 rewrites this view around the word-cloud backdrop. The
///         private `ScopeChoice` became `OnboardingScopeChoice`. Behaviour is
///         unchanged but for the now-deterministic subseries tiebreak, which is
///         documented at `OnboardingScopeResolver.subseries`.
///   4.0 — O-4: rebuilt around the word-cloud backdrop per the design hand-off's
///         4a/4b/4c. The three steps now float in one docked glass panel over a
///         full-bleed `WordCloudBackdropView`; `StepDot` became page dots and
///         `ScopeCard` a segmented control, with the subseries and volume pickers
///         moved into a transient sheet above the dock. All copy is localised.
///         **The flow's behaviour is unchanged** — `enqueueAndAdvance()`,
///         `completeOnboarding()` and `OnboardingScopeResolver` are called exactly
///         as before, and O-0's characterization tests pass untouched.
@MainActor
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// When on, glass is replaced by a solid card. `.glassEffect` degrades on its own, but
    /// not to an opaque surface — and the dock sits over a moving word cloud, so anything
    /// translucent leaves text competing with drifting serif words underneath it.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var step: OnboardingStep = .welcome

    /// Point size of the welcome / ready hero glyphs, scaled with Dynamic Type
    /// (relative to `.largeTitle`) so the icon grows with the body text it pairs
    /// with. Growth is clamped via `FRUSTheme.cappedGlyphSize` at the glyph sites
    /// so extreme sizes don't overwhelm the step layout.
    @ScaledMetric(relativeTo: .largeTitle) private var heroGlyphSize: CGFloat = 56

    // MARK: - Step 2 State

    /// The Ready step's check glyph, scaled with Dynamic Type and clamped by
    /// `FRUSTheme.cappedGlyphSize` — the `.dynamicTypeSize` cap is inert on a
    /// `.system(size:)` font, which is why the clamp is applied in code.
    @ScaledMetric(relativeTo: .title3) private var scaledReadyGlyph: CGFloat = 26

    /// Measured height of the dock stack, including any transient sheet above it.
    ///
    /// Feeds the backdrop's exclusion zone so the words clear whatever the dock actually
    /// occupies at the reader's type size — not what it occupied at the default one.
    @State private var measuredDockHeight: CGFloat = 0

    @State private var scopeChoice: OnboardingScopeChoice = .corpus
    @State private var selectedSubseries: String = ""
    @State private var selectedVolumeId: String = ""

    // MARK: - Body

    /// Which scope the backdrop previews. Tracks the segmented control on step 2, so the
    /// cloud re-aggregates as the user chooses — the reason the vectors are bundled at all.
    private var backdropScope: BundledCloudVectors.Scope {
        guard step == .addVolumes else { return .corpus }
        switch scopeChoice {
        case .corpus:
            return .corpus
        case .subseries:
            return selectedSubseries.isEmpty ? .corpus : .subseries(selectedSubseries)
        case .volume:
            guard !selectedVolumeId.isEmpty,
                  let entry = scopeResolver.volumes.first(where: { $0.volumeId == selectedVolumeId })
            else { return .corpus }
            return .volume(volumeId: entry.volumeId, subseries: entry.subseries)
        }
    }

    /// Dim factor per surface, from the hand-off: the denser Add Volumes dock needs a
    /// quieter field behind it than Welcome or Ready.
    private var backdropDim: Double {
        step == .addVolumes ? FRUSTheme.cloudDimAddVolumes : FRUSTheme.cloudDimDocked
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                WordCloudBackdropView(
                    scope: backdropScope,
                    dim: backdropDim,
                    // Keep words out from under the dock — measured, not estimated.
                    //
                    // This was a hardcoded height guess, which O-5 caught at an
                    // accessibility text size: the dock grows to fit the reader's type, the
                    // guess does not, and words were being placed where the dock had since
                    // expanded to. There is no feedback loop to fear here — the dock's
                    // height depends on its text, never on the backdrop.
                    exclusionZones: [dockExclusionZone(in: proxy.size)]
                )
                .ignoresSafeArea()

                VStack(spacing: FRUSTheme.onboardingSheetGap) {
                    if !appState.isOnline { offlineBanner }
                    if let sheet = transientSheet { sheet }
                    dock
                }
                .padding(.horizontal, FRUSTheme.onboardingDockMargin)
                // UI review F-5: cap the stack on iOS, where nothing bounded it and a 13-inch
                // iPad stretched the scope picker across the whole screen (measured: 1294 of
                // 1294 pt). macOS is already pinned by the window frame at :154.
                //
                // **The cap belongs on this CONTAINER, not on `dock`.** All three children are
                // full-width by construction — `offlineBanner` carries its own
                // `.frame(maxWidth: .infinity)` and its own background, and `transientSheet` is
                // the volume/subseries picker — so capping the dock alone would narrow the glass
                // slab while the picker above it stayed edge to edge. Capping here also avoids a
                // trap that costs a debugging cycle if the cap is pushed down into `dock`: its
                // `.frame(maxWidth: .infinity)` is followed immediately by
                // `.cloudSurfaceBackground`, so a cap applied before the background repaints the
                // slab at full width and measures as no change at all. Proposing 640 from the
                // parent leaves `dock` untouched and the background lands on the capped width.
                .frame(maxWidth: OnboardingDockMetrics.dockWidth(forContainerWidth: proxy.size.width))
                .padding(.bottom, dockBottomInset)
                .background {
                    GeometryReader { dockProxy in
                        Color.clear.preference(key: DockHeightKey.self,
                                               value: dockProxy.size.height)
                    }
                }
                .onPreferenceChange(DockHeightKey.self) { measuredDockHeight = $0 }
            }
        }
        #if os(macOS)
        .frame(width: 560, height: 540)
        #endif
        .animation(.easeInOut(duration: 0.2), value: appState.isOnline)
        .animation(.easeInOut(duration: 0.22), value: step)
        .animation(.easeOut(duration: 0.3), value: scopeChoice)
    }

    /// Space below the dock. iOS lifts it clear of the home indicator per the hand-off.
    private var dockBottomInset: CGFloat {
        #if os(macOS)
        FRUSTheme.onboardingDockMargin
        #else
        28
        #endif
    }

    /// The region the dock (and any sheet above it) occupies, for the backdrop to avoid.
    ///
    /// Uses the measured height once it is known, falling back to a first-frame estimate
    /// for the single pass before the preference resolves.
    ///
    /// The **width** follows the same rule as the dock itself (F-5). Before the cap the dock was
    /// the full screen and so was this rect; leaving it full-width afterwards would push words
    /// out of a band the dock no longer occupies — on a 13-inch iPad, roughly half the screen of
    /// empty space that the word cloud would refuse to use. That is the estimate-versus-measure
    /// mistake this function's own history records, in the other direction.
    private func dockExclusionZone(in size: CGSize) -> CGRect {
        let height = measuredDockHeight > 0
            ? measuredDockHeight + dockBottomInset
            : (step == .addVolumes ? 170 : 130) + dockBottomInset
        let width = OnboardingDockMetrics.dockWidth(forContainerWidth: size.width)
        return CGRect(x: (size.width - width) / 2,
                      y: max(0, size.height - height),
                      width: width,
                      height: height)
    }

    // MARK: - Dock

    /// The one glass surface every step floats in.
    private var dock: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch step {
            case .welcome:    welcomeDock
            case .addVolumes: scopeDock
            case .ready:      readyDock
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cloudSurfaceBackground(cornerRadius: FRUSTheme.onboardingDockRadius,
                                solid: reduceTransparency)
    }

    // MARK: - 4a Welcome

    private var welcomeDock: some View {
        dockLayout(
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    pageDots
                    Text(Self.welcomeTitle).font(.system(titleStyle, weight: .semibold))
                    Text(Self.welcomeBody)
                        .font(.system(bodyStyle))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                }
            },
            actions: { primaryButton(step.continueLabel) { advance() } }
        )
    }

    // MARK: - 4b Add Volumes

    private var scopeDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            dockLayout(
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        pageDots
                        Text(Self.scopeTitle).font(.system(denseTitleStyle, weight: .semibold))
                        #if !os(macOS)
                        scopeSegmentedControl
                        #endif
                    }
                },
                actions: {
                    #if os(macOS)
                    scopeSegmentedControl
                    #else
                    EmptyView()
                    #endif
                }
            )

            // Row 2. macOS puts the caption and the actions side by side; iPhone stacks
            // them. Sharing one row on a phone starves the primary button until its label
            // wraps a character per line — verified on screen, where "Continue" rendered
            // as a four-line vertical sliver.
            dockLayout(
                content: {
                    Text(scopeCaption)
                        .font(.system(bodyStyle))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                },
                actions: {
                    HStack(spacing: 14) {
                        plainButton(Self.backLabel) { if let prev = step.previous { step = prev } }
                        plainButton(Self.skipLabel) { step = .ready }
                        primaryButton(step.continueLabel) { advance() }
                            .disabled(!canProceedFromScope)
                    }
                    // Never let the caption squeeze the actions below their natural width.
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }
            )
        }
    }

    /// The three scopes. Full labels on macOS, short on iOS — the hand-off's split, because
    /// three full labels do not fit an iPhone segment at equal widths.
    private var scopeSegmentedControl: some View {
        Picker(Self.scopeTitle, selection: $scopeChoice) {
            ForEach(OnboardingScopeChoice.allCases, id: \.self) { choice in
                Text(segmentLabel(choice)).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: scopeChoice) { _, new in
            // Clear the other scope's selection, matching the pre-O-4 ScopeCard taps. The
            // resolver ignores the irrelevant field, but leaving it set would make the
            // backdrop preview a scope the user is no longer choosing.
            switch new {
            case .corpus:    selectedSubseries = ""; selectedVolumeId = ""
            case .subseries: selectedVolumeId = ""
            case .volume:    selectedSubseries = ""
            }
            if new == .volume { Task { await BundledCloudVectors.prepareVolumes() } }
        }
        #if os(macOS)
        .frame(maxWidth: 320)
        #endif
    }

    /// The caption swaps with the selection (hand-off 4b, dock row 2).
    private var scopeCaption: String {
        switch scopeChoice {
        case .corpus:    return Self.captionCorpus(volumeCount: appState.manifestStore.bundledEntries.count)
        case .subseries: return Self.captionSubseries
        case .volume:    return Self.captionVolume
        }
    }

    // MARK: - Transient sheet

    /// The picker floats above the dock, and **only** for the scopes that need one.
    /// Entire Corpus shows none, leaving the cloud unobstructed — hand-off 4b.
    @ViewBuilder
    private var transientSheet: (some View)? {
        if step == .addVolumes, scopeChoice != .corpus {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if scopeChoice == .subseries {
                            ForEach(allSubseries, id: \.self) { sub in
                                sheetRow(title: sub,
                                         detail: subseriesDetail(count: scopeResolver.volumeCount(inSubseries: sub)),
                                         isSelected: selectedSubseries == sub) { selectedSubseries = sub }
                            }
                        } else {
                            ForEach(scopeResolver.volumes) { volume in
                                sheetRow(title: volume.title, detail: volume.volumeId,
                                         isSelected: selectedVolumeId == volume.volumeId) {
                                    selectedVolumeId = volume.volumeId
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: FRUSTheme.onboardingSheetMaxHeight)
            .cloudSurfaceBackground(cornerRadius: FRUSTheme.onboardingSheetRadius,
                                    solid: reduceTransparency)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func sheetRow(title: String, detail: String, isSelected: Bool,
                          select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(rowTitleStyle, weight: .medium))
                        .foregroundStyle(.primary).lineLimit(2)
                    Text(detail).font(.system(rowDetailStyle)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
            // A greedy frame FIRST, then contentShape — `contentShape` alone does not widen
            // a plain-Button row's tap target.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 4c Ready

    /// Whether Finish from here will leave the reader with nothing to read.
    ///
    /// Read at render time on the Ready step, by which point Continue's enqueue has already run
    /// (`enqueueAndAdvance` awaits it before advancing) and Skip's has not — so this is the same
    /// condition `completeOnboarding` stores, evaluated one step earlier to choose honest copy.
    private var willFinishEmpty: Bool {
        OnboardingCompletion.finishedEmpty(
            hasVolumes: OnboardingViewModel.hasDownloadedVolumes(
                in: appState.downloadManager?.volumesDirectory),
            hasQueuedDownloads: !appState.downloadQueue.isEmpty)
    }

    private var readyDock: some View {
        dockLayout(
            content: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: FRUSTheme.cappedGlyphSize(scaledReadyGlyph, base: readyGlyphSize)))
                        .foregroundStyle(Color.green)
                    VStack(alignment: .leading, spacing: 6) {
                        pageDots
                        Text(Self.readyTitle).font(.system(titleStyle, weight: .semibold))
                        Text(willFinishEmpty ? Self.readyBodyEmpty : Self.readyBody)
                            .font(.system(bodyStyle))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            },
            actions: {
                HStack(spacing: 14) {
                    plainButton(Self.backLabel) { if let prev = step.previous { step = prev } }
                    primaryButton(step.continueLabel) { advance() }
                }
            }
        )
    }

    // MARK: - Dock chrome

    /// macOS lays the dock out in one row (content left, actions right); iOS stacks them
    /// with a full-width primary button. Hand-off 4a.
    @ViewBuilder
    private func dockLayout<C: View, A: View>(
        @ViewBuilder content: () -> C,
        @ViewBuilder actions: () -> A
    ) -> some View {
        #if os(macOS)
        HStack(alignment: .bottom, spacing: 16) {
            content()
            Spacer(minLength: 12)
            actions()
        }
        #else
        VStack(alignment: .leading, spacing: 14) {
            content()
            actions().frame(maxWidth: .infinity)
        }
        #endif
    }

    /// Page dots — position only, no numbers. `StepDot`'s numbered badges were the old
    /// full-screen indicator; in a dock they are chrome competing with the copy.
    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingStep.allCases) { s in
                Capsule()
                    .fill(dotColor(for: s))
                    .frame(width: s == step ? FRUSTheme.onboardingCurrentDotWidth : FRUSTheme.onboardingDotSize,
                           height: FRUSTheme.onboardingDotSize)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(stepPositionLabel))
    }

    private func dotColor(for s: OnboardingStep) -> Color {
        if s == step { return .accentColor }
        return s.index < step.index ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.18)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    private func plainButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
    }

    /// Continue / Get Started / Finish, routed exactly as before O-4.
    private func advance() {
        if step == .addVolumes {
            Task { await enqueueAndAdvance() }
        } else if let next = step.next {
            step = next
        } else {
            Task { await completeOnboarding() }
        }
    }

    // MARK: - Copy
    //
    // Verbatim from the design hand-off (4a/4b/4c). Every string is localised — before O-4
    // this view carried 14 raw `Text("…")` literals and not one `String(localized:)`, a
    // standing violation of the house convention with no mechanical gate behind it. Mirrored
    // in `Docs/EditableContent.md` §2 in the same commit.

    static let welcomeTitle = String(localized: "onboarding.welcome.title",
        defaultValue: "Welcome to FRUS Explorer")
    static let welcomeBody = String(localized: "onboarding.welcome.body",
        defaultValue: "The official documentary record of U.S. foreign policy since 1861 — searchable, cross-referenced, on your device.")

    static let scopeTitle = String(localized: "onboarding.scope.title",
        defaultValue: "What would you like to download?")
    /// The whole-series caption, with the count read from the bundled manifest.
    ///
    /// R-3 (New-Volume-Release-Plan §7.1): this was the one `552` literal that stayed *true* after
    /// a 553rd volume — the `+` made it a floor — and it is the model for the other eight. Deriving
    /// it makes the floor exact instead of merely honest. The `+` stays because the live manifest
    /// can list volumes the bundle does not know yet (`ManifestStore.newlyAvailable`).
    ///
    /// - Parameter volumeCount: `ManifestStore.bundledEntries.count`.
    static func captionCorpus(volumeCount: Int) -> String {
        String(format: String(localized: "onboarding.scope.caption.corpus.v2 %lld",
                              defaultValue: "%lld+ volumes · ≈ 3.3 GB — the entire series, fully offline."),
               Int64(volumeCount))
    }
    static let captionSubseries = String(localized: "onboarding.scope.caption.subseries",
        defaultValue: "A decade or diplomatic era — the recommended starting point.")
    static let captionVolume = String(localized: "onboarding.scope.caption.volume",
        defaultValue: "One volume to explore — typically a few MB.")

    static let readyTitle = String(localized: "onboarding.ready.title",
        defaultValue: "You're all set")
    static let readyBody = String(localized: "onboarding.ready.body",
        defaultValue: "Volumes download and index automatically — search unlocks in minutes. Your project \u{201C}My Research\u{201D} is ready.")

    /// The Ready step's copy when nothing is being downloaded.
    ///
    /// The line above promises volumes are downloading and that search unlocks in minutes. On a
    /// Skip — or any finish that enqueued nothing — both halves are false, and the reader would
    /// wait for a search that never arrives. What IS true is that the corpus is browsable and
    /// downloadable from inside the app, which is where Finish now lands them.
    static let readyBodyEmpty = String(localized: "onboarding.ready.body.empty",
        defaultValue: "Nothing is downloading yet — browse the corpus and add volumes whenever you like. Your project \u{201C}My Research\u{201D} is ready.")

    static let offlineBannerText = String(localized: "onboarding.offline.banner",
        defaultValue: "You are offline. Showing bundled catalog only.")

    static let backLabel = String(localized: "onboarding.action.back", defaultValue: "Back")
    static let skipLabel = String(localized: "onboarding.action.skip", defaultValue: "Skip")

    /// Segment labels. macOS gets the full phrasing; iOS gets short ones, because three
    /// full labels cannot share an iPhone's segment width without truncating.
    private func segmentLabel(_ choice: OnboardingScopeChoice) -> String {
        #if os(macOS)
        switch choice {
        case .corpus:    return String(localized: "onboarding.scope.segment.corpus.long", defaultValue: "Entire Corpus")
        case .subseries: return String(localized: "onboarding.scope.segment.subseries.long", defaultValue: "A Subseries")
        case .volume:    return String(localized: "onboarding.scope.segment.volume.long", defaultValue: "A Single Volume")
        }
        #else
        switch choice {
        case .corpus:    return String(localized: "onboarding.scope.segment.corpus.short", defaultValue: "Corpus")
        case .subseries: return String(localized: "onboarding.scope.segment.subseries.short", defaultValue: "Subseries")
        case .volume:    return String(localized: "onboarding.scope.segment.volume.short", defaultValue: "Volume")
        }
        #endif
    }

    private func subseriesDetail(count: Int) -> String {
        String(localized: "onboarding.scope.sheet.volumeCount",
               defaultValue: "\(count) volume\(count == 1 ? "" : "s")",
               comment: "Row detail in the subseries sheet: how many volumes an era contains")
    }

    /// Spoken position for the page dots, which are decorative on their own.
    private var stepPositionLabel: String {
        String(localized: "onboarding.step.position",
               defaultValue: "Step \(step.index + 1) of \(OnboardingStep.allCases.count): \(step.label)",
               comment: "VoiceOver label for the onboarding page dots")
    }

    // MARK: - Metrics

    // Dynamic Type. The hand-off specifies point sizes; these are the nearest text STYLES,
    // so the dock scales with the reader's setting instead of pinning at one size. The
    // house convention is that text scales and only the word cloud is exempt — its size
    // encodes frequency, so scaling it would destroy the encoding rather than aid
    // legibility (documented at `FRUSTheme.swift` and at `WordCloudBackdropView`).
    //
    // iOS defaults line up almost exactly with the hand-off: .title3 = 20 pt, .headline =
    // 17 pt, .subheadline = 15 pt, .caption = 12 pt.

    private var titleStyle: Font.TextStyle { .title3 }
    private var denseTitleStyle: Font.TextStyle { .headline }
    private var bodyStyle: Font.TextStyle { .subheadline }
    private var rowTitleStyle: Font.TextStyle { .subheadline }
    private var rowDetailStyle: Font.TextStyle { .caption }

    #if os(macOS)
    private var readyGlyphSize: CGFloat { 30 }
    #else
    private var readyGlyphSize: CGFloat { 26 }
    #endif

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(Self.offlineBannerText)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.yellow.opacity(0.2))
        .foregroundStyle(.primary)
    }

    // MARK: - Derived Data

    /// The pure step-2 logic, rebuilt from whichever manifest view is current.
    ///
    /// A refreshed manifest wins over the bundled one, so a user who came online during
    /// onboarding is offered what the network knows rather than what shipped.
    private var scopeResolver: OnboardingScopeResolver {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return OnboardingScopeResolver(manifestEntries: source)
    }

    /// Subseries sorted newest-first by the leading four-digit year.
    private var allSubseries: [String] { scopeResolver.subseries }

    /// Volumes grouped by subseries, subseries sorted newest-first.
    private var volumesBySubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        scopeResolver.volumesBySubseries
    }

    // MARK: - Validation

    private var canProceedFromScope: Bool {
        scopeResolver.canProceed(
            scope: scopeChoice,
            selectedSubseries: selectedSubseries,
            selectedVolumeId: selectedVolumeId
        )
    }

    // MARK: - Actions

    private func enqueueAndAdvance() async {
        if let dm = appState.downloadManager {
            let volumes = scopeResolver.enqueueSet(
                scope: scopeChoice,
                selectedSubseries: selectedSubseries,
                selectedVolumeId: selectedVolumeId
            )
            for entry in volumes {
                await dm.enqueueDownload(entry)
            }
        }
        step = .ready
    }

    private func completeOnboarding() async {
        if let newProjectId = OnboardingCompletion.ensureDefaultProjectExists(in: modelContext) {
            appState.activeProjectId = newProjectId
        }
        // Record a finish that leaves the reader with nothing to read, so `ContentView` lets them
        // into the app instead of returning them to the Welcome page for ever. Evaluated from the
        // OUTCOME rather than from which button was tapped: Skip is the usual way here, but a
        // scope that enqueues nothing — offline, or one resolving to no volumes — traps a reader
        // who tapped Continue in exactly the same way. See
        // `AppState.hasFinishedOnboardingWithoutVolumes`.
        appState.hasFinishedOnboardingWithoutVolumes = OnboardingCompletion.finishedEmpty(
            hasVolumes: OnboardingViewModel.hasDownloadedVolumes(
                in: appState.downloadManager?.volumesDirectory),
            hasQueuedDownloads: !appState.downloadQueue.isEmpty)
        appState.hasCompletedOnboarding = true
    }

    // MARK: - Helpers

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

// MARK: - DockHeightKey

/// Carries the measured dock height up to the backdrop's exclusion zone.
///
/// Version history:
///   1.0 — O-5: initial implementation
private struct DockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
