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
///   1.4 — 2026-11-18 (L25, decision 139): six templates in place of four, so the grid has three
///          rows of two, and the compact chip row shows all six (it scrolls; `compactPresets`, which
///          left Scholarly edition out, is gone). The grid is rows of two held to their taller card's
///          height, and a card's subtitle takes up to three lines, which the Mac's popover needs
///   1.5 — L43: the collection's own facts, each a plain control that L44 then trims: *Opening* and *See also* in
///          Document content, and a fourth section, Citations & wording, with *Citation style* and the ten labels'
///          words (`CollectionWording`)
struct CollectionCompositionRows: View {

    /// The collection whose persisted composition is being edited.
    @Bindable var collection: Collection

    /// Applies a one-tap preset (4a). Supplied by hosts that own the collection's entry list, so
    /// apparatus insertion goes through their `sortedEntries` management (never a model-direct write
    /// behind the outline's back). When `nil`, the Presets section is hidden.
    var onApplyPreset: ((CollectionPreset) -> Void)?

    /// Overrides the automatic compact-vs-regular preset layout choice (Composer v2). `nil` = auto
    /// (from the horizontal size class); `false` forces the card grid; `true` forces the short-chip
    /// row. The iPad ⚙ Collection sheet passes `false` because an iPadOS form sheet reports a compact
    /// size class yet is wide enough for the grid, whose cards give each template's name and subtitle.
    var presetsCompact: Bool?

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif
    /// Whether to render presets as the compact (iPhone) short-chip row rather than the card grid.
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

    /// The collection's citation style (L43): its stored raw value, which reads as History at State where it is unset
    /// or unknown. Writes the chosen style's raw value, never `nil`.
    private var citationStyle: Binding<CitationStyle> {
        Binding(get: { collection.citationStyle.flatMap(CitationStyle.init(rawValue:)) ?? .historyAtState },
                set: { collection.citationStyle = $0.rawValue })
    }

    /// Which line leads a document with no title of the author's (L43): the citation, which an unset collection's
    /// reads as, or the volume's heading.
    private var opening: Binding<CollectionDocumentPlan.Opening> {
        Binding(get: { collection.opening == CollectionDocumentPlan.Opening.volumeHeading.rawValue
                        ? .volumeHeading : .citation },
                set: { collection.opening = $0.rawValue })
    }

    /// One label's word in the collection's wording (L43): the collection's own, or empty, which the field shows as
    /// the app's word. Writing the stored map keeps every other pair, a later build's among them.
    private func wording(_ label: CollectionWording.Label) -> Binding<String> {
        Binding(get: { CollectionWording(json: collection.labelsJSON).ownWord(for: label) ?? "" },
                set: { collection.labelsJSON = CollectionWording.updating(collection.labelsJSON, label: label, with: $0) })
    }

    /// The two openings a collection offers, with the words its picker shows.
    static func openingName(_ opening: CollectionDocumentPlan.Opening) -> String {
        switch opening {
        case .volumeHeading:
            return String(localized: "composition.opening.volumeHeading", defaultValue: "The volume’s heading leads")
        case .citation, .title:
            return String(localized: "composition.opening.citation", defaultValue: "The citation leads")
        }
    }

    var body: some View {
        // Composer v2: the three content-source sections carry colored icon-tile headers (blue
        // document / green annotations / orange analysis) with a one-line caption, and presets
        // render as a selectable card grid (three rows of two regular / short-chip row compact) that
        // marks the active preset. Every underlying binding is unchanged; only the presentation is new.
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
            // L43: which line leads a document with no title of the author's (the design's §3.3).
            Picker(String(localized: "composition.opening", defaultValue: "Opening"), selection: opening) {
                ForEach([CollectionDocumentPlan.Opening.volumeHeading, .citation], id: \.self) {
                    Text(Self.openingName($0)).tag($0)
                }
            }
            .accessibilityIdentifier("composition.opening.picker")

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

            // L43: See also for the collection (decision 164's sixth candidate), which a section or a document may set
            // for itself.
            Toggle(isOn: $collection.defaultIncludeRelatedDocuments) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "composition.seeAlso", defaultValue: "See also"))
                    Text(String(localized: "composition.seeAlso.subtitle",
                                defaultValue: "Under each document, the documents it cites that are also in this collection."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("composition.seeAlso.toggle")
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

        // MARK: Citations & wording (L43) — the style every citation prints in, and the collection's own words for
        // the labels its exports print.
        Section {
            Picker(String(localized: "composition.citationStyle", defaultValue: "Citation style"),
                   selection: citationStyle) {
                ForEach(CitationStyle.allCases) { Text($0.displayName).tag($0) }
            }
            .accessibilityIdentifier("composition.citationStyle.picker")

            DisclosureGroup {
                ForEach(CollectionWording.Label.allCases, id: \.self) { label in
                    wordingRow(label)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "composition.wording", defaultValue: "Wording"))
                    Text(String(localized: "composition.wording.subtitle",
                                defaultValue: "Your own words for the labels an export prints. A word left empty prints the app’s."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // On the header alone: on the group, SwiftUI gives it to the fields inside, in place of their own.
                .accessibilityIdentifier("composition.wording.group")
            }
        } header: {
            groupHeader(icon: "quote.opening", tint: .purple,
                        title: String(localized: "composition.group.citations",
                                      defaultValue: "Citations & wording"),
                        caption: String(localized: "composition.group.citations.help",
                                        defaultValue: "The style every citation prints in, and the export’s labels."))
        }
    }

    /// One label's row in Wording (L43): the app's word, and a field for the collection's own, which shows the app's
    /// word until one is typed. VoiceOver reads the label's name and the word the export prints.
    @ViewBuilder
    private func wordingRow(_ label: CollectionWording.Label) -> some View {
        HStack {
            Text(label.appWord)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(text: wording(label), prompt: Text(label.appWord)) {
                Text(label.appWord)
            }
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(String(format: String(localized: "composition.wording.field.accessibility %@",
                                                      defaultValue: "%@, printed as"), label.appWord))
            .accessibilityValue(CollectionWording(json: collection.labelsJSON).text(for: label))
            .accessibilityIdentifier("composition.wording.field.\(label.rawValue)")
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

    /// The preset picker — a selectable card grid of two columns on regular width (the six templates
    /// in three rows), a horizontal short-chip row on compact (iPhone), which shows all six and
    /// scrolls. The active preset (its recipe == the collection's current composition) is marked
    /// with the accent border.
    @ViewBuilder
    private func presetPicker(onApplyPreset: @escaping (CollectionPreset) -> Void) -> some View {
        if isCompactPresets {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CollectionPreset.allCases) { preset in
                        presetChip(preset, onApplyPreset: onApplyPreset)
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            // Rows of two, each an `HStack` held to its ideal height, which is its taller card's at the
            // card's own width; each card's frame then fills the row, so both boxes of a row are one
            // height (L25). A `LazyVGrid` sized each card to its own text, so a one-line name beside a
            // two-line one drew boxes of 76 and 89 pt in one row on the Mac; a `Grid` evened the rows
            // but settled their height before a name wrapped at the column's width, and cut the name.
            VStack(spacing: 8) {
                ForEach(Self.presetRows, id: \.self) { row in
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(row) { preset in
                            presetCard(preset, onApplyPreset: onApplyPreset)
                        }
                        if row.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The templates in the grid's rows of two, in `CollectionPreset.allCases`' order.
    private static let presetRows: [[CollectionPreset]] = stride(from: 0, to: CollectionPreset.allCases.count, by: 2).map {
        Array(CollectionPreset.allCases[$0..<min($0 + 2, CollectionPreset.allCases.count)])
    }

    /// One preset card (regular width): name + subtitle, accent border/fill when active.
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
                // Three lines: the Mac's ⚙ popover, 420 pt wide, gives a card about 155 pt of text, and
                // "Notes · highlights · headnotes · chronology · persons" needs three there (L25).
                Text(preset.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity, alignment: .topLeading)
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
/// Edits apply **live** to the model, and each is **saved** as it is made — every field's and toggle's binding writes
/// the collection and then saves the context that holds it — so closing the app straight after an edit here loses
/// nothing, as it loses nothing typed in the collection editor's own settings (#1415). Before, these rows left the save
/// to the app's autosave; the one incidental save they used to get, the editor's old `saveLive()` run from its flag
/// follow, went with #1413. The introduction *prose* is deliberately excluded — it is authored in the main editor's
/// front-matter area (a rich-text editor with nil-on-empty save semantics), not an attribute.
///
/// Version history:
///   1.0 — Collections editor UX (#188-E): persistent collection-attributes inspector section
///   1.1 — MACCOL (the plan of record's "Section defaults save each write"): every edit is saved as it is made
///         (`optional(_:)`, `saving(_:)`)
struct CollectionAttributesRows: View {

    /// The collection whose identity attributes are being edited.
    @Bindable var collection: Collection

    /// Binds an optional string field, persisting `nil` when the text is emptied so exporters
    /// treat "cleared" the same as "never set", and saving each edit.
    private func optional(_ keyPath: ReferenceWritableKeyPath<Collection, String?>) -> Binding<String> {
        Binding(get: { collection[keyPath: keyPath] ?? "" },
                set: { collection[keyPath: keyPath] = $0.isEmpty ? nil : $0; save() })
    }

    /// Binds one of the collection's export toggles, saving each switch.
    private func saving(_ keyPath: ReferenceWritableKeyPath<Collection, Bool>) -> Binding<Bool> {
        Binding(get: { collection[keyPath: keyPath] },
                set: { collection[keyPath: keyPath] = $0; save() })
    }

    /// Saves the context that holds the collection, so the edit just written survives the app being closed.
    private func save() {
        try? collection.modelContext?.save()
    }

    var body: some View {
        // The identifiers are for `CollectionEditorTitleTests` (#1413), which types here from a heading's sheet.
        TextField(String(localized: "collection.attributes.note", defaultValue: "Description"),
                  text: optional(\.note), axis: .vertical)
            .lineLimit(1...3)
            .accessibilityIdentifier("collection.attributes.note.field")

        TextField(String(localized: "collection.attributes.subtitle", defaultValue: "Subtitle"),
                  text: optional(\.subtitle))
            .accessibilityIdentifier("collection.attributes.subtitle.field")

        TextField(String(localized: "collection.attributes.author", defaultValue: "Author line"),
                  text: optional(\.authorLine))
            .accessibilityIdentifier("collection.attributes.author.field")

        Toggle(String(localized: "collection.attributes.colophon",
                      defaultValue: "Append colophon page on export"),
               isOn: saving(\.includeColophon))
            .accessibilityIdentifier("collection.attributes.colophon.toggle")

        Toggle(String(localized: "collection.attributes.projectProvenance",
                      defaultValue: "Stamp active project on export"),
               isOn: saving(\.includeProjectProvenance))

        // M-2. The third surface. #617 added this toggle to `CollectionEditorView` only and #620
        // added it to `MacCollectionManagerView`; this view is the iOS/iPad document inspector's
        // copy, and it had the other two export toggles and not this one. Two `Text`s because it
        // is the only export option that puts the text of the researcher's own searches into a
        // document they may be about to publish.
        Toggle(isOn: saving(\.includeMethodAppendix)) {
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
