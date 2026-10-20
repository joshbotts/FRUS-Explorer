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

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Job-kind presentation

private extension IndexingActivityAttributes.ContentState {
    /// SF Symbol for the compact / minimal presentation, by job kind.
    var compactSymbol: String {
        switch resolvedKind {
        case .indexing:    return "square.and.arrow.down"
        case .summarizing: return "sparkles"
        }
    }

    /// SF Symbol for the expanded / lock-screen leading icon (stale overrides optimise, which
    /// overrides the job kind).
    func leadingSymbol(isStale: Bool) -> String {
        if isStale { return "pause.circle" }
        if isOptimizing { return "wand.and.stars" }
        return compactSymbol
    }

    /// The colour of the activity's icons: blue while the app is updating it, grey once it has
    /// stopped.
    func iconColor(isStale: Bool) -> Color {
        isStale ? .secondary : .blue
    }

    /// Localised text shown while progress is indeterminate (no fraction).
    var indeterminateLabel: String {
        switch resolvedKind {
        case .indexing:
            return String(localized: "liveactivity.parsing", defaultValue: "Parsing…")
        case .summarizing:
            // Indeterminate means the run has no total yet, which is the enumeration phase — it is
            // parsing volumes, not summarizing (#560).
            return String(localized: "liveactivity.summarizing.preparing",
                          defaultValue: "Preparing to summarize…")
        }
    }
}

/// Live Activity widget for FRUS Explorer indexing progress.
///
/// Renders in three contexts:
/// - **Dynamic Island compact**: small download icon (leading) + percentage or "…" (trailing)
/// - **Dynamic Island expanded**: volume title, linear progress bar, ETA
/// - **Lock screen / banner**: full progress card matching the expanded Dynamic Island layout
///
/// Each draws a stale activity as stopped (#1642): grey icons, a pause mark where the percentage
/// was, the bar held grey at its last fraction, and `stoppedLabel` in place of the count and the
/// seconds left. `ContentState.detail(isStale:)` decides it for all three. The sentence, and
/// which seconds left are printed (`shownSecondsLeft`), are in `IndexingActivityAttributes.swift`,
/// which the app compiles too, so its unit tests read what this prints (#1695).
///
/// One activity follows a whole indexing queue (#1695), so the title names each volume in turn,
/// and the finishing merge of a whole-library pass, which names no volume, is titled
/// *Finalizing index…* by the app.
struct IndexingLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IndexingActivityAttributes.self) { context in
            IndexingLockScreenView(state: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.leadingSymbol(isStale: context.isStale))
                        .foregroundStyle(context.state.iconColor(isStale: context.isStale))
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let qc = context.state.queueCurrent, let qt = context.state.queueTotal {
                        Text("\(qc)/\(qt)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IndexingExpandedView(state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                Image(systemName: context.state.compactSymbol)
                    .foregroundStyle(context.state.iconColor(isStale: context.isStale))
            } compactTrailing: {
                switch context.state.detail(isStale: context.isStale) {
                case .stopped:
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(context.state.stoppedLabel)
                case .finishing:
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.blue)
                case .progress(let fraction):
                    Text("\(Int(fraction * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                case .indeterminate:
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                if context.isStale {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(context.state.stoppedLabel)
                } else {
                    Image(systemName: context.state.compactSymbol)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - Expanded / Lock-Screen View

private struct IndexingExpandedView: View {
    let state: IndexingActivityAttributes.ContentState
    /// Whether the system has marked the activity stale: the app has stopped updating it.
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.volumeTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            switch state.detail(isStale: isStale) {
            case .stopped:
                // The bar is held, grey, at the last fraction the app reported: where the work
                // stopped. A state that had no fraction has no bar, since a moving one would say
                // that something is still happening.
                if let fraction = state.progressFraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(Color.secondary)
                }
                Text(state.stoppedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .finishing:
                // The title says it: the app titles the finishing merge *Finalizing index…*
                // (#1695), where the line under the bar said it under an empty title.
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
            case .progress(let fraction):
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                HStack {
                    if state.totalDocuments > 0 {
                        Text("\(state.completedDocuments)/\(state.totalDocuments) docs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let eta = state.shownSecondsLeft {
                        Text("~\(eta)s")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            case .indeterminate:
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
                Text(state.indeterminateLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct IndexingLockScreenView: View {
    let state: IndexingActivityAttributes.ContentState
    /// Whether the system has marked the activity stale: the app has stopped updating it.
    let isStale: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.leadingSymbol(isStale: isStale))
                .font(.title2)
                .foregroundStyle(state.iconColor(isStale: isStale))
                .frame(width: 32)
            IndexingExpandedView(state: state, isStale: isStale)
        }
        .padding()
    }
}
