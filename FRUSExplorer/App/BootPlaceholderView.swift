// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BootPlaceholderView

/// "We are still starting up" — the one surface that says so, rather than lying (#753).
///
/// ## Why this exists
/// The app's async boot runs *after* the first frame: the CloudKit check, sentinel read, FTS5 store
/// open, pipeline init, duplicate-record cleanup and research-trail migration all complete before
/// `searchService`, `crossReferenceStore` and `downloadManager` exist. Every surface that reads one
/// of those had a branch for "it is nil", and each of them rendered a **definitive** statement:
///
/// - the Search tab said *"Search Unavailable — the search index is not available"* over a fully
///   built index of 316,839 documents (audit M-23);
/// - a restored Cross-Reference Graph window said *"No Document Selected"* while holding a perfectly
///   good request (M-22);
/// - and `ContentView` routed a long-onboarded user with hundreds of volumes back to the first-run
///   **Welcome** screen (M-20), because `hasDownloadedVolumes(in: nil)` is `false` and a nil
///   download manager is indistinguishable from an empty library.
///
/// None of those is a wait; all three read as loss or breakage, and the flash lengthens with store
/// size — worst exactly for the users with most to lose.
///
/// macOS Search already carried the fix, with a comment naming the principle: a restored surface
/// "never renders the definitive empty state as a lie". This is that placeholder, extracted so the
/// three iOS sites share one vocabulary instead of three near-copies.
///
/// ## What this is not
/// It is not an error state and must never replace one. A store that genuinely failed to open still
/// needs to say so — the point of the distinction is that "not yet" and "not working" stopped being
/// the same sentence.
///
/// Version history:
///   1.0 — Session 2026-08-08: #753 (audit M-20, M-22, M-23)
struct BootPlaceholderView: View {

    /// Optional line under the spinner, naming what this particular surface is waiting for.
    var detail: String?

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(String(localized: "boot.preparingIndex", defaultValue: "Preparing your index…"))
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // One announcement for the whole surface, so VoiceOver says "still working" rather than
        // reading a spinner with no context.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "boot.preparingIndex.a11y",
                                   defaultValue: "Preparing your index. This surface will fill in when startup finishes."))
    }
}
