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
/// plural folding, markings and boilerplate filters) plus two user-managed stop
/// lists: a global one applied to every cloud, and a per-lens one for words that
/// should only be suppressed under a specific lens. Edits write through
/// `WordCloudSettings`, which bumps a revision so any open cloud recomputes.
///
/// Version history:
///   1.0 — Word Cloud: tunable criteria + stop-list management
struct WordCloudSettingsView: View {

    @AppStorage(WordCloudSettings.Keys.excludeBoilerplate) private var excludeBoilerplate = true
    @AppStorage(WordCloudSettings.Keys.filterMarkings) private var filterMarkings = true
    @AppStorage(WordCloudSettings.Keys.foldPlurals) private var foldPlurals = true
    @AppStorage(WordCloudSettings.Keys.minLength) private var minLength = WordCloudSettings.defaultMinLength
    @AppStorage(WordCloudSettings.Keys.minCount) private var minCount = WordCloudSettings.defaultMinCount

    @State private var globalWords: [String] = []
    @State private var newGlobalWord = ""
    @State private var selectedLens: WordCloudLens = .people
    @State private var lensWords: [String] = []
    @State private var newLensWord = ""

    var body: some View {
        Form {
            filteringSection
            thresholdsSection
            globalStopwordsSection
            lensStopwordsSection
        }
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.wordcloud.title", defaultValue: "Word Cloud"))
        .onAppear {
            globalWords = WordCloudSettings.globalStopwords
            lensWords = WordCloudSettings.lensStopwords(selectedLens)
        }
        .onChange(of: selectedLens) { _, lens in
            lensWords = WordCloudSettings.lensStopwords(lens)
            newLensWord = ""
        }
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
                        defaultValue: "Classification markings include terms like “Top Secret”, “Confidential”, precedence words (“Priority”, “Immediate”), and month names — document chrome that otherwise leaks into clouds, especially named-entity lenses."))
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
        } header: {
            Text(String(localized: "settings.wordcloud.thresholds.header", defaultValue: "Thresholds"))
        } footer: {
            Text(String(localized: "settings.wordcloud.thresholds.footer",
                        defaultValue: "Drop terms shorter than the minimum length or appearing fewer than the minimum number of times. Raising either makes a sparser, higher-signal cloud."))
        }
    }

    // MARK: - Global stop list

    private var globalStopwordsSection: some View {
        Section {
            stopwordEditor(
                words: globalWords,
                newWord: $newGlobalWord,
                add: {
                    WordCloudSettings.addGlobalStopword(newGlobalWord)
                    newGlobalWord = ""
                    globalWords = WordCloudSettings.globalStopwords
                },
                remove: { word in
                    WordCloudSettings.removeGlobalStopword(word)
                    globalWords = WordCloudSettings.globalStopwords
                }
            )
        } header: {
            Text(String(localized: "settings.wordcloud.global.header",
                        defaultValue: "Hidden Words (All Lenses)"))
        } footer: {
            Text(String(localized: "settings.wordcloud.global.footer",
                        defaultValue: "Words listed here are removed from every word cloud, on top of the built-in stop lists."))
        }
    }

    // MARK: - Per-lens stop list

    private var lensStopwordsSection: some View {
        Section {
            Picker(String(localized: "settings.wordcloud.lens.picker", defaultValue: "Lens"),
                   selection: $selectedLens) {
                ForEach(WordCloudLens.allCases) { lens in
                    Text(lens.label).tag(lens)
                }
            }
            stopwordEditor(
                words: lensWords,
                newWord: $newLensWord,
                add: {
                    WordCloudSettings.addLensStopword(newLensWord, lens: selectedLens)
                    newLensWord = ""
                    lensWords = WordCloudSettings.lensStopwords(selectedLens)
                },
                remove: { word in
                    WordCloudSettings.removeLensStopword(word, lens: selectedLens)
                    lensWords = WordCloudSettings.lensStopwords(selectedLens)
                }
            )
        } header: {
            Text(String(localized: "settings.wordcloud.lens.header",
                        defaultValue: "Hidden Words (Per Lens)"))
        } footer: {
            Text(String(localized: "settings.wordcloud.lens.footer",
                        defaultValue: "Words hidden only when the selected lens is active — useful for trimming a recurring false positive (for example, a place the recogniser keeps mistaking) without affecting other lenses."))
        }
    }

    // MARK: - Reusable editor

    /// A small add-field plus a deletable list of the current words.
    @ViewBuilder
    private func stopwordEditor(
        words: [String],
        newWord: Binding<String>,
        add: @escaping () -> Void,
        remove: @escaping (String) -> Void
    ) -> some View {
        HStack {
            TextField(String(localized: "settings.wordcloud.addWord.prompt",
                             defaultValue: "Add a word…"),
                      text: newWord)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .onSubmit(add)
            Button(action: add) {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newWord.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.borderless)
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
    }
}
