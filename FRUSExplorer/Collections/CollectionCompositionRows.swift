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
///   1.3 — Composer redesign Phase 1: the flat row list becomes three labeled `Section`s
///          (Document content / Your annotations / Analysis & apparatus) with a one-line
///          helper each. The view now OWNS its sections, so hosts place it directly rather
///          than wrapping it in their own Section/DisclosureGroup. Bindings are unchanged.
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
        // Composer redesign: the flat composition list is regrouped into three labeled sections
        // mapping 1:1 to the three content sources — document content, the user's annotations, and
        // generated analysis/apparatus — each with a one-line helper. Every underlying binding is
        // unchanged; only the grouping is new. Because this view now emits its own `Section`s, every
        // host places it directly (no wrapping Section/DisclosureGroup of its own).

        // MARK: Document content — how each document's text is carried into the export.
        Section {
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
        } header: {
            Text(String(localized: "composition.group.documentContent",
                        defaultValue: "Document content"))
        } footer: {
            Text(String(localized: "composition.group.documentContent.help",
                        defaultValue: "How each document's text is included — its depth, footnotes, and the archival source note."))
        }

        // MARK: Your annotations — the researcher's own notes and highlights.
        Section {
            Toggle(String(localized: "composition.includeNotes",
                          defaultValue: "Include research notes"),
                   isOn: $collection.includeNotes)

            Toggle(String(localized: "composition.applyHighlights",
                          defaultValue: "Apply highlights to document body"),
                   isOn: $collection.applyHighlights)
                .disabled(bodyDepth.wrappedValue != .full)

            // The collection-level headnote default (Composer redesign): documents at "Default"
            // inherit this. A per-document card overrides it (Show a summary above the document).
            Toggle(String(localized: "composition.defaultHeadnote",
                          defaultValue: "Headnotes"),
                   isOn: $collection.defaultIncludeHeadnote)
        } header: {
            Text(String(localized: "composition.group.annotations",
                        defaultValue: "Your annotations"))
        } footer: {
            Text(String(localized: "composition.group.annotations.help",
                        defaultValue: "Your research notes and highlights, and a headnote summary above each document. Highlights apply to full-text documents only."))
        }

        // MARK: Analysis & apparatus — generated overviews and the contents-list style. The five
        // generated apparatus blocks (chronology, indexes, bibliography) are per-entry rows managed
        // from the Apparatus menu / contents outline; a later phase surfaces them here as
        // present/insert controls.
        Section {
            Toggle(String(localized: "composition.includeWordCloud",
                          defaultValue: "Include word-cloud overview (PDF and HTML)"),
                   isOn: $collection.includeWordCloud)

            Picker(String(localized: "composition.tocStyle", defaultValue: "Contents list"),
                   selection: tocStyle) {
                ForEach(CollectionToCStyle.allCases) { Text($0.displayName).tag($0) }
            }
        } header: {
            Text(String(localized: "composition.group.analysis",
                        defaultValue: "Analysis & apparatus"))
        } footer: {
            Text(String(localized: "composition.group.analysis.help",
                        defaultValue: "Generated overviews and how the contents list is styled. Add chronologies and indexes from the Apparatus menu."))
        }
    }
}

// MARK: - CollectionAttributesRows

/// The collection's identity / title-page attributes — its one-line note, subtitle, author
/// line, and colophon toggle — as a drop-in group of form rows (mirroring
/// `CollectionCompositionRows`). Surfaced at the top of the per-entry inspector (#188-E) so
/// these collection-level values stay reachable after the researcher focuses a document.
///
/// Edits apply **live** to the model via `@Bindable`, matching `CollectionCompositionRows`.
/// The introduction *prose* is deliberately excluded — it is authored in the main editor's
/// front-matter area (a rich-text editor with nil-on-empty save semantics), not an attribute.
///
/// Version history:
///   1.0 — Collections editor UX (#188-E): persistent collection-attributes inspector section
struct CollectionAttributesRows: View {

    /// The collection whose identity attributes are being edited.
    @Bindable var collection: Collection

    /// Binds an optional string field, persisting `nil` when the text is emptied so exporters
    /// treat "cleared" the same as "never set".
    private func optional(_ keyPath: ReferenceWritableKeyPath<Collection, String?>) -> Binding<String> {
        Binding(get: { collection[keyPath: keyPath] ?? "" },
                set: { collection[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        TextField(String(localized: "collection.attributes.note", defaultValue: "Description"),
                  text: optional(\.note), axis: .vertical)
            .lineLimit(1...3)

        TextField(String(localized: "collection.attributes.subtitle", defaultValue: "Subtitle"),
                  text: optional(\.subtitle))

        TextField(String(localized: "collection.attributes.author", defaultValue: "Author line"),
                  text: optional(\.authorLine))

        Toggle(String(localized: "collection.attributes.colophon",
                      defaultValue: "Append colophon page on export"),
               isOn: $collection.includeColophon)
    }
}
