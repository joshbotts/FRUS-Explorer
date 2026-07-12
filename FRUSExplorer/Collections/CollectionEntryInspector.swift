// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import SwiftData

// MARK: - CollectionEntryInspector

/// The **per-entry control surface** for one collection entry (Authoring Phase 5): its
/// identity (header, volume), the user's own annotations for it (research notes,
/// highlights, tags, AI summary), its archival provenance (source note, cross-reference
/// count), the headnote controls, and the per-entry **export overrides** — highlights
/// (with per-highlight selection, A8), research notes, source note, footnotes, summary
/// prompt, and the related-documents line (A10). Every override is optional: "Default"
/// inherits the nearest ancestor heading's section default, else the collection setting
/// — resolved in exactly one place, `CollectionContentResolver`.
///
/// A **heading entry** presented here shows the section-defaults variant instead: the
/// same override controls, applied to every document the section owns (unless a
/// document sets its own).
///
/// Opened from an entry row so the manager is a place to *see* — and now *shape* — the
/// full range of document-level data while composing. It reuses the app's existing
/// stores (`CrossReferenceStore`, `IndexingPipeline`, SwiftData) and reads no new data.
///
/// Version history:
///   1.0 — Collections rework Phase 2: editorial data surface
///   1.1 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.2 — Authoring Phase 5: the "first non-empty summary" display became prompt-aware
///          (prefers the collection's `summaryPromptId`, labels the producing prompt);
///          new Headnote section — toggle `includeHeadnote` and pick the
///          `GeneratedSummary` (`headnoteSummaryId`) rendered above the body in exports
///   1.3 — Authoring Phase 5 (excerpts): the highlight count became a highlight *list*
///          (colour chip + passage preview) with a per-highlight "Insert as Excerpt"
///          action (creation path c) — the capture is handed to the presenting editor
///          via `onInsertExcerpt`, which appends through the shared `CollectionExcerpts`
///          factory; highlights without stored text stay listed but not insertable
///   1.4 — Authoring Phase 5 (read-write inspector): the Export Overrides section
///          (highlights / notes / source note / footnotes / summary prompt / related
///          documents, each Default-On-Off), per-highlight include checkboxes writing
///          `selectedHighlightIds` (empty = all; unselecting every passage turns
///          highlights off for the entry, since the empty set means "all"), the
///          excerpts-in-this-collection list, and the heading (section-defaults)
///          variant. Honesty audit: the footnote override carries a caption naming its
///          real reach (HTML exports + preview; PDF/DOCX footnotes are ungated — a
///          pre-existing gap), and tags keep reading as data, not a control
///   1.5 — Footnote gate closed in PDF/DOCX (owner decision 2026-07-03): the honesty
///          caption under the footnote override is gone — the setting now gates all
///          three export formats and the preview, so there is no gap left to disclose
///   1.6 — Session 2026-07-04 (macOS UI audit B8): `isInspectorColumn` presentation
///          flag — the macOS Collections manager now hosts this view in a trailing
///          `.inspector` column (sized via `inspectorColumnWidth` instead of the
///          sheet's min-size frame) so the outline stays visible and editable while
///          overrides and "Insert as Excerpt" act on it; the sheet presentations
///          (iOS/iPad, shared heading row) are unchanged
///   1.7 — Collections Manager M2 (D3/D5): the inspector is now the single per-entry
///          edit surface. It absorbs the **body-depth Picker** (leading Export Overrides
///          as the parent gate the rest refine — moved verbatim from the reporting rows)
///          and gains **per-note include toggles** (D5, empty = all, mirroring the
///          per-highlight checkboxes and `setHighlightIncluded`) co-located with the
///          Research-notes whether-gate, plus the "New Note…" affordance threaded from
///          the editors via `onNewNote`. The reporting rows now show read-only status
///          chips only
///   1.8 — Collections Manager M3 (D4): the identity section gains a **title-override**
///          `TextField` — one field driving both the ToC label and the export heading —
///          showing the derived default (`derivedTitlePlaceholder`) as placeholder;
///          clearing it restores the derived title (empty → `nil`). Document-only; the
///          heading variant is unchanged (a section edits its title inline via its row).
///          M3 review finding 1: the placeholder now resolves the true history.state.gov
///          citation (`resolvedCitation`, from manifest volume metadata + document number)
///          so it shows exactly what `exportHeading` produces when the field is blank —
///          previously it showed the source-note header, which `exportHeading` never uses
struct CollectionEntryInspector: View {

    /// One highlight row offered for excerpt insertion (Authoring Phase 5).
    private struct HighlightChoice: Identifiable {
        /// The source highlight's id — row identity only, never serialized.
        let id: UUID
        /// The ready-to-insert capture; `nil` when the highlight has no stored text
        /// (pre-Session-131), which leaves the row visible but not insertable.
        let capture: CollectionExcerptCapture?
        /// The highlight's colour, for the row chip.
        let color: DocumentHighlight.Color
    }

    /// One summarization prompt offered by the summary-prompt override picker.
    private struct PromptChoice: Identifiable {
        /// The `SummarizationPrompt.id`.
        let id: UUID
        /// The prompt's display name.
        let name: String
    }

    /// One research note offered by the per-note include toggles (D5). Row identity is
    /// the note's id (also the `selectedNoteIds` element); the preview is its first line.
    private struct NoteChoice: Identifiable {
        /// The `ResearchNote.id` — row identity and the `selectedNoteIds` element.
        let id: UUID
        /// A short single-line preview of the note body, or the untitled fallback.
        let preview: String
    }

    /// The inspector's top-level segment (Composer redesign 2b): the per-document surface or the
    /// whole-collection composition. Selected by the `Document | Composition` segmented control.
    private enum InspectorTab: Hashable {
        case document
        case composition
    }

    /// The entry whose document is being inspected.
    let entry: CollectionEntry

    /// Appends an excerpt entry to the owning collection (Authoring Phase 5, creation
    /// path c) — supplied by the presenting editor so its entry list stays in sync.
    /// `nil` (e.g. a future read-only presentation) hides the insert buttons.
    var onInsertExcerpt: ((CollectionExcerptCapture) -> Void)? = nil

    /// Creates a new `ResearchNote` for this document and links it to the entry (D5) —
    /// supplied by the presenting editor (it owns the note-create sheet + entry list).
    /// `nil` (the heading variant, or a future read-only presentation) hides the
    /// "New Note…" affordance in the per-note include list.
    var onNewNote: (() -> Void)? = nil

    /// Whether this presentation is the macOS Collections manager's trailing
    /// `.inspector` column (UI audit B8) rather than a sheet. In the column the
    /// sheet's min-size frame is replaced by `inspectorColumnWidth` sizing; the Done
    /// button stays (its `dismiss` closes the inspector column). Defaults to `false`
    /// — the iOS/iPad sheets and the shared heading-row sheet are unaffected.
    var isInspectorColumn: Bool = false

    /// Whether to show the **Document | Composition** segmented control at the top of the inspector
    /// (Composer redesign 2b). The iPad `.inspector` host passes `true` (regular width) so the
    /// researcher can flip between this document's surface and the whole-collection composition; the
    /// iPhone sheet, the Mac column, and the heading-row sheet keep the flat pinned layout (`false`),
    /// pending their own host restructures (Phase 4). Ignored for a heading entry (no document).
    var showsCompositionSegment: Bool = false

    /// Whether the flat pinned layout includes the collection-level **Collection** settings section
    /// (name / note / front matter / composition). `true` for the iPhone sheet and Mac column (the
    /// pinned #188-E section); `false` for the Composer v2 iPad **Configure** sheet, which is
    /// document-only because collection settings live in a separate ⚙ Collection sheet. Ignored when
    /// the segmented control is shown.
    var showsCollectionSettings: Bool = true

    /// Applies a one-tap composition preset (4a), threaded from the host so apparatus insertion goes
    /// through its entry-list management. Passed on to `CollectionCompositionRows`; when `nil` the
    /// embedded composition shows no Presets section.
    var onApplyPreset: ((CollectionPreset) -> Void)?

    /// Whether this is presented as a **drill-in push** onto an existing navigation stack (iPhone,
    /// Composer redesign 4). When `true` the inspector omits its own `NavigationStack` and Done
    /// button — the pushing stack's back button dismisses it. Defaults to `false` (sheet / macOS
    /// inspector column), which keeps the self-contained stack + Done.
    var isPushed: Bool = false

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var header: String?
    @State private var volumeTitle = ""
    /// The resolved history.state.gov citation for this document, mirroring the resolver's
    /// derivation (manifest volume metadata + document number via
    /// `HistoryAtStateCitationFormatter`). Backs the title-override placeholder so it shows
    /// the real export-heading fallback (M3, finding 1); empty until `load()` resolves it.
    @State private var resolvedCitation = ""
    @State private var sourceNote: String?
    @State private var summaryPreview: String?
    @State private var summaryPromptName: String?
    /// The editable-headnote card's draft buffer + edit mode (Composer redesign).
    @State private var headnoteDraft: String = ""
    @State private var isEditingHeadnote = false
    /// Drives the Regenerate control's in-progress spinner + re-entrancy guard, and surfaces a
    /// user-facing failure inline in the card (Composer redesign 2c-2c Regenerate).
    @State private var isRegenerating = false
    @State private var regenError: String?
    /// The inspector's top-level segment when `showsCompositionSegment` (Composer redesign 2b):
    /// this document's surface, or the whole-collection composition. View-state only, never
    /// persisted; reset per entry because the inspector is recreated via `.id(entry.id)`.
    @State private var inspectorTab: InspectorTab = .document
    @State private var noteTexts: [String] = []
    /// The document's research notes as include-toggle rows (D5).
    @State private var noteChoices: [NoteChoice] = []
    @State private var tags: [String] = []
    @State private var highlightCount = 0
    /// The document's highlights as insertable rows (Authoring Phase 5).
    @State private var highlightChoices: [HighlightChoice] = []
    /// Ids of highlights inserted as excerpts during this presentation — feedback only.
    @State private var insertedHighlightIds: Set<UUID> = []
    @State private var crossRefCount = 0
    @State private var isLoading = true
    /// The summarization prompts offered by the summary-prompt override picker.
    @State private var promptChoices: [PromptChoice] = []

    /// Whether this presentation is the heading (section-defaults) variant.
    private var isHeading: Bool { entry.entryKind == .heading }

    /// The inspector's navigation title: the owning collection's name (#188-E), so the
    /// researcher always sees which collection they're editing. Falls back to the generic
    /// "Document Details" / "Section Details" role when the collection has no name yet.
    private var collectionDisplayTitle: String {
        let name = entry.collection?.name ?? ""
        guard !name.isEmpty else {
            return isHeading
                ? String(localized: "collection.inspector.section.title", defaultValue: "Section Details")
                : String(localized: "collection.inspector.title", defaultValue: "Document Details")
        }
        return name
    }

    /// The pinned collection-level attributes section (#188-E). Sourced from the entry's owning
    /// collection (the SwiftData inverse relationship), so no call-site threading is needed.
    /// Shows the collection's identity attributes and its export-composition defaults, both
    /// edited live via `@Bindable` — reusing `CollectionAttributesRows` / `CollectionCompositionRows`.
    @ViewBuilder
    private var collectionSection: some View {
        if let collection = entry.collection {
            Section {
                CollectionAttributesRows(collection: collection)
            } header: {
                Text(String(localized: "collection.inspector.collection.header",
                            defaultValue: "Collection"))
            } footer: {
                Text(String(localized: "collection.inspector.collection.footer",
                            defaultValue: "These settings apply to the whole collection."))
            }
            // `CollectionCompositionRows` owns its three labeled Composer sections, so it is placed
            // directly here rather than wrapped in a single "Export composition" section.
            CollectionCompositionRows(collection: collection, onApplyPreset: onApplyPreset)
        }
    }

    var body: some View {
        if isInspectorColumn {
            // Inspector-column presentation (macOS Collections manager, B8): the
            // column's width is negotiated with the split view, not forced by the
            // sheet's fixed minimum frame.
            inspectorBody
                .inspectorColumnWidth(min: 340, ideal: 420, max: 560)
        } else {
            inspectorBody
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 480)
                #endif
        }
    }

    /// The shared presentation body. As a sheet or macOS inspector column it hosts the sectioned
    /// list in its own `NavigationStack` with a Done button; as an iPhone drill-in **push**
    /// (`isPushed`) it omits both, letting the pushing stack's back button dismiss it.
    @ViewBuilder private var inspectorBody: some View {
        if isPushed {
            inspectorList
        } else {
            NavigationStack { inspectorList }
        }
    }

    /// The sectioned inspector list + its title, Done button (sheet/column only), and load task.
    private var inspectorList: some View {
        List {
            if showsCompositionSegment && !isHeading {
                // Composer redesign 2b (iPad): the top segmented control splits the pinned flat
                // layout into this document's surface vs. the whole-collection composition.
                segmentPickerRow
                switch inspectorTab {
                case .document:
                    documentSections
                case .composition:
                    collectionSection
                }
            } else {
                // Flat pinned layout (iPhone sheet, Mac column, heading rows): collection-level
                // attributes stay reachable above the per-entry sections (#188-E) — unless the host
                // owns them elsewhere (Composer v2 iPad: composition is its own ⚙ Collection sheet,
                // so the per-row Configure sheet is document-only).
                if showsCollectionSettings {
                    collectionSection
                }
                if isHeading {
                    headingIdentitySection
                    sectionDefaultsSection
                } else {
                    documentSections
                }
            }
        }
        .navigationTitle(collectionDisplayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !isPushed {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    /// The `Document | Composition` segmented control pinned at the top of the inspector (Composer
    /// redesign 2b). Styled as a clear-backed row so it reads as a top-level switch rather than a
    /// boxed list cell.
    @ViewBuilder private var segmentPickerRow: some View {
        Picker(selection: $inspectorTab) {
            Text(String(localized: "collection.inspector.tab.document", defaultValue: "Document"))
                .tag(InspectorTab.document)
            Text(String(localized: "collection.inspector.tab.composition", defaultValue: "Composition"))
                .tag(InspectorTab.composition)
        } label: {
            Text(String(localized: "collection.inspector.tab.label", defaultValue: "Inspector view"))
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// The per-document sections (identity → provenance), shared by the flat pinned layout and the
    /// segmented `Document` tab. The loading placeholder stands in until `load()` resolves.
    @ViewBuilder private var documentSections: some View {
        identitySection
        if isLoading {
            Section {
                HStack {
                    ProgressView()
                    Text(String(localized: "collection.inspector.loading",
                                defaultValue: "Loading document details…"))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            annotationsSection
            overridesSection
            headnoteSection
            excerptsSection
            provenanceSection
        }
    }

    private var identitySection: some View {
        Section {
            if let header, !header.isEmpty {
                Text(header).font(.headline).textSelection(.enabled)
            }
            LabeledContent(String(localized: "collection.inspector.document", defaultValue: "Document"),
                           value: entry.documentId)
            LabeledContent(String(localized: "collection.inspector.volume", defaultValue: "Volume"),
                           value: volumeTitle.isEmpty ? entry.volumeId : volumeTitle)
            // M3 (D4): the per-document title override — one field driving BOTH the
            // collection ToC label and the top-of-document export heading. The derived
            // default shows as placeholder; clearing the field restores it (empty → nil).
            // Document-only — the heading variant edits its title inline via its row.
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    String(localized: "collection.inspector.titleOverride",
                           defaultValue: "Title override"),
                    text: Binding(
                        get: { entry.titleOverride ?? "" },
                        set: { entry.titleOverride = $0.isEmpty ? nil : $0 }),
                    prompt: Text(derivedTitlePlaceholder)
                )
                Text(String(localized: "collection.inspector.titleOverride.caption",
                            defaultValue: "Overrides the document title in the table of contents and the export heading. Leave blank to use the derived title."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// The derived default title shown as the override field's placeholder — the exact
    /// value `CollectionExportDocument.exportHeading` produces when `titleOverride` is nil:
    /// the resolved history.state.gov citation when non-empty, else `"{volumeTitle} —
    /// {documentId}"` (the resolver's `"{volumeId}/{documentId}"`-style fallback, shown here
    /// with the friendly volume title). This mirrors `exportHeading`'s real precedence
    /// (`citation.isEmpty ? title : citation`), which never consults the source-note header,
    /// so an author sees exactly what leaving the field blank will produce.
    private var derivedTitlePlaceholder: String {
        if !resolvedCitation.isEmpty { return resolvedCitation }
        let vol = volumeTitle.isEmpty ? entry.volumeId : volumeTitle
        return "\(vol) — \(entry.documentId)"
    }

    /// Identity for the heading (section-defaults) variant.
    private var headingIdentitySection: some View {
        Section {
            LabeledContent(String(localized: "collection.inspector.section.heading",
                                  defaultValue: "Section"),
                           value: (entry.text?.isEmpty == false)
                               ? (entry.text ?? "")
                               : String(localized: "collection.inspector.section.untitled",
                                        defaultValue: "Untitled section"))
        }
    }

    @ViewBuilder private var annotationsSection: some View {
        Section(String(localized: "collection.inspector.yourData", defaultValue: "Your Annotations")) {
            // Per-note include toggles (D5): identical in shape to the per-highlight
            // rows below — a checkbox (macOS) / switch (iOS) + note preview. An empty
            // `selectedNoteIds` means **all**, so every row reads checked until the
            // user deselects one; unchecking the last note turns notes off for the
            // entry (empty can't mean "none"). Co-located with the whether-gate (the
            // Research-notes Default/On/Off picker in Export Overrides) so which +
            // whether are visible together.
            if noteChoices.isEmpty {
                Label(String(localized: "collection.inspector.noNotes", defaultValue: "No research notes"),
                      systemImage: "note.text")
                    .foregroundStyle(.secondary).font(.callout)
            } else {
                ForEach(noteChoices) { choice in
                    HStack(alignment: .top, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { noteIncluded(choice.id) },
                            set: { setNoteIncluded(choice.id, $0) }
                        )) {
                            EmptyView()
                        }
                        .labelsHidden()
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        #endif
                        .accessibilityLabel(String(localized: "collection.inspector.note.include",
                                                   defaultValue: "Include this research note when notes apply"))
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        Text(choice.preview)
                            .font(.callout)
                            .lineLimit(3)
                    }
                }
                Text(String(localized: "collection.inspector.note.selectionCaption",
                            defaultValue: "Checked notes are included when research notes apply to this document. Unselecting every note turns notes off for it."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let onNewNote {
                Button {
                    onNewNote()
                } label: {
                    Label(String(localized: "collection.inspector.note.new",
                                 defaultValue: "New Note\u{2026}"),
                          systemImage: "plus")
                }
                .font(.callout)
            }

            Label {
                Text(highlightCount == 1
                     ? String(localized: "collection.inspector.highlight.one", defaultValue: "1 highlight")
                     : String(localized: "collection.inspector.highlight.many",
                              defaultValue: "\(highlightCount) highlights"))
                    .font(.callout)
                    .foregroundStyle(highlightCount == 0 ? .secondary : .primary)
            } icon: { Image(systemName: "highlighter") }

            // Per-highlight rows (Authoring Phase 5): an include checkbox (A8 —
            // `selectedHighlightIds`, empty = all), passage preview + colour chip,
            // each insertable as a frozen excerpt entry when the editor supplied the
            // append action and the highlight has stored text.
            ForEach(highlightChoices) { choice in
                HStack(alignment: .top, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { highlightIncluded(choice.id) },
                        set: { setHighlightIncluded(choice.id, $0) }
                    )) {
                        EmptyView()
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #else
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    #endif
                    .accessibilityLabel(String(localized: "collection.inspector.highlight.include",
                                               defaultValue: "Include this passage when highlights apply"))
                    Circle()
                        .fill(choice.color.swiftUIColor)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                        .accessibilityLabel(choice.color.displayName)
                    if let capture = choice.capture {
                        Text(capture.text)
                            .font(.caption)
                            .lineLimit(3)
                        Spacer(minLength: 8)
                        if onInsertExcerpt != nil {
                            if insertedHighlightIds.contains(choice.id) {
                                Label(String(localized: "collection.inspector.excerpt.inserted",
                                             defaultValue: "Inserted"),
                                      systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Button(String(localized: "collection.inspector.excerpt.insert",
                                              defaultValue: "Insert as Excerpt")) {
                                    onInsertExcerpt?(capture)
                                    insertedHighlightIds.insert(choice.id)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    } else {
                        Text(String(localized: "collection.inspector.excerpt.noText",
                                    defaultValue: "No stored passage text — open the document and re-create this highlight to excerpt it."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !highlightChoices.isEmpty {
                Text(String(localized: "collection.inspector.highlight.selectionCaption",
                            defaultValue: "Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !tags.isEmpty {
                Label { Text(tags.joined(separator: ", ")).font(.callout) }
                    icon: { Image(systemName: "tag") }
            }

            if let summaryPreview, !summaryPreview.isEmpty {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        // Prompt-aware label (Phase 5): name the producing prompt when known.
                        Text(summaryPromptName.map { name in
                            String(localized: "collection.inspector.summaryFromPrompt",
                                   defaultValue: "AI summary — \(name)")
                        } ?? String(localized: "collection.inspector.summary",
                                    defaultValue: "AI summary"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(summaryPreview).font(.callout).lineLimit(3)
                    }
                } icon: { Image(systemName: "sparkles") }
            }
        }
    }

    // MARK: - Resolved-inheritance display (Composer redesign, idea #5)

    /// What a document entry's overrides resolve to *right now* — the section (nearest ancestor
    /// heading) value, else the collection default — so each override at "Default" can show
    /// "Default → On/Off" instead of a prose-only inheritance note. Reuses the existing ancestor
    /// cascade (`CollectionOutline.sectionOverrideValues`) and the canonical `CollectionBodyDepth
    /// .resolve`; the UI DISPLAYS the resolver's result, it does not reimplement resolution.
    private struct ResolvedEntryDefaults {
        let bodyDepth: CollectionBodyDepth
        let highlights: Bool
        let notes: Bool
        let sourceNote: Bool
        let footnotes: Bool
        let related: Bool
        let summaryPromptId: UUID?
        let headnote: Bool
    }

    /// The resolved defaults for the focused document entry, or `nil` for headings (whose own
    /// values ARE the section default) and when the outline can't be read. Computed on the
    /// MainActor view: reads `@Model` fields to build plain `[Value?]` arrays, then the pure
    /// cascade resolves them.
    private var resolvedEntryDefaults: ResolvedEntryDefaults? {
        guard !isHeading, let collection = entry.collection else { return nil }
        let ordered = (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard let index = ordered.firstIndex(where: { $0.id == entry.id }) else { return nil }
        let refs = ordered.map(CollectionOutline.StructuralRef.init)
        // The nearest-ancestor-heading value for one override field at this entry's position.
        func section<Value>(_ field: (CollectionEntry) -> Value?) -> Value? {
            CollectionOutline.sectionOverrideValues(
                refs, headingValues: ordered.map { $0.entryKind == .heading ? field($0) : nil }
            )[index]
        }
        return ResolvedEntryDefaults(
            bodyDepth: CollectionBodyDepth.resolve(entryOverride: nil,
                                                   sectionOverride: section { $0.bodyDepthOverride },
                                                   collectionDefault: collection.defaultBodyDepth),
            highlights: section { $0.applyHighlightsOverride } ?? collection.applyHighlights,
            notes: section { $0.includeNotesOverride } ?? collection.includeNotes,
            sourceNote: section { $0.includeSourceNoteOverride } ?? collection.effectiveIncludeSourceNote,
            footnotes: section { $0.includeFootnotesOverride } ?? collection.effectiveIncludeFootnotes,
            related: section { $0.includeRelatedDocuments } ?? false,
            summaryPromptId: section { $0.summaryPromptIdOverride } ?? collection.summaryPromptId,
            // Headnote has no heading-level section default in the Composer model — it resolves
            // straight to the collection default.
            headnote: collection.defaultIncludeHeadnote
        )
    }

    /// "Default → On" / "Default → Off" for a resolved Bool override.
    private func defaultResolves(_ value: Bool) -> String {
        value
            ? String(localized: "collection.inspector.override.resolvesOn", defaultValue: "Default → On")
            : String(localized: "collection.inspector.override.resolvesOff", defaultValue: "Default → Off")
    }

    /// "Default → <value>" for a resolved non-Bool override (body depth, summary prompt).
    private func defaultResolves(to text: String) -> String {
        String(localized: "collection.inspector.override.resolvesTo",
               defaultValue: "Default → \(text)")
    }

    /// The resolved summary-prompt name for the "Default → …" subtitle (or "None" when unset).
    private func resolvedPromptName(_ id: UUID?) -> String {
        guard let id, let choice = promptChoices.first(where: { $0.id == id }) else {
            return String(localized: "collection.inspector.override.prompt.none", defaultValue: "None")
        }
        return choice.name
    }

    // MARK: - Export overrides (Authoring Phase 5)

    /// A Default / On / Off picker bound to one optional-Bool override field.
    /// "Default" (`nil`) inherits the section default, else the collection setting; when at Default,
    /// an optional `subtitle` shows what it resolves to right now (Composer redesign, idea #5).
    private func overridePicker(_ title: String, _ binding: Binding<Bool?>,
                                subtitle: String? = nil) -> some View {
        Picker(selection: binding) {
            Text(String(localized: "collection.inspector.override.default",
                        defaultValue: "Default"))
                .tag(Bool?.none)
            Text(String(localized: "collection.inspector.override.on",
                        defaultValue: "On"))
                .tag(Bool?.some(true))
            Text(String(localized: "collection.inspector.override.off",
                        defaultValue: "Off"))
                .tag(Bool?.some(false))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle, binding.wrappedValue == nil {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .pickerStyle(.menu)
    }

    /// The shared override controls — the same six fields serve a document entry (its
    /// own overrides) and a heading entry (its section defaults); only the containing
    /// section's copy differs. Every control here is functional: highlights, notes,
    /// source note, and footnotes (PDF/DOCX gated since the 2026-07-03 owner decision)
    /// gate all three export formats and the preview.
    @ViewBuilder private var overrideControls: some View {
        // Resolve the section/collection defaults once so each override at "Default" can show what
        // it resolves to right now (Composer redesign idea #5). `nil` for headings.
        let rd = resolvedEntryDefaults
        overridePicker(String(localized: "collection.inspector.override.highlights",
                              defaultValue: "Highlights"),
                       Binding(get: { entry.applyHighlightsOverride },
                               set: { entry.applyHighlightsOverride = $0 }),
                       subtitle: rd.map { defaultResolves($0.highlights) })
        overridePicker(String(localized: "collection.inspector.override.notes",
                              defaultValue: "Research notes"),
                       Binding(get: { entry.includeNotesOverride },
                               set: { entry.includeNotesOverride = $0 }),
                       subtitle: rd.map { defaultResolves($0.notes) })
        overridePicker(String(localized: "collection.inspector.override.sourceNote",
                              defaultValue: "Source note"),
                       Binding(get: { entry.includeSourceNoteOverride },
                               set: { entry.includeSourceNoteOverride = $0 }),
                       subtitle: rd.map { defaultResolves($0.sourceNote) })
        overridePicker(String(localized: "collection.inspector.override.footnotes",
                              defaultValue: "Footnotes"),
                       Binding(get: { entry.includeFootnotesOverride },
                               set: { entry.includeFootnotesOverride = $0 }),
                       subtitle: rd.map { defaultResolves($0.footnotes) })

        Picker(selection: Binding(get: { entry.summaryPromptIdOverride },
                                  set: { entry.summaryPromptIdOverride = $0 })) {
            Text(String(localized: "collection.inspector.override.default",
                        defaultValue: "Default"))
                .tag(UUID?.none)
            ForEach(promptChoices) { choice in
                Text(choice.name).tag(UUID?.some(choice.id))
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "collection.inspector.override.prompt",
                            defaultValue: "Summary prompt"))
                if entry.summaryPromptIdOverride == nil, let rd {
                    Text(defaultResolves(to: resolvedPromptName(rd.summaryPromptId)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .pickerStyle(.menu)

        overridePicker(String(localized: "collection.inspector.override.related",
                              defaultValue: "Related documents"),
                       Binding(get: { entry.includeRelatedDocuments },
                               set: { entry.includeRelatedDocuments = $0 }),
                       subtitle: rd.map { defaultResolves($0.related) })
        Text(String(localized: "collection.inspector.override.related.caption",
                    defaultValue: "Adds a \u{201C}See also\u{201D} line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section."))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    /// This entry's body-depth override (`nil` = follow the section/collection default);
    /// the parent gate the other overrides refine — highlights only apply at `.full`
    /// (moved here from the reporting row in Collections Manager M2, D3).
    private var bodyDepthOverride: Binding<String?> {
        Binding(get: { entry.bodyDepthOverride }, set: { entry.bodyDepthOverride = $0 })
    }

    /// Depths offered here: those available on this device, plus the entry's current
    /// override even when it isn't otherwise offered (a synced `.summaryOnly` on an
    /// AI-less device). Moved verbatim from the reporting row (Collections Manager M2).
    private var entryDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        if let raw = entry.bodyDepthOverride, let d = CollectionBodyDepth(rawValue: raw),
           !available.contains(d) {
            return available + [d]
        }
        return available
    }

    /// The body-depth Picker — the parent gate the rest of the overrides refine, so it
    /// leads both the document Export Overrides and the heading Section Defaults sections.
    private var bodyDepthPicker: some View {
        Picker(selection: bodyDepthOverride) {
            Text(String(localized: "collection.entry.bodyDepth.default",
                        defaultValue: "Default")).tag(String?.none)
            ForEach(entryDepthOptions) { Text($0.displayName).tag(String?.some($0.rawValue)) }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "collection.entry.bodyDepth.label",
                            defaultValue: "Body depth"))
                if entry.bodyDepthOverride == nil, let rd = resolvedEntryDefaults {
                    Text(defaultResolves(to: rd.bodyDepth.displayName))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .pickerStyle(.menu)
    }

    /// The document entry's Export Overrides section.
    @ViewBuilder private var overridesSection: some View {
        Section(String(localized: "collection.inspector.overrides",
                       defaultValue: "Export Overrides")) {
            bodyDepthPicker
            overrideControls
            Text(String(localized: "collection.inspector.overrides.caption",
                        defaultValue: "Default follows the section's setting when its heading sets one, else the collection's composition."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// The heading entry's Section Defaults variant: the same controls, applied to
    /// every document the section owns unless a document sets its own override.
    @ViewBuilder private var sectionDefaultsSection: some View {
        Section(String(localized: "collection.inspector.sectionDefaults",
                       defaultValue: "Section Defaults")) {
            overrideControls
            Text(String(localized: "collection.inspector.sectionDefaults.caption",
                        defaultValue: "Documents in this section use these settings unless they set their own. Default falls through to the collection's composition."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Per-highlight selection (A8)

    /// Whether a highlight is included when highlights apply: an empty
    /// `selectedHighlightIds` means **all** (the pre-override behavior).
    private func highlightIncluded(_ id: UUID) -> Bool {
        entry.selectedHighlightIds.isEmpty || entry.selectedHighlightIds.contains(id)
    }

    /// Writes one highlight's inclusion, keeping the canonical A8 forms: a selection of
    /// every highlight collapses back to the empty set (so future highlights keep
    /// flowing in automatically), and unselecting the last passage turns the entry's
    /// highlight override off — the empty set cannot mean "none", so "none" is
    /// expressed as `applyHighlightsOverride = false` (the row caption says so).
    private func setHighlightIncluded(_ id: UUID, _ include: Bool) {
        let allIds = highlightChoices.map(\.id)
        var selected = entry.selectedHighlightIds.isEmpty ? allIds : entry.selectedHighlightIds
        if include {
            if !selected.contains(id) { selected.append(id) }
        } else {
            selected.removeAll { $0 == id }
        }
        if Set(selected).isSuperset(of: allIds) {
            entry.selectedHighlightIds = []
        } else if selected.isEmpty {
            entry.selectedHighlightIds = []
            entry.applyHighlightsOverride = false
        } else {
            entry.selectedHighlightIds = selected
        }
    }

    // MARK: - Per-note selection (D5)

    /// Whether a research note is included when notes apply: an empty `selectedNoteIds`
    /// means **all** (mirroring `highlightIncluded` / `selectedHighlightIds`). While the
    /// entry is still on the legacy single-note path (`selectedNoteIds` empty and
    /// `researchNoteId` set), that link scopes the "all" set to the one linked note so
    /// the row reflects what actually exports — matching the resolver's precedence.
    private func noteIncluded(_ id: UUID) -> Bool {
        if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.contains(id) }
        if let legacy = entry.researchNoteId { return legacy == id }
        return true
    }

    /// Writes one note's inclusion, keeping the canonical D5 forms exactly as
    /// `setHighlightIncluded`: selecting every note collapses back to the empty set (so
    /// future notes on the document keep flowing in automatically), and unselecting the
    /// last note turns the entry's notes override off — the empty set cannot mean "none",
    /// so "none" is expressed as `includeNotesOverride = false` (the row caption says so).
    /// Migrates the legacy single-note `researchNoteId` into the array on first edit.
    private func setNoteIncluded(_ id: UUID, _ include: Bool) {
        let allIds = noteChoices.map(\.id)
        // Seed from the effective set so the first edit preserves the current meaning:
        // an empty selection currently means "all" (or, un-migrated, the one legacy note).
        var selected: [UUID]
        if !entry.selectedNoteIds.isEmpty {
            selected = entry.selectedNoteIds
        } else if let legacy = entry.researchNoteId {
            selected = [legacy]
        } else {
            selected = allIds
        }
        // Clear the legacy link once we start writing the array (single source of truth).
        entry.researchNoteId = nil
        if include {
            if !selected.contains(id) { selected.append(id) }
        } else {
            selected.removeAll { $0 == id }
        }
        if Set(selected).isSuperset(of: allIds) {
            entry.selectedNoteIds = []
        } else if selected.isEmpty {
            entry.selectedNoteIds = []
            entry.includeNotesOverride = false
        } else {
            entry.selectedNoteIds = selected
        }
    }

    // MARK: - Excerpts in this collection (Authoring Phase 5)

    /// The excerpt entries this collection already carries from this document — shown so
    /// the inspector is the one place to see a document's whole contribution. Rows are
    /// read-only here; excerpts are moved and deleted in the collection list itself.
    private var documentExcerpts: [CollectionEntry] {
        (entry.collection?.documentEntries ?? [])
            .filter {
                $0.entryKind == .excerpt
                    && $0.volumeId == entry.volumeId
                    && $0.documentId == entry.documentId
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The "Excerpts in This Collection" section; hidden when there are none.
    @ViewBuilder private var excerptsSection: some View {
        let excerpts = documentExcerpts
        if !excerpts.isEmpty {
            Section(String(localized: "collection.inspector.excerpts",
                           defaultValue: "Excerpts in This Collection")) {
                ForEach(excerpts, id: \.id) { excerpt in
                    Label {
                        Text(excerpt.text ?? "")
                            .font(.callout.italic())
                            .lineLimit(3)
                    } icon: {
                        Image(systemName: "text.quote")
                    }
                }
                Text(String(localized: "collection.inspector.excerpts.caption",
                            defaultValue: "Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Headnote controls (Authoring Phase 5): opt a document entry into an italic
    /// abstract above its body in exports/preview, and — when stored summaries exist —
    /// choose which `GeneratedSummary` supplies it (labeled by producing prompt;
    /// "Automatic" = the resolver's fallback pick, preferring the collection's prompt).
    @ViewBuilder private var headnoteSection: some View {
        Section(String(localized: "collection.inspector.headnote", defaultValue: "Headnote")) {
            // Now a Default/On/Off override (Composer redesign): Default inherits the collection's
            // headnote default, shown as "Default → On/Off". The editable "key takeaway" card
            // replaces this in a following phase.
            let rd = resolvedEntryDefaults
            overridePicker(String(localized: "collection.inspector.headnote.toggle",
                                  defaultValue: "Show a summary above the document"),
                           Binding(get: { entry.includeHeadnote },
                                   set: { entry.includeHeadnote = $0 }),
                           subtitle: rd.map { defaultResolves($0.headnote) })

            if entry.includeHeadnote ?? rd?.headnote ?? false {
                headnoteCard
            }
        }
    }

    /// Reserved `promptId` stamped on a dedicated headnote draft — it has no producing prompt, and
    /// `isHeadnoteDraft` already excludes it from every prompt-aware query.
    private static let headnoteDraftPromptId = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!

    /// The `GeneratedSummary` backing this entry's headnote: the explicit pick (including a
    /// dedicated draft, fetched by id), else the resolver's fallback (the collection prompt's
    /// summary, else the first non-empty non-draft) — mirroring `CollectionContentResolver`.
    private var currentHeadnoteSummary: GeneratedSummary? {
        let vid = entry.volumeId
        let did = entry.documentId
        if let sid = entry.headnoteSummaryId,
           let chosen = try? modelContext.fetch(
               FetchDescriptor<GeneratedSummary>(predicate: #Predicate { $0.id == sid })).first,
           !chosen.responseText.isEmpty {
            return chosen
        }
        let stored = ((try? modelContext.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did && !$0.isHeadnoteDraft }))) ?? [])
            .filter { !$0.responseText.isEmpty }
        // Mirror the resolver's preferred-prompt precedence (entry override → section default →
        // collection default) so the card seeds and edits the SAME summary the export will use.
        let promptId = entry.summaryPromptIdOverride ?? resolvedEntryDefaults?.summaryPromptId
        return promptId.flatMap { pid in stored.first { $0.promptId == pid } } ?? stored.first
    }

    /// The editable "key takeaway" headnote card (Composer redesign): the resolved abstract that
    /// renders above the document in exports, presented as a first-class editable takeaway. AI seeds
    /// it (a stored summary); the user can Edit it into a dedicated draft that never touches the
    /// document's summaries and, once edited, is not labeled AI. (Regenerate arrives next.)
    @ViewBuilder private var headnoteCard: some View {
        let summary = currentHeadnoteSummary
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "collection.inspector.headnote.keyTakeaway",
                            defaultValue: "Key takeaway \u{00B7} headnote"))
                    .font(.caption2).fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(FRUSTheme.headnotePurple)
                Spacer()
                headnoteProvenanceChip(summary.map { $0.authorship ?? .aiGenerated })
            }

            if isEditingHeadnote {
                TextEditor(text: $headnoteDraft)
                    .font(.callout)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(FRUSTheme.headnotePurpleBorder))
                HStack {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                        isEditingHeadnote = false
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Button(String(localized: "collection.inspector.headnote.save", defaultValue: "Save")) {
                        commitHeadnote(seed: summary)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(headnoteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(.caption)
            } else {
                if let text = summary?.responseText, !text.isEmpty {
                    Text(text).font(.callout).italic()
                } else {
                    Text(String(localized: "collection.inspector.headnote.empty",
                                defaultValue: "No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                headnoteActionRow(summary: summary)
            }
        }
        .padding(12)
        .background(FRUSTheme.headnotePurpleFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(FRUSTheme.headnotePurpleBorder, lineWidth: 1))
    }

    /// The provenance chip in the headnote card header — AI draft / AI · edited / Yours.
    @ViewBuilder private func headnoteProvenanceChip(_ authorship: SummaryAuthorship?) -> some View {
        if let authorship {
            let label: (text: String, icon: String) = {
                switch authorship {
                case .aiGenerated:
                    return (String(localized: "collection.inspector.headnote.chip.ai",
                                   defaultValue: "AI draft"), "sparkles")
                case .aiEdited:
                    return (String(localized: "collection.inspector.headnote.chip.aiEdited",
                                   defaultValue: "AI \u{00B7} edited"), "pencil")
                case .userWritten:
                    return (String(localized: "collection.inspector.headnote.chip.user",
                                   defaultValue: "Yours"), "person")
                }
            }()
            Label(label.text, systemImage: label.icon)
                .font(.caption2)
                .foregroundStyle(authorship == .userWritten ? Color.secondary : FRUSTheme.headnotePurple)
        }
    }

    /// The display-mode action row under the headnote text: **Edit** plus — when the on-device
    /// summarizer is available — a **Generate/Regenerate** button, with an inline error or a
    /// "download the volume" hint when the document's text isn't available locally.
    /// (Composer redesign 2c-2c Regenerate.)
    @ViewBuilder private func headnoteActionRow(summary: GeneratedSummary?) -> some View {
        HStack(spacing: 14) {
            Button {
                headnoteDraft = summary?.responseText ?? ""
                isEditingHeadnote = true
            } label: {
                Label(String(localized: "collection.inspector.headnote.edit", defaultValue: "Edit"),
                      systemImage: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(isRegenerating)

            if aiSummarizationAvailable {
                Button {
                    Task { await regenerateHeadnote() }
                } label: {
                    if isRegenerating {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.small)
                            Text(String(localized: "collection.inspector.headnote.regenerating",
                                        defaultValue: "Generating…"))
                        }
                    } else {
                        Label(summary == nil
                              ? String(localized: "collection.inspector.headnote.generate",
                                       defaultValue: "Generate")
                              : String(localized: "collection.inspector.headnote.regenerate",
                                       defaultValue: "Regenerate"),
                              systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRegenerating || !documentTextAvailableLocally)
            }
            Spacer(minLength: 0)
        }
        .font(.caption)

        if let regenError {
            Label(regenError, systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.red)
        } else if aiSummarizationAvailable && !documentTextAvailableLocally {
            Text(String(localized: "collection.inspector.headnote.regen.needsVolume",
                        defaultValue: "Download this document's volume to generate a summary."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Whether the on-device summarizer can run at all — the service is wired **and** Apple
    /// Intelligence reports itself available on this device.
    private var aiSummarizationAvailable: Bool {
        appState.summarizationService != nil && AppleIntelligenceProvider.shared.isAvailable
    }

    /// Whether this document's text is available locally (its volume is indexed, or at least
    /// downloaded) — the cheap synchronous gate for enabling Regenerate. Regenerate never
    /// downloads; it only summarizes text already on device.
    private var documentTextAvailableLocally: Bool {
        if let pipeline = appState.indexingPipeline,
           (try? pipeline.isVolumeIndexed(entry.volumeId)) == true {
            return true
        }
        return appState.downloadManager?.isVolumeDownloaded(entry.volumeId) == true
    }

    /// Commits an edited headnote as a dedicated `GeneratedSummary` draft (Composer redesign): a
    /// change to an AI seed is `.aiEdited`, otherwise `.userWritten`; the shared `swapHeadnoteDraft`
    /// marks it `isHeadnoteDraft` so it never appears among the document's summaries, and the export
    /// attribution honors its authorship.
    private func commitHeadnote(seed: GeneratedSummary?) {
        isEditingHeadnote = false
        let trimmed = headnoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        // Compare trimmed-to-trimmed so a whitespace-only edit of the seed is a genuine no-op and does
        // not spuriously mint a new draft (which would also flip attribution).
        guard !trimmed.isEmpty,
              seed?.responseText.trimmingCharacters(in: .whitespacesAndNewlines) != trimmed else { return }
        // AI-derived text — whether a fresh AI draft or one already AI-edited — stays labeled as
        // AI-assisted across further edits; only a nil seed or the user's own text yields `.userWritten`.
        let seedAuthorship = seed.map { $0.authorship ?? .aiGenerated }
        let seedIsAIDerived = seedAuthorship == .aiGenerated || seedAuthorship == .aiEdited
        let authorship: SummaryAuthorship =
            (seedIsAIDerived && !(seed?.responseText.isEmpty ?? true)) ? .aiEdited : .userWritten
        swapHeadnoteDraft(text: trimmed, authorship: authorship)
    }

    /// Deletes any prior **dedicated** headnote draft (never a real document summary), mints a fresh
    /// `isHeadnoteDraft` `GeneratedSummary` with `text` + `authorship`, repoints
    /// `entry.headnoteSummaryId` to it (a new id flips the preview fingerprint, which hashes
    /// `headnoteSummaryId` not the text, so the preview refreshes), and saves. Shared by Edit
    /// (`commitHeadnote`) and Regenerate (`regenerateHeadnote`).
    private func swapHeadnoteDraft(text: String, authorship: SummaryAuthorship) {
        if let sid = entry.headnoteSummaryId,
           let existing = try? modelContext.fetch(FetchDescriptor<GeneratedSummary>(
               predicate: #Predicate { $0.id == sid })).first,
           existing.isHeadnoteDraft {
            modelContext.delete(existing)
        }
        let draft = GeneratedSummary(documentId: entry.documentId, volumeId: entry.volumeId,
                                     promptId: Self.headnoteDraftPromptId, responseText: text,
                                     authorship: authorship, isHeadnoteDraft: true)
        modelContext.insert(draft)
        entry.headnoteSummaryId = draft.id
        try? modelContext.save()
    }

    /// Regenerates the headnote with a fresh on-device AI summary (Composer redesign 2c-2c): runs
    /// the entry's effective prompt over the document's text, then swaps in a dedicated
    /// `.aiGenerated` headnote draft — the same collection-private draft mechanism as Edit, so it
    /// never pollutes the document's summary carousel. Failures surface inline via `regenError`.
    private func regenerateHeadnote() async {
        guard !isRegenerating else { return }
        guard let service = appState.summarizationService,
              AppleIntelligenceProvider.shared.isAvailable else {
            regenError = String(localized: "collection.inspector.headnote.regen.unavailable",
                                defaultValue: "On-device summarization isn't available on this device.")
            return
        }
        guard let prompt = resolveHeadnotePrompt() else {
            regenError = String(localized: "collection.inspector.headnote.regen.noPrompt",
                                defaultValue: "No summarization prompt is available.")
            return
        }
        isRegenerating = true
        regenError = nil
        defer { isRegenerating = false }

        guard let bodyText = await headnoteDocumentText() else {
            // The button is only enabled when the volume is present locally, so a nil here means
            // this particular document has no extractable body text (e.g. an editorial stub) —
            // not that the volume needs downloading.
            regenError = String(localized: "collection.inspector.headnote.regen.noText",
                                defaultValue: "This document has no text available to summarize.")
            return
        }
        // Build the Sendable snapshot on the main actor before crossing the summarizer's actor boundary.
        let snapshot = SummarizationPromptSnapshot(from: prompt)
        do {
            let (text, _) = try await service.generateSummaryText(
                documentText: bodyText,
                prompt: snapshot,
                provider: AppleIntelligenceProvider.shared,
                documentId: entry.documentId,
                volumeId: entry.volumeId)
            guard !Task.isCancelled else { return }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                regenError = String(localized: "collection.inspector.headnote.regen.empty",
                                    defaultValue: "The summarizer returned no text. Try again.")
                return
            }
            swapHeadnoteDraft(text: clean, authorship: .aiGenerated)
        } catch {
            regenError = error.localizedDescription
        }
    }

    /// Resolves the `SummarizationPrompt` a headnote Regenerate should run: the entry's effective
    /// cascade prompt (entry override → section default → collection default), else the app-shipped
    /// default (the oldest `isStandard` prompt, i.e. "Standard Summary" — selected by creation
    /// order rather than its localized name).
    private func resolveHeadnotePrompt() -> SummarizationPrompt? {
        let effectiveId = entry.summaryPromptIdOverride ?? resolvedEntryDefaults?.summaryPromptId
        if let id = effectiveId,
           let prompt = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>(
               predicate: #Predicate { $0.id == id })))?.first {
            return prompt
        }
        let standard = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == true },
            sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return standard.first
    }

    /// Obtains this document's plain body text for on-device summarization — the cheap indexed path
    /// first (a single `document_cache` lookup), then an on-disk TEI parse. Returns `nil` when the
    /// text isn't available locally (the volume is neither indexed nor downloaded); Regenerate then
    /// reports that rather than downloading.
    private func headnoteDocumentText() async -> String? {
        // 1. Indexed body text (space-joined) — the cheapest correct source.
        if let pipeline = appState.indexingPipeline,
           let fetched = try? await pipeline.fetchDocumentBodyText(
               volumeId: entry.volumeId, documentId: entry.documentId),
           !fetched.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fetched
        }
        // 2. Fallback: parse the on-disk TEI (paragraph-joined, matching the document view).
        guard let dm = appState.downloadManager else { return nil }
        let volumeURL = dm.volumeURL(for: entry.volumeId)
        guard FileManager.default.fileExists(atPath: volumeURL.path) else { return nil }
        guard let ast = try? await FRUSDocumentParser().parseDocument(
            documentId: entry.documentId, volumeURL: volumeURL) else { return nil }
        let text = ast.nodes.map(\.plainText).joined(separator: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    @ViewBuilder private var provenanceSection: some View {
        Section(String(localized: "collection.inspector.provenance", defaultValue: "Provenance")) {
            if let sourceNote, !sourceNote.isEmpty {
                Label { Text(sourceNote).font(.callout).textSelection(.enabled) }
                    icon: { Image(systemName: "archivebox") }
            } else {
                Label(String(localized: "collection.inspector.noSource",
                             defaultValue: "No archival source note indexed"),
                      systemImage: "archivebox")
                    .foregroundStyle(.secondary).font(.callout)
            }
            if crossRefCount > 0 {
                Label {
                    Text(crossRefCount == 1
                         ? String(localized: "collection.inspector.crossRef.one",
                                  defaultValue: "1 cross-reference")
                         : String(localized: "collection.inspector.crossRef.many",
                                  defaultValue: "\(crossRefCount) cross-references"))
                        .font(.callout)
                } icon: { Image(systemName: "arrow.triangle.branch") }
            }
        }
    }

    /// Gathers the document's data from the app's existing stores. Fast SwiftData reads run
    /// inline; header / cross-refs / source note come from the actor-isolated stores.
    /// The heading variant needs only the prompt list for its section-defaults picker.
    private func load() async {
        // Prompt choices power the summary-prompt override picker in both variants.
        let allPrompts = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>())) ?? []
        promptChoices = allPrompts.map { PromptChoice(id: $0.id, name: $0.name) }

        guard !isHeading else {
            isLoading = false
            return
        }

        let vid = entry.volumeId
        let did = entry.documentId

        let manifestEntry = appState.manifestStore.entry(forVolumeId: vid)
        volumeTitle = manifestEntry?.title ?? ""

        // Resolve the history.state.gov citation exactly as `CollectionContentResolver`
        // does (manifest volume metadata + document number; the formatter never reads the
        // document header/dateline), so the override placeholder shows the true
        // export-heading fallback. Empty when the volume is not in the manifest.
        if let manifestEntry {
            let docNum: String? = did.hasPrefix("d")
                ? Int(did.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: did, documentNumber: docNum, header: "", dateline: nil)
            resolvedCitation = HistoryAtStateCitationFormatter()
                .format(document: docMeta, volume: FRUSVolumeMetadata(manifestEntry))
        }

        let (docTags, docNotes) = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: did, volumeId: vid, context: modelContext)
        tags = docTags
        noteTexts = docNotes

        // Per-note include rows (D5): the document's own research notes, ordered newest
        // first (matching the editors' `notes(for:)` ordering by `lastModified`).
        let docNoteRecords = ((try? modelContext.fetch(FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did }))) ?? [])
            .sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        noteChoices = docNoteRecords.map { note in
            let trimmed = note.bodyText.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines)
            return NoteChoice(
                id: note.id,
                preview: trimmed.isEmpty
                    ? String(localized: "collection.entry.note.emptyPreview",
                             defaultValue: "Untitled Note")
                    : String(trimmed))
        }

        let highlights = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did }))) ?? []
        highlightCount = highlights.count
        highlightChoices = highlights
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .map { HighlightChoice(id: $0.id,
                                   capture: CollectionExcerpts.capture(from: $0),
                                   color: $0.color) }

        let summaries = ((try? modelContext.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.volumeId == vid && $0.documentId == did }))) ?? [])
            // Exclude dedicated headnote drafts (Composer redesign) — they belong to a collection
            // entry's headnote, not the document's summary set.
            .filter { !$0.responseText.isEmpty && !$0.isHeadnoteDraft }
        // Prompt-aware pick (Phase 5): prefer the summary produced by the collection's
        // configured prompt; else fall back to the first non-empty one (prior behavior).
        let prompts = (try? modelContext.fetch(FetchDescriptor<SummarizationPrompt>())) ?? []
        let promptNames = Dictionary(prompts.map { ($0.id, $0.name) },
                                     uniquingKeysWith: { first, _ in first })
        let collectionPromptId = entry.collection?.summaryPromptId
        let shown = collectionPromptId.flatMap { pid in summaries.first { $0.promptId == pid } }
            ?? summaries.first
        summaryPreview = shown?.responseText
        summaryPromptName = shown.flatMap { promptNames[$0.promptId] }

        if let store = appState.crossReferenceStore {
            header = (try? await store.documentHeaders(
                for: [(volumeId: vid, documentId: did)]))?["\(vid)/\(did)"]
            let inbound = (try? await store.inboundEdges(forDocumentId: did, volumeId: vid))?.count ?? 0
            let outbound = (try? await store.outboundEdges(forDocumentId: did, volumeId: vid))?.count ?? 0
            crossRefCount = inbound + outbound
        }

        sourceNote = try? await appState.indexingPipeline?
            .fetchDocumentSourceNote(volumeId: vid, documentId: did)

        isLoading = false
    }
}
