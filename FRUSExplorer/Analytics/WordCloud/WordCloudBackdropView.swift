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
///   1.1 — layout cache keyed on a quantised box and bounded, after an on-device probe
///          showed the strip's height animation re-running the packer inside `body`
///   1.2 — P-1: opt-in `drift` renders the same words as particles in a Canvas
///          (`WordCloudDriftCanvas`); the static Text path is unchanged
///   1.3 — three things a surface used to have decided for it. `composition` lets a host declare
///          itself a band rather than leaving `bandHeight` to infer it from a frame the iPad
///          indexing banner grows past; `lensSet` makes WHICH lenses a surface cycles a
///          presentation decision beside `lensSeed`'s WHERE-it-starts; and `staggerDelay` holds a
///          stagger BUDGET, so the per-word figures authored for twenty-five words (#532) stop
///          doubling the transition at the fifty a full-bleed surface has asked for since #551
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

    /// Whether this surface is a band with live content over it, or a field to be inside.
    ///
    /// **The size is not a reliable proxy, and the indexing banner is the proof.** `wordCount` and
    /// `fillFactor` both infer the answer from `bandHeight`, which is right on iPhone and wrong on
    /// iPad: `IndexingBannerView` mounts `IndexingContextCard` only at regular width, and that card
    /// takes the banner past 160 pt. The strip therefore flipped to FIELD treatment — bleed 0.12
    /// and 35–50 words instead of 25 contained ones — behind four lines of prose, with words
    /// clipped at the frame edge where the strip's own doc says a clipped word "reads as a
    /// rendering fault". At iPad widths the 250,000 pt² step is a banner only 183 pt tall on a
    /// 13-inch in landscape, so the fifty-word ceiling meant for a whole window is one Dynamic Type
    /// notch away on the narrower ones too.
    ///
    /// A host that knows it is a band says so, rather than leaving a layout accident to decide.
    var composition: Composition = .automatic

    /// Draw the words as drifting particles in a `Canvas` instead of static `Text` views.
    ///
    /// Opt-in per surface rather than a wholesale replacement, for two reasons. The first
    /// is that it makes the A/B one flag: the same build, the same device, the same
    /// vocabulary, one variable changed — which is the only way the `draw` number in the
    /// frame probe means anything. The second is blast radius: the splash and the onboarding
    /// dock are first-run surfaces whose composition has already been reviewed on device,
    /// and there is no reason to re-open them to answer a question about the indexing strip.
    var drift: Bool = false

    /// Which lens this surface STARTS on, or `nil` to keep the wall-clock-derived start
    /// (visual-marketing plan §3.2, M-5).
    ///
    /// **The default start is not lens 0; it is arbitrary, and that is the defect.** `lensIndex`
    /// is seeded 0 but the cadence driver assigns the ABSOLUTE phase integer at the first boundary
    /// it crosses, so a surface that lives across one — roughly 38% of 1.6 s fresh-install splashes,
    /// at a 4.2 s cadence — lands on a lens decided by the wall clock. For the indexing strip, which
    /// lives for minutes, that is harmless and even desirable. For the splash it is not: the splash
    /// is simultaneously the App Preview's opening frame, a store screenshot and the README hero,
    /// and the one beat that most needs to be reproducible was the one that could not be.
    ///
    /// A seed pins the START and keeps the cadence: subsequent changes advance RELATIVE to the
    /// first phase this surface saw, so a long-lived seeded surface still cycles, deterministically.
    var lensSeed: Int?

    /// Which lenses this surface cycles through.
    ///
    /// **A presentation decision, not a payload one.** `WordCloudLens.bundledCloudLenses` is the
    /// generator's contract — the four lists `cloud-vectors-core.json` carries — and it stays as it
    /// is. What a given surface should SHOW out of those four is a different question, and it was
    /// never asked: one global list on a 4.2 s cadence gave every lens 25% of every surface's time.
    ///
    /// Read against the shipped corpus lists, they are not equivalent. `concepts` is *policy, war,
    /// treaty, interest, security, order, power, authority, negotiation, peace, development, trade,
    /// aid…* — it reads as FRUS. `topics` is mixed but recognisable (*president, soviet, agreement,
    /// treaty* beside *time, question, view, matter, case, point*). `actions` is twenty-five
    /// generic English verbs — *say, take, give, see, receive, follow, think, believe, consider,
    /// get, seem* — which would be the top of any English corpus and say nothing about this one.
    /// `sentiment` is a polarity display rather than a vocabulary.
    ///
    /// So the sets below are named rather than left implicit, and `lensSeed` already established
    /// that WHERE a surface starts in the cycle is the surface's business; this is the same
    /// argument applied to WHICH lenses are in it.
    var lensSet: [WordCloudLens] = WordCloudBackdropView.ambientLenses

    /// The lenses a first-impression surface shows: the two that describe the corpus.
    ///
    /// The launch splash and onboarding are the first thing anyone sees, and one of them is the App
    /// Preview's opening frame. Neither should be able to open on twenty-five generic verbs, and a
    /// polarity display is a misleading first sentence about a documentary record.
    static let firstImpressionLenses: [WordCloudLens] = [.concepts, .topics]

    /// The lenses a long-lived ambient surface cycles: everything but the verbs.
    ///
    /// The indexing banner and a pending search run for minutes, where variety is the point —
    /// but `actions` is uninformative at every duration, so it is out here too. It stays in
    /// `bundledCloudLenses` because the artifact ships it and a future surface may want it.
    static let ambientLenses: [WordCloudLens] = [.concepts, .topics, .sentiment]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lensIndex = 0
    /// The first cadence phase this surface saw, so a seeded surface can advance relative to it.
    @State private var phaseOrigin: Int?
    @State private var layouts: [LayoutKey: [PlacedWord]] = [:]

    private var lenses: [WordCloudLens] { lensSet }

    /// How far the drift canvas must shift its wall-clock lens index to agree with the chip.
    ///
    /// Zero on an unseeded surface, where `lensIndex` IS the absolute phase and the canvas already
    /// agrees. On a seeded one it is the gap the seed opened, so both halves of the surface name
    /// the same lens — which is what makes M-5's reproducible opening frame reproducible in the
    /// words as well as in the label.
    /// The shift the drift canvas needs to draw the lens the chip names.
    ///
    /// The arithmetic is short enough to check by eye: the canvas computes
    /// `absolutePhase + offset`, and the cadence driver sets `lensIndex = seed + absolutePhase −
    /// phaseOrigin`. Equating the two leaves `offset = seed − phaseOrigin`, with no clock in it.
    ///
    /// **The `currentPhase` fallback is the first frame, and the first frame is the one that
    /// matters.** `phaseOrigin` is `nil` until the cadence driver's `onAppear`, so a version that
    /// returned 0 there would disagree with the chip on exactly the frame that opens the App
    /// Preview. The driver is about to record this same value as the origin, so using it now is
    /// the answer that will hold a moment later rather than a guess.
    ///
    /// - Parameters:
    ///   - seed: the surface's `lensSeed`, or `nil` for an unseeded surface.
    ///   - origin: the recorded phase origin, or `nil` before it is recorded.
    ///   - currentPhase: the absolute phase now, used only when `origin` is `nil`.
    /// - Returns: the offset, or 0 for an unseeded surface — byte-identical to before.
    static func driftLensOffset(seed: Int?, origin: Int?, currentPhase: Int) -> Int {
        guard let seed else { return 0 }
        return seed - (origin ?? currentPhase)
    }

    /// This surface's offset, for the canvas.
    private var driftLensOffset: Int {
        Self.driftLensOffset(seed: lensSeed, origin: phaseOrigin,
                             currentPhase: phase(at: Date()))
    }
    private var lens: WordCloudLens {
        // Floor-modulo: a seeded surface can reach a negative index if the clock moves backwards
        // across a boundary, and `%` in Swift keeps the sign.
        lenses[((lensIndex % lenses.count) + lenses.count) % lenses.count]
    }

    var body: some View {
        GeometryReader { proxy in
            // The static path's resolve is only needed for the words it draws and for the
            // chip's provenance. In drift mode without a chip it is pure duplicate work.
            let resolved = (drift && !showsChip) ? nil : resolve(size: proxy.size)
            ZStack(alignment: .topLeading) {
                if drift {
                    if let snapshot = driftSnapshot(size: proxy.size) {
                        // The chip and the words must name one lens. `lensIndex` already carries
                        // the seed; the canvas derives its own index from the absolute clock, so
                        // it is handed the difference.
                        WordCloudDriftCanvas(snapshot: snapshot, dim: dim,
                                             reduceMotion: reduceMotion,
                                             lensOffset: driftLensOffset)
                    }
                } else if let resolved {
                    ForEach(Array(resolved.words.enumerated()), id: \.element.id) { rank, word in
                        Text(word.term)
                            .font(.system(size: word.fontSize, weight: .semibold, design: .serif))
                            .foregroundStyle(color(for: word, resolved: resolved))
                            .rotationEffect(.degrees(word.rotationDegrees))
                            .position(word.center)
                            .transition(wordTransition(rank: rank, count: resolved.words.count))
                    }
                }
            }
            // The drift canvas applies `dim` per particle, so it must not be applied twice.
            .opacity(drift ? 1 : dim)
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
            .animation(drift ? nil : crossfade, value: lensIndex)
            .background(alignment: .center) { cadenceDriver }
            // Inert unless FRUS_FRAME_PROBE=1. The backdrop's frame cost is what gates the
            // drift work, and this is where it is measured.
            .frameTimeProbe()
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
                .onAppear { if phaseOrigin == nil { phaseOrigin = phase(at: context.date) } }
                .onChange(of: phase(at: context.date)) { _, newPhase in
                    // Unseeded surfaces keep the absolute phase, byte for byte as before.
                    let next = lensSeed.map { seed in
                        seed + (newPhase - (phaseOrigin ?? newPhase))
                    } ?? newPhase
                    guard next != lensIndex else { return }
                    lensIndex = next
                    onLensChange?(lenses[((next % lenses.count) + lenses.count) % lenses.count])
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
        /// **Load-bearing for the same reason `exclusion` is.** A band and a field at one quantised
        /// box ask the packer for different word counts, so without this a surface that declared
        /// itself a band could be handed a field's fifty words out of the cache.
        let composition: Composition
        /// The exclusion rects, quantised. **Load-bearing, and it was missing.**
        ///
        /// `exclusionZones` is fed straight into the packer but was not part of the cache
        /// key, so two different exclusion rects at the same quantised box returned the
        /// same placement. Onboarding derives its zone from `measuredDockHeight`, and O-5
        /// introduced that measurement precisely because a hardcoded guess left words
        /// underneath a dock that had grown at large accessibility text sizes. The cache
        /// silently handed back the pre-growth layout and re-created the bug the
        /// measurement existed to fix — visible only at a text size nobody re-tests at.
        ///
        /// Predates the drift work; surfaced here because both renderers now build the key
        /// through one function.
        let exclusion: [Int]
    }

    /// Collapses exclusion rects onto the same 8 pt grid the box uses.
    ///
    /// Quantised for the same reason the box is: the dock's measured height changes by
    /// fractions of a point as type settles, and an exact key would miss on every one of
    /// them and re-run the packer inside `body`.
    static func exclusionSignature(_ zones: [CGRect]) -> [Int] {
        zones.flatMap { rect in
            [Int((rect.minX / 8).rounded()), Int((rect.minY / 8).rounded()),
             Int((rect.width / 8).rounded()), Int((rect.height / 8).rounded())]
        }
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

        // Quantised to a coarse grid, and PACKED at the quantised size, not the real one.
        //
        // The key used to be the exact rounded pixel size. The indexing strip animates its
        // own height (and the banner grows when its queue list expands), so a single
        // animation swept the GeometryReader through every intermediate height — each a
        // fresh key, each a full cache miss, each running the Archimedean packer
        // synchronously inside `body` on the main thread, and each leaving a permanent
        // entry in an unbounded dictionary. Bucketing collapses that whole sweep to at most
        // a handful of layouts.
        //
        // Rounding DOWN matters: the packer then places words inside a box no larger than
        // the one being drawn, so a bucket boundary can never push a word outside the frame.
        let box = Self.quantised(size)
        let key = LayoutKey(width: Int(box.width), height: Int(box.height),
                            lens: lens, scopeKey: scopeKey, composition: composition,
                            exclusion: Self.exclusionSignature(exclusionZones))
        if let cached = layouts[key] {
            return Resolved(words: cached, provenance: source.provenance, maxCount: maxCount, lens: lens)
        }
        // The packer is deterministic given its inputs, so the seed is implicit: the same
        // scope at the same size always lays out identically, which is what makes the cache
        // sound and the cloud stable across relaunches.
        let placed = layout(for: lens, terms: source.terms, box: box)
        return Resolved(words: placed, provenance: source.provenance, maxCount: maxCount, lens: lens)
    }

    /// Builds the drift renderer's immutable input: one packed, coloured field per lens.
    ///
    /// Runs in `body`, deliberately. Everything expensive or observable lives here —
    /// `BundledCloudVectors.terms`, the packer (behind its cache), and the sentiment
    /// polarity lookup, which is a linear scan of an 865-entry vocabulary per word. The
    /// render closure then reads nothing but the returned value. That is the rule
    /// `CrossReferenceGraphView` already records for its own canvas; at 120 Hz it is the
    /// difference between ~21,000 string comparisons every 4.2 seconds and 2.6 million a
    /// second.
    ///
    /// All four lenses are built, not just the visible one, so the canvas can cross-fade and
    /// cycle without ever invalidating this body.
    private func driftSnapshot(size: CGSize) -> WordCloudDriftCanvas.Snapshot? {
        guard size.width > 40, size.height > 40 else { return nil }
        let box = Self.quantised(size)
        var layers: [WordCloudDriftCanvas.Snapshot.Layer] = []

        for candidate in lenses {
            guard let source = BundledCloudVectors.terms(forScope: scope, lens: candidate),
                  let maxCount = source.terms.first?.count else { continue }
            // An empty placement is KEPT, not skipped. The chip reads its lens from
            // `lensIndex`, the canvas derives its layer from the same clock, and the two
            // agree only while layer index == lens index. Dropping a lens here would shift
            // every later index by one and the chip would start naming the wrong lens —
            // the same class of defect as the O-2 chip bug, which took looking at the
            // screen to find. A lens with no vectors at all is still skipped, because then
            // there is nothing to name either.
            let placed = layout(for: candidate, terms: source.terms, box: box)
            let field = WordCloudDriftField(placed: placed, rankCeiling: Self.rankCeiling,
                                            exclusionZones: exclusionZones,
                                            canvas: box,
                                            fill: Self.fillFactor(for: box, composition: composition))
            var colors: [String: Color] = [:]
            var sizes: [String: CGFloat] = [:]
            for word in placed {
                colors[word.term] = color(for: word, lens: candidate, maxCount: maxCount)
                // Resolved at the ceiling so the renderer only ever scales down — a symbol's
                // glyph outlines are resolution-independent but its layout metrics are not.
                sizes[word.term] = word.fontSize * WordCloudDriftField.maximumScale
            }
            layers.append(.init(lens: candidate, field: field,
                                colors: colors, symbolFontSizes: sizes))
        }
        guard !layers.isEmpty else { return nil }
        // Flattened here rather than in the ViewBuilder: (lens, term) is unique by
        // construction, where a nested ForEach keyed on the bare term is not.
        let symbols = layers.flatMap { layer in
            layer.field.particles.map { particle in
                WordCloudDriftCanvas.Snapshot.Symbol(
                    key: .init(lens: layer.lens, term: particle.term),
                    fontSize: layer.symbolFontSizes[particle.term] ?? particle.baseFontSize,
                    color: layer.colors[particle.term] ?? .primary)
            }
        }
        return .init(layers: layers, symbols: symbols, size: box)
    }

    /// The packer result for one lens at one box, through the same cache the static path uses.
    private func layout(for candidate: WordCloudLens, terms: [TermCount], box: CGSize) -> [PlacedWord] {
        let key = LayoutKey(width: Int(box.width), height: Int(box.height),
                            lens: candidate, scopeKey: scopeKey, composition: composition,
                            exclusion: Self.exclusionSignature(exclusionZones))
        if let cached = layouts[key] { return cached }
        let placed = WordCloudLayout.place(
            terms: terms,
            in: box,
            maxWords: Self.wordCount(for: box, composition: composition),
            minFontSize: 12,
            maxFontSize: min(42, max(28, box.width / 12)),
            exclusionZones: exclusionZones,
            yCompression: FRUSTheme.cloudYCompression,
            sizeExponent: FRUSTheme.cloudSizeExponent
        )
        Task { @MainActor in
            if layouts.count >= Self.layoutCacheLimit { layouts.removeAll() }
            layouts[key] = placed
        }
        return placed
    }

    /// The rank ceiling the depth model normalises by, so depth means the same thing on
    /// every surface regardless of how many words a given frame could fit.
    static let rankCeiling = 50

    /// Words to ask the packer for, scaled to the frame.
    ///
    /// A 96 pt strip and a 1200 pt window are not the same brief. Twenty-five words is right
    /// for a band; on a full window it is a handful of terms in a large void, which is the
    /// complaint this answers. Every bundled `(scope, lens)` list holds exactly fifty
    /// entries, so fifty is the ceiling the data supports — asking for more would silently
    /// get fewer.
    ///
    /// Measured cost at the top of that range: 50 words across two lenses is 100 particles
    /// mid-crossfade, ~2.6 ms per frame in the worst (fully cold) measurement and far less
    /// warm. 200 particles was 6.2 ms — three quarters of a 120 Hz budget — which is why
    /// this stops at fifty rather than scaling indefinitely.
    static func wordCount(for box: CGSize, composition: Composition = .automatic) -> Int {
        // A declared band is a band at any size — see `composition`.
        guard composition != .band else { return 25 }
        // Height first, and area only after — the same discriminator `fillFactor` uses, so
        // the two cannot disagree about what a band is. Area alone got this wrong: an
        // 820 x 96 strip is 78,720 pt², indistinguishable by area from a small square, and
        // the strip was handed 35 words for a space that fits fifteen.
        guard box.height >= Self.bandHeight else { return 25 }
        return box.width * box.height < 250_000 ? 35 : 50
    }

    /// Below this height a surface is a band, not a window: no extra words, no bleed.
    static let bandHeight: CGFloat = 160

    /// How a host wants its cloud composed.
    ///
    /// Only two cases, because only one direction needs forcing: a surface can know it is a band
    /// with content over it, and nothing needs to claim to be a field it is not big enough to be.
    enum Composition: Equatable, Sendable {
        /// Infer from the frame — every surface's behaviour before ``Composition`` existed.
        case automatic
        /// A band carrying live content: contained, no bleed, a band's word count, whatever the
        /// frame grows to.
        case band
    }

    /// How much of the frame the field should occupy, and whether it may bleed off the edge.
    ///
    /// A short strip stays fully contained — a word clipped by a 96 pt band reads as a
    /// rendering fault, not as depth. A large surface spreads past its own edges, which is
    /// what separates being inside a cloud from looking at a picture of one.
    static func fillFactor(for box: CGSize, composition: Composition = .automatic) -> CGFloat {
        guard composition != .band else { return 0.98 }
        return box.height < Self.bandHeight ? 0.98 : 1.12
    }

    /// Snaps a size down to the layout grid.
    ///
    /// 8 pt is fine enough that the cloud never looks mis-fitted inside its box and coarse
    /// enough that a height animation crosses only a few buckets.
    private static func quantised(_ size: CGSize) -> CGSize {
        let grid: CGFloat = 8
        return CGSize(width: max(grid, (size.width / grid).rounded(.down) * grid),
                      height: max(grid, (size.height / grid).rounded(.down) * grid))
    }

    /// Layouts kept before the cache is dropped wholesale.
    private static let layoutCacheLimit = 32

    private var scopeKey: String {
        switch scope {
        case .corpus: return "corpus"
        case .subseries(let id): return id
        case .volume(let id, _): return id
        }
    }

    // MARK: - Appearance

    private func color(for word: PlacedWord, resolved: Resolved) -> Color {
        color(for: word, lens: resolved.lens, maxCount: resolved.maxCount)
    }

    /// The same rule, with the lens passed in rather than read off live `@State`.
    ///
    /// The original read `lens` — the computed property off `lensIndex` — while taking
    /// `resolved.lens` as its other input. Equal within one body pass, but the drift
    /// snapshot colours four lenses in a single pass, so the live value is wrong for three
    /// of them.
    private func color(for word: PlacedWord, lens candidate: WordCloudLens, maxCount: Int) -> Color {
        let weight = Double(word.count) / Double(max(1, maxCount))
        if candidate == .sentiment {
            switch BundledCloudVectors.polarity(of: word.term, inScope: scope, lens: candidate) {
            case 1:  return FRUSTheme.cloudSentimentPositive
            case -1: return FRUSTheme.cloudSentimentNegative
            default: break
            }
        }
        if weight > FRUSTheme.cloudAccentThreshold { return FRUSTheme.cloudAccent(for: candidate) }
        // Ink, deepening with weight — the hand-off's rgba(58,62,72, 0.35 + 0.5 × w).
        return Color.primary.opacity(0.35 + 0.5 * weight)
    }

    /// Reduce Motion: crossfade only — no scale, no stagger.
    private var crossfade: Animation {
        reduceMotion
            ? .easeInOut(duration: FRUSTheme.cloudFadeOutDuration)
            : .easeInOut(duration: FRUSTheme.cloudTransformDuration)
    }

    private func wordTransition(rank: Int, count: Int) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.86))
                .animation(.easeOut(duration: FRUSTheme.cloudTransformDuration)
                    .delay(Self.staggerDelay(rank: rank, count: count,
                                             perWord: FRUSTheme.cloudStaggerIn))),
            removal: .opacity.combined(with: .scale(scale: 0.86))
                .animation(.easeIn(duration: FRUSTheme.cloudFadeOutDuration)
                    .delay(Self.staggerDelay(rank: rank, count: count,
                                             perWord: FRUSTheme.cloudStaggerOut)))
        )
    }

    /// How long word `rank` of `count` waits before it joins or leaves, in seconds.
    ///
    /// **The stagger is a BUDGET, not a per-word constant, and it was a per-word constant.** Both
    /// figures in `FRUSTheme` were authored for twenty-five words; a full-bleed surface asks for
    /// fifty, which doubled a tail nobody re-tuned. Holding the total fixed at whatever the
    /// reference count implies returns the authored value EXACTLY at twenty-five and halves it at
    /// fifty, so the rhythm is preserved at the size it was designed for and merely stops growing
    /// past it. At fifty words the incoming tail goes 1.86 s -> 0.93 s inside a 4.2 s hold.
    ///
    /// `min` rather than a plain division, so a cloud with FEWER words than the reference keeps the
    /// authored rhythm instead of smearing a fixed budget across a handful of terms.
    ///
    /// - Parameters:
    ///   - rank: the word's position, 0 for the largest.
    ///   - count: how many words this surface is drawing.
    ///   - perWord: the authored delay — `FRUSTheme.cloudStaggerIn` or `…Out`.
    /// - Returns: that word's delay.
    static func staggerDelay(rank: Int, count: Int, perWord: Double) -> Double {
        let reference = Double(max(2, FRUSTheme.cloudStaggerReferenceWordCount) - 1)
        let budget = perWord * reference
        let spread = count > 1 ? min(perWord, budget / Double(count - 1)) : perWord
        return Double(rank) * spread
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
