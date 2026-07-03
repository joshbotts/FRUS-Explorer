// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CollectionHeadingRow

/// An editable section-heading entry in the collection (Phase 3a). Shared by the iOS editor
/// and the macOS manager. `onDelete`, when provided, renders an inline delete control —
/// macOS supplies it (the List has no swipe-to-delete); iOS omits it (swipe handles deletion).
///
/// The heading also carries an optional **section body depth** (Phase 3c): documents under
/// this heading use it unless they have their own per-entry override. Stored in the heading
/// entry's `bodyDepthOverride`.
///
/// **Outline editing (Phase 4).** The row is the heading's control surface for the derived
/// section tree: level-stepped typography via `depth`, a collapse/expand chevron (view
/// state only — the owning editor hides the section's rows), and a context menu with
/// Rename, Indent/Outdent (gated by `CollectionOutline.canIndent`/`canOutdent`, passed in
/// as flags), "Delete Heading Only" (children bubble up via normalize) and "Delete
/// Section" (heading + contents, confirmed first).
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.1 — Authoring Phase 4 (editor step): outline controls — depth-stepped title font,
///          collapse chevron, and the section context menu (rename / indent / outdent /
///          delete-heading-only vs delete-section-with-confirmation); the inline trash
///          became `showsInlineDelete` (macOS) with `onDelete` reused by the menu
///   1.2 — Authoring Phase 5 (overrides): "Section Details…" context-menu item presents
///          the `CollectionEntryInspector` heading variant — the section-defaults
///          control surface (highlights / notes / source note / footnotes / summary
///          prompt / related documents), cascading to the section's documents
///   (file) Authoring Phase 5 (excerpts): `CollectionExcerptRow` added below
///   (file) Authoring Phase 6 (generated apparatus): `CollectionGeneratedEntryRow` added below
struct CollectionHeadingRow: View {
    @Binding var entry: CollectionEntry
    /// Deletes the heading entry ONLY — its contents stay and any sub-headings bubble up
    /// one level (the editor normalizes). Drives the context menu on both platforms and,
    /// when `showsInlineDelete` is set, the trailing trash button.
    var onDelete: (() -> Void)? = nil
    /// Whether to render the inline trailing trash for `onDelete` — macOS passes `true`
    /// (its List has no swipe-to-delete); iOS keeps deletion on swipe + context menu.
    var showsInlineDelete: Bool = false
    /// The heading's resolved outline depth (`1...CollectionOutline.maxLevel`), stepping
    /// the title typography. Defaults to 1 (the pre-Phase-4 appearance).
    var depth: Int = 1
    /// Whether the section's rows are currently hidden (view state owned by the editor).
    var isCollapsed: Bool = false
    /// How many entries the section owns below the heading — shown while collapsed and
    /// in the Delete Section confirmation.
    var sectionEntryCount: Int = 0
    /// Toggles the collapse state; `nil` hides the chevron.
    var onToggleCollapse: (() -> Void)? = nil
    /// Whether Indent is a valid outline mutation here (`CollectionOutline.canIndent`).
    var canIndent: Bool = false
    /// Whether Outdent is a valid outline mutation here (`CollectionOutline.canOutdent`).
    var canOutdent: Bool = false
    /// Indents the section one level (heading + descendants); `nil` hides the menu item.
    var onIndent: (() -> Void)? = nil
    /// Outdents the section one level; `nil` hides the menu item.
    var onOutdent: (() -> Void)? = nil
    /// Deletes the heading AND every entry in its section range. Invoked only after the
    /// user confirms; `nil` hides the menu item.
    var onDeleteSection: (() -> Void)? = nil

    /// Focus for the title field, so the context menu's Rename can summon the keyboard.
    @FocusState private var titleFocused: Bool
    /// Presents the Delete Section confirmation dialog.
    @State private var confirmDeleteSection = false
    /// Presents the section-defaults inspector (Authoring Phase 5).
    @State private var showSectionInspector = false

    @Environment(AppState.self) private var appState

    /// The section's body-depth override (`nil` = documents follow the collection default).
    private var sectionDepth: Binding<String?> {
        Binding(get: { entry.bodyDepthOverride }, set: { entry.bodyDepthOverride = $0 })
    }

    /// Depths offered: those available on this device, plus the current override even when it
    /// isn't otherwise offered (a synced `.summaryOnly` on an AI-less device).
    private var depthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        if let raw = entry.bodyDepthOverride, let d = CollectionBodyDepth(rawValue: raw),
           !available.contains(d) {
            return available + [d]
        }
        return available
    }

    /// Level-stepped title typography: level 1 keeps the pre-Phase-4 headline; deeper
    /// levels step down so the outline reads at a glance.
    private var titleFont: Font {
        switch depth {
        case ...1: return .headline
        case 2:    return .subheadline.weight(.semibold)
        default:   return .footnote.weight(.semibold)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let onToggleCollapse {
                    Button(action: onToggleCollapse) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCollapsed
                        ? String(localized: "collection.section.expand", defaultValue: "Expand section")
                        : String(localized: "collection.section.collapse", defaultValue: "Collapse section"))
                }
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(String(localized: "collection.heading.placeholder", defaultValue: "Section heading"),
                          text: Binding(get: { entry.text ?? "" }, set: { entry.text = $0 }))
                    .font(titleFont)
                    .focused($titleFocused)
                if isCollapsed && sectionEntryCount > 0 {
                    Text(String(format: String(localized: "collection.section.collapsedCount %lld",
                                               defaultValue: "%lld hidden"),
                                Int64(sectionEntryCount)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                // Section-defaults inspector (Authoring Phase 5): the heading variant of
                // the entry inspector, cascading overrides to the section's documents.
                Button {
                    showSectionInspector = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "collection.section.inspect",
                                           defaultValue: "Section defaults"))
                .help(String(localized: "collection.section.inspect.help",
                             defaultValue: "Set export defaults for every document in this section"))
                structuralDeleteButton(showsInlineDelete ? onDelete : nil)
            }
            // Section body depth — applied to documents under this heading (Phase 3c).
            Picker(selection: sectionDepth) {
                Text(String(localized: "collection.section.bodyDepth.default", defaultValue: "Default"))
                    .tag(String?.none)
                ForEach(depthOptions) { Text($0.displayName).tag(String?.some($0.rawValue)) }
            } label: {
                Text(String(localized: "collection.section.bodyDepth.label", defaultValue: "Section body"))
            }
            .pickerStyle(.menu)
            .font(.caption)
        }
        .padding(.vertical, 4)
        .contextMenu { sectionContextMenu }
        .sheet(isPresented: $showSectionInspector) {
            CollectionEntryInspector(entry: entry)
                .environment(appState)
        }
        .confirmationDialog(
            String(localized: "collection.section.delete.confirm.title",
                   defaultValue: "Delete Section?"),
            isPresented: $confirmDeleteSection,
            titleVisibility: .visible
        ) {
            Button(String(localized: "collection.section.delete.confirm.action",
                          defaultValue: "Delete Section"),
                   role: .destructive) {
                onDeleteSection?()
            }
        } message: {
            Text(String(format: String(localized: "collection.section.delete.confirm.message %lld",
                                       defaultValue: "Deletes this heading and the %lld entries it contains."),
                        Int64(sectionEntryCount)))
        }
    }

    /// The section context menu: rename, section defaults, indent/outdent, and the two
    /// delete flavors.
    @ViewBuilder
    private var sectionContextMenu: some View {
        Button {
            titleFocused = true
        } label: {
            Label(String(localized: "collection.section.rename", defaultValue: "Rename"),
                  systemImage: "pencil")
        }
        Button {
            showSectionInspector = true
        } label: {
            Label(String(localized: "collection.section.defaults",
                         defaultValue: "Section Defaults…"),
                  systemImage: "slider.horizontal.3")
        }
        if let onIndent {
            Button(action: onIndent) {
                Label(String(localized: "collection.section.indent", defaultValue: "Indent"),
                      systemImage: "increase.indent")
            }
            .disabled(!canIndent)
        }
        if let onOutdent {
            Button(action: onOutdent) {
                Label(String(localized: "collection.section.outdent", defaultValue: "Outdent"),
                      systemImage: "decrease.indent")
            }
            .disabled(!canOutdent)
        }
        Divider()
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "collection.section.deleteHeadingOnly",
                             defaultValue: "Delete Heading Only"),
                      systemImage: "trash")
            }
        }
        if onDeleteSection != nil {
            Button(role: .destructive) {
                confirmDeleteSection = true
            } label: {
                Label(String(localized: "collection.section.deleteSection",
                             defaultValue: "Delete Section"),
                      systemImage: "trash.fill")
            }
        }
    }
}

/// A trailing delete control shared by the heading and prose rows; renders nothing when
/// `onDelete` is `nil`.
@MainActor @ViewBuilder
func structuralDeleteButton(_ onDelete: (() -> Void)?) -> some View {
    if let onDelete {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Image(systemName: "trash").foregroundStyle(.red.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help(String(localized: "collection.entry.delete.help",
                     defaultValue: "Remove this document from the collection"))
    }
}

// MARK: - CollectionProseRow

/// An editable editorial prose block in the collection — rich text (Phase 3b). Shared by the
/// iOS editor and the macOS manager. `onDelete`, when provided, renders an inline delete
/// control (see ``CollectionHeadingRow``). Bold/italic/underline/colour are edited with the
/// native text view and stored as RTF on the entry.
struct CollectionProseRow: View {
    @Binding var entry: CollectionEntry
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.caption)
                .foregroundStyle(.secondary)
            RichTextEditor(initialRTF: entry.richText, plainFallback: entry.text ?? "") { rtf, plain in
                entry.richText = rtf
                entry.text = plain
            }
            .frame(minHeight: 60, maxHeight: 220)
            structuralDeleteButton(onDelete)
        }
        .padding(.vertical, 4)
        // A pre-RTF (Phase 3b) entry stores its body as a JSON-encoded AttributedString;
        // heal it to RTF on load so exports, sync, and .fruscollection files see RTF.
        // The editor itself decodes either format, so display doesn't depend on this.
        .onAppear { ProseRichText.migrateLegacyJSONIfNeeded(entry) }
    }
}

// MARK: - CollectionExcerptRow

/// A frozen-quotation entry in the collection (Authoring Phase 5). Shared by the iOS
/// editor and the macOS manager: a quote-styled row showing the passage preview, a
/// provenance caption (document id · volume title), and the source highlight's colour
/// chip when known. Movable and deletable like a prose block; deliberately offers no
/// body-depth or note controls — the excerpt's content is its frozen `text`, edited
/// nowhere (decision A9: the verbatim passage is the rendering source of truth).
///
/// Version history:
///   1.0 — Authoring Phase 5 (excerpts): initial implementation
struct CollectionExcerptRow: View {
    /// The `.excerpt` entry being displayed (read-only; excerpts are never edited in place).
    let entry: CollectionEntry
    /// The containing volume's display title from the manifest. `nil` falls back to the
    /// volume id.
    var volumeTitle: String? = nil
    /// Deletes the entry — macOS supplies it for the inline trash (its List has no
    /// swipe-to-delete); iOS omits it (swipe handles deletion).
    var onDelete: (() -> Void)? = nil

    /// The source highlight's colour, when the excerpt was created from one.
    private var accentColor: DocumentHighlight.Color? {
        entry.excerptColorTag.flatMap { DocumentHighlight.Color(rawValue: $0) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.quote")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text ?? "")
                    .font(.callout.italic())
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if let color = accentColor {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel(color.displayName)
                    }
                    Text([entry.documentId.isEmpty ? nil : entry.documentId,
                          volumeTitle ?? (entry.volumeId.isEmpty ? nil : entry.volumeId)]
                        .compactMap(\.self)
                        .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            structuralDeleteButton(onDelete)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "collection.entry.excerpt.accessibility",
                                   defaultValue: "Excerpt from \(entry.documentId): \(entry.text ?? "")"))
    }
}

// MARK: - CollectionGeneratedEntryRow

/// A placeable generated apparatus block in the collection (Authoring Phase 6). Shared
/// by the iOS editor and the macOS manager: a distinct row showing the block type's
/// icon and title with an honest "resolves at export and in the preview" caption.
/// Movable and deletable like a prose block; deliberately offers no body-depth or
/// inspector controls — the block's content is computed from the collection's resolved
/// document set at every resolve, never authored or stored.
///
/// An entry whose `generatedBlockType` this build doesn't know (written by a newer app
/// version) renders a fallback "Unsupported block" presentation; the resolver skips it,
/// so it degrades to an inert placement marker rather than junk output. Deleting it is
/// allowed — the entry carries only its type string, and the newer build can re-add it.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): initial implementation
struct CollectionGeneratedEntryRow: View {
    /// The `.generated` entry being displayed (read-only; blocks have no editable content).
    let entry: CollectionEntry
    /// Deletes the entry — macOS supplies it for the inline trash (its List has no
    /// swipe-to-delete); iOS omits it (swipe handles deletion).
    var onDelete: (() -> Void)? = nil

    /// The typed block type, when this build knows the stored raw value.
    private var blockType: CollectionGeneratedBlockType? {
        entry.generatedBlockType.flatMap { CollectionGeneratedBlockType(rawValue: $0) }
    }

    /// The row title: the block type's display name, or the unsupported fallback.
    private var title: String {
        blockType?.displayName
            ?? String(localized: "collection.entry.generated.unsupported",
                      defaultValue: "Unsupported block")
    }

    /// The row caption: the honest resolution note, or the update hint for an unknown type.
    private var caption: String {
        blockType != nil
            ? String(localized: "collection.entry.generated.caption",
                     defaultValue: "Generated from this collection's documents at export and in the preview.")
            : String(localized: "collection.entry.generated.unsupported.detail",
                     defaultValue: "Update FRUS Explorer to resolve this block.")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: blockType?.systemImage ?? "questionmark.square.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            structuralDeleteButton(onDelete)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "collection.entry.generated.accessibility",
                                   defaultValue: "Generated block: \(title)"))
    }
}

// MARK: - EntryRow

/// A single row in the documents list that lets the user configure per-entry export options.
///
/// Users can:
/// - Toggle whether the document body is included in the export.
/// - Select zero or more research notes to include alongside the document.
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections
///          Authoring Phase 1)
///   1.1 — Authoring Phase 3: `isDuplicate` flag renders the subtle "Also in collection"
///          badge when the same document appears on more than one entry (A4)
///   1.2 — Authoring Phase 5 (excerpts): `onInsertExcerpt` threads the editors' append
///          action into the inspector's per-highlight "Insert as Excerpt" rows
struct EntryRow: View {
    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]
    /// The document's header/title from the indexed cache, when the volume is indexed
    /// (Authoring Phase 1 row parity with `MacEntryRow`). `nil` falls back to the id.
    var documentHeader: String? = nil
    /// The containing volume's display title from the manifest. `nil` falls back to the
    /// volume id.
    var volumeTitle: String? = nil
    /// The document's ISO date (`date_iso`) from the index, shown alongside the volume.
    var documentDate: String? = nil
    /// Whether this document appears on more than one entry of the collection — shows
    /// the subtle "Also in collection" badge (A4, duplicates allowed).
    var isDuplicate: Bool = false
    /// Appends an excerpt entry to the owning collection (Authoring Phase 5) — supplied
    /// by the editor so the inspector's "Insert as Excerpt" keeps the pane's entry list
    /// in sync. `nil` hides the inspector's insert affordance.
    var onInsertExcerpt: ((CollectionExcerptCapture) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @State private var showInspector = false

    /// This entry's body-depth override (`nil` = follow the collection default).
    private var bodyDepthOverride: Binding<String?> {
        Binding(get: { entry.bodyDepthOverride }, set: { entry.bodyDepthOverride = $0 })
    }

    /// Depths offered here: those available on this device, plus the entry's current override
    /// even when it isn't otherwise offered (a synced `.summaryOnly` on an AI-less device).
    private var entryDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        if let raw = entry.bodyDepthOverride, let d = CollectionBodyDepth(rawValue: raw),
           !available.contains(d) {
            return available + [d]
        }
        return available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Document identity + inspector affordance. The indexed header is the primary
            // line when available; the raw id remains the fallback for unindexed volumes.
            HStack(alignment: .firstTextBaseline) {
                Text(documentHeader ?? entry.documentId)
                    .font(.body)
                    .lineLimit(2)
                    .accessibilityLabel(
                        String(localized: "collection.entry.document.accessibility",
                               defaultValue: "Document \(documentHeader ?? entry.documentId)")
                    )
                Spacer(minLength: 8)
                Button {
                    showInspector = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "collection.entry.inspect",
                                           defaultValue: "Document details"))
            }

            // Volume context (+ document id and date when the header is shown above, so
            // the citation stays checkable at a glance).
            Text([
                documentHeader != nil ? entry.documentId : nil,
                volumeTitle ?? entry.volumeId,
                documentDate,
            ].compactMap(\.self).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Duplicate marker (A4): the same document appears on another entry.
            if isDuplicate {
                Label(String(localized: "collection.entry.duplicate",
                             defaultValue: "Also in collection"),
                      systemImage: "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Per-entry body depth (overrides the collection default for this document)
            Picker(selection: bodyDepthOverride) {
                Text(String(localized: "collection.entry.bodyDepth.default",
                            defaultValue: "Default")).tag(String?.none)
                ForEach(entryDepthOptions) { Text($0.displayName).tag(String?.some($0.rawValue)) }
            } label: {
                Text(String(localized: "collection.entry.bodyDepth.label",
                            defaultValue: "Body depth"))
            }
            .pickerStyle(.menu)
            .font(.caption)

            // Per-note selection (multi-select)
            if !availableNotes.isEmpty {
                Text(String(localized: "collection.entry.notes.header",
                            defaultValue: "Include notes:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(availableNotes) { note in
                        let isOn = Binding<Bool>(
                            get: {
                                // Prefer selectedNoteIds when non-empty; fall back to researchNoteId.
                                if !entry.selectedNoteIds.isEmpty {
                                    return entry.selectedNoteIds.contains(note.id)
                                }
                                return entry.researchNoteId == note.id
                            },
                            set: { include in
                                // Migrate from legacy single-note to multi-note on first edit.
                                if entry.selectedNoteIds.isEmpty, let legacy = entry.researchNoteId {
                                    entry.selectedNoteIds = [legacy]
                                    entry.researchNoteId = nil
                                }
                                if include {
                                    if !entry.selectedNoteIds.contains(note.id) {
                                        entry.selectedNoteIds.append(note.id)
                                    }
                                } else {
                                    entry.selectedNoteIds.removeAll { $0 == note.id }
                                }
                            }
                        )
                        Toggle(isOn: isOn) {
                            Text(noteLabel(note))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showInspector) {
            CollectionEntryInspector(entry: entry, onInsertExcerpt: onInsertExcerpt)
                .environment(appState)
        }
    }

    private func noteLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? String(localized: "collection.entry.note.emptyPreview",
                                        defaultValue: "Untitled Note") : String(preview)
    }
}

// MARK: - UnrecognizedEntryRow

/// Inert placeholder for an entry whose `kind` was written by a newer app version
/// (`CollectionEntryKind.unrecognized`). Shown by both managers so a future entry kind
/// synced via CloudKit degrades to an explanatory row instead of a junk document row.
/// Deliberately offers no controls: the entry's data belongs to the newer build, so this
/// build must neither edit nor delete it (Authoring Phase 1 sync guard).
///
/// Version history:
///   1.0 — Authoring Phase 1 (Session 2026-07-02)
struct UnrecognizedEntryRow: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "collection.entry.unrecognized.title",
                            defaultValue: "Unsupported entry"))
                    .font(.callout)
                Text(String(localized: "collection.entry.unrecognized.detail",
                            defaultValue: "Update FRUS Explorer to view this entry."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
