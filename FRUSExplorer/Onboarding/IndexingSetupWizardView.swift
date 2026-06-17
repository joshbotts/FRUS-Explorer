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
/// Presented from `IndexingQueueBannerView` (iOS) and `SupportingViews` (macOS).
///
/// Version history:
///   1.0 — Session 155: education pages + project/collection setup wizard
///   2.0 — Session 163: setup wizard removed; education-only, dismiss on completion
struct WhileIndexingSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        IndexingEducationView(presentationContext: .onboarding) {
            dismiss()
        }
    }
}
