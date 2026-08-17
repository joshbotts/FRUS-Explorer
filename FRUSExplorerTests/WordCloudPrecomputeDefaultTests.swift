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

import Foundation
import Testing
@testable import FRUSExplorer

/// The background word-cloud precompute ships **off**, and the one-time migration turns it off for
/// the installs that adopted the old default by never touching the switch.
///
/// ## Why the feature was disabled rather than throttled
/// Measured from an owner device on build 42 (`cpu_resource_fatal`, 2026-08-17): the corpus job ran
/// NLTagger at **97% CPU for 50 seconds** and iOS killed the process — 48s of CPU against an
/// 80%-over-60s limit. Throttling was the obvious fix and would have been the wrong one, because
/// the feature could not pay for itself even when it completed:
///
/// * A resource kill is not a `CancellationError`. The process dies, `precompute` never returns,
///   the signature is never dequeued, and the same scope runs again on the next wake — forever.
/// * The disk key carries `fp=documentCacheCount`, and the enqueue site is the *end of indexing a
///   volume*, so any entry written is invalidated by the next volume indexed.
/// * The owner ran it on every device and reported no noticeable gain, which is what prompted the
///   check.
///
/// Version history:
///   1.0 — the NLTagger CPU-kill investigation
@Suite("Background word-cloud precompute is off by default", .serialized)
struct WordCloudPrecomputeDefaultTests {

    private static let enabledKey = "frus.wordcloud.backgroundPrecompute"
    private static let markerKey = "frus.wordcloud.backgroundPrecompute.defaultOffMigrated"
    private static let queueKey = "frus.wordcloud.precomputeQueue"

    /// Restores whatever the running user had, so the suite cannot alter a real preference.
    private func withCleanDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.object(forKey: Self.enabledKey)
        let savedMarker = defaults.object(forKey: Self.markerKey)
        let savedQueue = defaults.object(forKey: Self.queueKey)
        defer {
            defaults.removeObject(forKey: Self.enabledKey)
            defaults.removeObject(forKey: Self.markerKey)
            if let savedEnabled { defaults.set(savedEnabled, forKey: Self.enabledKey) }
            if let savedMarker { defaults.set(savedMarker, forKey: Self.markerKey) }
            defaults.removeObject(forKey: Self.queueKey)
            if let savedQueue { defaults.set(savedQueue, forKey: Self.queueKey) }
        }
        defaults.removeObject(forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.markerKey)
        defaults.removeObject(forKey: Self.queueKey)
        body()
    }

    @Test("A fresh install has it off")
    func freshInstallIsOff() {
        withCleanDefaults {
            #expect(WordCloudPrecomputeQueue.isEnabled == false, """
                A fresh install still enables the background precompute. It runs NLTagger over the \
                whole corpus, is killed by iOS at 97% CPU before finishing, and re-queues itself \
                forever.
                """)
        }
    }

    /// The migration is the half that reaches existing users — every install shipped with it on.
    @Test("An install that never touched the switch is turned off once")
    func adoptedDefaultIsMigratedOff() {
        withCleanDefaults {
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            #expect(WordCloudPrecomputeQueue.isEnabled == false, """
                A stored `true` survived the migration. Flipping the default alone reaches nobody \
                who already has the app — which is everyone, since it shipped on.
                """)
        }
    }

    /// Deliberate choices must survive. The migration runs once and only ever removes a `true`.
    @Test("A deliberate opt-in after the migration is respected")
    func deliberateOptInSurvives() {
        withCleanDefaults {
            _ = WordCloudPrecomputeQueue.isEnabled          // runs the migration, sets the marker
            WordCloudPrecomputeQueue.setEnabled(true)
            #expect(WordCloudPrecomputeQueue.isEnabled == true, """
                A user who turned the precompute on AFTER the migration had it turned off again. \
                The migration must run exactly once.
                """)
        }
    }

    /// And an explicit `false` is never rewritten — the migration must not touch it.
    @Test("An explicit opt-out is left alone")
    func explicitOptOutUntouched() {
        withCleanDefaults {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            #expect(WordCloudPrecomputeQueue.isEnabled == false)
            #expect(UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool == false,
                    "the stored opt-out was removed rather than respected")
        }
    }

    /// A backlog enqueued under the old default is dropped — it can never run again.
    @Test("The migration clears a queue left by the old default")
    func migrationClearsTheBacklog() {
        withCleanDefaults {
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            UserDefaults.standard.set(["corpus"], forKey: Self.queueKey)
            _ = WordCloudPrecomputeQueue.isEnabled
            #expect(WordCloudPrecomputeQueue.pending().isEmpty, """
                A backlog queued under the old default survived the migration. The drain refuses \
                those signatures now, so they are dead state that outlives the feature.
                """)
        }
    }

    /// Nothing may be queued while it is off, or the queue grows against a drain that refuses it.
    @Test("Enqueue is a no-op while disabled")
    func enqueueIsNoOpWhenDisabled() {
        withCleanDefaults {
            WordCloudPrecomputeQueue.enqueue("corpus")
            #expect(WordCloudPrecomputeQueue.pending().isEmpty, """
                A scope was queued while the precompute is disabled. The drain refuses to run it, \
                so it would accumulate in UserDefaults forever.
                """)
        }
    }
}
