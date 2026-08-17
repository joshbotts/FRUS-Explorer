// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A persisted queue of word-cloud scopes to precompute in the background.
///
/// Expensive scopes (the corpus, and large subseries) are enqueued by their
/// `WordCloudScope.signature` after the index changes, then drained by the iOS
/// `BGProcessingTask` handler — which computes each one and writes it to
/// `WordCloudDiskCache`, so the user later opens it instantly. The queue survives
/// relaunch (it lives in `UserDefaults`), since a background task may not fire
/// until well after the app is suspended.
///
/// Version history:
///   1.0 — Word Cloud feature: background precompute (sequencing step 1)
enum WordCloudPrecomputeQueue {

    /// UserDefaults key for the pending-signature list.
    private static let queueKey = "frus.wordcloud.precomputeQueue"
    /// UserDefaults key for the user's background-precompute preference.
    private static let enabledKey = WordCloudSettings.Keys.backgroundPrecompute

    /// Whether background precomputation is enabled. Defaults to `true`.
    static var isEnabled: Bool {
        migrateDefaultOnce()
        return UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    /// Turns the old default off once, for installs that adopted it by never touching the switch.
    ///
    /// **The feature could not deliver what it promised, and it was costing users their app.**
    /// Measured from an owner device on build 42 (`cpu_resource_fatal`, 2026-08-17): the corpus
    /// precompute ran NLTagger at **97% CPU for 50 seconds** and iOS terminated the process —
    /// 48s of CPU against an 80%-over-60s limit. Three things follow, and each alone would be
    /// enough:
    ///
    /// 1. **It cannot finish.** A resource kill is not a `CancellationError`; the process dies, so
    ///    `precompute` never returns, the signature is never dequeued, and the same scope runs
    ///    again on the next wake. A permanent loop that burns battery and never produces an entry.
    /// 2. **Even finishing would rarely help.** The disk key carries `fp=documentCacheCount`, and
    ///    the enqueue site is *the end of indexing a volume* — so the entry a run would write is
    ///    invalidated by the next volume indexed. During the full re-index build 42 forces, that
    ///    is every time.
    /// 3. **Nobody observed a benefit.** The owner had it on across every device and reported no
    ///    noticeable gain in corpus word-cloud performance, which is what prompted this check.
    ///
    /// Flipping the default alone would not have reached anyone already running it, and every
    /// install shipped with it on. So the stored value is cleared once — deliberately narrow: it
    /// only removes a `true`, so a user who chose `false` is untouched, and after the marker is
    /// set a later deliberate `true` is respected forever.
    private static func migrateDefaultOnce() {
        let marker = "frus.wordcloud.backgroundPrecompute.defaultOffMigrated"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: marker) else { return }
        defaults.set(true, forKey: marker)
        if defaults.object(forKey: enabledKey) as? Bool == true {
            defaults.removeObject(forKey: enabledKey)
        }
        // Drop whatever was queued under the old default. Those signatures can never run now —
        // the drain refuses them — so leaving them is dead state that outlives the feature, and a
        // later deliberate opt-in should start from a clean queue rather than inherit a backlog
        // enqueued by a version the user never chose. Found by a test that failed because the
        // queue survived a disable.
        defaults.removeObject(forKey: queueKey)
    }

    /// Sets the background-precompute preference.
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled { UserDefaults.standard.removeObject(forKey: queueKey) }
    }

    /// The signatures currently queued for precomputation, in insertion order.
    static func pending() -> [String] {
        UserDefaults.standard.stringArray(forKey: queueKey) ?? []
    }

    /// `true` when at least one scope is queued.
    static var hasPending: Bool { !pending().isEmpty }

    /// Enqueues a scope signature (no-op when disabled or already queued).
    static func enqueue(_ signature: String) {
        guard isEnabled else { return }
        var queue = pending()
        guard !queue.contains(signature) else { return }
        queue.append(signature)
        UserDefaults.standard.set(queue, forKey: queueKey)
    }

    /// Removes a scope signature once its precompute has completed (or failed).
    static func remove(_ signature: String) {
        var queue = pending()
        queue.removeAll { $0 == signature }
        UserDefaults.standard.set(queue, forKey: queueKey)
    }
}
