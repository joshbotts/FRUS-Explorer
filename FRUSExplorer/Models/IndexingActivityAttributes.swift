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

#if os(iOS)
import ActivityKit
import Foundation

/// The kind of long-running job a Live Activity represents.
///
/// The activity contract was generalised from indexing-only to any background
/// job; `kind` lets the widget pick the right verb/icon. Optional in the content
/// state so activities encoded by an older app version (no `kind`) still decode —
/// `nil` is treated as `.indexing`.
///
/// Version history:
///   1.0 — Live Activity generalization
public enum LiveActivityJobKind: String, Codable, Hashable, Sendable {
    case indexing
    case summarizing
}

/// ActivityKit attributes for the FRUS Explorer indexing Live Activity.
///
/// Shared between the main app target (which starts and updates the activity) and the
/// `FRUSExplorerWidgets` extension (which renders the Dynamic Island and lock-screen UI).
/// The struct is compiled independently into each target — no shared framework is needed.
///
/// ## Lifecycle
/// - Started by `AppState.syncIndexingLiveActivity(update:)` when the first non-complete
///   `IndexingProgressUpdate` arrives and this process holds no indexing activity. An indexing
///   activity an earlier process left is taken over in place of a new one.
/// - Updated by the same function on each throttled progress event (≤10 Hz via the clock-based
///   filter in `connectIndexingProgress`). Every update carries a stale date, and the app sends
///   the last one again while it runs (`LiveActivityLifecycle`), so the system marks the
///   activity stale only when the app has stopped running; the widget then draws
///   `ContentState.Detail.stopped`.
/// - Ended by `AppState.endIndexingLiveActivity()` when stage == `.complete`, and, for an
///   activity nothing is driving any more, by `AppState.endLeftoverLiveActivities()` at the
///   next launch (#1642).
///
/// A summarization run's activity has the same attributes and the same lifecycle, through
/// `AppState.syncSummarizationLiveActivity()`.
public struct IndexingActivityAttributes: ActivityAttributes {

    /// Dynamic content that changes with each progress update.
    ///
    /// Generalised beyond indexing: `kind` selects the verb/icon, and the field
    /// names below read generically — `volumeTitle` is the job's title,
    /// `completedDocuments`/`totalDocuments` are processed/total items, and
    /// `isOptimizing` is any indeterminate "finishing" phase.
    public struct ContentState: Codable, Hashable, Sendable {
        /// The job kind. `nil` (older encodings) is treated as `.indexing`.
        public var kind: LiveActivityJobKind?
        /// Display title of the job (shown in Dynamic Island + lock screen).
        public var volumeTitle: String
        /// 0.0–1.0 fractional progress, or `nil` while the XML parse is running or during FTS5 optimise.
        public var progressFraction: Double?
        /// Estimated seconds remaining, or `nil` when rate is unknown.
        public var etaSeconds: Int?
        /// Number of documents stored so far in the current volume.
        public var completedDocuments: Int
        /// Total document count for the current volume (0 until parse completes).
        public var totalDocuments: Int
        /// `true` during the post-batch FTS5 optimise pass (renders an indeterminate indicator).
        public var isOptimizing: Bool
        /// 1-based position within a multi-volume batch, or `nil` for single-volume indexing.
        public var queueCurrent: Int?
        /// Total volume count in the current batch, or `nil` for single-volume indexing.
        public var queueTotal: Int?

        /// The job kind, defaulting to `.indexing` for content encoded before `kind` existed.
        public var resolvedKind: LiveActivityJobKind { kind ?? .indexing }

        /// What an activity shows under its title.
        public enum Detail: Equatable, Sendable {
            /// The app has stopped updating the activity: the last update's stale date has passed.
            case stopped
            /// The indeterminate finishing phase (`isOptimizing`).
            case finishing
            /// Progress as a fraction, 0 to 1.
            case progress(Double)
            /// Under way, with no fraction to show yet.
            case indeterminate
        }

        /// What to show under the title, given whether the system has marked the activity stale.
        ///
        /// Stale comes first. Whatever the last update said, the app is no longer doing it, and a
        /// moving bar or a count of seconds left would say that it is (#1642). Both of the
        /// widget's presentations read this, so the Dynamic Island and the Lock Screen agree.
        public func detail(isStale: Bool) -> Detail {
            if isStale { return .stopped }
            if isOptimizing { return .finishing }
            if let progressFraction { return .progress(progressFraction) }
            return .indeterminate
        }
    }
}
#endif
