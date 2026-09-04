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

    /// Applies a one-tap preset (4a). Supplied by hosts that own the collection's entry list, so
    /// apparatus insertion goes through their `sortedEntries` management (never a model-direct write
    /// behind the outline's back). When `nil`, the Presets section is hidden.
    var onApplyPreset: ((CollectionPreset) -> Void)?

    /// Overrides the automatic compact-vs-regular preset layout choice (Composer v2). `nil` = auto
    /// (from the horizontal size class); `false` forces the 2×2 grid; `true` forces the short-chip
    /// row. The iPad ⚙ Collection sheet passes `false` because an iPadOS form sheet reports a compact
    /// size class yet is wide enough for the grid — and the chip row omits Scholarly edition.
    var presetsCompact: Bool?

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif
    /// Whether to render presets as the compact (iPhone) short-chip row rather than the 2×2 grid.
    /// A host override wins; otherwise the horizontal size class decides.
    private var isCompactPresets: Bool {
        if let presetsCompact { return presetsCompact }
        #if os(iOS)
        return hSizeClass == .compact
        #else
        return false
        #endif
    }

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
        // Composer v2: the three content-source sections carry colored icon-tile headers (blue
        // document / green annotations / orange analysis) with a one-line caption, and presets
        // render as a selectable card grid (2×2 regular / short-chip row compact) that marks the
        // active preset. Every underlying binding is unchanged; only the presentation is new.
        // Because this view emits its own `Section`s, hosts place it directly.

        // MARK: Presets — a one-tap starting composition. Applying one overwrites the composition
        // fields below and appends the preset's apparatus (never removing existing entries). Shown
        // only where a host wires `onApplyPreset` (which routes apparatus through its entry list).
        if let onApplyPreset {
            Section {
                presetPicker(onApplyPreset: onApplyPreset)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text(String(localized: "composition.presets.header",
                            defaultValue: "Start from a template — optional"))
            }
        }

        // MARK: Document content — how each document's text is carried into the export.
        Section {
            Picker(String(localized: "composition.bodyDepth", defaultValue: "Body depth"),
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
                            defaultValue: "Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Phase 5: the footnote tri-state picker became two independent toggles, so
            // "all footnotes AND the source note" is finally expressible.
            Toggle(String(localized: "composition.includeFootnotes",
                          defaultValue: "Footnotes"),
                   isOn: includeFootnotes)

            Toggle(String(localized: "composition.includeSourceNote",
                          defaultValue: "Archival source note"),
                   isOn: includeSourceNote)
        } header: {
            groupHeader(icon: "doc.text", tint: .blue,
                        title: String(localized: "composition.group.documentContent",
                                      defaultValue: "Document content"),
                        caption: String(localized: "composition.group.documentContent.help",
                                        defaultValue: "How much of each source to include."))
        }

        // MARK: Your annotations — the researcher's own notes and highlights.
        Section {
            Toggle(String(localized: "composition.includeNotes",
                          defaultValue: "Research notes"),
                   isOn: $collection.includeNotes)

            Toggle(String(localized: "composition.applyHighlights",
                          defaultValue: "Highlights in body"),
                   isOn: $collection.applyHighlights)
                .disabled(bodyDepth.wrappedValue != .full)

            // The collection-level headnote default (Composer redesign): documents at "Default"
            // inherit this. A per-document card overrides it (Show a summary above the document).
            Toggle(String(localized: "composition.defaultHeadnote",
                          defaultValue: "Headnotes"),
                   isOn: $collection.defaultIncludeHeadnote)
        } header: {
            groupHeader(icon: "note.text", tint: .green,
                        title: String(localized: "composition.group.annotations",
                                      defaultValue: "Your annotations"),
                        caption: String(localized: "composition.group.annotations.help",
                                        defaultValue: "Notes, highlights & headnotes — linked to each source."))
        }

        // MARK: Analysis & apparatus — generated overviews and the contents-list style. The five
        // generated apparatus blocks (chronology, indexes, bibliography) are per-entry rows managed
        // from the Apparatus menu / contents outline; a later phase surfaces them here as
        // present/insert controls.
        Section {
            Toggle(String(localized: "composition.includeWordCloud",
                          defaultValue: "Word-cloud overview"),
                   isOn: $collection.includeWordCloud)

            Picker(String(localized: "composition.tocStyle", defaultValue: "Contents list"),
                   selection: tocStyle) {
                ForEach(CollectionToCStyle.allCases) { Text($0.displayName).tag($0) }
            }
        } header: {
            groupHeader(icon: "chart.bar", tint: .orange,
                        title: String(localized: "composition.group.analysis",
                                      defaultValue: "Analysis & apparatus"),
                        caption: String(localized: "composition.group.analysis.help",
                                        defaultValue: "Generated overviews and the contents-list style."))
        }
    }

    // MARK: - Group header (Composer v2)

    /// A grouped-composition section header: a tinted icon tile + title + one-line caption,
    /// replacing the plain uppercase Form header. The three sections map 1:1 to the content
    /// sources (document content = blue, your annotations = green, analysis & apparatus = orange).
    @ViewBuilder
    private func groupHeader(icon: String, tint: Color, title: String, caption: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        // Override the Form section header's default uppercasing/caption styling.
        .textCase(nil)
        .padding(.vertical, 4)
    }

    // MARK: - Presets (Composer v2)

    /// The preset picker — a 2×2 selectable card grid on regular width, a horizontal short-chip
    /// row on compact (iPhone). The active preset (its recipe == the collection's current
    /// composition) is marked with the accent border.
    @ViewBuilder
    private func presetPicker(onApplyPreset: @escaping (CollectionPreset) -> Void) -> some View {
        if isCompactPresets {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(compactPresets) { preset in
                        presetChip(preset, onApplyPreset: onApplyPreset)
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(CollectionPreset.allCases) { preset in
                    presetCard(preset, onApplyPreset: onApplyPreset)
                }
            }
        }
    }

    /// The compact (iPhone) preset subset — Scholarly is omitted (too dense for the phone chip row).
    private var compactPresets: [CollectionPreset] {
        [.teachingReader, .briefingPacket, .sourceDossier]
    }

    /// One 2×2 preset card (regular width): name + subtitle, accent border/fill when active.
    @ViewBuilder
    private func presetCard(_ preset: CollectionPreset,
                            onApplyPreset: @escaping (CollectionPreset) -> Void) -> some View {
        let active = preset.matches(collection)
        Button {
            onApplyPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? Color.accentColor : .primary)
                Text(preset.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .padding(12)
            .background(active ? Color.accentColor.opacity(0.07) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(active ? Color.accentColor : Color.secondary.opacity(0.25),
                              lineWidth: active ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.displayName)
        .accessibilityValue(active
            ? String(localized: "composition.presets.active", defaultValue: "Active")
            : preset.subtitle)
        .accessibilityHint(String(localized: "composition.presets.applyHint",
                                  defaultValue: "Applies this composition. Everything stays editable afterward."))
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    /// One compact (iPhone) preset chip: short name + one-word tag, accent border when active.
    @ViewBuilder
    private func presetChip(_ preset: CollectionPreset,
                            onApplyPreset: @escaping (CollectionPreset) -> Void) -> some View {
        let active = preset.matches(collection)
        Button {
            onApplyPreset(preset)
        } label: {
            VStack(spacing: 1) {
                Text(preset.shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? Color.accentColor : .primary)
                Text(preset.shortTag)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(active ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.displayName)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
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

        Toggle(String(localized: "collection.attributes.projectProvenance",
                      defaultValue: "Stamp active project on export"),
               isOn: $collection.includeProjectProvenance)

        // M-2. The third surface. #617 added this toggle to `CollectionEditorView` only and #620
        // added it to `MacCollectionManagerView`; this view is the iOS/iPad document inspector's
        // copy, and it had the other two export toggles and not this one. Two `Text`s because it
        // is the only export option that puts the text of the researcher's own searches into a
        // document they may be about to publish.
        Toggle(isOn: $collection.includeMethodAppendix) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "collection.attributes.methodAppendix",
                            defaultValue: "Append the query log"))
                Text(String(localized: "collection.frontmatter.methodAppendix.subtitle",
                            defaultValue: "Every search you ran under the active project, with its scope and result count."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
