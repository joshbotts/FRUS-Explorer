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

/// The animated word cloud that sits behind onboarding and the launch splash.
///
/// Reads pre-generated vectors from ``BundledCloudVectors``, so it renders **before a
/// single volume is downloaded** — which is what lets the Add Volumes step preview a
/// scope's vocabulary at the moment the user is choosing what to download.
///
/// ## It is decoration, and behaves like it
/// - No vectors, or the core file not yet resident → renders **nothing**. Never a spinner,
///   never a placeholder. A backdrop that announces its own absence is worse than no
///   backdrop.
/// - Hidden from VoiceOver entirely. The words carry no information a screen-reader user
///   can act on; the lens chip is the accessible surface.
/// - Exempt from Dynamic Type, per the convention already documented at
///   `FRUSTheme.swift` — word size encodes frequency, so scaling it would destroy the
///   encoding rather than aid legibility.
///
/// ## One driver, not one timer per word
/// A single `TimelineView(.animation)` advances the lens phase. Words animate off SwiftUI
/// transitions keyed on the lens, with the hand-off's staggers applied as per-word delays.
/// Layouts are computed once per (canvas size × lens × scope) and cached, because the
/// Archimedean packer is O(words × spiral steps) and must not run per frame.
///
/// Version history:
///   1.0 — O-2: initial implementation
struct WordCloudBackdropView: View {

    /// Which scope's vocabulary to show.
    let scope: BundledCloudVectors.Scope

    /// Word opacity multiplier — `FRUSTheme.cloudDim*` per surface.
    var dim: Double = FRUSTheme.cloudDimDocked

    /// Rects the words must avoid, in the backdrop's own coordinate space. Callers pass the
    /// area their fixed UI occupies (the splash identity block, the docked panel).
    var exclusionZones: [CGRect] = []

    /// Whether the lens chip is drawn. The splash positions its own chip separately.
    var showsChip: Bool = true

    /// Reports each lens change, so a host can label a chip it owns.
    var onLensChange: ((WordCloudLens) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lensIndex = 0
    @State private var layouts: [LayoutKey: [PlacedWord]] = [:]

    private var lenses: [WordCloudLens] { WordCloudLens.bundledCloudLenses }
    private var lens: WordCloudLens { lenses[lensIndex % lenses.count] }

    var body: some View {
        GeometryReader { proxy in
            let resolved = resolve(size: proxy.size)
            ZStack(alignment: .topLeading) {
                if let resolved {
                    ForEach(Array(resolved.words.enumerated()), id: \.element.id) { rank, word in
                        Text(word.term)
                            .font(.system(size: word.fontSize, weight: .semibold, design: .serif))
                            .foregroundStyle(color(for: word, resolved: resolved))
                            .rotationEffect(.degrees(word.rotationDegrees))
                            .position(word.center)
                            .transition(wordTransition(rank: rank))
                    }
                }
            }
            .opacity(dim)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay(alignment: .topLeading) {
                if showsChip, let resolved {
                    // Keyed on the lens and delayed to the crossfade's midpoint. Without
                    // the delay the chip switches at t=0 while the outgoing words are still
                    // fading (0.95 s) and the incoming ones are still staggering in (~1 s) —
                    // so for most of every transition the chip names a lens that is not on
                    // screen. Caught by looking at it; no build or test would have.
                    LensChip(lens: resolved.lens, provenance: resolved.provenance)
                        .id(resolved.lens)
                        .transition(.opacity.animation(
                            .easeInOut(duration: 0.55)
                            .delay(reduceMotion ? 0 : FRUSTheme.cloudFadeOutDuration / 2)))
                        .padding(.leading, 20)
                        .padding(.top, 64)
                }
            }
            .animation(crossfade, value: lensIndex)
            .background(alignment: .center) { cadenceDriver }
        }
    }

    // MARK: - Cadence

    /// The single driver. `TimelineView(.animation)` ticks with the display; the phase is
    /// derived from elapsed time rather than incremented, so a dropped frame cannot make
    /// the cycle drift.
    ///
    /// Rendered into a zero-size background: it exists to advance state, not to draw.
    private var cadenceDriver: some View {
        TimelineView(.animation) { context in
            Color.clear
                .frame(width: 0, height: 0)
                .onChange(of: phase(at: context.date)) { _, newPhase in
                    guard newPhase != lensIndex else { return }
                    lensIndex = newPhase
                    onLensChange?(lenses[newPhase % lenses.count])
                }
        }
    }

    private func phase(at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / FRUSTheme.cloudLensCadence)
    }

    // MARK: - Layout

    /// Identifies a cached layout. Size is rounded so a one-point resize does not thrash
    /// the cache during a rotation or window drag.
    private struct LayoutKey: Hashable {
        let width: Int
        let height: Int
        let lens: WordCloudLens
        let scopeKey: String
    }

    private struct Resolved {
        let words: [PlacedWord]
        let provenance: BundledCloudVectors.Provenance
        let maxCount: Int
        /// The lens these words came from — carried rather than re-read, so the chip and
        /// the words can never disagree about which lens is being shown.
        let lens: WordCloudLens
    }

    private func resolve(size: CGSize) -> Resolved? {
        guard size.width > 40, size.height > 40,
              let source = BundledCloudVectors.terms(forScope: scope, lens: lens),
              let maxCount = source.terms.first?.count
        else { return nil }

        let key = LayoutKey(width: Int(size.width.rounded()), height: Int(size.height.rounded()),
                            lens: lens, scopeKey: scopeKey)
        if let cached = layouts[key] {
            return Resolved(words: cached, provenance: source.provenance, maxCount: maxCount, lens: lens)
        }
        // The packer is deterministic given its inputs, so the seed is implicit: the same
        // scope at the same size always lays out identically, which is what makes the cache
        // sound and the cloud stable across relaunches.
        let placed = WordCloudLayout.place(
            terms: source.terms,
            in: size,
            maxWords: 25,
            minFontSize: 12,
            maxFontSize: min(42, max(28, size.width / 12)),
            exclusionZones: exclusionZones,
            yCompression: FRUSTheme.cloudYCompression,
            sizeExponent: FRUSTheme.cloudSizeExponent
        )
        Task { @MainActor in layouts[key] = placed }
        return Resolved(words: placed, provenance: source.provenance, maxCount: maxCount, lens: lens)
    }

    private var scopeKey: String {
        switch scope {
        case .corpus: return "corpus"
        case .subseries(let id): return id
        case .volume(let id, _): return id
        }
    }

    // MARK: - Appearance

    private func color(for word: PlacedWord, resolved: Resolved) -> Color {
        let weight = Double(word.count) / Double(max(1, resolved.maxCount))
        if lens == .sentiment {
            switch BundledCloudVectors.polarity(of: word.term, inScope: scope, lens: lens) {
            case 1:  return FRUSTheme.cloudSentimentPositive
            case -1: return FRUSTheme.cloudSentimentNegative
            default: break
            }
        }
        if weight > FRUSTheme.cloudAccentThreshold { return FRUSTheme.cloudAccent(for: lens) }
        // Ink, deepening with weight — the hand-off's rgba(58,62,72, 0.35 + 0.5 × w).
        return Color.primary.opacity(0.35 + 0.5 * weight)
    }

    /// Reduce Motion: crossfade only — no scale, no stagger.
    private var crossfade: Animation {
        reduceMotion
            ? .easeInOut(duration: FRUSTheme.cloudFadeOutDuration)
            : .easeInOut(duration: FRUSTheme.cloudTransformDuration)
    }

    private func wordTransition(rank: Int) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.86))
                .animation(.easeOut(duration: FRUSTheme.cloudTransformDuration)
                    .delay(Double(rank) * FRUSTheme.cloudStaggerIn)),
            removal: .opacity.combined(with: .scale(scale: 0.86))
                .animation(.easeIn(duration: FRUSTheme.cloudFadeOutDuration)
                    .delay(Double(rank) * FRUSTheme.cloudStaggerOut))
        )
    }
}

// MARK: - LensChip

/// The accessible surface for the backdrop: names the lens, and says when the words on
/// screen are an *era's* rather than the scope's own.
///
/// Version history:
///   1.0 — O-2: initial implementation
struct LensChip: View {

    /// The lens currently on screen.
    let lens: WordCloudLens

    /// Where the words actually came from.
    let provenance: BundledCloudVectors.Provenance

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(FRUSTheme.cloudAccent(for: lens))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FRUSTheme.cloudAccent(for: lens))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(FRUSTheme.cloudAccent(for: lens).opacity(0.10))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// `"Concepts"`, or `"Concepts · 1969–76 (era)"` when an era stood in.
    ///
    /// The qualifier is decision O-4-2 and is **not** cosmetic: without it a user reading a
    /// volume's cloud to decide whether to download it would be reading its era's
    /// vocabulary and attributing it to the volume.
    private var label: String {
        switch provenance {
        case .exact:
            return lens.shortLabel
        case .subseriesFallback(let subseries):
            return String(
                localized: "wordcloud.backdrop.chip.era",
                defaultValue: "\(lens.shortLabel) · \(subseries) (era)",
                comment: "Lens chip when a volume's own cloud was too thin and its era's vocabulary is shown instead"
            )
        }
    }
}
