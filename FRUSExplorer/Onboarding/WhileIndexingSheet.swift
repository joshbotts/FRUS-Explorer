// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - WhileIndexingSheet

/// The first-run education sheet shown from the indexing banner while the first volumes
/// index.
///
/// Originally this presented the educational pages followed by a guided
/// project-and-collection setup wizard (`IndexingSetupWizardView`). Session 163 removed the
/// forced setup: new users now just read the `IndexingEducationView` feature guide and tap
/// "Start exploring" to dismiss. A default research project is already created silently by
/// `OnboardingView`, and projects/collections are created on demand from the normal UI
/// (the project picker and `CollectionEditorView`), so nothing is lost by dropping the
/// up-front configuration.
///
/// Presented from `IndexingQueueBannerView` (iOS only). The macOS status bar's
/// auto-presented copy was removed by the 2026-07-04 UI audit (B7) — its "Learn"
/// button now opens the standalone `frus.researchGuide` window instead, so nothing
/// modal interrupts first-run exploration on macOS.
///
/// Version history:
///   1.0 — Session 155: education pages + project/collection setup wizard
///   2.0 — Session 163: setup wizard removed; education-only, dismiss on completion
///   2.1 — Session 2026-07-04 (macOS UI audit B7): macOS presentation removed;
///          iOS-only from here on (view unchanged)
///   2.2 — O-0: file renamed `IndexingSetupWizardView.swift` → `WhileIndexingSheet.swift`.
///          The old name was the wizard Session 163 deleted, and it made this live,
///          iOS-presented sheet read as dead code in two separate audits. View unchanged.
///   3.0 — O-3 fix: the (c) word-cloud backdrop lives HERE, behind the education
///         content. O-3 declared it in `MainTabView` and never placed it in the
///         hierarchy, so it rendered on no device; and behind the banner strip it
///         would have been a thin bar rather than a backdrop. This sheet is the
///         surface the plan actually names.
///   3.1 — Session 2026-08-07: backdrop removed. See "Why the cloud is not here" below —
///         O-3's own rule ("backdrop to the content, never a rival to it") is what it
///         failed in practice, on the one surface whose entire purpose is reading.
///
/// ## Why the cloud is not here
/// Version 3.0 put the animated word cloud behind this sheet on the reasoning that this is
/// the surface genuinely bare for minutes. In use it reads the other way round: the sheet is
/// **several screens of prose a first-run user is being asked to read**, and a cloud that
/// re-aggregates as volumes land animates *underneath the paragraph they are on*. O-3's own
/// constraint was "backdrop to the content, never a rival to it", and moving text is a rival
/// no dim factor fixes.
///
/// The cloud is not lost — it still runs where it costs nothing to read: the launch splash,
/// the onboarding backdrop, and the `IndexingCloudStrip` in the indexing banner itself, which
/// is where a user watching progress will actually see it. `CloudSurfaceArbiter`'s
/// `.indexingBackdrop` case therefore still has live consumers (both banner views and
/// `ContentView`) and is deliberately left in place.
struct WhileIndexingSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        IndexingEducationView(presentationContext: .onboarding) {
            dismiss()
        }
    }
}
