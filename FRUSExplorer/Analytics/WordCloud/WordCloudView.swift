// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftData
import SwiftUI

/// Presentation mode for the word cloud.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudViewMode: String, CaseIterable {
    /// Spiral tag cloud.
    case cloud
    /// Ranked term/count list (also the accessibility representation of the cloud).
    case list

    /// Localised toolbar label.
    var label: String {
        switch self {
        case .cloud: return String(localized: "wordcloud.mode.cloud", defaultValue: "Cloud")
        case .list:  return String(localized: "wordcloud.mode.list", defaultValue: "List")
        }
    }

    /// SF Symbol for the segmented control.
    var systemImage: String {
        switch self {
        case .cloud: return "cloud"
        case .list:  return "list.number"
        }
    }
}

/// Observable progress holder for long-running (corpus/subseries) computation.
///
/// Main-actor isolated so the service's `@Sendable` progress callback can update
/// it from a hop to the main actor and SwiftUI observes the change.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 3 progress reporting
@MainActor @Observable final class WordCloudProgressModel {
    /// Fraction complete in `0...1`, or `nil` when indeterminate / idle.
    var fraction: Double?
}

/// Displays a word cloud for a `WordCloudScope` — the most frequent meaningful
/// terms across the document(s) the scope resolves to.
///
/// Two modes share one data set: a spiral tag **cloud** (font size ∝ √count) and
/// a ranked **list**. The list doubles as the cloud's `accessibilityRepresentation`,
/// since a scattered cloud is opaque to VoiceOver. Tapping any term hands off to
/// **Corpus Analytics** (`pendingAnalytics`) for a **corpus-wide** frequency view of
/// that term across the series — the same for every cloud scope, since seeing a term's
/// arc across the whole FRUS run is the feature's point. For volume- and
/// subseries-scoped clouds the word context menu adds an "analyze within this
/// volume/subseries" option, and a direct "Search for this term" shortcut is always
/// offered. The view can be exported as PNG, PDF, or CSV.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — Session 164: word taps hand off to Corpus Analytics rather than Search,
///          corpus-wide by default; volume/subseries clouds get an optional scoped
///          handoff via the word context menu; Search stays on the context menu
///   1.2 — Word Cloud fixes: `load()` no longer cancels `loadTask` (a self-cancel
///          when running inside it left the spinner stuck after "Show hidden words");
///          call sites cancel the previous load instead
///   1.3 — Session 2026-07-04 (UI audit A8): the sentiment lens honors Differentiate
///          Without Color — polarised words gain +/− prefixes (in the layout input,
///          so packing stays overlap-free), the legend swaps its dots for the same
///          glyphs, and image exports carry the marks through
///   1.4 — Session 2 / #233: a word's menu can "Hide in this word cloud" — a
///          non-persistent, per-open-cloud hide (`sessionHiddenWords`) applied at the
///          display layer via `visibleTerms`, so it is instant, backfills from the fetched
///          surplus, and evaporates when the cloud closes; "Show N hidden words" now also
///          restores it
///   1.5 — #258 Phase 5: `.customScope` clouds — the scope bar gains a "My Volume
///          Scopes" section (FTS-grain Menu idiom), and custom-scope clouds join the
///          volume-aligned scoped-Analytics handoff (offered only when the resolved
///          indexed set is non-empty — never hand Analytics a bare empty set)
///   1.6 — Q wave: the index-unavailable placeholder named `cloud.slash`, which does not
///          exist — it had been rendering as a blank. `SymbolNameAuditTests` now gates every
///          literal symbol name in the app.

struct WordCloudView: View {

    /// The body of material to visualise.
    let scope: WordCloudScope

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Differentiate Without Color (UI audit A8): when set, the sentiment lens adds
    /// +/− prefixes to polarised words (cloud, list, legend, and image exports) so
    /// polarity is never conveyed by hue alone.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    /// #338 step 3: the scene (window) this cloud renders in, so its Analyze / Chronology hand-offs
    /// address the same window. Injected into the iOS word-cloud sheet by `MainTabView`; nil on macOS,
    /// where the helper targets the singleton analytics / chronology windows.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Excludes FRUS-boilerplate words ("telegram", "department", …) in addition
    /// to the always-on English stopwords. Persisted; defaults on.
    @AppStorage(WordCloudSettings.Keys.excludeBoilerplate) private var excludeBoilerplate = true

    /// Whether the cloud ranks by raw frequency or by keyness against the bundled corpus reference.
    /// `@AppStorage`, not `@State`: the macOS window applies `.id(scope.signature)` to this view, so
    /// view state is destroyed whenever the window is retargeted — a `@State` measure would revert
    /// to frequency on the Mac while surviving the same action on iOS.
    @AppStorage(WordCloudSettings.Keys.measure) private var measureRaw = KeynessCloudMeasure.frequency.rawValue

    // Word-cloud criteria mirrored from Settings so changing any of them recomputes
    // an open cloud. The list-based stop lists are covered by `settingsRevision`.
    @AppStorage(WordCloudSettings.Keys.filterMarkings) private var filterMarkings = true
    @AppStorage(WordCloudSettings.Keys.foldPlurals) private var foldPlurals = true
    @AppStorage(WordCloudSettings.Keys.minLength) private var minLength = WordCloudSettings.defaultMinLength
    @AppStorage(WordCloudSettings.Keys.minCount) private var minCount = WordCloudSettings.defaultMinCount
    @AppStorage(WordCloudSettings.Keys.revision) private var settingsRevision = 0

    // Device-local appearance: typeface and packing density. Changing either restyles
    // and re-lays out an open cloud (both feed `LayoutKey`).
    @AppStorage(WordCloudSettings.Keys.fontDesign) private var fontDesignRaw = WordCloudFontDesign.rounded.rawValue
    @AppStorage(WordCloudSettings.Keys.density) private var densityRaw = WordCloudDensity.balanced.rawValue

    /// The resolved typeface family for the cloud.
    private var fontDesign: WordCloudFontDesign { WordCloudFontDesign(rawValue: fontDesignRaw) ?? .rounded }
    /// The resolved packing density for the cloud.
    private var density: WordCloudDensity { WordCloudDensity(rawValue: densityRaw) ?? .balanced }

    @State private var viewMode: WordCloudViewMode = .cloud
    @State private var result: WordCloudResult = .empty
    @State private var title: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var placements: [PlacedWord] = []
    @State private var loadTask: Task<Void, Never>?
    /// The written export awaiting an iOS share sheet; always `nil` on macOS, which saves directly.
    @State private var exportShareItem: AnalyticsExportFile?
    /// A human-readable export failure, surfaced in an alert.
    @State private var exportError: String?
    @State private var progressModel = WordCloudProgressModel()
    @State private var hiddenWords: Set<String> = []
    /// Words hidden **only** for this open cloud (#233): non-persistent, per-view-instance,
    /// lowercased bare terms. Because it is `@State` on the sheet/window-scoped view it
    /// resets automatically when the cloud closes (iOS sheet dismissal) or is retargeted
    /// (the macOS window applies `.id(scope.signature)` to this view). Applied at the
    /// display layer via `visibleTerms`, so a hide is instant and never triggers a recompute.
    @State private var sessionHiddenWords: Set<String> = []
    @State private var comparisonScope: WordCloudScope?
    @State private var lens: WordCloudLens = .allTerms
    /// The keyness reading of the current result, or why there isn't one.
    ///
    /// Recomputed by a `.task(id:)` rather than in a body-computed property: the reference is a
    /// 20,000-entry dictionary and the score is a pass over every term, and a view body may be
    /// evaluated many times per frame.
    @State private var keyness: KeynessCloud.Outcome?

    @Query(sort: \Collection.name) private var collections: [Collection]
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    /// Maximum terms requested from the service (the cloud places a subset).
    /// Shared with the background precompute so their cache keys match.
    private static let termLimit = WordCloudLoader.standardTermLimit

    #if DEBUG
    /// Test seam: the limit this view requests, so an audit can prove it matches the precompute's.
    static var termLimitForTesting: Int { termLimit }
    #endif

    /// Colour palette — all system colours so the cloud adapts to light/dark mode.
    private static let palette: [Color] = [
        .blue, .teal, .indigo, .purple, .pink, .orange, .green, .red, .cyan, .mint
    ]

    var body: some View {
        NavigationStack {
            Group {
                if appState.wordFrequencyService == nil {
                    unavailablePlaceholder
                } else if isLoading {
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if result.terms.isEmpty && lens == .allTerms {
                    emptyView
                } else {
                    content
                }
            }
            .navigationTitle(String(localized: "wordcloud.title", defaultValue: "Word Cloud"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .navigationDestination(item: $comparisonScope) { secondary in
                WordCloudComparisonView(primary: scope, secondary: secondary)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task(id: TaskKey(signature: scope.signature, exclude: excludeBoilerplate,
                          lens: lens, settings: settingsToken)) {
            // Supersede any manual reload (e.g. "Show hidden words") still in
            // flight; this criteria-driven load owns the view state from here.
            loadTask?.cancel()
            loadTask = nil
            await load()
        }
        // Keyed on everything that changes the ANSWER, including the live settings the availability
        // check reads: flipping "Hide common diplomatic words" in this view's own Options menu is
        // one tap, and it is the exact case the reference's configuration guard exists for — a
        // verdict cached against the lens alone would go stale on that tap. `result` is fingerprinted
        // rather than compared, since `WordCloudResult` is not Equatable.
        .task(id: KeynessKey(measure: measureRaw, lens: lens, exclude: excludeBoilerplate,
                             settings: settingsToken, termCount: result.terms.count,
                             tokenTotal: result.totalTokenCount, hidden: sessionHiddenWords,
                             referenceReady: BundledKeynessBaseline.isAvailable)) {
            // The reference decodes off the main actor during launch, so a keyness read taken
            // before it lands verdicts `.noArtifact` — and without `referenceReady` in the key,
            // nothing would ever re-evaluate it. The mode would stay dark for the whole session
            // with a message blaming a missing bundle resource that is present.
            await BundledKeynessBaseline.prepare()
            recomputeKeyness()
        }
        .sheet(item: $exportShareItem) { item in
            AnalyticsExportShareSheet(item: item)
        }
        // D3 Phase 4: a failed export used to be a silent no-op — the exporter returned nil, the
        // sheet never presented, and the menu click simply did nothing.
        .alert(String(localized: "analytics.export.error.title", defaultValue: "Export Failed"),
               isPresented: Binding(get: { exportError != nil },
                                    set: { if !$0 { exportError = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            scopeHeader
            lensBar
            measureBar
            if lens.colorsBySentiment { sentimentLegend }
            Divider()
            if belowSignalThreshold {
                insufficientSignalView
            } else if measure == .keyness, case .unavailable(let reason) = keyness ?? .pending {
                // `.pending` is NOT `.noArtifact`: before the first recompute lands there is no
                // verdict yet, and rendering "the bundled corpus reference could not be loaded" for
                // that frame states a failure that has not happened.
                keynessUnavailableView(reason)
            } else {
                switch viewMode {
                case .cloud: cloudCanvas
                case .list:  measure == .keyness ? AnyView(keynessList) : AnyView(rankedList)
                }
            }
        }
    }

    /// `true` when the active lens depends on semantic signal the current scope
    /// doesn't contain enough of to be meaningful. Keyed to the *unfiltered* `result` so
    /// per-cloud session hides can't tip the cloud into the "Not Enough Signal" placeholder.
    private var belowSignalThreshold: Bool {
        lens.isSignalDependent && result.terms.count < lens.minimumSignalTerms
    }

    /// The terms actually shown — `result.terms` minus this cloud's session hides (#233).
    /// The layout, ranked list, header count, and exports all read this so what the user
    /// sees, curates, and exports agree; the empty-state / signal-threshold / Options-menu
    /// checks deliberately keep reading the full `result` so a user can't hide into a dead end.
    private var visibleTerms: [TermCount] {
        result.visibleTerms(excluding: sessionHiddenWords)
    }

    /// The active measure.
    private var measure: KeynessCloudMeasure {
        KeynessCloudMeasure(rawValue: measureRaw) ?? .frequency
    }

    /// The keyness ranking, when one is available and the user has asked for it.
    private var ranking: KeynessCloud.Ranking? {
        guard measure == .keyness, case .ranked(let ranking) = keyness else { return nil }
        return ranking
    }

    /// The terms handed to the layout.
    ///
    /// Under keyness these are **scaled scores, not counts** — layout input only. Nothing that
    /// renders a number reads them; the keyness list builds its own rows from `KeynessScore`, which
    /// is what stops a G² of 1,240 being printed under the "occurrences" label.
    private var layoutInputTerms: [TermCount] {
        guard let ranking else { return visibleTerms }
        return KeynessCloud.layoutTerms(ranking.scores)
    }

    /// Horizontally-scrolling lens selector. A scrolling chip bar rather than a
    /// fixed segmented control because there are more lenses than fit a phone width.
    private var lensBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WordCloudLens.allCases) { option in
                    lensChip(option)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .accessibilityLabel(String(localized: "wordcloud.lens.label", defaultValue: "Show"))
    }

    /// One selectable lens chip.
    private func lensChip(_ option: WordCloudLens) -> some View {
        let selected = option == lens
        return Button {
            lens = option
        } label: {
            Label(option.label, systemImage: option.systemImage)
                .font(.caption.weight(selected ? .semibold : .regular))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected
                                   ? Color.accentColor
                                   : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Chooses what the cloud is measuring. A segmented picker rather than a menu item because it
    /// changes what every word on screen means, and that should be visible without opening anything.
    private var measureBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Picker(selection: $measureRaw) {
                ForEach(KeynessCloudMeasure.allCases, id: \.rawValue) {
                    Text($0.pickerLabel).tag($0.rawValue)
                }
            } label: {
                Text(String(localized: "wordcloud.measure.label", defaultValue: "Size words by"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            #if os(macOS)
            // Unbounded, a segmented picker stretches the full window width on a wide Mac window.
            .frame(maxWidth: 320, alignment: .leading)
            #endif
            if let ranking {
                // NOT `.fixedSize(vertical:)`: a fixed-size multi-line Text above a greedy List in a
                // non-scrolling VStack pushes content out of view — the shape that blanked the
                // macOS corpus browser. Bounded instead, with the full text available to VoiceOver
                // and as a hover/long-press tooltip.
                Text(keynessCaveat(ranking))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .help(keynessCaveat(ranking))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// What the keyness ranking can and cannot see, stated on screen.
    ///
    /// Two facts a reader needs and cannot infer. The ranking covers only the terms the cloud
    /// fetched, so a word that is rare here but unique to this scope is out of reach — and that is
    /// only true when the fetch was actually cut short, which `rankedAmongTopFrequent` computes
    /// rather than assumes. And the reference prices a truncated head of the corpus vocabulary, so a
    /// term rarer than its cutoff is *unpriced*, not absent — a distinction that decides whether a
    /// word at the top of this list is a finding or an artefact.
    private func keynessCaveat(_ ranking: KeynessCloud.Ranking) -> String {
        var parts: [String] = []
        if ranking.rankedAmongTopFrequent {
            parts.append(String(format: String(
                localized: "wordcloud.keyness.caveat.truncated %lld",
                defaultValue: "Ranked among this scope’s %lld most frequent words."),
                Int64(ranking.candidateCount)))
        } else {
            parts.append(String(format: String(
                localized: "wordcloud.keyness.caveat.complete %lld",
                defaultValue: "Ranked over every word occurring at least %lld times here."),
                Int64(ranking.minimumScopeCount)))
        }
        if ranking.referenceCutoffCount > 1 {
            parts.append(String(format: String(
                localized: "wordcloud.keyness.caveat.reference %lld",
                defaultValue: "Words occurring fewer than %lld times corpus-wide are unpriced and score as if new."),
                Int64(ranking.referenceCutoffCount)))
        }
        return parts.joined(separator: " ")
    }

    /// The keyness reading as a list: the term, how distinctive it is, and both raw counts.
    ///
    /// A separate list from ``rankedList`` rather than a re-sort of it, because the numbers differ in
    /// kind. Printing a G² of 1,240 under the existing "%lld occurrences" label would be a plain
    /// falsehood, and that label is also what VoiceOver announces.
    private var keynessList: some View {
        let scores = ranking?.scores ?? []
        let maxScore = scores.first?.logLikelihood ?? 1
        return List {
            ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                Button { analyze(for: score.term) } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 1) {
                            // A8 parity with `rankedList`: under Differentiate Without Color the
                            // sentiment lens conveys polarity with +/− marks rather than hue, and a
                            // keyness list that dropped them would convey polarity by colour alone.
                            Text(useSentimentMarks
                                 ? WordCloudLexicons.markedTerm(score.term) : score.term)
                                .font(.body)
                                .foregroundStyle(lens.colorsBySentiment
                                                 ? wordColor(term: score.term, colorIndex: index)
                                                 : Color.primary)
                            Text("\(foldDifference(score)) · \(countsCaption(for: score))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                                .lineLimit(2)
                        }
                        Spacer()
                        keynessBar(score: score.logLikelihood, maxScore: maxScore)
                        Text(Self.keynessFormatter.string(from: NSNumber(value: score.logLikelihood))
                             ?? "")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: score.term))
                // Announced as what it IS. Reusing the frequency row's "%lld occurrences" would read
                // a log-likelihood aloud as an occurrence count.
                .accessibilityValue(Text(String(format: String(
                    localized: "wordcloud.keyness.row.a11y %@ %@ %@",
                    defaultValue: "keyness %@; %@; %@"),
                    Self.keynessFormatter.string(from: NSNumber(value: score.logLikelihood)) ?? "",
                    foldDifference(score), countsCaption(for: score))))
                .accessibilityHint(String(localized: "wordcloud.tap.hint",
                                          defaultValue: "Charts this term in Corpus Analytics"))
                .accessibilityAction(named: Text(String(localized: "wordcloud.word.search",
                                                        defaultValue: "Search for this term"))) {
                    search(for: score.term)
                }
                .contextMenu { wordContextMenu(term: score.term) }
            }
        }
        .listStyle(.plain)
    }

    /// The effect size, as a fold difference — "38×" rather than "5.26".
    ///
    /// `KeynessScore.logRatio` is log₂ of the two relative frequencies, which is the corpus-linguistics
    /// convention and is what the CSV export carries for citation. On screen it is raised back to a
    /// plain multiple, because that is the number a reader can act on: `stalin` at log₂ 5.26 and
    /// `babelsberg` at 8.32 are "38× more often here" and "320× more often here", and the second is
    /// a far stronger claim than the two logs make it look.
    ///
    /// This sits beside G², not instead of it, because they answer different questions and the list is
    /// ranked on G². G² conflates effect size with sample size: in *The Conference of Berlin*,
    /// `germany` scores 3,244 on 1,787 uses at 6× while `babelsberg` scores 3,806 on 429 uses at 320×.
    /// Ranking on G² alone therefore ranks partly by how much text a scope contains, which is exactly
    /// what misleads when comparing a small collection with a large volume.
    private func foldDifference(_ score: KeynessScore) -> String {
        let fold = score.foldOverRepresentation
        guard fold.isFinite, fold > 0 else { return "" }
        let formatted = fold >= 10
            ? fold.formatted(.number.precision(.fractionLength(0)))
            : fold.formatted(.number.precision(.fractionLength(1)))
        return String(format: String(localized: "wordcloud.keyness.row.fold %@",
                                     defaultValue: "%@× more often here"), formatted)
    }

    /// The two raw counts under a keyness row — with "unpriced" said plainly.
    ///
    /// A reference count of zero means one of two very different things: the corpus genuinely never
    /// used the word, or the word is rarer corpus-wide than the reference's truncation cutoff and
    /// was never priced. A bare "0 corpus-wide" asserts the first. It is also the row a high keyness
    /// score will have floated to the very top, so it is the one most likely to be read as a finding.
    private func countsCaption(for score: KeynessScore) -> String {
        if ranking?.isUnpriced(score) == true, let cutoff = ranking?.referenceCutoffCount {
            return String(format: String(
                localized: "wordcloud.keyness.row.counts.unpriced %lld %lld",
                defaultValue: "%lld here · fewer than %lld corpus-wide (unpriced)"),
                Int64(score.scopeCount), Int64(cutoff))
        }
        return String(format: String(
            localized: "wordcloud.keyness.row.counts %lld %lld",
            defaultValue: "%lld here · %lld corpus-wide"),
            Int64(score.scopeCount), Int64(score.referenceCount))
    }

    /// One decimal place: G² spans single digits to thousands, and a bare Int would show the whole
    /// bottom of the list as the same number.
    private static let keynessFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()

    /// A proportional bar over the keyness score. Separate from ``weightBar(count:maxCount:)``,
    /// which takes Ints and would produce a negative frame width from a signed score.
    private func keynessBar(score: Double, maxScore: Double) -> some View {
        let fraction = maxScore > 0 ? CGFloat(max(0, min(1, score / maxScore))) : 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.55))
            .frame(width: 60 * fraction, height: 6)
            .frame(width: 60, alignment: .leading)
    }

    /// Why there is no keyness reading — always with the reason, and with the fix when there is one.
    ///
    /// The three unavailable reasons are NOT interchangeable. A configuration mismatch is the only
    /// one the user can act on, so it names the setting; the others explain a structural limit so the
    /// reader stops looking for a control that does not exist.
    private func keynessUnavailableView(_ reason: KeynessCloud.Unavailable) -> some View {
        let detail: String
        switch reason {
        case .pending:
            detail = String(localized: "wordcloud.keyness.unavailable.pending",
                            defaultValue: "Loading the bundled corpus reference…")
        case .noArtifact:
            detail = String(localized: "wordcloud.keyness.unavailable.noArtifact",
                            defaultValue: "The bundled corpus reference could not be loaded, so there is nothing to measure this scope against.")
        case .lensNotPriced(let lens):
            detail = String(format: String(
                localized: "wordcloud.keyness.unavailable.lens %@",
                defaultValue: "The “%@” lens has no corpus reference. Names of people, places, and organizations are not counted across the whole corpus, so there is nothing to compare this scope against. Switch to another lens, or size words by frequency."),
                lens.label)
        case .configurationMismatch(let mismatches):
            detail = String(format: String(
                localized: "wordcloud.keyness.unavailable.mismatch %@",
                defaultValue: "Your settings count words differently from the bundled corpus reference, so the two can’t be compared: %@. Restore that setting to compare this scope with the corpus."),
                Self.mismatchDescription(mismatches))
        case .noTermsAboveFloor(let minimum):
            detail = String(format: String(
                localized: "wordcloud.keyness.unavailable.floor %lld",
                defaultValue: "No word occurs at least %lld times in this scope. A word appearing once or twice can top a keyness ranking without saying anything about the documents, so nothing is ranked."),
                Int64(minimum))
        case .nothingOverRepresented:
            detail = String(localized: "wordcloud.keyness.unavailable.nothingDistinctive",
                            defaultValue: "Nothing here is used more than it is across the corpus. That is a real result, not an error: this scope’s vocabulary is typical of the series.")
        }
        return ContentUnavailableView(
            String(localized: "wordcloud.keyness.unavailable.title", defaultValue: "No Distinctiveness Ranking"),
            systemImage: "chart.bar.doc.horizontal",
            description: Text(detail)
        )
    }

    /// Names the mismatched settings in the user's own vocabulary — the Settings labels, not the
    /// enum cases.
    private static func mismatchDescription(
        _ mismatches: [KeynessBaselineFile.Configuration.Mismatch]
    ) -> String {
        mismatches.map { mismatch in
            switch mismatch {
            case .diplomaticLayer:
                String(localized: "wordcloud.keyness.mismatch.boilerplate",
                       defaultValue: "“Hide common diplomatic words” is off")
            case .foldPlurals:
                String(localized: "wordcloud.keyness.mismatch.plurals",
                       defaultValue: "plural folding differs")
            case .filterMarkings:
                String(localized: "wordcloud.keyness.mismatch.markings",
                       defaultValue: "classification-marking filtering differs")
            case .minimumLength:
                String(localized: "wordcloud.keyness.mismatch.length",
                       defaultValue: "your minimum word length is shorter")
            case .lexicons, .stopwords:
                String(localized: "wordcloud.keyness.mismatch.payload",
                       defaultValue: "the bundled word lists have changed since the reference was built")
            }
        }
        // Duplicates are possible: `.lexicons` and `.stopwords` share one description.
        .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        .joined(separator: "; ")
    }

    /// Colour key shown under the lens bar while the sentiment lens is active.
    private var sentimentLegend: some View {
        HStack(spacing: 14) {
            // A8: under Differentiate Without Color the legend swaps its color dots
            // for the +/− glyphs the cloud prefixes words with.
            Label(String(localized: "wordcloud.sentiment.positive", defaultValue: "Positive"),
                  systemImage: differentiateWithoutColor ? "plus.circle.fill" : "circle.fill")
                .foregroundStyle(.green)
            Label(String(localized: "wordcloud.sentiment.negative", defaultValue: "Negative"),
                  systemImage: differentiateWithoutColor ? "minus.circle.fill" : "circle.fill")
                .foregroundStyle(.red)
            Spacer()
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    /// Shown when a signal-dependent lens (entities, concepts, sentiment) finds too
    /// few matching terms in the current scope to be worth displaying.
    private var insufficientSignalView: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.lens.insufficient.title", defaultValue: "Not Enough Signal"),
            systemImage: lens.systemImage,
            description: Text(String(
                format: String(localized: "wordcloud.lens.insufficient.detail %@",
                               defaultValue: "There aren't enough %@ in this scope to fill a cloud. Try a broader scope or a different lens."),
                lens.label.lowercased()
            ))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Whether the +/− no-color sentiment marks are active (UI audit A8): the
    /// sentiment lens is on AND the user asked for Differentiate Without Color.
    private var useSentimentMarks: Bool {
        differentiateWithoutColor && lens.colorsBySentiment
    }

    // MARK: - Research-grade export (D3 Phase 4)

    /// The methods statement for a word-cloud export.
    ///
    /// `appliesDocumentDating` is **false**: a cloud counts tokens across whatever documents its
    /// scope resolves to and never reads a date, so the shared dating rule and the year-range line
    /// would both describe work this export did not do.
    ///
    /// The caveats disclose what the picture cannot: **every** filter that removed a word before it
    /// could be counted, and — the ones that most affect a reader's trust — the user's own hand
    /// hides and personal stop lists.
    ///
    /// Getting this list complete matters more than usual, because a word never counted is also
    /// absent from `totalTokenCount`, which is the share column's denominator. A caveat that names
    /// only some of the filters therefore mis-describes the numbers themselves, not just the
    /// selection.
    private var cloudProvenance: AnalyticsProvenance {
        let tuning = WordCloudSettings.tuning
        let globalStops = WordCloudSettings.globalStopwords.count
        let lensStops = WordCloudSettings.lensStopwords(lens).count
        var caveats: [String] = [
            // The denominator is LENS-SCOPED: under every lens but "All terms" the tokenizer only
            // counts words that pass the lens gate, so this total — and every share computed from
            // it — describes that lens's vocabulary, not the scope's whole text.
            String(format: String(localized: "wordcloud.export.caveat.population %lld %lld %@",
                                  defaultValue: "Population: these counts cover the %lld document(s) in this scope. The share column divides by %lld, which is every word counted under the \"%@\" lens after the filters below. That is not the scope's total word count. Shares from two different lenses cannot be compared."),
                   Int64(result.documentCount), Int64(result.totalTokenCount), lens.label),
            String(format: String(localized: "wordcloud.export.caveat.stopwords %@ %@",
                                  defaultValue: "Stopwords: common English words are always removed. FRUS boilerplate (telegram, department, embassy…) is %@; classification markings, months, and weekdays (secret, confidential, january…) are %@."),
                   excludeBoilerplate
                   ? String(localized: "wordcloud.export.caveat.stopwords.excluded", defaultValue: "also removed")
                   : String(localized: "wordcloud.export.caveat.stopwords.kept", defaultValue: "kept"),
                   tuning.filterMarkings
                   ? String(localized: "wordcloud.export.caveat.stopwords.excluded", defaultValue: "also removed")
                   : String(localized: "wordcloud.export.caveat.stopwords.kept", defaultValue: "kept")),
            String(format: String(localized: "wordcloud.export.caveat.tuning %lld %lld %@",
                                  defaultValue: "Tuning: words shorter than %lld character(s) and words occurring fewer than %lld time(s) are excluded; plural folding is %@."),
                   Int64(tuning.minimumLength), Int64(tuning.minimumCount),
                   tuning.foldPlurals
                   ? String(localized: "common.on", defaultValue: "on")
                   : String(localized: "common.off", defaultValue: "off")),
        ]
        // Two distinct kinds of user curation, and they act at different points, so they are stated
        // separately rather than added together:
        //  - the SESSION hide removes a word from an already-counted result, so it leaves the
        //    denominator alone;
        //  - a personal stop list removes the word BEFORE counting, so it also shrinks the
        //    denominator. Nothing else in the file reveals either one.
        let handHidden = hiddenWords.union(sessionHiddenWords).count
        if handHidden > 0 {
            caveats.append(String(format: String(localized: "wordcloud.export.caveat.hidden %lld",
                                                 defaultValue: "Hidden words: %lld word(s) were hidden by hand in this cloud and are absent from this export. They were counted before being hidden, so they remain in the denominator above."),
                                  Int64(handHidden)))
        }
        if globalStops + lensStops > 0 {
            caveats.append(String(format: String(localized: "wordcloud.export.caveat.stopLists %lld %lld %@",
                                                 defaultValue: "Your stop lists: %lld word(s) from your global hidden-word list and %lld from your list for the \"%@\" lens were removed before counting. They are in neither this table nor its denominator. You can edit both lists in Settings → Word Cloud."),
                                  Int64(globalStops), Int64(lensStops), lens.label))
        }
        if let ranking {
            caveats.append(String(format: String(
                localized: "wordcloud.export.caveat.keyness %lld %lld %@",
                defaultValue: "Keyness: each word is scored against a built-in reference for the whole FRUS corpus. That reference covers %lld of the corpus's %lld distinct words for this lens, and was generated %@. Only words used more here than in the corpus are listed. A word this scope conspicuously avoids is a real finding, and this table does not carry it."),
                Int64(ranking.referenceRetained), Int64(ranking.referenceDistinct),
                ranking.generated ?? String(localized: "common.unknown", defaultValue: "unknown")))
            caveats.append(ranking.rankedAmongTopFrequent
                ? String(format: String(
                    localized: "wordcloud.export.caveat.keyness.truncated %lld",
                    defaultValue: "Keyness candidates: only this scope's %lld most frequent words were scored, so a word that is rare here but unique to it is outside this ranking."),
                    Int64(ranking.candidateCount))
                : String(format: String(
                    localized: "wordcloud.export.caveat.keyness.complete %lld",
                    defaultValue: "Keyness candidates: every word occurring at least %lld times in this scope was scored."),
                    Int64(ranking.minimumScopeCount)))
            if ranking.referenceCutoffCount > 1 {
                caveats.append(String(format: String(
                    localized: "wordcloud.export.caveat.keyness.cutoff %lld",
                    defaultValue: "Reference coverage: the reference counts only words occurring at least %lld times across the corpus. A rarer word is marked unpriced rather than absent. It is scored as though the corpus never used it. Treat a high score on a rare word with care."),
                    Int64(ranking.referenceCutoffCount)))
            }
        }
        if lens != .allTerms {
            caveats.append(String(format: String(localized: "wordcloud.export.caveat.lens %@",
                                                 defaultValue: "Lens: the cloud is filtered to the \"%@\" word list, so this is a subset of the scope's vocabulary, not its whole frequency ranking."),
                                  lens.label))
        }
        return AnalyticsProvenance(
            // Named rather than reusing the bare scope title, which is also the Scope: line — a
            // preamble that prints the same long volume title twice reads like a bug.
            figureTitle: String(format: String(localized: "wordcloud.export.figureTitle %@",
                                               defaultValue: "Word Cloud — %@"), title),
            // Not a constant: under keyness the ranking is not by frequency, and a plate or CSV
            // that says it is would be a positive assertion of the wrong method — the one thing an
            // exported research artefact must never do.
            axisLabel: ranking != nil
                ? String(localized: "wordcloud.export.axis.keyness",
                         defaultValue: "Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference")
                : String(localized: "wordcloud.export.axis",
                         defaultValue: "Ranked by frequency across the scope's documents"),
            scopeLabel: title,
            indexedVolumeCount: appState.indexedVolumeIds.count,
            yearRange: nil,
            appliesDocumentDating: false,
            // Deliberately nil in BOTH measures. `AnalyticsProvenance.valueModeCaveat` appends a
            // fixed sentence explaining that "a share is that period's matching documents divided by
            // all indexed documents in the same period" — true of the Corpus Analytics charts it was
            // written for, and nonsense above a word cloud, which has no periods and (under keyness)
            // no share column at all. The measure travels in `axisLabel` and the caveats instead.
            valueMode: nil,
            extraCaveats: caveats
        )
    }

    /// Exports the cloud's terms as a provenance-stamped CSV.
    private func exportCSV() {
        let table: ChartInspectorData
        if let ranking {
            table = AnalyticsChartTables.wordCloudKeynessTable(
                title: title,
                scores: ranking.scores.map {
                    (term: $0.term, logLikelihood: $0.logLikelihood, logRatio: $0.logRatio,
                     scopeCount: $0.scopeCount, referenceCount: $0.referenceCount)
                })
        } else {
            table = AnalyticsChartTables.wordCloudTable(
                title: title,
                terms: visibleTerms.map { (term: $0.term, count: $0.count) },
                totalTokens: result.totalTokenCount)
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: title, prefix: Self.filenamePrefix) + ".csv"
        report(AnalyticsExportDelivery.deliver(text: table.provenancedCSV(cloudProvenance),
                                               filename: filename))
    }

    /// The identifying facts printed under the cloud's title in an exported image.
    ///
    /// Deliberately **not** the shared `captionLines`, whose second line leads with the scope — on a
    /// cloud the scope is already the heading directly above, so repeating it wasted the line and
    /// pushed the export date off the end. These are the facts the picture itself cannot carry.
    ///
    /// - Parameter drawnTerms: How many words the layout actually placed. The cloud can rank many
    ///   more than the plate draws, so this is counted from the placements — a caption built from
    ///   `visibleTerms.count` would claim words the reader cannot find.
    /// - Returns: The caption line.
    private func cloudFigureCaption(drawnTerms: Int) -> String {
        [
            String(format: String(localized: "wordcloud.export.caption.documents %lld",
                                  defaultValue: "%lld documents"), Int64(result.documentCount)),
            String(format: String(localized: "wordcloud.export.caption.terms %lld %lld",
                                  defaultValue: "%lld of %lld terms drawn"),
                   Int64(drawnTerms), Int64(layoutInputTerms.count)),
            // Without this a keyness plate and a frequency plate are indistinguishable once they
            // leave the app, and they are answers to different questions.
            ranking != nil
                ? String(localized: "wordcloud.export.caption.keyness",
                         defaultValue: "sized by keyness vs. the FRUS corpus")
                : String(localized: "wordcloud.export.caption.frequency",
                         defaultValue: "sized by frequency"),
            AnalyticsProvenance.appCredit,
            cloudProvenance.formattedDate,
        ].joined(separator: " · ")
    }

    /// Exports the cloud artwork as a PNG or PDF.
    private func exportImage(_ format: AnalyticsFigureFormat) {
        guard let data = WordCloudExporter.imageData(
            terms: layoutInputTerms, title: title,
            provenanceLine: { cloudFigureCaption(drawnTerms: $0) },
            format: format, palette: Self.palette,
            sentimentColors: lens.colorsBySentiment, sentimentMarks: useSentimentMarks
        ) else {
            exportError = String(localized: "analytics.export.error.render",
                                 defaultValue: "The figure could not be rendered.")
            return
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: title, prefix: Self.filenamePrefix)
            + "." + format.pathExtension
        report(AnalyticsExportDelivery.deliver(data: data, filename: filename,
                                               contentType: format.contentType))
    }

    /// Surfaces an export outcome: present the iOS share sheet, or report a failure.
    private func report(_ outcome: AnalyticsExportOutcome) {
        switch outcome {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// Word-cloud exports are filed under their own name, not as analytics charts.
    private static let filenamePrefix = "FRUS-WordCloud"

    /// The colour for a word: sentiment polarity under the sentiment lens, otherwise
    /// the rank-based palette.
    private func wordColor(term: String, colorIndex: Int) -> Color {
        if lens.colorsBySentiment {
            switch WordCloudLexicons.polarity(of: term) {
            case .positive: return .green
            case .negative: return .red
            case .none:     return .secondary
            }
        }
        return Self.palette[colorIndex % Self.palette.count]
    }

    private var scopeHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: WordCloudGlyph.symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                // Counts what is ACTUALLY shown. Under keyness the cloud draws only the
                // over-represented terms, so reporting the frequency count here would name a
                // number of words the reader cannot find anywhere on screen.
                Text(String(
                    format: String(localized: "wordcloud.provenance %lld %lld",
                                   defaultValue: "%lld terms from %lld documents"),
                    Int64(ranking?.scores.count ?? visibleTerms.count), Int64(result.documentCount)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// The spiral tag cloud, with each word an individually tappable, accessible element.
    private var cloudCanvas: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placements) { word in
                    // A8: under the no-color sentiment encoding `word.term` is the
                    // marked display form (the marks were part of the layout input,
                    // so packing accounts for their width); hand-offs and polarity
                    // lookups use the bare term.
                    Text(word.term)
                        .font(.system(size: word.fontSize, weight: .semibold, design: fontDesign.swiftUIDesign))
                        .foregroundStyle(wordColor(term: WordCloudLexicons.bareTerm(word.term),
                                                   colorIndex: word.colorIndex))
                        .fixedSize()
                        .rotationEffect(.degrees(word.rotationDegrees))
                        .position(word.center)
                        .onTapGesture { analyze(for: WordCloudLexicons.bareTerm(word.term)) }
                        .contextMenu { wordContextMenu(term: WordCloudLexicons.bareTerm(word.term)) }
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // Re-ranking leaves `termCount` untouched, so without the measure (and the ranking's
            // own size) the spiral would keep the frequency arrangement while the list re-ordered
            // underneath it.
            .task(id: LayoutKey(measure: measureRaw, rankedCount: ranking?.scores.count ?? 0,
                                width: geo.size.width, height: geo.size.height,
                                signature: scope.signature, exclude: excludeBoilerplate,
                                lens: lens, termCount: result.terms.count,
                                fontDesign: fontDesign, density: density,
                                sentimentMarks: useSentimentMarks,
                                hidden: sessionHiddenWords)) {
                // A8: lay out the marked display terms so the +/− prefixes get the
                // width they render with. Filter this cloud's session hides first (#233),
                // before the mark mapping, so hidden words don't reappear under the
                // sentiment lens (where the layout term carries a +/− prefix).
                let base = layoutInputTerms
                let layoutTerms = useSentimentMarks
                    ? base.map { TermCount(term: WordCloudLexicons.markedTerm($0.term),
                                           count: $0.count) }
                    : base
                placements = WordCloudLayout.place(
                    terms: layoutTerms, in: geo.size,
                    spacingScale: density.spacingScale, widthFactor: fontDesign.widthFactor
                )
            }
        }
        // The representation must follow the MEASURE. `KeynessCloud` drops under-represented terms
        // specifically because this list is what VoiceOver reads instead of the canvas, so leaving
        // it on the frequency list would hand a VoiceOver reader a different set of words, in a
        // different order, announced as occurrence counts — the exact invariant that design note
        // claims to preserve.
        .accessibilityRepresentation {
            measure == .keyness && ranking != nil ? AnyView(keynessList) : AnyView(rankedList)
        }
    }

    /// Ranked term list — also the accessibility representation of the cloud.
    private var rankedList: some View {
        let maxCount = visibleTerms.first?.count ?? 1
        return List {
            ForEach(Array(visibleTerms.enumerated()), id: \.element.id) { index, term in
                Button { analyze(for: term.term) } label: {
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 28, alignment: .trailing)
                        // A8: the list shows the same +/− marks as the cloud under
                        // the no-color sentiment encoding.
                        Text(useSentimentMarks ? WordCloudLexicons.markedTerm(term.term) : term.term)
                            .font(.body)
                            .foregroundStyle(lens.colorsBySentiment
                                             ? wordColor(term: term.term, colorIndex: index)
                                             : Color.primary)
                        Spacer()
                        weightBar(count: term.count, maxCount: maxCount)
                        Text("\(term.count)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: term.term))
                .accessibilityValue(Text(String(
                    format: String(localized: "wordcloud.occurrences %lld",
                                   defaultValue: "%lld occurrences"),
                    Int64(term.count)
                )))
                // The row's tap (its default VoiceOver action) charts the term in Corpus
                // Analytics — not a search (the stale "Search for this term" hint predated
                // the analyze hand-off).
                .accessibilityHint(String(localized: "wordcloud.tap.hint",
                                          defaultValue: "Charts this term in Corpus Analytics"))
                // Mirror the word menu into the VoiceOver actions rotor so hide/search are
                // reachable without opening the context menu (which VoiceOver surfaces
                // inconsistently across platforms).
                .accessibilityAction(named: Text(String(localized: "wordcloud.word.hide.session",
                                                        defaultValue: "Hide in this word cloud"))) {
                    hideWordInThisCloud(term.term)
                }
                .accessibilityAction(named: Text(String(localized: "wordcloud.word.search",
                                                        defaultValue: "Search for this term"))) {
                    search(for: term.term)
                }
                .contextMenu { wordContextMenu(term: term.term) }
            }
        }
        .listStyle(.plain)
    }

    /// A proportional bar visualising a term's share of the top count.
    private func weightBar(count: Int, maxCount: Int) -> some View {
        let fraction = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.55))
            .frame(width: 60 * fraction, height: 6)
            .frame(width: 60, alignment: .leading)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            if let fraction = progressModel.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 240)
                Text(verbatim: "\(Int(fraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
            Text(scope == .corpus
                 ? String(localized: "wordcloud.loading.corpus",
                          defaultValue: "Analyzing the corpus — this can take a moment…")
                 : String(localized: "wordcloud.loading", defaultValue: "Building word cloud…"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.empty.title", defaultValue: "No Terms"),
            systemImage: WordCloudGlyph.symbol,
            description: Text(String(
                localized: "wordcloud.empty.detail",
                defaultValue: "There's no indexed text in this scope yet. Download and index the relevant volumes, then try again."
            ))
        )
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            String(localized: "wordcloud.error.title", defaultValue: "Couldn't Build Word Cloud"),
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "wordcloud.unavailable.title", defaultValue: "Word Cloud Unavailable"),
            systemImage: "exclamationmark.magnifyingglass",
            description: Text(String(
                localized: "wordcloud.unavailable.detail",
                defaultValue: "The search index could not be opened, so word clouds are unavailable."
            ))
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
        }
        #endif
        ToolbarItem(placement: .principal) {
            Picker(String(localized: "wordcloud.mode.label", defaultValue: "View"),
                   selection: $viewMode) {
                ForEach(WordCloudViewMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        ToolbarItem(placement: .primaryAction) {
            FeatureInfoButton(
                heading: String(localized: "wordcloud.info.heading", defaultValue: "About the Word Cloud"),
                items: [
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.shows.title", defaultValue: "What you're seeing"),
                        detail: String(localized: "wordcloud.info.shows.detail.v2",
                                       defaultValue: "The meaningful terms in the chosen scope — a document, volume, subseries, collection, tag, saved search, custom volume scope, or the whole corpus. “Size words by” chooses what the sizes mean.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.measure.title", defaultValue: "Frequency vs. Distinctive"),
                        detail: String(localized: "wordcloud.info.measure.detail",
                                       defaultValue: "Frequency sizes each word by how often it appears here. That tends to surface the vocabulary every FRUS volume shares. Distinctive compares this scope with a built-in reference for the whole corpus. It sizes each word by how much more it is used here than across the series. The measure is log-likelihood keyness, the corpus-linguistics standard. Distinctive lists only words used more here than in the corpus. A word this scope conspicuously avoids is a real finding, and it will not appear. Words occurring fewer than three times here are never ranked. One or two mentions can top a keyness list without telling you anything about the documents.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.keyness.numbers.title",
                                      defaultValue: "Reading the Distinctive list"),
                        detail: String(localized: "wordcloud.info.keyness.numbers.detail",
                                       defaultValue: "Each row carries two numbers, and they answer different questions. The score on the right is log-likelihood (G²). It measures how strong the evidence is that the difference is real, and the list is ranked on it. “38× more often here” is the effect size: how much more often the word is used here than across the corpus, per word of text. G² grows with the amount of text, so a long volume scores higher than a short collection for the same effect. When you compare two scopes, compare the multiples. A word marked “unpriced” occurs too rarely across the corpus to be counted in the reference, so its multiple is an upper bound.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.lenses.title", defaultValue: "Lenses"),
                        detail: String(localized: "wordcloud.info.lenses.detail",
                                       defaultValue: "The lens chips narrow the cloud to a kind of term — People, Places, Organizations, Topics, Actions, Descriptors, Concepts, or Sentiment — using on-device language analysis.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.filters.title", defaultValue: "What's filtered out"),
                        detail: String(localized: "wordcloud.info.filters.detail",
                                       defaultValue: "Common stopwords are always removed. A word's own menu can hide it from this cloud only, which lasts until you next open it. The same menu can add it to a hidden-word list, either global or for one lens. You manage those lists in Settings → Word Cloud. You can also hide diplomatic boilerplate. Use “Show hidden words” in the Options menu to bring hidden words back.")),
                    FeatureInfoItem(
                        title: String(localized: "wordcloud.info.tap.title", defaultValue: "Tapping a word"),
                        detail: String(localized: "wordcloud.info.tap.detail",
                                       defaultValue: "Charts how often that term appears across the whole corpus in Corpus Analytics; the word's menu also offers a scoped chart and a direct Search.")),
                ]
            )
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if isDateRangeScope {
                    Button {
                        viewInChronology()
                    } label: {
                        Label(String(localized: "wordcloud.viewInChronology",
                                     defaultValue: "View in Chronology"),
                              systemImage: "calendar.day.timeline.left")
                    }
                    Divider()
                }
                Toggle(String(localized: "wordcloud.filter.boilerplate",
                              defaultValue: "Hide common diplomatic words"),
                       isOn: $excludeBoilerplate)
                if !hiddenWords.isEmpty || !sessionHiddenWords.isEmpty {
                    Button {
                        resetHiddenWords()
                    } label: {
                        // Union of the persistent per-scope hides and this cloud's session
                        // hides, de-duplicated so a word hidden both ways is counted once.
                        Label(String(format: String(localized: "wordcloud.filter.showHidden %lld",
                                                     defaultValue: "Show %lld hidden words"),
                                     Int64(hiddenWords.union(sessionHiddenWords).count)),
                              systemImage: "eye")
                    }
                }
                Divider()
                compareMenu
                Divider()
                Section(String(localized: "wordcloud.export.section", defaultValue: "Export")) {
                    Button {
                        exportCSV()
                    } label: {
                        Label(String(localized: "wordcloud.export.csv", defaultValue: "CSV…"),
                              systemImage: "tablecells")
                    }
                    Button {
                        exportImage(.png)
                    } label: {
                        Label(String(localized: "wordcloud.export.png", defaultValue: "Image (PNG)…"),
                              systemImage: "photo")
                    }
                    Button {
                        exportImage(.pdf)
                    } label: {
                        Label(String(localized: "wordcloud.export.pdf", defaultValue: "PDF…"),
                              systemImage: "doc.richtext")
                    }
                }
                // Gated on isLoading too: during a recompute `result` still holds the PREVIOUS
                // criteria's terms and totals, while the provenance reads settings live — so an
                // export taken mid-reload would stamp the new method onto the old numbers.
                // Also gated on the keyness verdict: with Distinctive selected but no ranking, the
                // data would be frequency rows while the user believes they are exporting keyness.
                // Gating the provenance alone is not enough — the FILE would be honest and the
                // ACTION still surprising.
                .disabled(visibleTerms.isEmpty || isLoading || (measure == .keyness && ranking == nil))
            } label: {
                Label(String(localized: "wordcloud.menu", defaultValue: "Options"),
                      systemImage: "ellipsis.circle")
            }
            .disabled(result.terms.isEmpty)
        }
    }

    /// "Compare with…" submenu: pick a second scope (corpus, a collection, or a
    /// tag) to view side by side with the current one.
    @ViewBuilder
    private var compareMenu: some View {
        Menu {
            // `ComparativeCloudColumn` is a separate host with its own loader and no measure of its
            // own, so a side-by-side comparison is always by frequency. Offering it unlabelled two
            // rows under a keyness cloud would put two contradictory answers to one question in one
            // menu. Out of scope to unify here; stated rather than left to be discovered.
            if measure == .keyness {
                Section(String(localized: "wordcloud.compare.frequencyOnly",
                               defaultValue: "Side-by-side compares by frequency")) { EmptyView() }
            }
            if scope != .corpus {
                Button(String(localized: "wordcloud.compare.corpus", defaultValue: "Corpus")) {
                    comparisonScope = .corpus
                }
            }
            if !collections.isEmpty {
                Menu(String(localized: "wordcloud.compare.collections", defaultValue: "Collection")) {
                    ForEach(collections) { collection in
                        let candidate = WordCloudScope.collection(id: collection.id)
                        if candidate != scope {
                            Button(collection.name.isEmpty
                                   ? String(localized: "wordcloud.compare.untitled", defaultValue: "Untitled")
                                   : collection.name) {
                                comparisonScope = candidate
                            }
                        }
                    }
                }
            }
            if !tags.isEmpty {
                Menu(String(localized: "wordcloud.compare.tags", defaultValue: "Tag")) {
                    ForEach(tags) { tag in
                        let candidate = WordCloudScope.userTag(id: tag.id)
                        if candidate != scope {
                            Button(tag.name) { comparisonScope = candidate }
                        }
                    }
                }
            }
        } label: {
            Label(String(localized: "wordcloud.compare.menu", defaultValue: "Compare with…"),
                  systemImage: "rectangle.split.2x1")
        }
    }

    // MARK: - Loading & Actions

    /// Resolves the scope and computes its top terms.
    ///
    /// Runs inside either the criteria-driven `.task(id:)` or a manual reload task
    /// (`loadTask`). Callers cancel any previous load *before* starting a new one;
    /// `load()` itself must never cancel `loadTask`, because when it runs inside
    /// `loadTask` a self-cancel aborts the load it is performing — the early
    /// cancellation return then skips `isLoading = false` and the spinner never clears.
    /// Re-ranks the loaded terms by keyness, or records why it cannot.
    ///
    /// Reads `WordCloudSettings.tuning` rather than this view's four raw `@AppStorage` mirrors: the
    /// static accessor CLAMPS (`max(2, minLength)`, `max(1, minCount)`) and is the value
    /// `WordCloudLoader` actually counted the scope with. Checking availability against the
    /// unclamped mirrors would describe a tokenisation that did not produce the numbers on screen.
    ///
    /// `includeDiplomatic:` is `excludeBoilerplate` **verbatim**. The two names sound opposite and
    /// are not: `WordCloudLoader.load` passes `includeDiplomaticStopwords: excludeBoilerplate`
    /// straight through. Negating it here would compile, read plausibly, and invert the one guard
    /// that stops `department`/`telegram`/`washington` — reference count zero — from being ranked as
    /// the corpus's most distinctive vocabulary.
    private func recomputeKeyness() {
        guard measure == .keyness else { keyness = nil; return }
        keyness = KeynessCloud.rank(
            terms: visibleTerms,
            scopeTotal: result.totalTokenCount,
            // The FETCHED count, not `visibleTerms.count`: a single session hide would otherwise
            // take a full 220-term fetch to 219 and flip the caveat to a claim of completeness.
            fetchedTermCount: result.terms.count,
            termLimit: Self.termLimit,
            lens: lens,
            tuning: WordCloudSettings.tuning,
            includeDiplomatic: excludeBoilerplate
        )
    }

    /// Resolves the scope and computes its top terms.
    ///
    /// Runs inside either the criteria-driven `.task(id:)` or a manual reload task
    /// (`loadTask`). Callers cancel any previous load *before* starting a new one;
    /// `load()` itself must never cancel `loadTask`, because when it runs inside
    /// `loadTask` a self-cancel aborts the load it is performing — the early
    /// cancellation return then skips `isLoading = false` and the spinner never clears.
    private func load() async {
        guard appState.wordFrequencyService != nil else { return }
        isLoading = true
        errorMessage = nil
        progressModel.fraction = nil
        hiddenWords = WordCloudOverrides.hidden(for: scope.signature)

        // Heavy scopes (corpus, subseries) report determinate progress and persist
        // their result to disk. The handler hops to the main actor to update state.
        let model = progressModel
        let handler: WordCloudProgress = { processed, total in
            Task { @MainActor in
                model.fraction = total > 0 ? Double(processed) / Double(total) : nil
            }
        }

        do {
            let (computed, loadedTitle) = try await WordCloudLoader.load(
                scope: scope, excludeBoilerplate: excludeBoilerplate,
                hiddenWords: hiddenWords, limit: Self.termLimit, lens: lens,
                appState: appState, modelContext: modelContext, progress: handler
            )
            if Task.isCancelled { return }
            title = loadedTitle
            result = computed
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        progressModel.fraction = nil
        isLoading = false
    }

    /// Shared context-menu actions for a word (cloud glyph or list row).
    @ViewBuilder
    private func wordContextMenu(term: String) -> some View {
        // Default handoff — corpus-wide frequency of the term across the whole series,
        // matching a plain tap.
        Button {
            analyze(for: term)
        } label: {
            Label(String(localized: "wordcloud.word.analyze", defaultValue: "Analyze in Corpus Analytics"),
                  systemImage: "chart.bar.xaxis")
        }
        // Optional scoped handoff — only offered for volume/subseries clouds, where
        // Analytics can restrict the chart to the cloud's own volumes.
        if let scopedLabel = scopedAnalyzeMenuLabel {
            Button {
                analyze(for: term, scoped: true)
            } label: {
                Label(scopedLabel, systemImage: "chart.bar.xaxis.ascending")
            }
        }
        Button {
            search(for: term)
        } label: {
            Label(String(localized: "wordcloud.word.search", defaultValue: "Search for this term"),
                  systemImage: "magnifyingglass")
        }
        // Hide actions, narrowest → broadest scope: this cloud (non-persistent, until it
        // closes) → this lens (persists) → all word clouds (persists, broadest) (#233).
        Button(role: .destructive) {
            hideWordInThisCloud(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide.session",
                         defaultValue: "Hide in this word cloud"),
                  systemImage: "eye.slash.fill")
        }
        Button(role: .destructive) {
            hideWordInLens(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide.lens",
                         defaultValue: "Hide this word in this lens"),
                  systemImage: "eye.slash.circle")
        }
        Button(role: .destructive) {
            hideWordGlobally(term)
        } label: {
            Label(String(localized: "wordcloud.word.hide.global",
                         defaultValue: "Hide this word in all word clouds"),
                  systemImage: "eye.slash")
        }
    }

    /// Hides `term` from **this open cloud only** (#233): non-persistent, no recompute.
    /// Inserting into `sessionHiddenWords` updates `visibleTerms` and the `LayoutKey`, so the
    /// cloud, ranked list, header count, and exports all drop the word and the cloud backfills
    /// from the fetched surplus instantly. Reversible via the Options menu's "Show N hidden
    /// words"; evaporates when the cloud closes.
    private func hideWordInThisCloud(_ term: String) {
        sessionHiddenWords.insert(term.lowercased())
        AccessibilityNotification.Announcement(
            String(format: String(localized: "wordcloud.word.hidden.a11y",
                                   defaultValue: "%@ hidden from this word cloud"),
                   term)
        ).post()
    }

    /// Hides `term` from **every** word cloud by adding it to the global custom stop
    /// list (`WordCloudSettings`), and removes it from the current result immediately
    /// for instant feedback. Persisting bumps the settings revision, so any open cloud
    /// recomputes from the authoritative list on the next pass. Manage/un-hide these in
    /// Settings → Word Cloud.
    private func hideWordGlobally(_ term: String) {
        WordCloudSettings.addGlobalStopword(term)
        removeTermFromResult(term)
    }

    /// Hides `term` only under the currently-selected lens (its per-lens custom stop
    /// list), so it stays visible under other lenses. Removes it from the current
    /// result immediately.
    private func hideWordInLens(_ term: String) {
        WordCloudSettings.addLensStopword(term, lens: lens)
        removeTermFromResult(term)
    }

    /// Removes `term` from the displayed result without a recompute, so a hide takes
    /// effect instantly. Case-insensitive because the stop lists store lowercased words.
    private func removeTermFromResult(_ term: String) {
        let lower = term.lowercased()
        result = WordCloudResult(
            terms: result.terms.filter { $0.term.lowercased() != lower },
            documentCount: result.documentCount,
            totalTokenCount: result.totalTokenCount
        )
    }

    /// Restores every word hidden from this cloud — both the non-persistent session hides
    /// (#233) and this scope's persistent `WordCloudOverrides`.
    ///
    /// Session hides clear with a pure state change (no recompute — `visibleTerms` and the
    /// `LayoutKey` update immediately). Only when persistent overrides were also in play does
    /// the cloud reload from the pipeline. The previous manual load (if any) is cancelled
    /// *before* the new task is created — never from inside `load()`, which would self-cancel
    /// (see `load()`).
    private func resetHiddenWords() {
        sessionHiddenWords.removeAll()
        // `hiddenWords` mirrors the persisted per-scope overrides (set in `load()`); when it
        // is empty only session hides were active, so skip the pipeline recompute entirely.
        guard !hiddenWords.isEmpty else { return }
        WordCloudOverrides.reset(for: scope.signature)
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    /// Primary word-tap action: hands off to Corpus Analytics seeded with `term`.
    ///
    /// By default the handoff is **corpus-wide**, regardless of the cloud's own scope —
    /// the point of the feature is to see how a term that caught the user's eye appears
    /// across the whole FRUS series, which is more revealing than a scope-local count.
    /// Pass `scoped: true` (the volume/subseries-only context-menu action) to instead
    /// restrict Analytics to the cloud's volumes via `analyticsScope()`. From Analytics
    /// the researcher reaches the matching documents through its built-in "View in
    /// Search" gateway.
    private func analyze(for term: String, scoped: Bool = false) {
        let volumeIds: [String]?
        let label: String?
        if scoped {
            (volumeIds, label) = analyticsScope()
        } else {
            (volumeIds, label) = (nil, nil)
        }
        appState.openAnalytics(
            AnalyticsParameters(term: term, scopeVolumeIds: volumeIds, scopeLabel: label),
            from: sceneID
        )
        #if DEBUG
        print("[WordCloudView] Handoff to Corpus Analytics — term: \"\(term)\", scope: \(label ?? "corpus"), volumes: \(volumeIds?.count ?? 0)")
        #endif
        #if os(macOS)
        // Open the Analytics window DIRECTLY (the MainWindowView relay is retired —
        // provenance PR 2); it inherits this word cloud's provenance (transitive bind).
        appState.bindTool(.analytics, to: appState.provenance(of: .wordCloud))
        openWindow.fronting(id: "frus.analytics")
        #else
        // Corpus Analytics is presented from the Browse tab on iOS; bring it forward
        // so the analytics sheet (opened by `BrowserView` on `pendingAnalytics`) is visible.
        appState.openTab(.browse, from: sceneID)
        #endif
        dismiss()
    }

    /// Label for the optional scoped-analytics context-menu action, or `nil` when the
    /// cloud's scope only supports a corpus-wide handoff. Only the volume-aligned
    /// scopes — volume, subseries, and custom volume scopes — can meaningfully
    /// restrict Analytics to their own volumes; corpus, document, collection, tag,
    /// and saved-search clouds offer just the corpus-wide handoff.
    private var scopedAnalyzeMenuLabel: String? {
        switch scope {
        case .volume:
            return String(localized: "wordcloud.word.analyze.volume",
                          defaultValue: "Analyze within this volume")
        case .subseries:
            return String(localized: "wordcloud.word.analyze.subseries",
                          defaultValue: "Analyze within this subseries")
        case .customScope:
            // Offered only when the handoff would be non-empty (#258 invariant:
            // Analytics reads an empty volume set as "no filter", so handing it a
            // bare empty set would silently invert to the whole corpus).
            guard customScopeAnalyticsIds() != nil else { return nil }
            return String(localized: "wordcloud.word.analyze.customScope",
                          defaultValue: "Analyze within this scope")
        case .subjectCategory:
            // Volume-aligned like the others (#308 F6); same #258 empty-set guard.
            guard subjectCategoryAnalyticsIds() != nil else { return nil }
            return String(localized: "wordcloud.word.analyze.subject",
                          defaultValue: "Analyze within this topic")
        case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange:
            return nil
        }
    }

    /// The custom scope's indexed volume ids for the scoped Analytics handoff, or
    /// `nil` when the cloud is not a custom-scope cloud, the record is dangling, or
    /// no member volume is indexed (`.noIndexedMembers`/`.scopeUnavailable` — never
    /// pass an empty set through to Analytics).
    private func customScopeAnalyticsIds() -> [String]? {
        guard case let .customScope(id) = scope else { return nil }
        var descriptor = FetchDescriptor<CustomVolumeScope>(
            predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return nil }
        guard case let .resolved(ids) = CustomScopeResolver.indexedResolution(
            memberVolumeIds: record.volumeIds, indexed: appState.indexedVolumeIds)
        else { return nil }
        return ids.sorted()
    }

    /// The subject-category cloud's volume ids for the scoped Analytics handoff, or `nil`
    /// when the cloud isn't a subject cloud or the resolved volume set is empty (the
    /// profiles index is unavailable, or the category/sub-category tags no volume). Never
    /// returns a bare empty set — Analytics reads that as "no filter" (#258 invariant).
    private func subjectCategoryAnalyticsIds() -> [String]? {
        guard case let .subjectCategory(category, subcategory) = scope else { return nil }
        let resolved = VolumeSubjectProfilesStore.shared?.resolvedByVolume ?? [:]
        let ids: Set<String>
        if let subcategory {
            ids = ScopeFacets.volumeIds(forCategory: category, subcategory: subcategory,
                                        resolvedByVolume: resolved)
        } else {
            ids = ScopeFacets.volumeIds(forCategory: category, resolvedByVolume: resolved)
        }
        return ids.isEmpty ? nil : ids.sorted()
    }

    /// Translates `scope` into the volume-ID scope Corpus Analytics understands, for
    /// the optional scoped context-menu handoff.
    ///
    /// Analytics buckets by whole volumes, so only the volume-aligned scopes carry
    /// through: `.volume` → that volume, `.subseries` → the subseries' volumes,
    /// `.customScope` → the scope's *indexed* members. The remaining scopes —
    /// `.corpus`, plus the sub-volume / document-set scopes `.document`,
    /// `.collection`, `.userTag`, and `.savedSearch`, which Analytics cannot express
    /// at volume granularity — return `(nil, nil)` (corpus-wide); these scopes never
    /// reach this method because `scopedAnalyzeMenuLabel` hides the scoped action
    /// for them.
    ///
    /// - Returns: The volume-ID scope and its display label, or `(nil, nil)` for a
    ///   corpus-wide query.
    private func analyticsScope() -> (volumeIds: [String]?, label: String?) {
        switch scope {
        case let .volume(volumeId):
            return ([volumeId], title.isEmpty ? volumeId : title)
        case let .subseries(subseriesId):
            let volumeIds = appState.manifestStore.bundledEntries
                .filter { $0.subseries == subseriesId }
                .map(\.volumeId)
            guard !volumeIds.isEmpty else { return (nil, nil) }
            return (volumeIds, title.isEmpty ? subseriesId : title)
        case .customScope:
            guard let ids = customScopeAnalyticsIds() else { return (nil, nil) }
            return (ids, title.isEmpty
                    ? String(localized: "wordcloud.scope.customScope",
                             defaultValue: "Volume Scope")
                    : title)
        case .subjectCategory:
            guard let ids = subjectCategoryAnalyticsIds() else { return (nil, nil) }
            return (ids, title.isEmpty
                    ? String(localized: "wordcloud.scope.subject",
                             defaultValue: "Detected Topic")
                    : title)
        case .corpus, .document, .collection, .userTag, .savedSearch, .dateRange:
            return (nil, nil)
        }
    }

    /// Secondary action: hands off to Search pre-filled with `term`, mirroring the
    /// Analytics → Search handoff. Still offered in the word context menu for users
    /// who want to jump straight to the documents rather than via Analytics.
    private func search(for term: String) {
        appState.openSearch(SearchParameters(keywords: term), from: sceneID)
        #if DEBUG
        print("[WordCloudView] Handoff to Search — term: \"\(term)\"")
        #endif
        #if os(macOS)
        // Open the Search window DIRECTLY (the MainWindowView relay is retired —
        // provenance PR 2); it inherits this word cloud's provenance (transitive bind).
        appState.bindTool(.search, to: appState.provenance(of: .wordCloud))
        openWindow.fronting(id: "frus.search")
        #else
        // #369 BUG-10: bring the Search tab forward on iOS. Without this the query runs invisibly on
        // the backgrounded Search tab and the user is dropped back on the word cloud's prior tab —
        // every sibling hand-off (Analyze/Chronology, :844) sets `pendingTab`; this one didn't.
        appState.openTab(.search, from: sceneID)
        #endif
        dismiss()
    }

    /// Whether this cloud is scoped to a date range, gating the "View in Chronology"
    /// handoff (only a date-range cloud maps cleanly back onto the Chronology browser).
    private var isDateRangeScope: Bool {
        if case .dateRange = scope { return true }
        return false
    }

    /// Opens the Chronology browser for this cloud's date range — the inverse of the
    /// "Word Cloud for this range" handoff from Chronology. Only meaningful for a
    /// `.dateRange` scope.
    private func viewInChronology() {
        guard case let .dateRange(startISO, endISO) = scope else { return }
        appState.openChronology(
            ChronologyParameters(
                rangeStart: WordCloudScope.day(fromISO: startISO),
                rangeEnd: WordCloudScope.day(fromISO: endISO)
            ),
            from: sceneID
        )
        #if DEBUG
        print("[WordCloudView] Handoff to Chronology — range: \(startISO)…\(endISO)")
        #endif
        #if os(macOS)
        // Chronology inherits this word cloud's provenance (transitive bind).
        appState.bindTool(.chronology, to: appState.provenance(of: .wordCloud))
        openWindow.fronting(id: "frus.chronology")
        #else
        // Chronology is presented from the Browse tab on iOS; surface it and dismiss
        // this sheet so `BrowserView` can present it on the `pendingChronology` change.
        appState.openTab(.browse, from: sceneID)
        dismiss()
        #endif
    }

    // MARK: - Recompute Keys

    /// A token summarising the Settings-driven criteria; changing any of them (or a
    /// custom stop list, via the revision) recomputes the cloud.
    private var settingsToken: String {
        "m\(filterMarkings ? 1 : 0)f\(foldPlurals ? 1 : 0)l\(minLength)c\(minCount)r\(settingsRevision)"
    }

    /// Drives a reload when the scope, stopword policy, lens, or criteria change.
    /// Everything that changes a keyness verdict.
    ///
    /// `exclude` and `settings` are members because the availability check reads the LIVE tokenisation
    /// — not the defaults — and both are reachable without leaving this view.
    private struct KeynessKey: Equatable {
        let measure: String
        let lens: WordCloudLens
        let exclude: Bool
        let settings: String
        let termCount: Int
        let tokenTotal: Int
        let hidden: Set<String>
        /// Whether the bundled reference has finished decoding, so a verdict taken before it landed
        /// is re-evaluated rather than cached as a permanent failure.
        let referenceReady: Bool
    }

    /// Drives a reload when the scope, stopword policy, lens, or criteria change.
    private struct TaskKey: Equatable {
        let signature: String
        let exclude: Bool
        let lens: WordCloudLens
        let settings: String
    }

    /// Drives a spiral relayout when the canvas size, scope, policy, or lens changes.
    private struct LayoutKey: Equatable {
        /// The active measure, so switching frequency↔keyness re-lays out.
        let measure: String
        /// How many terms the keyness ranking kept, which the raw term count does not track.
        let rankedCount: Int
        let width: CGFloat
        let height: CGFloat
        let signature: String
        let exclude: Bool
        let lens: WordCloudLens
        let termCount: Int
        let fontDesign: WordCloudFontDesign
        let density: WordCloudDensity
        /// Whether the A8 +/− marks are in the layout input (re-lays out when the
        /// Differentiate Without Color setting or the lens flips).
        let sentimentMarks: Bool
        /// The words hidden just for this open cloud (#233). Included so hiding/un-hiding a
        /// word re-runs the spiral packer — the placed set backfills from the fetched
        /// surplus rather than relying on a term-count change.
        let hidden: Set<String>
    }
}

#if os(macOS)
/// Content for the macOS `frus.wordcloud` window.
///
/// Seeds its scope from `appState.pendingWordCloud` (set by whichever surface opened
/// the window) and tracks subsequent hand-offs, but also hosts a `WordCloudScopeBar`
/// so the user can retarget the cloud to any available scope — corpus, subseries,
/// volume, collection, tag, saved search, or custom volume scope — directly from
/// this app-level window.
///
/// `pendingWordCloud` is cleared here after each consumption (mirroring how
/// `MacSearchWindowView` consumes `pendingSearch`). Leaving it set would make
/// `.onChange` — which only fires on an `Equatable` change — silently drop the
/// next hand-off whenever it targets the *same* scope (e.g. reopening the same
/// volume's word cloud after closing this window).
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   2.0 — Word Cloud: in-window scope picker
///   2.1 — Word Cloud fixes: consume-and-clear `pendingWordCloud` so repeating a
///          hand-off for an identical scope reopens the window
struct WordCloudWindowContent: View {
    @Environment(AppState.self) private var appState

    /// The scope currently displayed; `nil` until one is chosen or handed off.
    @State private var scope: WordCloudScope?

    var body: some View {
        VStack(spacing: 0) {
            WordCloudScopeBar(scope: $scope)
            Divider()
            if let scope {
                WordCloudView(scope: scope)
                    .id(scope.signature)
            } else {
                ContentUnavailableView(
                    String(localized: "wordcloud.window.empty.title", defaultValue: "No Word Cloud"),
                    systemImage: WordCloudGlyph.symbol,
                    description: Text(String(
                        localized: "wordcloud.window.empty.detail",
                        defaultValue: "Pick a scope above, or open a word cloud from a document, volume, collection, tag, saved search, volume scope, or the corpus."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Consume any hand-off that arrived while this window didn't exist —
            // the one that opened it, or one made while it was closed. A pending
            // scope is always fresher than any state this window carries, because
            // every consumption clears it.
            // #338 step 2: consume the hand-off addressed to this singleton window.
            if let handoff = appState.pendingWordCloud, handoff.target == .macWordCloud {
                scope = handoff.payload
                appState.pendingWordCloud = nil
            }
        }
        .onChange(of: appState.pendingWordCloud) { _, handoff in
            // A hand-off arriving while the window is already open retargets it.
            guard let handoff, handoff.target == .macWordCloud else { return }
            scope = handoff.payload
            appState.pendingWordCloud = nil
        }
    }
}

/// A compact scope selector for the macOS word-cloud window.
///
/// Presents a single menu listing every scope the cloud can target: the whole
/// corpus, a subseries, a specific volume (grouped under its subseries), a user
/// collection / tag / saved search, or a custom volume scope. The button shows a
/// readable label for the current scope so the window always says what it's
/// analysing.
///
/// Version history:
///   1.0 — Word Cloud: in-window scope picker
///   1.1 — #258 Phase 5: "My Volume Scopes" section — the FTS-grain Menu idiom
///          (enabled with the honest indexed count, disabled when no member is
///          indexed; a zero-indexed scope could only ever render an empty cloud)
private struct WordCloudScopeBar: View {
    /// The scope binding shared with `WordCloudWindowContent`.
    @Binding var scope: WordCloudScope?

    @Environment(AppState.self) private var appState
    @Query(sort: \Collection.name) private var collections: [Collection]
    @Query(sort: \UserTag.name) private var tags: [UserTag]
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]
    @Query(sort: \CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]

    /// The known volume manifest entries (diffed if available, else bundled).
    private var entries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    /// The distinct subseries names, in manifest order.
    private var subseriesList: [String] {
        var seen = Set<String>()
        var all: [String] = []
        for entry in entries where seen.insert(entry.subseries).inserted { all.append(entry.subseries) }
        return all
    }

    /// The volumes belonging to a subseries.
    private func volumes(in subseries: String) -> [VolumeManifestEntry] {
        entries.filter { $0.subseries == subseries }
    }

    /// The bundled volume-subject profiles, `volumeId → [ResolvedSubject]`, or empty when
    /// the index isn't present in the bundle (the "By Detected Topic" menu then hides).
    private var resolvedByVolume: [String: [VolumeSubjectProfiles.ResolvedSubject]] {
        VolumeSubjectProfilesStore.shared?.resolvedByVolume ?? [:]
    }

    /// The "By Detected Topic" scope menu (#308 F6): a two-level drill-down over the bundled
    /// detected-topic taxonomy. The whole-category item scopes the coarse level; sub-categories
    /// discriminate (`subCategoryCatalog` hides the folded "General" bucket, still reachable via
    /// the whole-category item). Framed "experimental" — these are automatically detected topics,
    /// not editorial subject headings, and may include mistags.
    @ViewBuilder
    private func subjectScopeMenu(
        _ resolved: [String: [VolumeSubjectProfiles.ResolvedSubject]]
    ) -> some View {
        Menu(String(localized: "wordcloud.scope.bySubject", defaultValue: "By Detected Topic")) {
          Section(String(localized: "wordcloud.scope.subject.experimental",
                         defaultValue: "Detected topics — experimental")) {
            ForEach(ScopeFacets.categoryCatalog(resolvedByVolume: resolved)) { category in
                Menu(category.label) {
                    Button(String(format: String(
                        localized: "wordcloud.scope.subject.wholeCategory %@",
                        defaultValue: "All of %@"), category.label)) {
                        scope = .subjectCategory(category: category.label, subcategory: nil)
                    }
                    ForEach(ScopeFacets.subCategoryCatalog(forCategory: category.label,
                                                          resolvedByVolume: resolved)) { sub in
                        Button(sub.subcategory) {
                            scope = .subjectCategory(category: sub.category,
                                                     subcategory: sub.subcategory)
                        }
                    }
                }
            }
          }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(String(localized: "wordcloud.scopeBar.label", defaultValue: "Scope"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                Button(String(localized: "wordcloud.scope.corpus", defaultValue: "Entire Corpus")) {
                    scope = .corpus
                }
                Menu(String(localized: "wordcloud.scope.subseries", defaultValue: "Subseries")) {
                    ForEach(subseriesList, id: \.self) { sub in
                        Button(sub) { scope = .subseries(subseriesId: sub) }
                    }
                }
                Menu(String(localized: "wordcloud.scope.volume", defaultValue: "Volume")) {
                    ForEach(subseriesList, id: \.self) { sub in
                        Menu(sub) {
                            ForEach(volumes(in: sub)) { vol in
                                Button(vol.title.isEmpty ? vol.volumeId : vol.title) {
                                    scope = .volume(volumeId: vol.volumeId)
                                }
                            }
                        }
                    }
                }
                if !collections.isEmpty {
                    Menu(String(localized: "wordcloud.scope.collection", defaultValue: "Collection")) {
                        ForEach(collections) { collection in
                            Button(collection.name.isEmpty
                                   ? String(localized: "wordcloud.scope.untitled", defaultValue: "Untitled")
                                   : collection.name) {
                                scope = .collection(id: collection.id)
                            }
                        }
                    }
                }
                if !tags.isEmpty {
                    Menu(String(localized: "wordcloud.scope.tag", defaultValue: "Tag")) {
                        ForEach(tags) { tag in
                            Button(tag.name) { scope = .userTag(id: tag.id) }
                        }
                    }
                }
                if !savedSearches.isEmpty {
                    Menu(String(localized: "wordcloud.scope.savedSearch", defaultValue: "Saved Search")) {
                        ForEach(savedSearches) { search in
                            Button(search.name.isEmpty
                                   ? String(localized: "wordcloud.scope.untitled", defaultValue: "Untitled")
                                   : search.name) {
                                scope = .savedSearch(id: search.id)
                            }
                        }
                    }
                }
                if !customScopes.isEmpty {
                    Menu(String(localized: "analytics.scope.customScopes",
                                defaultValue: "My Volume Scopes")) {
                        ForEach(customScopes) { record in
                            customScopeItem(record)
                        }
                    }
                }
                let resolved = resolvedByVolume
                if !resolved.isEmpty {
                    subjectScopeMenu(resolved)
                }
                Divider()
                Button(String(localized: "wordcloud.scope.dateRange", defaultValue: "Date Range")) {
                    scope = defaultDateRangeScope()
                }
            } label: {
                Text(currentLabel)
                    .font(.subheadline.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            if case let .dateRange(startISO, endISO) = scope {
                DatePicker("", selection: Binding(
                    get: { WordCloudScope.day(fromISO: startISO) ?? .distantPast },
                    set: { scope = .dateRange(startISO: WordCloudScope.isoDay(from: $0), endISO: endISO) }
                ), in: ...(WordCloudScope.day(fromISO: endISO) ?? .now), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityLabel(String(localized: "wordcloud.scope.dateRange.from", defaultValue: "Range start"))
                Text(verbatim: "–").foregroundStyle(.tertiary)
                DatePicker("", selection: Binding(
                    get: { WordCloudScope.day(fromISO: endISO) ?? .now },
                    set: { scope = .dateRange(startISO: startISO, endISO: WordCloudScope.isoDay(from: $0)) }
                ), in: (WordCloudScope.day(fromISO: startISO) ?? .distantPast)..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityLabel(String(localized: "wordcloud.scope.dateRange.to", defaultValue: "Range end"))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// One custom-scope menu item (#258 Phase 5): the FTS-grain Menu idiom shared
    /// with `AnalyticsScopeBar` — enabled with its honest indexed count, disabled
    /// when no member volume is indexed (the cloud reads indexed text, so a
    /// zero-indexed scope could only ever render an empty cloud).
    @ViewBuilder
    private func customScopeItem(_ record: CustomVolumeScope) -> some View {
        switch CustomScopeResolver.indexedResolution(memberVolumeIds: record.volumeIds,
                                                     indexed: appState.indexedVolumeIds) {
        case .resolved(let ids):
            Button {
                scope = .customScope(id: record.id)
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.customScope %@ %lld %lld",
                    defaultValue: "%@ (%lld of %lld indexed)"),
                    record.name, Int64(ids.count), Int64(record.volumeIds.count)))
            }
        case .noIndexedMembers, .scopeUnavailable:
            Button {
                // Unreachable: disabled below. Present for the shared Button shape.
            } label: {
                Text(String(format: String(
                    localized: "analytics.scope.customScope.none %@",
                    defaultValue: "%@ — none indexed yet"), record.name))
            }
            .disabled(true)
        }
    }

    /// A sensible default date-range scope when the user first picks "Date Range":
    /// the corpus's most recent year, mirroring the Chronology browser's default.
    private func defaultDateRangeScope() -> WordCloudScope {
        let corpus = appState.manifestStore.corpusDateRange
        let cal = Calendar(identifier: .gregorian)
        let end = corpus.upperBound
        let start = cal.date(byAdding: .year, value: -1, to: end) ?? corpus.lowerBound
        return .dateRange(startISO: WordCloudScope.isoDay(from: start),
                          endISO: WordCloudScope.isoDay(from: end))
    }

    /// A readable label for the current scope, resolved against the manifest and
    /// the user's SwiftData records.
    private var currentLabel: String {
        guard let scope else {
            return String(localized: "wordcloud.scope.choose", defaultValue: "Choose scope…")
        }
        switch scope {
        case .corpus:
            return String(localized: "wordcloud.scope.corpus", defaultValue: "Entire Corpus")
        case let .subseries(subseriesId):
            return subseriesId
        case let .volume(volumeId):
            return entries.first { $0.volumeId == volumeId }?.title ?? volumeId
        case let .document(_, documentId):
            return String(format: String(localized: "wordcloud.scope.document %@",
                                          defaultValue: "Document %@"), documentId)
        case let .collection(id):
            return collections.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.collection", defaultValue: "Collection")
        case let .userTag(id):
            return tags.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.tag", defaultValue: "Tag")
        case let .savedSearch(id):
            return savedSearches.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.savedSearch", defaultValue: "Saved Search")
        case let .customScope(id):
            return customScopes.first { $0.id == id }?.name
                ?? String(localized: "wordcloud.scope.customScope", defaultValue: "Volume Scope")
        case let .subjectCategory(category, subcategory):
            return subcategory.map { "\(category) · \($0)" } ?? category
        case let .dateRange(startISO, endISO):
            return WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO)
        }
    }
}
#endif
