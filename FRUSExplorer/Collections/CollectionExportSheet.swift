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
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let collection: Collection
    let entries: [CollectionEntry]
    let allNotes: [ResearchNote]
    let appState: AppState

    /// All projects, to resolve the active project for export provenance (#377 Phase 4) — mirrors
    /// the `authorLine` placeholder lookup in the collection editors.
    @Query(sort: \Project.name) private var allProjects: [Project]

    /// The active project (the source of export provenance), or `nil` in Global Context.
    private var activeProject: Project? { allProjects.first { $0.id == appState.activeProjectId } }

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportedURL: URL? = nil
    @State private var exportError: String? = nil
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
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(Text("\(fmt.gridLabel), \(fmt.gridCaption)"))
            }
        }
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
                    Text(String(localized: "export.zotero.send.caption",
                                defaultValue: "Over the Zotero web API — carries your tags & research notes. Falls back to an RIS file with no account."))
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
        #if os(macOS)
        macExportBody
        #else
        iOSExportBody
        #endif
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

            // Options — the plain-language composition summary (what actually renders, set in the
            // collection's Composition section), the selectable format grid, the native-file
            // notes-privacy opt-in when `.fruscollection` is chosen, and the separated "Send to a
            // Reference Manager" Zotero row (Composer v2 §Export).
            VStack(alignment: .leading, spacing: 16) {
                Text(collection.compositionSummarySentence)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

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

            // Inline error — shown above the button bar when present
            if let error = exportError {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
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
    #if os(iOS)
    private var iOSExportBody: some View {
        NavigationStack {
            Form {
                // Plain-language summary of what will actually render (set in Composition).
                Section {
                    Text(collection.compositionSummarySentence)
                        .font(.callout)
                }

                // Selectable format grid (Composer v2 §Export) — headerless, matching the canvas (the
                // grid sits directly under the composition summary with no "Format" label) and the
                // macOS body.
                Section {
                    exportFormatGrid
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
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

                // Progress feedback, or the Export {Format} primary button.
                Section {
                    if let msg = preparingMessage ?? summaryGeneratingMessage {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(msg).foregroundStyle(.secondary)
                        }
                    } else if isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(String(localized: "export.progress.label",
                                        defaultValue: "Exporting…"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await runExport() }
                        } label: {
                            Text(exportButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(entries.isEmpty && collection.savedSearchId == nil)
                    }
                }

                if let error = exportError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
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
    #endif // os(iOS)

    /// Runs the selected export: native `.fruscollection` files serialize the collection's
    /// source directly; every rendered format resolves content through
    /// `CollectionContentResolver` (one path for smart and static collections) and hands
    /// the resolved items to the format's exporter.
    private func runExport() async {
        exportError = nil

        // Native shareable-collection file (D9): serialize the collection's source directly.
        if selectedFormat == .fruscollection {
            runNativeExport()
            return
        }

        // The RIS card resolves citations only (no body/summaries/volume downloads), so route it
        // through the Zotero RIS path rather than the generic render pipeline (Composer v2 §Export).
        if selectedFormat == .zoteroJSON {
            await exportZoteroRIS()
            return
        }

        isExporting = true
        defer {
            isExporting = false
            preparingMessage = nil
            summaryGeneratingMessage = nil
        }
        do {
            let items = try await makeResolver().resolve(
                collection: collection, entries: entries, allNotes: allNotes, purpose: .export)
            let provenance = CollectionExportMetadata.projectProvenance(
                enabled: collection.includeProjectProvenance,
                projectName: activeProject?.name,
                researchQuestion: activeProject?.researchQuestion)
            let appendixLines = ResearchDataExporter.collectionMethodAppendixLines(
                enabled: collection.includeMethodAppendix,
                modelContext: modelContext,
                activeProject: activeProject)
            let metadata = CollectionExportMetadata(
                name: collection.name, note: collection.note,
                subtitle: collection.subtitle, authorLine: collection.authorLine,
                projectName: provenance.name, projectResearchQuestion: provenance.question,
                includeColophon: collection.includeColophon,
                methodAppendixLines: appendixLines)
            guard let exporter = selectedFormat.makeExporter() else { return }
            let url = try await exporter.export(
                metadata: metadata, items: items, options: buildExportOptions())
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

    /// Assembles `CollectionExportOptions` from the collection's persisted composition
    /// (edited in the manager's Composition section) plus the format-dependent word-cloud gate.
    private func buildExportOptions() -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:          CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            includeFootnotes:  collection.effectiveIncludeFootnotes,
            includeSourceNote: collection.effectiveIncludeSourceNote,
            applyHighlights:   collection.applyHighlights,
            includeNotes:      collection.includeNotes,
            summaryPromptId:   collection.summaryPromptId,
            includeWordCloud: collection.includeWordCloud && (selectedFormat == .pdf || selectedFormat == .html),
            includeHeadnoteDefault: collection.defaultIncludeHeadnote
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
                    defaultValue: "Shares an editable copy of this collection — its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above."))
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
            let data = try NativeCollectionSerializer.encode(file)

            let safeName = collection.name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
                .joined(separator: "-")
            let filename = (safeName.isEmpty ? "collection" : safeName)
                + "." + NativeCollectionSerializer.fileExtension
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
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
                metadata: metadata, documents: docs, options: buildExportOptions())
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
            return
        }
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            let items = docs.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.zoteroItem)
            guard !items.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let result = try await ZoteroAPIClient().send(
                items: items,
                collectionName: collection.name.isEmpty ? nil : collection.name,
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
        }
    }

    /// Resolves the collection's export documents for the Zotero send, handling both
    /// the smart (saved-search) and static collection paths via the shared resolver.
    /// The Zotero formats render citations and notes — never body content — so this
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
