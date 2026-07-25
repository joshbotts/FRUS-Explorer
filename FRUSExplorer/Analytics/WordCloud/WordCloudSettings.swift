// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// User-managed word-cloud preferences: tunable criteria plus custom stop lists
/// (global and per-lens), persisted in `UserDefaults`.
///
/// This is the single source of truth read by `WordCloudLoader` when it assembles a
/// request, and written by the Word Cloud Settings pane. Scalars share their keys
/// with the `@AppStorage` bindings in the Settings UI; the stop lists are stored as
/// JSON and mutated through the `add`/`remove` helpers, which bump ``revision`` so an
/// open cloud can detect the change and recompute.
///
/// Version history:
///   1.0 — Word Cloud: tunable criteria + stop-list management
enum WordCloudSettings {

    /// `UserDefaults` keys. The scalar keys are also used as `@AppStorage` keys in
    /// the Settings UI, so changing one here means changing it there too.
    enum Keys {
        /// Minimum surviving token length.
        static let minLength = "frus.wordcloud.minLength"
        /// Minimum total occurrence count.
        static let minCount = "frus.wordcloud.minCount"
        /// Plural-folding toggle.
        static let foldPlurals = "frus.wordcloud.foldPlurals"
        /// Classification-markings filter toggle.
        static let filterMarkings = "frus.wordcloud.filterMarkings"
        /// Diplomatic-boilerplate toggle (shared with the in-view menu toggle).
        static let excludeBoilerplate = "frus.wordcloud.excludeBoilerplate"
        /// Global custom stop list (JSON `[String]`).
        static let globalStopwords = "frus.wordcloud.customStopwords"
        /// Per-lens custom stop lists (JSON `[lensRawValue: [String]]`).
        static let lensStopwords = "frus.wordcloud.lensStopwords"
        /// Cloud typeface family (`WordCloudFontDesign` raw value). Device-local.
        static let fontDesign = "frus.wordcloud.fontDesign"
        /// Cloud packing density (`WordCloudDensity` raw value). Device-local.
        static let density = "frus.wordcloud.density"
        /// Monotonic revision bumped whenever a stop list changes.
        static let revision = "frus.wordcloud.settingsRevision"
        /// Background precompute of heavy clouds. Declared here (S-2a) because the literal was
        /// previously written out in both the Settings toggle and `WordCloudPrecomputeQueue`,
        /// where a one-sided edit would have silently decoupled the switch from the queue.
        static let backgroundPrecompute = "frus.wordcloud.backgroundPrecompute"
    }

    /// Default minimum token length.
    static let defaultMinLength = 3
    /// Default minimum occurrence count.
    static let defaultMinCount = 1

    private static var store: UserDefaults { .standard }

    // MARK: - Scalar criteria

    /// Minimum surviving token length (≥ 2).
    static var minimumLength: Int {
        max(2, (store.object(forKey: Keys.minLength) as? Int) ?? defaultMinLength)
    }

    /// Minimum total occurrence count (≥ 1).
    static var minimumCount: Int {
        max(1, (store.object(forKey: Keys.minCount) as? Int) ?? defaultMinCount)
    }

    /// Whether plural-folding is enabled.
    static var foldPlurals: Bool {
        (store.object(forKey: Keys.foldPlurals) as? Bool) ?? true
    }

    /// Whether classification markings are filtered.
    static var filterMarkings: Bool {
        (store.object(forKey: Keys.filterMarkings) as? Bool) ?? true
    }

    /// The cloud typeface family (device-local; defaults to ``WordCloudFontDesign/rounded``).
    static var fontDesign: WordCloudFontDesign {
        (store.string(forKey: Keys.fontDesign)).flatMap(WordCloudFontDesign.init(rawValue:)) ?? .rounded
    }

    /// The cloud packing density (device-local; defaults to ``WordCloudDensity/balanced``).
    static var density: WordCloudDensity {
        (store.string(forKey: Keys.density)).flatMap(WordCloudDensity.init(rawValue:)) ?? .balanced
    }

    /// The current tuning value assembled from the scalar criteria.
    static var tuning: WordCloudTuning {
        WordCloudTuning(
            minimumLength: minimumLength,
            minimumCount: minimumCount,
            foldPlurals: foldPlurals,
            filterMarkings: filterMarkings
        )
    }

    // MARK: - Revision

    /// A monotonic counter bumped whenever the stop lists change, so views keyed on
    /// it recompute. Scalar criteria are observed directly via `@AppStorage`.
    static var revision: Int { store.integer(forKey: Keys.revision) }

    private static func bumpRevision() {
        store.set(revision &+ 1, forKey: Keys.revision)
    }

    // MARK: - Global stop list

    /// The global custom stopwords (lowercased, sorted) applied to every lens.
    static var globalStopwords: [String] {
        (store.array(forKey: Keys.globalStopwords) as? [String]) ?? []
    }

    /// Adds a word to the global stop list.
    static func addGlobalStopword(_ word: String) {
        guard let normalized = normalize(word) else { return }
        var set = Set(globalStopwords)
        guard set.insert(normalized).inserted else { return }
        store.set(set.sorted(), forKey: Keys.globalStopwords)
        bumpRevision()
    }

    /// Removes a word from the global stop list.
    static func removeGlobalStopword(_ word: String) {
        var set = Set(globalStopwords)
        guard set.remove(word.lowercased()) != nil else { return }
        store.set(set.sorted(), forKey: Keys.globalStopwords)
        bumpRevision()
    }

    // MARK: - Per-lens stop lists

    /// The custom stopwords (lowercased, sorted) applied only to `lens`.
    static func lensStopwords(_ lens: WordCloudLens) -> [String] {
        lensStopwordMap()[lens.rawValue] ?? []
    }

    /// Adds a word to a lens's stop list.
    static func addLensStopword(_ word: String, lens: WordCloudLens) {
        guard let normalized = normalize(word) else { return }
        var map = lensStopwordMap()
        var set = Set(map[lens.rawValue] ?? [])
        guard set.insert(normalized).inserted else { return }
        map[lens.rawValue] = set.sorted()
        saveLensStopwordMap(map)
        bumpRevision()
    }

    /// Removes a word from a lens's stop list.
    static func removeLensStopword(_ word: String, lens: WordCloudLens) {
        var map = lensStopwordMap()
        var set = Set(map[lens.rawValue] ?? [])
        guard set.remove(word.lowercased()) != nil else { return }
        map[lens.rawValue] = set.isEmpty ? nil : set.sorted()
        saveLensStopwordMap(map)
        bumpRevision()
    }

    // MARK: - Assembled extras

    /// The combined extra stopwords for a lens: the global list unioned with that
    /// lens's own list. Loader unions this with the per-scope hidden words.
    static func extraStopwords(for lens: WordCloudLens) -> Set<String> {
        Set(globalStopwords).union(lensStopwords(lens))
    }

    // MARK: - Helpers

    private static func lensStopwordMap() -> [String: [String]] {
        guard let data = store.data(forKey: Keys.lensStopwords),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return map
    }

    private static func saveLensStopwordMap(_ map: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        store.set(data, forKey: Keys.lensStopwords)
    }

    /// Lowercases, trims, and rejects empty input.
    private static func normalize(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
