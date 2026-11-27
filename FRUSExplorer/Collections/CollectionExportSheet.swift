// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ExportSheetView

/// Picker + progress view that runs the chosen exporter and presents a share sheet.
///
/// Content resolution lives in `CollectionContentResolver` — this sheet is purely
/// format selection, progress feedback, and file delivery.
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.1 — Session 2026-07-02 (Collections Authoring Phase 2a): all resolution
///          (`resolveItems`, `resolveDocuments`, `resolveSmartDocuments`, `resolveSummaries`,
///          `prepareVolumes`, render-model helpers, `SmartEntry`) moved to
///          `CollectionContentResolver`; smart and static exports share one resolve path
///   1.2 — Wave R-2a: the four `appState.logEvent(.export(…))` calls became one `recordExport`
///          helper writing an `ExportHistoryEntry` through `ExportHistoryRecorder`. The record
///          gained the collection's name and the active project, neither of which the retired
///          `SessionEvent` payload carried
///   1.3 — #1463: the rendered formats' metadata comes from `CollectionExportMetadata.forExport`,
///          which the preview calls too, and the native file is written by
///          `NativeCollectionSerializer.writeTemporaryFile(_:)`; both name an unnamed collection
///          "Untitled Collection" through `CollectionExportNaming`
///   1.4 — #1497: Send to Zotero Library names its Zotero collection through
///          `CollectionExportNaming.zoteroCollectionName` — trimmed, or "FRUS Explorer Collection - yyyy-mm-dd"
///   1.5 — 2026-10-09: #1585 — the exporter's options come from `ExportFormat.exportOptions(for:)`
///          where the sheet built them itself, asking for the word cloud of PDF and HTML only; a
///          Word export now carries the cloud the Composition section turned on
///   1.6 — L29 (#2000): Send to Zotero Library posts the RIS file's records
///          (`ZoteroCollectionExporter.records(for:options:)`), each document's research notes only where
///          they print, where it posted every item as resolved and read no setting
///   1.7 — L35 (the plan of record's lane 1; J9, J11, decisions 192, 198 and DECISION_AX1): the sentence says what
///          the export will print, counted as the export reads the collection (`CollectionExportSentence`), where it
///          read the collection's defaults; before Export the sheet says what this device lacks for it; it opens on the
///          format the collection last exported as on this device (`CollectionExportFormatMemory`); on iPhone and iPad
///          Export is pinned at the foot, with the format a menu there at the accessibility sizes and the sentence no
///          larger than AX1, so it opens on its sentence, format and Export at any size; BibTeX resolves no summary,
///          which it never prints. The Collections list and Manage Collections open it (`CollectionListExportSheet`)
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    /// The reader's text size: at an accessibility size the iOS sheet chooses its format from a menu (`usesFormatMenu`).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let collection: Collection
    let entries: [CollectionEntry]
    let allNotes: [ResearchNote]
    let appState: AppState

    /// Opens the sheet for `collection` on the format it last exported as on this device (L35).
    ///
    /// - Parameters:
    ///   - collection: The collection to export.
    ///   - entries: Its entries, in their order.
    ///   - allNotes: Every research note, one copy of each.
    ///   - appState: The app's state, whose services the export resolves through.
    init(collection: Collection, entries: [CollectionEntry], allNotes: [ResearchNote], appState: AppState) {
        self.collection = collection
        self.entries = entries
        self.allNotes = allNotes
        self.appState = appState
        _selectedFormat = State(initialValue: CollectionExportFormatMemory.format(
            for: collection.id, offered: ExportFormat.gridFormats(smartCollection: collection.savedSearchId != nil)))
    }

    /// All projects, to resolve the active project for export provenance (#377 Phase 4) — mirrors
    /// the `authorLine` placeholder lookup in the collection editors.
    @Query(sort: \Project.name) private var allProjects: [Project]

    /// The active project (the source of export provenance), or `nil` in Global Context.
    private var activeProject: Project? { allProjects.first { $0.id == appState.activeProjectId } }

    /// The format chosen: the one this collection last exported as on this device as the sheet opens, else PDF.
    @State private var selectedFormat: ExportFormat
    /// What the export will print, counted as the sheet opens (`CollectionContentResolver.exportTally`); `nil` until
    /// then, and when it could not be counted.
    @State private var tally: CollectionExportTally?
    /// Why the export could not be counted, which its export would meet too: a smart collection's search not ready, or
    /// its saved search gone.
    @State private var tallyFailure: String?
    @State private var isExporting = false
    @State private var exportedURL: URL? = nil
    @State private var exportError: String? = nil

    /// The pre-export quotation check (M-3). `nil` until the check has run.
    @State private var verification: ExcerptVerificationReport?
    /// D9a privacy default: research notes are excluded from a shared `.fruscollection`
    /// file unless the user opts in here. Independent of the collection's `includeNotes`
    /// composition setting (which governs rendered exports, not shared source files).
    @State private var includeNotesInSharedFile = false
    /// Non-nil while volumes need to be downloaded/indexed before export can proceed.
    @State private var preparingMessage: String? = nil
    /// Non-nil while summaries are being generated on demand.
    @State private var summaryGeneratingMessage: String? = nil
    /// Non-nil after a successful "Send to Zotero Library" run (drives the result alert).
    @State private var zoteroResult: ZoteroSendResult? = nil

    /// The formats shown in the grid, in canvas order — the native `.fruscollection` is dropped for
    /// smart collections (D8/D9b). The web-API Zotero send is the separate `zoteroSendRow`, not a card.
    private var exportGridFormats: [ExportFormat] {
        ExportFormat.gridFormats(smartCollection: collection.savedSearchId != nil)
    }

    /// The "Export {Format}" primary-button title reflecting the selected card (Composer v2 §Export).
    private var exportButtonTitle: String {
        String(format: String(localized: "export.button.format %@", defaultValue: "Export %@"),
               selectedFormat.gridLabel)
    }

    /// What the export will print, in a sentence written from what it counts (L35, decision 192), or why it could not
    /// be counted; `nil` while it is counted.
    private var sentence: String? {
        if let tallyFailure { return tallyFailure }
        return tally.map {
            CollectionExportSentence.text(for: $0, format: selectedFormat,
                                          drawsWordCloud: selectedFormat.exportOptions(for: collection).includeWordCloud)
        }
    }

    /// What this device lacks for the export, said before Export (J11, #2018); `nil` when it lacks nothing.
    private var deviceLacks: String? {
        tally.flatMap { CollectionExportSentence.deviceLacks($0, format: selectedFormat, availability: .forExport) }
    }

    /// The sentence, then what this device lacks: the first thing the sheet says on every platform (decision 192).
    /// Until the export is counted, a spinner holds the sentence's place.
    @ViewBuilder
    private var whatWillPrint: some View {
        if let sentence {
            Text(sentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("collection.export.sentence")
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("collection.export.sentence.counting")
        }
        if let deviceLacks {
            Label {
                Text(deviceLacks)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                // The icon carries the colour; the words keep the text's, which orange on white would not keep legible.
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            // One element, the icon's and the words' frame: the identifier fell to the icon alone without it.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("collection.export.lacks")
        }
    }

    /// The footer note under the export options (Composer v2 §Export).
    private var exportFooterNote: String {
        String(localized: "export.footer.note",
               defaultValue: "Files download · Zotero sends over the web")
    }

    /// The 2-column selectable format grid (Composer v2 §Export): each card shows the format label +
    /// a one-line descriptor and marks itself with an accent border when chosen. Shared by both
    /// platform bodies.
    @ViewBuilder
    private var exportFormatGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(exportGridFormats) { fmt in
                let isSelected = fmt == selectedFormat
                Button { selectedFormat = fmt } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fmt.gridLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        Text(fmt.gridCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                      lineWidth: isSelected ? 1.5 : 0.5))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                // The format an export runs in stays chosen until it ends: it is the one remembered (L35).
                .disabled(isExporting)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(Text("\(fmt.gridLabel), \(fmt.gridCaption)"))
                .accessibilityIdentifier("collection.export.format.\(fmt.rawValue)")
            }
        }
    }

    /// Whether the iOS sheet chooses its format from a menu at its foot (`formatMenu`) rather than the grid: at the
    /// accessibility text sizes, where the grid's six cards are taller than an iPhone, and a card cut short in a
    /// column of two. The Mac's sheet keeps the grid.
    private var usesFormatMenu: Bool {
        #if os(iOS)
        dynamicTypeSize.isAccessibilitySize
        #else
        false
        #endif
    }

    /// The format as a menu, for the accessibility text sizes (`usesFormatMenu`): the grid's formats, each with its
    /// line, the chosen one ticked.
    private var formatMenu: some View {
        Picker(selection: $selectedFormat) {
            ForEach(exportGridFormats) { fmt in
                VStack(alignment: .leading) {
                    Text(fmt.gridLabel)
                    Text(fmt.gridCaption)
                }
                .tag(fmt)
            }
        } label: {
            Text(String(localized: "export.format.menu", defaultValue: "Format"))
        }
        .pickerStyle(.menu)
        .disabled(isExporting)
        .accessibilityIdentifier("collection.export.format.menu")
    }

    /// The separated "Send to Zotero Library" row (Composer v2 §Export): the annotation-preserving
    /// web-API send when connected, with the RIS-file fallback otherwise — distinct from the RIS
    /// grid card (a plain file). Shared by both platform bodies.
    @ViewBuilder
    private var zoteroSendRow: some View {
        Button { Task { await sendToZotero() } } label: {
            HStack(spacing: 12) {
                // Zotero brand mark (#CC2936, design tokens) — a red rounded "Z".
                Text(verbatim: "Z")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7)
                        .fill(Color(red: 0.80, green: 0.16, blue: 0.21)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "export.zotero.send", defaultValue: "Send to Zotero Library"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    // #358: the old single caption promised "falls back to an RIS file with no
                    // account" on both platforms. On iOS that fallback reaches nothing: Zotero's
                    // iOS app declares no document types for `.ris` and has no File → Import, so
                    // the file lands nowhere. Saying so is the fix; the file is still worth
                    // producing, but for a Mac.
                    Text(zoteroCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting || (entries.isEmpty && collection.savedSearchId == nil))
    }

    var body: some View {
        // One `Group` with exactly ONE child, so the modifier below applies once. (`Group`
        // applies a presentation modifier per child — harmless here, and the reason the platform
        // bodies are not siblings.) Mounted here rather than on each platform body so the
        // quotation check cannot ship on one platform and not the other, which is how #606's
        // macOS banner went missing.
        Group {
            #if os(macOS)
            macExportBody
            #else
            iOSExportBody
            #endif
        }
        .task { await verifyExcerpts() }
        .task { await countWhatWillPrint() }
    }

    /// Counts what the export will print, for the sentence (L35): the export's own reading of the collection, which
    /// parses, downloads and asks nothing (`CollectionContentResolver.exportTally`).
    private func countWhatWillPrint() async {
        do {
            tally = try await makeResolver().exportTally(collection: collection, entries: entries, allNotes: allNotes)
        } catch is CancellationError {
            return
        } catch {
            tallyFailure = error.localizedDescription
        }
    }

    // MARK: - macOS body

    /// macOS-native export dialog.
    ///
    /// Replaces the `NavigationStack { Form }` pattern used on iOS, which adds
    /// an unwanted navigation bar on macOS. Changes from the iOS layout:
    /// - Title row + Divider + content area + Divider + button bar
    /// - Format uses `.pickerStyle(.radioGroup)` — the HIG-correct control for
    ///   2–5 mutually exclusive options in a dialog body (segmented is correct
    ///   for toolbars/control strips, not dialog content areas)
    /// - Contents List uses a `LabeledContent` row with `.pickerStyle(.menu)`
    /// - Progress spinner sits inline in the button bar next to Export
    /// - Error message appears above the button bar, not in a Form section
    /// - Export is the default action (↩) via `.keyboardShortcut(.defaultAction)`
    #if os(macOS)
    private var macExportBody: some View {
        VStack(spacing: 0) {

            // Title
            Text(String(localized: "export.nav.title", defaultValue: "Export collection"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            // Options — what the export will print and what this Mac lacks for it (L35), the selectable
            // format grid, the native-file notes-privacy opt-in when `.fruscollection` is chosen, and the
            // separated "Send to a Reference Manager" Zotero row (Composer v2 §Export).
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) { whatWillPrint }

                exportFormatGrid

                if selectedFormat == .fruscollection {
                    VStack(alignment: .leading, spacing: 6) { nativeShareOptions }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "export.zotero.section",
                                defaultValue: "Send to a Reference Manager"))
                        .font(.caption).fontWeight(.semibold).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    zoteroSendRow
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.06)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Quotation check (M-3) — above the error banner, because it is a statement about
            // the work rather than about this attempt to export it.
            if let summary = verification?.summary {
                Divider()
                verificationLabel(summary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            // Inline error — shown above the button bar when present
            if let error = exportError {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                    // #358: a failed send is not a dead end — the file route is unaffected by
                    // whatever broke the API call.
                    if zoteroFileRecoveryOffered {
                        Button {
                            zoteroFileRecoveryOffered = false
                            Task { await exportZoteroRIS() }
                        } label: {
                            Label(String(localized: "export.zotero.recover",
                                         defaultValue: "Save a Zotero file instead"),
                                  systemImage: "doc.badge.arrow.up")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            Divider()

            // Button bar — footer note (left) + Export {Format} (primary, right). Zotero moved into
            // the content area as its own row (Composer v2 §Export).
            HStack(spacing: 12) {
                Button(String(localized: "export.close", defaultValue: "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Text(exportFooterNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Progress feedback — inline in the button bar when busy
                if let msg = preparingMessage ?? summaryGeneratingMessage {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(msg).font(.callout).foregroundStyle(.secondary)
                    }
                } else if isExporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "export.progress.label",
                                    defaultValue: "Exporting…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await runExport() }
                } label: {
                    Text(exportButtonTitle)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isExporting
                          || preparingMessage != nil
                          || (entries.isEmpty && collection.savedSearchId == nil))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 260)
        .sheet(item: $exportedURL) { url in
            MacExportCompleteView(url: url)
        }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
    }
    #endif

    // MARK: - iOS body

    /// iOS/iPadOS export sheet.
    ///
    /// Retains `NavigationStack { Form }` which is the correct pattern on iOS:
    /// the navigation bar provides title and Cancel/Close button placement,
    /// and the Form renders correctly as an inset-grouped table.
    ///
    /// Since L35 Export is pinned at the foot (`iOSExportBar`), with the format's menu there at the accessibility text
    /// sizes, so that the sheet opens on its sentence with the format and Export in view at any text size (J9); an
    /// export's error follows the sentence, and the form scrolls to it. 1.0 put Export in the form below the Zotero row,
    /// and below the screen from AX3 on an iPhone 17. The sentence and the line under it grow no further than
    /// `textSizeLimit` (decision DECISION_AX1): at the reader's AX5 a long one ran under the bar on an iPhone SE.
    #if os(iOS)
    private var iOSExportBody: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    // What the export will print, and what this device lacks for it (decision 192): the form opens on
                    // it, drawn no larger than AX1 (decision DECISION_AX1), so that an iPhone shows the sentence whole
                    // above the bar at every text size, with the format and Export in view there.
                    Section {
                        whatWillPrint.dynamicTypeSize(...Self.textSizeLimit)
                    }

                    // An export's failure, first, where its sentence is: below the form's fold it went unseen.
                    if let error = exportError {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.callout)
                                .id(Self.errorRowId)
                            // #358: a failed send is not a dead end — the file route is unaffected by
                            // whatever broke the API call.
                            if zoteroFileRecoveryOffered {
                                Button {
                                    zoteroFileRecoveryOffered = false
                                    Task { await exportZoteroRIS() }
                                } label: {
                                    Label(String(localized: "export.zotero.recover",
                                                 defaultValue: "Save a Zotero file instead"),
                                          systemImage: "doc.badge.arrow.up")
                                }
                            }
                        }
                    }

                    // Selectable format grid (Composer v2 §Export) — headerless, matching the canvas (the
                    // grid sits directly under the composition summary with no "Format" label) and the
                    // macOS body. At the accessibility sizes the format is the menu at the foot.
                    if !usesFormatMenu {
                        Section {
                            exportFormatGrid
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }

                    // Native `.fruscollection` file: research-notes privacy opt-in.
                    if selectedFormat == .fruscollection {
                        Section { nativeShareOptions }
                    }

                    // Separated "Send to a Reference Manager" Zotero row.
                    Section {
                        zoteroSendRow
                    } header: {
                        Text(String(localized: "export.zotero.section",
                                    defaultValue: "Send to a Reference Manager"))
                    } footer: {
                        Text(exportFooterNote)
                    }

                    if let summary = verification?.summary {
                        Section {
                            verificationLabel(summary)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { iOSExportBar }
                .onChange(of: exportError) { _, error in
                    guard error != nil else { return }
                    withAnimation { proxy.scrollTo(Self.errorRowId, anchor: .top) }
                }
            }
            .navigationTitle(String(localized: "export.nav.title", defaultValue: "Export collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "export.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exportedURL) { url in
                ShareSheet(url: url)
                    .ignoresSafeArea()
            }
            .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        }
    }

    /// The foot of the iOS sheet, pinned under the form so that it is in view however long the sheet (L35, J9): what an
    /// export is doing while it runs, else Export, which names the format; at the accessibility text sizes the format's
    /// menu above it (`usesFormatMenu`).
    ///
    /// Its text grows no further than `textSizeLimit`, as a bar's does, and a long press shows it large (the Large
    /// Content Viewer): at AX5 an iPhone SE has no room for the bar at full size and the sentence above it.
    private var iOSExportBar: some View {
        VStack(spacing: 10) {
            if usesFormatMenu {
                // A menu picker outside a form shows its choice alone, so the row names it.
                HStack {
                    Text(String(localized: "export.format.menu", defaultValue: "Format"))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Spacer(minLength: 8)
                    formatMenu
                        .labelsHidden()
                        .accessibilityShowsLargeContentViewer()
                }
            }
            if let msg = preparingMessage ?? summaryGeneratingMessage {
                exportProgress(msg)
            } else if isExporting {
                exportProgress(String(localized: "export.progress.label", defaultValue: "Exporting…"))
            } else {
                Button {
                    Task { await runExport() }
                } label: {
                    Text(exportButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(entries.isEmpty && collection.savedSearchId == nil)
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("collection.export.run")
            }
        }
        .dynamicTypeSize(...Self.textSizeLimit)
        .padding(.horizontal, 16)
        .padding(.vertical, Self.barVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collection.export.bar")
    }

    /// What an export is doing, in the bar where Export stands.
    private func exportProgress(_ message: String) -> some View {
        HStack {
            ProgressView().padding(.trailing, 8)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The largest text size the sheet's sentence and the bar at its foot are drawn at (decision DECISION_AX1).
    static let textSizeLimit: DynamicTypeSize = .accessibility1

    /// The space above and below the bar's controls.
    static let barVerticalPadding: CGFloat = 12

    /// The id of the error's row, which the form scrolls to when an export fails.
    private static let errorRowId = "collection.export.error"
    #endif // os(iOS)

    /// Runs the selected export: native `.fruscollection` files serialize the collection's
    /// source directly; every rendered format resolves content through
    /// `CollectionContentResolver` (one path for smart and static collections) and hands
    /// the resolved items to the format's exporter. An export that succeeds is the format the
    /// sheet opens on next for this collection on this device (L35, `CollectionExportFormatMemory`);
    /// the Zotero send, which runs from its own row, never is.
    private func runExport() async {
        exportError = nil
        zoteroFileRecoveryOffered = false

        switch selectedFormat {
        case .fruscollection:
            // Native shareable-collection file (D9): serialize the collection's source directly.
            runNativeExport()
        case .zoteroJSON:
            // The RIS card resolves citations only (no body/summaries/volume downloads), so route it
            // through the Zotero RIS path rather than the generic render pipeline (Composer v2 §Export).
            await exportZoteroRIS()
        case .pdf, .html, .docx, .bibtex:
            await runRenderedExport()
        }
        // A file was made: each path sets `exportedURL` when it makes one and `exportError` when it cannot, and no file
        // is in hand as Export is tapped, since the sheet that hands it over covers this one. The format cannot change
        // while an export runs (the grid and the menu are disabled then), so it is the one exported.
        if exportError == nil, exportedURL != nil {
            CollectionExportFormatMemory.remember(selectedFormat, for: collection.id)
        }
    }

    /// Exports a rendered format, or BibTeX, through the resolver and the format's exporter.
    ///
    /// BibTeX prints each document's citation and notes and nothing of its body, so it resolves the documents alone, as
    /// the RIS card and the Zotero send do (`resolvedZoteroDocuments()`): on the full path a *Summaries* collection had
    /// its summaries written for a file that prints none, and where Apple Intelligence could not write them the BibTeX
    /// export failed (L35, beside #2018).
    private func runRenderedExport() async {
        isExporting = true
        defer {
            isExporting = false
            preparingMessage = nil
            summaryGeneratingMessage = nil
        }
        do {
            let items: [CollectionExportItem]
            if selectedFormat == .bibtex {
                items = try await resolvedZoteroDocuments().map(CollectionExportItem.document)
            } else {
                // #1516: PDF, Word and HTML print a figure's image, so they fetch the ones that are not on the device.
                items = try await makeResolver().resolve(
                    collection: collection, entries: entries, allNotes: allNotes, purpose: .export,
                    printsFigureImages: selectedFormat.printsFigureImages)
            }
            let metadata = CollectionExportMetadata.forExport(
                of: collection, activeProject: activeProject, modelContext: modelContext)
            guard let exporter = selectedFormat.makeExporter() else { return }
            // #1585: the format builds the options, so Word is asked for the word cloud as PDF
            // and HTML are, and `CollectionExportParityTests` hands each exporter these same ones.
            let url = try await exporter.export(
                metadata: metadata, items: items, options: selectedFormat.exportOptions(for: collection))
            exportedURL = url
            recordExport(format: selectedFormat.rawValue,
                         documentCount: items.documents.count)
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Records a completed export in the research trail (Wave R-2a, contract D1).
    ///
    /// The four export paths below all end here rather than each inserting a row: the
    /// research-logging gate belongs in one place, and `ExportHistoryRecorder` is where the trail's
    /// other three writers keep theirs. This replaces `appState.logEvent(.export(…))`, whose
    /// `SessionEvent` store is retired.
    ///
    /// - Parameters:
    ///   - format: `ExportFormat.rawValue`, or `"zotero-api"` for the Web-API send.
    ///   - documentCount: How many documents went out.
    /// The quotation-check line, styled by what it is saying.
    ///
    /// Orange rather than red: a quotation that cannot be found is a thing to look at, not a
    /// failure of this export. Red is the export error's, and one screen with two red messages
    /// meaning different things teaches the researcher to read neither.
    @ViewBuilder
    private func verificationLabel(_ summary: String) -> some View {
        Label(summary, systemImage: verification?.hasFailures == true
              ? "exclamationmark.triangle" : "info.circle")
            .foregroundStyle(verification?.hasFailures == true ? Color.orange : Color.secondary)
            .font(.callout)
    }

    /// Checks every stored quotation in this collection against the indexed text (M-3).
    ///
    /// Runs when the sheet opens rather than on the Export button, so the researcher sees it
    /// while they still have the collection in mind — and, per decision M-3-1, it never blocks:
    /// a volume freed from disk would otherwise make an export impossible with no way through.
    private func verifyExcerpts() async {
        let requests = entries.compactMap { entry -> ExcerptVerifier.Request? in
            guard entry.entryKind == .excerpt,
                  let text = entry.text, !text.isEmpty,
                  !entry.volumeId.isEmpty, !entry.documentId.isEmpty
            else { return nil }
            return ExcerptVerifier.Request(volumeId: entry.volumeId,
                                           documentId: entry.documentId,
                                           text: text)
        }
        guard !requests.isEmpty else {
            verification = nil
            return
        }
        let keys = Set(requests.map { WordCloudDocumentKey(volumeId: $0.volumeId,
                                                           documentId: $0.documentId) })
        // A read failure is not a verdict. Treating it as "not found" would accuse the researcher's
        // quotations of being wrong because a query failed, so an empty map degrades every request
        // to `.documentNotIndexed`, which reports as a limit on the check.
        guard let pipeline = appState.indexingPipeline else {
            // No pipeline means nothing is indexed on this device yet. Every quotation reports as
            // uncheckable rather than as wrong.
            verification = ExcerptVerificationReport(
                outcomes: Dictionary(uniqueKeysWithValues:
                    requests.map { ($0, ExcerptVerifier.Outcome.documentNotIndexed) }))
            return
        }
        let bodies = (try? await pipeline.documentBodyTextsByKey(forKeys: Array(keys))) ?? [:]
        let outcomes = ExcerptVerifier.verify(requests, bodyTexts: bodies)
        // R-5 P3b-1 (design Q-7 g): the verifier reads a vanished document and a freed volume
        // alike — no body text — and used to tell the reader "their volumes are not downloaded"
        // about a document an update removed. The revision table knows the difference; the rule
        // that applies it is `ExcerptVerifier.upgradingVanished`, tested on its own.
        var changeKinds: [String: String] = [:]
        for request in outcomes.filter({ $0.value == .documentNotIndexed }).keys {
            let key = "\(request.volumeId)/\(request.documentId)"
            guard changeKinds[key] == nil else { continue }
            let row = try? await pipeline.documentRevision(volumeId: request.volumeId,
                                                          documentId: request.documentId)
            changeKinds[key] = row?.changeKind ?? ""
        }
        verification = ExcerptVerificationReport(
            outcomes: ExcerptVerifier.upgradingVanished(outcomes, changeKinds: changeKinds))

        #if DEBUG
        print("[CollectionExportSheet] Verified \(requests.count) excerpt(s): "
              + "\(verification?.verifiedCount ?? 0) ok, \(verification?.failures.count ?? 0) not found")
        #endif
    }

    private func recordExport(format: String, documentCount: Int) {
        ExportHistoryRecorder.record(format: format,
                                     documentCount: documentCount,
                                     collectionName: collection.name,
                                     projectId: appState.activeProjectId,
                                     in: modelContext)
    }

    /// Builds a content resolver whose progress callbacks drive this sheet's
    /// volume-preparation and summary-generation status messages.
    private func makeResolver() -> CollectionContentResolver {
        CollectionContentResolver(
            appState: appState,
            modelContext: modelContext,
            onPreparingStatus: { preparingMessage = $0 },
            onSummaryStatus: { summaryGeneratingMessage = $0 }
        )
    }

    // MARK: - Native collection file (Phase 4 / D9)

    /// Options shown when the native `.fruscollection` format is selected: the D9a
    /// notes-privacy opt-in plus a short explanation of what the shared file carries.
    @ViewBuilder
    private var nativeShareOptions: some View {
        Toggle(String(localized: "export.native.includeNotes",
                      defaultValue: "Include my research notes"),
               isOn: $includeNotesInSharedFile)
        Text(String(localized: "export.native.hint",
                    defaultValue: "Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Serializes the collection to a temporary `.fruscollection` file and routes it into the
    /// shared export-delivery path. Bypasses document resolution entirely — the native format
    /// carries the collection's *source* (references + composition + structure), not rendered
    /// content — so no volume needs to be downloaded to produce it.
    private func runNativeExport() {
        exportError = nil
        zoteroFileRecoveryOffered = false
        // Smart collections have no static entries to serialize yet (D9b); the picker hides the
        // native format for them, but guard defensively.
        guard collection.savedSearchId == nil else {
            exportError = String(localized: "export.native.smartUnsupported",
                                 defaultValue: "Smart collections can’t be shared as a file yet.")
            return
        }
        isExporting = true
        defer { isExporting = false }
        do {
            let resolveNoteTexts: (CollectionEntry) -> [String] = { entry in
                // Mirror CollectionContentResolver's note-resolution (D5): explicit
                // selection wins; else an un-migrated legacy single-note link counts; else
                // an empty selection with no legacy link means **all** of the document's
                // notes — so this native export stays in lockstep with every rendered
                // format instead of silently dropping notes on untouched entries.
                if !entry.selectedNoteIds.isEmpty {
                    return entry.selectedNoteIds.compactMap { id in
                        allNotes.first { $0.id == id }?.bodyText
                    }.filter { !$0.isEmpty }
                }
                if let legacyId = entry.researchNoteId,
                   let legacy = allNotes.first(where: { $0.id == legacyId }) {
                    return legacy.bodyText.isEmpty ? [] : [legacy.bodyText]
                }
                return allNotes
                    .filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }
                    .map(\.bodyText)
                    .filter { !$0.isEmpty }
            }
            let file = NativeCollectionSerializer.makeFile(
                from: collection,
                includeNotes: includeNotesInSharedFile,
                resolveNoteTexts: resolveNoteTexts)
            let url = try NativeCollectionSerializer.writeTemporaryFile(file)
            exportedURL = url
            recordExport(format: selectedFormat.rawValue,
                         documentCount: entries.filter { $0.entryKind == .document }.count)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Send to Zotero Library (Web API)

    /// `true` when a Zotero account is connected (Settings → Integrations → Zotero).
    private var isZoteroConnected: Bool { ZoteroAccountStore.shared.isConnected }

    /// What the row can honestly promise, which differs by platform when no account is connected.
    private var zoteroCaption: String {
        if isZoteroConnected {
            return String(localized: "export.zotero.send.caption.connected",
                          defaultValue: "Over the Zotero web API — carries your tags & research notes.")
        }
        #if os(iOS)
        // Verified against zotero/zotero-ios: no `CFBundleDocumentTypes` for `.ris`, no
        // File → Import, and the share extension runs web translators only. An RIS cannot reach
        // Zotero on this device, so the row must not imply that it does.
        return String(localized: "export.zotero.send.caption.iosNoAccount",
                      defaultValue: "Connect a Zotero account to send with your tags & research notes. Without one this saves an RIS file, which Zotero can import on a Mac — not on iPhone or iPad.")
        #else
        return String(localized: "export.zotero.send.caption.macNoAccount",
                      defaultValue: "Connect a Zotero account to send with your tags & research notes. Without one this saves an RIS file for Zotero’s File → Import.")
        #endif
    }

    /// Set when a connected send failed and the RIS file is still worth offering (#358).
    ///
    /// A failed send used to end at an error message, discarding the work of resolving and
    /// formatting the collection. The file route is unaffected by whatever broke the API call —
    /// a bad key, an offline device, a 500 — so it is offered as a recovery rather than a
    /// dead end.
    @State private var zoteroFileRecoveryOffered = false

    /// The unified "Send to Zotero Library" action (Composer v2 §Export), invoked by `zoteroSendRow`:
    /// the annotation-preserving Web-API send when a Zotero account is connected, else the RIS-file
    /// fallback for Zotero desktop (the row's caption states this behavior).
    private func sendToZotero() async {
        if isZoteroConnected {
            await sendToZoteroLibrary()
        } else {
            await exportZoteroRIS()
        }
    }

    /// Produces the Zotero RIS file (desktop-import fallback) and routes it into the shared
    /// export delivery. Reuses `resolvedZoteroDocuments()` (static + smart paths) so the RIS
    /// file and the Web-API send always carry the same resolved documents.
    private func exportZoteroRIS() async {
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            guard !docs.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
            let url = try await ZoteroCollectionExporter().export(
                metadata: metadata, documents: docs,
                options: ExportFormat.zoteroJSON.exportOptions(for: collection))
            exportedURL = url
            recordExport(format: ExportFormat.zoteroJSON.rawValue, documentCount: docs.count)
        } catch is CancellationError {
            return
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Resolves the collection's documents (static or smart) and POSTs them to the
    /// user's Zotero library, then surfaces a result alert.
    private func sendToZoteroLibrary() async {
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            exportError = ZoteroAPIError.missingCredentials.errorDescription
            zoteroFileRecoveryOffered = true
            return
        }
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            // The records the RIS file prints, under the options it is written with: each document's research
            // notes go only where they print (#2000). The send took every item as resolved and read no setting.
            let items = ZoteroCollectionExporter.records(
                for: docs.map(CollectionExportItem.document),
                options: ExportFormat.zoteroJSON.exportOptions(for: collection))
            guard !items.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let result = try await ZoteroAPIClient().send(
                items: items,
                collectionName: CollectionExportNaming.zoteroCollectionName(savedName: collection.name),
                apiKey: apiKey,
                userID: userID,
                username: store.username
            ) { message in
                Task { @MainActor in preparingMessage = message }
            }
            // The decisive case for contract D1: this send has a real external side effect —
            // items land in the user's live Zotero library — and this row is the app's only
            // memory that it happened.
            recordExport(format: "zotero-api", documentCount: result.addedItems)
            zoteroResult = result
        } catch is CancellationError {
            return
        } catch {
            exportError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
            // #358: the send failed, but the collection is resolved and the file route does not
            // depend on whatever broke the API call. Offer it rather than ending here.
            zoteroFileRecoveryOffered = true
        }
    }

    /// Resolves the collection's export documents for the Zotero send, the RIS card and, since L35, BibTeX, handling
    /// both the smart (saved-search) and static collection paths via the shared resolver.
    /// The three render citations and notes — never body content — so this
    /// deliberately uses `resolveDocuments`, which skips the summary phase.
    private func resolvedZoteroDocuments() async throws -> [CollectionExportDocument] {
        try await makeResolver().resolveDocuments(
            collection: collection, entries: entries, allNotes: allNotes, purpose: .export)
    }

    /// Localised body for the Zotero result alert.
    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        var line = String(format: String(localized: "export.zotero.result %lld %lld",
                                          defaultValue: "Added %lld documents and %lld notes to Zotero."),
                          Int64(result.addedItems), Int64(result.addedNotes))
        if result.failedItems > 0 {
            line += " " + String(format: String(localized: "export.zotero.result.failed %lld",
                                                defaultValue: "%lld failed."),
                                 Int64(result.failedItems))
        }
        return line
    }
}

// MARK: - MacExportCompleteView

#if os(macOS)
/// Shown after a successful export on macOS.
///
/// Offers two actions:
/// - **Reveal in Finder** — opens the file's containing folder with the file selected.
/// - **Save To…** — presents an `NSSavePanel` so the user can copy the exported file
///   to a permanent location of their choice.
///
/// The file lives in `FileManager.temporaryDirectory` and will be cleaned up by
/// the OS; using the Save panel is the recommended path for keeping the output.
struct MacExportCompleteView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Success content
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text(String(localized: "export.mac.success.title",
                            defaultValue: "Export Complete"))
                    .font(.headline)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            // Button bar — Done (left, Escape), Reveal in Finder (secondary),
            // Save To… (primary, Return). Standard macOS success dialog layout.
            HStack(spacing: 8) {
                Button(String(localized: "export.mac.done",
                              defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "export.mac.reveal",
                              defaultValue: "Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    dismiss()
                }

                Button(String(localized: "export.mac.saveTo",
                              defaultValue: "Save To\u{2026}")) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = url.lastPathComponent
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let dest = panel.url {
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: url, to: dest)
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 340)
    }
}
#endif

// MARK: - ShareSheet

#if os(iOS)
/// Thin wrapper around the iOS share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - URL: Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Zotero result alert

/// Presents the outcome of a "Send to Zotero Library" run, with an optional
/// "View in Zotero" link. Shared by the export sheet's macOS and iOS bodies.
private struct ZoteroResultAlertModifier: ViewModifier {
    @Binding var result: ZoteroSendResult?
    let message: (ZoteroSendResult) -> String
    let openURL: OpenURLAction

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "export.zotero.result.title", defaultValue: "Sent to Zotero"),
            isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } }),
            presenting: result
        ) { result in
            if let url = result.webURL {
                Button(String(localized: "export.zotero.viewInZotero",
                              defaultValue: "View in Zotero")) { openURL(url) }
            }
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { result in
            Text(message(result))
        }
    }
}

extension View {
    /// Attaches the Zotero "Sent to Zotero" result alert.
    func zoteroResultAlert(
        result: Binding<ZoteroSendResult?>,
        message: @escaping (ZoteroSendResult) -> String,
        openURL: OpenURLAction
    ) -> some View {
        modifier(ZoteroResultAlertModifier(result: result, message: message, openURL: openURL))
    }
}

// MARK: - CollectionExportMetadata.forExport

extension CollectionExportMetadata {
    /// The metadata an export of `collection` carries — the one builder the export sheet's rendered formats and the
    /// live preview (`CollectionPreviewView`) both call (#1463), so the preview shows the title, provenance and method
    /// appendix the exported file will carry.
    ///
    /// It passes the SAVED name, which may be empty; `init` resolves the title ("Untitled Collection" for an unnamed
    /// collection). The preview used to carry a fallback of its own while the sheet passed the name through, which is
    /// how the preview read "Untitled Collection" over an export titled blank. (The sheet's Zotero RIS file makes its
    /// metadata by hand from the name and note alone, and `init` titles that the same way.)
    @MainActor
    static func forExport(of collection: Collection, activeProject: Project?,
                          modelContext: ModelContext) -> CollectionExportMetadata {
        let provenance = projectProvenance(
            enabled: collection.includeProjectProvenance,
            projectName: activeProject?.name,
            researchQuestion: activeProject?.researchQuestion)
        let appendixLines = ResearchDataExporter.collectionMethodAppendixLines(
            enabled: collection.includeMethodAppendix,
            modelContext: modelContext,
            activeProject: activeProject)
        return CollectionExportMetadata(
            name: collection.name, note: collection.note,
            subtitle: collection.subtitle, authorLine: collection.authorLine,
            projectName: provenance.name, projectResearchQuestion: provenance.question,
            includeColophon: collection.includeColophon,
            methodAppendixLines: appendixLines)
    }
}

// MARK: - CollectionExportSentence (L35)

/// The export sheet's sentence: what an export will print, written from what the export counts
/// (`CollectionContentResolver.exportTally`; L35, the third review's J9, decision 192).
///
/// It took the place of `Collection.compositionSummarySentence` in the sheet, which reads the collection's defaults:
/// it said "with headnotes" over documents with none to print, and said what the collection's default prints of a
/// document set to print otherwise. The sentence follows the format chosen, since BibTeX and RIS print citations and the
/// collection file the collection itself.
///
/// Version history:
///   1.0 — L35 (J9, decision 192): initial implementation
enum CollectionExportSentence {

    /// What an export in `format` prints of a collection that counts `tally`.
    ///
    /// - Parameters:
    ///   - tally: What the export resolves the collection's documents to.
    ///   - format: The format chosen.
    ///   - drawsWordCloud: Whether the export draws the collection's word-cloud overview: asked for, in a format that
    ///     draws one (`ExportFormat.exportOptions(for:)`).
    /// - Returns: One sentence: the documents and how each prints, then what prints with them.
    static func text(for tally: CollectionExportTally, format: ExportFormat, drawsWordCloud: Bool) -> String {
        let count = tally.documents
        guard count > 0 else {
            return String(localized: "export.sentence.noDocuments", defaultValue: "This collection has no documents.")
        }
        switch format {
        case .fruscollection:
            return CountCopy.phrase(
                count,
                one: String(localized: "export.sentence.native.one %@",
                            defaultValue: "An editable copy of this collection and its %@ document."),
                many: String(localized: "export.sentence.native.many %@",
                             defaultValue: "An editable copy of this collection and its %@ documents."))
        case .bibtex, .zoteroJSON:
            return sentence(lead: citationsLead(count), with: tally.printsNotes ? [yourNotes] : [])
        case .pdf, .html, .docx:
            var parts: [String] = []
            if tally.headnotesAsked > 0 { parts.append(headnotes(printed: tally.headnotesPrinted, of: count)) }
            if tally.printsNotes { parts.append(yourNotes) }
            if tally.printsHighlights {
                parts.append(String(localized: "export.sentence.highlights", defaultValue: "your highlights"))
            }
            if drawsWordCloud {
                parts.append(String(localized: "collection.export.summary.wordCloud",
                                    defaultValue: "a word-cloud overview"))
            }
            return sentence(lead: renderedLead(tally), with: parts)
        }
    }

    /// What this device lacks for the export, said before Export (J11, #2018): the summaries the export must write,
    /// where Apple Intelligence cannot write one here, in the words the export stops with
    /// (`CollectionSummaryExportError`). `nil` when it lacks nothing: every summary the export prints is stored, or
    /// Apple Intelligence can write the rest, or the format prints none.
    static func deviceLacks(_ tally: CollectionExportTally, format: ExportFormat,
                            availability: AppleIntelligenceAvailability) -> String? {
        guard format.printsSummaries, tally.summariesToWrite > 0, !availability.isAvailable else { return nil }
        return CollectionSummaryExportError.summariesNeedAppleIntelligence(
            missing: tally.summariesToWrite, availability: availability).errorDescription
    }

    // MARK: The sentence's parts

    /// "your notes": a document's research notes print with it.
    private static var yourNotes: String {
        String(localized: "export.sentence.notes", defaultValue: "your notes")
    }

    /// `lead`, then ", with" and `parts` as a list, and a full stop.
    private static func sentence(lead: String, with parts: [String]) -> String {
        guard !parts.isEmpty else { return lead + "." }
        return String(format: String(localized: "export.sentence.with %1$@ %2$@", defaultValue: "%1$@, with %2$@."),
                      lead, ListFormatter.localizedString(byJoining: parts))
    }

    /// The documents of a citations-only export: "A citation for each of 6 documents".
    private static func citationsLead(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "export.sentence.citations.one %@",
                                     defaultValue: "A citation for %@ document"),
                         many: String(localized: "export.sentence.citations.many %@",
                                      defaultValue: "A citation for each of %@ documents"))
    }

    /// The documents of a rendered export and how each prints: "The full text of 6 documents", or, where they print
    /// differently, "6 documents: 2 in full, 2 as summaries and 2 as citations".
    private static func renderedLead(_ tally: CollectionExportTally) -> String {
        let count = tally.documents
        if tally.inFull == count {
            return CountCopy.phrase(count,
                                    one: String(localized: "export.sentence.full.one %@",
                                                defaultValue: "The full text of %@ document"),
                                    many: String(localized: "export.sentence.full.many %@",
                                                 defaultValue: "The full text of %@ documents"))
        }
        if tally.asSummaries == count {
            return CountCopy.phrase(count,
                                    one: String(localized: "export.sentence.summaries.one %@",
                                                defaultValue: "A summary of %@ document"),
                                    many: String(localized: "export.sentence.summaries.many %@",
                                                 defaultValue: "A summary of each of %@ documents"))
        }
        if tally.asCitations == count { return citationsLead(count) }
        var ways: [String] = []
        if tally.inFull > 0 {
            ways.append(String(format: String(localized: "export.sentence.mixed.full %@", defaultValue: "%@ in full"),
                               tally.inFull.formatted()))
        }
        if tally.asSummaries > 0 {
            ways.append(CountCopy.phrase(tally.asSummaries,
                                         one: String(localized: "export.sentence.mixed.summaries.one %@",
                                                     defaultValue: "%@ as a summary"),
                                         many: String(localized: "export.sentence.mixed.summaries.many %@",
                                                      defaultValue: "%@ as summaries")))
        }
        if tally.asCitations > 0 {
            ways.append(CountCopy.phrase(tally.asCitations,
                                         one: String(localized: "export.sentence.mixed.citations.one %@",
                                                     defaultValue: "%@ as a citation"),
                                         many: String(localized: "export.sentence.mixed.citations.many %@",
                                                      defaultValue: "%@ as citations")))
        }
        return String(format: String(localized: "export.sentence.mixed %1$@ %2$@", defaultValue: "%1$@ documents: %2$@"),
                      count.formatted(), ListFormatter.localizedString(byJoining: ways))
    }

    /// How many of the documents print a headnote (decision 192): "headnotes for 4 of 6", or of a collection of one,
    /// "its headnote" or "no stored headnote". A headnote prints where one is asked for and a summary is stored for it.
    private static func headnotes(printed: Int, of count: Int) -> String {
        if count == 1 {
            return printed == 1
                ? String(localized: "export.sentence.headnote.one", defaultValue: "its headnote")
                : String(localized: "export.sentence.headnote.none", defaultValue: "no stored headnote")
        }
        return String(format: String(localized: "export.sentence.headnotes %1$@ %2$@",
                                     defaultValue: "headnotes for %1$@ of %2$@"),
                      printed.formatted(), count.formatted())
    }
}

extension ExportFormat {
    /// Whether an export in this format prints a summary: PDF, HTML and Word do, and ask Apple Intelligence for one not
    /// stored. BibTeX and RIS print citations, and the collection file the collection itself.
    fileprivate var printsSummaries: Bool {
        switch self {
        case .pdf, .html, .docx: return true
        case .zoteroJSON, .bibtex, .fruscollection: return false
        }
    }
}

// MARK: - CollectionExportFormatMemory (L35)

/// The format each collection last exported as on this device, which its export sheet opens on (L35; the design's
/// §5.1: "It opens on the format this collection last exported as on this device"). So *Export…* and then Export
/// repeat the last export, from the lists as from the editor.
///
/// It is the device's, in `UserDefaults`, and not a synced preference. Only an export made with the sheet's Export is
/// kept: the Zotero send runs from its own row and is not a format the sheet opens on (the third review). A format the
/// sheet does not offer the collection now — the collection file, after a link to a saved search — opens on PDF, as
/// every sheet did until then.
///
/// Version history:
///   1.0 — L35: initial implementation
enum CollectionExportFormatMemory {

    /// The defaults key: a map from a collection's id to the raw value of the format it last exported as.
    static let defaultsKey = "frus.collections.exportFormatById"

    /// The format `collectionId` last exported as here, if the sheet offers it among `offered`; else PDF.
    static func format(for collectionId: UUID, offered: [ExportFormat],
                       in defaults: UserDefaults = .standard) -> ExportFormat {
        let stored = (defaults.dictionary(forKey: defaultsKey) as? [String: String])?[collectionId.uuidString]
        guard let format = stored.flatMap(ExportFormat.init(rawValue:)), offered.contains(format) else { return .pdf }
        return format
    }

    /// Keeps `format` as the one `collectionId` last exported as here.
    static func remember(_ format: ExportFormat, for collectionId: UUID, in defaults: UserDefaults = .standard) {
        var formats = (defaults.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
        formats[collectionId.uuidString] = format.rawValue
        defaults.set(formats, forKey: defaultsKey)
    }
}

// MARK: - CollectionListExportSheet (L35)

/// The export sheet opened from a list rather than from the collection's editor (L35, lane 1): a row of the Collections
/// list on iPhone and iPad, and a row of Manage Collections on the Mac. It reads for itself what the editor hands the
/// sheet: the collection's entries in their order, and every research note, one copy of each.
///
/// Version history:
///   1.0 — L35: initial implementation
struct CollectionListExportSheet: View {
    /// The collection to export.
    let collection: Collection

    @Environment(AppState.self) private var appState
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNoteCopies: [ResearchNote]

    var body: some View {
        ExportSheetView(collection: collection,
                        entries: CollectionEntryOrdering.modelOrder(of: collection),
                        allNotes: ResearchNote.oneCopyEach(allNoteCopies),
                        appState: appState)
    }
}
