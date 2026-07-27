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
struct WhileIndexingSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        IndexingEducationView(presentationContext: .onboarding) {
            dismiss()
        }
        .background { indexingCloudBackdrop }
    }

    /// (c) — the word cloud behind the education content, scoped to what is landing.
    ///
    /// The plan places the cloud here rather than behind the banner strip: this sheet is
    /// what actually fills the download-and-index wait, and it is the surface that is
    /// genuinely bare for minutes. **Backdrop to the content, never a rival to it** — hence
    /// the quieter dim factor and no lens chip, so it cannot compete with the prose a user
    /// opened this sheet to read.
    ///
    /// Scoped to the volumes currently queued, so it re-aggregates as they land.
    @ViewBuilder
    private var indexingCloudBackdrop: some View {
        if CloudSurfaceArbiter.resolve(appState: appState) == .indexingBackdrop {
            WordCloudBackdropView(
                scope: CloudSurfaceArbiter.indexingScope(
                    queuedVolumeIds: appState.downloadQueue,
                    manifest: appState.manifestStore
                ),
                dim: FRUSTheme.cloudDimAddVolumes,
                showsChip: false
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}
