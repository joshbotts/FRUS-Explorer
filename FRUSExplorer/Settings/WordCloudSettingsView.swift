// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// Settings pane for word-cloud filtering criteria and custom stop lists.
///
/// Exposes the tunable criteria backing `WordCloudTuning` (minimum length/count,
/// plural folding, markings and boilerplate filters) plus a user-managed stop list,
/// scoped either to every cloud or to a single lens. Edits write through
/// `WordCloudSettings`, which bumps a revision so any open cloud recomputes.
///
/// ## The bench (S-5b)
/// Every control here is a threshold or a filter, and each used to state only what it *is* —
/// "Minimum occurrences: 3" — never what it costs. The pane now opens with a live sample of the
/// terms the current settings keep, and the Thresholds section carries a "Keeps N of M terms"
/// line. Both come from ``WordCloudBench``, which measures against the user's most recent cached
/// `.allTerms` cloud (or a canned list when there is no suitable one) and never touches the search
/// index — opening Settings must not start indexing work.
///
/// Version history:
///   1.0 — Word Cloud: tunable criteria + stop-list management
///   1.1 — S-2a: background precompute moved here from Storage (it is a word-cloud behaviour,
///          not a storage one), giving macOS a control it never had
///   1.2 — S-5b: the bench — live sample row, "Keeps N of M terms" consequence line — and the
///          two stop-list sections merged into one editor with a scope picker. Also observes
///          `WordCloudSettings.Keys.revision`, so a stop-list change arriving from another
///          device refreshes the sample; re-reads the sample when the Settings window becomes
///          active again (it is a sibling window, not a modal); and drops `maxHeight: .infinity`,
///          which Session 67 removed elsewhere because it stops the split-view detail column
///          bounding the Form.
struct WordCloudSettingsView: View {

    @AppStorage(WordCloudSettings.Keys.excludeBoilerplate) private var excludeBoilerplate = true
    @AppStorage(WordCloudSettings.Keys.filterMarkings) private var filterMarkings = true
    @AppStorage(WordCloudSettings.Keys.foldPlurals) private var foldPlurals = true
    @AppStorage(WordCloudSettings.Keys.minLength) private var minLength = WordCloudSettings.defaultMinLength
    @AppStorage(WordCloudSettings.Keys.minCount) private var minCount = WordCloudSettings.defaultMinCount
    @AppStorage(WordCloudSettings.Keys.fontDesign) private var fontDesignRaw = WordCloudFontDesign.rounded.rawValue
    @AppStorage(WordCloudSettings.Keys.density) private var densityRaw = WordCloudDensity.balanced.rawValue
    /// Bumped by every stop-list mutation, including ones arriving over iCloud. Observed so the
    /// sample re-filters when a hidden word is added on another device.
    @AppStorage(WordCloudSettings.Keys.revision) private var settingsRevision = 0

    #if os(macOS)
    /// Whether the Settings window is active. Settings is a sibling window on macOS, so a user
    /// can open a cloud in the main window and come straight back — re-read the sample then,
    /// rather than keep telling them to go and do what they have just done.
    @Environment(\.controlActiveState) private var controlActiveState
    #endif

    /// Which stop list the editor is showing — every cloud, or one lens.
    @State private var stopListScope: StopListScope = .allLenses
    @State private var words: [String] = []
    @State private var newWord = ""

    /// The sample terms, read from disk on appear and whenever this window becomes active again.
    @State private var sample: [TermCount] = []
    /// Whether `sample` is the user's own cached cloud rather than the canned list.
    @State private var sampleIsFromUserCorpus = false

    /// The sample re-filtered through the current criteria. Recomputed in `body`, which is cheap
    /// — a `filter` over at most the cached term limit (220) — and keeps the number exact as the
    /// user drags a stepper, which a `.task`-driven `@State` could not.
    private var bench: WordCloudBench {
        WordCloudBench.evaluate(
            sample: sample,
            tuning: WordCloudTuning(minimumLength: max(2, minLength),
                                    minimumCount: max(1, minCount),
                                    foldPlurals: foldPlurals,
                                    filterMarkings: filterMarkings),
            lens: stopListScope.lens ?? .allTerms,
            includeDiplomatic: excludeBoilerplate,
            extraStopwords: WordCloudSettings.extraStopwords(for: stopListScope.lens ?? .allTerms),
            isFromUserCorpus: sampleIsFromUserCorpus
        )
    }

    var body: some View {
        Form {
            sampleSection
            filteringSection
            thresholdsSection
            appearanceSection
            stopListSection
        }
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.wordcloud.title", defaultValue: "Word Cloud"))
        .task { loadSample() }
        #if os(macOS)
        .onChange(of: controlActiveState) { _, state in
            if state != .inactive { loadSample() }
        }
        #endif
        .onChange(of: stopListScope) { _, scope in
            words = scope.words
            newWord = ""
        }
        .onChange(of: settingsRevision) { _, _ in
            words = stopListScope.words
        }
    }

    // MARK: - Live sample

    /// What the current settings actually produce, drawn from real terms.
    ///
    /// A row of terms sized by rank rather than a laid-out cloud: the pane is a form column a
    /// few hundred points wide, and a miniature of the packed layout at that size would be
    /// illegible and would misrepresent the real thing.
    @ViewBuilder
    private var sampleSection: some View {
        Section {
            if bench.kept.isEmpty {
                Text(String(localized: "settings.wordcloud.sample.none",
                            defaultValue: "These settings keep nothing from the sample. Lower a threshold or turn a filter off."))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                SampleTermsRow(terms: Array(bench.kept.prefix(12)),
                               design: WordCloudFontDesign(rawValue: fontDesignRaw) ?? .rounded)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(sampleAccessibilityLabel)
            }
        } header: {
            Text(String(localized: "settings.wordcloud.sample.header", defaultValue: "Sample"))
        } footer: {
            Text(bench.provenance)
        }
    }

    private var sampleAccessibilityLabel: String {
        String(format: String(localized: "settings.wordcloud.sample.a11y %@",
                              defaultValue: "Sample of kept terms: %@"),
               bench.kept.prefix(12).map(\.term).joined(separator: ", "))
    }


    // MARK: - Filtering

    private var filteringSection: some View {
        Section {
            Toggle(String(localized: "settings.wordcloud.boilerplate",
                          defaultValue: "Hide common diplomatic words"),
                   isOn: $excludeBoilerplate)
            Toggle(String(localized: "settings.wordcloud.markings",
                          defaultValue: "Filter classification markings"),
                   isOn: $filterMarkings)
            Toggle(String(localized: "settings.wordcloud.foldPlurals",
                          defaultValue: "Merge plural and singular forms"),
                   isOn: $foldPlurals)
        } header: {
            Text(String(localized: "settings.wordcloud.filtering.header", defaultValue: "Filtering"))
        } footer: {
            Text(String(localized: "settings.wordcloud.markings.footer",
                        defaultValue: "Classification markings include terms like \"Top Secret\" and \"Confidential\", precedence words like \"Priority\" and \"Immediate\", and month names. These words describe the form of a document, not its content. Left in, they crowd the cloud, especially the named-entity lenses."))
        }
    }

    // MARK: - Thresholds

    private var thresholdsSection: some View {
        Section {
            Stepper(value: $minLength, in: 2...8) {
                Text(String(format: String(localized: "settings.wordcloud.minLength %lld",
                                            defaultValue: "Minimum word length: %lld"),
                            Int64(minLength)))
            }
            Stepper(value: $minCount, in: 1...20) {
                Text(String(format: String(localized: "settings.wordcloud.minCount %lld",
                                            defaultValue: "Minimum occurrences: %lld"),
                            Int64(minCount)))
            }
            // The consequence line, next to the controls that cause it.
            LabeledContent {
                Text(bench.summary)
                    .foregroundStyle(bench.kept.isEmpty ? Color.red : Color.secondary)
                    .monospacedDigit()
            } label: {
                Text(String(localized: "settings.wordcloud.bench.label", defaultValue: "Effect"))
            }
        } header: {
            Text(String(localized: "settings.wordcloud.thresholds.header", defaultValue: "Thresholds"))
        } footer: {
            Text(String(localized: "settings.wordcloud.thresholds.footer",
                        defaultValue: "Drops terms shorter than the minimum length, and terms appearing fewer than the minimum number of times. Raising either gives a sparser cloud of stronger terms. Occurrences are counted across the whole scope before the top terms are picked. So raising the minimum count may not change the sample above. It thins the long tail you never see."))
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker(selection: $fontDesignRaw) {
                ForEach(WordCloudFontDesign.allCases) { design in
                    Text(design.label).tag(design.rawValue)
                }
            } label: {
                Text(String(localized: "settings.wordcloud.font", defaultValue: "Font"))
            }
            Picker(selection: $densityRaw) {
                ForEach(WordCloudDensity.allCases) { density in
                    Text(density.label).tag(density.rawValue)
                }
            } label: {
                Text(String(localized: "settings.wordcloud.density", defaultValue: "Density"))
            }
        } header: {
            Text(String(localized: "settings.wordcloud.appearance.header", defaultValue: "Appearance"))
        } footer: {
            Text(String(localized: "settings.wordcloud.appearance.footer",
                        defaultValue: "Choose the typeface the cloud is drawn in and how tightly its words pack together. Compact fits more terms; airy spaces them out for legibility. These settings apply on this device only."))
        }
    }

    // MARK: - Hidden words

    /// One stop-list editor with a scope control (S-5b).
    ///
    /// There used to be two near-identical sections — "Hidden Words (All Lenses)" and "Hidden
    /// Words (Per Lens)" — each with its own text field, its own add button, and its own list,
    /// which made the pane read as though the two lists did different *kinds* of thing. They do
    /// the same thing at different scope, so scope is now a control rather than a section
    /// boundary, and there is one editor to learn.
    @ViewBuilder
    private var stopListSection: some View {
        Section {
            Picker(String(localized: "settings.wordcloud.stoplist.scope", defaultValue: "Applies to"),
                   selection: $stopListScope) {
                Text(String(localized: "settings.wordcloud.stoplist.allLenses",
                            defaultValue: "Every cloud")).tag(StopListScope.allLenses)
                ForEach(WordCloudLens.allCases) { lens in
                    Text(lens.label).tag(StopListScope.lens(lens))
                }
            }

            HStack {
                TextField(String(localized: "settings.wordcloud.addWord.prompt",
                                 defaultValue: "Add a word…"),
                          text: $newWord)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "settings.wordcloud.add.a11y",
                                           defaultValue: "Add hidden word"))
            }

            if words.isEmpty {
                Text(String(localized: "settings.wordcloud.empty", defaultValue: "No custom words yet."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(words, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button(role: .destructive) {
                            remove(word)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(String(
                            format: String(localized: "settings.wordcloud.remove %@",
                                           defaultValue: "Remove %@"), word))
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.wordcloud.stoplist.header", defaultValue: "Hidden Words"))
        } footer: {
            Text(stopListScope.footer)
        }
    }

    // MARK: - Mutations

    /// Re-reads the sample from disk and the hidden-word list for the current scope.
    private func loadSample() {
        let loaded = WordCloudBench.loadSample()
        sample = loaded.terms
        sampleIsFromUserCorpus = loaded.isFromUserCorpus
        words = stopListScope.words
    }

    private func add() {
        switch stopListScope {
        case .allLenses:
            WordCloudSettings.addGlobalStopword(newWord)
        case .lens(let lens):
            WordCloudSettings.addLensStopword(newWord, lens: lens)
        }
        newWord = ""
        words = stopListScope.words
    }

    private func remove(_ word: String) {
        switch stopListScope {
        case .allLenses:
            WordCloudSettings.removeGlobalStopword(word)
        case .lens(let lens):
            WordCloudSettings.removeLensStopword(word, lens: lens)
        }
        words = stopListScope.words
    }

    // MARK: - StopListScope

    /// Which stop list the single editor is editing.
    enum StopListScope: Hashable {
        /// The global list, applied to every cloud.
        case allLenses
        /// One lens's own list.
        case lens(WordCloudLens)

        /// The lens this scope names, or `nil` for the global list.
        var lens: WordCloudLens? {
            if case .lens(let lens) = self { return lens }
            return nil
        }

        /// The words currently stored at this scope.
        var words: [String] {
            switch self {
            case .allLenses:      return WordCloudSettings.globalStopwords
            case .lens(let lens): return WordCloudSettings.lensStopwords(lens)
            }
        }

        /// What hiding a word at this scope costs.
        var footer: String {
            switch self {
            case .allLenses:
                return String(localized: "settings.wordcloud.global.footer",
                              defaultValue: "Words listed here are removed from every word cloud, on top of the built-in stop lists.")
            case .lens:
                return String(localized: "settings.wordcloud.lens.footer",
                              defaultValue: "Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recognizer keeps mistaking) without affecting other lenses.")
            }
        }
    }
}

// MARK: - SampleTermsRow

/// The kept sample terms, sized by rank — the settings pane's miniature of a cloud.
///
/// Not a real `WordCloudLayout`: the pane is a form column a few hundred points wide, and a
/// packed layout at that size would be illegible and would misrepresent what the cloud looks
/// like at full size. A flowing row of rank-sized words carries the one thing the pane needs to
/// show — which terms survive, and roughly how they rank — and reflows at any width.
///
/// Version history:
///   1.0 — S-5b: initial implementation
private struct SampleTermsRow: View {

    /// The surviving terms, highest count first.
    let terms: [TermCount]
    /// The typeface the user has chosen for their clouds, so the sample looks like theirs.
    let design: WordCloudFontDesign

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(terms.enumerated()), id: \.element.id) { index, term in
                Text(term.term)
                    .font(.system(size: fontSize(forRank: index),
                                  weight: index < 2 ? .semibold : .regular,
                                  design: design.swiftUIDesign))
                    .foregroundStyle(index < 3 ? Color.accentColor : Color.primary.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    /// Ranks fall from 20pt to 11pt across the shown terms — enough spread to read as a cloud,
    /// gentle enough that the last term is still legible.
    private func fontSize(forRank rank: Int) -> CGFloat {
        guard terms.count > 1 else { return 20 }
        let t = CGFloat(rank) / CGFloat(terms.count - 1)
        return 20 - (9 * t)
    }
}
