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
struct WhileIndexingSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        IndexingEducationView(presentationContext: .onboarding) {
            dismiss()
        }
    }
}
