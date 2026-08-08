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
///   1.3 — Session 2026-07-04 (macOS UI audit B8): optional `onInspect` — the macOS
///          manager passes it so the section-defaults inspector opens in the pane's
///          trailing `.inspector` column (matching document rows) instead of the
///          local sheet; `nil` (the iOS editor) keeps the sheet unchanged
///   1.4 — Session 2026-07-04 (UI audit A4): `onMoveUp`/`onMoveDown` — Move Up /
///          Move Down as VoiceOver `accessibilityAction`s and section context-menu
///          items, so reordering doesn't require the drag gesture
///   (file) Authoring Phase 5 (excerpts): `CollectionExcerptRow` added below
///   (file) Authoring Phase 6 (generated apparatus): `CollectionGeneratedEntryRow` added below
///   (file) UI audit A4 (2026-07-04): shared Move Up / Move Down helpers
///          (`entryMoveContextMenuItems`, `View.entryMoveControls`) added beside
///          `structuralDeleteButton`; every row type gained the optional closures
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
    /// Shows the section-defaults inspector in the presenting pane's trailing
    /// `.inspector` column (UI audit B8) — the macOS manager supplies it; `nil`
    /// (the iOS editor) presents the local `CollectionEntryInspector` sheet instead.
    var onInspect: (() -> Void)? = nil
    /// Moves the section (heading + contents) one visible position up (UI audit A4);
    /// `nil` (first row) omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the section one visible position down (UI audit A4); `nil` (last row)
    /// omits the action.
    var onMoveDown: (() -> Void)? = nil

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
                // Section-defaults inspector (Authoring Phase 5): the heading variant of the entry
                // inspector, cascading overrides to the section's documents. B8: the macOS manager
                // routes it into its inspector column via onInspect. Composer v2 §D: a labeled
                // Configure pill, never an info glyph.
                ConfigurePill(label: String(localized: "collection.section.configure",
                                            defaultValue: "Section defaults")) {
                    if let onInspect { onInspect() } else { showSectionInspector = true }
                }
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
        // A4: VoiceOver Move Up / Move Down (menu items live in sectionContextMenu).
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown,
                           includesContextMenu: false)
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
            if let onInspect { onInspect() } else { showSectionInspector = true }
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
        // A4: reorder without the drag gesture (shared items; the section moves whole).
        entryMoveContextMenuItems(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
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
/// `onDelete` is `nil`. Carries an explicit localized accessibility label (UI audit A10)
/// so VoiceOver doesn't fall back to the SF Symbol's inferred name.
@MainActor @ViewBuilder
func structuralDeleteButton(_ onDelete: (() -> Void)?) -> some View {
    if let onDelete {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Image(systemName: "trash").foregroundStyle(.red.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "collection.entry.delete.a11y",
                                   defaultValue: "Remove entry"))
        .help(String(localized: "collection.entry.delete.help",
                     defaultValue: "Remove this document from the collection"))
    }
}

// MARK: - Configure trigger (Composer v2 §D)

/// The labeled **Configure** control that opens a row's per-entry inspector (Composer v2 §D):
/// an accent-tinted pill with a `slider.horizontal.3` glyph and a visible label — never a bare
/// `ⓘ` info glyph, which reads as "more information" rather than "you can act here." `ⓘ` /
/// `FeatureInfoButton` stays reserved for *explanatory* help popovers, not for opening editors.
///
/// The trigger is one affordance across platforms; the presenting editor decides the surface
/// (a sheet on iPad, a trailing `.inspector` on Mac, a pushed screen on iPhone).
///
/// Version history:
///   1.0 — Composer v2 §D: labeled Configure trigger replaces the info-glyph editor openers
struct ConfigurePill: View {
    /// The pill's label — "Configure" on a document row, "Section defaults" on a heading row.
    var label: String = String(localized: "collection.entry.configure", defaultValue: "Configure")
    /// Opens the per-entry inspector for the row.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(FRUSTheme.overrideChipForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FRUSTheme.overrideChipBackground, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Move Up / Move Down (UI audit A4)

/// Localized title for the shared Move Up action (UI audit A4).
@MainActor
private var entryMoveUpTitle: String {
    String(localized: "collection.entry.moveUp", defaultValue: "Move Up")
}

/// Localized title for the shared Move Down action (UI audit A4).
@MainActor
private var entryMoveDownTitle: String {
    String(localized: "collection.entry.moveDown", defaultValue: "Move Down")
}

/// Context-menu items for the shared Move Up / Move Down reorder actions (UI audit A4).
/// The heading row splices these into its existing section context menu; the other row
/// types get them via ``SwiftUICore/View/entryMoveControls(onMoveUp:onMoveDown:includesContextMenu:)``.
/// A `nil` closure (edge of the outline, or a presentation without reordering) omits its item.
@MainActor @ViewBuilder
func entryMoveContextMenuItems(onMoveUp: (() -> Void)?,
                               onMoveDown: (() -> Void)?) -> some View {
    if let onMoveUp {
        Button(action: onMoveUp) {
            Label(entryMoveUpTitle, systemImage: "arrow.up")
        }
    }
    if let onMoveDown {
        Button(action: onMoveDown) {
            Label(entryMoveDownTitle, systemImage: "arrow.down")
        }
    }
}

/// Adds the named VoiceOver actions (and, unless suppressed, a context menu) that make
/// outline reordering possible without drag gestures (UI audit A4): drag handles and
/// `onMove` are invisible to VoiceOver, so every entry row exposes Move Up / Move Down
/// as `accessibilityAction`s wired to the editors' shared move engine.
///
/// Version history:
///   1.0 — Session 2026-07-04 (UI audit A4): initial implementation
private struct EntryMoveControls: ViewModifier {
    /// Moves the row one visible position up; `nil` (first row) omits the action.
    let onMoveUp: (() -> Void)?
    /// Moves the row (a heading: its whole section) one visible position down; `nil`
    /// (last row) omits the action.
    let onMoveDown: (() -> Void)?
    /// Whether to also attach a context menu with the same items. The heading row
    /// passes `false` — it splices `entryMoveContextMenuItems` into its own section
    /// context menu instead (a second `.contextMenu` would replace the first).
    let includesContextMenu: Bool

    func body(content: Content) -> some View {
        if onMoveUp == nil && onMoveDown == nil {
            content
        } else {
            withMenu(content)
                .accessibilityAction(named: Text(entryMoveUpTitle)) { onMoveUp?() }
                .accessibilityAction(named: Text(entryMoveDownTitle)) { onMoveDown?() }
        }
    }

    /// Attaches the reorder context menu when requested.
    @ViewBuilder
    private func withMenu(_ content: Content) -> some View {
        if includesContextMenu {
            content.contextMenu {
                entryMoveContextMenuItems(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Shared Move Up / Move Down reorder affordances for collection entry rows
    /// (UI audit A4): named VoiceOver actions plus (optionally) a context menu with
    /// the same items. See ``EntryMoveControls``.
    ///
    /// - Parameters:
    ///   - onMoveUp: Moves the row one visible position up; `nil` omits the action.
    ///   - onMoveDown: Moves the row one visible position down; `nil` omits the action.
    ///   - includesContextMenu: Pass `false` when the row already has a context menu
    ///     and splices `entryMoveContextMenuItems` into it itself (the heading row).
    @MainActor
    func entryMoveControls(onMoveUp: (() -> Void)?,
                           onMoveDown: (() -> Void)?,
                           includesContextMenu: Bool = true) -> some View {
        modifier(EntryMoveControls(onMoveUp: onMoveUp,
                                   onMoveDown: onMoveDown,
                                   includesContextMenu: includesContextMenu))
    }
}

// MARK: - CollectionProseRow

/// An editable editorial prose block in the collection — rich text (Phase 3b). Shared by the
/// iOS editor and the macOS manager. `onDelete`, when provided, renders an inline delete
/// control (see ``CollectionHeadingRow``). Bold/italic/underline/colour are edited with the
/// native text view and stored as RTF on the entry.
///
/// Version history:
///   1.0 — Authoring Phase 3b (rich text)
///   1.1 — Session 2026-07-04 (UI audit A4): `onMoveUp`/`onMoveDown` reorder actions
///          via the shared `entryMoveControls`
struct CollectionProseRow: View {
    @Binding var entry: CollectionEntry
    var onDelete: (() -> Void)? = nil
    /// Moves the row one visible position up (UI audit A4); `nil` omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the row one visible position down (UI audit A4); `nil` omits the action.
    var onMoveDown: (() -> Void)? = nil

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
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
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
///   1.1 — Session 2026-07-04 (UI audit A4): `onMoveUp`/`onMoveDown` reorder actions
///          via the shared `entryMoveControls`
struct CollectionExcerptRow: View {
    /// The `.excerpt` entry being displayed (read-only; excerpts are never edited in place).
    let entry: CollectionEntry
    /// The containing volume's display title from the manifest. `nil` falls back to the
    /// volume id.
    var volumeTitle: String? = nil
    /// Deletes the entry — macOS supplies it for the inline trash (its List has no
    /// swipe-to-delete); iOS omits it (swipe handles deletion).
    var onDelete: (() -> Void)? = nil
    /// Moves the row one visible position up (UI audit A4); `nil` omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the row one visible position down (UI audit A4); `nil` omits the action.
    var onMoveDown: (() -> Void)? = nil

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
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
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
///   1.1 — Authoring Phase 6 (blocks): `documentCount` live subtitle for the
///          document-driven blocks (bibliography/chronology)
///   1.2 — Session 2026-07-04 (UI audit A4): `onMoveUp`/`onMoveDown` reorder actions
///          via the shared `entryMoveControls`
struct CollectionGeneratedEntryRow: View {
    /// The `.generated` entry being displayed (read-only; blocks have no editable content).
    let entry: CollectionEntry
    /// The collection's current document-entry count, shown as a live "Lists N documents"
    /// subtitle for the document-driven blocks (bibliography/chronology) — the one count
    /// the editors already have for free. The other blocks' row counts (persons, tags,
    /// archival groups) require the resolution queries themselves, so their rows show
    /// only the type caption (documented choice — no speculative count caching).
    var documentCount: Int? = nil
    /// Deletes the entry — macOS supplies it for the inline trash (its List has no
    /// swipe-to-delete); iOS omits it (swipe handles deletion).
    var onDelete: (() -> Void)? = nil
    /// Moves the row one visible position up (UI audit A4); `nil` omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the row one visible position down (UI audit A4); `nil` omits the action.
    var onMoveDown: (() -> Void)? = nil

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

    /// The row caption: the honest resolution note — prefixed with the live document
    /// count for the document-driven blocks — or the update hint for an unknown type.
    private var caption: String {
        guard let type = blockType else {
            return String(localized: "collection.entry.generated.unsupported.detail",
                          defaultValue: "Update FRUS Explorer to resolve this block.")
        }
        let base = String(localized: "collection.entry.generated.caption",
                          defaultValue: "Generated from this collection's documents at export and in the preview.")
        // Bibliography/chronology rows are one-per-document, so the entry count IS the
        // block's row count; the other blocks would need real resolution to count.
        if let count = documentCount, type == .bibliography || type == .chronology {
            let counted = String(localized: "collection.entry.generated.documentCount",
                                 defaultValue: "Lists \(count) document\(count == 1 ? "" : "s").")
            return "\(counted) \(base)"
        }
        return base
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
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
    }
}

// MARK: - EntryRow

/// A single **reporting** row in the documents list (Collections Manager M2, D3): the
/// document's identity plus read-only status chips projecting its per-entry export
/// configuration. All editing routes to the shared `CollectionEntryInspector` via the ⓘ
/// button — on iPhone the presenting editor opens it as a `.sheet`, on iPad as a trailing
/// system `.inspector` column (selection-driven, matching macOS). The row keeps only the
/// navigational/structural affordances: ⓘ inspect and the A4 Move Up / Move Down actions
/// (delete stays on swipe in the owning `List`).
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections
///          Authoring Phase 1)
///   1.1 — Authoring Phase 3: `isDuplicate` flag renders the subtle "Also in collection"
///          badge when the same document appears on more than one entry (A4)
///   1.2 — Authoring Phase 5 (excerpts): `onInsertExcerpt` threads the editors' append
///          action into the inspector's per-highlight "Insert as Excerpt" rows
///   1.3 — Session 2026-07-04 (UI audit A4): `onMoveUp`/`onMoveDown` reorder actions
///          via the shared `entryMoveControls`
///   1.4 — Collections Manager M2 (D3): the row became **pure reporting**. The inline
///          body-depth Picker and per-note toggle list moved into the inspector; the
///          row now shows read-only status chips and delegates opening the inspector to
///          the presenting editor via `onInspect` (so iPad can promote the sheet to an
///          `.inspector` column). `onInsertExcerpt`/`showInspector`/`appState` moved out
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
    /// Opens the per-entry inspector for this row (Collections Manager M2, D3). The
    /// presenting editor decides the surface: an iPhone `.sheet` or an iPad selection-
    /// driven `.inspector` column.
    var onInspect: () -> Void

    /// Opens this entry's document in the app's reader (#755 / audit M-18, M-19).
    ///
    /// A separate action rather than a change to the row tap: the tap has opened the configure
    /// inspector since Composer v2 §D, and researchers rely on it. What was missing was any route
    /// at all — the Collections module contained no `openDocument`, `openBrowseDocument` or
    /// `DocumentView` reference anywhere, making it the only document list in the app with no way
    /// into the reader. Every other one (search, history, chronology, research, graph, related,
    /// neighbours) opens it.
    var onOpenDocument: (() -> Void)? = nil
    /// Whether to render the trailing **⚙ Configure** pill (Composer v2 §D). `true` on the iPad
    /// (regular-width) rows where the pill is the labeled configure trigger; `false` on the iPhone
    /// (compact) drill-in rows, where the whole-row disclosure is the trigger, so the row shows a
    /// chevron accessory instead — matching the §C iPhone canvas.
    var showsConfigurePill: Bool = true
    /// Moves the row one visible position up (UI audit A4); `nil` omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the row one visible position down (UI audit A4); `nil` omits the action.
    var onMoveDown: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                // Document identity. The indexed header is the primary line when available; the
                // raw id remains the fallback for unindexed volumes.
                Text(documentHeader ?? entry.documentId)
                    .font(.body)
                    .lineLimit(2)
                    .accessibilityLabel(
                        String(localized: "collection.entry.document.accessibility",
                               defaultValue: "Document \(documentHeader ?? entry.documentId)")
                    )

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

                // Labeled override chips (Composer v2 §3): body depth, note count, and override
                // flags project the inspector's state — text-only pills, shown only when a value
                // differs from the collection default, so an untouched row stays clean.
                BreadcrumbFlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
                    entryStatusChips(entry: entry, availableNoteCount: availableNotes.count)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Configure trigger (Composer v2 §D). iPad (regular): the labeled ⚙ Configure pill.
            // iPhone (compact): the whole-row disclosure is the trigger, so show a chevron accessory
            // instead of the pill — matching the §C drill-in canvas.
            if showsConfigurePill {
                ConfigurePill(action: onInspect)
            } else {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        // Whole-row tap focuses the inspector on this document (#188-E). `.contentShape` makes the
        // padding/Spacer regions hit-testable; the Configure Button (when shown) consumes its own tap
        // first, so there is no double-fire, and a discrete tap does not swallow swipe-to-delete.
        .contentShape(Rectangle())
        .onTapGesture { onInspect() }
        // #755: the reader route. Long-press rather than tap, so the established configure gesture
        // is untouched; also exposed as a VoiceOver action, since a context menu alone is not.
        .contextMenu {
            if let onOpenDocument {
                Button {
                    onOpenDocument()
                } label: {
                    Label(String(localized: "collection.entry.openDocument",
                                 defaultValue: "Open Document"),
                          systemImage: "book.pages")
                }
            }
        }
        .accessibilityAction(named: Text(String(localized: "collection.entry.openDocument",
                                                defaultValue: "Open Document"))) {
            onOpenDocument?()
        }
        // Without the pill (iPhone) the row itself is the configure control: merge its children into
        // one focusable button and bridge VoiceOver activation to `onInspect` — a bare
        // `.onTapGesture` is not exposed to VoiceOver. With the pill (iPad) the `ConfigurePill` is
        // already the labeled a11y button, so the row's children stay individually navigable.
        .modifier(EntryRowConfigureAccessibility(enabled: !showsConfigurePill, action: onInspect))
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
    }
}

/// Accessibility grouping for the pill-less (iPhone drill-in) `EntryRow`: collapses the row's
/// identity + status chips into a single focusable **button** and wires VoiceOver activation to the
/// configure action, since a bare `.onTapGesture` is not surfaced to VoiceOver. Inert on the pill
/// path — the `ConfigurePill` is already a labeled button and the row stays child-navigable.
private struct EntryRowConfigureAccessibility: ViewModifier {
    /// Whether to apply the button grouping (true on the iPhone chevron rows).
    let enabled: Bool
    /// The configure action VoiceOver activation invokes.
    let action: () -> Void
    func body(content: Content) -> some View {
        if enabled {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text(String(localized: "collection.entry.configure.hint",
                                                defaultValue: "Opens this document's settings")))
                .accessibilityAction { action() }
        } else {
            content
        }
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

// MARK: - Entry status chips (Collections Manager M2, D3)

/// One quiet, read-only status chip projecting a slice of a document entry's inspector
/// state onto the (now pure-reporting) row, so the collection list stays scannable
/// while still communicating configuration at a glance (Collections Manager M2, D3).
/// Compact and capsule-styled; never a control — every edit routes to the inspector.
///
/// Version history:
///   1.0 — Collections Manager M2 (D3): initial implementation
struct EntryStatusChip: View {
    /// The chip's short localized label.
    let text: String

    var body: some View {
        // Text-only accent-tinted pill (Composer v2 §3): a *labeled* override chip, never an icon
        // tile — the word alone ("Summary", "7 notes", "Headnote") carries the meaning, matching the
        // redesign's managed-disclosure rule that document rows show only labeled chips.
        Text(text)
            .font(.caption2)
            .foregroundStyle(FRUSTheme.overrideChipForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(FRUSTheme.overrideChipBackground, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .combine)
    }
}

/// Whether a document entry's headnote is **resolved on** — its own explicit `includeHeadnote`
/// override if set, else the owning collection's `defaultIncludeHeadnote` (Composer redesign 3).
/// Mirrors the resolver's two-tier headnote cascade (there is no section-level headnote override),
/// so the row's Headnote chip reflects what will actually export, including an inherited default.
@MainActor
func collectionEntryHeadnoteIsResolvedOn(_ entry: CollectionEntry) -> Bool {
    entry.includeHeadnote ?? entry.collection?.defaultIncludeHeadnote ?? false
}

/// The read-only status chips for one **document** entry — body depth (when overridden),
/// the research-note projection (effective count, or "Notes off" when notes are turned off
/// for the entry), and the override flags (highlights off, headnote, see-also). Shared by
/// `MacEntryRow` (macOS) and `EntryRow` (iOS) so both rows report identically (Collections
/// Manager M2, D3). Emits nothing when the entry is at its defaults, keeping an untouched
/// row clean.
///
/// - Parameters:
///   - entry: The document entry whose configuration is projected.
///   - availableNoteCount: How many research notes the document has — used to size the
///     note-count chip in the empty-`selectedNoteIds` (= all) case (D5).
@MainActor @ViewBuilder
func entryStatusChips(entry: CollectionEntry, availableNoteCount: Int) -> some View {
    // Body depth — only when the entry overrides the collection/section default. The chip uses the
    // short label ("Summary", not "Summary only"), which reads cleanly in a wrapping pill row.
    if let raw = entry.bodyDepthOverride,
       let depth = CollectionBodyDepth(rawValue: raw) {
        EntryStatusChip(text: depth.chipLabel)
    }

    // Research notes: when the entry has turned notes off (D5 uncheck-last end state, or
    // an explicit override) no notes export, so report "Notes off" — mirroring the
    // "Highlights off" chip — rather than a misleading count. Otherwise show the effective
    // note count (D5 semantics): explicit selection wins; else the legacy single-note link
    // counts as one; else empty = all of the document's notes.
    if entry.includeNotesOverride == false {
        EntryStatusChip(
            text: String(localized: "collection.entry.chip.notesOff",
                         defaultValue: "Notes off"))
    } else {
        let noteCount: Int = {
            if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.count }
            if entry.researchNoteId != nil { return 1 }
            return availableNoteCount
        }()
        if noteCount > 0 {
            // Proper singular/plural: "1 note" vs "7 notes" (the earlier "%lld notes" printed
            // "1 notes"; the prototype's "1 documents" is likewise a mock bug not to replicate).
            EntryStatusChip(
                text: noteCount == 1
                    ? String(localized: "collection.entry.chip.notes.one", defaultValue: "1 note")
                    : String(format: String(localized: "collection.entry.chip.notes.other %lld",
                                            defaultValue: "%lld notes"),
                             Int64(noteCount)))
        }
    }

    // Highlights explicitly turned off for this entry.
    if entry.applyHighlightsOverride == false {
        EntryStatusChip(
            text: String(localized: "collection.entry.chip.highlightsOff",
                         defaultValue: "Highlights off"))
    }

    // Headnote — resolution-aware (Composer redesign 3): the chip shows whenever a headnote will
    // actually export for this document, whether opted in explicitly per-entry or inherited from the
    // collection's `defaultIncludeHeadnote`.
    if collectionEntryHeadnoteIsResolvedOn(entry) {
        EntryStatusChip(
            text: String(localized: "collection.entry.chip.headnote",
                         defaultValue: "Headnote"))
    }

    // Related-documents "See also" line opted in.
    if entry.includeRelatedDocuments == true {
        EntryStatusChip(
            text: String(localized: "collection.entry.chip.seeAlso",
                         defaultValue: "See also"))
    }
}

// MARK: - InlineNoteCreateSheet

/// Focused sheet for creating a new `ResearchNote` from within a collection editor. For
/// full note editing (tags, projects, summaries) use `ResearchNoteEditorView` from the
/// document view. Shared by the macOS manager and the iOS `CollectionEditorView` — the
/// per-entry inspector's "New Note…" affordance (Collections Manager M2, D5).
///
/// Version history:
///   1.0 — extracted from MacCollectionManagerView (Collections Manager M2): made
///          cross-platform + localized so the iOS editor's inspector can open it too
struct InlineNoteCreateSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// The document the note is filed under.
    let documentId: String
    /// The document's volume.
    let volumeId: String
    /// The active project to file the note under, if any.
    let activeProjectId: UUID?
    /// Called with the newly created note after it is inserted and indexed.
    let onCreated: (ResearchNote) -> Void

    @State private var bodyText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "collection.entry.newNote.title",
                            defaultValue: "New Research Note")).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            TextEditor(text: $bodyText)
                .font(.body)
                .padding(12)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "collection.entry.newNote.save",
                              defaultValue: "Save Note")) {
                    let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = ResearchNote(
                        documentId: documentId,
                        volumeId: volumeId,
                        bodyText: trimmed,
                        projectIds: activeProjectId.map { [$0] } ?? []
                    )
                    modelContext.insert(note)
                    try? modelContext.save()   // ensure Research window @Query updates promptly
                    // Push immediately so note text is searchable in this session.
                    if let pipeline = appState.indexingPipeline {
                        let vid = volumeId
                        let did = documentId
                        // Text only. Passing `userTagIds: nil` here used to set the
                        // document's `user_tag_ids` to NULL — and that column is per
                        // document, not per note, so creating an untagged note erased tags
                        // another note on the same document had contributed. They came back
                        // at the next launch's push, which is why it was invisible.
                        Task { try? await pipeline.updateNoteText(
                            volumeId: vid, documentId: did, bodyText: trimmed
                        ) }
                    }
                    onCreated(note)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 440, minHeight: 280)
    }
}
