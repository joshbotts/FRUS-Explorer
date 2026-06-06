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

/// Live Activity widget for FRUS Explorer indexing progress.
///
/// Renders in three contexts:
/// - **Dynamic Island compact**: small download icon (leading) + percentage or "…" (trailing)
/// - **Dynamic Island expanded**: volume title, linear progress bar, ETA
/// - **Lock screen / banner**: full progress card matching the expanded Dynamic Island layout
struct IndexingLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IndexingActivityAttributes.self) { context in
            IndexingLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isOptimizing ? "wand.and.stars" : "square.and.arrow.down")
                        .foregroundStyle(.blue)
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
                    IndexingExpandedView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if context.state.isOptimizing {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.blue)
                } else if let fraction = context.state.progressFraction {
                    Text("\(Int(fraction * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Expanded / Lock-Screen View

private struct IndexingExpandedView: View {
    let state: IndexingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.volumeTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            if state.isOptimizing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
                Text(String(localized: "liveactivity.optimizing", defaultValue: "Finalizing index…"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let fraction = state.progressFraction {
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
                    if let eta = state.etaSeconds {
                        Text("~\(eta)s")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
                Text(String(localized: "liveactivity.parsing", defaultValue: "Parsing…"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct IndexingLockScreenView: View {
    let state: IndexingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.isOptimizing ? "wand.and.stars" : "square.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            IndexingExpandedView(state: state)
        }
        .padding()
    }
}
