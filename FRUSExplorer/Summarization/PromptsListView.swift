// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - PromptsListView

/// Settings panel for managing AI summarization prompts.
///
/// ## Layout
/// - Standard prompts section: read-only; shipped with the app; not editable or deletable.
/// - My Prompts section: user-created prompts; tap to edit; swipe to delete.
/// - "New Prompt" toolbar button opens `PromptEditorView` in create mode.
///
/// Each row shows the prompt name, output format badge, and the number of summaries
/// that have been generated using that prompt.
///
/// ## Log prefix
/// `[SummarizationUI]`
///
/// Version history:
///   1.0 — Session 20: initial implementation
struct PromptsListView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Query private var allSummaries: [GeneratedSummary]

    @State private var showNewPromptEditor = false
    @State private var promptToEdit: SummarizationPrompt? = nil

    private var standardPrompts: [SummarizationPrompt] {
        allPrompts.filter(\.isStandard)
    }

    private var userPrompts: [SummarizationPrompt] {
        allPrompts.filter { !$0.isStandard }
    }

    var body: some View {
        List {
            if !standardPrompts.isEmpty {
                Section(String(localized: "prompts.list.standard.header",
                               defaultValue: "Standard")) {
                    ForEach(standardPrompts) { prompt in
                        PromptRow(
                            prompt: prompt,
                            summaryCount: summaryCount(for: prompt)
                        )
                    }
                }
            }

            Section(String(localized: "prompts.list.user.header",
                           defaultValue: "My Prompts")) {
                if userPrompts.isEmpty {
                    Text(String(localized: "prompts.list.user.empty",
                                defaultValue: "No custom prompts yet. Tap + to create one."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(userPrompts) { prompt in
                        Button {
                            promptToEdit = prompt
                        } label: {
                            PromptRow(
                                prompt: prompt,
                                summaryCount: summaryCount(for: prompt)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteUserPrompts)
                }
            }
        }
        .navigationTitle(
            String(localized: "prompts.list.title", defaultValue: "Summarization Prompts")
        )
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewPromptEditor = true
                } label: {
                    Label(
                        String(localized: "prompts.list.toolbar.new",
                               defaultValue: "New Prompt"),
                        systemImage: "plus"
                    )
                }
                .accessibilityLabel(
                    String(localized: "prompts.list.toolbar.new.a11y",
                           defaultValue: "Create new prompt")
                )
            }
        }
        .sheet(isPresented: $showNewPromptEditor) {
            PromptEditorView(promptToEdit: nil)
        }
        .sheet(item: $promptToEdit) { prompt in
            PromptEditorView(promptToEdit: prompt)
        }
    }

    // MARK: - Helpers

    private func summaryCount(for prompt: SummarizationPrompt) -> Int {
        allSummaries.filter { $0.promptId == prompt.id }.count
    }

    private func deleteUserPrompts(at offsets: IndexSet) {
        for offset in offsets {
            let prompt = userPrompts[offset]
            modelContext.delete(prompt)
            #if DEBUG
            print("[SummarizationUI] Deleted prompt '\(prompt.name)'")
            #endif
        }
    }
}

// MARK: - PromptRow

private struct PromptRow: View {
    let prompt: SummarizationPrompt
    let summaryCount: Int

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(prompt.name)
                        .font(.body)
                    if prompt.isStandard {
                        Text(String(localized: "prompts.list.row.standard.badge",
                                    defaultValue: "Standard"))
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                HStack(spacing: 8) {
                    formatBadge
                    if summaryCount > 0 {
                        Text(summaryCountLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if !prompt.isStandard {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        // #312 follow-up: no frame needed — the Spacer already makes this HStack full width.
        // contentShape makes the gap between the name and the chevron tappable under
        // `.buttonStyle(.plain)`, which hit-tests only opaque content.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var formatBadge: some View {
        let label: String
        let color: Color
        switch prompt.responseFormat {
        case .general:
            label = String(localized: "prompts.list.row.format.general",
                           defaultValue: "General")
            color = .secondary
        case .structured:
            label = String(localized: "prompts.list.row.format.structured",
                           defaultValue: "Structured")
            color = .blue
        }
        return Text(label)
            .font(.caption)
            .foregroundStyle(color)
    }

    private var summaryCountLabel: String {
        summaryCount == 1
            ? String(localized: "prompts.list.row.summaryCount.singular",
                     defaultValue: "1 summary")
            : String(localized: "prompts.list.row.summaryCount.plural",
                     defaultValue: "\(summaryCount) summaries")
    }

    private var accessibilityLabel: String {
        let format: String
        switch prompt.responseFormat {
        case .general:  format = "general"
        case .structured: format = "structured"
        }
        let count = summaryCount == 0
            ? "no summaries"
            : summaryCount == 1 ? "1 summary" : "\(summaryCount) summaries"
        return "\(prompt.name), \(format) format, \(count)"
    }
}
