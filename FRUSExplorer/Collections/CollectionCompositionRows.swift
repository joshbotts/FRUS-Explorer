// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionCompositionRows

/// The editorial controls that determine *what an exported product contains* — persisted on
/// the `Collection` and edited in the manager (not the export sheet). Renders as a group of
/// form rows shared by the iOS editor (inside a `Section`) and the macOS manager (inside a
/// `DisclosureGroup`). Enum-backed fields are stored as raw-value strings on the model, so the
/// pickers bind through small mapping `Binding`s.
///
/// Edits apply **live** to the model, matching the iOS editor's other content edits (document
/// add/remove/reorder and smart-collection linkage) and the fully-live macOS manager. Only a
/// collection's name and note use the iOS editor's draft/Save step; composition, like the
/// document list itself, is not part of that draft.
///
/// Version history:
///   1.0 — Collections rework Phase 1a: composition moved out of the ephemeral export sheet
///   1.1 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.2 — Authoring Phase 5: the footnote tri-state picker replaced by two toggles bound
///          to `effectiveIncludeFootnotes`/`effectiveIncludeSourceNote` — "all footnotes
///          AND the source note" becomes expressible; writes keep `footnoteStyle` in sync
struct CollectionCompositionRows: View {

    /// The collection whose persisted composition is being edited.
    @Bindable var collection: Collection

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    private var bodyDepth: Binding<CollectionBodyDepth> {
        Binding(get: { CollectionBodyDepth(rawValue: collection.defaultBodyDepth) ?? .full },
                set: { collection.defaultBodyDepth = $0.rawValue })
    }

    /// Body-depth choices: those available on this device, plus the currently-persisted value
    /// even when it isn't otherwise offered here. A `"summaryOnly"` collection synced from a
    /// device with Apple Intelligence must still render with a selected row (and stay editable)
    /// on a device without it — otherwise the picker would show a blank selection.
    private var bodyDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        let current = bodyDepth.wrappedValue
        return available.contains(current) ? available : available + [current]
    }
    /// The effective "include footnotes" flag (Authoring Phase 5). Reads fall back to the
    /// legacy `footnoteStyle` derivation for untouched collections; writes persist the
    /// Bool pair and a best-fit `footnoteStyle` for old readers (see `Collection`).
    private var includeFootnotes: Binding<Bool> {
        Binding(get: { collection.effectiveIncludeFootnotes },
                set: { collection.effectiveIncludeFootnotes = $0 })
    }
    /// The effective "include archival source note" flag (Authoring Phase 5). Same
    /// derivation/write-through semantics as `includeFootnotes`.
    private var includeSourceNote: Binding<Bool> {
        Binding(get: { collection.effectiveIncludeSourceNote },
                set: { collection.effectiveIncludeSourceNote = $0 })
    }
    private var tocStyle: Binding<CollectionToCStyle> {
        Binding(get: { CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation },
                set: { collection.tocStyle = $0.rawValue })
    }

    var body: some View {
        Picker(String(localized: "composition.bodyDepth", defaultValue: "Document body"),
               selection: bodyDepth) {
            ForEach(bodyDepthOptions) { Text($0.displayName).tag($0) }
        }

        if bodyDepth.wrappedValue == .summaryOnly {
            Picker(String(localized: "composition.summaryPrompt", defaultValue: "Summary prompt"),
                   selection: Binding(get: { collection.summaryPromptId },
                                      set: { collection.summaryPromptId = $0 })) {
                Text(String(localized: "composition.summaryPrompt.none", defaultValue: "Select…"))
                    .tag(UUID?.none)
                ForEach(allPrompts) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            Text(String(localized: "composition.summaryPrompt.hint",
                        defaultValue: "Summaries are generated on demand for documents that don't already have one for this prompt. Requires Apple Intelligence."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Phase 5: the footnote tri-state picker became two independent toggles, so
        // "all footnotes AND the source note" is finally expressible.
        Toggle(String(localized: "composition.includeFootnotes",
                      defaultValue: "Include footnotes"),
               isOn: includeFootnotes)

        Toggle(String(localized: "composition.includeSourceNote",
                      defaultValue: "Include archival source note"),
               isOn: includeSourceNote)

        Picker(String(localized: "composition.tocStyle", defaultValue: "Contents list"),
               selection: tocStyle) {
            ForEach(CollectionToCStyle.allCases) { Text($0.displayName).tag($0) }
        }

        Toggle(String(localized: "composition.applyHighlights",
                      defaultValue: "Apply highlights to document body"),
               isOn: $collection.applyHighlights)
            .disabled(bodyDepth.wrappedValue != .full)

        Toggle(String(localized: "composition.includeNotes",
                      defaultValue: "Include research notes"),
               isOn: $collection.includeNotes)

        Toggle(String(localized: "composition.includeWordCloud",
                      defaultValue: "Include word-cloud overview (PDF and HTML)"),
               isOn: $collection.includeWordCloud)
    }
}
