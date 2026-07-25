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
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
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
