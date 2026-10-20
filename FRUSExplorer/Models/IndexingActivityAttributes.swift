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
///   `IndexingProgressUpdate` of a queue arrives and this process holds no indexing activity. A
///   live indexing activity an earlier process left is taken over in place of a new one
///   (`LiveActivityLifecycle.activityToTakeOver(_:among:ended:)`).
/// - Updated by the same function on each throttled progress event (≤10 Hz via the clock-based
///   filter in `connectIndexingProgress`), for every volume of the queue in turn, and shown each
///   volume finished as it finishes. Every update carries a stale date, and the app sends
///   the last one again while it runs (`LiveActivityLifecycle`), so the system marks the
///   activity stale only when the app has stopped running; the widget then draws
///   `ContentState.Detail.stopped`.
/// - Ended by `AppState.endIndexingLiveActivity()` when the queue ends (`endIndexingBatch()`),
///   not as each volume finishes: one activity follows the whole queue (#1695, plan of record
///   decision 63). An activity nothing is driving any more is ended by
///   `AppState.endLeftoverLiveActivities()` at the next launch (#1642).
///
/// A summarization run's activity has the same attributes and the same lifecycle, through
/// `AppState.syncSummarizationLiveActivity()`, and ends with its run.
///
/// Version history:
///   1.0 — 2026-06-05: initial implementation, with the Dynamic Island Live Activity
///   1.1 — 2026-10-12 (#1642): `ContentState.detail(isStale:)`
///   1.2 — 2026-10-20 (#1695): `ContentState.continuesInBackground`, `shownSecondsLeft` and
///          `stoppedLabel`, the last moved here from the widget so a unit test reads what it prints
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
        /// Estimated seconds remaining, rounded up, or `nil` when rate is unknown. The widget
        /// prints it through `shownSecondsLeft`.
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
        /// Whether a summarization run goes on by itself while the app is not running (#1695,
        /// plan of record decision 64): Continue in the background is on, and the run is saved
        /// for the background task to resume. `nil` for an indexing run and in content encoded
        /// before it existed; both read as `false`.
        public var continuesInBackground: Bool? = nil

        /// The job kind, defaulting to `.indexing` for content encoded before `kind` existed.
        public var resolvedKind: LiveActivityJobKind { kind ?? .indexing }

        /// The fewest seconds left the widget prints (#1695). A volume often takes no more than
        /// that, and #1642's session saw "~0s" for most of one, when the count was cut down to a
        /// whole second rather than rounded up.
        public static let fewestSecondsShown = 5

        /// The seconds left as the widget prints them: `etaSeconds`, or `nil` under
        /// `fewestSecondsShown`.
        public var shownSecondsLeft: Int? {
            guard let etaSeconds, etaSeconds >= Self.fewestSecondsShown else { return nil }
            return etaSeconds
        }

        /// What the activity says in place of its count and seconds left once the app has
        /// stopped updating it (#1642), and what VoiceOver is told for the small Dynamic
        /// Island's pause mark.
        ///
        /// The system marks an activity stale two minutes after its last update, and the app
        /// sends one every thirty seconds while it runs, so this shows when the app has been
        /// suspended in the background or has gone. The widget cannot tell which. Opening the app
        /// is the next step in both: a suspended run goes on, and after the app was closed the
        /// launch ends this activity and shows what is left to do.
        ///
        /// A summarization run the background task will resume says so (`continuesInBackground`,
        /// decision 64): between two of its background runs the app is suspended, and the work
        /// goes on at the next one without the reader.
        public var stoppedLabel: String {
            switch resolvedKind {
            case .indexing:
                return String(localized: "liveactivity.stopped.indexing",
                              defaultValue: "Indexing has stopped. Open FRUS Explorer to continue.")
            case .summarizing:
                if continuesInBackground == true {
                    return String(localized: "liveactivity.stopped.summarizing.background",
                                  defaultValue: "Summarizing will continue in the background. Open FRUS Explorer to continue now.")
                }
                return String(localized: "liveactivity.stopped.summarizing",
                              defaultValue: "Summarizing has stopped. Open FRUS Explorer to continue.")
            }
        }

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
