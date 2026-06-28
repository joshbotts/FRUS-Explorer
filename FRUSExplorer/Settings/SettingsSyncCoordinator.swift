// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

/// Mirrors a curated set of `UserDefaults`-backed preferences to and from a
/// CloudKit-synced ``SyncedPreferences`` record, but only while a **device-local**
/// master toggle is on.
///
/// ## Why mirror rather than read the model directly
/// Every synced setting is consumed app-wide through `@AppStorage` / `UserDefaults`
/// (the word-cloud loader, citation formatter, document-mode logic, …). Keeping
/// `UserDefaults` as the working store on every device means none of those consumers
/// change: this coordinator simply copies values between `UserDefaults` and the model
/// when sync is enabled.
///
/// ## Directions
/// - **Push** (`UserDefaults → model`): a debounced observer of `UserDefaults`
///   changes writes local edits up so CloudKit propagates them.
/// - **Pull** (`model → UserDefaults`): performed on launch, when CloudKit imports a
///   remote change, and on foreground. Settings rarely change, so this cadence is
///   ample and avoids brittle real-time store observation.
///
/// Both directions are diff-guarded (they only write on an actual difference), which
/// makes them idempotent and prevents the observer feedback loop.
///
/// ## Optionality
/// The toggle is stored locally and never synced, so leaving it off on a device keeps
/// that device's settings independent. Turning it on **adopts** the existing cloud
/// record if one exists, otherwise **seeds** a new record from this device.
///
/// Version history:
///   1.0 — Optional iCloud settings sync
@MainActor
@Observable
final class SettingsSyncCoordinator {

    /// Device-local toggle key (deliberately not part of `SyncedPreferences`).
    static let enabledKey = "frus.settings.syncEnabled"

    /// The research-logging `UserDefaults` key (declared inline elsewhere).
    private static let researchLoggingKey = "researchSessionLoggingEnabled"

    private let context: ModelContext
    private var observer: NSObjectProtocol?
    private var pushTask: Task<Void, Never>?
    /// Set while writing `UserDefaults` from the model, so the change observer ignores
    /// our own writes (belt-and-braces alongside the diff guards).
    private var isApplying = false

    /// Whether settings sync is currently enabled on this device.
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    /// Creates a coordinator bound to a model context (the container's main context).
    ///
    /// The coordinator is an app-lifetime singleton (held by `AppState`), so it has no
    /// `deinit` teardown; the change observer captures `self` weakly, so it simply
    /// stops doing work if the coordinator is ever released.
    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Lifecycle

    /// Installs the change observer and performs an initial pull if sync is on.
    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            // Already on the main queue; hop onto the main actor to touch state.
            MainActor.assumeIsolated { self?.schedulePush() }
        }
        if isEnabled { pull() }
    }

    /// Pulls the latest synced values into `UserDefaults` if sync is enabled. Safe to
    /// call from CloudKit-import and foreground hooks.
    func syncNowIfEnabled() {
        guard isEnabled else { return }
        pull()
    }

    /// Responds to the master toggle changing in Settings.
    ///
    /// - Parameter enabled: The new toggle state (already written to `UserDefaults`).
    func handleEnabledChange(_ enabled: Bool) {
        if enabled {
            // Adopt the cloud record if present, otherwise seed one from this device.
            if resolveCanonical(create: false) != nil {
                pull()
            } else {
                push()
            }
        }
        // Disabling needs no action: the observer and pull paths both gate on `isEnabled`.
    }

    // MARK: - Push (UserDefaults → model)

    private func schedulePush() {
        guard isEnabled, !isApplying else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.push()
        }
    }

    private func push() {
        guard isEnabled else { return }
        guard let record = resolveCanonical(create: true) else { return }
        if applyDefaultsToModel(record) {
            record.updatedAt = .now
            try? context.save()
        }
    }

    // MARK: - Pull (model → UserDefaults)

    private func pull() {
        guard let record = resolveCanonical(create: false) else { return }
        applyModelToDefaults(record)
    }

    // MARK: - Singleton resolution

    /// Returns the canonical record (earliest `createdAt`), deleting any duplicate
    /// records CloudKit may have produced. Optionally creates one if none exists.
    private func resolveCanonical(create: Bool) -> SyncedPreferences? {
        let all = (try? context.fetch(
            FetchDescriptor<SyncedPreferences>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        if let canonical = all.first {
            for duplicate in all.dropFirst() { context.delete(duplicate) }
            if all.count > 1 { try? context.save() }
            return canonical
        }
        guard create else { return nil }
        let fresh = SyncedPreferences()
        context.insert(fresh)
        return fresh
    }

    // MARK: - Field mapping

    /// Copies the model's values into `UserDefaults`, only writing where they differ.
    /// Returns nothing; bumps the word-cloud revision when a stop list changed so open
    /// clouds recompute.
    private func applyModelToDefaults(_ p: SyncedPreferences) {
        isApplying = true
        defer { isApplying = false }
        let store = UserDefaults.standard

        setInt(p.wcMinLength, WordCloudSettings.Keys.minLength, store)
        setInt(p.wcMinCount, WordCloudSettings.Keys.minCount, store)
        setBool(p.wcFoldPlurals, WordCloudSettings.Keys.foldPlurals, store)
        setBool(p.wcFilterMarkings, WordCloudSettings.Keys.filterMarkings, store)
        setBool(p.wcExcludeBoilerplate, WordCloudSettings.Keys.excludeBoilerplate, store)
        setBool(p.researchLoggingEnabled, Self.researchLoggingKey, store)
        setNonEmptyString(p.citationStyleRaw, SettingsKeys.citationStyle, store)
        setNonEmptyString(p.defaultDocumentModeRaw, SettingsKeys.defaultDocumentMode, store)

        var listChanged = false

        // Global stop list: model JSON → `[String]`.
        let modelGlobal = decodeStringArray(p.wcGlobalStopwordsJSON)
        let currentGlobal = (store.array(forKey: WordCloudSettings.Keys.globalStopwords) as? [String]) ?? []
        if modelGlobal != currentGlobal {
            store.set(modelGlobal, forKey: WordCloudSettings.Keys.globalStopwords)
            listChanged = true
        }

        // Per-lens stop lists: model JSON string → backing `Data`.
        let modelLensData = Data(p.wcLensStopwordsJSON.utf8)
        let currentLensData = store.data(forKey: WordCloudSettings.Keys.lensStopwords) ?? Data()
        if !p.wcLensStopwordsJSON.isEmpty, modelLensData != currentLensData {
            store.set(modelLensData, forKey: WordCloudSettings.Keys.lensStopwords)
            listChanged = true
        }

        if listChanged {
            store.set(store.integer(forKey: WordCloudSettings.Keys.revision) &+ 1,
                      forKey: WordCloudSettings.Keys.revision)
        }
    }

    /// Copies `UserDefaults` values into the model, only writing where they differ.
    /// Returns `true` when anything changed.
    private func applyDefaultsToModel(_ p: SyncedPreferences) -> Bool {
        let store = UserDefaults.standard
        var changed = false

        func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SyncedPreferences, T>, _ value: T) {
            if p[keyPath: keyPath] != value { p[keyPath: keyPath] = value; changed = true }
        }

        update(\.wcMinLength, WordCloudSettings.minimumLength)
        update(\.wcMinCount, WordCloudSettings.minimumCount)
        update(\.wcFoldPlurals, WordCloudSettings.foldPlurals)
        update(\.wcFilterMarkings, WordCloudSettings.filterMarkings)
        update(\.wcExcludeBoilerplate, (store.object(forKey: WordCloudSettings.Keys.excludeBoilerplate) as? Bool) ?? true)
        update(\.researchLoggingEnabled, (store.object(forKey: Self.researchLoggingKey) as? Bool) ?? true)
        update(\.citationStyleRaw, store.string(forKey: SettingsKeys.citationStyle) ?? "")
        update(\.defaultDocumentModeRaw, store.string(forKey: SettingsKeys.defaultDocumentMode) ?? "")

        let globalJSON = encodeStringArray(WordCloudSettings.globalStopwords)
        update(\.wcGlobalStopwordsJSON, globalJSON)

        let lensJSON = store.data(forKey: WordCloudSettings.Keys.lensStopwords)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        update(\.wcLensStopwordsJSON, lensJSON)

        return changed
    }

    // MARK: - Primitive helpers

    private func setInt(_ value: Int, _ key: String, _ store: UserDefaults) {
        if (store.object(forKey: key) as? Int) != value { store.set(value, forKey: key) }
    }

    private func setBool(_ value: Bool, _ key: String, _ store: UserDefaults) {
        if (store.object(forKey: key) as? Bool) != value { store.set(value, forKey: key) }
    }

    /// Applies a string only when the model carries a real value, so an unset record
    /// never clobbers a device's local default.
    private func setNonEmptyString(_ value: String, _ key: String, _ store: UserDefaults) {
        guard !value.isEmpty else { return }
        if store.string(forKey: key) != value { store.set(value, forKey: key) }
    }

    private func decodeStringArray(_ json: String) -> [String] {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return array
    }

    private func encodeStringArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return json
    }
}
