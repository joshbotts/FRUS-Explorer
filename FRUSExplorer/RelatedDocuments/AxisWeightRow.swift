// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AxisWeightRow

/// One similarity axis's weight slider — the single implementation, mounted by both tuning surfaces
/// (#1029).
///
/// ## Why this exists
/// The global tuning in `RelatedDocumentsView` and the per-project override in `ProjectHomeView`
/// carried two hand-maintained copies of this row whose bodies were identical apart from the bound
/// state, the release action, and one localization key holding the *same sentence*. They drifted:
/// both were still rendering "Available when detected-topic data ships" long after the artifact
/// shipped, and the fix in #1020 had to be made twice. No test pinned either copy, so the next
/// drift would have shipped just as quietly. This is the `SemanticStorageSection` precedent —
/// "a section written twice is two places to drift".
///
/// ## The release contract, which is load-bearing
/// The value updates live for feedback, but `onCommit` fires **only when the drag settles**
/// (`onEditingChanged == false`). Both callers do something expensive there — a UserDefaults write
/// plus a re-rank, or a project write plus a debounced recompute — so a drag must be one commit and
/// not one per tick.
///
/// Both hosts already compile for iOS and macOS, so this needs no `#if os` split.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1029, extracted from the two copies
struct AxisWeightRow: View {

    /// The axis this row tunes.
    let axis: SimilarityAxis

    /// The live weight, `0...1`. Bound to the caller's draft state, never to storage — see the
    /// release contract above.
    @Binding var value: Double

    /// An explanatory caption rendered under the slider, or `nil` for none.
    ///
    /// A parameter rather than a computed property so the difference between the two hosts is one
    /// visible line at the call site instead of a hidden divergence in two bodies: the Related panel
    /// explains the semantic axis where the reader meets it, and Project Home does not.
    var caption: String?

    /// Called when the drag settles. Never on every tick.
    let onCommit: () -> Void

    /// Whether this axis's backing data is missing on this device.
    ///
    /// Only the detected-topic axis can be in this state, and only when the bundled index is absent
    /// or failed to decode — NOT "the data has not shipped yet", which is what the retired copy in
    /// both twins used to claim (#1020).
    private var isUnavailable: Bool {
        axis == .sharedSubjects && DocumentSubjectStore.shared == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Label(axis.displayName, systemImage: axis.systemImage)
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0...1,
                   onEditingChanged: { editing in if !editing { onCommit() } })
                .disabled(isUnavailable)
            if isUnavailable {
                // ONE key now, and that is the point: the twins each carried this identical sentence
                // under their own namespace precisely because sharing a key across two views is the
                // collision this codebase has been bitten by before. With one view there is one
                // string, so the reason for two keys is gone.
                Text(String(localized: "related.weights.axis.unavailable",
                            defaultValue: "Detected-topic data is unavailable on this device."))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
