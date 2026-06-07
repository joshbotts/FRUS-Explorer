// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - IndexingSetupWizardView

/// Guided research-context setup shown after the educational pages while indexing runs.
///
/// Two steps:
///  1. **Project** — name and research-question for a first research project
///  2. **Collection** — name and curator note for a first collection
///
/// Neither step is required; "Skip" advances without creating the record.
/// On completion the sheet dismisses back to the main interface.
///
/// Category 4 note (from planning): the collection step intentionally does NOT
/// let users add volumes yet — adding documents requires the index to be
/// partially complete, and the intent is to give users something *to think about*
/// while they wait, not to build the collection now.
///
/// Version history:
///   1.0 — Session 155: initial implementation
struct IndexingSetupWizardView: View {

    // MARK: - Dependencies

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var step: Step = .project
    @State private var projectName: String = ""
    @State private var projectQuestion: String = ""
    @State private var collectionName: String = ""
    @State private var collectionNote: String = ""
    @State private var isSaving: Bool = false

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(16)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case .project:  projectContent
                    case .collection: collectionContent
                    case .done:     doneContent
                    }
                }
                .padding(24)
            }

            Divider()

            // Button bar
            HStack {
                Button(step == .project
                       ? String(localized: "setup.skip", defaultValue: "Skip")
                       : String(localized: "setup.back", defaultValue: "Back")) {
                    handleBack()
                }
                .keyboardShortcut(step == .project ? .cancelAction : .none)
                Spacer()
                Button(advanceLabel) { handleAdvance() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 380)
    }
    #endif

    // MARK: - iOS

    private var iOSBody: some View {
        NavigationStack {
            Form {
                switch step {
                case .project:    projectSection
                case .collection: collectionSection
                case .done:       doneSection
                }
            }
            .navigationTitle(step.navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .project
                           ? String(localized: "setup.skip", defaultValue: "Skip")
                           : String(localized: "setup.back", defaultValue: "Back")) {
                        handleBack()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(advanceLabel) { handleAdvance() }
                        .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Step content (iOS Form sections)

    private var projectSection: some View {
        Group {
            Section(String(localized: "setup.project.header",
                           defaultValue: "Research Project")) {
                TextField(String(localized: "setup.project.namePlaceholder",
                                 defaultValue: "Project name"),
                          text: $projectName)
                TextField(String(localized: "setup.project.questionPlaceholder",
                                 defaultValue: "Research question (optional)"),
                          text: $projectQuestion,
                          axis: .vertical)
                    .lineLimit(3...6)
            }
            Section {
                Text(String(localized: "setup.project.explanation",
                            defaultValue: "Projects offer users an activity lens on their research in FRUS Explorer. Every note, highlight, summary, and collection you create is tagged with the active project, making it easy to keep separate research threads distinct in the app. You can switch projects instantly, or work in the global context with no project selected."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var collectionSection: some View {
        Group {
            Section(String(localized: "setup.collection.header",
                           defaultValue: "Collection")) {
                TextField(String(localized: "setup.collection.namePlaceholder",
                                 defaultValue: "Collection name"),
                          text: $collectionName)
                TextField(String(localized: "setup.collection.notePlaceholder",
                                 defaultValue: "What is this collection for? What argument or theme will it build?"),
                          text: $collectionNote,
                          axis: .vertical)
                    .lineLimit(4...10)
            }
            Section {
                Text(String(localized: "setup.collection.explanation",
                            defaultValue: "A collection is a curated set of FRUS documents you assemble for a purpose — a compilation of primary sources for students to discuss in class, a dossier to include in a policy brief, or a research workbook that can be easily integrated with other sources. You can add documents once indexing finishes. Jot down what kinds of documents you want to find in FRUS and how you intend to use them in the note to capture your thinking now, while your purpose is clear."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var doneSection: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(String(localized: "setup.done.title", defaultValue: "You're set up"))
                    .font(.headline)
                Text(String(localized: "setup.done.body",
                            defaultValue: "Indexing is still running in the background. When it finishes, the volumes you have added will be searchable. Happy FRUSing!"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - macOS step content (VStack-based)

    private var projectContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "setup.project.name.label", defaultValue: "Project name"))
                    .font(.callout.weight(.medium))
                TextField(String(localized: "setup.project.namePlaceholder",
                                 defaultValue: "Project name"),
                          text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "setup.project.question.label",
                            defaultValue: "Research question (optional)"))
                    .font(.callout.weight(.medium))
                TextField(String(localized: "setup.project.questionPlaceholder",
                                 defaultValue: "What are you trying to understand?"),
                          text: $projectQuestion,
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }
            Text(String(localized: "setup.project.explanation",
                        defaultValue: "Projects offer users an activity lens on their research in FRUS Explorer. Every note, highlight, summary, and collection you create is tagged with the active project, making it easy to keep separate research threads distinct in the app. You can switch projects instantly, or work in the global context with no project selected."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var collectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "setup.collection.name.label", defaultValue: "Collection name"))
                    .font(.callout.weight(.medium))
                TextField(String(localized: "setup.collection.namePlaceholder",
                                 defaultValue: "Collection name"),
                          text: $collectionName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "setup.collection.note.label",
                            defaultValue: "Collection note"))
                    .font(.callout.weight(.medium))
                TextField(String(localized: "setup.collection.notePlaceholder",
                                 defaultValue: "What is this collection for? What argument or theme will it build?"),
                          text: $collectionNote,
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
            }
            Text(String(localized: "setup.collection.explanation",
                        defaultValue: "A collection is a curated set of FRUS documents you assemble for a purpose — a compilation of primary sources for students to discuss in class, a dossier to include in a policy brief, or a research workbook that can be easily integrated with other sources. You can add documents once indexing finishes. Jot down what kinds of documents you want to find in FRUS and how you intend to use them in the note to capture your thinking now, while your purpose is clear."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var doneContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(String(localized: "setup.done.title", defaultValue: "You're set up"))
                .font(.title2.bold())
            Text(String(localized: "setup.done.body",
                        defaultValue: "Indexing is still running in the background. When it finishes, the volumes you have added will be searchable. Happy FRUSing!"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step indicator (macOS)

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Step.allCases) { s in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step == s ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 22, height: 22)
                        if completedSteps.contains(s) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(s.number)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(step == s ? .white : .secondary)
                        }
                    }
                    Text(s.label)
                        .font(.system(size: 12))
                        .foregroundStyle(step == s ? Color.primary : Color.secondary)
                }
                if s != Step.allCases.last {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    private var completedSteps: Set<Step> {
        switch step {
        case .project:    return []
        case .collection: return [.project]
        case .done:       return [.project, .collection]
        }
    }

    // MARK: - Navigation

    private var advanceLabel: String {
        switch step {
        case .project:    return String(localized: "setup.advance.project",  defaultValue: "Next")
        case .collection: return String(localized: "setup.advance.collection", defaultValue: "Next")
        case .done:       return String(localized: "setup.advance.done",     defaultValue: "Start Researching")
        }
    }

    private func handleAdvance() {
        switch step {
        case .project:
            let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let project = Project(
                    name: name,
                    researchQuestion: projectQuestion.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                modelContext.insert(project)
                appState.activeProjectId = project.id
            }
            withAnimation { step = .collection }

        case .collection:
            let name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let note = collectionNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                let collection = Collection(name: name, note: note)
                modelContext.insert(collection)
            }
            withAnimation { step = .done }

        case .done:
            dismiss()
        }
    }

    private func handleBack() {
        switch step {
        case .project:    dismiss()
        case .collection: withAnimation { step = .project }
        case .done:       withAnimation { step = .collection }
        }
    }

    // MARK: - Step enum

    enum Step: String, CaseIterable, Identifiable {
        case project, collection, done
        var id: String { rawValue }
        var number: Int {
            switch self { case .project: return 1; case .collection: return 2; case .done: return 3 }
        }
        var label: String {
            switch self {
            case .project:    return String(localized: "setup.step.project",    defaultValue: "Project")
            case .collection: return String(localized: "setup.step.collection", defaultValue: "Collection")
            case .done:       return String(localized: "setup.step.done",       defaultValue: "Done")
            }
        }
        var navigationTitle: String {
            switch self {
            case .project:    return String(localized: "setup.nav.project",    defaultValue: "Research Project")
            case .collection: return String(localized: "setup.nav.collection", defaultValue: "Start a Collection")
            case .done:       return String(localized: "setup.nav.done",       defaultValue: "Ready")
            }
        }
    }
}

// MARK: - WhileIndexingSheet

/// Combined education + setup container. Shown as a sheet from the indexing banner.
struct WhileIndexingSheet: View {
    @State private var phase: Phase = .education
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch phase {
        case .education:
            IndexingEducationView {
                withAnimation { phase = .setup }
            }
        case .setup:
            IndexingSetupWizardView()
        }
    }

    enum Phase { case education, setup }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? { self.isEmpty ? nil : self }
}
