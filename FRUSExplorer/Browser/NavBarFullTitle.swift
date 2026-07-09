// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - TwoLineNavTitleView

/// A navigation-bar principal title that wraps to two lines, doubling the usable title
/// space over the system inline title (one tail-truncated line).
///
/// FRUS volume and compilation titles begin with the constant boilerplate
/// "Foreign Relations of the United States, …", so a single inline line often shows only
/// the boilerplate and truncates the distinctive tail. Rendered as a two-line principal
/// `ToolbarItem`, the example titles fit almost entirely. Paragraph-length 19th-century
/// titles still cannot fit any navigation bar — the complete value stays available in the
/// in-content title header (which scrolls) and, for VoiceOver, in this view's
/// `accessibilityLabel`, which always carries the full untruncated string.
///
/// Mirrors the existing principal-toolbar precedent in `ArchivalNeighborsSheet`.
///
/// Version history:
///   1.0 — Session 1 / #237: initial implementation
struct TwoLineNavTitleView: View {
    /// The complete title; shown wrapped to two lines and exposed in full to VoiceOver.
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            // VoiceOver reads the complete title, not the visually truncated two lines.
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
    }
}
