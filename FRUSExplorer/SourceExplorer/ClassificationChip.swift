// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ClassificationChip

/// A quiet capsule chip showing a document source note's classification markings
/// (Source Explorer Phase 5, surfacing the Phase-1 S1 column).
///
/// The marking text is extracted by
/// `SourceNoteParser.classificationMarking(fromSourceNote:)` — sentence 2 of the
/// note when it matches the marking vocabulary (e.g. "Secret; Nodis",
/// "No classification marking") — the same derivation `document_sources.classification`
/// stores at index time. Surfaces: the Source Explorer (iOS sheet + macOS window,
/// beside the raw note), search result rows (both the iOS search view and the macOS
/// search window — the note is already loaded per row, no extra query), and — via the
/// HTML pipeline, not this view — the reading views' source footnote.
///
/// Styling is deliberately semantic-quiet: secondary text in a hairline capsule, no
/// color coding — the text itself is the signal (classification levels are historical
/// metadata, not alerts), and no color-only channel means nothing is lost to
/// color-blind users. VoiceOver reads an explicit "Classification markings" prefix.
///
/// Version history:
///   1.0 — Session 2026-07-04: Source Explorer Phase 5 step 1
struct ClassificationChip: View {

    /// The marking text (e.g. "Secret; Nodis"), already validated by
    /// `SourceNoteParser.classificationMarking(fromSourceNote:)`.
    let marking: String

    var body: some View {
        Text(marking)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.5), in: Capsule())
            .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
            .accessibilityLabel(String(format: String(
                localized: "classification.chip.accessibility %@",
                defaultValue: "Classification markings: %@"), marking))
    }
}
