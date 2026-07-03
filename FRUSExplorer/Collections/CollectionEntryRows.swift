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

    /// The section context menu: rename, indent/outdent, and the two delete flavors.
    @ViewBuilder
    private var sectionContextMenu: some View {
        Button {
            titleFocused = true
        } label: {
            Label(String(localized: "collection.section.rename", defaultValue: "Rename"),
                  systemImage: "pencil")
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
            CollectionEntryInspector(entry: entry)
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
