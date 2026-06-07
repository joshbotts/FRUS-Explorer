// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ResearchGuideView

/// Standalone presentation of the FRUS educational pages, independent of
/// the indexing flow.
///
/// `IndexingEducationView` was originally built to run only once, while the
/// first index builds. Its content — what FRUS is, how the corpus evolved,
/// how to read a document, and how to research with it — is also valuable
/// as an on-demand reference, so this wrapper re-presents the same five
/// pages with `presentationContext: .standalone`:
///  - the final page offers "Done" instead of "Set Up My Research →"
///  - the guide can open directly to a specific page via
///    `AppState.researchGuideInitialPageId`, which contextual entry points
///    (e.g. an info affordance in the Source Explorer) set just before
///    presenting the guide
///
/// ## Entry points
/// - **iOS/iPadOS**: presented as a sheet from Settings
///   (`AppState.showResearchGuide`)
/// - **macOS**: a dedicated `Window` scene (`id: "frus.researchGuide"`)
///   reachable from the Help menu
///
/// Version history:
///   1.0 — Session 2026-06-06: introduced alongside the standalone
///         `IndexingEducationView.PresentationContext`
struct ResearchGuideView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let initialPageId = appState.researchGuideInitialPageId
        content(initialPageId: initialPageId)
            // Consume the deep-link request so a later plain "open the guide"
            // (with no requested topic) starts from the first page again.
            .onDisappear {
                appState.researchGuideInitialPageId = nil
            }
    }

    @ViewBuilder
    private func content(initialPageId: String?) -> some View {
        #if os(iOS)
        NavigationStack {
            educationView(initialPageId: initialPageId)
                .navigationTitle(String(localized: "researchGuide.title",
                                        defaultValue: "Research Guide"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "researchGuide.close", defaultValue: "Close")) {
                            dismiss()
                        }
                    }
                }
        }
        #else
        educationView(initialPageId: initialPageId)
        #endif
    }

    private func educationView(initialPageId: String?) -> some View {
        IndexingEducationView(
            initialPageId: initialPageId,
            presentationContext: .standalone,
            onComplete: { dismiss() }
        )
        // Re-create the view (and its internal page-index state) when the
        // requested topic changes, so a second contextual deep link while
        // the guide is already open jumps to the new page.
        .id(initialPageId ?? "default")
    }
}

// MARK: - ResearchGuideLinkButton

/// Contextual entry point that opens the standalone Research Guide
/// pre-scrolled to a specific `EducationPage`.
///
/// Several screens reference concepts the Research Guide explains in more
/// depth — the Source Explorer's source-note breakdown and NARA Catalog
/// Lookup both relate to "Understanding What You're Reading"
/// (`EducationPage.page3`, id `"understanding-documents"`), and the App
/// Feature Walkthrough page documents Source Explorer and NARA Lookup
/// directly (`EducationPage.page5`, id `"app-features"`). Rather than
/// duplicating "set the deep-link target, then present the guide" at each
/// call site, this button centralizes it:
///  - sets `AppState.researchGuideInitialPageId` to `pageId`
///  - **macOS**: opens the dedicated `Window` scene (`id: "frus.researchGuide"`)
///  - **iOS/iPadOS**: presents `ResearchGuideView` as a local sheet
///
/// Version history:
///   1.0 — Session 2026-06-06: introduced for contextual deep-links from
///         Source Explorer, NARA Catalog Lookup, and document source notes
struct ResearchGuideLinkButton: View {

    /// The `EducationPage.id` to open the guide to.
    let pageId: String
    /// Accessible label and toolbar/menu title for the button, e.g.
    /// "Learn About Source Notes".
    let label: String

    @Environment(AppState.self) private var appState

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #else
    @State private var showGuide = false
    #endif

    var body: some View {
        Button {
            // Set the deep-link target *before* presenting/opening the guide
            // — `ResearchGuideView` reads it on appearance.
            appState.researchGuideInitialPageId = pageId
            #if os(macOS)
            openWindow(id: "frus.researchGuide")
            #else
            showGuide = true
            #endif
        } label: {
            Label(label, systemImage: "questionmark.circle")
        }
        #if os(iOS)
        .sheet(isPresented: $showGuide) {
            ResearchGuideView()
        }
        #endif
    }
}
