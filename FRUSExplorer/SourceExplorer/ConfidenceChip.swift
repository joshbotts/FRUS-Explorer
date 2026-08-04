// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ConfidenceChip

/// A capsule chip stating how confident an archival resolution is — "Likely" or "Possible".
///
/// The **word is the signal**; the tint only reinforces it, so nothing is lost to a
/// color-blind user and VoiceOver reads the confidence without help. That is why this chip
/// carries an explicit accessibility label rather than relying on the bare text.
///
/// Introduced by the pre-1906 country-series section (Phase 2), where a document with no
/// source note is classified from its dateline and both candidates are shown. It was
/// duplicated verbatim in `SourceExplorerView` and `MacSourceExplorerView`; #375's curated
/// lot outcomes needed the same grammar, and a third copy is how the two Source Explorer
/// views drift apart (`project_dual_settings_views`). One chip, two call sites each.
///
/// Version history:
///   1.0 — Session 2026-08-03: extracted from the two Source Explorer views for #375 (N-3)
struct ConfidenceChip: View {

    /// How confident the resolution is.
    let confidence: CentralFilesConfidence

    var body: some View {
        Text(confidence.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidence == .high ? Color.green.opacity(0.18)
                                            : Color.orange.opacity(0.18),
                        in: Capsule())
            .accessibilityLabel(String(format: String(
                localized: "confidence.chip.accessibility %@",
                defaultValue: "Confidence: %@"), confidence.label))
    }
}
